# Pencere Yönetimi

---

## Pencere Oluşturma

GPUI'de pencereyi açan ana API `cx.open_window(options, root_builder)`'dır.
İlk parametre pencerenin başlangıç davranışını anlatan `WindowOptions`,
ikincisi ise pencerenin root view'unu kuran closure'dır. Tipik kullanım şu
kalıbı izler:

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

**`WindowOptions` alanları.** Aşağıdaki alanlar pencerenin oluşumunda
sorumluluğu olan başlıca parametreleri tanımlar:

- `window_bounds`: `None` verilirse GPUI display için varsayılan bounds seçer.
  `Some` ile gelen değer `Windowed`, `Maximized` veya `Fullscreen` başlangıcını
  belirler. Default seçilirken baz alınan boyutlar
  `gpui::DEFAULT_WINDOW_SIZE: Size<Pixels>` (1536×1095, ana Zed penceresi
  için) ve `gpui::DEFAULT_ADDITIONAL_WINDOW_SIZE` (900×750, 6:5 oranında
  settings veya rules library benzeri ek pencereler için) const'larıdır
  (`window.rs:70,74`); kendi varsayılan boyutunu ayrıca ezmek gerekmiyorsa bu
  değerlere güvenilebilir.
- `titlebar`: `Some(TitlebarOptions)` sistem başlık çubuğu ayarı için
  kullanılır. `None` verildiğinde özel titlebar yolu açılır.
- `focus`: pencere oluşturulduğu anda odağı alıp almayacağını belirler.
- `show`: pencerenin hemen gösterilip gösterilmeyeceğini kontrol eder. Zed ana
  pencereleri başlangıçta `show: false`, `focus: false` ile açar ve hazır
  olduğunda gösterir.
- `kind`: `Normal`, `PopUp`, `Floating`, `Dialog`; Linux Wayland feature'ı ile
  birlikte `LayerShell` de mevcuttur.
- `is_movable`, `is_resizable`, `is_minimizable`: platform seviyesindeki
  pencere kabiliyetleridir.
- `display_id`: belirli bir monitör hedefler.
- `window_background`: `Opaque`, `Transparent`, `Blurred` değerleri; Windows
  için ayrıca `MicaBackdrop` ve `MicaAltBackdrop` seçenekleri de vardır.
- `app_id`: Linux desktop'larda uygulama gruplandırması ve görev çubuğu
  davranışı için kullanılır.
- `window_min_size`: minimum içerik boyutu.
- `window_decorations`: `Server` veya `Client` seçimini taşır. Linux'ta
  kritik bir alandır; macOS ve Windows tarafında ise pratikte titlebar
  seçenekleri daha belirleyicidir.
- `icon`: X11 üzerinde pencere ikonu için kullanılır.
- `tabbing_identifier`: macOS native pencere tab gruplaması için.

`Window::new` çağrısı GPUI platform penceresini açtıktan sonra şu sırayı
izler:

1. `platform_window.request_decorations(...)` çağrılır.
2. `platform_window.set_background_appearance(window_background)` çağrılır.
3. Bounds `Fullscreen` ise fullscreen, `Maximized` ise zoom uygulanır.
4. Platform callback'leri bağlanır.
5. İlk render gerçekleştirilir.

## Zed'de Ana Pencere Nasıl Açılır?

Zed'in ana pencere açma akışı `crates/zed/src/zed.rs::build_window_options`
fonksiyonunda toplanır. Yeni bir workspace penceresi açılacağında bu fonksiyon
tercih edilir:

```rust
let options = zed::build_window_options(display_uuid, cx);
let window = cx.open_window(options, |window, cx| {
    cx.new(|cx| Workspace::new(/* ... */, window, cx))
})?;
```

Fonksiyon kendi içinde şu işleri sırayla yapar:

- `display_uuid` ile uygun display'i bulur.
- `ZED_WINDOW_DECORATIONS=server|client` env değişkeniyle override'ı okur.
- Aksi durumda `WorkspaceSettings::window_decorations` ayarını kullanır.
- `TitlebarOptions { appears_transparent: true, traffic_light_position: (9,9) }`
  kurar.
