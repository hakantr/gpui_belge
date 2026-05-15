# Bölüm XIV — Zed Workspace

---

## Zed Workspace Dock ve Panel Modeli


Bu bölüm GPUI çekirdeği değil, Zed'in `workspace` crate'i üstündeki dock/panel
katmanıdır. Dosyalar: `crates/workspace/src/workspace.rs`,
`crates/workspace/src/dock.rs`, `crates/workspace/src/pane.rs`.

Panel helper yüzeyi:

- `panel::PanelHeader` default `header_height` veya `panel_header_container`
  sağlayan bir helper trait değil, `workspace::Panel` üstünde marker trait'tir.
  Header yüksekliği gerekiyorsa doğrudan `Tab::container_height(cx)`, container
  gerekiyorsa `h_flex()`/`v_flex()` ve `ui::Button`/`ui::IconButton`
  bileşenleriyle kur.
- `panel_button`, `panel_filled_button`, `panel_icon_button` ve
  `panel_filled_icon_button` free function helper'ları yoktur. Panel UI'ında
  button layer/size/style kararlarını açık şekilde component üzerinde belirt.
- Git paneli `GitPanelTab::{Changes, History}` durumuyla iki tab render eder.
  Changes tab'ı eski staged/unstaged liste ve commit footer akışını korur;
  History tab'ı commit geçmişini `UniformListScrollHandle` ile sanallaştırır,
  ok tuşlarıyla `focused_history_entry` seçer ve confirm ile `CommitView::open`
  çağırır. Panel action listener'larına `ActivateChangesTab` /
  `ActivateHistoryTab` eklenmelidir.

Workspace yapısı:

- `Workspace` merkezde pane grubu, solda `left_dock`, sağda `right_dock`, altta
  `bottom_dock` taşır.
- Dock entity'si `DockPosition::{Left, Bottom, Right}` ile konumlanır.
- `Workspace::left_dock()`, `right_dock()`, `bottom_dock()`, `all_docks()`,
  `dock_at_position(position)` erişim sağlar.
- Aksiyonlar: `ToggleLeftDock`, `ToggleRightDock`, `ToggleBottomDock`,
  `ToggleAllDocks`, `CloseActiveDock`, `CloseAllDocks`,
  `Increase/DecreaseActiveDockSize`, `ResetActiveDockSize` vb.

Panel yazmak için `Panel` trait'i uygulanır:

- `persistent_name()` ve `panel_key()` persist/keymap/telemetry kimliğidir.
- `position`, `position_is_valid`, `set_position` panelin hangi dock'ta olacağını
  yönetir.
- `default_size`, `min_size`, `initial_size_state`, `size_state_changed`,
  `supports_flexible_size`, `set_flexible_size` boyut/persist davranışıdır.
- `icon`, `icon_tooltip`, `icon_label`, `toggle_action`, `activation_priority`
  status bar button ve sıralamayı belirler.
- `starts_open`, `set_active`, `is_zoomed`, `set_zoomed`, `pane`, `remote_id`
  dock state ve remote workspace entegrasyonudur.
- Panel `Focusable + EventEmitter<PanelEvent> + Render` olmalıdır.

Dock davranışı:

- `Dock::add_panel` paneli `activation_priority` sırasına göre ekler. Aynı priority
  debug build'de panic eder; her panel benzersiz priority seçmelidir.
- `Dock::set_open`, `activate_panel`, `active_panel`, `visible_panel`,
  `panel::<T>()`, `remove_panel`, `resize_active_panel`, `resize_all_panels`
  temel yönetim API'leridir.
- Panel `PanelEvent::Activate` emit ederse dock açılır, panel aktiflenir ve focus
  panele taşınır.
- `PanelEvent::Close` aktif görünür paneli kapatır.
- `PanelEvent::ZoomIn/ZoomOut` workspace zoom layer state'ini günceller.
- Boyut state'i `PanelSizeState { size, flex }` olarak persist edilir.

Workspace `toggle_dock` akışı:

1. Dock görünürse açık pozisyonlar kaydedilir.
2. Dock open state terslenir.
3. Aktif panel yoksa ilk enabled panel aktiflenir.
4. Açılıyorsa focus panel focus handle'a taşınır; kapanıyorsa focused panelden
   geliyorsa focus center pane'e döner.
5. Workspace serialize edilir.

Yeni panel eklerken kontrol:

- Panel `panel_key` değişirse eski persist ve keymap adları kırılır.
- `position_is_valid` bottom/side sınırlamalarını net tanımlamalıdır.
- `toggle_action()` action'ı register edilmiş olmalıdır.
- `activation_priority()` benzersiz olmalıdır.
- `set_active` içinde UI state değişiyorsa `cx.notify()` çağrısı unutulmamalıdır.
- Dock değiştiren settings gözlemlerinde panel taşınırken size state axis değişirse
  reset edilebilir; bu mevcut `Dock::add_panel`/settings observer akışında yapılır.

## Workspace Item, Pane, Modal, Toast ve Notification Sistemi


GPUI bir UI framework'üdür; Zed'in workspace katmanı bunun üstünde tab/pane,
modal, toast ve bildirim akışlarını standartlaştırır. Yeni bir editor benzeri
panel veya komut yazıyorsan bu sözleşmeleri tanımalısın.

