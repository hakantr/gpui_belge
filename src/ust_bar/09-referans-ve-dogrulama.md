# Bölüm IX — Referans ve doğrulama

Detaylı public API envanteri ve kaynak doğrulama komutları, okuma akışını bölmemesi için başvuru bölümünde kalır.

## 21. Public API envanteri

Bu bölümde `pub` iki anlama ayrılır:

- **Dış API:** Başka crate'lerin path üzerinden erişebildiği yüzey.
- **Lexical `pub`:** Kaynakta `pub` yazsa da private bir modülün içinde kaldığı
  için yalnızca crate içinde kullanılabilen yüzey.

`system_window_tabs.rs` içindeki `SystemWindowTabs` dış API değildir. Tip
kaynakta `pub struct` olarak yazılmıştır, fakat modülü crate kökünde
`mod system_window_tabs;` olarak private kaldığı için dışarıdan
`platform_title_bar::system_window_tabs::SystemWindowTabs` path'iyle erişilemez.
Dışa açılan parça yalnızca root'taki `pub use system_window_tabs::{...}`
satırlarıdır (`platform_title_bar.rs:24-26`).

### Crate kökü (`platform_title_bar`)

| Dış API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `pub mod platforms` | `platform_title_bar.rs:1` | `platform_title_bar::platforms::{platform_linux, platform_windows}` path'ini açar. **Cfg-gate yoktur**: `platforms.rs` her iki alt modülü de koşulsuz `pub mod` ile expose eder (`platforms.rs:1-2`). Yani Windows derlemesinde dahi `platform_title_bar::platforms::platform_linux::LinuxWindowControls` derlenir; runtime seçimi `PlatformStyle::platform()` ile yapılır. |
| `pub use system_window_tabs::{...}` | `DraggedWindowTab`, `MergeAllWindows`, `MoveTabToNewWindow`, `ShowNextWindowTab`, `ShowPreviousWindowTab` (`platform_title_bar.rs:24-26`) | `SystemWindowTabs` re-export edilmez. |
| `pub struct PlatformTitleBar` | Private alanlar: `id: ElementId`, `platform_style: PlatformStyle`, `children: SmallVec<[AnyElement; 2]>`, `should_move: bool`, `system_window_tabs: Entity<SystemWindowTabs>` (**strong**), `button_layout: Option<WindowButtonLayout>`, `multi_workspace: Option<WeakEntity<MultiWorkspace>>` (**weak**) (`platform_title_bar.rs:28-36`) | Alanlara dışarıdan erişim yok. **Ownership farkı**: `system_window_tabs` strong `Entity` — titlebar tabs alt-entity'yi sahiplenir ve drop edildiğinde onu da sürükler. `multi_workspace` weak — workspace bağımsız yaşar; titlebar sadece gözlemler. Aksini yapmak (workspace'i strong tutmak) **ownership cycle** üretir. |
| `PlatformTitleBar::new` | `pub fn new(id: impl Into<ElementId>, cx: &mut Context<Self>) -> Self` (`platform_title_bar.rs:39`) | `SystemWindowTabs::new()` ile internal tab entity oluşturur. |
| `with_multi_workspace` | `pub fn with_multi_workspace(mut self, multi_workspace: WeakEntity<MultiWorkspace>) -> Self` (`platform_title_bar.rs:54`) | Builder tarzı ilk bağlantı. |
| `set_multi_workspace` | `pub fn set_multi_workspace(&mut self, multi_workspace: WeakEntity<MultiWorkspace>)` (`platform_title_bar.rs:59`) | Sonradan sidebar state kaynağı bağlar. |
| `title_bar_color` | `pub fn title_bar_color(&self, window: &mut Window, cx: &mut Context<Self>) -> Hsla` (`platform_title_bar.rs:63`) | Linux/FreeBSD'de aktif/pasif ve move state'ine bakar; diğer platformlarda active/inactive ayrımı yapmaz. |
| `set_children` | `pub fn set_children<T>(&mut self, children: T) where T: IntoIterator<Item = AnyElement>` (`platform_title_bar.rs:75-77`) | Render'da `mem::take` ile tüketildiği için her render'da tekrar çağrılır. |
| `set_button_layout` | `pub fn set_button_layout(&mut self, button_layout: Option<WindowButtonLayout>)` (`platform_title_bar.rs:82`) | Sadece Linux + `Decorations::Client` olduğunda `effective_button_layout` tarafından kullanılır. |
| `PlatformTitleBar::init` | `pub fn init(cx: &mut App)` (`platform_title_bar.rs:100`) | Internal `SystemWindowTabs::init(cx)` çağrısıdır. |
| `is_multi_workspace_enabled` | `pub fn is_multi_workspace_enabled(cx: &App) -> bool` (`platform_title_bar.rs:112`) | Zed'de `DisableAiSettings` tersine bağlı feature flag. |
| `render_left_window_controls` | `pub fn render_left_window_controls(button_layout: Option<WindowButtonLayout>, close_action: Box<dyn Action>, window: &Window) -> Option<AnyElement>` (`platform_title_bar.rs:121-125`) | Yalnız Linux/FreeBSD + CSD; `button_layout.left[0]` boşsa `None`. |
| `render_right_window_controls` | `pub fn render_right_window_controls(button_layout: Option<WindowButtonLayout>, close_action: Box<dyn Action>, window: &Window) -> Option<AnyElement>` (`platform_title_bar.rs:150-154`) | Linux/FreeBSD + CSD'de layout kullanır, Windows'ta `WindowsWindowControls::new(height)`, macOS'ta `None`. |

`PlatformTitleBar` render davranışı API imzasından daha önemlidir:

- `close_action` kaynakta sabit `Box::new(workspace::CloseWindow)` olarak
  oluşturulur (`platform_title_bar.rs:189`). Serbest render fonksiyonları ise
  dışarıdan `Box<dyn Action>` alır.
