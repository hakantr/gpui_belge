# JSON sözleşmesi ve parse katmanı

Runtime modeli hazırken Zed uyumlu JSON sözleşmesini, opsiyonellik kuralını ve hata toleransını kur.

---

## 19. `ThemeContent` ve serde flatten/rename desenleri

**Kaynak modül:** `kvs_tema/src/schema.rs`.

JSON tema dosyalarını parse edebilen tip hiyerarşisi. Üç seviye:

```
ThemeFamilyContent      ← dosya kökü, "themes" array taşır
└── ThemeContent        ← bir tema varyantı (light veya dark)
    └── ThemeStyleContent ← tüm renk grupları flat yapıda
        ├── ThemeColorsContent  (flatten)
        ├── StatusColorsContent (flatten)
        ├── Vec<PlayerColorContent>
        ├── IndexMap<String, HighlightStyleContent>  (syntax)
        └── Option<WindowBackgroundContent>
```

### Tip imzaları

```rust
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ThemeFamilyContent {
    pub name: String,
    pub author: String,
    pub themes: Vec<ThemeContent>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ThemeContent {
    pub name: String,
    pub appearance: AppearanceContent,
    pub style: ThemeStyleContent,
}

#[settings_macros::with_fallible_options]
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema, MergeFrom, PartialEq)]
#[serde(default)]
pub struct ThemeStyleContent {
    #[serde(rename = "background.appearance")]
    pub window_background_appearance: Option<WindowBackgroundContent>,

    #[serde(default)]
    pub accents: Vec<AccentContent>,

    #[serde(flatten, default)]
    pub colors: ThemeColorsContent,

    #[serde(flatten, default)]
    pub status: StatusColorsContent,

    #[serde(default)]
    pub players: Vec<PlayerColorContent>,

    #[serde(default)]
    pub syntax: IndexMap<String, HighlightStyleContent>,
}
```

### Diğer Content tipleri — temel tanımlar ve tam alan haritası

`ThemeStyleContent`'in alt-tipleri:

```rust
// ─── Enum'lar — snake_case rename
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AppearanceContent {
    Light,
    Dark,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum WindowBackgroundContent {
    Opaque,
    Transparent,
    Blurred,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum FontStyleContent {
    Normal,
    Italic,
    Oblique,
}

// ─── Newtype — saydam
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct FontWeightContent(pub f32);

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct AccentContent(pub Option<String>);

// ─── HighlightStyleContent (syntax token sözleşmesi)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema, MergeFrom, PartialEq)]
#[serde(default)]
pub struct HighlightStyleContent {
    pub color: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none", deserialize_with = "treat_error_as_none")]
    pub background_color: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none", deserialize_with = "treat_error_as_none")]
    pub font_style: Option<FontStyleContent>,

    #[serde(skip_serializing_if = "Option::is_none", deserialize_with = "treat_error_as_none")]
    pub font_weight: Option<FontWeightContent>,
}

impl HighlightStyleContent {
    /// 4 alanın hepsi `None` ise true. Selector preview ve test'lerde
    /// "syntax override boş mu" sorusu için kullanılır.
    /// Zed paritesi: `settings_content/src/theme.rs:1128`.
    pub fn is_empty(&self) -> bool {
        self.color.is_none()
            && self.background_color.is_none()
            && self.font_style.is_none()
            && self.font_weight.is_none()
    }
}

// ─── PlayerColorContent (collaboration slot'ları)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct PlayerColorContent {
    pub cursor: Option<String>,
    pub background: Option<String>,
    pub selection: Option<String>,
}

// ─── ThemeColorsContent (UI renkleri — ~150 alan)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    pub border: Option<String>,
    #[serde(rename = "border.variant")]
    pub border_variant: Option<String>,
    #[serde(rename = "border.focused")]
    pub border_focused: Option<String>,
    #[serde(rename = "border.selected")]
    pub border_selected: Option<String>,
    #[serde(rename = "border.transparent")]
    pub border_transparent: Option<String>,
    #[serde(rename = "border.disabled")]
    pub border_disabled: Option<String>,

    pub background: Option<String>,
    #[serde(rename = "surface.background")]
    pub surface_background: Option<String>,
    #[serde(rename = "elevated_surface.background")]
    pub elevated_surface_background: Option<String>,

    #[serde(rename = "element.background")]
    pub element_background: Option<String>,
    #[serde(rename = "element.hover")]
    pub element_hover: Option<String>,
    #[serde(rename = "element.active")]
    pub element_active: Option<String>,
    #[serde(rename = "element.selected")]
    pub element_selected: Option<String>,
    #[serde(rename = "element.disabled")]
    pub element_disabled: Option<String>,

    pub text: Option<String>,
    #[serde(rename = "text.muted")]
    pub text_muted: Option<String>,
    #[serde(rename = "text.placeholder")]
    pub text_placeholder: Option<String>,
    #[serde(rename = "text.disabled")]
    pub text_disabled: Option<String>,
    #[serde(rename = "text.accent")]
    pub text_accent: Option<String>,

    pub icon: Option<String>,
    #[serde(rename = "icon.muted")]
    pub icon_muted: Option<String>,
    #[serde(rename = "icon.disabled")]
    pub icon_disabled: Option<String>,

    #[serde(rename = "terminal.ansi.black")]
    pub terminal_ansi_black: Option<String>,
    #[serde(rename = "terminal.ansi.red")]
    pub terminal_ansi_red: Option<String>,
    // ... 8 ANSI rengi × 3 (normal + bright + dim) = 24 alan
    // ... terminal background/foreground/bright_foreground/dim_foreground
    // ... editör, debugger, vcs, vim, panel, scrollbar, tab grupları
    // (tam liste: ThemeColors'taki ~150 alanın hepsi mirror edilir)
}

// Referans Zed sürümü için tam ThemeColorsContent alan haritası:
//
// border => "border"
// border_variant => "border.variant"
// border_focused => "border.focused"
// border_selected => "border.selected"
// border_transparent => "border.transparent"
// border_disabled => "border.disabled"
// elevated_surface_background => "elevated_surface.background"
// surface_background => "surface.background"
// background => "background"
// element_background => "element.background"
// element_hover => "element.hover"
// element_active => "element.active"
// element_selected => "element.selected"
// element_disabled => "element.disabled"
// element_selection_background => "element.selection_background"
// drop_target_background => "drop_target.background"
// drop_target_border => "drop_target.border"
// ghost_element_background => "ghost_element.background"
// ghost_element_hover => "ghost_element.hover"
// ghost_element_active => "ghost_element.active"
// ghost_element_selected => "ghost_element.selected"
// ghost_element_disabled => "ghost_element.disabled"
// text => "text"
// text_muted => "text.muted"
// text_placeholder => "text.placeholder"
// text_disabled => "text.disabled"
// text_accent => "text.accent"
// icon => "icon"
// icon_muted => "icon.muted"
// icon_disabled => "icon.disabled"
// icon_placeholder => "icon.placeholder"
// icon_accent => "icon.accent"
// debugger_accent => "debugger.accent"
// status_bar_background => "status_bar.background"
// title_bar_background => "title_bar.background"
// title_bar_inactive_background => "title_bar.inactive_background"
// toolbar_background => "toolbar.background"
// tab_bar_background => "tab_bar.background"
// tab_inactive_background => "tab.inactive_background"
// tab_active_background => "tab.active_background"
// search_match_background => "search.match_background"
// search_active_match_background => "search.active_match_background"
// panel_background => "panel.background"
// panel_focused_border => "panel.focused_border"
// panel_indent_guide => "panel.indent_guide"
// panel_indent_guide_hover => "panel.indent_guide_hover"
// panel_indent_guide_active => "panel.indent_guide_active"
// panel_overlay_background => "panel.overlay_background"
// panel_overlay_hover => "panel.overlay_hover"
// pane_focused_border => "pane.focused_border"
// pane_group_border => "pane_group.border"
// deprecated_scrollbar_thumb_background => "scrollbar_thumb.background"
// scrollbar_thumb_background => "scrollbar.thumb.background"
// scrollbar_thumb_hover_background => "scrollbar.thumb.hover_background"
// scrollbar_thumb_active_background => "scrollbar.thumb.active_background"
// scrollbar_thumb_border => "scrollbar.thumb.border"
// scrollbar_track_background => "scrollbar.track.background"
// scrollbar_track_border => "scrollbar.track.border"
// minimap_thumb_background => "minimap.thumb.background"
// minimap_thumb_hover_background => "minimap.thumb.hover_background"
// minimap_thumb_active_background => "minimap.thumb.active_background"
// minimap_thumb_border => "minimap.thumb.border"
// editor_foreground => "editor.foreground"
// editor_background => "editor.background"
// editor_gutter_background => "editor.gutter.background"
// editor_subheader_background => "editor.subheader.background"
// editor_active_line_background => "editor.active_line.background"
// editor_highlighted_line_background => "editor.highlighted_line.background"
// editor_debugger_active_line_background => "editor.debugger_active_line.background"
// editor_line_number => "editor.line_number"
// editor_active_line_number => "editor.active_line_number"
// editor_hover_line_number => "editor.hover_line_number"
// editor_invisible => "editor.invisible"
// editor_wrap_guide => "editor.wrap_guide"
// editor_active_wrap_guide => "editor.active_wrap_guide"
// editor_indent_guide => "editor.indent_guide"
// editor_indent_guide_active => "editor.indent_guide_active"
// editor_document_highlight_read_background => "editor.document_highlight.read_background"
// editor_document_highlight_write_background => "editor.document_highlight.write_background"
// editor_document_highlight_bracket_background => "editor.document_highlight.bracket_background"
// editor_diff_hunk_added_background => "editor.diff_hunk.added.background"
// editor_diff_hunk_added_hollow_background => "editor.diff_hunk.added.hollow_background"
// editor_diff_hunk_added_hollow_border => "editor.diff_hunk.added.hollow_border"
// editor_diff_hunk_deleted_background => "editor.diff_hunk.deleted.background"
// editor_diff_hunk_deleted_hollow_background => "editor.diff_hunk.deleted.hollow_background"
// editor_diff_hunk_deleted_hollow_border => "editor.diff_hunk.deleted.hollow_border"
// terminal_background => "terminal.background"
// terminal_foreground => "terminal.foreground"
// terminal_ansi_background => "terminal.ansi.background"
// terminal_bright_foreground => "terminal.bright_foreground"
// terminal_dim_foreground => "terminal.dim_foreground"
// terminal_ansi_black => "terminal.ansi.black"
// terminal_ansi_bright_black => "terminal.ansi.bright_black"
// terminal_ansi_dim_black => "terminal.ansi.dim_black"
// terminal_ansi_red => "terminal.ansi.red"
// terminal_ansi_bright_red => "terminal.ansi.bright_red"
// terminal_ansi_dim_red => "terminal.ansi.dim_red"
// terminal_ansi_green => "terminal.ansi.green"
// terminal_ansi_bright_green => "terminal.ansi.bright_green"
// terminal_ansi_dim_green => "terminal.ansi.dim_green"
// terminal_ansi_yellow => "terminal.ansi.yellow"
// terminal_ansi_bright_yellow => "terminal.ansi.bright_yellow"
// terminal_ansi_dim_yellow => "terminal.ansi.dim_yellow"
// terminal_ansi_blue => "terminal.ansi.blue"
// terminal_ansi_bright_blue => "terminal.ansi.bright_blue"
// terminal_ansi_dim_blue => "terminal.ansi.dim_blue"
// terminal_ansi_magenta => "terminal.ansi.magenta"
// terminal_ansi_bright_magenta => "terminal.ansi.bright_magenta"
// terminal_ansi_dim_magenta => "terminal.ansi.dim_magenta"
// terminal_ansi_cyan => "terminal.ansi.cyan"
// terminal_ansi_bright_cyan => "terminal.ansi.bright_cyan"
// terminal_ansi_dim_cyan => "terminal.ansi.dim_cyan"
// terminal_ansi_white => "terminal.ansi.white"
// terminal_ansi_bright_white => "terminal.ansi.bright_white"
// terminal_ansi_dim_white => "terminal.ansi.dim_white"
// link_text_hover => "link_text.hover"
// version_control_added => "version_control.added"
// version_control_deleted => "version_control.deleted"
// version_control_modified => "version_control.modified"
// version_control_renamed => "version_control.renamed"
// version_control_conflict => "version_control.conflict"
// version_control_ignored => "version_control.ignored"
// version_control_word_added => "version_control.word_added"
// version_control_word_deleted => "version_control.word_deleted"
// version_control_conflict_marker_ours => "version_control.conflict_marker.ours"
// version_control_conflict_marker_theirs => "version_control.conflict_marker.theirs"
// version_control_conflict_ours_background => "version_control_conflict_ours_background" (deprecated)
// version_control_conflict_theirs_background => "version_control_conflict_theirs_background" (deprecated)
// vim_normal_background => "vim.normal.background"
// vim_insert_background => "vim.insert.background"
// vim_replace_background => "vim.replace.background"
// vim_visual_background => "vim.visual.background"
// vim_visual_line_background => "vim.visual_line.background"
// vim_visual_block_background => "vim.visual_block.background"
// vim_yank_background => "vim.yank.background"
// vim_helix_jump_label_foreground => "vim.helix_jump_label.foreground"
// vim_helix_normal_background => "vim.helix_normal.background"
// vim_helix_select_background => "vim.helix_select.background"
// vim_normal_foreground => "vim.normal.foreground"
// vim_insert_foreground => "vim.insert.foreground"
// vim_replace_foreground => "vim.replace.foreground"
// vim_visual_foreground => "vim.visual.foreground"
// vim_visual_line_foreground => "vim.visual_line.foreground"
// vim_visual_block_foreground => "vim.visual_block.foreground"
// vim_helix_normal_foreground => "vim.helix_normal.foreground"
// vim_helix_select_foreground => "vim.helix_select.foreground"

// ─── StatusColorsContent (14 status × 3 = 42 alan)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct StatusColorsContent {
    pub error: Option<String>,
    #[serde(rename = "error.background")]
    pub error_background: Option<String>,
    #[serde(rename = "error.border")]
    pub error_border: Option<String>,

    pub warning: Option<String>,
    #[serde(rename = "warning.background")]
    pub warning_background: Option<String>,
    #[serde(rename = "warning.border")]
    pub warning_border: Option<String>,

    // ... 14 status (conflict, created, deleted, hidden, hint, ignored,
    // info, modified, predictive, renamed, success, unreachable) × üçlü
}
```

`ThemeColorsContent` referans Zed sürümü için 146 `Option<String>` alan
taşır. Bunların 143'ü runtime `ThemeColors` alanlarına birebir gider;
3'ü eski tema JSON'larını kırmamak için content-only deprecated uyumluluk
alanıdır:

- `deprecated_scrollbar_thumb_background` (`scrollbar_thumb.background`)
  yeni `scrollbar_thumb_background` boşsa ona aktarılır.
- `version_control_conflict_ours_background` yeni
  `version_control_conflict_marker_ours` boşsa ona aktarılır.
- `version_control_conflict_theirs_background` yeni
  `version_control_conflict_marker_theirs` boşsa ona aktarılır.

