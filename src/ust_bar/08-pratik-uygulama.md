# Pratik uygulama

Önceki bölümlerde anlatılan parçalar bir araya geldiğinde geriye
günlük geliştirme sırasında en sık başvurulan üç şey kalır:
değişikliğe konu olan noktaların listesi, platform bazlı kontrol
listeleri ve daha önce başkalarının yakalandığı sık hatalar. Bu
bölüm, bu üç başlığı pratik bir başvuru olarak en sona yakın bir
yere toplar.

## 18. Özelleştirme noktaları

Aşağıdaki tablo, üst barda en sık değiştirilen davranışların hangi
dosya veya alanda ele alındığını gösterir. Yeni bir özelleştirme
ihtiyacı doğduğunda önce buradan başlanır; tabloda yer alan giriş
ilgili kodun kapısını verir.

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Close butonu farklı bir action dispatch etmeli | `PlatformTitleBar` içine `close_action` alanı eklenir veya doğrudan serbest render fonksiyonları kullanılır. |
| Linux buton sırası ayardan gelmeli | `set_button_layout(...)` çağrısı uygulamanın settings state'ine bağlanır; ayar değiştikçe yeniden render tetiklenir. |
| Linux butonlarının ikonu/rengi değişmeli | `WindowControlStyle` veya `WindowControlType::icon()` port karşılığında değişiklik yapılır. |
| Windows close hover rengi farklı olmalı | `platform_windows.rs` içindeki `WindowsCaptionButton::Close` (crate-içi enum) renkleri değiştirilir. Tip public değildir; port hedefinde aynı dört variant kendi enum'la yeniden yazılır. |
| Titlebar yüksekliği değişmeli | `platform_title_bar_height` karşılığı port edilir ve tüm titlebar/controls kullanımlarında aynı değer kullanılır. |
| Native tabs kapatılmalı | `SystemWindowTabs` render child'ı feature flag ile boş döndürülür; controller kaldırılmaz, böylece geri açmak kolaydır. |
| Sekme plus butonu yeni pencere açmalı | `zed_actions::OpenRecent` yerine uygulamanın kendi `NewWindow` action'ı dispatch edilir. |
| Sidebar açıkken kontroller gizlenmemeli | `sidebar_render_state` ve `show_left/right_controls` koşulları değiştirilir. |
| Sağ tık window menu kapatılmalı | Linux CSD'deki `window.show_window_menu(ev.position)` bağı kaldırılır veya bir ayara bağlanır. |
| Çift tıklama maximize yerine farklı bir action olmalı | Platform click handler'ları ürünün kendi action'ına yönlendirilir; macOS sistem davranışına bilinçli olarak müdahale edildiği unutulmaz. |

## 19. Kontrol listesi

Aşağıdaki listeler, üst bar entegrasyonu tamamlandıktan sonra hızlıca
gözden geçirilmesi gereken maddeleri toplar. Listeyi pratik bir
"kaçırdığım bir şey var mı?" denetimi olarak kullanmak amaçlanır;
her madde kabaca bir kod parçasına veya teste karşılık gelir.

### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında **bir kez**
  çağrılıyor mu kontrol edilir. İki kez çağrılması, observer'ların
  duplike çalışmasına yol açar.
- Pencerenin `WindowOptions.titlebar` alanı transparent titlebar
  değeriyle açılıyor mu doğrulanır.
- Linux CSD ihtiyacı varsa `WindowDecorations::Client` isteniyor mu
  bakılır.
- CSD kullanılıyorsa pencere gölgesi, kenarlığı ve resize davranışı
  için ayrı bir sarmal uygulanıyor mu kontrol edilir. Bu sarmal
  olmadan titlebar yine de render olur, ama pencere kenarı native
  hissetmez.
- Titlebar child'ları her render geçişinde `set_children(...)` ile
  yenileniyor mu doğrulanır.
- Titlebar üzerindeki interaktif child'lar drag propagation'ı ile
  çakışıyor mu test edilir; bir buton tıklamasının pencereyi
  sürüklemediğinden emin olunur.
- Tema token'ları aktif, pasif ve hover durumlarının hepsini
  kapsıyor mu kontrol edilir; eksik bir token render'da bariz
  görsel boşluklar bırakır.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı yoluyla
  `WindowButtonLayout` geliyor mu kontrol edilir.
- Sol ve sağ buton dizilerinin boş slotlarının doğru davrandığı test
  edilir (ilk slot boş ise tarafın tamamen gizlendiği unutulmaz).
- Desktop layout değişiminde titlebar otomatik olarak yeniden render
  olup olmadığı doğrulanır.
- `window.window_controls()` capability sonucu, minimize ve maximize
  desteğini doğru filtreliyor mu sınanır.
- Sağ tık ile açılan sistem pencere menüsü, ürünün istediği davranışla
  uyumlu mu kontrol edilir; bazı uygulamalar bu menüyü tamamen
  kapatmayı tercih edebilir.

