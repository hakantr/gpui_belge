# Erişilebilirlik

GPUI'nin mevcut public yüzeyi erişilebilirlik bilgisini AccessKit üzerinden taşır. `gpui` crate kökü `accesskit` modülünü ve sık kullanılan `Action`, `Role`, `Orientation`, `Toggled` tiplerini yeniden dışa aktarır; `Action` dışarıda `AccessibleAction` adıyla kullanılır. Uygulama kodunda erişilebilirlik bilgisi çoğunlukla `div().id(...).role(...).aria_*()` zinciri ve `text!` makrosu üzerinden tanımlanır.

## Temel Model

GPUI erişilebilirlik ağacını element ağacından üretir, fakat her görsel element otomatik olarak anlamlı bir erişilebilirlik node'u sayılmaz. Ekran okuyucuya anlamlı bir node sağlamak için iki unsur gereklidir:

- Stabil bir element kimliği: `div().id("kaydet")` veya tekrar eden öğelerde kayıt kimliğine bağlı benzersiz bir ID.
- Anlamlı rol ve özellikler: `role(Role::Button)`, `aria_label(...)`, `aria_selected(...)`, `aria_toggled(...)` gibi metotlar.

`role(Role::GenericContainer)` rolünün kullanılmasından kaçınılmalıdır; bu rol GPUI erişilebilirlik ağacında filtrelenir. `role(Role::GenericContainer)` çağrısı debug derlemede bir doğrulama (`debug_assert`) tetikleyerek panik oluşturur; release derlemede ise etkili bir node üretmez. Sıradan layout kapsayıcılarında rol belirtmemek genellikle daha doğrudur. Erişilebilirlik bilgisi, kullanıcının etkileştiği veya ekran okuyucuda duyulması gereken semantik yüzeylere tanımlanmalıdır.

ID kararlılığı erişilebilirlik için son derece önemlidir. Aynı kontrol her render aşamasında farklı bir ID alırsa ekran okuyucu bunu güncellenen bir node olarak değil, silinen ve yeniden eklenen yeni bir node olarak algılar. Liste satırlarında sıra numarası yerine mümkünse domain kimliği tercih edilmelidir.

## Metin Node'ları

Düz string alt öğeler (çocuklar) ekranda çizilebilir, ancak erişilebilirlik ağacında sabit metin node'u gerektiğinde `Text` veya `text!` kullanılır:

- `text!("Başlık")` aynı makro çağrı konumundan türetilen sabit bir `ElementId` üretir.
- `text!(id = "durum-mesaji", metin)` metin ID'sini açıkça belirterek dinamik veya tekrar eden içerikte en güvenli yolu sunar.
- `Text::new(id, SharedString)` elle kurulan erişilebilir metin node'u üretir.
- `Text::new_inaccessible(text)` metni ekran okuyucudan gizler; parent container zaten `aria_label(...)` ile aynı bilgiyi veriyorsa tekrar duyurmayı önlemek için tercih edilir.

Tek bir `text!` çağrısını tekrar eden satır oluşturucusunda (builder) kullanırken dikkatli olunmalıdır. Aynı kaynak konumu aynı ID'yi üreteceği için satır başına farklı erişilebilir metin node'u gerekiyorsa `text!(id = ("satir-baslik", kayit_id), baslik)` biçiminde açıkça bir ID belirtilir.

## Etkileşimli Element API'si

Erişilebilirlik akıcı (fluent) metotları `StatefulInteractiveElement` üzerinde bulunur; pratikte önce `.id(...)` çağrılıp ardından semantik bilgi eklenir:

- `role(Role::Button)`, `role(Role::CheckBox)`, `role(Role::Switch)`, `role(Role::SpinButton)` gibi AccessKit rolleri.
- `aria_label(text)` görünür metinden bağımsız duyurulacak etiketi tanımlar.
- `aria_selected(bool)`, `aria_expanded(bool)`, `aria_toggled(Toggled::True | Toggled::False | Toggled::Mixed)` seçim, açılma ve toggle durumunu taşır.
- `aria_active_descendant()` bileşik widget desenlerinde gerçek klavye odağı parent üzerinde kalırken seçili child node'un erişilebilirlik odağı gibi duyurulmasını sağlar.
- `a11y_synthetic_children(|builder| ...)`, element ağacında karşılığı olmayan sentetik erişilebilirlik child node'larını ilgili element node'unun altına ekler.
- `aria_numeric_value(f64)`, `aria_numeric_value_step(f64)`, `aria_min_numeric_value(f64)`, `aria_max_numeric_value(f64)` sayaç, slider veya spinbutton gibi sayısal kontroller içindir.
- `aria_value(text)` metin tabanlı kontrolün güncel değerini, `aria_placeholder(text)` ise boş durum açıklamasını erişilebilirlik ağacına taşır.
- `aria_orientation(Orientation::Horizontal | Orientation::Vertical)` yön bilgisini belirtir.
- `aria_level(usize)`, `aria_position_in_set(usize)`, `aria_size_of_set(usize)` başlık ve liste hiyerarşilerinde kullanılır.
- `aria_row_index(...)`, `aria_column_index(...)`, `aria_row_count(...)`, `aria_column_count(...)` grid veya tablo benzeri yüzeylerde kullanılır.
- `on_a11y_action(AccessibleAction::..., listener)` ekran okuyucudan gelen action isteğini kontrol state'ine bağlar.

