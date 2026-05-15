# Bölüm XIII — Zed UI Bileşenleri

---

## Zed UI Prelude, Style Extension Trait'leri ve Component Sözleşmesi


Zed uygulama kodu çoğu zaman doğrudan `gpui::prelude::*` değil
`ui::prelude::*` import eder. Bu prelude GPUI çekirdeğini yeniden export eder ve
Zed'e özgü component/style katmanını ekler.

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

`CommonAnimationExt` de crate kökünden (`ui::CommonAnimationExt`) explicit
import edilir; `with_rotate_animation(duration_secs)` ve
`with_keyed_rotate_animation(id, duration_secs)` sağlar.

Animasyon yüzeyi:

- `AnimationDuration::{Instant, Fast, Slow}` sırasıyla 50/150/300 ms döner;
  `.duration()` veya `Into<Duration>` ile GPUI animation'a verilir.
- `AnimationDirection::{FromBottom, FromLeft, FromRight, FromTop}` giriş
  animasyon yönüdür.
- `DefaultAnimations`: `.animate_in(direction, fade)`,
  `.animate_in_from_bottom(fade)`, `.animate_in_from_left(fade)`,
  `.animate_in_from_right(fade)`, `.animate_in_from_top(fade)`.
  Blanket impl `Styled + Element` olan elementler içindir.
- `CommonAnimationExt` rotasyon helper'ı yalnız `Transformable` implement eden
  elementlerde çalışır; Zed UI tarafında bu pratikte `Icon` ve `Vector`
  demektir.
- **Animasyon wrapper transparency:** `popover_menu.rs:16` ve `:32`,
  `impl<T: Clickable> Clickable for gpui::AnimationElement<T>` ve
  `impl<T: Toggleable> Toggleable for gpui::AnimationElement<T>` impl'leri
  taşır. Bu yüzden bir element `.with_animation(...)` veya
  `.animate_in_from_bottom(...)` ile sarıldığında `Clickable`/`Toggleable`
  trait yüzeyini kaybetmez — `PopoverMenu::trigger(...)` animasyonlu trigger
  da kabul eder, çünkü `PopoverTrigger: IntoElement + Clickable + Toggleable
  + 'static` supertrait listesini blanket impl ile karşılar
  (`impl<T: IntoElement + Clickable + Toggleable + 'static> PopoverTrigger for T {}`).

Public export modeli:

- `crates/ui/src/ui.rs` iç modülleri (`components`, `styles`, `traits`) private
  tutar ve `pub use components::*`, `pub use prelude::*`,
  `pub use styles::*`, `pub use traits::animation_ext::*` ile public yüzeyi
  düzleştirir. Bu yüzden tüketici kodunda `ui::Button`, `ui::Color`,
  `ui::Clickable`, `ui::theme_is_transparent` gibi yollar kullanılır;
  `ui::components::...` veya `ui::styles::...` public API yolu değildir.
- Bilinçli public nested modüller (`pub mod`) kendi namespace'iyle kullanılır:
  - `ui::scrollbars::{ShowScrollbar, ScrollbarVisibility, ScrollbarAutoHide}` —
    scrollbar görünürlük settings yüzeyi.
  - `ui::animation::{AnimationDirection, AnimationDuration, DefaultAnimations}`
    — prelude'da da olan animasyon helper modülü; `workspace::toast_layer`
    gibi kodlar explicit `ui::animation::DefaultAnimations` import edebilir.
  - `ui::table_row::{TableRow, IntoTableRow}` — `data_table.rs` içinden public
    açılan kolon sayısı doğrulamalı tablo satırı modülü.
  - `ui::utils::*` — non-styling yardımcılar (aşağıdaki utils başlığı).
  - `ui::component_prelude::*` — component yazarken kullanılan derive ve
    registry yüzeyi: `Component`, `ComponentId`, `ComponentScope`,
    `ComponentStatus`, `example_group`, `example_group_with_title`,
    `single_example`, `RegisterComponent` (ui_macros), `Documented`
    (documented crate). Yeni component yazarken `use ui::component_prelude::*;`
    `ui::prelude::*`'a ek olarak import edilir.
- `ui::prelude::*` sık kullanılan küçük yüzeydir; tüm component envanteri
  değildir. `ButtonLike`, `ContextMenu`, `Tooltip`, `Modal`, `Table`,
  `Vector`, `ThreadItem` gibi tipler crate kökünden explicit import edilir.

Style extension'ları:

