# Zed UI Bileşenleri Kullanım Rehberi

Bu rehber, `../zed` çalışma ağacındaki Zed UI bileşenlerini kaynak alır
(`../zed` içinde `git rev-parse --short HEAD`: `db6039d815`). Amaç, `crates/ui`
merkezli bileşenleri kaynak dosyaları, export yolları, builder API'leri, preview
desteği ve gerçek kullanım örnekleriyle tek yerde açıklayarak kendi GPUI tabanlı
ekranlarınızda doğru, tutarlı ve Zed tasarım sistemiyle uyumlu UI kurmanıza
yardımcı olmaktır.

Ana kapsam:

- `crates/ui`: bileşenlerin çoğu, tasarım sistemi token'ları ve prelude.
- `crates/component`: component gallery ve preview kayıt sistemi.
- `crates/icons`: `IconName` kaynakları.
- `crates/theme`: tema token'larının arkasındaki etkin tema verisi.

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

`crates/ui/src/prelude.rs` daha seçicidir. Her component'i değil, sık kullanılan
temel UI primitive'lerini ve trait'leri getirir:

- `gpui::prelude::*`, `App`, `Context`, `Window`, `AnyElement`, `ElementId`,
  `ParentElement`, `RenderOnce`, `SharedString`, `div`, `px`, `rems`.
- Component preview tipleri: `Component`, `ComponentScope`,
  `example_group`, `example_group_with_title`, `single_example`,
  `RegisterComponent`.
- Ortak trait'ler: `Clickable`, `Disableable`, `FixedWidth`, `StyledExt`,
  `Toggleable`, `VisibleOnHover`.
- Sık kullanılan bileşenler ve token'lar: `Button`, `IconButton`,
  `SelectableButton`, `ButtonCommon`, `ButtonSize`, `ButtonStyle`, `Color`,
  `Headline`, `HeadlineSize`, `Icon`, `IconName`, `IconPosition`, `IconSize`,
  `Label`, `LabelCommon`, `LabelSize`, `LineHeightStyle`, `LoadingLabel`,
  `h_flex`, `v_flex`, `h_group*`, `v_group*`, `Severity`, `ActiveTheme`.

Rehberdeki örneklerde kural şu olacak: örnekler önce `use ui::prelude::*;` ile
başlayacak, prelude'da olmayan bileşenler ayrıca `use ui::{...};` satırında
belirtilecek.

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
| `StyledExt` | `crates/ui/src/traits/styled_ext.rs` | Tema ve durum odaklı style yardımcıları. |
| `LabelCommon` | `crates/ui/src/components/label/label_like.rs` | Label ailesinin ortak size/color/weight/truncation yüzeyi. |
| `ButtonCommon` | `crates/ui/src/components/button/button_like.rs` | Button ailesinin ortak icon, style, key binding ve loading yüzeyi. |
| `SelectableButton` | `crates/ui/src/components/button/button_like.rs` | `Button`, `IconButton`, `ButtonLike` için seçilebilirlik sözleşmesi. |

### Kaynak indeksi

