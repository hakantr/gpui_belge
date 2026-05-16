# JSON sözleşmesi ve parse katmanı

Runtime modeli kurulduktan sonra sıra JSON sözleşmesine gelir. Burada üç konu
birlikte düşünülür: Zed uyumlu JSON yapısı, alanların opsiyonel ele alınması
ve parse sırasında ne kadar hata toleransı gösterileceği. Bu kararlar birbirine
sıkı bağlıdır; birindeki tercih diğer ikisinin davranışını doğrudan etkiler.

---

## 19. `ThemeContent` ve serde flatten/rename desenleri

**Kaynak modül:** `kvs_tema/src/schema.rs`.

JSON tema dosyalarını parse eden tip hiyerarşisi üç seviyeden oluşur:

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

`ThemeColorsContent`, referans Zed sürümünde 146 adet `Option<String>` alan
taşır. Bunların 143'ü runtime `ThemeColors` alanlarına birebir gider. Geriye
kalan 3 alan ise eski tema JSON'larını kırmamak için yalnızca content
tarafında tutulan deprecated uyumluluk alanlarıdır:

- `deprecated_scrollbar_thumb_background` (`scrollbar_thumb.background`)
  yeni `scrollbar_thumb_background` alanı boş olduğunda ona aktarılır.
- `version_control_conflict_ours_background`, yeni
  `version_control_conflict_marker_ours` boş olduğunda ona aktarılır.
- `version_control_conflict_theirs_background`, yeni
  `version_control_conflict_marker_theirs` boş olduğunda ona aktarılır.

Refinement üretilirken yeni alan **her zaman önceliklidir**. Deprecated alan
yalnızca fallback olarak kullanılır. Runtime `ThemeColors` içinde deprecated
alan bulundurulmaz.

**Davranış kuralları (özet):**

| Tip | Opsiyonellik | Yanlış değer davranışı |
|-----|--------------|------------------------|
| `AppearanceContent` | `ThemeContent.appearance` **zorunlu** | Deserialize hatası (tema hiç yüklenmez) |
| `WindowBackgroundContent` | `ThemeStyleContent` üstünde `#[with_fallible_options]` bulunur | User settings `RootUserSettings::parse_json` hattında `None` + `ParseStatus::Failed`; tema dosyası normal serde hattında deserialize hatası |
| `FontStyleContent` | `Option` + `treat_error_as_none` | `None` |
| `FontWeightContent` | `Option` + `treat_error_as_none`; `f32` newtype | `None` |
| `HighlightStyleContent.color` | `Option<String>`; özel deserializer yok | Geçersiz hex string → refinement'ta `None`; yanlış JSON tipi → deserialize hatası |
| `HighlightStyleContent` (diğer) | `Option<...>` + `treat_error_as_none` | `None` |
| `PlayerColorContent` (3 alan) | hepsi `Option<String>` | Eksik alan baseline.local'dan |
| `ThemeColorsContent` (150 alan) | her biri `Option<String>` | Refinement → baseline |
| `StatusColorsContent` (42 alan) | her biri `Option<String>` | Refinement → baseline (fg→bg türetme uygulanır) |

> **`AppearanceContent` neden `Option` değil?** Bir tema'nın "Light mı, Dark
> mı?" sorusu **kritiktir**. Bu bilgi eksik olduğunda renk seçimi anlamını
> yitirir. Bu yüzden alan, sözleşmenin zorunlu enum alanı olarak tutulur.

### `#[serde(flatten)]` — alt struct'ları aynı seviyeye açar

JSON dosyasında `style` objesi içinde **150'den fazla alan düz olarak**
sıralanır; iç içe `"colors": { ... }` yapısı yoktur. Rust tarafında bu
alanlar mantıksal olarak ayrı struct'larda (`ThemeColorsContent`,
`StatusColorsContent`) tutulur. JSON parse edilirken ise **aynı seviyeden**
deserialize edilirler. `#[serde(flatten)]` bu eşlemeyi sağlar.

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

İki ayrı struct'ın alanları **aynı JSON object'i** içinden deserialize edilir.
Çakışan anahtar bulunmamalıdır. Örneğin `ThemeColorsContent` içinde `"error"`
alanı yoktur; bu yüzden `StatusColorsContent.error` ile çatışmaz.

### `#[serde(rename = "...")]` — alan adı eşleme

Rust alan adı snake_case, JSON anahtarı ise dot.separated biçimindedir:

```rust
#[serde(rename = "border.variant")]
pub border_variant: Option<String>,
```

Detaylar Konu 23'te ele alınır.

### `#[serde(rename_all = "snake_case")]` — enum variant adları

`AppearanceContent`, `WindowBackgroundContent`, `FontStyleContent` gibi
**enum'lar** için variant adlarını JSON'a `snake_case` olarak aktarmak
amacıyla kullanılır:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AppearanceContent {
    Light,
    Dark,
}
```

Bu sayede JSON'da `"appearance": "light"` yazılır. Rust variant adı `Light`
olsa bile JSON tarafında küçük harf kullanılır. `rename_all = "snake_case"`
attribute'u, her variant için tek tek `rename` yazma yükünü kaldırır.

### `#[serde(transparent)]` — newtype'ı saydamlaştır

```rust
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct FontWeightContent(pub f32);
```

