# 9. Liste ve Tree Bileşenleri

Liste bileşenleri; aynı görsel ritme sahip satırları, bölüm başlıklarını, boş durum bildirimlerini ve hiyerarşik gezinme (navigation) arayüzlerini kurmak için kullanılır. Küçük ve orta ölçekli statik listelerde `List` ve `ListItem` kullanımı çoğunlukla yeterlidir. Satır sayısı arttığında ve satır yükseklikleri sabit kaldığında ise GPUI'nin `uniform_list(...)` çağrısı tercih edilmelidir. `StickyItems` ve `IndentGuides` gibi yardımcı araçlar da bu düşük seviyeli listenin üzerine ek bir süsleme/kılavuz katmanı olarak eklenebilir.

Hangi durumda hangi bileşenin tercih edileceğine karar verirken aşağıdaki ayrım faydalı olacaktır:

![Liste ve Tree Bileşenleri](assets/liste-bilesenleri-haritasi.svg)

- Basit bir kapsayıcı, header ve boş durum için `List` uygundur.
- Tıklanabilir veya seçilebilir bir satır için `ListItem` doğru yüzeydir.
- Listenin ana bölüm başlığı için `ListHeader` kullanılır.
- Daha küçük bir alt bölüm başlığı için `ListSubHeader` vardır.
- Liste içinde yatay bir ayırıcı için `ListSeparator` tercih edilir.
- Sabit açıklama maddeleri için yardımcı araç olarak `ListBulletItem` kullanılır.
- Hiyerarşik ve açılıp kapanabilen bir gezinme satırı için `TreeViewItem` doğrudan bu rol için tasarlanmıştır.
- Büyük bir `uniform_list` içinde sticky üst öğe veya header davranışı istendiğinde `StickyItems` devreye girer.
- Büyük hiyerarşik listelerde girinti kılavuz çizgileri için `IndentGuides` kullanılır.

## List

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::List`, `ui::EmptyMessage`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for List`.

Ne zaman kullanılır:

- Az sayıda satır içeren ayar, onboarding, modal, provider veya kart içi listelerde.
- Header ve boş durumun aynı bileşen üzerinden yönetilmesinin istendiği yerlerde.
- Çocuk satırların yükseklikleri birbirinden farklı olabilir ve lazy rendering gerekmediği durumlarda.

Ne zaman kullanılmaz:

- Binlerce satır barındıran, kaydırma (scroll) yapılan ve performans açısından kritik olan listeler için GPUI'nin `uniform_list(...)` çağrısı tercih edilir.
- Tablo semantiği, column resize veya header/satır sözleşmesi gerektiren yapılar için doğrudan tablo veya veri bileşenleri daha doğru bir araçtır.

Temel API:

- Constructor: `List::new()`.
- Builder'lar: `.empty_message(...)`, `.header(...)`, `.toggle(...)`.
- `ParentElement` implement eder; `.child(...)` ve `.children(...)` kabul eder.
- `EmptyMessage`: `Text(SharedString)` veya `Element(AnyElement)`.

Boş durum tipi:

| API | Rol |
| :-- | :-- |
| `EmptyMessage` | Liste boşken gösterilecek içeriği seçer; `Text` düz label, `Element` ise özel `AnyElement` boş durumu sağlar. |

Davranış:

- `RenderOnce` implement eder.
- Kapsayıcı; tam genişlikte bir `v_flex()` ve dikey padding ile çizilir.
- Hiç çocuk yoksa varsayılan olarak `"No items"` mesajı muted bir `Label` şeklinde gösterilir.
- `.empty_message(...)` ya bir string ya da özel bir `AnyElement` alabilir.
- `.toggle(Some(false))` verilir ve children boşsa, boş durum da gizlenir.
- `.header(...)` tanımlandığında header, alt öğelerden (children) önce render edilir.

Örnek:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem};

