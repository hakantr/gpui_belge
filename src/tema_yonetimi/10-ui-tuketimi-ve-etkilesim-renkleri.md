# Bölüm X — UI tüketimi ve etkileşim renkleri

Bileşen tarafında `cx.theme()` okuma yolunu ve hover/active/disabled gibi state renklerini kullan.

---

## 41. `cx.theme()` ile bileşen renklendirme

**Tüketici sözleşmesi:** UI bileşenleri tema değerlerine `cx.theme()`
üzerinden erişir. Bu çağrı `&Arc<Theme>` döner — klonsuz, allocation
yok.

### Temel kalıp

```rust
use gpui::{div, prelude::*, App, Window, Context};
use kvs_tema::ActiveTheme;

struct AnaPanel;

impl Render for AnaPanel {
    fn render(
        &mut self,
        _w: &mut Window,
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

**Üç gerek:**

1. **`use kvs_tema::ActiveTheme;`** — trait import edilmemişse `cx.theme()`
   "method not found" hatası verir.
2. **`let tema = cx.theme();`** — `&Arc<Theme>` döndüğü için `&self`
   borrow gibi davranır; render içinde tek seferlik bağlama.
3. **Alan erişimi** — `styles` crate-içi olduğu için tüketici
   `tema.colors().background` gibi accessor kullanır.

### Erişim yolları kıyaslaması

```rust
// Accessor metotları (önerilen değil, dış crate için zorunlu)
let bg = tema.colors().background;
let muted = tema.colors().text_muted;
let error = tema.status().error;
let local = tema.players().local().cursor;
```

**Accessor metotları neden tercih?** `styles` alanının iç düzeni sync
turunda değişebilir (örn. `colors` ve `status` ayrıştırılır). Accessor
yöntemi sözleşmeyi `theme.colors()` üzerinde sabitler; tüketici kodu
etkilenmez.

### Prelude modül deseni

`kvs_tema` her render dosyasında üç import gerektirebilir:

```rust
use kvs_tema::ActiveTheme;
use kvs_tema::Theme;
use kvs_tema::Appearance;
```

Prelude modül bunu tek satıra indirir:

```rust
// kvs_tema/src/prelude.rs
pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily};
pub use crate::styles::*;
```

Tüketici:

```rust
use kvs_tema::prelude::*;
```

> **`gpui::prelude` ile çakışma:** GPUI'nin `prelude::*`'ı `Render`
> ve fluent API trait'lerini getirir. `kvs_tema::prelude::*`'ı yanına
> koyarsan iki ayrı `use` satırı:
> ```rust
> use gpui::{prelude::*, div, App, Window, Context};
> use kvs_tema::prelude::*;
> ```

### Stateless okuma vs cached değer

```rust
// (A) Stateless — her render'da tema okur
impl Render for X {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div().bg(cx.theme().colors().background)
    }
}

// (B) Cached — state'te tutar
struct X {
    bg: Hsla,
}
impl X {
    fn new(cx: &mut Context<Self>) -> Self {
        Self { bg: cx.theme().colors().background }
    }
}
impl Render for X {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div().bg(self.bg)  // ← tema değişirse güncellenmez!
    }
}
```

**Her zaman (A) — stateless.** `cx.refresh_windows()` (Bölüm VIII/Konu 35) view'ı yeniden çağırır; tema yeni değerlerle okunur. (B) tema
değişimine **kapalı** — eski rengi tutar; bug.

İstisna: render içinde **hesaplanmış değer** (örn. `bg.opacity(0.5)`)
performans için cache edilebilir; ama `cx.theme()` çağrısı zaten
allocation'suz, cache gereksiz.

### Birden fazla alan okuma

`cx.theme()` çağrısını **bir kez yap**, türeyenleri lokal bind et:

```rust
// İYİ
let tema = cx.theme();
let colors = tema.colors();
let status = tema.status();

div()
    .bg(colors.background)
    .text_color(colors.text)
    .border_color(if has_error { status.error } else { colors.border })

// KÖTÜ (her çağrı `cx.global` lookup)
div()
    .bg(cx.theme().colors().background)
    .text_color(cx.theme().colors().text)
    .border_color(if has_error {
        cx.theme().status().error
    } else {
        cx.theme().colors().border
    })
