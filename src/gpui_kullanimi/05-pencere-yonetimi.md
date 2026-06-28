# Pencere Yönetimi

## Sürüm Analiz Raporu

- [x] Kaynak commit aralığı: `f88bc7e18aeb..46ff888db853`.
- [x] Doğrulanan pencere yüzeyi: `WindowOptions::is_movable` macOS özel başlık çubuğu notu ve `WindowParams::app_id` aktarımı.
- [x] Kaynak doğrulama dosyaları: `crates/gpui/src/platform.rs` ve `crates/gpui/src/window.rs`.

---

## Pencere Oluşturma

![GPUI Pencere Yaşam Döngüsü](assets/pencere-yasam-dongusu.svg)

Pencerenin oluşturulması (`open_window`), odaklanarak aktif hale gelmesi (`activation`), arka plana alınması (`minimize`) ve nihai olarak kapatılması (`on_window_closed`) süreçleri işletim sistemi ile eşgüdümlü olarak yürütülür. Yukarıdaki yaşam döngüsü şeması bu durum geçişlerini ve olay kancalarını özetlemektedir.

GPUI üzerinde pencere açmak için kullanılan temel API `cx.open_window(options, root_builder)` işlevidir. Buradaki ilk parametre pencerenin başlangıç davranışlarını tanımlayan `WindowOptions` yapısıyken; ikinci parametre ise pencerenin kök görünümünü (root view) yapılandıran bir closure'dır. Tipik kullanım senaryolarında şu kod kalıbı izlenir:

```rust
let tutamac = cx.open_window(
    WindowOptions {
        window_bounds: Some(WindowBounds::centered(size(px(900.), px(700.)), cx)),
        titlebar: Some(TitlebarOptions {
            title: Some("Pencerem".into()),
            appears_transparent: true,
            traffic_light_position: Some(point(px(9.), px(9.))),
        }),
        focus: true,
        show: true,
        kind: WindowKind::Normal,
        is_movable: true,
        is_resizable: true,
        is_minimizable: true,
        window_min_size: Some(size(px(360.), px(240.))),
        window_background: cx.theme().window_background_appearance(),
        window_decorations: Some(gpui::WindowDecorations::Client),
        app_id: Some(ReleaseChannel::global(cx).app_id().to_owned()),
        ..Default::default()
    },
    |window, cx| {
        window.activate_window();
        cx.new(|cx| KokGorunum::new(window, cx))
    },
)?;
```

**`WindowOptions` alanları.** Aşağıdaki alanlar, pencerenin oluşturulması sürecinde rol alan temel yapılandırma parametrelerini tanımlamaktadır:

- `window_bounds`: Bu alan `None` olarak geçilirse, GPUI otomatik olarak bir temel sınır seçer ve yeni pencerenin başlangıç konumuna 25 piksellik kademeli bir kaydırma (cascade) payı ekler. Temel sınır; aktif bir pencere varsa onun geri yüklenebilir boyutunu, aktif bir pencere bulunmuyorsa hedef ekranın (display) `default_bounds()` değerini baz alır. Kademeli kaydırma mantığı her iki senaryoda da işler; dolayısıyla aktif pencere bulunmadığında bile ekran varsayılan değerlerinin üzerine 25 piksel eklenir. Konumu kaydırılan pencerenin ekranın görünür sınırlarının dışına taşması durumunda, pencere görünür alan sınırlarına sabitlenir. Ekran varsayılanı, `gpui::DEFAULT_WINDOW_SIZE: Size<Pixels>` (1536×1095) değerini mevcut ekran boyutuna göre kırparak ortalar. `Some` ile iletilen değer ise pencerenin `Windowed`, `Maximized` veya `Fullscreen` durumlarından hangisiyle başlatılacağını belirler; `Maximized` ve `Fullscreen` modlarında iletilen sınırlar, geri yükleme boyutu olarak bellek altında tutulur. Ek veya yardımcı pencereler için Zed tarafında sıkça yararlanılan bir diğer sabit değer ise `gpui::DEFAULT_ADDITIONAL_WINDOW_SIZE` (900×750 piksel, ayarlar veya kütüphane arayüzleri için 6:5 oranında) yapısıdır. Özel bir varsayılan boyut tanımlama ihtiyacı bulunmadığı durumlarda, `None` seçeneğinin sunduğu kademeli varsayılan davranışa güvenmek en pratik yoldur.
- `titlebar`: Sistem başlık çubuğu ayarlarını yapılandırmak amacıyla `Some(TitlebarOptions)` değeri iletilir. `None` değeri sağlandığında ise istemci tarafından çizilen özel başlık çubuğu (custom titlebar) mekanizması etkinleşir.
- `focus`: Pencerenin oluşturulduğu anda klavye odağını otomatik olarak devralıp devralmayacağını belirler.
- `show`: Pencerenin oluşturulur oluşturulmaz ekranda görünür olup olmayacağını denetler. Örneğin Zed, ana uygulama pencerelerini başlangıçta `show: false` ve `focus: false` ayarlarıyla arka planda yükler, arayüz tamamen hazır duruma geldiğinde ise görünür kılar.
- `kind`: Pencerenin türünü belirler. `Normal`, `PopUp`, `Floating`, `Dialog` varyantlarının yanı sıra Linux Wayland desteği etkin olduğunda `LayerShell` seçeneği de kullanılabilir durumdadır.
- `is_movable`, `is_resizable`, `is_minimizable`: Pencerenin taşınabilirliği, yeniden boyutlandırılabilirliği ve simge durumuna küçültülebilirliği gibi platform düzeyindeki yetenekleri denetleyen bayraklardır. Yerel pencere taşıma davranışının korunması gerekiyorsa `is_movable: true` kullanılır; macOS 27 üzerinde özel başlık çubuğu kendi sürükleme davranışını `Window::start_window_move` ile yönetiyorsa `is_movable: false` tercih edilir. Aksi halde AppKit başlık alanını sistemin sahip olduğu bir bölge gibi yorumlayıp çift tıklama ayrıştırması sırasında tıklamaları geciktirebilir.
- `display_id`: Pencerenin hangi monitör üzerinde açılacağını belirlemek amacıyla ilgili ekranın benzersiz kimliğini kabul eder.
- `window_background`: Arka plan görünümünü belirleyen `Opaque`, `Transparent`, `Blurred` değerlerinin yanı sıra her platform için tanımlanmış `MicaBackdrop` ve `MicaAltBackdrop` varyantlarını içerir. Ancak Mica tabanlı arka planların görsel etkisi yalnızca Windows 11 üzerinde (DWM motoru aracılığıyla) desteklenir.
- `app_id`: Linux masaüstü ortamlarında pencerelerin doğru şekilde gruplandırılması ve görev çubuğu davranışlarının düzenlenmesi amacıyla kullanılır.
- `window_min_size`: Pencerenin küçülebileceği en küçük boyut sınırını tanımlar.
- `window_decorations`: Pencere süslemelerinin sunucu tarafında mı (`Server`) yoksa istemci tarafında mı (`Client`) oluşturulacağını belirler. Linux platformunda oldukça kritik bir öneme sahip olan bu alan, macOS ve Windows tarafında yerini pratikte `TitlebarOptions` ayarlarına bırakır.
- `icon`: X11 pencere yöneticilerinde görüntülenecek pencere ikonunu tanımlamak amacıyla kullanılır.
- `tabbing_identifier`: macOS işletim sistemine özel yerel pencere sekmelerinin (window tabs) gruplandırılmasında kullanılan tanımlayıcıyı belirtir.

GPUI arka planında `Window::new` çağrısı, düşük seviyeli platform penceresini oluşturduktan sonra şu işlem sırasını takip eder:

1. `platform_window.request_decorations(...)` işlevi aracılığıyla süsleme türü talep edilir.
2. `platform_window.set_background_appearance(window_background)` ile arka plan görünümü yapılandırılır.
3. Pencere sınırları `Fullscreen` ise tam ekran modu, `Maximized` ise ekranı kaplama yakınlaştırması uygulanır.
4. Platform düzeyindeki geri çağrı (callback) mekanizmaları bağlanır.

Pencerenin ilk çizim işlemi `Window::new` gövdesi içinde gerçekleştirilmez. Bu süreç, bir üst katmandaki `open_window` akışında tamamlanır: Kök görünüm (root view) kurulduktan hemen sonra, pencerenin ekranda belirmesinden önce en az bir defa çizim altyapısının çalıştırılması amacıyla `window.draw(...)` çağrısı tetiklenir ve ardından ilgili pencere tutamacı (handle) geri döndürülür.

## Zed'de Ana Pencere Nasıl Açılır?

Zed editörünün ana pencere açma süreçleri `build_window_options` yardımcı fonksiyonunda merkezileştirilmiştir. Proje genelinde yeni bir çalışma alanı (workspace) penceresi başlatılmak istendiğinde bu fonksiyondan yararlanılması önerilir:

```rust
let secenekler = zed::build_window_options(ekran_uuid, cx);
let window = cx.open_window(secenekler, |window, cx| {
    cx.new(|cx| Workspace::new(/* ... */, window, cx))
})?;
```

Bu fonksiyon arka planda sırasıyla şu işlemleri gerçekleştirir:

- `display_uuid` parametresini kullanarak uygun ekran referansını bulur.
- `ZED_WINDOW_DECORATIONS=server|client` ortam değişkenini (environment variable) denetleyerek harici bir yapılandırma olup olmadığını kontrol eder.
- Ortam değişkeni bulunmuyorsa varsayılan davranış olarak `WorkspaceSettings::window_decorations` ayarını baz alır.
- Görsel tasarım standartlarına uygun olarak `TitlebarOptions { appears_transparent: true, traffic_light_position: (9,9) }` ayarlarını yapılandırır.
- Pencerelerin arka planda yüklenmesi için `focus: false`, `show: false` ve `kind: WindowKind::Normal` tanımlamalarını uygular.
- Pencere arka plan rengini (`window_background`) aktif tema paletinden devralır.
- Linux ve FreeBSD işletim sistemleri için uygulama ikonunu pencereye bağlar.
- macOS platformunda yerel sekmeli çalışma tercih edilmişse `tabbing_identifier: Some("zed")` atamasını gerçekleştirir.

Hakkında (About) veya çeşitli modal bildirim pencereleri gibi daha küçük ölçekli arayüzlerde bu fonksiyonu çağırmak yerine, doğrudan amaca yönelik `WindowOptions` yapılandırması oluşturmak daha yaygın bir tasarım kalıbıdır. Örneğin "hakkında" penceresi şu seçeneklerle yapılandırılır:

- Ekran üzerinde merkezlenmiş sınırlar (`centered`)
- Saydam başlık çubuğu görünümü (`appears_transparent: true`)
- Yeniden boyutlandırılamayan pencere yapısı (`is_resizable: false`)
- Simge durumuna küçültülemeyen yapı (`is_minimizable: false`)
- Yüzen pencere türü (`kind: WindowKind::Floating`)

## Ekran ve Çoklu Monitör

Sistemde birden fazla ekran bağlandığında hedef ekran, uygulama bağlamı üzerinden `cx.displays()` listesi taranarak tespit edilebilir. Bu liste, bağlı her bir ekranın kimlik bilgisini, fiziksel sınırlarını ve varsa UUID verilerini sunar:

```rust
for ekran in cx.displays() {
    let id = ekran.id();
    let sinirlar = ekran.bounds();
    let gorunur_sinirlar = ekran.visible_bounds();
    let uuid = ekran.uuid().ok();
}
```

Belirli bir ekran üzerinde yeni bir pencere başlatmak için seçilen ekranın kimlik değeri yapılandırma ayarlarına iletilmelidir:

```rust
WindowOptions {
    display_id: Some(ekran.id()),
    window_bounds: Some(WindowBounds::Windowed(sinirlar)),
    ..Default::default()
}
```

Ekran sınırları (`Bounds`) her zaman piksel cinsinden küresel ekran koordinat sisteminde ifade edilir. `WindowBounds::centered(size, cx)` çağrısı, ana veya varsayılan ekran üzerinde otomatik merkezleme gerçekleştirir. Özel koordinatlarla elle konumlandırma yapılması gereken durumlarda ise `Bounds::new(origin, size)` yapısı tercih edilmelidir.

## WindowKind Davranışı

Pencerenin işletim sistemi düzeyindeki rolü ve davranış şekli `WindowKind` enum varyantları ile belirlenir. Yapılan bu seçim pencerenin odaklanma kurallarını, katman sırasını (z-order) ve kenar süslemelerini doğrudan etkiler:

- `Normal`: Standart ana uygulama penceresi.
- `PopUp`: Diğer pencerelerin her zaman üstünde konumlanan, bildirimler ve geçici açılır pencereler için kullanılan pencere yapısı. Örneğin Zed, kullanıcı bildirim pencerelerini oluştururken bu türden yararlanır.
- `Floating`: Ana pencere üzerinde serbestçe yüzen ve diğer içeriklerin üstünde kalan yardımcı arayüz paneli.
- `Dialog`: Ana pencereyle olan etkileşimi geçici olarak askıya alan modal platform penceresi.
- `LayerShell`: Wayland görüntü sunucusunun `layer-shell` özelliği etkin olduğunda dock (rıhtım), durum çubukları veya arka plan yüzeyleri üretmek amacıyla tercih edilir.

GPUI mimarisinde modal kutular, popover panelleri ve menüler gibi yaşam döngüleri başka bir görünüm (view) tarafından kontrol edilen dinamik parçalar `ManagedView` protokolüne bağlı çalışır. Bu protokol, `Focusable + EventEmitter<DismissEvent> + Render` özelliklerinin (trait boundaries) bir araya gelmesiyle oluşur. Görünüm nesnesi bir `DismissEvent` yaydığında (emit ettiğinde), onu ekranda sunan üst katman bu tetiklemeyi yakalayarak modalı veya geçici menüyü bellekten kaldırabilir. `ManagedView` ve `DismissEvent` desenlerinin, uygulama içi görünüm tabanlı yapılar için tasarlandığını akılda tutmak gerekir; bu mekanizmalar, işletim sistemi düzeyinde etkileşimi bloke eden `WindowKind::Dialog` platform pencere yapısından tamamen farklı çalışır.

| Arayüz / Yapı | Alt Bileşen Sınırları | Temel Amacı |
| :-- | :-- | :-- |
| `ManagedView` | `Focusable + EventEmitter<DismissEvent> + Render` | Modal, popover veya menü gibi üst katmanlarca yönetilen görünümlerin ortak arayüz sözleşmesidir. |
| `DismissEvent` | Boş etkinlik yapısı (`struct`) | Görünümün kapatılma talebini kendisini sunan üst katmana iletmesini sağlar. |
| `Focusable` | `focus_handle(&self, cx)` | Görünümün odaklanma handle referansını dışarıya sunar; `cx.focus_view` bu yapıya dayanır. |
| `FocusId`, `WeakFocusHandle` | Benzersiz odak kimliği, `upgrade` | Odak ağacı (focus tree) kimlik tanımlayıcısı ve zayıf referanslı odak tutamacıdır. |

Açılır pencerelerde (pop-up) ve masaüstü bildirimlerinde sıklıkla tercih edilen tipik yapılandırma şu şekildedir:

```rust
WindowOptions {
    titlebar: None,
    kind: WindowKind::PopUp,
    focus: false,
    show: true,
    is_movable: false,
    window_background: WindowBackgroundAppearance::Transparent,
    window_decorations: Some(WindowDecorations::Client),
    ..Default::default()
}
```

Bu kullanım desenine ait somut örnekler Zed kod tabanındaki `agent_ui` ve `collab_ui` paketleri (crates) altında incelenebilir.

## Başlık Çubuğu ve Pencere Süslemesi

Başlık çubuğu (titlebar) ve pencere süslemesi (window decoration) teknik olarak birbirinden farklı iki konsepttir. Arayüz kararlılığını korumak adına bu iki kavramın sorumluluk sınırlarını ayrı ele almak gerekir:

- `TitlebarOptions`: macOS ve Windows işletim sistemlerindeki yerel başlık çubuğu görünümlerini, başlık metinlerini ve macOS tarafındaki pencere kontrol butonlarının (traffic light) konumlandırmalarını yönetir.
- `WindowDecorations`: Linux (Wayland ve X11) ortamlarında süsleme katmanının pencere yöneticisi/sunucusu tarafından mı (`Server`) yoksa doğrudan uygulamanın kendisi (istemci) tarafından mı (`Client`) çizileceğini belirler.

GPUI tarafında bu durumları yönetmek üzere şu veri tipleri sunulmuştur:

```rust
pub enum WindowDecorations {
    Server,
    Client,
}

pub enum Decorations {
    Server,
    Client { tiling: Tiling },
}
```

`WindowDecorations` pencere başlatılırken talep edilen süsleme kipini temsil ederken; `Decorations` ise işletim sistemi pencere yöneticisinden dönen fiili durumu ifade eder ve `window.window_decorations()` çağrısı vasıtasıyla sorgulanabilir. Ekran kompozitörü (compositor) kısıtlamaları nedeniyle talep edilen süsleme biçimi her zaman tam olarak karşılanamayabilir; bu sebeple iki veri yapısı birbirinden ayrı tutulmalıdır.

`Tiling` yapısı, istemci tarafı süslemelerin ekran kenarlarına yapışık (döşenmiş) olup olmadığını dört ana yön (`top`, `left`, `right`, `bottom`) doğrultusunda denetler. `Tiling::tiled()` işlevi tüm kenarların yapışık olduğunu varsayan hazır bir yapılandırma sunarken; `Tiling::is_tiled()` metodu en az bir kenarın ekrana sıfırlandığı durumlarda `true` değerini döndürür. Bu kenar hizalama verileri, arayüzde dinamik olarak yeniden boyutlandırma tutamakları (resize handles) veya başlık çubuğu boşlukları hesaplanırken önem kazanır; standart pencere açılışlarında ise `WindowOptions.window_decorations` tanımı genellikle tek başına yeterlidir.

