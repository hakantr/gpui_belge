# Zed kaynak haritası ve bağlantı modeli

İlk bölümde katmanları ayırdık. Bu bölümde Zed tarafındaki gerçek kaynakların nerede durduğunu görürsün. Önce dosyaların fiziksel haritası çıkarılır; ardından başlık çubuğunun uygulama içinde hangi geri çağrılarla yaşadığı, hangi anda hangi entity'nin oluşturulduğu ve bu parçaların birbirine nasıl bağlandığı anlatılır.

## 5. Zed kaynak haritası

| Parça | Görev |
| :-- | :-- |
| `PlatformTitleBar` | Ana render entity'si, sürükleme alanı, arka plan, köşe yuvarlama, çocuk slotları, sol/sağ buton yerleşimi. |
| `render_left_window_controls` | Linux CSD'de sol pencere butonlarını üretir. |
| `render_right_window_controls` | Linux CSD veya Windows için sağ pencere butonlarını üretir. |
| `LinuxWindowControls` | Linux minimize, maximize/restore ve kapat butonlarının GPUI render katmanı. |
| `WindowsWindowControls` | Windows caption butonları ve `WindowControlArea` eşleşmeleri. |
| `SystemWindowTabs` | Yerel pencere sekmeleri, sekme menüsü, sürükle-bırak ve pencere birleştirme davranışları. Modül özel olduğu için dış crate API'si değildir; `PlatformTitleBar` içinde çocuk entity olarak kullanılır. |
| `TitleBar` | Zed'in uygulama başlığı, proje adı, menü, kullanıcı ve workspace durumunu `PlatformTitleBar` içine bağlayan üst seviye bileşen. |
| `OnboardingBanner` | Ürün başlık çubuğu için duyuru bandı altyapısı (`title_bar` crate'inde). Güncel sürümde `TitleBar`'a bağlı değildir; ayrıntı [Üst Bar](../ust_bar/ust_bar.md) bölümünde. |
| `UpdateVersion` | Otomatik güncelleme durumunu üst barda gösterir ve güncelleme ipucu metnini üretir. İpucu `"Sürüme Güncelle:"` önekini, SHA için de tam commit değerini kullanır. |
| `UpdateButton` | `UpdateVersion` tarafından kullanılan görsel kabuk. `checking`, `downloading`, `installing`, `updated`, `errored` durumları için ayrı yapıcılar sağlar. `Checking/Downloading/Installing` durumlarında butona `disabled(true)` ayarlanır; bu süre içinde tıklama davranışı kapalıdır. Döner durumlarda animasyonlu ikon `LoadCircle` (2 turluk dönüş) kullanılır. Hata durumu mesajı `"Güncelleme Başarısız"` biçimindedir. |
| `client_side_decorations` | CSD pencere gölgesi, kenarlık, resize kenarları ve inset yönetimi. |
| `WindowOptions` | Pencere dekorasyonu, titlebar seçenekleri ve yerel tabbing identifier ayarları. |

## 6. Zed içindeki bağlantı modeli

![TitleBar Başlatma → Render Zinciri](assets/titlebar-init-render-zinciri.svg)

Zed'in ana workspace penceresinde başlangıç noktası `title_bar::init(cx)` fonksiyonudur. Bu fonksiyon iki iş yapar. Önce platform kabuğunu hazırlamak için `PlatformTitleBar::init(cx)` çağırır. Sonra her yeni `Workspace` açıldığında bir `TitleBar` entity'si oluşturur ve bu entity'yi ilgili workspace'in titlebar item alanına yerleştirir.

Basitleştirilmiş akış şu şekilde okunabilir:

```rust
pub fn init(cx: &mut App) {
    platform_title_bar::PlatformTitleBar::init(cx);

    cx.observe_new(|calisma_alani: &mut Workspace, window, cx| {
        let Some(window) = window else {
            return;
        };

        let coklu_calisma_alani = calisma_alani.multi_workspace().cloned();
        let oge = cx.new(|cx| {
            TitleBar::new("baslik-cubugu", calisma_alani, coklu_calisma_alani, window, cx)
        });

        calisma_alani.set_titlebar_item(oge.into(), window, cx);
    })
    .detach();
}
```

`TitleBar` entity'si kendi `Render` akışı sırasında alt katmandaki `PlatformTitleBar` entity'sini günceller. Tipik render adımı şuna benzer:

```rust
self.platform_titlebar.update(cx, |baslik_cubugu, _| {
    baslik_cubugu.set_button_layout(buton_yerlesimi);
    baslik_cubugu.set_children(cocuklar);
});

self.platform_titlebar.clone().into_any_element()
```

Bu kullanım, port sırasında çok kolay kaçan bir ayrıntıyı gösterir: `PlatformTitleBar`, kendisine verilen çocuk elementleri render sırasında `mem::take` ile tüketir. Yani çocuk listesi bir kez verildikten sonra sonraki render'da boş kalır. Bu yüzden dinamik başlık içeriği her render geçişinde yeniden `set_children(...)` çağrısıyla tazelenmelidir. Entity oluşturulurken bir defalık verilen içerik sonraki karede görünmez.

Zed uygulamasındaki gerçek yönetim zinciri şu kaynaklardan takip edilir:

| Aşama | Ne yapıyor? |
| :-- | :-- |
| Pencere açılışı | `ZED_WINDOW_DECORATIONS` çevre değişkeni veya `WorkspaceSettings::window_decorations` ile client/server decoration seçer; `TitlebarOptions { appears_transparent: true, traffic_light_position: Some(point(px(9), px(9))) }`, `is_movable: true`, `window_decorations`, `tabbing_identifier` ayarlarını verir. |
| GPUI pencere başlangıcı | Platform yerel sekme görünürlüğünü `SystemWindowTabController::init_visible` ile başlatır ve platform `tabbed_windows()` listesini denetleyiciye ekler. |
| Başlık çubuğu kurulumu | `PlatformTitleBar::init(cx)` çağrılır; her yeni `Workspace` için `TitleBar::new(...)` entity'si oluşturulup `workspace.set_titlebar_item(...)` ile workspace'e bağlanır. |
| Ürün başlık çubuğu render geçişi | `TitleBar`, her render geçişinde `set_button_layout(...)` ve `set_children(...)` çağırır. `show_menus(cx)` sonucu açıksa platform kabuğu ile ürün başlığı iki satıra ayrılır; kapalıysa ürün çocukları doğrudan `PlatformTitleBar` içine verilir. Bu yardımcı yalnız ayarı değil, macOS'ta `ZED_USE_CROSS_PLATFORM_MENU` çevre değişkeni koşulunu da dikkate alır. |
| Ürün başlık çubuğu duyuru bandı | Duyuru bandı `TitleBar` katmanında yönetilir; platform kabuğu bunu bilmez. Duyuru bandı altyapısı güncel sürümde bağlı değildir (alan `None`). Ayrıntı [Üst Bar](../ust_bar/ust_bar.md) bölümünde. |
| Güncelleme bildirimi | İndirme, kurulum ve güncellendi durumları ipucu metnini `version_tooltip_message(...)` üzerinden alır. Metin `"Sürüme Güncelle:"` biçimindedir; SHA kısaltılmaz. |
| Platform başlık çubuğu render geçişi | Sürükleme alanı, çift tıklama, yan panel çakışması, Linux/Windows pencere kontrolleri, sağ tık pencere menüsü ve `SystemWindowTabs` çocuğu burada birleşir. |
| CSD dış sarmal | `client_side_decorations(...)` gölge, kenarlık, yeniden boyutlandırma kenarı, imleç ve `window.set_client_inset(...)` davranışlarını sağlar. Başlık çubuğu tek başına CSD penceresinin tamamı değildir. |
| Workspace/proje aktivasyonu | `OpenMode::NewWindow` yanında `OpenMode::Activate` de `window.activate_window()` çağırır. Mevcut pencereye/yan panele açılan proje aktif hale getirildiğinde başlık çubuğu durumu da pencere öne alınmış kabulüyle güncellenmelidir. |
| Platform geri çağrıları | Buton yerleşimi değişimi, aktif pencere değişimi, hit-test, yerel sekme taşıma/birleştirme/seçme ve sekme çubuğu geçiş geri çağrıları GPUI denetleyici durumuna bağlanır. |

Bu zincirden çıkan port kuralı nettir: `PlatformTitleBar` tek başına tam bir başlık çubuğu uygulaması değildir. O yalnızca render edilen başlık kabuğunu temsil eder. Zed'de bu kabuğu gerçekten çalışır hale getiren şey; `WindowOptions` ayarları, GPUI'nin platform geri çağrıları, `TitleBarSettings`, `Workspace` yaşam döngüsü ve CSD sarmalının birlikte kurduğu bütündür. Port hedefinde de bu beş parça aynı anda düşünmen gerekir. Bunlardan biri eksik kalırsa başlık çubuğunun davranış paritesi bozulur.

---
