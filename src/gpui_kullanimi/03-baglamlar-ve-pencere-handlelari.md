# Bölüm III — Bağlamlar ve Pencere Handle'ları

---

## Temel Bağlamlar


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

## WindowHandle, AnyWindowHandle ve VisualContext


`open_window` veya test helper'ları typed `WindowHandle<V>` döndürür. Bu handle
pencerenin root view tipini bilir; `AnyWindowHandle` ise root tipini runtime'da
taşır ve gerektiğinde downcast edilir.

`WindowHandle<V>` `#[derive(Deref, DerefMut)]` ile içindeki
`AnyWindowHandle`'a deref eder. Bu yüzden bazı metotlar typed handle üzerinde
çağrılabilir görünür ama owner'ı aslında `AnyWindowHandle`'dır. API yüzeyini
okurken `Owner::method -> dönüş tipi -> hata semantiği` üçlüsünü birlikte
değerlendir.

Aynı kalıp GPUI'de başka handle ve event ailelerinde de görülür:

- `Entity<T>: Deref<Target = AnyEntity>` ve `WeakEntity<T>:
  Deref<Target = AnyWeakEntity>` — typed entity handle'ları untyped handle'a
  deref eder. Detay "Entity Type Erasure, Callback Adaptörleri ve View Cache" başlığındadır.
- `ModifiersChangedEvent`, `ScrollWheelEvent`, `PinchEvent`, `MouseExitEvent`:
  `Deref<Target = Modifiers>` — bu dört event Modifiers metodlarını doğrudan
  açar (`event.secondary()`, `event.modified()`). `MouseDownEvent`,
  `MouseUpEvent`, `MouseMoveEvent` ise Deref *etmez*; yalnızca `modifiers`
  alanını ifşa eder. Detay "CursorStyle, FontWeight ve Sabit Enum Tabloları" başlığındadır.
- `Context<'a, T>: Deref<Target = App>` — `cx.theme()`, `cx.refresh_windows()`
  gibi App metotları Context üzerinden de çağrılabilir (bkz. "Temel Bağlamlar").

Bu Deref aliasing pattern'inde metot adını tek başına yeterli sayma; aynı ad
typed ve untyped owner'larda farklı dönüş tipiyle bulunabilir.

`WindowHandle<V>`:

```rust
handle.update(cx, |root: &mut Workspace, window, cx| {
    root.focus_active_pane(window, cx);
})?;

let root_ref: &Workspace = handle.read(cx)?;
let title = handle.read_with(cx, |root, cx| root.title(cx))?;
let entity = handle.entity(cx)?;
// WindowHandle::is_active `Option<bool>` döner; pencere kapanmış/geçici
// olarak ödünç alınmışsa `None`. Tipik kullanım:
let active: Option<bool> = handle.is_active(cx);

// `window_id()` owner olarak `AnyWindowHandle` metodudur; fakat
// `WindowHandle<V>: Deref<Target = AnyWindowHandle>` olduğu için bu çağrı
// method resolution ile çalışır:
let id = handle.window_id();

// Untyped handle saklamak veya AnyWindowHandle API'sini açık göstermek
// istiyorsan dönüşümü bilinçli yap:
let any: AnyWindowHandle = handle.into();
let same_id = any.window_id();
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

let title = any_handle.read::<Workspace, _, _>(cx, |workspace, cx| {
    workspace.read(cx).title(cx)
})?;
```

Tam owner/metot yüzeyi:

| Owner | Metot | Dönüş | Not |
|---|---|---|---|
| `WindowHandle<V>` | `new(id)` | `Self` | Root tipini runtime'da doğrulamaz; id + `TypeId::of::<V>()` saklar. |
| `WindowHandle<V>` | `root(cx)` | `Result<Entity<V>>` | Sadece `test` veya `test-support`; root type mismatch/kapalı pencere hata. |
| `WindowHandle<V>` | `update(cx, |&mut V, &mut Window, &mut Context<V>| ...)` | `Result<R>` | Typed root view mutate eder. |
| `WindowHandle<V>` | `read(&App)` | `Result<&V>` | Kısa süreli immutable borrow; kapalı/borrowed pencere hata. |
| `WindowHandle<V>` | `read_with(cx, |&V, &App| ...)` | `Result<R>` | Callback içinde güvenli okuma. |
| `WindowHandle<V>` | `entity(cx)` | `Result<Entity<V>>` | Root entity handle'ını döndürür. |
| `WindowHandle<V>` | `is_active(&mut App)` | `Option<bool>` | Kapalı veya borrowed pencere `None`. |
| `WindowHandle<V>` deref | `window_id()` | `WindowId` | Owner `AnyWindowHandle`; deref sayesinde `handle.window_id()` çalışır. |
| `WindowHandle<V>` deref | `downcast<T>()` | `Option<WindowHandle<T>>` | Owner `AnyWindowHandle`; typed handle'da çoğu zaman gereksizdir. |
| `AnyWindowHandle` | `window_id()` | `WindowId` | Pencere kimliği. |
| `AnyWindowHandle` | `downcast<T>()` | `Option<WindowHandle<T>>` | `TypeId` eşleşmezse `None`. |
| `AnyWindowHandle` | `update(cx, |AnyView, &mut Window, &mut App| ...)` | `Result<R>` | Root type bilinmez; callback `AnyView` alır. |
| `AnyWindowHandle` | `read::<T, _, _>(cx, |Entity<T>, &App| ...)` | `Result<R>` | Önce downcast yapar, sonra typed entity okutur. |

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

---

