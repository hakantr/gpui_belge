# Bölüm IV — Async, Görev ve Durum Yönetimi

---

## Async İşler


Foreground task:

```rust
cx.spawn(async move |cx| {
    cx.update(|cx| {
        // App state güncelle
    })
})
.detach();
```

Entity task:

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

Window'a bağlı task:

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

`Context::spawn` ve `spawn_in` imzaları
`AsyncFnOnce(WeakEntity<T>, &mut AsyncApp/AsyncWindowContext)` ister; closure
`async move |this, cx| { ... }` formuyla yazılır. Closure `Result` döndürüyorsa
örnekteki gibi `Ok::<(), anyhow::Error>(())` ile tip annotate et veya en üstte
`let _: Result<_, anyhow::Error> = ...` kullan.

`window.to_async(cx)` doğrudan `AsyncWindowContext` üretir; callback dışına
taşınacak pencere bağlı async helper yazarken kullanılır. Çoğu entity/view kodunda
`cx.spawn_in(window, ...)` daha güvenli ve okunur wrapper'dır.

Background thread:

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

Testlerde zamanlayıcı:

- GPUI testlerinde `smol::Timer::after(...)` yerine
  `cx.background_executor().timer(duration).await` kullan.
- `run_until_parked()` ile uyum için GPUI executor timer'ı tercih edilir.

## Executor, Priority, Timeout ve Test Zamanı


GPUI'da foreground iş UI thread üzerinde, background iş scheduler/thread pool
üzerinde çalışır. Bu ayrım sadece performans değil, hangi context'in await
noktası boyunca tutulabileceğini de belirler.

Temel tipler:

- `BackgroundExecutor`: `spawn`, `spawn_with_priority`, `timer`,
  `scoped`, `scoped_priority`, testlerde `advance_clock`, `run_until_parked`,
  `simulate_random_delay`.
- `ForegroundExecutor`: main thread'e future koyar; `spawn`,
  `spawn_with_priority`, synchronous köprü için `block_on` ve
  `block_with_timeout` sağlar.
- `Priority`: `RealtimeAudio`, `High`, `Medium`, `Low`. Realtime ayrı thread
  ister; UI dışı audio gibi çok sınırlı işler dışında kullanılmaz.
- `Task<T>`: await edilebilir handle. Drop edilirse iş iptal edilir;
  tamamlanması isteniyorsa await edilir, struct alanında saklanır veya
  `detach()`/`detach_and_log_err(cx)` kullanılır.
- `FutureExt::with_timeout(duration, executor)`: future ile executor timer'ını
  yarışır ve `Result<T, Timeout>` döndürür.

Örnek:

```rust
let executor = cx.background_executor().clone();
let task = cx.background_spawn(async move {
    parse_large_file(path).await
});

let result = task
    .with_timeout(Duration::from_secs(5), &executor)
    .await?;
```

Foreground priority:

```rust
cx.spawn_with_priority(Priority::High, async move |cx| {
    cx.update(|cx| {
        cx.refresh_windows();
    });
})
.detach();
```

`AsyncApp::update(|cx| ...)` doğrudan `R` döndürür; entity'lerden farklı olarak
fallible değildir, bu yüzden `?` ile yayılmaz. Pencere içi async çalışmada
`AsyncWindowContext::update(|window, cx| ...) -> Result<R>` ya da
`Entity::update(cx, ...)` fallible varyantları kullanılır.

Async context convenience yüzeyi:

- `AsyncApp::refresh()` tüm pencereler için redraw planlar; `update(|cx|
  cx.refresh_windows())` yazmadan async path'ten redraw tetiklemek içindir.
- `AsyncApp::background_executor()` ve `foreground_executor()` executor
  handle'larını verir. Timer/timeout veya nested spawn gerekiyorsa bunları kullan.
- `AsyncApp::subscribe(&entity, ...)`, `open_window(options, ...)`, `spawn(...)`,
  `has_global::<G>()`, `read_global`, `try_read_global`, `read_default_global`,
  `update_global` ve `on_drop(&weak, ...)` await edilebilir app task'larında aynı
  foreground state'e güvenli dönüş noktalarıdır.
