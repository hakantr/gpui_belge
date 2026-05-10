# 6. Pencere Yönetimi

---

## 6.1. Pencere Oluşturma

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

## 6.2. Zed'de Ana Pencere Nasıl Açılır?

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

## 6.3. Display ve Çoklu Monitor

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

## 6.4. WindowKind Davranışı

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

## 6.5. Başlık Çubuğu ve Pencere Dekorasyonu

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

## 6.6. Custom Titlebar Nasıl Tanımlanır?

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

## 6.7. Kontrol Butonları Nasıl Yönetilir?

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

## 6.8. Client-Side Decoration ve Resize

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

## 6.9. Platforma Göre Dekorasyon Davranışı

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

## 6.10. Blur, Transparency ve Mica Yönetimi

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
- UI tarafında `ui::styles::appearance::theme_is_transparent(cx)` transparent veya
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

## 6.11. Pencere Üzerinden Yapılan İşlemler

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

## 6.12. Pencere Bounds Persist ve Restore

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

## 6.13. Native Window Tabs ve SystemWindowTabController

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

## 6.14. Layer Shell ve Özel Platform Pencereleri

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