```

Tekrar maliyeti pratikte düşük (`cx.global` HashMap lookup), ama
okunabilirlik için tek bağlama.

### Bileşen tasarım deseni

UI bileşenleri için **tema okuma sözleşmesi**:

```rust
use kvs_tema::prelude::*;

struct Button {
    label: SharedString,
    on_click: Box<dyn Fn(&mut Window, &mut App)>,
}

impl Render for Button {
    fn render(
        &mut self,
        _w: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let colors = cx.theme().colors();

        div()
            .px_3()
            .py_2()
            .bg(colors.element_background)
            .text_color(colors.text)
            .rounded_md()
            .border_1()
            .border_color(colors.border)
            .child(self.label.clone())
    }
}
```

**Sözleşme noktaları:**

- Bileşen kendi içinde tema okur — parent'tan renk parametre olarak
  almaz.
- Bileşen `Theme` tipini import etmez; sadece `ActiveTheme` trait'ini
  (prelude ile).
- Bileşen state'inde `Hsla` tutmaz — her render fresh okur.

### Tuzaklar

1. **`use kvs_tema::ActiveTheme;` unutmak**: `cx.theme()` "method not
   found" hatası. En yaygın import bug'ı. Prelude kullan.
2. **`cx.theme().clone()`**: `&Arc<Theme>` zaten ucuz; `.clone()`
   refcount artırır ama referans yeterli. Gereksiz.
3. **Bileşen state'inde renk cache'lemek**: Tema değişiminde stale.
   Stateless oku.
4. **`tema.styles.colors.X` zinciri**: Dış crate için compile hatasıdır.
   Accessor kullan (`theme.colors()`).
5. **Render dışında `cx.theme()`**: `&mut Context<Self>` `App`'ten
   `cx.theme()` çağırmana izin verir; ama render fazı dışında çağrı
   genelde yanlış soyutlama — bileşen state'i tutar, theme değişiminde
   yeniden okunmaz. Render fazına bağla.
6. **`Context<T>` yerine `&Window`**: `Window` üzerinden `cx.theme()`
   yok; `Window` `App` deref etmez. Render imzası `(&mut Window, &mut
   Context<Self>)` — iki parametre ayrı.

### `Theme::darken` ile appearance-aware koyulaştırma

Zed'in `Theme::darken(color, light_amount, dark_amount)` (`theme.rs:274`)
yardımcısı bir rengi appearance'a göre **lightness** azaltarak koyulaştırır:
light tema modunda `light_amount`, dark tema modunda `dark_amount` kullanılır;
sonuç `l = (l - amount).max(0.0)` ile alt sınırlanır. Aynı bileşenin
iki temada da yeterli kontrast tutmasını sağlamak için iki ayrı miktar
geçilir.

```rust
use kvs_tema::ActiveTheme;

