# 15. AI ve Collab Özel Alanı

Bu bölümdeki bileşenler Zed'in AI, agent, provider, collaboration ve update
akışlarına sıkı bağlıdır. Genel uygulamalarda doğrudan kullanmadan önce
domain modelinizin bu API'lere gerçekten uyup uymadığı kontrol edilmelidir.

Genel kural:

- Domain'e bağlı bileşenlerde gerçek servis state'i component içine
  taşınmaz; component'e yalnızca render için gereken label, status, icon,
  callback ve metadata verilir.
- AI/Collab bileşenleri başka panellerde kompoze edilirken kendi domain
  state'leri view'da tutulmalı; component yalnızca görsel hizalama yapar.

## AiSettingItem

Kaynak:

- Tanım: `../zed/crates/ui/src/components/ai/ai_setting_item.rs`
- Export: `ui::AiSettingItem`, `ui::AiSettingItemStatus`,
  `ui::AiSettingItemSource`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for AiSettingItem`

Ne zaman kullanılır:

- MCP server, agent provider veya AI integration ayar satırı göstermek için.
- Status indicator, source icon, detail label, action button ve detay satırını
  tek compact row'da toplamak için.

Temel API:

- `AiSettingItem::new(id, label, status, source)`
- `.icon(element)`
- `.detail_label(text)`
- `.action(element)`
- `.details(element)`
- `AiSettingItemStatus`: `Stopped`, `Starting`, `Running`, `Error`,
  `AuthRequired`, `Authenticating`
- `AiSettingItemSource`: `Extension`, `Custom`, `Registry`

Davranış:

- Icon verilmezse label'ın ilk harfinden küçük avatar üretir.
- `Starting` ve `Authenticating` durumlarında icon opacity pulse animasyonu alır.
- Status tooltip'i ve source tooltip'i otomatik üretilir.
- Status indicator, `IconDecorationKind::Dot` ile icon köşesine yerleşir.

Örnek:

```rust
use ui::{
    AiSettingItem, AiSettingItemSource, AiSettingItemStatus, IconButton, IconName, IconSize,
    prelude::*,
};

fn render_mcp_setting_row() -> impl IntoElement {
    AiSettingItem::new(
        "postgres-mcp",
        "Postgres",
        AiSettingItemStatus::Running,
        AiSettingItemSource::Extension,
    )
    .detail_label("3 tools")
    .action(
        IconButton::new("postgres-settings", IconName::Settings)
            .icon_size(IconSize::Small)
            .icon_color(Color::Muted),
    )
}
```

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/agent_configuration.rs`: MCP server ve agent
  configuration listeleri.
- `../zed/crates/ui/src/components/ai/ai_setting_item.rs`: running, stopped,
  starting ve error preview örnekleri.

Dikkat edilecekler:

- Source enum'u gerçek kurulum kaynağıyla eşleşmelidir; tooltip metni bundan
  türetilir.
- `.details(...)` uzun hata metinleri için kullanılabilir ama ana satırı
  kalabalıklaştırmayın.

## AgentSetupButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/ai/agent_setup_button.rs`
- Export: `ui::AgentSetupButton`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for AgentSetupButton`, ancak preview `None` döndürür.

Ne zaman kullanılır:

- Onboarding veya provider setup ekranında agent seçeneğini card-button gibi
  göstermek için.
- Üstte icon/name, altta state bilgisi olan küçük seçim yüzeyi gerektiğinde.

Temel API:

- `AgentSetupButton::new(id)`
- `.icon(Icon)`
- `.name(text)`
- `.state(element)`
- `.disabled(bool)`
- `.on_click(handler)`

Davranış:

- Disabled değil ve on_click varsa hover'da pointer cursor, hover background ve
  border rengi uygulanır.
- `state(...)` verilirse alt bölüm border-top ve subtle background ile ayrılır.

Örnek:

```rust
use ui::{AgentSetupButton, Icon, IconName, IconSize, prelude::*};

