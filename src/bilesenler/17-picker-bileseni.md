# 17. Picker Bileşeni

`picker` crate'i komut paleti dışında da kullanılan genel bir seçim ve arama bileşenidir. Dosya bulucu, branch seçici, command palette, model seçici ve fuzzy seçim gerektiren her UI bunun üzerine kurarsın. Bu yapı yeniden kullanılabilir bir GPUI bileşeni olarak `bilesenler/` bölümünde yer alır.

---

## `PickerDelegate`

Picker UI'ı kendisi durum tutmaz; tüm seçim mantığı bir `PickerDelegate` uygulaması üzerinden işler. Yeni bir picker yazılırken esas iş bu trait'i uygulamaktır:

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

Minimum uygulama bu sekiz metottan ibarettir. Picker editöre yazılan her tuşta `update_matches`'i async çağırır; mevcut eşleşme state'i hemen işlenir, task tamamlandığında da liste tekrar güncellenir.

---

## Sık üzerine yazılan davranışlar

Picker farklı senaryolara uydurmak için opsiyonel ek davranış noktaları sağlar:

- `select_history(Direction, sorgu, ...) -> Option<String>` — yukarı veya aşağı oklarını varsayılan seçim yerine sorgu geçmişinde gezdirmek için.
- `can_select(sira, ...)`, `select_on_hover()`, `selected_index_changed(...)` — seçilebilir satırları ve hover/seçim yan etkilerini yönetir.
- `no_matches_text(...)`, `render_header(...)`, `render_footer(...)` — boş durum ile sabit üst ve alt alanlar.
- `render_editor(editor, window, cx)` — varsayılan arama editörü kabını değiştirir; özel padding, divider veya kompozisyon gerekiyorsa kullanılır.
- `documentation_aside(...)` ve `documentation_aside_index()` — seçili veya hover edilen öğe için sağda dokümantasyon paneli göstermek.
- `confirm_update_query(...)`, `confirm_input(...)`, `confirm_completion(...)` — enter'ın seçimi onaylamak yerine sorguyu dönüştürdüğü veya birebir girdiyi action'a çevirdiği picker türleri.
- `separators_after_indices()` — belirli satır indekslerinden sonra divider çizdirir; gruplu sonuç listelerinde görsel ayrım sağlar.
- `editor_position() -> PickerEditorPosition::{Start, End}` — arama editörünün listenin üstünde mi altında mı duracağını belirler.
- `finalize_update_matches(sorgu, sure, ...) -> bool` — arka plan eşleştirmesini kısa süreliğine bloklayarak ilk çizim ve onay yarışını azaltır.
- `should_dismiss() -> bool` — picker'ın cancel/dismiss akışında kapanıp kapanmayacağını belirleyen son karardır.

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
- `editor_move_up(...)`, `editor_move_down(...)`, `cycle_selection(...)` — picker'ın action binding'leri veya özel key handler'ları tarafından selection'ı hareket ettiren dışa açık yardımcılar.
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

`picker` crate'i dışa açık olarak iki hazır render yardımcısı sağlar:

- `HighlightedMatch`: `text`, `highlight_positions` ve `color` alanlarını taşıyan tek satırlık highlighted label. `IntoElement` implement eder.
- `HighlightedMatchWithPaths`: ana match label'ını, opsiyonel prefix'i, path parçalarını ve aktiflik işaretini birlikte render eder.

Temel API:

- `HighlightedMatch::join(components, separator) -> HighlightedMatch`: birden çok highlighted parçayı separator ile birleştirir ve byte offset'lerini güvenli şekilde taşır.
- `HighlightedMatch::color(color) -> HighlightedMatch`: label rengini değiştirir.
- `HighlightedMatchWithPaths::render_paths_children(element) -> Div`: path çocuklarını verilen container'a ekler.
- `HighlightedMatchWithPaths::is_active(active) -> HighlightedMatchWithPaths`: aktif satırda check icon gösterir.

Bu tipler özellikle file finder, branch picker veya symbol picker gibi path/label ayrımı yapan delegate'lerde kullanışlıdır. Sadece düz metin satırı gerekiyorsa doğrudan `ListItem` ve `HighlightedLabel` kompozisyonu daha sade kalır.

---

## Picker Dışa Açık API Kapsam Tablosu

Picker crate'indeki dışa açık yardımcıların çoğu, `PickerDelegate` davranışını ayarlayan küçük taşıyıcılardır. Aşağıdaki tablo ayrı başlık gerektirmeyen ama API okurken bilinmesi gereken yüzeyi kapsar.

