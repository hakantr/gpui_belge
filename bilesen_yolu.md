# Zed UI Bileşenleri Çalışma Yol Haritası

Bu dosya, `rehber.md` içindeki GPUI kullanım haritasına paralel olarak Zed'in
`crates/ui` merkezli bileşenleri için ayrıntılı bir kullanım rehberi ve örnek kod
seti hazırlamak üzere izlenecek yolu tanımlar.

hazırlanan bilesen rehberinin adı: `bilesen_rehberi.md`

Çalışma deposu ve kaynak konumu:

- Bu yol haritası ve `bilesen_rehberi.md`, `../gpui_belge` dokümantasyon
  deposunda tutulur ve bundan sonraki çalışmalar bu depo üzerinde yapılır.
- Zed kaynak dosyaları `../zed` altında bulunur. Bileşen API'leri, export yolları
  ve kullanım örnekleri bu dizindeki kaynak dosyalardan kontrol edilmelidir.
- Komut örneklerinde `crates/...` ile başlayan yollar, `../zed` deposuna göre
  verilmiştir.

Hazırlandığı çalışma ağacı referansı:

- `git rev-parse --short HEAD`: `db6039d815`
- Ana kapsam: `crates/ui`, `crates/component`, `crates/icons`, `crates/theme`
- Yardımcı kapsam: `crates/ui_input`, `crates/notifications`, `crates/collab_ui`

Amaç, her bileşen için şu soruları tek bir yerde cevaplayan bir çalışma üretmektir:

- Bileşen hangi kullanıcı arayüzü problemi için kullanılmalı?
- Hangi dosyada tanımlı, nereden export ediliyor, hangi prelude ile çağrılıyor?
- Oluşturucu ve builder API'leri nelerdir?
- State, focus, action, event, theme ve layout ile nasıl etkileşir?
- Zed içinde gerçek kullanım örnekleri nerede bulunur?
- Minimum, stateful ve kompozisyon örnekleri nasıl yazılır?
- Bileşeni yanlış kullanmaya açık noktalar nelerdir?

## 1. Nihai Çıktılar

Bu yol haritası tamamlandığında aşağıdaki çıktılar oluşmalı:

1. **Bileşen kullanım rehberi**: `rehber.md` seviyesinde ayrıntılı, kaynak dosya
   odaklı, kategori bazlı bir doküman.
2. **Kaynak indeksi**: Her bileşen için tanım dosyası, export yolu, ilişkili trait,
   enum ve yardımcı tipler.
3. **Örnek kod kataloğu**: Her kategori için küçük, okunabilir ve mümkün olduğunda
   derlenebilir Rust örnekleri.
4. **Kompozisyon örnekleri**: Ayarlar satırı, toolbar, dropdown menü, tablo,
   bildirim ve AI/collab kartı gibi gerçek Zed ekranlarına benzeyen örnekler.
5. **Doğrulama listesi**: Kod örneklerinin `ui::prelude::*`, component preview
   düzeni, tema token'ları ve GPUI event modeliyle uyumunu kontrol eden liste.

## 2. Rehber Bölüm Şablonu

Her bileşen başlığı aynı şablonla hazırlanmalı. Bu, uzun rehberde gezinmeyi ve
bileşenleri karşılaştırmayı kolaylaştırır.

```text
## BileşenAdı

Kaynak:
- Tanım: ...
- Export: ...
- İlgili tipler: ...

Ne zaman kullanılır:
- ...

Ne zaman kullanılmaz:
- ...

Temel API:
- Constructor: ...
- Builder yöntemleri: ...
- Trait'ler: ...

Davranış:
- Render modeli: RenderOnce / Render / Entity
- Event/focus/action ilişkisi
- Theme, Color, Severity, IconName, LabelSize gibi token'lar

Örnekler:
- Minimum örnek
- Varyant/stil örneği
- Stateful veya callback örneği
- Başka bileşenlerle kompozisyon örneği

Zed içinden kullanım:
- ...

Dikkat edilecekler:
- ...
```

## 3. Kaynak Haritası

