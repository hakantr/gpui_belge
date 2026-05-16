# Temeller

---

## Büyük Resim

GPUI, üst üste oturan üç katmandan oluşur. Her katman bir altındakine
güvenerek çalışır ve bir üstündekine daha sade bir arayüz sunar; böylece
uygulamanın hangi sorunu nerede çözmesi gerektiği oldukça netleşir.

1. **Platform katmanı.** İşletim sistemine doğrudan dokunan kısımdır. macOS,
   Windows, Linux, web ve test ortamları aynı arayüzün arkasına saklanır;
   uygulama kodu "pencere aç", "girdi al", "ekrana çiz" gibi istekleri ortak
   sözleşme üzerinden ifade eder. Bu sözleşmeyi `Platform` ve `PlatformWindow`
   trait'leri taşır: pencere oluşturma, ekran listesi, pano (clipboard),
   sürükle-bırak, ses, dosya seçici gibi platforma özgü tüm yetenekler bu iki
   trait üzerinden açılır. Her hedef için ayrı bir gerçekleştirme mevcuttur,
   ama yukarıdaki kod tek bir API ile konuşur.
2. **Uygulama/durum katmanı.** Uygulamanın yaşam döngüsü ve bellekteki tüm
   durumu burada tutulur. Çekirdek tipler birbirine sıkıca bağlıdır:
   `Application` süreç başlangıcını ve event loop'u yönetir; `App` global durumun
   ana erişim noktasıdır; `Context<T>` belirli bir varlığı güncellerken
   geçici olarak `App`'in üstüne binen genişletilmiş bir bağlamdır;
   `Entity<T>` ve `WeakEntity<T>` heap üzerinde tutulan durum kutucuklarına
   güçlü ve zayıf el verir; `Task` arka plan işlerini, `Subscription` ise olay
   dinleme aboneliklerini drop'ta otomatik temizleyen sahiplik araçlarıdır.
   `Global`'lar uygulama ömrü boyunca tek nüsha duran kaynaklar için
   ayrılmıştır, event sistemi de varlıklar arasında tipli mesajlaşmayı kurar.
3. **Render/element katmanı.** Ekrandaki ağacı üretip çizen kısımdır. Burada
   iki ana rol vardır: `Render` trait'i durum sahibi entity'lerin her frame
   yeni bir element ağacı üretmesini sağlar, `RenderOnce` ve `IntoElement`
   ise yeniden kullanılabilir, durumsuz bileşenleri tanımlar. `Element`
   trait'i ise layout + paint sözleşmesinin kendisidir; `div`, `canvas`,
   `list`, `uniform_list`, `img`, `svg`, `anchored` ve `surface` bu trait'in
   hazır gerçekleştirmeleridir. Üstüne `Styled` ve `InteractiveElement`
   fluent API'leri eklenir: flex/grid stil zinciri, renkler, tıklama, sürükleme,
   focus ve scroll davranışı bu zincirler üzerinden okunur.

Zed bu üç katmanın üstüne kendi tasarım sistemini koyar. Bunlar GPUI'nin
parçası değil, GPUI üzerine yazılmış son kullanıcı bileşenleridir:

- `crates/ui` — Button, Icon, Label, Modal, ContextMenu, Tooltip, Tab, Table,
  Toggle ve benzeri yeniden kullanılan bileşenleri barındırır. Tutarlı bir
  görsel dil ve davranış kalıbı sağlar; uygulama içindeki ekranlar bu kitten
  bileşen alarak yapılır.
- `crates/platform_title_bar` — platforma göre pencere kontrol butonlarını ve
  başlık çubuğu davranışını çizer. Linux ve Windows tarafında "client-side
  decoration" gerektiğinde başlık çubuğu da bu paket tarafından üretilir.
- `crates/workspace` — ana çalışma alanını, client-side decoration gölgesini,
  pencere köşelerindeki resize bölgelerini ve pencere içeriğini tek bir
  bütün halinde birleştirir. Uygulamanın iskeleti, panellerin yerleşimi ve
  pencere kromu burada toplanır.