| Veri Yapısı | Desteklenen Nitelikler | Kullanım Amacı |
| :-- | :-- | :-- |
| `WindowDecorations` | `Server`, `Client` | Pencere açılışında arzu edilen dekorasyon yöntemini belirtir. |
| `Decorations` | `Server`, `Client { tiling }` | Pencere yöneticisi tarafından onaylanan gerçek süsleme durumunu bildirir. |
| `Tiling` | `top`, `left`, `right`, `bottom`, `tiled`, `is_tiled` | İstemci dekorasyonunun ekran sınırlarına yapışma durumunu detaylandırır. |
| `WindowBounds` | `Windowed`, `Maximized`, `Fullscreen`, `centered` | Pencerenin ekrandaki fiziksel boyut alanını ve durumunu temsil eder. |

Zed üzerindeki dekorasyon tercihi yapılandırma dosyasında tek bir alan ile ifade edilir:

```json
{
  "window_decorations": "client"
}
```

Aynı zamanda terminal üzerinden ortam değişkeni (environment variable) kullanılarak da bu ayar ezilebilir:

```sh
ZED_WINDOW_DECORATIONS=server
ZED_WINDOW_DECORATIONS=client
```

Zed ayar tipleri içinde yer alan `settings_content::workspace::WindowDecorations` tanımı yalnızca `client` ve `server` değerlerini kabul etmektedir; varsayılan tercih ise `client` olarak belirlenmiştir.

## Özel Başlık Çubuğu Nasıl Tanımlanır?

Basit bir GPUI projesinde işletim sisteminin sağladığı yerel başlık çubuğunu tamamen kapatıp, onun yerine özel tasarlanmış bir başlık çubuğu bileşenini kök görünüm (root view) içerisine dahil etmek mümkündür:

```rust
cx.open_window(
    WindowOptions {
        titlebar: None,
        is_movable: false,
        ..Default::default()
    },
    |_, cx| cx.new(|_| OrnekGorunum),
)?;
```

Kök görünüm içerisinde özel başlık çubuğu şu yapısal şablonda çizilebilir:

```rust
div()
    .flex()
    .flex_col()
    .size_full()
    .child(
        h_flex()
            .window_control_area(WindowControlArea::Drag)
            .h(px(34.))
            .child("Başlık")
    )
    .child(icerik)
```

Bu modelde pencere sürükleme davranışı `WindowControlArea::Drag` veya doğrudan `window.start_window_move()` üzerinden uygulama tarafında başlatılır. Özellikle macOS 27 hedefinde `WindowOptions::is_movable` alanının `false` bırakılması, özel başlık çubuğu alanındaki tıklamaların sistem başlık çubuğu çift tıklama ayrıştırmasına takılmadan uygulama hit-test hattına ulaşmasını sağlar.

Özellikle Windows platformunda pencere kontrol butonlarının (caption buttons) yer aldığı bölgelerin doğru tanımlanması için `window_control_area` çağrısı kritik bir role sahiptir; işletim sistemi düzeyindeki tıklama çarpışma testleri (hit testing) doğrudan bu alanlar üzerinden çözümlenir:

- `WindowControlArea::Drag`: Pencerenin fareyle sürüklenebileceği başlık alanını belirtir.
- `WindowControlArea::Close`: Yerel pencere kapatma butonunun tetikleme alanını tanımlar.
- `WindowControlArea::Max`: Ekranı kaplama (maximize) veya pencereli moda geri dönme butonu alanıdır.
- `WindowControlArea::Min`: Pencereyi simge durumuna küçültme butonunun tıklama alanıdır.

Zed mimarisinde yeni bir çalışma alanı (workspace) penceresi tasarlarken sıfırdan başlık çubuğu yazmak yerine, kütüphanenin hazır sunduğu `PlatformTitleBar` bileşeni kullanılır:

```rust
let platform_baslik_cubugu = cx.new(|cx| {
    PlatformTitleBar::new("baslik-cubugu", cx)
});

platform_baslik_cubugu.update(cx, |baslik_cubugu, _| {
    baslik_cubugu.set_children([sol_veya_orta_icerik.into_any_element()]);
});

platform_baslik_cubugu.into_any_element()
```

`PlatformTitleBar` bileşeni varsayılan olarak şu işlevleri otomatik olarak yürütür:

- Linux istemci tarafı süslemesi (CSD) için sol ve sağ taraftaki kontrol butonlarının yerleşimi.
- Windows işletim sistemine özel pencere kontrol butonlarının konumlandırılması.
- macOS platformundaki traffic light buton yerleşimi, iç boşlukları ve çift tıklama eylemleri.
- Linux üzerinde başlık çubuğuna çift tıklandığında ekranı kaplama veya eski boyuta döndürme işlevleri.
- Başlık çubuğunun genel sürükleme alanlarının yapılandırılması.
- Linux platformunda başlık çubuğuna sağ tıklandığında açılan pencere menüsü.
- Yan panellerin (sidebars) açık olduğu senaryolarda butonlar ile arayüz köşe yuvarlamalarının (rounded corners) uyumlu hale getirilmesi.

Zed'in başlık çubuğu yönetiminde ayrıca şu iki hususa dikkat edilmelidir:

- `OnboardingBanner` modülü, başlık çubuğunda yeni özellik tanıtımları sergilemek amacıyla hazır bir şablon sunar. Standart `TitleBar::new` yapılandırmasında `banner` alanı varsayılan olarak `None` şeklinde kurulur. Bu nedenle arayüze yeni bir banner yerleştirilmek istendiğinde, banner entity nesnesinin haricen oluşturulması, görünürlük koşullarının belirlenmesi ve ilişkili eylemlerinin (actions) açıkça atanması gerekir.
- Güncelleme sürecinde `UpdateButton::checking`, `downloading` ve `installing` durumları etkileşimsiz (pasif) butonlar olarak sunulur. Sürüm bilgisi ipucu metinleri `"Update to Version: ..."` şeklinde formatlanır ve SHA tabanlı sürümlerde kısa SHA formatı yerine tam SHA kodu görüntülenir.

## Kontrol Butonları Nasıl Yönetilir?

Pencere kontrol butonları her işletim sisteminde farklı görsel standartlara göre çizilir. Doğru bileşen mimarisi tercih edildiği sürece çizim detayları geliştirici için soyutlanmış olur:

- macOS: İşletim sisteminin yerel traffic light butonları devreye girer. Zed bu butonların iç boşluklarını ve `traffic_light_position` değerlerini bütünleşik olarak yönetir. Pencere açıldıktan sonra çalışma zamanında bu konumu değiştirmek için `Window::set_traffic_light_position(position: Point<Pixels>)` metodu çağrılabilir.
- Windows: `platform_title_bar::platforms::platform_windows::WindowsWindowControls` bileşeni butonların çizimini üstlenir ve her buton `WindowControlArea` vasıtasıyla platformun yerel çarpışma testi alanlarına bağlanır.
- Linux: `platform_title_bar::platforms::platform_linux::LinuxWindowControls` yapısı, `WindowButtonLayout` ve `WindowControls` verilerini baz alarak kapatma, küçültme ve ekranı kaplama butonlarının yerleşimini gerçekleştirir.

Sol ve sağ kontrol butonlarını hazır olarak çizmek amacıyla şu iki yardımcı fonksiyondan yararlanılır:

```rust
platform_title_bar::render_left_window_controls(
    cx.button_layout(),
    Box::new(workspace::CloseWindow),
    window,
)

platform_title_bar::render_right_window_controls(
    cx.button_layout(),
    Box::new(workspace::CloseWindow),
    window,
)
```

Pencere kapatma butonu doğrudan `window.remove_window()` metodunu tetiklemez. Bunun yerine kapatma eylemi (action) yönlendirilir:

```rust
window.dispatch_action(workspace::CloseWindow.boxed_clone(), cx);
```

Bu dolaylı yönlendirme sayesinde; kaydedilmemiş değişikliklerin (`dirty buffers`) denetlenmesi, kullanıcıya onay diyaloglarının gösterilmesi, çalışma alanının (workspace) kapatılma mantığı ve klavye kısayollarının aynı tutarlı akış üzerinden yürütülmesi sağlanır.

**Linux `WindowButtonLayout`.** Linux platformunda butonların dizilim düzeni oldukça esnektir ve kullanıcı tercihlerine göre özelleştirilebilir:

- `WindowButton::{Minimize, Maximize, Close}` yapıları sıralı kontrol tiplerini temsil eder. Buton düzeni, sol ve sağ kenarlar için `Option<WindowButton>` varyantlarını barındıran sabit boyutlu dizilerde tutulur. Her kenardaki maksimum buton sayısı platform düzeyinde `gpui::MAX_BUTTONS_PER_SIDE: usize = 3` sabitiyle sınırlandırılmıştır. `WindowButtonLayout::{left, right}` dizileri भी bu sınır doğrultusunda yapılandırılır.
- Aktif dizilim düzeni, platform katmanından `cx.button_layout()` çağrısı ile elde edilir.
- GNOME masaüstü standartlarında kullanılan `"close,minimize:maximize"` dizilim metinleri otomatik olarak ayrıştırılabilir.
- Linux için varsayılan yedek düzen `WindowButtonLayout::linux_default()` ile üretilir; bu düzen sağ kenarda sırasıyla küçültme, ekranı kaplama ve kapatma butonlarını barındırır.
- Kullanıcının `TitleBarSettings` dosyası üzerinden yaptığı özelleştirmeler, `TitleBar` bileşeni tarafından `PlatformTitleBar::set_button_layout` aracılığıyla sisteme aktarılır.