#### Item ve ItemHandle

`crates/workspace/src/item.rs:167+`. Pane içindeki her tab içeriği `Item`
trait'ini uygular:

```rust
pub trait Item: Focusable + EventEmitter<Self::Event> + Render + Sized {
    type Event;

    fn tab_content(&self, params: TabContentParams, window: &Window, cx: &App)
        -> AnyElement;
    fn tab_tooltip_text(&self, _: &App) -> Option<SharedString> { None }
    fn deactivated(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn workspace_deactivated(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn telemetry_event_text(&self, _: &App) -> Option<&'static str> { None }
    fn navigate(&mut self, _data: Box<dyn Any>, _window: &mut Window, _cx: &mut Context<Self>) -> bool { false }
    // ... save/save_as, project_path, can_split, breadcrumbs, dragged_selection, ...
}
```

`ItemHandle` boxed/dyn karşılığıdır; pane API'leri çoğunlukla `Box<dyn ItemHandle>`
ile çalışır. `FollowableItem` collab takibi (workspace follow) için ek
sözleşmedir.

Tipik akış:

- Yeni tab tipini `impl Item for MyView` ile uygula.
- `Workspace::open_path`/`open_paths`/`open_abs_path` zaten `ProjectItem` üreterek
  doğru `Item` view'ini açar; özel akışta `Pane::add_item(Box::new(view), ...)`
  kullanılır.
- `Pane::activate_item`, `close_active_item`, `navigate_backward`,
  `navigate_forward`, `split` (split direction ile yeni pane) Pane API'leridir.
- `Workspace::split_pane(pane, direction, cx)` mevcut pane'i böler.
- `Workspace::register_action::<A>(|workspace, &A, window, cx| ...)` workspace
  global action'larını ekler (komut paleti üzerinden veya keymap'ten tetiklenen).

#### ModalView ve Modal Layer

`crates/workspace/src/modal_layer.rs:13+`:

```rust
pub trait ModalView: ManagedView {
    fn on_before_dismiss(&mut self, window, cx) -> DismissDecision { ... }
    fn fade_out_background(&self) -> bool { false }
    fn render_bare(&self) -> bool { false }
}
```

`ManagedView = Focusable + EventEmitter<DismissEvent> + Render`. Modal yazarken
bu bileşik trait'i sağlamak gerekir.

Açma/kapama:

```rust
workspace.toggle_modal(window, cx, |window, cx| {
    MyModal::new(window, cx)
});

workspace.hide_modal(window, cx);
```

`toggle_modal` halihazırda aynı tip bir modal açıksa onu kapatır; aksi halde yenisini açar. `on_before_dismiss` `DismissDecision::Dismiss(false)` veya
`Pending` döndürürse yeni modal görünmez.

#### StatusBar ve StatusItemView

`crates/workspace/src/status_bar.rs`:

```rust
pub trait StatusItemView: Render {
    fn set_active_pane_item(
        &mut self,
        active_pane_item: Option<&dyn ItemHandle>,
        window: &mut Window,
        cx: &mut Context<Self>,
    );

    fn hide_setting(&self, cx: &App) -> Option<HideStatusItem>;
}
```

Workspace status bar'a item eklemek:

```rust
workspace.status_bar().update(cx, |status_bar, cx| {
    status_bar.add_left_item(my_view, window, cx);
    status_bar.add_right_item(other_view, window, cx);
});
```

Status item active pane item değiştikçe `set_active_pane_item` ile bilgilendirilir;
böylece git branch indicator, cursor position gibi item'lar focused buffer'a
göre güncellenir.
`hide_setting()` `Some(HideStatusItem)` döndürürse status bar sağ tık menüsüne
"Hide Button" kaydı eklenir ve kullanıcı ayar dosyası `update_settings_file`
üzerinden güncellenir. Item zaten başka bir ayarla koşullu görünüyorsa `None`
döndürülebilir.

#### Notification ve Toast Sistemi

`crates/workspace/src/notifications.rs`:

```rust
pub trait Notification:
    EventEmitter<DismissEvent> + EventEmitter<SuppressEvent> + Focusable + Render
{}

pub enum NotificationId {
    Unique(TypeId),               // tip başına tek
    Composite(TypeId, ElementId), // tip + sub-id
    Named(SharedString),          // serbest isim
}

// Constructor yardımcıları:
// NotificationId::unique::<MyNotification>()
// NotificationId::composite::<MyNotification>(element_id)
// NotificationId::named("save".into())
```

Mesaj göstermek için:

```rust
workspace.show_notification(
    NotificationId::unique::<MyNotification>(),
    cx,
    |cx| cx.new(|cx| MyNotification::new(cx)),
);

workspace.show_toast(
    Toast::new(NotificationId::named("save".into()), "Saved")
        .autohide(),
    cx,
);

workspace.show_error(&error, cx);
```

`Toast` lightweight ve geçicidir (autohide), `Notification` ise persistant
view'dir ve kullanıcı dismiss edene kadar görünür. `SuppressEvent` aynı kaynaktan
gelen tekrarlı bildirimleri bastırmak için kullanılır.

