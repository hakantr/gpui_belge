# Dış API ve test ortamı

Tüketiciye açılacak kararlı yüzeyi sınırla ve test ortamında tema mock düzenini kur.

---

## 43. Public API kataloğu ve crate-içi sınır

`kvs_tema` ve `kvs_syntax_tema` crate'lerinin **dışa açtığı** sözleşme
ile **iç implementasyon detayları** ayrımı. Bu sınır, Zed sözleşmesi
evrilse bile tüketici kodun kararlı kalması için kritik.

### Sınır felsefesi

| Kategori | Kararlı | Kim kullanır | Değişimde davranış |
|----------|---------|--------------|-------------------|
| **Public API (kararlı)** | ✓ | Tüketici UI bileşenleri | Major sürüm bump |
| **Public API (kararsız)** | Kısmen | İleri kullanıcı / extension yazarı | Minor sürüm değişebilir |
| **Crate-içi (`pub(crate)`)** | ✗ | Sadece `kvs_tema` modülleri | Patch sürümde değişebilir |

### `kvs_tema` public API kataloğu

**Veri tipleri (kararlı):**

```rust
pub use crate::Theme;            // accessor metotlarıyla okunur (Konu 12)
pub use crate::ThemeFamily;
pub use crate::Appearance;

pub use crate::styles::ThemeColors;
pub use crate::styles::StatusColors;
pub use crate::styles::PlayerColors;
pub use crate::styles::PlayerColor;
pub use crate::styles::AccentColors;
pub use crate::styles::SystemColors;

// Icon tema sözleşmesi (Konu 18)
pub use crate::icon_theme::{
    IconTheme, IconThemeFamily, IconDefinition,
    DirectoryIcons, ChevronIcons,
};
```

> **`ThemeStyles` listede YOK.** `Theme.styles` alanı `pub(crate)` —
> tüketici accessor'larla okur (`theme.colors()`, `theme.status()`).
> `ThemeStyles` tipini import etmek tüketici için anlamsız.

**Runtime (kararlı):**

```rust
pub use crate::runtime::ActiveTheme;             // cx.theme() için trait
pub use crate::runtime::GlobalTheme;
pub use crate::runtime::SystemAppearance;
pub use crate::runtime::init;
pub use crate::runtime::temayi_degistir;         // tek-yönlü helper (Konu 38)
pub use crate::runtime::temayi_yeniden_yukle;    // disk reload (Konu 38)
pub use crate::runtime::observe_system_appearance;  // pencere observer (Konu 35)
```

**Registry (kararlı):**

```rust
pub use crate::registry::{
    ThemeRegistry, ThemeMeta, ThemeNotFoundError, IconThemeNotFoundError,
};
```

**Fallback (kararlı, namespace altında):**

```rust
// kvs_tema::fallback::kvs_default_dark()
// kvs_tema::fallback::kvs_default_light()
pub mod fallback;   // pub modül; içeride sadece public fonksiyonlar
```

**Schema (KARARSIZ — extension/ileri kullanım için, tek tek ihraç):**

```rust
// Glob YASAK — yeni iç tip eklenince istemeden public olmaması için
// tek tek ihraç:
pub use crate::schema::{
    AppearanceContent, FontStyleContent, FontWeightContent,
    HighlightStyleContent, PlayerColorContent, StatusColorsContent,
    ThemeColorsContent, ThemeContent, ThemeFamilyContent,
    ThemeStyleContent, WindowBackgroundContent,
    try_parse_color,
};

// Icon tema Content tipleri (Konu 18)
pub use crate::icon_theme::{
    IconThemeContent, IconThemeFamilyContent,
    DirectoryIconsContent, ChevronIconsContent, IconDefinitionContent,
};
```

> **Schema kararsız:** Bu tipler JSON sözleşmesini taşır; Zed tarafında
> yeni alan/enum eklenebilir. Tüketici doğrudan
> `ThemeColorsContent` kullanırsa yeni alan parse'ında derleme bozulabilir.
> Mecbur değilse kullanma; `Theme::from_content` üzerinden çalış.

**`kvs_syntax_tema` public API:**

```rust
pub use SyntaxTheme;
```

Tek tip. `HighlightStyle` GPUI'den geliyor; re-export gereksiz.

### Crate-içi (NON-public) modüller

| Modül | İçerik | Erişim |
|-------|--------|--------|
| `refinement.rs` | `theme_colors_refinement`, `status_colors_refinement`, `apply_status_color_defaults`, `color()` helper | `pub(crate)` — sadece `Theme::from_content` çağırır |
| `runtime` iç detay | `GlobalThemeRegistry`, `GlobalSystemAppearance` newtype'ları | `pub(crate)` veya `pub(super)` |

**Neden gizli?** Refinement davranışı Zed'in evrimine bağlı. Türetme
kuralları (`apply_status_color_defaults`'ın 6 status listesi) değişebilir.
Tüketici bu fonksiyonu doğrudan çağırırsa kontrolün dışında bağlılık
oluşturur.

### Lib kökü yapısı (`kvs_tema/src/kvs_tema.rs`)

Konu 4'teki iskeletle **birebir aynı**. Burada özet:

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

// Crate-içi (gizli)
pub(crate) mod refinement;          // Bölüm VII

// Namespace altında public (kvs_tema::fallback::*)
pub mod fallback;

// Private dosya modülleri, içeriği selektif ihraç edilir
mod icon_theme;
mod registry;
mod runtime;
mod schema;
mod styles;

// Glob ihraç — kararlı modüller (yeni iç tip neredeyse hep public istenir)
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
// → ThemeStyles tipi crate-içi; ihraç edilmez (Konu 12)
```

**Pattern:**

- `pub(crate) mod refinement` — `refinement.rs` modülü dışarıya kapalı,
  içeride paylaşılır.
- `pub use module::*` — kararlı modüller için tüm-ihracı; her iç tipin
  public olmasını istiyorsan glob; istemiyorsan tek tek.
- `pub use schema::{...}` — schema modülü için **glob YASAK** çünkü yeni
  iç implementasyon tipleri (mesela `serde` helper'ları) istemeden public
  olmasın.
- `pub mod fallback` — fallback fonksiyonları namespace altında
  (`kvs_tema::fallback::kvs_default_dark`). `fallback.rs` içinde sadece
  bu iki fonksiyon `pub`, diğer her şey `pub(super)` veya private.

### `prelude` modülü (önerilen)

```rust
// kvs_tema/src/prelude.rs
//! kvs_tema prelude — sık kullanılan tipleri tek import'a indirir.

pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily};
pub use crate::styles::{
    AccentColors, PlayerColor, PlayerColors,
    StatusColors, SystemColors, ThemeColors,
};
```

Tüketici:

```rust
use kvs_tema::prelude::*;
// Theme, ActiveTheme, ThemeColors, vs. hepsi mevcut
```

> **Prelude'a `ThemeRegistry`/`GlobalTheme` koymadık.** Bu tipler
> uygulama init/admin kodu içindir — UI bileşenleri kullanmaz. Render
> path'i prelude'unu hafif tut.

### Versiyon politikası (semver)

`kvs_tema` `0.x.y` aşamasındayken:

| Değişim | Sürüm bump |
|---------|------------|
| Public API'ye yeni alan/fn ekleme | `0.x.y+1` (patch) |
| Public API'de breaking change (alan kaldır, signature değiştir) | `0.x+1.0` (minor) |
| Mimari değişim (modül adı, prelude içerik) | `0.x+1.0` |
| Crate-içi (`pub(crate)`) değişim | `0.x.y+1` |

`1.0` sonrası:

| Değişim | Sürüm bump |
|---------|------------|
| Yeni alan/fn | Minor |
| Breaking | Major |
| Bug fix | Patch |

### Tüketici sözleşmesi

Tüketici kodu güvenle yapabileceği şeyler:

✓ `cx.theme().colors().background` okumak
✓ `kvs_tema::Theme`, `kvs_tema::ThemeColors` importlamak
✓ `ThemeRegistry::global(cx)` ile registry sorgulamak
✓ `kvs_tema::init(cx)` çağırmak
✓ `kvs_tema::temayi_degistir(ad, cx)` ile tema değiştirmek
✓ `kvs_tema::temayi_yeniden_yukle(yol, cx)` ile disk'ten reload
✓ `kvs_tema::observe_system_appearance(window, cx)` ile sistem mod takibi
✓ `kvs_tema::SystemAppearance::global(cx)` ile sistem mod sorgulamak
✓ `GlobalTheme::icon_theme(cx)` ile aktif icon tema okumak
✓ `ThemeRegistry::global(cx).list_icon_themes()` ile icon tema seçeneklerini listelemek

Tüketicinin yapamayacağı şeyler (compile hatası):

✗ `theme.styles.colors.X` yazmak — `styles` `pub(crate)`, accessor şart
✗ `GlobalThemeRegistry`/`GlobalSystemAppearance` newtype'larına dokunmak
  (private)

Tüketicinin yapmaması gerekenler (compile geçer ama kötü pratik):

✗ `kvs_tema::ThemeColorsContent` üzerinde `match` yazmak — schema
  kararsız (Konu 19)
✗ `kvs_tema::try_parse_color(...)` doğrudan çağırmak — `Theme::from_content`
  zaten sarmalıyor
✗ Tema yüklerken `baseline`'ı yanlış appearance ile seçmek (Konu 32)

### `pub(crate)` ile gerçek izolasyon

`pub use crate::refinement::*` yazdığında **`refinement` modülü public
olur** — istemediğin halde dışa açtın. `pub(crate) mod refinement;`
ile modülü gizli tut, `Theme::from_content` impl bloğunda direkt çağır:

```rust
// kvs_tema.rs
pub(crate) mod refinement;