fn render_agent_setup_button() -> impl IntoElement {
    AgentSetupButton::new("setup-zed-agent")
        .icon(Icon::new(IconName::ZedAgent).size(IconSize::Small))
        .name("Zed Agent")
        .state(Label::new("Ready").size(LabelSize::Small).color(Color::Success))
        .on_click(|_, _window, _cx| {})
}
```

Zed içinden kullanım:

- `../zed/crates/onboarding/src/basics_page.rs`: onboarding agent setup
  seçenekleri.

Dikkat edilecekler:

- Empty card üretmemek için en az icon/name veya state verin.
- Disabled state click handler'ı render etmez.

## ThreadItem

Kaynak:

- Tanım: `../zed/crates/ui/src/components/ai/thread_item.rs`
- Export: `ui::ThreadItem`, `ui::AgentThreadStatus`,
  `ui::ThreadItemWorktreeInfo`, `ui::WorktreeKind`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ThreadItem`

Ne zaman kullanılır:

- Agent thread listesinde title, status, timestamp, worktree metadata ve diff
  özetini tek satırda göstermek için.
- Hover action slot'u ve selected/focused görsel state'i gereken thread listeleri
  için.

Temel API:

- `ThreadItem::new(id, title)`
- `.timestamp(text)`
- `.icon(IconName)`, `.icon_color(Color)`, `.icon_visible(bool)`
- `.custom_icon_from_external_svg(svg)`
- `.notified(bool)`
- `.status(AgentThreadStatus)`
- `.title_generating(bool)`, `.title_label_color(Color)`,
  `.highlight_positions(Vec<usize>)`
- `.selected(bool)`, `.focused(bool)`, `.hovered(bool)`, `.rounded(bool)`
- `.added(usize)`, `.removed(usize)`
- `.project_paths(Arc<[PathBuf]>)`, `.project_name(text)`
- `.worktrees(Vec<ThreadItemWorktreeInfo>)`
- `.is_remote(bool)`, `.archived(bool)`
- `.on_click(handler)`, `.on_hover(handler)`, `.action_slot(element)`,
  `.base_bg(Hsla)`
- `AgentThreadStatus`: `Completed`, `Running`, `WaitingForConfirmation`,
  `Error`. `Completed` varsayılan durumdur ve özel status ikon/animasyon
  göstermez.

Davranış:

- `Running` status `LoadCircle` icon'u ve rotate animation gösterir.
- `WaitingForConfirmation` warning icon ve tooltip üretir.
- `Error` close icon ve tooltip üretir.
- `notified(true)` accent circle kullanır.
- Metadata satırında linked worktree bilgisi, project name/path, diff stat ve
  timestamp sırayla render edilir.
- `action_slot(...)` yalnızca `.hovered(true)` olduğunda görünür.

Örnek:

```rust
use ui::{
    AgentThreadStatus, IconButton, IconName, IconSize, ThreadItem,
    ThreadItemWorktreeInfo, WorktreeKind, prelude::*,
};

fn render_agent_thread() -> impl IntoElement {
    ThreadItem::new("thread-parser", "Fix parser error recovery")
        .icon(IconName::AiClaude)
        .status(AgentThreadStatus::Running)
        .timestamp("12m")
        .worktrees(vec![ThreadItemWorktreeInfo {
            worktree_name: Some("parser-fix".into()),
            branch_name: Some("fix/parser-recovery".into()),
            full_path: "/worktrees/parser-fix".into(),
            highlight_positions: Vec::new(),
            kind: WorktreeKind::Linked,
        }])
        .added(42)
        .removed(7)
        .hovered(true)
        .action_slot(
            IconButton::new("delete-thread", IconName::Trash)
                .icon_size(IconSize::Small)
                .icon_color(Color::Muted),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/sidebar/src/thread_switcher.rs`: thread switcher listesi.
- `../zed/crates/sidebar/src/sidebar.rs`: sidebar thread entries.
- `../zed/crates/zed/src/visual_test_runner.rs`: geniş thread item varyantları.

Dikkat edilecekler:

- `ThreadItem` yoğun bir domain component'idir. Genel liste satırı için
  `ListItem` veya özel `h_flex()` kompozisyonu daha temiz olabilir.
- Worktree metadata'sında yalnızca `WorktreeKind::Linked` olan ve worktree/branch
  bilgisi bulunan girdiler gösterilir.
- Hover state'i component içinde ölçülmez; parent `.hovered(...)` değerini
  yönetmelidir.

## ConfiguredApiCard

Kaynak:

- Tanım: `../zed/crates/ui/src/components/ai/configured_api_card.rs`
- Export: `ui::ConfiguredApiCard`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ConfiguredApiCard`

Ne zaman kullanılır:

- API key veya provider credential yapılandırılmış durumunu göstermek için.
- Reset/remove key aksiyonunu aynı satırda sunmak için.

Temel API:

- `ConfiguredApiCard::new(label)`
- `.button_label(text)`
- `.tooltip_label(text)`
- `.disabled(bool)`
- `.button_tab_index(isize)`
- `.on_click(handler)`

Davranış:

- Sol tarafta success `Check` icon ve label render edilir.
- Button label verilmezse `"Reset Key"`.
- Button start icon'u `Undo`.
- `disabled(true)` button'ı disabled yapar ve click handler bağlanmaz.

Örnek:

```rust
use ui::{ConfiguredApiCard, prelude::*};

fn render_configured_key_card() -> impl IntoElement {
    ConfiguredApiCard::new("OpenAI API key configured")
        .button_label("Reset Key")
        .tooltip_label("Click to replace the current key")
        .on_click(|_, _window, _cx| {})
}
```

Zed içinden kullanım:

- `../zed/crates/language_models/src/provider/open_ai.rs`: provider key state.
- `../zed/crates/language_models/src/provider/anthropic.rs`,
  `deepseek.rs`, `google.rs`, `open_router.rs`: benzer provider kartları.
- `../zed/crates/settings_ui/src/pages/edit_prediction_provider_setup.rs`.

Dikkat edilecekler:

- Card yalnızca configured durumunu temsil eder; credential giriş formu değildir.
- `button_tab_index(...)`, provider setup ekranında keyboard order ayarlamak için
  kullanılır.

## ParallelAgentsIllustration

Kaynak:

- Tanım: `../zed/crates/ui/src/components/ai/parallel_agents_illustration.rs`
- Export: `ui::ParallelAgentsIllustration`
- Prelude: Hayır, `use ui::ParallelAgentsIllustration;` ekleyin.
- Preview: Doğrudan `impl Component for ParallelAgentsIllustration` yok; onboarding
  ve marketing yüzeylerinde başka component'lerin preview içinde kullanılır.

Ne zaman kullanılır:

- Onboarding, "what's new" veya parallel agent özelliklerini tanıtan boş durum
  ekranlarında. Agent listesi, thread görünümü ve proje paneli skeleton'ından
  oluşan miniatür bir Zed workspace çizimi gerektiğinde.
- Henüz veri olmayan ama özelliğin görsel anlamını anlatmak gereken alanlarda
  dekoratif bir illustration olarak.

Ne zaman kullanılmaz:

- Gerçek agent thread listesi için: `ThreadItem` + `List` kompozisyonu kullanın.
- Etkileşim gerektiren agent provider seçimi için: `AgentSetupButton` veya
  `AiSettingItem` daha uygundur.
- Veri görünüm component'i olarak: bu yapı görsel pulse animasyonlu skeleton
  içerir, click handler veya state yüzeyi sunmaz.

Temel API:

- Constructor: `ParallelAgentsIllustration::new()` — argümansız değer üretir.
- `RenderOnce` implement eder; sonradan style builder zinciri yoktur.
- Konteyner içinde yerleştirilirken yükseklik 180px civarında sabittir;
  genişliği parent layout belirler.

Davranış:

- Üç kolonlu bir grid çizer: solda agent listesi, ortada thread görünümü, sağda
  proje paneli skeleton'ı.
- `gpui::Animation` ve `pulsating_between(0.1, 0.8)` ile thread görünümündeki
  loading bar'lara süreklilik animasyonu uygular.
- Renkler `cx.theme().colors().element_selected`, `panel_background`,
  `editor_background` ve `text_muted.opacity(0.05)` token'larından gelir; tema
  değişikliklerinde otomatik uyum sağlar.
- İlk agent satırı `selected` durumdadır ve `DiffStat`, worktree etiketi,
  zaman metni gibi alt component'lerle birlikte render edilir.

Örnek:

```rust
use ui::prelude::*;
use ui::ParallelAgentsIllustration;

