# 4. Render ve Element

---

## 4.1. Render Modeli

Bir pencerenin root view'i `Entity<V>` olmalı ve `V: Render` implement etmelidir:

```rust
struct MyView {
    focus_handle: FocusHandle,
}

impl Render for MyView {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .id("my-view")
            .track_focus(&self.focus_handle)
            .key_context("my-view")
            .on_action(cx.listener(|this, _: &CloseWindow, window, cx| {
                window.remove_window();
            }))
            .size_full()
            .child("Content")
    }
}
```

Reusable, state taşımayan bileşenlerde `RenderOnce` kullanılır:

```rust
#[derive(IntoElement)]
struct Badge {
    label: SharedString,
}

impl RenderOnce for Badge {
    fn render(self, _window: &mut Window, _cx: &mut App) -> impl IntoElement {
        div().rounded_sm().px_2().child(self.label)
    }
}
```

`Render` mutable view state ile çalışır. `RenderOnce` sahipliği alır ve genellikle
Zed UI bileşenlerinde tercih edilir.

## 4.2. Element Yaşam Döngüsü ve Draw Fazları

`Element` sözleşmesi üç fazdan oluşur:

1. `request_layout(...) -> (LayoutId, RequestLayoutState)`: stil ve child layout
   istekleri Taffy layout ağacına verilir. Bu fazda paint yapılmaz.
2. `prepaint(...) -> PrepaintState`: layout bounds bilinir; hitbox, scroll state,
   element state ve ölçüm gibi paint öncesi işler yapılır.
3. `paint(...)`: scene primitive'leri üretilir. `paint_quad`, `paint_path`,
   `paint_image`, `paint_svg`, `set_cursor_style` gibi çağrılar burada yapılır.

`Window` debug assertion'ları faz ihlalini yakalar: `insert_hitbox` yalnızca
prepaint'te, `paint_*` çağrıları paint'te, `with_text_style` ve bazı ölçüm
yardımcıları prepaint/paint içinde geçerlidir.

State saklama yolları:

- View state'i: `Entity<T>` alanları.
- Element-local state: stabil `id(...)` ile `window.with_element_state` veya
  `with_optional_element_state`; aynı ID değişirse state sıfırlanır.
- Frame callback: `window.on_next_frame(...)`.
- Effect sonunda erteleme: `cx.defer(...)`, `window.defer(cx, ...)`,
  `cx.defer_in(window, ...)`.
- Sürekli redraw: `window.request_animation_frame()`.

Render katmanı:

- `Render`: entity/view state'ini her render'da element ağacına çevirir.
- `RenderOnce`: sadece elemente dönüştürülecek hafif bileşenler için uygundur.
- `ParentElement`: child kabul eden elementler.
- `Styled`: style refinement zincirine dahil olan elementler.
- `InteractiveElement`: focus, action, key, mouse, hover, drag/drop dinleyicileri.
- `StatefulInteractiveElement`: `id(...)` sonrası scroll/focus gibi stateful
  interaktif davranışlar.

Kritik kural: `cx.notify()` view render çıktısını etkileyen state değiştiğinde
çağrılır. `window.refresh()` tüm pencerenin tekrar çizimini ister; local view
state değişiminde önce `cx.notify()` tercih edilir.

## 4.3. Element Haritası

GPUI yerleşik elementleri:

- `div()`: neredeyse tüm layout ve container işleri. Flex/grid, style, child,
  event, focus ve window-control area destekler.
- Metin: `&'static str`, `String`, `SharedString` doğrudan element olur.
  Daha karmaşık metin için `StyledText` ve `InteractiveText`.
- `svg()`: path veya external path ile SVG çizimi.
- `img(...)`: asset, path, URL, byte kaynağı gibi image kaynaklarını çizer; loading
  ve fallback slotları destekler.
- `canvas(prepaint, paint)`: düşük seviye çizim veya hitbox/cursor gibi prepaint
  gerektiren işler için.