- `AsyncWindowContext::window_handle()` bağlı pencereyi verir.
  `update(|window, cx| ...)` sadece window state'i, `update_root(|root, window,
  cx| ...)` root `AnyView` de gerektiğinde kullanılır.
- `AsyncWindowContext::on_next_frame(...)`, `read_global`, `update_global`,
  `spawn(...)` ve `prompt(...)` pencereye bağlı async işlerde `Window` kapanmış
  olabilir durumunu `Result`/fallback receiver ile yönetir.

Entity ve window bağlı priority spawn:

- `cx.spawn_in_with_priority(priority, window, async move |weak, cx| { ... })`
  current entity'nin `WeakEntity<T>` handle'ını ve `AsyncWindowContext` verir.
- `window.spawn_with_priority(priority, cx, async move |cx| { ... })` pencere
  handle'ına bağlı ama entity'siz async iş içindir.
- Priority yalnızca foreground executor kuyruğunda polling önceliği verir;
  uzun CPU işi hâlâ `background_spawn` tarafına taşınmalıdır.

Hazır değer:

```rust
fn cached_or_async(cached: Option<Data>, cx: &App) -> Task<anyhow::Result<Data>> {
    if let Some(data) = cached {
        Task::ready(Ok(data))
    } else {
        cx.background_spawn(async move { load_data().await })
    }
}
```

Test zamanı:

- `cx.background_executor().timer(duration).await` GPUI scheduler'a bağlıdır;
  `smol::Timer::after` GPUI `run_until_parked()` ile uyumsuz kalabilir.
- `advance_clock(duration)` sadece fake clock'u ilerletir; runnable işleri
  yürütmek için ayrıca `run_until_parked()` gerekir.
- `allow_parking()` outstanding task varken parked olmayı testte bilerek
  kabul etmek içindir; production path'e taşınmaz.
- `block_with_timeout` timeout olduğunda future'ı geri verir; bu, işi iptal
  etmek ya da sonra yeniden poll etmek için çağıranın karar vermesini sağlar.
- `PriorityQueueSender<T>` / `PriorityQueueReceiver<T>` yalnızca
  Windows/Linux/wasm cfg'lerinde re-export edilir. `send(priority, item)`,
  `try_pop()`, `pop()`, `try_iter()` ve `iter()` ile high/medium/low kuyrukları
  ağırlıklı seçimle tüketir; `Priority::RealtimeAudio` bu kuyruğa girmez.

## Task, TaskExt ve Async Hata Yönetimi


`Task<T>` GPUI'ın temel async handle'ıdır. Yardımcı trait `TaskExt`
(`crates/gpui/src/executor.rs:33+`) `Task<Result<T, E>>` üzerine ek metotlar ekler:

```rust
pub trait TaskExt<T, E> {
    fn detach_and_log_err(self, cx: &App);
    fn detach_and_log_err_with_backtrace(self, cx: &App);
}
```

`detach_and_log_err` task'ı arka plana atar ve hata oluşursa
`log::error!("...: {err}")` formatında loglar. `_with_backtrace` aynı işlevi
`{:?}` formatıyla yapar; `anyhow::Error` durumlarında full backtrace ister.

Pratik akış:

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

Detach varyantları:

- `task.detach()`: hata loglanmaz, sessizce yutulur. UI'da gösterilemeyen
  fire-and-forget iş için.
- `task.detach_and_log_err(cx)`: standart akış, prod kodunda tercih edilir.
- `task.detach_and_prompt_err(prompt_label, window, cx, |err, window, cx| ...)`:
  workspace UI'sında kullanılan ek helper (workspace crate'inde tanımlı);
  hatayı modal prompt'la kullanıcıya gösterir.

Yazarken kararlar:

- Async sonuç caller'a dönmesi gerekiyorsa `Task<R>` döndür ve await et; struct
  alanında saklamak iptal davranışı verir.
- Caller fire-and-forget yaptıysa task'ı return etmek gereksiz; doğrudan
  `detach_and_log_err(cx)` çağır.
- Result'ı log'a düşürmemek için manuel `if let Err(e) = task.await { ... }`
  yazma; `detach_and_log_err` zaten `track_caller` ile log location'ı tutar.

Tuzaklar:

- Result tipinin `E` argümanı `Display + Debug` istemeli; `anyhow::Error` ve
  custom error tipi otomatik uyar.
- Task'ı `Vec<Task<()>>` içinde topladıysan drop sırası sürpriz olabilir;
  iptal etmek istemediğin tipik akışta `detach()` daha açık bir niyet bildirir.
- `cx.spawn_in(window, ...)` Window düştüğünde task otomatik iptal etmez;
  WeakEntity üzerinden `update`/`update_in` çağrısı `Result` döndüğünden
  bunu erken çıkış sinyali olarak ele al.

## Global State, Observe ve Event


Global state:

```rust
struct MyGlobal(State);
impl Global for MyGlobal {}

