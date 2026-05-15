# Ek D. `crates/ui/src/components` Public API Yüzeyi

Kaynak: `../zed` commit `3493830ce94ee1fa9d25ca92dcf23b502109fe07`.
`pub(crate)`, `pub(super)` ve `pub(in ...)` kapsam dışıdır. Trait metotları
public trait sözleşmesi olduğu için ayrıca listelenir. Private modül içinde
`pub` görünen sealed adlar dış crate API'si değildir; ilgili satırda özellikle
"private/sealed" olarak işaretlenir.
`Öğeler` satırındaki `use ...::*` kayıtları kaynakta `pub use ...::*` olarak
geçen re-export kapılarıdır.

## `crates/ui/src/components.rs`
- Öğeler: `use ai::*`; `use avatar::*`; `use banner::*`; `use button::*`; `use callout::*`; `use chip::*`; `use collab::*`; `use context_menu::*`; `use count_badge::*`; `use data_table::*`; `use diff_stat::*`; `use disclosure::*`; `use divider::*`; `use dropdown_menu::*`; `use facepile::*`; `use gradient_fade::*`; `use group::*`; `use icon::*`; `use image::*`; `use indent_guides::*`; `use indicator::*`; `use keybinding::*`; `use keybinding_hint::*`; `use label::*`; `use list::*`; `use modal::*`; `use navigable::*`; `use notification::*`; `use popover::*`; `use popover_menu::*`; `use progress::*`; `use project_empty_state::*`; `use redistributable_columns::*`; `use right_click_menu::*`; `use scrollbar::*`; `use stack::*`; `use sticky_items::*`; `use tab::*`; `use tab_bar::*`; `use toggle::*`; `use tooltip::*`; `use tree_view_item::*`

## `crates/ui/src/components/ai/agent_setup_button.rs`
- Öğeler: `struct AgentSetupButton`
- Metotlar:
  - `AgentSetupButton::new(id: impl Into<ElementId>) -> Self`
  - `AgentSetupButton::icon(mut self, icon: Icon) -> Self`
  - `AgentSetupButton::name(mut self, name: impl Into<SharedString>) -> Self`
  - `AgentSetupButton::state(mut self, element: impl IntoElement) -> Self`
  - `AgentSetupButton::disabled(mut self, disabled: bool) -> Self`
  - `AgentSetupButton::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`

## `crates/ui/src/components/ai/ai_setting_item.rs`
- Öğeler: `enum AiSettingItemStatus`; `enum AiSettingItemSource`; `struct AiSettingItem`
- Metotlar:
  - `AiSettingItem::new( id: impl Into<ElementId>, label: impl Into<SharedString>, status: AiSettingItemStatus, source: AiSettingItemSource, ) -> Self`
  - `AiSettingItem::icon(mut self, element: impl IntoElement) -> Self`
  - `AiSettingItem::detail_label(mut self, detail: impl Into<SharedString>) -> Self`
  - `AiSettingItem::action(mut self, element: impl IntoElement) -> Self`
  - `AiSettingItem::details(mut self, element: impl IntoElement) -> Self`
- Public enum variantları: AiSettingItemStatus: `Stopped`, `Starting`, `Running`, `Error`, `AuthRequired`, `Authenticating`; AiSettingItemSource: `Extension`, `Custom`, `Registry`

## `crates/ui/src/components/ai/configured_api_card.rs`
- Öğeler: `struct ConfiguredApiCard`
- Metotlar:
  - `ConfiguredApiCard::new(label: impl Into<SharedString>) -> Self`
  - `ConfiguredApiCard::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ConfiguredApiCard::button_label(mut self, button_label: impl Into<SharedString>) -> Self`
  - `ConfiguredApiCard::tooltip_label(mut self, tooltip_label: impl Into<SharedString>) -> Self`
  - `ConfiguredApiCard::disabled(mut self, disabled: bool) -> Self`
  - `ConfiguredApiCard::button_tab_index(mut self, tab_index: isize) -> Self`

