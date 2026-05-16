# Runtime veri modeli

GPUI tipleri tanındıktan sonra, uygulamanın bellekte taşıyacağı tema
modelini kurabiliriz. Bu modelin içinde ana `Theme` tipi, renk grupları,
syntax tema kabı ve icon tema sözleşmesi yer alır. Bu bölüm runtime tarafının
ana yapı taşlarını tek tek anlatır ve her parçanın neden bu şekilde
tasarlandığını açıklar.

---

## 12. `Theme` ve `ThemeStyles` üst yapısı

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

Tema'nın **üst düzey** sözleşmesi iki struct'a ayrılır: `Theme` ve
`ThemeStyles`. `Theme`, metadata ile stil kabını bir araya getirir.
`ThemeStyles` ise tüm renk ve stil gruplarını taşır. Bu ayrım, ilerideki
okuma ve klonlama işlemlerinin neden ucuz kaldığını da gösterir.

```rust
pub struct Theme {
    pub id: String,
    pub name: SharedString,
    pub appearance: Appearance,
    pub(crate) styles: ThemeStyles,   // accessor'lar üzerinden okunur
}

pub(crate) struct ThemeStyles {
    pub(crate) window_background_appearance: WindowBackgroundAppearance,
    pub(crate) system: SystemColors,
    pub(crate) colors: ThemeColors,
    pub(crate) status: StatusColors,
    pub(crate) player: PlayerColors,
    pub(crate) accents: AccentColors,
    pub(crate) syntax: Arc<kvs_syntax_tema::SyntaxTheme>,
}

// Tüketicinin tek okuma yolu — accessor metotları (Konu 41, 43)
impl Theme {
    pub fn colors(&self) -> &ThemeColors      { &self.styles.colors }
    pub fn status(&self) -> &StatusColors     { &self.styles.status }
    pub fn players(&self) -> &PlayerColors    { &self.styles.player }
    pub fn accents(&self) -> &AccentColors    { &self.styles.accents }
    pub fn system(&self) -> &SystemColors     { &self.styles.system }
    pub fn syntax(&self) -> &Arc<kvs_syntax_tema::SyntaxTheme> {
        &self.styles.syntax
    }
    pub fn appearance(&self) -> Appearance {
        self.appearance
    }
    pub fn window_background_appearance(&self) -> WindowBackgroundAppearance {
        self.styles.window_background_appearance
    }

    /// Lightness'i azaltarak renk koyulaştırır. İlk değer light tema,
    /// ikincisi dark tema modunda kullanılır; lightness alt sınırı 0.0.
    /// Zed paritesi (`crates/theme/src/theme.rs:288`).
    pub fn darken(&self, color: Hsla, light_amount: f32, dark_amount: f32) -> Hsla {
        let amount = match self.appearance {
            Appearance::Light => light_amount,
            Appearance::Dark => dark_amount,
        };
        let mut hsla = color;
        hsla.l = (hsla.l - amount).max(0.0);
        hsla
    }
}
```

> **Visibility kararı:** `styles` alanı `pub(crate)` olarak tanımlanır.
> Tüketici crate doğrudan `theme.styles.X` zincirini **yazamaz**; her okuma
> accessor üzerinden geçer. Bunun nedeni basittir: `ThemeStyles`'ın iç düzeni
> Zed sözleşmesine göre zamanla değişebilir. Accessor arayüzü ise dış
> sözleşmeyi `theme.colors()` gibi metotlar üzerinde **sabitler**. İç düzen
> değişse bile tüketici kod kırılmaz. Bu kural Konu 43'te public API kataloğu
> üzerinden ayrıca netleştirilir.

### Alan-alan davranış

| Alan | Tip | Niye böyle |
|------|-----|------------|
| `id` | `String` | Unique tema id'sidir; runtime'da `uuid::Uuid::new_v4()` ile üretilir. Map key olarak kullanılmadığı için hash ihtiyacı yoktur. |
| `name` | `SharedString` | İnsan-okunabilir ad (örn. "Kvs Default Dark"). Registry map key'i olarak çok klonlandığından `Arc<str>` ucuzluğu burada kazanç sağlar (bkz. Konu 7). |
| `appearance` | `Appearance` | `Light` veya `Dark`. UI tarafının sistem moduna göre tema seçmesini mümkün kılar. |
| `styles` | `ThemeStyles` | Tüm renk grupları. Ayrı bir struct olarak tutulmasının nedeni: `Theme` klonlanırken `styles`'ın boyutunu (~150 `Hsla` + diğerleri) tek alan altında bir arada tutmaktır. |

### `ThemeStyles` alt katmanları

| Alt katman | Tip | Bölüm referansı |
|-----------|-----|-----------------|
| `window_background_appearance` | `WindowBackgroundAppearance` | Bölüm III/Konu 8 |
| `system` | `SystemColors` | Konu 16 |
| `colors` | `ThemeColors` | Konu 13 |
| `status` | `StatusColors` | Konu 14 |
| `player` | `PlayerColors` | Konu 15 |
| `accents` | `AccentColors` | Konu 16 |
| `syntax` | `Arc<SyntaxTheme>` | Konu 18 |

### `Arc<SyntaxTheme>` neden Arc?

`SyntaxTheme` içinde genelde 50-200 girdilik highlight listesi bulunur. Syntax
bölümü, tema renklerinden **bağımsız** olarak paylaşılabilir. Bu yüzden
`Arc` ile sarmalamak işe yarar: aynı syntax teması birden fazla `Theme`
varyantı arasında kullanılabilir. Örneğin light ve dark sürümler yalnızca UI
renklerinde ayrışıp aynı syntax kurallarını paylaşabilir.

Diğer alt katmanlar (`ThemeColors`, `StatusColors`, vb.) `Arc` ile sarılmaz.
Her biri görece küçüktür; en büyük grup yaklaşık 150 `Hsla` taşır. Ayrıca
baseline ile her varyant için ayrı bir klon almak zaten beklenen akıştır.

### Erişim desenleri

```rust
let theme = cx.theme();                       // &Arc<Theme>
let bg = theme.colors().background;           // accessor üzerinden
let muted = theme.colors().text_muted;
let error = theme.status().error;
let local = theme.players().local().cursor;
```

> **Zed eşdeğeri:** Zed'in `crates/theme/src/theme.rs` dosyasında da
> `theme.colors()` ve `theme.status()` accessor'ları bulunur.
> `kvs_tema`'da bu sözleşme aynen korunur; accessor'lar yukarıdaki struct
> tanımının `impl Theme` bloğunda yer alır.
>
> Tüketici kod **hiçbir zaman** `theme.styles.X` yazmaz — `styles` alanı
> `pub(crate)` olduğundan crate dışından görünmez (Konu 43).

### `Theme` clone stratejisi

`Theme` bir bütün olarak yaklaşık `~150 × Hsla (16 byte) + birkaç enum + Arc
+ String` boyutundadır; yani **2.5-3 KiB** civarında kalır. Her `cx.theme()`
çağrısı `&Arc<Theme>` döndürür. Bu yüzden yaygın kullanımda clone maliyeti
yalnızca `Arc` refcount artışıdır. Doğrudan `Theme::clone()` çağırmak çoğu
zaman gerekmez; `GlobalTheme.theme` zaten `Arc<Theme>` üzerinden taşınır.

### Tuzaklar

1. **`id` ile `name` arasında karışıklık**: `name` `SharedString` tipindedir
   ve registry'de key olarak kullanılır. `id` (uuid) yalnızca tema-içi
   tanımlama amacıyla tutulur; ikisinin birbirinin yerine konulması
   registry akışını bozar.
2. **`styles` alanını `pub` yapmak**: Bu, dış sözleşmeyi doğrudan iç yapıya
   bağlar. Bu rehberin kararı `pub(crate)` yönündedir. Tüketicinin tek okuma
   yolu accessor metotlarıdır (`theme.colors()`, `theme.status()` vb.). İç
   düzen ileride değişse bile accessor arayüzü sabit kalır.
3. **`appearance` runtime'da değişmez**: Bir tema *Light* olarak yüklendi
   diye runtime'da Dark olarak yeniden işlenmez. Tema değişimi için
   `GlobalTheme::update_theme` çağrısı yapılarak yeni bir `Arc<Theme>`
   aktive edilmelidir.
4. **`SystemColors::default()` ile doldurmanın yeterliliği**: Tema yazarı
   sistem renklerini özelleştirmek istemiyorsa `Default::default()`
   yeterlidir. Bazı geliştiriciler bu alanı atlayıp `unsafe zeroed` ile
   karıştırıp yapıyı görünmez hale getirme yoluna gider; bu yaklaşım
   sonradan zor takip edilen hatalara yol açar.

---

## 13. `ThemeColors` alan kataloğu ve reflection API

**Kaynak modül:** `kvs_tema/src/styles/colors.rs`.

UI renk paletinin tamamı tek bir struct altında toplanır. **Alan sayısı
yaklaşık 150 civarındadır**; kesin sayı takip edilen Zed tema sözleşmesine
bağlıdır.

```rust
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct ThemeColors {
    /* ~150 alan, gruplara ayrılmış */
}
```

`#[derive(Refineable)]` attribute'u sayesinde `ThemeColorsRefinement` ikizi
otomatik olarak üretilir (bkz. Konu 11).

### Alan grupları (semantik kategoriler)

Aşağıdaki tablo, alan adlandırma prefix'lerini ve her grubun **ne işe
yaradığını** özetler. Zed'in `crates/theme/src/styles/colors.rs`
dosyasındaki sıralama korunur. Bir alanı eksik bırakmak, sözleşmeyi delmek
anlamına gelir (Konu 2).

