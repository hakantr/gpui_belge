# Item, Pane, Modal, Toast ve Notification Sistemi

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Pane` | `focus_handle` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Item` | Trait üyeleri 1 | `act_as_type`, `active_project_path`, `added_to_workspace`, `as_searchable`, `breadcrumb_location`, `breadcrumb_prefix`, `can_save`, `can_save_as`, `capability`, `clone_on_split`, `discarded`, `handle_drop`, `has_conflict`, `has_deleted_file`, `is_dirty`, `on_removed` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `Item` | Trait üyeleri 2 | `pane_changed`, `pixel_position_of_cursor`, `preserve_preview`, `set_nav_history`, `show_toolbar`, `suggested_filename`, `tab_extra_context_menu_actions`, `tab_icon`, `tab_tooltip_content`, `to_item_events`, `toggle_read_only` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `Pane` | Metotlar 1 | `activate_item`, `activate_last_item`, `activate_next_item`, `activate_previous_item`, `activation_history`, `active_item_index`, `add_item`, `add_item_inner`, `autosave_item`, `can_navigate_backward`, `can_navigate_forward`, `close_active_item`, `close_all_items`, `close_clean_items`, `close_current_preview_item`, `close_item_by_id`, `close_items`, `close_items_for_project_path`, `close_items_to_the_left_by_id`, `close_items_to_the_right_by_id`, `close_items_to_the_side_by_id`, `close_multibuffer_items`, `close_other_items` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Pane` | Metotlar 2 | `context_menu_focused`, `disable_history`, `display_nav_history_buttons`, `drag_split_direction`, `enable_history`, `focus_active_item`, `fork_nav_history`, `go_to_newer_tag`, `go_to_older_tag`, `handle_deleted_project_item`, `handle_item_edit`, `handle_tab_drop`, `has_focus`, `icon_color`, `in_center_group`, `index_for_item`, `is_active_item_pinned`, `is_active_preview_item`, `is_zoomed`, `item_for_entry`, `item_for_index`, `item_for_path`, `items_len` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Pane` | Metotlar 3 | `nav_history`, `nav_history_for_item`, `nav_history_mut`, `navigate_backward`, `new_item_context_menu_handle`, `pinned_count`, `preview_item`, `preview_item_id`, `preview_item_idx`, `project_item_restoration_data`, `remove_item_and_focus_on_pane`, `render_menu_overlay`, `replace_preview_item_id`, `save_item`, `set_can_split`, `set_can_toggle_zoom`, `set_close_pane_if_empty`, `set_pinned_count`, `set_render_tab_bar`, `set_render_tab_bar_buttons`, `set_should_display_tab_bar`, `set_should_display_welcome_page`, `set_zoom_out_on_close`, `set_zoomed` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Pane` | Metotlar 4 | `skip_save_on_close`, `split`, `split_item_context_menu_handle`, `swap_item_left`, `swap_item_right`, `take_active_item`, `toggle_zoom`, `toolbar`, `track_alternate_file_items`, `unpreview_item_if_preview`, `zoom_in` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Toast` | Metotlar | `autohide` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


GPUI bir UI framework'üdür. Zed'in çalışma alanı katmanı bunun üstünde tab/pane, modal, toast ve bildirim akışlarını standartlaştırır. Yeni bir editör benzeri panel veya komut yazarken bu sözleşmeleri bilmen gerekir.

![Item, Pane, Modal ve Notification Akışı](assets/item-pane-modal-notification.svg)

---

## Item ve ItemHandle

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `ItemHandle` | Trait üyeleri 1 | `added_to_pane`, `breadcrumbs`, `buffer_kind`, `can_autosave`, `can_split`, `deactivated`, `downgrade_item`, `dragged_tab_content`, `for_each_project_item`, `include_in_nav_history`, `item_focus_handle`, `item_id`, `navigate`, `on_release`, `project_entry_ids`, `project_item_model_ids`, `project_path`, `project_paths`, `relay_action`, `save`, `save_as`, `subscribe_to_item_events` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `ItemHandle` | Trait üyeleri 2 | `tab_content`, `tab_content_text`, `tab_tooltip_text`, `telemetry_event_text`, `to_any_view`, `to_followable_item_handle`, `to_searchable_item_handle`, `to_serializable_item_handle`, `workspace_deactivated`, `workspace_settings` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