### Windows

- Caption button alanlarının `WindowControlArea::{Min, Max, Close}`
  olarak kaldığı doğrulanır; aksi halde Windows native caption
  davranışı bozulur.
- Sağ taraftaki ürün butonlarının caption button hitbox'ları ile
  çakışmadığı test edilir.
- `platform_title_bar_height` değerinin Windows için `32px` varsayımını
  koruduğu veya bilinçli olarak değiştirildiği netleştirilir.
- Close butonunun hover rengi (Microsoft'un kırmızısı), tema
  politikasıyla uyumlu mu kontrol edilir.

### macOS

- Trafik ışıkları için sol padding korunuyor mu doğrulanır.
- `traffic_light_position` ile titlebar child'larının çakışmadığı
  test edilir.
- Fullscreen ve native tabs davranışının ayrı senaryolarda doğru
  çalıştığı kontrol edilir; iki özelliğin birlikte etkinleştiği
  durumlar gözden kaçırılır.
- Çift tıklamanın sistem davranışına mı yoksa ürünün özel
  davranışına mı yönlendirileceği bilinçli olarak karara bağlanır.

### Native tabs

- `tabbing_identifier` değerinin aynı tab grubuna ait tüm pencerelerde
  birbirinin aynısı olduğu doğrulanır.
- Sekme kapatma action'ı kirli doküman veya workspace state'ini
  kontrol ediyor mu test edilir; aksi halde kaydedilmemiş çalışmalar
  kaybolabilir.
- Sekmenin yeni bir pencereye taşınmasının ardından uygulama state'inin
  doğru pencerede oluştuğu doğrulanır.
- Plus butonunun ürünün istediği yeni pencere/workspace action'ını
  dispatch ettiği test edilir; varsayılan `OpenRecent` davranışı
  yanlışlıkla bırakılmamış olur.
- Sağ tık menüsündeki metinler ve action'lar ürünün diline ve
  davranışına göre uyarlanmış mı kontrol edilir.

## 20. Sık yapılan hatalar

Aşağıdaki liste, üst bar port edilirken en sık karşılaşılan
yanlışları toplar. Bu noktalardan bazıları kolayca gözden kaçar; bir
kez yapıldığında sebebini anlamak saatler alabilir. Her madde ile
birlikte hatanın yol açtığı sonuç da yazılmıştır:

- `PlatformTitleBar` child element'lerinin yalnızca constructor sırasında
  verilmesi. Zed, child listesini render sırasında tükettiği için
  içerik sonraki render geçişinde kaybolur ve başlık çubuğu boş
  görünür.
- Linux CSD butonlarının gösterilip pencere resize ve border sarmalının
  uygulanmaması. Başlık çubuğu çalışıyor gibi görünür; ancak pencere
  kenarı native hissetmez ve gölge/yuvarlama gibi detaylar eksik kalır.
- Close butonunun uygulama lifecycle'ına bağlanmadan doğrudan pencereyi
  kapatması. Bu durumda kirli doküman uyarıları, arka plan görevleri
  veya workspace cleanup adımları atlanmış olur; kullanıcı çalışma
  kaybı yaşar.
- Windows butonlarının Linux'taki gibi click handler ile yönetilmeye
  çalışılması. Windows implementasyonu yalnızca hit-test alanı sağlar;
  davranış platform caption katmanındadır. Buraya click handler
  yerleştirilirse istenen tıklama davranışı hiç tetiklenmez.
- Native tabs açıkken `tabbing_identifier` verilmemesi. Bu eksik
  yapıldığında pencereler aynı native tab grubunda birleşmez ve
  kullanıcı "neden sekmelerim ayrı pencerelerde kalıyor?" sorusunu
  sorar.
- `DraggedWindowTab` payload'ının yalnız bir alan listesi olarak
  mirror edilmesi. Aynı tab bar üzerinde yapılan drop sekmenin yerini
  değiştirir; tab bar dışına bırakma sekmeyi yeni pencereye taşır;
  merge ise ayrı bir action ve context menu akışıdır. Bu üç dal farkı
  yok sayılırsa drag/drop davranışı hatalı çalışır.
- `SystemWindowTabController` state'inin platform native tab state'iyle
  aynı kaynak sanılması. Controller, Zed tarafındaki UI ve action
  modelidir; gerçek platform çağrıları (`window.move_tab_to_new_window`,
  `window.merge_all_windows`) ayrıca yapılır. İki tarafın senkron
  tutulması ihmal edilirse görüntü ile sistem davranışı farklı düşer.
- Uygulamaya özgü menülerin doğrudan `PlatformTitleBar` içine
  gömülmesi. Daha temiz model, platform kabuğunu ayrı, ürün titlebar
  içeriğini ayrı tutmaktır; bu ayrım bozulduğunda port edilen bileşen
  ürünün lehçesine kilitlenir ve başka projede yeniden kullanılamaz
  hâle gelir.

