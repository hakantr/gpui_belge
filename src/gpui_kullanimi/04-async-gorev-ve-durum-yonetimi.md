# Async, Görev ve Durum Yönetimi

---

## Async İşler

GPUI'de async işler, bağlam üzerinden spawn edilen `Task` handle'larıyla
yönetilir. Üç temel kalıp vardır: foreground task, current entity'ye bağlı
task ve pencereyi de hesaba katan task. Foreground task UI thread'i ile aynı
executor'da çalışır; diğer iki kalıp entity ya da pencere yaşam döngüsünü
hesaba katar. Her biri biraz farklı bir closure imzasıyla yazılır.

**Foreground task.** En sade biçimdir; entity veya pencere bağlamı gerektirmez:

```rust
cx.spawn(async move |cx| {
    cx.update(|cx| {
        // App state güncelle
    })
})
.detach();
```

**Entity'ye bağlı task.** Closure başlangıçta current entity'nin
`WeakEntity` handle'ını verir. Böylece async beklemeler sırasında entity'nin
düşmüş olma ihtimali `Result` üzerinden görünür hale gelir:

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

**Pencereye bağlı task.** Pencere context'ini de async tarafa taşır; `Window`
metotları `cx.update_in` ile birlikte kullanılabilir:

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
`AsyncFnOnce(WeakEntity<T>, &mut AsyncApp/AsyncWindowContext)` ister; bu
nedenle closure `async move |this, cx| { ... }` biçiminde yazılır. Closure'ın
gövdesi `Result` döndürüyorsa derleyicinin tipini çıkarması için ya
örnekteki gibi `Ok::<(), anyhow::Error>(())` ile son ifade tip-açıklanmalı, ya
da en üstte `let _: Result<_, anyhow::Error> = ...` kalıbı kullanılmalıdır.

`window.to_async(cx)` doğrudan bir `AsyncWindowContext` üretir. Callback dışına
taşınacak pencere bağlı async yardımcılar yazılırken bu yol tercih edilir.
Günlük entity/view kodunda ise `cx.spawn_in(window, ...)` daha güvenli ve
okunaklı bir sarmalayıcıdır.

**Background thread.** CPU-yoğun iş foreground executor'ı bloklamasın diye
ayrı bir executor'a verilir. Sonuç hazır olduğunda foreground task ile UI'ya
geri taşınır:

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

**Testlerde zamanlayıcı.** Test ortamında zamanın kontrol altında olması için
GPUI'nın kendi timer'ı kullanılır:

- GPUI testlerinde `smol::Timer::after(...)` yerine
  `cx.background_executor().timer(duration).await` çağrılır. Bu sayede zamanı
  manuel ilerletme ve `run_until_parked()` ile senkron çalışma mümkün olur.
- `run_until_parked()` ile uyum sağlandığında GPUI executor timer'ı tercih
  edilir; bu çift, deterministik test akışının temelidir.

## Executor, Priority, Timeout ve Test Zamanı

GPUI'da iş iki executor arasında bölünür. Foreground executor UI thread
üzerinde çalışır; background executor ise scheduler ve thread pool üzerinde
çalışır. Bu ayrım yalnızca performans için değildir. Bir `await` noktasından
sonra hangi context'in tutulabileceğini de belirler. Foreground tarafta `App`
veya `Window`'a güvenli dönüş noktaları vardır; background tarafta bunlar
yoktur.

**Temel tipler.** Sistem aşağıdaki parçalardan oluşur:

- `BackgroundExecutor`: ana metotları `spawn`, `spawn_with_priority`, `timer`,
  `scoped`, `scoped_priority`'dir; test desteğiyle birlikte `advance_clock`,
  `run_until_parked` ve `simulate_random_delay` da kullanılabilir.
- `ForegroundExecutor`: future'ları main thread'e koyar; `spawn`,
  `spawn_with_priority`, ek olarak senkron köprü için `block_on` ve
  `block_with_timeout` sağlar.
- `Priority`: dört seviyesi vardır — `RealtimeAudio`, `High`, `Medium`, `Low`.
  Realtime ayrı bir thread ister; UI dışı audio gibi çok sınırlı işler dışında
  kullanılması önerilmez.
- `Task<T>`: await edilebilir handle'dır. Drop edildiğinde içindeki iş iptal
  olur; tamamlanmasının istendiği durumlarda await edilir, struct alanında
  saklanır veya `detach()` / `detach_and_log_err(cx)` ile bırakılır.
- `FutureExt::with_timeout(duration, executor)`: bir future'ı executor timer'ı
  ile yarıştırır ve sonucu `Result<T, Timeout>` olarak verir.

**Timeout örneği.** Tipik bir kullanım, uzun süren bir background işine
süre sınırı koymaktır:

```rust
let executor = cx.background_executor().clone();
let task = cx.background_spawn(async move {
    parse_large_file(path).await
});

let result = task
    .with_timeout(Duration::from_secs(5), &executor)
    .await?;
```

**Foreground priority.** Aciliyet seviyeleri foreground tarafta polling sırasını
belirler; öncelikli işler executor kuyruğunda öne geçer:

```rust
cx.spawn_with_priority(Priority::High, async move |cx| {
    cx.update(|cx| {
        cx.refresh_windows();
    });
})
.detach();
```

**Update semantiği.** `AsyncApp::update(|cx| ...)` doğrudan `R` döndürür;
entity'lerin aksine fallible değildir, dolayısıyla `?` ile yayılması
gerekmez. Pencere içi async çalışmada
`AsyncWindowContext::update(|window, cx| ...) -> Result<R>` veya
`Entity::update(cx, ...)` fallible varyantları kullanılır.

