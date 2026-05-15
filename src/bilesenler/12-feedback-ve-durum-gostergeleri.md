# 12. Feedback ve Durum Göstergeleri

Feedback bileşenleri kullanıcıya uygulama durumunu anlatır: bilgi, başarı, uyarı,
hata, ilerleme, sayaç veya dikkat gerektiren karar. Bu gruptaki bileşenler aynı
tema token'larını kullanır ama farklı yoğunluklarda görünür:

- `Banner`: sayfa veya panel üstünde kısa, non-blocking mesaj.
- `Callout`: içerik akışı içinde daha açıklayıcı, karar veya aksiyon gerektiren
  mesaj.
- `Modal`: kendi modal içeriğinizi kurmak için shell.
- `AlertModal`: kısa karar akışı veya uyarı diyalogu.
- `AnnouncementToast`: yeni özellik veya duyuru kartı; lifecycle parent
  notification sistemi tarafından yönetilir.
- `CountBadge`, `Indicator`, `ProgressBar`, `CircularProgress`: küçük durum ve
  ilerleme göstergeleri.

## Severity

Kaynak:

- Tanım: `../zed/crates/ui/src/styles/severity.rs`
- Export: `ui::Severity`
- Prelude: `ui::prelude::*` içinde gelir.

Ne zaman kullanılır:

- Mesajın tonunu `Info`, `Success`, `Warning`, `Error` olarak tek enum üzerinden
  seçmek için.
- `Banner` ve `Callout` gibi bileşenlerde icon, background ve border rengini
  otomatik eşleştirmek için.

Davranış:

- `Banner` ve `Callout`, severity değerinden icon ve status renklerini türetir.
- `Info` nötr/muted, `Success` yeşil, `Warning` sarı, `Error` kırmızı status
  token'larını kullanır.
- Severity, kullanıcıya gösterilen metnin yerine geçmez. Mesaj kısa ve açık
  olmalıdır; aksiyon varsa ayrı button slot'u kullanın.

## Banner

Kaynak:

- Tanım: `../zed/crates/ui/src/components/banner.rs`
- Export: `ui::Banner`
- İlgili tipler: `ui::Severity`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Banner`

Ne zaman kullanılır:

- Sayfa veya panel içinde kısa bilgi, başarı, uyarı veya hata mesajı göstermek
  için.
- Kullanıcıyı akıştan koparmadan bir CTA veya düzeltme aksiyonu sunmak için.
- İçeriğin üstünde veya ilgili bölümün başında non-blocking mesaj göstermek için.

Ne zaman kullanılmaz:

- Uzun açıklama, bullet listesi veya ayrıntılı karar gerekiyorsa `Callout`.
- Kullanıcının devam etmeden karar vermesi gerekiyorsa `AlertModal`.
- Kısa süreli global bildirim lifecycle'ı gerekiyorsa app notification altyapısı
  ve uygun notification view kullanın.

Temel API:

- `Banner::new()`
- `.severity(Severity)`
- `.action_slot(element)`
- `.wrap_content(bool)`
- ParentElement: `.child(...)`, `.children(...)`

Davranış:

- Varsayılan severity `Severity::Info`.
- Severity'ye göre icon, background ve border rengi seçilir.
- `action_slot(...)` varsa banner sağ tarafta aksiyon alanı açar ve içerik
  padding'i ona göre değişir.
- `.wrap_content(true)`, dar alanlarda içeriğin satıra kırılmasına izin verir.

Örnek:

```rust
use ui::{Banner, Button, Icon, IconName, IconSize, Severity, prelude::*};

fn render_sync_banner() -> impl IntoElement {
    Banner::new()
        .severity(Severity::Info)
        .child(Label::new("Sync in progress"))
        .action_slot(
            Button::new("view-sync", "View")
                .end_icon(Icon::new(IconName::ArrowUpRight).size(IconSize::Small)),
        )
}
```

Çok satırlı içerik:

```rust
use ui::{Banner, Severity, prelude::*};