fn render_parallel_agents_onboarding() -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(Headline::new("Run agents in parallel").size(HeadlineSize::Large))
        .child(
            Label::new("Spin up multiple agents to investigate, refactor and review side by side.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
        .child(ParallelAgentsIllustration::new())
}
```

Zed içinden kullanım:

- `../zed/crates/onboarding/src/onboarding.rs` ve ilişkili sayfalar: parallel
  agent özelliğinin tanıtım alanlarında dekoratif illustration olarak.
- `../zed/crates/ui/src/components/ai/parallel_agents_illustration.rs`: bileşenin
  tek tanım dosyası; alt yapı taşları (`DiffStat`, `Divider`, `Label`, `Icon`)
  doğrudan ui crate'inden tüketilir.

Dikkat edilecekler:

- Bu bileşen yalnızca görsel bir illustration'dır; gerçek thread, worktree veya
  agent verisi göstermek için kullanılmamalıdır.
- Sürekli pulse animasyonu içerdiği için arka planda görünmediği halde
  render maliyetini paylaşır; geniş onboarding sayfalarında scroll dışında
  kaldığında parent'ı `.when(visible, ...)` veya `IntoElement` koşullu render
  ile kontrol edin.
- `ParallelAgentsIllustration::new()` parametresizdir; renk veya boyut özelleştirmesi
  bileşenin kendi içine bağımlıdır. Farklı görsel gerekiyorsa kaynak dosyayı
  referans alarak özel bir illustration component'i yazmak daha uygundur.

## CollabNotification

Kaynak:

- Tanım: `../zed/crates/ui/src/components/collab/collab_notification.rs`
- Export: `ui::CollabNotification`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for CollabNotification`

Ne zaman kullanılır:

- Incoming call, project share, contact request veya channel invite gibi iki
  aksiyonlu collaboration notification view'ı için.
- Avatar + metin + accept/dismiss button düzenini standart tutmak için.

Temel API:

- `CollabNotification::new(avatar_uri, accept_button, dismiss_button)`
- ParentElement: `.child(...)`, `.children(...)`

Davranış:

- Avatar `px(40.)` boyutunda render edilir.
- Sağ tarafta iki button dikey yerleşir.
- İçerik `SmallVec<[AnyElement; 2]>` ile tutulur ve `v_flex().truncate()` içinde
  render edilir.

Örnek:

```rust
use ui::{Button, CollabNotification, prelude::*};

fn render_project_share_notification() -> impl IntoElement {
    CollabNotification::new(
        "https://avatars.githubusercontent.com/u/67129314?v=4",
        Button::new("open-shared-project", "Open"),
        Button::new("dismiss-shared-project", "Dismiss"),
    )
    .child(Label::new("Ada shared a project with you"))
    .child(Label::new("zed").color(Color::Muted))
}
```

Zed içinden kullanım:

- `../zed/crates/collab_ui/src/notifications/project_shared_notification.rs`
- `../zed/crates/collab_ui/src/notifications/incoming_call_notification.rs`
- `../zed/crates/collab_ui/src/collab_panel.rs`

Dikkat edilecekler:

- Accept ve dismiss button'larının callback'leri parent notification view'ında
  bağlanmalıdır.
- Uzun kullanıcı veya proje adlarında child label'lara truncate davranışı ekleyin.

## UpdateButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/collab/update_button.rs`
- Export: `ui::UpdateButton`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for UpdateButton`

Ne zaman kullanılır:

- Title bar içinde auto-update durumunu ve update aksiyonunu göstermek için.
- Checking/downloading/installing/updated/error state'leri için hazır görünüm
  gerektiğinde.

Temel API:

- `UpdateButton::new(icon, message)`
- `.icon_animate(bool)`
- `.icon_color(Option<Color>)`
- `.tooltip(text)`
- `.with_dismiss()`
- `.disabled(bool)`
- `.on_click(handler)`
- `.on_dismiss(handler)`
- Convenience constructors:
  `UpdateButton::checking()`, `downloading(version)`, `installing(version)`,
  `updated(version)`, `errored(error)`

Davranış:

- `icon_animate(true)`, icon'a rotate animation uygular.
- `.with_dismiss()` sağ tarafta dismiss icon button gösterir.
- `.disabled(true)`, ana `ButtonLike` alanını disable eder; checking,
  downloading ve installing convenience constructor'ları artık bu durumu
  kendileri uygular.
- Main area `ButtonLike::new("update-button")` ile render edilir.
- Tooltip verilirse main button area'ya bağlanır.
- `checking()` ve `installing(...)` dönen `IconName::LoadCircle` kullanır;
  animation süresi 2 saniyedir. `downloading(...)` `IconName::Download`,
  `errored(...)` ise `IconName::Warning` ile çizilir.
- Convenience constructor varsayılan mesajları: `checking()` "Checking for
  Zed Updates…", `downloading(...)` "Downloading Zed Update…",
  `installing(...)` "Installing Zed Update…", `errored(...)` "Failed to
  Update" yazısını kullanır; özel metin gerekiyorsa `UpdateButton::new(...)`
  ile açık state kurulmalıdır.
- Kenarlık rengi disabled state'e göre değişir: aktif konumda
  `colors().text.opacity(0.15)` ile yumuşatılmış bir border, disabled
  konumda ise standart `colors().border` kullanılır. Bu nedenle aktif
  `updated(...)` ve `errored(...)` durumları, disabled olan checking /
  downloading / installing durumlarından daha belirgin bir kenarlık
  taşır.
- Title bar'daki `UpdateVersion` tooltip'i artık `Update to Version: ...`
  biçimindedir; SHA tabanlı version'da kısaltılmış SHA yerine tam SHA gösterilir.

Örnek:

```rust
use ui::{UpdateButton, prelude::*};

fn render_ready_update_button() -> impl IntoElement {
    UpdateButton::updated("1.99.0")
        .on_click(|_, _window, _cx| {})
        .on_dismiss(|_, _window, _cx| {})
}
```

Zed içinden kullanım:

- `../zed/crates/auto_update_ui/src/auto_update_ui.rs`: auto-update title bar ve
  notification akışları.

Dikkat edilecekler:

- Bu component title bar bağlamına göre tasarlanmıştır; genel sayfa CTA'sı olarak
  kullanmayın.
- `checking()`, `downloading(...)` ve `installing(...)` disabled geldiği için
  bu durumlarda click handler bağlamayın; kullanıcı aksiyonu gerekiyorsa
  `updated(...)`, `errored(...)` veya `UpdateButton::new(...)` ile açık state
  kurun.
- `updated(...)` ve `errored(...)` dismiss gösterir; dismiss callback'i
  bağlanmazsa button görünür ama state temizlenmez.

## Diğer ve AI/Collab Kompozisyon Örnekleri

Collab özet satırı:

```rust
use ui::{Avatar, Chip, DiffStat, Facepile, prelude::*};

fn render_collab_summary() -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(
            Facepile::empty()
                .child(Avatar::new("https://avatars.githubusercontent.com/u/326587?s=60"))
                .child(Avatar::new("https://avatars.githubusercontent.com/u/2280405?s=60")),
        )
        .child(
            v_flex()
                .min_w_0()
                .child(Label::new("Reviewing changes").truncate())
                .child(Chip::new("2 reviewers").label_color(Color::Muted)),
        )
        .child(DiffStat::new("review-summary-diff", 12, 3))
}
```

Agent settings satırı:

```rust
use ui::{
    AiSettingItem, AiSettingItemSource, AiSettingItemStatus, ConfiguredApiCard,
    IconButton, IconName, IconSize, prelude::*,
};