`Workspace::toggle_status_toast<V: ToastView>` ise modal layer mantığında
`ToastView` üzerinden toast'ı toggle eder; tipik UI elemanları (örn. async iş
ilerleme göstergeleri) bu yolla bağlanır.

```rust
pub trait ToastView: ManagedView {
    fn action(&self) -> Option<ToastAction>;
    fn auto_dismiss(&self) -> bool { true }
}
```

`ToastAction::new(label, on_click)` toast içindeki aksiyon butonunu tanımlar.
`ToastView` tabanlı toast'larda auto dismiss default `true`; `Workspace::show_toast`
ile gösterilen lightweight `Toast` struct'ında ise `.autohide()` çağrılmadıkça
otomatik kapanma yoktur.

#### `Workspace::open_*` Akışı

```rust
let task = workspace.open_paths(
    vec![PathBuf::from("src/main.rs")],
    OpenOptions {
        visible: Some(OpenVisible::All),
        ..Default::default()
    },
    None,
    window,
    cx,
);
```

Önemli giriş noktaları:

- `workspace::open_paths(paths, app_state, open_options, cx)`: standalone helper;
  gerekirse pencere açar veya mevcut workspace'i yeniden kullanır.
- `Workspace::open_paths(abs_paths, OpenOptions, pane, window, cx)`: mevcut
  workspace içinde birden çok absolute path açar.
- `Workspace::open_path(project_path, pane, focus, window, cx)`: belirli bir
  `ProjectPath`'i mevcut workspace içinde açar; `Task<Result<Box<dyn ItemHandle>>>`
  döndürür.
- `Workspace::open_abs_path(path, options, window, cx)`: `PathBuf` alır, dosyayı
  worktree'ye ekler ve item açar.
- `Workspace::open_path_preview(path, pane, focus_item, allow_preview, activate,
  window, cx)`: file finder gibi ön izleme akışları için.
- `Workspace::split_abs_path(...)`, `split_path(...)`, `split_item(...)`: yeni
  pane oluşturarak path veya item'i split içinde açar.

#### Tuzaklar

- `Item` implementasyonunda `Self::Event` türünü doğru tanımlamak ve
  `EventEmitter<Self::Event>` impl etmek gerekir; aksi halde `Item` trait
  bound'u tutmaz.
- `Pane::add_item` `Box::new(view)` ile yapılır; pane item ownership'ini alır.
- `Workspace::register_action` callback signature'ı
  `Fn(&mut Self, &A, &mut Window, &mut Context<Self>)` — diğer GPUI
  `on_action` listener'larından farklı pozisyonel düzeni var (`&A` ortada).
- `NotificationId::Unique(TypeId::of::<T>())` ile aynı tipte iki notification
  açarsan ikincisi birinciyi yerine geçer; farklı sub-id istiyorsan
  `Composite(TypeId, ElementId)` kullan.
- `Toast` autohide süresi varsayılan değildir; uzun mesajlarda elle
  `dismiss_toast` çağırılması gerekebilir.
- `ModalView::on_before_dismiss` `Pending` döndürürse modal kapanma akışı
  beklemeye girer; testte `run_until_parked()` ile resolve sürecini ilerletmen
  gerekir.

## Workspace Serialization, OpenOptions, ProjectItem ve SearchableItem


Workspace item açma yalnızca `Pane::add_item` değildir; Zed session restore,
project item resolution, search bar ve collab follow gibi katmanları da item
trait'leri üzerinden bağlar.

#### SerializableItem ve Restore

`SerializableItem` workspace kapanırken veya item event'i geldiğinde item state'ini
workspace DB'ye yazmak ve sonra geri yüklemek için kullanılır:

```rust
pub trait SerializableItem: Item {
    fn serialized_item_kind() -> &'static str;

    fn cleanup(
        workspace_id: WorkspaceId,
        alive_items: Vec<ItemId>,
        window: &mut Window,
        cx: &mut App,
    ) -> Task<Result<()>>;

    fn deserialize(
        project: Entity<Project>,
        workspace: WeakEntity<Workspace>,
        workspace_id: WorkspaceId,
        item_id: ItemId,
        window: &mut Window,
        cx: &mut App,
    ) -> Task<Result<Entity<Self>>>;

    fn serialize(
        &mut self,
        workspace: &mut Workspace,
        item_id: ItemId,
        closing: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<Task<Result<()>>>;

    fn should_serialize(&self, event: &Self::Event) -> bool;
}
```

Kayıt:

```rust
workspace::register_serializable_item::<MyItem>(cx);
```

- `serialized_item_kind()` session DB'deki discriminant'tır; değiştirirsen eski
  session restore bozulur.
- `serialize(..., closing, ...)` `None` döndürürse o event için yazma yapılmaz.
- `should_serialize(event)` item event'inden sonra serialization gerekip
  gerekmediğini belirler.
- `cleanup(workspace_id, alive_items, ...)` DB'de artık canlı olmayan item kayıtlarını
  temizlemek için çağrılır.
- `SerializableItemHandle` `Entity<T: SerializableItem>` için blanket implement
  edilir; pane/workspace type erasure bu handle üzerinden çalışır.

#### OpenOptions ve open_paths

Top-level `workspace::open_paths` ve `Workspace::open_paths` aynı option modelini
kullanır:

- `visible: Option<OpenVisible>`: `All`, `None`, `OnlyFiles`, `OnlyDirectories`.
  `All` hem dosya hem dizinleri project panelde görünür yapar; `None` hiçbirini
  görünür yapmaz; `OnlyFiles` dizinleri, `OnlyDirectories` dosyaları dışarıda
  bırakır.
- `focus: Option<bool>`: açılan item focus alsın mı?
- `workspace_matching: WorkspaceMatching`: `None`, `MatchExact`,
  `MatchSubdirectory`.
- `add_dirs_to_sidebar`: unmatched directory yeni pencere açmak yerine mevcut
  local `MultiWorkspace` penceresine workspace olarak eklensin mi? Default `true`.
  Ekleme yalnız hedef window'da `multi_workspace_enabled(cx)` true ise yapılır;
  bu durumda `requesting_window` aktif/ilk local multi-workspace window'a set
  edilir ve sidebar açılır.
- `wait`: CLI `--wait` benzeri akışlarda pencerenin kapanmasını bekleme davranışı.
- `requesting_window`: hedef `WindowHandle<MultiWorkspace>` varsa onu kullan.
- `open_mode: OpenMode`: `NewWindow`, `Add`, `Activate`.
- `env`: açılan workspace için environment override.
- `open_in_dev_container`: dev container açma isteği.

`OpenMode::Activate`, `NewWindow` gibi hedef window'u foreground'a getirir.
Default davranışta `-n`, `-a` veya `-r` verilmeden folder açmak mevcut pencerenin
Threads sidebar'ına yeni project olarak eklenir. Yeni pencere isteniyorsa CLI'da
`zed -n path`, Open Recent'te modifier'lı enter/click veya
`cli_default_open_behavior = "new_window"` kullanılmalıdır.

`OpenResult { window, workspace, opened_items }` top-level açma sonucudur. İç
workspace açma fonksiyonları çoğunlukla `Task<Result<Box<dyn ItemHandle>>>` veya
çoklu path için `Task<Vec<Option<Result<Box<dyn ItemHandle>>>>>` döndürür.

#### ProjectItem

`ProjectItem` Zed project entry'sinden workspace item view'i üretir:

```rust
pub trait ProjectItem: Item {
    type Item: project::ProjectItem;

    fn project_item_kind() -> Option<ProjectItemKind> { None }

    fn for_project_item(
        project: Entity<Project>,
        pane: Option<&Pane>,
        item: Entity<Self::Item>,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Self;

    fn for_broken_project_item(...) -> Option<InvalidItemView> { None }
}
```

Normal dosya açma `project::ProjectItem::try_open` üzerinden item'i çözer; hata
durumunda `for_broken_project_item` bozuk/eksik kaynağı temsil eden view üretmek
için kullanılabilir.

#### SearchableItem

Workspace search bar'ın bir item içinde çalışması için `SearchableItem` gerekir:

- `type Match`: arama sonucunu temsil eden cloneable match tipi.
- `supported_options() -> SearchOptions`: case, word, regex, replacement,
  selection, select_all, find_in_results desteklerini bildirir.
- `find_matches(query, window, cx) -> Task<Vec<Match>>` veya token'lı
  `find_matches_with_token`.
- `update_matches`, `clear_matches`, `activate_match`, `select_matches`.
- `replace` ve `replace_all` replace destekleyen item'lar içindir.
- `SearchEvent::{MatchesInvalidated, ActiveMatchChanged}` search UI'ı yeniden
  sorgulamaya zorlar.
- `SearchableItemHandle` type-erased search item'ıdır; `Item::as_searchable`
  bunu döndürerek pane toolbar search bar'a bağlanır.
- `query_suggestion(seed_query_override: Option<SeedQuerySetting>, window, cx)`
  search bar'ın başlangıç sorgusunu üretir. `None` normal
  `seed_search_query_from_cursor` ayarını kullanır; `Some(Always)` gibi
  override'lar Cmd-E / Vim search gibi "bu çağrıda cursor altındaki kelimeyi kesin
  kullan" davranışını açıkça ifade eder.

#### FollowableItem

Collab/follow akışı için `FollowableItem` kullanılır:

- `remote_id()`, `to_state_proto`, `from_state_proto` remote view state'ini taşır.
- `to_follow_event(event)` item event'ini follow event'e çevirir.
- `add_event_to_update_proto` ve `apply_update_proto` incremental remote update
  akışıdır.
- `set_leader_id` takip edilen kullanıcı bilgisini item state'ine işler.
- `dedup(existing, ...) -> Option<Dedup>` remote item açılırken mevcut item ile
  birleştirme veya replace kararıdır.

Tuzaklar:

- Serializable item'i register etmezsen `deserialize` hiç çağrılmaz; session restore
  silently invalid item'e düşebilir.
- `serialized_item_kind` global namespace gibidir; başka item ile çakıştırma.
- Search match tipini byte offset, buffer snapshot ve token ile uyumlu tut; stale
  match'i yeni buffer üzerinde kullanmak yanlış range'e gider.
- `OpenOptions::visible = None` default olarak workspace'e görünür worktree ekleme
  anlamına gelmez; path açma davranışını özellikle directory/file ayrımı için
  açık seç.

