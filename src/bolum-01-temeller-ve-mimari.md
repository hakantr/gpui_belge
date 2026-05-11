# 1. Temeller ve Mimari

---

## 1.1. Büyük Resim

GPUI mimarisini pratikte üç katman üzerinden okumak yararlı olur:

1. **Platform katmanı**: macOS, Windows, Linux, web ve test ortamlarını soyutlar.
   `Platform` ve `PlatformWindow` trait'leri burada ana sözleşmedir.
2. **Uygulama ve durum katmanı**: `Application`, `App`, `Context<T>`, `Entity<T>`,
   `WeakEntity<T>`, `Task`, `Subscription`, `Global` ve event sistemini yönetir.
3. **Render/UI öğesi katmanı**: `Render`, `RenderOnce`, `IntoElement`, `Element`,
   `div`, `canvas`, `list`, `uniform_list`, `img`, `svg`, `anchored`, `surface`
   ve `Styled`/`InteractiveElement` fluent API'leriyle UI ağacını oluşturur.

Zed, bu katmanların üstüne kendi tasarım sistemini ve uygulama kabuğunu ekler:

- `crates/ui`: Button, Icon, Label, Modal, ContextMenu, Tooltip, Tab, Table, Toggle vb.
- `crates/platform_title_bar`: platforma göre pencere kontrol butonlarını ve başlık
  çubuğu davranışını yönetir.
- `crates/workspace`: ana çalışma alanını, client-side decoration gölgesini, resize
  bölgelerini ve pencere içeriğini bir araya getirir.

## 1.2. Hızlı Referans: GPUI Kavram Sözlüğü

Bu rehberde Rust tip adları İngilizce bırakılır; çünkü kodda aynen bu isimlerle kullanılırlar. Ancak ilk okuma sırasında şu Türkçe karşılıklarla düşünmek metni kolaylaştırır: **entity = varlık**, **handle = tutamaç**, **view = görünüm**, **element = UI öğesi**, **state = durum**, **context = bağlam**. Sonraki bölümlerde bu terimler mümkün olduğunca Türkçe karşılıklarıyla birlikte kullanılır.

| Kavram | Tip | Yer | Kısa Açıklama |
|---|---|---|---|
| Application | `Application` | `gpui_platform` | İşletim sistemine göre doğru platform kodunu seçer ve uygulama kapanana kadar pencere, girdi ve çizim olaylarını ana event loop içinde yürütür. |
| Kök bağlam | `App` | `app.rs` | Uygulamanın ana bağlamı. Pencere açma, varlık (`entity`) oluşturma ve uygulama genelindeki ayarlara/duruma (`state`) erişim buradan yapılır. |
| Varlık | `Entity<T>` | `app/entity_map.rs` | Heap'te tutulan model veya durum için güçlü tutamaç (`handle`). Görünüm/model durumu burada saklanır ve diğer yerlerden bu tutamaç ile güncellenir. |
| Zayıf tutamaç | `WeakEntity<T>` | aynı | Aynı varlığa (`entity`) işaret eder ama onu hayatta tutmaz. Karşılıklı referanslardan doğabilecek referans döngülerini önler. |
| Güncelleme bağlamı | `Context<T>` | `app.rs` | Bir varlık güncellenirken alınan bağlam. Varlık durumunu değiştirmeye ve aynı anda `App` API'lerine erişmeye imkan verir. |
| Async bağlam | `AsyncApp` | `app/async_context.rs` | `await` noktaları arasında taşınabilen uygulama bağlamı. Async işlerden tekrar foreground'a dönüp uygulama durumunu güncellemek için kullanılır. |
| Pencere | `Window` | `window.rs` | Tek bir pencerenin boyut, odak, görünür içerik ve platform durumunu tutar. |
| Pencere tutamacı | `WindowHandle<V>` | `window.rs` | Belirli bir görünüm (`view`) tipini bilen pencere referansı. Pencereyi dışarıdan güncellemek veya pencereye komut göndermek için kullanılır. |
| Async iş tutamacı | `Task<T>` | `executor.rs` | Arka planda veya foreground executor'da çalışan iş. `Task` tutamacı drop edildiğinde iş iptal edilir. |
| Abonelik tutamacı | `Subscription` | `subscription.rs` | Bir olaya aboneliği temsil eder. Saklanmazsa veya drop edilirse abonelik kapanır. |
| UI öğesi | `impl Element` | `element.rs` | Ekrana çizilen tek bir UI parçası. Boyutunu hesaplar (layout) ve kendini çizer (paint). |
| Görünüm | `impl Render` | `view.rs` | Durum tutan ve her render'da yeni bir UI öğesi ağacı üreten varlık; React'teki component modeline benzer. |
| Action | `impl Action` | `action.rs` | Klavyeden, menüden veya komut paletinden tetiklenip focus ağacında yukarı doğru iletilen komut mesajı (örn. "Save", "OpenFile"). |
| Odak tutamacı | `FocusHandle` | `window.rs` | Bir UI öğesinin odak kimliği. Tab sırasını ve klavye girdisini hangi öğenin alacağını belirler. |
| Hitbox | `Hitbox` | `window.rs` | Bir UI öğesinin tıklama, hover ve imleç davranışlarına tepki veren görünmez alanı. |
| ScrollHandle | `ScrollHandle` | `elements/div.rs` | Bir scroll alanının kaydırma konumunu paylaşılabilir biçimde tutar; koddan kaydırma yapmak için kullanılır. |
| Animation | `Animation` | `elements/animation.rs` | Belirli sürede iki değer arasında easing ile yumuşak geçiş yapar (örn. opaklığı 0'dan 1'e çıkarır). |
| Asset source | `AssetSource` trait | `assets.rs` | İkon, font, resim gibi asset'leri ham byte olarak sağlayan kaynak; verinin diskten mi gömülüden mi geldiğini soyutlar. |
| Color | `Hsla`/`Rgba` | `color.rs` | UI'da kullanılan renk tipleri. `Hsla` ton/doygunluk/açıklık, `Rgba` kırmızı/yeşil/mavi/alfa bileşenleriyle çalışır. |
| Pixels | `Pixels` | `geometry.rs` | Cihaz ölçeğinden bağımsız mantıksal piksel birimi. Yüksek DPI/Retina ekranda ölçek faktörüyle fiziksel piksele çevrilir. |
| Background | `Background` | `color.rs` | Bir alanın dolgusu: düz renk, gradient veya pattern (desen) olabilir. |
| Keymap | `Keymap` | `keymap/` | Tuş kombinasyonlarını action'lara bağlayan, aktif bağlama göre değişebilen tablo. |
| Global | `impl Global` | `global.rs` | Tüm uygulamada tek kopya tutulan paylaşımlı durum (örn. tema, ayarlar). |
| Olay yayınlayıcı | `EventEmitter<E>` | `app.rs` | Bir varlığın (`entity`) başka varlıklara olay duyurmak için kullandığı yayıncı (örn. "değiştim", "tıklandım"). |


---
