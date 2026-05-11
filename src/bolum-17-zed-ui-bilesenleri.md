# 17. Zed UI Bileşenleri

---

## 17.1. Zed UI Prelude, Style Extension Trait'leri ve Component Sözleşmesi

Zed UI katmanı (`crates/ui`) GPUI çekirdeğinin üstüne kendi tasarım sistemini, yardımcı trait'lerini ve hazır bileşenlerini ekler. Tipik bir Zed dosyası `gpui::prelude::*` yerine `ui::prelude::*` import eder; bu prelude hem GPUI'nin temel trait/tiplerini hem de Zed'e özgü helper'ları (semantic renkler, layout shortcut'ları, typography, button/label sözleşmeleri) tek seferde getirir. Bu yapı, her dosyada onlarca ayrı import yazmak yerine standart bir başlangıç noktası sağlar ve tasarım kararlarının tutarlı kalmasına yardımcı olur.

`ui::prelude::*` içinde önemli export'lar:

- `gpui::prelude::*` üzerinden gelen trait/tipler: `AppContext` (anonim),
  `BorrowAppContext`, `Context`, `Element`, `InteractiveElement`, `IntoElement`,
  `ParentElement`, `Refineable`, `Render`, `RenderOnce`, `StatefulInteractiveElement`,
  `Styled`, `StyledImage`, `TaskExt` (anonim), `VisualContext`, `FluentBuilder`.
- `gpui` doğrudan tipleri: `App`, `Window`, `Div`, `AnyElement`, `ElementId`,
  `SharedString`, `Pixels`, `Rems`, `AbsoluteLength`, `DefiniteLength`,
  `div`, `px`, `rems`, `relative`.
- Zed layout helper'ları: `h_flex()`, `v_flex()`, `h_group()`, `h_group_sm()`,
  `h_group_lg()`, `h_group_xl()`, `v_group()`, `v_group_sm()`, `v_group_lg()`,
  `v_group_xl()`.
- Theme erişimi: `theme::ActiveTheme`, `Color`, `PlatformStyle`, `Severity`.
- Stil/spacing yardımcıları: `StyledTypography`, `TextSize`, `DynamicSpacing`,
  `rems_from_px`, `vh`, `vw`.
- Animasyon: `AnimationDirection`, `AnimationDuration`, `DefaultAnimations`.
- Component sistemi: `Component`, `ComponentScope`, `RegisterComponent`,
  `example_group`, `example_group_with_title`, `single_example`.
- Component'ler: `Button`, `ButtonCommon`, `ButtonSize`, `ButtonStyle`,
  `IconButton`, `SelectableButton`, `Headline`, `HeadlineSize`, `Icon`,
  `IconName`, `IconPosition`, `IconSize`, `Label`, `LabelCommon`, `LabelSize`,
  `LineHeightStyle`, `LoadingLabel`.
- Trait'ler (`crate::traits::*`): `StyledExt`, `Clickable`, `Disableable`,
  `Toggleable`, `VisibleOnHover`, `FixedWidth`.

`ButtonLike` prelude'da değildir; `ui::ButtonLike` yoluyla doğrudan import edilir.
Yine prelude'da olmayanlar (örn. `Tooltip`, `ContextMenu`, `Popover`,
`PopoverMenu`, `Modal`, `RightClickMenu`) doğrudan `ui::` namespace'inden
çağrılır.

Style extension'ları:

- `StyledExt::h_flex()` = `flex().flex_row().items_center()`.
- `StyledExt::v_flex()` = `flex().flex_col()`.
- `elevation_1/2/3(cx)` ve `*_borderless(cx)` Zed elevation katmanlarını uygular:
  `Surface`, `ElevatedSurface`, `ModalSurface`. Popover/modal gibi katmanlarda
  elle shadow/border üretmek yerine bunları kullan.
- `border_primary(cx)` ve `border_muted(cx)` theme border renklerini bağlar.
- `debug_bg_red/green/blue/yellow/cyan/magenta()` yalnızca geliştirme sırasında
  layout teşhisi içindir.

Tipografi:

- `StyledTypography::font_ui(cx)` ve `font_buffer(cx)` theme settings'teki UI ve
  buffer font family değerlerini bağlar.
- `text_ui_lg(cx)`, `text_ui(cx)`, `text_ui_sm(cx)`, `text_ui_xs(cx)` UI scale'i
  dikkate alan semantic metin boyutlarıdır.
- `text_buffer(cx)` buffer font size'a uyar; editor içeriğiyle aynı boyda
  görünmesi gereken metinde kullanılır.
- `TextSize::{Large, Default, Small, XSmall, Ui, Editor}` hem `.rems(cx)` hem
  `.pixels(cx)` verir. Hardcoded `px(14.)` yerine semantic boyut tercih edilir.

