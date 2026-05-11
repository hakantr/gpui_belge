# Zed Platform Title Bar Kullanım Rehberi

Bu rehber, `../zed` çalışma ağacındaki Zed `platform_title_bar` modülünü kaynak
alır (`../zed` içinde `git rev-parse --short HEAD`: `db6039d815`). Amaç,
Zed'in platforma duyarlı başlık çubuğunu kendi GPUI uygulamanıza nasıl dahil
edebileceğinizi, hangi parçaları değiştirebileceğinizi ve pencere butonlarını
uygulama katmanınızdaki varlıklar, action'lar ve ayarlarla nasıl
yönetebileceğinizi göstermektir.

Bu dokümanda `crates/...` ile başlayan yollar `../zed` deposuna göredir.

## 1. Kapsam

`platform_title_bar`, yalnızca bir toolbar bileşeni değildir. Zed içinde şu
işleri birlikte yürütür:

- Pencereyi sürüklenebilir yapan başlık çubuğu yüzeyini üretir.
- Linux client-side decoration durumunda sol veya sağ pencere butonlarını
  render eder.
- Windows'ta caption button hit-test alanlarını GPUI `WindowControlArea` ile
  platforma bildirir.
- macOS'ta trafik ışıklarına alan bırakır ve çift tıklama davranışını sistem
  titlebar davranışına iletir.
- `SystemWindowTabs` ile native pencere sekmeleri için görünür sekme çubuğu,
  sekme kapatma, sekme sürükleme, sekmeyi yeni pencereye alma ve tüm pencereleri
  birleştirme davranışlarını bağlar.
- Zed workspace katmanındaki `CloseWindow`, `OpenRecent`, `WorkspaceSettings`,
  `ItemSettings`, `MultiWorkspace` ve tema token'larına dayanır.

Kendi uygulamanıza alırken iki yaklaşım vardır:

1. **Zed ekosistemi içinde doğrudan kullanmak**: `platform_title_bar` crate'ini
   olduğu gibi kullanırsınız. Bunun için Zed'in `workspace`, `settings`,
   `theme`, `ui`, `project` ve `zed_actions` crate'leri de uygulamanızda
   bulunmalıdır.
2. **Bağımsız GPUI uygulaması için port etmek**: Render davranışını korur,
   Zed'e özel action ve ayarları kendi uygulama tiplerinizle değiştirirsiniz.
   Bu, Zed dışındaki uygulamalar için daha kontrollü yoldur.

Kod kopyalama veya doğrudan uyarlama yaparken `crates/platform_title_bar` paket
lisansının `GPL-3.0-or-later` olduğunu ayrıca kontrol edin.

## 2. Kaynak Haritası

| Parça | Kaynak | Görev |
| :-- | :-- | :-- |
| `PlatformTitleBar` | `crates/platform_title_bar/src/platform_title_bar.rs` | Ana render entity'si, drag alanı, arka plan, köşe yuvarlama, child slotları, sol/sağ buton yerleşimi. |
| `render_left_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD'de sol pencere butonlarını üretir. |
| `render_right_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD veya Windows için sağ pencere butonlarını üretir. |
| `LinuxWindowControls` | `crates/platform_title_bar/src/platforms/platform_linux.rs` | Linux minimize, maximize/restore ve close butonlarının GPUI render katmanı. |
| `WindowsWindowControls` | `crates/platform_title_bar/src/platforms/platform_windows.rs` | Windows caption butonları ve `WindowControlArea` eşleşmeleri. |
| `SystemWindowTabs` | `crates/platform_title_bar/src/system_window_tabs.rs` | Native pencere sekmeleri, sekme menüsü, sürükle-bırak ve pencere birleştirme davranışları. |
| `TitleBar` | `crates/title_bar/src/title_bar.rs` | Zed'in uygulama başlığı, proje adı, menü, kullanıcı ve workspace state'ini `PlatformTitleBar` içine bağlayan üst seviye bileşen. |
| `client_side_decorations` | `crates/workspace/src/workspace.rs` | CSD pencere gölgesi, border, resize kenarları ve inset yönetimi. |
| `WindowOptions` | `crates/gpui/src/platform.rs` | Pencere dekorasyonu, titlebar options ve native tabbing identifier ayarları. |

