# 10. Tab Bileşenleri

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

## Tab

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

## TabBar

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

## Tab Kompozisyon Örnekleri

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

