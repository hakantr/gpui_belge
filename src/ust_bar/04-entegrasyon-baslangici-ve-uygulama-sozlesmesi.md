# Bölüm IV — Entegrasyon başlangıcı ve uygulama sözleşmesi

Pencere açılırken gereken GPUI ayarlarını yap ve platform kabuğunun uygulama state'ine soracağı controller sözleşmesini tanımla.

## 9. Entegrasyon ön koşulları

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

**İstenen decoration ile gerçek decoration aynı kabul edilmemelidir.**
`WindowOptions.window_decorations` sadece istek değeridir; render sırasında
her zaman `window.window_decorations()` sonucu esas alınır. Kaynakta iki
platform farkı var:

- Wayland'da server-side decoration istenir ama compositor decoration
  protokolünü desteklemezse GPUI `WindowDecorations::Client`'a düşer
  (`gpui_linux/src/linux/wayland/window.rs:1469-1484`).
- X11'de client-side decoration istenir ama compositor desteği yoksa GPUI
  server-side decoration'a döner; `window_decorations()` da doğrudan
  `Decorations::Server` verir (`gpui_linux/src/linux/x11/window.rs:1742-1748`,
  `1818-1828`).

Bu yüzden `PlatformTitleBar::effective_button_layout(...)` ve
`render_left/right_window_controls(...)` doğru şekilde ayar değerine değil
**actual** `Decorations::Client` sonucuna bakar.

## 10. Uygulama katmanına önerilen model

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

