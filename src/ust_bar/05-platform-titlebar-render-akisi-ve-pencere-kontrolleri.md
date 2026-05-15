# Bölüm V — Platform titlebar render akışı ve pencere kontrolleri

Bu noktadan sonra başlık çubuğunun render davranışı, Linux/Windows/macOS farkları ve close/minimize/maximize bağları uygulanır.

## 11. Davranış modeli

### Sürükleme

Ana titlebar yüzeyi `WindowControlArea::Drag` ile işaretlenir. Ayrıca sol mouse
down/move akışıyla `window.start_window_move()` çağırır. Bu kombinasyon,
platforma bağlı titlebar drag davranışının tutarlı işlemesini sağlar.

Başlık çubuğuna koyduğunuz interaktif elementler kendi mouse down/click
olaylarında propagation'ı durdurmalıdır. Aksi halde buton, arama kutusu veya
menü tıklaması pencere sürükleme davranışıyla çakışabilir.

`should_move` state'i dört noktada düzenlenir
(`platform_title_bar.rs:200-220`):

- `on_mouse_down(Left, ...)` → `should_move = true`.
- `on_mouse_move(...)` → eğer `should_move` true ise **önce** `false`'a
  çekilir, **sonra** `window.start_window_move()` çağrılır. Tek-atışlık
  tetikleyici; her yeni drag için yeni bir mouse_down zincirine ihtiyaç
  vardır.
- `on_mouse_up(Left, ...)` → `should_move = false` (drag başlatılmadıysa
  da temizle).
- `on_mouse_down_out(...)` → `should_move = false` (titlebar dışına
  tıklanırsa state sızıntısını önle).

Linux pencere kontrol katmanı **üç ayrı `stop_propagation()` noktası**
kullanır (awk taraması ile çıkarılır; rg dağınık satırları toplamaz):

| Yer | Olay | Kaynak | Neyi engeller? |
| :-- | :-- | :-- | :-- |
| `LinuxWindowControls` h_flex container | `on_mouse_down(Left)` | `platform_linux.rs:50` | Buton grubuna basıldığında titlebar drag başlamasını. |
| `WindowControl` (her buton) | `on_mouse_move` | `platform_linux.rs:228` | Buton üzerinde mouse gezerken titlebar drag tetiklenmesini. |
| `WindowControl` `on_click` callback gövdesi | `cx.stop_propagation()` ilk satır | `platform_linux.rs:230` | Click event'inin yukarı kabarıp başka handler'lara ulaşmasını. Action dispatch'inden ÖNCE çalışır. |

Üçü birden olmadan: (1) buton üstüne mouse_down ile drag başlar, (2)
buton hover'larken mouse_move drag tetikler, (3) close action dispatch
edilirken aynı click PlatformTitleBar'a kabarıp `should_move = true`
yapar. Port hedefinde aynı üç noktaya **eşdeğer engeller** koymak
gerekir.

Windows tarafında `.occlude()` (`platform_windows.rs:128`) aynı amaca
hizmet eder ama tek satırlık ifade: caption butonu üzerinde tüm mouse
event'leri alt katmanlara sızdırmaz.

### Fullscreen render ayrımı

Fullscreen koşulu yalnız görünsel bir detay değildir; hangi child'ların
eklendiğini değiştirir (`platform_title_bar.rs:243-320`). `window.is_fullscreen()`
true ise sol tarafta macOS trafik ışığı padding'i de Linux sol kontrolleri de
eklenmez, sadece `.pl_2()` fallback'i kullanılır. Aynı render zincirinde sağ
taraf bloğu da `when(!window.is_fullscreen(), ...)` arkasındadır; yani sağ
caption kontrolleri ve Linux CSD sağ tık sistem pencere menüsü fullscreen'de
kurulmaz. `SystemWindowTabs` child'ı ise bu koşulun dışında, titlebar'ın
altına eklenmeye devam eder (`platform_title_bar.rs:322-325`).

Port hedefinde bu ayrımı tek bir "fullscreen padding'i değiştir" kuralına
indirgemeyin: fullscreen, hem sol/sağ pencere kontrol render'ını hem de Linux
CSD `window.show_window_menu(...)` bağını etkiler.

### Çift tıklama

Platform farkı Zed kaynağında ayrı işlenir:

- macOS: `window.titlebar_double_click()`
- Linux/FreeBSD: `window.zoom_window()`
- Windows: davranış platform caption/hit-test katmanına bırakılır.

