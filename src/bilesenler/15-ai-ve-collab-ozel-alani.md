# 15. AI ve Collab Özel Alanı

Bu bölümdeki bileşenler Zed'in AI, agent (temsilci), sağlayıcı, iş birliği (collaboration) ve güncelleme akışlarına yakından bağlıdır. Bu yüzden genel bir uygulamada kullanmadan önce alan modelinin bu API'lere gerçekten uyup uymadığını kontrol edilmesi gerekir. Aksi halde bileşen görsel olarak hazır görünür, fakat modelin ihtiyaçlarıyla çelişebilir.

Bu ailede iki genel kural geçerlidir:

- Alana bağlı bileşenlerde gerçek servis durumu bileşenin içine taşınmaz. Bileşene yalnızca render için gereken etiket, durum, ikon, geri çağrı (callback) ve üstveri (metadata) verilir.
- AI ve Collab bileşenlerini başka panellerde kompoze ederken alan durumunun görünümde (view) tutulması gerekir. Bu bileşenler yalnızca o durumu görsel olarak düzenler.

![AI ve Collab Domain Haritası](assets/ai-collab-domain-haritasi.svg)

## AiSettingItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::AiSettingItem`, `ui::AiSettingItemStatus`, `ui::AiSettingItemSource`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for AiSettingItem`.

Tavsiye Edilen Kullanım Alanları:

- MCP sunucusu, temsilci (agent) sağlayıcısı veya AI entegrasyonu için ayar satırı göstermek gerektiğinde.
- Durum göstergesi, kaynak ikonu, detay etiketi, eylem butonu ve detay satırını tek bir kompakt satırda (row) toplamak için.

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
| `AiSettingItemStatus` | Sağlayıcı veya MCP satırının durumunu taşır: `Stopped`, `Starting`, `Running`, `Error`, `AuthRequired`, `ClientSecretRequired`, `Authenticating`. |
| `AiSettingItemSource` | Ayarın nereden geldiğini belirtir: `Extension`, `Custom` veya `Registry`. |

Davranış:

- Bir ikon verilmediğinde, etiketin ilk harfinden küçük bir avatar otomatik olarak üretilir.
- `Starting` ve `Authenticating` durumlarında ikon, opaklık (opacity) üzerinden nabız (pulse) animasyonu alır.
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

- `agent_ui` crate'i: MCP sunucusu ve temsilci yapılandırma listeleri.
- `ui` crate'i: Çalışıyor (running), durduruldu (stopped), başlatılıyor (starting) ve hata (error) önizleme örnekleri.

Dikkat Edilmesi Gereken Hususlar:

- Kaynak (source) enum değeri, gerçek kurulum kaynağıyla eşleşmelidir; tooltip metni bu değerden türetilir.
- `.details(...)` alanı uzun bir hata metni için kullanılabilir. Yine de ana satırın aşırı kalabalıklaşmamasına dikkat edilmesi gerekir.

## AgentSetupButton

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::AgentSetupButton`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for AgentSetupButton`.

Tavsiye Edilen Kullanım Alanları:

- İlk kurulum (onboarding) veya sağlayıcı kurulum (provider setup) ekranında bir temsilci seçeneğini kart buton şeklinde göstermek için.
- Üstte ikon veya isim, altta durum bilgisi olan küçük bir seçim yüzeyi gerektiğinde.

Temel API:

- `AgentSetupButton::new(id)`.
- `.icon(Icon)`.
- `.name(text)`.
- `.state(element)`.
- `.disabled(bool)`.
- `.on_click(handler)`.

Davranış:

- Devre dışı (disabled) değilse ve bir `on_click` bağlanmışsa, üzerine gelindiğinde (hover) işaretçi imleci (pointer cursor), hover arka planı ve sınır rengi uygulanır.
- `state(...)` verildiğinde, alt bölüm üst kenarlık (border-top) ve ince bir arka plan ile ayrılır.

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

- `onboarding` crate'i: Onboarding sırasında temsilci kurulum seçenekleri.

Dikkat Edilmesi Gereken Hususlar:

- Boş bir kart üretmemek için en azından ikon ile isim veya durum bilgisinin verilmesi gerekir.
- Devre dışı (disabled) durumdayken tıklama işleyicisi render edilmez.

## ThreadItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ThreadItem`, `ui::AgentThreadStatus`, `ui::ThreadItemWorktreeInfo`, `ui::WorktreeKind`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ThreadItem`.

Tavsiye Edilen Kullanım Alanları:

- Bir temsilci thread listesinde başlık, durum, zaman bilgisi, worktree üstverisi ve diff özetini tek satırda göstermek için.
- Hover eylem alanı ve seçili/odaklanmış görsel durumu gerektiren thread listelerinde.

Temel API:

- `ThreadItem::new(id, title)`.
- `.timestamp(text)`.
- `.icon(IconName)`, `.icon_color(Color)`, `.icon_visible(bool)`.
- `.custom_icon_from_external_svg(svg)`.
- `.icon_char(text)`: İkon alanında tek karakterlik temsilci/thread simgesi gösterir; verildiğinde `.icon(...)` ve `.custom_icon_from_external_svg(...)` değerlerinden önceliklidir.
- `.notified(bool)`.
- `.status(AgentThreadStatus)`.
- `.title_generating(bool)`, `.title_label_color(Color)`, `.highlight_positions(Vec<usize>)`.
- `.title_slot(element)`: Başlık alanını tamamen özel bir element ile doldurur; normal başlık, oluşturuluyor etiketi ve vurgu yolu yerine geçer.
- `.is_truncated(bool)`: Uzun başlıklar için solma katmanını açar veya kapatır. Varsayılan değer `true`'dur.
- `.selected(bool)`, `.focused(bool)`, `.hovered(bool)`, `.rounded(bool)`.
- `.added(usize)`, `.removed(usize)`.
- `.project_paths(Arc<[PathBuf]>)`, `.project_name(text)`.
- `.worktrees(Vec<ThreadItemWorktreeInfo>)`.
- `.is_remote(bool)`, `.archived(bool)`.
- `.on_click(handler)`, `.on_hover(handler)`, `.action_slot(element)`, `.base_bg(Hsla)`.
- `AgentThreadStatus`: `Completed`, `Running`, `WaitingForConfirmation`, `Error`. `Completed` varsayılan durumdur ve özel bir durum ikonu/animasyonu göstermez.

Thread metadata taşıyıcıları:

| API | Rol |
| :-- | :-- |
| `AgentThreadStatus` | Thread satırının tamamlanmış, çalışıyor, onay bekliyor veya hata durumunda olduğunu seçer. |
| `ThreadItemWorktreeInfo` | Thread satırında gösterilecek worktree adı, branch adı, tam yol (path), vurgulanacak pozisyonlar ve worktree türünü taşır. |
| `WorktreeKind` | Worktree bilgisini `Main` veya `Linked` olarak sınıflandırır; bileşen yalnız gösterilebilir linked üstveriyi öne çıkarır. |

Davranış:

- `Running` durumu, `LoadCircle` ikonunu dönüş animasyonu (rotate animation) ile birlikte gösterir.
- `WaitingForConfirmation` onay bekliyor ikonu ve bir tooltip üretir.
- `Error` durumu kapatma ikonu ve bir tooltip üretir.
- `notified(true)` vurgulu bir daire kullanır.
- Üstveri satırında ilişkili worktree bilgisi, proje adı veya yolu, diff statüsü ve zaman bilgisi sırayla render edilir.
- `title_slot(...)` verildiğinde başlık metnini bileşen değil, doğrudan verilen element çizer; bu yol özel ikon, rozet veya zengin başlık kompozisyonları için ayrılmıştır.
- `is_truncated(false)` solma katmanını kapatır; üst yerleşim başlık taşmasını kendisi yönetecekse tercih edilir.
- Pencere arka planı opak değilse başlık solma gradyanı çizilmez; bunun yerine `Label` veya `HighlightedLabel` üzerinde doğrudan `.truncate()` uygulanır. Böylece transparent window üzerinde solma katmanı görünür bir yama gibi belirmez.
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

- `sidebar` crate'i: Thread geçiş listesi (thread switcher).
- `sidebar` crate'i: Kenar çubuğu thread girdileri.
- `zed` crate'i: Geniş thread öğesi varyantları.

Dikkat Edilmesi Gereken Hususlar:

- `ThreadItem` yoğun bir alan bileşenidir. Genel bir liste satırı ihtiyacı için `ListItem` veya özel bir `h_flex()` kompozisyonu çok daha temiz bir çözüm sunar.
- Worktree üstverisinde yalnızca `WorktreeKind::Linked` olan ve worktree veya branch bilgisi bulunan girdiler gösterilir; diğerleri bileşen tarafından filtrelenir.
- Hover durumu bileşen içinde ölçülmez. Üst görünümde, `.hovered(...)` değerinin doğru şekilde yönetilmesi gerekir.

## ConfiguredApiCard

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ConfiguredApiCard`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ConfiguredApiCard`.

Tavsiye Edilen Kullanım Alanları:

- Bir API key veya sağlayıcı kimlik bilgisinin (provider credential) yapılandırılmış olduğu durumu göstermek için.
- Anahtarı sıfırlama veya kaldırma aksiyonunu aynı satırda sunmak için.

Temel API:

- `ConfiguredApiCard::new(id, label)`.
- `.button_label(text)`.
- `.tooltip_label(text)`.
- `.disabled(bool)`.
- `.button_tab_index(isize)`.
- `.on_click(handler)`.

Davranış:

- Sol tarafta başarı rengiyle bir `Check` ikonu ve etiket render edilir.
- Buton etiketi (button label) verilmediğinde varsayılan olarak `"Reset Key"` gelir.
- Butonun başlangıç ikonu `Undo`'dur.
- `disabled(true)`, butonu devre dışı bırakır ve tıklama işleyicisi bağlanmaz.

Örnek:

```rust
use ui::{ConfiguredApiCard, prelude::*};

fn yapilandirilmis_anahtar_karti_render() -> impl IntoElement {
    ConfiguredApiCard::new("openai-api-karti", "OpenAI API anahtarı yapılandırıldı")
        .button_label("Anahtarı sıfırla")
        .tooltip_label("Geçerli anahtarı değiştirmek için tıkla")
        .on_click(|_, _window, _cx| {})
}
```

Zed içinden kullanım örnekleri:

- `language_models` crate'i: Sağlayıcı anahtar durumu (provider key state).
- `language_models` crate'i (`deepseek`, `google`, `open_router` modülleri): Benzer sağlayıcı kartları.
- `settings_ui` crate'i.

Dikkat Edilmesi Gereken Hususlar:

- Kart yalnızca yapılandırılmış (configured) durumu temsil eder; bir kimlik girişi (credential setup) formu değildir.
- `button_tab_index(...)` metodu, sağlayıcı kurulum ekranında klavye sırasını ayarlamak için kullanılır.

