# Test, headless ve dış varlık kaynakları

Bu bölüm, üretim binary'si dışındaki varlık senaryolarını ele alır. GPUI test ortamları (`TestApp`, `TestAppContext`, `HeadlessAppContext`, `VisualTestAppContext`) varlık hattını opsiyonel kabul eder; bu, testlerin varlık bağımlılığı olmadan çalışmasını mümkün kılar. Buna karşılık varlık render'ı içeren testler için (örneğin SVG ikonların gerçekten çizildiği görsel testler) gerçek `Assets` struct'ının test ortamına aktarılması gerekir. Bu iki ihtiyaç arasındaki ince çizgiyi netleştirmek, "neden bazı testler varlık gerektirir, bazıları gerektirmez?" sorusunu cevaplar. Ayrıca dosya sistemindeki SVG/PNG dosyalarının çalışma zamanına nasıl alındığı (`SvgAsset`, `Resource::Path`) bu bölümde toparlanır; uygulamanın binary varlıkların yanı sıra dış kaynaklı varlıkları da bilinçli bir şekilde yönetmesinin nasıl yapıldığı açığa kavuşur.

---

## 1. Varlık gerektirmeyen testler: `()` boş AssetSource

Çoğu GPUI testi varlık hattına ihtiyaç duymaz. Layout testi, olay dağıtım testi, entity testi gibi senaryolar font ve ikon olmadan da çalışır. Bu durumda `App` boş `AssetSource` ile kurarsın:

```rust
impl Application {
    pub fn with_platform(platform: Rc<dyn Platform>) -> Self {
        Self(App::new_app(
            platform,
            Arc::new(()),                  // <-- boş AssetSource varsayılanı
            Arc::new(NullHttpClient),
        ))
    }
    // ...
}
```

`Arc::new(())` `Arc<dyn AssetSource>` üretir; çünkü unit type için `AssetSource` implementasyonu vardır:

```rust
impl AssetSource for () {
    fn load(&self, _yol: &str) -> Result<Option<Cow<'static, [u8]>>> {
        Ok(None)
    }

    fn list(&self, _yol: &str) -> Result<Vec<SharedString>> {
        Ok(vec![])
    }
}
```

Bu davranışın test ortamındaki anlamı: tüm `cx.asset_source().load(yol)` çağrıları `Ok(None)` döner, tüm `list` çağrıları boş vektör verir. Yani SVG render hattı çağrılırsa bayt bulamaz ve hata log'lar; font yükleyici hiçbir font bulamaz; tema yükleyici hiçbir gömülü tema yüklemez. Testin etki alanı bu sayede varlığın bulunmasına bağlı olmaktan çıkar.

`()` `Sized` ve `Sync + Send` olduğundan `Arc::new(())` neredeyse maliyetsizdir (boş tip için Rust derleyicisi optimize eder). Başarım açısından "boş kaynak" pratikte sıfır ek yüktür.

---

## 2. `TestApp::with_text_system_and_assets`

GPUI'de iki test yüzeyi yan yana durur. `#[gpui::test]` makrosunun verdiği klasik `TestAppContext`, `TestAppContext::build` içinde boş `Arc::new(())` varlık kaynağı ile kurarsın. Daha yeni ve sade test API'si olan `TestApp` ise gerçek veya sahte varlık kaynağı geçirmek için ayrı bir yapıcı sunar:

```rust
impl TestApp {
    pub fn with_seed(seed: u64) -> Self {
        Self::build(seed, None, Arc::new(()))
    }

    pub fn with_text_system(metin_sistemi: Arc<dyn PlatformTextSystem>) -> Self {
        Self::build(0, Some(metin_sistemi), Arc::new(()))
    }

    pub fn with_text_system_and_assets(
        metin_sistemi: Arc<dyn PlatformTextSystem>,
        varlik_kaynagi: Arc<dyn crate::AssetSource>,
    ) -> Self {
        Self::build(0, Some(metin_sistemi), varlik_kaynagi)
    }

    fn build(
        seed: u64,
        platform_metin_sistemi: Option<Arc<dyn PlatformTextSystem>>,
        varlik_kaynagi: Arc<dyn crate::AssetSource>,
    ) -> Self {
        // ...
        let uygulama = App::new_app(platform.clone(), varlik_kaynagi, http_client);
        // ...
    }
}
```

