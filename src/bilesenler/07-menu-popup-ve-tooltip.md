# 7. Menü, Popup ve Tooltip

## Sürüm Analiz Raporu

- [x] Güncel kaynak commit aralığı: `e7311d52ba1b..693962917b5a`.
- [x] Güncel doğrulama: `ContextMenu::toggleable_entry_disabled_when(...)` builder imzası ve disabled toggleable girdi davranışı doğrulandı.
- [x] Kaynak doğrulama dosyası: `crates/ui/src/components/context_menu.rs`.

Bu bölüm, bir kontrolün arkasından geçici bir yüzey açan bileşenleri anlatır. Önceki bölümde form ve seçim durumunun nasıl tutulduğunu gördük; burada odak biraz değişir. Artık asıl soru "değer nerede duruyor" değil, "seçenekler nasıl sunulacak, menü içeriği hangi modelle kurulacak, popup nasıl açılıp kapanacak" sorusudur.

Hangi durumda hangi bileşenin tercih edileceği konusunda aşağıdaki ayrım faydalı olacaktır:

![Menü, Popup ve Tooltip Seçimi](assets/menu-popup-secimi.svg)

- Seçili değeri tetikleyici üzerinde gösteren bir seçenek listesi için `DropdownMenu` uygundur.
- Menü içeriğinde girdi, ayırıcı, alt menü ve action dispatch akışı gerekiyorsa `ContextMenu` doğru yapı taşıdır.
- Buton veya ikon tetikleyici ile açılan ve içinde yönetilen bir view barındıran menüler için `PopoverMenu` tercih edilir.
- İkincil tıklamayla (sağ tık) açılan bir bağlam menüsü için `right_click_menu` vardır.
- Bir popup yüzeyinin içeriğini doğru elevation ve padding ile çizmek için `Popover` kullanılması mümkündür.
- Kısa hover açıklamaları veya kısayol bilgilerini göstermek için ise `Tooltip` doğru yüzeydir.

Menü ve popup bileşenleri kendi başlarına durum (state) saklamaz. Girdi işleyicileri view veya model durumunu günceller. Popup'ın açılıp kapanma davranışı ise ilgili menü, popover veya üst bileşen yaşam döngüsü tarafından yönetilir.

Bileşenlerin açılış yönleri ve kenetlenme noktaları, `Anchor` koordinatları doğrultusunda belirlenir. Aşağıdaki şemada, tetikleyici bir elemana göre popup ve tooltip bileşenlerinin nasıl konumlandırıldığı ve kenetlendiği görselleştirilmiştir:

![Menu ve Popup Konumlandırma](assets/menu-popup-konumlandirma.svg)

## DropdownMenu

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::DropdownMenu`, `ui::DropdownStyle`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for DropdownMenu`.

Ne zaman kullanılır:

- Seçili değerin tetikleyici üzerinde göründüğü seçenek picker'larında.
- Liste kısa olduğu, ancak satır içi bir segment kontrol için fazla uzun kaldığı durumlarda.
- Menü içeriğinin doğal olarak bir `ContextMenu` ile ifade edilebildiği yapılarda.

Ne zaman kullanılmaz:

- Tetikleyici üzerindeki değer değişmiyor ve yalnızca bir eylem listesi açılıyorsa, doğrudan `PopoverMenu<ContextMenu>` kullanılması niyeti daha açık gösterir.
- Geniş bir arama veya filtre deneyimi gerekiyorsa, bir picker bileşeni veya özel yönetilen view tercih edilir.

Temel API:

- Constructor: `DropdownMenu::new(id, label, menu: Entity<ContextMenu>)`.
- Özel label için: `DropdownMenu::new_with_element(id, label: AnyElement, menu)`.
- Builder'lar: `.style(DropdownStyle)`, `.trigger_size(ButtonSize)`, `.trigger_tooltip(...)`, `.trigger_icon(IconName)`, `.full_width(bool)`, `.handle(PopoverMenuHandle<ContextMenu>)`, `.attach(Anchor)`, `.offset(Point<Pixels>)`, `.tab_index(...)`, `.no_chevron()`, `.aria_label(...)`, `.disabled(bool)`.
- `DropdownStyle`: `Solid`, `Outlined`, `Subtle`, `Ghost`.

Davranış:

