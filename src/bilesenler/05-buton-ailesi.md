# 5. Buton Ailesi

Buton ailesi, kullanıcı eylemlerini başlatan veya görünür bir UI durumunu
değiştiren bileşenlerden oluşur. `Button` metinli eylemler için,
`IconButton` yalnızca ikonlu kontroller için, `ButtonLike` ise özel içerikli
buton yüzeyleri için tasarlanmıştır. Ailenin diğer üyeleri de bu üç temel
yüzeyin üstüne ek davranış veya kompozisyon ekler; arka planda aynı buton
disiplinini paylaşırlar.

Hangi durumda hangisini seçeceğiniz için şu kısa ayrım yeterli olur:

- Açık metinli bir komut için `Button` ilk seçenektir.
- Toolbar, panel başlığı veya kompakt bir kontrol için `IconButton` daha
  uygun düşer.
- İçerik standart label/icon düzeninden ayrılıyorsa `ButtonLike` daha esnek bir
  yüzey sunar.
- Harici bir URL'i açan metin linki için `ButtonLink` vardır.
- Clipboard'a kopyalama davranışı için `CopyButton` doğrudan kullanılır.
- Bir ana eylem ve onun yanında açılır seçenekler gerekiyorsa `SplitButton`
  bu birleşik yapıyı kurar.
- Aynı grupta birbirini dışlayan seçimler için `ToggleButtonGroup` tercih
  edilir.

## Ortak buton trait'leri ve token'lar

Kaynak:

- Ortak trait ve token'lar:
  `../zed/crates/ui/src/components/button/button_like.rs`.
- Prelude: `Button`, `IconButton`, `SelectableButton`, `ButtonCommon`,
  `ButtonSize`, `ButtonStyle` otomatik gelir. `TintColor`, `ButtonLike`,
  `ButtonLink`, `CopyButton`, `SplitButton` ve toggle button tipleri ise
  ayrıca import edilir.

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

> **`key_binding` ve `key_binding_position` trait'te yer almaz.** Bu iki
> builder, `Button` struct'ının kendisine ait inherent (impl) metotlardır
> ve `IconButton`, `ButtonLike`, `SplitButton` üzerinde **çalışmaz**. Bu
> üç buton tipinde shortcut hint'i göstermek için elle bir `KeyBinding`
> widget'ı eklenir (bkz. Bölüm 14, `KeyBinding`).
> `KeybindingPosition` enum'unun değerleri (`Start`, `End` — varsayılan
> olarak `End`) ise yalnızca `Button::key_binding_position(...)` parametresi
> bağlamında anlam taşır.

Buton stilleri:

- `ButtonStyle::Subtle`: varsayılan; çoğu sıradan toolbar ve satır eylemi
  için yeterlidir.
- `ButtonStyle::Filled`: daha fazla vurgu isteyen birincil veya modal
  eylemler için.
- `ButtonStyle::Tinted(TintColor::Accent | Error | Warning | Success)`:
  seçili veya semantik bir vurgu gerektiren durumlar için.
- `ButtonStyle::Outlined` ve `OutlinedGhost`: ikincil ama sınırla
  ayrılması istenen eylemler için.
- `ButtonStyle::OutlinedCustom(hsla)`: özel bir border rengi gerektiğinde
  kullanılır.
- `ButtonStyle::Transparent`: yalnızca foreground ve hover davranışı
  istenen kompakt kontroller için uygundur.

Buton boyutları:

- `ButtonSize::Large`: 32px yükseklik.
- `ButtonSize::Medium`: 28px.
- `ButtonSize::Default`: 22px.
- `ButtonSize::Compact`: 18px.
- `ButtonSize::None`: 16px; link veya özel kompozisyonlarda tercih edilir.

Seçili görünümün nasıl ifade edileceği (`Tinted` mi, `selected_style` mı)
sahnenin niyetine göre değişir. Aşağıdaki tablo bu kararı özetler:

| Senaryo | Tercih | Neden |
| :-- | :-- | :-- |
| Buton seçili olmasa bile semantik bir renk taşıyor (örn. delete / approve) | `.style(ButtonStyle::Tinted(TintColor::...))` | Tinted, normal stilin yerine geçer; toggle olmadan da renk kalıcı kalır. |
| Buton normalde `Subtle` veya `Filled`; seçildiğinde vurgulu görünmeli | `.toggle_state(true).selected_style(ButtonStyle::Tinted(TintColor::Accent))` | `selected_style` yalnızca `toggle_state` true iken devreye girer; seçim kalktığında eski stile döner. |
| Seçili durumda da `Subtle` görünmeli ama icon/label rengi değişsin | `.toggle_state(true).selected_label_color(Color::Accent)` veya `IconButton::selected_icon_color(...)` | Buton arka planı korunur, yalnızca içerik rengi değişir. |
| Seçili durumda farklı bir ikon görünmeli | `IconButton::selected_icon(IconName::...)` | Toggle iken icon swap'i `selected_style` ile kombine edilebilir. |

`SelectableButton` trait'i `Button`, `IconButton` ve `ButtonLike` için
`selected_style(ButtonStyle)` yüzeyini ortak bir şekilde sunar; aynı görsel
kural birden fazla buton tipinde uygulanacaksa bu helper tek noktadan
kullanılabilir.

Dikkat edilecek noktalar:

- `ButtonCommon::tooltip(...)`, `Tooltip::text(...)` gibi
  `Fn(&mut Window, &mut App) -> AnyView` döndüren helper'larla birlikte
  kullanılır.
- `ButtonLike`, render sırasında click handler'ı içinde
  `cx.stop_propagation()` çağırır. Bu yüzden iç içe yerleştirilmiş
  tıklanabilir yüzeylerde event akışı buna göre düşünülmelidir.
- Disabled durumda olan butonlarda click ve right-click handler'ları
  uygulanmaz; sahnede görünseler bile etkileşime girmezler.

## Button

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/button.rs`
- Export: `ui::Button`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: `impl Component for Button`.

Ne zaman kullanılır:

- Metinle açıklanan kullanıcı eylemleri için: Save, Open, Retry, Apply,
  Cancel gibi komutlar.
- Modal footer, form eylemi, callout action veya satır içi komut
  ihtiyaçlarında.
- Metin ile birlikte start veya end icon ve bir keybinding hint'inin
  birlikte gösterilmesi gerektiğinde.

Ne zaman kullanılmaz:

- Yalnızca ikon kullanılacaksa `IconButton` daha doğru bir yüzeydir.
- İçerik özel slot'lardan oluşuyorsa `ButtonLike` esneklik sağlar.
- Görsel olarak harici bir web linki ifade edilecekse `ButtonLink` tercih
  edilir.

Temel API:

- Constructor: `Button::new(id, label)`.
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

- `RenderOnce` implement eder ve render sonunda arka planda bir
  `ButtonLike` üretir.
- `loading(true)` olduğunda `start_icon` yerine dönen
  `IconName::LoadCircle` ikonu çizilir.
- Disabled durumda label ve icon `Color::Disabled` ile çizilir.
- `truncate(true)` yalnızca dinamik ve taşma riski olan label'larda
  kullanılır; kaynak yorumunda statik label'lar için kullanılmaması
  gerektiği özellikle belirtilir.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: kaydetme, oluşturma
  ve JSON düzenleme eylemleri.
- `../zed/crates/recent_projects/src/recent_projects.rs`: Open, New Window,
  Delete gibi proje eylemleri.
- `../zed/crates/git_ui/src/git_panel.rs`: commit, selector ve split
  button parçaları.

Dikkat edilecek noktalar:

- Dinamik bir label için `truncate(true)` eklenirken, parent container'a da
  `min_w_0` gibi taşmayı sınırlayacak bir layout davranışının verilmesi
  gerekir; aksi halde truncate beklendiği gibi çalışmaz.
- Loading state yalnızca görsel bir spinner sağlar. Async işin hatasını view
  state'ine taşımak yine view tarafının sorumluluğudur.
- Tinted stiller için kullanılan `TintColor` prelude içinde gelmez;
  ayrıca import edilir.

## IconButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/icon_button.rs`
- Export: `ui::IconButton`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: `impl Component for IconButton`.

Ne zaman kullanılır:

- Kompakt toolbar eylemleri, panel kapatma, filtre, refresh, split veya
  menu trigger gibi yalnızca ikonla tanınan eylemler için.
- Seçili durum geldiğinde ikonun veya rengin değişmesi gereken senaryolar
  için.
- İkonun yanında küçük bir status dot gerektiğinde `.indicator(...)` ile
  birlikte kullanılır.

Ne zaman kullanılmaz:

- Eylem ikonla yeterince anlatılamıyorsa `Button` daha okunabilir bir
  tercih olur.
- İçerik ikon dışında özel bir layout gerektiriyorsa `ButtonLike` daha
  uygundur.

Temel API:

- Constructor: `IconButton::new(id, icon)`.
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

- `RenderOnce` implement eder ve render sonunda bir `ButtonLike` üretir.
- Seçili durumda `selected_icon` tanımlanmışsa o ikon çizilir.
- Seçili durumdayken `selected_style` da verilmişse, ikon rengi bu stile
  karşılık gelen semantik renkten türetilir. Aksi halde
  `selected_icon_color` veya `Color::Selected` kullanılır.
- `IconButtonShape::Square`, ikonun kare ölçüsünü kullanarak butonun
  width ve height değerlerini eşitler; yani buton bir kare gibi çizilir.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/sidebar/src/sidebar.rs`: sidebar ve terminal toolbar
  kontrolleri.
- `../zed/crates/search/src/search_bar.rs`: search control butonları.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: filtre ve exact
  match kontrolleri.

Dikkat edilecek noktalar:

- İkon-only bir kontrol çoğunlukla bir tooltip ister; aksi halde simgenin
  anlamı kullanıcı için kaybolur.
- `.visible_on_hover(group_name)` kullanıldığında, parent element üzerinde
  aynı isimle `.group(group_name)` çağrılmış olmalıdır; yoksa hover etkisi
  beklenen şekilde tetiklenmez.
- Seçili state'in yalnızca görsel olarak değiştirilmesi yeterli değildir.
  View state'i değişiyorsa handler içinde state'in güncellenmesi ve
  ardından `cx.notify()` çağrılması gerekir.

## ButtonLike

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/button_like.rs`
- Export: `ui::ButtonLike`
- Prelude: Hayır; `use ui::ButtonLike;` ayrıca eklenir.
- Preview: `impl Component for ButtonLike`.

Ne zaman kullanılır:

- Standart `Button` veya `IconButton` slot modelinin yetmediği özel
  yüzeylerde.
- Buton gibi davranan ama içinde birden fazla label, icon, badge veya özel
  bir layout bulunan satır ve trigger'lar için.
- Split button'ın sol veya sağ parçasını özel köşe yuvarlamalarıyla
  oluşturmak gerektiğinde.

Ne zaman kullanılmaz:

- Basit bir metinli eylem için `Button` zaten yeterlidir.
- Yalnızca bir ikon için `IconButton` daha tutarlı bir tercihtir.
- "Sadece biraz farklı spacing istedim" gibi bir nedenle kullanılması
  uygun değildir; tutarlılık açısından yüksek seviyeli bileşenler
  önceliklidir.

Temel API:

- Constructor: `ButtonLike::new(id)`.
- Grup constructor'ları: `new_rounded_left`, `new_rounded_right`,
  `new_rounded_all`.
- Style ve durum: `.style(...)`, `.size(...)`, `.disabled(...)`,
  `.toggle_state(...)`, `.selected_style(...)`, `.opacity(...)`,
  `.height(...)`.
- Davranış: `.on_click(...)`, `.on_right_click(...)`, `.tooltip(...)`,
  `.hoverable_tooltip(...)`, `.cursor_style(...)`, `.tab_index(...)`,
  `.layer(...)`, `.track_focus(...)`, `.visible_on_hover(...)`.
- Layout: `ParentElement` implement eder; `.child(...)` ve
  `.children(...)` kabul eder. Ayrıca `.width(...)` ve `.full_width()`
  builder'larını taşır.

Davranış:

- `RenderOnce` implement eder.
- Kendisine verilen child'ları bir h-flex buton yüzeyi içinde render eder.
- Style hesabı için enabled, hover, active, focus ve disabled durumlarının
  hepsi `ButtonStyle` üzerinden türetilir.
