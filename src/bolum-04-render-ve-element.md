# 4. Render ve Element

---

## 4.1. Render Modeli

GPUI'de "render" yapmak, view state'inden bir element ağacı (UI'ın o frame'deki yapısı) üretmek demektir. Render çıktısı kalıcı bir ağaç olarak saklanmaz; her frame'de yeniden üretilir, GPUI bu çıktının layout'unu hesaplar ve ekrana çizer. Kalıcı bilgi gerekiyorsa view state, element-local state veya ilgili handle'larda tutulur.

Render iki şekilde ifade edilir:

- **`Render` trait'i**, durum tutan view'lar (Entity tabanlı) içindir. Aynı view birden çok frame boyunca yaşar; her frame'de `render` çağrılır ve içerideki state mutable referansla erişilir. Bir pencerenin kök view'ı `Entity<V>` tipinde olmak ve `V: Render` implementasyonuna sahip olmak zorundadır:

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
            .child("İçerik")
    }
}
```

- **`RenderOnce` trait'i**, durum tutmayan, tek seferlik element üretimi yapan hafif bileşenler içindir. `render(self, ...)` çağrısı değeri sahiplenir; aynı değer bir kez elemente dönüştürülür:

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

Hangisinin ne zaman tercih edildiği:

- *`Render` (Entity ile birlikte)*: state tutan, ömrü birden çok frame'e yayılan, event aboneliği veya async iş barındıran view'lar için. Tipik örnekler: workspace, editor pane, settings paneli.
- *`RenderOnce` (`#[derive(IntoElement)]` ile)*: durum taşımayan tasarım sistemi bileşenleri için. Tipik örnekler: Button, Badge, Icon, Tooltip içeriği. Zed UI bileşenlerinin neredeyse tamamı `RenderOnce` tabanlıdır.

## 4.2. Element Yaşam Döngüsü ve Draw Fazları

Her element bir frame içinde üç fazdan geçer. Bu fazlar bilinçli olarak ayrılmıştır çünkü her birinin yapabileceği iş farklıdır: layout hesaplandığında geometri henüz yoktur, paint sırasında ise layout artık sabittir ve geometriye dokunulamaz.

1. **`request_layout(...) -> (LayoutId, RequestLayoutState)`** — Element kendi stilini ve child layout isteklerini Taffy layout ağacına bildirir. Bu fazda *hiçbir piksel çizilmez*, hitbox eklenmez ve nihai bounds henüz bilinmez.
2. **`prepaint(...) -> PrepaintState`** — Layout artık bilindiği için, çizimden önce yapılması gereken her şey burada yapılır: hitbox kayıtları, scroll state hesabı, element state okuma/yazma, child bounds'a göre ölçüm.
3. **`paint(...)`** — Asıl çizim. `paint_quad`, `paint_path`, `paint_image`, `paint_svg`, `set_cursor_style` gibi çağrılar yalnızca bu fazda geçerlidir.

`Window` üzerinde her faz için debug assertion bulunur; yanlış fazda yapılan çağrı (örn. `request_layout` içinde `paint_quad`) test/debug build'inde panic'e yol açar. Faz kuralları: `insert_hitbox` yalnızca prepaint'te, `paint_*` çağrıları yalnızca paint'te, `with_text_style` ve bazı ölçüm yardımcıları ise prepaint/paint sırasında geçerlidir.

### State'i nerede saklamak gerekir

Render her frame yeniden çalıştığı için, sıradan bir local değişken iki frame arasında saklanamaz. GPUI bu boşluğu birkaç farklı saklama yolu sunarak doldurur:

- **View state** (`Entity<T>` alanları) — view'ın kendine ait, uzun yaşayan durum. Tipik örnek: input alanının değeri, panelin açık/kapalı durumu, seçili öğe veya model snapshot'ı.
- **Element-local state** — yalnızca tek bir element'in iç durumu (örn. hover animasyon sayacı, virtualized list scroll offset). Stabil bir `id(...)` ile `window.with_element_state` veya `window.use_keyed_state` üzerinden tutulur. ID değişirse state sıfırlanır.
- **Frame callback** (`window.on_next_frame(...)`) — bir sonraki frame'in render'ından önce çalışacak callback.
- **Effect sonunda erteleme** (`cx.defer(...)`, `window.defer(cx, ...)`, `cx.defer_in(window, ...)`) — mevcut update effect'i bittikten sonra çalıştırılacak iş için.
- **Sürekli redraw** (`window.request_animation_frame()`) — bir sonraki frame için anında render isteği.

### Render katmanının trait'leri

- **`Render`** — entity/view state'ini her render'da element ağacına çevirir.
- **`RenderOnce`** — durum taşımayan hafif bileşenler için tek seferlik render.
- **`ParentElement`** — child kabul eden elementler. `.child(...)` ve `.children(...)` bu trait'le gelir.
- **`Styled`** — style refinement zincirine dahil olan elementler. `.flex()`, `.w(...)`, `.bg(...)` gibi method'lar burada tanımlıdır.
- **`InteractiveElement`** — focus, action, key, mouse, hover, drag/drop dinleyicileri ekler. `.on_click`, `.on_mouse_down`, `.track_focus` bu trait üzerindendir.
- **`StatefulInteractiveElement`** — `id(...)` çağrıldıktan sonra elde edilir; scroll, focus gibi stateful interaktif davranışları açar.

### `cx.notify()` ve `window.refresh()` arasındaki fark

- `cx.notify()` — view'ın render çıktısını etkileyen state değişikliklerinde çağrılır. GPUI ilgili view'ı bir sonraki frame'de yeniden render edilmek üzere işaretler. Çoğu durumda doğru seçenek budur.
- `window.refresh()` — tüm pencerenin yeniden çizimini ister; herhangi bir state değişikliği olmadan da pencere tamamen yeniden çizilir. Genelde tema, font ölçeği gibi pencerenin tamamını etkileyen değişikliklerde tercih edilir.

Local view state değişimleri için `cx.notify()` esastır; `refresh` daha kaba (ve daha pahalı) bir araçtır ve hedef daha dar olduğunda kullanılmaz.

## 4.3. Element Haritası

GPUI yerleşik element fabrikalarının küçük bir setini sağlar; tasarım sistemi katmanı (Zed UI) bunların üzerine kurulur. Aşağıda yerleşik elementler ve tipik kullanım yerleri:

- **`div()`** — Genel amaçlı container. Flex/grid layout, style zinciri, child, event, focus ve window-control area desteği içerir. UI'da en sık görülen elementtir.
- **Metin** — `&'static str`, `String`, `SharedString` doğrudan element olarak kullanılabilir; başka bir element'in `.child(...)` çağrısına geçirilen string otomatik olarak metin elementine dönüşür. Daha zengin metin (renkli aralık, link, kod span'i) için `StyledText` ve `InteractiveText` vardır.
- **`svg()`** — Gömülü path veya asset yoluyla SVG çizimi.
- **`img(...)`** — Asset, dosya yolu, URL veya byte kaynağı gibi farklı görsel kaynakları çizer. Loading ve fallback slotları içerir.
- **`canvas(prepaint, paint)`** — Düşük seviye, manuel çizim için. Bir prepaint kapaması ile bir paint kapaması alır; hitbox/cursor gibi prepaint gerektiren özel işlere uygundur.
- **`anchored()`** — Pencereye veya belirli bir noktaya sabitlenen popover, menu gibi UI parçaları için.
- **`deferred(child)`** — Child'ın layout'unu yerinde tutar ama paint'i ertelenmiş queue'ya alır; çizim sırası [Deferred Draw](#47-deferred-draw-prepaint-order-ve-overlay-katmanı) bölümünde açıklanır.
- **`list(...)`** — Değişken yükseklikli, büyük listeler için sanallaştırılmış element.
- **`uniform_list(...)`** — Item yükseklikleri sabit veya kolay ölçülen listeler için daha verimli sanallaştırma.
- **`surface(...)`** — Platform/native bir surface kaynağını (örn. video frame, harici GPU surface) element olarak gösterir.

### Sık kullanılan style grupları

Aşağıdaki method'lar fluent zincire eklenir ve hem `div()` üzerinde hem de `Styled` trait'ini implemente eden Zed UI bileşenleri üzerinde çalışır:

- *Layout*: `.flex()`, `.flex_col()`, `.flex_row()`, `.grid()`, `.items_center()`, `.justify_between()`, `.content_stretch()`, `.size_full()`, `.w(...)`, `.h(...)`.
- *Boşluklar (spacing)*: `.p_*`, `.px_*`, `.gap_*`, `.m_*` (Tailwind benzeri ölçek; örn. `.p_2()`, `.px_4()`).
- *Metin*: `.text_color(...)`, `.text_sm()`, `.text_xl()`, `.font_family(...)`, `.truncate()`, `.line_clamp(...)`.
- *Çerçeve ve şekil*: `.border_1()`, `.border_color(...)`, `.rounded_sm()`.
- *Konum*: `.absolute()`, `.relative()`, `.top(...)`, `.left(...)`.
- *Durum (state)*: `.hover(...)`, `.active(...)`, `.focus(...)`, `.focus_visible(...)`, `.group(...)`, `.group_hover(...)`.
- *Etkileşim*: `.on_click(...)`, `.on_mouse_down(...)`, `.on_scroll_wheel(...)`, `.on_key_down(...)`, `.on_action(...)`, `.track_focus(...)`, `.key_context(...)`.

Zed kodu yazılırken `gpui::prelude::*` yerine `ui::prelude::*` import edilmesi tercih edilir; bu prelude `gpui` prelude'unun yanına tasarım sistemi tiplerini (Button, Label, Icon, Theme renkleri vs.) de ekler.

## 4.4. Element ID, Element State ve Type Erasure

GPUI'de element ağacı her frame yeniden kurulur; bir önceki frame'deki element nesnesi bu frame'de aynı obje olarak var olmayabilir. Bu yüzden bir elementin kendine ait kalıcı state'i (örn. hover animasyon sayacı, virtualized list scroll konumu, image cache durumu) "obje kimliğinden" değil, **stabil bir ID'den** referanslanmak zorundadır. Aynı render konumunda aynı ID kullanıldığı sürece state korunur; ID değiştiği an state sıfırlanır.

### Temel tipler

- **`ElementId`** — Bir element için kimlik. `Name`, `Integer`, `NamedInteger`, `Path`, `Uuid`, `FocusHandle`, `CodeLocation` gibi varyantlarla farklı kaynaklardan inşa edilebilir.
- **`GlobalElementId`** — `ElementId`'nin parent namespace zinciriyle birleşmiş hâli. Aynı `ElementId` farklı parent'lar altında farklı `GlobalElementId`'ler üretir; bu sayede iki ayrı bölümdeki "row-0" elementleri çakışmaz.
- **`AnyElement`** — Element type erasure'ı. Child listelerinde farklı tipte elementleri aynı `Vec<AnyElement>` içinde tutmak için kullanılır.
- **`AnyView`, `AnyEntity`** — View veya entity için type erasure. Tip bilgisi runtime'a taşınır; gerektiğinde `.downcast()` ile geri çevrilir.

### Element state API'leri

State okuma/yazma `Window` üzerinde tanımlıdır ve yalnızca element çizimi sırasında (prepaint/paint fazlarında) çağrılır:

```rust
let row_state = window.use_keyed_state(
    ElementId::named_usize("row", row_ix),
    cx,
    |_, cx| RowState::new(cx),
);
```

Daha düşük seviyeli ihtiyaçlar için:

```rust
window.with_global_id("image-cache".into(), |global_id, window| {
    window.with_element_state::<MyState, _>(global_id, |state, window| {
        let mut state = state.unwrap_or_else(MyState::default);
        state.prepare(window);
        (state.snapshot(), state)
    })
});
```

### Kurallar

- `window.with_id(element_id, |window| { ... })` lokal element id stack'ine bir id push eder; `with_global_id` ise bu stack'i tek bir `GlobalElementId`'ye dönüştürür.
- **Liste item'larında `use_state` yerine `use_keyed_state` kullanılır.** `use_state` ID'yi caller location'dan üretir; aynı `for` döngüsündeki tüm item'lar aynı caller location'a sahip olduğu için ayırt edilemez ve state karışır.
- `with_element_namespace(id, ...)` custom element içinde child ID'lerin parent ID'leriyle çakışmasını önler.
- Aynı `GlobalElementId` ve aynı state tipi için **reentrant** `with_element_state` çağrısı panic eder; içeride aynı state'e tekrar girilmek istenirse iş `cx.defer(...)` ile bir sonraki effect cycle'a alınır.
- ID değiştiğinde önceki frame'in state'i devam etmez; animasyon, hover, scroll ve image cache state'i sıfırlanır.

### Type erasure ne zaman kullanılır

- *Public component API child kabul ediyorsa* `impl IntoElement` parametresi alınır; çağıranın verdiği somut element tipi API'nin dışına sızdırılmaz.
- *Struct alanında çocuk element saklanacaksa* `AnyElement` kullanılır; her child farklı tipte olabileceği için jenerik bir alan yetmez.
- *View/entity saklarken* mümkün olduğunca tipli `Entity<T>` tutulur. `AnyEntity` / `AnyView` yalnızca plugin sistemi, heterojen koleksiyon veya dock item gibi tipi önceden bilinemeyen alanlarda tercih edilir.

## 4.5. FluentBuilder ve Koşullu Element Üretimi

Element zinciri (`div().flex().bg(...)...`) okunaklı bir akış sağlar; ancak araya bir `if` veya `match` bloğu girdiğinde zincir kopar ve ifadenin bütünlüğü dağılır. `FluentBuilder` trait'i bu sorunu çözmek için tasarlanmıştır: koşullu mantığı zincirin içinde tutmaya yarayan yardımcı method'lar ekler. Kaynak: `crates/gpui/src/util.rs::FluentBuilder`.

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

Her yardımcının pratik anlamı:

- **`when(cond, |this| ...)`** — koşul `true` ise verilen kapama uygulanır; aksi halde element olduğu gibi geçer. En sık kullanılan helper'dır.
- **`when_else(cond, |this| ..., |this| ...)`** — koşula göre iki farklı dönüşümden biri uygulanır.
- **`when_some(option, |this, value| ...)`** — `Option` `Some(v)` ise kapama içeride `v` ile çalışır; `None` ise atlanır. Closure içinde `Option`'ı `unwrap` etmek gerekmez.
- **`when_none(&option, |this| ...)`** — `Option` `None` ise kapama çalışır (örn. "veri yok" mesajı yerleştirmek için).
- **`map(|this| ...)`** — keyfi dönüşüm için "kaçış kapısı". Zincirin dönüş tipini değiştirebilir; tipik kullanımı `match` ile dallandırmadır.

Tipik kullanım:

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

### Avantajlar

- Method chain bozulmadan koşullu UI yazılır; ifade tek bir akış olarak okunur.
- `when` ailesi closure içine geçen elementin tipini *değiştirmez*; bu sayede zincirin sonraki halkaları aynı tipin method'larını çağırmaya devam edebilir.
- `map`, zincirin dönüş tipini de değiştirebilen genel amaçlı bir dönüşüm sağlar; `match` ile dallandırma yapmak için kullanılır.

### Tuzaklar

- `when` kapaması **her render'da çalışır**; içine ağır hesap konulmaz. Pahalı bir değer önceden hesaplanıp closure'a kapatılır.
- Aynı element üzerinde uzun `when_some` zincirleri okunabilirliği bozduğunda, ilgili state önceden `if let` ile pre-compute edilip tek bir `.child(...)` çağrısıyla eklenir.
- `map` zincirin dönüş tipini değiştirebilir; buna karşın `when` ailesi tipi sabit tutar, bu yüzden style refinement zinciri devam ettirilebilir. `match` kollarının Rust gereği yine uyumlu tek bir dönüş tipinde birleşmesi gerekir.

## 4.6. Refineable, StyleRefinement ve MergeFrom

GPUI ve Zed iki ayrı birleştirme (composition) paterni kullanır: render sırasında stilleri katmanlandırmak için `Refineable`, settings/tema yüklemelerinde JSON katmanlarını birleştirmek için `MergeFrom`. İki patern farklı problem alanlarını çözer ama aynı temel fikri paylaşır: bir taban yapı üstüne kısmi bir "üst-yazım" uygulamak.

#### Refineable: render zincirinde stil katmanları

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

Trait'in dikkat çeken yanları:

- `type Refinement` da `Refineable` olmak zorundadır; yani bir refinement'ın kendisi de refine edilebilir. Örneğin `style_refinement_a.refine(&style_refinement_b)` zincirleme merge için kullanılır.
- `Refinement` ayrıca `IsEmpty + Default` zorunluluğu taşır. `IsEmpty`, "bu refinement uygulansa herhangi bir alan değişir mi?" sorusunu yanıtlar; merge optimizasyonu, layout cache invalidation ve `subtract` çıktısı bu kontrole dayanır.
- `is_superset_of(refinement)`, bir instance'ın halihazırda söz konusu refinement'ı kapsayıp kapsamadığını söyler; kapsıyorsa gereksiz `refine` çağrısı yapılmaz.
- `subtract(refinement)` aradaki farkı yeni bir refinement olarak verir (örn. iki temayı karşılaştırırken yalnızca değişen alanları çıkarmak için).
- `from_cascade(cascade)`, aşağıda anlatılan `Cascade` yapısını default değer üzerine uygular; tema/stil katmanlamasının sondaki "düzleştirme" adımıdır.

`#[derive(Refineable)]` (gpui re-export'u ile): orijinal struct'la aynı alanlara sahip ama her alanı `Option`'lı hâle getirilmiş `XRefinement` türünü üretir. `refine` çağrısı yalnızca `Some` olan alanları yazar; `None` alanlar "etki yok" anlamına gelir. Yaygın olarak kullanılan somut türler hep derive ile üretilir, elle yazılmaz:

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

Bu `*Refinement` tipleri uygulamada genellikle doğrudan adlandırılmaz; fluent API zinciri arka planda bir refinement toplar ve render sırasında base style üzerine uygular. Elle inşa etmenin tipik gerektiği tek tür `StyleRefinement`'tır; örneğin `.hover(|style| style.bg(...))` callback'inin imzasında bu refinement açıkça görülür.

Tipik kullanım (`crates/gpui/src/style.rs:178`):

```rust
let mut style = Style::default();
style.refine(&StyleRefinement::default()
    .text_size(px(20.))
    .font_weight(FontWeight::SEMIBOLD));
```

Element fluent zinciri (örn. `div().text_size(px(14.)).bg(rgb(0xff))`) arka planda bir `StyleRefinement` üretir; render sırasında base style üstüne `refine` edilir. `TextStyle`/`TextStyleRefinement`, `HighlightStyle`, `PlayerColors`, `ThemeColors` gibi tüm tema yapıları aynı pattern'i izler.

`refined(self, refinement)`, mevcut nesneyi değiştirmeden immutable bir kopya üretir; "ek style ile yeni bir base elde et" senaryolarında kullanılır.

#### Cascade ve CascadeSlot

`Refineable` tek başına iki katmanı (base + refinement) birleştirir. Daha derin akışlar (örn. base → tema override → hover → focus → active gibi sıralı katmanlar) için aynı crate bir katman yığını sağlar (`crates/refineable/src/refineable.rs:80,93`):

```rust
pub struct Cascade<S: Refineable>(Vec<Option<S::Refinement>>);
pub struct CascadeSlot(usize);
```

Temel API:

- `Cascade::default()` — slot 0'ı `Some(default)` ile kurar; ek slotlar başta `None`'dur. Slot 0 her zaman dolu kalır ve "base" refinement'ı tutar.
- `cascade.reserve() -> CascadeSlot` — yeni `None` slot ekler ve handle döndürür. Hover, focus, active gibi her dinamik katman için bir slot ayrılır.
- `cascade.base() -> &mut S::Refinement` — slot 0'ı mutable verir; layout başında asıl style buraya yazılır.
- `cascade.set(slot, Option<S::Refinement>)` — belirli bir slot'a refinement yerleştirir ya da `None` ile devre dışı bırakır.
- `cascade.merged() -> S::Refinement` — slot 0 üstüne diğer dolu slotları sırayla `refine` eder; sonraki slot önceki slotu ezer.
- `Refineable::from_cascade(&cascade) -> Self` — `default().refined(merged())` kısa yolu; render sırasında nihai stili üretmek için kullanılır.

**Önemli not — GPUI'nin kendi interaktif stil sistemi `Cascade` kullanmaz.** `.hover(...)`, `.active(...)`, `.focus(...)`, `.focus_visible(...)`, `.in_focus(...)`, `.group_hover(...)`, `.group_active(...)` zinciri arka planda `Cascade`/`CascadeSlot` yerine `Interactivity` struct'ında her durum için ayrı bir `Option<Box<StyleRefinement>>` alanı tutar (`elements/div.rs:1681+`'deki `hover_style`, `active_style`, `focus_style`, `in_focus_style`, `focus_visible_style`, `group_hover_style`, `group_active_style`). Render fazında bu refinement'lar sırayla `refine` edilir. Pratik sonucu: hover style'ına verilen `StyleRefinement::bg(...)` base background'u ezer; ancak hover style `font_size`'a dokunmuyorsa base'in `font_size`'ı korunur — `None` alan "etki yok" demektir.

`Cascade<S>` ve `CascadeSlot` arayüzü `refineable` crate'inde public olarak durur; ancak GPUI çekirdeği ve Zed bu sürümde içeriden kullanmaz. Üç veya daha fazla katmanlı refinement yığınını dışarıdan inşa etmek isteyen kütüphane yazarları için açık bir uzantı noktasıdır.

#### MergeFrom: settings ve tema katmanlarını birleştirme

`crates/settings_content/src/merge_from.rs`:

```rust
pub trait MergeFrom {
    fn merge_from(&mut self, other: &Self);
    fn merge_from_option(&mut self, other: Option<&Self>) {
        if let Some(other) = other { self.merge_from(other); }
    }
}
```

Default merge davranışı:

- *`HashMap`, `BTreeMap`, struct alanları* — derin merge: yalnızca `other`'da var olan alanlar üstüne yazılır.
- *`Option<T>`* — `None` mevcut değeri ezmez; `Some` recursive merge eder.
- *`Vec` ve primitive'ler* — tam üzerine yazma. (Vec append etmek için aşağıdaki `ExtendingVec` kullanılır.)

`#[derive(MergeFrom)]` derive'ı struct alanları için bu kurallara uygun recursive merge implementasyonu üretir. İki yardımcı sarıcı tip mevcuttur:

- **`ExtendingVec<T>`** — `Vec<T>` yerine kullanılır; her merge'te öncekinin sonuna eklenir (concat).
- **`SaturatingBool`** — bir kez `true` olduktan sonra `false` ile geri ezilmez.

Tipik Zed settings yükleme zinciri:

1. `assets/settings/default.json` parse edilir → `SettingsContent::default()` baz alınır.
2. Kullanıcı dosyası `~/.config/zed/settings.json` → `merge_from_option`.
3. Aktif profil → `merge_from_option`.
4. Worktree (proje kökü) `.zed/settings.json` → `merge_from_option`.
5. Sonuçtan `Settings::from_settings(content)` ile concrete struct türetilir.

Bu sıralamada en spesifik kaynak (worktree) en sona, en genel kaynak (default) en başa konur; sonraki katman önceki katmanın değerlerini ezebilir.

#### Tuzaklar

- `Refineable` zincirinde `default()` baz değeri her seferinde yeniden hesaplanır; ağır base style'lar varsa cache'lenmesi gerekir.
- `MergeFrom` sıralaması ters-yüz çalışmaz: en spesifik kaynak en sona, en genel kaynak en başa konur (`local > profile > user > default`). Yanlış sıralama "user ayarı default'u eziyor gibi görünür ama aslında tersine ezilir" tarzı sessiz hatalara yol açar.
- Vec'leri append etmek için `ExtendingVec` kullanılır; tam üzerine yazma istenen yerlerde düz `Vec` yeterlidir.
- `Option<Option<T>>` gibi iç içe `Option` yapıları `MergeFrom`'un default davranışıyla doğru birleşmeyebilir; bu tür alanlarda özel `impl MergeFrom` yazılır.

## 4.7. Deferred Draw, Prepaint Order ve Overlay Katmanı

`deferred(child)` çağrısı, child'ın **layout'unu yerinde** tutar — yani parent içindeki ölçü ve konum hesabı normal şekilde yapılır — ancak **paint'i ancestor paint'lerinden sonraya** erteler. Bu yapı, "konumu kendi parent'ına göre hesaplansın ama görsel olarak üst katmanda çizilsin" gereken parçalar için tasarlanmıştır. Tipik kullanım yerleri: context menu, dropdown, resize handle, dock drop overlay, modal arkaplan.

```rust
deferred(
    anchored()
        .anchor(Anchor::TopRight)
        .position(menu_position)
        .child(menu),
)
.with_priority(1)
```

Faz bazında davranış:

- `request_layout` — Child normal layout alır (sanki deferred olmasa yapacağı şey). Bu yüzden `anchored` gibi konum hesabı yapan child'lar parent bounds'a göre doğru çalışır.
- `prepaint` — Child `window.defer_draw(...)` çağrısıyla deferred queue'ya taşınır.
- `paint` — Deferred element kendi paint fazında bir şey çizmez; tüm normal paint'ler bittikten sonra deferred queue işlenir.
- `with_priority(n)` — Aynı frame içindeki deferred elementler arasında z-order belirler; yüksek priority üstte çizilir. Tüm pencerede geçerli global bir z-index *değildir*.

### `Div` prepaint yardımcıları

- `on_children_prepainted(|bounds, window, cx| { ... })` — Child'lar prepaint olduktan sonra onların bounds'larını ölçüp sonraki paint için state üretmek için kullanılır.
- `with_dynamic_prepaint_order(...)` — Child prepaint sırasını runtime'da belirler. Özellikle bir child'ın autoscroll veya ölçüm sonucu başka bir child'ı etkilediği durumlarda gerekir (örn. önce ölçülen menünün konumuna göre arka çubuğun çizilmesi).

### Tuzaklar

- Deferred child layout'ta yer tuttuğu için `absolute`/`anchored` konumlarının başvuru noktası hâlâ parent bounds'tır; "ekrandan bağımsız" değildir.
- Overlay altındaki mouse olaylarını engellemek gerekiyorsa child içinde `.occlude()` veya `.block_mouse_except_scroll()` kullanılır; aksi halde overlay altına tıklama altta kalan elementlere de gider.
- `with_priority` global bir z-index değildir, yalnızca **aynı frame içindeki deferred queue** için sıralama belirler. Farklı pencereler veya farklı frame'ler için z-order sağlanmaz.


---
