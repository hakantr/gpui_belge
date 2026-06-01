# Async, Görev ve Durum Yönetimi

---

## Async İşler

![GPUI Async Mimari](assets/async-mimari.svg)

GPUI'de async işleri, bağlam üzerinden başlattığın `Task` handle'larıyla yönetirsin. Üç temel kalıp vardır: ön plan görevi, o anki entity'ye bağlı görev ve pencereyi de hesaba katan görev. Ön plan görevi UI iş parçacığı ile aynı çalıştırıcı üzerinde koşar; diğer iki kalıp entity ya da pencere yaşam döngüsünü hesaba katar. Her birini biraz farklı bir closure imzasıyla yazarsın.

**Ön plan görevi.** En sade biçimdir; entity veya pencere bağlamı gerektirmez:

```rust
cx.spawn(async move |cx| {
    cx.update(|cx| {
        // App verisini güncelle
    })
})
.detach();
```

**Entity'ye bağlı görev.** Closure başlangıçta o anki entity'nin `WeakEntity` handle'ını verir. Böylece async beklemeler sırasında entity'nin düşmüş olma ihtimali `Result` üzerinden görünür hale gelir:

```rust
cx.spawn(async move |gorunum, cx| {
    cx.background_executor().timer(Duration::from_millis(200)).await;
    gorunum.update(cx, |gorunum, cx| {
        gorunum.hazir_mi = true;
        cx.notify();
    })?;
    Ok::<(), anyhow::Error>(())
})
.detach_and_log_err(cx);
```

**Pencereye bağlı görev.** Pencere bağlamını da async tarafa taşır; `Window` metotlarını `cx.update_in` ile birlikte kullanabilirsin:

```rust
cx.spawn_in(window, async move |gorunum, cx| {
    gorunum.update_in(cx, |gorunum, window, cx| {
        window.activate_window();
        cx.notify();
    })?;
    Ok::<(), anyhow::Error>(())
})
.detach_and_log_err(cx);
```

`Context::spawn` ve `spawn_in` imzaları `AsyncFnOnce(WeakEntity<T>, &mut AsyncApp/AsyncWindowContext)` ister; bu nedenle closure'ı `async move |gorunum, cx| { ... }` biçiminde yazarsın. Closure'ın gövdesi `Result` döndürüyorsa derleyicinin tipini çıkarması için ya örnekteki gibi `Ok::<(), anyhow::Error>(())` ile son ifade tipini açıkça yazman, ya da en üstte `let _: Result<_, anyhow::Error> = ...` kalıbını kullanman gerekir.

`window.to_async(cx)` doğrudan bir `AsyncWindowContext` üretir. Geri çağrı dışına taşınacak pencereye bağlı async yardımcılar yazarken bu yolu tercih edersin. Günlük entity ve view kodunda ise `cx.spawn_in(window, ...)`, daha güvenli ve okunaklı bir sarmalayıcıdır.

**Arka plan iş parçacığı.** CPU yoğun işi, ön plan çalıştırıcısını bloklamasın diye ayrı bir çalıştırıcıya verirsin. Sonuç hazır olduğunda ön plan görevi ile UI'ya geri taşırsın:

```rust
let gorev = cx.background_spawn(async move {
    pahali_is().await
});

cx.spawn(async move |cx| {
    let sonuc = gorev.await;
    cx.update(|cx| {
        // sonucu UI'a taşı
    })
})
.detach();
```

**Testlerde zamanlayıcı.** Test ortamında zamanın kontrol altında olması için GPUI'nın kendi zamanlayıcısını kullanırsın:

- GPUI testlerinde `smol::Timer::after(...)` yerine `cx.background_executor().timer(duration).await` çağırırsın. Bu sayede zamanı elle ilerletme ve `run_until_parked()` ile senkron çalışma mümkün olur. `cx.background_executor().timer()` ile `run_until_parked()` birlikte deterministik test akışının temelini oluşturur.

## Çalıştırıcı, Öncelik, Timeout ve Test Zamanı

GPUI'da iş iki çalıştırıcı arasında bölünür. Ön plan çalıştırıcısı UI iş parçacığı üzerinde çalışır; arka plan çalıştırıcısı ise zamanlayıcı (`scheduler`) ve iş parçacığı havuzu (`thread pool`) üzerinde çalışır. Bu ayrım yalnızca başarım için değildir. Bir `await` noktasından sonra hangi bağlamın tutulabileceğini de belirler. Ön plan tarafında `App` veya `Window`'a güvenli dönüş noktaları vardır; arka plan tarafında bunlar yoktur.

**Temel tipler.** Sistem aşağıdaki parçalardan oluşur:

- `BackgroundExecutor`: ana metotları `spawn`, `spawn_with_priority`, `timer`, `scoped`, `scoped_priority` ve `is_main_thread`'dir; test desteğiyle birlikte `advance_clock`, `run_until_parked` ve `simulate_random_delay`'i de kullanabilirsin.
- `ForegroundExecutor`: future'ları ana iş parçacığına yerleştirir; `spawn`, `spawn_with_priority`, ek olarak senkron köprü için `block_on` ve `block_with_timeout` sağlar.
- `Priority`: dört seviyesi vardır — `RealtimeAudio`, `High`, `Medium`, `Low`. `RealtimeAudio` ayrı bir iş parçacığı ister; UI dışı ses gibi çok sınırlı işler dışında kullanman önerilmez.
- `Task<T>`: `await` edilebilir handle'dır. Değer elden çıktığında içindeki iş iptal olur; tamamlanmasını istersen ya `await` edersin, ya struct alanında saklarsın, ya da `detach()` / `detach_and_log_err(cx)` ile bırakırsın.
- `FutureExt::with_timeout(duration, executor)`: bir future'ı çalıştırıcının zamanlayıcısı ile yarıştırır ve sonucu `Result<T, Timeout>` olarak verir.

**Timeout örneği.** Tipik bir kullanım, uzun süren bir arka plan işine süre sınırı koymaktır:

```rust
let yurutucu = cx.background_executor().clone();
let gorev = cx.background_spawn(async move {
    buyuk_dosyayi_ayristir(yol).await
});

let sonuc = gorev
    .with_timeout(Duration::from_secs(5), &yurutucu)
    .await?;
```

**Ön plan önceliği.** Aciliyet seviyeleri ön plan tarafında yoklama (`polling`) sırasını belirler; öncelikli işler çalıştırıcı kuyruğunda öne geçer:

```rust
cx.spawn_with_priority(Priority::High, async move |cx| {
    cx.update(|cx| {
        cx.refresh_windows();
    });
})
.detach();
```

**Update anlamı.** `AsyncApp::update(|cx| ...)` doğrudan `R` döndürür; entity'lerin aksine başarısız olabilen bir çağrı değildir, o yüzden `?` ile yayman gerekmez. Pencere içi async çalışmada `AsyncWindowContext::update(|window, cx| ...) -> Result<R>` veya `Entity::update(cx, ...)` başarısız olabilen varyantlarını kullanırsın.

**Async bağlam kestirme yüzeyi.** Async bağlamlar üzerinde tekrar tekrar ihtiyaç duyacağın birkaç kestirme metot vardır:

- `AsyncApp::refresh()`, tüm pencereler için yeniden çizim planlar; async akıştan yeniden çizim tetiklemek için `update(|cx| cx.refresh_windows())` yazmana gerek bırakmaz.
- `AsyncApp::background_executor()` ve `foreground_executor()`, çalıştırıcı handle'larını döndürür. Zamanlayıcı, timeout veya iç içe `spawn` gerektiğinde buradan alırsın.
- `AsyncApp::subscribe(&entity, ...)`, `open_window(options, ...)`, `spawn(...)`, `has_global::<G>()`, `read_global`, `try_read_global`, `read_default_global`, `update_global` ve `on_drop(&weak, ...)`, `await` edilebilir app görevlerinde aynı ön plan verisine güvenli dönüş noktalarıdır.
- `AsyncWindowContext::window_handle()`, bağlı pencereyi verir. `update(|window, cx| ...)` yalnızca pencere verisini güncellerken, `update_root(|root, window, cx| ...)`'ı kök `AnyView` de gerektiğinde kullanırsın.
- `AsyncWindowContext::on_next_frame(...)`, `read_global`, `update_global`, `spawn(...)` ve `prompt(...)`, pencereye bağlı async işlerde "pencere kapanmış olabilir" durumunu `Result` veya yedek `receiver` üzerinden yönetir.

**Entity ve pencereye bağlı öncelikli spawn.** Öncelikli işlerin daha tipli sürümleri için de yardımcılar mevcuttur:

- `cx.spawn_in_with_priority(priority, window, async move |weak, cx| { ... })`, o anki entity'nin `WeakEntity<T>` handle'ını ve `AsyncWindowContext` bağlamını verir.
- `window.spawn_with_priority(priority, cx, async move |cx| { ... })`, pencere handle'ına bağlı ama entity'siz async iş için uygundur.
- Öncelik yalnızca ön plan çalıştırıcısının kuyruğunda yoklama önceliği sağlar; uzun CPU işini hâlâ `background_spawn` tarafına taşıman gerekir.

**Hazır değer.** Bir hesap sonucu zaten eldeyse ek bir `Task` açmadan doğrudan `Task::ready` ile döndürebilirsin. Bu, çağıran kodun imzasını her iki yolda da `Task` olarak tutarlı bırakır:

```rust
fn onbellekten_veya_async(onbellekteki: Option<Veri>, cx: &App) -> Task<anyhow::Result<Veri>> {
    if let Some(veri) = onbellekteki {
        Task::ready(Ok(veri))
    } else {
        cx.background_spawn(async move { veri_yukle().await })
    }
}
```

**Test zamanı.** Test ortamında zamanlama davranışını anlaman için birkaç noktayı bilmen gerekir:

- `cx.background_executor().timer(duration).await` GPUI zamanlayıcısına bağlıdır; `smol::Timer::after` ise GPUI `run_until_parked()` ile uyumsuz kalabilir, bu nedenle testlerde tercih edilmez.
- `advance_clock(duration)` yalnızca sahte saati (`fake clock`) ilerletir; ilerlettiğin süreyle gelinen noktada hazır olan işleri çalıştırmak için ayrıca `run_until_parked()` çağırman gerekir.
- `allow_parking()`'i, bekleyen görev varken `parked` olmayı testte bilerek kabul etmek için kullanırsın; üretim akışlarına taşıman doğru değildir.
- `block_with_timeout` zaman aşımı olduğunda future'ı geri verir; bu davranış, işi iptal etmek veya daha sonra yeniden yoklamak konusundaki kararı çağırana bırakır.
- `PriorityQueueSender<T>` / `PriorityQueueReceiver<T>` yalnızca Windows, Linux ve wasm `cfg`'lerinde yeniden dışa aktarılır. `send(priority, item)`, `spin_send(priority, item)`, `try_pop()`, `spin_try_pop()`, `pop()`, `try_iter()` ve `iter()` metotları high, medium ve low kuyruklarını ağırlıklı seçimle tüketir; `Priority::RealtimeAudio` bu kuyruğa girmez. `spin_send` ve `spin_try_pop`, executor'ın kilitsiz hızlı yolunda kısa süreli dönerek kuyruk erişimi denediği için sıradan uygulama mesajlaşmasında değil scheduler/platform sınırında anlamlıdır.

**Executor tam yüzeyi.** `BackgroundExecutor` ve `ForegroundExecutor` aynı scheduler ailesini sarsalar da kullanım sınırları farklıdır:

- `BackgroundExecutor::new(dispatcher)` ve `ForegroundExecutor::new(dispatcher)`, platform veya test koşumu kurarken kullanılır; normal uygulama içinde çalıştırıcıyı `cx.background_executor()` ve `cx.foreground_executor()` ile alırsın.
- `BackgroundExecutor::spawn(...)` ve `spawn_with_priority(...)`, `Send + 'static` future ister; CPU, IO ve timer işleri için kullanılır. `Priority::RealtimeAudio` özel ses iş parçacığına iner, sıradan UI işi için yanlış tercihtir.
- `ForegroundExecutor::spawn(...)` ana iş parçacığında çalışır; `spawn_with_priority(...)` imzayı korur ama ön plan işleri sıralı çalıştığı için önceliği pratikte yok sayar.
- `BackgroundExecutor::scoped(...)` ve `scoped_priority(...)`, aynı kapsamda başlattığın işleri bekler; `Scope::spawn(...)` ödünç veriyle çalışan kısa ömürlü işleri güvenli biçimde toplar. Uzun yaşayan UI state'i güncellemek için `Context::spawn` veya `cx.background_spawn` daha okunaklıdır.
- `BackgroundExecutor::now()` ve `timer(duration)` test saatine bağlıdır; deterministik testlerde `std::time::Instant::now()` ve `smol::Timer` yerine bunları kullanırsın.
- `BackgroundExecutor::num_cpus()`, testte `set_num_cpus(...)` ile ezilebilir. İş bölme algoritması gerçek makine çekirdeğine bağımlı olmamalıysa testte bu değeri sabitlersin.
- `BackgroundExecutor::is_main_thread()`, alttaki `PlatformDispatcher` üzerinden mevcut thread'in UI ana thread'i olup olmadığını söyler. Bu kontrolü UI state'ine erişim izni gibi kullanmazsın; UI verisine dönmek için yine `AsyncApp::update`, `AsyncWindowContext::update`, `Context::spawn` veya `Window::spawn` sınırlarından geçersin.
- `scheduler_executor()` ve `dispatcher()` ham scheduler/platform handle'larına iner. Bunlar Zed'in alt crate'leri veya platform portları içindir; uygulama özellikleri bu handle'ları saklamamalıdır.

Test özelliği açıkken `BackgroundExecutor::simulate_random_delay()`, `advance_clock(...)`, `tick()`, `run_until_parked()`, `allow_parking()`, `forbid_parking()`, `set_block_on_ticks(...)`, `rng()` ve `set_num_cpus(...)` eklenir. Bunlar üretim zamanlayıcı davranışını değiştirme aracı değildir; testte olası yarışları ortaya çıkarmak, zamanı ilerletmek ve park davranışını bilinçli şekilde kabul etmek için kullanılır.

**Ön plan bloklama köprüleri.** `ForegroundExecutor::block_test(...)` yalnız GPUI test makrosunun async test gövdesini sürmesi içindir. `block_on(...)` ve `block_with_timeout(...)` senkron koddan future beklemek için kullanılabilir; UI event handler içinde uzun future'ı bloklamak pencereyi dondurur. Timeout sonucunda future geri döndüğü için çağıran taraf işi iptal mi edecek, tekrar mı sürecek açık karar vermelidir.