// Theme::from_content impl içinde (crate-içi)
use crate::refinement::{theme_colors_refinement, ...};
```

`refinement.rs`'in fonksiyonları `pub` olabilir; modülün kendisi
`pub(crate)` olduğu için dışa görünmez. Çapraz API.

### Tüketici API sınırı örneği

`cargo doc --no-deps` çalıştırıp **sadece istediğin tiplerin
görünmemelidir:

```sh
cargo doc -p kvs_tema --no-deps --open
```

Doc sayfasında `theme_colors_refinement` veya `apply_status_color_defaults`
görünüyorsa `pub use` zincirini gözden geçir; sızıntı var.

### Tuzaklar

1. **`pub use crate::*`'da `refinement` yakalanmak**: `pub use
   crate::refinement::*` yazıp sonra modülü `pub(crate)` yapmak —
   compile hatası ("re-exporting private module"). İkisi tutarlı
   olmalı.
2. **`Theme.styles` alanını public yapmak (`pub`)**: Şu an public — iç
   düzen sızıyor. Accessor metotları sundun mu? `styles`'ı
   `pub(crate)` yap, sadece accessor'lardan oku.
3. **`schema::*` glob ile public yapmak**: Schema tiplerinin tamamı
   dışa açılır; gelecekte iç tipler eklersen otomatik public olurlar.
   Açık tek tek `pub use`:
   ```rust
   pub use crate::schema::{
       ThemeFamilyContent, ThemeContent, ThemeStyleContent,
       ThemeColorsContent, StatusColorsContent, PlayerColorContent,
       HighlightStyleContent, AppearanceContent, WindowBackgroundContent,
       FontStyleContent, FontWeightContent,
       try_parse_color,
   };
   ```
4. **Semver dışı değişim**: 0.x'te de tüketici beklentisi vardır.
   Breaking değişim minor bump olsa bile changelog yaz.
5. **`prelude::*` glob importları endüstri görüşü dışında**: Bazı
   stil rehberleri glob'u reddediyor. Tüketici karar verir; sen
   prelude'u sun, kullanmazsa elle import etsin.
6. **`pub` accessor metodu yazmamak**: `theme.colors().background`
   gibi accessor olmadan `styles` alanına doğrudan erişim zorunlu;
   iç düzen değişiminde tüm tüketici kırılır. Accessor şart.
7. **Public API'ye `kvs_default_dark` doğrudan koymak**: `pub use
   fallback::*` ile değil, namespace altında (`pub mod fallback {
   pub use crate::fallback::{...}; }`) — tüketici `kvs_tema::fallback::kvs_default_dark`
   yazar, niyet açık.

### Son public yüzey — küçük ama atlanabilir parçalar

Aşağıdaki öğeler ana sözleşme kadar büyük değildir, ama tema crate'i
birebir mirror edilecekse public yüzey kararına dahil edilmelidir. Liste,
isimden çok owner/metot ve alan ilişkisine göre okunmalıdır:
`content = runtime + deprecated`, `reflection ⊆ runtime`.

| Öğe | Kaynak | Karar |
| :-- | :-- | :-- |
| `DEFAULT_DARK_THEME` (`theme.rs:45`) ve `DEFAULT_LIGHT_THEME`, `DEFAULT_DARK_THEME` (`settings_content/src/theme.rs:282-283`) | `theme.rs` + `settings_content` | İki ayrı tanım var: `theme.rs` yalnızca `DARK`'ı re-export eder, `settings_content` ikisini de tanımlar (`'One Light'` / `'One Dark'`). Mirror'da **tek kaynak**: `kvs_ayarlari_icerik::theme` sabitleri, `kvs_tema` `pub use` ile yeniden açar |
| `CLIENT_SIDE_DECORATION_ROUNDING`, `CLIENT_SIDE_DECORATION_SHADOW` (`px(10.0)`) | `theme.rs:48-50` | Tema renk sözleşmesi değil; client-side window decoration shadow/corner radius token'ı. `kvs_pencere`/`kvs_ui` tarafına ayrılır; değeri Zed referansıyla birebir tut (`px(10.0)`) |
| `DEFAULT_ICON_THEME_NAME` | `icon_theme.rs` | Aktif icon theme fallback seçimi için gerekli; icon theme registry mirror ediliyorsa taşınmalı |
| `ThemeNotFoundError`, `IconThemeNotFoundError` | `registry.rs` | Registry public API'sinin typed error yüzeyi; string error'a düşürme |
| `zed_default_themes()` | `fallback_themes.rs` | Test/fallback family üretir; GPL kod gövdesi kopyalanmaz, bağımsız `kvs_default_themes()` yazılır |
| `default_color_scales()` | `default_colors.rs` | 33 scale set'lik palet matrisi; sadece `ColorScale` mirror kararı verilirse taşınır |
| `Theme::darken(color, light_amount, dark_amount)` | `theme.rs` | Appearance'a göre lightness azaltan yardımcı; component tarafında kullanılacaksa helper olarak mirror edilebilir |
| `SystemAppearance::global_mut(cx)` | `theme.rs` | Sistem görünümünü testte veya platform event'inde güncelleme kapısı |
| `ThemeRegistry::insert_themes`, `.clear()` | `registry.rs` | Test, import ve kullanıcı tema yenileme akışında gerekir |
| `ThemeRegistry::register_test_themes`, `.register_test_icon_themes` | `registry.rs` | `test-support` gated helper; üretim API'si olarak expose edilmez |
| `Redistributable değildir: FontFamilyCache` | `font_family_cache.rs` | Sözleşme dışı kalır, ama public metodları 43.8'de not edildi |
| `ThemeSettingsProvider::ui_font`, `.buffer_font` | `theme_settings_provider.rs` | Provider font objesini de verir; sadece font size/density değildir |
| `ThemeSettingsContent` typography alanları | `settings_content/src/theme.rs` | `FontSize`, `FontFamilyName`, `FontFeaturesContent`, `BufferLineHeight`, `CodeFade` Konu 39'ye eklendi |
| `ThemeSelection::mode`, `IconThemeSelection::mode` | `theme_settings/src/settings.rs` | Selector UI hangi slot'un aktif olduğunu göstermek için gerekir |
| `GlobalTheme::new`, `.update_theme`, `.update_icon_theme`, `.theme`, `.icon_theme` | `theme.rs` | Zed public API'sinin tamamı. `set_theme_and_icon`, `set_theme`, `set_icon_theme` metotları **yoktur** — set yerine `cx.set_global(GlobalTheme::new(...))` ile init, sonra `update_*` ile değişim |
| `theme_settings::settings::set_theme`, `set_icon_theme`, `set_mode` | `theme_settings/src/settings.rs:233-315` | Kullanıcı `SettingsContent`'i mutate eden public mutator helper'lar. Runtime global'i **değil**; selector confirm akışında dosya yazımından önce çağrılır. Mirror tarafında `kvs_secici` veya `kvs_tema_ayarlari` crate'inde yer alır |
| `theme_settings::settings::appearance_to_mode`, `default_theme` | `theme_settings/src/settings.rs:30, 89` | `Appearance` ↔ `ThemeAppearanceMode` köprüsü ve fallback ad seçimi; selector/observer akışında kullanılır |
| `theme_settings::theme_settings::reload_theme`, `reload_icon_theme`, `load_user_theme`, `deserialize_user_theme`, `refine_theme_family`, `refine_theme`, `merge_player_colors`, `merge_accent_colors`, `increase_buffer_font_size`, `decrease_buffer_font_size` | `theme_settings/src/theme_settings.rs:185-428` | Zed'in JSON→Theme pipeline'ının ve runtime tema reload akışının kanonik fonksiyonları. Konu 32 + Konu 38'de detaylı |
| `theme_settings::settings::adjust_buffer_font_size`, `reset_buffer_font_size`, `adjust_ui_font_size`, `reset_ui_font_size`, `adjust_agent_ui_font_size`, `reset_agent_ui_font_size`, `adjust_agent_buffer_font_size`, `reset_agent_buffer_font_size`, `clamp_font_size`, `adjusted_font_size`, `observe_buffer_font_size_adjustment`, `setup_ui_font` | `theme_settings/src/settings.rs` | Runtime font ölçekleme override global'leri ve helper'ları (Konu 39). Settings UI / shortcut tarafında kullanılır |
| `ThemeSettings::*_font_size_settings`, `markdown_preview_font_family`, `markdown_preview_code_font_family` | `theme_settings/src/settings.rs:412-455` | Settings dosyasındaki baz değerleri override global'lerinden ayıran accessor'lar. Markdown preview text fontu UI fontuna, preview code fontu buffer fontuna fallback eder. `theme_settings::init` observer'ı `*_settings()` değerlerini izleyip runtime font override global'lerini resetler |
| `AgentUiFontSize`, `AgentBufferFontSize` newtype global'leri | `theme_settings/src/settings.rs:108, 114` | Agent panel font override'ı için `Global`-impl'lenmiş `Pixels` newtype'ları (Konu 39). `BufferFontSize` private, `UiFontSize` `pub(crate)`; root `pub use` listesine girmez |
| `theme_settings::schema::syntax_overrides`, `theme_colors_refinement`, `status_colors_refinement` | `theme_settings/src/schema.rs:40, 237, 65` | Content → Refinement dönüşüm fonksiyonlarının kanonik adları. **`theme_colors_refinement` 3 parametrelidir** (`this`, `status_colors`, `is_light`); fallback zincirleri ve diff-hunk opacity'leri Konu 30'te tam tablo |
| `theme_colors_refinement` fallback zincirleri | `theme_settings/src/schema.rs:237-876` | `scrollbar_thumb_background → deprecated_*`, `version_control_* → status.*`, `minimap_thumb_* → scrollbar_thumb_*` (alpha max `0.7`), `panel_overlay_* → panel_background` (+ `element_hover` blend), document highlight / Vim / Helix fallback'leri ve `editor_diff_hunk_* → version_control_* × LIGHT/DARK_DIFF_HUNK_*_OPACITY`. Konu 30 tablosu eksiksiz listeler |
| `LIGHT_DIFF_HUNK_FILLED_OPACITY`, `DARK_DIFF_HUNK_FILLED_OPACITY`, `LIGHT_DIFF_HUNK_HOLLOW_BACKGROUND_OPACITY`, `DARK_DIFF_HUNK_HOLLOW_BACKGROUND_OPACITY`, `LIGHT_DIFF_HUNK_HOLLOW_BORDER_OPACITY`, `DARK_DIFF_HUNK_HOLLOW_BORDER_OPACITY` | `theme_settings/src/schema.rs:16-21` | Referans değerler sırasıyla `0.16 / 0.12 / 0.08 / 0.06 / 0.48 / 0.36`. `pub(crate)` sabitler ama tüketici görünür sözleşme değil; sayılar mirror'da `kvs_tema_ayarlari` modülünde aynı tutulmalı |
| `apply_theme_color_defaults` kaynak rengi | `fallback_themes.rs:47-58` | `text_accent × 0.25` **değil** — `player_colors.local().selection`; alpha 1.0 ise 0.25'e çekilir, aksi halde olduğu gibi atanır. Konu 31'da ayrıntılıdır |
| `refine_theme` adım sırası | `theme_settings/src/theme_settings.rs:275-353` | `status_colors_refinement → apply_status_color_defaults → status.refine → merge_player_colors → theme_colors_refinement(c, &status_ref, is_light) → apply_theme_color_defaults(&player) → colors.refine → merge_accent_colors → inline syntax map + Arc::new(SyntaxTheme::new(...))`. Konu 32'da ayrıntılı |
| `pub fn syntax_overrides(style) -> Vec<(String, HighlightStyle)>` | `theme_settings/src/schema.rs:40` | Override map'i `IndexMap<String, HighlightStyleContent>` → `Vec<(String, gpui::HighlightStyle)>`. 4 alan (`color`, `background_color`, `font_style`, `font_weight`) parse edilir; underline/strikethrough/fade_out `Default::default()`. `ThemeSettings::modify_theme` içindeki `SyntaxTheme::merge`'in beklediği imza |
| `ThemeSettings::modify_theme` override akışı | `theme_settings/src/settings.rs:472-491` | Full `refine_theme` değildir: `apply_status_color_defaults` / `apply_theme_color_defaults` çağırmaz; status/theme refinement'ı doğrudan uygular, player/accent merge eder ve syntax için `SyntaxTheme::merge(base, syntax_overrides(...))` kullanır |
| `SyntaxTheme::merge(base, overrides) -> Arc<Self>` | `syntax_theme/src/syntax_theme.rs:96` | **Field-bazlı merge**: aynı capture varsa `new.<f>.or(existing.<f>)` ile birleştirir; capture yeni ise listenin sonuna ekler. Override boşsa baseline klonsuz döner. Konu 18 + settings-level theme override akışında kanonik kullanım |
| `ThemeName`, `IconThemeName`, `ThemeAppearanceMode`, `FontFamilyName` re-export zinciri | `settings_content/src/theme.rs:282, 501, 507` → `theme_settings::settings::pub use settings::{...}:13` | Owner `settings_content`; `theme_settings` `pub use` ile köprü kurar. Mirror'da `kvs_ayarlari_icerik` (veya muadili) tek kaynak, `kvs_tema_ayarlari` yalnızca `pub use` ile yeniden açar — aksi halde aynı tipi iki yerde tanımlama bug'ı |
| `Theme.styles` görünürlüğü | `theme.rs:216` | Zed'de **`pub styles: ThemeStyles`** (alan-bazlı). Yerel tasarım accessor disiplini için `pub(crate)` seçebilir; bu yerel sıkılaştırmadır. Zed paritesi `pub` |
| `ThemeFamily` alan görünürlüğü | `theme.rs:192-204` | `id`, `name`, `author`, `themes`, `scales` alanlarının hepsi `pub`. `scales: ColorScales` alanı 33 paleti taşır; referans değişiminde alan sayısı sabit kalır, palet sayısı değişebilir |
| `PlayerColors::color_for_participant(idx)` | `styles/players.rs:147` | Collab kullanıcı renkleri için `modulo (len - 1) + 1` offset'li lookup; **local slot'u (idx 0) atlar**, participant 0 listenin idx 1'inden başlar. Konu 15'te işleniyor, 43.9'da resmi imza |
| `PlayerColors::agent()`, `.absent()` davranışı | `styles/players.rs:130-136` | İkisi de `self.0.last().unwrap()` döner — yani **agent ve absent player aynı slot'tur** (listenin son elementi). Fallback temalarda son slot'u boş bırakmama nedeni budur |
| `theme::init` davranışı | `theme.rs:96-116` | `SystemAppearance::init → ThemeRegistry::set_global(assets, cx) → FontFamilyCache::init_global → default_global → themes.get(DEFAULT_DARK_THEME) (yoksa list().next()) → default_icon_theme().unwrap() → cx.set_global(GlobalTheme { theme, icon_theme })`. `GlobalTheme::new` çağırmaz, doğrudan struct literal kullanır (her ikisi de mümkün) |
| `Appearance::is_light`, `From<WindowAppearance>` | `theme.rs:63-78` | `is_light` `matches!(self, Light)`'tan kısa. `From<WindowAppearance>`: `Dark` ve `VibrantDark` → `Dark`; `Light` ve `VibrantLight` → `Light` (vibrant varyantları normal mapping'e düşer) |
| `SystemAppearance::Default = Dark` | `theme.rs:142-146` | Sistem görünümü alınamazsa default Dark. Mirror tarafta aynı varsayılan tutulmalı; aksi halde init önce ekrana light tema gelir, sonra sistem dark'sa dark'a sıçrama olur |
| `theme_settings::settings::BufferLineHeight` (`Comfortable`, `Standard`, `Custom(f32)`), `value()` | `theme_settings/src/settings.rs:340-369` | `Standard = 1.3`, `Comfortable = 1.618`, `Custom` doğrudan değer. Settings tarafında `f32 >= 1.0` kısıtı (`settings_content/src/theme.rs:452`) |
| `try_parse_color` (`theme/src/schema.rs:17`) | `theme/src/schema.rs` | Konu 21'de detaylı; 43.9'da public helper olarak teyit edilir |
| `gpui::Rgba::try_from(&str)` desteklediği formatlar | `gpui/src/color.rs:162-256` | **Dört format**: `#rgb` (3 hane, çiftleme), `#rgba` (4 hane, çiftleme), `#rrggbb` (6 hane), `#rrggbbaa` (8 hane). `#` zorunlu; trim yapılır. Konu 21'de ayrıntılı |
| `AppearanceContent` (`theme/src/schema.rs:11`) | `theme/src/schema.rs` | JSON `appearance` alanının enum mirror'ı (`Light` / `Dark`); Konu 19'de kullanılır |
| `theme_settings::init` observer 7 değişken tracking'i | `theme_settings/src/theme_settings.rs:85-142` | Settings değişiminde `reset_*_font_size` (4), `reload_theme` (theme_name veya overrides) (1+1=2), `reload_icon_theme` (1). Toplam 7 izleme alanı vardır; eksik tracking font size değerlerinin stale kalmasına yol açar. Konu 38'de ayrıntılı |
| `theme_settings::init` 2 katmanlı init paritesi | `theme_settings/src/theme_settings.rs:64-83` | `theme::init` (registry + fallback dark + GlobalTheme) ÇAĞRIDIKTAN SONRA `set_theme_settings_provider`, `load_bundled_themes` (LoadThemes::All ise), `configured_theme` ile settings'ten gelen seçimi çözüp `GlobalTheme::update_theme` + `update_icon_theme`. Mirror'da iki ayrı `init` fonksiyonu korunmalı; tek `kvs_tema::init`'te birleştirmek bağımlılık matrisini bozar |
| `Theme.styles.syntax` baseline davranışı | `theme_settings/src/theme_settings.rs:313-331` | `refine_theme` `Arc::new(SyntaxTheme::new(syntax_overrides))` — yani baseline syntax kullanılmaz, **tema JSON'unda syntax bloğu boşsa sonuç boş syntax theme**. Yazar `syntax: { ... }` zorunlu doldurmalıdır; aksi halde editor highlight'sız kalır. Konu 32'da ayrıntılı |
| `ThemeSettings::modify_theme` görünürlüğü | `theme_settings/src/settings.rs:472` | Aslında `fn` — **private**. `pub fn apply_theme_overrides(&self, arc_theme: Arc<Theme>) -> Arc<Theme>` üzerinden çağrılır; tüketici doğrudan `modify_theme` çağıramaz. Public yüzey `apply_theme_overrides`'tır |
| `ThemeRegistry::new` davranışı | `theme/src/registry.rs:101-123` | Constructor **zaten dolu döner**: `insert_theme_families([zed_default_themes()])` çağrısı ve `default_icon_theme()` (`DEFAULT_ICON_THEME_NAME`) icon haritasına yerleştirme. Mirror tarafta da aynı garanti tutulmalı; aksi halde `default_icon_theme()` çağrısı `Err` döner |
| `ThemeRegistry::list_names()` sıralama | `theme/src/registry.rs:181-185` | `Vec<SharedString>` döner ve **sıralı** (`names.sort()`). Buna karşılık `list()` (`Vec<ThemeMeta>`) **sıralı değil** — HashMap.values() üzerinden direkt map'lenir. Selector UI sıralı list istiyorsa `list_names` veya manuel sort gerek |
| `ThemeRegistry::clear()` davranışı | `theme/src/registry.rs:176-178` | Sadece `themes` HashMap'ini temizler — `icon_themes` HashMap'ine **dokunmaz**. Test/reset senaryolarında icon themes ayrıca `remove_icon_themes(...)` ile temizlenmelidir |
| `ThemeRegistry::load_icon_theme` baseline merge davranışı | `theme/src/registry.rs:250-330`, `file_icons/src/file_icons.rs:89-164` | Yüklenen icon theme'in `file_stems`, `file_suffixes`, `named_directory_icons` haritaları **default icon theme üstüne extend edilir**. `file_icons`, `directory_icons`, `chevron_icons` constructor'da default'tan kopyalanmaz; UI lookup eksik dosya tipi, klasör ve chevron path'lerinde `file_icons` crate'i üzerinden default icon theme'e düşer. Her tema için yeni UUID atanır |
| `icon_theme_schema` re-export sınırı | `theme/src/theme.rs:15, 36`; `theme/src/icon_theme_schema.rs:10-49` | Modülün kendisi `mod icon_theme_schema` ile private; root `pub use crate::icon_theme_schema::*` yalnız `IconThemeFamilyContent`, `IconThemeContent`, `DirectoryIconsContent`, `ChevronIconsContent`, `IconDefinitionContent` tiplerini açar. Mirror'da `kvs_tema::icon_theme_schema` path'i ancak bilinçli tasarım kararıysa public yapılmalı |
| `SyntaxTheme::one_dark()` | `syntax_theme/src/syntax_theme.rs:134-220` | `#[cfg(feature = "bundled-themes")]` altında public helper. Bundled `one/one.json` içinden `"One Dark"` syntax theme'i yükler; feature kapalıyken public API'de yoktur. Üretim tema yükleme hattı yerine test/dev fixture olarak düşün |
| `Refineable` trait yüzeyi tam katalog | `refineable/src/refineable.rs:29-131` | `Refineable`: `refine`, `refined`, `from_cascade`, `is_superset_of`, `subtract`; `IsEmpty`: `is_empty`; `Cascade<S>` metotları: `reserve`, `base`, `set`, `merged`; `CascadeSlot` yalnız slot handle'ıdır. Tema sistemi `from_cascade`/`Cascade` kullanmaz ama refineable trait sözleşmesi tam mirror edilmelidir |
| `#[with_fallible_options]` macro | `settings_macros/src/settings_macros.rs:110-152` | `Option<T>` alanlarına otomatik `#[serde(default, skip_serializing_if = "Option::is_none", deserialize_with = "crate::fallible_options::deserialize")]` ekler. `ThemeSettingsContent`, `ThemeStyleContent`, `ThemeColorsContent`, `StatusColorsContent` gibi tiplerde kullanılır; parse hatası alan `None`'a düşer, thread-local hata listesine eklenir |
| `fallible_options::parse_json`, crate-private `deserialize` | `settings_content/src/fallible_options.rs:11-65` | Top-level parse fonksiyonu (`parse_json::<T>(json) -> (Option<T>, ParseStatus)`) public re-export edilir; thread-local `ERRORS` listesi parse sırasında biriken hataları toplar. `deserialize` ise `pub(crate)` internal helper'dır, macro'nun eklediği serde attribute'u kullanır |
| `RootUserSettings::parse_json`, `parse_json_with_comments` | `settings_content/src/settings_content.rs:333-364` | `SettingsContent`, `Option<SettingsContent>` ve `UserSettingsContent` için public root parse trait'i. `parse_json` fallible option tolerant hattını, `parse_json_with_comments` ise normal `settings_json::parse_json_with_comments` sonucunu döner |
| `HighlightStyleContent::treat_error_as_none` istisnası | `settings_content/src/theme.rs:1104-1144` | `HighlightStyleContent` `#[with_fallible_options]` kullanmaz. Yalnız `background_color`, `font_style`, `font_weight` alanlarında yerel `treat_error_as_none` vardır; `color` alanında yoktur. Bu yüzden `font_style` bilinmeyen enum ise `None`, ama `"color": 3` deserialize hatasıdır |
| Tema dosyası parse yolu | `theme_settings/src/theme_settings.rs:212-234` | Bundled tema asset'leri `serde_json::from_slice` ile, kullanıcı tema dosyaları `serde_json_lenient::from_slice` ile parse edilir. Bu hatlar `RootUserSettings::parse_json` değildir; `with_fallible_options` hataları `ParseStatus` olarak toplamaz, normal serde hatası dönebilir |
| `MergeFrom` trait + derive | `settings_content/src/merge_from.rs:17-174`, `settings_macros::MergeFrom` | Primitive overwrite, `Option<T>` recursive merge, `Vec<T>` overwrite (concat değil), `HashMap/BTreeMap/IndexMap` key-bazlı recursive merge, `HashSet/BTreeSet` union, `serde_json::Value` Object recursive. Konu 20'da davranış matrisi tam tablo |
| `ThemeSettingsContent.ui_density` JSON rename | `settings_content/src/theme.rs:166-167` | `#[serde(rename = "unstable.ui_density")]` — kullanıcı JSON'unda **`"unstable.ui_density"`** yazmalıdır; `"ui_density"` çalışmaz. Konu 40'te ayrıntılı |
| `ThemeSettingsContent` schemars tag'leri | `settings_content/src/theme.rs:124-171` | `ui_font_fallbacks`, `buffer_font_fallbacks` `#[schemars(extend("uniqueItems" = true))]`; `unnecessary_code_fade` `#[schemars(range(min = 0.0, max = 0.9))]`; her font alanı `#[schemars(default = "...")]` ile default value fonksiyonu işaretli |
| `FontSize` newtype derive list'i | `settings_content/src/theme.rs:186-200` | `Clone, Copy, Debug, Serialize, Deserialize, JsonSchema, MergeFrom, PartialEq, PartialOrd, derive_more::FromStr` ve `#[serde(transparent)]`. Serialize iki ondalık basamakla (`serialize_f32_with_two_decimal_places`). Display formatı `{:.2}` |
| `UnderlineStyle`, `StrikethroughStyle` (`gpui::style:783-804`) | `gpui/src/style.rs` | `UnderlineStyle { thickness, color, wavy }`, `StrikethroughStyle { thickness, color }`. İkisi de `Refineable + Copy + Eq + Hash + JsonSchema`. Tema JSON sözleşmesinde syntax stillerinin underline/strikethrough alanları **YOK**; `refine_theme` her ikisini de `Default::default()` (nötr) bırakır. Konu 7'de işlendi |
| `HighlightStyle.fade_out` `Hash` impl | `gpui/src/style.rs:562-574` | `f32` `Hash` türetilemez; `to_be_bytes()` ile `u32`'ye çevrilip hashlenir. Mirror tarafta elle implement edilir veya GPUI'nin `HighlightStyle`'ı doğrudan kullanılır |
| `ThemeRegistry::default()` | `theme/src/registry.rs:327-331` | `Default for ThemeRegistry` impl'i `Self::new(Box::new(()))` — boş asset source ile constructor. Test'te `ThemeRegistry::default()` kısa yol; asset gerektiren testler `Box::new(()) as Box<dyn AssetSource>` parametresini açık geçirir |
| `FileIcons::get_icon`, `get_icon_for_type` | `file_icons/src/file_icons.rs:20-99` | `get_icon(path, cx)` 6 katmanlı: tam ad → dot-suffix loop → `multiple_extensions` → `extension_or_hidden_file_name` → ham `extension` → `"default"` tipi. Her katmanda `file_stems` veya `file_suffixes` aktif temasında lookup, sonra `get_icon_for_type(typ, cx)` ile `file_icons` aktif → default fallback |
| `FileIcons::get_folder_icon`, `get_chevron_icon` | `file_icons/src/file_icons.rs:102-165` | Klasör fallback'i: `named_directory_icons` (klasör adına özel) → private `get_generic_folder_icon` ile `directory_icons` (jenerik), her ikisinde de aktif → default tema fallback. Chevron: yalnız aktif → default. Expanded/collapsed slot ayrımı her katmanda korunur |
| `ParseStatus` 3 variantlı | `settings_content/src/settings_content.rs:75-83` | `Success`, **`Unchanged`** (dosya değişmediği için parse atlandı), `Failed { error: String }`. `Unchanged`, settings file watcher hattında "skip" sinyali için kritik |
| `SettingsContent.theme` flatten ilişkisi | `settings_content/src/settings_content.rs:114-145` | `pub theme: Box<ThemeSettingsContent>` **`#[serde(flatten)]`** ile işaretli. Kullanıcı `settings.json`'da `ui_font_size`, `theme`, `icon_theme`, `unstable.ui_density` vb. **top-level** alanlar olarak yazar — iç `"theme": { ... }` bloğu **YOK**. `SettingsContent` 25+ alt struct'ı flatten ile birleştirir; `Box` heap'e taşıyarak stack overflow'tan kaçınır |
| `UserSettingsContent` yapısı | `settings_content/src/settings_content.rs:407-421` | `content: Box<SettingsContent>` flatten + `release_channel_overrides` flatten + `platform_overrides` flatten + `profiles: IndexMap<String, SettingsProfile>` düz alan. Yani `~/.config/zed/settings.json` `SettingsContent` alanları + override blokları + `"profiles": {...}` taşır |
| `settings_overrides!` macro | `settings_content/src/settings_content.rs:40-65` | `Option<Box<SettingsContent>>` alanlı override struct'lar üretir + `OVERRIDE_KEYS: &[&str]` derive + `get_by_key(key) -> Option<&SettingsContent>` accessor. Release channel ve platform override'ları bu pattern'le tanımlıdır |
| `Settings` trait (`settings_store`) | `settings/src/settings_store.rs:60-129` | Tam public yüzey: `const PRESERVED_KEYS: Option<&'static [&'static str]> = None`, `from_settings(content: &SettingsContent) -> Self`, `register(cx: &mut App)`, `get<'a>(path: Option<SettingsLocation>, cx: &'a App) -> &'a Self`, `get_global(cx: &App) -> &Self`, `try_get(cx: &App) -> Option<&Self>`, `try_read_global<R>(cx: &AsyncApp, f: impl FnOnce(&Self) -> R) -> Option<R>`, `override_global(settings: Self, cx: &mut App)`. `ThemeSettings::get_global(cx)` bu trait'ten gelir; `from_settings` `SettingsContent.theme` flatten'ından typed `ThemeSettings` üretir |
| `SettingsStore` global'i | `settings/src/settings_store.rs` | `register_setting::<T: Settings>()` ile typed setting tipini dispatch tablosuna ekler; ayar dosyası değiştiğinde her kayıtlı tipin `from_settings`'i çağrılır. `cx.global::<SettingsStore>().get(None)` cache'lenmiş `&ThemeSettings` döner — accessor klonsuz, hot path |
| `settings_json::parse_json_with_comments` | `settings_json/src/settings_json.rs:743-746` | `serde_json_lenient::Deserializer` + `serde_path_to_error::deserialize`. Hata mesajları **field path'ini de gösterir** (örn. `theme.colors.background: invalid hex`); mirror tarafta da `serde_path_to_error` kullanmak kullanıcı deneyimini iyileştirir |
| `MergeFromTrait` re-export | `settings_content/src/settings_content.rs:23` | `merge_from::MergeFrom` `pub use ... as MergeFromTrait` ile yeniden ihraç edilir. Aynı trait için iki ad: `MergeFrom` (derive macro + trait) ve `MergeFromTrait` (alias). Mirror tarafta tek ada karar ver, çakışma testleri yaz |
| `HighlightStyleContent::is_empty()` | `settings_content/src/theme.rs:1128-1134` | 4 alanın hepsi `None` ise `true`. Selector preview, snapshot test ve `MergeFrom` "no-op detection" akışında kullanılır. `Refineable.is_empty` trait'inin elle muadili |
| `Refineable` derive `Option<T>` sarmalama kuralı | `refineable/derive_refineable/src/derive_refineable.rs:512-548` | Düz `T` → `Option<T>`; `Option<T>` aynen `Option<T>` (tekrar sarmalanmaz); `#[refineable] U` → `URefinement` (nested recursive). Konu 11'de tablo eklendi |
| `configured_theme`, `configured_icon_theme` görünürlüğü | `theme_settings/src/theme_settings.rs:145, 166` | Aslında `fn` — **private**. Mirror tarafta `pub fn` yapmak yerel API genişletmesidir. Zed paritesinde `init` ve `reload_theme` bu helper'ları çağırır, tüketici doğrudan erişmez |
| `load_bundled_themes` hata davranışı | `theme_settings/src/theme_settings.rs:199-222` | Her tema asset'i `log_err()` ile sarılır; parse hatası **panic etmez**, log'lanır ve sonraki asset'e geçer. Bu sayede tek bozuk bundled tema tüm Zed başlatmasını engellemez. Mirror tarafta aynı davranış zorunlu |
| `#[derive(RegisterSetting)]` auto-registration | `settings_macros/src/settings_macros.rs:85-105`, `settings/src/settings_store.rs:131-137, 412-416` | Setting tipini `inventory::submit!` ile static registry'ye ekler. `SettingsStore::new` → `load_settings_types` → `inventory::iter` ile **link-time** otomatik kaydedilir. `ThemeSettings` `#[derive(Clone, PartialEq, RegisterSetting)]` ile işaretli; `theme_settings::init` **elle register çağırmaz**. Konu 39'de tam akış |
| `inventory` crate auto-registration | `Cargo.toml` (settings, settings_macros) | Rust'ın link-time static registration için kullanılan crate. Setting tipi tanımının yapıldığı yerde `submit!`, toplama tarafında `collect!`. Mirror'da alternatif (elle register listesi) seçilirse iki pattern karıştırılmamalıdır; aksi halde sessiz kayıt eksikleri olur |
| `SettingsStore::override_global<T>` davranışı | `settings/src/settings_store.rs:475-483` | Test ve runtime override için. `setting_values[TypeId::of::<T>()].set_global_value(Box::new(value))`. Doc note: "The given value will be overwritten if the user settings file changes" — yani settings dosyası değişince override drop olur (observer akışı bunu garantiler). Tip kayıtlı değilse `panic!("unregistered setting type ...")` |
| `ThemeSettings` alan görünürlükleri | `theme_settings/src/settings.rs:39-89` | Font size alanları (`ui_font_size`, `buffer_font_size`, `agent_*_font_size`, `markdown_preview_font_family`, `markdown_preview_code_font_family`) **private**; accessor metotlar (`ui_font_size(cx)`, `buffer_font_size(cx)`, vs.) override-aware okuma yapar. Diğer alanlar (`ui_font`, `buffer_font`, `theme`, `icon_theme`, `theme_overrides`, `experimental_theme_overrides`, `buffer_line_height`, `markdown_preview_theme`, `ui_density`, `unnecessary_code_fade`) `pub`. Konu 39'de tam tablo |
| `theme` crate'i `#![deny(missing_docs)]` | `theme/src/theme.rs:1` | Crate-level lint zorlaması: tüm public öğeler doc yorumu gerektirir. Mirror'da aynısı uygulanırsa public API kalitesi artar; yeni alan eklendiğinde "doc yok" hatası sayesinde sözleşme atlanmaz |
| `theme` crate mod görünürlükleri | `theme/src/theme.rs:11-21, 32-42` | Tüm modüller (`default_colors`, `fallback_themes`, `font_family_cache`, `icon_theme`, `icon_theme_schema`, `registry`, `scale`, `schema`, `styles`, `theme_settings_provider`, `ui_density`) **private** `mod`. Public yüzey yalnızca `pub use crate::<mod>::*` re-export ile gelir. `fallback_themes` istisnası: yalnız `apply_status_color_defaults` ve `apply_theme_color_defaults` `pub use` ile açılır — diğer iç fonksiyonlar (`zed_default_dark` vb.) `pub(crate)` |
| `ui::is_light(cx)` public helper | `ui/src/utils.rs:23-25` | `cx.theme().appearance.is_light()` çağırır. UI tüketicileri için tekrar eden pattern; `kvs_ui` veya `kvs_bilesen` mirror'ında benzeri sağlanabilir. `ui::prelude` `pub use theme::ActiveTheme` ile trait'i tüketici crate'lere açar |
| `settings::IntoGpui` trait + 7 impl | `settings/src/content_into_gpui.rs:12-85` | `*Content` tiplerini GPUI runtime tiplerine çeviren tek köprü. İmpl edilen tipler: `FontStyleContent`, `FontWeightContent` (100-950 clamp), `FontFeaturesContent`, `WindowBackgroundContent`, `ModifiersContent`, `FontSize` (`px(self.0)`), `FontFamilyName` (`SharedString::from(self.0)`). `ThemeSettings::from_settings` her font alanında bu trait'i çağırır. Mirror tarafta `KvsIntoRuntime` veya benzeri trait gerek |
| `markdown_preview_code_font_family` settings alanı | `settings_content/src/theme.rs:155`, `theme_settings/src/settings.rs:62, 418` | Markdown preview içindeki inline code ve code block fontunu ayrı seçer. Unset ise `buffer_font.family` kullanılır; düz preview metni `markdown_preview_font_family` unset ise `ui_font.family` kullanmaya devam eder. Provider trait değişmez |
| Mermaid tema tüketimi | `markdown/src/mermaid.rs` | Mermaid renderer teması aktif `ThemeColors`, `AccentColors`, `PlayerColors`, `Appearance` ve `ThemeSettings::ui_font` üstünden üretilir. Tema/settings değişiminde cache invalidate edilmeli; `accent0..accentN` class'ları player slotlarından gelir |
| `gpui::Hsla::opaque_strategy`, `Arbitrary for Hsla` | `gpui/src/color.rs` | `proptest` feature'ı altında renk property testleri için resmi generator. Kontrast/türetme helper'larında sentetik örneklerin yanına property test eklenebilir |
| Completion kind syntax rengi | `editor/src/completions_menu.rs`, `settings_content/src/editor.rs` | `completion_menu_item_kind = "symbol"` açıkken completion kind rozetleri syntax capture renklerinden (`function`, `function.method`, `type`, `property`, `variable`, `keyword`, `string`) beslenir; tam capture yoksa parent capture fallback'i denenir |
| Content/Runtime tip duplication ve `From` impls | `theme_settings/src/settings.rs:136, 188, 350` ↔ `settings_content/src/theme.rs:267, 309, 438` | `ThemeSelection`, `IconThemeSelection`, `BufferLineHeight` **iki yerde tanımlı**: settings_content (Content, `JsonSchema/MergeFrom/EnumDiscriminants`) ve theme_settings (Runtime, daha az derive). Aralarında `From<settings::*>` impl. `UiDensity` için `ui_density_from_settings` `pub(crate)` helper kullanılır (`From` değil). Konu 39 ve 43.3'te açıklandı |
| `ThemeSettings::from_settings` panic kontratı | `theme_settings/src/settings.rs:619-666` | Her font ve theme alanında `.unwrap()` çağrılır — yani `default.json` zorunlu alanları (`ui_font_size/family/features/weight`, `buffer_font_*`, `buffer_line_height`, `theme`, `icon_theme`, `unnecessary_code_fade`) doldurmak zorundadır. Boşsa init panic eder. Mirror'da `kvs_default_settings.json` aynı zorunlu set'i taşımalı |
| `ThemeSelection::Default`, `IconThemeSelection` derive list'i | `settings_content/src/theme.rs:254-322` | Content tipleri `JsonSchema, MergeFrom, EnumDiscriminants, VariantArray, VariantNames, FromRepr` derive eder. `ThemeSelection::default() = Dynamic { mode: System, light: "One Light", dark: "One Dark" }`. Selector UI tabbed picker için `strum::VariantArray` ve `EnumDiscriminants` kullanılır |
| `ThemeAppearanceMode` derive ve default | `settings_content/src/theme.rs:329-354` | `Copy + Default + strum::VariantArray + strum::VariantNames` derive'larıyla; `#[default] System` variant. `serde(rename_all = "snake_case")` ile JSON'da `"light"`/`"dark"`/`"system"` |
| `BufferLineHeight::Custom` 1.0 alt sınır deserializer | `settings_content/src/theme.rs:445-460` | `#[serde(deserialize_with = "deserialize_line_height")] f32` özel fonksiyon; 1.0 altı değer **deserialize hatası** üretir. Çift savunma: parse'ta 1.0 alt sınır + runtime `ThemeSettings::line_height()` `f32::max(.., MIN_LINE_HEIGHT)` |
| `ThemeSettings::line_height()` + `MIN_LINE_HEIGHT` | `theme_settings/src/settings.rs:20, 451-453` | `MIN_LINE_HEIGHT = 1.0`. Buffer renderer satır yüksekliği için bu accessor kullanılır; ham `BufferLineHeight.value()` doğrudan değil — geçersiz değerlerden korunmak için clamp yapılır |
| `ColorScales` `IntoIterator` impl | `theme/src/scale.rs:194-235` | 33 paleti **sabit sırada** (`gray, mauve, slate, sage, olive, sand, gold, bronze, brown, yellow, amber, orange, tomato, red, ruby, crimson, pink, plum, purple, violet, iris, indigo, blue, cyan, teal, jade, green, grass, lime, mint, sky, black, white`) `Vec<ColorScaleSet>` olarak yayar. Snapshot test ve color picker için kanonik dolaşım. Konu 17'te işlendi |
| `FontFamilyName` impls | `settings_content/src/theme.rs:399-421` | `#[serde(transparent)]` newtype + `AsRef<str>` + `From<String>` + `From<FontFamilyName> for String`. `Arc<str>` taşır, klonsuz `SharedString`'e dönüşür (`IntoGpui::into_gpui()`) |
| `FontWeightContent::into_gpui()` 100-950 clamp | `settings/src/content_into_gpui.rs:32-34` | `FontWeight(self.0.clamp(100., 950.))` — CSS font-weight aralığında zorlama. `FontWeightContent::{THIN, EXTRA_LIGHT, ..., BLACK}` const'larının GPUI `FontWeight` const'larıyla eşleştiği test ile doğrulanır (`content_into_gpui.rs:92-103`) |
| `settings::private` modülü | `settings/src/settings.rs:21-25` | `pub mod private { pub use inventory; pub use crate::settings_store::{RegisteredSetting, SettingValue}; }`. `RegisterSetting` derive macro `settings::private::inventory::submit!` çağırır. Mirror'da `kvs_ayarlari::private` benzeri modül zorunlu; aksi halde macro çıktısı derlenmez |
| `theme_settings` re-export listesi | `theme_settings/src/theme_settings.rs:24-37` | `schema::{FontStyleContent, FontWeightContent, HighlightStyleContent, StatusColorsContent, ThemeColorsContent, ThemeContent, ThemeFamilyContent, ThemeStyleContent, WindowBackgroundContent, status_colors_refinement, syntax_overrides, theme_colors_refinement}` ve `settings::{AgentBufferFontSize, AgentUiFontSize, BufferLineHeight, FontFamilyName, IconThemeName, IconThemeSelection, ThemeAppearanceMode, ThemeName, ThemeSelection, ThemeSettings, adjust_*, reset_*, adjusted_font_size, appearance_to_mode, clamp_font_size, default_theme, observe_buffer_font_size_adjustment, set_icon_theme, set_mode, set_theme, setup_ui_font}` + `pub use theme::UiDensity`. Mirror'da tüm bu sembolleri tek kaynak crate'inden re-export et |