Bu yüzden üç ayrımı doğru yapmak gerekir:

- **`TestAppContext`** — Makro tabanlı testlerin varsayılan bağlamıdır; varlık kaynağı boş gelir ve özel varlık kaynağı almak için public bir constructor sunmaz.
- **`TestApp::with_text_system`** — Metin shaping testi için gerçek `PlatformTextSystem` yüklenir ama varlık kaynağı boş kalır. Tipik kullanım: metin layout'unu doğrulayan ama ikon içermeyen testler.
- **`TestApp::with_text_system_and_assets`** — Hem metin sistemi hem varlık kaynağı gerçek yüklenir. Tipik kullanım: SVG ikonları render eden, font dosyalarını okuyan testler.

Son yapıcı testlerin `assets` crate'ine bağımlılık eklemesini gerektirir; bu Zed test kodlarında genellikle yaparsın:

```rust
use assets::Assets;
// ...
let uygulama = TestApp::with_text_system_and_assets(
    metin_sistemi,
    Arc::new(Assets),
);
```

`Assets` struct'ı sıfır boyutlu tip olduğu için `Arc::new(Assets)` yine ucuzdur.

---

## 3. `HeadlessAppContext` ve `VisualTestAppContext`

GPUI iki ek test bağlamı sunar; her ikisi de varlık kaynağını opsiyonel parametre olarak alır.

### 3.1 HeadlessAppContext

Headless senaryolar (örneğin CI üzerinde ekran görüntüsü üretimi, otomasyon testleri):

```rust
impl HeadlessAppContext {
    pub fn new(platform_metin_sistemi: Arc<dyn PlatformTextSystem>) -> Self {
        Self::with_platform(platform_metin_sistemi, Arc::new(()), || None)
    }

    pub fn with_asset_source(
        platform_metin_sistemi: Arc<dyn PlatformTextSystem>,
        varlik_kaynagi: Arc<dyn AssetSource>,
    ) -> Self {
        Self::with_platform(platform_metin_sistemi, varlik_kaynagi, || None)
    }

    pub fn with_platform(
        platform_metin_sistemi: Arc<dyn PlatformTextSystem>,
        varlik_kaynagi: Arc<dyn AssetSource>,
        renderer_fabrikasi: impl Fn() -> Option<Box<dyn PlatformHeadlessRenderer>> + 'static,
    ) -> Self {
        // ...
    }
}
```

Üç yapıcının ilişkisi: `new` `()` ile çağırır; `with_asset_source` özelleştirilmiş varlık kaynağı ile çağırır; `with_platform` ek olarak headless renderer fabrikası alır. Renderer fabrikası `None` döndürürse window'lar render edilmez ama element ağacı ve layout hesaplanır.

### 3.2 VisualTestAppContext

macOS özelinde, gerçek Metal compositor üzerinde test yapan bağlam:

```rust
pub fn new(platform: Rc<dyn Platform>) -> Self {
    Self::with_asset_source(platform, Arc::new(()))
}

/// Görsel testlerde SVG ikonların doğru render edilmesi gerektiğinde bunu kullan.
/// İkon render'ını etkinleştirmek için gerçek `Assets` struct'ını geçir.
pub fn with_asset_source(
    platform: Rc<dyn Platform>,
    varlik_kaynagi: Arc<dyn AssetSource>,
) -> Self {
    // ...
}
```

Kaynak kodundaki belge yorumu net bir kullanım rehberi sunar: SVG ikonların doğru render edilmesi gereken testlerde `with_asset_source(platform, Arc::new(Assets))` çağırılır. Aksi halde testin döndüğü ekran görüntüsü ikon yerine boş alan içerir.