## İstemci Tarafı Süslemesi ve Yeniden Boyutlandırma

Zed'in istemci tarafı süsleme (CSD - client-side decoration) sarmalayıcı mantığı tek bir merkezi yardımcı fonksiyon üzerinde toplanmıştır:

```rust
workspace::client_side_decorations(oge, window, cx, doseme_kenar_yaricapi)
```

Bu sarmalayıcı yapı şu görevleri üstlenir:

- `window.window_decorations()` çağrısı ile işletim sisteminden dönen fiili süsleme kipini okur.
- İstemci tarafı süsleme devredeyse pencereye gölge payı kazandırmak için `window.set_client_inset(theme::CLIENT_SIDE_DECORATION_SHADOW)` çağrısını yapar.
- Sunucu tarafı süsleme (SSD) durumunda ise inset değerini `0` olarak belirler.
- `window.client_inset()` metodu, platform penceresine atanmış olan güncel inset değerini okumak için kullanılır; bu değerin iç boşluk (padding) ve gölge hesaplamalarıyla tutarlı tutulması gerekir.
- Döşenme (tiling) durumunun aktifliğine göre arayüz köşe yuvarlamalarını dinamik olarak devre dışı bırakır.
- Pencere sınırlarına kenarlık ve gölge efektleri ekler.
- Kenar ve köşe bölgelerinde fare imlecini otomatik olarak yeniden boyutlandırma (resize cursor) ikonuna dönüştürür.
- İlgili sınırlarda fareye tıklandığında `window.start_window_resize(edge)` çağrısını tetikleyerek platform düzeyinde boyutu günceller.

Köşe yuvarlama mantığı `theme::ClientDecorationsExt` uzantı trait'i üzerinden dışa da açıktır. `Styled` uygulayan herhangi bir öğeye `.rounded_client_corners(tiling)` zincirlenir; iki komşu kenarı da döşenmemiş olan her köşeye `theme::CLIENT_SIDE_DECORATION_ROUNDING` (10px) yarıçapı uygular, ekrana yapışık köşeleri köşeli bırakır. `client_side_decorations` sarmalayıcısı köşe yuvarlamasını içeride bu yardımcıyla hesaplar; kendi süsleme yüzeyini kuran bir bileşen de aynı tutarlı köşe davranışını doğrudan bu trait ile elde edebilir. Trait bütün `Styled` tipleri için genel olarak uygulandığından ayrıca elle implement edilmesi gerekmez.

Özel bir istemci tarafı süsleme modeli tasarlanırken şu temel prensipler izlenmelidir:

1. Platformun sunduğu fiili süsleme kipi `window.window_decorations()` üzerinden okunmalıdır.
2. İstemci kipi geçerliyse, gölge genişliği veya görünmez yeniden boyutlandırma alanı kadar `set_client_inset` değeri tanımlanmalıdır.
3. Ekrana yapışık döşenme (tiling) varsa, ilgili kenar ve köşelerden yuvarlama, iç boşluk ve gölge efektleri kaldırılmalıdır.
4. Yeniden boyutlandırma bölgeleri için sınır doğrultusunda `ResizeEdge` hesaplaması yapılmalıdır.
5. Sürükleme hareketi için başlık çubuğuna `WindowControlArea::Drag` alanı bağlanmalı ya da Linux ve macOS platformları için doğrudan `window.start_window_move()` metodu çağrılmalıdır.

macOS 27 hedefinde özel sürükleme davranışı uygulanıyorsa pencere açılışında `WindowOptions::is_movable = false` tanımlanmalıdır. Bu tercih, sistem başlık çubuğu mekanizması ile istemci tarafında çizilen drag alanının aynı tıklamayı paylaşmaya çalışmasını önler.

Linux tarafında sunucu düzeyinde pencere süslemesi her senaryoda garanti edilemez:

- Wayland protokolünde ekran kompozitörü (compositor) sunucu tarafı dekorasyon desteği sunmuyorsa, süsleme sorumluluğu otomatik olarak istemci tarafına (CSD) aktarılır.
- X11 sunucusunda aktif bir kompozitör bulunmadığında istemci tarafı süsleme talepleri doğrudan sunucu tarafına devredilebilir.

Bu nedenle, pencere oluşturulurken talep edilen başlangıç kipi yerine, her render karesinde güncel olarak sorgulanan fiili `window.window_decorations()` sonucu referans alınmalıdır.

## Platforma Göre Süsleme Davranışı

#### macOS

- `TitlebarOptions::appears_transparent = true` seçeneği, pencere stil maskesine yerel `NSFullSizeContentViewWindowMask` değerini ekler.
- `traffic_light_position` parametresi, yerel kapatma, küçültme ve yakınlaştırma (traffic light) butonlarının başlangıç konumunu belirler.
- `Window::set_traffic_light_position(position: Point<Pixels>)` çağrısı, aynı konumu çalışma zamanında dinamik olarak günceller. macOS platform kısıtlamalarına tabi olan bu metot, platform penceresinin durumunu güncelleyerek butonları hemen yeni koordinatlarına taşır.
- `titlebar_double_click()` metodu, yerel işletim sistemindeki çift tıklama eylemini uygular.
- `start_window_move()` işlevi, yerel Cocoa katmanındaki `performWindowDragWithEvent` çağrısını tetikler.
- `tabbing_identifier` tanımlandığında işletim sistemi düzeyinde yerel pencere sekmeleri etkinleştirilir.
- `WindowDecorations` yapılandırması macOS platformunda işlevsel bir etkiye sahip değildir; başlık çubuğu tasarımı ve davranışları doğrudan `TitlebarOptions` üzerinden yönetilir.

#### Windows

- `TitlebarOptions::appears_transparent` ayarı, özel veya pencere alanını tamamen kaplayan başlık çubuğu tasarımlarında tercih edilir.
- Kontrol butonlarının yerel çarpışma testi (hit testing) davranışları, `WindowControlArea` tanımları üzerinden Windows API düzeyindeki `HTCLOSE`, `HTMAXBUTTON`, `HTMINBUTTON`, `HTCAPTION` değerleriyle eşleştirilir.
- `WindowBackgroundAppearance::MicaBackdrop` ve `MicaAltBackdrop` değerleri, DWM (Desktop Window Manager) arka plan öznitelikleri aracılığıyla sisteme uygulanır.
- `WindowControls` çizimleri Zed tarafında Windows platformuna özgü bileşenler kullanılarak gerçekleştirilir.

#### Linux/FreeBSD - Wayland

- `WindowDecorations::Server` seçimi, `xdg-decoration` Wayland protokolü aracılığıyla talep edilir.
- Kompozitör sunucu tarafı süsleme desteği barındırmıyorsa, otomatik olarak istemci tarafı süslemeye (CSD) geçiş yapılır.
- `window_controls()` yetenekleri Wayland protokolünün sunduğu bilgi setinden okunur: Tam ekran, ekranı kaplama, simge durumuna küçültme ve pencere menüsü gibi yetenekleri içerir.
- `show_window_menu`, `start_window_move` ve `start_window_resize` gibi pencereler arası etkileşim eylemleri `xdg_toplevel` arabirimi üzerinden kompozitöre iletilir.
- Arka plan bulanıklaştırma için kompozitör `blur_manager` protokolünü destekliyorsa, `Blurred` tipindeki yüzeylere bulanıklık efekti uygulanabilir.

#### Linux/FreeBSD - X11

- `request_decorations` işlevi, X11 pencere yöneticisi özellikleri için `_MOTIF_WM_HINTS` mülkünü (property) günceller.
- İstemci tarafı dekorasyonların düzgün render edilmesi için aktif bir kompozitör gereklidir; kompozitör yoksa sunucu tarafı süsleme modeline geri dönülür.
- `show_window_menu` çağrısı, pencere yöneticisine `_GTK_SHOW_WINDOW_MENU` istemci mesajını (client message) iletir.
- Pencereyi taşıma veya yeniden boyutlandırma işlemleri `_NET_WM_MOVERESIZE` standart mesajıyla başlatılır.
- Pencerelerin kenarlara yapışma (tiling), tam ekran ve ekranı kaplama durumları `Decorations::Client { tiling }` sonucunu doğrudan şekillendirir.

#### Web/WASM

- Tarayıcı/Web ortamlarında işletim sistemi düzeyinde yerel pencere süslemesi kavramı bulunmamaktadır.
- `WindowBackgroundAppearance` yapılandırması tarayıcı pencerelerinde opak olarak kabul edilir veya herhangi bir işlem gerçekleştirilmez.
- Uygulama başlangıcında yerel web platformunun yapılandırılması için `gpui_platform::web_init()` çağrısı yürütülür.

## Bulanıklık, Şeffaflık ve Mica Yönetimi

Pencere arka planının görsel yapısı ve şeffaflık durumları `WindowBackgroundAppearance` enum varyantları ile tanımlanır:

```rust
pub enum WindowBackgroundAppearance {
    Opaque,
    Transparent,
    Blurred,
    MicaBackdrop,
    MicaAltBackdrop,
}
```

Zed'in tema ve ayar konfigürasyonu bu listenin tamamını değil, yalnızca belirli bir alt kümesini kullanıcıya açar. JSON sözleşmesinde alan adı `background.appearance` biçimindedir; Rust tarafındaki `window_background_appearance` adı serde katmanında dışarıya doğrudan taşınmaz:

```json
{
  "experimental.theme_overrides": {
    "background.appearance": "blurred"
  }
}
```

Tema adına göre geçersiz kılma yapılırken de aynı iç alan adı kullanılır:

```json
{
  "theme_overrides": {
    "One Dark": {
      "background.appearance": "transparent"
    }
  }
}
```

Kullanıcı ayarlarında ve tema JSON içeriğinde desteklenen değerler `opaque`, `transparent` ve `blurred` şeklindedir. Bu dış sözleşme `WindowBackgroundContent` enum'u üzerinden çözümlenir ve GPUI tarafındaki `WindowBackgroundAppearance::{Opaque, Transparent, Blurred}` değerlerine dönüştürülür. `MicaBackdrop` ve `MicaAltBackdrop` seçenekleri GPUI çekirdek kütüphanesi düzeyinde mevcut olsa da, Zed tema/settings JSON sözleşmesi bu değerleri parse etmez. Bu iki değer gerektiğinde yalnızca düşük seviye GPUI pencere yüzeyi üzerinden doğrudan iletilir.

Bu noktada iki katmanı ayırmak önemlidir:

- JSON/content katmanındaki `ThemeStyleContent::window_background_appearance` alanı `Option<WindowBackgroundContent>` tipindedir; tema veya ayar yazarı değer vermediğinde alan boş kalabilir.
- Runtime tema modelindeki `ThemeStyles::window_background_appearance` alanı ise `WindowBackgroundAppearance` tipindedir; refinement ve varsayılan tema çözümlemesi tamamlandıktan sonra uygulama kodu her zaman somut bir değer okur.
- `Theme::window_background_appearance()` metodu bu somut runtime değerini döndürür. Standart uygulama kodunda pencere arka planı için en güvenilir okuma noktası budur.

**Zed işlem akışı.** Temada yapılan değişiklikler o an açık bulunan tüm pencerelere anında yansıtılır:

- Tema yapılandırması çözümlenirken `WindowBackgroundContent` tipi uygun `WindowBackgroundAppearance` eşdeğerine dönüştürülür.
- Ana pencere başlatılırken pencere arka planı olarak `window_background: cx.theme().window_background_appearance()` ataması gerçekleştirilir.
- Ayarlar veya aktif tema güncellendiğinde, `zed` paketi tüm açık pencereler üzerinde sırasıyla `window.set_background_appearance(background_appearance)` metodunu çalıştırır.
- Arayüz bileşenlerinde yaygın olarak kullanılan `ui::theme_is_transparent(cx)` kontrolü; pencere şeffaf veya bulanık arka plana sahipse `true` değerini döndürür. Opak arka plan beklentisiyle tasarlanan bileşenlerin bu durumu gözetmesi önem taşır.

**API yüzeyi ve sorgulama sınırı.** Etkin tema tercihi `cx.theme().window_background_appearance()` ile okunur. Düşük seviyeli platform nesnesinde ayrıca `PlatformWindow::background_appearance()` ve `PlatformWindow::set_background_appearance(...)` metodları bulunur; bunlar platform implementasyonlarının sakladığı fiili değeri yönetir. Buna karşılık üst seviye `gpui::Window` yapısı public olarak `set_background_appearance(...)` metodunu sunar, ancak eşdeğer bir `window.background_appearance()` sorgu metodu açmaz. Bu nedenle normal render ve ayar akışlarında değer tema üzerinden okunur, pencereye ise `window.set_background_appearance(...)` ile uygulanır.

**Platform düzeyinde işleme.** Aynı enum değeri, her işletim sisteminin kendi kompozisyon yeteneklerine göre farklı bir mekanizmayla hayata geçirilir:

- macOS:
  - `Opaque` değeri pencereyi tamamen opak hale getirir.
  - `Transparent` ve `Blurred` modlarında çizim katmanının saydamlık özelliği etkinleştirilir.
  - macOS 12 ve üzeri sürümlerde `Blurred` ayarı seçildiğinde pencere hiyerarşisine `NSVisualEffectView` tabanlı yerel bulanıklık katmanı dinamik olarak dahil edilir. Bu katman `NSVisualEffectMaterial::Selection` ve `NSVisualEffectState::Active` ile kurulur; `CAChameleonLayer` arka plan tonu gizlenerek masaüstü renk tonlamasının bulanıklık üstüne binmesi engellenir.
  - macOS 12 altındaki sürümlerde `NSVisualEffectView` alt katman davranışı farklı olduğundan, `Blurred` için `CGSSetWindowBackgroundBlurRadius(..., 80)` çağrısı üzerinden WindowServer bulanıklığı kullanılır. `Opaque` ve `Transparent` değerlerinde bu yarıçap sıfırlanır.
- Windows:
  - `Opaque` seçeneğinde DWM kompozisyon öznitelikleri devre dışı bırakılır.
  - `Transparent` modunda pencere kompozisyon durumu şeffaf olarak etiketlenir.
  - `Blurred` tercih edildiğinde `set_window_composition_attribute` çağrısı aracılığıyla standart pencere bulanıklığı kompozisyon öznitelikleri devreye sokulur.
  - `MicaBackdrop` seçeneği Windows DWM düzeyindeki `DWMSBT_MAINWINDOW` efektini tetikler.
  - `MicaAltBackdrop` seçeneği ise sekmeli pencerelere özel `DWMSBT_TABBEDWINDOW` efektini uygular.
- Wayland:
  - Ekran kompozitörü `blur_manager` protokolünü destekliyorsa, `Blurred` türündeki pencereler için yüzeye bağlı bir blur nesnesi oluşturulur ve commit edilir.
  - Destek bulunmayan kompozitörlerde bulanıklık talebi görsel bir değişim oluşturmayabilir.
- X11:
  - `Opaque` dışındaki değerler çizim motorunun alfa kanalıyla şeffaflık yoluna girer.
  - X11 implementasyonu `Blurred` için yerel bir masaüstü arka planı bulanıklaştırması uygulamaz; sonuç pratikte kompozitörün sunduğu şeffaflık desteğiyle sınırlıdır.
- Web/WASM:
  - Tarayıcı platformunda `background_appearance()` her zaman `Opaque` döndürür; `set_background_appearance(...)` çağrısı etkisizdir.

**Element düzeyinde blur sınırı.** `WindowBackgroundAppearance::Blurred` ve Windows Mica değerleri pencere zeminini etkiler; tekil bir `div`, `Button`, sidebar veya panel için CSS'teki `backdrop-filter: blur(...)` benzeri ayrı bir element filtresi sağlamaz. GPUI `Style` yapısında element arka planı, border, köşe yarıçapı, `box_shadow`, metin stili ve opacity gibi alanlar bulunur; fakat elementin arkasındaki mevcut sahneyi örnekleyip bulanıklaştıran bir `filter` veya `backdrop_filter` alanı yer almaz.

Bu ayrım özellikle yarı saydam panellerde önemlidir. Bir tema `Blurred` pencere arka planını etkinleştirdiğinde işletim sistemi pencerenin arkasındaki masaüstü veya diğer pencere içeriklerini bulanıklaştırır. Sidebar, buton veya panel üzerinde `transparent_black()`, alfa kanalı düşük `Hsla` renkleri veya `opacity(...)` kullanıldığında görünen etki, o elementin kendi blur işlemi değildir; elementin yarı saydam yüzeyinden pencerenin en altındaki platform bulanıklığının görünmesidir. Aynı element opak bir `background` çizdiğinde bu platform etkisi kapanır.

macOS implementasyonunda `NSVisualEffectView` katmanı `content_view` altına `NSWindowOrderingMode::NSWindowBelow` ile eklenir; Windows ve Wayland tarafında da karar pencere/yüzey düzeyindedir. Bu nedenle bir sidebar'ın arkasında kalan editör metnini ya da bir butonun altındaki komşu UI katmanını yerel `WindowBackgroundAppearance::Blurred` ile bulanıklaştırmak mümkün değildir. Böyle bir görünüm gerektiğinde tasarımın yarı saydam renk, gölge, overlay ve opak yedek yüzey kombinasyonlarıyla kurulması gerekir; gerçek backdrop blur semantiği GPUI element stil API'sinde bulunmaz.

**Pratik kullanım kılavuzu.** Karar verme süreçlerinde hangi seçeneğin nerede tercih edilmesi gerektiği şu şekilde özetlenebilir:

- Standart tema ve ana pencere tasarımlarında: `cx.theme().window_background_appearance()` dinamik değeri temel alınmalıdır.
- Geçici üst katman panelleri (overlays) ve anlık bildirim pencerelerinde: `Transparent` seçeneği kullanılmalıdır.
- Windows 11 platformuna özel Mica efektlerinden yararlanılmak istendiğinde: Doğrudan `WindowBackgroundAppearance::MicaBackdrop` veya `MicaAltBackdrop` varyantları iletilmelidir; ancak bu seçimin Zed tema ayarlarına doğrudan bağlı olmadığı göz önünde bulundurulmalıdır.
- Bulanıklık efekti tercih edildiğinde, arayüz bileşenlerinin kök katmanlarında alfa kanalı (saydamlık) bırakılmalıdır; zira tamamen opak çizilen bir kök arka plan, arkadaki bulanıklık efektinin görünmesini engeller.

## Pencere Üzerinden Yapılan İşlemler

Pencerenin durumunu ve görsel sunumunu yönetmek amacıyla kullanılan `Window` API'leri, işlevsel amaçlarına göre gruplandırıldığında doğru metodun seçilmesi kolaylaşır. Her bir metot grubu, ilgili platform düzeyindeki sistem çağrılarına açılan güvenli birer kapıdır:

- **Sınır ve İçerik Ölçüleri:** `window.bounds()` aktif ekran koordinatlarını, `window.window_bounds()` pencerenin geri yüklenebilir `WindowBounds` değerini, `window.inner_window_bounds()` ise istemci inset (iç boşluk) payları hesaba katılmış iç sınırları sağlar. `window.viewport_size()` metodu ise çizilebilir güncel içerik boyutunu döndürür. `window.resize(size)` içerik boyutlarını günceller. Kalıcı pencere koordinatlarının saklanması süreçlerinde hangi sınır verisinden yararlanılacağını bu ayrım belirler.
- **Pencere Durumu ve Yaşam Döngüsü:** `window.is_fullscreen()` ve `window.is_maximized()` metotları pencerenin o anki ekran durumunu sorgular. `window.activate_window()`, `window.minimize_window()`, `window.zoom_window()` ve `window.toggle_fullscreen()` işlevleri kullanıcıya sunulan pencere durumunu işletim sistemi üzerinden değiştirir. `window.remove_window()` ise pencereyi çalışma zamanından tamamen kaldırır. Örneğin Zed, çalışma alanının (workspace) kapatılması gibi doğrulama gerektiren süreçlerde doğrudan bu kaldırma çağrısı yerine kapatma eylemini (action) tetiklemeyi tercih eder.
- **Başlık, Kimlik ve Arka Plan:** `window.set_window_title(title)`, `window.set_app_id(app_id)` ve `window.set_background_appearance(appearance)` metotları platform penceresinin kimlik niteliklerini ve arka plan kompozisyonlarını günceller. macOS platformunda belge düzenleme göstergeleri gerekiyorsa, `window.set_window_edited(true/false)` ile düzenleme durumu, `window.set_document_path(path)` ile ise belgenin dosya sistemi yolu sisteme bildirilebilir.
- **Süsleme ve Hareket:** `window.show_window_menu(position)` çağrısı Linux masaüstünde başlık çubuğu bağlam menüsünü tetikler. `window.start_window_move()` ve `window.start_window_resize(edge)` metotları, özel istemci dekorasyonları tasarlanırken pencerenin taşınması ve yeniden boyutlandırılması akışlarını başlatır. `window.request_decorations(...)` istenen dekorasyon kipini iletirken, `window.window_decorations()` fiili sonucu okur; `window.window_controls()` ise platformun sunduğu buton yeteneklerini listeler.
- **Kullanıcı Bildirimleri ve Sistem Uyarıları:** `window.prompt(...)` pencereye kenetlenmiş yerel veya özel onay pencerelerini başlatır. `window.play_system_bell()` platformun varsayılan sistem uyarı sesini (beep) tetikler; iş mantığı hatalarında büyük diyalog pencereleri açmak yerine hızlı bir kullanıcı geri bildirimi sağlamak amacıyla tercih edilir.

macOS yerel pencere sekmelerine yönelik ek API ailesi, işletim sistemi düzeyindeki sekme gruplarını yönetir:

- `window.set_tabbing_identifier(...)` metodu, aynı tanımlayıcıya sahip üst düzey pencereleri otomatik olarak yerel bir sekme grubunda toplar.
- `window.tabbed_windows()` fonksiyonu sekmeli pencerelerin grup bilgilerini `Option<Vec<SystemWindowTab>>` formatında sorgular.
- `window.tab_bar_visible()` yerel sekme barının aktif görünürlük durumunu bildirir.
- `window.merge_all_windows()`, `window.move_tab_to_new_window()` ve `window.toggle_window_tab_overview()` metotları ise işletim sisteminin yerel pencere sekmelerini yöneten kullanıcı komutlarının GPUI sarmalayıcılarıdır.

## Window Çalışma Zamanı API Aileleri

`Window` yapısı yalnızca pencere boyutlarını yöneten sade bir arayüz olmanın ötesinde; render çizim aşamaları, odak ağacı (focus tree), eylem yönlendirmeleri (action dispatching), element durum verileri (element state), platform tanıları ve FFI sınırlarına açılan kapsamlı bir çalışma zamanı kontrol merkezidir. Bu geniş API yüzeyini gruplar halinde ele almak anlaşılırlığı artırır:

**Kök Görünüm ve Pencere Handle Yönetimi:** `window.window_handle()` çağrısı tipsiz `AnyWindowHandle` referansı döndürür. Tipli bir kök görünümle çalışırken ise `WindowHandle<V>` yapısı tercih edilir. `WindowHandle::root(cx)`, `entity(cx)`, `read(cx)`, `read_with(cx, ...)`, `update(cx, ...)` ve `is_active(cx)` metotları, pencereye bağlı kök entity verilerini güvenli bir şekilde okumak veya güncellemek için kullanılır. Kök görünümün türünün bilinmediği dinamik senaryolarda `AnyWindowHandle::window_id()`, `downcast::<T>()`, `update(cx, ...)` ve `read(cx, ...)` arayüzlerinden yararlanılır. Bu handle referansları uzun süreli saklandığında ilgili pencerenin kapatılmış olma ihtimali bulunduğundan, dönüş değerleri her zaman hata kontrolü (`Result`) eşliğinde işlenmelidir.

**Asenkron Pencere Bağlamı:** `window.to_async(cx)` veya `Context::spawn_in(...)` çağrıları, yürütme akışını `AsyncWindowContext` bağlamına taşır. `AsyncWindowContext::window_handle()` bağlı olunan aktif pencereyi verir. Buradaki `update(...)` metodu pencere ve `App` verileri üzerinde işlem yaparken; `update_root(...)` doğrudan kök görünüme erişim sağlar. `on_next_frame(...)` ertelenen işlemleri bir sonraki ekran karesine devreder. `read_global(...)` ve `update_global(...)` işlevleri global uygulama verilerini yönetir. `spawn(...)` ise pencere ömrüne bağlı yeni asenkron görevler başlatır. `prompt(...)` çağrısı, pencerenin kapanmış olma ihtimalini `Result` ve kanallar aracılığıyla asenkron süreçte yönetilebilir kılar. Pencere ömründen bağımsız genel asenkron süreçler için `AsyncApp`, pencereye özel durum güncellemeleri veya onay kutuları (prompts) gerektiğinde ise `AsyncWindowContext` tercih edilmelidir.

**Kök Değiştirme ve Ekran Karesi Yaşam Döngüsü:** `replace_root(...)`, `root::<E>()`, `refresh()`, `remove_window()`, `draw(cx)`, `bounds_changed(cx)`, `request_animation_frame()` metotları ile test ortamlarında kullanılan `render_to_image()` işlevi pencerenin çizim döngüsünü doğrudan yönlendirir. Uygulama görünümleri genellikle `cx.notify()` ile kendi güncellemelerini ister; ancak tüm pencereyi yenilemek veya özel test çıktıları almak gerektiğinde `window.refresh()` ve `draw(...)` seviyesine inilir. `ArenaClearNeeded` yapısı, çizim arenasının hangi ekran karesinde temizleneceğini denetleyen dahili bir yardımcı araçtır; doğrudan bileşen durum verisi olarak kullanılmamalıdır.

**Odaklanma ve Tab Gezinmesi:** `focused(cx)`, `focus(handle, cx)`, `blur()`, `disable_focus()`, `focus_next(cx)` ve `focus_prev(cx)` metotları pencere odak ağacını yapılandırır. `FocusHandle::tab_index(...)`, `tab_stop(...)`, `downgrade()`, `focus(...)`, `is_focused(...)`, `contains_focused(...)`, `within_focused(...)`, `contains(...)` ve `dispatch_action(...)` işlevleri odaklanabilir bileşenlerin arayüz kontrolleridir. `WeakFocusHandle::upgrade()` metodu, odak handle referansını uzun ömürlü yapılarda zayıf referans olarak tutmak amacıyla kullanılır. `FocusId` ise bu sorguların arka plandaki düşük seviyeli kimlik karşılığıdır; uygulama kodlarında genellikle doğrudan `FocusHandle` kullanımı tercih edilir.