fn render_deprecation_banner() -> impl IntoElement {
    Banner::new()
        .severity(Severity::Warning)
        .wrap_content(true)
        .child(
            Label::new(
                "This setting is deprecated and will be ignored in a future release.",
            )
            .size(LabelSize::Small),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension upsell ve
  registry migration banner'ları.
- `../zed/crates/settings_ui/src/pages/tool_permissions_setup.rs`: ayar sayfası
  uyarıları.
- `../zed/crates/language_models/src/provider/opencode.rs`: provider durum
  mesajları.

Dikkat edilecekler:

- Banner kısa olmalıdır; birden fazla paragraf veya liste gerekiyorsa `Callout`.
- `action_slot(...)` içinde birden çok aksiyon gerekiyorsa `h_flex().gap_1()`
  ile açık spacing kurun.
- Banner'ı modal içi karar alanı gibi kullanmayın; modal kararları footer
  aksiyonlarıyla verilmelidir.

## Callout

Kaynak:

- Tanım: `../zed/crates/ui/src/components/callout.rs`
- Export: `ui::Callout`, `ui::BorderPosition`
- İlgili tipler: `ui::Severity`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Callout`

Ne zaman kullanılır:

- İçerik içinde kullanıcının okuması gereken açıklama, sınırlama veya karar
  mesajı göstermek için.
- Başlık, açıklama, aksiyon ve dismiss kontrolünü tek yüzeyde toplamak için.
- Markdown veya özel element gibi metin dışı açıklama içeriği gerekiyorsa
  `description_slot(...)` ile.

Ne zaman kullanılmaz:

- Sadece tek satırlık sayfa üstü mesaj için `Banner`.
- Global geçici bildirim için notification host.
- Bloklayıcı karar için `AlertModal`.

Temel API:

- `Callout::new()`
- `.severity(Severity)`
- `.icon(IconName)`
- `.title(text)`
- `.description(text)`
- `.description_slot(element)`
- `.actions_slot(element)`
- `.dismiss_action(element)`
- `.line_height(px)`
- `.border_position(BorderPosition::Top | BorderPosition::Bottom)`

Davranış:

- Varsayılan severity `Severity::Info`.
- `.icon(...)` çağrılmadığında icon alanı render edilmez; çağrıldığında icon rengi
  severity'den türetilir.
- `.description_slot(...)`, `.description(...)` ile aynı anda verilirse slot
  önceliklidir.
- Açıklama alanı `max_h_32()` ve `overflow_y_scroll()` kullanır; uzun içerikte
  callout yüksekliği kontrol altında kalır.
- Aksiyon ve dismiss slot'ları title satırının sağında render edilir.

Örnek:

```rust
use ui::{Button, Callout, IconButton, IconName, IconSize, Severity, prelude::*};

fn render_retry_callout() -> impl IntoElement {
    Callout::new()
        .severity(Severity::Warning)
        .icon(IconName::Warning)
        .title("Connection failed")
        .description("Retrying in 10 seconds. Check your network settings if this continues.")
        .actions_slot(Button::new("retry-now", "Retry now").label_size(LabelSize::Small))
        .dismiss_action(
            IconButton::new("dismiss-retry", IconName::Close).icon_size(IconSize::Small),
        )
}
```

Özel açıklama slot'u:

```rust
use ui::{Callout, IconName, Severity, prelude::*};

fn render_permission_callout() -> impl IntoElement {
    Callout::new()
        .severity(Severity::Error)
        .icon(IconName::XCircle)
        .title("Permission denied")
        .description_slot(
            v_flex()
                .gap_1()
                .child(Label::new("The selected command cannot run in this workspace."))
                .child(Label::new("Open workspace settings to allow it.").color(Color::Muted)),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: agent retry,
  token ve tool kullanımı uyarıları.
- `../zed/crates/zed/src/visual_test_runner.rs`: visual test durum mesajları.

Dikkat edilecekler:

- `Callout` içeriği flow içinde yer alır; viewport'u kaplayan bir overlay gibi
  davranmaz.
- Icon göstermek istiyorsanız `.icon(...)` açıkça çağrılmalıdır.
- Description slot'una scroll yapan karmaşık içerik koyarken içerideki metinlerin
  `min_w_0()` / `.truncate()` davranışını ayrıca düşünün.

## Modal

Kaynak:

- Tanım: `../zed/crates/ui/src/components/modal.rs`
- Export: `ui::Modal`, `ui::ModalHeader`, `ui::ModalRow`, `ui::ModalFooter`,
  `ui::Section`, `ui::SectionHeader`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Modal içeriğini Zed'in header, section ve footer düzeniyle kurmak için.
- Çok bölümlü ayar, form veya seçim akışı oluşturmak için.
- Scroll handle'ı dışarıdan yönetilen modal body gerektiğinde.

Ne zaman kullanılmaz:

- Kısa uyarı ve iki aksiyonlu karar için `AlertModal` daha az kodla doğru
  davranışı verir.
- Modal dışı panel veya sayfa düzeni için `v_flex()` / `Section` dışı layout daha
  uygundur.

Temel API:

- `Modal::new(id, scroll_handle)`
- `.header(ModalHeader)`
- `.section(Section)`
- `.footer(ModalFooter)`
- `.show_dismiss(bool)`
- `.show_back(bool)`
- ParentElement: `.child(...)`, `.children(...)`
- `ModalHeader::new().headline(...).description(...).icon(...).show_dismiss_button(...).show_back_button(...)`
- `ModalFooter::new().start_slot(...).end_slot(...)`
- `Section::new()`, `Section::new_contained()`, `.contained(bool)`,
  `.header(...)`, `.meta(...)`, `.padded(bool)`
- `SectionHeader::new(label).end_slot(...)`
- `ModalRow::new()`

Davranış:

- Modal root `size_full()`, `flex_1()` ve `overflow_hidden()` kullanır; modal
  container'ı genellikle parent overlay tarafından sağlanır.
- `scroll_handle` verilirse body `overflow_y_scroll()` ve `track_scroll(...)`
  ile bağlanır.
- `show_dismiss(true)` ve `show_back(true)`, header'da Zed'in `menu::Cancel`
  aksiyonunu dispatch eden icon button'lar üretir.
- `Section::new_contained()` border'lı iç yüzey üretir; normal `Section` daha
  düz bir akış verir.

Örnek:

```rust
use ui::{
    Button, Modal, ModalFooter, ModalHeader, ModalRow, Section, SectionHeader, prelude::*,
};

fn render_project_settings_modal() -> impl IntoElement {
    Modal::new("project-settings-modal", None)
        .show_dismiss(true)
        .header(
            ModalHeader::new()
                .headline("Project Settings")
                .description("Changes apply to the current workspace."),
        )
        .section(
            Section::new()
                .header(SectionHeader::new("Behavior"))
                .child(
                    ModalRow::new()
                        .child(Label::new("Format on save").flex_1())
                        .child(Label::new("Enabled").color(Color::Muted)),
                ),
        )
        .footer(ModalFooter::new().end_slot(Button::new("save-settings", "Save")))
}
```

Modal lifecycle ve workspace entegrasyonu:

Zed UI `Modal` bileşeni yalnızca içerik shell'idir; modal'ın açılıp
kapanmasını yöneten asıl katman `workspace::ModalLayer` ve
`workspace::ModalView` trait'idir.

```rust
use gpui::{Entity, ManagedView};
use ui::{Modal, ModalFooter, ModalHeader, Section, prelude::*};
use workspace::{ModalView, Workspace};

struct ProjectSettingsModal {
    focus_handle: gpui::FocusHandle,
}

impl gpui::EventEmitter<gpui::DismissEvent> for ProjectSettingsModal {}

impl gpui::Focusable for ProjectSettingsModal {
    fn focus_handle(&self, _cx: &App) -> gpui::FocusHandle {
        self.focus_handle.clone()
    }
}

impl ManagedView for ProjectSettingsModal {}
impl ModalView for ProjectSettingsModal {}

impl Render for ProjectSettingsModal {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        Modal::new("project-settings-modal", None)
            .header(ModalHeader::new().headline("Project Settings"))
            .section(Section::new().child(Label::new("…")))
            .footer(ModalFooter::new().end_slot(Button::new("close", "Close")))
    }
}

fn open_project_settings(
    workspace: &mut Workspace,
    window: &mut Window,
    cx: &mut Context<Workspace>,
) {
    workspace.toggle_modal::<ProjectSettingsModal, _>(window, cx, |_window, cx| {
        ProjectSettingsModal {
            focus_handle: cx.focus_handle(),
        }
    });
}
```

`ModalView` trait sözleşmesi:

- `ManagedView`: yani `Render + Focusable + EventEmitter<DismissEvent>`.
- `on_before_dismiss(window, cx) -> DismissDecision`: kapanmadan önce
  validation veya kullanıcı onayı istenebilir. `DismissDecision::Pending`
  kapanmayı erteler, `DismissDecision::Dismiss(false)` iptal eder.
- `fade_out_background(&self) -> bool`: ekrandaki diğer içeriği soluklaştırmak
  için override edilebilir.
- `render_bare(&self) -> bool`: workspace `ModalLayer`'ın varsayılan elevation
  yüzeyini bypass etmek için.

`Workspace::toggle_modal::<V, _>(window, cx, build_fn)`, aynı modal türü zaten
açıksa kapatır, farklı bir modal açıksa onu kapatıp yenisini açar. `ModalLayer`,
dismiss event'ini dinler ve focus'u önceki elemana geri verir.

Dikkat edilecekler:

- `Modal` yalnızca içerik shell'idir; açma/kapama lifecycle'ı modal host veya
  parent view tarafından yönetilir.
- Header dismiss/back button'ları `menu::Cancel` dispatch eder; parent context bu
  aksiyonu ele almalıdır.
- Section içinde çok sayıda ayar satırı varsa body scroll handle'ı verin.
- Modal'ı bir AlertModal yerine kullanıyorsanız bile yine workspace üzerinden
  `toggle_modal` ile sunun; ayrı bir overlay altyapısı kurmaya gerek yoktur.

## AlertModal

Kaynak:

- Tanım: `../zed/crates/ui/src/components/notification/alert_modal.rs`
- Export: `ui::AlertModal`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for AlertModal`

Ne zaman kullanılır:

- Kullanıcıdan kısa bir onay veya iptal kararı almak için.
- Güvenlik, silme, workspace trust gibi devam etmeden önce anlaşılması gereken
  uyarılar için.
- Özel header veya footer gerekse de temel modal iskeletini hızlı kurmak için.

Ne zaman kullanılmaz:

- Non-blocking bilgi mesajı için `Banner` veya `Callout`.
- Çok bölümlü ayar formu için `Modal`.
- Yeni özellik duyurusu için `AnnouncementToast`.

Temel API:

- `AlertModal::new(id)`
- `.title(text)`
- `.header(element)`
- `.footer(element)`
- `.primary_action(label)`
- `.dismiss_label(label)`
- `.width(width)`
- `.key_context(context)`
- `.on_action::<A>(listener)`
- `.track_focus(&focus_handle)`
- ParentElement: `.child(...)`, `.children(...)`

Davranış:

- Varsayılan genişlik `px(440.)`.
- `.title(...)` verilirse küçük `Headline` içeren default header üretir.
- `.primary_action(...)` veya `.dismiss_label(...)` verilirse default footer
  üretilir. Label verilmezse primary `"Ok"`, dismiss `"Cancel"` olur.
- Default footer button'ları görünümü kurar; karar akışını Zed action sistemiyle
  `.on_action(...)` veya parent lifecycle üzerinden bağlayın.
- `.header(...)` ve `.footer(...)`, default header/footer yerine tamamen özel
  element render eder.

Örnek:

```rust
use ui::{AlertModal, prelude::*};

fn render_delete_alert() -> impl IntoElement {
    AlertModal::new("delete-project-alert")
        .title("Delete project?")
        .child("This removes the project from the recent projects list.")
        .primary_action("Delete")
        .dismiss_label("Cancel")
}
```

Özel header:

```rust
use ui::{AlertModal, Icon, IconName, prelude::*};

fn render_restricted_workspace_alert(cx: &App) -> impl IntoElement {
    AlertModal::new("restricted-workspace-alert")
        .width(rems(40.))
        .header(
            v_flex()
                .p_3()
                .gap_1()
                .bg(cx.theme().colors().editor_background.opacity(0.5))
                .border_b_1()
                .border_color(cx.theme().colors().border_variant)
                .child(
                    h_flex()
                        .gap_2()
                        .child(Icon::new(IconName::Warning).color(Color::Warning))
                        .child(Label::new("Unrecognized Workspace")),
                ),
        )
        .child("Restricted mode prevents workspace commands from running automatically.")
        .primary_action("Trust Workspace")
        .dismiss_label("Stay Restricted")
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/security_modal.rs`: restricted workspace karar
  akışı; `key_context`, `track_focus` ve `.on_action(...)` birlikte kullanılır.
- `../zed/crates/ui/src/components/notification/alert_modal.rs`: basic ve custom
  header preview örnekleri.

Dikkat edilecekler:

- Kısa ve karar odaklı tutun. Birden fazla section gerekiyorsa `Modal` kullanın.
- Tehlikeli aksiyonlarda primary label net olmalıdır; `"Ok"` yerine `"Delete"`,
  `"Trust Workspace"` gibi eylemi yazın.
- Focus ve keyboard action davranışı gerekiyorsa `key_context(...)` ve
  `track_focus(...)` bağlamadan sadece görsel modal üretmeyin.

## AnnouncementToast

Kaynak:

- Tanım: `../zed/crates/ui/src/components/notification/announcement_toast.rs`
- Export: `ui::AnnouncementToast`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for AnnouncementToast`

Ne zaman kullanılır:

- Yeni özellik, önemli değişiklik veya üründeki görünür duyuruları kart biçiminde
  göstermek için.
- İllüstrasyon, başlık, açıklama, bullet listesi ve iki aksiyonlu duyuru
  gerekiyorsa.

Ne zaman kullanılmaz:

- Hata, retry veya inline durum mesajı için `Banner` / `Callout`.
- Basit toast ihtiyacı için parent notification sisteminin daha küçük view'ını
  kullanın.
- Kullanıcının devam etmeden karar vermesi gerekiyorsa `AlertModal`.

Temel API:

- `AnnouncementToast::new()`
- `.illustration(element)`
- `.heading(text)`
- `.description(text)`
- `.bullet_item(element)`
- `.bullet_items(items)`
- `.primary_action_label(text)`
- `.primary_on_click(handler)`
- `.secondary_action_label(text)`
- `.secondary_on_click(handler)`
- `.dismiss_on_click(handler)`

Davranış:

- Varsayılan primary label `"Try Now"`, secondary label `"Learn More"`.
- Click handler'ları boş default closure ile gelir; gerçek davranış için parent
  view dismiss veya navigation callback'i bağlamalıdır.
- Root element `occlude()`, `relative()`, `w_full()` ve `elevation_3(cx)` kullanır.
- Sağ üstte close icon button render edilir; dismiss lifecycle'ı
  `.dismiss_on_click(...)` callback'ine bırakılır.

Örnek:

```rust
use ui::{AnnouncementToast, ListBulletItem, prelude::*};

fn render_feature_announcement() -> impl IntoElement {
    div().w_80().child(
        AnnouncementToast::new()
            .heading("Parallel agents")
            .description("Run multiple agent threads across projects.")
            .bullet_item(ListBulletItem::new("Launch agents in isolated worktrees"))
            .bullet_item(ListBulletItem::new("Review progress without changing tabs"))
            .primary_action_label("Try Now")
            .primary_on_click(|_, _window, cx| cx.open_url("https://zed.dev"))
            .secondary_action_label("Learn More")
            .secondary_on_click(|_, _window, cx| cx.open_url("https://zed.dev/docs"))
            .dismiss_on_click(|_, _window, _cx| {}),
    )
}
```

Zed içinden kullanım:

- `../zed/crates/auto_update_ui/src/auto_update_ui.rs`: announcement toast
  notification view'ı; click handler'lar telemetry, URL ve dismiss callback'leri
  ile bağlanır.

Dikkat edilecekler:

- `AnnouncementToast` tek başına notification lifecycle'ı yönetmez. Dismiss,
  suppress veya route davranışı parent notification view içinde uygulanmalıdır.
- Bullet sayısını sınırlı tutun; çok uzun duyuru kartı kullanıcıyı akıştan koparır.
- İllüstrasyon eklenirse toast'ın üstünde render edilir ve body'den border ile
  ayrılır.

## Notification Modülü

Kaynak:

- Modül: `../zed/crates/ui/src/components/notification.rs`
- Export: `ui::AlertModal`, `ui::AnnouncementToast`
- Prelude: Hayır.

Mevcut `ui` kaynağında standalone `Notification` component'i yoktur.
`notification.rs`, yalnızca `alert_modal` ve `announcement_toast` modüllerini
re-export eder. Runtime bildirim kuyruğu, dismiss/suppress event'leri ve
notification trait'leri Zed'in daha üst seviye notification altyapısında tutulur.

Pratik sonuç:

- UI component olarak `AlertModal` veya `AnnouncementToast` render edin.
- Gösterme, saklama, kapatma ve tekrar göstermeme kararını parent notification
  view'ında yönetin.
- Toast içindeki click handler'larda gerekirse telemetry, URL açma ve dismiss
  akışını birlikte bağlayın.

## CountBadge

Kaynak:

- Tanım: `../zed/crates/ui/src/components/count_badge.rs`
- Export: `ui::CountBadge`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for CountBadge`

Ne zaman kullanılır:

- Icon, tab veya compact toolbar item üzerinde küçük sayaç göstermek için.
- Bildirim, hata, değişiklik veya bekleyen öğe sayısını küçük alanda belirtmek
  için.

Ne zaman kullanılmaz:

- Sayısal değer ana içerikse `Label` veya tablo hücresi kullanın.
- Durum sadece var/yok ise `Indicator::dot()` daha sade olabilir.

Temel API:

- `CountBadge::new(count)`

Davranış:

- `count > 99` için `"99+"` gösterir.
- `absolute()`, `top_0()`, `right_0()` ile parent'ın sağ üstüne yerleşir.
- Parent element `relative()` değilse badge beklenen anchor'a oturmaz.
- Background, editor background ile error status renginin blend edilmesiyle
  hesaplanır.

Örnek:

```rust
use ui::{CountBadge, IconButton, IconName, prelude::*};

fn render_notifications_button(count: usize) -> impl IntoElement {
    div()
        .relative()
        .child(IconButton::new("notifications", IconName::Bell))
        .when(count > 0, |this| this.child(CountBadge::new(count)))
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/dock.rs`: dock item üzerinde count badge.
- `../zed/crates/ui/src/components/count_badge.rs`: capped count preview.

Dikkat edilecekler:

- Parent'ın hitbox'ı ve badge'in absolute konumu birlikte düşünülmelidir; çok
  küçük icon button'larda badge tıklanabilir alanı görsel olarak kalabalıklaştırır.
- Badge metni otomatik capped olduğu için gerçek tam sayıyı tooltip veya detay
  view'da göstermek gerekebilir.

## Indicator

Kaynak:

- Tanım: `../zed/crates/ui/src/components/indicator.rs`
- Export: `ui::Indicator`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Indicator`

Ne zaman kullanılır:

- Küçük durum noktası, üst bar veya icon tabanlı durum göstergesi gerektiğinde.
- Liste satırında connection, breakpoint, conflict, active/inactive gibi hızlı
  taranabilir durumlar için.
- Icon button veya list item yanında dikkat çekmeyen status işareti için.

Ne zaman kullanılmaz:

- İşlem ilerlemesi için `ProgressBar` veya `CircularProgress`.
- Metinsel açıklama gerekiyorsa yanında `Label` kullanın; indicator tek başına
  erişilebilir anlam taşımaz.

Temel API:

- `Indicator::dot()`
- `Indicator::bar()`
- `Indicator::icon(icon)`
- `.color(Color)`
- `.border_color(Color)`

Davranış:

- Dot: `w_1p5()`, `h_1p5()`, `rounded_full()`.
- Bar: `w_full()`, `h_1p5()`, `rounded_t_sm()`; parent genişliği önemlidir.
- Icon indicator, icon'u `custom_size(rems_from_px(8.))` ile küçük render eder.
- `border_color(...)`, sadece dot ve bar için border uygular.

Örnek:

```rust
use ui::{Indicator, prelude::*};

fn render_connection_state(connected: bool) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            Indicator::dot().color(if connected {
                Color::Success
            } else {
                Color::Error
            }),
        )
        .child(Label::new(if connected { "Connected" } else { "Disconnected" }))
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/status_bar.rs`: status bar indicator.
- `../zed/crates/debugger_ui/src/dropdown_menus.rs`: debug session state.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: conflict indicator.
- `../zed/crates/title_bar/src/title_bar.rs`: title bar durum noktaları.

Dikkat edilecekler:

- Rengi `Color::Success`, `Warning`, `Error`, `Info`, `Muted` gibi semantic
  token'lardan seçin.
- Indicator'ı tek bilgi kaynağı yapmayın; özellikle error/warning durumlarında
  tooltip veya label ile anlamı belirtin.

## ProgressBar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/progress/progress_bar.rs`
- Export: `ui::ProgressBar`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ProgressBar`

Ne zaman kullanılır:

- İşlemin belirli bir `value / max_value` oranı varsa.
- Yatay alanda dosya indirme, kullanım limiti, sync veya task progress göstermek
  için.

Ne zaman kullanılmaz:

- İlerleme oranı bilinmiyorsa `LoadingLabel` veya `SpinnerLabel` kullanın.
- Çok dar inline alanda ring görünümü daha uygunsa `CircularProgress`.

Temel API:

- `ProgressBar::new(id, value, max_value, cx)`
- `.value(value)`
- `.max_value(max_value)`
- `.bg_color(hsla)`
- `.fg_color(hsla)`
- `.over_color(hsla)`

Davranış:

- Fill genişliği `(value / max_value).clamp(0.02, 1.0)` ile hesaplanır.
- `value > max_value` durumunda fill rengi `over_color` olur.
- Varsayılan foreground renk `cx.theme().status().info`.
- `max_value` pozitif olmalıdır; sıfır veya anlamsız max değer üretmeyin.

Örnek:

```rust
use ui::{ProgressBar, prelude::*};

fn render_usage_progress(used: f32, limit: f32, cx: &App) -> impl IntoElement {
    v_flex()
        .gap_1()
        .child(
            h_flex()
                .justify_between()
                .child(Label::new("Usage"))
                .child(Label::new(format!("{used:.0} / {limit:.0}")).color(Color::Muted)),
        )
        .child(ProgressBar::new("usage-progress", used, limit, cx))
}
```

Zed içinden kullanım:

- `../zed/crates/edit_prediction_ui/src/edit_prediction_button.rs`: kullanım
  limiti progress bar'ı.
- `../zed/crates/ui/src/components/progress/progress_bar.rs`: empty, partial ve
  filled preview örnekleri.

Dikkat edilecekler:

- `value` ve `max_value` aynı birimde olmalıdır.
- Progress bar'a yalnızca renk yüklemeyin; yakınında label veya tooltip ile
  bağlam verin.
- `value > max_value` bilinçli over-limit durumudur; normal tamamlandı state'i
  için `value == max_value` kullanın.

## CircularProgress

Kaynak:

- Tanım: `../zed/crates/ui/src/components/progress/circular_progress.rs`
- Export: `ui::CircularProgress`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for CircularProgress`

Ne zaman kullanılır:

- Dar veya inline alanda belirli ilerleme oranını ring olarak göstermek için.
- Token kullanımı, compact quota veya küçük status cluster'larında.

Ne zaman kullanılmaz:

- Geniş yatay alanda metinle birlikte ilerleme göstermek için `ProgressBar`
  daha okunaklıdır.
- İlerleme oranı bilinmiyorsa spinner/loading bileşeni kullanın.

Temel API:

- `CircularProgress::new(value, max_value, size, cx)`
- `.value(value)`
- `.max_value(max_value)`
- `.size(px)`
- `.stroke_width(px)`
- `.bg_color(hsla)`
- `.progress_color(hsla)`

Davranış:

- Canvas üzerinde background circle ve progress arc çizer.
- Progress üstten başlar ve saat yönünde ilerler.
- Progress oranı `(value / max_value).clamp(0.0, 1.0)` ile hesaplanır.
- `progress >= 0.999` durumunda tam çember çizilir.
- Varsayılan stroke width `px(4.)`.

Örnek:

```rust
use ui::{CircularProgress, prelude::*};

fn render_token_ring(used: f32, max: f32, cx: &App) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            CircularProgress::new(used, max, px(18.), cx)
                .stroke_width(px(2.))
                .progress_color(cx.theme().status().info),
        )
        .child(Label::new(format!("{used:.0}/{max:.0}")).size(LabelSize::Small))
}
```

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: token usage
  ring'leri.
- `../zed/crates/ui/src/components/progress/circular_progress.rs`: farklı yüzde
  preview örnekleri.

Dikkat edilecekler:

- Ring küçük olduğunda label veya tooltip olmadan oranı okumak zordur.
- `max_value` pozitif olmalıdır.
- Aynı ekranda çok sayıda animated veya sık güncellenen canvas progress
  kullanıyorsanız repaint maliyetini düşünün.

## Feedback Kompozisyon Örnekleri

Sync durumu:

```rust
use ui::{Banner, ProgressBar, Severity, prelude::*};

fn render_sync_feedback(progress: f32, cx: &App) -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(
            Banner::new()
                .severity(Severity::Info)
                .child(Label::new("Sync in progress"))
                .child(Label::new("Remote changes are being applied.").color(Color::Muted)),
        )
        .child(ProgressBar::new("sync-progress", progress, 1.0, cx))
}
```

Toolbar sayaç ve durum:

```rust
use ui::{CountBadge, IconButton, IconName, Indicator, prelude::*};

fn render_review_toolbar_item(issue_count: usize, has_errors: bool) -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(
            div()
                .relative()
                .child(IconButton::new("review", IconName::Check))
                .when(issue_count > 0, |this| this.child(CountBadge::new(issue_count))),
        )
        .child(
            Indicator::dot().color(if has_errors {
                Color::Error
            } else {
                Color::Success
            }),
        )
}
```

Karar rehberi:

- Kısa, non-blocking, sayfa/panel üstü mesaj: `Banner`.
- İçerik içinde açıklama + aksiyon + dismiss: `Callout`.
- Çok bölümlü modal içerik: `Modal`.
- Kısa karar veya uyarı diyalogu: `AlertModal`.
- Yeni özellik duyurusu: `AnnouncementToast` + notification lifecycle.
- Sayı bindirme: `CountBadge`.
- Var/yok veya state noktası: `Indicator`.
- Belirli yatay ilerleme: `ProgressBar`.
- Belirli compact ilerleme: `CircularProgress`.