Küçük method yüzeyleri:

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
ThemeSettings::markdown_preview_font_family()
ThemeSettings::markdown_preview_code_font_family()
ThemeSettings::buffer_font_size_settings()
ThemeSettings::ui_font_size_settings()
ThemeSettings::agent_ui_font_size_settings()
ThemeSettings::agent_buffer_font_size_settings()
ThemeSettings::line_height()
ThemeSettings::apply_theme_overrides(arc_theme)
Theme::darken(color, light_amount, dark_amount)
BufferLineHeight::value()
default_theme(appearance) -> &'static str
appearance_to_mode(appearance) -> ThemeAppearanceMode
clamp_font_size(size) -> Pixels
adjusted_font_size(size, cx) -> Pixels
```

Bu metodlar rehberin ana akışını değiştirmez, fakat tema editörü, collab
renkleri, density ölçümü ve snapshot karşılaştırması yazarken doğrudan
public API ihtiyacına dönüşür.

---

## 44. Test ortamında tema mock'lama

UI bileşenlerini test ederken **tüm tema sistemini** init etmek
pratik değil; sadece bileşenin renge ihtiyaç duyduğu kadar mock
tema kur.

### Strateji 1: Tam init (`kvs_tema::init`)

En basit. Test'in başında tam runtime kur:

```rust
use gpui::TestAppContext;
use kvs_tema::ActiveTheme;

