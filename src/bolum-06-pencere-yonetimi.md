# 6. Pencere Yönetimi

---

## 6.1. Pencere Oluşturma

Pencere açmanın tek giriş noktası `cx.open_window(...)` çağrısıdır. Bu çağrı iki şey alır: pencerenin nasıl açılacağını tarif eden `WindowOptions` ve pencere ilk kez kurulduğunda root view'ı üreten closure. Geriye dönen `WindowHandle<V>` pencereye sonradan tipli erişim sağlar.

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

### `WindowOptions` alanları

- **`window_bounds`** — Açılış pozisyonu ve boyutu. `None` verilirse GPUI display'in default bounds'unu seçer; `Some` verildiğinde `Windowed`, `Maximized` veya `Fullscreen` başlangıcı yapılır. Default seçilirken baz alınan boyutlar `gpui::DEFAULT_WINDOW_SIZE: Size<Pixels>` (1536×1095, ana Zed penceresi için) ve `gpui::DEFAULT_ADDITIONAL_WINDOW_SIZE` (900×750, 6:5 oranında settings/rules library tarzı ek pencereler için) const'larıdır (`window.rs:70,74`). Standart Zed boyutları yeterli geliyorsa bu sabitler doğrudan kullanılabilir.
- **`titlebar`** — `Some(TitlebarOptions)` sistem başlık çubuğunu yapılandırır (başlık metni, macOS traffic-light konumu, "appears transparent" bayrağı). `None` verildiğinde sistem titlebar'ı tamamen devre dışı bırakılır; custom (uygulama içinde çizilen) bir titlebar isteniyorsa bu yol seçilir.
- **`focus`** — Pencerenin oluştuğunda odak alıp almayacağı.
- **`show`** — Pencerenin hemen görünür mü olacağı. Zed ana pencereleri başlangıçta `show: false, focus: false` ile açılır ve içerik hazır olunca görünür hâle getirilir; bu, "yarı yüklenmiş pencere" görüntüsünü engeller.
- **`kind`** — Pencere türü: `Normal`, `PopUp`, `Floating`, `Dialog`. Linux Wayland feature aktifken [`LayerShell`](#614-layer-shell-ve-özel-platform-pencereleri) da kullanılabilir.
- **`is_movable`, `is_resizable`, `is_minimizable`** — Platform tarafından sağlanan pencere yetenekleri. Modal/About pencereleri için tipik olarak `false`.
- **`display_id`** — Hangi monitörde açılacağı. `None` ise birincil display.
- **`window_background`** — Arkaplan modu: `Opaque`, `Transparent`, `Blurred`. Windows için ayrıca [`MicaBackdrop`, `MicaAltBackdrop`](#610-blur-transparency-ve-mica-yönetimi) kullanılabilir.
- **`app_id`** — Linux taraflı desktop grouping (taskbar gruplama, icon eşleme) için kullanılır.
- **`window_min_size`** — Minimum içerik boyutu; kullanıcı pencereyi bu boyutun altına çekemez.
- **`window_decorations`** — `Server` ya da `Client`. Linux'ta belirleyicidir; macOS/Windows'ta pratikte [`TitlebarOptions`](#65-başlık-çubuğu-ve-pencere-dekorasyonu) daha çok karar verir.
- **`icon`** — X11 için pencere ikonu (taskbar/Alt-Tab gösteriminde).
- **`tabbing_identifier`** — macOS [native window tab](#613-native-window-tabs-ve-systemwindowtabcontroller) gruplaması.

### Açılış akışı

`open_window` çağrıldığında GPUI önce platform penceresini oluşturur, ardından şunları yapar:

1. `platform_window.request_decorations(...)` ile pencere dekorasyon modu (server/client) istenir.
2. `platform_window.set_background_appearance(window_background)` ile background türü uygulanır.
3. Bounds `Fullscreen` ise pencere fullscreen'e alınır, `Maximized` ise zoom uygulanır.
4. Platform callback'leri (kapatma, focus değişimi, drag vs.) bağlanır.
5. Root view oluşturulur ve ilk render gerçekleştirilir.

## 6.2. Zed'de Ana Pencere Nasıl Açılır

Yeni bir ana workspace penceresi açılırken `WindowOptions` her seferinde elle inşa edilmez; Zed'in `crates/zed/src/zed.rs::build_window_options` fonksiyonu kullanıcı ayarlarına, env değişkenlerine ve aktif temaya göre uygun seçenekleri tek seferde üretir. Bu yardımcı tüm ana pencerelerde tutarlı davranış sağlar.

```rust
let options = zed::build_window_options(display_uuid, cx);
let window = cx.open_window(options, |window, cx| {
    cx.new(|cx| Workspace::new(/* ... */, window, cx))
})?;
```

`build_window_options` şunları yapar:

- `display_uuid` ile uygun display'i bulur (önceki oturumdan kalan ekran).
- `ZED_WINDOW_DECORATIONS=server|client` env override'ı varsa onu kullanır.
- Aksi halde `WorkspaceSettings::window_decorations` ayarına başvurur (kullanıcı tercihi).
- `TitlebarOptions { appears_transparent: true, traffic_light_position: (9,9) }` ile macOS'a uygun traffic light konumu kurar.
- `focus: false, show: false, kind: Normal` ayarlar — pencere içerik hazır olduğunda görünür hâle getirilecek.
- `window_background` değerini aktif temadan alır (`cx.theme().window_background_appearance()`).
- Linux/FreeBSD'de app icon ekler.
- macOS native tabbing istenirse `tabbing_identifier: Some("zed")` verir.

Modal, About, küçük yardımcı pencereler gibi tek seferlik kullanımlarda `build_window_options` kullanılmaz; doğrudan `WindowOptions` inşa edilir. Örneğin `crates/zed/src/zed.rs::about` şu seçenekleri kurar:

- Centered bounds (`WindowBounds::centered(...)`).
- `appears_transparent: true` — custom render için.
- `is_resizable: false`, `is_minimizable: false` — küçük modal pencere davranışı.
- `kind: Normal`.

## 6.3. Display ve Çoklu Monitor

Bağlı ekranların listesi `cx.displays()` ile alınır; her `Display` ekranın kimliği, global koordinat sistemindeki konum ve boyutu, görünür (taskbar/dock kesilmiş) alan ve kalıcı UUID gibi bilgileri taşır. UUID, kullanıcının ekranı çıkarıp tekrar takması gibi durumlarda aynı monitörü güvenilir biçimde tanımak için kullanılır.

```rust
for display in cx.displays() {
    let id = display.id();
    let bounds = display.bounds();       // tüm ekran rect'i
    let visible = display.visible_bounds(); // taskbar/dock hariç
    let uuid = display.uuid().ok();      // restore için kalıcı kimlik
}
```

Pencereyi belirli bir ekranda açmak için `WindowOptions.display_id` ve `window_bounds` birlikte verilir:

```rust
WindowOptions {
    display_id: Some(display.id()),
    window_bounds: Some(WindowBounds::Windowed(bounds)),
    ..Default::default()
}
```

`Bounds` her zaman global ekran koordinatlarındadır (ekrana göre değil, tüm masaüstüne göre). Otomatik merkezleme için `WindowBounds::centered(size, cx)` ana display üstüne merkezlenmiş bir bounds üretir; elle konumlandırma gerekiyorsa `Bounds::new(origin, size)` kullanılır.

## 6.4. WindowKind Davranışı

`WindowKind` pencerenin işletim sistemine kendini ne olarak tanıttığını belirler. Sıralama, z-order, fokus alma davranışı, taskbar'da görünme — hepsi buna göre değişir.

- **`Normal`** — Ana uygulama penceresi. Taskbar/Dock'ta görünür, normal pencere kısayolları geçerlidir.
- **`PopUp`** — Diğer pencerelerin üstünde duran, geçici/bildirim amaçlı pencere. Taskbar'da görünmez. Zed bildirim pencerelerinde (call davet, kayıt vs.) bu tür kullanılır.
- **`Floating`** — Parent pencerenin üstünde sabitlenmiş floating panel. Tools/inspector benzeri ek paneller için uygundur.
- **`Dialog`** — Parent pencereyle etkileşimi bloklayan modal platform diyaloğu. "Kaydedilmedi, çıkmak istediğine emin misin?" gibi onay diyalogları bu türdür.
- **`LayerShell`** — Yalnızca Linux Wayland (feature aktif) altında geçerli. Dock, top bar, wallpaper gibi [compositor yüzeyleri](#614-layer-shell-ve-özel-platform-pencereleri) için kullanılır.

Bildirim/popup pencerelerinde tipik `WindowOptions` kombinasyonu, OS'tan bağımsız tutarlı bir görünüm üretir:

```rust
WindowOptions {
    titlebar: None,                                              // titlebar yok
    kind: WindowKind::PopUp,                                     // taskbar dışı, üstte
    focus: false,                                                // odak çalmasın
    show: true,                                                  // hemen görün
    is_movable: false,                                           // konum sabit
    window_background: WindowBackgroundAppearance::Transparent,  // kendi arka planı
    window_decorations: Some(WindowDecorations::Client),         // kabuk uygulamada
    ..Default::default()
}
```

Zed örnekleri: `crates/agent_ui/src/ui/agent_notification.rs`, `crates/collab_ui/src/collab_ui.rs`.

## 6.5. Başlık Çubuğu ve Pencere Dekorasyonu

Başlık çubuğu ve pencere dekorasyonu birbirine yakın görünse de iki ayrı kavramdır ve hangi platformlarda anlam taşıdıkları farklıdır:

- **`TitlebarOptions`** — macOS ve Windows tarafında native başlık çubuğu görünümünü kontrol eder. Pencere başlığı, macOS traffic-light butonlarının konumu, "appears transparent" gibi seçenekler buradadır.
- **`WindowDecorations`** — Linux/Wayland/X11 tarafında pencere kabuğunun (sınır, başlık çubuğu, kontrol butonları) **compositor mı** çizeceğini (Server) yoksa **uygulamanın kendi mi** çizeceğini (Client) belirler.

GPUI'de bunlar iki ayrı enum'la temsil edilir:

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

İkisi arasındaki fark önemlidir:

- `WindowDecorations` — pencere açılırken **istenen** moddur (`WindowOptions.window_decorations`).
- `Decorations` — pencerenin o anki **gerçek** durumudur ve `window.window_decorations()` ile okunur. İstek ile fiili durum farklı olabilir (örn. Wayland compositor'ı SSD desteklemiyorsa istek `Server` olsa bile sonuç `Client`'a düşer).

Bu yüzden tasarımda istenen mod değil, render anındaki fiili `Decorations` esas alınır.

Zed kullanıcı ayarı:

```json
{
  "window_decorations": "client"
}
```

Env override (yeniden başlatma gerektirmez):

```sh
ZED_WINDOW_DECORATIONS=server
ZED_WINDOW_DECORATIONS=client
```

Zed settings tipi `settings_content::workspace::WindowDecorations` yalnızca `client` ve `server` değerlerini destekler; default `client` olarak gelir.

## 6.6. Custom Titlebar Nasıl Tanımlanır

Custom titlebar, sistem başlık çubuğu yerine uygulama içinde çizilen bir başlık alanıdır. Bu yol, pencere kabuğuyla içeriği tek tasarım dilinde birleştirmek (örn. tema renkleriyle uyumlu başlık, başlığın içine entegre arama, tab bar gibi yapılar) için seçilir. İlk adım sistem titlebar'ını devre dışı bırakmaktır:

```rust
cx.open_window(
    WindowOptions {
        titlebar: None,
        ..Default::default()
    },
    |_, cx| cx.new(|_| MyView),
)?;
```

Root view içinde başlık alanı kendi elementleriyle çizilir:

```rust
div()
    .flex()
    .flex_col()
    .size_full()
    .child(
        h_flex()
            .window_control_area(WindowControlArea::Drag) // pencereyi sürüklenebilir kıl
            .h(px(34.))
            .child("Başlık")
    )
    .child(content)
```

Custom titlebar çizilirken `window_control_area` çağrısı özellikle Windows'ta kritiktir. Windows kabuğu, pencere yönetim olaylarını (sürükle, maximize, close butonu) hangi piksel bölgesinin temsil ettiğini ayrı bir hit-test mesajıyla sorar. `window_control_area` bu bölgeleri işaretler:

- **`WindowControlArea::Drag`** — Sürüklenebilir başlık alanı (genellikle titlebar arka planı).
- **`WindowControlArea::Close`** — Native close hit-test alanı.
- **`WindowControlArea::Max`** — Maximize/restore hit-test alanı.
- **`WindowControlArea::Min`** — Minimize hit-test alanı.

Bu işaretlemeler olmadan custom titlebar Windows'ta sürüklenmez veya AeroSnap çalışmaz.

Zed gibi büyük bir workspace pencere yapısı kurulurken titlebar'ı sıfırdan yazmaktansa `PlatformTitleBar` bileşeni kullanılır; platform farklılıklarını hazır biçimde halleder:

```rust
let platform_titlebar = cx.new(|cx| PlatformTitleBar::new("my-titlebar", cx));

platform_titlebar.update(cx, |titlebar, _| {
    titlebar.set_children([my_left_or_center_content.into_any_element()]);
});

platform_titlebar.into_any_element()
```

`PlatformTitleBar` aşağıdakileri otomatik üstlenir:

- Linux client-side decoration için sol/sağ pencere kontrol butonları.
- Windows için pencere kontrol butonları.
- macOS traffic-light padding'i ve double-click davranışı (titlebar'a çift tıklayınca minimize/zoom).
- Linux'ta double-click ile zoom/maximize.
- Başlık çubuğu drag alanı.
- Linux'ta sağ-tık ile window menu açma.
- Sidebar açıkken kontrol butonları ve köşe yuvarlamalarının uyumlandırılması.

## 6.7. Kontrol Butonları Nasıl Yönetilir

Pencerenin kapat–küçült–büyüt kontrol butonları her platformda farklı çizilir; bu farklar kullanıcının "doğru görünüm" beklentisinden kaynaklanır (macOS solda traffic light, Windows sağda büyük caption butonlar, Linux'ta dağıtım/desktop ortamına göre değişen düzen):

- **macOS** — Native traffic light butonları sistem tarafından çizilir; Zed sadece padding ve `traffic_light_position` ile bunların konumunu ayarlar.
- **Windows** — `platform_title_bar::platforms::platform_windows::WindowsWindowControls` caption butonlarını uygulama içinde çizer; her butonun `WindowControlArea` ile native hit-test alanına bağlanması gerekir (yoksa AeroSnap ve Windows snap layouts çalışmaz).
- **Linux** — `platform_title_bar::platforms::platform_linux::LinuxWindowControls`, `WindowButtonLayout` ve `WindowControls` bilgisine göre close/min/max butonlarını çizer.

Sol veya sağ kenara hazır kontrol grubu yerleştirmek için ortak fonksiyonlar vardır:

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

Close butonu doğrudan `window.remove_window()` çağırmaz. Zed'de kapatma bir **action** olarak dispatch edilir:

```rust
window.dispatch_action(workspace::CloseWindow.boxed_clone(), cx);
```

Bu yaklaşımın sebebi, kapatma akışında dirty buffer kontrolü, "kaydet?" onayı, workspace shutdown, keybinding ile gelen close — hepsinin **aynı yol**dan geçmesidir. Direkt `remove_window` çağrılırsa bu adımlar atlanır ve kullanıcı kaydedilmemiş değişiklikleri sessizce kaybedebilir.

### Linux `WindowButtonLayout`

Linux'ta buton düzeni desktop ortamına (GNOME/KDE/diğer) göre değişir. GPUI bu düzeni `WindowButtonLayout` ile temsil eder:

- `WindowButton::{Minimize, Maximize, Close}` üç buton tipidir; layout, sol ve sağ taraf için ayrı `Option<WindowButton>` slot dizileri taşır.
- Slot başı azami sayı `gpui::MAX_BUTTONS_PER_SIDE: usize = 3` (`platform.rs:457`) ile sabittir; `WindowButtonLayout::{left, right}` bu sayıda elementli dizidir.
- Platformdan `cx.button_layout()` ile gelir.
- GNOME tarzı `"close,minimize:maximize"` formatı (sol: close; sağ: minimize, maximize) parse edilebilir.
- Default Linux fallback: sağda minimize, maximize, close.
- `TitleBarSettings` içinde kullanıcı override'ı tanımlanabilir; `TitleBar` bu override'ı `PlatformTitleBar::set_button_layout` ile geçirir.

## 6.8. Client-Side Decoration ve Resize

Client-side decoration (CSD), pencerenin sınırlarını, başlık çubuğunu, kontrol butonlarını ve gölgesini compositor yerine uygulamanın kendisinin çizmesi demektir. Bu yaklaşımın avantajı tasarım birliği (pencere kabuğu uygulama temasıyla uyumlu görünür), maliyeti ise resize bölgesi, drag alanı, gölge hesabı gibi konuların uygulama tarafından üstlenilmesidir.

Zed'in hazır CSD wrapper'ı:

```rust
workspace::client_side_decorations(element, window, cx, border_radius_tiling)
```

Bu wrapper içeride şu işleri yapar:

- `window.window_decorations()` ile o anki fiili decoration modunu okur.
- Client decoration ise `window.set_client_inset(theme::CLIENT_SIDE_DECORATION_SHADOW)` çağırarak pencere içeriğinin gölge kadar içeri çekilmesini sağlar.
- Server decoration ise inset'i `0` yapar (compositor zaten her şeyi çizecek).
- `window.client_inset()` ile platform penceresine en son set edilen inset değeri okunabilir; wrapper'ın padding/shadow hesabı bu değerle uyumlu tutulur.
- Tiling durumuna göre uygun kenar/köşe yuvarlamalarını kaldırır (snap edildiğinde köşeler düz olmalı).
- Border ve shadow çizimi yapar.
- Kenar ve köşe bölgelerinde mouse cursor'unu uygun resize cursor'una çevirir.
- Mouse down olaylarında `window.start_window_resize(edge)` çağırarak compositor'a resize'ı devreder.

Kendi CSD wrapper'ını yazmak gerekirse aynı prensiplerin uygulanması beklenir:

1. Fiili decoration modu `window.window_decorations()` ile okunur.
2. Client moddaysa gölge ve görünmez resize alanı için gerekli kadar `set_client_inset` verilir.
3. Tiling durumu kontrol edilir; ilgili kenara/köşeye radius, padding veya shadow uygulanmaz (snap edildiğinde estetik kaybı olmasın diye).
4. Resize bölgelerinde `ResizeEdge` hesaplanır ve cursor'u uygun resize tipine çevrilir.
5. Sürükleme için titlebar'a `WindowControlArea::Drag` verilir; alternatif olarak Linux/macOS'ta `window.start_window_move()` çağrılır.

### Linux'ta SSD/CSD geçişi

Linux'ta server-side decoration her zaman mümkün olmayabilir; bu durum compositor desteğine bağlıdır:

- **Wayland** — Compositor decoration protocol sağlamazsa, "server" isteği "client"a düşer (sweetnoise gibi minimal compositor'larda yaygındır).
- **X11** — Compositor yoksa, client-side decoration server-side'a düşebilir (gölge desteklenmediği için).

Bu yüzden pencere açarken istenen mod değil, her render'da fiili `window.window_decorations()` sonucu esas alınır; UI buna göre kendini ayarlamalıdır.

## 6.9. Platforma Göre Dekorasyon Davranışı

Aynı `WindowOptions` ve `TitlebarOptions` her platformda farklı sistem API'lerine eşlenir; aşağıda her platformun bu seçenekleri nasıl yorumladığı özetlenir.

#### macOS

- `TitlebarOptions::appears_transparent = true` pencerenin style mask'ine `NSFullSizeContentViewWindowMask` ekler; içerik titlebar'ın altına kadar uzanabilir.
- `traffic_light_position` native close/min/zoom butonlarının konumunu özelleştirir.
- `titlebar_double_click()` titlebar'a çift tıklama davranışını (zoom/minimize, sistem tercihine göre) yürütür.
- `start_window_move()` native `performWindowDragWithEvent` çağrısını yapar.
- `tabbing_identifier` verilirse native window tabbing açılır (aynı identifier'a sahip pencereler tek tab grubunda toplanır).
- `WindowDecorations` macOS'ta pratikte no-op gibi davranır; titlebar davranışı `TitlebarOptions` ile belirlenir.

#### Windows

- `TitlebarOptions::appears_transparent` custom/full content titlebar için kullanılır (içerik titlebar bölgesine taşar).
- Caption butonlarının native hit-test davranışı `WindowControlArea` üzerinden `HTCLOSE`, `HTMAXBUTTON`, `HTMINBUTTON`, `HTCAPTION` olarak platform event katmanında eşlenir; AeroSnap ve snap layouts bu hit-test'lere dayanır.
- `WindowBackgroundAppearance::MicaBackdrop` ve `MicaAltBackdrop`, DWM backdrop attribute API'leri (`DWMSBT_MAINWINDOW`, `DWMSBT_TABBEDWINDOW`) ile uygulanır.
- `WindowControls` çizimi Zed tarafında Windows-özgü component ile yapılır.

#### Linux/FreeBSD — Wayland

- `WindowDecorations::Server` xdg-decoration protocol üzerinden istenir.
- Compositor SSD desteklemiyorsa istek otomatik olarak client-side'a düşürülür.
- `window_controls()` Wayland capabilities bilgisine göre gelir: fullscreen, maximize, minimize, window menu.
- `show_window_menu`, `start_window_move`, `start_window_resize` çağrıları xdg_toplevel üzerinden compositor'a devredilir.
- Blur için compositor `blur_manager` protocol'ünü destekliyorsa `Blurred` yüzeyde gerçek blur commit edilir; aksi halde istek görsel olarak fark yaratmaz.

#### Linux/FreeBSD — X11

- `request_decorations` `_MOTIF_WM_HINTS` özelliğine yazar.
- Client-side decoration ekran gölge çizebilen bir compositor gerektirir; compositor yoksa SSD'ye düşülür.
- `show_window_menu` `_GTK_SHOW_WINDOW_MENU` client message'ı gönderir.
- Move/resize işlemleri `_NET_WM_MOVERESIZE` tarzı mesajla başlatılır.
- Tiling, fullscreen ve maximize state'leri `Decorations::Client { tiling }` sonucunu etkiler; UI bu durumlara göre köşe yuvarlamalarını kaldırır.

#### Web/WASM

- Web platformunda native pencere dekorasyonu kavramı yoktur; pencere zaten tarayıcı tarafından sağlanır.
- `WindowBackgroundAppearance` web window için opaque/no-op kabul edilir.
- Uygulama entry point'inde `gpui_platform::web_init()` çağrısı yapılır.

## 6.10. Blur, Transparency ve Mica Yönetimi

`WindowBackgroundAppearance`, pencere arkaplanının nasıl ele alınacağını belirler. Bu, modern UI'ların arkasındaki masaüstü/duvar kağıdı içeriğinin görünmesi, blur efektleriyle camlaştırılmış paneller veya Windows 11'in Mica materyali gibi sistem materyallerinin kullanılması gibi senaryolar için tasarlanmıştır.

```rust
pub enum WindowBackgroundAppearance {
    Opaque,
    Transparent,
    Blurred,
    MicaBackdrop,
    MicaAltBackdrop,
}
```

Her varyantın anlamı:

- **`Opaque`** — Pencerenin arkasını göstermeyen düz dolu arkaplan. Tipik uygulama penceresi.
- **`Transparent`** — Pencere arkaplanı saydam; içerik tarafından çizilen renkler ekranda göründüğü gibi kalır, çizilmeyen yerler doğrudan altta kalan masaüstü içeriğini gösterir.
- **`Blurred`** — Arkaplan saydam ama altındaki içerik OS tarafından bulanıklaştırılır; "buzlu cam" görünümü oluşur. Sistem desteğine bağlıdır.
- **`MicaBackdrop`**, **`MicaAltBackdrop`** — Windows 11'e özgü Mica materyali. Sistem teması ve wallpaper'a göre yumuşak gölgeli arkaplan üretilir.

### Zed tema ayarı

```json
{
  "experimental.theme_overrides": {
    "window_background_appearance": "blurred"
  }
}
```

Zed tema schema'sı şu an için yalnızca `opaque`, `transparent`, `blurred` değerlerini destekler. `MicaBackdrop` ve `MicaAltBackdrop` GPUI seviyesinde mevcut olmasına rağmen kullanıcı ayarına henüz expose edilmemiştir.

### Zed akışı

- Tema refine edilirken `WindowBackgroundContent` → `WindowBackgroundAppearance` dönüşümü yapılır.
- Ana pencere açılırken `window_background: cx.theme().window_background_appearance()` set edilir.
- Settings ya da tema değişiminde `crates/zed/src/main.rs` tüm açık pencereler üzerinde `window.set_background_appearance(...)` çağırır; mevcut pencereler de yeni görünüme geçer.
- UI tarafında `ui::styles::appearance::theme_is_transparent(cx)` yardımcı fonksiyonu transparent veya blurred modda `true` döner; opak arkaplan varsayan bileşenler buna göre düzeltilmiş bir arkaplan rengi kullanır.

### Platform davranışı

- **macOS**
  - `Opaque` — native pencere opaque olarak işaretlenir.
  - `Transparent` ve `Blurred` için renderer transparency açılır.
  - macOS 12 öncesinde blur, `CGSSetWindowBackgroundBlurRadius` ile sabit 80 radius kullanır.
  - macOS 12 ve sonrasında `NSVisualEffectView` tabanlı blur view eklenir/kaldırılır.
- **Windows**
  - `Opaque` — DWM composition attribute kapatılır.
  - `Transparent` — composition state transparent.
  - `Blurred` — acrylic/blur benzeri composition attribute.
  - `MicaBackdrop` — DWM `DWMSBT_MAINWINDOW` (ana pencere için).
  - `MicaAltBackdrop` — DWM `DWMSBT_TABBEDWINDOW` (tab içeren pencereler için, biraz farklı ton).
- **Wayland** — Compositor `blur_manager` protocol'ünü destekliyorsa `Blurred` yüzeye blur commit edilir; desteklemiyorsa istek görsel olarak fark yaratmayabilir.
- **X11** — Transparent/blur renderer transparency'yi etkiler; ancak gerçek backdrop blur window manager veya compositor desteğine bağlıdır.

### Pratik karar tablosu

- *Tema/ana pencere* için tipik kullanım `cx.theme().window_background_appearance()` — kullanıcı tema ayarı otomatik uygulanır.
- *Geçici overlay/bildirim pencereleri* için `Transparent` — root container'ın gerçek arkaplanı UI içinde çizilir, kenarlar sistem masaüstüne bakar.
- *Windows 11'e özgü Mica* görünümü için doğrudan `WindowBackgroundAppearance::MicaBackdrop` veya `MicaAltBackdrop` kullanılır; Zed tema ayarına henüz bağlanmadığı için kod tarafında set edilmesi gerekir.
- *Blur kullanılan pencerede* root background gerçekten yarı saydam olmalı; tamamen opak bir UI çizilirse blur ekrana yansımaz ve fark hissedilmez.

## 6.11. Pencere Üzerinden Yapılan İşlemler

`Window` üzerinde tanımlı method'lar, açık bir pencerenin gözlemlenmesi (sorgulama) ve eylem (komut) ihtiyaçlarını karşılar. Sık kullanılan başlıca API'ler iki ana kümeye ayrılır.

**Boyut, konum ve durum sorgusu**

- `window.bounds()` — Global ekran koordinatlarında pencere bounds'u.
- `window.window_bounds()` — Tekrar açma/restore için `WindowBounds` (windowed/maximized/fullscreen ayrımıyla).
- `window.inner_window_bounds()` — Linux'ta CSD shadow inset hariç bounds.
- `window.viewport_size()` — Çizim yapılabilecek içerik alanının boyutu.
- `window.is_fullscreen()`, `window.is_maximized()` — Anlık pencere durumu.

**Pencere üzerinde komutlar**

- `window.resize(size)` — İçerik boyutunu değiştirir.
- `window.activate_window()` — Pencereyi öne getirir.
- `window.minimize_window()` — Simge durumuna küçültür.
- `window.zoom_window()` — Maximize (macOS'ta "zoom") yapar.
- `window.toggle_fullscreen()` — Tam ekran modunu açar/kapatır.
- `window.remove_window()` — Pencereyi kapatır (close action akışı kullanılmıyorsa).
- `window.set_window_title(title)` — Başlık metnini günceller.
- `window.set_app_id(app_id)` — Linux app id'sini değiştirir (taskbar gruplama için).
- `window.set_background_appearance(appearance)` — Arkaplan modunu canlı olarak değiştirir (tema değişimi).
- `window.set_window_edited(true/false)` — macOS'ta "kaydedilmemiş değişiklik" göstergesi (close butonu üzerinde nokta).
- `window.set_document_path(path)` — macOS document accessibility ve proxy icon için ilişkili dosya yolu.
- `window.show_window_menu(position)` — Linux'ta titlebar sağ-tık menüsü.
- `window.start_window_move()` / `window.start_window_resize(edge)` — Compositor'a sürükle/yeniden boyutlandırma jestini devretmek için.
- `window.request_decorations(WindowDecorations::Client | Server)` — Decoration modunu istemek için.
- `window.window_decorations()` — O anki fiili decoration modunu okur.
- `window.window_controls()` — Pencere kontrol butonları (kapat/min/max) ile ilgili yetenek bilgisi.
- `window.prompt(...)` — Native veya custom prompt diyaloğu açar.
- `window.play_system_bell()` — Sistem uyarı sesi.

### macOS native window tab API'leri

macOS'taki native pencere sekmeleri için ayrı method ailesi vardır. Bunlar yalnızca macOS'ta etkili çalışır; diğer platformlarda no-op davranır veya `None` döner.

- `window.tabbed_windows()` — Bu pencerenin bulunduğu tab grubundaki tüm pencereler.
- `window.tab_bar_visible()` — Tab bar şu anda görünür mü.
- `window.merge_all_windows()` — Tüm açık pencereleri tek tab grubuna birleştirir.
- `window.move_tab_to_new_window()` — Mevcut sekmeyi ayrı pencere olarak ayırır.
- `window.toggle_window_tab_overview()` — Tab overview ekranını açar/kapatır.
- `window.set_tabbing_identifier(...)` — Bu pencerenin hangi tab grubuna ait olduğunu belirler.

Native tabbing davranışı için 6.13.

## 6.12. Pencere Bounds Persist ve Restore

Kaynaklar: `crates/gpui/src/platform.rs::WindowBounds`, Zed tarafında `crates/workspace/src/persistence/`, `crates/workspace/src/workspace.rs` ve `crates/zed/src/zed.rs`.

Pencere bounds'unu kalıcılaştırmak (persist), kullanıcının önceki oturumdaki pencere konumu/boyutu/durumuyla aynı yere geri dönmesini sağlamak içindir. Bu işlem yalnızca pencere boyutunu değil, hangi durumda (windowed/maximized/fullscreen) olduğunu ve hangi ekranda açıldığını da kapsar.

```rust
pub enum WindowBounds {
    Windowed(Bounds<Pixels>),
    Maximized(Bounds<Pixels>),
    Fullscreen(Bounds<Pixels>),
}
```

Bu enum'un her varyantı içindeki `Bounds` **restore'a hazır** koordinatları taşır. Yani `Maximized` veya `Fullscreen` içine sarılmış bounds, kullanıcı pencereyi maximize/fullscreen'den çıkardığında dönülecek windowed boyuttur. Böylece "maximized iken kapattım, açtığımda yine maximized olsun, ama küçülttüğümde eski yerime gideyim" beklentisi karşılanır.

### Persist akışı

```rust
let bounds = window.inner_window_bounds();
serialize(bounds, display_uuid);
```

Zed varsayılan pencere boyutunu persist ederken `inner_window_bounds()` kullanır; workspace serialize sırasında bazı akışlarda `window.window_bounds()` tercih edilir. İkisi arasındaki fark platforma ve titlebar'ın bounds içine dahil edilip edilmediğine bağlıdır. Fullscreen/maximized durumlarında enum içindeki bounds, restore edilecek windowed bounds'u temsil eder. Display UUID'si ayrı kaydedilir çünkü kullanıcı oturumlar arasında monitör değiştirebilir veya ekranı çıkarabilir.

### Restore akışı

Workspace açılırken `zed::build_window_options` üstünde şu adımlar uygulanır:

1. Saklı `display_uuid`, `cx.displays()` listesindeki `display.uuid()` değerleriyle eşleştirilir.
2. Eşleşen display varsa `options.display_id` ona set edilir ve kayıtlı `WindowBounds` `options.window_bounds`'a yazılır.
3. Workspace'e özgü bounds yoksa global default window bounds okunur.
4. Hiç kayıt yoksa `WindowOptions.window_bounds = None` bırakılır; GPUI platforma uygun cascade/default bounds seçer.

### Değişiklikleri izlemek

Pencere bounds her değiştiğinde yeniden persist etmek gerekir; bunun için bir observer kurulur:

```rust
cx.observe_window_bounds(window, |this, window, cx| {
    let bounds = window.inner_window_bounds();
    this.persist_bounds(bounds);
}).detach();
```

Aynı şekilde `cx.observe_window_appearance(window, ...)` light/dark değişimini, `cx.observe_window_activation(window, ...)` foreground/background değişimini izler. `.detach()` observer'ı window/view ömrüne bağlar — abone kalıcı olarak yaşar.

### Tuzaklar

- `window.bounds()` (canlı ekran rect'i), `window.window_bounds()` ve `window.inner_window_bounds()` farklı değerler döndürebilir; restore/persist akışında hangi rect'in beklendiği Zed'in mevcut çağrı noktasına göre seçilir. Birbirine karıştırılan iki rect, restore'da pencerenin "biraz kayık" konuma açılmasına yol açar.
- Maximized/fullscreen enum'larının içindeki `Bounds<Pixels>` her zaman **restore size**'dır; ekranı doldursa bile bu değerin tutulması, kullanıcı normal moda döndüğünde eski boyutuna ulaşılmasını sağlar.
- Display UUID'si Linux/Wayland'de boş olabilir (`display.uuid().ok()` `None` döner); UUID yoksa display kimliği başka yollarla (display index, çözünürlük tespiti) yedeklenir veya restore tamamen atlanır.

## 6.13. Native Window Tabs ve SystemWindowTabController

macOS, birden çok top-level pencereyi tek pencere içindeki sekmelere dönüştürme yeteneği sunar (System Preferences → General → "Prefer tabs when opening documents" ayarı). Bu native window tabbing, Safari ve Finder'da görülen sistem davranışıdır. GPUI bunu iki katmanda destekler:

- **`WindowOptions::tabbing_identifier`** — Aynı identifier'a sahip pencerelerin sistem tarafından otomatik olarak tek tab grubuna alınmasına izin verir.
- **`SystemWindowTabController`** — GPUI global'i olarak açık native tab gruplarını ve görünürlük state'ini takip eder.

İlgili `Window` method'ları:

- `window.tabbed_windows() -> Option<Vec<SystemWindowTab>>` — Bu pencerenin yer aldığı tab grubundaki diğer pencerelerin listesi.
- `window.tab_bar_visible() -> bool` — Tab bar şu anda görünür mü.
- `window.merge_all_windows()` — Aynı tabbing_identifier'a sahip tüm açık pencereleri tek grupta birleştirir.
- `window.move_tab_to_new_window()` — Mevcut sekmeyi ayrı bir pencereye taşır.
- `window.toggle_window_tab_overview()` — macOS native tab overview ekranını açar/kapatır.
- `window.set_tabbing_identifier(Some(identifier))` — Pencerenin tab grubunu çalışma zamanında değiştirir.

### Hangi tab sistemi ne zaman kullanılır

- *Uygulama içi tablar* (editor sekmeleri, panel tabları, dosya sekmeleri) için **native tabbing kullanılmaz**; `workspace::Pane` ve `TabBar` ile uygulama içinde çizilen tablar tercih edilir. Bu tablar uygulama ile aynı tasarım dilinde olur ve cross-platform çalışır.
- *İşletim sistemi seviyesinde birden çok top-level pencereyi aynı sistem tab grubunda toplamak* gerekiyorsa (örn. birden fazla workspace penceresi tek macOS penceresi içinde sekmeler) `tabbing_identifier` verilir.

Native tab state'i platformdan gelir; Linux ve Windows üzerinde bu API'lerin bir kısmı no-op davranır veya `None` döner. Cross-platform uygulamalarda bu davranış fallback ile karşılanır.

### Tuzaklar

- **Native window tab ile uygulama içi pane tab farklı kavramlardır.** Persistence (kaydetme/restore) ve command routing (klavye/menü etkileşimi) ayrı yollardan akar; birinin davranışını diğeriyle eşitlemeye çalışmak karmaşık ve hatalıdır.
- **Window title değişikliğinde sekme başlığı da güncellenmelidir.** `window.set_window_title(...)` çağrısı tek başına bazı sürümlerde tab başlığını canlı olarak yenilemeyebilir; tab controller update akışı eşzamanlı olarak düşünülür.

## 6.14. Layer Shell ve Özel Platform Pencereleri

Linux Wayland compositor'larında "layer shell" adlı bir protocol vardır; bu protocol, ekrana yapışık dock, top bar, wallpaper, overlay HUD gibi *sıradan pencere olmayan* yüzeylerin oluşturulmasına izin verir. Normal Zed pencereleri her zaman `WindowKind::Normal` ile açılır; ancak Linux Wayland feature aktifken `WindowKind::LayerShell(LayerShellOptions)` kullanılarak bu özel yüzeylerden biri tanımlanabilir:

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

`LayerShellOptions` alanlarının anlamı:

- **`Layer`** — Yüzeyin compositor z-order'ında hangi katmanda olacağı. `Background` (wallpaper benzeri, en altta), `Bottom`, `Top`, `Overlay` (her şeyin üstünde).
- **`anchor`** — `layer_shell::Anchor` bitflag'i; yüzeyin ekranın hangi kenarlarına yapışacağı (`TOP`, `BOTTOM`, `LEFT`, `RIGHT` kombine edilir). Sadece bottom ile yapışmış surface bir dock olur; tüm dört kenara yapışmış surface tüm ekranı kaplar.
- **`exclusive_zone`** — Compositor'a "başka surface'ler bu alanı kapatmasın" der; örneğin bir dock için, diğer maximize pencereler dock'un altına gizlenmez.
- **`exclusive_edge`** — Exclusive zone'un hangi kenara uygulandığı.
- **`margin`** — CSS sırasına benzer şekilde top/right/bottom/left boşlukları.
- **`KeyboardInteractivity`** — Klavye girdisini nasıl alacağı: `None` (hiç almaz, HUD'lara uygun), `Exclusive` (modal gibi tüm girdiyi yakalar), `OnDemand` (kullanıcı yüzeye tıklayınca girdi alır).

Bu API yalnızca `#[cfg(all(target_os = "linux", feature = "wayland"))]` altında derlenir; diğer platformlarda mevcut değildir. Compositor layer-shell protocol'ünü desteklemiyorsa backend `LayerShellNotSupportedError` döndürür; uygulama tarafında bu hata yakalanıp `WindowKind::Normal` ile bir fallback pencere açılması planlanır.


---
