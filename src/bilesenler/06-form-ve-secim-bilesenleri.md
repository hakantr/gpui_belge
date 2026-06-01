# 6. Form ve Seçim Bileşenleri

Bu bölüm, kullanıcıdan değer alan veya var olan bir ayarı değiştiren kontrolleri anlatır. Butonlardan hemen sonra gelmesinin sebebi de budur: checkbox, switch ve input alanları aynı event modeline yaslanır; ayrıca önceki bölümlerdeki label ve icon düzenini tekrar kullanır. Butonların çalışma şeklini anladıysan, bu kontrollerin arkasındaki fikir tanıdık gelecektir.

Hangi durumda hangisini seçeceğini belirlemek için şu ayrım iş görür:

![Form Kontrolü Seçimi](assets/form-kontrolu-secimi.svg)

- Birbirinden bağımsız çoklu bir seçim varsa `Checkbox` doğru araçtır.
- Bir ayarı aç/kapat anlamı taşıyan tek bir değer için `Switch` daha uygundur.
- Label, açıklama ve switch birlikte düzenli bir tek satır ayar olarak görünecekse `SwitchField` bu üçlüyü tek seferde kurarsın.
- Tek satır metin girişi için ise `ui_input::InputField` kullanırsın.

Bu kontrollerin hepsi için ortak kural şudur: görsel durum ile uygulama durumu birbirinden ayrı düşünülür. Checkbox, switch veya input yalnızca o anki state'i ekrana yansıtır. Gerçek değer view state'inde veya uygulama modelinde tutulur ve handler içinde güncellenir. Bu ayrımı net tutmak, sahnenin tutarlı kalmasını sağlar.

## Checkbox

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Checkbox` | `description`, `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Checkbox` | Metotlar | `container_size`, `fill`, `label`, `label_color`, `label_size`, `new`, `on_click`, `on_click_ext`, `placeholder`, `style`, `tooltip`, `visualization_only` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Kaynak:

- Tanım: `../zed/crates/ui/src/components/toggle.rs`
- Export: `ui::Checkbox`, `ui::checkbox`, `ui::ToggleStyle`
- Prelude: Hayır; `Checkbox` ve `ToggleStyle` için ayrıca import edersin.
- `ToggleState` ise prelude içinde otomatik gelir.
- Preview: `impl Component for Checkbox`.

Ne zaman kullanırsın:

- Bir listedeki her seçimin diğerlerinden bağımsız olduğu durumlarda.
- Çoklu izin, filtre, staged file, feature capability gibi birden fazla değerin aynı anda seçilebileceği yapılarda.
- Üst seviye bir seçimin alt öğelerinin yalnızca bir kısmı seçiliyse `ToggleState::Indeterminate` ile bu kısmi durumu göstermek için.

Ne zaman kullanmazsın:

- Yalnızca tek bir ayarı açıp kapatma durumu söz konusuysa `Switch` veya `SwitchField` çok daha açık bir niyet ifade eder.
- Karşılıklı olarak birbirini dışlayan seçenekler için `ToggleButtonGroup`, `DropdownMenu` veya bir menu entry daha doğru yüzeydir.
- Sadece pasif bir durum göstergesi gerekiyorsa `Indicator`, `Icon` ya da `.visualization_only(true)` ile etkileşimsizleştirilmiş bir checkbox düşünebilirsin.

Temel API:

- Constructor: `Checkbox::new(id, checked: ToggleState)`.
- Yardımcı constructor: `checkbox(id, toggle_state)`.
- Builder'lar: `.disabled(bool)`, `.placeholder(bool)`, `.fill()`, `.visualization_only(bool)`, `.style(ToggleStyle)`, `.elevation(...)`, `.tooltip(...)`, `.label(...)`, `.label_size(...)`, `.label_color(...)`, `.on_click(...)`, `.on_click_ext(...)`.
- Statik ölçü yardımcısı: `Checkbox::container_size() -> Pixels` checkbox kutusu için kullanılan sabit yan ölçüsünü (`px(20.0)`) döndürür; bir checkbox satırını diğer kontrollerle hizalamak gerektiğinde başvurduğun değerdir.
- `ToggleStyle`: `Ghost`, `ElevationBased(ElevationIndex)`, `Custom(Hsla)`.

Davranış:

- `RenderOnce` implement eder.
- `ToggleState::Selected` için `IconName::Check`, `ToggleState::Indeterminate` için ise `IconName::Dash` ikonunu çizer.
- Click handler'a mevcut state değil, `self.toggle_state.inverse()` gönderilir. Yani handler her zaman "hedef state"i alır.
- `ToggleState::Indeterminate.inverse()` çağrısının sonucu `Selected` olur; bu sayede kısmi seçimden tıklama ile tam seçime geçilir.
- `disabled(true)` click handler'ını devre dışı bırakır.
- `visualization_only(true)` pointer ve hover davranışını kaldırır, ama bileşeni disabled gibi soluk renkle göstermez; yalnızca dokunulamaz hale getirir.

Örnek:

```rust
use ui::prelude::*;
use ui::{Checkbox, Tooltip};

