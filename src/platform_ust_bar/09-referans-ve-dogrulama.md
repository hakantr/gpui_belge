# Referans ve doğrulama

Bu bölüm, üst bar portunda dış API sınırını ve davranış paritesini netleştirir. Amaç ham kaynak taraması yaptırmak değil; hangi tiplerin dışarıdan kullanılacağını, hangi parçaların yalnız iç davranış taşıdığını ve render akışında hangi kararların korunması gerektiğini göstermektir.

## 21. Dış API sınırı ve davranış paritesi

Bu bölümde `pub` anahtar sözcüğünün iki farklı anlamı ayrılır. Bu ayrım netleşmediğinde "neden bu tipi import edemiyorum?" sorusu sıkça gündeme gelir:

- **Dış API:** Başka crate'lerden yol üzerinden doğrudan erişilebilen yüzeydir. Bu tipler dışarıdan kullanılmak üzere kasıtlı olarak açılmıştır.
- **Lexical `pub`:** Kaynakta `pub` yazsa da, tipi içeren modül crate kök dizininde private olabilir. Bu durumda öğeye yalnızca crate içinden ulaşılır. Yani `pub` işareti tek başına dış erişim sağlamaz.

Bu ayrımın iyi örneklerinden biri `system_window_tabs.rs` içindeki `SystemWindowTabs` tipidir. Kaynakta `pub struct` olarak yazılmıştır. Fakat modül crate kökünde `mod system_window_tabs;` biçiminde, yani private olarak bağlanır. Bu yüzden dışarıdan `platform_title_bar::system_window_tabs::SystemWindowTabs` yoluyla erişilemez. Crate dışına açılan parçalar yalnızca kök dosyadaki `pub use system_window_tabs::{...}` satırlarıdır.

### Crate kökü (`platform_title_bar`)

| Dış API | İmza / Tanım | Not |
| :-- | :-- | :-- |
| `pub mod platforms` | `pub mod platforms;` | `platform_title_bar::platforms::{platform_linux, platform_windows}` yolunu açar. **Cfg kapısı yoktur**: `platforms.rs` her iki alt modülü de koşulsuz `pub mod` ile dışa açar. Yani Windows derlemesinde dahi `platform_title_bar::platforms::platform_linux::LinuxWindowControls` derlenir; çalışma zamanı seçimi `PlatformStyle::platform()` ile gerçekleştirilir. |
| `pub use system_window_tabs::{...}` | `DraggedWindowTab`, `MergeAllWindows`, `MoveTabToNewWindow`, `ShowNextWindowTab`, `ShowPreviousWindowTab` | `SystemWindowTabs` re-export edilmez. |
| `pub struct PlatformTitleBar` | Private alanlar: `id: ElementId`, `platform_style: PlatformStyle`, `children: SmallVec<[AnyElement; 2]>`, `should_move: bool`, `system_window_tabs: Entity<SystemWindowTabs>` (**güçlü**), `button_layout: Option<WindowButtonLayout>`, `multi_workspace: Option<WeakEntity<MultiWorkspace>>` (**zayıf**) | Alanlara dışarıdan erişim yok. **Sahiplik farkı**: `system_window_tabs` güçlü `Entity` — Titlebar sekmeleri alt-entity'yi sahiplenir ve drop edildiğinde onu da sürükler. `multi_workspace` zayıf — `Workspace` bağımsız yaşar; titlebar sadece gözlemler. Aksini yapmak (`Workspace`'i güçlü tutmak) **sahiplik döngüsü** üretir. |
| `PlatformTitleBar::new` | `pub fn new(id: impl Into<ElementId>, cx: &mut Context<Self>) -> Self` | `SystemWindowTabs::new()` ile iç sekme entity'si oluşturur. |
| `with_multi_workspace` | `pub fn with_multi_workspace(mut self, multi_workspace: WeakEntity<MultiWorkspace>) -> Self` | Kurucu tarzı ilk bağlantı. |
| `set_multi_workspace` | `pub fn set_multi_workspace(&mut self, multi_workspace: WeakEntity<MultiWorkspace>)` | Sonradan yan panel durum kaynağı bağlar. |
| `title_bar_color` | `pub fn title_bar_color(&self, window: &mut Window, cx: &mut Context<Self>) -> Hsla` | Linux/FreeBSD'de aktif/pasif ve hareket durumuna bakar; diğer platformlarda etkin/etkin olmayan ayrımı yapmaz. |
| `set_children` | `pub fn set_children<T>(&mut self, children: T) where T: IntoIterator<Item = AnyElement>` | Render'da `mem::take` ile tüketildiği için her render işleminde tekrar çağrılır. |
| `set_button_layout` | `pub fn set_button_layout(&mut self, button_layout: Option<WindowButtonLayout>)` | Sadece Linux + `Decorations::Client` olduğunda `effective_button_layout` tarafından kullanılır. |
| `PlatformTitleBar::init` | `pub fn init(cx: &mut App)` | Internal `SystemWindowTabs::init(cx)` çağrısıdır. |
| `is_multi_workspace_enabled` | `pub fn is_multi_workspace_enabled(cx: &App) -> bool` | Zed'de `DisableAiSettings` tersine bağlı özellik bayrağı. |
| `platform_title_bar::render_left_window_controls` | `pub fn render_left_window_controls(button_layout: Option<WindowButtonLayout>, close_action: Box<dyn Action>, window: &Window) -> Option<AnyElement>` | Yalnız Linux/FreeBSD + CSD; `button_layout.left[0]` boşsa `None`. |
| `platform_title_bar::render_right_window_controls` | `pub fn render_right_window_controls(button_layout: Option<WindowButtonLayout>, close_action: Box<dyn Action>, window: &Window) -> Option<AnyElement>` | Linux/FreeBSD + CSD'de yerleşim kullanır, Windows'ta `WindowsWindowControls::new(height)`, macOS'ta `None`. |

