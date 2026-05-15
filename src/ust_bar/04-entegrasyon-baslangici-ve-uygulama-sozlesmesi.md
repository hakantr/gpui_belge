# Entegrasyon başlangıcı ve uygulama sözleşmesi

İskelet hazır olduktan sonra iki somut adım gelir. İlki pencerenin doğru seçeneklerle açılmasıdır. İkincisi ise platform kabuğunun uygulama state'iyle konuşacağı controller sözleşmesinin tanımlanmasıdır. Bu iki adım birlikte düşünülür. `WindowOptions` ayarları olmadan platform kabuğu doğru zemini bulamaz; controller sözleşmesi olmadan da uygulamanın iş kurallarını öğrenemez.

## 9. Entegrasyon ön koşulları

### Pencere seçenekleri

Custom titlebar davranışının çalışması, pencere açılırken verilen birkaç kritik ayara bağlıdır. Zed'in ana penceresinde `WindowOptions` içinde şu alanlar açıkça set edilir:

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

Bu alanların pratik karşılığı şudur:

- `titlebar.appears_transparent = true`, custom başlık içeriğinin native titlebar ile görsel olarak çakışmasını önler. Böylece iki katman üst üste binip kullanıcıya tuhaf bir görünüm vermez.
- `is_movable = true`, platformun pencere taşıma davranışının çalışması için açık kalmalıdır. Bu alanın kapalı bırakılması, başlık çubuğundan pencerenin sürüklenememesine yol açar.
- Linux/FreeBSD tarafında `window_decorations: Some(WindowDecorations::Client)` seçildiğinde Zed'in Linux pencere butonları ve client-side decoration (CSD) kenarları devreye girer. Bu yol en fazla kontrolü verir; aynı zamanda en fazla ayar isteyen yoldur.
- macOS'ta native tab grupları kullanılacaksa, aynı uygulamaya ait pencerelerin tamamına ortak bir `tabbing_identifier` verilmelidir. Farklı identifier'lar pencerelerin aynı tab grubuna düşmemesine yol açar.

### Client-side decoration sarmalı

`PlatformTitleBar` yalnızca üst başlık çubuğunu üretir. Bu çubuğun etrafındaki pencere gölgesi, kenarlık, resize kenarı ve client inset yönetimi onun sorumluluğunda değildir. Zed'de bu işler `workspace::client_side_decorations(...)` fonksiyonunun oluşturduğu ayrı bir sarmal tarafından yapılır.

Bir uygulamada Linux CSD desteği isteniyorsa, aynı sorumlulukları karşılayan bir sarmal port tarafında da yazılmalıdır. Bu sarmalın yüklendiği işler şunlardır:

- CSD aktifken `window.set_client_inset(...)` çağrısı yapmak.
- Pencere kenarlığını ve gölgesini çizmek.
- Tiling durumuna göre uygun köşe yuvarlamasını uygulamak.
- Kenarlardan resize işleminin başlatılmasını sağlamak.
- İçerik alanına geçen cursor propagation'ını kesmek.

Bu sarmal yazılmasa da başlık çubuğu görünür ve temel olarak çalışır. Ancak pencere kenarı ve resize davranışı Zed ile aynı hissi vermez. Yani başlık çubuğu tek başına CSD penceresi değildir; çevresinde bu sarmalın bulunması gerekir.

**İstenen decoration ile gerçekleşen decoration aynı kabul edilemez.** `WindowOptions.window_decorations` alanı yalnızca bir istek değeridir. Render sırasında bağlayıcı olan değer, her zaman `window.window_decorations()` çağrısının döndürdüğü gerçek durumdur. Kaynakta bu fark iki platformda açıkça görünür:

- Wayland'da server-side decoration istenir ama compositor decoration protokolünü desteklemezse GPUI `WindowDecorations::Client`'a düşer (`gpui_linux/src/linux/wayland/window.rs:1469-1484`).
- X11'de client-side decoration istenir ama compositor desteği yoksa GPUI server-side decoration'a döner; `window_decorations()` da doğrudan `Decorations::Server` verir (`gpui_linux/src/linux/x11/window.rs:1742-1748`, `1818-1828`).

Bu davranışlar nedeniyle `PlatformTitleBar::effective_button_layout(...)` ve `render_left/right_window_controls(...)` fonksiyonları doğru sonucu vermek için ayar değerine değil, **gerçekleşmiş** `Decorations::Client` durumuna bakar. İstek ile sonucu eşit kabul eden bir port en sık görülen hatalardan birini yapar: kullanıcı CSD istemiş gibi görünür, fakat compositor başka türlü davranmış olabilir.

## 10. Uygulama katmanına önerilen model

Üst bar davranışını merkezi yönetmek için aşağıdaki trait sözleşmesi yeterlidir. Bu sözleşme, platform kabuğunun uygulamayla konuşacağı en küçük yüzeyi tanımlar:

```rust
trait TitleBarController {
    fn close_action(&self) -> Box<dyn Action>;
    fn new_window_action(&self) -> Box<dyn Action>;
    fn button_layout(&self, cx: &App) -> Option<WindowButtonLayout>;
    fn sidebar_state(&self, cx: &App) -> ShellSidebarState;
    fn use_system_window_tabs(&self, cx: &App) -> bool;
}
```

Bu sözleşme sayesinde platform titlebar, render anında uygulama state'ine şu beş soruyu sorar:

- Kapatma işlemi tam olarak ne anlama geliyor?
- Yeni pencere hangi action ile açılıyor?
- Linux butonları hangi tarafta durmalı?
- Sidebar açık mı; pencere kontrolleriyle çakışıyor mu?
- Native tab desteği aktif mi değil mi?

Zed'in tasarımındaki en önemli kararlardan biri budur: platform titlebar yalnızca pencere kabuğunun mekaniğini bilir. Ürünün neyi kapatacağına, hangi menüyü açacağına veya hangi workspace'i taşıyacağına üst uygulama katmanı karar verir. Port hedefinde de aynı ayrımı korumak kodun yönetilebilir kalmasını sağlar. Bu ayrım bulanıklaşırsa platform kabuğu zamanla ürünün iş kurallarını içine almaya başlar. Sonunda hem test etmesi zorlaşır hem de başka projeye taşınamaz hale gelir.