**Async context convenience yüzeyi.** Async bağlamlar üzerinde tekrar tekrar
ihtiyaç duyulan birkaç kestirme metot vardır:

- `AsyncApp::refresh()` tüm pencereler için redraw planlar; async akıştan
  redraw tetiklemek için `update(|cx| cx.refresh_windows())` yazmaya gerek
  bırakmaz.
- `AsyncApp::background_executor()` ve `foreground_executor()` executor
  handle'larını döndürür. Timer/timeout veya iç içe spawn gerektiğinde
  buradan alınır.
- `AsyncApp::subscribe(&entity, ...)`, `open_window(options, ...)`,
  `spawn(...)`, `has_global::<G>()`, `read_global`, `try_read_global`,
  `read_default_global`, `update_global` ve `on_drop(&weak, ...)` await
  edilebilir app task'larında aynı foreground state'e güvenli dönüş
  noktalarıdır.
- `AsyncWindowContext::window_handle()` bağlı pencereyi verir.
  `update(|window, cx| ...)` yalnızca window state'ini güncellerken,
  `update_root(|root, window, cx| ...)` root `AnyView` de gerektiğinde
  kullanılır.
- `AsyncWindowContext::on_next_frame(...)`, `read_global`, `update_global`,
  `spawn(...)` ve `prompt(...)` pencereye bağlı async işlerde "pencere
  kapanmış olabilir" durumunu `Result` veya yedek receiver üzerinden
  yönetir.

**Entity ve window bağlı priority spawn.** Öncelikli işlerin daha tipli
sürümleri için de yardımcılar mevcuttur:

- `cx.spawn_in_with_priority(priority, window, async move |weak, cx| { ... })`
  current entity'nin `WeakEntity<T>` handle'ını ve `AsyncWindowContext`
  bağlamını verir.
- `window.spawn_with_priority(priority, cx, async move |cx| { ... })` pencere
  handle'ına bağlı ama entity'siz async iş için uygundur.
- Priority yalnızca foreground executor kuyruğunda polling önceliği sağlar;
  uzun CPU işi hâlâ `background_spawn` tarafına taşınmalıdır.

**Hazır değer.** Bir hesap sonucu zaten eldeyse ek bir `Task` açmadan doğrudan
`Task::ready` ile döndürülebilir. Bu, çağıran kodun imzasını her iki yolda da
`Task` olarak tutarlı bırakır:

```rust
fn cached_or_async(cached: Option<Data>, cx: &App) -> Task<anyhow::Result<Data>> {
    if let Some(data) = cached {
        Task::ready(Ok(data))
    } else {
        cx.background_spawn(async move { load_data().await })
    }
}
```

**Test zamanı.** Test ortamında zamanlama davranışını anlamak için birkaç
noktanın bilinmesi gerekir:

- `cx.background_executor().timer(duration).await` GPUI scheduler'a bağlıdır;
  `smol::Timer::after` ise GPUI `run_until_parked()` ile uyumsuz kalabilir,
  bu nedenle testlerde tercih edilmez.
- `advance_clock(duration)` yalnızca fake clock'u ilerletir; ilerletilen
  süreyle gelinen noktada hazır olan işleri çalıştırmak için ayrıca
  `run_until_parked()` çağrısı gereklidir.
- `allow_parking()` outstanding task varken parked olmayı testte bilerek
  kabul etmek için kullanılır; üretim akışlarına taşınması doğru
  değildir.
- `block_with_timeout` timeout olduğunda future'ı geri verir; bu davranış,
  işi iptal etmek veya daha sonra yeniden poll etmek konusunda kararı
  çağırana bırakır.
- `PriorityQueueSender<T>` / `PriorityQueueReceiver<T>` yalnızca
  Windows/Linux/wasm cfg'lerinde re-export edilir.
  `send(priority, item)`, `try_pop()`, `pop()`, `try_iter()` ve `iter()`
  metotları high/medium/low kuyruklarını ağırlıklı seçimle tüketir;
  `Priority::RealtimeAudio` bu kuyruğa girmez.

## Task, TaskExt ve Async Hata Yönetimi

`Task<T>` GPUI'ın temel async handle'ıdır. Yardımcı trait `TaskExt`
(`crates/gpui/src/executor.rs:33+`) `Task<Result<T, E>>` tipleri üzerine ek
metotlar bindirir:

```rust
pub trait TaskExt<T, E> {
    fn detach_and_log_err(self, cx: &App);
    fn detach_and_log_err_with_backtrace(self, cx: &App);
}
```

`detach_and_log_err` task'ı arka plana atar ve hata oluşması durumunda hatayı
`log::error!("...: {err}")` formatında loglar. `_with_backtrace` varyantı aynı
işi `{:?}` formatıyla yapar; bu sayede `anyhow::Error` gibi backtrace taşıyan
tipler tam stack ile loglanır.

**Pratik akış.** Tipik bir async UI iş parçası, network'tan veri çekmek ve
sonra view state'ini güncellemekten oluşur:

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

**Detach varyantları.** Task'ı bırakırken niyete göre üç farklı yardımcı
vardır:

- `task.detach()` — hata loglanmaz, sessizce yutulur. Yalnızca UI'da
  gösterilemeyen ve sonucu kaybolsa sorun olmayacak işler için
  uygundur.
- `task.detach_and_log_err(cx)` — standart akıştır; üretim kodunda hata
  yönetiminin varsayılan yolu olarak tercih edilir.