Kendi uygulamanızda çift tıklamanın maximize yerine minimize gibi farklı bir
ayar izlemesini istiyorsanız bu bölüm parametreleştirilmelidir.

macOS tarafında `window.titlebar_double_click()` sabit "zoom" değildir.
`gpui_macos` platform impl'i `NSGlobalDomain/AppleActionOnDoubleClick`
değerini okur; `"None"` için hiçbir şey yapmaz, `"Minimize"` için
`miniaturize_`, `"Maximize"` ve `"Fill"` için `zoom_`, bilinmeyen değer
için de `zoom_` çağırır (`gpui_macos/src/window.rs:1668-1712`). Linux
tarafındaki `window.zoom_window()` çağrısı ise bu macOS kullanıcı ayarını
taklit etmez; doğrudan maximize/restore davranışıdır.

### Renk

`title_bar_color` Linux/FreeBSD tarafında aktif pencere için
`title_bar_background`, pasif veya move sırasında `title_bar_inactive_background`
kullanır. Diğer platformlarda doğrudan `title_bar_background` döner.

Bu davranış, başlık çubuğu ve sekme çubuğu arasında görsel ayrımı korur. Kendi
tema sisteminizde en az şu token'lar gerekir (awk
`cx\.theme\(\)\.colors\(\)\.X` taramasının tam çıktısı):

- `title_bar_background` — aktif Linux + tüm platformlar (`platform_title_bar.rs:66/71`, `system_window_tabs.rs:389`)
- `title_bar_inactive_background` — pasif/move durumundaki Linux (`platform_title_bar.rs:68`)
- `tab_bar_background` — native tab arka planı (`system_window_tabs.rs:390`)
- `border` — Linux tab kenarı ve plus butonu sınırı (`system_window_tabs.rs:181/353/479/525`)
- `ghost_element_background` — Linux `WindowControlStyle.background` default'u (`platform_linux.rs:120`)
- `ghost_element_hover` — Linux WindowControl + Windows non-close hover (`platform_linux.rs:121`, `platform_windows.rs:117`)
- `ghost_element_active` — Windows non-close active state (`platform_windows.rs:119`)
- `icon` — Linux WindowControl glyph rengi (`platform_linux.rs:122`)
- `icon_muted` — Linux WindowControl hover glyph rengi (`platform_linux.rs:123`)
- `text` — Windows caption glyph rengi default (`platform_windows.rs:118/120`)
- **`drop_target_background`** — **tab drag-over hedef vurgusu** (`system_window_tabs.rs:205`)
- **`drop_target_border`** — **tab drag-over kenar vurgusu** (`system_window_tabs.rs:206`)

Son iki token, üzerine başka bir sekme sürüklendiğinde drop hedefini
vurgulamak için kullanılır; tema'da eksik kalırsa drag-and-drop görsel
geri-besleme çalışmaz.

### Yükseklik

Zed `platform_title_bar_height(window)` kullanır:

- Windows: sabit `32px`.
- Diğer platformlar: `1.75 * rem_size`, minimum `34px`.

Bu değer hem titlebar hem Windows buton yüksekliği hem de bazı yardımcı
başlıkların hizalaması için ortak kullanılmalıdır.

## 12. Buton yerleşimi ve ayar yönetimi

Linux/FreeBSD CSD tarafında buton sırası `WindowButtonLayout` ile belirlenir.
GPUI tipi iki sabit slot dizisi taşır:

```rust
pub struct WindowButtonLayout {
    pub left: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE],
    pub right: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE],
}
```

`WindowButton` değerleri:

- `Minimize`
- `Maximize`
- `Close`

GPUI tarafındaki `WindowButton` da dış API'dir
(`gpui/src/platform.rs:425-444`): `#[derive(Debug, Clone, Copy, PartialEq,
Eq, Hash)]` taşır ve `pub fn id(&self) -> &'static str` ile sırasıyla
`"minimize"`, `"maximize"`, `"close"` stable element id'lerini döndürür.
Bu id'ler Linux `WindowControl::new(...)` çağrılarında doğrudan kullanıldığı
için port hedefinde key/id uyumu korunmalıdır.

`WindowButtonLayout` üç public öğe ile gelir (`gpui/src/platform.rs:457-486`):