Refinement üretirken yeni alan **her zaman önceliklidir**; deprecated
alan sadece fallback olarak kullanılır. Runtime `ThemeColors` içinde
deprecated alan tutulmaz.

**Davranış kuralları (özet):**

| Tip | Opsiyonellik | Yanlış değer davranışı |
|-----|--------------|------------------------|
| `AppearanceContent` | `ThemeContent.appearance` **zorunlu** | Deserialize hatası (tema tüm yüklenmez) |
| `WindowBackgroundContent` | `ThemeStyleContent` üstünde `#[with_fallible_options]` var | User settings `RootUserSettings::parse_json` hattında `None` + `ParseStatus::Failed`; tema dosyası normal serde hattında deserialize hatası |
| `FontStyleContent` | `Option` + `treat_error_as_none` | `None` |
| `FontWeightContent` | `Option` + `treat_error_as_none`; `f32` newtype | `None` |
| `HighlightStyleContent.color` | `Option<String>`; özel deserializer yok | Geçersiz hex string → refinement'ta `None`; yanlış JSON tipi → deserialize hatası |
| `HighlightStyleContent` (diğer) | `Option<...>` + `treat_error_as_none` | `None` |
| `PlayerColorContent` (3 alan) | hepsi `Option<String>` | Eksik alan baseline.local'dan |
| `ThemeColorsContent` (150 alan) | her biri `Option<String>` | Refinement → baseline |
| `StatusColorsContent` (42 alan) | her biri `Option<String>` | Refinement → baseline (fg→bg türetme uygulanır) |

> **`AppearanceContent` neden `Option` değil?** Bir tema'nın "Light mı
> Dark mı" sorusu **kritik**; eksikse renk seçimi anlamsız. Tema
> yazarı bu alanı yazmak zorunda — sözleşmenin tek zorunlu enum alanı.

### `#[serde(flatten)]` — alt struct'ları aynı seviyeye açar

JSON dosyasında `style` objesi içinde **150+ alan düz olarak**
listelenir; iç içe `"colors": { ... }` yoktur. Bunu Rust'ta tutarken
mantıksal olarak grup ayrı struct'larda (`ThemeColorsContent`,
`StatusColorsContent`); ama JSON parse'ı sırasında **aynı seviyede**
deserialize edilirler. `#[serde(flatten)]` bu mapping'i sağlar.

**Davranış:**

```rust
ThemeStyleContent {
    #[serde(flatten, default)]
    pub colors: ThemeColorsContent,    // "background", "border", ...
    #[serde(flatten, default)]
    pub status: StatusColorsContent,   // "error", "warning", ...
    // ...
}
```

JSON:

```json
"style": {
  "background": "#000",       // ← ThemeColorsContent.background
  "border": "#111",           // ← ThemeColorsContent.border
  "error": "#f00",            // ← StatusColorsContent.error
  "warning": "#fa0"           // ← StatusColorsContent.warning
}
```

Iki ayrı struct'ın alanları **aynı JSON object'inde** karışık halde
deserialize edilir. Çakışan anahtar olamaz; `ThemeColorsContent`'in
"error" alanı yoksa (`StatusColorsContent`'te var) çakışma da yok.

### `#[serde(rename = "...")]` — alan adı eşleme

Rust alan adı snake_case, JSON anahtarı dot.separated:

```rust
#[serde(rename = "border.variant")]
pub border_variant: Option<String>,
```

Detay Konu 23'de.

### `#[serde(rename_all = "snake_case")]` — enum variant adları

`AppearanceContent`, `WindowBackgroundContent`, `FontStyleContent` gibi
**enum'lar** için variant adlarını JSON'a `snake_case` aktarmak:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AppearanceContent {
    Light,
    Dark,
}
```

→ JSON'da `"appearance": "light"` (Variant adı `Light` ama JSON'da
küçük harf). `rename_all = "snake_case"` her variant için tek tek
`rename` yazma yükünü ortadan kaldırır.

### `#[serde(transparent)]` — newtype'ı saydamlaştır

```rust
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct FontWeightContent(pub f32);
```

→ JSON'da `{ "font_weight": { "0": 700 } }` yerine doğrudan
`{ "font_weight": 700 }`. Newtype'ın sarmaladığı tek alan saydam
gösterilir; JSON tüketicisi `FontWeightContent`'in newtype olduğunu
bilmez.

### `#[serde(default)]` — eksik alana default değer

```rust
#[serde(flatten, default)]
pub colors: ThemeColorsContent,
```

JSON'da `colors` yok ise `ThemeColorsContent::default()` çağrılır =
tüm alanlar `None`. `default` annotation her bireysel alan için de
verilebilir:

```rust
#[serde(default)]
pub players: Vec<PlayerColorContent>,    // Yoksa boş Vec
```

### Hiyerarşik özet

| Attribute | Etkisi | Tema'da örnek |
|-----------|--------|---------------|
| `#[serde(flatten)]` | Alt struct'ı aynı seviyede aç | `ThemeColorsContent`/`StatusColorsContent` flatten ile düz |
| `#[serde(rename = "x.y")]` | Alan adını bağla | `border_variant` ↔ `"border.variant"` |
| `#[serde(rename_all = "snake_case")]` | Tüm variant'lara uygula | `AppearanceContent::Light` ↔ `"light"` |
| `#[serde(transparent)]` | Newtype'ı saydamlaştır | `FontWeightContent(700.0)` ↔ `700` |
| `#[serde(default)]` | Eksik alana default | `players: []` veya yok ise boş Vec |
| `#[serde(deserialize_with = "fn")]` | Custom deserializer | `treat_error_as_none` (Konu 22) |

### Tuzaklar

1. **`flatten` çakışması**: İki flatten'li struct'ın aynı isimli alanı
   olursa hangisinin önce parse edileceği tanımsız. Tema'da bu çakışma
   olmamalı; sözleşmede `ThemeColorsContent` ve `StatusColorsContent`
   alanları kesişmez.
2. **`flatten` performansı**: Serde flatten serde_derive'ın daha ağır
   üretimine yol açar. Tema deserialize hot path'te olmadığı için sorun
   değil; ama settings/config gibi sık çağrılan struct'ta dikkat.
3. **`rename` + alan-bazlı `default` çakışması**: `#[serde(rename =
   "x.y", default)]` doğru yazım; iki annotation tek `serde` parantezi
   içinde virgülle.
4. **`Serialize` türetmek opsiyonel**: Tema yalnız deserialize ediyorsa
   `Serialize` türetmeye gerek yok; ama `schemars::JsonSchema` veya
   round-trip test istiyorsan tut.
5. **`JsonSchema` türetimi**: `schemars` IDE auto-complete için tema
   dosyalarına JSON schema export edebilir. Türetim ücretsiz değil
   (compile time); kullanmıyorsan kaldır.

---

## 20. `*Content` tiplerinin opsiyonellik felsefesi

Content tipleri **tek bir kuralı** izler: her renk alanı `Option<String>`,
her enum alanı `Option<EnumContent>`. Hiçbir renk alanı sıkı tipli
`Hsla` veya zorunlu `String` değil.

### Üç gerekçe

**1. Kullanıcı her alanı yazmak zorunda değil.**

Zed temalarında tipik bir tema dosyası 150 alandan 30-50 tanesini yazar;
gerisi baseline'dan dolar. Eksik alanlar parse hatası vermek yerine
`None` olarak gelmeli — refinement katmanı (Bölüm VII) hangi alanın
override edildiğini, hangisinin baseline'dan kalacağını
`Some`/`None`'a göre ayırır.

**2. Renk parse hatası tüm temayı bozmamalı.**

```json
{
  "background": "#1c2025ff",     // ← geçerli
  "border": "rebeccapurple",     // ← geçersiz (named color, hex değil)
  "text": "#c8ccd4ff"            // ← geçerli
}
```

Eğer `border: String` (zorunlu) olsaydı, bir tek hatalı alan tüm temayı
hata ile yüklenmez yapar. `border: Option<String>` ile string olarak
gelir, sonra `try_parse_color` Result döner; başarısız ise refinement
`None`'a düşer ve baseline kullanılır.

**3. Tip sözleşmesi sürüm-bağımsız.**

Yarın Zed bir alana yeni bir varyant ekler (örn. `FontStyle::SemiOblique`).
Eski şema `font_style: "semi_oblique"` gibi değeri parse edemez.
**Eğer `font_style: Option<FontStyleContent>`** ise, `treat_error_as_none`
deserializer'ı (Konu 22) bilinmeyen variant'ı `None`'a düşürür ve tema
yüklemeye devam eder.

### İki katmanlı opsiyonellik

```
JSON          Content              Refinement       Theme
─────────────────────────────────────────────────────────
"#1c2025ff"   Some("#1c2025ff")   Some(Hsla(..))   Hsla(..)
"bozuk"       Some("bozuk")       None             baseline'dan
yok           None                 None             baseline'dan
```

**Görsel:**

- `Option<String>` katmanı = "kullanıcı bu alanı yazdı mı?"
- `Option<Hsla>` katmanı = "yazdıysa parse edilebildi mi?"

İki katman, iki ayrı hata türünü ayırt eder:

| Senaryo | Content katmanı | Refinement katmanı | Sonuç |
|---------|-----------------|--------------------|---------|
| Alan yok | `None` | `None` | Baseline |
| Alan var, geçerli hex | `Some("#...")` | `Some(Hsla(...))` | Kullanıcı override |
| Alan var, geçersiz hex | `Some("bozuk")` | `None` | Baseline (sessizce) |
| Alan var, geçerli ama farklı tip | `Some("...")` | `None` | Baseline (sessizce) |

### `Default::default()` her Content tipinde

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    pub border: Option<String>,
    pub border_variant: Option<String>,
    // ...
}
```

`Default` türetilir; tüm alanlar `Option<_>` olduğu için default = tüm
`None`. `#[serde(default)]` struct seviyesinde tüm alanlara uygulanır.