- Click handler disabled değilse çalışır ve event propagation
  durdurulur.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/recent_projects/src/sidebar_recent_projects.rs`: özel
  proje açma satırları.
- `../zed/crates/language_tools/src/highlights_tree_view.rs`: header
  yüzeyi.
- `../zed/crates/agent_ui/src/ui/mention_crease.rs`: özel mention yüzeyi.

Dikkat edilecek noktalar:

- `ButtonLike` unconstrained olduğu için tasarım sisteminin dışına çıkmak
  çok kolaydır; yalnızca gerçekten farklı bir slot ihtiyacı varsa devreye
  alınır. Aksi halde uygulamanın tutarlılığı zamanla erir.
- `new_rounded_left/right/all` constructor'ları split veya bitişik buton
  grupları için uygundur; tek bir buton için ise normal `new` çoğu zaman
  yeterli olur.

## ButtonLink

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/button_link.rs`
- Export: `ui::ButtonLink`
- Prelude: Hayır; `use ui::ButtonLink;` ayrıca eklenir.
- Preview: `impl Component for ButtonLink`.

Ne zaman kullanılır:

- Kullanıcıyı harici bir web sayfasına gönderen inline veya ayar metni
  içindeki linkler için.
- Bir linkin buton focus ve click davranışını taşıması, ama görsel olarak
  underline metin gibi görünmesi gerektiğinde.

Ne zaman kullanılmaz:

- Uygulama içi bir action için normal `Button` veya menu entry daha
  doğrudan bir çözümdür.
- Link metadata, tooltip veya rich content gerektiriyorsa özel bir
  `ButtonLike` kompozisyonuna geçmek gerekebilir.

Temel API:

- Constructor: `ButtonLink::new(label, link)`.
- Builder'lar: `.no_icon(bool)`, `.label_size(...)`, `.label_color(...)`.

Davranış:

- Render sırasında bir `ButtonLike::new(...)` kurar.
- Label otomatik olarak underline edilir.
- Varsayılan olarak `IconName::ArrowUpRight` end icon olarak gösterilir;
  bu yön oku link metnine "dışa açılır" niteliği verir.
- Click handler `cx.open_url(&self.link)` çağırarak bağlantıyı tarayıcıda
  açar.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/language_models/src/provider/open_ai.rs`.
- `../zed/crates/language_models/src/provider/anthropic.rs`.
- `../zed/crates/language_models/src/provider/google.rs`.

Dikkat edilecek noktalar:

- Harici bir bağlantıya gidileceğinin kullanıcıya açıkça belli edilmesi
  önemlidir. Varsayılan olan arrow-up-right ikonu bu yüzden değerlidir ve
  yalnızca link gerçekten inline bir metin gibi görünmesi gereken çok özel
  durumlarda `.no_icon(true)` ile kapatılır.

## CopyButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/copy_button.rs`
- Export: `ui::CopyButton`
- Prelude: Hayır; `use ui::CopyButton;` ayrıca eklenir.
- Preview: `impl Component for CopyButton`.

Ne zaman kullanılır:

- Sabit ya da render anında bilinen bir string'i clipboard'a kopyalamak
  için.
- SHA, path, komut, hata metni veya diagnostic içeriği gibi alanların
  yanında küçük bir copy ikonunun durması gerektiğinde.

Ne zaman kullanılmaz:

- Kopyalama işlemi async veya başarısız olabilen özel bir akış ise ve
  hatanın UI'da gösterilmesi gerekiyorsa, davranışı view state ile açıkça
  yöneten özel bir buton daha uygundur.

Temel API:

- Constructor: `CopyButton::new(id, message)`.
- Builder'lar: `.icon_size(...)`, `.disabled(bool)`, `.tooltip_label(...)`,
  `.visible_on_hover(...)`, `.custom_on_click(...)`.

Davranış:

- Render sırasında keyed bir `CopyButtonState` kullanır.
- Varsayılan click davranışı, verilen `message` string'ini clipboard'a
  yazar.