struct PrivacySettings {
    telemetry: bool,
}

impl Render for PrivacySettings {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Checkbox::new("telemetry-checkbox", self.telemetry.into())
            .label("Share anonymous diagnostics")
            .label_size(LabelSize::Small)
            .tooltip(Tooltip::text("Helps improve crash and performance diagnostics."))
            .on_click(cx.listener(|this: &mut PrivacySettings, state: &ToggleState, _, cx| {
                this.telemetry = state.selected();
                cx.notify();
            }))
    }
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/workspace/src/security_modal.rs`: güvenlik modalındaki seçim.
- `../zed/crates/git_ui/src/git_panel.rs`: staged/unstaged seçimleri.
- `../zed/crates/language_tools/src/lsp_log_view.rs`: context menu içinde yer alan custom checkbox entry.

Dikkat edeceğin noktalar:

- Handler'a gelen state mevcut state değil, hedef state'tir. `self.telemetry = state.selected()` gibi doğrudan uygulama state'ine yazılır; tekrar tersine çevirmeye gerek yoktur.
- Kısmi bir seçim gösteriliyorsa `ToggleState::from_any_and_all(...)` helper'ının kullanılması, manuel `if` koşullarına göre çok daha okunabilir bir sonuç verir.
- Checkbox bir label'a sahipse, click alanı tüm satıra yayılır. Satır içinde iç içe başka bir tıklanabilir element yer alacaksa, event propagation'ı bilinçli olarak ele alman gerekir.

## Switch

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Switch` | `description`, `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Switch` | Metotlar | `full_width`, `key_binding`, `label`, `label_position`, `label_size`, `new`, `on_click`, `tab_index` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Kaynak:

- Tanım: `../zed/crates/ui/src/components/toggle.rs`
- Export: `ui::Switch`, `ui::switch`, `ui::SwitchColor`, `ui::SwitchLabelPosition`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Switch`.

Ne zaman kullanırsın:

- Bir ayarı anında açıp kapatan, iki karşıt durumlu kontrollerde.
- Bir label gerekiyor ama uzun bir açıklama metni gerekmediği durumlarda.
- Toolbar veya kompakt ayar satırlarında.

Ne zaman kullanmazsın:

- Açıklama, tooltip ve switch'ten oluşan düzenli bir ayar satırı kuruluyorsa `SwitchField` daha bütünlüklü bir yüzey sağlar.
- Çoklu bir seçimde checkbox semantiği daha doğrudan bir anlatım sunar.

Temel API:

- Constructor: `Switch::new(id, state: ToggleState)`.
- Yardımcı constructor: `switch(id, toggle_state)`.
- Builder'lar: `.color(SwitchColor)`, `.disabled(bool)`, `.on_click(...)`, `.label(...)`, `.label_position(...)`, `.label_size(...)`, `.full_width(bool)`, `.key_binding(...)`, `.tab_index(...)`.
- `SwitchColor`: `Accent`, `Custom(Hsla)`.
- `SwitchLabelPosition`: `Start`, `End`.

Davranış:

- `ToggleState::Selected` açık, diğer state'ler kapalı görünür.
- Click handler'a `self.toggle_state.inverse()` gönderilir; yani Switch da Checkbox gibi hedef state'i taşır.
- `full_width(true)` switch ile label'ı satır içinde iki uca doğru yayar; böylece label solda, switch sağda görünür.
- `tab_index(...)` verildiğinde switch focus-visible bir border kazanır ve klavye focus sırasına dahil olur.

Örnek:

```rust
use ui::prelude::*;
use ui::{Switch, SwitchLabelPosition};