Bu attribute sayesinde JSON'da `{ "font_weight": { "0": 700 } }` yerine
doğrudan `{ "font_weight": 700 }` yazılır. Newtype'ın sarmaladığı tek alan
saydam görünür; JSON tüketicisi `FontWeightContent`'in newtype olduğunu fark
etmez.

### `#[serde(default)]` — eksik alana default değer

```rust
#[serde(flatten, default)]
pub colors: ThemeColorsContent,
```

JSON'da `colors` alanı yoksa `ThemeColorsContent::default()` çağrılır ve tüm
alanlar `None` olarak gelir. `default` annotation'ı alan bazında da
verilebilir:

```rust
#[serde(default)]
pub players: Vec<PlayerColorContent>,    // Yoksa boş Vec
```

### Hiyerarşik özet

| Attribute | Etkisi | Tema'da örnek |
|-----------|--------|---------------|
| `#[serde(flatten)]` | Alt struct'ı aynı seviyede açar | `ThemeColorsContent`/`StatusColorsContent` flatten ile düz |
| `#[serde(rename = "x.y")]` | Alan adını bağlar | `border_variant` ↔ `"border.variant"` |
| `#[serde(rename_all = "snake_case")]` | Tüm variant'lara uygulanır | `AppearanceContent::Light` ↔ `"light"` |
| `#[serde(transparent)]` | Newtype'ı saydamlaştırır | `FontWeightContent(700.0)` ↔ `700` |
| `#[serde(default)]` | Eksik alana default verir | `players: []` veya yok ise boş Vec |
| `#[serde(deserialize_with = "fn")]` | Custom deserializer kurar | `treat_error_as_none` (Konu 22) |

### Tuzaklar

1. **`flatten` çakışması**: İki flatten'li struct'ın aynı isimli bir alanı
   bulunursa, hangisinin önce parse edileceği tanımsız hale gelir. Tema
   sözleşmesinde bu çakışma görülmez; `ThemeColorsContent` ve
   `StatusColorsContent` alan kümeleri kesişmez.
2. **`flatten` performansı**: Serde flatten, serde_derive'ın daha ağır kod
   üretmesine yol açar. Tema deserialize'ı hot path'te olmadığı için bu
   genelde sorun değildir; ancak settings veya config gibi sık çağrılan
   struct'larda dikkat gerektirir.
3. **`rename` ile alan-bazlı `default` çakışması**: Doğru yazım
   `#[serde(rename = "x.y", default)]` biçimindedir; iki annotation aynı
   `serde` parantezi içinde virgülle ayrılır.
4. **`Serialize` türetmenin gerekliliği**: Yalnızca deserialize yapan bir
   tema için `Serialize` türetilmesi şart değildir; ancak
   `schemars::JsonSchema` veya round-trip test ihtiyacı varsa türetilmesi
   yerinde olur.
5. **`JsonSchema` türetimi**: `schemars`, IDE auto-complete için tema
   dosyalarına JSON schema export edebilir. Türetim ücretsiz değildir
   (compile-time maliyeti vardır); kullanılmadığı durumda bırakılmaması
   tercih edilir.

---

## 20. `*Content` tiplerinin opsiyonellik felsefesi

Content tipleri **tek bir ana kuralı** izler: her renk alanı
`Option<String>`, her enum alanı ise `Option<EnumContent>` olarak tutulur.
Renk alanları doğrudan `Hsla` veya zorunlu `String` yapılmaz.

### Üç gerekçe

**1. Kullanıcı her alanı yazmak zorunda değildir.**

Zed temalarında tipik bir tema dosyası 150 alandan yalnızca 30-50 kadarını
yazar; gerisi baseline'dan dolar. Eksik alanların parse hatası vermek yerine
`None` olarak gelmesi gerekir. Refinement katmanı (Bölüm VII), hangi alanın
override edildiğini ve hangisinin baseline'dan kalacağını bu `Some`/`None`
ayrımına bakarak belirler.

**2. Renk parse hatası tüm temayı bozmamalıdır.**

```json
{
  "background": "#1c2025ff",     // ← geçerli
  "border": "rebeccapurple",     // ← geçersiz (named color, hex değil)
  "text": "#c8ccd4ff"            // ← geçerli
}
```

`border: String` yani zorunlu alan olarak tanımlansaydı, tek bir hatalı alan
yüzünden tüm tema yüklenemezdi. `border: Option<String>` olduğunda değer
string olarak gelir. Ardından `try_parse_color` bir `Result` döndürür; hata
olursa refinement `None`'a düşer ve baseline değeri kullanılır.

**3. Tip sözleşmesi sürümden bağımsız kalır.**

Zed ileride bir alana yeni bir varyant ekleyebilir; örneğin
`FontStyle::SemiOblique`. Eski şema `font_style: "semi_oblique"` değerini
tanımaz. **Ancak `font_style: Option<FontStyleContent>`** olduğunda,
`treat_error_as_none` deserializer'ı (Konu 22) bilinmeyen varyantı `None`'a
düşürür ve tema yüklemesi devam eder.

### İki katmanlı opsiyonellik

```
JSON          Content              Refinement       Theme
─────────────────────────────────────────────────────────
"#1c2025ff"   Some("#1c2025ff")   Some(Hsla(..))   Hsla(..)
"bozuk"       Some("bozuk")       None             baseline'dan
yok           None                 None             baseline'dan
```

