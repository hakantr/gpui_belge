# Test, headless ve dış asset kaynakları

Bu bölüm, üretim binary'si dışındaki asset senaryolarını ele alır. GPUI test ortamları (`TestApp`, `TestAppContext`, `HeadlessAppContext`, `VisualTestAppContext`) asset boru hattını opsiyonel kabul eder; bu, testlerin asset bağımlılığı olmadan çalışmasını mümkün kılar. Buna karşılık asset rendering'i içeren testler için (örneğin SVG ikonların gerçekten çizildiği görsel testler) gerçek `Assets` struct'ının test ortamına aktarılması gerekir. Bu iki ihtiyaç arasındaki ince çizgiyi netleştirmek, "neden bazı testler asset gerektirir, bazıları gerektirmez?" sorusunu cevaplar. Ayrıca filesystem'deki SVG/PNG dosyalarının runtime'a nasıl alındığı (`SvgAsset`, `Resource::Path`) bu bölümde toparlanır; uygulamanın binary asset'lerin yanı sıra dış kaynaklı varlıkları da bilinçli bir şekilde yönetmesinin nasıl yapıldığı açığa kavuşur.

---

## 1. Asset olmayan testler: `()` boş AssetSource

Çoğu GPUI testi asset boru hattına ihtiyaç duymaz. Layout testi, event dispatch testi, entity testi gibi senaryolar font ve ikon olmadan da çalışır. Bu durumda `App` boş `AssetSource` ile kurarsın:

```rust
impl Application {
    pub fn with_platform(platform: Rc<dyn Platform>) -> Self {
        Self(App::new_app(
            platform,
            Arc::new(()),                  // <-- boş AssetSource varsayılan
            Arc::new(NullHttpClient),
        ))
    }
    // ...
}
```

`Arc::new(())` `Arc<dyn AssetSource>` üretir; çünkü unit type için `AssetSource` implementasyonu vardır:

```rust
impl AssetSource for () {
    fn load(&self, _path: &str) -> Result<Option<Cow<'static, [u8]>>> {
        Ok(None)
    }

    fn list(&self, _path: &str) -> Result<Vec<SharedString>> {
        Ok(vec![])
    }
}
```

Bu davranışın test ortamındaki anlamı: tüm `cx.asset_source().load(path)` çağrıları `Ok(None)` döner, tüm `list` çağrıları boş vektör verir. Yani SVG render hattı çağrılırsa byte bulamaz ve hata log'lar; font yükleyici hiçbir font bulamaz; tema yükleyici hiçbir gömülü tema yüklemez. Testin etki alanı bu sayede asset varlığına bağlı olmaktan çıkar.

`()` `Sized` ve `Sync + Send` olduğundan `Arc::new(())` neredeyse maliyetsizdir (boş tip için Rust derleyicisi optimize eder). Başarım açısından "boş source" pratikte sıfır overhead'dir.

---

## 2. `TestApp::with_text_system_and_assets`

GPUI'de iki test yüzeyi yan yana durur. `#[gpui::test]` makrosunun verdiği klasik `TestAppContext`, `TestAppContext::build` içinde boş `Arc::new(())` asset source ile kurarsın. Daha yeni ve sade test API'si olan `TestApp` ise gerçek veya mock asset source geçirmek için ayrı bir yapıcı sunar:

```rust
// crates/gpui/src/app/test_app.rs
impl TestApp {
    pub fn with_seed(seed: u64) -> Self {
        Self::build(seed, None, Arc::new(()))
    }

    pub fn with_text_system(text_system: Arc<dyn PlatformTextSystem>) -> Self {
        Self::build(0, Some(text_system), Arc::new(()))
    }

    pub fn with_text_system_and_assets(
        text_system: Arc<dyn PlatformTextSystem>,
        asset_source: Arc<dyn crate::AssetSource>,
    ) -> Self {
        Self::build(0, Some(text_system), asset_source)
    }

    fn build(
        seed: u64,
        platform_text_system: Option<Arc<dyn PlatformTextSystem>>,
        asset_source: Arc<dyn crate::AssetSource>,
    ) -> Self {
        // ...
        let app = App::new_app(platform.clone(), asset_source, http_client);
        // ...
    }
}
```