- `anchored()`: pencere veya belirli bir noktaya sabitlenen popover/menu gibi UI.
- `deferred(child)`: öncelikli/ertelenmiş render.
- `list(...)`: değişken yükseklikli büyük listeler.
- `uniform_list(...)`: sabit/sık ölçülebilir item yüksekliği olan verimli listeler.
- `surface(...)`: platform/native surface kaynağını element olarak gösterir.

Sık kullanılan style grupları:

- Layout: `.flex()`, `.flex_col()`, `.flex_row()`, `.grid()`, `.items_center()`,
  `.justify_between()`, `.content_stretch()`, `.size_full()`, `.w(...)`, `.h(...)`
- Spacing: `.p_*`, `.px_*`, `.gap_*`, `.m_*`
- Text: `.text_color(...)`, `.text_sm()`, `.text_xl()`, `.font_family(...)`,
  `.truncate()`, `.line_clamp(...)`
- Border/shape: `.border_1()`, `.border_color(...)`, `.rounded_sm()`
- Position: `.absolute()`, `.relative()`, `.top(...)`, `.left(...)`
- State: `.hover(...)`, `.active(...)`, `.focus(...)`, `.focus_visible(...)`,
  `.group(...)`, `.group_hover(...)`
- Interaction: `.on_click(...)`, `.on_mouse_down(...)`, `.on_scroll_wheel(...)`,
  `.on_key_down(...)`, `.on_action(...)`, `.track_focus(...)`, `.key_context(...)`

Zed içinde `ui::prelude::*` genellikle `gpui::prelude::*` yerine tercih edilir;
tasarım sistemi tiplerini de getirir.

## 4.4. Element ID, Element State ve Type Erasure

GPUI'de her render'da element ağacı yeniden kurulur; kalıcı element state'i için
stabil ID gerekir. Ana tipler:

- `ElementId`: `Name`, `Integer`, `NamedInteger`, `Path`, `Uuid`,
  `FocusHandle`, `CodeLocation` gibi varyantlar taşır.
- `GlobalElementId`: parent namespace zinciriyle birleşmiş gerçek ID.
- `AnyElement`: element type erasure; child listelerinde heterojen element tutar.
- `AnyView`/`AnyEntity`: view veya entity type erasure.

Element state API'leri `Window` üzerindedir ve yalnızca element çizimi sırasında
kullanılmalıdır:

```rust
let row_state = window.use_keyed_state(
    ElementId::named_usize("row", row_ix),
    cx,
    |_, cx| RowState::new(cx),
);
```

Alt seviye API:

```rust
window.with_global_id("image-cache".into(), |global_id, window| {
    window.with_element_state::<MyState, _>(global_id, |state, window| {
        let mut state = state.unwrap_or_else(MyState::default);
        state.prepare(window);
        (state.snapshot(), state)
    })
});
```

Kurallar:

- `window.with_id(element_id, |window| ...)` local element id stack'ine id push
  eder; `with_global_id` bu stack'i `GlobalElementId` haline getirir.
- Liste item'larında `use_state` yerine `use_keyed_state` kullan; `use_state`
  caller location ile ID üretir ve aynı render noktasındaki çoklu item'ları ayıramaz.
- `with_element_namespace(id, ...)` custom element içinde child ID çakışmasını
  önlemek için kullanılır.
- Aynı `GlobalElementId` ve aynı state tipi için reentrant
  `with_element_state` çağrısı panic eder.
- ID değişirse önceki frame'in state'i devam etmez; animasyon, hover, scroll ve
  image cache state'i sıfırlanır.

Type erasure kararları:

- Public component API child kabul ediyorsa `impl IntoElement` al.
- Struct içinde saklayacaksan `AnyElement` kullan.
- View/entity saklıyorsan mümkün olduğunca typed `Entity<T>` tut; yalnızca plugin,
  dock item veya heterojen koleksiyon gerekiyorsa `AnyEntity`/`AnyView` seç.

## 4.5. FluentBuilder ve Koşullu Element Üretimi

`crates/gpui/src/util.rs::FluentBuilder` trait'i tüm element tiplerine üç
yardımcı ekler:

```rust
pub trait FluentBuilder {
    fn map<U>(self, f: impl FnOnce(Self) -> U) -> U;
    fn when(self, condition: bool, then: impl FnOnce(Self) -> Self) -> Self;
    fn when_else(
        self,
        condition: bool,
        then: impl FnOnce(Self) -> Self,
        else_fn: impl FnOnce(Self) -> Self,
    ) -> Self;
    fn when_some<T>(self, option: Option<T>, then: impl FnOnce(Self, T) -> Self) -> Self;
    fn when_none<T>(self, option: &Option<T>, then: impl FnOnce(Self) -> Self) -> Self;
}
```

Kullanım:

```rust
div()
    .flex()
    .when(self.is_active, |this| this.bg(rgb(0xFF0000)))
    .when_some(self.icon.as_ref(), |this, icon| this.child(icon.clone()))
    .when_else(self.is_loading,
        |this| this.opacity(0.5),
        |this| this.opacity(1.0),
    )
    .map(|this| match self.density {
        UiDensity::Compact => this.gap_1(),
        UiDensity::Default => this.gap_2(),
        UiDensity::Comfortable => this.gap_4(),
    })
```

Avantajlar:

- Method chain bozulmaz; if/match dışı yapılar olmadan koşullu UI yazılır.
- Closure içine geçen element'in tipi korunur; child eklemek serbesttir.
- `map` keyfi bir transform için "escape hatch" sağlar.

Tuzaklar:

- `when` closure her render'da çalışır; ağır hesap yapma.
- Aynı element üzerinde defalarca `when_some` zinciri okunabilirliği bozarsa
  state'i normal `if let` ile pre-compute edip tek `child` çağrısı tercih edilir.
- `map` element tipini değiştirebilir; `when` ise tipi değiştirmez (refinement
  zincirinde tutulur).

## 4.6. Refineable, StyleRefinement ve MergeFrom

GPUI ve Zed'de iki kompozisyon paterni paralel çalışır: render zincirinde
`Refineable`, settings/tema yüklemesinde `MergeFrom`.

#### Refineable

`crates/refineable/src/refineable.rs`:

```rust
pub trait Refineable: Clone {
    type Refinement: Refineable<Refinement = Self::Refinement> + IsEmpty + Default;

    fn refine(&mut self, refinement: &Self::Refinement);
    fn refined(self, refinement: Self::Refinement) -> Self;

    fn from_cascade(cascade: &Cascade<Self>) -> Self
        where Self: Default + Sized;

    fn is_superset_of(&self, refinement: &Self::Refinement) -> bool;
    fn subtract(&self, refinement: &Self::Refinement) -> Self::Refinement;
}

pub trait IsEmpty {
    fn is_empty(&self) -> bool;
}
```

Trait sözleşmesi göründüğünden zengindir:

- `type Refinement` da `Refineable` olmalı; yani refinement'ın kendisi tekrar
  refine edilebilir (`refine_a.refine(&refine_b)` zincirleme merge için).
- Aynı `Refinement` ayrıca `IsEmpty + Default` zorunluluğunu taşır. `IsEmpty`
  "bu refinement uygulansa hiçbir alan değişir mi?" sorusunu cevaplar; merge,
  layout cache invalidation ve `subtract` çıktısı bu kontrole dayanır.
- `is_superset_of(refinement)` instance'ın halihazırda bu refinement'ı kapsayıp
  kapsamadığını söyler — gereksiz `refine` çağrılarını atlayabilirsin.
- `subtract(refinement)` aradaki farkı yeni bir refinement olarak verir.
- `from_cascade(cascade)` aşağıdaki `Cascade` yapısını default değer üzerine
  uygular; tema/stil katmanlamasının sondaki "düzleştirme" adımıdır.