Bu sayede JSON'da bütün bir struct (`colors`, `status`, vs.) eksik
olabilir; serde flatten katmanı `Default::default()` çağırır ve devam
eder.

### `Option<String>` neden `Option<Hsla>` değil?

İlk akla gelen: "Madem string'i Hsla'ya çevireceğiz, baştan
`Option<Hsla>` neden olmasın?"

**Cevap:** Serde'in JSON'dan `Hsla`'ya doğrudan deserialize yolu yok.
GPUI `Hsla` için manuel `Deserialize` impl gerekirdi, ki bu da hex
string parse logic'ini struct attribute'una sokar = test edilemez,
hata mesajı kötü.

Mevcut yaklaşımda:
1. Serde sadece "string olarak al" der.
2. `try_parse_color` ayrı bir fonksiyon — birim test edilebilir.
3. Hatalı renk = string olarak content'te kalır; Refinement aşamasında
   sessizce `None`'a düşer.

Bu **sorumluluk ayrımı** sağlam: serde "yapı doğru mu?" sorusunu cevaplar,
parser "değer geçerli mi?" sorusunu cevaplar.

### Tuzaklar

1. **`String` (Option olmadan) kullanmak**: Zorunlu alan = bir eksik alan
   tüm temayı patlatır. Sözleşmeye uygun değil.
2. **`Option<Hsla>` kullanmak (parse'ı Deserialize'a sokmak)**: Custom
   Deserialize implementasyonu test edilemez, hata mesajı kötü, parser
   katmanını sözleşmeye gömer. Mevcut iki-katman yaklaşımı tercih.
3. **`Default::default()` alanı atlamak**: `#[derive(Default)]` olmayan
   Content tipi `#[serde(default)]` kullanamaz; struct seviyesi default
   şart.
4. **`Default` ile dolu Hsla beklemek**: Content tipinin Default'u tüm
   `None` döner. Default'tan Theme inşa edilmez; refinement aşaması
   baseline ile birleştirir. "Boş tema dosyasını yüklemek = baseline"
   bilinçli.
5. **Bilinmeyen enum'a panic**: `font_style: "semi_oblique"` —
   `FontStyleContent` `SemiOblique`'i tanımıyor. Default deserialize
   panic. Çözüm: `HighlightStyleContent` içinde `treat_error_as_none`;
   diğer option-heavy content tiplerinde `#[with_fallible_options]` macro
   (Konu 22).

### `MergeFrom` derive davranış matrisi

`settings_content` tarafındaki kullanıcı settings content tipleri
`#[derive(..., MergeFrom)]` ile işaretlenir. Zed settings hiyerarşisi
(`default.json → user.json → project.json`) **`MergeFrom` üzerinden çalışır**
— `default` baz değerleri sağlar, kullanıcı ve proje settings'i üstüne merge
edilir. Tema dosyası payload'ı olan `theme_settings::ThemeFamilyContent` /
`ThemeContent` bu merge hattı değildir; onlar doğrudan deserialize edilip
runtime tema'ya refine edilir. `MergeFrom` trait'i
`settings_content/src/merge_from.rs` içinde tanımlıdır; alan tipine göre
davranış farklıdır:

| Alan tipi | `merge_from(self, other)` davranışı | Etki |
|-----------|-------------------------------------|------|
| Primitive (`u16`, `u32`, `i*`, `bool`, `f32`, `f64`, `char`, `usize`, `NonZeroUsize`, `NonZeroU32`) | `*self = other.clone()` | **Overwrite** — kullanıcı değeri default'u tamamen ezer |
| `String`, `Arc<str>`, `PathBuf`, `Arc<Path>` | overwrite | Aynı: tek bir scalar, üzerine yaz |
| `Option<T>` | `None` ise yok say; mevcut `Some` + yeni `Some` → recursive merge (`this.merge_from(other)`); mevcut `None` + yeni `Some` → `replace(other.clone())` | Recursive merge için en uygun tip |
| `Vec<T>` | `*self = other.clone()` | **Overwrite** (concat değil) — `accents: ["#aaa"]` user'ı default `accents`'i siler |
| `Box<T: MergeFrom>` | `self.as_mut().merge_from(other.as_ref())` | Pointer içeriği recursive merge |
| `HashMap<K, V: MergeFrom>` / `BTreeMap` / `IndexMap` | Her key için: varsa recursive merge, yoksa insert | Map'lerin key-bazlı birleşmesi (örn. `theme_overrides`) |
| `HashSet<T>` / `BTreeSet<T>` | union (her item insert) | Set'ler |
| `serde_json::Value` | Object → recursive merge; aksi halde overwrite | Free-form JSON için akıllı merge |

**Tema sözleşmesi için kritik sonuçlar:**

1. **`accents: Vec<AccentContent>` overwrite davranır**. Kullanıcı
   `experimental.theme_overrides.accents = ["#abc"]` yazdığında
   tema'nın baseline accent listesi silinir. Bunun istenmeyen yan etkisi
   var: tek bir rengi değiştirmek için kullanıcı tüm listeyi yeniden
   yazmalıdır. `merge_accent_colors` (Konu 32 Adım 5) bu davranışı
   `theme_overrides` zinciri içinde **partial fallback** ile yumuşatır
   ama JSON merge seviyesinde liste hâlâ atomic.