**Görsel olarak okunabilir özet:**

- `Option<String>` katmanı: "kullanıcı bu alanı yazdı mı?"
- `Option<Hsla>` katmanı: "yazdıysa parse edilebildi mi?"

İki ayrı katman, iki farklı durumu ayırmamızı sağlar:

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

`Default` türetilir; tüm alanlar `Option<_>` olduğundan default değerin
karşılığı "tüm alanlar `None`" olur. `#[serde(default)]` struct
seviyesinde tüm alanlara uygulanır.

Bu sayede JSON'da bütün bir struct (`colors`, `status` vb.) eksik olabilir.
Serde flatten katmanı `Default::default()` çağırır ve parse işlemine devam
eder.

### `Option<String>` neden `Option<Hsla>` değil?

İlk akla gelen soru şu olabilir: "Madem string ileride `Hsla`'ya çevriliyor,
neden baştan `Option<Hsla>` kullanmıyoruz?"

**Cevap:** Serde'nin JSON'dan `Hsla`'ya doğrudan deserialize edebileceği hazır
bir yol yoktur. GPUI `Hsla` için manuel bir `Deserialize` impl yazmak gerekir.
Bu da hex string parse mantığını struct attribute'larının içine taşır. Sonuçta
test etmesi zor bir parse adımı ve okunması güç hata mesajları ortaya çıkar.

Mevcut yaklaşımda akış şu şekilde işler:

1. Serde yalnızca "string olarak al" der.
2. `try_parse_color` ayrı bir fonksiyondur — birim test edilebilir.
3. Hatalı renk, string olarak content'te kalır; Refinement aşamasında
   sessizce `None`'a düşer.

Bu **sorumluluk ayrımı** sağlamdır: serde "yapı doğru mu?" sorusunu cevaplar,
parser ise "değer geçerli mi?" sorusunu cevaplar.

### Tuzaklar

1. **`String` (Option olmadan) kullanmak**: Zorunlu alan = bir eksik
   alanın tüm temayı patlatması demektir. Sözleşmeye uymaz.
2. **`Option<Hsla>` kullanmak (parse'ı Deserialize'a sokmak)**: Custom
   Deserialize implementasyonu test edilemez, hata mesajları zayıf kalır
   ve parser katmanı sözleşmeye gömülmüş olur. Mevcut iki-katman
   yaklaşımı bu senaryoya tercih edilir.
3. **`Default::default()` türevini atlamak**: `#[derive(Default)]`
   bulunmayan bir Content tipi `#[serde(default)]` kullanamaz; struct
   seviyesinde default şarttır.
4. **`Default` ile dolu Hsla beklemek**: Content tipinin `Default`
   çağrısı tüm alanları `None` döndürür. Default'tan doğrudan Theme inşa
   edilmez; refinement aşaması baseline ile birleştirir. "Boş tema
   dosyasını yüklemek = baseline" denkliği bilinçli bir tasarım
   sonucudur.
5. **Bilinmeyen enum'a panic**: `font_style: "semi_oblique"` ifadesinde
   `FontStyleContent` `SemiOblique`'i tanımıyorsa, default deserialize
   panic atar. Çözüm: `HighlightStyleContent` içinde
   `treat_error_as_none`; diğer option-heavy content tiplerinde ise
   `#[with_fallible_options]` macro'su (Konu 22).

### `MergeFrom` derive davranış matrisi

`settings_content` tarafındaki kullanıcı settings content tipleri
`#[derive(..., MergeFrom)]` ile işaretlenir. Zed settings hiyerarşisi
(`default.json → user.json → project.json`) **`MergeFrom` üzerinden çalışır**.
`default` baz değerleri sağlar; kullanıcı ve proje settings'i bunun üstüne
merge edilir. Tema dosyası payload'ı olan `theme_settings::ThemeFamilyContent`
ve `ThemeContent` ise bu merge hattının parçası değildir. Onlar doğrudan
deserialize edilir ve runtime tema'ya refine edilir. `MergeFrom` trait'i
`settings_content/src/merge_from.rs` içinde tanımlıdır ve alan tipine göre
davranışı değişir:

| Alan tipi | `merge_from(self, other)` davranışı | Etki |
|-----------|-------------------------------------|------|
| Primitive (`u16`, `u32`, `i*`, `bool`, `f32`, `f64`, `char`, `usize`, `NonZeroUsize`, `NonZeroU32`) | `*self = other.clone()` | **Overwrite** — kullanıcı değeri default'u tamamen ezer |
| `String`, `Arc<str>`, `PathBuf`, `Arc<Path>` | overwrite | Aynı: tek bir scalar değer üstüne yazılır |
| `Option<T>` | `None` ise yok sayar; mevcut `Some` + yeni `Some` → recursive merge (`this.merge_from(other)`); mevcut `None` + yeni `Some` → `replace(other.clone())` | Recursive merge için en uygun tip |
| `Vec<T>` | `*self = other.clone()` | **Overwrite** (concat değil) — `accents: ["#aaa"]` user değeri default `accents`'i siler |
| `Box<T: MergeFrom>` | `self.as_mut().merge_from(other.as_ref())` | Pointer içeriği recursive merge |
| `HashMap<K, V: MergeFrom>` / `BTreeMap` / `IndexMap` | Her key için: mevcutsa recursive merge, yoksa insert | Map'lerin key-bazlı birleşmesi (örn. `theme_overrides`) |
| `HashSet<T>` / `BTreeSet<T>` | union (her item insert edilir) | Set birleşimi |
| `serde_json::Value` | Object → recursive merge; aksi halde overwrite | Free-form JSON için akıllı merge |