#[gpui::test]
fn button_uses_theme_colors(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);  // Fallback temaları kurar

        let theme = cx.theme();
        assert_eq!(theme.appearance, kvs_tema::Appearance::Dark);
        assert_ne!(theme.colors().background, gpui::Hsla::default());
    });
}
```

**Avantaj:** Production akışına en yakın. Init bug'ları erken yakalanır.

**Dezavantaj:** Her test fallback tema oluşumu için ~50 µs harcar.
Yüzlerce test çalıştırıyorsan kümülatif.

### Strateji 2: Manuel kurulum (özel tema değerleri)

Test'in özel renk değerlerine ihtiyacı varsa, manuel kur:

**Bu strateji `kvs_tema` crate'inin İÇİNDEN çalışır** — `Theme { styles:
... }` literal'i `pub(crate)` field'lara erişir. `kvs_tema/tests/`
(entegrasyon testleri) **dış crate** sayılır; oradan struct literal
yazılamaz. Bu manuel kurulum sadece `kvs_tema/src/test.rs` (Strateji 3)
veya `kvs_tema` modülünün kendi birim testlerinde kullanılır.

```rust
// kvs_tema/src/test.rs içinde (crate-içi)
use std::sync::Arc;
use gpui::hsla;
use crate::{
    Theme, ThemeStyles, ThemeColors, StatusColors, PlayerColors,
    AccentColors, SystemColors, Appearance,
};

