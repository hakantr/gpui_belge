# 10. Tab Bileşenleri

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Tab` | `description`, `extend`, `interactivity`, `scope`, `toggle_state` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Tab` | Metotlar | `close_side`, `container_height`, `content_height`, `end_slot`, `new`, `position`, `start_slot` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Tab bileşenleri yatay bir navigation yüzeyi kurmak için kullanırsın. `Tab` tek bir sekmeyi çizer; `TabBar` ise sekmeleri, soldaki ve sağdaki action alanlarını ve yatay scroll container'ını birlikte düzenler. Seçili tab, aktif index, close davranışı ve tab pozisyonu gibi bilgiler view state'i tarafından hesaplanır. Tab bileşenleri bu bilgiyi kendi başına üretmez.

Hangi durumda hangisini seçeceğin için kısa özet:

- Tek bir tab yüzeyi için `Tab` yeterlidir.
- Tab koleksiyonu, soldaki/sağdaki toolbar kontrolleri ve yatay scroll alanı birlikte çizilecekse `TabBar` doğru üst yapıdır.
- Dosya veya editor sekmeleri gibi bitişik border davranışının önemli olduğu durumlarda, her tab için doğru `TabPosition` değerinin vermen gerekir.
- Tab içeriğinde icon, dirty indicator veya close/pin butonu gerekiyorsa `start_slot(...)` ve `end_slot(...)` yardımcıları kullanırsın.

## Tab

Kaynak:

- Tanım: `../zed/crates/ui/src/components/tab.rs`
- Export: `ui::Tab`, `ui::TabPosition`, `ui::TabCloseSide`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Tab`.

Ne zaman kullanırsın:

- Editor, pane, preview veya ayar ekranında yatay bir sekme satırı çizilirken.
- Seçili ve seçili olmayan tabların Zed tema renkleriyle uyumlu görünmesi gerektiğinde.
- Tabın solunda bir status veya icon, sağında close/pin gibi action butonu bulunması istendiğinde.

Ne zaman kullanmazsın:

- Bir segmented control veya mod seçici için `ToggleButtonGroup` daha doğru bir araçtır.
- İçeriği değiştirmeyen basit toolbar eylemleri için `Button` veya `IconButton` yeterlidir.
- Dikey bir navigation için `ListItem` veya `TreeViewItem` daha uygundur.

Temel API:

- Constructor: `Tab::new(id)`.
- Builder'lar: `.position(TabPosition)`, `.close_side(TabCloseSide)`, `.start_slot(...)`, `.end_slot(...)`, `.toggle_state(bool)`.
- Ölçü yardımcıları: `Tab::content_height(cx)`, `Tab::container_height(cx)`.
- `TabPosition`: `First`, `Middle(Ordering)`, `Last`.
- `TabCloseSide`: `Start`, `End`.
- `InteractiveElement` ve `StatefulInteractiveElement` implement eder; bu sayede `.on_click(...)`, drag/drop ve tooltip gibi GPUI interactivity builder'ları doğrudan kullanabilirsin.

Tab yerleşim enum'ları:

| API | Rol |
| :-- | :-- |
| `TabPosition` | Tab'ın satırdaki ilk, orta veya son konumunu bildirir; `Middle(Ordering)` aktif tab'a göre sol/sağ border davranışını taşır. |
| `TabCloseSide` | Close veya aksiyon slot'unun `Start` ya da `End` tarafında görüneceğini seçer. |

Davranış:

- `RenderOnce`, `Toggleable` ve `ParentElement` implement eder.
- `toggle_state(true)`, aktif tab renklerini ve border düzenini seçer.
- `TabPosition` aktif tab çevresindeki border'ları belirler. `Middle(Ordering)` içindeki `Ordering`, ilgili tabın seçili taba göre solda mı yoksa sağda mı olduğunu anlatır; bu bilgi border'ın hangi tarafta görüneceğini etkiler.
- `close_side(TabCloseSide::Start)` çağrısı, start ve end slot'ların görsel tarafını değiştirir. Workspace sekmelerinde close butonunun sol ya da sağ tarafta görünmesi bu seçim üzerinden uygularsın.
- Child içerik, `text_color(...)` atanmış bir `h_flex` içinde çizilir.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/workspace/src/pane.rs`: editor/pane tab render'ı; close side, drag/drop, pinned tab ve sağ tık context menu davranışlarıyla birlikte uygularsın.
- Component preview: `../zed/crates/ui/src/components/tab.rs`.

Dikkat edeceğin noktalar:

- `Tab`, aktif tabı kendi başına değiştirmez. Click handler içinde view state güncellenir ve ardından `cx.notify()` çağrılır.
- `TabPosition` verilmediğinde varsayılan değer `First` olur. Bu yüzden çoklu bir tab bar içinde her tab için doğru pozisyon hesaplanmalıdır; aksi halde border'lar tutarsız görünür.
- Close butonu gibi `end_slot` kontrolleri için ayrı ve sabit bir id kullanılması beklenir; aksi halde tıklamalar yanlış elemana yönlendirilebilir.
- Tab label'ının aktif veya pasif text rengini doğrudan miras almasını istemek gerekiyorsa, basit bir string child kullanmak yeterlidir. Özel label veya truncation gerektiğinde renk davranışının ayrıca kontrol etmen gerekir.
- `Tab::new("")` gibi boş bir id yalnızca özel render proxy'lerinde kullanırsın. Normal listelerde sabit bir id tercih edersin.

## TabBar

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `TabBar` | `description`, `extend`, `name`, `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `TabBar` | Metotlar | `end_child`, `end_children`, `end_children_mut`, `new`, `start_child`, `start_children`, `start_children_mut`, `track_scroll` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Kaynak:

- Tanım: `../zed/crates/ui/src/components/tab_bar.rs`
- Export: `ui::TabBar`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for TabBar`.

Ne zaman kullanırsın:

- Birden fazla `Tab` öğesinin ortak bir tab bar yüzeyinde gösterilmesi istendiğinde.
- Tabların solunda navigation veya history, sağında create veya ayarlar gibi toolbar eylemleri yer alacaksa.
- Tab listesi yatayda taşma riski taşıyorsa ve scroll state'inin takip edilmesi gerekiyorsa.

Ne zaman kullanmazsın:

- Tek bir segment kontrol veya küçük bir mod seçici için `ToggleButtonGroup` çok daha doğru bir tercihtir.
- Dikey bir navigation veya tree için `List` veya `TreeViewItem` daha uygundur.

Temel API:

- Constructor: `TabBar::new(id)`.
- Builder'lar: `.track_scroll(&ScrollHandle)`, `.start_child(...)`, `.start_children(...)`, `.end_child(...)`, `.end_children(...)`.
- Düşük seviye mutator'lar: `.start_children_mut() -> &mut SmallVec<[AnyElement; 2]>` ve `.end_children_mut() -> &mut SmallVec<[AnyElement; 2]>`. Bunlar builder zinciri dışında, parent state içinden start veya end slot listesinin elle değiştirilmesi gerektiğinde kullanırsın. Normal kompozisyonda tercih edilmezler.
- `ParentElement` implement eder; tablar `.child(...)` veya `.children(...)` ile orta scroll alanına eklersin.

Davranış:

- `RenderOnce` implement eder.
- Start children varsa, sol tarafta border'lı ve flex-none bir alan oluşturulur.
- Orta tab alanı `overflow_x_scroll()` kullanan bir `h_flex` içinde render edilir.
- End children varsa, sağ tarafta border'lı ve flex-none bir alan oluşturulur.
- `.track_scroll(...)`, internal tab scroll container'ına bir scroll handle bağlar.
- TabBar, çocuk tabların `TabPosition` veya selected state'ini hesaplamaz; bu sorumluluk view tarafına aittir.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/workspace/src/pane.rs`: tek satır, pinned/unpinned ve iki satırlı tab bar kompozisyonları.
- Component preview: `../zed/crates/ui/src/components/tab_bar.rs`.

Dikkat edeceğin noktalar:

- Start ve end children, tab scroll alanına dahil değildir. Bu yüzden navigation ve global tab eylemleri için uygundur; tabların kendisiyle karışmadan ayrı bir alanda yaşar.
- Tabların taşması bekleniyorsa, bir `ScrollHandle` view state'inde saklanır ve `.track_scroll(...)` ile bağlanır.
- Pinned ile unpinned tabları ayrı satırlarda göstermek gerekiyorsa, iki ayrı `TabBar` compose edilir. Kaynakta workspace pane tam olarak bu yaklaşımı kullanır.

## Tab Kompozisyon Örnekleri

Aşağıdaki örnek close butonu solda kalan bir tab gösterir. `TabCloseSide::Start` seçildiğinde start slot ile end slot'un görsel tarafları yer değiştirir:

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

Scroll handle bağlanmış bir tab bar örneğinde ise scroll davranışı view state'inde tutulan bir `ScrollHandle` üzerinden yönetilir:

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

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `TabPosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `First`, `Last`, `Middle` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `TabCloseSide`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `End`, `Start` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
