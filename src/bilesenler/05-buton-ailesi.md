# 5. Buton Ailesi

Buton ailesi, kullanıcı eylemlerini başlatan veya görünür bir UI durumunu toggle
eden bileşenlerden oluşur. `Button` metinli eylemler için, `IconButton` yalnızca
ikonlu kontroller için, `ButtonLike` ise özel içerikli buton yüzeyleri için
kullanılır. Diğer buton tipleri bu üç temel yüzeyin üstüne davranış veya
kompozisyon ekler.

Genel kural:

- Açık metinli bir komut için `Button`.
- Toolbar, panel başlığı veya kompakt kontrol için `IconButton`.
- İçeriği standart label/icon düzeninden farklıysa `ButtonLike`.
- Harici URL açan metin linki için `ButtonLink`.
- Clipboard kopyalama için `CopyButton`.
- Bir ana eylem ve yanında açılır seçenek gerekiyorsa `SplitButton`.
- Aynı grupta karşılıklı dışlayan seçimler için `ToggleButtonGroup`.

## Ortak buton trait'leri ve token'lar

Kaynak:

- Ortak trait ve token'lar:
  `../zed/crates/ui/src/components/button/button_like.rs`
- Prelude: `Button`, `IconButton`, `SelectableButton`, `ButtonCommon`,
  `ButtonSize`, `ButtonStyle` gelir. `TintColor`, `ButtonLike`,
  `ButtonLink`, `CopyButton`, `SplitButton` ve toggle button tipleri ayrıca
  import edilmelidir.

Ortak trait'ler:

- `ButtonCommon` (supertrait: `Clickable + Disableable`):
  `.id(&self) -> &ElementId`, `.style(ButtonStyle)`, `.size(ButtonSize)`,
  `.tooltip(Fn(...) -> AnyView)`, `.tab_index(impl Into<isize>)`,
  `.layer(ElevationIndex)`, `.track_focus(&FocusHandle)`.
- `Clickable`: `.on_click(handler)`, `.cursor_style(CursorStyle)`.
- `Disableable`: `.disabled(bool)`.
- `Toggleable`: `.toggle_state(bool)` (tek metot).
- `SelectableButton` (supertrait: `Toggleable`):
  `.selected_style(ButtonStyle)`.
- `FixedWidth`: `.width(impl Into<DefiniteLength>)`, `.full_width()`.
- `VisibleOnHover`: `.visible_on_hover(impl Into<SharedString>)`.

> **`key_binding` ve `key_binding_position` trait'te yoktur.** Bu iki
> builder `Button` struct'ının kendi inherent (impl) metotlarıdır;
> `IconButton`, `ButtonLike`, `SplitButton` üzerinde **çalışmaz**. Shortcut
> hint'i bu üçünde göstermek için manuel `KeyBinding` widget'ı eklenir
> (Bölüm 14/`KeyBinding`). `KeybindingPosition` enum'u (`Start`,
> `End` (Default)) yalnızca `Button::key_binding_position(...)` parametresi
> olarak anlam taşır.

Buton stilleri:

- `ButtonStyle::Subtle`: varsayılan, çoğu sıradan toolbar ve satır eylemi için.
- `ButtonStyle::Filled`: daha fazla vurgu isteyen birincil veya modal eylemleri.
- `ButtonStyle::Tinted(TintColor::Accent | Error | Warning | Success)`:
  seçili veya semantik vurgu isteyen durumlar.
- `ButtonStyle::Outlined` ve `OutlinedGhost`: ikincil ama sınırla ayrılması
  gereken eylemler.
- `ButtonStyle::OutlinedCustom(hsla)`: özel border rengi gerektiğinde.
- `ButtonStyle::Transparent`: yalnızca foreground/hover davranışı isteyen
  kompakt kontroller.

Buton boyutları:

- `ButtonSize::Large`: 32px yükseklik.
- `ButtonSize::Medium`: 28px.
- `ButtonSize::Default`: 22px.
- `ButtonSize::Compact`: 18px.
- `ButtonSize::None`: 16px; link veya özel kompozisyonlarda kullanılır.

Seçili görünüm seçimi (`Tinted` ya da `selected_style`):