- `focus: false`, `show: false`, `kind: Normal` olarak ayarlar.
- `window_background` değerini aktif temadan alır.
- Linux/FreeBSD'de uygulama ikonunu ekler.
- macOS native tabbing istendiğinde `tabbing_identifier: Some("zed")` verir.

Modal veya About benzeri küçük pencerelerde bu fonksiyonu kullanmak yerine
doğrudan `WindowOptions` kurmak daha yaygın bir desendir. Örneğin
`crates/zed/src/zed.rs::about` şu seçenekleri kullanır:

- Merkezlenmiş bounds
- `appears_transparent: true`
- `is_resizable: false`
- `is_minimizable: false`
- `kind: Normal`

## Display ve Çoklu Monitor

Birden fazla ekran olduğunda hedef display `cx.displays()` listesi üzerinden
bulunur. Liste her display için kimlik, bounds ve UUID bilgisini sağlar:

```rust
for display in cx.displays() {
    let id = display.id();
    let bounds = display.bounds();
    let visible = display.visible_bounds();
    let uuid = display.uuid().ok();
}
```

Belirli bir ekrana pencere açmak için seçilen display'in id'si options'a
verilir:

```rust
WindowOptions {
    display_id: Some(display.id()),
    window_bounds: Some(WindowBounds::Windowed(bounds)),
    ..Default::default()
}
```

`Bounds` her zaman ekran koordinatlarında ifade edilir.
`WindowBounds::centered(size, cx)` çağrısı ana ya da varsayılan display
üzerinde merkezleme yapar. Elle konumlandırma gerektiğinde
`Bounds::new(origin, size)` kullanılır.

## WindowKind Davranışı

Pencerenin rolü `WindowKind` ile belirlenir; bu seçim pencerenin focus
politikasını, z-order davranışını ve dekorasyonunu doğrudan etkiler:

- `Normal`: ana uygulama penceresi.
- `PopUp`: diğer pencerelerin üstünde duran, bildirim ve geçici popup'lar
  için. Zed bildirim pencerelerinde bu türü kullanır.
- `Floating`: parent üzerinde sabit duran floating panel.
- `Dialog`: parent etkileşimini bloklayan modal platform penceresi.
- `LayerShell`: Wayland layer-shell feature'ı aktifken dock, overlay veya
  wallpaper benzeri yüzeyler için.

Pop-up ve bildirim pencerelerinde tipik konfigürasyon şuna benzer:

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

Zed içindeki örnekler `crates/agent_ui/src/ui/agent_notification.rs` ve
`crates/collab_ui/src/collab_ui.rs` dosyalarındadır.

## Başlık Çubuğu ve Pencere Dekorasyonu

Başlık çubuğu ve pencere dekorasyonu iki ayrı kavramdır. Karışmaması için
ikisinin sorumluluğu ayrı düşünülmelidir:

- `TitlebarOptions`: macOS ve Windows native başlık çubuğunun görünümü, başlık
  metni ve macOS traffic light konumu burada belirlenir.
- `WindowDecorations`: Linux/Wayland/X11 tarafında dekorasyonun server-side mı
  yoksa client-side mı olacağını söyler.

GPUI tarafındaki tipler şunlardır:

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

`WindowDecorations` pencere açılırken istenen moddur; `Decorations` ise
platformun fiili durumudur ve `window.window_decorations()` ile okunur.
Compositor sınırları nedeniyle istenen mod her zaman aynen karşılanmayabilir,
bu yüzden bu ikisi ayrı tutulur.

Zed ayarı tek bir alan üzerinden ifade edilir:

```json
{
  "window_decorations": "client"
}
```

Env değişkeniyle de override mümkündür:

```sh
ZED_WINDOW_DECORATIONS=server
ZED_WINDOW_DECORATIONS=client
```

Zed settings tipi `settings_content::workspace::WindowDecorations` yalnızca
`client` ve `server` değerlerini destekler; varsayılan değer `client`'tır.

## Custom Titlebar Nasıl Tanımlanır?

Basit bir GPUI uygulamasında native başlık çubuğu kapatılır ve özel başlık
çubuğu root view içine yerleştirilir:

```rust
cx.open_window(
    WindowOptions {
        titlebar: None,
        ..Default::default()
    },
    |_, cx| cx.new(|_| MyView),
)?;
```

Root view içinde özel başlık çubuğu şu kalıpta çizilir:

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

Windows tarafında caption button bölgeleri için `window_control_area` çağrısı
kritik öneme sahiptir; native hit-test bu alanlar üzerinden çözülür:

- `WindowControlArea::Drag`: sürüklenebilir başlık alanı.
- `WindowControlArea::Close`: native close hit-test alanı.
- `WindowControlArea::Max`: maximize/restore hit-test alanı.
- `WindowControlArea::Min`: minimize hit-test alanı.

Zed'de yeni bir workspace benzeri pencere yapıldığında özel titlebar sıfırdan
yazılmaz; bunun yerine hazır `PlatformTitleBar` bileşeni kullanılır:

```rust
let platform_titlebar = cx.new(|cx| PlatformTitleBar::new("my-titlebar", cx));

platform_titlebar.update(cx, |titlebar, _| {
    titlebar.set_children([my_left_or_center_content.into_any_element()]);
});

platform_titlebar.into_any_element()
```

`PlatformTitleBar` hazır olarak şu işleri halleder:

- Linux client-side decoration için sol/sağ pencere kontrol butonları.
- Windows pencere kontrol butonları.
- macOS traffic light padding ve double-click davranışı.
- Linux double-click ile zoom/maximize.
- Başlık çubuğu drag alanı.
- Linux'ta sağ tık ile pencere menüsü.
- Sidebar açıkken kontrol butonları ve köşe yuvarlamalarının ayarlanması.

Zed'in titlebar davranışında dikkat çeken iki ayrıntı vardır:

- `TitleBar`, `SkillsFeatureFlag` açıkken `OnboardingBanner` ile "Introducing:
  Skills" banner'ını kurar; banner tıklaması
  `zed_actions::agent::OpenRulesToSkillsMigrationInfo` action'ını dispatch
  eder. Rules-to-Skills açıklaması modal katmanında gösterilir, titlebar
  label'ı migration sonucuna göre değişmez.
- `UpdateButton::checking`, `downloading` ve `installing` durumları disabled
  button olarak çizilir. Sürüm tooltip metni `"Update to Version: ..."`
  biçimindedir; SHA tabanlı sürümde kısa SHA yerine tam SHA gösterilir.

## Kontrol Butonları Nasıl Yönetilir?

Pencere kontrol butonları her platformda farklı çizilir; doğru bileşen
seçildiği sürece çizim ayrıntıları kullanıcının önüne çıkmaz:

- macOS: native traffic light kullanılır; Zed yalnızca padding ve
  `traffic_light_position` değerini ayarlar.
- Windows:
  `platform_title_bar::platforms::platform_windows::WindowsWindowControls`
  caption button'ları render eder; her buton `WindowControlArea` üzerinden
  native hit-test alanına bağlanır.
- Linux:
  `platform_title_bar::platforms::platform_linux::LinuxWindowControls`
  `WindowButtonLayout` ve `WindowControls` bilgilerine göre close/min/max
  butonlarını çizer.

Sol ve sağ kontrolleri hazır çizmek için iki yardımcı fonksiyon vardır:

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

Close butonu doğrudan `window.remove_window()` çağırmaz; bunun yerine Zed
close action'ı dispatch eder:

```rust
window.dispatch_action(workspace::CloseWindow.boxed_clone(), cx);
```

Böylece dirty buffer kontrolü, kullanıcıya sorma diyaloğu, workspace kapatma
mantığı ve keybinding ile aynı akış kullanılır.

**Linux `WindowButtonLayout`.** Linux tarafında buton düzeni esnektir ve
kullanıcı tarafında özelleştirilebilir:

- `WindowButton::{Minimize, Maximize, Close}` sıralı control tipleridir;
  layout sol ve sağ taraf için `Option<WindowButton>` slot dizileri tutar.
  Slot başı sayı `gpui::MAX_BUTTONS_PER_SIDE: usize = 3` (`platform.rs:457`)
  ile sabittir; `WindowButtonLayout::{left, right}` bu sayıda elemanlı
  dizilerdir.
