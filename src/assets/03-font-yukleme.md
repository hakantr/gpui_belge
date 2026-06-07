# Fontların paketlenmesi ve yüklenmesi

Bu bölüm, varlık altyapısının ilk büyük tüketicisi olan font yükleme yolunu ele almaktadır. Font yükleme süreci üç farklı sistemi eş zamanlı olarak besler: GPUI'nin metin şekillendirme (shaping) sistemi (`TextSystem`), SVG render hattının USVG fontdb veritabanı ve test ortamlarında kullanılan minimum test font kümesi. Bu üç sistem de aynı `AssetSource` yüzeyinden okuma yapar; fakat hedef tüketici yapıları farklıdır. Bu farklılığı anlamak, 'neden iki farklı yerde font yükleniyor?' sorusunun cevabını verir ve uygulamaya yeni font eklenirken hangi noktaların güncellenmesi gerektiğini netleştirir.

![Font Yükleme Akışı](images/font-yukleme-akisi.svg)

---

## 1. Font klasörünün yapısı

Zed iki font ailesini gömülü olarak taşır:

```text
assets/fonts/
├── ibm-plex-sans/
│   ├── IBMPlexSans-Regular.ttf
│   ├── IBMPlexSans-Italic.ttf
│   ├── IBMPlexSans-SemiBold.ttf
│   ├── IBMPlexSans-SemiBoldItalic.ttf
│   └── license.txt
└── lilex/
    ├── Lilex-Regular.ttf
    ├── Lilex-Bold.ttf
    ├── Lilex-Italic.ttf
    ├── Lilex-BoldItalic.ttf
    └── OFL.txt
```

**Karar:** Uygulamada iki ayrı font ailesi taşınır; bunlardan biri sans-serif (`IBM Plex Sans`), diğeri ise monospace (`Lilex`) karakterdedir. Her aileye ait dört temel varyant (regular, italic, bold, bold italic) bağımsız `.ttf` dosyaları olarak saklanır. Her klasörde bir lisans dosyasının bulundurulması zorunludur; OFL (Open Font License) bu lisans metinlerinin font dosyalarıyla birlikte taşınmasını şart koşar.

**Genişleme:** Yeni bir font eklenmesi durumunda yapılması gereken üç adım mevcuttur:

1. `.ttf` uzantılı dosya `fonts/<aile_adi>/` dizini altına yerleştirilir.
2. İlgili aileye ait lisans dosyası aynı klasör içine eklenir.
3. `Assets` struct yapısındaki `#[include = "fonts/**/*"]` direktifi rekürsif (recursive) nitelikte olduğundan herhangi bir ek kod değişikliği gerektirmez; dosyalar `RustEmbed` erişim kümesine otomatik olarak dahil edilir. Release/debug-embed derlemelerinde binary içerisine gömülen bu varlıklar, normal debug derlemelerinde ise aynı yollar üzerinden doğrudan dosya sisteminden okunur.

Dolayısıyla font ekleme süreci sadece bir dosya kopyalama işleminden ibarettir; kaynak kodda string referansı veya enum varyantı eklenmesi ihtiyacını doğurmaz. Bu davranış modeli, sonraki bölümlerde ele alınacak olan ikon ve ses sistemlerinden ayrışır: oralarda her yeni dosya için enum varyantı tanımlanması zorunludur.

---

## 2. `load_embedded_fonts`: ana font yükleme yolu

Zed'in `zed` crate'inde konumlanan font yükleyicisi de aynı list+load invariant'ını (değişmezini) uygular. Güncel kaynak kodlarında bu işlem background executor kapsamında fail-fast yöntemleriyle yürütülür; bu rehberde ise aynı akışın `Result` döndüren eşdeğer yapısı gösterilmektedir:

```rust
use anyhow::Context as _;

fn load_embedded_fonts(cx: &App) -> anyhow::Result<()> {
    let varlik_kaynagi = cx.asset_source();
    let font_yollari = varlik_kaynagi.list("fonts")?;
    let mut gomulu_fontlar = Vec::new();

    for font_yolu in &font_yollari {
        if !font_yolu.ends_with(".ttf") {
            continue;
        }

        let font_baytlari = varlik_kaynagi
            .load(font_yolu)?
            .with_context(|| format!("font varlığı bulunamadı: {font_yolu}"))?;
        gomulu_fontlar.push(font_baytlari);
    }

    cx.text_system()
        .add_fonts(gomulu_fontlar)?;
    Ok(())
}
```

Akış dört adımdan oluşur:

1. **`varlik_kaynagi.list("fonts")`** — Recursive listeleme yapılır; `fonts/ibm-plex-sans/...` ve `fonts/lilex/...` altındaki tüm dosyalar tek listede toplanır.
2. **`.ttf` filtresi** — `license.txt` and `OFL.txt` gibi dosyalar dışlanır. Filtre yalnızca path uzantısına bakar; klasör adına bakmaz. Yeni bir font klasörü eklendiğinde bu filtre otomatik genişler.
3. **List+load invariant'ı:** Kaynak kod yapısı önce `Result`, ardından `Option` katmanını çözer. İlk katman okuma hatalarını, ikinci katman ise 'varlığın mevcut olduğu' garantisini temsil eder. `list` çağrısından dönen bir dosya yolunun `load` ile sorunsuzca okunabiliyor olması beklenir; bu kural (invariant) bozulduğunda varlık paketi veya `RustEmbed` eşleşmelerinin gözden geçirilmesi gerekir.
4. **`cx.text_system().add_fonts(...)`:** Elde edilen tüm byte verileri tek bir çağrı ile `TextSystem`'e aktarılır. Bu işlem fontları platformun yerel metin sistemine (CoreText, DirectWrite, freetype) kaydeder; böylece uygulama bu adımdan sonra `font_family("IBM Plex Sans")` veya `font_family("Lilex")` gibi aile adlarıyla bu fontları doğrudan kullanabilir.

**Çağrı noktası:** `load_embedded_fonts(cx)` işlevi, Zed'in uygulama kurulum süreçlerinde herhangi bir pencere açılmadan önce çağrılır. Güncel `main.rs` içerisinde `Application::with_assets(Assets)` en başta yapılandırılır; font yükleme ise diğer global init (başlatma) işlemlerinden sonra, fakat editör veya workspace pencereleri açılmadan önce yürütülür. Buradaki en kritik gereksinim şudur: varlık kaynağı kurulmadığı takdirde `cx.asset_source()` boş `()` döneceğinden `list("fonts")` sonuç üretemez; eğer pencere açıldıktan sonra bu yükleme yapılırsa ilk karede (frame) font varsayılan yedeğe (fallback) düşebilir.

---

## 3. `Assets::load_fonts`: kütüphane içi yardımcı

`assets` crate'i aynı işi struct üzerinde method olarak da sunar:

```rust
impl Assets {
    pub fn load_fonts(&self, cx: &App) -> anyhow::Result<()> {
        let font_yollari = self.list("fonts")?;
        let mut gomulu_fontlar = Vec::new();
        for font_yolu in font_yollari {
            if font_yolu.ends_with(".ttf") {
                let font_baytlari = cx
                    .asset_source()
                    .load(&font_yolu)?
                    .with_context(|| format!("font varlığı bulunamadı: {font_yolu}"))?;
                gomulu_fontlar.push(font_baytlari);
            }
        }

        cx.text_system().add_fonts(gomulu_fontlar)
    }
}
```

Bu metot ile `main.rs` kapsamındaki `load_embedded_fonts` arasında iki belirgin fark mevcuttur. Birincisi **çağrı konumu**dur: `load_fonts` doğrudan `Assets` üzerinde konumlanan bir kütüphane yardımcısı iken, `load_embedded_fonts` Zed'in uygulama girişinde aynı list+load mantığını yürütür. İkincisi ise **okuma biçimi**dir: `load_embedded_fonts` font dosyalarını `background_executor().scoped(...)` ile paralel olarak okuyup her birini ayrı bir asenkron görev içinde yüklerken; `Assets::load_fonts` dosyaları sıralı bir `for` döngüsüyle tek tek işler. Alternatif binary veya özel bir örnek uygulama tarafında `Application::with_assets(Assets)` çağrısının ardından `Assets.load_fonts(cx)?` ifadesinin kullanılması yeterli olacaktır.