| Senaryo | Tercih | Neden |
| :-- | :-- | :-- |
| Buton seçili değilken bile semantik renk taşıyor (örn. delete / approve) | `.style(ButtonStyle::Tinted(TintColor::...))` | Tinted, normal stilin yerine geçer; toggle olmadan da renk kalıcıdır. |
| Buton normalde `Subtle` veya `Filled`; seçildiğinde vurgulu görünmeli | `.toggle_state(true).selected_style(ButtonStyle::Tinted(TintColor::Accent))` | `selected_style`, yalnızca `toggle_state` true iken devreye girer; seçim kalkınca eski stile döner. |
| Seçili durumda da `Subtle` görünmeli ama icon/label rengi değişsin | `.toggle_state(true).selected_label_color(Color::Accent)` veya `IconButton::selected_icon_color(...)` | Buton arka planı korunur, sadece içerik rengi değişir. |
| Seçili durumda farklı bir ikon görünmeli | `IconButton::selected_icon(IconName::...)` | Toggle iken icon swap'i `selected_style` ile kombine edilebilir. |

`SelectableButton` trait'i `Button`, `IconButton` ve `ButtonLike` için
`selected_style(ButtonStyle)` yüzeyini birlikte sunar; ortak bir görsel kural
gerektiğinde butonlar üzerinde aynı helper'ı çağırabilirsiniz.

Dikkat edilecekler:

- `ButtonCommon::tooltip(...)`, `Tooltip::text(...)` gibi `Fn(&mut Window,
  &mut App) -> AnyView` döndüren helper'larla kullanılır.
- `ButtonLike` render sırasında click handler içinde `cx.stop_propagation()`
  çağırır. İç içe tıklanabilir yüzeylerde event akışını buna göre tasarlayın.
- Disabled butonlarda click ve right-click handler'ları uygulanmaz.

## Button

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/button.rs`
- Export: `ui::Button`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: `impl Component for Button`

Ne zaman kullanılır:

- Metinle açıklanan kullanıcı eylemleri için: Save, Open, Retry, Apply, Cancel.
- Modal footer, form eylemi, callout action veya satır içi komutlarda.
- Metin + start/end icon + keybinding kombinasyonu gerektiğinde.

Ne zaman kullanılmaz:

- Yalnızca ikon varsa `IconButton`.
- İçerik özel slotlardan oluşuyorsa `ButtonLike`.
- Dış web linki görünümü gerekiyorsa `ButtonLink`.

Temel API:

- Constructor: `Button::new(id, label)`
- İçerik builder'ları: `.start_icon(...)`, `.end_icon(...)`,
  `.selected_label(...)`, `.selected_label_color(...)`, `.color(...)`,
  `.label_size(...)`, `.alpha(...)`, `.key_binding(...)`,
  `.key_binding_position(...)`.
- Durum builder'ları: `.loading(bool)`, `.truncate(bool)`,
  `.toggle_state(bool)`, `.selected_style(...)`, `.disabled(bool)`.
- Ortak builder'lar: `.style(...)`, `.size(...)`, `.tooltip(...)`,
  `.tab_index(...)`, `.layer(...)`, `.track_focus(...)`, `.width(...)`,
  `.full_width()`, `.on_click(...)`, `.cursor_style(...)`.

Davranış:

- `RenderOnce` implement eder ve render sonunda `ButtonLike` üretir.
- `loading(true)` olduğunda `start_icon` yerine dönen `IconName::LoadCircle`
  gösterilir.
- Disabled durumunda label ve icon `Color::Disabled` ile çizilir.
- `truncate(true)` yalnızca dinamik ve taşma riski olan label'larda kullanılmalı;
  kaynak yorumunda statik label'lar için kullanılmaması gerektiği belirtilir.

Örnekler:

```rust
use ui::prelude::*;
use ui::{TintColor, Tooltip};

struct ToolbarState {
    saved: bool,
    running: bool,
}

impl Render for ToolbarState {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        h_flex()
            .gap_1()
            .child(
                Button::new("save-project", "Save")
                    .start_icon(Icon::new(IconName::Check))
                    .style(ButtonStyle::Filled)
                    .tooltip(Tooltip::text("Save project"))
                    .on_click(cx.listener(|this: &mut ToolbarState, _, _, cx| {
                        this.saved = true;
                        cx.notify();
                    })),
            )
            .child(
                Button::new("run-task", "Run")
                    .loading(self.running)
                    .disabled(self.running)
                    .style(ButtonStyle::Tinted(TintColor::Success)),
            )
    }
}
```

```rust
use ui::prelude::*;