fn sg_listesi_render() -> impl IntoElement {
    List::new()
        .header(ListHeader::new("Sağlayıcılar"))
        .empty_message("Yapılandırılmış sağlayıcı yok")
        .child(
            ListItem::new("saglayici-openai")
                .start_slot(Icon::new(IconName::Check).size(IconSize::Small))
                .child(Label::new("OpenAI")),
        )
        .child(
            ListItem::new("saglayici-anthropic")
                .start_slot(Icon::new(IconName::Check).size(IconSize::Small))
                .child(Label::new("Anthropic")),
        )
}
```

Zed içinden kullanım örnekleri:

- `edit_prediction_ui` crate'i: özel boş durumlu completion listesi.
- `language_models` crate'i: provider ayar listeleri.
- `toolchain_selector` crate'i: toolchain seçenekleri.

Dikkat edilmesi gereken noktalar:

- `List`, kendi başına bir kaydırma (scroll) davranışı sunmaz. Kaydırma gerekiyorsa üst kapsayıcıya `.overflow_y_scroll()` eklenir; büyük listelerde ise `uniform_list(...)` tercih edilir.
- Dinamik çocuklar üretilirken sabit bir `ElementId` kullanılması önerilir. Yalnızca indeks üzerinden id vermek, yeniden sıralanan listelerde durum ve odak takibini zorlaştırır.
- Boş durum özel bir element ise onu `.into_any_element()` çağrısıyla iletilmesi gerekir.

## ListItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ListItem`, `ui::ListItemSpacing`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ListItem`.

Ne zaman kullanılır:

- Liste satırı, picker sonucu, ayar satırı, gezinme satırı veya action satırı için.
- Satırda bir start icon veya avatar, bir ana içerik ve bir sağ slot bir arada gerektiğinde.
- Seçili, disabled, hover, odak veya disclosure durumunun satır düzeyinde gösterilmesi istendiğinde.

Ne zaman kullanılmaz:

- Yalnızca metin gösterilecekse `Label` veya `ListBulletItem` çok daha sade bir çözüm sunar.
- Çok büyük listelerde `ListItem` satır olarak yine kullanılabilir, ancak kapsayıcı olarak `List` yerine `uniform_list(...)` tercih edilir.

Temel API:

- Constructor: `ListItem::new(id)`.
- Spacing: `.spacing(ListItemSpacing::Dense | ExtraDense | Sparse)`.
- Slotlar: `.start_slot(...)`, `.end_slot(...)`, `.end_slot_on_hover(...)`, `.show_end_slot_on_hover()`.
- Hiyerarşi: `.indent_level(usize)`, `.indent_step_size(Pixels)`, `.inset(bool)`, `.toggle(...)`, `.on_toggle(...)`, `.always_show_disclosure_icon(bool)`.
- Davranış: `.on_click(...)`, `.on_hover(...)`, `.on_secondary_mouse_down(...)`, `.tooltip(...)`.
- Görsel durum: `.toggle_state(bool)`, `.disabled(bool)`, `.selectable(bool)`, `.outlined()`, `.rounded()`, `.focused(bool)`, `.docked_right(bool)`, `.height(...)`, `.overflow_x()`, `.group_name(...)`.

Satır yoğunluğu:

| API | Rol |
| :-- | :-- |
| `ListItemSpacing` | `Dense`, `ExtraDense` ve `Sparse` seçenekleriyle satırın yatay/dikey iç boşluk ritmini belirler. |

Davranış:

- `RenderOnce`, `Disableable`, `Toggleable` ve `ParentElement` implement eder.
- `toggle_state(true)` satırı seçili arka plan ile çizer; fakat uygulama durumunu kendisi değiştirmez. Seçim bilgisinin arkasındaki gerçek değerin view tarafında saklanması gerekir.
- `disabled(true)` click işleyicisini devre dışı bırakır.
- `.toggle(Some(is_open))` bir disclosure ikonu render eder; çocukların gerçekten gösterilip gösterilmeyeceğini üst view kontrol eder.
- `end_slot_on_hover(...)`, normal end slot'u hover sırasında verilen hover slot'uyla değiştirir. `.show_end_slot_on_hover()` ise mevcut end slot'u yalnızca hover anında görünür kılar.
- `indent_level(...)` parametresi, `inset(false)` durumunda girintiyi satırın içinde uygular; `inset(true)` olduğunda ise girintiyi satırın dışında oluşturur.

Örnek:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem, ListItemSpacing, Tooltip};

struct DosyaListesi {
    secili_indeks: usize,
}

impl DosyaListesi {
    fn dosya_satiri_render(
        &self,
        indeks: usize,
        ad: &'static str,
        yol: &'static str,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        ListItem::new(("dosya-satiri", indeks))
            .spacing(ListItemSpacing::Dense)
            .toggle_state(self.secili_indeks == indeks)
            .start_slot(Icon::new(IconName::File).size(IconSize::Small).color(Color::Muted))
            .child(
                v_flex()
                    .min_w_0()
                    .child(Label::new(ad).truncate())
                    .child(Label::new(yol).size(LabelSize::Small).color(Color::Muted).truncate()),
            )
            .end_slot(
                IconButton::new(("dosya-satiri-eylemleri", indeks), IconName::Ellipsis)
                    .icon_size(IconSize::Small)
                    .tooltip(Tooltip::text("Dosya eylemleri")),
            )
            .show_end_slot_on_hover()
            .on_click(cx.listener(move |this: &mut DosyaListesi, _, _, cx| {
                this.secili_indeks = indeks;
                cx.notify();
            }))
    }
}

impl Render for DosyaListesi {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        List::new()
            .header(ListHeader::new("Açık dosyalar"))
            .child(self.dosya_satiri_render(0, "main.rs", "crates/app/src/main.rs", cx))
            .child(self.dosya_satiri_render(1, "lib.rs", "crates/ui/src/lib.rs", cx))
    }
}
```