`Assets::load_fonts` işlevi özellikle bu ikinci senaryo için tasarlanmıştır: bir kütüphane veya alternatif binary yapısı, `Assets` struct'ını kendi kuruluş hattında doğrudan çağırmak isteyebilir. O durumlarda `Application::with_assets(Assets)` çağrısının ardından tek satırlık `Assets.load_fonts(cx)?` çağrısı yeterli kabul edilir.

---

## 4. Test ortamı için `load_test_fonts`

`Assets` struct'ı test senaryoları için ayrı bir yardımcı da sağlar:

```rust
use anyhow::Context as _;

pub fn load_test_fonts(&self, cx: &App) -> anyhow::Result<()> {
    let font_baytlari = self
        .load("fonts/lilex/Lilex-Regular.ttf")?
        .with_context(|| "test fontu bulunamadı: fonts/lilex/Lilex-Regular.ttf")?;

    cx.text_system().add_fonts(vec![font_baytlari])
}
```

Bu metot yalnızca tek bir font yükler: `Lilex-Regular.ttf`. Gerekçe şudur: testlerde metin shaping davranışını doğrulamak için en az bir monospace fontu olmalıdır, fakat tüm fontları yüklemek başlatma süresini artırır. Tek bir Lilex regular varyantı çoğu yazı testi için yeterlidir.

**Kullanım yeri:** GPUI'nin `TestApp`, `TestAppContext`, `HeadlessAppContext` veya `VisualTestAppContext` kurulum süreçlerinde bu metot isteğe bağlı (opsiyonel) olarak çağrılır. Test senaryosu font kullanımına ihtiyaç duymuyorsa (örneğin sadece kaba bir layout testi yapılıyorsa) bu metot atlanabilir; o durumda `TextSystem` font listesi boş kalacağından metin elementlerinin boyutları sıfır olarak hesaplanır.

---

## 5. USVG fontdb entegrasyonu

`SvgRenderer` yapısı, SVG dosyalarındaki `<text>` etiketlerini doğru şekilde render edebilmek amacıyla bağımsız bir font veritabanı yönetir. Bu veritabanı `usvg::fontdb::Database` türündedir ve iki farklı kaynaktan beslenir: sistemde kurulu fontlar ve Zed'in gömülü fontları. Sistem fontları, `LazyLock` ile bir defa kurulan paylaşımlı bir `SYSTEM_FONT_DB` veritabanında saklanır; bu veritabanı programın ömrü boyunca yalnızca bir kez `load_system_fonts()` çağrısıyla doldurulur. Zenginleştirme yapılması gerektiğinde bu paylaşımlı veritabanı **klonlanır** ve gömülü fontlar bu klonun üzerine eklenir; böylece ana paylaşımlı sistem veritabanı mutasyona uğramadan temiz kalır:

```rust
fn load_bundled_fonts(varlik_kaynagi: &dyn AssetSource, db: &mut usvg::fontdb::Database) {
    let font_yollari = [
        "fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf",
        "fonts/lilex/Lilex-Regular.ttf",
    ];
    for yol in font_yollari {
        match varlik_kaynagi.load(yol) {
            Ok(Some(veri)) => db.load_font_data(veri.into_owned()),
            Ok(None) => log::warn!("Yerleşik font bulunamadı: {yol}"),
            Err(hata) => log::warn!("Yerleşik font yüklenemedi {yol}: {hata}"),
        }
    }
}
```

Güncel Zed kodunda bu zenginleştirilmiş fontdb, `SvgRenderer::new` anında değil ilk SVG render ihtiyacında lazy olarak hazırlanır. Böylece SVG render etmeyen testler sistem font veritabanını derin kopyalama maliyetini ödemez.

