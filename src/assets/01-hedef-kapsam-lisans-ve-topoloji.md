# Hedef, kapsam, lisans ve klasör topolojisi

Bu bölüm, asset altyapısının hangi amaçla kurulduğunu ve sınırlarının nerede çizildiğini netleştirir. Sonraki bölümler bu cevapların üzerine kurulur. Bu nedenle kararları burada açıkça koymak, aynı konuları ileride tekrar tekrar açmadan ilerlemeyi mümkün kılar.

Üç soru özellikle önemlidir: Asset altyapısı hangi varlık türlerini taşır? Bu varlıklar release binary'ye nasıl katılır veya debug modda filesystem'den nasıl okunur? Hangi parçalar GPL-3 sınırı içinde, hangileri uygulamanın özgür alanındadır?

---

## 1. Asset altyapısının kapsamı

Bir GPUI uygulamasında asset altyapısı, binary içine gömülü veya filesystem'den okunan tüm "veri" parçalarını UI runtime'ına taşıyan tek köprüdür. Aşağıdaki yedi varlık türü Zed'de bu köprü üzerinden ilerler:

| Varlık türü | Klasör | Format | Tüketici |
|-------------|--------|--------|----------|
| Font | `fonts/` | `.ttf` | `TextSystem::add_fonts`, USVG fontdb |
| Vektör ikon | `icons/`, `icons/file_icons/`, `icons/knockouts/` | `.svg` | `SvgRenderer`, `svg()` element, `Icon` |
| Vektör görsel | `images/` | `.svg` | `Vector` bileşeni, `svg()` element |
| Ses | `sounds/` | `.wav` | `Audio::play_sound`, `rodio::Decoder` |
| Prompt şablonu | `prompts/` | `.hbs` | `PromptBuilder`, `handlebars` motoru |
| Tema | `themes/<aile>/` | `.json` | `ThemeRegistry`, `load_bundled_themes` |
| Klavye/ayar | `keymaps/`, `settings/` | `.json` | `SettingsStore`, keymap parser |

Buna ek olarak `badge/v0.json` dosyası README üzerindeki shields.io rozetini besler ve runtime tarafından okunmaz; klasör topolojisinin parçası olarak listelenir ama asset boru hattına dahil değildir.

**İlke:** Tek bir klasör hiyerarşisi tüm bu varlıkları taşır, fakat her klasör kendi tüketicisi tarafından okunur. Yani `fonts/` klasörünü `TextSystem` okur, `themes/` klasörünü `ThemeRegistry` okur. `AssetSource` trait'i hepsine ortak yüzey sağlar; bunun ötesinde her tüketici kendi sözleşmesini koyar (örneğin font için `.ttf` filtresi, tema için `.json` filtresi).

**Sonuç:** Asset eklerken iki karar birlikte alırsın:

1. Dosya hangi klasöre konulur?
2. Hangi tüketici kodu, hangi macro veya runtime API ile bu dosyayı çağırır?

Bir SVG dosyasını `icons/` altına koymak yetmez; o ikona ait bir `IconName` varyantı da eklemen gerekir. Aynı şekilde bir `.wav` eklemek için `Sound` enum'una varyant girmek gerekir. Yapısal eşleşme tüm asset türleri için geçerlidir.

---

## 2. RustEmbed ile paketleme stratejisi

Zed iki ayrı `RustEmbed` struct'ı kullanır:

İlk struct büyük ve sık değişmeyen asset klasörlerini paketler:

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

İki struct birden olmasının teknik bir gerekçesi vardır: `RustEmbed` macro'sunun derleme süresinde tarama maliyeti, klasör büyüdükçe ciddi şekilde artar. `Assets` struct'ı; font, ikon ve tema klasörleri büyük olduğu için Zed binary'sinin sık yeniden derlenmesi sırasında her seferinde taranmasın diye **ayrı bir crate** olarak (`assets`) tutulur. Bu kararın yorumu kaynak dosyasının ilk satırında açıkça yazılıdır: "incremental build sırasında bir-iki saniye kazandırmak için ayrıldı". `SettingsAssets` ise yalnızca settings ve keymap JSON'larını tutar; bu klasörler küçük olduğundan settings crate'iyle aynı yerde bulunması yeniden derleme maliyetini büyütmez.