| Grup | Prefix / örnek | Rol | Yaklaşık alan sayısı |
|------|----------------|-----|---------------------|
| **Kenarlıklar** | `border`, `border_variant`, `border_focused`, `border_selected`, `border_transparent`, `border_disabled` | Çevre çizgileri ve focus/selection durumları | 6 |
| **Yüzeyler** | `background`, `surface_background`, `elevated_surface_background` | Pencere/panel/popover katmanlama | 3 |
| **Etkileşimli element** | `element_background`, `element_hover`, `element_active`, `element_selected`, `element_selection_background`, `element_disabled`, `drop_target_background`, `drop_target_border` | Button/clickable durumları | 8 |
| **Ghost element** | `ghost_element_background`, `ghost_element_hover`, `ghost_element_active`, `ghost_element_selected`, `ghost_element_disabled` | Şeffaf bg ile element durumları (toolbar icon vb.) | 5 |
| **Metin** | `text`, `text_muted`, `text_placeholder`, `text_disabled`, `text_accent` | Ön plan renkleri | 5 |
| **Icon** | `icon`, `icon_muted`, `icon_disabled` | Icon ön plan renkleri | 3 |
| **Editor** | `editor_*` (background, foreground, line_number, active_line_background, wrap_guide, document_highlight_*) | Kod editör katmanı | 18 |
| **Editor diff hunk** | `editor_diff_hunk_*` | Diff hunk background/border görünümü | 6 |
| **Terminal** | `terminal_background`, `terminal_foreground`, `terminal_ansi_*`, `terminal_ansi_dim_*` | Terminal foreground/background ve ANSI normal/bright/dim renkleri | 29 |
| **Panel** | `panel_background`, `panel_focused_border`, `panel_indent_guide_*` | Sidebar/panel kromu | ~5 |
| **Status bar** | `status_bar_background` | Alt durum çubuğu | 1-2 |
| **Title bar** | `title_bar_background`, `title_bar_inactive_background`, `title_bar_border` | Pencere başlığı | ~3 |
| **Tab** | `tab_bar_background`, `tab_active_background`, `tab_inactive_background` | Editor tab şeridi | ~5 |
| **Search** | `search_match_background` | Arama vurgusu | ~2 |
| **Scrollbar** | `scrollbar_thumb_*`, `scrollbar_track_*` | Kaydırma çubuğu | 6 |
| **Minimap** | `minimap_thumb_*` | Minimap kaydırma thumb'u | 4 |
| **Debugger** | `debugger_accent`, `editor_debugger_active_line_background` | Debug oturumu | 2 |
| **VCS** | `version_control_added`, `_modified`, `_deleted`, `_word_*`, `_conflict_marker_*` | Git/VCS göstergeleri | 10 |
| **Vim** | `vim_normal_*`, `vim_visual_*`, `vim_helix_*`, `vim_yank_background` | Vim/Helix modu vurgusu | 18 |
| **Pane group** | `pane_group_border`, `pane_focused_border` | Editor pane sınırları | ~2 |

> **Bu tablo yaklaşık sayılar verir.** Tam liste için
> `crates/theme/src/styles/colors.rs` runtime alanları ve
> `crates/settings_content/src/theme.rs` Content alanları esas alınır.

### Tam alan paritesi

Aşağıdaki liste, referans alınan Zed sürümündeki `ThemeColors` runtime
alanlarının **eksiksiz** kataloğudur. Runtime struct'ı toplam 143 adet
`Hsla` alanı taşır. `ThemeColorsContent` tarafında buna ek olarak 3
deprecated uyumluluk alanı yer alır; bunlar Bölüm V/Konu 19'de ayrıca
belirtilir.

```text
border:
  border, border_variant, border_focused, border_selected,
  border_transparent, border_disabled

surface:
  elevated_surface_background, surface_background, background

element:
  element_background, element_hover, element_active, element_selected,
  element_selection_background, element_disabled,
  drop_target_background, drop_target_border

ghost_element:
  ghost_element_background, ghost_element_hover, ghost_element_active,
  ghost_element_selected, ghost_element_disabled

text:
  text, text_muted, text_placeholder, text_disabled, text_accent

icon:
  icon, icon_muted, icon_disabled, icon_placeholder, icon_accent

debugger:
  debugger_accent

chrome:
  status_bar_background, title_bar_background,
  title_bar_inactive_background, toolbar_background,
  tab_bar_background, tab_inactive_background, tab_active_background,
  search_match_background, search_active_match_background,
  panel_background, panel_focused_border, panel_indent_guide,
  panel_indent_guide_hover, panel_indent_guide_active,
  panel_overlay_background, panel_overlay_hover,
  pane_focused_border, pane_group_border

scrollbar:
  scrollbar_thumb_background, scrollbar_thumb_hover_background,
  scrollbar_thumb_active_background, scrollbar_thumb_border,
  scrollbar_track_background, scrollbar_track_border

minimap:
  minimap_thumb_background, minimap_thumb_hover_background,
  minimap_thumb_active_background, minimap_thumb_border

vim:
  vim_normal_background, vim_insert_background, vim_replace_background,
  vim_visual_background, vim_visual_line_background,
  vim_visual_block_background, vim_yank_background,
  vim_helix_jump_label_foreground, vim_helix_normal_background,
  vim_helix_select_background, vim_normal_foreground,
  vim_insert_foreground, vim_replace_foreground, vim_visual_foreground,
  vim_visual_line_foreground, vim_visual_block_foreground,
  vim_helix_normal_foreground, vim_helix_select_foreground

editor:
  editor_foreground, editor_background, editor_gutter_background,
  editor_subheader_background, editor_active_line_background,
  editor_highlighted_line_background, editor_debugger_active_line_background,
  editor_line_number, editor_active_line_number, editor_hover_line_number,
  editor_invisible, editor_wrap_guide, editor_active_wrap_guide,
  editor_indent_guide, editor_indent_guide_active,
  editor_document_highlight_read_background,
  editor_document_highlight_write_background,
  editor_document_highlight_bracket_background,
  editor_diff_hunk_added_background,
  editor_diff_hunk_added_hollow_background,
  editor_diff_hunk_added_hollow_border,
  editor_diff_hunk_deleted_background,
  editor_diff_hunk_deleted_hollow_background,
  editor_diff_hunk_deleted_hollow_border

terminal:
  terminal_background, terminal_foreground, terminal_bright_foreground,
  terminal_dim_foreground, terminal_ansi_background,
  terminal_ansi_black, terminal_ansi_bright_black, terminal_ansi_dim_black,
  terminal_ansi_red, terminal_ansi_bright_red, terminal_ansi_dim_red,
  terminal_ansi_green, terminal_ansi_bright_green, terminal_ansi_dim_green,
  terminal_ansi_yellow, terminal_ansi_bright_yellow,
  terminal_ansi_dim_yellow, terminal_ansi_blue,
  terminal_ansi_bright_blue, terminal_ansi_dim_blue,
  terminal_ansi_magenta, terminal_ansi_bright_magenta,
  terminal_ansi_dim_magenta, terminal_ansi_cyan,
  terminal_ansi_bright_cyan, terminal_ansi_dim_cyan,
  terminal_ansi_white, terminal_ansi_bright_white,
  terminal_ansi_dim_white

link:
  link_text_hover

version_control:
  version_control_added, version_control_deleted,
  version_control_modified, version_control_renamed,
  version_control_conflict, version_control_ignored,
  version_control_word_added, version_control_word_deleted,
  version_control_conflict_marker_ours,
  version_control_conflict_marker_theirs
```

**Parite ilişkisi:** Runtime alanları, `ThemeColorsContent` alanları ve
deprecated content alanları arasında şu denge korunur: content alanları sayısı
= runtime alanları + deprecated uyumluluk alanları.

### Naming convention

| Konum | Stil | Örnek |
|-------|------|-------|
| Rust alan adı | `snake_case` | `border_variant`, `terminal_ansi_red` |
| JSON anahtarı | `dot.separated` | `border.variant`, `terminal.ansi.red` |
| Bağlantı | `#[serde(rename = "border.variant")]` | (Bölüm V/Konu 23) |

### `Refineable` davranışı

`ThemeColors` `Refineable` türevini taşıdığı için her alan için
`ThemeColorsRefinement` içinde bir `Option<Hsla>` üretilir. `from_content`
akışı şu şekilde işler:

1. Baseline `ThemeColors` klonlanır.
2. Kullanıcı temasından `ThemeColorsRefinement` üretilir.
3. `baseline.refine(&refinement)` çağrısıyla iki katman birleştirilir.

Sonuçta eksik alanlar baseline'dan gelir; kullanıcının verdiği alanlar
baseline'ın üstüne yazılır.

### Tuzaklar

1. **Sıra önemlidir (sözleşme açısından değil, okunabilirlik açısından)**:
   Zed dosyasındaki sıralamanın korunması, yeni alanların yerinin
   anlaşılmasını kolaylaştırır. Alfabetik sıralama ise yanlış bir tercih
   olur ve ileride parite kontrolünü zorlaştırır.
2. **Grup yorumlarını silmek**: `// Kenarlıklar`, `// Yüzeyler` gibi
   semantik yorumlar grup sınırını gösterir; yeni alan grupları eklenirken
   bu yorumlar referans noktası olarak iş görür.
3. **Yeni grup eklendiğinde Konu 13 tablosunu güncellememek**: Yeni bir
   semantik grup eklendiyse rehberin bu bölümündeki tabloya satır
   eklenmesi gerekir; aksi halde dokümantasyon kodun gerisinde kalır.
4. **Editor / debugger / vcs alanlarını dışlamak**: "Henüz editor yok"
   geçerli bir dışlama sebebi olarak kabul edilmez (Konu 2). Tüm alanlar
   eklenir, UI'da okunması sonraya bırakılabilir.
5. **`Option<Hsla>` alanları**: `ThemeColors` `Hsla` (Option değil) tutar.
   Eksik bir alan baseline'dan doldurulur — refinement katmanı bunu
   yönetir. `ThemeColors` içinde `Option<Hsla>` kullanılmaya kalkıldığında
   refinement deseni bozulur.

### `all_theme_colors` ve `ThemeColorField` — reflection API

**Kaynak:** `crates/theme/src/styles/colors.rs:346` (`ThemeColorField`
enum), `crates/theme/src/styles/colors.rs:596` (`all_theme_colors` fn).

Tema editörü, color picker, debug inspector veya snapshot testi yazarken tema
renklerini **runtime'da listelemek** gerekebilir. Zed bu ihtiyacı iki yapıyla
karşılar:

```rust
use strum::{AsRefStr, EnumIter, IntoEnumIterator};

/// Tema editörü/preview için seçilmiş reflection alt kümesi.
#[derive(EnumIter, Debug, Clone, Copy, AsRefStr)]
#[strum(serialize_all = "snake_case")]
pub enum ThemeColorField {
    Border,
    BorderVariant,
    // ... referans Zed sürümünde 111 variant
}

impl ThemeColors {
    pub fn color(&self, field: ThemeColorField) -> Hsla { /* match field */ }
    pub fn iter(&self) -> impl Iterator<Item = (ThemeColorField, Hsla)> + '_ { /* ... */ }
    pub fn to_vec(&self) -> Vec<(ThemeColorField, Hsla)> { /* ... */ }
}

/// Tüm tema renklerini key-value liste olarak döner
pub fn all_theme_colors(cx: &mut App) -> Vec<(Hsla, SharedString)> {
    let theme = cx.theme();
    ThemeColorField::iter()
        .map(|field| {
            let color = theme.colors().color(field);
            let name = field.as_ref().to_string();
            (color, SharedString::from(name))
        })
        .collect()
}
```

**Kritik parite notu:** `ThemeColorField`, `ThemeColors` içindeki her alanı
kapsamaz. Referans Zed sürümünde runtime `ThemeColors` 143 alan taşır;
`ThemeColorField` ise yalnızca 111 variant'lık bir reflection alt kümesidir.
Küme ilişkisi şöyledir:

```text
ThemeColorField labels ⊆ ThemeColors fields
ThemeColorField labels = 111
ThemeColors fields = 143
```

`ThemeColors` içinde bulunan ama Zed reflection API'sinde yer almayan 32
alan şunlardır:

```text
debugger_accent
editor_debugger_active_line_background
editor_diff_hunk_added_background
editor_diff_hunk_added_hollow_background
editor_diff_hunk_added_hollow_border
editor_diff_hunk_deleted_background
editor_diff_hunk_deleted_hollow_background
editor_diff_hunk_deleted_hollow_border
editor_hover_line_number
element_selection_background
version_control_conflict_marker_ours
version_control_conflict_marker_theirs
version_control_word_added
version_control_word_deleted
vim_helix_jump_label_foreground
vim_helix_normal_background
vim_helix_normal_foreground
vim_helix_select_background
vim_helix_select_foreground
vim_insert_background
vim_insert_foreground
vim_normal_background
vim_normal_foreground
vim_replace_background
vim_replace_foreground
vim_visual_background
vim_visual_block_background
vim_visual_block_foreground
vim_visual_foreground
vim_visual_line_background
vim_visual_line_foreground
vim_yank_background
```

**`kvs_tema`'da karşılığı:**

```rust
// kvs_tema/src/styles/colors_reflection.rs
#[derive(Debug, Clone, Copy)]
pub enum ThemeColorField {
    Background,
    Border,
    // ... Zed reflection subset'indeki 111 alan için bir variant
}

impl ThemeColorField {
    // Zed referansında `ALL` const yok; `strum::IntoEnumIterator`
    // kullanılıyor. `kvs_tema` isterse makrodan `ALL` üretebilir.
    pub const ALL: &'static [ThemeColorField] = &[
        ThemeColorField::Background,
        ThemeColorField::Border,
        // ...
    ];

    pub fn label(&self) -> SharedString {
        match self {
            Self::Background => "background".into(),
            Self::Border     => "border".into(),
            // ...
        }
    }

    pub fn value(&self, colors: &ThemeColors) -> Hsla {
        match self {
            Self::Background => colors.background,
            Self::Border     => colors.border,
            // ...
        }
    }
}

pub fn all_theme_colors(cx: &mut App) -> Vec<(Hsla, SharedString)> {
    let colors = cx.theme().colors();
    ThemeColorField::ALL
        .iter()
        .map(|f| (f.value(colors), f.label()))
        .collect()
}
```

**Üretim disiplini:** Burada iki stratejiden biri seçilmeli ve seçimin adı
net konulmalıdır:

- **Zed paritesi:** `ThemeColorField` yalnızca Zed'in 111 alanlık
  reflection subset'ini mirror eder. `ThemeColors` alanları için ayrıca
  143 alanlık bir runtime/content parite testi tutulur.
- **Yerel tam reflection:** `ThemeColorField` 143 alanın tamamını kapsar.
  Bu, Zed'den bilinçli bir genişletmedir; snapshot testlerinde `111`
  değil `143` beklenir.

111 ya da 143 alanı elle yazmak yorucu hale geldiğinde derive makrosu pratik
bir çözüm olur:

```rust
#[derive(Refineable, ThemeColorReflect)]
pub struct ThemeColors { /* ... */ }
```

`ThemeColorReflect` derive makrosu `ThemeColorField` enum'unu, `label` ve
`value` impl'lerini otomatik olarak üretir. Zed paritesi tercih edilmişse
32 alan, `#[theme_color_reflect(skip)]` benzeri bir attribute ile
reflection dışı bırakılır; aksi halde makro yerel genişletme üretir.
Refinement makrosuyla aynı crate içinde (`ui_macros` veya `kvs_macros`)
tutulması, bakım açısından çok daha tutarlı bir yerleşim olur.

**Kullanım yerleri:**

```rust
// Tema editörü ekranı
fn render_theme_editor(cx: &mut Context<ThemeEditor>) -> impl IntoElement {
    v_flex().children(
        kvs_tema::all_theme_colors(cx).into_iter().map(|(color, label)| {
            h_flex()
                .gap_2()
                .child(div().size(px(20.)).bg(color))
                .child(Label::new(label.clone()))
                .child(Label::new(format!("{:?}", color)))
        })
    )
}
```

```rust
// Snapshot testi
#[test]
fn theme_color_count_matches_zed_reference() {
    assert_eq!(ThemeColorField::ALL.len(), 111);
}
```

Bu test tek başına yeterli değildir. `ThemeColorField` label'larının tamamı
gerçek bir `ThemeColors` alanına denk gelmelidir. Dışarıda kalan 32 alanın da
yukarıdaki listeyle birebir eşleşmesi beklenir. Aksi halde yeni eklenen bir
alan sessizce reflection dışında kalabilir ya da yanlışlıkla reflection'a
eklenip Zed paritesi bozulabilir.

```rust
// Reflection karşılaştırması
let zed: Vec<_> = all_theme_colors_in(theme_a);
let user: Vec<_> = all_theme_colors_in(theme_b);
for ((a, label), (b, _)) in zed.iter().zip(user.iter()) {
    if a != b {
        println!("{}: {:?} → {:?}", label, a, b);
    }
}
```

---

## 14. `StatusColors`: fg/bg/border üçlüsü deseni

**Kaynak modül:** `kvs_tema/src/styles/status.rs`.

Diagnostic ve VCS durum renklerini taşır. Her durum için **üç alan** vardır:
foreground (`<ad>`), background (`<ad>_background`) ve border
(`<ad>_border`).

```rust
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct StatusColors {
    pub error: Hsla,
    pub error_background: Hsla,
    pub error_border: Hsla,
    pub warning: Hsla,
    pub warning_background: Hsla,
    pub warning_border: Hsla,
    // ... 14 status × 3 = 42 alan
}
```

### 14 status tipi

| Status | Kullanım |
|--------|----------|
| `conflict` | Git merge conflict markeri |
| `created` | Yeni eklenmiş satır/dosya |
| `deleted` | Silinmiş satır/dosya |
| `error` | Diagnostic hata seviyesi |
| `hidden` | Gizli/atlanmış öğeler |
| `hint` | Diagnostic hint seviyesi (en düşük) |
| `ignored` | `.gitignore` ile dışlanmış |
| `info` | Diagnostic info seviyesi |
| `modified` | Değiştirilmiş satır/dosya |
| `predictive` | Tahmin (örn. AI completion) |
| `renamed` | Adı değiştirilmiş dosya |
| `success` | Başarılı işlem göstergesi |
| `unreachable` | Erişilemez kod yolu |
| `warning` | Diagnostic uyarı seviyesi |

**Toplam:** 14 × 3 = **42 alan**.

Tam alan grupları:

```text
conflict, conflict_background, conflict_border
created, created_background, created_border
deleted, deleted_background, deleted_border
error, error_background, error_border
hidden, hidden_background, hidden_border
hint, hint_background, hint_border
ignored, ignored_background, ignored_border
info, info_background, info_border
modified, modified_background, modified_border
predictive, predictive_background, predictive_border
renamed, renamed_background, renamed_border
success, success_background, success_border
unreachable, unreachable_background, unreachable_border
warning, warning_background, warning_border
```

### Üçlü deseni

Her status üçlüsü kendi içinde tutarlı bir yapıya sahiptir:

```rust
pub <name>: Hsla,             // foreground — ana renk (icon, metin)
pub <name>_background: Hsla,  // arka plan — vurgu/highlight bg
pub <name>_border: Hsla,      // kenar — outline/divider
```

Pratikte tema yazarı çoğu zaman yalnızca foreground rengini verir.
`_background` ve `_border` değerleri ise baseline'dan gelir veya ayrı
yardımcılarla türetilir.

### Türetme önizleme (`apply_status_color_defaults`)

`refinement.rs` içindeki yardımcı; **foreground verilmiş ama background
verilmemiş** durumda `_background` değerini foreground'un **%25
alpha**'lı bir kopyasından türetir:

```rust
pub fn apply_status_color_defaults(r: &mut StatusColorsRefinement) {
    let pairs = &mut [
        (&mut r.deleted, &mut r.deleted_background),
        (&mut r.created, &mut r.created_background),
        (&mut r.modified, &mut r.modified_background),
        (&mut r.conflict, &mut r.conflict_background),
        (&mut r.error, &mut r.error_background),
        (&mut r.hidden, &mut r.hidden_background),
    ];
    for (fg, bg) in pairs {
        if bg.is_none() && let Some(fg) = fg.as_ref() {
            **bg = Some(fg.opacity(0.25));
        }
    }
}
```

Detaylar Bölüm VII/Konu 31'de işlenir. Burada bilinmesi gereken nokta şudur:
**fg-only** JSON temaları, belirli `_background` değerlerini baseline'dan
almaz. Bu değerler doğrudan kullanıcının verdiği foreground renginden
türetilir. Böylece tema yazarının seçtiği ana renkten kopmayan bir görsel
tutarlılık elde edilir.

### JSON şeması

