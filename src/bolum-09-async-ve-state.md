# 9. Async ve Durum (State)

---

## 9.1. Async İşler

GPUI'de async iş başlatmanın birkaç farklı yolu vardır; hangisinin seçildiği, işin **hangi bağlama (`context`) bağlı olacağına** ve **nerede çalışacağına** göre değişir. Foreground iş ana UI thread'inde planlanır; UI durumuna güvenli dönüş için kullanılır. Background iş ise scheduler/thread pool üzerinde çalışır ve UI'ı bloklamamalı, CPU yoğun veya I/O yoğun işler için ayrılır. Varlığa (`entity`) ve pencereye bağlı varyantlar, iş sırasında ilgili kaynak hâlâ yaşıyor mu kontrolünü `Result` üzerinden sağlar.

### Foreground task (App seviyesi)

App bağlamında async iş başlatmak — iş tamamlanınca tekrar UI thread'inde devam edilir.

```rust
cx.spawn(async move |cx| {
    cx.update(|cx| {
        // App durumunu güncelle
    })
})
.detach();
```

### Varlık task'ı (görünüm durumu ile)

Çalışan görünüme `WeakEntity<T>` üzerinden bağlı task. Görünüm bu arada düşmüşse `this.update(...)` çağrısı `Err` döner ve `?` ile erken çıkış sağlar:

```rust
cx.spawn(async move |this, cx| {
    cx.background_executor().timer(Duration::from_millis(200)).await;
    this.update(cx, |this, cx| {
        this.ready = true;
        cx.notify();
    })?;
    Ok::<(), anyhow::Error>(())
})
.detach_and_log_err(cx);
```

### Pencereye bağlı task

Varlık hem bir görünüm hem bir pencereye bağlıysa `spawn_in` kullanılır; closure'a `WeakEntity<T>` ve `AsyncWindowContext` birlikte gelir:

```rust
cx.spawn_in(window, async move |this, cx| {
    this.update_in(cx, |this, window, cx| {
        window.activate_window();
        cx.notify();
    })?;
    Ok::<(), anyhow::Error>(())
})
.detach_and_log_err(cx);
```

`Context::spawn` ve `spawn_in` imzaları `AsyncFnOnce(WeakEntity<T>, &mut AsyncApp/AsyncWindowContext)` formundadır; closure her zaman `async move |this, cx| { ... }` biçiminde yazılır. Closure `Result` döndürüyorsa örnekteki gibi `Ok::<(), anyhow::Error>(())` ile tip annotate edilir veya en üstte `let _: Result<_, anyhow::Error> = ...` ile bağlama kazandırılır.

`window.to_async(cx)` doğrudan bir `AsyncWindowContext` üretir; callback dışına taşınacak pencereye bağlı async helper yazılırken kullanılır. Sıradan varlık/görünüm kodlarında `cx.spawn_in(window, ...)` daha güvenli ve okunur wrapper'dır.

### Background thread

CPU yoğun veya bloklayıcı işler için. Sonuç UI'a dönerken `cx.spawn(...)` ile foreground'a tekrar geçilir:

```rust
let task = cx.background_spawn(async move {
    expensive_work().await
});

cx.spawn(async move |cx| {
    let result = task.await;
    cx.update(|cx| {
        // sonucu UI'a taşı
    })
})
.detach();
```

### Testlerde zamanlayıcı

- GPUI testlerinde `smol::Timer::after(...)` yerine `cx.background_executor().timer(duration).await` kullanılır.
- `run_until_parked()` ile uyum için GPUI executor timer'ı tercih edilir; başka kaynaktan gelen timer'lar bu mekanizma tarafından beklenmez.

## 9.2. Executor, Priority, Timeout ve Test Zamanı

GPUI'da foreground iş UI thread'inde, background iş ise scheduler/thread pool üzerinde çalışır. Bu ayrım yalnızca performans değil, **bir bağlamın (`context`) `await` noktası boyunca taşınıp taşınamayacağını** da belirler: UI durumu sadece foreground'dan güvenle tutulur. Aşağıda executor tipleri, priority kullanımı, timeout deseni ve test zamanı kontrolleri açıklanır.

### Temel tipler

- **`BackgroundExecutor`** — Background iş için: `spawn`, `spawn_with_priority`, `timer`, `scoped`, `scoped_priority`; testlerde `advance_clock`, `run_until_parked`, `simulate_random_delay`.
- **`ForegroundExecutor`** — Main thread'e future koyar: `spawn`, `spawn_with_priority`; senkron köprü için `block_on` ve `block_with_timeout`.
- **`Priority`** — `RealtimeAudio`, `High`, `Medium`, `Low`. `RealtimeAudio` ayrı bir thread ister; UI dışı audio gibi çok sınırlı işler dışında kullanılmaz.
- **`Task<T>`** — Await edilebilir tutamaç (`handle`). Drop edilirse iş iptal olur; tamamlanması istenirse await edilir, struct alanında saklanır veya `detach()` / `detach_and_log_err(cx)` ile bağımsız bırakılır.
- **`FutureExt::with_timeout(duration, executor)`** — Future'ı executor timer'ıyla yarışır; `Result<T, Timeout>` döndürür.

### Timeout deseni