cx.set_global(MyGlobal(state));

cx.update_global::<MyGlobal, _>(|global, cx| {
    global.0.changed = true;
});

let value = cx.read_global::<MyGlobal, _>(|global, _| global.0.clone());
```

Observe:

```rust
subscriptions.push(cx.observe(&other, |this, other, cx| {
    this.copy = other.read(cx).value;
    cx.notify();
}));
```

Event:

```rust
struct Saved;
impl EventEmitter<Saved> for Document {}

cx.emit(Saved);

subscriptions.push(cx.subscribe(&document, |this, document, _: &Saved, cx| {
    this.last_saved = Some(document.entity_id());
    cx.notify();
}));
```

Window observe:

- `cx.observe_window_bounds(window, ...)`
- `cx.observe_window_activation(window, ...)`
- `cx.observe_window_appearance(window, ...)`
- `cx.observe_button_layout_changed(window, ...)`
- `cx.observe_pending_input(window, ...)`
- `cx.observe_keystrokes(...)`

## Global State Yardımcıları ve `cx.defer`


`App` üzerinde bulunan yardımcı global state metotları, mevcut bölümlerde
parça parça geçtiği için burada tek listede topluyoruz:

- `cx.set_global<T: Global>(value)`: var olanı ezer; yoksa kurar.
- `cx.global<T>() -> &T`: panic eder; var olduğundan eminsen.
- `cx.global_mut<T>()`: aynı, mutable.
- `cx.default_global<T: Default>() -> &mut T`: yoksa default instance oluşturur,
  varsa mevcut global'i mutable döndürür.
- `cx.has_global<T>() -> bool`: kontrol etmeden global okumak istediğinde.
- `cx.try_global<T>() -> Option<&T>`: nullable okuma.
- `cx.update_global<T, R>(|g, cx| ...) -> R`: kapsamlı update.
- `cx.read_global<T, R>(|g, cx| ...) -> R`: kapsamlı read.
- `cx.remove_global<T>() -> T`: instance'ı geri alır; bir daha set edilmezse
  global yok sayılır.
- `cx.observe_global<T>(|cx| ...) -> Subscription`: global her notify olduğunda.

Effect cycle yönetimi:

- `cx.defer(|cx| ...)`: mevcut effect cycle bittiğinde çalışır. Reentrant
  `update` veya entity'leri stack'e geri vermek için ideal.
- `Context<T>::defer_in(window, |this, window, cx| ...)`: window-bound varyant.
- `window.defer(cx, |window, cx| ...)`: doğrudan window context'inden ertele.
- `window.refresh()`: pencereyi bir sonraki frame'de redraw için işaretle.
- `cx.refresh_windows()`: tüm pencereler için aynı.

Tuzaklar:

- `cx.global<T>()` ve `cx.global_mut<T>()` panic eder; init'i kontrol etmediğin
  call site'ta `try_global` veya `has_global` kullan.
- `update_global` sırasında aynı global'i tekrar update etmek panic verir;
  iç içe çağrılarda `defer` ile ertelemek güvenli yoldur.
- Subscription `detach()` edilmezse owner drop'unda iptal olur; uzun yaşayan
  observer için sahibi olan struct'a kaydet.

## Subscription Yaşam Döngüsü


`crates/gpui/src/subscription.rs`.

`Subscription` opaque tiptir; düşürüldüğünde callback kaydını siler. Pratikte
üç desen vardır:

```rust
// 1. Field'da sakla
struct View { _subs: Vec<Subscription> }
// new(): self._subs.push(cx.subscribe(...));

// 2. Detach (callback view ömrü boyunca yaşar)
cx.subscribe(&entity, |...| { ... }).detach();