- `task.detach_and_prompt_err(prompt_label, window, cx, |err, window, cx| ...)`
  — workspace UI'sında kullanılan ek bir helper'dır (workspace crate'inde
  tanımlıdır); hatayı modal bir prompt'la kullanıcıya gösterir.

**Yazarken kararlar.** Bir task'ın imzada nasıl görüneceğini seçerken şu
pratik kurallar işe yarar:

- Async sonuç çağıran koda dönmeliyse metot `Task<R>` döndürmeli ve çağıran
  kod bunu await etmelidir. Sonucu struct alanında saklamak ise ileride alan
  drop edilirse iptal davranışı verir.
- Çağıran kod sonucu beklemeyecekse task'ı return etmek gereksizdir; doğrudan
  `detach_and_log_err(cx)` çağırmak niyeti daha açık gösterir.
- Result'ı log'a düşürmemek için manuel `if let Err(e) = task.await { ... }`
  yazmak gereksizdir; `detach_and_log_err` zaten `track_caller` ile log
  konumunu kayda alır.

**Tuzaklar.** Bu API'lerle ilgili sık yapılan hatalar şunlardır:

- `Result` tipinin `E` argümanı `Display + Debug` istemelidir; `anyhow::Error`
  ve standart custom error tipleri otomatik uyar.
- Task'lar `Vec<Task<()>>` içinde toplandığında drop sırası sürpriz olabilir;
  iptalin amaçlanmadığı tipik akışlarda `detach()` daha açık bir niyet bildirir.
- `cx.spawn_in(window, ...)` Window düştüğünde task'ı otomatik iptal etmez;
  `WeakEntity` üzerinden `update`/`update_in` çağrısı `Result` döndüğünden bu
  dönüş erken çıkış sinyali olarak ele alınmalıdır.

## Global State, Observe ve Event

GPUI'da uygulama genelindeki paylaşılan durum üç ana mekanizmayla yönetilir:
global state, observe (durum değişimini dinlemek) ve event (tipli mesaj
yayma). Üçü de bağlam üzerinden çağrılır ve genellikle birlikte kullanılır.

**Global state.** Uygulama ömrü boyunca tek nüsha tutulan bir kaynak için
`Global` trait'i implement edilir ve `cx.set_global` ile yerleştirilir:

```rust
struct MyGlobal(State);
impl Global for MyGlobal {}

cx.set_global(MyGlobal(state));

cx.update_global::<MyGlobal, _>(|global, cx| {
    global.0.changed = true;
});

let value = cx.read_global::<MyGlobal, _>(|global, _| global.0.clone());
```

**Observe.** Bir entity'nin `cx.notify()` çağırması bütün gözlemcileri
tetikler. Tipik kullanım, derived state'i kaynağa bağlamaktır:

```rust
subscriptions.push(cx.observe(&other, |this, other, cx| {
    this.copy = other.read(cx).value;
    cx.notify();
}));
```

**Event.** Tipli mesaj yayma için entity `EventEmitter<E>` implement eder;
yayılan event abonelere ulaşır:

```rust
struct Saved;
impl EventEmitter<Saved> for Document {}

cx.emit(Saved);

subscriptions.push(cx.subscribe(&document, |this, document, _: &Saved, cx| {
    this.last_saved = Some(document.entity_id());
    cx.notify();
}));
```

**Pencere bazlı gözlem.** Pencerenin kendisine ait değişimler için ayrı bir
observer ailesi vardır; her biri ilgili pencere değişiminde tetiklenir:

- `cx.observe_window_bounds(window, ...)`
- `cx.observe_window_activation(window, ...)`
- `cx.observe_window_appearance(window, ...)`
- `cx.observe_button_layout_changed(window, ...)`
- `cx.observe_pending_input(window, ...)`
- `cx.observe_keystrokes(...)`

## Global State Yardımcıları ve `cx.defer`

`App` üzerinde bulunan global state yardımcıları rehberin farklı bölümlerinde
parça parça geçer; burada tek bir listede toplanır. Aynı kategori altında
"global'i değiştir" ve "effect cycle'ı yönet" başlıklarını birlikte ele almak
en sık sorulan iki konuyu yan yana getirir.

- `cx.set_global<T: Global>(value)` — var olanı ezer; yoksa kurar.
- `cx.global<T>() -> &T` — var olduğundan emin olunan çağrı noktalarında kullanılır;
  yoksa panic eder.
- `cx.global_mut<T>()` — aynısının mutable karşılığıdır.
- `cx.default_global<T: Default>() -> &mut T` — global yoksa default ile bir
  instance oluşturur, varsa mevcut global'i mutable verir.
- `cx.has_global<T>() -> bool` — okuma öncesi varlık kontrolü.
- `cx.try_global<T>() -> Option<&T>` — nullable okuma.
- `cx.update_global<T, R>(|g, cx| ...) -> R` — kapsamlı update.
- `cx.read_global<T, R>(|g, cx| ...) -> R` — kapsamlı read.
- `cx.remove_global<T>() -> T` — instance'ı geri alır; tekrar set edilmediği
  sürece global yok sayılır.
- `cx.observe_global<T>(|cx| ...) -> Subscription` — global her notify
  olduğunda callback'i tetikler.

**Effect cycle yönetimi.** GPUI içinde state değişimleri "effect cycle"
denilen turlar halinde işlenir; bir update'in içinden başka bir update başlatmak
yerine işleri ertelemek genellikle daha güvenlidir:

- `cx.defer(|cx| ...)` mevcut effect cycle bittiğinde çalışır. Reentrant
  update'leri kırmak veya entity'leri stack'e geri vermek için idealdir.
- `Context<T>::defer_in(window, |this, window, cx| ...)` aynı erteleme
  davranışının window-bound varyantıdır.
- `window.defer(cx, |window, cx| ...)` doğrudan window context'inden ertelemek
  için kullanılır.
- `window.refresh()` pencereyi bir sonraki frame'de redraw için işaretler.
- `cx.refresh_windows()` tüm pencereler için aynı işi yapar.

**Tuzaklar.** Global'ler ve defer kullanımında dikkat edilmesi gerekenler:

- `cx.global<T>()` ve `cx.global_mut<T>()` global yoksa panic eder; init
  kontrolünün yapılmadığı çağrı noktalarında `try_global` veya `has_global`
  tercih edilmelidir.
- `update_global` sırasında aynı global yeniden update edilirse panic verir;
  iç içe çağrılar varsa erteleme için `defer` güvenli yoldur.
- Subscription `detach()` edilmezse owner drop'ta iptal olur; uzun yaşaması
  gereken observer'lar bir struct alanında saklanmalıdır.

## Subscription Yaşam Döngüsü

`crates/gpui/src/subscription.rs`.

`Subscription` opaque bir tiptir; düşürüldüğünde içindeki callback kaydı silinir.
Bu davranış üç farklı kullanım desenine yol açar; aralarındaki seçim
abonelik kaydının ne kadar yaşaması gerektiğine bağlıdır:

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

**Subscription üreten yöntemler.** `Context<T>` üzerinde abonelik üreten temel
metotlar şunlardır:

- `cx.observe(entity, f)` — entity `cx.notify()` çağırdığında tetiklenir.
- `cx.subscribe(entity, f)` — `EventEmitter<E>` event'leri için.
- `cx.observe_global::<G>(f)` — global state değiştiğinde.
- `cx.observe_release(entity, f)` — entity drop edildiğinde.
- `cx.on_focus(handle, window, f)`, `cx.on_blur(...)`, `cx.on_focus_in(...)`,
  `cx.on_focus_lost(window, f)`. Descendant focus-out için düşük seviyeli
  `window.on_focus_out(handle, cx, f)` kullanılır.
- `cx.observe_window_bounds`, `cx.observe_window_activation`,
  `cx.observe_window_appearance`, `cx.observe_button_layout_changed`,
  `cx.observe_pending_input`, `cx.observe_keystrokes`.

**Tuzaklar.** Subscription kullanımında dikkat edilecek noktalar:

- `detach()` uzun yaşayan bir callback'i view ömründen koparır; view drop
  olduktan sonra callback hâlâ çalışıyorsa state erişimi için `WeakEntity`
  ile koruma şart olur.
- Birden çok abonelik birbirini etkiliyorsa drop sırasına davranış bağlamak
  hatalıdır; açık bir teardown metodu veya tek sahip struct kullanmak güvenli
  yoldur.
- `observe` callback'i içinden entity'yi update etmek panic verir; bunun
  yerine `cx.spawn(..)` ile async akışa taşınır veya `cx.defer(|cx| ...)`
  ile sonraki effect cycle'a ertelenir.

## Window-bound Observer, Release ve Focus Helper Desenleri

Standart `observe`, `subscribe` ve `on_release` callback'leri yalnızca `App`
veya `Context<T>` verir. Buna karşılık UI katmanında çoğu iş pencereye de
ihtiyaç duyduğu için GPUI aynı desenlerin pencere-bilinçli varyantlarını
ayrıca sağlar. Aşağıdaki başlıklar bu helper ailelerini ve aralarındaki seçimi
açar.

**Yeni entity gözleme.** Belirli bir tipin oluşturulduğu anda hook takmak
gerektiğinde `observe_new` kullanılır:

```rust
cx.observe_new(|workspace: &mut Workspace, window, cx| {
    if let Some(window) = window {
        workspace.install_window_hooks(window, cx);
    }
}).detach();
```

- `App::observe_new<T>(|state, Option<&mut Window>, &mut Context<T>| ...)`
  belirli türde bir entity oluşturulduğunda çalışır. Entity bir pencere içinde
  yaratıldıysa callback'e `Some(window)` gelir; headless ya da app-level
  yaratımda `None` gelebilir.
- Zed `zed.rs`, `toast_layer`, `theme_preview`, `telemetry_log`,
  `move_to_applications` gibi modüllerde workspace/project/editor yaratıldığında
  global hook takmak için bu deseni kullanır.
- Dönen `Subscription` saklanmalı ya da uygulama ömrü boyunca gerekiyorsa
  `detach()` edilmelidir.

**Window context'iyle observe/subscribe.** İçinde pencere context'i gerektiren
abonelikler ayrı bir yardımcı ailesiyle yapılır:

```rust
self._observe_active_pane = cx.observe_in(active_pane, window, |this, pane, window, cx| {
    this.sync_from_pane(&pane, window, cx);
});

self._subscription = cx.subscribe_in(&modal, window, |this, modal, event, window, cx| {
    this.handle_modal_event(modal, event, window, cx);
});
```

- `Context<T>::observe_in(&Entity<V>, window, |this, Entity<V>, window, cx| ...)`
  observed entity `cx.notify()` yaptığında current entity'yi pencere context'i
  eşliğinde update eder.
- `Context<T>::subscribe_in(&Entity<Emitter>, window, |this, emitter, event, window, cx| ...)`
  `EventEmitter` olaylarını window context'iyle işler.