| Kategori | Bileşen / API | Tanım kaynağı | Export | Prelude | Preview |
| :-- | :-- | :-- | :-- | :-- | :-- |
| Metin | `Label` | `crates/ui/src/components/label/label.rs` | `ui::Label` | Evet | Evet |
| Metin | `Headline` | `crates/ui/src/styles/typography.rs` | `ui::Headline` | Evet | Evet |
| Metin | `HighlightedLabel` | `crates/ui/src/components/label/highlighted_label.rs` | `ui::HighlightedLabel` | Hayır | Evet |
| Metin | `LoadingLabel` | `crates/ui/src/components/label/loading_label.rs` | `ui::LoadingLabel` | Evet | Hayır |
| Metin | `SpinnerLabel` | `crates/ui/src/components/label/spinner_label.rs` | `ui::SpinnerLabel` | Hayır | Evet |
| Buton | `Button` | `crates/ui/src/components/button/button.rs` | `ui::Button` | Evet | Evet |
| Buton | `IconButton` | `crates/ui/src/components/button/icon_button.rs` | `ui::IconButton` | Evet | Evet |
| Buton | `ButtonLike` | `crates/ui/src/components/button/button_like.rs` | `ui::ButtonLike` | Hayır | Evet |
| Buton | `SelectableButton` | `crates/ui/src/components/button/button_like.rs` | `ui::SelectableButton` | Evet | Trait |
| Buton | `ButtonLink` | `crates/ui/src/components/button/button_link.rs` | `ui::ButtonLink` | Hayır | Evet |
| Buton | `CopyButton` | `crates/ui/src/components/button/copy_button.rs` | `ui::CopyButton` | Hayır | Evet |
| Buton | `SplitButton` | `crates/ui/src/components/button/split_button.rs` | `ui::SplitButton` | Hayır | Hayır |
| Buton | `ToggleButtonGroup` | `crates/ui/src/components/button/toggle_button.rs` | `ui::ToggleButtonGroup` | Hayır | Evet |
| İkon | `Icon` | `crates/ui/src/components/icon.rs` | `ui::Icon` | Evet | Evet |
| İkon | `DecoratedIcon` | `crates/ui/src/components/icon/decorated_icon.rs` | `ui::DecoratedIcon` | Hayır | Evet |
| İkon | `IconDecoration` | `crates/ui/src/components/icon/icon_decoration.rs` | `ui::IconDecoration` | Hayır | Hayır |
| İkon | `IconName` | `crates/icons/src/icons.rs` | `ui::IconName` | Evet | Enum |
| İkon | `IconSize` | `crates/ui/src/components/icon.rs` | `ui::IconSize` | Evet | Enum |
| Form / Toggle | `Checkbox` | `crates/ui/src/components/toggle.rs` | `ui::Checkbox` | Hayır | Evet |
| Form / Toggle | `Switch` | `crates/ui/src/components/toggle.rs` | `ui::Switch` | Hayır | Evet |
| Form / Toggle | `SwitchField` | `crates/ui/src/components/toggle.rs` | `ui::SwitchField` | Hayır | Evet |
| Form / Toggle | `DropdownMenu` | `crates/ui/src/components/dropdown_menu.rs` | `ui::DropdownMenu` | Hayır | Evet |
| Menü / Popup | `ContextMenu` | `crates/ui/src/components/context_menu.rs` | `ui::ContextMenu` | Hayır | Hayır |
| Menü / Popup | `RightClickMenu` | `crates/ui/src/components/right_click_menu.rs` | `ui::RightClickMenu` | Hayır | Hayır |
| Menü / Popup | `Popover` | `crates/ui/src/components/popover.rs` | `ui::Popover` | Hayır | Hayır |
| Menü / Popup | `PopoverMenu` | `crates/ui/src/components/popover_menu.rs` | `ui::PopoverMenu` | Hayır | Hayır |
| Menü / Popup | `Tooltip` | `crates/ui/src/components/tooltip.rs` | `ui::Tooltip` | Hayır | Evet |
| Liste / Tree | `List` | `crates/ui/src/components/list/list.rs` | `ui::List` | Hayır | Evet |
| Liste / Tree | `ListItem` | `crates/ui/src/components/list/list_item.rs` | `ui::ListItem` | Hayır | Evet |
| Liste / Tree | `ListHeader` | `crates/ui/src/components/list/list_header.rs` | `ui::ListHeader` | Hayır | Evet |
| Liste / Tree | `ListSubHeader` | `crates/ui/src/components/list/list_sub_header.rs` | `ui::ListSubHeader` | Hayır | Evet |
| Liste / Tree | `ListSeparator` | `crates/ui/src/components/list/list_separator.rs` | `ui::ListSeparator` | Hayır | Hayır |
| Liste / Tree | `TreeViewItem` | `crates/ui/src/components/tree_view_item.rs` | `ui::TreeViewItem` | Hayır | Evet |
| Liste / Tree | `StickyItems` | `crates/ui/src/components/sticky_items.rs` | `ui::StickyItems` | Hayır | Hayır |
| Liste / Tree | `IndentGuides` | `crates/ui/src/components/indent_guides.rs` | `ui::IndentGuides` | Hayır | Hayır |
| Tab | `Tab` | `crates/ui/src/components/tab.rs` | `ui::Tab` | Hayır | Evet |
| Tab | `TabBar` | `crates/ui/src/components/tab_bar.rs` | `ui::TabBar` | Hayır | Evet |
| Layout | `h_flex` / `v_flex` | `crates/ui/src/components/stack.rs` | `ui::h_flex`, `ui::v_flex` | Evet | Fonksiyon |
| Layout | `h_group*` / `v_group*` | `crates/ui/src/components/group.rs` | `ui::h_group*`, `ui::v_group*` | Evet | Fonksiyon |
| Layout | `Divider` | `crates/ui/src/components/divider.rs` | `ui::Divider` | Hayır | Evet |
| Veri | `Table` | `crates/ui/src/components/data_table.rs` | `ui::Table` | Hayır | Evet |
| Veri | `TableInteractionState` | `crates/ui/src/components/data_table.rs` | `ui::TableInteractionState` | Hayır | State |
| Veri | `ColumnWidthConfig` | `crates/ui/src/components/data_table.rs` | `ui::ColumnWidthConfig` | Hayır | Enum |
| Veri | `ResizableColumnsState` | `crates/ui/src/components/data_table.rs` | `ui::ResizableColumnsState` | Hayır | State |
| Veri | `RedistributableColumnsState` | `crates/ui/src/components/redistributable_columns.rs` | `ui::RedistributableColumnsState` | Hayır | State |
| Veri | `TableResizeBehavior` | `crates/ui/src/components/redistributable_columns.rs` | `ui::TableResizeBehavior` | Hayır | Enum |
| Veri | `TableRow` | `crates/ui/src/components/data_table/table_row.rs` | `ui::table_row::TableRow` | Hayır | Yardımcı tip |
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
| AI / Collab | `AgentSetupButton` | `crates/ui/src/components/ai/agent_setup_button.rs` | `ui::AgentSetupButton` | Hayır | Evet |
| AI / Collab | `ThreadItem` | `crates/ui/src/components/ai/thread_item.rs` | `ui::ThreadItem` | Hayır | Evet |
| AI / Collab | `ConfiguredApiCard` | `crates/ui/src/components/ai/configured_api_card.rs` | `ui::ConfiguredApiCard` | Hayır | Evet |
| AI / Collab | `CollabNotification` | `crates/ui/src/components/collab/collab_notification.rs` | `ui::CollabNotification` | Hayır | Evet |
| AI / Collab | `UpdateButton` | `crates/ui/src/components/collab/update_button.rs` | `ui::UpdateButton` | Hayır | Evet |

