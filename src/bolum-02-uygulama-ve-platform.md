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
        div().size_full().child("Merhaba")
    }
}

fn main() {
    application().run(|cx: &mut App| {
        if let Err(error) = cx.open_window(WindowOptions::default(), |_, cx| cx.new(|_| Root)) {
            eprintln!("pencere açılamadı: {error:?}");
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
    // Platformun URL açma olayı.
});

app.on_reopen(|cx| {
    cx.activate(true);
});

app.run(|cx| {
    // Global state başlatma, keymap kaydı, pencere açma.
});
```

### Çıkış davranışı (QuitMode) ve uygulama aktivasyonu

**QuitMode** uygulamanın ne zaman kapanacağına karar veren politikadır. Üç değeri var:

- `QuitMode::Default`: macOS'ta tipik macOS davranışıdır; son pencere kapansa bile uygulama Dock'ta çalışmaya devam eder ve kapanmak için Cmd+Q ya da menüden Quit gerekir. Windows/Linux gibi diğer platformlarda son pencere kapanınca uygulama da kapanır.
- `QuitMode::LastWindowClosed`: Hangi platform olursa olsun son pencere kapandığı an uygulama otomatik kapanır.
- `QuitMode::Explicit`: Hiçbir pencere kalmasa bile uygulama açık kalır; yalnızca `cx.quit()` çağrılınca kapanır. Sistem tepsisi (tray) uygulamaları, arka plan servisleri için uygundur.

Mod, uygulama başlatılırken `application().with_quit_mode(...)` ile builder üzerinde belirlenir. Çalışma zamanında değiştirmek için `cx.set_quit_mode(mode)` kullanılır; builder ve runtime API'leri aynı alana yazdığı için, örneğin kullanıcı ayarlardan "uygulama arka planda kalsın" seçeneğini açıp kapattığında mod canlı olarak güncellenebilir.

**Kapanış akışı.** Çıkış kararı verildiği anda `cx.on_app_quit(|cx| async { ... })` ile kayıtlı tüm callback'ler paralel başlar. GPUI bunların tamamlanmasını `SHUTDOWN_TIMEOUT = 100ms` (`app.rs:71`) süresince bekler; eşik aşılırsa bekleyen future'lar iptal edilir ve platform exit'i devam eder. Bu yüzden uzun süren teardown işleri (büyük dosya flush, ağ kapatma vs.) fire-and-forget bırakılmaz; ya kısa tutulur ya da state daha önceden güvenli bir noktada kaydedilir.

**Aktivasyon (`cx.activate`)**, uygulamayı ön plana getirmek demektir. macOS'ta Dock'tan tıklanınca, Windows'ta görev çubuğundan seçilince OS bunu zaten otomatik tetikler. Programatik olarak öne getirmek için `cx.activate(ignoring_other_apps: bool)` çağrılır (örn. derin link ile dosya açıldığında pencere aktif edilir). `true` parametresi macOS'ta diğer uygulamaları zorla arkaya iter; günlük kullanımda `false` daha kibar bir aktivasyondur.

İlgili komutlar:

- `cx.hide()`, `cx.hide_other_apps()`, `cx.unhide_other_apps()`: macOS'ta Cmd+H mantığında uygulama gizleme. Uygulama yaşamaya devam eder, yalnızca pencereleri ekran dışına alınır.
- `window.activate_window()`: Belirli bir pencereyi öne getirir.
- `window.minimize_window()`: Pencereyi simge durumuna küçültür.
- `window.toggle_fullscreen()`: Tam ekran modunu açar/kapatır.

### Platform sinyalleri (OS'tan gelen olaylara nasıl bağlanılır)

Platform sinyalleri, **işletim sisteminin ilettiği değişiklikleri yakalamak için kaydedilen geri-çağrılardır (callback)**. Mantık basittir: uygulama başlatılırken (genelde `app.run(|cx| { ... })` içinde) `cx.on_xxx(|cx| { ... })` ile bir fonksiyon kaydedilir; OS o olay gerçekleştiğinde GPUI'nin ana event loop'u kayıtlı fonksiyonu çağırır ve içine güncel `&mut App` (veya ilgili veri) verir. Yani uygulama "şu olduğunda haber ver" şeklinde bir abonelik kurar, GPUI olayı aldığı an callback'i çalıştırır.

- **`cx.on_keyboard_layout_change(|cx| { ... })`** — Kullanıcı klavye düzenini değiştirdiğinde (örn. Türkçe Q'dan Türkçe F'ye, ya da macOS'ta dil çubuğundan İngilizce'ye dönüş) bu callback tetiklenir ve içine yazılan kod o anda çalışır. Tipik kullanımı: shortcut etiketlerini (`Ctrl+;` gibi) yeni layout'a göre yeniden hesaplama, sanal klavye gösterimini güncelleme, fiziksel tuş ipuçlarını yenileme. Anlık değer için `cx.keyboard_layout()` o anki layout kimliğini, `cx.keyboard_mapper()` ise tuş→karakter dönüşüm haritasını döndürür.

- **`cx.on_thermal_state_change(|state, cx| { ... })`** — Cihazın ısınma durumu değiştiğinde tetiklenir. macOS/iOS thermal API'leri üzerinden `Normal`, `Fair`, `Serious`, `Critical` gibi durumlar gelir. Buraya genelde CPU'yu rahatlatacak işlemler yazılır: arka plan indeksleme/sıkıştırma işlerinin geçici olarak durdurulması, animasyon FPS'inin düşürülmesi, tembel render moduna geçilmesi. Anlık okuma için `cx.thermal_state()` da kullanılabilir.

- **`cx.on_window_closed(|cx, window_id| { ... })`** — Bir pencere kapandıktan **sonra** çalışır. Gelen tek bilgi `WindowId`'dir; o pencereye artık erişilemez, yalnızca kayıtlardaki ilgili artifact'lar (eşleştirilmiş global state, geçici dosyalar) temizlenir.

- **`cx.set_cursor_hide_mode(CursorHideMode::...)`** — Kullanıcı klavyeyle yazmaya başladığında mouse imlecini otomatik gizleme politikasını belirler. Editörlerde genelde "OnTyping" tercih edilir.

- **`cx.refresh_windows()`** — Tüm açık pencerelere "yeniden çiz" sinyali atar; herhangi bir state değiştirmez. Tema/yazı tipi gibi global bir değişiklikten sonra her şeyin baştan çizilmesi gerektiğinde kullanılır.

- **`cx.set_quit_mode(mode)`** — [Çıkış davranışı](#çıkış-davranışı-quitmode-ve-uygulama-aktivasyonu) politikasını runtime'da günceller. `.with_quit_mode(...)` ile aynı alanı yazar.

### Tuzaklar

- **`on_open_urls` callback'i `&mut App` almaz.** Bu callback, kullanıcı sisteme kayıtlı bir URL şemasını (örn. `myapp://dosya/123`) tıklayıp uygulamayı açtığında ya da zaten açık uygulamaya bir URL geldiğinde tetiklenir. İmzası `&mut App` içermediği için içeriden doğrudan entity güncellenemez, pencere açılamaz, global state'e yazılamaz; yani "bu URL geldi, hemen ilgili dosyayı aç" mantığı doğrudan bu callback'e konmaz. Tipik çözüm, gelen URL'leri thread-safe bir kuyruğa (örn. `Arc<Mutex<Vec<Url>>>` veya kanal) yazmak ve asıl işi `&mut App` erişimi olan bir yerden, örneğin `app.run` içinde kurulan foreground task/defer akışından ya da uzun yaşayan bir global/entity köprüsünden yürütmektir.
- **`on_reopen` özellikle macOS Dock senaryosu içindir.** Kullanıcı tüm pencereleri kapattıktan sonra Dock'taki simgeye veya menü çubuğundaki uygulama adına yeniden tıkladığında macOS uygulamayı kapatmaz, `reopen` olayını gönderir. Bu olay yakalanmadığında Dock'a tıklamak yalnızca uygulamayı öne getirir ama hiçbir pencere açılmaz; kullanıcı açısından "tıkladım ama bir şey olmadı" hissi oluşur. Beklenen davranış için `on_reopen` içinde açık pencere sayısı kontrol edilir, sıfırsa yeni bir workspace penceresi açılır.
- **`refresh_windows()` veriyi değiştirmez, yalnızca yeniden çizdirir.** Bu çağrı entity state'ine dokunmaz; sadece "bir sonraki frame'de tüm pencereler `render`'larını yeniden çalıştırsın" sinyali atar. Altta yatan model aynı kaldıkça ekrandaki görüntü de aynı çıkar, yani içerik güncellemek için bu fonksiyon yeterli değildir. İçerik değişikliği gerektiğinde ilgili entity'ler `update`/`notify` ile değiştirilir; `refresh_windows()` ise tema, font ölçeği veya genel UI ayarı gibi *global bir parametre* değiştiğinde tüm pencerelerin yeni değere göre yeniden çizilmesini tetiklemek için kullanılır.

## 2.3. Platform Servisleri

"Platform servisi" ile kastedilen şey, işletim sistemine bağlı tüm yetenekleri (pencere yönetimi, pano, dosya seçici, klavye, ekran, kimlik bilgisi deposu vs.) `App` ve `Window` üzerinden tek bir tutarlı API olarak sunan katmandır. Uygulama kodu doğrudan macOS, Windows veya Linux çağrılarıyla uğraşmaz; örneğin `cx.write_to_clipboard(...)` çağrılır ve GPUI altta çalışan platforma göre doğru sistemi seçer. Aşağıdaki listeler `crates/gpui/src/app.rs` içindeki wrapper'ları işaret eder; gerçek davranış her platformun `Platform` trait implementasyonunda yer alır.

**`App` üzerinden ulaşılan servisler:**

- **Uygulama yaşam döngüsü.** Uygulamanın temel hayatta-kalma kontrolleri burada toplanır.
  - `cx.quit()`, `cx.restart()`: uygulamayı kapatır ya da yeniden başlatır. `set_restart_path(path)` özel bir binary ile restart için kullanılır (örn. güncelleme sonrası yeni sürümü çalıştırmak).
  - `cx.on_app_quit(|cx| async { ... })`, `cx.on_app_restart(|cx| { ... })`: kapanış veya yeniden başlatma anına bağlanan callback'ler (örn. state'i son anda diske yazma).
  - `cx.activate(...)`, `cx.hide()`, `cx.hide_other_apps()`, `cx.unhide_other_apps()`: [aktivasyon ve gizleme](#çıkış-davranışı-quitmode-ve-uygulama-aktivasyonu).

- **Pencereler.** Açık pencerelere toplu erişim:
  - `cx.windows()` tüm pencerelerin listesini, `cx.active_window()` o anda odakta olanı, `cx.window_stack()` ön-arka sırasını döndürür.
  - `cx.refresh_windows()`: hepsine "yeniden çiz" sinyali verir; veri değiştirmediği için [refresh tuzağına](#tuzaklar) dikkat edilir.

- **Display (ekran).** Çoklu monitör desteği:
  - `cx.displays()` tüm ekranları, `cx.primary_display()` birincil ekranı, `cx.find_display(id)` belirli bir ekran kimliğine karşılık geleni döndürür. Pencere konumlandırma ve "açılırken son ekranda aç" gibi restore akışlarında kullanılır.

- **Görünüm (appearance).** Sistem teması ve UI politikası okumaları:
  - `cx.window_appearance()`: o anki sistem temasını (light/dark/auto) verir.
  - `cx.button_layout()`: macOS/Windows/Linux'ta kapat–küçült–büyüt butonlarının dizilişini söyler; custom title bar çizilirken bu butonların konum hesabı için gerekir.
  - `cx.should_auto_hide_scrollbars()`: scroll bar'ın sürekli mi yoksa yalnızca scroll sırasında mı görüneceğini belirten kullanıcı tercihi.

- **Pano (clipboard).** Sistem panosuna okuma/yazma:
  - `cx.write_to_clipboard(item)`, `cx.read_from_clipboard()`: hem düz metin hem zengin içerik için.
  - Linux'taki "primary selection" (X11 orta-tıkla yapıştır) için ayrı API: `read_from_primary`, `write_to_primary`.
  - macOS'taki "Find Pasteboard" (Cmd+E ile arama panosuna kopyalama) için: `read_from_find_pasteboard`, `write_to_find_pasteboard`.

- **Credential deposu.** Sistem anahtarlığını (macOS Keychain, Windows Credential Manager, Linux Secret Service) tek API üzerinden yönetir:
  - `cx.write_credentials(url, username, password)`, `cx.read_credentials(url)`, `cx.delete_credentials(url)`. Dönüş tipleri `Task` olduğu için async'tir; await edilebilir ya da `detach_and_log_err(cx)` ile arka planda bırakılabilir.

- **URL.** Tarayıcıda link açma ve sistem URL şeması kaydı:
  - `cx.open_url(url)`: varsayılan tarayıcıyla açar.
  - `cx.register_url_scheme(scheme)`: uygulamayı bir URL şemasıyla (örn. `myapp://`) ilişkilendirir. Platform bu şemayla bir URL ilettiğinde `on_open_urls` callback'i tetiklenir.

- **Dosya ve sistem diyalogları.**
  - `cx.prompt_for_paths(options)`: native "Dosya Aç" diyaloğunu açar.
  - `cx.prompt_for_new_path(directory, suggested_name)`: "Farklı Kaydet" diyaloğu.
  - `cx.reveal_path(path)`: ilgili dosyayı OS'un dosya yöneticisinde (Finder, Explorer, Nautilus) seçili olarak gösterir.
  - `cx.open_with_system(path)`: dosyayı işletim sisteminin varsayılan uygulamasıyla açar.
  - `cx.can_select_mixed_files_and_dirs()`: dosya seçicide dosya ve klasörlerin aynı anda seçilip seçilemeyeceğini bildirir.

- **Menü.** Uygulama menüsü ve macOS'a özgü öğeler:
  - `cx.set_menus(menus)`: ana uygulama menüsünü kurar.
  - `cx.set_dock_menu(menu)`: macOS Dock simgesinin sağ-tık menüsü.
  - `cx.add_recent_document(path)`: işletim sisteminin "son kullanılanlar" listesine ekler.
  - `cx.update_jump_list(...)`: Windows Jump List öğelerini günceller.

- **Termal durum.** `cx.thermal_state()` o anki ısınma seviyesini döndürür; [`cx.on_thermal_state_change(...)` durum değişikliklerine bağlanır](#platform-sinyalleri-ostan-gelen-olaylara-nasıl-bağlanılır).

- **İmleç görünürlüğü.**
  - `cx.cursor_hide_mode()`, `cx.set_cursor_hide_mode(...)`, `cx.is_cursor_visible()`: tipik olarak yazma sırasında imleci gizleme politikası burada okunur ve değiştirilir.
  - İmlecin *şeklini* hitbox'a göre belirlemek için pencere/element seviyesinde `window.set_cursor_style(style, &hitbox)` kullanılır.
  - Drag sırasında ise `cx.set_active_drag_cursor_style(...)` devreye girer.

- **Ekran yakalama.** [`cx.is_screen_capture_supported()` ve `cx.screen_capture_sources()`](#screen-capture-ekran-yakalama).

- **Klavye.** Klavye düzeni ve karakter haritası: `cx.keyboard_layout()`, `cx.keyboard_mapper()` ve [`cx.on_keyboard_layout_change(...)`](#platform-sinyalleri-ostan-gelen-olaylara-nasıl-bağlanılır).

- **HTTP istemcisi.** `cx.http_client()` paylaşılan istemciyi döndürür; `cx.set_http_client(...)` çalışma zamanında değiştirmek için kullanılır. Başlatmada ise `Application::with_http_client(...)` builder API'si tercih edilir. Tipik Zed kurulumunda `crates/http_client` içindeki varsayılan kullanılır.

- **Uygulama yolu ve compositor.**
  - `cx.app_path()`: macOS'ta `.app` bundle'ının kök yolunu, Linux'ta yürütülen binary yolunu döndürür.
  - `cx.path_for_auxiliary_executable(name)`: bundle içindeki yardımcı binary'leri (örn. dil sunucusu, helper process) bulur.
  - `cx.compositor_name()`: Linux'ta `wayland`, `x11` ya da `xwayland` döner; diğer platformlarda boş string. Compositor'a özgü iş akışlarını (örn. CSD pencere gölgesi) tetiklemek için kontrol edilir.

**`Window` üzerinden ulaşılan servisler:**

- `window.on_window_should_close(cx, |window, cx| -> bool)`: kullanıcı kapatma butonuna bastığında çağrılır. `false` döndürmek kapatmayı iptal eder; "kaydedilmemiş değişiklik var, emin misiniz?" tarzı diyaloglar burada gösterilir.
- `window.appearance()`, `window.observe_window_appearance(...)`: o pencerenin görünüm modunu (light/dark) okur ve değiştiğinde haber alır.
- `window.tabbed_windows()`, `window.set_tabbing_identifier(...)`: [macOS'un native window tab desteği](./bolum-06-pencere-yonetimi.md#613-native-window-tabs-ve-systemwindowtabcontroller).

Platform trait'ini doğrudan implemente etmek ayrı bir konudur ve 2.4'te ele alınır; uygulama geliştirme tarafında `App` ve `Window` wrapper'ları üzerinden çalışmak yeterlidir.

## 2.4. Platform Trait Implementasyonu ve Wrapper Sınırları

Bu bölüm normal uygulama geliştirenleri ilgilendirmez; GPUI'ye yeni bir platform desteği eklerken (örn. yeni bir Linux compositor portu, embedded sistem veya başsız test backend'i) ya da var olan platform davranışını incelerken referans noktasıdır. Uygulama tarafında `Platform` ve `PlatformWindow` trait'lerine doğrudan dokunulmaz; bunun yerine `App` ve `Window` wrapper'ları kullanılır. Wrapper'lar trait method'larını çağırırken aynı zamanda cross-platform mantığı (örn. eksik kapasite için fallback, hitbox'a göre imleç seçimi) yürütür.

**`Platform` trait'inin ana grupları:**

- *Executor ve text system*: `background_executor`, `foreground_executor`, `text_system`. Tüm async iş ve metin çizim altyapısı bu üçü üzerinden akar.
- *Uygulama yaşam döngüsü*: `run`, `quit`, `restart`, `activate`, `hide`, `hide_other_apps`, `unhide_other_apps`, `on_quit`, `on_reopen`. Yeni platform, uygulamanın açılış-kapanış mantığını bu method'larla bağlamak zorundadır.
- *Display ve pencere*: `displays`, `primary_display`, `active_window`, `window_stack`, `open_window`. Pencere oluşturma çekirdeği.
- *Görünüm ve UI politikası*: `window_appearance`, `button_layout`, `should_auto_hide_scrollbars`, imleç görünürlüğü ve stili.
- *URL/yol/prompt*: `open_url`, `on_open_urls`, `register_url_scheme`, `prompt_for_paths`, `prompt_for_new_path`, `reveal_path`, `open_with_system`.
- *Menüler*: `set_menus`, `get_menus`, `set_dock_menu`, `on_app_menu_action`, `on_will_open_app_menu`, `on_validate_app_menu_command`.
- *Pano ve credentials*: normal clipboard, Linux primary selection, macOS find pasteboard ve credential store task'leri.
- *Ekran yakalama ve klavye*: `is_screen_capture_supported`, `screen_capture_sources`, `keyboard_layout`, `keyboard_mapper`, `on_keyboard_layout_change`.

**`PlatformWindow` trait'inin ana grupları:**

- *Bounds ve durum*: `bounds`, `window_bounds`, `content_size`, `resize`, `scale_factor`, `display`, `appearance`, `modifiers`, `capslock`. Pencerenin boyut, konum, ekran, görünüm ve klavye modifier durumu burada raporlanır.
- *Girdi*: `set_input_handler`, `take_input_handler`, `on_input`, `update_ime_position`. Klavye, mouse ve IME (input method editor) girdilerinin uygulamaya iletilme noktası.
- *Pencere yaşam döngüsü*: `activate`, `is_active`, `is_hovered`, `minimize`, `zoom`, `toggle_fullscreen`, `on_should_close`, `on_close`.
- *Render*: `on_request_frame`, `draw(scene)`, `completed_frame`, `sprite_atlas`, `is_subpixel_rendering_supported`. Çizim sahnesinin GPU'ya gönderildiği taraf.
- *Dekorasyon ve hit-test*: `set_title`, `set_background_appearance`, `on_hit_test_window_control`, `request_decorations`, `window_decorations`, `window_controls`. Başlık çubuğu, gölge, kontrol butonları gibi pencere kabuğu davranışları.
- *Platforma özel*: macOS tab/document API'leri, Linux move/resize/menu/app-id/inset, Windows raw handle, test-only `render_to_image`.

**Wrapper ile trait arasındaki sınır.** Trait method'larıyla `App`/`Window` üzerindeki benzer isimli method'lar bire-bir aynı değildir; wrapper bazı kararları kendi başına alır:

- `Platform::set_cursor_style`: tüm uygulama için tek bir genel imleç ayarlar (örn. global "bekleyen" imleci). UI'da belirli bir bölge için hitbox'a bağlı imleç gerektiğinde `Window::set_cursor_style` kullanılır; wrapper o sırada mouse'un hangi hitbox üzerinde olduğunu hesaplar.
- `PlatformWindow::prompt`: platformun native prompt desteğini temsil eder. `Window::prompt` ise bu desteği kullanır; native prompt yoksa GPUI tarafındaki prompt akışına düşebilir.
- `PlatformWindow::map_window`: Linux'ta "map" (pencereyi compositor'a görünür yap) ve "show" ayrımı içindir. Uygulama kodu bunu doğrudan çağırmaz; `WindowOptions.show` alanı ve wrapper davranışı yeterlidir.
- *Trait default method'ları "desteklenmiyor" anlamı taşır.* Wrapper üzerinden dönen `None` veya no-op sonuçları, platform yeteneğinin eksik olduğu şeklinde yorumlanır; UI tarafında bu duruma uygun bir fallback davranışı sağlanır (örn. özelliği menüden gizleme, alternatif yöntem önerme).

## 2.5. Headless, Screen Capture ve Test Renderer

İlgili kaynaklar: `crates/gpui/src/platform.rs::screen_capture_sources` ve `crates/gpui_platform/src/gpui_platform.rs::headless()`.

### Headless mod

"Headless mod", GPUI'nin pencere açmadan çalıştırılabildiği bir başlatma biçimidir. Ekrana görünür bir pencere çizilmez ama uygulamanın executor/async, asset loading, network I/O ve entity sistemi gibi geri kalan altyapısı çalışır. Tipik kullanım alanları: komut satırı alt komutları (örn. `myapp index ./project`), batch dosya işleme, sunucu süreçleri, performans benchmark'ları ve CI ortamında çalışan testler.

```rust
gpui_platform::headless().run(|cx: &mut App| {
    // Arka plan görevleri, asset yükleme, ağ I/O; render yok.
});
```

Headless çalışmanın varyantları ve hangisinin ne zaman tercih edildiği:

- **`gpui_platform::headless()`** — Görünür pencere açmadan uygulama çalıştırmak için kullanılır. Üretim ortamındaki CLI/server senaryoları bu yola düşer.
- **`HeadlessAppContext`** — Birim test ve entegrasyon testlerinde uygulama mantığını koşturmak için. Pencere açılmadan entity, action, async akış doğrulanır.
- **`VisualTestContext`** — UI testleri için tasarlanmıştır. Layout, render sonucu, snapshot gibi görsel doğrulamalar yapılır; sistem penceresi açılmaz ama in-memory render katmanı çalışır.
- **`gpui_platform::current_headless_renderer()`** — Yalnızca `test-support` feature'ı altında erişilebilir. Şu an macOS'ta Metal tabanlı headless renderer döndürebilir; diğer platformlarda `None` dönmesi olağandır. UI testlerinde gerçek pencere açmadan piksel doğrulaması yapmak için kullanılır.

`gpui_platform::headless` ve test context'leri birbiriyle karıştırılmaz. Üretimde headless çalıştırma için `gpui_platform::headless()`, test/UI doğrulaması için `HeadlessAppContext` veya `VisualTestContext` tercih edilir.

### Screen capture (ekran yakalama)

Screen capture, ekranın veya belirli bir pencerenin görüntüsünü uygulama içine akıtmaya yarar. Tipik kullanım alanları: ekran paylaşımı, ekran kaydı, picture-in-picture önizleme ve test amaçlı görüntü yakalama. API iki adımdan oluşur: önce mevcut kaynakların listesi alınır, ardından seçilen kaynaktan frame stream başlatılır.

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

Akış şöyle işler: `cx.screen_capture_sources()` platforma uygun kaynakların listesini bir `oneshot::Receiver<Result<Vec<Box<dyn ScreenCaptureSource>>>>` üzerinden döndürür. Liste platforma göre değişir; macOS'ta ekranlar ve uygulama pencereleri, Windows'ta benzer kaynaklar, Linux'ta ise compositor protokolüne (PipeWire/portal vb.) bağlı kaynaklar gelebilir. Seçilen kaynağın `stream(&ForegroundExecutor, frame_callback)` çağrısı yakalamayı başlatır; her yeni frame'de `frame_callback` `ScreenCaptureFrame` ile çağrılır. `stream.metadata()` ile stream'e ait çözünürlük gibi bilgiler okunabilir.

### Tuzaklar

- **macOS izinleri.** `screen_capture_sources()` çağrısı işletim sisteminin "Screen Recording" iznini gerektirebilir. Onay verilmezse liste boş döner ya da hata gelir; onay verildikten sonra izin uygulamanın sonraki başlatmalarında da geçerli kalır. UI tarafında ilk kullanımda izin penceresi açılabileceği beklentisi yönetilir.
- **Desteklenmeyen platformlar.** Capture'in çalışmadığı ortamlarda `cx.is_screen_capture_supported()` `false` döner veya kaynak listesi boş gelir. Buna karşılık olarak ilgili özelliğin menüden gizlenmesi ya da "bu platformda ekran paylaşımı desteklenmiyor" şeklinde bir bilgi gösterilmesi gerekir.
- **UI testlerinde gerçek pencere açma.** UI doğrulaması için sistem penceresi açmaktan kaçınılır; `TestAppContext`, `VisualTestContext` veya renderer factory ile beslenen `HeadlessAppContext` kullanılır. Aksi halde testler ekrana erişimi olmayan CI ortamında başarısız olur.


---
