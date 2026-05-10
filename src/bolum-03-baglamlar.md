# 3. Bağlamlar

---

## 3.1. Temel Bağlamlar

GPUI'de neredeyse her şey `cx` ile yapılır:

- `App`: global durum, pencere listesi, platform servisleri, keymap, global state,
  entity oluşturma ve pencere açma.
- `Context<T>`: bir `Entity<T>` güncellenirken gelir. `App` içine deref eder ve
  `cx.notify()`, `cx.emit(...)`, `cx.listener(...)`, `cx.observe(...)`,
  `cx.subscribe(...)`, `cx.spawn(...)` gibi entity odaklı API'leri ekler.
- `Window`: pencereye özel durum ve davranış. Focus, cursor, bounds, resize,
  title, background appearance, action dispatch, IME, prompt ve platform pencere
  işlemleri burada yapılır.
- `AsyncApp` / `AsyncWindowContext`: `await` noktaları boyunca tutulabilen async
  context. Entity/window kapanmış olabileceği için erişimler fallible olabilir.
- `TestAppContext` / `VisualTestContext`: testlerde simülasyon, zamanlayıcı ve
  görsel doğrulama için kullanılır.

Entity kullanımı:

```rust
let entity = cx.new(|cx| State::new(cx));

let value = entity.read(cx).value;

entity.update(cx, |state, cx| {
    state.value += 1;
    cx.notify();
});

let weak = entity.downgrade();
weak.update(cx, |state, cx| {
    state.value += 1;
    cx.notify();
})?;
```

Kurallar:

- Render çıktısını etkileyen state değiştiğinde `cx.notify()` çağır.
- Bir entity güncellenirken aynı entity'yi yeniden update etmeye çalışma; panic'e
  yol açabilir.
- Uzun yaşayan async işlerde `Entity<T>` yerine `WeakEntity<T>` yakala.
- `Task` düşerse iş iptal olur. Ya `await` et, ya struct alanında sakla, ya da
  `detach()` / `detach_and_log_err(cx)` kullan.

## 3.2. WindowHandle, AnyWindowHandle ve VisualContext

`open_window` veya test helper'ları typed `WindowHandle<V>` döndürür. Bu handle
pencerenin root view tipini bilir; `AnyWindowHandle` ise root tipini runtime'da
taşır ve gerektiğinde downcast edilir.

`WindowHandle<V>`:

```rust
handle.update(cx, |root: &mut Workspace, window, cx| {
    root.focus_active_pane(window, cx);
})?;

let title = handle.read_with(cx, |root, cx| root.title(cx))?;
let entity = handle.entity(cx)?;
let active = handle.is_active(cx);
let id = handle.window_id();
```

`AnyWindowHandle`:

```rust
if let Some(workspace) = any_handle.downcast::<Workspace>() {
    workspace.update(cx, |workspace, window, cx| {
        workspace.activate(window, cx);
    })?;
}

any_handle.update(cx, |root_view, window, cx| {
    let root_entity_id = root_view.entity_id();
    window.refresh();
    (root_entity_id, window.is_window_active())
})?;
```

Context trait'leri:

- `AppContext`: `new`, `reserve_entity`, `insert_entity`, `update_entity`,
  `read_entity`, `update_window`, `with_window`, `read_window`,
  `background_spawn`, `read_global`.
- `VisualContext`: pencere bağlı context'lerde `window_handle`,
  `update_window_entity`, `new_window_entity`, `replace_root_view`, `focus`
  sağlar.
- `BorrowAppContext`: `App`, `Context<T>`, async/test context gibi farklı
  context'lerle çalışan yardımcı fonksiyonlar için ortak global API yüzeyidir.

`window.replace_root(cx, |window, cx| NewRoot::new(window, cx))` mevcut pencerenin
root entity'sini yeni bir `Render` view ile değiştirir. Async/test context'lerde
aynı işlem `replace_root_view` helper'ı üzerinden yapılır. Bu, yeni pencere
açmadan root flow değiştirmek için kullanılır; eski root'a ait subscription ve
task ownership'i ayrıca düşünülmelidir.

`with_window(entity_id, ...)` entity'nin en son render edildiği pencereyi bulur.
Entity aynı anda birden fazla pencerede render ediliyorsa bu API bilinçli bir
"current window" kısayoludur; kesin pencere gerekiyorsa `WindowHandle` sakla.


---

