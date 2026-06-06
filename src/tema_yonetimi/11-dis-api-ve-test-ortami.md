# Dış API ve test ortamı

Bu bölüm iki işi netleştirir: tüketiciye açılacak public API sınırı ve test ortamında sahte tema düzeni. İyi çizilmiş bir public API sınırı, mevcut Zed sözleşmesinde hangi parçaların bilinçli olarak açıldığını gösterir. İyi kurulmuş bir test ortamı ise bileşenlerin tema değişimi karşısında doğru davrandığını sürdürülebilir biçimde doğrular.

---

## 43. Public API kataloğu ve crate-içi sınır

`kvs_tema` ve `kvs_syntax_tema` crate'lerinin **dışa açtığı** sözleşme ile **iç implementasyon detayları** arasındaki ayrımı netleştirir. Bu sınırın amacı, tüketicinin yalnızca mevcut uygulama için desteklenen yüzeye bağlanmasını sağlamaktır.

### Sınır felsefesi

| Kategori | Public mi? | Kim kullanır | Not |
| ---------- | ------------ | -------------- | ----- |
| **Public API** | ✓ | Tüketici UI bileşenleri | Uygulamanın desteklediği açık yüzey |
| **Schema API** | Kısmen | Tema yükleme/import kodu | Mevcut Zed JSON sözleşmesine bağlı |
| **Crate-içi (`pub(crate)`)** | ✗ | Yalnızca `kvs_tema` modülleri | Dış tüketiciye açılmaz |

### `kvs_tema` public API kataloğu

**Veri tipleri (public):**

```rust
pub use crate::Theme;            // accessor metotlarıyla okunur
pub use crate::ThemeFamily;
pub use crate::Appearance;

pub use crate::styles::ThemeColors;
pub use crate::styles::StatusColors;
pub use crate::styles::PlayerColors;
pub use crate::styles::PlayerColor;
pub use crate::styles::AccentColors;
pub use crate::styles::SystemColors;
pub use crate::styles::ThemeStyles;
pub use crate::styles::ThemeColorField;

// Icon tema sözleşmesi
pub use crate::icon_theme::{
    IconTheme, IconThemeFamily, IconDefinition,
    DirectoryIcons, ChevronIcons,
};
```

> **Zed parite notu:** Zed'de `ThemeStyles` tipi ve `Theme.styles` alanı public görünürlüktedir. Mirror tarafında accessor disiplini için `styles` alanı `pub(crate)` seçilirse bu bilinçli bir yerel sıkılaştırmadır; Zed public API kapsamı yine de `ThemeStyles`'ı kapsar.

**Runtime (public):**

```rust
pub use crate::runtime::ActiveTheme;             // cx.theme() için trait
pub use crate::runtime::GlobalTheme;
pub use crate::runtime::SystemAppearance;
pub use crate::runtime::init;
pub use crate::runtime::temayi_degistir;         // tek-yönlü helper
pub use crate::runtime::temayi_yeniden_yukle;    // disk reload
pub use crate::runtime::observe_system_appearance;  // pencere observer
```

**Registry (public):**

```rust
pub use crate::registry::{
    ThemeRegistry, ThemeMeta, ThemeNotFoundError, IconThemeNotFoundError,
};
```

**Fallback (public, namespace altında):**

```rust
// kvs_tema::fallback::kvs_default_dark()
// kvs_tema::fallback::kvs_default_light()
pub mod fallback;   // pub modül; içeride sadece public fonksiyonlar
```

**Schema (Zed sözleşmesine bağlı — tek tek ihraç):**

```rust
// Glob YASAK — yeni iç tip eklendiğinde istemeden public olmaması için
// tek tek ihraç:
pub use crate::schema::{
    AppearanceContent, FontStyleContent, FontWeightContent,
    HighlightStyleContent, PlayerColorContent, StatusColorsContent,
    ThemeColorsContent, ThemeContent, ThemeFamilyContent,
    ThemeStyleContent, WindowBackgroundContent,
    try_parse_color,
};

// Icon tema Content tipleri
pub use crate::icon_theme::{
    IconThemeContent, IconThemeFamilyContent,
    DirectoryIconsContent, ChevronIconsContent, IconDefinitionContent,
};
```

> **Schema public kullanım için ana kapı değildir:** Bu tipler mevcut Zed JSON sözleşmesini taşır. Tüketici doğrudan `ThemeColorsContent` kullanırsa JSON ayrıntılarına bağlanmış olur. Mecburiyet yoksa tema yükleme işlemleri `Theme::from_content` ve registry helper'ları üzerinden yürütülmelidir.

**`kvs_syntax_tema` public API:**

```rust
pub use SyntaxTheme;
```

Tek bir tip yeterli olur. `HighlightStyle` zaten GPUI'den gelir; re-export gereksizdir.

### Crate-içi (NON-public) modüller

| Modül | İçerik | Erişim |
| ------- | -------- | -------- |
| `refinement` | `theme_colors_refinement`, `status_colors_refinement`, `apply_status_color_defaults`, `color()` helper | `pub(crate)` — yalnızca `Theme::from_content` çağırır |
| `runtime` iç detayları | `GlobalThemeRegistry`, `GlobalSystemAppearance` newtype'ları | `pub(crate)` veya `pub(super)` |

**Neden gizli tutulur?** Refinement davranışı tema üretim hattının iç adımıdır. Tüketici bu fonksiyonları doğrudan çağırırsa, `Theme::from_content` ile tek yerde tutulması gereken sıra ve default kuralları dağılır.

### Lib kökü yapısı (`kvs_tema/src/kvs_tema.rs`)

İlgili bölümdeki iskeletle aynı yapıdır. Burada özet biçimde sunulur:

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

// Crate-içi (gizli)
pub(crate) mod refinement;          // ilgili bölüm

// Namespace altında public (kvs_tema::fallback::*)
pub mod fallback;

// Private dosya modülleri, içeriği seçici biçimde ihraç edilir
mod icon_theme;
mod registry;
mod runtime;
mod schema;
mod styles;

// Glob ihraç — public modüller
pub use crate::icon_theme::*;
pub use crate::registry::*;
pub use crate::runtime::*;
pub use crate::styles::*;

// Schema — KARARSIZ; tek tek ihraç, glob asla
pub use crate::schema::{
    AppearanceContent, FontStyleContent, FontWeightContent,
    HighlightStyleContent, PlayerColorContent, StatusColorsContent,
    ThemeColorsContent, ThemeContent, ThemeFamilyContent,
    ThemeStyleContent, WindowBackgroundContent,
    try_parse_color,
};

// Lib kökünde tanımlı tipler (zaten public)
// → Theme, ThemeFamily, Appearance
// → ThemeStyles ve ThemeColorField Zed paritesinde public yüzeydedir
```

**İzlenen kalıp:**

- `pub(crate) mod refinement` — `refinement` dışarıya kapalıdır, içeride paylaşılır.
- `pub use module::*` — public modüller için tümünü ihraç eden bir yol; her iç tipin public olması isteniyorsa glob, istenmiyorsa tek tek kullanırsın.
- `pub use schema::{...}` — schema modülü için **glob YASAK**; çünkü iç implementasyon tipleri (örneğin `serde` helper'ları) istenmeden public hale gelmemelidir.
- `pub mod fallback` — fallback fonksiyonları bir namespace altında toplanır (`kvs_tema::fallback::kvs_default_dark`). `fallback` içinde yalnızca bu iki fonksiyon `pub`'tır; gerisi `pub(super)` veya private kalır.

### `prelude` modülü (önerilen)

```rust
//! kvs_tema prelude — sık kullanılan tipleri tek import'a indirir.

pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily};
pub use crate::styles::{
    AccentColors, PlayerColor, PlayerColors,
    StatusColors, SystemColors, ThemeColors,
};
```

Tüketici tarafından kullanım:

```rust
use kvs_tema::prelude::*;
// Theme, ActiveTheme, ThemeColors, vb. hepsi mevcut
```

> **Prelude'a `ThemeRegistry`/`GlobalTheme` eklenmemiştir.** Bu tipler uygulama init ve admin kodu için anlam taşır; UI bileşenleri kullanmaz. Render path prelude'unun hafif tutulması yerinde olur.

### Referans güncelleme notu

`kvs_tema` hedeflediği Zed referansını değiştirdiğinde public export listesi, schema tipleri, fixture dosyaları ve snapshot testleri aynı çalışma içinde güncellemen gerekir. Sözleşme değişimini yalnızca bir yerde yapmak yeterli değildir; aksi halde belge, test ve runtime modeli farklı Zed durumlarını tarif eder.

### Tüketici sözleşmesi

Tüketici kodun güvenle yapabileceği işlemler:

- ✓ `cx.theme().colors().background` okunabilir.
- ✓ `kvs_tema::Theme` ve `kvs_tema::ThemeColors` import edebilirsin.
- ✓ `ThemeRegistry::global(cx)` ile registry sorgulanabilir.
- ✓ `kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx)` çağrılabilir.
- ✓ `kvs_tema::temayi_degistir(ad, cx)` ile tema değiştirilebilir.
- ✓ `kvs_tema::temayi_yeniden_yukle(yol, cx)` ile disk'ten reload yapılabilir.
- ✓ `kvs_tema::observe_system_appearance(window, cx)` ile sistem mod takibi kurulabilir.
- ✓ `kvs_tema::SystemAppearance::global(cx)` ile sistem mod sorgulanabilir.
- ✓ `GlobalTheme::icon_theme(cx)` ile aktif icon tema okunabilir.
- ✓ `ThemeRegistry::global(cx).list_icon_themes()` ile icon tema seçenekleri listelenebilir.

Tüketicinin yapamayacağı işlemler (compile hatası alır):

- ✗ `theme.styles.colors.X` zinciri kullanılamaz; `styles` `pub(crate)` olduğu için accessor şarttır.
- ✗ `GlobalThemeRegistry` veya `GlobalSystemAppearance` newtype'larına doğrudan dokunulamaz; ikisi de private kalır.

Tüketicinin yapmaması gereken işlemler (compile geçer ama kötü pratik):

- ✗ `kvs_tema::ThemeColorsContent` üzerinde UI davranışı kurma; bu tip schema JSON ayrıntısıdır.
- ✗ `kvs_tema::try_parse_color(...)` çağrısını doğrudan yapma; `Theme::from_content` zaten bu işlemi sarmalar.
- ✗ Tema yüklerken `baseline` appearance'ını aktif görünümden bağımsız seçme.

### `pub(crate)` ile gerçek izolasyon

`pub use crate::refinement::*` yazıldığında **`refinement` modülü public hale gelir**; istenmediği halde dışa açılır. `pub(crate) mod refinement;` ile modülün gizli tutulması ve `Theme::from_content` impl bloğu içinde doğrudan çağrılması doğru yaklaşımdır:

```rust
// kvs_tema.rs
pub(crate) mod refinement;