Zed içinden kullanım örnekleri:

- `picker` crate'i: picker satırları.
- `outline_panel` crate'i: outline satırları.
- `git_ui` crate'i: repository selector satırları.

Dikkat edilmesi gereken noktalar:

- `ListItem`, alt öğe içeriğini `overflow_hidden()` ile sarar. Bu yüzden uzun metinli içeriklerde iç etiketlere de `.truncate()` ve üst yerleşime (layout) `.min_w_0()` eklenmesi gerekir.
- Hover sırasında görünen action butonları için, satır ID'sinin ve içerideki action ID'lerinin sabit kalması önerilir; aksi takdirde hover durumu tutarlı çalışmaz.
- Sağ tıkla bir bağlam menüsü (context menu) açmak için `.on_secondary_mouse_down(...)` kullanılabilir; daha kapsamlı bir bağlam menüsü gerektiğinde ise `right_click_menu(...)` daha bütünsel bir çözüm sunar.

## ListHeader

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ListHeader`
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ListHeader`.

Ne zaman kullanılır:

- Liste veya panel içinde ana bir bölüm başlığı göstermek için.
- Başlık yanında bir icon, sayaç, action veya collapse disclosure gerektiğinde.

Ne zaman kullanılmaz:

- Daha küçük bir alt bölüm başlığı için `ListSubHeader` daha uygun bir yüzeydir.
- Sayfa veya modal ana başlığı için `Headline` veya modal header daha doğru bir tercihtir.

Temel API:

- Constructor: `ListHeader::new(label)`.
- Builder'lar: `.toggle(...)`, `.on_toggle(...)`, `.start_slot(...)`, `.end_slot(...)`, `.end_hover_slot(...)`, `.inset(bool)`, `.toggle_state(bool)`.

Davranış:

- `RenderOnce` ve `Toggleable` implement eder.
- UI density ayarına göre header yüksekliği otomatik olarak değişir.
- `.toggle(Some(is_open))` çağrısı, başa bir `Disclosure` ekler.
- `.on_toggle(...)` hem disclosure'a hem de label kapsayıcısının tıklama davranışına aynı anda bağlanır.
- `.end_hover_slot(...)` içeriği, header'ın group hover durumu sırasında sağ tarafta mutlak konumlu (absolute) olarak çizilir.

Örnek:

```rust
use ui::prelude::*;
use ui::{ListHeader, Tooltip};

fn son_projeler_basligi_render(sayi: usize) -> impl IntoElement {
    ListHeader::new("Son projeler")
        .start_slot(Icon::new(IconName::Folder).size(IconSize::Small))
        .end_slot(Label::new(sayi.to_string()).size(LabelSize::Small).color(Color::Muted))
        .end_hover_slot(
            IconButton::new("son-projeleri-temizle", IconName::Trash)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Son projeleri temizle")),
        )
}
```

