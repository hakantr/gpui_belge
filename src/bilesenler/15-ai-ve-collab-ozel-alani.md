# 15. AI ve Collab Özel Alanı

Bu bölümdeki bileşenler Zed'in AI, agent, provider, collaboration ve update akışlarına yakından bağlıdır. Bu yüzden genel bir uygulamada kullanılmadan önce alan modelinin bu API'lere gerçekten uyup uymadığı kontrol edilmelidir. Aksi halde bileşen görsel olarak hazır görünür, fakat modelin ihtiyaçlarıyla çelişebilir.

Bu ailede iki genel kural vardır:

- Alana bağlı bileşenlerde gerçek servis durumu bileşenin içine taşınmaz. Bileşene yalnızca render için gereken etiket, durum, ikon, callback ve üstveri verirsin.
- AI ve Collab bileşenleri başka panellerde kompoze edilirken alan durumu view'da tutulur. Bu bileşenler yalnızca o durumu görsel olarak düzenler.

![AI ve Collab Domain Haritası](assets/ai-collab-domain-haritasi.svg)

## AiSettingItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::AiSettingItem`, `ui::AiSettingItemStatus`, `ui::AiSettingItemSource`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for AiSettingItem`.

Ne zaman kullanırsın:

- MCP server, agent sağlayıcısı veya AI entegrasyonu için ayar satırı göstermek gerektiğinde.
- Durum göstergesi, kaynak ikonu, detay etiketi, eylem butonu ve detay satırını tek bir kompakt row'da toplamak için.

Temel API:

- `AiSettingItem::new(id, label, status, source)`.
- `.icon(element)`.
- `.detail_label(text)`.
- `.action(element)`.
- `.details(element)`.
- `AiSettingItemStatus`: `Stopped`, `Starting`, `Running`, `Error`, `AuthRequired`, `ClientSecretRequired`, `Authenticating`.
- `AiSettingItemSource`: `Extension`, `Custom`, `Registry`.

AI ayar satırı enum'ları:

| API | Rol |
| :-- | :-- |
| `AiSettingItemStatus` | Provider veya MCP satırının durumunu taşır: `Stopped`, `Starting`, `Running`, `Error`, `AuthRequired`, `ClientSecretRequired`, `Authenticating`. |
| `AiSettingItemSource` | Ayarın nereden geldiğini belirtir: `Extension`, `Custom` veya `Registry`. |

Davranış:

- Bir icon verilmediğinde, etiketin ilk harfinden küçük bir avatar otomatik olarak üretilir.
- `Starting` ve `Authenticating` durumlarında ikon, opacity üzerinden pulse animasyonu alır.
- Status ve source için tooltip otomatik üretilir.
- Durum göstergesi, `IconDecorationKind::Dot` ile ikonun köşesine yerleşir.

Örnek:

```rust
use ui::{
    AiSettingItem, AiSettingItemSource, AiSettingItemStatus, IconButton, IconName, IconSize,
    prelude::*,
};

fn mcp_ayar_satiri_render() -> impl IntoElement {
    AiSettingItem::new(
        "postgres-mcp",
        "Postgres",
        AiSettingItemStatus::Running,
        AiSettingItemSource::Extension,
    )
    .detail_label("3 araç")
    .action(
        IconButton::new("postgres-ayarlari", IconName::Settings)
            .icon_size(IconSize::Small)
            .icon_color(Color::Muted),
    )
}
```

Zed içinden kullanım örnekleri:

- `agent_ui` crate'i: MCP server ve agent configuration listeleri.
- `ui` crate'i: running, stopped, starting ve error preview örnekleri.

Dikkat edeceğin noktalar:

- Source enum'u, gerçek kurulum kaynağıyla eşleşmelidir; tooltip metni bu değerden türetilir.
- `.details(...)` uzun bir hata metni için kullanabilirsin. Yine de ana satırın kalabalıklaşmamasına dikkat edersin.

## AgentSetupButton

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::AgentSetupButton`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for AgentSetupButton`.

Ne zaman kullanırsın:

- Onboarding veya provider setup ekranında bir agent seçeneğini kart buton şeklinde göstermek için.
- Üstte ikon veya isim, altta durum bilgisi olan küçük bir seçim yüzeyi gerektiğinde.

Temel API:

- `AgentSetupButton::new(id)`.
- `.icon(Icon)`.
- `.name(text)`.
- `.state(element)`.
- `.disabled(bool)`.
- `.on_click(handler)`.

Davranış:

- Disabled değilse ve bir `on_click` bağlanmışsa, hover sırasında pointer cursor, hover arka planı ve border rengi uygulanır.
- `state(...)` verildiğinde, alt bölüm border-top ve subtle arka plan ile ayrılır.

Örnek:

```rust
use ui::{AgentSetupButton, Icon, IconName, IconSize, prelude::*};

fn ajan_kurulum_butonu_render() -> impl IntoElement {
    AgentSetupButton::new("zed-ajani-kur")
        .icon(Icon::new(IconName::ZedAgent).size(IconSize::Small))
        .name("Zed Agent")
        .state(Label::new("Hazır").size(LabelSize::Small).color(Color::Success))
        .on_click(|_, _window, _cx| {})
}
```

Zed içinden kullanım örnekleri:

- `onboarding` crate'i: onboarding sırasında agent setup seçenekleri.

Dikkat edeceğin noktalar:

- Boş bir kart üretmemek için en azından icon ile name veya state verilmesi beklenir.
- Disabled durumdayken click işleyicisi render edilmez.

## ThreadItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ThreadItem`, `ui::AgentThreadStatus`, `ui::ThreadItemWorktreeInfo`, `ui::WorktreeKind`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for ThreadItem`.

Ne zaman kullanırsın:

- Bir agent thread listesinde başlık, durum, zaman bilgisi, worktree üstverisi ve diff özetini tek satırda göstermek için.
- Hover eylem alanı ve selected/focused görsel durumu gerektiren thread listelerinde.

Temel API:

- `ThreadItem::new(id, title)`.
- `.timestamp(text)`.
- `.icon(IconName)`, `.icon_color(Color)`, `.icon_visible(bool)`.
- `.custom_icon_from_external_svg(svg)`.
- `.icon_char(text)`, icon slot'unda tek karakterlik agent/thread simgesi gösterir; verildiğinde `.icon(...)` ve `.custom_icon_from_external_svg(...)` değerlerinden önceliklidir.
- `.notified(bool)`.
- `.status(AgentThreadStatus)`.
- `.title_generating(bool)`, `.title_label_color(Color)`, `.highlight_positions(Vec<usize>)`.
- `.title_slot(element)` — başlık alanını tamamen özel bir element ile doldurur; normal title, generating label ve highlight yolu yerine geçer.
- `.is_truncated(bool)` — uzun başlıklar için gradient taşma katmanını açar veya kapatır. Varsayılan değer `true`'dur.
- `.selected(bool)`, `.focused(bool)`, `.hovered(bool)`, `.rounded(bool)`.
- `.added(usize)`, `.removed(usize)`.
- `.project_paths(Arc<[PathBuf]>)`, `.project_name(text)`.
- `.worktrees(Vec<ThreadItemWorktreeInfo>)`.
- `.is_remote(bool)`, `.archived(bool)`.
- `.on_click(handler)`, `.on_hover(handler)`, `.action_slot(element)`, `.base_bg(Hsla)`.
- `AgentThreadStatus`: `Completed`, `Running`, `WaitingForConfirmation`, `Error`. `Completed` varsayılan durumdur ve özel bir status ikonu/animasyonu göstermez.

Thread metadata taşıyıcıları:

| API | Rol |
| :-- | :-- |
| `AgentThreadStatus` | Thread satırının tamamlanmış, çalışıyor, onay bekliyor veya hata durumunda olduğunu seçer. |
| `ThreadItemWorktreeInfo` | Thread satırında gösterilecek worktree adı, branch adı, tam path, highlight pozisyonları ve worktree türünü taşır. |
| `WorktreeKind` | Worktree bilgisini `Main` veya `Linked` olarak sınıflandırır; bileşen yalnız gösterilebilir linked üstveriyi öne çıkarır. |

