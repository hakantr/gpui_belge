# 1. Temeller ve Mimari

---

## 1.1. Büyük Resim

GPUI mimarisini pratikte üç katman üzerinden okumak yararlı olur:

1. **Platform katmanı**: macOS, Windows, Linux, web ve test ortamlarını soyutlar.
   `Platform` ve `PlatformWindow` trait'leri burada ana sözleşmedir.
2. **Uygulama ve durum katmanı**: `Application`, `App`, `Context<T>`, `Entity<T>`,
   `WeakEntity<T>`, `Task`, `Subscription`, `Global` ve event sistemini yönetir.
3. **Render/element katmanı**: `Render`, `RenderOnce`, `IntoElement`, `Element`,
   `div`, `canvas`, `list`, `uniform_list`, `img`, `svg`, `anchored`, `surface`
   ve `Styled`/`InteractiveElement` fluent API'leriyle UI ağacını oluşturur.

Zed, bu katmanların üstüne kendi tasarım sistemini ve uygulama kabuğunu ekler:

- `crates/ui`: Button, Icon, Label, Modal, ContextMenu, Tooltip, Tab, Table, Toggle vb.
- `crates/platform_title_bar`: platforma göre pencere kontrol butonlarını ve başlık
  çubuğu davranışını yönetir.
- `crates/workspace`: ana çalışma alanını, client-side decoration gölgesini, resize
  bölgelerini ve pencere içeriğini bir araya getirir.

## 1.2. Hızlı Referans: GPUI Kavram Sözlüğü

| Kavram | Tip | Yer | Kısa Açıklama |
|---|---|---|---|
| Application | `Application` | `gpui_platform` | İşletim sistemine göre doğru platform kodunu seçer ve uygulama kapanana kadar pencere, girdi ve çizim olaylarını ana event loop içinde yürütür. |
| Root context | `App` | `app.rs` | Uygulamanın kök bağlamı. Pencere açma, entity oluşturma ve uygulama genelindeki ayarlara/state'e erişim buradan yapılır. |
| Entity | `Entity<T>` | `app/entity_map.rs` | Heap'te tutulan model veya durum için güçlü handle. View/model state'i burada saklanır ve diğer yerlerden bu handle ile güncellenir. |
| Weak handle | `WeakEntity<T>` | aynı | Aynı entity'ye işaret eder ama onu hayatta tutmaz. Karşılıklı referanslardan doğabilecek referans döngülerini önler. |
| Update context | `Context<T>` | `app.rs` | Bir entity güncellenirken alınan bağlam. Entity state'ini değiştirmeye ve aynı anda `App` API'lerine erişmeye imkan verir. |
| Async context | `AsyncApp` | `app/async_context.rs` | `await` noktaları arasında taşınabilen uygulama bağlamı. Async işlerden tekrar foreground'a dönüp uygulama state'ini güncellemek için kullanılır. |
| Pencere | `Window` | `window.rs` | Tek bir pencerenin boyut, odak, görünür içerik ve platform durumunu tutar. |
| Window handle | `WindowHandle<V>` | `window.rs` | Belirli bir view tipini bilen pencere referansı. Pencereyi dışarıdan güncellemek veya pencereye komut göndermek için kullanılır. |
| Future task | `Task<T>` | `executor.rs` | Arka planda veya foreground executor'da çalışan iş. `Task` handle'ı drop edildiğinde iş iptal edilir. |
| Subscription | `Subscription` | `subscription.rs` | Bir olaya abonelik handle'ı. Saklanmazsa veya drop edilirse abonelik kapanır. |
| Element | `impl Element` | `element.rs` | Ekrana çizilen tek bir UI parçası. Boyutunu hesaplar (layout) ve kendini çizer (paint). |
| View | `impl Render` | `view.rs` | Durum tutan ve her render'da yeni bir element ağacı üreten entity; React'teki component modeline benzer. |
| Action | `impl Action` | `action.rs` | Klavyeden, menüden veya komut paletinden tetiklenip focus ağacında yukarı doğru iletilen komut mesajı (örn. "Save", "OpenFile"). |
| Focus handle | `FocusHandle` | `window.rs` | Bir elementin odak kimliği. Tab sırasını ve klavye girdisini hangi öğenin alacağını belirler. |
| Hitbox | `Hitbox` | `window.rs` | Bir elementin tıklama, hover ve imleç davranışlarına tepki veren görünmez alanı. |
| ScrollHandle | `ScrollHandle` | `elements/div.rs` | Bir scroll alanının kaydırma konumunu paylaşılabilir biçimde tutar; koddan kaydırma yapmak için kullanılır. |
| Animation | `Animation` | `elements/animation.rs` | Belirli sürede iki değer arasında easing ile yumuşak geçiş yapar (örn. opaklığı 0'dan 1'e çıkarır). |
| Asset source | `AssetSource` trait | `assets.rs` | İkon, font, resim gibi asset'leri ham byte olarak sağlayan kaynak; verinin diskten mi gömülüden mi geldiğini soyutlar. |
| Color | `Hsla`/`Rgba` | `color.rs` | UI'da kullanılan renk tipleri. `Hsla` ton/doygunluk/açıklık, `Rgba` kırmızı/yeşil/mavi/alfa bileşenleriyle çalışır. |
| Pixels | `Pixels` | `geometry.rs` | Cihaz ölçeğinden bağımsız mantıksal piksel birimi. Yüksek DPI/Retina ekranda ölçek faktörüyle fiziksel piksele çevrilir. |
| Background | `Background` | `color.rs` | Bir alanın dolgusu: düz renk, gradient veya pattern (desen) olabilir. |
| Keymap | `Keymap` | `keymap/` | Tuş kombinasyonlarını action'lara bağlayan, aktif bağlama göre değişebilen tablo. |
| Global | `impl Global` | `global.rs` | Tüm uygulamada tek kopya tutulan paylaşımlı durum (örn. tema, ayarlar). |
| Event emitter | `EventEmitter<E>` | `app.rs` | Bir entity'nin başka entity'lere olay duyurmak için kullandığı yayıncı (örn. "değiştim", "tıklandım"). |


---
