# Test, headless ve dış varlık kaynakları

Bu bölüm, üretim binary'si dışındaki varlık senaryolarını ele almaktadır. GPUI test ortamları (`TestApp`, `TestAppContext`, `HeadlessAppContext`, `VisualTestAppContext`) varlık hattını isteğe bağlı (opsiyonel) kabul eder; bu durum, testlerin varlık bağımlılığı taşımadan hızlıca çalışmasını mümkün kılar. Buna karşın, varlık çizimi (render) içeren testler için (örneğin SVG ikonların gerçekten çizildiği görsel testler) gerçek `Assets` struct yapısının test ortamına aktarılması gerekir. Bu iki gereksinim arasındaki ince çizgiyi netleştirmek, 'neden bazı testler varlık gerektirirken bazıları buna ihtiyaç duymaz?' sorusunu yanıtlar. Ayrıca dosya sistemindeki SVG/PNG dosyalarının çalışma zamanına nasıl dahil edildiği (`SvgAsset`, `Resource::Path`) bu bölümde ele alınır; böylece uygulamanın binary varlıkların yanı sıra dış kaynaklı varlıkları da bilinçli şekilde yönetebilmesinin önü açılır.

---

## 1. Varlık gerektirmeyen testler: `()` boş AssetSource

Çoğu GPUI testi varlık hattına ihtiyaç duymaz. Layout testleri, olay dağıtım testleri veya entity testleri gibi senaryolar font ve ikon yüklemesi yapılmadan da çalışabilir. Bu durumlarda `App` boş bir `AssetSource` ile kurulur:

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

Bu davranışın test ortamındaki karşılığı, tüm `cx.asset_source().load(yol)` çağrılarının `Ok(None)` dönmesi, tüm `list` çağrılarının ise boş bir vektör üretmesidir. Dolayısıyla SVG render hattı çağrıldığında byte verisi bulamaz ve hata günlüğü (log) oluşturur; font yükleyici hiçbir font bulamaz; tema yükleyici ise gömülü temaları yükleyemez. Testlerin etki alanı bu sayede fiziksel varlıkların mevcut olmasına bağımlı olmaktan çıkar.

`()` `Sized` ve `Sync + Send` olduğundan `Arc::new(())` neredeyse maliyetsizdir (boş tip için Rust derleyicisi optimize eder). Başarım açısından "boş kaynak" pratikte sıfır ek yüktür.

---

## 2. `TestApp::with_text_system_and_assets`

GPUI bünyesinde iki farklı test yüzeyi yan yana yer alır. `#[gpui::test]` makrosunun sağladığı klasik `TestAppContext` yapısı, `TestAppContext::build` içerisinde varsayılan olarak boş `Arc::new(())` varlık kaynağı ile kurulur. Daha yeni ve sade bir test API'si sunan `TestApp` ise, gerçek veya sahte bir varlık kaynağı enjekte etmek için bağımsız bir yapıcı (constructor) sunar:

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
        Self { uygulama }
    }
}
```

Bu nedenle şu üç ayrımın doğru yapılması önem arz eder:

- **`TestAppContext`** — Makro tabanlı testlerin varsayılan bağlamıdır; varlık kaynağı boş gelir ve özel varlık kaynağı almak için public bir constructor sunmaz.
- **`TestApp::with_text_system`** — Metin shaping testi için gerçek `PlatformTextSystem` yüklenir ama varlık kaynağı boş kalır. Tipik kullanım: metin layout'unu doğrulayan ama ikon içermeyen testler.
- **`TestApp::with_text_system_and_assets`** — Hem metin sistemi hem varlık kaynağı gerçek yüklenir. Tipik kullanım: SVG ikonları render eden, font dosyalarını okuyan testler.

Son yapıcı metodun kullanılması, testlerin doğrudan `assets` crate'ine bağımlılık eklemesini gerektirir; bu yaklaşım Zed test kodlarında genellikle tercih edilir:

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
        Self { ... }
    }
}
```