## 3. Zed İçindeki Bağlantı Modeli

Zed ana workspace penceresinde `title_bar::init(cx)` çalışır. Bu fonksiyon önce
`PlatformTitleBar::init(cx)` çağırır, sonra her yeni `Workspace` için bir
`TitleBar` entity'si oluşturur ve workspace titlebar item'ına yerleştirir.

Basitleştirilmiş akış şöyledir:

```rust
pub fn init(cx: &mut App) {
    platform_title_bar::PlatformTitleBar::init(cx);

    cx.observe_new(|workspace: &mut Workspace, window, cx| {
        let Some(window) = window else {
            return;
        };

        let multi_workspace = workspace.multi_workspace().cloned();
        let item = cx.new(|cx| {
            TitleBar::new("title-bar", workspace, multi_workspace, window, cx)
        });

        workspace.set_titlebar_item(item.into(), window, cx);
    })
    .detach();
}
```

`TitleBar`, kendi `Render` akışında `PlatformTitleBar` entity'sini günceller:

```rust
self.platform_titlebar.update(cx, |titlebar, _| {
    titlebar.set_button_layout(button_layout);
    titlebar.set_children(children);
});

self.platform_titlebar.clone().into_any_element()
```

Bu kullanım önemli bir detayı gösterir: `PlatformTitleBar`, child element'lerini
render sırasında `mem::take` ile tüketir. Bu yüzden dinamik başlık içeriği her
render geçişinde tekrar `set_children(...)` ile verilmelidir.

## 4. Entegrasyon Ön Koşulları

### Pencere seçenekleri

Custom titlebar davranışı pencere açılırken başlar. Zed ana penceresinde
`WindowOptions` içinde şunlar ayarlanır:

```rust
WindowOptions {
    titlebar: Some(TitlebarOptions {
        title: None,
        appears_transparent: true,
        traffic_light_position: Some(point(px(9.0), px(9.0))),
    }),
    is_movable: true,
    window_decorations: Some(window_decorations),
    tabbing_identifier: if use_system_window_tabs {
        Some(String::from("zed"))
    } else {
        None
    },
    ..Default::default()
}
```

Kendi uygulamanızda:

- `titlebar.appears_transparent = true`, custom içerik ile native titlebar'ın
  görsel çakışmasını önler.
- `is_movable = true`, platform pencere taşıma davranışının çalışması için
  açık kalmalıdır.
- Linux/FreeBSD tarafında `window_decorations: Some(WindowDecorations::Client)`
  seçildiğinde Zed'in Linux butonları ve CSD kenarları devreye girer.
- macOS native tab grupları kullanılacaksa aynı uygulamaya ait pencerelerde
  ortak `tabbing_identifier` verilmelidir.

### Client-side decoration sarmalı

`PlatformTitleBar`, üst başlık çubuğunu üretir; pencerenin shadow, border, resize
kenarı ve client inset davranışı Zed'de `workspace::client_side_decorations(...)`
ile sarılır.

Kendi uygulamanızda Linux CSD kullanıyorsanız aynı sorumlulukları karşılayan bir
sarmal gerekir:

- CSD aktifken `window.set_client_inset(...)` çağrısı.
- Border ve gölge.
- Tiling durumuna göre köşe yuvarlama.
- Kenarlardan resize başlatma.
- İçerik alanında cursor propagation'ı kesme.

Bu sarmal olmadan titlebar görünür, fakat pencere kenarı/resize davranışı Zed ile
aynı olmaz.

## 5. Public API Envanteri

### `PlatformTitleBar`

| API | Kullanım |
| :-- | :-- |
| `PlatformTitleBar::new(id, cx)` | Başlık çubuğu entity state'ini oluşturur. |
| `with_multi_workspace(weak)` | İlk oluşturma sırasında sidebar state kaynağı verir. |
| `set_multi_workspace(weak)` | Sonradan sidebar state kaynağı bağlar. |
| `title_bar_color(window, cx)` | Aktif/pasif pencere durumuna göre titlebar rengini döndürür. |
| `set_children(children)` | Başlık çubuğunun orta içeriğini verir. Her render geçişinde yenilenmelidir. |
| `set_button_layout(layout)` | Linux CSD butonlarının sol/sağ yerleşimini override eder. |
| `PlatformTitleBar::init(cx)` | `SystemWindowTabs` global observer ve action renderer kayıtlarını kurar. |
| `is_multi_workspace_enabled(cx)` | Zed'de AI ayarına bağlı workspace sidebar davranışını kontrol eder. |

