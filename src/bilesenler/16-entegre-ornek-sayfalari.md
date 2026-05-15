# 16. Entegre Örnek Sayfaları

Bileşenleri tek tek doğru kullanmak yeterli değildir. Gerçek ekranlarda önemli
olan, state'in hangi view'da tutulduğu, event'lerin hangi sınırdan geçtiği,
asenkron işlerin nasıl izleneceği ve görsel state değişiminden sonra yeniden
render'ın nasıl tetikleneceğidir.

Bu bölümdeki örnekler tam ekran uygulama değildir; kendi domain tiplerinizi,
settings servislerinizi ve action tiplerinizi bağlayacağınız iskeletlerdir.
Kullanılan component API'leri `../zed` çalışma ağacındaki kaynak dosyalara göre
düzenlenmiştir.

Ortak uygulama kuralları:

- View'a ait geçici UI state'i view struct'ında tutun: seçili satır, açık menü,
  pending async task, hata mesajı, progress değeri.
- Paylaşılan veya servis kaynaklı state'i doğrudan component içinde saklamayın;
  render sırasında component'e label, status, icon, callback ve metadata olarak
  aktarın.
- View state'i değiştiren handler'larda `cx.listener(...)` kullanın. Bu sayede
  closure view instance'ına güvenli şekilde ulaşır.
- Görsel state değiştiğinde `cx.notify()` çağırın. Özellikle `selected`,
  `expanded`, `saving`, `error`, `progress` ve hover dışı custom state'lerde
  bunu atlamayın.
- Tamamlanması izlenecek asenkron işleri `Task` alanında saklayın. Sonucu UI'ı
  değiştirmeyen fire-and-forget işler için `.detach_and_log_err(cx)` kullanın.
- Menü içeriklerini `ContextMenu::build(...)` içinde oluşturun; menünün
  açılmasını `PopoverMenu` veya `right_click_menu(...)` gibi taşıyıcı
  bileşenlerle bağlayın.

## Ayarlar Paneli Satırı

Bu örnekte `Headline`, `Label`, `SwitchField`, `Button` ve `Callout` tek bir
ayar satırı içinde birlikte kullanılır.

Neden birlikte:

- `Headline` section başlığını verir.
- `Label` ayarın adı ve açıklaması için hafif metin katmanıdır.
- `SwitchField`, boolean ayarı erişilebilir bir toggle olarak yönetir.
- `Button`, elle kaydetme veya reset gibi komutları taşır.
- `Callout`, satırın altındaki hata, uyarı veya açıklayıcı aksiyonu gösterir.

State:

- `format_on_save`: switch'in render state'i.
- `saving`: button disable ve progress metni için geçici state.
- `last_error`: yalnızca hata olduğunda `Callout` render edilir.
- `_save_task`: ayar yazımı bitene kadar task'ın düşmemesi için tutulur.

Örnek:

```rust
use gpui::{ClickEvent, Task};
use ui::{
    Button, ButtonSize, ButtonStyle, Callout, Headline, HeadlineSize, IconName,
    Label, LabelSize, Severity, SwitchField, ToggleState, prelude::*,
};

struct EditorSettingsRow {
    format_on_save: bool,
    saving: bool,
    last_error: Option<SharedString>,
    _save_task: Option<Task<anyhow::Result<()>>>,
}

impl EditorSettingsRow {
    fn set_format_on_save(&mut self, selected: bool, cx: &mut Context<Self>) {
        self.format_on_save = selected;
        self.saving = true;
        self.last_error = None;
        cx.notify();

        self._save_task = Some(cx.spawn(async move |this, cx| {
            save_format_on_save(selected).await?;
            this.update(cx, |this, cx| {
                this.saving = false;
                cx.notify();
            })?;
            anyhow::Ok(())
        }));
    }

    fn retry_save(&mut self, cx: &mut Context<Self>) {
        self.set_format_on_save(self.format_on_save, cx);
    }
}

impl Render for EditorSettingsRow {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_3()
            .child(Headline::new("Editor").size(HeadlineSize::Small))
            .child(
                h_flex()
                    .justify_between()
                    .items_start()
                    .gap_3()
                    .child(
                        v_flex()
                            .gap_0p5()
                            .child(Label::new("Format on save"))
                            .child(
                                Label::new("Runs the configured formatter before writing files.")
                                    .size(LabelSize::Small)
                                    .color(Color::Muted),
                            ),
                    )
                    .child(
                        SwitchField::new(
                            "format-on-save",
                            Some("Enabled"),
                            Some("Apply formatting automatically".into()),
                            ToggleState::from(self.format_on_save),
                            cx.listener(
                                |this, selection: &ToggleState, _window, cx| {
                                    this.set_format_on_save(selection.selected(), cx);
                                },
                            ),
                        )
                        .disabled(self.saving),
                    ),
            )
            .child(
                Button::new("save-editor-settings", "Save Now")
                    .size(ButtonSize::Compact)
                    .style(ButtonStyle::Filled)
                    .disabled(self.saving)
                    .on_click(cx.listener(
                        |this, _: &ClickEvent, _window, cx| this.retry_save(cx),
                    )),
            )
            .when_some(self.last_error.clone(), |this, error| {
                this.child(
                    Callout::new()
                        .severity(Severity::Error)
                        .icon(IconName::Warning)
                        .title("Settings could not be saved")
                        .description(error)
                        .actions_slot(
                            Button::new("retry-editor-settings", "Retry")
                                .size(ButtonSize::Compact)
                                .on_click(cx.listener(
                                    |this, _: &ClickEvent, _window, cx| this.retry_save(cx),
                                )),
                        ),
                )
            })
    }
}
```

Dikkat edilecekler:

- `SwitchField::new(...)` callback'i yeni state'i `&ToggleState` olarak alır.
  `ToggleState::selected()` indeterminate state'i `false` kabul eder; üç durumlu
  bir ayarınız varsa `match` ile açık ele alın.
- Switch state'i optimistik güncelleniyorsa hata durumunda eski değeri geri
  yazın ve `cx.notify()` çağırın.
- Uzun süren yazımlarda `Button` ve `SwitchField` disabled olmalı; aksi halde
  aynı ayar için üst üste task başlatabilirsiniz.

## Toolbar ve Komut Menüsü

Bu örnekte `Button`, `IconButton`, `SplitButton`, `PopoverMenu`, `ContextMenu`,
`Tooltip` ve `KeybindingHint` aynı toolbar davranışını tamamlar.

Neden birlikte:

- `Button` veya `ButtonLike`, birincil komutu taşır.
- `IconButton`, compact komutlar ve menü tetikleyicileri için uygundur.
- `SplitButton`, birincil eylem ile varyant menüsünü tek kontrol gibi gösterir.
- `PopoverMenu`, tetikleyici ile `ContextMenu` view'ını ilişkilendirir.
- `Tooltip`, icon-only kontrollerin niyetini açıklar.
- `KeybindingHint`, gerçek keymap'ten gelen shortcut bilgisini görünür kılar.

Örnek:

```rust
use gpui::ClickEvent;
use ui::{
    ButtonLike, ButtonSize, ContextMenu, IconButton, IconName, Label,
    PopoverMenu, SplitButton, SplitButtonStyle, Tooltip, prelude::*,
};

struct CommandToolbar {
    can_run: bool,
}

impl CommandToolbar {
    fn run_default(&mut self, _window: &mut Window, cx: &mut Context<Self>) {
        self.can_run = false;
        cx.notify();

        cx.spawn(async move |_this, _cx| run_default_command().await)
            .detach_and_log_err(cx);
    }
}

impl Render for CommandToolbar {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let left = ButtonLike::new_rounded_left("run-default")
            .size(ButtonSize::Default)
            .disabled(!self.can_run)
            .child(Label::new("Run"))
            .on_click(cx.listener(
                |this, _: &ClickEvent, window, cx| this.run_default(window, cx),
            ))
            .tooltip(|_window, cx| Tooltip::simple("Run default command", cx));

        let right = PopoverMenu::<ContextMenu>::new("run-menu")
            .trigger(
                IconButton::new("run-menu-trigger", IconName::ChevronDown)
                    .size(ButtonSize::Default)
                    .tooltip(|_window, cx| Tooltip::simple("More run commands", cx)),
            )
            .menu(|window, cx| {
                Some(ContextMenu::build(window, cx, |menu, _window, _cx| {
                    menu.entry("Run All", None, |_window, _cx| {})
                        .entry("Run Selection", None, |_window, _cx| {})
                        .separator()
                        .entry("Configure Task...", None, |_window, _cx| {})
                }))
            });

        h_flex()
            .gap_1()
            .items_center()
            .child(
                SplitButton::new(left, right.into_any_element())
                    .style(SplitButtonStyle::Outlined),
            )
            .child(
                IconButton::new("stop-task", IconName::Stop)
                    .disabled(self.can_run)
                    .tooltip(|_window, cx| Tooltip::simple("Stop running task", cx)),
            )
    }
}
```