| Öğe | İmza / değer | Davranış notu |
| :-- | :-- | :-- |
| `MAX_BUTTONS_PER_SIDE` | `pub const MAX_BUTTONS_PER_SIDE: usize = 3` | Her taraf en fazla üç slot tutar. |
| `WindowButtonLayout::linux_default` | `pub fn linux_default() -> Self` | Sol taraf boş, sağ taraf `Minimize, Maximize, Close`. Yalnız Linux/FreeBSD cfg'inde derlenir. |
| `WindowButtonLayout::parse` | `pub fn parse(layout_string: &str) -> Result<Self>` | GNOME tarzı `left:right` string'i okur; `:` yoksa sol boş, tüm string sağ taraf sayılır. |

`parse(...)` davranışının iki ince noktası var (`gpui/src/platform.rs:486-541`):
tanınmayan adlar, en az bir geçerli buton varsa **yok sayılır**; tüm string
geçersizse hata döner. Aynı buton iki tarafta veya aynı tarafta tekrar edilirse
ilk görülen slot tutulur, tekrarlar atlanır. Bu nedenle `"close,foo"` geçerli
layout üretir, `"foo"` hata verir.

Render tarafında side'ın varlığı yalnız ilk slota bakılarak belirlenir:
`render_left_window_controls(...)` için `button_layout.left[0].is_none()`,
`render_right_window_controls(...)` için `button_layout.right[0].is_none()`
ise tüm taraf `None` döner (`platform_title_bar.rs:132-135`, `163-166`).
Manuel layout verirken `[None, Some(Close), ...]` gibi bir dizi o tarafı
tamamen gizler. İlk slot doluysa içerdeki sonraki `None` slotlar
`LinuxWindowControls` render'ındaki `filter_map(|b| *b)` ile sadece atlanır
(`platform_linux.rs:31-34`).

Zed ayar katmanı üç kullanım biçimi sunar:

| Ayar değeri | Sonuç |
| :-- | :-- |
| `platform_default` | Platform/desktop config takip edilir; `cx.button_layout()` fallback'i kullanılır. |
| `standard` | Zed Linux fallback'i: sağda minimize, maximize, close. |
| GNOME formatında string | Örneğin `"close:minimize,maximize"` veya `"close,minimize,maximize:"`. |

Uygulama katmanında bu ayarı saklamak istiyorsanız kullanıcı ayarınızı önce
`WindowButtonLayout` karşılığına çevirin, sonra render sırasında
`title_bar.set_button_layout(layout)` çağırın.

Zed `TitleBar` bu değişimi `cx.observe_button_layout_changed(window, ...)` ile
izleyip yeniden render tetikler. Kendi uygulamanızda desktop button layout
değişikliklerini canlı izlemek istiyorsanız aynı observer desenini kullanın.

**`Platform::button_layout()` trait default'u `None` döndürür**
(`gpui/src/platform.rs:162-164`); bu default'u **yalnızca Linux/FreeBSD
platform impl'i** override edip GTK / GNOME desktop ayarını (örn.
`gtk-decoration-layout`) okur. Yani `cx.button_layout()` çağrısı
Windows ve macOS'ta daima `None`'dur. `PlatformTitleBar::effective_button_layout(...)`
de zaten Linux + `Decorations::Client` dışındaki kombinasyonlarda
`None` döndürür (`platform_title_bar.rs:86-98`). Sonuç: button layout
ayar zinciri yalnızca Linux/FreeBSD CSD penceresinde anlamlıdır;
diğer platformlarda `set_button_layout(...)` etkisizdir.

Linux tarafında bu değer `gpui_linux` ortak state'inde başta
`WindowButtonLayout::linux_default()` olarak tutulur
(`gpui_linux/src/linux/platform.rs:143-150`) ve `Platform::button_layout()`
bu common state'i `Some(...)` olarak döndürür (`gpui_linux/src/linux/platform.rs:619-620`).
Canlı desktop değişimi XDP `ButtonLayout` olayıyla gelir: Wayland ve X11
client'ları gelen string'i `WindowButtonLayout::parse(...)` ile okur,
parse hata verirse yine `linux_default()`'a düşer, sonra her pencere için
`window.set_button_layout()` çağırır (`gpui_linux/src/linux/wayland/client.rs:636-645`,
`gpui_linux/src/linux/x11/client.rs:493-500`). Bu çağrı da
`on_button_layout_changed` callback'ini tetikler; Zed `TitleBar::new(...)`
içinde bu callback'i `cx.observe_button_layout_changed(window, ...)` ile
`cx.notify()`'a bağlar (`title_bar/src/title_bar.rs:441`).