```json
{
  "error": "#ff5555ff",
  "error.background": "#ff555520",
  "error.border": "#ff555580",
  "warning": "#ffaa00ff"
}
```

> **Not:** JSON anahtarında `.background` (`error.background`) kullanılır;
> Rust alan adında ise `_background` (`error_background`). İki taraf
> arasındaki köprü `#[serde(rename = "error.background")]` ile kurulur.

### Tüm alanlar Hsla, hiçbiri Option değil

`StatusColors` da `ThemeColors` gibi her alanı `Hsla` olarak tutar. Eksik
alanlar runtime struct'ında değil, refinement katmanında ele alınır.
`StatusColorsRefinement` her alanı otomatik olarak `Option<Hsla>` haline
getirir.

### Editor için `DiagnosticColors` projeksiyonu

Zed'in `crates/theme/src/styles/status.rs:83` dosyasında, `StatusColors`'un
yanı sıra **`DiagnosticColors`** adında üç alanlı bir tip de bulunur:

```rust
pub struct DiagnosticColors {
    pub error: Hsla,
    pub warning: Hsla,
    pub info: Hsla,
}
```

**Rol:** Editor diagnostic'leri için (squiggly underline, gutter işaretleri,
diagnostic popup) **sıkıştırılmış** bir renk seti sunar. `StatusColors` 42
alan taşır; `DiagnosticColors` ise editor render path'ine yalnızca üç
foreground rengini verir. Bu tip refinement zincirinde yer almaz; doğrudan
`StatusColors`'tan **türetilir**:

```rust
impl Theme {
    pub fn diagnostic_colors(&self) -> DiagnosticColors {
        DiagnosticColors {
            error: self.status().error,
            warning: self.status().warning,
            info: self.status().info,
        }
    }
}
```

**Kullanım yeri:** Editor crate'i (`kvs_editor`) diagnostic render sırasında
`cx.theme().status().error` yerine `cx.theme().diagnostic_colors().error`
çağrısını kullanabilir. Üç alanı tek seferde almak, her render'da ayrı ayrı
`status()` erişimi yapmaktan daha okunaklıdır.

**JSON sözleşmesinde yer almaz.** Tema dosyasında `diagnostic.error` gibi
bir anahtar bulunmaz; `error`, `warning` ve `info` değerleri
`StatusColors`'tan gelir. `DiagnosticColors` tamamen runtime tarafında
yapılan bir projeksiyondur.

**Ne zaman kullanılır?**

- Editor diagnostic render: `error` squiggly, `warning` squiggly, `info`
  squiggly.
- Diagnostic popup başlığı (severity icon + renk).
- Gutter işaretinin yanındaki severity dot.

**Ne zaman kullanılmaz?**

- Modal, banner veya toast tasarımları: bu yüzeylerde `StatusColors`'un
  üçlü deseni (fg/bg/border) gerekir; `DiagnosticColors` bg ve border
  taşımaz.
- File tree status alanları (created/modified/deleted): bunlar diagnostic
  değil VCS status değerleridir; `StatusColors.modified` gibi alanlardan
  beslenir.

**Sözleşme sınırı:** `DiagnosticColors` alanları Zed'in diagnostic severity
modelini izler. Zed tarafında yeni bir severity alanı eklenirse `kvs_tema`
runtime tipinin de aynı alanı taşıması beklenir.

### Tuzaklar

1. **Türetme kuralının atlanması**: Kullanıcı yalnızca `error` rengini
   verdiyse ve `apply_status_color_defaults` çağrılmadıysa,
   `error_background` baseline'dan kalır. Sonuç olarak kullanıcı
   temasının ana rengi var ama background eski temanın yarı saydam
   mavisidir; UI dağınık görünür.
2. **14 status'un tamamını dahil etmek**: Tema yazarı yalnızca `error` ve
   `warning` kullanıyor olsa bile, struct'ta `predictive`, `unreachable`,
   `renamed` vb. **bulunmak zorundadır** (Konu 2). UI'da okunmayan alanın
   maliyeti sıfırdır.
3. **`_background` ve `_border` farklı türetilebilir**: Background için
   %25 alpha makul bir tercihtir; border için %50 alpha çoğu zaman daha
   doğal durur. Mevcut yardımcı fonksiyon yalnızca `_background` için
   tanımlıdır — `_border` için ayrı bir türetme istendiğinde ek bir
   fonksiyonun yazılması yerinde olur.
4. **Yeni status tipi**: Zed sözleşmesindeki her status tipi fg/bg/border
   üçlüsüyle temsil edilir; foreground-only türetme gerektiren senaryolar
   `apply_status_color_defaults` içinde toplanır.

---

## 15. `PlayerColors`, `PlayerColor`, slot semantiği

**Kaynak modül:** `kvs_tema/src/styles/players.rs`.

"Player" terimi Zed'in collaboration sisteminden gelir. Aynı dosyada eş
zamanlı düzenleme yapan her kullanıcıya ayrı bir **cursor**, **selection** ve
**background** rengi atanır. Bu yapı single-player uygulamalarda da işe yarar;
örneğin multi-cursor görünümlerinde kullanılabilir.

```rust
#[derive(Clone, Debug, PartialEq)]
pub struct PlayerColor {
    pub cursor: Hsla,
    pub background: Hsla,
    pub selection: Hsla,
}

#[derive(Clone, Debug, PartialEq)]
pub struct PlayerColors(pub Vec<PlayerColor>);

impl Default for PlayerColors {
    fn default() -> Self {
        Self::dark()
    }
}
```

### `PlayerColor` alanları

| Alan | Rol |
|------|-----|
| `cursor` | Kullanıcının imleç rengi (tam opak). |
| `background` | Avatar/etiket arka planı (yarı saydam). |
| `selection` | Bu kullanıcının metin seçim arka planı (yarı saydam). |

### Slot semantiği

`PlayerColors(Vec<PlayerColor>)` sıralı bir listedir. **Index 0 yerel
kullanıcıya ayrılır**. Sonraki indeksler katılımcı (participant) slotlarıdır.

**Zed kaynak sözleşmesinin tüm metotları** (`crates/theme/src/styles/players.rs`):

```rust
impl PlayerColors {
    pub fn dark() -> Self { /* 8 player slot */ }
    pub fn light() -> Self { /* 8 player slot */ }

    /// İlk slot — yerel kullanıcı. Liste boşsa panic eder.
    pub fn local(&self) -> PlayerColor {
        *self.0.first().unwrap()
    }

    /// Agent slot — listenin son elemanı.
    pub fn agent(&self) -> PlayerColor {
        *self.0.last().unwrap()
    }

    /// Absent (yerelde olmayan) kullanıcı — agent ile aynı son slot.
    pub fn absent(&self) -> PlayerColor {
        *self.0.last().unwrap()
    }

    /// Read-only katılımcı — yerel renklerin grayscale projeksiyonu.
    pub fn read_only(&self) -> PlayerColor {
        let local = self.local();
        PlayerColor {
            cursor: local.cursor.grayscale(),
            background: local.background.grayscale(),
            selection: local.selection.grayscale(),
        }
    }

    /// Belirli bir katılımcı indeksine renk atar. Index 0 local slot'u
    /// atlar; modulo ile slot havuzu sarmal döner.
    pub fn color_for_participant(&self, participant_index: u32) -> PlayerColor {
        let len = self.0.len() - 1;
        self.0[(participant_index as usize % len) + 1]
    }
}
```

**Davranış kuralları:**

- Liste boş olduğunda `local()`, `agent()`, `absent()`, `read_only()` ve
  `color_for_participant()` metotlarının hepsi panic atar. Bu yüzden fallback
  temalarda en az bir `PlayerColor` bulunmalıdır. Collaboration veya
  participant renkleri kullanılacaksa en az iki slot gerekir.
- `color_for_participant(N)` çağrısı local slot'u atlar: participant 0,
  liste index 1'ini kullanır. 8 slot bulunduğu varsayıldığında remote
  slotlar index 1 ile 7 arasında döner.
- `agent()` ve `absent()` aynı slot'u döndürür: listenin son elemanı.
  Semantik ayrım tüketici tarafında yapılır. Bir kullanım agent UI'sı,
  diğeri offline kullanıcı olabilir.
- `read_only()` çağrı anında lokal slot'tan grayscale türevi üretir;
  fallback temada lokal değer dolu olduğu sürece otomatik çalışır.
- Bu API boş veya tek elemanlı listeyi tolere etmez; listenin runtime'a
  ulaşmadan önce fallback veya fixture testleriyle garanti altına
  alınması gerekir.

### JSON şeması

```json
{
  "players": [
    { "cursor": "#22d3eeff", "background": "#22d3ee40", "selection": "#22d3ee20" },
    { "cursor": "#a78bfaff", "background": "#a78bfa40", "selection": "#a78bfa20" }
  ]
}
```

`players` boş array olarak gelirse refinement deseni baseline listesini korur;
bu durum `Theme::from_content` içinde kontrol edilir.

### Kullanım örnekleri

```rust
// Yerel kullanıcının imleci
let yerel = cx.theme().players().local();
div().bg(yerel.cursor)

// 3. katılımcının seçimi
let katilimci = cx.theme().players().color_for_participant(3);
div().bg(katilimci.selection)
```

### Tuzaklar

1. **Boş `PlayerColors`**: `Vec` boş olduğunda `local()` panic eder; yalnız
   tek bir slot varsa `color_for_participant` modulo-by-zero hatasına yol
   açar. Fallback temalarda **en az bir local slot**, participant kullanılan
   senaryolarda ise **en az iki slot** bulundurulmalıdır:
   ```rust
   PlayerColors(vec![PlayerColor { cursor: accent, ... }])
   ```
2. **`color_for_participant(0)` ile `local()` arasındaki fark**: Bu iki
   çağrı aynı sonucu vermez. `local()` index 0'a karşılık gelir;
   `color_for_participant(0)` ise index 1'i döndürür. Remote katılımcı
   renkleri böylelikle local renkten ayrı tutulur.
3. **Modulo yerine clamp düşünmek**: Modulo davranışı kasıtlıdır — slot
   sayısı yetmediğinde "sarmal" bir döngü oluşturur. Clamp seçildiğinde
   ise son slot, sınırı aşan tüm katılımcılarda aynı renk olur ve
   katılımcılar birbirinden ayırt edilemez hale gelir.