- `StyledExt::h_flex()` = `flex().flex_row().items_center()`.
- `StyledExt::v_flex()` = `flex().flex_col()`.
- `elevation_1/2/3(cx)` ve `*_borderless(cx)` Zed elevation katmanlarını uygular:
  `Surface`, `ElevatedSurface`, `ModalSurface`. Popover/modal gibi katmanlarda
  elle shadow/border üretmek yerine bunları kullan. **Reference asimetrisi:**
  `elevation_1(cx)`, `elevation_2(cx)`, `elevation_3(cx)` `&App` alır;
  `elevation_1_borderless(cx)`, `elevation_2_borderless(cx)`,
  `elevation_3_borderless(cx)`, `border_primary(cx)` ve `border_muted(cx)`
  `&mut App` ister. Read-only render path'inde borderless varyantı
  çağrılamaz; mut access verir veya borderless yerine bordered varyantı seç.
- `debug_bg_red/green/blue/yellow/cyan/magenta()` yalnızca geliştirme sırasında
  layout teşhisi içindir.

Tipografi:

- `StyledTypography::font_ui(cx)` ve `font_buffer(cx)` theme settings'teki UI ve
  buffer font family değerlerini bağlar.
- `text_ui_size(TextSize, cx)` enum'dan semantic text size uygular.
- `text_ui_lg(cx)`, `text_ui(cx)`, `text_ui_sm(cx)`, `text_ui_xs(cx)` UI scale'i
  dikkate alan semantic metin boyutlarıdır.
- `text_buffer(cx)` buffer font size'a uyar; editor içeriğiyle aynı boyda
  görünmesi gereken metinde kullanılır.
- `TextSize::{Large, Default, Small, XSmall, Ui, Editor}` hem `.rems(cx)` hem
  `.pixels(cx)` verir. Hardcoded `px(14.)` yerine semantic boyut tercih edilir.

Semantic renk ve elevation:

- `Color` theme'e göre HSLA'ya çevrilen semantic enum'dur
  (`crates/ui/src/styles/color.rs`). Variantlar:
  `Default`, `Accent`, `Conflict`, `Created`, `Custom(Hsla)`, `Debugger`,
  `Deleted`, `Disabled`, `Error`, `Hidden`, `Hint`, `Ignored`, `Info`,
  `Modified`, `Muted`, `Placeholder`, `Player(u32)`, `Selected`, `Success`,
  `VersionControlAdded`, `VersionControlConflict`, `VersionControlDeleted`,
  `VersionControlIgnored`, `VersionControlModified`, `Warning`. Üretim/diff
  rengi için git/VCS varyantlarını, oyuncu vurgusu için `Player(u32)`'yi,
  highlight için `Selected`/`Hint`'i tercih et — bunlar `cx.theme().status()`
  veya player palette üzerinden HSLA'ya çözülür.
- `TintColor::{Accent, Error, Warning, Success}` button tint stillerine kaynaklık
  eder ve `Color`'a dönüştürülebilir.
- `Severity::{Info, Success, Warning, Error}` `Banner`/`Callout` gibi feedback
  bileşenlerinin semantic durumudur; `TintColor` veya `Color` yerine component
  severity sözleşmesi istediğinde bunu kullan.
- `PlatformStyle::{Mac, Linux, Windows}` ve `PlatformStyle::platform()` platforma
  göre UI ayrımı gereken bileşenlerde küçük branching yüzeyidir.
- `ElevationIndex::{Background, Surface, EditorSurface, ElevatedSurface,
  ModalSurface}` shadow, background ve "bu elevation üzerinde okunacak renk"
  kararlarını toplar.
  Public helper'ları (receiver/mut asimetrisi var):
  - `.shadow(self, cx: &App) -> Vec<BoxShadow>` — `self`'i tüketir; tipik
    olarak `match`/clone sonrası kullanılır.
  - `.bg(&self, cx: &mut App) -> Hsla` — `&mut App` ister (yalnız bu).
  - `.on_elevation_bg(&self, cx: &App) -> Hsla`,
    `.darker_bg(&self, cx: &App) -> Hsla` — `&App` yeterli.

Button/label ortak sözleşmeleri:

- `Clickable`: `.on_click(...)` ve `.cursor_style(...)`.
- `Disableable`: `.disabled(bool)`.
- `Toggleable`: `.toggle_state(bool)`; `ToggleState::{Unselected,
  Indeterminate, Selected}` üç durumlu checkbox/tree selection için.
  `ToggleState` ayrıca `.inverse()`, `.selected()` ve
  `from_any_and_all(any_checked, all_checked)` yardımcılarını sağlar.
