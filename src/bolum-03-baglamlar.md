# 3. Bağlamlar

---

## 3.1. Temel Bağlamlar

GPUI'de yapılan hemen her işlem — varlık (`entity`) güncellemek, pencere açmak, async iş başlatmak, global durum (`state`) okumak, event yayınlamak — `cx` ile gösterilen bir **bağlam** (`context`) nesnesi üzerinden gerçekleştirilir. Bağlam, o anda hangi kapsamda bulunulduğunu (tüm uygulama, belirli bir varlığın güncellenmesi, bir pencere, bir async devam) ve hangi API'lerin kullanılabilir olduğunu temsil eder. Bu yüzden GPUI kodunda fonksiyon imzalarında neredeyse her zaman `cx: &mut App` veya benzer bir parametre görülür; bağlam dışarıdan içeri taşınır, global bir singleton gibi "havadan" alınmaz.

GPUI'de en sık karşılaşılan bağlam tipleri ve hangisinin neyi temsil ettiği:

- **`App`** — Uygulamanın kök bağlamı. Pencere listesi, platform servisleri, keymap, global durum, yeni varlık (`entity`) oluşturma ve yeni pencere açma buradan yapılır. Genelde uygulama başlangıcındaki `app.run(|cx: &mut App| { ... })` içinde ve üst seviye event handler'larda görülür.
- **`Context<T>`** — Belirli bir `Entity<T>` güncellenirken otomatik olarak alınır (örn. `entity.update(cx, |state, cx| { ... })` içindeki ikinci `cx`). `App` API yüzeyine erişir (`Deref` ile) ve üstüne varlık-odaklı yardımcılar ekler: `cx.notify()` (render gerekli), `cx.emit(event)` (event yayınla), `cx.listener(...)` (callback ile varlığı yeniden çağır), `cx.observe(...)` ve `cx.subscribe(...)` (başka varlıkları izle), `cx.spawn(...)` (async iş başlat).
- **`Window`** — Belirli bir pencereye özgü durum ve davranış. Focus yönetimi, imleç, bounds, resize, title bar, background appearance, action dispatch, IME, prompt ve platform pencere işlemleri burada yapılır. Render fonksiyonları (`fn render(&mut self, window: &mut Window, cx: &mut Context<Self>)`) hem `Window`'u hem `Context`'i alır.
- **`AsyncApp` ve `AsyncWindowContext`** — `await` noktaları arasında taşınabilen bağlam türleridir. Async iş sürerken varlık veya pencere kapanmış olabileceği için bu bağlamlar üzerinden yapılan birçok erişim `Result` döndürür; yani hata ihtimali açıkça ele alınır.
- **`TestAppContext` ve `VisualTestContext`** — Testlerde kullanılır. Zaman simülasyonu, görsel doğrulama, manuel event tetikleme gibi test araçları ekler. Üretim kodunda yer almaz.

### Entity (varlık) oluşturma, okuma ve güncelleme

`cx.new(...)` ile heap'te yeni bir durum (`state`) oluşturulur ve geriye `Entity<T>` varlık tutamacı döner. Bu tutamaç clone'lanabilir ve farklı yerlere taşınabilir; tüm clone'lar aynı veriye işaret eder.

```rust
let entity = cx.new(|cx| State::new(cx));

// Veriyi salt-okunur biçimde almak için:
let value = entity.read(cx).value;

// Veriyi değiştirmek için:
entity.update(cx, |state, cx| {
    state.value += 1;
    cx.notify(); // render'da değişiklik görünecekse şart
});

// Hayatta tutmayan zayıf referans için:
let weak = entity.downgrade();
weak.update(cx, |state, cx| {
    state.value += 1;
    cx.notify();
})?; // varlık hâlâ yaşıyorsa Ok döner, düşmüşse Err — bu yüzden ?
```

`entity.read(cx)` veriyi salt-okunur referans olarak verir. `entity.update(cx, |state, cx| { ... })` ise içerideki closure'a değiştirilebilir referans geçer; closure tamamlanınca, içeride `cx.notify()` çağrılmışsa ilgili görünümlerin (`view`) yeniden render'ı planlanır. `notify` çağrılmazsa GPUI değişiklikten habersiz kalır ve ekranda eski görüntü kalır.

### Sık karşılaşılan kurallar

- **Render'ı etkileyen durum (`state`) değişikliklerinden sonra `cx.notify()` çağrılır.** Aksi halde değişiklik bellekte gerçekleşir ama UI bunu görmez; "değiştirdim ama ekran güncellenmiyor" yaygın bir tuzaktır.
- **Bir varlık güncellenirken aynı varlık yeniden update edilmez.** İç içe `entity.update(...)` çağrısı panic'e yol açar. İçeride aynı varlığa dokunmak gerekiyorsa iş `cx.defer(|cx| { ... })` ile sonraki effect cycle'a ertelenir.
- **Uzun ömürlü async işlerde `Entity<T>` yerine `WeakEntity<T>` taşınır.** Aksi halde async closure varlığı gereğinden uzun süre hayatta tutar; görünüm kapanmış olsa bile durum serbest kalmayabilir ve lifecycle davranışı beklenenden farklılaşır.
- **`Task` tutamacı düşürülürse iş iptal olur.** Bu yüzden başlatılan iş ya `await` edilir, ya bir struct alanında saklanır, ya da `detach()` / `detach_and_log_err(cx)` ile bağımsız bırakılır.

## 3.2. WindowHandle, AnyWindowHandle ve VisualContext