4. **`cursor` alpha değeri**: Bu alan genellikle 1.0 (tam opak) verilir;
   `background` ve `selection` ise yarı saydam tutulur. Üçünün de tam opak
   olduğu durumda metin görünmez hale gelir.
5. **Tema yazarının `players` alanını atlaması**: `players: []` verilmesi
   veya alanın hiç olmaması durumunda baseline'ın player paleti korunur.
   Bu davranış kasıtlıdır; her tema kendi player paletini sunmak zorunda
   değildir.

---

## 16. `AccentColors`, `SystemColors`, `Appearance`

Bu üç tip tema'nın **kromatik altyapısını** tamamlar: dönen accent listesi,
platforma özgü sabitler ve tema modunun nominal işareti.

### `AccentColors`

**Kaynak modül:** `kvs_tema/src/styles/accents.rs`.

Tema'nın vurgu renklerini taşır. Bu liste çoğunlukla rotasyon mantığıyla
kullanılır; örneğin chip, etiket veya label dizilerinde her öğeye sırayla
renk vermek için.

**Zed kaynak sözleşmesi** (`crates/theme/src/styles/accents.rs`):

```rust
#[derive(Clone, Debug, Deserialize, PartialEq)]
pub struct AccentColors(pub Arc<[Hsla]>);

impl Default for AccentColors {
    fn default() -> Self {
        Self::dark()
    }
}

impl AccentColors {
    pub fn dark() -> Self { /* 13 elemanlı sabit liste */ }
    pub fn light() -> Self { /* 13 elemanlı sabit liste */ }

    pub fn color_for_index(&self, index: u32) -> Hsla {
        self.0[index as usize % self.0.len()]
    }
}
```

**Üç önemli sözleşme noktası:**

- İç tip `Arc<[Hsla]>`'dır; `Vec<Hsla>` değildir. Sözleşme `Arc<[T]>`
  üzerinden paylaşılır. Klonlama ucuzdur, değerler mutate edilmez.
- Lookup metodunun adı `color_for_index`'dir, `color_for` değil.
- Boş liste için **fallback yoktur**: modulo lookup'u `len()` 0 olduğunda
  panic atar. `Default::default()` çağrısı `Self::dark()` döndürdüğü için
  varsayılan her zaman 13 elemanlıdır. Tema yazarının `accents: []` vermesine
  refinement katmanı da izin vermez (Bölüm VII/Konu 29).

**`kvs_tema`'da sözleşme:**

```rust
#[derive(Clone, Debug, Deserialize, PartialEq)]
pub struct AccentColors(pub Arc<[Hsla]>);

impl Default for AccentColors {
    fn default() -> Self {
        Self::dark()
    }
}

impl AccentColors {
    pub fn dark() -> Self { Self(Arc::from(default_dark_accents().as_slice())) }
    pub fn light() -> Self { Self(Arc::from(default_light_accents().as_slice())) }

    pub fn color_for_index(&self, index: u32) -> Hsla {
        self.0[index as usize % self.0.len()]
    }
}
```

**Davranış:**

- Modulo ile döner — accent listesi tükendiğinde başa sarar.
- Boş liste durumu sözleşmeyle dışarıda bırakılır. Yine de defansif kod
  gerektiren yerlerde `Default::default()` ile fallback kurulmalıdır; aksi
  halde sıfır eleman panic riski oluşturur.

**JSON şeması:**

```json
{
  "accents": ["#22d3eeff", "#a78bfaff", "#f59e0bff", null]
}
```

`null` girdiler `Vec<Option<String>>` olarak `*Content` tipine girer;
parse hatası alanlar `filter_map` ile elenir (`Theme::from_content`
içinde).

**Tema'da kullanım:**

```rust
let chip_color = cx.theme().accents().color_for_index(chip_index);
```

Etiket veya chip listesinde her öğeye bir index verildiğinde, renk
otomatik olarak liste üzerinden döner.

### `SystemColors`

**Kaynak modül:** `kvs_tema/src/styles/system.rs`.

Tema-bağımsız platform sabitlerini taşır. **Tüm temalarda aynı değerleri**
kullanır. Tema yazarı bunları override edebilir, ancak pratikte bu çok nadir
gereken bir tercihtir.

```rust
#[derive(Clone, Debug, PartialEq)]
pub struct SystemColors {
    pub transparent: Hsla,
    pub mac_os_traffic_light_red: Hsla,
    pub mac_os_traffic_light_yellow: Hsla,
    pub mac_os_traffic_light_green: Hsla,
}

impl Default for SystemColors {
    fn default() -> Self {
        Self {
            transparent: hsla(0., 0., 0., 0.),
            mac_os_traffic_light_red: hsla(0.0139, 0.79, 0.65, 1.0),
            mac_os_traffic_light_yellow: hsla(0.0986, 0.84, 0.62, 1.0),
            mac_os_traffic_light_green: hsla(0.3194, 0.49, 0.55, 1.0),
        }
    }
}
```

**Alanlar:**

| Alan | Rol |
|------|-----|
| `transparent` | `hsla(0,0,0,0)` sabitidir — `transparent_black()` ile aynı; alan olarak da ayrıca bulundurulur. |
| `mac_os_traffic_light_red` | macOS pencere kapatma butonu rengi (kırmızı). |
| `mac_os_traffic_light_yellow` | Minimize butonu rengi (sarı). |
| `mac_os_traffic_light_green` | Maximize/fullscreen butonu rengi (yeşil). |

