# 16. Entegre Örnek Sayfaları

Bileşenleri tek tek doğru kullanmak yeterli değildir. Gerçek bir ekranda asıl önemli olan state'in hangi view'da tutulduğu, event'lerin hangi sınırdan geçtiği, asenkron işlerin nasıl izlendiği ve görsel state değişiminden sonra render'ın nasıl yenilendiğidir. Tek başına anlaşılmış bileşenler, ancak bu akış içinde bir araya geldiklerinde anlamlı bir uygulama parçasına dönüşür.

Bu bölümdeki örnekler tam ekran uygulama değildir. Daha çok, kendi domain tiplerinizin, settings servislerinizin ve action tiplerinizin bağlanacağı iskeletlerdir. Kullanılan component API'leri `../zed` çalışma ağacındaki kaynak dosyalara göre düzenlenmiştir.

Ortak uygulama kuralları:

- View'a ait geçici UI state'i view struct'ında tutulur: seçili satır, açık menü, pending async task, hata mesajı ve progress değeri gibi alanlar burada yer alır.
- Paylaşılan veya servis kaynaklı state doğrudan component içinde saklanmaz. Bunun yerine render sırasında component'e label, status, icon, callback ve metadata olarak aktarılır.
- View state'i değiştiren handler'larda `cx.listener(...)` kullanılır. Bu sayede closure view instance'ına güvenli bir şekilde ulaşır.
- Görsel sonucu olan bir state değişiminden sonra `cx.notify()` çağrılır. Özellikle `selected`, `expanded`, `saving`, `error` ve `progress` gibi alanlarda bunu atlamamak gerekir.
- Tamamlanması izlenmesi gereken asenkron işler bir `Task` alanında saklanır. UI'ı değiştirmeyen fire-and-forget bir iş içinse `.detach_and_log_err(cx)` tercih edilir.
- Menü içerikleri `ContextMenu::build(...)` içinde oluşturulur. Menünün açılması ise `PopoverMenu` veya `right_click_menu(...)` gibi taşıyıcı bir bileşene bağlanır.

## Ayarlar Paneli Satırı

Bu örnekte `Headline`, `Label`, `SwitchField`, `Button` ve `Callout` tek bir ayar satırı içinde birlikte kullanılır.

Neden bir arada:

- `Headline`, section başlığını verir.
- `Label`, ayarın adı ve açıklaması için hafif bir metin katmanı sağlar.
- `SwitchField`, boolean bir ayarı erişilebilir bir toggle olarak yönetir.
- `Button`, elle kaydetme veya reset gibi komutları taşır.
- `Callout`, satırın altında bir hata, uyarı veya açıklayıcı bir aksiyon olarak görünür.

State:

- `format_on_save`: switch'in render state'i.
- `saving`: button'ı disable etmek ve progress metni için geçici state.
- `last_error`: yalnızca bir hata varsa `Callout` render edilir.
- `_save_task`: ayar yazımı bitene kadar task'ın drop edilmemesi için saklanır.

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

Dikkat edilecek noktalar:

- `SwitchField::new(...)` callback'i yeni state'i bir `&ToggleState` olarak alır. `ToggleState::selected()` indeterminate state'i `false` olarak kabul eder; üç durumlu bir ayar söz konusu ise bir `match` ile açık şekilde ele alınması gerekir.
- Switch state'i optimistik olarak güncelleniyorsa, hata durumunda eski değerin geri yazılması ve ardından `cx.notify()` çağrılması gerekir.
- Uzun süren yazımlarda `Button` ile `SwitchField` disabled olmalıdır; aksi halde aynı ayar için üst üste task başlatma riski oluşur.

## Toolbar ve Komut Menüsü

Bu örnekte `Button`, `IconButton`, `SplitButton`, `PopoverMenu`, `ContextMenu`, `Tooltip` ve `KeybindingHint` aynı toolbar davranışını birlikte tamamlar.

Neden bir arada:

- `Button` veya `ButtonLike`, birincil komutu taşır.
- `IconButton`, kompakt komutlar ve menü tetikleyicileri için uygundur.
- `SplitButton`, birincil eylem ile varyant menüsünü tek bir kontrol gibi gösterir.
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

`KeybindingHint` için pratik kurallar:

