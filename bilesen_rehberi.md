# Zed UI Bileşenleri Kullanım Rehberi

Bu rehber, `../zed` çalışma ağacındaki Zed UI bileşenlerini kaynak alır
(`../zed` içinde `git rev-parse HEAD`:
`6e8eaab25b5ac324e11a82d1563dcad39c84bace`). Amaç, `crates/ui` merkezli
bileşenleri kaynak dosyaları, export yolları, builder API'leri, preview desteği
ve gerçek kullanım örnekleriyle tek yerde açıklayarak kendi GPUI tabanlı
ekranlarınızda doğru, tutarlı ve Zed tasarım sistemiyle uyumlu UI kurmanıza
yardımcı olmaktır.

Ana kapsam:

- `crates/ui`: bileşenlerin çoğu, tasarım sistemi token'ları ve prelude.
- `crates/gpui/src/elements`: ham GPUI element primitive'leri (`div`,
  `img`, `svg`, `canvas`, `anchored`, `list`, `uniform_list`, `deferred`,
  `surface`, `StyledText`).
- `crates/component`: component gallery ve preview kayıt sistemi.
- `crates/icons`: `IconName` kaynakları.
- `crates/theme`: tema token'larının arkasındaki etkin tema verisi.

Yardımcı kapsam:

- `crates/ui_input`: editor tabanlı tek satır form input'u (`InputField`).
- `crates/notifications` ve `crates/collab_ui`: doğrudan Zed UI component'i
  olmayan, ama örneklerde lifecycle ve gerçek kullanım bağlamı veren katmanlar.

## 1. Kaynak ve API Envanteri

Bu bölüm, rehberde anlatılan bileşenlerin kaynak dosyalarını, export yollarını,
prelude durumunu ve preview desteğini gösterir. Bir bileşenin ayrıntılı kullanım
notları ilgili bileşen başlığında yer alır.

### Export modeli

`crates/ui/src/components.rs`, component modüllerini crate seviyesine açar:

```rust
mod button;
mod icon;
mod label;

pub use button::*;
pub use icon::*;
pub use label::*;
```

Bu düzen nedeniyle çoğu bileşen `ui::Button`, `ui::Icon`, `ui::Label` gibi
crate kökünden çağrılır. Alt modüller de kendi içlerinde `pub use *` yapar;
örneğin `crates/ui/src/components/button.rs`, `Button`, `IconButton`,
`ButtonLike`, `CopyButton`, `SplitButton` ve toggle button tiplerini dışarı açar.

`crates/ui/src/ui.rs` Zed UI crate'inin gerçek export kapısıdır:

```rust
pub mod component_prelude;
mod components;
pub mod prelude;
mod styles;
mod traits;
pub mod utils;

pub use components::*;
pub use prelude::*;
pub use styles::*;
pub use traits::animation_ext::*;
```

Bunun pratik sonucu:

- `components`, `styles` ve `traits` modülleri kaynakta `mod` (crate-içi)
  olarak tanımlandığı için doğrudan public path değildir;
  `ui::components::button::Button` gibi yollar yoktur. Tüketici kodu
  `ui::Button`, `ui::ContextMenu`, `ui::Color`, `ui::TextSize` gibi crate kökü
  re-export'larını kullanır. `pub use components::*`, `pub use styles::*` ve
  `pub use traits::animation_ext::*` bu özel modüllerin içindeki public adları
  crate köküne taşır.
- Public alt modül olarak kalıcı görünen yollar `ui::prelude`,
  `ui::component_prelude`, `ui::utils`, re-export zincirinden gelen
  `ui::animation`, `ui::scrollbars` ve `ui::table_row` yollarıdır.
- `traits::animation_ext` crate köküne açıldığı için `ui::CommonAnimationExt`
  import edilebilir. Buna karşılık `traits::transformable` crate kökünden
  açılmaz; kaynakta `pub trait Transformable` görünmesi tek başına tüketici
  API'si olduğu anlamına gelmez.

`crates/ui/src/prelude.rs` daha seçicidir. Her component'i değil, sık kullanılan
temel UI primitive'lerini ve trait'leri getirir:

- GPUI yeniden ihraçları (`pub use gpui::prelude::*` ve ayrıca):
  `AbsoluteLength`, `AnyElement`, `App`, `Context`, `DefiniteLength`, `Div`,
  `Element`, `ElementId`, `InteractiveElement`, `ParentElement`, `Pixels`,
  `Rems`, `RenderOnce`, `SharedString`, `Styled`, `Window`, `div`, `px`,
  `relative`, `rems`.
- Component preview tipleri: `Component`, `ComponentScope`,
  `example_group`, `example_group_with_title`, `single_example`,
  `RegisterComponent`.
- Ortak trait'ler: `Clickable`, `Disableable`, `FixedWidth`, `StyledExt`,
  `Toggleable`, `VisibleOnHover`.
- Tasarım sistemi token'ları ve yardımcıları: `DynamicSpacing`, `PlatformStyle`,
  `Severity`, `StyledTypography`, `TextSize`, `rems_from_px`, `vh`, `vw`,
  `ActiveTheme`.
- Animasyon yardımcıları: `AnimationDirection`, `AnimationDuration`,
  `DefaultAnimations`.
- Sık kullanılan bileşenler ve enum'lar: `Button`, `IconButton`,
  `SelectableButton`, `ButtonCommon`, `ButtonSize`, `ButtonStyle`, `Color`,
  `Headline`, `HeadlineSize`, `Icon`, `IconName`, `IconPosition`, `IconSize`,
  `Label`, `LabelCommon`, `LabelSize`, `LineHeightStyle`, `LoadingLabel`,
  `h_flex`, `v_flex`, `h_group*`, `v_group*`.

Rehberdeki örneklerde kural şu olacak: örnekler önce `use ui::prelude::*;` ile
başlayacak, prelude'da olmayan bileşenler ayrıca `use ui::{...};` satırında
belirtilecek.

#### Bu turdaki denetim düzeltmesi

`tema_rehber.md` dosyasının `8d14daf..7223211` farkı, önceki araştırmanın ana
kusurunu gösterdi: konu başlıklarına göre arama yapmak, public yüzeyi eksiksiz
yakalamaya yetmiyor. `refine_theme*`, `merge_*`, settings mutator'ları ve font
runtime helper'ları ancak şu sırayla bulunabildi: export kapısını oku, `pub`
adları çıkar, imzayı owner ile eşleştir, sonra gerçek kullanım yerlerini tara.
Bileşen tarafındaki karşılığı `IconSize::square`, `Checkbox::container_size`,
`Modal::show_back`, `TabBar::start_children_mut`, `ColumnWidthConfig::*` ve
`HeaderResizeInfo::reset_column` gibi kolay atlanan owner/metot yüzeyleridir.

Bileşen rehberi için aynı kural geçerlidir. Bir ad yalnızca metinde geçiyor diye
kapsanmış sayılmaz; şu dört bilgi birlikte doğrulanır:

- **Export yolu:** `ui::Button` mı, `ui::utils::WithRemSize` mi,
  `component::ComponentRegistry` mi?
- **Owner:** inherent metot mu (`DropdownMenu::no_chevron`), trait metodu mu
  (`ButtonCommon::tooltip`), yoksa private modülde kalan yardımcı mı
  (`Transformable`)?
- **İmza:** callback parametreleri ve return tipi kaynakla aynı mı?
- **Zed kullanımı:** `../zed` uygulaması bu API'yi preview'da mı, production
  UI'da mı, lifecycle yönetiminde mi kullanıyor?

#### Public yüzey snapshot'ı (`../zed` `6e8eaab25b`)

Aşağıdaki liste `crates/ui/src/components`, `crates/ui/src/styles`,
`crates/ui/src/utils`, `crates/ui/src/traits`, `crates/component/src` ve
`crates/ui_input/src` üzerinde `^pub` taramasıyla doğrulandı. Ayrıntılı builder
imzaları ilgili başlıklarda, yüksek riskli lifecycle API'leri ise bu tablonun
altında ayrıca verilir.

| Alan | Public adlar |
| :-- | :-- |
| Crate kapıları | `ui::prelude`, `ui::component_prelude`, `ui::utils`, `ui::animation`, `ui::scrollbars`, `ui::table_row` |
| Button ailesi | `Button`, `IconButton`, `ButtonLike`, `ButtonLink`, `CopyButton`, `SplitButton`, `ToggleButtonGroup`, `ToggleButtonSimple`, `ToggleButtonWithIcon`, `ButtonBuilder`, `ButtonConfiguration`, `SelectableButton`, `ButtonCommon`, `ButtonSize`, `ButtonStyle`, `IconPosition`, `KeybindingPosition`, `TintColor`, `IconButtonShape`, `SplitButtonStyle`, `SplitButtonKind`, `ToggleButtonPosition`, `ToggleButtonGroupStyle`, `ToggleButtonGroupSize` |
| Label / ikon | `Label`, `LabelLike`, `HighlightedLabel`, `LoadingLabel`, `SpinnerLabel`, `SpinnerVariant`, `LabelCommon`, `LabelSize`, `LineHeightStyle`, `Icon`, `IconName`, `IconSize`, `AnyIcon`, `IconWithIndicator`, `DecoratedIcon`, `IconDecoration`, `IconDecorationKind`, `KnockoutIconName`, `highlight_ranges` |
| Form ve popup | `checkbox`, `switch`, `Checkbox`, `Switch`, `SwitchField`, `ToggleStyle`, `SwitchColor`, `SwitchLabelPosition`, `DropdownMenu`, `DropdownStyle`, `ContextMenu`, `ContextMenuEntry`, `ContextMenuItem`, `DocumentationAside`, `DocumentationSide`, `Popover`, `POPOVER_Y_PADDING`, `PopoverMenu`, `PopoverMenuHandle`, `PopoverTrigger`, `RightClickMenu`, `right_click_menu`, `Tooltip`, `LinkPreview`, `tooltip_container` |
| Liste / tree | `List`, `EmptyMessage`, `ListItem`, `ListItemSpacing`, `ListHeader`, `ListSubHeader`, `ListSeparator`, `ListBulletItem`, `TreeViewItem`, `StickyCandidate`, `StickyItems`, `StickyItemsDecoration`, `sticky_items`, `IndentGuideColors`, `IndentGuides`, `indent_guides`, `RenderIndentGuideParams`, `RenderedIndentGuide`, `IndentGuideLayout` |
| Tablo | `UncheckedTableRow`, `Table`, `TableInteractionState`, `TableRenderContext`, `ColumnWidthConfig`, `StaticColumnWidths`, `ResizableColumnsState`, `RedistributableColumnsState`, `TableResizeBehavior`, `HeaderResizeInfo`, `render_table_row`, `render_table_header`, `bind_redistributable_columns`, `render_redistributable_columns_resize_handles`, `table_row::TableRow`, `table_row::IntoTableRow` |
| Feedback / durum | `Banner`, `Callout`, `BorderPosition`, `Modal`, `ModalHeader`, `ModalRow`, `ModalFooter`, `Section`, `SectionHeader`, `AlertModal`, `AnnouncementToast`, `CountBadge`, `Indicator`, `ProgressBar`, `CircularProgress`, `Severity` |
| Tab | `Tab`, `TabBar`, `TabPosition`, `TabCloseSide` |
| Layout / divider | `h_flex`, `v_flex`, `h_group`, `h_group_sm`, `h_group_lg`, `h_group_xl`, `v_group`, `v_group_sm`, `v_group_lg`, `v_group_xl`, `Divider`, `DividerColor`, `divider`, `vertical_divider` |
| Scrollbar | `Scrollbars`, `ScrollAxes`, `ScrollbarStyle`, `ScrollableHandle`, `WithScrollbar`, `on_new_scrollbars`, `EDITOR_SCROLLBAR_WIDTH` (ek olarak `ui::scrollbars` modülü altında `ShowScrollbar`, `ScrollbarVisibility`, `ScrollbarAutoHide`) |
| Diğer component'ler | `Avatar`, `AudioStatus`, `AvatarAudioStatusIndicator`, `CollaboratorAvailability`, `AvatarAvailabilityIndicator`, `Facepile`, `EXAMPLE_FACES`, `Chip`, `DiffStat`, `Disclosure`, `GradientFade`, `Vector`, `VectorName`, `KeyBinding`, `Key`, `KeyIcon`, `KeybindingHint`, `Navigable`, `NavigableEntry`, `render_keybinding_keystroke`, `render_modifiers`, `text_for_action`, `text_for_keystrokes`, `text_for_keybinding_keystrokes`, `text_for_keystroke` |
| AI / collab | `AiSettingItem`, `AiSettingItemStatus`, `AiSettingItemSource`, `AgentSetupButton`, `ThreadItem`, `AgentThreadStatus`, `ThreadItemWorktreeInfo`, `WorktreeKind`, `ConfiguredApiCard`, `ParallelAgentsIllustration`, `CollabNotification`, `UpdateButton` |
| Style / trait / utils | `Color`, `ElevationIndex`, `DynamicSpacing`, `ui_density`, `PlatformStyle`, `StyledTypography`, `TextSize`, `Headline`, `HeadlineSize`, `AnimationDuration`, `AnimationDirection`, `DefaultAnimations`, `CommonAnimationExt`, `Clickable`, `Disableable`, `FixedWidth`, `StyledExt`, `Toggleable`, `ToggleState`, `VisibleOnHover`, `WithRemSize`, `SearchInputWidth`, `FormatDistance`, `DateTimeType`, `CornerSolver`, `inner_corner_radius`, `apca_contrast`, `ensure_minimum_contrast`, `calculate_contrast_ratio`, `format_distance`, `format_distance_from_now`, `is_light`, `capitalize`, `reveal_in_file_manager_label`, `platform_title_bar_height`, `TRAFFIC_LIGHT_PADDING`, `BASE_REM_SIZE_IN_PX`, `rems_from_px`, `vw`, `vh`, `theme_is_transparent` |
| Component preview | `components`, `init`, `register_component`, `Component`, `ComponentFn`, `ComponentRegistry`, `ComponentId`, `ComponentMetadata`, `ComponentStatus`, `ComponentScope`, `ComponentExample`, `ComponentExampleGroup`, `single_example`, `empty_example`, `example_group`, `example_group_with_title` |
| `ui_input` | `InputField`, `InputFieldStyle`, `ErasedEditor`, `ErasedEditorEvent`, `ERASED_EDITOR_FACTORY` |

**Public görünen ama kullanım yüzeyi olmayanlar:** `MenuHandleElementState`,
`RequestLayoutState`, `PrepaintState`, `PopoverMenuElementState`,
`PopoverMenuFrameState` ve `ScrollbarPrepaintState` element/layout state
taşıyıcılarıdır. Kaynakta `pub struct` olmaları tüketiciye önerilen builder
API'si oldukları anlamına gelmez; `Element` implementasyonu içinde
`RequestLayoutState` / `PrepaintState` tipleri layout, prepaint ve paint
geçişleri arasında veri taşır, `MenuHandleElementState` ve
`PopoverMenuElementState` ise hover/açık menü durumlarını element id'sine bağlar.

**Callback yüzeyi olarak public, state taşıyıcı değil:**
`RenderIndentGuideParams`, `RenderedIndentGuide` ve `IndentGuideLayout`
`IndentGuides` callback'lerinin sözleşme tipleridir.
`IndentGuides::with_render_fn(...)` callback'i `RenderIndentGuideParams`'ı
girdi olarak alır ve `SmallVec<[RenderedIndentGuide; 12]>` döndürür;
`IndentGuides::on_click(...)` ise ilk parametre olarak `&IndentGuideLayout`
verir. Bu nedenle üç tip de "IndentGuides" başlığında alanlarıyla birlikte
listelenir; element state taşıyıcısı sayılmaz.

Benzer public alanlı sözleşme tipleri:

- `TableRenderContext`, `render_table_row(...)` ve `render_table_header(...)`
  için düşük seviye render bağlamıdır. `TableInteractionState` gibi saklanan
  view state'i değildir; `striped`, `show_row_borders`, `column_widths`,
  `map_row` ve `disable_base_cell_style` alanları render helper'larına
  aktarılır.
- `HeaderResizeInfo`, header resize/reset sözleşmesidir. `resize_behavior`
  alanı public okunur, ancak kolon state'i içeride `WeakEntity` olarak tutulur;
  reset için public yol `reset_column(...)` metodudur.
- `DocumentationAside`, context menu custom entry'leri için `side` ve `render`
  callback'ini taşıyan aside verisidir; tek başına render edilen component
  değildir.
- `ThreadItemWorktreeInfo`, `ThreadItem::worktrees(...)` için domain veri
  nesnesidir. `worktree_name`, `branch_name`, `full_path`,
  `highlight_positions` ve `kind` alanları thread metadata satırını besler.
- `ComponentExample` ve `ComponentExampleGroup`, component preview layout
  verisidir. Alanları public olsa da normal preview kodunda
  `single_example(...)`, `empty_example(...)`, `example_group(...)` ve builder
  metodları tercih edilir.
- `NavigableEntry`, `Navigable` wrapper'ına eklenen focus/scroll entry
  sözleşmesidir. `focus_handle` ve `scroll_anchor` alanları publictir, ancak
  çoğu kullanım `NavigableEntry::new(...)` veya `focusable(...)` üzerinden
  kurulmalıdır.

#### Snapshot satır ayrımı ve payload denetimi

Son snapshot düzeltmesi kaynakla doğrulandı:

- `tab.rs` ve `tab_bar.rs`: `Tab`, `TabBar`, `TabPosition` ve `TabCloseSide`
  ayrı Tab yüzeyidir. Zed içinde pane tab bar akışı `workspace/src/pane.rs`
  dosyasında `TabPosition::{First, Middle(Ordering), Last}`,
  `TabCloseSide::{Start, End}` ve `TabBar::new(...)` ile kurulur.
- `stack.rs`, `group.rs` ve `divider.rs`: `h_flex`, `v_flex`, `h_group*`,
  `v_group*`, `Divider`, `DividerColor`, `divider()` ve
  `vertical_divider()` layout/divider yüzeyidir; `Stack` veya `Group` adlı
  public struct yoktur.
- `scrollbar.rs`: `Scrollbars`, `ScrollAxes`, `ScrollbarStyle`,
  `ScrollableHandle`, `WithScrollbar`, `on_new_scrollbars` ve
  `EDITOR_SCROLLBAR_WIDTH` root export'tur; `ShowScrollbar`,
  `ScrollbarVisibility` ve `ScrollbarAutoHide` ise `ui::scrollbars` public alt
  modülü altındadır. Zed `main.rs` `on_new_scrollbars::<SettingsStore>(cx)`
  çağırır; editor ve panel kodları `Scrollbars::for_settings::<...>()`
  kullanır.
- `keybinding.rs`: `render_keybinding_keystroke`, `render_modifiers`,
  `text_for_action`, `text_for_keystrokes`,
  `text_for_keybinding_keystrokes` ve `text_for_keystroke` free helper olarak
  public'tir. Bunlar `KeyBinding` component'inin constructor'ı değil; arama,
  keymap editor, which-key ve quick action preview gibi yerlerde doğrudan
  kullanılır.

Ek denetim sınıfı: `pub struct Foo { pub field: ... }` taraması tek başına
yeterli değildir. Public tuple struct alanları ve payload taşıyan enum
variant'ları ayrıca kontrol edilmelidir:

- Public tuple alanları: `ComponentId(pub &'static str)` ve
  `ScrollbarAutoHide(pub bool)`. İlki registry id değerini, ikincisi global
  auto-hide bayrağını taşır.
- Payload variant'ları: `SplitButtonKind::{ButtonLike(ButtonLike),
  IconButton(IconButton)}`, `ToggleButtonGroupSize::Custom(Rems)`,
  `StaticColumnWidths::Explicit(TableRow<DefiniteLength>)`,
  `LabelSize::Custom(Rems)`, `EmptyMessage::{Text(SharedString),
  Element(AnyElement)}`, `ToggleStyle::{ElevationBased(ElevationIndex),
  Custom(Hsla)}`, `SwitchColor::Custom(Hsla)`, `Color::Player(u32)` ve
  `DateTimeType::{Naive(NaiveDateTime), Local(DateTime<Local>)}` gibi
  variant'lar yalnızca isim değil, veri taşıyan public construction yüzeyidir.

`pub` taramasının kaçırdığı bir diğer sınıf public trait implementasyonlarıdır.
`impl From<...> for PublicType` satırında `pub` yazmaz, ama dış crate için
ergonomik construction yüzeyi oluşturur. Kaynakta doğrulanan dönüşümler:

- `ToggleState`: `From<bool>` ve `From<Option<bool>>`; `None`,
  `Indeterminate` anlamına gelir.
- `Color`: `From<Hsla>`, `From<TintColor>`, `From<ButtonStyle>` ve
  `From<SwitchColor>`. `ButtonStyle::Tinted(tint)` tint rengini taşır; diğer
  button stilleri `Color::Default` olur. `SwitchColor::Custom(_)` da `Color`
  dönüşümünde custom rengi taşımaz, `Default` döner.
- `AnyIcon`: `From<Icon>` ve `From<AnimationElement<Icon>>`; `Icon` ise
  `From<IconName>` sağlar.
- `SplitButtonKind`: `From<IconButton>` ve `From<ButtonLike>`. Bu yüzden
  `SplitButton::new(left, right)` sol parçada iki component türünü kabul eder.
- `EmptyMessage`: `From<String>`, `From<&str>` ve `From<AnyElement>`.
- `SectionHeader`: `From<SharedString>` ve `From<&'static str>`.
- `ContextMenuItem`: `From<ContextMenuEntry>`.

Private tiplerdeki dönüşümler tüketici yüzeyi sayılmaz. Örneğin
`tooltip.rs` içindeki private `Title` enum'u için `From<SharedString>` vardır,
ancak dış API `Tooltip::text(...)`, `Tooltip::simple(...)` ve
`Tooltip::for_action*` constructor'ları üzerinden görünür.

#### İmzası özellikle kontrol edilen lifecycle API'leri

Bu grup, callback imzaları veya generic bound'ları nedeniyle en kolay yanlış
aktarılabilecek yüzeydir:

```rust
pub fn right_click_menu<M: ManagedView>(
    id: impl Into<ElementId>,
) -> RightClickMenu<M>;

impl<M: ManagedView> RightClickMenu<M> {
    pub fn menu(
        self,
        f: impl Fn(&mut Window, &mut App) -> Entity<M> + 'static,
    ) -> Self;
    pub fn trigger<F, E>(self, e: F) -> Self
    where
        F: FnOnce(bool, &mut Window, &mut App) -> E + 'static,
        E: IntoElement + 'static;
}

impl<M: ManagedView> PopoverMenuHandle<M> {
    pub fn show(&self, window: &mut Window, cx: &mut App);
    pub fn hide(&self, cx: &mut App);
    pub fn toggle(&self, window: &mut Window, cx: &mut App);
    pub fn is_deployed(&self) -> bool;
    pub fn is_focused(&self, window: &Window, cx: &App) -> bool;
    pub fn refresh_menu(
        &self,
        window: &mut Window,
        cx: &mut App,
        new_menu_builder: Rc<dyn Fn(&mut Window, &mut App) -> Option<Entity<M>>>,
    );
}

impl<M: ManagedView> PopoverMenu<M> {
    pub fn new(id: impl Into<ElementId>) -> Self;
    pub fn menu(
        self,
        f: impl Fn(&mut Window, &mut App) -> Option<Entity<M>> + 'static,
    ) -> Self;
    pub fn trigger<T: PopoverTrigger>(self, t: T) -> Self;
    pub fn trigger_with_tooltip<T: PopoverTrigger + ButtonCommon>(
        self,
        t: T,
        tooltip_builder: impl Fn(&mut Window, &mut App) -> AnyView + 'static,
    ) -> Self;
}

impl ContextMenu {
    pub fn build(
        window: &mut Window,
        cx: &mut App,
        f: impl FnOnce(Self, &mut Window, &mut Context<Self>) -> Self,
    ) -> Entity<Self>;
    pub fn build_persistent(
        window: &mut Window,
        cx: &mut App,
        builder: impl Fn(Self, &mut Window, &mut Context<Self>) -> Self + 'static,
    ) -> Entity<Self>;
}
```

**Zed kullanım paritesi:** Activity indicator, file finder, status bar, pane tab
bar, git branch picker ve settings UI aynı modeli izler: trigger `Button` veya
`IconButton` ile kurulur, menü `ContextMenu::build(...)` içinde üretilir,
popover açıkken focus `ManagedView`/`DismissEvent` zinciriyle yönetilir.
Context menu'yu elde tutmak gerekiyorsa `PopoverMenuHandle<ContextMenu>` view
state'inde saklanır; sağ tık menülerinde `right_click_menu(id).trigger(...).menu(...)`
akışı kullanılır.

### Ortak trait ve sistem tipleri

| Tip | Kaynak | Not |
| :-- | :-- | :-- |
| `Component` | `crates/component/src/component.rs` | Component gallery kaydı ve preview sözleşmesi. |
| `ComponentScope` | `crates/component/src/component.rs` | Preview'ların kategori/scope ayrımı. |
| `RegisterComponent` | `crates/ui/src/prelude.rs` üzerinden `ui_macros` | Component registry'ye otomatik kayıt için derive makrosu. |
| `RenderOnce` | `gpui`, `ui::prelude::*` içinde | Zed UI bileşenlerinde yaygın render modeli. |
| `ParentElement` | `gpui`, `ui::prelude::*` içinde | Slot/child kabul eden component'lerde kullanılır. |
| `Clickable` | `crates/ui/src/traits/clickable.rs` | `.on_click(...)` yüzeyi taşıyan bileşenler. |
| `Toggleable` / `ToggleState` | `crates/ui/src/traits/toggleable.rs` | Selected, unselected ve indeterminate state modeli. |
| `Disableable` | `crates/ui/src/traits/disableable.rs` | Disabled builder yüzeyi. |
| `FixedWidth` | `crates/ui/src/traits/fixed.rs` | Sabit genişlik davranışı. |
| `VisibleOnHover` | `crates/ui/src/traits/visible_on_hover.rs` | Hover grubuna bağlı görünürlük davranışı. |
| `StyledExt` | `crates/ui/src/traits/styled_ext.rs` | Flex, elevation, border ve debug background yardımcıları. |
| `CommonAnimationExt` | `crates/ui/src/traits/animation_ext.rs` | Döndürme animasyonu gibi ortak animation extension yüzeyi. |
| `Transformable` | `crates/ui/src/traits/transformable.rs` | Kaynakta `pub trait`, ancak `ui.rs` tarafından re-export edilmez; tüketici API'si olarak değil, `CommonAnimationExt` bound'u olarak değerlendirilir. |
| `LabelCommon` | `crates/ui/src/components/label/label_like.rs` | Label ailesinin ortak size/color/weight/truncation yüzeyi. |
| `ButtonCommon` | `crates/ui/src/components/button/button_like.rs` | Button ailesinin ortak accessor/builder yüzeyi: `id`, `style`, `size`, `tooltip`, `tab_index`, `layer`, `track_focus`. `Clickable + Disableable` supertrait. |
| `SelectableButton` | `crates/ui/src/components/button/button_like.rs` | `Button`, `IconButton`, `ButtonLike` için seçilebilirlik sözleşmesi. |
| `WithScrollbar` / `ScrollableHandle` | `crates/ui/src/components/scrollbar.rs` | Elementlere özel scrollbar bağlama ve scroll handle soyutlaması. |
| `IntoTableRow` | `crates/ui/src/components/data_table/table_row.rs` | `Vec<T>` değerlerini kolon sayısı doğrulanmış `TableRow<T>` tipine dönüştürme trait'i. |

### Kaynak indeksi

| Kategori | Bileşen / API | Tanım kaynağı | Export | Prelude | Preview |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Metin | `Label` | `crates/ui/src/components/label/label.rs` | `ui::Label` | Evet | Evet |
| Metin | `LabelLike` | `crates/ui/src/components/label/label_like.rs` | `ui::LabelLike` | Hayır | Evet |
| Metin | `Headline` | `crates/ui/src/styles/typography.rs` | `ui::Headline` | Evet | Evet |
| Metin | `HighlightedLabel` | `crates/ui/src/components/label/highlighted_label.rs` | `ui::HighlightedLabel` | Hayır | Evet |
| Metin | `LoadingLabel` | `crates/ui/src/components/label/loading_label.rs` | `ui::LoadingLabel` | Evet | Hayır |
| Metin | `SpinnerLabel` | `crates/ui/src/components/label/spinner_label.rs` | `ui::SpinnerLabel` | Hayır | Evet |
| Tasarım | `Color` | `crates/ui/src/styles/color.rs` | `ui::Color` | Evet | Evet |
| Buton | `Button` | `crates/ui/src/components/button/button.rs` | `ui::Button` | Evet | Evet |
| Buton | `IconButton` | `crates/ui/src/components/button/icon_button.rs` | `ui::IconButton` | Evet | Evet |
| Buton | `ButtonLike` | `crates/ui/src/components/button/button_like.rs` | `ui::ButtonLike` | Hayır | Evet |
| Buton | `SelectableButton` | `crates/ui/src/components/button/button_like.rs` | `ui::SelectableButton` | Evet | Trait |
| Buton | `ButtonLink` | `crates/ui/src/components/button/button_link.rs` | `ui::ButtonLink` | Hayır | Evet |
| Buton | `CopyButton` | `crates/ui/src/components/button/copy_button.rs` | `ui::CopyButton` | Hayır | Evet |
| Buton | `SplitButton` | `crates/ui/src/components/button/split_button.rs` | `ui::SplitButton` | Hayır | Hayır |
| Buton | `ToggleButtonGroup` | `crates/ui/src/components/button/toggle_button.rs` | `ui::ToggleButtonGroup` | Hayır | Evet |
| Buton | `ToggleButtonSimple` / `ToggleButtonWithIcon` | `crates/ui/src/components/button/toggle_button.rs` | `ui::ToggleButtonSimple`, `ui::ToggleButtonWithIcon` | Hayır | Yardımcı |
| Buton | `ButtonBuilder` / `ButtonConfiguration` | `crates/ui/src/components/button/toggle_button.rs` | `ui::ButtonBuilder`, `ui::ButtonConfiguration` | Hayır | Sealed helper |
| Buton | `KeybindingPosition` | `crates/ui/src/components/button/button_like.rs` | `ui::KeybindingPosition` | Hayır | Enum |
| İkon | `Icon` | `crates/ui/src/components/icon.rs` | `ui::Icon` | Evet | Evet |
| İkon | `DecoratedIcon` | `crates/ui/src/components/icon/decorated_icon.rs` | `ui::DecoratedIcon` | Hayır | Evet |
| İkon | `IconDecoration` | `crates/ui/src/components/icon/icon_decoration.rs` | `ui::IconDecoration` | Hayır | Hayır |
| İkon | `IconWithIndicator` | `crates/ui/src/components/icon.rs` | `ui::IconWithIndicator` | Hayır | Hayır |
| İkon | `AnyIcon` | `crates/ui/src/components/icon.rs` | `ui::AnyIcon` | Hayır | Enum |
| İkon | `IconName` | `crates/icons/src/icons.rs` | `ui::IconName` | Evet | Enum |
| İkon | `IconSize` | `crates/ui/src/components/icon.rs` | `ui::IconSize` | Evet | Enum |
| Form / Toggle | `Checkbox` | `crates/ui/src/components/toggle.rs` | `ui::Checkbox` | Hayır | Evet |
| Form / Toggle | `Switch` | `crates/ui/src/components/toggle.rs` | `ui::Switch` | Hayır | Evet |
| Form / Toggle | `SwitchField` | `crates/ui/src/components/toggle.rs` | `ui::SwitchField` | Hayır | Evet |
| Form / Input | `InputField` | `crates/ui_input/src/input_field.rs` | `ui_input::InputField` | Hayır | Evet |
| Form / Toggle | `DropdownMenu` | `crates/ui/src/components/dropdown_menu.rs` | `ui::DropdownMenu` | Hayır | Evet |
| Menü / Popup | `ContextMenu` | `crates/ui/src/components/context_menu.rs` | `ui::ContextMenu` | Hayır | Hayır |
| Menü / Popup | `RightClickMenu` | `crates/ui/src/components/right_click_menu.rs` | `ui::RightClickMenu` | Hayır | Hayır |
| Menü / Popup | `Popover` | `crates/ui/src/components/popover.rs` | `ui::Popover` | Hayır | Hayır |
| Menü / Popup | `PopoverMenu` | `crates/ui/src/components/popover_menu.rs` | `ui::PopoverMenu` | Hayır | Hayır |
| Menü / Popup | `Tooltip` | `crates/ui/src/components/tooltip.rs` | `ui::Tooltip` | Hayır | Evet |
| Menü / Popup | `LinkPreview` / `tooltip_container` | `crates/ui/src/components/tooltip.rs` | `ui::LinkPreview`, `ui::tooltip_container` | Hayır | Yardımcı |
| Liste / Tree | `List` | `crates/ui/src/components/list/list.rs` | `ui::List` | Hayır | Evet |
| Liste / Tree | `ListItem` | `crates/ui/src/components/list/list_item.rs` | `ui::ListItem` | Hayır | Evet |
| Liste / Tree | `ListHeader` | `crates/ui/src/components/list/list_header.rs` | `ui::ListHeader` | Hayır | Evet |
| Liste / Tree | `ListSubHeader` | `crates/ui/src/components/list/list_sub_header.rs` | `ui::ListSubHeader` | Hayır | Evet |
| Liste / Tree | `ListSeparator` | `crates/ui/src/components/list/list_separator.rs` | `ui::ListSeparator` | Hayır | Hayır |
| Liste / Tree | `ListBulletItem` | `crates/ui/src/components/list/list_bullet_item.rs` | `ui::ListBulletItem` | Hayır | Evet |
| Liste / Tree | `TreeViewItem` | `crates/ui/src/components/tree_view_item.rs` | `ui::TreeViewItem` | Hayır | Evet |
| Liste / Tree | `StickyItems` | `crates/ui/src/components/sticky_items.rs` | `ui::StickyItems` | Hayır | Hayır |
| Liste / Tree | `IndentGuides` | `crates/ui/src/components/indent_guides.rs` | `ui::IndentGuides` | Hayır | Hayır |
| Tab | `Tab` | `crates/ui/src/components/tab.rs` | `ui::Tab` | Hayır | Evet |
| Tab | `TabBar` | `crates/ui/src/components/tab_bar.rs` | `ui::TabBar` | Hayır | Evet |
| Layout | `h_flex` / `v_flex` | `crates/ui/src/components/stack.rs` | `ui::h_flex`, `ui::v_flex` | Evet | Fonksiyon |
| Layout | `h_group*` / `v_group*` | `crates/ui/src/components/group.rs` | `ui::h_group*`, `ui::v_group*` | Evet | Fonksiyon |
| Layout | `Divider` | `crates/ui/src/components/divider.rs` | `ui::Divider` | Hayır | Evet |
| Layout | `Scrollbars` | `crates/ui/src/components/scrollbar.rs` | `ui::Scrollbars`, `ui::ScrollAxes`, `ui::ScrollbarStyle`, `ui::scrollbars::{ShowScrollbar, ScrollbarVisibility, ScrollbarAutoHide}` | Hayır | Yardımcı |
| Layout | `WithScrollbar` / `on_new_scrollbars` | `crates/ui/src/components/scrollbar.rs` | `ui::WithScrollbar`, `ui::on_new_scrollbars` | Hayır | Trait / setup |
| GPUI primitive | `Div` / `div` | `crates/gpui/src/elements/div.rs` | `gpui::Div`, `gpui::div` | Evet | Primitive |
| GPUI primitive | `Styled` / `ParentElement` / `InteractiveElement` | `crates/gpui/src/styled.rs`, `crates/gpui/src/element.rs`, `crates/gpui/src/elements/div.rs` | `gpui::*` | Evet | Trait |
| GPUI primitive | `canvas` / `Canvas` | `crates/gpui/src/elements/canvas.rs` | `gpui::canvas`, `gpui::Canvas` | Evet | Primitive |
| GPUI primitive | `img` / `Img` / `ImageSource` / `StyledImage` | `crates/gpui/src/elements/img.rs` | `gpui::img`, `gpui::Img`, `gpui::ImageSource`, `gpui::StyledImage` | Evet | Primitive |
| GPUI primitive | `svg` / `Svg` / `Transformation` | `crates/gpui/src/elements/svg.rs` | `gpui::svg`, `gpui::Svg`, `gpui::Transformation` | Evet | Primitive |
| GPUI primitive | `anchored` / `Anchored` | `crates/gpui/src/elements/anchored.rs` | `gpui::anchored`, `gpui::Anchored` | Evet | Primitive |
| GPUI primitive | `deferred` / `Deferred` | `crates/gpui/src/elements/deferred.rs` | `gpui::deferred`, `gpui::Deferred` | Evet | Primitive |
| GPUI primitive | `surface` / `Surface` | `crates/gpui/src/elements/surface.rs` | `gpui::surface`, `gpui::Surface` | Evet | macOS primitive |
| GPUI primitive | `list` / `ListState` | `crates/gpui/src/elements/list.rs` | `gpui::list`, `gpui::ListState` | Evet | Variable-height virtualization |
| GPUI primitive | `uniform_list` / `UniformListScrollHandle` | `crates/gpui/src/elements/uniform_list.rs` | `gpui::uniform_list`, `gpui::UniformListScrollHandle` | Evet | Uniform virtualization |
| GPUI primitive | `StyledText` / `TextLayout` / `InteractiveText` | `crates/gpui/src/elements/text.rs` | `gpui::StyledText`, `gpui::TextLayout`, `gpui::InteractiveText` | Evet | Rich text primitive |
| Veri | `Table` | `crates/ui/src/components/data_table.rs` | `ui::Table` | Hayır | Evet |
| Veri | `TableInteractionState` | `crates/ui/src/components/data_table.rs` | `ui::TableInteractionState` | Hayır | State |
| Veri | `ColumnWidthConfig` | `crates/ui/src/components/data_table.rs` | `ui::ColumnWidthConfig` | Hayır | Enum |
| Veri | `StaticColumnWidths` | `crates/ui/src/components/data_table.rs` | `ui::StaticColumnWidths` | Hayır | Enum |
| Veri | `ResizableColumnsState` | `crates/ui/src/components/data_table.rs` | `ui::ResizableColumnsState` | Hayır | State |
| Veri | `RedistributableColumnsState` | `crates/ui/src/components/redistributable_columns.rs` | `ui::RedistributableColumnsState` | Hayır | State |
| Veri | `TableResizeBehavior` | `crates/ui/src/components/redistributable_columns.rs` | `ui::TableResizeBehavior` | Hayır | Enum |
| Veri | `TableRow` | `crates/ui/src/components/data_table/table_row.rs` | `ui::table_row::TableRow` | Hayır | Yardımcı tip |
| Veri | `IntoTableRow` | `crates/ui/src/components/data_table/table_row.rs` | `ui::table_row::IntoTableRow` | Hayır | Trait |
| Veri | `render_table_row` / `render_table_header` | `crates/ui/src/components/data_table.rs` | `ui::render_table_row`, `ui::render_table_header` | Hayır | Fonksiyon |
| Veri | `bind_redistributable_columns` | `crates/ui/src/components/redistributable_columns.rs` | `ui::bind_redistributable_columns` | Hayır | Fonksiyon |
| Veri | `render_redistributable_columns_resize_handles` | `crates/ui/src/components/redistributable_columns.rs` | `ui::render_redistributable_columns_resize_handles` | Hayır | Fonksiyon |
| Feedback | `Banner` | `crates/ui/src/components/banner.rs` | `ui::Banner` | Hayır | Evet |
| Feedback | `Callout` | `crates/ui/src/components/callout.rs` | `ui::Callout` | Hayır | Evet |
| Feedback | `Modal` | `crates/ui/src/components/modal.rs` | `ui::Modal` | Hayır | Hayır |
| Feedback | `ModalHeader` / `ModalFooter` / `ModalRow` | `crates/ui/src/components/modal.rs` | `ui::ModalHeader`, `ui::ModalFooter`, `ui::ModalRow` | Hayır | Hayır |
| Feedback | `Section` / `SectionHeader` | `crates/ui/src/components/modal.rs` | `ui::Section`, `ui::SectionHeader` | Hayır | Hayır |
| Feedback | `AlertModal` | `crates/ui/src/components/notification/alert_modal.rs` | `ui::AlertModal` | Hayır | Evet |
| Feedback | `AnnouncementToast` | `crates/ui/src/components/notification/announcement_toast.rs` | `ui::AnnouncementToast` | Hayır | Evet |
| Feedback | `CountBadge` | `crates/ui/src/components/count_badge.rs` | `ui::CountBadge` | Hayır | Evet |
| Feedback | `Indicator` | `crates/ui/src/components/indicator.rs` | `ui::Indicator` | Hayır | Evet |
| Feedback | `ProgressBar` | `crates/ui/src/components/progress/progress_bar.rs` | `ui::ProgressBar` | Hayır | Evet |
| Feedback | `CircularProgress` | `crates/ui/src/components/progress/circular_progress.rs` | `ui::CircularProgress` | Hayır | Evet |
| Diğer | `Avatar` | `crates/ui/src/components/avatar.rs` | `ui::Avatar` | Hayır | Evet |
| Diğer | `AvatarAudioStatusIndicator` | `crates/ui/src/components/avatar.rs` | `ui::AvatarAudioStatusIndicator`, `ui::AudioStatus` | Hayır | Yardımcı |
| Diğer | `AvatarAvailabilityIndicator` | `crates/ui/src/components/avatar.rs` | `ui::AvatarAvailabilityIndicator`, `ui::CollaboratorAvailability` | Hayır | Yardımcı |
| Diğer | `Facepile` | `crates/ui/src/components/facepile.rs` | `ui::Facepile` | Hayır | Evet |
| Diğer | `Chip` | `crates/ui/src/components/chip.rs` | `ui::Chip` | Hayır | Evet |
| Diğer | `DiffStat` | `crates/ui/src/components/diff_stat.rs` | `ui::DiffStat` | Hayır | Evet |
| Diğer | `Disclosure` | `crates/ui/src/components/disclosure.rs` | `ui::Disclosure` | Hayır | Evet |
| Diğer | `GradientFade` | `crates/ui/src/components/gradient_fade.rs` | `ui::GradientFade` | Hayır | Hayır |
| Diğer | `Vector` / `VectorName` | `crates/ui/src/components/image.rs` | `ui::Vector`, `ui::VectorName` | Hayır | Evet |
| Diğer | `KeyBinding` | `crates/ui/src/components/keybinding.rs` | `ui::KeyBinding` | Hayır | Evet |
| Diğer | `KeybindingHint` | `crates/ui/src/components/keybinding_hint.rs` | `ui::KeybindingHint` | Hayır | Evet |
| Diğer | `Navigable` | `crates/ui/src/components/navigable.rs` | `ui::Navigable` | Hayır | Hayır |
| AI / Collab | `AiSettingItem` | `crates/ui/src/components/ai/ai_setting_item.rs` | `ui::AiSettingItem` | Hayır | Evet |
| AI / Collab | `AiSettingItemStatus` / `AiSettingItemSource` | `crates/ui/src/components/ai/ai_setting_item.rs` | `ui::AiSettingItemStatus`, `ui::AiSettingItemSource` | Hayır | Enum |
| AI / Collab | `AgentSetupButton` | `crates/ui/src/components/ai/agent_setup_button.rs` | `ui::AgentSetupButton` | Hayır | Impl var / `None` |
| AI / Collab | `ThreadItem` | `crates/ui/src/components/ai/thread_item.rs` | `ui::ThreadItem` | Hayır | Evet |
| AI / Collab | `AgentThreadStatus` / `ThreadItemWorktreeInfo` | `crates/ui/src/components/ai/thread_item.rs` | `ui::AgentThreadStatus`, `ui::ThreadItemWorktreeInfo`, `ui::WorktreeKind` | Hayır | Yardımcı |
| AI / Collab | `ConfiguredApiCard` | `crates/ui/src/components/ai/configured_api_card.rs` | `ui::ConfiguredApiCard` | Hayır | Evet |
| AI / Collab | `ParallelAgentsIllustration` | `crates/ui/src/components/ai/parallel_agents_illustration.rs` | `ui::ParallelAgentsIllustration` | Hayır | Hayır |
| AI / Collab | `CollabNotification` | `crates/ui/src/components/collab/collab_notification.rs` | `ui::CollabNotification` | Hayır | Evet |
| AI / Collab | `UpdateButton` | `crates/ui/src/components/collab/update_button.rs` | `ui::UpdateButton` | Hayır | Evet |
| Utils | `WithRemSize` | `crates/ui/src/utils/with_rem_size.rs` | `ui::utils::WithRemSize` | Hayır | Hayır |
| Utils | `SearchInputWidth` | `crates/ui/src/utils/search_input.rs` | `ui::utils::SearchInputWidth` | Hayır | Hayır |
| Utils | `CornerSolver` / `inner_corner_radius` | `crates/ui/src/utils/corner_solver.rs` | `ui::utils::CornerSolver`, `ui::utils::inner_corner_radius` | Hayır | Fonksiyon |
| Utils | `FormatDistance` / `DateTimeType` | `crates/ui/src/utils/format_distance.rs` | `ui::utils::FormatDistance`, `ui::utils::DateTimeType`, `ui::utils::format_distance`, `ui::utils::format_distance_from_now` | Hayır | Yardımcı |
| Utils | `apca_contrast` / `calculate_contrast_ratio` / `ensure_minimum_contrast` | `crates/ui/src/utils/apca_contrast.rs`, `crates/ui/src/utils/color_contrast.rs` | `ui::utils::apca_contrast`, `ui::utils::calculate_contrast_ratio`, `ui::utils::ensure_minimum_contrast` | Hayır | Fonksiyon |
| Utils | `is_light` / `capitalize` / `reveal_in_file_manager_label` | `crates/ui/src/utils.rs` | `ui::utils::is_light`, `ui::utils::capitalize`, `ui::utils::reveal_in_file_manager_label` | Hayır | Fonksiyon |
| Utils | `platform_title_bar_height` / `TRAFFIC_LIGHT_PADDING` | `crates/ui/src/utils/constants.rs` | `ui::utils::platform_title_bar_height`, `ui::utils::TRAFFIC_LIGHT_PADDING` | Hayır | Sabit |
| Utils | `BASE_REM_SIZE_IN_PX` / `EDITOR_SCROLLBAR_WIDTH` | `crates/ui/src/styles/units.rs`, `crates/ui/src/components/scrollbar.rs` | `ui::BASE_REM_SIZE_IN_PX`, `ui::EDITOR_SCROLLBAR_WIDTH` | Hayır | Sabit |

### Constructor envanteri

Başlangıç constructor listesi kaynak dosyalar üzerinde yapılan `awk` taramasıyla
doğrulandı. Ayrıntılı builder listeleri ilgili bileşen başlıklarında verilecek.

| Bileşen / API | Constructor veya giriş noktası |
| :-- | :-- |
| `Label` | `Label::new(label)` |
| `LabelLike` | `LabelLike::new()` |
| `Color` | `Color::Default`, `Color::Muted`, `Color::Accent`, `Color::Custom(hsla)` ve `.color(cx)` |
| `Headline` | `Headline::new(text)` |
| `HighlightedLabel` | `HighlightedLabel::new(label, highlight_indices)` |
| `LoadingLabel` | `LoadingLabel::new(text)` |
| `SpinnerLabel` | `SpinnerLabel::new()` |
| `Button` | `Button::new(id, label)` |
| `IconButton` | `IconButton::new(id, icon)` |
| `ButtonLike` | `ButtonLike::new(id)` |
| `ButtonLink` | `ButtonLink::new(label, link)` |
| `CopyButton` | `CopyButton::new(id, message)` |
| `SplitButton` | `SplitButton::new(left, right)` |
| `ToggleButtonSimple` | `ToggleButtonSimple::new(label, on_click)` ve `.selected(selected)` |
| `ToggleButtonWithIcon` | `ToggleButtonWithIcon::new(label, icon, on_click)` ve `.selected(selected)` |
| `Icon` | `Icon::new(icon)`, `Icon::from_path(path)`, `Icon::from_external_svg(svg)` |
| `DecoratedIcon` | `DecoratedIcon::new(icon, decoration)` |
| `IconDecoration` | `IconDecoration::new(kind, knockout_color, cx)` |
| `IconWithIndicator` | `IconWithIndicator::new(icon, Option<Indicator>)` |
| `AnyIcon` | `AnyIcon::Icon(icon)`, `AnyIcon::AnimatedIcon(animation_element)` ve `From<Icon>`, `From<AnimationElement<Icon>>` dönüşümleri; `.map(|icon| ...)` ile içeriği dönüştürür |
| `Checkbox` | `Checkbox::new(id, checked)` veya `checkbox(id, state)` |
| `Switch` | `Switch::new(id, state)` veya `switch(id, state)` |
| `SwitchField` | `SwitchField::new(id, label: Option<impl Into<SharedString>>, description: Option<SharedString>, state: impl Into<ToggleState>, on_click)` |
| `InputField` | `ui_input::InputField::new(window, cx, placeholder_text)` |
| `DropdownMenu` | `DropdownMenu::new(id, label, menu)` veya `DropdownMenu::new_with_element(id, label, menu)` |
| `ContextMenu` | `ContextMenu::new(window, cx, builder)` veya `ContextMenu::build(window, cx, builder)` |
| `RightClickMenu` | `right_click_menu(id)` |
| `Popover` | `Popover::new()` |
| `PopoverMenu` | `PopoverMenu::new(id)` |
| `Tooltip` | `Tooltip::new(title)` |
| `LinkPreview` | `LinkPreview::new(url, cx) -> AnyView` |
| `DocumentationAside` | `DocumentationAside::new(side: DocumentationSide, render: Rc<dyn Fn(&mut App) -> AnyElement>)`; `DocumentationSide::Left` veya `Right` |
| `List` | `List::new()` |
| `ListItem` | `ListItem::new(id)` |
| `ListHeader` | `ListHeader::new(label)` |
| `ListSubHeader` | `ListSubHeader::new(label)` |
| `ListSeparator` | `ListSeparator` |
| `ListBulletItem` | `ListBulletItem::new(label)` |
| `TreeViewItem` | `TreeViewItem::new(id, label)` |
| `sticky_items` | `sticky_items(entity, compute_fn, render_fn)` |
| `indent_guides` | `indent_guides(indent_size, colors)` |
| `Tab` | `Tab::new(id)` |
| `TabBar` | `TabBar::new(id)` |
| `h_flex` / `v_flex` | `h_flex()`, `v_flex()` |
| `h_group*` / `v_group*` | `h_group_sm()`, `h_group()`, `h_group_lg()`, `h_group_xl()` ve dikey karşılıkları |
| `Divider` | `divider()`, `vertical_divider()` |
| `div` / `Div` | `div()`; ham GPUI container primitive'i |
| `canvas` / `Canvas` | `canvas(prepaint, paint)` |
| `img` / `Img` | `img(source)`, `Img::extensions()` |
| `image_cache` | `image_cache(provider)`, `retain_all(id)`, `RetainAllImageCache::new(cx)` |
| `svg` / `Svg` | `svg()` |
| `anchored` / `Anchored` | `anchored()` |
| `deferred` / `Deferred` | `deferred(child)` |
| `surface` / `Surface` | `surface(source)` |
| `list` / `ListState` | `list(state, render_item)`, `ListState::new(...)` |
| `uniform_list` | `uniform_list(id, item_count, render_item)`, `UniformListScrollHandle::new()` |
| `StyledText` / `InteractiveText` | `StyledText::new(text)`, `InteractiveText::new(styled_text, window, cx)` |
| `Scrollbars` | `Scrollbars::new(show_along)`, `Scrollbars::always_visible(show_along)`, `Scrollbars::for_settings::<S>()` |
| `Table` | `Table::new(cols)` |
| `TableInteractionState` | `TableInteractionState::new(cx)` |
| `ColumnWidthConfig` | `ColumnWidthConfig::auto()`, `ColumnWidthConfig::auto_with_table_width(width)`, `ColumnWidthConfig::explicit(widths)`, `ColumnWidthConfig::redistributable(columns_state)` |
| `ResizableColumnsState` | `ResizableColumnsState::new(cols, initial_widths, resize_behavior)` |
| `RedistributableColumnsState` | `RedistributableColumnsState::new(...)` |
| `TableRow` | `TableRow::from_vec(data, expected_length)`, `TableRow::try_from_vec(data, expected_length)`, `TableRow::from_element(element, length)` |
| `Banner` | `Banner::new()` |
| `Callout` | `Callout::new()` |
| `Modal` | `Modal::new(id, scroll_handle)` |
| `ModalHeader` / `ModalFooter` / `ModalRow` | `ModalHeader::new()`, `ModalFooter::new()`, `ModalRow::new()` |
| `Section` / `SectionHeader` | `Section::new()`, `Section::new_contained()`, `SectionHeader::new(label)` |
| `AlertModal` | `AlertModal::new(id)` |
| `AnnouncementToast` | `AnnouncementToast::new()` |
| `CountBadge` | `CountBadge::new(count)` |
| `Indicator` | `Indicator::dot()`, `Indicator::bar()`, `Indicator::icon(icon)` |
| `ProgressBar` | `ProgressBar::new(id, value, max_value, cx)` |
| `CircularProgress` | `CircularProgress::new(value, max_value, size, cx)` |
| `Avatar` | `Avatar::new(src)` |
| `AvatarAudioStatusIndicator` | `AvatarAudioStatusIndicator::new(audio_status)` |
| `AvatarAvailabilityIndicator` | `AvatarAvailabilityIndicator::new(availability)` |
| `Facepile` | `Facepile::new(faces)` |
| `Chip` | `Chip::new(label)` |
| `DiffStat` | `DiffStat::new(id, added, removed)` |
| `Disclosure` | `Disclosure::new(id, is_open)` |
| `GradientFade` | `GradientFade::new(base_bg, hover_bg, active_bg)` |
| `Vector` | `Vector::new(vector, width, height)` |
| `KeyBinding` | `KeyBinding::new(action, focus_handle, cx)` |
| `Key` / `KeyIcon` | `Key::new(key, color)`, `KeyIcon::new(icon, color)` |
| `KeybindingHint` | `KeybindingHint::new(keybinding, background_color)` |
| `NavigableEntry` / `Navigable` | `NavigableEntry::new(scroll_handle, cx)`, `Navigable::new(child)` |
| `AiSettingItem` | `AiSettingItem::new(id, label, status, source)` |
| `AgentSetupButton` | `AgentSetupButton::new(id)` |
| `ThreadItem` | `ThreadItem::new(id, title)` |
| `ConfiguredApiCard` | `ConfiguredApiCard::new(label)` |
| `ParallelAgentsIllustration` | `ParallelAgentsIllustration::new()` |
| `CollabNotification` | `CollabNotification::new(avatar_uri, accept_button, dismiss_button)` |
| `UpdateButton` | `UpdateButton::new(icon, message)` |
| `WithRemSize` | `WithRemSize::new(rem_size: impl Into<Pixels>)` |
| `CornerSolver` | `CornerSolver::new(root_radius, root_border, root_padding)` ve `.add_child(border, padding).corner_radius(level)` |
| `FormatDistance` | `FormatDistance::new(date, base_date)`, `FormatDistance::from_now(date)` |

### Public metod denetim notları

Kaynak taramasında public görünen ama genellikle builder bölümünde değil,
state/helper bölümünde kullanılan metodlar aşağıdaki tabloda izlenir. Yeni bir
Zed `ui` metodu eklendiğinde bu tablo veya ilgili bileşen başlığı aynı PR'da
güncellenmelidir.

| Kaynak | Metodlar | Rol |
| :-- | :-- | :-- |
| `styles/typography.rs` | `TextSize::pixels(cx)` | `TextSize` token'ını `Pixels` değerine çevirir |
| `styles/elevation.rs` | `ElevationIndex::on_elevation_bg(cx)`, `.darker_bg(cx)` | Elevation arka plan varyantlarını tema üzerinden çözer |
| `icon.rs` | `IconSize::square_components(window, cx)`, `IconSize::square(window, cx)`, `IconWithIndicator::indicator_color(color)` | İkon kare ölçüsü ve indicator rengi |
| `toggle.rs` | `Checkbox::container_size()` | Checkbox kutusu için sabit `Pixels` ölçüsü; satır hizalama için kullanılır |
| `divider.rs` | `Divider::render_solid(base, cx)`, `Divider::render_dashed(base)` | `Divider` render stratejisi; normal kullanımda `divider()` / `vertical_divider()` yeterlidir |
| `modal.rs` | `Modal::show_back(bool)`, `ModalHeader::show_back_button(bool)`, `Section::contained(bool)` | Modal seviyesinde geri butonunu açma, header'a back button ikonu ekleme ve `Section` border'lı yüzey toggle'ı |
| `tab_bar.rs` | `TabBar::start_children_mut()`, `TabBar::end_children_mut()` | Builder zinciri dışından TabBar başlangıç/bitiş child listelerini mutably düzenler (`SmallVec<[AnyElement; 2]>`) |
| `scrollbar.rs` | `ScrollbarAutoHide::should_hide()` | Scrollbar otomatik gizleme kararını okuyan global token; `Global` olarak set/get edilir |
| `data_table.rs` | `ColumnWidthConfig::table_width(window, cx)`, `ColumnWidthConfig::list_horizontal_sizing(window, cx)`, `ResizableColumnsState::reset_column_to_initial_width(col_idx)`, `Table::map_row(callback)`, `Table::empty_table_callback(callback)` | Table genişliği, horizontal sizing ve kolon reset helper'ları; `Table` üzerinde satır/empty callback'leri |
| `redistributable_columns.rs` | `TableResizeBehavior::is_resizable()`, `HeaderResizeInfo::reset_column(col_idx, window, cx)`, `RedistributableColumnsState::reset_column_to_initial_width(column_index, window)` | Resize davranışı sorgusu, header bilgi paketi üzerinden reset ve kolon initial width'e dönüş |
| `context_menu.rs` | `ContextMenu::selected_index()`, `.confirm(...)`, `.secondary_confirm(...)`, `.cancel(...)`, `.end_slot(...)`, `.clear_selected()`, `.select_first(...)`, `.select_last(...)`, `.select_next(...)`, `.select_previous(...)`, `.select_submenu_child(...)`, `.select_submenu_parent(...)`, `.on_action_dispatch(...)`, `.on_blur_subscription(subscription)` | Menü action, seçim, submenu traversal, end slot ve blur subscription state yönetimi |

#### Denetim mantığı düzeltmesi

Son iki commit arasındaki farkın gösterdiği ana hata, public metotları yalnızca
**ada göre** denetlemekti. Bu yaklaşım, `key_binding` adının rehberde geçmesini
yeterli sayıyor ama bu metodun `Button` üzerinde mi, `Switch` üzerinde mi,
yoksa ortak trait üzerinde mi bulunduğunu doğrulamıyordu. Aynı hata
`TableInteractionState` / `ResizableColumnsState`,
`ModalHeader` / `ModalRow` / `Section` ve `TabBarSlot` / `TabBar` gibi owner
kaymalarını da gizler.

Bu turda yakalayamadığım eksiklerin kök nedenleri:

- Rehber başındaki Zed commit'i güncel pin ile eşleşmiyordu; doğrulama eski
  `db6039d815` varsayımından değil, gerçek `6e8eaab25b5ac324e11a82d1563dcad39c84bace`
  çalışma ağacından yapılmalıdır.
- `pub fn` grep'i, `crates/ui/src/components.rs` içindeki `pub use ...::*`
  zincirini ve nested modül re-export'larını tek tek takip etmiyordu.
- Inherent metotlar owner bilgisiyle taşınmadığı için aynı isimli metotlar
  birbirinin yerine geçmiş sayıldı.
- Trait implementasyonlarındaki public yüzey `impl Clickable for IconButton`
  gibi bloklarda `pub` taşımadığı için yalnızca `pub fn` taramasıyla eksik
  kaldı.
- Owner çıkaran state-machine brace depth izlemezse bir `impl` bloğundan sonra
  gelen serbest fonksiyonları önceki owner'a sızdırır. Bu nedenle imza taraması
  yalnız başlığı değil blok derinliğini de izlemelidir.
- `pub(crate)` ve sealed/internal tipler tüketici API'si gibi sayıldı; dış
  crate'in gerçekten çağırabildiği yüzey ayrıca filtrelenmelidir.
- Rehber yalnızca bileşen kaynaklarını okuduğunda `workspace`, `component`,
  `component_preview` ve uygulama içi gerçek kullanım akışını kaçırabiliyor.

Doğru kural: her metot `owner::method` veya `Trait for Type::method` çiftiyle,
her export ise `components.rs -> alt modül -> pub item` zinciriyle izlenir.

#### Commit sonrası doğrulama (`5cd8338`)

Bu dosyadaki önceki commit, kaynak üzerinde tekrar doğrulandı:

- `crates/ui/src/ui.rs`, `components`, `styles` ve `traits` modüllerini
  `mod` olarak tutup yalnızca `pub use ...::*` zinciriyle crate köküne ad
  taşır. Bu nedenle public yol denetiminde kaynak dosyanın `pub` yazması değil,
  export zincirinden geçip geçmediği esas alınır.
- `crates/ui/src/components.rs` içinde `stories` modülü yoktur. Tek undeclared
  dosya `crates/ui/src/components/stories.rs` olarak kalır; dosyanın içindeki
  `mod context_menu; pub use context_menu::*;` satırları build chain'e
  girmediği için public API değildir.
- `ScrollbarStyle::to_pixels(&self) -> Pixels`,
  `PlatformStyle::platform() -> Self` ve `ComponentFn::new(f: fn()) -> Self`
  `pub const fn` biçimindedir. Public metod taraması `pub fn` ile sınırlanırsa
  bu üç compile-time helper düşer.
- `sticky_items<V, T>(...) -> StickyItems<T>` ve
  `<T: StickyCandidate + Clone + 'static> StickyItems<T>::with_decoration(...)`
  imzaları `sticky_items.rs` ile eşleşir; `with_decoration` serbest fonksiyon
  değil, generic bound'lu `StickyItems<T>` inherent metodudur.
- `ui_input::ERASED_EDITOR_FACTORY` public static olarak `OnceLock<fn(&mut
  Window, &mut App) -> Arc<dyn ErasedEditor>>` tipindedir ve Zed'de
  `editor::init` sırasında `Editor::single_line(...)` adapter'ı ile kurulur.

Ek kapsam taraması, `crates/ui`, `crates/component` ve `crates/ui_input`
altındaki public item adları, public enum variant'ları ve public struct
alanları için rehberde isim seviyesinde yeni eksik göstermedi. Sadece standart
trait implementasyonlarından gelen `fmt`, `eq`, `index_mut` ve `into_element`
metotları kullanıcıya dönük builder/lifecycle API'si olarak listelenmez.
`component::COMPONENT_DATA`, `component::ComponentFn::new(...)` ve
`component::__private` ise `RegisterComponent` / `inventory` mekanizmasının
makro tarafına açık iç yüzeyi olarak açıklanır; normal uygulama kodu
`components()`, `component::init()` ve `register_component::<T>()` üzerinden
ilerler.

Bu hatayı önlemek için rehberdeki her API satırı şu üç sınıftan biriyle
eşleştirilmelidir:

- **Trait metodu:** `Clickable::cursor_style`, `ButtonCommon::tooltip`,
  `FixedWidth::width` gibi import edilen trait üzerinden gelir.
- **Inherent builder:** `Button::key_binding`,
  `DropdownMenu::no_chevron`, `ContextMenu::rebuild` gibi yalnızca ilgili
  struct'ın `impl` bloğunda vardır.
- **Sealed/internal yüzey:** `ButtonBuilder` public görünür ama
  `private::ToggleButtonStyle` supertrait'i nedeniyle dış crate'te implement
  edilemez; `ButtonLikeRounding::{ALL, LEFT, RIGHT}` ise `pub(crate)` tip
  üzerinde kaldığı için tüketici API'si değildir.

Pratik sonuç: Bir metodun adı başka başlıkta geçiyor diye kapsanmış sayılmaz.
Örneğin `Button::key_binding(...)` ve `Switch::key_binding(...)` ayrı ayrı
doğrulanır; `IconButton`, `ButtonLike` veya `SplitButton` için otomatik
geçerli kabul edilmez.

### Repo gerçekliği notları

- Kaynaklarda `Stack` ve `Group` adları public struct değil. Mevcut API
  `h_flex`, `v_flex`, `h_group*`, `v_group*` helper fonksiyonlarıdır.
- `Image` için `crates/ui/src/components/image.rs` içinde public `Image` struct
  yok. Bu dosya `Vector` ve `VectorName` export eder. Raster görsel için GPUI
  tarafındaki `img(...)` ve `ImageSource` ayrıca anlatılmalı.
- `Notification` adı `crates/ui/src/components/notification.rs` içinde public
  component olarak yok; dosya `AlertModal` ve `AnnouncementToast` modüllerini
  re-export eden bir modül dosyasıdır.
- Kaynakta public görünen `MenuHandleElementState`, `RequestLayoutState`,
  `PrepaintState`, `PopoverMenuElementState`, `PopoverMenuFrameState` ve
  `ScrollbarPrepaintState` tipleri kullanıcıya dönük component API'si değil,
  element prepaint/layout state taşıyıcılarıdır. Rehberde kullanım yüzeyi olarak
  öne çıkarılmaz.
- `ToggleButton` adı tekil bir public component değil. Kaynakta
  `ToggleButtonGroup<T, COLS, ROWS>`, `ToggleButtonSimple`,
  `ToggleButtonWithIcon`, `ButtonBuilder`, `ToggleButtonGroupStyle` ve
  `ToggleButtonGroupSize` bulunur.
- `ListBulletItem`, `ModalHeader`, `ModalRow`, `ModalFooter`, `Section`,
  `SectionHeader`, `IconWithIndicator`, `AvatarAudioStatusIndicator`,
  `AvatarAvailabilityIndicator`, `ParallelAgentsIllustration` ve scrollbar
  tipleri kaynakta public yardımcı yapılardır. İlgili bölümlerde yalnızca ana
  bileşenleri açıklamayı destekledikleri ölçüde ele
  alınacaklar.
- Preview desteği `impl Component for ...` ile işaretlendi. `ContextMenu`,
  `Popover`, `PopoverMenu`, `RightClickMenu`, `Modal`, `GradientFade`,
  `StickyItems`, `IndentGuides`, `Navigable`, `SplitButton`, `IconDecoration`,
  `LoadingLabel` ve `ListSeparator` için doğrudan component preview bulunmadı.
  `AgentSetupButton` için `impl Component` vardır, ancak `preview()` `None`
  döndürür. `Color`, `LabelLike` ve `ui_input::InputField` da component
  preview sistemine kayıtlıdır.
- `crates/ui/src/styles/animation.rs` içindeki `Animation` tipi yalnızca
  animation preview göstermek için kullanılan private bir component'tir; public
  kullanım yüzeyi `AnimationDuration`, `AnimationDirection` ve
  `DefaultAnimations` trait'idir.
- `crates/ui/src/traits/transformable.rs` içindeki `Transformable` kaynakta
  `pub` olsa da `ui.rs` bunu re-export etmez. Rehberde doğrudan
  `.transform(...)` tüketici API'si olarak gösterilmez; public kullanım
  `CommonAnimationExt` üzerinden rotation helper'larıdır.

### Doğrulama komutları

Bu envanter şu komutlarla doğrulandı:

```sh
git rev-parse HEAD
find crates/ui/src/components crates/ui/src/styles crates/ui/src/traits crates/ui_input/src crates/component/src crates/icons/src -name '*.rs' -print
rg -n '^pub use|^pub mod|^mod ' crates/ui/src/ui.rs crates/ui/src/components.rs crates/ui/src/styles.rs crates/ui/src/traits.rs crates/ui/src/utils.rs crates/ui/src/prelude.rs crates/ui/src/component_prelude.rs
rg -o '^pub (struct|enum|trait|fn|type|const) [A-Za-z0-9_]+' crates/ui/src/components crates/ui/src/styles crates/ui/src/traits crates/ui/src/utils.rs crates/ui/src/utils crates/component/src crates/ui_input/src
find crates/ui/src/components crates/ui/src/styles crates/ui_input/src crates/component/src -name '*.rs' -print0 | xargs -0 awk '/impl Component for |impl<T: ButtonBuilder.*Component/ { print FILENAME ":" FNR ":" $0 }'
find crates/ui/src/components crates/ui/src/styles/typography.rs crates/ui_input/src -name '*.rs' -print0 | xargs -0 awk '/pub fn (new|build|dot|checkbox|switch|divider|vertical_divider|h_flex|v_flex|h_group|right_click_menu|sticky_items|indent_guides)\\b/ { print FILENAME ":" FNR ":" $0 }'
rg -n 'Button::new|IconButton::new|ContextMenu::build|DropdownMenu::new|PopoverMenu::new|right_click_menu|Table::new|Modal::new|Switch::new|Checkbox::new|Tooltip::' crates/workspace crates/editor crates/project_panel crates/outline_panel crates/settings_ui crates/collab_ui crates/activity_indicator crates/notifications crates/file_finder crates/command_palette crates/recent_projects crates/git_ui
```

## 2. Ortak Kullanım Temelleri

Zed UI bileşenleri, GPUI element modelinin üstüne yerleşen daha kısıtlı ve daha
tutarlı bir tasarım sistemi katmanıdır. `div()`, `Render`, `RenderOnce`,
`IntoElement`, `Styled`, `ParentElement` ve event handler'lar GPUI'den gelir;
`Button`, `Label`, `Icon`, `Color`, `Severity`, `ButtonStyle`, `ToggleState`
gibi tipler ise Zed'in UI crate'inde tanımlıdır.

### Import düzeni

Zed içinde yeni UI kodu yazarken başlangıç import'u genellikle şudur:

```rust
use ui::prelude::*;
```

`ui::prelude::*`, `gpui::prelude::*` içeriğini de getirir ve bunun üstüne Zed
tasarım sistemiyle sık kullanılan tipleri ekler. Bu yüzden sıradan bir view veya
component örneğinde `Button`, `Icon`, `Label`, `Color`, `h_flex`, `v_flex`,
`Context`, `Window`, `App`, `SharedString`, `AnyElement` ve `RenderOnce` için ayrı
import gerekmez.

Prelude her şeyi getirmez. Daha özel bileşenleri açıkça import edin:

```rust
use ui::prelude::*;
use ui::{Callout, ContextMenu, DropdownMenu, List, ListItem, Tooltip};
```

`gpui::prelude::*` yalnızca GPUI primitive'leriyle çalışırken yeterlidir. Zed UI
bileşenleriyle çalışırken `ui::prelude::*` tercih edilmelidir; aksi halde
tasarım token'ları ve ortak component trait'leri eksik kalır.

### Render modeli

Zed UI bileşenlerinin çoğu `RenderOnce` implement eder. Bu model, state taşımayan
ve builder zinciriyle kurulan küçük UI parçaları için uygundur:

```rust
use ui::prelude::*;

fn render_status_title() -> impl IntoElement {
    v_flex()
        .gap_1()
        .child(Headline::new("Project Settings").size(HeadlineSize::Medium))
        .child(
            h_flex()
                .gap_1()
                .child(
                    Icon::new(IconName::Check)
                        .size(IconSize::Small)
                        .color(Color::Success),
                )
                .child(
                    Label::new("Saved")
                        .size(LabelSize::Small)
                        .color(Color::Muted),
                ),
        )
}
```

View state'i tutan ekran parçalarında `Render` kullanılır. Kullanıcı etkileşimi
view state'i değiştiriyorsa, render çıktısının yenilenmesi için `cx.notify()`
çağrılmalıdır:

```rust
use ui::prelude::*;

struct SettingsRow {
    enabled: bool,
}

impl Render for SettingsRow {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        h_flex()
            .gap_2()
            .child(Label::new("Enable diagnostics"))
            .child(
                IconButton::new("toggle-diagnostics", IconName::Check)
                    .toggle_state(self.enabled)
                    .on_click(cx.listener(|this: &mut SettingsRow, _, _, cx| {
                        this.enabled = !this.enabled;
                        cx.notify();
                    })),
            )
    }
}
```

### Temel veri tipleri

`ElementId`, component state'i ve hitbox takibi için kullanılan kararlı kimliktir.
Button, tab, list item, table row ve toggle gibi etkileşimli bileşenlerde anlamlı
ve çakışmayan id kullanın.

`SharedString`, UI metinleri için tercih edilen string tipidir. `&'static str`,
`String` veya `Arc<str>` kaynaklı metinleri gereksiz kopya üretmeden elementlere
taşımaya yarar.

`AnyElement`, farklı concrete element tiplerini tek slotta saklamak gerektiğinde
kullanılır. Örneğin bir list item'in start slot'u bazen `Icon`, bazen özel bir
`div()` olabilir. Public builder API'si generic `impl IntoElement` kabul ediyorsa
çağıran tarafta `AnyElement` üretmeye gerek yoktur.

`AnyView`, entity tabanlı ve dinamik view döndüren tooltip, popover veya preview
gibi API'lerde görülür. Bir view'in yaşam döngüsü GPUI entity sistemi tarafından
yönetiliyorsa `AnyView` elemente göre daha uygun yüzeydir.

`Entity<ContextMenu>`, `DropdownMenu` ve menü tabanlı popup'larda sık görülür.
Menü içeriği focus, blur ve action dispatch davranışı taşıdığı için düz
`AnyElement` yerine entity olarak tutulur:

```rust
use ui::prelude::*;
use ui::ContextMenu;

fn build_sort_menu(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |menu, _, _| {
        menu.header("Sort by")
            .entry("Name", None, |_, _| {})
            .entry("Modified", None, |_, _| {})
    })
}
```

### Tasarım token'ları

`Color`, tema bağımsız semantik metin ve ikon rengi seçmek için kullanılır.
`Color::Default`, `Muted`, `Hidden`, `Disabled`, `Placeholder`, `Accent`,
`Info`, `Success`, `Warning`, `Error`, `Hint`, `Created`, `Modified`,
`Deleted`, `Conflict`, `Ignored`, `Debugger`, `Player(u32)`, `Selected` ve
version-control renkleri etkin temadan gerçek HSLA değerine çevrilir. Version
control variant'ları açık adlarıyla `VersionControlAdded`,
`VersionControlModified`, `VersionControlDeleted`, `VersionControlConflict` ve
`VersionControlIgnored` olarak gelir; diff/file status UI'larında genel
`Created`/`Modified` yerine bunları tercih edin. Özel HSLA gerektiğinde
`Color::Custom` vardır, ancak tutarlılık için semantik renkler önceliklidir.
`Color` ayrıca `Component` preview'ı olan bir tasarım token'ıdır;
gallery'de tema renklerini karşılaştırmak için kullanılabilir.

`Severity`, mesaj ve feedback bileşenlerinde durum seviyesini ifade eder:
`Info`, `Success`, `Warning`, `Error`. `Banner` ve `Callout` gibi bileşenler bu
seviyeyi arka plan, ikon ve vurgu rengine bağlar.

`IconName`, `crates/icons/src/icons.rs` içinde tanımlanan gömülü ikon adıdır.
`Icon::new(IconName::Check)` gibi kullanılır. Harici ikon teması veya SVG gerektiğinde
`Icon::from_path(...)` ve `Icon::from_external_svg(...)` vardır.

Boyut token'larını component ailesine göre seçin:

- Metin için `LabelSize` ve başlık için `HeadlineSize`.
- İkon için `IconSize`.
- Buton için `ButtonSize`.
- Progress veya özel çizim yüzeylerinde gerektiğinde `Pixels` veya `Rems`.

Buton görünümü için `ButtonStyle` kullanılır. `Subtle` varsayılan seçimdir,
`Filled` daha güçlü vurgu için, `Tinted(TintColor::...)` semantik durumlar için,
`Outlined` ve `OutlinedGhost` ikincil eylemler için uygundur.

Toggle state'i `ToggleState` ile ifade edilir. `bool` doğrudan `ToggleState`'e
dönüşebilir; üç durumlu seçimlerde `ToggleState::Indeterminate` veya
`ToggleState::from_any_and_all(any_checked, all_checked)` kullanın.

Transparent veya blurred tema kullanan pencere yüzeylerinde arka plan davranışını
ayırmak için `ui::theme_is_transparent(cx)` yardımcı fonksiyonunu kullanın. Bu
fonksiyon etkin `WindowBackgroundAppearance` değeri `Transparent` veya `Blurred`
ise `true` döner; custom yüzeylerde opak fallback gerekip gerekmediğini seçmek
için uygundur.

### Spacing token'ları (`DynamicSpacing`)

Padding, margin ve gap değerleri için elle `px(...)` veya `rems(...)` yazmak
yerine `crates/ui/src/styles/spacing.rs` içinde tanımlı `DynamicSpacing`
ölçeğini tercih edin. Bu enum kullanıcının UI yoğunluk ayarına (`Compact`,
`Default`, `Comfortable`) göre tek noktadan ölçek değiştirir.

- Adlandırma: `Base00`, `Base01`, `Base02`, `Base03`, `Base04`, `Base06`,
  `Base08`, `Base12`, `Base16`, `Base20`, `Base24`, `Base32`, `Base40`,
  `Base48`. `BaseXX`, `XX` değeri varsayılan yoğunlukta yaklaşık pixel
  değeridir (`Base04 ≈ 4px`, `Base16 ≈ 16px`).
- Kullanım: `.gap(DynamicSpacing::Base02.px(cx))`,
  `.p(DynamicSpacing::Base06.rems(cx))`.
- Üç değer manuel verildiğinde (örn. `(1, 1, 2)`) yoğunluğa göre değişir;
  tek değer verilirse `(n-4, n, n+4)` formülü uygulanır.
- Mevcut ui density'i `ui::ui_density(cx)` ile sorgulayabilirsiniz; bu döner
  değer yalnızca görsel kararlar için kullanılmalı, doğrudan spacing
  hesaplamak için değil.

Sabit aralık gerektiğinde `gap_0p5`, `gap_1`, `gap_1p5`, `gap_2` gibi GPUI
yardımcıları yeterlidir; bu sabitler `h_group*` ve `v_group*` helper'larının
arkasında kullanılır.

### Yükseklik / elevation token'ları (`ElevationIndex`)

`crates/ui/src/styles/elevation.rs`'teki `ElevationIndex`, bir yüzeyin görsel
"z-axis" konumunu ifade eder. Doğru elevation, doğru shadow, background ve
border kombinasyonunu otomatik üretir.

- `Background`: uygulamanın en alt zemini.
- `Surface`: paneller, pane'ler, ana yüzey container'ları.
- `EditorSurface`: editable buffer yüzeyleri (genelde `Surface` ile aynı renk).
- `ElevatedSurface`: popover, dropdown gibi paneller üstünde yer alan yüzeyler.
- `ModalSurface`: dialog, alert, modal gibi uygulamayı geçici olarak kilitleyen
  yüzeyler.

Pratik builder'lar `StyledExt` üzerinden gelir:

- `.h_flex()` ve `.v_flex()`: herhangi bir `Styled` elementi yatay/dikey flex
  container'a çevirir; `h_flex` ayrıca `items_center()` uygular.
- `.elevation_1(cx)` ve `.elevation_1_borderless(cx)`: hafif yükseltilmiş yüzey.
- `.elevation_2(cx)` ve `.elevation_2_borderless(cx)`: popover, popovermenu,
  tooltip yüzeyi.
- `.elevation_3(cx)` ve `.elevation_3_borderless(cx)`: modal ve announcement
  yüzeyi.
- `.border_primary(cx)` ve `.border_muted(cx)`: tema `border` ve
  `border_variant` renklerini doğrudan `border_color(...)` olarak uygular.
- `.debug_bg_red()`, `.debug_bg_green()`, `.debug_bg_blue()`,
  `.debug_bg_yellow()`, `.debug_bg_cyan()`, `.debug_bg_magenta()`: layout
  geliştirirken geçici arka plan rengi verir. Production UI'da bırakılmamalıdır.

`Popover` `.elevation_2(cx)`, `AnnouncementToast` `.elevation_3(cx)` kullanır.
Kendi modal/dialog yüzeyini elden kurarken aynı yardımcıları çağırın; aksi
halde shadow ve background görsel tutarlılığı bozulur.

### Platform stili (`PlatformStyle`)

`crates/ui/src/styles/platform.rs`'teki `PlatformStyle`, render kararlarını
işletim sistemine göre soyutlamak için kullanılır.

- Değerler: `Mac`, `Linux`, `Windows`.
- Mevcut platformu öğrenmek için `PlatformStyle::platform()` (const fn).
- `KeyBinding::platform_style(...)` modifier ikonu vs. metin gösterimini
  bu enum'a göre seçer.

Platforma özel davranış kurarken `cfg!` makrolarını dağıtmak yerine
`PlatformStyle::platform()` döndüren değeri tek noktada saklayın; testlerde
bu değeri override etmek daha kolaydır.

### Tipografi yardımcıları (`StyledTypography`, `TextSize`)

`crates/ui/src/styles/typography.rs`, `Headline` ve `Label` dışında düz
`div()` üzerine de tema tutarlı tipografi uygulamak için `StyledTypography`
trait'ini sağlar. `Styled` implement eden her tip otomatik bu trait'i alır.

Sık kullanılan yöntemler:

- `.font_ui(cx)` ve `.font_buffer(cx)`: tema UI/buffer fontunu uygular.
- `.text_ui_lg(cx)`, `.text_ui(cx)`, `.text_ui_sm(cx)`, `.text_ui_xs(cx)`:
  `Large`, `Default`, `Small`, `XSmall` boyutlarını seçer.
- `.text_buffer(cx)`: kullanıcının buffer font size'ını uygular.
- `.text_ui_size(TextSize::Editor, cx)` gibi serbest seçim.

`TextSize` değerleri ve karşılık geldikleri rem değerleri (16px = 1rem):

| `TextSize` | rem | px |
| :-- | :-- | :-- |
| `Large` | `rems_from_px(16.)` | `16` |
| `Default` | `rems_from_px(14.)` | `14` |
| `Small` | `rems_from_px(12.)` | `12` |
| `XSmall` | `rems_from_px(10.)` | `10` |
| `Ui` | settings'teki ui_font_size | dinamik |
| `Editor` | settings'teki buffer_font_size | dinamik |

`Label` ve `Headline` zaten doğru tipografiyi uygular; `div()` veya `h_flex()`
gibi yapı taşlarına metin yazıyorsanız `font_ui` + `text_ui_*` çağırmadan
bırakmayın. Aksi halde font ailesi sistemden devralınır ve tema değişikliği
yansımaz.

### Animasyon yardımcıları

`crates/ui/src/styles/animation.rs` küçük UI animasyonlarını standart
süreler ve yönlerle kurmak için bir trait sağlar.

- `AnimationDuration`: `Instant` (50ms), `Fast` (150ms), `Slow` (300ms).
- `AnimationDirection`: `FromBottom`, `FromLeft`, `FromRight`, `FromTop`.
- `DefaultAnimations` trait yöntemleri: `.animate_in(direction, fade_in)`,
  `.animate_in_from_bottom(fade)`, `.animate_in_from_top(fade)`,
  `.animate_in_from_left(fade)`, `.animate_in_from_right(fade)`.

`DefaultAnimations`, `Styled + Element` implement eden her tipe otomatik
bağlanır. Daha karmaşık animasyonlar için GPUI'nin `Animation`,
`AnimationExt`, `with_animation(...)` ve `with_animations(...)` yapılarını
doğrudan kullanın; `LoadingLabel`, `SpinnerLabel`, `AiSettingItem` ve
`ThreadItem::Running` durumu bu yolla animasyon uygular.

`ui::CommonAnimationExt` prelude içinde değildir, ancak crate kökünden export
edilir. `use ui::CommonAnimationExt as _;` ile import edildiğinde
`Transformable` implement eden bileşenlere `.with_rotate_animation(duration)` ve
`.with_keyed_rotate_animation(id, duration)` yardımcılarını ekler. Liste veya
tekrarlı item içinde aynı animasyon birden çok kez render edilecekse keyed
varyantı kullanın; varsayılan varyant call site konumunu element id olarak alır.

### `CommonAnimationExt` ve transform kısıtı

`crates/ui/src/traits/transformable.rs` içindeki `Transformable`, kaynakta
`pub trait` olarak görünür, ancak `ui.rs` tarafından crate köküne re-export
edilmez ve `ui::prelude::*` içinde de yoktur. Bu yüzden tüketici kodu için
kararlı çağrı yüzeyi `.transform(...)` değildir.

Pratikte kullanılabilir public yüzey `ui::CommonAnimationExt`'tir:

```rust
use ui::{CommonAnimationExt as _, prelude::*};

fn render_loading_icon() -> impl IntoElement {
    Icon::new(IconName::LoadCircle)
        .size(IconSize::Small)
        .with_rotate_animation(2)
}
```

`Icon` ve `Vector` içeride `Transformable` implement eder; bu bound sayesinde
`.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id,
duration)` çalışır. Doğrudan dönüşüm builder'ı gerekli olursa mirror tarafta
ya `Transformable` bilinçli biçimde re-export edilmeli ya da `Icon::transform`
/ `Vector::transform` gibi inherent builder eklenmelidir. Zed pin'inde bu doğrudan
tüketici API'si değildir.

### `ui::utils` modülü

`crates/ui/src/utils.rs` public alt modüldür; `is_light`,
`reveal_in_file_manager_label` ve `capitalize` doğrudan burada yaşar, geri
kalanlar alt modüllerden `ui::utils::*` altında re-export edilir. Bu yardımcılar
`ui` crate kökünden re-export edilmez; doğru çağrı yolu `ui::utils::is_light`,
`ui::utils::WithRemSize`, `ui::utils::FormatDistance` gibi alt modül yoludur.
`BASE_REM_SIZE_IN_PX`, `EDITOR_SCROLLBAR_WIDTH`, `theme_is_transparent` ve
`ui_density` ise styles/components re-export zinciri üzerinden `ui::...`
kökünden erişilebilir.

Temalama ve görsel:

- `is_light(cx: &mut App) -> bool`: etkin temanın açık/koyu olduğunu söyler;
  custom canvas çizimlerinde uygun overlay rengini seçmek için kullanın.
- `theme_is_transparent(cx)` (styles modülünde): transparent veya blurred
  pencere arka planı için aynı işi yapar.

İçerik ve etiket yardımcıları:

- `capitalize(str: &str) -> String`: ilk karakteri büyük harfe çevirip yeni
  `String` döndürür; locale-aware değil, hızlı UI label normalleştirme için.
- `reveal_in_file_manager_label(is_remote: bool) -> &'static str`: macOS için
  `"Reveal in Finder"`, Windows için `"Reveal in File Explorer"`, diğer
  durumlarda `"Reveal in File Manager"` döndürür. `is_remote` true ise her
  zaman generic etiket döner.

Layout ve ölçü yardımcıları:

- `BASE_REM_SIZE_IN_PX: f32 = 16.0` (`styles/units.rs`): rem tabanlı
  hesaplamalarda referans değer.
- `EDITOR_SCROLLBAR_WIDTH: Pixels` (`components/scrollbar.rs`):
  `ScrollbarStyle::Editor.to_pixels()` sabiti; editor görselli scrollbar
  genişliğini diğer panelle hizalamak için kullanın.
- `TRAFFIC_LIGHT_PADDING: f32`: macOS pencere kontrolleri (kapat/küçült/büyüt)
  için title bar'da ayrılması gereken sol padding; SDK 26 öncesi 71px, sonrası
  78px sabittir.
- `platform_title_bar_height(window: &Window) -> Pixels`: Windows'ta sabit
  32px, diğer platformlarda `1.75 * window.rem_size()` (minimum 34px) döndürür.
- `inner_corner_radius(parent_radius, parent_border, parent_padding, self_border)
  -> Pixels`: iç içe geçmiş yuvarlatılmış köşeler için child radius hesaplar.
- `CornerSolver::new(root_radius, root_border, root_padding)` ve
  `.add_child(border, padding).corner_radius(level)`: birden fazla seviyeli
  nesting için aynı problemin batch çözümü.
- `SearchInputWidth::THRESHOLD_WIDTH` / `MAX_WIDTH` (her ikisi 1200px) ve
  `SearchInputWidth::calc_width(container_width)`: arama input'unun container
  genişliğine göre yayılma/sınırlandırma davranışı.
- `WithRemSize::new(rem_size)`: alt ağaca farklı bir rem boyutunu zorla
  uygulayan element; settings preview gibi kendi ölçeklemesini yöneten
  alanlarda kullanılır. `.occlude()` ile pointer event'lerini engeller.

Erişilebilirlik ve renk kontrastı:

- `calculate_contrast_ratio(fg: Hsla, bg: Hsla) -> f32`: WCAG 2 standardı
  kontrast oranı.
- `apca_contrast(text_color: Hsla, background_color: Hsla) -> f32`: APCA Lc
  (lightness contrast) ölçeği; pozitif değer normal polarity (koyu metin/açık
  arka plan), negatif değer ters polarity. Tipik eşikler: `Lc 45` UI metni
  minimumu, `Lc 60` küçük metin, `Lc 75` gövde metni.
- `ensure_minimum_contrast(foreground: Hsla, background: Hsla,
  minimum_apca_contrast: f32) -> Hsla`: foreground'un lightness'ını
  ayarlayarak verilen APCA eşiğini sağlayan en yakın rengi döndürür; tema
  derived renklerin okunabilir kalmasını garantilemek için ideal.

Tarih farkı yardımcıları (`format_distance` modülü):

- `DateTimeType::Naive(NaiveDateTime)` veya `DateTimeType::Local(DateTime<Local>)`.
  `.to_naive()` her ikisini de `NaiveDateTime`'a çevirir.
- `format_distance(date, base_date, include_seconds, add_suffix, hide_prefix)
  -> String`: iki tarih arası mesafeyi "less than a minute ago", "about 2
  hours ago", "3 months from now" gibi metne çevirir.
- `format_distance_from_now(datetime, include_seconds, add_suffix,
  hide_prefix) -> String`: aynı şey ama `base_date` olarak `Local::now()`
  kullanır.
- `FormatDistance::new(date, base_date).include_seconds(...).add_suffix(...)
  .hide_prefix(...)`: builder yüzeyi; thread item, git commit ve activity
  feed'lerde tercih edilir. Kaynak yorumu bu modülün ileride `time_format`
  crate'ine taşınacağını söyler; yeni kodda `time_format` çözümlerine de göz
  atın.

### Layout yardımcıları

`h_flex()` yatay flex container, `v_flex()` dikey flex container üretir. Bu
yardımcılar raw `div()` yerine okunabilirliği artırır ve Zed UI örneklerinde
yaygın kullanılır.

`h_group*` ve `v_group*` helper'ları yön ve tutarlı gap seçimini birlikte verir.
Tekrarlanan toolbar, ayar satırı veya kompakt kontrol gruplarında bu helper'ları
tercih edin.

Raw `div()` hala geçerlidir. Özel grid, absolute positioning, canvas veya çok
spesifik style gerektiğinde doğrudan `div()` kullanmak daha açıktır.

### Hata yönetimi

UI olay işleyicilerinden veya async task'larından dönen `Result` değerleri
sessizce yutulmamalıdır. Tutarlı bir kuralı izleyin:

- Çağıran fonksiyon `Result` taşıyabiliyorsa hatayı `?` ile yayın.
- View içinde fire-and-forget bir task çalıştırıyorsanız hatayı log'a
  düşürmek için `task.detach_and_log_err(cx)` kullanın; `task.detach()` hatayı
  yok eder ve sebebi tespit edilemez.
- Async iş bitiminde view state'ini güncellemeniz gerekiyorsa task'ı view
  struct'ı içinde `Task<anyhow::Result<()>>` alanı olarak saklayın ve task
  içinde `this.update(cx, ...)?` ile entity'ye geri dönün. Bu pattern Bölüm
  12'de "Ayarlar Paneli Satırı" örneğinde uygulanır.
- Tek seferlik async sonucu kullanıcıya göstermeniz gerekiyorsa hatayı
  `last_error: Option<SharedString>` gibi bir state alanına yazıp
  `Callout` veya `Banner` ile sunun. Görsel state değiştiği için
  `cx.notify()` çağırmayı unutmayın.
- `unwrap()`, `expect(...)` ve `let _ = ...?` yerine açık eşleştirme yapın.
  `let _ =` üretim kodunda yalnızca hatayı bilinçli yok etmek istediğiniz
  ender durumlarda kabul edilir; o durumda da yorum satırıyla nedenini
  belirtin.

`anyhow::Result` ve `anyhow::Context` Zed crate'lerinde standarttır.
`?` operatörü ile hata yayıyorsanız mesaja `with_context(|| ...)` ekleyerek
log'da kaynağı görünür yapın.

### Component preview

Component preview sistemi, bileşen varyantlarını Zed içinde görsel olarak
incelemek için kullanılır. Sistem `crates/component` crate'i tarafından
yönetilir ve üç parçadan oluşur: `Component` trait'i, `ComponentRegistry`
global'i ve `single_example` / `example_group_with_title` gibi layout
helper'ları.

Zed uygulamasında bu sistem iki seviyede yönetilir:

- `workspace::init(app_state, cx)` içinde `component::init()` çağrılır. Bu,
  `inventory::iter::<ComponentFn>()` ile `RegisterComponent` derive'larından
  gelen kayıt fonksiyonlarını çalıştırır ve `COMPONENT_DATA` registry'sini
  doldurur.
- `crates/zed/src/main.rs` normal uygulama açılışında
  `component_preview::init(app_state.clone(), cx)` çağırır; standalone preview
  örneği de aynı şekilde önce `component::init()`, sonra settings/theme init,
  workspace init ve `component_preview::init(...)` sırasını izler.
- `ComponentPreview::new(...)` registry'yi `components()` ile okur,
  `sorted_components()` ve `component_map()` değerlerini kendi view state'ine
  alır, filter editor için `InputField::new(window, cx, "Find components or usages…")`
  kurar ve listeyi `ListState` ile sanallaştırır.
- Render tarafında preview sayfası `ComponentMetadata::preview()` callback'ini
  çağırır; callback `None` ise component kayıtlı kalır ama gallery'de örnek
  alanı çizmez. `AgentSetupButton` bunun bilinçli örneğidir.

Bu nedenle uygulama içi component sistemi runtime UI dependency injection
mekanizması değil, **görsel denetim ve dokümantasyon registry'si**dir.
Production ekranları component'leri doğrudan `ui::Button`,
`ui::ContextMenu`, `ui::Table` gibi builder'larla kullanır; component registry
yalnızca preview tool ve dokümantasyon/arama ekranları için devrededir.

`ui::prelude::*` yalnızca `Component`, `ComponentScope`, `example_group`,
`example_group_with_title`, `single_example` ve `RegisterComponent` derive
makrosunu getirir. Programatik registry erişimi (`ComponentRegistry`,
`ComponentMetadata`, `ComponentStatus`, `ComponentId`, `register_component`,
`empty_example`, `ComponentExample`, `ComponentExampleGroup`, `ComponentFn`)
gerektiğinde `use component::*;` veya doğrudan tek tek import yapın.

`Component` trait'in tam yüzeyi (her metot opsiyonel; derive makrosu
varsayılan implementasyon kullanır):

| Metot | Dönen | Varsayılan | Kullanım |
| :-- | :-- | :-- | :-- |
| `id() -> ComponentId` | `ComponentId(name)` | Otomatik | Registry lookup'u için stable kimlik; aynı görünür ada sahip iki bileşeni ayırt etmek için override edilir |
| `scope() -> ComponentScope` | `ComponentScope::None` | Override edilir | Gallery'de grup başlığını belirler |
| `status() -> ComponentStatus` | `ComponentStatus::Live` | İhtiyaca göre | Gallery filtreleme ve "production'a hazır mı?" işareti |
| `name() -> &'static str` | `type_name::<Self>()` | Genelde override | Gallery'de görünen ad; `type_name` modül yolunu da içerir |
| `sort_name() -> &'static str` | `Self::name()` | Bilinçli sıralama isteniyorsa override | İlişkili bileşenleri sıralı tutmak için (örn. `ButtonA`, `ButtonB`, `ButtonC`) |
| `description() -> Option<&'static str>` | `None` | Doc comment veya elle string | `documented::Documented` derive ile doc comment otomatik description olur |
| `preview(window, cx) -> Option<AnyElement>` | `None` | Genelde override | Gallery'de gösterilen örnek alanı |

`ComponentScope` tüm variant listesi (gallery'deki grup başlıkları):

```text
Agent, Collaboration, DataDisplay ("Data Display"), Editor,
Images ("Images & Icons"), Input ("Forms & Input"),
Layout ("Layout & Structure"), Loading ("Loading & Progress"),
Navigation, None ("Unsorted"), Notification,
Overlays ("Overlays & Layering"), Onboarding, Status,
Typography, Utilities, VersionControl ("Version Control")
```

`ComponentStatus` variant listesi ve anlamları:

| Variant | Anlam | Gallery davranışı |
| :-- | :-- | :-- |
| `Live` (varsayılan) | Üretimde kullanılabilir | Normal listelenir |
| `WorkInProgress` | Hâlâ tasarlanıyor veya kısmi implement | "WIP" badge'i; üretim kodunda kullanılmamalı |
| `EngineeringReady` | Tasarım tamamlandı, implementasyon bekliyor | "Ready to Build" badge'i |
| `Deprecated` | Yeni kodda kullanılmamalı | Uyarı badge'i; ileride kaldırılabilir |

Preview'a dahil edilecek küçük bir örnek component şu yapıyı izler:

```rust
use ui::component_prelude::*;
use ui::prelude::*;

#[derive(IntoElement, RegisterComponent)]
struct ExampleButtonSet;

impl RenderOnce for ExampleButtonSet {
    fn render(self, _window: &mut Window, _cx: &mut App) -> impl IntoElement {
        h_flex()
            .gap_1()
            .child(Button::new("default", "Default"))
            .child(Button::new("primary", "Primary").style(ButtonStyle::Filled))
            .child(IconButton::new("settings", IconName::Settings))
    }
}

impl Component for ExampleButtonSet {
    fn scope() -> ComponentScope {
        ComponentScope::Input
    }

    fn preview(_window: &mut Window, _cx: &mut App) -> Option<AnyElement> {
        Some(
            example_group_with_title(
                "Buttons",
                vec![single_example("Button set", ExampleButtonSet.into_any_element())],
            )
            .into_any_element(),
        )
    }
}
```

Preview kodunda `scope()` bileşenin gallery'de hangi grupta gösterileceğini
belirler. `preview()` herhangi bir `AnyElement` döndürebilir; tek bir örnek için
`single_example`, ilişkili varyantları gruplayarak göstermek için
`example_group_with_title` kullanılır.

Preview'ları Zed reposunda görsel olarak incelemek için:

```sh
cargo run -p component_preview --example component_preview
```

Çalıştırılan örnek pencere, `RegisterComponent` derive ile kayda alınmış tüm
bileşenleri sol panelden gezilebilir kategoriler (`ComponentScope`) altında
listeler. Yeni bir bileşene preview eklediğinizde derive makrosu kaydı kendisi
yapar; ayrı bir kayıt çağrısı gerekmez. Preview için doğrudan `impl Component`
yazan tipler (struct olmadan) gallery'ye eklenmez; en az boş bir
`#[derive(IntoElement, RegisterComponent)] struct ExampleComponent;` ile sarın.

**Programatik registry erişimi.** Component preview tool'u, dokümantasyon
üretici veya custom gallery yazıyorsanız `component` crate'inin registry
API'sine doğrudan erişebilirsiniz:

```rust
use component::{
    ComponentId, ComponentMetadata, ComponentRegistry, ComponentScope,
    ComponentStatus, components, init as init_components, register_component,
};

fn list_registered_buttons() {
    init_components();
    let registry: ComponentRegistry = components();

    for meta in registry.sorted_components() {
        if meta.scope() != ComponentScope::Input {
            continue;
        }
        if meta.status() != ComponentStatus::Live {
            continue;
        }
        println!(
            "{} ({}): {}",
            meta.name(),
            meta.id().0,
            meta.description().unwrap_or_else(|| "—".into()),
        );
    }
}
```

`ComponentRegistry` yüzeyi:

| Metot | Dönen | Kullanım |
| :-- | :-- | :-- |
| `previews() -> Vec<&ComponentMetadata>` | Preview verilmiş bileşenler | Gallery liste kaynağı |
| `sorted_previews() -> Vec<ComponentMetadata>` | Aynı, `sort_name`'e göre sıralı | Stabil sıralı liste |
| `components() -> Vec<&ComponentMetadata>` | Tüm kayıtlı bileşenler (preview'sız dahil) | Programatik denetim |
| `sorted_components() -> Vec<ComponentMetadata>` | Aynı, sıralı | Stabil sıralı |
| `component_map() -> HashMap<ComponentId, ComponentMetadata>` | Id → metadata haritası | Lookup |
| `get(id) -> Option<&ComponentMetadata>` | Id ile lookup | Tek bileşen sorgusu |
| `len() -> usize` | Toplam kayıt sayısı | Test asersiyonu |

`ComponentMetadata` accessor'ları: `id()`, `name()`, `description()`,
`preview()`, `scope()`, `sort_name()`, `scopeless_name()`, `status()`.

`register_component::<T>()` çağrısı `RegisterComponent` derive'ı yapmayan
tipler için manuel kayıt sunar; derive kullanıyorsanız çağırmaya gerek yok.
`init_components()` ise `inventory` ile toplanan otomatik kayıtları
çalıştırır ve registry global'ini hazırlar.

**Layout helper detayları.** Preview alanını kurarken üç farklı çıktı
tipi vardır:

```rust
use component::{
    ComponentExample, ComponentExampleGroup, empty_example,
    example_group, example_group_with_title, single_example,
};

// Tek varyant
let example: ComponentExample =
    single_example("Default", Button::new("d", "Default").into_any_element())
        .description("Birincil eylem için varsayılan stil.")
        .width(px(160.));

// Boş slot (henüz implement edilmemiş varyant)
let placeholder: ComponentExample = empty_example("Coming Soon");

// Başlıksız grup
let group: ComponentExampleGroup = example_group(vec![example, placeholder])
    .vertical();

// Başlıklı grup
let titled: ComponentExampleGroup = example_group_with_title(
    "Variants",
    vec![
        single_example("Subtle", Button::new("s", "Subtle").into_any_element()),
        single_example("Filled",
            Button::new("f", "Filled").style(ButtonStyle::Filled).into_any_element()),
    ],
)
.grow();
```

`ComponentExample` builder yüzeyi: `.description(text)`, `.width(pixels)`.
`ComponentExampleGroup` builder yüzeyi: `.width(pixels)`, `.grow()`,
`.vertical()`, `with_title(title, examples)` constructor'ı.

`ComponentExample` public alanları: `variant_name`, `description`, `element`,
`width`. Normal kullanımda bu alanları elle mutasyona açmak yerine
`single_example(...)`, `empty_example(...)`, `.description(...)` ve
`.width(...)` helper'larını kullanın. `variant_name` gallery'de görünen varyant
başlığıdır; test ve dokümantasyon üretici kodlarında doğrudan okunabilir.

`ComponentExampleGroup` public alanları: `title`, `examples`, `width`, `grow`,
`vertical`. Bunlar `RenderOnce` sırasında layout kararına çevrilir; üretim
preview kodunda builder metodları daha okunur.

**Component preview / preview helper sözleşmesi.** Bileşeninizin
`preview()` metodu `Option<AnyElement>` döndürür. `None` döndürmek, "bu
bileşen registry'de kayıtlı ama gallery'de gösterme" anlamına gelir;
örneğin `AgentSetupButton` `impl Component` taşır ama `preview()` `None`
döner. Yine de `RegisterComponent` derive'ı sayesinde `components()` ile
listelenebilir.

**`description()` ile doc comment otomasyonu.** `documented::Documented`
derive'ı eklenirse doc comment'in `Self::DOCS` sabitinden okunup
description olur:

```rust
use documented::Documented;

/// Birincil eylemler için varsayılan buton.
#[derive(IntoElement, RegisterComponent, Documented)]
struct PrimaryButtonExample;

impl Component for PrimaryButtonExample {
    fn description() -> Option<&'static str> {
        Some(Self::DOCS)
    }
}
```

### Zed uygulamasında component yönetimi

Zed'de `crates/ui` bileşenleri runtime'da merkezi bir "component manager"
tarafından yaratılmaz. Normal uygulama ekranlarında akış GPUI'nindir:
view/entity state'i `Render` implementasyonunda tutulur, küçük stateless UI
parçaları `RenderOnce` builder'larıyla oluşturulur ve `ui::prelude::*` ya da
doğrudan `use ui::{...}` import'larıyla çağrılır. `Button::new`,
`IconButton::new`, `ListItem::new`, `ContextMenu::build`,
`PopoverMenu::new`, `Scrollbars::for_settings` ve `Table::new` gibi
constructor'lar Zed uygulama crate'lerinde doğrudan kullanılır.

Component preview ise ayrı bir registry akışıdır:

- `../zed/crates/workspace/src/workspace.rs` içinde `workspace::init(...)`,
  başlangıçta `component::init()` çağırır. Bu çağrı `inventory` ile toplanan
  tüm `ComponentFn` kayıtlarını çalıştırır.
- `#[derive(RegisterComponent)]`, `ui_macros` üzerinden her component için
  `component::register_component::<T>()` çağıran bir kayıt fonksiyonu üretir
  ve bunu `component::__private::inventory::submit!` ile registry'ye ekler.
- `../zed/crates/component/src/component.rs`, registry global'ini
  `COMPONENT_DATA: LazyLock<RwLock<ComponentRegistry>>` olarak tutar.
  Tüketici kodu doğrudan global'e değil `components()`,
  `register_component::<T>()` ve `ComponentRegistry` accessor'larına gider.
- `../zed/crates/zed/src/main.rs`, normal uygulama açılışında
  `component_preview::init(app_state.clone(), cx)` çağırır. Bu, workspace'e
  `OpenComponentPreview` action'ını ve `ComponentPreview` serializable item'ını
  kaydeder.
- `../zed/crates/component_preview/src/component_preview.rs`,
  `components().sorted_components()` ile listeyi alır, `component_map()` ile
  id lookup haritası kurar, `InputField` ile filtreler, `ListItem` /
  `ListSubHeader` / `HighlightedLabel` ile sol navigasyonu render eder ve
  preview alanında `ComponentMetadata::preview()` fonksiyonunu çağırır.
- Aynı dosya active page bilgisini `ComponentPreviewDb` üzerinden
  `component_previews` tablosunda saklar; preview item split/restore sırasında
  `SerializableItem` implementasyonu bu state'i geri yükler.

Gerçek uygulama kullanımı için okuma sırası:

1. Builder imzası ve export yolu için önce `crates/ui/src/components.rs` ile
   ilgili alt modül dosyasını okuyun.
2. Registry/preview davranışı için `crates/component`, `ui_macros` ve
   `crates/component_preview` akışını okuyun.
3. Uygulama kompozisyonu için component'in Zed'deki gerçek çağrı yerlerine
   bakın. Örnekler: `title_bar` menü trigger'ları, `project_panel`
   scrollbars/list item kullanımı, `keymap_editor` data table kullanımı,
   `git_ui` branch/commit picker'ları, `workspace::notifications` toast ve
   notification frame kullanımı.

Bu ayrım önemlidir: `impl Component for T`, üretim ekranındaki lifecycle'ı
değil preview/gallery metadata'sını anlatır. Üretim ekranındaki lifecycle
GPUI `Entity`, `Context`, `Window`, `FocusHandle`, `Task` ve gerektiğinde
workspace katmanındaki `ModalLayer`, notification stack veya popover/menu
state handle'ları tarafından yönetilir.

## 3. Metin ve İkon Bileşenleri

Metin ve ikon bileşenleri Zed UI içinde en sık kullanılan yapı taşlarıdır. Başlık,
etiket, arama sonucu, durum satırı, liste item'i, toolbar ve bildirim gibi çoğu
kompozisyon bu bileşenlerden başlar.

Genel kural:

- Yapısal başlık için `Headline`.
- Normal UI metni için `Label`.
- Hazır label slot modeli yetmediğinde, sınırlı custom metin yüzeyi için
  `LabelLike`.
- Arama veya fuzzy match vurgusu için `HighlightedLabel`.
- İşlem devam ederken metinle geri bildirim vermek için `LoadingLabel`.
- Yalnızca yükleme göstergesi gerektiğinde `SpinnerLabel`.
- Simgeler için `Icon`; simgenin üstünde durum işareti gerekiyorsa
  `DecoratedIcon` ve `IconDecoration`.

### Label

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/label.rs`
- Ortak stil yüzeyi: `../zed/crates/ui/src/components/label/label_like.rs`
- Export: `ui::Label`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: `impl Component for Label`

Ne zaman kullanılır:

- Buton dışındaki kısa UI metinleri, açıklamalar, metadata, durum metinleri ve
  liste satırı metinleri için.
- Tema ile uyumlu renk, boyut, ağırlık ve truncation gereken her yerde.
- Metin içinde backtick ile işaretlenmiş küçük kod parçalarını göstermek için
  `render_code_spans()`.

Ne zaman kullanılmaz:

- Ekran veya bölüm başlığı gerekiyorsa `Headline` daha uygun.
- Metnin bir kısmı arama sonucuna göre vurgulanacaksa `HighlightedLabel`
  kullanılmalı.
- Tamamen özel rich text veya çok biçimli uzun içerik gerekiyorsa GPUI'nin
  `StyledText` / text primitive'leri daha doğrudan olabilir.

Temel API:

- Constructor: `Label::new(label: impl Into<SharedString>)`
- Sık builder'lar: `.size(LabelSize::...)`, `.color(Color::...)`,
  `.weight(FontWeight::...)`, `.italic()`, `.underline()`, `.strikethrough()`,
  `.alpha(f32)`, `.truncate()`, `.truncate_start()`, `.single_line()`,
  `.buffer_font(cx)`, `.inline_code(cx)`, `.render_code_spans()`.
- Mutator: `.set_text(text: impl Into<SharedString>)` `&mut self` üzerinden
  label metnini günceller; `Label` view alanında saklanıyorsa render dışından
  yeni `Label` üretmeden metni değiştirmek için kullanılır. Builder zincirinde
  değil, mevcut instance üzerinde çağrılır.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`,
  `.flex_shrink()`, `.flex_shrink_0()` ve margin style yöntemleri.
- Trait: `LabelCommon`.

Davranış:

- `RenderOnce` implement eder.
- `LabelCommon` ayarlarını `LabelLike` üzerinden uygular.
- `single_line()` newline karakterlerini tek satırda gösterilecek şekilde
  dönüştürür.
- `render_code_spans()` metindeki eşleşen backtick çiftlerini kaldırır ve bu
  aralıkları buffer fontuyla, element background rengiyle vurgular.

Örnekler:

```rust
use ui::prelude::*;

fn render_file_metadata(path: SharedString) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_1()
        .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate())
        .child(Label::new("modified").size(LabelSize::Small).color(Color::Warning))
}
```

```rust
use ui::prelude::*;

fn render_command_hint() -> impl IntoElement {
    Label::new("Run `zed --new` to open a fresh window.")
        .render_code_spans()
        .size(LabelSize::Small)
        .color(Color::Muted)
}
```

Zed içinden kullanım:

- `../zed/crates/recent_projects/src/recent_projects.rs`: proje adı, branch ve path
  metinlerinde `Label` ve `HighlightedLabel` birlikte kullanılır.
- `../zed/crates/remote_connection/src/remote_connection.rs`: uyarı ve durum
  satırlarında `Icon` + `Label` kompozisyonu kullanılır.
- `../zed/crates/git_ui/src/git_panel.rs`: status, commit ve branch
  metadata'larında `Label` yoğun biçimde kullanılır.

Dikkat edilecekler:

- Uzun metni dar container içinde kullanırken `.truncate()` veya
  `.truncate_start()` ekleyin; aksi halde satır taşması layout'u bozabilir.
- `Label::new(format!(...))` pratik olsa da sık render edilen listelerde hazır
  `SharedString` veya önceden üretilmiş metin kullanmak gereksiz allocation'ı
  azaltır.
- Tüm satırı monospace yapmak için `.buffer_font(cx)` veya `.inline_code(cx)`;
  yalnızca backtick içindeki parçaları vurgulamak için `.render_code_spans()`
  kullanın.

### LabelLike

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/label_like.rs`
- Export: `ui::LabelLike`
- Prelude: Hayır, `use ui::LabelLike;` ekleyin.
- Preview: `impl Component for LabelLike`

Ne zaman kullanılır:

- `Label` veya `HighlightedLabel` yeterli değilse, ama yine de `LabelCommon`
  renk/boyut/ağırlık/truncation kurallarını koruyan özel bir metin yüzeyi
  gerekiyorsa.
- Birden fazla child element içeren, label gibi davranan küçük inline
  kompozisyonlarda.

Ne zaman kullanılmaz:

- Düz metin için `Label`, arama vurgusu için `HighlightedLabel` daha tutarlı ve
  daha kısıtlıdır.
- Komple özel rich text, editor metni veya selectable text gerekiyorsa GPUI text
  primitive'leri daha uygun olabilir.

Temel API:

- Constructor: `LabelLike::new()`
- `LabelCommon`: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.line_height_style(...)`, `.italic()`, `.underline()`, `.strikethrough()`,
  `.alpha(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.
- Ek builder: `.truncate_start()`
- `ParentElement` implement eder; `.child(...)` ve `.children(...)` alır.
- `LineHeightStyle`: `TextLabel` varsayılan label/buffer line-height davranışı,
  `UiLabel` ise line-height `1` olan kompakt UI etiketi davranışıdır.

Davranış:

- `RenderOnce` implement eder.
- `Label` ailesinin kullandığı iç stil yüzeyidir; UI font weight'i, semantic
  `Color` ve `LabelSize` değerlerini aynı şekilde uygular.
- Serbest child kabul ettiği için tutarsız tipografi üretmek kolaydır; hazır
  label'ların yetmediği durumlarla sınırlayın.

Örnek:

```rust
use ui::prelude::*;
use ui::LabelLike;

fn render_inline_hint(action: SharedString, cx: &App) -> impl IntoElement {
    LabelLike::new()
        .size(LabelSize::Small)
        .color(Color::Muted)
        .child("Press ")
        .child(Label::new(action).inline_code(cx))
}
```

### Headline

Kaynak:

- Tanım: `../zed/crates/ui/src/styles/typography.rs`
- Export: `ui::Headline`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: `impl Component for Headline`

Ne zaman kullanılır:

- Modal başlığı, panel başlığı, onboarding başlığı ve section başlığı gibi görsel
  hiyerarşi kuran kısa metinler için.

Ne zaman kullanılmaz:

- Satır içi metadata, küçük açıklama veya body metni için `Label` kullanın.
- Çok renkli veya rich text başlık gerekiyorsa `Label`, `StyledText` veya özel
  element kompozisyonu daha açıktır.

Temel API:

- Constructor: `Headline::new(text: impl Into<SharedString>)`
- Builder yöntemleri: `.size(HeadlineSize::...)`, `.color(Color::...)`
- Boyutlar: `XSmall`, `Small`, `Medium`, `Large`, `XLarge`.

Davranış:

- `RenderOnce` implement eder.
- UI fontunu kullanır.
- `HeadlineSize` rem tabanlı font size ve sabit headline line-height üretir.

Örnek:

```rust
use ui::prelude::*;

fn render_panel_title() -> impl IntoElement {
    v_flex()
        .gap_0p5()
        .child(Headline::new("Extensions").size(HeadlineSize::Large))
        .child(
            Label::new("Manage installed language extensions.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension başlıkları ve
  sayfa başlıkları.
- `../zed/crates/ui/src/components/modal.rs`: modal header içinde.
- `../zed/crates/workspace/src/theme_preview.rs`: typography preview alanında.

Dikkat edilecekler:

- Mevcut kaynakta `Headline::color(...)` alanı set eder, ancak `render` içinde
  renk olarak doğrudan `cx.theme().colors().text` kullanılır. Renkli başlık
  davranışına ihtiyaç varsa kaynak değişene kadar `Label` veya özel `div()`
  kompozisyonuyla açık renk uygulayın.

### HighlightedLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/highlighted_label.rs`
- Export: `ui::HighlightedLabel`
- Prelude: Hayır, `use ui::HighlightedLabel;` ekleyin.
- Preview: `impl Component for HighlightedLabel`

Ne zaman kullanılır:

- Fuzzy search, picker, dosya/branch arama sonucu ve filtrelenmiş liste
  satırlarında eşleşen karakterleri vurgulamak için.

Ne zaman kullanılmaz:

- Vurgulanacak aralık yoksa normal `Label` daha basit.
- Vurgu byte pozisyonları yerine semantic span veya rich text gerekiyorsa
  doğrudan `StyledText` kullanmak daha esnek olabilir.

Temel API:

- Constructor: `HighlightedLabel::new(label, highlight_indices)`
- Range constructor: `HighlightedLabel::from_ranges(label, highlight_ranges)`
- Düşük seviye yardımcı:
  `highlight_ranges(text: &str, indices: &[usize], style: HighlightStyle)
  -> Vec<(Range<usize>, HighlightStyle)>`. Ardışık byte indekslerini char
  sınırlarına oturmuş tek bir range içinde birleştirir. `HighlightedLabel`
  bunu içeride kullanır; aynı dönüşümü `StyledText` veya custom rich text
  yüzeylerinde tekrar etmek için import edebilirsiniz.
- Okuma yöntemleri: `.text()`, `.highlight_indices()`
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.italic()`, `.underline()`, `.truncate()`, `.single_line()`.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`,
  `.flex_shrink()`, `.flex_shrink_0()`.

Davranış:

- `RenderOnce` implement eder.
- Vurgular tema accent text rengiyle çizilir.
- `highlight_indices` UTF-8 byte pozisyonlarıdır. `new(...)`, her pozisyonun
  geçerli char boundary olup olmadığını assert eder.

Örnekler:

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_search_result(highlight_indices: Vec<usize>) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_2()
        .child(Icon::new(IconName::MagnifyingGlass).size(IconSize::Small))
        .child(
            HighlightedLabel::new("Open Recent Project", highlight_indices)
                .size(LabelSize::Small)
                .truncate()
                .flex_1(),
        )
}
```

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_prefix_match() -> impl IntoElement {
    HighlightedLabel::from_ranges("workspace settings", vec![0..9])
        .size(LabelSize::Small)
}
```

Zed içinden kullanım:

- `../zed/crates/recent_projects/src/recent_projects.rs`: son projelerde proje
  adı eşleşmeleri.
- `../zed/crates/git_ui/src/branch_picker.rs`: branch adı eşleşmeleri.
- `../zed/crates/outline_panel/src/outline_panel.rs`: sembol ve path
  eşleşmeleri.

Dikkat edilecekler:

- `highlight_indices` karakter sırası değil byte offset listesidir. Türkçe veya
  emoji gibi çok byte'lı karakterlerde rasgele indeks üretmeyin; matcher'dan
  gelen byte pozisyonlarını veya `from_ranges` ile geçerli byte aralıklarını
  kullanın.
- `new(...)` geçersiz UTF-8 sınırında panic eden `assert!` içerir. Kullanıcı
  girdisinden üretilen pozisyonları önce doğrulamak gerekir.

### LoadingLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/loading_label.rs`
- Export: `ui::LoadingLabel`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: Doğrudan `impl Component for LoadingLabel` yok.

Ne zaman kullanılır:

- Bir async işlem sürerken metni kademeli gösteren ve sonunda nokta animasyonu
  yapan kısa durum label'ları için.
- "Loading credentials", "Connecting", "Generating commit" gibi tek satırlık
  durumlar için.

Ne zaman kullanılmaz:

- Sadece ikon/spinner gerekiyorsa `SpinnerLabel` veya animasyonlu `Icon`.
- Belirli progress oranı varsa `ProgressBar` veya `CircularProgress`.

Temel API:

- Constructor: `LoadingLabel::new(text)`
- `LabelCommon` builder'ları: `.size(...)`, `.weight(...)`,
  `.line_height_style(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.

Davranış:

- `RenderOnce` implement eder.
- İlk animasyonda metni soldan sağa görünür hale getirir; sonraki animasyonda
  metne `.`, `..`, `...` ekleyerek tekrar eder.
- Render sırasında label rengini `Color::Muted` yapar.

Örnek:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn render_loading_credentials() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::new().size(LabelSize::Small))
        .child(LoadingLabel::new("Loading credentials").size(LabelSize::Small))
}
```

Dikkat edilecekler:

- Kaynakta `LoadingLabel` `LabelCommon::color(...)` implement eder, ancak render
  içinde son aşamada `Color::Muted` uygular. Renge güvenmeniz gerekiyorsa normal
  `Label` ve ayrı spinner kompozisyonu kullanın.
- Bu component bir async task başlatmaz; yalnızca görsel animasyon sağlar.

### SpinnerLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/spinner_label.rs`
- Export: `ui::SpinnerLabel`
- Prelude: Hayır, `use ui::SpinnerLabel;` ekleyin.
- Preview: `impl Component for SpinnerLabel`

Ne zaman kullanılır:

- Kompakt alanlarda metinsiz yükleme göstergesi gerektiğinde.
- Label ile aynı hizalamada, text size'a bağlı spinner gerektiğinde.

Ne zaman kullanılmaz:

- İkon semantiği veya dönen simge gerekiyorsa `Icon::new(IconName::LoadCircle)`
  ve GPUI animasyon helper'ları kullanılabilir.
- Progress oranı biliniyorsa progress bileşenleri daha açıklayıcıdır.

Temel API:

- Constructor: `SpinnerLabel::new()`
- Varyantlar: `SpinnerLabel::dots()`, `.dots_variant()`, `.sand()`,
  `SpinnerLabel::with_variant(SpinnerVariant::...)`
- `SpinnerVariant`: `Dots`, `DotsVariant`, `Sand`.
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.alpha(...)`.

Davranış:

- `RenderOnce` implement eder.
- Unicode frame dizilerini `Animation::new(duration).repeat()` ile döndürür.
- Varsayılan rengi `Color::Muted` olan bir `Label` tabanlıdır.

Örnek:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn render_compact_spinner() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::sand().size(LabelSize::Small).color(Color::Accent))
        .child(Label::new("Indexing").size(LabelSize::Small).color(Color::Muted))
}
```

### Icon, IconName ve IconSize

Kaynak:

- `Icon`, `IconSize`, `AnyIcon`, `IconWithIndicator`:
  `../zed/crates/ui/src/components/icon.rs`
- `IconName`: `../zed/crates/icons/src/icons.rs`, `ui::IconName` olarak
  re-export edilir.
- Export: `ui::Icon`, `ui::IconName`, `ui::IconSize`
- Prelude: `Icon`, `IconName`, `IconSize` gelir.
- Preview: `impl Component for Icon`

Ne zaman kullanılır:

- Toolbar, list item, status row, tab, menu ve button içindeki semantik simgeler
  için.
- Tema rengine bağlı tek renk SVG ikonları için.
- Harici ikon teması veya provider SVG'si gerektiğinde `from_path` /
  `from_external_svg`.

Ne zaman kullanılmaz:

- Büyük raster görseller için GPUI `img(...)` / `ImageSource` veya `Avatar` /
  `Vector` gibi daha uygun bileşenler kullanılmalı.
- Simgenin yanında badge/durum gerekiyorsa çıplak `Icon` yerine
  `DecoratedIcon`, `IconWithIndicator` veya ilgili component slot'u düşünülmeli.

Temel API:

- `Icon::new(icon_name)`
- `Icon::from_path(path)`
- `Icon::from_external_svg(svg_path)`
- `.size(IconSize::...)`
- `.color(Color::...)`
- `IconSize`: `Indicator` 10px, `XSmall` 12px, `Small` 14px, `Medium` 16px,
  `XLarge` 48px, `Custom(Rems)`.
- Ölçü helper'ları: `IconSize::rems() -> Rems`,
  `IconSize::square(window, cx) -> Pixels` (icon ve simetrik padding'i içeren
  kare ölçüsü) ve `IconSize::square_components(window, cx) -> (Pixels, Pixels)`
  (icon ölçüsü ve tek taraf padding'i ayrı döner). `IconButtonShape::Square`
  ve custom icon konteyner hizalamalarında işe yarar.
- `IconName::path()` gömülü ikonun `icons/<name>.svg` yolunu döndürür.

Davranış:

- `RenderOnce` implement eder.
- `Icon::new` gömülü SVG kullanır ve rengi `text_color` üzerinden uygular.
- `from_path` için `icons/` ile başlayan yollar gömülü SVG, diğer yollar harici
  raster image olarak ele alınır.
- `from_external_svg` harici SVG path'ini `svg().external_path(...)` ile çizer.

Örnekler:

```rust
use ui::prelude::*;

fn render_status_icon() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(Icon::new(IconName::Check).size(IconSize::Small).color(Color::Success))
        .child(Label::new("Ready").size(LabelSize::Small).color(Color::Muted))
}
```

```rust
use ui::prelude::*;

fn render_tool_icon_from_embedded_path() -> impl IntoElement {
    Icon::from_path(IconName::ToolWeb.path())
        .size(IconSize::Small)
        .color(Color::Muted)
}
```

Zed içinden kullanım:

- `../zed/crates/remote_connection/src/remote_connection.rs`: warning ve loading
  status satırları.
- `../zed/crates/ai_onboarding/src/agent_api_keys_onboarding.rs`:
  `Icon::new(...)` ve `Icon::from_external_svg(...)` provider ikonları.
- `../zed/crates/editor/src/element.rs`: dosya ve outline ikonları için
  `Icon::from_path(...)`.

Dikkat edilecekler:

- Kullanacağınız `IconName` değerinin `../zed/crates/icons/src/icons.rs` içinde
  bulunduğunu kontrol edin.
- `IconSize::Custom(rems(...))` mümkün olsa da tasarım sistemiyle tutarlılık için
  standart boyutları tercih edin.
- Harici raster path'lerinde SVG recolor davranışı beklemeyin; `from_path`
  `icons/` dışındaki yolu image olarak işler.

### DecoratedIcon ve IconDecoration

Kaynak:

- `DecoratedIcon`: `../zed/crates/ui/src/components/icon/decorated_icon.rs`
- `IconDecoration`, `IconDecorationKind`, `KnockoutIconName`:
  `../zed/crates/ui/src/components/icon/icon_decoration.rs`
- Export: `ui::DecoratedIcon`, `ui::IconDecoration`,
  `ui::IconDecorationKind`
- Prelude: Hayır, ayrıca import edin.
- Preview: `DecoratedIcon` için vardır; `IconDecoration` tek başına preview
  değildir.

Ne zaman kullanılır:

- Bir dosya veya tab ikonunun üstüne hata, devre dışı, silinmiş veya özel durum
  işareti bindirmek için.
- İkon üzerinde küçük `X`, `Dot` veya `Triangle` overlay'i gerektiğinde.

Ne zaman kullanılmaz:

- Basit status noktası yeterliyse `Indicator` veya `IconWithIndicator` daha
  sade olabilir.
- Badge metni veya sayaç gerekiyorsa `CountBadge` gibi bileşenler daha uygun.

Temel API:

- `DecoratedIcon::new(icon, Option<IconDecoration>)`
- `IconDecoration::new(kind, knockout_color, cx)`
- `IconDecorationKind`: `X`, `Dot`, `Triangle`
- `KnockoutIconName`: `XFg`, `XBg`, `DotFg`, `DotBg`, `TriangleFg`,
  `TriangleBg`. Bu enum knockout SVG path'lerini üretir; normal tüketici kodu
  genellikle `IconDecorationKind` ile çalışır.
- Decoration builder'ları: `.kind(...)`, `.color(hsla)`,
  `.knockout_color(hsla)`, `.knockout_hover_color(hsla)`, `.position(point)`,
  `.size(px)`, `.group_name(...)`.

Davranış:

- `DecoratedIcon` relative bir container oluşturur, icon boyutunu container size
  olarak kullanır ve decoration'ı absolute overlay olarak ekler.
- `IconDecoration`, knockout foreground/background SVG çiftini kullanır.
  `knockout_color`, ikonun üzerinde durduğu yüzey rengiyle eşleşmelidir.
- `group_name(...)` verilirse knockout hover rengi group hover üzerinden değişir;
  verilmezse doğrudan hover style uygulanır.

Örnek:

```rust
use ui::prelude::*;
use ui::{DecoratedIcon, IconDecoration, IconDecorationKind};

fn render_file_with_error(cx: &App) -> impl IntoElement {
    let decoration = IconDecoration::new(
        IconDecorationKind::X,
        cx.theme().colors().surface_background,
        cx,
    )
    .color(Color::Error.color(cx));

    h_flex()
        .gap_2()
        .child(DecoratedIcon::new(
            Icon::new(IconName::FileDoc).color(Color::Muted),
            Some(decoration),
        ))
        .child(Label::new("schema.json").truncate())
}
```

Zed içinden kullanım:

- `../zed/crates/tab_switcher/src/tab_switcher.rs`: tab ikonları üzerine durum
  dekorasyonu bindirilir.
- `../zed/crates/zed/src/visual_test_runner.rs`: `ThreadItem` ikon dekorasyonu
  görsel testlerinde kullanılır.

Dikkat edilecekler:

- `IconDecoration::color(...)` `Color` değil `Hsla` bekler; semantik renkten
  üretmek için `Color::Error.color(cx)` gibi çağırın.
- Decoration knockout rengi arka planla eşleşmezse overlay çevresinde istenmeyen
  kenar görünebilir.
- Büyük veya metin içeren durumlar için ikon dekorasyonu yerine satır içinde
  `Indicator`, `CountBadge` veya açıklayıcı `Label` kullanın.

### Metin ve ikon kompozisyon örnekleri

Durum satırı:

```rust
use ui::prelude::*;

fn render_sync_status(message: SharedString, is_error: bool) -> impl IntoElement {
    let (icon, color) = if is_error {
        (IconName::Warning, Color::Error)
    } else {
        (IconName::Check, Color::Success)
    };

    h_flex()
        .min_w_0()
        .gap_1()
        .child(Icon::new(icon).size(IconSize::Small).color(color))
        .child(Label::new(message).size(LabelSize::Small).color(Color::Muted).truncate())
}
```

Arama sonucu:

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_project_match(
    name: SharedString,
    path: SharedString,
    match_indices: Vec<usize>,
) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_2()
        .child(Icon::new(IconName::Folder).color(Color::Muted))
        .child(
            v_flex()
                .min_w_0()
                .child(HighlightedLabel::new(name, match_indices).truncate())
                .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate()),
        )
}
```

Yükleme satırı:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn render_indexing_row() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::new().size(LabelSize::Small))
        .child(LoadingLabel::new("Indexing project").size(LabelSize::Small))
}
```

## 4. Buton Ailesi

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

### Ortak buton trait'leri ve token'lar

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
> (Bölüm 11/`KeyBinding`). `KeybindingPosition` enum'u (`Start`,
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

### Button

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

### IconButton

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

### ButtonLike

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

### ButtonLink

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

### CopyButton

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

### SplitButton

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

### ToggleButtonGroup

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
  dışından import edilemez. Public ad taramasında görünürse "kapsam dışı
  sealed helper" olarak sınıflandırılır.
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

### Buton Kompozisyon Örnekleri

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

## 5. Form, Toggle, Menü ve Popup

Bu bölümdeki bileşenler kullanıcıdan seçim almak, geçici eylem listeleri açmak
ve küçük yardımcı açıklamalar göstermek için kullanılır. Ortak kural, görsel
durum ile uygulama durumunu birbirinden ayırmaktır: checkbox, switch veya menu
entry yalnızca mevcut state'i render eder; gerçek değer view state'inde veya
uygulama modelinde tutulmalı ve handler içinde güncellenmelidir.

Genel seçim rehberi:

- Bağımsız çoklu seçim için `Checkbox`.
- Aç/kapat anlamı taşıyan tek ayar için `Switch`.
- Label, açıklama ve switch tek satır ayar olarak birlikte kullanılacaksa
  `SwitchField`.
- Tek satır metin girişi için `ui_input::InputField`.
- Seçili değeri trigger üzerinde gösteren seçenek listesi için `DropdownMenu`.
- Menü içeriği, entry, separator, submenu ve action dispatch için `ContextMenu`.
- İkincil tıklamayla açılan bağlam menüsü için `right_click_menu`.
- Buton/ikon trigger ile açılan managed view menüleri için `PopoverMenu`.
- Popup yüzeyinin içeriğini çizmek için `Popover`.
- Kısa hover açıklamaları ve shortcut bilgisini göstermek için `Tooltip`.

### Checkbox

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

### Switch

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

### SwitchField

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

### InputField (`ui_input`)

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

### DropdownMenu

Kaynak:

- Tanım: `../zed/crates/ui/src/components/dropdown_menu.rs`
- Export: `ui::DropdownMenu`, `ui::DropdownStyle`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for DropdownMenu`

Ne zaman kullanılır:

- Seçili değerin trigger üzerinde göründüğü option picker'larda.
- Liste kısa ama inline segment kontrol için fazla uzun olduğunda.
- Menü içeriği `ContextMenu` olarak hazırlanabiliyorsa.

Ne zaman kullanılmaz:

- Trigger değeri değişmiyor ve yalnızca eylem listesi açılıyorsa doğrudan
  `PopoverMenu<ContextMenu>` daha açık olabilir.
- Büyük arama/filter deneyimi gerekiyorsa picker bileşeni veya özel managed view
  tercih edin.

Temel API:

- Constructor: `DropdownMenu::new(id, label, menu: Entity<ContextMenu>)`
- Özel label: `DropdownMenu::new_with_element(id, label: AnyElement, menu)`
- Builder'lar: `.style(DropdownStyle)`, `.trigger_size(ButtonSize)`,
  `.trigger_tooltip(...)`, `.trigger_icon(IconName)`, `.full_width(bool)`,
  `.handle(PopoverMenuHandle<ContextMenu>)`, `.attach(Anchor)`,
  `.offset(Point<Pixels>)`, `.tab_index(...)`, `.no_chevron()`,
  `.disabled(bool)`.
- `DropdownStyle`: `Solid`, `Outlined`, `Subtle`, `Ghost`.

Davranış:

- Text label için `Button`, custom element label için `ButtonLike` üretir.
- İçeride `PopoverMenu::new((id, "popover"))` kullanır.
- Varsayılan trigger ikonu `IconName::ChevronUpDown`; `.no_chevron()` bu
  chevron'u kaldırır.
- Varsayılan attach noktası `Anchor::BottomRight`.
- `DropdownStyle` değerleri button stiline map edilir:
  `Solid -> Filled`, `Outlined -> Outlined`, `Subtle -> Subtle`,
  `Ghost -> Transparent`.

Örnek:

```rust
use ui::prelude::*;
use ui::{ContextMenu, DropdownMenu, DropdownStyle, Tooltip};

fn render_sort_dropdown(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu = ContextMenu::build(window, cx, |menu, _, _| {
        menu.header("Sort by")
            .toggleable_entry("Name", true, IconPosition::Start, None, |_, _| {})
            .toggleable_entry("Updated", false, IconPosition::Start, None, |_, _| {})
            .separator()
            .entry("Reverse order", None, |_, _| {})
    });

    DropdownMenu::new("sort-dropdown", "Name", menu)
        .style(DropdownStyle::Outlined)
        .trigger_tooltip(Tooltip::text("Change sort order"))
}
```

Zed içinden kullanım:

- `../zed/crates/acp_tools/src/acp_tools.rs`: connection selector.
- Component preview: `../zed/crates/ui/src/components/dropdown_menu.rs`.

Dikkat edilecekler:

- `DropdownMenu` menü entity'sini dışarıdan alır. Menü entry handler'ları
  seçili değeri view/model state'ine yazmalı; dropdown bunu kendisi güncellemez.
- Dinamik label kullanıyorsanız mevcut seçili değeri her render'da label'a
  yansıtın.
- `full_width(true)` trigger ve popover genişliğini birlikte etkiler; dar
  formlarda parent width'i de bilinçli ayarlayın.

### ContextMenu

Kaynak:

- Tanım: `../zed/crates/ui/src/components/context_menu.rs`
- Export: `ui::ContextMenu`, `ui::ContextMenuEntry`,
  `ui::ContextMenuItem`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok; `DropdownMenu` ve gerçek kullanım
  örnekleri üzerinden görülür.

Ne zaman kullanılır:

- Entry, separator, header, checked state, submenu veya action dispatch içeren
  menü içeriği oluşturmak için.
- Hem dropdown/popover içinde hem de sağ tık menüsünde aynı menü modelini
  kullanmak için.

Ne zaman kullanılmaz:

- Menü değil, serbest layout içeren popup yüzeyi gerekiyorsa `Popover` içinde
  özel managed view oluşturun.
- Sadece tek bir buton eylemi varsa menu gereksizdir.

Temel API:

- `ContextMenu::build(window, cx, |menu, window, cx| menu...)`
- `ContextMenu::build_persistent(window, cx, builder)` menü açık kalıp yeniden
  kurulacaksa.
- Yapı builder'ları: `.context(focus_handle)`, `.header(...)`,
  `.header_with_link(...)`, `.separator()`, `.label(...)`, `.entry(...)`,
  `.toggleable_entry(...)`, `.custom_row(...)`, `.custom_entry(...)`,
  `.custom_entry_with_docs(...)`, `.entry_with_end_slot(...)`,
  `.entry_with_end_slot_on_hover(...)`, `.selectable(bool)`, `.action(...)`,
  `.action_checked(...)`, `.action_checked_with_disabled(...)`,
  `.action_disabled_when(...)`, `.link(...)`, `.link_with_handler(...)`,
  `.submenu(...)`, `.submenu_with_icon(...)`, `.submenu_with_colored_icon(...)`,
  `.keep_open_on_confirm(bool)`, `.fixed_width(...)`, `.key_context(...)`,
  `.end_slot_action(action)`.
- Dinamik item ekleme builder'ları: `.item(item: impl Into<ContextMenuItem>)`
  ve `.extend(items: impl IntoIterator<Item = impl Into<ContextMenuItem>>)`
  zincirleme kullanım için; `&mut self` üzerinden mutate eden
  `.push_item(item)` builder dışında menüyü değiştirmek için (örn. event
  callback içinde).
- Programatik mutator'lar: `.rebuild(window, cx)` `build_persistent` ile
  açık kalan menünün içeriğini yeniden kurar; `.trigger_end_slot_handler
  (window, cx)` aktif entry'nin end slot handler'ını programatik olarak
  çalıştırır.
- Action/navigation metodları: `.selected_index()`, `.confirm(...)`,
  `.secondary_confirm(...)`, `.cancel(...)`, `.end_slot(...)`,
  `.clear_selected()`, `.select_first(...)`, `.select_last(...)`,
  `.select_next(...)`, `.select_previous(...)`, `.select_submenu_child(...)`,
  `.select_submenu_parent(...)`, `.on_action_dispatch(...)`,
  `.on_blur_subscription(...)`. Bunlar çoğunlukla keymap/action bağlarından
  çağrılır; normal menü inşasında builder zincirine karıştırılmaz.
- Entry builder'ları: `ContextMenuEntry::new(label).icon(...).toggleable(...)`
  `.custom_icon_path(...)`, `.custom_icon_svg(...)`, `.icon_position(...)`,
  `.icon_size(...)`, `.icon_color(...)`, `.action(...)`, `.handler(...)`,
  `.secondary_handler(...)`, `.disabled(...)`, `.documentation_aside(...)`.
- `ContextMenuItem` variant'ları: `Separator`, `Header`, `HeaderWithLink`,
  `Label`, `Entry`, `CustomEntry`, `Submenu`. Builder zincirleri çoğu durumda bu
  enum'u doğrudan üretir; dinamik menü listesi saklayacaksanız `ContextMenuItem`
  koleksiyonu kullanabilirsiniz.

Davranış:

- `Focusable` ve `EventEmitter<DismissEvent>` implement eder.
- Blur olduğunda menü kapanır; açık submenu focus'u korunuyorsa kapanma
  ertelenir.
- Confirm edilen entry handler'ı çalıştırılır. `keep_open_on_confirm(false)`
  durumunda menü `DismissEvent` yayınlar.
- `build_persistent(...)` ile kurulan menü rebuild edilebilir ve açık kalabilir.
- Keyboard navigation için menu action'larını ve `key_context` değerini kullanır.

Örnek:

```rust
use ui::prelude::*;
use ui::ContextMenu;

fn build_file_menu(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |menu, _, _| {
        menu.header("File")
            .entry("Rename", None, |_, _| {})
            .entry("Duplicate", None, |_, _| {})
            .separator()
            .toggleable_entry("Show hidden files", true, IconPosition::Start, None, |_, _| {})
            .submenu("Open with", |menu, _, _| {
                menu.entry("Text editor", None, |_, _| {})
                    .entry("System app", None, |_, _| {})
            })
    })
}
```

Zed içinden kullanım:

- `../zed/crates/language_tools/src/lsp_log_view.rs`: LSP server ve log view
  menüleri.
- `../zed/crates/git_ui/src/git_panel.rs`: git panel eylem menüleri.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: filtre ve keybinding
  menüleri.

Özel entry'ler:

```rust
use gpui::IntoElement;
use ui::prelude::*;
use ui::{Chip, ContextMenu};

fn build_menu_with_custom_entries(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |menu, _, _| {
        menu.header_with_link(
            "Available Tools",
            "Docs",
            "https://zed.dev/docs/tools",
        )
        .custom_entry(
            |_, _| {
                h_flex()
                    .gap_2()
                    .child(Label::new("Run Selection"))
                    .child(Chip::new("beta").label_color(Color::Accent))
                    .into_any_element()
            },
            |_, _| {},
        )
        .custom_entry_with_docs(
            |_, _| Label::new("Open Workspace Settings").into_any_element(),
            |_, _| {},
            Some(ui::DocumentationAside::new(
                ui::DocumentationSide::Right,
                std::rc::Rc::new(|_| {
                    Label::new("Workspace ayarları sadece bu proje için geçerlidir.")
                        .into_any_element()
                }),
            )),
        )
    })
}
```

`header_with_link(...)` üç parametre alır: başlık, link etiketi ve link URL'i.
Render edilen header'a tıklanırsa URL `cx.open_url(...)` ile açılır.

`custom_entry(render_fn, handler)`, entry görselini sıfırdan üretmenize izin
verir. Varsayılan olarak selectable'dır; `.selectable(false)` ile entry'yi
salt görsel hale getirebilirsiniz (label gibi).

`custom_entry_with_docs(render_fn, handler, documentation_aside)`, entry'nin
yanında popover olarak küçük bir dokümantasyon paneli açar. Ayrıca normal
`entry(...)` zinciri üzerine `.documentation_aside(side, render)` ile aynı
davranışı eklemek mümkündür.

Action ve link helper'ları:

- `action(label, action)`: önce varsa context focus handle'ına focus verir, sonra
  action dispatch eder.
- `action_checked(...)` ve `action_checked_with_disabled(...)`: action entry'ye
  checked/disabled durumunu ekler.
- `action_disabled_when(disabled, label, action)`: disabled koşulunu entry
  oluştururken bağlar.
- `link(...)` ve `link_with_handler(...)`: entry'nin sonuna `ArrowUpRight`
  ikonunu ekler, custom handler'ı çalıştırır ve action dispatch eder.

End slot ve icon helper'ları:

- `entry_with_end_slot(...)`, entry'nin sağ tarafına ikinci bir icon action
  koyar.
- `entry_with_end_slot_on_hover(...)`, aynı action'ı yalnızca hover sırasında
  gösterir.
- `custom_icon_path(...)` ve `custom_icon_svg(...)`, `ContextMenuEntry` üzerinde
  normal `IconName` yerine harici icon kaynağı seçer.
- `submenu_with_colored_icon(...)`, submenu label'ına semantik `Color` ile
  renklendirilmiş ikon ekler.

Dikkat edilecekler:

- `ContextMenu` bir açma mekanizması değildir. Onu `DropdownMenu`,
  `PopoverMenu` veya `right_click_menu` ile sunarsınız.
- Handler içinde view state'i değiştiriyorsanız ilgili entity üzerinden
  `window.handler_for(...)`, `cx.listener(...)` veya local model update pattern'ini
  kullanın; örneklerdeki boş handler'lar yalnızca API şeklini gösterir.
- Submenu builder'ları yeni `ContextMenu` değerini döndürmelidir; parent menüdeki
  state'i kopyalayarak kullanmanız gerekiyorsa closure capture'larını sade tutun.

### PopoverMenu

Kaynak:

- Tanım: `../zed/crates/ui/src/components/popover_menu.rs`
- Export: `ui::PopoverMenu`, `ui::PopoverMenuHandle`, `ui::PopoverTrigger`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok; gerçek kullanımlar menu trigger
  bileşenleri üzerinden ilerler.

Ne zaman kullanılır:

- Bir `Button`, `IconButton` veya `ButtonLike` trigger'a bağlı popover/menu
  açmak için.
- Menü açıldığında trigger seçili görünsün ve kapanınca eski focus geri gelsin
  istendiğinde.
- `ContextMenu` dışında başka bir `ManagedView` popup olarak sunulacaksa.

Ne zaman kullanılmaz:

- Sağ tık davranışı gerekiyorsa `right_click_menu`.
- Sadece hazır dropdown semantics'i gerekiyorsa `DropdownMenu`.

Temel API:

- Constructor: `PopoverMenu::new(id)`
- Builder'lar: `.full_width(bool)`, `.menu(...)`, `.with_handle(...)`,
  `.trigger(...)`, `.trigger_with_tooltip(...)`, `.anchor(Anchor)`,
  `.attach(Anchor)`, `.offset(Point<Pixels>)`, `.on_open(...)`.
- `PopoverMenuHandle` yöntemleri: `.show(...)`, `.hide(...)`, `.toggle(...)`,
  `.is_deployed()`, `.is_focused(...)`, `.refresh_menu(...)`.

Davranış:

- Trigger tipi `PopoverTrigger` trait'ini sağlamalıdır; bu trait
  `IntoElement + Clickable + Toggleable + 'static` kombinasyonunun public alias
  yüzeyidir.
- Trigger tıklandığında menu builder `Option<Entity<M>>` döndürür; `None`
  dönerse menü açılmaz.
- Açılan menu `DismissEvent` yayınladığında handle temizlenir ve önceki focus
  mümkünse geri verilir.
- Menü deferred render edildiği için focus iki `on_next_frame` sonrasında
  uygulanır.
- Trigger'a menü açıkken tekrar tıklamak menüyü dismiss eder ve propagation'ı
  durdurur.

Örnek:

```rust
use ui::prelude::*;
use ui::{ContextMenu, PopoverMenu, Tooltip};

fn render_more_actions(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu = ContextMenu::build(window, cx, |menu, _, _| {
        menu.entry("Rename", None, |_, _| {})
            .entry("Delete", None, |_, _| {})
    });

    PopoverMenu::new("more-actions")
        .menu(move |_, _| Some(menu.clone()))
        .trigger_with_tooltip(
            IconButton::new("more-actions-trigger", IconName::Menu)
                .icon_size(IconSize::Small)
                .style(ButtonStyle::Subtle),
            Tooltip::text("More actions"),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/language_tools/src/lsp_log_view.rs`: LSP seçim menüleri.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: add context ve
  permission menüleri.
- `../zed/crates/git_ui/src/git_panel.rs`: repository, branch ve commit
  kontrolleri.

Dikkat edilecekler:

- `trigger_with_tooltip(...)`, menü açıkken trigger tooltip'inin görünmesini
  engeller. İkon-only trigger'larda genellikle bunu tercih edin.
- `with_handle(...)` kullanıyorsanız handle'ı view state'inde saklayın; her
  render'da yeni handle oluşturmak dışarıdan show/hide kontrolünü bozar.
- `anchor` menünün hangi köşesinin konumlanacağını, `attach` trigger'ın hangi
  köşesine bağlanacağını belirler.

### RightClickMenu

Kaynak:

- Tanım: `../zed/crates/ui/src/components/right_click_menu.rs`
- Export: `ui::RightClickMenu`, `ui::right_click_menu`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok.

Ne zaman kullanılır:

- Dosya, tab, satır, liste item'i veya editor yüzeyi üzerinde sağ tıkla bağlam
  menüsü açmak için.
- Menü konumu varsayılan olarak cursor pozisyonuna göre belirlensin istendiğinde.

Ne zaman kullanılmaz:

- Sol tık trigger'lı menu için `PopoverMenu`.
- Seçili değeri gösteren kontrol için `DropdownMenu`.

Temel API:

- Constructor: `right_click_menu::<M>(id)`
- Builder'lar: `.trigger(|is_menu_active, window, cx| element)`,
  `.menu(|window, cx| Entity<M>)`, `.anchor(Anchor)`, `.attach(Anchor)`.

Davranış:

- `MouseButton::Right` ve hovered hitbox üzerinde bubble phase yakalanınca menü
  açılır.
- `prevent_default()` ve `stop_propagation()` çağırır.
- `attach(...)` verilirse menünün pozisyonu cursor yerine trigger bounds
  köşesine bağlanır.
- Açılan managed view `DismissEvent` yayınladığında menü state'i temizlenir ve
  focus mümkünse önceki elemana döner.

Örnek:

```rust
use ui::prelude::*;
use ui::{ContextMenu, right_click_menu};

fn render_project_row(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu = ContextMenu::build(window, cx, |menu, _, _| {
        menu.entry("Open", None, |_, _| {})
            .entry("Reveal in Finder", None, |_, _| {})
            .separator()
            .entry("Remove from Recent Projects", None, |_, _| {})
    });

    right_click_menu("recent-project-row-menu")
        .trigger(|menu_open, _window, cx| {
            h_flex()
                .w_full()
                .px_2()
                .py_1()
                .when(menu_open, |this| this.bg(cx.theme().colors().element_hover))
                .child(Label::new("zed").truncate())
        })
        .menu(move |_, _| menu.clone())
}
```

Zed içinden kullanım:

- `../zed/crates/platform_title_bar/src/system_window_tabs.rs`: sistem tab sağ
  tık menüsü.
- `../zed/crates/editor/src/element.rs`: buffer header bağlam menüsü.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: context entry
  sağ tık menüleri.

Dikkat edilecekler:

- Trigger closure'ındaki `is_menu_active` değerini hover/selected görseli için
  kullanabilirsiniz; uygulama state'i olarak saklamayın.
- Sağ tık menüsü içinde sol tıkla çalışan custom kontroller varsa event
  propagation'ı ve menu dismiss davranışını test edin.

### Popover

Kaynak:

- Tanım: `../zed/crates/ui/src/components/popover.rs`
- Export: `ui::Popover`, `ui::POPOVER_Y_PADDING`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok.

Ne zaman kullanılır:

- Açılmış bir popup yüzeyinin içeriğini standart elevation ve padding ile çizmek
  için.
- Menü olmayan ama trigger'a bağlı küçük seçenek paneli, açıklama paneli veya
  yardımcı içerik gerektiğinde.
- Ana içeriğe ek olarak sağ/yan açıklama alanı gerekiyorsa `.aside(...)`.

Ne zaman kullanılmaz:

- Popup'ı açmak/kapatmak için tek başına yeterli değildir; bunun için
  `PopoverMenu` veya başka managed view akışı gerekir.
- Sıradan context menu entry listesi için `ContextMenu` daha doğru.

Temel API:

- Constructor: `Popover::new()`
- Builder: `.aside(...)`
- `ParentElement` implement eder; `.child(...)` ve `.children(...)`
  kullanılabilir.

Davranış:

- İçeriği `v_flex().elevation_2(cx)` yüzeyinde çizer.
- `aside(...)` verilirse ikinci elevation yüzeyi olarak yan içerik ekler.
- `POPOVER_Y_PADDING` dikey padding hesabında kullanılır.

Örnek:

```rust
use ui::prelude::*;
use ui::Popover;

fn render_filter_popover() -> impl IntoElement {
    Popover::new()
        .child(
            v_flex()
                .gap_2()
                .px_2()
                .child(Label::new("Filter").size(LabelSize::Small).color(Color::Muted))
                .child(Label::new("Open files only")),
        )
        .aside(
            Label::new("Applies to the current workspace.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
}
```

Dikkat edilecekler:

- `Popover` konumlandırma yapmaz. Bir `ManagedView` render'ı içinde kullanıp o
  view'i `PopoverMenu` ile açmak gerekir.
- İçerik genişliğini child layout ile kontrol edin; `Popover` kendi başına sabit
  width vermez.

### Tooltip

Kaynak:

- Tanım: `../zed/crates/ui/src/components/tooltip.rs`
- Export: `ui::Tooltip`, `ui::LinkPreview`, `ui::tooltip_container`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Tooltip`

Ne zaman kullanılır:

- İkon-only butonun anlamını göstermek için.
- Disabled veya karmaşık kontrollerde kısa neden/metaveri göstermek için.
- Bir action'a bağlı klavye kısayolunu tooltip içinde göstermek için.

Ne zaman kullanılmaz:

- Kullanıcı akışının anlaşılması tooltip'e bağlı kalıyorsa label veya açıklama
  metni ekleyin.
- Uzun dokümantasyon, form hatası veya kalıcı bilgi için tooltip yerine görünür
  içerik kullanın.

Temel API:

- Basit builder closure: `Tooltip::text(title)`
- Immediate view: `Tooltip::simple(title, cx)`
- Action shortcut'lı builder: `Tooltip::for_action_title(title, action)`,
  `Tooltip::for_action_title_in(title, action, focus_handle)`
- Action shortcut'lı immediate view: `Tooltip::for_action(...)`,
  `Tooltip::for_action_in(...)`
- Meta açıklamalı view: `Tooltip::with_meta(...)`,
  `Tooltip::with_meta_in(...)`
- Özel element: `Tooltip::element(...)`, `Tooltip::new_element(...)`
- Instance builder'ları: `Tooltip::new(title).meta(...).key_binding(...)`.
- `tooltip_container(cx, |div, cx| ...)`: Zed tooltip yüzeyini özel içerikle
  yeniden kullanmak için düşük seviye helper.
- `LinkPreview::new(url: &str, cx: &mut App) -> AnyView`: uzun URL'i 100
  karakterlik parçalara bölüp en fazla 500 karakterde keserek tooltip yüzeyi
  içinde yumuşak satır kırma ile render eden basit URL önizleme view'ı. Geri
  dönen `AnyView` doğrudan `Tooltip::new_element(...)` veya entity tabanlı
  tooltip slot'larına geçirilebilir. Network çağrısı, başlık çekme veya
  metadata akışı içermez; bunlar parent tooltip view'ında elle uygulanmalıdır.

Davranış:

- Tooltip yüzeyi `tooltip_container(...)` içinde `elevation_2`, UI fontu ve tema
  text rengiyle çizilir.
- `key_binding` varsa title satırının sağında gösterilir.
- `meta` varsa ikinci satırda muted küçük label olarak çizilir.
- `Tooltip::text(...)` gibi yöntemler `.tooltip(...)` builder imzasına doğrudan
  uyan closure döndürür.

Örnek:

```rust
use ui::prelude::*;
use ui::Tooltip;

fn render_refresh_button() -> impl IntoElement {
    IconButton::new("refresh-models", IconName::RotateCw)
        .icon_size(IconSize::Small)
        .tooltip(Tooltip::text("Refresh models"))
}
```

Zed içinden kullanım:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: action ve binding
  tooltip'leri.
- `../zed/crates/git_ui/src/git_panel.rs`: git panel buton tooltip'leri.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: action,
  disabled state ve meta açıklamaları.

Dikkat edilecekler:

- `.tooltip(Tooltip::text(...))` en yaygın kullanım şeklidir.
- Shortcut göstermek istiyorsanız action tabanlı helper'ları kullanın; kısayolu
  elle string olarak yazmak keymap değişiklikleriyle uyumsuz hale gelir.
- Tooltip metnini uzun açıklama yerine kısa eylem adı veya kısa neden olarak
  tutun.

### Form ve Menü Kompozisyon Örnekleri

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

Popover içinde context menu:

```rust
use ui::prelude::*;
use ui::{ContextMenu, PopoverMenu, Tooltip};

fn render_toolbar_menu(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu = ContextMenu::build(window, cx, |menu, _, _| {
        menu.entry("New File", None, |_, _| {})
            .entry("New Folder", None, |_, _| {})
            .separator()
            .entry("Open Settings", None, |_, _| {})
    });

    PopoverMenu::new("toolbar-create-menu")
        .menu(move |_, _| Some(menu.clone()))
        .trigger_with_tooltip(
            IconButton::new("toolbar-create-menu-trigger", IconName::Plus)
                .icon_size(IconSize::Small),
            Tooltip::text("Create"),
        )
}
```

## 6. Liste ve Tree Bileşenleri

Liste bileşenleri, aynı görsel ritme sahip satırları, section başlıklarını,
boş durumları ve hiyerarşik navigation yüzeylerini kurmak için kullanılır.
Küçük ve orta ölçekli statik listelerde `List` + `ListItem` yeterlidir. Çok
büyük, scroll edilen ve satır yüksekliği aynı olan listelerde GPUI
`uniform_list(...)` kullanılır; `StickyItems` ve `IndentGuides` gibi yardımcılar
bu düşük seviye listeye decoration olarak eklenir.

Genel seçim rehberi:

- Basit container, header ve empty state için `List`.
- Tıklanabilir veya seçilebilir satır için `ListItem`.
- Listenin ana bölüm başlığı için `ListHeader`.
- Daha küçük alt bölüm başlığı için `ListSubHeader`.
- Liste içinde yatay ayırıcı için `ListSeparator`.
- Sabit açıklama bullet'ları için yardımcı olarak `ListBulletItem`.
- Hiyerarşik, expandable navigation satırı için `TreeViewItem`.
- Büyük `uniform_list` içinde sticky parent/header davranışı için `StickyItems`.
- Büyük hiyerarşik listede girinti çizgileri için `IndentGuides`.

### List

Kaynak:

- Tanım: `../zed/crates/ui/src/components/list/list.rs`
- Export: `ui::List`, `ui::EmptyMessage`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for List`

Ne zaman kullanılır:

- Az sayıda satır içeren ayar, onboarding, modal, provider veya kart içi listeler
  için.
- Header ve empty state aynı component üzerinde yönetilecekse.
- Çocuklar farklı yüksekliklerde olabilir ve lazy rendering gerekmiyorsa.

Ne zaman kullanılmaz:

- Binlerce satırlık, scroll edilen ve performans kritik listeler için GPUI
  `uniform_list(...)` kullanın.
- Tablo semantiği, column resize veya header/row sözleşmesi gerekiyorsa veri
  bileşenleri daha doğru olur.

Temel API:

- Constructor: `List::new()`
- Builder'lar: `.empty_message(...)`, `.header(...)`, `.toggle(...)`
- `ParentElement` implement eder; `.child(...)` ve `.children(...)`
  kullanılabilir.
- `EmptyMessage`: `Text(SharedString)` veya `Element(AnyElement)`.

Davranış:

- `RenderOnce` implement eder.
- Container tam genişlikte `v_flex()` ve dikey padding ile çizilir.
- Çocuk yoksa varsayılan `"No items"` mesajını muted `Label` olarak gösterir.
- `.empty_message(...)` string veya custom `AnyElement` alabilir.
- `.toggle(Some(false))` ve children boşsa empty state de gizlenir.
- `.header(...)` verilirse header children'dan önce render edilir.

Örnek:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem};

fn render_provider_list() -> impl IntoElement {
    List::new()
        .header(ListHeader::new("Providers"))
        .empty_message("No providers configured")
        .child(
            ListItem::new("provider-openai")
                .start_slot(Icon::new(IconName::Check).size(IconSize::Small))
                .child(Label::new("OpenAI")),
        )
        .child(
            ListItem::new("provider-anthropic")
                .start_slot(Icon::new(IconName::Check).size(IconSize::Small))
                .child(Label::new("Anthropic")),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/edit_prediction_ui/src/rate_prediction_modal.rs`: custom empty
  state'li completion listesi.
- `../zed/crates/language_models/src/provider/anthropic.rs`: provider ayar
  listeleri.
- `../zed/crates/toolchain_selector/src/toolchain_selector.rs`: toolchain
  seçenekleri.

Dikkat edilecekler:

- `List` scroll davranışı vermez. Scroll gerekiyorsa parent container'a
  `overflow_y_scroll()` veya büyük listede `uniform_list(...)` kullanın.
- Dinamik çocuklar üretirken stable `ElementId` kullanın; yalnızca index ile id
  vermek reorder edilen listelerde state/focus takibini zorlaştırır.
- Empty state custom element ise `.into_any_element()` verin.

### ListItem

Kaynak:

- Tanım: `../zed/crates/ui/src/components/list/list_item.rs`
- Export: `ui::ListItem`, `ui::ListItemSpacing`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ListItem`

Ne zaman kullanılır:

- Liste satırı, picker sonucu, ayar satırı, navigation row veya action row için.
- Satırda start icon/avatar, ana içerik ve sağ slot birlikte gerekiyorsa.
- Selected, disabled, hover, focus veya disclosure state'i satır düzeyinde
  gösterilecekse.

Ne zaman kullanılmaz:

- Sadece metin gösterecekseniz `Label` veya `ListBulletItem` daha sade olabilir.
- Çok büyük listelerde `ListItem` yine satır olarak kullanılabilir, ancak
  container olarak `List` yerine `uniform_list(...)` tercih edilmelidir.

Temel API:

- Constructor: `ListItem::new(id)`
- Spacing: `.spacing(ListItemSpacing::Dense | ExtraDense | Sparse)`
- Slotlar: `.start_slot(...)`, `.end_slot(...)`, `.end_slot_on_hover(...)`,
  `.show_end_slot_on_hover()`
- Hiyerarşi: `.indent_level(usize)`, `.indent_step_size(Pixels)`,
  `.inset(bool)`, `.toggle(...)`, `.on_toggle(...)`,
  `.always_show_disclosure_icon(bool)`
- Davranış: `.on_click(...)`, `.on_hover(...)`,
  `.on_secondary_mouse_down(...)`, `.tooltip(...)`
- Görsel state: `.toggle_state(bool)`, `.disabled(bool)`,
  `.selectable(bool)`, `.outlined()`, `.rounded()`, `.focused(bool)`,
  `.docked_right(bool)`, `.height(...)`, `.overflow_x()`,
  `.group_name(...)`.

Davranış:

- `RenderOnce`, `Disableable`, `Toggleable` ve `ParentElement` implement eder.
- `toggle_state(true)` satırı selected background ile çizer; uygulama state'ini
  kendisi değiştirmez.
- `disabled(true)` click handler'ı devre dışı bırakır.
- `.toggle(Some(is_open))` disclosure icon render eder; çocukların gerçekten
  gösterilip gösterilmeyeceğini parent view kontrol eder.
- `end_slot_on_hover(...)`, normal end slot'u hover sırasında verilen hover
  slot ile değiştirir. `.show_end_slot_on_hover()` mevcut end slot'u yalnızca
  hover'da gösterir.
- `indent_level(...)`, `inset(false)` iken girintiyi satır içinde; `inset(true)`
  iken satır dışında uygular.

Örnek:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem, ListItemSpacing, Tooltip};

struct FileList {
    selected: usize,
}

impl FileList {
    fn render_file_row(
        &self,
        ix: usize,
        name: &'static str,
        path: &'static str,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        ListItem::new(("file-row", ix))
            .spacing(ListItemSpacing::Dense)
            .toggle_state(self.selected == ix)
            .start_slot(Icon::new(IconName::File).size(IconSize::Small).color(Color::Muted))
            .child(
                v_flex()
                    .min_w_0()
                    .child(Label::new(name).truncate())
                    .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate()),
            )
            .end_slot(
                IconButton::new(("file-row-actions", ix), IconName::Ellipsis)
                    .icon_size(IconSize::Small)
                    .tooltip(Tooltip::text("File actions")),
            )
            .show_end_slot_on_hover()
            .on_click(cx.listener(move |this: &mut FileList, _, _, cx| {
                this.selected = ix;
                cx.notify();
            }))
    }
}

impl Render for FileList {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        List::new()
            .header(ListHeader::new("Open files"))
            .child(self.render_file_row(0, "main.rs", "crates/app/src/main.rs", cx))
            .child(self.render_file_row(1, "lib.rs", "crates/ui/src/lib.rs", cx))
    }
}
```

Zed içinden kullanım:

- `../zed/crates/picker/src/picker.rs`: picker satırları.
- `../zed/crates/outline_panel/src/outline_panel.rs`: outline satırları.
- `../zed/crates/git_ui/src/repository_selector.rs`: repository selector
  satırları.

Dikkat edilecekler:

- `ListItem` çocuk içeriğini `overflow_hidden()` ile sarar. Uzun metinlerde
  iç label'lara da `.truncate()` ve parent layout'a `.min_w_0()` ekleyin.
- Hover'da görünen action butonları için satırdaki id ve action id'lerini stable
  tutun.
- Sağ tık context menu için `.on_secondary_mouse_down(...)` kullanabilirsiniz;
  daha kapsamlı bağlam menüsünde `right_click_menu(...)` de uygundur.

### ListHeader

Kaynak:

- Tanım: `../zed/crates/ui/src/components/list/list_header.rs`
- Export: `ui::ListHeader`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ListHeader`

Ne zaman kullanılır:

- Liste veya panel içinde ana section başlığı göstermek için.
- Başlık yanında icon, count, action veya collapse disclosure gerekiyorsa.

Ne zaman kullanılmaz:

- Daha küçük alt bölüm başlığı için `ListSubHeader`.
- Sayfa veya modal ana başlığı için `Headline` / modal header daha uygundur.

Temel API:

- Constructor: `ListHeader::new(label)`
- Builder'lar: `.toggle(...)`, `.on_toggle(...)`, `.start_slot(...)`,
  `.end_slot(...)`, `.end_hover_slot(...)`, `.inset(bool)`,
  `.toggle_state(bool)`.

Davranış:

- `RenderOnce` ve `Toggleable` implement eder.
- UI density ayarına göre header yüksekliği değişir.
- `.toggle(Some(is_open))` başa `Disclosure` ekler.
- `.on_toggle(...)` hem disclosure'a hem label container click davranışına
  bağlanır.
- `.end_hover_slot(...)`, header group hover olduğunda sağ tarafta absolute
  olarak görünür.

Örnek:

```rust
use ui::prelude::*;
use ui::{ListHeader, Tooltip};

fn render_recent_header(count: usize) -> impl IntoElement {
    ListHeader::new("Recent projects")
        .start_slot(Icon::new(IconName::Folder).size(IconSize::Small))
        .end_slot(Label::new(count.to_string()).size(LabelSize::Small).color(Color::Muted))
        .end_hover_slot(
            IconButton::new("clear-recent-projects", IconName::Trash)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Clear recent projects")),
        )
}
```

Dikkat edilecekler:

- Header collapse state'i view state'inde tutulmalı; `.toggle(...)` yalnızca
  disclosure görünümünü alır.
- `end_hover_slot(...)` normal `end_slot` ile aynı alanı paylaşır; count ve hover
  action birlikte tasarlanmalıdır.

### ListSubHeader

Kaynak:

- Tanım: `../zed/crates/ui/src/components/list/list_sub_header.rs`
- Export: `ui::ListSubHeader`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ListSubHeader`

Ne zaman kullanılır:

- Liste içinde daha küçük ikinci seviye bölüm başlığı gerektiğinde.
- Küçük label, opsiyonel sol icon ve sağ slot yeterliyse.

Ne zaman kullanılmaz:

- Collapse disclosure, hover slot veya daha güçlü header davranışı gerekiyorsa
  `ListHeader`.

Temel API:

- Constructor: `ListSubHeader::new(label)`
- Builder'lar: `.left_icon(Option<IconName>)`, `.end_slot(AnyElement)`,
  `.inset(bool)`, `.toggle_state(bool)`.

Davranış:

- `RenderOnce` ve `Toggleable` implement eder.
- Label muted ve `LabelSize::Small` çizilir.
- `.end_slot(...)` doğrudan `AnyElement` bekler.

Örnek:

```rust
use ui::prelude::*;
use ui::ListSubHeader;

fn render_pinned_sub_header() -> impl IntoElement {
    ListSubHeader::new("Pinned")
        .left_icon(Some(IconName::Folder))
        .end_slot(Label::new("3").size(LabelSize::Small).color(Color::Muted).into_any_element())
}
```

Zed içinden kullanım:

- `../zed/crates/component_preview/src/component_preview.rs`: preview navigation
  section başlıkları.
- `../zed/crates/rules_library/src/rules_library.rs`: rules library bölüm
  başlıkları.
- `../zed/crates/agent_ui/src/threads_archive_view.rs`: archive view alt
  bölümleri.

Dikkat edilecekler:

- `end_slot(...)` generic değildir; slot elementini `.into_any_element()` ile
  verin.
- Subheader seçili state'i yalnızca görseldir; navigation state'i parent view'de
  tutulmalıdır.

### ListSeparator

Kaynak:

- Tanım: `../zed/crates/ui/src/components/list/list_separator.rs`
- Export: `ui::ListSeparator`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Aynı listede iki satır grubunu ince çizgiyle ayırmak için.
- Menü olmayan listelerde separator ihtiyacı olduğunda.

Ne zaman kullanılmaz:

- `ContextMenu` içinde `.separator()` kullanın.
- Section başlığı gerekiyorsa `ListHeader` veya `ListSubHeader` daha anlamlıdır.

Davranış:

- `RenderOnce` implement eder.
- Tam genişlikte 1px yükseklikli `border_variant` rengiyle çizilir.
- Dikey margin olarak `DynamicSpacing::Base06` kullanır.

Örnek:

```rust
use ui::prelude::*;
use ui::{List, ListItem, ListSeparator};

fn render_grouped_actions() -> impl IntoElement {
    List::new()
        .child(ListItem::new("copy").child(Label::new("Copy")))
        .child(ListItem::new("paste").child(Label::new("Paste")))
        .child(ListSeparator)
        .child(ListItem::new("delete").child(Label::new("Delete").color(Color::Error)))
}
```

### ListBulletItem

Kaynak:

- Tanım: `../zed/crates/ui/src/components/list/list_bullet_item.rs`
- Export: `ui::ListBulletItem`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ListBulletItem`

Ne zaman kullanılır:

- Modal, onboarding veya açıklama paneli içinde kısa madde listesi göstermek için.
- Dash icon'u, wrap davranışı ve Zed liste spacing'i hazır gelsin istendiğinde.

Ne zaman kullanılmaz:

- Tıklanabilir veya seçilebilir row için `ListItem`.
- Hiyerarşik tree veya çok satırlı navigation için `TreeViewItem`.

Temel API:

- Constructor: `ListBulletItem::new(label)`
- Builder: `.label_color(Color)`
- `ParentElement` implement eder; çocuk verilirse label yerine çocuklar
  wrap'li inline içerik olarak render edilir.

Dikkat edilecekler:

- Bu bileşen açıklama amaçlıdır. İçerisine action link koyabilirsiniz, fakat
  row-level selection veya keyboard navigation beklemeyin.
- Kaynakta iç `ListItem` id'si sabittir; keyed satır state'i gereken dinamik
  listelerde `ListItem` ile özel satır kurun.

### TreeViewItem

Kaynak:

- Tanım: `../zed/crates/ui/src/components/tree_view_item.rs`
- Export: `ui::TreeViewItem`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for TreeViewItem`

Ne zaman kullanılır:

- Parent/child ilişkisi olan navigation satırlarında.
- Root item disclosure ile açılıp kapanacak, child item'lar girinti çizgisiyle
  gösterilecekse.
- Seçili ve focused state'leri tree satırında gösterilecekse.

Ne zaman kullanılmaz:

- Slot'lu, serbest layout'lu row gerekiyorsa `ListItem`.
- Büyük ve özel hiyerarşik panel gerekiyorsa `uniform_list(...)` + `ListItem`
  + `IndentGuides` daha esnek olabilir.

Temel API:

- Constructor: `TreeViewItem::new(id, label)`
- Davranış: `.on_click(...)`, `.on_hover(...)`, `.on_secondary_mouse_down(...)`,
  `.tooltip(...)`, `.on_toggle(...)`, `.tab_index(...)`,
  `.track_focus(&FocusHandle)`
- Görsel state: `.expanded(bool)`, `.default_expanded(bool)`,
  `.root_item(bool)`, `.focused(bool)`, `.toggle_state(bool)`,
  `.disabled(bool)`, `.group_name(...)`.

Davranış:

- `RenderOnce`, `Disableable` ve `Toggleable` implement eder.
- `root_item(true)` olan satırda disclosure ve label aynı satırda çizilir.
- `root_item(false)` olan child satırda solda indentation line çizilir.
- `.expanded(...)` disclosure icon durumunu belirler; child satırları parent
  view koşullu render etmelidir.
- `.default_expanded(...)` mevcut kaynakta alanı set eder, ancak render içinde
  okunmaz. Açık/kapalı state için `.expanded(...)` kullanın.
- `.toggle_state(true)` selected background ve border davranışını tetikler.

Örnek:

```rust
use ui::prelude::*;
use ui::TreeViewItem;

struct SymbolTree {
    module_open: bool,
    selected: usize,
}

impl Render for SymbolTree {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .child(
                TreeViewItem::new("symbols-module", "module app")
                    .root_item(true)
                    .expanded(self.module_open)
                    .toggle_state(self.selected == 0)
                    .on_toggle(cx.listener(|this: &mut SymbolTree, _, _, cx| {
                        this.module_open = !this.module_open;
                        cx.notify();
                    })),
            )
            .when(self.module_open, |this| {
                this.child(
                    TreeViewItem::new("symbols-main", "fn main")
                        .toggle_state(self.selected == 1)
                        .on_click(cx.listener(|this: &mut SymbolTree, _, _, cx| {
                            this.selected = 1;
                            cx.notify();
                        })),
                )
            })
    }
}
```

Zed içinden kullanım:

- Component preview: `../zed/crates/ui/src/components/tree_view_item.rs`.
- Hiyerarşik panellerin çoğu daha özelleşmiş `ListItem` + `uniform_list`
  kompozisyonları kullanır; `TreeViewItem` hazır, basit tree row ihtiyacına
  yöneliktir.

Dikkat edilecekler:

- `TreeViewItem` child listesini kendi içinde tutmaz. Açık root altındaki child
  item'ları parent layout eklemelidir.
- Disabled state hover/click davranışını tamamen kaldırmaz; click handler
  disabled durumda bağlanmaz, fakat görsel state'i tasarımda kontrol edin.

### StickyItems

Kaynak:

- Tanım: `../zed/crates/ui/src/components/sticky_items.rs`
- Export: `ui::sticky_items`, `ui::StickyItems`, `ui::StickyCandidate`,
  `ui::StickyItemsDecoration`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok.

Ne zaman kullanılır:

- `uniform_list(...)` içinde scroll ederken üst parent/header satırlarının sticky
  kalması gerekiyorsa.
- Project panel gibi derin, hiyerarşik ve çok satırlı listelerde.

Ne zaman kullanılmaz:

- Normal `List` içinde kullanılamaz; `UniformListDecoration` akışına bağlıdır.
- Küçük listelerde sticky davranışın maliyeti ve karmaşıklığı gereksizdir.

Temel API:

- `sticky_items(entity, compute_fn, render_fn)`
- `StickyCandidate` trait'i: `fn depth(&self) -> usize`. Render edilecek her
  satır verisinin bu trait'i implement etmesi beklenir; depth değeri kalan
  range içindeki sıraya göre monotonik artmalıdır.
- `StickyItemsDecoration` trait'i: `fn compute(&self, indents:
  &SmallVec<[usize; 8]>, bounds, scroll_offset, item_height, window, cx)
  -> AnyElement`. Sticky bölgenin üstüne overlay (indent guide, vurgu) çizmek
  için bu trait'i implement edip `.with_decoration(...)` ile bağlayın;
  `IndentGuides` bu trait'i hazır şekilde implement eder.
- Builder: `.with_decoration(decoration: impl StickyItemsDecoration)`
- `compute_fn`: görünür range için sticky candidate listesi üretir.
- `render_fn`: seçilen sticky candidate için render edilecek `AnyElement`
  listesini üretir.

Davranış:

- `UniformListDecoration` implement eder.
- Görünür range ve candidate depth değerlerinden sticky anchor hesaplar.
- Sticky entry drift ediyorsa son sticky element scroll pozisyonuna göre yukarı
  itilir.
- Ek decoration olarak `IndentGuides` bağlanabilir.

Örnek iskelet:

```rust
use ui::{StickyCandidate, sticky_items};

#[derive(Clone)]
struct StickyOutlineEntry {
    index: usize,
    depth: usize,
}

impl StickyCandidate for StickyOutlineEntry {
    fn depth(&self) -> usize {
        self.depth
    }
}
```

Zed içinden kullanım:

- `../zed/crates/project_panel/src/project_panel.rs`: project tree sticky
  entries ve indent guide decoration birlikte kullanılır.

Dikkat edilecekler:

- Candidate `depth()` değerleri visible range sırasıyla uyumlu olmalıdır. Yanlış
  depth, sticky anchor'ın yanlış satırdan seçilmesine neden olur.
- `render_fn` birden fazla sticky ancestor döndürebilir; bu elemanların yüksekliği
  uniform list item height ile uyumlu olmalıdır.

### IndentGuides

Kaynak:

- Tanım: `../zed/crates/ui/src/components/indent_guides.rs`
- Export: `ui::indent_guides`, `ui::IndentGuides`,
  `ui::IndentGuideColors`, `ui::IndentGuideLayout`,
  `ui::RenderIndentGuideParams`, `ui::RenderedIndentGuide`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok.

Ne zaman kullanılır:

- Büyük hiyerarşik `uniform_list(...)` içinde girinti çizgileri göstermek için.
- Project panel, outline panel veya benzeri tree listelerinde.
- Sticky item decoration içinde de aynı girinti çizgileri devam etsin
  istendiğinde.

Ne zaman kullanılmaz:

- Basit `ListItem::indent_level(...)` kullanılan küçük listelerde.
- Editor metni indent guide'ları için; editor tarafının kendi indent guide
  sistemi vardır.

Temel API:

- Constructor: `indent_guides(indent_size: Pixels, colors: IndentGuideColors)`
- Renk helper'ı: `IndentGuideColors::panel(cx)`
- Builder'lar: `.with_compute_indents_fn(entity, compute_fn)`,
  `.with_render_fn(entity, render_fn)`, `.on_click(...)`
- `IndentGuideColors` public alanları: `default: Hsla`, `hover: Hsla`,
  `active: Hsla`. `panel(cx)` helper'ı dışında özel renk seti gerekiyorsa
  bu alanlarla doğrudan struct literal kurabilirsiniz.
- `RenderIndentGuideParams`: `indent_guides: SmallVec<[IndentGuideLayout; 12]>`,
  `indent_size: Pixels`, `item_height: Pixels`. `with_render_fn` callback'inin
  girdisidir.
- `RenderedIndentGuide`: `bounds: Bounds<Pixels>`, `layout: IndentGuideLayout`,
  `is_active: bool`, `hitbox: Option<Bounds<Pixels>>`. `with_render_fn`
  callback'inin döndürdüğü vektörün eleman tipidir.
- `IndentGuideLayout`: `offset: Point<usize>` (satır indeksi ve depth),
  `length: usize` (kaç satır boyunca süreceği), `continues_offscreen: bool`.
  `.on_click(...)` callback'i bu tipi `&IndentGuideLayout` olarak alır.

Davranış:

- `UniformListDecoration` olarak kullanıldığında
  `.with_compute_indents_fn(...)` zorunludur; verilmezse compute sırasında panic
  eder.
- Visible range sonrasında daha fazla item varsa range bir satır genişletilir;
  böylece offscreen devam eden guide hesaplanabilir.
- `.on_click(...)` verilirse guide hitbox'ları oluşur, hover rengi ve pointing
  hand cursor uygulanır.
- `.with_render_fn(...)` verilmezse her guide 1px genişlikte varsayılan çizgi
  olarak çizilir.

Örnek:

```rust
use gpui::{ListSizingBehavior, UniformListScrollHandle, uniform_list};
use ui::prelude::*;
use ui::{IndentGuideColors, ListItem, indent_guides};

#[derive(Clone)]
struct OutlineEntry {
    depth: usize,
    label: SharedString,
}

struct OutlineList {
    entries: Vec<OutlineEntry>,
    scroll_handle: UniformListScrollHandle,
}

impl Render for OutlineList {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let entries = self.entries.clone();

        uniform_list("outline-list", entries.len(), move |range, _, _| {
            range
                .map(|ix| {
                    let entry = &entries[ix];
                    ListItem::new(("outline-entry", ix))
                        .indent_level(entry.depth)
                        .indent_step_size(px(12.))
                        .child(Label::new(entry.label.clone()).truncate())
                })
                .collect::<Vec<_>>()
        })
        .with_sizing_behavior(ListSizingBehavior::Infer)
        .track_scroll(&self.scroll_handle)
        .with_decoration(
            indent_guides(px(12.), IndentGuideColors::panel(cx)).with_compute_indents_fn(
                cx.entity(),
                |this: &mut OutlineList, range, _, _| {
                    this.entries[range]
                        .iter()
                        .map(|entry| entry.depth)
                        .collect()
                },
            ),
        )
    }
}
```

Zed içinden kullanım:

- `../zed/crates/project_panel/src/project_panel.rs`: project tree indent
  guide'ları, custom render ve click davranışı. Project panel `on_click` içinde
  `IndentGuideLayout::offset.y` değerinden hedef satırı bulur; secondary
  modifier aktifse ilgili parent entry'yi collapse eder.
- `../zed/crates/outline_panel/src/outline_panel.rs`: outline list indent
  guide'ları. `with_render_fn(...)` aktif guide'ı hesaplayıp
  `RenderedIndentGuide::is_active` alanını set eder.
- `../zed/crates/git_ui/src/git_panel.rs`: hiyerarşik git panel satırları.
  Git panel custom render ile yalnızca bounds/layout üretir, `hitbox: None`
  bırakarak click davranışı eklemez.

Dikkat edilecekler:

- `indent_size` satırların `.indent_step_size(...)` değeriyle uyumlu olmalı.
- `with_compute_indents_fn(...)` visible range için tam olarak o aralıktaki depth
  dizisini üretmelidir.
- Custom render'da `hitbox` alanını büyütmek, ince 1px çizgilerin tıklanmasını
  kolaylaştırır.

### Liste ve Tree Kompozisyon Örnekleri

Collapsible bölüm:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem};

struct DependencyList {
    expanded: bool,
}

impl Render for DependencyList {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        List::new()
            .header(
                ListHeader::new("Dependencies")
                    .toggle(Some(self.expanded))
                    .on_toggle(cx.listener(|this: &mut DependencyList, _, _, cx| {
                        this.expanded = !this.expanded;
                        cx.notify();
                    })),
            )
            .when(self.expanded, |list| {
                list.child(
                    ListItem::new("dependency-gpui")
                        .start_slot(Icon::new(IconName::Folder).size(IconSize::Small))
                        .child(Label::new("gpui")),
                )
            })
    }
}
```

Right click destekli satır:

```rust
use ui::prelude::*;
use ui::{ListItem, Tooltip};

fn render_contextual_file_row() -> impl IntoElement {
    ListItem::new("contextual-file-row")
        .start_slot(Icon::new(IconName::File).size(IconSize::Small))
        .child(Label::new("settings.json").truncate())
        .end_slot(
            IconButton::new("contextual-file-actions", IconName::Ellipsis)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("File actions")),
        )
        .show_end_slot_on_hover()
        .on_secondary_mouse_down(|event, _window, cx| {
            cx.stop_propagation();
            let _position = event.position;
        })
}
```

## 7. Tab Bileşenleri

Tab bileşenleri yatay navigation yüzeyi kurmak için kullanılır. `Tab`, tek bir
tab satırını çizer; `TabBar`, bu tabları start/end action alanları ve yatay scroll
container'ı içinde düzenler. Seçili tab, aktif index, close davranışı ve tabların
pozisyonu view state'i tarafından hesaplanmalıdır.

Genel seçim rehberi:

- Tek tab yüzeyi için `Tab`.
- Tab koleksiyonunu, soldaki/sağdaki toolbar kontrollerini ve yatay scroll
  alanını bir arada çizmek için `TabBar`.
- Dosya/editor sekmeleri gibi bitişik border davranışı önemliyse her tab için
  doğru `TabPosition` verin.
- Tab içeriğinde icon, dirty indicator veya close/pin butonu gerekiyorsa
  `start_slot(...)` ve `end_slot(...)` kullanın.

### Tab

Kaynak:

- Tanım: `../zed/crates/ui/src/components/tab.rs`
- Export: `ui::Tab`, `ui::TabPosition`, `ui::TabCloseSide`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Tab`

Ne zaman kullanılır:

- Editor, pane, preview veya ayar ekranında yatay sekme satırı çizmek için.
- Seçili ve seçili olmayan tabların Zed tema renkleriyle uyumlu görünmesi
  gerektiğinde.
- Tabın solunda status/icon, sağında close/pin/action butonu gerektiğinde.

Ne zaman kullanılmaz:

- Segmented control veya mod seçici için `ToggleButtonGroup` daha doğru.
- İçerik değiştirmeyen basit toolbar eylemleri için `Button` veya `IconButton`
  kullanın.
- Dikey navigation için `ListItem` / `TreeViewItem` daha uygundur.

Temel API:

- Constructor: `Tab::new(id)`
- Builder'lar: `.position(TabPosition)`, `.close_side(TabCloseSide)`,
  `.start_slot(...)`, `.end_slot(...)`, `.toggle_state(bool)`
- Ölçü helper'ları: `Tab::content_height(cx)`, `Tab::container_height(cx)`
- `TabPosition`: `First`, `Middle(Ordering)`, `Last`
- `TabCloseSide`: `Start`, `End`
- `InteractiveElement` ve `StatefulInteractiveElement` implement ettiği için
  `.on_click(...)`, drag/drop ve tooltip gibi GPUI interactivity builder'ları
  kullanılabilir.

Davranış:

- `RenderOnce`, `Toggleable` ve `ParentElement` implement eder.
- `toggle_state(true)` aktif tab renklerini ve border düzenini seçer.
- `TabPosition` aktif tab çevresindeki border'ları belirler. `Middle(Ordering)`
  içindeki `Ordering`, tabın seçili taba göre solunda mı sağında mı olduğunu
  anlatır.
- `close_side(TabCloseSide::Start)`, start ve end slotların görsel tarafını
  değiştirir. Workspace tablarında close butonunun sol/sağ ayarı bu yolla
  uygulanır.
- Child içerik `text_color(...)` atanmış bir `h_flex` içinde çizilir.

Örnek:

```rust
use ui::prelude::*;
use ui::{Tab, TabCloseSide, TabPosition, Tooltip};

fn tab_position(index: usize, active: usize, count: usize) -> TabPosition {
    if index == 0 {
        TabPosition::First
    } else if index + 1 == count {
        TabPosition::Last
    } else {
        TabPosition::Middle(index.cmp(&active))
    }
}

struct EditorTabs {
    active: usize,
}

impl EditorTabs {
    fn render_tab(
        &self,
        index: usize,
        count: usize,
        title: &'static str,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        Tab::new(("editor-tab", index))
            .position(tab_position(index, self.active, count))
            .close_side(TabCloseSide::End)
            .toggle_state(self.active == index)
            .start_slot(Icon::new(IconName::File).size(IconSize::Small).color(Color::Muted))
            .end_slot(
                IconButton::new(("close-editor-tab", index), IconName::Close)
                    .icon_size(IconSize::Small)
                    .tooltip(Tooltip::text("Close tab")),
            )
            .child(title)
            .on_click(cx.listener(move |this: &mut EditorTabs, _, _, cx| {
                this.active = index;
                cx.notify();
            }))
    }
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/pane.rs`: editor/pane tab render'ı, close side,
  drag/drop, pinned tab ve sağ tık context menu davranışları.
- Component preview: `../zed/crates/ui/src/components/tab.rs`.

Dikkat edilecekler:

- `Tab` kendi başına aktif tabı değiştirmez. Click handler içinde view state'ini
  güncelleyin ve `cx.notify()` çağırın.
- `TabPosition` verilmezse varsayılan `First` olur; çoklu tab bar içinde her tab
  için doğru pozisyonu hesaplayın.
- Close butonu gibi `end_slot` kontrolleri için ayrı, stable id kullanın.
- Tab label'ının aktif/pasif text rengini doğrudan miras almasını istiyorsanız
  basit string child kullanın. Özel label/truncation gerektiğinde renk davranışını
  ayrıca kontrol edin.
- `Tab::new("")` gibi boş id yalnızca özel render proxy'lerinde kullanılmalı;
  normal listelerde stable id tercih edin.

### TabBar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/tab_bar.rs`
- Export: `ui::TabBar`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for TabBar`

Ne zaman kullanılır:

- Birden fazla `Tab` öğesini ortak tab bar yüzeyinde göstermek için.
- Tabların solunda navigation/history, sağında create/settings gibi toolbar
  eylemleri gerekiyorsa.
- Tab listesi yatayda taşabilir ve scroll state'i takip edilecekse.

Ne zaman kullanılmaz:

- Tek bir segment kontrol veya küçük mod seçici için `ToggleButtonGroup`.
- Dikey navigation veya tree için `List` / `TreeViewItem`.

Temel API:

- Constructor: `TabBar::new(id)`
- Builder'lar: `.track_scroll(&ScrollHandle)`, `.start_child(...)`,
  `.start_children(...)`, `.end_child(...)`, `.end_children(...)`
- Düşük seviye mutator'lar: `.start_children_mut() -> &mut SmallVec<[AnyElement;
  2]>` ve `.end_children_mut() -> &mut SmallVec<[AnyElement; 2]>` builder
  zinciri dışında, parent state içinden start/end slot listesini elle
  değiştirmek istediğinizde kullanılır. Normal kompozisyonda tercih edilmez.
- `ParentElement` implement eder; tablar `.child(...)` / `.children(...)` ile
  orta scroll alanına eklenir.

Davranış:

- `RenderOnce` implement eder.
- Start children varsa sol tarafta border'lı, flex-none bir alan oluşturur.
- Orta tab alanı `overflow_x_scroll()` kullanan `h_flex` içinde render edilir.
- End children varsa sağ tarafta border'lı, flex-none bir alan oluşturur.
- `.track_scroll(...)` internal tab scroll container'ına scroll handle bağlar.
- TabBar, çocuk tabların `TabPosition` veya selected state'ini hesaplamaz.

Örnek:

```rust
use ui::prelude::*;
use ui::{Tab, TabBar, TabPosition, Tooltip};

fn tab_position(index: usize, active: usize, count: usize) -> TabPosition {
    if index == 0 {
        TabPosition::First
    } else if index + 1 == count {
        TabPosition::Last
    } else {
        TabPosition::Middle(index.cmp(&active))
    }
}

fn render_editor_tab_bar(active: usize) -> impl IntoElement {
    let count = 3;

    TabBar::new("editor-tab-bar")
        .start_child(
            IconButton::new("navigate-back", IconName::ArrowLeft)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Back")),
        )
        .start_child(
            IconButton::new("navigate-forward", IconName::ArrowRight)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Forward")),
        )
        .child(
            Tab::new("tab-main")
                .position(tab_position(0, active, count))
                .toggle_state(active == 0)
                .child("main.rs"),
        )
        .child(
            Tab::new("tab-lib")
                .position(tab_position(1, active, count))
                .toggle_state(active == 1)
                .child("lib.rs"),
        )
        .child(
            Tab::new("tab-settings")
                .position(tab_position(2, active, count))
                .toggle_state(active == 2)
                .child("settings.json"),
        )
        .end_child(
            IconButton::new("new-tab", IconName::Plus)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("New tab")),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/pane.rs`: tek satır, pinned/unpinned ve iki satırlı
  tab bar kompozisyonları.
- Component preview: `../zed/crates/ui/src/components/tab_bar.rs`.

Dikkat edilecekler:

- Start/end children tab scroll alanına dahil değildir; navigation ve global tab
  eylemleri için uygundurlar.
- Tabların taşması bekleniyorsa `ScrollHandle` view state'inde saklanıp
  `.track_scroll(...)` ile bağlanmalıdır.
- Pinned ve unpinned tabları ayrı satırda göstermek gerekiyorsa iki ayrı
  `TabBar` compose edin; kaynakta workspace pane bu yaklaşımı kullanır.

### Tab Kompozisyon Örnekleri

Close butonu solda olan tab:

```rust
use ui::prelude::*;
use ui::{Tab, TabCloseSide, TabPosition, Tooltip};

fn render_left_close_tab() -> impl IntoElement {
    Tab::new("preview-tab")
        .position(TabPosition::First)
        .close_side(TabCloseSide::Start)
        .toggle_state(true)
        .end_slot(
            IconButton::new("close-preview-tab", IconName::Close)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Close preview")),
        )
        .child("Preview")
}
```

Scroll handle bağlanan tab bar:

```rust
use gpui::ScrollHandle;
use ui::prelude::*;
use ui::{Tab, TabBar};

struct ScrollableTabs {
    scroll_handle: ScrollHandle,
}

impl Render for ScrollableTabs {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        TabBar::new("scrollable-tabs")
            .track_scroll(&self.scroll_handle)
            .child(Tab::new("tab-a").child("A"))
            .child(Tab::new("tab-b").child("B"))
    }
}
```

## 8. Layout Yardımcıları

Layout yardımcıları, GPUI `div()` üzerine Zed'in sık kullanılan flex ve separator
kalıplarını ekler. Bunlar yüksek seviyeli component değil, layout kurarken tekrar
eden stil dizilerini kısaltan yapı taşlarıdır. İçerik semantiği veya state
yönetimi sağlamazlar.

Genel seçim rehberi:

- Satır düzeni ve dikey ortalama için `h_flex()`.
- Kolon düzeni için `v_flex()`.
- Küçük, tutarlı boşluklu inline gruplar için `h_group*`.
- Küçük, tutarlı boşluklu dikey gruplar için `v_group*`.
- Section, toolbar veya panel ayrımı için `Divider`.
- Sadece tek seferlik özel layout gerekiyorsa doğrudan `div()` + GPUI style
  builder'ları yeterlidir.

### h_flex ve v_flex

Kaynak:

- Tanım: `../zed/crates/ui/src/components/stack.rs`
- Altyapı: `../zed/crates/ui/src/traits/styled_ext.rs`
- Export: `ui::h_flex`, `ui::v_flex`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Bileşenleri satır veya kolon içinde hızlıca hizalamak için.
- Buton toolbar'ları, metadata satırları, icon + label kombinasyonları ve panel
  içerik düzenleri için.

Ne zaman kullanılmaz:

- Semantik component gerekiyorsa `ListItem`, `ButtonLike`, `Tab`, `Modal` gibi
  daha yüksek seviyeli bileşenler önceliklidir.
- Sadece tek stil gerekiyorsa doğrudan `div()` kullanmak daha açık olabilir.

Temel API:

- `h_flex() -> Div`
- `v_flex() -> Div`
- Aynı davranış herhangi bir `Styled` üzerinde `.h_flex()` ve `.v_flex()` olarak
  da kullanılabilir.

Davranış:

- `h_flex()` kaynakta `div().h_flex()` çağırır.
- `StyledExt::h_flex()` sırasıyla `.flex().flex_row().items_center()` uygular.
- `v_flex()` kaynakta `div().v_flex()` çağırır.
- `StyledExt::v_flex()` sırasıyla `.flex().flex_col()` uygular.
- Her ikisi de yalnızca layout stilini ayarlar; gap, width, overflow ve
  responsive davranış ayrıca verilmelidir.

Örnek:

```rust
use ui::prelude::*;
use ui::Tooltip;

fn render_toolbar_title(path: SharedString) -> impl IntoElement {
    h_flex()
        .w_full()
        .min_w_0()
        .justify_between()
        .gap_2()
        .child(
            h_flex()
                .min_w_0()
                .gap_1()
                .child(Icon::new(IconName::File).size(IconSize::Small).color(Color::Muted))
                .child(Label::new(path).truncate()),
        )
        .child(
            IconButton::new("toolbar-refresh", IconName::RotateCw)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Refresh")),
        )
}
```

Dikkat edilecekler:

- `h_flex()` varsayılan olarak `items_center()` uygular. Üstten hizalama
  gerekiyorsa `.items_start()` ile override edin.
- Uzun metin taşıyan h-flex satırlarında parent'a `.min_w_0()`, label'a
  `.truncate()` ekleyin.
- `v_flex()` gap vermez. Dikey boşluğu `.gap_*()` veya padding ile açıkça kurun.

### h_group ve v_group

Kaynak:

- Tanım: `../zed/crates/ui/src/components/group.rs`
- Export: `ui::h_group_sm`, `ui::h_group`, `ui::h_group_lg`,
  `ui::h_group_xl`, `ui::v_group_sm`, `ui::v_group`, `ui::v_group_lg`,
  `ui::v_group_xl`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Birbirine yakın durması gereken küçük ikon, label, badge veya button grupları
  için.
- Tekrarlanan compact spacing değerlerini aynı helper üzerinden korumak için.

Ne zaman kullanılmaz:

- Ana sayfa/panel layout'u için `h_flex()` / `v_flex()` daha açık.
- Büyük section boşlukları için helper spacing'i çok küçüktür; explicit `.gap_4()`
  gibi değerler kullanın.

Temel API:

- `h_group_sm()` -> `div().flex().gap_0p5()`
- `h_group()` -> `div().flex().gap_1()`
- `h_group_lg()` -> `div().flex().gap_1p5()`
- `h_group_xl()` -> `div().flex().gap_2()`
- `v_group_sm()` -> `div().flex().flex_col().gap_0p5()`
- `v_group()` -> `div().flex().flex_col().gap_1()`
- `v_group_lg()` -> `div().flex().flex_col().gap_1p5()`
- `v_group_xl()` -> `div().flex().flex_col().gap_2()`

Davranış:

- `h_group*` helper'ları `items_center()` eklemez. Satırdaki elemanların dikey
  hizası önemliyse `.items_center()` veya `.items_start()` ekleyin.
- `v_group*` helper'ları `flex_col()` ekler.
- Helper isimleri spacing ölçeğini anlatır: `sm`, varsayılan, `lg`, `xl`.

Örnek:

```rust
use ui::prelude::*;
use ui::Indicator;

fn render_status_cluster(count: usize) -> impl IntoElement {
    h_group()
        .items_center()
        .child(Indicator::dot().color(Color::Success))
        .child(Label::new("Synced").size(LabelSize::Small).color(Color::Muted))
        .child(Label::new(format!("{count} changes")).size(LabelSize::Small).color(Color::Muted))
}
```

```rust
use ui::prelude::*;

fn render_metadata_stack(branch: SharedString, path: SharedString) -> impl IntoElement {
    v_group_sm()
        .min_w_0()
        .child(Label::new(branch).size(LabelSize::Small).truncate())
        .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate())
}
```

Dikkat edilecekler:

- `h_group*` ve `v_group*` component değildir; sadece `Div` döndürür.
- Group helper'larını iç içe fazla kullanmak layout'u belirsizleştirir. Ana
  container için `h_flex` / `v_flex`, küçük alt kümeler için group helper
  kullanın.

### Divider

Kaynak:

- Tanım: `../zed/crates/ui/src/components/divider.rs`
- Export: `ui::Divider`, `ui::DividerColor`, `ui::divider`,
  `ui::vertical_divider`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Divider`

Ne zaman kullanılır:

- Panel, modal, toolbar veya listede görsel ayırıcı çizmek için.
- Aynı container içinde iki içeriği ince border rengiyle ayırmak için.
- Dashed separator gerekiyorsa dashed constructor'lar ile.

Ne zaman kullanılmaz:

- `ContextMenu` içinde separator gerekiyorsa `ContextMenu::separator()`.
- Sadece boşluk gerekiyorsa divider yerine margin/gap kullanın.
- Tablo veya listede semantic row separator gerekiyorsa ilgili component'in
  kendi border/separator davranışını tercih edin.

Temel API:

- Helper constructor'lar: `divider()`, `vertical_divider()`
- Associated constructor'lar: `Divider::horizontal()`, `Divider::vertical()`,
  `Divider::horizontal_dashed()`, `Divider::vertical_dashed()`
- Builder'lar: `.inset()`, `.color(DividerColor)`
- `DividerColor`: `Border`, `BorderFaded`, `BorderVariant`

Davranış:

- Varsayılan renk `DividerColor::BorderVariant`.
- Solid divider `bg(...)` ile çizilir.
- Dashed divider `canvas(...)` ve `PathBuilder::stroke(px(1.)).dash_array(...)`
  ile çizilir.
- Horizontal divider `h_px().w_full()`; vertical divider `w_px().h_full()` kullanır.
- `.inset()` horizontal için `mx_1p5()`, vertical için `my_1p5()` uygular.
- Vertical divider'ın görünür olması için parent container'ın yüksekliği belirli
  veya içerikten türetilmiş olmalıdır.

Örnek:

```rust
use ui::prelude::*;
use ui::{Divider, DividerColor};

fn render_settings_section() -> impl IntoElement {
    v_flex()
        .gap_3()
        .child(Label::new("Editor").size(LabelSize::Small).color(Color::Muted))
        .child(Divider::horizontal().color(DividerColor::BorderFaded))
        .child(Label::new("Format on save"))
}
```

```rust
use ui::prelude::*;
use ui::{Divider, DividerColor};

fn render_split_toolbar() -> impl IntoElement {
    h_flex()
        .h_8()
        .gap_2()
        .child(Button::new("run", "Run"))
        .child(Divider::vertical().color(DividerColor::Border))
        .child(Button::new("debug", "Debug"))
}
```

Zed içinden kullanım:

- `../zed/crates/settings_ui/src/settings_ui.rs`: section alt border'ları.
- `../zed/crates/recent_projects/src/recent_projects.rs`: proje grupları ve
  toolbar ayrımları.
- `../zed/crates/git_ui/src/project_diff.rs`: diff toolbar vertical divider'ları.

Dikkat edilecekler:

- Divider layout değil, görsel ayrımdır. Çok sık kullanıldığında UI kalabalık
  görünür; section hiyerarşisi için önce spacing ve başlık kullanın.
- Dashed divider özel canvas çizimi yapar. Basit ayrım için solid divider daha
  ucuz ve tutarlıdır.

### Layout Kompozisyon Örnekleri

Panel iskeleti:

```rust
use ui::prelude::*;
use ui::{Divider, Tooltip};

fn render_panel_shell(title: SharedString) -> impl IntoElement {
    v_flex()
        .size_full()
        .child(
            h_flex()
                .h_8()
                .px_2()
                .justify_between()
                .child(Label::new(title).truncate())
                .child(
                    IconButton::new("panel-close", IconName::Close)
                        .icon_size(IconSize::Small)
                        .tooltip(Tooltip::text("Close panel")),
                ),
        )
        .child(Divider::horizontal())
        .child(v_flex().flex_1().min_h_0().p_2().gap_2())
}
```

Inline metadata:

```rust
use ui::prelude::*;

fn render_branch_metadata(branch: SharedString, ahead: usize) -> impl IntoElement {
    h_group_sm()
        .items_center()
        .child(Icon::new(IconName::GitBranch).size(IconSize::Small).color(Color::Muted))
        .child(Label::new(branch).size(LabelSize::Small).truncate())
        .child(Label::new(format!("ahead {ahead}")).size(LabelSize::Small).color(Color::Muted))
}
```

### Scrollbar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/scrollbar.rs`
- Export: `ui::Scrollbars`, `ui::ScrollAxes`, `ui::ScrollbarStyle`,
  `ui::scrollbars::{ShowScrollbar, ScrollbarAutoHide, ScrollbarVisibility}`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok; gerçek kullanım panel, modal ve
  tablo kompozisyonları içindedir.

Ne zaman kullanılır:

- Bir scroll container'a Zed tema renkleriyle uyumlu scrollbar bağlamak için.
- Tablo, panel veya picker gibi içeriklerde tema scrollbar ayarına saygı
  duyan otomatik gösterim/gizleme davranışı gerektiğinde.
- Yatay, dikey veya iki yönlü scroll track'ini tek API ile yönetmek için.

Ne zaman kullanılmaz:

- Doğal browser/native scroll yeterliyse `overflow_y_scroll()` veya
  `overflow_x_scroll()` ile basit container kullanın; `Scrollbars`, tema ile
  hizalanmış özel scrollbar yüzeyi gerektiğinde devreye girer.

Temel API:

- `Scrollbars::new(show_along: ScrollAxes)`
- `Scrollbars::always_visible(show_along)`
- `Scrollbars::for_settings::<S: ScrollbarVisibility>()`
- `.id(ElementId)`, `.notify_content()`, `.tracked_entity(EntityId)`,
  `.tracked_scroll_handle(handle)`, `.show_along(axes)`, `.style(style)`,
  `.with_track_along(axes, bg)`, `.with_stable_track_along(axes, bg)`
- `WithScrollbar`: elementlere `.vertical_scrollbar_for(...)` ve
  `.custom_scrollbars(...)` ekleyen extension trait. Kaynakta yatay/double helper
  taslakları yorum satırı olarak durur; public API değildir.
- `ScrollableHandle`: custom handle yazacaksanız `max_offset`, `set_offset`,
  `offset`, `viewport` ve opsiyonel drag hook'larını sağlar.
- `on_new_scrollbars::<S>(cx)`: scrollbar global setting tipi değiştiğinde
  yeni `ScrollbarState` entity'lerini ayar değişikliklerine abone eden setup
  helper'ı.
- `ScrollAxes`: `Horizontal`, `Vertical`, `Both`.
- `ScrollbarStyle`: `Regular` (6px), `Editor` (15px).
- `ShowScrollbar`: `Auto`, `System`, `Always`, `Never`.

Davranış:

- `Scrollbars::new(ScrollAxes::Vertical)` varsayılan olarak tema scrollbar
  ayarına bağlı görünür; `always_visible(...)` ayarı yok sayar.
- `tracked_scroll_handle(...)`, harici bir `ScrollableHandle` (örn.
  `ScrollHandle`, `UniformListScrollHandle`) kullanır.
- `Table::interactable(...)` ile `TableInteractionState::with_custom_scrollbar(...)`
  birlikte verildiğinde `Scrollbars` tablonun yatay/dikey scroll handle'larına
  bağlanır.
- `ScrollbarStyle::Editor`, editor görselli scrollbar genişliği için
  kullanılır; panel ve liste için `Regular` daha uygundur.

Örnek:

```rust
use gpui::ScrollHandle;
use ui::prelude::*;
use ui::{ScrollAxes, Scrollbars};

struct LogPanel {
    scroll: ScrollHandle,
}

impl Render for LogPanel {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .size_full()
            .child(
                div()
                    .id("log-body")
                    .flex_1()
                    .overflow_y_scroll()
                    .track_scroll(&self.scroll)
                    .child(Label::new("…")),
            )
            .child(
                Scrollbars::new(ScrollAxes::Vertical)
                    .tracked_scroll_handle(self.scroll.clone()),
            )
    }
}
```

Dikkat edilecekler:

- `Scrollbars` kendi başına içerik scroll'lamaz; bir `ScrollableHandle` ile
  bağlanmalı veya bir `ScrollHandle::new()` üzerinden takip etmelidir.
- Tek bir scroll container'a doğrudan bağlanıyorsanız `WithScrollbar` helper'ları
  ayrı `Scrollbars` child'ı yazmaktan daha kısa ve daha az hata açıktır.
- `with_stable_track_along(...)`, scroll alanı yokken bile track yer ayırır;
  böylece scrollbar görünür/gizli değiştiğinde layout zıplaması olmaz.
- Birden çok scroll alanı varsa her birine `.id(...)` ile benzersiz id verin.

## 9. Veri ve Tablo Bileşenleri

Zed UI tarafında tablo ihtiyacı için ana giriş noktası `Table` bileşenidir.
Küçük ve sabit satırlı tabloları doğrudan `.row(...)` ile, büyük tabloları ise
GPUI'nin sanallaştırılmış liste altyapısına bağlanan `.uniform_list(...)` veya
`.variable_row_height_list(...)` ile render eder.

### GPUI uniform_list ile köprü

`Table::uniform_list(...)` ve Bölüm 6'daki büyük listeler aslında GPUI'nin
`uniform_list(...)` elementine bağlanır. Bu element, görünür satır aralığını
parça parça render ederek binlerce satırlı listeleri performans kaybı olmadan
gösterir. Kullanım kuralları:

- `uniform_list(id, item_count, |range, window, cx| Vec<AnyElement>)`: id ve
  satır sayısını alır, kalan kısım yalnızca görünür `range` için satırları
  üretir. Range içindeki indeks dizisi `range.map(|ix| ...)`.
- Satır yüksekliği homojen olmalıdır; içerik her satırda farklı yükseklik
  istiyorsa GPUI `list(...)` elementi ve `ListState` ile çalışan
  `Table::variable_row_height_list(...)` daha uygundur.
- Scroll davranışı için `UniformListScrollHandle` view struct'ında saklanır
  ve `.track_scroll(&handle)` ile bağlanır. `Table::interactable(...)`
  davranışı bunu kendi `TableInteractionState`'inde yönetir.
- `with_sizing_behavior(ListSizingBehavior::Infer)`, listenin içeriğine göre
  yükseklik almasını sağlar; `Fill` parent yüksekliğini kullanır.
- `with_decoration(...)` slotuna `IndentGuides`, `StickyItems` gibi
  decoration'lar bağlanır; bu decorations `UniformListDecoration` trait'ini
  implement etmelidir.

Karar matrisi:

| Satır modeli | Kullanım |
| :-- | :-- |
| Sabit, az satır | `List::new()` + `ListItem::new(...)`; doğrudan parent içinde scroll. |
| Sabit yükseklik, çok satır | `uniform_list(id, count, ...)` veya `Table::uniform_list(...)`. |
| Değişken yükseklik, çok satır | `gpui::list(...) + ListState` veya `Table::variable_row_height_list(...)`. |
| Hiyerarşik / sticky parent | `uniform_list(...)` + `IndentGuides` + `StickyItems`. |

`gpui::ListAlignment` (`Top`, `Bottom`) ve `ListSizingBehavior`
(`Fill`, `Infer`) için tip referansları `gpui` crate'inde tanımlıdır; UI
tarafında bunları kullanan örnekler `crates/keymap_editor`, `crates/csv_preview`
ve `crates/project_panel` içinde yer alır.

Bu ailede üç karar birlikte düşünülmelidir:

- Satır modeli: sabit satır listesi, sabit yükseklikli sanallaştırılmış liste
  veya değişken yükseklikli sanallaştırılmış liste.
- Kolon genişliği modeli: otomatik, explicit, redistributable veya resizable.
- Etkileşim modeli: sadece görsel tablo veya focus/scroll/resize state'i olan
  interactable tablo.

### Table

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::Table`, `ui::UncheckedTableRow`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Table`

Ne zaman kullanılır:

- Header, satır border'ları, striped görünüm ve kolon hizası gereken veri
  görünümleri için.
- Satır sayısı büyüdüğünde sanallaştırma üzerinden performanslı tablo render
  etmek için.
- Kolon genişliklerinin tek API üzerinden yönetilmesini istediğiniz durumlarda.

Ne zaman kullanılmaz:

- Tek kolonlu seçim listelerinde `List` / `ListItem` daha uygundur.
- Hiyerarşik veri için `TreeViewItem` kullanın.
- Form satırları veya toolbar bilgisi için tablo yerine `h_flex()` / `v_flex()`
  ile daha açık layout kurun.

Temel API:

- Constructor: `Table::new(cols)`
- Header: `.header(headers)`
- Sabit satır: `.row(items)`
- Sanallaştırılmış sabit yükseklikli satırlar:
  `.uniform_list(id, row_count, render_item_fn)`
- Sanallaştırılmış değişken yükseklikli satırlar:
  `.variable_row_height_list(row_count, list_state, render_row_fn)`
- Görsel builder'lar: `.striped()`, `.hide_row_borders()`, `.hide_row_hover()`,
  `.no_ui_font()`, `.disable_base_style()`
- Genişlik: `.width(width)`, `.width_config(config)`
- Etkileşim: `.interactable(&table_interaction_state)`
- Satır özelleştirme: `.map_row(callback)`
- Boş durum: `.empty_table_callback(callback)`

Davranış:

- `cols`, tablo satırlarının ve header'ın beklenen kolon sayısıdır.
- `.header(...)` ve `.row(...)` içine verilen `Vec<T>`, içeride `TableRow<T>`'a
  çevrilir. Eleman sayısı `cols` ile eşleşmezse panic oluşur.
- Varsayılan hücre stili `px_1()`, `py_0p5()`, `whitespace_nowrap()`,
  `text_ellipsis()` ve `overflow_hidden()` uygular.
- `.disable_base_style()` hücre baz stilini kapatır. CSV önizleme gibi her
  hücrenin kendi layout'unu taşıdığı durumlarda kullanılır.
- `.row(...)`, sadece tablo sabit satır modundayken satır ekler. Tablo
  `.uniform_list(...)` veya `.variable_row_height_list(...)` ile kurulduktan
  sonra satırlar closure üzerinden üretilir.
- `.map_row(...)`, tablonun oluşturduğu `Stateful<Div>` satır container'ını
  alır; seçili satır, hover state'i, sağ tık veya özel click davranışı eklemek
  için uygundur.

Minimum örnek:

```rust
use ui::{Table, prelude::*};

fn render_model_table() -> impl IntoElement {
    Table::new(3)
        .width(px(520.))
        .header(vec!["Model", "Provider", "Status"])
        .row(vec!["gpt-5.2", "OpenAI", "Ready"])
        .row(vec!["claude-sonnet", "Anthropic", "Needs key"])
        .row(vec!["local-llm", "Ollama", "Offline"])
        .striped()
}
```

Karışık hücre içeriği:

```rust
use ui::{Button, ButtonStyle, Indicator, Table, prelude::*};

fn render_package_row_table() -> impl IntoElement {
    Table::new(4)
        .width(px(720.))
        .header(vec![
            "State".into_any_element(),
            "Package".into_any_element(),
            "Version".into_any_element(),
            "Action".into_any_element(),
        ])
        .row(vec![
            Indicator::dot().color(Color::Success).into_any_element(),
            Label::new("rust-analyzer").truncate().into_any_element(),
            Label::new("1.0.0").color(Color::Muted).into_any_element(),
            Button::new("open-rust-analyzer", "Open")
                .style(ButtonStyle::Subtle)
                .into_any_element(),
        ])
}
```

Sabit yükseklikli büyük liste:

```rust
use gpui::Entity;
use ui::{Table, TableInteractionState, prelude::*};

#[derive(Clone)]
struct PackageRow {
    name: SharedString,
    version: SharedString,
    enabled: bool,
}

struct PackagesTable {
    table_state: Entity<TableInteractionState>,
    rows: Vec<PackageRow>,
}

impl PackagesTable {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            rows: Vec::new(),
        }
    }
}

impl Render for PackagesTable {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let rows = self.rows.clone();

        Table::new(3)
            .interactable(&self.table_state)
            .striped()
            .header(vec!["Package", "Version", "State"])
            .uniform_list("packages-table", rows.len(), move |range, _window, _cx| {
                range
                    .map(|index| {
                        let row = &rows[index];
                        vec![
                            Label::new(row.name.clone()).truncate().into_any_element(),
                            Label::new(row.version.clone())
                                .color(Color::Muted)
                                .into_any_element(),
                            Label::new(if row.enabled { "Enabled" } else { "Disabled" })
                                .into_any_element(),
                        ]
                    })
                    .collect()
            })
    }
}
```

Değişken yükseklikli satırlar:

```rust
use gpui::{Entity, ListAlignment, ListState};
use ui::{Table, TableInteractionState, prelude::*};

#[derive(Clone)]
struct LogRow {
    level: SharedString,
    message: SharedString,
}

struct LogTable {
    table_state: Entity<TableInteractionState>,
    list_state: ListState,
    rows: Vec<LogRow>,
}

impl LogTable {
    fn new(rows: Vec<LogRow>, cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            list_state: ListState::new(rows.len(), ListAlignment::Top, px(100.)),
            rows,
        }
    }

    fn replace_rows(&mut self, rows: Vec<LogRow>, cx: &mut Context<Self>) {
        self.list_state.reset(rows.len());
        self.rows = rows;
        cx.notify();
    }
}

impl Render for LogTable {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let rows = self.rows.clone();

        Table::new(2)
            .interactable(&self.table_state)
            .header(vec!["Level", "Message"])
            .variable_row_height_list(rows.len(), self.list_state.clone(), move |index, _, _| {
                let row = &rows[index];
                vec![
                    Label::new(row.level.clone()).color(Color::Muted).into_any_element(),
                    div()
                        .whitespace_normal()
                        .child(Label::new(row.message.clone()))
                        .into_any_element(),
                ]
            })
    }
}
```

Zed içinden kullanım:

- `../zed/crates/ui/src/components/data_table.rs`: component preview içindeki
  basit, striped ve karışık içerikli tablo örnekleri.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: keymap tablosu,
  `uniform_list`, `TableInteractionState` ve redistributable kolonlar.
- `../zed/crates/csv_preview/src/renderer/render_table.rs`: CSV için
  `ResizableColumnsState`, `disable_base_style()` ve iki farklı render
  mekanizması.
- `../zed/crates/edit_prediction_ui/src/edit_prediction_context_view.rs`:
  metadata için küçük, UI fontu kapatılmış tablo.

Dikkat edilecekler:

- Header ve tüm satırlar aynı kolon sayısında olmalıdır.
- `Vec` içinde farklı element tipleri kullanıyorsanız her hücreyi
  `.into_any_element()` ile aynı tipe çevirin.
- Büyük veri setlerinde `.row(...)` ile binlerce satır eklemeyin;
  `.uniform_list(...)` veya `.variable_row_height_list(...)` kullanın.
- `variable_row_height_list` için `ListState` satır sayısıyla senkron tutulmalıdır.
  Veri sayısı değiştiğinde `reset(...)` veya uygun `splice(...)` çağrısı yapın.

### TableInteractionState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::TableInteractionState`
- Prelude: Hayır, ayrıca import edin.
- Render modeli: `Entity<TableInteractionState>` olarak view state'inde tutulur.

Ne zaman kullanılır:

- Tablo kendi içinde dikey kaydırma yapacaksa.
- Kolon resize handle'ları kullanılacaksa.
- Tablo focus handle'ı, scroll offset'i veya özel scrollbar ayarı dışarıdan
  yönetilecekse.

Temel API:

- `TableInteractionState::new(cx)`
- `.with_custom_scrollbar(scrollbars)`
- `.scroll_offset() -> Point<Pixels>`
- `.set_scroll_offset(offset)`
- `TableInteractionState::listener(&entity, callback)`

Davranış:

- `focus_handle`, `scroll_handle`, `horizontal_scroll_handle` ve isteğe bağlı
  `custom_scrollbar` taşır.
- `.interactable(&state)` verilmedikçe tablo scroll/focus state'ini bu entity'ye
  bağlamaz.
- Yatay scroll, tablo genişliği modeline bağlıdır. Sabit toplam genişlik veya
  `ResizableColumnsState` yoksa tablo genellikle container'a sığacak şekilde
  davranır.
- `with_custom_scrollbar(...)`, Zed ayarlarından gelen scrollbar davranışını
  tabloya taşımak için kullanılır.

Örnek:

```rust
use gpui::Entity;
use ui::{ScrollAxes, Scrollbars, Table, TableInteractionState, prelude::*};

struct AuditTable {
    table_state: Entity<TableInteractionState>,
}

impl AuditTable {
    fn new(cx: &mut Context<Self>) -> Self {
        let table_state = cx.new(|cx| {
            TableInteractionState::new(cx)
                .with_custom_scrollbar(Scrollbars::new(ScrollAxes::Both))
        });

        Self { table_state }
    }

    fn render_table(&self) -> impl IntoElement {
        Table::new(2)
            .interactable(&self.table_state)
            .header(vec!["Time", "Event"])
            .row(vec!["09:42", "Project opened"])
    }
}
```

Zed içinden kullanım:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: custom scrollbar ile
  interactable keymap tablosu.
- `../zed/crates/csv_preview/src/csv_preview.rs`: CSV önizleme scroll state'i.
- `../zed/crates/git_graph/src/git_graph.rs`: tablo focus handle'ını selection
  davranışıyla birleştiren örnek.

Dikkat edilecekler:

- `TableInteractionState` doğrudan struct alanı olarak değil, `Entity` içinde
  tutulmalıdır.
- Scroll offset'i elle set ediyorsanız, aynı frame içinde veri sayısı ve liste
  state'i değişiklikleriyle çakıştırmayın.
- Focus davranışı gerekiyorsa `focus_handle` alanı public olduğu için Zed'deki
  örnekler gibi `tab_index(...)` / `tab_stop(...)` ile yapılandırılabilir.

### ColumnWidthConfig

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::ColumnWidthConfig`, `ui::StaticColumnWidths`
- Prelude: Hayır, ayrıca import edin.

Ne zaman kullanılır:

- Kolonların otomatik, oranlı, explicit veya kullanıcı tarafından yeniden
  boyutlandırılabilir olmasını seçmek için.
- Sanallaştırılmış tabloda yatay sizing davranışını doğru kurmak için.

Temel API:

- `ColumnWidthConfig::auto()`: kolonlar ve tablo otomatik genişler.
- `ColumnWidthConfig::auto_with_table_width(width)`: `.width(width)` ile aynı
  davranış; tablo genişliği sabit, kolonlar otomatik.
- `ColumnWidthConfig::explicit(widths)`: her kolon için explicit
  `DefiniteLength`.
- `ColumnWidthConfig::redistributable(columns_state)`: toplam alan korunarak
  kolonlar yeniden paylaştırılır.
- `ColumnWidthConfig::Resizable(columns_state)`: kolonlar mutlak genişlik taşır,
  tablo toplam genişliği kolon toplamıyla değişir.

Explicit genişlik örneği:

```rust
use ui::{ColumnWidthConfig, Table, prelude::*};

fn render_explicit_width_table() -> impl IntoElement {
    Table::new(3)
        .width_config(ColumnWidthConfig::explicit(vec![
            DefiniteLength::Absolute(AbsoluteLength::Pixels(px(96.))),
            DefiniteLength::Fraction(0.35),
            DefiniteLength::Fraction(0.65),
        ]))
        .header(vec!["Kind", "Name", "Path"])
        .row(vec!["File", "main.rs", "crates/app/src/main.rs"])
}
```

Dikkat edilecekler:

- `.width(width)` sadece `ColumnWidthConfig::auto_with_table_width(width)`
  kısaltmasıdır. Resize gerekiyorsa `.width_config(...)` kullanın.
- `explicit(widths)` içindeki `widths.len()` tablo kolon sayısıyla aynı olmalıdır.
- `Resizable` için associated constructor yoktur; enum varyantı doğrudan
  `ColumnWidthConfig::Resizable(entity)` olarak kullanılır.

### RedistributableColumnsState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/redistributable_columns.rs`
- Export: `ui::RedistributableColumnsState`
- İlgili tipler: `ui::TableResizeBehavior`, `ui::HeaderResizeInfo`
- Prelude: Hayır, ayrıca import edin.

Ne zaman kullanılır:

- Tablo container genişliğini koruyacak, kullanıcı sadece kolonların birbirine
  göre oranını değiştirecekse.
- Keymap editor ve git graph gibi tabloda toplam alan sabit kalmalıysa.
- Oranlı ve mutlak başlangıç genişliklerini aynı tabloda kullanmanız gerekiyorsa.

Ne zaman kullanılmaz:

- CSV veya spreadsheet benzeri tabloda kullanıcı tek kolonu genişletince toplam
  tablo genişliği de büyümeliyse `ResizableColumnsState` kullanın.
- Sadece sabit oranlı kolon gerekiyorsa `ColumnWidthConfig::explicit(...)` daha
  basittir.

Temel API:

- `RedistributableColumnsState::new(cols, initial_widths, resize_behavior)`
- `.cols()`
- `.initial_widths()`
- `.preview_widths()`
- `.resize_behavior()`
- `.widths_to_render()`
- `.preview_fractions(rem_size)`
- `.preview_column_width(column_index, window)`
- `.cached_container_width()`
- `.set_cached_container_width(width)`
- `.commit_preview()`
- `.reset_column_to_initial_width(column_index, window)`

Davranış:

- Başlangıç genişlikleri `DefiniteLength` alır; aynı tabloda
  `DefiniteLength::Fraction(...)` ve `DefiniteLength::Absolute(...)`
  kullanılabilir.
- Drag sırasında `preview_widths` güncellenir, drop sonrasında `commit_preview()`
  ile kalıcı genişliklere aktarılır.
- `Table` içinde `.interactable(...)` ve
  `.width_config(ColumnWidthConfig::redistributable(...))` birlikte
  kullanıldığında resize handle binding'i normal tablo için otomatik yapılır.
- `TableResizeBehavior::None`, ilgili divider yönünde resize yayılımını engeller.
- `TableResizeBehavior::Resizable`, varsayılan minimum sınırla resize'a izin
  verir.
- `TableResizeBehavior::MinSize(value)`, redistributable algoritmada minimum
  kolon oranı olarak kullanılır.

Örnek:

```rust
use gpui::Entity;
use ui::{
    ColumnWidthConfig, RedistributableColumnsState, Table, TableInteractionState,
    TableResizeBehavior, prelude::*,
};

struct KeyBindingTable {
    table_state: Entity<TableInteractionState>,
    columns: Entity<RedistributableColumnsState>,
}

impl KeyBindingTable {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            columns: cx.new(|_cx| {
                RedistributableColumnsState::new(
                    4,
                    vec![
                        DefiniteLength::Absolute(AbsoluteLength::Pixels(px(36.))),
                        DefiniteLength::Fraction(0.42),
                        DefiniteLength::Fraction(0.28),
                        DefiniteLength::Fraction(0.30),
                    ],
                    vec![
                        TableResizeBehavior::None,
                        TableResizeBehavior::Resizable,
                        TableResizeBehavior::Resizable,
                        TableResizeBehavior::Resizable,
                    ],
                )
            }),
        }
    }

    fn render_table(&self) -> impl IntoElement {
        Table::new(4)
            .interactable(&self.table_state)
            .width_config(ColumnWidthConfig::redistributable(self.columns.clone()))
            .header(vec!["", "Action", "Keystrokes", "Context"])
            .empty_table_callback(|_, _| Label::new("No keybindings").into_any_element())
    }
}
```

Zed içinden kullanım:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: oranlı kolonlar ve
  resize edilebilir keybinding tablosu.
- `../zed/crates/git_graph/src/git_graph.rs`: graph alanı ve commit tablosu aynı
  redistributable state ile hizalanır.

Dikkat edilecekler:

- `cols`, `initial_widths.len()` ve `resize_behavior.len()` aynı olmalıdır.
- Normal `Table` kullanımında `bind_redistributable_columns(...)` ve
  `render_redistributable_columns_resize_handles(...)` çağırmayın; `Table` bunu
  kendi wrapper'ında yapar.
- Aynı kolon state'ini farklı görsel bölgelerde paylaşıyorsanız, düşük seviye
  helper'ları kullanmanız gerekir.

### ResizableColumnsState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::ResizableColumnsState`
- İlgili tipler: `ui::TableResizeBehavior`
- Prelude: Hayır, ayrıca import edin.

Ne zaman kullanılır:

- Her kolonun mutlak genişliği ayrı ayrı değişecekse.
- Kullanıcı bir kolonu büyüttüğünde toplam tablo genişliği büyümeli ve yatay
  scroll devreye girmeliyse.
- CSV, spreadsheet veya geniş veri önizlemeleri için.

Temel API:

- `ResizableColumnsState::new(cols, initial_widths, resize_behavior)`
- `.cols()`
- `.resize_behavior()`
- `.set_column_configuration(col_idx, width, resize_behavior)`
- `.reset_column_to_initial_width(col_idx)`

Davranış:

- Başlangıç genişlikleri `AbsoluteLength` alır.
- Resize edilen kolonun genişliği değişir; komşu kolonlardan oran çalınmaz.
- `ColumnWidthConfig::Resizable(entity)` tablo toplam genişliğini kolon
  genişliklerinin toplamından hesaplar.
- `TableResizeBehavior::MinSize(value)`, resizable algoritmada rem tabanlı minimum
  eşik olarak uygulanır.

Örnek:

```rust
use gpui::Entity;
use ui::{
    ColumnWidthConfig, ResizableColumnsState, Table, TableInteractionState,
    TableResizeBehavior, prelude::*,
};

struct CsvLikeTable {
    table_state: Entity<TableInteractionState>,
    columns: Entity<ResizableColumnsState>,
}

impl CsvLikeTable {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            columns: cx.new(|_cx| {
                ResizableColumnsState::new(
                    3,
                    vec![
                        AbsoluteLength::Pixels(px(56.)),
                        AbsoluteLength::Pixels(px(180.)),
                        AbsoluteLength::Pixels(px(320.)),
                    ],
                    vec![
                        TableResizeBehavior::None,
                        TableResizeBehavior::Resizable,
                        TableResizeBehavior::MinSize(8.),
                    ],
                )
            }),
        }
    }

    fn render_table(&self) -> impl IntoElement {
        Table::new(3)
            .interactable(&self.table_state)
            .width_config(ColumnWidthConfig::Resizable(self.columns.clone()))
            .header(vec!["#", "Name", "Value"])
            .row(vec!["1", "language", "Rust"])
    }
}
```

Zed içinden kullanım:

- `../zed/crates/csv_preview/src/csv_preview.rs`: CSV kolon state'i
  `ResizableColumnsState` ile tutulur.
- `../zed/crates/csv_preview/src/renderer/render_table.rs`: tablo
  `ColumnWidthConfig::Resizable(...)` ile render edilir.

Dikkat edilecekler:

- Bu model yatay scroll üretebilir; tabloyu `.interactable(...)` ile bağlayın.
- Kolon sayısı değişirse eski state'i güncellemek yerine yeni
  `ResizableColumnsState` oluşturmak daha nettir.
- `set_column_configuration(...)`, runtime'da tek kolonun başlangıç ve mevcut
  genişliğini birlikte günceller.

### TableRow ve UncheckedTableRow

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table/table_row.rs`
- Export: `ui::table_row::TableRow`
- Alias: `ui::UncheckedTableRow<T> = Vec<T>`
- Prelude: Hayır.

Ne zaman kullanılır:

- Düşük seviye tablo helper'larına doğrulanmış satır vermeniz gerekiyorsa.
- Kolon sayısı invariant'ını tek noktada kontrol etmek istiyorsanız.
- Tablo dışındaki veri motorlarında satırları rectangular biçimde tutmak
  istiyorsanız.

Temel API:

- `TableRow::from_vec(data, expected_length)`
- `TableRow::try_from_vec(data, expected_length)`
- `TableRow::from_element(element, length)`
- `.cols()`
- `.get(col)`, `.expect_get(col)`
- `.as_slice()`, `.into_vec()`
- `.map(...)`, `.map_ref(...)`, `.map_cloned(...)`

Davranış:

- `from_vec(...)`, uzunluk eşleşmezse panic oluşturur.
- `try_from_vec(...)`, uzunluk hatasını `Result::Err` olarak döndürür.
- `Table::header(...)`, `Table::row(...)`, `.uniform_list(...)` ve
  `.variable_row_height_list(...)` public API'de `Vec<T>` kabul eder; `TableRow`
  dönüşümü içeride yapılır.
- `IntoTableRow` trait'i `Vec<T>` için tek bir
  `.into_table_row(expected_length)` yöntemi sağlar; uzunluk eşleşmezse panic
  eder. Kaynakta `Table` bunu içeride kullandığı için normal kullanımda import
  gerekmez; düşük seviye helper'lara iniyorsanız
  `use ui::table_row::IntoTableRow as _;` ile çağırabilirsiniz. Doğrulanmış
  (`Result` döndüren) dönüşüm için doğrudan
  `TableRow::try_from_vec(data, expected_length)` kullanın; `try_into_table_row`
  trait yöntemi mevcut değildir.

Örnek:

```rust
use ui::{AnyElement, table_row::TableRow};

fn checked_cells(cells: Vec<AnyElement>, cols: usize) -> Option<TableRow<AnyElement>> {
    TableRow::try_from_vec(cells, cols).ok()
}
```

Dikkat edilecekler:

- Normal `Table` kullanımında `TableRow` üretmeniz gerekmez.
- `expect_get(...)`, veri motoru invariant'ı bozulduğunda erken hata vermek için
  uygundur; kullanıcı girdisiyle gelen satırlarda `get(...)` daha güvenlidir.

### Düşük Seviye Resize ve Render Helper'ları

Kaynak:

- `render_table_row`: `../zed/crates/ui/src/components/data_table.rs`
- `render_table_header`: `../zed/crates/ui/src/components/data_table.rs`
- `TableRenderContext`: `../zed/crates/ui/src/components/data_table.rs`
- `HeaderResizeInfo`: `../zed/crates/ui/src/components/redistributable_columns.rs`
- `bind_redistributable_columns`:
  `../zed/crates/ui/src/components/redistributable_columns.rs`
- `render_redistributable_columns_resize_handles`:
  `../zed/crates/ui/src/components/redistributable_columns.rs`

Ne zaman kullanılır:

- Tek `Table` yeterli değilse; örneğin header, graph alanı ve tablo gövdesi farklı
  container'larda ama aynı kolon state'iyle hizalanacaksa.
- Resize handle'larını tablo dışındaki sibling elementlerin üzerine bind etmek
  gerekiyorsa.
- Satır/header render'ını `Table` dışındaki özel bir layout içinde yeniden
  kullanmak istiyorsanız.

Ne zaman kullanılmaz:

- Normal veri tablosu için bu helper'lara inmeyin. `Table`, header, row,
  scroll ve resize binding'ini tek yerde yönetir.
- Sadece genişlik ayarlamak için `bind_redistributable_columns(...)` çağırmayın;
  `ColumnWidthConfig` yeterlidir.

Temel API:

- `TableRenderContext::for_column_widths(column_widths, use_ui_font)`
  - `column_widths`: `Option<TableRow<Length>>`. `None` verirse hücreler
    sabit genişlik almaz; redistributable/resizable bir state'ten geliyorsa
    `columns_state.read(cx).widths_to_render()` çağırın.
  - `use_ui_font`: `true` ise hücre içeriği `text_ui(cx)` ile çizilir; `false`
    ise font ailesi parent'tan miras alınır. `Table::no_ui_font()` ile kapatılan
    davranışın aynısıdır. CSV preview, monospace görünüm için `false` verir.
  - `striped`, `show_row_borders`, `show_row_hover`, `total_row_count`,
    `disable_base_cell_style`, `map_row` alanları `Default::default()`
    benzeri varsayılanlarla doldurulur; özel görünüm gerekiyorsa
    `for_column_widths(...)` çıktısını alan alan değiştirebilirsiniz.
- `render_table_header(headers, table_context, resize_info, entity_id, cx)`
- `render_table_row(row_index, items, table_context, window, cx)`
- `HeaderResizeInfo::from_redistributable(&columns_state, cx)`
- `HeaderResizeInfo::from_resizable(&columns_state, cx)`
  - `resize_behavior: TableRow<TableResizeBehavior>` public alanı header
    hücresinin resizable olup olmadığını okumak içindir. İlgili kolon state'i
    public alan değildir; reset ve state update için `reset_column(...)`
    çağırın.
- `bind_redistributable_columns(container, columns_state)`
- `render_redistributable_columns_resize_handles(&columns_state, window, cx)`

Örnek:

```rust
use gpui::Entity;
use ui::{
    HeaderResizeInfo, RedistributableColumnsState, TableRenderContext,
    bind_redistributable_columns, render_redistributable_columns_resize_handles,
    render_table_header, table_row::TableRow, prelude::*,
};

fn render_custom_table_header(
    columns: &Entity<RedistributableColumnsState>,
    window: &mut Window,
    cx: &mut App,
) -> impl IntoElement {
    let widths = columns.read(cx).widths_to_render();
    let context = TableRenderContext::for_column_widths(Some(widths), true);
    let resize_info = HeaderResizeInfo::from_redistributable(columns, cx);

    bind_redistributable_columns(
        div()
            .relative()
            .child(render_table_header(
                TableRow::from_vec(
                    vec![
                        Label::new("Graph").into_any_element(),
                        Label::new("Description").into_any_element(),
                        Label::new("Author").into_any_element(),
                    ],
                    3,
                ),
                context,
                Some(resize_info),
                Some(columns.entity_id()),
                cx,
            ))
            .child(render_redistributable_columns_resize_handles(columns, window, cx)),
        columns.clone(),
    )
}
```

Zed içinden kullanım:

- `../zed/crates/git_graph/src/git_graph.rs`: graph canvas ve commit tablosu aynı
  redistributable kolon state'iyle hizalanır; header ve resize handle'ları düşük
  seviye helper'larla kurulur.

Dikkat edilecekler:

- `bind_redistributable_columns(...)`, drag move sırasında preview width'i
  günceller ve drop sırasında commit eder.
- `render_redistributable_columns_resize_handles(...)`, kolon state'inden
  divider'ları üretir; container'ın `relative()` olması handle yerleşimini daha
  öngörülebilir yapar.
- `render_table_header(...)` içinde çift tıklama ile kolon reset davranışı
  `HeaderResizeInfo` üzerinden bağlanır.
- Header ve row için aynı `TableRenderContext` genişlik modeli kullanılmalıdır;
  aksi halde hücreler hizalanmaz.

### Veri Tablosu Kompozisyon Örnekleri

Boş durumlu küçük tablo:

```rust
use ui::{Table, prelude::*};

fn render_empty_jobs_table() -> impl IntoElement {
    Table::new(3)
        .width(px(560.))
        .header(vec!["Job", "Status", "Duration"])
        .empty_table_callback(|_, _| {
            v_flex()
                .p_3()
                .gap_1()
                .child(Label::new("No jobs").color(Color::Muted))
                .child(Label::new("Queued jobs will appear here").size(LabelSize::Small))
                .into_any_element()
        })
}
```

Satır seçimi için `map_row(...)`:

```rust
use ui::{Table, prelude::*};

fn render_selectable_rows(selected_index: Option<usize>) -> impl IntoElement {
    Table::new(2)
        .header(vec!["Name", "Role"])
        .row(vec!["Ada", "Admin"])
        .row(vec!["Linus", "Maintainer"])
        .map_row(move |(index, row), _window, cx| {
            row.when(selected_index == Some(index), |row| {
                row.bg(cx.theme().colors().element_selected)
            })
            .into_any_element()
        })
}
```

Karar rehberi:

- Az satır, basit görünüm: `Table::new(...).header(...).row(...)`.
- Çok satır, tek satır yüksekliği: `.uniform_list(...)`.
- Çok satır, multiline veya değişken içerik: `.variable_row_height_list(...)`.
- Container genişliği sabit, kolon oranları değişsin: `RedistributableColumnsState`.
- Kolonlar mutlak genişlikli, yatay scroll olabilir: `ResizableColumnsState`.
- Header/gövde/ek görsel bölgeler aynı kolon state'ini paylaşacak:
  düşük seviye render ve resize helper'ları.

## 10. Feedback ve Durum Göstergeleri

Feedback bileşenleri kullanıcıya uygulama durumunu anlatır: bilgi, başarı, uyarı,
hata, ilerleme, sayaç veya dikkat gerektiren karar. Bu gruptaki bileşenler aynı
tema token'larını kullanır ama farklı yoğunluklarda görünür:

- `Banner`: sayfa veya panel üstünde kısa, non-blocking mesaj.
- `Callout`: içerik akışı içinde daha açıklayıcı, karar veya aksiyon gerektiren
  mesaj.
- `Modal`: kendi modal içeriğinizi kurmak için shell.
- `AlertModal`: kısa karar akışı veya uyarı diyalogu.
- `AnnouncementToast`: yeni özellik veya duyuru kartı; lifecycle parent
  notification sistemi tarafından yönetilir.
- `CountBadge`, `Indicator`, `ProgressBar`, `CircularProgress`: küçük durum ve
  ilerleme göstergeleri.

### Severity

Kaynak:

- Tanım: `../zed/crates/ui/src/styles/severity.rs`
- Export: `ui::Severity`
- Prelude: `ui::prelude::*` içinde gelir.

Ne zaman kullanılır:

- Mesajın tonunu `Info`, `Success`, `Warning`, `Error` olarak tek enum üzerinden
  seçmek için.
- `Banner` ve `Callout` gibi bileşenlerde icon, background ve border rengini
  otomatik eşleştirmek için.

Davranış:

- `Banner` ve `Callout`, severity değerinden icon ve status renklerini türetir.
- `Info` nötr/muted, `Success` yeşil, `Warning` sarı, `Error` kırmızı status
  token'larını kullanır.
- Severity, kullanıcıya gösterilen metnin yerine geçmez. Mesaj kısa ve açık
  olmalıdır; aksiyon varsa ayrı button slot'u kullanın.

### Banner

Kaynak:

- Tanım: `../zed/crates/ui/src/components/banner.rs`
- Export: `ui::Banner`
- İlgili tipler: `ui::Severity`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Banner`

Ne zaman kullanılır:

- Sayfa veya panel içinde kısa bilgi, başarı, uyarı veya hata mesajı göstermek
  için.
- Kullanıcıyı akıştan koparmadan bir CTA veya düzeltme aksiyonu sunmak için.
- İçeriğin üstünde veya ilgili bölümün başında non-blocking mesaj göstermek için.

Ne zaman kullanılmaz:

- Uzun açıklama, bullet listesi veya ayrıntılı karar gerekiyorsa `Callout`.
- Kullanıcının devam etmeden karar vermesi gerekiyorsa `AlertModal`.
- Kısa süreli global bildirim lifecycle'ı gerekiyorsa app notification altyapısı
  ve uygun notification view kullanın.

Temel API:

- `Banner::new()`
- `.severity(Severity)`
- `.action_slot(element)`
- `.wrap_content(bool)`
- ParentElement: `.child(...)`, `.children(...)`

Davranış:

- Varsayılan severity `Severity::Info`.
- Severity'ye göre icon, background ve border rengi seçilir.
- `action_slot(...)` varsa banner sağ tarafta aksiyon alanı açar ve içerik
  padding'i ona göre değişir.
- `.wrap_content(true)`, dar alanlarda içeriğin satıra kırılmasına izin verir.

Örnek:

```rust
use ui::{Banner, Button, Icon, IconName, IconSize, Severity, prelude::*};

fn render_sync_banner() -> impl IntoElement {
    Banner::new()
        .severity(Severity::Info)
        .child(Label::new("Sync in progress"))
        .action_slot(
            Button::new("view-sync", "View")
                .end_icon(Icon::new(IconName::ArrowUpRight).size(IconSize::Small)),
        )
}
```

Çok satırlı içerik:

```rust
use ui::{Banner, Severity, prelude::*};

fn render_deprecation_banner() -> impl IntoElement {
    Banner::new()
        .severity(Severity::Warning)
        .wrap_content(true)
        .child(
            Label::new(
                "This setting is deprecated and will be ignored in a future release.",
            )
            .size(LabelSize::Small),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension upsell ve
  registry migration banner'ları.
- `../zed/crates/settings_ui/src/pages/tool_permissions_setup.rs`: ayar sayfası
  uyarıları.
- `../zed/crates/language_models/src/provider/opencode.rs`: provider durum
  mesajları.

Dikkat edilecekler:

- Banner kısa olmalıdır; birden fazla paragraf veya liste gerekiyorsa `Callout`.
- `action_slot(...)` içinde birden çok aksiyon gerekiyorsa `h_flex().gap_1()`
  ile açık spacing kurun.
- Banner'ı modal içi karar alanı gibi kullanmayın; modal kararları footer
  aksiyonlarıyla verilmelidir.

### Callout

Kaynak:

- Tanım: `../zed/crates/ui/src/components/callout.rs`
- Export: `ui::Callout`, `ui::BorderPosition`
- İlgili tipler: `ui::Severity`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Callout`

Ne zaman kullanılır:

- İçerik içinde kullanıcının okuması gereken açıklama, sınırlama veya karar
  mesajı göstermek için.
- Başlık, açıklama, aksiyon ve dismiss kontrolünü tek yüzeyde toplamak için.
- Markdown veya özel element gibi metin dışı açıklama içeriği gerekiyorsa
  `description_slot(...)` ile.

Ne zaman kullanılmaz:

- Sadece tek satırlık sayfa üstü mesaj için `Banner`.
- Global geçici bildirim için notification host.
- Bloklayıcı karar için `AlertModal`.

Temel API:

- `Callout::new()`
- `.severity(Severity)`
- `.icon(IconName)`
- `.title(text)`
- `.description(text)`
- `.description_slot(element)`
- `.actions_slot(element)`
- `.dismiss_action(element)`
- `.line_height(px)`
- `.border_position(BorderPosition::Top | BorderPosition::Bottom)`

Davranış:

- Varsayılan severity `Severity::Info`.
- `.icon(...)` çağrılmadığında icon alanı render edilmez; çağrıldığında icon rengi
  severity'den türetilir.
- `.description_slot(...)`, `.description(...)` ile aynı anda verilirse slot
  önceliklidir.
- Açıklama alanı `max_h_32()` ve `overflow_y_scroll()` kullanır; uzun içerikte
  callout yüksekliği kontrol altında kalır.
- Aksiyon ve dismiss slot'ları title satırının sağında render edilir.

Örnek:

```rust
use ui::{Button, Callout, IconButton, IconName, IconSize, Severity, prelude::*};

fn render_retry_callout() -> impl IntoElement {
    Callout::new()
        .severity(Severity::Warning)
        .icon(IconName::Warning)
        .title("Connection failed")
        .description("Retrying in 10 seconds. Check your network settings if this continues.")
        .actions_slot(Button::new("retry-now", "Retry now").label_size(LabelSize::Small))
        .dismiss_action(
            IconButton::new("dismiss-retry", IconName::Close).icon_size(IconSize::Small),
        )
}
```

Özel açıklama slot'u:

```rust
use ui::{Callout, IconName, Severity, prelude::*};

fn render_permission_callout() -> impl IntoElement {
    Callout::new()
        .severity(Severity::Error)
        .icon(IconName::XCircle)
        .title("Permission denied")
        .description_slot(
            v_flex()
                .gap_1()
                .child(Label::new("The selected command cannot run in this workspace."))
                .child(Label::new("Open workspace settings to allow it.").color(Color::Muted)),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: agent retry,
  token ve tool kullanımı uyarıları.
- `../zed/crates/zed/src/visual_test_runner.rs`: visual test durum mesajları.

Dikkat edilecekler:

- `Callout` içeriği flow içinde yer alır; viewport'u kaplayan bir overlay gibi
  davranmaz.
- Icon göstermek istiyorsanız `.icon(...)` açıkça çağrılmalıdır.
- Description slot'una scroll yapan karmaşık içerik koyarken içerideki metinlerin
  `min_w_0()` / `.truncate()` davranışını ayrıca düşünün.

### Modal

Kaynak:

- Tanım: `../zed/crates/ui/src/components/modal.rs`
- Export: `ui::Modal`, `ui::ModalHeader`, `ui::ModalRow`, `ui::ModalFooter`,
  `ui::Section`, `ui::SectionHeader`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Modal içeriğini Zed'in header, section ve footer düzeniyle kurmak için.
- Çok bölümlü ayar, form veya seçim akışı oluşturmak için.
- Scroll handle'ı dışarıdan yönetilen modal body gerektiğinde.

Ne zaman kullanılmaz:

- Kısa uyarı ve iki aksiyonlu karar için `AlertModal` daha az kodla doğru
  davranışı verir.
- Modal dışı panel veya sayfa düzeni için `v_flex()` / `Section` dışı layout daha
  uygundur.

Temel API:

- `Modal::new(id, scroll_handle)`
- `.header(ModalHeader)`
- `.section(Section)`
- `.footer(ModalFooter)`
- `.show_dismiss(bool)`
- `.show_back(bool)`
- ParentElement: `.child(...)`, `.children(...)`
- `ModalHeader::new().headline(...).description(...).icon(...).show_dismiss_button(...).show_back_button(...)`
- `ModalFooter::new().start_slot(...).end_slot(...)`
- `Section::new()`, `Section::new_contained()`, `.contained(bool)`,
  `.header(...)`, `.meta(...)`, `.padded(bool)`
- `SectionHeader::new(label).end_slot(...)`
- `ModalRow::new()`

Davranış:

- Modal root `size_full()`, `flex_1()` ve `overflow_hidden()` kullanır; modal
  container'ı genellikle parent overlay tarafından sağlanır.
- `scroll_handle` verilirse body `overflow_y_scroll()` ve `track_scroll(...)`
  ile bağlanır.
- `show_dismiss(true)` ve `show_back(true)`, header'da Zed'in `menu::Cancel`
  aksiyonunu dispatch eden icon button'lar üretir.
- `Section::new_contained()` border'lı iç yüzey üretir; normal `Section` daha
  düz bir akış verir.

Örnek:

```rust
use ui::{
    Button, Modal, ModalFooter, ModalHeader, ModalRow, Section, SectionHeader, prelude::*,
};

fn render_project_settings_modal() -> impl IntoElement {
    Modal::new("project-settings-modal", None)
        .show_dismiss(true)
        .header(
            ModalHeader::new()
                .headline("Project Settings")
                .description("Changes apply to the current workspace."),
        )
        .section(
            Section::new()
                .header(SectionHeader::new("Behavior"))
                .child(
                    ModalRow::new()
                        .child(Label::new("Format on save").flex_1())
                        .child(Label::new("Enabled").color(Color::Muted)),
                ),
        )
        .footer(ModalFooter::new().end_slot(Button::new("save-settings", "Save")))
}
```

Modal lifecycle ve workspace entegrasyonu:

Zed UI `Modal` bileşeni yalnızca içerik shell'idir; modal'ın açılıp
kapanmasını yöneten asıl katman `workspace::ModalLayer` ve
`workspace::ModalView` trait'idir.

```rust
use gpui::{Entity, ManagedView};
use ui::{Modal, ModalFooter, ModalHeader, Section, prelude::*};
use workspace::{ModalView, Workspace};

struct ProjectSettingsModal {
    focus_handle: gpui::FocusHandle,
}

impl gpui::EventEmitter<gpui::DismissEvent> for ProjectSettingsModal {}

impl gpui::Focusable for ProjectSettingsModal {
    fn focus_handle(&self, _cx: &App) -> gpui::FocusHandle {
        self.focus_handle.clone()
    }
}

impl ManagedView for ProjectSettingsModal {}
impl ModalView for ProjectSettingsModal {}

impl Render for ProjectSettingsModal {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        Modal::new("project-settings-modal", None)
            .header(ModalHeader::new().headline("Project Settings"))
            .section(Section::new().child(Label::new("…")))
            .footer(ModalFooter::new().end_slot(Button::new("close", "Close")))
    }
}

fn open_project_settings(
    workspace: &mut Workspace,
    window: &mut Window,
    cx: &mut Context<Workspace>,
) {
    workspace.toggle_modal::<ProjectSettingsModal, _>(window, cx, |_window, cx| {
        ProjectSettingsModal {
            focus_handle: cx.focus_handle(),
        }
    });
}
```

`ModalView` trait sözleşmesi:

- `ManagedView`: yani `Render + Focusable + EventEmitter<DismissEvent>`.
- `on_before_dismiss(window, cx) -> DismissDecision`: kapanmadan önce
  validation veya kullanıcı onayı istenebilir. `DismissDecision::Pending`
  kapanmayı erteler, `DismissDecision::Dismiss(false)` iptal eder.
- `fade_out_background(&self) -> bool`: ekrandaki diğer içeriği soluklaştırmak
  için override edilebilir.
- `render_bare(&self) -> bool`: workspace `ModalLayer`'ın varsayılan elevation
  yüzeyini bypass etmek için.

`Workspace::toggle_modal::<V, _>(window, cx, build_fn)`, aynı modal türü zaten
açıksa kapatır, farklı bir modal açıksa onu kapatıp yenisini açar. `ModalLayer`,
dismiss event'ini dinler ve focus'u önceki elemana geri verir.

Dikkat edilecekler:

- `Modal` yalnızca içerik shell'idir; açma/kapama lifecycle'ı modal host veya
  parent view tarafından yönetilir.
- Header dismiss/back button'ları `menu::Cancel` dispatch eder; parent context bu
  aksiyonu ele almalıdır.
- Section içinde çok sayıda ayar satırı varsa body scroll handle'ı verin.
- Modal'ı bir AlertModal yerine kullanıyorsanız bile yine workspace üzerinden
  `toggle_modal` ile sunun; ayrı bir overlay altyapısı kurmaya gerek yoktur.

### AlertModal

Kaynak:

- Tanım: `../zed/crates/ui/src/components/notification/alert_modal.rs`
- Export: `ui::AlertModal`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for AlertModal`

Ne zaman kullanılır:

- Kullanıcıdan kısa bir onay veya iptal kararı almak için.
- Güvenlik, silme, workspace trust gibi devam etmeden önce anlaşılması gereken
  uyarılar için.
- Özel header veya footer gerekse de temel modal iskeletini hızlı kurmak için.

Ne zaman kullanılmaz:

- Non-blocking bilgi mesajı için `Banner` veya `Callout`.
- Çok bölümlü ayar formu için `Modal`.
- Yeni özellik duyurusu için `AnnouncementToast`.

Temel API:

- `AlertModal::new(id)`
- `.title(text)`
- `.header(element)`
- `.footer(element)`
- `.primary_action(label)`
- `.dismiss_label(label)`
- `.width(width)`
- `.key_context(context)`
- `.on_action::<A>(listener)`
- `.track_focus(&focus_handle)`
- ParentElement: `.child(...)`, `.children(...)`

Davranış:

- Varsayılan genişlik `px(440.)`.
- `.title(...)` verilirse küçük `Headline` içeren default header üretir.
- `.primary_action(...)` veya `.dismiss_label(...)` verilirse default footer
  üretilir. Label verilmezse primary `"Ok"`, dismiss `"Cancel"` olur.
- Default footer button'ları görünümü kurar; karar akışını Zed action sistemiyle
  `.on_action(...)` veya parent lifecycle üzerinden bağlayın.
- `.header(...)` ve `.footer(...)`, default header/footer yerine tamamen özel
  element render eder.

Örnek:

```rust
use ui::{AlertModal, prelude::*};

fn render_delete_alert() -> impl IntoElement {
    AlertModal::new("delete-project-alert")
        .title("Delete project?")
        .child("This removes the project from the recent projects list.")
        .primary_action("Delete")
        .dismiss_label("Cancel")
}
```

Özel header:

```rust
use ui::{AlertModal, Icon, IconName, prelude::*};

fn render_restricted_workspace_alert(cx: &App) -> impl IntoElement {
    AlertModal::new("restricted-workspace-alert")
        .width(rems(40.))
        .header(
            v_flex()
                .p_3()
                .gap_1()
                .bg(cx.theme().colors().editor_background.opacity(0.5))
                .border_b_1()
                .border_color(cx.theme().colors().border_variant)
                .child(
                    h_flex()
                        .gap_2()
                        .child(Icon::new(IconName::Warning).color(Color::Warning))
                        .child(Label::new("Unrecognized Workspace")),
                ),
        )
        .child("Restricted mode prevents workspace commands from running automatically.")
        .primary_action("Trust Workspace")
        .dismiss_label("Stay Restricted")
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/security_modal.rs`: restricted workspace karar
  akışı; `key_context`, `track_focus` ve `.on_action(...)` birlikte kullanılır.
- `../zed/crates/ui/src/components/notification/alert_modal.rs`: basic ve custom
  header preview örnekleri.

Dikkat edilecekler:

- Kısa ve karar odaklı tutun. Birden fazla section gerekiyorsa `Modal` kullanın.
- Tehlikeli aksiyonlarda primary label net olmalıdır; `"Ok"` yerine `"Delete"`,
  `"Trust Workspace"` gibi eylemi yazın.
- Focus ve keyboard action davranışı gerekiyorsa `key_context(...)` ve
  `track_focus(...)` bağlamadan sadece görsel modal üretmeyin.

### AnnouncementToast

Kaynak:

- Tanım: `../zed/crates/ui/src/components/notification/announcement_toast.rs`
- Export: `ui::AnnouncementToast`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for AnnouncementToast`

Ne zaman kullanılır:

- Yeni özellik, önemli değişiklik veya üründeki görünür duyuruları kart biçiminde
  göstermek için.
- İllüstrasyon, başlık, açıklama, bullet listesi ve iki aksiyonlu duyuru
  gerekiyorsa.

Ne zaman kullanılmaz:

- Hata, retry veya inline durum mesajı için `Banner` / `Callout`.
- Basit toast ihtiyacı için parent notification sisteminin daha küçük view'ını
  kullanın.
- Kullanıcının devam etmeden karar vermesi gerekiyorsa `AlertModal`.

Temel API:

- `AnnouncementToast::new()`
- `.illustration(element)`
- `.heading(text)`
- `.description(text)`
- `.bullet_item(element)`
- `.bullet_items(items)`
- `.primary_action_label(text)`
- `.primary_on_click(handler)`
- `.secondary_action_label(text)`
- `.secondary_on_click(handler)`
- `.dismiss_on_click(handler)`

Davranış:

- Varsayılan primary label `"Try Now"`, secondary label `"Learn More"`.
- Click handler'ları boş default closure ile gelir; gerçek davranış için parent
  view dismiss veya navigation callback'i bağlamalıdır.
- Root element `occlude()`, `relative()`, `w_full()` ve `elevation_3(cx)` kullanır.
- Sağ üstte close icon button render edilir; dismiss lifecycle'ı
  `.dismiss_on_click(...)` callback'ine bırakılır.

Örnek:

```rust
use ui::{AnnouncementToast, ListBulletItem, prelude::*};

fn render_feature_announcement() -> impl IntoElement {
    div().w_80().child(
        AnnouncementToast::new()
            .heading("Parallel agents")
            .description("Run multiple agent threads across projects.")
            .bullet_item(ListBulletItem::new("Launch agents in isolated worktrees"))
            .bullet_item(ListBulletItem::new("Review progress without changing tabs"))
            .primary_action_label("Try Now")
            .primary_on_click(|_, _window, cx| cx.open_url("https://zed.dev"))
            .secondary_action_label("Learn More")
            .secondary_on_click(|_, _window, cx| cx.open_url("https://zed.dev/docs"))
            .dismiss_on_click(|_, _window, _cx| {}),
    )
}
```

Zed içinden kullanım:

- `../zed/crates/auto_update_ui/src/auto_update_ui.rs`: announcement toast
  notification view'ı; click handler'lar telemetry, URL ve dismiss callback'leri
  ile bağlanır.

Dikkat edilecekler:

- `AnnouncementToast` tek başına notification lifecycle'ı yönetmez. Dismiss,
  suppress veya route davranışı parent notification view içinde uygulanmalıdır.
- Bullet sayısını sınırlı tutun; çok uzun duyuru kartı kullanıcıyı akıştan koparır.
- İllüstrasyon eklenirse toast'ın üstünde render edilir ve body'den border ile
  ayrılır.

### Notification Modülü

Kaynak:

- Modül: `../zed/crates/ui/src/components/notification.rs`
- Export: `ui::AlertModal`, `ui::AnnouncementToast`
- Prelude: Hayır.

Mevcut `ui` kaynağında standalone `Notification` component'i yoktur.
`notification.rs`, yalnızca `alert_modal` ve `announcement_toast` modüllerini
re-export eder. Runtime bildirim kuyruğu, dismiss/suppress event'leri ve
notification trait'leri Zed'in daha üst seviye notification altyapısında tutulur.

Pratik sonuç:

- UI component olarak `AlertModal` veya `AnnouncementToast` render edin.
- Gösterme, saklama, kapatma ve tekrar göstermeme kararını parent notification
  view'ında yönetin.
- Toast içindeki click handler'larda gerekirse telemetry, URL açma ve dismiss
  akışını birlikte bağlayın.

### CountBadge

Kaynak:

- Tanım: `../zed/crates/ui/src/components/count_badge.rs`
- Export: `ui::CountBadge`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for CountBadge`

Ne zaman kullanılır:

- Icon, tab veya compact toolbar item üzerinde küçük sayaç göstermek için.
- Bildirim, hata, değişiklik veya bekleyen öğe sayısını küçük alanda belirtmek
  için.

Ne zaman kullanılmaz:

- Sayısal değer ana içerikse `Label` veya tablo hücresi kullanın.
- Durum sadece var/yok ise `Indicator::dot()` daha sade olabilir.

Temel API:

- `CountBadge::new(count)`

Davranış:

- `count > 99` için `"99+"` gösterir.
- `absolute()`, `top_0()`, `right_0()` ile parent'ın sağ üstüne yerleşir.
- Parent element `relative()` değilse badge beklenen anchor'a oturmaz.
- Background, editor background ile error status renginin blend edilmesiyle
  hesaplanır.

Örnek:

```rust
use ui::{CountBadge, IconButton, IconName, prelude::*};

fn render_notifications_button(count: usize) -> impl IntoElement {
    div()
        .relative()
        .child(IconButton::new("notifications", IconName::Bell))
        .when(count > 0, |this| this.child(CountBadge::new(count)))
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/dock.rs`: dock item üzerinde count badge.
- `../zed/crates/ui/src/components/count_badge.rs`: capped count preview.

Dikkat edilecekler:

- Parent'ın hitbox'ı ve badge'in absolute konumu birlikte düşünülmelidir; çok
  küçük icon button'larda badge tıklanabilir alanı görsel olarak kalabalıklaştırır.
- Badge metni otomatik capped olduğu için gerçek tam sayıyı tooltip veya detay
  view'da göstermek gerekebilir.

### Indicator

Kaynak:

- Tanım: `../zed/crates/ui/src/components/indicator.rs`
- Export: `ui::Indicator`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Indicator`

Ne zaman kullanılır:

- Küçük durum noktası, üst bar veya icon tabanlı durum göstergesi gerektiğinde.
- Liste satırında connection, breakpoint, conflict, active/inactive gibi hızlı
  taranabilir durumlar için.
- Icon button veya list item yanında dikkat çekmeyen status işareti için.

Ne zaman kullanılmaz:

- İşlem ilerlemesi için `ProgressBar` veya `CircularProgress`.
- Metinsel açıklama gerekiyorsa yanında `Label` kullanın; indicator tek başına
  erişilebilir anlam taşımaz.

Temel API:

- `Indicator::dot()`
- `Indicator::bar()`
- `Indicator::icon(icon)`
- `.color(Color)`
- `.border_color(Color)`

Davranış:

- Dot: `w_1p5()`, `h_1p5()`, `rounded_full()`.
- Bar: `w_full()`, `h_1p5()`, `rounded_t_sm()`; parent genişliği önemlidir.
- Icon indicator, icon'u `custom_size(rems_from_px(8.))` ile küçük render eder.
- `border_color(...)`, sadece dot ve bar için border uygular.

Örnek:

```rust
use ui::{Indicator, prelude::*};

fn render_connection_state(connected: bool) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            Indicator::dot().color(if connected {
                Color::Success
            } else {
                Color::Error
            }),
        )
        .child(Label::new(if connected { "Connected" } else { "Disconnected" }))
}
```

Zed içinden kullanım:

- `../zed/crates/workspace/src/status_bar.rs`: status bar indicator.
- `../zed/crates/debugger_ui/src/dropdown_menus.rs`: debug session state.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: conflict indicator.
- `../zed/crates/title_bar/src/title_bar.rs`: title bar durum noktaları.

Dikkat edilecekler:

- Rengi `Color::Success`, `Warning`, `Error`, `Info`, `Muted` gibi semantic
  token'lardan seçin.
- Indicator'ı tek bilgi kaynağı yapmayın; özellikle error/warning durumlarında
  tooltip veya label ile anlamı belirtin.

### ProgressBar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/progress/progress_bar.rs`
- Export: `ui::ProgressBar`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for ProgressBar`

Ne zaman kullanılır:

- İşlemin belirli bir `value / max_value` oranı varsa.
- Yatay alanda dosya indirme, kullanım limiti, sync veya task progress göstermek
  için.

Ne zaman kullanılmaz:

- İlerleme oranı bilinmiyorsa `LoadingLabel` veya `SpinnerLabel` kullanın.
- Çok dar inline alanda ring görünümü daha uygunsa `CircularProgress`.

Temel API:

- `ProgressBar::new(id, value, max_value, cx)`
- `.value(value)`
- `.max_value(max_value)`
- `.bg_color(hsla)`
- `.fg_color(hsla)`
- `.over_color(hsla)`

Davranış:

- Fill genişliği `(value / max_value).clamp(0.02, 1.0)` ile hesaplanır.
- `value > max_value` durumunda fill rengi `over_color` olur.
- Varsayılan foreground renk `cx.theme().status().info`.
- `max_value` pozitif olmalıdır; sıfır veya anlamsız max değer üretmeyin.

Örnek:

```rust
use ui::{ProgressBar, prelude::*};

fn render_usage_progress(used: f32, limit: f32, cx: &App) -> impl IntoElement {
    v_flex()
        .gap_1()
        .child(
            h_flex()
                .justify_between()
                .child(Label::new("Usage"))
                .child(Label::new(format!("{used:.0} / {limit:.0}")).color(Color::Muted)),
        )
        .child(ProgressBar::new("usage-progress", used, limit, cx))
}
```

Zed içinden kullanım:

- `../zed/crates/edit_prediction_ui/src/edit_prediction_button.rs`: kullanım
  limiti progress bar'ı.
- `../zed/crates/ui/src/components/progress/progress_bar.rs`: empty, partial ve
  filled preview örnekleri.

Dikkat edilecekler:

- `value` ve `max_value` aynı birimde olmalıdır.
- Progress bar'a yalnızca renk yüklemeyin; yakınında label veya tooltip ile
  bağlam verin.
- `value > max_value` bilinçli over-limit durumudur; normal tamamlandı state'i
  için `value == max_value` kullanın.

### CircularProgress

Kaynak:

- Tanım: `../zed/crates/ui/src/components/progress/circular_progress.rs`
- Export: `ui::CircularProgress`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for CircularProgress`

Ne zaman kullanılır:

- Dar veya inline alanda belirli ilerleme oranını ring olarak göstermek için.
- Token kullanımı, compact quota veya küçük status cluster'larında.

Ne zaman kullanılmaz:

- Geniş yatay alanda metinle birlikte ilerleme göstermek için `ProgressBar`
  daha okunaklıdır.
- İlerleme oranı bilinmiyorsa spinner/loading bileşeni kullanın.

Temel API:

- `CircularProgress::new(value, max_value, size, cx)`
- `.value(value)`
- `.max_value(max_value)`
- `.size(px)`
- `.stroke_width(px)`
- `.bg_color(hsla)`
- `.progress_color(hsla)`

Davranış:

- Canvas üzerinde background circle ve progress arc çizer.
- Progress üstten başlar ve saat yönünde ilerler.
- Progress oranı `(value / max_value).clamp(0.0, 1.0)` ile hesaplanır.
- `progress >= 0.999` durumunda tam çember çizilir.
- Varsayılan stroke width `px(4.)`.

Örnek:

```rust
use ui::{CircularProgress, prelude::*};

fn render_token_ring(used: f32, max: f32, cx: &App) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            CircularProgress::new(used, max, px(18.), cx)
                .stroke_width(px(2.))
                .progress_color(cx.theme().status().info),
        )
        .child(Label::new(format!("{used:.0}/{max:.0}")).size(LabelSize::Small))
}
```

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: token usage
  ring'leri.
- `../zed/crates/ui/src/components/progress/circular_progress.rs`: farklı yüzde
  preview örnekleri.

Dikkat edilecekler:

- Ring küçük olduğunda label veya tooltip olmadan oranı okumak zordur.
- `max_value` pozitif olmalıdır.
- Aynı ekranda çok sayıda animated veya sık güncellenen canvas progress
  kullanıyorsanız repaint maliyetini düşünün.

### Feedback Kompozisyon Örnekleri

Sync durumu:

```rust
use ui::{Banner, ProgressBar, Severity, prelude::*};

fn render_sync_feedback(progress: f32, cx: &App) -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(
            Banner::new()
                .severity(Severity::Info)
                .child(Label::new("Sync in progress"))
                .child(Label::new("Remote changes are being applied.").color(Color::Muted)),
        )
        .child(ProgressBar::new("sync-progress", progress, 1.0, cx))
}
```

Toolbar sayaç ve durum:

```rust
use ui::{CountBadge, IconButton, IconName, Indicator, prelude::*};

fn render_review_toolbar_item(issue_count: usize, has_errors: bool) -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(
            div()
                .relative()
                .child(IconButton::new("review", IconName::Check))
                .when(issue_count > 0, |this| this.child(CountBadge::new(issue_count))),
        )
        .child(
            Indicator::dot().color(if has_errors {
                Color::Error
            } else {
                Color::Success
            }),
        )
}
```

Karar rehberi:

- Kısa, non-blocking, sayfa/panel üstü mesaj: `Banner`.
- İçerik içinde açıklama + aksiyon + dismiss: `Callout`.
- Çok bölümlü modal içerik: `Modal`.
- Kısa karar veya uyarı diyalogu: `AlertModal`.
- Yeni özellik duyurusu: `AnnouncementToast` + notification lifecycle.
- Sayı bindirme: `CountBadge`.
- Var/yok veya state noktası: `Indicator`.
- Belirli yatay ilerleme: `ProgressBar`.
- Belirli compact ilerleme: `CircularProgress`.

## 11. Diğer Bileşenler ve AI/Collab Özel Alanı

Bu gruptaki bileşenler ikiye ayrılır. `Avatar`, `Facepile`, `Chip`, `DiffStat`,
`Disclosure`, `GradientFade`, `Vector`, `KeyBinding`, `KeybindingHint` ve
`Navigable` genel UI yapı taşlarıdır. `AiSettingItem`, `AgentSetupButton`,
`ThreadItem`, `ConfiguredApiCard`, `CollabNotification` ve `UpdateButton` ise
Zed'in AI, agent, collaboration ve update akışlarına daha sıkı bağlıdır.

Genel kural:

- Domain'e bağlı bileşenlerde gerçek servis state'ini component içine taşımayın;
  component'e yalnızca render için gereken label, status, icon, callback ve
  metadata'yı verin.
- `ui::KeyBinding` ile `gpui::KeyBinding` isimleri farklıdır. UI bileşeni
  shortcut'ı render eder; GPUI tipi keymap'e binding tanımlar.
- `Image` adında public Zed UI component'i yoktur. Bundled SVG için `Vector`,
  raster veya dış görsel için GPUI `img(...)` / `ImageSource` kullanılır.

### Avatar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/avatar.rs`
- Export: `ui::Avatar`, `ui::AvatarAudioStatusIndicator`,
  `ui::AvatarAvailabilityIndicator`, `ui::AudioStatus`,
  `ui::CollaboratorAvailability`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Avatar`

Ne zaman kullanılır:

- Kullanıcı, collaborator, participant veya commit author görseli göstermek için.
- Avatar üstünde microphone veya availability göstergesi gerekiyorsa.
- Facepile içinde küçük, border'lı ve overlap eden avatarlar için.

Ne zaman kullanılmaz:

- Genel icon veya logo için `Icon` / `Vector`.
- Avatar kaynağı yoksa sadece harf badge'i gerekiyorsa özel `div()` + `Label`
  daha açık olabilir.

Temel API:

- `Avatar::new(src: impl Into<ImageSource>)`
- `.grayscale(bool)`
- `.border_color(color)`
- `.size(size)`
- `.indicator(element)`
- `AvatarAudioStatusIndicator::new(AudioStatus::Muted | AudioStatus::Deafened)`
- `AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free | Busy)`

Davranış:

- Varsayılan avatar boyutu `1rem`.
- Görsel yüklenemezse `IconName::Person` ile fallback render eder.
- `border_color(...)`, avatar çevresinde `1px` border açar ve facepile overlap
  görünümünde görsel boşluk yaratmak için kullanılır.
- Indicator, avatar container'ının child'ı olarak render edilir; indicator
  pozisyonu kendi elementinde absolute ayarlanır.

Örnek:

```rust
use ui::{
    Avatar, AvatarAvailabilityIndicator, CollaboratorAvailability, prelude::*,
};

fn render_reviewer_avatar() -> impl IntoElement {
    Avatar::new("https://avatars.githubusercontent.com/u/1714999?v=4")
        .size(px(28.))
        .border_color(gpui::transparent_black())
        .indicator(
            AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free)
                .avatar_size(px(28.)),
        )
}
```

Ses durumu:

```rust
use ui::{AudioStatus, Avatar, AvatarAudioStatusIndicator, prelude::*};

fn render_muted_participant(avatar_url: SharedString) -> impl IntoElement {
    Avatar::new(avatar_url)
        .size(px(32.))
        .indicator(AvatarAudioStatusIndicator::new(AudioStatus::Muted))
}
```

Zed içinden kullanım:

- `../zed/crates/collab_ui/src/collab_panel.rs`: contact ve participant
  satırları.
- `../zed/crates/title_bar/src/collab.rs`: title bar collaborator avatarları.
- `../zed/crates/editor/src/git.rs`: author avatarları.

Dikkat edilecekler:

- `.size(...)` için `px(...)` veya `rems(...)` kullanabilirsiniz; facepile'da aynı
  boyutu korumak daha temiz görünür.
- Audio status tooltip'i gerekiyorsa `AvatarAudioStatusIndicator::tooltip(...)`
  ile bağlayın.
- Availability indicator için `.avatar_size(...)` gerçek avatar boyutuyla aynı
  verilirse nokta oranı daha doğru olur.

### Facepile

Kaynak:

- Tanım: `../zed/crates/ui/src/components/facepile.rs`
- Export: `ui::Facepile`, `ui::EXAMPLE_FACES`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Facepile`

Ne zaman kullanılır:

- Aktif collaborator, reviewer veya participant grubunu kompakt göstermek için.
- Yüzleri soldan sağa overlap ederek küçük alanda birden çok kişiyi göstermek
  için.

Ne zaman kullanılmaz:

- Tek kullanıcı için `Avatar`.
- Sıralı, detaylı kullanıcı listesi için `ListItem` + `Avatar`.

Temel API:

- `Facepile::empty()`
- `Facepile::new(faces: SmallVec<[AnyElement; 2]>)`
- ParentElement: `.child(...)`, `.children(...)`
- Padding style yöntemleri desteklenir.

Davranış:

- Render sırasında `flex_row_reverse()` kullanır; sol yüz en üstte kalacak şekilde
  görsel overlap sağlar.
- İkinci ve sonraki yüzler `ml_neg_1()` ile bindirilir.
- `Facepile` overflow sayacı üretmez; daha fazla kişi varsa ayrıca `Chip` veya
  `CountBadge` benzeri bir eleman ekleyin.

Örnek:

```rust
use ui::{Avatar, Facepile, prelude::*};

fn render_reviewers() -> impl IntoElement {
    Facepile::empty()
        .child(Avatar::new("https://avatars.githubusercontent.com/u/326587?s=60").size(px(24.)))
        .child(Avatar::new("https://avatars.githubusercontent.com/u/2280405?s=60").size(px(24.)))
        .child(Avatar::new("https://avatars.githubusercontent.com/u/1789?s=60").size(px(24.)))
}
```

Zed içinden kullanım:

- `../zed/crates/collab_ui/src/collab_panel.rs`: channel ve participant
  özetlerinde.
- `../zed/crates/ui/src/components/facepile.rs`: default ve custom size preview.

Dikkat edilecekler:

- Overlap görünümü için avatar border rengini parent background ile eşleştirmek
  iyi sonuç verir.
- Çok fazla avatar eklemek yerine ilk birkaç kişiyi gösterip kalan sayıyı ayrı
  belirtin.

### Chip

Kaynak:

- Tanım: `../zed/crates/ui/src/components/chip.rs`
- Export: `ui::Chip`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Chip`

Ne zaman kullanılır:

- Filtre, plan adı, provider tipi, branch adı, metadata veya küçük status label'ı
  göstermek için.
- Icon + kısa label kombinasyonunu düşük vurgu ile göstermek için.

Ne zaman kullanılmaz:

- Etkileşimli menü butonu için `Button` / `DropdownMenu`.
- Uzun açıklama veya paragraf için `Label`.

Temel API:

- `Chip::new(label)`
- `.label_color(Color)`
- `.label_size(LabelSize)`
- `.icon(IconName)`
- `.icon_color(Color)`
- `.bg_color(Hsla)`
- `.border_color(Hsla)`
- `.height(Pixels)`
- `.truncate()`
- `.tooltip(...)`

Davranış:

- Varsayılan label size `LabelSize::XSmall`.
- Label buffer font ile render edilir.
- `.truncate()` parent içinde shrink etmeye izin verir; uzun chip metinlerinde
  kullanın.
- Tooltip closure `AnyView` döndürür.

Örnek:

```rust
use ui::{Chip, IconName, prelude::*};

fn render_branch_chip(branch: SharedString) -> impl IntoElement {
    Chip::new(branch)
        .icon(IconName::GitBranch)
        .icon_color(Color::Muted)
        .label_color(Color::Muted)
        .truncate()
}
```

Zed içinden kullanım:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension capability
  etiketleri.
- `../zed/crates/agent_ui/src/ui/model_selector_components.rs`: model metadata
  ve cost bilgisi.
- `../zed/crates/title_bar/src/plan_chip.rs`: plan adı gösterimi.

Dikkat edilecekler:

- Chip küçük bir bilgi kapsülüdür; primary action gibi kullanılmamalıdır.
- Custom background kullanıyorsanız border rengini de uyumlu seçin.
- Dar toolbar içinde `.truncate()` olmadan uzun label layout'u bozabilir.

### DiffStat

Kaynak:

- Tanım: `../zed/crates/ui/src/components/diff_stat.rs`
- Export: `ui::DiffStat`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for DiffStat`

Ne zaman kullanılır:

- Eklenen ve silinen satır sayılarını compact göstermek için.
- Commit, branch, thread veya file diff metadata'sı yanında.

Ne zaman kullanılmaz:

- Ayrıntılı file diff görünümü için.
- Sadece toplam değişiklik sayısı gerekiyorsa `Label` veya `CountBadge`.

Temel API:

- `DiffStat::new(id, added, removed)`
- `.label_size(LabelSize)`
- `.tooltip(text)`

Davranış:

- Added değeri `Color::Success`, removed değeri `Color::Error` ile render edilir.
- Removed label'ı typographic minus kullanır.
- Tooltip verilirse `Tooltip::text(...)` bağlanır.

Örnek:

```rust
use ui::{DiffStat, prelude::*};

fn render_file_change_summary() -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(Label::new("src/main.rs").truncate())
        .child(DiffStat::new("main-rs-diff", 12, 3).tooltip("12 additions, 3 deletions"))
}
```

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: tool result ve
  thread değişiklik özetleri.
- `../zed/crates/git_ui/src/project_diff.rs`: project diff metadata'sı.
- `../zed/crates/git_graph/src/git_graph.rs`: commit metadata.

Dikkat edilecekler:

- `id` stabil olmalıdır; aynı listede tekrar eden id kullanmayın.
- Sıfır değerlerin gösterilip gösterilmeyeceğine parent karar vermelidir.

### Disclosure

Kaynak:

- Tanım: `../zed/crates/ui/src/components/disclosure.rs`
- Export: `ui::Disclosure`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Disclosure`

Ne zaman kullanılır:

- Açılır/kapanır bölüm, tree satırı veya detay satırı için chevron button
  gerektiğinde.
- Parent state'in açılma durumunu kontrol ettiği controlled toggle için.

Ne zaman kullanılmaz:

- Tam satır tree davranışı için `TreeViewItem` daha fazla hazır davranış sağlar.
- Sadece görsel chevron gerekiyorsa `Icon` yeterlidir.

Temel API:

- `Disclosure::new(id, is_open)`
- `.on_toggle_expanded(handler)`
- `.opened_icon(IconName)`
- `.closed_icon(IconName)`
- `.disabled(bool)`
- `Clickable`: `.on_click(...)`, `.cursor_style(...)`
- `Toggleable`: `.toggle_state(selected)`
- `VisibleOnHover`: `.visible_on_hover(group_name)`

Davranış:

- Açıkken default icon `ChevronDown`, kapalıyken `ChevronRight`.
- Render sonucu `IconButton` üzerinden gelir.
- `is_open` internal state değildir; parent her render'da güncel değeri verir.
- **`Clickable::on_click` ve `on_toggle_expanded` aynı slotu yazar.** Kaynak
  implementasyon `on_click`'i `self.on_toggle_expanded = Some(Arc::new(handler))`
  olarak depolar; bu yüzden ikisi birlikte çağrılırsa **sonuncu** kazanır.
  Karışıklık önlemek için yalnızca birini kullanın.

Örnek:

```rust
use ui::{Disclosure, prelude::*};

fn render_collapsible_header(is_open: bool) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            Disclosure::new("advanced-toggle", is_open)
                .on_click(|_, _window, cx| cx.stop_propagation()),
        )
        .child(Label::new("Advanced"))
}
```

Zed içinden kullanım:

- `../zed/crates/ui/src/components/tree_view_item.rs`: tree item expansion.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: plan, queue ve
  edit detay açılımları.
- `../zed/crates/repl/src/outputs/json.rs`: JSON node expansion.

Dikkat edilecekler:

- Toggle state'i parent'ta tutulmalı ve click handler parent state'i
  güncellemelidir.
- `visible_on_hover(...)` kullanıyorsanız parent aynı group name'i tanımlamalıdır.

### GradientFade

Kaynak:

- Tanım: `../zed/crates/ui/src/components/gradient_fade.rs`
- Export: `ui::GradientFade`
- Prelude: Hayır, ayrıca import edin.
- Preview: Hayır.

Ne zaman kullanılır:

- Sağ kenarda taşan içerik veya hover action alanı üstünde yumuşak fade overlay
  gerektiğinde.
- Sidebar item gibi tek satırda metadata/action geçişini maskelemek için.

Ne zaman kullanılmaz:

- Genel background dekorasyonu için.
- Scrollbar veya gerçek clipping yerine geçecek şekilde.

Temel API:

- `GradientFade::new(base_bg, hover_bg, active_bg)`
- `.width(Pixels)`
- `.right(Pixels)`
- `.gradient_stop(f32)`
- `.group_name(name)`

Davranış:

- Absolute positioned, `top_0()`, `h_full()` ve sağ kenara bağlıdır.
- Renkleri app background ile blend ederek opaklaştırmaya çalışır.
- `group_name(...)` verilirse parent hover/active durumunda gradient rengi değişir.

Örnek:

```rust
use ui::{GradientFade, prelude::*};

fn render_fading_row(cx: &App) -> impl IntoElement {
    let base = cx.theme().colors().panel_background;
    let hover = cx.theme().colors().element_hover;

    h_flex()
        .group("metadata-row")
        .relative()
        .overflow_hidden()
        .child(Label::new("A very long metadata value that fades near the action").truncate())
        .child(
            GradientFade::new(base, hover, hover)
                .width(px(64.))
                .group_name("metadata-row"),
        )
}
```

Zed içinden kullanım:

- `../zed/crates/ui/src/components/ai/thread_item.rs`: action slot ve metadata
  fade overlay.
- `../zed/crates/sidebar/src/sidebar.rs`: sidebar satır hover fade.

Dikkat edilecekler:

- Parent `relative()` ve `overflow_hidden()` olmalıdır.
- Fade gerçek layout alanı ayırmaz; action slot veya trailing content için ayrıca
  padding/space bırakın.

### Vector ve Görsel Kullanımı

Kaynak:

- Tanım: `../zed/crates/ui/src/components/image.rs`
- Export: `ui::Vector`, `ui::VectorName`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Vector`

Ne zaman kullanılır:

- Zed içinde paketlenmiş SVG görsellerini belirli boyutta render etmek için.
- Logo, stamp veya product mark gibi icon standardına uymayan vektörler için.

Ne zaman kullanılmaz:

- Standart simge için `Icon`.
- Kullanıcı avatarı için `Avatar`.
- Raster veya dış görsel için GPUI `img(...)` / `ImageSource`.

Temel API:

- `Vector::new(VectorName, width: Rems, height: Rems)`
- `Vector::square(VectorName, size: Rems)`
- `.color(Color)`
- `.size(Size<Rems>)`
- `CommonAnimationExt` üzerinden `.with_rotate_animation(duration)`; doğrudan
  `.transform(...)` Zed tüketici API'si olarak re-export edilmez.
- `VectorName`: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`,
  `StudentStamp`, `ZedLogo`, `ZedXCopilot`

Davranış:

- `VectorName::path()` `images/<name>.svg` yolu üretir.
- SVG `flex_none()`, width ve height rem değerleriyle render edilir.
- `.color(...)`, SVG `text_color(...)` üzerinden uygulanır.

Örnek:

```rust
use ui::{Vector, VectorName, prelude::*};

fn render_zed_mark() -> impl IntoElement {
    Vector::square(VectorName::ZedLogo, rems(3.)).color(Color::Accent)
}
```

Dikkat edilecekler:

- `Image` adında public Zed UI component'i yoktur; rehberde görsel ihtiyacı için
  `Vector`, `Avatar`, `Icon` ve GPUI `img(...)` ayrımı yapılmalıdır.
- `VectorName` yalnızca kaynakta tanımlı bundled asset'leri kapsar.

GPUI `img(...)` ve `ImageSource` (raster veya dış görsel için):

```rust
use gpui::{ImageSource, SharedUri, img};
use ui::prelude::*;

fn render_remote_thumbnail() -> impl IntoElement {
    img(ImageSource::from(SharedUri::from(
        "https://zed.dev/img/banner.png",
    )))
    .size(px(96.))
    .rounded_md()
}

fn render_local_thumbnail() -> impl IntoElement {
    img(ImageSource::from(std::path::Path::new("/tmp/preview.png")))
        .size(px(96.))
        .rounded_md()
}
```

`ImageSource` aşağıdaki kaynaklardan otomatik dönüşür:

| Kaynak | Notlar |
| :-- | :-- |
| `&str`, `String`, `SharedString` | URL veya yerel yol; URL ise asenkron yüklenir. |
| `SharedUri` | Tip güvenli URL gösterimi; `Avatar::new("https://...")` örtük bu yolu kullanır. |
| `&Path`, `Arc<Path>`, `PathBuf` | Dosya sistemi yolu; senkron olarak okunur. |
| `Arc<RenderImage>`, `Arc<Image>` | Önceden decode edilmiş image bytes. |
| `F: Fn(&mut Window, &mut App) -> ImageSource` | Çağrı sırasında dinamik kaynak üretmek için. |

`Avatar::new` bu `Into<ImageSource>` zincirinin üzerinde durur; raw `img(...)`
kullanırken `flex_none()` ve sabit `size(...)` vermezseniz layout taşmaları
yaşanabilir. SVG ikon için her zaman `Icon` veya `Vector` tercih edilmelidir;
`img(...)` SVG path'lerini raster gibi muamele eder ve recolor edemez.

### KeyBinding

Kaynak:

- Tanım: `../zed/crates/ui/src/components/keybinding.rs`
- Export: `ui::KeyBinding`, `ui::Key`, `ui::KeyIcon`,
  `ui::render_keybinding_keystroke`, `ui::text_for_action`,
  `ui::text_for_keystrokes`, `ui::text_for_keybinding_keystrokes`,
  `ui::render_modifiers`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for KeyBinding`

Ne zaman kullanılır:

- UI içinde action'a bağlı shortcut göstermek için.
- Explicit keystroke dizisini platforma uygun tuş görseli olarak render etmek
  için.
- Tooltip, command palette veya ayar satırında klavye kısayolu göstermek için.

Ne zaman kullanılmaz:

- Keymap'e yeni binding tanımlamak için `gpui::KeyBinding` kullanılır.
- Sadece açıklama metni gerekiyorsa `text_for_action(...)` veya `Label`.

Temel API:

- `KeyBinding::for_action(action, cx)`
- `KeyBinding::for_action_in(action, focus_handle, cx)`
- `KeyBinding::new(action, focus_handle, cx)`
- `KeyBinding::from_keystrokes(keystrokes, vim_mode)`
- `.platform_style(PlatformStyle)`
- `.size(size)`
- `.disabled(bool)`
- `.has_binding(window)`
- `KeyBinding::set_vim_mode(cx, enabled)`
- `Key::new(key: impl Into<SharedString>, color: Option<Color>)` ve
  `KeyIcon::new(icon: IconName, color: Option<Color>)`: tekil tuş veya ikonlu
  tuş yüzeyi.
- `render_modifiers(modifiers: &Modifiers, platform_style: PlatformStyle,
  color: Option<Color>, size: Option<AbsoluteLength>, trailing_separator: bool)
  -> impl Iterator<Item = AnyElement>`: modifier dizisini platform stiline göre
  ikon/metin elementlerine çeviren düşük seviye helper. `trailing_separator`
  son modifier'dan sonra `+` ayırıcısı ekler.
- `text_for_keystroke(modifiers: &Modifiers, key: &str, cx: &App) -> String`:
  tek bir keystroke için platforma duyarlı metin üretir.

Davranış:

- Action source kullanıldığında window'daki en yüksek öncelikli binding aranır.
- Focus handle verilirse önce action için focus bağlamındaki binding aranır.
- Binding bulunamazsa `Empty` render edilir.
- Platform stili macOS için modifier icon'ları, Linux/Windows için metin ve `+`
  separator kullanır.

Örnek:

```rust
use gpui::{AnyElement, KeybindingKeystroke, Keystroke};
use ui::{KeyBinding, prelude::*};

fn render_save_shortcut() -> AnyElement {
    let Ok(parsed) = Keystroke::parse("cmd-s") else {
        return div().into_any_element();
    };
    let keystroke = KeybindingKeystroke::from_keystroke(parsed);

    KeyBinding::from_keystrokes(vec![keystroke].into(), false).into_any_element()
}
```

Dikkat edilecekler:

- `ui::KeyBinding` ile `gpui::KeyBinding` importlarını aynı dosyada kullanırken
  alias verin; aksi halde kod okunması zorlaşır.
- Action'a bağlı shortcut gösteriyorsanız binding bulunamama durumunu UI'da
  düşünün; component boş render edebilir.

### KeybindingHint

Kaynak:

- Tanım: `../zed/crates/ui/src/components/keybinding_hint.rs`
- Export: `ui::KeybindingHint`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for KeybindingHint`

Ne zaman kullanılır:

- Shortcut'ı prefix/suffix metniyle birlikte açıklamak için.
- Tooltip veya empty state içinde kısa klavye ipucu göstermek için.

Temel API:

- `KeybindingHint::new(keybinding, background_color)`
- `KeybindingHint::with_prefix(prefix, keybinding, background_color)`
- `KeybindingHint::with_suffix(keybinding, suffix, background_color)`
- `.prefix(text)`
- `.suffix(text)`
- `.size(Pixels)`

Davranış:

- Prefix/suffix italic buffer font ile render edilir.
- Keybinding parçası border, subtle background ve küçük shadow alır.
- Background color, theme text/accent renkleriyle blend edilerek hint yüzeyi
  oluşturulur.

Örnek:

```rust
use gpui::{AnyElement, KeybindingKeystroke, Keystroke};
use ui::{KeyBinding, KeybindingHint, prelude::*};

fn render_command_hint(cx: &App) -> AnyElement {
    let Ok(parsed) = Keystroke::parse("cmd-shift-p") else {
        return div().into_any_element();
    };
    let keystroke = KeybindingKeystroke::from_keystroke(parsed);
    let binding = KeyBinding::from_keystrokes(vec![keystroke].into(), false);

    KeybindingHint::new(binding, cx.theme().colors().surface_background)
        .prefix("Open command palette:")
        .into_any_element()
}
```

Zed içinden kullanım:

- `../zed/crates/settings_ui/src/settings_ui.rs`: ayar UI kısayol ipuçları.
- `../zed/crates/git_ui/src/commit_modal.rs`: modal shortcut hint'i.

Dikkat edilecekler:

- `background_color` parent yüzeyine yakın seçilmelidir; hint kendi border ve
  fill rengini bu değerden türetir.
- Çok uzun prefix/suffix kullanmayın; kısa komut açıklaması için tasarlanmıştır.

### Navigable

Kaynak:

- Tanım: `../zed/crates/ui/src/components/navigable.rs`
- Export: `ui::Navigable`, `ui::NavigableEntry`
- Prelude: Hayır, ayrıca import edin.
- Preview: Hayır.

Ne zaman kullanılır:

- Scrollable view içinde `menu::SelectNext` / `menu::SelectPrevious` aksiyonlarıyla
  klavye gezintisi kurmak için.
- Focus handle ve scroll anchor listesini tek wrapper'a bağlamak için.

Temel API:

- `NavigableEntry::new(scroll_handle, cx)`
- `NavigableEntry::focusable(cx)`
- `Navigable::new(child: AnyElement)`
- `.entry(NavigableEntry)`
- `NavigableEntry` public alanları: `focus_handle` ve
  `scroll_anchor: Option<ScrollAnchor>`. `new(...)` scroll anchor'lı entry,
  `focusable(...)` ise `scroll_anchor: None` olan entry üretir.

Davranış:

- Entry ekleme sırası traversal sırasıdır.
- Select next/previous aksiyonları focused entry'yi bulur, hedef entry'nin
  focus handle'ını focus eder ve scroll anchor varsa görünür alana scroll eder.
- `NavigableEntry::focusable(...)` scroll anchor olmadan focusable entry üretir.

Örnek:

```rust
use gpui::ScrollHandle;
use ui::{Navigable, NavigableEntry, prelude::*};

fn render_navigable_rows(scroll_handle: &ScrollHandle, cx: &App) -> impl IntoElement {
    let first = NavigableEntry::new(scroll_handle, cx);
    let second = NavigableEntry::new(scroll_handle, cx);

    let content = v_flex()
        .child(div().track_focus(&first.focus_handle).child(Label::new("First")))
        .child(div().track_focus(&second.focus_handle).child(Label::new("Second")));

    Navigable::new(content.into_any_element())
        .entry(first)
        .entry(second)
}
```

Dikkat edilecekler:

- Wrapper yalnızca action routing ve focus/scroll geçişini kurar; her child'ın
  kendisi focus track etmelidir.
- Entry listesi render edilen item sırasıyla aynı tutulmalıdır.

### AI ve Collab Bileşenleri

Bu alt grup Zed'in agent, provider ve collaboration ekranlarında kullanılan daha
özelleşmiş component'lerdir. Genel uygulamalarda doğrudan kullanmadan önce domain
modelinizin bu API'ye gerçekten uyup uymadığını kontrol edin.

### AiSettingItem

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

### AgentSetupButton

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

### ThreadItem

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

### ConfiguredApiCard

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

### ParallelAgentsIllustration

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

### CollabNotification

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

### UpdateButton

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
- `.on_click(handler)`
- `.on_dismiss(handler)`
- Convenience constructors:
  `UpdateButton::checking()`, `downloading(version)`, `installing(version)`,
  `updated(version)`, `errored(error)`

Davranış:

- `icon_animate(true)`, icon'a rotate animation uygular.
- `.with_dismiss()` sağ tarafta dismiss icon button gösterir.
- Main area `ButtonLike::new("update-button")` ile render edilir.
- Tooltip verilirse main button area'ya bağlanır.

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
- `updated(...)` ve `errored(...)` dismiss gösterir; dismiss callback'i
  bağlanmazsa button görünür ama state temizlenmez.

### Diğer ve AI/Collab Kompozisyon Örnekleri

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

## 12. Entegre Örnek Sayfaları

Bileşenleri tek tek doğru kullanmak yeterli değildir. Gerçek ekranlarda önemli
olan, state'in hangi view'da tutulduğu, event'lerin hangi sınırdan geçtiği,
asenkron işlerin nasıl izleneceği ve görsel state değişiminden sonra yeniden
render'ın nasıl tetikleneceğidir.

Bu bölümdeki örnekler tam ekran uygulama değildir; kendi domain tiplerinizi,
settings servislerinizi ve action tiplerinizi bağlayacağınız iskeletlerdir.
Kullanılan component API'leri `../zed` çalışma ağacındaki kaynak dosyalara göre
düzenlenmiştir.

Ortak uygulama kuralları:

- View'a ait geçici UI state'i view struct'ında tutun: seçili satır, açık menü,
  pending async task, hata mesajı, progress değeri.
- Paylaşılan veya servis kaynaklı state'i doğrudan component içinde saklamayın;
  render sırasında component'e label, status, icon, callback ve metadata olarak
  aktarın.
- View state'i değiştiren handler'larda `cx.listener(...)` kullanın. Bu sayede
  closure view instance'ına güvenli şekilde ulaşır.
- Görsel state değiştiğinde `cx.notify()` çağırın. Özellikle `selected`,
  `expanded`, `saving`, `error`, `progress` ve hover dışı custom state'lerde
  bunu atlamayın.
- Tamamlanması izlenecek asenkron işleri `Task` alanında saklayın. Sonucu UI'ı
  değiştirmeyen fire-and-forget işler için `.detach_and_log_err(cx)` kullanın.
- Menü içeriklerini `ContextMenu::build(...)` içinde oluşturun; menünün
  açılmasını `PopoverMenu` veya `right_click_menu(...)` gibi taşıyıcı
  bileşenlerle bağlayın.

### Ayarlar Paneli Satırı

Bu örnekte `Headline`, `Label`, `SwitchField`, `Button` ve `Callout` tek bir
ayar satırı içinde birlikte kullanılır.

Neden birlikte:

- `Headline` section başlığını verir.
- `Label` ayarın adı ve açıklaması için hafif metin katmanıdır.
- `SwitchField`, boolean ayarı erişilebilir bir toggle olarak yönetir.
- `Button`, elle kaydetme veya reset gibi komutları taşır.
- `Callout`, satırın altındaki hata, uyarı veya açıklayıcı aksiyonu gösterir.

State:

- `format_on_save`: switch'in render state'i.
- `saving`: button disable ve progress metni için geçici state.
- `last_error`: yalnızca hata olduğunda `Callout` render edilir.
- `_save_task`: ayar yazımı bitene kadar task'ın düşmemesi için tutulur.

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

Dikkat edilecekler:

- `SwitchField::new(...)` callback'i yeni state'i `&ToggleState` olarak alır.
  `ToggleState::selected()` indeterminate state'i `false` kabul eder; üç durumlu
  bir ayarınız varsa `match` ile açık ele alın.
- Switch state'i optimistik güncelleniyorsa hata durumunda eski değeri geri
  yazın ve `cx.notify()` çağırın.
- Uzun süren yazımlarda `Button` ve `SwitchField` disabled olmalı; aksi halde
  aynı ayar için üst üste task başlatabilirsiniz.

### Toolbar ve Komut Menüsü

Bu örnekte `Button`, `IconButton`, `SplitButton`, `PopoverMenu`, `ContextMenu`,
`Tooltip` ve `KeybindingHint` aynı toolbar davranışını tamamlar.

Neden birlikte:

- `Button` veya `ButtonLike`, birincil komutu taşır.
- `IconButton`, compact komutlar ve menü tetikleyicileri için uygundur.
- `SplitButton`, birincil eylem ile varyant menüsünü tek kontrol gibi gösterir.
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

`KeybindingHint` için kural:

- Shortcut'ı sabit string olarak yazmayın; mümkünse uygulamadaki action/keymap
  çözümünden `ui::KeyBinding` üretin.
- Hint'i toolbar'da her zaman göstermeyin. Komut palette, empty state veya
  onboarding gibi bağlamlarda daha değerlidir.
- Icon-only button varsa `Tooltip` zorunlu kabul edilmelidir; label'lı button'da
  tooltip yalnızca ek bağlam sağlıyorsa kullanılmalıdır.

### Proje Listesi

Bu örnekte `List`, `ListItem`, `TreeViewItem`, `Disclosure`, `IndentGuides` ve
`CountBadge` proje gezgini benzeri bir görünümde birlikte kullanılır.

Neden birlikte:

- `List`, liste container'ı ve empty state davranışını sağlar.
- `ListItem`, satır slot'ları, selected state ve secondary click için uygundur.
- `TreeViewItem`, dosya ağacı gibi expand/collapse ve focus davranışı olan
  satırlarda kullanılır.
- `Disclosure`, özel satır layout'larında aç/kapat icon'unu ayırır.
- `IndentGuides`, virtualization kullanılan ağaç listelerinde girinti çizgilerini
  hesaplama/render sürecine bağlanır.
- `CountBadge`, klasör veya filtre sonucundaki sayıları kompakt gösterir.

State:

- `expanded_project_ids`: hangi root veya klasörlerin açık olduğu.
- `selected_path`: tek seçili proje/dosya yolu.
- `pending_context_menu_path`: sağ tık menüsü açılırken kullanılan yol.
- Büyük listelerde scroll ve virtualization state'i component dışında kalmalıdır.

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

`IndentGuides` notu:

- `IndentGuides`, düz `List` içine otomatik çizgi eklemez. `uniform_list` veya
  sticky item decoration bağlamında `indent_guides(indent_size, colors)` ile
  kullanılır.
- Girinti hesabı için `with_compute_indents_fn(...)`, özel çizim için
  `with_render_fn(...)` bağlayın.
- Girinti state'i satır verisinden türetilmelidir; her satırda ayrı ayrı çizgi
  elementleri üretmek büyük ağaçlarda gereksiz maliyet yaratır.

### Veri Tablosu

Bu örnekte `Table`, `TableInteractionState`, `RedistributableColumnsState`,
`Indicator` ve `ProgressBar` birlikte kullanılır.

Neden birlikte:

- `Table`, satır/sütun düzenini ve header davranışını sağlar.
- `TableInteractionState`, scroll ve focus state'ini view dışında tutulabilir
  hale getirir.
- `RedistributableColumnsState`, sabit toplam genişlik içinde kullanıcıya sütun
  yeniden dağıtımı verir.
- `Indicator`, satırdaki kısa status bilgisini gösterir.
- `ProgressBar`, tabloyu besleyen async işlerin ilerlemesini gösterir.

State:

- `interaction_state: Entity<TableInteractionState>`
- `columns_state: Entity<RedistributableColumnsState>`
- `rows: Vec<RowVm>`
- `sync_progress: Option<(f32, f32)>`

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

Dikkat edilecekler:

- `Table::row(...)` küçük ve sabit listeler için yeterlidir. Büyük veri setinde
  `uniform_list(...)` veya `variable_row_height_list(...)` kullanın.
- `RedistributableColumnsState::new(cols, widths, resize_behavior)` içindeki
  `cols`, width sayısı ve resize behavior sayısı aynı olmalıdır.
- Progress değeri değiştiğinde `sync_progress` güncellenmeli ve `cx.notify()`
  çağrılmalıdır.

### Bildirim Merkezi

Bu örnekte `Notification` yaşam döngüsü, `NotificationFrame`,
`AnnouncementToast`, `Banner`, `AlertModal` ve `Button` birlikte düşünülür.

Neden birlikte:

- `Banner`, ekran veya panel üstündeki non-blocking duyuruyu gösterir.
- `NotificationFrame`, workspace notification stack'inde başlık, içerik, close
  ve suppress davranışını çerçeveler.
- `AnnouncementToast`, ürün duyurusu veya yeni özellik tanıtımı için hazır
  layout sağlar.
- `AlertModal`, kısa ve blocking karar anlarında kullanılır.
- `Button`, banner, toast ve modal action yüzeyini tamamlar.

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

- Workspace notification stack'e girecek view, `workspace::notifications::Notification`
  trait sınırını karşılamalıdır: `Render`, `Focusable`,
  `EventEmitter<DismissEvent>` ve `EventEmitter<SuppressEvent>`.
- Dismiss veya suppress state'i component içinde unutulmamalı; kullanıcı tercihi
  kalıcıysa settings/KV store tarafına yazılmalıdır.
- Blocking karar gerekmiyorsa `AlertModal` yerine `Banner` veya
  `NotificationFrame` kullanın.

### AI Sağlayıcı Kartları

Bu örnekte `ConfiguredApiCard`, `AiSettingItem`, `AgentSetupButton`,
`ThreadItem` ve `UpdateButton` aynı AI ayar alanında birlikte kullanılır.

Neden birlikte:

- `AiSettingItem`, agent/provider satırının status ve kaynak bilgisini taşır.
- `ConfiguredApiCard`, credential var/yok state'ini güvenli, kısa bir kartla
  gösterir.
- `AgentSetupButton`, provider veya agent kurulumu için action satırı sağlar.
- `ThreadItem`, son agent oturumlarını listelemek için domain'e özel satırdır.
- `UpdateButton`, AI alanının dışındaki update/collab özel durumlarında da aynı
  compact status/action modelini gösterir.

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
                    .tooltip("Checking provider metadata")
                    .on_click(|_event, _window, _cx| refresh_provider_metadata()),
            )
    }
}
```

Dikkat edilecekler:

- Provider secret veya token değerini component'e vermeyin. `ConfiguredApiCard`
  yalnızca "configured" state'ini ve reset action'ını taşır.
- `AiSettingItemStatus::Authenticating` ve `AuthRequired` gibi state'leri servis
  state'inden türetin; kullanıcı tıklamasıyla optimistic olarak değiştirmeyin.
- `ThreadItem` action slot'unda destructive action varsa tooltip ve confirm
  akışı ekleyin.

### Collaboration Özeti

Bu örnekte `Avatar`, `Facepile`, `CollabNotification`, `DiffStat` ve `Chip`
collaboration özet alanında birlikte kullanılır.

Neden birlikte:

- `Avatar`, tek kullanıcı veya çağrı katılımcısını gösterir.
- `Facepile`, aktif collaborator grubunu az yer kaplayarak gösterir.
- `CollabNotification`, davet veya paylaşım aksiyonu için hazır layout verir.
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

Dikkat edilecekler:

- `Facepile` içinde avatar boyutlarını aynı tutun; karışık boyut overlap
  hizasını bozar.
- `DiffStat` sadece özet sayı içindir. Dosya bazlı diff gerekiyorsa ayrı liste
  veya diff viewer kullanın.
- `CollabNotification` accept/dismiss davranışını kendi başına yönetmez; iki
  `Button`'ın handler'larını notification lifecycle'a bağlayın.

### Uyum Kontrol Listesi

Bir ekranı kendi uygulamanıza taşırken şu sırayla kontrol edin:

- Her state alanının sahibi belli mi: view, entity, servis store veya settings?
- View state'i değiştiren bütün event handler'lar `cx.listener(...)` üzerinden mi?
- Görsel sonucu olan state değişimlerinden sonra `cx.notify()` var mı?
- Async iş sonucunda view hala yaşıyor mu diye `Entity`/`WeakEntity` update
  sınırları doğru kullanılıyor mu?
- Fire-and-forget task'lar `.detach_and_log_err(cx)` ile loglanıyor mu?
- Menü içeriği render sırasında güncel state'ten mi kuruluyor?
- Icon-only kontrollerde `Tooltip` var mı?
- Shortcut gösterimi gerçek keymap/action çözümünden mi geliyor?
- Büyük listelerde `List` yerine virtualization veya `Table::uniform_list(...)`
  gibi uygun yüzey kullanıldı mı?
- AI/collab domain bileşenlerine sadece render metadata'sı veriliyor mu, gizli
  credential veya servis nesnesi taşınmıyor mu?

### Klavye Erişimi ve Action Akışı Kontrol Listesi

GPUI'de bir ekranın klavye erişimi dört parçayla kurulur: focus, tab order,
key context ve action dispatch. Bu parçalar `Navigable`, `Tooltip`, `KeyBinding`,
`Button*`, `ListItem`, `ContextMenu` ve `AlertModal` gibi bileşenlerin builder
yüzeyinde dağıtık olarak görülür. Bir ekran üretirken aşağıdaki sırayı izleyin:

1. **Focus handle'ı tek noktada üretin.** View struct'ında
   `focus_handle: FocusHandle` alanı tutun ve `Focusable` implement edin.
   Modal/AlertModal kullanıyorsanız aynı handle'ı `.track_focus(&focus_handle)`
   ile bağlayın.
2. **Tab order'ı `tab_index(...)` ile verin.** `Button`, `IconButton`,
   `ButtonLike`, `SwitchField`, `Switch`, `DropdownMenu`, `Disclosure`,
   `Tab`, `ToggleButtonGroup`, `ConfiguredApiCard`, `TreeViewItem` ve `Table`
   builder yüzeyleri `tab_index`'i (genellikle `&mut isize` veya `isize`)
   kabul eder. Aynı form üzerinde tek bir counter geçirin; her builder counter'ı
   kendi kullandığı kadar artırır.
3. **`tab_stop`/`track_focus` ile özel focusable kurun.** `ListItem` gibi
   yüksek seviyeli bileşenler odağı kendileri yönetir; özel `div()` veya
   `h_flex()` üzerinde klavye odağı vermek için `.track_focus(&handle)` ve
   gerektiğinde `.tab_index(...)` ekleyin. `NavigableEntry::focusable(cx)`
   scroll anchor'sız focusable entry üretir.
4. **`Navigable` ile up/down traversal kurun.** Scrollable listede
   `menu::SelectNext` / `menu::SelectPrevious` action'ları `Navigable::new(...)
   .entry(NavigableEntry::new(...))` bağlamasıyla doğru entry'ye scroll edip
   focus eder.
5. **`key_context(...)` ile bağlam zinciri kurun.** `AlertModal::key_context(...)`
   ve `ContextMenu::key_context(...)`, modal veya menü içindeyken keymap'in
   doğru bindings'i kullanmasını sağlar. Custom view'larda `cx.set_global` veya
   element üzerinde `.key_context(KeyContext::new("MyView"))` kullanın.
6. **Action dispatch'i `.on_action::<A>(listener)` ile bağlayın.**
   `AlertModal::on_action`, `Modal` içindeki `menu::Cancel` ve özel
   action'lar bu yolla yakalanır. Custom action tanımları `actions!(...)` veya
   `Action` derive makrosuyla yapılır.
7. **Shortcut'ları action'tan türetin.** Tooltip ve hint'lerde shortcut metni
   yazmak yerine `KeyBinding::for_action(action, cx)` veya
   `Tooltip::for_action_title(title, &action)` kullanın. Bu sayede keymap
   değiştiğinde UI otomatik güncel kalır.
8. **Icon-only kontrollerde tooltip zorunludur.** `IconButton`, `Disclosure`,
   `CopyButton` gibi label'sız kontroller `Tooltip::text(...)` veya
   `Tooltip::for_action_title(...)` ile niyetlerini açıklamalı.
9. **Modal/menu kapanınca focus'u geri verin.** `ModalLayer`,
   `ContextMenu`, `PopoverMenu` ve `right_click_menu` bu davranışı zaten
   uygular; özel popover yazıyorsanız `previous_focus_handle`'ı saklayıp
   dismiss'te `window.focus(&handle, cx)` çağırın.

Hızlı kontrol listesi:

- [ ] View'ın `focus_handle` alanı var ve `Focusable` implement ediyor mu?
- [ ] Tab order için tek bir `&mut isize` veya artan `isize` paylaşıldı mı?
- [ ] Listede ok tuşu traversal'i için `Navigable` bağlandı mı?
- [ ] Modal/menu için `key_context(...)` belirtildi mi?
- [ ] Shortcut tooltip'leri action tabanlı helper'larla mı üretiliyor?
- [ ] Icon-only kontroller `Tooltip` taşıyor mu?
- [ ] Modal/menu kapanışında önceki focus geri veriliyor mu?
- [ ] Sağ tık menüsü ve `on_secondary_mouse_down` davranışları aynı action
  setine bağlanıyor mu (mouse ve klavye akışı tutarlı mı)?

## 13. Ham GPUI Primitive'leri ve Metod Kapsamı

Bu bölüm, Zed `ui` bileşen katmanının altında kalan `gpui::elements`
primitive'lerini kapsar. Kural şudur: Zed `ui` içinde hazır bir bileşen varsa
önce onu kullanın; ham GPUI primitive'lerine yalnızca layout, çizim, metin
ölçümü, görsel cache, virtual list veya özel etkileşim yüzeyi gerektiğinde inin.

Kaynak kapısı:

- `crates/gpui/src/elements/mod.rs`: primitive export kapısı.
- `crates/gpui/src/element.rs`: `ParentElement`, `IntoElement`, `Element`.
- `crates/gpui/src/styled.rs`: `Styled` ortak stil yüzeyi.
- `crates/gpui/src/elements/div.rs`: `Div`, `Interactivity`,
  `InteractiveElement`, `StatefulInteractiveElement`, `ScrollHandle`.
- `crates/gpui/src/elements/{canvas,img,image_cache,svg,anchored,deferred,surface,text,list,uniform_list,animation}.rs`:
  özel primitive API'leri.

### Public GPUI element adları

Aşağıdaki liste `crates/gpui/src/elements` altındaki public type, trait,
constructor ve constant adlarını temsil eder. Rehber kapsam denetiminde bu
listenin boşta kalan adı olmamalıdır.

```text
Anchored, AnchoredFitMode, AnchoredPositionMode, AnchoredState,
Animation, AnimationElement, AnimationExt, AnyImageCache, Canvas, Deferred,
DeferredScrollToItem, Div, DivFrameState, DivInspectorState, DragMoveEvent,
ElementClickedState, ElementHoverState, FollowMode, GroupStyle,
ImageAssetLoader, ImageCache, ImageCacheElement, ImageCacheError,
ImageCacheItem, ImageCacheProvider, ImageLoadingTask, ImageSource,
ImageStyle, Img, ImgLayoutState, ImgResourceLoader, InteractiveElement,
InteractiveElementState, InteractiveText, InteractiveTextState,
Interactivity, ItemSize, LOADING_DELAY, List, ListAlignment,
ListHorizontalSizingBehavior, ListMeasuringBehavior, ListOffset,
ListPrepaintState, ListScrollEvent, ListSizingBehavior, ListState,
RetainAllImageCache, RetainAllImageCacheProvider, ScrollAnchor,
ScrollHandle, ScrollStrategy, Stateful, StatefulInteractiveElement,
StyledImage, StyledText, Surface, SurfaceSource, Svg, TextLayout,
Transformation, UniformList, UniformListDecoration, UniformListFrameState,
UniformListScrollHandle, UniformListScrollState, anchored, canvas, deferred,
div, image_cache, img, list, retain_all, surface, svg, uniform_list
```

### Karar tablosu

| İhtiyaç | Öncelikli API | Ham GPUI'ye inme sebebi |
| :-- | :-- | :-- |
| Standart satır, toolbar, ayar, menü, modal, tab, bildirim | `ui::*` bileşenleri | Tasarım token'ları, focus ve erişilebilirlik hazır gelir |
| Sadece container/layout | `div()`, `h_flex()`, `v_flex()` | Bileşen gerekmeyen layout yüzeyi |
| Özel paint veya ölçüm | `canvas(prepaint, paint)` | Hitbox, path, custom çizim veya renderer state gerekir |
| Görsel gösterimi | `img(source)` | Asset, URI, bytes veya cache davranışı gerekir |
| Ortak görsel cache | `image_cache(provider)` / `retain_all(id)` | Alt ağaçtaki `img` elemanları aynı cache'i kullanmalıdır |
| SVG asset | `svg().path(...)` / `.external_path(...)` | Vektör asset ve transform gerekir |
| Floating/anchored yüzey | `anchored()` | Tooltip, popover veya konumlanan overlay özel yazılır |
| Ertelenmiş ağır alt ağaç | `deferred(child)` | Render önceliği yönetilir |
| macOS surface | `surface(source)` | `CVPixelBuffer` tabanlı native yüzey çizilir |
| Değişken yükseklikli sanal liste | `list(state, render_item)` | Satır yüksekliği ölçülür ve state ile scroll yönetilir |
| Sabit yükseklikli sanal liste | `uniform_list(id, count, render_item)` | Çok büyük listede hızlı virtualization gerekir |
| Metin layout ölçümü veya span etkileşimi | `StyledText`, `InteractiveText` | Seçili aralık, highlight, hit-test veya inline tooltip gerekir |
| Animasyon | `Animation::new(...)`, `.with_animation(...)` | Element wrapper ile zaman tabanlı transform gerekir |

### Ortak trait yüzeyleri

`ParentElement`, çocuk alan bütün container'ların ortak ekleme kapısıdır:

| Trait | Metodlar | Not |
| :-- | :-- | :-- |
| `ParentElement` | `.extend(elements)`, `.child(child)`, `.children(children)` | `child` ve `children`, `IntoElement` kabul eder; `extend` `AnyElement` koleksiyonu ister |

`Styled`, `style(&mut self) -> &mut StyleRefinement` zorunlu metodunu ve
makro ile üretilen utility yüzeyini taşır. `Div`, `Img`, `Svg`, `Canvas`,
`Surface`, `ImageCacheElement`, `List`, `UniformList`, `Deferred`,
`AnimationElement` ve birçok Zed `ui` bileşeni bu yüzeyi miras alır.

`Styled` manuel metodları:

```text
block, flex, grid, hidden, scrollbar_width,
whitespace_normal, whitespace_nowrap, text_ellipsis, text_ellipsis_start,
text_overflow, text_align, text_left, text_center, text_right, truncate,
line_clamp, flex_col, flex_col_reverse, flex_row, flex_row_reverse,
flex_1, flex_auto, flex_initial, flex_none, flex_basis, flex_grow,
flex_grow_0, flex_shrink, flex_shrink_0, flex_wrap, flex_wrap_reverse,
flex_nowrap, items_start, items_end, items_center, items_baseline,
items_stretch, self_start, self_end, self_flex_start, self_flex_end,
self_center, self_baseline, self_stretch, justify_start, justify_end,
justify_center, justify_between, justify_around, justify_evenly,
content_normal, content_center, content_start, content_end,
content_between, content_around, content_evenly, content_stretch,
aspect_ratio, aspect_square, bg, border_dashed, text_style, text_color,
font_weight, text_bg, text_size, text_xs, text_sm, text_base, text_lg,
text_xl, text_2xl, text_3xl, italic, not_italic, underline, line_through,
text_decoration_none, text_decoration_color, text_decoration_solid,
text_decoration_wavy, text_decoration_0, text_decoration_1,
text_decoration_2, text_decoration_4, text_decoration_8, font_family,
font_features, font, line_height, opacity, grid_cols,
grid_cols_min_content, grid_cols_max_content, grid_rows, col_start,
col_start_auto, col_end, col_end_auto, col_span, col_span_full,
row_start, row_start_auto, row_end, row_end_auto, row_span,
row_span_full, debug, debug_below
```

`Styled` makro metodları kaynakta şu kurallarla üretilir:

| Makro ailesi | Üretilen metodlar |
| :-- | :-- |
| Visibility | `visible`, `invisible` |
| Size/gap prefix'leri | `w`, `h`, `size`, `min_size`, `min_w`, `min_h`, `max_size`, `max_w`, `max_h`, `gap`, `gap_x`, `gap_y` |
| Margin prefix'leri | `m`, `mt`, `mb`, `my`, `mx`, `ml`, `mr` |
| Padding prefix'leri | `p`, `pt`, `pb`, `px`, `py`, `pl`, `pr` |
| Position prefix'leri | `relative`, `absolute`, `inset`, `top`, `bottom`, `left`, `right` |
| Radius prefix'leri | `rounded`, `rounded_t`, `rounded_b`, `rounded_r`, `rounded_l`, `rounded_tl`, `rounded_tr`, `rounded_bl`, `rounded_br` |
| Border prefix'leri | `border_color`, `border`, `border_t`, `border_b`, `border_r`, `border_l`, `border_x`, `border_y` |
| Overflow | `overflow_hidden`, `overflow_x_hidden`, `overflow_y_hidden` |
| Cursor | `cursor`, `cursor_default`, `cursor_pointer`, `cursor_text`, `cursor_move`, `cursor_not_allowed`, `cursor_context_menu`, `cursor_crosshair`, `cursor_vertical_text`, `cursor_alias`, `cursor_copy`, `cursor_no_drop`, `cursor_grab`, `cursor_grabbing`, `cursor_ew_resize`, `cursor_ns_resize`, `cursor_nesw_resize`, `cursor_nwse_resize`, `cursor_col_resize`, `cursor_row_resize`, `cursor_n_resize`, `cursor_e_resize`, `cursor_s_resize`, `cursor_w_resize` |
| Shadow | `shadow`, `shadow_none`, `shadow_2xs`, `shadow_xs`, `shadow_sm`, `shadow_md`, `shadow_lg`, `shadow_xl`, `shadow_2xl` |

Size, margin, padding ve position prefix'leri için suffix formülü:
`{prefix}(length)` custom setter'ı vardır. Ayrıca uygun prefix'lerde
`{prefix}_{suffix}` ve auto dışındaki suffix'lerde `{prefix}_neg_{suffix}`
üretilir. Suffix seti: `0`, `0p5`, `1`, `1p5`, `2`, `2p5`, `3`, `3p5`,
`4`, `5`, `6`, `7`, `8`, `9`, `10`, `11`, `12`, `16`, `20`, `24`, `32`,
`40`, `48`, `56`, `64`, `72`, `80`, `96`, `112`, `128`, `auto`, `px`,
`full`, `1_2`, `1_3`, `2_3`, `1_4`, `2_4`, `3_4`, `1_5`, `2_5`, `3_5`,
`4_5`, `1_6`, `5_6`, `1_12`. `gap*`, `padding*` prefix'leri `auto`
üretmez. Radius suffix seti: `none`, `xs`, `sm`, `md`, `lg`, `xl`, `2xl`,
`3xl`, `full`. Border suffix seti: `0`, `1`, `2`, `3`, `4`, `5`, `6`, `7`,
`8`, `9`, `10`, `11`, `12`, `16`, `20`, `24`, `32`.

`InteractiveElement`, ham etkileşimli container davranışını taşır. `id(...)`
çağrısı `Stateful<Self>` döndürür; scroll, click, drag, active ve tooltip
gibi state isteyen metodlar bundan sonra kullanılabilir.

```text
group, id, track_focus, tab_stop, tab_index, tab_group, key_context,
hover, group_hover, debug_selector,
on_mouse_down, capture_any_mouse_down, on_any_mouse_down, on_mouse_up,
capture_any_mouse_up, on_any_mouse_up, on_mouse_pressure,
capture_mouse_pressure, on_mouse_down_out, on_mouse_up_out, on_mouse_move,
on_drag_move, on_scroll_wheel, on_pinch, capture_pinch, capture_action,
on_action, on_boxed_action, on_key_down, capture_key_down, on_key_up,
capture_key_up, on_modifiers_changed, drag_over, group_drag_over, on_drop,
can_drop, occlude, window_control_area, block_mouse_except_scroll, focus,
in_focus, focus_visible
```

`StatefulInteractiveElement` metodları:

```text
focusable, overflow_scroll, overflow_x_scroll, overflow_y_scroll,
track_scroll, anchor_scroll, active, group_active, on_click, on_aux_click,
on_drag, on_hover, tooltip, hoverable_tooltip
```

`Interactivity` lower-level metodları yukarıdaki fluent API'nin iç
karşılıklarıdır: `on_mouse_down`, `capture_any_mouse_down`,
`on_any_mouse_down`, `on_mouse_up`, `capture_any_mouse_up`,
`on_any_mouse_up`, `on_mouse_pressure`, `capture_mouse_pressure`,
`on_mouse_down_out`, `on_mouse_up_out`, `on_mouse_move`, `on_drag_move`,
`on_scroll_wheel`, `on_pinch`, `capture_pinch`, `capture_action`,
`on_action`, `on_boxed_action`, `on_key_down`, `capture_key_down`,
`on_key_up`, `capture_key_up`, `on_modifiers_changed`, `on_drop`,
`can_drop`, `on_click`, `on_aux_click`, `on_drag`, `on_hover`, `tooltip`,
`hoverable_tooltip`, `occlude_mouse`, `window_control_area`,
`block_mouse_except_scroll`. Uygulama kodunda mümkünse fluent
`InteractiveElement` / `StatefulInteractiveElement` metodlarını kullanın;
`Interactivity` doğrudan custom element yazarken gerekir.

Framework implementer metodları `source_location`, `request_layout`,
`prepaint`, `paint` ve `Div::compute_style` olarak görünür. Bunlar builder API
değildir; `Element` implementasyonu yazarken veya GPUI içini değiştirirken ele
alınır. `GroupHitboxes::get/push/pop` grup hover/active hitbox state'inin
internal global stack yönetimidir. `DraggedItem<T>::drag(cx)` ve
`.dragged_item()` drag payload okumak için event yardımcılarıdır.

Animasyon easing yardımcıları `linear(delta)`, `quadratic(delta)`,
`ease_in_out(delta)`, `ease_out_quint()` ve `bounce(easing)` adlarıyla export
edilir. Test modülündeki `select_next` / `select_previous` gibi örnek view
metodları public görünse de rehber kapsamı için component API sayılmaz.

### Primitive API kataloğu

| API | Constructor | Özel metodlar / ilişkili tipler | Kullanım disiplini |
| :-- | :-- | :-- | :-- |
| `Div` | `div()` | `Styled`, `ParentElement`, `InteractiveElement`, `StatefulInteractiveElement`; ayrıca `.on_children_prepainted(...)`, `.image_cache(...)`, `.with_dynamic_prepaint_order(...)` | Her özel layout'un tabanı olabilir; standart kontrol yerine kullanılacaksa focus, hover, tooltip ve action bağları açıkça kurulmalı |
| `ScrollHandle` | `ScrollHandle::new()` | `.offset()`, `.max_offset()`, `.top_item()`, `.bottom_item()`, `.bounds()`, `.bounds_for_item(ix)`, `.scroll_to_item(ix)`, `.scroll_to_top_of_item(ix)`, `.scroll_to_bottom()`, `.set_offset(point)`, `.logical_scroll_top()`, `.logical_scroll_bottom()`, `.children_count()` | `overflow_*_scroll` ve `.track_scroll(&handle)` ile bağlanır |
| `ScrollAnchor` | `ScrollAnchor::for_handle(handle)` | `.scroll_to(window, cx)` | Nested child'ın parent scroll alanına anchor edilmesi gerektiğinde kullanılır |
| `canvas` / `Canvas<T>` | `canvas(prepaint, paint)` | `Styled`; prepaint closure state döndürür, paint closure bu state ile çizim yapar | Sadece custom render gerektiğinde kullanın; layout'u `Styled` boyutlarıyla sabitleyin |
| `img` / `Img` | `img(source)` | `Img::extensions()`, `.image_cache(entity)`; `StyledImage`: `.grayscale(bool)`, `.object_fit(ObjectFit)`, `.with_fallback(fn)`, `.with_loading(fn)` | Loading ve fallback UI'sız uzak/asset görsel bırakmayın |
| `ImageSource` | `ImageSource::{Resource, Custom, Render, Image}` | `.remove_asset(cx)` | Asset lifecycle açıkça temizlenecekse kullanılır |
| `image_cache` / `ImageCacheElement` | `image_cache(provider)` | `ParentElement`, `Styled`; alt ağaçtaki `img` yüklerini provider cache'ine bağlar | Aynı ekran içinde tekrarlanan görsellerde kullanın |
| `AnyImageCache` | `Entity<I: ImageCache>` üzerinden `From` | `.load(resource, window, cx)` | Cache sağlayıcılarının type erasure katmanı |
| `ImageCache` | trait | `.load(resource, window, cx)` | Uygulama özel cache stratejisi gerekiyorsa implement edin |
| `ImageCacheProvider` | trait | `.provide(window, cx)` | Render/request-layout aşamasında cache sağlar |
| `RetainAllImageCache` | `RetainAllImageCache::new(cx)` | `.load(source, window, cx)`, `.clear(window, cx)`, `.remove(source, window, cx)`, `.len()`, `.is_empty()` | Basit retain-all stratejisidir; uzun ömürlü ekranlarda clear/remove sorumluluğunu unutmayın |
| `retain_all` | `retain_all(id)` | `RetainAllImageCacheProvider` üretir | Inline cache provider gerektiğinde kullanılır |
| `svg` / `Svg` | `svg()` | `.path(path)`, `.external_path(path)`, `.with_transformation(transformation)` | Icon için `Icon` tercih edin; raw SVG yalnızca asset transform gerekiyorsa |
| `Transformation` | `Transformation::scale(size)`, `::translate(point)`, `::rotate(radians)` | `.with_scaling(size)`, `.with_translation(point)`, `.with_rotation(radians)` | Birden fazla transform gerekiyorsa builder zinciriyle tek `Transformation` üretin |
| `anchored` / `Anchored` | `anchored()` | `.anchor(anchor)`, `.position(point)`, `.offset(point)`, `.position_mode(mode)`, `.snap_to_window()`, `.snap_to_window_with_margin(edges)`; `AnchoredFitMode`, `AnchoredPositionMode`, `AnchoredState` | Popover/menu gibi hazır yüzeyler yeterliyse onları kullanın; custom overlay'de pencere sınırı snap'ini açıkça seçin |
| `deferred` / `Deferred` | `deferred(child)` | `.with_priority(priority)`; `DeferredScrollToItem::priority(priority)` | Ağır alt ağaçları render sırasına sokar; interaktif kritik kontrolleri ertelemeyin |
| `surface` / `Surface` | `surface(source)` | `.object_fit(ObjectFit)`; `SurfaceSource` macOS `CVPixelBuffer` taşır | macOS native surface dışında kullanmayın; platform cfg sınırını koruyun |
| `list` / `List` | `list(state, render_item)` | `.with_sizing_behavior(ListSizingBehavior)`; `ListAlignment`, `ListHorizontalSizingBehavior`, `ListMeasuringBehavior`, `ListOffset`, `ListScrollEvent`, `FollowMode` | Değişken satır yüksekliğinde kullanın; state'i view alanında saklayın |
| `ListState` | `ListState::new(item_count, alignment, overdraw)` | `.measure_all()`, `.reset(count)`, `.remeasure()`, `.remeasure_items(range)`, `.item_count()`, `.is_scrolled_to_end()`, `.splice(range, count)`, `.splice_focusable(...)`, `.set_scroll_handler(...)`, `.logical_scroll_top()`, `.scroll_by(distance)`, `.scroll_to_end()`, `.set_follow_mode(mode)`, `.is_following_tail()`, `.scroll_to(offset)`, `.scroll_to_reveal_item(ix)`, `.bounds_for_item(ix)`, `.scrollbar_drag_started()`, `.scrollbar_drag_ended()`, `.is_scrollbar_dragging()`, `.set_offset_from_scrollbar(point)`, `.max_offset_for_scrollbar()`, `.scroll_px_offset_for_scrollbar()`, `.viewport_bounds()` | Veri değişiminde `splice`/`reset`, ölçüm değişiminde `remeasure*` çağrılmalı |
| `uniform_list` / `UniformList` | `uniform_list(id, item_count, render_item)` | `.with_width_from_item(index)`, `.with_sizing_behavior(...)`, `.with_horizontal_sizing_behavior(...)`, `.with_decoration(decoration)`, `.track_scroll(handle)`, `.y_flipped(bool)`; `UniformListDecoration`, `UniformListFrameState`, `UniformListScrollState` | Sabit satır geometrisi ve çok büyük veri için tercih edilir |
| `UniformListScrollHandle` | `UniformListScrollHandle::new()` | `.scroll_to_item(ix, strategy)`, `.scroll_to_item_strict(ix, strategy)`, `.scroll_to_item_with_offset(ix, strategy, offset)`, `.scroll_to_item_strict_with_offset(ix, strategy, offset)`, `.y_flipped()`, `.logical_scroll_top_index()`, `.is_scrollable()`, `.is_scrolled_to_end()`, `.scroll_to_bottom()`; `ScrollStrategy` | Dışarıdan scroll komutu ve okuma için handle saklanır |
| `StyledText` | `StyledText::new(text)` | `.layout()`, `.with_default_highlights(...)`, `.with_highlights(...)`, `.with_font_family_overrides(...)`, `.with_runs(runs)` | Highlight/rich text gerekiyorsa kullanın; normal label için `Label` daha doğru |
| `TextLayout` | `StyledText::layout()` | `.index_for_position(point)`, `.position_for_index(index)`, `.line_layout_for_index(index)`, `.bounds()`, `.line_height()`, `.len()`, `.text()`, `.wrapped_text()` | Hit-test ve ölçüm bilgisi prepaint/layout sonrası anlamlıdır |
| `InteractiveText` | `InteractiveText::new(id, styled_text)` | `.on_click(range, listener)`, `.on_hover(range, listener)`, `.tooltip(range, builder)`; `InteractiveTextState` | Inline link, mention veya span tooltip için kullanılır |
| `Animation` | `Animation::new(duration)` | `.repeat()`, `.with_easing(easing)` | Animasyon token'larını tek yerde üretin; sonsuz animasyonu bilinçli seçin |
| `AnimationExt` / `AnimationElement` | `.with_animation(id, animation, animator)`, `.with_animations(id, animations, animator)` | `AnimationElement::map_element(f)` | Elementi saran wrapper'dır; stable `ElementId` zorunludur |

### GPUI public enum ve state ayrıntıları

Ad/metod taraması tek başına yeterli değildir; bazı GPUI tiplerinde karar
variant'ları ve public state alanları asıl kullanım bilgisini taşır.

| Tip | Variant / Alan | Kullanım notu |
| :-- | :-- | :-- |
| `ScrollStrategy` | `Top`, `Center`, `Bottom`, `Nearest` | `UniformListScrollHandle` scroll komutlarında hedef item'ın viewport içinde nereye yerleşeceğini seçer |
| `FollowMode` | `Normal`, `Tail` | Chat/log listelerinde tail-follow davranışı; `Tail` yalnızca kullanıcı sonda kalıyorsa otomatik takip eder |
| `ListMeasuringBehavior` | `Measure(bool)`, `Visible` | Büyük değişken yükseklikli listelerde ilk ölçüm maliyetini kontrol eder |
| `ListHorizontalSizingBehavior` | `FitList`, `Unconstrained` | Satır genişliği listeye mi sığacak, yoksa en geniş item'a göre taşabilecek mi kararını verir |
| `AnchoredFitMode` | `SnapToWindow`, `SnapToWindowWithMargin`, `SwitchAnchor` | `anchored()` overlay'lerinde pencere sınırına sığdırma stratejisi |
| `AnchoredPositionMode` | `Window`, `Local` | Anchor koordinatının pencereye mi parent'a mı göre yorumlanacağını belirler |
| `ImageCacheError` | `Io`, `Usvg`, `Other` | Görsel yükleme/render hata sınıfları; fallback render için ayırt edilebilir |
| `ImageCacheItem` | `Loading`, `Loaded` | Cache iç state'i; tüketici çoğunlukla `ImageCache::load` sonucuyla çalışır |

Public state alanları:

| Tip | Alanlar | Not |
| :-- | :-- | :-- |
| `Animation` | `duration`, `oneshot`, `easing` | `.repeat()` `oneshot` değerini `false` yapar; direct field mutation yerine builder kullanın |
| `DeferredScrollToItem` | `item_index`, `strategy`, `offset`, `scroll_strict` | `UniformListScrollHandle` komutlarının pending state'i |
| `UniformListScrollState` | `base_handle`, `deferred_scroll_to_item`, `last_item_size`, `y_flipped` | Scroll handle arkasındaki state; okuma için handle metodlarını tercih edin |
| `ItemSize` | `item`, `contents` | `is_scrollable()` hesabında item viewport'u ve içerik boyutu ayrımı |
| `ListOffset` | `item_ix`, `offset_in_item` | Değişken yükseklikli listede logical scroll pozisyonu |
| `ListScrollEvent` | `visible_range`, `count`, `is_scrolled`, `is_following_tail` | `ListState::set_scroll_handler(...)` callback'inde scroll değişimini okuma yüzeyi |
| `DivInspectorState` | `base_style`, `bounds`, `content_size` | Inspector/debug build state'i; uygulama component API'si değildir |
| `Interactivity` | `element_id`, `active`, `hovered`, `base_style` | `Div` interactivity çekirdeği; üretim kodunda fluent builder metodları tercih edilir |

### Kullanım örüntüleri

Ham `div()` ile özel kontrol yazarken minimum iskelet:

```rust
div()
    .id("custom-control")
    .track_focus(&self.focus_handle)
    .tab_index(tab_index)
    .key_context("CustomControl")
    .hover(|style| style.bg(cx.theme().colors().element_hover))
    .focus_visible(|style| style.border_color(cx.theme().colors().border_focused))
    .on_click(cx.listener(|this, _event, window, cx| {
        this.activate(window, cx);
    }))
    .tooltip(|window, cx| Tooltip::text("Açıklama", window, cx))
    .child(Label::new("Etiket"))
```

Değişken yükseklikli liste örüntüsü:

```rust
list(self.list_state.clone(), move |range, window, cx| {
    range
        .map(|ix| self.render_row(ix, window, cx).into_any_element())
        .collect()
})
.with_sizing_behavior(ListSizingBehavior::Infer)
```

Sabit yükseklikli büyük liste örüntüsü:

```rust
uniform_list("items", self.items.len(), move |range, window, cx| {
    range
        .map(|ix| self.render_uniform_row(ix, window, cx).into_any_element())
        .collect()
})
.track_scroll(&self.uniform_scroll_handle)
```

Görsel cache örüntüsü:

```rust
image_cache(retain_all("image-cache"))
    .child(img(ImageSource::Resource(resource))
        .object_fit(ObjectFit::Cover)
        .with_loading(|_, _| div().size_full().into_any_element())
        .with_fallback(|_, _| Icon::new(IconName::Image).into_any_element()))
```

## 14. Doğrulanmış `crates/ui/src/components` Public API Yüzeyi

Kaynak: `../zed` commit `6e8eaab25b5ac324e11a82d1563dcad39c84bace`.
`pub(crate)`, `pub(super)` ve `pub(in ...)` kapsam dışıdır. Trait metotları
public trait sözleşmesi olduğu için ayrıca listelenir. Private modül içinde
`pub` görünen sealed adlar dış crate API'si değildir; ilgili satırda özellikle
"private/sealed" olarak işaretlenir.
`Öğeler` satırındaki `use ...::*` kayıtları kaynakta `pub use ...::*` olarak
geçen re-export kapılarıdır.

### `crates/ui/src/components.rs`
- Öğeler: `use ai::*`; `use avatar::*`; `use banner::*`; `use button::*`; `use callout::*`; `use chip::*`; `use collab::*`; `use context_menu::*`; `use count_badge::*`; `use data_table::*`; `use diff_stat::*`; `use disclosure::*`; `use divider::*`; `use dropdown_menu::*`; `use facepile::*`; `use gradient_fade::*`; `use group::*`; `use icon::*`; `use image::*`; `use indent_guides::*`; `use indicator::*`; `use keybinding::*`; `use keybinding_hint::*`; `use label::*`; `use list::*`; `use modal::*`; `use navigable::*`; `use notification::*`; `use popover::*`; `use popover_menu::*`; `use progress::*`; `use redistributable_columns::*`; `use right_click_menu::*`; `use scrollbar::*`; `use stack::*`; `use sticky_items::*`; `use tab::*`; `use tab_bar::*`; `use toggle::*`; `use tooltip::*`; `use tree_view_item::*`

### `crates/ui/src/components/ai/agent_setup_button.rs`
- Öğeler: `struct AgentSetupButton`
- Metotlar:
  - `AgentSetupButton::new(id: impl Into<ElementId>) -> Self`
  - `AgentSetupButton::icon(mut self, icon: Icon) -> Self`
  - `AgentSetupButton::name(mut self, name: impl Into<SharedString>) -> Self`
  - `AgentSetupButton::state(mut self, element: impl IntoElement) -> Self`
  - `AgentSetupButton::disabled(mut self, disabled: bool) -> Self`
  - `AgentSetupButton::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`

### `crates/ui/src/components/ai/ai_setting_item.rs`
- Öğeler: `enum AiSettingItemStatus`; `enum AiSettingItemSource`; `struct AiSettingItem`
- Metotlar:
  - `AiSettingItem::new( id: impl Into<ElementId>, label: impl Into<SharedString>, status: AiSettingItemStatus, source: AiSettingItemSource, ) -> Self`
  - `AiSettingItem::icon(mut self, element: impl IntoElement) -> Self`
  - `AiSettingItem::detail_label(mut self, detail: impl Into<SharedString>) -> Self`
  - `AiSettingItem::action(mut self, element: impl IntoElement) -> Self`
  - `AiSettingItem::details(mut self, element: impl IntoElement) -> Self`
- Public enum variantları: AiSettingItemStatus: `Stopped`, `Starting`, `Running`, `Error`, `AuthRequired`, `Authenticating`; AiSettingItemSource: `Extension`, `Custom`, `Registry`

### `crates/ui/src/components/ai/configured_api_card.rs`
- Öğeler: `struct ConfiguredApiCard`
- Metotlar:
  - `ConfiguredApiCard::new(label: impl Into<SharedString>) -> Self`
  - `ConfiguredApiCard::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ConfiguredApiCard::button_label(mut self, button_label: impl Into<SharedString>) -> Self`
  - `ConfiguredApiCard::tooltip_label(mut self, tooltip_label: impl Into<SharedString>) -> Self`
  - `ConfiguredApiCard::disabled(mut self, disabled: bool) -> Self`
  - `ConfiguredApiCard::button_tab_index(mut self, tab_index: isize) -> Self`

### `crates/ui/src/components/ai/parallel_agents_illustration.rs`
- Öğeler: `struct ParallelAgentsIllustration`
- Metotlar:
  - `ParallelAgentsIllustration::new() -> Self`

### `crates/ui/src/components/ai/thread_item.rs`
- Öğeler: `enum AgentThreadStatus`; `enum WorktreeKind`; `struct ThreadItemWorktreeInfo`; `struct ThreadItem`
- Metotlar:
  - `ThreadItem::new(id: impl Into<ElementId>, title: impl Into<SharedString>) -> Self`
  - `ThreadItem::timestamp(mut self, timestamp: impl Into<SharedString>) -> Self`
  - `ThreadItem::icon(mut self, icon: IconName) -> Self`
  - `ThreadItem::icon_color(mut self, color: Color) -> Self`
  - `ThreadItem::icon_visible(mut self, visible: bool) -> Self`
  - `ThreadItem::custom_icon_from_external_svg(mut self, svg: impl Into<SharedString>) -> Self`
  - `ThreadItem::notified(mut self, notified: bool) -> Self`
  - `ThreadItem::status(mut self, status: AgentThreadStatus) -> Self`
  - `ThreadItem::title_generating(mut self, generating: bool) -> Self`
  - `ThreadItem::title_label_color(mut self, color: Color) -> Self`
  - `ThreadItem::highlight_positions(mut self, positions: Vec<usize>) -> Self`
  - `ThreadItem::selected(mut self, selected: bool) -> Self`
  - `ThreadItem::focused(mut self, focused: bool) -> Self`
  - `ThreadItem::added(mut self, added: usize) -> Self`
  - `ThreadItem::removed(mut self, removed: usize) -> Self`
  - `ThreadItem::project_paths(mut self, paths: Arc<[PathBuf]>) -> Self`
  - `ThreadItem::project_name(mut self, name: impl Into<SharedString>) -> Self`
  - `ThreadItem::worktrees(mut self, worktrees: Vec<ThreadItemWorktreeInfo>) -> Self`
  - `ThreadItem::is_remote(mut self, is_remote: bool) -> Self`
  - `ThreadItem::archived(mut self, archived: bool) -> Self`
  - `ThreadItem::hovered(mut self, hovered: bool) -> Self`
  - `ThreadItem::rounded(mut self, rounded: bool) -> Self`
  - `ThreadItem::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ThreadItem::on_hover(mut self, on_hover: impl Fn(&bool, &mut Window, &mut App) + 'static) -> Self`
  - `ThreadItem::action_slot(mut self, element: impl IntoElement) -> Self`
  - `ThreadItem::base_bg(mut self, color: Hsla) -> Self`
- Public enum variantları: AgentThreadStatus: `Completed`, `Running`, `WaitingForConfirmation`, `Error`; WorktreeKind: `Main`, `Linked`

### `crates/ui/src/components/ai.rs`
- Öğeler: `use agent_setup_button::*`; `use ai_setting_item::*`; `use configured_api_card::*`; `use parallel_agents_illustration::*`; `use thread_item::*`

### `crates/ui/src/components/avatar.rs`
- Öğeler: `struct Avatar`; `enum AudioStatus`; `struct AvatarAudioStatusIndicator`; `enum CollaboratorAvailability`; `struct AvatarAvailabilityIndicator`
- Metotlar:
  - `Avatar::new(src: impl Into<ImageSource>) -> Self`
  - `Avatar::grayscale(mut self, grayscale: bool) -> Self`
  - `Avatar::border_color(mut self, color: impl Into<Hsla>) -> Self`
  - `Avatar::size<L: Into<AbsoluteLength>>(mut self, size: impl Into<Option<L>>) -> Self`
  - `Avatar::indicator<E: IntoElement>(mut self, indicator: impl Into<Option<E>>) -> Self`
  - `AvatarAudioStatusIndicator::new(audio_status: AudioStatus) -> Self`
  - `AvatarAudioStatusIndicator::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `AvatarAvailabilityIndicator::new(availability: CollaboratorAvailability) -> Self`
  - `AvatarAvailabilityIndicator::avatar_size(mut self, size: impl Into<Option<Pixels>>) -> Self`
- Public enum variantları: AudioStatus: `Muted`, `Deafened`; CollaboratorAvailability: `Free`, `Busy`

### `crates/ui/src/components/banner.rs`
- Öğeler: `struct Banner`
- Metotlar:
  - `Banner::new() -> Self`
  - `Banner::severity(mut self, severity: Severity) -> Self`
  - `Banner::action_slot(mut self, element: impl IntoElement) -> Self`
  - `Banner::wrap_content(mut self, wrap: bool) -> Self`

### `crates/ui/src/components/button/button.rs`
- Öğeler: `struct Button`
- Metotlar:
  - `Button::new(id: impl Into<ElementId>, label: impl Into<SharedString>) -> Self`
  - `Button::color(mut self, label_color: impl Into<Option<Color>>) -> Self`
  - `Button::label_size(mut self, label_size: impl Into<Option<LabelSize>>) -> Self`
  - `Button::selected_label<L: Into<SharedString>>(mut self, label: impl Into<Option<L>>) -> Self`
  - `Button::selected_label_color(mut self, color: impl Into<Option<Color>>) -> Self`
  - `Button::start_icon(mut self, icon: impl Into<Option<Icon>>) -> Self`
  - `Button::end_icon(mut self, icon: impl Into<Option<Icon>>) -> Self`
  - `Button::key_binding(mut self, key_binding: impl Into<Option<KeyBinding>>) -> Self`
  - `Button::key_binding_position(mut self, position: KeybindingPosition) -> Self`
  - `Button::alpha(mut self, alpha: f32) -> Self`
  - `Button::truncate(mut self, truncate: bool) -> Self`
  - `Button::loading(mut self, loading: bool) -> Self`

### `crates/ui/src/components/button/button_like.rs`
- Öğeler: `trait SelectableButton: Toggleable`; `trait ButtonCommon: Clickable + Disableable`; `enum IconPosition`; `enum KeybindingPosition`; `enum TintColor`; `enum ButtonStyle`; `enum ButtonSize`; `struct ButtonLike`
- Metotlar:
  - `ButtonSize::rems(self) -> Rems`
  - `ButtonLike::new(id: impl Into<ElementId>) -> Self`
  - `ButtonLike::new_rounded_left(id: impl Into<ElementId>) -> Self`
  - `ButtonLike::new_rounded_right(id: impl Into<ElementId>) -> Self`
  - `ButtonLike::new_rounded_all(id: impl Into<ElementId>) -> Self`
  - `ButtonLike::opacity(mut self, opacity: f32) -> Self`
  - `ButtonLike::height(mut self, height: DefiniteLength) -> Self`
  - `ButtonLike::on_right_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ButtonLike::hoverable_tooltip( mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static, ) -> Self`
- Trait metotları:
  - `trait SelectableButton::selected_style(self, style: ButtonStyle) -> Self`
  - `trait ButtonCommon::id(&self) -> &ElementId`
  - `trait ButtonCommon::style(self, style: ButtonStyle) -> Self`
  - `trait ButtonCommon::size(self, size: ButtonSize) -> Self`
  - `trait ButtonCommon::tooltip(self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `trait ButtonCommon::tab_index(self, tab_index: impl Into<isize>) -> Self`
  - `trait ButtonCommon::layer(self, elevation: ElevationIndex) -> Self`
  - `trait ButtonCommon::track_focus(self, focus_handle: &FocusHandle) -> Self`
- Public enum variantları: IconPosition: `Start`, `End`; KeybindingPosition: `Start`, `End`; TintColor: `Accent`, `Error`, `Warning`, `Success`; ButtonStyle: `Filled`, `Tinted`, `Outlined`, `OutlinedGhost`, `OutlinedCustom`, `Subtle`, `Transparent`; ButtonSize: `Large`, `Medium`, `Default`, `Compact`, `None`

### `crates/ui/src/components/button/button_link.rs`
- Öğeler: `struct ButtonLink`
- Metotlar:
  - `ButtonLink::new(label: impl Into<SharedString>, link: impl Into<String>) -> Self`
  - `ButtonLink::no_icon(mut self, no_icon: bool) -> Self`
  - `ButtonLink::label_size(mut self, label_size: LabelSize) -> Self`
  - `ButtonLink::label_color(mut self, label_color: Color) -> Self`

### `crates/ui/src/components/button/copy_button.rs`
- Öğeler: `struct CopyButton`
- Metotlar:
  - `CopyButton::new(id: impl Into<ElementId>, message: impl Into<SharedString>) -> Self`
  - `CopyButton::icon_size(mut self, icon_size: IconSize) -> Self`
  - `CopyButton::disabled(mut self, disabled: bool) -> Self`
  - `CopyButton::tooltip_label(mut self, tooltip_label: impl Into<SharedString>) -> Self`
  - `CopyButton::visible_on_hover(mut self, visible_on_hover: impl Into<SharedString>) -> Self`
  - `CopyButton::custom_on_click( mut self, custom_on_click: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`

### `crates/ui/src/components/button/icon_button.rs`
- Öğeler: `enum IconButtonShape`; `struct IconButton`
- Metotlar:
  - `IconButton::new(id: impl Into<ElementId>, icon: IconName) -> Self`
  - `IconButton::shape(mut self, shape: IconButtonShape) -> Self`
  - `IconButton::icon_size(mut self, icon_size: IconSize) -> Self`
  - `IconButton::icon_color(mut self, icon_color: Color) -> Self`
  - `IconButton::alpha(mut self, alpha: f32) -> Self`
  - `IconButton::selected_icon(mut self, icon: impl Into<Option<IconName>>) -> Self`
  - `IconButton::on_right_click( mut self, handler: impl Fn(&gpui::ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `IconButton::selected_icon_color(mut self, color: impl Into<Option<Color>>) -> Self`
  - `IconButton::indicator(mut self, indicator: Indicator) -> Self`
  - `IconButton::indicator_border_color(mut self, color: Option<Hsla>) -> Self`
- Public enum variantları: IconButtonShape: `Square`, `Wide`

### `crates/ui/src/components/button/split_button.rs`
- Öğeler: `enum SplitButtonStyle`; `enum SplitButtonKind`; `struct SplitButton`
- Metotlar:
  - `SplitButton::new(left: impl Into<SplitButtonKind>, right: AnyElement) -> Self`
  - `SplitButton::style(mut self, style: SplitButtonStyle) -> Self`
- Public enum variantları: SplitButtonStyle: `Filled`, `Outlined`, `Transparent`; SplitButtonKind: `ButtonLike`, `IconButton`

### `crates/ui/src/components/button/toggle_button.rs`
- Öğeler: `struct ToggleButtonPosition`; `struct ButtonConfiguration`; private/sealed `trait ToggleButtonStyle`; `trait ButtonBuilder: 'static + private::ToggleButtonStyle`; `struct ToggleButtonSimple`; `struct ToggleButtonWithIcon`; `enum ToggleButtonGroupStyle`; `enum ToggleButtonGroupSize`; `struct ToggleButtonGroup<T, const COLS: usize = 3, const ROWS: usize = 1> where T: ButtonBuilder,`
- Metotlar:
  - `ToggleButtonSimple::new( label: impl Into<SharedString>, on_click: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ToggleButtonSimple::selected(mut self, selected: bool) -> Self`
  - `ToggleButtonSimple::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `ToggleButtonWithIcon::new( label: impl Into<SharedString>, icon: IconName, on_click: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ToggleButtonWithIcon::selected(mut self, selected: bool) -> Self`
  - `ToggleButtonWithIcon::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `<T: ButtonBuilder, const COLS: usize> ToggleButtonGroup<T, COLS>::single_row(group_name: impl Into<SharedString>, buttons: [T; COLS]) -> Self`
  - `<T: ButtonBuilder, const COLS: usize> ToggleButtonGroup<T, COLS, 2>::two_rows( group_name: impl Into<SharedString>, first_row: [T; COLS], second_row: [T; COLS], ) -> Self`
  - `<T: ButtonBuilder, const COLS: usize, const ROWS: usize> ToggleButtonGroup<T, COLS, ROWS>::style(mut self, style: ToggleButtonGroupStyle) -> Self`
  - `<T: ButtonBuilder, const COLS: usize, const ROWS: usize> ToggleButtonGroup<T, COLS, ROWS>::size(mut self, size: ToggleButtonGroupSize) -> Self`
  - `<T: ButtonBuilder, const COLS: usize, const ROWS: usize> ToggleButtonGroup<T, COLS, ROWS>::selected_index(mut self, index: usize) -> Self`
  - `<T: ButtonBuilder, const COLS: usize, const ROWS: usize> ToggleButtonGroup<T, COLS, ROWS>::auto_width(mut self) -> Self`
  - `<T: ButtonBuilder, const COLS: usize, const ROWS: usize> ToggleButtonGroup<T, COLS, ROWS>::label_size(mut self, label_size: LabelSize) -> Self`
  - `<T: ButtonBuilder, const COLS: usize, const ROWS: usize> ToggleButtonGroup<T, COLS, ROWS>::tab_index(mut self, tab_index: &mut isize) -> Self`
- Trait metotları:
  - `trait ButtonBuilder::into_configuration(self) -> ButtonConfiguration`
- Public enum variantları: ToggleButtonGroupStyle: `Transparent`, `Filled`, `Outlined`; ToggleButtonGroupSize: `Default`, `Medium`, `Large`, `Custom`

### `crates/ui/src/components/button.rs`
- Öğeler: `use button::*`; `use button_like::*`; `use button_link::*`; `use copy_button::*`; `use icon_button::*`; `use split_button::*`; `use toggle_button::*`

### `crates/ui/src/components/callout.rs`
- Öğeler: `enum BorderPosition`; `struct Callout`
- Metotlar:
  - `Callout::new() -> Self`
  - `Callout::severity(mut self, severity: Severity) -> Self`
  - `Callout::icon(mut self, icon: IconName) -> Self`
  - `Callout::title(mut self, title: impl Into<SharedString>) -> Self`
  - `Callout::description(mut self, description: impl Into<SharedString>) -> Self`
  - `Callout::description_slot(mut self, description: impl IntoElement) -> Self`
  - `Callout::actions_slot(mut self, action: impl IntoElement) -> Self`
  - `Callout::dismiss_action(mut self, action: impl IntoElement) -> Self`
  - `Callout::line_height(mut self, line_height: Pixels) -> Self`
  - `Callout::border_position(mut self, border_position: BorderPosition) -> Self`
- Public enum variantları: BorderPosition: `Top`, `Bottom`

### `crates/ui/src/components/chip.rs`
- Öğeler: `struct Chip`
- Metotlar:
  - `Chip::new(label: impl Into<SharedString>) -> Self`
  - `Chip::label_color(mut self, color: Color) -> Self`
  - `Chip::label_size(mut self, size: LabelSize) -> Self`
  - `Chip::icon(mut self, icon: IconName) -> Self`
  - `Chip::icon_color(mut self, color: Color) -> Self`
  - `Chip::bg_color(mut self, color: Hsla) -> Self`
  - `Chip::border_color(mut self, color: Hsla) -> Self`
  - `Chip::height(mut self, height: Pixels) -> Self`
  - `Chip::truncate(mut self) -> Self`
  - `Chip::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`

### `crates/ui/src/components/collab/collab_notification.rs`
- Öğeler: `struct CollabNotification`
- Metotlar:
  - `CollabNotification::new( avatar_uri: impl Into<SharedUri>, accept_button: Button, dismiss_button: Button, ) -> Self`

### `crates/ui/src/components/collab/update_button.rs`
- Öğeler: `struct UpdateButton`
- Metotlar:
  - `UpdateButton::new(icon: IconName, message: impl Into<SharedString>) -> Self`
  - `UpdateButton::icon_animate(mut self, animate: bool) -> Self`
  - `UpdateButton::icon_color(mut self, color: impl Into<Option<Color>>) -> Self`
  - `UpdateButton::tooltip(mut self, tooltip: impl Into<SharedString>) -> Self`
  - `UpdateButton::with_dismiss(mut self) -> Self`
  - `UpdateButton::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `UpdateButton::on_dismiss( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `UpdateButton::checking() -> Self`
  - `UpdateButton::downloading(version: impl Into<SharedString>) -> Self`
  - `UpdateButton::installing(version: impl Into<SharedString>) -> Self`
  - `UpdateButton::updated(version: impl Into<SharedString>) -> Self`
  - `UpdateButton::errored(error: impl Into<SharedString>) -> Self`

### `crates/ui/src/components/collab.rs`
- Öğeler: `use collab_notification::*`; `use update_button::*`

### `crates/ui/src/components/context_menu.rs`
- Öğeler: `enum ContextMenuItem`; `struct ContextMenuEntry`; `struct ContextMenu`; `enum DocumentationSide`; `struct DocumentationAside`
- Metotlar:
  - `ContextMenuItem::custom_entry( entry_render: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, handler: impl Fn(&mut Window, &mut App) + 'static, documentation_aside: Option<DocumentationAside>, ) -> Self`
  - `ContextMenuEntry::new(label: impl Into<SharedString>) -> Self`
  - `ContextMenuEntry::toggleable(mut self, toggle_position: IconPosition, toggled: bool) -> Self`
  - `ContextMenuEntry::icon(mut self, icon: IconName) -> Self`
  - `ContextMenuEntry::custom_icon_path(mut self, path: impl Into<SharedString>) -> Self`
  - `ContextMenuEntry::custom_icon_svg(mut self, svg: impl Into<SharedString>) -> Self`
  - `ContextMenuEntry::icon_position(mut self, position: IconPosition) -> Self`
  - `ContextMenuEntry::icon_size(mut self, icon_size: IconSize) -> Self`
  - `ContextMenuEntry::icon_color(mut self, icon_color: Color) -> Self`
  - `ContextMenuEntry::toggle(mut self, toggle_position: IconPosition, toggled: bool) -> Self`
  - `ContextMenuEntry::action(mut self, action: Box<dyn Action>) -> Self`
  - `ContextMenuEntry::handler(mut self, handler: impl Fn(&mut Window, &mut App) + 'static) -> Self`
  - `ContextMenuEntry::secondary_handler(mut self, handler: impl Fn(&mut Window, &mut App) + 'static) -> Self`
  - `ContextMenuEntry::disabled(mut self, disabled: bool) -> Self`
  - `ContextMenuEntry::documentation_aside( mut self, side: DocumentationSide, render: impl Fn(&mut App) -> AnyElement + 'static, ) -> Self`
  - `DocumentationAside::new(side: DocumentationSide, render: Rc<dyn Fn(&mut App) -> AnyElement>) -> Self`
  - `ContextMenu::new( window: &mut Window, cx: &mut Context<Self>, f: impl FnOnce(Self, &mut Window, &mut Context<Self>) -> Self, ) -> Self`
  - `ContextMenu::build( window: &mut Window, cx: &mut App, f: impl FnOnce(Self, &mut Window, &mut Context<Self>) -> Self, ) -> Entity<Self>`
  - `ContextMenu::build_persistent( window: &mut Window, cx: &mut App, builder: impl Fn(Self, &mut Window, &mut Context<Self>) -> Self + 'static, ) -> Entity<Self>`
  - `ContextMenu::rebuild(&mut self, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::context(mut self, focus: FocusHandle) -> Self`
  - `ContextMenu::header(mut self, title: impl Into<SharedString>) -> Self`
  - `ContextMenu::header_with_link( mut self, title: impl Into<SharedString>, link_label: impl Into<SharedString>, link_url: impl Into<SharedString>, ) -> Self`
  - `ContextMenu::separator(mut self) -> Self`
  - `ContextMenu::extend<I: Into<ContextMenuItem>>(mut self, items: impl IntoIterator<Item = I>) -> Self`
  - `ContextMenu::item(mut self, item: impl Into<ContextMenuItem>) -> Self`
  - `ContextMenu::push_item(&mut self, item: impl Into<ContextMenuItem>)`
  - `ContextMenu::entry( mut self, label: impl Into<SharedString>, action: Option<Box<dyn Action>>, handler: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`
  - `ContextMenu::entry_with_end_slot( mut self, label: impl Into<SharedString>, action: Option<Box<dyn Action>>, handler: impl Fn(&mut Window, &mut App) + 'static, end_slot_icon: IconName, end_slot_title: SharedString, end_slot_handler: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`
  - `ContextMenu::entry_with_end_slot_on_hover( mut self, label: impl Into<SharedString>, action: Option<Box<dyn Action>>, handler: impl Fn(&mut Window, &mut App) + 'static, end_slot_icon: IconName, end_slot_title: SharedString, end_slot_handler: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`
  - `ContextMenu::toggleable_entry( mut self, label: impl Into<SharedString>, toggled: bool, position: IconPosition, action: Option<Box<dyn Action>>, handler: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`
  - `ContextMenu::custom_row( mut self, entry_render: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, ) -> Self`
  - `ContextMenu::custom_entry( mut self, entry_render: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, handler: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`
  - `ContextMenu::custom_entry_with_docs( mut self, entry_render: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, handler: impl Fn(&mut Window, &mut App) + 'static, documentation_aside: Option<DocumentationAside>, ) -> Self`
  - `ContextMenu::selectable(mut self, selectable: bool) -> Self`
  - `ContextMenu::label(mut self, label: impl Into<SharedString>) -> Self`
  - `ContextMenu::action(self, label: impl Into<SharedString>, action: Box<dyn Action>) -> Self`
  - `ContextMenu::action_checked( self, label: impl Into<SharedString>, action: Box<dyn Action>, checked: bool, ) -> Self`
  - `ContextMenu::action_checked_with_disabled( mut self, label: impl Into<SharedString>, action: Box<dyn Action>, checked: bool, disabled: bool, ) -> Self`
  - `ContextMenu::action_disabled_when( mut self, disabled: bool, label: impl Into<SharedString>, action: Box<dyn Action>, ) -> Self`
  - `ContextMenu::link(self, label: impl Into<SharedString>, action: Box<dyn Action>) -> Self`
  - `ContextMenu::link_with_handler( mut self, label: impl Into<SharedString>, action: Box<dyn Action>, handler: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`
  - `ContextMenu::submenu( mut self, label: impl Into<SharedString>, builder: impl Fn(ContextMenu, &mut Window, &mut Context<ContextMenu>) -> ContextMenu + 'static, ) -> Self`
  - `ContextMenu::submenu_with_icon( mut self, label: impl Into<SharedString>, icon: IconName, builder: impl Fn(ContextMenu, &mut Window, &mut Context<ContextMenu>) -> ContextMenu + 'static, ) -> Self`
  - `ContextMenu::submenu_with_colored_icon( mut self, label: impl Into<SharedString>, icon: IconName, icon_color: Color, builder: impl Fn(ContextMenu, &mut Window, &mut Context<ContextMenu>) -> ContextMenu + 'static, ) -> Self`
  - `ContextMenu::keep_open_on_confirm(mut self, keep_open: bool) -> Self`
  - `ContextMenu::trigger_end_slot_handler(&mut self, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::fixed_width(mut self, width: DefiniteLength) -> Self`
  - `ContextMenu::end_slot_action(mut self, action: Box<dyn Action>) -> Self`
  - `ContextMenu::key_context(mut self, context: impl Into<SharedString>) -> Self`
  - `ContextMenu::selected_index(&self) -> Option<usize>`
  - `ContextMenu::confirm(&mut self, _: &menu::Confirm, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::secondary_confirm( &mut self, _: &menu::SecondaryConfirm, window: &mut Window, cx: &mut Context<Self>, )`
  - `ContextMenu::cancel(&mut self, _: &menu::Cancel, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::end_slot(&mut self, _: &dyn Action, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::clear_selected(&mut self)`
  - `ContextMenu::select_first(&mut self, _: &SelectFirst, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::select_last(&mut self, window: &mut Window, cx: &mut Context<Self>) -> Option<usize>`
  - `ContextMenu::select_next(&mut self, _: &SelectNext, window: &mut Window, cx: &mut Context<Self>)`
  - `ContextMenu::select_previous( &mut self, _: &SelectPrevious, window: &mut Window, cx: &mut Context<Self>, )`
  - `ContextMenu::select_submenu_child( &mut self, _: &SelectChild, window: &mut Window, cx: &mut Context<Self>, )`
  - `ContextMenu::select_submenu_parent( &mut self, _: &SelectParent, window: &mut Window, cx: &mut Context<Self>, )`
  - `ContextMenu::on_action_dispatch( &mut self, dispatched: &dyn Action, window: &mut Window, cx: &mut Context<Self>, )`
  - `ContextMenu::on_blur_subscription(mut self, new_subscription: Subscription) -> Self`
- Public enum variantları: ContextMenuItem: `Separator`, `Header`, `HeaderWithLink`, `Label`, `Entry`, `CustomEntry`, `Submenu`; DocumentationSide: `Left`, `Right`

### `crates/ui/src/components/count_badge.rs`
- Öğeler: `struct CountBadge`
- Metotlar:
  - `CountBadge::new(count: usize) -> Self`

### `crates/ui/src/components/data_table/table_row.rs`
- Öğeler: `struct TableRow<T>(Vec<T>)`; `trait IntoTableRow<T>`
- Metotlar:
  - `<T> TableRow<T>::from_element(element: T, length: usize) -> Self where T: Clone,`
  - `<T> TableRow<T>::from_vec(data: Vec<T>, expected_length: usize) -> Self`
  - `<T> TableRow<T>::try_from_vec(data: Vec<T>, expected_len: usize) -> Result<Self, String>`
  - `<T> TableRow<T>::expect_get(&self, col: impl Into<usize>) -> &T`
  - `<T> TableRow<T>::get(&self, col: impl Into<usize>) -> Option<&T>`
  - `<T> TableRow<T>::as_slice(&self) -> &[T]`
  - `<T> TableRow<T>::into_vec(self) -> Vec<T>`
  - `<T> TableRow<T>::map_cloned<F, U>(&self, f: F) -> TableRow<U> where F: FnMut(T) -> U, T: Clone,`
  - `<T> TableRow<T>::map<F, U>(self, f: F) -> TableRow<U> where F: FnMut(T) -> U,`
  - `<T> TableRow<T>::map_ref<F, U>(&self, f: F) -> TableRow<U> where F: FnMut(&T) -> U,`
  - `<T> TableRow<T>::cols(&self) -> usize`
- Trait metotları:
  - `trait IntoTableRow::into_table_row(self, expected_length: usize) -> TableRow<T>`

### `crates/ui/src/components/data_table.rs`
- Öğeler: `pub mod table_row`; `type UncheckedTableRow<T> = Vec<T>`; `struct ResizableColumnsState`; `struct TableInteractionState`; `enum ColumnWidthConfig`; `enum StaticColumnWidths`; `struct Table`; `struct TableRenderContext`
- Fonksiyonlar:
  - `fn render_table_row( row_index: usize, items: TableRow<impl IntoElement>, table_context: TableRenderContext, window: &mut Window, cx: &mut App, ) -> AnyElement`
  - `fn render_table_header( headers: TableRow<impl IntoElement>, table_context: TableRenderContext, resize_info: Option<HeaderResizeInfo>, entity_id: Option<EntityId>, cx: &mut App, ) -> impl IntoElement`
- Metotlar:
  - `ResizableColumnsState::new( cols: usize, initial_widths: Vec<impl Into<AbsoluteLength>>, resize_behavior: Vec<TableResizeBehavior>, ) -> Self`
  - `ResizableColumnsState::cols(&self) -> usize`
  - `ResizableColumnsState::resize_behavior(&self) -> &TableRow<TableResizeBehavior>`
  - `ResizableColumnsState::set_column_configuration( &mut self, col_idx: usize, width: impl Into<AbsoluteLength>, resize_behavior: TableResizeBehavior, )`
  - `ResizableColumnsState::reset_column_to_initial_width(&mut self, col_idx: usize)`
  - `TableInteractionState::new(cx: &mut App) -> Self`
  - `TableInteractionState::with_custom_scrollbar(mut self, custom_scrollbar: Scrollbars) -> Self`
  - `TableInteractionState::scroll_offset(&self) -> Point<Pixels>`
  - `TableInteractionState::set_scroll_offset(&self, offset: Point<Pixels>)`
  - `TableInteractionState::listener<E: ?Sized>( this: &Entity<Self>, f: impl Fn(&mut Self, &E, &mut Window, &mut Context<Self>) + 'static, ) -> impl Fn(&E, &mut Window, &mut App) + 'static`
  - `ColumnWidthConfig::auto() -> Self`
  - `ColumnWidthConfig::redistributable(columns_state: Entity<RedistributableColumnsState>) -> Self`
  - `ColumnWidthConfig::auto_with_table_width(width: impl Into<DefiniteLength>) -> Self`
  - `ColumnWidthConfig::explicit<T: Into<DefiniteLength>>(widths: Vec<T>) -> Self`
  - `ColumnWidthConfig::widths_to_render(&self, cx: &App) -> Option<TableRow<Length>>`
  - `ColumnWidthConfig::table_width(&self, window: &Window, cx: &App) -> Option<Length>`
  - `ColumnWidthConfig::list_horizontal_sizing( &self, window: &Window, cx: &App, ) -> ListHorizontalSizingBehavior`
  - `Table::new(cols: usize) -> Self`
  - `Table::disable_base_style(mut self) -> Self`
  - `Table::uniform_list( mut self, id: impl Into<ElementId>, row_count: usize, render_item_fn: impl Fn( Range<usize>, &mut Window, &mut App, ) -> Vec<UncheckedTableRow<AnyElement>> + 'static, ) -> Self`
  - `Table::variable_row_height_list( mut self, row_count: usize, list_state: ListState, render_row_fn: impl Fn(usize, &mut Window, &mut App) -> UncheckedTableRow<AnyElement> + 'static, ) -> Self`
  - `Table::striped(mut self) -> Self`
  - `Table::hide_row_borders(mut self) -> Self`
  - `Table::width(mut self, width: impl Into<DefiniteLength>) -> Self`
  - `Table::width_config(mut self, config: ColumnWidthConfig) -> Self`
  - `Table::interactable(mut self, interaction_state: &Entity<TableInteractionState>) -> Self`
  - `Table::header(mut self, headers: UncheckedTableRow<impl IntoElement>) -> Self`
  - `Table::row(mut self, items: UncheckedTableRow<impl IntoElement>) -> Self`
  - `Table::no_ui_font(mut self) -> Self`
  - `Table::map_row( mut self, callback: impl Fn((usize, Stateful<Div>), &mut Window, &mut App) -> AnyElement + 'static, ) -> Self`
  - `Table::hide_row_hover(mut self) -> Self`
  - `Table::empty_table_callback( mut self, callback: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, ) -> Self`
  - `TableRenderContext::for_column_widths(column_widths: Option<TableRow<Length>>, use_ui_font: bool) -> Self`
- Public enum variantları: ColumnWidthConfig: `Static`, `Redistributable`, `Resizable`; StaticColumnWidths: `Auto`, `Explicit`

### `crates/ui/src/components/diff_stat.rs`
- Öğeler: `struct DiffStat`
- Metotlar:
  - `DiffStat::new(id: impl Into<ElementId>, added: usize, removed: usize) -> Self`
  - `DiffStat::label_size(mut self, label_size: LabelSize) -> Self`
  - `DiffStat::tooltip(mut self, tooltip: impl Into<SharedString>) -> Self`

### `crates/ui/src/components/disclosure.rs`
- Öğeler: `struct Disclosure`
- Metotlar:
  - `Disclosure::new(id: impl Into<ElementId>, is_open: bool) -> Self`
  - `Disclosure::on_toggle_expanded( mut self, handler: impl Into<Option<Arc<dyn Fn(&ClickEvent, &mut Window, &mut App) + 'static>>>, ) -> Self`
  - `Disclosure::opened_icon(mut self, icon: IconName) -> Self`
  - `Disclosure::closed_icon(mut self, icon: IconName) -> Self`
  - `Disclosure::disabled(mut self, disabled: bool) -> Self`

### `crates/ui/src/components/divider.rs`
- Öğeler: `enum DividerColor`; `struct Divider`
- Fonksiyonlar:
  - `fn divider() -> Divider`
  - `fn vertical_divider() -> Divider`
- Metotlar:
  - `DividerColor::hsla(self, cx: &mut App) -> Hsla`
  - `Divider::horizontal() -> Self`
  - `Divider::vertical() -> Self`
  - `Divider::horizontal_dashed() -> Self`
  - `Divider::vertical_dashed() -> Self`
  - `Divider::inset(mut self) -> Self`
  - `Divider::color(mut self, color: DividerColor) -> Self`
  - `Divider::render_solid(self, base: Div, cx: &mut App) -> impl IntoElement`
  - `Divider::render_dashed(self, base: Div) -> impl IntoElement`
- Public enum variantları: DividerColor: `Border`, `BorderFaded`, `BorderVariant`

### `crates/ui/src/components/dropdown_menu.rs`
- Öğeler: `enum DropdownStyle`; `struct DropdownMenu`
- Metotlar:
  - `DropdownMenu::new( id: impl Into<ElementId>, label: impl Into<SharedString>, menu: Entity<ContextMenu>, ) -> Self`
  - `DropdownMenu::new_with_element( id: impl Into<ElementId>, label: AnyElement, menu: Entity<ContextMenu>, ) -> Self`
  - `DropdownMenu::style(mut self, style: DropdownStyle) -> Self`
  - `DropdownMenu::trigger_size(mut self, size: ButtonSize) -> Self`
  - `DropdownMenu::trigger_tooltip( mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static, ) -> Self`
  - `DropdownMenu::trigger_icon(mut self, icon: IconName) -> Self`
  - `DropdownMenu::full_width(mut self, full_width: bool) -> Self`
  - `DropdownMenu::handle(mut self, handle: PopoverMenuHandle<ContextMenu>) -> Self`
  - `DropdownMenu::attach(mut self, attach: Anchor) -> Self`
  - `DropdownMenu::offset(mut self, offset: Point<Pixels>) -> Self`
  - `DropdownMenu::tab_index(mut self, arg: isize) -> Self`
  - `DropdownMenu::no_chevron(mut self) -> Self`
- Public enum variantları: DropdownStyle: `Solid`, `Outlined`, `Subtle`, `Ghost`

### `crates/ui/src/components/facepile.rs`
- Öğeler: `struct Facepile`; `const EXAMPLE_FACES: [&str; 6]`
- Metotlar:
  - `Facepile::empty() -> Self`
  - `Facepile::new(faces: SmallVec<[AnyElement; 2]>) -> Self`

### `crates/ui/src/components/gradient_fade.rs`
- Öğeler: `struct GradientFade`
- Metotlar:
  - `GradientFade::new(base_bg: Hsla, hover_bg: Hsla, active_bg: Hsla) -> Self`
  - `GradientFade::width(mut self, width: Pixels) -> Self`
  - `GradientFade::right(mut self, right: Pixels) -> Self`
  - `GradientFade::gradient_stop(mut self, stop: f32) -> Self`
  - `GradientFade::group_name(mut self, name: impl Into<SharedString>) -> Self`

### `crates/ui/src/components/group.rs`
- Fonksiyonlar:
  - `fn h_group_sm() -> Div`
  - `fn h_group() -> Div`
  - `fn h_group_lg() -> Div`
  - `fn h_group_xl() -> Div`
  - `fn v_group_sm() -> Div`
  - `fn v_group() -> Div`
  - `fn v_group_lg() -> Div`
  - `fn v_group_xl() -> Div`

### `crates/ui/src/components/icon/decorated_icon.rs`
- Öğeler: `struct DecoratedIcon`
- Metotlar:
  - `DecoratedIcon::new(icon: Icon, decoration: Option<IconDecoration>) -> Self`

### `crates/ui/src/components/icon/icon_decoration.rs`
- Öğeler: `enum KnockoutIconName`; `enum IconDecorationKind`; `struct IconDecoration`
- Metotlar:
  - `KnockoutIconName::path(&self) -> Arc<str>`
  - `IconDecoration::new(kind: IconDecorationKind, knockout_color: Hsla, cx: &App) -> Self`
  - `IconDecoration::kind(mut self, kind: IconDecorationKind) -> Self`
  - `IconDecoration::color(mut self, color: Hsla) -> Self`
  - `IconDecoration::knockout_color(mut self, color: Hsla) -> Self`
  - `IconDecoration::knockout_hover_color(mut self, color: Hsla) -> Self`
  - `IconDecoration::position(mut self, position: Point<Pixels>) -> Self`
  - `IconDecoration::size(mut self, size: Pixels) -> Self`
  - `IconDecoration::group_name(mut self, name: Option<SharedString>) -> Self`
- Public enum variantları: KnockoutIconName: `XFg`, `XBg`, `DotFg`, `DotBg`, `TriangleFg`, `TriangleBg`; IconDecorationKind: `X`, `Dot`, `Triangle`

### `crates/ui/src/components/icon.rs`
- Öğeler: `use decorated_icon::*`; `use icon_decoration::*`; `use icons::*`; `enum AnyIcon`; `enum IconSize`; `struct Icon`; `struct IconWithIndicator`
- Metotlar:
  - `AnyIcon::map(self, f: impl FnOnce(Icon) -> Icon) -> Self`
  - `IconSize::rems(self) -> Rems`
  - `IconSize::square_components(&self, window: &mut Window, cx: &mut App) -> (Pixels, Pixels)`
  - `IconSize::square(&self, window: &mut Window, cx: &mut App) -> Pixels`
  - `Icon::new(icon: IconName) -> Self`
  - `Icon::from_path(path: impl Into<SharedString>) -> Self`
  - `Icon::from_external_svg(svg: SharedString) -> Self`
  - `Icon::color(mut self, color: Color) -> Self`
  - `Icon::size(mut self, size: IconSize) -> Self`
  - `IconWithIndicator::new(icon: Icon, indicator: Option<Indicator>) -> Self`
  - `IconWithIndicator::indicator(mut self, indicator: Option<Indicator>) -> Self`
  - `IconWithIndicator::indicator_color(mut self, color: Color) -> Self`
  - `IconWithIndicator::indicator_border_color(mut self, color: Option<Hsla>) -> Self`
- Public enum variantları: AnyIcon: `Icon`, `AnimatedIcon`; IconSize: `Indicator`, `XSmall`, `Small`, `Medium`, `XLarge`, `Custom`

### `crates/ui/src/components/image.rs`
- Öğeler: `enum VectorName`; `struct Vector`
- Metotlar:
  - `VectorName::path(&self) -> Arc<str>`
  - `Vector::new(vector: VectorName, width: Rems, height: Rems) -> Self`
  - `Vector::square(vector: VectorName, size: Rems) -> Self`
  - `Vector::color(mut self, color: Color) -> Self`
  - `Vector::size(mut self, size: impl Into<Size<Rems>>) -> Self`
- Public enum variantları: VectorName: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`, `StudentStamp`, `ZedLogo`, `ZedXCopilot`

### `crates/ui/src/components/indent_guides.rs`
- Öğeler: `struct IndentGuideColors`; `struct IndentGuides`; `struct RenderIndentGuideParams`; `struct RenderedIndentGuide`; `struct IndentGuideLayout`
- Fonksiyonlar:
  - `fn indent_guides(indent_size: Pixels, colors: IndentGuideColors) -> IndentGuides`
- Metotlar:
  - `IndentGuideColors::panel(cx: &App) -> Self`
  - `IndentGuides::on_click( mut self, on_click: impl Fn(&IndentGuideLayout, &mut Window, &mut App) + 'static, ) -> Self`
  - `IndentGuides::with_compute_indents_fn<V: Render>( mut self, entity: Entity<V>, compute_indents_fn: impl Fn( &mut V, Range<usize>, &mut Window, &mut Context<V>, ) -> SmallVec<[usize; 64]> + 'static, ) -> Self`
  - `IndentGuides::with_render_fn<V: Render>( mut self, entity: Entity<V>, render_fn: impl Fn( &mut V, RenderIndentGuideParams, &mut Window, &mut App, ) -> SmallVec<[RenderedIndentGuide; 12]> + 'static, ) -> Self`

### `crates/ui/src/components/indicator.rs`
- Öğeler: `struct Indicator`
- Metotlar:
  - `Indicator::dot() -> Self`
  - `Indicator::bar() -> Self`
  - `Indicator::icon(icon: impl Into<AnyIcon>) -> Self`
  - `Indicator::color(mut self, color: Color) -> Self`
  - `Indicator::border_color(mut self, color: Color) -> Self`

### `crates/ui/src/components/keybinding.rs`
- Öğeler: `struct KeyBinding`; `struct Key`; `struct KeyIcon`
- Fonksiyonlar:
  - `fn render_keybinding_keystroke( keystroke: &KeybindingKeystroke, color: Option<Color>, size: impl Into<Option<AbsoluteLength>>, platform_style: PlatformStyle, vim_mode: bool, ) -> Vec<AnyElement>`
  - `fn render_modifiers( modifiers: &Modifiers, platform_style: PlatformStyle, color: Option<Color>, size: Option<AbsoluteLength>, trailing_separator: bool, ) -> impl Iterator<Item = AnyElement>`
  - `fn text_for_action(action: &dyn Action, window: &Window, cx: &App) -> Option<String>`
  - `fn text_for_keystrokes(keystrokes: &[Keystroke], cx: &App) -> String`
  - `fn text_for_keybinding_keystrokes(keystrokes: &[KeybindingKeystroke], cx: &App) -> String`
  - `fn text_for_keystroke(modifiers: &Modifiers, key: &str, cx: &App) -> String`
- Metotlar:
  - `KeyBinding::for_action(action: &dyn Action, cx: &App) -> Self`
  - `KeyBinding::for_action_in(action: &dyn Action, focus: &FocusHandle, cx: &App) -> Self`
  - `KeyBinding::has_binding(&self, window: &Window) -> bool`
  - `KeyBinding::set_vim_mode(cx: &mut App, enabled: bool)`
  - `KeyBinding::new(action: &dyn Action, focus_handle: Option<FocusHandle>, cx: &App) -> Self`
  - `KeyBinding::from_keystrokes(keystrokes: Rc<[KeybindingKeystroke]>, vim_mode: bool) -> Self`
  - `KeyBinding::platform_style(mut self, platform_style: PlatformStyle) -> Self`
  - `KeyBinding::size(mut self, size: impl Into<AbsoluteLength>) -> Self`
  - `KeyBinding::disabled(mut self, disabled: bool) -> Self`
  - `Key::new(key: impl Into<SharedString>, color: Option<Color>) -> Self`
  - `Key::size(mut self, size: impl Into<Option<AbsoluteLength>>) -> Self`
  - `KeyIcon::new(icon: IconName, color: Option<Color>) -> Self`
  - `KeyIcon::size(mut self, size: impl Into<Option<AbsoluteLength>>) -> Self`

### `crates/ui/src/components/keybinding_hint.rs`
- Öğeler: `struct KeybindingHint`
- Metotlar:
  - `KeybindingHint::new(keybinding: KeyBinding, background_color: Hsla) -> Self`
  - `KeybindingHint::with_prefix( prefix: impl Into<SharedString>, keybinding: KeyBinding, background_color: Hsla, ) -> Self`
  - `KeybindingHint::with_suffix( keybinding: KeyBinding, suffix: impl Into<SharedString>, background_color: Hsla, ) -> Self`
  - `KeybindingHint::prefix(mut self, prefix: impl Into<SharedString>) -> Self`
  - `KeybindingHint::suffix(mut self, suffix: impl Into<SharedString>) -> Self`
  - `KeybindingHint::size(mut self, size: impl Into<Option<Pixels>>) -> Self`

### `crates/ui/src/components/label/highlighted_label.rs`
- Öğeler: `struct HighlightedLabel`
- Fonksiyonlar:
  - `fn highlight_ranges( text: &str, indices: &[usize], style: HighlightStyle, ) -> Vec<(Range<usize>, HighlightStyle)>`
- Metotlar:
  - `HighlightedLabel::new(label: impl Into<SharedString>, highlight_indices: Vec<usize>) -> Self`
  - `HighlightedLabel::from_ranges( label: impl Into<SharedString>, highlight_ranges: Vec<Range<usize>>, ) -> Self`
  - `HighlightedLabel::text(&self) -> &str`
  - `HighlightedLabel::highlight_indices(&self) -> &[usize]`
  - `HighlightedLabel::flex_1(mut self) -> Self`
  - `HighlightedLabel::flex_none(mut self) -> Self`
  - `HighlightedLabel::flex_grow(mut self) -> Self`
  - `HighlightedLabel::flex_shrink(mut self) -> Self`
  - `HighlightedLabel::flex_shrink_0(mut self) -> Self`

### `crates/ui/src/components/label/label.rs`
- Öğeler: `struct Label`
- Metotlar:
  - `Label::new(label: impl Into<SharedString>) -> Self`
  - `Label::render_code_spans(mut self) -> Self`
  - `Label::set_text(&mut self, text: impl Into<SharedString>)`
  - `Label::truncate_start(mut self) -> Self`
  - `Label::flex_1(mut self) -> Self`
  - `Label::flex_none(mut self) -> Self`
  - `Label::flex_grow(mut self) -> Self`
  - `Label::flex_shrink(mut self) -> Self`
  - `Label::flex_shrink_0(mut self) -> Self`

### `crates/ui/src/components/label/label_like.rs`
- Öğeler: `enum LabelSize`; `enum LineHeightStyle`; `trait LabelCommon`; `struct LabelLike`
- Metotlar:
  - `LabelLike::new() -> Self`
  - `LabelLike::truncate_start(mut self) -> Self`
- Trait metotları:
  - `trait LabelCommon::size(self, size: LabelSize) -> Self`
  - `trait LabelCommon::weight(self, weight: FontWeight) -> Self`
  - `trait LabelCommon::line_height_style(self, line_height_style: LineHeightStyle) -> Self`
  - `trait LabelCommon::color(self, color: Color) -> Self`
  - `trait LabelCommon::strikethrough(self) -> Self`
  - `trait LabelCommon::italic(self) -> Self`
  - `trait LabelCommon::underline(self) -> Self`
  - `trait LabelCommon::alpha(self, alpha: f32) -> Self`
  - `trait LabelCommon::truncate(self) -> Self`
  - `trait LabelCommon::single_line(self) -> Self`
  - `trait LabelCommon::buffer_font(self, cx: &App) -> Self`
  - `trait LabelCommon::inline_code(self, cx: &App) -> Self`
- Public enum variantları: LabelSize: `Default`, `Large`, `Small`, `XSmall`, `Custom`; LineHeightStyle: `TextLabel`, `UiLabel`

### `crates/ui/src/components/label/loading_label.rs`
- Öğeler: `struct LoadingLabel`
- Metotlar:
  - `LoadingLabel::new(text: impl Into<SharedString>) -> Self`

### `crates/ui/src/components/label/spinner_label.rs`
- Öğeler: `enum SpinnerVariant`; `struct SpinnerLabel`
- Metotlar:
  - `SpinnerLabel::new() -> Self`
  - `SpinnerLabel::with_variant(variant: SpinnerVariant) -> Self`
  - `SpinnerLabel::dots() -> Self`
  - `SpinnerLabel::dots_variant() -> Self`
  - `SpinnerLabel::sand() -> Self`
- Public enum variantları: SpinnerVariant: `Dots`, `DotsVariant`, `Sand`

### `crates/ui/src/components/label.rs`
- Öğeler: `use highlighted_label::*`; `use label::*`; `use label_like::*`; `use loading_label::*`; `use spinner_label::*`

### `crates/ui/src/components/list/list.rs`
- Öğeler: `enum EmptyMessage`; `struct List`
- Metotlar:
  - `List::new() -> Self`
  - `List::empty_message(mut self, message: impl Into<EmptyMessage>) -> Self`
  - `List::header(mut self, header: impl Into<Option<ListHeader>>) -> Self`
  - `List::toggle(mut self, toggle: impl Into<Option<bool>>) -> Self`
- Public enum variantları: EmptyMessage: `Text`, `Element`

### `crates/ui/src/components/list/list_bullet_item.rs`
- Öğeler: `struct ListBulletItem`
- Metotlar:
  - `ListBulletItem::new(label: impl Into<SharedString>) -> Self`
  - `ListBulletItem::label_color(mut self, color: Color) -> Self`

### `crates/ui/src/components/list/list_header.rs`
- Öğeler: `struct ListHeader`
- Metotlar:
  - `ListHeader::new(label: impl Into<SharedString>) -> Self`
  - `ListHeader::toggle(mut self, toggle: impl Into<Option<bool>>) -> Self`
  - `ListHeader::on_toggle( mut self, on_toggle: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ListHeader::start_slot<E: IntoElement>(mut self, start_slot: impl Into<Option<E>>) -> Self`
  - `ListHeader::end_slot<E: IntoElement>(mut self, end_slot: impl Into<Option<E>>) -> Self`
  - `ListHeader::end_hover_slot<E: IntoElement>(mut self, end_hover_slot: impl Into<Option<E>>) -> Self`
  - `ListHeader::inset(mut self, inset: bool) -> Self`

### `crates/ui/src/components/list/list_item.rs`
- Öğeler: `enum ListItemSpacing`; `struct ListItem`
- Metotlar:
  - `ListItem::new(id: impl Into<ElementId>) -> Self`
  - `ListItem::group_name(mut self, group_name: impl Into<SharedString>) -> Self`
  - `ListItem::spacing(mut self, spacing: ListItemSpacing) -> Self`
  - `ListItem::selectable(mut self, has_hover: bool) -> Self`
  - `ListItem::always_show_disclosure_icon(mut self, show: bool) -> Self`
  - `ListItem::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ListItem::on_hover(mut self, handler: impl Fn(&bool, &mut Window, &mut App) + 'static) -> Self`
  - `ListItem::on_secondary_mouse_down( mut self, handler: impl Fn(&MouseDownEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ListItem::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `ListItem::inset(mut self, inset: bool) -> Self`
  - `ListItem::indent_level(mut self, indent_level: usize) -> Self`
  - `ListItem::indent_step_size(mut self, indent_step_size: Pixels) -> Self`
  - `ListItem::toggle(mut self, toggle: impl Into<Option<bool>>) -> Self`
  - `ListItem::on_toggle( mut self, on_toggle: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ListItem::start_slot<E: IntoElement>(mut self, start_slot: impl Into<Option<E>>) -> Self`
  - `ListItem::end_slot<E: IntoElement>(mut self, end_slot: impl Into<Option<E>>) -> Self`
  - `ListItem::end_slot_on_hover<E: IntoElement>(mut self, end_slot_on_hover: E) -> Self`
  - `ListItem::show_end_slot_on_hover(mut self) -> Self`
  - `ListItem::outlined(mut self) -> Self`
  - `ListItem::rounded(mut self) -> Self`
  - `ListItem::overflow_x(mut self) -> Self`
  - `ListItem::focused(mut self, focused: bool) -> Self`
  - `ListItem::docked_right(mut self, docked_right: bool) -> Self`
  - `ListItem::height(mut self, height: impl Into<DefiniteLength>) -> Self`
- Public enum variantları: ListItemSpacing: `Dense`, `ExtraDense`, `Sparse`

### `crates/ui/src/components/list/list_separator.rs`
- Öğeler: `struct ListSeparator`

### `crates/ui/src/components/list/list_sub_header.rs`
- Öğeler: `struct ListSubHeader`
- Metotlar:
  - `ListSubHeader::new(label: impl Into<SharedString>) -> Self`
  - `ListSubHeader::left_icon(mut self, left_icon: Option<IconName>) -> Self`
  - `ListSubHeader::end_slot(mut self, end_slot: AnyElement) -> Self`
  - `ListSubHeader::inset(mut self, inset: bool) -> Self`

### `crates/ui/src/components/list.rs`
- Öğeler: `use list::*`; `use list_bullet_item::*`; `use list_header::*`; `use list_item::*`; `use list_separator::*`; `use list_sub_header::*`

### `crates/ui/src/components/modal.rs`
- Öğeler: `struct Modal`; `struct ModalHeader`; `struct ModalRow`; `struct ModalFooter`; `struct Section`; `struct SectionHeader`
- Metotlar:
  - `Modal::new(id: impl Into<SharedString>, scroll_handle: Option<ScrollHandle>) -> Self`
  - `Modal::header(mut self, header: ModalHeader) -> Self`
  - `Modal::section(mut self, section: Section) -> Self`
  - `Modal::footer(mut self, footer: ModalFooter) -> Self`
  - `Modal::show_dismiss(mut self, show: bool) -> Self`
  - `Modal::show_back(mut self, show: bool) -> Self`
  - `ModalHeader::new() -> Self`
  - `ModalHeader::icon(mut self, icon: Icon) -> Self`
  - `ModalHeader::headline(mut self, headline: impl Into<SharedString>) -> Self`
  - `ModalHeader::description(mut self, description: impl Into<SharedString>) -> Self`
  - `ModalHeader::show_dismiss_button(mut self, show: bool) -> Self`
  - `ModalHeader::show_back_button(mut self, show: bool) -> Self`
  - `ModalRow::new() -> Self`
  - `ModalFooter::new() -> Self`
  - `ModalFooter::start_slot<E: IntoElement>(mut self, start_slot: impl Into<Option<E>>) -> Self`
  - `ModalFooter::end_slot<E: IntoElement>(mut self, end_slot: impl Into<Option<E>>) -> Self`
  - `Section::new() -> Self`
  - `Section::new_contained() -> Self`
  - `Section::contained(mut self, contained: bool) -> Self`
  - `Section::header(mut self, header: SectionHeader) -> Self`
  - `Section::meta(mut self, meta: impl Into<SharedString>) -> Self`
  - `Section::padded(mut self, padded: bool) -> Self`
  - `SectionHeader::new(label: impl Into<SharedString>) -> Self`
  - `SectionHeader::end_slot<E: IntoElement>(mut self, end_slot: impl Into<Option<E>>) -> Self`

### `crates/ui/src/components/navigable.rs`
- Öğeler: `struct Navigable`; `struct NavigableEntry`
- Metotlar:
  - `NavigableEntry::new(scroll_handle: &ScrollHandle, cx: &App) -> Self`
  - `NavigableEntry::focusable(cx: &App) -> Self`
  - `Navigable::new(child: AnyElement) -> Self`
  - `Navigable::entry(mut self, child: NavigableEntry) -> Self`

### `crates/ui/src/components/notification/alert_modal.rs`
- Öğeler: `struct AlertModal`
- Metotlar:
  - `AlertModal::new(id: impl Into<ElementId>) -> Self`
  - `AlertModal::title(mut self, title: impl Into<SharedString>) -> Self`
  - `AlertModal::header(mut self, header: impl IntoElement) -> Self`
  - `AlertModal::footer(mut self, footer: impl IntoElement) -> Self`
  - `AlertModal::primary_action(mut self, primary_action: impl Into<SharedString>) -> Self`
  - `AlertModal::dismiss_label(mut self, dismiss_label: impl Into<SharedString>) -> Self`
  - `AlertModal::width(mut self, width: impl Into<DefiniteLength>) -> Self`
  - `AlertModal::key_context(mut self, key_context: impl Into<String>) -> Self`
  - `AlertModal::on_action<A: Action>( mut self, listener: impl Fn(&A, &mut Window, &mut App) + 'static, ) -> Self`
  - `AlertModal::track_focus(mut self, focus_handle: &gpui::FocusHandle) -> Self`

### `crates/ui/src/components/notification/announcement_toast.rs`
- Öğeler: `struct AnnouncementToast`
- Metotlar:
  - `AnnouncementToast::new() -> Self`
  - `AnnouncementToast::illustration(mut self, illustration: impl IntoElement) -> Self`
  - `AnnouncementToast::heading(mut self, heading: impl Into<SharedString>) -> Self`
  - `AnnouncementToast::description(mut self, description: impl Into<SharedString>) -> Self`
  - `AnnouncementToast::bullet_item(mut self, item: impl IntoElement) -> Self`
  - `AnnouncementToast::bullet_items(mut self, items: impl IntoIterator<Item = impl IntoElement>) -> Self`
  - `AnnouncementToast::primary_action_label(mut self, primary_action_label: impl Into<SharedString>) -> Self`
  - `AnnouncementToast::primary_on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `AnnouncementToast::secondary_action_label( mut self, secondary_action_label: impl Into<SharedString>, ) -> Self`
  - `AnnouncementToast::secondary_on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `AnnouncementToast::dismiss_on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`

### `crates/ui/src/components/notification.rs`
- Öğeler: `use alert_modal::*`; `use announcement_toast::*`

### `crates/ui/src/components/popover.rs`
- Öğeler: `const POPOVER_Y_PADDING: Pixels = px(8.)`; `struct Popover`
- Metotlar:
  - `Popover::new() -> Self`
  - `Popover::aside(mut self, aside: impl IntoElement) -> Self where Self: Sized,`

### `crates/ui/src/components/popover_menu.rs`
- Öğeler: `trait PopoverTrigger: IntoElement + Clickable + Toggleable + 'static`; `struct PopoverMenuHandle<M>(Rc<RefCell<Option<PopoverMenuHandleState<M>>>>)`; `struct PopoverMenu<M: ManagedView>`; `struct PopoverMenuElementState<M>`; `struct PopoverMenuFrameState<M: ManagedView>`
- Metotlar:
  - `<M: ManagedView> PopoverMenuHandle<M>::show(&self, window: &mut Window, cx: &mut App)`
  - `<M: ManagedView> PopoverMenuHandle<M>::hide(&self, cx: &mut App)`
  - `<M: ManagedView> PopoverMenuHandle<M>::toggle(&self, window: &mut Window, cx: &mut App)`
  - `<M: ManagedView> PopoverMenuHandle<M>::is_deployed(&self) -> bool`
  - `<M: ManagedView> PopoverMenuHandle<M>::is_focused(&self, window: &Window, cx: &App) -> bool`
  - `<M: ManagedView> PopoverMenuHandle<M>::refresh_menu( &self, window: &mut Window, cx: &mut App, new_menu_builder: Rc<dyn Fn(&mut Window, &mut App) -> Option<Entity<M>>>, )`
  - `<M: ManagedView> PopoverMenu<M>::new(id: impl Into<ElementId>) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::full_width(mut self, full_width: bool) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::menu( mut self, f: impl Fn(&mut Window, &mut App) -> Option<Entity<M>> + 'static, ) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::with_handle(mut self, handle: PopoverMenuHandle<M>) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::trigger<T: PopoverTrigger>(mut self, t: T) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::trigger_with_tooltip<T: PopoverTrigger + ButtonCommon>( mut self, t: T, tooltip_builder: impl Fn(&mut Window, &mut App) -> AnyView + 'static, ) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::anchor(mut self, anchor: Anchor) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::attach(mut self, attach: Anchor) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::offset(mut self, offset: Point<Pixels>) -> Self`
  - `<M: ManagedView> PopoverMenu<M>::on_open(mut self, on_open: Rc<dyn Fn(&mut Window, &mut App)>) -> Self`

### `crates/ui/src/components/progress/circular_progress.rs`
- Öğeler: `struct CircularProgress`
- Metotlar:
  - `CircularProgress::new(value: f32, max_value: f32, size: Pixels, cx: &App) -> Self`
  - `CircularProgress::value(mut self, value: f32) -> Self`
  - `CircularProgress::max_value(mut self, max_value: f32) -> Self`
  - `CircularProgress::size(mut self, size: Pixels) -> Self`
  - `CircularProgress::stroke_width(mut self, stroke_width: Pixels) -> Self`
  - `CircularProgress::bg_color(mut self, color: Hsla) -> Self`
  - `CircularProgress::progress_color(mut self, color: Hsla) -> Self`

### `crates/ui/src/components/progress/progress_bar.rs`
- Öğeler: `struct ProgressBar`
- Metotlar:
  - `ProgressBar::new(id: impl Into<ElementId>, value: f32, max_value: f32, cx: &App) -> Self`
  - `ProgressBar::value(mut self, value: f32) -> Self`
  - `ProgressBar::max_value(mut self, max_value: f32) -> Self`
  - `ProgressBar::bg_color(mut self, color: Hsla) -> Self`
  - `ProgressBar::fg_color(mut self, color: Hsla) -> Self`
  - `ProgressBar::over_color(mut self, color: Hsla) -> Self`

### `crates/ui/src/components/progress.rs`
- Öğeler: `use circular_progress::*`; `use progress_bar::*`

### `crates/ui/src/components/redistributable_columns.rs`
- Öğeler: `enum TableResizeBehavior`; `struct HeaderResizeInfo`; `struct RedistributableColumnsState`
- Fonksiyonlar:
  - `fn bind_redistributable_columns( container: Div, columns_state: Entity<RedistributableColumnsState>, ) -> Div`
  - `fn render_redistributable_columns_resize_handles( columns_state: &Entity<RedistributableColumnsState>, window: &mut Window, cx: &mut App, ) -> AnyElement`
- Metotlar:
  - `TableResizeBehavior::is_resizable(&self) -> bool`
  - `TableResizeBehavior::min_size(&self) -> Option<f32>`
  - `HeaderResizeInfo::from_redistributable( columns_state: &Entity<RedistributableColumnsState>, cx: &App, ) -> Self`
  - `HeaderResizeInfo::from_resizable(columns_state: &Entity<ResizableColumnsState>, cx: &App) -> Self`
  - `HeaderResizeInfo::reset_column(&self, col_idx: usize, window: &mut Window, cx: &mut App)`
  - `RedistributableColumnsState::new( cols: usize, initial_widths: Vec<impl Into<DefiniteLength>>, resize_behavior: Vec<TableResizeBehavior>, ) -> Self`
  - `RedistributableColumnsState::cols(&self) -> usize`
  - `RedistributableColumnsState::initial_widths(&self) -> &TableRow<DefiniteLength>`
  - `RedistributableColumnsState::preview_widths(&self) -> &TableRow<DefiniteLength>`
  - `RedistributableColumnsState::resize_behavior(&self) -> &TableRow<TableResizeBehavior>`
  - `RedistributableColumnsState::widths_to_render(&self) -> TableRow<Length>`
  - `RedistributableColumnsState::preview_fractions(&self, rem_size: Pixels) -> TableRow<f32>`
  - `RedistributableColumnsState::preview_column_width(&self, column_index: usize, window: &Window) -> Option<Pixels>`
  - `RedistributableColumnsState::cached_container_width(&self) -> Pixels`
  - `RedistributableColumnsState::set_cached_container_width(&mut self, width: Pixels)`
  - `RedistributableColumnsState::commit_preview(&mut self)`
  - `RedistributableColumnsState::reset_column_to_initial_width(&mut self, column_index: usize, window: &Window)`
- Public enum variantları: TableResizeBehavior: `None`, `Resizable`, `MinSize`

### `crates/ui/src/components/right_click_menu.rs`
- Öğeler: `struct RightClickMenu<M: ManagedView>`; `struct MenuHandleElementState<M>`; `struct RequestLayoutState`; `struct PrepaintState`
- Fonksiyonlar:
  - `fn right_click_menu<M: ManagedView>(id: impl Into<ElementId>) -> RightClickMenu<M>`
- Metotlar:
  - `<M: ManagedView> RightClickMenu<M>::menu(mut self, f: impl Fn(&mut Window, &mut App) -> Entity<M> + 'static) -> Self`
  - `<M: ManagedView> RightClickMenu<M>::trigger<F, E>(mut self, e: F) -> Self where F: FnOnce(bool, &mut Window, &mut App) -> E + 'static, E: IntoElement + 'static,`
  - `<M: ManagedView> RightClickMenu<M>::anchor(mut self, anchor: Anchor) -> Self`
  - `<M: ManagedView> RightClickMenu<M>::attach(mut self, attach: Anchor) -> Self`

### `crates/ui/src/components/scrollbar.rs`
- Öğeler: `const EDITOR_SCROLLBAR_WIDTH: Pixels = ScrollbarStyle::Editor.to_pixels()`; `pub mod scrollbars::{ShowScrollbar, ScrollbarVisibility, ScrollbarAutoHide}`; `trait WithScrollbar: Sized`; `enum ScrollAxes`; `enum ScrollbarStyle`; `struct Scrollbars<T: ScrollableHandle = ScrollHandle>`; `trait ScrollableHandle: 'static + Any + Sized + Clone`; `struct ScrollbarPrepaintState`
- Fonksiyonlar:
  - `fn on_new_scrollbars<T: gpui::Global>(cx: &mut App)`
- Metotlar:
  - `ScrollbarAutoHide::should_hide(&self) -> bool`
  - `ScrollbarStyle::to_pixels(&self) -> Pixels` (`pub const fn`; sabit
    bağlamda da çağrılabilir, `EDITOR_SCROLLBAR_WIDTH` bunu kullanır)
  - `Scrollbars::new(show_along: ScrollAxes) -> Self`
  - `Scrollbars::always_visible(show_along: ScrollAxes) -> Self`
  - `Scrollbars::for_settings<S: ScrollbarVisibility + Default>() -> Scrollbars`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::id(mut self, id: impl Into<ElementId>) -> Self`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::notify_content(mut self) -> Self`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::tracked_entity(mut self, entity_id: EntityId) -> Self`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::tracked_scroll_handle<TrackedHandle: ScrollableHandle>( self, tracked_scroll_handle: &TrackedHandle, ) -> Scrollbars<TrackedHandle>`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::show_along(mut self, along: ScrollAxes) -> Self`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::style(mut self, style: ScrollbarStyle) -> Self`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::with_track_along(mut self, along: ScrollAxes, background_color: Hsla) -> Self`
  - `<ScrollHandle: ScrollableHandle> Scrollbars<ScrollHandle>::with_stable_track_along(mut self, along: ScrollAxes, background_color: Hsla) -> Self`
- Trait metotları:
  - `trait ScrollbarVisibility::visibility(&self, cx: &App) -> ShowScrollbar`
  - `trait WithScrollbar::custom_scrollbars<T>( self, config: Scrollbars<T>, window: &mut Window, cx: &mut App, ) -> Self::Output where T: ScrollableHandle`
  - `trait WithScrollbar::vertical_scrollbar_for<ScrollHandle: ScrollableHandle + Clone>( self, scroll_handle: &ScrollHandle, window: &mut Window, cx: &mut App, ) -> Self::Output`
  - `trait ScrollableHandle::max_offset(&self) -> Point<Pixels>`
  - `trait ScrollableHandle::set_offset(&self, point: Point<Pixels>)`
  - `trait ScrollableHandle::offset(&self) -> Point<Pixels>`
  - `trait ScrollableHandle::viewport(&self) -> Bounds<Pixels>`
  - `trait ScrollableHandle::drag_started(&self)`
  - `trait ScrollableHandle::drag_ended(&self)`
  - `trait ScrollableHandle::scrollable_along(&self, axis: ScrollbarAxis) -> bool`
  - `trait ScrollableHandle::content_size(&self) -> Size<Pixels>`
- Public enum variantları: ScrollAxes: `Horizontal`, `Vertical`, `Both`; ScrollbarStyle: `Regular`, `Editor`

### `crates/ui/src/components/stack.rs`
- Fonksiyonlar:
  - `fn h_flex() -> Div`
  - `fn v_flex() -> Div`

### `crates/ui/src/components/sticky_items.rs`
- Öğeler: `trait StickyCandidate`; `struct StickyItems<T>`; `trait StickyItemsDecoration`
- Fonksiyonlar:
  - `fn sticky_items<V, T>( entity: Entity<V>, compute_fn: impl Fn(&mut V, Range<usize>, &mut Window, &mut Context<V>) -> SmallVec<[T; 8]> + 'static, render_fn: impl Fn(&mut V, T, &mut Window, &mut Context<V>) -> SmallVec<[AnyElement; 8]> + 'static, ) -> StickyItems<T> where V: Render, T: StickyCandidate + Clone + 'static`
- Metotlar:
  - `<T: StickyCandidate + Clone + 'static> StickyItems<T>::with_decoration(mut self, decoration: impl StickyItemsDecoration + 'static) -> Self`
- Trait metotları:
  - `trait StickyCandidate::depth(&self) -> usize`
  - `trait StickyItemsDecoration::compute( &self, indents: &SmallVec<[usize; 8]>, bounds: Bounds<Pixels>, scroll_offset: Point<Pixels>, item_height: Pixels, window: &mut Window, cx: &mut App, ) -> AnyElement`

### `crates/ui/src/components/stories.rs`
- Bu dosya `crates/ui/src/components.rs` içinde `mod stories;` ile dahil
  edilmediği için public build chain'inin parçası değildir. Kaynakta
  `mod context_menu; pub use context_menu::*;` satırları görünür ama `stories`
  modülü `ui` crate'inden erişilebilir değildir. Tüketici API'si açısından
  yok sayılır.

### `crates/ui/src/components/tab.rs`
- Öğeler: `enum TabPosition`; `enum TabCloseSide`; `struct Tab`
- Metotlar:
  - `Tab::new(id: impl Into<ElementId>) -> Self`
  - `Tab::position(mut self, position: TabPosition) -> Self`
  - `Tab::close_side(mut self, close_side: TabCloseSide) -> Self`
  - `Tab::start_slot<E: IntoElement>(mut self, element: impl Into<Option<E>>) -> Self`
  - `Tab::end_slot<E: IntoElement>(mut self, element: impl Into<Option<E>>) -> Self`
  - `Tab::content_height(cx: &App) -> Pixels`
  - `Tab::container_height(cx: &App) -> Pixels`
- Public enum variantları: TabPosition: `First`, `Middle`, `Last`; TabCloseSide: `Start`, `End`

### `crates/ui/src/components/tab_bar.rs`
- Öğeler: `struct TabBar`
- Metotlar:
  - `TabBar::new(id: impl Into<ElementId>) -> Self`
  - `TabBar::track_scroll(mut self, scroll_handle: &ScrollHandle) -> Self`
  - `TabBar::start_children_mut(&mut self) -> &mut SmallVec<[AnyElement; 2]>`
  - `TabBar::start_child(mut self, start_child: impl IntoElement) -> Self where Self: Sized,`
  - `TabBar::start_children( mut self, start_children: impl IntoIterator<Item = impl IntoElement>, ) -> Self where Self: Sized,`
  - `TabBar::end_children_mut(&mut self) -> &mut SmallVec<[AnyElement; 2]>`
  - `TabBar::end_child(mut self, end_child: impl IntoElement) -> Self where Self: Sized,`
  - `TabBar::end_children(mut self, end_children: impl IntoIterator<Item = impl IntoElement>) -> Self where Self: Sized,`

### `crates/ui/src/components/toggle.rs`
- Öğeler: `enum ToggleStyle`; `struct Checkbox`; `enum SwitchColor`; `enum SwitchLabelPosition`; `struct Switch`; `struct SwitchField`
- Fonksiyonlar:
  - `fn checkbox(id: impl Into<ElementId>, toggle_state: ToggleState) -> Checkbox`
  - `fn switch(id: impl Into<ElementId>, toggle_state: ToggleState) -> Switch`
- Metotlar:
  - `Checkbox::new(id: impl Into<ElementId>, checked: ToggleState) -> Self`
  - `Checkbox::disabled(mut self, disabled: bool) -> Self`
  - `Checkbox::placeholder(mut self, placeholder: bool) -> Self`
  - `Checkbox::on_click( mut self, handler: impl Fn(&ToggleState, &mut Window, &mut App) + 'static, ) -> Self`
  - `Checkbox::on_click_ext( mut self, handler: impl Fn(&ToggleState, &ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `Checkbox::fill(mut self) -> Self`
  - `Checkbox::visualization_only(mut self, visualization: bool) -> Self`
  - `Checkbox::style(mut self, style: ToggleStyle) -> Self`
  - `Checkbox::elevation(mut self, elevation: ElevationIndex) -> Self`
  - `Checkbox::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `Checkbox::label(mut self, label: impl Into<SharedString>) -> Self`
  - `Checkbox::label_size(mut self, size: LabelSize) -> Self`
  - `Checkbox::label_color(mut self, color: Color) -> Self`
  - `Checkbox::container_size() -> Pixels`
  - `Switch::new(id: impl Into<ElementId>, state: ToggleState) -> Self`
  - `Switch::color(mut self, color: SwitchColor) -> Self`
  - `Switch::disabled(mut self, disabled: bool) -> Self`
  - `Switch::on_click( mut self, handler: impl Fn(&ToggleState, &mut Window, &mut App) + 'static, ) -> Self`
  - `Switch::label(mut self, label: impl Into<SharedString>) -> Self`
  - `Switch::label_position( mut self, label_position: impl Into<Option<SwitchLabelPosition>>, ) -> Self`
  - `Switch::label_size(mut self, size: LabelSize) -> Self`
  - `Switch::full_width(mut self, full_width: bool) -> Self`
  - `Switch::key_binding(mut self, key_binding: impl Into<Option<KeyBinding>>) -> Self`
  - `Switch::tab_index(mut self, tab_index: impl Into<isize>) -> Self`
  - `SwitchField::new( id: impl Into<ElementId>, label: Option<impl Into<SharedString>>, description: Option<SharedString>, toggle_state: impl Into<ToggleState>, on_click: impl Fn(&ToggleState, &mut Window, &mut App) + 'static, ) -> Self`
  - `SwitchField::description(mut self, description: impl Into<SharedString>) -> Self`
  - `SwitchField::disabled(mut self, disabled: bool) -> Self`
  - `SwitchField::color(mut self, color: SwitchColor) -> Self`
  - `SwitchField::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `SwitchField::tab_index(mut self, tab_index: isize) -> Self`
- Public enum variantları: ToggleStyle: `Ghost`, `ElevationBased`, `Custom`; SwitchColor: `Accent`, `Custom`; SwitchLabelPosition: `Start`, `End`

### `crates/ui/src/components/tooltip.rs`
- Öğeler: `struct Tooltip`; `struct LinkPreview`
- Fonksiyonlar:
  - `fn tooltip_container<C>(cx: &mut C, f: impl FnOnce(Div, &mut C) -> Div) -> impl IntoElement where C: AppContext + Borrow<App>,`
- Metotlar:
  - `Tooltip::simple(title: impl Into<SharedString>, cx: &mut App) -> AnyView`
  - `Tooltip::text(title: impl Into<SharedString>) -> impl Fn(&mut Window, &mut App) -> AnyView`
  - `Tooltip::for_action_title<T: Into<SharedString>>( title: T, action: &dyn Action, ) -> impl Fn(&mut Window, &mut App) -> AnyView + use<T>`
  - `Tooltip::for_action_title_in<Str: Into<SharedString>>( title: Str, action: &dyn Action, focus_handle: &FocusHandle, ) -> impl Fn(&mut Window, &mut App) -> AnyView + use<Str>`
  - `Tooltip::for_action( title: impl Into<SharedString>, action: &dyn Action, cx: &mut App, ) -> AnyView`
  - `Tooltip::for_action_in( title: impl Into<SharedString>, action: &dyn Action, focus_handle: &FocusHandle, cx: &mut App, ) -> AnyView`
  - `Tooltip::with_meta( title: impl Into<SharedString>, action: Option<&dyn Action>, meta: impl Into<SharedString>, cx: &mut App, ) -> AnyView`
  - `Tooltip::with_meta_in( title: impl Into<SharedString>, action: Option<&dyn Action>, meta: impl Into<SharedString>, focus_handle: &FocusHandle, cx: &mut App, ) -> AnyView`
  - `Tooltip::new(title: impl Into<SharedString>) -> Self`
  - `Tooltip::new_element(title: impl Fn(&mut Window, &mut App) -> AnyElement + 'static) -> Self`
  - `Tooltip::element( title: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, ) -> impl Fn(&mut Window, &mut App) -> AnyView`
  - `Tooltip::meta(mut self, meta: impl Into<SharedString>) -> Self`
  - `Tooltip::key_binding(mut self, key_binding: impl Into<Option<KeyBinding>>) -> Self`
  - `LinkPreview::new(url: &str, cx: &mut App) -> AnyView`

### `crates/ui/src/components/tree_view_item.rs`
- Öğeler: `struct TreeViewItem`
- Metotlar:
  - `TreeViewItem::new(id: impl Into<ElementId>, label: impl Into<SharedString>) -> Self`
  - `TreeViewItem::group_name(mut self, group_name: impl Into<SharedString>) -> Self`
  - `TreeViewItem::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `TreeViewItem::on_hover(mut self, handler: impl Fn(&bool, &mut Window, &mut App) + 'static) -> Self`
  - `TreeViewItem::on_secondary_mouse_down( mut self, handler: impl Fn(&MouseDownEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `TreeViewItem::tooltip(mut self, tooltip: impl Fn(&mut Window, &mut App) -> AnyView + 'static) -> Self`
  - `TreeViewItem::tab_index(mut self, tab_index: isize) -> Self`
  - `TreeViewItem::expanded(mut self, toggle: bool) -> Self`
  - `TreeViewItem::default_expanded(mut self, default_expanded: bool) -> Self`
  - `TreeViewItem::on_toggle( mut self, on_toggle: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `TreeViewItem::root_item(mut self, root_item: bool) -> Self`
  - `TreeViewItem::focused(mut self, focused: bool) -> Self`
  - `TreeViewItem::track_focus(mut self, focus_handle: &gpui::FocusHandle) -> Self`

## 15. Prosedürel Kapsam Doğrulaması

Bu rehbere yeni bir GPUI/Zed bileşeni eklenirken aşağıdaki sıra bozulmamalıdır:

1. Kaynak export'u bulun: `components.rs`, `elements/mod.rs`, ilgili modül.
2. Public ad source index tablosuna eklenir.
3. Constructor envanteri güncellenir.
4. Builder/metod yüzeyi **sahibiyle birlikte** ilgili başlıkta listelenir
   (`Button::key_binding`, `ButtonCommon::tooltip`, `Clickable for
   IconButton::cursor_style` gibi).
5. Public enum variant'ları ve public struct alanları kontrol edilir; kullanıcı
   API'si değilse "internal/debug/test-only" gerekçesiyle not düşülür.
6. Kullanım disiplini ve en az bir kompozisyon örüntüsü eklenir.
7. Focus, tooltip, action, scroll ve async riskleri checklist'e bağlanır.
8. Aşağıdaki doğrulamalar çalıştırılır ve boş diff beklenir.

Zed `ui` public ad kapsamı:

```sh
rg -o '^pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)' \
  ../zed/crates/ui/src/components \
  ../zed/crates/ui/src/styles \
  ../zed/crates/ui/src/traits \
  ../zed/crates/ui/src/utils.rs \
  ../zed/crates/ui/src/utils \
  -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/ui_pub_names.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/ui_pub_names.txt
```

Ham GPUI element public ad kapsamı:

```sh
rg -o '^pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)' \
  ../zed/crates/gpui/src/elements \
  -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/gpui_element_pub_names.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/gpui_element_pub_names.txt
```

Component preview crate public ad kapsamı (`crates/component`):

```sh
rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
  ../zed/crates/component/src \
  -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/component_pub_names.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/component_pub_names.txt
```

`ui_input` public ad kapsamı (`InputField`, `ErasedEditor`,
`ErasedEditorEvent`, `ERASED_EDITOR_FACTORY` ve diğer editor entegrasyon
yüzeyi):

```sh
rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
  ../zed/crates/ui_input/src \
  -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/ui_input_pub_names.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/ui_input_pub_names.txt
```

Owner+method matrisi (ad taraması tek başına yeterli değildir):

```sh
find ../zed/crates/ui/src ../zed/crates/ui_input/src ../zed/crates/component/src \
  -name '*.rs' > /tmp/bilesen_files.txt

awk '
function brace_delta(s, a, b, t) {
  t=s; a=gsub(/\{/, "", t)
  t=s; b=gsub(/\}/, "", t)
  return a-b
}
function normalize(s) {
  gsub(/[[:space:]]+/, " ", s)
  sub(/^[[:space:]]+/, "", s)
  sub(/[[:space:]]+$/, "", s)
  sub(/[[:space:]]*\{[[:space:]]*\}[[:space:]]*$/, "", s)
  sub(/[[:space:]]*[\{;][[:space:]]*$/, "", s)
  return s
}
function capture_signature(first, sig, nextline) {
  sig=first
  cap_delta=brace_delta(first)
  while (sig !~ /[\{\};][[:space:]]*$/ && (getline nextline) > 0) {
    sig=sig " " nextline
    cap_delta += brace_delta(nextline)
  }
  return normalize(sig)
}
FNR==1 { owner=""; mode=""; depth=0 }
{
  line=$0
  if (mode == "") {
    if (line ~ /^[[:space:]]*impl[[:space:]<]/) {
      hdr=line
      while (hdr !~ /\{/ && hdr !~ /;[[:space:]]*$/ && (getline nextline) > 0) {
        hdr=hdr " " nextline
      }
      if (hdr ~ /;[[:space:]]*$/ || hdr ~ /\{[[:space:]]*\}[[:space:]]*$/) {
        owner=""; mode=""; depth=0; next
      }
      owner=hdr
      sub(/^[[:space:]]*/, "", owner)
      sub(/[[:space:]]*\{.*$/, "", owner)
      gsub(/[[:space:]]+/, " ", owner)
      depth=brace_delta(hdr)
      mode="impl"
      next
    }
    if (line ~ /^[[:space:]]*pub trait[[:space:]]/) {
      hdr=line
      while (hdr !~ /\{/ && hdr !~ /;[[:space:]]*$/ && (getline nextline) > 0) {
        hdr=hdr " " nextline
      }
      if (hdr ~ /;[[:space:]]*$/) next
      owner=hdr
      sub(/^[[:space:]]*pub trait[[:space:]]+/, "trait ", owner)
      sub(/[<:].*/, "", owner)
      sub(/[[:space:]]*\{.*$/, "", owner)
      gsub(/[[:space:]]+/, " ", owner)
      depth=brace_delta(hdr)
      mode="trait"
      next
    }
    if (line ~ /^[[:space:]]*pub (async[[:space:]]+|const[[:space:]]+|unsafe[[:space:]]+)*fn [A-Za-z_]/) {
      sig=capture_signature(line)
      print FILENAME ":" FNR ":free :: " sig
      next
    }
  } else {
    if (depth == 1) {
      if (mode == "trait" && line ~ /^[[:space:]]*(pub[[:space:]]+)?(async[[:space:]]+|const[[:space:]]+|unsafe[[:space:]]+)*fn[[:space:]][A-Za-z_]/) {
        sig=capture_signature(line)
        print FILENAME ":" FNR ":" owner " :: " sig
        depth += cap_delta
        if (depth <= 0) { owner=""; mode=""; depth=0 }
        next
      }
      if (mode == "impl" && (line ~ /^[[:space:]]+pub[[:space:]]+(async[[:space:]]+|const[[:space:]]+|unsafe[[:space:]]+)*fn[[:space:]][A-Za-z_]/ || (owner ~ / for / && line ~ /^[[:space:]]+(async[[:space:]]+|const[[:space:]]+|unsafe[[:space:]]+)*fn[[:space:]][A-Za-z_]/))) {
        sig=capture_signature(line)
        print FILENAME ":" FNR ":" owner " :: " sig
        depth += cap_delta
        if (depth <= 0) { owner=""; mode=""; depth=0 }
        next
      }
    }
    depth += brace_delta(line)
    if (depth <= 0) { owner=""; mode=""; depth=0 }
  }
}
' $(cat /tmp/bilesen_files.txt) | sort -u > /tmp/bilesen_owner_methods.txt
```

Bu awk akışının `rg`/`grep` ile yakalayamayacağı beş sınıfı kapsamalıdır:

1. **Multi-line impl başlığı**: `impl<T: ButtonBuilder, const COLS: usize,
   const ROWS: usize> FixedWidth\n    for ToggleButtonGroup<T, COLS, ROWS>`
   gibi başlıklar tek satırlık ad araması ile owner bilgisinden kopar; awk
   `getline` ile `{`/`;`/`}` görene kadar birleştirir.
2. **Trait override metotları**: `impl Clickable for IconButton` içindeki
   `fn cursor_style(...)` `pub` taşımadığı için `rg 'pub fn'` taramasında
   görünmez. Bu metotlar trait üzerinden public yüzeydir ve component'in
   ortak builder listesine yazılır.
3. **Public trait sözleşmesi**: `pub trait ButtonCommon` içindeki `fn style(...)`
   gibi trait item'ları `pub` yazmaz ama trait public olduğu için dış yüzeydir.
   Bu satırlar `trait ButtonCommon :: fn style(...)` biçiminde ayrıca çıkar.
4. **Blok derinliği taşması**: `impl Global for VimStyle {}` gibi
   tek satırlık unit impl, getline loop'unu yutmaz; owner bir sonraki impl'e
   geçer. Awk'ın brace-depth takibi `impl` dışındaki serbest fonksiyonları
   önceki owner'a yanlış bağlamayı da engeller.
5. **`const fn` / `unsafe fn` qualifier'ları**: `pub const fn to_pixels(...)`
   (`ScrollbarStyle`) ve `pub const fn platform()` (`PlatformStyle`) örneklerinde
   `pub` ile `fn` arasında ek qualifier vardır. Regex `(async|const|unsafe)*`
   ile bu ekleri esnek biçimde tüketir; aksi halde compile-time helper'lar
   public yüzey listesinden düşer.

Bu dosya elle incelenir; her satır için metodun doğru **sahip başlığında**
geçtiği doğrulanır. Örneğin `impl Button::key_binding` yalnızca `Button`
başlığına yazılır; aynı adın `Switch::key_binding` üzerinde de bulunması ikinci
bir owner satırı olarak ayrıca doğrulanır. Trait implementasyonları
(`impl Clickable for IconButton :: cursor_style`) component başlığındaki ortak
builder listesine yansıtılır; trait'in kendisi ayrıca "Ortak trait" listesinde
kalır.

Ham GPUI element metod yüzeyi için kaynak kapısı:

```sh
rg -n '^pub fn |^    pub fn |^    fn [a-zA-Z_].*-> Self|^pub trait ' \
  ../zed/crates/gpui/src/elements \
  ../zed/crates/gpui/src/styled.rs \
  ../zed/crates/gpui_macros/src/styles.rs
```

Component ve `ui_input` metod yüzeyi için hızlı kaynak kapısı:

```sh
rg -n '^pub fn |^    pub fn |^    fn [a-zA-Z_].*-> Self|^pub trait ' \
  ../zed/crates/ui/src/components \
  ../zed/crates/ui/src/traits \
  ../zed/crates/component/src \
  ../zed/crates/ui_input/src
```

Public struct field ve enum variant kapsamı:

```sh
awk '
/^pub struct [A-Za-z0-9_]+/ { s=$3; sub(/\(.*/, "", s); in_s=1; next }
in_s && /^}/ { in_s=0; s="" }
in_s && /^[[:space:]]*pub [A-Za-z0-9_]+:/ {
  f=$2; gsub(/:.*/, "", f); print s "." f
}
' \
  ../zed/crates/ui/src/components/**/*.rs \
  ../zed/crates/ui/src/components/*.rs \
  ../zed/crates/ui/src/styles/*.rs \
  ../zed/crates/ui/src/traits/*.rs \
  ../zed/crates/ui/src/utils/*.rs \
  ../zed/crates/ui/src/utils.rs \
  ../zed/crates/component/src/*.rs \
  ../zed/crates/ui_input/src/*.rs \
  ../zed/crates/gpui/src/elements/*.rs \
  2>/dev/null | sort -u > /tmp/bilesen_public_fields.txt

while read item; do
  field="${item#*.}"
  rg -q "\\b${field}\\b" bilesen_rehberi.md || echo "${item}"
done < /tmp/bilesen_public_fields.txt

awk '
/^pub enum [A-Za-z0-9_]+/ { e=$3; in_e=1; next }
in_e && /^}/ { in_e=0; e="" }
in_e && /^[[:space:]]*[A-Z][A-Za-z0-9_]+[,{(]/ {
  v=$1; gsub(/[,{(].*/, "", v); print e "." v
}
' \
  ../zed/crates/ui/src/components/**/*.rs \
  ../zed/crates/ui/src/components/*.rs \
  ../zed/crates/ui/src/styles/*.rs \
  ../zed/crates/ui/src/traits/*.rs \
  ../zed/crates/ui/src/utils/*.rs \
  ../zed/crates/ui/src/utils.rs \
  ../zed/crates/component/src/*.rs \
  ../zed/crates/ui_input/src/*.rs \
  ../zed/crates/gpui/src/elements/*.rs \
  2>/dev/null | sort -u > /tmp/bilesen_enum_variants.txt

while read item; do
  variant="${item#*.}"
  rg -q "\\b${variant}\\b" bilesen_rehberi.md || echo "${item}"
done < /tmp/bilesen_enum_variants.txt
```

Geçiş kriteri: `ui`, GPUI element, `component` ve `ui_input` public ad
kontrollerinin **dördü de** çıktı üretmemelidir. Metod yüzeyi ve
field/variant kontrollerinde yeni bir public constructor, trait metodu,
builder metodu, enum variant'ı veya public alan görünüyorsa bu bölümdeki tablo
ve ilgili bileşen başlığı aynı değişiklikte güncellenmelidir. InputField için
Bölüm 5, component preview için Bölüm 2'nin "Component preview" alt başlığı,
ham GPUI state alanları için Bölüm 13 kullanılır.

> **Bilinen filtre dışı kalan kasıtlı atlamalar.**
>
> - `ui_input::InputFieldStyle`: public struct ama tüm alanları private;
>   tüketici tarafı için builder yüzeyi sunmaz, sadece `InputField`'in iç
>   render'ında kullanılır.
> - `component::COMPONENT_DATA`: `LazyLock<RwLock<ComponentRegistry>>`
>   global; `components()` ve `register_component()` üzerinden erişilir,
>   doğrudan tüketici API'si değildir.
> - `ToggleButtonStyle`: `toggle_button.rs` içinde `private` modülde duran
>   sealed supertrait; dış crate implement edemez.
> - `ButtonLikeRounding::{ALL, LEFT, RIGHT}`: `pub(crate)` tip üzerindeki
>   associated const'lar; yalnızca `ButtonLike::new_rounded_*` constructor'ları
>   üzerinden tüketici API'sine yansır.
>
> Public ad kontrolü bu adları raporlasa bile rehberde başlık açılmaz; bu
> istisnaları `tema_aktarimi.md`'ye benzer bir kapsam dışı listesinde
> toplamak iyi bir disiplindir.