pub(crate) fn test_theme(bg: gpui::Hsla, fg: gpui::Hsla) -> Theme {
    Theme {
        id: "test".into(),
        name: "Test Theme".into(),
        appearance: Appearance::Dark,
        styles: ThemeStyles {
            window_background_appearance: gpui::WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors {
                background: bg,
                text: fg,
                // ... diğer alanlar için dummy değer
                ..fallback_colors_dark()  // ← kalanlar fallback'ten
            },
            status: fallback_status_dark(),
            player: PlayerColors::default(),
            accents: AccentColors::default(),
            syntax: Arc::new(kvs_syntax_tema::SyntaxTheme::new(Vec::<(String, HighlightStyle)>::new())),
        },
    }
}
```

> **`..fallback_colors_dark()` yapmak için:** `ThemeColors`'a `Default`
> türetmen veya yardımcı bir `pub(crate) fn fallback_colors_dark() ->
> ThemeColors` tanımlaman gerek. Mevcut yapıda `ThemeColors`'ın
> `Default`'u yok (tüm alanları zorunlu); test helper'ı yaz.
>
> **Dış crate'ten test:** `kvs_ui/tests/`'te bu strateji çalışmaz;
> `feature = "test-util"` ile Strateji 3'ün public helper'ları çağrılır.

### Strateji 3: `kvs_tema` test helper'ı

`kvs_tema/src/test.rs` (yeni modül, `#[cfg(any(test, feature = "test-util"))]`):

