# Entegrasyon başlangıcı ve uygulama sözleşmesi

İskelet hazır olduktan sonra iki somut adım gelir. İlki pencerenin doğru seçeneklerle açılmasıdır. İkincisi ise platform kabuğunun uygulama durumuyla konuşacağı controller sözleşmesinin tanımlanmasıdır. Bu iki adım birlikte düşünülür. `WindowOptions` ayarları olmadan platform kabuğu doğru zemini bulamaz; controller sözleşmesi olmadan da uygulamanın iş kurallarını öğrenemez.

## 9. Entegrasyon ön koşulları

### Pencere seçenekleri

Özel titlebar davranışının çalışması, pencere açılırken verilen birkaç kritik ayara bağlıdır. Zed'in ana penceresinde `WindowOptions` içinde üst barı doğrudan ilgilendiren alanlar şunlardır; kaynakta bunlara ek olarak `focus`, `show`, `kind`, `display_id`, `window_background`, `app_id`, Linux/FreeBSD `icon` ve `window_min_size` gibi genel pencere alanları da ayrıca ayarlanır:

```rust
WindowOptions {
    titlebar: Some(TitlebarOptions {
        title: None,
        appears_transparent: true,
        traffic_light_position: Some(point(px(9.0), px(9.0))),
    }),
    is_movable: true,
    window_decorations: Some(pencere_dekorasyonlari),
    tabbing_identifier: if sistem_pencere_sekmeleri_kullanilsin_mi {
        Some(String::from("kvs-uygulama"))
    } else {
        None
    },
    ..Default::default()
}
```

Bu alanların pratik karşılığı şudur:

- `titlebar.appears_transparent = true`, özel başlık içeriğinin native titlebar ile görsel olarak çakışmasını önler. Böylece iki katman üst üste binip kullanıcıya tuhaf bir görünüm vermez.
- `is_movable = true`, platformun pencere taşıma davranışının çalışması için açık kalmalıdır. Bu alanın kapalı bırakılması, başlık çubuğundan pencerenin sürüklenememesine yol açar.
- Linux/FreeBSD tarafında `window_decorations: Some(WindowDecorations::Client)` seçildiğinde Zed'in Linux pencere butonları ve client-side decoration (CSD) kenarları devreye girer. Bu yol en fazla kontrolü verir; aynı zamanda en fazla ayar isteyen yoldur.
- macOS'ta native tab grupları kullanılacaksa, aynı uygulamaya ait pencerelerin tamamına ortak bir `tabbing_identifier` vermen gerekir. Farklı identifier'lar pencerelerin aynı tab grubuna düşmemesine yol açar.

### Client-side decoration sarmalı

`PlatformTitleBar` yalnızca üst başlık çubuğunu üretir. Bu çubuğun etrafındaki pencere gölgesi, kenarlık, yeniden boyutlandırma kenarı ve client inset yönetimi onun sorumluluğunda değildir. Zed'de bu işler `workspace::client_side_decorations(...)` fonksiyonunun oluşturduğu ayrı bir sarmal tarafından yaparsın.

Bir uygulamada Linux CSD desteği isteniyorsa, aynı sorumlulukları karşılayan bir sarmal port tarafında da yazılmalıdır. Bu sarmalın yüklendiği işler şunlardır:

- CSD aktifken `window.set_client_inset(...)` çağrısı yapmak.
- Pencere kenarlığını ve gölgesini çizmek.
- Tiling durumuna göre uygun köşe yuvarlamasını uygulamak.
- Kenarlardan yeniden boyutlandırma işleminin başlatılmasını sağlamak.
- İçerik alanına geçen imleç yayılımını kesmek.

Bu sarmal yazılmasa da başlık çubuğu görünür; temel olarak çalışır. Ancak pencere kenarı ve yeniden boyutlandırma davranışı Zed ile aynı hissi vermez. Yani başlık çubuğu tek başına CSD penceresi değildir; çevresinde bu sarmalın bulunması gerekir.

**İstenen dekorasyon ile gerçekleşen dekorasyon aynı kabul edilemez.** `WindowOptions.window_decorations` alanı yalnızca bir istek değeridir. Render sırasında bağlayıcı olan değer, her zaman `window.window_decorations()` çağrısının döndürdüğü gerçek durumdur. Kaynakta bu fark iki platformda açıkça görünür:

- Wayland'da server-side decoration istenir ama compositor decoration protokolünü desteklemezse GPUI `WindowDecorations::Client`'a düşer.
- X11'de client-side decoration istenir ama compositor desteği yoksa GPUI server-side decoration'a döner; `window_decorations()` da doğrudan `Decorations::Server` verir.

Bu davranışlar nedeniyle `PlatformTitleBar::effective_button_layout(...)` ve `render_left/right_window_controls(...)` fonksiyonları doğru sonucu vermek için ayar değerine değil, **gerçekleşmiş** `Decorations::Client` durumuna bakar. İstek ile sonucu eşit kabul eden bir port en sık görülen hatalardan birini yapar: kullanıcı CSD istemiş gibi görünür, fakat compositor başka türlü davranmış olabilir.

## 10. Uygulama katmanına önerilen model

Üst bar davranışını merkezi yönetmek için aşağıdaki trait sözleşmesi yeterlidir. Bu sözleşme, platform kabuğunun uygulamayla konuşacağı en küçük yüzeyi tanımlar:

```rust
trait TitleBarController {
    fn kapat_eylemi(&self) -> Box<dyn Action>;
    fn yeni_pencere_eylemi(&self) -> Box<dyn Action>;
    fn buton_yerlesimi(&self, cx: &App) -> Option<WindowButtonLayout>;
    fn yan_panel_durumu(&self, cx: &App) -> ShellSidebarState;
    fn sistem_pencere_sekmeleri_kullanilsin_mi(&self, cx: &App) -> bool;
}
```

Bu sözleşme sayesinde platform titlebar, render anında uygulama durumuna şu beş soruyu sorar:

- Kapatma işlemi tam olarak ne anlama geliyor?
- Yeni pencere hangi eylem ile açılıyor?
- Linux butonları hangi tarafta durmalı?
- Yan panel açık mı; pencere kontrolleriyle çakışıyor mu?
- Native tab desteği aktif mi değil mi?

Zed'in tasarımındaki en önemli kararlardan biri budur: platform titlebar yalnızca pencere kabuğunun mekaniğini bilir. Ürünün neyi kapatacağına, hangi menüyü açacağına veya hangi workspace'i taşıyacağına üst uygulama katmanı karar verir. Port hedefinde de aynı ayrımı korumak kodun yönetilebilir kalmasını sağlar. Bu ayrım bulanıklaşırsa platform kabuğu zamanla ürünün iş kurallarını içine almaya başlar. Sonunda hem test etmesi zorlaşır hem de başka projeye taşınamaz hale gelir.