**PriorityQueue hata ve iterator tipleri.** `SendError<T>` gönderilecek öğeyi geri taşır; alıcı yoksa veri kaybolmadan çağırana döner. `RecvError` tüm göndericiler düştüğünde alıcının daha fazla item beklememesi gerektiğini gösterir. `TryIter<T>` mevcut kuyruk boşalınca biter; `Iter<T>` yeni item bekleyebilir. Bu kuyruklar executor altyapısı ve platform koşulları için yararlıdır; uygulama içi sıradan mesajlaşmada önce daha açık bir kanal veya `Task` akışı düşünürsün.

**PlatformScheduler.** `PlatformScheduler::new(dispatcher)` ve `allocate_session_id()` platform dispatcher'ını scheduler crate'ine bağlayan iç katmandır. Dışarıdan görünür olsa bile uygulama kodu için hedef API değildir; bir future başlatmak istiyorsan `BackgroundExecutor`, `ForegroundExecutor`, `App::spawn`, `Context::spawn` veya `Window::spawn` yüzeylerinden birini seçersin.

## Task, TaskExt ve Async Hata Yönetimi

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `TaskExt` | Trait üyeleri | `detach_and_log_err`, `detach_and_log_err_with_backtrace` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


`Task<T>`, GPUI'ın scheduler katmanından yeniden dışa aktardığı ve `await` edilebilen temel async handle'dır. İç yapısı uygulama kodu için önemli değildir; önemli olan sahiplik davranışıdır: `Task` saklarsan iş yaşamaya devam eder, elden çıkarırsan iptal olur, bilinçli şekilde bağımsız bırakacaksan `detach` ailesini kullanırsın. Yardımcı trait `TaskExt` (`crates/gpui/src/executor.rs:33+`) `Task<Result<T, E>>` tipleri üzerine ek metotlar bindirir:

```rust
pub trait TaskExt<T, E> {
    fn detach_and_log_err(self, cx: &App);
    fn detach_and_log_err_with_backtrace(self, cx: &App);
}
```

`detach_and_log_err`, görevi arka plana atar ve hata oluşması durumunda hatayı `log::error!("...: {err}")` biçiminde loglar. `_with_backtrace` varyantı aynı işi `{:?}` biçimiyle yapar; bu sayede `anyhow::Error` gibi geri izleme (`backtrace`) taşıyan tipler tam çağrı yığınıyla loglanır.

**Pratik akış.** Tipik bir async UI iş parçası, ağdan veri çekmek ve sonra view verisini güncellemekten oluşur:

```rust
cx.spawn_in(window, async move |gorunum, cx| {
    let veri = http_istemcisi.get(adres).await?;
    gorunum.update_in(cx, |gorunum, window, cx| {
        gorunum.uygula(veri, window, cx);
    })?;
    Ok::<(), anyhow::Error>(())
})
.detach_and_log_err(cx);
```

**Detach varyantları.** Görevi bırakırken niyete göre üç farklı yardımcı vardır:

- `task.detach()` — hata loglanmaz, sessizce yutulur. Yalnızca UI'da gösterilemeyen ve sonucu kaybolsa sorun olmayacak işler için uygundur.
- `task.detach_and_log_err(cx)` — standart akıştır; üretim kodunda hata yönetiminin varsayılan yolu olarak tercih edilir.
- `task.detach_and_prompt_err(prompt_label, window, cx, |err, window, cx| ...)` — workspace UI'sında kullanılan ek bir yardımcıdır (workspace crate'inde tanımlıdır); hatayı modal bir prompt ile kullanıcıya gösterir.

**Yazarken kararlar.** Bir görevin imzada nasıl görüneceğini seçerken şu pratik kurallar işine yarar:

- Async sonuç çağıran koda dönmeliyse metot `Task<R>` döndürmeli ve çağıran kod bunu `await` etmelidir. Sonucu struct alanında saklamak ise ileride alan elden çıkarsa iptal davranışı verir.
- Çağıran kod sonucu beklemeyecekse görevi geri döndürmek gereksizdir; doğrudan `detach_and_log_err(cx)` çağırmak niyeti daha açık gösterir.
- `Result`'ı log'a düşürmemek için elle `if let Err(e) = task.await { ... }` yazman gereksizdir; `detach_and_log_err` zaten `track_caller` ile log konumunu kayda alır.

**Tuzaklar.** Bu API'lerle ilgili sık yapılan hatalar şunlar:

- `Result` tipinin `E` argümanı `Display + Debug` istemelidir; `anyhow::Error` ve standart özel hata tipleri otomatik uyar.
- Görevleri `Vec<Task<()>>` içinde topladığında elden çıkma sırası sürpriz olabilir; iptalin amaçlanmadığı tipik akışlarda `detach()` daha açık bir niyet bildirir.
- `cx.spawn_in(window, ...)`, `Window` düştüğünde görevi otomatik iptal etmez; `WeakEntity` üzerinden `update` veya `update_in` çağrısı `Result` döndüğünden bu dönüşü erken çıkış sinyali olarak ele alırsın.

## Uygulama Geneli Veri, Observe ve Olay

GPUI'da uygulama genelindeki paylaşılan veriyi üç ana mekanizmayla yönetirsin: `Global` (uygulama geneli veri), observe (veri değişimini dinlemek) ve olay (tipli mesaj yayma). Üçünü de bağlam üzerinden çağırırsın ve genellikle birlikte kullanırsın.

**Uygulama geneli veri.** Uygulama ömrü boyunca tek nüsha tutulan bir kaynak için `Global` trait'ini uygular ve `cx.set_global` ile yerleştirirsin:

```rust
struct GenelDurum(Durum);
impl Global for GenelDurum {}

cx.set_global(GenelDurum(durum));

cx.update_global::<GenelDurum, _>(|genel_durum, _cx| {
    genel_durum.0.degisti_mi = true;
});

let deger = cx.read_global::<GenelDurum, _>(|genel_durum, _| genel_durum.0.clone());
```

**Observe.** Bir entity'nin `cx.notify()` çağırması bütün gözlemcileri tetikler. Tipik kullanım, türetilmiş veriyi kaynağa bağlamaktır:

```rust
abonelikler.push(cx.observe(&diger, |gorunum, diger, cx| {
    gorunum.kopya = diger.read(cx).deger;
    cx.notify();
}));
```

**Olay.** Tipli mesaj yayma için entity `EventEmitter<E>` uygular; yaydığın olay abonelere ulaşır:

```rust
struct Kaydedildi;
impl EventEmitter<Kaydedildi> for Belge {}

cx.emit(Kaydedildi);

abonelikler.push(cx.subscribe(&belge, |gorunum, belge, _: &Kaydedildi, cx| {
    gorunum.son_kaydedilen = Some(belge.entity_id());
    cx.notify();
}));
```

**Pencere bazlı gözlem.** Pencerenin kendisine ait değişimler için ayrı bir gözlemci ailesi vardır; her biri ilgili pencere değişiminde tetiklenir:

- `cx.observe_window_bounds(window, ...)`
- `cx.observe_window_activation(window, ...)`
- `cx.observe_window_appearance(window, ...)`
- `cx.observe_button_layout_changed(window, ...)`
- `cx.observe_pending_input(window, ...)`
- `cx.observe_keystrokes(...)`

## Uygulama Geneli Veri Yardımcıları ve `cx.defer`

