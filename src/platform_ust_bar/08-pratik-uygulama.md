# Pratik uygulama

Önceki bölümlerde anlatılan parçalar bir araya geldiğinde günlük geliştirmede en sık ihtiyaç duyulan üç şey kalır: nereden özelleştirme yapılacağı, platform bazında neyin kontrol edileceği ve daha önce sık yakalanan hatalar. Bu bölüm bu üç başlığı pratik bir başvuru olarak toplar.

## 18. Özelleştirme noktaları

Aşağıdaki tablo, üst barda en sık değiştirilen davranışların hangi dosya veya alanda ele alındığını gösterir. Yeni bir özelleştirme ihtiyacı doğduğunda önce buraya bakılır; tablodaki giriş ilgili kodun kapısını açar.

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Kapat butonu farklı bir eylem göndermeli | `PlatformTitleBar` içine `close_action` alanı eklenir veya doğrudan serbest render fonksiyonları kullanılır. |
| Linux buton sırası ayardan gelmeli | `set_button_layout(...)` çağrısı uygulamanın ayar durumuna bağlanır; ayar değiştikçe yeniden render tetiklenir. |
| Linux butonlarının ikonu/rengi değişmeli | `WindowControlStyle` veya `WindowControlType::icon()` port karşılığında değişiklik yapılır. |
| Windows kapatma üzerine gelme rengi farklı olmalı | `platform_windows.rs` içindeki `WindowsCaptionButton::Close` (crate-içi enum) renkleri değiştirilir. Tip public değildir; port hedefinde aynı dört varyant kendi enum'unla yeniden yazılır. |
| Başlık çubuğu yüksekliği değişmeli | `platform_title_bar_height` karşılığı port edilir ve tüm başlık çubuğu/kontrol kullanımlarında aynı değer kullanılır. |
| Yerel sekmeler kapatılmalı | `SystemWindowTabs` render çocuk bileşeni özellik bayrağı ile boş döndürülür; denetleyici kaldırılmaz, böylece ihtiyaç doğduğunda etkinleştirmek kolaydır. |
| Sekme artı butonu yeni pencere açmalı | `zed_actions::OpenRecent` yerine uygulamanın kendi `YeniPencere` eylemi gönderilir. |
| Yan panel açıkken kontroller gizlenmemeli | `sidebar_render_state` ve `show_left/right_controls` koşulları değiştirilir. |
| Ürün duyuru bandı gösterilmeli | `UygulamaBaslikCubugu` içinde `OnboardingBanner` muadili bir çocuk bileşen kurulur; görünürlük özellik bayrağı/ayar koşulundan gelir, platform kabuğuna taşınmaz. |
| Güncelleme ipucu değişmeli | `UpdateVersion` muadili bileşendeki ipucu üreticisi güncellenir; eski `Version:` ve kısa SHA biçimi korunmaz. |
| Güncelleme butonunun durumları ayrıştırılmalı | `UpdateButton` muadilinde `checking`, `downloading`, `installing`, `updated`, `errored` için ayrı kurucular tutulur; ilk üçü `disabled(true)` ve döner ikonla işaretlenir, porttaki hata mesajı `"Güncelleme Başarısız"` gibi Türkçe yazılır. |
| Sağ tık pencere menüsü kapatılmalı | Linux CSD'deki `window.show_window_menu(ev.position)` bağı kaldırılır veya bir ayara bağlanır. |
| Çift tıklama maximize yerine farklı bir eylem olmalı | Platform tıklama işleyicileri ürünün kendi eylemine yönlendirilir; macOS sistem davranışına bilinçli olarak müdahale edildiği unutulmaz. |

## 19. Kontrol listesi

Aşağıdaki listeler, üst bar entegrasyonu tamamlandıktan sonra hızlıca gözden geçirilmesi gereken maddeleri toplar. Bunları pratik bir "kaçırdığım bir şey var mı?" denetimi gibi kullanmak gerekir. Her madde kabaca bir kod parçasına veya teste karşılık gelir.

### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında **bir kez** çağrılıyor mu kontrol edilir. İki kez çağrılması, gözlemcilerin çift çalışmasına yol açar.
- Pencerenin `WindowOptions.titlebar` alanı şeffaf başlık çubuğu değeriyle açılıyor mu doğrulanır.
- Linux CSD ihtiyacı varsa `WindowDecorations::Client` isteniyor mu bakılır.
- CSD kullanılıyorsa pencere gölgesi, kenarlığı ve yeniden boyutlandırma davranışı için ayrı bir sarmal uygulanıyor mu kontrol edilir. Bu sarmal olmadan başlık çubuğu yine render olur, ama pencere kenarı yerel hissettirmez.
- Başlık çubuğu çocukları her render geçişinde `set_children(...)` ile yenileniyor mu doğrulanır.
- Başlık çubuğu üzerindeki etkileşimli çocuk elementler sürükleme olay yayılımı ile çakışıyor mu test edilir; bir buton tıklamasının pencereyi sürüklemediğinden emin olunur.
- Tema token'ları aktif, pasif ve üzerine gelme durumlarının hepsini kapsıyor mu kontrol edilir; eksik bir token render'da bariz görsel boşluklar bırakır.
- Ürün duyuru bantları `PlatformTitleBar` içine gömülmeden, `UygulamaBaslikCubugu` çocuk grubu olarak kuruluyor mu kontrol edilir.
- Özellik bayrağına bağlı duyuru bantlarının başlangıçta tek sefer hesaplanmadığı, render sırasında güncel koşul ile gizlenip gösterildiği doğrulanır.
- Güncelleme ipucu semantik sürüm için de SHA için de `"Sürüme Güncelle:"` biçimini kullanıyor mu kontrol edilir; SHA kısaltma yedeği bırakılmaz.
- Güncelleme butonunun geçici durumları (`Checking…`, `Downloading…`, `Installing…`) sırasında tıklamanın kapalı olduğu doğrulanır; döner ikon `LoadCircle` üzerinden iki turluk dönüş yapıyor mu kontrol edilir. Port görünür metinleri Türkçeyse bu durumlar `"Denetleniyor…"`, `"İndiriliyor…"`, `"Kuruluyor…"` gibi yazılır.
- Mevcut pencereye/yan panele proje açan `Activate` akışı pencereyi öne alıyor ve başlık çubuğu durumunu güncelliyor mu test edilir.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı yoluyla `WindowButtonLayout` geliyor mu kontrol edilir.
- Sol ve sağ buton dizilerinin boş slotlarının doğru davrandığı test edilir (ilk slot boş ise tarafın tamamen gizlendiği unutulmaz).
- Masaüstü yerleşimi değiştiğinde başlık çubuğunun otomatik olarak yeniden render olup olmadığı doğrulanır.
- `window.window_controls()` yetenek sonucu, minimize ve maximize desteğini doğru filtreliyor mu sınanır.
- Sağ tık ile açılan sistem pencere menüsü ürünün istediği davranışla uyumlu mu kontrol edilir. Bazı uygulamalar bu menüyü tamamen kapatmayı tercih edebilir.

### Windows