`PlatformTitleBar` tipinin render davranışı çoğu zaman public API imzalarından daha kritiktir. Port uyumsuzluklarının büyük kısmı imza farklarından değil, render içindeki ince akışlardan doğar. Aşağıdaki maddeler bu davranışta doğrulanması gereken noktaları sıralar:

- `close_action`, kaynakta sabit olarak `Box::new(workspace::CloseWindow)` ifadesiyle oluşturulur. Buna karşılık serbest render fonksiyonları (`render_left_window_controls`, `render_right_window_controls`) kapatma eylemini dışarıdan `Box<dyn Action>` olarak alır; bu, davranışın yapılandırılabilir olduğu tek noktadır.
- `button_layout`, private bir yardımcı olan `effective_button_layout(...)` üzerinden çözümlenir. Bu çözüm yalnızca Linux + CSD durumunda yapılır ve mantığı `self.button_layout.or_else(|| cx.button_layout())` şeklindedir. Yani önce uygulamadan gelen değere bakılır, yoksa platforma sorulur.
- Ana titlebar yüzeyi `WindowControlArea::Drag` ile etiketlenir. Buna ek olarak macOS'ta çift tıklama `titlebar_double_click` çağrısına, Linux/FreeBSD'de ise `zoom_window` çağrısına bağlanır.
- Sol veya sağ yan panel açıkken, yan panel tarafındaki pencere kontrolleri gizlenir. Bu, görsel çakışmayı önlemek içindir.
- Linux CSD aktifken ve `supported_controls.window_menu` `true` ise, başlık çubuğunda sağ tıklama `window.show_window_menu(ev.position)` çağrısını tetikler.
- CSD render'ında titlebar, kendi üst köşelerini de düzeltir. Döşeli olmayan ve yan panel tarafından kapatılmayan üst köşelere `theme::CLIENT_SIDE_DECORATION_ROUNDING` uygulanır. Ardından şeffaf köşe boşluğunu kapatmak için `.mt(px(-1.)).mb(px(-1.)).border(px(1.))` ölçüleri ve `border_color(titlebar_color)` rengi eklenir.
- Render zincirinin sonunda, internal `SystemWindowTabs` entity'si çocuk olarak eklenir. Yani sekme çubuğu titlebar'ın görsel olarak hemen altında çizilir.

**Render hattı sıralaması**, port hedefinde hangi adımların hangi sırayla uygulanacağını gösterir. `render` fonksiyonu gövdesinde birbirini takip eden dört ayrı dönüşüm aşaması vardır:

| Aşama | İş |
| :-- | :-- |
| 1 | **Sürükleme Tespiti**: `on_mouse_down/up/down_out/move` zincirinin `should_move` bayrağıyla `window.start_window_move()` tetiklemesi. Bu aşama her zaman ilk uygulanır; sonraki aşamalar bu durumun üzerine inşa edilir. |
| 2 | **ID + Çift Tıklama**: `this.id(self.id.clone())` + Mac/Linux platform dalları `on_click`'i `event.click_count() == 2` kontrolüyle `titlebar_double_click` / `zoom_window`'a yönlendirir. Windows dalı yoktur. |
| 3 | **Sol Kenar Padding/Kontrolleri**: 4-yollu seçim — tam ekran ise `pl_2`, Mac + show_left_controls ise `pl(TRAFFIC_LIGHT_PADDING)`, Linux + CSD + dolu sol layout ise `render_left_window_controls(...)` çocuk, aksi halde `pl_2` yedek. |
| 4 | **Decorations Dalı**: `match decorations` — `Server` ise `el` olduğu gibi; `Client { tiling, .. }` ise döşeli olmayan üst köşelere `rounded_tr/tl(CLIENT_SIDE_DECORATION_ROUNDING)` + `mt(-1)/mb(-1)/border(1)` şeffaf boşluk düzeltmesi. |

Bu dört aşamalı zincirden sonra `.bg(titlebar_color).content_stretch().child(div().children(children))` ifadesi gelir. Bu ifade başlık çubuğunun ana içeriğini oluşturur. Ardından `.when(!is_fullscreen, |title_bar| ...)` zinciri sağ kontrolleri ve `window_menu` sağ tık işleyicisini ekler.

Bu sıralama önemlidir; aşamalar **birbirleriyle yer değiştirebilir değildir**. Örneğin 3. aşamadaki sol padding seçimi, 4. aşamadaki köşe yuvarlamasının yatay hizalamasını doğrudan etkiler. Sıralamayı değiştirmek gözle hemen fark edilmeyen hizalama uyumsuzlukları üretebilir.