**Girdi, Hitbox ve İmleç Kontrolü:** `mouse_position()`, `modifiers()`, `capslock()`, `last_input_was_keyboard()`, `capture_pointer(hitbox_id)`, `release_pointer()`, `captured_hitbox()`, `insert_hitbox(...)`, `set_cursor_style(...)`, `set_window_cursor_style(...)`, `request_autoscroll(...)` ve `take_autoscroll()` metotları kullanıcı etkileşim altyapısını oluşturur. `HitboxId::is_hovered(...)` ve `should_handle_scroll(...)` metotları, tipli `Hitbox` referansı üzerinden benzer kontroller sunar. Kaydırma (scroll) sırasında klavye girdilerinin durumunu da hesaba kattığı için, bu kontroller standart imleç konum denetimlerine göre daha kararlı sonuçlar verir. `TooltipId::is_hovered(...)` ise imlecin aktif bir ipucu kutusu (tooltip) üzerinde olup olmadığını denetler.

**Element Kimliği ve Durum Yönetimi (Element State):** `with_global_id(...)`, `with_id(...)`, `with_element_namespace(...)`, `use_keyed_state(...)`, `use_state(...)`, `with_element_state(...)` ve `with_optional_element_state(...)` metotları ekran kareleri arasında element başına veri korunmasını (state persistence) sağlar. Dinamik olarak tekrar eden liste satırları gibi yapılarda `ElementId::named_usize(name, index)` gibi benzersiz ve tutarlı kimlikler üretilir. Aynı global kimlik ve tip için iç içe state istekleri `panic` hatasına yol açabileceğinden, durum yaşam döngüleri element ağacının benzersiz kimlik hiyerarşisine sadık kalınarak tasarlanmalıdır.

**Çizim Bağlamı ve Ölçüm Ölçütleri:** `text_system()`, `text_style()`, `with_text_style(...)`, `rem_size()`, `set_rem_size(...)`, `with_rem_size(...)`, `line_height()`, `scale_factor()`, `pixel_snap(...)`, `pixel_snap_point(...)`, `pixel_snap_bounds(...)`, `with_content_mask(...)`, `content_mask()`, `with_element_offset(...)`, `with_absolute_element_offset(...)`, `element_offset()`, `transact(...)`, `request_layout(...)`, `request_measured_layout(...)`, `compute_layout(...)` ve `layout_bounds(...)` metotları özel element tasarımları implemente edilirken devreye girer. Standart `div()` veya Zed UI bileşenleri kullanılırken bu düşük seviyeli detaylara inilmez; ancak özel bir `Element` yazılırken hangi render fazında (layout, paint vb.) bulunulduğuna dikkat edilmelidir.

**Paint Primitifleri (Çizim Öğeleri):** `paint_layer(...)`, `paint_drop_shadows(...)`, `paint_inset_shadows(...)`, `paint_quad(...)`, `paint_path(...)`, `paint_underline(...)`, `paint_strikethrough(...)`, `paint_glyph(...)`, `paint_emoji(...)`, `paint_svg(...)`, `paint_image(...)`, `paint_surface(...)` ve `drop_image(...)` çağrıları yalnızca paint (boyama) fazı esnasında yürütülür. `fill(bounds, background)`, `quad(...)`, `outline(...)` ile `PaintQuad::corner_radii(...)`, `border_widths(...)`, `border_color(...)`, `background(...)` yardımcı metotları bu çizim çağrılarını besleyen verileri hazırlar. Günlük arayüz tasarımlarında ise fluent tarzı `.bg(...)`, `.border(...)`, `img(...)` veya `svg()` gibi yüksek seviyeli element metotlarının tercih edilmesi önerilir.

| Düşük Seviye Arayüz | Alt Nitelikler | Temel Açıklaması |
| :-- | :-- | :-- |
| `HitboxId` | Benzersiz ham kimlik | Test ortamlarında veya platform düzeyinde hitbox bölgelerini ayırt etmeyi sağlayan kimliktir. |
| `TooltipId` | `is_hovered` kontrolü | `window.set_tooltip(...)` çağrısı ile kaydedilen tooltip isteklerini benzersiz olarak tanımlar. |
| `outline` | Sınırlar, renk, çizgi stili | Debug işlemlerinde veya özel çizimlerde quad dış çizgileri üretmek için kullanılan pencere yardımcısıdır. |

**Action ve Keymap Sorguları:** `dispatch_action(...)`, `dispatch_keystroke(...)`, `dispatch_event(...)`, `prevent_default()`, `default_prevented()`, `context_stack()`, `available_actions(cx)`, `is_action_available(...)`, `is_action_available_in(...)`, `bindings_for_action(...)`, `highest_precedence_binding_for_action(...)`, `bindings_for_action_in_context(...)`, `bindings_for_action_in(...)`, `possible_bindings_for_input(...)`, `keystroke_text_for(...)`, `has_pending_keystrokes()` ve `pending_input_keystrokes()` metotları; komut paletleri, menü etkileşimleri ve kısayol göstergeleri oluşturulurken kullanılır. Belirli bir eylemi çalıştırmak için sadece `dispatch_action` çağrısı yeterliyken; kullanıcılara gösterilecek doğru kısayol metinlerini hesaplarken pencere bağlam yığınını (context stack) dikkate alan detaylı sorgulardan yararlanılmalıdır.

**Prompt, Platform ve Tanı Yardımcıları:** `prompt(...)`, `show_character_palette()`, `display(cx)`, `gpu_specs()`, `input_latency_snapshot()`, `play_system_bell()`, `window_title()`, `set_window_title(...)`, `set_window_edited(...)`, `set_document_path(...)`, `set_app_id(...)`, `set_background_appearance(...)`, `appearance()`, `is_window_active()` ve `is_window_hovered()` metotları yerel platform entegrasyonu sağlar. Her işletim sisteminin bu çağrılara aynı yanıtı vermeyebileceği (örneğin GPU özellikleri sorgulamasının veya karakter paleti açılmasının bazı platformlarda boş veya etkisiz dönebileceği) göz önünde bulundurulmalıdır.

**Ekran Karesi Düşük Seviye Kancaları (Hooks):** `set_key_context(...)`, `set_focus_handle(...)`, `set_view_id(...)`, `insert_window_control_hitbox(...)`, `handle_input(...)`, `on_mouse_event(...)`, `on_key_event(...)`, `on_modifiers_changed(...)`, `on_focus_in(...)`, `on_focus_out(...)`, `listener_for(...)`, `handler_for(...)`, `on_action(...)` ve `on_action_when(...)` metotları, yeni element sınıfları veya framework çekirdeği yazarken kullanılır. Standart uygulama görünümlerinde bu kancaların yerini fluent arayüze sahip `.key_context(...)`, `.track_focus(...)`, `.on_click(...)`, `.on_key_down(...)` veya `.on_action(...)` gibi element metotları alır.

**WindowInvalidator ve InputRateTracker:** `WindowInvalidator::invalidate_view(...)`, `is_dirty()`, `set_dirty(...)`, `set_phase(...)`, `update_count()`, `take_views()`, `replace_views(...)`, `not_drawing()`, `debug_assert_paint()`, `debug_assert_prepaint()` ve `debug_assert_paint_or_prepaint()` gibi yardımcı yapılar, çizim boru hattının kendi tutarlılığını ve bütünlüğünü denetler. `InputRateTracker::record_input()` ve `is_high_rate()` metotları ise sisteme yüksek frekansta girdi akışı (input event stream) geldiğinde platformun ekran tazeleme optimizasyonları yapmasına imkan tanır. Bu tipler uygulama durum verilerini yönetmek için tasarlanmamıştır; yalnızca pencere çalışma zamanının arka plandaki kararlarını modellemek amacıyla kullanılır.

## Pencere Sınırlarının Saklanması ve Geri Yüklenmesi

Pencerelerin ekrandaki konum ve boyut bilgileri, Zed tarafında `workspace` ve `zed` paketleri kullanılarak kalıcı olarak saklanır (disk üzerinde serialize edilir).

`WindowBounds` enum yapısı, pencerenin üç ana yerleşim durumunu temsil eder:

```rust
pub enum WindowBounds {
    Windowed(Bounds<Pixels>),
    Maximized(Bounds<Pixels>),
    Fullscreen(Bounds<Pixels>),
}
```

Buradaki `Bounds` yapısı, her üç senaryoda da pencerenin geri yüklenebilmesi için gerekli olan koordinat verilerini taşır. `Maximized` ve `Fullscreen` varyantlarının içerdiği sınır değerleri; bu özel modlar kapatıldığında (pencere eski normal haline getirildiğinde) geri dönülecek olan pencereli (`Windowed`) mod boyutlarını temsil eder.

**Saklama Süreci (Serialization):** Pencere konum ve boyut verileri kalıcı hale getirilirken izlenen tipik yöntem şu şekildedir:

```rust
let sinirlar = window.inner_window_bounds();
serilestir(sinirlar, ekran_uuid);
```

Zed varsayılan pencere boyutunu kaydederken `inner_window_bounds()` metodunu kullanır. Çalışma alanının (workspace) serileştirildiği bazı senaryolarda ise `window.window_bounds()` metodunun tercih edildiği de görülür. Bu iki metot arasındaki temel fark, dahil edilen platform pencere süslemelerinin veya başlık çubuğu geometrilerinin alan hesaplamalarına katılma biçimidir. Ekran UUID verisi ise pencere sınırlarından bağımsız olarak haricen saklanır. Bu ayrım, kullanıcıların sistemden monitör ayırması durumunda pencerenin kaybolmasını önlemek amacıyla tasarlanmıştır.

