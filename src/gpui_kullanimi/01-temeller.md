# Temeller

---

## Büyük Resim

GPUI, birbirinin üzerine kurulan üç katmandan oluşur. Her katman bir
altındakine güvenir ve bir üstündekine daha sade bir arayüz sunar. Böylece
uygulama kodunda hangi sorunun nerede çözülmesi gerektiği daha kolay görülür.

1. **Platform katmanı.** İşletim sistemine doğrudan dokunan kısımdır. macOS,
   Windows, Linux, web ve test ortamları aynı arayüzün arkasına alınır.
   Uygulama kodu "pencere aç", "girdi al", "ekrana çiz" gibi istekleri ortak
   bir sözleşmeyle anlatır. Bu sözleşmeyi `Platform` ve `PlatformWindow`
   trait'leri taşır. Pencere oluşturma, ekran listesi, pano (clipboard),
   sürükle-bırak, ses ve dosya seçici gibi platforma özgü yetenekler bu iki
   trait üzerinden açılır. Her hedef için ayrı bir gerçekleştirme vardır,
   ama üstteki uygulama kodu tek bir API ile konuşur.
2. **Uygulama/durum katmanı.** Uygulamanın yaşam döngüsü ve bellekteki tüm
   durumu burada tutulur. Çekirdek tipler birbirine sıkıca bağlıdır.
   `Application` süreç başlangıcını ve olay döngüsünü (event loop) yönetir.
   `App` global durumun ana erişim noktasıdır. `Context<T>`, belirli bir
   varlık güncellenirken `App`'in üstüne eklenen daha geniş bir bağlamdır.
   `Entity<T>` ve `WeakEntity<T>`, heap üzerinde tutulan durum kutularına
   güçlü ve zayıf erişim sağlar. `Task` arka plan işlerini, `Subscription` ise
   olay dinleme aboneliklerini drop edildiğinde otomatik temizleyen sahiplik
   araçlarıdır. `Global`'lar uygulama ömrü boyunca tek nüsha duran kaynaklar
   içindir. Event sistemi de varlıklar arasında tipli mesajlaşmayı kurar.
3. **Render/element katmanı.** Ekrandaki ağacı üretip çizen kısımdır. Burada
   iki ana rol vardır. `Render` trait'i, durum sahibi entity'lerin her frame'de
   yeni bir element ağacı üretmesini sağlar. `RenderOnce` ve `IntoElement`
   ise yeniden kullanılabilir, durumsuz bileşenleri tanımlar. `Element`
   trait'i layout + paint sözleşmesinin kendisidir. `div`, `canvas`,
   `list`, `uniform_list`, `img`, `svg`, `anchored` ve `surface` bu trait'in
   hazır gerçekleştirmeleridir. Üstüne `Styled` ve `InteractiveElement`
   fluent API'leri eklenir. Flex/grid stil zinciri, renkler, tıklama,
   sürükleme, focus ve scroll davranışı bu zincirlerden okunur.

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

Kısacası alttan yukarıya doğru sıralama "platform → durum → çizim" şeklindedir.
Zed bu temelin üstüne kendi UI bileşen setini ekler ve uygulamanın tanıdık
görünümünü buradan kurar. İlerleyen bölümler önce bu üç katmanı açar, son
bölümler ise Zed'in üst tabakasına döner.

## Hızlı Referans: GPUI Kavram Sözlüğü

Aşağıdaki tablo, rehber boyunca tekrar tekrar geçen temel tipleri tek bakışta
toparlamak için hazırlanmıştır. Her kavram ileride kendi bölümünde detaylıca
açılır; burada amaç bir ismin hangi katmana ait olduğunu, hangi dosyada
yaşadığını ve hangi sorumluluğu taşıdığını hızlıca hatırlatmaktır. Tablo
sırasıyla uygulama ömrü ve bağlamlardan başlar, pencere ve görev tiplerine
geçer, ardından render, etkileşim, geometri ve global kaynaklara doğru ilerler.

| Kavram | Tip | Yer | Kısa Açıklama |
|---|---|---|---|
| Application | `Application` | `gpui_platform` | Platformu seçer ve event loop'u sürer. |
| Root context | `App` | `app.rs` | Global durum, pencere ve entity oluşturma kapısı. |
| Entity | `Entity<T>` | `app/entity_map.rs` | Heap üzerinde tutulan durum handle'ı. |
| Weak handle | `WeakEntity<T>` | aynı | Döngüleri önleyen zayıf handle. |
| Update context | `Context<T>` | `app.rs` | Entity update sırasında `App`'e deref eden bağlam. |
| Async context | `AsyncApp` | `app/async_context.rs` | Await boyunca taşınabilen bağlam. |
| Pencere | `Window` | `window.rs` | Tek pencere durumu. |
| Window handle | `WindowHandle<V>` | `window.rs` | View tipini bilen window referansı. |
| Future task | `Task<T>` | `executor.rs` | Drop edildiğinde işi iptal eden future. |
| Subscription | `Subscription` | `subscription.rs` | Drop edildiğinde aboneliği kaldırır. |
| Element | `impl Element` | `element.rs` | Layout + paint sözleşmesi. |
| View | `impl Render` | `view.rs` | Stateful element ağacı üreten entity. |
| Action | `impl Action` | `action.rs` | Dispatch tree mesajı. |
| Focus handle | `FocusHandle` | `window.rs` | Focus ve tab navigasyon kimliği. |
| Hitbox | `Hitbox` | `window.rs` | Mouse hit-test alanı. |
| ScrollHandle | `ScrollHandle` | `elements/div.rs` | Paylaşılan scroll state. |
| Animation | `Animation` | `elements/animation.rs` | Süre/easing tabanlı interpolation. |
| Asset source | `AssetSource` trait | `assets.rs` | Asset byte'larını sağlayan kaynak. |
| Color | `Hsla`/`Rgba` | `color.rs` | UI renk tipleri. |
| Pixels | `Pixels` | `geometry.rs` | Mantıksal piksel. |
| Background | `Background` | `color.rs` | Düz renk, gradient veya pattern dolgusu. |
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
