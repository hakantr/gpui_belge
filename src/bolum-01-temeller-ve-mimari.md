# Bölüm I — Temeller ve Mimari

---

## 1. Büyük Resim

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

## 2. Hızlı Referans: GPUI Kavram Sözlüğü

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


---