`App` üzerinde bulunan `Global` yardımcıları rehberin farklı bölümlerinde parça parça geçer; burada tek bir listede toplandı. Aynı kategori altında "global'i değiştir" ve "etki döngüsünü (`effect cycle`) yönet" başlıklarını birlikte ele almak en sık sorulan iki konuyu yan yana getirir.

- `cx.set_global<T: Global>(deger)` — var olanı ezer; yoksa kurar.
- `cx.global<T>() -> &T` — var olduğundan emin olduğun çağrı noktalarında kullanırsın; yoksa `panic` üretir.
- `cx.global_mut<T>()` — aynısının değiştirilebilir karşılığıdır.
- `cx.default_global<T: Default>() -> &mut T` — global yoksa varsayılan değerle bir nesne oluşturur, varsa mevcut global'i değiştirilebilir biçimde verir.
- `cx.has_global<T>() -> bool` — okuma öncesi varlık kontrolü.
- `cx.try_global<T>() -> Option<&T>` — `null` olabilen okuma.
- `cx.update_global<T, R>(|g, cx| ...) -> R` — kapsamlı güncelleme.
- `cx.read_global<T, R>(|g, cx| ...) -> R` — kapsamlı okuma.
- `cx.remove_global<T>() -> T` — nesneyi geri alır; tekrar ayarlamadığın sürece global yok sayılır.
- `cx.observe_global<T>(|cx| ...) -> Subscription` — global her bildirim gönderdiğinde geri çağrıyı tetikler.

**Etki döngüsü yönetimi.** GPUI içinde veri değişimleri "etki döngüsü" denilen turlar hâlinde işlenir. İç içe güncelleme yerine işleri ertelemek genellikle daha güvenlidir:

- `cx.defer(|cx| ...)`, mevcut etki döngüsü bittiğinde çalışır. İç içe güncellemeleri kırmak veya entity'leri yığına geri vermek için idealdir.
- `Context<T>::defer_in(window, |gorunum, window, cx| ...)`, aynı erteleme davranışının pencereye bağlı varyantıdır.
- `window.defer(cx, |window, cx| ...)`'ı, doğrudan pencere bağlamından ertelemek için kullanırsın.
- `window.refresh()`, pencereyi bir sonraki ekran karesinde yeniden çizim için işaretler.
- `cx.refresh_windows()`, tüm pencereler için aynı işi yapar.

**Tuzaklar.** `Global`'ler ve `defer` kullanımında dikkat edeceklerin:

- `cx.global<T>()` ve `cx.global_mut<T>()` global yoksa `panic` üretir; kurulum kontrolünün yapılmadığı çağrı noktalarında `try_global` veya `has_global`'i tercih edersin.
- `update_global` sırasında aynı global yeniden güncellenirse `panic` verir; iç içe çağrılar varsa erteleme için `defer` güvenli yoldur.
- `Subscription`'a `detach()` çağırmazsan sahibinin düşmesiyle iptal olur; uzun yaşaması gereken gözlemcileri bir struct alanında saklarsın.

**Pencere arası iletişim seçimi.** Birden fazla pencerenin aynı değişiklikten etkilenmesi gerektiğinde iki ana model vardır:

- Uygulama geneli, tek kopya veri için `Global` kullanırsın. Tema, oturum, ayar veya tüm pencereleri etkileyen özellik bayrağı bu sınıftadır. Her pencere kendi view'unda `observe_global` veya pencere gerekiyorsa `observe_global_in` ile global değişimini dinler.
- Belirli bir belge, panel veya konu (`domain`) nesnesi birden fazla pencerede görünüyorsa paylaşılan `Entity<T>` saklarsın ve iki pencerenin kök view'una aynı entity klonunu geçirirsin. Bu durumda veri `Global` olmak zorunda değildir; sahiplik konu nesnesindedir.
- Tek seferlik mesajlar için `EventEmitter` + `subscribe` daha uygundur. Kalıcı durum gerekiyorsa event yerine durumu saklayan `Global` veya `Entity<T>` tercih edilir.

Global tabanlı akışta değişikliği tüm gözlemcilere mevcut etki döngüsünün sonunda yayarsın:

```rust
struct OturumDurumu {
    aktif_proje: Option<SharedString>,
}

impl Global for OturumDurumu {}

cx.update_global::<OturumDurumu, _>(|durum, _cx| {
    durum.aktif_proje = Some("gpui-doc".into());
});

self._oturum_gozlemi = cx.observe_global::<OturumDurumu>(|gorunum, cx| {
    gorunum.basligi_yenile(cx);
    cx.notify();
});
```

Paylaşılan entity modelinde ise iki pencere aynı tipli veriye bakar:

```rust
let belge = cx.new(|cx| BelgeDurumu::new(cx));

cx.open_window(WindowOptions::default(), {
    let belge = belge.clone();
    move |window, cx| cx.new(|cx| BelgePenceresi::new(belge.clone(), window, cx))
})?;

cx.open_window(WindowOptions::default(), {
    let belge = belge.clone();
    move |window, cx| cx.new(|cx| OnizlemePenceresi::new(belge.clone(), window, cx))
})?;
```

Pratik karar şudur: veri uygulama çapında tek kavramsa `Global`; belirli bir nesnenin durumuysa ve birden fazla yerde gösteriliyorsa paylaşılan `Entity<T>`; yalnız bildirim gerekiyorsa `EventEmitter` kullanırsın. `WindowHandle`'ı global durumda uzun süre saklamak genellikle son çaredir; pencere kapanmış olabileceği için her kullanımda hata yolunu düşünmen gerekir.

## Subscription Yaşam Döngüsü

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Subscription` | Metotlar | `detach`, `join`, `new` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


![EventEmitter ve Subscription Yaşam Döngüsü](assets/event-emitter-subscription.svg)


`crates/gpui/src/subscription.rs`.

`Subscription`, opak (`opaque`) bir tiptir; elden çıktığında içindeki geri çağrı kaydı silinir. Bu davranış üç farklı kullanım desenine yol açar; aralarındaki seçim abonelik kaydının ne kadar yaşaması gerektiğine bağlıdır:

```rust
// 1. Alanda sakla
struct Gorunum { _abonelikler: Vec<Subscription> }
// new(): self._abonelikler.push(cx.subscribe(...));

// 2. Detach (geri çağrı view ömrü boyunca yaşar)
cx.subscribe(&varlik, |...| { ... }).detach();