`#[derive(Refineable)]` (gpui re-export'lu): orijinal struct ile aynı alanlara
sahip ama her alanı `Option`'lı hale getirilmiş `XRefinement` türü üretir.
`refine` çağrısı yalnızca `Some` alanları yazar. Aşağıdaki somut türler hep
derive ile üretilir; ayrı yazmak gerekmez:

| Refinement türü | Üreten struct | Kaynak |
|---|---|---|
| `StyleRefinement` | `Style` | `style.rs:178` |
| `TextStyleRefinement` | `TextStyle` | `style.rs` |
| `UnderlineStyleRefinement` | `UnderlineStyle` | `style.rs` |
| `StrikethroughStyleRefinement` | `StrikethroughStyle` | `style.rs` |
| `BoundsRefinement` | `Bounds` | `geometry.rs` |
| `PointRefinement` | `Point` | `geometry.rs` |
| `SizeRefinement` | `Size` | `geometry.rs` |
| `EdgesRefinement` | `Edges` | `geometry.rs` |
| `CornersRefinement` | `Corners` | `geometry.rs` |
| `GridTemplateRefinement` | `GridTemplate` | `geometry.rs` |

Bu `*Refinement` tipleri çoğunlukla doğrudan adlandırılarak kullanılmaz; fluent
API zinciri arka planda toplar. Doğrudan elle inşa etmen gereken tek tip
genelde `StyleRefinement`'tır (örn. `.hover(|style| style.bg(...))` callback
imzası).

Tipik kullanım `Style`/`StyleRefinement` (`crates/gpui/src/style.rs:178`):

```rust
let mut style = Style::default();
style.refine(&StyleRefinement::default()
    .text_size(px(20.))
    .font_weight(FontWeight::SEMIBOLD));
```

Element fluent zinciri (örn. `div().text_size(px(14.)).bg(rgb(0xff))`)
arka planda `StyleRefinement` topluyor; render sırasında base style üzerine
refine ediliyor. `TextStyle`/`TextStyleRefinement`, `HighlightStyle`,
`PlayerColors`, `ThemeColors` gibi tüm tema yapıları aynı pattern'i kullanır.

`refined(self, refinement)` immutable bir kopya üretir; "ek style ile yeni base
elde et" senaryolarında uygundur.

#### Cascade ve CascadeSlot

`Refineable` tek başına iki katmanı (base + refinement) birleştirir; daha derin
hover/focus/active akışları için `crates/refineable/src/refineable.rs:80,93`
katman yığını sağlar:

```rust
pub struct Cascade<S: Refineable>(Vec<Option<S::Refinement>>);
pub struct CascadeSlot(usize);
```

API:

- `Cascade::default()` slot 0'ı `Some(default)` ile kurar; ek slotlar başta
  `None`'dur. Slot 0 her zaman dolu kalır ve "base" refinement'tır.
- `cascade.reserve() -> CascadeSlot`: yeni `None` slot ekler ve handle döndürür.
  Hover, focus, active gibi her dinamik katman için bir slot ayrılır.
- `cascade.base() -> &mut S::Refinement`: slot 0'ı mutable verir; layout başına
  asıl style yazılır.
- `cascade.set(slot, Option<S::Refinement>)`: belirli slot'a refinement koyar
  veya `None` ile devre dışı bırakır.
- `cascade.merged() -> S::Refinement`: slot 0 üstüne diğer dolu slotları
  sırayla `refine` eder; sonraki slot önceki slotu ezer.
- `Refineable::from_cascade(&cascade) -> Self`: `default().refined(merged())`
  shortcut'ı; render sırasında nihai stili üretmek için kullanılır.

Önemli not: GPUI'nin kendi `Interactivity` katmanı (`.hover(...)`, `.active(...)`,
`.focus(...)`, `.focus_visible(...)`, `.in_focus(...)`, `.group_hover(...)`,
`.group_active(...)` zinciri) **`Cascade`/`CascadeSlot` kullanmaz**;
`Interactivity` struct'ında her durum için ayrı bir `Option<Box<StyleRefinement>>`
alanı tutar (`elements/div.rs:1681+`'deki `hover_style`, `active_style`,
`focus_style`, `in_focus_style`, `focus_visible_style`, `group_hover_style`,
`group_active_style`) ve render fazında bu refinement'ları sırayla `refine`
eder. Yani hover style'ında verdiğin `StyleRefinement::bg(...)` base
background'u ezer ama `font_size`'a dokunmazsa base'in font_size'ı korunur —
None alan "etki yok" demektir.