- `button_layout` private helper `effective_button_layout(...)` ile sadece
  Linux + CSD durumunda `self.button_layout.or_else(|| cx.button_layout())`
  olarak çözülür (`platform_title_bar.rs:86-98`).
- Ana yüzey `WindowControlArea::Drag` alır (`platform_title_bar.rs:195-197`);
  macOS çift tıklamada `titlebar_double_click`, Linux/FreeBSD çift tıklamada
  `zoom_window` çağırır (`platform_title_bar.rs:225-237`).
- Sol/sağ sidebar açıksa ilgili taraftaki pencere kontrolleri gizlenir
  (`platform_title_bar.rs:241-257`, `294-307`).
- Linux CSD + `supported_controls.window_menu` varsa sağ tıkta
  `window.show_window_menu(ev.position)` çağrılır (`platform_title_bar.rs:309-315`).
- CSD render'ında titlebar kendi üst köşelerini de düzeltir: tiled olmayan ve
  sidebar tarafından kapatılmayan üst köşelere
  `theme::CLIENT_SIDE_DECORATION_ROUNDING` uygulanır, sonra transparent köşe
  boşluğunu kapatmak için `.mt(px(-1.)).mb(px(-1.)).border(px(1.))` ve
  `border_color(titlebar_color)` eklenir (`platform_title_bar.rs:262-279`).
- En sonda internal `SystemWindowTabs` child olarak eklenir
  (`platform_title_bar.rs:322-325`).

**Render pipeline sıralaması** (awk `.map(\|this\|` taraması, `render`
gövdesinde dört ardışık dönüşüm aşaması açığa çıkarır):

| Aşama | Yer | İş |
| :-- | :-- | :-- |
| 1 | `platform_title_bar.rs:199-221` | **Drag tespiti**: `on_mouse_down/up/down_out/move` zincirinin `should_move` bayrağıyla `window.start_window_move()` tetiklemesi. Bu aşama her zaman ilk uygulanır; sonraki stage'ler bu state'in üstüne kurulur. |
| 2 | `platform_title_bar.rs:222-239` | **ID + çift tıklama**: `this.id(self.id.clone())` + Mac/Linux platform branch'leri `on_click`'i `event.click_count() == 2` kontrolüyle `titlebar_double_click` / `zoom_window`'a yönlendirir. Windows branch'i yoktur. |
| 3 | `platform_title_bar.rs:240-261` | **Sol kenar padding/kontrolleri**: 4-yollu seçim — fullscreen ise `pl_2`, Mac + show_left_controls ise `pl(TRAFFIC_LIGHT_PADDING)`, Linux + CSD + dolu sol layout ise `render_left_window_controls(...)` child, aksi halde `pl_2` fallback. |
| 4 | `platform_title_bar.rs:262-280` | **Decorations branch**: `match decorations` — `Server` ise `el` olduğu gibi; `Client { tiling, .. }` ise tiled olmayan üst köşelere `rounded_tr/tl(CLIENT_SIDE_DECORATION_ROUNDING)` + `mt(-1)/mb(-1)/border(1)` transparent gap düzeltmesi. |

Bu zincirden sonra `.bg(titlebar_color).content_stretch().child(div().children(children))`
gelir (ana içerik), sonra `.when(!is_fullscreen, |title_bar| ...)` zinciri
sağ kontroller ve window_menu sağ-tık handler'ını ekler. Stage'ler
**commutative değildir**: stage 3'teki sol padding seçimi, stage 4'teki
corner rounding'in yatay hizalamasını etkiler.

`PlatformTitleBar.children` alanı `SmallVec<[AnyElement; 2]>` tipindedir
(`platform_title_bar.rs:31`). İki element için stack-inline kapasite
ayrılmış — Zed'in tipik kullanım kalıbı **sol grup + sağ grup**
şeklindedir (bkz. bu rehberin Konu 16 örneği). İkiden fazla element
verirseniz heap allocate edilir; iki gruba sıkıştırmak hem ergonomik
hem alokasyon-az'dır.

### `platforms::platform_linux`

| Dış API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `LinuxWindowControls` | `pub struct LinuxWindowControls` private alanlı (`platform_linux.rs:7-11`) | `#[derive(IntoElement)]`; dışarıdan alan set edilemez. |
| `LinuxWindowControls::new` | `pub fn new(id: &'static str, buttons: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE], close_action: Box<dyn Action>) -> Self` (`platform_linux.rs:14-18`) | Layout slotlarını ve close action'ı saklar. Render'da `WindowControls` capability'sine göre minimize/maximize filtrelenir, **`WindowButton::Close => true` arm'ı koşulsuzdur** (`platform_linux.rs:35-39`); `supported_controls.close` false olsa bile close butonu render edilir. |
| `WindowControlType` | `pub enum WindowControlType { Minimize, Restore, Maximize, Close }` (`platform_linux.rs:84-90`) | Variant sırası kaynakta `Minimize, Restore, Maximize, Close`; `WindowButton::Maximize` runtime'da pencere maximized ise `Restore` ikonuna çevrilir. |
| `WindowControlType::icon` | `pub fn icon(&self) -> IconName` (`platform_linux.rs:97`) | `GenericMinimize`, `GenericRestore`, `GenericMaximize`, `GenericClose` döner. |
| `WindowControlStyle` | `pub struct WindowControlStyle` private alanlı (`platform_linux.rs:107-113`) | Alanlar public değildir; sadece builder yüzeyi var. |
| `WindowControlStyle::default` | `pub fn default(cx: &mut App) -> Self` (`platform_linux.rs:116`) | `Default` trait impl'i değildir; argümansız `WindowControlStyle::default()` derlenmez. |
| `background` | `pub fn background(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:129`) | Builder. |
| `background_hover` | `pub fn background_hover(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:136`) | Builder. |
| `icon` | `pub fn icon(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:143`) | Builder. |
| `icon_hover` | `pub fn icon_hover(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:150`) | Builder. |
| `WindowControl` | `pub struct WindowControl` private alanlı (`platform_linux.rs:156-162`) | `#[derive(IntoElement)]`; public setter yok. |
| `WindowControl::new` | `pub fn new(id: impl Into<ElementId>, icon: WindowControlType, cx: &mut App) -> Self` (`platform_linux.rs:165`) | `close_action: None`; close için kullanılırsa click handler panik atar. |
| `WindowControl::new_close` | `pub fn new_close(id: impl Into<ElementId>, icon: WindowControlType, close_action: Box<dyn Action>, cx: &mut App) -> Self` (`platform_linux.rs:176-181`) | `close_action.boxed_clone()` saklar (`platform_linux.rs:188`). |
| `WindowControl::custom_style` | `pub fn custom_style(id: impl Into<ElementId>, icon: WindowControlType, style: WindowControlStyle) -> Self` (`platform_linux.rs:193-197`) | `#[allow(unused)]`; crate içinde çağrılmıyor, close action `None`. |