fn render_agent_settings_summary() -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(
            AiSettingItem::new(
                "claude-agent",
                "Claude Agent",
                AiSettingItemStatus::Running,
                AiSettingItemSource::Extension,
            )
            .detail_label("Ready")
            .action(
                IconButton::new("agent-settings", IconName::Settings)
                    .icon_size(IconSize::Small)
                    .icon_color(Color::Muted),
            ),
        )
        .child(ConfiguredApiCard::new("Anthropic API key configured"))
}
```

Karar rehberi:

- Kişi görseli: `Avatar`; kişi grubu: `Facepile`.
- Compact metadata etiketi: `Chip`.
- Eklenen/silinen satır özeti: `DiffStat`.
- Açılır/kapanır icon button: `Disclosure`.
- Sağ kenar fade overlay: `GradientFade`.
- Bundled SVG: `Vector`; raster/dış görsel: GPUI `img(...)`.
- Shortcut render: `KeyBinding`; açıklamalı shortcut hint: `KeybindingHint`.
- Focus/scroll traversal: `Navigable`.
- AI ayar satırı: `AiSettingItem`; provider credential state'i:
  `ConfiguredApiCard`; agent thread listesi: `ThreadItem`.
- Parallel agent özelliği için onboarding/illustration:
  `ParallelAgentsIllustration` (yalnızca dekoratif).
- Collaboration toast layout'u: `CollabNotification`; update title bar state'i:
  `UpdateButton`.

