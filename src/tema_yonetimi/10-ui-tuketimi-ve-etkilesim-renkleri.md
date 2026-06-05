# UI tüketimi ve etkileşim renkleri

Bileşen tarafında tema okuma yolu `cx.theme()` çağrısıdır. Hover, basılı, devre dışı ve seçili gibi durumlar da tema alanlarından beslenir. Bu bölüm, bileşenlerin tema değerlerine nasıl ulaştığını ve etkileşim durumlarında hangi alanları kullanması gerektiğini anlatır.

![UI Tema Tüketim Akışı](assets/ui-tema-tuketim-akisi.svg)

---

## 41. `cx.theme()` ile bileşen renklendirme

**Tüketici sözleşmesi:** UI bileşenleri tema değerlerine `cx.theme()` çağrısı üzerinden erişir. Bu çağrı `&Arc<Theme>` döndürür; klon ve bellek ayırma üretmeden okuma yaparsın.

### Temel kalıp

```rust
use gpui::{div, prelude::*, App, Window, Context};
use kvs_tema::ActiveTheme;

struct AnaPanel;

impl Render for AnaPanel {
    fn render(
        &mut self,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let tema = cx.theme();
        div()
            .bg(tema.colors().background)
            .text_color(tema.colors().text)
            .border_1()
            .border_color(tema.colors().border)
            .p_4()
            .child("Merhaba")
    }
}
```

**Üç gereklilik:**

1. **`use kvs_tema::ActiveTheme;`** — trait import edilmediği takdirde `cx.theme()` çağrısı "method not found" hatasıyla karşılaşır.
2. **`let tema = cx.theme();`** — `&Arc<Theme>` döndürdüğü için `&self` borrow gibi davranır; render içinde tek seferlik bağlamayla yetinilir.
3. **Alan erişimi** — `styles` crate-içi olduğundan, tüketici `tema.colors().background` gibi accessor'lar üzerinden okur.

### Erişim yolları kıyaslaması

```rust
// Accessor metotları (dış crate için zorunlu yol)
let arka_plan = tema.colors().background;
let soluk_metin = tema.colors().text_muted;
let hata = tema.status().error;
let yerel_imlec = tema.players().local().cursor;
```

**Accessor metotları neden tercih edilir?** `styles` alanı tema modelinin iç yerleşimidir; tüketici bileşenlerin bu iç yerleşime bağlanması istenmez. Accessor yöntemi, mevcut Zed sözleşmesinde okunacak alanı `theme.colors()` gibi açık bir kapıdan verir ve UI kodunu daha anlaşılır tutar.

### Çalışma zamanı renk ailelerini UI'da tüketme

`ThemeStyles`, `ThemeColors`, `StatusColors`, `PlayerColors`, `AccentColors`, `SystemColors` ve `SyntaxTheme` çalışma zamanı veri modelinin parçalarıdır; UI tarafında çoğunlukla bu tipleri doğrudan kurmazsın, aktif `Theme` üzerinden okursun. Bu ayrım önemlidir: bileşen kodu tema üreticisi değildir, tema tüketicisidir.

| Çalışma zamanı tipi | UI'daki erişim yolu | Kullanım |
| -------------- | --------------------- | ---------- |
| `ThemeStyles` | Doğrudan okunmaz; `Theme` accessor'ları üzerinden parçalanır. | Tema iç yapısını bir arada tutan kap. |
| `ThemeColors` | `cx.theme().colors()` | Yüzey, metin, icon, border, editor, terminal ve etkileşim renkleri. |
| `StatusColors` | `cx.theme().status()` | Hata, uyarı, bilgi, başarı, git/diff ve benzeri durum renkleri. |
| `PlayerColors` | `cx.theme().players()` | Collab cursor, selection, agent/remote participant ve Mermaid/git graph gibi döngüsel renkler. |
| `AccentColors` | `cx.theme().accents()` | İndent guide, rainbow bracket, grafik dilimi gibi index bazlı vurgu renkleri. |
| `SystemColors` | `cx.theme().system()` | `transparent` ve platform kromu için macOS traffic light renkleri. |
| `SyntaxTheme` | `cx.theme().syntax()` | Tree-sitter capture adlarından `HighlightStyle` çözme. |