`PlatformTitleBar.children` alanı `SmallVec<[AnyElement; 2]>` tipinde tanımlıdır. Yapı iki element için yığın içi kapasite ayırır. Bunun nedeni Zed'in tipik kullanım kalıbının **sol grup + sağ grup** olmasıdır. Bu yapıya ikiden fazla element verildiğinde dinamik bellek ayırma işlemi gerçekleştirilir. Bu yüzden içeriği iki gruba toplamak hem ergonomik açıdan tutarlı kalır hem de bellek ayırma sayısını azaltır.

### `platforms::platform_linux`

Tam modül yolu `platform_title_bar::platforms::platform_linux` olarak dışa açıktır.

| Dış API | İmza / Tanım | Not |
| :-- | :-- | :-- |
| `platform_title_bar::platforms::platform_linux::LinuxWindowControls` | `pub struct LinuxWindowControls` private alanlı | `#[derive(IntoElement)]`; dışarıdan alan ayarlanamaz. |
| `LinuxWindowControls::new` | `pub fn new(id: &'static str, buttons: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE], close_action: Box<dyn Action>) -> Self` | Yerleşim slotlarını ve kapatma eylemini saklar. Render'da `WindowControls` yeteneğine göre minimize/maximize filtrelenir, **`WindowButton::Close => true` kolu koşulsuzdur**; `supported_controls.close` false olsa bile kapat butonu render edilir. |
| `platform_title_bar::platforms::platform_linux::WindowControlType` | `pub enum WindowControlType { Minimize, Restore, Maximize, Close }` | Varyant sırası kaynakta `Minimize, Restore, Maximize, Close`; `WindowButton::Maximize` çalışma zamanında pencere büyütülmüşse `Restore` ikonuna çevrilir. |
| `WindowControlType::icon` | `pub fn icon(&self) -> IconName` | `GenericMinimize`, `GenericRestore`, `GenericMaximize`, `GenericClose` döner. |
| `platform_title_bar::platforms::platform_linux::WindowControlStyle` | `pub struct WindowControlStyle` private alanlı | Alanlar public değildir; sadece kurucu zinciri yüzeyi var. |
| `WindowControlStyle::default` | `pub fn default(cx: &mut App) -> Self` | `Default` trait impl'i değildir; argümansız `WindowControlStyle::default()` derlenmez. |
| `background` | `pub fn background(mut self, color: impl Into<Hsla>) -> Self` | Kurucu zinciri adımı. |
| `background_hover` | `pub fn background_hover(mut self, color: impl Into<Hsla>) -> Self` | Kurucu zinciri adımı. |
| `icon` | `pub fn icon(mut self, color: impl Into<Hsla>) -> Self` | Kurucu zinciri adımı. |
| `icon_hover` | `pub fn icon_hover(mut self, color: impl Into<Hsla>) -> Self` | Kurucu zinciri adımı. |
| `platform_title_bar::platforms::platform_linux::WindowControl` | `pub struct WindowControl` private alanlı | `#[derive(IntoElement)]`; public ayarlayıcı yok. |
| `WindowControl::new` | `pub fn new(id: impl Into<ElementId>, icon: WindowControlType, cx: &mut App) -> Self` | `close_action: None`; kapatma için kullanılırsa tıklama işleyicisi panik atar. |
| `WindowControl::new_close` | `pub fn new_close(id: impl Into<ElementId>, icon: WindowControlType, close_action: Box<dyn Action>, cx: &mut App) -> Self` | `close_action.boxed_clone()` saklar. |
| `WindowControl::custom_style` | `pub fn custom_style(id: impl Into<ElementId>, icon: WindowControlType, style: WindowControlStyle) -> Self` | Crate içinde çağrılmıyor, kapatma eylemi `None`. |

Linux davranışının kritik private yardımcısı `fn create_window_button(...)` dış API değildir; buna rağmen davranış paritesi için zorunlu bir karar noktasıdır. İçinde `WindowButton::Close` dalı yalnızca `WindowControl::new_close(...)` çağrısını kullanır. Kapat butonunu `WindowControl::new(...)` ile üretmeye çalışmak, çalışma zamanında kapatma eylemi yoksa `Use WindowControl::new_close() for close control.` mesajıyla hızlı hata paniğine yol açar. Bu, kapat butonu için uyumsuz kurucu kullanılmasının engellenmesi için konmuş bir güvenlik önlemidir.

**Derive ve klonlanabilirlik haritası**, hangi tipin değer semantiğiyle taşındığını ve hangisinin yalnız element olarak tüketildiğini gösterir:

| Tip | Derive Kümesi | Önemi |
| :-- | :-- | :-- |
| `WindowControlType` | `Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Clone, Copy` | `Hash` + `Copy` — `HashMap` anahtarı olabilir, değer semantiği taşır. `PartialOrd/Ord` deklarasyon sırasını kullanır: `Minimize < Restore < Maximize < Close`. |
| `WindowControlStyle` | **Hiçbiri yok** | `Clone`, `Copy`, `Default` impl'i **yoktur**; her yeni örnek için `WindowControlStyle::default(cx)` çağrısı gerekir. `Default` trait olmadığı için generic koddan `D: Default` ile alınamaz. |
| `LinuxWindowControls` | `IntoElement` | `RenderOnce` yüzeyi; inşa edilip çocuk olarak verilir, alanlarına tekrar erişilemez. |
| `WindowControl` | `IntoElement` | Aynı RenderOnce yüzeyi. |
| `WindowsWindowControls` | `IntoElement` | Aynı. |
| `DraggedWindowTab` | `Clone` | Sürükleme yük tipi; clone'lanabilir ama `Copy` değil. |
| `PlatformTitleBar`, `SystemWindowTabs` | Yok | `Entity` ile yönetilir; trait impl'leri (`Render`, `ParentElement`) yüzeyi sağlar. |

**`WindowControlStyle::default(cx)` çağrısı hangi tema token'larını okur?** Bu soru port hedefinin tema sistemini doğrudan şekillendirir. Cevap aşağıdaki dört tema token'ına karşılık gelir:

| Stil Alanı | Tema Token |
| :-- | :-- |
| `background` | `colors.ghost_element_background` |
| `background_hover` | `colors.ghost_element_hover` |
| `icon` | `colors.icon` |
| `icon_hover` | `colors.icon_muted` |

Kurucu zincirinde geçersiz kılınmayan alanlar bu varsayılan değerlerinde kalır. Pratik sonuç nettir: Port hedefinin tema sistemi **yukarıdaki dört token'ı mutlaka sağlamalıdır**. Bu token'lardan biri sağlanmazsa Linux pencere butonlarının görünümü beklenmeyen renklere düşer.

**Sabit ölçüler.** Linux render kapanımlarında piksel paritesini korumak için aşağıdaki sabit değerlerin port hedefinde de aynı biçimde kullanılması gerekir:

| Yer | Değer |
| :-- | :-- |
| `LinuxWindowControls` buton kapsayıcı aralığı | `.gap_3()` (12px @ varsayılan rem) |
| `LinuxWindowControls` buton kapsayıcı yatay padding | `.px_3()` |
| `WindowControl` buton boyutu | `.w_5().h_5()` (≈20px) |
| `WindowControl` köşe yuvarlama | `.rounded_2xl()` |

**`Box<dyn Action>` klonlama zinciri.** Kapatma eyleminin render sırasında kaç defa klonlandığı önemlidir. Zincirin adımları şöyledir:

| Adım | Tetikleyici | Çağrı |
| :-- | :-- | :-- |
| 1 | `render()` başı | `let close_action = Box::new(workspace::CloseWindow);` (ilk Box üretimi, klon değil) |
| 2 | Tam ekran değil, macOS trafik ışığı padding dalı seçilmedi ve `show_left_controls` true | `close_action.as_ref().boxed_clone()` — `render_left_window_controls` argümanı |
| 3 | `show_right_controls` true ve `!is_fullscreen` | `close_action.as_ref().boxed_clone()` — `render_right_window_controls` argümanı |
| 4 | İlgili tarafta `WindowButton::Close` slot'u var | `create_window_button` → `WindowControl::new_close(..., close_action.boxed_clone(), cx)` |
| 5 | `new_close` gövdesi | `close_action: Some(close_action.boxed_clone())` (parametre hareket ettirilmek yerine yeniden klonlanır) |
| 6 | Kapat butonuna **tıklama anı** | Kapatma eylemi yoksa panik üretilir; aksi halde `boxed_clone()` sonucu `window.dispatch_action(...)` argümanı olur |

Adım 2 ve 3'teki klonlamalar render fonksiyonları çağrılmadan önce gerçekleştirilir. Bunun anlamı şudur: İlgili tarafta kapat butonu hiç üretilmese bile klonlama maliyeti doğar. Tam ekran durumunda adım 2 ve 3 atlanır; çünkü tam ekranda yan kontroller render'a girmez. macOS tarafında sol kenar genellikle trafik ışığı padding dalı ile çözüldüğü için adım 2 burada çalışmaz. Ancak tam ekran değilse adım 3 hâlâ `render_right_window_controls(...)` çağrısı öncesinde bir klon üretir ve fonksiyon Mac'te zaten `None` döner. Yani Mac'te fazladan bir klonlama maliyeti vardır. Windows tarafında `WindowsWindowControls` kapatma eylemi kullanmaz; buna rağmen tam ekran olmadığı sürece adım 2 ve 3 çalışabilir.

Adım 4 ve 5 yalnızca Linux CSD ortamında ve kapat butonunun bulunduğu tarafta tetiklenir. Tipik bir Linux GNOME render'ında, yani kapat sağda ve yan panel kapalıyken, adımlar 2 + 3 + 4 + 5 birlikte çalışır. Bu da render başına 4 adet `boxed_clone` anlamına gelir. Adım 6 ise yalnızca kapat butonuna tıklandığında ek olarak **+1** klon üretir.

