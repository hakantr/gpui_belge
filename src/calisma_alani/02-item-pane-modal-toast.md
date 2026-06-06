# Item, Pane, Modal, Toast ve Notification Sistemi

GPUI bir UI framework'üdür. Zed'in çalışma alanı katmanı bunun üstünde tab/pane, modal, toast ve bildirim akışlarını standartlaştırır. Yeni bir editör benzeri panel veya komut yazarken bu sözleşmeleri bilmen gerekir.

![Item, Pane, Modal ve Notification Akışı](assets/item-pane-modal-notification.svg)

---

## Item ve ItemHandle

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

`ItemHandle` boxed veya dyn karşılığıdır; pane API'leri çoğunlukla `Box<dyn ItemHandle>` ile çalışır. `to_any_view`, `to_followable_item_handle`, `to_serializable_item_handle`, `to_searchable_item_handle` ve `downgrade_item` tip silinmiş view/search/follow/serialization köprüleridir. `project_paths`, `project_entry_ids`, `project_item_model_ids`, `workspace_settings`, `item_focus_handle`, `subscribe_to_item_events`, `relay_action`, `added_to_pane`, `on_release`, `dragged_tab_content` ve `can_autosave` ise pane yaşam döngüsü, focus, tab sürükleme, autosave ve action yönlendirme tarafında kullanılır. `FollowableItem` collab takibi için ek bir sözleşmedir.

`Item` ek davranış noktaları tab görünümü, yaşam döngüsü ve capability davranışını aynı trait içinde toplar. `tab_icon`, `tab_tooltip_content`, `suggested_filename`, `breadcrumb_location`, `breadcrumb_prefix`, `show_toolbar` ve `tab_extra_context_menu_actions` tab/breadcrumb UI'ını besler. `can_save`, `can_save_as`, `is_dirty`, `capability`, `toggle_read_only`, `has_deleted_file` ve `has_conflict` save ve dosya durumu kararlarını verir. `added_to_workspace`, `pane_changed`, `discarded`, `on_removed`, `set_nav_history`, `preserve_preview`, `pixel_position_of_cursor`, `handle_drop`, `to_item_events`, `act_as_type` ve `clone_on_split` ise pane yaşam döngüsü, preview, drag/drop, event çevirimi ve split davranışının genişletme noktalarıdır.

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

Tekli arabellek (`Singleton`) item'lar bu varsayılanı miras alır; tek proje öğelerinin yolunu döndürür. Çok-arabellek item'lar (`ProjectDiff`, `MultiDiffView` gibi editör sarmalayıcıları) birincil imlecin altındaki arabelleğin yolunu döndürmek için bu yöntemi geçersiz kılar. `Editor` ise `active_buffer(cx)` üzerinden aktif tamponu bularak uygulamasını geçersiz kılar. `SplittableEditor` da sağ taraf editörüne yönlendirir.

`ItemHandle::project_path`, `<T as Item>::active_project_path` çağrısına yönlendirir; geçersiz kılma (override) tek bir noktada tanımlanır ve tutarlı çalışır.

Status bar'ın breadcrumb güncellemesi ve git panelinin aktif dosya tespiti bu yol üzerinden çalışır. `ItemEvent::UpdateBreadcrumbs` olayı geldiğinde, aktif panedeki aktif item bu olayı yayarsa çalışma alanı `active_item_path_changed(false, window, cx)` çağrısını tetikler.

**Tipik akış.** Yeni bir tab türü oluşturmak şu adımlardan geçer:

- `impl Item for BenimGorunumum` yazarsın.
- `Workspace::open_path`, `open_paths` veya `open_abs_path` zaten `ProjectItem` üreterek doğru `Item` view'ini açar; özel bir akışta `Pane::add_item(Box::new(view), ...)` kullanırsın.
- `Pane::activate_item`, `close_active_item`, `split` (split direction ile yeni pane) Pane API'leridir; `navigate_backward` ise `GoBack` action'ının işleyicisidir.
- `Workspace::split_pane(pane, direction, cx)` mevcut pane'i böler.
- `Workspace::register_action::<A>(|workspace, &A, window, cx| ...)` çalışma alanı seviyesinde global action'ları ekler (komut paleti veya keymap üzerinden tetiklenir).

---

## ModalView ve Modal Layer

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

Status item'lar aktif pane item değiştikçe `set_active_pane_item` ile bilgilendirilir; bu sayede git branch indicator veya imleç konumu gibi item'lar odaktaki buffer'a göre güncellenir. `hide_setting()` `Some(HideStatusItem)` döndürürse status bar sağ tık menüsüne kaynakta `"Hide Button"` kaydı eklenir ve kullanıcı ayar dosyası `update_settings_file` üzerinden güncellenir. Item zaten başka bir ayarla koşullu görünüyorsa `None` döndürülebilir.

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

**Item, follow, modal ve toast ek kapsamı.** Bu dışa açık yüzeyler item yaşam döngüsünün yan kanallarıdır: tab ayarları, follow/collab bağlantısı, modal stack ve notification host davranışını tamamlar.

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
| `add_hide_button_entry` | Status bar sağ tık menüsüne kaynakta `"Hide Button"` kaydını ekleyen yardımcıdır; `hide_setting()` döndüren item'larla birlikte kullanılır. |

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
- `Workspace::open_url_or_file(url_or_path, base_path, window, cx)` — metni önce URL olarak çözmeyi dener (`http`/`https` ve tanımadığı şemalar dış uygulamada `cx.open_url` ile açılır, `file://` yerel dosya olur); URL değilse dosya yolu sayar ve mutlak yolu doğrudan, göreli yolu önce `base_path`'e göre (yerel projede ve dosya gerçekten varsa) sonra proje worktree'lerine göre çözüp açar. Hiçbiri tutmazsa metni yine `cx.open_url` ile işletim sistemine bırakır. Markdown'daki, hover açıklamasındaki veya bildirimdeki bağlantılar gibi "URL mü, dosya mı belli değil" akışlarında kullanırsın.
- `Workspace::split_abs_path(...)`, `split_path(...)`, `split_item(...)` — yeni pane oluşturarak path veya item'i split içinde açar.

---

## Dikkat Noktaları

Item ve çalışma alanı tarafında dikkat edilmesi gereken hataya açık kullanımlar:

- `Item` uygulamasında `Self::Event` türünü doğru tanımlaman ve `EventEmitter<Self::Event>` uygulaman şarttır; aksi halde `Item` trait bound'u tutmaz.
- `Pane::add_item`'ı `Box::new(view)` ile çağırırsın; pane item sahipliğini alır.
- `Workspace::register_action` geri çağrı imzası `Fn(&mut Self, &A, &mut Window, &mut Context<Self>)` biçimindedir; diğer GPUI `on_action` dinleyicilerinden farklı bir pozisyonel düzene sahiptir (`&A` ortada).
- `NotificationId::Unique(TypeId::of::<T>())` ile aynı tipte iki notification açıldığında ikincisi birincinin yerine geçer; farklı bir sub-id isteniyorsa `Composite(TypeId, ElementId)` kullanırsın.
- `Toast` autohide süresi varsayılan değildir; uzun mesajlarda elle `dismiss_toast` çağrısı gerekebilir.
- `ModalView::on_before_dismiss` `Pending` (ya da `Dismiss(false)`) döndürürse modal kapatılmaz; açık kalır. Burada bir bekleme veya async çözümleme yoktur; kapanmayı kendin istediğinde modeli güncelleyip kapatma akışını yeniden çağırman gerekir.