2. **`theme_overrides: HashMap<String, ThemeStyleContent>` key-bazlı
   merge**. Kullanıcı yalnız `"One Dark": { ... }` yazsa bile
   `default.json`'da bulunan diğer tema override'ları korunur. Aynı tema
   adı için iki katmanda override varsa içleri recursive merge edilir.

3. **`Option<ThemeSelection>` recursive merge**. `default.json`'da
   `theme = Static("One Dark")`, user'da `theme = Dynamic { mode: System,
   light: ..., dark: ... }` ise: `Some + Some` → recursive `merge_from`
   çalışır. `ThemeSelection` kendisi `MergeFrom` derive'a sahip olduğu
   için variant değişebilir; ama bu derive enum davranışı **iç
   değerleri birleştirmek değil, override etmektir** (variant'lar farklı).

4. **Color string'leri `Option<String>` olduğu için her renk alanı**:
   - default'ta verilmemiş, user'da var → user değeri yazılır
   - default'ta var, user'da yok → default korunur
   - default'ta var, user'da var → user değeri yazılır (`String` overwrite)

Bu davranış matrisi `treat_error_as_none` vs. `with_fallible_options`
geçişinden bağımsızdır; ikisi de **parse seviyesinde**, MergeFrom ise
**post-parse merge seviyesinde** çalışır.

> **Mirror disiplini:** `kvs_tema` veya `kvs_ayarlari_icerik` crate'i bir
> `MergeFrom` derive macro'su mirror etmelidir (veya `settings_macros`
> crate'ini bağımlı bağlamalıdır). Tema sözleşmesi `MergeFrom`'a güvenir;
> elle `merge_from` yazmak (her *Content tipi için) çok dağınık ve hata
> kaynağı olur.

---

## 21. `try_parse_color`: hex → `Hsla` boru hattı

**Kaynak:** `kvs_tema/src/schema.rs` veya `kvs_tema/src/refinement.rs`
(yerleşimi kararsız).

JSON'dan gelen hex string'i runtime `Hsla`'ya çeviren tek fonksiyon:

```rust
use gpui::Hsla;
use palette::FromColor;

pub fn try_parse_color(s: &str) -> anyhow::Result<Hsla> {
    let rgba = gpui::Rgba::try_from(s)?;
    let srgba = palette::rgb::Srgba::from_components(
        (rgba.r, rgba.g, rgba.b, rgba.a)
    );
    let hsla = palette::Hsla::from_color(srgba);

    Ok(gpui::hsla(
        hsla.hue.into_positive_degrees() / 360.0,
        hsla.saturation,
        hsla.lightness,
        hsla.alpha,
    ))
}
```

### Boru hattı 4 adım

```
"#1c2025ff"  →  gpui::Rgba  →  palette::Srgba  →  palette::Hsla  →  gpui::Hsla
  hex string    (1) parse      (2) reinterpret    (3) color-space   (4) normalize
```

**Adım 1 — Hex string'i parse:**

```rust
let rgba = gpui::Rgba::try_from(s)?;
```

`gpui::Rgba::try_from` (`gpui/src/color.rs:162`) **dört** hex formatını
kabul eder:

| Format | Hex hanesi | Alpha kaynağı | Çiftleme |
|--------|-----------|---------------|----------|
| `#rgb` | 3 | `0xf` (`1.0`) | `0xa → 0xaa` (her hane çiftlenir) |
| `#rgba` | 4 | 4. hane | `0xa → 0xaa` (4 hane de çiftlenir) |
| `#rrggbb` | 6 | `0xff` (`1.0`) | yok |
| `#rrggbbaa` | 8 | son 2 hane | yok |

Önemli kurallar:

- **`#` zorunlu**: Kaynak kod `value.trim().split_once('#')` ile parse
  başlatır; `#` olmadan girilen hex (`RRGGBB`) `Err` döndürür.
- **Trim yapılır**: Önceki/sonraki whitespace temizlenir (`"  #1c2025  "`
  geçerlidir).
- **Büyük/küçük harf duyarsız**: `u8::from_str_radix(..., 16)` zaten
  duyarsız; `#1c2025FF` ve `#1C2025ff` aynı.
- **Kısa form çiftleme**: `#abc` → `#aabbcc`, `#abcd` → `#aabbccdd`.
  Tek hane `r` baytı 4 bit sola kaydırılıp kendisiyle OR'lanır
  (`(value << 4) | value`).
- **Alpha varsayılanı**: `#rgb` formatında alpha hane'si `0xf` (yani
  `0xff` = `1.0`); `#rrggbb` formatında byte `0xff`.

Hata durumları:

- Geçersiz hex karakter (`#zzz`): `u8::from_str_radix` `Err`.
- Tanınmayan uzunluk (`#abcde` 5 hex veya `#abcdefg` 7 hex): `match` 4
  varyantın hiçbirine düşmez, fall-through hatası.
- `#` yok: "invalid RGBA hex color" hatası.
- Boş string: `#` bulunamaz → `Err`.

Bu nedenle tema JSON'ında `"#abc"` yazmak geçerlidir; kısa form da Zed
paritesindeki desteklenen hex biçimlerindendir.

**Adım 2 — `Rgba` → `palette::Srgba`:**

```rust
let srgba = palette::rgb::Srgba::from_components(
    (rgba.r, rgba.g, rgba.b, rgba.a)
);
```

GPUI'nin `Rgba` tipi ile palette crate'inin `Srgba` tipi **aynı bellek
düzenine sahip** ama farklı crate'lerde. `from_components` tuple alıp
struct'a yerleştirir; veri kopyası yok denecek kadar küçük (4 × f32).

**Adım 3 — sRGB → HSL color space:**

```rust
let hsla = palette::Hsla::from_color(srgba);
```

`palette::Hsla` ve `palette::Srgba` farklı renk uzayında — sRGB cube'den
HSL silindirine matematiksel dönüşüm. `palette` crate'inin asıl işi
burada.

**Adım 4 — `palette::Hsla` → `gpui::Hsla`:**

```rust
gpui::hsla(
    hsla.hue.into_positive_degrees() / 360.0,
    hsla.saturation,
    hsla.lightness,
    hsla.alpha,
)
```

İki crate'in `Hsla` yapısı **uyumsuz**:

| Alan | palette | gpui |
|------|---------|------|
| `hue` | Derece (0-360°), `palette::RgbHue` newtype | Normalize (0.0-1.0), düz `f32` |
| `saturation` | 0.0-1.0 | 0.0-1.0 |
| `lightness` | 0.0-1.0 | 0.0-1.0 |
| `alpha` | 0.0-1.0 | 0.0-1.0 |

`hue.into_positive_degrees()` negatif değerleri 0-360'a normalize eder
(`-30°` → `330°`); `/ 360.0` ile GPUI normalize uzayına çekilir.

### Dönüş tipi: `Result<Hsla>`, Caller'da `Option<Hsla>`

`anyhow::Result<Hsla>` döner. Çağıran taraf hatayı `Option`'a yutuyor:

```rust
fn color(s: &Option<String>) -> Option<gpui::Hsla> {
    s.as_deref().and_then(|s| try_parse_color(s).ok())
}
```

Bu desen Bölüm VII/Konu 30'te detaylı: `Some(geçersiz hex) → None`.

### Test ve idempotans

`try_parse_color` saf (deterministic) ve test edilebilir:

```rust
#[test]
fn parse_solid_red() {
    let c = try_parse_color("#ff0000ff").unwrap();
    assert!((c.h - 0.0).abs() < 1e-3);
    assert!((c.s - 1.0).abs() < 1e-3);
    assert!((c.l - 0.5).abs() < 1e-3);
    assert!((c.a - 1.0).abs() < 1e-3);
}

#[test]
fn rejects_named_color() {
    assert!(try_parse_color("red").is_err());
}
```