## PaneGroup, NavHistory, Toolbar ve Sidebar Entegrasyonu


Pane ve workspace yalnız tab listesi değildir; split ağacı, navigation history,
toolbar item'ları ve multi-workspace sidebar birlikte çalışır.

#### PaneGroup ve SplitDirection

`PaneGroup` center veya dock içindeki pane ağacını taşır. Kök `Member::Pane` veya
`Member::Axis(PaneAxis)` olabilir.

- `PaneGroup::new(pane)` tek pane ile başlar.
- `split(old_pane, new_pane, SplitDirection, cx)` ağaca yeni pane ekler; eski pane
  bulunamazsa first pane fallback'i kullanılır.
- `remove`, `resize`, `reset_pane_sizes`, `swap`, `move_to_border` split ağacını
  değiştirir.
- `pane_at_pixel_position(point)`, `bounding_box_for_pane(pane)`,
  `find_pane_in_direction` drag/drop ve keyboard pane navigation için kullanılır.
- `SplitDirection::{Up, Down, Left, Right}`; `vertical(cx)` ve `horizontal(cx)`
  kullanıcı ayarına göre default split yönünü üretir.
- `SplitDirection::axis()`, `opposite()`, `edge(bounds)`,
  `along_edge(bounds, length)` resize/drop indicator hesaplarında kullanılır.

#### Pane Preview, Pin ve NavHistory

Pane item listesinde preview/pinned ayrımı vardır:

- `preview_item_id`, `preview_item`, `is_active_preview_item`,
  `unpreview_item_if_preview`, `replace_preview_item_id` preview tab akışıdır.
- `pinned_count`, `set_pinned_count` pinned tab sınırını yönetir.
- `activate_item`, `activate_previous_item`, `activate_next_item`,
  `activate_last_item`, `swap_item_left/right` tab selection ve sıra yönetimidir.
- `close_active_item`, `close_item_by_id`, `close_other_items`,
  `close_clean_items`, `close_all_items` save intent ve pinned davranışını hesaba
  katar.
- Workspace bir pane'i kaldırırken aktif pane kaldırılıyorsa
  `Workspace::force_remove_pane` artık önce `active_pane`'i kalan pane'e günceller:
  `focus_on` verilmişse o pane aktif olur, verilmemişse son kalan pane fallback
  olur. Aktif modal varsa focus fallback pane'e taşınmayabilir, ancak `active_pane`
  yine kaldırılmış pane olarak bırakılmaz.

Navigation:

- `Pane::nav_history_for_item(item)` item'e bağlı `ItemNavHistory` üretir.
- `ItemNavHistory::push(data, row, cx)` item history'ye entry ekler; item
  `include_in_nav_history()` false döndürürse eklenmez.
- `NavHistory::pop(GoingBack/GoingForward, cx)`, `clear`, `disable`, `enable`,
  `set_mode`, `for_each_entry` history yönetimidir.
- `push_tag`/`pop_tag` definition/reference gibi tag navigation stack'ini yönetir.

#### ToolbarItemView

Pane toolbar'a katkı verecek view `ToolbarItemView` uygular:

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

- `ToolbarItemLocation::{Hidden, PrimaryLeft, PrimaryRight, Secondary}` render
  yerini belirler.
- Item kendi yerini değiştirmek isterse `ToolbarItemEvent::ChangeLocation(...)`
  emit eder.
- `Toolbar::add_item(entity, window, cx)` item'i kaydeder.
- `Toolbar::set_active_item` active pane item değişince tüm toolbar item'larını
  günceller.
- `contribute_context` görünür toolbar item'larının key context'e katkı vermesini
  sağlar.

#### Sidebar ve MultiWorkspace

AI/multi-workspace sidebar ayrı bir trait ile bağlanır:

```rust
pub trait Sidebar: Focusable + Render + EventEmitter<SidebarEvent> + Sized {
    fn width(&self, cx: &App) -> Pixels;
    fn set_width(&mut self, width: Option<Pixels>, cx: &mut Context<Self>);
    fn has_notifications(&self, cx: &App) -> bool;
    fn side(&self, cx: &App) -> SidebarSide;
    fn serialized_state(&self, cx: &App) -> Option<String> { None }
    fn restore_serialized_state(&mut self, state: &str, window: &mut Window, cx: &mut Context<Self>) {}
}
```

- `MultiWorkspace::register_sidebar(entity, cx)` sidebar'ı handle olarak saklar,
  observe eder ve `SidebarEvent::SerializeNeeded` geldiğinde serialize eder.
- `toggle_sidebar`, `open_sidebar`, `close_sidebar`, `focus_sidebar` görünürlük ve
  focus akışıdır.
- `set_sidebar_overlay(Some(AnyView), cx)` sidebar üstüne overlay yerleştirir.
- `multi_workspace_enabled(cx)`, `!DisableAiSettings::disable_ai` ve
  `AgentSettings::enabled` koşullarının birlikte true olmasına bağlıdır. Bu false
  ise sidebar açma/focus işlemleri erken döner ve açık sidebar render edilmez.
- `sidebar_render_state(cx)` render tarafında open/side bilgisini taşır; `open`
  değeri hem sidebar açık olmasına hem de `multi_workspace_enabled(cx)` sonucuna
  bağlıdır.
