# Uygulama ve Platform

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Platform` | Trait üyeleri 1 | `activate`, `active_window`, `add_recent_document`, `app_path`, `background_executor`, `button_layout`, `can_select_mixed_files_and_dirs`, `compositor_name`, `delete_credentials`, `displays`, `foreground_executor`, `get_menus`, `hide`, `hide_other_apps` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `Platform` | Trait üyeleri 2 | `is_cursor_visible`, `is_screen_capture_supported`, `keyboard_layout`, `keyboard_mapper`, `on_app_menu_action`, `on_keyboard_layout_change`, `on_open_urls`, `on_quit`, `on_reopen`, `on_thermal_state_change`, `on_validate_app_menu_command`, `on_will_open_app_menu`, `open_url`, `open_window` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `Platform` | Trait üyeleri 3 | `open_with_system`, `path_for_auxiliary_executable`, `perform_dock_menu_action`, `primary_display`, `prompt_for_new_path`, `prompt_for_paths`, `quit`, `read_credentials`, `read_from_clipboard`, `read_from_find_pasteboard`, `register_url_scheme`, `restart`, `reveal_path`, `run` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `Platform` | Trait üyeleri 4 | `screen_capture_sources`, `set_cursor_style`, `set_dock_menu`, `set_menus`, `should_auto_hide_scrollbars`, `thermal_state`, `unhide_other_apps`, `update_jump_list`, `window_appearance`, `window_stack`, `write_credentials`, `write_to_clipboard`, `write_to_find_pasteboard` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


---

## İçindekiler
- [Platform Başlatma](#platform-başlatma)
- [Application Yaşam Döngüsü ve Platform Olayları](#application-yaşam-döngüsü-ve-platform-olayları)
- [Platform Servisleri](#platform-servisleri)
- [Platform Trait Uygulaması ve Sarmalayıcı Sınırları](#platform-trait-uygulaması-ve-sarmalayıcı-sınırları)
- [Başsız Çalışma, Ekran Yakalama ve Test Çizim Aracı](#başsız-çalışma-ekran-yakalama-ve-test-çizim-aracı)

---

## Platform Başlatma

Bir GPUI uygulamasının ilk adımı platform seçimidir. Platform, işletim sistemiyle konuşan tarafı temsil eder. Pencere açmak, klavye okumak ve ekrana çizmek gibi işler bu seçilen platform üzerinden yürür. Standart başlangıç şu kalıbı izler:

```rust
use gpui::{App, AppContext as _, WindowOptions, div, prelude::*};
use gpui_platform::application;

struct KokGorunum;

impl Render for KokGorunum {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div().size_full().child("Merhaba")
    }
}

fn main() {
    application().run(|cx: &mut App| {
        if let Err(hata) = cx.open_window(WindowOptions::default(), |_, cx| {
            cx.new(|_| KokGorunum)
        }) {
            eprintln!("pencere açılamadı: {hata:?}");
        }
    });
}
```

`application()` çağrısı çalıştığı işletim sistemine göre doğru platform uygulamasını otomatik döndürür. Zed'deki seçim kabaca şöyle:

![GPUI Platform Seçim Akışı](assets/platform-secim-akisi.svg)

- macOS: `gpui_macos::MacPlatform::new(headless)`
- Windows: `gpui_windows::WindowsPlatform::new(headless)`
- Linux/FreeBSD: `gpui_linux::current_platform(headless)`; Wayland veya X11 arka ucunu platform crate'i kendi içinde seçer.
- Web/WASM: `gpui_web::WebPlatform`

Görsel olmayan senaryolar için ayrı bir başlatıcı vardır: `gpui_platform::headless()`, test ve başsız (`headless`) çalıştırma için pencere açmayan bir platform üretir. Test desteği gerektiğinde `gpui_platform::current_headless_renderer()` çağırırsın; şu anda yalnızca macOS'ta Metal başsız çizim aracı döner, diğer hedeflerde `None` gelir.

## Application Yaşam Döngüsü ve Platform Olayları

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Application` | Metotlar | `new_inaccessible` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


