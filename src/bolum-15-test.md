# 15. Test

---

## 15.1. Test Rehberi

GPUI testlerinde:

- `#[gpui::test]` macro'su ve `TestAppContext` kullan.
- Pencere gerekiyorsa test context'in offscreen/window helper'larını kullan.
- Async timer için `cx.background_executor().timer(duration).await`.
- UI action testlerinde key binding ve action dispatch'i doğrudan test et.
- Görsel test gerekiyorsa `VisualTestContext` ve headless renderer desteğini kontrol et.
- Element debug bounds gerekiyorsa test-support altında `.debug_selector(...)` ekle.

Testlerde kaçınılacaklar:

- `smol::Timer::after(...)` ile `run_until_parked()` beklemek.
- `unwrap()` ile test dışı production yoluna panik taşımak.
- Async hata sonuçlarını `let _ = ...` ile yutmak.

## 15.2. Test Bağlamları ve Simülasyon

`crates/gpui/src/app/test_context.rs`, `crates/gpui/src/app/visual_test_context.rs`.

`#[gpui::test]` makrosu bir `TestAppContext` sağlar. Görsel test için
`add_window` bir `WindowHandle<V>` döndürür ve `VisualTestContext` ile sürülür.
İsim benzerliğine dikkat: `VisualTestContext` test penceresini kendi içinde tutar;
macOS `test-support` altındaki `VisualTestAppContext` ise window handle'ı açık
argüman olarak alan ayrı bir bağlamdır.

```rust
#[gpui::test]
fn test_save(cx: &mut TestAppContext) {
    let window = cx.add_window(|window, cx| cx.new(|cx| Editor::new(window, cx)));

    cx.simulate_keystrokes(window, "cmd-s");
    cx.run_until_parked();

    window.read_with(cx, |editor, _| {
        assert!(editor.is_clean);
    });
}
```

Sık kullanılan API'ler:

- `cx.add_window(|window, cx| cx.new(...))`: yeni offscreen pencere.
- `cx.simulate_keystrokes(window, "cmd-s left")`: boşlukla ayrılmış keystroke dizisi.
- `cx.simulate_input(window, "hello")`: text input simulasyonu.
- `cx.dispatch_action(window, action)`.
- `cx.run_until_parked()`: tüm pending future/task tamamlanıncaya kadar sürer.
- `cx.background_executor.advance_clock(duration)`: deterministic timer ilerletme.
- `cx.background_executor.run_until_parked()`: test executor'ında yalnızca background.
- `window.update(cx, |view, window, cx| ...)`: pencere içi state mutate.

`add_window_view` veya `add_empty_window` ile alınan `VisualTestContext` pencere
bağlamını taşıdığı için *bazı* metotları window argümansız çağrılır:

- `cx.simulate_keystrokes("cmd-p")` ve `cx.simulate_input("hello")` — `self.window`
  kullanır.
- `cx.dispatch_action(action)` — yine `self.window` üzerinden dispatch eder.
- `cx.run_until_parked()`, `cx.window_title()`, `cx.document_path()` window-less
  helper'lardır.

Mouse simülasyon metotları `VisualTestContext` üzerinde de `self.window`
üzerinden çalışır ve window argümanı almaz (`test_context.rs:764-809`):

- `cx.simulate_mouse_move(position, button, modifiers)`
- `cx.simulate_mouse_down(position, button, modifiers)`
- `cx.simulate_mouse_up(position, button, modifiers)`
- `cx.simulate_click(position, modifiers)`

Pencere argümanı isteyen helper'lar `TestAppContext` üzerindeki
`simulate_keystrokes(window, ...)`, `simulate_input(window, ...)`,
`dispatch_action(window, ...)` ve `dispatch_keystroke(window, ...)` ailesidir.
`VisualTestContext` bu window handle'ı kendi içinde tuttuğu için aynı klavye ve
action helper'larını window-less sarmallar olarak sunar.
`VisualTestAppContext` ise `simulate_keystrokes(window, ...)`,
`simulate_mouse_move(window, ...)`, `simulate_click(window, ...)` ve
`dispatch_action(window, ...)` şeklindeki window argümanlı formu kullanır.

Pratik kurallar:

- Real tutarlılık için `smol::Timer` yerine `cx.background_executor.timer(d)` kullan.
- `run_until_parked` ile `advance_clock` kombine edilirken önce clock ilerlet,
  sonra park bekle. `VisualTestContext` `TestAppContext` içine deref ettiği için
  normal yolda `cx.background_executor.advance_clock(d)` kullanılır; direct
  `advance_clock(d)` helper'ı `VisualTestAppContext` üzerindedir.
- Async test için `#[gpui::test]` `async fn(cx: &mut TestAppContext)` formunu
  destekler; foreground task'ları orada `cx.spawn` ile kur.
- Pencerenin gerçekten render edilmesi için `VisualTestContext::draw(...)`,
  `TestApp::draw()` veya doğrudan `window.draw(cx).clear()` kullanılan bir
  pencere update'i gerekebilir; aksi halde debug bounds/layout bilgisi üretilmez.

Tuzaklar:

- `simulate_keystrokes` action dispatch'i tetikler ama keymap binding kaydedilmiş
  olmalıdır; testte `cx.bind_keys([...])` çağırmayı unutma.
- `run_until_parked` zaman ilerletmez; sadece pending future'ları sürer. Timer
  beklenirken `advance_clock` şart.
- `dispatch_action` focus tree'de action handler bulamazsa sessizce no-op'tur;
  view'in gerçekten focused olduğundan emin ol.


---