### `palette` versiyonu önemli

`palette` major sürüm farkı color-space dönüşümünü değiştirebilir; aynı
hex farklı `Hsla` üretir. Bu yüzden:

- `palette` sürümü Zed'in kullandığı sürümle uyumlu olmalı (Bölüm II/Konu 5).
- Fixture testleri `assert_eq!(...)` yerine `assert!((a - b).abs() <
  epsilon)` ile yazılır — küçük floating-point kayması beklenir.

### Performans

Her renk alanı için tek bir `try_parse_color` çağrısı; bir tema ~150
renk için ~150 fonksiyon çağrısı. Tek tema yüklemesi mikrosaniye
düzeyinde. Hot path değil.

### Tuzaklar

1. **3-hex shorthand desteksiz**: `#abc` (CSS shorthand) parse edilmez.
   Zed temalarında kullanılmaz, ama kullanıcı temasında karşılaşılırsa
   parse hatası.
2. **`palette` ihmali**: Manuel sRGB → HSL dönüşümü yazmak (palette
   olmadan) Zed davranışından sapar. Kullan.
3. **Negatif hue korunması**: `palette::Hsla::from_color` bazen `hue =
   -30°` döndürür; `into_positive_degrees()` zorunlu, atla = `h = -30/360
   = -0.083` ki GPUI bunu 0.917'ye sarmaz, **clamp eder**.
4. **`alpha = 0.0` hata gibi görünür**: Geçerli bir tema rengi (örn.
   `transparent_black`) alpha 0 olabilir. `try_parse_color` Ok döner,
   `Hsla.a = 0.0`. UI'da görünmez ama parse hatası değil — fark et.
5. **Refinement aşamasında hata yutmak**: `try_parse_color(s).ok()`
   hata mesajını siler. Debug için log: `try_parse_color(s).inspect_err(
   |e| tracing::warn!("bad color: {}", e)).ok()`.

---

## 22. Hata tolerans: `treat_error_as_none`, `deny_unknown_fields` tuzağı

Tema sözleşmesinin **forward compatibility** prensibi: gelecekte Zed
yeni bir alan veya yeni bir enum varyantı eklerse, eski kod **patlaması
yerine sessizce göz ardı etmeli**. İki ayrı vektör var: bilinmeyen
**alanlar** ve bilinmeyen **değerler**.

### Vektör 1: Bilinmeyen alanlar — `deny_unknown_fields` YASAK

Serde varsayılan olarak bilinmeyen alanları **görmezden gelir**. Yeni
bir alan JSON'da göründüğünde mevcut Content struct'ı onu sessizce
atlar. **Bu davranış tam istediğimiz.**

```rust
// YASAK:
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]   // ← Zed yeni alan eklerse parse PATLAR
pub struct ThemeColorsContent { ... }

// DOĞRU:
#[derive(Deserialize)]
// deny_unknown_fields YOK — bilinmeyen alan göz ardı edilir
pub struct ThemeColorsContent { ... }
```

**Senaryo:** Zed `inlay_hint_background` alanı ekledi. Sen henüz mirror
etmedin. JSON'da bu anahtar var:

- `deny_unknown_fields` AÇIK: Tüm tema yüklemesi `Err("unknown field
  inlay_hint_background")`. Kullanıcı tema açamaz.
- `deny_unknown_fields` KAPALI (default): Alan sessizce atlanır. Tema
  yüklenir, sadece o alanın özelliği etkisiz kalır.

**Bu kural keskin:** Tema sözleşmesinin **hiçbir** Content tipinde
`deny_unknown_fields` kullanma.

### Vektör 2: Bilinmeyen enum değerleri — iki tolerans hattı

Enum alanlar için varsayılan davranış farklı: serde bilinmeyen variant
gördüğünde `Err` döner.

**Senaryo:** Zed `FontStyle::SemiOblique` ekledi. JSON: `"font_style":
"semi_oblique"`. Sen `FontStyleContent` mirror'unda bu variant yok.

- Standart deserialize: `Err("unknown variant semi_oblique, expected one
  of normal, italic, oblique")`. Tüm tema patlar.
- `HighlightStyleContent` içinde: `treat_error_as_none` alanı `None`'a düşürür.
- `#[with_fallible_options]` kullanılan diğer content tiplerinde: alan
  `None`'a düşer ve hata thread-local hata listesinde biriktirilerek dosyanın
  `ParseStatus`'una yansıtılır.

**Zed paritesi iki ayrı mekanizmadır:**

1. **Attribute macro** (`#[with_fallible_options]`): `ThemeSettingsContent`,
   `ThemeStyleContent`, `ThemeColorsContent`, `StatusColorsContent` gibi
   option-heavy struct/enum'lar üstüne yerleştirilir. Macro her `Option<T>`
   alanı için otomatik şu attribute'u ekler:
   ```rust
   #[serde(
       default,
       skip_serializing_if = "Option::is_none",
       deserialize_with = "crate::fallible_options::deserialize",
   )]
   ```
   Bu hatları elle `#[serde(deserialize_with = "...")]` yazmadan kurarsın.

2. **`fallible_options::deserialize` fonksiyonu**: Tek tek alanı çağırır;
   hata varsa thread-local `ERRORS` listesine ekler ve `Default::default()`
   (yani `None`) döndürür. `ERRORS` `None` ise (parse_json çağrılmadıysa)
   hatayı yutmaz, yukarı kabarcıklar.

3. **`fallible_options::parse_json::<T>(json)`**: Top-level çağrı.
   `ERRORS` thread-local'ını sıfırlar, parse'ı çalıştırır, bittikten sonra
   biriken hataları toplar ve `(Option<T>, ParseStatus)` döner. `ParseStatus`
   **üç variantlıdır** (`settings_content::ParseStatus`,
   `settings_content/src/settings_content.rs:76`): `Success`,
   `Unchanged` (kaynak dosya değişmediği için parse atlandı), ve
   `Failed { error: String }`. `Unchanged` yalnızca settings dosya yönetim
   katmanından gelir (file watcher değişiklik olmadığına karar verirse);
   `parse_json` doğrudan çağrıldığında `Success` veya `Failed` döner.

Public tüketici yolu genelde doğrudan `fallible_options::parse_json` değildir.
`settings_content::RootUserSettings` trait'i `SettingsContent`,
`Option<SettingsContent>` ve `UserSettingsContent` için
`parse_json(json) -> (Option<Self>, ParseStatus)` ve
`parse_json_with_comments(json) -> anyhow::Result<Self>` sağlar. İç helper
`fallible_options::deserialize` ise `pub(crate)` kalır; yalnız
`#[with_fallible_options]` macro'sunun eklediği serde attribute'u tarafından
crate içinden çağrılır.

Bu tolerans **yalnız `fallible_options::parse_json` / `RootUserSettings`
hattında** tam davranır. Tema dosyaları farklı yoldan gelir:
`load_bundled_themes` bundled `assets/themes/*.json` için
`serde_json::from_slice`, `deserialize_user_theme` kullanıcı tema dosyası için
`serde_json_lenient::from_slice` kullanır. Bu normal serde yollarında
`ERRORS` thread-local'ı kurulmadığı için `fallible_options::deserialize`
hatayı yutmaz, deserialize hatası olarak döndürür. `HighlightStyleContent`
içindeki yerel `treat_error_as_none` ise bu thread-local'a bağlı değildir ve
tema dosyası parse'ında da seçili alanları `None`'a düşürür.