Pane içindeki her tab içeriği `Item` trait'ini uygular:

```rust
pub trait Item: Focusable + EventEmitter<Self::Event> + Render + Sized {
    type Event;

    fn tab_content(&self, params: TabContentParams, window: &Window, cx: &App)
        -> AnyElement;
    fn tab_content_text(&self, detail: usize, cx: &App) -> SharedString;
    fn tab_tooltip_text(&self, _: &App) -> Option<SharedString> { None }
    fn deactivated(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn workspace_deactivated(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn telemetry_event_text(&self) -> Option<&'static str> { None }
    fn navigate(
        &mut self,
        _data: Arc<dyn Any + Send>,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> bool {
        false
    }
    // ... save/save_as, project_path, can_split, breadcrumbs, dragged_selection, ...
}
```

`ItemHandle` boxed veya dyn karşılığıdır; pane API'leri çoğunlukla `Box<dyn ItemHandle>` ile çalışır. `to_any_view`, `to_followable_item_handle`, `to_serializable_item_handle`, `to_searchable_item_handle` ve `downgrade_item` tip silinmiş view/search/follow/serialization köprüleridir. `project_paths`, `project_entry_ids`, `project_item_model_ids`, `workspace_settings`, `item_focus_handle`, `subscribe_to_item_events`, `relay_action`, `added_to_pane`, `on_release`, `dragged_tab_content` ve `can_autosave` ise pane lifecycle, focus, tab sürükleme, autosave ve action yönlendirme tarafında kullanılır. `FollowableItem` collab takibi için ek bir sözleşmedir.

`Item` hook'ları tab görünümü, lifecycle ve capability davranışını aynı trait içinde toplar. `tab_icon`, `tab_tooltip_content`, `suggested_filename`, `breadcrumb_location`, `breadcrumb_prefix`, `show_toolbar` ve `tab_extra_context_menu_actions` tab/breadcrumb UI'ını besler. `can_save`, `can_save_as`, `is_dirty`, `capability`, `toggle_read_only`, `has_deleted_file` ve `has_conflict` save ve dosya durumu kararlarını verir. `added_to_workspace`, `pane_changed`, `discarded`, `on_removed`, `set_nav_history`, `preserve_preview`, `pixel_position_of_cursor`, `handle_drop`, `to_item_events`, `act_as_type` ve `clone_on_split` ise pane lifecycle, preview, drag/drop, event çevirimi ve split davranışının extension noktalarıdır.

**`active_project_path`.** `Item` trait'inde varsayılan bir yöntem olarak tanımlıdır; `ItemHandle::project_path` ise buna yönlendirilmiştir:

```rust
fn active_project_path(&self, cx: &App) -> Option<ProjectPath> {
    if self.buffer_kind(cx) != ItemBufferKind::Singleton {
        return None;
    }
    let mut result = None;
    self.for_each_project_item(cx, &mut |_, item| {
        result = item.project_path(cx);
    });
    result
}
```

Tekli arabellek (`Singleton`) item'lar bu varsayılanı miras alır; tek proje öğelerinin yolunu döndürür. Çok-arabellek item'lar (`MultiBuffer`, `ProjectDiff`, `MultiDiffView` gibi) birincil imlecin altındaki arabelleğin yolunu döndürmek için bu yöntemi geçersiz kılar. `Editor` ise `active_buffer(cx)` üzerinden aktif tamponu bularak uygulamasını geçersiz kılar. `SplittableEditor` da sağ taraf editörüne yönlendirir.

`ItemHandle::project_path` artık `<T as Item>::active_project_path` çağrısına yönlendirilmiştir; dolayısıyla eski `for_each_project_item` mantığı tek bir yerde toplanmış ve geçersiz kılma mekanizması tutarlı hale gelmiştir.