- Layout platformdan `cx.button_layout()` ile gelir.
- GNOME tarzı `"close,minimize:maximize"` formatı parse edilebilir.
- Varsayılan Linux yedeği sağda minimize, maximize, close şeklindedir.
- `TitleBarSettings` içinde kullanıcı override'ı da yer alır; `TitleBar`
  bunu `PlatformTitleBar::set_button_layout` ile aktarır.

## Client-Side Decoration ve Resize

Zed'in client-side decoration sarmalayıcısı tek bir helper üzerinde
toplanmıştır:

```rust
workspace::client_side_decorations(element, window, cx, border_radius_tiling)
```

Bu sarmalayıcının yaptığı işler şunlardır:

- `window.window_decorations()` ile fiili dekorasyon modunu okur.
- Client decoration durumunda
  `window.set_client_inset(theme::CLIENT_SIDE_DECORATION_SHADOW)` çağırır.
- Server decoration durumunda inset değerini `0` yapar.
- `window.client_inset()` platform penceresine son set edilen inset değerini
  okumak için kullanılabilir; bu değer padding ve shadow hesabıyla uyumlu
  tutulmalıdır.
- Tiling durumuna göre köşe yuvarlamalarını kaldırır.
- Border ve shadow çizer.
- Kenar ve köşe bölgelerinde cursor'u resize cursor'a çevirir.
- Mouse down'da `window.start_window_resize(edge)` çağırır.

Özel bir client-side decoration yapıldığında aynı prensiplerin tekrarlanması
gerekir:

1. Fiili mod `window.window_decorations()` ile okunur.
2. Client mod ise gölge veya görünmez resize alanı kadar `set_client_inset`
   verilir.
3. Tiling varsa ilgili kenar ve köşeye radius, padding ve shadow verilmez.
4. Resize bölgelerinde `ResizeEdge` hesaplanır.
5. Hareket için başlık çubuğuna `WindowControlArea::Drag` bağlanır ya da
   Linux/macOS için `window.start_window_move()` çağrılır.

Linux'ta server-side decoration her zaman mümkün olmayabilir:

- Wayland'de compositor decoration protocol sağlamazsa server isteği client'a
  düşürülür.
- X11'de compositor olmadığında client-side decoration server'a düşebilir.

Bu nedenle pencere açılırken istenen mod değil, her render'da alınan fiili
`window.window_decorations()` sonucu esas alınır.

## Platforma Göre Dekorasyon Davranışı

#### macOS

- `TitlebarOptions::appears_transparent = true` style mask'e
  `NSFullSizeContentViewWindowMask` ekler.
- `traffic_light_position` native close/min/zoom butonlarının konumunu taşır.
- `titlebar_double_click()` native double-click aksiyonunu uygular.
- `start_window_move()` native `performWindowDragWithEvent` çağırır.
- `tabbing_identifier` verildiğinde native window tabbing açılır.
- `WindowDecorations` pratikte platform no-op'una karşılık gelir; macOS için
  başlık çubuğu davranışını `TitlebarOptions` belirler.

#### Windows

- `TitlebarOptions::appears_transparent` custom veya full-content titlebar
  için kullanılır.
- Caption butonlarının native hit-test davranışı `WindowControlArea`
  üzerinden `HTCLOSE`, `HTMAXBUTTON`, `HTMINBUTTON`, `HTCAPTION` değerlerine
  platform event katmanında eşlenir.
- `WindowBackgroundAppearance::MicaBackdrop` ve `MicaAltBackdrop` değerleri
  DWM backdrop attribute ile uygulanır.
- `WindowControls` çizimi Zed tarafında Windows component'i ile yapılır.

#### Linux/FreeBSD - Wayland

- `WindowDecorations::Server` xdg-decoration protocol ile istenir.
- Compositor server-side decoration desteklemiyorsa client-side'a düşülür.
- `window_controls()` Wayland capabilities bilgisinden gelir: fullscreen,
  maximize, minimize, window menu.
- `show_window_menu`, `start_window_move`, `start_window_resize` xdg_toplevel
  üzerinden compositor'a devredilir.