// Theme::from_content impl içinde (crate-içi)
use crate::refinement::{theme_colors_refinement, ...};
```

`refinement`'in fonksiyonları `pub` olabilir; modülün kendisi `pub(crate)` olduğu için dış dünyaya görünmez kalır. Bu, pratik bir API izolasyonu sağlar.

### Tüketici API sınırı örneği

`cargo doc --no-deps` çalıştırıldığında **yalnızca istenen tiplerin** görünmesi beklersin:

```sh
cargo doc -p kvs_tema --no-deps --open
```

Doc sayfasında `theme_colors_refinement` veya `apply_status_color_defaults` görünüyorsa `pub use` zincirinin gözden geçirilmesi gerekir; bir sızıntı söz konusudur.

### Dikkat Noktaları

1. **`pub use crate::*` içinde `refinement`'in yakalanması**: `pub use crate::refinement::*` yazıp ardından modülün `pub(crate)` olarak tutulması bir compile hatasına yol açar ("re-exporting private module"). İki tarafın tutarlı olması gerekir.
2. **`Theme.styles` alanının public yapılması (`pub`)**: Bu durumda alan public hale gelir ve iç düzen sızar. Accessor metotlarını sunduktan sonra `styles`'ı `pub(crate)` olarak tutarsın ve okumaları yalnızca accessor üzerinden yaparsın.
3. **`schema::*` glob ile public ihraç**: Schema tiplerinin tamamı dışa açılır; iç tipler de otomatik olarak public olur. Bunun yerine tek tek `pub use` yapılması doğru tercihtir:
   ```rust
   pub use crate::schema::{
       ThemeFamilyContent, ThemeContent, ThemeStyleContent,
       ThemeColorsContent, StatusColorsContent, PlayerColorContent,
       HighlightStyleContent, AppearanceContent, WindowBackgroundContent,
       FontStyleContent, FontWeightContent,
       try_parse_color,
   };
   ```
4. **Public yüzeyi belirsiz bırakmak**: Tüketici hangi modüle bağlanacağını bilmiyorsa schema ve refinement detaylarına kayar. Public export listesi bu yüzden açık tutman gerekir.
5. **`prelude::*` glob importlarının endüstri görüşü**: Bazı stil rehberleri glob'u kabul etmez. Bu konudaki karar tüketiciye bırakılır; prelude sunulur, kullanılması veya elle import edilmesi geliştiricinin tercihinde kalır.
6. **`pub` accessor metotlarının yazılmaması**: `theme.colors().background` gibi accessor olmadan `styles` alanına doğrudan erişim zorunlu hale gelir; iç düzen değiştiğinde tüm tüketici kodu kırılır. Accessor yazılması şarttır.
7. **Public API'ye `kvs_default_dark` doğrudan koymak**: `pub use fallback::*` yerine namespace altında tutmak (`pub mod fallback { pub use crate::fallback::{...}; }`) niyetin açık görünmesini sağlar — tüketici `kvs_tema::fallback::kvs_default_dark` ifadesini yazarak amaca işaret eder.

### Son public yüzey — küçük ama atlanabilir parçalar

Aşağıdaki öğeler ana sözleşme kadar büyük görünmeyebilir, ama tema crate'i birebir mirror edilecekse public yüzey kararlarına dahil edilmelidir. Listeyi isim ezberiyle değil, owner/metot/alan ilişkisiyle okumak daha yararlıdır: `content = runtime`, `reflection ⊆ runtime`.

| Öğe | Karar |
| :-- | :-- |
| `DEFAULT_DARK_THEME` (`theme`) ve `DEFAULT_LIGHT_THEME`, `DEFAULT_DARK_THEME` (`settings_content` crate'i) | İki ayrı tanım vardır: `theme` yalnızca `DARK`'ı re-export eder, `settings_content` ikisini de tanımlar (`'One Light'` / `'One Dark'`). Mirror'da **tek kaynak**: `kvs_ayarlari_icerik::theme` sabitleri, `kvs_tema` `pub use` ile yeniden açar |
| `CLIENT_SIDE_DECORATION_ROUNDING`, `CLIENT_SIDE_DECORATION_SHADOW` (`px(10.0)`) | Tema renk sözleşmesi değildir; client-side window decoration shadow/corner radius token'ıdır. `kvs_pencere`/`kvs_ui` tarafına ayrılır; değer Zed referansıyla birebir tutulur (`px(10.0)`) |
| `DEFAULT_ICON_THEME_NAME` | Aktif icon theme fallback seçimi için gereklidir; icon theme registry mirror edildiğinde taşınmalıdır |
| `ThemeNotFoundError`, `IconThemeNotFoundError` | Registry public API'sinin typed error yüzeyidir; string error'a düşürülmemesi gerekir |
| `zed_default_themes()` | Test/fallback family üretir; GPL kod gövdesi kopyalanmaz, bağımsız bir `kvs_default_themes()` yazılır |
| `default_color_scales()` | 33 scale set'lik palet matrisidir; yalnızca `ColorScale` mirror kararı verildiğinde taşınır |
| `Theme::darken(color, light_amount, dark_amount)` | Appearance'a göre lightness azaltan bir yardımcıdır; bileşen tarafında kullanılacaksa helper olarak mirror edilebilir |
| `SystemAppearance::global_mut(cx)` | Sistem görünümünü testte veya platform event'inde güncellemek için bir kapıdır |
| `ThemeRegistry::insert_themes`, `.clear()` | Test, import ve kullanıcı tema yenileme akışında gerekir |
| `ThemeRegistry::register_test_themes`, `.register_test_icon_themes` | `test-support` gated helper'dır; üretim API'si olarak dışa açılmaz |
| `Redistributable değildir: FontFamilyCache` | Sözleşmenin dışında kalır, ancak public metotları 43.8'de not edilmiştir |
| `ThemeSettingsProvider::ui_font`, `.buffer_font` | Provider font objesini de verir; yalnızca font size/density ile sınırlı değildir |
| `ThemeSettingsContent` typography alanları | `FontSize`, `FontFamilyName`, `FontFeaturesContent`, `BufferLineHeight`, `CodeFade` ilgili bölüme eklenmiştir |
| `ThemeSelection::mode`, `IconThemeSelection::mode` | Selector UI'nın hangi slot'un aktif olduğunu göstermesi için gereklidir |
| `GlobalTheme::new`, `.update_theme`, `.update_icon_theme`, `.theme`, `.icon_theme` | Zed public API'sinin tamamıdır. `set_theme_and_icon`, `set_theme`, `set_icon_theme` metotları **yoktur** — set yerine `cx.set_global(GlobalTheme::new(...))` ile init yaparsın, sonra `update_*` ile değişim yürütülür |
| `theme_settings::settings::set_theme`, `set_icon_theme`, `set_mode` | Kullanıcı `SettingsContent`'ini mutate eden public mutator helper'lardır. Runtime global'i **değil**; selector confirm akışında dosya yazımından önce çağırırsın. Mirror tarafında `kvs_secici` veya `kvs_tema_ayarlari` crate'inde yer alır |
| `theme_settings::settings::appearance_to_mode`, `default_theme` | `Appearance` ↔ `ThemeAppearanceMode` köprüsü ve fallback ad seçimi; selector/observer akışında kullanılır |
| `theme_settings::theme_settings::reload_theme`, `reload_icon_theme`, `load_user_theme`, `deserialize_user_theme`, `refine_theme_family`, `refine_theme`, `merge_player_colors`, `merge_accent_colors`, `increase_buffer_font_size`, `decrease_buffer_font_size` | Zed'in JSON → Theme pipeline'ının ve runtime tema reload akışının kanonik fonksiyonlarıdır. İlgili bölümlerde ayrıntılı işlenir |
| `theme_settings::settings::adjust_buffer_font_size`, `reset_buffer_font_size`, `adjust_ui_font_size`, `reset_ui_font_size`, `adjust_agent_ui_font_size`, `reset_agent_ui_font_size`, `adjust_agent_buffer_font_size`, `reset_agent_buffer_font_size`, `clamp_font_size`, `adjusted_font_size`, `observe_buffer_font_size_adjustment`, `setup_ui_font` | Runtime font ölçekleme override global'leri ve helper'larıdır. Ayar UI ve shortcut tarafında kullanılır |
| `ThemeSettings::*_font_size_settings`, `markdown_preview_font_family`, `markdown_preview_code_font_family` | Ayar dosyasındaki baz değerleri override global'lerinden ayıran accessor'lardır. Markdown preview text fontu UI fontuna, preview code fontu buffer fontuna fallback eder. `theme_settings::init` observer'ı `*_settings()` değerlerini izleyip runtime font override global'lerini sıfırlar |
| `AgentUiFontSize`, `AgentBufferFontSize` newtype global'leri | Agent panel font override'ı için `Global`-impl'lenmiş `Pixels` newtype'larıdır. `BufferFontSize` private, `UiFontSize` `pub(crate)`'tir; root `pub use` listesine girmez |
| `theme_settings::schema::syntax_overrides`, `theme_colors_refinement`, `status_colors_refinement` | Content → Refinement dönüşüm fonksiyonlarının kanonik adlarıdır. **`theme_colors_refinement` 3 parametrelidir** (`this`, `status_colors`, `is_light`); fallback zincirleri ve diff-hunk opacity'leri ilgili bölümde tam tablo halinde verilir |
| `theme_colors_refinement` fallback zincirleri | `version_control_* → status.*`, `minimap_thumb_* → scrollbar_thumb_*` (alpha max `0.7`), `panel_overlay_* → panel_background` (+ `element_hover` blend), document highlight / Vim / Helix fallback'leri ve `editor_diff_hunk_* → version_control_* × LIGHT/DARK_DIFF_HUNK_*_OPACITY`. İlgili bölüm tablosu eksiksiz listeler |
| `LIGHT_DIFF_HUNK_FILLED_OPACITY`, `DARK_DIFF_HUNK_FILLED_OPACITY`, `LIGHT_DIFF_HUNK_HOLLOW_BACKGROUND_OPACITY`, `DARK_DIFF_HUNK_HOLLOW_BACKGROUND_OPACITY`, `LIGHT_DIFF_HUNK_HOLLOW_BORDER_OPACITY`, `DARK_DIFF_HUNK_HOLLOW_BORDER_OPACITY` | Referans değerler sırasıyla `0.16 / 0.12 / 0.08 / 0.06 / 0.48 / 0.36`. Modül-özel `const` sabitlerdir (modül dışına zaten görünmez), tüketici görünür sözleşme değildir; sayıların mirror'da `kvs_tema_ayarlari` modülünde aynı tutman gerekir |
| `apply_theme_color_defaults` kaynak rengi | `text_accent × 0.25` **değil** — `player_colors.local().selection`; alpha 1.0 ise 0.25'e çekilir, aksi halde olduğu gibi atarsın. İlgili bölümde ayrıntılıdır |
| `refine_theme` adım sırası | `status_colors_refinement → apply_status_color_defaults → status.refine → merge_player_colors → theme_colors_refinement(c, &status_ref, is_light) → apply_theme_color_defaults(&player) → colors.refine → merge_accent_colors → inline syntax map + Arc::new(SyntaxTheme::new(...))`. İlgili bölümde ayrıntılı |
| `pub fn syntax_overrides(style) -> Vec<(String, HighlightStyle)>` | Override map'i `IndexMap<String, HighlightStyleContent>` → `Vec<(String, gpui::HighlightStyle)>` çevirir. 4 alan (`color`, `background_color`, `font_style`, `font_weight`) parse edilir; underline/strikethrough/fade_out `Default::default()`'tan gelir. `ThemeSettings::modify_theme` içindeki `SyntaxTheme::merge`'in beklediği imzadır |
| `ThemeSettings::modify_theme` override akışı | Full `refine_theme` değildir: `apply_status_color_defaults` veya `apply_theme_color_defaults` çağırmaz; status/theme refinement'ı doğrudan uygular, player/accent merge eder ve syntax için `SyntaxTheme::merge(base, syntax_overrides(...))` kullanır |
| `SyntaxTheme::merge(base, overrides) -> Arc<Self>` | **Field-bazlı merge**: aynı capture varsa `new.<f>.or(existing.<f>)` ile birleştirir; capture yeni ise listenin sonuna eklersin. Override boşsa baseline klonsuz döner. İlgili bölüm + settings seviyesi theme override akışında kanonik kullanımdır |
| `ThemeName`, `IconThemeName`, `ThemeAppearanceMode`, `FontFamilyName` re-export zinciri | Owner `settings_content`'tir; `theme_settings` `pub use` ile köprü kurarsın. Mirror'da `kvs_ayarlari_icerik` (veya muadili) tek kaynaktır, `kvs_tema_ayarlari` yalnızca `pub use` ile yeniden açar; aynı tipin iki yerde tanımlanması tip kimliği ayrışmasına yol açar |
| `Theme.styles` görünürlüğü | Zed'de **`pub styles: ThemeStyles`** (alan-bazlı). Yerel tasarım accessor disiplini için `pub(crate)` seçebilirsin; bu yerel bir sıkılaştırmadır. Zed paritesi `pub`'tır |
| `ThemeStylesRefinement` | `#[derive(Refineable)]` tarafından `ThemeStyles` için üretilen public refinement tipidir. Nested `colors` ve `status` override zinciri için kullanılır; mirror tarafında derive çıktısı veya elle yazılmış eşdeğeri public kapsama dahil edilmelidir |
| `ThemeColorFieldIter` | `ThemeColorField` üzerindeki `EnumIter` derive çıktısıdır. Doğrudan elle import etmek yerine `ThemeColorField::iter()` ve `all_theme_colors(cx)` üzerinden tüketilmesi önerilir; rustdoc public API'de ayrı tip olarak görünür |
| `ThemeFamily` alan görünürlüğü | `id`, `name`, `author`, `themes`, `scales` alanlarının tamamı `pub`'tır. `scales: ColorScales` alanı hedeflenen referansta 33 paleti taşır |
| `PlayerColors::color_for_participant(idx)` | Collab kullanıcı renkleri için `modulo (len - 1) + 1` offset'li lookup; **local slot'u (idx 0) atlar**, participant 0 listenin idx 1'inden başlar. İlgili bölümde işlenmiştir, 43.9'da resmi imzası verilir |
| `PlayerColors::agent()`, `.absent()` davranışı | İkisi de listenin son slotunu fail-fast açarak döner — yani **agent ve absent player aynı slot'tur** (listenin son elementi). Fallback temalarda son slot'un boş bırakılmamasının nedeni budur |
| `theme::init` davranışı | `SystemAppearance::init → ThemeRegistry::set_global(assets, cx) → FontFamilyCache::init_global → default_global → themes.get(DEFAULT_DARK_THEME) (yoksa list().next()) → default_icon_theme sonucunu fail-fast açma → cx.set_global(GlobalTheme { theme, icon_theme })`. `GlobalTheme::new` çağrısı yerine doğrudan struct literal kullanılır (her ikisi de mümkündür) |
| `Appearance::is_light`, `From<WindowAppearance>` | `is_light` `matches!(self, Light)`'tan kısadır. `From<WindowAppearance>`: `Dark` ve `VibrantDark` → `Dark`; `Light` ve `VibrantLight` → `Light` (vibrant varyantları normal mapping'e düşer) |
| `SystemAppearance::Default = Dark` | Sistem görünümü alınamadığında default Dark değeri alırsın. Mirror tarafında aynı varsayılan tutman gerekir; aksi halde init önce ekrana light tema gelir, sonra sistem dark olduğunda dark'a sıçrama oluşur |
| `theme_settings::settings::BufferLineHeight` (`Comfortable`, `Standard`, `Custom(f32)`), `value()` | `Standard = 1.3`, `Comfortable = 1.618`, `Custom` doğrudan değer alır. Settings tarafında `f32 >= 1.0` kısıtı vardır (`settings_content` crate'i) |
| `try_parse_color` (`theme` crate'i) | ilgili bölümde ayrıntılıdır; 43.9'da public helper olarak teyit edilir |
| `gpui::Rgba::try_from(&str)` desteklediği formatlar | **Dört format**: `#rgb` (3 hane, çiftleme), `#rgba` (4 hane, çiftleme), `#rrggbb` (6 hane), `#rrggbbaa` (8 hane). `#` zorunludur; trim yaparsın. İlgili bölümde ayrıntılı |
| `AppearanceContent` (`theme` crate'i) | JSON `appearance` alanının enum mirror'ı (`Light` / `Dark`); ilgili bölümde kullanılır |
| `theme_settings::init` observer 8 değişken tracking'i | Ayar değişiminde `reset_*_font_size` (buffer, UI, agent UI, agent buffer, git commit buffer = 5), `reload_theme` (theme_name veya overrides = 2) ve `reload_icon_theme` (1) izlersin. Toplam 8 izleme değeri vardır; bu alanlardan biri takip edilmediğinde ilgili runtime override güncel ayarla uyumsuz kalır. İlgili bölümde ayrıntılı |
| `theme_settings::init` 2 katmanlı init paritesi | `theme::init` (registry + fallback dark + GlobalTheme) çağrıldıktan sonra `set_theme_settings_provider`, `load_bundled_themes` (LoadThemes::All ise), `configured_theme` ile settings'ten gelen seçim çözülür ve `GlobalTheme::update_theme` + `update_icon_theme` ile aktif tema atarsın. Mirror'da iki ayrı `init` fonksiyonunun korunması gerekir; tek `kvs_tema::init`'te birleştirilmesi bağımlılık matrisini bozar |
| `Theme.styles.syntax` baseline davranışı | `refine_theme` `Arc::new(SyntaxTheme::new(syntax_overrides))` çağırır — yani baseline syntax kullanılmaz, **tema JSON'unda syntax bloğu boşsa sonuç boş syntax theme** olur. Yazarın `syntax: { ... }` doldurması beklenir; aksi halde editor highlight'sız kalır. İlgili bölümde ayrıntılı |
| `ThemeSettings::modify_theme` görünürlüğü | Aslında `fn` — **private**. `pub fn apply_theme_overrides(&self, arc_theme: Arc<Theme>) -> Arc<Theme>` üzerinden çağrılır; tüketici doğrudan `modify_theme` çağıramaz. Public yüzey `apply_theme_overrides`'tır |
| `ThemeRegistry::new` davranışı | Constructor **zaten dolu döner**: `insert_theme_families([zed_default_themes()])` çağrısı ve `default_icon_theme()` (`DEFAULT_ICON_THEME_NAME`) icon haritasına yerleştirme yapar. Mirror tarafında da aynı garanti tutman gerekir; aksi halde `default_icon_theme()` çağrısı `Err` döner |
| `ThemeRegistry::list_names()` sıralama | `Vec<SharedString>` döner ve **sıralıdır** (`names.sort()`). Buna karşılık `list()` (`Vec<ThemeMeta>`) **sıralı değildir** — HashMap.values() üzerinden doğrudan map'lenir. Selector UI sıralı liste isterse `list_names` veya manuel sort gerekir |
| `ThemeRegistry::clear()` davranışı | Yalnızca `themes` HashMap'ini temizler — `icon_themes` HashMap'ine **dokunmaz**. Test/reset senaryolarında icon themes ayrıca `remove_icon_themes(...)` ile temizlemen gerekir |
| `ThemeRegistry::load_icon_theme` baseline merge davranışı | Yüklenen icon theme'in `file_stems`, `file_suffixes`, `named_directory_icons` haritaları **default icon theme üstüne extend edilir**. `file_icons`, `directory_icons`, `chevron_icons` constructor'da default'tan kopyalanmaz; UI lookup eksik dosya tipi, klasör ve chevron path'lerinde `file_icons` crate'i üzerinden default icon theme'e düşer. Her tema için yeni UUID atanır |
| `icon_theme_schema` re-export sınırı | Modülün kendisi `mod icon_theme_schema` ile private'tır; root `pub use crate::icon_theme_schema::*` yalnızca `IconThemeFamilyContent`, `IconThemeContent`, `DirectoryIconsContent`, `ChevronIconsContent`, `IconDefinitionContent` tiplerini açar. Mirror'da `kvs_tema::icon_theme_schema` path'i ancak bilinçli bir tasarım kararıysa public yapman gerekir |
| `SyntaxTheme::one_dark()` | `#[cfg(feature = "bundled-themes")]` altında public helper'dır. Bundled `one/one.json` içinden `"One Dark"` syntax theme'i yükler; feature kapalıyken public API'de bulunmaz. Üretim tema yükleme hattı yerine test/dev fixture olarak düşünülmesi yerinde olur |
| `Refineable` trait yüzeyi tam katalog | `Refineable`: `refine`, `refined`, `from_cascade`, `is_superset_of`, `subtract`; `IsEmpty`: `is_empty`; `Cascade<S>` metotları: `reserve`, `base`, `set`, `merged`; `CascadeSlot` yalnız slot handle'ıdır. Tema sistemi `from_cascade`/`Cascade` kullanmaz ama refineable trait sözleşmesi tam mirror edilmelidir |
| `#[with_fallible_options]` macro | `Option<T>` alanlarına otomatik olarak `#[serde(default, skip_serializing_if = "Option::is_none", deserialize_with = "crate::fallible_options::deserialize")]` ekler. `ThemeSettingsContent`, `ThemeStyleContent`, `ThemeColorsContent`, `StatusColorsContent` gibi tiplerde kullanılır; parse hatası alan `None`'a düşer ve hata thread-local hata listesine eklenir |
| `fallible_options::parse_json`, crate-private `deserialize` | Top-level parse fonksiyonu (`parse_json::<T>(json) -> (Option<T>, ParseStatus)`) public re-export edilir; thread-local `ERRORS` listesi parse sırasında biriken hataları toplar. `deserialize` ise `pub(crate)` internal helper'dır, macro'nun eklediği serde attribute'u kullanır |
| `RootUserSettings::parse_json`, `parse_json_with_comments` | `SettingsContent`, `Option<SettingsContent>` ve `UserSettingsContent` için public root parse trait'idir. `parse_json` fallible option tolerant hattını, `parse_json_with_comments` ise normal `settings_json::parse_json_with_comments` sonucunu döner |
| `HighlightStyleContent::treat_error_as_none` istisnası | `HighlightStyleContent` `#[with_fallible_options]` kullanmaz. Yalnızca `background_color`, `font_style`, `font_weight` alanlarında yerel `treat_error_as_none` bulunur; `color` alanında bulunmaz. Bu yüzden `font_style` bilinmeyen enum olduğunda `None` döner, ama `"color": 3` bir deserialize hatası üretir |
| Tema dosyası parse yolu | Bundled tema asset'leri `serde_json::from_slice` ile, kullanıcı tema dosyaları `serde_json_lenient::from_slice` ile parse edersin. Bu hatlar `RootUserSettings::parse_json` değildir; `with_fallible_options` hataları `ParseStatus` olarak toplamaz, normal serde hatası dönebilir |
| `MergeFrom` trait + derive | Primitive overwrite, `Option<T>` recursive merge, `Vec<T>` overwrite (concat değil), `HashMap`/`BTreeMap`/`IndexMap` key-bazlı recursive merge, `HashSet`/`BTreeSet` union, `serde_json::Value` Object recursive. İlgili bölümde davranış matrisi tam tablo olarak verilir |
| `ThemeSettingsContent.ui_density` JSON rename | `#[serde(rename = "unstable.ui_density")]` — kullanıcı JSON'unda **`"unstable.ui_density"`** yazmalıdır; `"ui_density"` çalışmaz. İlgili bölümde ayrıntılıdır |
| `ThemeSettingsContent` schemars tag'leri | `ui_font_fallbacks`, `buffer_font_fallbacks` `#[schemars(extend("uniqueItems" = true))]`; `unnecessary_code_fade` `#[schemars(range(min = 0.0, max = 0.9))]`; her font alanı `#[schemars(default = "...")]` ile default value fonksiyonu işaretlidir |
| `FontSize` newtype derive list'i | `Clone, Copy, Debug, Serialize, Deserialize, JsonSchema, MergeFrom, PartialEq, PartialOrd, derive_more::FromStr` ve `#[serde(transparent)]`. Serialize iki ondalık basamakla yapılır (`serialize_f32_with_two_decimal_places`). Display formatı `{:.2}`'dir |
| `UnderlineStyle`, `StrikethroughStyle` (`gpui::style:783-804`) | `UnderlineStyle { thickness, color, wavy }`, `StrikethroughStyle { thickness, color }`. İkisi de `Refineable + Copy + Eq + Hash + JsonSchema` türevlidir. Tema JSON sözleşmesinde syntax stillerinin underline/strikethrough alanları **yoktur**; `refine_theme` her ikisini de `Default::default()` (nötr) bırakır. İlgili bölümde işlendi |
| `HighlightStyle.fade_out` `Hash` impl | `f32` `Hash` türevini taşımaz; `to_be_bytes()` ile `u32`'ye çevrilip hash'lenir. Mirror tarafında elle implement edilir veya GPUI'nin `HighlightStyle`'ı doğrudan kullanılır |
| `ThemeRegistry::default()` | `Default for ThemeRegistry` impl'i `Self::new(Box::new(()))` — boş asset source ile constructor. Test'te `ThemeRegistry::default()` kısa yol olarak iş görür; asset gerektiren testler `Box::new(()) as Box<dyn AssetSource>` parametresini açık geçirir |
| `FileIcons::get_icon`, `get_icon_for_type` | `get_icon(path, cx)` 6 katmanlıdır: tam ad → dot-suffix loop → `multiple_extensions` → `extension_or_hidden_file_name` → ham `extension` → `"default"` tipi. Her katmanda `file_stems` veya `file_suffixes` aktif temasında lookup, sonra `get_icon_for_type(typ, cx)` ile `file_icons` aktif → default fallback yapılır |
| `FileIcons::get_folder_icon`, `get_chevron_icon` | Klasör fallback'i: `named_directory_icons` (klasör adına özel) → private `get_generic_folder_icon` ile `directory_icons` (jenerik); her ikisinde de aktif → default tema fallback. Chevron: yalnızca aktif → default. Expanded/collapsed slot ayrımı her katmanda korunur |
| `ParseStatus` 3 variantlı | `Success`, **`Unchanged`** (dosya değişmediği için parse atlandı), `Failed { error: String }`. `Unchanged`, settings file watcher hattında "skip" sinyali için kritik bir varianttır |
| `SettingsContent.theme` flatten ilişkisi | `pub theme: Box<ThemeSettingsContent>` **`#[serde(flatten)]`** ile işaretlidir. Kullanıcı `settings.json`'da `ui_font_size`, `theme`, `icon_theme`, `unstable.ui_density` vb. **top-level** alanlar olarak yazar — iç `"theme": { ... }` bloğu **yoktur**. `SettingsContent` 25'ten fazla alt struct'ı flatten ile birleştirir; `Box` dinamik belleğe taşıyarak stack overflow'tan kaçınır |
| `UserSettingsContent` yapısı | `content: Box<SettingsContent>` flatten + `release_channel_overrides` flatten + `platform_overrides` flatten + `profiles: IndexMap<String, SettingsProfile>` düz alan. Yani `~/.config/zed/settings.json` `SettingsContent` alanlarını + override bloklarını + `"profiles": {...}` alanını taşır |
| `settings_overrides!` macro | `Option<Box<SettingsContent>>` alanlı override struct'lar üretir + `OVERRIDE_KEYS: &[&str]` derive eder + `get_by_key(key) -> Option<&SettingsContent>` accessor sunar. Release channel ve platform override'ları bu pattern ile tanımlıdır |
| `Settings` trait (`settings_store`) | Tam public yüzeyi şu metotlardan oluşur: `const PRESERVED_KEYS: Option<&'static [&'static str]> = None`, `from_settings(content: &SettingsContent) -> Self`, `register(cx: &mut App)`, `get<'a>(path: Option<SettingsLocation>, cx: &'a App) -> &'a Self`, `get_global(cx: &App) -> &Self`, `try_get(cx: &App) -> Option<&Self>`, `try_read_global<R>(cx: &AsyncApp, f: impl FnOnce(&Self) -> R) -> Option<R>`, `override_global(settings: Self, cx: &mut App)`. `ThemeSettings::get_global(cx)` bu trait'ten gelir; `from_settings` `SettingsContent.theme` flatten'ından typed `ThemeSettings` üretir |
| `SettingsStore` global'i | `register_setting::<T: Settings>()` ile typed setting tipini dispatch tablosuna ekler; ayar dosyası değiştiğinde her kayıtlı tipin `from_settings`'i çağırırsın. `cx.global::<SettingsStore>().get(None)` cache'lenmiş bir `&ThemeSettings` döner — accessor klonsuzdur ve hot path'tedir |
| `settings_json::parse_json_with_comments` | `serde_json_lenient::Deserializer` + `serde_path_to_error::deserialize`. Hata mesajları **field path'ini de gösterir** (örn. `theme.colors.background: invalid hex`); mirror tarafında da `serde_path_to_error` kullanılması kullanıcı deneyimini iyileştirir |
| `MergeFromTrait` re-export | `merge_from::MergeFrom` `pub use ... as MergeFromTrait` ile yeniden ihraç edersin. Aynı trait için iki ad: `MergeFrom` (derive macro + trait) ve `MergeFromTrait` (alias). Mirror tarafında tek bir ada karar verilmesi ve çakışma testlerinin yazılması yerinde olur |
| `HighlightStyleContent::is_empty()` | 4 alanın hepsi `None` ise `true` döner. Selector preview, snapshot test ve `MergeFrom` "no-op detection" akışında kullanırsın. `Refineable.is_empty` trait'inin elle muadilidir |
| `Refineable` derive `Option<T>` sarmalama kuralı | Düz `T` → `Option<T>`; `Option<T>` aynen `Option<T>` (tekrar sarmalanmaz); `#[refineable] U` → `URefinement` (nested recursive). İlgili bölümde tablo eklenmiştir |
| `configured_theme`, `configured_icon_theme` görünürlüğü | Aslında `fn` — **private**. Mirror tarafında `pub fn` yapmak yerel bir API genişletmesi anlamına gelir. Zed paritesinde `init` ve `reload_theme` bu helper'ları çağırır, tüketici doğrudan erişmez |
| `load_bundled_themes` hata davranışı | Her tema asset'i `log_err()` ile sarılır; parse hatası başlatmayı durdurmaz, log'lanır ve sonraki asset'e geçilir. Bu sayede tek bir bozuk bundled tema tüm Zed başlatmasını engellemez. Mirror tarafında aynı davranış zorunludur |
| `#[derive(RegisterSetting)]` auto-registration | Setting tipini `inventory::submit!` ile static registry'ye ekler. `SettingsStore::new` → `load_settings_types` → `inventory::iter` ile **link-time** olarak otomatik kaydedersin. `ThemeSettings` `#[derive(Clone, PartialEq, RegisterSetting)]` ile işaretlidir; `theme_settings::init` **elle register çağırmaz**. İlgili bölümde tam akış verilir |
| `inventory` crate auto-registration | Rust'ın link-time static registration için kullandığı crate'dir. Setting tipi tanımının yapıldığı yerde `submit!`, toplama tarafında `collect!` kullanırsın. Mirror'da alternatif (elle register listesi) seçildiğinde iki pattern'in karıştırılmaması gerekir; aksi halde sessiz kayıt eksiklikleri oluşur |
| `SettingsStore::override_global<T>` davranışı | Test ve runtime override için kullanırsın. `setting_values[TypeId::of::<T>()].set_global_value(Box::new(value))`. Doc note: "The given value will be overwritten if the user settings file changes" — yani settings dosyası değiştiğinde override drop edilir (observer akışı bunu garanti altına alır). Tip kayıtlı değilse kayıtlı olmayan setting tipi için fail-fast çalışır |
| `ThemeSettings` alan görünürlükleri | Font size alanları (`ui_font_size`, `buffer_font_size`, `agent_*_font_size`, `markdown_preview_font_family`, `markdown_preview_code_font_family`) **private**'tır; accessor metotlar (`ui_font_size(cx)`, `buffer_font_size(cx)` vb.) override-aware okuma yapar. Diğer alanlar (`ui_font`, `buffer_font`, `theme`, `icon_theme`, `theme_overrides`, `experimental_theme_overrides`, `buffer_line_height`, `markdown_preview_theme`, `ui_density`, `unnecessary_code_fade`) `pub`'tır. İlgili bölümde tam tablo verilir |
| `theme` crate'i `#![deny(missing_docs)]` | Crate-level lint zorlamasıdır: tüm public öğeler doc yorumu gerektirir. Mirror tarafında aynısı uygulandığında public API kalitesi artar; yeni bir alan eklendiğinde "doc yok" hatası sayesinde sözleşme atlanmaz |
| `theme` crate mod görünürlükleri | Tüm modüller (`default_colors`, `fallback_themes`, `font_family_cache`, `icon_theme`, `icon_theme_schema`, `registry`, `scale`, `schema`, `styles`, `theme_settings_provider`, `ui_density`) **private** `mod`'dur. Public yüzey yalnızca `pub use crate::<mod>::*` re-export ile gelir. `fallback_themes` istisnasında yalnızca `apply_status_color_defaults` ve `apply_theme_color_defaults` `pub use` ile açılır — diğer iç fonksiyonlar (`zed_default_dark` vb.) `pub(crate)` kalır |
| `ui::is_light(cx)` public helper | `cx.theme().appearance.is_light()` çağırır. UI tüketicileri için tekrar eden bir pattern; `kvs_ui` veya `kvs_bilesen` mirror'ında benzeri sağlanabilir. `ui::prelude` `pub use theme::ActiveTheme` ile trait'i tüketici crate'lere açar |
| `settings::IntoGpui` trait + 7 impl | `*Content` tiplerini GPUI runtime tiplerine çeviren tek köprüdür. İmpl edilen tipler: `FontStyleContent`, `FontWeightContent` (100-950 clamp), `FontFeaturesContent`, `WindowBackgroundContent`, `ModifiersContent`, `FontSize` (`px(self.0)`), `FontFamilyName` (`SharedString::from(self.0)`). `ThemeSettings::from_settings` her font alanında bu trait'i çağırır. Mirror tarafında `KvsIntoRuntime` veya benzeri bir trait gerekir |
| `markdown_preview_code_font_family` settings alanı | Markdown preview içindeki inline code ve code block fontunu ayrı seçer. Boş bırakıldığında `buffer_font.family` kullanılır; düz preview metni `markdown_preview_font_family` boş ise `ui_font.family` kullanmaya devam eder. Provider trait'i değişmez |
| Mermaid tema tüketimi | Mermaid renderer teması aktif `ThemeColors`, `PlayerColors`, `StatusColors`, `Appearance` ve `ThemeSettings::ui_font` üstünden üretilir. `Hsla` renkleri renderer'a alpha'sız `#rrggbb` olarak verirsin. Güncel `MermaidTheme` alanları `background`, `primary_*`, `secondary_color`, `tertiary_color`, `line_color`, `text_color`, `edge_label_background`, `cluster_*`, `note_*`, `actor_*`, `activation_*`, `git_branch_colors`, `git_branch_label_colors`, `er_attr_bg_*`, `error_color`, `warning_color` ve `accent_colors` set'idir. Git branch label renkleri `text_color_for_background` ile hesaplanır; vurgu sınıfları `.zed-accent-0..N` adlarıyla player slot'larından üretilir ve fill rengi `0.15` opacity ile Mermaid arka planına blend edersin. Diyagram fenced blok kapanmış (`metadata.is_fenced_closed`) olmalıdır; `~~~src` `.mermaid`/`.mmd` dosyaları da render hattına girer |
| `Markdown::invalidate_mermaid_cache` | `pub fn invalidate_mermaid_cache(&mut self, cx: &mut Context<Self>)`. `options.render_mermaid_diagrams` açıkken `mermaid_state` cache'ini temizler, parsed markdown'u yeniden render kuyruğuna atar ve `cx.notify()` çağırır. Tema observer'larından çağrılır; aksi halde tema değişimi mermaid SVG cache'inde kalır. `mermaid_showing_code: HashSet<usize>` Preview/Code sekme durumunu offset bazında tutar; `toggle_mermaid_tab(offset)` ve `is_mermaid_showing_code(offset)` `pub(crate)` yardımcılarıyla yönetilir |
| `MarkdownOptions::render_mermaid_diagrams`, `CopyButtonVisibility`, `WrapButtonVisibility` | `MarkdownOptions { render_mermaid_diagrams: true, ..Default::default() }` mermaid pipeline'ını açar; kapatıldığında hem cache hem `mermaid_showing_code` boşaltılır. Mermaid render fonksiyonu sekme başlığı ve kopya butonu için `copy_button_visibility` değerini okur; `CopyButtonVisibility::Hidden` seçildiğinde ikisi de çizilmez. `wrap_button_visibility` normal code block toolbar sözleşmesinin alanıdır ve Mermaid render fonksiyonu tarafından kullanılmaz, ancak `CodeBlockRenderer::Default` struct literal'i yazarken alanın sağlanması gerekir. Bu yüzey markdown render hattının parçasıdır, tema crate'inde değildir |
| `gpui::Hsla::opaque_strategy`, `Arbitrary for Hsla` | `proptest` feature'ı altında renk property testleri için resmi generator'dır. Kontrast/türetme helper'larında sentetik örneklerin yanına property test ekleyebilirsin |
| `CompletionMenuItemKind` ve syntax rengi | `EditorSettingsContent.completion_menu_item_kind` enum'u `off` / `symbol` değerlerini taşır. `symbol` açıkken completion kind rozetleri `constructor`, `constant`, `enum`, `function.method`, `function`, `namespace`, `operator`, `property`, `string`, `type`, `variable`, `variant`, `keyword` capture'larından beslenir; noktalı capture yoksa parent capture fallback'i denenir. Bu ayar `ThemeSettingsContent` alanı değildir |
| Content/Runtime tip duplication ve `From` impls | `ThemeSelection`, `IconThemeSelection`, `BufferLineHeight` **iki yerde tanımlıdır**: settings_content (Content, `JsonSchema/MergeFrom/EnumDiscriminants`) ve theme_settings (Runtime, daha az derive). Aralarında `From<settings::*>` impl bulunur. `UiDensity` için `ui_density_from_settings` `pub(crate)` helper kullanılır (`From` değil). İlgili bölüm ve 43.3'te açıklanmıştır |
| `ThemeSettings::from_settings` fail-fast kontratı | Her font ve theme alanı fail-fast açılır — yani `default.json` zorunlu alanları (`ui_font_size/family/features/weight`, `buffer_font_*`, `buffer_line_height`, `theme`, `icon_theme`, `unnecessary_code_fade`) doldurmak zorundadır. Boş olduğunda init erken durur. Mirror'da `kvs_default_settings.json` aynı zorunlu set'i taşımalıdır |
| `ThemeSelection::Default`, `IconThemeSelection` derive list'i | Content tipleri `JsonSchema, MergeFrom, EnumDiscriminants, VariantArray, VariantNames, FromRepr` derive eder. `ThemeSelection::default() = Dynamic { mode: System, light: "One Light", dark: "One Dark" }`. Selector UI tabbed picker için `strum::VariantArray` ve `EnumDiscriminants` kullanılır |
| `ThemeAppearanceMode` derive ve default | `Copy + Default + strum::VariantArray + strum::VariantNames` derive'larıyla birlikte gelir; `#[default] System` varyantını taşır. `serde(rename_all = "snake_case")` ile JSON'da `"light"`, `"dark"`, `"system"` biçiminde görünür |
| `BufferLineHeight::Custom` 1.0 alt sınır deserializer | `#[serde(deserialize_with = "deserialize_line_height")] f32` özel fonksiyonu kullanılır; 1.0 altındaki değer **deserialize hatası** üretir. Çift savunma: parse'ta 1.0 alt sınır + runtime `ThemeSettings::line_height()` `f32::max(.., MIN_LINE_HEIGHT)` |
| `ThemeSettings::line_height()` + `MIN_LINE_HEIGHT` | `MIN_LINE_HEIGHT = 1.0`. Buffer renderer satır yüksekliği için bu accessor kullanılır; ham `BufferLineHeight.value()` doğrudan döndürülmez — geçersiz değerlerden korunmak amacıyla clamp yapılır |
| `ColorScales` `IntoIterator` impl | 33 paleti **sabit bir sırada** (`gray, mauve, slate, sage, olive, sand, gold, bronze, brown, yellow, amber, orange, tomato, red, ruby, crimson, pink, plum, purple, violet, iris, indigo, blue, cyan, teal, jade, green, grass, lime, mint, sky, black, white`) `Vec<ColorScaleSet>` olarak yayar. Snapshot test ve color picker için kanonik bir dolaşımdır. İlgili bölümde işlenmiştir |
| `FontFamilyName` impls | `#[serde(transparent)]` newtype + `AsRef<str>` + `From<String>` + `From<FontFamilyName> for String`. `Arc<str>` taşır, klonsuz `SharedString`'e dönüşür (`IntoGpui::into_gpui()`) |
| `FontWeightContent::into_gpui()` 100-950 clamp | `FontWeight(self.0.clamp(100., 950.))` — CSS font-weight aralığında zorlama yapar. `FontWeightContent::{THIN, EXTRA_LIGHT, ..., BLACK}` const'larının GPUI `FontWeight` const'larıyla eşleştiği test ile doğrulanır (`content_into_gpui`) |
| `settings::private` modülü | `pub mod private { pub use inventory; pub use crate::settings_store::{RegisteredSetting, SettingValue}; }`. `RegisterSetting` derive macro `settings::private::inventory::submit!` çağırır. Mirror tarafında `kvs_ayarlari::private` benzeri bir modül zorunludur; aksi halde macro çıktısı derlenmez |
| `theme_settings` re-export listesi | `schema::{FontStyleContent, FontWeightContent, HighlightStyleContent, StatusColorsContent, ThemeColorsContent, ThemeContent, ThemeFamilyContent, ThemeStyleContent, WindowBackgroundContent, status_colors_refinement, syntax_overrides, theme_colors_refinement}` ve `settings::{AgentBufferFontSize, AgentUiFontSize, GitCommitBufferFontSize, BufferLineHeight, FontFamilyName, IconThemeName, IconThemeSelection, ThemeAppearanceMode, ThemeName, ThemeSelection, ThemeSettings, adjust_*, reset_*, adjusted_font_size, appearance_to_mode, clamp_font_size, default_theme, observe_buffer_font_size_adjustment, set_icon_theme, set_mode, set_theme, setup_ui_font}` + `pub use theme::UiDensity`. Mirror tarafında bu sembollerin tek kaynak crate'inden re-export edilmesi gerekir |

Küçük metot yüzeyleri:

```rust
AccentColors::color_for_index(index)
PlayerColors::agent()
PlayerColors::absent()
PlayerColors::read_only()
ThemeColors::to_vec()
UiDensity::spacing_ratio()
ColorScale::step_1()
ColorScale::step_2()
ColorScale::step_3()
ColorScale::step_4()
ColorScale::step_5()
ColorScale::step_6()
ColorScale::step_7()
ColorScale::step_8()
ColorScale::step_9()
ColorScale::step_10()
ColorScale::step_11()
ColorScale::step_12()
ColorScale::step(step)
ColorScaleSet::new(name, light, light_alpha, dark, dark_alpha)
ColorScaleSet::name()
ColorScaleSet::light()
ColorScaleSet::light_alpha()
ColorScaleSet::dark()
ColorScaleSet::dark_alpha()
ColorScaleSet::step(cx, step)
ColorScaleSet::step_alpha(cx, step)
ThemeSettingsProvider::ui_font(cx)
ThemeSettingsProvider::buffer_font(cx)
ThemeSelection::mode()
IconThemeSelection::mode()
ThemeSelection::name(system_appearance)
IconThemeSelection::name(system_appearance)
ThemeSettings::buffer_font_size(cx)
ThemeSettings::ui_font_size(cx)
ThemeSettings::agent_ui_font_size(cx)
ThemeSettings::agent_buffer_font_size(cx)
ThemeSettings::git_commit_buffer_font_size(cx)
ThemeSettings::markdown_preview_font_family()
ThemeSettings::markdown_preview_code_font_family()
Markdown::invalidate_mermaid_cache(cx)
ThemeSettings::buffer_font_size_settings()
ThemeSettings::ui_font_size_settings()
ThemeSettings::agent_ui_font_size_settings()
ThemeSettings::agent_buffer_font_size_settings()
ThemeSettings::git_commit_buffer_font_size_settings()
ThemeSettings::line_height()
ThemeSettings::apply_theme_overrides(arc_theme)
Theme::darken(color, light_amount, dark_amount)
BufferLineHeight::value()
default_theme(appearance) -> &'static str
appearance_to_mode(appearance) -> ThemeAppearanceMode
clamp_font_size(size) -> Pixels
adjusted_font_size(size, cx) -> Pixels
```

Bu metotlar rehberin ana akışını değiştirmez. Ancak tema editörü, collab renkleri, density ölçümü ve snapshot karşılaştırması yazıldığında doğrudan public API ihtiyacına dönüşürler.

---

## 44. Test ortamında tema sahteleme

UI bileşenleri test edilirken **tüm tema sistemini** init etmek çoğu zaman gerekmez. Yalnızca bileşenin renk ihtiyacını karşılayacak kadar bir sahte tema kurmak yeterli olabilir.

### Strateji 1: Tam init (`kvs_tema::init`)

En basit yol. Test'in başında tüm çalışma zamanını kurarsın:

```rust
use gpui::TestAppContext;
use kvs_tema::ActiveTheme;

#[gpui::test]
fn buton_tema_renklerini_kullanir(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx);  // Fallback temaları kurar

        let tema = cx.theme();
        assert_eq!(tema.appearance, kvs_tema::Appearance::Dark);
        assert_ne!(tema.colors().background, gpui::Hsla::default());
    });
}
```

**Avantaj:** Üretim akışına en yakın yöntemdir. Init uyumsuzlukları erken aşamada yakalanır.

**Dezavantaj:** Her test fallback tema oluşumu için ~50 µs harcar. Yüzlerce test koşulduğunda bu süre birikir.

### Strateji 2: Manuel kurulum (özel tema değerleri)

Test'in özel renk değerlerine ihtiyacı varsa kurulum elle yaparsın:

**Bu strateji `kvs_tema` crate'inin içinden çalışır.** `Theme { styles: ... }` literal'i `pub(crate)` alanlara erişim gerektirir. `kvs_tema/tests/` (entegrasyon testleri) **dış crate** sayılır; oradan struct literal yazılamaz. Bu manuel kurulum yalnızca `kvs_tema/src/test.rs` (Strateji 3) veya `kvs_tema` modülünün kendi birim testlerinde kullanırsın.

```rust
//içinde (crate-içi)
use std::sync::Arc;
use gpui::hsla;
use crate::{
    Theme, ThemeStyles, ThemeColors, StatusColors, PlayerColors,
    AccentColors, SystemColors, Appearance,
};

pub(crate) fn test_temasi(arka_plan: gpui::Hsla, on_plan: gpui::Hsla) -> Theme {
    Theme {
        id: "test".into(),
        name: "Test Teması".into(),
        appearance: Appearance::Dark,
        styles: ThemeStyles {
            window_background_appearance: gpui::WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors {
                background: arka_plan,
                text: on_plan,
                // ... diğer alanlar için sahte değer
                ..yedek_koyu_renkler()  // ← kalanlar yedekten
            },
            status: yedek_koyu_durum(),
            player: PlayerColors::default(),
            accents: AccentColors::default(),
            syntax: Arc::new(kvs_syntax_tema::SyntaxTheme::new(Vec::<(String, HighlightStyle)>::new())),
        },
    }
}
```

> **`..yedek_koyu_renkler()` yapılabilmesi için:** `ThemeColors`'a `Default` türevi eklenmesi veya `pub(crate) fn yedek_koyu_renkler() -> ThemeColors` adında bir yardımcı tanımlaman gerekir. Mevcut yapıda `ThemeColors`'ın `Default` türevi bulunmaz; tüm alanlar zorunludur. Bu nedenle test helper'ını yazman beklersin.
>
> **Dış crate'ten test:** `kvs_ui/tests/` içinde bu strateji çalışmaz. `feature = "test-support"` üzerinden Strateji 3'ün public helper'ları çağırırsın.

### Strateji 3: `kvs_tema` test helper'ı

`kvs_tema/src/test.rs` (yeni modül, `#[cfg(any(test, feature = "test-support"))]`):

```rust
#[cfg(any(test, feature = "test-support"))]
pub mod test {
    use crate::*;

    /// Test için minimal tema kurar.
    pub fn test_ortamini_baslat(cx: &mut gpui::App) -> anyhow::Result<()> {
        // ThemeRegistry::new AssetSource ister — testte `()` kullanılır.
        ThemeRegistry::set_global(Box::new(()) as Box<dyn gpui::AssetSource>, cx);
        let kayit = ThemeRegistry::global(cx);
        kayit.insert_themes([test_temasi()]);
        let tema = kayit.get("Test Teması")?;
        let ikon_tema = kayit.default_icon_theme()?;
        cx.set_global(GlobalTheme::new(tema, ikon_tema));
        Ok(())
    }

    /// Yeniden kullanılabilir test tema'sı.
    pub fn test_temasi() -> Theme {
        // Tüm alanları açık ama belirgin renklerle doldur
        // (hata ayıklama için kolayca ayırt edilir)
        let kirmizi = gpui::hsla(0.0, 1.0, 0.5, 1.0);
        let yesil = gpui::hsla(0.333, 1.0, 0.5, 1.0);
        Theme {
            id: "test".into(),
            name: "Test Teması".into(),
            appearance: Appearance::Dark,
            styles: ThemeStyles {
                colors: ThemeColors {
                    background: kirmizi,
                    border: yesil,
                    text: yesil,
                    // ... her alan benzersiz renkte (hata ayıklama için)
                },
                // ...
            },
        }
    }
}
```

Tüketici tarafında (`kvs_ui/tests/...`):

```rust
[dev-dependencies]
kvs_tema = { path = "../kvs_tema", features = ["test-support"] }
```

```rust
use kvs_tema::test::test_ortamini_baslat;

#[gpui::test]
fn render_test_temasini_kullanir(cx: &mut TestAppContext) -> anyhow::Result<()> {
    cx.update(|cx| -> anyhow::Result<()> {
        test_ortamini_baslat(cx)?;

        let tema = cx.theme();
        assert_eq!(tema.name.as_ref(), "Test Teması");
        Ok(())
    })?;
    Ok(())
}
```

### Snapshot test deseni

Tema değerlerinin **belirli yerlerde** kullanıldığını doğrulamak için:

```rust
use kvs_tema::test::{test_ortamini_baslat, test_temasi};

#[gpui::test]
fn buton_tema_arka_planiyla_cizilir(cx: &mut TestAppContext) -> anyhow::Result<()> {
    cx.update(|cx| -> anyhow::Result<()> {
        test_ortamini_baslat(cx)?;

        let tema = test_temasi();
        let beklenen_arka_plan = tema.colors().element_background;

        let buton = cx.new(|_| Buton::new("Tamam".into()));

        // Element ağacını incele (test API'ları rehber.md #75'te).
        // Veya çizilmiş sahneyi sorgula:
        let render_ciktisi = /* ... */;
        assert!(render_ciktisi.arka_plan_icerir(beklenen_arka_plan));
        Ok(())
    })?;
    Ok(())
}
```

> **GPUI test API'ları:** `TestAppContext::simulate_input`, `find_view` vb. rehber.md #75'te ayrıntılı işlersin. Render çıktısının test edilmesi tema'nın doğru okunduğunu doğrular; tema'nın **kendi** doğruluğu için ilgili bölüm fixture testleri yeterli olur.

### Tema değişimi simülasyonu

```rust
#[gpui::test]
fn ui_tema_degisiminde_guncellenir(cx: &mut TestAppContext) -> anyhow::Result<()> {
    cx.update(|cx| -> anyhow::Result<()> {
        kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx);
        let ilk = cx.theme().name.clone();

        // Açık temaya geç.
        kvs_tema::temayi_degistir("Kvs Varsayılan Açık", cx)?;

        let yeni_tema = cx.theme();
        assert_ne!(yeni_tema.name, ilk);
        assert_eq!(yeni_tema.appearance, kvs_tema::Appearance::Light);
        Ok(())
    })?;
    Ok(())
}
```

### Test'te `refresh_windows`

`TestAppContext` headless bir bağlamdır; açık pencere bulunmaz. `cx.refresh_windows()` hata üretmez ama görünür bir etkisi de olmaz. Tema değişimi test edilirken `cx.theme()` çağrısı **yeni değeri** döndürür; global hemen güncellersin.

UI bileşeninin gerçekten yeniden render edilip edilmediğini doğrulamak için `VisualTestContext` gerekir (rehber.md #75) — pencereyi açar, render eder ve snapshot karşılaştırması yapar.

### Tema Sahtelemede Dikkat Edilmesi Gereken Kullanım

```rust
// Bağlam dışı örnek: cx olmadan, struct literal ile tema oluşturmak
// (dış crate'te zaten derlenmez — `styles` pub(crate))
let tema = kvs_tema::fallback::kvs_default_dark();
let arka_plan = tema.colors().background;
let buton_arka_plan = arka_plan;  // ← bileşen rendering'i ile bağlantısı yok
```

Bu test yalnızca `Theme` struct'ının kendi alanlarını doğrular. **Tüketici kodun `cx.theme()` çağrısının doğru çalıştığını test etmez.** Bir UI testi hedefleniyorsa `TestAppContext::update` üzerinden global kurulum yapman gerekir.

### Test ortamı sınır listesi

| Test türü | Strateji | Bileşen |
| ----------- | ---------- | --------- |
| Sözleşme doğrulama (parse, refinement) | `#[test]` + fixture | — |
| Çalışma zamanı init/registry | `#[gpui::test]` + `init` | Strateji 1 |
| Bileşen tema okuma | `#[gpui::test]` + custom theme | Strateji 2 veya 3 |
| Visual snapshot (render çıktısı) | `VisualTestContext` | rehber.md #75 |
| Tema değişim akışı | `#[gpui::test]` + `temayi_degistir` | ilgili bölüm + bu konu |

### Dikkat Noktaları

1. **`kvs_tema::init(...)` veya test helper kurulumu**: `cx.theme()` global tema kurulmadan çağrıldığında çalışma zamanı erken durur. Her testin ilk adımında init veya manuel `cx.set_global(GlobalTheme::new(...))` kurulumu bulunmalıdır.
2. **`TestAppContext::run` yerine `update`**: Tema testleri sync çalışır; `update` doğru tercihtir. `run` async bir event loop kurar ve burada gerekmez.
3. **`test_temasi()` fixture maliyeti**: `set_global` her çağrıda üstüne yazar; birikimli state üretmez ama başarım maliyeti vardır. Test fixture olarak `Arc<Theme>` paylaşılabilir.
4. **`feature = "test-support"` kapsamı**: `#[cfg(any(test, feature = "test-support"))]` koşulunu kurarsın; release build'de kapalı kalır.
5. **Test tema'sının tüm alanlarının açık doldurulması**: `unsafe { zeroed() }` ile doldurulan bir test = üretimde görünmez bir UI'a karşılık gelir. Test sırasında bile tüm alanların açık değerle doldurulması, yakalama gücünü yükseltir.
6. **`refresh_windows` ve headless test ilişkisi**: `TestAppContext` üzerinde görünür render etkisi olmaz ama global state güncel kalır; test mantığı `cx.theme()` ile yeni değeri okur. `VisualTestContext` kullanıldığında ise render gerçek anlamda tetiklersin.
7. **Sahte tema için `Theme.id` ayrımı**: Test'te birden fazla tema kurulduğunda farklı `id`'leri (`"test-1"`, `"test-2"`) vermen gerekir; aksi halde `Theme.id` üzerinden yapılan equality testi beklenen ayrımı göstermez.

---