- Metin label durumunda arka planda bir `Button` üretilir; özel element label durumunda ise bir `ButtonLike` kullanılır.
- `.aria_label(...)` verilmezse tetikleyicinin erişilebilirlik etiketi görünür label'dan türetilir. Özel element label'ı metin üretmiyorsa bu builder'ın açıkça tanımlanması gerekir.
- Dahili olarak `PopoverMenu::new((id, "popover"))` kurulur.
- Tetikleyici erişilebilirlik ağacında `Role::ComboBox` rolüyle görünür; popover handle durumuna göre `aria_expanded` değeri güncellenir.
- `.aria_label(...)`, görünür label'ın ekran okuyucu için yetersiz kaldığı veya özel element label kullanıldığı durumlarda tetikleyici adını açıkça verir.
- Expand ve collapse AccessKit action'ları tetikleyiciye bağlanır; ekran okuyucudan gelen açma/kapama isteği aynı popover handle üzerinden yürütülür.
- Varsayılan tetikleyici ikonu `IconName::ChevronUpDown`'dur; `.no_chevron()` bu oku kaldırır.
- Varsayılan attach noktası `Anchor::BottomRight`'tır.
- `DropdownStyle` değerleri buton stiline şu şekilde eşlenir: `Solid -> Filled`, `Outlined -> Outlined`, `Subtle -> Subtle`, `Ghost -> Transparent`.

Örnek:

```rust
use ui::prelude::*;
use ui::{ContextMenu, DropdownMenu, DropdownStyle, Tooltip};

fn siralama_acilir_menusunu_render_et(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu_icerigi = ContextMenu::build(window, cx, |icerik, _, _| {
        icerik.header("Sıralama")
            .toggleable_entry("Ad", true, IconPosition::Start, None, |_, _| {})
            .toggleable_entry("Güncellenme", false, IconPosition::Start, None, |_, _| {})
            .separator()
            .entry("Sıralamayı tersine çevir", None, |_, _| {})
    });

    DropdownMenu::new("siralama-dropdown", "Ad", menu_icerigi)
        .style(DropdownStyle::Outlined)
        .trigger_tooltip(Tooltip::text("Sıralamayı değiştir"))
}
```

Zed içinden kullanım örnekleri:

- `acp_tools` crate'i: bağlantı seçici.
- Bileşen önizleme: `ui` crate'i.

Dikkat edilmesi gereken noktalar:

- `DropdownMenu`, menu entity'sini dışarıdan alır. Menü girdi işleyicileri seçili değeri view veya model durumuna yazmalıdır; dropdown bu yazımı kendi başına yapmaz.
- Dinamik bir label kullanıldığında mevcut seçili değerin her render'da label'a yansıtılması gerekir. Aksi halde kontrol seçim değişse bile eski etiketi göstermeye devam eder.
- `full_width(true)`, tetikleyici ile popover'ın genişliklerini birlikte etkiler. Dar formlarda üst genişliğin de bilinçli ayarlanması gerekir.