- Blur için compositor `blur_manager` destekliyorsa `Blurred` yüzeyde blur
  commit edilir.

#### Linux/FreeBSD - X11

- `request_decorations` `_MOTIF_WM_HINTS` yazar.
- Client-side decoration compositor gerektirir; yoksa server-side'a düşer.
- `show_window_menu` `_GTK_SHOW_WINDOW_MENU` client message gönderir.
- Move/resize işlemi `_NET_WM_MOVERESIZE` tarzı bir mesajla başlatılır.
- Tiling, fullscreen ve maximize state'leri
  `Decorations::Client { tiling }` sonucunu etkiler.

#### Web/WASM

- Web platformunda native pencere dekorasyonu kavramı bulunmaz.
- `WindowBackgroundAppearance` şu anda web pencerede opaque/no-op kabul
  edilir.
- Entry point'te `gpui_platform::web_init()` çağrılır.

## Blur, Transparency ve Mica Yönetimi

Pencere arka planının görünümü `WindowBackgroundAppearance` enum'u ile
ifade edilir:

```rust
pub enum WindowBackgroundAppearance {
    Opaque,
    Transparent,
    Blurred,
    MicaBackdrop,
    MicaAltBackdrop,
}
```

Zed tema ayarı bu enum'un tamamını değil, yalnızca seçili bir alt kümesini
kullanıcı içeriği üzerinden destekler:

```json
{
  "experimental.theme_overrides": {
    "window_background_appearance": "blurred"
  }
}
```

Desteklenen setting değerleri `opaque`, `transparent` ve `blurred`'dir.
`MicaBackdrop` ve `MicaAltBackdrop` değerleri GPUI seviyesinde mevcuttur,
ancak Zed tema şeması şu anda bunları kullanıcıya ifşa etmez.

**Zed akışı.** Tema değişimleri tüm açık pencerelere yansıtılır:

- Tema refine edilirken `WindowBackgroundContent` ->
  `WindowBackgroundAppearance` dönüştürülür.
- Ana pencere açılırken `window_background: cx.theme()
  .window_background_appearance()` verilir.
- Settings veya tema değiştiğinde `crates/zed/src/main.rs` tüm açık
  pencerelere `window.set_background_appearance(background_appearance)`
  çağrısı yapar.
- UI tarafında public yol `ui::theme_is_transparent(cx)`'tir; transparent
  veya blurred ise `true` döner. Opak arka plan varsayan bileşenler buna
  göre davranmalıdır.

**Platform davranışı.** Aynı enum değeri her platformda farklı bir
mekanizmayla ifade edilir:

- macOS:
  - `Opaque` pencereyi opak yapar.
  - `Transparent` ve `Blurred` için renderer transparency açılır.
  - macOS 12 öncesinde blur `CGSSetWindowBackgroundBlurRadius` ile 80 radius
    kullanır.
  - macOS 12 ve sonrasında `NSVisualEffectView` tabanlı blur view eklenir ya
    da kaldırılır.
- Windows:
  - `Opaque`: composition attribute kapatılır.
  - `Transparent`: composition state transparent olarak işaretlenir.
  - `Blurred`: acrylic veya blur benzeri composition attribute uygulanır.
  - `MicaBackdrop`: DWM `DWMSBT_MAINWINDOW`.
  - `MicaAltBackdrop`: DWM `DWMSBT_TABBEDWINDOW`.
- Wayland:
  - Compositor blur protocol desteklerse `Blurred` yüzeye blur uygulanır.
  - Aksi durumda blur isteği gözle görülür bir değişiklik üretmeyebilir.
- X11:
  - Transparent veya blur renderer transparency'yi etkiler; gerçek backdrop
    blur için window manager veya compositor desteği gereklidir.

**Pratik karar tablosu.** Hangi değerin nerede tercih edileceği şu şekilde
özetlenebilir:

- Tema ve ana pencere için: `cx.theme().window_background_appearance()`.
- Geçici overlay ve bildirim için: `Transparent`.
- Windows 11'e özel Mica isteniyorsa: doğrudan
  `WindowBackgroundAppearance::MicaBackdrop` veya `MicaAltBackdrop` verilir;
  ancak bu seçim Zed tema setting'e otomatik bağlanmaz.
