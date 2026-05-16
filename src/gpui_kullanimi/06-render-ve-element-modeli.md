# Render ve Element Modeli

---

## Render Modeli

Bir pencerenin root view'u her zaman bir `Entity<V>` olur ve bu V tipi
`Render` trait'ini implement etmek zorundadır. `Render::render` her frame'de
yeniden çağrılan, view state'ini element ağacına dönüştüren ana metottur:

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

State taşımayan, yeniden kullanılan küçük bileşenler için ise `RenderOnce`
trait'i kullanılır. Bu trait `self`'i tüketir ve genellikle Zed UI bileşenleri
gibi statik veriden inşa edilen parçalar için tercih edilir:

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

Aradaki ayrım net bir şekilde sahiplik üzerine kuruludur: `Render` mutable
view state ile çalışır; `RenderOnce` ise sahipliği alır ve genellikle Zed UI
bileşenlerinde tercih edilir. Hangisinin seçileceği, bileşenin state'inin
nerede saklandığına bağlıdır — state view içinde tutulacaksa `Render`,
caller'ın geçirdiği yapıdan tek seferlik inşa ediliyorsa `RenderOnce`.

## Element Yaşam Döngüsü ve Draw Fazları

`Element` sözleşmesi üç ana fazdan oluşur ve bu üç faz aynı frame içinde
sırasıyla çalışır:

1. `request_layout(...) -> (LayoutId, RequestLayoutState)` — stil ve child
   layout istekleri Taffy layout ağacına verilir. Bu fazda paint yapılmaz;
   yalnızca "ne kadar yer istiyorum, çocuklarımın layout id'leri nedir"
   bilgisi üretilir.
2. `prepaint(...) -> PrepaintState` — layout sonucu artık bilinir, dolayısıyla
   bounds'a göre yapılması gereken işler burada gerçekleşir: hitbox kaydı,
   scroll state hazırlığı, element state okuma ve gerekli ölçümler.
3. `paint(...)` — sahnedeki primitive'ler üretilir. `paint_quad`,
   `paint_path`, `paint_image`, `paint_svg`, `set_cursor_style` gibi çağrılar
   bu faza aittir.

`Window` üzerindeki debug assertion'lar faz ihlallerini yakalar:
`insert_hitbox` yalnızca prepaint'te; `paint_*` çağrıları paint'te;
`with_text_style` ve bazı ölçüm yardımcıları ise prepaint veya paint
fazlarında geçerlidir. Yanlış fazda yapılan bir çağrı debug build'de panic
üretir, böylece hatalar erken yakalanır.

**State saklama yolları.** Element seviyesinde state'in nerede tutulduğu
genellikle yaşam süresine göre belirlenir:

- View state'i: `Entity<T>` alanları olarak tutulur.
- Element-local state: stabil bir `id(...)` ile birlikte
  `window.with_element_state` veya `with_optional_element_state` üzerinden
  saklanır; aynı ID değişirse state sıfırlanır.
- Frame callback: `window.on_next_frame(...)` ile sonraki frame'e kayıt.
- Effect sonunda erteleme: `cx.defer(...)`, `window.defer(cx, ...)`,
  `cx.defer_in(window, ...)`.
- Sürekli redraw: `window.request_animation_frame()` ile yeni frame talebi.

**Render katmanı.** GPUI'da render zinciri birkaç trait'in birlikte
çalışmasıyla ortaya çıkar; her trait belirli bir yetenek setini temsil eder:

- `Render`: entity/view state'ini her render'da element ağacına çevirir.
- `RenderOnce`: yalnızca element'e dönüştürülecek hafif bileşenler için
  uygundur.
- `ParentElement`: child kabul eden elementlerin trait'idir.
- `Styled`: style refinement zincirine dahil olan elementleri belirler.
- `InteractiveElement`: focus, action, key, mouse, hover, drag/drop
  dinleyicilerini açar.
- `StatefulInteractiveElement`: `id(...)` çağrısından sonra scroll/focus gibi
  stateful interaktif davranışları açar.

**Kritik kural.** `cx.notify()`, view'un render çıktısını etkileyen bir state
değiştiğinde çağrılır; bu olmadan view yeniden render edilmez.
`window.refresh()` ise tüm pencerenin tekrar çizimini ister; lokal view state
değişimleri için önce `cx.notify()` tercih edilir, çünkü daha hedeflenmiş bir
yenilemedir.