- `sidebar_has_notifications(cx)` titlebar/status indicator için kullanılır.
- Workspace aktivasyonunda retain kararı artık sidebar'ın açık olmasına bağlı
  değildir. Multi-workspace etkinse yeni aktif workspace ve önceki transient aktif
  workspace retain edilir; multi-workspace devre dışıysa eski transient workspace
  detach edilir. Settings değişiminde etkin durumdan devre dışına geçiş
  `collapse_to_single_workspace` ile tüm grupları atar.
- Threads sidebar thread'lerle birlikte terminal entry'lerini de MRU switcher'a
  dahil eder; terminal aktivasyonu `AgentPanel::activate_terminal` üzerinden
  yapılır ve `ArchiveSelectedThread` aktif terminalde close davranışına bağlanır.
- Sidebar ve panel empty-state akışları root path'i olmayan workspace'te yeni
  thread/terminal oluşturmaz; kullanıcı önce project açmaya yönlendirilir.
- Draft thread entry'leri ayrı icon/close davranışıyla gösterilir. Draft başlığı
  mesaj editor içeriğinden üretildiği için sidebar görünür draft editor'larını
  observe edip yazdıkça entry'leri yeniler.

Tuzaklar:

- Toolbar item `set_active_pane_item` içinde location döndürür ama daha sonra yer
  değiştirecekse event emit etmelidir; sadece state değiştirip `cx.notify()` yeterli
  değildir.
- Sidebar state'i serialize etmek istiyorsan `SidebarEvent::SerializeNeeded` emit
  etmeyi unutma.
- Workspace retain/detach davranışını sidebar açık/kapalı durumuna bağlama;
  güncel karar kaynağı `multi_workspace_enabled(cx)` sonucudur.
- Nav history preview item'i ayrı işaretler; preview tab gerçek tab'a pinlenince
  history entry'lerini buna göre güncelle.
- Split yönü hardcode etmek yerine user ayarlı default isteniyorsa
  `SplitDirection::vertical(cx)` / `horizontal(cx)` kullan.

## Workspace Notification Yardımcıları ve Async Hata Gösterimi


Bildirim sistemi yalnız `show_notification` değildir; workspace dışı app-level
notification ve async error propagation için yardımcı trait'ler vardır.

App-level notification:

- `show_app_notification(id, cx, build)`: active workspace varsa orada, yoksa tüm
  workspace'lerde notification gösterir.
- `dismiss_app_notification(id, cx)`: aynı id'li app notification'ları kapatır.
- `NotificationFrame` başlık, içerik, suppress/close butonu ve suffix compose
  etmek için kullanılan standart frame'dir.
- `simple_message_notification::MessageNotification` primary/secondary mesaj,
  icon, click handler, close/suppress ve "more info" URL gibi hazır alanlar sağlar.

Error propagation:

- `NotifyResultExt::notify_err(workspace, cx)`: `Result` error ise workspace
  notification gösterir ve `None` döndürür.
- `notify_workspace_async_err(weak_workspace, async_cx)`: async task içinde weak
  workspace'e error notification yollar.
- `notify_app_err(cx)`: active workspace yoksa app-level notification gösterir.
- `NotifyTaskExt::detach_and_notify_err(workspace, window, cx)`: `Task<Result<...>>`
  sonucunu window üzerinde spawn eder ve error'u workspace notification'a çevirir.
- `DetachAndPromptErr::prompt_err` ve `detach_and_prompt_err`: `anyhow::Result`
  task'ını prompt tabanlı kullanıcı hatasına çevirir.

Kullanım seçimi:

- Kullanıcı aksiyonunun sonucu doğrudan workspace içinde görünmeli ise
  `notify_err`/`detach_and_notify_err`.
- Kritik onay veya seçim gerekiyorsa `detach_and_prompt_err`.
- Workspace yokken de görünmesi gereken startup/global hata için
  `notify_app_err` veya `show_app_notification`.

Tuzaklar:

- `detach_and_log_err` yalnız loglar; kullanıcıya görünür hata isteniyorsa
  workspace notification/prompt helper'larından birini seç.
- `show_app_notification` aynı id ile birden fazla workspace'te gösterim yapabilir;
  id'yi `NotificationId::named` veya `composite` ile bilinçli seç.
- `MessageNotification` click handler'ları `Window` ve `App` alır; workspace state
  gerekiyorsa weak workspace/entity yakala ve düşmüş olma ihtimalini ele al.

## AppState, WorkspaceStore, WorkspaceDb ve OpenListener Akışı


Zed uygulamasında workspace açma, sadece `open_window` çağrısı değildir. Startup,
CLI/open-url istekleri, workspace DB ve collab follow state'i birkaç global/handle
üzerinden birbirine bağlanır.

#### AppState

`AppState` Zed workspace açma ve restore işlemlerinde taşınan uygulama servis
paketidir:

- `languages: Arc<LanguageRegistry>`
- `client: Arc<Client>`
- `user_store: Entity<UserStore>`
- `workspace_store: Entity<WorkspaceStore>`
- `fs: Arc<dyn fs::Fs>`
- `build_window_options: fn(Option<Uuid>, &mut App) -> WindowOptions`
- `node_runtime: NodeRuntime`
- `session: Entity<AppSession>`