- `Context<T>::observe_self(|this, cx| ...)` current entity `cx.notify()`
  yaptığında kendi üzerinde callback çalıştırır; türetilmiş ya da cache durumu
  tek noktada tutmak için kullanılabilir.
- `Context<T>::subscribe_self::<Evt>(|this, event, cx| ...)` current entity'nin
  kendi yaydığı event'i dinler. Bu desen dikkatli kullanılmalıdır; çoğu
  durumda event'i emit eden kod yolunda state'i doğrudan güncellemek daha
  açıktır.
- `Context<T>::observe_global_in::<G>(window, |this, window, cx| ...)` global
  state notify olduğunda current entity'yi pencere context'iyle update eder.
  Pencere geçici olarak update stack'inden alınmış veya kapanmışsa
  notification atlanır, observer canlı kalır.
- Bu API'ler `ensure_window(observer_id, window.handle.id)` çağırır;
  entity'nin hangi pencereye bağlı çalışacağını GPUI'a kaydeder. Aynı entity
  birden fazla pencerede kullanılacaksa hangi pencerenin bağlandığı bilinçli
  şekilde düşünülmelidir.

**Release gözleme.** Bir entity yok edilirken yapılacak temizlikler için
release callback'leri vardır:

- `App::observe_release(&entity, |state, cx| ...)` — entity'nin son güçlü
  handle'ı düştükten sonra, state drop edilmeden hemen önce çalışır.
- `App::observe_release_in(&entity, window, |state, window, cx| ...)` — aynı
  callback'i pencere handle'ı üzerinden çalıştırır; pencere kapanmışsa update
  başarısız olur ve callback atlanabilir.
- `Context<T>::on_release_in(window, |this, window, cx| ...)` — current
  entity'nin release'ini pencereyle gözler.
- `Context<T>::observe_release_in(&other, window, |this, other, window, cx| ...)`
  — başka bir entity release olurken observer entity'yi de update eder.

**Focus helper'ları.** Focus akışına müdahale için tipli yardımcılar mevcuttur:

- `cx.focus_view(&entity, window)` — `Focusable` implement eden başka bir
  view'i focus eder.
- `cx.focus_self(window)` — current entity `Focusable` ise focus'u kendine
  taşır. İçeride `window.defer(...)` kullanır; bu nedenle render ya da action
  callback içinde çağrıldığında focus değişimi effect cycle sonunda uygulanır.
- `window.disable_focus()` — pencereyi blur eder ve ardından `focus_enabled`
  bayrağını `false` yapar. Tersine çeviren bir API yoktur, yani çağrıldıktan
  sonra `focus_next/focus_prev/focus(...)` çağrıları sessizce no-op olur.
  Uygulama component'lerinde genellikle gerekmez; sadece pencere ömrü boyunca
  klavye focus'unu kalıcı kapatmak isteyen ender durumlarda kullanılır.

**Tuzaklar.** Bu helper aileleri kullanılırken gözden kaçabilecek noktalar:

- `observe_new` callback'inde `window`'un her zaman var olduğu varsayılmamalıdır;
  headless test ve app-level entity yaratımı `None` üretebilir.
- Window-bound subscription bir struct alanında saklanmazsa callback hemen
  düşer.
- `focus_self` ertelemeli çalıştığı için hemen sonraki satırda focus değişmiş
  gibi okumak yanıltıcıdır; sonucu sonraki effect veya frame akışında gözlemek
  gerekir.

## Entity Reservation ve Çift Yönlü Referans

`crates/gpui/src/app/async_context.rs:43+` ve
`app.rs::reserve_entity`/`insert_entity`.

Bazen bir entity oluşturulurken başka bir entity'nin kimliğini veya zayıf
handle'ını önceden bilmek gerekir; en tipik örnek `Workspace` ve `Pane` ikilisidir.
Bunu kuvvetli referans döngüsü kurmadan yapmak için `Reservation` deseni
mevcuttur. Önce kimlik rezerve edilir, ardından entity bu rezervasyona
yerleştirilir:

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

**`Reservation<T>` yüzeyi.** Rezervasyon nesnesi ile iki temel iş yapılır:

- `entity_id()` — entity henüz oluşturulmadan kimliğini verir.
- `cx.insert_entity(reservation, build)` — rezervasyonu doldurur ve
  `Entity<T>` döndürür.
- Doldurulmadan drop edildiğinde rezervasyon iptal olur.

**Deseni.** Çocuk entity ebeveyne `WeakEntity` ile bağlanır; rezervasyon
sayesinde ebeveyni oluştururken çocuğun handle'ının önceden bilinmesi gereken
durumlarda da döngü oluşmaz. Aynı API `AsyncApp` üzerinden de çağrılabilir.

**Tuzaklar.** Reservation kullanılırken karşılaşılabilecek hata desenleri:

- Reservation kullanmadan iki `Entity<T>` birbirine kuvvetli sahiplikle
  bağlandığında, hiçbir handle drop olmadığı için bellek sızıntısı oluşur.
- `insert_entity` çağrılmadan reservation drop edildiğinde entity hiç
  oluşturulmamış sayılır; daha önce `entity_id()` ile yayılmış olan kimlik
  artık geçersizdir.
- `cx.new` bir update'in ortasında rezervasyonu da doldurabilir; reentrant
  update yasakları reservation için de aynen geçerlidir.

## Entity Release, Cleanup ve Leak Detection

Entity handle'ları ref-count mantığıyla yaşar; son güçlü `Entity<T>` handle'ı
düştüğünde entity release edilir. `WeakEntity<T>` ise bu davranışı engellemez,
yalnızca canlıyken zayıf erişim sağlar.