Bu tablo, rehber çalışmasında ilk bakılacak dosyaları gösterir. API ayrıntıları
her fazda ilgili dosyadan doğrulanmalıdır.

| Kategori | Bileşen | Ana kaynak |
| :-- | :-- | :-- |
| Metin | `Label` | `crates/ui/src/components/label/label.rs` |
| Metin | `Headline` | `crates/ui/src/styles/typography.rs` |
| Metin | `HighlightedLabel` | `crates/ui/src/components/label/highlighted_label.rs` |
| Metin | `LoadingLabel` | `crates/ui/src/components/label/loading_label.rs` |
| Metin | `SpinnerLabel` | `crates/ui/src/components/label/spinner_label.rs` |
| Buton | `Button` | `crates/ui/src/components/button/button.rs` |
| Buton | `IconButton` | `crates/ui/src/components/button/icon_button.rs` |
| Buton | `SelectableButton` | `crates/ui/src/components/button/button_like.rs` |
| Buton | `ButtonLike` | `crates/ui/src/components/button/button_like.rs` |
| Buton | `ButtonLink` | `crates/ui/src/components/button/button_link.rs` |
| Buton | `CopyButton` | `crates/ui/src/components/button/copy_button.rs` |
| Buton | `SplitButton` | `crates/ui/src/components/button/split_button.rs` |
| Buton | `ToggleButton` | `crates/ui/src/components/button/toggle_button.rs` |
| İkon | `Icon` | `crates/ui/src/components/icon.rs` |
| İkon | `DecoratedIcon` | `crates/ui/src/components/icon/decorated_icon.rs` |
| İkon | `IconDecoration` | `crates/ui/src/components/icon/icon_decoration.rs` |
| İkon | `IconName` | `crates/icons/src/icons.rs`, `crates/ui/src/components/icon.rs` üzerinden re-export |
| İkon | `IconSize` | `crates/ui/src/components/icon.rs` |
| Form / Toggle | `Checkbox` | `crates/ui/src/components/toggle.rs` |
| Form / Toggle | `Switch` | `crates/ui/src/components/toggle.rs` |
| Form / Toggle | `SwitchField` | `crates/ui/src/components/toggle.rs` |
| Form / Toggle | `DropdownMenu` | `crates/ui/src/components/dropdown_menu.rs` |
| Menü / Popup | `ContextMenu` | `crates/ui/src/components/context_menu.rs` |
| Menü / Popup | `RightClickMenu` | `crates/ui/src/components/right_click_menu.rs` |
| Menü / Popup | `Popover` | `crates/ui/src/components/popover.rs` |
| Menü / Popup | `PopoverMenu` | `crates/ui/src/components/popover_menu.rs` |
| Menü / Popup | `Tooltip` | `crates/ui/src/components/tooltip.rs` |
| Liste / Tree | `List` | `crates/ui/src/components/list/list.rs` |
| Liste / Tree | `ListItem` | `crates/ui/src/components/list/list_item.rs` |
| Liste / Tree | `ListHeader` | `crates/ui/src/components/list/list_header.rs` |
| Liste / Tree | `ListSubHeader` | `crates/ui/src/components/list/list_sub_header.rs` |
| Liste / Tree | `ListSeparator` | `crates/ui/src/components/list/list_separator.rs` |
| Liste / Tree | `TreeViewItem` | `crates/ui/src/components/tree_view_item.rs` |
| Liste / Tree | `StickyItems` | `crates/ui/src/components/sticky_items.rs` |
| Liste / Tree | `IndentGuides` | `crates/ui/src/components/indent_guides.rs` |
| Tab | `Tab` | `crates/ui/src/components/tab.rs` |
| Tab | `TabBar` | `crates/ui/src/components/tab_bar.rs` |
| Layout Yardımcıları | `h_flex` | `crates/ui/src/components/stack.rs` |
| Layout Yardımcıları | `v_flex` | `crates/ui/src/components/stack.rs` |
| Layout Yardımcıları | `h_group*` | `crates/ui/src/components/group.rs` |
| Layout Yardımcıları | `v_group*` | `crates/ui/src/components/group.rs` |
| Layout Yardımcıları | `Stack` | `crates/ui/src/components/stack.rs`; mevcut kaynakta `h_flex` / `v_flex` helper'ları doğrulandı |
| Layout Yardımcıları | `Group` | `crates/ui/src/components/group.rs`; mevcut kaynakta `h_group*` / `v_group*` helper'ları doğrulandı |
| Layout Yardımcıları | `Divider` | `crates/ui/src/components/divider.rs` |
| Veri | `Table` | `crates/ui/src/components/data_table.rs` |
| Veri | `TableInteractionState` | `crates/ui/src/components/data_table.rs` |
| Veri | `RedistributableColumnsState` | `crates/ui/src/components/redistributable_columns.rs` |
| Veri | `render_table_row` | `crates/ui/src/components/data_table.rs` |
| Veri | `render_table_header` | `crates/ui/src/components/data_table.rs` |
| Feedback | `Banner` | `crates/ui/src/components/banner.rs` |
| Feedback | `Callout` | `crates/ui/src/components/callout.rs` |
| Feedback | `Modal` | `crates/ui/src/components/modal.rs` |
| Feedback | `AlertModal` | `crates/ui/src/components/notification/alert_modal.rs` |
| Feedback | `AnnouncementToast` | `crates/ui/src/components/notification/announcement_toast.rs` |
| Feedback | `Notification` | `crates/ui/src/components/notification.rs` |
| Feedback | `CountBadge` | `crates/ui/src/components/count_badge.rs` |
| Feedback | `Indicator` | `crates/ui/src/components/indicator.rs` |
| Feedback | `ProgressBar` | `crates/ui/src/components/progress/progress_bar.rs` |
| Feedback | `CircularProgress` | `crates/ui/src/components/progress/circular_progress.rs` |
| Diğer | `Avatar` | `crates/ui/src/components/avatar.rs` |
| Diğer | `Facepile` | `crates/ui/src/components/facepile.rs` |
| Diğer | `Chip` | `crates/ui/src/components/chip.rs` |
| Diğer | `DiffStat` | `crates/ui/src/components/diff_stat.rs` |
| Diğer | `Disclosure` | `crates/ui/src/components/disclosure.rs` |
| Diğer | `GradientFade` | `crates/ui/src/components/gradient_fade.rs` |
| Diğer | `Image` | `crates/ui/src/components/image.rs`; mevcut kaynakta `Vector` / `VectorName`, raw image için `gpui::img` ve `ImageSource` doğrulanmalı |
| Diğer | `KeyBinding` | `crates/ui/src/components/keybinding.rs` |
| Diğer | `KeybindingHint` | `crates/ui/src/components/keybinding_hint.rs` |
| Diğer | `Navigable` | `crates/ui/src/components/navigable.rs` |
| Diğer | `bind_redistributable_columns` | `crates/ui/src/components/redistributable_columns.rs` |
| Diğer | `render_redistributable_columns_resize_handles` | `crates/ui/src/components/redistributable_columns.rs` |
| AI / Collab Özel | `AiSettingItem` | `crates/ui/src/components/ai/ai_setting_item.rs` |
| AI / Collab Özel | `AgentSetupButton` | `crates/ui/src/components/ai/agent_setup_button.rs` |
| AI / Collab Özel | `ThreadItem` | `crates/ui/src/components/ai/thread_item.rs` |
| AI / Collab Özel | `ConfiguredApiCard` | `crates/ui/src/components/ai/configured_api_card.rs` |
| AI / Collab Özel | `CollabNotification` | `crates/ui/src/components/collab/collab_notification.rs` |
| AI / Collab Özel | `UpdateButton` | `crates/ui/src/components/collab/update_button.rs` |