Semantic renk ve elevation:

- `Color` theme'e göre HSLA'ya çevrilen semantic enum'dur:
  `Default`, `Muted`, `Hidden`, `Disabled`, `Placeholder`, `Accent`, `Info`,
  `Success`, `Warning`, `Error`, VCS durum renkleri ve `Custom(Hsla)`.
- `TintColor::{Accent, Error, Warning, Success}` button tint stillerine kaynaklık
  eder ve `Color`'a dönüştürülebilir.
- `ElevationIndex::{Background, Surface, EditorSurface, ElevatedSurface,
  ModalSurface}` shadow, background ve "bu elevation üzerinde okunacak renk"
  kararlarını toplar.

Button/label ortak sözleşmeleri:

- `Clickable`: `.on_click(...)` ve `.cursor_style(...)`.
- `Disableable`: `.disabled(bool)`.
- `Toggleable`: `.toggle_state(bool)`; `ToggleState::{Unselected,
  Indeterminate, Selected}` üç durumlu checkbox/tree selection için.
- `SelectableButton`: selected durumda farklı `ButtonStyle` tanımlar.
- `ButtonCommon`: `.style(ButtonStyle)`, `.size(ButtonSize)`, `.tooltip(...)`,
  `.tab_index(...)`, `.layer(ElevationIndex)`, `.track_focus(...)`.
- `ButtonStyle::{Filled, Tinted(TintColor), Outlined, OutlinedGhost,
  OutlinedCustom(Hsla), Subtle, Transparent}`.
- `ButtonSize::{Large, Medium, Default, Compact, None}`.
- `LabelCommon`: `.size(LabelSize)`, `.weight(FontWeight)`,
  `.line_height_style(LineHeightStyle)`, `.color(Color)`, `.truncate()`,
  `.single_line()`, `.buffer_font(cx)`, `.inline_code(cx)`.

Diğer UI yardımcıları:

- `VisibleOnHover::visible_on_hover(group)` elementi başlangıçta invisible yapar,
  belirtilen group hover olduğunda visible'a çevirir. `""` global group'tur.
- `WithRemSize::new(px(...))` child ağacında `window.with_rem_size` uygular;
  özel preview veya küçük component ölçeklemesi için kullanılır.