fn render_branch_selector(branch: SharedString) -> impl IntoElement {
    Button::new("branch-selector", branch)
        .end_icon(Icon::new(IconName::ChevronDown).size(IconSize::Small))
        .truncate(true)
}
```

Zed içinden kullanım:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: kaydetme, oluşturma ve JSON
  düzenleme eylemleri.
- `../zed/crates/recent_projects/src/recent_projects.rs`: Open, New Window,
  Delete gibi proje eylemleri.
- `../zed/crates/git_ui/src/git_panel.rs`: commit, selector ve split button
  parçalarında.

Dikkat edilecekler:

- Dinamik label için `truncate(true)` eklerken parent container'a da `min_w_0`
  gibi taşmayı sınırlayan layout davranışı verin.
- Loading state sadece görsel spinner sağlar; async işin hatasını state'e taşıma
  sorumluluğu view tarafındadır.
- Tinted stiller için `TintColor` prelude'da değildir; ayrıca import edin.

## IconButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/icon_button.rs`
- Export: `ui::IconButton`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: `impl Component for IconButton`

Ne zaman kullanılır:

- Kompakt toolbar eylemleri, panel kapatma, filtre, refresh, split/menu trigger
  gibi sadece ikonla tanınan eylemler için.
- Seçili durum ikon veya renk değiştirmeli olduğunda.
- İkonun yanında küçük status dot gerekiyorsa `.indicator(...)`.

Ne zaman kullanılmaz:

- Eylem ikonla yeterince anlaşılmıyorsa `Button` kullanın.
- İçerik ikon dışında özel layout gerektiriyorsa `ButtonLike`.

Temel API:

- Constructor: `IconButton::new(id, icon)`
- İkon builder'ları: `.icon_size(...)`, `.icon_color(...)`,
  `.selected_icon(...)`, `.selected_icon_color(...)`, `.alpha(...)`.
- Şekil: `.shape(IconButtonShape::Square | Wide)`.
- Durum ve davranış: `.indicator(...)`, `.indicator_border_color(...)`,
  `.toggle_state(...)`, `.selected_style(...)`, `.disabled(...)`,
  `.on_click(...)`, `.on_right_click(...)`, `.visible_on_hover(...)`.
- Ortak builder'lar: `.style(...)`, `.size(...)`, `.tooltip(...)`,
  `.tab_index(...)`, `.layer(...)`, `.track_focus(...)`, `.width(...)`,
  `.full_width()`, `.cursor_style(...)`.

Davranış:

- `RenderOnce` implement eder ve `ButtonLike` üretir.
- Seçili durumda `selected_icon` varsa o ikon çizilir.
- Seçili ve `selected_style` verilmişse ikon rengi bu stile karşılık gelen
  semantik renkten türetilir; aksi halde `selected_icon_color` veya
  `Color::Selected` kullanılır.
- `IconButtonShape::Square`, icon size'ın kare ölçüsünü kullanarak butonun
  width/height değerini eşitler.

Örnek:

```rust
use ui::prelude::*;
use ui::{IconButtonShape, Tooltip};

struct SidebarToggle {
    open: bool,
}

impl Render for SidebarToggle {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        IconButton::new("toggle-sidebar", IconName::Menu)
            .shape(IconButtonShape::Square)
            .icon_size(IconSize::Small)
            .toggle_state(self.open)
            .selected_icon(IconName::Close)
            .tooltip(Tooltip::text("Toggle sidebar"))
            .on_click(cx.listener(|this: &mut SidebarToggle, _, _, cx| {
                this.open = !this.open;
                cx.notify();
            }))
    }
}
```

Zed içinden kullanım:

- `../zed/crates/sidebar/src/sidebar.rs`: sidebar ve terminal toolbar
  kontrolleri.
- `../zed/crates/search/src/search_bar.rs`: search control butonları.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: filtre ve exact match
  kontrolleri.

Dikkat edilecekler:

- İkon-only kontrol çoğu durumda tooltip gerektirir.
- `.visible_on_hover(group_name)` kullanıyorsanız parent elementte aynı
  `group(group_name)` adı olmalı.
- Seçili state'i yalnızca görsel olarak değiştirmek yetmez; view state'i
  değişiyorsa handler içinde state'i güncelleyip `cx.notify()` çağırın.

## ButtonLike

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/button_like.rs`
- Export: `ui::ButtonLike`
- Prelude: Hayır, `use ui::ButtonLike;` ekleyin.
- Preview: `impl Component for ButtonLike`

Ne zaman kullanılır:

- Standart `Button` veya `IconButton` slot modeli yetmediğinde.
- Buton gibi davranan ama içinde birden fazla label, icon, badge veya özel layout
  bulunan satır ve trigger'larda.
- Split button sol/sağ parçalarını özel yuvarlatma ile oluştururken.

Ne zaman kullanılmaz:

- Basit metinli eylem için `Button`.
- Sadece ikon için `IconButton`.
- Sırf spacing farklı diye kullanılmamalı; tutarlılık için yüksek seviyeli
  bileşenler önceliklidir.

Temel API:

- Constructor: `ButtonLike::new(id)`
- Grup constructor'ları: `new_rounded_left`, `new_rounded_right`,
  `new_rounded_all`.
- Style/durum: `.style(...)`, `.size(...)`, `.disabled(...)`,
  `.toggle_state(...)`, `.selected_style(...)`, `.opacity(...)`,
  `.height(...)`.
- Davranış: `.on_click(...)`, `.on_right_click(...)`, `.tooltip(...)`,
  `.hoverable_tooltip(...)`, `.cursor_style(...)`, `.tab_index(...)`,
  `.layer(...)`, `.track_focus(...)`, `.visible_on_hover(...)`.
- Layout: `ParentElement` implement ettiği için `.child(...)` ve `.children(...)`
  alır; ayrıca `.width(...)`, `.full_width()`.

Davranış:

- `RenderOnce` implement eder.
- Kendi child'larını h-flex buton yüzeyi içinde render eder.
- Style için enabled/hover/active/focus/disabled durumları `ButtonStyle`
  üzerinden hesaplanır.
- Click handler disabled değilse çalışır ve event propagation durdurulur.

Örnek:

```rust
use ui::prelude::*;
use ui::{ButtonLike, Tooltip};