Örnek:

```rust
use gpui::{AccessibleAction, Context, Role, Toggled, Window, div, prelude::*, text};

struct SayacArayuzu {
    sayac: i32,
    etkin: bool,
}

impl Render for SayacArayuzu {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .id("sayac-koku")
            .role(Role::Application)
            .aria_label("Sayaç örneği")
            .child(text!(id = "sayac-baslik", "Sayaç"))
            .child(
                div()
                    .id("sayac-degeri")
                    .focusable()
                    .tab_stop(true)
                    .role(Role::SpinButton)
                    .aria_label(format!("Sayaç: {}", self.sayac))
                    .aria_numeric_value(self.sayac as f64)
                    .aria_min_numeric_value(0.0)
                    .on_a11y_action(AccessibleAction::Increment, {
                        let sayac_gorunumu = cx.entity().downgrade();
                        move |_veri, _window, cx| {
                            sayac_gorunumu
                                .update(cx, |gorunum, cx| {
                                    gorunum.sayac += 1;
                                    cx.notify();
                                })
                                .ok();
                        }
                    })
                    .on_a11y_action(AccessibleAction::Decrement, {
                        let sayac_gorunumu = cx.entity().downgrade();
                        move |_veri, _window, cx| {
                            sayac_gorunumu
                                .update(cx, |gorunum, cx| {
                                    gorunum.sayac = (gorunum.sayac - 1).max(0);
                                    cx.notify();
                                })
                                .ok();
                        }
                    })
                    .child(text!(id = "sayac-metin", format!("Değer: {}", self.sayac))),
            )
            .child(
                div()
                    .id("ozellik-anahtari")
                    .focusable()
                    .tab_stop(true)
                    .role(Role::Switch)
                    .aria_label("Özelliği etkinleştir")
                    .aria_toggled(if self.etkin {
                        Toggled::True
                    } else {
                        Toggled::False
                    })
                    .on_a11y_action(AccessibleAction::Click, {
                        let sayac_gorunumu = cx.entity().downgrade();
                        move |_veri, _window, cx| {
                            sayac_gorunumu
                                .update(cx, |gorunum, cx| {
                                    gorunum.etkin = !gorunum.etkin;
                                    cx.notify();
                                })
                                .ok();
                        }
                    })
                    .child(text!(id = "ozellik-metin", "Özellik")),
            )
    }
}
```

Bu örnekte framework tipleri İngilizce kalır; uygulama durumu ve yardımcı değişkenler Türkçe adlandırılır. Action listener'ları view durumunu `WeakEntity` üzerinden günceller ve sonuçta `cx.notify()` çağırır.

## Sentetik Node ve Aktif Descendant

Özel `Element` uygulamaları, tek bir çizim yüzeyi içinde birden fazla semantik erişilebilirlik node'u göstermek zorunda kalabilir. Bu durumda `Element::a11y_synthetic_children(&mut self, prepaint, builder)` düşük seviye kancası çalışır. GPUI bu kancayı `prepaint` sonrasında çağırır; böylece görünür aralık, imleç konumu veya ölçülmüş sınırlar gibi `PrepaintState` verileri erişilebilirlik ağacına yansıtılabilir. Ham `div()` zincirinde aynı davranış `StatefulInteractiveElement::a11y_synthetic_children(|builder| ...)` ile eklenir; closure yalnız element `.id(...)` ve `.role(...)` üzerinden erişilebilirlik node'u ürettiğinde çalışır.

`A11ySubtreeBuilder` yalnızca ilgili elementin erişilebilirlik node'u oluşturulduğunda çağrıya verilir. Builder, parent node'a güvenli biçimde child eklemek ve aynı parent altında kararlı `NodeId` üretmek için kullanılır:

| API | Rol |
| :-- | :-- |
| `Element::a11y_synthetic_children(&mut self, prepaint, builder)` | Özel `Element` implementasyonlarının sentetik erişilebilirlik child node'ları üretmesini sağlar. |
| `StatefulInteractiveElement::a11y_synthetic_children(f)` | `div().id(...).role(...).a11y_synthetic_children(...)` zincirinde aynı davranışı fluent olarak bağlar. |
| `A11ySubtreeBuilder::synthetic_node_id(key)` | Parent node kimliğiyle birlikte verilen anahtarı hashleyerek child için kararlı `NodeId` üretir. |
| `A11ySubtreeBuilder::push_child(id, node)` | Sentetik leaf node'u parent node'un child'ı olarak ekler; aynı ID ağaçta varsa `false` döner. |
| `A11ySubtreeBuilder::parent_node()` | Parent `accesskit::Node` üzerinde text selection gibi ek özellikler yazılması gerektiğinde mutable referans sağlar. |