Status bar'ın breadcrumb güncellemesi ve git panelinin aktif dosya tespiti bu yol üzerinden çalışır. `ItemEvent::UpdateBreadcrumbs` olayı geldiğinde — aktif panedeki aktif item bu olayı yayarsa — çalışma alanı `active_item_path_changed(false, window, cx)` çağrısını tetikler. Bu bağlantı önceden eksikti: olay `_ => {}` dalına düşüyor, herhangi bir yol değişikliği bildirilmiyordu. Artık bu dal açıkça ele alınmaktadır.

**Tipik akış.** Yeni bir tab türü oluşturmak şu adımlardan geçer:

- `impl Item for BenimGorunumum` yazılır.
- `Workspace::open_path`, `open_paths` veya `open_abs_path` zaten `ProjectItem` üreterek doğru `Item` view'ini açar; özel bir akışta `Pane::add_item(Box::new(view), ...)` kullanırsın.
- `Pane::activate_item`, `close_active_item`, `navigate_backward`, `navigate_forward`, `split` (split direction ile yeni pane) Pane API'leridir.
- `Workspace::split_pane(pane, direction, cx)` mevcut pane'i böler.
- `Workspace::register_action::<A>(|workspace, &A, window, cx| ...)` çalışma alanı seviyesinde global action'ları ekler (komut paleti veya keymap üzerinden tetiklenir).

---

## ModalView ve Modal Layer

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `ModalView` | Trait üyeleri | `fade_out_background`, `on_before_dismiss`, `render_bare` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


`ModalView` trait'i şu sözleşmeyi taşır:

```rust
pub trait ModalView: ManagedView {
    fn on_before_dismiss(
        &mut self,
        _window: &mut Window,
        _cx: &mut Context<Self>,
    ) -> DismissDecision {
        DismissDecision::Dismiss(true)
    }

    fn fade_out_background(&self) -> bool { false }
    fn render_bare(&self) -> bool { false }
}
```

`ManagedView = Focusable + EventEmitter<DismissEvent> + Render`. Modal yazarken bu bileşik trait'in sağlanması gerekir.

**Açma ve kapama.** Modal toggle akışı şu yardımcılara dayanır:

```rust
calisma_alani.toggle_modal(window, cx, |window, cx| {
    ModalGorunumu::new(window, cx)
});

calisma_alani.hide_modal(window, cx);
```

`toggle_modal` aynı tipte bir modal zaten açıksa onu kapatır; aksi halde yenisini açar. `on_before_dismiss` varsayılan olarak `DismissDecision::Dismiss(true)` döndürür. Bu metod `DismissDecision::Dismiss(false)` veya `Pending` döndürürse yeni modal görünmez.

---

## StatusBar ve StatusItemView

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `StatusItemView` | Trait üyeleri | `hide_setting`, `set_active_pane_item` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


`workspace` crate'i:

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

Çalışma alanı status bar'a item eklemek için:

```rust
calisma_alani.status_bar().update(cx, |durum_cubugu, cx| {
    durum_cubugu.add_left_item(sol_gorunum, window, cx);
    durum_cubugu.add_right_item(sag_gorunum, window, cx);
});
```

Status item'lar aktif pane item değiştikçe `set_active_pane_item` ile bilgilendirilir; bu sayede git branch indicator veya imleç konumu gibi item'lar odaktaki buffer'a göre güncellenir. `hide_setting()` `Some(HideStatusItem)` döndürürse status bar sağ tık menüsüne "Hide Button" kaydı eklenir ve kullanıcı ayar dosyası `update_settings_file` üzerinden güncellenir. Item zaten başka bir ayarla koşullu görünüyorsa `None` döndürülebilir.

---

## Notification ve Toast Sistemi

`workspace` crate'i:

```rust
pub trait Notification:
    EventEmitter<DismissEvent> + EventEmitter<SuppressEvent> + Focusable + Render
{}

pub enum NotificationId {
    Unique(TypeId),               // tip başına tek
    Composite(TypeId, ElementId), // tip + sub-id
    Named(SharedString),          // serbest isim
}

// Yapıcı yardımcıları:
// NotificationId::unique::<BildirimGorunumu>()
// NotificationId::composite::<BildirimGorunumu>(oge_id)
// NotificationId::named("kaydet".into())
```

