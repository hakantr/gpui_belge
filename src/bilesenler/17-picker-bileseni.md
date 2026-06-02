# 17. Picker Bileşeni

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Picker` | `focus_handle` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Picker` | Metotlar 1 | `cancel`, `cycle_selection`, `editor_move_down`, `editor_move_up`, `focus`, `is_scrolled_to_end`, `list`, `list_measure_all`, `max_height`, `nonsearchable_list`, `nonsearchable_uniform_list`, `query`, `refresh`, `refresh_placeholder` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Picker` | Metotlar 2 | `select_first`, `select_next`, `set_query`, `show_scrollbar`, `update_matches_with_options`, `widest_item`, `width` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Picker` | Alanlar | `delegate` | Public veri alanları; runtime, stil veya ayar sözleşmesinin taşınan parçalarıdır. |


`crates/picker/` komut paleti dışında da kullanılan genel bir seçim ve arama bileşenidir. Dosya bulucu, branch picker, command palette, model picker ve fuzzy seçim gerektiren her UI bunun üzerine kurarsın. Bu yapı yeniden kullanılabilir bir GPUI bileşeni olarak `bilesenler/` bölümünde yer alır.

---

## `PickerDelegate`

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `PickerDelegate` | Trait üyeleri 1 | `can_select`, `confirm`, `confirm_completion`, `confirm_input`, `confirm_update_query`, `dismissed`, `documentation_aside`, `documentation_aside_index`, `editor_position`, `finalize_update_matches`, `match_count`, `no_matches_text`, `placeholder_text`, `render_editor`, `render_footer` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `PickerDelegate` | Trait üyeleri 2 | `render_header`, `render_match`, `select_history`, `select_on_hover`, `selected_index`, `selected_index_changed`, `separators_after_indices`, `set_selected_index`, `should_dismiss`, `update_matches` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


Picker UI'ı kendisi durum tutmaz; tüm seçim mantığı bir `PickerDelegate` uygulaması üzerinden işler. Yeni bir picker yazılırken esas iş bu trait'i implement etmektir:

```rust
pub trait PickerDelegate: Sized + 'static {
    type ListItem: IntoElement;

    fn match_count(&self) -> usize;
    fn selected_index(&self) -> usize;
    fn set_selected_index(&mut self, ix: usize, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn placeholder_text(&self, window: &mut Window, cx: &mut App) -> Arc<str>;
    fn update_matches(&mut self, query: String, window: &mut Window, cx: &mut Context<Picker<Self>>) -> Task<()>;
    fn confirm(&mut self, secondary: bool, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn dismissed(&mut self, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn render_match(&self, ix: usize, selected: bool, window: &mut Window, cx: &mut Context<Picker<Self>>) -> Option<Self::ListItem>;
}
```

Minimum uygulama bu sekiz metottan ibarettir. Picker editöre yazılan her tuşta `update_matches`'i async çağırır; tamamlanma sonrasında liste yeniden çizilir.

---

## Sık üzerine yazılan davranışlar

Picker farklı senaryolara uydurmak için opsiyonel hook'lar sağlar:

- `select_history(Direction, sorgu, ...) -> Option<String>` — yukarı veya aşağı oklarını varsayılan seçim yerine sorgu geçmişinde gezdirmek için.
- `can_select(sira, ...)`, `select_on_hover()`, `selected_index_changed(...)` — seçebilirsin satırları ve hover/seçim yan etkilerini yönetir.
- `no_matches_text(...)`, `render_header(...)`, `render_footer(...)` — boş durum ile sabit üst ve alt alanlar.
- `render_editor(editor, window, cx)` — varsayılan arama editörü kabını değiştirir; custom padding, divider veya kompozisyon gerekiyorsa kullanılır.
- `documentation_aside(...)` ve `documentation_aside_index()` — seçili veya hover edilen öğe için sağda dokümantasyon paneli göstermek.
- `confirm_update_query(...)`, `confirm_input(...)`, `confirm_completion(...)` — enter'ın seçimi onaylamak yerine sorguyu dönüştürdüğü veya birebir girdiyi action'a çevirdiği picker türleri.
- `separators_after_indices()` — belirli satır indekslerinden sonra divider çizdirir; gruplu sonuç listelerinde görsel ayrım sağlar.
- `editor_position() -> PickerEditorPosition::{Start, End}` — arama editörünün listenin üstünde mi altında mı duracağını belirler.
- `finalize_update_matches(sorgu, sure, ...) -> bool` — arka plan eşleştirmesini kısa süreliğine bloklayarak ilk çizim ve onay yarışını azaltır.
- `should_dismiss() -> bool` — picker'ın confirm/dismiss akışında kapanıp kapanmayacağını belirleyen son karardır.

---

## Yapıcı seçimi

Picker üretmek için dört yapıcı vardır:

- `Picker::uniform_list(temsilci, window, cx)` — aramalı picker; tüm satırlar aynı yükseklikteyse tercih edilir ve `gpui::uniform_list` kullanır.
- `Picker::list(temsilci, window, cx)` — aramalı picker; satır yükseklikleri değişkense kullanırsın.
- `Picker::nonsearchable_uniform_list(...)` ve `Picker::nonsearchable_list(...)` — arama editörü olmayan seçim listeleri.

