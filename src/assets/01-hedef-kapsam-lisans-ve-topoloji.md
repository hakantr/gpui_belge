# Hedef, kapsam, lisans ve klasör topolojisi

Bu bölüm, varlık altyapısının hangi amaçla kurulduğunu ve sınırlarının nerede çizildiğini netleştirmeyi hedefler. Sonraki bölümler bu temel kararlar üzerine inşa edilir. Bu kararların baştan net bir şekilde ortaya konması, aynı konuları ilerleyen aşamalarda tekrar tartışmaya açmadan istikrarlı bir şekilde ilerlemeyi mümkün kılar.

Üç soru özellikle önemlidir: Varlık altyapısı hangi varlık türlerini taşır? Bu varlıklar release binary'ye nasıl katılır veya debug modda dosya sisteminden nasıl okunur? Hangi parçalar GPL-3 sınırı içinde, hangileri uygulamanın özgür alanındadır?

---

## 1. Varlık altyapısının kapsamı

Bir GPUI uygulamasında varlık altyapısı, binary içine gömülü veya dosya sisteminden okunan tüm "veri" parçalarını UI çalışma zamanına taşıyan tek köprüdür. Aşağıdaki yedi varlık türü Zed'de bu köprü üzerinden ilerler:

| Varlık türü | Klasör | Format | Tüketici |
|-------------|--------|--------|----------|
| Font | `fonts/` | `.ttf` | `TextSystem::add_fonts`, USVG fontdb |
| Vektör ikon | `icons/`, `icons/file_icons/`, `icons/knockouts/` | `.svg` | `SvgRenderer`, `svg()` element, `Icon` |
| Vektör görsel | `images/` | `.svg` | `Vector` bileşeni, `svg()` element |
| Ses | `sounds/` | `.wav` | `Audio::play_sound`, `rodio::Decoder` |
| Prompt şablonu | `prompts/` | `.hbs` | `PromptBuilder`, `handlebars` motoru |
| Tema | `themes/<aile>/` | `.json` | `ThemeRegistry`, `load_bundled_themes` |
| Klavye/ayar | `keymaps/`, `settings/` | `.json` | `SettingsStore`, keymap parser |

Buna ek olarak `badge/v0.json` dosyası README üzerindeki shields.io rozetini besler ve çalışma zamanı tarafından okunmaz; klasör topolojisinin parçası olarak listelenir ama varlık hattına dahil değildir.

**İlke:** Tek bir klasör hiyerarşisi tüm bu varlık gruplarını taşır; ancak her klasör kendi özel tüketicisi tarafından işlenir. Örneğin `fonts/` klasöründeki verileri `TextSystem` okurken, `themes/` klasöründeki verileri `ThemeRegistry` işler. `AssetSource` trait'i bu yapıların tamamı için ortak bir erişim yüzeyi sunar; bunun ötesinde her tüketici kendi özel gereksinim sözleşmesini tanımlar (örneğin fontlar için `.ttf` uzantı filtresi, temalar için `.json` uzantı filtresi).

**Sonuç:** Yeni bir varlık eklerken iki kararı eş zamanlı olarak vermen gerekir:

1. İlgili dosyayı hangi hedef klasöre yerleştireceğin,
2. Hangi tüketici kodun, hangi makro veya çalışma zamanı (runtime) API'si vasıtasıyla bu dosyayı çağıracağı.

Sadece bir SVG dosyasını `icons/` dizini altına yerleştirmen yeterli değildir; o ikona ait bir `IconName` varyantını da tanımlaman zorunludur. Benzer şekilde, yeni bir `.wav` dosyası eklemek için `Sound` enum yapısına uygun bir varyant girmen gerekir. Bu tür yapısal eşleşme gereksinimleri tüm varlık türleri için geçerlidir.

---

## 2. RustEmbed ile paketleme stratejisi

Zed iki ayrı `RustEmbed` struct'ı kullanır:

İlk struct büyük ve sık değişmeyen varlık klasörlerini paketler:

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

İkinci struct yalnızca settings ve keymap JSON'larını taşır:

```rust
#[derive(RustEmbed)]
#[folder = "../../assets"]
#[include = "settings/*"]
#[include = "keymaps/*"]
#[exclude = "*.DS_Store"]
pub struct SettingsAssets;
```

İki struct birden olmasının teknik bir gerekçesi vardır: `RustEmbed` makrosunun derleme zamanındaki klasör tarama maliyeti, klasör boyutu büyüdükçe ciddi şekilde artış gösterir. `Assets` struct yapısı; font, ikon ve tema klasörleri hacimli olduğundan, Zed binary'sinin sık gerçekleştirilen yeniden derleme süreçlerinde her seferinde taranarak gecikmelere yol açmaması için **ayrı bir crate** (`assets` crate'i) altında tutulur. Bu kararın arka planındaki açıklama, kaynak kod dosyasının ilk satırında 'artımlı derleme (incremental build) sırasında bir-iki saniye kazanmak amacıyla ayrıldı' ifadesiyle açıkça belirtilmiştir. `SettingsAssets` ise yalnızca settings ve keymap JSON dosyalarını barındırır; bu dosyalar küçük boyutlu olduğu için, settings crate'iyle aynı konumda bulunmaları derleme süresi üzerinde kayda değer bir maliyet oluşturmaz.

`RustEmbed` davranışı derleme (build) moduna göre ikiye ayrılır: release derlemelerinde veya `debug-embed` feature'ı etkinken dosyalar binary içinden okunurken, normal debug derlemelerinde aynı yollar doğrudan dosya sisteminden dinamik olarak çekilir. Zed dokümantasyonlarında 'gömülü varlık' ifadesiyle üretim (release) davranışı kastedilse de, özel uygulamalarda debug modundaki canlı dosya okuma davranışının da hesaba katılması gerekir.

**Önemli ayrıntı:** `Assets` struct yapısı `AssetSource` trait'ini implement eder ve çalışma zamanına `Application::with_assets(Assets)` zinciriyle bağlanır. Buna karşılık `SettingsAssets` yapısı, `RustEmbed::get` üzerinden senkron olarak `asset_str()` yardımıyla okunur; yani çalışma zamanına global bir kaynak olarak kaydedilmez. Bu ayrım üçüncü bölümde derinlemesine incelenecektir.

---

## 2.1. `Assets` public yüzeyi ve gömülü gruplar

`assets` crate'inde `Assets` tek public `RustEmbed` taşıyıcısıdır. Ayrı crate olarak tutulmasının amacı, büyük varlık ağacını Zed ana crate'i her yeniden derlendiğinde tekrar taratmamak ve GPUI çalışma zamanına yalnız `AssetSource` sözleşmesiyle bağlamaktır.

| API | Kapsam | Kullanım notu |
|-----|--------|---------------|
| `Assets` | `RustEmbed` struct'ı ve `AssetSource` implementasyonu | `Application::with_assets(Assets)` çağrısıyla çalışma zamanına aktarılır; `load` ve `list` çağrıları buradan karşılanır. |
| `fonts` | `#[include = "fonts/**/*"]` | `.ttf` dosyaları `Assets::load_fonts` ve testte `load_test_fonts` üzerinden `TextSystem` içine yüklenir. |
| `icons` | `#[include = "icons/**/*"]` | `IconName`, `SvgRenderer` ve `svg()` tüketicilerinin path sözleşmesini besler. |
| `images` | `#[include = "images/**/*"]` | `Vector` ve görsel SVG tüketiminde kullanılır; raster image cache ile karıştırılmaz. |
| `themes` | `#[include = "themes/**/*"]`, `#[exclude = "themes/src/*"]` | Bundled tema JSON'ları ve lisans dosyaları buradan okunur; kaynak tema üretim klasörü paketlenmez. |
| `sounds` | `#[include = "sounds/**/*"]` | `Sound` enum'u ve ses hattı için `.wav` varlıklarını taşır. |
| `prompts` | `#[include = "prompts/**/*"]` | Handlebars prompt şablonları için kullanılır. |
| `markdown` | `#[include = "*.md"]` | Kural tanımlı olsa da `assets/` kökünde `.md` dosyası bulunmadığından grup şu an boştur; ileride kök Markdown eklenirse bu kapsamla taranır. |
| `Assets::get` | `RustEmbed` tarafından üretilen statik erişim | Tek path için `EmbeddedFile` döndürür; `AssetSource::load` bu çağrıyı `Result<Option<Cow<[u8]>>>` sözleşmesine sarar. |
| `Assets::iter` | `RustEmbed` tarafından üretilen iterator | `AssetSource::list` içinde prefix filtrelemesi için kullanılır. |
| `Assets::load_fonts` | Çalışma zamanı font yükleme yardımcısı | `fonts` altındaki `.ttf` dosyalarını listeler, byte'ları `cx.asset_source()` üzerinden alır ve `TextSystem::add_fonts` çağırır. |
| `Assets::load_test_fonts` | Test font yükleme yardımcısı | Minimum Lilex fontunu yükleyerek headless/test ortamının metin ölçümünü çalışır hale getirir. |