Mesaj göstermek için kullanılan başlıca akışlar şunlardır:

```rust
calisma_alani.show_notification(
    NotificationId::unique::<BildirimGorunumu>(),
    cx,
    |cx| cx.new(|cx| BildirimGorunumu::new(cx)),
);

calisma_alani.show_toast(
    Toast::new(NotificationId::named("kaydet".into()), "Kaydedildi")
        .autohide(),
    cx,
);

calisma_alani.show_error(&hata, cx);
```

`Toast` hafif ve geçicidir (autohide); `Notification` ise kalıcı bir view'dir ve kullanıcı dismiss edene kadar görünür kalır. `SuppressEvent` aynı kaynaktan gelen tekrarlı bildirimleri bastırmak için kullanırsın.

`Workspace::toggle_status_toast<V: ToastView>` modal layer mantığında `ToastView` üzerinden toast'ı toggle eder; tipik UI elemanları (örneğin async iş ilerleme göstergeleri) bu yolla bağlanır.

```rust
pub trait ToastView: ManagedView {
    fn action(&self) -> Option<ToastAction>;
    fn auto_dismiss(&self) -> bool { true }
}
```

`ToastAction::new(label, on_click)` toast içindeki action butonunu tanımlar. `ToastView` tabanlı toast'larda auto dismiss varsayılan olarak `true`'dur. `Workspace::show_toast` ile gösterilen hafif `Toast` struct'ında ise `.autohide()` çağrılmadıkça otomatik kapanma yoktur.

---

## Item, modal, status ve toast API kapsamı

Bu bölümde bazı tipler davranışın ana başlığıdır (`Item`, `ModalView`, `Notification`), bazıları ise o davranışın seçenek veya olay taşıyıcısıdır. Aşağıdaki tablo ikinci grubu başlık şişirmeden kapsar.

| API | Rol |
|-----|-----|
| `workspace::Event` | Workspace seviyesinde pane ekleme/kaldırma, item ekleme/kaldırma, aktif item değişimi, modal açma, zoom değişimi ve panel ekleme gibi olayları yayar. |
| `workspace::pane::Event` | Pane seviyesinde item ekleme, aktivasyon, kapatma, split, pin/unpin, focus ve zoom olaylarını taşır. |
| `DismissDecision` | Modal kapanmadan önce `Dismiss(true)`, `Dismiss(false)` veya `Pending` kararı verir. |
| `HideStatusItem` | Status bar öğesinin sağ tık menüsünden kullanıcı ayarına gizleme yazmasını sağlar; `new` kapanışı alır, `apply` ayar dosyasını günceller. |
| `ItemEvent` | `CloseItem`, `UpdateTab`, `UpdateBreadcrumbs`, `Edit` sinyalleriyle item değişimini çalışma alanına bildirir. |
| `ItemBufferKind` | `Multibuffer`, `Singleton`, `None` ile item'in project buffer ilişkisini sınıflandırır. |
| `TabContentParams` | `detail`, `selected`, `preview`, `deemphasized` alanlarını tab çizimine taşır; `text_color()` anlamsal rengi üretir. |
| `TabTooltipContent` | Tooltip'i düz `Text` veya custom view üreten `Custom` kapanışı olarak temsil eder. |
| `OpenVisible` | Açılan path'in project panelde görünürlüğünü `All`, `None`, `OnlyFiles`, `OnlyDirectories` olarak sınırlar. |
| `NotificationId` | Bildirimleri `Unique(TypeId)`, `Composite(TypeId, ElementId)` veya `Named(SharedString)` kimliğiyle dedupe eder. |
| `SuppressEvent` | Kullanıcının aynı notification kaynağını bastırma isteğini notification view'den workspace'e taşır. |
| `ToastView` | `ManagedView` tabanlı toast view sözleşmesidir; `action()` buton action'ını, `auto_dismiss()` kapanma davranışını verir. |
| `ToastAction` | Toast içindeki buton için `id`, `label` ve optional `on_click` callback'ini taşır. |
| `modal_layer` | `ModalView`, `DismissDecision` ve modal stack davranışını barındıran modül sınırıdır. |
| `notifications` | Workspace notification listesi, notification id'leri, app-level notification ve hata yardımcılarının modül sınırıdır. |
| `pane` | Item tab listesi, split, zoom, close/save action'ları ve pane olaylarını barındıran ana modüldür. |

