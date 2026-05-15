# 6. Form ve Seçim Bileşenleri

Bu bölüm, kullanıcıdan değer alan veya var olan bir ayarı değiştiren kontrolleri
anlatır. Butonlardan sonra gelir; çünkü checkbox, switch ve input alanları hem
ortak event modelini hem de önceki bölümlerdeki label/icon düzenini kullanır.

Genel seçim rehberi:

- Bağımsız çoklu seçim için `Checkbox`.
- Aç/kapat anlamı taşıyan tek ayar için `Switch`.
- Label, açıklama ve switch tek satır ayar olarak birlikte kullanılacaksa
  `SwitchField`.
- Tek satır metin girişi için `ui_input::InputField`.

Ortak kural, görsel durum ile uygulama durumunu birbirinden ayırmaktır: checkbox,
switch veya input yalnızca mevcut state'i render eder; gerçek değer view
state'inde veya uygulama modelinde tutulmalı ve handler içinde güncellenmelidir.

## Checkbox

Kaynak:

- Tanım: `../zed/crates/ui/src/components/toggle.rs`
- Export: `ui::Checkbox`, `ui::checkbox`, `ui::ToggleStyle`
- Prelude: Hayır, `Checkbox` ve `ToggleStyle` için ayrıca import edin.
- `ToggleState` prelude içinde gelir.
- Preview: `impl Component for Checkbox`

Ne zaman kullanılır:

- Bir listedeki her seçimin diğerlerinden bağımsız olduğu durumlarda.
- Çoklu izin, filtre, staged file, feature capability gibi birden fazla değerin
  aynı anda seçilebildiği yapılarda.
- Üst seviye seçim kısmi seçiliyse `ToggleState::Indeterminate` göstermek için.

Ne zaman kullanılmaz:

- Tek bir ayarı açıp kapatıyorsanız `Switch` veya `SwitchField` daha açık.
- Karşılıklı dışlayan seçenekler için `ToggleButtonGroup`, `DropdownMenu` veya
  menu entry kullanın.
- Sadece pasif durum göstergesi gerekiyorsa `Indicator`, `Icon` veya
  `.visualization_only(true)` ile etkileşimsiz checkbox düşünülmeli.

Temel API:

- Constructor: `Checkbox::new(id, checked: ToggleState)`
- Yardımcı constructor: `checkbox(id, toggle_state)`
- Builder'lar: `.disabled(bool)`, `.placeholder(bool)`, `.fill()`,
  `.visualization_only(bool)`, `.style(ToggleStyle)`, `.elevation(...)`,
  `.tooltip(...)`, `.label(...)`, `.label_size(...)`, `.label_color(...)`,
  `.on_click(...)`, `.on_click_ext(...)`.
- Statik ölçü helper'ı: `Checkbox::container_size() -> Pixels` checkbox kutusu
  için kullanılan sabit yan ölçüsünü (`px(20.0)`) döndürür; checkbox satırını
  diğer kontrollere hizalarken kullanın.
- `ToggleStyle`: `Ghost`, `ElevationBased(ElevationIndex)`, `Custom(Hsla)`.

Davranış:

- `RenderOnce` implement eder.
- `ToggleState::Selected` için `IconName::Check`, `ToggleState::Indeterminate`
  için `IconName::Dash` çizer.
- Click handler'a mevcut state değil, `self.toggle_state.inverse()` gönderilir.
- `ToggleState::Indeterminate.inverse()` sonucu `Selected` olur.
- `disabled(true)` click handler'ı devre dışı bırakır.
- `visualization_only(true)` pointer/hover davranışını kaldırır, ancak bileşeni
  disabled gibi soluk çizmez.

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

Zed içinden kullanım:

- `../zed/crates/workspace/src/security_modal.rs`: güvenlik modalındaki seçim.
- `../zed/crates/git_ui/src/git_panel.rs`: staged/unstaged seçimleri.
- `../zed/crates/language_tools/src/lsp_log_view.rs`: context menu içindeki
  custom checkbox entry.

Dikkat edilecekler:

- Handler'a gelen state hedef state'tir. `self.telemetry = state.selected()`
  gibi doğrudan uygulama state'ine yazın.
- Kısmi seçim gösteriyorsanız `ToggleState::from_any_and_all(...)` kullanmak,
  manuel koşullardan daha okunur.