## ContextMenu

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ContextMenu`, `ui::ContextMenuEntry`, `ui::ContextMenuItem`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan bir bileşen önizlemesi yok; `DropdownMenu` ve gerçek kullanım örnekleri üzerinden görünür hale gelir.

Ne zaman kullanılır:

- Girdi, ayırıcı, header, checked durumu, alt menü ve action dispatch içeren bir menü içeriği oluşturmak için.
- Aynı menü modelinin hem dropdown veya popover içinde hem de sağ tık menüsünde tekrar tekrar kullanılması gereken durumlarda.

Ne zaman kullanılmaz:

- Bir menü değil de serbest layout içeren bir popup yüzeyi gerekiyorsa, bir `Popover` içinde özel bir yönetilen view kurmak daha doğru bir çözümdür.
- Yalnızca tek bir buton eylemi söz konusuysa bir menü kurmaya gerek kalmaz; sade bir buton yeterlidir.

Temel API:

- `ContextMenu::build(window, cx, |menu, window, cx| menu...)`.
- Menünün açık kalmasını ve yeniden oluşturulabilmesini gerektiren durumlarda ise `ContextMenu::build_persistent(window, cx, builder)` yöntemi tercih edilir.
- Yapı builder'ları: `.context(focus_handle)`, `.header(...)`, `.header_with_link(...)`, `.separator()`, `.label(...)`, `.entry(...)`, `.toggleable_entry(...)`, `.toggleable_entry_disabled_when(...)`, `.custom_row(...)`, `.custom_entry(...)`, `.custom_entry_with_docs(...)`, `.entry_with_end_slot(...)`, `.entry_with_end_slot_on_hover(...)`, `.selectable(bool)`, `.action(...)`, `.action_checked(...)`, `.action_checked_with_disabled(...)`, `.action_disabled_when(...)`, `.link(...)`, `.link_with_handler(...)`, `.submenu(...)`, `.submenu_with_icon(...)`, `.submenu_with_colored_icon(...)`, `.keep_open_on_confirm(bool)`, `.fixed_width(...)`, `.key_context(...)`, `.end_slot_action(action)`.
- Dinamik öğe (item) ekleme builder'ları: `.item(item: impl Into<ContextMenuItem>)` ve `.extend(items: impl IntoIterator<Item = impl Into<ContextMenuItem>>)` zincirleme kullanım için uygundur. `&mut self` üzerinden menüyü değiştiren `.push_item(item)` ise builder zinciri dışında menü içeriğini güncellemek gerektiğinde (örneğin bir olay geri çağrısı içinde) tercih edilir.
- Programatik değiştiriciler: `.rebuild(window, cx)`, `build_persistent` ile açık kalan menünün içeriğini yeniden kurar; `.trigger_end_slot_handler(window, cx)` ise aktif girdinin end slot işleyicisini programatik olarak çalıştırır.
- Action ve gezinme metodları: `.selected_index()`, `.confirm(...)`, `.secondary_confirm(...)`, `.cancel(...)`, `.end_slot(...)`, `.clear_selected()`, `.select_first(...)`, `.select_last(...)`, `.select_next(...)`, `.select_previous(...)`, `.select_submenu_child(...)`, `.select_submenu_parent(...)`, `.on_action_dispatch(...)`, `.on_blur_subscription(...)`. Bunlar büyük çoğunlukla keymap ve action bağlarından çağrılır; normal menü inşası sırasında builder zincirine karıştırılmaz. `.select_last(...)` diğer `select_*` metodlarından farklıdır: bir action işleyicisi değil, son seçilebilir girdinin indeksini `Option<usize>` olarak döndüren bir yardımcıdır; seçilebilir girdi yoksa `None` verir.
- Girdi builder'ları: `ContextMenuEntry::new(label).icon(...).toggleable(...)` zincirine ek olarak `.custom_icon_path(...)`, `.custom_icon_svg(...)`, `.icon_position(...)`, `.icon_size(...)`, `.icon_color(...)`, `.action(...)`, `.handler(...)`, `.secondary_handler(...)`, `.disabled(...)`, `.documentation_aside(...)` builder'ları vardır.
- `ContextMenuItem` varyantları: `Separator`, `Header`, `HeaderWithLink`, `Label`, `Entry`, `CustomEntry`, `Submenu`. Builder zincirleri çoğu durumda bu enum'u doğrudan üretir; dinamik bir menü listesi saklanacaksa `ContextMenuItem` koleksiyonu da bu amaçla kullanmak mümkündür.

Davranış:

- `Focusable` ve `EventEmitter<DismissEvent>` implement eder.
- Kök element erişilebilirlik ağacında `Role::Menu` rolünü taşır.
- Standart girdiler `Role::MenuItem`, toggleable girdiler ise `Role::MenuItemCheckBox` olarak raporlanır; checked/toggled durumları girdi durumundan üretilir.
- Gerçek klavye odağı menü container'ında kalır; seçili girdi `ListItem::aria_active_descendant()` ile aktif descendant olarak bildirilir.
- Özel girdi render eden `custom_entry(...)` ve `custom_row(...)` kullanımlarında anlamlı label ve rol bilgisi özel element tarafından tamamlanmalıdır.
- Blur olduğunda menü kapanır; bir alt menü açıkken odak orada korunuyorsa kapanma ertelenir.
- Confirm edilen girdi işleyicisi çalıştırılır. `keep_open_on_confirm(false)` durumunda menü `DismissEvent` yayınlar ve kapanır.
- `build_persistent(...)` ile kurulan menü hem rebuild edilebilir hem de açık kalabilir.
- Klavye gezinmesi (navigation) için menünün kendi action'ları ve `key_context` değeri birlikte kullanılır.

Örnek:

```rust
use ui::prelude::*;
use ui::ContextMenu;

fn dosya_menusu_olustur(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |icerik, _, _| {
        icerik.header("Dosya")
            .entry("Yeniden adlandır", None, |_, _| {})
            .entry("Çoğalt", None, |_, _| {})
            .separator()
            .toggleable_entry("Gizli dosyaları göster", true, IconPosition::Start, None, |_, _| {})
            .submenu("Birlikte aç", |alt_menu, _, _| {
                alt_menu.entry("Metin editörü", None, |_, _| {})
                    .entry("Sistem uygulaması", None, |_, _| {})
            })
    })
}
```

Zed içinden kullanım örnekleri:

- `language_tools` crate'i: LSP server ve log view menüleri.
- `git_ui` crate'i: git panel eylem menüleri.
- `keymap_editor` crate'i: filtre ve keybinding menüleri.

Özel girdiler oluşturulduğunda menü çok daha esnek bir hâle gelir:

```rust
use gpui::IntoElement;
use ui::prelude::*;
use ui::{Chip, ContextMenu};