`Application`, GPUI çalışmaya başlamadan önce kullandığın builder katmanıdır. Asset kaynağı, HTTP istemcisi ve çıkış politikası gibi süreç ömrü boyunca geçerli ayarları burada kurarsın. Tipik kurulum şöyle:

```rust
let uygulama = gpui_platform::application()
    .with_assets(Varliklar)
    .with_http_client(http_istemcisi)
    .with_quit_mode(QuitMode::Default);

uygulama.on_open_urls(|urller| {
    // Platform URL açma olayı.
});

uygulama.on_reopen(|cx| {
    cx.activate(true);
});

uygulama.run(|cx| {
    // Genel kurulum, keymap, pencereler.
});
```

`run` çağrısı, kontrolü platformun olay döngüsüne devreder. Bu noktadan sonra uygulama olay tabanlı çalışır.

**Çıkış ve etkinleştirme.** Uygulamanın hangi durumda çıkacağını `QuitMode` ile ayarlarsın:

- `QuitMode::Default`: macOS'ta yalnızca açık bir çıkış isteğiyle sonlanır; diğer platformlarda ise son pencere kapandığında GPUI otomatik çıkış yapar.
- `QuitMode::LastWindowClosed`: son pencere kapanır kapanmaz uygulama biter.
- `QuitMode::Explicit`: çıkış yalnızca `App::quit()` çağrılınca olur.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `QuitMode` | `Default`, `LastWindowClosed`, `Explicit` | Uygulamanın son pencere kapandığında mı yoksa açık quit isteğiyle mi sonlanacağını belirler. |
| `CursorHideMode` | platform cursor gizleme politikası | Yazma/fare/action etkileşimlerinden sonra imlecin ne zaman görünür kalacağını App seviyesinde ayarlar. |
- `cx.on_app_quit(|cx| async { ... })` ile kaydettiğin tüm geri çağrıları GPUI, uygulama tamamen sonlanmadan önce çalıştırır. Bu geri çağrılar için ayrılan süreyi `gpui::SHUTDOWN_TIMEOUT: Duration = 100ms` (`app.rs:71`) sabiti belirler; bu eşik aşılırsa hâlâ bekleyen `future`'lar iptal olur ve GPUI platform çıkışını sürdürür. Bu yüzden uzun kapanış işlerini bağımsız bırakılan bir `Task`'e değil, bir yaşam döngüsü gözlemcisine bağla.
- `cx.activate(ignoring_other_apps)`, `cx.hide()`, `cx.hide_other_apps()`, `cx.unhide_other_apps()` platform genelindeki uygulama durumunu değiştirir.
- `window.activate_window()`, `window.minimize_window()`, `window.toggle_fullscreen()` ise pencere seviyesindeki kontrolleri verir.

**Platform sinyalleri.** Uygulama, işletim sisteminden gelen olayları çeşitli kanallarla dinleyebilir:

- `cx.on_keyboard_layout_change(...)` — klavye düzeni değiştiğinde tetiklenir.
- `cx.keyboard_layout()` ve `cx.keyboard_mapper()` — keystroke'ları action'lara eşlemek için gerekli verileri sağlar.
- `cx.thermal_state()` ve `cx.on_thermal_state_change(...)` — yoğun çizim, dizinleme veya arka plan işlerinde kısıtlama (`throttling`) kararı verirken kullanırsın.
- `cx.set_cursor_hide_mode(CursorHideMode::...)` — yazım veya action sonrasında imleci gizleme politikasını ayarlar.
- `cx.refresh_windows()` — tüm pencereleri tek bir etki döngüsü (`effect cycle`) içinde yeniden çizmeye zorlar.
- `cx.set_quit_mode(mode)` — çıkış politikasını çalışma zamanında değiştirir; builder tarafındaki `.with_quit_mode(...)` ile aynı alanı besler.
- `cx.on_window_closed(|cx, window_id| ...)` — pencere kapandıktan *sonra* çalışır; bu noktada pencereye artık erişemezsin, geri çağrı yalnızca `WindowId` alır.

**Tuzaklar.** Bu API'lerde sık görülen birkaç yanlış anlama var:

- `on_open_urls` geri çağrısı `&mut App` almaz; uygulama verisi gerekiyorsa URL'leri kendi kuyruğuna veya bir `Global`'e taşıyacak bir köprü kurman gerekir.
- `on_reopen` özellikle macOS'ta Dock veya uygulama ikonuna tıklamayla yeniden açılma senaryosunda devreye girer; açık pencere yoksa yeni bir çalışma alanı açma mantığını burada tetiklersin.
- `refresh_windows()` veriyi değiştirmez; yalnızca yeniden çizim etkisini planlar.

## Platform Servisleri

`App` üzerinden ulaştığın platform servisleri uygulamanın dış dünyaya açılan kapılarıdır. Pencere yönetimi, panoya yazma, kimlik bilgileri, URL açma ve ekran yakalama buradan ilerler. Sarmalayıcılar (`wrapper`'lar) `crates/gpui/src/app.rs` içinde tanımlıdır; asıl davranış platforma özgü `Platform` trait uygulamasında yaşar. Aşağıdaki gruplama, hangi işin nereden çağrılacağını hızlıca bulmak içindir.

- **Uygulama yaşam döngüsü:** `quit`, `restart`, `set_restart_path`, `on_app_quit(|cx| async ...)`, `on_app_restart(|cx| ...)`, `activate`, `hide`, `hide_other_apps`, `unhide_other_apps`.
- **Pencereler:** `windows`, `active_window`, `window_stack`, `refresh_windows`.
- **Ekran:** `displays`, `primary_display`, `find_display`.
- **Görünüm:** `window_appearance`, `button_layout`, `should_auto_hide_scrollbars`, `set_cursor_hide_mode`.
- **Pano:** `read_from_clipboard`, `write_to_clipboard`.
- **Linux primary selection:** `read_from_primary`, `write_to_primary` — X11 ve Wayland'da orta tıklamayla yapıştırma için ayrı bir pano vardır; bu çift o panoyu hedefler.
- **macOS find pasteboard:** `read_from_find_pasteboard`, `write_to_find_pasteboard` — macOS'taki uygulama geneli "son aranan metin" panosunu yönetir.
- **Keychain ve kimlik bilgisi deposu:** `write_credentials(url, username, password)`, `read_credentials(url) -> Task<Result<Option<(String, Vec<u8>)>>>`, `delete_credentials(url)`. Geri dönen `Task`, arka plan çalıştırıcısında çalışır; bunu `await` edebilirsin veya `detach_and_log_err(cx)` ile bırakabilirsin.
- **URL:** `open_url`, `register_url_scheme`.
- **Dosya ve prompt:** `prompt_for_paths`, `prompt_for_new_path`, `reveal_path`, `open_with_system`, `can_select_mixed_files_and_dirs`.
- **Menü:** `set_menus`, `get_menus`, `set_dock_menu`, `add_recent_document`, `update_jump_list`.
- **Termal durum:** `thermal_state`, `on_thermal_state_change`.
- **İmleç görünürlüğü:** `cursor_hide_mode`, `set_cursor_hide_mode`, `is_cursor_visible`. İşaretçinin görsel stilini, pencere veya hitbox bağlamında `window.set_cursor_style(style, &hitbox)` ile, sürükleme sırasında ise `cx.set_active_drag_cursor_style(...)` ile belirlersin.
- **Ekran yakalama:** `is_screen_capture_supported`, `screen_capture_sources`.
- **Klavye:** `keyboard_layout()`, `keyboard_mapper()`, `on_keyboard_layout_change(|cx| ...)`.
- **HTTP istemcisi:** `http_client() -> Arc<dyn HttpClient>`, `set_http_client(Arc<dyn HttpClient>)`. `Application::with_http_client(...)` ile başlangıçta da ayarlayabilirsin; tipik olarak `crates/http_client` içindeki Zed varsayılanı tercih edilir.
- **Uygulama yolu ve compositor:** `app_path() -> Result<PathBuf>` (macOS bundle yolu ya da Linux'ta çalıştırılabilir dosya), `path_for_auxiliary_executable(name)` (yardımcı çalıştırılabilirler için bundle araması), `compositor_name() -> &'static str` (Linux'ta `wayland`, `x11`, `xwayland` gibi adlar; diğer platformlarda boş metin).

`Window` üzerinden gelen pencereye özgü kontroller ise şunlardır:

- `window.on_window_should_close(cx, |window, cx| -> bool)` — kullanıcı kapatma butonuna bastığında çalışır; `false` döndürmek kapanışı iptal eder.
- `window.appearance()`, `window.observe_window_appearance(...)` — pencere görünüm modunu (light/dark vb.) okur ve değişimini dinler.
- `window.tabbed_windows()`, `window.set_tabbing_identifier(...)` ve diğer yerel pencere sekmesi API'leri ("Yerel Pencere Sekmeleri ve SystemWindowTabController" bölümüne bakın).

Yeni bir platform uyarlaması (`port`) veya test arka ucu yazdığında bu sözleşmelerin tamamını karşılaman gerekir. Normal uygulama geliştirirken ise trait'lerin kendisine değil, `App` ve `Window` sarmalayıcılarına dokunmayı tercih edersin. Böylece platform farklarını sarmalayıcı katmanı üstlenir.

## Platform Trait Uygulaması ve Sarmalayıcı Sınırları

Uygulama kodu `Platform` veya `PlatformWindow` trait'lerini doğrudan çağırmaz; akış `App` ve `Window` sarmalayıcıları üzerinden ilerler. Trait sözleşmesini bilmek en çok yeni bir platform uyarlaması, test platformu veya başsız arka uç yazarken gerekir. Aşağıdaki listeler trait'lerin hangi büyük yetenek gruplarına ayrıldığını gösterir.

`Platform` ana grupları:

- **Çalıştırıcı ve metin:** `background_executor`, `foreground_executor`, `text_system` — görev çalıştırıcılar ve metin sistemi platforma bağlı kaynaklardır.
- **Uygulama yaşam döngüsü:** `run`, `quit`, `restart`, `activate`, `hide`, `hide_other_apps`, `unhide_other_apps`, `on_quit`, `on_reopen`.
- **Ekran ve pencere:** `displays`, `primary_display`, `active_window`, `window_stack`, `open_window`.
- **Görünüm ve UI politikası:** `window_appearance`, `button_layout`, `should_auto_hide_scrollbars`, imleç görünürlüğü ve stili.
- **URL, yol ve prompt:** `open_url`, `on_open_urls`, `register_url_scheme`, `prompt_for_paths`, `prompt_for_new_path`, `reveal_path`, `open_with_system`.
- **Menüler:** `set_menus`, `get_menus`, `set_dock_menu`, `on_app_menu_action`, `on_will_open_app_menu`, `on_validate_app_menu_command`.
- **Pano ve kimlik bilgisi:** normal pano, Linux primary selection, macOS find pasteboard ve kimlik bilgisi deposu görevleri.
- **Ekran yakalama ve klavye:** `is_screen_capture_supported`, `screen_capture_sources`, `keyboard_layout`, `keyboard_mapper`, `on_keyboard_layout_change`.

`PlatformWindow` ana grupları:

- **Sınırlar ve durum:** `bounds`, `window_bounds`, `content_size`, `resize`, `scale_factor`, `display`, `appearance`, `modifiers`, `capslock`.
- **Girdi:** `set_input_handler`, `take_input_handler`, `on_input`, `update_ime_position` — IME desteği ve klavye girişi bu metotlardan geçer.
- **Pencere yaşam döngüsü:** `activate`, `is_active`, `is_hovered`, `minimize`, `zoom`, `toggle_fullscreen`, `on_should_close`, `on_close`.
- **Çizim:** `on_request_frame`, `draw(scene)`, `completed_frame`, `sprite_atlas`, `is_subpixel_rendering_supported`.
- **Süsleme ve çarpışma testi:** `set_title`, `set_background_appearance`, `on_hit_test_window_control`, `request_decorations`, `window_decorations`, `window_controls`.
- **Platforma özel:** macOS sekme ve belge API'leri, Linux taşıma, yeniden boyutlandırma, menü, `app-id` ve `inset` desteği, Windows ham handle, yalnızca test için `render_to_image`.

**Sarmalayıcı sınırı.** Trait ve sarmalayıcı arasındaki en kritik ayrımlar şu:

- `Platform::set_cursor_style`, genel platform imlecini ayarlar; uygulama UI'ında hitbox'a bağlı stil gerekiyorsa `Window::set_cursor_style` tercih edilir.
- `PlatformWindow::prompt`, yerel bir prompt döndürebilir; `Window::prompt` ise gerektiğinde özel prompt yedeğini de yönetir.
- `PlatformWindow::map_window`, Linux'ta `map` ve `show` ayrımı için vardır; uygulama kodunda doğrudan çağırmazsın, `WindowOptions.show` ve pencere sarmalayıcısının davranışı bu işi karşılar.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `PlatformWindow` | pencere yaşam döngüsü, bounds, prompt, clipboard/input, accessibility, render/test hook'ları | İşletim sistemi pencere arka ucunun ana trait'idir; uygulama kodu `Window` sarmalayıcısını kullanır. |
| `ScreenCaptureSource`, `ScreenCaptureStream`, `ScreenCaptureFrame` | `metadata`, `stream`, frame callback payload | Platform ekran yakalama kaynaklarını ve akan kareleri temsil eder. |
| `ElementInputHandler`, `EntityInputHandler` | input handler bağlayıcıları | Platform input kararlarını view/entity `InputHandler` uygulamasına taşır. |
- Trait üzerinde varsayılan metot "desteklenmiyor" anlamına gelir; sarmalayıcı üzerinden dönen `None` veya işlem yapmayan (`no-op`) sonuçları, o platformun yeteneksizliği olarak değerlendirirsin.

## Platform Taşıyıcıları ve Port Sınırı

GPUI'nın platform modülünde görünen bazı public tipler uygulama geliştiricisinin doğrudan çağıracağı API değil, yeni platform arka ucu veya başsız renderer yazarken karşılayacağı sözleşmedir. Bunları rehberde tutmanın amacı, "hangi işi `App`/`Window` ile yaparım, hangi işi platform implementasyonu üstlenir?" ayrımını netleştirmektir.

**Display ve sistem sinyalleri.** `PlatformDisplay`, `DisplayId`, `SourceMetadata`, `ThermalState`, `RequestFrameOptions` ve `PlatformHeadlessRenderer` platformun ekran, ısı durumu, frame isteği ve başsız çizim sınırını tanımlar. Uygulama kodunda bunlara genellikle `cx.displays()`, `cx.primary_display()`, `cx.find_display(id)`, `cx.thermal_state()`, `cx.on_thermal_state_change(...)`, `cx.is_screen_capture_supported()` ve `cx.screen_capture_sources()` üzerinden erişirsin. Yeni bir platform yazmıyorsan `PlatformDisplay` trait'ini implement etmeye veya `RequestFrameOptions` üretmeye çalışmazsın.

**Metin, input ve atlas sınırı.** `PlatformTextSystem`, `NoopTextSystem`, `PlatformInputHandler`, `PlatformAtlas`, `AtlasKey`, `AtlasTextureList`, `AtlasTile`, `AtlasTextureId`, `AtlasTextureKind` ve `TileId` renderer ile platformun alt sözleşmeleridir. Metin tarafında uygulama akışı `App::text_system()`, `Window::text_system()`, `Window::line_height()` ve `StyledText` üzerindedir; girdi tarafında `EntityInputHandler`, `ElementInputHandler` ve element listener'ları kullanılır; görsel atlas tarafında ise normal yol `img(...)`, `svg()`, `window.paint_image(...)` ve `window.paint_svg(...)`'dır. Bu düşük seviyeli taşıyıcıları doğrudan kullanmak, atlas temizliği ve platform kaynak ömrünü de sana yükler.

**Çalıştırıcı ve platform dispatcher.** `PlatformDispatcher`, `RunnableMeta`, `RunnableVariant` ve `TimerResolutionGuard` task scheduling ile platform event loop'u arasında kalır. Uygulama kodunda bunların karşılığı `cx.background_executor()`, `cx.foreground_executor()`, `cx.spawn(...)`, `Task` ve testlerde `run_until_parked()` yardımcılarıdır. `RunnableMeta` kaynak konumu bilgisini taşır; profiler ve debug tooling bunu kullanır. Normal bir uygulama özelliği için bu tipleri state modeline koymazsın.

**Platform yardımcı fonksiyonları.** `guess_compositor()` Linux/Wayland/X11 arka ucunun compositor adını tahmin eden düşük seviye yardımcıdır; uygulama tarafında `cx.compositor_name()` daha doğru seviyedir. `get_gamma_correction_ratios(gamma)` glif/atlas gamma düzeltmesi içindir; tema rengi, kontrast veya tasarım paleti seçimi için kullanılmaz. Ekran yakalama tarafındaki `scap_screen_sources(...)`, `scap` arka ucunu `ScreenCaptureSource` sözleşmesine uyarlar; kullanıcıya dönük akışta `cx.screen_capture_sources()` sarmalayıcısını tercih edersin.

**Doğru tercih.** Platform tipleriyle karşılaştığında şu karar çizgisi iş görür: uygulama penceresi açıyor, menü kuruyor, prompt gösteriyor veya asset çiziyorsan `App`, `Window` ve element API'lerini kullanırsın. Yeni işletim sistemi arka ucu, test platformu, headless renderer veya GPU atlas entegrasyonu yazıyorsan `Platform`, `PlatformWindow`, `PlatformTextSystem`, `PlatformInputHandler`, `PlatformAtlas` ve ilgili taşıyıcıları implement edersin.

## Başsız Çalışma, Ekran Yakalama ve Test Çizim Aracı

Görsel arayüz olmadan da bir GPUI uygulamasını başlatabilirsin. Bu yol özellikle CLI alt komutları, toplu işler, sunucu süreçleri ve başarım ölçüm (`benchmark`) senaryolarında işine yarar. İlgili modüller `crates/gpui/src/platform.rs::screen_capture_sources` ve `crates/gpui_platform/src/gpui_platform.rs::headless()` içinde yer alır.

Başsız bir uygulamayı şu biçimde başlatırsın:

```rust
gpui_platform::headless().run(|cx: &mut App| {
    // Arka plan görevleri, asset yükleme, ağ IO; çizim yok.
});
```

Bu yapı pencere açmaz; o yüzden görsel doğrulama veya ekran görüntüsü (`screenshot`) üretimi için uygun değildir. UI testi gerektiğinde `gpui_platform::headless` yerine `HeadlessAppContext` veya `VisualTestContext` tercih edersin. `gpui_platform::current_headless_renderer()` ise yalnızca `test-support` özelliği (`feature`) altında derlenir; şu anda macOS'ta Metal başsız çizim aracı döndürebilir, diğer platformlarda `None` döner.

**Ekran yakalama API'si.** Ekran yakalama akışını GPUI `oneshot` kanallar üzerinde kurar ve ekran karelerini bir geri çağrıya iletir:

```rust
let destekleniyor_mu = cx.update(|cx| cx.is_screen_capture_supported());

let kaynak_alici = cx.update(|cx| cx.screen_capture_sources());
let kaynaklar = kaynak_alici.await??;
if let Some(kaynak) = kaynaklar.first() {
    let akis_alici = kaynak.stream(
        cx.foreground_executor(),
        Box::new(|kare| {
            // kare: ScreenCaptureFrame
        }),
    );
    let akis = akis_alici.await??;
    let ust_veri = akis.metadata()?;
}
```

`ScreenCaptureSource`, her platformda farklı bir kaynak listesi sunar (ekran, pencere, alan gibi). Yakalama `ScreenCaptureSource::stream(&ForegroundExecutor, frame_callback)` ile başlar. Geri dönen `oneshot::Receiver<Result<Box<dyn ScreenCaptureStream>>>`, akış handle'ını taşır; ekran karelerini ise GPUI geri çağrına `ScreenCaptureFrame` olarak iletir.

Linux/Windows tarafındaki `screen-capture` özelliği açıkken `gpui::platform::scap_screen_capture` modülü, `scap` arka ucunu `ScreenCaptureSource` ve `ScreenCaptureStream` trait'lerine uyarlar. Uygulama kodu çoğunlukla bu modüle inmez; özellik/platform ayrımını `cx.is_screen_capture_supported()` ve `cx.screen_capture_sources()` sarmalayıcıları üzerinden yönetirsin.

**Tuzaklar.** Ekran yakalama ve başsız çalışma tarafında dikkat edilecek birkaç nokta var:

- macOS'ta `Screen Recording` izni kullanıcı onayı gerektirir; ilk çağrıda sistem bir izin penceresi açar, onaydan sonra ileriki çalıştırmalarda da izin geçerli kalır.
- Bazı platformlarda ekran yakalama desteklenmez; `is_screen_capture_supported()` `false` dönebilir veya kaynak listesi boş gelebilir. Bu durumu uygulama tarafında kullanıcıya açıklayıcı bir mesajla ele alman gerekir.
- UI testlerinde gerçek bir platform penceresi açmak yerine `TestAppContext`, `VisualTestContext` veya çizim aracı fabrikası verilen `HeadlessAppContext` tercih edersin; böylece testler CI ortamlarında ekran olmadan da çalışır.

---

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `QuitMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Default`, `Explicit`, `LastWindowClosed` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CursorHideMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Never`, `OnTyping`, `OnTypingAndAction` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `EntityInputHandler`

| Grup | API | Not |
|---|---|---|
| Trait metotları 1 | `accepts_text_input`, `bounds_for_range`, `character_index_for_point`, `marked_text_range`, `replace_and_mark_text_in_range`, `replace_text_in_range`, `selected_text_range`, `text_for_range` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 2 | `unmark_text` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `ElementInputHandler`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `ScreenCaptureSource`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `metadata`, `stream` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `ScreenCaptureStream`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `metadata` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `ScreenCaptureFrame`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PlatformWindow`

| Grup | API | Not |
|---|---|---|
| Trait metotları 1 | `a11y_init`, `a11y_tree_update`, `a11y_update_window_bounds`, `activate`, `appearance`, `background_appearance`, `bounds`, `capslock` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 2 | `completed_frame`, `content_size`, `display`, `draw`, `get_title`, `gpu_specs`, `inner_window_bounds`, `is_active` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 3 | `is_fullscreen`, `is_hovered`, `is_maximized`, `is_subpixel_rendering_supported`, `map_window`, `merge_all_windows`, `minimize`, `modifiers` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 4 | `mouse_position`, `move_tab_to_new_window`, `on_active_status_change`, `on_appearance_changed`, `on_button_layout_changed`, `on_close`, `on_hit_test_window_control`, `on_hover_status_change` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 5 | `on_input`, `on_merge_all_windows`, `on_move_tab_to_new_window`, `on_moved`, `on_request_frame`, `on_resize`, `on_select_next_tab`, `on_select_previous_tab` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 6 | `on_should_close`, `on_toggle_tab_bar`, `play_system_bell`, `prompt`, `request_decorations`, `resize`, `scale_factor`, `set_app_id` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 7 | `set_background_appearance`, `set_client_inset`, `set_document_path`, `set_edited`, `set_input_handler`, `set_tabbing_identifier`, `set_title`, `set_traffic_light_position` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 8 | `show_character_palette`, `show_window_menu`, `sprite_atlas`, `start_window_move`, `start_window_resize`, `tab_bar_visible`, `tabbed_windows`, `take_input_handler` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 9 | `titlebar_double_click`, `toggle_fullscreen`, `toggle_window_tab_overview`, `update_ime_position`, `window_bounds`, `window_controls`, `window_decorations`, `zoom` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `InputHandler`

| Grup | API | Not |
|---|---|---|
| Trait metotları 1 | `accepts_text_input`, `apple_press_and_hold_enabled`, `bounds_for_range`, `character_index_for_point`, `marked_text_range`, `prefers_ime_for_printable_keys`, `replace_and_mark_text_in_range`, `replace_text_in_range` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 2 | `selected_text_range`, `text_for_range`, `unmark_text` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

<!-- phase14-api-anchor:end -->