fn render_account_trigger(name: SharedString, email: SharedString) -> impl IntoElement {
    ButtonLike::new("account-trigger")
        .style(ButtonStyle::Subtle)
        .tooltip(Tooltip::text("Switch account"))
        .child(
            h_flex()
                .min_w_0()
                .gap_2()
                .child(Icon::new(IconName::Person).size(IconSize::Small))
                .child(
                    v_flex()
                        .min_w_0()
                        .child(Label::new(name).truncate())
                        .child(Label::new(email).size(LabelSize::Small).color(Color::Muted).truncate()),
                ),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/recent_projects/src/sidebar_recent_projects.rs`: özel proje açma
  satırları.
- `../zed/crates/language_tools/src/highlights_tree_view.rs`: header yüzeyi.
- `../zed/crates/agent_ui/src/ui/mention_crease.rs`: özel mention yüzeyi.

Dikkat edilecekler:

- `ButtonLike` unconstrained olduğu için tasarım sistemi dışına çıkmak kolaydır;
  yalnızca gerçek slot ihtiyacı varsa kullanın.
- `new_rounded_left/right/all` split veya bitişik buton grupları için uygundur;
  tek butonlarda normal `new` çoğu zaman yeterlidir.

## ButtonLink

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/button_link.rs`
- Export: `ui::ButtonLink`
- Prelude: Hayır, `use ui::ButtonLink;` ekleyin.
- Preview: `impl Component for ButtonLink`

Ne zaman kullanılır:

- Kullanıcıyı harici bir web sayfasına gönderen inline veya ayar metni içi
  linklerde.
- Linkin buton focus/click davranışı taşıması ama görsel olarak underline metin
  gibi görünmesi gerektiğinde.

Ne zaman kullanılmaz:

- Uygulama içi action için normal `Button` veya menu entry kullanın.
- Link metadata, tooltip veya rich content gerektiriyorsa özel `ButtonLike`
  kompozisyonu gerekebilir.

Temel API:

- Constructor: `ButtonLink::new(label, link)`
- Builder'lar: `.no_icon(bool)`, `.label_size(...)`, `.label_color(...)`.

Davranış:

- Render sırasında `ButtonLike::new(...)` kurar.
- Label underline edilir.
- Varsayılan olarak `IconName::ArrowUpRight` end icon gösterir.
- Click handler `cx.open_url(&self.link)` çağırır.

Örnek:

```rust
use ui::prelude::*;
use ui::ButtonLink;

fn render_provider_link() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(Label::new("Create an API key in"))
        .child(
            ButtonLink::new("provider settings", "https://example.com/settings")
                .label_size(LabelSize::Small)
                .label_color(Color::Accent),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/language_models/src/provider/open_ai.rs`
- `../zed/crates/language_models/src/provider/anthropic.rs`
- `../zed/crates/language_models/src/provider/google.rs`

Dikkat edilecekler:

- Harici bağlantıyı kullanıcıya açıkça anlatın. Varsayılan arrow-up-right ikonu bu
  nedenle korunmalıdır; yalnızca gerçekten inline metin gibi görünmesi gerekiyorsa
  `.no_icon(true)` kullanın.

## CopyButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/copy_button.rs`
- Export: `ui::CopyButton`
- Prelude: Hayır, `use ui::CopyButton;` ekleyin.
- Preview: `impl Component for CopyButton`

Ne zaman kullanılır:

- Sabit veya render anında bilinen bir string'i clipboard'a kopyalamak için.
- SHA, path, komut, hata metni veya diagnostic içeriği yanında küçük copy ikonu
  gerektiğinde.

Ne zaman kullanılmaz:

- Kopyalama async/fallible özel bir işlem gerektiriyorsa ve hata UI'da
  gösterilecekse davranışı view state'iyle açık yöneten özel buton daha uygun
  olabilir.

Temel API:

- Constructor: `CopyButton::new(id, message)`
- Builder'lar: `.icon_size(...)`, `.disabled(bool)`, `.tooltip_label(...)`,
  `.visible_on_hover(...)`, `.custom_on_click(...)`.

Davranış:

- Render sırasında keyed `CopyButtonState` kullanır.
- Varsayılan click davranışı clipboard'a `message` yazar.
- Kopyaladıktan sonra iki saniye boyunca `IconName::Check`, `Color::Success` ve
  "Copied!" tooltip'i gösterir.
- İki saniyelik state yenilemesi için `cx.background_executor().timer(...)`
  kullanan bir task detach edilir.
- `custom_on_click(...)` verilirse varsayılan clipboard yazma davranışı yerine
  custom handler çalışır.

Örnek:

```rust
use ui::prelude::*;
use ui::CopyButton;

fn render_copyable_sha(short_sha: SharedString, full_sha: SharedString) -> impl IntoElement {
    h_flex()
        .group("sha-row")
        .gap_1()
        .child(Label::new(short_sha).size(LabelSize::Small).color(Color::Muted))
        .child(
            CopyButton::new("copy-commit-sha", full_sha)
                .tooltip_label("Copy commit SHA")
                .visible_on_hover("sha-row"),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/markdown/src/markdown.rs`: code block copy davranışı.
- `../zed/crates/git_ui/src/commit_tooltip.rs`: commit SHA kopyalama.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: komut ve hata
  metni kopyalama.

Dikkat edilecekler:

- `visible_on_hover(...)` için parent'ta aynı isimle `.group(...)` kullanılmalı.
- `custom_on_click(...)` default copy davranışını tamamlamaz, onun yerine geçer.
  Custom handler hata üretebiliyorsa hatayı view state'e taşımak veya görünür
  şekilde loglamak gerekir.

## SplitButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/split_button.rs`
- Export: `ui::SplitButton`
- Prelude: Hayır, `use ui::SplitButton;` ekleyin.
- Preview: Doğrudan `impl Component for SplitButton` yok.

Ne zaman kullanılır:

- Bir ana eylemin yanında aynı kontrol içinde ikinci bir trigger gerekiyorsa.
  Örneğin Commit + commit seçenekleri, Run + run configuration menüsü.

Ne zaman kullanılmaz:

- İki eylem eşit önemdeyse ayrı `Button` veya toolbar grubu daha okunur.
- Sağ parça yalnızca dekoratifse split button gereksizdir.

Temel API:

- Constructor: `SplitButton::new(left, right)`
- `left`: `ButtonLike` veya `IconButton` (`SplitButtonKind` üzerinden).
- `right`: `AnyElement`.
- Style: `SplitButtonStyle::Filled`, `Outlined`, `Transparent`.

Davranış:

- `RenderOnce` implement eder.
- Sol ve sağ parçayı tek bir h-flex kontrol olarak render eder.
- `Filled` ve `Outlined` stillerde border ve divider çizer; `Filled` ayrıca
  surface background ve küçük shadow uygular.

Örnek:

```rust
use ui::prelude::*;
use ui::{ButtonLike, SplitButton, SplitButtonStyle, Tooltip};

fn render_run_split_button() -> impl IntoElement {
    let left = ButtonLike::new_rounded_left("run-primary")
        .style(ButtonStyle::Filled)
        .child(
            h_flex()
                .gap_1()
                .child(Icon::new(IconName::PlayFilled).size(IconSize::Small))
                .child(Label::new("Run")),
        );

    let right = IconButton::new("run-options", IconName::ChevronDown)
        .style(ButtonStyle::Filled)
        .tooltip(Tooltip::text("Run options"))
        .into_any_element();

    SplitButton::new(left, right).style(SplitButtonStyle::Filled)
}
```

Zed içinden kullanım:

- `../zed/crates/git_ui/src/git_panel.rs`: commit split button.
- `../zed/crates/git_ui/src/commit_modal.rs`: commit modal split button.
- `../zed/crates/debugger_ui/src/session/running/console.rs`: console action
  split button.

Dikkat edilecekler:

- Sol ve sağ parçanın kendi click handler'ları olmalı; `SplitButton` yalnızca
  görsel kompozisyon sağlar.
- Sağ parçayı popover/menu trigger yapacaksanız focus kapanma davranışını ilgili
  `PopoverMenu` veya `ContextMenu` tarafında yönetin.

## ToggleButtonGroup

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/toggle_button.rs`
- Export: `ui::ToggleButtonGroup`, `ui::ToggleButtonSimple`,
  `ui::ToggleButtonWithIcon`, `ui::ToggleButtonGroupStyle`,
  `ui::ToggleButtonGroupSize`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ToggleButtonGroup<...>`

Ne zaman kullanılır:

- Aynı anda tek seçimin aktif olduğu segment kontrol veya mod seçici için.
- Görünüm modu, diff modu, filtre modu veya küçük ayar seçenekleri için.

Ne zaman kullanılmaz:

- Bağımsız aç/kapat kontrolleri için `Switch`, `Checkbox` veya tekil
  `IconButton::toggle_state(...)` daha uygun.
- Seçenek sayısı fazla veya dinamikse dropdown/menu daha ölçeklenebilir.

Temel API:

- Button entry: `ToggleButtonSimple::new(label, on_click)`
- İkonlu entry: `ToggleButtonWithIcon::new(label, icon, on_click)`
- Entry builder'ları: `.selected(bool)`, `.tooltip(...)`
- Group constructor'ları:
  `ToggleButtonGroup::single_row(group_name, [buttons; COLS])`,
  `ToggleButtonGroup::two_rows(group_name, first_row, second_row)`
- Group builder'ları: `.style(ToggleButtonGroupStyle)`,
  `.size(ToggleButtonGroupSize)`, `.selected_index(usize)`,
  `.auto_width()`, `.label_size(LabelSize)`, `.tab_index(&mut isize)`,
  `.width(impl Into<DefiniteLength>)`, `.full_width()`.
- `ToggleButtonGroupStyle`: `Transparent`, `Filled`, `Outlined`.
- `ToggleButtonGroupSize`: `Default`, `Medium`, `Large`, `Custom(Rems)`.

Davranış:

- `RenderOnce` implement eder.
- Her entry bir `ButtonLike` olarak render edilir.
- `selected_index` veya entry'nin `.selected(true)` durumu seçili görünümü
  tetikler.
- Seçili görünüm `ButtonStyle::Tinted(TintColor::Accent)` ve accent label/icon
  rengiyle çizilir.
- `ToggleButtonPosition`, grup içindeki ilk/orta/son segmentin köşe yuvarlamasını
  taşır; public const değerleri (`HORIZONTAL_FIRST`, `HORIZONTAL_MIDDLE`,
  `HORIZONTAL_LAST`) vardır, ancak alanları private olduğu için normal kullanıcı
  kodunda doğrudan segment state'i üretmek yerine `ToggleButtonGroup` kullanın.
- `ButtonBuilder` public ama private supertrait ile sealed durumdadır. Dış crate
  kendi entry tipini implement edemez; `ToggleButtonSimple` ve
  `ToggleButtonWithIcon` beklenen giriş noktalarıdır.
- Sealed supertrait kaynakta `private::ToggleButtonStyle` adını taşır; crate
  dışından import edilemez ve tüketici API'si değildir.
- `ButtonConfiguration` aynı iç taşıyıcı rolündedir; alanları private olduğu
  için tüketici kodu tarafından elle kurulmaz, yalnızca `ButtonBuilder`
  implementasyonlarının dönüş değeridir.

Örnek:

```rust
use ui::prelude::*;
use ui::{ToggleButtonGroup, ToggleButtonGroupStyle, ToggleButtonSimple};

struct DiffModePicker {
    selected: usize,
}

impl Render for DiffModePicker {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        ToggleButtonGroup::single_row(
            "diff-mode",
            [
                ToggleButtonSimple::new("Unified", cx.listener(
                    |this: &mut DiffModePicker, _, _, cx| {
                        this.selected = 0;
                        cx.notify();
                    },
                )),
                ToggleButtonSimple::new("Split", cx.listener(
                    |this: &mut DiffModePicker, _, _, cx| {
                        this.selected = 1;
                        cx.notify();
                    },
                )),
            ],
        )
        .selected_index(self.selected)
        .style(ToggleButtonGroupStyle::Outlined)
        .auto_width()
    }
}
```

Zed içinden kullanım:

- `../zed/crates/git_ui/src/git_picker.rs`: git picker mod seçimi.
- Component preview: `../zed/crates/ui/src/components/button/toggle_button.rs`
  içinde tek satır, ikonlu ve çok satırlı örnekler.

Dikkat edilecekler:

- `selected_index` bounds kontrolü yapmaz; entry sayısıyla uyumlu indeks verin.
- `tab_index(&mut isize)` verilen değişkeni button sayısı kadar artırır. Aynı
  form içinde sonraki focusable elemanları hesaba katın.
- `ToggleButtonGroup` sadece görsel seçimi kurar; gerçek selected state'i view
  struct alanında tutulmalı ve click handler'da güncellenmelidir.

## Buton Kompozisyon Örnekleri

Toolbar:

```rust
use ui::prelude::*;
use ui::{TintColor, Tooltip};

struct EditorToolbar {
    sidebar_open: bool,
    saving: bool,
}

impl Render for EditorToolbar {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        h_flex()
            .gap_1()
            .child(
                IconButton::new("toggle-sidebar", IconName::Menu)
                    .toggle_state(self.sidebar_open)
                    .tooltip(Tooltip::text("Toggle sidebar"))
                    .on_click(cx.listener(|this: &mut EditorToolbar, _, _, cx| {
                        this.sidebar_open = !this.sidebar_open;
                        cx.notify();
                    })),
            )
            .child(
                Button::new("save", "Save")
                    .start_icon(Icon::new(IconName::Check))
                    .loading(self.saving)
                    .style(ButtonStyle::Tinted(TintColor::Accent)),
            )
    }
}
```

Ayar satırı eylemleri:

```rust
use ui::prelude::*;
use ui::{ButtonLink, CopyButton};

fn render_api_key_actions(masked_key: SharedString, docs_url: &'static str) -> impl IntoElement {
    h_flex()
        .gap_2()
        .child(Label::new(masked_key.clone()).size(LabelSize::Small).color(Color::Muted))
        .child(CopyButton::new("copy-api-key", masked_key).tooltip_label("Copy key"))
        .child(ButtonLink::new("Provider docs", docs_url).label_size(LabelSize::Small))
}
```