// 3. Geçici scope (drop sonrası unsubscribe)
let _sub = cx.observe(&entity, |...| { ... });
// _sub düştüğünde callback kaldırılır
```

Subscription üreten yöntemler (`Context<T>` üzerinde):

- `cx.observe(entity, f)`: `cx.notify()` çağrıldığında fire eder.
- `cx.subscribe(entity, f)`: `EventEmitter<E>` event'leri için.
- `cx.observe_global::<G>(f)`: global state değişti.
- `cx.observe_release(entity, f)`: entity drop edildi.
- `cx.on_focus(handle, window, f)` / `cx.on_blur(...)` / `cx.on_focus_in(...)` /
  `cx.on_focus_lost(window, f)`. Descendant focus-out için düşük seviyeli
  `window.on_focus_out(handle, cx, f)` kullanılır.
- `cx.observe_window_bounds`, `cx.observe_window_activation`,
  `cx.observe_window_appearance`, `cx.observe_button_layout_changed`,
  `cx.observe_pending_input`, `cx.observe_keystrokes`.

Tuzaklar:

- `detach()` uzun yaşayan callback'i view ömründen koparır; view drop olduktan
  sonra hâlâ fire ederse `WeakEntity` ile koru.
- Subscription drop sırasına davranış bağlama; birden çok abonelik birbirini
  etkiliyorsa açık teardown metodu veya tek owner struct kullan.
- `observe` sırasında entity'yi update etmek panic verir; `cx.spawn(..)` ile
  ertele veya `cx.defer(|cx| ...)` kullan.

## Window-bound Observer, Release ve Focus Helper Desenleri


Normal `observe`, `subscribe` ve `on_release` callback'leri sadece `App` veya
`Context<T>` verir. UI katmanında çoğu iş pencere de istediği için GPUI aynı
desenlerin window-bound varyantlarını sağlar.

Yeni entity gözleme:

```rust
cx.observe_new(|workspace: &mut Workspace, window, cx| {
    if let Some(window) = window {
        workspace.install_window_hooks(window, cx);
    }
}).detach();
```

- `App::observe_new<T>(|state, Option<&mut Window>, &mut Context<T>| ...)`
  belirli türde bir entity oluşturulduğunda çalışır. Entity bir window içinde
  yaratıldıysa `Some(window)` gelir; headless veya app-level yaratımda `None`
  gelebilir.
- Zed `zed.rs`, `toast_layer`, `theme_preview`, `telemetry_log`,
  `move_to_applications` gibi modüllerde workspace/project/editor yaratıldığında
  global hook takmak için bu deseni kullanır.
- Dönen `Subscription` saklanmalı veya app ömrü boyunca gerekiyorsa `detach()`
  edilmelidir.

Window context'iyle observe/subscribe:

```rust
self._observe_active_pane = cx.observe_in(active_pane, window, |this, pane, window, cx| {
    this.sync_from_pane(&pane, window, cx);
});