## 4. Çalışma Fazları

### Faz 0: Envanter ve sınırları netleştirme

Amaç: Bileşen listesini repo gerçekliğiyle eşleştirmek.

Yapılacaklar:

- `crates/ui/src/components.rs` export listesini temel al.
- `crates/ui/src/prelude.rs` içinde doğrudan gelen tipleri ayrıca işaretle.
- `Component`, `RenderOnce`, `ParentElement`, `Clickable`, `Toggleable`,
  `Disableable`, `Fixed`, `VisibleOnHover`, `StyledExt` gibi ortak trait'leri çıkar.
- Her bileşen için constructor, public builder yöntemi, ilişkili enum ve slot
  tiplerini `rg` ile listele.
- Component preview desteği olan tipleri `impl Component for ...` üzerinden işaretle.

Teslim kriteri:

- Kaynak haritasında her satırın dosya yolu doğrulanmış olmalı.
- Rehberde ele alınmayacak veya farklı crate'e ait olan tipler açıkça not edilmeli.

### Faz 1: Ortak temel bölümünü yazma

Amaç: Bileşenleri okumadan önce gereken ortak Zed UI bilgisini tek yerde toplamak.

Yazılacak başlıklar:

- `ui::prelude::*` ne getirir?
- `gpui::prelude::*` ile `ui::prelude::*` farkı nedir?
- Zed UI bileşenlerinde `RenderOnce` neden yaygın?
- `ElementId`, `SharedString`, `AnyElement`, `AnyView`, `Entity<ContextMenu>` ne
  zaman gerekir?