Custom titlebar uygulamasında (rehber.md #27) traffic light butonları elle
çizildiğinde, renkler bu alanlardan beslenmelidir.

**Tema'da kullanım:**

```rust
// SystemColors::default() kullanıldığı sürece elle inşa etmeye gerek yok
ThemeStyles {
    system: SystemColors::default(),
    // ...
}
```

### `Appearance`

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

```rust
#[derive(Debug, PartialEq, Clone, Copy, serde::Deserialize)]
pub enum Appearance {
    Light,
    Dark,
}

impl Appearance {
    pub fn is_light(&self) -> bool {
        match self {
            Self::Light => true,
            Self::Dark => false,
        }
    }
}

impl From<WindowAppearance> for Appearance {
    fn from(value: WindowAppearance) -> Self {
        match value {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Self::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Self::Light,
        }
    }
}
```

> **Not:** Zed kaynağındaki `Appearance` `#[serde(rename_all = ...)]`
> attribute'u taşımaz. JSON tarafında `"appearance": "light"` veya `"dark"`
> üretmek için Content katmanı kendi `AppearanceContent` enum'unu taşır
> (Konu 19). Bu yüzden runtime `Appearance` için doğrudan deserialize
> ihtiyacı normal akışta ortaya çıkmaz. Yine de `serde::Deserialize` derive'lı
> tutulması testlerde ve bazı iç akışlarda işe yarar.

**Tema'da rol:** Tema'nın **nominal modu**. Sistem light/dark mod
sinyalinden farklıdır:

| Tip | Anlam | Kaynak |
|-----|-------|--------|
| `Appearance` | "Bu tema light mi, dark mı?" | Tema JSON'undaki `"appearance"` alanı |
| `WindowAppearance` (Bölüm III/Konu 8) | "OS şu an light mı, dark mı?" | `cx.window_appearance()` |

Bu iki değerin birbiriyle **eşleşmesi zorunlu değildir**. Kullanıcı sistem
dark moddayken açıkça light bir tema seçmiş olabilir.

**JSON anahtarı:** `"appearance": "light"` veya `"appearance": "dark"`.

**Kullanım:**

```rust
let active = cx.theme();
if active.appearance.is_light() {
    // light-spesifik logo varyantı, vs.
}
```

### Tuzaklar

1. **`AccentColors` listesinin boş başlatılması**: Boş liste lookup sırasında
   panic riski oluşturur. Fallback temalarda en az 4-6 accent doldurmak,
   görsel çeşitliliği koruyan en pratik yaklaşımdır.
2. **`SystemColors`'un sıfır bırakılması**: `Default::default()` kullanmak
   yeterlidir. Elle doldurma yolu seçildiğinde macOS traffic light
   renklerinin elle hesaplanması gerekir, bu da gereksiz bir bakım yükü
   getirir.
3. **`Appearance` ile `WindowAppearance` arasındaki karışıklık**: İlki
   tema'nın nominal modunu, ikincisi sistem modunu temsil eder. Aralarında
   `From<WindowAppearance> for Appearance` impl'i bulunur; `Vibrant*`
   varyantları `Light`/`Dark` değerlerine indirgenir. Doğrudan dönüşüm
   şöyle çalışır:
   ```rust
   let app_appearance: Appearance = cx.window_appearance().into();
   ```
   Sözleşme tutarlılığı açısından `SystemAppearance::init` de aynı `From`
   impl'ini içeride kullanır (Konu 35). "İki kategoriye indirgeme"
   davranışının tek kaynağı bu impl'dir.
4. **JSON'daki `appearance` alanı için casing**: Runtime `Appearance` ile
   JSON'daki `AppearanceContent` ayrı tiplerdir. Content tarafı
   serializer ayarlarını taşır (Konu 19); runtime enum'unun rename
   politikası tüketici tarafında görünmez.
5. **`AccentColors::color_for_index(u32)` taşması**: `u32::MAX` verilse
   bile modulo güvenlidir — usize'a cast 64-bit platformda taşma
   yaratmaz. 32-bit platformlarda dikkat gerektirir ama bu nadir bir
   senaryodur.
6. **`AccentColors` iç tipini `Vec<Hsla>` yapmak**: Sözleşme `Arc<[Hsla]>`
   üzerinedir. `Vec` yazıldığında baseline'dan yapılan klon her tema
   varyantında yeni bir allocation üretir; bu durum `Arc<[T]>`'nin
   cheap-clone garantisini bozar.

---

## 17. `ColorScale` ailesi — 12-adımlı palet sistemi

**Kaynak:** `crates/theme/src/scale.rs`.

Zed'in fallback temalarındaki renk üretim sistemi **Radix UI** color scales
modelinden esinlenir. Her renk ailesi 12 adımlı bir skala olarak modellenir.
Zed referansında `neutral` adında tek bir alan yoktur; nötr aileler `gray`,
`mauve`, `slate`, `sage`, `olive`, `sand` gibi ayrı scale set'ler halinde
tutulur. Adım numarası **semantik anlam** taşır:

```rust
pub struct ColorScaleStep(usize);

impl ColorScaleStep {
    pub const ONE: Self = Self(1);    // Ana arka plan
    pub const TWO: Self = Self(2);    // Subtle bg
    pub const THREE: Self = Self(3);  // Normal element bg
    pub const FOUR: Self = Self(4);   // Hover element bg
    pub const FIVE: Self = Self(5);   // Active element bg
    pub const SIX: Self = Self(6);    // Border
    pub const SEVEN: Self = Self(7);  // Strong border
    pub const EIGHT: Self = Self(8);  // Element focus ring
    pub const NINE: Self = Self(9);   // Solid background (accent)
    pub const TEN: Self = Self(10);   // Hover solid bg
    pub const ELEVEN: Self = Self(11);// Low-contrast text
    pub const TWELVE: Self = Self(12);// High-contrast text
}

pub struct ColorScale(Vec<Hsla>);    // 12 Hsla

impl ColorScale {
    pub fn step(&self, step: ColorScaleStep) -> Hsla { /* ... */ }
    pub fn step_1(&self) -> Hsla { /* ... */ }
    // ... step_12 kadar
}

pub struct ColorScaleSet {
    name: SharedString,
    light: ColorScale,
    light_alpha: ColorScale,
    dark: ColorScale,
    dark_alpha: ColorScale,
}

impl ColorScaleSet {
    pub fn new(
        name: impl Into<SharedString>,
        light: ColorScale,
        light_alpha: ColorScale,
        dark: ColorScale,
        dark_alpha: ColorScale,
    ) -> Self;

    pub fn name(&self) -> &SharedString;
    pub fn light(&self) -> &ColorScale;
    pub fn light_alpha(&self) -> &ColorScale;
    pub fn dark(&self) -> &ColorScale;
    pub fn dark_alpha(&self) -> &ColorScale;
    pub fn step(&self, cx: &App, step: ColorScaleStep) -> Hsla;
    pub fn step_alpha(&self, cx: &App, step: ColorScaleStep) -> Hsla;
}

pub struct ColorScales {
    pub gray: ColorScaleSet,
    pub mauve: ColorScaleSet,
    pub slate: ColorScaleSet,
    pub sage: ColorScaleSet,
    pub olive: ColorScaleSet,
    pub sand: ColorScaleSet,
    pub gold: ColorScaleSet,
    pub bronze: ColorScaleSet,
    pub brown: ColorScaleSet,
    pub yellow: ColorScaleSet,
    pub amber: ColorScaleSet,
    pub orange: ColorScaleSet,
    pub tomato: ColorScaleSet,
    pub red: ColorScaleSet,
    pub ruby: ColorScaleSet,
    pub crimson: ColorScaleSet,
    pub pink: ColorScaleSet,
    pub plum: ColorScaleSet,
    pub purple: ColorScaleSet,
    pub violet: ColorScaleSet,
    pub iris: ColorScaleSet,
    pub indigo: ColorScaleSet,
    pub blue: ColorScaleSet,
    pub cyan: ColorScaleSet,
    pub teal: ColorScaleSet,
    pub jade: ColorScaleSet,
    pub green: ColorScaleSet,
    pub grass: ColorScaleSet,
    pub lime: ColorScaleSet,
    pub mint: ColorScaleSet,
    pub sky: ColorScaleSet,
    pub black: ColorScaleSet,
    pub white: ColorScaleSet,
}

impl IntoIterator for ColorScales {
    type Item = ColorScaleSet;
    type IntoIter = std::vec::IntoIter<Self::Item>;

    /// `vec![self.gray, self.mauve, ..., self.white]` sırasıyla 33 paleti
    /// dolaşır. Tüm paletleri kataloglamak (snapshot, color picker grid)
    /// için kanonik yol.
    fn into_iter(self) -> Self::IntoIter { /* ... 33 element vec'i ... */ }
}
```

**`ColorScales::IntoIterator` davranışı:** Zed
(`theme/src/scale.rs:194-235`) tüm 33 paleti **sabit bir sırada**
(`gray → mauve → slate → sage → olive → sand → gold → bronze → brown →
yellow → amber → orange → tomato → red → ruby → crimson → pink → plum →
purple → violet → iris → indigo → blue → cyan → teal → jade → green →
grass → lime → mint → sky → black → white`) `Vec` olarak yayar. Sıralama
deterministiktir. Snapshot testleri ve UI palet ızgaraları bu sıraya güvenebilir.
Mirror tarafta bu sıranın korunması gerekir; aksi halde color picker ile
snapshot karşılaştırmaları farklı sırada değer üretir ve testler düşer.

**Kullanım örneği (Zed `StatusColors::dark()`):**

```rust
impl StatusColors {
    pub fn dark() -> Self {
        Self {
            error: red().dark().step_9(),
            error_background: red().dark().step_9().opacity(0.25),
            error_border: red().dark().step_9(),
            // ...
        }
    }
}
```

`red()` bir `ColorScaleSet` döndürür; `.dark()` bu set içinden bir
`ColorScale` seçer; `.step_9()` ise solid accent rengini verir.

**`kvs_tema`'da ele alma seçenekleri:**

1. **Skala olmadan, doğrudan `hsla` ile:** Bölüm VI/Konu 25 zaten bu yolu
   anlatır. Az sayıda tema için yeterli olur; alanlar arası tutarlılık
   "anchor hue + opacity" disiplini sayesinde sağlanır.

2. **Minimal scale (`step_*` helper'ları olmadan, sadece sabit):**

   ```rust
   pub struct KvsScale {
       pub step_1: Hsla,
       pub step_2: Hsla,
       // ...
       pub step_12: Hsla,
   }

   pub fn neutral_dark() -> KvsScale {
       KvsScale {
           step_1:  hsla(220.0 / 360.0, 0.06, 0.08, 1.0),
           step_2:  hsla(220.0 / 360.0, 0.06, 0.10, 1.0),
           step_3:  hsla(220.0 / 360.0, 0.06, 0.13, 1.0),
           // ... 12 adım
       }
   }
   ```

3. **Tam Radix-style scale (Zed pariteli):** `crates/theme/src/scale.rs`
   ve `crates/theme/src/default_colors.rs` mirror edilir. Bu **kapsamlı**
   bir iştir — `default_color_scales()` 33 renk ailesi için 12 adım ile
   light/dark/alpha matrisini taşır. Tema sıfırdan tasarlanacaksa bu
   yola girilmesi gerekmez; yalnızca Zed'in birebir paletini taklit
   etmek hedefleniyorsa bu yol seçilir (lisans-temizliği için HSL
   değerlerinin bağımsız üretilmesi şarttır; Bölüm I/Konu 3).

**Tavsiye:** Çoğu uygulama için 1. seçenek, yani Konu 25'teki anchor
disiplini yeterlidir. ColorScale modeli, **20'den fazla tema varyantı**
üretmesi gereken design system'lerde anlamlı olur. Tek dark ve tek light tema
için çoğu zaman gereğinden ağır kalır.

**Public domain açık-lisanslı kaynaklar:**

- [Radix UI Colors](https://www.radix-ui.com/colors) — MIT lisanslı,
  HSL değerleri açıktır.
- [Tailwind CSS palette](https://tailwindcss.com/docs/customizing-colors)
  — MIT lisanslı.
- [Open Color](https://yeun.github.io/open-color/) — MIT lisanslı.

Bu kaynaklardaki HSL değerleri referans olarak alınabilir; bunları tema
içinde `ColorScale` ile modellemek isteğe bağlıdır.

---

## 18. `ThemeFamily`, `SyntaxTheme`, `IconTheme`

Bu üç tip, tema'nın **paketleme ve uzantı** tarafını taşır. `ThemeFamily` bir
paket içindeki birden fazla varyantı tek çatı altında toplar. `SyntaxTheme`
syntax token'larının ayrı sözleşmesini taşır. `IconTheme` ise icon tema
sözleşmesinin runtime modelini kurar.

### `ThemeFamily`

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

**Zed kaynak sözleşmesi** (`crates/theme/src/theme.rs:192`):

```rust
pub struct ThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<Theme>,
    /// Sözleşmenin sondan bir alanı — Zed'in `scale.rs` palet matrisi.
    /// Yorum: "This will be removed in the future."
    pub scales: ColorScales,
}
```

**Rol:** Bir **paket** içinde birden fazla tema varyantını bir arada tutar.
Örneğin "One" ailesi `One Light` ve `One Dark` varyantlarını içerir. Zed'in
`assets/themes/` altındaki her JSON dosyası tek bir `ThemeFamily`
deserialize'ına karşılık gelir.

**Alan rolleri:**

| Alan | Rol |
|------|-----|
| `id` | Paket id'si (uuid veya stable id). |
| `name` | Paketin adı (örn. "One"). |
| `author` | Paketin yazarı (örn. "Zed Industries"). |
| `themes` | Bu paketin içindeki tüm varyantlar (light + dark). |
| `scales` | Aileye bağlı palet matrisi — `ColorScales` (43.5'te detay). |

> **`scales` alanı için karar:** Zed kaynağı bu alanı `"This will be
> removed in the future."` notuyla taşır. `kvs_tema` `ColorScale` mirror
> etmiyorsa (Konu 17 tavsiyesi) bu alan da alınmaz; mirror ediyorsa
> parite gereği aynı sırayla eklenir.

**JSON şeması:**

```json
{
  "name": "One",
  "author": "Zed Industries",
  "themes": [
    { "name": "One Light", "appearance": "light", "style": { ... } },
    { "name": "One Dark", "appearance": "dark", "style": { ... } }
  ]
}
```

**Registry'ye yükleme:**

```rust
let family: ThemeFamilyContent = serde_json_lenient::from_slice(&bytes)?;
let themes: Vec<Theme> = family.themes
    .into_iter()
    .map(|theme_content| Theme::from_content(theme_content, &baseline))
    .collect();
registry.insert_themes(themes);
```

Aile metadata'sı registry'ye doğrudan geçirilmez; yalnızca tek tek `Theme`
örnekleri kaydedilir. Aile bilgisini `Theme.id` üzerinden veya ek bir metadata
tablosunda saklamak istenirse bu ayrıca verilecek opsiyonel bir karardır.

### `SyntaxTheme`

**Kaynak crate:** `kvs_syntax_tema`
(`kvs_syntax_tema/src/kvs_syntax_tema.rs`). Zed'in
`crates/syntax_theme/src/syntax_theme.rs` dosyasıyla pariteldir.

```rust
#[derive(Debug, PartialEq, Eq, Clone, Default)]
pub struct SyntaxTheme {
    highlights: Vec<HighlightStyle>,
    capture_name_map: BTreeMap<String, usize>,
}

impl SyntaxTheme {
    /// Yeni sözleşme: tuple iterator alır, `Self` döner (Arc DEĞİL).
    pub fn new(
        highlights: impl IntoIterator<Item = (String, HighlightStyle)>,
    ) -> Self { /* tuple'ları ayrıştırır, capture_name_map indexler */ }

    /// Highlight'ı index üzerinden okur.
    pub fn get(&self, highlight_index: impl Into<usize>) -> Option<&HighlightStyle>;

    /// Capture adıyla highlight lookup'u.
    pub fn style_for_name(&self, name: &str) -> Option<HighlightStyle>;

    /// İndekse karşılık gelen capture adını döner.
    pub fn get_capture_name(&self, idx: impl Into<usize>) -> Option<&str>;

    /// Capture adı için u32 highlight id'sini döner; "string.escape"
    /// gibi alt-kapsama "string" base prefix'i ile eşleşmesini sağlar.
    pub fn highlight_id(&self, capture_name: &str) -> Option<u32>;

    /// Base tema'yı kullanıcı override'ı ile birleştirir; entry boşsa
    /// base'i olduğu gibi döndürür.
    pub fn merge(
        base: Arc<Self>,
        user_syntax_styles: Vec<(String, HighlightStyle)>,
    ) -> Arc<Self>;

    #[cfg(any(test, feature = "test-support"))]
    pub fn new_test(colors: impl IntoIterator<Item = (&'static str, Hsla)>) -> Self;
    #[cfg(any(test, feature = "test-support"))]
    pub fn new_test_styles(
        colors: impl IntoIterator<Item = (&'static str, HighlightStyle)>,
    ) -> Self;
}
```

**Yapı için önemli notlar:**

- İki **private** alan bulunur: `highlights: Vec<HighlightStyle>` yalnızca
  stil vektörüdür, capture adı taşımaz. `capture_name_map:
  BTreeMap<String, usize>` ise capture adından indexe gider. Eski API'deki
  `Vec<(String, HighlightStyle)>` artık dış crate'lere açılmaz; tüketici
  `style_for_name`, `get` ve `highlight_id` üzerinden okur.
- `new(...)` `Self` döndürür ve **`Arc::new` sarmalamaz** — `Arc`
  sözleşmesi caller tarafında kurulur (`Arc::new(SyntaxTheme::new(...))`).
- `style_for_name` `BTreeMap` lookup'u yapar. "İlk eşleşme kazanır" gibi bir
  davranış yoktur; anahtar uniq tutulur. Aynı capture iki kez verilirse `new`
  çağrısı sırasında ikincisi haritada birincisinin üstüne yazar.
- `highlight_id` prefix-eşleşmeli aramaya izin verir:
  `"string.escape"` capture'ı `"string"` highlight'ına düşer. Tree-sitter
  integration'da alt kapsama kuralının çalışma biçimi budur.

**JSON şeması:**

```json
{
  "syntax": {
    "comment": { "color": "#8b9eb999", "font_style": "italic" },
    "string":  { "color": "#a1c181ff" },
    "keyword": { "color": "#c678ddff", "font_weight": 700 }
  }
}
```

JSON tarafında bu yapı bir object olarak yer alır ve sırası `IndexMap` ile
korunur. Rust runtime'a `Vec<(String, HighlightStyle)>` listesi olarak
iletilir. `SyntaxTheme::new` bu listeyi tüketir ve iki private alana
(`highlights` ve `capture_name_map`) ayırır.

**`new()` `Self` döner — `Arc` sarmalı caller tarafında kurulur:**

```rust
let syntax = Arc::new(SyntaxTheme::new(highlights));
```

`Theme` struct'ı içinde alan tipi `Arc<SyntaxTheme>` olarak tanımlanır.
`Arc` sözleşmesi `Theme` katmanında kurulur; `SyntaxTheme::new` API'si
ise Zed'de olduğu gibi `Self` döndürür.

**Tema'da kullanım:**

```rust
// Capture adı ile lookup — BTreeMap O(log n)
let style = cx.theme().syntax().style_for_name("comment");

// Highlight id alıp index üzerinden okumak (tree-sitter integration)
let id = cx.theme().syntax().highlight_id("string.escape")?;
let style = cx.theme().syntax().get(id as usize)?;

// Capture adı index'ten geri okuma
let name = cx.theme().syntax().get_capture_name(0)?;
```

> **Alan iterasyonu:** `highlights` private bir `Vec<HighlightStyle>`'dır
> ve capture adları bu vektörde tutulmaz. Capture adlarına erişmek için
> `get_capture_name(idx)` döngüsü kullanılır veya `highlight_id` ile
> aramaya başvurulur.

Editor entegrasyonu Bölüm X ve XI'de ele alınır.
`SyntaxTheme::merge(base, override)` helper'ı override'ları base'in üstüne
uygular ve yeni bir `Arc` döndürür. Tema override'ları (Bölüm IX/Konu 39) bu
helper'ı çağırır.

### `IconTheme`

**Kaynak modül:** `kvs_tema/src/icon_theme.rs`.

Tema sistemi yalnızca UI renklerini değil, **icon tema sözleşmesini** de
mirror eder; bu Konu 2'deki temel ilkenin parçasıdır. `IconTheme`, Zed'in
`crates/theme/src/icon_theme.rs` dosyasındaki yapıyla alan paritesi korunarak
yazılır.

**Runtime sözleşmesi:**

```rust
use std::sync::Arc;
use collections::HashMap;
use gpui::SharedString;

pub struct IconTheme {
    pub id: String,
    pub name: SharedString,
    pub appearance: Appearance,
    pub directory_icons: DirectoryIcons,
    pub named_directory_icons: HashMap<String, DirectoryIcons>,
    pub chevron_icons: ChevronIcons,
    pub file_stems: HashMap<String, String>,     // "Cargo.toml" → "icon-id"
    pub file_suffixes: HashMap<String, String>,  // "rs" → "icon-id"
    pub file_icons: HashMap<String, IconDefinition>,
}

pub struct DirectoryIcons {
    pub collapsed: Option<SharedString>,         // SVG/PNG yolu
    pub expanded: Option<SharedString>,
}

pub struct ChevronIcons {
    pub collapsed: Option<SharedString>,
    pub expanded: Option<SharedString>,
}

pub struct IconDefinition {
    pub path: SharedString,                       // asset altındaki dosya yolu
}

pub struct IconThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<IconTheme>,
}
```

> **Uyarı:** Alan listesi Zed icon theme sözleşmesini takip eder. Icon theme
> sözleşmesi UI renk sözleşmesinden daha hızlı değişebilir. Bu yüzden runtime
> tipinde alan paritesini korumak özellikle önemlidir.

**JSON Content sözleşmesi:**

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct IconThemeFamilyContent {
    pub name: String,
    pub author: String,
    pub themes: Vec<IconThemeContent>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct IconThemeContent {
    pub name: String,
    pub appearance: AppearanceContent,
    #[serde(default)]
    pub directory_icons: DirectoryIconsContent,
    #[serde(default)]
    pub named_directory_icons: HashMap<String, DirectoryIconsContent>,
    #[serde(default)]
    pub chevron_icons: ChevronIconsContent,
    #[serde(default)]
    pub file_stems: HashMap<String, String>,
    #[serde(default)]
    pub file_suffixes: HashMap<String, String>,
    #[serde(default)]
    pub file_icons: HashMap<String, IconDefinitionContent>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct DirectoryIconsContent {
    pub collapsed: Option<String>,
    pub expanded: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct ChevronIconsContent {
    pub collapsed: Option<String>,
    pub expanded: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct IconDefinitionContent {
    pub path: String,
}
```

`*Content` tiplerinin opsiyonellik felsefesi UI temasıyla aynıdır (Konu
20): her alan ya `Option` taşır ya da `#[serde(default)]` ile boş bırakma
hakkı tanır.

**Content → Runtime akışı:**

```rust
impl IconTheme {
    pub fn from_content(c: IconThemeContent) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name: SharedString::from(c.name),
            appearance: match c.appearance {
                AppearanceContent::Light => Appearance::Light,
                AppearanceContent::Dark => Appearance::Dark,
            },
            directory_icons: DirectoryIcons {
                collapsed: c.directory_icons.collapsed.map(SharedString::from),
                expanded: c.directory_icons.expanded.map(SharedString::from),
            },
            named_directory_icons: c.named_directory_icons.into_iter()
                .map(|(k, v)| (k, DirectoryIcons {
                    collapsed: v.collapsed.map(SharedString::from),
                    expanded: v.expanded.map(SharedString::from),
                }))
                .collect(),
            chevron_icons: ChevronIcons {
                collapsed: c.chevron_icons.collapsed.map(SharedString::from),
                expanded: c.chevron_icons.expanded.map(SharedString::from),
            },
            file_stems: c.file_stems,
            file_suffixes: c.file_suffixes,
            file_icons: c.file_icons.into_iter()
                .map(|(k, v)| (k, IconDefinition { path: v.path.into() }))
                .collect(),
        }
    }
}
```

UI temasından farklı olarak burada **refinement katmanı yoktur**. Yani
`Refineable` türevli alan-bazlı tema override hattı icon tema için çalışmaz.
Buna rağmen Zed'in yükleme ve lookup davranışı "tam replacement" da değildir.
`ThemeRegistry::load_icon_theme`, kullanıcı temasının `file_stems`,
`file_suffixes` ve `named_directory_icons` haritalarını default icon theme'in
üstüne genişletir. `directory_icons`, `chevron_icons` ve `file_icons`
alanları runtime objesine kullanıcının verdiği biçimde girer. Lookup sırasında
ise eksik dosya tipi, klasör ve chevron path'leri aktif temadan default icon
theme'e düşebilir. Mirror tarafta bu iki aşama ayrı düşünülmelidir:
schema/refinement yoktur, ama registry yükleme ve UI lookup fallback'i vardır.

**Rol:** Dosya, dizin ve chevron icon'larının **kaynağını** tutar. UI yalnızca
icon id'sini bilir; asıl SVG/PNG asset registry'sinden gelir.

**Tema sözleşmesindeki yeri:** Icon tema, UI tema (`Theme`) ile **kardeş**
bir kavramdır — `Theme.styles` içine **girmez**. Zed'e uyumlu runtime'da
ikisi aynı `ThemeRegistry` içinde farklı map'lerde tutulur:

```rust
struct ThemeRegistryState {
    themes: HashMap<SharedString, Arc<Theme>>,
    icon_themes: HashMap<SharedString, Arc<IconTheme>>,
    extensions_loaded: bool,
}

impl ThemeRegistry {
    pub fn insert_icon_theme(&self, icon_theme: IconTheme) { /* ... */ }
    pub fn get_icon_theme(&self, name: &str) -> Result<Arc<IconTheme>, IconThemeNotFoundError> { /* ... */ }
    pub fn list_icon_themes(&self) -> Vec<ThemeMeta> { /* ... */ }
    pub fn load_icon_theme(&self, family: IconThemeFamilyContent, icons_root: &Path) -> anyhow::Result<()> { /* ... */ }
}
```

Aktif icon tema, ayrı bir `GlobalIconTheme` yerine `GlobalTheme` içinde
tutulur (Konu 34). Bu seçim, tema değişimi ile icon tema değişimini aynı
refresh modeline bağlar: settings değişir → uygun `Theme` ve `IconTheme`
registry'den çözülür → `GlobalTheme::update_theme` ve `update_icon_theme`
çağrıları yapılır → `cx.refresh_windows()` ile ekran yenilenir.

**JSON şeması:**

```json
{
  "name": "Material Icons",
  "author": "Material team",
  "themes": [{
    "name": "Material",
    "appearance": "dark",
    "directory_icons": {
      "collapsed": "icons/folder-closed.svg",
      "expanded":  "icons/folder-open.svg"
    },
    "named_directory_icons": {
      ".github": {
        "collapsed": "icons/folder-github.svg",
        "expanded":  "icons/folder-github-open.svg"
      }
    },
    "chevron_icons": {
      "collapsed": "icons/chevron-right.svg",
      "expanded":  "icons/chevron-down.svg"
    },
    "file_stems": { "Cargo.toml": "rust-cargo", "package.json": "npm" },
    "file_suffixes": { "rs": "rust", "ts": "typescript", "md": "markdown" },
    "file_icons": {
      "rust":       { "path": "icons/rust.svg" },
      "typescript": { "path": "icons/typescript.svg" },
      "markdown":   { "path": "icons/markdown.svg" }
    }
  }]
}
```

**Lookup mantığı (Zed `file_icons` crate paritesi —
`crates/file_icons/src/file_icons.rs`):**

```rust
pub fn icon_for_type(typ: &str, active: &IconTheme, default: &IconTheme) -> Option<&str> {
    active
        .file_icons
        .get(typ)
        .or_else(|| default.file_icons.get(typ))
        .map(|d| d.path.as_ref())
}

pub fn get_icon(path: &Path, active: &IconTheme, default: &IconTheme) -> Option<SharedString> {
    let resolve = |suffix: &str| -> Option<SharedString> {
        active
            .file_stems
            .get(suffix)
            .or_else(|| active.file_suffixes.get(suffix))
            .and_then(|typ| icon_for_type(typ, active, default).map(SharedString::from))
    };

    // 1. Tam dosya adı: "eslint.config.js" gibi full match
    if let Some(mut typ) = path.file_name().and_then(|n| n.to_str()) {
        if let Some(p) = resolve(typ) { return Some(p); }

        // 2. Nokta ile bölünen suffix'leri sırayla dene:
        //    "auth.module.js" → "module.js" → "js"
        while let Some((_, suffix)) = typ.split_once('.') {
            if let Some(p) = resolve(suffix) { return Some(p); }
            typ = suffix;
        }
    }

    // 3. Multi-extension: "Component.stories.tsx" gibi alternatif suffix
    if let Some(suffix) = path.multiple_extensions() {
        if let Some(p) = resolve(suffix.as_str()) { return Some(p); }
    }

    // 4. Normal extension veya hidden file adı (`.gitignore`)
    if let Some(suffix) = path.extension_or_hidden_file_name() {
        if let Some(p) = resolve(suffix) { return Some(p); }
    }

    // 5. Sadece normal extension: ".data.json" → "json"
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        if let Some(p) = resolve(ext) { return Some(p); }
    }

    // 6. "default" tipine düş (her icon theme'de bulunmalı)
    icon_for_type("default", active, default).map(SharedString::from)
}
```

Yani **lookup zinciri 6 katmanlıdır**: tam ad → dot-suffix loop →
`multiple_extensions` → `extension_or_hidden_file_name` → ham `extension`
→ `"default"` tipi. Her katmanda önce aktif tema'nın
`file_stems`/`file_suffixes` haritası, sonra `file_icons` araması ile
aktif → default fallback gerçekleştirilir. Klasör ve chevron icon'larında
ayrıca **3 katman** vardır: `named_directory_icons` (klasör adına özel) →
`directory_icons` (jenerik) → her ikisinde de aktif → default fallback. Bu
akış expanded/collapsed slot ayrımını da korur.

Public method yüzeyi gerçek adlarıyla şudur: `FileIcons::get(cx)`,
`FileIcons::get_icon(path, cx)`,
`FileIcons::get_icon_for_type(typ, cx)`,
`FileIcons::get_folder_icon(expanded, path, cx)` ve
`FileIcons::get_chevron_icon(expanded, cx)`. Generic folder fallback'ini
sağlayan `get_generic_folder_icon` ise private bir helper'dır; portta dış
API olarak açılması doğru olmaz.

**Asset yükleme:** Icon path'leri (örn. `icons/rust.svg`) `AssetSource`
katmanından çözülür (Konu 26). `IconTheme` yalnızca path'i tutar; SVG parse'ı
GPUI'nin `svg()` element çağrısında gerçekleşir.

**Bundling akışı (Konu 26'ün parça-paralel akışı):**

```rust
pub fn load_bundled_icon_themes(
    registry: &ThemeRegistry,
) -> anyhow::Result<()> {
    for path in EmbeddedAssets::iter()
        .filter(|p| p.starts_with("icon_themes/") && p.ends_with(".json"))
    {
        let file = EmbeddedAssets::get(&path)
            .ok_or_else(|| anyhow::anyhow!("asset missing: {}", path))?;
        let family: IconThemeFamilyContent =
            serde_json_lenient::from_slice(&file.data)?;
        registry.load_icon_theme(family, Path::new("icon_themes/"))?;
    }
    Ok(())
}
```

**`kvs_tema::init` ile entegrasyon:**

`init`, UI tema registry'sinin yanı sıra icon tema registry'sini de
kurabilir. Bu adım opsiyoneldir — uygulama icon teması kullanmıyorsa
atlanabilir:

```rust
pub fn init(cx: &mut App) {
    SystemAppearance::init(cx);

    // UI tema registry (Konu 36)
    let theme_registry = Arc::new(ThemeRegistry::new(Box::new(()) as Box<dyn AssetSource>));
    theme_registry.insert_themes([
        fallback::kvs_default_dark(),
        fallback::kvs_default_light(),
    ]);
    // set_global Zed'de pub(crate); kvs_tema'da mirror'da public yapmak
    // mümkün ama init helper kullanmak daha tutarlı (Konu 36).
    kvs_tema::init(LoadThemes::JustBase, cx);

    let theme_registry = ThemeRegistry::global(cx);
    let active_theme = theme_registry
        .get("Kvs Default Dark")
        .expect("default tema kayıtlı olmalı");
    let active_icon_theme = theme_registry
        .default_icon_theme()
        .expect("default icon tema kayıtlı olmalı");

    cx.set_global(GlobalTheme::new(active_theme, active_icon_theme));
}
```

### Tuzaklar

1. **`ThemeFamily.id` kullanılmıyorsa**: Registry yalnızca `Theme`'leri
   isim üzerinden indeksler. `ThemeFamily.id` runtime'da neredeyse hiç
   sorgulanmaz — saklanması daha çok debug ve isimlendirme amacıyla
   anlamlıdır. Ekstra metadata için ihtiyaç duyulmuyorsa atlanması da
   mümkündür, ancak Zed paritesini koruma adına tutulmasında fayda
   vardır.
2. **`SyntaxTheme::new()`'nun `Arc` döndüğünü varsaymak**: Zed sözleşmesi
   `Self` döndürür; `Arc` sözleşmesi caller tarafında kurulur
   (`Arc::new(SyntaxTheme::new(...))`).
3. **`SyntaxTheme.highlights` alanına dışarıdan erişmeye çalışmak**: Bu
   alan private'tır; tüketici yalnızca `style_for_name`, `get`,
   `get_capture_name` ve `highlight_id` üzerinden okur.
   `IndexMap`/`HashMap` tartışması tarihseldir: gerçek implementasyon iki
   ayrı yapıyı bir arada kullanır (`Vec<HighlightStyle>` ve
   `BTreeMap<String, usize>`).
4. **`IconTheme` ile `Theme` arasında bağ kurmak**: İki sözleşme ayrıdır.
   Birbirine bağlama denemesi (`Theme.icon: IconTheme` gibi) sync
   disiplinini bozar — Zed ikisini ayrı tutar ve aynı yaklaşımın mirror
   tarafta da korunması beklenir.
5. **`IconTheme` mirror'unun ertelenmesi**: "Henüz icon tema
   kullanmıyorum" geçerli bir dışlama sebebi olarak kabul edilmez (Konu 2).
   Struct'ın tanımlanması ve runtime implementasyonunun
   `unimplemented!()` placeholder ile sonraya bırakılması yeterli bir
   yaklaşımdır.

---