```rust
#[cfg(any(test, feature = "test-util"))]
pub mod test {
    use crate::*;
    use std::sync::Arc;

    /// Test için minimal tema kurar.
    pub fn init_test(cx: &mut gpui::App) {
        // ThemeRegistry::new artık AssetSource zorunlu — testte `()` kullanılır.
        let registry = Arc::new(ThemeRegistry::new(Box::new(()) as Box<dyn gpui::AssetSource>));
        registry.insert_themes([test_theme()]);
        let theme = registry.get("Test").unwrap();
        let icon_theme = registry.default_icon_theme().unwrap();
        // ThemeRegistry::set_global Zed'de pub(crate); test helper'ı
        // kvs_tema'nın test-support feature'ı altında public açar veya
        // doğrudan GlobalThemeRegistry newtype'ını cx.set_global ile kurar.
        cx.set_global(GlobalThemeRegistry(registry.clone()));
        cx.set_global(GlobalTheme::new(theme, icon_theme));
    }

    /// Yeniden kullanılabilir test tema'sı.
    pub fn test_theme() -> Theme {
        // Tüm alanları açık ama belirgin renklerle doldur
        // (debug için fark edilir)
        let red = gpui::hsla(0.0, 1.0, 0.5, 1.0);
        let green = gpui::hsla(0.333, 1.0, 0.5, 1.0);
        Theme {
            id: "test".into(),
            name: "Test".into(),
            appearance: Appearance::Dark,
            styles: ThemeStyles {
                colors: ThemeColors {
                    background: red,
                    border: green,
                    text: green,
                    // ... her alan benzersiz renkte (debug için)
                },
                // ...
            },
        }
    }
}
```