self._subscription = cx.subscribe_in(&modal, window, |this, modal, event, window, cx| {
    this.handle_modal_event(modal, event, window, cx);
});
```

- `Context<T>::observe_in(&Entity<V>, window, |this, Entity<V>, window, cx| ...)`
  observed entity `cx.notify()` yaptığında current entity'yi pencere context'iyle
  update eder.
- `Context<T>::subscribe_in(&Entity<Emitter>, window, |this, emitter, event, window, cx| ...)`
  `EventEmitter` olaylarını window context'iyle işler.
- `Context<T>::observe_self(|this, cx| ...)` current entity `cx.notify()` yaptığında
  kendi üzerinde callback çalıştırır; derived/cache state'i tek yerde tutmak için
  kullanılabilir.
- `Context<T>::subscribe_self::<Evt>(|this, event, cx| ...)` current entity'nin
  kendi yaydığı event'i dinler. Bu desen dikkatli kullanılmalı; çoğu durumda event'i
  doğrudan emit eden kod path'inde state güncellemek daha açıktır.
- `Context<T>::observe_global_in::<G>(window, |this, window, cx| ...)` global
  state notify olduğunda current entity'yi pencere context'iyle update eder.
  Pencere geçici olarak update stack'inden alınmış veya kapanmışsa notification
  atlanır, observer canlı kalır.
- Bu API'ler `ensure_window(observer_id, window.handle.id)` çağırır; entity'nin
  hangi pencereye bağlı çalışacağını GPUI'a kaydeder. Aynı entity birden fazla
  pencerede kullanılacaksa hangi pencerenin bağlandığını açıkça düşün.

Release gözleme:

- `App::observe_release(&entity, |state, cx| ...)`: entity'nin son strong handle'ı
  düştükten sonra, state drop edilmeden hemen önce çalışır.
- `App::observe_release_in(&entity, window, |state, window, cx| ...)`: aynı
  callback'i pencere handle'ı üzerinden çalıştırır; pencere kapanmışsa update
  başarısız olur ve callback atlanabilir.
- `Context<T>::on_release_in(window, |this, window, cx| ...)`: current entity'nin
  release'ini pencereyle gözler.
- `Context<T>::observe_release_in(&other, window, |this, other, window, cx| ...)`:
  başka entity release olurken observer entity'yi de update eder.

Focus helper'ları:

- `cx.focus_view(&entity, window)`: `Focusable` implement eden başka bir view'i
  focuslar.
- `cx.focus_self(window)`: current entity `Focusable` ise focus'u kendine taşır.
  İçeride `window.defer(...)` kullanır; bu nedenle render/action callback içinde
  çağrıldığında focus değişimi effect cycle sonunda uygulanır.
- `window.disable_focus()`: pencereyi blur eder ve ardından `focus_enabled`
  bayrağını `false` yapar. Tersine çeviren bir API yoktur, yani çağrıldıktan
  sonra `focus_next/focus_prev/focus(...)` çağrıları sessizce no-op olur.
  Uygulama component'lerinde genellikle gerekmez; sadece pencere ömrü boyunca
  klavye focus'unu kalıcı kapatmak istediğinde kullan.

Tuzaklar:

- `observe_new` callback'inde `window` her zaman vardır varsayma; headless test ve
  app-level entity yaratımı `None` üretebilir.
- Window-bound subscription'ı struct alanında saklamazsan callback hemen düşer.
- `focus_self` delayed çalıştığı için hemen sonraki satırda focus değişmiş gibi
  okumak yanlıştır; sonucu sonraki effect/frame akışında gözle.

## Entity Reservation ve Çift Yönlü Referans


`crates/gpui/src/app/async_context.rs:43+` ve `app.rs::reserve_entity`/`insert_entity`.

Bazen bir entity oluşturulurken başka bir entity'nin kimliğini veya zayıf handle'ını
önceden bilmek gerekir (ör. `Workspace` ve `Pane`). Bunu kuvvetli referans döngüsü
kurmadan yapmak için `Reservation` deseni vardır:

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

`Reservation<T>`:

- `entity_id()` daha entity oluşturulmadan kimliği verir.
- `cx.insert_entity(reservation, build)` rezervasyonu doldurur ve `Entity<T>` döner.
- Doldurulmadan drop edilirse rezervasyon iptal olur.

Deseni: çocuk entity ebeveyne `WeakEntity` ile bağlanır; rezervasyon sayesinde
ebeveynin oluştururken çocuk handle'ı önceden bilinmesi gerektiği durumlarda da
döngü oluşmaz. `AsyncApp` üzerinden de aynı API çağrılabilir.

Tuzaklar:

- Reservation kullanmadan iki `Entity<T>` birbirine kuvvetli sahiplikle bağlanırsa
  hiçbir handle drop olmadığında bellek sızıntısı oluşur.
- `insert_entity` çağrılmadan reservation drop'ta entity oluşturulmamış sayılır;
  daha önce `entity_id()` ile yayılmış kimlik artık geçersizdir.
- `cx.new` mevcut güncellemenin içinde rezervasyonu da doldurabilir; reentrant
  `update` yasakları aynı şekilde geçerlidir.

## Entity Release, Cleanup ve Leak Detection


Entity handle'ları ref-count mantığıyla yaşar. Son güçlü `Entity<T>` handle'ı
düştüğünde entity release edilir; `WeakEntity<T>` bunu engellemez.

Cleanup API'leri:

- `cx.on_release(|this, cx| ...)`: mevcut entity release edilirken çalışır.
- `App::observe_release(&entity, |entity, cx| ...)`: app context'ten başka bir
  entity'nin release'ini izle.
- `Context<T>::observe_release(&entity, |this, entity, cx| ...)`: view state ile
  başka bir entity'nin release'ini izle.
- `window.observe_release(&entity, cx, |entity, window, cx| ...)`: release
  sırasında window context gerekiyorsa.
- `cx.on_drop(...)` / `AsyncApp::on_drop(...)`: Rust scope drop'unda entity update
  etmek için `Deferred` callback üretir; entity zaten düşmüşse update başarısız
  olabilir.

Örnek:

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

Leak kontrolü testlerde/feature altında:

```rust
let snapshot = cx.leak_detector_snapshot();
// Test body.
cx.assert_no_new_leaks(&snapshot);
```

Tuzaklar:

- Subscription saklanmazsa hemen drop olur ve listener iptal edilir.
- Karşılıklı `Entity<T>` alanları cycle üretir; bir taraf `WeakEntity<T>` olmalı.
- Release callback içinde uzun async iş başlatacaksan entity state'in artık
  kapanmakta olduğunu varsay; gerekli veriyi callback başında kopyala.
- `WeakEntity::update/read_with` her zaman `Result` döndürür; entity düşmüş
  olabileceği için hatayı görünür biçimde ele al.

## Entity Type Erasure, Callback Adaptörleri ve View Cache


Bu bölüm GPUI çekirdeğinde public olan ama günlük kullanımda kolay atlanan küçük
API yüzeylerini toplar.

#### Entity ve WeakEntity Tam Yüzeyi

`Entity<T>` güçlü handle'dır:

- `entity.entity_id() -> EntityId`
- `entity.downgrade() -> WeakEntity<T>`
- `entity.into_any() -> AnyEntity`
- `entity.read(cx: &App) -> &T`
- `entity.read_with(cx, |state, cx| ...) -> R`
- `entity.update(cx, |state, cx| ...) -> R`
- `entity.update_in(visual_cx, |state, window, cx| ...) -> C::Result<R>`
- `entity.as_mut(cx) -> GpuiBorrow<T>`: mutable borrow verir; borrow drop
  olurken entity notify edilir.
- `entity.write(cx, value)`: state'i komple değiştirir ve `cx.notify()` çağırır.

`Context<T>` current entity için aynı kimlik/handle yüzeyini verir:

- `cx.entity_id() -> EntityId`
- `cx.entity() -> Entity<T>`: current entity hâlâ canlı olmak zorunda olduğu için
  strong handle döndürür.
- `cx.weak_entity() -> WeakEntity<T>`: async task, listener veya döngüsel sahiplik
  riski olan alanlarda saklanacak handle budur.

Kimlik dönüşümleri:

- `EntityId::as_u64()` ve `EntityId::as_non_zero_u64()` FFI, telemetry veya
  debug map anahtarı gibi typed id dışına çıkılan yerlerde kullanılır.
- `WindowId::as_u64()` aynı işi pencere kimliği için yapar. Bu değerleri domain
  id'si veya kalıcı workspace serialization anahtarı gibi kullanma; GPUI runtime
  kimliğidir.

`WeakEntity<T>` zayıf handle'dır:

- `weak.upgrade() -> Option<Entity<T>>`
- `weak.update(cx, |state, cx| ...) -> Result<R>`
- `weak.read_with(cx, |state, cx| ...) -> Result<R>`
- `weak.update_in(cx, |state, window, cx| ...) -> Result<R>`: entity'nin current
  window'ını `App::with_window(entity_id, ...)` üzerinden bulur; entity düşmüşse
  veya current window yoksa hata döner.
- `WeakEntity::new_invalid()` hiçbir zaman upgrade edilemeyen sentinel handle
  üretir; opsiyon yerine "geçersiz ama tipli handle" gereken yerlerde kullanılır.

`AnyEntity` ve `AnyWeakEntity` heterojen koleksiyonlar içindir:

- `AnyEntity::{entity_id, entity_type, downgrade, downcast::<T>}`
- `AnyWeakEntity::{entity_id, is_upgradable, upgrade, new_invalid}`
- `AnyWeakEntity::assert_released()` yalnız test/leak-detection feature altında
  vardır; güçlü handle sızıntısını yakalamak için kullanılır.

Kural: plugin/dock/workspace gibi heterojen koleksiyon sınırı yoksa typed
`Entity<T>`/`WeakEntity<T>` kullan. `AnyEntity` downcast zorunluluğu getirir ve
yanlış tipte `downcast::<T>()` entity'yi `Err(AnyEntity)` olarak geri verir.

##### Deref ile gizlenmiş yüzey (typed handle üzerinden untyped metot)

`Entity<T>` ve `WeakEntity<T>` `#[derive(Deref, DerefMut)]` ile içlerindeki
untyped handle'a deref eder
(`crates/gpui/src/app/entity_map.rs:413` ve `:739`):