Bu yüzden üç ayrımı doğru yapmak gerekir:

- **`TestAppContext`** — Makro tabanlı testlerin varsayılan bağlamıdır; asset source'u boş gelir ve özel asset source almak için public bir constructor sunmaz.
- **`TestApp::with_text_system`** — Metin shaping testi için gerçek `PlatformTextSystem` yüklenir ama asset source boş kalır. Tipik kullanım: metin layout'unu doğrulayan ama ikon içermeyen testler.
- **`TestApp::with_text_system_and_assets`** — Hem metin sistemi hem asset source gerçek yüklenir. Tipik kullanım: SVG ikonları render eden, font dosyalarını okuyan testler.

Son yapıcı testlerin `crates/assets` crate'ine dependency eklemesini gerektirir; bu Zed test kodlarında genellikle yaparsın:

```rust
use assets::Assets;
// ...
let app = TestApp::with_text_system_and_assets(
    text_system,
    Arc::new(Assets),
);
```

`Assets` struct'ı zero-sized type olduğu için `Arc::new(Assets)` yine ucuzdur.

---

## 3. `HeadlessAppContext` ve `VisualTestAppContext`

GPUI iki ek test bağlamı sunar; her ikisi de asset source'u opsiyonel parametre olarak alır.

### 3.1 HeadlessAppContext

Headless senaryolar (örneğin CI üzerinde screenshot üretimi, otomasyon testleri):

```rust
impl HeadlessAppContext {
    pub fn new(platform_text_system: Arc<dyn PlatformTextSystem>) -> Self {
        Self::with_platform(platform_text_system, Arc::new(()), || None)
    }

    pub fn with_asset_source(
        platform_text_system: Arc<dyn PlatformTextSystem>,
        asset_source: Arc<dyn AssetSource>,
    ) -> Self {
        Self::with_platform(platform_text_system, asset_source, || None)
    }

    pub fn with_platform(
        platform_text_system: Arc<dyn PlatformTextSystem>,
        asset_source: Arc<dyn AssetSource>,
        renderer_factory: impl Fn() -> Option<Box<dyn PlatformHeadlessRenderer>> + 'static,
    ) -> Self {
        // ...
    }
}
```

Üç yapıcının ilişkisi: `new` `()` ile çağırır; `with_asset_source` özelleştirilmiş asset source ile çağırır; `with_platform` ek olarak headless renderer fabrikası alır. Renderer fabrikası `None` döndürürse window'lar render edilmez ama element ağacı ve layout hesaplanır.

### 3.2 VisualTestAppContext

macOS özelinde, gerçek Metal compositor üzerinde test yapan bağlam:

```rust
pub fn new(platform: Rc<dyn Platform>) -> Self {
    Self::with_asset_source(platform, Arc::new(()))
}

/// Use this when you need SVG icons to render properly in visual tests.
/// Pass the real `Assets` struct to enable icon rendering.
pub fn with_asset_source(
    platform: Rc<dyn Platform>,
    asset_source: Arc<dyn AssetSource>,
) -> Self {
    // ...
}
```

Kaynak kodundaki doc comment net bir kullanım rehberi sunar: SVG ikonların doğru render edilmesi gereken testlerde `with_asset_source(platform, Arc::new(Assets))` çağırılır. Aksi halde testin döndüğü screenshot ikon yerine boş alan içerir.

Bu üç test bağlamının ortak deseni şudur: asset source `Arc<dyn AssetSource>` olarak parametrize edilir; test yazarı senaryosuna göre `Arc::new(())` veya `Arc::new(Assets)` arasında seçim yapar. Asset bağımlılığının opsiyonel tutulması, testlerin asset boyutu değişimine duyarsız kalmasını sağlar.

---

## 4. `Assets::load_test_fonts` ile minimum font kümesi

Test ortamında metin shaping yapılması gerekiyorsa ama tüm font'ları yüklemek istenmiyorsa, `Assets::load_test_fonts` çağrılır:

```rust
pub fn load_test_fonts(&self, cx: &App) {
    cx.text_system()
        .add_fonts(vec![
            self.load("fonts/lilex/Lilex-Regular.ttf")??,
        ])
        ?
}
```

Bu metot yalnızca `Lilex-Regular.ttf` dosyasını yükler. Üç gerekçe vardır:

- **Minimum maliyet:** Test başlatılırken tüm font ailelerini yüklemek hem CPU hem bellek harcar. Tek bir Lilex regular varyantı çoğu yazı testi için yeterlidir.
- **Monospace garantisi:** Lilex monospace font'tur; karakter genişlikleri tutarlıdır. Bu, snapshot testlerinde piksel düzeyinde tutarlılık sağlamak için kritiktir.
- **Lisans sürtünmesi yok:** Lilex OFL ile dağıtılır; test fixture'ları için kullanılırken ek lisans dikkati gerekmez.

`load_test_fonts` `Application::with_assets(Assets)` çağrısından sonra çağırırsın. Çoğu test bağlamında bu adım manuel olarak eklenir, otomatik yapılmaz; testler font'a ihtiyaç duymadığı sürece atlanır.

---

## 5. Filesystem'den SVG yüklemek: `SvgAsset` ve `external_path`

Asset boru hattının ikinci ana ihtiyacı, runtime'da değişken filesystem path'lerinden gelen varlıkları render etmektir. İkon tema extension'ları, kullanıcı SVG'leri ve dinamik üretilen ikonlar bu yoldan geçer.

`svg()` element'inin iki path setter'ı vardır:

```rust
.path("icons/x.svg")              // binary'den
.external_path("/tmp/icon.svg")   // filesystem'den
```

Filesystem yolu `SvgAsset` üzerinden geçer:

```rust
enum SvgAsset {}

impl Asset for SvgAsset {
    type Source = SharedString;
    type Output = Result<Arc<[u8]>, Arc<std::io::Error>>;

    fn load(
        source: Self::Source,
        _cx: &mut App,
    ) -> impl Future<Output = Self::Output> + Send + 'static {
        async move {
            let bytes = fs::read(Path::new(source.as_ref())).map_err(|e| Arc::new(e))?;
            let bytes = Arc::from(bytes);
            Ok(bytes)
        }
    }
}
```

Akış şudur:

```rust
// Element paint metodu içinden:
let Some(bytes) = window
    .use_asset::<SvgAsset>(path, cx)
    .and_then(|asset| asset.log_err())
else {
    return;
};

window
    .paint_svg(bounds, path.clone(), Some(&bytes), transformation, color, cx)
    .log_err();
```

Üç ayrıntı dikkat çekicidir:

- **`SvgAsset` `cx.asset_source()`'a hiç bakmaz.** Doğrudan `fs::read` yapar. Yani filesystem yolu binary asset boru hattından bağımsızdır; `with_assets` çağrısı yapılmamış olsa bile çalışır.
- **`use_asset` cache'i sayesinde aynı dosya birden fazla kez okunmaz.** İlk render'da `fs::read` çalışır, sonraki render'larda cache'lenen Future'dan byte'lar paylaşılır.
- **`paint_svg`'nin ikinci argümanı `Some(&bytes)`** — Bu, asset source'tan okumaması gerektiğini söyler; doğrudan verilen byte'lar üzerinden çalışır. Bu adım, binary path ile filesystem path arasındaki tek arayüz farkıdır.

---

## 6. Filesystem'den raster image yüklemek: `Resource::Path`

Raster image'lar için yol `Resource` enum'unun üç varyantı üzerinden işler:

```rust
pub enum Resource {
    Uri(SharedUri),
    Path(Arc<Path>),
    Embedded(SharedString),
}
```

`img(Path::new("/tmp/screenshot.png"))` çağrısı `Resource::Path` üretir. `ImageAssetLoader::load` bu varyantı senkron `fs::read` ile karşılar:

```rust
Resource::Path(uri) => fs::read(uri.as_ref())?,
```