fn ozel_girdili_menu_olustur(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |icerik, _, _| {
        icerik.header_with_link(
            "Kullanılabilir Araçlar",
            "Belgeler",
            "https://zed.dev/docs/tools",
        )
        .custom_entry(
            |_, _| {
                h_flex()
                    .gap_2()
                    .child(Label::new("Seçimi çalıştır"))
                    .child(Chip::new("beta").label_color(Color::Accent))
                    .into_any_element()
            },
            |_, _| {},
        )
        .custom_entry_with_docs(
            |_, _| Label::new("Çalışma alanı ayarlarını aç").into_any_element(),
            |_, _| {},
            Some(ui::DocumentationAside::new(
                ui::DocumentationSide::Right,
                std::rc::Rc::new(|_| {
                    Label::new("Çalışma alanı ayarları sadece bu proje için geçerlidir.")
                        .into_any_element()
                }),
            )),
        )
    })
}
```

`header_with_link(...)` üç parametre alır: başlık, link etiketi ve link URL'i. Render edilen header'a tıklandığında URL `cx.open_url(...)` ile açılır.

`custom_entry(render_fn, handler)`, girdi görselini sıfırdan üretmeye olanak verir. Varsayılan olarak seçilebilir; girdinin yalnızca görsel kalması istendiğinde (yani bir label gibi davranması beklendiğinde) `.selectable(false)` ile bu davranış kapatılır.

`custom_entry_with_docs(render_fn, handler, documentation_aside)` ise girdinin yanında bir popover olarak küçük bir dokümantasyon paneli açılmasını sağlar. Aynı davranış normal `entry(...)` zinciri üzerine `.documentation_aside(side, render)` çağrılarak da eklenmesi mümkündür.

Action ve link yardımcıları:

- `action(label, action)`: önce varsa context odak handle'ına odak verir, ardından action dispatch eder.
- `toggleable_entry_disabled_when(label, toggled, disabled, position, action, handler)`: checked/toggled durumunu gösteren menü girdisini disabled koşuluyla birlikte üretir; `disabled` `true` olduğunda girdi render edilir ama işleyici çağrılmaz.
- `action_checked(...)` ve `action_checked_with_disabled(...)`: action girdisine sırasıyla checked ve disabled durumlarını ekler.
- `action_disabled_when(disabled, label, action)`: disabled koşulunu girdi oluştururken doğrudan bağlar.
- `link(...)` ve `link_with_handler(...)`: girdinin sonuna bir `ArrowUpRight` ikonu ekler, özel işleyiciyi çalıştırır ve ardından action dispatch eder.

End slot ve ikon yardımcıları:

- `entry_with_end_slot(...)`, girdinin sağ tarafına ikinci bir icon action koyar; yani satırın sağında ek bir kontrol yer alır.
- `entry_with_end_slot_on_hover(...)`, aynı action'ı yalnızca satırın üzerine gelindiğinde gösterir.
- `custom_icon_path(...)` ve `custom_icon_svg(...)`, `ContextMenuEntry` üzerinde normal bir `IconName` yerine harici bir ikon kaynağı seçer.
- `submenu_with_colored_icon(...)`, alt menü label'ına semantik `Color` ile renklendirilmiş bir ikon ekler.

Dikkat edilmesi gereken noktalar:

- `ContextMenu` tek başına bir pencere açma mekanizması değildir. Kullanıcının görebilmesi için `DropdownMenu`, `PopoverMenu` veya `right_click_menu` arayüzlerinden biriyle sunulmalıdır.
- İşleyici içinde view durumu güncellenecekse, ilgili entity üzerinden `window.handler_for(...)`, `cx.listener(...)` veya yerel model güncelleme desenlerinin tercih edilmesi gerekir. Yukarıdaki örneklerde yer alan boş işleyiciler yalnızca API kullanım şeklini gösterme amacı taşır.
- Alt menü builder'ları yeni bir `ContextMenu` değerini döndürmelidir. Üst menüdeki durumun kopyalanması gerektiğinde closure capture'larının sade tutulması okunabilirliği artırır.

## PopoverMenu

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::PopoverMenu`, `ui::PopoverMenuHandle`, `ui::PopoverTrigger`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: Doğrudan bir bileşen önizlemesi yok; gerçek kullanım menu tetikleyici bileşenleri üzerinden ortaya çıkar.

Ne zaman kullanılır:

- Bir `Button`, `IconButton` veya `ButtonLike` tetikleyicisine bağlı bir popover veya menü açmak gerektiğinde.
- Menü açıldığında tetikleyicinin seçili görünmesi ve menü kapanınca eski odağın geri gelmesi istendiğinde.
- `ContextMenu` dışında başka bir `ManagedView`'in popup olarak sunulacağı durumlarda.

Ne zaman kullanılmaz:

- Sağ tık davranışı gerekiyorsa `right_click_menu` daha doğru bir yüzeydir.
- Yalnızca hazır dropdown semantikleri gerekiyorsa `DropdownMenu` daha tutarlı bir tercihtir.