Linux davranışının kritik private helper'ı `fn create_window_button(...)`
(`platform_linux.rs:56-62`) dış API değildir ama parite için zorunlu karar
noktasıdır. `WindowButton::Close` branch'i yalnız `WindowControl::new_close(...)`
çağırır (`platform_linux.rs:77-79`). `WindowControl::new(...)` ile close
üretmek no-op değil; `expect("Use WindowControl::new_close() for close control.")`
ile paniktir (`platform_linux.rs:235-239`).

**Derive ve clonability haritası** (awk `#[derive(...)]` taraması ile
yakalanır, rg satır-bazlı eşleşmede struct ile derive arasındaki bağı
göstermez):

| Tip | Derive set | Önemi |
| :-- | :-- | :-- |
| `WindowControlType` | `Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Clone, Copy` (`platform_linux.rs:84`) | `Hash` + `Copy` — `HashMap` key olabilir, value semantiği. `PartialOrd/Ord` deklarasyon sırasını kullanır: `Minimize < Restore < Maximize < Close`. |
| `WindowControlStyle` | **Hiçbiri yok** (`platform_linux.rs:107-108`) | `Clone`, `Copy`, `Default` impl'i **yoktur**; her yeni instance için `WindowControlStyle::default(cx)` çağrısı gerekir. `Default` trait olmadığı için generic koddan `D: Default` ile alınamaz. |
| `LinuxWindowControls` | `IntoElement` (`platform_linux.rs:6`) | `RenderOnce` yüzeyi; build edilip child olarak verilir, alanları tekrar erişilemez. |
| `WindowControl` | `IntoElement` (`platform_linux.rs:156`) | Aynı RenderOnce yüzeyi. |
| `WindowsWindowControls` | `IntoElement` (`platform_windows.rs:5`) | Aynı. |
| `DraggedWindowTab` | `Clone` (`system_window_tabs.rs:28`) | Drag payload tipi; clone'lanabilir ama `Copy` değil. |
| `PlatformTitleBar`, `SystemWindowTabs` | Yok | `Entity` ile yönetilir; trait impl'leri (`Render`, `ParentElement`) yüzeyi sağlar. |

**`WindowControlStyle::default(cx)` hangi tema token'larını okur?**
(`platform_linux.rs:117-124`):

| Style alanı | Tema token |
| :-- | :-- |
| `background` | `colors.ghost_element_background` |
| `background_hover` | `colors.ghost_element_hover` |
| `icon` | `colors.icon` |
| `icon_hover` | `colors.icon_muted` |

Builder zincirinde override edilmeyen alanlar bu default'larda kalır;
yani port hedefi tema sisteminin **bu dört token'ı sağlaması** zorunludur
(diğer rehber bölümlerinde de listelenir).