Bu tablo, `Assets` içindeki alt özelliklerin her birini ayrı bir başlık haline getirmek yerine sözleşme türlerine göre açıklamaktadır: klasör grupları dosya yollarının kapsamını, `get`/`iter` metotları `RustEmbed` yüzeyini, `load_fonts`/`load_test_fonts` ise GPUI çalışma zamanı (runtime) üzerindeki etkileri ortaya koyar.

---

## 3. AssetSource trait'inin sözleşmesi

GPUI tarafında varlık altyapısının tek yüzeyi `AssetSource` trait'idir:

```rust
pub trait AssetSource: 'static + Send + Sync {
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>>;
    fn list(&self, path: &str) -> Result<Vec<SharedString>>;
}
```

Burada iki metoda dikkat etmen gerekir:

- `load`: Verilen dosya yolu (path) için ham byte içeriğini döner. Dönüş tipindeki `Option`, bazı kaynakların 'dosya mevcut değil' durumunu `Ok(None)` ile ifade edebilmesine imkan tanır; ancak her implementasyonun bu yapıyı kullanması zorunlu değildir. Zed bünyesindeki `Assets` implementasyonu `RustEmbed::get(path)` metodu `None` döndürdüğünde `with_context` vasıtasıyla bir `Err` üretirken, boş `()` implementasyonu her durumda doğrudan `Ok(None)` döndürür.
- `list`: Belirtilen prefix ile başlayan tüm dosya yollarını döner. Rekürsif (recursive) bir davranış sergiler; örneğin `list("fonts")` çağrısı, `fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf` gibi alt klasörlerde yer alan tüm dosyaları da listeler.

GPUI ayrıca `AssetSource` için `()` (unit type) üzerinden boş bir implementation sağlar. Bu, varlık gerektirmeyen testler ve headless senaryolar için varsayılan davranıştır: `load` her zaman `Ok(None)` döner ve `list` boş vektör verir. `Application::with_assets` çağrılmadığı sürece `App` bu boş kaynağı kullanır.

---

## 4. Klasör topolojisi detayları

`assets/` klasörünün yapısı aşağıdaki gibidir; her satırdaki açıklama, klasörün hangi çalışma zamanı parçası tarafından okunduğunu belirtir.