- `Color`, `Severity`, `IconName`, `IconSize`, `LabelSize`, `ButtonSize`,
  `ButtonStyle`, `ToggleState` gibi tasarım sistemi token'ları nasıl seçilir?
- Component preview sistemi nasıl çalışır?

Örnek üretilecek konu:

```rust
use ui::prelude::*;

fn render_status_title() -> impl IntoElement {
    v_flex()
        .gap_1()
        .child(Headline::new("Project Settings").size(HeadlineSize::Medium))
        .child(
            h_flex()
                .gap_1()
                .child(Icon::new(IconName::Check).size(IconSize::Small).color(Color::Success))
                .child(Label::new("Saved").size(LabelSize::Small).color(Color::Muted)),
        )
}
```

### Faz 2: Metin ve ikon bileşenleri

Kapsam:

- `Label`, `Headline`, `HighlightedLabel`, `LoadingLabel`, `SpinnerLabel`
- `Icon`, `DecoratedIcon`, `IconDecoration`, `IconName`, `IconSize`

Yazılacaklar:

- Metin hiyerarşisi: `Headline` ile başlık, `Label` ile UI metni.
- `LabelCommon` üzerinden boyut, ağırlık, renk, italic, underline, alpha ve
  truncation kullanımı.
- Arama veya filtre vurgusu için `HighlightedLabel`.
- Async veya arka plan işlem metinleri için `LoadingLabel` ve `SpinnerLabel`.
- `IconName` kaynakları, embedded SVG ve external path ayrımı.
- `IconSize` değerlerinin rem ve px davranışı.
- `DecoratedIcon` ve `IconDecoration` ile durum veya badge kompozisyonu.

Örnek üretilecek konu:

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_search_result(highlight_indices: Vec<usize>) -> impl IntoElement {
    h_flex()
        .gap_2()
        .child(Icon::new(IconName::MagnifyingGlass).size(IconSize::Small))
        .child(
            HighlightedLabel::new("Open Recent Project", highlight_indices)
                .size(LabelSize::Small),
        )
}
```

Doğrulama:

- `HighlightedLabel` constructor imzası kaynak dosyadan tekrar kontrol edilmeli.
- `IconName` örneğinde kullanılan ikon adının `crates/icons/src/icons.rs` içinde
  var olduğu doğrulanmalı.

### Faz 3: Buton ailesi

Kapsam:

- `Button`, `IconButton`, `SelectableButton`, `ButtonLike`
- `ButtonLink`, `CopyButton`, `SplitButton`, `ToggleButton`

Yazılacaklar:

- `Button` ve `IconButton` ayrımı.
- Daha özel içerik gerektiğinde `ButtonLike` kullanımı.
- `SelectableButton` trait'inin `Button`, `IconButton`, `ButtonLike` üzerindeki
  etkisi.
- `ButtonStyle`, `TintColor`, `ButtonSize`, `start_icon`, `end_icon`,
  `key_binding`, `loading`, `disabled`, `toggle_state` örnekleri.
- `CopyButton` gibi davranış taşıyan bileşenlerde hatayı sessizce yutmama kuralı.
- `SplitButton` ve `PopoverMenu` ilişkisi.

Örnek üretilecek konu:

```rust
use ui::prelude::*;