**Sabit ölçüler** (Linux render closure'larında pixel parite için):

| Yer | Değer | Kaynak |
| :-- | :-- | :-- |
| `LinuxWindowControls` buton container gap'i | `.gap_3()` (12px @ default rem) | `platform_linux.rs:48` |
| `LinuxWindowControls` buton container yatay padding | `.px_3()` | `platform_linux.rs:49` |
| `WindowControl` buton boyutu | `.w_5().h_5()` (≈20px) | `platform_linux.rs:222-223` |
| `WindowControl` köşe yuvarlama | `.rounded_2xl()` | `platform_linux.rs:221` |

**`Box<dyn Action>` klonlama zinciri** (awk `boxed_clone()` taraması ile
çıkarılır — rg her satırı ayrı ayrı bulur, zinciri toplamaz):

| Adım | Yer | Tetikleyici | Çağrı |
| :-- | :-- | :-- | :-- |
| 1 | `platform_title_bar.rs:189` | `render()` başı | `let close_action = Box::new(workspace::CloseWindow);` (ilk Box üretimi, klon değil) |
| 2 | `platform_title_bar.rs:251` | Fullscreen değil, macOS trafik ışığı padding branch'i seçilmedi ve `show_left_controls` true | `close_action.as_ref().boxed_clone()` — `render_left_window_controls` argümanı |
| 3 | `platform_title_bar.rs:302` | `show_right_controls` true ve `!is_fullscreen` | `close_action.as_ref().boxed_clone()` — `render_right_window_controls` argümanı |
| 4 | `platform_linux.rs:78` | İlgili tarafta `WindowButton::Close` slot'u var | `create_window_button` → `WindowControl::new_close(..., close_action.boxed_clone(), cx)` |
| 5 | `platform_linux.rs:188` | `new_close` gövdesi | `close_action: Some(close_action.boxed_clone())` (parametre move'lanmak yerine yeniden klonlanır) |
| 6 | `platform_linux.rs:239` | Close butonuna **click anı** | `.expect(...).boxed_clone()` — `window.dispatch_action(...)` argümanı |

Adım 2 ve 3 clone'u render fonksiyonları çağrılmadan önce yapılır; bu yüzden
o tarafta close butonu üretilmese bile clone maliyeti doğabilir. Fullscreen'de
adım 2 ve 3 atlanır. macOS'ta sol taraf genellikle trafik ışığı padding branch'i
ile çözülür; bu durumda adım 2 çalışmaz, fakat fullscreen değilse adım 3
`render_right_window_controls(...)` çağrısı öncesinde boşa clone üretir ve
fonksiyon Mac'te `None` döner. Windows'ta `WindowsWindowControls` close action'ı
kullanmaz; buna rağmen fullscreen değilse adım 2 ve 3 çalışabilir.

Adım 4 ve 5 yalnızca Linux CSD + close butonunun bulunduğu tarafta tetiklenir.
Tipik bir Linux GNOME render'ı (close sağda, sidebar kapalı): adım 2 + 3 + 4
+ 5 = **4 boxed_clone** per render. Adım 6 yalnızca click anında, **+1** ek
klon.

`Box<dyn Action>::boxed_clone()` aslında trait üzerinden v-table dispatch
yapan klon işlemidir (`Action::boxed_clone(&self) -> Box<dyn Action>`).
Concrete tip için maliyet `Clone` impl'ine bağlıdır; `workspace::CloseWindow`
gibi unit struct'lar için ucuz, alan taşıyan action'lar için klonlama
maliyeti her render'da çarpılır. Port hedefinde action tipinin hafif
tutulması (alan içermemesi) bu yolu hızlandırır; ayrıca adım 5
optimize edilebilir (parametre `Some(close_action)` ile move'lanırsa
bir klon ortadan kalkar).

### `platforms::platform_windows`

| Dış API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `WindowsWindowControls` | `pub struct WindowsWindowControls { button_height: Pixels }` private alanlı (`platform_windows.rs:6-8`) | `#[derive(IntoElement)]`; dışarıdan sadece constructor var. |
| `WindowsWindowControls::new` | `pub fn new(button_height: Pixels) -> Self` (`platform_windows.rs:11`) | Render'da minimize, maximize/restore ve close caption butonlarını üretir. |

`WindowsCaptionButton` public değildir (`platform_windows.rs:58-64`). Private
`id()`, `icon()` ve `control_area()` metotları sırasıyla stable id, Segoe glyph
ve `WindowControlArea::{Min, Max, Close}` döndürür (`platform_windows.rs:66-94`).
Windows butonları Linux gibi click handler çağırmaz; `.window_control_area(...)`
hit-test alanı verir (`platform_windows.rs:124-135`) ve davranış platform
caption katmanında yürür.

**Segoe Fluent Icons glyph kodları** (Windows native parite için):

| Variant | Kodepoint | Kaynak |
| :-- | :-- | :-- |
| `Minimize` | `\u{e921}` | `platform_windows.rs:80` |
| `Restore` | `\u{e923}` | `platform_windows.rs:81` |
| `Maximize` | `\u{e922}` | `platform_windows.rs:82` |
| `Close` | `\u{e8bb}` | `platform_windows.rs:83` |

Font seçimi `WindowsWindowControls::get_font()` ile yapılır
(`platform_windows.rs:16/21`); Windows build 22000+ (Windows 11) için
`"Segoe Fluent Icons"`, daha eski sürümler için `"Segoe MDL2 Assets"`.
Port hedefinde bu font'lar yoksa glyph'ler kareler olarak render olur;
fallback SVG ikon zorunlu olabilir.

**Renk sabitleri** (`platform_windows.rs:99-122`):

| Buton | Hover bg | Hover fg | Active bg | Active fg |
| :-- | :-- | :-- | :-- | :-- |
| `Close` | `Rgba { r: 232/255, g: 17/255, b: 32/255, a: 1.0 }` = `#E81120` | `gpui::white()` | `color.opacity(0.8)` | `white().opacity(0.8)` |
| Diğerleri | `theme.ghost_element_hover` | `theme.text` | `theme.ghost_element_active` | `theme.text` |

Close butonunun kırmızısı (`#E81120`) **tema'dan değil, koddan gelir** —
Microsoft'un Windows title bar kapatma kırmızısıdır. Port hedefinin tema
sistemi farklı bir close vurgu rengi istiyorsa bu sabit override
edilmelidir.

**Sabit ölçüler** (Windows caption butonu):

| Yer | Değer | Kaynak |
| :-- | :-- | :-- |
| Caption buton genişliği | `.w(px(36.))` (36px) | `platform_windows.rs:129` |
| Glyph metin boyutu | `.text_size(px(10.0))` (10px) | `platform_windows.rs:131` |
| Buton yüksekliği | `WindowsWindowControls::new(button_height)`'ten `.h_full()` ile yayılır | `platform_windows.rs:11, 130` |
| Mouse propagation | `.occlude()` (alt katmanlara mouse event sızdırmaz) | `platform_windows.rs:128` |

### Root'tan re-export edilen system tab action'ları

`actions!(window, [...])` makrosu dört unit struct üretir
(`system_window_tabs.rs:18-26`). Makro çıktısı `Clone`, `PartialEq`, `Default`,
`Debug` ve `gpui::Action` derive eder (`gpui/src/action.rs:24-40`):

- `pub struct ShowNextWindowTab;`
- `pub struct ShowPreviousWindowTab;`
- `pub struct MergeAllWindows;`
- `pub struct MoveTabToNewWindow;`

Bu action'lar root'tan re-export edilir (`platform_title_bar.rs:24-26`) ve Zed
`title_bar` crate'i de aynı adları tekrar re-export eder
(`title_bar/src/title_bar.rs:13-16`).

`DraggedWindowTab` de root'tan re-export edilir. İmzası:

```rust
#[derive(Clone)]
pub struct DraggedWindowTab {
    pub id: WindowId,
    pub ix: usize,
    pub handle: AnyWindowHandle,
    pub title: String,
    pub width: Pixels,
    pub is_active: bool,
    pub active_background_color: Hsla,
    pub inactive_background_color: Hsla,
}
```

Kaynak: `system_window_tabs.rs:28-38`. Bu tip aynı zamanda drag preview için
`Render` implement eder (`system_window_tabs.rs:498-528`).

### Lexical `pub` ama dış API olmayan parçalar

| Öğe | Neden dış API değil? | Kullanım |
| :-- | :-- | :-- |
| `SystemWindowTabs` | `system_window_tabs` modülü private (`platform_title_bar.rs:2`) | `PlatformTitleBar::new` içinde entity olarak oluşturulur (`platform_title_bar.rs:39-42`) ve render sonunda child yapılır (`platform_title_bar.rs:322-325`). |
| `SystemWindowTabs::new` | Private modül içinde lexical `pub` (`system_window_tabs.rs:47`) | Internal scroll handle, ölçülen tab genişliği ve `last_dragged_tab` başlangıcı. |
| `SystemWindowTabs::init` | Private modül içinde lexical `pub` (`system_window_tabs.rs:55`) | `PlatformTitleBar::init(cx)` üzerinden çağrılır (`platform_title_bar.rs:100-101`). |
| `SystemWindowTabs::render_tab` | Private method (`system_window_tabs.rs:142`) | Tab elementlerini, drag/drop'u, middle-click close'u, close button'u ve context menu'yü kurar. |
| `handle_tab_drop` | Private method (`system_window_tabs.rs:358`) | Sadece same-bar drop reorder: `SystemWindowTabController::update_tab_position(...)`. |
| `handle_right_click_action` | Private method (`system_window_tabs.rs:362`) | Context menu action'larını hedef tab penceresinde çalıştırır. |

Bu ayrım port için önemlidir: `SystemWindowTabs` dış API olarak taşınmak zorunda
değildir; ama davranışı mirror edilecekse private event router'ları da
incelenmelidir.

### GPUI native tab destek yüzeyi

Bu tipler `platform_title_bar` crate'inden değil, `gpui` crate'inden gelir; yine
de native tab davranışının state kaynağıdır.

| API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `SystemWindowTab` | `#[doc(hidden)] pub struct SystemWindowTab { pub id, pub title, pub handle, pub last_active_at }` (`gpui/src/app.rs:276-283`) | Platform native tab metadata'sı. |
| `SystemWindowTab::new` | `pub fn new(title: SharedString, handle: AnyWindowHandle) -> Self` (`gpui/src/app.rs:287`) | `id` handle'dan, `last_active_at` `Instant::now()` ile gelir. |
| `SystemWindowTabController::new` | `pub fn new() -> Self` (`gpui/src/app.rs:308`) | Empty global controller. |
| `SystemWindowTabController::init` | `pub fn init(cx: &mut App)` (`gpui/src/app.rs:316`) | Global controller'ı resetler. |
| `tab_groups` | `pub fn tab_groups(&self) -> &FxHashMap<usize, Vec<SystemWindowTab>>` (`gpui/src/app.rs:321`) | Grupları doğrudan ref olarak verir. |
| `tabs` | `pub fn tabs(&self, id: WindowId) -> Option<&Vec<SystemWindowTab>>` (`gpui/src/app.rs:380`) | Verilen pencereyle aynı gruptaki tab listesi. |
| `init_visible` | `pub fn init_visible(cx: &mut App, visible: bool)` (`gpui/src/app.rs:387`) | Sadece `visible` `None` ise set eder. |
| `is_visible` | `pub fn is_visible(&self) -> bool` (`gpui/src/app.rs:395`) | `None` ise `false`. |
| `set_visible` | `pub fn set_visible(cx: &mut App, visible: bool)` (`gpui/src/app.rs:400`) | Platform toggle callback'i kullanır. |
| `update_last_active` | `pub fn update_last_active(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:406`) | Aktif pencere değişiminde çağrılır. |
| `update_tab_position` | `pub fn update_tab_position(cx: &mut App, id: WindowId, ix: usize)` (`gpui/src/app.rs:418`) | Same-bar drag/drop reorder. |
| `update_tab_title` | `pub fn update_tab_title(cx: &mut App, id: WindowId, title: SharedString)` (`gpui/src/app.rs:432`) | Workspace title güncellemesinde kullanılır. |
| `add_tab` | `pub fn add_tab(cx: &mut App, id: WindowId, tabs: Vec<SystemWindowTab>)` (`gpui/src/app.rs:456`) | Platform tab listesinden controller grubu kurar. |
| `remove_tab` | `pub fn remove_tab(cx: &mut App, id: WindowId) -> Option<SystemWindowTab>` (`gpui/src/app.rs:489`) | Boş kalan grupları temizler. |
| `move_tab_to_new_window` | `pub fn move_tab_to_new_window(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:504`) | Controller state'inde yeni grup açar; platform move ayrıca çağrılır. |
| `merge_all_windows` | `pub fn merge_all_windows(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:515`) | Controller gruplarını tek grupta birleştirir; platform merge ayrıca çağrılır. |
| `select_next_tab` | `pub fn select_next_tab(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:533`) | Sonraki handle'ı `activate_window()` ile aktive eder. |
| `select_previous_tab` | `pub fn select_previous_tab(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:548`) | Önceki handle'ı aktive eder. |
| `get_next_tab_group_window` | `pub fn get_next_tab_group_window(cx: &mut App, id: WindowId) -> Option<&AnyWindowHandle>` (`gpui/src/app.rs:326`) | Grup id sırası `HashMap` key sırasından gelir; kaynakta TODO var. |
| `get_prev_tab_group_window` | `pub fn get_prev_tab_group_window(cx: &mut App, id: WindowId) -> Option<&AnyWindowHandle>` (`gpui/src/app.rs:351`) | Aynı key sırası belirsizliği geçerlidir. |