Dikkat edilmesi gereken noktalar:

- Header'ın daraltılma/açılma (collapse) durumu view durumunda saklanmalıdır; `.toggle(...)` yalnızca disclosure görünümünü ayarlar, gerçek açık/kapalı bilgisini taşımaz.
- `end_hover_slot(...)`, normal `end_slot` ile aynı alanı paylaşır. Bu yüzden sayaç ve hover action birlikte tasarlanırken, ikisinin görsel olarak nasıl yer değiştireceği önceden planlanmalıdır.

## ListSubHeader

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ListSubHeader`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ListSubHeader`.

Ne zaman kullanılır:

- Liste içinde daha küçük, ikinci seviye bir bölüm başlığı gerektiğinde.
- Küçük label, opsiyonel sol ikon ve sağ slot yeterli olduğunda.

Ne zaman kullanılmaz:

- Collapse disclosure, hover slot veya daha güçlü header davranışı gerekiyorsa `ListHeader` daha uygundur.

Temel API:

- Constructor: `ListSubHeader::new(label)`.
- Builder'lar: `.left_icon(Option<IconName>)`, `.end_slot(AnyElement)`, `.inset(bool)`, `.toggle_state(bool)`.

Davranış:

- `RenderOnce` ve `Toggleable` implement eder.
- Etiket (label), muted renkte ve `LabelSize::Small` boyutunda çizilir.
- `.end_slot(...)` doğrudan bir `AnyElement` bekler.

Örnek:

```rust
use ui::prelude::*;
use ui::ListSubHeader;

fn sabitlenmis_alt_baslik_render() -> impl IntoElement {
    ListSubHeader::new("Sabitlenenler")
        .left_icon(Some(IconName::Folder))
        .end_slot(Label::new("3").size(LabelSize::Small).color(Color::Muted).into_any_element())
}
```

Zed içinden kullanım örnekleri:

- `component_preview` crate'i: önizleme gezinme bölüm başlıkları.
- `editor` crate'i: completion menu group header'ları.
- `agent_ui` crate'i: archive view alt bölümleri.

Dikkat edilmesi gereken noktalar:

- `end_slot(...)` generic değildir; slot elementinin `.into_any_element()` çağrısıyla iletilmesi gerekir.
- Subheader'ın selected durumu yalnızca görseldir; gerçek gezinme durumunun üst view'da tutulması gerekir.

## ListSeparator

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ListSeparator`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Aynı listede iki satır grubunu ince bir çizgiyle ayırmak için.
- Menü olmayan listelerde ayırıcı ihtiyacı doğduğunda.

Ne zaman kullanılmaz:

- `ContextMenu` içinde ayrım gerekiyorsa `.separator()` doğrudan menü API'sinde yer alır.
- Bölüm başlığı gerekiyorsa `ListHeader` veya `ListSubHeader` çok daha anlamlı bir araçtır.

Davranış:

- `RenderOnce` implement eder.
- Tam genişlikte, 1px yükseklikli ve `border_variant` rengiyle çizilir.
- Dikey dış boşluk (margin) olarak `DynamicSpacing::Base06` kullanılır.

Örnek:

```rust
use ui::prelude::*;
use ui::{List, ListItem, ListSeparator};

