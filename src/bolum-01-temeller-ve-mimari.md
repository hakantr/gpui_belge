# 1. Temeller ve Mimari

---

## 1.1. Büyük Resim

GPUI üç katmanlıdır:

1. **Platform katmanı**: macOS, Windows, Linux, web ve test ortamlarını soyutlar.
   `Platform` ve `PlatformWindow` trait'leri burada ana sözleşmedir.
2. **Uygulama/durum katmanı**: `Application`, `App`, `Context<T>`, `Entity<T>`,
   `WeakEntity<T>`, `Task`, `Subscription`, `Global` ve event sistemini yönetir.
3. **Render/element katmanı**: `Render`, `RenderOnce`, `IntoElement`, `Element`,
   `div`, `canvas`, `list`, `uniform_list`, `img`, `svg`, `anchored`, `surface`
   ve `Styled`/`InteractiveElement` fluent API'leri ile UI ağacını oluşturur.

Zed bu katmanların üstüne kendi tasarım sistemini koyar:

- `crates/ui`: Button, Icon, Label, Modal, ContextMenu, Tooltip, Tab, Table, Toggle vb.
- `crates/platform_title_bar`: platforma göre pencere kontrol butonlarını ve başlık
  çubuğu davranışını çizer.
- `crates/workspace`: ana çalışma alanını, client-side decoration gölgesini, resize
  bölgelerini ve pencere içeriğini birleştirir.

## 1.2. Hızlı Referans: GPUI Kavram Sözlüğü

| Kavram | Tip | Yer | Kısa Açıklama |
|---|---|---|---|
| Application | `Application` | `gpui_platform` | İşletim sistemine göre (Mac/Windows/Linux) doğru platform kodunu seçer ve uygulama açıldığı andan kapanana kadar tüm olayları (tıklama, klavye, çizim) işleyen ana döngüyü döndürür. |
| Root context | `App` | `app.rs` | Uygulamanın kök bağlamı. Yeni pencere açmak, entity oluşturmak ve uygulama genelindeki ayarlara/state'e erişmek için kullanılır. |
| Entity | `Entity<T>` | `app/entity_map.rs` | Heap'te tutulan bir veriye (modeline, durumuna) işaret eden tanıtıcı. State'inizi burada saklar, başka yerlerden bu handle ile erişirsiniz. |
| Weak handle | `WeakEntity<T>` | aynı | Aynı entity'ye işaret eden ama onu hayatta tutmayan zayıf referans. Karşılıklı tutmadan doğan bellek sızıntısını (cycle) engeller. |
| Update context | `Context<T>` | `app.rs` | Bir entity'yi güncellerken aldığınız özel bağlam. Hem entity'nin içine müdahale eder hem de App'in tüm imkanlarını sunar. |
| Async context | `AsyncApp` | `app/async_context.rs` | Async fonksiyonlarda `await` aralarında bile elinizde kalmaya devam edebilen uzun ömürlü bağlam. |
| Pencere | `Window` | `window.rs` | Tek bir pencerenin tüm durumu (boyut, focus, içerik, vs.). |
| Window handle | `WindowHandle<V>` | `window.rs` | Belirli bir view tipini bilen pencere referansı. Pencereye dışarıdan (başka thread'den de) komut göndermek için kullanılır. |
| Future task | `Task<T>` | `executor.rs` | Arka planda çalışan iş. Elinizdeki Task düştüğünde (drop) iş otomatik iptal olur. |
| Subscription | `Subscription` | `subscription.rs` | Bir olaya abone olunca verilen "fiş". Elden çıktığı (drop) an abonelik kapanır. |
| Element | `impl Element` | `element.rs` | Ekrana çizilen tek bir UI parçası. Boyutunu hesaplar (layout) ve kendini çizer (paint). |
| View | `impl Render` | `view.rs` | Durum tutan ve her render'da yeni bir element ağacı üreten entity. React'teki component'in karşılığı. |
| Action | `impl Action` | `action.rs` | Klavyeden veya menüden tetiklenip focus ağacında yukarı doğru iletilen komut mesajı (örn. "Save", "OpenFile"). |
| Focus handle | `FocusHandle` | `window.rs` | Bir element'in odak (focus) kimliği. Tab ile hangi sıraya geçilir, klavye girdisini kim yakalar — bunu belirler. |
| Hitbox | `Hitbox` | `window.rs` | Bir element'in mouse tıklama/hover'a tepki vereceği görünmez tepki alanı. |
| ScrollHandle | `ScrollHandle` | `elements/div.rs` | Bir scroll alanının kaydırma konumunu paylaşılabilir biçimde tutar. Programatik olarak scroll etmek için kullanılır. |
| Animation | `Animation` | `elements/animation.rs` | Belirli sürede iki değer arasında easing ile yumuşak geçiş yapan animasyon (örn. opaklığı 0'dan 1'e çıkar). |
| Asset source | `AssetSource` trait | `assets.rs` | İkon, font, resim gibi varlıkları (asset) ham byte olarak sağlayan kaynak. Diskten mi gömülüden mi geldiği fark etmez. |
| Color | `Hsla`/`Rgba` | `color.rs` | UI'da kullanılan renk tipleri. `Hsla` ton/doygunluk, `Rgba` kırmızı/yeşil/mavi tabanlıdır. |
| Pixels | `Pixels` | `geometry.rs` | Cihaz ölçeğinden bağımsız "mantıksal" piksel birimi. Retina ekranda otomatik 2x'e çevrilir. |
| Background | `Background` | `color.rs` | Bir alanın dolgusu: düz renk, gradient (renk geçişi) veya desen olabilir. |
| Keymap | `Keymap` | `keymap/` | Hangi tuş kombinasyonunun hangi action'ı tetikleyeceğini tutan tablo. Aktif panele/moda göre değişir. |
| Global | `impl Global` | `global.rs` | Tüm uygulamada tek kopyası bulunan paylaşımlı durum (örn. tema, ayarlar). |
| Event emitter | `EventEmitter<E>` | `app.rs` | Bir entity'nin başkalarına olay duyurmak için kullandığı yayıncı (örn. "değiştim", "tıklandım"). |


---