`Box<dyn Action>::boxed_clone()` çağrısı trait üzerinden v-table dispatch yapan bir klon işlemidir (`Action::boxed_clone(&self) -> Box<dyn Action>`). Bu klonun maliyeti somut tipin `Clone` implementasyonuna bağlıdır. `workspace::CloseWindow` gibi unit struct'lar için maliyet neredeyse sıfırdır. Alan taşıyan eylemlerde ise bu maliyet her render'da artış gösterebilir. Port hedefinde eylem tipini alan taşımayacak şekilde tasarlamak bu süreci hızlandırır. Ayrıca adım 5 optimize edilebilir: Parametre hareket ettirilebilir, yani `Some(close_action)` ile move'lanabilir biçimde alınırsa, bir klon adımı tamamen ortadan kalkar.

### `platforms::platform_windows`

Tam modül yolu `platform_title_bar::platforms::platform_windows` olarak dışa açıktır.

| Dış API | İmza / Tanım | Not |
| :-- | :-- | :-- |
| `platform_title_bar::platforms::platform_windows::WindowsWindowControls` | `pub struct WindowsWindowControls { button_height: Pixels }` private alanlı | `#[derive(IntoElement)]`; dışarıdan sadece kurucu var. |
| `WindowsWindowControls::new` | `pub fn new(button_height: Pixels) -> Self` | Render'da minimize, maximize/restore ve close caption butonlarını üretir. |

`WindowsCaptionButton` tipi crate dışına açılmamıştır; yalnızca crate içinde kullanılır. Tipin private metotları `id()`, `icon()` ve `control_area()` sırasıyla şu üç şeyi döner: Kararlı element id'si, Segoe glyph karakteri ve `WindowControlArea::{Min, Max, Close}` varyantlarından biri. Windows butonları, Linux'taki gibi tıklama işleyicisi çağırmaz; bunun yerine `.window_control_area(...)` ile hit-test alanı üretirler ve davranış platform caption katmanı tarafından sürdürülür.

**Segoe Fluent Icons glyph kodları.** Windows native paritesini korumak için aşağıdaki dört Unicode codepoint değerinin birebir aynen kullanılması gerekir:

| Varyant | Codepoint |
| :-- | :-- |
| `Minimize` | `\u{e921}` |
| `Restore` | `\u{e923}` |
| `Maximize` | `\u{e922}` |
| `Close` | `\u{e8bb}` |

Bu glyph'lerin gösterilmesi için kullanılan font, çalışılan Windows build'ine göre değişir. Font seçimi `WindowsWindowControls::get_font()` fonksiyonunda gerçekleştirilir. Build numarası 22000 veya üzerindeyse `"Segoe Fluent Icons"` font'u tercih edilir; build numarası bunun altındaysa `"Segoe MDL2 Assets"` tercih edilir. Port hedefinin çalıştığı sistemde bu font'lar yoksa glyph'ler boş kareler olarak render olur. Bu durumda SVG ikon yedeği gerekebilir.

**Renk sabitleri.** Windows pencere butonlarının üzerine gelme ve active durumlarındaki renkleri sabit olarak tanımlanır. Aşağıdaki tablo bu sabitleri özetler:

| Buton | Hover bg | Hover fg | Active bg | Active fg |
| :-- | :-- | :-- | :-- | :-- |
| `Close` | `Rgba { r: 232/255, g: 17/255, b: 32/255, a: 1.0 }` = `#E81120` | `gpui::white()` | `color.opacity(0.8)` | `white().opacity(0.8)` |
| Diğerleri | `theme.ghost_element_hover` | `theme.text` | `theme.ghost_element_active` | `theme.text` |

Burada özellikle dikkat çeken nokta kapat butonunun kırmızısıdır: `#E81120` **temadan değil, doğrudan koddan gelir**. Bu renk Microsoft'un Windows title bar kapatma kırmızısıdır ve native hissi korumak için sabit tutulur. Port hedefinin tema sistemi farklı bir kapatma vurgu rengi istiyorsa bu sabitin geçersiz kılınması gerekir. Bu sabit değiştirilmezse tema değişse bile kapatma üzerine gelme rengi Microsoft kırmızısında kalır.

**Sabit ölçüler** (Windows caption butonu):

| Yer | Değer |
| :-- | :-- |
| Caption buton genişliği | `.w(px(36.))` (36px) |
| Glyph metin boyutu | `.text_size(px(10.0))` (10px) |
| Buton yüksekliği | `WindowsWindowControls::new(button_height)`'ten `.h_full()` ile yayılır |
| Fare olay yayılımı | `.occlude()` (alt katmanlara fare olayı sızdırmaz) |

### Kökten re-export edilen sistem sekme eylemleri

Native pencere sekmeleri için gerekli eylemler `actions!(window, [...])` makrosu ile üretilir. Bu makro dört unit struct'ı tek seferde tanımlar. Makro çıktısı şu derive kümesini otomatik ekler: `Clone`, `PartialEq`, `Default`, `Debug` ve `gpui::Action`. Üretilen tipler şunlardır:

- `pub struct ShowNextWindowTab;`
- `pub struct ShowPreviousWindowTab;`
- `pub struct MergeAllWindows;`
- `pub struct MoveTabToNewWindow;`

Bu dört eylem crate kökünden re-export edilir. Ardından Zed'in `title_bar` crate'i aynı adları kendi seviyesinde bir kez daha re-export eder. Bu çift re-export, tüketicilerin tipleri kendileri için en uygun yoldan import etmesine imkan verir.