fn gruplanmis_eylemler_render() -> impl IntoElement {
    List::new()
        .child(ListItem::new("kopyala").child(Label::new("Kopyala")))
        .child(ListItem::new("yapistir").child(Label::new("Yapıştır")))
        .child(ListSeparator)
        .child(ListItem::new("sil").child(Label::new("Sil").color(Color::Error)))
}
```

## ListBulletItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ListBulletItem`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ListBulletItem`.

Ne zaman kullanılır:

- Modal, onboarding veya açıklama paneli içinde kısa bir madde listesi göstermek için.
- Dash ikonu, satır wrap davranışı ve Zed liste aralığının hazır gelmesi istendiğinde.

Ne zaman kullanılmaz:

- Tıklanabilir veya seçilebilir bir satır için `ListItem` doğru yüzeydir.
- Hiyerarşik bir tree veya çok satırlı bir gezinme için `TreeViewItem` daha uygundur.

Temel API:

- Constructor: `ListBulletItem::new(label)`.
- Builder: `.label_color(Color)`.
- `ParentElement` implement eder; bir alt öğe (child) verildiğinde label yerine alt öğeler kaydırmalı (wrap) satır içi içerik olarak render edilir.

Dikkat edilmesi gereken noktalar:

- Bu bileşen açıklayıcı bir içerik için tasarlanmıştır. İçerisine bir action link konabilir, ama satır düzeyinde seçim veya klavye gezinmesi beklenmemelidir.
- Kaynakta iç `ListItem` id'si sabittir; bu yüzden keyed bir satır durumunun gerektiği dinamik listelerde `ListItem` ile özel bir satır kurmak daha doğru bir tercih olur.

## TreeViewItem

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::TreeViewItem`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for TreeViewItem`.

Ne zaman kullanılır:

- Üst öğe ile child arasında bir ilişkinin olduğu gezinme satırlarında.
- Root öğesinin disclosure ile açılıp kapanacağı, child öğelerin ise girinti çizgisiyle gösterileceği yapılarda.
- Seçili ve odaklı durumların tree satırı üzerinden gösterileceği durumlarda.

Ne zaman kullanılmaz:

- Slot'lu, serbest layout'lu bir satır gerektiğinde `ListItem` daha esnek bir çözüm sunar.
- Büyük ve özel bir hiyerarşik panel kurulurken `uniform_list(...)`, `ListItem` and `IndentGuides` üçlüsü çok daha esnek bir altyapı verir.

Temel API:

- Constructor: `TreeViewItem::new(id, label)`.
- Davranış: `.on_click(...)`, `.on_hover(...)`, `.on_secondary_mouse_down(...)`, `.tooltip(...)`, `.on_toggle(...)`, `.tab_index(...)`, `.track_focus(&FocusHandle)`.
- Görsel durum: `.expanded(bool)`, `.default_expanded(bool)`, `.root_item(bool)`, `.focused(bool)`, `.toggle_state(bool)`, `.disabled(bool)`, `.group_name(...)`.

Davranış:

- `RenderOnce`, `Disableable` ve `Toggleable` implement eder.
- `root_item(true)` olan satırlarda disclosure ile label aynı satırda çizilir.
- `root_item(false)` olan bir alt (child) satırda, solda bir girinti çizgisi çizilir.
- `.expanded(...)` yalnızca disclosure ikonunun görünümünü belirler; child satırlarının gerçekten render edilip edilmeyeceğine üst view karar verir.
- `.default_expanded(...)` mevcut kaynak kodda alanı set eder, ancak render içinde okunmaz. Açık veya kapalı durum kontrolü için `.expanded(...)` kullanılır.
- `.toggle_state(true)` seçili arka plan ile birlikte border davranışını tetikler.

Örnek:

```rust
use ui::prelude::*;
use ui::TreeViewItem;

struct SembolAgaci {
    modul_acik: bool,
    secili_indeks: usize,
}

impl Render for SembolAgaci {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .child(
                TreeViewItem::new("semboller-modul", "modül uygulama")
                    .root_item(true)
                    .expanded(self.modul_acik)
                    .toggle_state(self.secili_indeks == 0)
                    .on_toggle(cx.listener(|this: &mut SembolAgaci, _, _, cx| {
                        this.modul_acik = !this.modul_acik;
                        cx.notify();
                    })),
            )
            .when(self.modul_acik, |this| {
                this.child(
                    TreeViewItem::new("semboller-baslat", "fn baslat")
                        .toggle_state(self.secili_indeks == 1)
                        .on_click(cx.listener(|this: &mut SembolAgaci, _, _, cx| {
                            this.secili_indeks = 1;
                            cx.notify();
                        })),
                )
            })
    }
}
```

Zed içinden kullanım örnekleri:

- Bileşen önizleme: `ui` crate'i.
- Zed içindeki hiyerarşik panellerin büyük kısmı, daha özelleşmiş `ListItem` ile `uniform_list` kompozisyonlarını kullanır. `TreeViewItem` ise hazır ve basit bir tree satırı ihtiyacına dönüktür.

Dikkat edilmesi gereken noktalar:

- `TreeViewItem`, alt öğe (child) listesini kendi içinde barındırmaz. Açık bir root elemanının altındaki child öğelerinin üst yerleşim (layout) tarafından eklenmesi gerekir.
- Devre dışı (disabled) durumu, hover ve tıklama davranışını tamamen ortadan kaldırmaz. Tıklama işleyicisi devre dışı olunduğunda bağlanmaz; ancak görsel durumun da tasarımda devre dışı olarak ifade edilmesine dikkat edilmelidir.

## StickyItems

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::sticky_items`, `ui::StickyItems`, `ui::StickyCandidate`, `ui::StickyItemsDecoration`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan bir bileşen önizlemesi yok.