Temel API:

- Constructor: `PopoverMenu::new(id)`.
- Builder'lar: `.full_width(bool)`, `.menu(...)`, `.with_handle(...)`, `.trigger(...)`, `.trigger_with_tooltip(...)`, `.anchor(Anchor)`, `.attach(Anchor)`, `.offset(Point<Pixels>)`, `.on_open(...)`.
- `PopoverMenuHandle` yöntemleri: `.show(...)`, `.hide(...)`, `.toggle(...)`, `.is_deployed()`, `.is_focused(...)`, `.refresh_menu(...)`.

Davranış:

- Tetikleyici tipi `PopoverTrigger` trait'ini sağlamalıdır. Bu trait, `IntoElement + Clickable + Toggleable + 'static` kombinasyonunun public bir alias yüzeyidir.
- `.trigger(...)` için yalnız `PopoverTrigger` yeterlidir; ancak `.trigger_with_tooltip(...)` kullanmak isteniyorsa tetikleyicinin ayrıca `ButtonCommon` sağlaması gerekir. Bu yüzden tooltip'li tetikleyici, buton ailesinden bir öğe (örneğin `Button` veya `IconButton`) olmalıdır.
- Tetikleyici tıklandığında menu builder bir `Option<Entity<M>>` döndürür; `None` döndürdüğünde menü açılmaz.
- Açılan menü `DismissEvent` yayınladığında handle temizlenir ve mümkünse önceki odak geri verilir.
- Menü ertelenmiş (deferred) olarak render edildiği için odaklama işlemi iki `on_next_frame` sonrasında uygulanır.
- Tetikleyiciye menü açıkken tekrar tıklanırsa menü dismiss edilir ve olay yayılımı durdurulur.
- Bu durum tipleri manuel olarak üretilmez; `PopoverMenu` element yaşam döngüsü tarafından otomatik olarak yönetilir.

**Menu ve popover yardımcı API kapsamı.** Aşağıdaki tipler bu bölümdeki davranışların küçük taşıyıcılarıdır:

| API | Alt özellikler | Kullanım notu |
|-----|----------------|---------------|
| `DropdownStyle` | `Solid`, `Outlined`, `Subtle`, `Ghost` | Dropdown tetikleyicisinin buton stiline eşlenen görsel yüzeyidir. |
| `DropdownMenu::aria_label` | builder | Özel veya ikon ağırlıklı tetikleyicide erişilebilirlik adını görünür label'dan bağımsız verir. |
| `ContextMenuItem` | `Separator`, `Header`, `HeaderWithLink`, `Label`, `Entry`, `CustomEntry`, `Submenu` | Menü içeriğini saklamak veya dinamik üretmek için kullanılan enum modelidir. |
| `ContextMenuEntry` | `toggle`, `toggleable`, label alanı, `icon`, `custom_icon_path`, `custom_icon_svg`, `handler`, `secondary_handler`, `action`, `disabled`, `documentation_aside`, end-slot alanları | Tek bir seçilebilir menü satırının bütün görsel ve davranış bilgisini taşır. |
| `DocumentationSide` | `Left`, `Right` | Girdi dokümantasyon panelinin menünün hangi yanında açılacağını belirtir. |
| `DocumentationAside` | `side`, `render`; `new` | Girdi veya picker yanında küçük açıklama paneli render etmek amacıyla kullanılır. |
| `PopoverMenuHandle` | `show`, `hide`, `toggle`, `is_deployed`, `is_focused`, `refresh_menu` | Popover'ın dışarıdan açma/kapama ve içerik yenileme tutamacıdır. |
| `PopoverTrigger` | `IntoElement + Clickable + Toggleable + 'static` | Popover tetikleyicisi olabilecek buton benzeri elementleri sınırlayan trait alias yüzeyidir. |
| `PopoverMenuElementState` | private alanlar: `menu`, `child_bounds` | Açık menü entity'si ve tetikleyici sınır bilgisini element durumu olarak saklar. |
| `PopoverMenuFrameState` | private alanlar: `child_layout_id`, `child_element`, `menu_element`, `menu_handle` | Popover layout pass sırasında kullanılan geçici frame durumudur. |
| `MenuHandleElementState` | private alanlar: `menu`, `position` | Sağ tık menüsünün açık entity'sini ve cursor/handle pozisyonunu saklar. |
| `RequestLayoutState` | private alanlar: `child_layout_id`, `child_element`, `menu_element` | `right_click_menu` elementinin layout sırasında child ve menu elementlerini taşıdığı durumdur. |
| `PrepaintState` | private alanlar: `hitbox`, `child_bounds` | `right_click_menu` için prepaint aşamasında hitbox ve child bounds bilgisini taşır. |
| `POPOVER_Y_PADDING` | `Pixels` sabiti | `Popover` yüzeyinin dikey iç boşluğuna eklenen sabit değerdir. |
| `tooltip_container` | `AppContext` tabanlı yardımcı | Tooltip ve link preview yüzeylerine ortak elevation, font, padding ve metin rengini uygular. |
| `LinkPreview` | `new(url, cx)` | Uzun URL'i 100 karakterlik parçalara bölüp 500 karakterde kırpan tooltip view'idir. |
| `popover_menu` | `picker` crate alt modülü | `PickerPopoverMenu` sarmalayıcısını sağlar; picker'ı `PopoverMenu` içinde trigger arkasına yerleştirir. |