`RustEmbed` davranışı build moduna göre ikiye ayrılır: release build'de veya `debug-embed` feature'ı açıkken dosyalar binary içinden gelir; normal debug build'de aynı path'ler filesystem'den okunur. Zed dokümanlarında "gömülü asset" denildiğinde üretim davranışı kastedilir, fakat kendi uygulamanızda debug modda canlı dosya okuma davranışını da hesaba katmak gerekir.

**Önemli ayrıntı:** `Assets` struct'ı `AssetSource` trait'ini implement eder ve runtime'a `Application::with_assets(Assets)` zinciriyle bağlanır. `SettingsAssets` ise `RustEmbed::get` üzerinden senkron olarak `asset_str()` yardımıyla okunur; runtime'a global olarak kaydedilmez. Bu ayrım üçüncü bölümde derinlemesine işlenir.

---

## 2.1. `Assets` public yüzeyi ve gömülü gruplar

`assets` crate'inde `Assets` tek public `RustEmbed` taşıyıcısıdır. Ayrı crate olarak tutulmasının amacı, büyük asset ağacını Zed ana crate'i her yeniden derlendiğinde tekrar taratmamak ve GPUI runtime'a yalnız `AssetSource` sözleşmesiyle bağlamaktır.

| API | Kapsam | Kullanım notu |
|-----|--------|---------------|
| `Assets` | `RustEmbed` struct'ı ve `AssetSource` implementasyonu | `Application::with_assets(Assets)` ile runtime'a verilir; `load` ve `list` çağrıları buradan karşılanır. |
| `fonts` | `#[include = "fonts/**/*"]` | `.ttf` dosyaları `Assets::load_fonts` ve testte `load_test_fonts` üzerinden `TextSystem` içine yüklenir. |
| `icons` | `#[include = "icons/**/*"]` | `IconName`, `SvgRenderer` ve `svg()` tüketicilerinin path sözleşmesini besler. |
| `images` | `#[include = "images/**/*"]` | `Vector` ve görsel SVG tüketiminde kullanılır; raster image cache ile karıştırılmaz. |
| `themes` | `#[include = "themes/**/*"]`, `#[exclude = "themes/src/*"]` | Bundled tema JSON'ları ve lisans dosyaları buradan okunur; kaynak tema üretim klasörü paketlenmez. |
| `sounds` | `#[include = "sounds/**/*"]` | `Sound` enum'u ve audio pipeline için `.wav` varlıklarını taşır. |
| `prompts` | `#[include = "prompts/**/*"]` | Handlebars prompt şablonları için kullanılır. |
| `markdown` | `#[include = "*.md"]` | Kök Markdown dosyalarını kapsar; mevcut ağaçta runtime ana akışına yük bindiren geniş bir grup değildir. |
| `Assets::get` | `RustEmbed` tarafından üretilen statik erişim | Tek path için `EmbeddedFile` döndürür; `AssetSource::load` bu çağrıyı `Result<Option<Cow<[u8]>>>` sözleşmesine sarar. |
| `Assets::iter` | `RustEmbed` tarafından üretilen iterator | `AssetSource::list` içinde prefix filtrelemesi için kullanılır. |
| `Assets::load_fonts` | Runtime font yükleme yardımcısı | `fonts` altındaki `.ttf` dosyalarını listeler, byte'ları `cx.asset_source()` üzerinden alır ve `TextSystem::add_fonts` çağırır. |
| `Assets::load_test_fonts` | Test font yükleme yardımcısı | Minimum Lilex fontunu yükleyerek headless/test ortamının metin ölçümünü çalışır hale getirir. |

