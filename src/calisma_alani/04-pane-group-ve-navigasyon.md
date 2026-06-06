# PaneGroup, NavHistory, Toolbar ve Sidebar Entegrasyonu

Pane ve çalışma alanı yalnızca bir tab listesinden ibaret değildir; split ağacı, gezinme geçmişi, toolbar öğeleri ve çoklu çalışma alanı sidebar yapıları bir bütün halinde koordineli şekilde çalışır.

---

## PaneGroup ve SplitDirection

`PaneGroup`, merkez veya dock içindeki pane ağacını taşıyan temel yapıdır. Bu ağacın kök düğümü `Member::Pane` veya `Member::Axis(PaneAxis)` olabilir.

- `PaneGroup::new(pane)` metodu tek bir pane ile grubu başlatır.
- `PaneGroup::with_root(root)` metodu hazır bir `Member` ağacından grup kurmayı sağlar; restore (durum kurtarma) veya test akışlarında kök split ağacı zaten elde mevcutsa bu metottan yararlanılır.
- `PaneGroup::set_is_center(true)` metodu grubun workspace merkez alanı olduğunu işaretler; dock içindeki pane grupları ile merkez pane grubu bu alan üzerinden birbirinden ayrışır.
- `split(old_pane, new_pane, SplitDirection, cx)` metodu ağaca yeni bir pane ekler; eğer `old_pane` bulunamazsa ilk pane yedek (fallback) olarak kullanılır.
- `remove`, `resize`, `reset_pane_sizes`, `swap` ve `move_to_border` gibi metotlar split ağacının yapısını değiştirmek için kullanılır.
- `pane_at_pixel_position(point)`, `bounding_box_for_pane(pane)`, `find_pane_in_direction`, `first_pane()` ve `last_pane()` metotları; sürükle-bırak işlemleri, fallback odak yönetimi ve klavye aracılığıyla pane'ler arası gezinmede etkin rol oynar.
- `full_height_column_count()` metodu, merkez alanın tam yüksekliğe yayılan kolon sayısını döndürür. `invert_axies(cx)` ise split ağacındaki eksenleri tersine çevirerek pane konumlarını yeniden işaretler.
- `SplitDirection::{Up, Down, Left, Right}` yön belirteçleri; `vertical(cx)` ve `horizontal(cx)` metotları aracılığıyla kullanıcı ayarlarına göre varsayılan split yönünü üretir.
- `SplitDirection::all()` metodu dört yönü `[Up, Down, Left, Right]` sırasıyla verir; bu durum yön taraması veya key binding (tuş ataması) üretiminde kolaylık sağlar.
- `SplitDirection::axis()`, `opposite()`, `edge(bounds)` ve `along_edge(bounds, length)` metotları, resize (boyutlandırma) ve bırakma göstergesi hesaplamalarında kullanılır.
- `SplitDirection::increasing()` yönün koordinat ekseninde artan tarafa doğru gidip gitmediğini bildirir; `Down` ve `Right` artan, `Up` ve `Left` ise azalan yönü temsil eder.

---

## Pane Preview, Pin ve NavHistory

Pane item listesinde önizleme (preview) ve sabitlenmiş (pinned) öğe ayrımı bulunur; her iki durum da benzer ancak farklı mantıksal senaryolarda yönetilir:

- `preview_item_id`, `preview_item`, `is_active_preview_item`, `unpreview_item_if_preview` ve `replace_preview_item_id` gibi fonksiyonlar, önizleme tab akışını kontrol eder.
- `pinned_count` ve `set_pinned_count` metotları sabitlenmiş tab sınırını yönetmek için kullanılır.
- `activate_item`, `activate_previous_item`, `activate_next_item`, `activate_last_item` ve `swap_item_left/right` metotları, tab seçimini ve sekmelerin sıralamasını yönetir.
- `close_active_item`, `close_item_by_id`, `close_other_items`, `close_clean_items` ve `close_all_items` metotları; kaydetme niyetini (save intent) ve sabitlenmiş sekme davranışını hesaba katarak kapatma işlemlerini yürütür.
- Workspace bir pane'i kaldırırken aktif pane kaldırılıyorsa `Workspace::force_remove_pane` metodu, önce `active_pane` bilgisini geriye kalan bir pane'e günceller: `focus_on` parametresi verilmişse o pane aktif olur, verilmemişse son kalan pane yedek olarak seçilir. Aktif bir modal varsa odak yedek pane'e taşınmayabilir; ancak `active_pane` hiçbir durumda kaldırılmış olan pane olarak bırakılmaz.