`ThemeColorField` ve `all_theme_colors(cx)` normal bileşen render'ı için değil, tema editörü, color picker, debug inspector ve snapshot ekranı için düşünülür. `ThemeColorField` `ThemeColors` alanlarının reflection alt kümesini isimlendirir; `all_theme_colors(cx)` aktif temadan bu alanları `(Hsla, SharedString)` listesi olarak verir. Bir buton arka planı çizeceksen `all_theme_colors` dolaşmazsın; doğrudan `theme.colors().element_background` okursun.

```rust
let tema = cx.theme();
let renkler = tema.colors();
let durum = tema.status();
let oyuncular = tema.players();

let hata_rengi = durum.diagnostic().error;
let yerel_secim = oyuncular.local().selection;
let katilimci = oyuncular.color_for_participant(katilimci_indeksi);
let salt_okunur = oyuncular.read_only();
let yok_katilimci = oyuncular.absent();
```

`StatusColors::diagnostic()` yalnızca üçlü bir `DiagnosticColors` görünümü üretir: `error`, `warning` ve `info`. Diagnostic panel, satır içi hata şeridi veya durum rozeti bu üç alanı okuyabilir; ama `created`, `deleted`, `modified` gibi VCS renkleri bu helper'da yoktur. Onlar için doğrudan `theme.status().created` gibi alan okursun.

`PlayerColor` tek katılımcının `cursor`, `background` ve `selection` üçlüsüdür. `PlayerColors::color_for_participant(index)` local oyuncuyu atlayıp remote katılımcılar arasında modulo ile döner; bu yüzden collab katılımcı rengi seçerken kullanılır. `PlayerColors::read_only()` local rengi grayscale'e çeker; salt-okunur veya pasif kullanıcı göstergesinde işe yarar. `PlayerColors::absent()` ise son renk slot'unu döndürür ve bulunmayan/ayrılmış katılımcı durumunda kullanılır. Liste boşsa bu helper'ların güvenli çalışması beklenmez; fallback tema en az bir player rengi sağlamalıdır.

`AccentColors::color_for_index(index)` index'i accent listesine modulo ile sarar. Bu API, sınırsız sayıda indent guide veya Mermaid pie dilimi gibi tekrar eden görsel slotlarda kullanışlıdır. `default_color_scales()` ise `ColorScales` ailesinin built-in palet matrisini üretir; sıradan UI bileşeni bunu çağırmaz. Fallback tema veya tema editörü, scale tabanlı palette preview üretirken bu fonksiyona ihtiyaç duyar.

`SystemColors::transparent` özel bir `Hsla` değeridir ve şeffaf border/background placeholder'larında kullanılır. macOS traffic light alanları ise titlebar/pencere kromu içindir; form bileşenlerinde status rengi gibi kullanılmaz.

### Prelude modül deseni

`kvs_tema` her render dosyasında üç ayrı import gerektirebilir:

```rust
use kvs_tema::ActiveTheme;
use kvs_tema::Theme;
use kvs_tema::Appearance;
```

Prelude modülü bu üç import'u tek satıra indirir:

```rust
pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily};
pub use crate::styles::*;
```

Tüketici tarafından kullanım:

```rust
use kvs_tema::prelude::*;
```

> **`gpui::prelude` ile çakışma:** GPUI'nin `prelude::*` modülü `Render` trait'ini ve fluent API trait'lerini taşır. `kvs_tema::prelude::*` yanına eklendiğinde iki ayrı `use` satırı tercih edilir:
> ```rust
> use gpui::{prelude::*, div, App, Window, Context};
> use kvs_tema::prelude::*;
> ```

### Durumsuz okuma ile cache'li değer karşılaştırması

