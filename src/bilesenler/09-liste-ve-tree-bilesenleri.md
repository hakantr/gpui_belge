# 9. Liste ve Tree Bileşenleri

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

## List

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

## ListItem

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

## ListHeader

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

## ListSubHeader

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

## ListSeparator

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

## ListBulletItem

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

## TreeViewItem

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

## StickyItems

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

## IndentGuides

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

## Liste ve Tree Kompozisyon Örnekleri

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