Davranış:

- `Running` status'u, `LoadCircle` ikonunu rotate animation ile birlikte gösterir.
- `WaitingForConfirmation` warning ikonu ve bir tooltip üretir.
- `Error` durumu close ikonu ve bir tooltip üretir.
- `notified(true)` accent bir circle kullanır.
- Üstveri satırında linked worktree bilgisi, project name veya path, diff stat ve timestamp sırayla render edilir.
- `title_slot(...)` verildiğinde başlık metnini bileşen değil verilen element çizer; bu yol özel ikon, badge veya zengin başlık kompozisyonu için ayrılmıştır.
- `is_truncated(false)` gradient taşma katmanını kapatır; üst yerleşim başlık taşmasını kendisi yönetecekse kullanılır.
- `action_slot(...)` yalnızca `.hovered(true)` durumunda görünür.

Örnek:

```rust
use ui::{
    AgentThreadStatus, IconButton, IconName, IconSize, ThreadItem,
    ThreadItemWorktreeInfo, WorktreeKind, prelude::*,
};

fn ajan_thread_satiri_render() -> impl IntoElement {
    ThreadItem::new("parser-thread", "Parser hata toparlamasını düzelt")
        .icon(IconName::AiClaude)
        .status(AgentThreadStatus::Running)
        .timestamp("12m")
        .worktrees(vec![ThreadItemWorktreeInfo {
            worktree_name: Some("parser-duzeltme".into()),
            branch_name: Some("fix/parser-hata-toparlama".into()),
            full_path: "/worktrees/parser-duzeltme".into(),
            highlight_positions: Vec::new(),
            kind: WorktreeKind::Linked,
        }])
        .added(42)
        .removed(7)
        .hovered(true)
        .action_slot(
            IconButton::new("thread-sil", IconName::Trash)
                .icon_size(IconSize::Small)
                .icon_color(Color::Muted),
        )
}
```

Zed içinden kullanım örnekleri:

- `sidebar` crate'i: thread switcher listesi.
- `sidebar` crate'i: sidebar thread entries.
- `zed` crate'i: geniş thread item varyantları.

Dikkat edeceğin noktalar:

- `ThreadItem` yoğun bir alan bileşenidir. Genel bir liste satırı ihtiyacı için `ListItem` veya özel bir `h_flex()` kompozisyonu çok daha temiz bir çözüm sunar.
- Worktree üstverisinde yalnızca `WorktreeKind::Linked` olan ve worktree veya branch bilgisi bulunan girdiler gösterilir; diğerleri bileşen tarafından filtrelenir.
- Hover durumu bileşen içinde ölçülmez. Üst view, `.hovered(...)` değerini doğru şekilde yönetmek durumundadır.

## ConfiguredApiCard

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ConfiguredApiCard`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for ConfiguredApiCard`.

Ne zaman kullanırsın:

- Bir API key veya provider credential'ın yapılandırılmış olduğu durumu göstermek için.
- Anahtarı sıfırlama veya kaldırma aksiyonunu aynı satırda sunmak için.

Temel API:

- `ConfiguredApiCard::new(label)`.
- `.button_label(text)`.
- `.tooltip_label(text)`.
- `.disabled(bool)`.
- `.button_tab_index(isize)`.
- `.on_click(handler)`.

Davranış:

- Sol tarafta success rengiyle bir `Check` ikonu ve etiket render edilir.
- Button label verilmediğinde varsayılan olarak `"Reset Key"` gelir.
- Button'ın start ikonu `Undo`'dur.
- `disabled(true)`, button'ı disabled hâle getirir ve click işleyicisi bağlanmaz.

Örnek:

```rust
use ui::{ConfiguredApiCard, prelude::*};

fn yapilandirilmis_anahtar_karti_render() -> impl IntoElement {
    ConfiguredApiCard::new("OpenAI API anahtarı yapılandırıldı")
        .button_label("Anahtarı sıfırla")
        .tooltip_label("Geçerli anahtarı değiştirmek için tıkla")
        .on_click(|_, _window, _cx| {})
}
```

Zed içinden kullanım örnekleri:

- `language_models` crate'i: provider key state'i.
- `language_models` crate'i, `deepseek`, `google`, `open_router`: benzer provider kartları.
- `settings_ui` crate'i.

Dikkat edeceğin noktalar:

- Kart yalnızca configured durumu temsil eder; bir credential giriş formu değildir.
- `button_tab_index(...)`, provider setup ekranında klavye sırasını ayarlamak için kullanırsın.

## SkillsIllustration

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::SkillsIllustration`.
- Prelude: Hayır; `use ui::SkillsIllustration;` ayrıca eklersin.
- Preview: Doğrudan `impl Component for SkillsIllustration` yok; onboarding ve agent skills yüzeylerinde başka component'lerin içinde kullanırsın.

Ne zaman kullanırsın:

- Onboarding, "what's new" veya agent skills özelliklerini tanıtan boş durum ekranlarında. Skill adları ve source bilgisiyle küçük bir görsel tanıtım alanı gerektiğinde.
- Henüz veri olmayan ama özelliğin görsel anlamını anlatmak gereken alanlarda dekoratif bir illüstrasyon olarak.

Ne zaman kullanmazsın:

- Gerçek bir agent thread listesi için: `ThreadItem` ile `List` kompozisyonu kullanırsın.
- Etkileşim gerektiren agent provider seçimi için: `AgentSetupButton` veya `AiSettingItem` çok daha uygundur.
- Gerçek skill katalogu, arama veya seçim listesi için bu bileşen kullanılmaz; yalnızca statik bir illüstrasyondur ve click işleyicisi veya durum yüzeyi sunmaz.

Temel API:

- Constructor: `SkillsIllustration::new()`. Bu çağrı argümansızdır.
- `RenderOnce` implement eder; sonradan eklenen bir style builder zinciri yoktur.
- Kapsayıcı içinde yerleştirildiğinde yüksekliği 150px civarında sabittir; genişliği ise üst yerleşim belirler.

Davranış:

- Üç satırlı bir skill listesi çizer. Her satırda iki küçük skill etiketi yer alır.
- Her skill etiketi `Sparkle` ikonu, skill adı ve parantez içinde source bilgisini gösterir.
- Üst katmanda editor arka plan renginden transparana giden bir gradient fade bulunur.
- Renkler `cx.theme().colors().border`, `element_active` ve `editor_background` token'larından beslenir; bu sayede tema değişikliklerinde otomatik uyum sağlar.

Örnek:

```rust
use ui::prelude::*;
use ui::SkillsIllustration;