`KeybindingHint` için kural:

- Shortcut'ı sabit string olarak yazmayın; mümkünse uygulamadaki action/keymap
  çözümünden `ui::KeyBinding` üretin.
- Hint'i toolbar'da her zaman göstermeyin. Komut palette, empty state veya
  onboarding gibi bağlamlarda daha değerlidir.
- Icon-only button varsa `Tooltip` zorunlu kabul edilmelidir; label'lı button'da
  tooltip yalnızca ek bağlam sağlıyorsa kullanılmalıdır.

## Proje Listesi

Bu örnekte `List`, `ListItem`, `TreeViewItem`, `Disclosure`, `IndentGuides` ve
`CountBadge` proje gezgini benzeri bir görünümde birlikte kullanılır.

Neden birlikte:

- `List`, liste container'ı ve empty state davranışını sağlar.
- `ListItem`, satır slot'ları, selected state ve secondary click için uygundur.
- `TreeViewItem`, dosya ağacı gibi expand/collapse ve focus davranışı olan
  satırlarda kullanılır.
- `Disclosure`, özel satır layout'larında aç/kapat icon'unu ayırır.
- `IndentGuides`, virtualization kullanılan ağaç listelerinde girinti çizgilerini
  hesaplama/render sürecine bağlanır.
- `CountBadge`, klasör veya filtre sonucundaki sayıları kompakt gösterir.

State:

- `expanded_project_ids`: hangi root veya klasörlerin açık olduğu.
- `selected_path`: tek seçili proje/dosya yolu.
- `pending_context_menu_path`: sağ tık menüsü açılırken kullanılan yol.
- Büyük listelerde scroll ve virtualization state'i component dışında kalmalıdır.

Örnek:

```rust
use gpui::ClickEvent;
use std::collections::HashSet;
use ui::{
    CountBadge, Disclosure, Icon, IconName, Label, List, ListHeader, ListItem,
    TreeViewItem, prelude::*,
};

struct ProjectList {
    expanded: HashSet<SharedString>,
    selected_path: Option<SharedString>,
}

impl ProjectList {
    fn toggle_project(&mut self, project_id: SharedString, cx: &mut Context<Self>) {
        if !self.expanded.insert(project_id.clone()) {
            self.expanded.remove(&project_id);
        }
        cx.notify();
    }

    fn select_path(&mut self, path: SharedString, cx: &mut Context<Self>) {
        self.selected_path = Some(path);
        cx.notify();
    }
}

impl Render for ProjectList {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let project_id: SharedString = "zed".into();
        let project_open = self.expanded.contains(&project_id);
        let src_path: SharedString = "zed/crates/ui/src".into();

        List::new()
            .header(
                ListHeader::new("Projects")
                    .end_slot(CountBadge::new(3))
                    .toggle(Some(project_open))
                    .on_toggle(cx.listener({
                        let project_id = project_id.clone();
                        move |this, _: &ClickEvent, _window, cx| {
                            this.toggle_project(project_id.clone(), cx);
                        }
                    })),
            )
            .child(
                ListItem::new("project-zed")
                    .toggle_state(self.selected_path.as_ref() == Some(&project_id))
                    .start_slot(
                        Disclosure::new("project-zed-disclosure", project_open)
                            .on_click(cx.listener({
                                let project_id = project_id.clone();
                                move |this, _: &ClickEvent, _window, cx| {
                                    this.toggle_project(project_id.clone(), cx);
                                }
                            })),
                    )
                    .end_slot(CountBadge::new(12))
                    .child(Label::new("zed"))
                    .on_click(cx.listener({
                        let project_id = project_id.clone();
                        move |this, _: &ClickEvent, _window, cx| {
                            this.select_path(project_id.clone(), cx);
                        }
                    })),
            )
            .when(project_open, |this| {
                this.child(
                    TreeViewItem::new("project-zed-src", "crates/ui/src")
                        .expanded(true)
                        .toggle_state(self.selected_path.as_ref() == Some(&src_path))
                        .on_click(cx.listener({
                            let src_path = src_path.clone();
                            move |this, _: &ClickEvent, _window, cx| {
                                this.select_path(src_path.clone(), cx);
                            }
                        })),
                )
                .child(
                    ListItem::new("project-zed-components")
                        .indent_level(2)
                        .start_slot(Icon::new(IconName::Folder))
                        .child(Label::new("components"))
                        .end_slot(CountBadge::new(41)),
                )
            })
    }
}
```