### Yardımcı render fonksiyonları

`render_left_window_controls(button_layout, close_action, window)`:

- Yalnızca Linux/FreeBSD platform stili için anlamlıdır.
- Yalnızca `Decorations::Client` durumunda element döndürür.
- `button_layout.left[0]` boşsa `None` döner.
- Close butonu için dışarıdan `Box<dyn Action>` alır.

`render_right_window_controls(button_layout, close_action, window)`:

- Linux/FreeBSD CSD'de `button_layout.right` ile `LinuxWindowControls` üretir.
- Windows'ta `WindowsWindowControls::new(height)` üretir.
- macOS'ta `None` döner; trafik ışıkları native titlebar tarafından yönetilir.

### Platform butonları

| Tip | Platform | Davranış |
| :-- | :-- | :-- |
| `LinuxWindowControls` | Linux/FreeBSD CSD | `WindowButtonLayout` sırasını okur, desteklenmeyen minimize/maximize butonlarını filtreler. |
| `WindowControl` | Linux/FreeBSD CSD | Minimize için `window.minimize_window()`, maximize/restore için `window.zoom_window()`, close için verilen action'ı dispatch eder. |
| `WindowControlStyle` | Linux/FreeBSD CSD | Buton arka planı ve ikon renklerini değiştirmek için builder yüzeyi sağlar. |
| `WindowsWindowControls` | Windows | Minimize, maximize/restore ve close butonlarını `WindowControlArea::{Min, Max, Close}` olarak işaretler. |

## 6. Kendi Uygulamana Dahil Etme

### Doğrudan Zed crate'iyle kullanım

Zed workspace crate'leri, settings kayıtları ve tema altyapısı uygulamanızda
zaten varsa entegrasyon iskeleti şöyledir. Bu yol, Zed'in uygulama başlangıç
kurulumuna yakın bir ortam bekler; bağımsız GPUI uygulamalarında port yaklaşımı
daha uygundur.

```rust
use gpui::{App, Context, Entity, Render, Window, div};
use platform_title_bar::PlatformTitleBar;
use ui::prelude::*;

pub fn init(cx: &mut App) {
    PlatformTitleBar::init(cx);
}

pub struct AppShell {
    title_bar: Entity<PlatformTitleBar>,
}

impl AppShell {
    pub fn new(cx: &mut Context<Self>) -> Self {
        Self {
            title_bar: cx.new(|cx| PlatformTitleBar::new("app-title-bar", cx)),
        }
    }
}

impl Render for AppShell {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let title = div()
            .id("title")
            .text_sm()
            .child("My GPUI App")
            .into_any_element();

        self.title_bar.update(cx, |title_bar, _| {
            title_bar.set_children([title]);
        });

        v_flex()
            .size_full()
            .child(self.title_bar.clone())
            .child(div().id("content").flex_1())
    }
}
```

Bu örnekte `set_children` render içinde çağrılır. Bunun nedeni, Zed kaynağında
child listesinin render sırasında tüketilmesidir. Entity oluşturulurken bir kez
child vermek yeterli değildir.

### Bağımsız GPUI uygulamasına port

Zed dışındaki uygulamalarda doğrudan crate bağımlılığı genellikle ağırdır.
Port ederken şu değişimleri yapın:

| Zed bağımlılığı | Port karşılığı |
| :-- | :-- |
| `workspace::CloseWindow` | Uygulamanızın `CloseWindow`, `CloseDocument`, `CloseProject` veya `QuitRequested` action'ı. |
| `zed_actions::OpenRecent { create_new_window: true }` | Uygulamanızın `NewWindow` veya `OpenWorkspace` action'ı. |
| `WorkspaceSettings::use_system_window_tabs` | Uygulama ayarınızdaki native tab seçeneği. |
| `ItemSettings::{close_position, show_close_button}` | Sekme kapatma butonu konumu ve görünürlüğü için kendi ayar tipiniz. |
| `MultiWorkspace` ve `SidebarRenderState` | Sol/sağ panel açık mı bilgisini veren kendi shell state'iniz. |
| `DisableAiSettings` | Multi workspace veya sidebar davranışını açıp kapatan kendi feature flag'iniz. |
| `cx.theme().colors().title_bar_background` | Kendi tema sisteminizdeki titlebar token'ı. |