Örnek:

```rust
use ui::prelude::*;
use ui::{ContextMenu, PopoverMenu, Tooltip};

fn ek_eylemleri_render_et(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu_icerigi = ContextMenu::build(window, cx, |icerik, _, _| {
        icerik.entry("Yeniden adlandır", None, |_, _| {})
            .entry("Sil", None, |_, _| {})
    });

    PopoverMenu::new("ek-eylemler")
        .menu(move |_, _| Some(menu_icerigi.clone()))
        .trigger_with_tooltip(
            IconButton::new("ek-eylemler-tetikleyici", IconName::Menu)
                .icon_size(IconSize::Small)
                .style(ButtonStyle::Subtle),
            Tooltip::text("Ek eylemler"),
        )
}
```

Zed içinden kullanım örnekleri:

- `language_tools` crate'i: LSP seçim menüleri.
- `agent_ui` crate'i: bağlam ekleme ve izin menüleri.
- `git_ui` crate'i: repository, branch ve commit kontrolleri.

Dikkat edilmesi gereken noktalar:

- `trigger_with_tooltip(...)`, menü açıkken tetikleyici tooltip'inin görünmesini engeller. Yalnız ikonlu tetikleyicilerde bu davranış genellikle istenir.
- `with_handle(...)` kullanıldığında handle'ı view durumunda saklanması gerekir. Her render'da yeni bir handle oluşturulması, dışarıdan show ve hide kontrolünü işlemez hâle getirir.
- `anchor` menünün hangi köşesinin konumlanacağını belirler; `attach` ise tetikleyicinin hangi köşesine bağlanacağını ifade eder. İkisi birlikte popup'ın görsel olarak nereye yapışacağını yönetir.

## RightClickMenu

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::RightClickMenu`, `ui::right_click_menu`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: Doğrudan bir bileşen önizlemesi yok.

Ne zaman kullanılır:

- Dosya, tab, satır, liste öğesi veya editor yüzeyi üzerinde sağ tıkla bir bağlam menüsünün açılması gerektiğinde.
- Menü konumunun varsayılan olarak cursor pozisyonuna göre belirlenmesi istendiğinde.

Ne zaman kullanılmaz:

- Sol tık tetikleyicili bir menü için `PopoverMenu` daha uygundur.
- Seçili değeri gösteren bir kontrol için `DropdownMenu` daha doğru bir yüzeydir.

Temel API:

- Constructor: `right_click_menu::<M>(id)`.
- Builder'lar: `.trigger(|is_menu_active, window, cx| element)`, `.menu(|window, cx| Entity<M>)`, `.maybe_menu(|window, cx| Option<Entity<M>>)`, `.anchor(Anchor)`, `.attach(Anchor)`.

Davranış:

- Sağ tık (`MouseButton::Right`) hovered hitbox üzerinde bubble phase'de yakalandığında menü açılır.
- Açılma sırasında `prevent_default()` ve `stop_propagation()` çağrılır; böylece browser veya üst kontrol olayı işlemez.
- `.maybe_menu(...)` `None` döndürdüğünde sağ tık olayı yakalanır fakat menü açılmaz. Bu desen, satır bazlı izinler, boş seçimler veya geçici olarak devre dışı kalan bağlam menüleri için uygundur.
- `attach(...)` verildiğinde, menünün pozisyonu cursor yerine tetikleyici sınırının belirtilen köşesine bağlanır.
- Açılan yönetilen view `DismissEvent` yayınladığında menü durumu temizlenir ve mümkünse odak önceki elemana geri döner.
- Bu durum tipleri manuel olarak üretilmez; sağ tık menüsünün işaretçi (cursor) konumu, odak dönüşü ve ertelenmiş (deferred) menü render işlem için element sistemi kullanılır.

Örnek:

```rust
use ui::prelude::*;
use ui::{ContextMenu, right_click_menu};

