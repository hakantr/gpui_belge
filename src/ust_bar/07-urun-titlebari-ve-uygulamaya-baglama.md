# Ürün titlebar'ı ve uygulamaya bağlama

Platform kabuğu hazır olunca ürün başlığı, sidebar bilgisi, menüler ve uygulama shell'i bu kabuğa bağlanır.

## 15. Sidebar ve workspace etkileşimi

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

Zed'in ürün modelinde klasör ve projeler varsayılan olarak yeni pencere açmak
yerine mevcut pencerenin threads sidebar'ına eklenebilir. `File > Open`,
`File > Open Recent`, klasör sürükleme ve `zed ~/project` davranışı aynı pencere
içinde workspace değiştirebilir; yeni pencere için Open Recent'ta Cmd/Ctrl+Enter
veya CLI tarafında `zed -n` kullanılır. `cli_default_open_behavior` varsayılanı
`existing_window` ise CLI açılışları da mevcut pencere/sidebar yolunu izler.

Bu durum `PlatformTitleBar` render sözleşmesini değiştirmez: zayıf
`MultiWorkspace` referansı platform kabuğunda sadece sidebar tarafındaki pencere
kontrolü çakışmasını çözmek için okunur. Ürün titlebar'ı için kural şudur:
aktif proje/workspace değişimi pencere değişmeden gerçekleşebilir. Proje adı,
worktree bilgisi, sidebar tarafı ve başlık içeriği `Window` lifecycle'ına değil
aktif `MultiWorkspace::workspace()` durumuna gözlemci bağlayarak güncellenmelidir.

Sidebar açık mı sorusunu "açık proje var mı" sorusundan ayrı tutun. Boş
workspace'lerde yeni thread/terminal oluşturma no-op olabilir; buna rağmen
sidebar'ın açık/kapalı ve sol/sağ konumu titlebar kontrol çakışması için ayrı
bir render state'tir.

## 16. Başlık çubuğuna içerik yerleştirme

`PlatformTitleBar` kendi başına sadece platform kabuğunu sağlar. Zed'in gerçek
ürün başlığı `crates/title_bar/src/title_bar.rs` içindeki `TitleBar` tarafından
oluşturulur. Bu katman şunları child olarak verir:

- Uygulama menüsü.
- Proje adı / recent projects popover.
- Git branch adı ve durum ikonu.
- Restricted mode göstergesi.
- Kullanıcı menüsü, sign-in butonu, plan chip, update bildirimi.
- Collab/screen share göstergeleri.
- Feature flag'e bağlı onboarding/announcement banner'ları.
- Update bildirimi tooltip'i (`Update to Version: ...` gibi).

Update tooltip'inin biçimi `crates/title_bar/src/update_version.rs:66-75`
içindeki `version_tooltip_message` fonksiyonunda kurulur. Sürüm semantik ise
`SemanticVersion::to_string()` çıktısı; commit SHA ise `AppCommitSha::full()`
ile kısaltılmamış 40 karakterlik hash döner (önceki "`14d9a41…`" tarzı kısa
gösterim kaldırılmıştır). Tooltip metni her durumda `"Update to Version:"`
ön ekiyle başlar. Portta tooltip kabuğu için bu uzun string'in tek satıra
sığacağı varsayılmamalıdır; `Tooltip::text` veya muadili genişlik sınırı
düşünülmelidir.

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

## 17. Kendi uygulamana dahil etme

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

---