Tüketici (`kvs_ui/tests/...`):

```rust
[dev-dependencies]
kvs_tema = { path = "../kvs_tema", features = ["test-util"] }
```

```rust
use kvs_tema::test::init_test;

#[gpui::test]
fn render_uses_test_theme(cx: &mut TestAppContext) {
    cx.update(|cx| {
        init_test(cx);

        let theme = cx.theme();
        assert_eq!(theme.name.as_ref(), "Test");
    });
}
```

### Snapshot test deseni

Tema değerlerinin **belirli yerlerde** kullanıldığını doğrulamak için:

```rust
use kvs_tema::test::{init_test, test_theme};

#[gpui::test]
fn button_renders_with_theme_background(cx: &mut TestAppContext) {
    cx.update(|cx| {
        init_test(cx);

        let theme = test_theme();
        let expected_bg = theme.colors().element_background;

        let button = cx.new(|_| Button::new("OK".into()));

        // Element ağacını inspect et (test API'ları rehber.md #75'te)
        // Veya rendered scene'i query et:
        let render_output = /* ... */;
        assert!(render_output.contains_bg(expected_bg));
    });
}
```

> **GPUI test API'ları:** `TestAppContext::simulate_input`,
> `find_view`, vs. rehber.md #75'te detaylı. Render output'unu test
> etmek tema'nın doğru okunduğunu doğrular; tema'nın **kendi**
> doğruluğu için Bölüm VI fixture testleri yeterli.