```rust
#[derive(Deref, DerefMut)]
pub struct Entity<T>     { any_entity: AnyEntity,         entity_type: PhantomData<_> }
#[derive(Deref, DerefMut)]
pub struct WeakEntity<T> { any_entity: AnyWeakEntity,     entity_type: PhantomData<_> }
```

Bu yüzden `AnyEntity`/`AnyWeakEntity` üzerindeki bazı metotlar typed handle
üzerinde method resolution ile çağrılabilir; "owner sadece untyped tip"
yanılgısı buradan doğar. Ayrım `Owner::method -> dönüş tipi` çiftiyle yapılır,
ad tek başına yeterli değildir.

| Owner | Metot | Dönüş | Erişim |
|---|---|---|---|
| `Entity<T>` | `entity_id()` | `EntityId` | Inherent (`AnyEntity::entity_id` ile aynı değeri okur; inherent kazanır). |
| `Entity<T>` | `downgrade()` | `WeakEntity<T>` | Inherent; aynı adlı `AnyEntity::downgrade -> AnyWeakEntity` gölgelenir. |
| `Entity<T>` | `into_any()` | `AnyEntity` | Inherent; `self`'i tüketir. |
| `Entity<T>` | `read(&App)` | `&T` | Inherent. |
| `Entity<T>` | `read_with(cx, |&T, &App| ...)` | `R` | Inherent. |
| `Entity<T>` | `update(cx, |&mut T, &mut Context<T>| ...)` | `R` | Inherent. |
| `Entity<T>` | `update_in(visual_cx, |&mut T, &mut Window, &mut Context<T>| ...)` | `C::Result<R>` | Inherent. |
| `Entity<T>` | `as_mut(&mut cx)` | `GpuiBorrow<T>` | Inherent; drop'ta `cx.notify()`. |
| `Entity<T>` | `write(&mut cx, value)` | `()` | Inherent; state'i değiştirir ve notify eder. |
| `Entity<T>` deref | `entity_type()` | `TypeId` | Owner `AnyEntity`; Entity inherent karşılığı yoktur, deref ile çağrılır. |
| `Entity<T>` deref-only edge case | `downcast::<U>()` | `Result<Entity<U>, AnyEntity>` | Owner `AnyEntity::downcast(self)` — **`self`'i tüketir**. Auto-deref tüketen metoda dağıtmadığından `entity.downcast::<U>()` doğrudan derlenmez; `entity.into_any().downcast::<U>()` yaz. |
| `AnyEntity` | `entity_id()` | `EntityId` | Inherent. |
| `AnyEntity` | `entity_type()` | `TypeId` | Inherent. |
| `AnyEntity` | `downgrade()` | `AnyWeakEntity` | Inherent. |
| `AnyEntity` | `downcast::<U>()` | `Result<Entity<U>, AnyEntity>` | Inherent; `self`'i tüketir. |

