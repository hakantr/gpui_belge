# 15. Test

---

## 15.1. Test Rehberi

GPUI testleri sıradan Rust testlerinden farklıdır: zaman, executor, pencere ve girdi simülasyonu deterministik bir kontrol altındadır. Bu bölüm tipik bir GPUI testinin uyduğu kuralları kısa bir kontrol listesi olarak sunar; ayrıntılı API'ler [Test Bağlamları ve Simülasyon](#152-test-bağlamları-ve-simülasyon) bölümünde listelenir.

### Yapılması gerekenler

- **`#[gpui::test]` makrosu ve `TestAppContext` kullanılır.** Normal `#[test]` GPUI runtime'ı kuramaz.
- **Pencere gerekiyorsa** test bağlamının offscreen pencere yardımcıları (`add_window`, `add_window_view`) tercih edilir.
- **Async timer için** `cx.background_executor().timer(duration).await` kullanılır; `smol::Timer::after` ile çelişir.
- **UI action testlerinde** key binding ve action dispatch doğrudan test edilir; binding kaydı `cx.bind_keys([...])` ile testte de yapılır.
- **Görsel test gerekiyorsa** `VisualTestContext` kullanılır; headless renderer desteği platforma göre değişir.
- **UI öğesi debug bounds** gerekiyorsa test-support feature altında `.debug_selector(...)` ile etiketlenir.

### Kaçınılması gerekenler

- **`smol::Timer::after(...)` ile `run_until_parked()` beklemek.** GPUI scheduler bu timer'ı görmez; test sonsuza dek parked kalabilir.
- **`unwrap()` ile test dışı üretim yoluna panik taşımak.** Test başarısızlığı net mesajla raporlanmalıdır; `expect("...")` veya `assert!` tercih edilir.
- **Async hata sonuçlarını `let _ = ...` ile yutmak.** Test sessizce başarılı görünebilir; sonuç açıkça assert edilir.

## 15.2. Test Bağlamları ve Simülasyon

Kaynak: `crates/gpui/src/app/test_context.rs`, `crates/gpui/src/app/visual_test_context.rs`.

GPUI testleri için üç farklı bağlam vardır ve hangisinin seçildiği "pencere açılıyor mu?" ve "pencere argümanı her seferinde verilmek mi isteniyor?" sorularına göre değişir:

- **`TestAppContext`** — `#[gpui::test]` makrosu tarafından sağlanan ana bağlam. Pencere argümanı her API'ye **açıkça** verilir.
- **`VisualTestContext`** — `add_window_view` / `add_empty_window` ile alınır; test penceresini **kendi içinde** tutar, bu sayede klavye/fare/dispatch çağrılarında pencere argümanı geçirilmez.
- **`VisualTestAppContext`** — Yalnızca macOS `test-support` altında. Yine pencere tutamacını (`handle`) argüman olarak alan ayrı bir bağlam (isim benzerliğine dikkat).

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
- **`cx.simulate_input(window, "hello")`** — Metin girdisi simülasyonu.
- **`cx.dispatch_action(window, action)`** — Action dispatch'i.
- **`cx.run_until_parked()`** — Tüm bekleyen future/task'ler tamamlanıncaya kadar executor'ı sürer.
- **`cx.background_executor.advance_clock(duration)`** — Sahte saati ilerletir (deterministik timer için).
- **`cx.background_executor.run_until_parked()`** — Test executor'ında yalnız background tarafını sürer.
- **`window.update(cx, |view, window, cx| ...)`** — Pencere içi durumu değiştirir.

### `VisualTestContext` farkı

`VisualTestContext` pencere bağlamını kendi içinde tuttuğu için **bazı method'ları pencere argümansız** çağrılır:

- `cx.simulate_keystrokes("cmd-p")` ve `cx.simulate_input("hello")` — `self.window` kullanır.
- `cx.dispatch_action(action)` — yine `self.window` üzerinden.
- `cx.run_until_parked()`, `cx.window_title()`, `cx.document_path()` — Pencere argümansız yardımcılardır.

Fare simülasyonları `VisualTestContext` üzerinde `self.window` ile çalışır (`test_context.rs:764-809`):

- `cx.simulate_mouse_move(position, button, modifiers)`
- `cx.simulate_mouse_down(position, button, modifiers)`
- `cx.simulate_mouse_up(position, button, modifiers)`
- `cx.simulate_click(position, modifiers)`

Pencere argümanını isteyen formlar `TestAppContext` üzerindeki `simulate_keystrokes(window, ...)`, `simulate_input(window, ...)`, `dispatch_action(window, ...)`, `dispatch_keystroke(window, ...)` ailesidir. `VisualTestAppContext` (macOS) tüm yardımcılarda pencere argümanlı formu kullanır.

### Pratik kurallar

- **Deterministik zaman tutarlılığı için `smol::Timer` yerine `cx.background_executor.timer(d)` kullanılır;** scheduler her ikisini de görmez ama yalnızca executor timer'ı `run_until_parked` ile uyumludur.
- **`run_until_parked` + `advance_clock` kombinasyonunda önce saat ilerletilir, sonra park beklenir.** `VisualTestContext` `TestAppContext` içine deref olduğu için aynı yolda `cx.background_executor.advance_clock(d)` kullanılır; doğrudan `advance_clock(d)` yardımcısı yalnız `VisualTestAppContext` üzerindedir.
- **Async test için** `#[gpui::test]` `async fn(cx: &mut TestAppContext)` formunu destekler; foreground task'ları içeride `cx.spawn` ile kurulur.
- **Pencerenin gerçekten render edilmesi için** `VisualTestContext::draw(...)`, `TestApp::draw()` veya pencerede bir update tetiklenmesi gerekebilir; aksi halde debug bounds/layout bilgisi üretilmez.

### Tuzaklar

- **`simulate_keystrokes` action dispatch'i tetikler ama keymap binding kaydedilmiş olmalıdır;** testte `cx.bind_keys([...])` çağrılması unutulursa kısayol sessizce çalışmaz.
- **`run_until_parked` zaman ilerletmez;** sadece pending future'ları sürer. Timer'la birlikte kullanıldığında `advance_clock` da çağrılmalıdır.
- **`dispatch_action` odak ağacında action işleyicisi bulamazsa sessizce no-op'tur.** Action'ın çalışması için ilgili görünümün gerçekten odakta olduğundan emin olunur (`cx.focus_view(...)` veya benzeri).


---