**Tema sözleşmesi için kritik sonuçlar:**

1. **`accents: Vec<AccentContent>` overwrite davranır.** Kullanıcı
   `experimental.theme_overrides.accents = ["#abc"]` yazdığında, temanın
   baseline accent listesi silinir. Bunun istenmeyen bir yan etkisi
   vardır: tek bir rengi değiştirmek için kullanıcı tüm listeyi yeniden
   yazmak zorunda kalır. `merge_accent_colors` (Konu 32 Adım 5) bu
   davranışı `theme_overrides` zinciri içinde **partial fallback** ile
   yumuşatır; yine de JSON merge seviyesinde liste hâlâ atomic olarak
   davranır.

2. **`theme_overrides: HashMap<String, ThemeStyleContent>` key-bazlı
   merge.** Kullanıcı yalnızca `"One Dark": { ... }` yazsa bile
   `default.json` içinde bulunan diğer tema override'ları korunur. Aynı
   tema adı için iki katmanda override varsa, içleri recursive merge ile
   birleştirilir.

3. **`Option<ThemeSelection>` recursive merge.** `default.json` içinde
   `theme = Static("One Dark")`, kullanıcı tarafında ise
   `theme = Dynamic { mode: System, light: ..., dark: ... }`
   tanımlıysa: `Some + Some` → recursive `merge_from` çalışır.
   `ThemeSelection` kendisi `MergeFrom` derive'ına sahip olduğundan
   variant değişebilir; ancak bu derive enum davranışı **iç değerleri
   birleştirmek değil, override etmektir** (variant'lar farklı olduğunda
   içler birbirine karışmaz).

4. **Color string'leri `Option<String>` olduğundan her renk alanı için**:
   - default'ta verilmemiş, user'da var → user değeri yazılır
   - default'ta var, user'da yok → default korunur
   - default'ta var, user'da var → user değeri yazılır (`String`
     overwrite)

Bu davranış matrisi `treat_error_as_none` ve `with_fallible_options`
mekanizmalarından bağımsızdır. Onlar **parse seviyesinde**, `MergeFrom` ise
**post-parse merge seviyesinde** çalışır.

> **Mirror disiplini:** `kvs_tema` veya `kvs_ayarlari_icerik` crate'i bir
> `MergeFrom` derive macro'su mirror etmelidir; alternatif olarak
> `settings_macros` doğrudan dependency yapılır. Tema sözleşmesi `MergeFrom`
> üzerine kurulduğu için her `*Content` tipi için elle `merge_from` yazmak
> dağınık ve hata üretmeye açık bir yola dönüşür.

---

## 21. `try_parse_color`: hex → `Hsla` boru hattı

**Kaynak:** `kvs_tema/src/schema.rs` veya `kvs_tema/src/refinement.rs`
(yerleşimi kararsızdır).

JSON'dan gelen hex string'i runtime `Hsla` değerine çeviren tek fonksiyon:

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

### Boru hattının dört adımı

```
"#1c2025ff"  →  gpui::Rgba  →  palette::Srgba  →  palette::Hsla  →  gpui::Hsla
  hex string    (1) parse      (2) reinterpret    (3) color-space   (4) normalize
```

**Adım 1 — Hex string'in parse edilmesi:**

```rust
let rgba = gpui::Rgba::try_from(s)?;
```

`gpui::Rgba::try_from` (`gpui/src/color.rs:162`) **dört** hex formatını kabul
eder:

| Format | Hex hanesi | Alpha kaynağı | Çiftleme |
|--------|-----------|---------------|----------|
| `#rgb` | 3 | `0xf` (`1.0`) | `0xa → 0xaa` (her hane çiftlenir) |
| `#rgba` | 4 | 4. hane | `0xa → 0xaa` (4 hane de çiftlenir) |
| `#rrggbb` | 6 | `0xff` (`1.0`) | yok |
| `#rrggbbaa` | 8 | son 2 hane | yok |

Önemli kurallar:

- **`#` zorunludur**: Kaynak kod `value.trim().split_once('#')` ile parse
  başlatır; `#` olmadan girilen hex (`RRGGBB`) `Err` döndürür.
- **Trim yapılır**: Önceki ve sonraki whitespace temizlenir
  (`"  #1c2025  "` geçerli sayılır).
- **Büyük/küçük harf duyarsızdır**: `u8::from_str_radix(..., 16)` zaten
  duyarsız çalışır; `#1c2025FF` ve `#1C2025ff` aynı sonucu verir.
- **Kısa form çiftleme**: `#abc` → `#aabbcc`, `#abcd` → `#aabbccdd`. Tek
  bir hane (`r` baytı) 4 bit sola kaydırılır ve kendisiyle OR'lanır
  (`(value << 4) | value`).
- **Alpha varsayılanı**: `#rgb` formatında alpha hanesi `0xf` (yani
  `0xff` = `1.0`); `#rrggbb` formatında ise byte `0xff` olarak gelir.

Hata durumları:

- Geçersiz hex karakter (`#zzz`): `u8::from_str_radix` `Err` döndürür.
- Tanınmayan uzunluk (`#abcde` 5 hex veya `#abcdefg` 7 hex): `match` dört
  varyantın hiçbirine düşmez ve fall-through hatası üretir.
- `#` yok: "invalid RGBA hex color" hatası verilir.
- Boş string: `#` bulunamaz ve `Err` döner.

Bu nedenle tema JSON'ında `"#abc"` yazılması geçerlidir; kısa form da Zed
paritesindeki desteklenen hex biçimlerinin bir parçasıdır.

**Adım 2 — `Rgba` → `palette::Srgba`:**

```rust
let srgba = palette::rgb::Srgba::from_components(
    (rgba.r, rgba.g, rgba.b, rgba.a)
);
```

GPUI'nin `Rgba` tipi ile palette crate'inin `Srgba` tipi aynı değerleri taşır,
ama farklı crate'lerde tanımlıdır. `from_components` tuple alıp struct'a
yerleştirir; veri kopyası çok küçük bir maliyettir (yalnızca 4 × f32).

**Adım 3 — sRGB → HSL color space dönüşümü:**

```rust
let hsla = palette::Hsla::from_color(srgba);
```

`palette::Hsla` ile `palette::Srgba` farklı renk uzaylarında bulunur. Burada
sRGB küpünden HSL silindirine matematiksel bir dönüşüm yapılır. `palette`
crate'inin asıl işi bu adımdadır.

**Adım 4 — `palette::Hsla` → `gpui::Hsla`:**

```rust
gpui::hsla(
    hsla.hue.into_positive_degrees() / 360.0,
    hsla.saturation,
    hsla.lightness,
    hsla.alpha,
)
```

İki crate'in `Hsla` yapısı birbirine **uyumsuzdur**:

| Alan | palette | gpui |
|------|---------|------|
| `hue` | Derece (0–360°), `palette::RgbHue` newtype | Normalize (0.0–1.0), düz `f32` |
| `saturation` | 0.0–1.0 | 0.0–1.0 |
| `lightness` | 0.0–1.0 | 0.0–1.0 |
| `alpha` | 0.0–1.0 | 0.0–1.0 |

`hue.into_positive_degrees()` negatif değerleri 0–360 aralığına normalize
eder (`-30°` → `330°`); ardından `/ 360.0` ile değer GPUI'nin normalize
uzayına çekilir.

### Dönüş tipi: `Result<Hsla>`, çağıran tarafta `Option<Hsla>`

Fonksiyon `anyhow::Result<Hsla>` döndürür. Çağıran taraf hatayı `Option`
katmanına indirir:

```rust
fn color(s: &Option<String>) -> Option<gpui::Hsla> {
    s.as_deref().and_then(|s| try_parse_color(s).ok())
}
```

Bu desen Bölüm VII/Konu 30'da ayrıntılı olarak ele alınır:
`Some(geçersiz hex) → None`.

### Test ve idempotans

`try_parse_color` saf (deterministic) ve doğal olarak test edilebilir
bir fonksiyondur:

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

### `palette` versiyonunun önemi

`palette` major sürüm farkı color-space dönüşümünü değiştirebilir. Aynı hex
değeri farklı bir `Hsla` üretebilir. Bu nedenle:

- `palette` sürümünün Zed'in kullandığı sürümle uyumlu tutulması gerekir
  (Bölüm II/Konu 5).
- Fixture testleri `assert_eq!(...)` yerine `assert!((a - b).abs() <
  epsilon)` ile yazılır — küçük floating-point sapmaları beklenen bir
  durumdur.

### Performans

Her renk alanı için tek bir `try_parse_color` çağrısı yapılır. Yaklaşık 150
renkli bir tema için yaklaşık 150 fonksiyon çağrısı gerçekleşir. Tek bir tema
yüklemesi mikrosaniye seviyesinde kalır. Bu fonksiyon hot path'te yer almaz.

### Tuzaklar

1. **3-hex shorthand desteksizliği**: `#abc` (CSS shorthand) Zed
   paritesinde desteklenmesine rağmen, beklenmedik bir hex formatıyla
   karşılaşıldığında parse hatası alınabilir; kullanıcı temalarında bu
   durumun düşünülmesi gerekir.
2. **`palette` ihmali**: Manuel sRGB → HSL dönüşümü yazmak (palette
   olmadan) Zed davranışından sapar; bu yüzden `palette` kullanılır.
3. **Negatif hue koruması**: `palette::Hsla::from_color` zaman zaman
   `hue = -30°` döndürür; `into_positive_degrees()` çağrısı zorunludur,
   atlanması durumunda `h = -30/360 = -0.083` olur ve GPUI bunu 0.917'ye
   sarmaz, doğrudan **clamp eder**.
4. **`alpha = 0.0` hata gibi görünür**: Geçerli bir tema rengi (örneğin
   `transparent_black`) alpha 0 olabilir. `try_parse_color` `Ok` döner
   ve `Hsla.a = 0.0` verir. UI'da görünmez ama bu bir parse hatası
   değildir; davranışın bilinmesi gerekir.