**Geri Yükleme Süreci (Deserialization):** Çalışma alanı (workspace) yeniden açılırken `zed::build_window_options` fonksiyonu çerçevesinde şu adımlar izlenir:

1. Diskten okunan saklı `display_uuid` bilgisi, `cx.displays()` listesindeki ekranların `display.uuid()` değerleriyle karşılaştırılarak eşleştirilir.
2. Eşleşen ekran tespit edilirse `options.display_id` değeri atanır ve kayıtlı `WindowBounds` verisi `options.window_bounds` alanına yerleştirilir.
3. Çalışma alanına özel herhangi bir sınır kaydı bulunmuyorsa, uygulamanın genel varsayılan pencere boyutları okunur.
4. Sistemde hiçbir kayıt bulunmadığı takdirde `WindowOptions.window_bounds` alanı `None` olarak bırakılır ve GPUI, işletim sisteminin varsayılan kademeli yerleşim kurallarını devreye sokar.

Pencere boyutlarının değişmesini dinamik olarak izlemek için şu şekilde bir abonelik kurulabilir:

```rust
cx.observe_window_bounds(window, |gorunum, window, _cx| {
    let sinirlar = window.inner_window_bounds();
    gorunum.sinirlari_kaydet(sinirlar);
}).detach();
```

Benzer şekilde, açık veya koyu tema değişikliklerini izlemek için `cx.observe_window_appearance(window, ...)`, pencerenin ön plana veya arka plana geçişini takip etmek için ise `cx.observe_window_activation(window, ...)` abonelikleri kullanılır.

**Dikkat edilmesi gereken hususlar.** Pencere sınırları yönetilirken karşılaşılan yaygın karmaşalar şunlardır:

- `window.bounds()` (aktif ekran koordinatları), `window.window_bounds()` ve `window.inner_window_bounds()` değerleri birbirinden farklı geometrileri temsil edebilir. Saklama ve geri yükleme süreçlerinde hangi dikdörtgen verisinin beklendiği, ilgili Zed çağırma noktasına göre dikkatlice seçilmelidir.
- Ekranı kaplama (maximize) ve tam ekran (fullscreen) durumlarında enum içindeki `Bounds<Pixels>` değeri, pencerenin pencereli moda geri döndüğünde alacağı boyutları saklar; dolayısıyla platform penceresi o an tüm ekranı kaplasa bile kayıt altındaki geri yükleme boyutları korunur.
- Linux Wayland üzerinde bazı ekran kompozitörleri ekran UUID bilgisi döndürmeyebilir. Bu durumda `display.uuid().ok()` çağrısı `None` döneceğinden, güvenli bir yedek (fallback) ekran eşleme mantığının kurgulanması gerekir.

## Yerel Pencere Sekmeleri ve SystemWindowTabController

macOS yerel pencere sekmeleri (window tabs), GPUI kapsamında iki katmanlı bir kontrol yapısı üzerinde yükselir:

- `WindowOptions::tabbing_identifier`: Aynı kimlik metnine sahip pencerelerin işletim sistemi düzeyinde tek bir yerel sekme grubunda birleştirilmesini sağlar.
- `SystemWindowTabController`: Bir GPUI `Global` durumu olarak yerel sekme gruplarını ve bunların görünürlük durumlarını izler.

İlişkili `Window` API metotları şunlardır:

- `window.tabbed_windows() -> Option<Vec<SystemWindowTab>>`
- `window.tab_bar_visible() -> bool`
- `window.merge_all_windows()`
- `window.move_tab_to_new_window()`
- `window.toggle_window_tab_overview()`
- `window.set_tabbing_identifier(Some(identifier))`

**Tasarım kararları.** İşletim sisteminin sunduğu yerel sekmeler ile uygulama içi sekme yapıları tamamen farklı kavramlardır:

- Zed'in dosya sekmeleri ve panel sistemleri için yerel sekmeler yerine, doğrudan uygulama düzeyindeki `workspace::Pane` ve `TabBar` bileşenleri kullanılır.
- İşletim sistemi düzeyinde birden fazla bağımsız pencerenin aynı yerel sekme grubu altında toplanması istendiğinde `tabbing_identifier` alanına değer iletilmelidir.
- Sekme verileri doğrudan işletim sisteminden alınır. Dolayısıyla Linux ve Windows platformlarında bu API metotlarının bir kısmı no-op (etkisiz) kalabilir veya `None` döndürebilir.

**`SystemWindowTabController` arayüzü.** Bu denetleyici bir `Global` durum nesnesi olarak saklanır ve platform katmanından gelen yerel sekme gruplarını GPUI içinde izler:

- `SystemWindowTabController::init(cx)` ilk kurulumu gerçekleştirir.
- `init_visible(cx, visible)`, `is_visible()` ve `set_visible(cx, visible)` metotları yerel sekme barının görünürlüğünü denetler.
- `tab_groups()` ve `tabs(window_id)` işlevleri ham grup ve sekme listelerini okur.
- `add_tab(cx, id, tabs)`, `remove_tab(cx, id)`, `update_tab_position(cx, id, ix)`, `update_tab_title(cx, id, title)` ve `update_last_active(cx, id)` metotları, işletim sisteminden gelen güncellemeleri GPUI state'ine işler.
- `get_next_tab_group_window(cx, id)`, `get_prev_tab_group_window(cx, id)`, `select_next_tab(cx, id)`, `select_previous_tab(cx, id)`, `move_tab_to_new_window(cx, id)` ve `merge_all_windows(cx, id)` metotları ise yerel sekme yönlendirme komutlarını çalıştırır.

Uygulama içi dosya/pane sekmelerini bu denetleyici yapısıyla modellemekten kaçınılmalıdır; bu arayüz yalnızca işletim sistemi pencerelerini gruplamak üzere tasarlanmıştır.

**Dikkat edilmesi gereken hususlar.** Yerel sekmeler yapılandırılırken şu kurallar göz önünde bulundurulmalıdır:

- Yerel pencere sekmeleri ile Zed'in kendi arayüz sekmeleri farklı yaşam döngülerine sahiptir; kalıcılık modelleri ve komut yönlendirme mekanizmaları ayrışır.
- Pencere başlığı güncellendiğinde, yerel sekme başlığının da güncellenmesi için `window.set_window_title(...)` çağrısıyla birlikte sekme denetleyicisinin de eş zamanlı güncellenmesi gerektiği unutulmamalıdır.

## Layer Shell ve Özel Platform Pencereleri

Standart Zed pencereleri `WindowKind::Normal` seçeneğiyle açılır. Ancak Linux Wayland desteği etkinleştirildiğinde `WindowKind::LayerShell(LayerShellOptions)` yapısı; ekran kenarlarına kenetlenen paneller, rıhtımlar (docks) veya masaüstü widget'ları benzeri özel yüzeyler oluşturmak amacıyla kullanılabilir:

```rust
use gpui::layer_shell::*;

WindowOptions {
    titlebar: None,
    window_background: WindowBackgroundAppearance::Transparent,
    kind: WindowKind::LayerShell(LayerShellOptions {
        namespace: "gpui".to_string(),
        layer: Layer::Overlay,
        anchor: Anchor::LEFT | Anchor::RIGHT | Anchor::BOTTOM,
        margin: Some((px(0.), px(0.), px(40.), px(0.))),
        keyboard_interactivity: KeyboardInteractivity::None,
        ..Default::default()
    }),
    ..Default::default()
}
```

Layer Shell yapılandırma ayarları, Wayland kompozitörüne ilgili yüzeyin konumlandırılma ve etkileşim kurallarını bildirir:

- `Layer`: Yüzeyin dikey katman sırasını belirler; `Background`, `Bottom`, `Top`, `Overlay` varyantlarını içerir.
- `layer_shell::Anchor`: Yüzeyin hangi kenarlara yaslanacağını belirten bit bayrağıdır; `TOP`, `BOTTOM`, `LEFT`, `RIGHT` değerleri mantıksal VEYA ile birleştirilebilir.
- `exclusive_zone`: Kompozitörün, diğer pencerelerin bu yüzey alanının üzerine binmesini engellemesi amacıyla istenir.
- `exclusive_edge`: Özel alanın (exclusive zone) hangi kenar doğrultusunda geçerli olacağını belirtir.
- `margin`: Yüzeyin kenar boşluklarını sırasıyla üst, sağ, alt ve sol şeklinde tanımlar.
- `KeyboardInteractivity`: Klavyeden girdi alma politikasını yönetir; `None`, `Exclusive`, `OnDemand` seçeneklerini sunar.

Bu API ailesi yalnızca `#[cfg(all(target_os = "linux", feature = "wayland"))]` platform koşulu altında derlenebilir. Ekran kompozitörü bu protokolü desteklemediği takdirde arka uç sistemi `LayerShellNotSupportedError` hatasını döndürür. Bu gibi durumlarda, uygulamanın normal bir pencere (`WindowKind::Normal`) üzerinden çalışmaya devam etmesini sağlayacak bir yedek (fallback) senaryonun tasarlanması önerilir.