Bu üç yapıcının arasındaki ilişki şu şekildedir: `new` metodu `()` boş kaynağıyla başlatır; `with_asset_source` özelleştirilmiş bir varlık kaynağı alır; `with_platform` ise bunlara ek olarak bir headless renderer fabrikası kabul eder. Renderer fabrikası `None` döndürdüğünde pencereler (window'lar) çizilmez ancak element ağacı ve layout hesaplamaları tamamlanır.

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
    Self { ... }
}
```

Kaynak kodundaki belge yorumu net bir kullanım rehberi sunar: SVG ikonların doğru render edilmesi gereken testlerde `with_asset_source(platform, Arc::new(Assets))` çağrılır. Aksi halde testin döndüğü ekran görüntüsü ikon yerine boş alan içerir.

Bu üç test bağlamının ortak deseni şudur: varlık kaynağı `Arc<dyn AssetSource>` olarak parametrize edilir; test yazarı senaryosuna göre `Arc::new(())` veya `Arc::new(Assets)` arasında seçim yapar. Varlık bağımlılığının opsiyonel tutulması, testlerin varlık boyutu değişimine duyarsız kalmasını sağlar.

---

## 4. `Assets::load_test_fonts` ile minimum font kümesi

Test ortamında metin şekillendirmesi (shaping) yapılması hedeflendiği halde tüm fontların yüklenmesinden kaçınılıyorsa, kaynak kodda test yardımcısı (test helper) olarak `Assets::load_test_fonts` çağrısı gerçekleştirilir. Zed bünyesindeki bu yardımcı işlev, fail-fast test varsayımıyla kurgulanmıştır; aynı akışın uygulama kodunda hata yayacak şekildeki karşılığı şu şekilde ifade edilebilir:

```rust
pub fn load_test_fonts_sonuc(&self, cx: &App) -> anyhow::Result<()> {
    let font = self
        .load("fonts/lilex/Lilex-Regular.ttf")?
        .with_context(|| "Lilex test fontu varlık paketinde bulunamadı")?;

    cx.text_system().add_fonts(vec![font])
}
```

Bu metot yalnızca `Lilex-Regular.ttf` dosyasını yükler. Üç gerekçe vardır:

- **Minimum maliyet:** Test başlatılırken tüm font ailelerini yüklemek hem CPU hem bellek harcar. Tek bir Lilex regular varyantı çoğu yazı testi için yeterlidir.
- **Monospace garantisi:** Lilex monospace font'tur; karakter genişlikleri tutarlıdır. Bu, snapshot testlerinde piksel düzeyinde tutarlılık sağlamak için kritiktir.
- **Lisans sürtünmesi yok:** Lilex OFL ile dağıtılır; test fixture'ları için kullanılırken ek lisans dikkati gerekmez.

`load_test_fonts` çağrısı `Application::with_assets(Assets)` adımının ardından gerçekleştirilir. Çoğu test bağlamında bu adım manuel olarak dahil edilir, otomatik olarak yürütülmez; font kullanımı gerektirmeyen testlerde bu yükleme adımı tamamen atlanır.

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

- **`SvgAsset` yapısı `cx.asset_source()` arayüzünü kullanmaz:** Doğrudan senkron `fs::read` işlemini yürütür. Yani dosya sistemi yolu binary varlık hattından bağımsızdır; `with_assets` çağrısı yapılmamış olsa dahi çalışır.
- **`use_asset` cache mekanizması sayesinde aynı dosya mükerrer şekilde okunmaz:** İlk çizim (render) anında `fs::read` çalışırken, sonraki render süreçlerinde önbelleğe alınan Future üzerinden ham byte verileri paylaşılır.
- **`paint_svg` işlevinin üçüncü argümanı `Some(&baytlar)`:** `paint_svg(bounds, path, data, transformation, color, cx)` imzasında `data` üçüncü konumsal argümanı temsil eder. Bu argüman dolu geldiğinde `paint_svg` varlık kaynağından okuma yapmaz; doğrudan verilen byte'lar üzerinden çizim gerçekleştirir. Bu adım, binary yol ile dosya sistemi yolu arasındaki yegane arayüz farkıdır.

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

Üç yol da aynı decode hattına akar (`image::guess_format`, format decoder, BGRA dönüşümü). Bu, varlık hattının tipik bir kararıdır: kaynak türü ne olursa olsun, decode adımı tek bir noktada birleşir.

### 6.1 HTTP istemcisi ve testler

Testlerde HTTP yolu kritik bir rol üstlenir: hem `TestApp::build` hem de `TestAppContext::build` süreçlerinde `FakeHttpClient::with_404_response` yapılandırılır. Yani tüm HTTP görsel istekleri test ortamında 404 kodu döndürür ve `Resource::Uri` varyantı kullanıldığında `BadStatus` hatasıyla karşılaşılır.

Bu davranış kasıtlıdır: test süreçlerinin ağa bağımlı olmaması hedeflenir. Eğer test kapsamında HTTP üzerinden görsel yüklenmesi gerekiyorsa, `FakeHttpClient::create` yardımıyla özel yanıt döndüren bir handler kurulur:

```rust
let istemci = FakeHttpClient::create(|_istek| async move {
    Ok(Response::builder()
        .status(200)
        .body(AsyncBody::from("<svg></svg>"))?)
});
```

Bu, varlık hattının test ortamında nasıl sahte kaynakla çalışabileceğinin örneklerinden biridir.

---

## 7. Sahte AssetSource yazmak

Bazen testler için tamamen özel bir varlık kaynağına ihtiyaç duyulabilir. Tipik senaryo, bir testin yalnızca belirli dosya yollarına yanıt vermesinin hedeflenmesidir. Trait gereği iki metodun implement edilmesi gerekir:

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
- **Hata enjeksiyonu:** Belirli bir dosya yolu için `Err` döndürmek mümkündür; bu, varlık yükleme hatası altındaki kullanıcı arayüzü (UI) davranışlarını test etmeyi sağlar.
- **Determinizm:** Sahte kaynaklar deterministtir; gömülü varlıkların dosya sistemi durumuna göre değişkenlik göstermesi riski bulunmaz.

Bu desen GPUI'nin varlık hattının `dyn AssetSource` üzerinden parametrize edilmesinin pratik karşılığıdır. Trait object esnekliği test yazarına geniş bir alan sağlar.

---

## 8. Dış dosya yollarını güvenli yönetmek

Dosya sisteminden varlık okumak güvenlik ve sağlamlık açısından dikkat ister:

- **Symlink takibi:** `fs::read` symlink'leri (sembolik bağları) takip eder; uygulamanın kabul ettiği dizinin dışına çıkan bir symlink, hassas dosyalara yetkisiz erişim sağlayabilir. Kullanıcının sağladığı dosya yollarının canonicalize edilip (mutlaklaştırılıp) izin verilen bir kök dizin altında doğrulanması gerekir.
- **Yol enjeksiyonu:** Kullanıcı girdisi `Resource::Embedded` olarak yorumlandığında, `../../etc/passwd` gibi dosya yolları varlık kaynağına sızabilir. `RustEmbed::get` yalnızca include kalıplarıyla kapsanan varlık yollarını döndürdüğü için bu risk pratikte son derece düşüktür. Mevcut yapılandırmada `debug-embed` özelliği kapalı olduğundan debug derlemelerde `get` metodu varlıkları doğrudan dosya sisteminden okur ve bu kolda canonical path (mutlak yol) kontrolleri devreye girer; release derlemelerinde ise varlıklar binary içerisine gömülü olduğundan bu dosya sistemi kontrol yolu hiç çalıştırılmaz. Buna karşın, `Resource::Path` için aynı koruma garantisi yoktur ve açık bir doğrulama yapılması gerekir.
- **`is_uri` sezgisi:** `From<&str> for ImageSource` dönüşümü `is_uri(s)` yardımıyla URI ayrımı gerçekleştirir; bu işlev `url::Url::from_str` çağrısı başarılı olduğunda `true` döner. Windows ortamındaki `C:\Users\...\icon.svg` gibi dosya yollarında, sürücü harfi olan `c:` ifadesi bir URL şeması sanılarak ayrıştırma işlemi `Ok` dönebilir ve `is_uri` `true` verebilir. Bu yüzden böyle bir girdi `Embedded` yerine `Resource::Uri` olarak yorumlanır; sonuçta geçersiz bir URI'ye dönüşerek yüklenemez. Girdinin dosya sistemi yolu olma ihtimalinin bulunduğu durumlarda string yerine `PathBuf::from(girdi).into()` ile dönüşüm yapılması çok daha güvenlidir.

---

## 9. Varlık hattını devre dışı bırakmak

Bazı durumlarda varlık hattının tamamen devre dışı bırakılması gerekir:

- **Headless CLI:** Komut satırı uygulaması GPUI'yi kullanır ancak hiçbir pencere (window) açmaz; dolayısıyla SVG render veya font yüklemesi gerekmez. Bu senaryoda `Application::with_assets` çağrısı yapılmaz ve varsayılan boş `()` kaynağı korunur.
- **Düşük boyutlu binary'ler:** Varlık gömme işlemleri binary boyutunu artırır. Varlıkların doğrudan dosya sisteminden okunduğu taşınabilir (portatif) binary'ler için, `RustEmbed` kullanmadan bağımsız bir `AssetSource` implementasyonu gerçekleştirilebilir:

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
        let baslangic = self.taban_dizin.join(yol);
        let mut bekleyenler = vec![baslangic];
        let mut yollar = Vec::new();

        while let Some(dizin) = bekleyenler.pop() {
            for kayit in std::fs::read_dir(&dizin)? {
                let kayit = kayit?;
                let tam_yol = kayit.path();
                if tam_yol.is_dir() {
                    disabled_dizin_tarama(tam_yol, &mut bekleyenler);
                } else if let Ok(goreli_yol) = tam_yol.strip_prefix(&self.taban_dizin) {
                    yollar.push(goreli_yol.to_string_lossy().replace('\\', "/").into());
                }
            }
        }

        Ok(yollar)
    }
}

fn disabled_dizin_tarama(tam_yol: PathBuf, bekleyenler: &mut Vec<PathBuf>) {
    bekleyenler.push(tam_yol);
}
```