`IndentGuides` notu:

- `IndentGuides`, düz `List` içine otomatik çizgi eklemez. `uniform_list` veya
  sticky item decoration bağlamında `indent_guides(indent_size, colors)` ile
  kullanılır.
- Girinti hesabı için `with_compute_indents_fn(...)`, özel çizim için
  `with_render_fn(...)` bağlayın.
- Girinti state'i satır verisinden türetilmelidir; her satırda ayrı ayrı çizgi
  elementleri üretmek büyük ağaçlarda gereksiz maliyet yaratır.

## Veri Tablosu

Bu örnekte `Table`, `TableInteractionState`, `RedistributableColumnsState`,
`Indicator` ve `ProgressBar` birlikte kullanılır.

Neden birlikte:

- `Table`, satır/sütun düzenini ve header davranışını sağlar.
- `TableInteractionState`, scroll ve focus state'ini view dışında tutulabilir
  hale getirir.
- `RedistributableColumnsState`, sabit toplam genişlik içinde kullanıcıya sütun
  yeniden dağıtımı verir.
- `Indicator`, satırdaki kısa status bilgisini gösterir.
- `ProgressBar`, tabloyu besleyen async işlerin ilerlemesini gösterir.

State:

- `interaction_state: Entity<TableInteractionState>`
- `columns_state: Entity<RedistributableColumnsState>`
- `rows: Vec<RowVm>`
- `sync_progress: Option<(f32, f32)>`

Örnek:

```rust
use ui::{
    ColumnWidthConfig, Indicator, ProgressBar, RedistributableColumnsState,
    Table, TableInteractionState, TableResizeBehavior, prelude::*,
};

struct PackageRow {
    name: SharedString,
    version: SharedString,
    status: PackageStatus,
}

enum PackageStatus {
    Ready,
    Updating,
    Failed,
}

struct PackageTable {
    interaction_state: Entity<TableInteractionState>,
    columns_state: Entity<RedistributableColumnsState>,
    rows: Vec<PackageRow>,
    sync_progress: Option<(f32, f32)>,
}

impl Render for PackageTable {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let table = self.rows.iter().fold(
            Table::new(3)
                .interactable(&self.interaction_state)
                .width_config(ColumnWidthConfig::redistributable(
                    self.columns_state.clone(),
                ))
                .striped()
                .header(vec!["Status", "Package", "Version"]),
            |table, row| {
                let color = match row.status {
                    PackageStatus::Ready => Color::Success,
                    PackageStatus::Updating => Color::Info,
                    PackageStatus::Failed => Color::Error,
                };

                table.row(vec![
                    Indicator::dot().color(color).into_any_element(),
                    row.name.clone().into_any_element(),
                    row.version.clone().into_any_element(),
                ])
            },
        );

        v_flex()
            .gap_2()
            .when_some(self.sync_progress, |this, (value, max)| {
                this.child(ProgressBar::new("package-sync-progress", value, max, cx))
            })
            .child(table)
    }
}
```