`uniform_list` `gpui::uniform_list` üzerinde sanallaştırma kullandığı için çok büyük listelerde tercih edersin. `list` `ListState` tabanlıdır; değişken satır yükseklikleri ölçülürken `list_measure_all()` ile her satır önceden ölçtürülür.

---

## Kullanılabilir ayarlar

Picker davranışı zincir üzerinden ince ayarlanır:

- `width(...)`, `max_height(...)`, `widest_item(...)` — ölçü ve liste genişliği.
- `show_scrollbar(bool)` — dış scrollbar gösterimi.
- `modal(bool)` — picker kendi başına modal gibi çiziliyorsa elevation verir; daha büyük bir modalın parçasıysa `false` yapılabilir.
- `list_measure_all()` — `ListState` tabanlı listede tüm öğeleri ölçmek için.
- `refresh(&mut self, window, cx)`, `update_matches_with_options(..., ScrollBehavior)` — eşleşme akışını dışarıdan tetikleyen değişebilen yardımcılar.
- `editor_move_up(...)`, `editor_move_down(...)`, `cycle_selection(...)` — picker'ın action binding'leri veya özel key handler'ları tarafından selection'ı hareket ettiren public yardımcılar.
- `refresh_placeholder(window, cx)` — delegate'in `placeholder_text(...)` sonucunu editor placeholder'ına tekrar yazar.
- `query(&self, cx: &App) -> String` — editördeki anlık sorguyu okur.
- `set_query(&self, sorgu: &str, window: &mut Window, cx: &mut App)` — editör metnini değiştirir; `&self` aldığına dikkat — picker entity'sini bir `update` bloğunun içine sokmak şart değildir, doğrudan picker referansından çağrılabilir. `cx` burada `Context<...>` değil `&mut App` olduğu için entity context gerekiyorsa update bloğundan dışarı çıkmak gerekebilir.

---

## Action ve key context

Picker kökü kendi key context'ini ve action dinleyicilerini kurar:

- Çizim kökü `"Picker"` key context'ini ekler.
- `menu::SelectNext`, `menu::SelectPrevious`, `menu::SelectFirst`, `menu::SelectLast`, `menu::Cancel`, `menu::Confirm`, `menu::SecondaryConfirm`, `picker::ConfirmCompletion` ve `picker::ConfirmInput` action'larını dinler.
- Tıklama onayı sırasında `cx.stop_propagation()` ve `window.prevent_default()` çağrılır; bu sayede picker satırına tıklama dış elementlere sızmaz.

---

## Highlighted match yardımcıları

`crates/picker/src/highlighted_match_with_paths.rs` public olarak iki hazır render yardımcısı sağlar:

- `HighlightedMatch`: `text`, `highlight_positions` ve `color` alanlarını taşıyan tek satırlık highlighted label. `IntoElement` implement eder.
- `HighlightedMatchWithPaths`: ana match label'ını, opsiyonel prefix'i, path parçalarını ve aktiflik işaretini birlikte render eder.

Temel API:

- `HighlightedMatch::join(components, separator) -> HighlightedMatch`: birden çok highlighted parçayı separator ile birleştirir ve byte offset'lerini güvenli şekilde taşır.
- `HighlightedMatch::color(color) -> HighlightedMatch`: label rengini değiştirir.
- `HighlightedMatchWithPaths::render_paths_children(element) -> Div`: path çocuklarını verilen container'a ekler.
- `HighlightedMatchWithPaths::is_active(active) -> HighlightedMatchWithPaths`: aktif satırda check icon gösterir.

Bu tipler özellikle file finder, branch picker veya symbol picker gibi path/label ayrımı yapan delegate'lerde kullanışlıdır. Sadece düz text satırı gerekiyorsa doğrudan `ListItem` ve `HighlightedLabel` kompozisyonu daha sade kalır.

---

## Picker public API kapsam tablosu

Picker crate'indeki public yardımcıların çoğu, `PickerDelegate` davranışını ayarlayan küçük taşıyıcılardır. Aşağıdaki tablo ayrı başlık gerektirmeyen ama API okurken bilinmesi gereken yüzeyi kapsar.