Pratik port sınırı:

- `platform_title_bar.rs` içinden Zed workspace bağımlılıklarını çıkarın.
- `system_window_tabs.rs` içindeki action ve settings kullanımlarını kendi
  action/settings tiplerinizle değiştirin veya native tab desteğini ilk sürümde
  tamamen kapatın.
- `platforms/platform_linux.rs` ve `platforms/platform_windows.rs` daha taşınabilir
  parçalardır; çoğu uygulamada daha az değişiklik ister.

## 7. Davranış Modeli

### Sürükleme

Ana titlebar yüzeyi `WindowControlArea::Drag` ile işaretlenir. Ayrıca sol mouse
down/move akışıyla `window.start_window_move()` çağırır. Bu kombinasyon,
platforma bağlı titlebar drag davranışının tutarlı işlemesini sağlar.

Başlık çubuğuna koyduğunuz interaktif elementler kendi mouse down/click
olaylarında propagation'ı durdurmalıdır. Aksi halde buton, arama kutusu veya
menü tıklaması pencere sürükleme davranışıyla çakışabilir.

### Çift tıklama

Platform farkı Zed kaynağında ayrı işlenir:

- macOS: `window.titlebar_double_click()`
- Linux/FreeBSD: `window.zoom_window()`
- Windows: davranış platform caption/hit-test katmanına bırakılır.

Kendi uygulamanızda çift tıklamanın maximize yerine minimize gibi farklı bir
ayar izlemesini istiyorsanız bu bölüm parametreleştirilmelidir.

### Renk

`title_bar_color` Linux/FreeBSD tarafında aktif pencere için
`title_bar_background`, pasif veya move sırasında `title_bar_inactive_background`
kullanır. Diğer platformlarda doğrudan `title_bar_background` döner.

Bu davranış, başlık çubuğu ve sekme çubuğu arasında görsel ayrımı korur. Kendi
tema sisteminizde en az şu token'lar gerekir:

- `title_bar_background`
- `title_bar_inactive_background`
- `tab_bar_background`
- `border`
- `ghost_element_background`
- `ghost_element_hover`
- `ghost_element_active`
- `icon`
- `icon_muted`
- `text`

### Yükseklik

Zed `platform_title_bar_height(window)` kullanır:

- Windows: sabit `32px`.
- Diğer platformlar: `1.75 * rem_size`, minimum `34px`.

Bu değer hem titlebar hem Windows buton yüksekliği hem de bazı yardımcı
başlıkların hizalaması için ortak kullanılmalıdır.

## 8. Buton Yerleşimi ve Ayar Yönetimi

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

## 9. Butonları Uygulama Katmanına Bağlama

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

### Sekme butonları

`SystemWindowTabs` içindeki sekme kapatma davranışı da `workspace::CloseWindow`
dispatch eder. Sağ tık menüsünde şu işlemler bulunur:

- Close Tab
- Close Other Tabs
- Move Tab to New Window
- Show All Tabs

Alt sağdaki plus butonu `zed_actions::OpenRecent { create_new_window: true }`
dispatch eder. Kendi uygulamanızda bu action büyük olasılıkla `NewWindow`,
`OpenWorkspace` veya `CreateDocumentWindow` olmalıdır.

## 10. System Window Tabs

`PlatformTitleBar::init(cx)`, `SystemWindowTabs::init(cx)` çağırır. Bu kurulum
iki şeyi yapar:

1. `WorkspaceSettings::use_system_window_tabs` ayarını izler ve pencerelerin
   `tabbing_identifier` değerlerini günceller.
2. Yeni `Workspace` entity'leri için action renderer kaydeder:
   `ShowNextWindowTab`, `ShowPreviousWindowTab`, `MoveTabToNewWindow`,
   `MergeAllWindows`.