### Constructor envanteri

Başlangıç constructor listesi `rg -n "pub fn (new|build|dot|checkbox|switch|divider|...)"`
çıktısından doğrulandı. Ayrıntılı builder listeleri ilgili bileşen başlıklarında
verilecek.

| Bileşen / API | Constructor veya giriş noktası |
| :-- | :-- |
| `Label` | `Label::new(label)` |
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
| `Checkbox` | `Checkbox::new(id, checked)` veya `checkbox(id, state)` |
| `Switch` | `Switch::new(id, state)` veya `switch(id, state)` |
| `SwitchField` | `SwitchField::new(id, label, description, state, on_click)` |
| `DropdownMenu` | `DropdownMenu::new(id, label, menu)` veya `DropdownMenu::new_with_element(id, label, menu)` |
| `ContextMenu` | `ContextMenu::new(window, cx, builder)` veya `ContextMenu::build(window, cx, builder)` |
| `RightClickMenu` | `right_click_menu(id)` |
| `Popover` | `Popover::new()` |
| `PopoverMenu` | `PopoverMenu::new(id)` |
| `Tooltip` | `Tooltip::new(title)` |
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
| `Facepile` | `Facepile::new(faces)` |
| `Chip` | `Chip::new(label)` |
| `DiffStat` | `DiffStat::new(id, added, removed)` |
| `Disclosure` | `Disclosure::new(id, is_open)` |
| `GradientFade` | `GradientFade::new(base_bg, hover_bg, active_bg)` |
| `Vector` | `Vector::new(vector, width, height)` |
| `KeyBinding` | `KeyBinding::new(action, focus_handle, cx)` |
| `KeybindingHint` | `KeybindingHint::new(keybinding, background_color)` |
| `NavigableEntry` / `Navigable` | `NavigableEntry::new(scroll_handle, cx)`, `Navigable::new(child)` |
| `AiSettingItem` | `AiSettingItem::new(id, label, status, source)` |
| `AgentSetupButton` | `AgentSetupButton::new(id)` |
| `ThreadItem` | `ThreadItem::new(id, title)` |
| `ConfiguredApiCard` | `ConfiguredApiCard::new(label)` |
| `CollabNotification` | `CollabNotification::new(avatar_uri, accept_button, dismiss_button)` |
| `UpdateButton` | `UpdateButton::new(icon, message)` |