### Zed `title_bar` crate'inin public tüketim yüzeyi

Zed uygulaması bu platform crate'ini doğrudan kök API olarak da, `title_bar`
crate'i üzerinden re-export olarak da kullanır:

| API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `pub mod collab` | `title_bar/src/title_bar.rs:2` | Platform titlebar değil, Zed collab UI helper modülü. |
| Platform re-export'ları | `pub use platform_title_bar::{ self, DraggedWindowTab, MergeAllWindows, MoveTabToNewWindow, PlatformTitleBar, ShowNextWindowTab, ShowPreviousWindowTab }` (`title_bar/src/title_bar.rs:13-16`) | Zed içi tüketiciler aynı action/tipleri `title_bar` üzerinden de alabilir. |
| `restore_banner` | `pub use onboarding_banner::restore_banner` (`title_bar/src/title_bar.rs:59`) | Product titlebar banner helper'ı. |
| `init` | `pub fn init(cx: &mut App)` (`title_bar/src/title_bar.rs:79`) | Platform titlebar init + per-workspace `TitleBar` entity kurulumu. |
| `TitleBar` | `pub struct TitleBar` private alanlı (`title_bar/src/title_bar.rs:150-163`) | Zed ürün başlığıdır; generic platform shell değildir. |
| `TitleBar::new` | `pub fn new(id: impl Into<ElementId>, workspace: &Workspace, multi_workspace: Option<WeakEntity<MultiWorkspace>>, window: &mut Window, cx: &mut Context<Self>) -> Self` (`title_bar/src/title_bar.rs:385-391`) | `PlatformTitleBar::new(...)` entity'sini oluşturur ve `observe_button_layout_changed` subscription'ı kurar (`title_bar.rs:441-455`). |
| Product helper'ları | `effective_active_worktree`, `render_restricted_mode`, `render_project_host`, `render_sign_in_button`, `render_user_menu_button` (`title_bar.rs:490`, `625`, `672`, `1142`, `1161`) | Zed'e özgü proje/kullanıcı UI yüzeyi; platform titlebar port API'si olarak kopyalanmamalıdır. |
| Ürün banner'ı | `OnboardingBanner::new(...)` | Feature flag'e bağlı duyuru/ürün mesajı katmanıdır; platform titlebar API'sine taşınmamalıdır. |