## SkillsIllustration

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::SkillsIllustration`.
- Prelude: Hayır; `use ui::SkillsIllustration;` şeklinde ayrıca eklenmelidir.
- Preview: Doğrudan `impl Component for SkillsIllustration` yoktur; onboarding ve temsilci beceri arayüzlerinde başka bileşenlerin içinde kullanılır.

Tavsiye Edilen Kullanım Alanları:

- Onboarding, "yenilikler" veya temsilci becerilerini tanıtan boş durum ekranlarında. Beceri adları ve kaynak (source) bilgisiyle küçük bir görsel tanıtım alanı gerektiğinde.
- Henüz veri olmayan ama özelliğin görsel anlamını anlatmak gereken alanlarda dekoratif bir illüstrasyon olarak.

Tercih Edilmemesi Gereken Durumlar:

- Gerçek bir temsilci thread listesi için: `ThreadItem` ile `List` kompozisyonunun kullanılması gerekir.
- Etkileşim gerektiren temsilci sağlayıcı seçimi için: `AgentSetupButton` veya `AiSettingItem` çok daha uygundur.
- Gerçek beceri katalogu, arama veya seçim listesi için bu bileşenin kullanılmaması gerekir; yalnızca statik bir illüstrasyondur ve tıklama işleyicisi ya da durum yüzeyi sunmaz.

Temel API:

- Constructor: `SkillsIllustration::new()`. Bu çağrı argümansızdır.
- `RenderOnce` implement eder; sonradan eklenen bir style builder zinciri yoktur.
- Kapsayıcı içinde yerleştirildiğinde yüksekliği 150px civarında sabittir; genişliği ise üst yerleşim belirler.

Davranış:

- Üç satırlı bir beceri (skill) listesi çizer. Her satırda iki küçük beceri etiketi yer alır.
- Her beceri etiketi `Sparkle` ikonu, beceri adı ve parantez içinde kaynak bilgisini gösterir.
- Üst katmanda editör arka plan renginden saydama giden bir solma efekti (gradient fade) bulunur.
- Renkler `cx.theme().colors().border`, `element_active` ve `editor_background` belirteçlerinden beslenir; bu sayede tema değişikliklerine otomatik olarak uyum sağlar.

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

- `agent_ui` crate'i ve onboarding ilişkili akışlar: Beceri özelliğinin tanıtım alanlarında dekoratif bir illüstrasyon olarak kullanılır.
- `ui` crate'i: Bileşenin tek tanım dosyası; alt yapı taşları (`Label`, `Icon`, `h_flex`, `v_flex`) doğrudan ui crate'inden tüketilir.

Dikkat Edilmesi Gereken Hususlar:

- Bu bileşen yalnızca görsel bir illüstrasyondur; gerçek thread, worktree veya temsilci verisi göstermek için kullanılmaması gerekir.
- İçindeki beceri adları statiktir; gerçek proje veya kullanıcı beceri listesinden beslenmez.
- `SkillsIllustration::new()` çağrısı parametresizdir; renk veya boyut özelleştirmesi tamamen bileşenin kendi koduna bağlıdır. Farklı bir görsele ihtiyaç duyulduğunda, kaynak dosyayı referans alarak özel bir illüstrasyon bileşeni yazılması daha uygun olur.

## CollabNotification

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::CollabNotification`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for CollabNotification`.

Tavsiye Edilen Kullanım Alanları:

- Gelen çağrı, proje paylaşımı, kişi isteği veya kanal daveti gibi iki aksiyonlu iş birliği bildirim görünümleri (collaboration notification view) için.
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

Dikkat Edilmesi Gereken Hususlar:

- Kabul ve kapat butonlarının geri çağrıları (callbacks) üst bildirim görünümünde bağlanır.
- Uzun kullanıcı veya proje adlarında, çocuk etiketlere (child labels) bir sınırlandırma (truncate) davranışının eklenmesi gerekir; aksi halde satır taşabilir.

## Agent Skills UI

Kaynak:

- Tamamlama (completion) ve mention: `agent_ui` crate'i, `acp_thread` crate'i.
- Thread banner'ları: `agent_ui` crate'i.
- Kurallar geçişi (rules migration): `prompt_store` crate'i.
- Duyuru toast'u (announcement toast): `auto_update_ui` crate'i.

Tavsiye Edilen Kullanım Alanları:

- Temsilci girdisi (agent input) içinde `/skill-name` veya `@` mention üzerinden bir `SKILL.md` dosyasını prompt bağlamına eklemek için.
- Beceri yükleme hatalarını konuşma (conversation) içinde kullanıcıya gösterip dosyaya doğrudan açılabilir bir aksiyon sunmak için.
- Beceri tanıtımını kullanıcıya tek seferlik bir duyuru toast'u üzerinden iletmek için.

Davranış:

- Prompt bağlam tipi `skill` olarak geçer ve UI etiketi `Skills`, ikonu `IconName::Sparkle` olur.
- Eğik çizgi (slash) otomatik tamamlama açıldığında sağlayıcı önce temsilciye `slash_autocomplete_invoked(...)` durumunu bildirir; yerel temsilci bunu global ve projeye özel beceriler taramasını başlatmak için kullanır.
- Otomatik tamamlama listesinde Beceriler (Skills), Temsilci Komutları (Agent Commands) grubundan önce sıralanır. Beceri tamamlama etiketinde ad ve kapsam/kaynak birlikte gösterilir; belgeleme (documentation) alanında beceri açıklaması yer alır.
- Beceri seçildiğinde yerel temsilci metne `MentionUri::Skill` bağlantısı ekler. Bağlantı veya mention açıldığında ilgili `SKILL.md` dosyası çalışma alanında mutlak yol (absolute path) ile açılır.
- `SkillLoadingIssuesUpdated`, proje için geçerli `SkillLoadingIssue` listesinin tamamını replacement-style bir olayla taşır. Thread görünümü `LoadFailed` ve `CatalogBudgetExceeded` kayıtlarını uyarı `Callout` bileşenleriyle, uzun açıklama sorunlarını ise toplu açıklama uyarısıyla gösterir. Dosyaya bağlı callout `Open Skill` butonu ve kapatma ikon butonu taşır; sorun listeden çıktığında ilgili kapatma kaydı temizlenir ve aynı sorun yeniden oluşursa tekrar gösterilir.
- Kurallardan becerilere geçiş (rules-to-skills migration) tek seferlik çalışır; tüm kullanıcılar için aynı şekilde uygulanır. `MIGRATION_DONE_KEY` sabitinin değeri olan `rules_to_skills_migration_done` global KVP anahtarıyla bir kez çalışacak şekilde korunur. Zed, varsayılan olmayan kuralları (non-default rules) global beceri dizinine `SKILL.md` olarak taşır; varsayılan kuralları (default rules) ve özelleştirilmiş built-in prompt gövdelerini global `AGENTS.md` dosyasına ekler. Özelleştirilmemiş dahili prompt'ları `AGENTS.md` dosyasına aktarmaz; bunlar zaten kullanıcının kişisel `AGENTS.md` dosyasına yerleştirildiğinden, hiç yazmadığı metni dosyaya eklemekten kaçınır. Sonuç `MIGRATION_RESULT_KEY` sabitinin değeri olan `rules_to_skills_migration_result` anahtarıyla saklanır.
- Zed, beceriler duyuru toast'unu `auto_update_ui` içinde "Introducing Skills Support" başlığıyla kurar. Migration sonucu boş değilse kurallar dönüşümünü anlatan ek madde gösterir; `"Try Now"` etiketli birincil eylem temsilci paneline odaklanır, `"Read Documentation"` etiketli ikincil eylem beceri dokümantasyonuna yönlendirir. Toast `skills_announcement_dismissed` KVP anahtarıyla bir kez kapatılır.
- Araç izinleri kurulum sayfasında `skill` aracı ayrı bir satırdır. Regex şablonları beceri adıyla değil, becerinin `SKILL.md` dosyasının mutlak yoluyla eşleşir.

Dikkat Edilmesi Gereken Hususlar:

- Beceri gövdesi bileşen durumuna kopyalanmaz; UI katalog metadatasını, dosya yolunu ve yükleme hatalarını gösterir. Gövde, ihtiyaç anında beceri aracı (skill tool) tarafından okunur.
- Projeye özel beceri ile global beceri aynı adı kullanıyorsa, kullanıcı arayüzünde kapsam/kaynak gösterilir; aksi halde otomatik tamamlamada hangi becerinin seçildiği belirsizleşir.
- Beceri yükleme sorunları kapatılabilir, ancak bu kalıcı bir engelleme değildir. Alttaki dosya düzelip daha sonra aynı sorun yeniden oluşursa uyarı tekrar gösterilir.

## UpdateButton

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::UpdateButton`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for UpdateButton`.

Tavsiye Edilen Kullanım Alanları:

- Başlık çubuğu içinde otomatik güncelleme durumunu ve güncelleme aksiyonunu göstermek için.
- Kontrol ediliyor, indiriliyor, kuruluyor, güncellendi veya hata durumları için hazır bir görünüm gerektiğinde.

Temel API:

- `UpdateButton::new(icon, message)`.
- `.icon_animate(bool)`.
- `.icon_color(Option<Color>)`.
- `.tooltip(text)`.
- `.progress(Option<f32>)`.
- `.with_dismiss()`.
- `.disabled(bool)`.
- `.on_click(handler)`.
- `.on_dismiss(handler)`.
- Yardımcı kurucular (convenience constructors): `UpdateButton::checking()`, `downloading(version, progress)`, `installing(version)`, `updated(version)`, `errored(error)`.

Davranış:

- `icon_animate(true)` çağrısı, ikona dönme animasyonu uygular.
- `.with_dismiss()` sağ tarafta bir kapatma ikon butonu gösterir.
- `.disabled(true)`, ana buton benzeri alanı devre dışı bırakır. Bunun yanında `checking`, `downloading` ve `installing` hazır kurucuları bu durumu kendileri uygular.
- Ana alan `ButtonLike::new("update-button")` üzerinden render edilir.
- İpucu verildiğinde ana buton alanına bağlanır.
- `checking()` ile `installing(...)` dönen `IconName::LoadCircle` kullanır; animasyon süresi 2 saniyedir. `downloading(...)` progress değeri verilmediğinde `IconName::Download` kullanır; progress değeri verildiğinde ikon yerinde `CircularProgress` halkası çizer. `updated(...)` `IconName::Download`, `errored(...)` ise `IconName::Warning` ile çizilir.
- Hazır kurucuların arayüzde ürettiği varsayılan mesajlar şu biçimdedir: `checking()` `"Checking for Zed Updates…"`, `downloading(...)` `"Downloading Zed Update…"`, `installing(...)` `"Installing Zed Update…"`, `updated(...)` `"Restart to Update"`, `errored(...)` ise `"Failed to Update"`. Özel bir metin gerektiğinde `UpdateButton::new(...)` ile açıkça bir durum kurulur.
- Kenarlık rengi devre dışı duruma göre değişir: Aktif konumda `colors().text.opacity(0.15)` ile yumuşatılmış bir kenarlık, devre dışı konumda ise standart `colors().border` kullanılır. Bu nedenle aktif `updated(...)` ve `errored(...)` durumları, devre dışı olan `checking`, `downloading` ve `installing` durumlarından daha belirgin bir kenarlık taşır.
- Başlık çubuğundaki `UpdateVersion` ipucu `"Update to Version: ..."` biçimindedir ve `semver::Version` değerinin `to_string()` çıktısını kullanır; nightly build metadata varsa sürüm metninin parçası olarak görünür.

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

- `auto_update_ui` crate'i: Otomatik güncelleme başlık çubuğu ve bildirim akışları.

Dikkat Edilmesi Gereken Hususlar:

- Bu bileşen başlık çubuğu bağlamına göre tasarlanmıştır; genel bir sayfa CTA'sı olarak kullanılmaması gerekir.
- `checking()`, `downloading(...)` ve `installing(...)` kurucuları zaten devre dışı (disabled) bir hâlde gelir. Bu yüzden bu durumlarda tıklama işleyicisi bağlamak anlamsızdır; kullanıcının bir aksiyon gerçekleştirebilmesi gerekiyorsa `updated(...)`, `errored(...)` veya `UpdateButton::new(...)` ile açıkça bir durum kurulması gerekir.
- `updated(...)` ve `errored(...)` kapatma (dismiss) butonu gösterir; bir dismiss callback'i bağlanmadığında buton görünür kalır ama durum temizlenmez.

## AI/Collab Kompozisyon Örnekleri

Bir collab özet satırı için Facepile, Chip ve DiffStat birlikte kullanılabilir. Aşağıdaki örnek hem gözden geçirenleri hem değişiklik sayısını hem de açıklayıcı bir başlığı tek bir satırda toplar:

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

Bir temsilci ayar satırı için ise `AiSettingItem` ile `ConfiguredApiCard` birlikte iyi bir özet sunar. İlki MCP veya temsilci sağlayıcısını temsil eder; ikincisi kimlik bilgisinin yapılandırıldığını gösterir:

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
        .child(ConfiguredApiCard::new(
            "anthropic-api-karti",
            "Anthropic API anahtarı yapılandırıldı",
        ))
}
```