4. **`HighlightStyleContent` istisnası**: Bu struct
   `#[with_fallible_options]` kullanmaz. Kaynakta yalnız
   `background_color`, `font_style`, `font_weight` alanlarında yerel
   `treat_error_as_none` vardır; `color` alanında yoktur. Sonuç olarak
   `"font_style": "semi_oblique"` veya `"background_color": 3` sessizce
   `None` olur, ama `"color": 3` doğrudan deserialize hatası üretir. Geçersiz
   renk string'i (`"color": "not-a-color"`) ise content aşamasında `Some`
   kalır ve refinement'ta `try_parse_color(...).ok()` ile `None`'a düşer.

**Mekanizma (kullanıcı tarafından görünmeyen):**

1. `parse_json::<ThemeColorsContent>(json)` çağrılır.
2. Her `Option<T>` alanı için macro tarafından eklenen
   `fallible_options::deserialize` çağrılır.
3. Bir alan parse hata verirse → hata thread-local'a yazılır, alan `None`
   olarak set edilir, parse devam eder.
4. Tüm parse bitince `ParseStatus` döner; UI gerekirse uyarı gösterir,
   eksik alan baseline'dan dolar.

**Kullanım (mirror tarafı):**

```rust
#[settings_macros::with_fallible_options]
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema, MergeFrom)]
#[serde(default)]
pub struct ThemeColorsContent {
    pub text: Option<String>,
    pub icon: Option<String>,
    // ...
}
```

`HighlightStyleContent` ise Zed'de hâlâ özel deserializer kullanır:

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema, MergeFrom, PartialEq)]
#[serde(default)]
pub struct HighlightStyleContent {
    pub color: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", deserialize_with = "treat_error_as_none")]
    pub background_color: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", deserialize_with = "treat_error_as_none")]
    pub font_style: Option<FontStyleContent>,
    #[serde(skip_serializing_if = "Option::is_none", deserialize_with = "treat_error_as_none")]
    pub font_weight: Option<FontWeightContent>,
}
```

> **Notlar:**
>
> - Macro yalnız `Option<T>` alanlarını işaretler; `Vec<T>`, `String`,
>   primitive alanlar etkilenmez — onların hatası hâlâ üst seviyeyi patlatır.
> - `HighlightStyleContent` için eski elle yazılmış `treat_error_as_none`
>   pattern'i kaynakta hâlâ geçerli; bunu `#[with_fallible_options]` ile
>   değiştirme kararı Zed tarafında verilmeden mirror tarafında değiştirme.
> - `serde_json_lenient` deserializer'ı (`parse_json` içinde kullanılır)
>   trailing comma'ları ve comment'leri kabul eder; bu da kullanıcı dostu
>   editör deneyimine ek toleranstır.

### Hata tolerans matrisi

| Senaryo | Default davranış | İstediğimiz | Çözüm |
|---------|------------------|-------------|-------|
| Bilinmeyen alan | Görmezden gelir | Görmezden gelinsin | Hiçbir şey yapma (`deny_unknown_fields` ekleme) |
| Bilinmeyen enum variant | Err | None'a düş | `treat_error_as_none` veya `#[with_fallible_options]` |
| Yanlış tip (örn. number bekleniyor, string geldi) | Err | None'a düş | `treat_error_as_none` veya `#[with_fallible_options]` |
| Hex parse hatası | (Content katmanı string olarak alır) | None'a düş | Refinement katmanında `try_parse_color(s).ok()` |
| `null` değer | None | None | Default davranış uyar |

### Test örnekleri

```rust
#[test]
fn unknown_field_does_not_break() {
    let json = r#"{
        "name": "Test", "author": "x",
        "themes": [{
            "name": "T", "appearance": "dark",
            "style": {
                "background": "#000000ff",
                "future.unknown.field": "#ffffffff"   // ← yeni alan
            }
        }]
    }"#;
    let family: ThemeFamilyContent =
        serde_json_lenient::from_str(json).unwrap();   // parse oluyor
}

#[test]
fn unknown_font_style_falls_to_none() {
    let json = r#"{ "color": "#000", "font_style": "semi_oblique" }"#;
    let h: HighlightStyleContent = serde_json::from_str(json).unwrap();
    assert!(h.font_style.is_none());                   // bilinmeyen → None
    assert!(h.color.is_some());                        // diğer alan etkilenmez
}
```

### Tuzaklar

1. **`deny_unknown_fields` cazibesi**: "Daha sıkı validation iyi" mantığı
   yanlış. Sözleşme **yaşayan**; sıkı validation = breaking change'lerde
   acı.
2. **`treat_error_as_none` her yerde**: Zed bunu yalnız
   `HighlightStyleContent`'te seçili alanlara koyuyor. Genel settings
   content'inde macro kullanılıyor; syntax highlight struct'ında ise mevcut
   özel davranışı değiştirme.
3. **Hata yutmayı sessizce yapmak**: Production'da `tracing::warn!` ile
   log et — kullanıcı tema dosyasındaki tipo'yu fark etmesin diye değil,
   debug için. Default log kapalı tut.
4. **`#[serde(default)]` unutmak**: `deserialize_with` yazıldığında
   default davranış değişir; `default` annotation şart, yoksa alan yoksa
   hata.
5. **`serde_json::Value` performans**: `treat_error_as_none` her alanı
   bir kez `Value`'ya, sonra tipe çevirir = iki kez parse. Hot path
   değil, tema yüklemesi nadir. Sorun değil.

---

## 23. JSON anahtar konvansiyonu (dot vs snake_case)

Tema JSON dosyalarında alan adları **dot.separated** yazılır; Rust
alan adları **snake_case**. İki konvansiyon `#[serde(rename = "...")]`
ile bağlanır.

### Konvansiyon

| Konum | Stil | Örnek |
|-------|------|-------|
| Zed JSON dosyası | `dot.separated` | `border.variant`, `element.hover`, `text.muted`, `terminal.ansi.red` |
| Rust alan adı | `snake_case` | `border_variant`, `element_hover`, `text_muted`, `terminal_ansi_red` |
| `#[serde(rename = "...")]` | Bağlantı | `#[serde(rename = "border.variant")]` |

### Mekanizma

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    #[serde(rename = "border")]
    pub border: Option<String>,

    #[serde(rename = "border.variant")]
    pub border_variant: Option<String>,

    #[serde(rename = "border.focused")]
    pub border_focused: Option<String>,

    #[serde(rename = "element.hover")]
    pub element_hover: Option<String>,
    // ...
}
```

**Her alan için ayrı `rename`** — `rename_all` snake_case ↔ dot dönüşümü
sağlayamaz (serde'in rename_all'u kebab-case, camelCase, PascalCase,
SCREAMING_SNAKE_CASE destekler; dot ayrımı yoktur). Yani her alan elle
işaretlenir.

### Hiyerarşi gösterimi

Dot konvansiyonu Zed JSON'unun **görsel hiyerarşisini** korur:

```json
{
  "background": "#000",                  // genel arka plan
  "background.appearance": "opaque",     // pencere arka plan tipi
  "border": "#111",                      // ana border
  "border.variant": "#222",              // alternatif border
  "border.focused": "#3a8",              // focus durumunda border
  "border.disabled": "#444",             // disabled durumunda border
  "element.hover": "#332",               // element üzerinde hover
  "element.active": "#443",              // element basılı
  "element.selected": "#a83",            // element seçili
  "terminal.ansi.red": "#f00",           // terminal ANSI 8 kırmızı
  "terminal.ansi.bright_red": "#f44"     // terminal ANSI bright kırmızı
}
```

Tek bir alfabetik sıralama ile **mantıksal gruplar** yan yana gelir —
`border` ailesinin tamamı, `element` ailesinin tamamı, `terminal.ansi`
ailesinin tamamı. Snake_case'te bu sıralama bozulurdu (`border_variant`,
`border_focused`, `border_disabled` alfabetik olarak `disabled`,
`focused`, `variant` sırasında dağılır).

### Çift altçizgi konvansiyonu (boundary case)

Bazı alanlar **iki seviye** dot konvansiyon taşır:

| JSON | Rust |
|------|------|
| `terminal.ansi.red` | `terminal_ansi_red` |
| `terminal.ansi.bright_red` | `terminal_ansi_bright_red` |
| `version_control.added` | `version_control_added` |

Yani: dot **alt seviye ayrımı**, underscore **kelime ayrımı**. JSON
anahtarındaki underscore Rust adında korunur:

```json
"terminal.ansi.bright_red": "#ff5555"
```

```rust
#[serde(rename = "terminal.ansi.bright_red")]
pub terminal_ansi_bright_red: Option<String>,
```

### Status renklerinde özel durum

`StatusColors`'ta `_background` ve `_border` Rust suffix'leri JSON'da
**ayrı dot seviyesi** olur:

| Rust alan | JSON anahtarı |
|-----------|---------------|
| `error` | `error` |
| `error_background` | `error.background` |
| `error_border` | `error.border` |
| `success_background` | `success.background` |

```rust
#[serde(rename = "error")]
pub error: Option<String>,