- `SelectableButton`: selected durumda farklı `ButtonStyle` tanımlar.
- `ButtonCommon`: `.id()` accessor'ı ve `.style(ButtonStyle)`,
  `.size(ButtonSize)`, `.tooltip(...)`, `.tab_index(...)`,
  `.layer(ElevationIndex)`, `.track_focus(...)`.
- `ButtonStyle::{Filled, Tinted(TintColor), Outlined, OutlinedGhost,
  OutlinedCustom(Hsla), Subtle, Transparent}`.
- `ButtonSize::{Large, Medium, Default, Compact, None}`.
- `LabelCommon`: `.size(LabelSize)`, `.weight(FontWeight)`,
  `.line_height_style(LineHeightStyle::{TextLabel, UiLabel})` — `TextLabel`
  default (UI/buffer default line-height), `UiLabel` line-height'i 1.0'a sabitler,
  `.color(Color)`, `.strikethrough()`, `.italic()`, `.underline()`,
  `.alpha(f32)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.
- `LabelLike` (underlying primitive struct) ayrıca inherent
  `.truncate_start()` taşır — `LabelCommon` trait'inde yer almaz; başlangıçtan
  ellipsis ile kesmek için `LabelLike` veya `Label` üzerinde doğrudan çağrılır.
- `FixedWidth`: `.width(DefiniteLength)` ve `.full_width()`; mevcut UI
  katmanında `Button`, `IconButton` ve `ButtonLike` üzerinde implement edilir.

Diğer UI yardımcıları:

- `VisibleOnHover::visible_on_hover(group)` elementi başlangıçta invisible yapar,
  belirtilen group hover olduğunda visible'a çevirir. `""` global group'tur.
- `WithRemSize::new(px(...))` child ağacında `window.with_rem_size` uygular;
  özel preview veya küçük component ölçeklemesi için kullanılır;
  `.occlude()` mouse etkileşimini kapatır.
- `ui::utils` public nested namespace olarak kalır. Sık kullanılan export'lar:
  `is_light(cx)`, `reveal_in_file_manager_label(is_remote)`, `capitalize(str)`,
  `SearchInputWidth::calc_width(container_width)`,
  `platform_title_bar_height(&Window)`,
  `calculate_contrast_ratio(fg, bg)`, `apca_contrast(text, bg)`,
  `ensure_minimum_contrast(...)`, `CornerSolver::new(root_radius, root_border,
  root_padding)`, `inner_corner_radius(...)`,
  `FormatDistance::{new(date, base_date), from_now(date), include_seconds(bool),
  add_suffix(bool), hide_prefix(bool)}`, `format_distance(...)`,
  `format_distance_from_now(...)`, `DateTimeType::{Naive(NaiveDateTime),
  Local(DateTime<Local>)}`.
- `BASE_REM_SIZE_IN_PX` `ui::utils` altında değil, `styles/units.rs` üzerinden
  crate köküne gelen `ui::BASE_REM_SIZE_IN_PX` sabitidir; `rems_from_px(...)`,
  `vh(...)`, `vw(...)` ile aynı units yüzeyindedir.
- `ui::ui_density(cx: &mut App) -> UiDensity` styles modülünden gelen
  ergonomik helper'dır; `theme::theme_settings(cx).ui_density(cx)` kısayolu.
  Spacing kararları için `DynamicSpacing` enum'unu tercih et, density'yi
  yalnızca styling dışı kararlar (örn. icon size, compact toggle) için kullan.
- Keybinding görünümü için crate kökünde public free fonksiyonlar:
  - `text_for_action(action: &dyn Action, window, cx) -> Option<String>`
  - `text_for_keystrokes(keystrokes: &[Keystroke], cx) -> String`
  - `text_for_keystroke(modifiers: &Modifiers, key: &str, cx) -> String`
  - `text_for_keybinding_keystrokes(keystrokes: &[KeybindingKeystroke], cx) -> String`
  - `render_keybinding_keystroke(...)`, `render_modifiers(...)`: element üretir.
  Bu yardımcılar tooltip/menu metni üretirken `KeyBinding` veya `KeybindingHint`
  bileşeninden ayrı düşünülmelidir; bileşen render eder, free fn metin üretir.
- `Transformable` trait crate dışına public değildir (`traits` modülü private);
  yalnız `Icon` ve `Vector` implement eder. Bu yüzden `CommonAnimationExt`
  üzerindeki `with_rotate_animation`/`with_keyed_rotate_animation` zinciri
  yalnız bu iki tip üzerinde derlenir. Üçüncü taraf bir element için döndürme
  istiyorsan ya `Icon`/`Vector` sar ya da kendi `with_animation` zincirini kur.
- Scrollbar katmanı **iki ayrı API yüzeyi** sunar; doğru olanı seç:
  - Düşük seviye: `Scrollbars::new(ScrollAxes)` builder zinciri —
    `.tracked_scroll_handle(handle)`, `.id(...)`, `.notify_content()`,
    `.style(ScrollbarStyle)`, `.with_track_along(...)` vb. — sonra
    `div().custom_scrollbars(config, window, cx)` ile uygulanır.
    `custom_scrollbars` ve `vertical_scrollbar_for` yalnızca
    `WithScrollbar` trait üzerindedir; `WithScrollbar`
    `Div` ve `Stateful<Div>` için implement edilir.
  - Kısayol: `div().vertical_scrollbar_for(&scroll_handle, window, cx)` —
    `WithScrollbar::vertical_scrollbar_for` default impl'i kendi içinde
    `Scrollbars::new(ScrollAxes::Vertical).tracked_scroll_handle(handle)`
    kurar. **`Scrollbars` üzerinde inherent `.vertical_scrollbar_for(...)`
    yoktur**; zincir parent element üzerinde başlar.
  - Görünürlük ayarı crate kökünde değil
    `ui::scrollbars::{ShowScrollbar, ScrollbarVisibility, ScrollbarAutoHide}`
    namespace'i altındadır; `ScrollbarVisibility` settings trait'i,
    `ScrollbarAutoHide` ise auto-hide durumunu taşıyan `Global` tipidir.
  - Enum yüzeyi: `ScrollAxes::{Horizontal, Vertical, Both}` (Scrollbars'a
    verilen üç-değerli eksen seçimi) ve `ScrollbarStyle::{Regular, Editor}`.
    Özel scroll handle yazıyorsan `ScrollableHandle: 'static + Any + Sized
    + Clone` trait'i `max_offset(&self) -> Point<Pixels>`,
    `set_offset(&self, Point<Pixels>)`, `offset(&self) -> Point<Pixels>`,
    `viewport(&self) -> Bounds<Pixels>`, default impl'li
    `drag_started(&self)`/`drag_ended(&self)`,
    `scrollable_along(&self, ScrollbarAxis) -> bool` ve
    `content_size(&self) -> Size<Pixels>` sözleşmesini taşır.
    **`ScrollbarAxis` ≠ `ScrollAxes`.** `ScrollbarAxis` scrollbar.rs
    içinde `gpui::Axis as ScrollbarAxis` aliasıdır; iki variantı
    (`Horizontal`, `Vertical`) vardır ve scrollable handle'ın tek eksen
    sorgusu için kullanılır. `ScrollAxes` (Horizontal/Vertical/Both)
    `Scrollbars::new(...)` yapılandırma yüzeyidir.
  - `on_new_scrollbars<T: gpui::Global>(cx)` bir global ayarı
    `ScrollbarState::settings_changed` observer'ına bağlamak için düşük seviye
    helper'dır; normal component render'ında çağrılan bir builder değildir.

Tuzaklar:

- Uygulama UI'ında doğrudan `cx.theme().colors().text_*` yazmak mümkün olsa da
  reusable component için `Color`/`TintColor` semantic katmanı daha dayanıklıdır.
- `ButtonLike` güçlü ama unconstrained bir primitive'dir; hazır `Button`,
  `IconButton`, `ToggleButtonGroup`, `ToggleButtonSimple` veya
  `ToggleButtonWithIcon` yeterliyse onları kullan. `ToggleButton` adında
  bağımsız bir public tip yoktur.
- `VisibleOnHover` için parent'ta aynı group adıyla hover group kurulmadıysa
  element hiçbir zaman görünmez.
- Public görünen bazı state structs kullanıcı-facing builder değildir:
  `PopoverMenuElementState`, `PopoverMenuFrameState`, `MenuHandleElementState`,
  `RequestLayoutState`, `PrepaintState`, `ScrollbarPrepaintState`. Bunlar
  `Element` associated state tipleri olarak public kalmıştır; doğrudan
  oluşturup component API'si gibi kullanma.

Zed uygulamasında yönetim:

- Component registry çalışma zamanı render path'i değildir; app kodu bileşenleri
  doğrudan `ui::{...}` veya `ui::prelude::*` ile import edip element ağacına
  koyar.
- `workspace::init` içinde `component::init()` çağrılır. Bu çağrı
  `#[derive(RegisterComponent)]` tarafından inventory'ye eklenen
  `ComponentFn` kayıtlarını çalıştırır ve `ComponentRegistry`'yi doldurur.