`DraggedWindowTab` tipi de aynı şekilde crate kökünden re-export edilir. İmzası şöyledir:

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

Bu tip aynı zamanda sürükleme önizlemesi olarak kendini çizmek için `Render` trait'ini implement eder. Yani hem veri taşır hem de görsel sunum sağlar.

### Lexical `pub` ama dış API olmayan parçalar

Aşağıdaki tablo, kaynakta `pub` görünmesine rağmen crate sınırının dışından erişilemeyen parçaları listeler. Bunları görmek port hedefinde davranış paritesi için önemlidir; çünkü Zed bu yardımcı parçaları kendi içinde aktif olarak kullanır.

| Öğe | Neden Dış API Değil? | Kullanım |
| :-- | :-- | :-- |
| `SystemWindowTabs` | `system_window_tabs` modülü private | `PlatformTitleBar::new` içinde entity olarak oluşturulur ve render sonunda çocuk olarak eklenir. |
| `SystemWindowTabs::new` | Private modül içinde lexical `pub` | İç kaydırma tutamacı, ölçülen sekme genişliği ve `last_dragged_tab` başlangıcı. |
| `SystemWindowTabs::init` | Private modül içinde lexical `pub` | `PlatformTitleBar::init(cx)` üzerinden çağrılır. |
| `SystemWindowTabs::render_tab` | Private method | Sekme elementlerini, sürükle-bırakı, orta tıkla kapatmayı, kapat butonunu ve bağlam menüsünü kurar. |
| `handle_tab_drop` | Private method | Sadece aynı çubukta bırakma ile yeniden sıralama: `SystemWindowTabController::update_tab_position(...)`. |
| `handle_right_click_action` | Private method | Bağlam menüsü eylemlerini hedef sekme penceresinde çalıştırır. |

Bu ayrımın port hedefi için anlamı şudur: `SystemWindowTabs` tipi dış API olarak taşınmak zorunda değildir. Tüketicilere doğrudan göstermemek serbestlik sağlar. Ancak davranış birebir taşınacaksa private olay yönlendiricilerinin de ayrı ayrı incelenmesi gerekir; özellikle `handle_tab_drop` ve `handle_right_click_action` önemlidir. Yalnızca public yüzey taşınırsa bu yönlendiricilerin yaptığı iş dışarıda kalır ve sekme davranışı eksik kalır.

### GPUI native tab destek yüzeyi

Aşağıdaki tipler `platform_title_bar` crate'inden değil, `gpui` crate'inden gelir. Buna rağmen native sekme davranışının durum kaynağını oluşturdukları için bu bölümde yer almaları gerekir. Port hedefi, sekme denetleyicisini fiilen bu yüzey üzerinden işletir:

| API | İmza / Tanım | Not |
| :-- | :-- | :-- |
| `SystemWindowTab` | `#[doc(hidden)] pub struct SystemWindowTab { pub id, pub title, pub handle, pub last_active_at }` | Platform native sekme üst verisi. |
| `SystemWindowTab::new` | `pub fn new(title: SharedString, handle: AnyWindowHandle) -> Self` | `id` handle'dan, `last_active_at` `Instant::now()` ile gelir. |
| `SystemWindowTabController::new` | `pub fn new() -> Self` | Boş global denetleyici. |
| `SystemWindowTabController::init` | `pub fn init(cx: &mut App)` | Global denetleyiciyi resetler. |
| `tab_groups` | `pub fn tab_groups(&self) -> &FxHashMap<usize, Vec<SystemWindowTab>>` | Grupları doğrudan referans olarak verir. |
| `tabs` | `pub fn tabs(&self, id: WindowId) -> Option<&Vec<SystemWindowTab>>` | Verilen pencereyle aynı gruptaki sekme listesi. |
| `init_visible` | `pub fn init_visible(cx: &mut App, visible: bool)` | Sadece `visible` `None` ise ayarlar. |
| `is_visible` | `pub fn is_visible(&self) -> bool` | `None` ise `false`. |
| `set_visible` | `pub fn set_visible(cx: &mut App, visible: bool)` | Platform geçiş geri çağrısı kullanır. |
| `update_last_active` | `pub fn update_last_active(cx: &mut App, id: WindowId)` | Aktif pencere değişiminde çağrılır. |
| `update_tab_position` | `pub fn update_tab_position(cx: &mut App, id: WindowId, ix: usize)` | Aynı çubukta sürükle-bırak yeniden sıralaması. |
| `update_tab_title` | `pub fn update_tab_title(cx: &mut App, id: WindowId, title: SharedString)` | Workspace başlığı güncellemesinde kullanılır. |
| `add_tab` | `pub fn add_tab(cx: &mut App, id: WindowId, tabs: Vec<SystemWindowTab>)` | Platform sekme listesinden denetleyici grubu kurulur. |
| `remove_tab` | `pub fn remove_tab(cx: &mut App, id: WindowId) -> Option<SystemWindowTab>` | Boş kalan grupları temizler. |
| `move_tab_to_new_window` | `pub fn move_tab_to_new_window(cx: &mut App, id: WindowId)` | Denetleyici durumunda yeni grup açar; platform taşıma ayrıca çağrılır. |
| `merge_all_windows` | `pub fn merge_all_windows(cx: &mut App, id: WindowId)` | Denetleyici gruplarını tek grupta birleştirir; platform birleştirme ayrıca çağrılır. |
| `select_next_tab` | `pub fn select_next_tab(cx: &mut App, id: WindowId)` | Sonraki handle'ı `activate_window()` ile aktive eder. |
| `select_previous_tab` | `pub fn select_previous_tab(cx: &mut App, id: WindowId)` | Önceki handle'ı aktive eder. |
| `get_next_tab_group_window` | `pub fn get_next_tab_group_window(cx: &mut App, id: WindowId) -> Option<&AnyWindowHandle>` | Grup id sırası `HashMap` anahtar sırasından gelir; kaynakta TODO var. |
| `get_prev_tab_group_window` | `pub fn get_prev_tab_group_window(cx: &mut App, id: WindowId) -> Option<&AnyWindowHandle>` | Aynı anahtar sırası belirsizliği geçerlidir. |