- Checkbox label'ı varsa click alanı tüm satıra yayılır; iç içe tıklanabilir
  element koyacaksanız event propagation'ı açıkça düşünün.

## Switch

Kaynak:

- Tanım: `../zed/crates/ui/src/components/toggle.rs`
- Export: `ui::Switch`, `ui::switch`, `ui::SwitchColor`,
  `ui::SwitchLabelPosition`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Switch`

Ne zaman kullanılır:

- Bir ayarı anında açıp kapatan, iki karşıt durumlu kontrollerde.
- Label'a ihtiyaç var ama açıklama metni yoksa.
- Toolbar veya kompakt ayar satırlarında.

Ne zaman kullanılmaz:

- Açıklama, tooltip ve switch birlikte düzenli bir ayar satırı oluşturacaksa
  `SwitchField` daha uygundur.
- Çoklu seçimde checkbox semantiği daha doğrudur.

Temel API:

- Constructor: `Switch::new(id, state: ToggleState)`
- Yardımcı constructor: `switch(id, toggle_state)`
- Builder'lar: `.color(SwitchColor)`, `.disabled(bool)`, `.on_click(...)`,
  `.label(...)`, `.label_position(...)`, `.label_size(...)`,
  `.full_width(bool)`, `.key_binding(...)`, `.tab_index(...)`.
- `SwitchColor`: `Accent`, `Custom(Hsla)`.
- `SwitchLabelPosition`: `Start`, `End`.

Davranış:

- `ToggleState::Selected` açık, diğer state'ler kapalı görünür.
- Click handler'a `self.toggle_state.inverse()` gönderilir.
- `full_width(true)` switch ve label'ı satır içinde iki uca yayar.
- `tab_index(...)` verilirse switch focus-visible border ve klavye focus sırası
  alır.

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

Dikkat edilecekler:

- `ToggleState::Indeterminate` switch için ayrı bir görsel ara durum üretmez;
  switch açık/kapalı anlamı taşıdığı için state'i genellikle `bool` üzerinden
  üretin.
- Disabled switch dış container'da pointer cursor'ı tamamen kaldırmaz; kullanıcıya
  neden disabled olduğunu göstermek gerekiyorsa satır açıklaması veya tooltip
  ekleyin.

## SwitchField

Kaynak:

- Tanım: `../zed/crates/ui/src/components/toggle.rs`
- Export: `ui::SwitchField`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for SwitchField`

Ne zaman kullanılır:

- Ayar ekranlarında label, açıklama ve switch birlikte gösterilecekse.
- Tek satırda sağda switch, solda metinsel bağlam isteyen seçeneklerde.
- Tooltip ikonuyla ek bilgi verilmesi gereken ayarlarda.

Ne zaman kullanılmaz:

- Yalnızca kompakt bir switch gerekiyorsa `Switch`.
- Birden fazla bağımsız seçim varsa `Checkbox` listesi.

Temel API:

- Constructor:
  `SwitchField::new(id, label, description, toggle_state, on_click)`
- `label`: `Option<impl Into<SharedString>>`
- `description`: `Option<SharedString>`
- `toggle_state`: `impl Into<ToggleState>`
- Builder'lar: `.description(...)`, `.disabled(bool)`, `.color(...)`,
  `.tooltip(...)`, `.tab_index(...)`.

Davranış:

- `RenderOnce` implement eder.
- Container tıklaması ve iç switch tıklaması aynı `on_click` callback'ini hedef
  state ile çağırır.
- Tooltip verildiğinde label yanında `IconButton::new("tooltip_button",
  IconName::Info)` render edilir. Bu ikonun boş click handler'ı vardır; bilgi
  ikonuna tıklamak switch'i toggle etmez.
- Açıklama varsa muted label olarak çizilir.

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

Dikkat edilecekler:

- `SwitchField` tam genişlikte ayar satırı davranışı verir. Toolbar gibi dar
  alanlarda doğrudan `Switch` kullanın.
- Tooltip sadece label varsa görsel ikonla birlikte çizilir; labelsız kullanımda
  tooltip beklemeyin.

Ortak `ToggleState` modeli:

| Variant | Anlam | Not |
| :-- | :-- | :-- |
| `Unselected` | Kapalı / seçili değil | `Default` variant'tır; `false.into()` bu değeri üretir |
| `Indeterminate` | Kısmi seçim | Checkbox'ta görsel ara durum verir; switch'te ayrı görsel ara durum beklemeyin |
| `Selected` | Açık / seçili | `true.into()` bu değeri üretir |

Yardımcılar: `.inverse()`, `ToggleState::from_any_and_all(any_checked,
all_checked)`, `.selected()`, `From<bool>`.

## InputField (`ui_input`)

Kaynak:

- Tanım: `../zed/crates/ui_input/src/input_field.rs`
- Export: `ui_input::InputField`
- Prelude: Hayır, `use ui_input::InputField;` ekleyin.
- Preview: `impl Component for InputField`

Ne zaman kullanılır:

- Search input, API key alanı, ayar formu veya modal içi tek satır metin girişi
  gerektiğinde.
- Editor tabanlı gerçek text input davranışı, focus handle, placeholder, masked
  değer ve tab order desteği isteniyorsa.

Ne zaman kullanılmaz:

- Sadece statik metin göstermek için `Label`.
- Çok satırlı veya editor özellikli içerik için doğrudan editor tabanlı view.
- `crates/ui` içine bağımlılık eklerken; `ui_input`, editor'a bağımlı olduğu için
  ayrı crate'te tutulur.

Temel API:

- Constructor: `InputField::new(window, cx, placeholder_text)`
- Builder'lar: `.start_icon(IconName)`, `.label(...)`, `.label_size(...)`,
  `.label_min_width(...)`, `.tab_index(...)`, `.tab_stop(bool)`,
  `.masked(bool)`.
- Okuma/yazma: `.text(cx)`, `.is_empty(cx)`, `.clear(window, cx)`,
  `.set_text(text, window, cx)`, `.set_masked(masked, window, cx)`.
- Düşük seviye erişim: `.editor() -> &Arc<dyn ErasedEditor>`.

Davranış:

- `Render` ve `Focusable` implement eder; genellikle `Entity<InputField>` olarak
  view state'inde tutulur.
- `InputField::new(...)`, `ui_input::ERASED_EDITOR_FACTORY` kurulmuş olmasını
  bekler. Zed runtime bunu editor entegrasyonu sırasında hazırlar.
- `.masked(true)` verilirse sağda show/hide `IconButton` render edilir ve click
  ile mask state'i güncellenir.
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

Zed içinden kullanım:

- `../zed/crates/language_models/src/provider/open_ai.rs`: API key input'u.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: context ve action input'ları.
- `../zed/crates/component_preview/src/component_preview.rs`: component arama
  filter input'u.

Düşük seviye yüzey — `ErasedEditor`:

`.editor()` ile elde edilen `Arc<dyn ErasedEditor>`, gerçek `Editor` view'ına
type-erased bir kapıdır. Bu sayede `ui_input` crate'i `editor` crate'ine
bağımlı değil; editor entegrasyonu `ERASED_EDITOR_FACTORY: OnceLock<...>`
ile uygulama başlangıcında bir kez kurulur:

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
| `BufferEdited` | Kullanıcı metni değiştirdiğinde (yazma, silme, paste, vs.) |
| `Blurred` | Editor focus'u kaybettiğinde |

Değer değişimini takip etmek için view içinde subscription kurun ve
saklayın:

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

> **`_input_subscription` saklamak şart.** `Subscription` drop edilirse
> callback ölür ve `BufferEdited` event'i artık tetiklenmez. Aynı kural
> diğer GPUI subscription'ları için de geçerli.

Dikkat edilecekler:

- `InputField` `RenderOnce` değildir; her render'da yeniden yaratmayın, entity
  olarak saklayın.
- Text değerini `field.read(cx).text(cx)` ile okuyun; değer değişimine tepki
  vermeniz gerekiyorsa yukarıdaki `subscribe` örneğini izleyin ve dönen
  `Subscription`'ı view alanında saklayın.
- `ERASED_EDITOR_FACTORY` kurulmadan `InputField::new` çağrılırsa panic eder;
  editor crate init'i uygulama başlangıcında çalışmalı.
- `label_min_width(...)` adı tarihsel olarak label dese de kaynakta input
  container'ın `min_width` değerini ayarlar.

## Form Kompozisyon Örnekleri

Ayar satırı:

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