5. **Refinement aşamasında hatanın yutulması**: `try_parse_color(s).ok()`
   hata mesajını sessizce siler. Debug için bir log eklenmesi yerinde
   olur: `try_parse_color(s).inspect_err(|e| tracing::warn!("bad color:
   {}", e)).ok()`. Default'ta log kapalı tutulduğunda kullanıcı tarafında
   gürültü olmaz, ama debug ihtiyacında bilgi hazır bulunur.

---

## 22. Hata tolerans: `treat_error_as_none`, `deny_unknown_fields` tuzağı

Tema sözleşmesinin **forward compatibility** prensibi şudur: Zed gelecekte
yeni bir alan veya enum varyantı eklediğinde eski kod **patlamak yerine bunu
göz ardı edebilmelidir**. Bu prensibin iki yönü vardır: bilinmeyen
**alanlar** ve bilinmeyen **değerler**.

### Vektör 1: Bilinmeyen alanlar — `deny_unknown_fields` YASAK

Serde varsayılan olarak bilinmeyen alanları **görmezden gelir**. Yeni bir alan
JSON'da göründüğünde mevcut Content struct'ı onu sessizce atlar. Tema
sözleşmesi için istenen davranış budur.

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

**Senaryo:** Zed `inlay_hint_background` adında bir alan ekledi. Henüz
mirror tarafa eklenmemiş olsun. JSON dosyasında bu anahtar bulunuyor:

- `deny_unknown_fields` AÇIK: Tüm tema yüklemesi `Err("unknown field
  inlay_hint_background")` ile başarısız olur. Kullanıcı temasını
  açamaz.
- `deny_unknown_fields` KAPALI (default): Alan sessizce atlanır. Tema
  yüklenir, yalnızca o alanın özelliği etkisiz kalır.

**Bu kural nettir:** Tema sözleşmesinin **hiçbir** Content tipinde
`deny_unknown_fields` kullanılmaz.

### Vektör 2: Bilinmeyen enum değerleri — iki tolerans hattı

Enum alanlarda varsayılan davranış farklıdır: serde bilinmeyen bir variant
gördüğünde `Err` döndürür.

**Senaryo:** Zed `FontStyle::SemiOblique` ekledi. JSON:
`"font_style": "semi_oblique"`. Mirror tarafındaki `FontStyleContent`'te
bu variant henüz yok.

- Standart deserialize: `Err("unknown variant semi_oblique, expected one
  of normal, italic, oblique")`. Tüm tema patlar.
- `HighlightStyleContent` içinde: `treat_error_as_none` alanı `None`'a
  düşürür.
- `#[with_fallible_options]` kullanılan diğer content tiplerinde: alan
  `None`'a düşer ve hata thread-local hata listesinde biriktirilerek
  dosyanın `ParseStatus`'una yansıtılır.

**Zed paritesi iki ayrı mekanizmadan oluşur:**

1. **Attribute macro** (`#[with_fallible_options]`):
   `ThemeSettingsContent`, `ThemeStyleContent`, `ThemeColorsContent`,
   `StatusColorsContent` gibi option-heavy struct/enum'lar üzerine
   yerleştirilir. Macro her `Option<T>` alanı için otomatik olarak şu
   attribute'u ekler:
   ```rust
   #[serde(
       default,
       skip_serializing_if = "Option::is_none",
       deserialize_with = "crate::fallible_options::deserialize",
   )]
   ```
   Bu sayede her alana elle `#[serde(deserialize_with = "...")]` yazma
   ihtiyacı ortadan kalkar.

2. **`fallible_options::deserialize` fonksiyonu**: Tek tek alanı çağırır;
   bir hata varsa thread-local `ERRORS` listesine ekler ve
   `Default::default()` (yani `None`) döndürür. `ERRORS` `None` ise
   (`parse_json` çağrılmadıysa) hatayı yutmaz; doğrudan yukarı
   kabarcıklayarak iletir.

3. **`fallible_options::parse_json::<T>(json)`**: Top-level çağrı
   noktasıdır. `ERRORS` thread-local'ını sıfırlar, parse'ı çalıştırır,
   parse bittikten sonra biriken hataları toplar ve `(Option<T>,
   ParseStatus)` döndürür. `ParseStatus` **üç variantlıdır**
   (`settings_content::ParseStatus`,
   `settings_content/src/settings_content.rs:76`): `Success`, `Unchanged`
   (kaynak dosya değişmediği için parse atlanır) ve
   `Failed { error: String }`. `Unchanged` yalnızca settings dosya
   yönetim katmanından gelir (file watcher değişiklik olmadığına karar
   verdiğinde); `parse_json` doğrudan çağrıldığında yalnızca `Success`
   veya `Failed` döner.

Public tüketici yolu genelde doğrudan `fallible_options::parse_json` değildir.
`settings_content::RootUserSettings` trait'i, `SettingsContent`,
`Option<SettingsContent>` ve `UserSettingsContent` için
`parse_json(json) -> (Option<Self>, ParseStatus)` ile
`parse_json_with_comments(json) -> anyhow::Result<Self>` metotlarını sağlar.
İç helper olan `fallible_options::deserialize` ise `pub(crate)` kalır; yalnızca
`#[with_fallible_options]` macro'sunun eklediği serde attribute'u tarafından
crate içinden çağrılır.