`Left`, `Right`, `All` gibi enum varyantlarında ayrı paragraf gerekmez; tablo satırındaki yön veya görünürlük etkisi okuyucunun API'yi kullanması için yeterlidir.

**Item, follow, modal ve toast ek kapsamı.** Bu public yüzeyler item lifecycle'ının yan kanallarıdır: tab ayarları, follow/collab bağlantısı, modal stack ve notification host davranışını tamamlar.

| API | Rol |
| :-- | :-- |
| `ActivateOnClose`, `ClosePosition`, `ShowCloseButton`, `ShowDiagnostics` | Tab kapatma sonrası aktivasyon, close button konumu, close button görünürlüğü ve diagnostic göstergesi ayarlarını item yüzeyine re-export eder. |
| `HighlightedText` | Tab veya item metadata'sında highlight pozisyonlarıyla birlikte metin taşımak için kullanılan küçük veri modelidir. |
| `WeakItemHandle`, `WeakFollowableItemHandle`, `FollowableItemHandle` | Item ve followable item'lara strong ownership almadan erişmek veya tip silinmiş follow sözleşmesine bağlanmak için kullanılır. |
| `FollowEvent`, `FollowableViewRegistry`, `FollowerState`, `LEADER_UPDATE_THROTTLE` | Follow event dönüşümü, remote view registry, follower state ve lider güncelleme throttling sabitini kapsar. |
| `ActiveModal` | Modal layer içinde açık modal view ve dismiss davranışını taşıyan internal state modelidir. |
| `ToastLayer`, `RestoreBanner`, `SuppressNotification`, `ClearAllNotifications` | Toast host, restore banner ve notification bastırma/temizleme action'larını temsil eder. |
| `Notifications`, `LanguageServerPrompt`, `ErrorMessagePrompt` | Workspace notification host'u ile language server ve hata prompt view'lerinin public yüzeyidir. |
| `PaneSearchBarCallbacks` | Pane search toolbar'ının match navigation ve replace callback'lerini pane dışındaki toolbar view'ına taşır. |
| `add_hide_button_entry` | Status bar sağ tık menüsüne "Hide Button" kaydını ekleyen helper'dır; `hide_setting()` döndüren item'larla birlikte kullanılır. |

---

## `Workspace::open_*` Akışı

Çalışma alanı içinde dosya açmanın birkaç yolu vardır; en doğrudan yol `open_paths`'tir. Tipik bir çağrı:

```rust
let gorev = calisma_alani.open_paths(
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

**Önemli giriş noktaları.** Çalışma alanı içinde içerik açmak için farklı ihtiyaçlara karşılık veren birkaç yardımcı vardır:

- `workspace::open_paths(paths, app_state, open_options, cx)` — bağımsız yardımcıdır; gerekirse pencere açar veya mevcut workspace'i yeniden kullanır.
- `Workspace::open_paths(abs_paths, OpenOptions, pane, window, cx)` — mevcut çalışma alanı içinde birden çok mutlak path açar.
- `Workspace::open_path(project_path, pane, focus, window, cx)` — belirli bir `ProjectPath`'i mevcut çalışma alanı içinde açar; `Task<Result<Box<dyn ItemHandle>>>` döner.
- `Workspace::open_abs_path(path, options, window, cx)` — `PathBuf` alır, dosyayı worktree'ye ekler ve item açar.
- `Workspace::open_path_preview(path, pane, focus_item, allow_preview, activate, window, cx)` — dosya bulucu gibi önizleme akışları için.
- `Workspace::split_abs_path(...)`, `split_path(...)`, `split_item(...)` — yeni pane oluşturarak path veya item'i split içinde açar.

---

## Tuzaklar

Item ve çalışma alanı tarafında dikkat edilmesi gereken yaygın hatalar:

- `Item` uygulamasında `Self::Event` türünün doğru tanımlanması ve `EventEmitter<Self::Event>` uygulanması şarttır; aksi halde `Item` trait bound'u tutmaz.
- `Pane::add_item` `Box::new(view)` ile yapılır; pane item sahipliğini alır.
- `Workspace::register_action` geri çağrı imzası `Fn(&mut Self, &A, &mut Window, &mut Context<Self>)` biçimindedir; diğer GPUI `on_action` dinleyicilerinden farklı bir pozisyonel düzene sahiptir (`&A` ortada).
- `NotificationId::Unique(TypeId::of::<T>())` ile aynı tipte iki notification açıldığında ikincisi birincinin yerine geçer; farklı bir sub-id isteniyorsa `Composite(TypeId, ElementId)` kullanırsın.
- `Toast` autohide süresi varsayılan değildir; uzun mesajlarda elle `dismiss_toast` çağrısı gerekebilir.
- `ModalView::on_before_dismiss` `Pending` döndürürse modal kapanma akışı beklemeye girer; testte `run_until_parked()` ile resolve sürecinin ilerletilmesi gerekir.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `ItemEvent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `CloseItem`, `Edit`, `UpdateBreadcrumbs`, `UpdateTab` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `TabContentParams`

