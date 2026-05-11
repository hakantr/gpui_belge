# Zed UI Bileşenleri Kullanım Rehberi

Bu rehber, `../zed` çalışma ağacındaki Zed UI bileşenlerine göre hazırlanır
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
| Veri | `RedistributableColumnsState` | `crates/ui/src/components/redistributable_columns.rs` | `ui::RedistributableColumnsState` | Hayır | State |
| Veri | `render_table_row` / `render_table_header` | `crates/ui/src/components/data_table.rs` | `ui::render_table_row`, `ui::render_table_header` | Hayır | Fonksiyon |
| Veri | `bind_redistributable_columns` | `crates/ui/src/components/redistributable_columns.rs` | `ui::bind_redistributable_columns` | Hayır | Fonksiyon |
| Veri | `render_redistributable_columns_resize_handles` | `crates/ui/src/components/redistributable_columns.rs` | `ui::render_redistributable_columns_resize_handles` | Hayır | Fonksiyon |
| Feedback | `Banner` | `crates/ui/src/components/banner.rs` | `ui::Banner` | Hayır | Evet |
| Feedback | `Callout` | `crates/ui/src/components/callout.rs` | `ui::Callout` | Hayır | Evet |
| Feedback | `Modal` | `crates/ui/src/components/modal.rs` | `ui::Modal` | Hayır | Hayır |
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
| `TreeViewItem` | `TreeViewItem::new(id, label)` |
| `sticky_items` | `sticky_items(view, item_count, render_item, item_size, ...)` |
| `indent_guides` | `indent_guides(indent_size, colors)` |
| `Tab` | `Tab::new(id)` |
| `TabBar` | `TabBar::new(id)` |
| `h_flex` / `v_flex` | `h_flex()`, `v_flex()` |
| `h_group*` / `v_group*` | `h_group_sm()`, `h_group()`, `h_group_lg()`, `h_group_xl()` ve dikey karşılıkları |
| `Divider` | `divider()`, `vertical_divider()` |
| `Table` | `Table::new(cols)` |
| `TableInteractionState` | `TableInteractionState::new(cx)` |
| `RedistributableColumnsState` | `RedistributableColumnsState::new(...)` |
| `Banner` | `Banner::new()` |
| `Callout` | `Callout::new()` |
| `Modal` | `Modal::new(id, scroll_handle)` |
| `AlertModal` | `AlertModal::new(id)` |
| `AnnouncementToast` | `AnnouncementToast::new()` |
| `CountBadge` | `CountBadge::new(count)` |
| `Indicator` | `Indicator::dot()` |
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

- Yol haritasındaki `Stack` ve `Group` adları public struct değil. Mevcut API
  `h_flex`, `v_flex`, `h_group*`, `v_group*` helper fonksiyonlarıdır.
- Yol haritasındaki `Image` için `crates/ui/src/components/image.rs` içinde public
  `Image` struct yok. Bu dosya `Vector` ve `VectorName` export eder. Raster
  görsel için GPUI tarafındaki `img(...)` ve `ImageSource` ayrıca anlatılmalı.
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
  tipleri kaynakta public olsa da yol haritasının ana listesinde yoktur. İlgili
  bölümlerde yalnızca ana bileşenleri açıklamayı destekledikleri ölçüde ele
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