Ne zaman kullanılır:

- Bir `uniform_list(...)` içinde scroll ederken üst öğe veya header satırlarının sticky kalması gerektiğinde.
- Project panel gibi derin, hiyerarşik ve çok satırlı listelerde.

Ne zaman kullanılmaz:

- Normal bir `List` içinde kullanılamaz; `UniformListDecoration` akışına bağlıdır.
- Küçük listelerde sticky davranışın hem maliyeti hem karmaşıklığı gereksizdir.

Temel API:

- `sticky_items(entity, compute_fn, render_fn)`.
- `StickyCandidate` trait'i: `fn depth(&self) -> usize`. Render edilecek her satır verisinin bu trait'i implement etmesi istenir; depth değerinin görünür aralık içindeki sıraya göre monotonik olarak artması gerekir.
- `StickyItemsDecoration` trait'i: `fn compute(...) -> AnyElement`. Sticky bölgenin üstüne kaplama (girinti çizgisi, vurgu vb.) çizmek için bu trait implement edilip `.with_decoration(...)` ile bağlanır; `IndentGuides` bu trait'i hazır şekilde implement eder.
- Builder: `.with_decoration(decoration: impl StickyItemsDecoration)`.

Sticky altyapı API'leri:

| API | Rol |
| :-- | :-- |
| `sticky_items` | `uniform_list(...)` için sticky üst öğe/header süslemesi üreten public yardımcıdır. |
| `StickyCandidate` | Satır verisinden `depth()` bilgisini okuyarak hangi üst öğelerin sticky kalacağını hesaplatan trait'dir. |
| `StickyItemsDecoration` | Sticky kaplama üzerine ek çizim veya girinti vurgusu bindirmek için kullanılan süsleme trait'idir. |

Davranış:

- `UniformListDecoration` implement eder.
- Görünür aralık ve aday depth değerlerinden sticky anchor hesaplar.
- Sticky girdi "drift" ediyorsa (yani konumu kayıyorsa), son sticky element scroll pozisyonuna göre yukarı doğru itilir.
- Ek süsleme olarak `IndentGuides` de aynı anda bağlanabilir.

Örnek iskelet:

```rust
use ui::{StickyCandidate, sticky_items};

#[derive(Clone)]
struct SabitAnahatGirdisi {
    indeks: usize,
    derinlik: usize,
}

impl StickyCandidate for SabitAnahatGirdisi {
    fn depth(&self) -> usize {
        self.derinlik
    }
}
```

Zed içinden kullanım örnekleri:

- `project_panel` crate'i: project tree sticky girdileri ile girinti kılavuzu süslemesi birlikte kullanılır.

Dikkat edilmesi gereken noktalar:

- Aday `depth()` değerleri görünür aralık sırasıyla uyumlu olmalıdır. Yanlış bir depth değeri tanımlanması, sticky anchor'ın yanlış bir satırdan seçilmesine sebep olur.
- `render_fn` birden fazla sticky ata döndürebilir; bu elemanların yüksekliklerinin uniform list item yüksekliği ile uyumlu olması gerekir.