`Resource::Uri` ise HTTP istemcisi üzerinden okur:

```rust
Resource::Uri(uri) => {
    let mut response = client.get(uri.as_ref(), ().into(), true).await
        .with_context(|| format!("loading image asset from {uri:?}"))?;
    let mut body = Vec::new();
    response.body_mut().read_to_end(&mut body).await?;
    if !response.status().is_success() {
        // ... ImageCacheError::BadStatus
    }
    body
}
```

Ve `Resource::Embedded` `cx.asset_source()` üzerinden gider:

```rust
Resource::Embedded(path) => {
    let data = asset_source.load(&path).ok().flatten();
    if let Some(data) = data {
        data.to_vec()
    } else {
        return Err(ImageCacheError::Asset(...));
    }
}
```

Üç yol da aynı decode hattına akar (`image::guess_format`, format decoder, BGRA dönüşüm). Bu, asset boru hattının tipik bir kararıdır: kaynak türü ne olursa olsun, decode adımı tek bir noktada birleşir.

### 6.1 HTTP istemcisi ve testler

Testlerde HTTP yolu önemli bir noktadır: hem `TestApp::build` hem `TestAppContext::build` `FakeHttpClient::with_404_response` kurarsın. Yani tüm HTTP image istekleri test ortamında 404 döndürür ve `Resource::Uri` varyantı kullanıldığında `BadStatus` hatası alırsın.

Bu davranış kasıtlıdır: testlerin ağa bağımlı olmaması gerekir. Eğer testte HTTP üzerinden image yüklenmesi gerekiyorsa `FakeHttpClient`'ın özel bir yanıt veren varyantı kullanırsın:

```rust
let client = FakeHttpClient::with_response_provider(|request| {
    // ... custom yanıt
});
```

Bu, asset boru hattının test ortamında nasıl mock'lanabileceğinin örneklerinden biridir.

---

## 7. Mock AssetSource yazmak

Bazen testler için tamamen özel bir asset source gerekir. Tipik senaryo: bir testin yalnızca belirli path'lere yanıt vermesini istemek. Trait gereği iki metot implement edilir:

```rust
struct MockAssetSource(HashMap<&'static str, &'static [u8]>);

impl AssetSource for MockAssetSource {
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>> {
        Ok(self.0.get(path).map(|bytes| Cow::Borrowed(*bytes)))
    }

    fn list(&self, path: &str) -> Result<Vec<SharedString>> {
        Ok(self.0
            .keys()
            .filter(|p| p.starts_with(path))
            .map(|p| (*p).into())
            .collect())
    }
}

let mock = Arc::new(MockAssetSource({
    let mut map = HashMap::new();
    map.insert("icons/test.svg", &include_bytes!("test.svg")[..]);
    map
}));
let app = TestApp::with_text_system_and_assets(text_system, mock);
```

Üç fayda:

- **Kontrollü erişim:** Yalnızca testte ihtiyaç duyulan dosyalar gömülür; binary'nin tamamı yüklenmez. Bu, derleme süresini ve test başlatma süresini kısaltır.
- **Hata enjeksiyonu:** Belirli bir path için `Err` döndürmek mümkündür; bu, asset yükleme hatası altındaki UI davranışını test etmeyi sağlar.
- **Determinizm:** Mock'lar deterministtir; binary asset'lerin dosya sistemi durumuna göre değişmesi riski yoktur.

Bu desen GPUI'nin asset boru hattının `dyn AssetSource` üzerinden parametrize edilmesinin pratik karşılığıdır. Trait object esnekliği test yazarına geniş bir alan sağlar.

---

## 8. Dış dosya path'lerini güvenli yönetmek

Filesystem'den varlık okumak güvenlik ve sağlamlık açısından dikkat ister:

- **Symlink takibi.** `fs::read` symlink'leri takip eder; uygulamanın kabul ettiği dizinin dışına çıkan bir symlink hassas dosyalara erişim sağlayabilir. Kullanıcı sağladığı path'leri canonicalize edip whitelist edilmiş kök altında doğrulamak gerekir.
- **Path injection.** Kullanıcı girdisi `Resource::Embedded` olarak yorumlanırsa `../../etc/passwd` gibi path'ler asset source'a sızabilir. `RustEmbed::get` yalnızca include kalıplarıyla kapsanan asset path'lerini döndürür ve debug filesystem kolunda canonical path kontrolü yapar; bu yüzden risk pratikte düşüktür. Buna karşılık `Resource::Path` için aynı garanti yoktur; explicit doğrulama gerekir.
- **`is_uri` heuristic'i.** `From<&str>` for `ImageSource` `is_uri(s)` ile URI ayrımı yapar; "C:\Users\..." gibi path'ler `is_uri` true dönmediği için `Embedded` olarak yorumlanır. Bu yanlış yorumlama sessiz başarısızlığa yol açar (asset bulunamaz). Path olduğundan emin olunmayan input için `PathBuf::from(input).into()` ile dönüştürmek daha güvenlidir.

Bu kurallar asset boru hattının "hız+esneklik" tasarımının kullanıcı koduna yansıyan boş kısımlarıdır; trait davranışı izin verir, doğrulama uygulamaya kalır.

---

## 9. Asset boru hattını devre dışı bırakmak

Bazı durumlarda asset boru hattının tamamen devre dışı bırakılması gerekir:

- **Headless CLI:** Komut satırı uygulaması GPUI'yi kullanır ama hiçbir window açmaz; SVG render veya font yükleme gerekmez. Bu senaryoda `Application::with_assets` çağrılmaz, boş `()` kalır.
- **Çok küçük binary'ler:** Asset gömme binary boyutunu büyütür. Asset'lerin filesystem'den okunduğu portatif binary'ler için `RustEmbed` kullanılmadan `AssetSource` implement edilebilir:

```rust
struct FilesystemAssets {
    base_dir: PathBuf,
}

impl AssetSource for FilesystemAssets {
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>> {
        let full_path = self.base_dir.join(path);
        match std::fs::read(&full_path) {
            Ok(bytes) => Ok(Some(Cow::Owned(bytes))),
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(err) => Err(err.into()),
        }
    }

    fn list(&self, path: &str) -> Result<Vec<SharedString>> {
        // ... walkdir veya benzer yardımıyla recursive listeleme
        todo!()
    }
}
```

Bu desen, üretim binary'sinin asset'leri gömülü taşırken testlerin veya alternatif binary'lerin filesystem'den okumasını sağlar. Aynı `cx.asset_source()` yüzeyinden çalıştığı için diğer kod yolları değişmez.

---

## 10. Asset boru hattının test edilebilirlik özeti

`AssetSource` trait'inin esnek tasarımı dört farklı test/dış senaryoyu birden destekler:

| Senaryo | AssetSource türü | Test bağlamı |
|---------|------------------|--------------|
| Asset olmayan makro testleri | `Arc::new(())` | `TestAppContext` (`#[gpui::test]`) |
| Asset olmayan sade testler | `Arc::new(())` | `TestApp::new` veya `TestApp::with_text_system` |
| Gerçek asset'lerle metin testi | `Arc::new(Assets)` | `TestApp::with_text_system_and_assets` |
| Mock asset'lerle birim testi | `Arc::new(MockAssetSource(...))` | `TestApp::with_text_system_and_assets` |
| Filesystem'den okuyan portatif binary | `Arc::new(FilesystemAssets { ... })` | `Application::with_assets` (production) |
| Görsel snapshot testi | `Arc::new(Assets)` | `VisualTestAppContext::with_asset_source` |
| Headless CI render testi | `Arc::new(Assets)` veya mock | `HeadlessAppContext::with_asset_source` |

Bu çoklu kullanım modelinin gerçekleşebilmesi, `AssetSource` trait'inin minimal arayüzünden kaynaklanır. Trait yalnızca iki metot tanımlar; her implementasyon kendi maliyet profili ve davranışını seçer. Bu, asset altyapısının "uzak ya da yakın, gömülü ya da filesystem, üretim ya da test" sorularını tek bir kod yolundan cevaplayabilmesinin sebebidir.

---
