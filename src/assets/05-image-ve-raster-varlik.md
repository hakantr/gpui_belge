# Görsel ve raster varlık akışı

Bu bölüm, vektörel logolar ve raster (PNG/JPG/WebP/GIF) görseller için kullanılan boru hattını anlatır. İkon sistemiyle paylaşılan bir SVG render hattı vardır, ama tüketim yüzeyi farklıdır. `images/` klasörü serbest boyutlu vektör görsellere ev sahipliği yapar. Raster image'lar ise `img()` element'i ve `ImageSource` enum'u üzerinden akar. Bu ayrım, uzaktan URL'den gelen görsel ile binary'ye gömülü logonun aynı arayüzü nasıl paylaştığını açıklar.

Bölüm boyunca `Resource::Embedded` ve `Resource::Path` koşullarının ne zaman seçildiğini görürsün. `ImageAssetLoader` format desteği ve image cache davranışı da aynı akış içinde ele alınır.

---

## 1. `images/` klasörü ve `VectorName`

İkonların aksine vektörel görseller (logolar, damgalar, dekoratif çizimler) `assets/images/` altında durur:

```text
assets/images/
├── business_stamp.svg
├── grid.svg
├── pro_trial_stamp.svg
├── pro_user_stamp.svg
├── student_stamp.svg
├── zed_logo.svg
└── zed_x_copilot.svg
```

`crates/ui/src/components/image.rs` içindeki `VectorName` enum'u bu dosyaları registry'ye bağlar:

```rust
#[derive(
    Debug, PartialEq, Eq, Copy, Clone, EnumIter, EnumString, IntoStaticStr, Serialize, Deserialize,
)]
#[strum(serialize_all = "snake_case")]
pub enum VectorName {
    BusinessStamp,
    Grid,
    ProTrialStamp,
    ProUserStamp,
    StudentStamp,
    ZedLogo,
    ZedXCopilot,
}

impl VectorName {
    pub fn path(&self) -> Arc<str> {
        let file_stem: &'static str = self.into();
        format!("images/{file_stem}.svg").into()
    }
}
```

İkonlardaki `IconName` ile yapısı **bire bir aynıdır**: snake_case dönüşüm, `EnumIter`, `IntoStaticStr`. Tek fark path prefix'idir (`images/` vs `icons/`). Bu kasıtlı tasarım kararı sayesinde yeni bir vektör görsel eklemek için:

1. `assets/images/yeni_logo.svg` dosyası eklersin.
2. `VectorName::YeniLogo` varyantı eklersin.
3. UI'da `Vector::square(VectorName::YeniLogo, rems_from_px(60.))` ile kullanırsın.

---

## 2. `Vector` bileşeni

`Vector` ile `Icon` arasındaki tek mimari fark, boyutlandırma yaklaşımıdır:

```rust
pub struct Vector {
    path: Arc<str>,
    color: Color,
    size: Size<Rems>,            // <-- Size<Rems>: genişlik ve yükseklik ayrı
    transformation: Transformation,
}

impl Vector {
    pub fn new(vector: VectorName, width: Rems, height: Rems) -> Self {
        Self {
            path: vector.path(),
            color: Color::default(),
            size: Size { width, height },
            transformation: Transformation::default(),
        }
    }

    pub fn square(vector: VectorName, size: Rems) -> Self {
        Self::new(vector, size, size)
    }
}
```

`Icon` `Rems` ile **tek değer** alır. `IconSize` enum'undan türetilmiş standart boyutlardan birini bekler; `Vector` ise genişlik ve yükseklik için iki ayrı `Rems` ister. Bu, kullanım amaçları arasındaki anlam farkını yansıtır:

| Boyut | Icon | Vector |
|-------|------|--------|
| Tipik kullanım | UI eylemleri (16-24px) | Logo, damga (40-200px) |
| Boyut alanı | Tek değer (kare) | Genişlik + yükseklik |
| Standart ölçek | `IconSize` enum'u | Çağrı yerinde belirlenir |
| Renk modeli | Tek renkli (tema rengi) | Tek renkli (tema rengi) |

İki bileşen de aynı `svg()` element'ini ve aynı `SvgRenderer` yolunu kullanır; bu yüzden `Vector` da yalnızca tek renkli SVG'leri doğru render eder. Bunun nedeni `Window::paint_svg` çağrısının SVG'yi alpha mask olarak rasterleştirip tek bir `text_color` ile boyamasıdır. Çok renkli logo veya illüstrasyon gerekiyorsa `Vector` yerine `img("images/logo.svg")` kullanman gerekir; `ImageAssetLoader` SVG byte'larını `SvgRenderer::render_single_frame` ile tam renkli `RenderImage`'a çevirir.