#[serde(rename = "error.background")]
pub error_background: Option<String>,

#[serde(rename = "error.border")]
pub error_border: Option<String>,
```

### Pratik liste

Yaygın renk grupları için Rust ↔ JSON eşlemesi:

| Rust | JSON |
|------|------|
| `border` | `border` |
| `border_variant` | `border.variant` |
| `border_focused` | `border.focused` |
| `border_selected` | `border.selected` |
| `border_transparent` | `border.transparent` |
| `border_disabled` | `border.disabled` |
| `surface_background` | `surface.background` |
| `elevated_surface_background` | `elevated_surface.background` |
| `element_background` | `element.background` |
| `element_hover` | `element.hover` |
| `element_active` | `element.active` |
| `element_selected` | `element.selected` |
| `element_disabled` | `element.disabled` |
| `ghost_element_background` | `ghost_element.background` |
| `text_muted` | `text.muted` |
| `text_placeholder` | `text.placeholder` |
| `text_accent` | `text.accent` |
| `icon_muted` | `icon.muted` |
| `terminal_ansi_red` | `terminal.ansi.red` |
| `terminal_ansi_bright_red` | `terminal.ansi.bright_red` |
| `error_background` | `error.background` |
| `version_control_added` | `version_control.added` |

> **Kaynak eşleşmesi:** Bu tablo Zed'in
> `crates/settings_content/src/theme.rs` dosyasındaki
> `#[serde(rename = "...")]` annotation'larıyla birebir aynı anahtarları
> kullanır.

### Tuzaklar

1. **`rename` olmadan snake_case beklemek**: `border_variant` (Rust)
   yazıp `rename` koymazsan, serde JSON'da `"border_variant"` bekler.
   Zed JSON'unda `"border.variant"` yazıyor → alan **sessizce boş kalır**
   (`None`). En yaygın hata.
2. **`rename` typo'su**: `#[serde(rename = "boder.variant")]` (typo'lu).
   Compile hatası olmaz, parse'ta alan boş kalır; gerçek tema örnekleri
   bu tür eşleşme hatalarını görünür kılar.
3. **`rename_all` snake_case'e güvenmek**: `#[serde(rename_all =
   "snake_case")]` Rust ↔ snake_case JSON dönüşümü için; dot konvansiyonu
   için **işe yaramaz**. Her alanı elle işaretle.
4. **Dot içinde alanı tek kelime sanmak**: `border.variant` Rust'ta iki
   alan değil tek alan (`border_variant`). Dot kelime ayırıcı değil, dot
   hiyerarşi ayırıcı.
5. **`status.error` yerine `error.status`**: Status renklerinde JSON
   prefix `error.background`, **`status.error_background` değil**.
   StatusColors flatten ile düz seviyeye açılır; "status" anahtarı
   yoktur. Aynı şey `colors.background` yerine `background` için de
   geçerli.
6. **JSON 'da hem `border_variant` hem `border.variant` yazmak**:
   Kullanıcı temasında bu iki anahtar görünürse hangisinin kazanacağı
   tanımsız. Geliştirici doc'unda **sadece dot konvansiyonu**'nu önder.

### `serde_json_lenient` ile JSON yazım kolaylığı

Zed tema dosyaları **standart JSON değil**: yorum satırları ve trailing
comma içerebilir. Bunları parse edebilmek için `serde_json_lenient`
kullanılır (Konu 5 bağımlılık matrisinde sabit).

**Desteklenen genişletmeler:**

```jsonc
{
  // Tek satır yorum (// ile başlar)
  "name": "My Theme",
  "author": "x",

  /* Çok satırlı yorum bloğu —
     açıklama, atıf, vs. */
  "themes": [{
    "name": "My Dark",
    "appearance": "dark",
    "style": {
      "background": "#1c2025ff",
      "border":     "#2a2f3aff",   // satır sonu yorumu da kabul
      "text":       "#c8ccd4ff",   // ← trailing comma yasal
    },
  }],   // ← array elemanı sonrası trailing comma
}       // ← object kapatması öncesi trailing comma
```

**Standart `serde_json` (lenient olmayan) bu JSON'u parse edemez:**
yorum satırı `Err("expected value")`, trailing comma `Err("trailing
comma")` verir. Zed tüm built-in temalarını yorum/trailing comma ile
yazıyor; bu yüzden `serde_json_lenient` **zorunlu**.

**Kullanım:**

```rust
let family: ThemeFamilyContent =
    serde_json_lenient::from_slice(&bytes)?;
// veya str için:
let family: ThemeFamilyContent =
    serde_json_lenient::from_str(json)?;
```

API yüzeyi `serde_json` ile uyumlu — sadece import farkı.

**Sınırlamalar:**

- Unquoted key (`{ name: "x" }`) **kabul edilmez** — JavaScript object
  literal değil, JSON.
- Single quote string (`'value'`) kabul edilmez.
- JSON5'in genişletmeleri tam olarak destekli değil; sadece yorum +
  trailing comma.

**Tuzak — yazma yönü:** Tema dosyasını sen yazıyorsan (test fixture,
fallback dump) `serde_json::to_string_pretty` çıktısı standart JSON'dur
(yorumsuz). Lenient sadece **okuma**da; yazılan çıktı sade JSON
formatındadır.

---

## 24. `deserialize_icon_theme` — IconTheme JSON helper'ı

**Kaynak:** `crates/theme/src/theme.rs:286`.

Konu 18'de icon tema JSON yüklemesini gösterdik. Zed bu işi tek satır
helper'la sarmalar:

```rust
pub fn deserialize_icon_theme(bytes: &[u8]) -> anyhow::Result<IconThemeFamilyContent> {
    serde_json_lenient::from_slice(bytes).context("icon theme deserialize")
}
```

**`kvs_tema`'daki karşılığı:**

```rust
pub fn deserialize_icon_theme(bytes: &[u8]) -> anyhow::Result<IconThemeFamilyContent> {
    serde_json_lenient::from_slice(bytes)
        .with_context(|| "icon tema parse hatası")
}
```

Tek satırlık helper ama:

- `serde_json_lenient` import'unu tüketici crate'den gizler.
- Hata mesajını `anyhow::Context` ile zenginleştirir.
- Parser implementasyonu değişirse (örn. `serde_json` ile `comments`
  feature'ı), helper içeride güncellenir; tüketici etkilenmez.

---