```text
assets/
├── fonts/                       # TextSystem + USVG fontdb okur
├── ibm-plex-sans/
│   ├── IBMPlexSans-Regular.ttf
│   ├── IBMPlexSans-Italic.ttf
│   ├── IBMPlexSans-SemiBold.ttf
│   ├── IBMPlexSans-SemiBoldItalic.ttf
│   └── license.txt
└── lilex/                   # monospace font ailesi
    ├── Lilex-Regular.ttf
    ├── Lilex-Bold.ttf
    ├── Lilex-Italic.ttf
    ├── Lilex-BoldItalic.ttf
    └── OFL.txt
├── icons/                       # SvgRenderer + Icon bileşeni okur
│   ├── *.svg                    # IconName::path() ile eşlenen UI ikonları
│   ├── file_icons/              # IconTheme::file_icons + chevron/folder
│   │   └── *.svg
│   ├── knockouts/               # IconDecoration için maskeler
│   │   └── *.svg
│   └── LICENSES                 # ikon SVG'lerinin lisans kaynağı (Lucide, ISC)
├── images/                      # Vector bileşeni okur (SVG raster değil)
│   ├── zed_logo.svg
│   ├── zed_x_copilot.svg
│   ├── grid.svg
│   ├── business_stamp.svg
│   ├── pro_trial_stamp.svg
│   ├── pro_user_stamp.svg
│   └── student_stamp.svg
├── themes/                      # ThemeRegistry + load_bundled_themes okur
│   ├── one/
│   │   ├── one.json
│   │   └── LICENSE
│   ├── ayu/
│   │   ├── ayu.json
│   │   └── LICENSE
│   ├── gruvbox/
│   │   ├── gruvbox.json
│   │   └── LICENSE
│   └── LICENSES                 # paketlenmiş tema lisanslarını toplayan dosya
├── sounds/                      # Ses hattı okur
│   └── *.wav                    # Sound enum varyantlarıyla 1:1 eşleşir
├── keymaps/                     # SettingsAssets üzerinden okunur
│   ├── default-linux.json
│   ├── default-macos.json
│   ├── default-windows.json
│   ├── initial.json
│   ├── storybook.json
│   ├── vim.json
│   ├── linux/                   # platforma özgü override paketleri
│   └── macos/                   # atom/cursor/emacs/jetbrains/sublime/textmate
├── settings/                    # SettingsAssets üzerinden okunur
│   ├── default.json
│   ├── default_semantic_token_rules.json
│   ├── initial_user_settings.json
│   ├── initial_server_settings.json
│   ├── initial_local_settings.json
│   ├── initial_tasks.json
│   ├── initial_debug_tasks.json
│   └── initial_local_debug_tasks.json
├── prompts/                     # PromptBuilder + handlebars motoru okur
│   ├── content_prompt.hbs
│   ├── content_prompt_v2.hbs
│   └── terminal_assistant_prompt.hbs
└── badge/
    └── v0.json                  # çalışma zamanı tarafından okunmaz; README rozeti
```

**Tüketici-klasör eşlemesi:** Bir klasörün çalışma zamanında işlevsel olabilmesi için iki şartın eş zamanlı olarak sağlanması gerekir. İlk olarak, ilgili klasörün `RustEmbed` struct'ında `#[include]` özniteliği ile açıkça tanımlanmış olması şarttır; aksi takdirde `list` ve `load` işlevleri o klasörü göremez. İkinci olarak, o klasörü okuyan bir tüketicinin (örneğin font yükleyici, ikon enum yapısı veya ses hattı) çağrılmış olması gerekir. Bu iki şarttan biri eksik kaldığında, varlık release binary dosyasında veya debug dosya sistemi ağacında yer alsa bile kullanıcı arayüzünde (UI) görüntülenmez.

---

## 5. Lisans katmanlaması