Zed ürün titlebar'ı, duyuru banner'larını da `TitleBar` katmanında yönetir.
Örneğin Skills duyurusu `SkillsFeatureFlag` ile görünür olur ve ilgili migration
bilgi action'ını dispatch eder. Kendi uygulamanızda benzer bir duyuru varsa bunu
`AppTitleBar` child grubuna koyun; platform kabuğuna sorumluluk olarak eklemeyin.

`OnboardingBanner` örneği, görünürlük koşulunu builder zincirinin sonundaki
`.visible_when(|cx| cx.has_flag::<SkillsFeatureFlag>())` çağrısıyla alır
(`title_bar/src/title_bar.rs:455-472`). Bu kalıp portta da aynen kullanılabilir:
banner kurucusuna bir predicate kapanışı verilir, kapanış her render geçişinde
çağrılarak `App`/`Context` üzerinden gelen feature flag veya ayar durumuna göre
banner'ı tamamen gizler. `title_bar.rs` içindeki çağrı `feature_flags`
crate'inden gelen `FeatureFlagAppExt` trait'iyle `cx.has_flag::<...>()`
çağrısına dayanır; port hedefinde aynı yardımcı yoksa benzer bir
`AppSettings`/`AppFlags` API'si yeterlidir. `TitleBar::new` içinde banner artık
sabit olarak kurulup `Some(...)` ile alana yazılır; eski "`banner: None`"
yerleşik durum kaldırılmıştır, dolayısıyla banner katmanı her örnekte hazır
durumdadır ve sadece `visible_when` predicate'i ile gizlenir.

`OnboardingBanner::new(...)` çağrısı, bu rehber yazıldığı anda sırasıyla şu
parametreleri alır: telemetri/dismiss kimliği için bir string (`"Skills
Migration Announcement"` gibi), `IconName` ikonu (`IconName::Sparkle`), banner
metni (`"Skills"`), opsiyonel ön ek (`Some("Introducing:".into())`) ve tıklama
ile dispatch edilecek boxed action (`zed_actions::agent::OpenRulesToSkillsMigrationInfo.boxed_clone()`).
Portta bu imzaların adları korunabilir; içerik, ikon ve action ürün tarafından
belirlenir.

`title_bar_settings.rs` içindeki `pub struct TitleBarSettings` (`title_bar_settings.rs:5-15`)
private modülde kaldığı için crate dışı API değildir; Zed ayar sistemi içinde
kullanılır. Kullanıcı ayarı tarafındaki dış veri tipi
`settings_content::title_bar::WindowButtonLayoutContent`'tir; Linux/FreeBSD'de
`pub fn into_layout(self) -> Option<WindowButtonLayout>` ile `WindowButtonLayout`
değerine çevrilir (`settings_content/src/title_bar.rs:24-49`).
`settings_content::title_bar::TitleBarSettingsContent` de public ayar payload'ıdır:
`show_branch_status_icon`, `show_onboarding_banner`, `show_user_picture`,
`show_branch_name`, `show_project_items`, `show_sign_in`, `show_user_menu`,
`show_menus` ve `button_layout` alanlarını `Option<...>` olarak taşır
(`settings_content/src/title_bar.rs:83-126`). Runtime tarafındaki
`TitleBarSettings` bu payload'dan üretilir (`title_bar_settings.rs:17-32`).

