# 8. Scrollbar ve Scroll Altyapısı

Scrollbar bileşeni, panel, liste, modal ve özel scroll kapsayıcılarında Zed temasıyla uyumlu bir scroll geri bildirimi sağlar. Layout primitiflerinden ayrı anlatılmasının nedeni şudur: scrollbar yalnızca çizilen bir görsel parça değildir. Tema ayarına, scrollbar görünürlüğü tercihine ve `ScrollableHandle` ile kurduğu bağlantıya göre davranır. Bu yüzden basit bir layout yardımcısından daha fazla sorumluluk taşır.

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Scrollbars`, `ui::ScrollAxes`, `ui::ScrollbarStyle`, `ui::scrollbars::{ShowScrollbar, ScrollbarAutoHide, ScrollbarVisibility}`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan bir bileşen önizlemesi yok; gerçek kullanım örnekleri panel, modal ve tablo kompozisyonlarının içinde görünür.

Ne zaman kullanılır:

- Bir scroll kapsayıcısına, Zed tema renkleriyle uyumlu bir scrollbar bağlamak için.
- Tablo, panel veya picker gibi içeriklerde, tema scrollbar ayarına saygı duyan otomatik gösterim ve gizleme davranışı gerektiğinde.
- Yatay, dikey veya iki yönlü scroll track'inin tek bir API üzerinden yönetilmesi gerektiğinde.

Ne zaman kullanılmaz:

- Doğal scroll davranışı yeterliyse `overflow_y_scroll()` veya `overflow_x_scroll()` ile basit bir kapsayıcı tercih edilir. `Scrollbars`, tema ile hizalanmış özel bir scrollbar yüzeyi gerektiğinde devreye girer; her scroll alanına eklenmesi zorunlu değildir.

Temel API:

- `Scrollbars::new(show_along: ScrollAxes)`.
- `Scrollbars::always_visible(show_along)`.
- `Scrollbars::for_settings::<S: ScrollbarVisibility + Default>()`.
- `.id(ElementId)`, `.notify_content()`, `.tracked_entity(EntityId)`, `.tracked_scroll_handle(&handle)`, `.show_along(axes)`, `.style(style)`, `.with_track_along(axes, bg)`, `.with_stable_track_along(axes, bg)`.
- `WithScrollbar`: elementlere `.vertical_scrollbar_for(...)` ve `.custom_scrollbars(...)` metodlarını ekleyen bir extension trait'tir. Kaynakta yatay ve çift yönlü yardımcı taslakları yorum satırı olarak durur; bu yardımcılar public API değildir.
- `ScrollableHandle`: kendi handle'ını yazıyorsan, `max_offset`, `set_offset`, `offset`, `viewport` ve opsiyonel olarak sürükleme hook'larını sağlaman gerekir. Bu sözleşme, `Scrollbars`'ın handle ile nasıl konuşacağını belirler.
- `on_new_scrollbars::<S>(cx)`: scrollbar global setting tipinin değiştiği durumlarda, yeni kurulan scrollbar durumlarını bu ayar değişikliklerine abone eden ve değişiklikte yeniden hesaplatan kurulum yardımcısıdır.
- `ScrollAxes`: `Horizontal`, `Vertical`, `Both`.
- `ScrollbarStyle`: `Regular` (6px), `Editor` (15px).
- `EDITOR_SCROLLBAR_WIDTH`: `ScrollbarStyle::Editor.to_pixels()` ile aynı değeri taşıyan 15px sabitidir. Editör scrollbar'ı ile aynı genişlikte boşluk ayrılması veya panel hizalaması gerektiğinde kullanılır.
- `ShowScrollbar`: `Auto`, `System`, `Always`, `Never`.
- `ScrollbarAutoHide::should_hide()`: platform veya ayar katmanından gelen otomatik gizleme bayrağını okur. Bu değer her ayar kurulumunda değil, yalnız ayar `ShowScrollbar::System` olduğunda görünürlüğü belirler; bu durumda scrollbar autohide ile sistem tercihini izler. Bileşen içinde manuel olarak polling yapmak yerine ayar tipini scrollbar'a bağlamak daha doğru bir yaklaşımdır.

Scrollbar altyapı yüzeyi:

| API | Rol |
| :-- | :-- |
| `ScrollAxes` | Scrollbar'ın yatay, dikey veya iki eksende çizileceğini seçer: `Horizontal`, `Vertical`, `Both`. |
| `ScrollableHandle` | Scrollbar'ın içerik offset'i, viewport, maksimum offset ve sürükleme yaşam döngüsü ile konuştuğu trait sözleşmesidir. |
| `WithScrollbar` | Elementlere `.vertical_scrollbar_for(...)` ve `.custom_scrollbars(...)` extension metodlarını ekler. |
| `ShowScrollbar` | Ayar seviyesinde görünürlük politikasını taşır: `Auto`, `System`, `Always`, `Never`. |
| `ScrollbarVisibility` | Global ayar tipinin scrollbar görünürlük tercihini public trait olarak sağlar. |
| `ScrollbarAutoHide` | Platform veya ayardan gelen otomatik gizleme bilgisini `should_hide()` ile okuyan küçük sarmalayıcıdır. |
| `ScrollbarPrepaintState` | Üst hitbox ve thumb prepaint bilgisini tutar; `Scrollbars` elementinin dahili hit test ve sürükleme hazırlık aşamalarında kullanılır. |
| `on_new_scrollbars` | Yeni kurulan scrollbar durumlarını ayar değişikliklerine abone edip değişiklikte yeniden hesaplatan kurulum yardımcısıdır. |

Davranış:

- `Scrollbars::new(ScrollAxes::Vertical)` varsayılan `ShowScrollbar::Auto` ayarıyla otomatik gizleme (autohide) şeklinde çalışır. Global ayar tipine bağlamak istendiğinde `Scrollbars::for_settings::<S>()` tercih edilir. `always_visible(...)` ayarı ise görünürlük tercihini yok sayarak scrollbar'ı her zaman görünür kılar.
- `tracked_scroll_handle(&handle)` ile harici bir `ScrollableHandle` (örneğin bir `ScrollHandle` veya `UniformListScrollHandle`) bağlanır; scrollbar bu handle üzerinden okuma ve yazma işlemlerini yürütür.
- `Table::interactable(...)` ile `TableInteractionState::with_custom_scrollbar(...)` birlikte kullanıldığında `Scrollbars`, tablonun yatay ve dikey scroll handle'larına bağlanır; yani tablo kendi scroll davranışını dış bir scrollbar üzerinden sürer.
- `ScrollbarStyle::Editor`, editor görseliyle gelen scrollbar genişliğinde çizim yapar; panel ve listelerde ise `Regular` daha uygundur.
- `ListState` tabanlı değişken yükseklikli listelerde scrollbar sürükleme durumu `scrollbar_drag_started()`, `scrollbar_drag_ended()` ve `is_scrollbar_dragging()` ile izlenir. `set_offset_from_scrollbar(point)` çağrısında aşağı yöndeki kaydırma negatif `y` offset değeriyle temsil edilir; `point(px(0.), px(-150.))` içeriğin 150px aşağı kaydırıldığı durumu ifade eder.
- Sürükleme sırasında liste içeriği büyürse scrollbar konumu sürükleme başlangıcındaki içerik yüksekliğine göre korunur. Kullanıcı sürüklemeyi kaydırma alanının sonuna getirdiğinde tail-follow yeniden etkinleşir; bu durum özellikle log, terminal ve yapay zeka sohbetleri gibi sona akması gereken listelerde manuel kaydırma ile otomatik takip arasındaki ayrımı korur.
- `ScrollbarPrepaintState`, prepaint aşamasında üst hitbox'ı ve yatay/dikey thumb yerleşimlerini (layout) tutar. Struct public görünür ama alanları private olduğu için tüketici kodunun doğrudan oluşturabileceği bir model değildir; thumb hit test, track tıklaması ve sürükleme başlangıcı için `Scrollbars` elementi tarafından dahili olarak kullanılır.

Örnek:

```rust
use gpui::ScrollHandle;
use ui::prelude::*;
use ui::{ScrollAxes, Scrollbars, WithScrollbar};