fn render_toolbar(cx: &mut Context<MyView>) -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(
            Button::new("save-project", "Save")
                .start_icon(Icon::new(IconName::Check))
                .on_click(cx.listener(|this: &mut MyView, _, _, cx| {
                    this.save_requested = true;
                    cx.notify();
                })),
        )
        .child(
            IconButton::new("toggle-sidebar", IconName::Menu)
                .toggle_state(true)
                .on_click(cx.listener(|this: &mut MyView, _, _, cx| {
                    this.sidebar_open = !this.sidebar_open;
                    cx.notify();
                })),
        )
}
```

Doğrulama:

- Örnek view içinde `save_requested` ve `sidebar_open` alanları tanımlanmalı.
- `on_click` closure argümanları ilgili bileşen trait imzasıyla eşleşmeli.

### Faz 4: Form, toggle, menü ve popup

Kapsam:

- `Checkbox`, `Switch`, `SwitchField`, `DropdownMenu`
- `ContextMenu`, `RightClickMenu`, `Popover`, `PopoverMenu`, `Tooltip`

Yazılacaklar:

- `ToggleState` değerleri: `Selected`, `Unselected`, `Indeterminate`.
- `Checkbox` ve `Switch` için handler imzaları.
- `SwitchField` içinde label, description, disabled ve layout ilişkisi.
- `ContextMenu::build` ile menü entity'si oluşturma.
- `DropdownMenu` için trigger, menu, icon, full width ve disabled davranışı.
- `Popover` ile içerik, `PopoverMenu` ile açılma/kapanma yönetimi ayrımı.
- `RightClickMenu` için secondary click ve context menu kullanım yerleri.
- `Tooltip` için sadece açıklama değil, keyboard hint ve meta bilgi kompozisyonu.

Örnek üretilecek konu:

```rust
use ui::prelude::*;
use ui::ContextMenu;

fn build_sort_menu(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |menu, _, _| {
        menu.header("Sort by")
            .entry("Name", None, |_, _| {})
            .entry("Modified", None, |_, _| {})
            .separator()
            .toggleable_entry("Folders first", true, IconPosition::Start, None, |_, _| {})
    })
}
```

Doğrulama:

- `ContextMenu` handler'larında gerçek örneklerde `window.dispatch_action(...)`
  veya view state update yolu açık gösterilmeli.
- Menu ve popover örnekleri focus kapanma davranışıyla birlikte açıklanmalı.

### Faz 5: Liste, tree, tab ve layout yardımcıları

Kapsam:

- `List`, `ListItem`, `ListHeader`, `ListSubHeader`, `ListSeparator`
- `TreeViewItem`, `StickyItems`, `IndentGuides`
- `Tab`, `TabBar`
- `h_flex`, `v_flex`, `h_group*`, `v_group*`, `Stack`, `Group`, `Divider`

Yazılacaklar:

- `List` ile `gpui::list` ayrımı.
- `ListItem` slot modeli: start slot, end slot, hover slot, selected, disabled,
  toggle, indent.
- `TreeViewItem` içinde disclosure, indent ve nested state.
- `StickyItems` ve `IndentGuides` için scroll/tree ilişkisi.
- `Tab` ve `TabBar` için selected, close action ve overflow davranışı.
- Layout yardımcılarının raw `div()` üzerine ne eklediği:
  - `h_flex`: horizontal flex ve center alignment
  - `v_flex`: vertical flex
  - `h_group*` / `v_group*`: yalnızca tutarlı gap ve yön
- `Stack` ve `Group` adları listede geçse de mevcut kaynakta birebir
  public struct olarak görünmeyenler için rehberde "karşılık gelen API" notu yaz.
- `Divider` yön, inset, renk ve container ilişkisi.

Örnek üretilecek konu:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem};

fn render_project_list(selected: usize) -> impl IntoElement {
    List::new()
        .child(ListHeader::new("Projects"))
        .child(
            ListItem::new("project-alpha")
                .toggle_state(selected == 0)
                .start_slot(Icon::new(IconName::Folder))
                .child(Label::new("alpha")),
        )
        .child(
            ListItem::new("project-beta")
                .toggle_state(selected == 1)
                .start_slot(Icon::new(IconName::Folder))
                .child(Label::new("beta")),
        )
}
```

