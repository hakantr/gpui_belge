# Bölüm II — Zed kaynak haritası ve bağlantı modeli

Ardından Zed içindeki gerçek kaynakları ve başlık çubuğunun uygulama içinde hangi callbacklerle yaşadığını oku.

## 5. Zed kaynak haritası

| Parça | Kaynak | Görev |
| :-- | :-- | :-- |
| `PlatformTitleBar` | `crates/platform_title_bar/src/platform_title_bar.rs` | Ana render entity'si, drag alanı, arka plan, köşe yuvarlama, child slotları, sol/sağ buton yerleşimi. |
| `render_left_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD'de sol pencere butonlarını üretir. |
| `render_right_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD veya Windows için sağ pencere butonlarını üretir. |
| `LinuxWindowControls` | `crates/platform_title_bar/src/platforms/platform_linux.rs` | Linux minimize, maximize/restore ve close butonlarının GPUI render katmanı. |
| `WindowsWindowControls` | `crates/platform_title_bar/src/platforms/platform_windows.rs` | Windows caption butonları ve `WindowControlArea` eşleşmeleri. |
| `SystemWindowTabs` | `crates/platform_title_bar/src/system_window_tabs.rs` | Native pencere sekmeleri, sekme menüsü, sürükle-bırak ve pencere birleştirme davranışları. Modül private olduğu için dış crate API'si değildir; `PlatformTitleBar` içinde child entity olarak kullanılır. |
| `TitleBar` | `crates/title_bar/src/title_bar.rs` | Zed'in uygulama başlığı, proje adı, menü, kullanıcı ve workspace state'ini `PlatformTitleBar` içine bağlayan üst seviye bileşen. |
| `client_side_decorations` | `crates/workspace/src/workspace.rs` | CSD pencere gölgesi, border, resize kenarları ve inset yönetimi. |
| `WindowOptions` | `crates/gpui/src/platform.rs` | Pencere dekorasyonu, titlebar options ve native tabbing identifier ayarları. |

## 6. Zed içindeki bağlantı modeli

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

Zed uygulamasındaki gerçek yönetim zinciri şu kaynaklardan okunur:

| Aşama | Kaynak | Ne yapıyor? |
| :-- | :-- | :-- |
| Pencere açılışı | `crates/zed/src/zed.rs:322-370` | `ZED_WINDOW_DECORATIONS` env değeri veya `WorkspaceSettings::window_decorations` ile client/server decoration seçer; `TitlebarOptions { appears_transparent: true, traffic_light_position: Some(point(px(9), px(9))) }`, `is_movable: true`, `window_decorations`, `tabbing_identifier` ayarlarını verir. |
| GPUI pencere bootstrap'i | `crates/gpui/src/window.rs:1295-1299` | Platform native tab görünürlüğünü `SystemWindowTabController::init_visible` ile başlatır ve platform `tabbed_windows()` listesini controller'a ekler. |
| Title bar kurulumu | `crates/title_bar/src/title_bar.rs:79-88` | `PlatformTitleBar::init(cx)` çağrılır; her yeni `Workspace` için `TitleBar::new(...)` entity'si oluşturulup `workspace.set_titlebar_item(...)` ile workspace'e bağlanır. |
| Product titlebar render'i | `crates/title_bar/src/title_bar.rs:346-379` | `TitleBar`, her render'da `set_button_layout(...)` ve `set_children(...)` çağırır. `show_menus` açıksa platform kabuğu ile ürün başlığı iki satıra ayrılır; kapalıysa ürün child'ları doğrudan `PlatformTitleBar` içine verilir. |
| Platform titlebar render'i | `crates/platform_title_bar/src/platform_title_bar.rs:183-325` | Drag alanı, double-click, sidebar çakışması, Linux/Windows pencere kontrolleri, sağ tık window menu ve `SystemWindowTabs` child'ı burada birleşir. |
| CSD dış sarmal | `crates/workspace/src/workspace.rs:10475-10670` | `client_side_decorations(...)` shadow, border, resize edge, cursor ve `window.set_client_inset(...)` davranışlarını sağlar. Titlebar tek başına CSD penceresinin tamamı değildir. |
| Platform callback'leri | `crates/gpui/src/window.rs:1453-1565` | Button layout değişimi, aktif pencere değişimi, hit-test, native tab taşıma/birleştirme/seçme ve tab bar toggle callback'leri GPUI controller state'ine bağlanır. |

Bu zincirden çıkan port kuralı: `PlatformTitleBar` yalnızca render edilen başlık
kabuğudur. Zed'de onu yaşatan sistem `WindowOptions`, GPUI platform callback'leri,
`TitleBarSettings`, `Workspace` lifecycle'ı ve CSD sarmalıyla birlikte çalışır.

---