// 3. Geçici kapsam (elden çıkınca abonelik kalkar)
let _abonelik = cx.observe(&varlik, |...| { ... });
// _abonelik düştüğünde geri çağrı kaldırılır
```

**Abonelik üreten yöntemler.** `Context<T>` üzerinde abonelik üreten temel metotlar şunlar:

- `cx.observe(entity, f)` — entity `cx.notify()` çağırdığında tetiklenir.
- `cx.subscribe(entity, f)` — `EventEmitter<E>` olayları için.
- `cx.observe_global::<G>(f)` — uygulama geneli veri değiştiğinde.
- `cx.observe_release(entity, f)` — entity elden çıktığında.
- `cx.on_focus(handle, window, f)`, `cx.on_blur(...)`, `cx.on_focus_in(...)`, `cx.on_focus_lost(window, f)`. Alt öğenin odak kaybı için düşük seviyeli `window.on_focus_out(handle, cx, f)`'i kullanırsın.
- `cx.observe_window_bounds`, `cx.observe_window_activation`, `cx.observe_window_appearance`, `cx.observe_button_layout_changed`, `cx.observe_pending_input`, `cx.observe_keystrokes`.

`Subscription::new(unsubscribe)`, özel bir kaynak için "handle düşerse temizle" davranışı kurar. `Subscription::detach()` geri çağrıyı handle ömründen koparır; `Subscription::join(a, b)` iki aboneliği tek handle altında toplar ve drop edildiğinde ikisini de kapatır. `SubscriberSet::insert`, `remove` ve `retain` GPUI'nın kendi observe/subscribe altyapısının iç haritasıdır; uygulama kodunda olay dinlemek için bu set'i yönetmez, yukarıdaki bağlam metotlarını kullanırsın.

**Tuzaklar.** Abonelik kullanımında dikkat edeceğin noktalar:

- `detach()`, uzun yaşayan bir geri çağrıyı view ömründen koparır; view düştükten sonra geri çağrı hâlâ çalışıyorsa veri erişimi için `WeakEntity` ile koruma şart olur.
- Birden çok abonelik birbirini etkiliyorsa elden çıkma sırasına davranış bağlamak hatalıdır; açık bir kapatma metodu veya tek sahipli struct kullanmak güvenli yoldur.
- `observe` geri çağrısının içinden entity'yi güncellemek `panic` verir; bunun yerine `cx.spawn(..)` ile async akışa taşırsın veya `cx.defer(|cx| ...)` ile sonraki etki döngüsüne ertelersin.

## Pencere Bağlı Gözlemci, Release ve Odak Yardımcı Desenleri

Standart `observe`, `subscribe` ve `on_release` geri çağrıları yalnızca `App` veya `Context<T>` verir. Buna karşılık UI katmanında çoğu iş pencereye de ihtiyaç duyduğu için GPUI, aynı desenlerin pencereye duyarlı varyantlarını ayrıca sağlar. Aşağıdaki başlıklar bu yardımcı ailelerini ve aralarındaki seçimi açar.

**Yeni entity gözleme.** Belirli bir tipin oluşturulduğu anda kanca (`hook`) takmak gerektiğinde `observe_new`'i kullanırsın:

```rust
cx.observe_new(|calisma_alani: &mut Workspace, window, cx| {
    if let Some(window) = window {
        calisma_alani.pencere_kancalarini_kur(window, cx);
    }
}).detach();
```

- `App::observe_new<T>(|durum, Option<&mut Window>, &mut Context<T>| ...)`, belirli türde bir entity oluşturulduğunda çalışır. Entity bir pencere içinde yaratıldıysa geri çağrıya `Some(window)` gelir; başsız ya da uygulama seviyesindeki yaratımda `None` gelebilir.
- Zed `zed.rs`, `toast_layer`, `theme_preview`, `telemetry_log`, `move_to_applications` gibi modüllerde workspace, project veya editor yaratıldığında uygulama geneli kanca takmak için bu deseni kullanır.
- Dönen `Subscription`'ı saklarsın ya da uygulama ömrü boyunca gerekiyorsa `detach()` edersin.

**Pencere bağlamıyla observe ve subscribe.** İçinde pencere bağlamı gerektiren abonelikleri ayrı bir yardımcı ailesiyle yaparsın:

```rust
self._aktif_bolme_gozlemi = cx.observe_in(aktif_bolme, window, |gorunum, bolme, window, cx| {
    gorunum.bolmeden_esitle(&bolme, window, cx);
});

self._abonelik = cx.subscribe_in(&modal, window, |gorunum, modal, olay, window, cx| {
    gorunum.modal_olayini_isle(modal, olay, window, cx);
});
```

- `Context<T>::observe_in(&Entity<V>, window, |gorunum, Entity<V>, window, cx| ...)`, gözlenen entity `cx.notify()` yaptığında o anki entity'yi pencere bağlamı eşliğinde günceller.
- `Context<T>::subscribe_in(&Entity<Yayici>, window, |gorunum, yayici, olay, window, cx| ...)`, `EventEmitter` olaylarını pencere bağlamıyla işler.
- `Context<T>::observe_self(|gorunum, cx| ...)`, o anki entity `cx.notify()` yaptığında kendi üzerinde geri çağrıyı çalıştırır; türetilmiş ya da önbelleklenmiş veriyi tek noktada tutmak için kullanabilirsin.
- `Context<T>::subscribe_self::<Olay>(|gorunum, olay, cx| ...)`, o anki entity'nin kendi yaydığı olayı dinler. Bu deseni dikkatli kullanman gerekir; çoğu durumda olayı yayan kod yolunda veriyi doğrudan güncellemek daha açıktır.
- `Context<T>::observe_global_in::<G>(window, |gorunum, window, cx| ...)`, uygulama geneli veri bildirim gönderdiğinde o anki entity'yi pencere bağlamıyla günceller. Pencere geçici olarak güncelleme yığınından alınmış veya kapanmışsa bildirim atlanır, gözlemci canlı kalır.
- Bu API'ler `ensure_window(observer_id, window.handle.id)` çağırır; entity'nin hangi pencereye bağlı çalışacağını GPUI'a kaydeder. Aynı entity birden fazla pencerede kullanılacaksa hangi pencerenin bağlandığını bilinçli şekilde düşünmen gerekir.

**Release gözleme.** Bir entity yok edilirken yapılacak temizlikler için serbest bırakma (`release`) geri çağrıları vardır:

- `App::observe_release(&varlik, |durum, cx| ...)` — entity'nin son güçlü handle'ı düştükten sonra, veri elden çıkmadan hemen önce çalışır.
- `App::observe_release_in(&varlik, window, |durum, window, cx| ...)` — aynı geri çağrıyı pencere handle'ı üzerinden çalıştırır; pencere kapanmışsa güncelleme başarısız olur ve geri çağrı atlanabilir.
- `Context<T>::on_release_in(window, |gorunum, window, cx| ...)` — o anki entity'nin serbest bırakılmasını pencereyle birlikte gözler.
- `Context<T>::observe_release_in(&other, window, |gorunum, other, window, cx| ...)` — başka bir entity serbest bırakılırken gözlemci entity'yi de günceller.

**Odak yardımcıları.** Odak akışına müdahale için tipli yardımcılar mevcuttur:

- `cx.focus_view(&entity, window)` — `Focusable` uygulayan başka bir view'a odağı taşır.
- `cx.focus_self(window)` — o anki entity `Focusable` ise odağı kendine taşır. İçeride `window.defer(...)` kullanır; bu nedenle çizim ya da action geri çağrısı içinde çağırdığında odak değişimi etki döngüsünün sonunda uygulanır.
- `window.disable_focus()` — pencerenin odağını sıfırlar ve ardından `focus_enabled` bayrağını `false` yapar. Tersine çeviren bir API yoktur; yani çağırdıktan sonra `focus_next` / `focus_prev` / `focus(...)` çağrıları sessizce işlem yapmaz. Uygulama bileşenlerinde genellikle gerekmez; yalnızca pencere ömrü boyunca klavye odağını kalıcı kapatmak isteyen ender durumlarda kullanırsın.

**Tuzaklar.** Bu yardımcı aileleri kullanılırken gözden kaçabilecek noktalar:

- `observe_new` geri çağrısında `window`'un her zaman var olduğunu varsayma; başsız test ve uygulama seviyesindeki entity yaratımı `None` üretebilir.
- Pencereye bağlı aboneliği bir struct alanında saklamazsan geri çağrı hemen düşer.
- `focus_self` ertelemeli çalıştığı için hemen sonraki satırda odak değişmiş gibi okumak yanıltıcıdır; sonucu sonraki etki veya ekran karesi akışında gözlemen gerekir.

## Entity Reservation ve Çift Yönlü Referans

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Reservation` | Metotlar | `entity_id` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