fn skills_tanitim_render() -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(Headline::new("Ajan becerilerini kullan").size(HeadlineSize::Large))
        .child(
            Label::new("Ajana yeniden kullanılabilir bağlam vermek için odaklı beceriler ekle.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
        .child(SkillsIllustration::new())
}
```

Zed içinden kullanım örnekleri:

- `agent_ui` crate'i ve onboarding ilişkili akışlar: skill özelliğinin tanıtım alanlarında dekoratif bir illüstrasyon olarak.
- `ui` crate'i: bileşenin tek tanım dosyası; alt yapı taşları (`Label`, `Icon`, `h_flex`, `v_flex`) doğrudan ui crate'inden tüketilir.

Dikkat edeceğin noktalar:

- Bu bileşen yalnızca görsel bir illüstrasyondur; gerçek thread, worktree veya agent verisi göstermek için kullanılmaması beklenir.
- İçindeki skill adları statiktir; gerçek proje veya kullanıcı skill listesinden beslenmez.
- `SkillsIllustration::new()` çağrısı parametresizdir; renk veya boyut özelleştirmesi tamamen bileşenin kendi içine bağımlıdır. Farklı bir görsele ihtiyaç doğduğunda, kaynak dosyayı referans alarak özel bir illüstrasyon bileşeni yazmak daha uygun olur.

## CollabNotification

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::CollabNotification`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for CollabNotification`.

Ne zaman kullanırsın:

- Gelen çağrı, proje paylaşımı, kişi isteği veya channel invite gibi iki aksiyonlu collaboration notification view'ı için.
- Avatar, metin ve kabul/kapat buton düzenini standart bir şekilde tutmak için.

Temel API:

- `CollabNotification::new(avatar_uri, accept_button, dismiss_button)`.
- ParentElement: `.child(...)`, `.children(...)`.

Davranış:

- Avatar `px(40.)` boyutunda render edilir.
- Sağ tarafta iki buton dikey olarak yerleşir.
- İçerik `SmallVec<[AnyElement; 2]>` üzerinden tutulur ve bir `v_flex().truncate()` içinde render edilir.

Örnek:

```rust
use ui::{Button, CollabNotification, prelude::*};

fn proje_paylasim_bildirimi_render() -> impl IntoElement {
    CollabNotification::new(
        "https://avatars.githubusercontent.com/u/67129314?v=4",
        Button::new("paylasilan-projeyi-ac", "Aç"),
        Button::new("paylasimi-kapat", "Kapat"),
    )
    .child(Label::new("Ada seninle bir proje paylaştı"))
    .child(Label::new("zed").color(Color::Muted))
}
```

Zed içinden kullanım örnekleri:

- `collab_ui` crate'i: `IncomingCallNotification` içinde gelen çağrı/proje paylaşımı bildirimi.
- `collab_ui` crate'i: `ProjectSharedNotification` içinde paylaşılan proje daveti.
- `collab_ui` crate'i: `CollabNotificationToast` içinde panel odaklayan genel collaboration toast yüzeyi.

Dikkat edeceğin noktalar:

- Kabul ve kapat butonlarının callback'leri üst notification view'ında bağlanmalıdır.
- Uzun kullanıcı veya proje adlarında, child label'lara bir truncate davranışının eklemen gerekir; aksi halde satır taşabilir.

## Agent Skills UI

Kaynak:

- Completion ve mention: `agent_ui` crate'i, `acp_thread` crate'i.
- Thread banner'ları: `agent_ui` crate'i.
- Rules migration: `prompt_store` crate'i.
- Announcement toast: `auto_update_ui` crate'i.

Ne zaman kullanırsın:

- Agent input içinde `/skill-name` veya `@` mention üzerinden bir `SKILL.md` dosyasını prompt bağlamına eklemek için.
- Skill load hatalarını conversation içinde kullanıcıya gösterip dosyaya doğrudan açılabilir bir aksiyon sunmak için.
- Skills tanıtımını kullanıcıya tek seferlik bir announcement toast üzerinden iletmek için.

Davranış:

- Prompt context tipi `skill` olarak geçer ve UI label'ı `Skills`, ikonu `IconName::Sparkle` olur.
- Slash autocomplete açıldığında provider önce delegate'e `slash_autocomplete_invoked(...)` bildirir; native agent bunu global ve proje-local skills taramasını başlatmak için kullanır.
- Slash listesinde Skills, Agent Commands grubundan önce sıralanır. Skill completion label'ında ad ve scope/source birlikte gösterilir; documentation alanında skill description yer alır.
- Skill seçildiğinde metne `MentionUri::Skill` link'i eklersin. Link veya mention açıldığında ilgili `SKILL.md` dosyası workspace içinde absolute path ile açılır.
- `SkillLoadingErrorsUpdated` event'leri thread view'da warning `Callout` olarak render edilir. Her callout kaynakta `Open File` butonu ve dismiss ikon butonu taşır; dosya düzeltildiğinde veya kaldırıldığında dismiss kaydı da temizlenir.
- Rules-to-Skills migration tek seferlik ve non-destructive çalışır; tüm kullanıcılar için aynı şekilde uygulanır. `MIGRATION_DONE_KEY` sabitinin değeri olan `rules_to_skills_migration_done` global KVP anahtarıyla bir kez çalışacak şekilde korunur. Non-default Rules global skills dizinine `SKILL.md` olarak taşınır; Default Rules ve özelleştirilmiş (customized) built-in prompt gövdelerini Zed global `AGENTS.md` dosyasına ekler. Özelleştirilmemiş (uncustomized) built-in prompt'ları `AGENTS.md`'ye aktarmaz; bunlar zaten kullanıcının kişisel `AGENTS.md`'sine enjekte edildiğinden, hiç yazmadığı metni dosyaya eklemekten kaçınır. Sonuç `MIGRATION_RESULT_KEY` sabitinin değeri olan `rules_to_skills_migration_result` anahtarıyla saklanır.
- Skills announcement toast'u `auto_update_ui` içinde "Introducing Skills Support" başlığıyla kurarsın. Migration sonucu boş değilse Rules dönüşümünü anlatan ek bullet gösterir; `"Try Now"` etiketli primary action agent paneline focus eder, `"Read Documentation"` etiketli secondary action skills dokümantasyonuna gider. Toast `skills_announcement_dismissed` KVP anahtarıyla bir kez dismiss edilir.
- Tool permissions setup sayfasında `skill` aracı ayrı bir satırdır. Regex pattern'leri skill adıyla değil, skill'in `SKILL.md` dosyasının absolute path'iyle eşleşir.

Dikkat edeceğin noktalar:

- Skill gövdesi bileşen durumuna kopyalanmaz; UI catalog metadata'sını, dosya yolunu ve yükleme hatalarını gösterir. Gövde, ihtiyaç anında skill tool tarafından okunur.
- Project-local skill ile global skill aynı adı kullanıyorsa, kullanıcı arayüzünde scope/source gösterilmelidir; aksi halde slash completion'da hangi skill'in seçildiği belirsizleşir.
- Skill load hataları dismiss edilebilir ama bu kalıcı bir suppress değildir. Alttaki dosya düzelip sonra yeniden bozulursa hata tekrar gösterilir.

## UpdateButton

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::UpdateButton`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for UpdateButton`.

Ne zaman kullanırsın:

- Title bar içinde auto-update durumunu ve update aksiyonunu göstermek için.
- Checking, downloading, installing, updated veya error state'leri için hazır bir görünüm gerektiğinde.

Temel API:

- `UpdateButton::new(icon, message)`.
- `.icon_animate(bool)`.
- `.icon_color(Option<Color>)`.
- `.tooltip(text)`.
- `.with_dismiss()`.
- `.disabled(bool)`.
- `.on_click(handler)`.
- `.on_dismiss(handler)`.
- Convenience constructor'lar: `UpdateButton::checking()`, `downloading(version)`, `installing(version)`, `updated(version)`, `errored(error)`.

Davranış:

- `icon_animate(true)` çağrısı, ikona dönme animasyonu uygular.
- `.with_dismiss()` sağ tarafta bir kapatma ikon butonu gösterir.
- `.disabled(true)`, ana `ButtonLike` alanını devre dışı bırakır. Bunun yanında `checking`, `downloading` ve `installing` hazır kurucuları bu durumu kendileri uygular.
- Ana alan `ButtonLike::new("update-button")` üzerinden render edilir.
- İpucu verildiğinde ana buton alanına bağlanır.
- `checking()` ile `installing(...)` dönen `IconName::LoadCircle` kullanır; animasyon süresi 2 saniyedir. `downloading(...)` ve `updated(...)` `IconName::Download`, `errored(...)` ise `IconName::Warning` ile çizilir.
- Hazır kurucuların arayüzde ürettiği varsayılan mesajlar şu biçimdedir: `checking()` `"Checking for Zed Updates…"`, `downloading(...)` `"Downloading Zed Update…"`, `installing(...)` `"Installing Zed Update…"`, `updated(...)` `"Restart to Update"`, `errored(...)` ise `"Failed to Update"`. Özel bir metin gerektiğinde `UpdateButton::new(...)` ile açıkça bir durum kurarsın.
- Kenarlık rengi devre dışı duruma göre değişir: aktif konumda `colors().text.opacity(0.15)` ile yumuşatılmış bir kenarlık, devre dışı konumda ise standart `colors().border` kullanırsın. Bu nedenle aktif `updated(...)` ve `errored(...)` durumları, devre dışı olan `checking`, `downloading` ve `installing` durumlarından daha belirgin bir kenarlık taşır.
- Başlık çubuğundaki `UpdateVersion` ipucu `"Update to Version: ..."` biçimindedir; SHA tabanlı bir sürümde kısaltılmış SHA yerine tam SHA gösterilir.

Örnek:

```rust
use ui::{UpdateButton, prelude::*};

fn hazir_guncelleme_butonu_render() -> impl IntoElement {
    UpdateButton::updated("1.99.0")
        .on_click(|_, _window, _cx| {})
        .on_dismiss(|_, _window, _cx| {})
}
```

Zed içinden kullanım örnekleri:

- `auto_update_ui` crate'i: auto-update title bar ve notification akışları.

Dikkat edeceğin noktalar:

- Bu bileşen title bar bağlamına göre tasarlanmıştır; genel bir sayfa CTA'sı olarak kullanılması beklenmez.
- `checking()`, `downloading(...)` ve `installing(...)` constructor'ları zaten disabled bir hâlde gelir. Bu yüzden bu durumlarda click işleyicisi bağlamak anlamsızdır; kullanıcı bir aksiyon yapabilmeliyse `updated(...)`, `errored(...)` veya `UpdateButton::new(...)` ile açıkça bir durum kurmak gerekir.
- `updated(...)` ve `errored(...)` dismiss gösterir; bir dismiss callback'i bağlanmadığında button görünür kalır ama state temizlenmez.

## AI/Collab Kompozisyon Örnekleri

Bir collab özet satırı için Facepile, Chip ve DiffStat birlikte kullanabilirsin. Aşağıdaki örnek hem reviewer'ları hem değişiklik sayısını hem de açıklayıcı bir başlığı tek bir satırda toplar:

```rust
use ui::{Avatar, Chip, DiffStat, Facepile, prelude::*};

fn collab_ozeti_render() -> impl IntoElement {
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
                .child(Label::new("Değişiklikler inceleniyor").truncate())
                .child(Chip::new("2 inceleyen").label_color(Color::Muted)),
        )
        .child(DiffStat::new("inceleme-ozeti-diff", 12, 3))
}
```

Bir agent ayar satırı için ise `AiSettingItem` ile `ConfiguredApiCard` birlikte iyi bir özet sunar. İlki MCP veya agent provider'ı temsil eder; ikincisi credential'ın yapılandırıldığını gösterir:

```rust
use ui::{
    AiSettingItem, AiSettingItemSource, AiSettingItemStatus, ConfiguredApiCard,
    IconButton, IconName, IconSize, prelude::*,
};