| API | Alt özellikler | Kullanım notu |
|-----|----------------|---------------|
| `ConfirmCompletion` | Action struct | Seçili completion'ı onaylayan `picker` namespace action'ıdır; delegate `confirm_completion` ile sorguyu güncelleyebilir. |
| `ConfirmInput` | `secondary` | Seçili satırı değil, editördeki ham input'u onaylar; secondary confirm bilgisini `secondary` alanıyla taşır. |
| `Direction` | `Up`, `Down` | `select_history` içinde yukarı/aşağı geçmiş gezinme yönünü belirtir. |
| `ScrollBehavior` | `RevealSelected`, `PreserveOffset` | Match güncellenirken seçili satıra scroll etme veya mevcut offset'i koruma kararını taşır. |
| `PickerEditorPosition` | `Start`, `End` | Arama editörünün listenin üstünde veya altında render edilmesini seçer. |
| `highlighted_match_with_paths` | Modül | Path'li fuzzy sonuçların label ve path parçalarını ayrı vurgulayan hazır render yardımcılarını barındırır. |
| `picker::popover_menu` | Modül | `PickerPopoverMenu` tipini barındırır; picker entity'sini `ui::PopoverMenu` trigger'ı arkasında açılan managed view haline getirir. |
| `HighlightedMatch` | `text`, `highlight_positions`, `color`; `join`, `color` | Tek label üzerindeki byte offset highlight bilgisini taşır; `join` parçaları birleştirirken offset'leri güvenli biçimde kaydırır. |
| `HighlightedMatchWithPaths` | `prefix`, `match_label`, `paths`, `active`; `render_paths_children`, `is_active` | Ana eşleşme label'ı, opsiyonel prefix, path satırları ve aktif satır check işaretini birlikte render eder. |

Bu tabloda `Up/Down`, `Start/End` gibi varyantlar için ayrıca alt başlık açmak gerekli değildir; isimleri doğrudan davranışı anlatır ve ilgili delegate hook'unda okunur.

---

## `PickerPopoverMenu`

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `PickerPopoverMenu` | `focus_handle` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `PickerPopoverMenu` | Metotlar | `new`, `offset`, `with_handle` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Picker'ı bir popover içine yerleştiren ince sarmalayıcıdır. `new(picker, trigger, tooltip, anchor, cx)` picker'ın `DismissEvent`'ini popover dismiss olayına bağlar; `with_handle(...)` ve `offset(...)` ile dış popover handle ve konum ayarı yaparsın. Picker bir toolbar butonu veya popover tetikleyicisi arkasında açılacaksa doğrudan modal yerine bu sarmalayıcı tercih edersin.

---

## Pratikteki picker örnekleri

Zed içinde picker üzerine kurulu çeşitli akışların kendine özgü davranışları vardır:

- `file_finder` artık `path:line-column` sorgularına ek olarak `path:start-end` satır aralıklarını da anlar. Örneğin `src/app.rs:12-20` dosyayı açıp ilgili satır aralığını seçer; aralık dosya sonunu aşarsa EOF'a kırpılır. Geçersiz veya ters aralıklar `PathWithPosition` davranışına düşer ve tek konuma gider. Sonda kalan tek satır iki noktası `path:12:` biçiminde temizlenir, fakat aralık biçimleri korunur.
- `git_ui::branch_picker::select_popover(...)` checkout yapmayan seçim popover'ı üretir. Bu mod `BranchSelectionBehavior::Select` kullanır, placeholder olarak `Select branch...` gösterir, footer ve silme aksiyonlarını sunmaz, seçimden sonra `DismissEvent` yayar ve verilen `SelectBranchCallback` ile seçilen `Branch` değerini dışarı taşır. Branch sıralama seçili branch'i, aktif remote üzerindeki branch'leri, aktif/upstream bağlamını ve kalanları önceliklendirir; aynı öncelikte yerel branch'ler uzak branch'lerden önce gelir.
- Komut paleti picker üzerinde `Picker::uniform_list` ile kurarsın. Sorgu eşleştirme, geçmiş gezinme ve secondary confirm davranışı [Çalışma Alanı → Komut Paleti](../calisma_alani/08-komut-paleti.md) bölümünde anlatılır.

---

## Tuzaklar

- `PickerDelegate::update_matches` `Task<()>` döner; arka plan eşleştirmesi tamamlanmadan satırların `match_count` üzerinde tutulması veri yarışmasına yol açar. Pratik akış mevcut sonuçları silmeden yenisini hesaplamak ve atomic değişimle `set_matches` yapmaktır.
- `selected_index` sınır dışı kalırsa picker boş çizilir; `update_matches` sonrasında index'in `min(match_count - 1, selected_index)` ile yenilenmesi sağlanmalıdır.
- `confirm` `cx.stop_propagation()` çağrısı varsayılan değildir; özel confirm akışında dış element'in olay almaması istenirse delegate kendi durumunu set ettikten sonra `window.prevent_default()` çağırmalıdır.
- `PickerPopoverMenu` `DismissEvent`'ini dışarıdaki popover'a aktardığı için picker'ın kendi `dismissed` hook'una yapılması gereken iş yine delegate üzerinde kalır; modal'a özel temizlik kodu burada yapılmalı, popover sarmalayıcısı temizlik yapmaz.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `HighlightedMatchWithPaths`

| Grup | API | Not |
|---|---|---|
| Metotlar | `is_active`, `render_paths_children` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `active`, `match_label`, `paths`, `prefix` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `HighlightedMatch`

| Grup | API | Not |
|---|---|---|
| Metotlar | `color`, `join` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `color`, `highlight_positions`, `text` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `Direction`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Down`, `Up` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ScrollBehavior`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `PreserveOffset`, `RevealSelected` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ConfirmInput`

| Grup | API | Not |
|---|---|---|
| Alanlar | `secondary` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PickerEditorPosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `End`, `Start` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