fn proje_satirini_render_et(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu_icerigi = ContextMenu::build(window, cx, |icerik, _, _| {
        icerik.entry("Aç", None, |_, _| {})
            .entry("Finder'da göster", None, |_, _| {})
            .separator()
            .entry("Son projelerden kaldır", None, |_, _| {})
    });

    right_click_menu("son-proje-satiri-menusu")
        .trigger(|menu_acik, _window, cx| {
            h_flex()
                .w_full()
                .px_2()
                .py_1()
                .when(menu_acik, |this| this.bg(cx.theme().colors().element_hover))
                .child(Label::new("zed").truncate())
        })
        .menu(move |_, _| menu_icerigi.clone())
}
```

Zed içinden kullanım örnekleri:

- `platform_title_bar` crate'i: sistem tab sağ tık menüsü.
- `editor` crate'i: buffer header bağlam menüsü.
- `agent_ui` crate'i: context girdisi sağ tık menüleri.

Dikkat edilmesi gereken noktalar:

- Tetikleyici closure'ı içinde gelen `is_menu_active` değerini, hover veya selected görsel durumu için kullanılması mümkündür. Bu değerin bir uygulama durumu olarak saklanmaması gerekir; çünkü durum zaten menü tarafından otomatik olarak yönetilmektedir.
- Sağ tık menüsünün içinde sol tıkla çalışan özel kontroller varsa, olay yayılımı davranışının ve menu dismiss akışının test edilmesi gerekir; yoksa sürpriz davranışlar ortaya çıkabilir.

## Popover

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Popover`, `ui::POPOVER_Y_PADDING`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: Doğrudan bir bileşen önizlemesi yok.

Ne zaman kullanılır:

- Açılmış bir popup yüzeyinin içeriğini standart elevation ve padding ile çizmek için.
- Menü olmayan ama tetikleyiciye bağlı küçük bir seçenek paneli, açıklama paneli veya yardımcı içerik gerektiğinde.
- Ana içeriğe ek olarak yan tarafta bir açıklama alanı gerekiyorsa `.aside(...)` builder'ı bu rolü üstlenir.

Ne zaman kullanılmaz:

- Popup'ı açmak veya kapatmak için tek başına yeterli değildir; bu iş için `PopoverMenu` veya başka bir yönetilen view akışı gerekir.
- Sıradan bir context menu girdi listesi için `ContextMenu` daha doğru bir yüzeydir.

Temel API:

- Constructor: `Popover::new()`.
- Builder: `.aside(...)`.
- `ParentElement` implement eder; `.child(...)` ve `.children(...)` kabul eder.

Davranış:

- İçeriği `v_flex().elevation_2(cx)` yüzeyi üzerinde çizer.
- `.aside(...)` kullanıldığında, second bir elevation yüzeyi olarak yan içerik eklenir.
- `POPOVER_Y_PADDING` sabiti dikey padding hesabı sırasında kullanılır.

Örnek:

```rust
use ui::prelude::*;
use ui::Popover;

fn filtre_popoverini_render_et() -> impl IntoElement {
    Popover::new()
        .child(
            v_flex()
                .gap_2()
                .px_2()
                .child(Label::new("Filtre").size(LabelSize::Small).color(Color::Muted))
                .child(Label::new("Yalnız açık dosyalar")),
        )
        .aside(
            Label::new("Geçerli çalışma alanına uygulanır.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
}
```

Dikkat edilmesi gereken noktalar:

- `Popover` konumlandırma yapmaz. Bir `ManagedView` render'ı içinde kullanılması ve o view'in `PopoverMenu` ile açılması gerekir.
- İçerik genişliği child layout aracılığıyla kontrol edilir; `Popover` kendi başına sabit bir genişlik vermez.

## Tooltip

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Tooltip`, `ui::LinkPreview`, `ui::tooltip_container`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Tooltip`.

Ne zaman kullanılır:

- Yalnız ikonlu bir butonun anlamını anlatmak için.
- Disabled veya karmaşık kontrollerde kısa bir neden veya metaveri göstermek için.
- Bir action'a bağlı klavye kısayolunun tooltip içinde gösterilmesi istendiğinde.

Ne zaman kullanılmaz:

- Kullanıcı akışının doğru anlaşılması tooltip'in görünmesine bağlıysa, bunun yerine doğrudan görünür bir etiket (label) veya açıklama metni eklenmesi gerekir.
- Uzun dokümantasyon, form hatası veya kalıcı bilgi için tooltip yerine görünür bir içerik kullanılması gerekir; aksi halde önemli bilgi gizli kalır.

Temel API:

- Basit builder closure: `Tooltip::text(title)`.
- Immediate view: `Tooltip::simple(title, cx)`.
- Action kısayollu builder: `Tooltip::for_action_title(title, action)`, `Tooltip::for_action_title_in(title, action, focus_handle)`.
- Action kısayollu immediate view: `Tooltip::for_action(...)`, `Tooltip::for_action_in(...)`.
- Meta açıklamalı view: `Tooltip::with_meta(...)`, `Tooltip::with_meta_in(...)`.
- Özel element: `Tooltip::element(...)`, `Tooltip::new_element(...)`.
- Instance builder'ları: `Tooltip::new(title).meta(...).key_binding(...)`.
- `tooltip_container(cx, |div, cx| ...)`: Zed tooltip yüzeyini özel içerikle yeniden kullanmak için kullanılan düşük seviyeli yardımcı.
- `LinkPreview::new(url: &str, cx: &mut App) -> AnyView`: uzun bir URL'i 100 karakterlik parçalara bölüp, en fazla 500 karakterde keserek tooltip yüzeyi içinde yumuşak satır kırma ile render eden basit bir URL önizleme view'ı. Dönen `AnyView`, doğrudan `Tooltip::new_element(...)` veya entity tabanlı tooltip slot'larına geçirilebilir. Bu detaylar üst tooltip view yapısı içinde manuel olarak uygulanır.

Davranış:

- Tooltip yüzeyi `tooltip_container(...)` içinde `elevation_2`, UI fontu ve tema metin rengiyle çizilir.
- `key_binding` varsa başlık satırının sağında gösterilir.
- `meta` verildiğinde, ikinci satırda küçük ve muted bir etiket (label) olarak çizilir.
- `Tooltip::text(...)` gibi yöntemler, `.tooltip(...)` builder imzasına doğrudan uyan bir closure döndürür.
- GPUI görünür tooltip'i kaynak elementin hover durumuna bağlı tutar. Mouse kaynak hitbox'tan ayrıldığında normal tooltip kapanır; `hoverable_tooltip` kullanıldığında tooltip yüzeyi de hover alanı sayılır ve kullanıcı mouse'u tooltip içine taşıdığı sürece yüzey açık kalabilir.
- Mouse imleci kaynak element üzerinde varsayılan olarak 500 ms bekledikten sonra tooltip gösterilir. Bu gecikmeyi tek bir element için özelleştirmek gerekirse, tooltip'in eklendiği (id'li) element üzerinde `.tooltip_show_delay(delay)` metodu zincirlenir; daha hızlı geri bildirim için kısaltılır, kazara açılmayı azaltmak için ise uzatılır. Özel `Element` yazarken aynı ayarın imperatif biçimi `Interactivity::tooltip_show_delay(delay)`'dir.

Örnek:

```rust
use ui::prelude::*;
use ui::Tooltip;

fn yenile_butonunu_render_et() -> impl IntoElement {
    IconButton::new("modelleri-yenile", IconName::RotateCw)
        .icon_size(IconSize::Small)
        .tooltip(Tooltip::text("Modelleri yenile"))
}
```

Zed içinden kullanım örnekleri:

- `keymap_editor` crate'i: action ve binding tooltip'leri.
- `git_ui` crate'i: git panel buton tooltip'leri.
- `agent_ui` crate'i: action, disabled durumu ve meta açıklamaları.

Dikkat edilmesi gereken noktalar:

- `.tooltip(Tooltip::text(...))` en yaygın ve en sade kullanım biçimidir.
- Kısayol göstermek isteniyorsa action tabanlı yardımcılar tercih edilir; kısayolu elle string olarak yazmak, keymap değişikliklerinde tutarsızlığa yol açar.
- Tooltip metninin uzun bir açıklama değil; kısa bir eylem adı veya kısa bir neden olarak tutulması okunabilirliği korur.

## Menü ve Popup Kompozisyon Örnekleri

Bir toolbar üzerindeki ek eylem menüsü, `PopoverMenu` ve `ContextMenu`'nün en doğal kombinasyonudur. Bir ikon tetikleyiciye tooltip eklenmesi mümkündür, menü içeriği ise dışarıda `ContextMenu::build` ile hazırlanır:

```rust
use ui::prelude::*;
use ui::{ContextMenu, PopoverMenu, Tooltip};

fn arac_cubugu_menusunu_render_et(window: &mut Window, cx: &mut App) -> impl IntoElement {
    let menu_icerigi = ContextMenu::build(window, cx, |icerik, _, _| {
        icerik.entry("Yeni dosya", None, |_, _| {})
            .entry("Yeni klasör", None, |_, _| {})
            .separator()
            .entry("Ayarları aç", None, |_, _| {})
    });

    PopoverMenu::new("arac-cubugu-olustur-menusu")
        .menu(move |_, _| Some(menu_icerigi.clone()))
        .trigger_with_tooltip(
            IconButton::new("arac-cubugu-olustur-tetikleyici", IconName::Plus)
                .icon_size(IconSize::Small),
            Tooltip::text("Oluştur"),
        )
}
```