## IndentGuides

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::indent_guides`, `ui::IndentGuides`, `ui::IndentGuideColors`, `ui::IndentGuideLayout`, `ui::RenderIndentGuideParams`, `ui::RenderedIndentGuide`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan bir bileşen önizlemesi yok.

Ne zaman kullanılır:

- Büyük bir hiyerarşik `uniform_list(...)` içinde girinti çizgileri göstermek için.
- Project panel, outline panel veya benzer tree listelerinde.
- Sticky item süslemesi içinde de aynı girinti çizgilerinin devam etmesi istendiğinde.

Ne zaman kullanılmaz:

- Basit `ListItem::indent_level(...)` kullanılan küçük listelerde, girinti çizgilerine ihtiyaç duyulmaz.
- Editor metni indent guide'ları için bu bileşen kullanılmaz; editor tarafı kendi indent guide sistemini taşır.

Temel API:

- Constructor: `indent_guides(indent_size: Pixels, colors: IndentGuideColors)`.
- Renk yardımcısı: `IndentGuideColors::panel(cx)`.
- Builder'lar: `.with_compute_indents_fn(entity, compute_fn)`, `.with_render_fn(entity, render_fn)`, `.on_click(...)`.
- `IndentGuideColors` public alanları: `default: Hsla`, `hover: Hsla`, `active: Hsla`. `panel(cx)` yardımcısı dışında özel bir renk seti gerektiğinde, bu alanlarla doğrudan bir struct literal kurulabilir.
- `RenderIndentGuideParams`: `indent_guides: SmallVec<[IndentGuideLayout; 12]>`, `indent_size: Pixels`, `item_height: Pixels`. `with_render_fn` geri çağrısının girdisidir.
- `RenderedIndentGuide`: `bounds: Bounds<Pixels>`, `layout: IndentGuideLayout`, `is_active: bool`, `hitbox: Option<Bounds<Pixels>>`. `with_render_fn` geri çağrısından dönen vektörın eleman tipidir.
- `IndentGuideLayout`: `offset: Point<usize>` (satır indeksi ve depth), `length: usize` (kaç satır boyunca süreceği), `continues_offscreen: bool`. `.on_click(...)` geri çağrısı bu tipi `&IndentGuideLayout` olarak alır.

Indent guide taşıyıcıları:

| API | Rol |
| :-- | :-- |
| `IndentGuideColors` | Girinti çizgileri için default, hover ve active renk setini taşır; `panel(cx)` panel temasına uygun varsayılanı üretir. |
| `RenderIndentGuideParams` | Özel render geri çağrısına hesaplanmış guide layout'larını, indent ölçüsünü ve item yüksekliğini verir. |
| `RenderedIndentGuide` | Özel render sonucunda her guide için bounds, layout, active durum ve opsiyonel hitbox bilgisini taşır. |
| `IndentGuideLayout` | Bir guide'ın hangi satır/depth noktasından başlayıp kaç satır sürdüğünü ve offscreen devam edip etmediğini belirtir. |

Davranış:

- `UniformListDecoration` olarak kullanıldığında `.with_compute_indents_fn(...)` çağrısı zorunludur; verilmediğinde compute sırasında panic oluşur.
- Görünür aralık sonrasında daha fazla item varsa, aralık bir satır genişletilir; böylece ekran dışında devam eden bir guide doğru hesaplanır.
- `.on_click(...)` verildiğinde guide hitbox'ları oluşur, hover rengi uygulanır ve pointing hand cursor görünür.
- `.with_render_fn(...)` tanımlanmadığında her kılavuz (guide) 1px genişliğinde varsayılan bir çizgi olarak çizilir.

Örnek:

```rust
use gpui::{ListSizingBehavior, UniformListScrollHandle, uniform_list};
use ui::prelude::*;
use ui::{IndentGuideColors, ListItem, indent_guides};

#[derive(Clone)]
struct AnahatGirdisi {
    derinlik: usize,
    etiket: SharedString,
}

struct AnahatListesi {
    girdiler: Vec<AnahatGirdisi>,
    kaydirma_tutamaci: UniformListScrollHandle,
}

impl Render for AnahatListesi {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let girdiler = self.girdiler.clone();