Bu bölümdeki bileşenlerin tercih yerlerini özetleyen kısa karar rehberi şöyledir:

- Kişi görseli için `Avatar`; kişi grubu için `Facepile`.
- Kompakt üstveri etiketi için `Chip`.
- Eklenen ve silinen satır özetleri için `DiffStat`.
- Açılır veya kapanır bir ikon butonu için `Disclosure`.
- Sağ kenarda yumuşak bir fade katmanı için `GradientFade`.
- Paketlenmiş bir SVG için `Vector`; raster veya dış kaynaklı bir görsel için GPUI `img(...)`.
- Kısayol render işlemi için `KeyBinding`; açıklamalı bir kısayol ipucu için `KeybindingHint`.
- Odak ve kaydırma traversal'ı için `Navigable`.
- AI ayar satırı için `AiSettingItem`; sağlayıcı kimlik durumu (provider credential state) için `ConfiguredApiCard`; temsilci thread listesi için `ThreadItem`.
- Temsilci becerileri (agent skills) özelliği için onboarding veya illüstrasyon alanı gerekiyorsa `SkillsIllustration` (yalnızca dekoratif).
- İş birliği bildirim yerleşimi (collaboration notification layout) için `CollabNotification`; başlık çubuğu güncelleme durumu için `UpdateButton`.