Render sırasında `SystemWindowTabController` global state'i okunur. Controller
aktif pencerenin sekme grubunu döndürür; yoksa current window tek sekme gibi
gösterilir.

Sekme çubuğu şu durumlarda boş döner:

- Platform `window.tab_bar_visible()` false ve controller görünür değilse.
- `use_system_window_tabs` false ve yalnızca bir sekme varsa.

Kendi uygulamanızda native tab desteğini ilk aşamada istemiyorsanız:

- `PlatformTitleBar::init(cx)` çağrısını kaldırmak yerine, port edilen
  `PlatformTitleBar` içinde `SystemWindowTabs` child'ını feature flag ile kapatın.
- `tabbing_identifier` değerini `None` bırakın.
- Sekme action'larını kaydetmeyin.

Native tab desteğini koruyacaksanız:

- Her pencereye aynı uygulama tab group adı verin.
- `SystemWindowTabController::init(cx)` çağrısını ayar açıldığında yapın.
- Yeni açılan pencereleri controller'a `SystemWindowTab::new(title, handle)` ile
  bildirin.
- Sekme kapatma ve yeni pencere action'larını uygulama lifecycle'ınıza bağlayın.

## 11. Sidebar ve Workspace Etkileşimi

`PlatformTitleBar`, `MultiWorkspace` zayıf referansı alabiliyor. Bunun tek amacı
başlık çubuğundaki pencere kontrollerinin sidebar ile çakışmasını önlemek:

- Sol sidebar açıksa sol pencere kontrolleri gizlenir.
- Sağ sidebar açıksa sağ pencere kontrolleri gizlenir.
- CSD köşe yuvarlama sidebar tarafında kapatılır.

Zed'de bu bilgi `SidebarRenderState { open, side }` ile gelir. Kendi
uygulamanızda sol/sağ panel varsa aynı soyutlamayı daha küçük bir tipe
indirgemek yeterlidir:

```rust
#[derive(Default, Clone, Copy)]
struct ShellSidebarState {
    open: bool,
    side: SidebarSide,
}
```

Eğer sidebar yoksa bu alanı tamamen kaldırabilir veya daima default state
döndürebilirsiniz.

`PlatformTitleBar::is_multi_workspace_enabled(cx)` Zed'de
`DisableAiSettings` üzerinden döner. Bu isim uygulama dışı görünse de davranış
aslında feature flag'dir. Kendi uygulamanızda bunu `AppSettings::multi_workspace`
veya `ShellSettings::sidebar_enabled` gibi doğrudan isimlendirilmiş bir ayarla
değiştirin.

## 12. Başlık Çubuğuna İçerik Yerleştirme

`PlatformTitleBar` kendi başına sadece platform kabuğunu sağlar. Zed'in gerçek
ürün başlığı `crates/title_bar/src/title_bar.rs` içindeki `TitleBar` tarafından
oluşturulur. Bu katman şunları child olarak verir:

- Uygulama menüsü.
- Proje adı / recent projects popover.
- Git branch adı ve durum ikonu.
- Restricted mode göstergesi.
- Kullanıcı menüsü, sign-in butonu, plan chip, update bildirimi.
- Collab/screen share göstergeleri.

Kendi uygulamanızda aynı pattern'i kullanın: platform titlebar'ı shell olarak
tutun, ürününüzün anlamlı varlıklarını üst seviye `AppTitleBar` veya
`ShellTitleBar` entity'sinde üretin.

Önerilen ayrım:

| Katman | Sorumluluk |
| :-- | :-- |
| `PlatformTitleBar` | Platform davranışı, drag alanı, pencere kontrolleri, native tabs. |
| `AppTitleBar` | Uygulama adı, aktif workspace/doküman, menüler, kullanıcı aksiyonları. |
| `AppShell` | Pencere layout'u, CSD sarmalı, titlebar + içerik kompozisyonu. |
| `AppState` | Workspace, doküman, user session, ayar ve lifecycle action'ları. |

Başlık çubuğu içeriğinde `justify_between` kullanıldığı için çocukları sol,
orta ve sağ grup olarak vermek pratik olur:

```rust
let children = [
    h_flex()
        .id("title-left")
        .gap_2()
        .child(app_menu)
        .child(project_picker)
        .into_any_element(),
    h_flex()
        .id("title-right")
        .gap_1()
        .child(sync_status)
        .child(user_menu)
        .into_any_element(),
];

self.platform_titlebar.update(cx, |title_bar, _| {
    title_bar.set_children(children);
});
```

Interaktif child'larda dikkat edilecekler:

- Butonlar ve popover tetikleyicileri click/mouse down propagation'ını
  durdurmalıdır.
- Uzun metinler `truncate()` veya sabit `max_w(...)` ile sınırlandırılmalıdır.
- Sağ tarafta platform pencere butonları olabileceği için ürün butonlarınızın
  sağ padding ve flex shrink davranışını test edin.
- Fullscreen modunda native pencere kontrolleri değişebileceği için macOS ve
  Windows davranışını ayrı kontrol edin.

## 13. Özelleştirme Noktaları

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Close butonu farklı action dispatch etsin | `PlatformTitleBar` içine `close_action` alanı ekle veya serbest render fonksiyonlarını kullan. |
| Linux buton sırası ayardan gelsin | `set_button_layout(...)` çağrısını uygulama settings state'ine bağla. |
| Linux buton ikon/rengi değişsin | `WindowControlStyle` veya `WindowControlType::icon()` portunda değişiklik yap. |
| Windows close hover rengi değişsin | `platform_windows.rs` içinde `WindowsCaptionButton::Close` renklerini değiştir. |
| Titlebar yüksekliği değişsin | `platform_title_bar_height` karşılığını uygulamana taşı ve tüm titlebar/controls kullanımında aynı değeri kullan. |
| Native tabs kapatılsın | `SystemWindowTabs` render child'ını feature flag ile boş döndür. |
| Sekme plus butonu yeni pencere açsın | `zed_actions::OpenRecent` yerine uygulama `NewWindow` action'ını dispatch et. |
| Sidebar açıkken kontroller gizlenmesin | `sidebar_render_state` ve `show_left/right_controls` koşullarını değiştir. |
| Sağ tık window menu kapatılsın | Linux CSD `window.show_window_menu(ev.position)` bağını kaldır veya ayara bağla. |
| Çift tıklama maximize yerine özel action olsun | Platform click handler'larını kendi action'ına yönlendir. |

## 14. Kontrol Listesi

### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında bir kez çağrılıyor.
- Pencere `WindowOptions.titlebar` değerini transparent titlebar ile açıyor.
- Linux CSD gerekiyorsa `WindowDecorations::Client` isteniyor.
- CSD kullanılıyorsa pencere gölge/border/resize sarmalı ayrıca uygulanıyor.
- Titlebar child'ları her render geçişinde `set_children(...)` ile yenileniyor.
- İnteraktif titlebar child'ları drag propagation ile çakışmıyor.
- Tema token'ları aktif, pasif ve hover durumlarını kapsıyor.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı ile `WindowButtonLayout` geliyor.
- Sol ve sağ buton dizilerinde boş slotlar doğru davranıyor.
- Desktop layout değişince titlebar yeniden render oluyor.
- `window.window_controls()` minimize/maximize desteğini doğru filtreliyor.
- Sağ tık sistem pencere menüsü istenen ürün davranışıyla uyumlu.

### Windows

- Caption button alanları `WindowControlArea::{Min, Max, Close}` olarak kalıyor.
- Sağdaki ürün butonları caption button hitbox'larıyla çakışmıyor.
- `platform_title_bar_height` Windows için `32px` varsayımını koruyor veya bilinçli
  değiştiriliyor.
- Close hover rengi tema politikanızla uyumlu.

### macOS

- Trafik ışıkları için sol padding korunuyor.
- `traffic_light_position` ile titlebar child'ları çakışmıyor.
- Fullscreen ve native tabs davranışı ayrıca test ediliyor.
- Çift tıklama sistem davranışına mı, özel davranışa mı gidecek netleştiriliyor.

### Native tabs

- `tabbing_identifier` tüm ilgili pencerelerde aynı.
- Sekme kapatma action'ı kirli doküman/workspace state'ini kontrol ediyor.
- Sekmeyi yeni pencereye alma uygulama state'ini doğru taşıyor.
- Plus butonu doğru yeni pencere/workspace action'ını dispatch ediyor.
- Sağ tık menü metinleri ve action'ları ürün diline uyarlanıyor.