Burada dikkat edilmesi gereken üç ayrıntı vardır:

- **Sabit kodlu path listesi:** USVG yalnızca iki regular varyantı yükler. Bold, italic ve bold-italic gibi varyantlar dahil edilmez. Gerekçe: SVG'lerde nadiren bold metin bulunur; pratikte regular varyantlar render kalitesi için yeterlidir ve veritabanı boyutu küçük kalır.
- **Hata toleransı:** `load` çağrısı `None` ya da `Err` döndürürse uyarı log'lanır, fakat fail-fast çalışmaz. Bu davranış GPUI'yi varlık bağımlılığından koruyan bir tampon görevi yapar; varlık hattı kurulu olmasa bile SVG render hattı çalışmaya devam eder, sadece yerleşik font'lar olmayacaktır.
- **Sistem fontları ile birleştirme:** `load_bundled_fonts` işlevi doğrudan paylaşılan `SYSTEM_FONT_DB` üzerinde değil, onun bir klonu üzerinde çalışır. Sistemde kurulu fontlar bu paylaşımlı veritabanına bir kez `load_system_fonts()` ile yüklenir; her zenginleştirmede veritabanı klonlanır ve bundled fontlar klona eklenir. Dolayısıyla bundled fontlar sistem fontlarının üzerine biner; çakışma durumunda hangi varyantın seçileceği doğrudan `usvg` kütüphanesinin kendi önceliklendirme kurallarına bağlı kalır.

### 5.1 Generic family yedeği

USVG fontdb'nin ilginç bir davranışı vardır: generic CSS aileleri (`sans-serif`, `serif`, `monospace`, `cursive`, `fantasy`) varsayılan olarak Microsoft font'larına (Arial, Times New Roman) bağlanır. Bu font'lar çoğu Linux dağıtımında kurulu olmadığından, fontconfig bu varsayılanları düzeltmediği durumda generic aile `query` çağrıları `None` döner. Linux sistemlerinde fontconfig genellikle bunları doldurur ama her zaman güvenilir değildir. Zed bu boşluğu kapatmak için `fix_generic_font_families` fonksiyonunu kullanır:

```rust
let aileler_ve_yedekler: &[(Family<'_>, &str)] = &[
    (Family::SansSerif, "IBM Plex Sans"),
    (Family::Serif, "IBM Plex Sans"),       // Zed serif font taşımıyor; sans yedeği
    (Family::Monospace, "Lilex"),
    (Family::Cursive, "IBM Plex Sans"),
    (Family::Fantasy, "IBM Plex Sans"),
];
```

Her generic aile için bir yedek ad belirlenir. Veritabanında o ailenin bir sürümü zaten mevcutsa herhangi bir yedek uygulanmaz; aksi takdirde `db.set_sans_serif_family(name)` gibi metotlarla ad ataması gerçekleştirilir. Bu sayede SVG içinde `font-family="sans-serif"` belirteci taşıyan bir `<text>` öğesi hiçbir Linux dağıtımında fontsuz kalarak bozulmaz.

**Önemli mantık:** Serif font Zed tarafından paketlenmediği için Serif → IBM Plex Sans yedeği kasıtlıdır. SVG render çıktısı serif beklenen yerde sans-serif görünür; bu, "hiç render olmamak" yerine "yakın eşdeğer ile render olmak" kararıdır.

### 5.2 Emoji font seçimi

USVG'nin font seçim hattı ayrıca emoji karakterleri için özel bir yol içerir:

```rust
#[cfg(target_os = "macos")]
const EMOJI_FONT_FAMILIES: &[&str] = &["Apple Color Emoji", ".AppleColorEmojiUI"];

#[cfg(target_os = "windows")]
const EMOJI_FONT_FAMILIES: &[&str] = &["Segoe UI Emoji", "Segoe UI Symbol"];

#[cfg(any(target_os = "linux", target_os = "freebsd"))]
const EMOJI_FONT_FAMILIES: &[&str] = &[
    "Noto Color Emoji", "Emoji One", "Twitter Color Emoji", "JoyPixels",
];
```