### Repo gerçekliği notları

- Kaynaklarda `Stack` ve `Group` adları public struct değil. Mevcut API
  `h_flex`, `v_flex`, `h_group*`, `v_group*` helper fonksiyonlarıdır.
- `Image` için `crates/ui/src/components/image.rs` içinde public `Image` struct
  yok. Bu dosya `Vector` ve `VectorName` export eder. Raster görsel için GPUI
  tarafındaki `img(...)` ve `ImageSource` ayrıca anlatılmalı.
- `Notification` adı `crates/ui/src/components/notification.rs` içinde public
  component olarak yok; dosya `AlertModal` ve `AnnouncementToast` modüllerini
  re-export eden bir modül dosyasıdır.
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

### Doğrulama komutları

Bu envanter şu komutlarla doğrulandı:

```sh
rg --files crates/ui/src/components crates/ui/src/styles crates/ui/src/traits crates/component/src crates/icons/src
rg -n "impl Component for |impl<T: ButtonBuilder.*Component" crates/ui/src/components crates/ui/src/styles crates/component/src
rg -n "pub fn (new|build|dot|checkbox|switch|divider|vertical_divider|h_flex|v_flex|h_group|right_click_menu|sticky_items|indent_guides)\\b" crates/ui/src/components crates/ui/src/styles/typography.rs
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
`Color::Default`, `Muted`, `Accent`, `Success`, `Warning`, `Error`, `Info` ve
version-control renkleri etkin temadan gerçek HSLA değerine çevrilir. Özel HSLA
gerektiğinde `Color::Custom` vardır, ancak tutarlılık için semantik renkler
önceliklidir.

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

### Layout yardımcıları

`h_flex()` yatay flex container, `v_flex()` dikey flex container üretir. Bu
yardımcılar raw `div()` yerine okunabilirliği artırır ve Zed UI örneklerinde
yaygın kullanılır.

`h_group*` ve `v_group*` helper'ları yön ve tutarlı gap seçimini birlikte verir.
Tekrarlanan toolbar, ayar satırı veya kompakt kontrol gruplarında bu helper'ları
tercih edin.

Raw `div()` hala geçerlidir. Özel grid, absolute positioning, canvas veya çok
spesifik style gerektiğinde doğrudan `div()` kullanmak daha açıktır.

### Component preview

Component preview sistemi, bileşen varyantlarını Zed içinde görsel olarak
incelemek için kullanılır. Preview'a dahil edilecek küçük bir örnek component
şu yapıyı izler:

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

## 3. Metin ve İkon Bileşenleri

Metin ve ikon bileşenleri Zed UI içinde en sık kullanılan yapı taşlarıdır. Başlık,
etiket, arama sonucu, durum satırı, liste item'i, toolbar ve bildirim gibi çoğu
kompozisyon bu bileşenlerden başlar.

Genel kural:

- Yapısal başlık için `Headline`.
- Normal UI metni için `Label`.
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

- `ButtonCommon`: `.style(...)`, `.size(...)`, `.tooltip(...)`,
  `.tab_index(...)`, `.layer(...)`, `.track_focus(...)`.
- `Clickable`: `.on_click(...)`, `.cursor_style(...)`.
- `Disableable`: `.disabled(bool)`.
- `Toggleable`: `.toggle_state(bool)`.
- `SelectableButton`: `.selected_style(ButtonStyle)`.
- `FixedWidth`: `.width(...)`, `.full_width()`.
- `VisibleOnHover`: `.visible_on_hover(group_name)`.

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
  `.full_width()`, `.on_click(...)`.

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
  `.full_width()`.

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
- Group builder'ları: `.style(...)`, `.size(...)`, `.selected_index(...)`,
  `.auto_width()`, `.label_size(...)`, `.tab_index(&mut isize)`,
  `.width(...)`, `.full_width()`.

Davranış:

- `RenderOnce` implement eder.
- Her entry bir `ButtonLike` olarak render edilir.
- `selected_index` veya entry'nin `.selected(true)` durumu seçili görünümü
  tetikler.
- Seçili görünüm `ButtonStyle::Tinted(TintColor::Accent)` ve accent label/icon
  rengiyle çizilir.

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
  `.selectable(bool)`, `.submenu(...)`, `.submenu_with_icon(...)`,
  `.keep_open_on_confirm(bool)`, `.fixed_width(...)`, `.key_context(...)`.
- Entry builder'ları: `ContextMenuEntry::new(label).icon(...).toggleable(...)`
  `.action(...)`, `.handler(...)`, `.secondary_handler(...)`,
  `.disabled(...)`, `.documentation_aside(...)`.

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
- Export: `ui::PopoverMenu`, `ui::PopoverMenuHandle`
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

- Trigger tipi `IntoElement + Clickable + Toggleable + 'static` olmalıdır.
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
- `StickyCandidate` trait'i: `fn depth(&self) -> usize`
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
- `RenderIndentGuideParams`: `indent_guides`, `indent_size`, `item_height`
- `RenderedIndentGuide`: `bounds`, `layout`, `is_active`, `hitbox`
- `IndentGuideLayout`: `offset`, `length`, `continues_offscreen`

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
  guide'ları, custom render ve click davranışı.
