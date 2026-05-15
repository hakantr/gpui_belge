# 8. Scrollbar ve Scroll Altyapısı

Scrollbar bileşeni Zed UI içinde panel, liste, modal ve özel scroll
container'larında tema renkleriyle uyumlu scroll geri bildirimi sağlar.
Layout primitive'lerinden ayrı tutulur çünkü tema ayarı, scrollbar
görünürlüğü ve `ScrollableHandle` ile entegre çalışır.

Kaynak:

- Tanım: `../zed/crates/ui/src/components/scrollbar.rs`
- Export: `ui::Scrollbars`, `ui::ScrollAxes`, `ui::ScrollbarStyle`,
  `ui::scrollbars::{ShowScrollbar, ScrollbarAutoHide, ScrollbarVisibility}`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan component preview yok; gerçek kullanım panel, modal ve
  tablo kompozisyonları içindedir.

Ne zaman kullanılır:

- Bir scroll container'a Zed tema renkleriyle uyumlu scrollbar bağlamak için.
- Tablo, panel veya picker gibi içeriklerde tema scrollbar ayarına saygı
  duyan otomatik gösterim/gizleme davranışı gerektiğinde.
- Yatay, dikey veya iki yönlü scroll track'ini tek API ile yönetmek için.

Ne zaman kullanılmaz:

- Doğal browser/native scroll yeterliyse `overflow_y_scroll()` veya
  `overflow_x_scroll()` ile basit container kullanın; `Scrollbars`, tema ile
  hizalanmış özel scrollbar yüzeyi gerektiğinde devreye girer.

Temel API:

- `Scrollbars::new(show_along: ScrollAxes)`
- `Scrollbars::always_visible(show_along)`
- `Scrollbars::for_settings::<S: ScrollbarVisibility>()`
- `.id(ElementId)`, `.notify_content()`, `.tracked_entity(EntityId)`,
  `.tracked_scroll_handle(handle)`, `.show_along(axes)`, `.style(style)`,
  `.with_track_along(axes, bg)`, `.with_stable_track_along(axes, bg)`
- `WithScrollbar`: elementlere `.vertical_scrollbar_for(...)` ve
  `.custom_scrollbars(...)` ekleyen extension trait. Kaynakta yatay/double helper
  taslakları yorum satırı olarak durur; public API değildir.
- `ScrollableHandle`: custom handle yazacaksanız `max_offset`, `set_offset`,
  `offset`, `viewport` ve opsiyonel drag hook'larını sağlar.
- `on_new_scrollbars::<S>(cx)`: scrollbar global setting tipi değiştiğinde
  yeni `ScrollbarState` entity'lerini ayar değişikliklerine abone eden setup
  helper'ı.
- `ScrollAxes`: `Horizontal`, `Vertical`, `Both`.
- `ScrollbarStyle`: `Regular` (6px), `Editor` (15px).
- `ShowScrollbar`: `Auto`, `System`, `Always`, `Never`.

Davranış:

- `Scrollbars::new(ScrollAxes::Vertical)` varsayılan olarak tema scrollbar
  ayarına bağlı görünür; `always_visible(...)` ayarı yok sayar.
- `tracked_scroll_handle(...)`, harici bir `ScrollableHandle` (örn.
  `ScrollHandle`, `UniformListScrollHandle`) kullanır.
- `Table::interactable(...)` ile `TableInteractionState::with_custom_scrollbar(...)`
  birlikte verildiğinde `Scrollbars` tablonun yatay/dikey scroll handle'larına
  bağlanır.
- `ScrollbarStyle::Editor`, editor görselli scrollbar genişliği için
  kullanılır; panel ve liste için `Regular` daha uygundur.

Örnek:

```rust
use gpui::ScrollHandle;
use ui::prelude::*;
use ui::{ScrollAxes, Scrollbars};

struct LogPanel {
    scroll: ScrollHandle,
}

impl Render for LogPanel {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .size_full()
            .child(
                div()
                    .id("log-body")
                    .flex_1()
                    .overflow_y_scroll()
                    .track_scroll(&self.scroll)
                    .child(Label::new("…")),
            )
            .child(
                Scrollbars::new(ScrollAxes::Vertical)
                    .tracked_scroll_handle(self.scroll.clone()),
            )
    }
}
```

Dikkat edilecekler:

- `Scrollbars` kendi başına içerik scroll'lamaz; bir `ScrollableHandle` ile
  bağlanmalı veya bir `ScrollHandle::new()` üzerinden takip etmelidir.
- Tek bir scroll container'a doğrudan bağlanıyorsanız `WithScrollbar` helper'ları
  ayrı `Scrollbars` child'ı yazmaktan daha kısa ve daha az hata açıktır.
- `with_stable_track_along(...)`, scroll alanı yokken bile track yer ayırır;
  böylece scrollbar görünür/gizli değiştiğinde layout zıplaması olmaz.
- Birden çok scroll alanı varsa her birine `.id(...)` ile benzersiz id verin.