- Blur tercih edildiğinde içerikte gerçekten alfa bırakılır; tamamen opak
  bir root background blur'ın görünmez olmasına yol açar.

## Pencere Üzerinden Yapılan İşlemler

Pencerenin durumuna ve görünümüne dair sık kullanılan `Window` API'leri
şunlardır; her biri ilgili platform çağrısının sade bir kapısıdır:

- `window.bounds()` — global ekran koordinatlarında bounds.
- `window.window_bounds()` — tekrar açma ve restore için `WindowBounds`.
- `window.inner_window_bounds()` — Linux inset hariç bounds.
- `window.viewport_size()` — drawable içerik boyutu.
- `window.resize(size)` — content size'ı değiştirir.
- `window.is_fullscreen()`, `window.is_maximized()`
- `window.activate_window()`
- `window.minimize_window()`
- `window.zoom_window()`
- `window.toggle_fullscreen()`
- `window.remove_window()`
- `window.set_window_title(title)`
- `window.set_app_id(app_id)`
- `window.set_background_appearance(appearance)`
- `window.set_window_edited(true/false)` — macOS dirty göstergesi.
- `window.set_document_path(path)` — macOS belge erişilebilirliği ve path.
- `window.show_window_menu(position)` — Linux başlık çubuğu context menu.
- `window.start_window_move()`, `window.start_window_resize(edge)`
- `window.request_decorations(WindowDecorations::Client/Server)`
- `window.window_decorations()`
- `window.window_controls()`
- `window.prompt(...)`
- `window.play_system_bell()`

macOS native window tabbing için ek bir API ailesi vardır:

- `window.tabbed_windows()`
- `window.tab_bar_visible()`
- `window.merge_all_windows()`
- `window.move_tab_to_new_window()`
- `window.toggle_window_tab_overview()`
- `window.set_tabbing_identifier(...)`

## Pencere Bounds Persist ve Restore

`crates/gpui/src/platform.rs::WindowBounds`, Zed tarafında
`crates/workspace/src/persistence/`, `crates/workspace/src/workspace.rs` ve
`crates/zed/src/zed.rs`.

`WindowBounds` enum'u pencerenin üç ana durumunu kapsar:

```rust
pub enum WindowBounds {
    Windowed(Bounds<Pixels>),
    Maximized(Bounds<Pixels>),
    Fullscreen(Bounds<Pixels>),
}
```

`Bounds` her üç durumda da geri yüklemeye hazır koordinatları taşır.
`Maximized` ve `Fullscreen` içindeki bounds değeri, ilgili durum kapatıldığında
geri dönülecek windowed bounds'u temsil eder.

**Persist akışı.** Bounds saklanırken tipik kullanım şudur:

```rust
let bounds = window.inner_window_bounds();
serialize(bounds, display_uuid);
```

Zed varsayılan pencere boyutunu saklarken `inner_window_bounds()` kullanır.
Workspace serialize sırasında bazı akışlarda `window.window_bounds()` da tercih
edilir. İkisi arasındaki fark, dahil edilen platform veya başlık çubuğu
rect'inin farklı olmasından kaynaklanır. Fullscreen ya da maximized
durumlarında enum içindeki bounds, geri yüklenecek windowed bounds'u temsil
eder. Display UUID'si ayrı saklanır; kullanıcı sonradan monitörü ayırabileceği
için bu kimliğin pencere bounds'undan bağımsız tutulması gerekir.

**Restore akışı.** Workspace açılırken `zed::build_window_options` üstünde
şu sıra izlenir:

1. Saklı `display_uuid`, `cx.displays()` içindeki `display.uuid()`
   değerleriyle eşleştirilir.
2. Display bulunmuşsa `options.display_id` ayarlanır ve kayıtlı
   `WindowBounds` değeri `options.window_bounds`'a yerleştirilir.
3. Workspace'e özel bounds bulunmuyorsa varsayılan window bounds okunur.
4. Hiç kayıt yoksa `WindowOptions.window_bounds = None` bırakılır ve GPUI
   platform varsayılan/cascade bounds seçer.

Bounds değişimini izlemek için subscription kullanılır:

```rust
cx.observe_window_bounds(window, |this, window, cx| {
    let bounds = window.inner_window_bounds();
    this.persist_bounds(bounds);
}).detach();
```

Aynı şekilde `cx.observe_window_appearance(window, ...)` light/dark
değişimini, `cx.observe_window_activation(window, ...)` ise
foreground/background değişimini takip eder.

**Tuzaklar.** Bounds tarafında karşılaşılan tipik karışıklıklar şunlardır:

- `window.bounds()` (canlı ekran rect'i), `window.window_bounds()` ve
  `window.inner_window_bounds()` farklı olabilir; restore veya persist
  akışında hangi rect'in beklendiği mevcut Zed çağrı noktasına göre
  seçilmelidir.
- Maximized ve fullscreen enum'larının içindeki `Bounds<Pixels>` restore
  boyutudur; canlı platform bounds ekranı tamamen kaplasa bile restore
  sonrasında bu windowed bounds'a geri dönülür.
- Display UUID'si Linux/Wayland tarafında boş olabilir; bu durumda
  `display.uuid().ok()` `None` döner ve uygun bir yedek davranış
  düşünülmelidir.

## Native Window Tabs ve SystemWindowTabController

macOS native window tabbing GPUI'de iki katmanlı bir yapı üzerinde durur:

- `WindowOptions::tabbing_identifier` — aynı identifier'a sahip pencerelerin
  native tab grubuna girmesini sağlar.
- `SystemWindowTabController` — GPUI global'i olarak native tab gruplarını
  ve görünürlük state'ini izler.

İlgili `Window` API'leri şunlardır:

- `window.tabbed_windows() -> Option<Vec<SystemWindowTab>>`
- `window.tab_bar_visible() -> bool`
- `window.merge_all_windows()`
- `window.move_tab_to_new_window()`
- `window.toggle_window_tab_overview()`
- `window.set_tabbing_identifier(Some(identifier))`

**Kullanım kararı.** Native tabbing ile uygulama içi tab sistemleri farklı
kavramlardır:

- Zed workspace tab ve pane sistemi için native tabbing yerine
  `workspace::Pane` ve `TabBar` kullanılır.
- İşletim sistemi seviyesinde birden çok top-level pencerenin aynı native
  tab grubuna alınması gerektiğinde `tabbing_identifier` verilir.
- Native tab state'i platformdan gelir; Linux ve Windows üzerinde bu
  API'lerin bir kısmı no-op kalabilir veya `None` dönebilir.

**Tuzaklar.** Native tab kullanırken dikkat edilmesi gerekenler:

- Native window tab ile Zed pane tab aynı kavram değildir; persistence ve
  komut yönlendirmesi farklıdır.
- Window title değiştiğinde native tab title için
  `window.set_window_title(...)` ve controller güncellemesi birlikte
  düşünülmelidir.

## Layer Shell ve Özel Platform Pencereleri

Normal Zed pencereleri `WindowKind::Normal` ile açılır. Linux Wayland feature'ı
aktifken `WindowKind::LayerShell(LayerShellOptions)` overlay, dock veya
wallpaper benzeri yüzeyler için kullanılabilir:

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

Layer shell ayarları compositor'a yüzeyin nerede ve nasıl davranacağını
anlatır:

- `Layer`: `Background`, `Bottom`, `Top`, `Overlay`.
- `layer_shell::Anchor`: bitflag; `TOP/BOTTOM/LEFT/RIGHT` kombine edilir.
- `exclusive_zone`: compositor'ın başka surface'lerin bu alanı kaplamamasını
  istemesi için.
- `exclusive_edge`: exclusive zone'un hangi kenara ait olduğunu belirtir.
- `margin`: CSS sırasıyla top/right/bottom/left.
- `KeyboardInteractivity`: `None`, `Exclusive`, `OnDemand`.

Bu API yalnızca `#[cfg(all(target_os = "linux", feature = "wayland"))]`
altında mevcuttur. Compositor protocol desteklemediğinde backend
`LayerShellNotSupportedError` döndürür; bu durumda normal app penceresine
düşen bir yedek akış planlanmalıdır.

---