```rust
// (A) Durumsuz — her render'da tema okur
impl Render for DurumsuzPanel {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div().bg(cx.theme().colors().background)
    }
}

// (B) Cache'li — durum alanında tutar
struct CacheliPanel {
    arka_plan: Hsla,
}
impl CacheliPanel {
    fn new(cx: &mut Context<Self>) -> Self {
        Self { arka_plan: cx.theme().colors().background }
    }
}
impl Render for CacheliPanel {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div().bg(self.arka_plan)  // ← tema değişirse güncellenmez!
    }
}
```

**Genel tercih (A), yani durumsuz yaklaşımdır.** `cx.refresh_windows()` view'ı yeniden çağırır ve tema yeni değerlerle okunur. (B) yaklaşımı tema değişimine **kapalı** kalır; eski rengi tutmaya devam eder ve tema değişimiyle uyumsuz kalır.

İstisna: render içinde **hesaplanmış bir değer** (örneğin `arka_plan.opacity(0.5)`) başarım için cache edilebilir. Ancak `cx.theme()` zaten bellek ayırma üretmediği için bu seviyede cache çoğu zaman gereksizdir.

### Birden fazla alan okuma

`cx.theme()` çağrısının **bir kez** yapılıp, türeyenlerin lokal olarak bind edilmesi okunabilirliği artırır:

```rust
// Tercih edilen
let tema = cx.theme();
let renkler = tema.colors();
let durum = tema.status();

div()
    .bg(renkler.background)
    .text_color(renkler.text)
    .border_color(if hata_var_mi { durum.error } else { renkler.border })

// Tekrarlı okuma (her çağrı `cx.global` lookup yapar)
div()
    .bg(cx.theme().colors().background)
    .text_color(cx.theme().colors().text)
    .border_color(if hata_var_mi {
        cx.theme().status().error
    } else {
        cx.theme().colors().border
    })
```