## 13. Butonları uygulama katmanına bağlama

### Close davranışı

`PlatformTitleBar` kendi render'ında close action'ı şu şekilde sabitler:

```rust
let close_action = Box::new(workspace::CloseWindow);
```

Bu yüzden kendi uygulamanızda close butonunun farklı bir varlığı kapatmasını
istiyorsanız üç seçenek vardır:

1. `PlatformTitleBar`'ı port edip `close_action` alanı ekleyin.
2. Zed'in serbest fonksiyonlarını kullanıp `render_left_window_controls` ve
   `render_right_window_controls` çağrılarına kendi `Box<dyn Action>` değerinizi
   verin.
3. Linux butonlarını doğrudan `LinuxWindowControls::new(...)` ile üretip close
   action'ı orada verin.

Örnek uygulama action eşleşmesi:

```rust
actions!(app, [CloseActiveWorkspace, NewWorkspaceWindow]);

let close_action: Box<dyn Action> = Box::new(CloseActiveWorkspace);
let controls = platform_title_bar::render_right_window_controls(
    cx.button_layout(),
    close_action,
    window,
);
```

Close action'ının ne kapatacağı uygulama modelinize göre belirlenmelidir:

| Uygulama varlığı | Close action anlamı |
| :-- | :-- |
| Tek pencereli app | Pencereyi kapat veya quit on last window politikasını işlet. |
| Workspace tabanlı app | Aktif workspace'i kapat, son workspace ise pencereyi kapat. |
| Doküman tabanlı app | Aktif dokümanı kapat, kirli state varsa kaydetme modalı aç. |
| Çok hesaplı/dashboard app | Aktif tenant veya view değil, pencere/shell lifecycle'ını kapat. |

### Minimize ve maximize

Linux `WindowControl` minimize ve maximize işlemlerini doğrudan `Window` üstünden
yapar:

- `window.minimize_window()`
- `window.zoom_window()`

Bu butonlar uygulama action katmanına uğramaz. Eğer maximize/minimize öncesi
telemetry, policy veya layout persist istiyorsanız `WindowControl`'ü port edip
bu işlemleri kendi action'ınıza yönlendirin.

Windows tarafında butonlar click handler ile pencere fonksiyonu çağırmaz.
`WindowControlArea::{Min, Max, Close}` hit-test alanı üretir; platform katmanı
native caption davranışını uygular. Bu yüzden Windows buton davranışını action
katmanına almak Linux'e göre daha fazla platform uyarlaması gerektirir.

`window.window_controls()` capability yüzeyi de platforma göre değişebilir.
**`WindowControls` struct'ı dört alan taşır** (`gpui/src/platform.rs:402-413`):
`fullscreen`, `maximize`, `minimize`, `window_menu` — `close` alanı **yoktur**.
Bu, "close her zaman desteklenir" tasarım kararıdır ve `LinuxWindowControls`
filter'ındaki koşulsuz `WindowButton::Close => true` arm'ı bu yüzden gerekir
(`platform_linux.rs:38`). `platform_title_bar` crate'inin gerçekten okuduğu
capability'ler: `minimize`, `maximize` (Linux buton filtresi),
`window_menu` (sağ tık window menu); `fullscreen` ise bu crate içinde okunmaz.
Trait default'u "her şey destekleniyor" kabul eder (`WindowControls::default`,
`gpui/src/platform.rs:413-422`), fakat Wayland `xdg_toplevel::Event::WmCapabilities`
geldiğinde önce tüm bayrakları `false` yapar, sonra compositor'ın bildirdiği
`Maximize`, `Minimize`, `Fullscreen`, `WindowMenu` capability'lerini tek tek
`true` yapar (`gpui_linux/src/linux/wayland/window.rs:788-817`). Bu değer
sonraki configure'da `state.window_controls` içine alınır ve appearance
callback'iyle rerender tetiklenir (`gpui_linux/src/linux/wayland/window.rs:601-612`).
Sonuç:

- `LinuxWindowControls` minimize/maximize butonlarını bu capability'ye göre
  filtreler; close her zaman render edilebilir (`platform_linux.rs:30-39`).
- Linux CSD titlebar sağ tık window menu handler'ı sadece
  `supported_controls.window_menu` true ise eklenir (`platform_title_bar.rs:309-315`).
- Port ederken `WindowControls::default()` değerini kalıcı gerçek sanma;
  özellikle Wayland'da capability configure olayı geldikten sonra değişebilir.


---