`aria_active_descendant()` ayrı ama tamamlayıcı bir desendir. Odak, container üzerinde kalır; seçili satır veya menü girdisi ise erişilebilirlik ağacında aktif descendant olarak işaretlenir. Bu yöntem menü, listbox ve benzeri composite widget'larda seçili öğenin ekran okuyucu tarafından odaklanmış gibi duyurulmasını sağlar. GPUI bu bildirimi yalnızca ilgili node'un odaklı bir ancestor'ı varsa uygular; bu nedenle seçili child üzerinde koşulsuz ayarlanması güvenlidir.

## Platform ve Test Notları

`Application::new_inaccessible(platform)` GPUI uygulamasını AccessKit entegrasyonu olmadan başlatır. Bu yol başsız test, screenshot üretimi veya erişilebilirlik köprüsünün bilinçli olarak kapatıldığı ortamlar içindir. Böyle bir uygulamada `.role(...)` ve `.aria_*()` zincirlerini tanımlamak mümkündür, fakat erişilebilirlik entegrasyonu zorla kapatıldığı için AccessKit adapter çağrıları yapılmaz.

Platform arka ucu (backend) yazılırken erişilebilirlik köprüsü `A11yCallbacks` ve `PlatformWindow` üzerindeki `a11y_init`, `a11y_tree_update`, `a11y_update_window_bounds` çağrılarıyla kurulur. Uygulama veya bileşen kodu bu seviyeye normalde inmez. Ekran okuyucudan gelen action'ı bağlamak için düşük seviyeli `Window::on_a11y_action(node_id, action, listener)` yerine element üzerindeki `.on_a11y_action(...)` fluent metodu tercih edilir. Render sırasında yalnız erişilebilirlik ağacında gözlemlenecek pahalı veri hazırlanıyorsa `Window::is_a11y_active() -> bool` ile o karede erişilebilirlik ağacı üretilip üretilmediği kontrol edilebilir; erişilebilirlik etkinleştiğinde GPUI yeniden çizim tetiklediği için bu veri bir sonraki ağaç güncellemesinden önce hesaplanır.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `accesskit` | crate kök reexport | AccessKit tiplerini GPUI kökünden erişilebilir yapar. |
| `AccessibleAction` | `accesskit::Action` reexport'u | Ekran okuyucudan gelen click/increment/decrement gibi action isteklerini temsil eder. |
| `Role` | AccessKit role reexport'u | Elementin semantik rolünü belirtir. |
| `Orientation` | `Horizontal`, `Vertical` | Slider/list/tree gibi yönlü erişilebilirlik yüzeylerinde yön bilgisini taşır. |
| `Toggled` | `True`, `False`, `Mixed` | Toggle/switch/checkbox durumunu erişilebilirlik ağacına aktarır. |
| `Element::a11y_synthetic_children` | `PrepaintState`, `A11ySubtreeBuilder` | Özel elementin AccessKit ağacına gerçek GPUI child'ı olmayan synthetic node'lar eklemesini sağlar. |
| `A11ySubtreeBuilder` | `synthetic_node_id`, `push_child`, `parent_node` | Synthetic çocuk node kimliği üretir, leaf node ekler ve parent node'u günceller. |
| `StatefulInteractiveElement::aria_active_descendant` | odaklanmış ancestor şartı | Composite widget içinde seçili alt öğeyi erişilebilirlik odağı olarak raporlar. |
| `StatefulInteractiveElement::a11y_synthetic_children` | closure tabanlı builder | `div()` zincirinde synthetic erişilebilirlik child'ları üretir. |
| `A11yCallbacks` | `activation`, `action`, `deactivation` | `PlatformWindow` erişilebilirlik köprüsünde platform adapter'ının çağırdığı callback setidir. |
| `PlatformWindow` | `a11y_init`, `a11y_tree_update`, `a11y_update_window_bounds` | Erişilebilirlik ağacını platform penceresine taşıyan düşük seviye trait yüzeyidir. |
| `Window::is_a11y_active` | `pub fn is_a11y_active(&self) -> bool` | Geçerli karede erişilebilirlik ağacı üretiminin aktif olup olmadığını bildirir. |
| `Element::a11y_synthetic_children`, `A11ySubtreeBuilder` | `synthetic_node_id`, `push_child`, `parent_node` | Element karşılığı olmayan erişilebilirlik child node'larını üretmek için kullanılır. |
| `_accessibility` | rustdoc-only modül | GPUI'nin AccessKit re-export ve accessibility doc yüzeyini bir arada gösteren gizli/dokümantasyon amaçlı modül sınırıdır; uygulama kodu doğrudan import etmez. |

Pratik kontrol listesi:

- Etkileşimli her ham `div()` için sabit `.id(...)` verilmelidir.
- Kontrolün görünür metni belirsizse veya ikon-only ise `aria_label(...)` eklenmelidir.
- Toggle, seçim, genişleme ve sayısal değer durumu render çıktısındaki gerçek durumla aynı yerde üretilmelidir.
- Tekrarlı dinamik metinlerde açık `text!(id = ..., metin)` kullanılmalıdır.
- Parent `aria_label(...)` zaten aynı bilgiyi veriyorsa dekoratif veya tekrarlı alt metni `Text::new_inaccessible(...)` ile gizlenmelidir.