Kısacası alttan yukarıya doğru sıralama "platform → durum → çizim" şeklindedir;
Zed ise bu temelin üstüne kendi UI kitini ekleyerek tanıdık bir görünüm
oluşturur. İlerleyen bölümler bu üç katmanı tek tek açar, son bölümler ise
Zed'in üst tabakasına döner.

## Hızlı Referans: GPUI Kavram Sözlüğü

Aşağıdaki tablo, rehber boyunca tekrar tekrar geçen temel tipleri tek bakışta
toparlamak için hazırlanmıştır. Her kavram ileride kendi bölümünde detaylıca
açılır; burada amaç bir ismin hangi katmana ait olduğunu, hangi dosyada
yaşadığını ve hangi sorumluluğu taşıdığını hızlıca hatırlatmaktır. Tablo
sırasıyla uygulama ömrü ve bağlamlardan başlar, pencere ve görev tiplerine
geçer, ardından render, etkileşim, geometri ve global kaynaklara doğru ilerler.

| Kavram | Tip | Yer | Kısa Açıklama |
|---|---|---|---|
| Application | `Application` | `gpui_platform` | Platform seçer ve event loop'u sürer. |
| Root context | `App` | `app.rs` | Global state, window, entity create. |
| Entity | `Entity<T>` | `app/entity_map.rs` | Heap-allocated state handle. |
| Weak handle | `WeakEntity<T>` | aynı | Cycle önleyici zayıf handle. |
| Update context | `Context<T>` | `app.rs` | Entity update'inde, App'e deref. |
| Async context | `AsyncApp` | `app/async_context.rs` | Await boyu tutulan context. |
| Pencere | `Window` | `window.rs` | Tek pencere durumu. |
| Window handle | `WindowHandle<V>` | `window.rs` | View tipini bilen window referansı. |
| Future task | `Task<T>` | `executor.rs` | Drop'ta iptal eden future. |
| Subscription | `Subscription` | `subscription.rs` | Drop'ta unsubscribe. |
| Element | `impl Element` | `element.rs` | Layout + paint sözleşmesi. |
| View | `impl Render` | `view.rs` | Stateful element ağacı üreten entity. |
| Action | `impl Action` | `action.rs` | Dispatch tree mesajı. |
| Focus handle | `FocusHandle` | `window.rs` | Focus ve tab navigasyon kimliği. |
| Hitbox | `Hitbox` | `window.rs` | Mouse hit-test alanı. |
| ScrollHandle | `ScrollHandle` | `elements/div.rs` | Paylaşılan scroll state. |
| Animation | `Animation` | `elements/animation.rs` | Süre/easing tabanlı interpolation. |
| Asset source | `AssetSource` trait | `assets.rs` | Asset bytes provider. |
| Color | `Hsla`/`Rgba` | `color.rs` | UI renk tipleri. |
| Pixels | `Pixels` | `geometry.rs` | Mantıksal piksel. |
| Background | `Background` | `color.rs` | Solid/gradient/pattern fill. |
| Keymap | `Keymap` | `keymap/` | Bağlam-duyarlı keybinding tablosu. |
| Global | `impl Global` | `global.rs` | Tek instance app-genel state. |
| Event emitter | `EventEmitter<E>` | `app.rs` | Entity event yayınlayıcı. |

Tablo kavramların ne olduğunu özetler; *ne zaman hangisinin tercih edileceği*
sorusu sonraki bölümlerin işidir. Örneğin `Entity<T>` ile `WeakEntity<T>`
arasındaki seçim sahiplik döngülerini, `Context<T>` ile `AsyncApp` arasındaki
seçim async sınırını, `Element` ile `Render` arasındaki ayrım da durumlu ve
durumsuz parçaları nerede tutmak gerektiğini belirler. Bu nüanslar ilgili
bölümlerde örneklerle açılır.

---
