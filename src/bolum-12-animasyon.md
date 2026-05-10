# Bölüm XII — Animasyon

---

## 68. Animasyon Sistemi

Animasyon API `crates/gpui/src/elements/animation.rs` içindedir.

`Animation` üç alandan oluşur: `duration: Duration`, `oneshot: bool` (false ise
tekrar eder), `easing: Rc<dyn Fn(f32) -> f32>`. Inşa: `Animation::new(duration)`
linear easing ile tek seferlik animasyon oluşturur. `.repeat()` döngüye alır,
`.with_easing(fn)` easing değiştirir.

`AnimationExt` trait, herhangi bir `IntoElement` için iki metot ekler:

```rust
use gpui::{Animation, AnimationExt};
use std::time::Duration;

div()
    .size(px(100.))
    .with_animation(
        "grow",
        Animation::new(Duration::from_millis(500))
            .with_easing(gpui::ease_in_out),
        |el, delta| el.size(px(100. + 100. * delta)),
    )
```

Çoklu animasyon zinciri için `with_animations(id, vec![anim_a, anim_b], |el, ix, delta| ...)`.

Yerleşik easing fonksiyonları (`crates/gpui/src/elements/animation.rs:211+`):
`linear`, `quadratic`, `ease_in_out`, `ease_out_quint()`, `bounce(inner)`,
`pulsating_between(min, max)`. `pulsating_between` yön değiştirerek değer döndürür
(loading indicator için ideal; `Animation::repeat()` ile birleştirilir).

Tuzaklar:

- Element ID render boyunca stabil olmalıdır; değişirse animasyon state sıfırlanır.
- Animator closure `'static` olduğundan dış state'i `Rc`/`Arc`/`clone` ile yakala.
- Repeat animasyonu `window.request_animation_frame()` ile bir sonraki frame'i ister;
  bu da mevcut view'i sonraki frame'de notify eder. Gerekmiyorsa oneshot bırak.
- Frame'ler arası progress değeri executor saatinden hesaplanır; normal
  `TestAppContext`/`VisualTestContext` testlerinde `cx.background_executor.advance_clock(...)`
  veya `TestApp::advance_clock(...)` kullan. macOS'a özel `VisualTestAppContext`
  üzerinde ayrıca doğrudan `advance_clock(...)` helper'ı vardır.


---