`Cascade<S>` ve `CascadeSlot` arayüzü `refineable` crate'inde public olarak
durur fakat GPUI çekirdeği veya Zed bu sürümde içeriden kullanmıyor;
çoklu-katmanlı (3+) refinement yığınını dışarıdan inşa etmek isteyen kütüphane
yazarları için bir uzantı noktasıdır.

#### MergeFrom

`crates/settings_content/src/merge_from.rs`:

```rust
pub trait MergeFrom {
    fn merge_from(&mut self, other: &Self);
    fn merge_from_option(&mut self, other: Option<&Self>) {
        if let Some(other) = other { self.merge_from(other); }
    }
}
```

Default kurallar:

- HashMap, BTreeMap, struct: derin merge — sadece `other`'da var olan alanlar
  yazılır.
- `Option<T>`: `None` ezmez; `Some` recursive merge eder.
- Diğer tipler (Vec, primitive): tam üzerine yazma.

`#[derive(MergeFrom)]` derive'ı struct alanları için recursive merge üretir.
Davranışı değiştirmek için `ExtendingVec<T>` (her merge'te concat) ve
`SaturatingBool` (bir kez true olunca kalır) gibi sarıcılar mevcuttur.

Settings yükleme zinciri:

1. `assets/settings/default.json` → `SettingsContent::default()` baz alınır.
2. User `~/.config/zed/settings.json` parse → `merge_from_option`.
3. Aktif profil → `merge_from_option`.
4. Worktree `.zed/settings.json` → `merge_from_option`.
5. Sonuç `Settings::from_settings(content)` ile concrete struct'a çevrilir.

Tuzaklar:

- `Refineable` zincirinde `default()` baz değeri her seferinde yeniden hesaplanır;
  ağır base style'ları cache'le.
- `MergeFrom` sıralaması alt-üst değildir: en spesifik kaynağı en sona koy
  (`local > profile > user > default`).
- Vec'leri append etmek için `ExtendingVec`; üzerine yazmak gerekiyorsa düz `Vec`.
- `Option<Option<T>>` gibi yapı yapmak istiyorsan `MergeFrom`'un default davranışı
  doğru sonucu vermeyebilir; özel impl yaz.

## 4.7. Deferred Draw, Prepaint Order ve Overlay Katmanı

`deferred(child)` child'ın layout'unu bulunduğu yerde tutar, fakat paint'i ancestor
paint'lerinden sonraya erteler. Popover, context menu, resize handle ve dock drop
overlay gibi "üstte çizilmeli ama layout'ta yer tutmamalı" parçalar için kullanılır.

```rust
deferred(
    anchored()
        .anchor(Anchor::TopRight)
        .position(menu_position)
        .child(menu),
)
.with_priority(1)
```

Davranış:

- `request_layout`: child normal layout alır.
- `prepaint`: child `window.defer_draw(...)` ile deferred queue'ya taşınır.
- `paint`: deferred element kendi paint'inde bir şey çizmez.
- `with_priority(n)`: aynı frame'deki deferred elementler arasında z-order verir;
  yüksek priority üstte çizilir.

`Div` prepaint yardımcıları:

- `on_children_prepainted(|bounds, window, cx| ...)`: child bounds'larını ölçüp
  sonraki paint için state üretir.
- `with_dynamic_prepaint_order(...)`: child prepaint sırasını runtime'da belirler.
  Özellikle bir child'ın autoscroll veya ölçüm sonucu diğer child'ı etkiliyorsa
  kullanılır.

Tuzaklar:

- Deferred child layout'ta yer tuttuğu için absolute/anchored konumu hâlâ doğru
  parent bounds'a bağlıdır.
- Overlay mouse'u bloke etmeliyse child içinde `.occlude()` veya
  `.block_mouse_except_scroll()` kullan.
- Priority global z-index değildir; aynı window frame içindeki deferred queue
  için geçerlidir.


---