Bu tolerans **yalnızca `fallible_options::parse_json` veya
`RootUserSettings` hattında** tam davranışını gösterir. Tema dosyaları farklı
bir yoldan gelir: `load_bundled_themes`, bundled `assets/themes/*.json` için
`serde_json::from_slice` kullanır; `deserialize_user_theme`, kullanıcı tema
dosyası için `serde_json_lenient::from_slice` kullanır. Bu normal serde
yollarında `ERRORS` thread-local'ı kurulmadığı için
`fallible_options::deserialize` hatayı yutmaz; doğrudan deserialize hatası
döndürür. `HighlightStyleContent` içindeki yerel `treat_error_as_none` ise bu
thread-local'a bağlı değildir ve tema dosyası parse'ında da seçili alanları
`None`'a düşürür.

4. **`HighlightStyleContent` istisnası**: Bu struct
   `#[with_fallible_options]` kullanmaz. Kaynakta yalnızca
   `background_color`, `font_style` ve `font_weight` alanlarında yerel
   `treat_error_as_none` bulunur; `color` alanında bulunmaz. Sonuç olarak
   `"font_style": "semi_oblique"` veya `"background_color": 3` sessizce
   `None`'a düşer, ama `"color": 3` doğrudan bir deserialize hatası
   üretir. Geçersiz bir renk string'i (`"color": "not-a-color"`) ise
   content aşamasında `Some` olarak kalır ve refinement'ta
   `try_parse_color(...).ok()` ile `None`'a düşer.

**Mekanizma (kullanıcı tarafından görünmeyen):**

1. `parse_json::<ThemeColorsContent>(json)` çağrılır.
2. Her `Option<T>` alanı için macro tarafından eklenen
   `fallible_options::deserialize` çağrılır.
3. Bir alan parse hatası verdiğinde → hata thread-local'a yazılır, alan
   `None` olarak set edilir, parse devam eder.
4. Tüm parse tamamlandığında `ParseStatus` döner; UI gerekirse uyarı
   gösterir, eksik alan baseline'dan doldurulur.

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
> - Macro yalnızca `Option<T>` alanlarını işaretler. `Vec<T>`, `String` ve
>   primitive alanlar etkilenmez; onların hatası hâlâ üst seviyeyi patlatır.
> - `HighlightStyleContent` için elle yazılmış eski `treat_error_as_none`
>   deseni kaynakta hâlâ geçerlidir; bunun `#[with_fallible_options]`
>   ile değiştirilmesi kararı Zed tarafında verilmeden mirror tarafında
>   yerinde tutulur.
> - `serde_json_lenient` deserializer'ı (`parse_json` içinde kullanılır)
>   trailing comma ve comment kabul eder; bu da kullanıcı dostu editör
>   deneyimi için ek bir tolerans katmanı sağlar.

### Hata tolerans matrisi

| Senaryo | Default davranış | İstenen | Çözüm |
|---------|------------------|---------|-------|
| Bilinmeyen alan | Görmezden gelir | Görmezden gelinsin | Hiçbir şey eklenmez (`deny_unknown_fields` kullanılmaz) |
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

1. **`deny_unknown_fields` cazibesi**: "Daha sıkı validation iyidir" sezgisi
   burada yanıltıcıdır. Sözleşme **yaşayan** bir yapıdadır; sıkı validation
   breaking change'lerde kullanıcıyı gereksiz yere durdurur.
2. **`treat_error_as_none` her yere koymak**: Zed bunu yalnızca
   `HighlightStyleContent`'te seçili alanlara koyar. Genel settings
   content'inde macro kullanılır; syntax highlight struct'ında ise
   mevcut özel davranışın değiştirilmesi tercih edilmez.
3. **Hata yutmayı sessizce yapmak**: Production'da `tracing::warn!` ile
   log alınması yerinde olur — amaç kullanıcının tema dosyasındaki bir
   typo'yu fark etmesi değil, debug akışı için bilgi bırakmaktır. Log
   seviyesi default olarak kapalı tutulabilir.
4. **`#[serde(default)]` unutmak**: `deserialize_with` yazıldığında
   default davranış değişir; `default` annotation'ı bu durumda şart hale
   gelir, aksi takdirde alan eksik olduğunda hata alınır.
5. **`serde_json::Value` performansı**: `treat_error_as_none` her alanı
   bir kez `Value`'ya, sonra tipe çevirir — yani iki kez parse yapılır.
   Tema yüklemesi hot path olmadığı için bu maliyet pratikte sorun
   yaratmaz.

---

## 23. JSON anahtar konvansiyonu (dot vs snake_case)

Tema JSON dosyalarında alan adları **dot.separated** yazılır; Rust alan adları
ise **snake_case** olarak tutulur. İki konvansiyon `#[serde(rename = "...")]`
ile birbirine bağlanır.

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

**Her alan için ayrı `rename`** kullanılır. `rename_all`, snake_case ↔ dot
dönüşümünü yapamaz. Serde'in `rename_all` desteği kebab-case, camelCase,
PascalCase ve SCREAMING_SNAKE_CASE gibi biçimleri kapsar; dot ayrımını
desteklemez. Bu yüzden her alan elle işaretlenir.

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

Dot konvansiyonu sayesinde **mantıksal gruplar** yan yana kalır. `border`
ailesi, `element` ailesi ve `terminal.ansi` ailesi aynı blokta toplanır.
Snake_case JSON kullanılsaydı bu sıralama bozulurdu; `border_variant`,
`border_focused`, `border_disabled` gibi isimler alfabetik olarak farklı
yerlere dağılırdı.