- `zed/src/main.rs` `component_preview::init(app_state, cx)` çağırır.
  Component preview, `component::components().sorted_components()` ile
  registry'yi okur; isim, scope ve description üzerinden filtreler.
- `Component` trait public sözleşmesi: `id()`, `scope()`, `status()`,
  `name()`, `sort_name()`, `description()` ve
  `preview(&mut Window, &mut App) -> Option<AnyElement>`. Tüm metotlar
  default impl'e sahiptir; pratik minimum implementasyon yalnızca
  `scope()` + `preview()` override etmektir. Default davranış:
  - `id() -> ComponentId(Self::name())`
  - `name() -> std::any::type_name::<Self>()` (modül yolu dahil)
  - `scope() -> ComponentScope::None`
  - `status() -> ComponentStatus::Live`
  - `sort_name() -> Self::name()`
  - `description()` ve `preview()` `None` döner.
  Bu sözleşme görsel test/debug/dokümantasyon içindir; normal UI
  kullanımında component registry lookup yapılmaz.
- `ComponentScope` 17 variantı (organizasyon kovaları — strum
  `Display`/`EnumString` ile string serialize edilir): `Agent`,
  `Collaboration`, `DataDisplay` (`"Data Display"`), `Editor`, `Images`
  (`"Images & Icons"`), `Input` (`"Forms & Input"`), `Layout`
  (`"Layout & Structure"`), `Loading` (`"Loading & Progress"`),
  `Navigation`, `None` (`"Unsorted"`), `Notification`, `Overlays`
  (`"Overlays & Layering"`), `Onboarding`, `Status`, `Typography`,
  `Utilities`, `VersionControl` (`"Version Control"`).
