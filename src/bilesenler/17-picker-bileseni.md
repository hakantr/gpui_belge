# 17. Picker Bileşeni

`picker` crate'i, komut paleti dışında da kullanılan genel bir seçim ve arama bileşenidir. Dosya bulucu, branch seçici, command palette, model seçici ve fuzzy seçim gerektiren her türlü kullanıcı arayüzü (UI) bunun üzerine kurulur. Bu yapı, yeniden kullanılabilir bir GPUI bileşeni olarak `bilesenler/` bölümünde yer alır.

---

## `PickerDelegate`

Picker UI bileşeni kendi içinde durum tutmaz; tüm seçim mantığı bir `PickerDelegate` uygulaması üzerinden işler. Yeni bir picker yazılırken esas iş bu trait'i uygulamaktır:

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

Minimum uygulama bu sekiz metottan ibarettir. Picker arama kutusuna yazılan her tuş vuruşunda `update_matches` metodunu asenkron olarak çağırır; mevcut eşleşme durumu hemen işlenir, task tamamlandığında da liste tekrar güncellenir.

---

## Sık Üzerine Yazılan Davranışlar

Picker, farklı senaryolara uyum sağlamak amacıyla opsiyonel ek davranış noktaları sağlar:

- `select_history(Direction, sorgu, ...) -> Option<String>`: Yukarı veya aşağı oklarını varsayılan seçim yerine sorgu geçmişinde gezdirmek için kullanılır.
- `can_select(sira, ...)`, `select_on_hover()`, `selected_index_changed(...)`: Seçilebilir satırları ve hover/seçim yan etkilerini yönetir.
- `no_matches_text(...)`, `render_header(...)`, `render_footer(...)`: Boş durum ile sabit üst ve alt alanlardır.
- `render_editor(editor, window, cx)`: Varsayılan arama kutusu kabını değiştirir; özel iç kenar boşluğu (padding), bölücü (divider) veya kompozisyon gerekiyorsa kullanılır.
- `documentation_aside(...)` ve `documentation_aside_index()`: Seçili veya üzerinde durulan (hover) öğe için sağda dokümantasyon paneli göstermek amacıyla tercih edilir.
- `confirm_update_query(...)`, `confirm_input(...)`, `confirm_completion(...)`: Enter tuşunun seçimi onaylamak yerine sorguyu dönüştürdüğü veya doğrudan girdiyi eyleme (action) çevirdiği picker türleridir.
- `separators_after_indices()`: Belirli satır indekslerinden sonra bölücü çizdirir; gruplandırılmış sonuç listelerinde görsel ayrım sağlar.
- `editor_position() -> PickerEditorPosition::{Start, End}`: Arama kutusunun listenin üstünde mi yoksa altında mı duracağını belirler.
- `finalize_update_matches(sorgu, sure, ...) -> bool`: Arka plan eşleştirmesini kısa süreliğine bloklayarak ilk çizim ve onay yarışını azaltır.
- `should_dismiss() -> bool`: Picker bileşeninin kapatma (dismiss) akışında kapanıp kapanmayacağını belirleyen son karardır.

---

## Yapıcı (Constructor) Seçimi

Picker üretmek için dört yapıcı mevcuttur:

- `Picker::uniform_list(temsilci, window, cx)`: Aramalı picker'dır; tüm satırlar aynı yükseklikteyse tercih edilir ve arka planda `gpui::uniform_list` kullanır.
- `Picker::list(temsilci, window, cx)`: Aramalı picker'dır; satır yükseklikleri değişkense kullanılır.
- `Picker::nonsearchable_uniform_list(...)` ve `Picker::nonsearchable_list(...)`: Arama kutusu olmayan seçim listeleridir.

`uniform_list` varyantı `gpui::uniform_list` üzerinde sanallaştırma kullandığı için çok büyük listelerde tercih edilir. `list` varyantı ise `ListState` tabanlıdır; değişken satır yükseklikleri ölçülürken `list_measure_all()` ile her satır önceden ölçtürülür.

---

## Kullanılabilir Ayarlar

Picker davranışı zincir üzerinden ince ayarlarla yapılandırılabilir:

- `width(...)`, `max_height(...)`, `widest_item(...)`: Ölçü ve liste genişliği ayarları.
- `show_scrollbar(bool)`: Dış kaydırma çubuğu gösterimi.
- `modal(bool)`: Picker kendi başına modal gibi çiziliyorsa elevation (yükseklik) verir; daha büyük bir modalın parçasıysa `false` yapılır.
- `list_measure_all()`: `ListState` tabanlı listede tüm öğeleri ölçmek için kullanılır.
- `refresh(&mut self, window, cx)`, `update_matches_with_options(..., ScrollBehavior)`: Eşleşme akışını dışarıdan tetikleyen yardımcı metotlardır.
- `editor_move_up(...)`, `editor_move_down(...)`, `cycle_selection(...)`: Picker'ın eylem bağlantıları veya özel tuş işleyicileri (key handlers) tarafından seçimi hareket ettiren dışa açık yardımcılardır.
- `refresh_placeholder(window, cx)`: Temsilcinin (delegate) `placeholder_text(...)` sonucunu arama kutusu placeholder alanına tekrar yazar.
- `query(&self, cx: &App) -> String`: Arama kutusundaki anlık sorguyu okur.
- `set_query(&self, sorgu: &str, window: &mut Window, cx: &mut App)`: Arama kutusu metnini değiştirir. Bu metodun `&self` aldığına dikkat edilmelidir; picker entity'sini bir `update` bloğunun içine sokmak şart değildir, doğrudan picker referansından çağrılabilir. `cx` burada `Context<...>` değil `&mut App` olduğu için entity bağlamı gerekiyorsa update bloğundan dışarı çıkmak gerekebilir.

---

## Eylem (Action) ve Tuş Bağlamı (Key Context)

Picker kökü kendi tuş bağlamını ve eylem dinleyicilerini kurar:

- Çizim kökü `"Picker"` key context'ini ekler.
- `menu::SelectNext`, `menu::SelectPrevious`, `menu::SelectFirst`, `menu::SelectLast`, `menu::Cancel`, `menu::Confirm`, `menu::SecondaryConfirm`, `editor::MoveUp`, `editor::MoveDown`, `picker::ConfirmCompletion` ve `picker::ConfirmInput` eylemlerini dinler. `editor::MoveUp` ve `editor::MoveDown` yukarı/aşağı seçim hareketini editör eylemi olarak da karşılar.
- Tıklama onayı sırasında `cx.stop_propagation()` ve `window.prevent_default()` çağrılır; bu sayede picker satırına tıklama dış elementlere sızmaz.

---

## Vurgulu Eşleşme (Highlighted Match) Yardımcıları

`picker` crate'i dışa açık olarak iki hazır render yardımcısı sağlar:

- `HighlightedMatch`: `text`, `highlight_positions` ve `color` alanlarını taşıyan tek satırlık vurgulanmış etikettir (highlighted label). `IntoElement` implement eder.
- `HighlightedMatchWithPaths`: Ana eşleşme etiketini, isteğe bağlı prefix'i, yol (path) parçalarını ve aktiflik işaretini birlikte render eder.

Temel API:

- `HighlightedMatch::join(components, separator) -> HighlightedMatch`: Birden çok vurgulanmış parçayı bir ayırıcı ile birleştirir ve byte offset'lerini güvenli şekilde taşır.
- `HighlightedMatch::color(color) -> HighlightedMatch`: Etiket rengini değiştirir.
- `HighlightedMatchWithPaths::render_paths_children(element) -> Div`: Path çocuklarını verilen container'a ekler.
- `HighlightedMatchWithPaths::is_active(active) -> HighlightedMatchWithPaths`: Aktif satırda check ikonunu gösterir.

Bu tipler özellikle dosya bulucu, branch picker veya sembol seçici gibi yol/etiket ayrımı yapan temsilcilerde (delegate) kullanışlıdır. Sadece düz metin satırı gerekiyorsa doğrudan `ListItem` ve `HighlightedLabel` kompozisyonu daha sade bir çözüm sunar.

---

## Picker Dışa Açık API Kapsam Tablosu

Picker crate'indeki dışa açık yardımcıların çoğu, `PickerDelegate` davranışını ayarlayan küçük taşıyıcılardır. Aşağıdaki tablo ayrı başlık gerektirmeyen ama API okurken bilinmesi gereken yüzeyi kapsar.

| API | Alt özellikler | Kullanım notu |
|-----|----------------|---------------|
| `ConfirmCompletion` | Action struct | Seçili tamamlama eylemini onaylayan `picker` ad alanı eylemidir; temsilci `confirm_completion` ile sorguyu güncelleyebilir. |
| `ConfirmInput` | `secondary` | Seçili satırı değil, arama kutusundaki ham girdiyi onaylar; secondary confirm bilgisini `secondary` alanıyla taşır. |
| `Direction` | `Up`, `Down` | `select_history` içinde yukarı/aşağı geçmiş gezinme yönünü belirtir. |
| `ScrollBehavior` | `RevealSelected`, `PreserveOffset` | Eşleşme güncellenirken seçili satıra kaydırma yapma veya mevcut offset'i koruma kararını taşır. |
| `PickerEditorPosition` | `Start`, `End` | Arama kutusunun listenin üstünde veya altında render edilmesini seçer. |
| `highlighted_match_with_paths` | Modül | Yol içeren fuzzy sonuçların etiket ve yol parçalarını ayrı ayrı vurgulayan hazır render yardımcılarını barındırır. |
| `picker::popover_menu` | Modül | `PickerPopoverMenu` tipini barındırır; picker entity'sini `ui::PopoverMenu` tetikleyicisi arkasında açılan yönetilen bir görünüm (view) haline getirir. |
| `HighlightedMatch` | `text`, `highlight_positions`, `color`; `join`, `color` | Tek label üzerindeki byte offset vurgu bilgisini taşır; `join` parçaları birleştirirken offset'leri güvenli biçimde kaydırır. |
| `HighlightedMatchWithPaths` | `prefix`, `match_label`, `paths`, `active`; `render_paths_children`, `is_active` | Ana eşleşme etiketi, isteğe bağlı prefix, yol satırları ve aktif satır check işaretini birlikte render eder. |