Bir background işin belirli süreyi geçmesi durumunda iptal edilebilmesi için tipik desen:

```rust
let executor = cx.background_executor().clone();
let task = cx.background_spawn(async move {
    parse_large_file(path).await
});

let result = task
    .with_timeout(Duration::from_secs(5), &executor)
    .await?;
```

### Priority spawn

Foreground kuyruğunda öncelik artırmak için:

```rust
cx.spawn_with_priority(Priority::High, async move |cx| {
    cx.update(|cx| {
        cx.refresh_windows();
    });
})
.detach();
```

`AsyncApp::update(|cx| { ... })` doğrudan `R` döndürür; varlık update'lerinden farklı olarak fallible değildir, bu yüzden `?` ile yayılmaz. Pencereye bağlı async çalışmada `AsyncWindowContext::update(|window, cx| { ... }) -> Result<R>` veya `Entity::update(cx, ...)` fallible varyantları kullanılır.

### Async bağlam yardımcı yüzeyi

- **`AsyncApp::refresh()`** — Tüm pencereler için redraw planlar. Async path'inden `update(|cx| cx.refresh_windows())` yazmadan redraw tetiklemek için.
- **`AsyncApp::background_executor()` ve `foreground_executor()`** — Executor tutamaçlarını verir. Timer/timeout veya nested spawn gerekiyorsa buradan alınır.
- **`AsyncApp::subscribe(&entity, ...)`, `open_window(options, ...)`, `spawn(...)`, `has_global::<G>()`, `read_global`, `try_read_global`, `read_default_global`, `update_global`, `on_drop(&weak, ...)`** — Await edilebilir app task'larında aynı foreground duruma güvenli dönüş noktaları.
- **`AsyncWindowContext::window_handle()`** — Bağlı pencereyi verir.
- **`AsyncWindowContext::update(|window, cx| ...)`** — Sadece pencere durumu için; `update_root(|root, window, cx| ...)` kök `AnyView` de gerekiyorsa kullanılır.
- **`AsyncWindowContext::on_next_frame(...)`, `read_global`, `update_global`, `spawn(...)`, `prompt(...)`** — Pencereye bağlı async işlerde "pencere kapanmış olabilir" durumunu `Result` ya da yedek receiver ile yönetir.

### Entity ve window bağlı priority spawn

- **`cx.spawn_in_with_priority(priority, window, async move |weak, cx| { ... })`** — Mevcut varlığın `WeakEntity<T>` tutamacını ve `AsyncWindowContext`'i birlikte verir.
- **`window.spawn_with_priority(priority, cx, async move |cx| { ... })`** — Pencere tutamacına bağlı ama varlıksız async iş için.
- **Önemli:** Priority yalnızca **foreground executor** kuyruğunda polling önceliği verir; uzun CPU işi yine `background_spawn` tarafına taşınır.

### Hazır değer

Cache hit/miss akışı için "synchronously hazır" task üretmek:

```rust
fn cached_or_async(cached: Option<Data>, cx: &App) -> Task<anyhow::Result<Data>> {
    if let Some(data) = cached {
        Task::ready(Ok(data))
    } else {
        cx.background_spawn(async move { load_data().await })
    }
}
```

### Test zamanı kontrolleri

- **`cx.background_executor().timer(duration).await`** — GPUI scheduler'a bağlıdır; `smol::Timer::after` GPUI'nin `run_until_parked()` mekanizmasıyla uyumsuz kalabilir.
- **`advance_clock(duration)`** — Sadece fake clock'u ilerletir; runnable işleri yürütmek için ayrıca `run_until_parked()` gereklidir.
- **`allow_parking()`** — Outstanding task varken parked olunmasını testte bilerek kabul etmek için. Production path'inde kullanılmaz.
- **`block_with_timeout`** — Timeout sırasında future'ı geri verir; çağıran "iptal mi etsem, sonra mı poll etsem?" kararını verebilir.
- **`PriorityQueueSender<T>` / `PriorityQueueReceiver<T>`** — Yalnızca Windows/Linux/wasm cfg'lerinde re-export edilir. `send(priority, item)`, `try_pop()`, `pop()`, `try_iter()`, `iter()` ile high/medium/low kuyrukları ağırlıklı seçimle tüketir; `Priority::RealtimeAudio` bu kuyruğa girmez.

## 9.3. Task, TaskExt ve Async Hata Yönetimi

`Task<T>` GPUI'ın temel async tutamacıdır; herhangi bir spawn yaratıcı işlemden geri döner. Yardımcı trait `TaskExt` (`crates/gpui/src/executor.rs:33+`), `Task<Result<T, E>>` üzerine hata yönetimini standardize eden iki ek method ekler:

```rust
pub trait TaskExt<T, E> {
    fn detach_and_log_err(self, cx: &App);
    fn detach_and_log_err_with_backtrace(self, cx: &App);
}
```

- **`detach_and_log_err`** — Task'ı arka plana atar; hata oluşursa `log::error!("...: {err}")` formatında loglar.
- **`detach_and_log_err_with_backtrace`** — Aynı işlevi `{:?}` formatıyla yapar; `anyhow::Error` durumlarında full backtrace gösterir.

### Pratik akış