`WeakEntity<T>` tarafı ad çakışmaları yüzünden ayrıca okunaklı tutulmalıdır;
inherent ile deref-only metotlar aynı isimle farklı imza taşır:

| Owner | Metot | Dönüş | Erişim |
|---|---|---|---|
| `WeakEntity<T>` | `upgrade()` | `Option<Entity<T>>` | Inherent; aynı adlı `AnyWeakEntity::upgrade -> Option<AnyEntity>` gölgelenir. |
| `WeakEntity<T>` | `update(cx, |&mut T, &mut Context<T>| ...)` | `Result<R>` | Inherent. |
| `WeakEntity<T>` | `update_in(cx, |&mut T, &mut Window, &mut Context<T>| ...)` | `Result<R>` | Inherent; entity'nin son render edildiği pencereyi `App::with_window` ile bulur. |
| `WeakEntity<T>` | `read_with(cx, |&T, &App| ...)` | `Result<R>` | Inherent. |
| `WeakEntity<T>` | `new_invalid()` | `Self` | Inherent; aynı adlı `AnyWeakEntity::new_invalid -> AnyWeakEntity` gölgelenir. |
| `WeakEntity<T>` deref | `entity_id()` | `EntityId` | Owner `AnyWeakEntity`; deref ile çağrılır. |
| `WeakEntity<T>` deref | `is_upgradable()` | `bool` | Owner `AnyWeakEntity`; deref ile çağrılır. |
| `WeakEntity<T>` deref | `assert_released()` | `()` | Owner `AnyWeakEntity`; sadece `test`/`leak-detection`. |
| `AnyWeakEntity` | `entity_id()` | `EntityId` | Inherent. |
| `AnyWeakEntity` | `is_upgradable()` | `bool` | Inherent. |
| `AnyWeakEntity` | `upgrade()` | `Option<AnyEntity>` | Inherent — typed handle üzerinden çağrılırsa `WeakEntity::upgrade` kazanır. |
| `AnyWeakEntity` | `new_invalid()` | `Self` | Inherent. |
| `AnyWeakEntity` | `assert_released()` | `()` | Inherent; `test`/`leak-detection`. |

Pratik sonuç: `weak.entity_id()` çağrısı typed handle'da deref üzerinden
`AnyWeakEntity::entity_id`'a iner; ama `weak.upgrade()` typed kazanır ve
`Option<Entity<T>>` döner. Aynı kod parçasında her ikisi de görünür, oysa
ownership'leri farklıdır; ayrımı `Owner::method -> dönüş` çiftiyle yap.