Bu üç test bağlamının ortak deseni şudur: varlık kaynağı `Arc<dyn AssetSource>` olarak parametrize edilir; test yazarı senaryosuna göre `Arc::new(())` veya `Arc::new(Assets)` arasında seçim yapar. Varlık bağımlılığının opsiyonel tutulması, testlerin varlık boyutu değişimine duyarsız kalmasını sağlar.

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

## 5. Dosya sisteminden SVG yüklemek: `SvgAsset` ve `external_path`

Varlık hattının ikinci ana ihtiyacı, çalışma zamanında değişken dosya sistemi yollarından gelen varlıkları render etmektir. İkon tema extension'ları, kullanıcı SVG'leri ve dinamik üretilen ikonlar bu yoldan geçer.

`svg()` element'inin iki yol ayarlayıcısı vardır:

```rust
.path("icons/x.svg")              // binary'den
.external_path("/tmp/icon.svg")   // dosya sisteminden
```

Dosya sistemi yolu `SvgAsset` üzerinden geçer:

```rust
enum SvgAsset {}

impl Asset for SvgAsset {
    type Source = SharedString;
    type Output = Result<Arc<[u8]>, Arc<std::io::Error>>;

    fn load(
        kaynak: Self::Source,
        _cx: &mut App,
    ) -> impl Future<Output = Self::Output> + Send + 'static {
        async move {
            let baytlar = fs::read(Path::new(kaynak.as_ref())).map_err(|hata| Arc::new(hata))?;
            let baytlar = Arc::from(baytlar);
            Ok(baytlar)
        }
    }
}
```

Akış şudur:

```rust
// Element paint metodu içinden:
let Some(baytlar) = window
    .use_asset::<SvgAsset>(yol, cx)
    .and_then(|varlik| varlik.log_err())
else {
    return;
};

window
    .paint_svg(sinirlar, yol.clone(), Some(&baytlar), donusum, renk, cx)
    .log_err();
```

Üç ayrıntı dikkat çekicidir:

- **`SvgAsset` `cx.asset_source()`'a hiç bakmaz.** Doğrudan `fs::read` yapar. Yani dosya sistemi yolu binary varlık hattından bağımsızdır; `with_assets` çağrısı yapılmamış olsa bile çalışır.
- **`use_asset` cache'i sayesinde aynı dosya birden fazla kez okunmaz.** İlk render'da `fs::read` çalışır, sonraki render'larda cache'lenen Future'dan baytlar paylaşılır.
- **`paint_svg`'nin ikinci argümanı `Some(&baytlar)`** — Bu, varlık kaynağından okumaması gerektiğini söyler; doğrudan verilen baytlar üzerinden çalışır. Bu adım, binary yol ile dosya sistemi yolu arasındaki tek arayüz farkıdır.

---

## 6. Dosya sisteminden raster görsel yüklemek: `Resource::Path`

Raster görseller için yol `Resource` enum'unun üç varyantı üzerinden işler:

```rust
pub enum Resource {
    Uri(SharedUri),
    Path(Arc<Path>),
    Embedded(SharedString),
}
```

`img(Path::new("/tmp/ekran_goruntusu.png"))` çağrısı `Resource::Path` üretir. `ImageAssetLoader::load` bu varyantı senkron `fs::read` ile karşılar:

```rust
Resource::Path(yol) => fs::read(yol.as_ref())?,
```

`Resource::Uri` ise HTTP istemcisi üzerinden okur:

```rust
Resource::Uri(uri) => {
    let mut yanit = istemci.get(uri.as_ref(), ().into(), true).await
        .with_context(|| format!("görsel varlığı yüklenemedi: {uri:?}"))?;
    let mut govde = Vec::new();
    yanit.body_mut().read_to_end(&mut govde).await?;
    if !yanit.status().is_success() {
        // ... ImageCacheError::BadStatus
    }
    govde
}
```

Ve `Resource::Embedded` `cx.asset_source()` üzerinden gider:

```rust
Resource::Embedded(yol) => {
    let veri = varlik_kaynagi.load(&yol).ok().flatten();
    if let Some(veri) = veri {
        veri.to_vec()
    } else {
        return Err(ImageCacheError::Asset(...));
    }
}
```