**Gezinme (Navigation).** Geçmiş yönetimi hem item hem de pane düzeyinde işlev görür:

- `Pane::nav_history_for_item(item)` metodu item'a bağlı bir `ItemNavHistory` örneği üretir.
- `ItemNavHistory::push(data, row, cx)` metodu item geçmişine giriş ekler; eğer item `include_in_nav_history()` için `false` döndürürse geçmişe ekleme yapılmaz.
- `NavHistory::pop(GoingBack/GoingForward, cx)`, `clear`, `disable`, `enable`, `set_mode` ve `for_each_entry` metotları gezinme geçmişi yönetimini gerçekleştirir.
- `NavHistory::path_for_item(item_id)` metodu ilgili item için kaydedilmiş proje ve mutlak yol (absolute path) çiftini okur; `rename_item(item_id, project_path, abs_path)` bu kaydı günceller, `remove_item(item_id)` ise item kapandığında bu kaydı backward (geri), forward (ileri), closed (kapatılanlar) ve tag (etiket) yığınından temizler.
- `push_tag` ve `pop_tag` metotları, tanım veya referans gibi etiket gezinme yığınını yönetir.

---

## ToolbarItemView

Pane toolbar'a (araç çubuğu) katkı sağlayan view'lar `ToolbarItemView` trait'ini uygular:

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

- `ToolbarItemLocation::{Hidden, PrimaryLeft, PrimaryRight, Secondary}` yerleşimleri çizim alanını belirler.
- Eğer bir item kendi konumunu dinamik olarak değiştirmek isterse `ToolbarItemEvent::ChangeLocation(...)` olayını yayar.
- `Toolbar::add_item(varlik, window, cx)` metodu ilgili araç çubuğu öğesini sisteme kaydeder.
- `Toolbar::set_active_item` metodu, aktif pane item değiştiğinde tüm toolbar öğelerini günceller.
- `Toolbar::focus_changed(focused, window, cx)` metodu pane odağı değiştiğinde durumu toolbar öğelerine iletir; `set_can_navigate(can_navigate, cx)` ise geri/ileri gezinme kontrolünün etkinliğini saklar ve araç çubuğunu yeniden yapılandırır.
- `contribute_context` metodu görünür toolbar öğelerinin klavye bağlamına (key context) katkı vermesini sağlar.

---

## Sidebar ve MultiWorkspace

Yapay zeka (AI) ve çoklu çalışma alanı sidebar'ı (yan bar) ayrı bir trait üzerinden sisteme dahil edilir:

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

Sidebar yaşam döngüsü `MultiWorkspace` yapısı üzerinde yönetilir:

- `MultiWorkspace::register_sidebar(entity, cx)` metodu sidebar'ı handle olarak saklar, gözlemler ve `SidebarEvent::SerializeNeeded` olayı tetiklendiğinde serileştirme işlemini başlatır.
- `ProjectGroup { key: ProjectGroupKey, workspaces, expanded }` ve `SerializedProjectGroupState` yapıları, çoklu workspace gruplarının kalıcı anahtarını ve açık/kapalı durumunu taşır.
- `add_background_workspace(workspace, window, cx)` metodu gelen workspace'i kayıt ve tutma defterine ekler, fakat aktif workspace'i değiştirmez ve odağı taşımaz. Agent, `create_thread` gibi kullanıcının mevcut bağlamını bölmeden sibling worktree açan akışlarda bu metodu kullanarak yeni workspace'i arka planda sidebar grubuna dahil eder.
- `toggle_sidebar`, `open_sidebar`, `close_sidebar` ve `focus_sidebar` metotları görünürlük ve odak akışlarını düzenler.
- `prepare_for_focus`, `toggle_thread_switcher`, `cycle_project` ve `cycle_thread` metotları, odak hazırlığı ile proje/thread MRU (en son kullanılanlar) geçişlerini sidebar implementasyonuna devreder.
- `set_sidebar_overlay(Some(AnyView), cx)` metodu sidebar üzerine geçici bir kaplama yerleştirir.
- `multi_workspace_enabled(cx)` durumunun aktif olması; `!DisableAiSettings::disable_ai` ve `AgentSettings::enabled` koşullarının her ikisinin de true olmasına bağlıdır. Bu koşul sağlanmadığında (false döndüğünde) sidebar açma veya odaklanma işlemleri erken sonlanır ve açık sidebar ekrana çizilmez.
- `sidebar_render_state(cx)` metodu çizim tarafında open (açık) ve side (kenar) bilgisini taşır; buradaki `open` değeri hem sidebar'ın açık olmasına hem de `multi_workspace_enabled(cx)` sonucuna bağlıdır.
- `sidebar_has_notifications(cx)` metodu başlık çubuğu veya durum göstergelerinin güncellenmesinde kullanılır.
- Çalışma alanını aktif tutma veya serbest bırakma kararı sidebar'ın açık olmasına bağlı değildir. Çoklu çalışma alanı etkinse aktif çalışma alanı ve son transient (geçici) aktif çalışma alanı saklanır; çoklu çalışma alanı devre dışıysa geçici çalışma alanı ayrılır. Ayar değişiminde etkin durumdan devre dışına geçiş, `collapse_to_single_workspace` aracılığıyla tüm grupları devreden çıkarır.
- Bir pencerede birden çok çalışma alanı tek bir platform penceresini paylaşır; bu durumda pencerenin başlığı ve "değiştirildi" (modified) göstergesi yalnızca aktif çalışma alanına aittir. `MultiWorkspace` aktif çalışma alanını değiştirdiğinde yeni aktif çalışma alanının `Workspace::refresh_window_state(window, cx)` metodunu çağırır; bu metot pencere başlığını yeniden hesaplayıp uygular ve `window.set_window_edited(...)` ile düzenlenme göstergesini tazeler. Böylece işletim sistemi penceresinin başlığı ve değişiklik göstergesi her zaman fiilen görünen çalışma alanını yansıtır.
- Threads sidebar, thread'lerle birlikte terminal girişlerini de MRU switcher yapısına dahil eder; terminal aktivasyonu `AgentPanel::activate_terminal` üzerinden yürütülür ve `ArchiveSelectedThread` eylemi aktif terminalde kapatma davranışına bağlanır.
- Sidebar ve panel boş durum (empty state) akışları, kök yolu tanımlanmamış bir çalışma alanında yeni thread veya terminal oluşturmaz; thread listesi bu gibi durumlarda `ProjectEmptyState` çizer.
- Taslak thread girişleri ayrı bir ikon ve kapatma davranışıyla gösterilir. Taslak başlığı mesaj editör içeriğinden dinamik olarak üretildiği için sidebar, görünür taslak editörleri gözlemleyerek metin yazıldıkça girişleri yeniler.

---

## PaneGroup, Toolbar ve Sidebar API Kapsamı

Aşağıdaki dışa açık tiplerin ayrıntılı davranışları yukarıda belirtilen akışlarda yer almaktadır; tablo, taşıyıcıların hangi kararları ve durumları temsil ettiğini özetler:

| API | Rolü |
|-----|-----|
| `ItemNavHistory` | Item'a bağlı gezinme geçmişidir; `push`, `pop_backward`, `pop_forward`, `push_tag` ve `navigation_entry` ile pane geçmiş zincirini yönetir. |
| `Member` | Pane split ağacının düğümüdür; `Pane` yapraklarını ve `Axis(PaneAxis)` iç düğümlerini taşır. |
| `PaneAxis` | `axis`, `members`, `flexes`, `bounding_boxes` alanlarıyla yatay/dikey split kolunu temsil eder; `new` ve `load` ile kurulur. |
| `ProjectGroup` | MultiWorkspace sidebar'da birlikte gruplanan workspace listesini taşır. |
| `ProjectGroupKey` | Project group kalıcı kimliğidir; grubun kimlik ve serileştirme ayrımı için kullanılır, sıralama ise grup listesindeki konumla tutulur. |
| `SerializedProjectGroupState` | Project group açık/kapalı bilgisinin persist edilen (kalıcılaştırılan) halidir. |
| `SidebarEvent` | Sidebar'ın serileştirme ihtiyacını workspace'e bildirir. |
| `SidebarSide` | Sidebar'ın pencerenin hangi tarafında duracağını seçer; titlebar ve render tarafı bu değeri kullanır. |
| `ToolbarItemEvent` | Toolbar item'ın konum değiştirme isteğini `ChangeLocation(ToolbarItemLocation)` olarak yayar. |
| `ToolbarItemLocation` | `Hidden`, `PrimaryLeft`, `PrimaryRight`, `Secondary` yerleşimlerini tanımlar. |
| `MultiWorkspace::add_background_workspace` | Yeni workspace'i arka plan sekmesi (retained background tab) olarak ekler; aktif workspace ve odak yerinde kalır. |
| `Workspace::refresh_window_state` | Paylaşılan platform penceresinin başlığını ve düzenlenme göstergesini aktif çalışma alanına göre yeniden uygular; `MultiWorkspace` aktif çalışma alanı değişiminde bu metodu çağırır. |
| `dock` | Dock içindeki pane grupları ve merkez pane ile yan/alt panel ayrımını bağlayan modüldür. |
| `pane` | Tab listesi, önizleme/sabitleme ve split eylemlerinin ana modülüdür. |
| `pane_group` | Split ağacı ve pane boyutlandırma (resize)/yer değiştirme (swap)/taşıma davranışlarının modülüdür. |
| `history_manager` | Yakın zamanlı workspace geçmişi ve platform jump list güncellemesini yöneten modüldür. |
| `path_list` | Workspace açma ve yakın geçmiş tarafında yol (path) kümelerini normalize eden yardımcı modüldür. |