Kurulum notu:

```rust
fn new(cx: &mut Context<PackageTable>) -> PackageTable {
    PackageTable {
        interaction_state: cx.new(|cx| TableInteractionState::new(cx)),
        columns_state: cx.new(|_| {
            RedistributableColumnsState::new(
                3,
                vec![rems(5.), rems(16.), rems(8.)],
                vec![
                    TableResizeBehavior::None,
                    TableResizeBehavior::Resizable,
                    TableResizeBehavior::Resizable,
                ],
            )
        }),
        rows: Vec::new(),
        sync_progress: None,
    }
}
```

Dikkat edilecekler:

- `Table::row(...)` küçük ve sabit listeler için yeterlidir. Büyük veri setinde
  `uniform_list(...)` veya `variable_row_height_list(...)` kullanın.
- `RedistributableColumnsState::new(cols, widths, resize_behavior)` içindeki
  `cols`, width sayısı ve resize behavior sayısı aynı olmalıdır.
- Progress değeri değiştiğinde `sync_progress` güncellenmeli ve `cx.notify()`
  çağrılmalıdır.

## Bildirim Merkezi

Bu örnekte `Notification` yaşam döngüsü, `NotificationFrame`,
`AnnouncementToast`, `Banner`, `AlertModal` ve `Button` birlikte düşünülür.

Neden birlikte:

- `Banner`, ekran veya panel üstündeki non-blocking duyuruyu gösterir.
- `NotificationFrame`, workspace notification stack'inde başlık, içerik, close
  ve suppress davranışını çerçeveler.
- `AnnouncementToast`, ürün duyurusu veya yeni özellik tanıtımı için hazır
  layout sağlar.
- `AlertModal`, kısa ve blocking karar anlarında kullanılır.
- `Button`, banner, toast ve modal action yüzeyini tamamlar.

Örnek:

```rust
use gpui::ClickEvent;
use ui::{
    AlertModal, AnnouncementToast, Banner, Button, ButtonSize, ListBulletItem,
    Severity, prelude::*,
};
use workspace::notifications::NotificationFrame;

struct NotificationCenterPreview {
    show_restart_alert: bool,
}

impl Render for NotificationCenterPreview {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_3()
            .child(
                Banner::new()
                    .severity(Severity::Warning)
                    .child("Language server restarted after a crash.")
                    .action_slot(
                        Button::new("open-lsp-log", "Open Log")
                            .size(ButtonSize::Compact),
                    ),
            )
            .child(
                NotificationFrame::new()
                    .with_title(Some("Indexing project"))
                    .with_content("Symbols are still being indexed.")
                    .with_suffix(Button::new("hide-indexing", "Hide").size(ButtonSize::Compact))
                    .on_close(|suppress, _window, _cx| {
                        if *suppress {
                            persist_notification_suppression();
                        }
                    }),
            )
            .child(
                AnnouncementToast::new()
                    .heading("Agent threads can now be restored")
                    .description("Recent work is available from the thread history.")
                    .bullet_item(ListBulletItem::new("Open previous agent sessions"))
                    .bullet_item(ListBulletItem::new("Continue from saved context"))
                    .primary_action_label("Open Threads")
                    .primary_on_click(|_event, _window, _cx| open_thread_history())
                    .secondary_action_label("Learn More")
                    .secondary_on_click(|_event, _window, _cx| open_release_notes())
                    .dismiss_on_click(|_event, _window, _cx| dismiss_announcement()),
            )
            .when(self.show_restart_alert, |this| {
                this.child(
                    AlertModal::new("restart-required")
                        .title("Restart required")
                        .child("The update will be applied after restarting the application.")
                        .primary_action("Restart")
                        .dismiss_label("Later")
                        .on_action(cx.listener(
                            |this, _: &menu::Confirm, _window, cx| {
                                this.show_restart_alert = false;
                                cx.notify();
                            },
                        )),
                )
            })
    }
}
```