Üç yol da aynı decode hattına akar (`image::guess_format`, format decoder, BGRA dönüşüm). Bu, varlık hattının tipik bir kararıdır: kaynak türü ne olursa olsun, decode adımı tek bir noktada birleşir.

### 6.1 HTTP istemcisi ve testler

Testlerde HTTP yolu önemli bir noktadır: hem `TestApp::build` hem `TestAppContext::build` `FakeHttpClient::with_404_response` kurarsın. Yani tüm HTTP görsel istekleri test ortamında 404 döndürür ve `Resource::Uri` varyantı kullanıldığında `BadStatus` hatası alırsın.

Bu davranış kasıtlıdır: testlerin ağa bağımlı olmaması gerekir. Eğer testte HTTP üzerinden görsel yüklenmesi gerekiyorsa `FakeHttpClient`'ın özel bir yanıt veren varyantı kullanırsın:

```rust
let istemci = FakeHttpClient::with_response_provider(|istek| {
    // ... özel yanıt
});
```

Bu, varlık hattının test ortamında nasıl sahte kaynakla çalışabileceğinin örneklerinden biridir.

---

## 7. Sahte AssetSource yazmak

Bazen testler için tamamen özel bir varlık kaynağı gerekir. Tipik senaryo: bir testin yalnızca belirli yollara yanıt vermesini istemek. Trait gereği iki metot implement edilir:

```rust
struct SahteVarlikKaynagi(HashMap<&'static str, &'static [u8]>);

impl AssetSource for SahteVarlikKaynagi {
    fn load(&self, yol: &str) -> Result<Option<Cow<'static, [u8]>>> {
        Ok(self.0.get(yol).map(|baytlar| Cow::Borrowed(*baytlar)))
    }

    fn list(&self, yol: &str) -> Result<Vec<SharedString>> {
        Ok(self.0
            .keys()
            .filter(|kayit_yolu| kayit_yolu.starts_with(yol))
            .map(|kayit_yolu| (*kayit_yolu).into())
            .collect())
    }
}

let sahte_kaynak = Arc::new(SahteVarlikKaynagi({
    let mut harita = HashMap::new();
    harita.insert("icons/test.svg", &include_bytes!("test.svg")[..]);
    harita
}));
let uygulama = TestApp::with_text_system_and_assets(metin_sistemi, sahte_kaynak);
```

Üç fayda:

- **Kontrollü erişim:** Yalnızca testte ihtiyaç duyulan dosyalar gömülür; binary'nin tamamı yüklenmez. Bu, derleme süresini ve test başlatma süresini kısaltır.
- **Hata enjeksiyonu:** Belirli bir yol için `Err` döndürmek mümkündür; bu, varlık yükleme hatası altındaki UI davranışını test etmeyi sağlar.
- **Determinizm:** Sahte kaynaklar deterministtir; binary varlıkların dosya sistemi durumuna göre değişmesi riski yoktur.

Bu desen GPUI'nin varlık hattının `dyn AssetSource` üzerinden parametrize edilmesinin pratik karşılığıdır. Trait object esnekliği test yazarına geniş bir alan sağlar.

---

## 8. Dış dosya yollarını güvenli yönetmek

Dosya sisteminden varlık okumak güvenlik ve sağlamlık açısından dikkat ister:

- **Symlink takibi.** `fs::read` symlink'leri takip eder; uygulamanın kabul ettiği dizinin dışına çıkan bir symlink hassas dosyalara erişim sağlayabilir. Kullanıcı sağladığı yolları canonicalize edip izinli kök altında doğrulamak gerekir.
- **Yol enjeksiyonu.** Kullanıcı girdisi `Resource::Embedded` olarak yorumlanırsa `../../etc/passwd` gibi yollar varlık kaynağına sızabilir. `RustEmbed::get` yalnızca include kalıplarıyla kapsanan varlık yollarını döndürür ve debug dosya sistemi kolunda canonical path kontrolü yapar; bu yüzden risk pratikte düşüktür. Buna karşılık `Resource::Path` için aynı garanti yoktur; açık doğrulama gerekir.
- **`is_uri` sezgisi.** `From<&str>` for `ImageSource` `is_uri(s)` ile URI ayrımı yapar; "C:\Users\..." gibi yollar `is_uri` true dönmediği için `Embedded` olarak yorumlanır. Bu yanlış yorumlama sessiz başarısızlığa yol açar (varlık bulunamaz). Yol olduğundan emin olunmayan girdi için `PathBuf::from(girdi).into()` ile dönüştürmek daha güvenlidir.