| API | Alt özellikler | Kullanım notu |
|-----|----------------|---------------|
| `ConfirmCompletion` | Action struct | Seçili completion'ı onaylayan `picker` namespace action'ıdır; delegate `confirm_completion` ile sorguyu güncelleyebilir. |
| `ConfirmInput` | `secondary` | Seçili satırı değil, editördeki ham input'u onaylar; secondary confirm bilgisini `secondary` alanıyla taşır. |
| `Direction` | `Up`, `Down` | `select_history` içinde yukarı/aşağı geçmiş gezinme yönünü belirtir. |
| `ScrollBehavior` | `RevealSelected`, `PreserveOffset` | Match güncellenirken seçili satıra scroll etme veya mevcut offset'i koruma kararını taşır. |
| `PickerEditorPosition` | `Start`, `End` | Arama editörünün listenin üstünde veya altında render edilmesini seçer. |
| `highlighted_match_with_paths` | Modül | Path'li fuzzy sonuçların label ve path parçalarını ayrı vurgulayan hazır render yardımcılarını barındırır. |
| `picker::popover_menu` | Modül | `PickerPopoverMenu` tipini barındırır; picker entity'sini `ui::PopoverMenu` trigger'ı arkasında açılan yönetilen view haline getirir. |
| `HighlightedMatch` | `text`, `highlight_positions`, `color`; `join`, `color` | Tek label üzerindeki byte offset highlight bilgisini taşır; `join` parçaları birleştirirken offset'leri güvenli biçimde kaydırır. |
| `HighlightedMatchWithPaths` | `prefix`, `match_label`, `paths`, `active`; `render_paths_children`, `is_active` | Ana eşleşme label'ı, opsiyonel prefix, path satırları ve aktif satır check işaretini birlikte render eder. |

Bu tabloda `Up/Down`, `Start/End` gibi varyantlar için ayrıca alt başlık açmak gerekli değildir; isimleri doğrudan davranışı anlatır ve ilgili delegate hook'unda okunur.

---

## `PickerPopoverMenu`

Picker'ı bir popover içine yerleştiren ince sarmalayıcıdır. `new(picker, trigger, tooltip, anchor, cx)` picker'ın `DismissEvent`'ini popover dismiss olayına bağlar; `with_handle(...)` ve `offset(...)` ile dış popover handle ve konum ayarı yaparsın. Picker bir toolbar butonu veya popover tetikleyicisi arkasında açılacaksa doğrudan modal yerine bu sarmalayıcı tercih edersin.

---

## Pratikteki picker örnekleri

Zed içinde picker üzerine kurulu çeşitli akışların kendine özgü davranışları vardır:

- `file_finder` hem `path:line-column` sorgularını hem de `path:start-end` satır aralıklarını anlar. Örneğin `src/app` dosyayı açıp ilgili satır aralığını seçer; aralık dosya sonunu aşarsa EOF'a kırpılır. Geçersiz veya ters aralıklar `PathWithPosition` davranışına düşer ve tek konuma gider. Sonda kalan tek satır iki noktası `path:12:` biçiminde temizlenir, fakat aralık biçimleri korunur.
- `git_ui::branch_picker::select_popover(...)` checkout yapmayan seçim popover'ı üretir. Bu mod `BranchSelectionBehavior::Select` kullanır, placeholder olarak `Select branch…` gösterir, footer ve silme aksiyonlarını sunmaz, seçimde `SelectBranchCallback` ile seçilen `Branch` değerini dışarı taşır ve ardından `DismissEvent` yayar. Branch sıralama seçili branch'i en öne alır; aktif branch'in remote'undaki diğer branch'ler sonra gelir. Kalan branch'ler ile aktif/upstream eşleşmeleri ayrı önceliklere ayrılır; aynı öncelikte yerel branch'ler uzak branch'lerden önce gelir.
- Komut paleti picker üzerinde `Picker::uniform_list` ile kurarsın. Sorgu eşleştirme, geçmiş gezinme ve secondary confirm davranışı [Çalışma Alanı → Komut Paleti](../calisma_alani/08-komut-paleti.md) bölümünde anlatılır.

---

## Dikkat Noktaları

- `PickerDelegate::update_matches` `Task<()>` döner; arka plan eşleştirmesi tamamlanmadan satır sayısını ve seçim state'ini uyumsuz bırakmak tutarsız seçim davranışı üretir. Pratik akış mevcut sonuçları silmeden yenisini hesaplamak ve tek state değişimiyle `matches` ile `selected_index` değerini birlikte güncellemektir.
- `selected_index` sınır dışı kalırsa picker boş çizilir; `update_matches` sonrasında `match_count == 0` durumu ayrı ele alınmalı, diğer durumlarda index `min(match_count - 1, selected_index)` ile yenilenmelidir.
- Tıklama onayı picker tarafından `cx.stop_propagation()` ve `window.prevent_default()` ile sarılır. Klavye veya özel confirm action'ında bu çağrılar otomatik değildir; dış element'in olay almaması gerekiyorsa delegate kendi durumunu set ettikten sonra ilgili propagation/default davranışını ayrıca yönetmelidir.
- `PickerPopoverMenu` `DismissEvent`'ini dışarıdaki popover'a aktardığı için picker'ın kendi `dismissed` hook'una yapılması gereken iş yine delegate üzerinde kalır; modal'a özel temizlik kodu burada yapılmalı, popover sarmalayıcısı temizlik yapmaz.