`AppState::set_global(state, cx)` global olarak kurar; `AppState::global(cx)` ve
`try_global(cx)` okuma yapar. Testlerde `AppState::test(cx)` fake FS, test
language registry ve test settings store kurar.

#### WorkspaceStore

`WorkspaceStore` açık workspace'leri `AnyWindowHandle + WeakEntity<Workspace>`
çifti olarak izler. Collab tarafındaki follow/update follower mesajları bu store
üzerinden uygun workspace'e yönlendirilir.

- `WorkspaceStore::new(client, cx)` client request/message handler'larını kaydeder.
- `workspaces()` weak workspace iterator'ı verir.
- `workspaces_with_windows()` window handle ile birlikte döndürür.
- `update_followers(project_id, update, cx)` aktif call üzerinden follower update
  mesajı gönderir.
- Collab/titlebar/follow akışlarında client tarafındaki `User` artık
  `legacy_id: LegacyUserId` alanını taşır; proto room role lookup,
  participant index ve `join_in_room_project` gibi legacy id bekleyen yerlere
  `user.legacy_id` verilmelidir. `user.id` alanı bu client modelinde yoktur.

#### WorkspaceDb ve HistoryManager

`WorkspaceDb::global(cx)` session/workspace persistence için kullanılan SQLite
bağlantı wrapper'ıdır. Workspace restore ve recent project history şu katmanlara
dağılır:

- `open_workspace_by_id(workspace_id, app_state, requesting_window, cx)` DB'deki
  serialized workspace'i açar.
- `read_serialized_multi_workspaces`, `SerializedMultiWorkspace`,
  `SerializedWorkspaceLocation`, `SessionWorkspace`, `ItemId` persistence modelidir.
- `HistoryManager::global(cx)` recent local workspace geçmişini verir.
- `HistoryManager::update_history(id, entry, cx)` recent list'i günceller ve
  platform jump list'i yeniler.
- `HistoryManager::delete_history(id, cx)` unload edilen workspace'i geçmişten
  kaldırır.

#### OpenListener ve RawOpenRequest

`zed::open_listener` app dışından gelen açma isteklerini queue'lar:

```rust
let (listener, rx) = OpenListener::new();
listener.open(RawOpenRequest {
    urls,
    diff_paths,
    diff_all,
    dev_container,
    wsl,
    cwd,
});
```

- `OpenListener` bir `Global`'dir; `open(...)` isteği unbounded channel'a yollar.
- `RawOpenRequest` ham CLI/URL alanlarını taşır.
- `OpenRequest::parse(raw, cx)` bunları typed `OpenRequest` haline getirir.
- `OpenRequestKind` kaynak türünü belirtir: CLI connection, extension, agent
  panel, shared agent thread, dock menu action, builtin JSON schema, setting,
  git clone, git commit vb.
- Linux/FreeBSD'de `listen_for_cli_connections` release-channel socket'i üzerinden
  CLI isteklerini alır.
- `RawOpenRequest::cwd` CLI process'inin çalışma dizinini taşır. Yalnız `--diff`
  path'leri verildiğinde workspace context'i için bu cwd kullanılır; Zed app
  process'inin `std::env::current_dir()` değeri macOS bundle veya zaten çalışan
  instance yüzünden güvenilir değildir.
- SSH URL parse akışı normal URL'lere ek olarak SCP/git tarzı
  `ssh://user@host:~/project` ve `ssh://user@host:/absolute/path` biçimlerini
  normalize eder. Username/password URL-decode edilir; IPv6 SCP-style authority
  ve çift port benzeri belirsiz biçimler reddedilir.
- `open_paths_with_positions` diff path canonicalization için `app_state.fs`
  kullanır ve hataları `opened_items` listesine taşıyarak diğer path'leri açmaya
  devam eder.

Global agent yönergesi:

- Startup sırasında `zed::watch_user_agents_md(app_state.fs.clone(), cx)` çağrılır.
  Bu, `paths::agents_file()` (`~/.config/zed/AGENTS.md`, platforma göre eşdeğeri)
  dosyasını izler ve `agent::UserAgentsMd` global'ine yükler.
- Boş veya whitespace-only dosya `UserAgentsMdState::Empty`, başarılı okuma
  `Loaded`, okunamayan mevcut dosya `Error` olur. Error durumunda settings
  hatalarıyla aynı app-level notification yolu kullanılır.
- Native agent system prompt'u kişisel `AGENTS.md` içeriğini "Personal
  `AGENTS.md`" olarak project rules'tan önce render eder; conflict halinde
  project rules daha sonra geldiği için daha spesifik kabul edilir.

Tuzaklar:

- Workspace açma akışında `AppState::build_window_options` kullan; doğrudan
  `WindowOptions` kopyalamak Zed'in titlebar, app id, bounds restore ve platform
  ayarlarını bypass eder.
- `WorkspaceStore` weak workspace tutar; iterasyon yaparken upgrade başarısız
  olabilir.
- `OpenListener::open` listener yoksa hatayı loglar; request teslim edildi
  varsayımıyla kullanıcı akışı başlatma.
- DB restore path'inde serializable item kind eksikse item restore edilemez;
  yeni item türü eklerken `register_serializable_item` startup init'inde
  çağrılmalıdır.