`crates/gpui/src/app/async_context.rs:43+` ve `app.rs::reserve_entity`/`insert_entity`.

Bazen bir entity oluştururken başka bir entity'nin kimliğini veya zayıf handle'ını önceden bilmen gerekir; en tipik örnek `Workspace` ve `Pane` ikilisidir. Bunu kuvvetli referans döngüsü kurmadan yapmak için `Reservation` deseni mevcuttur. Önce kimliği rezerve edersin, sonra entity'yi bu rezervasyona yerleştirirsin:

```rust
let bolme_rezervasyonu: Reservation<Pane> = cx.reserve_entity();
let bolme_id = bolme_rezervasyonu.entity_id();

let calisma_alani = cx.new(|cx| {
    Workspace::with_pane_id(bolme_id, cx)
});

let bolme = cx.insert_entity(bolme_rezervasyonu, |cx| {
    Pane::new(calisma_alani.downgrade(), cx)
});
```

**`Reservation<T>` yüzeyi.** Rezervasyon nesnesi ile iki temel iş yaparsın:

- `entity_id()` — entity henüz oluşturulmadan kimliğini verir.
- `cx.insert_entity(reservation, build)` — rezervasyonu doldurur ve `Entity<T>` döndürür.
- Doldurulmadan elden çıkarıldığında rezervasyon iptal olur.

**Deseni.** Alt entity, üst öğeye `WeakEntity` ile bağlanır; rezervasyon sayesinde üst öğeyi oluştururken alt öğenin handle'ının önceden bilinmesi gereken durumlarda da döngü oluşmaz. Aynı API'yi `AsyncApp` üzerinden de çağırabilirsin.

**Tuzaklar.** Rezervasyon kullanırken karşılaşabileceğin hata desenleri:

- Rezervasyon kullanmadan iki `Entity<T>`'yi birbirine güçlü sahiplikle bağladığında, hiçbir handle düşmediği için bellek sızıntısı oluşur.
- `insert_entity` çağırmadan rezervasyonu elden çıkardığında entity hiç oluşturulmamış sayılır; daha önce `entity_id()` ile yaydığın kimlik artık geçersizdir.
- `cx.new`, bir güncellemenin ortasında rezervasyonu da doldurabilir; iç içe güncelleme yasakları rezervasyon için de aynen geçerlidir.

## Entity Release, Temizlik ve Sızıntı Tespiti

![Entity / WeakEntity Sahiplik Modeli](assets/entity-sahiplik.svg)

Entity handle'ları referans sayısı (`ref-count`) mantığıyla yaşar; son güçlü `Entity<T>` handle'ı düştüğünde entity serbest bırakılır. `WeakEntity<T>` ise bu davranışı engellemez, yalnızca canlıyken zayıf erişim sağlar.

**Temizlik API'leri.** Serbest bırakma anında yapılacak işler için birkaç farklı geri çağrı biçimi vardır:

- `cx.on_release(|gorunum, cx| ...)` — mevcut entity serbest bırakılırken çalışır.
- `App::observe_release(&varlik, |serbest_birakilan, cx| ...)` — uygulama bağlamından başka bir entity'nin serbest bırakılmasını izler.
- `Context<T>::observe_release(&varlik, |gorunum, serbest_birakilan, cx| ...)` — view verisi ile birlikte başka bir entity'nin serbest bırakılmasını izler.
- `window.observe_release(&varlik, cx, |serbest_birakilan, window, cx| ...)`'ı, serbest bırakma sırasında pencere bağlamı gerektiğinde kullanırsın.
- `cx.on_drop(...)` / `AsyncApp::on_drop(...)` — Rust kapsamı düştüğünde entity güncellemek için ertelenmiş bir geri çağrı üretir; entity zaten düşmüşse güncelleme başarısız olabilir.

**Örnek.** Önbellek serbest bırakılmasını gözlemleyen bir view tipik bir desendir:

```rust
struct Onizleme {
    onbellek: Entity<RetainAllImageCache>,
    onbellek_birakildi: bool,
    _abonelikler: Vec<Subscription>,
}

impl Onizleme {
    fn new(cx: &mut Context<Self>) -> Self {
        let onbellek = RetainAllImageCache::new(cx);
        let abonelik = cx.observe_release(&onbellek, |gorunum, _onbellek, cx| {
            gorunum.onbellek_birakildi = true;
            cx.notify();
        });

        Self {
            onbellek,
            onbellek_birakildi: false,
            _abonelikler: vec![abonelik],
        }
    }
}
```

**Sızıntı kontrolü.** Test ve özellik bayrağı altında entity sızıntısını izleyebilirsin:

```rust
let sizinti_anlik_gorunumu = cx.leak_detector_snapshot();
// Test gövdesi.
cx.assert_no_new_leaks(&sizinti_anlik_gorunumu);
```

**Tuzaklar.** Temizlik ve serbest bırakma çalışmasında dikkat edeceklerin:

- `Subscription`'ı saklamazsan hemen düşer ve dinleyici iptal olur.
- Karşılıklı `Entity<T>` alanları döngü üretir; bir tarafın `WeakEntity<T>` olması gerekir.
- Serbest bırakma geri çağrısı içinde uzun async iş başlatacaksan entity verisinin kapanmakta olduğunu varsayman gerekir; gerekli veriyi geri çağrı başında kopyalarsın.
- `WeakEntity::update` ve `read_with` her zaman `Result` döndürür; entity düşmüş olabileceği için hatayı görünür biçimde ele alman gerekir.

## Entity Tip Soyutlaması, Geri Çağrı Adaptörleri ve View Önbelleği

Bu bölüm GPUI çekirdeğinde genel olan ama günlük kullanımda kolay atlanan küçük API yüzeylerini toplar. Entity'nin tipli ve tipsiz varyantları, view önbellek mekanizması, geri çağrı adaptörleri ve düşük seviyeli kimlik tipleri burada ele alınır.

#### Entity ve WeakEntity Tam Yüzeyi

`Entity<T>` güçlü handle'dır ve şu metotları sağlar:

- `varlik.entity_id() -> EntityId`
- `varlik.downgrade() -> WeakEntity<T>`
- `varlik.into_any() -> AnyEntity`
- `varlik.read(cx: &App) -> &T`
- `varlik.read_with(cx, |durum, cx| ...) -> R`
- `varlik.update(cx, |durum, cx| ...) -> R`
- `varlik.update_in(gorsel_cx, |durum, window, cx| ...) -> C::Result<R>`
- `varlik.as_mut(cx) -> GpuiBorrow<T>` — değiştirilebilir ödünç verir; ödünç düşerken entity bildirim alır.
- `varlik.write(cx, deger)` — veriyi tamamen değiştirir ve `cx.notify()` çağırır.

`Context<T>`, o anki entity için aynı kimlik ve handle yüzeyini sağlar:

- `cx.entity_id() -> EntityId`
- `cx.entity() -> Entity<T>` — o anki entity hâlâ canlı olmak zorunda olduğu için güçlü handle döndürür.
- `cx.weak_entity() -> WeakEntity<T>` — async görev, dinleyici veya döngüsel sahiplik riski olan alanlarda saklayacağın handle budur.