```rust
cx.spawn_in(window, async move |this, cx| {
    let data = http_client.get(url).await?;
    this.update_in(cx, |this, window, cx| {
        this.apply(data, window, cx);
    })?;
    Ok::<(), anyhow::Error>(())
})
.detach_and_log_err(cx);
```

### Detach varyantları ve hangisinin ne zaman seçildiği

- **`task.detach()`** — Hata loglanmaz, sessizce yutulur. UI'da gösterilemeyen, kullanıcıya doğrudan etkisi olmayan fire-and-forget işler için.
- **`task.detach_and_log_err(cx)`** — Standart akış, production kodunda varsayılan tercih.
- **`task.detach_and_prompt_err(prompt_label, window, cx, |err, window, cx| ...)`** — Workspace UI'sında tanımlı ek helper (workspace crate'inde); hatayı modal prompt ile kullanıcıya gösterir. Kayıt başarısız olunca onay isteyen senaryolar için uygundur.

### Yazım kararları

- **Async sonuç caller'a dönmesi gerekiyorsa** `Task<R>` döndürülür ve await edilir; struct alanında saklamak iptal davranışı sağlar.
- **Caller fire-and-forget yapacaksa** task'ı return etmek gereksizdir; doğrudan `detach_and_log_err(cx)` çağrılır.
- **Result'ı log'a düşürmemek için** manuel `if let Err(e) = task.await { ... }` yazılmaz; `detach_and_log_err` zaten `track_caller` ile log location'ı korur.

### Tuzaklar

- **Result tipinin `E` argümanı `Display + Debug` istemeli;** `anyhow::Error` ve sıradan custom error tipi otomatik uyar.
- **Task'ı `Vec<Task<()>>` içinde toplamak** drop sırasında sürpriz iptaller üretebilir; iptal istenmeyen tipik akışta `detach()` daha açık niyet bildirir.
- **`cx.spawn_in(window, ...)` window düştüğünde task'ı otomatik iptal etmez.** Ancak `WeakEntity` üzerinden `update` veya `update_in` çağrısı `Result` döner; bu `Err` döndüğünde async fonksiyon `?` ile erken sonlanır ve task pratikte iptal etkisi gösterir.

## 9.4. Global Durum, Observe ve Event

Bir uygulamada bazı veriler tek bir varlığa (`entity`) ait değildir; tema, ayarlar, kullanıcı oturumu gibi paylaşılan durumlar uygulamada tek kopya tutulur. GPUI bunu **`Global`** trait'i ile modeller. Varlıklar arasında iletişim ise iki kanal üzerinden yapılır: **observe** (bir varlığın `cx.notify()` çağrısını dinle) ve **event** (bir varlığın tanımlı tipte event yayınlaması). Bu üç mekanizma birbirini tamamlar.

### Global durum

```rust
struct MyGlobal(State);
impl Global for MyGlobal {}

cx.set_global(MyGlobal(state));

cx.update_global::<MyGlobal, _>(|global, cx| {
    global.0.changed = true;
});

let value = cx.read_global::<MyGlobal, _>(|global, _| global.0.clone());
```

### Observe — başka varlığın notify çağrısını dinleme

`cx.observe(...)`, bir başka varlık `cx.notify()` çağırdığında tetiklenir. Hangi alanın değiştiği belli olmasa da "bir şey değişti, baktığım durumu yeniden hesaplayayım" senaryosu için uygundur.

```rust
subscriptions.push(cx.observe(&other, |this, other, cx| {
    this.copy = other.read(cx).value;
    cx.notify();
}));
```

### Event — tipli mesaj yayınlama

Bir varlık belirli olayları (`Saved`, `Closed`, `Inserted` gibi) tipli olarak yayınlayabilir. Yayıncı `EventEmitter<E>` implemente eder; dinleyici `cx.subscribe` ile abone olur.

```rust
struct Saved;
impl EventEmitter<Saved> for Document {}

cx.emit(Saved);

subscriptions.push(cx.subscribe(&document, |this, document, _: &Saved, cx| {
    this.last_saved = Some(document.entity_id());
    cx.notify();
}));
```

`observe` vs `subscribe` farkı: `observe` tipsiz "bir şey değişti" sinyalidir; `subscribe` tipli, anlamlı bir event payload taşır. Anlamlı semantik gerekiyorsa event tercih edilir.

### Window observe helper'ları

Pencere durumundaki değişiklikleri izlemek için hazır observer'lar:

- `cx.observe_window_bounds(window, ...)` — Pencere yeniden boyutlandırıldı/taşındı.
- `cx.observe_window_activation(window, ...)` — Pencere foreground/background.
- `cx.observe_window_appearance(window, ...)` — Light/dark görünüm değişti; tema tarafı [WindowAppearance ve Tema Modu](./bolum-05-stil-geometri-ve-renkler.md#55-windowappearance-ve-tema-modu) bölümünde anlatılır.
- `cx.observe_button_layout_changed(window, ...)` — Linux pencere kontrol butonu düzeni değişti; pencere tarafı [Kontrol Butonları Nasıl Yönetilir](./bolum-06-pencere-yonetimi.md#67-kontrol-butonları-nasıl-yönetilir) bölümünde ele alınır.
- `cx.observe_pending_input(window, ...)` — IME pending input durumu değişti.
- `cx.observe_keystrokes(...)` — Pencerede dispatch edilen keystroke; kullanım ayrımı [Action ve Keymap Runtime Introspection](./bolum-08-action-ve-keymap.md#85-action-ve-keymap-runtime-introspection) bölümünde açıklanır.

## 9.5. Global Durum Yardımcıları ve `cx.defer`

Global durum üzerinde işlem yapan tüm method'lar tek bir referans listesi olarak `App` üzerinde toplanır. Bu listeyle birlikte effect cycle'ı yöneten `defer` ailesi de pratikte aynı bağlamda kullanılır; reentrant update yasağını aşmak için `defer` özellikle global update senaryolarında devreye girer.

### Global durum method'ları

- **`cx.set_global<T: Global>(value)`** — Mevcut instance varsa ezer; yoksa kurar.
- **`cx.global<T>() -> &T`** — Yoksa panic eder. Yalnızca varlığından kesin emin olunan call site'ta kullanılır.
- **`cx.global_mut<T>()`** — Aynı, mutable referans verir; aynı panic davranışı.
- **`cx.default_global<T: Default>() -> &mut T`** — Yoksa default instance oluşturur, varsa mevcut olanı mutable döndürür. Lazy init pattern'i için.
- **`cx.has_global<T>() -> bool`** — Okumadan önce kontrol etmek için.
- **`cx.try_global<T>() -> Option<&T>`** — Nullable okuma.
- **`cx.update_global<T, R>(|g, cx| ...) -> R`** — Kapsamlı update.
- **`cx.read_global<T, R>(|g, cx| ...) -> R`** — Kapsamlı okuma.
- **`cx.remove_global<T>() -> T`** — Instance'ı geri alır; tekrar set edilmezse global yok sayılır.
- **`cx.observe_global<T>(|cx| ...) -> Subscription`** — Global notify olduğunda çalışan observer.

### Effect cycle yönetimi (`defer` ailesi)

Bir update çalışırken iç içe başka bir update başlatmak çoğu zaman panic'e yol açar (örn. aynı varlık üzerinde reentrant update, aynı global üzerinde iç içe update). Bu durumda iş **defer** ile mevcut effect cycle'ın sonuna ertelenir; cycle bittiğinde GPUI sırada bekleyen defer callback'lerini sırayla çalıştırır.

- **`cx.defer(|cx| { ... })`** — Mevcut effect cycle bittiğinde çalışır.
- **`Context<T>::defer_in(window, |this, window, cx| ...)`** — Pencereye bağlı varyant; görünüm durumu ve pencere beraber gelir.
- **`window.defer(cx, |window, cx| ...)`** — Pencere bağlamından ertele.
- **`window.refresh()`** — Pencereyi sonraki frame'de redraw için işaretler.
- **`cx.refresh_windows()`** — Tüm pencereler için aynı.

### Tuzaklar

- **`cx.global<T>()` ve `cx.global_mut<T>()` yoksa panic eder.** Init'in garanti olmadığı call site'larda `try_global` veya `has_global` ile kontrol yapılır.
- **`update_global` sırasında aynı global'i tekrar update etmek panic verir.** İç içe update gerekiyorsa iç çağrı `cx.defer(...)` ile ertelenir.
- **Subscription `detach()` edilmezse owner drop'unda iptal olur.** Uzun ömürlü observer için abonelik, sahibi olan struct'ın bir alanında saklanır. Yaşam döngüsü ayrımı [Subscription Yaşam Döngüsü](#96-subscription-yaşam-döngüsü) bölümünde özetlenir.

## 9.6. Subscription Yaşam Döngüsü

Kaynak: `crates/gpui/src/subscription.rs`.

`Subscription`, observe/subscribe/event/focus benzeri kayıtların ortak tutamaç (`handle`) tipidir. Opaque'tır ve **düşürüldüğü an** ilgili callback kaydını siler. Bu basit kural pratik üç desen ortaya çıkarır:

```rust
// 1. Field'da sakla — abonelik görünüm ömrü kadar yaşar
struct View { _subs: Vec<Subscription> }
// new(): self._subs.push(cx.subscribe(...));

// 2. Detach — callback görünümden bağımsız yaşar
cx.subscribe(&entity, |...| { ... }).detach();

// 3. Geçici scope — drop sonrası otomatik unsubscribe
let _sub = cx.observe(&entity, |...| { ... });
// _sub düştüğünde callback kaldırılır
```

### Subscription üreten yöntemler

`Context<T>` üzerinde mevcut başlıca subscription üreticiler:

- **`cx.observe(entity, f)`** — Hedef varlık `cx.notify()` çağırdığında fire eder.
- **`cx.subscribe(entity, f)`** — `EventEmitter<E>` event'leri için tipli dinleyici.
- **`cx.observe_global::<G>(f)`** — Global durum değiştiğinde.
- **`cx.observe_release(entity, f)`** — Varlık drop edildiğinde, durum silinmeden hemen önce.
- **`cx.on_focus(handle, window, f)`, `cx.on_blur(...)`, `cx.on_focus_in(...)`, `cx.on_focus_lost(window, f)`** — Odak değişimleri. Descendant focus-out için düşük seviyeli `window.on_focus_out(handle, cx, f)` kullanılır.
- **Pencere observer'ları**: `cx.observe_window_bounds`, `cx.observe_window_activation`, `cx.observe_window_appearance`, `cx.observe_button_layout_changed`, `cx.observe_pending_input`, `cx.observe_keystrokes`.

### Tuzaklar

- **`detach()` uzun yaşayan callback'i görünüm ömründen koparır.** Görünüm drop olduktan sonra hâlâ fire ediyorsa içeride `WeakEntity` saklanır ve `update` çağrısının `Err` döneceği bilinerek erken çıkış yapılır.
- **Subscription drop sırasına davranış bağlanmaz.** Birden çok abonelik birbirine bağlıysa, drop sırası deterministic değildir; açık bir `teardown()` method'u veya tek bir owner struct ile yönetilir.
- **`observe` callback'i içinde gözlenen varlığı update etmek panic verir.** Reentrant update yasağı geçerlidir; iş `cx.defer(|cx| ...)` veya `cx.spawn(...)` ile ertelenir.

## 9.7. Window-bound Observer, Release ve Focus Helper Desenleri

Standart `observe`, `subscribe` ve `on_release` callback'leri yalnızca `App` veya `Context<T>` parametresi verir. UI katmanında pek çok iş `&mut Window` da istediği için GPUI aynı desenlerin **pencereye bağlı (`window-bound`)** varyantlarını sağlar; aynı zamanda yeni varlık yaratımını gözlemleyen `observe_new` deseni global hook'lar için kullanılır.

### Yeni varlık yaratımını gözleme

`App::observe_new<T>(|state, Option<&mut Window>, &mut Context<T>| ...)`, belirli türde her yeni varlık oluşumunda tetiklenir. Varlık bir pencere içinde yaratıldıysa `Some(window)` gelir; headless veya app-level yaratımda `None` olabilir.

```rust
cx.observe_new(|workspace: &mut Workspace, window, cx| {
    if let Some(window) = window {
        workspace.install_window_hooks(window, cx);
    }
}).detach();
```

Zed'de `zed.rs`, `toast_layer`, `theme_preview`, `telemetry_log`, `move_to_applications` gibi modüller workspace/project/editor yaratıldığında global hook takmak için bu deseni kullanır. Dönen `Subscription` ya saklanır ya da app ömrü boyunca gerekiyorsa `detach()` edilir.

### Pencere bağlamıyla observe/subscribe

```rust
self._observe_active_pane = cx.observe_in(active_pane, window, |this, pane, window, cx| {
    this.sync_from_pane(&pane, window, cx);
});

self._subscription = cx.subscribe_in(&modal, window, |this, modal, event, window, cx| {
    this.handle_modal_event(modal, event, window, cx);
});
```

- **`Context<T>::observe_in(&Entity<V>, window, |this, Entity<V>, window, cx| ...)`** — Hedef varlık `cx.notify()` yaptığında mevcut varlığı pencere bağlamıyla update eder.
- **`Context<T>::subscribe_in(&Entity<Emitter>, window, |this, emitter, event, window, cx| ...)`** — `EventEmitter` olaylarını pencere bağlamıyla işler.
- **`Context<T>::observe_self(|this, cx| ...)`** — Mevcut varlık `cx.notify()` çağırdığında kendi üzerinde callback çalıştırır; türetilmiş/cache durumunu tek yerde tutmak için kullanılır.
- **`Context<T>::subscribe_self::<Evt>(|this, event, cx| ...)`** — Mevcut varlığın kendi yaydığı event'i dinler. Bu desen dikkatli kullanılmalıdır; çoğu durumda event'i emit eden kod yolunda durum güncellemek daha açıktır.
- **`Context<T>::observe_global_in::<G>(window, |this, window, cx| ...)`** — Global durum notify olduğunda mevcut varlığı pencere bağlamıyla update eder. Pencere geçici olarak update stack'inden alınmışsa veya kapanmışsa notification atlanır, observer canlı kalır.

Bu API'ler içeride `ensure_window(observer_id, window.handle.id)` çağırır; varlığın hangi pencereye bağlı çalışacağını GPUI'a kaydeder. Aynı varlık birden fazla pencerede kullanılacaksa hangi pencerenin bağlandığını planlamak önemlidir.

### Release gözleme

- **`App::observe_release(&entity, |state, cx| ...)`** — Varlığın son güçlü tutamacı (`strong handle`) düştükten sonra, durum drop edilmeden hemen önce çalışır.
- **`App::observe_release_in(&entity, window, |state, window, cx| ...)`** — Aynı callback'i pencere üzerinden çalıştırır; pencere kapanmışsa update başarısız olur ve callback atlanabilir.
- **`Context<T>::on_release_in(window, |this, window, cx| ...)`** — Mevcut varlığın release'ini pencereyle birlikte gözler.
- **`Context<T>::observe_release_in(&other, window, |this, other, window, cx| ...)`** — Başka varlık release olurken observer varlığı da update eder.

### Focus helper'ları

- **`cx.focus_view(&entity, window)`** — `Focusable` implement eden başka bir görünümü odaklar.
- **`cx.focus_self(window)`** — Mevcut varlık `Focusable` ise odağı kendine taşır. İçeride `window.defer(...)` kullanır; bu nedenle render veya action callback'i içinde çağrıldığında odak değişimi effect cycle sonunda uygulanır.
- **`window.disable_focus()`** — Pencereyi blur eder ve `focus_enabled` bayrağını `false` yapar. **Tersine çeviren bir API yoktur**; çağrıldıktan sonra `focus_next/focus_prev/focus(...)` çağrıları sessizce no-op olur. Yalnızca pencere ömrü boyunca klavye odağını kalıcı olarak kapatmak gerekiyorsa kullanılır (read-only viewer, kiosk modu).

### Tuzaklar

- **`observe_new` callback'inde `window` her zaman gelmez.** Headless testlerde ve app-level varlık yaratımında `None` döner; closure mutlaka `Option`'u ele almalıdır.
- **Pencereye bağlı subscription struct alanında saklanmazsa hemen drop olur** ve callback bir kez bile çalışmadan iptal edilir. `_subscription = ...` formu zorunludur (alan adı `_` ile başlayan unused field convention'u).
- **`focus_self` ertelendiği için hemen sonraki satırda focus değişmiş gibi okumak yanlış sonuç verir.** Sonuç sonraki effect/frame akışında gözlemlenir.

## 9.8. Varlık Reservation ve Çift Yönlü Referans

Kaynak: `crates/gpui/src/app/async_context.rs:43+` ve `app.rs::reserve_entity`/`insert_entity`.

İki varlık (`entity`) birbirini bilmek zorundaysa (örn. `Workspace` ↔ `Pane`: workspace çocuk pane'in id'sini bilir, pane parent workspace'e `WeakEntity` ile bağlanır), önce hangisi yaratılacaktır? Sıradan akış sıralıdır — önce parent, sonra child — ama parent yaratılırken child'ın id'si bilinmek zorundadır. **Reservation deseni**, bu sıralama sorununu çözer: önce child için bir id rezerve edilir, parent bu id ile yaratılır, sonra child rezervasyona yerleştirilir.

```rust
let pane_reservation: Reservation<Pane> = cx.reserve_entity();
let pane_id = pane_reservation.entity_id();

let workspace = cx.new(|cx| {
    Workspace::with_pane_id(pane_id, cx)
});

let pane = cx.insert_entity(pane_reservation, |cx| {
    Pane::new(workspace.downgrade(), cx)
});
```

### `Reservation<T>` API

- **`entity_id()`** — Entity daha yaratılmadan önce kimliğini verir.
- **`cx.insert_entity(reservation, build)`** — Rezervasyonu doldurur ve `Entity<T>` döndürür.
- Doldurulmadan drop edilirse rezervasyon iptal olur ve önceden yayılmış id geçersiz hâle gelir.

Tipik desen: child varlık parent'a `WeakEntity` ile bağlanır (cycle olmasın diye); rezervasyon sayesinde parent yaratılırken child id'sinin önceden bilinmesi gerektiği durumlarda da güçlü-güçlü döngü kurulmaz. Aynı API `AsyncApp` üzerinden de çağrılabilir.

### Tuzaklar

- **Reservation kullanmadan iki `Entity<T>` birbirine güçlü sahiplikle bağlanırsa cycle oluşur** ve hiçbir tutamaç drop olmadan bellekte kalır. En az bir taraf `WeakEntity<T>` olmalıdır.
- **`insert_entity` çağrılmadan rezervasyon drop edilirse varlık yaratılmamış sayılır.** Önceden `entity_id()` ile yayılan kimlik geçersiz olur; parent bu id'ye işaret eden bir referans tutuyorsa upgrade asla başarılı olmaz.
- **`cx.new` mevcut update'in içinde rezervasyonu da doldurabilir;** reentrant `update` yasakları [Effect cycle yönetimi](#effect-cycle-yönetimi-defer-ailesi) bölümündeki erteleme kurallarıyla aynı mantığa tabidir.

## 9.9. Varlık Release, Cleanup ve Leak Detection

Varlık tutamaçları (`entity handle`) ref-count tabanlı yaşar: son güçlü `Entity<T>` tutamacı düştüğü an varlık release edilir (durum drop'lanır), `WeakEntity<T>` bu kararı etkilemez. Release sırasında temizlik yapmak gerekirse (önbellek dosyası sil, ağ bağlantısı kapat, observer'ı bilgilendir) GPUI bir dizi callback noktası sağlar; ayrıca testlerde sızıntı (leak) tespiti için ek araçlar vardır.

### Cleanup API'leri

- **`cx.on_release(|this, cx| ...)`** — Mevcut varlık release edilirken çalışır; varlık durumu hâlâ erişilebilirdir, ama yeni iş başlatmak için elverişsizdir.
- **`App::observe_release(&entity, |entity, cx| ...)`** — App bağlamından başka bir varlığın release'ini izler.
- **`Context<T>::observe_release(&entity, |this, entity, cx| ...)`** — Görünüm durumu ile başka bir varlığın release'ini birlikte izler.
- **`window.observe_release(&entity, cx, |entity, window, cx| ...)`** — Release anında pencere bağlamı gerekiyorsa.
- **`cx.on_drop(...)` / `AsyncApp::on_drop(...)`** — Rust scope drop'unda varlık update etmek için "deferred" callback üretir; varlık zaten düşmüşse update başarısız olabilir.

### Tipik kullanım

```rust
struct Preview {
    cache: Entity<RetainAllImageCache>,
    cache_released: bool,
    _subscriptions: Vec<Subscription>,
}

impl Preview {
    fn new(cx: &mut Context<Self>) -> Self {
        let cache = RetainAllImageCache::new(cx);
        let subscription = cx.observe_release(&cache, |this, _cache, cx| {
            this.cache_released = true;
            cx.notify();
        });

        Self {
            cache,
            cache_released: false,
            _subscriptions: vec![subscription],
        }
    }
}
```

### Leak kontrolü (testler / feature flag arkasında)

Bellek sızıntılarını yakalamak için snapshot tabanlı denetim:

```rust
let snapshot = cx.leak_detector_snapshot();
// Testin gövdesi burada çalışır.
cx.assert_no_new_leaks(&snapshot);
```

Snapshot alındıktan sonra oluşturulan ve test sonunda hâlâ canlı kalan varlıklar bu çağrıda raporlanır. Genelde test feature'ı altında kullanılır.

### Tuzaklar

- **Subscription saklanmazsa hemen drop olur ve listener iptal edilir.** `let _ = cx.subscribe(...)` veya `_subscriptions: Vec<Subscription>` alanı zorunludur.
- **Karşılıklı `Entity<T>` alanları cycle üretir;** en az bir tarafın `WeakEntity<T>` olması gerekir.
- **Release callback içinde uzun async iş başlatılırsa**, varlık durumunun artık kapanmakta olduğu varsayılır; callback'in başında ihtiyaç duyulan veriler kopyalanır.
- **`WeakEntity::update` / `read_with` her zaman `Result` döndürür.** Varlık düşmüş olabileceği için hatayı görünür biçimde ele almak gerekir; `?` ile erken çıkış doğru desendir.

## 9.10. Varlık Type Erasure, Callback Adaptörleri ve Görünüm Cache

Bu bölüm GPUI çekirdeğinde public olan, ama günlük kullanımda kolayca gözden kaçan küçük API yüzeylerini bir araya getirir: `Entity` ve `WeakEntity` üzerindeki nadir method'lar, `AnyEntity`/`AnyView` type erasure mekaniği, UI öğesi callback'leri için adaptör seçimi, `AnyView::cached` ile görünüm cache deseni, `FocusHandle`'ın daha az bilinen yüzeyi ve `ElementId` varyantları.

#### Entity ve WeakEntity Tam Yüzeyi

`Entity<T>` güçlü tutamaçtır (`strong handle`):

- `entity.entity_id() -> EntityId`
- `entity.downgrade() -> WeakEntity<T>`
- `entity.into_any() -> AnyEntity`
- `entity.read(cx: &App) -> &T`
- `entity.read_with(cx, |state, cx| ...) -> R`
- `entity.update(cx, |state, cx| ...) -> R`
- `entity.update_in(visual_cx, |state, window, cx| ...) -> C::Result<R>`
- `entity.as_mut(cx) -> GpuiBorrow<T>`: mutable borrow verir; borrow drop
  olurken varlık notify edilir.
- `entity.write(cx, value)`: durumu komple değiştirir ve `cx.notify()` çağırır.

`Context<T>` mevcut varlık için aynı kimlik/tutamaç yüzeyini verir:

- `cx.entity_id() -> EntityId`
- `cx.entity() -> Entity<T>`: mevcut varlık hâlâ canlı olmak zorunda olduğu için
  güçlü tutamaç döndürür.
- `cx.weak_entity() -> WeakEntity<T>`: async task, listener veya döngüsel sahiplik
  riski olan alanlarda saklanacak tutamaç budur.

Kimlik dönüşümleri:

- `EntityId::as_u64()` ve `EntityId::as_non_zero_u64()` FFI, telemetry veya
  debug map anahtarı gibi typed id dışına çıkılan yerlerde kullanılır.
- `WindowId::as_u64()` aynı işi pencere kimliği için yapar. Bu değerleri domain
  id'si veya kalıcı workspace serialization anahtarı gibi kullanma; GPUI runtime
  kimliğidir.

`WeakEntity<T>` zayıf tutamaçtır:

- `weak.upgrade() -> Option<Entity<T>>`
- `weak.update(cx, |state, cx| ...) -> Result<R>`
- `weak.read_with(cx, |state, cx| ...) -> Result<R>`
- `weak.update_in(cx, |state, window, cx| ...) -> Result<R>`: varlığın mevcut
  penceresini `App::with_window(entity_id, ...)` üzerinden bulur; varlık düşmüşse
  veya current window yoksa hata döner.
- `WeakEntity::new_invalid()` hiçbir zaman upgrade edilemeyen sentinel tutamaç
  üretir; opsiyon yerine "geçersiz ama tipli tutamaç" gereken yerlerde kullanılır.

`AnyEntity` ve `AnyWeakEntity` heterojen koleksiyonlar içindir:

- `AnyEntity::{entity_id, entity_type, downgrade, downcast::<T>}`
- `AnyWeakEntity::{entity_id, is_upgradable, upgrade, new_invalid}`
- `AnyWeakEntity::assert_released()` yalnız test/leak-detection feature altında
  vardır; güçlü tutamaç sızıntısını yakalamak için kullanılır.

Kural: plugin/dock/workspace gibi heterojen koleksiyon sınırı yoksa typed
`Entity<T>`/`WeakEntity<T>` kullan. `AnyEntity` downcast zorunluluğu getirir ve
yanlış tipte `downcast::<T>()` varlığı `Err(AnyEntity)` olarak geri verir.

#### AnyView, AnyWeakView ve EmptyView

`AnyView`, `Render` implement eden bir `Entity<V>` için UI öğesi olarak
kullanılabilen type-erased görünüm tutamacıdır:

```rust
let view: AnyView = pane.clone().into();
div().child(view.clone());
```

Önemli metotlar:

- `AnyView::from(entity)` veya `entity.into_element()` typed görünümü type-erased
  UI öğesi yapar.
- `any_view.downcast::<T>() -> Result<Entity<T>, AnyView>` typed tutamaca geri
  dönmek içindir.
- `any_view.downgrade() -> AnyWeakView`; `AnyWeakView::upgrade() -> Option<AnyView>`.
- `any_view.entity_id()` ve `entity_type()` debug/registry mantığı için kullanılır.
- `EmptyView` hiçbir şey render etmeyen `Render` görünümüdür.

`AnyView::cached(style_refinement)` pahalı child görünüm render'ını cache'lemek için
kullanılır:

```rust
div().child(
    AnyView::from(pane.clone())
        .cached(StyleRefinement::default().v_flex().size_full()),
)
```

Cache, görünüm `cx.notify()` çağırmadıysa önceki layout/prepaint/paint aralıklarını
yeniden kullanır. `Window::refresh()` çağrısı cache'i bypass eder; inspector
picking açıkken de hitbox'ların eksiksiz olması için caching devre dışı kalır.
Cache key bounds, aktif `ContentMask` ve aktif `TextStyle` içerir. Bu nedenle
`cached(...)` için verdiğin kök `StyleRefinement`, görünümün gerçek kök layout
stiliyle uyumlu olmalıdır; yanlış refinement layout'u bayat veya hatalı gösterir.

#### Callback Adaptörleri

Çoğu UI öğesi callback'i görünüm durumu almaz:

```rust
Fn(&Event, &mut Window, &mut App)
```

Duruma dönmek için doğru adaptörü seç:

- `cx.listener(|this, event, window, cx| ...)`:
  `Fn(&Event, &mut Window, &mut App)` üretir. İçeride mevcut varlığın
  `WeakEntity` tutamacı kullanılır; varlık düşmüşse callback sessizce no-op olur.
- `cx.processor(|this, event, window, cx| -> R { ... })`:
  `Fn(Event, &mut Window, &mut App) -> R` üretir. Event'i sahiplenir ve dönüş
  değeri gerekirken kullanılır.
- `window.listener_for(&entity, |state, event, window, cx| ...)`:
  mevcut `Context<T>` dışında, elde typed `Entity<T>` varken listener üretir.
- `window.handler_for(&entity, |state, window, cx| ...)`:
  event parametresi olmayan `Fn(&mut Window, &mut App)` handler üretir.

`cx.listener` dışındaki adaptörleri reusable component veya window-level helper
yazarken kullan. Handler içinde `cx.notify()` çağrısı yine durum değişimine göre
senin sorumluluğundadır.

#### FocusHandle Zayıf Tutamaç ve Dispatch

`FocusHandle` yalnız focus vermek için değildir:

- `focus_handle.downgrade() -> WeakFocusHandle`
- `WeakFocusHandle::upgrade() -> Option<FocusHandle>`
- `focus_handle.contains(&other, window) -> bool`: son rendered frame'deki focus
  ağaç ilişkisini kontrol eder.
- `focus_handle.dispatch_action(&action, window, cx)`: dispatch'i odaktaki node
  yerine belirli odak tutamacının node'undan başlatır.

`contains_focused(window, cx)` "ben veya descendant focused mı?", `within_focused`
ise "ben focused node'un içinde miyim?" sorusunu cevaplar. `within_focused`
imzasında `cx: &mut App` vardır; çünkü dispatch/focus path hesaplarında app
durumuyla çalışır.

#### ElementId Tam Varyantları

Stabil UI öğesi durumu için kullanılan `ElementId` varyantları:

- `View(EntityId)`, `Integer(u64)`, `Name(SharedString)`, `Uuid(Uuid)`
- `FocusHandle(FocusId)`, `NamedInteger(SharedString, u64)`, `Path(Arc<Path>)`
- `CodeLocation(Location<'static>)`, `NamedChild(Arc<ElementId>, SharedString)`
- `OpaqueId([u8; 20])`

`ElementId::named_usize(name, usize)` `NamedInteger` üretir. Debug selector veya
string tabanlı ID gerektiğinde `Name`; liste satırı gibi tekrar eden yapılarda
`NamedInteger`; text anchor gibi byte-level kimliklerde `OpaqueId` kullanılır.


---