## 15. Kaynak Doğrulama Komutları

Bu rehber hazırlanırken kaynak kontrolü `awk` ile yapılmıştır. Aynı kontrolleri
tekrar çalıştırmak için:

```sh
find ../zed/crates -name '*.rs' -print0 |
  xargs -0 awk '/PlatformTitleBar::|PlatformTitleBar|render_left_window_controls|render_right_window_controls|ShowNextWindowTab|MergeAllWindows|set_button_layout|set_multi_workspace/ { print FILENAME ":" FNR ":" $0 }'
```

Public API yüzeyini görmek için:

```sh
find ../zed/crates/title_bar ../zed/crates/platform_title_bar -name '*.rs' -print0 |
  xargs -0 awk '/pub struct|pub enum|pub fn|actions!|impl Render|impl RenderOnce|impl ParentElement/ { print FILENAME ":" FNR ":" $0 }'
```

Pencere seçenekleri ve CSD bağlantılarını kontrol etmek için:

```sh
find ../zed/crates -name '*.rs' -print0 |
  xargs -0 awk '/WindowOptions|WindowDecorations|Decorations::Client|WindowControlArea|set_tabbing_identifier|button_layout\\(|tab_bar_visible\\(|start_window_move|show_window_menu/ { print FILENAME ":" FNR ":" $0 }'
```

`WindowButtonLayout` ayar zincirini görmek için:

```sh
find ../zed/crates/gpui/src ../zed/crates/settings_content/src ../zed/crates/title_bar/src -name '*.rs' -print0 |
  xargs -0 awk '/WindowButtonLayout|WindowButton|button_layout|into_layout|observe_button_layout_changed/ { print FILENAME ":" FNR ":" $0 }'
```

## 16. Sık Yapılan Hatalar

- `PlatformTitleBar` child'larını yalnızca constructor'da vermek. Zed child'ları
  render sırasında tükettiği için içerik sonraki render'da kaybolur.
- Linux CSD butonlarını gösterip pencere resize/border sarmalını uygulamamak.
  Başlık çubuğu çalışır, fakat pencere kenarı native hissettirmez.
- Close butonunu uygulama lifecycle'ına bağlamadan doğrudan pencere kapatmak.
  Kirli doküman, background task veya workspace cleanup adımları atlanabilir.
- Windows butonlarını Linux gibi click handler ile yönetmeye çalışmak. Windows
  implementation hit-test alanı verir; davranış platform katmanındadır.
- Native tabs açıkken `tabbing_identifier` vermemek. Pencereler aynı native tab
  grubunda birleşmez.
- App-specific menüleri `PlatformTitleBar` içine gömmek. Daha temiz model,
  platform kabuğunu ayrı, ürün titlebar içeriğini ayrı tutmaktır.

## 17. Uygulama Katmanına Önerilen Model

Kendi uygulamanızda titlebar davranışını merkezi yönetmek için şu sözleşme yeterli
olur:

```rust
trait TitleBarController {
    fn close_action(&self) -> Box<dyn Action>;
    fn new_window_action(&self) -> Box<dyn Action>;
    fn button_layout(&self, cx: &App) -> Option<WindowButtonLayout>;
    fn sidebar_state(&self, cx: &App) -> ShellSidebarState;
    fn use_system_window_tabs(&self, cx: &App) -> bool;
}
```

Bu sözleşme sayesinde platform titlebar şu soruları uygulama state'ine sormuş
olur:

- Kapatma ne anlama geliyor?
- Yeni pencere nasıl açılıyor?
- Linux butonları hangi tarafta durmalı?
- Sidebar pencere kontrolleriyle çakışıyor mu?
- Native tabs açık mı?

Zed'in tasarımında güçlü olan nokta budur: platform titlebar, pencere kabuğunun
mekaniğini bilir; ürünün neyi kapatacağına, hangi menüyü açacağına veya hangi
workspace'i taşıyacağına üst uygulama katmanı karar verir. Kendi uygulamanızda da
bu ayrımı korumak, bileşeni büyüdükçe yönetilebilir tutar.