**Cleanup API'leri.** Release anında yapılacak işler için birkaç farklı
callback formu vardır:

- `cx.on_release(|this, cx| ...)` — mevcut entity release edilirken çalışır.
- `App::observe_release(&entity, |entity, cx| ...)` — app context'inden başka
  bir entity'nin release'ini izler.
- `Context<T>::observe_release(&entity, |this, entity, cx| ...)` — view state
  ile birlikte başka bir entity'nin release'ini izler.
- `window.observe_release(&entity, cx, |entity, window, cx| ...)` — release
  sırasında window context gerektiğinde kullanılır.
- `cx.on_drop(...)` / `AsyncApp::on_drop(...)` — Rust scope drop'unda entity
  update etmek için `Deferred` callback üretir; entity zaten düşmüşse update
  başarısız olabilir.

**Örnek.** Cache release'ini gözlemleyen bir view tipik bir desendir:

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

**Leak kontrolü.** Test ve feature bayrağı altında entity sızıntısı izlenebilir:

```rust
let snapshot = cx.leak_detector_snapshot();
// Test body.
cx.assert_no_new_leaks(&snapshot);
```

**Tuzaklar.** Cleanup ve release çalışmasında dikkat edilmesi gerekenler:

- Subscription saklanmadığında hemen drop olur ve listener iptal edilir.
- Karşılıklı `Entity<T>` alanları cycle üretir; bir tarafın `WeakEntity<T>`
  olması gereklidir.
- Release callback'i içinde uzun async iş başlatılacaksa entity state'in
  kapanmakta olduğu varsayılmalı; gerekli veri callback başında kopyalanmalıdır.
- `WeakEntity::update/read_with` her zaman `Result` döndürür; entity düşmüş
  olabileceği için hata görünür biçimde ele alınmalıdır.

## Entity Type Erasure, Callback Adaptörleri ve View Cache

Bu bölüm GPUI çekirdeğinde public olan ama günlük kullanımda kolay atlanan
küçük API yüzeylerini toplar. Entity'nin tipli/untyped varyantları, view cache
mekanizması, callback adaptörleri ve düşük seviyeli kimlik tipleri burada ele
alınır.

#### Entity ve WeakEntity Tam Yüzeyi

`Entity<T>` güçlü handle'dır ve şu metotları sağlar:

- `entity.entity_id() -> EntityId`
- `entity.downgrade() -> WeakEntity<T>`
- `entity.into_any() -> AnyEntity`
- `entity.read(cx: &App) -> &T`
- `entity.read_with(cx, |state, cx| ...) -> R`
- `entity.update(cx, |state, cx| ...) -> R`
- `entity.update_in(visual_cx, |state, window, cx| ...) -> C::Result<R>`
- `entity.as_mut(cx) -> GpuiBorrow<T>` — mutable borrow verir; borrow drop
  olurken entity notify edilir.
- `entity.write(cx, value)` — state'i komple değiştirir ve `cx.notify()`
  çağırır.

`Context<T>` current entity için aynı kimlik ve handle yüzeyini sağlar:

- `cx.entity_id() -> EntityId`
- `cx.entity() -> Entity<T>` — current entity hâlâ canlı olmak zorunda olduğu
  için strong handle döndürür.
- `cx.weak_entity() -> WeakEntity<T>` — async task, listener veya döngüsel
  sahiplik riski olan alanlarda saklanacak handle budur.

**Kimlik dönüşümleri.** GPUI çalışma zamanı kimlikleri `u64` olarak dışarı
verilebilir:

- `EntityId::as_u64()` ve `EntityId::as_non_zero_u64()` FFI, telemetry veya
  debug map anahtarı gibi tipli id sınırının dışına çıkılan yerlerde kullanılır.
- `WindowId::as_u64()` aynı işi pencere kimliği için yapar. Bu değerler
  domain id'si veya kalıcı workspace serialization anahtarı olarak
  kullanılmamalıdır; GPUI çalışma zamanı kimliği olmaları kalıcılık garantisi
  vermez.

`WeakEntity<T>` zayıf handle'dır:

- `weak.upgrade() -> Option<Entity<T>>`
- `weak.update(cx, |state, cx| ...) -> Result<R>`
- `weak.read_with(cx, |state, cx| ...) -> Result<R>`
- `weak.update_in(cx, |state, window, cx| ...) -> Result<R>` — entity'nin
  current window'ını `App::with_window(entity_id, ...)` üzerinden bulur;
  entity düşmüşse veya current window yoksa hata döner.
- `WeakEntity::new_invalid()` hiçbir zaman upgrade edilemeyen sentinel handle
  üretir; opsiyon yerine "geçersiz ama tipli handle" gereken yerlerde
  kullanılır.

`AnyEntity` ve `AnyWeakEntity` heterojen koleksiyonlar içindir:

- `AnyEntity::{entity_id, entity_type, downgrade, downcast::<T>}`
- `AnyWeakEntity::{entity_id, is_upgradable, upgrade, new_invalid}`
- `AnyWeakEntity::assert_released()` yalnız `test`/`leak-detection` feature'ı
  altında vardır; güçlü handle sızıntısını yakalamak için kullanılır.

**Kural.** Plugin, dock veya workspace gibi heterojen koleksiyon sınırı yoksa
tipli `Entity<T>`/`WeakEntity<T>` tercih edilir. `AnyEntity` downcast
zorunluluğu getirir; yanlış tipte `downcast::<T>()` çağrısı entity'yi
`Err(AnyEntity)` olarak geri verir.