---

## `PickerPopoverMenu`

Picker'ı bir popover içine yerleştiren ince sarmalayıcıdır. `new(picker, trigger, tooltip, anchor, cx)` yapıcı metodu picker'ın `DismissEvent`'ini popover kapatma olayına bağlar; `with_handle(...)` ve `offset(...)` ile dış popover handle ve konum ayarları yapılır. Picker bir araç çubuğu butonu veya popover tetikleyicisi arkasında açılacaksa doğrudan modal yerine bu sarmalayıcı tercih edilir.

---

## Pratikteki Picker Örnekleri

Zed içinde picker üzerine kurulu çeşitli akışların kendine özgü davranışları vardır:

- `file_finder` hem `path:line-column` sorgularını hem de `path:start-end` satır aralıklarını anlar. Örneğin `src/app` dosyasını açıp ilgili satır aralığını seçer; aralık dosya sonunu aşarsa EOF'a kırpılır. Ters sayısal aralık (örneğin `10-5`) başlangıç satırını tek konum olarak kullanır; aralık olarak değil, yalnızca o satıra gider. Yalnız başlangıcı sayısal olmayan ya da tümüyle bozuk bir aralık ise `PathWithPosition` ayrıştırmasına düşer. Sonda kalan tek iki nokta üst üste işareti `path:12:` biçiminde temizlenir, ancak aralık biçimleri korunur.
- `git_ui::branch_picker::select_popover(...)` dal değiştirme (checkout) yapmayan seçim popover'ı üretir. Bu mod `BranchSelectionBehavior::Select` kullanır, placeholder olarak `Select branch…` gösterir, footer ve silme aksiyonlarını sunmaz, seçim yapıldığında `SelectBranchCallback` ile seçilen `Branch` değerini dışarı taşır ve ardından `DismissEvent` yayar. Dal sıralaması seçili dalı en öne alır; aktif dalın remote'undaki diğer dallar sonra gelir. Kayan dallar ile aktif/upstream eşleşmeleri ayrı önceliklere ayrılır; aynı öncelikte yerel dallar uzak dallardan önce gelir.
- Komut paleti picker arayüzü `Picker::uniform_list` ile kurulur. Sorgu eşleştirme, geçmiş gezinme ve ikincil onay (secondary confirm) davranışları [Çalışma Alanı → Komut Paleti](../calisma_alani/08-komut-paleti.md) bölümünde detaylandırılmıştır.

---

## Dikkat Noktaları

- `PickerDelegate::update_matches` metodu `Task<()>` döner; arka plan eşleştirmesi tamamlanmadan satır sayısını ve seçim durumunu uyumsuz bırakmak tutarsız seçim davranışına yol açar. Pratik akış mevcut sonuçları silmeden yenisini hesaplamak ve tek durum değişimiyle `matches` ile `selected_index` değerini birlikte güncellemektir.
- `selected_index` sınır dışı kalırsa liste yine `match_count()` ile sürüldüğü için satırlar çizilir; yalnız hiçbir satır seçili görünmez, picker boş çizilmez. Yine de seçimin kaybolmaması için `update_matches` sonrasında `match_count == 0` durumu ayrı ele alınır, diğer durumlarda indeks `min(match_count - 1, selected_index)` formülüyle yenilenir.
- Tıklama onayı picker tarafından `cx.stop_propagation()` ve `window.prevent_default()` ile sarılır. Klavye veya özel onay eyleminde bu çağrılar otomatik değildir; dış elementin olay almaması gerekiyorsa delegate kendi durumunu set ettikten sonra ilgili yayılım/varsayılan davranışı ayrıca yönetmelidir.
- `PickerPopoverMenu` `DismissEvent`'ini dışarıdaki popover'a aktardığı için picker'ın kendi `dismissed` kancasına (hook) yapılması gereken iş yine delegate üzerinde kalır; modal'a özel temizlik kodu burada yazılır, popover sarmalayıcısı temizlik yapmaz.