`cx.open_window(...)` veya test helper'ları yeni bir pencere açtığında geriye `WindowHandle<V>` türünde bir pencere tutamacı döner. Bu tutamaç pencerenin **kök görünüm tipini** (`V`) bilen, dışarıdan o pencereye komut göndermek için kullanılan değerdir. Pencereye dair kod iki yerden birinde bulunur: ya pencerenin içinde (`render` fonksiyonu, `&mut Window` ile), ya da pencere dışından (`WindowHandle` üzerinden). Pencereye dışarıdan tipli erişim için ana köprü budur.

`AnyWindowHandle` aynı amaca hizmet eder ama kök görünüm tipini taşımaz; ihtiyaç olduğunda runtime'da downcast edilerek tipli versiyona çevrilir. Örneğin tüm açık pencerelerin listesi `Vec<AnyWindowHandle>` olarak gelir, içlerinden belirli bir tipte (örn. `Workspace`) olanları işlemek için downcast yapılır.

### `WindowHandle<V>` kullanımı

```rust
// Tipli kök görünüme erişim:
handle.update(cx, |root: &mut Workspace, window, cx| {
    root.focus_active_pane(window, cx);
})?;

// Sadece okuma:
let title = handle.read_with(cx, |root, cx| root.title(cx))?;

// Kök varlığı tutamaç olarak al:
let entity = handle.entity(cx)?;

// Pencere şu anda aktif mi?
let active = handle.is_active(cx);

// Pencerenin runtime kimliği:
let id = handle.window_id();
```

`handle.update(...)` çağrısı, pencere hâlâ açıksa içerideki closure'ı çalıştırır; pencere bu arada kapanmışsa `Err` döner ve bu yüzden `?` ile sonlandırılır. Closure üç şey alır: kök görünümün değiştirilebilir hâli (tipli, örn. `Workspace`), `&mut Window` ve kök görünüme ait güncelleme bağlamı (`Context<T>`). Pencereyle yapılacak hemen her şey (focus, refresh, resize, prompt) bu closure içinde mümkündür.

### `AnyWindowHandle` kullanımı

```rust
// Önce tipli versiyona çevir, sonra normal update:
if let Some(workspace) = any_handle.downcast::<Workspace>() {
    workspace.update(cx, |workspace, window, cx| {
        workspace.activate(window, cx);
    })?;
}

// Veya tipi bilmeden generic erişim:
any_handle.update(cx, |root_view, window, cx| {
    let root_entity_id = root_view.entity_id();
    window.refresh();
    (root_entity_id, window.is_window_active())
})?;
```

Generic `update` closure'ı içinde kök görünüm `AnyView` olarak gelir; tipli işlem gerekiyorsa önce `downcast::<V>()` ile çevrilir.

### Context trait ailesi

Farklı bağlam tipleri (`App`, `Context<T>`, `AsyncApp`, `TestAppContext` vb.) ortak işlemleri trait'ler üzerinden paylaşır. Bu sayede aynı yardımcı fonksiyon birden fazla bağlam türüyle çalışabilir; örneğin bir helper hem senkron `&mut App` hem async `&mut AsyncApp` ile çağrılabilir.

- **`AppContext`** — Uygulama seviyesindeki temel işlemler için ortak yüzey. `new`, `reserve_entity`, `insert_entity`, `update_entity`, `read_entity`, `update_window`, `with_window`, `read_window`, `background_spawn`, `read_global` gibi varlık ve pencere yönetimi method'larını içerir. Senkron, async ve test context'leri bu trait'i implemente eder.
- **`VisualContext`** — Pencereye bağlı bağlamlarda (örn. render içindeki `Context<View>`, `WindowContext`) ek olarak sağlanan yüzey. `window_handle()`, `update_window_entity`, `new_window_entity`, `replace_root_view`, `focus` gibi pencere-üstü işlemleri buradan gelir.
- **`BorrowAppContext`** — Farklı bağlam tiplerinde aynı global API'yi gerektiren yardımcı fonksiyonlar için kullanılan ortak yüzey. Bir fonksiyon bu trait'i alarak hem `&mut App`, hem `&mut Context<T>`, hem `&mut AsyncApp` üzerinden çağrılabilir hâle gelir.

### Kök Görünümü Çalışırken Değiştirmek

Bir pencerenin tüm içeriği aslında tek bir kök görünüm tarafından üretilir. Bu kök, uygulama çalışırken değiştirilebilir:

```rust
window.replace_root(cx, |window, cx| NewRoot::new(window, cx));
```

Async veya test bağlamlarında aynı işlem `replace_root_view` helper'ı üzerinden yapılır. Tipik kullanımı: yeni bir pencere açmadan tüm UI akışını başka bir ekrana geçirmek (örn. login ekranından workspace'e geçiş, "Welcome" ekranından ana çalışma alanına geçiş). Eski kök görünüme ait abonelikler (`Subscription`), kök varlık drop edildiğinde otomatik olarak kalkar; ancak `detach` edilmiş veya başka bir yerde saklanan task'lar yaşamaya devam edebilir. Bu yüzden kök değişiminden önce ilgili task ve abonelik yönetiminin gözden geçirilmesi gerekir.

### Hangi pencerede çalışıldığını bulmak

`with_window(entity_id, |window, cx| { ... })`, verilen varlığın **geçerli veya en son ilişkilendirilen** penceresini bulup içinde çalıştırma yapar. Bir varlık aynı anda birden fazla pencerede render ediliyorsa bu API bilinçli bir kısayoldur; kesin pencere hedeflenmek isteniyorsa varlık oluşturulurken ilgili `WindowHandle` saklanır ve sonradan doğrudan o pencere tutamacı üzerinden işlem yapılır.


---