struct EditorSettings {
    auto_save: bool,
}

impl Render for EditorSettings {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Switch::new("auto-save-switch", self.auto_save.into())
            .label("Auto save")
            .label_position(Some(SwitchLabelPosition::Start))
            .full_width(true)
            .on_click(cx.listener(|this: &mut EditorSettings, state: &ToggleState, _, cx| {
                this.auto_save = state.selected();
                cx.notify();
            }))
    }
}
```

Dikkat edeceğin noktalar:

- `ToggleState::Indeterminate`, switch için ayrı bir görsel ara durum üretmez. Switch açık/kapalı anlamı taşıdığı için state'in çoğunlukla `bool` üzerinden üretilmesi daha tutarlı bir tercihtir.
- Disabled bir switch, dış container'da pointer cursor'ı tamamen kaldırmaz. Kullanıcıya neden disabled olduğunu anlatmak gerekiyorsa satıra kısa bir açıklama veya tooltip eklemek bu boşluğu kapatır.

## SwitchField

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `SwitchField` | `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `SwitchField` | Metotlar | `description`, `tab_index`, `tooltip` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Kaynak:

- Tanım: `../zed/crates/ui/src/components/toggle.rs`
- Export: `ui::SwitchField`
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for SwitchField`.

Ne zaman kullanırsın:

- Ayar ekranlarında label, açıklama ve switch'in bir arada gösterileceği durumlarda.
- Tek satırda sağda switch, solda metinsel bağlam isteyen seçeneklerde.
- Bir tooltip ikonuyla ek bilgi verilmesi gereken ayarlarda.

Ne zaman kullanmazsın:

- Yalnızca kompakt bir switch gerekiyorsa `Switch` daha sade bir yüzey sunar.
- Birden fazla bağımsız seçim varsa bir `Checkbox` listesi daha doğru bir ifade biçimidir.

Temel API:

- Constructor: `SwitchField::new(id, label, description, toggle_state, on_click)`.
- `label`: `Option<impl Into<SharedString>>`.
- `description`: `Option<SharedString>`.
- `toggle_state`: `impl Into<ToggleState>`.
- Builder'lar: `.description(...)`, `.disabled(bool)`, `.color(...)`, `.tooltip(...)`, `.tab_index(...)`.

Davranış:

- `RenderOnce` implement eder.
- Container'ın kendisine yapılan tıklama ile iç switch'e yapılan tıklama, aynı `on_click` callback'ini hedef state ile çağırır; yani satırın herhangi bir yerine tıklamak da switch'i toggle eder.
- Tooltip verildiğinde label'ın yanında bir `IconButton::new("tooltip_button", IconName::Info)` render edilir. Bu ikonun click handler'ı boştur; yani bilgi ikonuna tıklamak switch'i toggle etmez, yalnızca bilgi göstergesi olarak durur.
- Açıklama verildiğinde, muted renkli bir label olarak çizilir.

Örnek:

```rust
use ui::prelude::*;
use ui::{SwitchField, Tooltip};

struct AssistantSettings {
    fast_mode: bool,
}