- `ComponentStatus::{WorkInProgress, EngineeringReady, Live (default),
  Deprecated}`; her variant `.description() -> &str` ile kendi açıklama
  metnini döner (preview ekranında gösterilir).
- Diğer public registry yüzeyleri: `ComponentId(pub &'static str)`,
  `ComponentMetadata { id, description, name, preview, scope, sort_name,
  status }`, `ComponentExample { variant_name, description, element,
  width }`, `ComponentExampleGroup`, `empty_example(variant_name)`,
  `register_component::<T: Component>()`. `COMPONENT_DATA: LazyLock<RwLock<
  ComponentRegistry>>` global storage'dır; tüketici kod yerine
  `component::components()` accessor'ını kullanır.
- **`ui` prelude vs `component_prelude` asimetrisi:** `ui::prelude::*`
  yalnız `Component` ve `ComponentScope`'u re-export eder. `ComponentStatus`,
  `ComponentId`, `Documented` `ui::component_prelude::*` üzerinden gelir;
  `ui::ComponentStatus` doğrudan çalışmaz, `ui::component_prelude::ComponentStatus`
  veya `component::ComponentStatus` yazılır.

## Zed UI Bileşen Envanteri


Zed'de yeni UI yazarken önce `ui` bileşenlerini ara. Başlıca bileşenler:

- Metin: `Label`, `LabelLike` (underlying primitive), `Headline`,
  `HighlightedLabel` ve `highlight_ranges(...)` free fn yardımcısı,
  `LoadingLabel`, `SpinnerLabel` (`SpinnerVariant::{Dots (default),
  DotsVariant, Sand}`). `SpinnerLabel` constructorları: `new()` default
  Dots, `with_variant(SpinnerVariant)` ve doğrudan kısayollar `dots()`,
  `dots_variant()`, `sand()`. `SpinnerLabel` ayrıca `LabelCommon` implement
  ettiği için `.size/.color/.weight/...` zinciri kullanılabilir.