impl Render for HoverChip {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let tema = cx.theme();
        // Hover'da background'u light'ta 0.06, dark'ta 0.04 koyulaştır.
        let hover_bg = tema.darken(tema.colors().element_background, 0.06, 0.04);
        div()
            .bg(tema.colors().element_background)
            .hover(|s| s.bg(hover_bg))
            .text_color(tema.colors().text)
    }
}
```

**Sınırlar:** `darken` yalnızca lightness'i etkiler; alpha, saturation,
hue olduğu gibi kalır. Şeffaf renkler için sonuç hâlâ şeffaftır. Kaynak
notunda "tentative solution" diye işaretli — Zed kalıcı bir renk sistemi
oturtana kadar geçici. Mirror tarafta aynı imzayla tutmak parite açısından
önemlidir, ama daha karmaşık (`OkLab` veya `palette::Mix`) bir varyant
yazılırsa bu yerel API genişletmesi olur.

### Markdown preview, code fontu ve Mermaid tema tüketimi

Markdown preview hattı tema tüketicisi olarak şu alanları kullanır:

- Düz markdown metni preview modunda `markdown_preview_font_family()` ile
  okunur ve unset ise `ui_font.family` kullanır.
- Inline code ve code block'lar yeni
  `markdown_preview_code_font_family()` accessor'ını kullanır; unset ise
  `buffer_font.family`'ye düşer. Bu yüzden settings mirror'ında
  `markdown_preview_font_family` ile `markdown_preview_code_font_family`
  ayrı alanlardır.
- Mermaid render'ı artık aktif tema renklerinden kendi renderer temasını
  üretir: `editor_background`, `surface_background`, `element_background`,
  `ghost_element_hover`, `panel_background`, `text`, `border`,
  `border_variant`, `accents()` ve `players()` birlikte kullanılır.
- Mermaid `accent0..accentN` class'ları player renklerinden üretilir;
  fill rengi light/dark appearance'a göre okunabilir kontrasta çekilir.
  Bu, player slotlarının yalnız collab cursor için değil, görsel markdown
  diyagramları için de tüketildiği anlamına gelir.
- Tema veya settings değiştiğinde Mermaid image cache'i invalid edilmelidir;
  aksi halde markdown preview eski tema renkleriyle kalır.

Editor completion menüsündeki `completion_menu_item_kind = "symbol"`
ayarı da syntax theme'i editor metni dışında tüketir: LSP completion kind
değerleri `function`, `function.method`, `type`, `property`, `variable`,
`keyword`, `string` gibi highlight capture adlarına eşlenir; tam capture
bulunamazsa parent capture denenir. Syntax theme boş bırakılırsa bu rozetler
renksiz kalır.

---

## 42. Hover / active / disabled / selected / ghost desenleri

GPUI'nin fluent API'si etkileşim durumları için `.hover()`, `.active()`
ve `Interactivity` katmanı sağlar. Tema'da her durum için **özel
alanlar** var; nasıl eşleneceği sözleşmenin bir parçası.

### Etkileşim alanları eşlemesi

```
ThemeColors:
├── element_background    ← varsayılan
├── element_hover         ← .hover(|s| s.bg(...))
├── element_active        ← .active(|s| s.bg(...))
├── element_selected      ← seçili state (uygulama mantığı)
├── element_selection_background  ← metin seçim bg
├── element_disabled      ← disabled state
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

impl Render for InteractiveButton {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let colors = cx.theme().colors();

        div()
            .id("btn")                              // ← Interactivity için ID şart
            .px_3()
            .py_2()
            .bg(colors.element_background)
            .text_color(colors.text)
            .rounded_md()
            .hover(|s| s.bg(colors.element_hover))
            .active(|s| s.bg(colors.element_active))
            .child("Click")
    }
}
```

**Önemli:**

- `.id(...)` çağrısı **şart** — Interactivity (hover/active/click)
  bileşeni stateful, ID olmadan GPUI durumu tanıyamaz.
- `.hover(|s| ...)`, `.active(|s| ...)` — `StyleRefinement` callback'i
  (Bölüm III/Konu 11). Bu refinement element üstüne layer'lanır.

### Hover varyantları

```rust
// 1. Tek alan değişimi
div().bg(colors.element_background)
    .hover(|s| s.bg(colors.element_hover))

// 2. Hover'da border ekleme
div().border_1().border_color(colors.border)
    .hover(|s| s.border_color(colors.border_focused))

// 3. Hover'da text rengi değişimi
div().text_color(colors.text_muted)
    .hover(|s| s.text_color(colors.text))
```

### Active (basılı) state

```rust
div()
    .bg(colors.element_background)
    .hover(|s| s.bg(colors.element_hover))
    .active(|s| s.bg(colors.element_active))
```

**Sıralama önemli:** GPUI önce hover, sonra active uygular. Active'de
verdiğin alan, hover'ın üstüne yazılır. Active state, mouse button
basılıyken aktif.

### Disabled state

GPUI'nin doğrudan `.disabled(|s| ...)` callback'i yok; durum mantığını
sen yönetirsin:

```rust
let bg = if self.is_disabled {
    colors.element_disabled
} else {
    colors.element_background
};

let text = if self.is_disabled {
    colors.text_disabled
} else {
    colors.text
};

div()
    .id("btn")
    .bg(bg)
    .text_color(text)
    .when(!self.is_disabled, |this| {
        this.hover(|s| s.bg(colors.element_hover))
            .active(|s| s.bg(colors.element_active))
            .on_click(/* ... */)
    })
```

`.when(cond, |this| ...)` — koşullu fluent. Disabled'da hover/active
ve click handler atlanır.

> **Alternatif:** `element_disabled` zaten "soluk" rengi taşır; hover
> davranışını disabled'da tamamen kapatmak yerine sadece görsel
> feedback'i farklılaştırmak yeterli olabilir. Tasarım kararına bağlı.

### Selected state

Seçili öğeler için **uygulama mantığı** durumu tanır; tema sadece
rengini sağlar:

```rust
struct ListItem {
    label: SharedString,
    is_selected: bool,
}