impl Render for AssistantSettings {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        SwitchField::new(
            "fast-mode",
            Some("Fast mode"),
            Some("Prefer quicker responses for routine edits.".into()),
            self.fast_mode,
            cx.listener(|this: &mut AssistantSettings, state: &ToggleState, _, cx| {
                this.fast_mode = state.selected();
                cx.notify();
            }),
        )
        .tooltip(Tooltip::text("This changes the behavior for new requests."))
    }
}
```

Dikkat edeceğin noktalar:

- `SwitchField`, tam genişlikte bir ayar satırı davranışı kurarsın. Toolbar gibi dar alanlarda bu fazla yer kaplar; orada doğrudan `Switch` tercih edersin.
- Tooltip yalnızca label varlığında görsel bir ikonla birlikte çizilir; label'sız kullanımda tooltip görünmez.

Ortak `ToggleState` modeli:

| Variant | Anlam | Not |
| :-- | :-- | :-- |
| `Unselected` | Kapalı / seçili değil | `Default` variant'tır; `false.into()` bu değeri üretir |
| `Indeterminate` | Kısmi seçim | Checkbox'ta görsel ara durum üretir; switch'te ayrı bir ara durum beklenmez |
| `Selected` | Açık / seçili | `true.into()` bu değeri üretir |

Yardımcılar: `.inverse()`, `ToggleState::from_any_and_all(any_checked, all_checked)`, `.selected()`, `From<bool>`. Bunlardan `from_any_and_all`, alt seçimlerin sayısına göre üst state'in otomatik olarak doğru variant'a oturmasını sağlar.

Form ve toggle yardımcı API'leri:

| API | Rol |
| :-- | :-- |
| `checkbox` | `Checkbox::new(id, toggle_state)` için kısa constructor'dır; görsel ve handler davranışı `Checkbox` ile aynıdır. |
| `switch` | `Switch::new(id, toggle_state)` için kısa constructor'dır; iki durumlu ayar satırlarında sade kullanım sağlar. |
| `ToggleStyle` | Checkbox ve benzeri toggle yüzeylerinde `Ghost`, `ElevationBased(ElevationIndex)` veya `Custom(Hsla)` görünümünü seçer. |
| `SwitchColor` | Switch açık durum rengini `Accent` ya da `Custom(Hsla)` olarak belirler. |
| `SwitchLabelPosition` | Switch label'ının `Start` veya `End` tarafında duracağını seçer. |

## InputField (`ui_input`)

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `InputField` | `description`, `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `InputField` | Metotlar | `is_empty`, `label`, `label_min_width`, `label_size`, `masked`, `start_icon`, `tab_index`, `tab_stop` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Kaynak:

- Tanım: `../zed/crates/ui_input/src/input_field.rs`
- Export: `ui_input::InputField`
- Prelude: Hayır; `use ui_input::InputField;` ayrıca eklersin.
- Preview: `impl Component for InputField`.

Ne zaman kullanırsın:

- Search input, API key alanı, ayar formu veya modal içi tek satır metin girişi gerektiğinde.
- Editor tabanlı gerçek text input davranışı, focus handle, placeholder, masked değer ve tab order desteği istendiğinde.

Ne zaman kullanmazsın:

- Yalnızca statik bir metin göstermek için `Label` daha basit ve doğru bir çözümdür.
- Çok satırlı veya editor özellikleri gerektiren bir içerik için doğrudan editor tabanlı bir view kullanmak gerekir.
- `crates/ui` içine bağımlılık eklerken `ui_input`'u çözüm olarak düşünmemen gerekir; `ui_input`, editor crate'ine bağımlı olduğu için ayrı bir crate olarak tutulur ve bu sınırı korumak istersin.

Temel API:

- Constructor: `InputField::new(window, cx, placeholder_text)`.
- Builder'lar: `.start_icon(IconName)`, `.label(...)`, `.label_size(...)`, `.label_min_width(...)`, `.tab_index(...)`, `.tab_stop(bool)`, `.masked(bool)`.
- Okuma/yazma: `.text(cx)`, `.is_empty(cx)`, `.clear(window, cx)`, `.set_text(text, window, cx)`, `.set_masked(masked, window, cx)`.
- Düşük seviye erişim: `.editor() -> &Arc<dyn ErasedEditor>`.

Davranış:

- `Render` ve `Focusable` implement eder; genellikle `Entity<InputField>` olarak view state'inde tutulur.
- `InputField::new(...)` çağrısı, `ui_input::ERASED_EDITOR_FACTORY` factory fonksiyonunun önceden kurulmuş olmasını bekler. Zed runtime'ı bu factory'i editor entegrasyonu sırasında hazırlar.
- `.masked(true)` verildiğinde sağda bir show/hide `IconButton` render edilir ve bu butona tıklamak mask state'ini günceller.
- Focus görünümü editor focus handle'ına bağlı border rengiyle çizilir.

Örnek:

```rust
use gpui::Entity;
use ui::prelude::*;
use ui_input::InputField;

fn new_api_key_input(window: &mut Window, cx: &mut App) -> Entity<InputField> {
    cx.new(|cx| {
        InputField::new(window, cx, "sk-...")
            .label("API key")
            .start_icon(IconName::LockOutlined)
            .masked(true)
    })
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/language_models/src/provider/open_ai.rs`: API key input'u.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: context ve action input'ları.
- `../zed/crates/component_preview/src/component_preview.rs`: component arama filter input'u.