Zed uygulamasında `TitleBar` bu platform bileşenini iki farklı render modunda
besler (`title_bar/src/title_bar.rs:346-379`). `show_menus` true ise
`PlatformTitleBar::set_children(...)` yalnız uygulama menüsünü alır; ürün
başlığı ikinci bir satır olarak aynı `title_bar_color` ile render edilir.
`show_menus` false ise tüm ürün children'ı doğrudan `PlatformTitleBar` içine
verilir. Her iki yolda da `set_button_layout(button_layout)` render sırasında
çağrılır ve desktop layout değişimleri `observe_button_layout_changed(...)`
subscription'ı ile `cx.notify()` tetikler (`title_bar/src/title_bar.rs:441`).
Bu yüzden portta `PlatformTitleBar` tek başına "Zed titlebar UI'si" değildir;
Zed ürünü onu menü modu ve settings durumuna göre farklı child setleriyle
yönetir.

## 22. Kaynak doğrulama komutları

Kaynak doğrulamasını yalnız public adlar ve payload alanlarıyla sınırlamayın.
Owner/metot ve olay hedefi ayrımını da doğrulayın. Kontrolleri üç seviyede
çalıştır:

1. Public API envanteri.
2. Owner/metot yüzeyi.
3. Event akışı ve payload alan paritesi.

```sh
rg -n '^pub (struct|enum|fn)|^\s*pub fn|actions!\(' \
  ../zed/crates/platform_title_bar/src \
  -g '*.rs'
```

`PlatformTitleBar` owner/metot yüzeyi:

```sh
rg -n '^impl PlatformTitleBar|^\s*pub fn (new|with_multi_workspace|set_multi_workspace|title_bar_color|set_children|set_button_layout|init|is_multi_workspace_enabled)|^pub fn render_(left|right)_window_controls' \
  ../zed/crates/platform_title_bar/src/platform_title_bar.rs
```

System tab controller yüzeyi:

```sh
sed -n '270,560p' ../zed/crates/gpui/src/app.rs \
  | rg '^pub struct SystemWindowTab|^impl SystemWindowTab|^pub struct SystemWindowTabController|^impl SystemWindowTabController|^\s*pub fn'
```

`DraggedWindowTab` alan paritesi ve event akışı:

```sh
sed -n '28,39p' ../zed/crates/platform_title_bar/src/system_window_tabs.rs
rg -n 'on_drag|last_dragged_tab|drag_over::<DraggedWindowTab>|on_drop|on_mouse_up_out|handle_tab_drop|move_tab_to_new_window|merge_all_windows|update_tab_position' \
  ../zed/crates/platform_title_bar/src/system_window_tabs.rs
```

Fullscreen ve tab render ayrıntıları:

```sh
rg -n 'is_fullscreen|render_left_window_controls|render_right_window_controls|show_window_menu|CLIENT_SIDE_DECORATION_ROUNDING|mt\(px\(-1|SystemWindowTabs|Tab::content_height|Tab::container_height|measured_tab_width|max\(rem_size|ShowCloseButton|ClosePosition|visible_on_hover|drop_target|IconButton::new\("plus"' \
  ../zed/crates/platform_title_bar/src \
  ../zed/crates/ui/src/components/tab.rs \
  ../zed/crates/settings_content/src/workspace.rs
```

Native tab init ve sağ tık/action ayrımını görmek için:

```sh
rg -n 'observe_global::<SettingsStore>|was_use_system_window_tabs|set_tabbing_identifier|tabbed_windows|register_action_renderer|toggle_window_tab_overview|MergeAllWindows|build_window_options|tabbing_identifier' \
  ../zed/crates/platform_title_bar/src/system_window_tabs.rs \
  ../zed/crates/gpui/src/window.rs \
  ../zed/crates/zed/src/zed.rs
```

Controller grup mutasyonlarını görmek için:

```sh
rg -n 'pub fn (add_tab|remove_tab|move_tab_to_new_window|merge_all_windows|update_tab_position|update_tab_title|select_next_tab|select_previous_tab|get_next_tab_group_window|get_prev_tab_group_window)' \
  ../zed/crates/gpui/src/app.rs
```

Pencere seçenekleri ve CSD bağlantılarını kontrol etmek için:

```sh
find ../zed/crates -name '*.rs' -print0 |
  xargs -0 awk '/WindowOptions|WindowDecorations|Decorations::Client|WindowControlArea|set_tabbing_identifier|button_layout\\(|tab_bar_visible\\(|start_window_move|show_window_menu/ { print FILENAME ":" FNR ":" $0 }'
```

`WindowButtonLayout` ayar zincirini görmek için:

```sh
find ../zed/crates/gpui/src ../zed/crates/settings_content/src ../zed/crates/title_bar/src -name '*.rs' -print0 |
  xargs -0 awk '/MAX_BUTTONS_PER_SIDE|WindowButtonLayout|WindowButton|button_layout|linux_default|parse\\(|into_layout|observe_button_layout_changed/ { print FILENAME ":" FNR ":" $0 }'
```

Owner ayrımı (struct vs trait vs inherent fn vs free fn) için **state-machine
awk** kullan. `rg`'nin satır-tabanlı eşleşmesi bir `pub fn`'in hangi `impl`
bloğunun içinde olduğunu raporlamaz; awk içindeki kalıcı state ile bunu
çıkarırız:

```sh
find ../zed/crates/platform_title_bar/src -name '*.rs' -print0 |
  xargs -0 gawk '
    BEGIN { owner = "(free)" }
    /^pub struct [A-Za-z0-9_]+/  { print FILENAME ":" FNR ":STRUCT: " $0; next }
    /^pub enum [A-Za-z0-9_]+/    { print FILENAME ":" FNR ":ENUM: "   $0; next }
    /^pub trait [A-Za-z0-9_]+/   { print FILENAME ":" FNR ":TRAIT: "  $0; next }
    /^pub fn [A-Za-z0-9_]+/      { print FILENAME ":" FNR ":FREE_FN: " $0; next }
    /^impl[^!]/ {
      if (match($0, /for[[:space:]]+([A-Za-z0-9_]+)/, m))                  { owner = m[1] " (trait impl)" }
      else if (match($0, /impl(<[^>]+>)?[[:space:]]+([A-Za-z0-9_]+)/, m))   { owner = m[2] " (inherent)" }
      else                                                                  { owner = "?" }
      print FILENAME ":" FNR ":IMPL[" owner "]: " $0; next
    }
    /^[[:space:]]+pub fn [A-Za-z0-9_]+/ {
      print FILENAME ":" FNR ":  METHOD[" owner "]: " $0
    }
  '
```

Bu komut `WindowControl::new`, `WindowControl::new_close`,
`WindowControl::custom_style` üçlüsünü ve `WindowControlStyle::default(cx)` gibi
**inherent** ad çakışmalarını ayrı satırlarda gösterir. `rg '^impl '` yalnızca
header'ı verir; metotların hangi owner'a ait olduğunu eşleştirmek için ya
`-A N` ile blok büyüklüğünü tahmin etmek ya da awk state'i kullanmak gerekir —
state-machine yolu daha güvenlidir.

**Modül görünürlüğü kontrolü:** `pub struct` tek başına dış API değildir.
Önce crate kökündeki `pub mod`, `mod` ve `pub use` kapılarını gör:

```sh
rg -n '^(pub mod|mod |pub use)|^pub (struct|enum|fn)|^[[:space:]]+pub fn' \
  ../zed/crates/platform_title_bar/src/platform_title_bar.rs \
  ../zed/crates/platform_title_bar/src/platforms.rs \
  ../zed/crates/platform_title_bar/src/platforms/*.rs \
  ../zed/crates/platform_title_bar/src/system_window_tabs.rs
```

Okuma kuralı:

- `platform_title_bar.rs` içindeki `pub mod platforms;` dış path açar.
- `platform_title_bar.rs` içindeki `mod system_window_tabs;` private kapıdır.
- Private modül içindeki `pub struct SystemWindowTabs` dış API değildir.
- Aynı private modülden root'a `pub use` edilen `DraggedWindowTab` ve tab
  action'ları dış API olur.

**Sınırı:** Yukarıdaki kalıplar `^pub fn` ve `^[[:space:]]+pub fn` ile
sadece **public** öğeleri yakalar. Crate-içi `fn create_window_button(...)`
gibi file-private free helper'lar (Linux render yolunun gerçek
dispatch noktası) gözden kaçar. Davranış paritesi için bu helper'ları
da görmek istersen kalıpları gevşet:

```sh
find ../zed/crates/platform_title_bar/src -name '*.rs' -print0 |
  xargs -0 gawk '
    /^fn [A-Za-z0-9_]+/         { print FILENAME ":" FNR ":FREE_FN(priv): " $0 }
    /^[[:space:]]+fn [A-Za-z0-9_]+/ { print FILENAME ":" FNR ":  METHOD(priv): " $0 }
  '
```

Çıktıda şu file-private parçalar görünür:

- `fn create_window_button(...)` (`platform_linux.rs:56`) — Linux render
  yolunun gerçek dispatch noktası.
- `fn id(&self)`, `fn icon(&self)`, `fn control_area(&self)`
  (`platform_windows.rs:68, 78, 88`) — `WindowsCaptionButton` üzerindeki
  inherent yardımcılar.
- `fn get_font()` (`platform_windows.rs:16, 21`) — Windows 11 / Windows 10
  ayrımı için font seçicisi (`Segoe Fluent Icons` vs `Segoe MDL2 Assets`).
- `fn handle_tab_drop`, `fn handle_right_click_action`
  (`system_window_tabs.rs:358, 362`) — tab bar event router'ları.
- `PlatformTitleBar::effective_button_layout`, `::sidebar_render_state`
  (`platform_title_bar.rs:86, 104`) — public yüzeyin arkasındaki karar
  helper'ları.
- `fn render(...)` satırları — `Render`/`RenderOnce` trait impl gövdeleri;
  ayrı satırlarda görüldüklerinde `IMPL[Owner (trait impl)]` header'ı ile
  eşleştirilmesi gerekir.

Bu set, **dış API'ye değil ama davranış mirror'ına** dahil olan
parçaları açığa çıkarır. Port hedefinde aynı isimleri kullanmak şart
değil; ama her birinin davranışına paralel bir karar noktası
bulunmalıdır.

Crate sınırını aşan keşif için (örn. `SystemWindowTabController`
`platform_title_bar` referansıyla bulunur ama `gpui` crate'inde tanımlıdır):

```sh
# Önce platform_title_bar'da geçen tüm tip adlarını çıkar
gawk '
  match($0, /\<([A-Z][A-Za-z0-9_]+)\>/, m) { print m[1] }
' ../zed/crates/platform_title_bar/src/*.rs \
  ../zed/crates/platform_title_bar/src/platforms/*.rs \
  | sort -u > /tmp/ptb_referenced.txt

# Sonra her birinin tanım crate'ini bul
while read name; do
  defs=$(rg -l "^pub (struct|enum|trait|fn|type) ${name}\b" ../zed/crates 2>/dev/null)
  [ -n "${defs}" ] && echo "${name}: ${defs}"
done < /tmp/ptb_referenced.txt
```

Bu adım `DraggedWindowTab` doğrudan `platform_title_bar`'da olsa da
`SystemWindowTabController`'ın `gpui/src/app.rs`'te tanımlı olduğunu açığa
çıkarır — bu cross-crate sıçramayı **yalnızca** rehberin merkez crate'inde
tarama yapmak kaçırır.