| Grup | API | Not |
|---|---|---|
| Metotlar | `text_color` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `deemphasized`, `detail`, `preview`, `selected` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `TabTooltipContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Custom`, `Text` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ItemBufferKind`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Multibuffer`, `None`, `Singleton` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `WeakItemHandle`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `boxed_clone`, `id`, `upgrade` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `FollowEvent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Unfollow` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `FollowableItemHandle`

| Grup | API | Not |
|---|---|---|
| Trait metotları 1 | `add_event_to_update_proto`, `apply_update_proto`, `dedup`, `downgrade`, `is_project_item`, `remote_id`, `set_leader_id`, `to_follow_event` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 2 | `to_state_proto`, `update_agent_location` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `WeakFollowableItemHandle`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `upgrade` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `DismissDecision`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Dismiss`, `Pending` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `NotificationId`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Composite`, `Named`, `Unique` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `composite`, `named`, `unique` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `LanguageServerPrompt`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `ErrorMessagePrompt`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new`, `with_link_button` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `Event`

| Grup | API | Not |
|---|---|---|
| Varyantlar 1 | `ActivateItem`, `AddItem`, `ChangeItemTitle`, `Focus`, `ItemPinned`, `ItemUnpinned`, `JoinAll`, `JoinIntoNext` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Varyantlar 2 | `Remove`, `RemovedItem`, `Split`, `UserSavedItem`, `ZoomIn`, `ZoomOut` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `HideStatusItem`

| Grup | API | Not |
|---|---|---|
| Metotlar | `apply`, `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `ToastView`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `action`, `auto_dismiss` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `ToastAction`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `id`, `label`, `on_click` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ToastLayer`

| Grup | API | Not |
|---|---|---|
| Metotlar 1 | `active_toast`, `clear_dismiss_timer`, `has_active_toast`, `hide_toast`, `new`, `restart_dismiss_timer`, `show_toast`, `start_dismiss_timer` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 2 | `toggle_toast` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `PaneSearchBarCallbacks`

| Grup | API | Not |
|---|---|---|
| Alanlar | `setup_search_bar`, `wrap_div_with_search_actions` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `FollowableViewRegistry`

| Grup | API | Not |
|---|---|---|
| Metotlar | `from_state_proto`, `register`, `to_followable_view` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `Event`

| Grup | API | Not |
|---|---|---|
| Varyantlar 1 | `Activate`, `ActiveItemChanged`, `ContactRequestedJoin`, `ItemAdded`, `ItemRemoved`, `ModalOpened`, `OpenBundledFile`, `PaneAdded` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Varyantlar 2 | `PanelAdded`, `PaneRemoved`, `UserSavedItem`, `WorkspaceCreated`, `WorktreeCreationChanged`, `ZoomChanged` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `OpenVisible`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `All`, `None`, `OnlyDirectories`, `OnlyFiles` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