##### Deref ile gizlenmiş yüzey (tipli handle üzerinden untyped metot)

`Entity<T>` ve `WeakEntity<T>` `#[derive(Deref, DerefMut)]` ile içlerindeki
untyped handle'a deref eder
(`crates/gpui/src/app/entity_map.rs:413` ve `:739`):

```rust
#[derive(Deref, DerefMut)]
pub struct Entity<T>     { any_entity: AnyEntity,         entity_type: PhantomData<_> }
#[derive(Deref, DerefMut)]
pub struct WeakEntity<T> { any_entity: AnyWeakEntity,     entity_type: PhantomData<_> }
```

Bu yüzden `AnyEntity` ve `AnyWeakEntity` üzerindeki bazı metotlar tipli
handle'da method resolution ile çağrılabilir. "Owner yalnız untyped tiptir"
yanılgısı buradan doğar. Doğru ayrım `Owner::method -> dönüş tipi` çiftiyle
yapılır; metot adı tek başına yeterli değildir.

| Owner | Metot | Dönüş | Erişim |
|---|---|---|---|
| `Entity<T>` | `entity_id()` | `EntityId` | Inherent (`AnyEntity::entity_id` ile aynı değeri okur; inherent kazanır). |
| `Entity<T>` | `downgrade()` | `WeakEntity<T>` | Inherent; aynı adlı `AnyEntity::downgrade -> AnyWeakEntity` gölgelenir. |
| `Entity<T>` | `into_any()` | `AnyEntity` | Inherent; `self`'i tüketir. |
| `Entity<T>` | `read(&App)` | `&T` | Inherent. |
| `Entity<T>` | `read_with(cx, \|&T, &App\| ...)` | `R` | Inherent. |
| `Entity<T>` | `update(cx, \|&mut T, &mut Context<T>\| ...)` | `R` | Inherent. |
| `Entity<T>` | `update_in(visual_cx, \|&mut T, &mut Window, &mut Context<T>\| ...)` | `C::Result<R>` | Inherent. |
| `Entity<T>` | `as_mut(&mut cx)` | `GpuiBorrow<T>` | Inherent; drop'ta `cx.notify()`. |
| `Entity<T>` | `write(&mut cx, value)` | `()` | Inherent; state'i değiştirir ve notify eder. |
| `Entity<T>` deref | `entity_type()` | `TypeId` | Owner `AnyEntity`; Entity inherent karşılığı yoktur, deref ile çağrılır. |
| `Entity<T>` deref-only özel durum | `downcast::<U>()` | `Result<Entity<U>, AnyEntity>` | Owner `AnyEntity::downcast(self)` — **`self`'i tüketir**. Auto-deref tüketen metoda uygulanmadığı için `entity.downcast::<U>()` doğrudan derlenmez; `entity.into_any().downcast::<U>()` yazılmalıdır. |
| `AnyEntity` | `entity_id()` | `EntityId` | Inherent. |
| `AnyEntity` | `entity_type()` | `TypeId` | Inherent. |
| `AnyEntity` | `downgrade()` | `AnyWeakEntity` | Inherent. |
| `AnyEntity` | `downcast::<U>()` | `Result<Entity<U>, AnyEntity>` | Inherent; `self`'i tüketir. |

`WeakEntity<T>` tarafında ad çakışmaları yüzünden tablo daha da dikkatli
okunmalıdır; inherent ve deref-only metotlar aynı isimle farklı imza taşır:

| Owner | Metot | Dönüş | Erişim |
|---|---|---|---|
| `WeakEntity<T>` | `upgrade()` | `Option<Entity<T>>` | Inherent; aynı adlı `AnyWeakEntity::upgrade -> Option<AnyEntity>` gölgelenir. |
| `WeakEntity<T>` | `update(cx, \|&mut T, &mut Context<T>\| ...)` | `Result<R>` | Inherent. |
| `WeakEntity<T>` | `update_in(cx, \|&mut T, &mut Window, &mut Context<T>\| ...)` | `Result<R>` | Inherent; entity'nin son render edildiği pencereyi `App::with_window` ile bulur. |
| `WeakEntity<T>` | `read_with(cx, \|&T, &App\| ...)` | `Result<R>` | Inherent. |
| `WeakEntity<T>` | `new_invalid()` | `Self` | Inherent; aynı adlı `AnyWeakEntity::new_invalid -> AnyWeakEntity` gölgelenir. |
| `WeakEntity<T>` deref | `entity_id()` | `EntityId` | Owner `AnyWeakEntity`; deref ile çağrılır. |
| `WeakEntity<T>` deref | `is_upgradable()` | `bool` | Owner `AnyWeakEntity`; deref ile çağrılır. |
| `WeakEntity<T>` deref | `assert_released()` | `()` | Owner `AnyWeakEntity`; sadece `test`/`leak-detection`. |
| `AnyWeakEntity` | `entity_id()` | `EntityId` | Inherent. |
| `AnyWeakEntity` | `is_upgradable()` | `bool` | Inherent. |
| `AnyWeakEntity` | `upgrade()` | `Option<AnyEntity>` | Inherent — typed handle üzerinden çağrılırsa `WeakEntity::upgrade` kazanır. |
| `AnyWeakEntity` | `new_invalid()` | `Self` | Inherent. |
| `AnyWeakEntity` | `assert_released()` | `()` | Inherent; `test`/`leak-detection`. |

