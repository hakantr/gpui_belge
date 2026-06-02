# AssetSource sözleşmesi ve RustEmbed entegrasyonu

Bu bölüm, asset altyapısının iki ana taşıyıcı parçasını tanıtır: klasörü `get/iter` API'si arkasına alan `RustEmbed` macro'su ve runtime'da bu varlıklara tek tip arayüz sağlayan `AssetSource` trait'i. Her iki parça birbirinden bağımsız tasarlanmıştır; bir uygulama `RustEmbed` kullanmadan da `AssetSource` implement edebilir (örneğin tüm varlıkları filesystem'den okuyan bir uygulama), bunun tersi de geçerlidir. Zed bu ikisini birleştiren küçük bir köprü struct'ı yazar; bu bölüm o köprünün hem sözleşmesini hem davranışını ortaya koyar.

---

<div align="center">

![Asset ve SVG Tüketim Boru Hattı](images/asset_flow.svg)

</div>

## 1. AssetSource trait'inin tanımı

GPUI tarafında asset altyapısının tek yüzeyi `gpui::AssetSource` trait'idir. Tanım `gpui` crate'indedir ve gövdesi yalnızca iki metottan oluşur:

```rust
pub trait AssetSource: 'static + Send + Sync {
    /// Verilen path'teki varlığı yükler.
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>>;

    /// Verilen prefix ile başlayan tüm varlık path'lerini listeler.
    fn list(&self, path: &str) -> Result<Vec<SharedString>>;
}
```

Trait'in üç özelliği bilinçli bir tasarım kararıdır:

- **`'static` yaşam süresi:** `AssetSource` `App` global state'ine konacaktır; bu yüzden borrow yaşam süresi taşıyamaz. Tüm path string'leri ve byte slice'ları `'static` veya `Cow<'static>` ile aktarılır.
- **`Send + Sync`:** Asset yükleme arka plan task'lerinde yapılabilir (örneğin `ImageAssetLoader` background executor üzerinde çalışır). Bu yüzden trait thread-safe olmak zorundadır.
- **`Cow<'static, [u8]>` dönüş tipi:** `RustEmbed` derleme zamanında varlıkları binary'ye gömdüğünde `Cow::Borrowed` döner (kopya yok); filesystem'den okuyan bir uygulama ise `Cow::Owned` döner. Tüketici tarafında her iki durum aynı kod yoluyla çalışır.

`load` metodunun `Result<Option<...>>` dönmesi bilinçlidir, fakat "bulunamadı" davranışı implementasyona bırakırsın. Boş veya filesystem tabanlı bir kaynak dosya yokken `Ok(None)` döndürebilir; Zed'in `Assets` sarmalayıcısı ise eksik path'i `Err` kabul eder. Bu sayede tüketici, kullandığı kaynağın kontratına göre "fallback'e geç" veya "log'la ve görünmez bırak" davranışını açıkça seçer.

### 1.1 Boş implementation: `()`

GPUI, `AssetSource` trait'ini Rust'ın unit type'ı `()` için de implement eder:

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

Bu boş implementation iki yerde varsayılan davranışı sağlar:

1. **`Application::with_platform` çağrısının ilk hali:** `Application::with_assets` çağrılmadığı sürece `App` `Arc::new(())` ile gelir; yani varlıkları sormak hata vermez, sadece her şey "yok" döner.
2. **`LoadThemes::JustBase`:** Tema sistemi başlatılırken `LoadThemes::JustBase` seçilirse `ThemeRegistry` `Box::new(()) as Box<dyn AssetSource>` ile kurulur; kullanıcı temaları yüklenmez, sadece fallback tema kalır. Bu mod özellikle testlerde tema dosyalarına bağımlı olmadan çalışmayı mümkün kılar.

Boş implementation'ın varlığı şu pratik sonucu doğurur: bir test veya başlangıç senaryosu yazılırken asset olmayan bir `App` kurmak için ekstra struct yazmaya gerek kalmaz. `Arc::new(())` yeterlidir.

---

## 2. RustEmbed macro'su ve klasör paketleme

`rust-embed` crate'i, bir klasörü tek bir statik erişim API'si arkasına koyan procedural macro sağlar. Zed'in release build'lerinde ve `debug-embed` feature'ı açıkken dosyalar binary'ye gömülür; normal debug build'lerde ise aynı API filesystem'den okur. Bu ayrım önemlidir: `Assets::get` ve `Assets::iter` çağrıları her iki modda da aynı görünür, fakat debug modda dosya değişiklikleri yeniden derleme gerektirmeden okunabilirken release modda içerik binary'nin parçasıdır. Zed bu macro'yu iki ayrı struct üzerinde kullanır.

### 2.1 Ana asset struct'ı

```rust
#[derive(RustEmbed)]
#[folder = "../../assets"]
#[include = "fonts/**/*"]
#[include = "icons/**/*"]
#[include = "images/**/*"]
#[include = "themes/**/*"]
#[exclude = "themes/src/*"]
#[include = "sounds/**/*"]
#[include = "prompts/**/*"]
#[include = "*.md"]
#[exclude = "*.DS_Store"]
pub struct Assets;
```

Macro derleme zamanında `assets/` klasörünü tarar ve release/debug-embed kolu için aşağıdaki yapıyı üretir:

- `Assets::get(path) -> Option<EmbeddedFile>`: Verilen path için varlığı döner. `EmbeddedFile` içinde `data: Cow<'static, [u8]>` ve metadata bulunur.
- `Assets::iter() -> impl Iterator<Item = Cow<'static, str>>`: `RustEmbed` kalıplarıyla eşleşen dosya path'lerini döner. Bu iterator `list` metodunda filtreleme için kullanırsın.

`#[include]` ve `#[exclude]` direktifleri `rust-embed` 8.11'de `globset` ile ayrı kümeler halinde değerlendirilir. Sıra "ilk eşleşen kazanır" şeklinde çalışmaz; exclude kalıpları include kalıplarından önceliklidir. Bu yüzden `themes/src/*` kalıbı, `themes/**/*` include'u ile eşleşen dosyaları da dışarıda bırakır. `*.DS_Store` kalıbı da aynı nedenle konumundan bağımsız olarak eşleşen dosyaları çıkarır.

Bir başka pratik ayrıntı: `globset::Glob::new` varsayılan ayarında `*` path ayırıcısını da eşleyebilir; `SettingsAssets` tarafındaki `#[include = "keymaps/*"]` bu yüzden `keymaps/macos/atom.json` gibi alt dizinlerdeki dosyaları da kapsar. Buna rağmen yeni kalıp yazarken niyeti açık etmek için alt dizin gerekiyorsa `**/*` kullanmak daha okunur ve ileride farklı glob motoruna taşınmayı kolaylaştırır.

**Önemli ayrıntı:** Macro, generate edilen release kolu için dosya listesini derleme sırasında üretir. Bu maliyet küçük klasörlerde hissedilmez ama Zed gibi yüzlerce ikon ve onlarca temayı taşıyan bir asset klasörü ile incremental build'lerde fark edilebilir bir gecikme yaratabilir. Bu yüzden Zed `Assets` struct'ını **ayrı bir crate** içine koymuştur (`assets`); `zed` crate'i yeniden derlenirken bu crate'in cache'i değişmez; tarama atlanır. Dosya başındaki yorum bu kararı açıkça doğrular: "...ana zed crate'inden ayrıldı, böylece zed her yeniden derlendiğinde RustEmbed macro'sunu çalıştırmak gerekmez. Incremental build'de bir-iki saniye kazandırır."

### 2.2 Ayar ve klavye asset struct'ı

```rust
#[derive(RustEmbed)]
#[folder = "../../assets"]
#[include = "settings/*"]
#[include = "keymaps/*"]
#[exclude = "*.DS_Store"]
pub struct SettingsAssets;
```

`SettingsAssets` ayrı tutulmasının iki gerekçesi vardır:

- **Erken erişim:** Settings ve keymap dosyaları uygulama başlatma sırasında `App` runtime'ı kurulmadan **önce** okunur. `default_settings()` fonksiyonu `cx.asset_source()` çağırmaz; doğrudan `SettingsAssets::get` üzerinden gider. Eğer bu varlıklar `Assets` içinde olsaydı, settings sisteminin başlatılması `App` kurulumuna bağımlı hale gelir ve döngüsel bağımlılık riski doğardı.
- **Crate sınırı:** `settings` crate'i `assets` crate'ine ve `Application::with_assets` ile kurulan runtime asset source'a bağımlı olmamalıdır. `settings` crate'i `gpui::App` tipini kullanır, fakat default settings/keymap içeriğini `Assets` üzerinden değil kendi `SettingsAssets` struct'ı üzerinden okur. Bu, settings başlatmasını ana asset crate'inin kuruluş sırasından ayırır. Bağımlılık grafiğini de düzleştirir.

İki struct birden olmasının pratik karşılığı şudur: aynı `assets/` klasöründeki dosyalar iki kez paketlenmez. `#[include]` filtreleri çakışmadığı sürece her dosya yalnızca bir struct tarafından alınır; release build'de bu, aynı byte'ların iki ayrı embed koluna girmemesi anlamına gelir.

---

## 3. AssetSource implementation'ı

`Assets` struct'ı `RustEmbed`'in ürettiği API'yi `AssetSource` trait'ine taşır:

```rust
impl AssetSource for Assets {
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>> {
        Self::get(path)
            .map(|f| Some(f.data))
            .with_context(|| format!("loading asset at path {path:?}"))
    }

    fn list(&self, path: &str) -> Result<Vec<SharedString>> {
        Ok(Self::iter()
            .filter_map(|p| {
                if p.starts_with(path) {
                    Some(p.into())
                } else {
                    None
                }
            })
            .collect())
    }
}
```

İki metot da basittir ama bazı incelikler vardır:

- `load`: `Self::get` `Option<EmbeddedFile>` döner; `Some(f.data)` ile içerdeki `Cow<'static, [u8]>` çıkarılır. `with_context` burada önemlidir: path yoksa `Option::None`, `Err` haline çevrilir; mesaj olarak `loading asset at path ...` eklersin. Yani `Assets` için eksik dosya `Ok(None)` değil hatadır. `Ok(None)` davranışını Zed'de özellikle boş `()` kaynağı ve bu yolu seçen custom kaynaklar üretir.
- `list`: `starts_with` ile prefix filtresi yapar. Yani `list("fonts")` çağrısı `fonts/ibm-plex-sans/...` gibi tüm alt klasörlerdeki path'leri döner. Bu davranış font yükleyici tarafından kullanılır ve recursive listeleme ihtiyacını ortadan kaldırır.

`list` metodunun recursive olması, font ve tema klasörlerindeki alt dizinleri (örneğin `themes/one/`, `themes/ayu/`) ek bir traverse koduna gerek kalmadan keşfetmeyi mümkün kılar. Tüketici sadece sonuçları kendi uzantı filtresinden geçirir (`.ttf`, `.json` vb.).

---

## 4. Runtime'a bağlama: `Application::with_assets`

`AssetSource` implementasyonu, GPUI'ye `Application::with_assets` zinciriyle aktarılır. `gpui` crate'indeki imza:

```rust
impl Application {
    pub fn with_platform(platform: Rc<dyn Platform>) -> Self {
        Self(App::new_app(
            platform,
            Arc::new(()),                  // <-- başlangıçta boş AssetSource
            Arc::new(NullHttpClient),
        ))
    }

    pub fn with_assets(self, asset_source: impl AssetSource) -> Self {
        let mut context_lock = self.0.borrow_mut();
        let asset_source = Arc::new(asset_source);
        context_lock.asset_source = asset_source.clone();
        context_lock.svg_renderer = SvgRenderer::new(asset_source);
        drop(context_lock);
        self
    }
    // ...
}
```

Üç gözlem önemlidir:

1. **`with_assets` çağrılmadıysa varsayılan değer boş `()`'tır.** Yani asset boru hattını kurmak unutulursa uygulama çökmez, sadece her ikon ve font "yok" döner. Bu davranış testler için faydalıdır ama production'da `with_assets` çağrısının atlanması SVG ve font yükleme hatalarına yol açar.
2. **`SvgRenderer` constructor'ı asset source'u alır.** Bu sayede `svg()` element'i path string'ini doğrudan ham byte'lara çevirebilir; ekstra bir köprü gerekmez. `SvgRenderer::new` çağrısı asset source'un `Arc` clone'unu kendi içine kopyalar, böylece SVG render hattı `App` lock'una girmeden asset okuyabilir.
3. **`Arc<dyn AssetSource>`:** Trait object olarak saklarsın. Bu, farklı asset kaynaklarının (RustEmbed, filesystem, network) aynı runtime üzerinde yan yana taşınmasını mümkün kılar. Pratikte Zed yalnızca tek bir asset source kullanır ama trait object esnekliği test ortamında değer kazanır.

Zed'in `main.rs` dosyasındaki kuruluş zinciri:

```rust
let app = Application::with_platform(gpui_platform::current_platform(false))
    .with_assets(Assets);
```

`Assets` struct'ı zero-sized type olduğu için `Arc::new(Assets)` neredeyse maliyetsizdir. Asset boru hattı bu tek satırla devreye girer.

---

## 5. `cx.asset_source()` ile tüketim yüzeyi

Runtime'a girmiş bir uygulamada asset source'a iki yoldan ulaşılır:

- `App::asset_source(&self) -> &Arc<dyn AssetSource>`: Doğrudan asset source referansı verir.
- `cx.asset_source()`: Aynı metodun `Context` üzerinden kestirme yolu.

Pratikte bu yüzey üç farklı kullanım deseni üretir:

**Senkron list+load:**

```rust
let asset_source = cx.asset_source();
let font_paths = asset_source.list("fonts")?;
for font_path in &font_paths {
    if !font_path.ends_with(".ttf") {
        continue;
    }
    let font_bytes = asset_source.load(font_path)??;
    // ...
}
```

Bu desen font yükleme (`load_embedded_fonts`) ve tema yükleme (`load_bundled_themes`) gibi uygulama başlatma yollarında kullanırsın. Senkron çağrıdır; bu yüzden release'te binary içinden gelen veya debug'da yerel filesystem'den hızlı okunan küçük varlıklar için uygundur. Ağ veya büyük filesystem varlıkları için `Asset` trait'i tercih edersin.

**Tek varlık yükleme (senkron):**

```rust
let path = format!("sounds/{}.wav", sound.file());
let bytes = cx.asset_source().load(&path)?
    .map(anyhow::Ok)
    .with_context(|| format!("No asset available for path {path}"))??
    .into_owned();
```

`Audio::sound_source` bu deseni kullanır: tek bir dosyayı senkron olarak alır ve `rodio::Decoder`'a verir. WAV dosyaları küçük olduğundan async loader gerekmez.

**Indirect tüketim (svg renderer, image cache):**

`SvgRenderer` ve `ImageAssetLoader` `cx.asset_source()` çağrısını kendi içlerinde yapar. UI kodu yalnızca path verir; render hattı path'i asset source'a çevirip byte'lara erişir. Bu, asset path'lerinin uygulama yüzeyinde "string olarak" dolaşmasını sağlar; ham byte taşımak gerekmez.

---

## 6. Üç tüketim desenini birbirinden ayırmak

Asset altyapısı tek arayüze sahiptir, ama tüketici tarafında üç farklı desen ortaya çıkar. Bunları birbirinden ayırmak önemlidir çünkü her birinin maliyet profili farklıdır:

| Desen | Tipik tüketici | Yaşam süresi | Maliyet profili |
|-------|---------------|--------------|-----------------|
| **Toplu liste+load** | `load_embedded_fonts`, `load_bundled_themes` | Uygulama başlatma anında bir kez | O(varlık sayısı); önyüklenmiş varlıklar için ucuz |
| **Tek dosya senkron load** | `Audio::sound_source`, `default_settings` | Talep anında | O(1); ufak dosyalar için ideal |
| **Asynchronous fetch (Asset trait)** | `ImageAssetLoader`, `SvgAsset` | Talep anında, cache'li | Background executor; büyük dosyalar veya ağ kaynaklı için |

`Asset` trait'i (üçüncü desenin yüzeyi) `gpui` crate'inde tanımlıdır:

```rust
pub trait Asset: 'static {
    type Source: Clone + Hash + Send;
    type Output: Clone + Send;

    fn load(
        source: Self::Source,
        cx: &mut App,
    ) -> impl Future<Output = Self::Output> + Send + 'static;
}
```

Bu trait `AssetSource`'tan farklıdır: `AssetSource` ham byte sağlar; `Asset` trait'i ise belirli bir varlık türü için decode/parse/decode-image gibi işlemleri de kapsayan asenkron yükleyicidir. Tipik implementation'lar `cx.asset_source()` çağrısı yapar, byte'ları alır ve kendi formatına çevirir. `window.use_asset::<T>(source, cx)` ve `cx.fetch_asset::<T>(source)` çağrıları cache mekanizmasını sağlar; aynı kaynak ikinci kez istendiğinde yüklenmiş Future paylaşılır.

Bu üçlü mimarinin pratik sonucu şudur: bir varlığı sadece "alıp byte'larına bakmak" gerekiyorsa `AssetSource` yeterlidir; bir varlığı UI render hattına bağlamak ve cache'lemek gerekiyorsa `Asset` trait'inin altına ayrı bir implementation yazılır. `SvgAsset` ve `ImageAssetLoader` bu desenin örnekleridir; sonraki bölümlerde her biri tüketici bağlamında ayrıca işlenir.

---

## 7. Kendi GPUI uygulamasında minimum kurulum

Zed'in yaklaşımını kendi uygulamanızda sergilemek için Zed'in asset dosyalarını veya crate gövdesini kopyalamak gerekmez. Aynı desen küçük bir `RustEmbed` struct'ı ve `AssetSource` implementasyonu ile kurulabilir:

```rust
use anyhow::Context as _;
use gpui::{AssetSource, Result, SharedString};
use rust_embed::RustEmbed;
use std::borrow::Cow;

#[derive(RustEmbed)]
#[folder = "assets"]
#[include = "fonts/**/*"]
#[include = "icons/**/*"]
#[include = "images/**/*"]
#[exclude = "*.DS_Store"]
pub struct AppAssets;

impl AssetSource for AppAssets {
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>> {
        Self::get(path)
            .map(|file| Some(file.data))
            .with_context(|| format!("loading asset at path {path:?}"))
    }

    fn list(&self, path: &str) -> Result<Vec<SharedString>> {
        Ok(Self::iter()
            .filter_map(|asset_path| {
                asset_path
                    .starts_with(path)
                    .then(|| asset_path.into())
            })
            .collect())
    }
}
```

Uygulama kuruluşunda tek zorunlu bağlantı `with_assets` çağrısıdır:

```rust
let app = gpui_platform::application().with_assets(AppAssets);
app.run(|cx| {
    // Pencere açmadan önce fontları, temaları veya kendi başlangıç asset'lerini yükle.
});
```

Bu minimum kurulumdan sonra `svg().path("icons/search.svg")`, `img("images/logo.svg")`, `cx.asset_source().load("...")` ve `cx.asset_source().list("...")` aynı Zed desenini kullanır. Dosya varlığını tip güvenli yapmak istiyorsan Zed'in `IconName`, `VectorName` ve `Sound` enum'larıyla yaptığı gibi kendi küçük registry enum'larını ekle; yalnızca path string'i vermek çalışır, fakat preview, serialization ve eksik dosya kontrolü zayıf kalır.

---