Tekrarın maliyeti pratikte düşüktür (`cx.global` bir HashMap lookup'u yapar). Yine de okunabilirlik için tek bir bağlama yeterlidir.

### Bileşen tasarım deseni

UI bileşenleri için **tema okuma sözleşmesi**:

```rust
use kvs_tema::prelude::*;

struct Buton {
    etiket: SharedString,
    tiklandiginda: Box<dyn Fn(&mut Window, &mut App)>,
}

impl Render for Buton {
    fn render(
        &mut self,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let renkler = cx.theme().colors();

        div()
            .px_3()
            .py_2()
            .bg(renkler.element_background)
            .text_color(renkler.text)
            .rounded_md()
            .border_1()
            .border_color(renkler.border)
            .child(self.etiket.clone())
    }
}
```

**Sözleşme noktaları:**

- Bileşen tema değerini kendi içinde okur; üst bileşenden renk parametresi almaz.
- Bileşen `Theme` tipini import etmez; yalnızca `ActiveTheme` trait'ini (prelude ile) kullanır.
- Bileşen durum alanında `Hsla` tutmaz — her render'da temayı taze olarak okur.

### Dikkat Noktaları

1. **`use kvs_tema::ActiveTheme;` import'u**: Trait kapsamda olmadığında `cx.theme()` için "method not found" hatası alınır. Prelude kullanımı bu import gereksinimini pratikte görünmez kılar.
2. **`cx.theme().clone()` çağrısı**: `&Arc<Theme>` zaten ucuz bir referanstır; `.clone()` refcount artırır ancak çoğu durumda referans yeterlidir. Gereksiz bir maliyet doğurur.
3. **Bileşen durum alanında rengin cache'lenmesi**: Tema değişiminde eski kalır. Durumsuz okuma tercih edersin.
4. **`tema.styles.colors.X` zinciri**: Dış crate'ten erişildiğinde compile hatası verir. Accessor (`theme.colors()`) tek doğru yoldur.
5. **Render dışında `cx.theme()` çağrısı**: `&mut Context<Self>` `App`'ten `cx.theme()` çağrısına izin verir; ancak render fazı dışındaki kullanım çoğu durumda cache veya state kararını yeniden düşünmeyi gerektirir. Bileşen durum alanında renk tuttuğunda tema değişiminde yeniden okunmaz; çağrıyı render fazıyla sınırlandırman daha sağlamdır.
6. **`Context<T>` yerine `&Window` ile erişim denemek**: `Window` üzerinden `cx.theme()` yapılamaz; `Window` `App`'e deref etmez. Render imzası `(&mut Window, &mut Context<Self>)` biçimindedir — iki parametre birbirinden ayrıdır.

### `Theme::darken` ile appearance-aware koyulaştırma

Zed'in `Theme::darken(color, light_amount, dark_amount)` (`theme`) yardımcısı, bir rengi appearance'a göre **lightness** azaltarak koyulaştırır. Light tema modunda `light_amount`, dark tema modunda `dark_amount` kullanırsın. Sonuç `l = (l - amount).max(0.0)` ile alt sınırlanır. Aynı bileşenin iki temada da yeterli kontrastı koruması için iki ayrı miktar verirsin.

```rust
use kvs_tema::ActiveTheme;

impl Render for VurguCipi {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let tema = cx.theme();
        // Hover'da arka planı light'ta 0.06, dark'ta 0.04 koyulaştır.
        let hover_arka_plan = tema.darken(tema.colors().element_background, 0.06, 0.04);
        div()
            .bg(tema.colors().element_background)
            .hover(|s| s.bg(hover_arka_plan))
            .text_color(tema.colors().text)
    }
}
```

**Sınırlar:** `darken` yalnızca lightness değerini etkiler; alpha, saturation ve hue olduğu gibi kalır. Şeffaf renkler yine şeffaftır. Mirror tarafta aynı imzanın korunması parite açısından önemlidir. Daha gelişmiş bir varyant (`OkLab` veya `palette::Mix`) yerel API genişletmesi olarak ele alırsın.

### Markdown önizleme, code fontu ve Mermaid tema tüketimi

Markdown önizleme hattı, tema tüketicisi olarak şu alanları kullanır:

- Düz markdown metni önizleme modunda `markdown_preview_font_family()` ile okunur; bu alan set edilmemişse `ui_font.family` kullanırsın.
- Inline code ve code block'lar yeni `markdown_preview_code_font_family()` accessor'ını kullanır; set edilmediğinde `buffer_font.family` değerine düşer. Bu nedenle settings mirror'ında `markdown_preview_font_family` ile `markdown_preview_code_font_family` ayrı alanlar olarak tutulur. `MarkdownStyle::default` constructor'ı code block ve inline code TextStyleRefinement'ında bu accessor'dan dönen değeri kullanır; `is_preview` bayrağı `false` ise (örn. agent panel anlatımı) doğrudan `buffer_font.family` okunur, böylece markdown önizleme ile uygulama içi markdown render aynı yardımcı imzasını paylaşır.
- Mermaid render hattı aktif tema renklerinden kendi renderer temasını üretir. Renkler renderer'a `#rrggbb` CSS hex olarak verilir; alpha kanalı taşınmaz, o yüzden şeffaflık gerekiyorsa renk önce tema tarafında uygun zemine blend edilmelidir. Hangi `ThemeColors` slot'unun hangi Mermaid alanına gittiğini şu tablo gösterir:

| MermaidTheme alanı | Tema kaynağı |
| --------------- | ---------- |
| `background`, `edge_label_background` | `colors.editor_background` |
| `primary_color`, `note_background`, `er_attr_bg_odd` | `colors.surface_background` |
| `primary_text_color`, `text_color` | `colors.text` |
| `primary_border_color`, `line_color`, `actor_border`, `activation_border` | `colors.border` |
| `secondary_color`, `actor_background`, `er_attr_bg_even` | `colors.element_background` |
| `tertiary_color`, `activation_background` | `colors.ghost_element_hover` |
| `cluster_background` | `colors.panel_background` |
| `cluster_border`, `note_border` | `colors.border_variant` |
| `error_color`, `warning_color` | `theme.status().error`, `theme.status().warning` |
| `git_branch_colors` | `theme.players().0[i % len].cursor` |
| `git_branch_label_colors` | `mermaid_render::text_color_for_background(git_branch_color)` |
| `accent_colors` | Her player slot'u için `{ foreground: cursor, background }` |

- Mermaid fontu `ThemeSettings::ui_font.family` üzerinden gelir ve GPUI'nin font fallback çözümlemesinden geçirilir. Sanal Zed font adları burada normalize edilir: `.ZedSans` ve `Zed Plex Sans` `IBM Plex Sans`, `.ZedMono` `Lilex`, `.SystemUIFont` ise `system-ui` olarak çözülür. Tanımsız bir ad gelirse renderer'a olduğu gibi geçer.
- Mermaid postprocess katmanı player renklerinden `zed-accent-0..N` sınıfları üretir. Fill rengi player `background` değerinin Mermaid arka planı üstüne `0.15` opacity ile blend edilmesiyle, stroke ise player `cursor` değeriyle oluşturulur. Metin rengi `mermaid_render::text_color_for_background` üzerinden OKLCH tabanlı seçilir: arka plan chroma'sının yaklaşık %15'i korunur, hedef kontrast en az `4.5:1` olur; gerekirse chroma binary search ile düşürülür ve son çare olarak siyah/beyaz fallback kullanılır.
- Mermaid kaynağı yazılırken `%%{init}%%`, elle `classDef` ve temadan bağımsız hex renkler kullanılmaz. Vurgu sınıfları kaynak metinden değil renderer postprocess adımından gelir; bu yüzden kullanıcı kaynağında aynı sınıf adlarının yeniden tanımlanması tema renkleriyle çakışan bir sonuç üretir. Yalnızca birebir marka/ürün rengi gerekiyorsa sabit kodlu renk kabul edilir.
- Diyagramın render edilebilmesi için fenced code block'un **kapanmış olması** gerekir (`metadata.is_fenced_closed`). Açık (henüz kapanmamış) bir blok parse sırasında dahil edilmez; bu sayede yarı yazılmış markdown önizleme akışında erken hata üretilmez.
- İki kaynak türü desteklenir. İlk tür klasik `~~~mermaid` etiketli fenced blok'tur; `mermaid` etiketinden sonra opsiyonel sayı `scale` olarak parse edilir (`mermaid 200` → %200) ve `10..=500` aralığına sıkıştırılır. İkinci tür `~~~src` ile başlayan ve `.mermaid` veya `.mmd` uzantılı bir dosyaya işaret eden `FencedSrc` blok'tur; bu durumda scale sabit `100` kabul edilir. Diğer uzantılar bu yola girmez.
- Render başarılı olduğunda blok `Preview | Code` sekme başlığıyla birlikte çizilir; varsayılan sekme görsel önizleme, `Code` sekmesi ise diyagramın kaynağıdır. Hangi blok'un hangi sekmede olduğu `Markdown.mermaid_showing_code: HashSet<usize>` içinde tutulur; her offset için `toggle_mermaid_tab(offset)` çağrısı aynı kümeyi flip eder. Render başarısız olur veya cache henüz hazır değilse sekme başlığı çizilmez ve kullanıcıya doğrudan kaynak gösterilir. Render bekleme satırı `top-1 right-2` köşesinde `"Rendering..."` etiketiyle pulsing animasyon olarak çıkar.
- Mermaid bloklarında sekme başlığı ve kopya butonu görünürlüğü `copy_button_visibility` üzerinden kontrol edilir. `MarkdownElement` `CodeBlockRenderer::Default { copy_button_visibility, .. }` taşıyorsa Mermaid blok'u bu değeri okur; `CopyButtonVisibility::Hidden` seçildiğinde sekme başlığı ve kopya butonu çizilmez. `wrap_button_visibility` normal code block renderer sözleşmesinin alanıdır; Mermaid render fonksiyonu bu alanı kullanmaz, ancak `CodeBlockRenderer::Default` struct literal'i yazarken alanın sağlanması gerekir.
- Mermaid SVG çıktısı blok başına bir kez render edilip `MermaidState::cache` içinde tutulur. Tema veya `ThemeSettings` değiştiğinde cache geçersizleştirilmelidir; aksi takdirde markdown preview önceki tema renkleriyle kalır. Bunun için `Markdown::invalidate_mermaid_cache(&mut Context<Self>)` public metodu eklersin. Metot `options.render_mermaid_diagrams` açıkken `mermaid_state.clear()` çağırır, parsed markdown'u yeniden render kuyruğuna atar ve `cx.notify()` ile yeniden çizim tetikler. Agent panel gibi tema değişimini observe eden tüketiciler bu çağrıyı `cx.observe_window_appearance` veya tema observer'ına bağlar. `MarkdownOptions { render_mermaid_diagrams: true, ..Default::default() }` bayrağı kapatıldığında ise hem cache hem `mermaid_showing_code` kümesi tamamen boşaltılır.

Editor completion menüsündeki `completion_menu_item_kind = "symbol"` ayarı da syntax theme'i editor metni dışında tüketir. Ayar `off` iken rozet yoktur; `symbol` iken her completion için tek harflik bir rozet çizilir ve varsa syntax capture rengiyle boyanır. Noktalı capture adlarında tam ad bulunamazsa parent capture denenir (`function.method` → `function`). Capture yoksa veya capture'ın `color` alanı boşsa rozet yine çizilir, ancak özel renklendirme yapılmaz.

| LSP kind | Rozet | Syntax capture |
| ---------- | ------- | ---------------- |
| `TEXT` | `t` | — |
| `METHOD` | `m` | `function.method` |
| `FUNCTION` | `f` | `function` |
| `CONSTRUCTOR` | `C` | `constructor` |
| `FIELD` | `f` | `property` |
| `VARIABLE` | `v` | `variable` |
| `CLASS` | `c` | `type` |
| `INTERFACE` | `i` | `type` |
| `MODULE` | `M` | `namespace` |
| `PROPERTY` | `p` | `property` |
| `UNIT` | `u` | — |
| `VALUE` | `v` | — |
| `ENUM` | `e` | `enum` |
| `KEYWORD` | `k` | `keyword` |
| `SNIPPET` | `s` | `string` |
| `COLOR` | `c` | — |
| `FILE` | `F` | — |
| `REFERENCE` | `r` | — |
| `FOLDER` | `D` | — |
| `ENUM_MEMBER` | `e` | `variant` |
| `CONSTANT` | `c` | `constant` |
| `STRUCT` | `S` | `type` |
| `EVENT` | `E` | — |
| `OPERATOR` | `o` | `operator` |
| `TYPE_PARAMETER` | `T` | `type` |

---

## 42. Hover / active / disabled / selected / ghost desenleri

GPUI'nin fluent API'si etkileşim durumları için `.hover()`, `.active()` ve `Interactivity` katmanını sağlar. Tema tarafında her durum için **özel alanlar** vardır. Bu alanların nasıl eşleneceği sözleşmenin parçasıdır.

### Etkileşim alanları eşlemesi

```text
ThemeColors:
├── element_background    ← varsayılan
├── element_hover         ← .hover(|s| s.bg(...))
├── element_active        ← .active(|s| s.bg(...))
├── element_selected      ← seçili durum (uygulama mantığı)
├── element_selection_background  ← metin seçim arka planı
├── element_disabled      ← devre dışı durum
│
├── ghost_element_background  ← transparan varyant
├── ghost_element_hover
├── ghost_element_active
├── ghost_element_selected
└── ghost_element_disabled
```

### Temel etkileşim deseni

```rust
use gpui::{div, prelude::*};
use kvs_tema::prelude::*;

impl Render for EtkilesimliButon {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let renkler = cx.theme().colors();

        div()
            .id("buton")                            // ← Interactivity için ID şart
            .px_3()
            .py_2()
            .bg(renkler.element_background)
            .text_color(renkler.text)
            .rounded_md()
            .hover(|s| s.bg(renkler.element_hover))
            .active(|s| s.bg(renkler.element_active))
            .child("Tıkla")
    }
}
```

**Önemli noktalar:**

- `.id(...)` çağrısı **şarttır** — Interactivity (hover/active/click) bileşeni stateful bir yapıdadır ve ID olmadan GPUI durumu tanıyamaz.
- `.hover(|s| ...)` ve `.active(|s| ...)` çağrıları bir `StyleRefinement` callback'i alır. Bu refinement element üzerine layer'lanır.

### Hover varyantları

```rust
// 1. Tek alan değişimi
div().bg(renkler.element_background)
    .hover(|s| s.bg(renkler.element_hover))

// 2. Hover'da border ekleme
div().border_1().border_color(renkler.border)
    .hover(|s| s.border_color(renkler.border_focused))

// 3. Hover'da metin rengi değişimi
div().text_color(renkler.text_muted)
    .hover(|s| s.text_color(renkler.text))
```

### Active (basılı) durum

```rust
div()
    .bg(renkler.element_background)
    .hover(|s| s.bg(renkler.element_hover))
    .active(|s| s.bg(renkler.element_active))
```

**Sıralama önemlidir:** GPUI önce hover'ı uygular, ardından active'i yerleştirir. Active'de verilen alan hover'ın üstüne yazılır. Active durum, mouse button basılıyken etkin olur.

### Disabled durum

GPUI doğrudan bir `.disabled(|s| ...)` callback'i sunmaz; devre dışı mantığı uygulama tarafında yönetilir:

```rust
let arka_plan = if self.devre_disi_mi {
    renkler.element_disabled
} else {
    renkler.element_background
};

let metin = if self.devre_disi_mi {
    renkler.text_disabled
} else {
    renkler.text
};

div()
    .id("buton")
    .bg(arka_plan)
    .text_color(metin)
    .when(!self.devre_disi_mi, |oge| {
        oge.hover(|s| s.bg(renkler.element_hover))
            .active(|s| s.bg(renkler.element_active))
            .on_click(/* ... */)
    })
```

`.when(kosul, |oge| ...)` koşullu bir fluent yardımcısıdır. Devre dışı durumda hover, active ve click handler tamamen atlanır.

> **Alternatif:** `element_disabled` zaten "soluk" bir renk taşır; hover davranışı devre dışı durumda tamamen kapatılmak yerine yalnızca görsel geri bildirimin farklılaştırılması da yeterli olabilir. Bu noktada karar tasarım tercihine kalır.

### Selected durum

Seçili öğeler için durum bilgisini **uygulama mantığı** taşır; tema yalnızca rengi sağlar:

```rust
struct ListeOgesi {
    etiket: SharedString,
    secili_mi: bool,
}

impl Render for ListeOgesi {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let renkler = cx.theme().colors();

        let arka_plan = if self.secili_mi {
            renkler.element_selected
        } else {
            renkler.element_background
        };

        div()
            .id(SharedString::from(format!("oge-{}", self.etiket)))
            .px_3().py_2()
            .bg(arka_plan)
            .text_color(renkler.text)
            .hover(|s| s.bg(renkler.element_hover))
            .child(self.etiket.clone())
    }
}
```

> **`element_selected` ile `element_selection_background` arasındaki fark:**
> - `element_selected` bir liste öğesinin seçili durumunu gösterir.
> - `element_selection_background` metin seçimi (highlight) arka planıdır.
>
> İki alan birbirinden farklıdır ve karıştırılmamalıdır.

### Ghost element family

"Ghost" terimi, transparan arka planlı bir elementi tanımlar. Araç çubuğu ikon butonları gibi yüzeye yapışmış görünen bileşenlerde kullanırsın.

```rust
div()
    .id("arac-cubugu-dugmesi")
    .p_2()
    .bg(renkler.ghost_element_background)         // transparan
    .text_color(renkler.icon)
    .hover(|s| s.bg(renkler.ghost_element_hover)) // hover'da görünür ol
    .active(|s| s.bg(renkler.ghost_element_active))
```

`ghost_element_background` genellikle `hsla(0, 0, 0, 0)` (tamamen şeffaf) olarak tutulur. Hover durumunda `ghost_element_hover` (çoğunlukla `elevated_surface_background` rengine yakın bir değer) devreye girer ve element görünür hale gelir.

**Ne zaman ghost kullanılır?**

| Durum | element | ghost_element |
| ------- | --------- | --------------- |
| Araç çubuğu ikon butonu |  | ✓ |
| Form button | ✓ |  |
| Sidebar item |  | ✓ (genelde) |
| Modal action | ✓ |  |
| Tab şeridi |  | ✓ |
| Dropdown trigger | ✓ |  |

**Genel kural:** Element'in **kendine ait bir kromu** varsa (border, görünür arka plan) → `element_*` seçersin. Yüzeye yapışmış, yalnızca hover/active'de görünen bir element ise → `ghost_element_*` tercih edersin.

### Bırakma hedefi (drag & drop)

```rust
div()
    .bg(renkler.background)
    .when(self.birakma_hedefi_aktif_mi, |oge| {
        oge.bg(renkler.drop_target_background)
            .border_2()
            .border_color(renkler.drop_target_border)
    })
```

Bırakma hedefi alanları, sürükleme işlemi sırasında kullanıcıya "buraya bırakılabilir" geri bildirimi vermek için kullanırsın.

### Etkileşim alanı seçim akış şeması

```text
Bileşen interactive mi?
├── Hayır → element_background (statik arka plan) + metin
│
└── Evet
    ├── Yüzeye yapışmış mı? (toolbar/sidebar/tab)
    │   └── Evet → ghost_element_background + ghost_element_hover/active
    │
    └── Kendi kromu var mı? (button/card/modal)
        └── Evet → element_background + element_hover/active
```

### Dikkat Noktaları

1. **`.id()` çağrısının yeri**: Interactivity stateful bir yapıdır; ID olmadan hover/active state bağlanamaz ve derleme hatası yerine etkileşim durumu görünmez kalır.
2. **`.hover` callback'inde tekrar `cx` üzerinden tema erişimi**:
   ```rust
   .hover(|s| s.bg(cx.theme().colors().element_hover))  // ← cx burada yok
   ```
   `cx` callback dışında bağlandığı için bu kapsamda erişim mümkün olmaz. Doğru yol, değeri önceden bağlamaktır:
   ```rust
   let hover_arka_plan = renkler.element_hover;
   .hover(move |s| s.bg(hover_arka_plan))
   ```
3. **Hover ile active sıralamasının tersine yazılması**: `.active(...).hover(...)` yazılsa bile davranış aynıdır (refinement sırası önceden belirlenmiştir); ancak okunabilirlik için `hover → active` sıralaması idiomatik kabul edilir.
4. **`element_disabled` yerine `element_background.opacity(0.5)` tercih etmek**: İki seçenek farklı tasarım kararlarıdır. Tema yazarı devre dışı durum için özel bir renk vermiş olabilir; bu durumda `element_disabled` alanını kullanman gerekir.
5. **`element_selected` tabanı**: Refinement aşamasında `Some` değer geldiğinde dolu olur; tema yazarı vermediğinde baseline değerinden gelir. Fallback tema değerinin açık doldurulması, beklenmeyen boşlukların önüne geçer.
6. **Ghost ile element seçimi**: Toolbar bir element'e `element_background` verildiğinde, beklenen şeffaf görüntü yerine yüzey rengiyle dolar; bu durum tasarım dilinin kaymasına yol açar.
7. **Etkileşim durumlarının kontrast olmayan renklerle verilmesi**: `element_hover` ile `element_background` arasında yeterli lightness farkı bulunmadığında kullanıcı hover etkisini fark etmez. Tema testlerinde bu farkın gözle doğrulanması yerinde olur.

---