---

## Pane, Tab ve Navigation Action Kapsamı

Aşağıdaki kayıtlar çalışma alanı action yüzeyinin büyük kısmını oluşturur. Bunlar çoğunlukla `actions!` makrosuyla üretilen command tipleridir; `Clone`, `Default`, `Debug` ve `Action` gibi türetilmiş alt yüzeyleri ayrıca başlık gerektirmez.

| API | Rolü |
| :-- | :-- |
| `ActivateItem`, `ActivatePreviousItem`, `ActivateNextItem`, `ActivateLastItem` | Aktif pane içindeki tab seçimini doğrudan, önceki/sonraki veya son aktif item yönünde değiştirir. |
| `ActivatePane`, `ActivatePreviousPane`, `ActivateNextPane`, `ActivateLastPane` | Workspace içindeki pane seçimini açık pane kimliği (id), MRU veya sıra mantığıyla değiştirir. |
| `ActivatePaneUp`, `ActivatePaneDown`, `ActivatePaneLeft`, `ActivatePaneRight` | Split ağacında yön bilgisine göre komşu pane'e odaklanır. |
| `ActivatePreviousWindow`, `ActivateNextWindow` | Uygulamadaki çalışma alanı pencereleri arasında önceki/sonraki pencereye geçer. |
| `FocusCenterPane` | Odağı panel, dock veya modal tarafındayken merkez pane alanına geri döndürür. |
| `GoBack`, `GoForward`, `GoToOlderTag`, `GoToNewerTag`, `AlternateFile`, `ReopenClosedItem` | Pane navigation history, tag stack ve kapatılmış item geçmişi üzerinde gezinir. |
| `NavigationMode`, `NavigationEntry`, `TagNavigationMode`, `TagStackEntry`, `ActivationHistoryEntry` | Geri/ileri navigation, tag yığını ve item aktivasyon geçmişinin taşıyıcı modelleridir. |
| `CloseCleanItems`, `CloseItemsToTheLeft`, `CloseItemsToTheRight`, `CloseMultibufferItems` | Aktif pane içinde düzenlenmemiş (dirty olmayan) olanları, sekmenin sol/sağ tarafını veya multibuffer item'ları kapatır. |
| `CloseAllItemsAndPanes`, `CloseInactiveTabsAndPanes`, `CloseItemInAllPanes`, `CloseIntent`, `UnpinAllTabs` | Workspace/pane düzeyinde toplu kapatma, aktif olmayanları temizleme, tüm pane'lerde aynı item'ı kapatma, kapatma niyeti (close intent) ve sabitlemeleri kaldırma kararlarını taşır. |
| `SplitMode`, `SplitUp`, `SplitDown`, `SplitLeft`, `SplitRight`, `SplitHorizontal`, `SplitVertical` | Mevcut item veya pane içeriğini yeni split yönüne göre ayırır; yatay/dikey yardımcılar kullanıcı ayarlı varsayılanlarla birlikte düşünülür. |
| `SplitAndMoveUp`, `SplitAndMoveDown`, `SplitAndMoveLeft`, `SplitAndMoveRight` | Aktif item'ı yeni split'e taşıyarak bölme ve taşıma işlemini tek bir eylemde birleştirir. |
| `NewFileSplit`, `NewFileSplitHorizontal`, `NewFileSplitVertical` | Yeni dosya item'ını mevcut pane yerine split içinde açar. |
| `MoveItemToPane`, `MoveItemToPaneInDirection`, `move_item`, `move_active_item`, `clone_active_item` | Aktif veya seçili item'ı hedef pane'e taşır ya da klonlar; düşük seviyeli fonksiyonlar action handler'ların ortak taşıma çekirdeğidir. |
| `MovePaneUp`, `MovePaneDown`, `MovePaneLeft`, `MovePaneRight`, `SwapPaneAdjacent` | Pane'in split ağacındaki konumunu taşır veya komşu pane ile yer değiştirir. |
| `SwapPaneUp`, `SwapPaneDown`, `SwapPaneLeft`, `SwapPaneRight`, `SwapItemLeft`, `SwapItemRight` | Pane veya sekme sırasını yön bazlı yer değiştirme (swap) işlemiyle değiştirir. |
| `SelectedEntry`, `DraggedSelection`, `DraggedTab`, `Side` | Sekme/pane sürükle-bırak ve seçim durumunda kullanılan veri taşıyıcılarıdır; `Side` sol/sağ bırakma tarafını belirler. |
| `render_item_indicator`, `tab_details` | Sekme render işleminde dirty/diagnostic/pin gibi göstergeleri ve tooltip/detay metnini üretmeye yardım eden düşük seviyeli fonksiyonlardır. |
| `DeploySearch`, `NewSearch`, `ToggleFileFinder`, `ToggleProjectSymbols` | Pane search bar, yeni search item, dosya bulucu (file finder) ve proje sembolleri arayüzlerini açıp kapatan komut tipleridir. |
| `NewFile`, `NewTerminal`, `NewCenterTerminal`, `OpenTerminal`, `OpenInTerminal`, `OpenFiles` | Workspace içinde yeni dosya, terminal veya dosya listesi açma yollarını temsil eder. |
| `ReloadActiveItem`, `RevealInProjectPanel`, `TogglePinTab`, `TogglePreviewTab`, `ToggleExpandItem` | Aktif item'ı yenileme, proje panelinde gösterme ve sekme önizleme/sabitleme/genişletilmiş durumunu değiştirme action'larıdır. |
| `ToggleZoom`, `ToggleCenteredLayout`, `ToggleReadOnlyFile`, `ToggleEditPrediction`, `SendKeystrokes` | Pane veya aktif item üzerinde yakınlaştırma (zoom), merkezlenmiş yerleşim (centered layout), salt okunur (read-only), düzenleme tahmini (edit prediction) ve yapay tuş vuruşları (sentetik keystroke) davranışlarını tetikler. |
| `ShutdownDebugAdapters`, `DebuggerProvider`, `TerminalProvider` | Hata ayıklama adaptörlerini (debug adapter) kapatma eylemi ile workspace'in terminal/debug sağlayıcı trait sınırlarını kapsar. |

---

## Dikkat Edilmesi Gereken Hususlar

Entegrasyonlar sırasında şu noktalara dikkat edilmesi önem arz eder:

- Toolbar item, `set_active_pane_item` içerisinde konumu döndürür; ancak daha sonra konum değiştireceği zaman olay yaymalıdır. Sadece durum değiştirip `cx.notify()` çağrısı yapmak yeterli değildir.
- Sidebar durumu serileştirilecekse, `SidebarEvent::SerializeNeeded` olayının akışa eklenmesi gerekir.
- Çalışma alanını tutma veya ayırma davranışı sidebar'ın açık ya da kapalı olması durumuna bağlanmamalıdır; bu konudaki güncel karar kaynağı doğrudan `multi_workspace_enabled(cx)` sonucudur.
- Navigasyon geçmişi (nav history) önizleme item'larını ayrı işaretler; önizleme sekmesi gerçek bir sekme olarak sabitlendiğinde geçmiş girişlerinin de bu doğrultuda güncellenmesi gerekir.
- Split yönü sabit kodlanmış olarak verilmek yerine kullanıcı ayarlı varsayılanlara göre belirlenmek isteniyorsa `SplitDirection::vertical(cx)` veya `horizontal(cx)` kullanılmalıdır.