`Vector::render` çağrısı sade tutulur:

```rust
impl RenderOnce for Vector {
    fn render(self, _window: &mut Window, cx: &mut App) -> impl IntoElement {
        let width = self.size.width;
        let height = self.size.height;

        svg()
            .flex_none()
            .w(width)
            .h(height)
            .path(self.path)
            .text_color(self.color.color(cx))
            .with_transformation(self.transformation)
    }
}
```

`svg()` element'ine doğrudan path verilir, ekstra adım yoktur. Yani `Vector` özünde "iki boyutu ayrı tutan bir SVG ikonu" olarak ele alınabilir.

---

## 3. `img()` element'i ve `ImageSource`

Raster image'lar, uzak URL'ler ve filesystem'deki büyük görseller için `img()` element'i kullanırsın. `crates/gpui/src/elements/img.rs` içindeki tanımı dört kaynak türünü desteklemek üzere tasarlanmıştır:

```rust
#[derive(Clone)]
pub enum ImageSource {
    /// The image content will be loaded from some resource location
    Resource(Resource),
    /// Cached image data
    Render(Arc<RenderImage>),
    /// Cached image data
    Image(Arc<Image>),
    /// A custom loading function to use
    Custom(Arc<dyn Fn(&mut Window, &mut App) -> Option<Result<Arc<RenderImage>, ImageCacheError>>>),
}
```

Dört varyantın anlamı:

- **`Resource(Resource)`** — Bir path, URI veya embedded path string'idir. En sık kullanılan kaynak türüdür; `From<&str>`, `From<&Path>`, `From<PathBuf>` gibi conversion'lar bu varyantı üretir.
- **`Render(Arc<RenderImage>)`** — Daha önce decode edilmiş ham BGRA buffer. Cache veya elle üretilmiş image data için kullanılır; ekstra yükleme yapılmaz, doğrudan render edilir.
- **`Image(Arc<Image>)`** — Decode edilmemiş ama yüklenmiş image instance'ı. Decode adımı yine asenkron yapılır; tipik olarak format dönüştürmesi gereken kaynaklar için.
- **`Custom(Arc<dyn Fn>)`** — Tamamen özel bir loader. UI bileşeni kendi yüklemesini tanımlamak istediğinde (örneğin clipboard'tan görsel yapıştırma) bu varyant kullanırsın.

### 3.1 String'den ImageSource'a tip dönüşümleri

`img(...)` çağrısının kabul ettiği değer tip karmaşıklığı sayesinde tek çağrıyla yönetilir. `crates/gpui/src/elements/img.rs` dosyasındaki kritik dönüşüm:

```rust
impl<'a> From<&'a str> for ImageSource {
    fn from(s: &'a str) -> Self {
        if is_uri(s) {
            Self::Resource(Resource::Uri(s.to_string().into()))
        } else {
            Self::Resource(Resource::Embedded(s.to_string().into()))
        }
    }
}
```

Heuristik basittir: `url::Url::from_str(s).is_ok()` true dönerse string bir URI olarak yorumlanır; aksi halde embedded asset path'i kabul edilir. Yani:

- `img("images/zed_logo.svg")` → `Resource::Embedded("images/zed_logo.svg")`
- `img("https://example.com/avatar.png")` → `Resource::Uri("https://example.com/avatar.png")`
- `img(&Path::new("/tmp/screenshot.png"))` → `Resource::Path(...)` (ayrı `From<&Path>` impl'i)

Bu otomatik dönüşüm zinciri, bileşen yazarlarının kaynak türünü açıkça belirtmesine gerek bırakmaz. Path olduğundan emin olunmayan bir input için string yerine `PathBuf` veya `Arc<Path>` kullanmak daha sağlamdır. Aksi halde değer "https://..." ile başlamadığı sürece `Embedded` kabul edilir ve binary'den okunmaya çalışılır.

---

## 4. `Resource` enum'u ve üç kaynak yolu

`crates/gpui/src/asset_cache.rs` içindeki `Resource` enum'u, kaynak türünü ayrıştırır:

```rust
pub enum Resource {
    Uri(SharedUri),
    Path(Arc<Path>),
    Embedded(SharedString),
}
```

`ImageAssetLoader::load` üç varyantı sırayla işler:

```rust
async move {
    let bytes = match source.clone() {
        Resource::Path(uri) => fs::read(uri.as_ref())?,
        Resource::Uri(uri) => {
            let mut response = client.get(uri.as_ref(), ().into(), true).await
                .with_context(|| format!("loading image asset from {uri:?}"))?;
            let mut body = Vec::new();
            response.body_mut().read_to_end(&mut body).await?;
            if !response.status().is_success() {
                // ... ImageCacheError::BadStatus döner
            }
            body
        }
        Resource::Embedded(path) => {
            let data = asset_source.load(&path).ok().flatten();
            if let Some(data) = data {
                data.to_vec()
            } else {
                return Err(ImageCacheError::Asset(
                    format!("Embedded resource not found: {}", path).into(),
                ));
            }
        }
    };
    // ... decode adımı
}
```

Üç yolun karakteristikleri:

| Resource | Kaynak | Hata davranışı | Cache anahtarı |
|----------|--------|----------------|----------------|
| `Path` | Filesystem (senkron `fs::read`) | `std::io::Error` | `Arc<Path>` hash'i |
| `Uri` | HTTP istemcisi (`cx.http_client()`) | `BadStatus` veya body okuma hatası | `SharedUri` hash'i |
| `Embedded` | `cx.asset_source()` | `ImageCacheError::Asset` | `SharedString` hash'i |

Üç yolun ortak yanı, tümünün byte'a indirilmesidir. Sonraki decode adımı her üçü için aynıdır:

```rust
if let Ok(format) = image::guess_format(&bytes) {
    let data = match format {
        ImageFormat::Gif => {
            let decoder = GifDecoder::new(Cursor::new(&bytes))?;
            // ... her frame okunur, RGBA→BGRA döndürülür
        }
        // ... diğer formatlar
    };
}
```

`image` crate'i format tespit eder; her format için ayrı bir decoder hattı vardır. GIF için animasyon frame'leri sırayla işlenir, statik formatlar için tek frame üretilir.

### 4.1 Desteklenen format listesi

`Img::extensions()` desteklenen formatları döner:

```rust
pub fn extensions() -> &'static [&'static str] {
    &[
        "avif", "jpg", "jpeg", "png", "gif", "webp", "tif", "tiff", "tga", "dds",
        "bmp", "ico", "hdr", "exr", "pbm", "pam", "ppm", "pgm", "ff", "farbfeld",
        "qoi", "svg",
    ]
}
```

Bu liste `image::ImageFormat::from_extension` çıktısının üzerine `svg` eklenmiş halidir. SVG hem `svg()` element'i hem `img()` element'i üzerinden render edilebilir; aralarındaki fark şudur:

- `svg()` ile çağrı: `text_color` ile tek renkli boyama yapılır; ikon tarzı kullanım.
- `img()` ile çağrı: SVG `SvgRenderer` üzerinden raster image olarak çevirilir; çok renkli dosyalar buradan geçer.

Uygulamadaki gerçek ayrım uzantıdan çok byte içeriğine dayanır. `ImageAssetLoader`, önce `image::guess_format(&bytes)` ile raster formatları yakalar; bu çağrı SVG için format döndürmezse `svg_renderer.render_single_frame(&bytes, 1.0)` fallback'ine geçer. Bu yüzden `Img::extensions()` listesindeki `svg`, "image crate SVG decode ediyor" anlamına değil, `img()` element'inin SVG byte'larını GPUI'nin SVG renderer'ı üzerinden kabul ettiği anlamına gelir.

---

## 5. `ImageAssetLoader` ve `Asset` cache'i

`ImageAssetLoader` `Asset` trait'inin somut bir implementasyonudur:

```rust
pub enum ImageAssetLoader {}

impl Asset for ImageAssetLoader {
    type Source = Resource;
    type Output = Result<Arc<RenderImage>, ImageCacheError>;

    fn load(source: Self::Source, cx: &mut App) -> impl Future<Output = Self::Output> + Send + 'static {
        let client = cx.http_client();
        let svg_renderer = cx.svg_renderer();
        let asset_source = cx.asset_source().clone();
        async move {
            // ... yukarıdaki üç yol
        }
    }
}

pub type ImgResourceLoader = AssetLogger<ImageAssetLoader>;
```

Üç nokta önemlidir:

- **`AssetLogger<T>` sarmalayıcısı:** `crates/gpui/src/asset_cache.rs` içinde tanımlı bu adapter, `T::Output` `Result` olduğunda `Err` varyantını log'a düşürür. Pratikte `img()` element'i `ImgResourceLoader = AssetLogger<ImageAssetLoader>` ile çalışır; yani hata durumunda log'a açıklayıcı bir mesaj girer, fakat exception fırlatılmaz.
- **`cx.svg_renderer()` ve `cx.http_client()` clone'ları async kapanışa kapatılır:** Trait `'static` Future istediği için async kapanış kendi `cx` referansını taşıyamaz. Bu yüzden ihtiyaç duyulan servisler (svg renderer, http client, asset source) kapanış başlangıcında ödenir.
- **Output `Arc<RenderImage>`:** Yüklenmiş image cache'lenmiş şekilde döner; aynı kaynak için ikinci çağrı aynı `Arc` referansını döndürür. `RenderImage` `ImageId` taşır ve GPU sprite atlas'ında bu id ile aranır.

### 5.1 `use_asset` cache mekaniği

`ImageSource::use_data` çağrısı `window.use_asset::<ImgResourceLoader>(resource, cx)` ile asset cache'ine girer:

```rust
pub fn use_asset<A: Asset>(&mut self, source: &A::Source, cx: &mut App) -> Option<A::Output> {
    let (task, is_first) = cx.fetch_asset::<A>(source);
    task.clone().now_or_never().or_else(|| {
        if is_first {
            let entity_id = self.current_view();
            self.spawn(cx, {
                let task = task.clone();
                async move |cx| {
                    task.await;

                    cx.on_next_frame(move |_, cx| {
                        cx.notify(entity_id);
                    });
                }
            })
            .detach();
        }
        None
    })
}
```

Akış:

1. `cx.fetch_asset::<A>(source)` cache'te task var mı bakar. Yoksa yeni Future başlatır.
2. `now_or_never()` Future hazırsa sonucu döner; aksi halde `None` döner ve view'in re-render edilmesi için bir tetikleyici kurarsın.
3. İlk çağrıda (`is_first == true`) Future tamamlandığında `cx.notify(entity_id)` çağrılır; böylece görsel yüklenince view yeniden çizilir ve `use_asset` ikinci çağrıda sonucu döner.

Pratik sonucu şudur: bir image element ilk render'da "boş" olarak çizilir, byte'lar yüklenip decode edildikten sonra otomatik olarak yenilenir. Bu davranış kullanıcı tarafında titrek bir flash olarak görünür; bunu yumuşatmak için `with_loading(...)` ile yer tutucu UI verilebilir.

---

## 6. `ImageCache` ve `image_cache` element'i

Image cache'in iki seviyesi vardır:

- **Global cache:** `App` üzerinde `loading_assets` haritası. `use_asset` çağrısı varsayılan olarak buraya düşer.
- **Lokal cache:** Element ağacındaki bir `ImageCacheElement`. Belirli bir bölgenin image'larını ayrı bir cache'e yönlendirmek için kullanırsın.

`Icon::preview` örneğindeki kullanım:

```rust
h_flex()
    .image_cache(gpui::retain_all("all icons"))
    .flex_wrap()
    .gap_2()
    .children(<IconName as strum::IntoEnumIterator>::iter().map(...))
```

`gpui::retain_all` "bu cache hiçbir şeyi atmasın" davranışı verir; tüm ikon galerisi açıkken cache evict olmaz. Diğer cache provider'ları LRU veya boyut sınırlı davranabilir; uygulamanın belleğini koruyarak bellek izini sınırlamak için kullanılırlar.

`Img::image_cache(entity)` çağrısı, bir image element'in cache hiyerarşisindeki en yakın `ImageCacheElement`'i yoksaymasını sağlar; doğrudan verilen cache kullanırsın. Bu, "şu görseli özel bir cache'e koy" davranışı için kapı açar.

---

## 7. Üç tüketim akışını ayırmak

Görsel asset'lar için tüketim yüzeyini netleştirmek gerekirse:

| Senaryo | Çağrı | Resource türü | Cache |
|---------|-------|--------------|-------|
| Binary'deki tek renkli vektör logo | `Vector::new(VectorName::X, w, h)` | `svg().path("images/x.svg")` doğrudan monochrome SvgRenderer yoluna düşer | Sprite atlas / alpha mask cache |
| Binary'deki renkli SVG | `img("images/x.svg")` | `Resource::Embedded` | `ImgResourceLoader` |
| Binary'deki raster | `img("images/x.png")` | `Resource::Embedded` | `ImgResourceLoader` |
| Filesystem'deki dış görsel | `img(Path::new("/tmp/x.png"))` | `Resource::Path` | `ImgResourceLoader` |
| Uzak HTTP görsel | `img("https://...")` | `Resource::Uri` | `ImgResourceLoader` |
| Önceden decode edilmiş | `img(arc_render_image)` | `ImageSource::Render` (cache yok) | - |
| Özel loader | `img(\|w, cx\| ...)` | `ImageSource::Custom` | Loader'a göre |

Tek `img()` element'inin altında bu kadar farklı yolun durması, kullanıcı tarafında basit bir API üretir: aynı çağrı imzası dört farklı kaynak türüyle çalışır. Asset boru hattı bu basitliği `Resource` enum'unun decode aşamasında türünü ayırarak sağlar.

---

## 8. `RenderImage` ve `Image` ayrımı

Boru hattının en sonunda iki ayrı türün bulunması ilk bakışta kafa karıştırıcıdır:

- **`Image`** — Format tespit edilmiş ama henüz BGRA'ya decode edilmemiş ham image. `to_image_data(renderer)` çağrısı `RenderImage`'a çevirir.
- **`RenderImage`** — BGRA buffer içeren, ImageId taşıyan ve GPU atlas'ında konumlandırılabilen son hal.

Akış: `Resource → bytes → Image → RenderImage → GPU atlas`. `ImgResourceLoader` Resource'tan RenderImage'a kadar tek adımda gider; `ImageDecoder` ise elinde Image olan bir kullanıcıya RenderImage döndürür. Bu ayrım iki kullanım senaryosunu destekler:

1. Image instance'ı uygulama içinde paylaşılıyor (örneğin clipboard'dan paste edilmiş görsel) — `ImageDecoder` ile decode edilir.
2. Resource path olarak verildi — `ImgResourceLoader` resource'tan başlayıp tüm yolu tek seferde geçer.

---

## 9. Pratik kullanım örnekleri

Tipik kullanımlar dört kalıpta toplanır:

```rust
// 1. Binary'deki tek renkli Zed logosu
Vector::square(VectorName::ZedLogo, rems_from_px(60.))
    .color(Color::Accent)

// 2. Binary'deki renkli SVG veya raster image
img("images/business_stamp.svg")
    .size(rems_from_px(40.))

// 3. Dış URL'den avatar
img("https://example.com/avatars/user_42.png")
    .size(rems_from_px(24.))
    .with_fallback(|| Icon::new(IconName::User).into_any_element())

// 4. Filesystem'deki ekran görüntüsü
img(Path::new(&path_to_screenshot))
    .object_fit(ObjectFit::Contain)
    .with_loading(|| div().child("Yükleniyor..."))
```

Dördüncü örnekte iki ek setter dikkat çekicidir:

- **`with_loading`** — Image yüklenmeden önce gösterilecek yer tutucu UI. Async yüklemede ilk frame'in boş kalmaması için kullanırsın.
- **`with_fallback`** — Image yüklenemezse (404, decode hatası) gösterilecek alternatif UI. Genellikle ikon veya hata kutusu konur.

İki callback de `Fn() -> AnyElement` imzasındadır; çağrı sırasında her render'da yeniden çağrılır, durum tutmaz.

---

## 10. Pratik akış özeti

```text
img("images/x.png")
    │
    ▼ String -> ImageSource (heuristic)
ImageSource::Resource(Resource::Embedded("images/x.png"))
    │
    ▼ window.use_asset::<ImgResourceLoader>(resource, cx)
cx.fetch_asset::<ImgResourceLoader>(resource)
    │
    ▼ task cache: ilk çağrıda Future başlat
ImageAssetLoader::load
    ├── Resource::Path -> fs::read
    ├── Resource::Uri  -> cx.http_client().get(...)
    └── Resource::Embedded -> cx.asset_source().load(&path)
    │
    ▼ image::guess_format(bytes)
    │
    ▼ decoder hattı (Gif/Png/Jpg/Svg/...)
    │
    ▼ RGBA → BGRA dönüşümü
    │
    ▼ Arc<RenderImage> (ImageId atanır)
    │
    ▼ window.paint_image(bounds, render_image, style, cx)
    │
    ▼ GPU sprite atlas + paint kuyruğu
```

Üç noktanın altı çizilmelidir:

- **Resource tabanlı image yükleme async'dir**, render zamanı sıfır değildir. İlk frame'de görsel görünmez kalabilir; loading state'i bilinçli yönetilmelidir. `ImageSource::Render` gibi önceden decode edilmiş kaynaklarda bu bekleme yoktur.
- **`ImgResourceLoader` üç kaynak türünü birden taşır**; bu yüzden `img()` element'i URL, path ve embedded path için aynı API'yi sunar.
- **Cache hash'i Resource türünü içerir**; aynı path string'i bir kez URI bir kez Embedded olarak yorumlanırsa farklı cache anahtarları üretilir. Bu pratik olarak çakışma yaratmaz çünkü dönüşüm deterministtir, fakat custom loader yazılırken hash davranışı dikkate alınmalıdır.

---