### Zed `title_bar` crate'inin public tüketim yüzeyi

Zed uygulaması platform crate'ini iki yoldan tüketir: Bazı parçalar doğrudan kök API olarak kullanılır; bazıları ise `title_bar` crate'i üzerinden re-export edilir. Aşağıdaki tablo bu yüzeyin ana parçalarını gösterir:

| API | İmza / Tanım | Not |
| :-- | :-- | :-- |
| `pub mod collab` | `pub mod collab;` | Platform titlebar değil, Zed collab UI yardımcı modülü. |
| Platform re-export'ları | `pub use platform_title_bar::{ self, DraggedWindowTab, MergeAllWindows, MoveTabToNewWindow, PlatformTitleBar, ShowNextWindowTab, ShowPreviousWindowTab }` | Zed içi tüketiciler aynı eylem/tipleri `title_bar` üzerinden de alabilir. |
| `restore_banner` | `pub use onboarding_banner::restore_banner` | Ürün titlebar banner yardımcısı. |
| `init` | `pub fn init(cx: &mut App)` | Platform titlebar init + her `Workspace` için `TitleBar` entity kurulumu. |
| `TitleBar` | `pub struct TitleBar` özel alanlı | Zed ürün başlığıdır; genel platform kabuğu değildir. |
| `TitleBar::new` | `pub fn new(id: impl Into<ElementId>, workspace: &Workspace, multi_workspace: Option<WeakEntity<MultiWorkspace>>, window: &mut Window, cx: &mut Context<Self>) -> Self` | `PlatformTitleBar::new(...)` entity'sini oluşturur ve `observe_button_layout_changed` aboneliği kurar. |
| Ürün yardımcıları | `effective_active_worktree`, `render_restricted_mode`, `render_project_host`, `render_sign_in_button`, `render_user_menu_button` | Zed'e özgü proje/kullanıcı UI yüzeyi; platform başlık çubuğu port API'si olarak kopyalanmamalıdır. |
| Ürün duyuru bandı | `OnboardingBanner::new(...)` | Özellik bayrağına bağlı duyuru/ürün mesajı katmanıdır; platform başlık çubuğu API'sine taşınmamalıdır. |
| Güncelleme bildirimi | `UpdateVersion::version_tooltip_message(...)` | İpucu metnini `"Update to Version: ..."` biçiminde üretir. SHA için `short()` değil `full()` kullanılır. |
| Güncelleme bildiriminin görsel kabuğu | `UpdateButton` | Beş durum için ayrı kurucu: `checking`, `downloading`, `installing`, `updated`, `errored`. İlk üçü `disabled(true)` ile gelir; render sırasında düğme `disabled` bayrağına geçer ve sınırı `colors().border` ile çizilir. `updated`/`errored` durumlarında sınır `colors().text.opacity(0.15)` üzerinden hesaplanır. Döner ikon yalnız `checking` ve `installing` durumlarında `IconName::LoadCircle` ile iki turluk dönüş yapar; `downloading` ve `updated` durumlarında `Download`, `errored` durumunda `Warning` ikonu kullanılır. Kaynak hata görünür metni `"Failed to Update"` biçimindedir; yerelleştirilmiş portta anlam korunarak Türkçeleştirilir. |

Zed ürün başlık çubuğu eylem ve işbirliği yardımcı kapsamı:

| API | Rol |
| :-- | :-- |
| `SimulateUpdateAvailable`, `SwitchBranch`, `ToggleProjectMenu`, `ToggleUserMenu` | Ürün başlık çubuğunda güncelleme simülasyonu, dal değiştirme, proje menüsü ve kullanıcı menüsünü açma eylemleridir. |
| `toggle_screen_sharing`, `toggle_mute`, `toggle_deafen` | Başlık çubuğu işbirliği kontrollerinden ekran paylaşımı, mikrofonu kapatma ve dinlemeyi kapatma durumunu `Workspace` çağrı durumuna bağlayan yardımcı fonksiyonlardır. |