- `Scrollbars::new(ScrollAxes::Vertical)` ve `.vertical_scrollbar_for(handle,
  window, cx)` Zed'in custom scrollbar katmanıdır. `ShowScrollbar::{Auto,
  System, Always, Never}` ayarını `ScrollbarVisibility` global'i üzerinden
  platform auto-hide davranışıyla birleştirir.

### Tuzaklar

- **Uygulama UI'ında doğrudan `cx.theme().colors().text_*` yazılabilir;** ancak yeniden kullanılabilir component'lerde `Color` / `TintColor` semantic katmanı daha dayanıklıdır. Tema değiştiğinde semantic kullanan kod otomatik uyum sağlar.
- **`ButtonLike` güçlü ama serbest bir primitive'dir;** hazır `Button`, `IconButton`, `ToggleButton` yeterliyse onlar tercih edilir. Aksi halde tutarsız buton görünümleri ortaya çıkar.
- **`VisibleOnHover` parent'ta aynı isimli hover group kurulmamışsa hiç görünmez.** Group adının her iki tarafta da aynı yazıldığından emin olmak gerekir; aksi halde element sessizce kaybolur.

## 17.2. Zed UI Bileşen Envanteri

Zed UI katmanı, GPUI'nin yerleşik elementlerinin (`div`, `svg`, `img` vb.) üzerine onlarca hazır bileşen sunar. Yeni bir UI yazılırken **önce bu envanter taranır**; aynı işi yapan bir bileşen varsa sıfırdan element ağacı kurmak yerine onu kullanmak hem görsel tutarlılık hem de focus/dismiss/aksesibilite gibi davranışların hazır gelmesi anlamına gelir. Aşağıdaki liste bileşenleri amaca göre gruplandırır.

- Metin: `Label`, `Headline`, `HighlightedLabel`, `LoadingLabel`, `SpinnerLabel`
- Buton: `Button`, `IconButton`, `SelectableButton`, `ButtonLike`,
  `ButtonLink`, `CopyButton`, `SplitButton`, `ToggleButton`
- İkon: `Icon`, `DecoratedIcon`, `IconDecoration`, `IconName`, `IconSize`
- Form/toggle: `Checkbox`, `Switch`, `SwitchField`, `DropdownMenu`
- Menü/popup: `ContextMenu`, `RightClickMenu`, `Popover`, `PopoverMenu`, `Tooltip`
- Liste/tree: `List`, `ListItem`, `ListHeader`, `ListSubHeader`, `ListSeparator`,
  `TreeViewItem`, `StickyItems`, `IndentGuides`
- Tab: `Tab`, `TabBar`
- Layout yardımcıları: `h_flex`, `v_flex`, `h_group*`, `v_group*`, `Stack`,
  `Group`, `Divider`
- Veri: `Table`, `TableInteractionState`, `RedistributableColumnsState`,
  `render_table_row`, `render_table_header`
- Feedback: `Banner`, `Callout`, `Modal`, `AlertModal`, `AnnouncementToast`,
  `Notification`, `CountBadge`, `Indicator`, `ProgressBar`, `CircularProgress`
- Diğer: `Avatar`, `Facepile`, `Chip`, `DiffStat`, `Disclosure`,
  `GradientFade`, `Image`, `KeyBinding`, `KeybindingHint`, `Navigable`,
  `RedistributableColumnsState` + `bind_redistributable_columns()` /
  `render_redistributable_columns_resize_handles()` (yeniden boyutlanabilir
  tablo başlıkları için state + helper fonksiyon çifti)
- AI/collab özel: `AiSettingItem`, `AgentSetupButton`, `ThreadItem`,
  `ConfiguredApiCard`, `CollabNotification`, `UpdateButton`

### Genel kural

- Zed içinde ham `div().on_click(...)` ile buton üretmeden önce `Button` veya `IconButton` kullanılır; tasarım sistemi tutarlılığı bu seçimle korunur.
- Sadece görsel/tek seferlik parça için `RenderOnce`, stateful view için `Render` tercih edilir (bkz. 4.1).
- Listeler büyükse `list` veya `uniform_list` ile sanallaştırılır (bkz. 10.2).
- Tooltip, popover ve context menu için hazır bileşenler kullanılır; focus/blur kapanma davranışı bu bileşenlerde önceden çözülmüştür (bkz. 17.3).

## 17.3. ManagedView, DismissEvent, Modal, Popover ve Tooltip Yaşam Döngüsü

Modal, popover, context menu gibi UI parçaları kendi başına yaşamaz; bir başka view tarafından açılır, kullanıcı bir aksiyon yaptığında veya dışına tıkladığında kapatılır. Bu yaşam döngüsünü düzenlemek için GPUI **`ManagedView`** trait'ini kullanır: yönetilen view kapatılmak istediğinde `DismissEvent` emit eder; yöneten view bu event'i dinler ve view'ı kaldırır. Aynı zincir tooltip ve popover için de geçerlidir.

```rust
pub trait ManagedView: Focusable + EventEmitter<DismissEvent> + Render {}
```

```rust
pub trait ManagedView: Focusable + EventEmitter<DismissEvent> + Render {}
```

Bir modal, popover veya context menu kapatılmak istediğinde kendi entity context'inden `DismissEvent` yayar:

```rust
impl EventEmitter<DismissEvent> for MyModal {}

fn dismiss(&mut self, cx: &mut Context<Self>) {
    cx.emit(DismissEvent);
}
```

### Zed/UI tarafındaki kullanıcılar

- **`ContextMenu`** — `ManagedView` implementasyonu vardır; komut listesi ve separator yönetimi için kullanılır.
- **`PopoverMenu<M: ManagedView>`** — Anchor element'ten odaklanabilir popover açar; `PopoverMenuHandle<M>` dışarıdan toggle/close kontrolü için tutulabilir.
- **`right_click_menu(id)`** — Context menu'yu mouse event akışına bağlayan UI helper'ı.
- **Workspace modal layer** — `ModalView` / `ToastView` katmanları `DismissEvent` aboneliği üzerinden kapanmayı yönetir; `on_before_dismiss` varsa kapanmadan önce çağrılır (kullanıcıya "kaydedilmedi" sorusu için).

### Tooltip

- **Element fluent API'leri**: `.tooltip(|window, cx| AnyView)` ve `.hoverable_tooltip(|window, cx| AnyView)`.
- Imperative `Interactivity` API aynı callback imzasını kullanır.
- **`hoverable_tooltip` ile `tooltip` farkı**: `hoverable_tooltip` mouse tooltip içine geçince kapanmaz (tooltip içeriğinin tıklanabilir veya scroll edilebilir olabileceği durumlar için); normal `tooltip` ise pointer owner element'ten ayrılınca release edilir.

### Tuzaklar

- **Modal/popover view `Focusable` sağlamazsa klavye ve dismiss davranışı eksik kalır.** Trait bound bütünüyle karşılanmalıdır; aksi halde focus zincirinde kopukluk oluşur.
- **`DismissEvent` emit eden entity'nin subscription'ı saklanmazsa** layer kapanma callback'i düşer ve view sessizce açık kalır.
- **Aynı element üzerinde birden fazla tooltip tanımlamak debug assert'e yol açar.** Tek bir elemana tek tooltip kuralı geçerlidir.


---