- Buton: `Button` (`KeybindingPosition::{Start, End}` ile
  `.key_binding_position(...)`), `IconButton`
  (`IconButtonShape::{Square, Wide}`), `SelectableButton`, `ButtonLike`
  (`ButtonBuilder`/`ButtonConfiguration` sealed yardımcılar), `ButtonLink`,
  `CopyButton`, `SplitButton`
  (`SplitButtonStyle::{Filled, Outlined, Transparent}`,
  `SplitButtonKind::{ButtonLike(ButtonLike), IconButton(IconButton)}` —
  segment olarak hem button-like hem icon button kabul eder),
  `ToggleButtonGroup` (`ToggleButtonGroupStyle::{Transparent, Filled,
  Outlined}`, `ToggleButtonGroupSize::{Default, Medium, Large, Custom(Rems)}`,
  `ToggleButtonPosition` — bu **enum değil struct**'tır; `leftmost`,
  `rightmost`, `topmost`, `bottommost` private `bool` alanlarıyla grup içi
  konum bayrağıdır) ve giriş tipleri `ToggleButtonSimple`,
  `ToggleButtonWithIcon`. `ToggleButton` adında bağımsız bir struct yoktur;
  tekil toggle yerine her zaman grup içinde segment kullanılır.
- İkon: `Icon`, `DecoratedIcon`, `IconDecoration`,
  `IconDecorationKind::{X, Dot, Triangle}`, `IconName`,
  `IconPosition::{Start, End}` (button içinde label-icon sırası),
  `IconSize`, `IconWithIndicator`, `KnockoutIconName::{XFg, XBg, DotFg, DotBg,
  TriangleFg, TriangleBg}` (IconDecoration için eşli fg/bg svg adları),
  `AnyIcon::{Icon(Icon), AnimatedIcon(AnimationElement<Icon>)}` (type-erased
  ikon: hem statik hem animasyonlu varyantı tek tipte taşır). `IconName`
  `crates/icons` crate'inde tanımlanır, `ui::prelude` üzerinden re-export
  edilir. `IconSize` varyantları: `Indicator`, `XSmall`, `Small`, `Medium`,
  `XLarge`, `Custom(Rems)`; `.rems()`, `.square_components(window, cx)`,
  `.square(window, cx)` verir.
- Form/toggle: `Checkbox`, `Switch` (`SwitchColor::{Accent, Custom(Hsla)}`,
  `SwitchLabelPosition::{Start, End}`), `SwitchField`, `DropdownMenu`
  (`DropdownStyle::{Solid, Outlined, Subtle, Ghost}`), `ToggleStyle::{Ghost,
  ElevationBased(ElevationIndex), Custom(Hsla)}`.
  Lowercase yardımcı fonksiyonlar `checkbox(id, state)` ve
  `switch(id, state)` constructor kısayollarıdır.
- Metin girişi: `ui_input::InputField` ayrı crate'tedir; `ui` re-export etmez.
  `InputField::new(window, cx, placeholder)` editor factory gerektirir ve
  `.label`, `.start_icon`, `.masked`, `.tab_index`, `.text`, `.set_text`,
  `.clear` gibi form alanı API'sini sağlar.
- Menü/popup: `ContextMenu`, `ContextMenuEntry`,
  `ContextMenuItem::{Separator, Header(SharedString), HeaderWithLink(title,
  link_label, link_url), Label(SharedString), Entry(ContextMenuEntry),
  CustomEntry { entry_render, handler, selectable, documentation_aside },
  Submenu { label, icon, icon_color, builder }}` — `ContextMenu` builder'ına
  doğrudan eklenen yedi tip menü satırı,
  `DocumentationAside { side: DocumentationSide, render: Rc<...> }`,
  `DocumentationSide::{Left, Right}`,
  `RightClickMenu<M: ManagedView>` ve free fn `right_click_menu(id)`,
  `Popover`, `PopoverMenu<M: ManagedView>`,
  `PopoverMenuHandle<M>` (imperatif kontrol için `show(window, cx)`,
  `hide(cx)`, `toggle(window, cx)`, `is_deployed() -> bool`,
  `is_focused(window, cx) -> bool`, `refresh_menu(...)` metotları —
  `Default` implement eder ve `PopoverMenu::with_handle(handle)` ile bağlanır),
  `PopoverTrigger` (`IntoElement + Clickable + Toggleable + 'static`
  supertraitlerini taşıyan her tipe blanket impl), `Tooltip`, `LinkPreview`
  ve free fn `tooltip_container(cx, f)`.