Notification yaşam döngüsü:

- Workspace notification stack'e girecek view, `workspace::notifications::Notification`
  trait sınırını karşılamalıdır: `Render`, `Focusable`,
  `EventEmitter<DismissEvent>` ve `EventEmitter<SuppressEvent>`.
- Dismiss veya suppress state'i component içinde unutulmamalı; kullanıcı tercihi
  kalıcıysa settings/KV store tarafına yazılmalıdır.
- Blocking karar gerekmiyorsa `AlertModal` yerine `Banner` veya
  `NotificationFrame` kullanın.

## AI Sağlayıcı Kartları

Bu örnekte `ConfiguredApiCard`, `AiSettingItem`, `AgentSetupButton`,
`ThreadItem` ve `UpdateButton` aynı AI ayar alanında birlikte kullanılır.

Neden birlikte:

- `AiSettingItem`, agent/provider satırının status ve kaynak bilgisini taşır.
- `ConfiguredApiCard`, credential var/yok state'ini güvenli, kısa bir kartla
  gösterir.
- `AgentSetupButton`, provider veya agent kurulumu için action satırı sağlar.
- `ThreadItem`, son agent oturumlarını listelemek için domain'e özel satırdır.
- `UpdateButton`, AI alanının dışındaki update/collab özel durumlarında da aynı
  compact status/action modelini gösterir.

Örnek:

```rust
use gpui::ClickEvent;
use ui::{
    AgentSetupButton, AgentThreadStatus, AiSettingItem, AiSettingItemSource,
    AiSettingItemStatus, ConfiguredApiCard, Icon, IconButton, IconName,
    ThreadItem, UpdateButton, prelude::*,
};

struct AiProviderPanel {
    provider_running: bool,
    selected_thread_id: Option<SharedString>,
}

impl Render for AiProviderPanel {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let thread_id: SharedString = "thread-42".into();

        v_flex()
            .gap_2()
            .child(
                AiSettingItem::new(
                    "openai-provider",
                    "OpenAI",
                    if self.provider_running {
                        AiSettingItemStatus::Running
                    } else {
                        AiSettingItemStatus::Stopped
                    },
                    AiSettingItemSource::Custom,
                )
                .icon(Icon::new(IconName::ZedAgent))
                .detail_label("Used by Assistant and inline edits")
                .action(
                    IconButton::new("openai-settings", IconName::Settings)
                        .on_click(|_event, _window, _cx| open_provider_settings()),
                )
                .details(
                    ConfiguredApiCard::new("API key configured")
                        .button_label("Reset Key")
                        .tooltip_label("Replace the stored API key")
                        .on_click(|_event, _window, _cx| reset_provider_key()),
                ),
            )
            .child(
                AgentSetupButton::new("setup-local-agent")
                    .icon(Icon::new(IconName::Terminal))
                    .name("Local Agent")
                    .state(Label::new("Not configured").color(Color::Muted))
                    .on_click(|_event, _window, _cx| open_agent_setup()),
            )
            .child(
                ThreadItem::new(thread_id.clone(), "Refactor settings panel")
                    .timestamp("2m ago")
                    .status(AgentThreadStatus::Running)
                    .project_name("gpui_belge")
                    .selected(self.selected_thread_id.as_ref() == Some(&thread_id))
                    .notified(true)
                    .added(12)
                    .removed(4)
                    .action_slot(IconButton::new("archive-thread-42", IconName::Archive))
                    .on_click(cx.listener({
                        let thread_id = thread_id.clone();
                        move |this, _: &ClickEvent, _window, cx| {
                            this.selected_thread_id = Some(thread_id.clone());
                            cx.notify();
                        }
                    })),
            )
            .child(
                UpdateButton::checking()
                    .tooltip("Checking provider metadata"),
            )
    }
}
```

Dikkat edilecekler:

- Provider secret veya token değerini component'e vermeyin. `ConfiguredApiCard`
  yalnızca "configured" state'ini ve reset action'ını taşır.