- Shortcut sabit bir string olarak yazılmaz. Mümkün olduğunda uygulamadaki action veya keymap çözümünden bir `ui::KeyBinding` üretilir.
- Hint her toolbar'da görünmek zorunda değildir. Asıl değerli olduğu yerler komut palette, empty state veya onboarding gibi bağlamlardır.
- Icon-only bir buton varsa `Tooltip` zorunlu kabul edilir; label'lı bir buton üzerinde tooltip ise yalnızca ek bir bağlam sağlıyorsa kullanılır.

## Proje Listesi

Bu örnekte `List`, `ListItem`, `TreeViewItem`, `Disclosure`, `IndentGuides` ve `CountBadge`, bir proje gezgini benzeri görünümde birlikte çalışır.

Neden bir arada:

- `List`, liste container'ı ve empty state davranışı için temel yapıdır.
- `ListItem`, satır slot'larını, selected state'i ve secondary click'i destekler.
- `TreeViewItem`, dosya ağacı gibi expand veya collapse ile focus davranışı olan satırlarda kullanılır.
- `Disclosure`, özel satır layout'larında aç/kapat ikonunu ayrı bir parça olarak yerleştirmeye yarar.
- `IndentGuides`, virtualization kullanan ağaç listelerinde girinti çizgilerini hesaplama ve render sürecine bağlar.
- `CountBadge`, bir klasör veya filtre sonucundaki sayıları kompakt biçimde gösterir.

State:

- `expanded_project_ids`: hangi root veya klasörlerin açık olduğu.
- `selected_path`: tek seçili proje veya dosya yolu.
- `pending_context_menu_path`: sağ tık menüsü açılırken kullanılan yol.
- Büyük listelerde scroll ve virtualization state'i bileşenlerin dışında tutulur.

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

`IndentGuides` notları:

- `IndentGuides`, düz bir `List` içine otomatik olarak çizgi eklemez. `uniform_list` veya sticky item decoration bağlamında `indent_guides(indent_size, colors)` çağrısıyla kullanılır.
- Girinti hesabı için `with_compute_indents_fn(...)`, özel bir çizim için ise `with_render_fn(...)` bağlanır.
- Girinti state'i satır verisinden türetilmelidir. Her satırda ayrı ayrı çizgi elemanları üretmek, büyük ağaçlarda gereksiz bir maliyet yaratır.

## Veri Tablosu

Bu örnekte `Table`, `TableInteractionState`, `RedistributableColumnsState`, `Indicator` ve `ProgressBar` birlikte kullanılır.

Neden bir arada:

- `Table`, satır ve sütun düzenini, header davranışını sağlar.
- `TableInteractionState`, scroll ve focus state'ini view dışında tutulabilir hâle getirir.
- `RedistributableColumnsState`, sabit bir toplam genişlik içinde kullanıcıya sütun yeniden dağıtımı seçeneği verir.
- `Indicator`, satırdaki kısa status bilgisini gösterir.
- `ProgressBar`, tabloyu besleyen async işlerin ilerlemesini gösterir.

State:

- `interaction_state: Entity<TableInteractionState>`.
- `columns_state: Entity<RedistributableColumnsState>`.
- `rows: Vec<RowVm>`.
- `sync_progress: Option<(f32, f32)>`.

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

Dikkat edilecek noktalar:

- `Table::row(...)` küçük ve sabit listeler için yeterlidir. Büyük bir veri setinde `uniform_list(...)` veya `variable_row_height_list(...)` kullanılır.
- `RedistributableColumnsState::new(cols, widths, resize_behavior)` içinde `cols`, width sayısı ve resize behavior sayısı birbirine eşit olmalıdır.
- Progress değeri değiştiğinde `sync_progress` güncellenir ve hemen ardından `cx.notify()` çağrılır.

## Bildirim Merkezi

Bu örnekte bir notification yaşam döngüsü ile birlikte `NotificationFrame`, `AnnouncementToast`, `Banner`, `AlertModal` ve `Button` birlikte düşünülür.

Neden bir arada:

- `Banner`, ekran veya panel üstündeki non-blocking bir duyuruyu gösterir.
- `NotificationFrame`, workspace notification stack'inde başlığı, içeriği, close ve suppress davranışını birlikte çerçeveler.
- `AnnouncementToast`, ürün duyurusu veya yeni özellik tanıtımı için hazır bir layout sağlar.
- `AlertModal`, kısa ve blocking bir karar anında devreye girer.
- `Button`, banner, toast ve modal action yüzeylerinin tamamlayıcısıdır.

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