- Liste/tree: `List` (`EmptyMessage::{Text(SharedString), Element(AnyElement)}`),
  `ListItem` (`ListItemSpacing::{Dense, ExtraDense, Sparse}`),
  `ListHeader`, `ListSubHeader`, `ListSeparator` (`pub struct ListSeparator;` —
  unit struct, builder yok), `ListBulletItem`, `TreeViewItem`,
  `StickyCandidate` (`depth(&self) -> usize`), `StickyItems<T>` ve free fn
  constructor `sticky_items<V, T>(...)`, `StickyItemsDecoration`
  (`compute(indents, bounds, scroll_offset, item_height, window, cx)`),
  `IndentGuides` (`IndentGuideColors` — `panel(cx) -> Self` factory ile;
  `IndentGuideLayout { offset: Point<usize>, length: usize,
  continues_offscreen: bool }`;
  `RenderIndentGuideParams { indent_guides: SmallVec<[IndentGuideLayout;12]>,
  indent_size, item_height }`; `RenderedIndentGuide { bounds, layout,
  is_active, hitbox: Option<Bounds<Pixels>> }`) ile free fn constructor
  `indent_guides(indent_size: Pixels, colors: IndentGuideColors)`. `IndentGuides`
  builder yüzeyi: `.on_click(|&IndentGuideLayout, &mut Window, &mut App|)`,
  `.with_compute_indents_fn::<V>(entity, |&mut V, Range<usize>, &mut Window,
  &mut Context<V>| -> SmallVec<[usize;64]>)` ve `.with_render_fn::<V>(entity,
  |&mut V, RenderIndentGuideParams, &mut Window, &mut App| ->
  SmallVec<[RenderedIndentGuide;12]>)`. `IndentGuides`, `UniformListDecoration`
  trait'ini implement ettiği için `uniform_list(...).with_decoration(guides)`
  ile bağlanır. GPUI tarafında `impl<T: UniformListDecoration + 'static>
  UniformListDecoration for Entity<T>` blanket impl'i bulunur — bir
  decoration tipini `Entity<T>` içinde saklayıp aynı `.with_decoration(...)`
  yüzeyine geçirmek mümkündür.
- Tab: `Tab`, `TabBar`, `TabPosition::{First, Middle(Ordering), Last}`,
  `TabCloseSide::{Start, End}`
- Layout yardımcıları: `h_flex()`, `v_flex()`, `h_group*()`, `v_group*()`,
  `Divider` (`DividerColor::{Border, BorderFaded, BorderVariant}`),
  `divider()` ve `vertical_divider()` free fn constructorları, `Scrollbars`.
  `Stack` ve `Group` adında public struct yoktur; bunlar helper fonksiyon
  ailesidir.