## Element Haritası

GPUI'nın yerleşik elementleri farklı görevler için ayrı ayrı tasarlanmıştır.
Aşağıdaki liste hangi element'in hangi sorumluluk için seçileceğine dair
hızlı bir rehberdir:

- `div()` — neredeyse tüm layout ve container işlerinin temel taşıdır.
  Flex/grid, style, child, event, focus ve window-control area destekler.
- Metin — `&'static str`, `String`, `SharedString` doğrudan element olur.
  Daha karmaşık metin durumlarında `StyledText` ve `InteractiveText` devreye
  girer.
- `svg()` — inline path veya harici path ile SVG çizimi sağlar.
- `img(...)` — asset, path, URL veya byte kaynağı gibi image kaynaklarını
  çizer; loading ve fallback slotları da destekler.
- `canvas(prepaint, paint)` — düşük seviyeli çizim ya da hitbox/cursor gibi
  prepaint gerektiren işler için kullanılır.
- `anchored()` — pencereye veya belirli bir noktaya sabitlenen popover ve
  menu benzeri UI parçaları içindir.
- `deferred(child)` — öncelikli veya ertelenmiş render gerektiren durumlar
  için.
- `list(...)` — değişken yükseklikli büyük listelerde tercih edilir.
- `uniform_list(...)` — sabit veya kolay ölçülen item yüksekliği olan, yüksek
  performans gerektiren listeler için.
- `surface(...)` — platform/native bir surface kaynağını element olarak
  gösterir.

**Sık kullanılan style grupları.** Fluent API'de tekrar tekrar karşılaşılan
zincir parçaları genelde şu gruplar altında toplanır:

- Layout: `.flex()`, `.flex_col()`, `.flex_row()`, `.grid()`,
  `.items_center()`, `.justify_between()`, `.content_stretch()`,
  `.size_full()`, `.w(...)`, `.h(...)`.
- Spacing: `.p_*`, `.px_*`, `.gap_*`, `.m_*`.
- Text: `.text_color(...)`, `.text_sm()`, `.text_xl()`, `.font_family(...)`,
  `.truncate()`, `.line_clamp(...)`.
- Border/shape: `.border_1()`, `.border_color(...)`, `.rounded_sm()`.
- Position: `.absolute()`, `.relative()`, `.top(...)`, `.left(...)`.
- State: `.hover(...)`, `.active(...)`, `.focus(...)`, `.focus_visible(...)`,
  `.group(...)`, `.group_hover(...)`.
- Interaction: `.on_click(...)`, `.on_mouse_down(...)`,
  `.on_scroll_wheel(...)`, `.on_key_down(...)`, `.on_action(...)`,
  `.track_focus(...)`, `.key_context(...)`.

Zed kod tabanında `ui::prelude::*` genellikle `gpui::prelude::*` yerine
tercih edilir; bu prelude tasarım sistemi tiplerini de birlikte getirir,
böylece import listesi sade kalır.

## Element ID, Element State ve Type Erasure

GPUI'da her render'da element ağacı sıfırdan kurulur; oysa hover/scroll/cache
gibi durumlar frame'ler arasında korunmalıdır. Bu kalıcılığı kuran şey stabil
ID'lerdir. İlgili ana tipler şunlardır:

- `ElementId` — `Name`, `Integer`, `NamedInteger`, `Path`, `Uuid`,
  `FocusHandle`, `CodeLocation` gibi varyantlar taşır.
- `GlobalElementId` — parent namespace zinciriyle birleşerek tam yol oluşturur.
- `AnyElement` — element type erasure; child listelerinde heterojen element
  tutmak için kullanılır.
- `AnyView` / `AnyEntity` — view veya entity için type erasure.

Element state API'leri `Window` üzerindedir ve yalnızca element çizimi
sırasında çağrılabilir. Yüksek seviyeli API state'i otomatik yönetir:

```rust
let row_state = window.use_keyed_state(
    ElementId::named_usize("row", row_ix),
    cx,
    |_, cx| RowState::new(cx),
);
```

Daha düşük seviyeli ihtiyaçlar için global id ve element state API'leri
doğrudan açıktır:

```rust
window.with_global_id("image-cache".into(), |global_id, window| {
    window.with_element_state::<MyState, _>(global_id, |state, window| {
        let mut state = state.unwrap_or_else(MyState::default);
        state.prepare(window);
        (state.snapshot(), state)
    })
});
```

**Kurallar.** Element id'siyle çalışırken gözetilmesi gereken disiplinler
şunlardır:

- `window.with_id(element_id, |window| ...)` lokal element id stack'ine id
  ekler; `with_global_id` bu stack'ten tam bir `GlobalElementId` üretir.
- Liste item'larında `use_state` yerine `use_keyed_state` tercih edilir;
  `use_state` caller location'a göre id üretir ve aynı render noktasındaki
  birden fazla item'ı birbirinden ayıramaz.
- `with_element_namespace(id, ...)` custom element içinde child id
  çakışmalarını önlemek için kullanılır.
- Aynı `GlobalElementId` ve aynı state tipi için reentrant
  `with_element_state` çağrısı panic verir.
- ID değiştiğinde önceki frame'in state'i devam etmez; animasyon, hover,
  scroll ve image cache state'i sıfırlanır.

**Type erasure kararları.** Tipli ve untyped element/view arasında seçim
yapılırken şu yönlendirmeler işe yarar:

- Public bir component API'si child kabul ediyorsa `impl IntoElement` almak
  uygundur.
- Struct içinde saklanacaksa `AnyElement` kullanılır.
- View veya entity saklanıyorsa mümkün olduğu kadar tipli `Entity<T>` tutmak
  tercih edilir; yalnızca plugin, dock item veya heterojen koleksiyon gerektiren
  durumlarda `AnyEntity`/`AnyView` seçilir.

## FluentBuilder ve Koşullu Element Üretimi

`crates/gpui/src/util.rs::FluentBuilder` trait'i tüm element tiplerine üç
yardımcı ekler ve fluent zincirin if/match bloklarıyla kırılmasını engeller:

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

Tipik bir kullanım birden fazla koşullu davranışı tek bir akıcı zincirde
toparlar:

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

**Avantajlar.** Bu yardımcıların getirdiği başlıca kolaylıklar şunlardır:

- Method chain bozulmaz; if/match yapılarına başvurmadan koşullu UI
  yazılabilir.
- Closure içine geçen element'in tipi korunur; child eklemeye devam etmek
  serbesttir.
- `map` keyfi bir transform için "escape hatch" olarak iş görür.

**Tuzaklar.** Aynı kolaylıkların yanlış kullanımı küçük sorunlar üretebilir:

- `when` closure her render'da çalışır; içinde ağır hesap yapılması performans
  problemi doğurur.
- Aynı element üzerinde defalarca `when_some` zincirlemek okunabilirliği
  bozarsa state'i önce normal `if let` ile pre-compute etmek ve tek `child`
  çağrısı yapmak tercih edilir.
- `map` element tipini değiştirebilir; `when` ise tipi değiştirmez (refinement
  zincirinde kalır). Bu nedenle map kullanımı dikkatli yapılır.

## Refineable, StyleRefinement ve MergeFrom

GPUI ve Zed'de iki kompozisyon paterni paralel çalışır: render zincirinde
`Refineable`, settings ve tema yüklemesinde `MergeFrom`. İkisi de "default
üzerine kademe kademe override" mantığını işletir, ancak farklı yerlerde
devreye girer.

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

Trait sözleşmesi göründüğünden zengindir ve birkaç ince detay içerir:

- `type Refinement` da `Refineable` olmalıdır; yani refinement'ın kendisi
  tekrar refine edilebilir — bu sayede `refine_a.refine(&refine_b)`
  zincirleme merge mümkün olur.
- Aynı `Refinement` ayrıca `IsEmpty + Default` zorunluluğunu taşır.
  `IsEmpty` "bu refinement uygulansa hiçbir alan değişir mi?" sorusunu
  cevaplar; merge, layout cache invalidation ve `subtract` çıktısı bu
  kontrole dayanır.
- `is_superset_of(refinement)` instance'ın halihazırda bu refinement'ı
  kapsayıp kapsamadığını söyler; gereksiz `refine` çağrıları bu sayede
  atlanabilir.
- `subtract(refinement)` iki refinement arasındaki farkı yeni bir refinement
  olarak verir.