Varlık altyapısının kendi kodu (yani `assets` crate'indeki `AssetSource` implementasyonu) küçük ve standart bir `RustEmbed` sarmalayıcısıdır. Kod mantığında özel bir telif riski yoktur; ancak varlıkların kendileri farklı lisanslara tabidir ve her biri ayrı değerlendirilmelidir.

| Katman | Lisans tarafı |
|--------|---------------|
| `AssetSource` implementasyonu | `RustEmbed` etrafında ince sarmalayıcı; standart Rust kodu |
| Fonts (`fonts/ibm-plex-sans/`, `fonts/lilex/`) | OFL (Open Font License); lisans dosyaları font klasörünün içinde tutulur |
| Icons (`icons/*.svg`) | Lucide (ISC) kökenli, bir bölümü Feather (MIT) olan SVG'ler; lisans `icons/LICENSES` dosyasıyla taşınır |
| Themes (`themes/*/`) | Her tema ailesinin kendi `LICENSE` dosyası vardır; `themes/LICENSES` dosyası ise bunları tek metinde toplar |
| Sounds (`sounds/*.wav`) | Zed projesi tarafından üretilmiş WAV dosyaları; GPL-3 sınırı içindedir |
| Prompts (`prompts/*.hbs`) | Zed projesi tarafından üretilen şablonlar; GPL-3 sınırı içindedir |

**Yapılabilir / Yapılamaz:**

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| `RustEmbed` ile kendi varlık klasörünü kurmak ve `AssetSource` trait'ini implement etmek | Zed'in `assets` modülünün gövdesini doğrudan kopyalamak yerine yeniden yazmak |
| OFL lisanslı IBM Plex Sans ve Lilex fontlarını lisans dosyalarıyla birlikte taşımak | Lisans dosyası olmadan font dosyası taşımak (OFL bunu açıkça yasaklar) |
| Lucide (ISC) ikonlarını `icons/LICENSES` dosyasıyla birlikte taşımak veya MIT/Apache lisanslı kendi ikonlarını eklemek | `icons/*.svg` dosyalarını `icons/LICENSES` lisans metni olmadan taşımak (ISC, telif ve izin bildiriminin korunmasını şart koşar) |
| Yapısal akışı (RustEmbed → AssetSource → SvgRenderer → svg element) anlayıp kendi koduyla yeniden yazmak | `cx.asset_source()` çağrı zincirindeki kod parçalarını birebir kopyalamak |

**Sonuç:** Varlık altyapısının genel mimari yapısı (RustEmbed + AssetSource + tüketici zincirleri) açık ve standart bir tasarım desenidir; bu nedenle telif korumasına tabi değildir. Ancak varlıkların kendileri (fontlar, ikonlar, sesler, prompt'lar) mutlaka kendi lisans dosyalarıyla birlikte taşınmalıdır. Kendi uygulamanı geliştirirken, Zed bünyesindeki font ve tema dosyalarını kendi lisanslarıyla birlikte projene dahil etmen mümkündür; Lucide (ISC) tabanlı SVG ikonlarını da `icons/LICENSES` metniyle birlikte serbestçe taşıyabilirsin. WAV ses dosyaları ise doğrudan Zed ekibi tarafından üretilmiş olup GPL-3 lisans sınırları dahilindedir; bu sınırların dışında bir kullanım hedefliyorsan, bu sesleri yeniden üretmen veya uyumlu lisansa sahip eşdeğerleriyle değiştirmen gerekir.

---

## 6. Bağımlılık yönü

Varlık altyapısının bağımlılık grafiği iki katmanlıdır:

```text
RustEmbed erişim kümesi (release embed / debug dosya sistemi)
       │
       ▼
AssetSource trait (gpui)
       │
       ▼
Application::with_assets ──> svg_renderer, varlık cache'i, text_system
       │
       ▼
Tüketiciler (Icon, Vector, img, Sound, Theme, Settings, Prompt)
```

Ters yönde bir bağımlılık kurulması yasaktır: `AssetSource` trait yapısı, tüketici kodlarına hiçbir şekilde referans vermez. Yani `gpui::AssetSource` ne `Icon` yapısını, ne `Sound` enum'unu ne de `Theme` nesnesini tanır; yalnızca ham byte verileri döndürür. Bu gevşek bağlılık sayesinde varlık altyapısı son derece sade ve bağımsız kalır: yeni bir varlık türü eklemek için `AssetSource` arayüzünün değiştirilmesi gerekmez, yalnızca yeni bir tüketici katmanının eklenmesi yeterlidir.

Bu kararın pratikteki anlamı şudur: uygulamanın ilerleyen süreçte bir varlık türünü değiştirmek istemesi durumunda (örneğin SVG ikonlar yerine PDF formatına geçilmesi), `AssetSource` katmanı bu değişiklikten etkilenmez. Sadece tüketici tarafındaki dosya yolu eşleştirme ve render mantığının güncellenmesi yeterli olur.

---