- Workspace notification stack'e girecek bir view, `workspace::notifications::Notification` trait sınırını karşılamalıdır: `Render`, `Focusable`, `EventEmitter<DismissEvent>` ve `EventEmitter<SuppressEvent>` birlikte beklenir.
- Dismiss veya suppress state'i bileşen içinde unutulmaz. Kullanıcı tercihi kalıcı olarak saklanacaksa, settings veya bir KV store tarafında tutulması gerekir.
- Bloklayıcı bir karar gerekmiyorsa, `AlertModal` yerine bir `Banner` veya `NotificationFrame` çok daha uygun bir seçim olur.

## AI Sağlayıcı Kartları

Bu örnekte `ConfiguredApiCard`, `AiSettingItem`, `AgentSetupButton`, `ThreadItem` ve `UpdateButton` aynı AI ayar alanında birlikte kullanılır.

Neden bir arada:

- `AiSettingItem`, bir agent veya provider satırının status ve kaynak bilgisini taşır.
- `ConfiguredApiCard`, credential var/yok state'ini güvenli ve kısa bir kartla gösterir.
- `AgentSetupButton`, bir provider veya agent kurulumu için action satırı sağlar.
- `ThreadItem`, son agent oturumlarını listelemek için domain'e özel bir satır sunar.
- `UpdateButton`, AI alanının dışında bir update veya collab özel durumu yaşandığında da aynı kompakt status/action modelini gösterir.

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

Dikkat edilecek noktalar:

- Provider secret veya token değerleri bir component'e verilmez. `ConfiguredApiCard` yalnızca "configured" state'ini ve reset action'ını taşıdığı için bu sınır net şekilde korunur.
- `AiSettingItemStatus::Authenticating` ve `AuthRequired` gibi state'ler servis state'inden türetilmelidir; kullanıcı tıklamasıyla optimistik olarak değiştirilmesi yanıltıcı olabilir.
- `ThreadItem` action slot'unda destructive bir action varsa, tooltip ve onay akışının eklenmesi gerekir.

## Collaboration Özeti

Bu örnekte `Avatar`, `Facepile`, `CollabNotification`, `DiffStat` ve `Chip` bir collaboration özet alanında birlikte kullanılır.

Neden bir arada:

- `Avatar`, tek bir kullanıcıyı veya çağrı katılımcısını gösterir.
- `Facepile`, aktif collaborator grubunu az yer kaplayarak bir arada sunar.
- `CollabNotification`, bir davet veya paylaşım aksiyonu için hazır bir layout verir.
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

Dikkat edilecek noktalar:

- `Facepile` içinde avatar boyutlarının aynı tutulması beklenir; karışık boyutlar overlap hizasını bozar.
- `DiffStat` yalnızca özet bir sayı için tasarlanmıştır. Dosya bazlı bir diff gerekiyorsa ayrı bir liste veya diff viewer kullanılır.
- `CollabNotification` accept ve dismiss davranışını kendi içinde yönetmez; iki `Button`'ın handler'larının notification lifecycle'ına bağlanması gerekir.

## Uyum Kontrol Listesi

Bir ekran kendi uygulamana taşınırken aşağıdaki sıranın izlenmesi işe yarar:

- Her state alanının sahibi belirli mi: view, entity, servis store veya settings?
- View state'i değiştiren bütün event handler'lar `cx.listener(...)` üzerinden mi geçiyor?
- Görsel sonucu olan state değişimlerinden sonra `cx.notify()` çağrısı var mı?
- Async iş sonucunda view hâlâ yaşıyor mu kontrolü için `Entity` veya `WeakEntity` update sınırları doğru kullanılıyor mu?
- Fire-and-forget task'lar `.detach_and_log_err(cx)` ile loglanıyor mu?
- Menü içeriği render sırasında güncel state'ten mi kuruluyor?
- Icon-only kontrollerde bir `Tooltip` var mı?
- Shortcut gösterimi gerçek keymap veya action çözümünden mi geliyor?
- Büyük listelerde `List` yerine bir virtualization yapısı veya `Table::uniform_list(...)` gibi uygun bir yüzey kullanıldı mı?
- AI ve collab domain bileşenlerine yalnızca render metadata'sı mı veriliyor, yoksa gizli credential veya servis nesnesi mi taşınıyor?

## Klavye Erişimi ve Action Akışı Kontrol Listesi