Bu tablo, `Assets` içindeki alt özelliklerin tamamını başlık yapmak yerine sözleşme türüne göre açıklar: klasör grupları path kapsamını, `get`/`iter` `RustEmbed` yüzeyini, `load_fonts`/`load_test_fonts` ise GPUI runtime etkisini anlatır.

---

## 3. AssetSource trait'inin sözleşmesi

GPUI tarafında asset altyapısının tek yüzeyi `AssetSource` trait'idir:

```rust
pub trait AssetSource: 'static + Send + Sync {
    fn load(&self, path: &str) -> Result<Option<Cow<'static, [u8]>>>;
    fn list(&self, path: &str) -> Result<Vec<SharedString>>;
}
```

İki metoda dikkat etmek gerekir:

- `load`: Verilen path için ham byte içeriği döner. Dönüş tipindeki `Option`, bazı kaynakların "dosya yok" durumunu `Ok(None)` ile ifade edebilmesine izin verir; fakat her implementasyon bunu kullanmak zorunda değildir. Zed'in `Assets` implementasyonu `RustEmbed::get(path)` `None` döndürürse `with_context` üzerinden `Err` üretir, boş `()` implementasyonu ise her zaman `Ok(None)` döndürür.
- `list`: Verilen prefix ile başlayan tüm path'leri döner. Recursive davranır; örneğin `list("fonts")` çağrısı `fonts/ibm-plex-sans/IBMPlexSans-Regular.ttf` gibi alt klasörlerdeki dosyaları da listeler.

GPUI ayrıca `AssetSource` için `()` (unit type) üzerinden boş bir implementation sağlar. Bu, asset gerektirmeyen testler ve headless senaryolar için varsayılan davranıştır: `load` her zaman `Ok(None)` döner ve `list` boş vektör verir. `Application::with_assets` çağrılmadığı sürece `App` bu boş kaynağı kullanır.

---

## 4. Klasör topolojisi detayları

`assets/` klasörünün yapısı aşağıdaki gibidir; her satırdaki açıklama, klasörün hangi runtime parçası tarafından okunduğunu belirtir.

```text
assets/
├── fonts/                       # TextSystem + USVG fontdb okur
│   ├── ibm-plex-sans/
│   │   ├── IBMPlexSans-Regular.ttf
│   │   ├── IBMPlexSans-Italic.ttf
│   │   ├── IBMPlexSans-SemiBold.ttf
│   │   ├── IBMPlexSans-SemiBoldItalic.ttf
│   │   └── license.txt
│   └── lilex/                   # monospace font ailesi
│       ├── Lilex-Regular.ttf
│       ├── Lilex-Bold.ttf
│       ├── Lilex-Italic.ttf
│       ├── Lilex-BoldItalic.ttf
│       └── OFL.txt
├── icons/                       # SvgRenderer + Icon bileşeni okur
│   ├── *.svg                    # IconName::path() ile eşlenen UI ikonları
│   ├── file_icons/              # IconTheme::file_icons + chevron/folder
│   │   └── *.svg
│   └── knockouts/               # IconDecoration için maskeler
│       └── *.svg
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
│   └── LICENSES/                # paketlenmiş tema lisansları
├── sounds/                      # Audio pipeline okur
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
    └── v0.json                  # runtime tarafından okunmaz; README rozeti
```

**Tüketici-klasör eşlemesi:** Bir klasörün runtime'da değer üretebilmesi için iki şart aynı anda sağlanmalıdır. İlk olarak ilgili `RustEmbed` struct'ında `#[include]` ile beyan edilmiş olmalıdır; aksi halde `list` ve `load` o klasörü hiç görmez. İkinci olarak klasörü okuyan bir tüketici (font yükleyici, ikon enum'u, ses pipeline'ı vb.) çağırılmalıdır. İki şarttan biri eksikse asset release binary'de veya debug filesystem ağacında durur ama UI'da görünmez.

---

## 5. Lisans katmanlaması