**Kimlik dönüşümleri.** GPUI çalışma zamanı kimliklerini `u64` olarak dışarı verebilirsin:

- `EntityId::as_u64()` ve `EntityId::as_non_zero_u64()`'i, FFI, telemetri veya hata ayıklama eşlemesi anahtarı gibi tipli id sınırının dışına çıktığın yerlerde kullanırsın.
- `WindowId::as_u64()` aynı işi pencere kimliği için yapar. Bu değerleri iş alanı (`domain`) kimliği veya kalıcı workspace serileştirme anahtarı olarak kullanma; GPUI çalışma zamanı kimliği olmaları kalıcılık garantisi vermez.

`WeakEntity<T>` zayıf handle'dır:

- `zayif.upgrade() -> Option<Entity<T>>`
- `zayif.update(cx, |durum, cx| ...) -> Result<R>`
- `zayif.read_with(cx, |durum, cx| ...) -> Result<R>`
- `zayif.update_in(cx, |durum, window, cx| ...) -> Result<R>` — entity'nin o anki penceresini `App::with_window(entity_id, ...)` üzerinden bulur; entity düşmüşse veya o anki pencere yoksa hata döner.
- `WeakEntity::new_invalid()`, hiçbir zaman yükseltilemeyen nöbetçi (`sentinel`) handle üretir; opsiyon yerine "geçersiz ama tipli handle" gereken yerlerde kullanırsın.

`AnyEntity` ve `AnyWeakEntity`, heterojen koleksiyonlar içindir:

- `AnyEntity::{entity_id, entity_type, downgrade, downcast::<T>}`
- `AnyWeakEntity::{entity_id, is_upgradable, upgrade, new_invalid}`
- `AnyWeakEntity::assert_released()` yalnız `test` veya `leak-detection` özelliği altında vardır; güçlü handle sızıntısını yakalamak için kullanırsın.

**Kural.** Plugin, dock veya workspace gibi heterojen koleksiyon sınırı yoksa tipli `Entity<T>` veya `WeakEntity<T>`'yi tercih edersin. `AnyEntity`, alta `downcast` zorunluluğu getirir; yanlış tipte `downcast::<T>()` çağrısı entity'yi `Err(AnyEntity)` olarak geri verir.

##### Deref ile gizlenmiş yüzey (tipli handle üzerinden tipsiz metot)

`Entity<T>` ve `WeakEntity<T>`, `#[derive(Deref, DerefMut)]` ile içlerindeki tipsiz handle'a deref eder (`crates/gpui/src/app/entity_map.rs:413` ve `:739`):

```rust
#[derive(Deref, DerefMut)]
pub struct Entity<T>     { any_entity: AnyEntity,         entity_type: PhantomData<_> }
#[derive(Deref, DerefMut)]
pub struct WeakEntity<T> { any_entity: AnyWeakEntity,     entity_type: PhantomData<_> }
```

Bu yüzden `AnyEntity` ve `AnyWeakEntity` üzerindeki bazı metotlar tipli handle'da metot çözümlemesi ile çağrılabilir. "Sahip yalnız tipsiz tiptir" yanılgısı buradan doğar. Doğru ayrımı `Sahip::metot -> dönüş tipi` çiftiyle yaparsın; metot adı tek başına yeterli değildir.

| Sahip | Metot | Dönüş | Erişim |
|---|---|---|---|
| `Entity<T>` | `entity_id()` | `EntityId` | Doğrudan (`AnyEntity::entity_id` ile aynı değeri okur; doğrudan çağrı kazanır). |
| `Entity<T>` | `downgrade()` | `WeakEntity<T>` | Doğrudan; aynı adlı `AnyEntity::downgrade -> AnyWeakEntity` gölgelenir. |
| `Entity<T>` | `into_any()` | `AnyEntity` | Doğrudan; `self`'i tüketir. |
| `Entity<T>` | `read(&App)` | `&T` | Doğrudan. |
| `Entity<T>` | `read_with(cx, \|&T, &App\| ...)` | `R` | Doğrudan. |
| `Entity<T>` | `update(cx, \|&mut T, &mut Context<T>\| ...)` | `R` | Doğrudan. |
| `Entity<T>` | `update_in(gorsel_cx, \|&mut T, &mut Window, &mut Context<T>\| ...)` | `C::Result<R>` | Doğrudan. |
| `Entity<T>` | `as_mut(&mut cx)` | `GpuiBorrow<T>` | Doğrudan; düşerken `cx.notify()`. |
| `Entity<T>` | `write(&mut cx, deger)` | `()` | Doğrudan; veriyi değiştirir ve bildirim gönderir. |
| `Entity<T>` deref | `entity_type()` | `TypeId` | Sahip `AnyEntity`; `Entity`'de doğrudan karşılığı yoktur, deref ile çağrılır. |
| `Entity<T>` yalnız deref özel durum | `downcast::<U>()` | `Result<Entity<U>, AnyEntity>` | Sahip `AnyEntity::downcast(self)` — **`self`'i tüketir**. Otomatik deref tüketen metoda uygulanmadığı için `varlik.downcast::<U>()` doğrudan derlenmez; `varlik.into_any().downcast::<U>()` yazman gerekir. |
| `AnyEntity` | `entity_id()` | `EntityId` | Doğrudan. |
| `AnyEntity` | `entity_type()` | `TypeId` | Doğrudan. |
| `AnyEntity` | `downgrade()` | `AnyWeakEntity` | Doğrudan. |
| `AnyEntity` | `downcast::<U>()` | `Result<Entity<U>, AnyEntity>` | Doğrudan; `self`'i tüketir. |

`WeakEntity<T>` tarafında ad çakışmaları yüzünden tabloyu daha da dikkatli okuman gerekir; doğrudan ve yalnız deref ile gelen metotlar aynı isimle farklı imza taşır:

| Sahip | Metot | Dönüş | Erişim |
|---|---|---|---|
| `WeakEntity<T>` | `upgrade()` | `Option<Entity<T>>` | Doğrudan; aynı adlı `AnyWeakEntity::upgrade -> Option<AnyEntity>` gölgelenir. |
| `WeakEntity<T>` | `update(cx, \|&mut T, &mut Context<T>\| ...)` | `Result<R>` | Doğrudan. |
| `WeakEntity<T>` | `update_in(cx, \|&mut T, &mut Window, &mut Context<T>\| ...)` | `Result<R>` | Doğrudan; entity'nin son çizildiği pencereyi `App::with_window` ile bulur. |
| `WeakEntity<T>` | `read_with(cx, \|&T, &App\| ...)` | `Result<R>` | Doğrudan. |
| `WeakEntity<T>` | `new_invalid()` | `Self` | Doğrudan; aynı adlı `AnyWeakEntity::new_invalid -> AnyWeakEntity` gölgelenir. |
| `WeakEntity<T>` deref | `entity_id()` | `EntityId` | Sahip `AnyWeakEntity`; deref ile çağrılır. |
| `WeakEntity<T>` deref | `is_upgradable()` | `bool` | Sahip `AnyWeakEntity`; deref ile çağrılır. |
| `WeakEntity<T>` deref | `assert_released()` | `()` | Sahip `AnyWeakEntity`; yalnız `test` veya `leak-detection`. |
| `AnyWeakEntity` | `entity_id()` | `EntityId` | Doğrudan. |
| `AnyWeakEntity` | `is_upgradable()` | `bool` | Doğrudan. |
| `AnyWeakEntity` | `upgrade()` | `Option<AnyEntity>` | Doğrudan — tipli handle üzerinden çağrılırsa `WeakEntity::upgrade` kazanır. |
| `AnyWeakEntity` | `new_invalid()` | `Self` | Doğrudan. |
| `AnyWeakEntity` | `assert_released()` | `()` | Doğrudan; `test` veya `leak-detection`. |