#### AnyView, AnyWeakView ve EmptyView

`AnyView`, `Render` implement eden bir `Entity<V>` için element olarak
kullanılabilen type-erased view handle'dır:

```rust
let view: AnyView = pane.clone().into();
div().child(view.clone());
```

Önemli metotlar:

- `AnyView::from(entity)` veya `entity.into_element()` typed view'i type-erased
  element yapar.
- `any_view.downcast::<T>() -> Result<Entity<T>, AnyView>` typed handle'a geri
  dönmek içindir.
- `any_view.downgrade() -> AnyWeakView`; `AnyWeakView::upgrade() -> Option<AnyView>`.
- `any_view.entity_id()` ve `entity_type()` debug/registry mantığı için kullanılır.
- `EmptyView` hiçbir şey render etmeyen `Render` view'idir.

`AnyView::cached(style_refinement)` pahalı child view render'ını cache'lemek için
kullanılır:

```rust
div().child(
    AnyView::from(pane.clone())
        .cached(StyleRefinement::default().v_flex().size_full()),
)
```

Cache, view `cx.notify()` çağırmadıysa önceki layout/prepaint/paint aralıklarını
yeniden kullanır. `Window::refresh()` çağrısı cache'i bypass eder; inspector
picking açıkken de hitbox'ların eksiksiz olması için caching devre dışı kalır.
Cache key bounds, aktif `ContentMask` ve aktif `TextStyle` içerir. Bu nedenle
`cached(...)` için verdiğin root `StyleRefinement` view'in gerçek root layout
stiliyle uyumlu olmalıdır; yanlış refinement layout'u bayat veya hatalı gösterir.

#### Callback Adaptörleri

Çoğu element callback'i view state almaz:

```rust
Fn(&Event, &mut Window, &mut App)
```

State'e dönmek için doğru adaptörü seç:

- `cx.listener(|this, event, window, cx| ...)`:
  `Fn(&Event, &mut Window, &mut App)` üretir. İçeride current entity'nin
  `WeakEntity` handle'ı kullanılır; entity düşmüşse callback sessizce no-op olur.
- `cx.processor(|this, event, window, cx| -> R { ... })`:
  `Fn(Event, &mut Window, &mut App) -> R` üretir. Event'i sahiplenir ve dönüş
  değeri gerekirken kullanılır.
- `window.listener_for(&entity, |state, event, window, cx| ...)`:
  current `Context<T>` dışında, elde typed `Entity<T>` varken listener üretir.
- `window.handler_for(&entity, |state, window, cx| ...)`:
  event parametresi olmayan `Fn(&mut Window, &mut App)` handler üretir.

`cx.listener` dışındaki adaptörleri reusable component veya window-level helper
yazarken kullan. Handler içinde `cx.notify()` çağrısı yine state değişimine göre
senin sorumluluğundadır.

#### FocusHandle Zayıf Handle ve Dispatch

`FocusHandle` yalnız focus vermek için değildir:

- `focus_handle.downgrade() -> WeakFocusHandle`
- `WeakFocusHandle::upgrade() -> Option<FocusHandle>`
- `focus_handle.contains(&other, window) -> bool`: son rendered frame'deki focus
  ağaç ilişkisini kontrol eder.
- `focus_handle.dispatch_action(&action, window, cx)`: dispatch'i focused node
  yerine belirli focus handle'ın node'undan başlatır.

`contains_focused(window, cx)` "ben veya descendant focused mı?", `within_focused`
ise "ben focused node'un içinde miyim?" sorusunu cevaplar. `within_focused`
imzasında `cx: &mut App` vardır; çünkü dispatch/focus path hesaplarında app
state'iyle çalışır.

#### ElementId Tam Varyantları

Stabil element state için kullanılan `ElementId` varyantları:

- `View(EntityId)`, `Integer(u64)`, `Name(SharedString)`, `Uuid(Uuid)`
- `FocusHandle(FocusId)`, `NamedInteger(SharedString, u64)`, `Path(Arc<Path>)`
- `CodeLocation(Location<'static>)`, `NamedChild(Arc<ElementId>, SharedString)`
- `OpaqueId([u8; 20])`

`ElementId::named_usize(name, usize)` `NamedInteger` üretir. Debug selector veya
string tabanlı ID gerektiğinde `Name`; liste satırı gibi tekrar eden yapılarda
`NamedInteger`; text anchor gibi byte-level kimliklerde `OpaqueId` kullanılır.

---

---