Asset altyapısının kendi kodu (yani `assets` crate'indeki `AssetSource` implementasyonu) küçük ve standart bir `RustEmbed` sarmalayıcısıdır. Kod mantığında özel bir telif riski yoktur; ancak varlıkların kendileri farklı lisanslara tabidir ve her biri ayrı değerlendirilmelidir.

| Katman | Lisans tarafı |
|--------|---------------|
| `AssetSource` implementasyonu | `RustEmbed` etrafında ince sarmalayıcı; standart Rust kodu |
| Fonts (`fonts/ibm-plex-sans/`, `fonts/lilex/`) | Sırasıyla OFL (Open Font License); lisans dosyaları font klasörünün içinde tutulur |
| Icons (`icons/*.svg`) | Zed projesi tarafından üretilen SVG'ler; GPL-3 sınırı içindedir |
| Themes (`themes/*/`) | Her tema ailesinin kendi LICENSE dosyası vardır; `themes/LICENSES/` bunları toplar |
| Sounds (`sounds/*.wav`) | Zed projesi tarafından üretilmiş WAV dosyaları; GPL-3 sınırı içindedir |
| Prompts (`prompts/*.hbs`) | Zed projesi tarafından üretilen şablonlar; GPL-3 sınırı içindedir |

**Yapılabilir / Yapılamaz:**

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| `RustEmbed` ile kendi asset klasörünü kurmak ve `AssetSource` trait'ini implement etmek | Zed'in `assets` modülünün gövdesini kopyalamak yerine yeniden yazmak gerekir |
| OFL lisanslı IBM Plex Sans ve Lilex fontlarını lisans dosyalarıyla birlikte taşımak | Lisans dosyası olmadan font dosyası taşımak (OFL bunu açıkça yasaklar) |
| Zed dışında MIT/Apache lisanslı kendi ikonlarını eklemek | `icons/*.svg` dosyalarını GPL-3 sınırı dışında bir uygulamaya doğrudan kopyalamak |
| Yapısal akışı (RustEmbed → AssetSource → SvgRenderer → svg element) anlayıp kendi koduyla yeniden yazmak | `cx.asset_source()` çağrı zincirindeki kod parçalarını birebir kopyalamak |

**Sonuç:** Asset altyapısının yapısı (RustEmbed + AssetSource + tüketici zincirleri) açık bir desendir; telif kapsamında değildir. Ancak varlıkların kendisi (font, ikon, ses, prompt) lisans dosyasıyla birlikte taşınır. Kendi uygulamasını kuran geliştirici, Zed'in font ve tema dosyalarını lisanslarıyla birlikte taşıyabilir. SVG ikon ve WAV ses dosyaları GPL-3 sınırı dışında kullanılacaksa yeniden üretilmeli ya da MIT/Apache eşdeğerleriyle değiştirilmelidir.

---

## 6. Bağımlılık yönü

Asset altyapısının bağımlılık grafiği iki katmanlıdır:

```text
RustEmbed erişim kümesi (release embed / debug filesystem)
       │
       ▼
AssetSource trait (gpui)
       │
       ▼
Application::with_assets ──> svg_renderer, asset cache, text_system
       │
       ▼
Tüketiciler (Icon, Vector, img, Sound, Theme, Settings, Prompt)
```

Ters yön yasaktır: `AssetSource` trait'i tüketici kodlarına referans vermez. Yani `gpui::AssetSource` ne `Icon`'u ne `Sound`'u ne de `Theme`'i bilir; sadece byte döner. Bu sayede asset altyapısı sakin tutulur: yeni bir varlık türü eklemek için `AssetSource` arayüzü değişmez, yalnızca yeni bir tüketici eklersin.

Bu kararın pratikteki anlamı şudur: uygulama bir asset türünü zamanla değiştirmek isterse (örneğin SVG ikonları PDF'e döndürmek), `AssetSource` katmanı bundan etkilenmez. Yalnızca tüketici tarafındaki path eşleştirme ve render kodu değişir.

---