## Item Ayarları, Context Menu, ApplicationMenu ve Focus-Follows-Mouse


Zed UI kodunda sık görülen ama GPUI çekirdeği olmayan birkaç yardımcı katman daha
vardır.

#### Item Ayarları ve SaveIntent

Item/tab davranışını settings tarafına bağlayan tipler:

- `ItemSettings`: `git_status`, `close_position`, `activate_on_close`,
  `file_icons`, `show_diagnostics`, `show_close_button` alanlarını `tabs` ve
  `git` ayarlarından üretir.
- `PreviewTabsSettings`: preview tab kaynaklarını ayrı ayrı açıp kapatır:
  project panel, file finder, multibuffer, code navigation, keep-preview gibi.
- `TabContentParams { detail, selected, preview, deemphasized }`: tab render'ına
  selection/preview/focus dışı durumu taşır; `text_color()` semantic `Color`
  döndürür.
- `TabTooltipContent::{Text, Custom}` tab tooltip'ini string veya custom view
  olarak tanımlar.
- `ItemBufferKind::{Multibuffer, Singleton, None}` item'in buffer ilişkisini
  sınıflandırır.

Save/close akışında `SaveIntent` kullanılır:

- `Save`, `FormatAndSave`, `SaveWithoutFormat`, `SaveAll`, `SaveAs`, `Close`,
  `Overwrite`, `Skip`.
- Pane close action'ları `CloseActiveItem`, `CloseOtherItems`, `CloseAllItems`
  gibi action struct'larında optional `SaveIntent` taşır. Dirty/format/conflict
  davranışını doğrudan boolean ile çoğaltma; mevcut save intent zincirine bağlan.
- `SaveOptions { format, force_format, autosave }` item save implementasyonunun
  düşük seviyeli karar paketidir.

#### ContextMenu ve PopoverMenu

`ContextMenu` bir `ManagedView` olarak modal/popover zincirine takılır. İçerik
modeli:

- `ContextMenuItem::{Separator, Header, HeaderWithLink, Label, Entry,
  CustomEntry, Submenu}`.
- `ContextMenuEntry` label, icon, checked/toggle, action, disabled, secondary
  handler, documentation aside ve end-slot gibi alanları taşır.
- `ContextMenu::build(window, cx, |menu, window, cx| ...)` menü entity'si üretir.
- `menu.context(focus_handle)` menu action availability ve keybinding display için
  belirli focus context'ini kullanır.

`PopoverMenu<M: ManagedView>` anchor element ile managed menu view'i bağlar:

- `PopoverMenu::new(id)`, `.menu(...)`, `.with_handle(handle)`, `.anchor(...)`,
  `.attach(...)`, `.offset(...)`, `.full_width(...)`, `.on_open(...)`.
- `PopoverMenuHandle<M>` dışarıdan toggle/close ve açık menu entity'sine erişim
  için saklanır.
- Popover konumlandırması `window.layout_bounds` ve çift `on_next_frame` desenini
  kullanabilir; anchor bounds ilk frame'de, menu bounds sonraki frame'de bilinir.

#### Client-side ApplicationMenu

macOS dışındaki client-side application menu `title_bar::ApplicationMenu` ile
çizilir:

- `ApplicationMenu::new(window, cx)` `cx.get_menus()` ile platform/app menülerini
  okur ve her top-level menu için `PopoverMenuHandle<ContextMenu>` saklar.
- `OpenApplicationMenu(String)` action'ı belirli menüyü açar.
- `ActivateMenuLeft`/`ActivateMenuRight` client-side menu bar içinde yatay gezinir.
- `ApplicationMenu` boş submenu'leri ve ardışık/trailing separator'ları temizler,
  sonra `OwnedMenuItem::{Action, Submenu, Separator, SystemMenu}` değerlerini
  işler. `Action`/`Submenu`/`Separator` `ContextMenu` entry'lerine dönüşür;
  `SystemMenu(_)` client-side context'te anlamlı olmadığı için yok sayılır.

#### FocusFollowsMouse

`FocusFollowsMouse` trait'i `StatefulInteractiveElement` üzerine eklenir:

```rust
element.focus_follows_mouse(WorkspaceSettings::get_global(cx).focus_follows_mouse, cx)
```

- Ayar enabled ise hover enter sırasında target `AnyWindowHandle + FocusHandle`
  global state'e yazılır.
- Debounce için `cx.background_executor().timer(settings.debounce).await`
  kullanılır.
- Debounce sonunda `cx.update_window(window, |_, window, cx| window.focus(&focus, cx))`
  çağrılır.
- Daha spesifik child focus target'ı varken parent hover onu ezmesin diye
  `focus_handle.contains(existing, window)` kontrolü yapılır.

Tuzaklar:

- Context menu action'ları focused element context'ine göre enable/disable olur;
  menüyü focus context'i olmadan kurarsan bazı action'lar görünür ama çalışmayabilir.
- ApplicationMenu platform menu bar değildir; macOS native menü ayrı platform
  menü akışından gelir.
- Focus-follows-mouse global debounce state kullanır; aynı anda birden çok hover
  target'ı yarışabilir, bu nedenle daha spesifik child kontrolünü kaldırma.

---

---