Doğrulama:

- `List::new()` ve `ListHeader::new(...)` imzaları kaynak dosyadan kontrol edilmeli.
- `ListItem` örneğinde slot ve child zincirinin gerçek `ParentElement`
  davranışıyla uyumlu olduğu doğrulanmalı.

### Faz 6: Veri ve tablo bileşenleri

Kapsam:

- `Table`, `TableInteractionState`, `RedistributableColumnsState`
- `render_table_row`, `render_table_header`
- `bind_redistributable_columns`
- `render_redistributable_columns_resize_handles`

Yazılacaklar:

- `Table` yüksek seviyeli API olarak ne sağlar?
- `TableInteractionState` hover, selection ve interaction için nasıl tutulur?
- Column resize state'i ne zaman `RedistributableColumnsState` olur?
- `render_table_row` ve `render_table_header` helper'ları hangi düşük seviye
  durumlarda kullanılır?
- Resize handle rendering ve binding sırası.
- Büyük veri listeleri için performans, sabit yükseklik ve virtualization notları.

Örnek üretilecek konu:

```rust
use ui::prelude::*;
use ui::Indicator;

struct PackageRow {
    name: SharedString,
    version: SharedString,
    enabled: bool,
}

fn render_package_status(row: &PackageRow) -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(
            Indicator::dot().color(if row.enabled {
                Color::Success
            } else {
                Color::Muted
            }),
        )
        .child(Label::new(row.name.clone()))
        .child(Label::new(row.version.clone()).color(Color::Muted))
}
```

Doğrulama:

- Tablo örnekleri `data_table.rs` içindeki mevcut component preview örnekleriyle
  karşılaştırılmalı.
- Resize state örneği, gerçek `Context<T>` içinde state alanı tutacak şekilde
  yazılmalı.

### Faz 7: Feedback ve durum göstergeleri

Kapsam:

- `Banner`, `Callout`, `Modal`, `AlertModal`
- `AnnouncementToast`, `Notification`
- `CountBadge`, `Indicator`, `ProgressBar`, `CircularProgress`

Yazılacaklar:

- `Banner` ile `Callout` ayrımı: sayfa üstü mesaj ve içerik içi açıklama.
- `Severity` ile icon/color seçiminin nasıl otomatikleştiği.
- `Modal` temel yapısı ve `AlertModal` karar akışı.
- Toast ve notification için lifecycle, action ve dismiss davranışı.
- `CountBadge` için sayaç, overflow, küçük alan kullanımı.
- `Indicator`, `ProgressBar`, `CircularProgress` için durum ve yükleme ayrımı.

Örnek üretilecek konu:

```rust
use ui::prelude::*;
use ui::{Banner, ProgressBar};

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

Doğrulama:

- `Banner::new()` ve `ProgressBar::new(...)` constructor imzaları kontrol edilmeli.
- Kullanıcıya dönük hata örneklerinde hatanın UI katmanına nasıl taşındığı
  açıklanmalı.

### Faz 8: Diğer bileşenler ve AI/collab özel alanı

Kapsam:

- `Avatar`, `Facepile`, `Chip`, `DiffStat`, `Disclosure`, `GradientFade`, `Image`
- `KeyBinding`, `KeybindingHint`, `Navigable`
- `AiSettingItem`, `AgentSetupButton`, `ThreadItem`, `ConfiguredApiCard`
- `CollabNotification`, `UpdateButton`

Yazılacaklar:

- `Avatar` ve `Facepile` için kullanıcı, participant, audio status ve overflow.
- `Chip` için filtre, status veya metadata kullanım sınırları.
- `DiffStat` için eklenen/silinen satır gösterimi.
- `Disclosure` ile açılır/kapanır satır ve tree ilişkisi.
- `GradientFade` ile scroll edge affordance.
- `Image` ile asset, theme ve fallback davranışı.
- `Image` adı listede geçse de mevcut kaynakta `Vector` / `VectorName` ve
  `gpui::img` / `ImageSource` karşılıkları ayrıca doğrulanmalı.
- `KeyBinding` ve `KeybindingHint` ile action, tooltip ve menü ilişkisi.
- `Navigable` için klavye gezinmesi ve focus sırası.
- AI/collab bileşenlerinde domain state'inin UI component ile ne kadar
  sıkı bağlı olduğu.

Örnek üretilecek konu:

```rust
use ui::prelude::*;
use ui::{Avatar, DiffStat};

fn render_collab_summary() -> impl IntoElement {
    h_flex()
        .gap_2()
        .child(Avatar::new("path/to/ada.png"))
        .child(
            v_flex()
                .gap_0p5()
                .child(Label::new("Ada Lovelace"))
                .child(Label::new("Reviewing changes").size(LabelSize::Small).color(Color::Muted)),
        )
        .child(DiffStat::new("ada-diff", 12, 3))
}
```

Doğrulama:

- `Avatar::new(...)` ve `DiffStat::new(...)` imzaları kaynak dosyadan
  doğrulanmalı.
- AI/collab örneklerinde gerçek servis bağımlılıkları taklit edilmemeli; component
  API'sini gösterecek minimal veriyle yetinilmeli.

### Faz 9: Entegre örnek sayfaları

Amaç: Tek tek bileşenlerden sonra gerçek ekran parçası gibi okunabilen birleşik
örnekler üretmek.

Örnek sayfalar:

1. **Ayarlar paneli satırı**: `Headline`, `Label`, `SwitchField`, `Button`,
   `Callout`.
2. **Toolbar ve komut menüsü**: `Button`, `IconButton`, `SplitButton`,
   `PopoverMenu`, `ContextMenu`, `Tooltip`, `KeybindingHint`.
3. **Proje listesi**: `List`, `ListItem`, `TreeViewItem`, `Disclosure`,
   `IndentGuides`, `CountBadge`.
4. **Veri tablosu**: `Table`, `TableInteractionState`,
   `RedistributableColumnsState`, `Indicator`, `ProgressBar`.
5. **Bildirim merkezi**: `Notification`, `AnnouncementToast`, `Banner`,
   `AlertModal`, `Button`.
6. **AI sağlayıcı kartları**: `ConfiguredApiCard`, `AiSettingItem`,
   `AgentSetupButton`, `ThreadItem`, `UpdateButton`.
7. **Collab özeti**: `Avatar`, `Facepile`, `CollabNotification`, `DiffStat`,
   `Chip`.

Her entegre örnek için yazılacaklar:

- Hangi bileşenleri neden birlikte kullandığı.
- State'in hangi struct alanlarında tutulduğu.
- Hangi eventlerin `cx.listener` ile view state'e döndüğü.
- Hangi async işlerin `Task` olarak saklanması veya `detach_and_log_err(cx)` ile
  ayrılması gerektiği.
- Hangi görsel durumların `cx.notify()` gerektirdiği.

### Faz 10: Doğrulama, temizlik ve bakım notları

Yapılacaklar:

- Dokümandaki her kod bloğunda importların gerçek olup olmadığını kontrol et.
- Constructor ve builder imzalarını kaynak dosyayla eşleştir.
- `unwrap()` ve `let _ =` ile hata yutma içeren örneklerden kaçın.
- Async örneklerde hataların UI state'e taşındığını göster.
- `smol::Timer::after(...)` yerine GPUI executor timer notunu test bölümlerinde
  koru.
- Component preview örnekleri eklenirse `./script/clippy` ile ilgili crate'i
  kontrol et.
- Sadece doküman değişikliği ise PR release notes için `- N/A` kullan.

## 5. Örnek Kod Üretim Stratejisi

Örnekler üç seviyede hazırlanmalı:

### Seviye 1: Minimum kullanım

Tek bileşenin constructor ve en yaygın iki builder yöntemini gösterir.

```rust
use ui::prelude::*;