## `crates/ui/src/components/ai/parallel_agents_illustration.rs`
- Öğeler: `struct ParallelAgentsIllustration`
- Metotlar:
  - `ParallelAgentsIllustration::new() -> Self`

## `crates/ui/src/components/ai/thread_item.rs`
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

## `crates/ui/src/components/ai.rs`
- Öğeler: `use agent_setup_button::*`; `use ai_setting_item::*`; `use configured_api_card::*`; `use parallel_agents_illustration::*`; `use thread_item::*`

## `crates/ui/src/components/avatar.rs`
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

## `crates/ui/src/components/banner.rs`
- Öğeler: `struct Banner`
- Metotlar:
  - `Banner::new() -> Self`
  - `Banner::severity(mut self, severity: Severity) -> Self`
  - `Banner::action_slot(mut self, element: impl IntoElement) -> Self`
  - `Banner::wrap_content(mut self, wrap: bool) -> Self`

## `crates/ui/src/components/button/button.rs`
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

## `crates/ui/src/components/button/button_like.rs`
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

## `crates/ui/src/components/button/button_link.rs`
- Öğeler: `struct ButtonLink`
- Metotlar:
  - `ButtonLink::new(label: impl Into<SharedString>, link: impl Into<String>) -> Self`
  - `ButtonLink::no_icon(mut self, no_icon: bool) -> Self`
  - `ButtonLink::label_size(mut self, label_size: LabelSize) -> Self`
  - `ButtonLink::label_color(mut self, label_color: Color) -> Self`

## `crates/ui/src/components/button/copy_button.rs`
- Öğeler: `struct CopyButton`
- Metotlar:
  - `CopyButton::new(id: impl Into<ElementId>, message: impl Into<SharedString>) -> Self`
  - `CopyButton::icon_size(mut self, icon_size: IconSize) -> Self`
  - `CopyButton::disabled(mut self, disabled: bool) -> Self`
  - `CopyButton::tooltip_label(mut self, tooltip_label: impl Into<SharedString>) -> Self`
  - `CopyButton::visible_on_hover(mut self, visible_on_hover: impl Into<SharedString>) -> Self`
  - `CopyButton::custom_on_click( mut self, custom_on_click: impl Fn(&mut Window, &mut App) + 'static, ) -> Self`

## `crates/ui/src/components/button/icon_button.rs`
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

## `crates/ui/src/components/button/split_button.rs`
- Öğeler: `enum SplitButtonStyle`; `enum SplitButtonKind`; `struct SplitButton`
- Metotlar:
  - `SplitButton::new(left: impl Into<SplitButtonKind>, right: AnyElement) -> Self`
  - `SplitButton::style(mut self, style: SplitButtonStyle) -> Self`
- Public enum variantları: SplitButtonStyle: `Filled`, `Outlined`, `Transparent`; SplitButtonKind: `ButtonLike`, `IconButton`

## `crates/ui/src/components/button/toggle_button.rs`
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

## `crates/ui/src/components/button.rs`
- Öğeler: `use button::*`; `use button_like::*`; `use button_link::*`; `use copy_button::*`; `use icon_button::*`; `use split_button::*`; `use toggle_button::*`

## `crates/ui/src/components/callout.rs`
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

## `crates/ui/src/components/chip.rs`
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

## `crates/ui/src/components/collab/collab_notification.rs`
- Öğeler: `struct CollabNotification`
- Metotlar:
  - `CollabNotification::new( avatar_uri: impl Into<SharedUri>, accept_button: Button, dismiss_button: Button, ) -> Self`