- Kopyalama sonrasında iki saniye boyunca `IconName::Check`,
  `Color::Success` ile birlikte "Copied!" tooltip'i gösterir.
- İki saniyelik state yenilemesi için
  `cx.background_executor().timer(...)` kullanan bir task detach edilir;
  yani süre dolduğunda görsel kendiliğinden eski hâline döner.
- `custom_on_click(...)` verildiğinde, varsayılan clipboard yazma davranışı
  yerine custom handler çalışır.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/markdown/src/markdown.rs`: code block copy davranışı.
- `../zed/crates/git_ui/src/commit_tooltip.rs`: commit SHA kopyalama.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: komut ve
  hata metni kopyalama.

Dikkat edilecek noktalar:

- `visible_on_hover(...)` için parent elementte aynı isimle `.group(...)`
  bulunmalıdır.
- `custom_on_click(...)`, varsayılan kopya davranışına ekleme yapmaz;
  onun yerine geçer. Custom handler hata üretebiliyorsa, hatanın view
  state'ine taşınması veya görünür biçimde loglanması gerekir; aksi halde
  kullanıcı kopya başarısız olduğunda fark etmez.

## SplitButton

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/split_button.rs`
- Export: `ui::SplitButton`
- Prelude: Hayır; `use ui::SplitButton;` ayrıca eklenir.
- Preview: Doğrudan `impl Component for SplitButton` yok.

Ne zaman kullanılır:

- Bir ana eylemin yanında aynı kontrol içinde ikinci bir trigger gerektiğinde.
  Örneğin Commit ile commit seçenekleri ya da Run ile run configuration
  menüsünün birlikte yer alması bu kalıba uyar.

Ne zaman kullanılmaz:

- İki eylem birbirine eşit önemdeyse ayrı `Button` veya bir toolbar grubu
  daha okunaklı bir yapı kurar.
- Sağ parça sadece dekoratifse split button bu yapıya gereksiz bir ağırlık
  katar.

Temel API:

- Constructor: `SplitButton::new(left, right)`.
- `left`: `ButtonLike` veya `IconButton` (`SplitButtonKind` üzerinden).
- `right`: `AnyElement`.
- Style: `SplitButtonStyle::Filled`, `Outlined`, `Transparent`.

Davranış:

- `RenderOnce` implement eder.
- Sol ve sağ parçayı tek bir h-flex kontrol olarak render eder; iki parça
  görsel olarak tek bir bütünmüş gibi görünür.
- `Filled` ve `Outlined` stilleri border ile divider çizer; ayrıca
  `Filled` stilinde surface background ve hafif bir shadow uygulanır.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/git_ui/src/git_panel.rs`: commit split button.
- `../zed/crates/git_ui/src/commit_modal.rs`: commit modal split button.
- `../zed/crates/debugger_ui/src/session/running/console.rs`: console
  action split button.

Dikkat edilecek noktalar:

- Sol ve sağ parça kendi click handler'larını taşımalıdır; `SplitButton`
  yalnızca görsel bir kompozisyon sağlar, eylemleri birleştirmez.
- Sağ parça bir popover veya menu trigger olacaksa, focus kapanma
  davranışı ilgili `PopoverMenu` ya da `ContextMenu` tarafında yönetilir;
  SplitButton bu sorumluluğu üstlenmez.

## ToggleButtonGroup

Kaynak:

- Tanım: `../zed/crates/ui/src/components/button/toggle_button.rs`
- Export: `ui::ToggleButtonGroup`, `ui::ToggleButtonSimple`,
  `ui::ToggleButtonWithIcon`, `ui::ToggleButtonGroupStyle`,
  `ui::ToggleButtonGroupSize`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for ToggleButtonGroup<...>`.

Ne zaman kullanılır:

- Aynı anda tek seçimin aktif olduğu segment kontrol veya mod seçicilerde.
- Görünüm modu, diff modu, filtre modu veya küçük bir ayar seçicisi gibi
  durumlar için.

Ne zaman kullanılmaz:

- Bağımsız aç/kapat kontrolleri için `Switch`, `Checkbox` veya tekil
  `IconButton::toggle_state(...)` daha uygun bir araçtır.