**Pratik sonuç.** `weak.entity_id()` çağrısı tipli handle'da deref üzerinden
`AnyWeakEntity::entity_id` metoduna iner. Buna karşılık `weak.upgrade()`
çağrısında tipli metot kazanır ve sonuç `Option<Entity<T>>` olur. Aynı kod
parçasında ikisi yan yana görünebilir ama sahipleri farklıdır; ayrım yine
`Owner::method -> dönüş` çiftiyle yapılır.

#### AnyView, AnyWeakView ve EmptyView

`AnyView`, `Render` implement eden bir `Entity<V>` için element olarak
kullanılabilen type-erased view handle'dır. Bu sayede farklı view tipleri
tek bir element yuvasına yerleştirilebilir:

```rust
let view: AnyView = pane.clone().into();
div().child(view.clone());
```

**Önemli metotlar.** Type-erased view ile çalışırken sık kullanılan API'ler
şunlardır:

- `AnyView::from(entity)` veya `entity.into_element()` — tipli view'i
  type-erased element haline getirir.
- `any_view.downcast::<T>() -> Result<Entity<T>, AnyView>` — tipli handle'a
  geri dönmek için kullanılır.
- `any_view.downgrade() -> AnyWeakView` ve
  `AnyWeakView::upgrade() -> Option<AnyView>` — zayıf handle dönüşümleri.
- `any_view.entity_id()` ve `entity_type()` — debug ve registry mantığında
  kullanılır.
- `EmptyView` — hiçbir şey render etmeyen `Render` view'idir; placeholder
  amaçlı kullanılır.

**Cached view.** `AnyView::cached(style_refinement)` pahalı bir child view'in
render'ını cache'lemek için kullanılır:

```rust
div().child(
    AnyView::from(pane.clone())
        .cached(StyleRefinement::default().v_flex().size_full()),
)
```

Cache, view `cx.notify()` çağırmadığı sürece önceki layout/prepaint/paint
aralıklarını yeniden kullanır. `Window::refresh()` çağrısı cache'i bypass
eder; inspector picking açıkken de hitbox'ların eksiksiz olabilmesi için
cache devre dışı kalır. Cache anahtarı (key) bounds, aktif `ContentMask` ve
aktif `TextStyle`'ı içerir. Bu nedenle `cached(...)` çağrısında verilen root
`StyleRefinement` view'in gerçek root layout stiliyle uyumlu olmalıdır; yanlış
refinement layout'u bayat veya hatalı gösterir.

#### Callback Adaptörleri

Çoğu element callback'i view state'ini doğrudan almaz:

```rust
Fn(&Event, &mut Window, &mut App)
```

Callback'ten view state'ine geri dönmek için uygun adaptör seçilir:

- `cx.listener(|this, event, window, cx| ...)` —
  `Fn(&Event, &mut Window, &mut App)` üretir. İçeride current entity'nin
  `WeakEntity` handle'ı kullanılır; entity düşmüşse callback sessizce no-op
  olur.
- `cx.processor(|this, event, window, cx| -> R { ... })` —
  `Fn(Event, &mut Window, &mut App) -> R` üretir. Event'i sahiplenir ve dönüş
  değeri gerektiğinde tercih edilir.
- `window.listener_for(&entity, |state, event, window, cx| ...)` — current
  `Context<T>` dışında, elde tipli `Entity<T>` varken listener üretir.
- `window.handler_for(&entity, |state, window, cx| ...)` — event parametresi
  olmayan `Fn(&mut Window, &mut App)` handler üretir.

`cx.listener` dışındaki adaptörler yeniden kullanılabilir component'ler veya
window seviyesindeki yardımcılar yazılırken devreye girer. Handler içinde
state değiştiğinde `cx.notify()` çağırmak yine çağıranın sorumluluğundadır;
adaptör bunu otomatik yapmaz.

#### FocusHandle Zayıf Handle ve Dispatch

`FocusHandle` yalnızca focus vermek için değildir; zayıf handle ve dispatch
kontrolü de sunar:

- `focus_handle.downgrade() -> WeakFocusHandle`
- `WeakFocusHandle::upgrade() -> Option<FocusHandle>`
- `focus_handle.contains(&other, window) -> bool` — son render edilen
  frame'deki focus ağacı ilişkisini kontrol eder.
- `focus_handle.dispatch_action(&action, window, cx)` — dispatch'i focused
  node yerine belirli bir focus handle'ın node'undan başlatır.

`contains_focused(window, cx)` "ben veya altımdaki bir node focused mu?"
sorusuna, `within_focused` ise "ben focused node'un içinde miyim?" sorusuna
cevap verir. `within_focused` imzasında `cx: &mut App` vardır; çünkü
dispatch/focus path hesaplarında app state'iyle çalışır.

#### ElementId Tam Varyantları

Kararlı (stabil) element state'i için kullanılan `ElementId` varyantları
şunlardır:

- `View(EntityId)`, `Integer(u64)`, `Name(SharedString)`, `Uuid(Uuid)`
- `FocusHandle(FocusId)`, `NamedInteger(SharedString, u64)`, `Path(Arc<Path>)`
- `CodeLocation(Location<'static>)`,
  `NamedChild(Arc<ElementId>, SharedString)`
- `OpaqueId([u8; 20])`

`ElementId::named_usize(name, usize)` `NamedInteger` üretir. Pratik seçim
şöyledir: debug selector veya string tabanlı ID gerektiğinde `Name`; liste
satırı gibi tekrar eden yapılarda `NamedInteger`; text anchor gibi byte-level
kimliklerde `OpaqueId` tercih edilir.

---