fn render_minimum_button() -> impl IntoElement {
    Button::new("run-task", "Run")
        .start_icon(Icon::new(IconName::PlayFilled))
        .style(ButtonStyle::Filled)
}
```

### Seviye 2: Stateful view parçası

`Render` implement eden bir view içinde state değişimi ve `cx.notify()` gösterilir.

```rust
use ui::prelude::*;
use ui::Switch;

struct PreferencesView {
    auto_save: bool,
}

impl Render for PreferencesView {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Switch::new("auto-save", self.auto_save.into())
            .label("Auto save")
            .on_click(cx.listener(|this: &mut PreferencesView, state, _, cx| {
                this.auto_save = state.selected();
                cx.notify();
            }))
    }
}
```

### Seviye 3: Component preview örneği

Component gallery içinde varyantları göstermek için `RegisterComponent` ve
`Component` kullanılır.

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
            .child(IconButton::new("icon", IconName::Settings))
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

## 6. Araştırma Sırası

Her kategori için aynı okuma sırası izlenmeli:

1. `crates/ui/src/components/<kategori>.rs` modül dosyasını oku.
2. Alt dosyalarda public struct, enum, trait ve `impl RenderOnce` bloklarını çıkar.
3. `impl Component for ...` bölümünü incele; mevcut preview örneklerini temel al.
4. `awk '/<BileşenAdı>::/ { print FILENAME ":" FNR ":" $0 }' ...` ile Zed
   içindeki gerçek çağrıları bul.
5. Benzer kullanım yerlerinden minimum ve gerçekçi örnek kod üret.
6. Örneği rehberdeki bölüm şablonuna yerleştir.
7. API imzaları değişmişse kaynak haritasını güncelle.

Önerilen komutlar:

```sh
find crates/ui/src/components/button -name '*.rs' -print0 | xargs -0 awk '/pub struct Button|impl Button|impl Component for Button/ { print FILENAME ":" FNR ":" $0 }'
find crates -name '*.rs' -print0 | xargs -0 awk '/Button::new|IconButton::new|ToggleButton::/ { print FILENAME ":" FNR ":" $0 }'
find crates/ui/src/components -name '*.rs' -print0 | xargs -0 awk '/impl Component for/ { print FILENAME ":" FNR ":" $0 }'
```

## 7. Kapsam Dışı Bırakılacaklar

Bu çalışma şu konulara ancak bileşen kullanımını açıklamak için gerekli olduğu
kadar girmeli:

- GPUI platform penceresi, renderer ve event loop ayrıntıları.
- Tema dosyalarının tam schema açıklaması.
- Zed workspace, editor veya project panel mimarisinin geniş anlatımı.
- AI/collab servislerinin network veya persistence davranışı.
- Yeni tasarım sistemi önerileri.

## 8. Tamamlanma Tanımı

Çalışma tamamlandı sayılmadan önce:

- Listedeki her bileşenin rehberde kendi başlığı olmalı.
- Her kategori en az bir minimum ve bir kompozisyon örneği içermeli.
- Public API bilgisi kaynak dosyadaki imzalarla eşleşmeli.
- Event veya async örnekleri `cx.notify()`, `Task` yaşam döngüsü ve hata yayılımı
  açısından doğru olmalı.
- Örneklerde panikleyen `unwrap()` kullanılmamalı.
- Hatalar `let _ =` ile sessizce yutulmamalı.
- Gerekirse component preview örnekleri eklenmeli ve `./script/clippy` ile kontrol
  planı belirtilmeli.