impl Render for ListItem {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let colors = cx.theme().colors();

        let bg = if self.is_selected {
            colors.element_selected
        } else {
            colors.element_background
        };

        div()
            .id(SharedString::from(format!("item-{}", self.label)))
            .px_3().py_2()
            .bg(bg)
            .text_color(colors.text)
            .hover(|s| s.bg(colors.element_hover))
            .child(self.label.clone())
    }
}
```

> **`element_selected` vs `element_selection_background`:**
> - `element_selected` = bir liste öğesinin seçili durumu.
> - `element_selection_background` = metin seçimi (highlight) arka planı.
> İkisi farklı; karıştırma.

### Ghost element family

"Ghost" = transparan arka planlı element; toolbar icon button gibi
yüzeye yapışmış görünüm.

```rust
div()
    .id("toolbar-btn")
    .p_2()
    .bg(colors.ghost_element_background)         // transparan
    .text_color(colors.icon)
    .hover(|s| s.bg(colors.ghost_element_hover)) // hover'da görünür ol
    .active(|s| s.bg(colors.ghost_element_active))
```

`ghost_element_background` genelde `hsla(0, 0, 0, 0)` (tamamen şeffaf).
Hover'da `ghost_element_hover` (genelde `elevated_surface_background`'a
yakın) görünür hale gelir.

**Ne zaman ghost kullan?**

| Durum | element | ghost_element |
|-------|---------|---------------|
| Toolbar icon button | | ✓ |
| Form button | ✓ | |
| Sidebar item | | ✓ (genelde) |
| Modal action | ✓ | |
| Tab şeridi | | ✓ |
| Dropdown trigger | ✓ | |

**Genel kural:** Element'in **kendine ait kromu** olacaksa (border,
visible bg) → `element_*`. Yüzeye yapışmış, sadece hover/active'de
görünüyorsa → `ghost_element_*`.

### Drop target (drag & drop)

```rust
div()
    .bg(colors.background)
    .when(self.is_drop_target_active, |this| {
        this.bg(colors.drop_target_background)
            .border_2()
            .border_color(colors.drop_target_border)
    })
```

Drop target alanları drag sırasında "burada bırak" feedback'i için.

### Etkileşim alanı seçim akış şeması

```
Bileşen interactive mi?
├── Hayır → element_background (statik bg) + text
│
└── Evet
    ├── Yüzeye yapışmış mı? (toolbar/sidebar/tab)
    │   └── Evet → ghost_element_background + ghost_element_hover/active
    │
    └── Kendi kromu var mı? (button/card/modal)
        └── Evet → element_background + element_hover/active
```

### Tuzaklar

1. **`.id()` atlamak**: Interactivity stateful — ID yoksa hover/active
   çalışmaz, "method not found" yerine sessiz başarısızlık.
2. **`.hover` callback'inde tema'ya tekrar erişmek**:
   ```rust
   .hover(|s| s.bg(cx.theme().colors().element_hover))  // ← cx burada yok
   ```
   `cx` callback dışında bağlandığı için burada erişilmez. Önceden
   bind et:
   ```rust
   let hover_bg = colors.element_hover;
   .hover(move |s| s.bg(hover_bg))
   ```
3. **Hover ve active sıralama tersine**: `.active(...).hover(...)` yazsan
   bile davranış aynı (refinement sırası belirlenmiş); ama okunabilirlik
   için `hover → active` sıralaması idiomatik.
4. **`element_disabled` ile `element_background.opacity(0.5)`**: İkisi
   farklı tasarım kararı. Tema yazarı disabled'a özel renk vermiş
   olabilir; `element_disabled` alanını kullan.
5. **`element_selected` her zaman dolu sanmak**: Refinement aşamasında
   `Some` ise dolu; tema yazarı vermediyse baseline'dan gelir. Fallback
   tema değerini açık doldur (Bölüm VI/Konu 25).
6. **Ghost ve element karıştırmak**: Toolbar'a `element_background`
   verirsen şeffaf kalmak yerine yüzey rengiyle dolar = tasarım dili
   kayar.
7. **Etkileşim durumlarını kontrast olmayan renklerle vermek**: `element_hover`
   ile `element_background` arasında yeterli lightness farkı yoksa
   kullanıcı hover'ı fark etmez. Tema testinde gözle bak.

---

