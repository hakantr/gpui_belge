# 2. Uygulama ve Platform

---

## 2.1. Platform Başlatma

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

## 2.2. Application Yaşam Döngüsü ve Platform Olayları

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

## 2.3. Platform Servisleri

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

## 2.4. Platform Trait Implementasyonu ve Wrapper Sınırları

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

## 2.5. Headless, Screen Capture ve Test Renderer

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

