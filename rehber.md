# Zed GPUI Kullanım Haritası

Bu rehber, Zed içinde yeni bir pencere, başlık çubuğu, pencere dekorasyonu, platforma özel davranış, blur/transparency ve UI bileşeni eklerken başka bir kaynağa ihtiyaç duymadan doğru dosyaya ve doğru API'ye yönelebilmek için hazırlanmış kapsamlı bir başvuru kaynağıdır.

Ana kaynak dosyalar:

- GPUI çekirdeği: `crates/gpui/src/gpui.rs`, `app.rs`, `window.rs`, `platform.rs`
- Platform seçimi: `crates/gpui_platform/src/gpui_platform.rs`
- Platform uygulamaları: `crates/gpui_macos`, `crates/gpui_windows`, `crates/gpui_linux`, `crates/gpui_web`
- Zed ana pencere seçenekleri: `crates/zed/src/zed.rs`
- Zed başlık çubuğu / dekorasyon: `crates/platform_title_bar`, `crates/title_bar`, `crates/workspace/src/workspace.rs`
- Zed UI bileşenleri: `crates/ui`, metin girişi için `crates/ui_input`
- Ayarlar ve tema: `crates/settings_content`, `crates/settings`, `crates/theme_settings`, `crates/theme`

Rehber 21 ana bölüm altında 102 başlıkta organize edilmiştir; her başlık ilgili GPUI/Zed dosyasındaki tipleri, fonksiyonları ve pratik kullanım desenlerini özetler. İçindekiler aşağıdadır.

## İçindekiler


**Bölüm I — Temeller ve Mimari**

- 1. Büyük Resim
- 2. Hızlı Referans: GPUI Kavram Sözlüğü

**Bölüm II — Uygulama ve Platform**

- 3. Platform Başlatma
- 4. Application Yaşam Döngüsü ve Platform Olayları
- 5. Platform Servisleri
- 6. Platform Trait Implementasyonu ve Wrapper Sınırları
- 7. Headless, Screen Capture ve Test Renderer

**Bölüm III — Bağlamlar**

- 8. Temel Bağlamlar
- 9. WindowHandle, AnyWindowHandle ve VisualContext

**Bölüm IV — Render ve Element**

- 10. Render Modeli
- 11. Element Yaşam Döngüsü ve Draw Fazları
- 12. Element Haritası
- 13. Element ID, Element State ve Type Erasure
- 14. FluentBuilder ve Koşullu Element Üretimi
- 15. Refineable, StyleRefinement ve MergeFrom
- 16. Deferred Draw, Prepaint Order ve Overlay Katmanı

**Bölüm V — Stil, Geometri ve Renkler**

- 17. Style ve Layout Haritası
- 18. Geometri Tipleri ve Birim Yönetimi
- 19. Renkler, Gradient ve Background
- 20. SharedString, SharedUri ve Ucuz Klonlanan Tipler
- 21. WindowAppearance ve Tema Modu

**Bölüm VI — Pencere Yönetimi**

- 22. Pencere Oluşturma
- 23. Zed'de Ana Pencere Nasıl Açılır?
- 24. Display ve Çoklu Monitor
- 25. WindowKind Davranışı
- 26. Başlık Çubuğu ve Pencere Dekorasyonu
- 27. Custom Titlebar Nasıl Tanımlanır?
- 28. Kontrol Butonları Nasıl Yönetilir?
- 29. Client-Side Decoration ve Resize
- 30. Platforma Göre Dekorasyon Davranışı
- 31. Blur, Transparency ve Mica Yönetimi
- 32. Pencere Üzerinden Yapılan İşlemler
- 33. Pencere Bounds Persist ve Restore
- 34. Native Window Tabs ve SystemWindowTabController
- 35. Layer Shell ve Özel Platform Pencereleri

**Bölüm VII — Etkileşim**

- 36. Focus, Blur ve Keyboard
- 37. Mouse, Drag, Drop ve Hitbox
- 38. Drag ve Drop İçerik Üretimi
- 39. Hitbox, Cursor, Pointer Capture ve Autoscroll
- 40. Tab Sırası ve Klavye Navigasyonu
- 41. Text Input ve IME
- 42. Text Input Handler ve IME Derin Akış
- 43. Keystroke, Modifiers ve Platform Bağımsız Kısayollar

**Bölüm VIII — Action ve Keymap**

- 44. Action Sistemi Derinlemesine
- 45. Action Makro Detayları, register_action! ve Deprecated Alias
- 46. Keymap, KeyContext ve Dispatch Stack
- 47. DispatchPhase, Event Propagation ve DispatchEventResult
- 48. Action ve Keymap Runtime Introspection
- 49. Zed Keymap Dosyası, Validator ve Unbind Akışı

**Bölüm IX — Async ve State**

- 50. Async İşler
- 51. Executor, Priority, Timeout ve Test Zamanı
- 52. Task, TaskExt ve Async Hata Yönetimi
- 53. Global State, Observe ve Event
- 54. Global State Yardımcıları ve `cx.defer`
- 55. Subscription Yaşam Döngüsü
- 56. Window-bound Observer, Release ve Focus Helper Desenleri
- 57. Entity Reservation ve Çift Yönlü Referans
- 58. Entity Release, Cleanup ve Leak Detection
- 59. Entity Type Erasure, Callback Adaptörleri ve View Cache

**Bölüm X — Liste ve Sanallaştırma**

- 60. ScrollHandle ve Scroll Davranışı
- 61. List ve UniformList Sanallaştırma

**Bölüm XI — Asset, Image, Path ve Çizim**

- 62. Asset, Image ve SVG Yükleme
- 63. Asset, ImageCache ve Surface Boru Hattı
- 64. Path Çizimi ve Custom Drawing
- 65. Anchored ve Popover Konumlandırma
- 66. PaintQuad, Window Paint Primitives ve BorderStyle
- 67. Window Drawing Context Stack, Asset Fetch ve SVG Transform

**Bölüm XII — Animasyon**

- 68. Animasyon Sistemi

**Bölüm XIII — Text Sistemi**

- 69. Text, Font ve Metin Ölçümü
- 70. StyledText, TextLayout ve InteractiveText

**Bölüm XIV — Input, Sistem ve Menü**

- 71. Input, Clipboard, Prompt ve Platform Servisleri
- 72. Prompt Builder, PromptHandle ve Fallback Prompt
- 73. Uygulama Menüsü ve Dock

**Bölüm XV — Test**

- 74. Test Rehberi
- 75. Test Bağlamları ve Simülasyon

**Bölüm XVI — Inspector ve Düşük Seviye API**

- 76. Inspector ve Debug Yardımcıları
- 77. Default Colors, GPU Specs ve Platform Diagnostics
- 78. Window Runtime Snapshot, Layout Ölçümü ve Frame Zamanlama
- 79. App/Window Low-level Servisleri: Platform, Text, Palette ve Atlas
- 80. CursorStyle, FontWeight ve Sabit Enum Tabloları
- 81. Kalan GPUI Tipleri: Dış API ve Crate-İçi Sınır

**Bölüm XVII — Zed UI Bileşenleri**

- 82. Zed UI Prelude, Style Extension Trait'leri ve Component Sözleşmesi
- 83. Zed UI Bileşen Envanteri
- 84. ManagedView, DismissEvent, Modal, Popover ve Tooltip Yaşam Döngüsü

**Bölüm XVIII — Zed Workspace**

- 85. Zed Workspace Dock ve Panel Modeli
- 86. Workspace Item, Pane, Modal, Toast ve Notification Sistemi
- 87. Workspace Serialization, OpenOptions, ProjectItem ve SearchableItem
- 88. PaneGroup, NavHistory, Toolbar ve Sidebar Entegrasyonu
- 89. Workspace Notification Yardımcıları ve Async Hata Gösterimi
- 90. AppState, WorkspaceStore, WorkspaceDb ve OpenListener Akışı
- 91. Item Ayarları, Context Menu, ApplicationMenu ve Focus-Follows-Mouse

**Bölüm XIX — Zed Settings ve Theme**

- 92. Persist, Settings ve Theme Akışı (Zed Tarafı)
- 93. SettingsStore: Kayıt, Okuma, Override ve Migration
- 94. ThemeRegistry, ThemeFamily ve Tema Yükleme

**Bölüm XX — Komut Paleti ve Picker**

- 95. CommandPalette: Filter, Aliases ve Interceptor
- 96. CommandPalette Runtime Akışı, Fuzzy Arama ve Geçmiş
- 97. Picker, PickerDelegate ve PickerPopoverMenu

**Bölüm XXI — Reçeteler ve Kontrol Listeleri**

- 98. Reçeteler
- 99. Sık Hatalar ve Doğru Desenler
- 100. Yeni Pencere Eklerken Kontrol Listesi
- 101. Kısa Cevaplar
- 102. Dosya Yoluna Göre Ne Nerede?


---

## Bölüm I — Temeller ve Mimari

---

### 1. Büyük Resim

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

### 2. Hızlı Referans: GPUI Kavram Sözlüğü

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

## Bölüm II — Uygulama ve Platform

---

### 3. Platform Başlatma

Yeni GPUI uygulaması başlatmanın standart yolu:

```rust
use gpui::{App, AppContext as _, WindowOptions, div, prelude::*};
use gpui_platform::application;

struct Root;

impl Render for Root {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div().size_full().child("Hello")
    }
}

fn main() {
    application().run(|cx: &mut App| {
        if let Err(error) = cx.open_window(WindowOptions::default(), |_, cx| cx.new(|_| Root)) {
            eprintln!("failed to open window: {error:?}");
        }
    });
}
```

Zed'de pratikte `application()` çağrısı, işletim sistemine göre şu platformu seçer:

- macOS: `gpui_macos::MacPlatform::new(headless)`
- Windows: `gpui_windows::WindowsPlatform::new(headless)`
- Linux/FreeBSD: `gpui_linux::current_platform(headless)`; Wayland/X11 backend'i
  platform crate içinde seçilir.
- Web/WASM: `gpui_web::WebPlatform`

`gpui_platform::headless()` test ve başsız çalıştırma için platform sağlar.
`gpui_platform::current_headless_renderer()` şu anda test desteği altında macOS'ta
Metal headless renderer döndürür.

### 4. Application Yaşam Döngüsü ve Platform Olayları

`Application` GPUI başlamadan önceki builder katmanıdır:

```rust
let app = gpui_platform::application()
    .with_assets(Assets)
    .with_http_client(http_client)
    .with_quit_mode(QuitMode::Default);

app.on_open_urls(|urls| {
    // Platform URL open event.
});

app.on_reopen(|cx| {
    cx.activate(true);
});

app.run(|cx| {
    // Global init, keymap, windows.
});
```

Quit ve activation:

- `QuitMode::Default`: macOS'ta explicit quit, diğer platformlarda son pencere
  kapanınca quit.
- `QuitMode::LastWindowClosed`: son window kapanınca otomatik çık.
- `QuitMode::Explicit`: yalnızca `App::quit()` ile çık.
- `cx.on_app_quit(|cx| async { ... })` callback'lerinin tamamı sürdürülürken
  uygulama `gpui::SHUTDOWN_TIMEOUT: Duration = 100ms` (`app.rs:71`) süresince
  bekler. Bu eşik aşılırsa pending future'lar iptal edilip platform exit
  sürdürülür; uzun teardown işlerini fire-and-forget değil, uygun bir lifecycle
  observer'ında yap.
- `cx.activate(ignoring_other_apps)`, `cx.hide()`, `cx.hide_other_apps()`,
  `cx.unhide_other_apps()` platform app state'ini yönetir.
- `window.activate_window()`, `window.minimize_window()`,
  `window.toggle_fullscreen()` pencere seviyesidir.

Platform sinyalleri:

- `cx.on_keyboard_layout_change(...)`: klavye layout değişimi.
- `cx.keyboard_layout()` ve `cx.keyboard_mapper()`: keystroke mapping için.
- `cx.thermal_state()` ve `cx.on_thermal_state_change(...)`: yoğun render,
  indexing veya background iş throttling'i için.
- `cx.set_cursor_hide_mode(CursorHideMode::...)`: typing/action sonrası cursor
  gizleme politikasını değiştirir.
- `cx.refresh_windows()`: tüm pencereleri tek effect cycle içinde redraw'a zorlar.
- `cx.set_quit_mode(mode)`: runtime'da quit politikasını değiştirir; builder
  tarafındaki `.with_quit_mode(...)` ile aynı alanı besler.
- `cx.on_window_closed(|cx, window_id| ...)`: pencere kapandıktan sonra çalışır;
  bu noktada window artık erişilebilir değildir, yalnızca `WindowId` gelir.

Tuzaklar:

- `on_open_urls` callback'i `&mut App` almaz; app state gerekiyorsa URL'leri
  kendi queue/global state'inize aktaracak bir köprü kurun.
- `on_reopen` macOS Dock/app icon senaryosunda önemlidir; açık pencere yoksa yeni
  workspace açma mantığı burada tetiklenir.
- `refresh_windows()` state değiştirmez; yalnızca redraw effect'i planlar.

### 5. Platform Servisleri

`App` üzerinden ulaşılan ana platform servisleri (her biri `crates/gpui/src/app.rs`
içinde wrapper, gerçek davranış `Platform` trait implementasyonunda):

- Uygulama yaşam döngüsü: `quit`, `restart`, `set_restart_path`,
  `on_app_quit(|cx| async ...)`, `on_app_restart(|cx| ...)`, `activate`, `hide`,
  `hide_other_apps`, `unhide_other_apps`.
- Pencereler: `windows`, `active_window`, `window_stack`, `refresh_windows`.
- Display: `displays`, `primary_display`, `find_display`.
- Appearance: `window_appearance`, `button_layout`, `should_auto_hide_scrollbars`,
  `set_cursor_hide_mode`.
- Clipboard: `read_from_clipboard`, `write_to_clipboard`.
- Linux primary selection: `read_from_primary`, `write_to_primary`.
- macOS find pasteboard: `read_from_find_pasteboard`, `write_to_find_pasteboard`.
- Keychain / credential store: `write_credentials(url, username, password)`,
  `read_credentials(url) -> Task<Result<Option<(String, Vec<u8>)>>>`,
  `delete_credentials(url)`. Geri dönen `Task` background executor üzerinde çalışır;
  await edilebilir veya `detach_and_log_err(cx)` ile bırakılabilir.
- URL: `open_url`, `register_url_scheme`.
- Dosya/prompt: `prompt_for_paths`, `prompt_for_new_path`, `reveal_path`,
  `open_with_system`, `can_select_mixed_files_and_dirs`.
- Menü: `set_menus`, `get_menus`, `set_dock_menu`, `add_recent_document`,
  `update_jump_list`.
- Termal durum: `thermal_state`, `on_thermal_state_change`.
- Cursor görünürlüğü: `cursor_hide_mode`, `set_cursor_hide_mode`,
  `is_cursor_visible`. İşaretçi stili pencere/hitbox bağlamında
  `window.set_cursor_style(style, &hitbox)`, drag sırasında ise
  `cx.set_active_drag_cursor_style(...)` ile yönetilir.
- Screen capture: `is_screen_capture_supported`, `screen_capture_sources`.
- Klavye: `keyboard_layout()`, `keyboard_mapper()`,
  `on_keyboard_layout_change(|cx| ...)`.
- HTTP client: `http_client() -> Arc<dyn HttpClient>`,
  `set_http_client(Arc<dyn HttpClient>)`. `Application::with_http_client(...)`
  ile başlatma sırasında da set edilir; tipik olarak `crates/http_client` içindeki
  Zed varsayılanı kullanılır.
- Uygulama yolu ve compositor: `app_path() -> Result<PathBuf>` (macOS bundle path
  ya da Linux executable), `path_for_auxiliary_executable(name)` (yardımcı binary
  yolu için bundle search), `compositor_name() -> &'static str` (Linux'ta `wayland`,
  `x11`, `xwayland` gibi adlar; diğer platformlarda boş string).

`Window` üzerinden:

- `window.on_window_should_close(cx, |window, cx| -> bool)`: kullanıcı close
  butonuna bastığında çalıştırılır; `false` döndürerek kapatmayı iptal eder.
- `window.appearance()`, `window.observe_window_appearance(...)`.
- `window.tabbed_windows()`, `window.set_tabbing_identifier(...)` ve diğer native
  window tab API'leri (bkz. Bölüm 34).

Platform trait implementasyonu yazıyorsan `Platform` ve `PlatformWindow` içindeki
tüm bu sözleşmeleri karşılaman gerekir. Uygulama geliştirirken doğrudan trait'e
değil `App`/`Window` wrapper'larına dokunmak tercih edilir.

### 6. Platform Trait Implementasyonu ve Wrapper Sınırları

Uygulama kodu normalde `Platform` veya `PlatformWindow` trait'lerini doğrudan
çağırmaz; `App` ve `Window` wrapper'ları üzerinden gider. Yeni platform portu,
test platformu veya headless backend yazarken trait sözleşmesi gerekir.

`Platform` ana grupları:

- Executor/text: `background_executor`, `foreground_executor`, `text_system`.
- App lifecycle: `run`, `quit`, `restart`, `activate`, `hide`,
  `hide_other_apps`, `unhide_other_apps`, `on_quit`, `on_reopen`.
- Display/window: `displays`, `primary_display`, `active_window`,
  `window_stack`, `open_window`.
- Appearance/UI policy: `window_appearance`, `button_layout`,
  `should_auto_hide_scrollbars`, cursor visibility/style.
- URL/path/prompt: `open_url`, `on_open_urls`, `register_url_scheme`,
  `prompt_for_paths`, `prompt_for_new_path`, `reveal_path`,
  `open_with_system`.
- Menüler: `set_menus`, `get_menus`, `set_dock_menu`,
  `on_app_menu_action`, `on_will_open_app_menu`,
  `on_validate_app_menu_command`.
- Clipboard/credentials: normal clipboard, Linux primary selection, macOS find
  pasteboard, credential store task'leri.
- Screen capture ve keyboard: `is_screen_capture_supported`,
  `screen_capture_sources`, `keyboard_layout`, `keyboard_mapper`,
  `on_keyboard_layout_change`.

`PlatformWindow` ana grupları:

- Bounds/state: `bounds`, `window_bounds`, `content_size`, `resize`,
  `scale_factor`, `display`, `appearance`, `modifiers`, `capslock`.
- Input: `set_input_handler`, `take_input_handler`, `on_input`,
  `update_ime_position`.
- Window lifecycle: `activate`, `is_active`, `is_hovered`, `minimize`, `zoom`,
  `toggle_fullscreen`, `on_should_close`, `on_close`.
- Render: `on_request_frame`, `draw(scene)`, `completed_frame`,
  `sprite_atlas`, `is_subpixel_rendering_supported`.
- Decoration/hit-test: `set_title`, `set_background_appearance`,
  `on_hit_test_window_control`, `request_decorations`,
  `window_decorations`, `window_controls`.
- Platform özel: macOS tab/document APIs, Linux move/resize/menu/app-id/inset,
  Windows raw handle, test-only `render_to_image`.

Wrapper sınırı:

- `Platform::set_cursor_style` global platform cursor'ıdır; uygulama UI'ında
  hitbox'a bağlı stil için `Window::set_cursor_style` kullan.
- `PlatformWindow::prompt` native prompt döndürebilir; `Window::prompt` custom
  prompt fallback'ini de yönetir.
- `PlatformWindow::map_window` Linux map/show ayrımı için vardır; uygulama
  kodunda `WindowOptions.show` ve window wrapper davranışına güven.
- Trait default method'ları "desteklenmiyor" anlamı taşır; wrapper üzerinden
  dönen `None` veya no-op sonuçlarını platform capability olarak ele al.

### 7. Headless, Screen Capture ve Test Renderer

`crates/gpui/src/platform.rs::screen_capture_sources` ve
`crates/gpui_platform/src/gpui_platform.rs::headless()`.

Headless platform ile pencere açmadan GPUI uygulaması çalıştırmak mümkündür:

```rust
gpui_platform::headless().run(|cx: &mut App| {
    // Background tasks, asset loading, network IO; render yok.
});
```

Bu yol özellikle CLI alt komutlar, batch işler ve sunucu/benchmark süreçleri
için kullanılır. UI doğrulama veya screenshot gerekiyorsa `gpui_platform::headless`
ile karıştırmadan `HeadlessAppContext`/`VisualTestContext` kullanılır.
`gpui_platform::current_headless_renderer()` yalnızca `test-support` feature'ı
altında vardır; şu anda macOS'ta Metal headless renderer döndürebilir, diğer
platformlarda `None` olabilir.

Screen capture API'si:

```rust
let supported = cx.update(|cx| cx.is_screen_capture_supported());

let sources_rx = cx.update(|cx| cx.screen_capture_sources());
let sources = sources_rx.await??;
if let Some(source) = sources.first() {
    let stream_rx = source.stream(
        cx.foreground_executor(),
        Box::new(|frame| {
            // frame: ScreenCaptureFrame
        }),
    );
    let stream = stream_rx.await??;
    let metadata = stream.metadata()?;
}
```

`ScreenCaptureSource` her platformda farklı kaynak listesi sunar. Capture,
`ScreenCaptureSource::stream(&ForegroundExecutor, frame_callback)` ile başlar.
Dönen `oneshot::Receiver<Result<Box<dyn ScreenCaptureStream>>>` stream handle'ını
verir; frame'ler callback'e `ScreenCaptureFrame` olarak gelir.

Tuzaklar:

- macOS izinleri (`Screen Recording`) kullanıcı onayı ister; ilk çağrıda dialog
  açılır ve sonraki başlatmalarda da geçerlidir.
- Platform screen capture desteklemiyorsa `is_screen_capture_supported()` false
  dönebilir veya kaynak listesi boş olabilir.
- UI testinde gerçek platform penceresi yerine `TestAppContext`,
  `VisualTestContext` veya renderer factory verilen `HeadlessAppContext` seç.


---

## Bölüm III — Bağlamlar

---

### 8. Temel Bağlamlar

GPUI'de neredeyse her şey `cx` ile yapılır:

- `App`: global durum, pencere listesi, platform servisleri, keymap, global state,
  entity oluşturma ve pencere açma.
- `Context<T>`: bir `Entity<T>` güncellenirken gelir. `App` içine deref eder ve
  `cx.notify()`, `cx.emit(...)`, `cx.listener(...)`, `cx.observe(...)`,
  `cx.subscribe(...)`, `cx.spawn(...)` gibi entity odaklı API'leri ekler.
- `Window`: pencereye özel durum ve davranış. Focus, cursor, bounds, resize,
  title, background appearance, action dispatch, IME, prompt ve platform pencere
  işlemleri burada yapılır.
- `AsyncApp` / `AsyncWindowContext`: `await` noktaları boyunca tutulabilen async
  context. Entity/window kapanmış olabileceği için erişimler fallible olabilir.
- `TestAppContext` / `VisualTestContext`: testlerde simülasyon, zamanlayıcı ve
  görsel doğrulama için kullanılır.

Entity kullanımı:

```rust
let entity = cx.new(|cx| State::new(cx));

let value = entity.read(cx).value;

entity.update(cx, |state, cx| {
    state.value += 1;
    cx.notify();
});

let weak = entity.downgrade();
weak.update(cx, |state, cx| {
    state.value += 1;
    cx.notify();
})?;
```

Kurallar:

- Render çıktısını etkileyen state değiştiğinde `cx.notify()` çağır.
- Bir entity güncellenirken aynı entity'yi yeniden update etmeye çalışma; panic'e
  yol açabilir.
- Uzun yaşayan async işlerde `Entity<T>` yerine `WeakEntity<T>` yakala.
- `Task` düşerse iş iptal olur. Ya `await` et, ya struct alanında sakla, ya da
  `detach()` / `detach_and_log_err(cx)` kullan.

### 9. WindowHandle, AnyWindowHandle ve VisualContext

`open_window` veya test helper'ları typed `WindowHandle<V>` döndürür. Bu handle
pencerenin root view tipini bilir; `AnyWindowHandle` ise root tipini runtime'da
taşır ve gerektiğinde downcast edilir.

**Hata kaynağı:** Önceki kontrol sadece "metot adı var mı?" sorusuna baktı.
`WindowHandle<V>` ise `#[derive(Deref, DerefMut)]` ile içindeki
`AnyWindowHandle`'a deref eder. Bu yüzden bazı metotlar typed handle üzerinde
çağrılabilir görünür ama owner'ı aslında `AnyWindowHandle`'dır. Doğru denetim
`Owner::method -> dönüş tipi -> hata semantiği` üçlüsüyle yapılmalıdır.

Aynı kalıp GPUI'de en az üç başka yerde tekrar eder — denetim turunda hepsini
ayrı doğrula:

- `Entity<T>: Deref<Target = AnyEntity>` ve `WeakEntity<T>:
  Deref<Target = AnyWeakEntity>` — typed entity handle'ları untyped handle'a
  deref eder. Detay Konu 59.
- `ModifiersChangedEvent`, `ScrollWheelEvent`, `PinchEvent`, `MouseExitEvent`:
  `Deref<Target = Modifiers>` — bu dört event Modifiers metodlarını doğrudan
  açar (`event.secondary()`, `event.modified()`). `MouseDownEvent`,
  `MouseUpEvent`, `MouseMoveEvent` ise Deref *etmez*; yalnızca `modifiers`
  alanını ifşa eder. Detay Konu 80.
- `Context<'a, T>: Deref<Target = App>` — `cx.theme()`, `cx.refresh_windows()`
  gibi App metotları Context üzerinden de çağrılabilir (Konu 8).

Bu Deref aliasing pattern'ini denetim awk script'inde **state-machine** ile
takip et; basit `rg '^impl '` çıktısı `for` parçasını gevşek eşleştirdiği için
"Bu metot hangi `impl` bloğunun içinde tanımlandı?" sorusunu cevaplayamaz.

`WindowHandle<V>`:

```rust
handle.update(cx, |root: &mut Workspace, window, cx| {
    root.focus_active_pane(window, cx);
})?;

let root_ref: &Workspace = handle.read(cx)?;
let title = handle.read_with(cx, |root, cx| root.title(cx))?;
let entity = handle.entity(cx)?;
// WindowHandle::is_active `Option<bool>` döner; pencere kapanmış/geçici
// olarak ödünç alınmışsa `None`. Tipik kullanım:
let active: Option<bool> = handle.is_active(cx);

// `window_id()` owner olarak `AnyWindowHandle` metodudur; fakat
// `WindowHandle<V>: Deref<Target = AnyWindowHandle>` olduğu için bu çağrı
// method resolution ile çalışır:
let id = handle.window_id();

// Untyped handle saklamak veya AnyWindowHandle API'sini açık göstermek
// istiyorsan dönüşümü bilinçli yap:
let any: AnyWindowHandle = handle.into();
let same_id = any.window_id();
```

`AnyWindowHandle`:

```rust
if let Some(workspace) = any_handle.downcast::<Workspace>() {
    workspace.update(cx, |workspace, window, cx| {
        workspace.activate(window, cx);
    })?;
}

any_handle.update(cx, |root_view, window, cx| {
    let root_entity_id = root_view.entity_id();
    window.refresh();
    (root_entity_id, window.is_window_active())
})?;

let title = any_handle.read::<Workspace, _, _>(cx, |workspace, cx| {
    workspace.read(cx).title(cx)
})?;
```

Tam owner/metot yüzeyi:

| Owner | Metot | Dönüş | Not |
|---|---|---|---|
| `WindowHandle<V>` | `new(id)` | `Self` | Root tipini runtime'da doğrulamaz; id + `TypeId::of::<V>()` saklar. |
| `WindowHandle<V>` | `root(cx)` | `Result<Entity<V>>` | Sadece `test` veya `test-support`; root type mismatch/kapalı pencere hata. |
| `WindowHandle<V>` | `update(cx, |&mut V, &mut Window, &mut Context<V>| ...)` | `Result<R>` | Typed root view mutate eder. |
| `WindowHandle<V>` | `read(&App)` | `Result<&V>` | Kısa süreli immutable borrow; kapalı/borrowed pencere hata. |
| `WindowHandle<V>` | `read_with(cx, |&V, &App| ...)` | `Result<R>` | Callback içinde güvenli okuma. |
| `WindowHandle<V>` | `entity(cx)` | `Result<Entity<V>>` | Root entity handle'ını döndürür. |
| `WindowHandle<V>` | `is_active(&mut App)` | `Option<bool>` | Kapalı veya borrowed pencere `None`. |
| `WindowHandle<V>` deref | `window_id()` | `WindowId` | Owner `AnyWindowHandle`; deref sayesinde `handle.window_id()` çalışır. |
| `WindowHandle<V>` deref | `downcast<T>()` | `Option<WindowHandle<T>>` | Owner `AnyWindowHandle`; typed handle'da çoğu zaman gereksizdir. |
| `AnyWindowHandle` | `window_id()` | `WindowId` | Pencere kimliği. |
| `AnyWindowHandle` | `downcast<T>()` | `Option<WindowHandle<T>>` | `TypeId` eşleşmezse `None`. |
| `AnyWindowHandle` | `update(cx, |AnyView, &mut Window, &mut App| ...)` | `Result<R>` | Root type bilinmez; callback `AnyView` alır. |
| `AnyWindowHandle` | `read::<T, _, _>(cx, |Entity<T>, &App| ...)` | `Result<R>` | Önce downcast yapar, sonra typed entity okutur. |

**Denetim komutu:** Bu bölüm güncellenirken owner-metot ayrımını kaynak
üstünden tekrar çıkar. Önce kaba smoke-test (`rg` yeterli):

```sh
sed -n '5450,5650p' ../zed/crates/gpui/src/window.rs \
  | rg '^impl.*WindowHandle|^impl AnyWindowHandle|pub fn (new|root|update|read|read_with|entity|is_active|window_id|downcast)'
```

Asıl denetim ise state-machine awk gerektirir — `rg` bir `pub fn`'in hangi
`impl` bloğunun içinde tanımlandığını söylemez, awk'te kalıcı `owner` state'i
tutarak bu eşlemeyi kuruyoruz:

```sh
gawk '
  BEGIN { owner = "(file)" }
  /^impl[<[:space:]]/ {
    if (match($0, /[[:space:]]for[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)/, m)) {
      trait_name = ""
      if (match($0, /^impl(<[^>]+>)?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)/, t)) { trait_name = t[2] }
      owner = m[1] " (impl " trait_name ")"
    } else if (match($0, /^impl(<[^>]+>)?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)/, m)) {
      owner = m[2] " (inherent)"
    }
    next
  }
  /^[[:space:]]*pub (fn|const|async fn)[[:space:]]/ {
    n = $0
    sub(/^[[:space:]]*pub[[:space:]]+/, "", n)
    sub(/[[:space:]]*\{?[[:space:]]*$/, "", n)
    print FILENAME ":" FNR ":" owner ":" n
  }
' ../zed/crates/gpui/src/window.rs \
  | grep -E ':(WindowHandle|AnyWindowHandle) '
```

Bu çıktı `WindowHandle (inherent):fn read(...)` ve `AnyWindowHandle
(inherent):fn read(...)` satırlarını ayrı ayrı verir; aynı ada sahip iki
metot olduğu hemen görünür. `impl[<[:space:]]` regex'i `impl<T>...`
formundaki generic impl bloklarını da yakalar (yalnız `^impl ` kullanırsan
generic impl'leri kaçırırsın).

Context trait'leri:

- `AppContext`: `new`, `reserve_entity`, `insert_entity`, `update_entity`,
  `read_entity`, `update_window`, `with_window`, `read_window`,
  `background_spawn`, `read_global`.
- `VisualContext`: pencere bağlı context'lerde `window_handle`,
  `update_window_entity`, `new_window_entity`, `replace_root_view`, `focus`
  sağlar.
- `BorrowAppContext`: `App`, `Context<T>`, async/test context gibi farklı
  context'lerle çalışan yardımcı fonksiyonlar için ortak global API yüzeyidir.

`window.replace_root(cx, |window, cx| NewRoot::new(window, cx))` mevcut pencerenin
root entity'sini yeni bir `Render` view ile değiştirir. Async/test context'lerde
aynı işlem `replace_root_view` helper'ı üzerinden yapılır. Bu, yeni pencere
açmadan root flow değiştirmek için kullanılır; eski root'a ait subscription ve
task ownership'i ayrıca düşünülmelidir.

`with_window(entity_id, ...)` entity'nin en son render edildiği pencereyi bulur.
Entity aynı anda birden fazla pencerede render ediliyorsa bu API bilinçli bir
"current window" kısayoludur; kesin pencere gerekiyorsa `WindowHandle` sakla.


---

## Bölüm IV — Render ve Element

---

### 10. Render Modeli

Bir pencerenin root view'i `Entity<V>` olmalı ve `V: Render` implement etmelidir:

```rust
struct MyView {
    focus_handle: FocusHandle,
}

impl Render for MyView {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div()
            .id("my-view")
            .track_focus(&self.focus_handle)
            .key_context("my-view")
            .on_action(cx.listener(|this, _: &CloseWindow, window, cx| {
                window.remove_window();
            }))
            .size_full()
            .child("Content")
    }
}
```

Reusable, state taşımayan bileşenlerde `RenderOnce` kullanılır:

```rust
#[derive(IntoElement)]
struct Badge {
    label: SharedString,
}

impl RenderOnce for Badge {
    fn render(self, _window: &mut Window, _cx: &mut App) -> impl IntoElement {
        div().rounded_sm().px_2().child(self.label)
    }
}
```

`Render` mutable view state ile çalışır. `RenderOnce` sahipliği alır ve genellikle
Zed UI bileşenlerinde tercih edilir.

### 11. Element Yaşam Döngüsü ve Draw Fazları

`Element` sözleşmesi üç fazdan oluşur:

1. `request_layout(...) -> (LayoutId, RequestLayoutState)`: stil ve child layout
   istekleri Taffy layout ağacına verilir. Bu fazda paint yapılmaz.
2. `prepaint(...) -> PrepaintState`: layout bounds bilinir; hitbox, scroll state,
   element state ve ölçüm gibi paint öncesi işler yapılır.
3. `paint(...)`: scene primitive'leri üretilir. `paint_quad`, `paint_path`,
   `paint_image`, `paint_svg`, `set_cursor_style` gibi çağrılar burada yapılır.

`Window` debug assertion'ları faz ihlalini yakalar: `insert_hitbox` yalnızca
prepaint'te, `paint_*` çağrıları paint'te, `with_text_style` ve bazı ölçüm
yardımcıları prepaint/paint içinde geçerlidir.

State saklama yolları:

- View state'i: `Entity<T>` alanları.
- Element-local state: stabil `id(...)` ile `window.with_element_state` veya
  `with_optional_element_state`; aynı ID değişirse state sıfırlanır.
- Frame callback: `window.on_next_frame(...)`.
- Effect sonunda erteleme: `cx.defer(...)`, `window.defer(cx, ...)`,
  `cx.defer_in(window, ...)`.
- Sürekli redraw: `window.request_animation_frame()`.

Render katmanı:

- `Render`: entity/view state'ini her render'da element ağacına çevirir.
- `RenderOnce`: sadece elemente dönüştürülecek hafif bileşenler için uygundur.
- `ParentElement`: child kabul eden elementler.
- `Styled`: style refinement zincirine dahil olan elementler.
- `InteractiveElement`: focus, action, key, mouse, hover, drag/drop dinleyicileri.
- `StatefulInteractiveElement`: `id(...)` sonrası scroll/focus gibi stateful
  interaktif davranışlar.

Kritik kural: `cx.notify()` view render çıktısını etkileyen state değiştiğinde
çağrılır. `window.refresh()` tüm pencerenin tekrar çizimini ister; local view
state değişiminde önce `cx.notify()` tercih edilir.

### 12. Element Haritası

GPUI yerleşik elementleri:

- `div()`: neredeyse tüm layout ve container işleri. Flex/grid, style, child,
  event, focus ve window-control area destekler.
- Metin: `&'static str`, `String`, `SharedString` doğrudan element olur.
  Daha karmaşık metin için `StyledText` ve `InteractiveText`.
- `svg()`: path veya external path ile SVG çizimi.
- `img(...)`: asset, path, URL, byte kaynağı gibi image kaynaklarını çizer; loading
  ve fallback slotları destekler.
- `canvas(prepaint, paint)`: düşük seviye çizim veya hitbox/cursor gibi prepaint
  gerektiren işler için.
- `anchored()`: pencere veya belirli bir noktaya sabitlenen popover/menu gibi UI.
- `deferred(child)`: öncelikli/ertelenmiş render.
- `list(...)`: değişken yükseklikli büyük listeler.
- `uniform_list(...)`: sabit/sık ölçülebilir item yüksekliği olan verimli listeler.
- `surface(...)`: platform/native surface kaynağını element olarak gösterir.

Sık kullanılan style grupları:

- Layout: `.flex()`, `.flex_col()`, `.flex_row()`, `.grid()`, `.items_center()`,
  `.justify_between()`, `.content_stretch()`, `.size_full()`, `.w(...)`, `.h(...)`
- Spacing: `.p_*`, `.px_*`, `.gap_*`, `.m_*`
- Text: `.text_color(...)`, `.text_sm()`, `.text_xl()`, `.font_family(...)`,
  `.truncate()`, `.line_clamp(...)`
- Border/shape: `.border_1()`, `.border_color(...)`, `.rounded_sm()`
- Position: `.absolute()`, `.relative()`, `.top(...)`, `.left(...)`
- State: `.hover(...)`, `.active(...)`, `.focus(...)`, `.focus_visible(...)`,
  `.group(...)`, `.group_hover(...)`
- Interaction: `.on_click(...)`, `.on_mouse_down(...)`, `.on_scroll_wheel(...)`,
  `.on_key_down(...)`, `.on_action(...)`, `.track_focus(...)`, `.key_context(...)`

Zed içinde `ui::prelude::*` genellikle `gpui::prelude::*` yerine tercih edilir;
tasarım sistemi tiplerini de getirir.

### 13. Element ID, Element State ve Type Erasure

GPUI'de her render'da element ağacı yeniden kurulur; kalıcı element state'i için
stabil ID gerekir. Ana tipler:

- `ElementId`: `Name`, `Integer`, `NamedInteger`, `Path`, `Uuid`,
  `FocusHandle`, `CodeLocation` gibi varyantlar taşır.
- `GlobalElementId`: parent namespace zinciriyle birleşmiş gerçek ID.
- `AnyElement`: element type erasure; child listelerinde heterojen element tutar.
- `AnyView`/`AnyEntity`: view veya entity type erasure.

Element state API'leri `Window` üzerindedir ve yalnızca element çizimi sırasında
kullanılmalıdır:

```rust
let row_state = window.use_keyed_state(
    ElementId::named_usize("row", row_ix),
    cx,
    |_, cx| RowState::new(cx),
);
```

Alt seviye API:

```rust
window.with_global_id("image-cache".into(), |global_id, window| {
    window.with_element_state::<MyState, _>(global_id, |state, window| {
        let mut state = state.unwrap_or_else(MyState::default);
        state.prepare(window);
        (state.snapshot(), state)
    })
});
```

Kurallar:

- `window.with_id(element_id, |window| ...)` local element id stack'ine id push
  eder; `with_global_id` bu stack'i `GlobalElementId` haline getirir.
- Liste item'larında `use_state` yerine `use_keyed_state` kullan; `use_state`
  caller location ile ID üretir ve aynı render noktasındaki çoklu item'ları ayıramaz.
- `with_element_namespace(id, ...)` custom element içinde child ID çakışmasını
  önlemek için kullanılır.
- Aynı `GlobalElementId` ve aynı state tipi için reentrant
  `with_element_state` çağrısı panic eder.
- ID değişirse önceki frame'in state'i devam etmez; animasyon, hover, scroll ve
  image cache state'i sıfırlanır.

Type erasure kararları:

- Public component API child kabul ediyorsa `impl IntoElement` al.
- Struct içinde saklayacaksan `AnyElement` kullan.
- View/entity saklıyorsan mümkün olduğunca typed `Entity<T>` tut; yalnızca plugin,
  dock item veya heterojen koleksiyon gerekiyorsa `AnyEntity`/`AnyView` seç.

### 14. FluentBuilder ve Koşullu Element Üretimi

`crates/gpui/src/util.rs::FluentBuilder` trait'i tüm element tiplerine üç
yardımcı ekler:

```rust
pub trait FluentBuilder {
    fn map<U>(self, f: impl FnOnce(Self) -> U) -> U;
    fn when(self, condition: bool, then: impl FnOnce(Self) -> Self) -> Self;
    fn when_else(
        self,
        condition: bool,
        then: impl FnOnce(Self) -> Self,
        else_fn: impl FnOnce(Self) -> Self,
    ) -> Self;
    fn when_some<T>(self, option: Option<T>, then: impl FnOnce(Self, T) -> Self) -> Self;
    fn when_none<T>(self, option: &Option<T>, then: impl FnOnce(Self) -> Self) -> Self;
}
```

Kullanım:

```rust
div()
    .flex()
    .when(self.is_active, |this| this.bg(rgb(0xFF0000)))
    .when_some(self.icon.as_ref(), |this, icon| this.child(icon.clone()))
    .when_else(self.is_loading,
        |this| this.opacity(0.5),
        |this| this.opacity(1.0),
    )
    .map(|this| match self.density {
        UiDensity::Compact => this.gap_1(),
        UiDensity::Default => this.gap_2(),
        UiDensity::Comfortable => this.gap_4(),
    })
```

Avantajlar:

- Method chain bozulmaz; if/match dışı yapılar olmadan koşullu UI yazılır.
- Closure içine geçen element'in tipi korunur; child eklemek serbesttir.
- `map` keyfi bir transform için "escape hatch" sağlar.

Tuzaklar:

- `when` closure her render'da çalışır; ağır hesap yapma.
- Aynı element üzerinde defalarca `when_some` zinciri okunabilirliği bozarsa
  state'i normal `if let` ile pre-compute edip tek `child` çağrısı tercih edilir.
- `map` element tipini değiştirebilir; `when` ise tipi değiştirmez (refinement
  zincirinde tutulur).

### 15. Refineable, StyleRefinement ve MergeFrom

GPUI ve Zed'de iki kompozisyon paterni paralel çalışır: render zincirinde
`Refineable`, settings/tema yüklemesinde `MergeFrom`.

#### Refineable

`crates/refineable/src/refineable.rs`:

```rust
pub trait Refineable: Clone {
    type Refinement: Refineable<Refinement = Self::Refinement> + IsEmpty + Default;

    fn refine(&mut self, refinement: &Self::Refinement);
    fn refined(self, refinement: Self::Refinement) -> Self;

    fn from_cascade(cascade: &Cascade<Self>) -> Self
        where Self: Default + Sized;

    fn is_superset_of(&self, refinement: &Self::Refinement) -> bool;
    fn subtract(&self, refinement: &Self::Refinement) -> Self::Refinement;
}

pub trait IsEmpty {
    fn is_empty(&self) -> bool;
}
```

Trait sözleşmesi göründüğünden zengindir:

- `type Refinement` da `Refineable` olmalı; yani refinement'ın kendisi tekrar
  refine edilebilir (`refine_a.refine(&refine_b)` zincirleme merge için).
- Aynı `Refinement` ayrıca `IsEmpty + Default` zorunluluğunu taşır. `IsEmpty`
  "bu refinement uygulansa hiçbir alan değişir mi?" sorusunu cevaplar; merge,
  layout cache invalidation ve `subtract` çıktısı bu kontrole dayanır.
- `is_superset_of(refinement)` instance'ın halihazırda bu refinement'ı kapsayıp
  kapsamadığını söyler — gereksiz `refine` çağrılarını atlayabilirsin.
- `subtract(refinement)` aradaki farkı yeni bir refinement olarak verir.
- `from_cascade(cascade)` aşağıdaki `Cascade` yapısını default değer üzerine
  uygular; tema/stil katmanlamasının sondaki "düzleştirme" adımıdır.

`#[derive(Refineable)]` (gpui re-export'lu): orijinal struct ile aynı alanlara
sahip ama her alanı `Option`'lı hale getirilmiş `XRefinement` türü üretir.
`refine` çağrısı yalnızca `Some` alanları yazar. Aşağıdaki somut türler hep
derive ile üretilir; ayrı yazmak gerekmez:

| Refinement türü | Üreten struct | Kaynak |
|---|---|---|
| `StyleRefinement` | `Style` | `style.rs:178` |
| `TextStyleRefinement` | `TextStyle` | `style.rs` |
| `UnderlineStyleRefinement` | `UnderlineStyle` | `style.rs` |
| `StrikethroughStyleRefinement` | `StrikethroughStyle` | `style.rs` |
| `BoundsRefinement` | `Bounds` | `geometry.rs` |
| `PointRefinement` | `Point` | `geometry.rs` |
| `SizeRefinement` | `Size` | `geometry.rs` |
| `EdgesRefinement` | `Edges` | `geometry.rs` |
| `CornersRefinement` | `Corners` | `geometry.rs` |
| `GridTemplateRefinement` | `GridTemplate` | `geometry.rs` |

Bu `*Refinement` tipleri çoğunlukla doğrudan adlandırılarak kullanılmaz; fluent
API zinciri arka planda toplar. Doğrudan elle inşa etmen gereken tek tip
genelde `StyleRefinement`'tır (örn. `.hover(|style| style.bg(...))` callback
imzası).

Tipik kullanım `Style`/`StyleRefinement` (`crates/gpui/src/style.rs:178`):

```rust
let mut style = Style::default();
style.refine(&StyleRefinement::default()
    .text_size(px(20.))
    .font_weight(FontWeight::SEMIBOLD));
```

Element fluent zinciri (örn. `div().text_size(px(14.)).bg(rgb(0xff))`)
arka planda `StyleRefinement` topluyor; render sırasında base style üzerine
refine ediliyor. `TextStyle`/`TextStyleRefinement`, `HighlightStyle`,
`PlayerColors`, `ThemeColors` gibi tüm tema yapıları aynı pattern'i kullanır.

`refined(self, refinement)` immutable bir kopya üretir; "ek style ile yeni base
elde et" senaryolarında uygundur.

#### Cascade ve CascadeSlot

`Refineable` tek başına iki katmanı (base + refinement) birleştirir; daha derin
hover/focus/active akışları için `crates/refineable/src/refineable.rs:80,93`
katman yığını sağlar:

```rust
pub struct Cascade<S: Refineable>(Vec<Option<S::Refinement>>);
pub struct CascadeSlot(usize);
```

API:

- `Cascade::default()` slot 0'ı `Some(default)` ile kurar; ek slotlar başta
  `None`'dur. Slot 0 her zaman dolu kalır ve "base" refinement'tır.
- `cascade.reserve() -> CascadeSlot`: yeni `None` slot ekler ve handle döndürür.
  Hover, focus, active gibi her dinamik katman için bir slot ayrılır.
- `cascade.base() -> &mut S::Refinement`: slot 0'ı mutable verir; layout başına
  asıl style yazılır.
- `cascade.set(slot, Option<S::Refinement>)`: belirli slot'a refinement koyar
  veya `None` ile devre dışı bırakır.
- `cascade.merged() -> S::Refinement`: slot 0 üstüne diğer dolu slotları
  sırayla `refine` eder; sonraki slot önceki slotu ezer.
- `Refineable::from_cascade(&cascade) -> Self`: `default().refined(merged())`
  shortcut'ı; render sırasında nihai stili üretmek için kullanılır.

Önemli not: GPUI'nin kendi `Interactivity` katmanı (`.hover(...)`, `.active(...)`,
`.focus(...)`, `.focus_visible(...)`, `.in_focus(...)`, `.group_hover(...)`,
`.group_active(...)` zinciri) **`Cascade`/`CascadeSlot` kullanmaz**;
`Interactivity` struct'ında her durum için ayrı bir `Option<Box<StyleRefinement>>`
alanı tutar (`elements/div.rs:1681+`'deki `hover_style`, `active_style`,
`focus_style`, `in_focus_style`, `focus_visible_style`, `group_hover_style`,
`group_active_style`) ve render fazında bu refinement'ları sırayla `refine`
eder. Yani hover style'ında verdiğin `StyleRefinement::bg(...)` base
background'u ezer ama `font_size`'a dokunmazsa base'in font_size'ı korunur —
None alan "etki yok" demektir.

`Cascade<S>` ve `CascadeSlot` arayüzü `refineable` crate'inde public olarak
durur fakat GPUI çekirdeği veya Zed bu sürümde içeriden kullanmıyor;
çoklu-katmanlı (3+) refinement yığınını dışarıdan inşa etmek isteyen kütüphane
yazarları için bir uzantı noktasıdır.

#### MergeFrom

`crates/settings_content/src/merge_from.rs`:

```rust
pub trait MergeFrom {
    fn merge_from(&mut self, other: &Self);
    fn merge_from_option(&mut self, other: Option<&Self>) {
        if let Some(other) = other { self.merge_from(other); }
    }
}
```

Default kurallar:

- HashMap, BTreeMap, struct: derin merge — sadece `other`'da var olan alanlar
  yazılır.
- `Option<T>`: `None` ezmez; `Some` recursive merge eder.
- Diğer tipler (Vec, primitive): tam üzerine yazma.

`#[derive(MergeFrom)]` derive'ı struct alanları için recursive merge üretir.
Davranışı değiştirmek için `ExtendingVec<T>` (her merge'te concat) ve
`SaturatingBool` (bir kez true olunca kalır) gibi sarıcılar mevcuttur.

Settings yükleme zinciri:

1. `assets/settings/default.json` → `SettingsContent::default()` baz alınır.
2. User `~/.config/zed/settings.json` parse → `merge_from_option`.
3. Aktif profil → `merge_from_option`.
4. Worktree `.zed/settings.json` → `merge_from_option`.
5. Sonuç `Settings::from_settings(content)` ile concrete struct'a çevrilir.

Tuzaklar:

- `Refineable` zincirinde `default()` baz değeri her seferinde yeniden hesaplanır;
  ağır base style'ları cache'le.
- `MergeFrom` sıralaması alt-üst değildir: en spesifik kaynağı en sona koy
  (`local > profile > user > default`).
- Vec'leri append etmek için `ExtendingVec`; üzerine yazmak gerekiyorsa düz `Vec`.
- `Option<Option<T>>` gibi yapı yapmak istiyorsan `MergeFrom`'un default davranışı
  doğru sonucu vermeyebilir; özel impl yaz.

### 16. Deferred Draw, Prepaint Order ve Overlay Katmanı

`deferred(child)` child'ın layout'unu bulunduğu yerde tutar, fakat paint'i ancestor
paint'lerinden sonraya erteler. Popover, context menu, resize handle ve dock drop
overlay gibi "üstte çizilmeli ama layout'ta yer tutmamalı" parçalar için kullanılır.

```rust
deferred(
    anchored()
        .anchor(Anchor::TopRight)
        .position(menu_position)
        .child(menu),
)
.with_priority(1)
```

Davranış:

- `request_layout`: child normal layout alır.
- `prepaint`: child `window.defer_draw(...)` ile deferred queue'ya taşınır.
- `paint`: deferred element kendi paint'inde bir şey çizmez.
- `with_priority(n)`: aynı frame'deki deferred elementler arasında z-order verir;
  yüksek priority üstte çizilir.

`Div` prepaint yardımcıları:

- `on_children_prepainted(|bounds, window, cx| ...)`: child bounds'larını ölçüp
  sonraki paint için state üretir.
- `with_dynamic_prepaint_order(...)`: child prepaint sırasını runtime'da belirler.
  Özellikle bir child'ın autoscroll veya ölçüm sonucu diğer child'ı etkiliyorsa
  kullanılır.

Tuzaklar:

- Deferred child layout'ta yer tuttuğu için absolute/anchored konumu hâlâ doğru
  parent bounds'a bağlıdır.
- Overlay mouse'u bloke etmeliyse child içinde `.occlude()` veya
  `.block_mouse_except_scroll()` kullan.
- Priority global z-index değildir; aynı window frame içindeki deferred queue
  için geçerlidir.


---

## Bölüm V — Stil, Geometri ve Renkler

---

### 17. Style ve Layout Haritası

GPUI style sistemi CSS/Tailwind'e benzer fluent metotlardan oluşur, fakat Rust
tipleriyle daha nettir:

- Boyut: `w`, `h`, `size`, `min_w`, `max_w`, `flex_basis`, `size_full`,
  `h_auto`, `relative(f32)`, `px`, `rems`.
- Layout: `flex`, `grid`, `flex_row`, `flex_col`, `items_*`, `justify_*`,
  `content_*`, `gap_*`, `flex_wrap`, `flex_grow`, `flex_shrink`.
- Position: `relative`, `absolute`, `inset_*`, `top/right/bottom/left`,
  `z_index`.
- Overflow: plain style overflow ve stateful `.overflow_*_scroll()`.
- Background/border: `bg`, `border_*`, `border_color`, `rounded_*`,
  `box_shadow`, `opacity`.
- Text: `text_color`, `text_bg`, `text_size`, `text_*`, `font_family`,
  `font_weight`, `italic`, `line_height`, `text_ellipsis`, `line_clamp`.
- Interaction: `hover`, `active`, `focus`, `focus_visible`, `cursor_*`,
  `track_focus`, `key_context`, action/key/mouse handlers.
- Group styling: `.group("name")`, `group_hover(...)`, `group_active(...)` ve
  `group_drag_over::<T>(...)` aynı isimli interaction grubuna göre uygulanır.
- Grid placement: container için `grid_cols`, `grid_cols_min_content`,
  `grid_cols_max_content`, `grid_rows`; child için `col_start`, `col_end`,
  `col_span`, `col_span_full`, `row_start`, `row_end`, `row_span`,
  `row_span_full` kullanılır. Altta `GridTemplate`,
  `TemplateColumnMinSize` ve `GridPlacement::{Line, Span, Auto}` vardır.

Yukarıdaki fluent metotların büyük kısmı `Styled` trait body'sinde tek tek
yazılmaz; bir grup proc macro tarafından üretilir. `crates/gpui/src/styled.rs`
trait gövdesinde bu makrolar tek satır olarak invoke edilir, `gpui_macros`
crate'i ise her invoke için onlarca metot expand eder. Hangi macro hangi
metotları üretiyor:

| Proc macro (`gpui_macros::...!()`) | Üretilen fluent metotlar (Styled trait üyesi olarak) |
|---|---|
| `visibility_style_methods!()` | `visible()`, `invisible()` |
| `margin_style_methods!()` | `m_*` ile birlikte `mt_`, `mb_`, `my_`, `mx_`, `ml_`, `mr_` ve her birinin spacing scale + `auto` varyantları (`mt_auto()` gibi) |
| `padding_style_methods!()` | `p_*`, `pt_`, `pb_`, `py_`, `px_`, `pl_`, `pr_` (margin ailesinin padding karşılığı) |
| `position_style_methods!()` | `relative()`, `absolute()` ve positioned element offset prefix'leri: `inset`, `top`, `bottom`, `left`, `right` |
| `overflow_style_methods!()` | `overflow_hidden()`, `overflow_x_hidden()`, `overflow_y_hidden()` |
| `cursor_style_methods!()` | `cursor(CursorStyle)`, `cursor_default()`, `cursor_pointer()`, `cursor_text()`, `cursor_move()`, `cursor_not_allowed()`, `cursor_context_menu()`, `cursor_crosshair()`, `cursor_vertical_text()`, `cursor_alias()`, `cursor_copy()`, `cursor_no_drop()`, `cursor_grab()`, `cursor_grabbing()`, ve resize ailesi: `cursor_ew_resize()`, `cursor_ns_resize()`, `cursor_nesw_resize()`, `cursor_nwse_resize()`, `cursor_col_resize()`, `cursor_row_resize()`, `cursor_n_resize()`, `cursor_e_resize()`, `cursor_s_resize()`, `cursor_w_resize()` |
| `border_style_methods!()` | `border_color(C)` ve `border_*` width prefix'leri (`border_*`, `border_t_*`, `border_r_*`, `border_b_*`, `border_l_*`, `border_x_*`, `border_y_*`) × suffix tablosu (`_0`, `_1`, `_2`, `_4`, `_8`, vb.) |
| `box_shadow_style_methods!()` | `shadow(Vec<BoxShadow>)`, `shadow_none()`, `shadow_2xs()`, `shadow_xs()`, `shadow_sm()`, `shadow_md()`, `shadow_lg()`, `shadow_xl()`, `shadow_2xl()` |

Bu makrolar `pub` (proc) macro olarak `gpui_macros` crate'inden export edilir
ve `gpui::{visibility_style_methods, margin_style_methods, ...}` üzerinden de
yeniden re-export edilir. Doğrudan uygulama kodu çağırmaz — fluent metotlar
zaten `Styled` trait'inin parçası olduğu için her `Styled` impl'i otomatik
sahip olur.

`Styled` trait içinde ayrıca `gpui_macros::style_helpers!()` çağrısı vardır, fakat
bu proc macro `#[doc(hidden)]` olduğu ve `gpui` crate kökünden re-export
edilmediği için `target/doc/gpui/all.html` macro listesinde yer almaz. `w_*`,
`h_*`, `size_*`, `min_size_*`, `min_w_*`, `min_h_*`, `max_size_*`, `max_w_*`,
`max_h_*`, `gap_*`, `gap_x_*`, `gap_y_*` ve `rounded_*` aileleri bu internal
macrodan gelir.

Custom bir element için `Styled` impl ediyorsan trait'in tüm metotları
otomatik miras kalır; bu makroları yeniden invoke etmek gerekmez. Yalnız
GPUI'nin kendisi gibi yeni bir style framework yazıyorsan (paralel bir
`Styled` benzeri trait için) bu macro'ları kendi trait'inin içinde invoke
edebilirsin — `method_visibility` parametresi public/pub(crate) ayarına izin
verir.

Pratik kararlar:

- Görünüm state'e bağlıysa `Render` içinde koşullu `.when(...)` kullan; style'ı
  sonradan imperative değiştirmeye çalışma.
- Scroll, focus, tooltip, animation gibi stateful elementlerde ID stabil olmalıdır.
- Parent layout genişliği belirsizse text overflow, image aspect ratio ve absolute
  child konumu beklediğin sonucu vermeyebilir.
- Kart/toolbar/list gibi tekrar eden UI'da boyutları `min/max/aspect_ratio` ile
  sabitle; hover veya loading state layout shift üretmemeli.

### 18. Geometri Tipleri ve Birim Yönetimi

`crates/gpui/src/geometry.rs`.

GPUI üç farklı pixel birimi kullanır:

- `Pixels(f32)`: scale-bağımsız mantıksal piksel. UI kodunda neredeyse her zaman
  bu kullanılır.
- `ScaledPixels(f32)`: `Pixels * window.scale_factor()`. Renderer'a iletilen değer.
- `DevicePixels(i32)`: fiziksel cihaz pikseli. Asset/texture boyutlarında kullanılır.

Yardımcılar:

```rust
let p = px(12.0);                  // Pixels
let r = rems(1.5);                 // Rems
let p2 = point(px(10.), px(20.));  // Point<Pixels>
let s = size(px(100.), px(40.));   // Size<Pixels>
let b = Bounds::from_corners(point(px(0.), px(0.)), point(px(100.), px(100.)));
```

Diğer birimler:

- `Rems(f32)`: kök font boyutuna görelidir (Zed'de `theme.ui_font_size` ile bağlı).
  `.text_sm()`, `.gap_2()` gibi makro üretilen helper'lar genelde Rems üzerinden
  Pixels üretir.
- `AbsoluteLength`: `Pixels` veya `Rems`.
- `DefiniteLength`: `Absolute(AbsoluteLength)` veya `Fraction(f32)`.
- `Length`: `Definite(DefiniteLength)` veya `Auto`.

Stil API'leri Length kabul eder:

```rust
div().w(px(120.))           // Pixels
    .min_h(rems(2.))        // Rems
    .flex_basis(relative(0.5)) // Fraction
    .h_auto()
```

Generic container'lar `Point<T>`, `Size<T>`, `Bounds<T>`, `Edges<T>`, `Corners<T>`
çoğu metot için aritmetik destekler (`+`, `-`, `*`, `/`).

Kaynakta public inherent metot yüzeyi:

- `Point<T>`: `map`, `scale`, `magnitude`, `relative_to`, `max`, `min`, `clamp`.
- `Size<T>`: `new`, `map`, `center`, `scale`, `max`, `min`, `full`, `auto`,
  `to_pixels`, `to_device_pixels`.
- `Bounds<T>`: `centered`, `maximized`, `new`, `from_corners`,
  `from_anchor_and_size`, `centered_at`, `top_center`, `bottom_center`,
  `left_center`, `right_center`, `intersects`, `center`, `half_perimeter`,
  `dilate`, `extend`, `inset`, `space_within`, `top`, `bottom`, `left`,
  `right`, `top_right`, `bottom_right`, `bottom_left`, `corner`, `contains`,
  `is_contained_within`, `map`, `map_origin`, `map_size`, `localize`,
  `is_empty`, `scale`, `to_device_pixels`, `to_pixels`.
- `Edges<T>`: `all`, `map`, `any`, `auto`, `zero`, `to_pixels`, `scale`, `max`.
  Birden fazla `zero`/`to_pixels` impl'i farklı generic specialization'lardan
  gelir.
- `Corners<T>`: `all`, `corner`, `to_pixels`, `scale`, `max`,
  `clamp_radii_for_quad_size`, `map`.
- Birim wrapper'ları: `Pixels::{as_f32, floor, round, ceil, scale, pow, abs,
  signum, to_f64}`, `ScaledPixels::{as_f32, floor, round, ceil}`,
  `Rems::{is_zero, to_pixels, to_rems}`, `DevicePixels::to_bytes`.

Hazır oran sabitleri:

- `phi() -> DefiniteLength` (`geometry.rs:3698`): altın oranı `relative(1.618_034)`
  olarak döndürür — yani parent'ın **1.618 katı**, %50 değil. GPUI'nin kendisi
  default `TextStyle::line_height` değeri olarak `phi()` kullanır
  (`style.rs:451`); yani bir font için satır yüksekliği `font_size * 1.618`'dir.
  Layout oranlamada (örn. golden-ratio iki sütun) parent'ın katı olarak
  istenirse aynı sabit kullanılabilir.

Tuzaklar:

- `Bounds::contains(point)` half-open intervallere göre çalışır; sınır pikseli
  `false` dönebilir.
- `Pixels` ile `ScaledPixels` aritmetiği `From`/`Into` üzerinden açık konversiyon
  ister; örtük çevrilmez.
- `point(x, y)` argument sırası önce X sonra Y'dir; `size(width, height)` de aynı.

### 19. Renkler, Gradient ve Background

`crates/gpui/src/color.rs` ve `colors.rs`.

İki temel tip:

- `Rgba { r, g, b, a }`: 0.0–1.0 aralığında bileşenler.
- `Hsla { h, s, l, a }`: 0.0–1.0 aralığında bileşenler.

Constructor'lar:

```rust
let red = rgb(0xff0000);                    // Rgba, alfa 1.0
let translucent = rgba(0xff000080);         // 0xRRGGBBAA
let h = hsla(0.0, 1.0, 0.5, 1.0);           // saf kırmızı
let grey = opaque_grey(0.5, 1.0);           // gri yardımcısı
```

Hazır renk sabitleri (hepsi `pub const fn ... -> Hsla`, `color.rs:344+`):

| Fonksiyon | HSLA değeri | Not |
|---|---|---|
| `black()` | `(0.0, 0.0, 0.0, 1.0)` | Saf siyah |
| `white()` | `(0.0, 0.0, 1.0, 1.0)` | Saf beyaz |
| `transparent_black()` | `(0.0, 0.0, 0.0, 0.0)` | Tam saydam siyah — gradient ucu olarak kullanışlı |
| `transparent_white()` | `(0.0, 0.0, 1.0, 0.0)` | Tam saydam beyaz |
| `red()` | `(0.0, 1.0, 0.5, 1.0)` | %100 doygun kırmızı |
| `blue()` | `(0.666…, 1.0, 0.5, 1.0)` | %100 doygun mavi |
| `yellow()` | `(0.166…, 1.0, 0.5, 1.0)` | %100 doygun sarı |
| `green()` | `(0.333…, 1.0, **0.25**, 1.0)` | Diğerlerinden farklı: lightness 0.25 (koyu yeşil) |

Bunlar Zed tasarım sisteminden bağımsızdır; tema renkleri için `cx.theme().colors()`
kullan. Debug placeholder, GPU shader test'i veya tema-bağımsız palette örneği
gerekirse bu sabitler hazır gelir. `transparent_black()` `linear_gradient` ucu
olarak en yaygın kullanılan tek-parça çağrısıdır (ör. fade-out maskeleri).

Sık kullanılan metotlar (`color.rs:472+`):

- `is_transparent()`, `is_opaque()`
- `opacity(factor)`: alfayı çarpar.
- `alpha(a)`: alfayı doğrudan ayarlar.
- `fade_out(factor)`: in-place alfa azaltma.
- `blend(other)`: pre-multiplied alpha ile karıştırır.
- `grayscale()`: doygunluğu sıfırlar.
- `to_rgb()`: Hsla → Rgba.

Background tipi (`color.rs:763+`) sadece düz renk değildir:

```rust
solid_background(rgb(0xffffff))
linear_gradient(
    angle_deg,
    linear_color_stop(rgb(0x000000), 0.0),
    linear_color_stop(rgb(0xffffff), 1.0),
)
checkerboard(rgb(0xeeeeee), 8.0)
pattern_slash(rgb(0xff0000), 2.0, 6.0)
```

`linear_gradient(...).color_space(ColorSpace::Oklab)` ile renk uzayı seçilebilir;
`opacity(factor)` her stop'a uygulanır. `Background::as_solid()` yalnızca düz
renk background için `Some(Hsla)` döndürür; gradient/pattern için `None` döner.

`.bg(impl Into<Background>)` her style fluent API'sinde mevcut. Düz `Hsla` da
`Into<Background>` implement eder, bu yüzden `.bg(theme.colors().panel_background)`
tipik kullanımdır.

Pratik notlar:

- Alfa = 0 fakat opaque arka planın üzerine çiziyorsan temadaki opak rengi tercih et.
- Gradient stop'lar `0.0` ve `1.0` arasında sıralı vermeli; aksi halde GPU shader'ı
  beklenmedik dağılım verebilir.
- Hsla'da hue 1.0'a sarılmaz (clamp'lenir); rotasyon için `hue + delta` modulo 1.0
  ile hesapla.

### 20. SharedString, SharedUri ve Ucuz Klonlanan Tipler

`SharedString` GPUI'nin `gpui_shared_string` re-export'udur; `SharedUri`
`crates/gpui/src/shared_uri.rs` içinde bu string tipini sarar.

UI ağacı her render'da yeniden oluşturulduğu için string ve URI kopyalama maliyeti
hızla birikir. GPUI bunun için `Arc` tabanlı tipler sunar:

- `SharedString`: `&'static str` veya `Arc<str>`. `Clone` ucuzdur (ref-count).
  `Display`, `AsRef<str>`, `Into<SharedString>` impl'ler mevcuttur. `&'static str`,
  `String` ve `Cow<'_, str>` ücretsizce dönüşür.
- `SharedUri`: aynı stratejiyle URI; `ImageSource::Resource(Resource::Uri(...))`
  burada `SharedUri` ister.

Render içinde `String` üretip clone etmek yerine entity state'de `SharedString`
sakla:

```rust
struct Header { title: SharedString }

impl Header {
    fn set_title(&mut self, title: impl Into<SharedString>, cx: &mut Context<Self>) {
        self.title = title.into();
        cx.notify();
    }
}

impl Render for Header {
    fn render(&mut self, _: &mut Window, _: &mut Context<Self>) -> impl IntoElement {
        div().child(self.title.clone())
    }
}
```

İlgili ucuz klon tipleri:

- `Arc<str>`, `Arc<Path>`, `Arc<[T]>`: GPUI sıkça `Arc` based slice/path bekler.
- `Hsla`/`Rgba`: `Copy` tipli, doğrudan değer geçirilir.
- `ElementId`: `Clone`, internal ID veya string varyantları taşır.

Tuzaklar:

- `SharedString::from(String)` çağrısı bir kez allocation yapar; sonraki klonlar
  ücretsiz. Hot path'te tekrar tekrar `String` üretmekten kaçın.
- `to_string()` çağrısı yeni `String` allocation üretir; gerekmiyorsa
  `as_ref()` veya `Display` ile yaz.
- Format string her render'da çalışıyorsa `format!` sonucu da her frame allocation
  yapar; sonucu cache'lemek için entity state'te tut.

### 21. WindowAppearance ve Tema Modu

`crates/gpui/src/platform.rs:1604` içinde tanımlı:

```rust
pub enum WindowAppearance {
    Light,        // macOS: aqua
    VibrantLight, // macOS: NSAppearanceNameVibrantLight
    Dark,         // macOS: darkAqua
    VibrantDark,  // macOS: NSAppearanceNameVibrantDark
}
```

`Vibrant` varyantları macOS `NSAppearance` değerleriyle doğrudan eşleşir. Diğer
platformlar bu enum'u yine taşır, fakat vibrancy'nin gerçek etkisi platform
implementasyonuna bağlıdır. Sistem açık/koyu tercih ettiğinde GPUI bunu platform
appearance olarak yansıtır; kullanıcı manuel tema override yapmıyorsa Zed teması
bu sinyali takip eder.

Erişim:

- `cx.window_appearance() -> WindowAppearance`: uygulama-genel platform tercihi.
- `window.appearance() -> WindowAppearance`: pencerenin gerçek görünümü
  (parent override edebilir).
- `window.observe_window_appearance(|window, cx| ...)`: entity state'e gerek
  yoksa doğrudan pencere observer'ı.
- `cx.observe_window_appearance(window, |this, window, cx| ...)`: `Context<T>`
  içinden view state ile birlikte değişimi izle.
- `window.observe_button_layout_changed(...)` ve
  `cx.observe_button_layout_changed(window, ...)`: platform pencere kontrol
  butonu düzeni değiştiğinde çalışır.

Zed örüntüsü `crates/zed/src/main.rs` içinde tema seçimine bağlanır:

```rust
cx.observe_window_appearance(window, |_, window, cx| {
    let appearance = window.appearance();
    *SystemAppearance::global_mut(cx) = SystemAppearance(appearance.into());
    theme_settings::reload_theme(cx);
    theme_settings::reload_icon_theme(cx);
}).detach();
```

Tuzaklar:

- macOS dışında `VibrantLight`/`VibrantDark` üretilmez; eşleştirme tablosunda
  yine de tüm dört değeri ele al.
- Sistem temasını değiştirmek pencere açıldıktan sonra `window_background_appearance`
  değişimini tetiklemez; tema akışında manuel `window.set_background_appearance(...)`
  çağrısı gerekir.
- `Vibrant*` ile birlikte `WindowBackgroundAppearance::Blurred` eklenirse macOS'ta
  blur'un üzerine extra vibrancy bindirilir; tasarım sisteminde tek katman seç.


---

## Bölüm VI — Pencere Yönetimi

---

### 22. Pencere Oluşturma

Ana API:

```rust
let handle = cx.open_window(
    WindowOptions {
        window_bounds: Some(WindowBounds::centered(size(px(900.), px(700.)), cx)),
        titlebar: Some(TitlebarOptions {
            title: Some("My Window".into()),
            appears_transparent: true,
            traffic_light_position: Some(point(px(9.), px(9.))),
        }),
        focus: true,
        show: true,
        kind: WindowKind::Normal,
        is_movable: true,
        is_resizable: true,
        is_minimizable: true,
        window_min_size: Some(size(px(360.), px(240.))),
        window_background: cx.theme().window_background_appearance(),
        window_decorations: Some(gpui::WindowDecorations::Client),
        app_id: Some(ReleaseChannel::global(cx).app_id().to_owned()),
        ..Default::default()
    },
    |window, cx| {
        window.activate_window();
        cx.new(|cx| MyRootView::new(window, cx))
    },
)?;
```

`WindowOptions` alanları:

- `window_bounds`: `None` ise GPUI display default bounds seçer. `Some` verilirse
  `Windowed`, `Maximized` veya `Fullscreen` başlangıcı yapılır. Default seçilirken
  baz alınan boyut `gpui::DEFAULT_WINDOW_SIZE: Size<Pixels>` (1536×1095, ana
  Zed penceresi için) ve `gpui::DEFAULT_ADDITIONAL_WINDOW_SIZE` (900×750, 6:5
  oranında settings/rules library benzeri ek pencereler için) const'larıdır
  (`window.rs:70,74`); kendi varsayılan boyutunu override etmek istemiyorsan
  bu değerlere güvenebilirsin.
- `titlebar`: `Some(TitlebarOptions)` sistem başlık çubuğu konfigürasyonu.
  `None`, custom titlebar için kullanılır.
- `focus`: oluşturulduğunda odak alıp almayacağı.
- `show`: hemen gösterilip gösterilmeyeceği. Zed ana pencereleri başlangıçta
  `show: false`, `focus: false` ile açar ve hazır olunca gösterir.
- `kind`: `Normal`, `PopUp`, `Floating`, `Dialog`, Linux Wayland feature ile
  `LayerShell`.
- `is_movable`, `is_resizable`, `is_minimizable`: platform pencere kabiliyetleri.
- `display_id`: belirli monitor.
- `window_background`: `Opaque`, `Transparent`, `Blurred`, Windows için ayrıca
  `MicaBackdrop`, `MicaAltBackdrop`.
- `app_id`: Linux desktop grouping vb.
- `window_min_size`: minimum content size.
- `window_decorations`: `Server` veya `Client`. Linux'ta kritik; macOS/Windows'ta
  pratikte titlebar seçenekleri daha belirleyici.
- `icon`: X11 için pencere ikonu.
- `tabbing_identifier`: macOS native window tabs gruplaması.

`Window::new` içinde GPUI platform penceresini açar, sonra:

1. `platform_window.request_decorations(...)` çağırır.
2. `platform_window.set_background_appearance(window_background)` çağırır.
3. Bounds `Fullscreen` ise fullscreen, `Maximized` ise zoom uygular.
4. Platform callback'lerini bağlar.
5. İlk render'ı yapar.

### 23. Zed'de Ana Pencere Nasıl Açılır?

Zed'in ana referansı `crates/zed/src/zed.rs::build_window_options` fonksiyonudur.
Yeni ana workspace penceresi açacaksan bunu kullan:

```rust
let options = zed::build_window_options(display_uuid, cx);
let window = cx.open_window(options, |window, cx| {
    cx.new(|cx| Workspace::new(/* ... */, window, cx))
})?;
```

Bu fonksiyon şunları yapar:

- `display_uuid` ile uygun display'i bulur.
- `ZED_WINDOW_DECORATIONS=server|client` env override'ını okur.
- Aksi durumda `WorkspaceSettings::window_decorations` ayarını kullanır.
- `TitlebarOptions { appears_transparent: true, traffic_light_position: (9,9) }`
  kurar.
- `focus: false`, `show: false`, `kind: Normal` ayarlar.
- `window_background` değerini aktif temadan alır.
- Linux/FreeBSD'de app icon ekler.
- macOS native tabbing istenirse `tabbing_identifier: Some("zed")` verir.

Modal/About gibi küçük pencereler için doğrudan `WindowOptions` oluşturmak normaldir.
`crates/zed/src/zed.rs::about` örneği:

- Centered bounds
- `appears_transparent: true`
- `is_resizable: false`
- `is_minimizable: false`
- `kind: Normal`

### 24. Display ve Çoklu Monitor

Display bilgisi:

```rust
for display in cx.displays() {
    let id = display.id();
    let bounds = display.bounds();
    let visible = display.visible_bounds();
    let uuid = display.uuid().ok();
}
```

Belirli ekranda pencere açmak için:

```rust
WindowOptions {
    display_id: Some(display.id()),
    window_bounds: Some(WindowBounds::Windowed(bounds)),
    ..Default::default()
}
```

`Bounds` ekran koordinatlarıdır. `WindowBounds::centered(size, cx)` ana/default
display üzerinde merkezler. Elle konumlandırma gerekiyorsa `Bounds::new(origin, size)`
kullan.

### 25. WindowKind Davranışı

- `Normal`: ana uygulama penceresi.
- `PopUp`: diğer pencerelerin üstünde, bildirim ve geçici popup için. Zed bildirim
  pencerelerinde kullanır.
- `Floating`: parent üstünde floating panel.
- `Dialog`: parent etkileşimini kapatan modal platform penceresi.
- `LayerShell`: Wayland layer-shell feature ile dock/overlay/wallpaper benzeri
  yüzeyler için.

Pop-up/bildirim pencerelerinde tipik seçenekler:

```rust
WindowOptions {
    titlebar: None,
    kind: WindowKind::PopUp,
    focus: false,
    show: true,
    is_movable: false,
    window_background: WindowBackgroundAppearance::Transparent,
    window_decorations: Some(WindowDecorations::Client),
    ..Default::default()
}
```

Zed örnekleri: `crates/agent_ui/src/ui/agent_notification.rs`,
`crates/collab_ui/src/collab_ui.rs`.

### 26. Başlık Çubuğu ve Pencere Dekorasyonu

İki kavramı ayır:

- `TitlebarOptions`: macOS/Windows native titlebar görünümü, title ve macOS traffic
  light konumu.
- `WindowDecorations`: Linux/Wayland/X11 tarafında server-side decoration mı,
  client-side decoration mı istendiği.

GPUI tipleri:

```rust
pub enum WindowDecorations {
    Server,
    Client,
}

pub enum Decorations {
    Server,
    Client { tiling: Tiling },
}
```

`WindowDecorations`, pencere açarken istenen moddur. `Decorations`, platformun fiili
durumudur ve `window.window_decorations()` ile okunur.

Zed ayarı:

```json
{
  "window_decorations": "client"
}
```

Env override:

```sh
ZED_WINDOW_DECORATIONS=server
ZED_WINDOW_DECORATIONS=client
```

Zed settings tipi `settings_content::workspace::WindowDecorations` sadece `client`
ve `server` destekler; default `client`.

### 27. Custom Titlebar Nasıl Tanımlanır?

Basit GPUI uygulamasında:

```rust
cx.open_window(
    WindowOptions {
        titlebar: None,
        ..Default::default()
    },
    |_, cx| cx.new(|_| MyView),
)?;
```

Root view içinde kendi başlık çubuğunu çiz:

```rust
div()
    .flex()
    .flex_col()
    .size_full()
    .child(
        h_flex()
            .window_control_area(WindowControlArea::Drag)
            .h(px(34.))
            .child("Title")
    )
    .child(content)
```

Windows'ta caption button bölgeleri için `window_control_area` çok önemlidir:

- `WindowControlArea::Drag`: sürüklenebilir başlık alanı.
- `WindowControlArea::Close`: native close hit-test alanı.
- `WindowControlArea::Max`: maximize/restore hit-test alanı.
- `WindowControlArea::Min`: minimize hit-test alanı.

Zed'de yeni workspace benzeri pencere yapıyorsan custom titlebar'ı sıfırdan yazma.
`PlatformTitleBar` kullan:

```rust
let platform_titlebar = cx.new(|cx| PlatformTitleBar::new("my-titlebar", cx));

platform_titlebar.update(cx, |titlebar, _| {
    titlebar.set_children([my_left_or_center_content.into_any_element()]);
});

platform_titlebar.into_any_element()
```

`PlatformTitleBar` şunları halleder:

- Linux client-side decoration için sol/sağ pencere kontrol butonları.
- Windows pencere kontrol butonları.
- macOS traffic light padding ve double-click davranışı.
- Linux double-click ile zoom/maximize.
- Başlık çubuğu drag alanı.
- Linux'ta sağ tık window menu.
- Sidebar açıkken kontrol butonları ve köşe yuvarlamalarını ayarlama.

### 28. Kontrol Butonları Nasıl Yönetilir?

Kontrol butonları platforma göre farklı çizilir:

- macOS: native traffic lights; Zed sadece padding ve `traffic_light_position` ayarlar.
- Windows: `platform_title_bar::platforms::platform_windows::WindowsWindowControls`
  caption button render eder; her buton `WindowControlArea` ile native hit-test
  alanına bağlanır.
- Linux: `platform_title_bar::platforms::platform_linux::LinuxWindowControls`
  `WindowButtonLayout` ve `WindowControls` bilgisine göre close/min/max çizer.

Sol/sağ kontrol çizmek için hazır fonksiyonlar:

```rust
platform_title_bar::render_left_window_controls(
    cx.button_layout(),
    Box::new(workspace::CloseWindow),
    window,
)

platform_title_bar::render_right_window_controls(
    cx.button_layout(),
    Box::new(workspace::CloseWindow),
    window,
)
```

Close butonu doğrudan `window.remove_window()` çağırmaz; Zed'de close action
dispatch edilir:

```rust
window.dispatch_action(workspace::CloseWindow.boxed_clone(), cx);
```

Böylece dirty buffer, confirmation, workspace close mantığı ve keybinding ile aynı
akış kullanılır.

Linux `WindowButtonLayout`:

- `WindowButton::{Minimize, Maximize, Close}` sıralı control tipleridir; layout
  sol ve sağ taraf için `Option<WindowButton>` slot dizileri taşır. Slot başı
  sayısı `gpui::MAX_BUTTONS_PER_SIDE: usize = 3` (`platform.rs:457`) ile
  sabittir; `WindowButtonLayout::{left, right}` bu sayıda elementli dizidir.
- Platformdan `cx.button_layout()` ile gelir.
- GNOME tarzı `"close,minimize:maximize"` formatı parse edilebilir.
- Default Linux fallback: sağda minimize, maximize, close.
- `TitleBarSettings` içinde kullanıcı override'ı da vardır; `TitleBar` bunu
  `PlatformTitleBar::set_button_layout` ile geçirir.

### 29. Client-Side Decoration ve Resize

Zed'in client-side decoration wrapper'ı:

```rust
workspace::client_side_decorations(element, window, cx, border_radius_tiling)
```

Yaptıkları:

- `window.window_decorations()` ile fiili decoration modunu okur.
- Client decoration ise `window.set_client_inset(theme::CLIENT_SIDE_DECORATION_SHADOW)` çağırır.
- Server decoration ise inset'i `0` yapar.
- `window.client_inset()` platform penceresine son set edilen inset değerini
  okumak için kullanılabilir; wrapper padding/shadow hesabıyla uyumlu tutulmalıdır.
- Tiling durumuna göre köşe yuvarlamalarını kaldırır.
- Border ve shadow çizer.
- Kenar/corner bölgelerinde cursor'u resize cursor'a çevirir.
- Mouse down'da `window.start_window_resize(edge)` çağırır.

Kendi client-side decoration yapacaksan aynı prensipleri uygula:

1. Fiili modu `window.window_decorations()` ile oku.
2. Client ise gölge/invisible resize alanı kadar `set_client_inset` ver.
3. Tiling varsa ilgili kenar/köşeye radius, padding ve shadow verme.
4. Resize bölgelerinde `ResizeEdge` hesapla.
5. Hareket için titlebar'a `WindowControlArea::Drag` veya Linux/macOS için
   `window.start_window_move()` bağla.

Linux'ta server-side decoration her zaman mümkün olmayabilir:

- Wayland'de compositor decoration protocol sağlamazsa server isteği client'a düşer.
- X11'de compositor yoksa client-side decoration server'a düşebilir.

Bu yüzden pencere açarken istediğin modu değil, her render'da fiili
`window.window_decorations()` sonucunu esas al.

### 30. Platforma Göre Dekorasyon Davranışı

#### macOS

- `TitlebarOptions::appears_transparent = true` style mask'e
  `NSFullSizeContentViewWindowMask` ekler.
- `traffic_light_position` native close/min/zoom butonlarının konumunu taşır.
- `titlebar_double_click()` native double-click aksiyonunu uygular.
- `start_window_move()` native `performWindowDragWithEvent` çağırır.
- `tabbing_identifier` verilirse native window tabbing açılır.
- `WindowDecorations` pratikte platform no-op gibi davranır; macOS için başlık
  çubuğu davranışını `TitlebarOptions` belirler.

#### Windows

- `TitlebarOptions::appears_transparent` custom/full content titlebar için kullanılır.
- Caption butonlarının native hit-test davranışı `WindowControlArea` üzerinden
  `HTCLOSE`, `HTMAXBUTTON`, `HTMINBUTTON`, `HTCAPTION` olarak platform event
  katmanında eşlenir.
- `WindowBackgroundAppearance::MicaBackdrop` ve `MicaAltBackdrop` DWM backdrop
  attribute ile uygulanır.
- `WindowControls` çizimi Zed tarafında Windows component ile yapılır.

#### Linux/FreeBSD - Wayland

- `WindowDecorations::Server` xdg-decoration protocol ile istenir.
- Compositor server-side decoration desteklemiyorsa client-side'a düşülür.
- `window_controls()` Wayland capabilities bilgisinden gelir: fullscreen,
  maximize, minimize, window menu.
- `show_window_menu`, `start_window_move`, `start_window_resize` xdg_toplevel
  üzerinden compositor'a devredilir.
- Blur için compositor `blur_manager` destekliyorsa `Blurred` yüzeyde blur commit
  edilir.

#### Linux/FreeBSD - X11

- `request_decorations` `_MOTIF_WM_HINTS` yazar.
- Client-side decoration compositor gerektirir; yoksa server-side'a düşer.
- `show_window_menu` `_GTK_SHOW_WINDOW_MENU` client message gönderir.
- Move/resize `_NET_WM_MOVERESIZE` tarzı mesajla başlatılır.
- Tiling, fullscreen ve maximize state'leri `Decorations::Client { tiling }`
  sonucunu etkiler.

#### Web/WASM

- Web platformunda native pencere dekorasyonu kavramı yoktur.
- `WindowBackgroundAppearance` şu anda web window için opaque/no-op kabul edilir.
- Entry point'te `gpui_platform::web_init()` çağır.

### 31. Blur, Transparency ve Mica Yönetimi

GPUI tipi:

```rust
pub enum WindowBackgroundAppearance {
    Opaque,
    Transparent,
    Blurred,
    MicaBackdrop,
    MicaAltBackdrop,
}
```

Zed tema ayarı sadece şunları kullanıcı tema içeriğinden destekler:

```json
{
  "experimental.theme_overrides": {
    "window_background_appearance": "blurred"
  }
}
```

Desteklenen setting değerleri: `opaque`, `transparent`, `blurred`.
`MicaBackdrop` ve `MicaAltBackdrop` GPUI seviyesinde var, ancak Zed tema schema'sı
şu anda bunları expose etmiyor.

Zed akışı:

- Tema refine edilirken `WindowBackgroundContent` -> `WindowBackgroundAppearance`
  dönüştürülür.
- Ana pencere açılırken `window_background: cx.theme().window_background_appearance()`.
- Settings/theme değiştiğinde `crates/zed/src/main.rs` tüm açık pencerelerde
  `window.set_background_appearance(background_appearance)` çağırır.
- UI tarafında public yol `ui::theme_is_transparent(cx)`'dir; transparent veya
  blurred ise true döner; opak arka plan varsayan bileşenler buna göre davranmalıdır.

Platform davranışı:

- macOS:
  - `Opaque` native window opaque yapar.
  - `Transparent` ve `Blurred` için renderer transparency açılır.
  - macOS 12 öncesi blur `CGSSetWindowBackgroundBlurRadius` ile 80 radius kullanır.
  - macOS 12+ `NSVisualEffectView` tabanlı blur view ekler/kaldırır.
- Windows:
  - `Opaque`: composition attribute kapatılır.
  - `Transparent`: composition state transparent.
  - `Blurred`: acrylic/blur benzeri composition attribute.
  - `MicaBackdrop`: DWM `DWMSBT_MAINWINDOW`.
  - `MicaAltBackdrop`: DWM `DWMSBT_TABBEDWINDOW`.
- Wayland:
  - Compositor blur protocol desteklerse `Blurred` yüzeye blur uygular.
  - Aksi durumda blur isteği görünür fark yaratmayabilir.
- X11:
  - Transparent/blur renderer transparency'yi etkiler, gerçek backdrop blur window
    manager/compositor desteğine bağlıdır.

Pratik karar tablosu:

- Tema/ana pencere için: `cx.theme().window_background_appearance()` kullan.
- Geçici overlay/bildirim için: `Transparent`.
- Windows 11 özel Mica istiyorsan: doğrudan `WindowBackgroundAppearance::MicaBackdrop`
  veya `MicaAltBackdrop` kullan; fakat Zed theme setting'e otomatik bağlanmaz.
- Blur kullanıyorsan: içerikte gerçekten alfa bırak; tamamen opak root background
  blur'u görünmez yapar.

### 32. Pencere Üzerinden Yapılan İşlemler

Sık kullanılan `Window` API'leri:

- `window.bounds()`: global ekran koordinatlarında bounds.
- `window.window_bounds()`: tekrar açma/restore için `WindowBounds`.
- `window.inner_window_bounds()`: Linux inset hariç bounds.
- `window.viewport_size()`: drawable content size.
- `window.resize(size)`: content size değiştirir.
- `window.is_fullscreen()`, `window.is_maximized()`
- `window.activate_window()`
- `window.minimize_window()`
- `window.zoom_window()`
- `window.toggle_fullscreen()`
- `window.remove_window()`
- `window.set_window_title(title)`
- `window.set_app_id(app_id)`
- `window.set_background_appearance(appearance)`
- `window.set_window_edited(true/false)` macOS dirty indicator.
- `window.set_document_path(path)` macOS document accessibility/path.
- `window.show_window_menu(position)` Linux titlebar context menu.
- `window.start_window_move()`, `window.start_window_resize(edge)`
- `window.request_decorations(WindowDecorations::Client/Server)`
- `window.window_decorations()`
- `window.window_controls()`
- `window.prompt(...)`
- `window.play_system_bell()`

macOS window tab API'leri:

- `window.tabbed_windows()`
- `window.tab_bar_visible()`
- `window.merge_all_windows()`
- `window.move_tab_to_new_window()`
- `window.toggle_window_tab_overview()`
- `window.set_tabbing_identifier(...)`

### 33. Pencere Bounds Persist ve Restore

`crates/gpui/src/platform.rs::WindowBounds`, Zed tarafında
`crates/workspace/src/persistence/`, `crates/workspace/src/workspace.rs` ve
`crates/zed/src/zed.rs`.

`WindowBounds` enum üç durumu kapsar:

```rust
pub enum WindowBounds {
    Windowed(Bounds<Pixels>),
    Maximized(Bounds<Pixels>),
    Fullscreen(Bounds<Pixels>),
}
```

`Bounds` her durumda restore-ready koordinatları taşır; `Maximized`/`Fullscreen`
içindeki bounds, durum kapatıldığında dönülecek windowed bounds'tır.

Persist akışı:

```rust
let bounds = window.inner_window_bounds();
serialize(bounds, display_uuid);
```

Zed varsayılan pencere boyutu persist ederken `inner_window_bounds()` kullanır;
workspace serialize sırasında bazı akışlarda `window.window_bounds()` da kullanılır.
İkisi arasındaki fark platform/titlebar dahil edilen rect farklarına bağlıdır.
Fullscreen/maximized durumlarında enum içindeki bounds restore edilecek windowed
bounds'u temsil eder. Display UUID'si ayrı saklanır çünkü kullanıcı sonradan
monitor'ü ayırabilir.

Restore akışı `Workspace` açılırken `zed::build_window_options` üstüne uygulanır:

1. Saklı `display_uuid`, `cx.displays()` içindeki `display.uuid()` değerleriyle
   eşleştirilir.
2. Display bulunduysa `options.display_id` set edilir, kayıtlı `WindowBounds`
   `options.window_bounds` olur.
3. Workspace-specific bounds yoksa default window bounds okunur.
4. Hiç kayıt yoksa `WindowOptions.window_bounds = None` kalır ve GPUI platform
   default/cascade bounds seçer.

Bounds değişimini izlemek için:

```rust
cx.observe_window_bounds(window, |this, window, cx| {
    let bounds = window.inner_window_bounds();
    this.persist_bounds(bounds);
}).detach();
```

Aynı şekilde `cx.observe_window_appearance(window, ...)` light/dark değişimini,
`cx.observe_window_activation(window, ...)` foreground/background değişimini izler.

Tuzaklar:

- `window.bounds()` (live screen rect), `window.window_bounds()` ve
  `window.inner_window_bounds()` farklı olabilir; restore/persist akışında hangi
  rect'in beklediğini mevcut Zed çağrı noktasına göre seç.
- Maximized/fullscreen enum'larının içindeki `Bounds<Pixels>` restore size'dır;
  live platform bounds ekranı doldursa bile restore sonrası bu windowed bounds'a
  dönülür.
- Display UUID'si Linux/Wayland'de boş olabilir (`display.uuid().ok()` None döner);
  fallback gerekli.

### 34. Native Window Tabs ve SystemWindowTabController

macOS native window tabbing GPUI'de iki katmanlıdır:

- `WindowOptions::tabbing_identifier`: aynı identifier'a sahip windows native tab
  group'a girebilir.
- `SystemWindowTabController`: GPUI global'i olarak native tab gruplarını ve
  görünürlük state'ini izler.

Window API'leri:

- `window.tabbed_windows() -> Option<Vec<SystemWindowTab>>`
- `window.tab_bar_visible() -> bool`
- `window.merge_all_windows()`
- `window.move_tab_to_new_window()`
- `window.toggle_window_tab_overview()`
- `window.set_tabbing_identifier(Some(identifier))`

Kullanım kararı:

- Zed workspace tab/pane sistemi için native tabbing yerine `workspace::Pane` ve
  `TabBar` kullanılır.
- İşletim sistemi seviyesinde birden çok top-level window'u aynı native tab gruba
  almak istiyorsan `tabbing_identifier` ver.
- Native tab state'i platformdan gelir; Linux/Windows üzerinde bu API'lerin bir
  kısmı no-op veya `None` dönebilir.

Tuzaklar:

- Native window tab ile Zed pane tab aynı kavram değildir; persistence ve command
  routing farklıdır.
- Window title değiştiğinde native tab title için `window.set_window_title(...)`
  ve controller update akışı birlikte düşünülmelidir.

### 35. Layer Shell ve Özel Platform Pencereleri

Normal Zed pencereleri `WindowKind::Normal` ile açılır. Linux Wayland feature
aktifken `WindowKind::LayerShell(LayerShellOptions)` overlay/dock/wallpaper
benzeri yüzeyler için kullanılabilir:

```rust
use gpui::layer_shell::*;

WindowOptions {
    titlebar: None,
    window_background: WindowBackgroundAppearance::Transparent,
    kind: WindowKind::LayerShell(LayerShellOptions {
        namespace: "gpui".to_string(),
        layer: Layer::Overlay,
        anchor: Anchor::LEFT | Anchor::RIGHT | Anchor::BOTTOM,
        margin: Some((px(0.), px(0.), px(40.), px(0.))),
        keyboard_interactivity: KeyboardInteractivity::None,
        ..Default::default()
    }),
    ..Default::default()
}
```

Layer shell alanları:

- `Layer`: `Background`, `Bottom`, `Top`, `Overlay`.
- `layer_shell::Anchor`: bitflag; `TOP/BOTTOM/LEFT/RIGHT` kombine edilir.
- `exclusive_zone`: compositor'ın başka surface'leri bu alanı kapatmamasını ister.
- `exclusive_edge`: exclusive zone kenarı.
- `margin`: CSS sırası ile top/right/bottom/left.
- `KeyboardInteractivity`: `None`, `Exclusive`, `OnDemand`.

Bu API yalnızca `#[cfg(all(target_os = "linux", feature = "wayland"))]` altında
vardır. Compositor protocol desteklemiyorsa backend `LayerShellNotSupportedError`
döndürür; normal app penceresi fallback'i planla.


---

## Bölüm VII — Etkileşim

---

### 36. Focus, Blur ve Keyboard

Focus handle:

```rust
struct View {
    focus_handle: FocusHandle,
}

impl View {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            focus_handle: cx.focus_handle(),
        }
    }
}
```

Render:

```rust
div()
    .track_focus(&self.focus_handle)
    .focus_visible(|style| style.border_color(cx.theme().colors().border_focused))
```

Focus vermek:

```rust
self.focus_handle.focus(window, cx);
// veya
cx.focus_view(&child_entity, window);
```

Focus sorguları:

- `focus_handle.is_focused(window)`: handle doğrudan focused mı?
- `focus_handle.contains_focused(window, cx)`: bu handle veya descendant focused mı?
- `focus_handle.within_focused(window, cx)`: bu handle focused node'un içinde mi?

Focus olayları:

- `cx.on_focus(handle, window, ...)`: handle doğrudan focus aldı.
- `cx.on_focus_in(handle, window, ...)`: handle veya descendant focus aldı.
- `cx.on_blur(handle, window, ...)`: handle focus kaybetti.
- `cx.on_focus_out(handle, window, |this, event, window, cx| ...)`: handle veya
  descendant focus dışına çıktı; callback view state alır ve `FocusOutEvent`
  içinden blur'lanan handle'a (`event.blurred`) erişilebilir.
- `window.on_focus_out(handle, cx, |event, window, cx| ...)`: aynı olayın view
  state almayan düşük seviyeli `Window` varyantı; geri çağrımı `Subscription`
  olarak döner.
- `cx.on_focus_lost(window, ...)`: pencere içinde focus kalmadı.

Keyboard action akışı:

1. `actions!(namespace, [ActionA, ActionB])` veya `#[derive(Action)]` +
   `#[action(...)]` ile action tanımla.
2. Element ağacında `.key_context("context-name")` belirt.
3. `cx.bind_keys([KeyBinding::new("cmd-k", ActionA, Some("context-name"))])`.
4. Handler için `.on_action(...)`, `.capture_action(...)` veya `cx.on_action(...)` kullan.

Event propagation:

- Mouse/key event handler'lar default propagate eder.
- `cx.stop_propagation()` daha arkadaki/üstteki handler'lara gitmesini keser.
- Action bubble phase'de handler'lar default propagation'ı durdurur; gerekirse
  `cx.propagate()` kullanılır.

### 37. Mouse, Drag, Drop ve Hitbox

Element interactivity:

- `.on_click(...)`
- `.on_mouse_down(...)`, `.on_mouse_up(...)`, `.on_mouse_move(...)`
- `.on_mouse_down_out(...)`, `.on_mouse_up_out(...)`
- `.on_scroll_wheel(...)`
- `.on_pinch(...)`
- `.on_drag_move::<T>(...)`
- `.drag_over::<T>(...)`
- `.on_drop::<T>(...)`
- `.can_drop(...)`
- `.occlude()` veya `.block_mouse_except_scroll()`
- `.cursor_pointer()`, `.cursor(...)`

Pencere kontrol hitbox'ı:

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
```

Custom resize/cursor için `canvas` ile hitbox eklemek Zed'deki client decoration
desenidir:

```rust
canvas(
    |bounds, window, _cx| {
        window.insert_hitbox(bounds, HitboxBehavior::Normal)
    },
    |_bounds, hitbox, window, _cx| {
        window.set_cursor_style(CursorStyle::ResizeLeftRight, &hitbox);
    },
)
```

Burada `canvas` imzası `prepaint: FnOnce(Bounds<Pixels>, &mut Window, &mut App) -> T`
ve `paint: FnOnce(Bounds<Pixels>, T, &mut Window, &mut App)` şeklindedir; ikinci
closure'da ilk pozisyonel argüman `bounds` (kullanılmıyorsa `_bounds`), ikinci
argüman ise prepaint'in döndürdüğü değer (`hitbox`) olur. `set_cursor_style`
hitbox'a referans ister; bu yüzden `&hitbox` geçilir.

### 38. Drag ve Drop İçerik Üretimi

`crates/gpui/src/elements/div.rs:572+` ve `1271+`.

GPUI'de drag, drag edilen elementin yerine ayrı bir "ghost" view oluşturur ve
mouse'u onun ile takip eder.

```rust
div()
    .id("draggable")
    .on_drag(payload.clone(), |payload, mouse_offset, window, cx| {
        cx.new(|_| GhostView::for_payload(payload.clone(), mouse_offset))
    })
```

İmza:

```rust
fn on_drag<T, W>(
    self,
    value: T,
    constructor: impl Fn(&T, Point<Pixels>, &mut Window, &mut App) -> Entity<W> + 'static,
) -> Self
where
    T: 'static,
    W: 'static + Render;
```

- `value: T` drag payload tipidir; alıcı tarafta `on_drop::<T>` ile aynı tip ile
  bağlanır.
- `constructor` her drag başlangıcında ghost view üretir; mouse offset'i payload'a
  göre konumlandırır.
- `W: Render` ghost'un kendi entity'sidir; standart render gibi davranır.

Drop tarafı:

```rust
div()
    .drag_over::<MyPayload>(|style, payload, window, cx| {
        style.bg(rgb(0xeeeeee))
    })
    .can_drop(|payload, window, cx| {
        payload
            .downcast_ref::<MyPayload>()
            .is_some_and(|payload| payload.is_compatible(window, cx))
    })
    .on_drop::<MyPayload>(cx.listener(|this, payload: &MyPayload, window, cx| {
        this.accept(payload.clone());
        cx.notify();
    }))
```

API:

- `.on_drag::<T, W>(value, ctor)`: drag başlat.
- `.drag_over::<T>(|style, payload, window, cx| -> StyleRefinement)`: hover sırasında
  uygulanan stil refinement.
- `.can_drop(|payload: &dyn Any, window, cx| -> bool)`: drop kabul edilip
  edilmeyeceği. Tip kontrolü gerekiyorsa `downcast_ref::<T>()` kullanılır.
- `.on_drop::<T>(listener)`: drop tamamlandı.
- `.on_drag_move::<T>(listener)`: drag süresince mouse pozisyonu.
- `cx.has_active_drag()`: app genelinde aktif drag var mı?
- `cx.active_drag_cursor_style()`: aktif drag cursor override'ı.
- `cx.stop_active_drag(window)`: aktif drag'i temizler, window refresh planlar ve
  gerçekten drag vardıysa `true` döndürür. Escape/cancel path'lerinde kullanılır.

Harici sürükleme (dosya sistem drag-in) için `FileDropEvent` ve `ExternalPaths`
akışı kullanılır. Platform `FileDropEvent::Entered/Pending/Submit/Exited`
üretir; `Window::dispatch_event` bunu dahili `active_drag` durumuna ve
`ExternalPaths` payload'ına çevirir. UI tarafında normal drag/drop API'siyle
yakalanır:

```rust
div()
    .on_drag_move::<ExternalPaths>(cx.listener(|this, event, window, cx| {
        let paths = event.drag(cx).paths();
        this.preview_external_drop(paths, event.bounds, window, cx);
    }))
    .on_drop(cx.listener(|this, paths: &ExternalPaths, window, cx| {
        this.handle_external_paths_drop(paths, window, cx);
    }))
```

`ExternalPaths::paths()` `&[PathBuf]` döndürür. Ghost view platform tarafından
dosya ikonları olarak çizilir; GPUI tarafındaki `Render for ExternalPaths`
bilerek `Empty` döndürür.

Tuzaklar:

- Drag edilen tip `T: 'static` olmalıdır; lifetime taşıyan tip kabul edilmez.
- Aynı element üzerinde `on_drag` iki kez çağrılırsa panic ("calling on_drag more
  than once on the same element is not supported").
- Ghost view her drag'de yeni `cx.new(...)` ile yaratılır; yan etkilerden kaçın.
- `can_drop` false dönerse `drag_over`/`group_drag_over` stilleri uygulanmaz ve
  `on_drop` çağrılmaz; kabul edilmeyen hedefin visual feedback'ini ayrı state ile
  göstermen gerekiyorsa `on_drag_move` kullan.

### 39. Hitbox, Cursor, Pointer Capture ve Autoscroll

Hitbox, mouse hit-test ve cursor davranışının temelidir. Element handler'ları çoğu
zaman bunu senin yerine kurar; custom canvas/element yazarken doğrudan kullanılır.

```rust
let hitbox = window.insert_hitbox(bounds, HitboxBehavior::Normal);
if hitbox.is_hovered(window) {
    window.set_cursor_style(CursorStyle::PointingHand, &hitbox);
}
```

Davranış tipleri:

- `HitboxBehavior::Normal`: arkadaki hitbox'ları etkilemez.
- `HitboxBehavior::BlockMouse`: arkadaki mouse, hover, tooltip ve scroll hitbox
  davranışlarını bloke eder; `.occlude()` bunu kullanır.
- `HitboxBehavior::BlockMouseExceptScroll`: arkadaki mouse interaction'ı bloke
  eder ama scroll seçimini geçirebilir; `.block_mouse_except_scroll()` bunu kullanır.

Pointer capture:

```rust
window.capture_pointer(hitbox.id);
// drag/resize bittiğinde
window.release_pointer();
```

Capture aktifken ilgili hitbox hovered sayılır; resize handle ve sürükleme
etkileşimlerinde mouse bounds dışına çıksa bile hareketi takip etmek için kullanılır.
`window.captured_hitbox()` aktif capture id'sini döndürür; custom element debug
veya nested drag state ayrıştırması dışında genelde gerekmez.

Autoscroll:

- `window.request_autoscroll(bounds)`: drag sırasında viewport kenarına yakın
  bölge için autoscroll talep eder.
- `window.take_autoscroll()`: scroll container tarafında talebi tüketir.

Cursor:

- `window.set_cursor_style(style, &hitbox)`: hitbox hovered ise cursor ayarlar.
- `window.set_window_cursor_style(style)`: window genel cursor state'i.
- `cx.set_active_drag_cursor_style(style, window)`: aktif drag payload'ı için
  cursor override.
- `cx.active_drag_cursor_style()` mevcut drag cursor'unu okur.

Tuzaklar:

- `Hitbox::is_hovered` keyboard input modality sırasında false dönebilir; scroll
  handler yazarken `should_handle_scroll` kullan.
- Overlay elementleri `.occlude()` kullanmazsa arkadaki butonlar hover/click
  almaya devam edebilir.
- Pointer capture release edilmezse sonraki mouse hareketlerinde yanlış hitbox
  hovered kalabilir.

### 40. Tab Sırası ve Klavye Navigasyonu

`crates/gpui/src/tab_stop.rs`, `window.rs:397`.

Tab navigasyonu `FocusHandle` üzerindeki iki bayrakla kontrol edilir:

```rust
let handle = cx.focus_handle()
    .tab_stop(true)        // Tab tuşuyla durulabilir
    .tab_index(0);         // Sıra path'ine katılır
```

Tab traversal sırası TabStopMap içindeki node sıralamasına göre belirlenir:

1. Aynı grup içinde `tab_index` küçükten büyüğe.
2. `tab_index` eşitse element ağaç sırası (DFS).
3. `tab_stop(false)` olan handle sırada konum tutar ama klavyeyle durak olmaz.
   Negatif `tab_index` özel olarak "devre dışı" anlamına gelmez; sadece sıralamada
   daha erken bir path değeri üretir.

Grup oluşturmak için element tarafında `.tab_group()` kullanılır; grubun sırası
gerekiyorsa aynı elemente `.tab_index(index)` verilir. `TabStopMap::begin_group`
ve `end_group` internal traversal operasyonlarıdır; uygulama kodu genelde bunları
doğrudan çağırmaz.

Custom element yazarken low-level karşılığı `window.with_tab_group(Some(index),
|window| ...)` çağrısıdır; `None` verirsen grup açmadan closure'ı çalıştırır.
Normal component kodunda `.tab_group()` fluent API'si tercih edilir.

Window üzerindeki yardımcılar:

- `window.focus_next(cx)` / `window.focus_prev(cx)`: Tab/Shift-Tab sırasında çağrılır.
- `window.focused(cx)`: o anki odak handle'ı.

Custom input bileşeni yazıyorsan:

```rust
div()
    .track_focus(&self.focus_handle)
    .on_action(cx.listener(|this, _: &menu::Confirm, window, cx| { ... }))
    .child(/* ... */)
```

`tab_stop(true)` olmadan handle yalnızca programatik focus alır; klavyeyle
ulaşılamaz. Aksesibilite ve form akışı için her interaktif element bir handle'a
sahip olmalı.

### 41. Text Input ve IME

Platform IME entegrasyonu `InputHandler` üzerinden çalışır. Editor benzeri metin
alanları şunları sağlamalıdır:

- `selected_text_range`
- `marked_text_range`
- `text_for_range`
- `replace_text_in_range`
- `replace_and_mark_text_in_range`
- `unmark_text`
- `bounds_for_range`
- `character_index_for_point`
- `accepts_text_input`

Ham `InputHandler` implementasyonu yazıyorsan ayrıca
`prefers_ime_for_printable_keys` override edilebilir. Ancak yaygın view yolu olan
`EntityInputHandler` + `ElementInputHandler` ikilisinde bu ayrı bir hook değildir;
mevcut wrapper `prefers_ime_for_printable_keys` için `accepts_text_input`
sonucunu kullanır. IME/keybinding önceliğini `accepts_text_input`'tan bağımsız
yönetmen gerekiyorsa doğrudan `InputHandler` implement eden özel handler yaz.

IME aday penceresini doğru yerde tutmak için:

```rust
window.invalidate_character_coordinates();
```

Zed'de form tipi tek satır input için doğrudan editor yazmak yerine
`ui_input::InputField` kullan. Bu crate editor'a bağlı olduğu için `ui` içinde
değildir.

`ui_input` public yüzeyi:

- `pub use input_field::*`; ana component `InputField`.
- `InputField::new(window, cx, placeholder_text)` tek satır editor instance'ı
  ister ve placeholder'ı hemen editor'a yazar.
- Builder/metotlar: `.start_icon(IconName)`, `.label(...)`,
  `.label_size(LabelSize)`, `.label_min_width(Length)`, `.tab_index(isize)`,
  `.tab_stop(bool)`, `.masked(bool)`, `.is_empty(cx)`, `.editor()`,
  `.text(cx)`, `.clear(window, cx)`, `.set_text(text, window, cx)`,
  `.set_masked(masked, window, cx)`.
- `InputFieldStyle` public struct olarak görünür ama alanları private; dışarıdan
  style override sözleşmesi değil, render içi tema snapshot'ıdır.
- `ErasedEditor` trait'i editor köprüsüdür: `text`, `set_text`, `clear`,
  `set_placeholder_text`, `move_selection_to_end`, `set_masked`,
  `focus_handle`, `subscribe`, `render`, `as_any`.
- `ErasedEditorEvent::{BufferEdited, Blurred}` picker/search gibi üst
  bileşenlerin edit/blur akışını dinlemesi için kullanılır.
- `ERASED_EDITOR_FACTORY: OnceLock<fn(&mut Window, &mut App) -> Arc<dyn
  ErasedEditor>>` editor crate tarafından kurulur. Zed'de
  `crates/editor/src/editor.rs` init akışında bu factory
  `Editor::single_line(window, cx)` döndüren `ErasedEditorImpl` ile set edilir.
  `InputField::new` factory unset ise panic eder; bu yüzden uygulama init
  sırası editor kurulumu tamamlandıktan sonra `InputField` oluşturmaya dayanır.

### 42. Text Input Handler ve IME Derin Akış

Metin düzenleyen custom element yazıyorsan yalnızca key event dinlemek yeterli
değildir. IME, dead key, marked text ve candidate window için platforma
`InputHandler` vermen gerekir.

View tarafı:

```rust
impl EntityInputHandler for EditorLikeView {
    fn selected_text_range(
        &mut self,
        ignore_disabled_input: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<UTF16Selection> {
        self.selection_utf16(ignore_disabled_input, window, cx)
    }

    fn marked_text_range(
        &self,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<Range<usize>> {
        self.marked_range_utf16(window, cx)
    }

    fn unmark_text(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        self.clear_marked_text(window, cx);
    }

    // text_for_range, replace_text_in_range,
    // replace_and_mark_text_in_range, bounds_for_range,
    // character_index_for_point da uygulanır.
}
```

Element paint sırasında:

```rust
window.handle_input(
    &focus_handle,
    ElementInputHandler::new(bounds, view_entity.clone()),
    cx,
);
```

Kurallar:

- Range değerleri UTF-16 offset'idir; Rust byte index'iyle karıştırma.
- `bounds_for_range` screen/candidate positioning için doğru absolute bounds
  döndürmelidir.
- Cursor/selection hareketinden sonra `window.invalidate_character_coordinates()`
  çağır; IME paneli yeni konuma taşınır.
- `accepts_text_input` false ise platform text insertion engellenebilir.
- Raw `InputHandler::prefers_ime_for_printable_keys` true ise non-ASCII IME
  aktifken printable tuşlar keybinding'den önce IME'ye gider. `ElementInputHandler`
  ile sarılan `EntityInputHandler` için GPUI bu kararı `accepts_text_input`
  üzerinden verir; trait'te ayrı bir override noktası yoktur.

Tuzaklar:

- Sadece `.on_key_down` ile text editor yazmak IME ve dead-key dillerinde bozulur.
- UTF-16 range'i byte slice'a doğrudan uygulamak çok byte'lı karakterlerde panic
  veya yanlış seçim üretir.
- Input handler frame'e bağlıdır; focused element paint edilmezse platform input
  handler da düşer.

### 43. Keystroke, Modifiers ve Platform Bağımsız Kısayollar

`crates/gpui/src/platform/keystroke.rs` klavye girdisinin normalized modelidir.
Keymap sadece action binding değildir; pending input, IME ve gösterim metni de
bu tiplerle taşınır.

Ana tipler:

- `Keystroke { modifiers, key, key_char }`: gerçek input. `key` basılan tuşun
  ASCII karşılığıdır (örn. option-s için `s`); `key_char` o tuşla üretilebilecek
  karakteri tutar (örn. option-s için `Some("ß")`, cmd-s için `None`). Asciiye
  çevrilemeyen layout'larda `key` yine ASCII fallback'idir, asıl yazılan
  karakter `key_char`'a düşer. Ayrı bir `ime_key` alanı yoktur.
- `KeybindingKeystroke`: binding dosyalarında görünen display modifier/key ile
  eşleşme için kullanılan sarıcı.
- `InvalidKeystrokeError`: parse hatası. Hatanın `Display` çıktısı
  `gpui::KEYSTROKE_PARSE_EXPECTED_MESSAGE: &str` const'ını şablon olarak
  kullanır (`platform/keystroke.rs:69`); kullanıcı keymap parser'ında aynı
  bekleyiş cümlesini göstermek istersen bu sabite bağlan.
- `Modifiers`: `control`, `alt`, `shift`, `platform`, `function` alanları.
- `AsKeystroke`: hem `Keystroke` hem display wrapper'ları üzerinden ortak
  keystroke erişimi sağlayan küçük trait.
- `Capslock { on }`: platform input snapshot'ında capslock durumunu taşır.

Kullanım:

```rust
let keystroke = Keystroke::parse("cmd-shift-p")?;
let text = keystroke.unparse();
let handled = window.dispatch_keystroke(keystroke, cx);
```

Modifier yardımcıları:

- `Modifiers::none()`, `command()`, `windows()`, `super_key()`,
  `secondary_key()`, `control()`, `alt()`, `shift()`, `function()`,
  `command_shift()`, `control_shift()`.
- `command()`, `windows()`, `super_key()` üçü de aynı şeyi yapar:
  `Modifiers { platform: true, .. }` üretir. Tek bir `platform` field'ı OS'a
  göre command (macOS), windows (Windows) veya super (Linux) anlamına gelir;
  bu üç constructor sadece kavramsal vurgu için ayrı isimle export edilir.
- `secondary_key()` macOS'ta command, Linux/Windows'ta control üretir; Zed'de
  platform bağımsız kısayol yazarken çoğu durumda doğru seçim budur.
- `modified()`, `secondary()`, `number_of_modifiers()`,
  `is_subset_of(&other)` input ayrıştırmada kullanılır.

IME:

- `Keystroke::is_ime_in_progress()` IME composition sırasında true döner.
- `window.dispatch_keystroke(...)` test/simülasyon path'inde
  `with_simulated_ime()` uygular; doğrudan lower-level event üretirken IME
  state'ini ayrıca düşünmek gerekir.

`KeybindingKeystroke` yüzeyi:

- `KeybindingKeystroke::new_with_mapper(inner, use_key_equivalents,
  keyboard_mapper)`: platform keyboard mapper üzerinden display key/modifier
  üretir. `from_keystroke(keystroke)` platform mapping yapmadan sarar.
  Windows'ta `new(inner, display_modifiers, display_key)` constructor'ı da vardır;
  macOS/Linux build'lerinde bu constructor yoktur.
- `inner()`, `modifiers()`, `key()` getter'ları display ve gerçek keystroke
  ayrımını saklar. Windows'ta `modifiers()`/`key()` display değerini döndürebilir;
  gerçek GPUI input'u için `inner()` okunur.
- `set_modifiers(...)`, `set_key(...)`, `remove_key_char()` ve `unparse()`
  keybinding editor/normalizer akışında kullanılır. `remove_key_char()` yalnız
  `inner.key_char = None` yapar; `key` alanını silmez.

Binding sorguları:

- `window.bindings_for_action(&Action)` ve `window.keystroke_text_for(&Action)`
  kullanıcıya gösterilecek kısayol metni için tercih edilir.
- `cx.all_bindings_for_input(&[Keystroke])` ve
  `window.possible_bindings_for_input(&[Keystroke])` multi-stroke veya prefix
  binding durumlarında kullanılabilir.
- `window.pending_input_keystrokes()` henüz tamamlanmamış input zincirini verir.


---

## Bölüm VIII — Action ve Keymap

---

### 44. Action Sistemi Derinlemesine

`crates/gpui/src/action.rs`, `key_dispatch.rs`.

Action tanımının iki ana yolu vardır.

Veri taşımayan action:

```rust
use gpui::actions;
actions!(my_namespace, [Save, Close, Reload]);
```

`actions!` makrosu her isim için unit struct ve `Action` impl üretir; namespace
`my_namespace::Save` adıyla registry'ye kaydolur.

Veri taşıyan action:

```rust
use gpui::Action;

#[derive(Clone, PartialEq, serde::Deserialize, schemars::JsonSchema, Action)]
#[action(namespace = editor)]
pub struct GoToLine { pub line: u32 }
```

`#[action(namespace = ..., name = "...", no_json, no_register,
deprecated_aliases = [...], deprecated = "...")]` attribute'leri kontrol sağlar.
Default olarak `Deserialize` derive edilmesi ve `JsonSchema` implement edilmesi
beklenir; pure code action için `no_json` kullan, register edilmesini
istemiyorsan `no_register` ekle.

Dispatch:

- `window.dispatch_action(action.boxed_clone(), cx)`: focused element'ten root'a doğru
  bubble.
- `focus_handle.dispatch_action(&action, window, cx)`: belirli handle'dan başlatır.
- Keymap girdileri eşleştiğinde otomatik dispatch edilir.

Listener kaydı:

```rust
.on_action(cx.listener(|this, action: &GoToLine, window, cx| {
    this.go_to(action.line);
    cx.notify();
}))
.capture_action(cx.listener(handler)) // capture phase
```

`DispatchPhase`:

- `Capture`: root'tan focused element'e doğru.
- `Bubble`: focused element'ten root'a doğru. Default; action handler'lar burada
  default olarak propagation'ı durdurur. Aksi gerekiyorsa içinde `cx.propagate()`.

Keybinding:

```rust
cx.bind_keys([
    KeyBinding::new("cmd-s", Save, Some("Workspace")),
    KeyBinding::new("ctrl-g", GoToLine { line: 0 }, Some("Editor")),
]);
```

Context predicate gramer (`crates/gpui/src/keymap/context.rs:172,360+`):

- `Editor` — context stack'te `Editor` identifier'ı var.
- `Editor && !ReadOnly` — birleştirme + negasyon.
- `Workspace > Editor` — `>` operatörü "Editor parent dispatch path'inde Workspace
  altında" anlamına gelen descendant predicate'idir.
- `mode == insert` — eşitlik (`KeyContext::set("mode", "insert")` ile yazılan
  key/value değerine bakar).
- `mode != normal` — eşitsizlik.
- `(Editor || Terminal) && !ReadOnly` — parantezle gruplama.

Gerçek parser yalnızca şu operatörleri tanır: `>`, `&&`, `||`, `==`, `!=`, `!`.
`in (a, b)`, `not in`, fonksiyon çağrısı gibi syntax'lar yoktur. Vim modu gibi
çoklu seçenek için `mode == normal || mode == visual` yazılır.

`.key_context("Editor")` ile element ağaca context push eder; child'lar üst
context'leri görür. Aynı binding birden çok context'te match ederse en
spesifik (en derin) context kazanır.

Tuzaklar:

- Action register edilmeden binding atılırsa keymap parse hata verir; `actions!`
  veya `#[derive(Action)]` mutlaka ana modülde derlenmiş olmalı.
- Bubble fazında handler `cx.propagate()` çağırmazsa parent action handler'lara
  ulaşmaz (default davranış).
- Aynı action ismi iki crate'te tanımlanırsa registry collision olur; namespace zorunlu.
- Zed runtime'da bilinmeyen action ismi keymap'te warning log üretir, panic değil.

### 45. Action Makro Detayları, register_action! ve Deprecated Alias

`#[derive(Action)]` ve `actions!` makrosu çoğu zaman yeterlidir, ancak action
sözleşmesinin ek köşe taşları vardır.

#### `Action` trait'inin gerçek yüzeyi (`crates/gpui/src/action.rs:117+`)

```rust
pub trait Action: Any + Send {
    fn boxed_clone(&self) -> Box<dyn Action>;
    fn partial_eq(&self, other: &dyn Action) -> bool;
    fn name(&self) -> &'static str;
    fn name_for_type() -> &'static str where Self: Sized;
    fn build(value: serde_json::Value) -> Result<Box<dyn Action>>
        where Self: Sized;
    fn action_json_schema(_: &mut SchemaGenerator) -> Option<Schema>
        where Self: Sized { None }
    fn deprecated_aliases() -> &'static [&'static str]
        where Self: Sized { &[] }
    fn deprecation_message() -> Option<&'static str>
        where Self: Sized { None }
    fn documentation() -> Option<&'static str>
        where Self: Sized { None }
}
```

`name(&self)` runtime ad, `name_for_type()` static ad — runtime polymorphism
gerekirse ilkini, registration'da ikincisini kullan.

#### `#[action(...)]` attribute'leri

`#[derive(Action)]` üzerinde:

- `namespace = my_crate`: action adını `my_crate::Save` formuna çevirir.
- `name = "OpenFile"`: namespace içinde özel ad.
- `no_json`: `Deserialize`/`JsonSchema` derive zorunluluğunu kaldırır;
  `build()` her zaman hata döndürür, `action_json_schema()` `None`.
  Pure-code action (örn. `RangeAction { start: usize }`) için kullan.
- `no_register`: inventory üzerinden otomatik kaydı atlar; trait'i elle
  uygularken veya conditional kayıt yaparken gerekir.
- `deprecated_aliases = ["editor::OldName", "old::Name"]`: keymap'te eski adı
  kabul ederken kullanıcıya warning üretmek için.
- `deprecated = "message"`: action'ın kendisini deprecated işaretler;
  `deprecation_message()` bu metni döndürür.

#### `register_action!` makrosu

`#[derive(Action)]` kullanmadan `Action`'u manuel implement ediyorsan, action'ın
inventory'e girmesi için:

```rust
use gpui::register_action;

register_action!(Paste);
```

Bu makro yalnızca `inventory::submit!` çağrısı üretir; struct/impl tanımına
dokunmaz. `no_register` ile birleştiği takdirde elle ne zaman register
edileceğini sen belirlersin.

#### Action runtime API'leri

- `cx.is_action_available(&action) -> bool`: focused element path'te bu action'ı
  dinleyen biri var mı? Menü item'larını disable etmek için ideal.
- `window.is_action_available(&action, cx)`: window-spesifik versiyon.
- `cx.dispatch_action(&action)`: focused window'a yayınla.
- `window.dispatch_action(action.boxed_clone(), cx)`: window-spesifik.
- `cx.build_action(name, json_value)`: keymap entry'sinden runtime action üretir;
  schema yoksa `ActionBuildError` döner.

#### Tuzaklar

- `partial_eq` derive default'ta `PartialEq` impl'i kullanır; derive ekleme
  unutulursa karşılaştırma yanlış sonuç verebilir.
- Aynı `name()` döndüren iki action register edilirse inventory startup'ta
  panic eder; namespace kullanmak çakışmayı önler.
- `deprecated_aliases` keymap parser'ı eski adı yeni action'a yönlendirir, ama
  Rust kodunda eski tipi referans etmeye devam edersen iki tanım çakışır.
- `no_json` action'ı keymap dosyasından çağıramazsın; sadece kod içinden
  `dispatch_action` ile tetiklenir.

### 46. Keymap, KeyContext ve Dispatch Stack

Action tanımlamak tek başına yetmez; keybinding'in çalışması için focused element
dispatch path'inde uygun `KeyContext` bulunmalıdır.

Context koyma:

```rust
div()
    .track_focus(&self.focus_handle)
    .key_context("Editor mode=insert")
    .on_action(cx.listener(|this, _: &Save, window, cx| {
        this.save(window, cx);
    }))
```

Binding ekleme:

```rust
cx.bind_keys([
    KeyBinding::new("cmd-s", Save, Some("Editor")),
    KeyBinding::new("ctrl-g", GoToLine { line: 0 }, Some("Workspace && !Editor")),
]);
```

Önemli parçalar:

- `KeyContext::parse("Editor mode = insert")`: elementin bağlamını üretir.
- `KeyContext::new_with_defaults()`: default context set'iyle başlar.
  `primary()`, `secondary()` parse edilen ana/ek context entry'lerine erişir;
  `is_empty()`, `clear()`, `extend(&other)`, `add(identifier)`, `set(key, value)`,
  `contains(key)` ve `get(key)` düşük seviyeli context inşa/sorgu yüzeyidir.
- `KeyBindingContextPredicate`: binding tarafındaki predicate dilidir:
  `Editor`, `mode == insert`, `!Terminal`, `Workspace > Editor`,
  `A && B`, `A || B`.
- `KeyBindingContextPredicate::parse(source)` predicate'i üretir.
  `eval(context_stack)` bool eşleşme, `depth_of(context_stack)` en derin eşleşme
  derinliği, `is_superset(&other)` ise keymap önceliği ve conflict analizinde
  kullanılır. `eval_inner(...)` public olsa da parser/validator gibi düşük
  seviyeli kodlar içindir; normal component kodu doğrudan çağırmaz.
- `Keymap::bindings_for_input(input, context_stack)`: eşleşen action'ları ve
  pending multi-stroke durumunu döndürür.
- `Keymap::possible_next_bindings_for_input(input, context_stack)`: mevcut
  chord prefix'ini takip edebilecek binding'leri precedence sırasıyla verir.
- `Keymap::version() -> KeymapVersion`: binding set'i değiştikçe artan sayaçtır;
  keybinding UI cache'lerinde invalidation anahtarı olarak kullanılabilir.
- `Keymap::new(bindings)`, `add_bindings(bindings)`, `bindings()`,
  `bindings_for_action(action)`, `all_bindings_for_input(input)` ve `clear()`
  ham keymap tablosunu kurma/sorgulama/reset yüzeyidir. Uygulama akışında çoğu
  zaman `cx.bind_keys(...)` ve settings loader tercih edilir; bu metotlar test,
  validator, diagnostic ve özel keymap UI için doğrudan kullanılır.
- `window.context_stack()`: focused node'dan root'a dispatch path context'leri.
- `window.keystroke_text_for(&action)`: UI'da gösterilecek en yüksek öncelikli
  binding string'i.
- `window.possible_bindings_for_input(&[keystroke])`: chord/pending yardım UI'ları
  için kullanılabilir.
- `cx.key_bindings() -> Rc<RefCell<Keymap>>`: keymap'e düşük seviyeli erişim.
  Production kodunda mümkünse `bind_keys`, keymap dosyası ve validator akışı
  kullan; bu handle test/diagnostic ve özel keymap UI için uygundur.
- `cx.clear_key_bindings()`: tüm binding'leri temizler ve windows refresh planlar;
  normal uygulama akışında değil test/reset path'lerinde kullanılır.

Öncelik:

- Context path'te daha derin eşleşme daha yüksek önceliklidir.
- Aynı derinlikte sonra eklenen binding önce gelir; user keymap bu yüzden built-in
  binding'leri ezebilir.
- `NoAction` ve `Unbind` binding'leri devre dışı bırakma için kullanılır.
- Printable input IME'ye gidecekse `InputHandler::prefers_ime_for_printable_keys`
  keybinding yakalamayı geriye çekebilir. `EntityInputHandler` kullanan view'larda
  bu değer `ElementInputHandler` tarafından `accepts_text_input` sonucundan
  türetilir; ayrı karar gerekiyorsa raw `InputHandler` yaz.

Tuzaklar:

- `.key_context(...)` olmayan subtree'de context predicate'li binding çalışmaz.
- Handler focus path'te değilse action bubble oraya ulaşmaz; global handler için
  `cx.on_action(...)`, local handler için element `.on_action(...)` kullan.
- `KeyBinding::new` parse hatasında panic edebilir; kullanıcı JSON'undan yükleme
  yaparken `KeyBinding::load` ve error reporting tercih edilir.
- `KeyBinding::load(keystrokes, action, context_predicate, use_key_equivalents,
  action_input, keyboard_mapper)` fallible loader'dır; `KeyBindingKeystroke`
  mapping'ini de burada kurar. `context_predicate` `Option<Rc<KeyBindingContextPredicate>>`,
  `action_input` ise `Option<SharedString>` alır ve hata durumunda
  `InvalidKeystrokeError` döner. Runtime'da `with_meta(...)`/`set_meta(...)`
  binding'in hangi keymap katmanından geldiğini taşır; `match_keystrokes(...)`
  tam/pending eşleşmeyi, `keystrokes()`, `action()`, `predicate()`, `meta()` ve
  `action_input()` getter'ları diagnostic ve command/keymap UI'ı besler.

### 47. DispatchPhase, Event Propagation ve DispatchEventResult

Mouse, key ve action olayları element ağacında iki fazda akar:

```rust
pub enum DispatchPhase {
    Capture, // root → focused
    Bubble,  // focused → root (default)
}
```

`Window::on_mouse_event`, `on_key_event`, `on_modifiers_changed` listener'ları
faza göre çağrılır. Element fluent API'lerinde `.on_*` ailesi bubble fazına,
`.capture_*` ailesi capture fazına bağlanır.

Kontrol bayrakları (`crates/gpui/src/app.rs:2021+`):

- `cx.stop_propagation()`: aynı tipteki diğer handler'ların çağrılmasını keser
  (mouse'ta z-index'te alt katman, key'de ağaçta üst element).
- `cx.propagate()`: bir önceki `stop_propagation()` etkisini geri alır. Action
  handler'lar bubble fazında default olarak propagation'ı durdurur, bu yüzden
  parent'a düşmesini istiyorsan handler içinden `cx.propagate()` çağır.
- `window.prevent_default()` / `window.default_prevented()`: aynı dispatch içinde
  default element davranışını bastıran pencere bayrağıdır. Mevcut kullanımın
  en görünür örneği mouse down sırasında parent focus transferini engellemektir.

Platform tarafına döndürülen sonuç:

```rust
pub struct DispatchEventResult {
    pub propagate: bool,        // hâlâ bubble ediliyorsa true
    pub default_prevented: bool, // GPUI default davranışı bastırıldı mı
}
```

`PlatformWindow::on_input` callback'i `Fn(PlatformInput) -> DispatchEventResult`
döndürür. Mevcut platform backend'lerinde "event işlendi mi?" kararı esas olarak
`propagate` üzerinden alınır (`!propagate` handled anlamına gelir).
`default_prevented` GPUI dispatch ağacındaki default element davranışını ve
test/diagnostic sonucu taşır; platform default action kontrolü gibi genelleme
yapmadan, handler'ın açıkça kontrol ettiği yerlerde anlamlandır.

Pratik akış:

1. Element listener fire eder, view state günceller, gerekirse `cx.notify()`.
2. Listener event'i tüketmek istiyorsa `cx.stop_propagation()` çağırır.
3. Action handler default davranışı korumak istiyorsa `cx.propagate()` ile
   bubble'ı yeniden açar.
4. Default focus transferi gibi GPUI içi davranış bastırılacaksa
   `window.prevent_default()` çağrılır.

Tuzaklar:

- `capture_*` handler'ları focus path bilinmeden çalışır; pencere global
  shortcut/observer için kullanılır, ama state mutate etmek istiyorsan focused
  element'i runtime'da kontrol et.
- Action propagation davranışı mouse/key event'lerden ters çalışır. Yeni action
  yazarken ezbere `stop_propagation` koymak parent action'larını öldürebilir.
- `default_prevented` genel bir platform cancellation API'si değildir; hangi
  davranışı durdurduğunu anlamak için ilgili element/window handler'ının
  `window.default_prevented()` kontrol edip etmediğine bak.

### 48. Action ve Keymap Runtime Introspection

Action tanımlama ve dispatch önceki bölümlerde var; Zed komut paleti, keymap UI
ve geliştirici diagnostikleri için runtime introspection yüzeyi ayrıca bilinmeli.

Action registry:

- `cx.build_action(name, data) -> Result<Box<dyn Action>, ActionBuildError>`:
  string action adı ve optional JSON verisinden runtime action üretir.
- `cx.all_action_names() -> &[&'static str]`: register edilmiş tüm action
  adlarını döndürür. Registration, action'ın element ağacında available olduğu
  anlamına gelmez.
- `cx.action_schemas(generator)`: non-internal action adları ve JSON schema'ları.
- `cx.action_schema_by_name(name, generator)`: tek action için schema döndürür;
  `None` action yok, `Some(None)` action var ama schema yok demektir.
- `cx.deprecated_actions_to_preferred_actions()`,
  `cx.action_deprecation_messages()`, `cx.action_documentation()`: keymap
  validator, command palette ve migration mesajları için registry metadata'sı.

Available action ve binding sorguları:

- `window.available_actions(cx)`: focused element dispatch path'indeki action
  listener'larını ve global action listener'larını birleştirir. Menü/komut UI'ında
  "bu action şu anda yapılabilir mi?" sorusunun window-spesifik cevabıdır.
- `window.on_action_when(condition, TypeId::of::<A>(), listener)`: paint fazında
  current dispatch node'una conditional low-level action listener ekler. Element
  API'deki `.on_action(...)`/`.capture_action(...)` genelde daha okunur; custom
  element yazmıyorsan bu seviyeye inme.
- `cx.is_action_available(&action)` ve `window.is_action_available(&action, cx)`:
  bool kısayollar.
- `window.is_action_available_in(&action, focus_handle)`: action availability
  sorgusunu belirli focus handle dispatch path'inden yapar.
- `window.bindings_for_action(&action)`: focused context stack'e göre action'a
  giden binding'leri döndürür; display için son binding en yüksek öncelikli kabul
  edilir.
- `window.highest_precedence_binding_for_action(&action)`: aynı sorgunun daha
  ucuz tek sonuç versiyonu.
- `window.bindings_for_action_in(&action, focus_handle)` ve
  `highest_precedence_binding_for_action_in(...)`: sorguyu belirli focus handle
  path'inden yapar.
- `window.bindings_for_action_in_context(&action, KeyContext)`: tek bir elle
  verilmiş context'e göre sorgu.
- `window.highest_precedence_binding_for_action_in_context(&action, KeyContext)`:
  aynı sorgunun tek sonuçlu en yüksek öncelik versiyonu.
- `cx.all_bindings_for_input(&[Keystroke])`: context'e bakmadan input dizisine
  kayıtlı tüm binding'leri listeler.
- `window.possible_bindings_for_input(&[Keystroke])`: multi-stroke/prefix akışında
  current context stack'e göre sıradaki aday binding'leri verir. Tam eşleşen
  action dispatch sonucunu öğrenmek için normal `window.dispatch_keystroke(...)`
  akışı kullanılmalıdır; public `Window::bindings_for_input` helper'ı yoktur.
- `window.pending_input_keystrokes()` ve `window.has_pending_keystrokes()`:
  tamamlanmamış key chord durumunu UI'da göstermek veya test etmek için.

Keystroke global gözlem:

```rust
let after_dispatch = cx.observe_keystrokes(|event, window, cx| {
    log_key(event, window, cx);
});

let before_dispatch = cx.intercept_keystrokes(|event, window, cx| {
    if should_block(event) {
        cx.stop_propagation();
    }
});
```

- `observe_keystrokes` action/event mekanizmaları çözüldükten sonra çalışır ve
  propagation durdurulduysa çağrılmaz.
- `intercept_keystrokes` dispatch'ten önce çalışır; burada
  `cx.stop_propagation()` çağırmak action dispatch'i engeller.
- Her ikisi de `Subscription` döndürür; kaybedilirse observer düşer.

Tuzaklar:

- `all_action_names` içinde görünen action'ın o anda kullanılabilir olması
  garanti değildir; UI enable/disable için `available_actions` veya
  `is_action_available` kullan.
- Binding display ederken context stack'i hesaba katmayan `cx.all_bindings_for_input`
  yerine mümkünse window/focus handle bazlı sorgu kullan.
- Interceptor'lar global etkilidir; modal özelinde key engelleyeceksen mümkünse
  element action/capture handler ile sınırla.

### 49. Zed Keymap Dosyası, Validator ve Unbind Akışı

GPUI action/keybinding modeli Zed'de `settings::keymap_file` ile kullanıcı
dosyasına bağlanır. Bu bölüm runtime dispatch'ten farklı olarak JSON yükleme,
schema ve dosya güncelleme tarafını kapsar.

Dosya modeli:

- `KeymapFile(Vec<KeymapSection>)`: top-level JSON array.
- `KeymapSection`: context predicate ve binding/unbind map'lerini taşır. Alan
  görünürlüğü dengesizdir — yalnız `pub context: String` dış erişime açıktır;
  `use_key_equivalents: bool`, `unbind: Option<IndexMap<...>>`,
  `bindings: Option<IndexMap<...>>` ve `unrecognized_fields: IndexMap<...>`
  alanları **private**'tır. `KeymapFile` parser'ı bu alanlara crate içinden
  doğrudan erişir; dış kod yalnız `KeymapSection::bindings(&self)` getter'ını
  kullanabilir, bu da `(keystroke, KeymapAction)` çiftlerini dönen tek public
  iterator'dır (`keymap_file.rs:101`). `unbind` ve `use_key_equivalents` için
  ayrı public getter şu sürümde yoktur.
- `KeymapAction(Value)`: `null`, `"action::Name"` veya
  `["action::Name", { ...args... }]` biçimlerini temsil eder.
- `UnbindTargetAction(Value)`: `unbind` map'indeki hedef action değeri.
- `KeymapFileLoadResult::{Success, SomeFailedToLoad, JsonParseFailure}`:
  dosyanın kısmen yüklenebildiği senaryoyu açıkça ayırır.

Yükleme:

```rust
let keymap = KeymapFile::parse(&contents)?;
let result = KeymapFile::load(&contents, cx);
```

`load_asset(asset_path, source, cx)` bundled keymap dosyalarını yükler ve
`KeybindSource` metadata'sı set edebilir. `load_panic_on_failure` sadece
startup/test gibi "asset bozuksa devam etmeyelim" path'leri içindir.

Base keymap:

- `BaseKeymap::{VSCode, JetBrains, SublimeText, Atom, TextMate, Emacs, Cursor,
  None}`.
- Base/default/vim/user binding'leri `KeybindSource` metadata'sı taşır; UI
  hangi binding'in nereden geldiğini bu metadata ile gösterir.

Validator:

- `KeyBindingValidator`: belirli action type'ı için binding doğrulaması yapar.
- `KeyBindingValidatorRegistration(pub fn() -> Box<dyn KeyBindingValidator>)`
  inventory ile toplanır.
- Validator hatası `MarkdownString` döner; keymap UI bunu kullanıcıya
  açıklanabilir hata olarak gösterebilir.

Disable / unbind sentinel action'ları:

GPUI iki ayrı sentinel action sağlar (`gpui::action.rs:425-453`); ikisinin de
runtime davranışı **dispatch etmemek**, fakat keymap dispatch tablosundaki
işlevleri farklıdır:

- **`zed::NoAction`** — `actions!(zed, [NoAction])` ile tanımlı, veri taşımaz.
  Keymap JSON'unda eylem değeri olarak `null` veya `"zed::NoAction"` yazılır:

  ```json
  { "context": "Editor", "bindings": { "cmd-p": null } }
  ```

  Aynı keystroke'a daha düşük öncelikle bağlanmış action'lar bu context için
  iptal edilir; eşleşme `Keymap::resolve_binding` tarafında
  `disabled_binding_matches_context(...)` çağrısıyla **context-aware** olarak
  filtrelenir (`gpui/src/keymap.rs:120`). Yani `NoAction` belirli bir context
  predicate'i içinde tuşu sessize alır.

- **`zed::Unbind(SharedString)`** — `derive(Action)` ile tanımlı, payload bir
  action adıdır. JSON formatı:

  ```json
  ["zed::Unbind", "editor::NewLine"]
  ```

  Keymap parser'ı bu sentinel'ı gördüğünde aynı keystroke'a aynı action adıyla
  ileriden gelen tüm binding'leri **action context'inden bağımsız olarak**
  iptal eder (`keymap.rs:124-128`'deki `is_unbind` kolu). Yani `editor::NewLine`
  için `enter` tuşunu tüm context'lerde unbind etmek için kullanılır.

Sentinel kontrol API'leri:

- `gpui::is_no_action(&dyn Action) -> bool` (`action.rs:445`): `as_any().is::<NoAction>()`
  ile downcast eder. Custom keymap UI veya komut paleti listesinde
  "(disabled)" göstergesi koymak için kullanılabilir.
- `gpui::is_unbind(&dyn Action) -> bool` (`action.rs:450`): aynı şekilde
  `Unbind` instance'ını downcast eder.

`KeymapFile::update_keybinding` `KeybindUpdateOperation::Remove` için bu iki
sentinel'i bağlama göre üretir: user binding'leri `Remove` doğrudan dosyadan
siler, framework/default binding'leri ise sessize alabilmek için kullanıcı
keymap'ine `null` (NoAction) veya `["zed::Unbind", ...]` entry yazar.

Dosya güncelleme:

```rust
let updated = KeymapFile::update_keybinding(
    operation,
    keymap_contents,
    tab_size,
    keyboard_mapper,
)?;
```

- `KeybindUpdateOperation::Add { source, from }`: yeni binding ekler.
- `Replace { source, target, target_keybind_source }`: user binding ise değiştirir;
  user dışı binding değişiyorsa add + suppression unbind'e dönüştürebilir.
- `Remove { target, target_keybind_source }`: user binding'i dosyadan siler;
  user dışı binding'i kaldırmak için `unbind` yazar.
- `KeybindUpdateTarget` action adı, optional action arguments, context ve
  `KeybindingKeystroke` dizisini taşır.

Tuzaklar:

- `use_key_equivalents` yalnızca destekleyen platformlarda anlamlıdır; keyboard
  mapper verilmeden dosya güncelleme doğru keystroke string'i üretemez.
- Non-user binding'i "silmek" gerçek kaynağı değiştirmez; kullanıcı keymap'ine
  suppress eden `unbind` entry'si yazılır.
- Kullanıcı JSON'u bozuksa `update_keybinding` dosyayı değiştirmez; önce parse
  başarıyla geçmelidir.


---

## Bölüm IX — Async ve State

---

### 50. Async İşler

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

### 51. Executor, Priority, Timeout ve Test Zamanı

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

### 52. Task, TaskExt ve Async Hata Yönetimi

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

### 53. Global State, Observe ve Event

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

### 54. Global State Yardımcıları ve `cx.defer`

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

### 55. Subscription Yaşam Döngüsü

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

### 56. Window-bound Observer, Release ve Focus Helper Desenleri

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

### 57. Entity Reservation ve Çift Yönlü Referans

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

### 58. Entity Release, Cleanup ve Leak Detection

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

### 59. Entity Type Erasure, Callback Adaptörleri ve View Cache

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
ownership'leri farklıdır — denetimi `Owner::method -> dönüş` çiftiyle yap.

**Denetim komutu:** State-machine awk ile owner+metot eşlemesi
(`crates/gpui/src/app/entity_map.rs`):

```sh
gawk '
  BEGIN { owner = "(file)" }
  /^impl[<[:space:]]/ {
    if (match($0, /[[:space:]]for[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)/, m)) {
      trait_name = ""
      if (match($0, /^impl(<[^>]+>)?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)/, t)) { trait_name = t[2] }
      owner = m[1] " (impl " trait_name ")"
    } else if (match($0, /^impl(<[^>]+>)?[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)/, m)) {
      owner = m[2] " (inherent)"
    }
    next
  }
  /^[[:space:]]*pub (fn|const|async fn)[[:space:]]/ {
    n = $0; sub(/^[[:space:]]*pub[[:space:]]+/, "", n); sub(/[[:space:]]*\{?[[:space:]]*$/, "", n)
    print FILENAME ":" FNR ":" owner ":" n
  }
' ../zed/crates/gpui/src/app/entity_map.rs \
  | grep -E ':(Entity|WeakEntity|AnyEntity|AnyWeakEntity) '
```

Çıktıda aynı ad birden çok owner satırında çıkıyorsa (`upgrade`, `new_invalid`,
`entity_id` gibi) tabloda inherent/deref ayrımı gözden kaçırılmamış olur.

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

## Bölüm X — Liste ve Sanallaştırma

---

### 60. ScrollHandle ve Scroll Davranışı

`crates/gpui/src/elements/div.rs:3387+`.

`ScrollHandle`, scroll offset'ini paylaşılabilir bir handle olarak temsil eder.
`Rc<RefCell<ScrollHandleState>>` üzerinden çalışır, view'lar arasında klonlanabilir.

Public API:

- `ScrollHandle::new()`
- `offset() -> Point<Pixels>`: anlık scroll konumu.
- `max_offset() -> Point<Pixels>`
- `top_item()`, `bottom_item()`: görünür ilk/son child item dizini.
- `bounds()`: scroll container bounds.
- `bounds_for_item(ix)`: child bounds.
- `scroll_to_item(ix)`, `scroll_to_top_of_item(ix)`: prepaint zamanında istenen
  item'a scroll eder.
- `scroll_to_bottom()`
- `set_offset(point)`: offset'i doğrudan ayarlar. Offset içerik origin'inin
  parent origin'ine uzaklığıdır; aşağı kaydıkça Y genelde negatife gider.
- `logical_scroll_top()`, `logical_scroll_bottom()`: görünür child index'i ve
  child içi pixel offset'i döndürür.
- `children_count()`: scroll edilen child sayısı.

Element üzerine bağlama:

```rust
let handle = ScrollHandle::new();

div()
    .id("list")
    .overflow_y_scroll()
    .track_scroll(&handle)
    .child(/* ... */)
```

`overflow_scroll`, `overflow_x_scroll`, `overflow_y_scroll` `StatefulInteractiveElement`
metotlarıdır; pratikte önce `.id(...)` çağırıp `Stateful<Div>` üretmen gerekir.
Overflow `Scroll` olduğunda input wheel/touch event'i bu container içinde tüketilir.
`track_scroll` aynı handle'ı render geçişleri arasında bağlar; aynı handle başka
yerden okunabilir ve değiştirilebilir.

`ScrollAnchor` (`div.rs:3332+`) bir handle ile çalışan helper'dır; immediate child
olmasa bile belirli bir element'in görünür kalmasını ister:

```rust
let anchor = ScrollAnchor::for_handle(handle.clone());
anchor.scroll_to(window, cx);
```

Tuzaklar:

- `id(...)` çağırmadan `overflow_*_scroll` çalışmaz; element interaktif değildir.
- `track_scroll` çağırılmadan handle değerleri eski kalır; offset güncel olmaz.
- Klavye ile scroll dispatch için `.on_key_down(...)` veya action ile
  `scroll_to_item` çağrılır; otomatik klavye scroll yoktur.

Liste elementlerinde ayrı state/handle tipleri vardır:

- `ListState`: `scroll_by`, `scroll_to`, `scroll_to_reveal_item`, `scroll_to_end`,
  `set_follow_mode(FollowMode::Tail)`, `logical_scroll_top`,
  `is_scrolled_to_end`, `is_following_tail`.
- `UniformListScrollHandle`: `scroll_to_item(..., ScrollStrategy)`,
  `scroll_to_item_strict`, `scroll_to_item_with_offset`,
  `scroll_to_item_strict_with_offset`, `logical_scroll_top_index`,
  `is_scrolled_to_end`, `scroll_to_bottom`.

Büyük listelerde doğrudan `ScrollHandle` yerine bu listeye özel
`ListState`/`UniformListScrollHandle` API'lerini kullanmak doğru sonuç verir.

### 61. List ve UniformList Sanallaştırma

GPUI'de büyük listeler için iki çekirdek element vardır:

- `list(state, render_item)`: item yükseklikleri farklı olabilir. Ölçüm cache'i
  `ListState` içindedir.
- `uniform_list(id, item_count, render_range)`: tüm item'lar aynı yükseklikteyse
  daha hızlıdır; ilk/örnek item ölçülür ve görünür range çizilir.

Değişken yükseklikli liste:

```rust
struct LogView {
    rows: Vec<Row>,
    list_state: ListState,
}

impl LogView {
    fn new() -> Self {
        Self {
            rows: Vec::new(),
            list_state: ListState::new(0, ListAlignment::Top, px(300.)),
        }
    }

    fn replace_rows(&mut self, rows: Vec<Row>, cx: &mut Context<Self>) {
        self.rows = rows;
        self.list_state.reset(self.rows.len());
        cx.notify();
    }
}
```

Render:

```rust
list(self.list_state.clone(), |ix, window, cx| {
    render_row(ix, window, cx).into_any_element()
})
.with_sizing_behavior(ListSizingBehavior::Auto)
```

`ListState` yönetimi:

- `new(item_count, alignment, overdraw)`: builder.
- `measure_all()` (consuming): `ListMeasuringBehavior::Measure(false)` set ederek
  scrollbar boyutunun yalnızca render edilmiş elementlere değil, **tüm liste**
  ölçümüne dayanmasını sağlar.
- `item_count() -> usize`: o anki item sayısı.
- `reset(count)`: tüm item seti değişti.
- `splice(old_range, count)`: aralık değişti; scroll offset'i korunur.
- `splice_focusable(old_range, focus_handles)`: focusable item'ları sanallaştırırken
  focus handle dizisi geçilir; aksi halde görünür olmayan focused item render
  dışı kalabilir.
- `remeasure()`: font/theme gibi tüm yükseklikleri etkileyen değişim.
- `remeasure_items(range)`: streaming text veya lazy content gibi belirli item'lar.
- `set_follow_mode(FollowMode::Tail)`: chat/log gibi tail-follow davranışı.
- `is_following_tail() -> bool`: aktif takip durumu.
- `is_scrolled_to_end() -> Option<bool>`: en alta scroll mu? `None` henüz layout
  yapılmamışsa.
- `scroll_by(distance)`, `scroll_to_end()`, `scroll_to(ListOffset)`,
  `scroll_to_reveal_item(ix)`.
- `logical_scroll_top() -> ListOffset`: aktif scroll konumu.
- `bounds_for_item(ix) -> Option<Bounds<Pixels>>`: render edilmişse item rect'i.
- `set_scroll_handler(...)`: görünür range ve follow state takibi.

Custom scrollbar API'si (kendi scrollbar widget'ını yazıyorsan; `ui::Scrollbars`
zaten bu metotlar üzerinde kuruludur):

- `viewport_bounds() -> Bounds<Pixels>`: en son layout edilmiş viewport rect'i.
- `scroll_px_offset_for_scrollbar() -> Point<Pixels>`: scrollbar için adapte
  edilmiş güncel scroll konumu.
- `max_offset_for_scrollbar() -> Point<Pixels>`: ölçülmüş item'lara göre maksimum
  scroll. Drag sırasında bu değer sabit kalır ki scrollbar sıçramasın.
- `set_offset_from_scrollbar(point)`: scrollbar drag/click'inden gelen offset'i
  uygular.
- `scrollbar_drag_started()` / `scrollbar_drag_ended()`: drag sırasında overdraw
  ölçümünden kaynaklı yükseklik dalgalanmasını dondurmak/serbest bırakmak için.
  Drag'a girerken started, bırakırken ended çağırmazsan scrollbar drag boyunca
  beklenmedik şekilde sürünebilir.

Uniform liste:

```rust
let scroll_handle = self.scroll_handle.clone();

uniform_list("search-results", self.items.len(), move |range, window, cx| {
    range
        .map(|ix| render_result(ix, window, cx))
        .collect()
})
.track_scroll(&scroll_handle)
.with_width_from_item(Some(0))
```

`UniformListScrollHandle`:

- `scroll_to_item(ix, ScrollStrategy::Nearest)`
- `scroll_to_item_strict(ix, ScrollStrategy::Center)`
- `scroll_to_item_with_offset(ix, strategy, offset)`
- `scroll_to_bottom()`
- `is_scrollable()`, `is_scrolled_to_end()`
- `y_flipped(true)`: item 0 altta olacak şekilde ters akış.

Karar:

- Item yükseklikleri gerçekten aynıysa `uniform_list`.
- Yükseklik değişebiliyorsa `list` ve doğru `splice`/`remeasure` çağrıları.
- Focusable item'lar sanallaştırılıyorsa `splice_focusable` ile focus handle ver;
  aksi halde görünür olmayan focused item render dışı kalabilir.


---

## Bölüm XI — Asset, Image, Path ve Çizim

---

### 62. Asset, Image ve SVG Yükleme

`crates/gpui/src/asset_cache.rs`, `assets.rs`, `elements/img.rs`, `svg.rs`.

`Asset` trait async loader sözleşmesidir:

```rust
trait Asset {
    type Source: ...;
    type Output: ...;
    fn load(source: Self::Source, cx: &mut App) -> impl Future<Output = Self::Output>;
}
```

Kaynak gösterimi:

- `Resource::Path(Arc<Path>)`
- `Resource::Uri(SharedUri)` — `http://`, `https://`, `file://` vb.
- `Resource::Embedded(SharedString)` — `AssetSource` üzerinden gömülü asset.

`AssetSource` trait `App::with_assets` ile kurulan global asset providerdır.
`crates/assets` Zed binary'sinde `RustEmbed` ile SVG/icons dahil eder.
Kurulu kaynak gerektiğinde `cx.asset_source()` ile okunabilir; çoğu UI kodu bunu
doğrudan değil `Resource::Embedded`, `svg().path(...)` veya `window.use_asset`
üzerinden kullanır.

Image element:

```rust
img(PathBuf::from("path/to/icon.png"))
    .w(px(24.))
    .h(px(24.))
    .object_fit(ObjectFit::Contain)
    .with_loading(|| div().bg(rgb(0xeeeeee)).into_any_element())
    .with_fallback(|| div().bg(rgb(0xffeeee)).into_any_element())
```

`img(impl Into<ImageSource>)` kabul eder. `ImageSource`:

- `Resource(Resource)`
- `Render(Arc<RenderImage>)` — önceden raster edilmiş frame'ler.
- `Image(Arc<Image>)` — encoded bytes (PNG/JPEG/WebP).
- `Custom(Arc<dyn Fn(&mut Window, &mut App) -> Option<Result<Arc<RenderImage>, ImageCacheError>>>)`

URL string otomatik `Uri` olarak parse edilir; URL olmayan `&str`/`String`
`Resource::Embedded` olur ve `AssetSource` içinden aranır. Dosya sistemi path'i
için `Path`, `PathBuf` veya `Arc<Path>` geçir.

SVG:

```rust
svg().path("icons/check.svg").size(px(16.)).text_color(rgb(0x000000))
```

SVG path `AssetSource`'tan okunur. `text_color` SVG'deki `currentColor` referanslarını
boyamak için kullanılır. Custom path string yerine derive edilen `IconName::path()`
de geçirilebilir (Zed'de `Icon::new(IconName::Check)` doğrudan kullanılır).

Cache davranışı iki katmanlıdır: `window.use_asset::<A>(source, cx)` aynı source
için tek async load task'ını paylaşır ve tamamlanınca current view'i yeniden
çizdirir; `ImageCache` ise decode edilmiş `RenderImage`'ı tutar. Element bazında
`.image_cache(&entity)` veya ağacın üstünde `image_cache(retain_all("id"))`
kullanılabilir. Hata loglama `ImgResourceLoader = AssetLogger<...>` ile otomatiktir.

Tuzaklar:

- URL parse başarısızsa string embedded asset sayılır; gerçek dosya yolu için
  `PathBuf` kullanmadıysan yanlış kaynaktan arama yapılır.
- Custom closure `'static` olmalı; `Window`/`App` sadece closure çağrısında
  parametre olarak kullanılmalı.
- `with_fallback` yalnızca yükleme tamamlandığında ve hatalıysa fallback render eder.
- `with_loading` yükleme 200 ms'den uzun sürerse loading fallback'ini render
  eder. Bu eşik `gpui::LOADING_DELAY: Duration` const'ında tanımlıdır
  (`elements/img.rs:31`); kendi delayed-fallback akışın için aynı değeri
  ödünç alabilirsin.
- `RenderImage` GIF/animated WebP için `frame_count()` ve `delay(frame_index)`
  sağlar; `img` element'i aktif pencerede frame ilerletip animation frame ister.

### 63. Asset, ImageCache ve Surface Boru Hattı

GPUI asset katmanı üç seviyelidir:

- `AssetSource`: embedded/static asset byte'larını sağlar.
- `Asset`: async loader trait'i; `Source -> Output`.
- `Resource`: image/svg kaynak adresi: `Uri(SharedUri)`, `Path(Arc<Path>)`,
  `Embedded(SharedString)`.

Image cache elementleri:

```rust
div()
    .image_cache(retain_all("avatars"))
    .child(img(avatar_uri.clone()).object_fit(ObjectFit::Cover))
```

Alternatif wrapper:

```rust
image_cache(retain_all("preview-cache"))
    .child(img(preview_path.clone()))
```

`RetainAllImageCache`:

- `RetainAllImageCache::new(cx)` entity cache oluşturur.
- `retain_all(id)` element-local cache provider oluşturur.
- `load(resource, window, cx)` sonuç hazır değilse `None`, hazırsa
  `Some(Result<Arc<RenderImage>, ImageCacheError>)` döndürür.
- Release sırasında `cx.drop_image(...)` ile GPU image kaynaklarını bırakır.

Custom cache gerektiğinde `ImageCache` trait'i uygulanır:

```rust
impl ImageCache for MyImageCache {
    fn load(
        &mut self,
        resource: &Resource,
        window: &mut Window,
        cx: &mut App,
    ) -> Option<Result<Arc<RenderImage>, ImageCacheError>> {
        self.load_or_poll(resource, window, cx)
    }
}
```

`Surface` ayrı bir yol izler: macOS'ta `CVPixelBuffer` gibi platform surface
kaynaklarını `surface(buffer).object_fit(...)` ile çizmek içindir. Genel image
asset cache'i yerine `window.paint_surface(...)` boru hattını kullanır ve şu anda
platforma bağlıdır.

Tuzaklar:

- Cache ID'si değişirse decode edilmiş image state'i düşer.
- `img("literal")` URL değilse embedded resource olarak yorumlanır; filesystem
  için `PathBuf`/`Arc<Path>` ver.
- Çok büyük veya sürekli değişen image setlerinde `RetainAllImageCache` sınırsız
  büyüyebilir; özel eviction stratejisi için kendi `ImageCache` implementasyonu yaz.

### 64. Path Çizimi ve Custom Drawing

`crates/gpui/src/path_builder.rs`, `scene.rs`, `elements/canvas.rs`.

GPUI doğrudan path API yerine `canvas` elementi ve `PathBuilder` ile vektör çizim
sağlar. `PathBuilder` lyon tessellator wrapper'ıdır.

```rust
canvas(
    |bounds, window, _cx| {
        // prepaint: hitbox, layout-zamanlı state
        window.insert_hitbox(bounds, HitboxBehavior::Normal)
    },
    |bounds, _hitbox, window, _cx| {
        // paint: window.paint_path(...) çağrıları
        let mut path = PathBuilder::fill();
        path.move_to(bounds.origin);
        path.line_to(bounds.bottom_left());
        path.line_to(bounds.bottom_right());
        path.close();
        if let Ok(built) = path.build() {
            window.paint_path(built, rgb(0x4f46e5));
        }
    },
)
.size_full()
```

`PathBuilder`:

- `PathBuilder::fill()` ya da `PathBuilder::stroke(width)` ile başlat.
- `move_to(point)`, `line_to(point)`, `curve_to(to, ctrl)`,
  `cubic_bezier_to(to, control_a, control_b)`, `arc_to(radii, x_rotation,
  large_arc, sweep, to)`, `relative_arc_to(...)`, `add_polygon(...)`, `close()`.
- `dash_array(&[Pixels])` yalnızca stroke path'lerde anlamlıdır; odd sayıda değer
  verilirse SVG/CSS davranışı gibi liste iki kez tekrarlanır.
- `transform(...)`, `translate(point)`, `scale(f32)`, `rotate(degrees)` path'i
  build öncesi dönüştürür.
- `build()` → tessellated `Path<Pixels>` döner; `?` ile hata yay.

Tessellator parametreleri (`PathStyle`, `FillOptions`, `StrokeOptions`,
`FillRule`):

GPUI bu tipleri lyon'dan re-export eder
(`pub use lyon::tessellation::{FillOptions, FillRule, StrokeOptions}`,
`path_builder.rs:11-12`). `PathBuilder.style: PathStyle` alanı public'tir; iki
varyantı vardır:

```rust
pub enum PathStyle {
    Stroke(StrokeOptions),
    Fill(FillOptions),
}
```

Default constructor'lar default lyon parametrelerini set eder
(`PathBuilder::fill()` → `FillOptions::default()`; `PathBuilder::stroke(width)`
→ `StrokeOptions::default().with_line_width(width.0)`). Bu seçenekleri
özelleştirmek istersen `path.style` alanını doğrudan değiştir veya path inşa
ettikten sonra yeni `PathStyle` ata:

- `FillOptions`: `tolerance` (flattening hassasiyeti, default 0.1), `fill_rule`
  (`FillRule::{EvenOdd, NonZero}`, SVG `fill-rule` semantiği; default
  **`EvenOdd`** — `lyon_tessellation::FillOptions::DEFAULT_FILL_RULE`),
  `sweep_orientation` (default `Orientation::Vertical`),
  `handle_intersections` (default `true`). Hızlı yardımcılar:
  `FillOptions::even_odd()`, `FillOptions::non_zero()`,
  `FillOptions::tolerance(t)`.
- `StrokeOptions`: `line_width` (default 1.0), `start_cap` ve `end_cap` (her
  sub-path için başlangıç/bitiş cap'i, default `LineCap::Butt`), `line_join`
  (default `LineJoin::Miter`), `miter_limit` (default 4.0), `tolerance`
  (default 0.1). Tüm bu sabitler
  `lyon_tessellation::StrokeOptions::{DEFAULT_LINE_CAP, DEFAULT_LINE_JOIN,
  DEFAULT_MITER_LIMIT, DEFAULT_LINE_WIDTH, DEFAULT_TOLERANCE}` const'larında
  görünür.
- `FillRule::EvenOdd` (lyon ve gpui default'u): SVG even-odd kuralı; iç içe
  path'lerde delik üretir. İki üst üste binen kapalı path'in çakışan bölgesi
  şeffaf olur.
  `FillRule::NonZero`: SVG non-zero winding kuralı; yön kombinasyonuna göre
  kapsama hesaplar, çakışan path'ler genelde dolu kalır. Karmaşık kompozit
  shape'ler için kasıtlı olarak `non_zero()` seçilir.

Lyon API'sine inmek istersen `lyon::tessellation::FillOptions::tolerance(0.5)`
gibi builder zincirleri kullanılabilir; gpui bu builder'ları olduğu gibi
yeniden export ettiği için ek wrapper'a ihtiyacın yoktur.

Window paint API'leri:

- `window.paint_path(path, color)`
- `window.paint_quad(quad)`: `fill(bounds, ...).border(...)` shorthand.
- `window.paint_strikethrough(...)`, `paint_underline(...)`
- `window.paint_image(...)`: raster image draw.
- `window.paint_layer(bounds, |window| ...)`: aynı draw order'da toplanan geometri
  için yeni layer açar; genellikle performans ve overdraw kontrolü için kullanılır.

Tuzaklar:

- Tessellation pahalıdır; her frame yeni path inşa etmek FPS'i düşürür. Mümkünse
  prepaint'te build edip paint'te yalnızca çiz.
- Path bounds dışına taşan kısım clip'lenmez; `paint_layer` ile manuel clipping yap.
- Stroke genişliği logical Pixels'dir; DPI yüksek ekranda çok ince kalmasın diye
  `px(1.0).max(...)` ile zemin tut.

### 65. Anchored ve Popover Konumlandırma

`crates/gpui/src/elements/anchored.rs`.

`anchored()` fonksiyonu bir `Anchored` builder döndürür:

```rust
anchored()
    .anchor(Anchor::TopLeft)
    .position(point(px(120.), px(80.)))
    .offset(point(px(0.), px(4.)))
    .snap_to_window_with_margin(Edges::all(px(8.)))
    .child(menu_view.into_any_element())
```

API:

- `anchor(Anchor)`: child'ın hangi referans noktasının `position`'a
  hizalanacağı. `Anchor` varyantları `TopLeft`, `TopRight`, `BottomLeft`,
  `BottomRight`, `TopCenter`, `BottomCenter`, `LeftCenter`, `RightCenter`.
- `position(point)`: anchor noktası (window veya local koordinatlarda).
- `offset(point)`: hizalama sonrası ek kayma.
- `position_mode(AnchoredPositionMode::Window)` veya
  `position_mode(AnchoredPositionMode::Local)`: koordinat referansı.
- `snap_to_window()` ve `snap_to_window_with_margin(Edges)`: pencere dışına taşıyorsa
  aynı anchor'ı koruyarak pencere içine kaydırır.

`AnchoredFitMode`:

- `SwitchAnchor` (default): yetersiz alanda tersine flip.
- `SnapToWindow`: aynı köşede kalır, pencere kenarına oturur.
- `SnapToWindowWithMargin(Edges)`: marjin bırakarak oturur.

Anchored element ağaca normal çocuk gibi eklenir, fakat layout fazında parent
bounds'unu yok sayar; absolute positioning gibi davranır. Tooltip, popover ve
ContextMenu altta bu element ile çalışır.

Tuzaklar:

- Position `Local` modda parent'ın content origin'ine görelidir; window modda
  ekranda mutlak değil, **pencere içi** koordinatlardır.
- Snap fonksiyonları arasında en son çağrılan kazanır.
- Anchored child kendi içinde overflow `Visible` davranır; içerik pencereyi taşırsa
  scroll için ekstra wrapper gerekir.

### 66. PaintQuad, Window Paint Primitives ve BorderStyle

`canvas` ve custom `Element::paint` içinde GPU'ya gönderilen primitive'ler:

```rust
window.paint_quad(fill(bounds, rgb(0xeeeeee)));

window.paint_quad(
    quad(
        bounds,
        Corners::all(px(8.)),                  // corner_radii
        rgb(0xffffff),                         // background
        Edges::all(px(1.)),                    // border_widths
        rgb(0xdddddd),                         // border_color
        BorderStyle::Solid,                    // veya Dashed
    ),
);

window.paint_quad(outline(bounds, rgb(0xff0000), BorderStyle::Solid));
```

`PaintQuad` builder yardımcıları (`window.rs:5848+`):

- `.corner_radii(impl Into<Corners<Pixels>>)`
- `.border_widths(impl Into<Edges<Pixels>>)`
- `.border_color(impl Into<Hsla>)`
- `.background(impl Into<Background>)`

Diğer paint API'leri:

- `window.paint_path(Path<Pixels>, impl Into<Background>)`: tessellated path.
- `window.paint_underline(Point, width, &UnderlineStyle)`: text underline.
- `window.paint_strikethrough(Point, width, &StrikethroughStyle)`.
- `window.paint_glyph(...)`: tek glyph rasterize ve çizim. Genellikle TextLayout
  zaten kullanır; nadiren elle çağrılır.
- `window.paint_emoji(...)`: emoji renk glyph.
- `window.paint_image(bounds, corner_radii, RenderImage, ...)`: raster image.
- `window.paint_svg(bounds, path, data, transformation, color, cx)`: monochrome
  SVG mask'i, `SvgRenderer` atlas cache'i üzerinden.
- `window.paint_surface(bounds, CVPixelBuffer)`: macOS-only native surface.
- `window.paint_shadows(bounds, corner_radii, &[BoxShadow])`: drop shadow set.
- `window.paint_layer(bounds, |window| ...)`: aynı bounds üzerinde clip ile yeni
  render katmanı; overflow gizleme ve transform için.

`BorderStyle` (`crates/gpui/src/scene.rs:544`): `Solid` ve `Dashed`.
`Corners<P>`, `Edges<P>`, `Bounds<P>`, `Hsla`, `Background` zaten bilinen
geometri/renk tipleridir; her builder bunlara `Into` üzerinden kabul eder.

Tuzaklar:

- `paint_*` çağrıları yalnızca `Element::paint` fazında geçerlidir; prepaint veya
  layout'ta panic verir.
- `paint_path` her frame yeniden tessellate edersen FPS düşer; mümkünse path
  prepaint'te oluştur ve element state'inde sakla.
- `paint_layer` clip'lediği için içerik bounds dışına taşan kısımlar gizlenir;
  shadow gibi taşan efektler için layer dışında çiz.
- `border_widths` dört kenara ayrı değer verebilir (`Edges { top, right, bottom, left }`);
  düz bir değer verirsen `Edges::all(px(1.))`.

### 67. Window Drawing Context Stack, Asset Fetch ve SVG Transform

Custom element yazarken `Window` yalnızca paint primitive çağırdığın yer değildir;
draw fazlarında aktif style, offset, clipping ve asset yükleme context'ini de
taşır.

Context stack yardımcıları:

- `window.with_text_style(Some(TextStyleRefinement), |window| ...)`: aktif text
  style stack'ine refinement ekler. İçeride `window.text_style()` birleşmiş
  sonucu verir.
- `window.with_rem_size(Some(px(...)), |window| ...)`: rem override stack'i;
  `window.rem_size()` içeride override değerini döndürür.
- `window.set_rem_size(px(...))`: pencerenin base rem değerini kalıcı değiştirir.
- `window.with_content_mask(Some(ContentMask { bounds }), |window| ...)`:
  mevcut mask ile intersection alır; paint/prepaint içindeki `content_mask()`
  bu aktif clip'i verir.
- `window.with_image_cache(Some(cache), |window| ...)`: child ağacı için aktif
  image cache stack'ini değiştirir. `ImageCacheElement` ve `Div` background
  image path'leri bunu kullanır; normal component kodu çoğunlukla
  `image_cache(retain_all(...))` fluent API'sini kullanır.
- `window.with_element_offset(offset, |window| ...)` ve
  `with_absolute_element_offset(offset, |window| ...)`: prepaint sırasında child
  offset'ini değiştirir. Scroll/list implementasyonlarının hitbox ve layout
  koordinatlarını doğru üretmesi buna dayanır.
- `window.element_offset()`: prepaint sırasında aktif offset'i okur.
- `window.transact(|window| -> Result<_, _> { ... })`: prepaint yan etkilerini
  deneme amaçlı yapar; closure `Err` dönerse hitbox/tooltip/dispatch/layout
  kayıtları eski index'e truncate edilir.

Frame/paint yardımcıları:

- `window.set_window_cursor_style(style)`: hitbox'a bağlı olmayan, tüm pencere
  için cursor request'i; paint fazında çağrılır ve hitbox cursor'larından önceliklidir.
- `window.set_tooltip(AnyTooltip) -> TooltipId`: tooltip request'i prepaint
  fazında kaydedilir.
- `window.paint_svg(...)`: `SvgRenderer` ve sprite atlas üzerinden monochrome SVG
  mask'i çizer. SVG'yi her zaman hedef boyutun
  `gpui::SMOOTH_SVG_SCALE_FACTOR: f32 = 2.0` (`svg_renderer.rs:81`) katı
  çözünürlükte rasterize edip tekrar küçültür; bu yüzden `paint_svg` çağrısı
  küçük icon boyutlarında bile yumuşak kenar üretir. `paint_image` decode
  edilmiş raster frame, `paint_surface` ise macOS native surface içindir.

Generic asset yükleme:

```rust
if let Some(result) = window.use_asset::<MyAsset>(&source, cx) {
    render_loaded(result, window, cx);
}
```

- `window.use_asset::<A>(&source, cx) -> Option<A::Output>`: load bitmediyse
  `None` döner ve ilk load tamamlanınca current view'i next frame'de notify eder.
- `window.get_asset::<A>(&source, cx) -> Option<A::Output>`: cache'i poll eder,
  ama tamamlandığında view redraw planlamaz.
- `cx.fetch_asset::<A>(&source) -> (Shared<Task<A::Output>>, bool)`: daha düşük
  seviye ortak task cache'i; aynı asset type/source için tek `Asset::load`
  future'ı paylaşılır.
- `AssetLogger<T>` `Asset<Output = Result<R, E>>` yükleyicisini sarar ve error
  sonucunu loglar.

SVG transform:

```rust
svg()
    .path("icons/check.svg")
    .with_transformation(
        Transformation::rotate(radians(0.2))
            .with_scaling(size(1.2, 1.2))
            .with_translation(point(px(2.), px(0.))),
    )
```

- `svg().path(...)`: embedded `AssetSource` içinden SVG okur.
- `svg().external_path(...)`: filesystem path'i okur.
- `Transformation::{scale, translate, rotate}` ve
  `with_scaling/with_translation/with_rotation` sadece çizimi etkiler; hitbox ve
  layout boyutu değişmez.
- Lower-level `TransformationMatrix::{unit, translate, rotate, scale}` scene
  primitive'lerinde kullanılır.
- `SvgSize` `SvgRenderer` render isteğinin raster boyutunu tanımlar:
  `Size(Size<DevicePixels>)` mutlak boyut, `ScaleFactor(f32)` SVG'nin
  bildirdiği boyuta çarpan uygular.

Tuzaklar:

- `with_content_mask` sadece clip mask'idir; hitbox veya layout'u otomatik
  küçültmez.
- `use_asset` redraw'ı current view entity'sine bağlar; view dışı helper'da
  çağırıyorsan current view beklentisini bozma.
- SVG transformation görsel olarak döndürür/ölçekler, fakat pointer hitbox'ı
  eski layout rect'inde kalır.


---

## Bölüm XII — Animasyon

---

### 68. Animasyon Sistemi

Animasyon API `crates/gpui/src/elements/animation.rs` içindedir.

`Animation` üç alandan oluşur: `duration: Duration`, `oneshot: bool` (false ise
tekrar eder), `easing: Rc<dyn Fn(f32) -> f32>`. Inşa: `Animation::new(duration)`
linear easing ile tek seferlik animasyon oluşturur. `.repeat()` döngüye alır,
`.with_easing(fn)` easing değiştirir.

`AnimationExt` trait, herhangi bir `IntoElement` için iki metot ekler:

```rust
use gpui::{Animation, AnimationExt};
use std::time::Duration;

div()
    .size(px(100.))
    .with_animation(
        "grow",
        Animation::new(Duration::from_millis(500))
            .with_easing(gpui::ease_in_out),
        |el, delta| el.size(px(100. + 100. * delta)),
    )
```

Çoklu animasyon zinciri için `with_animations(id, vec![anim_a, anim_b],
|el, ix, delta| ...)`. Closure'a (element, animation_index, delta_in_animation)
parametreleri verilir; `ix` aktif animasyonun vec içindeki sırasıdır, `delta`
o animasyona göre 0..1 ilerlemedir. Sıralı/çoklu fazlı geçiş yazarken
`ix` ile `match` yapılır.

Yerleşik easing fonksiyonları (`crates/gpui/src/elements/animation.rs:211+`):
`linear`, `quadratic`, `ease_in_out`, `ease_out_quint()`, `bounce(inner)`,
`pulsating_between(min, max)`. `pulsating_between` yön değiştirerek değer döndürür
(loading indicator için ideal; `Animation::repeat()` ile birleştirilir).

Tuzaklar:

- Element ID render boyunca stabil olmalıdır; değişirse animasyon state sıfırlanır.
- Animator closure `'static` olduğundan dış state'i `Rc`/`Arc`/`clone` ile yakala.
- Repeat animasyonu `window.request_animation_frame()` ile bir sonraki frame'i ister;
  bu da mevcut view'i sonraki frame'de notify eder. Gerekmiyorsa oneshot bırak.
- Frame'ler arası progress değeri executor saatinden hesaplanır; normal
  `TestAppContext`/`VisualTestContext` testlerinde `cx.background_executor.advance_clock(...)`
  veya `TestApp::advance_clock(...)` kullan. macOS'a özel `VisualTestAppContext`
  üzerinde ayrıca doğrudan `advance_clock(...)` helper'ı vardır.


---

## Bölüm XIII — Text Sistemi

---

### 69. Text, Font ve Metin Ölçümü

Ana tipler `crates/gpui/src/text_system.rs`, `style.rs` ve
`elements/text.rs` içinde:

- `TextStyle`: renk, font family, font size, line height, weight/style,
  decoration, whitespace, overflow, align, line clamp.
- `HighlightStyle`: belirli range'lere uygulanacak partial stil.
- `TextRun`: UTF-8 byte uzunluğu + font + renk/dekorasyon. Run toplam uzunluğu
  metin byte uzunluğunu tam karşılamalıdır.
- `StyledText`: `SharedString` + run/highlight/font override ile render edilir.
- `InteractiveText`: character/range bazlı click, hover ve tooltip sağlar.
- `Font`, `FontWeight`, `FontStyle`, `FontFeatures`, `FontFallbacks`.

Örnek:

```rust
let text = StyledText::new("Error: missing field")
    .with_highlights([(0..5, HighlightStyle {
        color: Some(rgb(0xff0000).into()),
        font_weight: Some(FontWeight::BOLD),
        ..Default::default()
    })]);

div()
    .text_size(rems(0.875))
    .font_family(".SystemUIFont")
    .line_height(relative(1.4))
    .child(text)
```

Metin ölçümü ve layout:

- `window.text_style()` aktif inherited style'ı verir.
- `window.text_system()` pencereye bağlı `WindowTextSystem`'dır.
- `App::text_system()` global text system'a erişir.
- `TextStyle::to_run(len)` inherited style'dan run üretir.
- `TextStyle::line_height_in_pixels(rem_size)` line-height değerini pixel'e çevirir.
- `window.line_height()` aktif text style'a göre satır yüksekliği döndürür.

Tuzaklar:

- Highlight range'leri byte range'dir; UTF-8 char boundary olmalıdır.
- `SharedString` kopyalamayı azaltır; render child'larında `String` yerine tercih et.
- `text_ellipsis`, `line_clamp`, `white_space` gibi overflow davranışları layout
  genişliğine bağlıdır; parent width belirsizse truncation beklediğin gibi çalışmaz.
- Uygulama genel text rendering modu `cx.set_text_rendering_mode(...)` ile
  `PlatformDefault`, `Subpixel`, `Grayscale` arasında seçilir. Subpixel akışı
  her glyph için yatayda `gpui::SUBPIXEL_VARIANTS_X: u8 = 4`, dikeyde
  `gpui::SUBPIXEL_VARIANTS_Y: u8 = 1` farklı varyant rasterize eder
  (`text_system.rs:45,48`); yani glyph atlas boyutu yatay subpixel pozisyonuna
  duyarlı, dikey değil.

### 70. StyledText, TextLayout ve InteractiveText

Basit metin `SharedString` olarak child verilebilir; ölçüm, highlight,
font override veya tıklanabilir aralık gerekiyorsa `StyledText` kullanılır.

`StyledText`:

```rust
let text = StyledText::new("Open settings")
    .with_highlights(vec![(0..4, highlight_style)])
    .with_font_family_overrides(vec![(5..13, "ZedMono".into())]);

let layout = text.layout().clone();
```

Precomputed `TextRun` varsa delayed highlight yerine `.with_runs(runs)` kullan;
`with_default_highlights(&default_style, ranges)` ise parent style yerine açık
bir `TextStyle` baz alarak run üretir.

Ölçüm/prepaint sonrası `TextLayout`:

- `index_for_position(point) -> Result<usize, usize>`: piksel pozisyonundan
  UTF-8 byte index'i.
- `position_for_index(index) -> Option<Point<Pixels>>`: byte index'ten piksel.
- `line_layout_for_index(index)`, `bounds()`, `line_height()`, `len()`,
  `text()`, `wrapped_text()`.

`TextLayout` değerleri layout/prepaint yapılmadan okunursa panic edebilir; bu
nedenle event handler veya after-layout path'inde kullanılır, render sırasında
ölçülmemiş layout'a güvenilmez.

`InteractiveText`:

```rust
InteractiveText::new("settings-link", StyledText::new("Open settings"))
    .on_click(vec![0..13], |range_index, window, cx| {
        window.dispatch_action(OpenSettings.boxed_clone(), cx);
    })
    .on_hover(|index, event, window, cx| {
        update_hover(index, event, window, cx);
    })
    .tooltip(|index, window, cx| build_tooltip(index, window, cx))
```

Aralıklar byte index aralığıdır; Unicode metinde character sınırlarını yanlış
hesaplamak hover/click eşleşmesini bozabilir. `on_click` yalnızca mouse down ve
mouse up aynı verilen range içinde kaldığında listener çağırır.


---

## Bölüm XIV — Input, Sistem ve Menü

---

### 71. Input, Clipboard, Prompt ve Platform Servisleri

Element event ailesi:

- Keyboard: `.on_key_down`, `.capture_key_down`, `.on_key_up`, `.capture_key_up`.
- Mouse: `.on_mouse_down`, `.capture_any_mouse_down`, `.on_mouse_up`,
  `.capture_any_mouse_up`, `.on_mouse_move`, `.on_mouse_down_out`,
  `.on_mouse_up_out`, `.on_click`, `.on_hover`.
- Gesture/scroll: `.on_scroll_wheel`, `.on_pinch`, `.capture_pinch`.
- Drag/drop: `.on_drag`, `.on_drag_move`, `.on_drop`.
- Action: `.capture_action::<A>`, `.on_action::<A>`, `.on_boxed_action`.

Event tipleri `interactive.rs` ve `platform.rs` içinde tanımlıdır:
`KeyDownEvent`, `KeyUpEvent`, `MouseDownEvent`, `MouseUpEvent`,
`MouseMoveEvent`, `MousePressureEvent`, `ScrollWheelEvent`, `PinchEvent`,
`FileDropEvent`, `ExternalPaths`, `ClickEvent`. `ScrollDelta::pixel_delta(line_height)`
line-based scroll'u pixel'e çevirir; `coalesce` aynı yöndeki delta'ları birleştirir.

Clipboard:

```rust
cx.write_to_clipboard(ClipboardItem::new_string("metin".to_string()));

if let Some(item) = cx.read_from_clipboard()
    && let Some(text) = item.text()
{
    // kullan
}
```

`ClipboardItem` birden çok `ClipboardEntry` taşıyabilir: `String`, `Image`,
`ExternalPaths`. String entry metadata'sı `new_string_with_metadata` veya
`new_string_with_json_metadata` ile yazılır. Linux/FreeBSD için primary selection
`read_from_primary`/`write_to_primary`, macOS Find pasteboard için
`read_from_find_pasteboard`/`write_to_find_pasteboard` cfg-gated API'lerdir.

Prompt ve dosya seçici:

- `window.prompt(level, message, detail, answers, cx) -> oneshot::Receiver<usize>`.
- `cx.set_prompt_builder(...)` custom GPUI prompt UI kurar; `reset_prompt_builder`
  native/default akışa döner.
- `cx.prompt_for_paths(PathPromptOptions { files, directories, multiple, prompt })`
  dosya/dizin seçici açar.
- `cx.prompt_for_new_path(directory, suggested_name)` save dialog açar.
- `cx.open_url(url)`, `cx.register_url_scheme(scheme)`, `cx.reveal_path(path)`,
  `cx.open_with_system(path)` platform servislerine gider.
- Platform credential store: `cx.write_credentials(url, username, password)`,
  `cx.read_credentials(url)`, `cx.delete_credentials(url)` async `Task<Result<_>>`
  döndürür.
- Uygulama yolu ve sistem bilgisi: `cx.app_path()`,
  `cx.path_for_auxiliary_executable(name)`, `cx.compositor_name()`,
  `cx.should_auto_hide_scrollbars()`.
- Restart ve HTTP client: `cx.set_restart_path(path)`, `cx.restart()`,
  `cx.http_client()`, `cx.set_http_client(client)`.

### 72. Prompt Builder, PromptHandle ve Fallback Prompt

`Window::prompt` platform dialog'u açar; platform prompt desteklemiyorsa veya
custom prompt builder set edilmişse GPUI içinde render edilen prompt kullanılır.

```rust
let response = window.prompt(
    PromptLevel::Warning,
    "Unsaved changes",
    Some("Close without saving?"),
    &[PromptButton::cancel("Cancel"), PromptButton::ok("Close")],
    cx,
);

let selected_index = response.await?;
```

Prompt tipleri:

- `PromptLevel::{Info, Warning, Critical}` görsel önem seviyesidir.
- `PromptButton::ok(label)`, `cancel(label)`, `new(label)` sırasıyla ok/cancel
  ve generic action butonu üretir; `label()` ve `is_cancel()` okunabilir.
- `PromptResponse(pub usize)`: custom prompt view'in seçilen buton index'ini
  emit ettiği event.
- `Prompt`: `EventEmitter<PromptResponse> + Focusable` trait birleşimidir.
- `PromptHandle::with_view(view, window, cx)`: custom prompt entity'sini
  window'a bağlar, önceki focus'u kaydeder, prompt yanıtında focus'u geri verir.
- `fallback_prompt_renderer(...)`: `set_prompt_builder` ile default GPUI prompt
  render'ını zorlamak için kullanılabilir.

Zed entegrasyonu (`crates/ui_prompt`):

- `ui_prompt::init(cx)` `WorkspaceSettings::use_system_prompts` ayarını
  `SettingsStore` üzerinden gözlemler. Sistem prompt'ları açıksa
  `cx.reset_prompt_builder()` çağırarak platform diyaloğuna düşer; aksi halde
  `cx.set_prompt_builder(zed_prompt_renderer)` ile GPUI içi markdown destekli
  prompt'a geçer. Linux/FreeBSD'de sistem prompt yoksayılır, daima Zed
  renderer kullanılır.
- `ZedPromptRenderer` public struct: `Markdown` entity'siyle message/detail
  render eder; cancel ve confirm action'larını içeride dispatch eder. Uygulama
  kodu doğrudan oluşturmaz, sadece prompt builder fonksiyonu tarafından
  kurulur.

Custom builder:

```rust
cx.set_prompt_builder(|level, message, detail, actions, handle, window, cx| {
    let message = message.to_string();
    let detail = detail.map(ToString::to_string);
    let actions = actions.to_vec();
    let view = cx.new(|cx| MyPrompt::new(level, message, detail, actions, cx));
    handle.with_view(view, window, cx)
});
```

Tuzaklar:

- GPUI re-entrant prompt desteklemez; bir prompt açıkken aynı window'da ikinci
  prompt açma path'i tasarlanmalıdır.
- Custom prompt `Focusable` sağlamalıdır; aksi halde `PromptHandle::with_view`
  focus restore zincirini tamamlayamaz.
- Prompt sonucu buton label'ı değil, `answers` dizisindeki index'tir.

### 73. Uygulama Menüsü ve Dock

`crates/gpui/src/platform/app_menu.rs`.

Tipler:

- `Menu { name, items, disabled }`
- `MenuItem`:
  - `Separator`
  - `Submenu(Menu)`
  - `SystemMenu(OsMenu)` — macOS Services gibi sistem submenu'leri.
  - `Action { name, action, os_action, checked, disabled }`
- `OsAction`: `Cut`, `Copy`, `Paste`, `SelectAll`, `Undo`, `Redo`. Native edit
  menu eşlemesi için.

Builder örneği:

```rust
cx.set_menus(vec![
    Menu::new("Zed").items([
        MenuItem::action("About Zed", zed::About),
        MenuItem::Separator,
        MenuItem::action("Quit", workspace::Quit),
    ]),
    Menu::new("Edit").items([
        MenuItem::os_action("Undo", editor::Undo, OsAction::Undo),
        MenuItem::os_action("Redo", editor::Redo, OsAction::Redo),
        MenuItem::Separator,
        MenuItem::os_action("Cut", editor::Cut, OsAction::Cut),
        MenuItem::os_action("Copy", editor::Copy, OsAction::Copy),
        MenuItem::os_action("Paste", editor::Paste, OsAction::Paste),
        MenuItem::os_action("Select All", editor::SelectAll, OsAction::SelectAll),
    ]),
]);
```

`MenuItem::action(name, action)` veri taşımayan unit struct action'lar için kısayoldur;
veri taşıyan action'larda da doğrudan action değerini geçebilirsin:
`MenuItem::action("Go To Line", GoToLine { line: 1 })`. Aynı menü modelinin
clone'lanması gerekiyorsa `Menu::owned()`/`MenuItem::owned()` kullanılır.

Diğer menü API'leri (`App` üzerinde):

- `cx.set_dock_menu(Vec<MenuItem>)` — macOS dock right-click menüsü; Windows'ta
  dock menu/jump list modelinin parçası.
- `cx.add_recent_document(path)` — macOS recent items.
- `cx.update_jump_list(menus, entries) -> Task<Vec<SmallVec<[PathBuf; 2]>>>` —
  Windows jump list'i günceller ve kullanıcının listeden kaldırdığı entry'leri
  task sonucu olarak döndürür. Zed `HistoryManager` bu sonucu history'den siler.
- `cx.get_menus()` — şu anda set edili menü modelini okur.

Platform davranışı:

- macOS native `NSMenu` ile çizilir; klavye kısayolları binding'lerden okunur.
- Windows ve Linux platform state'i `OwnedMenu` olarak saklar; Zed bu modeli
  uygulama içi menü/render katmanlarında kullanır.
- Linux dock menüsü backend'de `todo`/no-op'tur; dock/jump-list davranışı için
  platforma özel fallback gerekir.

Tuzak: Aynı action birden çok menü item'a bağlanırsa keymap'te tek shortcut
gösterilir. `os_action` yalnızca macOS native edit menu eşlemesini etkiler;
diğer platformlarda alelade action gibidir.


---

## Bölüm XV — Test

---

### 74. Test Rehberi

GPUI testlerinde:

- `#[gpui::test]` macro'su ve `TestAppContext` kullan.
- Pencere gerekiyorsa test context'in offscreen/window helper'larını kullan.
- Async timer için `cx.background_executor().timer(duration).await`.
- UI action testlerinde key binding ve action dispatch'i doğrudan test et.
- Görsel test gerekiyorsa `VisualTestContext` ve headless renderer desteğini kontrol et.
- Element debug bounds gerekiyorsa test-support altında `.debug_selector(...)` ekle.

Testlerde kaçınılacaklar:

- `smol::Timer::after(...)` ile `run_until_parked()` beklemek.
- `unwrap()` ile test dışı production yoluna panik taşımak.
- Async hata sonuçlarını `let _ = ...` ile yutmak.

### 75. Test Bağlamları ve Simülasyon

`crates/gpui/src/app/test_context.rs`, `crates/gpui/src/app/visual_test_context.rs`.

`#[gpui::test]` makrosu bir `TestAppContext` sağlar. Görsel test için
`add_window` bir `WindowHandle<V>` döndürür ve `VisualTestContext` ile sürülür.
İsim benzerliğine dikkat: `VisualTestContext` test penceresini kendi içinde tutar;
macOS `test-support` altındaki `VisualTestAppContext` ise window handle'ı açık
argüman olarak alan ayrı bir bağlamdır.

```rust
#[gpui::test]
fn test_save(cx: &mut TestAppContext) {
    let window = cx.add_window(|window, cx| cx.new(|cx| Editor::new(window, cx)));

    cx.simulate_keystrokes(window, "cmd-s");
    cx.run_until_parked();

    window.read_with(cx, |editor, _| {
        assert!(editor.is_clean);
    });
}
```

Sık kullanılan API'ler:

- `cx.add_window(|window, cx| cx.new(...))`: yeni offscreen pencere.
- `cx.simulate_keystrokes(window, "cmd-s left")`: boşlukla ayrılmış keystroke dizisi.
- `cx.simulate_input(window, "hello")`: text input simulasyonu.
- `cx.dispatch_action(window, action)`.
- `cx.run_until_parked()`: tüm pending future/task tamamlanıncaya kadar sürer.
- `cx.background_executor.advance_clock(duration)`: deterministic timer ilerletme.
- `cx.background_executor.run_until_parked()`: test executor'ında yalnızca background.
- `window.update(cx, |view, window, cx| ...)`: pencere içi state mutate.

`add_window_view` veya `add_empty_window` ile alınan `VisualTestContext` pencere
bağlamını taşıdığı için *bazı* metotları window argümansız çağrılır:

- `cx.simulate_keystrokes("cmd-p")` ve `cx.simulate_input("hello")` — `self.window`
  kullanır.
- `cx.dispatch_action(action)` — yine `self.window` üzerinden dispatch eder.
- `cx.run_until_parked()`, `cx.window_title()`, `cx.document_path()` window-less
  helper'lardır.

Mouse simülasyon metotları `VisualTestContext` üzerinde de `self.window`
üzerinden çalışır ve window argümanı almaz (`test_context.rs:764-809`):

- `cx.simulate_mouse_move(position, button, modifiers)`
- `cx.simulate_mouse_down(position, button, modifiers)`
- `cx.simulate_mouse_up(position, button, modifiers)`
- `cx.simulate_click(position, modifiers)`

Pencere argümanı isteyen helper'lar `TestAppContext` üzerindeki
`simulate_keystrokes(window, ...)`, `simulate_input(window, ...)`,
`dispatch_action(window, ...)` ve `dispatch_keystroke(window, ...)` ailesidir.
`VisualTestContext` bu window handle'ı kendi içinde tuttuğu için aynı klavye ve
action helper'larını window-less sarmallar olarak sunar.
`VisualTestAppContext` ise `simulate_keystrokes(window, ...)`,
`simulate_mouse_move(window, ...)`, `simulate_click(window, ...)` ve
`dispatch_action(window, ...)` şeklindeki window argümanlı formu kullanır.

Pratik kurallar:

- Real tutarlılık için `smol::Timer` yerine `cx.background_executor.timer(d)` kullan.
- `run_until_parked` ile `advance_clock` kombine edilirken önce clock ilerlet,
  sonra park bekle. `VisualTestContext` `TestAppContext` içine deref ettiği için
  normal yolda `cx.background_executor.advance_clock(d)` kullanılır; direct
  `advance_clock(d)` helper'ı `VisualTestAppContext` üzerindedir.
- Async test için `#[gpui::test]` `async fn(cx: &mut TestAppContext)` formunu
  destekler; foreground task'ları orada `cx.spawn` ile kur.
- Pencerenin gerçekten render edilmesi için `VisualTestContext::draw(...)`,
  `TestApp::draw()` veya doğrudan `window.draw(cx).clear()` kullanılan bir
  pencere update'i gerekebilir; aksi halde debug bounds/layout bilgisi üretilmez.

Tuzaklar:

- `simulate_keystrokes` action dispatch'i tetikler ama keymap binding kaydedilmiş
  olmalıdır; testte `cx.bind_keys([...])` çağırmayı unutma.
- `run_until_parked` zaman ilerletmez; sadece pending future'ları sürer. Timer
  beklenirken `advance_clock` şart.
- `dispatch_action` focus tree'de action handler bulamazsa sessizce no-op'tur;
  view'in gerçekten focused olduğundan emin ol.


---

## Bölüm XVI — Inspector ve Düşük Seviye API

---

### 76. Inspector ve Debug Yardımcıları

`crates/gpui/src/inspector.rs` (feature: `inspector`).

`gpui` crate'i `inspector` feature ile derlendiğinde (veya `debug_assertions`
açıkken) dev tool entegrasyonu sağlar:

- `InspectorElementId`: her element için `(file, line, instance)` tabanlı kimlik.
- `InspectorElementPath` (`inspector.rs:30`): bir elementin
  `GlobalElementId` zincirini ve construction'dan `&'static Location` source
  location'ını birleştiren kimlik. Element seçildiğinde inspector UI'ı bu
  path üzerinden source link gösterir. Hem alanları hem `Clone` impl'i feature
  gate altındadır.
- Element source location `#[track_caller]` ile yakalanır ve
  `InspectorElementPath.source_location` alanına yazılır.
- Element seçimi window'da `Inspector` global state üzerinden tetiklenir.
- `Window::toggle_inspector(cx)` inspector panelini açar/kapatır.
- `Window::with_inspector_state(...)` aktif elemente özel geçici inspector state'i
  tutar.
- `App::set_inspector_renderer(InspectorRenderer)` inspector UI'ını bağlar.
  `InspectorRenderer` (`inspector.rs:55`) bir type alias'tır:

  ```rust
  pub type InspectorRenderer =
      Box<dyn Fn(&mut Inspector, &mut Window, &mut Context<Inspector>) -> AnyElement>;
  ```

  Yani inspector panelinin içeriği bu closure tarafından üretilir; argümanlar
  Inspector state, ait olduğu Window ve Inspector için Context.
- `App::register_inspector_element(...)` belirli element tipinin inspector
  panel render'ını kaydeder; element seçildiğinde state için custom UI çizer.

Reflection katmanı (Styled metotlarını runtime'da listelemek için):

`Styled` trait `cfg(any(feature = "inspector", debug_assertions))` altında
`#[gpui_macros::derive_inspector_reflection]` ile annote edilir
(`styled.rs:18-21`). Bu macro yan etki olarak iki API üretir:

- **`gpui::styled_reflection`** — proc macro çıktısı modül.
  - `pub fn methods<T: Styled + 'static>() -> Vec<FunctionReflection<T>>`:
    `Styled` trait'inin tüm reflectable metotlarını belirli bir somut tip için
    wrap eder.
  - `pub fn find_method<T: Styled + 'static>(name: &str) -> Option<FunctionReflection<T>>`:
    aynı listeyi name eşleşmesiyle filtreler.
- **`gpui::inspector_reflection::FunctionReflection<T>`** (`inspector.rs:233`):
  ```rust
  pub struct FunctionReflection<T> {
      pub name: &'static str,
      pub function: fn(Box<dyn Any>) -> Box<dyn Any>,
      pub documentation: Option<&'static str>,
      pub _type: PhantomData<T>,
  }
  ```
  `documentation` alanı trait metodunun `///` doc comment'inden çıkarılır
  (`gpui_macros::extract_doc_comment`). Inspector UI bu metni markdown olarak
  render eder — örn. `inspector_ui/src/div_inspector.rs:670` Styled metodu
  autocomplete'inde `CompletionDocumentation::MultiLineMarkdown` formuna
  sarmalıyor. Tailwind doc linki gibi ham link'ler de bu yolla hyperlink olur.
- `FunctionReflection::invoke(value: T) -> T` — metodu çalışma zamanında
  çağırır; inspector "method picker" akışında kullanıcı bir style metodunu
  seçince mevcut element'in `StyleRefinement`'ı bu invoke ile dönüştürülür.

Production build'de inspector kodu sıfır maliyetlidir; reflection module ve
`FunctionReflection` da feature gate'in dışında bulunmadığı için release Zed
binary'sinde derlenmez.

Diğer debug helper'ları:

- `div().debug_selector(|| "my-button")`: test ve inspector'da selector ata.
- `crates/gpui/src/profiler.rs`: executor task timing buffer'ları; runtime'da
  `gpui::profiler::set_enabled(true)` ile açılır ve thread timing delta'ları
  `ProfilingCollector` ile okunur.
- `RUST_LOG=gpui=debug` ile event/key dispatch log seviyesi yükselir.
- `debug_selector` değerleri testte `VisualTestContext::debug_bounds(selector)`
  üzerinden okunur; production overlay için ayrı bir env bayrağına güvenme.

### 77. Default Colors, GPU Specs ve Platform Diagnostics

Tema sistemi dışındaki küçük ama pratik platform yüzeyleri:

- `Colors::for_appearance(window)`: `WindowAppearance::Light/VibrantLight`
  için light, `Dark/VibrantDark` için dark default palet döndürür.
- `Colors::light()`, `Colors::dark()`, `Colors::get_global(cx)`: GPUI örnekleri
  ve base component'lerde kullanılan framework renkleri. Zed uygulama UI'ında
  esas kaynak `cx.theme().colors()` olmalıdır.
- `DefaultColors` trait'i `cx.default_colors()` kısayolunu sağlar; bunun için
  `GlobalColors(Arc<Colors>)` global state olarak set edilmiş olmalıdır.
- `DefaultAppearance::{Light, Dark}` `WindowAppearance` değerinden türetilir ve
  base GPUI renk setini seçmek için kullanılır.
- `window.gpu_specs() -> Option<GpuSpecs>`: Linux/Vulkan tarafında GPU/driver
  bilgisi ve software emulation durumu; macOS ve Windows'ta şu anda `None`
  dönebilir.
- `window.set_window_edited(true)`: platform seviyesinde "dirty document"
  göstergesi.
- `window.set_document_path(Some(path))`: macOS'ta `AXDocument` accessibility
  property değerini ayarlar.
- `window.play_system_bell()`: platform alert sesi.
- `window.window_title()`, `titlebar_double_click()`, `tabbed_windows()`,
  `merge_all_windows()`, `move_tab_to_new_window()`,
  `toggle_window_tab_overview()`, `set_tabbing_identifier(...)`: macOS'a özgü
  pencere/tab entegrasyonlarıdır.
- `window.input_latency_snapshot()`: `input-latency-histogram` feature'ı açıkken
  input-to-frame ve mid-frame input histogramlarını döndürür.

Bu API'ler tema veya pencere oluşturma akışının merkezinde değildir; ama
diagnostic ekranları, test harness'leri, macOS doküman pencereleri ve platforma
duyarlı davranışlarda rehbere dahil edilmelidir.

### 78. Window Runtime Snapshot, Layout Ölçümü ve Frame Zamanlama

Zed'in `workspace` ve `ui` katmanında sık görülen bazı `Window` çağrıları
render çıktısı üretmez; o anki pencere/input durumunu okumak veya işi doğru frame
fazına taşımak için kullanılır.

Anlık input snapshot'ı:

- `window.modifiers() -> Modifiers`: o an basılı modifier'ları verir. Zed'de
  Shift/Alt/Ctrl ile notification suppress, pane clone veya quick action preview
  davranışı değiştirmek için kullanılır.
- `window.capslock() -> Capslock`: capslock durumunu okur.
- `window.mouse_position() -> Point<Pixels>`: pointer'ın pencere içi konumu.
  Context menu ve right-click menu konumlandırmasında doğrudan kullanılır.
- `window.last_input_was_keyboard() -> bool`: focus-visible kararlarında ana
  sinyaldir; pointer ile focuslanan elemente gereksiz focus ring çizmemek için.
- `window.is_window_hovered() -> bool`: tooltip, popover veya hover overlay'i
  window dışına çıkınca kapatmak gibi durumlarda kullanılır.

Render/prepaint sırasında current view ve layout:

- `window.current_view() -> EntityId`: şu anda render/prepaint/paint edilen view
  entity'sidir. `request_animation_frame`, `use_asset` ve hover/indent-guide gibi
  delayed notify akışları bu id'ye bağlanır. Yalnızca draw fazlarında anlamlıdır;
  uzun süre saklanacak domain id gibi ele alınmamalıdır.
- `window.request_layout(style, children, cx) -> LayoutId`: custom element'in
  taffy layout ağacına node eklemesidir.
- `window.request_measured_layout(style, measure) -> LayoutId`: text veya dinamik
  ölçüm gerektiren elementlerde layout zamanı ölçüm closure'ı sağlar.
- `window.compute_layout(layout_id, available_space, cx)`: verilen layout node'u
  için hesaplamayı tetikler.
- `window.layout_bounds(layout_id) -> Bounds<Pixels>`: hesaplanan bounds'u
  pencere koordinatlarında döndürür. Popover/right-click menu gibi bileşenler
  anchor bounds'u öğrenmek için bunu prepaint sırasında okur.
- `window.pixel_snap(...)`, `pixel_snap_f64(...)`, `pixel_snap_point(...)`,
  `pixel_snap_bounds(...)`: logical pikseli device pixel grid'e hizalar. İnce
  çizgi, indent guide ve overlay border'larında bulanıklığı azaltmak için kullan.

Frame zamanlama araçları:

```rust
window.on_next_frame(|window, cx| {
    window.refresh();
});

cx.on_next_frame(window, |this, window, cx| {
    this.remeasure(window, cx);
});

window.defer(cx, |window, cx| {
    window.dispatch_action(MyAction.boxed_clone(), cx);
});
```

- `window.on_next_frame(...)`: mevcut frame tamamlandıktan sonraki frame'de çalışır.
  Layout sonucu, hitbox veya popover konumu bir frame sonra bilinecekse doğru
  araçtır. Zed UI'da bazı menu konumlandırmaları iki kez `on_next_frame` kullanır;
  ilk frame anchor/layout bilgisini, ikinci frame menu entity'sinin kendi bounds'unu
  stabilize eder.
- `Context<T>::on_next_frame(window, |this, window, cx| ...)`: aynı işin current
  entity'ye bağlı helper'ıdır; callback içinde entity update context'i gelir.
- `window.request_animation_frame()`: sürekli animasyon, GIF/video veya animated
  image için yeni frame ister. Bir view içinde çağrıldığında current view'i next
  frame'de notify eder.
- `cx.defer(...)`, `window.defer(cx, ...)`, `cx.defer_in(window, ...)`: mevcut
  effect cycle bittikten sonra çalışır. Entity zaten update stack'inde olduğunda
  reentrant update panic'inden kaçmak veya focus/menu dispatch'ini stack boşalınca
  yapmak için kullanılır. Layout ölçümü gerekiyorsa `defer` değil `on_next_frame`
  tercih edilir.

Low-level custom element hook'ları:

- `window.insert_window_control_hitbox(area, hitbox)`: paint fazında platform
  control hitbox'ı kaydeder; Windows custom titlebar'da min/max/close ve drag
  alanları için kullanılır.
- `window.set_key_context(context)`: paint fazında current dispatch node'una
  keybinding context bağlar. Element API'deki `.key_context(...)` bunun sarmalıdır.
- `window.set_focus_handle(&focus_handle, cx)`: prepaint fazında current dispatch
  node'unu focus handle ile ilişkilendirir. Element API'deki `.track_focus(...)`
  çoğu uygulama kodunda daha doğru seviyedir.
- `window.set_view_id(view_id)`: prepaint fazında dispatch/cache node'una view id
  bağlar. Kaynak yorumunda kaldırılması planlanan düşük seviyeli bir kaçış yolu
  olarak işaretlidir; normal view render akışında kullanma.
- `window.bounds_changed(cx)`: platform resize/move callback'inin yaptığı state
  yenileme ve observer notify işlemini tetikler. Platform/test altyapısı içindir;
  app code'da resize simülasyonu dışında çağırma.

### 79. App/Window Low-level Servisleri: Platform, Text, Palette ve Atlas

Bu küçük API'ler ana render modelinin parçası değildir, fakat Zed başlangıcı,
editor text davranışı ve image cache gibi yerlerde kullanılır.

Application/platform kurulumu:

- `Application::with_platform(Rc<dyn Platform>)` Application kurmak için tek
  yapıcıdır; `Application::new()` diye sade bir constructor yoktur.
- Production kodu genellikle bu yapıcıyı doğrudan çağırmaz; `gpui_platform`
  yardımcıları kullanılır:
  - `gpui_platform::application()` →
    `Application::with_platform(current_platform(false))`.
  - `gpui_platform::headless()` →
    `Application::with_platform(current_platform(true))`.
  - Hedef wasm tek thread ise `gpui_platform::single_threaded_web()` aynı
    desenin web varyantıdır.
- Test koşumunda `Application::with_platform(test_platform)` ile
  `TestPlatform`/`VisualTestPlatform` enjekte edilir; `Application::run`
  GPUI'a sahipliği geçirip event loop'u sürer.
- `Application::with_assets(Assets)` embedded asset kaynağını bağlar; `svg()`,
  `window.use_asset` ve bundled resource yüklemeleri buna dayanır. SVG
  rasterizer da bu çağrıdan sonra reset edilir.
- `Application::with_http_client(Arc<dyn HttpClient>)` runtime HTTP istemcisini
  bağlar; default `NullHttpClient` instance'tır.
- Headless testlerde `HeadlessAppContext::with_platform(...)` aynı fikrin test
  harness versiyonudur (UI penceresi açmadan App, executor ve platform
  servislerini kurar).

Text/render servisleri:

- `cx.set_text_rendering_mode(mode)` ve `cx.text_rendering_mode()` uygulama
  genel text rendering modunu yönetir. Zed startup'ta ayarlardan gelen değeri
  buraya yazar.
- `TextRenderingMode::{PlatformDefault, Subpixel, Grayscale}` desteklenir.
  `PlatformDefault` text system tarafında platformun önerdiği gerçek moda
  çözülür; ölçüm/paint path'inde enum'u doğrudan string ayar gibi ele alma.
- `cx.svg_renderer() -> SvgRenderer` low-level SVG rasterizer handle'ını verir.
  Uygulama elementleri çoğunlukla `svg()` veya `window.paint_svg(...)` kullanır;
  cache/renderer entegrasyonu yazıyorsan doğrudan erişim gerekir.
- `window.show_character_palette()` platform karakter paletini açar. Editor
  tarafındaki `show_character_palette` action'ı bu çağrıya iner.

Image atlas ve kaynak bırakma:

- `window.drop_image(Arc<RenderImage>) -> Result<()>`: current window sprite
  atlas'ından image kaynağını bırakır.
- `cx.drop_image(image, current_window)`: tüm pencerelerde atlas temizliği yapar.
  Current window update edilirken `App.windows` içinden geçici olarak çıkmış
  olabileceği için `Some(window)` argümanı ayrıca verilir.
- Zed/GPUI image cache release callback'leri atlas sızıntısı olmaması için bu
  API'leri kullanır; normal `img()`/`svg()` kullanımında elle çağırman gerekmez.

Pencere/platform küçük servisleri:

- `window.display(cx) -> Option<Rc<dyn PlatformDisplay>>`: pencerenin bulunduğu
  display'i platform display listesiyle eşler.
- `window.show_character_palette()`, `window.play_system_bell()`,
  `window.set_window_edited(...)`, `window.set_document_path(...)` gibi çağrılar
  platform entegrasyonudur; cross-platform davranışları platform trait
  implementasyonuna bağlıdır.
- `window.gpu_specs()` ve feature-gated `window.input_latency_snapshot()` diagnostic
  ekranlar veya performans analizleri içindir, uygulama state akışının kaynağı
  yapılmamalıdır.

Tuzaklar:

- `cx.svg_renderer()` veya `cx.drop_image(...)` gibi low-level servisleri component
  API yerine kullanmak ownership/cache sorumluluğunu da sana verir.
- `Application::with_platform` production'da tek platform seçimini startup'ta
  yapar; runtime platform değiştirme mekanizması değildir.
- `show_character_palette` her platformda gerçek UI açmayabilir; platform
  implementasyonu no-op olabilir.

### 80. CursorStyle, FontWeight ve Sabit Enum Tabloları

Sık başvurulan ama her seferinde aramak zorunda kalınan platform sabitleri:

#### `CursorStyle` (`crates/gpui/src/platform.rs:1745+`)

CSS cursor karşılıklarıyla:

- `Arrow` (default)
- `IBeam`, `IBeamCursorForVerticalLayout` — text input
- `Crosshair`
- `OpenHand` (`grab`), `ClosedHand` (`grabbing`)
- `PointingHand` (`pointer`)
- `ResizeLeft`, `ResizeRight`, `ResizeLeftRight` — yatay resize
- `ResizeUp`, `ResizeDown`, `ResizeUpDown` — dikey resize
- `ResizeUpLeftDownRight`, `ResizeUpRightDownLeft` — köşe resize
- `ResizeColumn`, `ResizeRow` — tablo/grid resize
- `OperationNotAllowed` (`not-allowed`)
- `DragLink` (`alias`), `DragCopy` (`copy`)
- `ContextualMenu` (`context-menu`)

Element'te: `.cursor(CursorStyle::PointingHand)` veya kısayollar
`.cursor_pointer()`, `.cursor_text()`, `.cursor_grab()`, `.cursor_default()`.

#### `FontWeight` (`crates/gpui/src/text_system.rs:871+`)

CSS weight değerleriyle birebir:

- `THIN` (100), `EXTRA_LIGHT` (200), `LIGHT` (300)
- `NORMAL` (400, default), `MEDIUM` (500)
- `SEMIBOLD` (600), `BOLD` (700)
- `EXTRA_BOLD` (800), `BLACK` (900)

`FontWeight::ALL` dizisi tüm değerleri sırayla taşır. UI bileşenlerinde
genellikle `FontWeight::SEMIBOLD` ve `FontWeight::BOLD` kullanılır.

#### `FontStyle`

`Normal`, `Italic`, `Oblique`. `.italic()` fluent kısayolu Italic'e set eder.

#### `WindowControlArea` (`crates/gpui/src/window.rs:564`)

`Drag`, `Close`, `Max`, `Min`. Custom titlebar yazarken Windows native hit-test
için zorunlu.

#### `HitboxBehavior` (`crates/gpui/src/window.rs:692`)

`Normal`, `BlockMouse`, `BlockMouseExceptScroll`. `.occlude()` ve
`.block_mouse_except_scroll()` element kısayolları sırasıyla son ikisini set eder.

#### `BorderStyle` (`crates/gpui/src/scene.rs:544`)

`Solid`, `Dashed`. `Style::border_style` veya `paint_quad` ile geçilir.

#### `Anchor`, `Corners` ve Layer-shell `Anchor`

Anchored elementte kullanılan tip `gpui::Anchor`'dır:
`TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`, `TopCenter`,
`BottomCenter`, `LeftCenter`, `RightCenter`.

`Corners<T>` farklı bir tiptir; border radius/quad köşe yarıçapları içindir.
Layer-shell modülündeki `Anchor` ise bitflag yapısıdır
(`TOP | BOTTOM | LEFT | RIGHT`) ve anchored element `Anchor`'ıyla karıştırılmaz.

#### `ResizeEdge` (`crates/gpui/src/platform.rs:358`)

`Top`, `Bottom`, `Left`, `Right`, `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`.
`window.start_window_resize(edge)` argümanı.

### 81. Kalan GPUI Tipleri: Dış API ve Crate-İçi Sınır

Bu bölüm, iki farklı yüzeyi ayırır: `crates/gpui/src/gpui.rs` üzerinden dışarı
export edilen public API ve private modüllerde `pub` tanımlanmış olsa da yalnız
crate içinde erişilebilen taşıyıcılar. `pub` kelimesi tek başına dış API anlamına
gelmez; dış kullanıcı açısından asıl sınır `gpui.rs` içindeki `pub use ...` /
`pub(crate) use ...` kararlarıdır.

#### Style ve Layout Enumları

`style.rs` tarafındaki temel enum/type alias'lar `Styled` fluent metotlarının
arkasındaki ham değerlerdir:

- Hizalama: `AlignItems`, `AlignSelf`, `JustifyItems`, `JustifySelf`,
  `AlignContent`, `JustifyContent`.
- Flex: `FlexDirection`, `FlexWrap`.
- Görünürlük ve metin: `Visibility`, `WhiteSpace`, `TextOverflow`, `TextAlign`.
- Dolgu: `Fill` (`style.rs:808`); şu an tek varyantı `Color(Background)`'tır.
  Tek varyantlı bir enum olmasının nedeni gelecekte ek dolgu tipleri (örn. örüntü
  tabanlı fill) eklenebilmesi için API'yi sabit tutmak. Solid renk dışında bir
  şey üretmek istiyorsan `Background` tipinin `linear_gradient`/`pattern_slash`/
  `checkerboard` constructor'larını kullan.
- Debug: `DebugBelow`, yalnız `debug_assertions` altında derlenir; `debug_below`
  styling'ini custom element içinden okumak için global marker olarak kullanılır.

Uygulama kodunda genellikle bu enumları doğrudan construct etmek yerine
`.items_center()`, `.justify_between()`, `.flex_col()`, `.whitespace_nowrap()`,
`.text_ellipsis()` gibi helper metotlar kullanılır. Custom element veya style
refinement yazarken ham enumlar gerekir.

#### Geometri Yardımcıları

`geometry.rs` public yüzeyindeki düşük seviye yardımcılar:

- `Axis` ve `Along`: yatay/dikey eksene göre `Point`, `Size`, `Bounds` gibi
  tiplerden ilgili boyutu seçmek için kullanılır.
- `Half` ve `IsZero`: generic geometri hesaplarında yarıya bölme ve sıfır testi
  sağlayan trait'lerdir.
- `Radians`/`radians(value)` ve `Percentage`/`percentage(value)`: transform,
  gradient ve responsive ölçü değerlerini tip güvenli taşır.
- `GridLocation` ve `GridPlacement`: `.grid_row(...)`, `.grid_col(...)`,
  `.grid_area(...)` gibi style metotlarının ham grid yerleşim girdisidir.
- `PathStyle`: path çiziminde fill/stroke stil seçimini taşır.

Bu tipleri özellikle custom layout hesaplarında, canvas/path çiziminde ve grid
placement değerlerini programatik üretirken kullan.

#### Element ve Frame-State Taşıyıcıları

Bazı public tipler element ağacının layout/prepaint/paint fazları arasında state
taşır:

- `Drawable<E>`, `Canvas<T>`, `AnimationElement<E>`, `Svg`, `Img`, `SurfaceSource`.
- `AnchoredState`, `DivFrameState`, `DivInspectorState`, `ImgLayoutState`,
  `ListPrepaintState`, `InteractiveTextState`, `UniformListFrameState`,
  `UniformListScrollState`.
- `InteractiveElementState`, `ElementClickedState`, `ElementHoverState`,
  `GroupStyle`, `DragMoveEvent<T>`.
- `DeferredScrollToItem`, `ItemSize`, `UniformListDecoration`,
  `ListScrollEvent`, `ListMeasuringBehavior`, `ListHorizontalSizingBehavior`.

Normal uygulama kodunda bu state tipleri çoğunlukla doğrudan tutulmaz; `div()`,
`canvas(...)`, `img(...)`, `svg()`, `list(...)`, `uniform_list(...)`,
`anchored()`, `deferred(...)` ve ilgili element builder'ları bunları üretir.
Custom element implementasyonu yazarken `Element::request_layout`,
`Element::prepaint` ve `Element::paint` dönüş değerlerinde bu taşıyıcıların
benzer desenlerini izle.

#### Input Event Tipleri

`interactive.rs` event ailesi:

- Trait sınıfları: `InputEvent`, `KeyEvent`, `MouseEvent`, `GestureEvent`.
- Klavye: `ModifiersChangedEvent`, `KeyboardClickEvent`, `KeyboardButton`.
- Mouse: `MouseClickEvent`, `MouseExitEvent`, `PressureStage`.
- Dokunma/gesture: `TouchPhase`, `NavigationDirection`.
- Hitbox: `HitboxId` rendered frame içinde hitbox'ı tanımlayan opaque id'dir;
  uygulama kodu genellikle `Hitbox` handle'ı ve `window.hitbox(...)` sonucu ile
  çalışır.
- Drag/drop tarafında `ExternalPaths` ve `FileDropEvent` Bölüm 38'te ayrıca
  ele alındı.

Element callback'lerinde çoğu zaman concrete event tipi otomatik gelir:
`.on_mouse_down(|event, window, cx| ...)`, `.on_scroll_wheel(...)`,
`.on_modifiers_changed(...)` gibi. Synthetic test event'i veya platform input
çevirimi yazarken `InputEvent::to_platform_input()` hattı önemlidir.

**Modifiers deref aliasing (asimetrik):** Aşağıdaki dört event açıkça
`impl Deref for X { type Target = Modifiers; }` taşır
(`crates/gpui/src/interactive.rs:77`, `:450`, `:502`, `:590`):

- `ModifiersChangedEvent`
- `ScrollWheelEvent`
- `PinchEvent`
- `MouseExitEvent`

Sonuç olarak `Modifiers` üzerindeki tüm `&self` metotları — `secondary()`,
`modified()`, `number_of_modifiers()`, `is_subset_of(...)` ve `control`,
`alt`, `shift`, `platform`, `function` alanları — bu dört event üzerinde
doğrudan çağrılabilir. Konu 43'teki kısayollar (`Modifiers::command_shift()`
vb.) ise `Modifiers` üzerinde **inherent associated function**'dır; event
üzerinden çağrılmaz, ayrı bir `Modifiers` üretmek için kullanılır.

`MouseDownEvent`, `MouseUpEvent` ve `MouseMoveEvent` Deref *etmez*; yalnızca
`modifiers: Modifiers` alanını ifşa eder. Bu yüzden bu üç event'te
`event.modifiers.secondary()` yazılır, dört Deref'li event'te ise hem
`event.modifiers.secondary()` hem `event.secondary()` çalışır. Asimetri
kasıtlıdır: Deref'li dörtlü "input'un modifier şapkası budur" semantiğini
taşır; mouse press/move event'leri ise modifier'ı sadece yan veri olarak
saklar.

**Denetim komutu:** Yeni bir event ailesinde Deref var mı:

```sh
rg -n '^impl Deref for [A-Z][A-Za-z]+(Event|Action)' \
  ../zed/crates/gpui/src/interactive.rs \
  ../zed/crates/gpui/src/platform.rs
```

#### Image, SVG ve Cache Taşıyıcıları

Image/SVG hattında public fakat genelde framework tarafından taşınan tipler:

- `ImageId`, `ImageFormat`, `ClipboardString`.
- `ImageFormatIter`: `ImageFormat` üzerindeki `#[derive(EnumIter)]`
  (`platform.rs:1973`) ile otomatik üretilen iterator tipi. Uygulama kodu
  doğrudan adlandırmaz; `ImageFormat::iter()` çağrısı (strum'dan) bu tipi
  döndürür. `from_mime_type` fonksiyonu kendi içinde
  `Self::iter().find(...)` ile clipboard içeriğini "olası en yaygın formattan
  başlayarak" eşleştirir; varyant sırası — Png, Jpeg, Webp, Gif, Svg, Bmp,
  Tiff, Ico, Pnm — kasıtlıdır ve iter sonucunu doğrudan etkiler.
- `ImageStyle`, `ImageAssetLoader`, `ImageCacheProvider`, `AnyImageCache`,
  `ImageCacheItem`, `ImageLoadingTask`, `RetainAllImageCacheProvider`.
- `RenderImageParams` ve `RenderSvgParams`: renderer'a verilecek rasterization
  parametrelerini taşır.

Uygulama seviyesinde çoğunlukla `img(source)`, `svg().path(...)`,
`image_cache(retain_all(id))`, `window.use_asset(...)`, `window.paint_image(...)`
ve `window.paint_svg(...)` kullanılır. Cache implementasyonu yazıyorsan
`ImageCacheProvider -> ImageCache -> ImageCacheItem` zincirine inilir.

#### Platform, Dispatcher, Atlas ve Renderer Sınırı

Platform implementasyonu veya headless renderer yazılmadıkça aşağıdaki tipler
application kodunda nadiren doğrudan kullanılır:

- Display/diagnostic: `DisplayId`, `ThermalState`, `SourceMetadata`,
  `RequestFrameOptions`, `WindowParams`, `InputLatencySnapshot`.
- Dispatcher/executor: rustdoc public yüzeyinde `Scope`, `FallibleTask`,
  `SchedulerForegroundExecutor` ve `RunnableMeta` görünür. Buna ek olarak
  platform sınırında `#[doc(hidden)]` tutulan `PlatformDispatcher`,
  `RunnableVariant` (`Runnable<RunnableMeta>` type alias'ı) ve
  `TimerResolutionGuard` vardır; bunlar `target/doc/gpui/all.html` listesinde
  yer almaz ve uygulama API'si olarak kullanılmamalıdır.
  Detay:
  - `RunnableMeta { location: &'static Location<'static> }`
    (`scheduler/src/scheduler.rs:59`) — her scheduled task'a iliştirilen debug
    metadata. `track_caller` ile yakalanan kaynak konumunu taşır; profiler ve
    log akışı doc-hidden `RunnableVariant` üzerinden bu alana ulaşır.
  - `FallibleTask<T>` (`scheduler/src/executor.rs:250`) — `Task::fallible(self)`
    çağrısının döndürdüğü wrapper. Future olarak poll edildiğinde `Option<T>`
    döner; iptal edilirse panik atmaz, `None` üretir. `must_use` işaretli olduğu
    için sessizce drop edilirse derleme uyarısı verir.
  - `SchedulerForegroundExecutor` — `gpui::executor.rs:10` `pub use scheduler::ForegroundExecutor as SchedulerForegroundExecutor`
    re-export'u. GPUI tarafındaki `ForegroundExecutor` bunun üzerinde wrapper'dır;
    ham scheduler handle'ına `ForegroundExecutor::scheduler_executor()`
    (`executor.rs:369`) çağrısıyla inilir, `BackgroundExecutor::scheduler_executor()`
    de paralel `scheduler::BackgroundExecutor` döner. Uygulama kodu genelde
    `cx.foreground_executor()` veya `cx.background_executor()` kullanır;
    scheduler handle yalnızca scheduler crate'iyle doğrudan etkileşim gerekirse
    çekilir.
- Text/keyboard: `PlatformTextSystem`, `NoopTextSystem`,
  `PlatformKeyboardLayout`, `PlatformKeyboardMapper`, `DummyKeyboardMapper`,
  `PlatformInputHandler`.
- GPU atlas: `PlatformAtlas`, `AtlasKey`, `AtlasTextureList<T>`, `AtlasTile`,
  `AtlasTextureId`, `AtlasTextureKind`, `TileId`.
- Headless/screen capture: `PlatformHeadlessRenderer`, `scap_screen_sources(...)`.
- Test platformu: `TestDispatcher`, `TestScreenCaptureSource`,
  `TestScreenCaptureStream`, `TestWindow`.
- İç scheduler: `PlatformScheduler` modül içinde public olsa da crate kökünden
  normal application API olarak export edilen bir yüzey değildir.

Bu tiplerin doğru sahibi `gpui_platform` implementasyonlarıdır. Zed uygulama
katmanında genelde `cx.platform()`, `cx.text_system()`, `cx.svg_renderer()`,
`window.drop_image(...)`, `window.input_latency_snapshot()` veya Bölüm 7'teki
headless/screen capture API'leri üzerinden dolaylı erişilir.

#### Scene, Primitive ve Crate-İçi Arena Taşıyıcıları

`scene.rs`, `arena.rs` ve `taffy.rs` renderer/layout boru hattının alt katmanıdır:

- Scene tarafı dış API'ye re-export edilir: `Scene`, `Primitive`,
  `PrimitiveBatch`, `DrawOrder`, `Quad`, `Underline`, `Shadow`, `PaintSurface`,
  `MonochromeSprite`, `SubpixelSprite`, `PolychromeSprite`, `PathId`,
  `PathVertex<P>`, `PathVertex_ScaledPixels`.
- Layout tarafında `AvailableSpace` ve `LayoutId` crate kökünden public export
  edilir. `TaffyLayoutEngine` ise `taffy` private modülünde `pub struct` olsa da
  `gpui.rs` sadece `use taffy::TaffyLayoutEngine` yaptığı için dış API değildir.
- Arena tarafında `Arena` ve `ArenaBox<T>` `arena` private modülünde `pub`
  tanımlanır ama `gpui.rs` bunları `pub(crate) use arena::*` ile yalnız crate
  içine açar; dış application kodunun API'si değildir.

Uygulama kodu genellikle bu tipleri elle üretmez. `Element` implementasyonları
`window.paint_quad`, `window.paint_image`, `window.paint_path`,
`window.paint_layer` gibi API'ler üzerinden scene'e primitive ekler. Arena
yönetimi `Window::draw` boyunca dahili olarak yapılır; arena'yı açıp kapatan
`ElementArenaScope` da `window.rs` içinde `pub(crate)` olduğu için uygulama kodu
doğrudan kullanmaz, `AnyElement`/`Element` API'leri üzerinden çalışır.

Scene public metot envanteri:

- `Scene`: `clear`, `len`, `push_layer`, `pop_layer`, `insert_primitive`,
  `replay`, `finish`, `batches`.
- `Primitive`: `bounds`, `content_mask`.
- `TransformationMatrix`: `unit`, `translate`, `rotate`, `scale`, `compose`,
  `apply`.
- `Path`: `new`, `scale`, `move_to`, `line_to`, `curve_to`, `push_triangle`,
  `clipped_bounds`.

#### Text System ve Line Layout Taşıyıcıları

`text_system.rs` ve alt modülleri font shaping, wrapping ve glyph rasterization
verilerini public tiplerle taşır:

- Font/glyph kimlikleri: `TextSystem`, `FontId`, `FontFamilyId`, `GlyphId`,
  `FontMetrics`, `RenderGlyphParams`, `GlyphRasterData`.
- Satır shaping: `ShapedLine`, `ShapedRun`, `ShapedGlyph`, `LineLayout`,
  `WrappedLine`, `WrappedLineLayout`, `FontRun`.
- Wrapping: `LineWrapper`, `LineWrapperHandle`, `LineFragment`, `Boundary`,
  `WrapBoundary`, `TruncateFrom`.
- Decoration: `DecorationRun`.

Normal UI kodu bunlara `window.text_system()`, `window.line_height()`,
`window.text_style()`, `StyledText`, `TextLayout` ve `InteractiveText` üzerinden
dokunur. Custom text renderer veya editor-level ölçüm kodunda ham tipler gerekir.

Text public metot envanteri:

- `TextSystem`: `new`, `all_font_names`, `add_fonts`, `get_font_for_id`,
  `resolve_font`, `bounding_box`, `typographic_bounds`, `advance`,
  `layout_width`, `em_width`, `em_advance`, `em_layout_width`, `ch_width`,
  `ch_advance`, `units_per_em`, `cap_height`, `x_height`, `ascent`, `descent`,
  `baseline_offset`, `line_wrapper`.
- `WindowTextSystem`: `new`, `shape_line`, `shape_line_by_hash`, `shape_text`,
  `layout_line`, `try_layout_line_by_hash`, `layout_line_by_hash`.
- `Font`: `bold`, `italic`.
- `FontMetrics`: `ascent`, `descent`, `line_gap`, `underline_position`,
  `underline_thickness`, `cap_height`, `x_height`, `bounding_box`.
- `ShapedLine`: `len`, `width`, `with_len`, `paint`, `paint_background`,
  `split_at`.
- `WrappedLine`: `len`, `paint`, `paint_background`.
- `LineLayout`: `index_for_x`, `closest_index_for_x`, `x_for_index`,
  `font_id_for_index`.
- `WrappedLineLayout`: `len`, `width`, `size`, `ascent`, `descent`,
  `wrap_boundaries`, `font_size`, `runs`, `index_for_position`,
  `closest_index_for_position`, `position_for_index`.
- `LineWrapper`: `wrap_line`, `should_truncate_line`, `truncate_line`.
- `FontFeatures`: `disable_ligatures`, `tag_value_list`, `is_calt_enabled`.
- `FontFallbacks`: `fallback_list`, `from_fonts`.

#### Profiler, Queue ve Global Traitleri

Performans ve queue altyapısındaki public taşıyıcılar:

- Profiler: `TaskTiming`, `ThreadTaskTimings`, `ThreadTimings`,
  `ThreadTimingsDelta`, `GlobalThreadTimings`, `GuardedTaskTimings`,
  `SerializedLocation`, `SerializedTaskTiming`, `SerializedThreadTaskTimings`.
- Priority queue: `SendError<T>`, `RecvError`, `Iter<T>`, `TryIter<T>`.
- Global helper trait'leri: `ReadGlobal`, `UpdateGlobal`.

Profiler tipleri `gpui::profiler` yüzeyinden task/thread zamanlamalarını okumak
ve serialize etmek içindir. Queue hata/iterator tipleri
`PriorityQueueSender`/`PriorityQueueReceiver` kullanıldığında görünür. `ReadGlobal`
ve `UpdateGlobal` trait'leri global state okuma/güncelleme kısayollarını sağlar;
uygulama kodunda çoğu zaman doğrudan `cx.global`, `cx.read_global`,
`cx.update_global` çağrıları yeterlidir.

#### Prompt Renderer Taşıyıcıları

Prompt katmanında iki ek tip vardır:

- `RenderablePromptHandle`: prompt sonucunu custom `RenderOnce` UI ile
  gösterebilen handle.
- `FallbackPromptRenderer`: platform native prompt yoksa GPUI içinde fallback
  prompt render etmek için kullanılan renderer hook'u.

Uygulama tarafında çoğu zaman `cx.prompt(...)`, `cx.prompt_for_path(...)`,
`cx.prompt_for_new_path(...)` ve `PromptBuilder` yeterlidir; custom platform veya
headless prompt davranışı yazarken bu taşıyıcılara inilmelidir.

#### Menu, Keymap, Action ve Test Taşıyıcıları

Doğrudan kullanıcı akışında nadiren görülen public yardımcılar:

- Menu: `SystemMenuType`, `OwnedOsMenu`.
- Keymap: `KeymapVersion`, `BindingIndex`, `KeyBindingMetaIndex`,
  `ContextEntry`.
- Tab sırası: `TabStopOperation` `tab_stop.rs` içinde `pub enum` olsa da modül
  `gpui.rs` tarafından `pub(crate) use tab_stop::*` ile açılır; dış API değildir.
  Focus traversal için dış kod `FocusHandle`, `tab_stop`, `tab_group` ve
  `tab_index` API'lerini kullanır.
- Action registry: `MacroActionBuilder`, `MacroActionData`,
  `generate_list_of_all_registered_actions()`.
- Test: `TestAppWindow<V>` ve macOS `test-support` için `VisualTestAppContext`.
- App internals: `AppCell`, `AppRef`, `AppRefMut`, `ArenaClearNeeded`,
  `KeystrokeEvent`, `AnyDrag`, `LeakDetectorSnapshot`.

`generate_list_of_all_registered_actions()` action registry'yi dokümantasyon,
komut paleti veya test doğrulaması için tarar. `AppCell`/`AppRef`/`AppRefMut`
normal uygulama kodunun sahiplenmesi gereken tipler değildir; `App`, `Context<T>`
ve async context'ler üzerinden çalışmak doğru sınırdır.

#### Küçük Public Fonksiyonlar

- `guess_compositor()`: Linux/Wayland/X11 compositor adını tahmin eder; Bölüm 5'deki
  `cx.compositor_name()` akışının düşük seviye yardımcısıdır.
- `get_gamma_correction_ratios(gamma)`: atlas/glyph rendering gamma düzeltme
  oranlarını üretir; tema rengi seçmek için kullanılmaz.
- `LinearColorStop`: gradient stop verisidir; `linear_gradient(...)` helper'ları
  bunu üretir.
- `combine_highlights(...)`: text highlight katmanlarını birleştirir; editor/text
  rendering hattında kullanılır.
- `hash(data)`: asset cache key üretimi için helper'dır.
- `percentage(value)`: `Percentage` constructor helper'ıdır.
- `scap_screen_sources(...)`: screen capture kaynaklarını platforma göre toplar;
  uygulama kodunda çoğu zaman `cx.screen_capture_sources(...)` tercih edilir.

#### Constants ve Type Aliases

`target/doc/gpui/all.html` altında ayrı listelenen sabitler:

- `DEFAULT_WINDOW_SIZE = 1536x1095`: `WindowOptions.window_bounds` verilmezse
  default placement için kullanılan ana pencere boyutu.
- `DEFAULT_ADDITIONAL_WINDOW_SIZE = 900x750`: settings/rules library gibi ek
  işlevsel pencereler için önerilen minimum oranlı boyut.
- `KEYSTROKE_PARSE_EXPECTED_MESSAGE`: `InvalidKeystrokeError` mesajının
  "beklenen modifier + key" açıklaması.
- `LOADING_DELAY = 200ms`: `img()` elementinin loading state'i göstermeden önce
  beklediği süre.
- `MAX_BUTTONS_PER_SIDE = 3`: `WindowButtonLayout` içinde bir tarafta tutulabilen
  native control button slot sayısı.
- `SHUTDOWN_TIMEOUT = 100ms`: `Context::on_app_quit` future'larının app quit
  sırasında çalışabileceği süre.
- `SMOOTH_SVG_SCALE_FACTOR = 2.0`: SVG'leri daha yumuşak raster etmek için
  kullanılan yüksek çözünürlük scale'i.
- `SUBPIXEL_VARIANTS_X = 4`, `SUBPIXEL_VARIANTS_Y = 1`: glyph atlas subpixel
  rasterization varyant sayıları.

Type alias'lar:

- `AlignSelf = AlignItems`, `JustifyItems = AlignItems`,
  `JustifySelf = AlignItems`, `JustifyContent = AlignContent`: style enum
  alias'ları.
- `DrawOrder = u32`: scene layer/primitive sıralama anahtarı.
- `ImageLoadingTask = Shared<Task<Result<Arc<RenderImage>, ImageCacheError>>>`:
  image cache loader task tipi.
- `ImgResourceLoader = AssetLogger<ImageAssetLoader>`: `img()` elementinin asset
  loader alias'ı.
- `InspectorRenderer = Box<dyn Fn(&mut Inspector, &mut Window,
  &mut Context<Inspector>) -> AnyElement>`: `App::set_inspector_renderer(...)`
  ile kurulan inspector UI renderer callback'i.
- `PathVertex_ScaledPixels = PathVertex<ScaledPixels>`: scene path vertex alias'ı.
- `Result = anyhow::Result`: crate kök hata alias'ı.
- `Transform = lyon::math::Transform`: path builder transform alias'ı.

Renk/geometri kısa fonksiyonları:

- Renk: `rgb(0xRRGGBB)`, `rgba(0xRRGGBBAA)`, `hsla(h, s, l, a)`,
  `black()`, `white()`, `red()`, `green()`, `blue()`, `yellow()`,
  `transparent_black()`, `transparent_white()`, `opaque_grey(l, a)`.
- Background: `solid_background(color)`, `linear_color_stop(color, percentage)`,
  `linear_gradient(angle, from, to)`, `pattern_slash(color, width, interval)`,
  `checkerboard(color, size)`.
- Geometri: `point(x, y)`, `size(width, height)`, `px(f32)`, `rems(f32)`,
  `relative(f32)`, `percentage(f32)`, `radians(f32)`, `auto()`, `phi()`.

#### Kök Re-export ve Makro Yüzeyi

`gpui.rs` crate kökünde yalnız GPUI modüllerini değil, bazı yardımcı crate'leri de
yeniden export eder:

- `Result`: `anyhow::Result` alias'ıdır; GPUI API'leriyle aynı hata tipini
  kullanmak için tercih edilir.
- `ArcCow`: `gpui_util::arc_cow::ArcCow`; clone maliyeti düşük copy-on-write
  paylaşımlı veri taşımak içindir.
- `FutureExt` ve `Timeout`: `future.with_timeout(duration, executor)` zincirinin
  trait ve hata tipidir. Zincirin döndürdüğü future wrapper tipi
  `WithTimeout<T>`'dir.
- `block_on`: `pollster::block_on`; sync köprü gerektiğinde foreground olmayan
  küçük future'lar için kullanılır.
- `ctor`: inventory/action registration gibi startup registration desenleri için
  yeniden export edilir.
- `http_client`: GPUI platform HTTP client trait'lerine crate kökünden erişim
  sağlar.
- `proptest`: yalnız `test-support`/test build'lerinde property test yardımcılarını
  export eder.
- Makrolar: `Action`, `IntoElement`, `AppContext`, `VisualContext`,
  `register_action`, `test`, `property_test`. `gpui.rs` ayrıca `Render`
  derive'ını da re-export eder, fakat makro kaynağında `#[doc(hidden)]`
  olduğu için `target/doc/gpui/all.html` içinde listelenmez ve
  `derive.Render.html` sayfası üretilmez. Bu derive yalnız boş bir
  `Render` impl'i üretir; `render` gövdesi `gpui::Empty` döndürür. Gerçek UI
  üreten view'lerde manuel `impl Render` yazılır.

Rustdoc listesindeki `Action`, `IntoElement`, `Refineable`, `AppContext` ve
`VisualContext` kısa adları tek bir öğe değildir; trait ve derive macro
yüzeyleri ayrı namespace'lerde yaşar. `#[derive(AppContext)]` struct içinde
`#[app]` ile işaretlenmiş `&mut App` alanını bulur ve `AppContext` metodlarını
o alana delege eder. `#[derive(VisualContext)]` hem `#[app]` hem `#[window]`
ister; `VisualContext` için `type Result<T> = T` üretir, `window_handle`,
`update_window_entity`, `new_window_entity`, `replace_root_view` ve `focus`
çağrılarını ilgili `App`/`Window` alanlarına indirir. `prelude::IntoElement`,
`prelude::Refineable` ve `prelude::VisualContext` rustdoc'ta görünen derive
macro alias'larıdır; yeni trait veya farklı runtime davranışı değildir.

Bu re-export'lar yeni API anlamına gelmez; modüllerde anlatılan aynı yüzeyin
crate kökünden ergonomik erişimidir. Özellikle `property_test` ve `proptest`
yalnız test kodunda, `ctor` ise registration altyapısı gibi dar alanlarda
kullanılmalıdır.

Test helper fonksiyonları `gpui::test` modülünde tutulur: `seed_strategy()`,
`apply_seed_to_proptest_config(...)`, `run_test_once(...)`, `run_test(...)` ve
`Observation<T>`. Bunlar `#[gpui::test]` ve `#[gpui::property_test]` makrolarının
altyapısıdır; normal app kodu çağırmaz.

Profiler helper'ları `add_task_timing(...)` ve
`get_current_thread_task_timings()` thread-local task timing toplama için
kullanılır. Text fallback helper'ları `font_name_with_fallbacks(...)` ve
`font_name_with_fallbacks_shared(...)` platform font ailesi fallback adını
döndürür. `swap_rgba_pa_to_bgra(...)` premultiplied RGBA byte buffer'ını platform
BGRA düzenine çevirmek için renk/bitmap alt katmanında kullanılır.

---

## Bölüm XVII — Zed UI Bileşenleri

---

### 82. Zed UI Prelude, Style Extension Trait'leri ve Component Sözleşmesi

Zed uygulama kodu çoğu zaman doğrudan `gpui::prelude::*` değil
`ui::prelude::*` import eder. Bu prelude GPUI çekirdeğini yeniden export eder ve
Zed'e özgü component/style katmanını ekler.

`ui::prelude::*` içinde önemli export'lar:

- `gpui::prelude::*` üzerinden gelen trait/tipler: `AppContext` (anonim),
  `BorrowAppContext`, `Context`, `Element`, `InteractiveElement`, `IntoElement`,
  `ParentElement`, `Refineable`, `Render`, `RenderOnce`, `StatefulInteractiveElement`,
  `Styled`, `StyledImage`, `TaskExt` (anonim), `VisualContext`, `FluentBuilder`.
- `gpui` doğrudan tipleri: `App`, `Window`, `Div`, `AnyElement`, `ElementId`,
  `SharedString`, `Pixels`, `Rems`, `AbsoluteLength`, `DefiniteLength`,
  `div`, `px`, `rems`, `relative`.
- Zed layout helper'ları: `h_flex()`, `v_flex()`, `h_group()`, `h_group_sm()`,
  `h_group_lg()`, `h_group_xl()`, `v_group()`, `v_group_sm()`, `v_group_lg()`,
  `v_group_xl()`.
- Theme erişimi: `theme::ActiveTheme`, `Color`, `PlatformStyle`, `Severity`.
- Stil/spacing yardımcıları: `StyledTypography`, `TextSize`, `DynamicSpacing`,
  `rems_from_px`, `vh`, `vw`.
- Animasyon: `AnimationDirection`, `AnimationDuration`, `DefaultAnimations`.
- Component sistemi: `Component`, `ComponentScope`, `RegisterComponent`,
  `example_group`, `example_group_with_title`, `single_example`.
- Component'ler: `Button`, `ButtonCommon`, `ButtonSize`, `ButtonStyle`,
  `IconButton`, `SelectableButton`, `Headline`, `HeadlineSize`, `Icon`,
  `IconName`, `IconPosition`, `IconSize`, `Label`, `LabelCommon`, `LabelSize`,
  `LineHeightStyle`, `LoadingLabel`.
- Trait'ler (`crate::traits::*`): `StyledExt`, `Clickable`, `Disableable`,
  `Toggleable`, `VisibleOnHover`, `FixedWidth`.

`ButtonLike` prelude'da değildir; `ui::ButtonLike` yoluyla doğrudan import edilir.
Yine prelude'da olmayanlar (örn. `Tooltip`, `ContextMenu`, `Popover`,
`PopoverMenu`, `Modal`, `RightClickMenu`) doğrudan `ui::` namespace'inden
çağrılır.

`CommonAnimationExt` de crate kökünden (`ui::CommonAnimationExt`) explicit
import edilir; `with_rotate_animation(duration_secs)` ve
`with_keyed_rotate_animation(id, duration_secs)` sağlar.

Animasyon yüzeyi:

- `AnimationDuration::{Instant, Fast, Slow}` sırasıyla 50/150/300 ms döner;
  `.duration()` veya `Into<Duration>` ile GPUI animation'a verilir.
- `AnimationDirection::{FromBottom, FromLeft, FromRight, FromTop}` giriş
  animasyon yönüdür.
- `DefaultAnimations`: `.animate_in(direction, fade)`,
  `.animate_in_from_bottom(fade)`, `.animate_in_from_left(fade)`,
  `.animate_in_from_right(fade)`, `.animate_in_from_top(fade)`.
  Blanket impl `Styled + Element` olan elementler içindir.
- `CommonAnimationExt` rotasyon helper'ı yalnız `Transformable` implement eden
  elementlerde çalışır; Zed UI tarafında bu pratikte `Icon` ve `Vector`
  demektir.

Public export modeli:

- `crates/ui/src/ui.rs` iç modülleri (`components`, `styles`, `traits`) private
  tutar ve `pub use components::*`, `pub use prelude::*`,
  `pub use styles::*`, `pub use traits::animation_ext::*` ile public yüzeyi
  düzleştirir. Bu yüzden tüketici kodunda `ui::Button`, `ui::Color`,
  `ui::Clickable`, `ui::theme_is_transparent` gibi yollar kullanılır;
  `ui::components::...` veya `ui::styles::...` public API yolu değildir.
- Bilinçli public nested modüller (`pub mod`) kendi namespace'iyle kullanılır:
  - `ui::scrollbars::{ShowScrollbar, ScrollbarVisibility, ScrollbarAutoHide}` —
    scrollbar görünürlük settings yüzeyi.
  - `ui::animation::{AnimationDirection, AnimationDuration, DefaultAnimations}`
    — prelude'da da olan animasyon helper modülü; `workspace::toast_layer`
    gibi kodlar explicit `ui::animation::DefaultAnimations` import edebilir.
  - `ui::table_row::{TableRow, IntoTableRow}` — `data_table.rs` içinden public
    açılan kolon sayısı doğrulamalı tablo satırı modülü.
  - `ui::utils::*` — non-styling yardımcılar (aşağıdaki utils başlığı).
  - `ui::component_prelude::*` — component yazarken kullanılan derive ve
    registry yüzeyi: `Component`, `ComponentId`, `ComponentScope`,
    `ComponentStatus`, `example_group`, `example_group_with_title`,
    `single_example`, `RegisterComponent` (ui_macros), `Documented`
    (documented crate). Yeni component yazarken `use ui::component_prelude::*;`
    `ui::prelude::*`'a ek olarak import edilir.
- `ui::prelude::*` sık kullanılan küçük yüzeydir; tüm component envanteri
  değildir. `ButtonLike`, `ContextMenu`, `Tooltip`, `Modal`, `Table`,
  `Vector`, `ThreadItem` gibi tipler crate kökünden explicit import edilir.

Style extension'ları:

- `StyledExt::h_flex()` = `flex().flex_row().items_center()`.
- `StyledExt::v_flex()` = `flex().flex_col()`.
- `elevation_1/2/3(cx)` ve `*_borderless(cx)` Zed elevation katmanlarını uygular:
  `Surface`, `ElevatedSurface`, `ModalSurface`. Popover/modal gibi katmanlarda
  elle shadow/border üretmek yerine bunları kullan. **Reference asimetrisi:**
  `elevation_1(cx)`, `elevation_2(cx)`, `elevation_3(cx)` `&App` alır;
  `elevation_1_borderless(cx)`, `elevation_2_borderless(cx)`,
  `elevation_3_borderless(cx)`, `border_primary(cx)` ve `border_muted(cx)`
  `&mut App` ister. Read-only render path'inde borderless varyantı
  çağrılamaz; mut access verir veya borderless yerine bordered varyantı seç.
- `debug_bg_red/green/blue/yellow/cyan/magenta()` yalnızca geliştirme sırasında
  layout teşhisi içindir.

Tipografi:

- `StyledTypography::font_ui(cx)` ve `font_buffer(cx)` theme settings'teki UI ve
  buffer font family değerlerini bağlar.
- `text_ui_size(TextSize, cx)` enum'dan semantic text size uygular.
- `text_ui_lg(cx)`, `text_ui(cx)`, `text_ui_sm(cx)`, `text_ui_xs(cx)` UI scale'i
  dikkate alan semantic metin boyutlarıdır.
- `text_buffer(cx)` buffer font size'a uyar; editor içeriğiyle aynı boyda
  görünmesi gereken metinde kullanılır.
- `TextSize::{Large, Default, Small, XSmall, Ui, Editor}` hem `.rems(cx)` hem
  `.pixels(cx)` verir. Hardcoded `px(14.)` yerine semantic boyut tercih edilir.

Semantic renk ve elevation:

- `Color` theme'e göre HSLA'ya çevrilen semantic enum'dur
  (`crates/ui/src/styles/color.rs`). Variantlar:
  `Default`, `Accent`, `Conflict`, `Created`, `Custom(Hsla)`, `Debugger`,
  `Deleted`, `Disabled`, `Error`, `Hidden`, `Hint`, `Ignored`, `Info`,
  `Modified`, `Muted`, `Placeholder`, `Player(u32)`, `Selected`, `Success`,
  `VersionControlAdded`, `VersionControlConflict`, `VersionControlDeleted`,
  `VersionControlIgnored`, `VersionControlModified`, `Warning`. Üretim/diff
  rengi için git/VCS varyantlarını, oyuncu vurgusu için `Player(u32)`'yi,
  highlight için `Selected`/`Hint`'i tercih et — bunlar `cx.theme().status()`
  veya player palette üzerinden HSLA'ya çözülür.
- `TintColor::{Accent, Error, Warning, Success}` button tint stillerine kaynaklık
  eder ve `Color`'a dönüştürülebilir.
- `Severity::{Info, Success, Warning, Error}` `Banner`/`Callout` gibi feedback
  bileşenlerinin semantic durumudur; `TintColor` veya `Color` yerine component
  severity sözleşmesi istediğinde bunu kullan.
- `PlatformStyle::{Mac, Linux, Windows}` ve `PlatformStyle::platform()` platforma
  göre UI ayrımı gereken bileşenlerde küçük branching yüzeyidir.
- `ElevationIndex::{Background, Surface, EditorSurface, ElevatedSurface,
  ModalSurface}` shadow, background ve "bu elevation üzerinde okunacak renk"
  kararlarını toplar.
  Public helper'ları (receiver/mut asimetrisi var):
  - `.shadow(self, cx: &App) -> Vec<BoxShadow>` — `self`'i tüketir; tipik
    olarak `match`/clone sonrası kullanılır.
  - `.bg(&self, cx: &mut App) -> Hsla` — `&mut App` ister (yalnız bu).
  - `.on_elevation_bg(&self, cx: &App) -> Hsla`,
    `.darker_bg(&self, cx: &App) -> Hsla` — `&App` yeterli.

Button/label ortak sözleşmeleri:

- `Clickable`: `.on_click(...)` ve `.cursor_style(...)`.
- `Disableable`: `.disabled(bool)`.
- `Toggleable`: `.toggle_state(bool)`; `ToggleState::{Unselected,
  Indeterminate, Selected}` üç durumlu checkbox/tree selection için.
  `ToggleState` ayrıca `.inverse()`, `.selected()` ve
  `from_any_and_all(any_checked, all_checked)` yardımcılarını sağlar.
- `SelectableButton`: selected durumda farklı `ButtonStyle` tanımlar.
- `ButtonCommon`: `.id()` accessor'ı ve `.style(ButtonStyle)`,
  `.size(ButtonSize)`, `.tooltip(...)`, `.tab_index(...)`,
  `.layer(ElevationIndex)`, `.track_focus(...)`.
- `ButtonStyle::{Filled, Tinted(TintColor), Outlined, OutlinedGhost,
  OutlinedCustom(Hsla), Subtle, Transparent}`.
- `ButtonSize::{Large, Medium, Default, Compact, None}`.
- `LabelCommon`: `.size(LabelSize)`, `.weight(FontWeight)`,
  `.line_height_style(LineHeightStyle::{TextLabel, UiLabel})` — `TextLabel`
  default (UI/buffer default line-height), `UiLabel` line-height'i 1.0'a sabitler,
  `.color(Color)`, `.strikethrough()`, `.italic()`, `.underline()`,
  `.alpha(f32)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.
- `LabelLike` (underlying primitive struct) ayrıca inherent
  `.truncate_start()` taşır — `LabelCommon` trait'inde yer almaz; başlangıçtan
  ellipsis ile kesmek için `LabelLike` veya `Label` üzerinde doğrudan çağrılır.
- `FixedWidth`: `.width(DefiniteLength)` ve `.full_width()`; mevcut UI
  katmanında `Button`, `IconButton` ve `ButtonLike` üzerinde implement edilir.

Diğer UI yardımcıları:

- `VisibleOnHover::visible_on_hover(group)` elementi başlangıçta invisible yapar,
  belirtilen group hover olduğunda visible'a çevirir. `""` global group'tur.
- `WithRemSize::new(px(...))` child ağacında `window.with_rem_size` uygular;
  özel preview veya küçük component ölçeklemesi için kullanılır;
  `.occlude()` mouse etkileşimini kapatır.
- `ui::utils` public nested namespace olarak kalır. Sık kullanılan export'lar:
  `is_light(cx)`, `reveal_in_file_manager_label(is_remote)`, `capitalize(str)`,
  `SearchInputWidth::calc_width(container_width)`,
  `platform_title_bar_height(&Window)`,
  `calculate_contrast_ratio(fg, bg)`, `apca_contrast(text, bg)`,
  `ensure_minimum_contrast(...)`, `CornerSolver::new(root_radius, root_border,
  root_padding)`, `inner_corner_radius(...)`,
  `FormatDistance::{new(date, base_date), from_now(date), include_seconds(bool),
  add_suffix(bool), hide_prefix(bool)}`, `format_distance(...)`,
  `format_distance_from_now(...)`, `DateTimeType::{Naive(NaiveDateTime),
  Local(DateTime<Local>)}`.
- `BASE_REM_SIZE_IN_PX` `ui::utils` altında değil, `styles/units.rs` üzerinden
  crate köküne gelen `ui::BASE_REM_SIZE_IN_PX` sabitidir; `rems_from_px(...)`,
  `vh(...)`, `vw(...)` ile aynı units yüzeyindedir.
- `ui::ui_density(cx: &mut App) -> UiDensity` styles modülünden gelen
  ergonomik helper'dır; `theme::theme_settings(cx).ui_density(cx)` kısayolu.
  Spacing kararları için `DynamicSpacing` enum'unu tercih et, density'yi
  yalnızca styling dışı kararlar (örn. icon size, compact toggle) için kullan.
- Keybinding görünümü için crate kökünde public free fonksiyonlar:
  - `text_for_action(action: &dyn Action, window, cx) -> Option<String>`
  - `text_for_keystrokes(keystrokes: &[Keystroke], cx) -> String`
  - `text_for_keystroke(modifiers: &Modifiers, key: &str, cx) -> String`
  - `text_for_keybinding_keystrokes(keystrokes: &[KeybindingKeystroke], cx) -> String`
  - `render_keybinding_keystroke(...)`, `render_modifiers(...)`: element üretir.
  Bu yardımcılar tooltip/menu metni üretirken `KeyBinding` veya `KeybindingHint`
  bileşeninden ayrı düşünülmelidir; bileşen render eder, free fn metin üretir.
- `Transformable` trait crate dışına public değildir (`traits` modülü private);
  yalnız `Icon` ve `Vector` implement eder. Bu yüzden `CommonAnimationExt`
  üzerindeki `with_rotate_animation`/`with_keyed_rotate_animation` zinciri
  yalnız bu iki tip üzerinde derlenir. Üçüncü taraf bir element için döndürme
  istiyorsan ya `Icon`/`Vector` sar ya da kendi `with_animation` zincirini kur.
- Scrollbar katmanı **iki ayrı API yüzeyi** sunar; doğru olanı seç:
  - Düşük seviye: `Scrollbars::new(ScrollAxes)` builder zinciri —
    `.tracked_scroll_handle(handle)`, `.id(...)`, `.notify_content()`,
    `.style(ScrollbarStyle)`, `.with_track_along(...)` vb. — sonra
    `div().custom_scrollbars(config, window, cx)` ile uygulanır.
    `custom_scrollbars` ve `vertical_scrollbar_for` yalnızca
    `WithScrollbar` trait üzerindedir; `WithScrollbar`
    `Div` ve `Stateful<Div>` için implement edilir.
  - Kısayol: `div().vertical_scrollbar_for(&scroll_handle, window, cx)` —
    `WithScrollbar::vertical_scrollbar_for` default impl'i kendi içinde
    `Scrollbars::new(ScrollAxes::Vertical).tracked_scroll_handle(handle)`
    kurar. **`Scrollbars` üzerinde inherent `.vertical_scrollbar_for(...)`
    yoktur**; zincir parent element üzerinde başlar.
  - Görünürlük ayarı crate kökünde değil
    `ui::scrollbars::{ShowScrollbar, ScrollbarVisibility, ScrollbarAutoHide}`
    namespace'i altındadır; `ScrollbarVisibility` settings trait'i,
    `ScrollbarAutoHide` ise auto-hide durumunu taşıyan `Global` tipidir.
  - Enum yüzeyi: `ScrollAxes::{Horizontal, Vertical, Both}` (Scrollbars'a
    verilen üç-değerli eksen seçimi) ve `ScrollbarStyle::{Regular, Editor}`.
    Özel scroll handle yazıyorsan `ScrollableHandle: 'static + Any + Sized
    + Clone` trait'i `max_offset(&self) -> Point<Pixels>`,
    `set_offset(&self, Point<Pixels>)`, `offset(&self) -> Point<Pixels>`,
    `viewport(&self) -> Bounds<Pixels>`, default impl'li
    `drag_started(&self)`/`drag_ended(&self)`,
    `scrollable_along(&self, ScrollbarAxis) -> bool` ve
    `content_size(&self) -> Size<Pixels>` sözleşmesini taşır.
    **`ScrollbarAxis` ≠ `ScrollAxes`.** `ScrollbarAxis` scrollbar.rs
    içinde `gpui::Axis as ScrollbarAxis` aliasıdır; iki variantı
    (`Horizontal`, `Vertical`) vardır ve scrollable handle'ın tek eksen
    sorgusu için kullanılır. `ScrollAxes` (Horizontal/Vertical/Both)
    `Scrollbars::new(...)` yapılandırma yüzeyidir.
  - `on_new_scrollbars<T: gpui::Global>(cx)` bir global ayarı
    `ScrollbarState::settings_changed` observer'ına bağlamak için düşük seviye
    helper'dır; normal component render'ında çağrılan bir builder değildir.

Tuzaklar:

- Uygulama UI'ında doğrudan `cx.theme().colors().text_*` yazmak mümkün olsa da
  reusable component için `Color`/`TintColor` semantic katmanı daha dayanıklıdır.
- `ButtonLike` güçlü ama unconstrained bir primitive'dir; hazır `Button`,
  `IconButton`, `ToggleButtonGroup`, `ToggleButtonSimple` veya
  `ToggleButtonWithIcon` yeterliyse onları kullan. `ToggleButton` adında
  bağımsız bir public tip yoktur.
- `VisibleOnHover` için parent'ta aynı group adıyla hover group kurulmadıysa
  element hiçbir zaman görünmez.
- Public görünen bazı state structs kullanıcı-facing builder değildir:
  `PopoverMenuElementState`, `PopoverMenuFrameState`, `MenuHandleElementState`,
  `RequestLayoutState`, `PrepaintState`, `ScrollbarPrepaintState`. Bunlar
  `Element` associated state tipleri olarak public kalmıştır; doğrudan
  oluşturup component API'si gibi kullanma.

Zed uygulamasında yönetim:

- Component registry çalışma zamanı render path'i değildir; app kodu bileşenleri
  doğrudan `ui::{...}` veya `ui::prelude::*` ile import edip element ağacına
  koyar.
- `workspace::init` içinde `component::init()` çağrılır. Bu çağrı
  `#[derive(RegisterComponent)]` tarafından inventory'ye eklenen
  `ComponentFn` kayıtlarını çalıştırır ve `ComponentRegistry`'yi doldurur.
- `zed/src/main.rs` `component_preview::init(app_state, cx)` çağırır.
  Component preview, `component::components().sorted_components()` ile
  registry'yi okur; isim, scope ve description üzerinden filtreler.
- `Component` trait public sözleşmesi: `id()`, `scope()`, `status()`,
  `name()`, `sort_name()`, `description()` ve
  `preview(&mut Window, &mut App) -> Option<AnyElement>`. Bu sözleşme
  görsel test/debug/dokümantasyon içindir; normal UI kullanımında component
  registry lookup yapılmaz.

### 83. Zed UI Bileşen Envanteri

Zed'de yeni UI yazarken önce `ui` bileşenlerini ara. Başlıca bileşenler:

- Metin: `Label`, `LabelLike` (underlying primitive), `Headline`,
  `HighlightedLabel` ve `highlight_ranges(...)` free fn yardımcısı,
  `LoadingLabel`, `SpinnerLabel` (`SpinnerVariant::{Dots (default),
  DotsVariant, Sand}`). `SpinnerLabel` constructorları: `new()` default
  Dots, `with_variant(SpinnerVariant)` ve doğrudan kısayollar `dots()`,
  `dots_variant()`, `sand()`. `SpinnerLabel` ayrıca `LabelCommon` implement
  ettiği için `.size/.color/.weight/...` zinciri kullanılabilir.
- Buton: `Button` (`KeybindingPosition::{Start, End}` ile
  `.key_binding_position(...)`), `IconButton`
  (`IconButtonShape::{Square, Wide}`), `SelectableButton`, `ButtonLike`
  (`ButtonBuilder`/`ButtonConfiguration` sealed yardımcılar), `ButtonLink`,
  `CopyButton`, `SplitButton`
  (`SplitButtonStyle::{Filled, Outlined, Transparent}`,
  `SplitButtonKind::{ButtonLike(ButtonLike), IconButton(IconButton)}` —
  segment olarak hem button-like hem icon button kabul eder),
  `ToggleButtonGroup` (`ToggleButtonGroupStyle::{Transparent, Filled,
  Outlined}`, `ToggleButtonGroupSize::{Default, Medium, Large, Custom(Rems)}`,
  `ToggleButtonPosition`) ve giriş tipleri `ToggleButtonSimple`,
  `ToggleButtonWithIcon`. `ToggleButton` adında bağımsız bir struct yoktur;
  tekil toggle yerine her zaman grup içinde segment kullanılır.
- İkon: `Icon`, `DecoratedIcon`, `IconDecoration`,
  `IconDecorationKind::{X, Dot, Triangle}`, `IconName`,
  `IconPosition::{Start, End}` (button içinde label-icon sırası),
  `IconSize`, `IconWithIndicator`, `KnockoutIconName::{XFg, XBg, DotFg, DotBg,
  TriangleFg, TriangleBg}` (IconDecoration için eşli fg/bg svg adları),
  `AnyIcon::{Icon(Icon), AnimatedIcon(AnimationElement<Icon>)}` (type-erased
  ikon: hem statik hem animasyonlu varyantı tek tipte taşır). `IconName`
  `crates/icons` crate'inde tanımlanır, `ui::prelude` üzerinden re-export
  edilir. `IconSize` varyantları: `Indicator`, `XSmall`, `Small`, `Medium`,
  `XLarge`, `Custom(Rems)`; `.rems()`, `.square_components(window, cx)`,
  `.square(window, cx)` verir.
- Form/toggle: `Checkbox`, `Switch` (`SwitchColor::{Accent, Custom(Hsla)}`,
  `SwitchLabelPosition::{Start, End}`), `SwitchField`, `DropdownMenu`
  (`DropdownStyle::{Solid, Outlined, Subtle, Ghost}`), `ToggleStyle::{Ghost,
  ElevationBased(ElevationIndex), Custom(Hsla)}`.
  Lowercase yardımcı fonksiyonlar `checkbox(id, state)` ve
  `switch(id, state)` constructor kısayollarıdır.
- Metin girişi: `ui_input::InputField` ayrı crate'tedir; `ui` re-export etmez.
  `InputField::new(window, cx, placeholder)` editor factory gerektirir ve
  `.label`, `.start_icon`, `.masked`, `.tab_index`, `.text`, `.set_text`,
  `.clear` gibi form alanı API'sini sağlar.
- Menü/popup: `ContextMenu`, `ContextMenuEntry`,
  `ContextMenuItem::{Separator, Header(SharedString), HeaderWithLink(title,
  link_label, link_url), Label(SharedString), Entry(ContextMenuEntry),
  CustomEntry { entry_render, handler, selectable, documentation_aside },
  Submenu { label, icon, icon_color, builder }}` — `ContextMenu` builder'ına
  doğrudan eklenen yedi tip menü satırı,
  `DocumentationAside { side: DocumentationSide, render: Rc<...> }`,
  `DocumentationSide::{Left, Right}`,
  `RightClickMenu<M: ManagedView>` ve free fn `right_click_menu(id)`,
  `Popover`, `PopoverMenu<M: ManagedView>`, `PopoverMenuHandle<M>`,
  `PopoverTrigger`, `Tooltip`, `LinkPreview` ve free fn
  `tooltip_container(cx, f)`.
- Liste/tree: `List` (`EmptyMessage::{Text(SharedString), Element(AnyElement)}`),
  `ListItem` (`ListItemSpacing::{Dense, ExtraDense, Sparse}`),
  `ListHeader`, `ListSubHeader`, `ListSeparator` (`pub struct ListSeparator;` —
  unit struct, builder yok), `ListBulletItem`, `TreeViewItem`,
  `StickyCandidate` (`depth(&self) -> usize`), `StickyItems<T>` ve free fn
  constructor `sticky_items<V, T>(...)`, `StickyItemsDecoration`
  (`compute(indents, bounds, scroll_offset, item_height, window, cx)`),
  `IndentGuides` (`IndentGuideColors`, `IndentGuideLayout`,
  `RenderIndentGuideParams`, `RenderedIndentGuide`) ile free fn constructor
  `indent_guides(indent_size: Pixels, colors: IndentGuideColors)`.
- Tab: `Tab`, `TabBar`, `TabPosition::{First, Middle(Ordering), Last}`,
  `TabCloseSide::{Start, End}`
- Layout yardımcıları: `h_flex()`, `v_flex()`, `h_group*()`, `v_group*()`,
  `Divider` (`DividerColor::{Border, BorderFaded, BorderVariant}`),
  `divider()` ve `vertical_divider()` free fn constructorları, `Scrollbars`.
  `Stack` ve `Group` adında public struct yoktur; bunlar helper fonksiyon
  ailesidir.
- Veri: `Table`, `TableInteractionState`,
  `ColumnWidthConfig::{Static { widths, table_width }, Redistributable {
  columns_state, table_width }, Resizable(Entity<ResizableColumnsState>)}` —
  bu üçlü tablo kolon modunu belirler: `Static` resize handle vermez,
  `Redistributable` toplam tablo genişliğini sabit tutarak komşuya devreder,
  `Resizable` her kolonu bağımsız büyütür ve toplam genişlik değişir.
  `StaticColumnWidths::{Auto, Explicit(TableRow<DefiniteLength>)}` Static
  modun alt seçimidir. `ResizableColumnsState`, `RedistributableColumnsState`,
  `HeaderResizeInfo`, `TableResizeBehavior::{None, Resizable, MinSize(f32)}`,
  `TableRow<T>` (`pub struct TableRow<T>(Vec<T>)` — kolon sayısı doğrulanmış
  satır), `UncheckedTableRow<T>` (`pub type UncheckedTableRow<T> = Vec<T>` —
  doğrulamasız satır; struct değil tip alias'ıdır), `TableRenderContext`,
  `IntoTableRow` trait, `render_table_row`, `render_table_header`,
  `bind_redistributable_columns()` ve
  `render_redistributable_columns_resize_handles()`.
- Feedback: `Banner`, `Callout` (`BorderPosition::{Top, Bottom}`),
  `Modal`, `ModalHeader`, `ModalFooter`, `ModalRow`, `Section`,
  `SectionHeader`, `AlertModal`,
  `AnnouncementToast`, `CountBadge`, `Indicator`, `ProgressBar`,
  `CircularProgress`. `ui::Notification` standalone component değildir;
  workspace bildirim sistemi ayrı `workspace::notifications` trait'leriyle
  yönetilir.
- Diğer: `Avatar`, `AvatarAudioStatusIndicator` (`AudioStatus::{Muted,
  Deafened}` enum'u ile), `AvatarAvailabilityIndicator`
  (`CollaboratorAvailability` enum'u ile), `Facepile`, `Chip`, `DiffStat`,
  `Disclosure`, `GradientFade`, `Vector`, `VectorName`, `KeyBinding`,
  `KeybindingHint`, `Key`, `KeyIcon` (keybinding sub-primitives —
  `text_for_keystroke`/`render_modifiers` free fn'leri ile kullanılır),
  `Navigable` ve `NavigableEntry`. `Image` adında public Zed UI
  component'i yoktur; raster görsel için GPUI `img(...)` / `ImageSource`,
  bundled SVG için `Vector` kullanılır.
- AI/collab özel: `AiSettingItem` (`AiSettingItemStatus`,
  `AiSettingItemSource`), `AgentSetupButton`, `ConfiguredApiCard`,
  `ParallelAgentsIllustration`, `ThreadItem` (`AgentThreadStatus`,
  `WorktreeKind`, `ThreadItemWorktreeInfo`), `CollabNotification`,
  `UpdateButton`

Genel kural:

- Zed içinde ham `div().on_click(...)` ile buton üretmeden önce `Button` veya
  `IconButton` kullan.
- Sadece görsel/tek seferlik parça için `RenderOnce`, stateful view için `Render`.
- Listeler çok büyükse `list` veya `uniform_list` kullan.
- Tooltip, popover ve context menu için hazır bileşenleri kullan; focus/blur
  kapanma davranışı orada çözülmüş durumdadır.

### 84. ManagedView, DismissEvent, Modal, Popover ve Tooltip Yaşam Döngüsü

`ManagedView` GPUI'da başka bir view tarafından yaşam döngüsü yönetilen UI
parçaları için blanket trait'tir:

```rust
pub trait ManagedView: Focusable + EventEmitter<DismissEvent> + Render {}
```

Bir modal, popover veya context menu kapatılmak istediğinde kendi entity
context'inden `DismissEvent` yayar:

```rust
impl EventEmitter<DismissEvent> for MyModal {}

fn dismiss(&mut self, cx: &mut Context<Self>) {
    cx.emit(DismissEvent);
}
```

Zed/UI bileşenleri:

- `ContextMenu`: `ManagedView` uygular; command listesi ve separator yönetimi
  için kullanılır.
- `PopoverMenu<M: ManagedView>`: anchor element'ten focus edilebilir popover
  açar; `PopoverMenuHandle<M>` dışarıdan toggle/close için tutulabilir.
- `right_click_menu(id)`: context menu'yu mouse event akışına bağlayan UI
  helper'ıdır.
- Workspace modal layer `ModalView`/`ToastView` gibi katmanlarda
  `DismissEvent` subscription'ı ile kapanmayı yönetir; `on_before_dismiss`
  varsa kapanmadan önce çağrılır.

Tooltip:

- Element fluent API: `.tooltip(|window, cx| AnyView)` ve
  `.hoverable_tooltip(|window, cx| AnyView)`.
- Imperative `Interactivity` API aynı callback imzasını kullanır.
- `hoverable_tooltip` mouse tooltip içine geçince kapanmaz; normal tooltip
  pointer owner element'ten ayrılınca release edilir.

Tuzaklar:

- Modal/popover view `Focusable` sağlamazsa klavye ve dismiss davranışı eksik
  kalır.
- `DismissEvent` emit eden entity subscription'ı saklanmazsa layer kapanma
  callback'i düşer.
- Aynı elementte birden fazla tooltip tanımlamak debug assert'e yol açar.


---

## Bölüm XVIII — Zed Workspace

---

### 85. Zed Workspace Dock ve Panel Modeli

Bu bölüm GPUI çekirdeği değil, Zed'in `workspace` crate'i üstündeki dock/panel
katmanıdır. Dosyalar: `crates/workspace/src/workspace.rs`,
`crates/workspace/src/dock.rs`, `crates/workspace/src/pane.rs`.

Workspace yapısı:

- `Workspace` merkezde pane grubu, solda `left_dock`, sağda `right_dock`, altta
  `bottom_dock` taşır.
- Dock entity'si `DockPosition::{Left, Bottom, Right}` ile konumlanır.
- `Workspace::left_dock()`, `right_dock()`, `bottom_dock()`, `all_docks()`,
  `dock_at_position(position)` erişim sağlar.
- Aksiyonlar: `ToggleLeftDock`, `ToggleRightDock`, `ToggleBottomDock`,
  `ToggleAllDocks`, `CloseActiveDock`, `CloseAllDocks`,
  `Increase/DecreaseActiveDockSize`, `ResetActiveDockSize` vb.

Panel yazmak için `Panel` trait'i uygulanır:

- `persistent_name()` ve `panel_key()` persist/keymap/telemetry kimliğidir.
- `position`, `position_is_valid`, `set_position` panelin hangi dock'ta olacağını
  yönetir.
- `default_size`, `min_size`, `initial_size_state`, `size_state_changed`,
  `supports_flexible_size`, `set_flexible_size` boyut/persist davranışıdır.
- `icon`, `icon_tooltip`, `icon_label`, `toggle_action`, `activation_priority`
  status bar button ve sıralamayı belirler.
- `starts_open`, `set_active`, `is_zoomed`, `set_zoomed`, `pane`, `remote_id`
  dock state ve remote workspace entegrasyonudur.
- Panel `Focusable + EventEmitter<PanelEvent> + Render` olmalıdır.

Dock davranışı:

- `Dock::add_panel` paneli `activation_priority` sırasına göre ekler. Aynı priority
  debug build'de panic eder; her panel benzersiz priority seçmelidir.
- `Dock::set_open`, `activate_panel`, `active_panel`, `visible_panel`,
  `panel::<T>()`, `remove_panel`, `resize_active_panel`, `resize_all_panels`
  temel yönetim API'leridir.
- Panel `PanelEvent::Activate` emit ederse dock açılır, panel aktiflenir ve focus
  panele taşınır.
- `PanelEvent::Close` aktif görünür paneli kapatır.
- `PanelEvent::ZoomIn/ZoomOut` workspace zoom layer state'ini günceller.
- Boyut state'i `PanelSizeState { size, flex }` olarak persist edilir.

Workspace `toggle_dock` akışı:

1. Dock görünürse açık pozisyonlar kaydedilir.
2. Dock open state terslenir.
3. Aktif panel yoksa ilk enabled panel aktiflenir.
4. Açılıyorsa focus panel focus handle'a taşınır; kapanıyorsa focused panelden
   geliyorsa focus center pane'e döner.
5. Workspace serialize edilir.

Yeni panel eklerken kontrol:

- Panel `panel_key` değişirse eski persist ve keymap adları kırılır.
- `position_is_valid` bottom/side sınırlamalarını net tanımlamalıdır.
- `toggle_action()` action'ı register edilmiş olmalıdır.
- `activation_priority()` benzersiz olmalıdır.
- `set_active` içinde UI state değişiyorsa `cx.notify()` çağrısı unutulmamalıdır.
- Dock değiştiren settings gözlemlerinde panel taşınırken size state axis değişirse
  reset edilebilir; bu mevcut `Dock::add_panel`/settings observer akışında yapılır.

### 86. Workspace Item, Pane, Modal, Toast ve Notification Sistemi

GPUI bir UI framework'üdür; Zed'in workspace katmanı bunun üstünde tab/pane,
modal, toast ve bildirim akışlarını standartlaştırır. Yeni bir editor benzeri
panel veya komut yazıyorsan bu sözleşmeleri tanımalısın.

#### Item ve ItemHandle

`crates/workspace/src/item.rs:167+`. Pane içindeki her tab içeriği `Item`
trait'ini uygular:

```rust
pub trait Item: Focusable + EventEmitter<Self::Event> + Render + Sized {
    type Event;

    fn tab_content(&self, params: TabContentParams, window: &Window, cx: &App)
        -> AnyElement;
    fn tab_tooltip_text(&self, _: &App) -> Option<SharedString> { None }
    fn deactivated(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn workspace_deactivated(&mut self, window: &mut Window, cx: &mut Context<Self>) {}
    fn telemetry_event_text(&self, _: &App) -> Option<&'static str> { None }
    fn navigate(&mut self, _data: Box<dyn Any>, _window: &mut Window, _cx: &mut Context<Self>) -> bool { false }
    // ... save/save_as, project_path, can_split, breadcrumbs, dragged_selection, ...
}
```

`ItemHandle` boxed/dyn karşılığıdır; pane API'leri çoğunlukla `Box<dyn ItemHandle>`
ile çalışır. `FollowableItem` collab takibi (workspace follow) için ek
sözleşmedir.

Tipik akış:

- Yeni tab tipini `impl Item for MyView` ile uygula.
- `Workspace::open_path`/`open_paths`/`open_abs_path` zaten `ProjectItem` üreterek
  doğru `Item` view'ini açar; özel akışta `Pane::add_item(Box::new(view), ...)`
  kullanılır.
- `Pane::activate_item`, `close_active_item`, `navigate_backward`,
  `navigate_forward`, `split` (split direction ile yeni pane) Pane API'leridir.
- `Workspace::split_pane(pane, direction, cx)` mevcut pane'i böler.
- `Workspace::register_action::<A>(|workspace, &A, window, cx| ...)` workspace
  global action'larını ekler (komut paleti üzerinden veya keymap'ten tetiklenen).

#### ModalView ve Modal Layer

`crates/workspace/src/modal_layer.rs:13+`:

```rust
pub trait ModalView: ManagedView {
    fn on_before_dismiss(&mut self, window, cx) -> DismissDecision { ... }
    fn fade_out_background(&self) -> bool { false }
    fn render_bare(&self) -> bool { false }
}
```

`ManagedView = Focusable + EventEmitter<DismissEvent> + Render`. Modal yazarken
bu bileşik trait'i sağlamak gerekir.

Açma/kapama:

```rust
workspace.toggle_modal(window, cx, |window, cx| {
    MyModal::new(window, cx)
});

workspace.hide_modal(window, cx);
```

`toggle_modal` halihazırda aynı tip bir modal açıksa onu kapatır; aksi halde yenisini açar. `on_before_dismiss` `DismissDecision::Dismiss(false)` veya
`Pending` döndürürse yeni modal görünmez.

#### StatusBar ve StatusItemView

`crates/workspace/src/status_bar.rs`:

```rust
pub trait StatusItemView: Render {
    fn set_active_pane_item(
        &mut self,
        active_pane_item: Option<&dyn ItemHandle>,
        window: &mut Window,
        cx: &mut Context<Self>,
    );

    fn hide_setting(&self, cx: &App) -> Option<HideStatusItem>;
}
```

Workspace status bar'a item eklemek:

```rust
workspace.status_bar().update(cx, |status_bar, cx| {
    status_bar.add_left_item(my_view, window, cx);
    status_bar.add_right_item(other_view, window, cx);
});
```

Status item active pane item değiştikçe `set_active_pane_item` ile bilgilendirilir;
böylece git branch indicator, cursor position gibi item'lar focused buffer'a
göre güncellenir.
`hide_setting()` `Some(HideStatusItem)` döndürürse status bar sağ tık menüsüne
"Hide Button" kaydı eklenir ve kullanıcı ayar dosyası `update_settings_file`
üzerinden güncellenir. Item zaten başka bir ayarla koşullu görünüyorsa `None`
döndürülebilir.

#### Notification ve Toast Sistemi

`crates/workspace/src/notifications.rs`:

```rust
pub trait Notification:
    EventEmitter<DismissEvent> + EventEmitter<SuppressEvent> + Focusable + Render
{}

pub enum NotificationId {
    Unique(TypeId),               // tip başına tek
    Composite(TypeId, ElementId), // tip + sub-id
    Named(SharedString),          // serbest isim
}

// Constructor yardımcıları:
// NotificationId::unique::<MyNotification>()
// NotificationId::composite::<MyNotification>(element_id)
// NotificationId::named("save".into())
```

Mesaj göstermek için:

```rust
workspace.show_notification(
    NotificationId::unique::<MyNotification>(),
    cx,
    |cx| cx.new(|cx| MyNotification::new(cx)),
);

workspace.show_toast(
    Toast::new(NotificationId::named("save".into()), "Saved")
        .autohide(),
    cx,
);

workspace.show_error(&error, cx);
```

`Toast` lightweight ve geçicidir (autohide), `Notification` ise persistant
view'dir ve kullanıcı dismiss edene kadar görünür. `SuppressEvent` aynı kaynaktan
gelen tekrarlı bildirimleri bastırmak için kullanılır.

`Workspace::toggle_status_toast<V: ToastView>` ise modal layer mantığında
`ToastView` üzerinden toast'ı toggle eder; tipik UI elemanları (örn. async iş
ilerleme göstergeleri) bu yolla bağlanır.

```rust
pub trait ToastView: ManagedView {
    fn action(&self) -> Option<ToastAction>;
    fn auto_dismiss(&self) -> bool { true }
}
```

`ToastAction::new(label, on_click)` toast içindeki aksiyon butonunu tanımlar.
`ToastView` tabanlı toast'larda auto dismiss default `true`; `Workspace::show_toast`
ile gösterilen lightweight `Toast` struct'ında ise `.autohide()` çağrılmadıkça
otomatik kapanma yoktur.

#### `Workspace::open_*` Akışı

```rust
let task = workspace.open_paths(
    vec![PathBuf::from("src/main.rs")],
    OpenOptions {
        visible: Some(OpenVisible::All),
        ..Default::default()
    },
    None,
    window,
    cx,
);
```

Önemli giriş noktaları:

- `workspace::open_paths(paths, app_state, open_options, cx)`: standalone helper;
  gerekirse pencere açar veya mevcut workspace'i yeniden kullanır.
- `Workspace::open_paths(abs_paths, OpenOptions, pane, window, cx)`: mevcut
  workspace içinde birden çok absolute path açar.
- `Workspace::open_path(project_path, pane, focus, window, cx)`: belirli bir
  `ProjectPath`'i mevcut workspace içinde açar; `Task<Result<Box<dyn ItemHandle>>>`
  döndürür.
- `Workspace::open_abs_path(path, options, window, cx)`: `PathBuf` alır, dosyayı
  worktree'ye ekler ve item açar.
- `Workspace::open_path_preview(path, pane, focus_item, allow_preview, activate,
  window, cx)`: file finder gibi ön izleme akışları için.
- `Workspace::split_abs_path(...)`, `split_path(...)`, `split_item(...)`: yeni
  pane oluşturarak path veya item'i split içinde açar.

#### Tuzaklar

- `Item` implementasyonunda `Self::Event` türünü doğru tanımlamak ve
  `EventEmitter<Self::Event>` impl etmek gerekir; aksi halde `Item` trait
  bound'u tutmaz.
- `Pane::add_item` `Box::new(view)` ile yapılır; pane item ownership'ini alır.
- `Workspace::register_action` callback signature'ı
  `Fn(&mut Self, &A, &mut Window, &mut Context<Self>)` — diğer GPUI
  `on_action` listener'larından farklı pozisyonel düzeni var (`&A` ortada).
- `NotificationId::Unique(TypeId::of::<T>())` ile aynı tipte iki notification
  açarsan ikincisi birinciyi yerine geçer; farklı sub-id istiyorsan
  `Composite(TypeId, ElementId)` kullan.
- `Toast` autohide süresi varsayılan değildir; uzun mesajlarda elle
  `dismiss_toast` çağırılması gerekebilir.
- `ModalView::on_before_dismiss` `Pending` döndürürse modal kapanma akışı
  beklemeye girer; testte `run_until_parked()` ile resolve sürecini ilerletmen
  gerekir.

### 87. Workspace Serialization, OpenOptions, ProjectItem ve SearchableItem

Workspace item açma yalnızca `Pane::add_item` değildir; Zed session restore,
project item resolution, search bar ve collab follow gibi katmanları da item
trait'leri üzerinden bağlar.

#### SerializableItem ve Restore

`SerializableItem` workspace kapanırken veya item event'i geldiğinde item state'ini
workspace DB'ye yazmak ve sonra geri yüklemek için kullanılır:

```rust
pub trait SerializableItem: Item {
    fn serialized_item_kind() -> &'static str;

    fn cleanup(
        workspace_id: WorkspaceId,
        alive_items: Vec<ItemId>,
        window: &mut Window,
        cx: &mut App,
    ) -> Task<Result<()>>;

    fn deserialize(
        project: Entity<Project>,
        workspace: WeakEntity<Workspace>,
        workspace_id: WorkspaceId,
        item_id: ItemId,
        window: &mut Window,
        cx: &mut App,
    ) -> Task<Result<Entity<Self>>>;

    fn serialize(
        &mut self,
        workspace: &mut Workspace,
        item_id: ItemId,
        closing: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<Task<Result<()>>>;

    fn should_serialize(&self, event: &Self::Event) -> bool;
}
```

Kayıt:

```rust
workspace::register_serializable_item::<MyItem>(cx);
```

- `serialized_item_kind()` session DB'deki discriminant'tır; değiştirirsen eski
  session restore bozulur.
- `serialize(..., closing, ...)` `None` döndürürse o event için yazma yapılmaz.
- `should_serialize(event)` item event'inden sonra serialization gerekip
  gerekmediğini belirler.
- `cleanup(workspace_id, alive_items, ...)` DB'de artık canlı olmayan item kayıtlarını
  temizlemek için çağrılır.
- `SerializableItemHandle` `Entity<T: SerializableItem>` için blanket implement
  edilir; pane/workspace type erasure bu handle üzerinden çalışır.

#### OpenOptions ve open_paths

Top-level `workspace::open_paths` ve `Workspace::open_paths` aynı option modelini
kullanır:

- `visible: Option<OpenVisible>`: `All`, `None`, `OnlyFiles`, `OnlyDirectories`.
- `focus: Option<bool>`: açılan item focus alsın mı?
- `workspace_matching: WorkspaceMatching`: `None`, `MatchExact`,
  `MatchSubdirectory`.
- `add_dirs_to_sidebar`: unmatched directory yeni pencere açmak yerine mevcut
  local `MultiWorkspace` penceresine workspace olarak eklensin mi? Default `true`.
  Ekleme yalnız hedef window'da `multi_workspace_enabled(cx)` true ise yapılır;
  bu durumda `requesting_window` aktif/ilk local multi-workspace window'a set
  edilir ve sidebar açılır.
- `wait`: CLI `--wait` benzeri akışlarda pencerenin kapanmasını bekleme davranışı.
- `requesting_window`: hedef `WindowHandle<MultiWorkspace>` varsa onu kullan.
- `open_mode: OpenMode`: `NewWindow`, `Add`, `Activate`.
- `env`: açılan workspace için environment override.
- `open_in_dev_container`: dev container açma isteği.

`OpenResult { window, workspace, opened_items }` top-level açma sonucudur. İç
workspace açma fonksiyonları çoğunlukla `Task<Result<Box<dyn ItemHandle>>>` veya
çoklu path için `Task<Vec<Option<Result<Box<dyn ItemHandle>>>>>` döndürür.

#### ProjectItem

`ProjectItem` Zed project entry'sinden workspace item view'i üretir:

```rust
pub trait ProjectItem: Item {
    type Item: project::ProjectItem;

    fn project_item_kind() -> Option<ProjectItemKind> { None }

    fn for_project_item(
        project: Entity<Project>,
        pane: Option<&Pane>,
        item: Entity<Self::Item>,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Self;

    fn for_broken_project_item(...) -> Option<InvalidItemView> { None }
}
```

Normal dosya açma `project::ProjectItem::try_open` üzerinden item'i çözer; hata
durumunda `for_broken_project_item` bozuk/eksik kaynağı temsil eden view üretmek
için kullanılabilir.

#### SearchableItem

Workspace search bar'ın bir item içinde çalışması için `SearchableItem` gerekir:

- `type Match`: arama sonucunu temsil eden cloneable match tipi.
- `supported_options() -> SearchOptions`: case, word, regex, replacement,
  selection, select_all, find_in_results desteklerini bildirir.
- `find_matches(query, window, cx) -> Task<Vec<Match>>` veya token'lı
  `find_matches_with_token`.
- `update_matches`, `clear_matches`, `activate_match`, `select_matches`.
- `replace` ve `replace_all` replace destekleyen item'lar içindir.
- `SearchEvent::{MatchesInvalidated, ActiveMatchChanged}` search UI'ı yeniden
  sorgulamaya zorlar.
- `SearchableItemHandle` type-erased search item'ıdır; `Item::as_searchable`
  bunu döndürerek pane toolbar search bar'a bağlanır.

#### FollowableItem

Collab/follow akışı için `FollowableItem` kullanılır:

- `remote_id()`, `to_state_proto`, `from_state_proto` remote view state'ini taşır.
- `to_follow_event(event)` item event'ini follow event'e çevirir.
- `add_event_to_update_proto` ve `apply_update_proto` incremental remote update
  akışıdır.
- `set_leader_id` takip edilen kullanıcı bilgisini item state'ine işler.
- `dedup(existing, ...) -> Option<Dedup>` remote item açılırken mevcut item ile
  birleştirme veya replace kararıdır.

Tuzaklar:

- Serializable item'i register etmezsen `deserialize` hiç çağrılmaz; session restore
  silently invalid item'e düşebilir.
- `serialized_item_kind` global namespace gibidir; başka item ile çakıştırma.
- Search match tipini byte offset, buffer snapshot ve token ile uyumlu tut; stale
  match'i yeni buffer üzerinde kullanmak yanlış range'e gider.
- `OpenOptions::visible = None` default olarak workspace'e görünür worktree ekleme
  anlamına gelmez; path açma davranışını özellikle directory/file ayrımı için
  açık seç.

### 88. PaneGroup, NavHistory, Toolbar ve Sidebar Entegrasyonu

Pane ve workspace yalnız tab listesi değildir; split ağacı, navigation history,
toolbar item'ları ve multi-workspace sidebar birlikte çalışır.

#### PaneGroup ve SplitDirection

`PaneGroup` center veya dock içindeki pane ağacını taşır. Kök `Member::Pane` veya
`Member::Axis(PaneAxis)` olabilir.

- `PaneGroup::new(pane)` tek pane ile başlar.
- `split(old_pane, new_pane, SplitDirection, cx)` ağaca yeni pane ekler; eski pane
  bulunamazsa first pane fallback'i kullanılır.
- `remove`, `resize`, `reset_pane_sizes`, `swap`, `move_to_border` split ağacını
  değiştirir.
- `pane_at_pixel_position(point)`, `bounding_box_for_pane(pane)`,
  `find_pane_in_direction` drag/drop ve keyboard pane navigation için kullanılır.
- `SplitDirection::{Up, Down, Left, Right}`; `vertical(cx)` ve `horizontal(cx)`
  kullanıcı ayarına göre default split yönünü üretir.
- `SplitDirection::axis()`, `opposite()`, `edge(bounds)`,
  `along_edge(bounds, length)` resize/drop indicator hesaplarında kullanılır.

#### Pane Preview, Pin ve NavHistory

Pane item listesinde preview/pinned ayrımı vardır:

- `preview_item_id`, `preview_item`, `is_active_preview_item`,
  `unpreview_item_if_preview`, `replace_preview_item_id` preview tab akışıdır.
- `pinned_count`, `set_pinned_count` pinned tab sınırını yönetir.
- `activate_item`, `activate_previous_item`, `activate_next_item`,
  `activate_last_item`, `swap_item_left/right` tab selection ve sıra yönetimidir.
- `close_active_item`, `close_item_by_id`, `close_other_items`,
  `close_clean_items`, `close_all_items` save intent ve pinned davranışını hesaba
  katar.
- Workspace bir pane'i kaldırırken aktif pane kaldırılıyorsa
  `Workspace::force_remove_pane` artık önce `active_pane`'i kalan pane'e günceller:
  `focus_on` verilmişse o pane aktif olur, verilmemişse son kalan pane fallback
  olur. Aktif modal varsa focus fallback pane'e taşınmayabilir, ancak `active_pane`
  yine kaldırılmış pane olarak bırakılmaz.

Navigation:

- `Pane::nav_history_for_item(item)` item'e bağlı `ItemNavHistory` üretir.
- `ItemNavHistory::push(data, row, cx)` item history'ye entry ekler; item
  `include_in_nav_history()` false döndürürse eklenmez.
- `NavHistory::pop(GoingBack/GoingForward, cx)`, `clear`, `disable`, `enable`,
  `set_mode`, `for_each_entry` history yönetimidir.
- `push_tag`/`pop_tag` definition/reference gibi tag navigation stack'ini yönetir.

#### ToolbarItemView

Pane toolbar'a katkı verecek view `ToolbarItemView` uygular:

```rust
pub trait ToolbarItemView: Render + EventEmitter<ToolbarItemEvent> {
    fn set_active_pane_item(
        &mut self,
        active_pane_item: Option<&dyn ItemHandle>,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> ToolbarItemLocation;

    fn pane_focus_update(&mut self, pane_focused: bool, window: &mut Window, cx: &mut Context<Self>) {}
    fn contribute_context(&self, context: &mut KeyContext, cx: &App) {}
}
```

- `ToolbarItemLocation::{Hidden, PrimaryLeft, PrimaryRight, Secondary}` render
  yerini belirler.
- Item kendi yerini değiştirmek isterse `ToolbarItemEvent::ChangeLocation(...)`
  emit eder.
- `Toolbar::add_item(entity, window, cx)` item'i kaydeder.
- `Toolbar::set_active_item` active pane item değişince tüm toolbar item'larını
  günceller.
- `contribute_context` görünür toolbar item'larının key context'e katkı vermesini
  sağlar.

#### Sidebar ve MultiWorkspace

AI/multi-workspace sidebar ayrı bir trait ile bağlanır:

```rust
pub trait Sidebar: Focusable + Render + EventEmitter<SidebarEvent> + Sized {
    fn width(&self, cx: &App) -> Pixels;
    fn set_width(&mut self, width: Option<Pixels>, cx: &mut Context<Self>);
    fn has_notifications(&self, cx: &App) -> bool;
    fn side(&self, cx: &App) -> SidebarSide;
    fn serialized_state(&self, cx: &App) -> Option<String> { None }
    fn restore_serialized_state(&mut self, state: &str, window: &mut Window, cx: &mut Context<Self>) {}
}
```

- `MultiWorkspace::register_sidebar(entity, cx)` sidebar'ı handle olarak saklar,
  observe eder ve `SidebarEvent::SerializeNeeded` geldiğinde serialize eder.
- `toggle_sidebar`, `open_sidebar`, `close_sidebar`, `focus_sidebar` görünürlük ve
  focus akışıdır.
- `set_sidebar_overlay(Some(AnyView), cx)` sidebar üstüne overlay yerleştirir.
- `multi_workspace_enabled(cx)`, `!DisableAiSettings::disable_ai` ve
  `AgentSettings::enabled` koşullarının birlikte true olmasına bağlıdır. Bu false
  ise sidebar açma/focus işlemleri erken döner ve açık sidebar render edilmez.
- `sidebar_render_state(cx)` render tarafında open/side bilgisini taşır; `open`
  değeri hem sidebar açık olmasına hem de `multi_workspace_enabled(cx)` sonucuna
  bağlıdır.
- `sidebar_has_notifications(cx)` titlebar/status indicator için kullanılır.
- Workspace aktivasyonunda retain kararı artık sidebar'ın açık olmasına bağlı
  değildir. Multi-workspace etkinse yeni aktif workspace ve önceki transient aktif
  workspace retain edilir; multi-workspace devre dışıysa eski transient workspace
  detach edilir. Settings değişiminde etkin durumdan devre dışına geçiş
  `collapse_to_single_workspace` ile tüm grupları atar.

Tuzaklar:

- Toolbar item `set_active_pane_item` içinde location döndürür ama daha sonra yer
  değiştirecekse event emit etmelidir; sadece state değiştirip `cx.notify()` yeterli
  değildir.
- Sidebar state'i serialize etmek istiyorsan `SidebarEvent::SerializeNeeded` emit
  etmeyi unutma.
- Workspace retain/detach davranışını sidebar açık/kapalı durumuna bağlama;
  güncel karar kaynağı `multi_workspace_enabled(cx)` sonucudur.
- Nav history preview item'i ayrı işaretler; preview tab gerçek tab'a pinlenince
  history entry'lerini buna göre güncelle.
- Split yönü hardcode etmek yerine user ayarlı default isteniyorsa
  `SplitDirection::vertical(cx)` / `horizontal(cx)` kullan.

### 89. Workspace Notification Yardımcıları ve Async Hata Gösterimi

Bildirim sistemi yalnız `show_notification` değildir; workspace dışı app-level
notification ve async error propagation için yardımcı trait'ler vardır.

App-level notification:

- `show_app_notification(id, cx, build)`: active workspace varsa orada, yoksa tüm
  workspace'lerde notification gösterir.
- `dismiss_app_notification(id, cx)`: aynı id'li app notification'ları kapatır.
- `NotificationFrame` başlık, içerik, suppress/close butonu ve suffix compose
  etmek için kullanılan standart frame'dir.
- `simple_message_notification::MessageNotification` primary/secondary mesaj,
  icon, click handler, close/suppress ve "more info" URL gibi hazır alanlar sağlar.

Error propagation:

- `NotifyResultExt::notify_err(workspace, cx)`: `Result` error ise workspace
  notification gösterir ve `None` döndürür.
- `notify_workspace_async_err(weak_workspace, async_cx)`: async task içinde weak
  workspace'e error notification yollar.
- `notify_app_err(cx)`: active workspace yoksa app-level notification gösterir.
- `NotifyTaskExt::detach_and_notify_err(workspace, window, cx)`: `Task<Result<...>>`
  sonucunu window üzerinde spawn eder ve error'u workspace notification'a çevirir.
- `DetachAndPromptErr::prompt_err` ve `detach_and_prompt_err`: `anyhow::Result`
  task'ını prompt tabanlı kullanıcı hatasına çevirir.

Kullanım seçimi:

- Kullanıcı aksiyonunun sonucu doğrudan workspace içinde görünmeli ise
  `notify_err`/`detach_and_notify_err`.
- Kritik onay veya seçim gerekiyorsa `detach_and_prompt_err`.
- Workspace yokken de görünmesi gereken startup/global hata için
  `notify_app_err` veya `show_app_notification`.

Tuzaklar:

- `detach_and_log_err` yalnız loglar; kullanıcıya görünür hata isteniyorsa
  workspace notification/prompt helper'larından birini seç.
- `show_app_notification` aynı id ile birden fazla workspace'te gösterim yapabilir;
  id'yi `NotificationId::named` veya `composite` ile bilinçli seç.
- `MessageNotification` click handler'ları `Window` ve `App` alır; workspace state
  gerekiyorsa weak workspace/entity yakala ve düşmüş olma ihtimalini ele al.

### 90. AppState, WorkspaceStore, WorkspaceDb ve OpenListener Akışı

Zed uygulamasında workspace açma, sadece `open_window` çağrısı değildir. Startup,
CLI/open-url istekleri, workspace DB ve collab follow state'i birkaç global/handle
üzerinden birbirine bağlanır.

#### AppState

`AppState` Zed workspace açma ve restore işlemlerinde taşınan uygulama servis
paketidir:

- `languages: Arc<LanguageRegistry>`
- `client: Arc<Client>`
- `user_store: Entity<UserStore>`
- `workspace_store: Entity<WorkspaceStore>`
- `fs: Arc<dyn fs::Fs>`
- `build_window_options: fn(Option<Uuid>, &mut App) -> WindowOptions`
- `node_runtime: NodeRuntime`
- `session: Entity<AppSession>`

`AppState::set_global(state, cx)` global olarak kurar; `AppState::global(cx)` ve
`try_global(cx)` okuma yapar. Testlerde `AppState::test(cx)` fake FS, test
language registry ve test settings store kurar.

#### WorkspaceStore

`WorkspaceStore` açık workspace'leri `AnyWindowHandle + WeakEntity<Workspace>`
çifti olarak izler. Collab tarafındaki follow/update follower mesajları bu store
üzerinden uygun workspace'e yönlendirilir.

- `WorkspaceStore::new(client, cx)` client request/message handler'larını kaydeder.
- `workspaces()` weak workspace iterator'ı verir.
- `workspaces_with_windows()` window handle ile birlikte döndürür.
- `update_followers(project_id, update, cx)` aktif call üzerinden follower update
  mesajı gönderir.
- Collab/titlebar/follow akışlarında client tarafındaki `User` artık
  `legacy_id: LegacyUserId` alanını taşır; proto room role lookup,
  participant index ve `join_in_room_project` gibi legacy id bekleyen yerlere
  `user.legacy_id` verilmelidir. `user.id` alanı bu client modelinde yoktur.

#### WorkspaceDb ve HistoryManager

`WorkspaceDb::global(cx)` session/workspace persistence için kullanılan SQLite
bağlantı wrapper'ıdır. Workspace restore ve recent project history şu katmanlara
dağılır:

- `open_workspace_by_id(workspace_id, app_state, requesting_window, cx)` DB'deki
  serialized workspace'i açar.
- `read_serialized_multi_workspaces`, `SerializedMultiWorkspace`,
  `SerializedWorkspaceLocation`, `SessionWorkspace`, `ItemId` persistence modelidir.
- `HistoryManager::global(cx)` recent local workspace geçmişini verir.
- `HistoryManager::update_history(id, entry, cx)` recent list'i günceller ve
  platform jump list'i yeniler.
- `HistoryManager::delete_history(id, cx)` unload edilen workspace'i geçmişten
  kaldırır.

#### OpenListener ve RawOpenRequest

`zed::open_listener` app dışından gelen açma isteklerini queue'lar:

```rust
let (listener, rx) = OpenListener::new();
listener.open(RawOpenRequest {
    urls,
    diff_paths,
    diff_all,
    dev_container,
    wsl,
});
```

- `OpenListener` bir `Global`'dir; `open(...)` isteği unbounded channel'a yollar.
- `RawOpenRequest` ham CLI/URL alanlarını taşır.
- `OpenRequest::parse(raw, cx)` bunları typed `OpenRequest` haline getirir.
- `OpenRequestKind` kaynak türünü belirtir: CLI connection, extension, agent
  panel, shared agent thread, dock menu action, builtin JSON schema, setting,
  git clone, git commit vb.
- Linux/FreeBSD'de `listen_for_cli_connections` release-channel socket'i üzerinden
  CLI isteklerini alır.

Tuzaklar:

- Workspace açma akışında `AppState::build_window_options` kullan; doğrudan
  `WindowOptions` kopyalamak Zed'in titlebar, app id, bounds restore ve platform
  ayarlarını bypass eder.
- `WorkspaceStore` weak workspace tutar; iterasyon yaparken upgrade başarısız
  olabilir.
- `OpenListener::open` listener yoksa hatayı loglar; request teslim edildi
  varsayımıyla kullanıcı akışı başlatma.
- DB restore path'inde serializable item kind eksikse item restore edilemez;
  yeni item türü eklerken `register_serializable_item` startup init'inde
  çağrılmalıdır.

### 91. Item Ayarları, Context Menu, ApplicationMenu ve Focus-Follows-Mouse

Zed UI kodunda sık görülen ama GPUI çekirdeği olmayan birkaç yardımcı katman daha
vardır.

#### Item Ayarları ve SaveIntent

Item/tab davranışını settings tarafına bağlayan tipler:

- `ItemSettings`: `git_status`, `close_position`, `activate_on_close`,
  `file_icons`, `show_diagnostics`, `show_close_button` alanlarını `tabs` ve
  `git` ayarlarından üretir.
- `PreviewTabsSettings`: preview tab kaynaklarını ayrı ayrı açıp kapatır:
  project panel, file finder, multibuffer, code navigation, keep-preview gibi.
- `TabContentParams { detail, selected, preview, deemphasized }`: tab render'ına
  selection/preview/focus dışı durumu taşır; `text_color()` semantic `Color`
  döndürür.
- `TabTooltipContent::{Text, Custom}` tab tooltip'ini string veya custom view
  olarak tanımlar.
- `ItemBufferKind::{Multibuffer, Singleton, None}` item'in buffer ilişkisini
  sınıflandırır.

Save/close akışında `SaveIntent` kullanılır:

- `Save`, `FormatAndSave`, `SaveWithoutFormat`, `SaveAll`, `SaveAs`, `Close`,
  `Overwrite`, `Skip`.
- Pane close action'ları `CloseActiveItem`, `CloseOtherItems`, `CloseAllItems`
  gibi action struct'larında optional `SaveIntent` taşır. Dirty/format/conflict
  davranışını doğrudan boolean ile çoğaltma; mevcut save intent zincirine bağlan.
- `SaveOptions { format, force_format, autosave }` item save implementasyonunun
  düşük seviyeli karar paketidir.

#### ContextMenu ve PopoverMenu

`ContextMenu` bir `ManagedView` olarak modal/popover zincirine takılır. İçerik
modeli:

- `ContextMenuItem::{Separator, Header, HeaderWithLink, Label, Entry,
  CustomEntry, Submenu}`.
- `ContextMenuEntry` label, icon, checked/toggle, action, disabled, secondary
  handler, documentation aside ve end-slot gibi alanları taşır.
- `ContextMenu::build(window, cx, |menu, window, cx| ...)` menü entity'si üretir.
- `menu.context(focus_handle)` menu action availability ve keybinding display için
  belirli focus context'ini kullanır.

`PopoverMenu<M: ManagedView>` anchor element ile managed menu view'i bağlar:

- `PopoverMenu::new(id)`, `.menu(...)`, `.with_handle(handle)`, `.anchor(...)`,
  `.attach(...)`, `.offset(...)`, `.full_width(...)`, `.on_open(...)`.
- `PopoverMenuHandle<M>` dışarıdan toggle/close ve açık menu entity'sine erişim
  için saklanır.
- Popover konumlandırması `window.layout_bounds` ve çift `on_next_frame` desenini
  kullanabilir; anchor bounds ilk frame'de, menu bounds sonraki frame'de bilinir.

#### Client-side ApplicationMenu

macOS dışındaki client-side application menu `title_bar::ApplicationMenu` ile
çizilir:

- `ApplicationMenu::new(window, cx)` `cx.get_menus()` ile platform/app menülerini
  okur ve her top-level menu için `PopoverMenuHandle<ContextMenu>` saklar.
- `OpenApplicationMenu(String)` action'ı belirli menüyü açar.
- `ActivateMenuLeft`/`ActivateMenuRight` client-side menu bar içinde yatay gezinir.
- `ApplicationMenu` boş submenu'leri ve ardışık/trailing separator'ları temizler,
  sonra `OwnedMenuItem::{Action, Submenu, Separator, SystemMenu}` değerlerini
  işler. `Action`/`Submenu`/`Separator` `ContextMenu` entry'lerine dönüşür;
  `SystemMenu(_)` client-side context'te anlamlı olmadığı için yok sayılır.

#### FocusFollowsMouse

`FocusFollowsMouse` trait'i `StatefulInteractiveElement` üzerine eklenir:

```rust
element.focus_follows_mouse(WorkspaceSettings::get_global(cx).focus_follows_mouse, cx)
```

- Ayar enabled ise hover enter sırasında target `AnyWindowHandle + FocusHandle`
  global state'e yazılır.
- Debounce için `cx.background_executor().timer(settings.debounce).await`
  kullanılır.
- Debounce sonunda `cx.update_window(window, |_, window, cx| window.focus(&focus, cx))`
  çağrılır.
- Daha spesifik child focus target'ı varken parent hover onu ezmesin diye
  `focus_handle.contains(existing, window)` kontrolü yapılır.

Tuzaklar:

- Context menu action'ları focused element context'ine göre enable/disable olur;
  menüyü focus context'i olmadan kurarsan bazı action'lar görünür ama çalışmayabilir.
- ApplicationMenu platform menu bar değildir; macOS native menü ayrı platform
  menü akışından gelir.
- Focus-follows-mouse global debounce state kullanır; aynı anda birden çok hover
  target'ı yarışabilir, bu nedenle daha spesifik child kontrolünü kaldırma.


---

## Bölüm XIX — Zed Settings ve Theme

---

### 92. Persist, Settings ve Theme Akışı (Zed Tarafı)

GPUI çekirdeği değil ama yeni pencere/UI eklerken temaya ve ayarlara takılı
kalmak gerekir. Ana dosyalar: `crates/settings`, `crates/settings_content`,
`crates/theme`, `crates/theme_settings`.

Akış:

1. Kullanıcı `~/.config/zed/settings.json` veya proje `.zed/settings.json` yazar.
2. `SettingsStore` global'i değişimi yayar.
3. `Settings` trait'leri (`WorkspaceSettings`, `ThemeSettings`, ...) kendi
   bölümlerini parse eder.
4. UI tarafları `cx.observe_global::<SettingsStore>(...)` ile değişimi izler ve
   yeniden render eder.

Yeni bir ayar eklemek için önce `settings_content` içindeki JSON içerik modeline
alan eklenir, sonra runtime settings tipi `Settings` trait'ini uygular. Bu
repodaki gerçek trait ilişkili içerik tipi veya `load` yöntemi değil,
`from_settings` kullanır:

```rust
#[derive(Clone, Deserialize, RegisterSetting)]
pub struct YourSettings {
    pub enabled: bool,
}

impl Settings for YourSettings {
    fn from_settings(content: &settings::SettingsContent) -> Self {
        let section = &content.your_feature;
        Self {
            enabled: section.enabled.unwrap_or(false),
        }
    }
}
```

`RegisterSetting` derive'ı inventory üzerinden tipi `SettingsStore` içine kaydeder.
Elle kayıt gerekiyorsa uygulama başlangıcında `YourSettings::register(cx)` da
kullanılabilir. `Settings::get_global(cx)`, `Settings::get(path, cx)` ve
`Settings::try_get(cx)` okuma tarafındaki standart giriş noktalarıdır.

Güncel agent ayar içeriğinde `agent.default_model` yanında
`agent.subagent_model: Option<LanguageModelSelection>` de bulunur. `spawn_agent`
ile açılan subagent thread'i bu ayar set edilmişse onu kullanır; ayar yoksa parent
agent'ın model seçimiyle devam eder. Agent/multi-workspace davranışında
`AgentSettings::enabled` de önemli bir settings sinyalidir.

Tema renkleri:

```rust
let colors = cx.theme().colors();
let panel_bg = colors.panel_background;
let border = colors.border;
```

`cx.theme()` aktif `ThemeVariant` (light/dark) döndürür. `.colors()`,
`.players()`, `.syntax()` bölümlerini taşır. `theme::ActiveTheme` extension trait
`App` üzerinde olduğu için `cx.theme()` doğrudan çalışır.

Persist edilen örnekler:

- Pencere bounds (bkz. Bölüm 33).
- Açık projeler ve recent: `crates/recent_projects`.
- Workspace serialization: `crates/workspace/src/persistence.rs` ve
  `db` crate'i (SQLite tabanlı).
- Vim mod, panel boyutları, dock state: workspace serialization.

Tuzaklar:

- `cx.theme()` panel açılırken `None` olmaz; ancak `cx.global::<ThemeRegistry>()`
  henüz yüklenmemişse fallback theme döner.
- Settings serialization `SettingsContent` merge akışına bağlıdır; user/global,
  project ve language-specific kaynaklar `SettingsStore` içinde recompute edilir.
- Yeni ayar eklerken `settings_content` schema güncellenmeden JSON schema
  doğrulaması eski formatı kabul etmez.

### 93. SettingsStore: Kayıt, Okuma, Override ve Migration

`crates/settings/src/settings_store.rs`. `SettingsStore` Zed'in tüm ayar
kaynaklarını tek bir tip-güvenli store içinde birleştirir.

Ayar kayıt yolları:

```rust
// Derive ile inventory üzerinden otomatik kayıt:
#[derive(Clone, Deserialize, RegisterSetting)]
pub struct YourSettings { pub enabled: bool }

impl Settings for YourSettings {
    fn from_settings(content: &SettingsContent) -> Self {
        Self { enabled: content.your_feature.as_ref()
            .and_then(|f| f.enabled).unwrap_or(false) }
    }
}

// Manuel kayıt (her zaman çalışan path):
YourSettings::register(cx);
```

`RegisterSetting` derive `inventory::collect!` ile build-time topluluk yaratır.
Store kurulumu `SettingsStore::new(cx, &settings::default_settings())` imzasıyla
yapılır; Zed'in normal başlangıç yolunda bunu `settings::init(cx)` çağırır ve
oluşan store'u `cx.set_global(settings)` ile global yapar.

Okuma:

- `YourSettings::get_global(cx)`: aktif global değer.
- `YourSettings::get(Some(SettingsLocation { worktree_id, path }), cx)`:
  worktree veya `.zed/settings.json` override'ı dahil değer.
- `YourSettings::try_get(cx)`: store register edilmemişse `None`.
- `YourSettings::try_read_global(async_cx, |s| ...)`: async context içinde.

Yazma:

- `YourSettings::override_global(value, cx)`: programatik override; persist
  edilmez, sadece runtime state'i değiştirir.
- `settings::update_settings_file(fs, cx, |content, cx| { ... })`: user
  JSON'unu kalıcı yazma yolu; dosya okuma/yazma, parse ve store update akışı
  `SettingsStore::update_settings_file(...)` üzerinden tamamlanır.
- `SettingsStore::update_user_settings(...)` yalnızca `test-support` altında
  vardır; uygulama kodunda kalıcı yazma için kullanılmaz.

Observer akışı:

```rust
cx.observe_global::<SettingsStore>(|cx| {
    let theme = ThemeSettings::get_global(cx);
    apply_theme(theme, cx);
}).detach();
```

`SettingsStore` global'i her dosya değişimi veya programatik override sonrası
notify edilir; observer içinde değer zaten yeni state'tedir.

Migration:

- Kullanıcı JSON'u eski schema kullanıyorsa
  `crates/settings/src/migrator/` modülü değerleri yeni anahtarlara taşır.
- `SettingsStore::set_user_settings(...)` ve file watcher/update callback'leri
  `SettingsParseResult { parse_status, migration_status }` döndürür veya taşır.
- `MigrationStatus` değerleri `NotNeeded`, `Succeeded` ve
  `Failed { error }` şeklindedir. Başarılı migration in-memory uygulanır;
  çağıran taraf gerekiyorsa dosyayı yeniden yazar veya kullanıcıya uyarı üretir.
- Parse sonucu `ParseStatus::Success`, `ParseStatus::Unchanged` veya
  `ParseStatus::Failed { error }` olur; migration durumu ayrı alandır.

Tuzaklar:

- `from_settings` panic ediyorsa default JSON eksiktir; her alan
  `assets/settings/default.json` içinde tanımlı olmalıdır.
- Per-language ayar gerekiyorsa `LanguageSettings::get(Some(location), cx)` ile
  worktree-specific override otomatik gelir.
- Observer'da `cx.notify()` çağrısı entity'yi yeniden render etmek için gereklidir;
  `observe_global` sadece callback'i çalıştırır, view'i invalidate etmez.

### 94. ThemeRegistry, ThemeFamily ve Tema Yükleme

`crates/theme/src/registry.rs`, `crates/theme/src/theme.rs`,
`crates/theme_settings/src/theme_settings.rs`.

Tema veri modeli:

- `ThemeFamily { name, author, themes: Vec<Theme> }`: bir paket içindeki light/dark
  varyantlar.
- `Theme { name, appearance, styles }`: belirli bir varyant.
- `ThemeColors`, `StatusColors`, `PlayerColors`, `SyntaxTheme`: alt kategoriler.
- `Appearance::Light | Dark`: theme'in nominal görünüm modu.

`ThemeRegistry`:

- `ThemeRegistry::global(cx) -> Arc<Self>`: aktif registry.
- `ThemeRegistry::default_global(cx)` ve `try_global(cx)`: init/test kodunda
  registry erişimi.
- `registry.assets()`: bundled theme/icon asset source'u.
- `registry.list_names() -> Vec<SharedString>`: yüklü tema adları.
- `registry.list() -> Vec<ThemeMeta>`: tema adı ve appearance metadata'sı.
- `registry.get(name) -> Result<Arc<Theme>, ThemeNotFoundError>`.
- `registry.insert_theme_families(families)` veya `insert_themes(themes)`:
  tema ekleme.
- `registry.remove_user_themes(&names)`: verilen tema adlarını temizleme.
- `registry.list_icon_themes()`, `get_icon_theme(name)`,
  `default_icon_theme()`, `load_icon_theme(content, icons_root_dir)`,
  `remove_icon_themes(&names)`: icon theme yönetimi.
- `registry.extensions_loaded()` ve `set_extensions_loaded()`: extension
  temalarının yüklenip yüklenmediği bayrağı.

Aktif tema akışı:

```rust
let theme = cx.theme();        // &Arc<Theme>
let colors = theme.colors();   // &ThemeColors
let status = theme.status();   // &StatusColors
let players = theme.players(); // &PlayerColors
let syntax = theme.syntax();   // &SyntaxTheme
```

`cx.theme()` extension trait `theme::ActiveTheme` ile sağlanır; `App` üzerinde
çalışır. Aktif tema `ThemeSettings` içindeki seçimden ve `SystemAppearance`'tan
hesaplanır:

```rust
pub fn reload_theme(cx: &mut App) {
    let theme = configured_theme(cx);
    GlobalTheme::update_theme(cx, theme);
    cx.refresh_windows();
}
```

`reload_icon_theme(cx)` aynı modeli icon theme için uygular. `theme::init(...)`
registry, `SystemAppearance`, font family cache ve fallback `GlobalTheme`
kurar; `theme_settings::init(...)` bunun üzerine settings observer'larını ve
bundled/user theme yükleme akışını bağlar.

Tema ayar sağlayıcısı:

- `theme::set_theme_settings_provider(provider, cx)`: UI font, buffer font,
  font size ve UI density kaynağını global olarak bağlar.
- `theme::theme_settings(cx) -> &dyn ThemeSettingsProvider`: theme crate'inin
  concrete settings crate'ine bağımlı olmadan font/density okumasını sağlar.
- `UiDensity::{Compact, Default, Comfortable}` ve `spacing_ratio()` spacing
  ölçeğini verir; Zed tarafında provider implementasyonu `theme_settings`
  crate'indedir.

Custom tema yükleme:

```rust
theme_settings::load_user_theme(&ThemeRegistry::global(cx), bytes)?;
theme_settings::reload_theme(cx);
```

`load_user_theme` JSON'u `ThemeFamilyContent` olarak deserialize eder,
`refine_theme_family` ile gerçek `ThemeFamily` üretir ve
`insert_theme_families` çağırır. `crates/theme_importer/` VS Code temalarından
`theme_settings::ThemeContent` üretmek için yardımcılar içerir. Zed tarafında
`load_user_themes_in_background` ve watcher akışı dosya değişiminden sonra
`theme_settings::reload_theme(cx)` çağırır.

Tuzaklar:

- `cx.theme()` ilk frame'de fallback theme döndürebilir; observer ile
  `SystemAppearance` veya `SettingsStore` dinleyip rerender şarttır.
- `ThemeColors` tüm tokenları içerir; eksik token kullanıcı temada `null`
  bırakılırsa default light/dark theme'den fallback alınır.
- `Theme.styles.colors.background` yerine doğrudan `theme.colors().background`
  kullan; styles alanı internal layout'tur.


---

## Bölüm XX — Komut Paleti ve Picker

---

### 95. CommandPalette: Filter, Aliases ve Interceptor

`crates/command_palette_hooks/` global'leri komut paleti UX'ini şekillendirir.
UI'ı yazmadan önce bu global'leri tanımak gerekir, çünkü odaktaki elementten
toplanan action listesi, görünürlük filtresi ve alternatif komut sonuçları bu
katmandan geçer. Zed başlangıcında `command_palette::init(cx)`,
`command_palette_hooks::init(cx)` çağırır; filtre global'i bu çağrıyla kurulur.

#### CommandPaletteFilter

```rust
pub struct CommandPaletteFilter {
    hidden_namespaces: HashSet<&'static str>,
    hidden_action_types: HashSet<TypeId>,
    shown_action_types: HashSet<TypeId>,
}
```

Erişim:

- `CommandPaletteFilter::try_global(cx) -> Option<&Self>`
- `CommandPaletteFilter::global_mut(cx) -> &mut Self`
- `CommandPaletteFilter::update_global(cx, |filter, cx| ...)`

`update_global` global yoksa yeni global oluşturmaz; `cx.has_global` kontrolünden
sonra çalışır ve global yoksa no-op olur. Bu nedenle kendi test/app
kurulumunda command palette crate'ini kullanmadan yalnızca hook crate'ine
erişiyorsan önce `command_palette_hooks::init(cx)` çağırman gerekir.

Filtre yönetimi:

- `is_hidden(&action) -> bool`: belirli action namespace veya tip olarak gizliyse
  true. Komut paleti UI'ı bu sonuca göre gösterimi atlar. `shown_action_types`
  içinde olan tipler namespace gizli olsa bile görünür kalır.
- `hide_namespace(&'static str)` / `show_namespace(&'static str)`: bir namespace'in
  tüm action'larını gizle/göster (örn. headless paneller için).
- `hide_action_types(impl IntoIterator<Item = &TypeId>)` /
  `show_action_types(impl IntoIterator<Item = &TypeId>)`: belirli action tiplerini
  topluca yönetir. `hide_action_types` tipi `hidden_action_types` içine ekler ve
  `shown_action_types` içinden çıkarır; `show_action_types` bunun tersini yapar.

Tipik kullanım `CommandPaletteFilter::update_global(cx, |filter, _| { ... })`
içinde aynı anda hem `hide_namespace` hem `hide_action_types` çağırarak feature
flag tabanlı komut görünürlüğünü tek seferde değiştirmektir. Vim entegrasyonu
vim modu açıldığında `vim` namespace'ini gösterir ve modu kapatınca tekrar
gizler.

#### CommandAliases (WorkspaceSettings)

`WorkspaceSettings::command_aliases: HashMap<String, ActionName>`. Kullanıcı
JSON'una `"command_aliases": { "ag": "search::ToggleSearch" }` yazınca komut
paleti query tam olarak `ag` olduğunda sorguyu `search::ToggleSearch` string'ine
çevirir. Bu çeviri fuzzy eşleşme ve interceptor çağrısından önce yapılır; alias
bir action nesnesi üretmez, yalnızca palette sorgusunu canonical action adına
yaklaştırır. Yeni komut sunarken alias sözleşmesini bozmaktan kaçın; eski adları
keymap tarafında desteklemek için `#[action(deprecated_aliases = [...])]`, komut
paleti kullanıcı sorgusu içinse `command_aliases` kullanılır.

#### CommandInterceptor

Komut paletindeki "tam string'i komuta dönüştür" davranışı (örn. vim ex
komutları, line jump `:42`) `GlobalCommandPaletteInterceptor` üzerinden çalışır:

```rust
GlobalCommandPaletteInterceptor::set(cx, |query, workspace, cx| {
    parse_query_to_actions(query, workspace, cx)
});
```

İmzalar:

- `set(cx, Fn(&str, WeakEntity<Workspace>, &mut App) -> Task<CommandInterceptResult>)`
- `clear(cx)`: interceptor'ı kaldırır.
- `intercept(query, workspace, cx) -> Option<Task<CommandInterceptResult>>`:
  komut paleti UI'ı her tuş vuruşunda çağırır.

`CommandInterceptResult`:

```rust
pub struct CommandInterceptResult {
    pub results: Vec<CommandInterceptItem>,
    pub exclusive: bool, // true ise normal action eşleşmeleri gizlenir
}

pub struct CommandInterceptItem {
    pub action: Box<dyn Action>,
    pub string: String,             // palette'te gösterilecek metin
    pub positions: Vec<usize>,      // highlight pozisyonları
}
```

Tipik akış: vim modu açıkken `:w<CR>` gibi komutları intercept edip
`SaveActiveItem` action'ına çevirir; başka extension/agent tipi de aynı
mekanizmayı kullanır. Komut paleti, interceptor sonuçlarını normal fuzzy action
eşleşmeleriyle birleştirir. Aynı action zaten normal eşleşmelerde varsa
interceptor sonucu eklenmeden önce normal sonuçtan çıkarılır. `exclusive = true`
ise yalnızca interceptor sonuçları gösterilir; `exclusive = false` ise
interceptor sonuçları listenin başına eklenip normal eşleşmeler arkadan gelir.

#### Action Documentation ve Deprecation Mesajları

Action trait'inin `documentation()`, `deprecation_message()` ve
`deprecated_aliases()` yüzeyi command palette ile karıştırılmamalıdır:

- Komut paleti satırında şu anda humanized action adı ve mevcut keybinding
  gösterilir; action documentation/deprecation mesajı palette satırında ayrı
  bir açıklama olarak render edilmez.
- `#[action(deprecated_aliases = ["foo::OldName"])]` eski adı
  `ActionRegistry::build_action` içinde hala inşa edilebilir yapar ve keymap JSON
  schema/uyarı akışına yansır. Komut paleti ise `window.available_actions(cx)`
  ile odaktaki dispatch path'ten action tiplerini toplar ve
  `build_action_type(type_id)` ile canonical action adını üretir; eski alias'ı
  ayrı palette satırı olarak listelemez.
- Doc comment yazmak yine önemlidir: derive macro bunu `documentation()`'a
  çevirir ve keymap editor/JSON schema gibi action keşif yüzeyleri bu bilgiyi
  kullanır.
- `#[action(deprecated = "...")]` de keymap schema/uyarı akışını besler. Komut
  paleti kullanıcı sorgusuna eski kısa ad vermek istiyorsan
  `WorkspaceSettings::command_aliases` kullanmalısın.

#### Tuzaklar

- `CommandPaletteFilter` global state'tir; testlerde bir feature açıp kapatınca
  sonraki test başlamadan reset etmen gerekebilir.
- `hide_action_types` ile gizlenen tip register edilmiş olmalı; aksi halde
  filtreye eklendiği halde komut paleti listesinde zaten görünmez.
- `Interceptor::set` mevcut interceptor'ı ezer; çoklu kaynak gerekiyorsa zinciri
  kendi koduna kuracaksın (örn. önce vim, başarısızsa AI agent gibi).
- `CommandInterceptResult::exclusive = true` yoğunlukla kullanılırsa kullanıcı
  normal action listesinden komutlara ulaşamaz; gerçekten "tek doğru sonuç var"
  iken set et.

### 96. CommandPalette Runtime Akışı, Fuzzy Arama ve Geçmiş

`crates/command_palette/src/command_palette.rs` Zed'in gerçek komut paleti
akışıdır. Başlatma ve açma sırası:

1. `command_palette::init(cx)` hook global'lerini kurar ve
   `cx.observe_new(CommandPalette::register).detach()` ile her yeni
   `Workspace` için `zed_actions::command_palette::Toggle` action'ını register
   eder.
2. `CommandPalette::toggle(workspace, query, window, cx)` mevcut focus handle'ı
   alır. Focus yoksa palette açılmaz. Sonra `workspace.toggle_modal(...)` ile
   `CommandPalette` modal view olarak oluşturulur.
3. `CommandPalette::new(previous_focus_handle, query, workspace, window, cx)`
   `window.available_actions(cx)` çağırır. Bu liste bütün registry değil, odaktaki
   dispatch path üzerinde `.on_action(...)` ile bağlanmış action'lar ve global
   action listener'larıdır.
4. Her action `CommandPaletteFilter::is_hidden` ile elenir ve görünen action'lar
   `humanize_action_name(action.name())` sonucuyla `Command { name, action }`
   haline getirilir.
5. UI `Picker::uniform_list(delegate, window, cx)` ile kurulur, sonra başlangıç
   query'si `picker.set_query(query, window, cx)` ile editöre yazılır.

Arama akışı:

- `humanize_action_name("editor::GoToDefinition")` sonucu
  `"editor: go to definition"` olur; `go_to_line::Deploy` gibi snake case adlar
  boşluklu hale gelir.
- `normalize_action_query(input)` trim yapar, ardışık whitespace'i tek boşluğa
  indirir, `_` karakterlerini boşluğa çevirir ve ardışık `::` yazımlarını arama
  için sadeleştirir.
- `WorkspaceSettings::command_aliases` tam query eşleşmesini canonical action adı
  string'ine çevirir.
- Query Zed link ise (`parse_zed_link`) palette `OpenZedUrl { url }` action'ını
  interceptor sonucu gibi listeye ekler.
- Normal command listesi background executor üzerinde
  `fuzzy_nucleo::match_strings_async(..., Case::Smart, LengthPenalty::On, 10000,
  ...)` ile eşleşir. Eşleşmeler hit count'a göre, sonra alfabetik ada göre
  sıralanmış komut havuzundan gelir.
- Interceptor sonucu varsa `matches_updated` içinde normal eşleşmelerle
  birleştirilir; duplicate action'lar `Action::partial_eq` ile ayıklanır.

Geçmiş ve sıralama `CommandPaletteDB` içindedir:

- SQLite domain adı `CommandPaletteDB`; tablo `command_invocations`.
- `write_command_invocation(command_name, user_query)` çalıştırılan komutu ve
  kullanıcının yazdığı sorguyu kaydeder. Tablo 1000 kayıt üstüne çıktığında en
  eski kayıt silinir.
- `list_commands_used()` komut başına invocation sayısı ve son kullanım zamanını
  döndürür; palette açılırken hit count yüksek olan komutlar önce sıralanır.
- `list_recent_queries()` boş olmayan kullanıcı sorgularını son kullanım zamanına
  göre getirir; command palette yukarı/aşağı gezinirken aynı prefix ile query
  geçmişine dönebilir.

Onay davranışı:

- Normal confirm seçili command'i alır, telemetry'ye
  `source = "command palette"` ile yazar, `CommandPaletteDB` kaydını background
  task olarak başlatır, eski focus handle'a geri odaklanır, modalı dismiss eder
  ve `window.dispatch_action(action, cx)` çağırır.
- Secondary confirm seçili action'ın canonical adını `String` olarak alıp
  `zed_actions::ChangeKeybinding { action: action_name.to_string() }` action'ını
  dispatch eder. Buradaki `action` alanı action nesnesi değil, registry name
  string'idir (örn. `"editor::GoToDefinition"`); keymap editor bu string'i alır
  ve binding ekleme akışını başlatır. Footer'daki "Add/Change Keybinding" butonu
  da aynı yolu kullanır.
- `finalize_update_matches` pending background sonucu en fazla kısa bir süre
  foreground'da bekleyebilir; bu, palette açılırken boş liste parlamasını ve
  otomasyon sırasında erken enter basılmasını azaltır.

### 97. Picker, PickerDelegate ve PickerPopoverMenu

`crates/picker/` command palette dışında da kullanılan genel seçim/arama
bileşenidir. Bir picker yazarken ana iş `PickerDelegate` implementasyonudur:

```rust
pub trait PickerDelegate: Sized + 'static {
    type ListItem: IntoElement;

    fn match_count(&self) -> usize;
    fn selected_index(&self) -> usize;
    fn set_selected_index(&mut self, ix: usize, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn placeholder_text(&self, window: &mut Window, cx: &mut App) -> Arc<str>;
    fn update_matches(&mut self, query: String, window: &mut Window, cx: &mut Context<Picker<Self>>) -> Task<()>;
    fn confirm(&mut self, secondary: bool, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn dismissed(&mut self, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn render_match(&self, ix: usize, selected: bool, window: &mut Window, cx: &mut Context<Picker<Self>>) -> Option<Self::ListItem>;
}
```

Sık override edilen davranışlar:

- `select_history(Direction, query, ...) -> Option<String>`: yukarı/aşağı okları
  default seçim yerine query geçmişinde gezdirmek için.
- `can_select(ix, ...)`, `select_on_hover()`, `selected_index_changed(...)`:
  seçilebilir satırları ve hover/selection yan etkilerini yönetir.
- `no_matches_text(...)`, `render_header(...)`, `render_footer(...)`:
  boş durum ve sabit üst/alt alanlar.
- `documentation_aside(...)` ve `documentation_aside_index()`: seçili/hover edilen
  öğe için sağda dokümantasyon paneli göstermek.
- `confirm_update_query(...)`, `confirm_input(...)`, `confirm_completion(...)`:
  enter'ın seçimi onaylamak yerine query'yi dönüştürdüğü veya literal input'u
  action'a çevirdiği picker türleri.
- `editor_position() -> PickerEditorPosition::{Start, End}`: arama editörünün
  listenin üstünde mi altında mı duracağını belirler.
- `finalize_update_matches(query, duration, ...) -> bool`: background matching'i
  kısa süre bloklayarak ilk render/confirm yarışını azaltır.

Constructor seçimi:

- `Picker::uniform_list(delegate, window, cx)`: aramalı picker; tüm satırlar aynı
  yükseklikteyse tercih edilir ve `gpui::uniform_list` kullanır.
- `Picker::list(delegate, window, cx)`: aramalı picker; satır yükseklikleri
  değişkense kullanılır.
- `Picker::nonsearchable_uniform_list(...)` ve `Picker::nonsearchable_list(...)`:
  arama editörü olmayan seçim listeleri.

Kullanılabilir ayarlar:

- `width(...)`, `max_height(...)`, `widest_item(...)`: ölçü ve liste genişliği.
- `show_scrollbar(bool)`: dış scrollbar gösterimi.
- `modal(bool)`: picker kendi başına modal gibi render ediliyorsa elevation verir;
  daha büyük bir modalın parçasıysa `false` yapılabilir.
- `list_measure_all()`: `ListState` tabanlı listede tüm öğeleri ölçmek için.
- `refresh(&mut self, window, cx)`, `update_matches_with_options(...,
  ScrollBehavior)`: match akışını dışarıdan tetikleyen mutable yardımcılar.
- `query(&self, cx: &App) -> String`: editördeki anlık sorguyu okur.
- `set_query(&self, query: &str, window: &mut Window, cx: &mut App)`: editör
  metnini değiştirir; `&self` aldığına dikkat — picker entity'sini `update`
  bloğunun içine sokmak şart değil, doğrudan picker referansından çağrılabilir.
  `cx` burada `Context<...>` değil `&mut App` olduğu için entity context
  gerekiyorsa update bloğundan dışarı çıkmak gerekebilir.

Action/key context:

- Render root `"Picker"` key context'ini kurar.
- `menu::SelectNext`, `menu::SelectPrevious`, `menu::SelectFirst`,
  `menu::SelectLast`, `menu::Cancel`, `menu::Confirm`,
  `menu::SecondaryConfirm`, `picker::ConfirmCompletion` ve `picker::ConfirmInput`
  action'larını dinler.
- Click confirm sırasında `cx.stop_propagation()` ve `window.prevent_default()`
  çağrılır; bu yüzden picker satırına tıklama dış elementlere sızmaz.

`PickerPopoverMenu<T, TT, P>` bir picker'ı `ui::PopoverMenu` içine koyan ince
sarmaldır. `new(picker, trigger, tooltip, anchor, cx)` picker'ın
`DismissEvent`'ini popover dismiss event'ine bağlar; `with_handle(...)` ve
`offset(...)` ile dış popover handle/konum ayarı yapılır. Picker bir toolbar
butonu veya popover tetikleyicisi arkasında açılacaksa doğrudan modal yerine bu
sarmalı kullan.


---

## Bölüm XXI — Reçeteler ve Kontrol Listeleri

---

### 98. Reçeteler

#### Yeni Workspace Penceresi

1. `zed::build_window_options(display_uuid, cx)` kullan.
2. Root view olarak workspace/multi-workspace entity oluştur.
3. Titlebar için `TitleBar`/`PlatformTitleBar` yolunu izle.
4. Root content'i `workspace::client_side_decorations(...)` ile sar.
5. Close işlemi için `workspace::CloseWindow` action'ını dispatch et.

#### Küçük Dialog Penceresi

```rust
cx.open_window(
    WindowOptions {
        titlebar: Some(TitlebarOptions {
            title: Some("Dialog".into()),
            appears_transparent: true,
            traffic_light_position: Some(point(px(12.), px(12.))),
        }),
        window_bounds: Some(WindowBounds::centered(size(px(440.), px(300.)), cx)),
        is_resizable: false,
        is_minimizable: false,
        kind: WindowKind::Dialog,
        app_id: Some(ReleaseChannel::global(cx).app_id().to_owned()),
        ..Default::default()
    },
    |window, cx| {
        window.activate_window();
        cx.new(|cx| DialogView::new(window, cx))
    },
)?;
```

#### Transparent/Blurred Notification

```rust
WindowOptions {
    titlebar: None,
    focus: false,
    show: true,
    kind: WindowKind::PopUp,
    is_movable: false,
    is_resizable: false,
    window_background: WindowBackgroundAppearance::Transparent,
    window_decorations: Some(WindowDecorations::Client),
    ..Default::default()
}
```

Blur istersen `Transparent` yerine `Blurred` kullan; içerik root'unun tamamen opak
arka plan çizmediğinden emin ol.

#### Platforma Göre UI Ayırma

```rust
match PlatformStyle::platform() {
    PlatformStyle::Mac => { /* macOS */ }
    PlatformStyle::Linux => { /* Linux */ }
    PlatformStyle::Windows => { /* Windows */ }
}
```

Compile-time farklılık gerekiyorsa `cfg!(target_os = "...")` veya `#[cfg(...)]`
kullan. Runtime styling için `PlatformStyle` daha okunur.

#### Titlebar Drag ve Double Click

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
    .on_click(|event, window, _| {
        if event.click_count() == 2 {
            if cfg!(target_os = "macos") {
                window.titlebar_double_click();
            } else {
                window.zoom_window();
            }
        }
    })
```

Linux/macOS'ta elle drag başlatman gerekirse mouse move sırasında:

```rust
window.start_window_move();
```

Windows için `WindowControlArea::Drag` native hit-test tarafında daha doğru yoldur.

#### Client-Side Resize Handle

```rust
.on_mouse_down(MouseButton::Left, move |event, window, _| {
    if let Some(edge) = resize_edge(event.position, shadow, size, tiling) {
        window.start_window_resize(edge);
    }
})
```

Cursor'u da aynı edge'e göre `ResizeUpDown`, `ResizeLeftRight`,
`ResizeUpLeftDownRight`, `ResizeUpRightDownLeft` yap.

#### Tema Değişince Pencere Arka Planını Güncelleme

```rust
cx.observe_global::<SettingsStore>(move |cx| {
    for window in cx.windows() {
        let appearance = cx.theme().window_background_appearance();
        window.update(cx, |_, window, _| {
            window.set_background_appearance(appearance);
        }).ok();
    }
}).detach();
```

Zed ana uygulaması bu deseni zaten kullanır.

### 99. Sık Hatalar ve Doğru Desenler

- **İstenen decoration'a güvenme**: `WindowOptions.window_decorations` sadece istektir.
  Render sırasında `window.window_decorations()` sonucunu kullan.
- **Blur görünmüyor**: Root veya theme tamamen opak renk çiziyor olabilir. Transparent
  surface ve alfa gerekir.
- **Linux kontrol butonları yanlış tarafta**: `cx.button_layout()` ve
  `observe_button_layout_changed` kullanılmalı.
- **Windows caption butonları tıklanmıyor**: Buton elementlerinde
  `window_control_area(Close/Max/Min)` eksik olabilir.
- **Close davranışı bypass ediliyor**: Zed workspace penceresinde doğrudan
  `remove_window` yerine `workspace::CloseWindow` action'ını dispatch et.
- **Async task çalışırken yok oluyor**: Dönen `Task` saklanmamış veya detach edilmemiştir.
- **Entity leak**: Uzun yaşayan task/subscription içinde güçlü `Entity` yakalamak yerine
  `WeakEntity` kullan.
- **Render güncellenmiyor**: State değişiminden sonra `cx.notify()` unutulmuştur.
- **Focus callback'i fire etmiyor**: Element `.track_focus(&focus_handle)` ile ağaca
  bağlanmamış olabilir.
- **Custom titlebar altında içerik tıklanamıyor**: Drag/window control hitbox'ı fazla
  geniş olabilir veya `.occlude()` yanlış yerde olabilir.
- **Client decoration shadow boşluğu**: `set_client_inset` ve dış wrapper padding/shadow
  birlikte yönetilmelidir.

### 100. Yeni Pencere Eklerken Kontrol Listesi

1. Bu pencere workspace mi, modal mı, popup mı? `WindowKind` seç.
2. Ana Zed penceresiyse `build_window_options` kullan.
3. Bounds restore edilecek mi? `WindowBounds` persist et.
4. Hangi display'de açılacak? `display_id` veya `display_uuid` seç.
5. Titlebar native mi custom mı? `TitlebarOptions`/`PlatformTitleBar` kararını ver.
6. Linux decoration modu ayardan mı gelecek? `window_decorations` bağla.
7. Client decoration varsa wrapper, inset, resize handle ve tiling durumunu ekle.
8. Close action doğrudan pencereyi kapatmalı mı, yoksa workspace close flow mu?
9. Blur/transparent gerekiyorsa `window_background` ve root alpha uyumunu kontrol et.
10. Focus başlangıcı doğru mu? `focus`, `show`, `activate_window`, focus handle.
11. Minimum size gerekli mi?
12. App id ve Linux icon gerekiyor mu?
13. macOS native tabbing isteniyor mu? `tabbing_identifier`.
14. Settings/theme değişiminde arka plan güncellenecek mi?
15. Button layout değişiminde titlebar yeniden render olacak mı?
16. Testte timer gerekiyorsa GPUI executor timer kullanıldı mı?

### 101. Kısa Cevaplar

**İleride pencere oluşturmak için nasıl yapmalıyım?**

Workspace penceresi için `zed::build_window_options` ile başla. Özel küçük pencere
için doğrudan `cx.open_window(WindowOptions { ... }, |window, cx| cx.new(...))`
kullan. Root view `Render` implement eden bir `Entity` olmalı.

**Pencere dekorunu nasıl tanımlarım?**

Linux için `WindowOptions.window_decorations = Some(WindowDecorations::Client/Server)`.
Render tarafında fiili sonucu `window.window_decorations()` ile oku. Zed tarzı
client decoration için `workspace::client_side_decorations` kullan. macOS/Windows'ta
custom titlebar için `TitlebarOptions { appears_transparent: true }` veya
`titlebar: None` ve `PlatformTitleBar` kullan.

**Kontrol butonlarını nasıl yönetirim?**

Zed içinde `platform_title_bar::render_left_window_controls` ve
`render_right_window_controls` kullan. Linux'ta `cx.button_layout()` ve
`window.window_controls()` sonucu belirleyicidir. Windows'ta butonlar
`WindowControlArea::{Min, Max, Close}` ile native hit-test'e bağlanır. Close için
workspace akışında `CloseWindow` action dispatch et.

**Blur yönetimini işletim sistemine göre nasıl yaparım?**

Pencere açarken veya tema değişince `window.set_background_appearance(...)` kullan.
Zed tema akışı `opaque`, `transparent`, `blurred` destekler. macOS gerçek blur'u
`NSVisualEffectView`/legacy blur radius ile, Windows composition/DWM ile, Wayland
compositor blur protocol ile uygular. Destek yoksa `Blurred` transparan gibi
davranabilir. Root UI opak çiziyorsa blur görünmez.

**Platform farklarını nerede soyutlarım?**

Davranış platform penceresiyle ilgiliyse GPUI `Platform`/`PlatformWindow` katmanında.
Zed UI görünümüyle ilgiliyse `PlatformStyle::platform()` ve `platform_title_bar`
bileşenlerinde. Ayar farkı gerekiyorsa `settings_content` schema ve `settings`
dönüşümlerinde.

### 102. Dosya Yoluna Göre Ne Nerede?

- Pencere açma API'si: `crates/gpui/src/app.rs::open_window`
- Pencere seçenekleri: `crates/gpui/src/platform.rs::WindowOptions`
- Platform penceresi sözleşmesi: `crates/gpui/src/platform.rs::PlatformWindow`
- Pencere wrapper metotları: `crates/gpui/src/window.rs`
- Element ve render trait'leri: `crates/gpui/src/element.rs`, `view.rs`
- Style fluent API: `crates/gpui/src/styled.rs`
- Interactivity fluent API: `crates/gpui/src/elements/div.rs`
- Platform seçimi: `crates/gpui_platform/src/gpui_platform.rs`
- macOS pencere davranışı: `crates/gpui_macos/src/window.rs`
- Windows pencere davranışı: `crates/gpui_windows/src/window.rs`, `events.rs`
- Linux Wayland davranışı: `crates/gpui_linux/src/linux/wayland/window.rs`
- Linux X11 davranışı: `crates/gpui_linux/src/linux/x11/window.rs`
- Zed ana window options: `crates/zed/src/zed.rs::build_window_options`
- Zed platform titlebar: `crates/platform_title_bar/src/platform_title_bar.rs`
- Linux controls: `crates/platform_title_bar/src/platforms/platform_linux.rs`
- Windows controls: `crates/platform_title_bar/src/platforms/platform_windows.rs`
- Workspace client decoration: `crates/workspace/src/workspace.rs::client_side_decorations`
- Zed titlebar composition: `crates/title_bar/src/title_bar.rs`
- Theme background appearance: `crates/theme/src/theme.rs`,
  `crates/theme_settings/src/theme_settings.rs`,
  `crates/settings/src/content_into_gpui.rs`
- UI component export list: `crates/ui/src/components.rs`
- UI input: `crates/ui_input/src/ui_input.rs`, `input_field.rs`