struct GunlukPaneli {
    kaydirma: ScrollHandle,
}

impl Render for GunlukPaneli {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .size_full()
            .child(
                div()
                    .id("gunluk-govdesi")
                    .flex_1()
                    .overflow_y_scroll()
                    .track_scroll(&self.kaydirma)
                    .child(Label::new("…"))
                    .custom_scrollbars(
                        Scrollbars::new(ScrollAxes::Vertical)
                            .tracked_scroll_handle(&self.kaydirma),
                        window,
                        cx,
                    ),
            )
    }
}
```

Dikkat edilmesi gereken noktalar:

- `Scrollbars` kendi başına içerik kaydırmaz. İçeriğin gerçekten kaydırılabilmesi için onun bir `ScrollableHandle` ile bağlanması veya bir `ScrollHandle::new()` üzerinden takip edilmesi gerekir.
- Tek bir scroll kapsayıcısına doğrudan bağlanılıyorsa `WithScrollbar` yardımcılarını kullanmak, ayrı bir `Scrollbars` alt öğesi (child) eklemeye kıyasla hem daha pratik hem de hata payı daha düşük bir yaklaşımdır.
- `with_stable_track_along(...)` metodu, scroll alanı henüz yokken bile track için yer ayırır. Bu sayede scrollbar görünür veya gizli olarak değiştiğinde düzen (layout) aniden zıplamaz; sahne sabit kalır.
- Birden fazla scroll alanı bulunuyorsa, her birine `.id(...)` üzerinden benzersiz bir ID tanımlanması gerekir; aksi takdirde GPUI scroll durumlarını karıştırabilir.
- `set_offset_from_scrollbar(...)` için pozitif offset kullanımı güncel API sözleşmesine uymaz. Scrollbar handle geliştirilirken `offset()` and `set_offset(...)` değerlerinin aynı yön işaretlerini kullandığından emin olunması gerekir.
