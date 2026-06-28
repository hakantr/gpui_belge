# 17. Picker Bileşeni

## Sürüm Analiz Raporu

- [x] Kaynak commit aralığı: `f88bc7e18aeb..46ff888db853`.
- [x] Doğrulanan picker yüzeyi: `Picker::select_query`, `ErasedEditor::select_all`, `(Picker && with_preview) > Editor` key context'i ve preview layout kalıcılığı.
- [x] Kaynak doğrulama dosyaları: `crates/picker/src/picker.rs`, `crates/picker/src/render.rs`, `crates/picker/src/persistence.rs` ve `crates/ui_input/src/ui_input.rs`.

`picker` crate'i, komut paleti dışında da kullanılan genel bir seçim ve arama bileşenidir. Dosya bulucu, branch seçici, command palette, model seçici ve fuzzy seçim gerektiren her türlü kullanıcı arayüzü (UI) bunun üzerine kurulur. Bu yapı, yeniden kullanılabilir bir GPUI bileşeni olarak `bilesenler/` bölümünde yer alır.

---

## `PickerDelegate`

Picker UI bileşeni kendi içinde durum tutmaz; tüm seçim mantığı bir `PickerDelegate` uygulaması üzerinden işler. Yeni bir picker yazılırken esas iş bu trait'i uygulamaktır:

```rust
pub trait PickerDelegate: Sized + 'static {
    type ListItem: IntoElement;

    fn name() -> &'static str;
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

Minimum uygulama bu dokuz metottan ibarettir. `name()` değeri picker'ın kalıcı ayar anahtarıdır; delegate tipinin Rust adından türetilmez, çünkü tip yeniden adlandırmaları kullanıcıya ait preview yerleşimi gibi kalıcı tercihleri bozabilir. Picker arama kutusuna yazılan her tuş vuruşunda `update_matches` metodunu asenkron olarak çağırır; mevcut eşleşme durumu hemen işlenir, task tamamlandığında da liste tekrar güncellenir.

---

## Sık Üzerine Yazılan Davranışlar

Picker, farklı senaryolara uyum sağlamak amacıyla opsiyonel ek davranış noktaları sağlar:

- `select_history(Direction, sorgu, ...) -> Option<String>`: Yukarı veya aşağı oklarını varsayılan seçim yerine sorgu geçmişinde gezdirmek için kullanılır.
- `can_select(sira, ...)`, `select_on_hover()`, `selected_index_changed(...)`: Seçilebilir satırları ve hover/seçim yan etkilerini yönetir.
- `has_another_open_menu(window, cx)`: Delegate tarafından açılan ek popover veya menüler varken picker'ın blur ile kapanmasını engelleyen tamamlayıcı kontroldür.
- `searchbar_trailer(window, cx)`: Arama çubuğunun sağ ucuna filtre, toggle veya küçük action elementi ekler; tüm arama kutusu yeniden çizilecekse `render_editor(...)` daha geniş yüzey sağlar.
- `no_matches_text(...)`, `render_header(...)`, `render_footer(...)`: Boş durum ile sabit üst ve alt alanlardır. Footer normalde yalnız `render_footer(...)` döndüğünde veya preview etkin olduğunda görünür.
- `render_editor(editor, window, cx)`: Varsayılan arama kutusu kabını değiştirir; özel iç kenar boşluğu (padding), bölücü (divider) veya kompozisyon gerekiyorsa kullanılır.
- `try_get_preview_data_for_match(cx) -> Option<PreviewUpdate>` ve `preview_layout_changed(layout_is_horizontal)`: Seçili eşleşme için preview içeriğini ve preview sağda/aşağıda konumlandığında satır render uyarlamasını yönetir.
- `actions_menu(window, cx) -> Vec<PickerAction>`: Footer içinde `Actions` menüsü açılmasını sağlar; preview yönü, gizleme/gösterme veya delegate'e özel eylemler bu listeyle sunulur.
- `documentation_aside(...)` ve `documentation_aside_index()`: Seçili veya üzerinde durulan (hover) öğe için sağda dokümantasyon paneli göstermek amacıyla tercih edilir.
- `confirm_update_query(...)`, `confirm_input(...)`, `confirm_completion(...)`: Enter tuşunun seçimi onaylamak yerine sorguyu dönüştürdüğü veya doğrudan girdiyi eyleme (action) çevirdiği picker türleridir.
- `separators_after_indices()`: Belirli satır indekslerinden sonra bölücü çizdirir; gruplandırılmış sonuç listelerinde görsel ayrım sağlar.
- `editor_position() -> PickerEditorPosition::{Start, End}`: Arama kutusunun listenin üstünde mi yoksa altında mı duracağını belirler.
- `finalize_update_matches(sorgu, sure, ...) -> bool`: Arka plan eşleştirmesini kısa süreliğine bloklayarak ilk çizim ve onay yarışını azaltır.
- `should_dismiss() -> bool`: Picker bileşeninin kapatma (dismiss) akışında kapanıp kapanmayacağını belirleyen son karardır.

---

## Yapıcı (Constructor) Seçimi

Picker üretmek için aramalı, aramasız ve preview destekli altı yapıcı mevcuttur:

- `Picker::uniform_list(temsilci, window, cx)`: Aramalı picker'dır; tüm satırlar aynı yükseklikteyse tercih edilir ve arka planda `gpui::uniform_list` kullanır.
- `Picker::list(temsilci, window, cx)`: Aramalı picker'dır; satır yükseklikleri değişkense kullanılır.
- `Picker::uniform_list_with_preview(temsilci, project, window, cx)`: Sabit satır yüksekliğiyle çalışan ve sağda veya altta preview paneli açabilen picker üretir.
- `Picker::list_with_preview(temsilci, project, window, cx)`: Değişken satır yüksekliğiyle çalışan ve preview paneli taşıyan picker üretir.
- `Picker::nonsearchable_uniform_list(...)` ve `Picker::nonsearchable_list(...)`: Arama kutusu olmayan seçim listeleridir.

`uniform_list` varyantı `gpui::uniform_list` üzerinde sanallaştırma kullandığı için çok büyük listelerde tercih edilir. `list` varyantı ise `ListState` tabanlıdır; değişken satır yükseklikleri ölçülürken `list_measure_all()` ile her satır önceden ölçtürülür. Preview'lu constructor'lar `Project` entity'si alır; `PreviewSource::Path` ve `PreviewSource::Buffer` akışları bu proje bağlamı üzerinden editör önizlemesine bağlanır.

---

## Kullanılabilir Ayarlar

Picker davranışı zincir üzerinden ince ayarlarla yapılandırılabilir:

- `initial_width(width)`: Picker'ın ilk açılış genişliğini `RelativeWidth` uyumlu bir değerle belirler. Preview taşımayan sade picker'larda bu genişlik aynı zamanda sonuç alanının minimum genişliği olarak ele alınır; böylece picker açıldığı ölçünün altına sıkışmaz.
- `max_height(height)`: Picker'ın üst yükseklik sınırını `RelativeHeight` uyumlu bir değerle belirler. Preview gizliyken içerik azsa picker bu sınırın altında kalabilir; preview sağda veya altta görünürken yüksekliği dolduran daha geniş yerleşim kullanılır.
- `show_scrollbar(bool)`: Dış kaydırma çubuğu gösterimi.
- `embedded()`: Picker'ı dış bir modal veya panelin içine gömülü olarak sunar; kendi elevated container ve blur ile kapanma davranışını çizmez.
- `popover()`: Picker'ı menu/popover tetikleyicisine bağlı bir yüzey olarak sunar; kendi elevated container'ını çizer, fakat resize davranışı etkinleşmez.
- `resizable(bool)`: Modal picker'ın sürüklenerek yeniden boyutlandırılıp boyutunun kalıcılaştırılıp kalıcılaştırılmayacağını belirler. Preview içeren modallar varsayılan olarak yeniden boyutlandırılabilir, sade picker'lar varsayılan olarak sabit kalır.
- `list_measure_all()`: `ListState` tabanlı listede tüm öğeleri ölçmek için kullanılır.
- `refresh(&mut self, window, cx)`, `update_matches_with_options(..., ScrollBehavior)`: Eşleşme akışını dışarıdan tetikleyen yardımcı metotlardır.
- `editor_move_up(...)`, `editor_move_down(...)`, `cycle_selection(...)`: Picker'ın eylem bağlantıları veya özel tuş işleyicileri (key handlers) tarafından seçimi hareket ettiren dışa açık yardımcılardır.
- `refresh_placeholder(window, cx)`: Temsilcinin (delegate) `placeholder_text(...)` sonucunu arama kutusu placeholder alanına tekrar yazar.
- `query(&self, cx: &App) -> String`: Arama kutusundaki anlık sorguyu okur.
- `set_query(&self, sorgu: &str, window: &mut Window, cx: &mut App)`: Arama kutusu metnini değiştirir. Bu metodun `&self` aldığına dikkat edilmelidir; picker entity'sini bir `update` bloğunun içine sokmak şart değildir, doğrudan picker referansından çağrılabilir. `cx` burada `Context<...>` değil `&mut App` olduğu için entity bağlamı gerekiyorsa update bloğundan dışarı çıkmak gerekebilir.
- `select_query(&self, window, cx)`: Arama kutusundaki tüm sorguyu seçer. Seed edilmiş veya dışarıdan `set_query(...)` ile yazılmış sorgularda ilk klavye girdisinin mevcut metni tek adımda değiştirmesi hedeflendiğinde kullanılır.

Varsayılan ölçüler iki sabit üzerinden okunur: `DEFAULT_MODAL_WIDTH = Rems(34.0)` ve `DEFAULT_MODAL_MAX_HEIGHT = Rems(24.0)`. `shape::Centered::simple()` sade picker için bu değerleri kullanır. Preview layout'u gizliyken aynı sade ölçü korunur; preview sağda veya altta açıldığında `default_shape_for_layout(...)` daha geniş preview odaklı yerleşimi seçer. Boyut kalıcılığı `KeyValueStore` içinde `pickers_v2` ad alanına yazılır; anahtarlar delegate `name()` değeri ile preview layout adını birlikte taşır (`hidden`, `below`, `right`, `none`). Preview konumu değiştirildiğinde son layout tercihi de aynı delegate adıyla saklanır; preview sonradan kapansa bile bir sonraki preview'lu açılış bu son yön bilgisinden devam eder. Bu ad alanı, güncel picker ölçü sözleşmesinin ayrı ve tutarlı şekilde yüklenmesini sağlar.

---

## Preview ve Footer API'si

Preview destekli picker'lar `Preview` editor alanını kendi içinde yönetir. Temsilci seçili eşleşme için `try_get_preview_data_for_match(cx)` metodundan `PreviewUpdate` döndürdüğünde picker, kaynak türüne göre preview içeriğini günceller. Crate kökü bu tipi `picker::preview::Update` üzerinden `PreviewUpdate` adıyla yeniden dışa aktarır. `PreviewUpdate` iki parçadan oluşur: içeriğin nereden okunacağını belirleyen `PreviewSource` ve vurgulanacak konumu taşıyan isteğe bağlı `MatchLocation`.

- `PreviewSource::Path(PathBuf)`: Mutlak dosya yolunu preview editöründe açar.
- `PreviewSource::Buffer(Entity<Buffer>)`: Zaten elde bulunan `Buffer` entity'sini preview içine bağlar.
- `PreviewSource::Message(HighlightedText)`: Dosya veya buffer yerine merkezde vurgulu bir açıklama gösterir.
- `PreviewUpdate::from_path(...)`, `PreviewUpdate::from_buffer(...)` ve `PreviewUpdate::message(...)`: En yaygın üç update biçimini kısa yoldan üretir.
- `MatchLocation { anchor_range, range }`: Hem highlight anchor aralığını hem de scroll için byte/offset aralığını taşır.

Footer, delegate'in `render_footer(...)` çıktısı varsa onu kullanır. Özel footer yoksa ve picker preview ile kurulduysa, varsayılan footer preview kontrollerini ve `actions_menu(...)` sonucunu gösterir. `PickerAction` enum'u bu eylem menüsünün satırlarını modellemektedir: `PickerAction::button(label, action)` tıklanabilir satır üretir, `PickerAction::header(label)` başlık satırı ekler, `PickerAction::separator()` grupları ayırır ve `.toggled(bool)` bir action satırını işaretli/işaretsiz gösterir.

Picker kök eylemleri preview ve actions menüsünü doğrudan yönetir: `TogglePreview`, `SetPreviewRight`, `SetPreviewBelow`, `SetPreviewHidden`, `ToggleActionsMenu` ve `ToMultiBuffer`. `ToMultiBuffer`, preview içeriğini çoklu buffer akışına taşıyan özel eylemdir; diğerleri preview panelinin görünürlüğünü ve konumunu değiştirir.

`PickerDelegate::name()` değeri preview layout tercihleri için kalıcılık anahtarı olarak kullanılır. Aynı logical picker için kararlı bir string seçilmesi, kullanıcı tercihinin delegate tipi yeniden düzenlense bile korunmasını sağlar.

---

## Eylem (Action) ve Tuş Bağlamı (Key Context)

Picker kökü kendi tuş bağlamını ve eylem dinleyicilerini kurar:

- Çizim kökü `"Picker"` key context'ini ekler.
- Preview paneli bulunan picker'larda aynı kök context'e `"with_preview"` etiketi de eklenir. Bu nedenle preview'a özgü kısayollar `(Picker && with_preview) > Editor` bağlamında tutulur; `ToggleActionsMenu` gibi preview bağımsız eylemler ise `Picker > Editor` bağlamında kalır.
- `menu::SelectNext`, `menu::SelectPrevious`, `menu::SelectFirst`, `menu::SelectLast`, `menu::Cancel`, `menu::Confirm`, `menu::SecondaryConfirm`, `editor::MoveUp`, `editor::MoveDown`, `picker::ConfirmCompletion`, `picker::ConfirmInput`, `picker::TogglePreview`, `picker::SetPreviewRight`, `picker::SetPreviewBelow`, `picker::SetPreviewHidden` ve `picker::ToggleActionsMenu` eylemlerini dinler. `editor::MoveUp` ve `editor::MoveDown` yukarı/aşağı seçim hareketini editör eylemi olarak da karşılar.
- Tıklama onayı sırasında `cx.stop_propagation()` ve `window.prevent_default()` çağrılır; bu sayede picker satırına tıklama dış elementlere sızmaz.

---

## Vurgulu Eşleşme (Highlighted Match) Yardımcıları

`picker` crate'i dışa açık olarak iki hazır render yardımcısı sağlar:

- `HighlightedMatch`: `text`, `highlight_positions` ve `color` alanlarını taşıyan tek satırlık vurgulanmış etikettir (highlighted label). `IntoElement` implement eder.
- `HighlightedMatchWithPaths`: Ana eşleşme etiketini, isteğe bağlı prefix'i, yol (path) parçalarını ve aktiflik işaretini birlikte render eder.
- `HighlightedText` ve `HighlightedTextBuilder`: Preview mesajları gibi editor dışı vurgulu metin taşıyıcılarında kullanılır; `picker` crate kökü bu tipleri `language` crate'inden yeniden dışa aktarır.

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
| `DEFAULT_MODAL_WIDTH` | `Rems(34.0)` | Preview taşımayan modal picker'ın standart açılış genişliğidir. |
| `DEFAULT_MODAL_MAX_HEIGHT` | `Rems(24.0)` | Preview gizliyken sade picker'ın içerik azaldığında altına inebildiği standart üst yükseklik sınırıdır. |
| `Direction` | `Up`, `Down` | `select_history` içinde yukarı/aşağı geçmiş gezinme yönünü belirtir. |
| `ScrollBehavior` | `RevealSelected`, `PreserveOffset` | Eşleşme güncellenirken seçili satıra kaydırma yapma veya mevcut offset'i koruma kararını taşır. |
| `PickerEditorPosition` | `Start`, `End` | Arama kutusunun listenin üstünde veya altında render edilmesini seçer. |
| `Picker::select_query` | `window`, `cx` | Arama kutusundaki tüm sorguyu seçer; seed edilmiş sorgunun ilk yazımda değiştirilmesini sağlar. |
| `TogglePreview`, `SetPreviewRight`, `SetPreviewBelow`, `SetPreviewHidden`, `ToggleActionsMenu`, `ToMultiBuffer` | Action struct | Preview paneli, actions menüsü ve preview içeriğini multi-buffer akışına taşıma davranışlarını tetikler. |
| `RelativeWidth`, `RelativeHeight`, `ViewportFraction` | `FULL`, `viewport`, `rems`, `from_pixels`, `as_pixels` | Picker genişlik, yükseklik ve preview bölücü ölçülerini viewport oranı ile `Rems` toplamı olarak temsil eden ölçü tipleridir. |
| `Preview` | `new_editor`, `update`, `render`, `adjust_to_new_size` | Preview panelinin editor tabanlı içeriğini yönetir; picker constructor'ları tarafından oluşturulur. |
| `PreviewSource` | `Path`, `Buffer`, `Message` | Preview içeriğinin dosya yolu, hazır buffer veya vurgulu mesajdan üretileceğini seçer. |
| `picker::preview::Update` | `source`, `match_location`; `from_path`, `from_buffer`, `message` | Preview güncellemesinin asıl modül içi tip adıdır; crate kökü aynı tipi `PreviewUpdate` adıyla yeniden dışa aktarır. |
| `PreviewUpdate` | `source`, `match_location`; `from_path`, `from_buffer`, `message` | Delegate'in seçili eşleşme için preview içeriğini güncelleme sözleşmesidir. |
| `MatchLocation` | `anchor_range`, `range` | Preview içinde hem highlight hem de scroll hedefini taşır. |
| `PickerAction` | `button`, `header`, `separator`, `toggled` | Footer `Actions` menüsünün başlık, ayırıcı ve action satırlarını modelleyen public enum'dur. |
| `HighlightedText`, `HighlightedTextBuilder` | Vurgulu mesaj metni | Preview mesajları veya açıklama satırları için parça bazlı vurgulu metin üretir. |
| `ErasedEditor` | Tip silmeli editor köprüsü | Arama kutusu editor'ünü delegate ve özel render akışlarında crate sınırını bozmadan taşır. |
| `highlighted_match_with_paths` | Modül | Yol içeren fuzzy sonuçların etiket ve yol parçalarını ayrı ayrı vurgulayan hazır render yardımcılarını barındırır. |
| `picker::parts` | Modül | Birden çok picker tarafından kullanılan küçük görsel parçaları toplar; şu an dışa açık ana yardımcısı `project_scan_indicator` fonksiyonudur. |
| `picker::parts::project_scan_indicator` | `has_query`, `project`, `cx` | Proje taraması sürerken ve sorgu mevcutken dönen `LoadCircle` göstergesini üretir; tarama tamamlandıysa `None` döner. |
| `picker::popover_menu` | Modül | `PickerPopoverMenu` tipini barındırır; picker entity'sini `ui::PopoverMenu` tetikleyicisi arkasında açılan yönetilen bir görünüm (view) haline getirir. |
| `HighlightedMatch` | `text`, `highlight_positions`, `color`; `join`, `color` | Tek label üzerindeki byte offset vurgu bilgisini taşır; `join` parçaları birleştirirken offset'leri güvenli biçimde kaydırır. |
| `HighlightedMatchWithPaths` | `prefix`, `match_label`, `paths`, `active`; `render_paths_children`, `is_active` | Ana eşleşme etiketi, isteğe bağlı prefix, yol satırları ve aktif satır check işaretini birlikte render eder. |
| `HighlightedText`, `HighlightedTextBuilder` | language re-export | Preview mesajları ve editor dışı vurgulu açıklamalar için ortak vurgulu metin modelidir. |
| `ErasedEditor` | ui_input re-export | `PickerDelegate::render_editor(...)` içinde kullanılan tip silmeli input editor sözleşmesidir. |

---

## `PickerPopoverMenu`

Picker'ı bir popover içine yerleştiren ince sarmalayıcıdır. `new(picker, trigger, tooltip, anchor, cx)` yapıcı metodu picker'ın `DismissEvent`'ini popover kapatma olayına bağlar ve picker entity'si üzerinde `set_popover()` çağırarak sunumu `Presentation::Popover` davranışına geçirir. Böylece picker kendi elevated yüzeyini çizer, fakat modal'a özgü resize kalıcılığı devreye girmez. `with_handle(...)` ve `offset(...)` ile dış popover handle ve konum ayarları yapılır. Picker bir araç çubuğu butonu veya popover tetikleyicisi arkasında açılacaksa doğrudan modal yerine bu sarmalayıcı tercih edilir.

---

## Pratikteki Picker Örnekleri

Zed içinde picker üzerine kurulu çeşitli akışların kendine özgü davranışları vardır:

- `file_finder` hem `path:line-column` sorgularını hem de `path:start-end` satır aralıklarını anlar. Örneğin `src/app` dosyasını açıp ilgili satır aralığını seçer; aralık dosya sonunu aşarsa EOF'a kırpılır. Ters sayısal aralık (örneğin `10-5`) başlangıç satırını tek konum olarak kullanır; aralık olarak değil, yalnızca o satıra gider. Yalnız başlangıcı sayısal olmayan ya da tümüyle bozuk bir aralık ise `PathWithPosition` ayrıştırmasına düşer. Sonda kalan tek iki nokta üst üste işareti `path:12:` biçiminde temizlenir, ancak aralık biçimleri korunur.
- `git_ui::branch_picker::select_popover(...)` dal değiştirme (checkout) yapmayan seçim popover'ı üretir. Bu mod `BranchSelectionBehavior::Select` kullanır, placeholder olarak `Select branch…` gösterir, footer ve silme aksiyonlarını sunmaz, seçim yapıldığında `SelectBranchCallback` ile seçilen `Branch` değerini dışarı taşır ve ardından `DismissEvent` yayar. Dal sıralaması seçili dalı en öne alır; aktif dalın remote'undaki diğer dallar sonra gelir. Kayan dallar ile aktif/upstream eşleşmeleri ayrı önceliklere ayrılır; aynı öncelikte yerel dallar uzak dallardan önce gelir.
- Komut paleti picker arayüzü `Picker::uniform_list` ile kurulur. Sorgu eşleştirme, geçmiş gezinme ve ikincil onay (secondary confirm) davranışları [Çalışma Alanı → Komut Paleti](../calisma_alani/08-komut-paleti.md) bölümünde detaylandırılmıştır.

---

## Dikkat edilmesi gereken noktalar

- `PickerDelegate::update_matches` metodu `Task<()>` döner; arka plan eşleştirmesi tamamlanmadan satır sayısını ve seçim durumunu uyumsuz bırakmak tutarsız seçim davranışına yol açar. Pratik akış mevcut sonuçları silmeden yenisini hesaplamak ve tek durum değişimiyle `matches` ile `selected_index` değerini birlikte güncellemektir.
- `PickerDelegate::name()` kullanıcı tercihleri için kalıcı anahtar olduğundan, çeviri, refactor veya deneysel varyant adlarıyla sık değiştirilmemelidir.
- Preview kullanan picker'larda `try_get_preview_data_for_match(...)` sonucu seçili satırla aynı model snapshot'ından üretilmelidir; aksi halde preview eski satıra ait buffer veya konumu gösterebilir.
- `selected_index` sınır dışı kalırsa liste yine `match_count()` ile sürüldüğü için satırlar çizilir; yalnız hiçbir satır seçili görünmez, picker boş çizilmez. Yine de seçimin kaybolmaması için `update_matches` sonrasında `match_count == 0` durumu ayrı ele alınır, diğer durumlarda indeks `min(match_count - 1, selected_index)` formülüyle yenilenir.
- Tıklama onayı picker tarafından `cx.stop_propagation()` ve `window.prevent_default()` ile sarılır. Klavye veya özel onay eyleminde bu çağrılar otomatik değildir; dış elementin olay almaması gerekiyorsa delegate kendi durumunu set ettikten sonra ilgili yayılım/varsayılan davranışı ayrıca yönetmelidir.
- `PickerPopoverMenu` `DismissEvent`'ini dışarıdaki popover'a aktardığı için picker'ın kendi `dismissed` kancasına (hook) yapılması gereken iş yine delegate üzerinde kalır; modal'a özel temizlik kodu burada yazılır, popover sarmalayıcısı temizlik yapmaz.
