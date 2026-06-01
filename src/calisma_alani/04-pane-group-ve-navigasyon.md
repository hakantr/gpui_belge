# PaneGroup, NavHistory, Toolbar ve Sidebar Entegrasyonu

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `NavHistory` | Metotlar | `clear`, `disable`, `enable`, `for_each_entry`, `pop`, `pop_tag`, `set_mode` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `PaneGroup` | Metotlar | `bounding_box_for_pane`, `find_pane_in_direction`, `move_to_border`, `pane_at_pixel_position`, `remove`, `reset_pane_sizes`, `resize`, `split`, `swap` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Toolbar` | Metotlar | `add_item`, `set_active_item` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Pane ve çalışma alanı yalnızca tab listesinden ibaret değildir; split ağacı, gezinme geçmişi, toolbar item'ları ve çoklu çalışma alanı sidebar birlikte çalışır.

---

## PaneGroup ve SplitDirection

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `SplitDirection` | Metotlar | `along_edge`, `axis`, `edge`, `horizontal`, `opposite`, `vertical` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `SplitDirection` | Varyantlar | `Down`, `Left`, `Right`, `Up` | Enum seçim değerleri; davranış farkı ilgili konu anlatımında verilir. |


`PaneGroup` merkez veya dock içindeki pane ağacını taşır. Kök `Member::Pane` veya `Member::Axis(PaneAxis)` olabilir.

- `PaneGroup::new(pane)` tek bir pane ile başlar.
- `split(old_pane, new_pane, SplitDirection, cx)` ağaca yeni pane ekler; `old_pane` bulunamazsa ilk pane yedek olarak kullanırsın.
- `remove`, `resize`, `reset_pane_sizes`, `swap`, `move_to_border` split ağacını değiştirir.
- `pane_at_pixel_position(point)`, `bounding_box_for_pane(pane)`, `find_pane_in_direction` sürükle-bırak ve klavyeyle pane gezinme için kullanırsın.
- `SplitDirection::{Up, Down, Left, Right}`; `vertical(cx)` ve `horizontal(cx)` kullanıcı ayarına göre varsayılan split yönünü üretir.
- `SplitDirection::axis()`, `opposite()`, `edge(bounds)`, `along_edge(bounds, length)` resize ve bırakma göstergesi hesaplarında kullanırsın.

---

## Pane Preview, Pin ve NavHistory

Pane item listesinde preview ve sabitlenmiş ayrımı vardır; her ikisi de benzer ama farklı durumlarda yönetilir:

- `preview_item_id`, `preview_item`, `is_active_preview_item`, `unpreview_item_if_preview`, `replace_preview_item_id` preview tab akışıdır.
- `pinned_count`, `set_pinned_count` sabitlenmiş tab sınırını yönetir.
- `activate_item`, `activate_previous_item`, `activate_next_item`, `activate_last_item`, `swap_item_left/right` tab seçim ve sırasının yönetimidir.
- `close_active_item`, `close_item_by_id`, `close_other_items`, `close_clean_items`, `close_all_items` save intent ve sabitlenmiş davranışı hesaba katar.
- Workspace bir pane'i kaldırırken aktif pane kaldırılıyorsa `Workspace::force_remove_pane` önce `active_pane`'i kalan bir pane'e günceller: `focus_on` verilmişse o pane aktif olur, verilmemişse son kalan pane yedek olarak seçersin. Aktif modal varsa odak yedek pane'e taşınmayabilir; ancak `active_pane` yine kaldırılmış pane olarak bırakılmaz.

**Gezinme.** Geçmiş yönetimi item ve pane düzeyinde çalışır:

- `Pane::nav_history_for_item(item)` item'e bağlı bir `ItemNavHistory` üretir.
- `ItemNavHistory::push(data, row, cx)` item geçmişine giriş ekler; item `include_in_nav_history()` `false` döndürdüğünde eklenmez.
- `NavHistory::pop(GoingBack/GoingForward, cx)`, `clear`, `disable`, `enable`, `set_mode`, `for_each_entry` geçmiş yönetimini yapar.
- `push_tag` ve `pop_tag` tanım veya referans gibi tag gezinme yığınını yönetir.

---

## ToolbarItemView

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `ToolbarItemView` | Trait üyeleri | `contribute_context`, `pane_focus_update`, `set_active_pane_item` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


Pane toolbar'a katkı veren view'lar `ToolbarItemView` uygular:

```rust
pub trait ToolbarItemView: Render + EventEmitter<ToolbarItemEvent> {
    fn set_active_pane_item(
        &mut self,
        active_pane_item: Option<&dyn ItemHandle>,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> ToolbarItemLocation;

    fn pane_focus_update(&mut self, pane_focused: bool, window: &mut Window, cx: &mut Context<Self>) {}
    fn contribute_context(&self, context: &mut KeyContext, cx: &App) {}
}
```

- `ToolbarItemLocation::{Hidden, PrimaryLeft, PrimaryRight, Secondary}` çizim yerini belirler.
- Item kendi yerini değiştirmek isterse `ToolbarItemEvent::ChangeLocation(...)` yayar.
- `Toolbar::add_item(varlik, window, cx)` item'i kaydeder.
- `Toolbar::set_active_item` aktif pane item değiştiğinde tüm toolbar item'larını günceller.
- `contribute_context` görünür toolbar item'larının key context'e katkı vermesini sağlar.

---

## Sidebar ve MultiWorkspace

AI ve çoklu çalışma alanı sidebar'ı ayrı bir trait üzerinden bağlanır:

```rust
pub trait Sidebar: Focusable + Render + EventEmitter<SidebarEvent> + Sized {
    fn width(&self, cx: &App) -> Pixels;
    fn set_width(&mut self, width: Option<Pixels>, cx: &mut Context<Self>);
    fn has_notifications(&self, cx: &App) -> bool;
    fn side(&self, cx: &App) -> SidebarSide;
    fn is_threads_list_view_active(&self) -> bool { true }
    fn prepare_for_focus(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn toggle_thread_switcher(&mut self, select_last: bool, window: &mut Window, cx: &mut Context<Self>) {}
    fn cycle_project(&mut self, forward: bool, window: &mut Window, cx: &mut Context<Self>) {}
    fn cycle_thread(&mut self, forward: bool, window: &mut Window, cx: &mut Context<Self>) {}
    fn serialized_state(&self, cx: &App) -> Option<String> { None }
    fn restore_serialized_state(&mut self, state: &str, window: &mut Window, cx: &mut Context<Self>) {}
}
```

Sidebar yaşam döngüsü `MultiWorkspace` üzerinde yönetilir:

- `MultiWorkspace::register_sidebar(entity, cx)` sidebar'ı handle olarak saklar, gözlemler ve `SidebarEvent::SerializeNeeded` geldiğinde serileştirir.
- `ProjectGroup { key: ProjectGroupKey, workspaces, expanded }` ve `SerializedProjectGroupState` çoklu workspace gruplarının kalıcı anahtarını ve açık/kapalı durumunu taşır.
- `toggle_sidebar`, `open_sidebar`, `close_sidebar`, `focus_sidebar` görünürlük ve odak akışıdır.
- `prepare_for_focus`, `toggle_thread_switcher`, `cycle_project` ve `cycle_thread` focus ön hazırlığı ile proje/thread MRU geçişlerini sidebar implementasyonuna devreder.
- `set_sidebar_overlay(Some(AnyView), cx)` sidebar üzerine kaplama yerleştirir.
- `multi_workspace_enabled(cx)`, `!DisableAiSettings::disable_ai` ve `AgentSettings::enabled` koşullarının birlikte true olmasına bağlıdır. Bu false olduğunda sidebar açma veya focus işlemleri erken döner ve açık sidebar çizilmez.
- `sidebar_render_state(cx)` çizim tarafında open ve side bilgisini taşır; `open` değeri hem sidebar'ın açık olmasına hem de `multi_workspace_enabled(cx)` sonucuna bağlıdır.
- `sidebar_has_notifications(cx)` başlık çubuğu veya durum göstergesi için kullanırsın.
- Çalışma alanı aktivasyonunda tutma kararı sidebar'ın açık olmasına bağlı değildir. Çoklu çalışma alanı etkinse aktif çalışma alanı ve son transient aktif çalışma alanı tutulur; çoklu çalışma alanı devre dışıysa transient çalışma alanı ayrılır. Ayar değişiminde etkin durumdan devre dışına geçiş `collapse_to_single_workspace` ile tüm grupları atar.
- Threads sidebar thread'lerle birlikte terminal girişlerini de MRU switcher'a dahil eder; terminal aktivasyonu `AgentPanel::activate_terminal` üzerinden yapılır ve `ArchiveSelectedThread` aktif terminalde kapatma davranışına bağlanır.
- Sidebar ve panel boş durum akışları kök yolu olmayan çalışma alanında yeni thread veya terminal oluşturmaz; kullanıcı önce bir proje açmaya yönlendirilir.
- Taslak thread girişleri ayrı icon ve kapatma davranışıyla gösterilir. Taslak başlığı mesaj editör içeriğinden üretildiği için sidebar görünür taslak editör'leri gözlemleyip yazıldıkça girişleri yeniler.

**PaneGroup, toolbar ve sidebar API kapsamı.** Aşağıdaki public tiplerin ayrıntılı davranışı üstteki akışlarda yer alır; tablo, taşıyıcıların hangi kararı temsil ettiğini özetler.

| API | Rol |
|-----|-----|
| `ItemNavHistory` | Item'e bağlı gezinme geçmişidir; `push`, `pop_backward`, `pop_forward`, `push_tag` ve `navigation_entry` ile pane history zincirini yönetir. |
| `Member` | Pane split ağacının düğümüdür; `Pane` yapraklarını ve `Axis(PaneAxis)` iç düğümlerini taşır. |
| `PaneAxis` | `axis`, `members`, `flexes`, `bounding_boxes` alanlarıyla yatay/dikey split kolunu temsil eder; `new` ve `load` ile kurulur. |
| `ProjectGroup` | MultiWorkspace sidebar'da birlikte gruplanan workspace listesini taşır. |
| `ProjectGroupKey` | Project group kalıcı kimliğidir; sıralama ve serileştirme bu anahtarla yapılır. |
| `SerializedProjectGroupState` | Project group açık/kapalı ve sıra bilgisinin persist edilen halidir. |
| `SidebarEvent` | Sidebar'ın serileştirme veya görünürlük/yeniden çizim ihtiyacını workspace'e bildirir. |
| `SidebarSide` | Sidebar'ın pencere tarafını seçer; titlebar ve render tarafı bu değeri kullanır. |
| `ToolbarItemEvent` | Toolbar item'ın konum değiştirme isteğini `ChangeLocation(ToolbarItemLocation)` olarak yayar. |
| `ToolbarItemLocation` | `Hidden`, `PrimaryLeft`, `PrimaryRight`, `Secondary` yerleşimlerini tanımlar. |
| `dock` | Dock içindeki pane grupları ve center pane ile yan/alt panel ayrımını bağlayan modüldür. |
| `pane` | Tab listesi, preview/pin ve split eylemlerinin ana modülüdür. |
| `pane_group` | Split ağacı ve pane resize/swap/move davranışının modülüdür. |
| `history_manager` | Yakın zamanlı workspace geçmişi ve platform jump list güncellemesini yöneten modüldür. |
| `path_list` | Workspace açma ve recent history tarafında path kümelerini normalize eden yardımcı modüldür. |

**Pane, tab ve navigation action kapsamı.** Aşağıdaki kayıtlar çalışma alanı action yüzeyinin büyük kısmını oluşturur. Bunlar çoğunlukla `actions!` makrosuyla üretilen command tipleridir; `Clone`, `Default`, `Debug` ve `Action` gibi türetilmiş alt yüzeyleri ayrıca başlık gerektirmez.

| API | Rol |
| :-- | :-- |
| `ActivateItem`, `ActivatePreviousItem`, `ActivateNextItem`, `ActivateLastItem` | Aktif pane içindeki tab seçimini doğrudan, önceki/sonraki veya son aktif item yönünde değiştirir. |
| `ActivatePane`, `ActivatePreviousPane`, `ActivateNextPane`, `ActivateLastPane` | Workspace içindeki pane seçimini explicit pane id, MRU veya sıra mantığıyla değiştirir. |
| `ActivatePaneUp`, `ActivatePaneDown`, `ActivatePaneLeft`, `ActivatePaneRight` | Split ağacında yön bilgisine göre komşu pane'e odaklanır. |
| `ActivatePreviousWindow`, `ActivateNextWindow` | Uygulamadaki çalışma alanı pencereleri arasında önceki/sonraki pencereye geçer. |
| `FocusCenterPane` | Odak panel, dock veya modal tarafındayken merkez pane alanına geri döndürür. |
| `GoBack`, `GoForward`, `GoToOlderTag`, `GoToNewerTag`, `AlternateFile`, `ReopenClosedItem` | Pane navigation history, tag stack ve kapatılmış item geçmişi üzerinde gezinir. |
| `NavigationMode`, `NavigationEntry`, `TagNavigationMode`, `TagStackEntry`, `ActivationHistoryEntry` | Geri/ileri navigation, tag yığını ve item aktivasyon geçmişinin taşıyıcı modelleridir. |
| `CloseCleanItems`, `CloseItemsToTheLeft`, `CloseItemsToTheRight`, `CloseMultibufferItems` | Aktif pane içinde dirty olmayanları, tab'ın sol/sağ tarafını veya multibuffer item'ları kapatır. |
| `CloseAllItemsAndPanes`, `CloseInactiveTabsAndPanes`, `CloseItemInAllPanes`, `CloseIntent`, `UnpinAllTabs` | Workspace/pane düzeyinde toplu kapatma, inactive cleanup, tüm pane'lerde aynı item'ı kapatma, close niyeti ve pin temizleme kararlarını taşır. |
| `SplitMode`, `SplitUp`, `SplitDown`, `SplitLeft`, `SplitRight`, `SplitHorizontal`, `SplitVertical` | Mevcut item veya pane içeriğini yeni split yönüne göre ayırır; yatay/dikey helper'lar kullanıcı ayarlı varsayılanlarla birlikte düşünülür. |
| `SplitAndMoveUp`, `SplitAndMoveDown`, `SplitAndMoveLeft`, `SplitAndMoveRight` | Aktif item'ı yeni split'e taşıyarak bölme ve taşıma işlemini tek action'da birleştirir. |
| `NewFileSplit`, `NewFileSplitHorizontal`, `NewFileSplitVertical` | Yeni dosya item'ını mevcut pane yerine split içinde açar. |
| `MoveItemToPane`, `MoveItemToPaneInDirection`, `move_item`, `move_active_item`, `clone_active_item` | Aktif veya seçili item'ı hedef pane'e taşır ya da klonlar; düşük seviye fonksiyonlar action handler'ların ortak taşıma çekirdeğidir. |
| `MovePaneUp`, `MovePaneDown`, `MovePaneLeft`, `MovePaneRight`, `SwapPaneAdjacent` | Pane'in split ağacındaki konumunu taşır veya komşu pane ile yer değiştirir. |
| `SwapPaneUp`, `SwapPaneDown`, `SwapPaneLeft`, `SwapPaneRight`, `SwapItemLeft`, `SwapItemRight` | Pane veya tab sırasını yön bazlı swap işlemiyle değiştirir. |
| `SelectedEntry`, `DraggedSelection`, `DraggedTab`, `Side` | Tab/pane drag-drop ve seçim state'inde kullanılan küçük veri taşıyıcılarıdır; `Side` sol/sağ drop tarafını seçer. |
| `render_item_indicator`, `tab_details` | Tab render'ında dirty/diagnostic/pin gibi göstergeleri ve tooltip/detail metnini üretmeye yardım eden düşük seviye fonksiyonlardır. |
| `DeploySearch`, `NewSearch`, `ToggleFileFinder`, `ToggleProjectSymbols` | Pane search bar, yeni search item, file finder ve project symbols yüzeylerini açıp kapatan command tipleridir. |
| `NewFile`, `NewTerminal`, `NewCenterTerminal`, `OpenTerminal`, `OpenInTerminal`, `OpenFiles` | Workspace içinde yeni dosya, terminal veya dosya listesi açma yollarını temsil eder. |
| `ReloadActiveItem`, `RevealInProjectPanel`, `TogglePinTab`, `TogglePreviewTab`, `ToggleExpandItem` | Aktif item'ı yenileme, project panelde gösterme ve tab preview/pin/expanded state'ini değiştirme action'larıdır. |
| `ToggleZoom`, `ToggleCenteredLayout`, `ToggleReadOnlyFile`, `ToggleEditPrediction`, `SendKeystrokes` | Pane veya aktif item üzerinde zoom, centered layout, read-only, edit prediction ve sentetik keystroke davranışını tetikler. |
| `ShutdownDebugAdapters`, `DebuggerProvider`, `TerminalProvider` | Debug adapter kapatma action'ı ile workspace'in terminal/debug sağlayıcı trait sınırlarını kapsar. |

**Tuzaklar.** Bu entegrasyonlarda dikkat edilmesi gerekenler:

- Toolbar item `set_active_pane_item` içinde konum döndürür; ancak daha sonra yer değiştireceği zaman olay yaymalıdır, sadece durum değiştirip `cx.notify()` yeterli değildir.
- Sidebar durumu serileştirilecekse `SidebarEvent::SerializeNeeded` yaymak unutulmamalıdır.
- Çalışma alanı tutma veya ayırma davranışı sidebar açık/kapalı durumuna bağlanmamalıdır; güncel karar kaynağı `multi_workspace_enabled(cx)` sonucudur.
- Nav history preview item'ı ayrı işaretler; preview tab gerçek tab'a sabitlendiğinde history girişleri buna göre güncellenmelidir.
- Split yönü sabit kodlanmış olarak verilmek yerine kullanıcı ayarlı varsayılan isteniyorsa `SplitDirection::vertical(cx)` veya `horizontal(cx)` kullanırsın.