- Caption button alanlarının `WindowControlArea::{Min, Max, Close}` olarak kaldığı doğrulanır; aksi halde Windows yerel caption davranışı bozulur.
- Sağ taraftaki ürün butonlarının caption button hitbox'ları ile çakışmadığı test edilir.
- `platform_title_bar_height` değerinin Windows için `32px` varsayımını koruduğu veya bilinçli olarak değiştirildiği netleştirilir.
- Kapat butonunun üzerine gelme rengi (Microsoft'un kırmızısı), tema politikasıyla uyumlu mu kontrol edilir.

### macOS

- Trafik ışıkları için sol padding korunuyor mu doğrulanır.
- `traffic_light_position` ile başlık çubuğu çocuklarının çakışmadığı test edilir.
- Çalışma zamanında başlık çubuğu yüksekliği, duyuru bandı veya yoğunluk değişiyorsa `window.set_traffic_light_position(...)` ile yerel buton konumu da güncelleniyor mu kontrol edilir.
- Tam ekran ve yerel sekme davranışının ayrı senaryolarda doğru çalıştığı kontrol edilir; iki özelliğin birlikte etkinleştiği durumlar gözden kaçırılır.
- Çift tıklamanın sistem davranışına mı yoksa ürünün özel davranışına mı yönlendirileceği bilinçli olarak karara bağlanır.

### Yerel sekmeler

- `tabbing_identifier` değerinin aynı tab grubuna ait tüm pencerelerde birbirinin aynısı olduğu doğrulanır.
- Sekme kapatma eylemi kirli doküman veya çalışma alanı durumunu kontrol ediyor mu test edilir; aksi halde kaydedilmemiş çalışmalar kaybolabilir.
- Sekmenin yeni bir pencereye taşınmasının ardından uygulama durumunun doğru pencerede oluştuğu doğrulanır.
- Artı butonunun ürünün istediği yeni pencere/çalışma alanı eylemini gönderdiği test edilir; varsayılan `OpenRecent` davranışı yanlışlıkla bırakılmamış olur.
- Sağ tık menüsündeki metinler ve eylemler ürünün diline ve davranışına göre uyarlanmış mı kontrol edilir.

## 20. Sık yapılan hatalar

Aşağıdaki liste, üst bar port edilirken en sık karşılaşılan yanlışları toplar. Bazıları kolayca gözden kaçar; yapıldıktan sonra sebebini anlamak saatler alabilir. Her maddeyle birlikte hatanın yol açtığı sonuç da yazılmıştır:

- `PlatformTitleBar` çocuk elementlerinin yalnızca kurucu sırasında verilmesi. Zed çocuk listesini render sırasında tükettiği için içerik sonraki render geçişinde kaybolur ve başlık çubuğu boş görünür.
- Linux CSD butonlarının gösterilip pencere yeniden boyutlandırma ve kenarlık sarmalının uygulanmaması. Başlık çubuğu çalışıyor gibi görünür; fakat pencere kenarı yerel hissettirmez ve gölge/yuvarlama gibi detaylar eksik kalır.
- Kapat butonunun uygulama yaşam döngüsüne bağlanmadan doğrudan pencereyi kapatması. Bu durumda kirli doküman uyarıları, arka plan görevleri veya çalışma alanı temizlik adımları atlanmış olur; kullanıcı çalışma kaybı yaşar.
- Windows butonlarının Linux'taki gibi tıklama işleyicisi ile yönetilmeye çalışılması. Windows implementasyonu yalnızca hit-test alanı sağlar; davranış platform caption katmanındadır. Buraya tıklama işleyicisi yerleştirilirse istenen tıklama davranışı hiç tetiklenmez.
- Yerel sekmeler açıkken `tabbing_identifier` verilmemesi. Bu eksik yapıldığında pencereler aynı yerel sekme grubunda birleşmez ve kullanıcı "neden sekmelerim ayrı pencerelerde kalıyor?" sorusunu sorar.
- `DraggedWindowTab` yükünün yalnız bir alan listesi olarak birebir taşınması. Aynı sekme çubuğu üzerinde yapılan bırakma sekmenin yerini değiştirir. Sekme çubuğu dışına bırakma sekmeyi yeni pencereye taşır. Birleştirme ise ayrı bir eylem ve bağlam menüsü akışıdır. Bu üç dal farkı yok sayılırsa sürükle-bırak davranışı hatalı çalışır.
- `SystemWindowTabController` durumunun platform yerel sekme durumuyla aynı kaynak sanılması. Denetleyici, Zed tarafındaki UI ve eylem modelidir; gerçek platform çağrıları (`window.move_tab_to_new_window`, `window.merge_all_windows`) ayrıca yaparsın. İki tarafın senkron tutulması ihmal edilirse görüntü ile sistem davranışı farklı düşer.
- Uygulamaya özgü menülerin doğrudan `PlatformTitleBar` içine gömülmesi. Daha temiz model, platform kabuğunu ayrı ve ürün başlık çubuğu içeriğini ayrı tutmaktır. Bu ayrım bozulduğunda port edilen bileşen ürünün lehçesine kilitlenir ve başka projede yeniden kullanılamaz hale gelir.
- Skills gibi ürün duyurularının platform kabuğuna taşınması. Bu duyuru bantları özellik bayrağı, geçiş modalı ve ürün metniyle ilgilidir; doğru yerleri `UygulamaBaslikCubugu` katmanıdır.
- Güncelleme ipucunda eski `Version:` veya kısa SHA biçimini korumak. Zed davranışı tam SHA ve Türkçe portta `"Sürüme Güncelle:"` öneki kullanır; eski biçim için ayrı uyumluluk yolu açılırsa davranış gereksiz yere çatallanır.
- Güncelleme butonunun döner ikonlu durumlarını tıklanabilir bırakmak. `Checking`, `Downloading` ve `Installing` kurucuları `disabled(true)` ile gelir; bu bayrak portta atlanırsa kullanıcı yarım kalmış indirme sırasında tekrar tıklayıp aynı işi yeniden başlatabilir. Portta hata görünür metni `"Güncelleme Başarısız"` gibi Türkçe yazılır.