### Çift altçizgi konvansiyonu (boundary case)

Bazı alanlar **iki seviyeli** dot konvansiyonu taşır:

| JSON | Rust |
|------|------|
| `terminal.ansi.red` | `terminal_ansi_red` |
| `terminal.ansi.bright_red` | `terminal_ansi_bright_red` |
| `version_control.added` | `version_control_added` |

Yani dot **alt seviye ayrımını**, underscore ise **kelime ayrımını** temsil
eder. JSON anahtarında bulunan underscore Rust adında korunur:

```json
"terminal.ansi.bright_red": "#ff5555"
```

```rust
#[serde(rename = "terminal.ansi.bright_red")]
pub terminal_ansi_bright_red: Option<String>,
```

### Status renklerinde özel durum

`StatusColors` içinde `_background` ve `_border` Rust suffix'leri JSON
tarafında **ayrı bir dot seviyesi** olarak görünür:

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
   alanına `rename` eklenmediği durumda, serde JSON tarafında
   `"border_variant"` bekler. Zed JSON'unda ise `"border.variant"`
   yazıldığı için alan **sessizce boş kalır** (`None`). En yaygın
   karşılaşılan hatadır.
2. **`rename` typo'su**: `#[serde(rename = "boder.variant")]` gibi
   typo'lu bir kullanım compile hatası vermez; parse anında alan boş
   kalır. Gerçek tema örnekleri ile çalışmak, bu tür eşleşme hatalarını
   görünür kılar.
3. **`rename_all` snake_case'e güvenmek**: `#[serde(rename_all =
   "snake_case")]` Rust ↔ snake_case JSON dönüşümü için tasarlanmıştır;
   dot konvansiyonu için **işe yaramaz**. Her alanın elle işaretlenmesi
   gerekir.
4. **Dot içinde alanı tek kelime sanmak**: `border.variant` Rust
   tarafında iki alan değil tek bir alandır (`border_variant`). Dot
   kelime ayırıcısı değil, hiyerarşi ayırıcısı olarak işlev görür.
5. **`status.error` yerine `error.status` beklemek**: Status renklerinde
   JSON prefix'i `error.background` biçimindedir; **`status.error_background`
   değil**. `StatusColors` flatten ile düz seviyeye açıldığı için
   "status" diye bir prefix bulunmaz. Aynı durum `colors.background`
   yerine doğrudan `background` için de geçerlidir.
6. **JSON'da hem `border_variant` hem `border.variant` yazmak**:
   Kullanıcı temasında bu iki anahtar bir arada görünürse hangisinin
   kazanacağı tanımsız bir hale gelir. Geliştirici dokümantasyonunda
   yalnızca dot konvansiyonunun önerilmesi, bu belirsizliği ortadan
   kaldırır.

### `serde_json_lenient` ile JSON yazım kolaylığı

Zed tema dosyaları pratikte **standart JSON'dan biraz daha esnektir**: yorum
satırları ve trailing comma içerebilir. Bu yapıların parse edilebilmesi için
`serde_json_lenient` kullanılır (Konu 5 bağımlılık matrisinde yer alır).

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

**Standart `serde_json` bu JSON'u parse edemez.** Yorum satırı
`Err("expected value")`, trailing comma ise `Err("trailing comma")` döndürür.
Zed built-in temalarında yorum ve trailing comma kullanabildiği için
`serde_json_lenient` kullanmak **zorunludur**.

**Kullanım:**

```rust
let family: ThemeFamilyContent =
    serde_json_lenient::from_slice(&bytes)?;
// veya str için:
let family: ThemeFamilyContent =
    serde_json_lenient::from_str(json)?;
```

API yüzeyi `serde_json` ile uyumludur; aradaki tek fark import yolundadır.

**Sınırlamalar:**

- Unquoted key (`{ name: "x" }`) **kabul edilmez** — bu yapı JavaScript
  object literal'idir, JSON değildir.
- Single quote string (`'value'`) kabul edilmez.
- JSON5'in genişletmelerinin tamamı desteklenmez; yalnızca yorum ve
  trailing comma desteği bulunur.

**Tuzak — yazma yönü:** Tema dosyası mirror tarafında yazıldığında (test
fixture veya fallback dump için), `serde_json::to_string_pretty` çıktısı
standart JSON üretir (yorumsuz). Lenient yalnızca **okumada** etkilidir;
yazılan çıktı sade JSON formatında olur.

---

## 24. `deserialize_icon_theme` — IconTheme JSON helper'ı

**Kaynak:** `crates/theme/src/theme.rs:286`.

Konu 18 içinde icon tema JSON yüklemesi ele alınmıştı. Zed bu işlemi tek
satırlık bir helper ile sarmalar:

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

Tek satırlık bir helper gibi görünür, ama birkaç pratik faydası vardır:

- `serde_json_lenient` import'unu tüketici crate'lerden gizler.
- Hata mesajını `anyhow::Context` ile zenginleştirir; debug çıktısında
  hangi adımın başarısız olduğu net anlaşılır.
- Parser implementasyonu ileride değişirse (örneğin `serde_json` ile
  `comments` feature'ı), helper içeride güncellenir ve tüketici
  tarafında hiçbir değişiklik gerekmez.

---