- Seçenek sayısı fazlaysa ya da dinamik olarak değişiyorsa, bir
  dropdown/menu çözümü daha ölçeklenebilir bir tercih olur.

Temel API:

- Button entry: `ToggleButtonSimple::new(label, on_click)`.
- İkonlu entry: `ToggleButtonWithIcon::new(label, icon, on_click)`.
- Entry builder'ları: `.selected(bool)`, `.tooltip(...)`.
- Group constructor'ları:
  `ToggleButtonGroup::single_row(group_name, [buttons; COLS])`,
  `ToggleButtonGroup::two_rows(group_name, first_row, second_row)`.
- Group builder'ları: `.style(ToggleButtonGroupStyle)`,
  `.size(ToggleButtonGroupSize)`, `.selected_index(usize)`,
  `.auto_width()`, `.label_size(LabelSize)`, `.tab_index(&mut isize)`,
  `.width(impl Into<DefiniteLength>)`, `.full_width()`.
- `ToggleButtonGroupStyle`: `Transparent`, `Filled`, `Outlined`.
- `ToggleButtonGroupSize`: `Default`, `Medium`, `Large`, `Custom(Rems)`.

Davranış:

- `RenderOnce` implement eder.
- Her entry bir `ButtonLike` olarak render edilir.
- `selected_index` veya entry'nin `.selected(true)` durumu, seçili görünümü
  birlikte tetikler.
- Seçili görünüm `ButtonStyle::Tinted(TintColor::Accent)` arka planı ile
  accent label/icon rengi kombinasyonuyla çizilir.
- `ToggleButtonPosition` grup içinde ilk, orta veya son segmentin köşe
  yuvarlamasını ifade eder. Public sabit değerleri vardır
  (`HORIZONTAL_FIRST`, `HORIZONTAL_MIDDLE`, `HORIZONTAL_LAST`), ancak
  alanlar private olduğu için normal kullanıcı kodu doğrudan segment
  state'i kuramaz; bunun yerine `ToggleButtonGroup` aracılığıyla
  kullanılması gerekir.
- `ButtonBuilder` trait'i public görünmesine rağmen private bir
  supertrait ile sealed durumdadır. Bu nedenle dış bir crate kendi entry
  tipini implement edemez; beklenen giriş noktaları `ToggleButtonSimple`
  ve `ToggleButtonWithIcon`'dur.
- Sealed supertrait kaynakta `private::ToggleButtonStyle` adıyla yer alır;
  crate dışından import edilemez ve tüketici API'si olarak düşünülmemiştir.
- `ButtonConfiguration` aynı şekilde iç bir taşıyıcı görevindedir; alanları
  private olduğu için tüketici kodu tarafından elle kurulmaz, yalnızca
  `ButtonBuilder` implementasyonlarının dönüş değeri olarak ortaya çıkar.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/git_ui/src/git_picker.rs`: git picker mod seçimi.
- Component preview: `../zed/crates/ui/src/components/button/toggle_button.rs`
  içindeki tek satır, ikonlu ve çok satırlı örnekler.

Dikkat edilecek noktalar:

- `selected_index` bir bounds kontrolü yapmaz; verilen indeksin entry
  sayısıyla uyumlu olması gerekir.
- `tab_index(&mut isize)` çağrısı, verilen değişkeni buton sayısı kadar
  artırır. Aynı form içinde sonraki focusable elemanların hesaba katılması
  gerekir; aksi halde tab sırası beklenmedik bir noktaya kayar.
- `ToggleButtonGroup` yalnızca görsel seçim davranışını kurar; asıl seçili
  state'in view struct'ı içinde bir alanda tutulması ve click handler'da
  güncellenmesi gerekir.

## Buton Kompozisyon Örnekleri

Aşağıdaki toolbar örneği `IconButton` ve `Button`'ı birlikte kullanır.
İlk buton sidebar'ı toggle eder; ikinci buton ise bir loading state'i ile
birlikte vurgulu bir kayıt eylemini temsil eder:

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

Bir ayar satırında ise maskelenmiş bir API anahtarı, onu kopyalayan bir
`CopyButton` ve provider belgelerine yönlendiren bir `ButtonLink` aynı
satırda yer alabilir:

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