Bu desen, üretim binary'sinin varlıkları gömülü olarak taşırken testlerin veya alternatif binary'lerin dosya sisteminden okuma yapmasına imkan tanır. Aynı `cx.asset_source()` yüzeyinden çalıştığı için diğer tüm kod yolları değişmeden korunur.

---

## 10. Varlık hattının test edilebilirlik özeti

`AssetSource` trait'inin esnek tasarımı birden fazla test ve dış kaynak senaryosunu destekler:

| Senaryo | AssetSource türü | Test bağlamı |
|---------|------------------|--------------|
| Varlık gerektirmeyen makro testleri | `Arc::new(())` | `TestAppContext` (`#[gpui::test]`) |
| Varlık gerektirmeyen sade testler | `Arc::new(())` | `TestApp::new` veya `TestApp::with_text_system` |
| Gerçek varlıklarla metin testi | `Arc::new(Assets)` | `TestApp::with_text_system_and_assets` |
| Sahte varlıklarla birim testi | `Arc::new(SahteVarlikKaynagi(...))` | `TestApp::with_text_system_and_assets` |
| Dosya sisteminden okuyan portatif binary | `Arc::new(DosyaSistemiVarliklari { ... })` | `Application::with_assets` (üretim) |
| Görsel snapshot testi | `Arc::new(Assets)` | `VisualTestAppContext::with_asset_source` |
| Headless CI render testi | `Arc::new(Assets)` veya sahte kaynak | `HeadlessAppContext::with_asset_source` |

Bu çoklu kullanım modelinin hayata geçirilebilmesi, `AssetSource` trait'inin minimal arayüz tasarımından kaynaklanır. Trait yalnızca iki metot tanımlar; her bir implementasyon kendi maliyet profilini ve davranış biçimini seçer. Bu sayede varlık altyapısı; 'uzak veya yakın, gömülü veya dosya sistemi, üretim veya test' gibi tüm farklı senaryoları tek bir kod yolu üzerinden yanıtlayabilmektedir.

---