GPUI'de bir ekranın klavye erişimi dört parçayla kurulur: focus, tab order, key context ve action dispatch. Bu dört parça `Navigable`, `Tooltip`, `KeyBinding`, `Button*`, `ListItem`, `ContextMenu` ve `AlertModal` gibi bileşenlerin builder yüzeylerinde dağıtık olarak yer alır. Bir ekran üretirken aşağıdaki sıranın izlenmesi tutarlı bir sonuç verir:

1. **Focus handle'ı tek bir noktada üretin.** View struct'ında bir `focus_handle: FocusHandle` alanı tutulur ve view `Focusable` implement eder. Modal veya AlertModal kullanılıyorsa aynı handle `.track_focus(&focus_handle)` çağrısıyla bağlanır.
2. **Tab order'ı `tab_index(...)` ile verin.** `Button`, `IconButton`, `ButtonLike`, `SwitchField`, `Switch`, `DropdownMenu`, `Disclosure`, `Tab`, `ToggleButtonGroup`, `ConfiguredApiCard`, `TreeViewItem` ve `Table` builder yüzeyleri `tab_index`'i (genellikle `&mut isize` veya `isize`) kabul eder. Aynı form üzerinde tek bir counter geçirilir; her builder counter'ı kendi kullandığı kadar artırır.
3. **`tab_stop` ve `track_focus` ile özel focusable kurun.** `ListItem` gibi yüksek seviyeli bileşenler odağı kendileri yönetir; özel bir `div()` veya `h_flex()` üzerinde klavye odağı vermek için `.track_focus(&handle)` ve gerektiğinde `.tab_index(...)` eklenir. `NavigableEntry::focusable(cx)`, scroll anchor olmadan focusable bir entry üretir.
4. **`Navigable` ile up/down traversal kurun.** Scrollable bir listede `menu::SelectNext` ve `menu::SelectPrevious` action'ları, `Navigable::new(...).entry(NavigableEntry::new(...))` bağlamasıyla doğru entry'ye scroll yapıp focus verir.
5. **`key_context(...)` ile bağlam zinciri kurun.** `AlertModal::key_context(...)` ve `ContextMenu::key_context(...)`, modal veya menü içindeyken keymap'in doğru binding'leri kullanmasını sağlar. Custom view'larda `cx.set_global` veya bir element üzerinde `.key_context(KeyContext::new("MyView"))` çağrısı kullanılır.
6. **Action dispatch'i `.on_action::<A>(listener)` ile bağlayın.** `AlertModal::on_action`, `Modal` içindeki `menu::Cancel` ve özel action'lar bu yolla yakalanır. Custom action tanımları `actions!(...)` ile veya `Action` derive makrosuyla yapılır.
7. **Shortcut'ları action'tan türetin.** Tooltip ve hint'lerde shortcut metni elle yazmak yerine `KeyBinding::for_action(action, cx)` veya `Tooltip::for_action_title(title, &action)` kullanılır. Bu sayede keymap değiştiğinde UI otomatik olarak güncel kalır.
8. **Icon-only kontrollerde tooltip zorunludur.** `IconButton`, `Disclosure`, `CopyButton` gibi label'sız kontroller `Tooltip::text(...)` veya `Tooltip::for_action_title(...)` ile niyetlerini açıklamalıdır.
9. **Modal veya menü kapandığında focus'u geri verin.** `ModalLayer`, `ContextMenu`, `PopoverMenu` ve `right_click_menu` bu davranışı zaten uygular. Özel bir popover yazılıyorsa, önceki focus handle saklanır ve dismiss anında `window.focus(&handle, cx)` çağrısıyla geri verilir.

Hızlı kontrol listesi:

- [ ] View'ın bir `focus_handle` alanı var ve `Focusable` implement ediyor mu?
- [ ] Tab order için tek bir `&mut isize` veya artan bir `isize` paylaşıldı mı?
- [ ] Listede ok tuşu traversal'i için `Navigable` bağlandı mı?
- [ ] Modal veya menü için `key_context(...)` belirtildi mi?
- [ ] Shortcut tooltip'leri action tabanlı helper'larla mı üretiliyor?
- [ ] Icon-only kontroller `Tooltip` taşıyor mu?
- [ ] Modal ya da menü kapanışında önceki focus geri veriliyor mu?
- [ ] Sağ tık menüsü ve `on_secondary_mouse_down` davranışları aynı action setine bağlanıyor mu (yani mouse ve klavye akışı birbiriyle tutarlı mı)?
