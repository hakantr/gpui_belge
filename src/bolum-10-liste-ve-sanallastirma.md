# 10. Liste ve Sanallaştırma

---

## 10.1. ScrollHandle ve Scroll Davranışı

Kaynak: `crates/gpui/src/elements/div.rs:3387+`.

`ScrollHandle`, scroll offset'ini birden fazla view arasında paylaşılabilir bir handle olarak temsil eder. İçeride `Rc<RefCell<ScrollHandleState>>` tutar ve clone'lanır; aynı handle hem scroll container'a hem de scrollbar/programatik scroll yapan kodlara verilerek senkron tutulabilir. Sıradan `div()` scroll'u için yeterlidir; büyük listeler için ayrı, sanallaştırma destekli state tipleri kullanılır (bkz. 10.2).

### Public API

- **`ScrollHandle::new()`** — Yeni boş handle.
- **`offset() -> Point<Pixels>`** — O anki scroll konumu.
- **`max_offset() -> Point<Pixels>`** — Maksimum scroll mesafesi.
- **`top_item()`, `bottom_item()`** — Görünür ilk/son child item dizini.
- **`bounds()`** — Scroll container bounds.
- **`bounds_for_item(ix)`** — Belirli bir child'ın bounds'u.
- **`scroll_to_item(ix)`, `scroll_to_top_of_item(ix)`** — Prepaint zamanında istenen item'a scroll eder.
- **`scroll_to_bottom()`** — Aşağıya kaydırır.
- **`set_offset(point)`** — Offset'i doğrudan ayarlar. Offset içerik origin'inin parent origin'ine uzaklığıdır; aşağı kaydırıldıkça Y genelde negatife gider.
- **`logical_scroll_top()`, `logical_scroll_bottom()`** — Görünür child index'i ve child içi pixel offset'i.
- **`children_count()`** — Scroll edilen child sayısı.

### Element üzerine bağlama

```rust
let handle = ScrollHandle::new();

div()
    .id("list")
    .overflow_y_scroll()
    .track_scroll(&handle)
    .child(/* ... */)
```

`overflow_scroll`, `overflow_x_scroll`, `overflow_y_scroll` method'ları `StatefulInteractiveElement` üzerindedir; pratikte önce `.id(...)` çağrılarak `Stateful<Div>` üretilmesi gerekir. Overflow `Scroll` olduğunda wheel/touch event'i bu container içinde tüketilir. `track_scroll` aynı handle'ı render geçişleri arasında bağlar; handle başka yerden okunabilir ve değiştirilebilir.

### Belirli element'i görünür tutma — `ScrollAnchor`

`ScrollAnchor` (`div.rs:3332+`) bir handle ile çalışan helper'dır; doğrudan child olmasa bile belirli bir element'in görünür kalmasını ister:

```rust
let anchor = ScrollAnchor::for_handle(handle.clone());
anchor.scroll_to(window, cx);
```

### Tuzaklar

- **`.id(...)` çağrılmadan `overflow_*_scroll` çalışmaz;** element interaktif değildir, scroll event'leri yakalanmaz.
- **`track_scroll` çağrılmadan handle değerleri eski kalır;** offset, programatik okuma için güncel olmaz.
- **Klavye ile scroll otomatik değildir.** Page-up/page-down gibi tuşları yakalamak için `.on_key_down(...)` veya action ile `scroll_to_item` çağrılır.

### Liste-özgü state tipleri

Sıradan `div().overflow_y_scroll()` küçük scroll alanları için uygundur; büyük listelerde (binlerce satır) sanallaştırma gerekir ve aşağıdaki tipler kullanılır:

- **`ListState`** (değişken yükseklik için) — `scroll_by`, `scroll_to`, `scroll_to_reveal_item`, `scroll_to_end`, `set_follow_mode(FollowMode::Tail)`, `logical_scroll_top`, `is_scrolled_to_end`, `is_following_tail`.
- **`UniformListScrollHandle`** (sabit yükseklik için) — `scroll_to_item(..., ScrollStrategy)`, `scroll_to_item_strict`, `scroll_to_item_with_offset`, `scroll_to_item_strict_with_offset`, `logical_scroll_top_index`, `is_scrolled_to_end`, `scroll_to_bottom`.

Büyük listelerde doğrudan `ScrollHandle` yerine bu liste-özel API'ler tercih edilir; ölçüm cache'i ve sanallaştırma davranışı bunlara entegre çalışır.

## 10.2. List ve UniformList Sanallaştırma

Büyük listelerde tüm item'ları element ağacına eklemek hem layout hem paint açısından sürdürülemezdir. **Sanallaştırma**, yalnızca o an görünür (ve overdraw için ekstra birkaç) item'ın oluşturulmasıdır; ekran dışındakiler render edilmez. GPUI bu amaçla iki ayrı çekirdek element sunar; aralarındaki seçim item yüksekliklerinin sabit olup olmamasına göre yapılır.