`is_emoji_presentation(ch)` `true` döndüğünde, `select_emoji_font` bu listedeki ilk uygun aile adını bulup `id` değerini geri verir. Emoji fontları Zed binary içerisine gömülmez; sistem fontlarının kullanılması beklenir. Bu karar binary boyutu için kritik öneme sahiptir: Apple Color Emoji tek başına 100 MB'tan fazla alan kapladığından binary'ye gömülmesi pratik değildir.

---

## 6. `add_fonts` çağrısının `TextSystem` tarafındaki etkisi

`cx.text_system().add_fonts(vec)` çağrısı font byte'larını platforma özgü metin sistemine (macOS CoreText, Windows DirectWrite, Linux freetype) verir. Detaylar metin sistemi bölümünde işlenir; bu bölüm için bilinmesi gereken üç davranış vardır:

1. **Idempotent değildir:** Aynı font ikinci kez eklenirse hiçbir platform "zaten var" cevabı döndürmez; her platform tekrar çağrıda font'u koşulsuz yeniden ekler. macOS, Windows ve Linux tarafının üçü de gelen byte'ları doğrudan platform font veritabanına yeniden kaydeder, var olup olmadığını sorgulamaz. Bu yüzden `add_fonts` tek seferlik çağrılmak üzere tasarlanmıştır.
2. **Lifetime:** Byte verileri `Cow<'static>` biçiminde gelir; buradaki `'static` ömrü iki farklı sahiplik durumunu kapsar. `Cow::Borrowed` durumu release embed yoludur: byte'lar binary içerisine gömülmüştür, binary'nin statik veri segmentinde durur ve çalışma zamanında ek bir bellek ayrımına ihtiyaç duymaz. `Cow::Owned` durumu ise dosya sisteminden okuma yolunu temsil eder: byte'lar heap üzerinde dinamik olarak ayrılır ve `Arc` ile sarılarak font verisi olarak bellekte tutulur. Her iki durumda da veriler uygulama ömrü boyunca canlı kalır; yegane fark verinin nerede depolandığıdır.
3. **Çağrı zamanı:** `add_fonts` çağrısının **pencere açılmadan önce** yapılması gerekir; aksi takdirde ilk karede (frame) font bulunamadığı için varsayılan yedeğe düşülür ve metin hedeflenen fontla çizilemez. Zed bu sebeple font yükleme işlemlerini `Application::with_assets` çağrısının ardından, fakat editör ve çalışma alanı (workspace) pencereleri açılmadan önce tetikler.

---

## 7. Pratik akış özeti

Font sisteminin bütününü tek bir akış olarak okumak gerekirse:

```text
assets/fonts/<aile>/*.ttf
       │
       ▼ (RustEmbed erişim kümesi; release'te embed, debug'da dosya sistemi)
Assets struct
       │
       ▼ (Application::with_assets)
App.asset_source: Arc<dyn AssetSource>
       │
       ├──► load_embedded_fonts ──► cx.text_system().add_fonts ──► GPUI metin sistemi
       │
       └──► SvgRenderer::new ──► load_bundled_fonts ──► usvg::fontdb::Database
                                                       └──► fix_generic_font_families
                                                       └──► select_emoji_font (sistem font'ları)
```

İki tüketici (`TextSystem` ve USVG fontdb) aynı `.ttf` dosyalarını farklı yollardan yükler. Bu durum kod tabanındaki tekrarın temel sebebidir: GPUI'nin kendi metin şekillendirmesi (shaping) için ayrı bir kütüphane, SVG render hattı için ise farklı bir kütüphane kullanılır ve bu iki kütüphane font veritabanlarını ortak yönetmez. Bunun pratik sonucu şudur: uygulamaya yeni bir font ailesi eklemek isteyen bir geliştirici, hem `TextSystem`'in görebilmesi için `assets/fonts/` dizini altına dosyayı yerleştirir, hem de SVG renderlarında bu fontun desteklenmesi hedefleniyorsa `load_bundled_fonts` listesini güncellemeyi göz önünde bulundurur.

---