Bu kurallar varlık hattının "hız+esneklik" tasarımının kullanıcı koduna yansıyan boş kısımlarıdır; trait davranışı izin verir, doğrulama uygulamaya kalır.

---

## 9. Varlık hattını devre dışı bırakmak

Bazı durumlarda varlık hattının tamamen devre dışı bırakılması gerekir:

- **Headless CLI:** Komut satırı uygulaması GPUI'yi kullanır ama hiçbir window açmaz; SVG render veya font yükleme gerekmez. Bu senaryoda `Application::with_assets` çağrılmaz, boş `()` kalır.
- **Çok küçük binary'ler:** Varlık gömme binary boyutunu büyütür. Varlıkların dosya sisteminden okunduğu portatif binary'ler için `RustEmbed` kullanılmadan `AssetSource` implement edilebilir:

```rust
struct DosyaSistemiVarliklari {
    taban_dizin: PathBuf,
}

impl AssetSource for DosyaSistemiVarliklari {
    fn load(&self, yol: &str) -> Result<Option<Cow<'static, [u8]>>> {
        let tam_yol = self.taban_dizin.join(yol);
        match std::fs::read(&tam_yol) {
            Ok(baytlar) => Ok(Some(Cow::Owned(baytlar))),
            Err(hata) if hata.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(hata) => Err(hata.into()),
        }
    }

    fn list(&self, yol: &str) -> Result<Vec<SharedString>> {
        // ... walkdir veya benzer yardımıyla özyinelemeli listeleme
        todo!()
    }
}
```

Bu desen, üretim binary'sinin varlıkları gömülü taşırken testlerin veya alternatif binary'lerin dosya sisteminden okumasını sağlar. Aynı `cx.asset_source()` yüzeyinden çalıştığı için diğer kod yolları değişmez.

---

## 10. Varlık hattının test edilebilirlik özeti

`AssetSource` trait'inin esnek tasarımı dört farklı test/dış senaryoyu birden destekler:

| Senaryo | AssetSource türü | Test bağlamı |
|---------|------------------|--------------|
| Varlık gerektirmeyen makro testleri | `Arc::new(())` | `TestAppContext` (`#[gpui::test]`) |
| Varlık gerektirmeyen sade testler | `Arc::new(())` | `TestApp::new` veya `TestApp::with_text_system` |
| Gerçek varlıklarla metin testi | `Arc::new(Assets)` | `TestApp::with_text_system_and_assets` |
| Sahte varlıklarla birim testi | `Arc::new(SahteVarlikKaynagi(...))` | `TestApp::with_text_system_and_assets` |
| Dosya sisteminden okuyan portatif binary | `Arc::new(DosyaSistemiVarliklari { ... })` | `Application::with_assets` (üretim) |
| Görsel snapshot testi | `Arc::new(Assets)` | `VisualTestAppContext::with_asset_source` |
| Headless CI render testi | `Arc::new(Assets)` veya sahte kaynak | `HeadlessAppContext::with_asset_source` |

Bu çoklu kullanım modelinin gerçekleşebilmesi, `AssetSource` trait'inin minimal arayüzünden kaynaklanır. Trait yalnızca iki metot tanımlar; her implementasyon kendi maliyet profili ve davranışını seçer. Bu, varlık altyapısının "uzak ya da yakın, gömülü ya da dosya sistemi, üretim ya da test" sorularını tek bir kod yolundan cevaplayabilmesinin sebebidir.

---