**Pratik sonuç.** `zayif.entity_id()` çağrısı, tipli handle'da deref üzerinden `AnyWeakEntity::entity_id` metoduna iner. Buna karşılık `zayif.upgrade()` çağrısında tipli metot kazanır ve sonuç `Option<Entity<T>>` olur. Aynı kod parçasında ikisi yan yana görünebilir ama sahipleri farklıdır; ayrımı yine `Sahip::metot -> dönüş` çiftiyle yaparsın.

#### AnyView, AnyWeakView ve EmptyView

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `AnyView` | Metotlar | `downcast`, `downgrade`, `entity_id`, `entity_type` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `AnyWeakView` | Metotlar | `upgrade` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


`AnyView`, `Render` uygulayan bir `Entity<V>` için element olarak kullanılabilen, tipi silinmiş view handle'ıdır. Bu sayede farklı view tiplerini tek bir element yuvasına yerleştirebilirsin:

```rust
let gorunum: AnyView = bolme.clone().into();
div().child(gorunum.clone());
```

**Önemli metotlar.** Tipi silinmiş view ile çalışırken sık kullandığın API'ler:

- `AnyView::from(varlik)` veya `varlik.into_element()` — tipli view'u, tipi silinmiş element hâline getirir.
- `any_view.downcast::<T>() -> Result<Entity<T>, AnyView>` — tipli handle'a geri dönmek için kullanırsın.
- `any_view.downgrade() -> AnyWeakView` ve `AnyWeakView::upgrade() -> Option<AnyView>` — zayıf handle dönüşümleri.
- `any_view.entity_id()` ve `entity_type()` — hata ayıklama ve kayıt defteri mantığında kullanırsın.
- `EmptyView` — hiçbir şey çizmeyen `Render` view'udur; yer tutucu amaçlı kullanırsın.

**Önbelleklenmiş view.** `AnyView::cached(style_refinement)`'ı, pahalı bir alt öğe view'unun çizim sonucunu önbelleğe almak için kullanırsın:

```rust
div().child(
    AnyView::from(bolme.clone())
        .cached(StyleRefinement::default().v_flex().size_full()),
)
```

Önbellek, view `cx.notify()` çağırmadığı sürece önceki yerleşim, çizim hazırlığı ve çizim aralıklarını yeniden kullanır. `Window::refresh()` çağrısı önbelleği atlatır; inspector seçimi açıkken de hitbox'ların eksiksiz olabilmesi için önbellek devre dışı kalır. Önbellek anahtarı sınırları (`bounds`), aktif `ContentMask` ve aktif `TextStyle`'ı içerir. Bu nedenle `cached(...)` çağrısında verdiğin kök `StyleRefinement`, view'un gerçek kök yerleşim stiliyle uyumlu olmalıdır; yanlış refinement yerleşimi bayat veya hatalı gösterir.

#### Geri Çağrı Adaptörleri

Çoğu element geri çağrısı view verisini doğrudan almaz:

```rust
Fn(&Event, &mut Window, &mut App)
```

Geri çağrıdan view verisine geri dönmek için uygun adaptörü seçersin:

- `cx.listener(|gorunum, olay, window, cx| ...)` — `Fn(&Event, &mut Window, &mut App)` üretir. İçeride o anki entity'nin `WeakEntity` handle'ını kullanır; entity düşmüşse geri çağrı sessizce işlem yapmaz.
- `cx.processor(|gorunum, olay, window, cx| -> R { ... })` — `Fn(Event, &mut Window, &mut App) -> R` üretir. Olayı sahiplenir ve dönüş değeri gerektiğinde tercih edersin.
- `window.listener_for(&varlik, |durum, olay, window, cx| ...)` — o anki `Context<T>` dışında, elinde tipli `Entity<T>` varken dinleyici üretir.
- `window.handler_for(&varlik, |durum, window, cx| ...)` — olay parametresi olmayan `Fn(&mut Window, &mut App)` dinleyicisi üretir.

`cx.listener` dışındaki adaptörler, yeniden kullanılabilir bileşenler veya pencere seviyesindeki yardımcılar yazarken devreye girer. Dinleyici içinde veri değiştiğinde `cx.notify()` çağırmak yine çağıranın sorumluluğundadır; adaptör bunu otomatik yapmaz.

#### `FocusHandle` Zayıf Handle ve Dispatch

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `FocusHandle` | Metotlar | `contains`, `contains_focused`, `dispatch_action`, `downgrade`, `focus`, `is_focused`, `tab_index`, `tab_stop`, `within_focused` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `FocusHandle` | Alanlar | `tab_index`, `tab_stop` | Public veri alanları; runtime, stil veya ayar sözleşmesinin taşınan parçalarıdır. |


`FocusHandle` yalnızca odak vermek için değildir; zayıf handle ve yönlendirme kontrolü de sunar:

- `focus_handle.downgrade() -> WeakFocusHandle`
- `WeakFocusHandle::upgrade() -> Option<FocusHandle>`
- `focus_handle.contains(&other, window) -> bool` — son çizilen ekran karesindeki odak ağacı ilişkisini kontrol eder.
- `focus_handle.dispatch_action(&action, window, cx)` — yönlendirmeyi odaktaki düğüm yerine belirli bir odak handle'ının düğümünden başlatır.

`contains_focused(window, cx)` "ben veya altımdaki bir düğüm odakta mı?" sorusuna, `within_focused` ise "ben odaktaki düğümün içinde miyim?" sorusuna cevap verir. `within_focused` imzasında `cx: &mut App` vardır; çünkü yönlendirme ve odak yolu hesaplarında uygulama verisiyle çalışır.

#### `ElementId` Tam Varyantları

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `ElementId` | `Error`, `from`, `hash` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `ElementId` | Metotlar | `named_usize` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `ElementId` | Varyantlar | `CodeLocation`, `Integer`, `Name`, `NamedChild`, `NamedInteger`, `OpaqueId`, `Uuid` | Enum seçim değerleri; davranış farkı ilgili konu anlatımında verilir. |


Sabit element verisi için kullandığın `ElementId` varyantları şunlar:

- `View(EntityId)`, `Integer(u64)`, `Name(SharedString)`, `Uuid(Uuid)`
- `FocusHandle(FocusId)`, `NamedInteger(SharedString, u64)`, `Path(Arc<Path>)`
- `CodeLocation(Location<'static>)`, `NamedChild(Arc<ElementId>, SharedString)`
- `OpaqueId([u8; 20])`

`ElementId::named_usize(name, usize)`, `NamedInteger` üretir. Pratik seçim şöyledir: hata ayıklama seçicisi veya metin tabanlı ID gerektiğinde `Name`; liste satırı gibi tekrar eden yapılarda `NamedInteger`; metin tutamacı (`text anchor`) gibi byte seviyesinde kimliklerde `OpaqueId`'i tercih edersin.

---