- `../zed/crates/outline_panel/src/outline_panel.rs`: outline list indent
  guide'ları.
- `../zed/crates/git_ui/src/git_panel.rs`: hiyerarşik git panel satırları.

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

## 9. Veri ve Tablo Bileşenleri

Zed UI tarafında tablo ihtiyacı için ana giriş noktası `Table` bileşenidir.
Küçük ve sabit satırlı tabloları doğrudan `.row(...)` ile, büyük tabloları ise
GPUI'nin sanallaştırılmış liste altyapısına bağlanan `.uniform_list(...)` veya
`.variable_row_height_list(...)` ile render eder.

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

    fn replace_rows(&mut self, rows: Vec<LogRow>) {
        self.list_state.reset(rows.len());
        self.rows = rows;
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
- `render_table_header(headers, table_context, resize_info, entity_id, cx)`
- `render_table_row(row_index, items, table_context, window, cx)`
- `HeaderResizeInfo::from_redistributable(&columns_state, cx)`
- `HeaderResizeInfo::from_resizable(&columns_state, cx)`
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
- `ModalHeader::new().headline(...).description(...).icon(...).show_dismiss_button(...)`
- `ModalFooter::new().start_slot(...).end_slot(...)`
- `Section::new()`, `Section::new_contained()`, `.header(...)`, `.meta(...)`,
  `.padded(bool)`
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

Dikkat edilecekler:

- `Modal` yalnızca içerik shell'idir; açma/kapama lifecycle'ı modal host veya
  parent view tarafından yönetilir.
- Header dismiss/back button'ları `menu::Cancel` dispatch eder; parent context bu
  aksiyonu ele almalıdır.
- Section içinde çok sayıda ayar satırı varsa body scroll handle'ı verin.

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
