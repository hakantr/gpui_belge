# Bölüm X — Liste ve Sanallaştırma

---

## 60. ScrollHandle ve Scroll Davranışı

`crates/gpui/src/elements/div.rs:3387+`.

`ScrollHandle`, scroll offset'ini paylaşılabilir bir handle olarak temsil eder.
`Rc<RefCell<ScrollHandleState>>` üzerinden çalışır, view'lar arasında klonlanabilir.

Public API:

- `ScrollHandle::new()`
- `offset() -> Point<Pixels>`: anlık scroll konumu.
- `max_offset() -> Point<Pixels>`
- `top_item()`, `bottom_item()`: görünür ilk/son child item dizini.
- `bounds()`: scroll container bounds.
- `bounds_for_item(ix)`: child bounds.
- `scroll_to_item(ix)`, `scroll_to_top_of_item(ix)`: prepaint zamanında istenen
  item'a scroll eder.
- `scroll_to_bottom()`
- `set_offset(point)`: offset'i doğrudan ayarlar. Offset içerik origin'inin
  parent origin'ine uzaklığıdır; aşağı kaydıkça Y genelde negatife gider.
- `logical_scroll_top()`, `logical_scroll_bottom()`: görünür child index'i ve
  child içi pixel offset'i döndürür.
- `children_count()`: scroll edilen child sayısı.

Element üzerine bağlama:

```rust
let handle = ScrollHandle::new();

div()
    .id("list")
    .overflow_y_scroll()
    .track_scroll(&handle)
    .child(/* ... */)
```

`overflow_scroll`, `overflow_x_scroll`, `overflow_y_scroll` `StatefulInteractiveElement`
metotlarıdır; pratikte önce `.id(...)` çağırıp `Stateful<Div>` üretmen gerekir.
Overflow `Scroll` olduğunda input wheel/touch event'i bu container içinde tüketilir.
`track_scroll` aynı handle'ı render geçişleri arasında bağlar; aynı handle başka
yerden okunabilir ve değiştirilebilir.

`ScrollAnchor` (`div.rs:3332+`) bir handle ile çalışan helper'dır; immediate child
olmasa bile belirli bir element'in görünür kalmasını ister:

```rust
let anchor = ScrollAnchor::for_handle(handle.clone());
anchor.scroll_to(window, cx);
```

Tuzaklar:

- `id(...)` çağırmadan `overflow_*_scroll` çalışmaz; element interaktif değildir.
- `track_scroll` çağırılmadan handle değerleri eski kalır; offset güncel olmaz.
- Klavye ile scroll dispatch için `.on_key_down(...)` veya action ile
  `scroll_to_item` çağrılır; otomatik klavye scroll yoktur.

Liste elementlerinde ayrı state/handle tipleri vardır:

- `ListState`: `scroll_by`, `scroll_to`, `scroll_to_reveal_item`, `scroll_to_end`,
  `set_follow_mode(FollowMode::Tail)`, `logical_scroll_top`,
  `is_scrolled_to_end`, `is_following_tail`.
- `UniformListScrollHandle`: `scroll_to_item(..., ScrollStrategy)`,
  `scroll_to_item_strict`, `scroll_to_item_with_offset`,
  `scroll_to_item_strict_with_offset`, `logical_scroll_top_index`,
  `is_scrolled_to_end`, `scroll_to_bottom`.

Büyük listelerde doğrudan `ScrollHandle` yerine bu listeye özel
`ListState`/`UniformListScrollHandle` API'lerini kullanmak doğru sonuç verir.

## 61. List ve UniformList Sanallaştırma

GPUI'de büyük listeler için iki çekirdek element vardır:

- `list(state, render_item)`: item yükseklikleri farklı olabilir. Ölçüm cache'i
  `ListState` içindedir.
- `uniform_list(id, item_count, render_range)`: tüm item'lar aynı yükseklikteyse
  daha hızlıdır; ilk/örnek item ölçülür ve görünür range çizilir.

Değişken yükseklikli liste:

```rust
struct LogView {
    rows: Vec<Row>,
    list_state: ListState,
}

impl LogView {
    fn new() -> Self {
        Self {
            rows: Vec::new(),
            list_state: ListState::new(0, ListAlignment::Top, px(300.)),
        }
    }

    fn replace_rows(&mut self, rows: Vec<Row>, cx: &mut Context<Self>) {
        self.rows = rows;
        self.list_state.reset(self.rows.len());
        cx.notify();
    }
}
```