- Veri: `Table`, `TableInteractionState`,
  `ColumnWidthConfig::{Static { widths, table_width }, Redistributable {
  columns_state, table_width }, Resizable(Entity<ResizableColumnsState>)}` —
  bu üçlü tablo kolon modunu belirler: `Static` resize handle vermez,
  `Redistributable` toplam tablo genişliğini sabit tutarak komşuya devreder,
  `Resizable` her kolonu bağımsız büyütür ve toplam genişlik değişir.
  `StaticColumnWidths::{Auto, Explicit(TableRow<DefiniteLength>)}` Static
  modun alt seçimidir. `ResizableColumnsState`, `RedistributableColumnsState`,
  `HeaderResizeInfo`, `TableResizeBehavior::{None, Resizable, MinSize(f32)}`,
  `TableRow<T>` (`pub struct TableRow<T>(Vec<T>)` — kolon sayısı doğrulanmış
  satır), `UncheckedTableRow<T>` (`pub type UncheckedTableRow<T> = Vec<T>` —
  doğrulamasız satır; struct değil tip alias'ıdır), `TableRenderContext`,
  `IntoTableRow` trait, `render_table_row`, `render_table_header`,
  `bind_redistributable_columns()` ve
  `render_redistributable_columns_resize_handles()`.
- Feedback: `Banner`, `Callout` (`BorderPosition::{Top, Bottom}`),
  `Modal`, `ModalHeader`, `ModalFooter`, `ModalRow`, `Section`,
  `SectionHeader`, `AlertModal`,
  `AnnouncementToast`, `CountBadge`, `Indicator`, `ProgressBar`,
  `CircularProgress`. `ui::Notification` standalone component değildir;
  workspace bildirim sistemi ayrı `workspace::notifications` trait'leriyle
  yönetilir.
- Diğer: `Avatar`, `AvatarAudioStatusIndicator` (`AudioStatus::{Muted,
  Deafened}` enum'u ile), `AvatarAvailabilityIndicator`
  (`CollaboratorAvailability::{Free, Busy}` enum'u ile), `Facepile`, `Chip`,
  `DiffStat`,
  `Disclosure`, `GradientFade`, `Vector`, `VectorName`, `KeyBinding`,
  `KeybindingHint`, `Key`, `KeyIcon` (keybinding sub-primitives —
  `text_for_keystroke`/`render_modifiers` free fn'leri ile kullanılır),
  `Navigable` ve `NavigableEntry`. `Image` adında public Zed UI
  component'i yoktur; raster görsel için GPUI `img(...)` / `ImageSource`,
  bundled SVG için `Vector` kullanılır.
- AI/collab özel: `AiSettingItem` (`AiSettingItemStatus`,
  `AiSettingItemSource`), `AgentSetupButton`, `ConfiguredApiCard`,
  `ParallelAgentsIllustration`, `ThreadItem` (`AgentThreadStatus`,
  `WorktreeKind`, `ThreadItemWorktreeInfo`), `CollabNotification`,
  `UpdateButton`

Component API yüzeyi:

- `Table::pin_cols(n)` ilk `n` kolonu yatay scroll sırasında sabit tutar.
  `ColumnWidthConfig::Resizable` ile kullanılır; `n == 0` veya `n >= cols` ise
  tek parçalı layout'a düşer. Pinned layout'ta header ve
  satırların scrollable bölümleri ortak `ScrollHandle` ile senkron tutulur.
- `ResizableColumnsState::drag_to(col_idx, drag_x, rem_size)` test edilebilir
  düşük seviye resize yüzeyidir. Pinned layout'ta drag koordinatı doğal,
  scroll edilmemiş kolon şeridi koordinatıdır; `on_drag_move` yatay scroll
  offset'ini bunu hesaplamak için alır.
- `ProjectEmptyState::new(label, focus_handle, open_project_key_binding)` ortak
  boş-proje UI'ıdır. Project panel, Git panel ve Threads sidebar aynı
  "Open Project / Clone Repository" component'ini kullanır.
- `Button::loading(true)` `start_icon` yerine dönen `LoadCircle` spinner'ı çizer.
  Loading açıkken ayrıca start icon bekleme; component bunu bilinçli olarak
  bastırır.

Genel kural:

- Zed içinde ham `div().on_click(...)` ile buton üretmeden önce `Button` veya
  `IconButton` kullan.
- Sadece görsel/tek seferlik parça için `RenderOnce`, stateful view için `Render`.
- Listeler çok büyükse `list` veya `uniform_list` kullan.
- Tooltip, popover ve context menu için hazır bileşenleri kullan; focus/blur
  kapanma davranışı orada çözülmüş durumdadır.

## ManagedView, DismissEvent, Modal, Popover ve Tooltip Yaşam Döngüsü


`ManagedView` GPUI'da başka bir view tarafından yaşam döngüsü yönetilen UI
parçaları için blanket trait'tir:

```rust
pub trait ManagedView: Focusable + EventEmitter<DismissEvent> + Render {}
```

Bir modal, popover veya context menu kapatılmak istediğinde kendi entity
context'inden `DismissEvent` yayar:

```rust
impl EventEmitter<DismissEvent> for MyModal {}

fn dismiss(&mut self, cx: &mut Context<Self>) {
    cx.emit(DismissEvent);
}
```

Zed/UI bileşenleri:

- `ContextMenu`: `ManagedView` uygular; command listesi ve separator yönetimi
  için kullanılır.
- `PopoverMenu<M: ManagedView>`: anchor element'ten focus edilebilir popover
  açar; `PopoverMenuHandle<M>` dışarıdan toggle/close için tutulabilir.
- `right_click_menu(id)`: context menu'yu mouse event akışına bağlayan UI
  helper'ıdır.
- Workspace modal layer `ModalView`/`ToastView` gibi katmanlarda
  `DismissEvent` subscription'ı ile kapanmayı yönetir; `on_before_dismiss`
  varsa kapanmadan önce çağrılır.

Tooltip:

- Element fluent API: `.tooltip(|window, cx| AnyView)` ve
  `.hoverable_tooltip(|window, cx| AnyView)`.
- Imperative `Interactivity` API aynı callback imzasını kullanır.
- `hoverable_tooltip` mouse tooltip içine geçince kapanmaz; normal tooltip
  pointer owner element'ten ayrılınca release edilir.

Tuzaklar:

- Modal/popover view `Focusable` sağlamazsa klavye ve dismiss davranışı eksik
  kalır.
- `DismissEvent` emit eden entity subscription'ı saklanmazsa layer kapanma
  callback'i düşer.
- Aynı elementte birden fazla tooltip tanımlamak debug assert'e yol açar.

---

---