### Tema değişimi simülasyonu

```rust
#[gpui::test]
fn ui_updates_on_theme_change(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);
        let initial = cx.theme().name.clone();

        // Light'a geç
        kvs_tema::temayi_degistir("Kvs Default Light", cx).unwrap();

        let new_theme = cx.theme();
        assert_ne!(new_theme.name, initial);
        assert_eq!(new_theme.appearance, kvs_tema::Appearance::Light);
    });
}
```

### Test'te `refresh_windows`

`TestAppContext` headless — açık pencere yok. `cx.refresh_windows()`
hata vermez ama hiçbir etkisi olmaz. Tema değişimini test ederken
`cx.theme()` çağrısı **yeni değeri** döner (global hemen güncellenmiş).

UI bileşeninin gerçekten yeniden render edilip edilmediğini test
etmek için `VisualTestContext` gerekir (rehber.md #75) — pencere açar,
render eder, snapshot karşılaştırır.

### Tema mock'lamayı yanlış yapmak

```rust
// YANLIŞ: cx olmadan, struct literal ile tema oluşturmak
// (dış crate'te bu zaten derlenmez — `styles` pub(crate))
let theme = kvs_tema::fallback::kvs_default_dark();
let bg = theme.colors().background;
let button_bg = bg;  // ← bileşen rendering'i ile bağlantısı yok
```

Bu test sadece `Theme` struct'ının kendi alanlarını doğrular — **tüketici
kodun cx.theme() çağrısının doğru çalıştığını test etmez**. UI test'i
istiyorsan `TestAppContext::update` ile global kur.

### Test ortamı sınır listesi

| Test türü | Strateji | Bileşen |
|-----------|----------|---------|
| Sözleşme doğrulama (parse, refinement) | `#[test]` + fixture | Bölüm VI/Konu 28 |
| Runtime init/registry | `#[gpui::test]` + `init` | Strateji 1 |
| Bileşen tema okuma | `#[gpui::test]` + custom theme | Strateji 2 veya 3 |
| Visual snapshot (render output) | `VisualTestContext` | rehber.md #75 |
| Tema değişim akışı | `#[gpui::test]` + `temayi_degistir` | Konu 38 + bu konu |

### Tuzaklar

1. **`kvs_tema::init(cx)` çağırmadan `cx.theme()`**: Panic. Her testin
   ilk satırı init veya manuel `cx.set_global(GlobalTheme::new(...))`.
2. **`TestAppContext::run` yerine `update`**: Tema testleri sync; `update`
   doğru. `run` async event loop, gerek yok.
3. **`test_theme()` her testte yeniden kurmak**: `set_global` her seferinde
   üzerine yazar; cumulative bug yok ama performans. Test fixture olarak
   `Arc<Theme>` paylaş.
4. **`feature = "test-util"`'ı production'da açık bırakmak**: `#[cfg(any(test,
   feature = "test-util"))]` koşulu; release build'de kapalı kalmalıdır.
5. **Test tema'sının tüm alanlarını sıfır bırakmak**: `unsafe { zeroed
   () }` ile dolduran test = production'da görünmez UI. Test'te bile
   tüm alanları açık değerle yaz; bug yakalama becerin yüksek olur.
6. **`refresh_windows` test'te etkisiz sanmak**: `TestAppContext`'te
   etkisiz ama global state güncel; test mantığı `cx.theme()` ile yeni
   değeri okur. `VisualTestContext` kullanıyorsan render'ı tetikler.
7. **Mock tema'nın `Theme.id` aynı**: Test'te birden fazla tema kurarsan
   farklı `id`'lerle (`"test-1"`, `"test-2"`); aksi halde `Theme.id`
   üzerinden equality test'i yaparsan yanlış sonuç.

---

