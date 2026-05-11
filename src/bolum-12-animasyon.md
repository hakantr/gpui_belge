# 12. Animasyon

---

## 12.1. Animasyon Sistemi

Kaynak: `crates/gpui/src/elements/animation.rs`.

GPUI'de animasyon, bir element'in zaman içinde aldığı style/boyut/opaklık değişimini bir **delta değeri** (`0.0` → `1.0`) üzerinden ifade etmektir. Belirlenmiş sürede sistem geçerli `delta`'yı hesaplar (easing fonksiyonundan geçirip yumuşatır), elemente her frame yeniden render imkânı sağlar. Bu yaklaşım deklaratiftir: hangi alanın nasıl ilerleyeceği tek bir closure'da tanımlanır, frame frame state yönetilmez.

### `Animation` yapısı

`Animation` üç alandan oluşur:

- **`duration: Duration`** — Animasyonun toplam süresi.
- **`oneshot: bool`** — `true` tek seferlik (default), `false` döngüye alır.
- **`easing: Rc<dyn Fn(f32) -> f32>`** — Doğrusal süreyi `[0.0, 1.0]` aralığında dağıtan fonksiyon (yumuşatma eğrisi).

Builder yapısı:

- **`Animation::new(duration)`** — Linear easing ile tek seferlik animasyon.
- **`.repeat()`** — Döngüye alır.
- **`.with_easing(fn)`** — Easing'i değiştirir.

### `AnimationExt` — element üzerine bağlama

`AnimationExt` trait, herhangi bir `IntoElement` üzerine animasyon eklenebilen iki method sunar:

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

Closure imzası `Fn(El, f32) -> El` formundadır: animasyon ID (örn. `"grow"`) ve `delta` parametresiyle her frame elemente uygulanacak transform belirtilir. Burada element 100px'ten 200px'e büyür.

Çoklu animasyon ardışık zinciri için `with_animations(id, vec![anim_a, anim_b], |el, ix, delta| ...)` kullanılır; `ix` o anki sıradaki animasyonun index'ini verir.

### Yerleşik easing fonksiyonları

`crates/gpui/src/elements/animation.rs:211+`:

- **`linear`** — Doğrusal (0→1 sabit hızla).
- **`quadratic`** — Kare eğri.
- **`ease_in_out`** — Başta ve sonda yumuşak, ortada hızlı (en sık kullanılan).
- **`ease_out_quint()`** — Sonu çok yumuşak (kuvvetli yavaşlama).
- **`bounce(inner)`** — İçteki easing'i alıp sonuna zıplama (bounce) ekler.
- **`pulsating_between(min, max)`** — `min` ↔ `max` arasında yön değiştirerek titreşir. Loading indicator için ideal; `Animation::repeat()` ile birlikte kullanılır.

### Tuzaklar

- **Element ID render boyunca stabil olmalıdır;** değişirse animasyon state'i sıfırlanır ve animasyon baştan başlar.
- **Animator closure `'static` olduğu için dış state `Rc`/`Arc`/`clone` ile yakalanır.** Borç alınan referans closure'a sığmaz.
- **`Repeat` animasyonu her frame'de `window.request_animation_frame()` ile sonraki frame'i ister;** bu, view'ı sürekli notify eder ve CPU kullanımı artar. Gerekmiyorsa oneshot bırakılır.
- **Frame'ler arası progress executor saatinden hesaplanır.** Normal `TestAppContext` / `VisualTestContext` testlerinde `cx.background_executor.advance_clock(...)` veya `TestApp::advance_clock(...)` ile zaman ilerletilir. macOS'a özgü `VisualTestAppContext` üzerinde ayrıca doğrudan `advance_clock(...)` helper'ı vardır.


---

