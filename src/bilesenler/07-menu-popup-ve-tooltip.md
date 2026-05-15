# 7. Menü, Popup ve Tooltip

Bu bölüm, bir kontrolün arkasından geçici yüzey açan bileşenleri anlatır. Form
ve seçim state'i hazır kabul edilir; burada odak, seçenekleri nasıl sunacağınız,
menü içeriğini hangi modelle kuracağınız ve popup lifecycle'ını nasıl
yöneteceğinizdir.

Genel seçim rehberi:

- Seçili değeri trigger üzerinde gösteren seçenek listesi için `DropdownMenu`.
- Menü içeriği, entry, separator, submenu ve action dispatch için `ContextMenu`.
- Buton/ikon trigger ile açılan managed view menüleri için `PopoverMenu`.
- İkincil tıklamayla açılan bağlam menüsü için `right_click_menu`.
- Popup yüzeyinin içeriğini çizmek için `Popover`.
- Kısa hover açıklamaları ve shortcut bilgisini göstermek için `Tooltip`.

Menü ve popup bileşenleri değer saklamaz; entry handler'ları view veya model
state'ini güncellemeli, popup'ın açılma/kapanma davranışı ise ilgili menu,
popover veya parent lifecycle tarafından yönetilmelidir.

## DropdownMenu

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

## ContextMenu

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

## PopoverMenu

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

## RightClickMenu

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

## Popover

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

## Tooltip

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

## Menü ve Popup Kompozisyon Örnekleri

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