- `from_cascade(cascade)` aşağıda anlatılan `Cascade` yapısını default değer
  üzerine uygular; tema ve stil katmanlamasının sondaki "düzleştirme"
  adımıdır.

`#[derive(Refineable)]` (gpui re-export'lu): orijinal struct ile aynı alanlara
sahip, ama her alanı `Option`'lı hale getirilmiş bir `XRefinement` türü
üretir. `refine` çağrısı yalnızca `Some` alanları yazar. Aşağıdaki somut
türler her zaman derive ile üretilir, ayrıca elle yazmaya gerek kalmaz:

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

Bu `*Refinement` tipleri çoğunlukla doğrudan adlandırılarak kullanılmaz;
fluent API zinciri onları arka planda toplar. Doğrudan elle inşa etmek
gerektiği tek tip genellikle `StyleRefinement`'tır — örneğin
`.hover(|style| style.bg(...))` callback'inin imzasında bu tip görünür.

Tipik kullanım `Style`/`StyleRefinement` (`crates/gpui/src/style.rs:178`)
üzerinden ilerler:

```rust
let mut style = Style::default();
style.refine(&StyleRefinement::default()
    .text_size(px(20.))
    .font_weight(FontWeight::SEMIBOLD));
```

Element fluent zinciri (örneğin
`div().text_size(px(14.)).bg(rgb(0xff))`) arka planda bir `StyleRefinement`
biriktirir; render sırasında base style üzerine refine eder.
`TextStyle`/`TextStyleRefinement`, `HighlightStyle`, `PlayerColors`,
`ThemeColors` gibi tüm tema yapıları aynı paterni kullanır.

`refined(self, refinement)` ise immutable bir kopya üretir; "ek style ile
yeni base elde et" senaryolarında uygundur.

#### Cascade ve CascadeSlot

`Refineable` tek başına iki katmanı (base + refinement) birleştirir. Daha
derin hover/focus/active akışları için
`crates/refineable/src/refineable.rs:80,93` katman yığını sunar:

```rust
pub struct Cascade<S: Refineable>(Vec<Option<S::Refinement>>);
pub struct CascadeSlot(usize);
```

API yüzeyi şu şekildedir:

- `Cascade::default()` slot 0'ı `Some(default)` ile kurar; ek slotlar başta
  `None`'dur. Slot 0 her zaman dolu kalır ve "base" refinement'tır.
- `cascade.reserve() -> CascadeSlot` yeni `None` slot ekler ve handle döner.
  Hover, focus, active gibi her dinamik katman için ayrı bir slot ayrılır.
- `cascade.base() -> &mut S::Refinement` slot 0'ı mutable verir; layout
  başına asıl style buraya yazılır.
- `cascade.set(slot, Option<S::Refinement>)` belirli bir slot'a refinement
  koyar veya `None` ile o katmanı devre dışı bırakır.
- `cascade.merged() -> S::Refinement` slot 0 üzerine diğer dolu slotları
  sırayla `refine` eder; sonraki slot önceki slotu ezer.
- `Refineable::from_cascade(&cascade) -> Self` `default().refined(merged())`
  shortcut'ıdır; render sırasında nihai stili üretmek için kullanılır.

**Önemli not.** GPUI'nın kendi `Interactivity` katmanı (`.hover(...)`,
`.active(...)`, `.focus(...)`, `.focus_visible(...)`, `.in_focus(...)`,
`.group_hover(...)`, `.group_active(...)` zinciri) **`Cascade`/`CascadeSlot`
kullanmaz**; `Interactivity` struct'ı her durum için ayrı bir
`Option<Box<StyleRefinement>>` alanı tutar
(`elements/div.rs:1681+`'deki `hover_style`, `active_style`, `focus_style`,
`in_focus_style`, `focus_visible_style`, `group_hover_style`,
`group_active_style`) ve render fazında bu refinement'ları sırayla `refine`
eder. Yani hover style'da verilen `StyleRefinement::bg(...)` base
background'u ezer ama `font_size`'a dokunmayan bir refinement base'in
font_size'ını korur; `None` alan "etki yok" anlamına gelir.