- `AiSettingItemStatus::Authenticating` ve `AuthRequired` gibi state'leri servis
  state'inden türetin; kullanıcı tıklamasıyla optimistic olarak değiştirmeyin.
- `ThreadItem` action slot'unda destructive action varsa tooltip ve confirm
  akışı ekleyin.

## Collaboration Özeti

Bu örnekte `Avatar`, `Facepile`, `CollabNotification`, `DiffStat` ve `Chip`
collaboration özet alanında birlikte kullanılır.

Neden birlikte:

- `Avatar`, tek kullanıcı veya çağrı katılımcısını gösterir.
- `Facepile`, aktif collaborator grubunu az yer kaplayarak gösterir.
- `CollabNotification`, davet veya paylaşım aksiyonu için hazır layout verir.
- `DiffStat`, collaboration sırasında değişen satır sayısını özetler.
- `Chip`, branch, role, room veya permission gibi kısa metadata'yı taşır.

Örnek:

```rust
use ui::{
    Avatar, Button, Chip, CollabNotification, DiffStat, Facepile, IconName,
    prelude::*,
};

fn render_collab_summary() -> impl IntoElement {
    v_flex()
        .gap_3()
        .child(
            h_flex()
                .gap_2()
                .items_center()
                .child(
                    Facepile::empty()
                        .child(Avatar::new("https://example.com/a.png").size(px(20.)))
                        .child(Avatar::new("https://example.com/b.png").size(px(20.)))
                        .child(Avatar::new("https://example.com/c.png").size(px(20.))),
                )
                .child(Chip::new("Live").icon(IconName::Circle).label_color(Color::Success))
                .child(DiffStat::new("collab-diff", 24, 7).tooltip("Shared branch diff")),
        )
        .child(
            CollabNotification::new(
                "https://example.com/avatar.png",
                Button::new("accept-share", "Accept"),
                Button::new("dismiss-share", "Dismiss").color(Color::Muted),
            )
            .child("Hakan invited you to join a shared project.")
            .child(Chip::new("read/write").truncate()),
        )
}
```

Dikkat edilecekler:

- `Facepile` içinde avatar boyutlarını aynı tutun; karışık boyut overlap
  hizasını bozar.
- `DiffStat` sadece özet sayı içindir. Dosya bazlı diff gerekiyorsa ayrı liste
  veya diff viewer kullanın.
- `CollabNotification` accept/dismiss davranışını kendi başına yönetmez; iki
  `Button`'ın handler'larını notification lifecycle'a bağlayın.

## Uyum Kontrol Listesi

Bir ekranı kendi uygulamanıza taşırken şu sırayla kontrol edin:

- Her state alanının sahibi belli mi: view, entity, servis store veya settings?
- View state'i değiştiren bütün event handler'lar `cx.listener(...)` üzerinden mi?
- Görsel sonucu olan state değişimlerinden sonra `cx.notify()` var mı?
- Async iş sonucunda view hala yaşıyor mu diye `Entity`/`WeakEntity` update
  sınırları doğru kullanılıyor mu?
- Fire-and-forget task'lar `.detach_and_log_err(cx)` ile loglanıyor mu?
- Menü içeriği render sırasında güncel state'ten mi kuruluyor?
- Icon-only kontrollerde `Tooltip` var mı?
- Shortcut gösterimi gerçek keymap/action çözümünden mi geliyor?
- Büyük listelerde `List` yerine virtualization veya `Table::uniform_list(...)`
  gibi uygun yüzey kullanıldı mı?
- AI/collab domain bileşenlerine sadece render metadata'sı veriliyor mu, gizli
  credential veya servis nesnesi taşınmıyor mu?

## Klavye Erişimi ve Action Akışı Kontrol Listesi

GPUI'de bir ekranın klavye erişimi dört parçayla kurulur: focus, tab order,
key context ve action dispatch. Bu parçalar `Navigable`, `Tooltip`, `KeyBinding`,
`Button*`, `ListItem`, `ContextMenu` ve `AlertModal` gibi bileşenlerin builder
yüzeyinde dağıtık olarak görülür. Bir ekran üretirken aşağıdaki sırayı izleyin:

1. **Focus handle'ı tek noktada üretin.** View struct'ında
   `focus_handle: FocusHandle` alanı tutun ve `Focusable` implement edin.
   Modal/AlertModal kullanıyorsanız aynı handle'ı `.track_focus(&focus_handle)`
   ile bağlayın.
2. **Tab order'ı `tab_index(...)` ile verin.** `Button`, `IconButton`,
   `ButtonLike`, `SwitchField`, `Switch`, `DropdownMenu`, `Disclosure`,
   `Tab`, `ToggleButtonGroup`, `ConfiguredApiCard`, `TreeViewItem` ve `Table`
   builder yüzeyleri `tab_index`'i (genellikle `&mut isize` veya `isize`)
   kabul eder. Aynı form üzerinde tek bir counter geçirin; her builder counter'ı
   kendi kullandığı kadar artırır.
3. **`tab_stop`/`track_focus` ile özel focusable kurun.** `ListItem` gibi
   yüksek seviyeli bileşenler odağı kendileri yönetir; özel `div()` veya
   `h_flex()` üzerinde klavye odağı vermek için `.track_focus(&handle)` ve
   gerektiğinde `.tab_index(...)` ekleyin. `NavigableEntry::focusable(cx)`
   scroll anchor'sız focusable entry üretir.
4. **`Navigable` ile up/down traversal kurun.** Scrollable listede
   `menu::SelectNext` / `menu::SelectPrevious` action'ları `Navigable::new(...)
   .entry(NavigableEntry::new(...))` bağlamasıyla doğru entry'ye scroll edip
   focus eder.
5. **`key_context(...)` ile bağlam zinciri kurun.** `AlertModal::key_context(...)`
   ve `ContextMenu::key_context(...)`, modal veya menü içindeyken keymap'in
   doğru bindings'i kullanmasını sağlar. Custom view'larda `cx.set_global` veya
   element üzerinde `.key_context(KeyContext::new("MyView"))` kullanın.
6. **Action dispatch'i `.on_action::<A>(listener)` ile bağlayın.**
   `AlertModal::on_action`, `Modal` içindeki `menu::Cancel` ve özel
   action'lar bu yolla yakalanır. Custom action tanımları `actions!(...)` veya
   `Action` derive makrosuyla yapılır.
7. **Shortcut'ları action'tan türetin.** Tooltip ve hint'lerde shortcut metni
   yazmak yerine `KeyBinding::for_action(action, cx)` veya
   `Tooltip::for_action_title(title, &action)` kullanın. Bu sayede keymap
   değiştiğinde UI otomatik güncel kalır.
8. **Icon-only kontrollerde tooltip zorunludur.** `IconButton`, `Disclosure`,
   `CopyButton` gibi label'sız kontroller `Tooltip::text(...)` veya
   `Tooltip::for_action_title(...)` ile niyetlerini açıklamalı.
9. **Modal/menu kapanınca focus'u geri verin.** `ModalLayer`,
   `ContextMenu`, `PopoverMenu` ve `right_click_menu` bu davranışı zaten
   uygular; özel popover yazıyorsanız `previous_focus_handle`'ı saklayıp
   dismiss'te `window.focus(&handle, cx)` çağırın.

Hızlı kontrol listesi:

- [ ] View'ın `focus_handle` alanı var ve `Focusable` implement ediyor mu?
- [ ] Tab order için tek bir `&mut isize` veya artan `isize` paylaşıldı mı?
- [ ] Listede ok tuşu traversal'i için `Navigable` bağlandı mı?
- [ ] Modal/menu için `key_context(...)` belirtildi mi?
- [ ] Shortcut tooltip'leri action tabanlı helper'larla mı üretiliyor?
- [ ] Icon-only kontroller `Tooltip` taşıyor mu?
- [ ] Modal/menu kapanışında önceki focus geri veriliyor mu?
- [ ] Sağ tık menüsü ve `on_secondary_mouse_down` davranışları aynı action
  setine bağlanıyor mu (mouse ve klavye akışı tutarlı mı)?