fn ajan_ayarlari_ozeti_render() -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(
            AiSettingItem::new(
                "claude-agent",
                "Claude Agent",
                AiSettingItemStatus::Running,
                AiSettingItemSource::Extension,
            )
            .detail_label("Hazır")
            .action(
                IconButton::new("ajan-ayarlari", IconName::Settings)
                    .icon_size(IconSize::Small)
                    .icon_color(Color::Muted),
            ),
        )
        .child(ConfiguredApiCard::new("Anthropic API anahtarı yapılandırıldı"))
}
```

Bu bölümdeki bileşenlerin nerede tercih edileceğini özetleyen kısa bir karar rehberi şöyle özetlenebilir:

- Kişi görseli için `Avatar`; kişi grubu için `Facepile`.
- Kompakt üstveri etiketi için `Chip`.
- Eklenen ve silinen satır özetleri için `DiffStat`.
- Açılır veya kapanır bir icon button için `Disclosure`.
- Sağ kenarda yumuşak bir fade katmanı için `GradientFade`.
- Paketlenmiş bir SVG için `Vector`; raster veya dış kaynaklı bir görsel için GPUI `img(...)`.
- Kısayol render için `KeyBinding`; açıklamalı bir kısayol ipucu için `KeybindingHint`.
- Focus ve scroll traversal için `Navigable`.
- AI ayar satırı için `AiSettingItem`; provider credential state'i için `ConfiguredApiCard`; agent thread listesi için `ThreadItem`.
- Agent skills özelliği için onboarding veya illüstrasyon alanı gerekiyorsa `SkillsIllustration` (yalnızca dekoratif).
- Collaboration toast yerleşimi için `CollabNotification`; title bar update state'i için `UpdateButton`.