        uniform_list("anahat-listesi", girdiler.len(), move |range, _, _| {
            range
                .map(|indeks| {
                    let girdi = &girdiler[indeks];
                    ListItem::new(("anahat-girdisi", indeks))
                        .indent_level(girdi.derinlik)
                        .indent_step_size(px(12.))
                        .child(Label::new(girdi.etiket.clone()).truncate())
                })
                .collect::<Vec<_>>()
        })
        .with_sizing_behavior(ListSizingBehavior::Infer)
        .track_scroll(&self.kaydirma_tutamaci)
        .with_decoration(
            indent_guides(px(12.), IndentGuideColors::panel(cx)).with_compute_indents_fn(
                cx.entity(),
                |this: &mut AnahatListesi, range, _, _| {
                    this.girdiler[range]
                        .iter()
                        .map(|girdi| girdi.derinlik)
                        .collect()
                },
            ),
        )
    }
}
```

Zed içinden kullanım örnekleri:

- `project_panel` crate'i: project tree indent guide'ları için özel render ve tıklama davranışı uygulanır. Project panel `on_click` içinde `IndentGuideLayout::offset.y` değerinden hedef satırı bulur; secondary modifier aktifse ilgili üst girdi kapatılır.
- `outline_panel` crate'i: outline list indent guide'ları. `with_render_fn(...)` aktif guide'ı hesaplar ve `RenderedIndentGuide::is_active` alanını ayarlar.
- `git_ui` crate'i: hiyerarşik git panel satırları. Git panel özel render ile yalnızca bounds ve layout üretir; `.on_click(...)` bağlanmadığı için kılavuz çizgileri yalnızca görsel kalır. `hitbox: None` verildiğinde, etkileşim açıksa `bounds` hitbox olarak kullanılır.

Dikkat edilmesi gereken noktalar:

- `indent_size` değeri satırların `.indent_step_size(...)` değeri ile uyumlu olmalıdır; aksi halde girinti çizgileri ile satır içerikleri birbirinden kayar.
- `with_compute_indents_fn(...)` geri çağrısı (callback), görünür aralık için tam olarak o aralıktaki depth dizisini üretmelidir.
- Özel render sırasında hitbox alanını biraz büyütmek, ince 1px çizgilerin tıklanmasını çok daha kolaylaştırır.

## Liste ve Tree Kompozisyon Örnekleri

Açılıp kapanabilen bir bölüm için `ListHeader` ile `List` birlikte kullanılır. Aşağıdaki örnekte genişleme değeri view durumunda tutulur ve header'ın disclosure ikonu bu değeri toggle eder:

```rust
use ui::prelude::*;
use ui::{List, ListHeader, ListItem};

struct BagimlilikListesi {
    genisletildi: bool,
}

impl Render for BagimlilikListesi {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        List::new()
            .header(
                ListHeader::new("Bağımlılıklar")
                    .toggle(Some(self.genisletildi))
                    .on_toggle(cx.listener(|this: &mut BagimlilikListesi, _, _, cx| {
                        this.genisletildi = !this.genisletildi;
                        cx.notify();
                    })),
            )
            .when(self.genisletildi, |liste| {
                liste.child(
                    ListItem::new("bagimlilik-gpui")
                        .start_slot(Icon::new(IconName::Folder).size(IconSize::Small))
                        .child(Label::new("gpui")),
                )
            })
    }
}
```

Sağ tık destekli bir satırda ise `ListItem::on_secondary_mouse_down` olayı, sağ tıklamayı yakalar ve istenirse `right_click_menu(...)` ile birlikte kullanılabilir. Aşağıdaki örnek yalnızca olayı yakalamayı göstermektedir:

```rust
use ui::prelude::*;
use ui::{ListItem, Tooltip};

fn baglamli_dosya_satiri_render() -> impl IntoElement {
    ListItem::new("baglamli-dosya-satiri")
        .start_slot(Icon::new(IconName::File).size(IconSize::Small))
        .child(Label::new("ayarlar.json").truncate())
        .end_slot(
            IconButton::new("baglamli-dosya-eylemleri", IconName::Ellipsis)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Dosya eylemleri")),
        )
        .show_end_slot_on_hover()
        .on_secondary_mouse_down(|olay, _window, cx| {
            cx.stop_propagation();
            let _konum = olay.position;
        })
}
```