Render:

```rust
list(self.list_state.clone(), |ix, window, cx| {
    render_row(ix, window, cx).into_any_element()
})
.with_sizing_behavior(ListSizingBehavior::Auto)
```

`ListState` yönetimi:

- `new(item_count, alignment, overdraw)`: builder.
- `measure_all()` (consuming): `ListMeasuringBehavior::Measure(false)` set ederek
  scrollbar boyutunun yalnızca render edilmiş elementlere değil, **tüm liste**
  ölçümüne dayanmasını sağlar.
- `item_count() -> usize`: o anki item sayısı.
- `reset(count)`: tüm item seti değişti.
- `splice(old_range, count)`: aralık değişti; scroll offset'i korunur.
- `splice_focusable(old_range, focus_handles)`: focusable item'ları sanallaştırırken
  focus handle dizisi geçilir; aksi halde görünür olmayan focused item render
  dışı kalabilir.
- `remeasure()`: font/theme gibi tüm yükseklikleri etkileyen değişim.
- `remeasure_items(range)`: streaming text veya lazy content gibi belirli item'lar.
- `set_follow_mode(FollowMode::Tail)`: chat/log gibi tail-follow davranışı.
- `is_following_tail() -> bool`: aktif takip durumu.
- `is_scrolled_to_end() -> Option<bool>`: en alta scroll mu? `None` henüz layout
  yapılmamışsa.
- `scroll_by(distance)`, `scroll_to_end()`, `scroll_to(ListOffset)`,
  `scroll_to_reveal_item(ix)`.
- `logical_scroll_top() -> ListOffset`: aktif scroll konumu.
- `bounds_for_item(ix) -> Option<Bounds<Pixels>>`: render edilmişse item rect'i.
- `set_scroll_handler(...)`: görünür range ve follow state takibi.

Custom scrollbar API'si (kendi scrollbar widget'ını yazıyorsan; `ui::Scrollbars`
zaten bu metotlar üzerinde kuruludur):

- `viewport_bounds() -> Bounds<Pixels>`: en son layout edilmiş viewport rect'i.
- `scroll_px_offset_for_scrollbar() -> Point<Pixels>`: scrollbar için adapte
  edilmiş güncel scroll konumu.
- `max_offset_for_scrollbar() -> Point<Pixels>`: ölçülmüş item'lara göre maksimum
  scroll. Drag sırasında bu değer sabit kalır ki scrollbar sıçramasın.
- `set_offset_from_scrollbar(point)`: scrollbar drag/click'inden gelen offset'i
  uygular.
- `scrollbar_drag_started()` / `scrollbar_drag_ended()`: drag sırasında overdraw
  ölçümünden kaynaklı yükseklik dalgalanmasını dondurmak/serbest bırakmak için.
  Drag'a girerken started, bırakırken ended çağırmazsan scrollbar drag boyunca
  beklenmedik şekilde sürünebilir.

Uniform liste:

```rust
let scroll_handle = self.scroll_handle.clone();

uniform_list("search-results", self.items.len(), move |range, window, cx| {
    range
        .map(|ix| render_result(ix, window, cx))
        .collect()
})
.track_scroll(&scroll_handle)
.with_width_from_item(Some(0))
```

`UniformListScrollHandle`:

- `scroll_to_item(ix, ScrollStrategy::Nearest)`
- `scroll_to_item_strict(ix, ScrollStrategy::Center)`
- `scroll_to_item_with_offset(ix, strategy, offset)`
- `scroll_to_bottom()`
- `is_scrollable()`, `is_scrolled_to_end()`
- `y_flipped(true)`: item 0 altta olacak şekilde ters akış.

Karar:

- Item yükseklikleri gerçekten aynıysa `uniform_list`.
- Yükseklik değişebiliyorsa `list` ve doğru `splice`/`remeasure` çağrıları.
- Focusable item'lar sanallaştırılıyorsa `splice_focusable` ile focus handle ver;
  aksi halde görünür olmayan focused item render dışı kalabilir.


---