## `crates/ui/src/components/collab/update_button.rs`
- Öğeler: `struct UpdateButton`
- Metotlar:
  - `UpdateButton::new(icon: IconName, message: impl Into<SharedString>) -> Self`
  - `UpdateButton::icon_animate(mut self, animate: bool) -> Self`
  - `UpdateButton::icon_color(mut self, color: impl Into<Option<Color>>) -> Self`
  - `UpdateButton::tooltip(mut self, tooltip: impl Into<SharedString>) -> Self`
  - `UpdateButton::with_dismiss(mut self) -> Self`
  - `UpdateButton::on_click( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `UpdateButton::on_dismiss( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `UpdateButton::disabled(mut self, disabled: bool) -> Self`
  - `UpdateButton::checking() -> Self`
  - `UpdateButton::downloading(version: impl Into<SharedString>) -> Self`
  - `UpdateButton::installing(version: impl Into<SharedString>) -> Self`
  - `UpdateButton::updated(version: impl Into<SharedString>) -> Self`
  - `UpdateButton::errored(error: impl Into<SharedString>) -> Self`

## `crates/ui/src/components/collab.rs`
- Öğeler: `use collab_notification::*`; `use update_button::*`

## `crates/ui/src/components/context_menu.rs`
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

## `crates/ui/src/components/count_badge.rs`
- Öğeler: `struct CountBadge`
- Metotlar:
  - `CountBadge::new(count: usize) -> Self`

## `crates/ui/src/components/data_table/table_row.rs`
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

## `crates/ui/src/components/data_table.rs`
- Öğeler: `pub mod table_row`; `type UncheckedTableRow<T> = Vec<T>`; `struct ResizableColumnsState`; `struct TableInteractionState`; `enum ColumnWidthConfig`; `enum StaticColumnWidths`; `struct Table`; `struct TableRenderContext`
- Fonksiyonlar:
  - `fn render_table_row( row_index: usize, items: TableRow<impl IntoElement>, table_context: TableRenderContext, window: &mut Window, cx: &mut App, ) -> AnyElement`
  - `fn render_table_header( headers: TableRow<impl IntoElement>, table_context: TableRenderContext, resize_info: Option<HeaderResizeInfo>, entity_id: Option<EntityId>, cx: &mut App, ) -> AnyElement`
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
  - `Table::pin_cols(mut self, n: usize) -> Self`
  - `Table::map_row( mut self, callback: impl Fn((usize, Stateful<Div>), &mut Window, &mut App) -> AnyElement + 'static, ) -> Self`
  - `Table::hide_row_hover(mut self) -> Self`
  - `Table::empty_table_callback( mut self, callback: impl Fn(&mut Window, &mut App) -> AnyElement + 'static, ) -> Self`
  - `TableRenderContext::for_column_widths(column_widths: Option<TableRow<Length>>, use_ui_font: bool) -> Self`
- Public enum variantları: ColumnWidthConfig: `Static`, `Redistributable`, `Resizable`; StaticColumnWidths: `Auto`, `Explicit`

## `crates/ui/src/components/diff_stat.rs`
- Öğeler: `struct DiffStat`
- Metotlar:
  - `DiffStat::new(id: impl Into<ElementId>, added: usize, removed: usize) -> Self`
  - `DiffStat::label_size(mut self, label_size: LabelSize) -> Self`
  - `DiffStat::tooltip(mut self, tooltip: impl Into<SharedString>) -> Self`

## `crates/ui/src/components/disclosure.rs`
- Öğeler: `struct Disclosure`
- Metotlar:
  - `Disclosure::new(id: impl Into<ElementId>, is_open: bool) -> Self`
  - `Disclosure::on_toggle_expanded( mut self, handler: impl Into<Option<Arc<dyn Fn(&ClickEvent, &mut Window, &mut App) + 'static>>>, ) -> Self`
  - `Disclosure::opened_icon(mut self, icon: IconName) -> Self`
  - `Disclosure::closed_icon(mut self, icon: IconName) -> Self`
  - `Disclosure::disabled(mut self, disabled: bool) -> Self`

## `crates/ui/src/components/divider.rs`
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

## `crates/ui/src/components/dropdown_menu.rs`
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

## `crates/ui/src/components/facepile.rs`
- Öğeler: `struct Facepile`; `const EXAMPLE_FACES: [&str; 6]`
- Metotlar:
  - `Facepile::empty() -> Self`
  - `Facepile::new(faces: SmallVec<[AnyElement; 2]>) -> Self`

## `crates/ui/src/components/gradient_fade.rs`
- Öğeler: `struct GradientFade`
- Metotlar:
  - `GradientFade::new(base_bg: Hsla, hover_bg: Hsla, active_bg: Hsla) -> Self`
  - `GradientFade::width(mut self, width: Pixels) -> Self`
  - `GradientFade::right(mut self, right: Pixels) -> Self`
  - `GradientFade::gradient_stop(mut self, stop: f32) -> Self`
  - `GradientFade::group_name(mut self, name: impl Into<SharedString>) -> Self`

## `crates/ui/src/components/group.rs`
- Fonksiyonlar:
  - `fn h_group_sm() -> Div`
  - `fn h_group() -> Div`
  - `fn h_group_lg() -> Div`
  - `fn h_group_xl() -> Div`
  - `fn v_group_sm() -> Div`
  - `fn v_group() -> Div`
  - `fn v_group_lg() -> Div`
  - `fn v_group_xl() -> Div`

## `crates/ui/src/components/icon/decorated_icon.rs`
- Öğeler: `struct DecoratedIcon`
- Metotlar:
  - `DecoratedIcon::new(icon: Icon, decoration: Option<IconDecoration>) -> Self`

## `crates/ui/src/components/icon/icon_decoration.rs`
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

## `crates/ui/src/components/icon.rs`
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

## `crates/ui/src/components/image.rs`
- Öğeler: `enum VectorName`; `struct Vector`
- Metotlar:
  - `VectorName::path(&self) -> Arc<str>`
  - `Vector::new(vector: VectorName, width: Rems, height: Rems) -> Self`
  - `Vector::square(vector: VectorName, size: Rems) -> Self`
  - `Vector::color(mut self, color: Color) -> Self`
  - `Vector::size(mut self, size: impl Into<Size<Rems>>) -> Self`
- Public enum variantları: VectorName: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`, `StudentStamp`, `ZedLogo`, `ZedXCopilot`

## `crates/ui/src/components/indent_guides.rs`
- Öğeler: `struct IndentGuideColors`; `struct IndentGuides`; `struct RenderIndentGuideParams`; `struct RenderedIndentGuide`; `struct IndentGuideLayout`
- Fonksiyonlar:
  - `fn indent_guides(indent_size: Pixels, colors: IndentGuideColors) -> IndentGuides`
- Metotlar:
  - `IndentGuideColors::panel(cx: &App) -> Self`
  - `IndentGuides::on_click( mut self, on_click: impl Fn(&IndentGuideLayout, &mut Window, &mut App) + 'static, ) -> Self`
  - `IndentGuides::with_compute_indents_fn<V: Render>( mut self, entity: Entity<V>, compute_indents_fn: impl Fn( &mut V, Range<usize>, &mut Window, &mut Context<V>, ) -> SmallVec<[usize; 64]> + 'static, ) -> Self`
  - `IndentGuides::with_render_fn<V: Render>( mut self, entity: Entity<V>, render_fn: impl Fn( &mut V, RenderIndentGuideParams, &mut Window, &mut App, ) -> SmallVec<[RenderedIndentGuide; 12]> + 'static, ) -> Self`

## `crates/ui/src/components/indicator.rs`
- Öğeler: `struct Indicator`
- Metotlar:
  - `Indicator::dot() -> Self`
  - `Indicator::bar() -> Self`
  - `Indicator::icon(icon: impl Into<AnyIcon>) -> Self`
  - `Indicator::color(mut self, color: Color) -> Self`
  - `Indicator::border_color(mut self, color: Color) -> Self`

## `crates/ui/src/components/keybinding.rs`
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

## `crates/ui/src/components/keybinding_hint.rs`
- Öğeler: `struct KeybindingHint`
- Metotlar:
  - `KeybindingHint::new(keybinding: KeyBinding, background_color: Hsla) -> Self`
  - `KeybindingHint::with_prefix( prefix: impl Into<SharedString>, keybinding: KeyBinding, background_color: Hsla, ) -> Self`
  - `KeybindingHint::with_suffix( keybinding: KeyBinding, suffix: impl Into<SharedString>, background_color: Hsla, ) -> Self`
  - `KeybindingHint::prefix(mut self, prefix: impl Into<SharedString>) -> Self`
  - `KeybindingHint::suffix(mut self, suffix: impl Into<SharedString>) -> Self`
  - `KeybindingHint::size(mut self, size: impl Into<Option<Pixels>>) -> Self`

## `crates/ui/src/components/label/highlighted_label.rs`
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

## `crates/ui/src/components/label/label.rs`
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

## `crates/ui/src/components/label/label_like.rs`
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

## `crates/ui/src/components/label/loading_label.rs`
- Öğeler: `struct LoadingLabel`
- Metotlar:
  - `LoadingLabel::new(text: impl Into<SharedString>) -> Self`

## `crates/ui/src/components/label/spinner_label.rs`
- Öğeler: `enum SpinnerVariant`; `struct SpinnerLabel`
- Metotlar:
  - `SpinnerLabel::new() -> Self`
  - `SpinnerLabel::with_variant(variant: SpinnerVariant) -> Self`
  - `SpinnerLabel::dots() -> Self`
  - `SpinnerLabel::dots_variant() -> Self`
  - `SpinnerLabel::sand() -> Self`
- Public enum variantları: SpinnerVariant: `Dots`, `DotsVariant`, `Sand`

## `crates/ui/src/components/label.rs`
- Öğeler: `use highlighted_label::*`; `use label::*`; `use label_like::*`; `use loading_label::*`; `use spinner_label::*`

## `crates/ui/src/components/list/list.rs`
- Öğeler: `enum EmptyMessage`; `struct List`
- Metotlar:
  - `List::new() -> Self`
  - `List::empty_message(mut self, message: impl Into<EmptyMessage>) -> Self`
  - `List::header(mut self, header: impl Into<Option<ListHeader>>) -> Self`
  - `List::toggle(mut self, toggle: impl Into<Option<bool>>) -> Self`
- Public enum variantları: EmptyMessage: `Text`, `Element`

## `crates/ui/src/components/list/list_bullet_item.rs`
- Öğeler: `struct ListBulletItem`
- Metotlar:
  - `ListBulletItem::new(label: impl Into<SharedString>) -> Self`
  - `ListBulletItem::label_color(mut self, color: Color) -> Self`

## `crates/ui/src/components/list/list_header.rs`
- Öğeler: `struct ListHeader`
- Metotlar:
  - `ListHeader::new(label: impl Into<SharedString>) -> Self`
  - `ListHeader::toggle(mut self, toggle: impl Into<Option<bool>>) -> Self`
  - `ListHeader::on_toggle( mut self, on_toggle: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ListHeader::start_slot<E: IntoElement>(mut self, start_slot: impl Into<Option<E>>) -> Self`
  - `ListHeader::end_slot<E: IntoElement>(mut self, end_slot: impl Into<Option<E>>) -> Self`
  - `ListHeader::end_hover_slot<E: IntoElement>(mut self, end_hover_slot: impl Into<Option<E>>) -> Self`
  - `ListHeader::inset(mut self, inset: bool) -> Self`

## `crates/ui/src/components/list/list_item.rs`
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

## `crates/ui/src/components/list/list_separator.rs`
- Öğeler: `struct ListSeparator`

## `crates/ui/src/components/list/list_sub_header.rs`
- Öğeler: `struct ListSubHeader`
- Metotlar:
  - `ListSubHeader::new(label: impl Into<SharedString>) -> Self`
  - `ListSubHeader::left_icon(mut self, left_icon: Option<IconName>) -> Self`
  - `ListSubHeader::end_slot(mut self, end_slot: AnyElement) -> Self`
  - `ListSubHeader::inset(mut self, inset: bool) -> Self`

## `crates/ui/src/components/list.rs`
- Öğeler: `use list::*`; `use list_bullet_item::*`; `use list_header::*`; `use list_item::*`; `use list_separator::*`; `use list_sub_header::*`

## `crates/ui/src/components/modal.rs`
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

## `crates/ui/src/components/navigable.rs`
- Öğeler: `struct Navigable`; `struct NavigableEntry`
- Metotlar:
  - `NavigableEntry::new(scroll_handle: &ScrollHandle, cx: &App) -> Self`
  - `NavigableEntry::focusable(cx: &App) -> Self`
  - `Navigable::new(child: AnyElement) -> Self`
  - `Navigable::entry(mut self, child: NavigableEntry) -> Self`

## `crates/ui/src/components/notification/alert_modal.rs`
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

## `crates/ui/src/components/notification/announcement_toast.rs`
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

## `crates/ui/src/components/notification.rs`
- Öğeler: `use alert_modal::*`; `use announcement_toast::*`

## `crates/ui/src/components/popover.rs`
- Öğeler: `const POPOVER_Y_PADDING: Pixels = px(8.)`; `struct Popover`
- Metotlar:
  - `Popover::new() -> Self`
  - `Popover::aside(mut self, aside: impl IntoElement) -> Self where Self: Sized,`

## `crates/ui/src/components/popover_menu.rs`
- Öğeler: `trait PopoverTrigger: IntoElement + Clickable + Toggleable + 'static`; `struct PopoverMenuHandle<M>(Rc<RefCell<Option<PopoverMenuHandleState<M>>>>)`; `struct PopoverMenu<M: ManagedView>`; `struct PopoverMenuElementState<M>`; `struct PopoverMenuFrameState<M: ManagedView>`
- Trait passthrough impl'leri:
  - `impl<T: Clickable> Clickable for gpui::AnimationElement<T> where T: Clickable + 'static`; `on_click` ve `cursor_style` `.map_element(...)` ile inner element'e delege edilir.
  - `impl<T: Toggleable> Toggleable for gpui::AnimationElement<T> where T: Toggleable + 'static`; `toggle_state` aynı yolla delege edilir.
  - Sonuç: `AnimationElement<IconButton>` gibi sarmalanmış tipler `PopoverTrigger` alias'ını sağlar ve `PopoverMenu::trigger(...)` argümanı olarak kabul edilir.
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

## `crates/ui/src/components/progress/circular_progress.rs`
- Öğeler: `struct CircularProgress`
- Metotlar:
  - `CircularProgress::new(value: f32, max_value: f32, size: Pixels, cx: &App) -> Self`
  - `CircularProgress::value(mut self, value: f32) -> Self`
  - `CircularProgress::max_value(mut self, max_value: f32) -> Self`
  - `CircularProgress::size(mut self, size: Pixels) -> Self`
  - `CircularProgress::stroke_width(mut self, stroke_width: Pixels) -> Self`
  - `CircularProgress::bg_color(mut self, color: Hsla) -> Self`
  - `CircularProgress::progress_color(mut self, color: Hsla) -> Self`

## `crates/ui/src/components/progress/progress_bar.rs`
- Öğeler: `struct ProgressBar`
- Metotlar:
  - `ProgressBar::new(id: impl Into<ElementId>, value: f32, max_value: f32, cx: &App) -> Self`
  - `ProgressBar::value(mut self, value: f32) -> Self`
  - `ProgressBar::max_value(mut self, max_value: f32) -> Self`
  - `ProgressBar::bg_color(mut self, color: Hsla) -> Self`
  - `ProgressBar::fg_color(mut self, color: Hsla) -> Self`
  - `ProgressBar::over_color(mut self, color: Hsla) -> Self`

## `crates/ui/src/components/progress.rs`
- Öğeler: `use circular_progress::*`; `use progress_bar::*`

## `crates/ui/src/components/project_empty_state.rs`
- Öğeler: `struct ProjectEmptyState`
- Metotlar:
  - `ProjectEmptyState::new( label: impl Into<SharedString>, focus_handle: FocusHandle, open_project_key_binding: KeyBinding, ) -> Self`
  - `ProjectEmptyState::on_open_project( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`
  - `ProjectEmptyState::on_clone_repo( mut self, handler: impl Fn(&ClickEvent, &mut Window, &mut App) + 'static, ) -> Self`

## `crates/ui/src/components/redistributable_columns.rs`
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

## `crates/ui/src/components/right_click_menu.rs`
- Öğeler: `struct RightClickMenu<M: ManagedView>`; `struct MenuHandleElementState<M>`; `struct RequestLayoutState`; `struct PrepaintState`
- Fonksiyonlar:
  - `fn right_click_menu<M: ManagedView>(id: impl Into<ElementId>) -> RightClickMenu<M>`
- Metotlar:
  - `<M: ManagedView> RightClickMenu<M>::menu(mut self, f: impl Fn(&mut Window, &mut App) -> Entity<M> + 'static) -> Self`
  - `<M: ManagedView> RightClickMenu<M>::trigger<F, E>(mut self, e: F) -> Self where F: FnOnce(bool, &mut Window, &mut App) -> E + 'static, E: IntoElement + 'static,`
  - `<M: ManagedView> RightClickMenu<M>::anchor(mut self, anchor: Anchor) -> Self`
  - `<M: ManagedView> RightClickMenu<M>::attach(mut self, attach: Anchor) -> Self`

## `crates/ui/src/components/scrollbar.rs`
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

## `crates/ui/src/components/stack.rs`
- Fonksiyonlar:
  - `fn h_flex() -> Div`
  - `fn v_flex() -> Div`

## `crates/ui/src/components/sticky_items.rs`
- Öğeler: `trait StickyCandidate`; `struct StickyItems<T>`; `trait StickyItemsDecoration`
- Fonksiyonlar:
  - `fn sticky_items<V, T>( entity: Entity<V>, compute_fn: impl Fn(&mut V, Range<usize>, &mut Window, &mut Context<V>) -> SmallVec<[T; 8]> + 'static, render_fn: impl Fn(&mut V, T, &mut Window, &mut Context<V>) -> SmallVec<[AnyElement; 8]> + 'static, ) -> StickyItems<T> where V: Render, T: StickyCandidate + Clone + 'static`
- Metotlar:
  - `<T: StickyCandidate + Clone + 'static> StickyItems<T>::with_decoration(mut self, decoration: impl StickyItemsDecoration + 'static) -> Self`
- Trait metotları:
  - `trait StickyCandidate::depth(&self) -> usize`
  - `trait StickyItemsDecoration::compute( &self, indents: &SmallVec<[usize; 8]>, bounds: Bounds<Pixels>, scroll_offset: Point<Pixels>, item_height: Pixels, window: &mut Window, cx: &mut App, ) -> AnyElement`

## `crates/ui/src/components/stories.rs`
- Bu dosya `crates/ui/src/components.rs` içinde `mod stories;` ile dahil
  edilmediği için public build chain'inin parçası değildir. Kaynakta
  `mod context_menu; pub use context_menu::*;` satırları görünür ama `stories`
  modülü `ui` crate'inden erişilebilir değildir. Tüketici API'si açısından
  yok sayılır.

## `crates/ui/src/components/tab.rs`
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

## `crates/ui/src/components/tab_bar.rs`
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

## `crates/ui/src/components/toggle.rs`
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

## `crates/ui/src/components/tooltip.rs`
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

## `crates/ui/src/components/tree_view_item.rs`
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