Düşük seviye yüzey — `ErasedEditor`:

`.editor()` çağrısıyla elde edilen `Arc<dyn ErasedEditor>` değeri, gerçek bir `Editor` view'una type-erased bir kapı sunar. Bu sayede `ui_input` crate'i `editor` crate'ine doğrudan bağımlı olmaz; editor entegrasyonu uygulama başlangıcında bir kez `ERASED_EDITOR_FACTORY: OnceLock<...>` üzerinden kurarsın:

`ui_input` köprü API'leri:

| API | Rol |
| :-- | :-- |
| `ERASED_EDITOR_FACTORY` | Runtime'da gerçek editor adapter'ını sağlayan global factory'dir; `InputField::new(...)` bu factory kurulduktan sonra çağrılmalıdır. |
| `ErasedEditor` | Text okuma/yazma, focus handle, masking, event subscription ve render işlemlerini crate sınırını bozmadan sunan trait yüzeyidir. |
| `ErasedEditorEvent` | `BufferEdited` ve `Blurred` event'leriyle input değişimi ve focus kaybını bildirir. |

```rust
// Uygulama init'inde (genellikle editor crate'inin init fonksiyonu kurar):
ui_input::ERASED_EDITOR_FACTORY
    .set(|window, cx| Arc::new(MyEditorAdapter::new(window, cx)))
    .ok();
```

`ErasedEditor` trait metodları:

| Metot | İmza | Kullanım |
| :-- | :-- | :-- |
| `text(cx)` | `(&self, &App) -> String` | Anlık metin değeri |
| `set_text(text, window, cx)` | `(&self, &str, &mut Window, &mut App)` | Programatik değer atama |
| `clear(window, cx)` | `(&self, &mut Window, &mut App)` | Tüm metni siler |
| `set_placeholder_text(text, window, cx)` | `(&self, &str, &mut Window, &mut App)` | Placeholder güncelleme |
| `move_selection_to_end(window, cx)` | `(&self, &mut Window, &mut App)` | İmleci sona taşır |
| `set_masked(masked, window, cx)` | `(&self, bool, &mut Window, &mut App)` | Şifre maskesi aç/kapat |
| `focus_handle(cx)` | `(&self, &App) -> FocusHandle` | Focus management |
| `subscribe(callback, window, cx)` | `Subscription` döner | Event subscription |
| `render(window, cx)` | `(&self, &mut Window, &App) -> AnyElement` | Manuel render (InputField içeride çağırır) |
| `as_any()` | `&dyn Any` | Downcast için |

`ErasedEditorEvent` enum'u iki variant taşır:

| Variant | Ne zaman emit edilir |
| :-- | :-- |
| `BufferEdited` | Kullanıcı metni değiştirdiğinde (yazma, silme, paste vb.) |
| `Blurred` | Editor focus'u kaybettiğinde |

Değer değişimini takip etmek için view içinde bir subscription kurman ve bunu saklaman gerekir. Subscription drop edildiğinde callback ölür ve event akışı durur:

```rust
use gpui::{Entity, Subscription};
use ui::prelude::*;
use ui_input::{ErasedEditorEvent, InputField};

struct ApiKeyForm {
    input: Entity<InputField>,
    current_value: String,
    _input_subscription: Subscription,
}

impl ApiKeyForm {
    fn new(window: &mut Window, cx: &mut Context<Self>) -> Self {
        let input = cx.new(|cx| {
            InputField::new(window, cx, "sk-...")
                .label("API key")
                .masked(true)
        });

        let subscription = input.read(cx).editor().subscribe(
            Box::new(cx.listener(|this: &mut Self, event, _window, cx| {
                match event {
                    ErasedEditorEvent::BufferEdited => {
                        this.current_value = this.input.read(cx).text(cx);
                        cx.notify();
                    }
                    ErasedEditorEvent::Blurred => {
                        // Doğrulama veya kaydet
                    }
                }
            })),
            window,
            cx,
        );

        Self { input, current_value: String::new(), _input_subscription: subscription }
    }
}
```

> **`_input_subscription` saklamak şart.** `Subscription` drop edilirse callback ölür ve `BufferEdited` event'i tetiklenmez. Aynı kural diğer GPUI subscription'ları için de geçerlidir.

Dikkat edeceğin noktalar:

- `InputField` `RenderOnce` değildir; her render'da yeniden yaratmak yerine entity olarak saklanır ve view state'inde tutulur.
- Text değeri `field.read(cx).text(cx)` ile okunur. Değer değişimine tepki verilecekse yukarıdaki `subscribe` örneği izlenir ve dönen `Subscription` view alanında saklarsın.
- `ERASED_EDITOR_FACTORY` kurulmadan `InputField::new` çağrılırsa panic oluşur; bu yüzden editor crate'inin init fonksiyonunun uygulama başlangıcında çalıştığından emin olman gerekir.
- `label_min_width(...)` adı tarihsel olarak "label" ifadesini taşısa da, kaynakta bu metod input container'ın `min_width` değerini ayarlar.

## Ayar UI Form Yüzeyi

Kaynak:

- Sayfa verisi: `../zed/crates/settings_ui/src/page_data.rs`.
- Renderer kayıtları: `../zed/crates/settings_ui/src/settings_ui.rs`.
- Tool permission setup: `../zed/crates/settings_ui/src/pages/tool_permissions_setup.rs`.

Davranış:

- `settings_ui::init_renderers(...)`, `settings::CompletionMenuItemKind` için dropdown renderer kaydeder. Bu ayar `editor.completion_menu_item_kind` JSON path'iyle görünür; değerler `off` ve `symbol` olur.
- Ayar sayfasındaki "Completion Menu Item Kind" satırı, completions menüsünde LSP item kind bilgisinin gösterilip gösterilmeyeceğini seçtirir. `off` item kind'i gizler, `symbol` syntax theme ile renklendirilmiş tek harfli badge gösterir.
- Version Control / Git Hunks bölümünde "Show Stage/Restore Buttons" satırı `git.show_stage_restore_buttons` boolean ayarını yazar. Bu değer false olduğunda diff hunk üstündeki Stage/Unstage ve Restore butonları render edilmez.
- Tool Permissions setup listesindeki `skill` aracı "Loading agent skill instructions" açıklamasıyla gelir. Regex açıklaması skill adına değil, skill'in `SKILL.md` dosyasının absolute path'ine göre eşleştiğini belirtir.
- Ayar araması boş query'de sonuç döndürmez. Query birden fazla kelime içerdiğinde sonuç, query kelimelerinin tamamının ilgili dokümandaki bir sözcük prefix'iyle eşleşmesini bekler.

Dikkat edeceğin noktalar:

- Yeni enum tabanlı ayarlar için yalnızca `SettingItem` eklemek yetmez; ilgili enum'un `init_renderers(...)` içinde uygun renderer'a kaydedilmesi gerekir.
- Git hunk butonları ayarla kapatıldığında aynı aksiyonu geriye uyumluluk amacıyla ikinci bir button ile geri ekleme. Kullanıcıya görünür yüzey ayar değerini doğrudan izlemelidir.

## Form Kompozisyon Örnekleri

Bir ayar satırı için tipik kompozisyon, `SwitchField`'ın etrafına bir `v_flex` koymak ve gerekirse birden fazla benzer satırı bu kolonda alt alta dizmektir. Aşağıdaki örnek tek bir satır gösterir:

```rust
use ui::prelude::*;
use ui::{SwitchField, Tooltip};

struct SettingsView {
    format_on_save: bool,
}

impl Render for SettingsView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_3()
            .child(
                SwitchField::new(
                    "format-on-save",
                    Some("Format on save"),
                    Some("Run the active formatter before writing the file.".into()),
                    self.format_on_save,
                    cx.listener(|this: &mut SettingsView, state: &ToggleState, _, cx| {
                        this.format_on_save = state.selected();
                        cx.notify();
                    }),
                )
                .tooltip(Tooltip::text("Uses the formatter configured for this language.")),
            )
    }
}
```

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `ToggleStyle`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Custom`, `ElevationBased`, `Ghost` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SwitchColor`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Accent`, `Custom` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SwitchLabelPosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `End`, `Start` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ErasedEditor`

| Grup | API | Not |
|---|---|---|
| Trait metotları 1 | `as_any`, `clear`, `focus_handle`, `move_selection_to_end`, `render`, `set_masked`, `set_placeholder_text`, `set_text` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 2 | `subscribe`, `text` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `ErasedEditorEvent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Blurred`, `BufferEdited` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