Ürün başlığı katmanının ayrıntıları (duyuru bandı, güncelleme bildirimi, kullanıcı menüsü, işbirliği) platform kabuğunun değil, `title_bar` crate'inin konusudur ve [Üst Bar](../ust_bar/ust_bar.md) bölümünde işlenir. Burada yalnız platform kabuğuyla kesişen kural önemlidir: Bu ürün varlıkları `PlatformTitleBar` içine gömülmez; `TitleBar` katmanında üretilip platform kabuğuna çocuk olarak teslim edilir. `OnboardingBanner` mekanizması crate'te hazır olmakla birlikte güncel sürümde `TitleBar`'ın `banner` alanı `None` bırakılır; ayrıntı ve doğru durum Üst Bar bölümündedir.

`UpdateVersion` tarafında `version_tooltip_message(...)` semantik sürüm için `SemanticVersion::to_string()`, commit için `AppCommitSha::full()` çıktısını kullanır ve her iki durumda da sonucu kaynak arayüzünde `"Update to Version: {version}"` kalıbına sarar. `Downloading`, `Installing` ve `Updated` render kolları bu metni `UpdateButton` kurucularına `version` değişkeni olarak geçirir. Port hedefinde kullanıcıya kısa SHA göstermek isteniyorsa bu bilinçli bir ürün farkı olarak kaydedilir; Zed paritesi değildir.

Zed'in `title_bar` crate'indeki `pub struct TitleBarSettings` tipi özel bir modülde kaldığı için crate dışı API değildir; yalnızca Zed'in kendi ayar sistemi içinde kullanılır. Kullanıcı ayarı tarafındaki dış veri tipi ise `settings_content::WindowButtonLayoutContent` tipidir. Linux/FreeBSD'de bu tip, `pub fn into_layout(self) -> Option<WindowButtonLayout>` çağrısıyla doğrudan `WindowButtonLayout` değerine dönüştürülür.

Aynı dosyada `settings_content::TitleBarSettingsContent` de public bir ayar yüküdür. Şu alanları taşır ve hepsi `Option<...>` sarmalındadır: `show_branch_status_icon`, `show_onboarding_banner`, `show_user_picture`, `show_branch_name`, `show_project_items`, `show_sign_in`, `show_user_menu`, `show_menus` ve `button_layout`. Çalışma zamanı tarafındaki `TitleBarSettings` tipi bu yükten üretilir.

Zed uygulamasında `TitleBar`, platform bileşenini iki farklı render modunda besler. Karar doğrudan ayar alanından değil, `application_menu::show_menus(cx)` yardımcısından gelir. Bu yardımcı `TitleBarSettings::show_menus` değerini okur; ayrıca macOS'ta cross-platform menü ancak `ZED_USE_CROSS_PLATFORM_MENU` çevre değişkeni varsa açılır. `show_menus(cx)` sonucu `true` ise `PlatformTitleBar::set_children(...)` yalnız uygulama menüsünü alır; ürün başlığı ikinci bir satır olarak aynı `title_bar_color` ile render edilir. Sonuç `false` ise bu ikinci satır kurulmaz; tüm ürün çocukları doğrudan `PlatformTitleBar` içine verilir. İki render modunda da ortak olan nokta şudur: `set_button_layout(button_layout)` çağrısını render sırasında gerçekleştirilir. Masaüstü yerleşimi değişimleri de `observe_button_layout_changed(...)` aboneliği üzerinden `cx.notify()` ile yeni render tetikler.

Bu bilgilerin port hedefi için anlamı şudur: `PlatformTitleBar` tek başına "Zed titlebar UI'si" değildir. Zed ürünü bu platform bileşenini menü moduna ve mevcut ayar durumuna göre farklı çocuk setleriyle besler. Port hedefinin ürün titlebar'ı da benzer bir mod farkındalığıyla yazılırsa ayar değişikliklerine doğru tepki veren esnek bir yapıya kavuşur.

## 22. Davranış doğrulama kontrol listesi

Üst bar davranışını güncellerken kaynak komutu listesi yerine aşağıdaki karar noktalarının tek tek doğrulanması gerekir:

- `PlatformTitleBar::new` içindeki `SystemWindowTabs` sahipliği güçlü `Entity` olarak kalır; `MultiWorkspace` bağlantısı ise zayıf kalır.
- Linux ve FreeBSD client-side decoration yolunda `button_layout` önce uygulama ayarından, yoksa platform varsayılanından çözümlenir.
- `render_left_window_controls` ve `render_right_window_controls` yalnız ilgili platform ve decoration koşullarında gerçek çocuk üretir.
- Linux kapat butonu `WindowControl::new_close` ile kurulur; normal `WindowControl::new` kapatma eylemi taşımaz.
- Windows caption butonları tıklama işleyicisi yerine `WindowControlArea::{Min, Max, Close}` hit-test alanlarıyla çalışır.
- `SystemWindowTabController` GPUI tarafındaki durum kaynağıdır; `platform_title_bar` yalnız bu durum üzerinden native sekme UI davranışını bağlar.
- Zed ürün titlebar katmanı platform kabuğuna ürün banner'ı, kullanıcı menüsü veya güncelleme butonu gibi ürün sorumlulukları eklemez; bunlar `TitleBar` çocuk kompozisyonunda kalır.

Bu liste, port eden geliştiricinin davranış paritesini gözden geçirmesi için yeterlidir. Kaynak keşfi ve kapsam taraması gerekiyorsa bunun çalışma notları mdBook dışında tutulur.

---
