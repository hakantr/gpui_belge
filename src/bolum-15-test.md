# 15. Test

---

## 15.1. Test Rehberi

GPUI testleri sıradan Rust testlerinden farklıdır: zaman, executor, pencere, input simülasyonu hepsi deterministik bir kontrol altındadır. Bu bölüm tipik bir GPUI testinin uyduğu kuralları kısa bir kontrol listesi olarak sunar; ayrıntılı API'ler için 15.2'ye bakılır.

### Yapılması gerekenler

- **`#[gpui::test]` makrosu ve `TestAppContext` kullanılır.** Normal `#[test]` GPUI runtime'ı kuramaz.
- **Pencere gerekiyorsa** test context'in offscreen/window helper'ları (`add_window`, `add_window_view`) tercih edilir.
- **Async timer için** `cx.background_executor().timer(duration).await` kullanılır; `smol::Timer::after` ile çelişir.
- **UI action testlerinde** key binding ve action dispatch doğrudan test edilir; binding kaydı `cx.bind_keys([...])` ile testte de yapılır.
- **Görsel test gerekiyorsa** `VisualTestContext` kullanılır; headless renderer desteği platforma göre değişir.
- **Element debug bounds** gerekiyorsa test-support feature altında `.debug_selector(...)` ile etiketlenir.

### Kaçınılması gerekenler

- **`smol::Timer::after(...)` ile `run_until_parked()` beklemek.** GPUI scheduler bu timer'ı görmez; test sonsuza dek parked kalabilir.
- **`unwrap()` ile test dışı production yoluna panik taşımak.** Test başarısızlığı net mesajla raporlanmalıdır; `expect("...")` veya `assert!` tercih edilir.
- **Async hata sonuçlarını `let _ = ...` ile yutmak.** Test sessizce başarılı görünebilir; sonuç açıkça assert edilir.

## 15.2. Test Bağlamları ve Simülasyon

Kaynak: `crates/gpui/src/app/test_context.rs`, `crates/gpui/src/app/visual_test_context.rs`.

GPUI testleri için üç farklı bağlam vardır ve hangisinin seçildiği "pencere açılıyor mu?" ve "pencere argümanı her seferinde verilmek mi isteniyor?" sorularına göre değişir:

- **`TestAppContext`** — `#[gpui::test]` makrosu tarafından sağlanan ana bağlam. Pencere argümanı her API'ye **açıkça** verilir.
- **`VisualTestContext`** — `add_window_view` / `add_empty_window` ile alınır; test penceresini **kendi içinde** tutar, bu sayede klavye/mouse/dispatch çağrılarında window argümanı geçirilmez.
- **`VisualTestAppContext`** — Yalnızca macOS `test-support` altında. Yine pencere handle'ını argüman olarak alan ayrı bir bağlam (isim benzerliğine dikkat).

### Tipik test örneği

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

### Sık kullanılan API'ler (`TestAppContext`)

- **`cx.add_window(|window, cx| cx.new(...))`** — Yeni offscreen pencere açar.
- **`cx.simulate_keystrokes(window, "cmd-s left")`** — Boşlukla ayrılmış keystroke dizisini simüle eder.
- **`cx.simulate_input(window, "hello")`** — Text input simülasyonu.
- **`cx.dispatch_action(window, action)`** — Action dispatch.
- **`cx.run_until_parked()`** — Tüm pending future/task tamamlanıncaya kadar executor'ı sürer.
- **`cx.background_executor.advance_clock(duration)`** — Fake clock'u ilerletir (deterministic timer için).
- **`cx.background_executor.run_until_parked()`** — Test executor'ında yalnız background side'ı sürer.
- **`window.update(cx, |view, window, cx| ...)`** — Pencere içi state mutate eder.

### `VisualTestContext` farkı

`VisualTestContext` pencere bağlamını kendi içinde tuttuğu için **bazı method'ları window argümansız** çağrılır:

- `cx.simulate_keystrokes("cmd-p")` ve `cx.simulate_input("hello")` — `self.window` kullanır.
- `cx.dispatch_action(action)` — yine `self.window` üzerinden.
- `cx.run_until_parked()`, `cx.window_title()`, `cx.document_path()` — Window-less helper'lardır.

Mouse simülasyonları `VisualTestContext` üzerinde `self.window` ile çalışır (`test_context.rs:764-809`):

- `cx.simulate_mouse_move(position, button, modifiers)`
- `cx.simulate_mouse_down(position, button, modifiers)`
- `cx.simulate_mouse_up(position, button, modifiers)`
- `cx.simulate_click(position, modifiers)`

Pencere argümanını isteyen formlar `TestAppContext` üzerindeki `simulate_keystrokes(window, ...)`, `simulate_input(window, ...)`, `dispatch_action(window, ...)`, `dispatch_keystroke(window, ...)` ailesidir. `VisualTestAppContext` (macOS) tüm helper'larda pencere argümanlı formu kullanır.

### Pratik kurallar

- **Real tutarlılık için `smol::Timer` yerine `cx.background_executor.timer(d)` kullanılır;** scheduler her ikisini de görmez ama yalnızca executor timer'ı `run_until_parked` ile uyumludur.
- **`run_until_parked` + `advance_clock` kombinasyonunda önce clock ilerletilir, sonra park beklenir.** `VisualTestContext` `TestAppContext` içine deref olduğu için aynı path'te `cx.background_executor.advance_clock(d)` kullanılır; doğrudan `advance_clock(d)` helper'ı yalnız `VisualTestAppContext` üzerindedir.
- **Async test için** `#[gpui::test]` `async fn(cx: &mut TestAppContext)` formunu destekler; foreground task'ları içeride `cx.spawn` ile kurulur.
- **Pencerenin gerçekten render edilmesi için** `VisualTestContext::draw(...)`, `TestApp::draw()` veya pencerede bir update tetiklenmesi gerekebilir; aksi halde debug bounds/layout bilgisi üretilmez.

### Tuzaklar

- **`simulate_keystrokes` action dispatch'i tetikler ama keymap binding kaydedilmiş olmalıdır;** testte `cx.bind_keys([...])` çağrılması unutulursa kısayol sessizce çalışmaz.
- **`run_until_parked` zaman ilerletmez;** sadece pending future'ları sürer. Timer'la birlikte kullanıldığında `advance_clock` da çağrılmalıdır.
- **`dispatch_action` focus tree'de action handler bulamazsa sessizce no-op'tur.** Action'ın çalışması için ilgili view'ın gerçekten focused olduğundan emin olunur (`cx.focus_view(...)` veya benzeri).


---

