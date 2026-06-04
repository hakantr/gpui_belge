# Erişilebilirlik

GPUI'nin mevcut public yüzeyi erişilebilirlik bilgisini AccessKit üzerinden taşır. `gpui` crate kökü `accesskit` modülünü ve sık kullanılan `Action`, `Role`, `Orientation`, `Toggled` tiplerini yeniden dışa aktarır; `Action` dışarıda `AccessibleAction` adıyla kullanılır. Uygulama kodunda erişilebilirlik bilgisi çoğunlukla `div().id(...).role(...).aria_*()` zinciri ve `text!` makrosu üzerinden verilir.

## Temel Model

GPUI erişilebilirlik ağacını element ağacından üretir, fakat her görsel element otomatik olarak anlamlı bir erişilebilirlik node'u sayılmaz. Ekran okuyucuya anlamlı bir node vermek için iki şey gerekir:

- Stabil bir element kimliği: `div().id("kaydet")` veya tekrar eden öğelerde kayıt kimliğine bağlı bir ID.
- Anlamlı rol ve özellikler: `role(Role::Button)`, `aria_label(...)`, `aria_selected(...)`, `aria_toggled(...)` gibi metotlar.

`role(Role::GenericContainer)` kullanma; bu rol GPUI erişilebilirlik ağacında filtrelenir ve etkili bir node üretmez. Sıradan layout kapsayıcılarında rol vermemek genellikle daha doğrudur. Erişilebilirlik bilgisi, kullanıcının etkileştiği veya ekran okuyucuda duyulması gereken semantik yüzeylere verilmelidir.

ID kararlılığı erişilebilirlik için de önemlidir. Aynı kontrol her render'da farklı ID alırsa ekran okuyucu bunu güncellenen bir node olarak değil, silinen ve yeniden eklenen bir node olarak algılar. Liste satırlarında sıra numarası yerine mümkünse domain kimliği kullanırsın.

## Metin Node'ları

Düz string çocuklar ekranda çizilebilir, ancak erişilebilirlik ağacında stabil metin node'u gerektiğinde `Text` veya `text!` kullanırsın:

- `text!("Başlık")` aynı makro çağrı konumundan türetilen stabil bir `ElementId` üretir.
- `text!(id = "durum-mesaji", metin)` metin ID'sini açıkça verir; dinamik veya tekrar eden içerikte en güvenli yoldur.
- `Text::new(id, SharedString)` elle kurulan erişilebilir metin node'u üretir.
- `Text::new_inaccessible(text)` metni ekran okuyucudan gizler; parent container zaten `aria_label(...)` ile aynı bilgiyi veriyorsa tekrar duyurmayı önlemek için kullanılır.

Tek bir `text!` çağrısını tekrar eden satır builder'ında kullanırken dikkatli ol. Aynı kaynak konumu aynı ID'yi üreteceği için satır başına farklı erişilebilir metin node'u gerekiyorsa `text!(id = ("satir-baslik", kayit_id), baslik)` biçiminde açık ID verirsin.

## Etkileşimli Element API'si

Erişilebilirlik fluent metotları `StatefulInteractiveElement` üzerinde bulunur; pratikte önce `.id(...)` çağırıp sonra semantik bilgiyi eklersin:

- `role(Role::Button)`, `role(Role::Checkbox)`, `role(Role::Switch)`, `role(Role::SpinButton)` gibi AccessKit rolleri.
- `aria_label(text)` görünür metinden bağımsız duyurulacak etiketi verir.
- `aria_selected(bool)`, `aria_expanded(bool)`, `aria_toggled(Toggled::True | Toggled::False | Toggled::Mixed)` seçim, açılma ve toggle durumunu taşır.
- `aria_numeric_value(f64)`, `aria_min_numeric_value(f64)`, `aria_max_numeric_value(f64)` sayaç, slider veya spinbutton gibi sayısal kontroller içindir.
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

Bu örnekte framework tipleri İngilizce kalır; uygulama state'i ve yardımcı değişkenler Türkçe adlandırılır. Action listener'ları view state'ini `WeakEntity` üzerinden günceller ve sonuçta `cx.notify()` çağırır.

## Platform ve Test Notları

`Application::new_inaccessible(platform)` GPUI uygulamasını AccessKit entegrasyonu olmadan başlatır. Bu yol başsız test, screenshot üretimi veya erişilebilirlik köprüsünün bilinçli olarak kapatıldığı ortamlar içindir. Böyle bir uygulamada `.role(...)` ve `.aria_*()` zincirleri element üstünde kalır, fakat platform adapter'ına erişilebilirlik ağacı gönderilmez.

Platform arka ucu yazıyorsan erişilebilirlik köprüsü `A11yCallbacks` ve `PlatformWindow` üzerindeki `a11y_init`, `a11y_tree_update`, `a11y_update_window_bounds` çağrılarıyla kurulur. Uygulama veya component kodu bu seviyeye normalde inmez. Ekran okuyucudan gelen action'ı bağlamak için düşük seviyeli `Window::on_a11y_action(node_id, action, listener)` yerine element üzerindeki `.on_a11y_action(...)` fluent metodunu tercih edersin.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `accesskit` | crate kök reexport | AccessKit tiplerini GPUI kökünden erişilebilir yapar. |
| `AccessibleAction` | `accesskit::Action` reexport'u | Ekran okuyucudan gelen click/increment/decrement gibi action isteklerini temsil eder. |
| `Role` | AccessKit role reexport'u | Elementin semantik rolünü belirtir. |
| `Orientation` | `Horizontal`, `Vertical` | Slider/list/tree gibi yönlü accessibility yüzeylerinde yön bilgisini taşır. |
| `Toggled` | `True`, `False`, `Mixed` | Toggle/switch/checkbox state'ini accessibility ağacına aktarır. |
| `A11yCallbacks` | init/tree/window-bounds callbacks | `PlatformWindow` erişilebilirlik köprüsünde platforma ait callback setidir. |
| `PlatformWindow` | `a11y_init`, `a11y_tree_update`, `a11y_update_window_bounds` | Erişilebilirlik ağacını platform penceresine taşıyan düşük seviye trait yüzeyidir. |
| `_accessibility` | rustdoc-only modül | GPUI'nin AccessKit re-export ve accessibility doc yüzeyini bir arada gösteren gizli/dokümantasyon amaçlı modül sınırıdır; uygulama kodu doğrudan import etmez. |

Pratik kontrol listesi:

- Etkileşimli her ham `div()` için stabil `.id(...)` ver.
- Kontrolün görünür metni belirsizse veya ikon-only ise `aria_label(...)` ekle.
- Toggle, seçim, genişleme ve sayısal değer state'ini render çıktısındaki gerçek state ile aynı yerde üret.
- Tekrarlı dinamik metinlerde açık `text!(id = ..., metin)` kullan.
- Parent `aria_label(...)` zaten aynı bilgiyi veriyorsa dekoratif veya tekrarlı alt metni `Text::new_inaccessible(...)` ile gizle.