`Cascade<S>` ve `CascadeSlot` arayüzü `refineable` crate'inde public olarak
durur; ancak GPUI çekirdeği veya Zed bu sürümde içeriden kullanmaz. Çoklu
katmanlı (3+) refinement yığınını dışarıdan inşa etmek isteyen kütüphane
yazarları için bir uzantı noktası olarak bulunur.

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

Default kurallar şu şekildedir:

- HashMap, BTreeMap, struct: derin merge — yalnızca `other`'da var olan
  alanlar yazılır.
- `Option<T>`: `None` üzerine yazmaz; `Some` recursive olarak merge eder.
- Diğer tipler (Vec, primitive): tam üzerine yazma.

`#[derive(MergeFrom)]` derive'ı struct alanları için recursive merge üretir.
Bu default davranışı değiştirmek için `ExtendingVec<T>` (her merge'te concat)
ve `SaturatingBool` (bir kez `true` olunca öyle kalır) gibi sarıcılar
hazırdır.

**Settings yükleme zinciri.** Settings okunurken katmanlar belli bir sırayla
merge edilir:

1. `assets/settings/default.json` → `SettingsContent::default()` baz alınır.
2. User `~/.config/zed/settings.json` parse edilir →
   `merge_from_option`.
3. Aktif profil → `merge_from_option`.
4. Worktree `.zed/settings.json` → `merge_from_option`.
5. Sonuç `Settings::from_settings(content)` ile concrete struct'a çevrilir.

**Tuzaklar.** Refineable ve MergeFrom kullanımlarında karşılaşılabilecek
hatalı kalıplar şunlardır:

- `Refineable` zincirinde `default()` baz değeri her seferinde yeniden
  hesaplanır; ağır base style'lar bir önbelleğe alınmalıdır.
- `MergeFrom` sıralaması alt-üst değildir: en spesifik kaynak en sona
  konulmalıdır (`local > profile > user > default`).
- Vec'leri append etmek gerekiyorsa `ExtendingVec`; üzerine yazmak yeterliyse
  düz `Vec` kullanılır.
- `Option<Option<T>>` gibi iç içe seçenek yapıları gerektiğinde MergeFrom'un
  default davranışı doğru sonucu vermeyebilir; bu durumda özel bir impl
  yazılması gerekir.

## Deferred Draw, Prepaint Order ve Overlay Katmanı

`deferred(child)` çağrısı, çocuk elementin layout'unu bulunduğu yerde tutar
ama paint'i ancestor paint'lerinden sonraya erteler. Bu davranış popover,
context menu, resize handle ve dock drop overlay gibi "üstte çizilmesi ama
layout'ta yer tutmaması gereken" parçalar için tasarlanmıştır:

```rust
deferred(
    anchored()
        .anchor(Anchor::TopRight)
        .position(menu_position)
        .child(menu),
)
.with_priority(1)
```

**Davranış.** Üç faz sırasıyla şu işleri yapar:

- `request_layout`: child normal şekilde layout alır.
- `prepaint`: child `window.defer_draw(...)` ile deferred queue'ya taşınır.
- `paint`: deferred element kendi paint'inde bir şey çizmez; çizim
  ertelenmiş kuyrukta sıra geldiğinde yapılır.
- `with_priority(n)`: aynı frame içindeki deferred elementler arasında
  z-order verir; yüksek priority üstte çizilir.

**`Div` prepaint yardımcıları.** Layout sonuçlarına göre prepaint'te aksiyon
almak gerektiğinde iki yardımcı vardır:

- `on_children_prepainted(|bounds, window, cx| ...)` — child bounds'larını
  ölçer ve sonraki paint için state üretir.
- `with_dynamic_prepaint_order(...)` — child prepaint sırasını runtime'da
  belirler. Özellikle bir child'ın autoscroll veya ölçüm sonucu diğer
  child'ı etkilediği durumlarda kullanılır.

**Tuzaklar.** Deferred draw kullanımında dikkat edilecek noktalar:

- Deferred child layout'ta yer tuttuğu için absolute/anchored konumlandırma
  hâlâ doğru parent bounds'a bağlıdır.
- Overlay'in mouse olaylarını bloklaması isteniyorsa child içinde
  `.occlude()` veya `.block_mouse_except_scroll()` kullanılır.
- Priority değeri global z-index değildir; yalnızca aynı window frame
  içindeki deferred queue için geçerlidir.

---