- **`list(state, render_item)`** — Item yükseklikleri **değişken** olabilir; ölçüm cache'i `ListState` içinde tutulur. Daha esnek ama biraz daha pahalı.
- **`uniform_list(id, item_count, render_range)`** — Tüm item'lar **aynı yükseklikteyse** kullanılır; örnek bir item ölçülür ve görünür range matematiksel olarak hesaplanır. Daha hızlı.

### Değişken yükseklikli liste

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

#### `ListState` yönetimi

- **`new(item_count, alignment, overdraw)`** — Builder.
- **`measure_all()`** *(consuming)* — `ListMeasuringBehavior::Measure(false)` set ederek scrollbar boyutunun yalnızca render edilmiş elementlere değil, **tüm liste** ölçümüne dayanmasını sağlar.
- **`item_count() -> usize`** — O anki item sayısı.
- **`reset(count)`** — Tüm item seti değişti (yeniden ölçüm gereklidir).
- **`splice(old_range, count)`** — Aralık değişti; scroll offset'i korunur. Insert/delete senaryolarında kullanılır.
- **`splice_focusable(old_range, focus_handles)`** — Focusable item'lar sanallaştırılırken focus handle dizisi geçilir; aksi halde görünür olmayan focused item render dışı kalabilir.
- **`remeasure()`** — Font/theme gibi tüm yükseklikleri etkileyen değişim sonrası.
- **`remeasure_items(range)`** — Streaming text veya lazy content gibi belirli item'lar için.
- **`set_follow_mode(FollowMode::Tail)`** — Chat/log gibi "yeni içerik geldikçe en alta kal" davranışı.
- **`is_following_tail() -> bool`** — Aktif takip durumu.
- **`is_scrolled_to_end() -> Option<bool>`** — En alta scroll edilmiş mi? `None` ise henüz layout yapılmamıştır.
- **`scroll_by(distance)`, `scroll_to_end()`, `scroll_to(ListOffset)`, `scroll_to_reveal_item(ix)`** — Scroll komutları.
- **`logical_scroll_top() -> ListOffset`** — Aktif scroll konumu.
- **`bounds_for_item(ix) -> Option<Bounds<Pixels>>`** — Render edilmiş item'ın rect'i.
- **`set_scroll_handler(...)`** — Görünür range ve follow state takibi için callback.

#### Custom scrollbar API'si

Kendi scrollbar widget'ı yazılırken (`ui::Scrollbars` zaten bunların üstüne kurulmuştur) ek method'lar gerekir:

- **`viewport_bounds() -> Bounds<Pixels>`** — En son layout edilmiş viewport rect'i.
- **`scroll_px_offset_for_scrollbar() -> Point<Pixels>`** — Scrollbar için adapte edilmiş scroll konumu.
- **`max_offset_for_scrollbar() -> Point<Pixels>`** — Ölçülmüş item'lara göre maksimum scroll. **Drag sırasında bu değer sabit kalır** ki scrollbar sıçramasın.
- **`set_offset_from_scrollbar(point)`** — Scrollbar drag/click'inden gelen offset'i uygular.
- **`scrollbar_drag_started()` / `scrollbar_drag_ended()`** — Drag sırasında overdraw ölçümünden kaynaklı yükseklik dalgalanmasını dondurmak/serbest bırakmak için. Drag'a girerken `started`, bırakırken `ended` çağrılmazsa scrollbar drag boyunca beklenmedik şekilde sürünebilir.

### Uniform liste

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

`UniformListScrollHandle` method'ları:

- **`scroll_to_item(ix, ScrollStrategy::Nearest)`** — Sadece gerekirse kaydırır.
- **`scroll_to_item_strict(ix, ScrollStrategy::Center)`** — Belirtilen strateji ile zorla kaydırır.
- **`scroll_to_item_with_offset(ix, strategy, offset)`** — Hizalama sonrası ek kayma.
- **`scroll_to_bottom()`** — En alta gider.
- **`is_scrollable()`, `is_scrolled_to_end()`** — Durum sorguları.
- **`y_flipped(true)`** — Item 0 altta olacak şekilde ters akış (chat/log için).

### Hangi list seçilir

- *Item yükseklikleri **gerçekten aynıysa*** `uniform_list` tercih edilir; matematiksel hesaplama yüksek FPS sağlar.
- *Yükseklikler değişiyorsa* `list` ve doğru `splice` / `remeasure` çağrıları kullanılır.
- *Focusable item'lar sanallaştırılıyorsa* `splice_focusable` ile focus handle dizisi de verilir; aksi halde görünür olmayan ama odakta olan item render dışı kalır ve klavye girdisini kaybeder.


---

