# Entegrasyon başlangıcı ve uygulama sözleşmesi

İskelet hazır olduktan sonra ilk somut adımlar pencerenin doğru
biçimde açılmasını sağlamak ve platform kabuğunun uygulama state'iyle
konuşacağı controller sözleşmesini tanımlamaktır. Bu iki adım birlikte
düşünülür; çünkü `WindowOptions` ayarları olmadan platform kabuğu
yeterli zemini bulamaz, controller sözleşmesi olmadan da platform
kabuğu uygulamanın iş kurallarını öğrenemez.

## 9. Entegrasyon ön koşulları

### Pencere seçenekleri

Custom titlebar davranışının çalışmaya başlaması, pencerenin
açılışındaki ilk birkaç ayara bağlıdır. Zed'in ana penceresinde
`WindowOptions` içinde şu alanlar açıkça verilir:

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

Bu alanların her birinin pratik anlamı şudur:

- `titlebar.appears_transparent = true`, custom başlık içeriğinin
  native titlebar ile görsel olarak çakışmasını önler; iki katmanın
  üst üste binip kullanıcıya tuhaf bir görünüm vermesinin önüne geçer.
- `is_movable = true`, platformun pencere taşıma davranışının çalışması
  için açık kalmalıdır. Bu alanın kapalı bırakılması, başlık çubuğundan
  pencerenin sürüklenememesine yol açar.
- Linux/FreeBSD tarafında `window_decorations:
  Some(WindowDecorations::Client)` seçildiğinde Zed'in Linux pencere
  butonları ve client-side decoration (CSD) kenarları devreye girer.
  Bu, dağıtım için en çok kontrol veren ama aynı zamanda en çok ayar
  gerektiren yoldur.
- macOS'ta native tab grupları kullanılacaksa, aynı uygulamaya ait
  pencerelerin tamamına ortak bir `tabbing_identifier` verilmelidir.
  Farklı identifier'lar pencerelerin aynı tab grubuna düşmemesine yol
  açar.

### Client-side decoration sarmalı

`PlatformTitleBar`, yalnızca üst başlık çubuğunu üretir. Bu çubuğun
etrafındaki pencere gölgesi, kenarlığı, resize kenarı ve client inset
yönetimi onun sorumluluğunda değildir; Zed'de bu sorumluluklar
`workspace::client_side_decorations(...)` fonksiyonunun oluşturduğu
ayrı bir sarmal tarafından üstlenilir.

Bir uygulamada Linux CSD desteği isteniyorsa, aynı sorumlulukları
karşılayan bir sarmal port tarafında da yazılmalıdır. Bu sarmalın
yüklendiği işler şunlardır:

- CSD aktifken `window.set_client_inset(...)` çağrısı yapmak.
- Pencere kenarlığını ve gölgesini çizmek.
- Tiling durumuna göre uygun köşe yuvarlamasını uygulamak.
- Kenarlardan resize işleminin başlatılmasını sağlamak.
- İçerik alanına geçen cursor propagation'ını kesmek.

Bu sarmal yazılmadığı sürece başlık çubuğu görünür hâlde çalışır;
ama pencere kenarı ve resize davranışı Zed ile aynı hissi vermez.
Yani başlık çubuğu tek başına CSD penceresi değildir; sarmal onun
çevresinde mutlaka olmalıdır.

**İstenen decoration ile gerçek decoration aynı kabul edilemez.**
`WindowOptions.window_decorations` alanı yalnızca bir istek değeridir;
render sırasında bağlayıcı olan her zaman `window.window_decorations()`
çağrısının döndürdüğü gerçek değerdir. Kaynakta bu fark iki platformda
açıkça görünür:

- Wayland'da server-side decoration istenir ama compositor decoration
  protokolünü desteklemezse GPUI `WindowDecorations::Client`'a düşer
  (`gpui_linux/src/linux/wayland/window.rs:1469-1484`).
- X11'de client-side decoration istenir ama compositor desteği yoksa GPUI
  server-side decoration'a döner; `window_decorations()` da doğrudan
  `Decorations::Server` verir (`gpui_linux/src/linux/x11/window.rs:1742-1748`,
  `1818-1828`).

Bu davranışlar nedeniyle
`PlatformTitleBar::effective_button_layout(...)` ve
`render_left/right_window_controls(...)` fonksiyonları, doğru sonucu
verebilmek için ayar değerine değil **gerçekleşmiş** `Decorations::Client`
durumuna bakar. İstek ile sonucu eşit kabul eden bir port, en sık
karşılaşılan hatalardan birini yapar: kullanıcı CSD istemiş gibi
görünür, oysa compositor başka türlü davranmıştır.

## 10. Uygulama katmanına önerilen model

Üst bar davranışının merkezi olarak yönetilebilmesi için aşağıdaki
trait sözleşmesi yeterlidir. Bu sözleşme, platform kabuğunun
uygulamayla konuşacağı en küçük yüzeyi tanımlar:

```rust
trait TitleBarController {
    fn close_action(&self) -> Box<dyn Action>;
    fn new_window_action(&self) -> Box<dyn Action>;
    fn button_layout(&self, cx: &App) -> Option<WindowButtonLayout>;
    fn sidebar_state(&self, cx: &App) -> ShellSidebarState;
    fn use_system_window_tabs(&self, cx: &App) -> bool;
}
```

Bu sözleşme sayesinde platform titlebar, render anında uygulama
state'ine şu beş soruyu sormuş olur:

- Kapatma işlemi tam olarak ne anlama geliyor?
- Yeni pencere hangi action ile açılıyor?
- Linux butonları hangi tarafta durmalı?
- Sidebar açık mı; pencere kontrolleriyle çakışıyor mu?
- Native tab desteği aktif mi değil mi?

Zed'in tasarımında en güçlü kararlardan biri budur: platform titlebar,
yalnızca pencere kabuğunun mekaniğini bilir; ürünün neyi kapatacağına,
hangi menüyü açacağına veya hangi workspace'i taşıyacağına ise üst
uygulama katmanı karar verir. Aynı ayrımın port hedefinde de
korunması, bileşen büyüyüp evrildikçe kodun yönetilebilir kalmasını
sağlar. Aksine, bu ayrım bulanıklaşırsa platform kabuğu zamanla
ürünün bütün iş kurallarını içine almaya başlar ve hem test edilemez
hem de başka projeye taşınamaz hâle gelir.

