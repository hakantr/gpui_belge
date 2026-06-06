# Pratik uygulama

Önceki bölümlerde anlatılan parçalar bir araya geldiğinde günlük geliştirmede en çok ihtiyaç duyulan üç şey kalır: nereden özelleştirme yapılacağı, platform bazında neyin kontrol edileceği ve dikkat isteyen durumların nerede doğduğu. Bu bölüm bu üç başlığı pratik bir başvuru olarak toplar.

## 18. Özelleştirme noktaları

Aşağıdaki tablo, üst barda en sık değiştirilen davranışların hangi dosya veya alanda ele alındığını gösterir. Yeni bir özelleştirme ihtiyacı doğduğunda önce buraya bakarsın; tablodaki giriş ilgili kodun kapısını açar.

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Kapat butonu farklı bir eylem göndermeli | `PlatformTitleBar` içine `close_action` alanı eklenir veya doğrudan serbest render fonksiyonları kullanırsın. |
| Linux buton sırası ayardan gelmeli | `set_button_layout(...)` çağrısı uygulamanın ayar durumuna bağlanır; ayar değiştikçe yeniden render tetiklersin. |
| Linux butonlarının ikonu/rengi değişmeli | `WindowControlStyle` veya `WindowControlType::icon()` port karşılığında değişiklik yaparsın. |
| Windows kapatma üzerine gelme rengi farklı olmalı | `platform_windows.rs` içindeki `WindowsCaptionButton::Close` (crate-içi enum) renkleri değiştirilir. Tip public değildir; port hedefinde aynı dört varyant kendi enum'unla yeniden yazılır. |
| Başlık çubuğu yüksekliği değişmeli | `platform_title_bar_height` karşılığı port edilir ve tüm başlık çubuğu/kontrol kullanımlarında aynı değer kullanırsın. |
| Yerel sekmeler kapatılmalı | `SystemWindowTabs` render çocuk bileşeni özellik bayrağı ile boş döndürülür; denetleyici kaldırılmaz, böylece ihtiyaç doğduğunda etkinleştirmek kolaydır. |
| Sekme artı butonu yeni pencere açmalı | `zed_actions::OpenRecent` yerine uygulamanın kendi `YeniPencere` eylemi gönderirsin. |
| Yan panel açıkken kontroller gizlenmemeli | `sidebar_render_state` ve `show_left/right_controls` koşulları değiştirilir. |
| Ürün duyuru bandı gösterilmeli | `UygulamaBaslikCubugu` içinde `OnboardingBanner` muadili bir çocuk bileşen kurulur; görünürlük bir ayar koşulu (`show_onboarding_banner`) ile kalıcı saklanan kapatılma durumundan gelir, platform kabuğuna taşınmaz. |
| Güncelleme ipucu değişmeli | `UpdateVersion` muadili bileşendeki ipucu üreticisi güncellenir; kaynak davranıştaki `"Update to Version:"` öneki ve tam SHA bilgisi korunur. |
| Güncelleme butonunun durumları ayrıştırılmalı | `UpdateButton` muadilinde `checking`, `downloading`, `installing`, `updated`, `errored` için ayrı kurucular tutulur; `checking` ve `installing` durumları döner `LoadCircle` ikonuyla, `downloading` durumu `Download` ikonuyla ve ilk üç durum `disabled(true)` ile işaretlenir. |
| Sağ tık pencere menüsü kapatılmalı | Linux CSD'deki `window.show_window_menu(ev.position)` bağı kaldırılır veya bir ayara bağlanır. |
| Çift tıklama maximize yerine farklı bir eylem olmalı | Platform tıklama işleyicileri ürünün kendi eylemine yönlendirilir; macOS sistem davranışına bilinçli olarak müdahale edildiği not edersin. |

## 19. Kontrol listesi

Aşağıdaki listeler, üst bar entegrasyonu tamamlandıktan sonra hızlıca gözden geçirilmesi gereken maddeleri toplar. Bunları pratik bir son kontrol denetimi gibi kullanırsın. Her madde kabaca bir kod parçasına veya teste karşılık gelir.

### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında **bir kez** çağrılıyor mu diye kontrol edersin. İki kez çağrılması, gözlemcilerin çift çalışmasına yol açar.
- Pencerenin `WindowOptions.titlebar` alanı şeffaf başlık çubuğu değeriyle açılıyor mu diye doğrularsın.
- Linux CSD ihtiyacı varsa `WindowDecorations::Client` isteniyor mu diye bakarsın.
- CSD kullanılıyorsa pencere gölgesi, kenarlığı ve yeniden boyutlandırma davranışı için ayrı bir sarmal uygulanıyor mu diye kontrol edersin. Bu sarmal olmadan başlık çubuğu yine render olur, ama pencere kenarı yerel hissettirmez.
- Başlık çubuğu çocukları her render geçişinde `set_children(...)` ile yenileniyor mu diye doğrularsın.
- Başlık çubuğu üzerindeki etkileşimli çocuk elementler sürükleme olay yayılımı ile çakışıyor mu diye test edersin; bir buton tıklamasının pencereyi sürüklemediğinden emin olursun.
- Tema token'ları aktif, pasif ve üzerine gelme durumlarının hepsini kapsıyor mu diye kontrol edersin; eksik bir token render'da bariz görsel boşluklar bırakır.
- Ürün duyuru bantları `PlatformTitleBar` içine gömülmeden, `UygulamaBaslikCubugu` çocuk grubu olarak kuruluyor mu diye kontrol edersin.
- Duyuru bantlarının görünürlüğünün başlangıçta tek sefer hesaplanmadığını, render sırasında güncel ayar koşulu ve kapatılma durumu ile gizlenip gösterildiğini doğrularsın. Görünürlük `should_show = !dismissed && visible_when(cx)` biçiminde değerlendirilir; `visible_when` bir koşul kapanışıdır ve kapatılma durumu kalıcı saklarsın.
- Güncelleme ipucu semantik sürüm için de SHA için de kaynak davranıştaki `"Update to Version:"` önekini ve tam SHA bilgisini koruyor mu diye kontrol edersin. Port görünür metinleri Türkçeyse bu veri ayrımı yerelleştirilmiş metinde de korunur.
- Güncelleme butonunun geçici durumları (`Checking for Zed Updates…`, `Downloading Zed Update…`, `Installing Zed Update…`) sırasında tıklamanın kapalı olduğunu doğrularsın; `checking` ve `installing` durumlarında döner `LoadCircle` ikonunun her turu 2 saniyede tamamlayan sürekli (sonsuz tekrarlı) bir dönüş yaptığını, `downloading` durumunda ise `Download` ikonunun animasyonsuz olarak kullanıldığını kontrol edersin. Port görünür metinleri Türkçeyse bu durumlar `"Denetleniyor…"`, `"İndiriliyor…"`, `"Kuruluyor…"` gibi yazılır.
- Mevcut pencereye/yan panele proje açan `Activate` akışı pencereyi öne alıyor ve başlık çubuğu durumunu güncelliyor mu diye test edersin.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı yoluyla `WindowButtonLayout` geliyor mu diye kontrol edersin.
- Sol ve sağ buton dizilerinin boş slotlarının doğru davrandığını test edersin (ilk slot boş ise tarafın tamamen gizlendiğini dikkate alırsın).
- Masaüstü yerleşimi değiştiğinde başlık çubuğunun otomatik olarak yeniden render olup olmadığını doğrularsın.
- `window.window_controls()` yetenek sonucu, minimize ve maximize desteğini doğru filtreliyor mu diye sınarsın.
- Sağ tık ile açılan sistem pencere menüsü ürünün istediği davranışla uyumlu mu diye kontrol edersin. Bazı uygulamalar bu menüyü tamamen kapatmayı tercih edebilir.

### Windows

- Caption button alanlarının `WindowControlArea::{Min, Max, Close}` olarak kaldığını doğrularsın; bu eşleme değişirse Windows yerel caption davranışıyla uyumsuzluk oluşur.
- Sağ taraftaki ürün butonlarının caption button hitbox'ları ile çakışmadığını test edersin.
- `platform_title_bar_height` değerinin Windows için `32px` varsayımını koruduğunu veya bilinçli olarak değiştirildiğini netleştirirsin.
- Kapat butonunun üzerine gelme rengi (Microsoft'un kırmızısı), tema politikasıyla uyumlu mu diye kontrol edersin.

### macOS

- Trafik ışıkları için sol padding korunuyor mu diye doğrularsın.
- `traffic_light_position` ile başlık çubuğu çocuklarının çakışmadığını test edersin.
- Trafik ışıklarının başlangıç konumu, pencere oluşturulurken `TitlebarOptions.traffic_light_position` ile verilir; Zed'in kendisi çalışma zamanında bu konumu yeniden ayarlamaz. Çalışma zamanında başlık çubuğu yüksekliği, duyuru bandı veya yoğunluk değişiyorsa yerel buton konumunu güncellemek porta özgü bir gerekliliktir; bu durumda `window.set_traffic_light_position(...)` çağrısıyla konumun güncellendiğini doğrularsın.
- Tam ekran ve yerel sekme davranışının ayrı senaryolarda doğru çalıştığını kontrol edersin; iki özelliğin birlikte etkinleştiği durumları ayrıca test edersin.
- Çift tıklamanın sistem davranışına mı yoksa ürünün özel davranışına mı yönlendirileceğini bilinçli olarak karara bağlarsın.

### Yerel sekmeler

- `tabbing_identifier` değerinin aynı tab grubuna ait tüm pencerelerde birbirinin aynısı olduğunu doğrularsın.
- Sekme kapatma eylemi kirli doküman veya çalışma alanı durumunu kontrol ediyor mu diye test edersin; bu kontrol yoksa kaydedilmemiş çalışmalar için ürünün koruma akışı devreye giremez.
- Sekmenin yeni bir pencereye taşınmasının ardından uygulama durumunun doğru pencerede oluştuğunu doğrularsın.
- Artı butonunun ürünün istediği yeni pencere/çalışma alanı eylemini gönderdiğini test edersin; kaynak `OpenRecent` davranışı değiştirilecekse bu seçimi bilinçli biçimde yaparsın.
- Sağ tık menüsündeki metinler ve eylemler ürünün diline ve davranışına göre uyarlanmış mı diye kontrol edersin.

## 20. Dikkat Edilmesi Gereken Kullanımlar

Aşağıdaki liste, üst bar port edilirken dikkat isteyen kullanım noktalarını toplar. Her maddeyle birlikte ilgili kararın görünür sonucu da yazılmıştır:

- `PlatformTitleBar` çocuk elementlerinin yalnızca kurucu sırasında verilmesi. Zed çocuk listesini render sırasında tükettiği için içerik sonraki render geçişinde kaybolur ve başlık çubuğu boş görünür.
- Linux CSD butonlarının gösterilip pencere yeniden boyutlandırma ve kenarlık sarmalının uygulanmaması. Başlık çubuğu çalışıyor gibi görünür; fakat pencere kenarı yerel hissettirmez ve gölge/yuvarlama gibi detaylar tasarım dışında kalır.
- Kapat butonunun uygulama yaşam döngüsüne bağlanmadan doğrudan pencereyi kapatması. Bu bağlantı yoksa kirli doküman uyarıları, arka plan görevleri veya çalışma alanı temizlik adımları devre dışında kalır; kullanıcı çalışma kaybı yaşayabilir.
- Windows butonlarının Linux'taki gibi tıklama işleyicisi ile yönetilmeye çalışılması. Windows implementasyonu yalnızca hit-test alanı sağlar; davranış platform caption katmanındadır. Buraya tıklama işleyicisi yerleştirilirse istenen tıklama davranışı hiç tetiklenmez.
- Yerel sekmeler açıkken `tabbing_identifier` verilmemesi. Bu bağlantı yoksa pencereler aynı yerel sekme grubunda birleşmez ve kullanıcı sekmelerin neden ayrı pencerelerde kaldığını anlayamaz.
- `DraggedWindowTab` yükünün yalnız bir alan listesi olarak birebir taşınması. Aynı sekme çubuğu üzerinde yapılan bırakma sekmenin yerini değiştirir. Sekme çubuğu dışına bırakma sekmeyi yeni pencereye taşır. Birleştirme ise ayrı bir eylem ve bağlam menüsü akışıdır. Bu üç dal ayrı kurulmazsa sürükle-bırak davranışının platform paritesi bozulur.
- `SystemWindowTabController` durumunun platform yerel sekme durumuyla aynı kaynak olarak ele alınması. Denetleyici, Zed tarafındaki UI ve eylem modelidir; gerçek platform çağrıları (`window.move_tab_to_new_window`, `window.merge_all_windows`) ayrıca yaparsın. İki tarafın senkron tutulması birlikte yapılmazsa görüntü ile sistem davranışı farklı düşer.
- Uygulamaya özgü menülerin doğrudan `PlatformTitleBar` içine gömülmesi. Daha temiz model, platform kabuğunu ayrı ve ürün başlık çubuğu içeriğini ayrı tutmaktır. Bu ayrım korunmadığında port edilen bileşen ürünün lehçesine kilitlenir ve başka projede yeniden kullanılamaz hale gelir.
- Skills gibi ürün duyurularının platform kabuğuna taşınması. Bu duyuru bantları özellik bayrağı, geçiş modalı ve ürün metniyle ilgilidir; doğru yerleri `UygulamaBaslikCubugu` katmanıdır.
- Güncelleme ipucunda eski `Version:` veya kısa SHA biçimini korumak. Zed davranışı tam SHA ve `"Update to Version:"` öneki kullanır; yerelleştirilmiş portta da aynı veri ayrımı korunur.
- Güncelleme butonunun geçici durumlarını tıklanabilir bırakmak. `Checking for Zed Updates…`, `Downloading Zed Update…` ve `Installing Zed Update…` durumları `disabled(true)` ile gelir; bu bayrak korunmazsa kullanıcı yarım kalmış indirme sırasında tekrar tıklayıp aynı işi yeniden başlatabilir. Kaynak hata görünür metni `"Failed to Update"` biçimindedir; yerelleştirilmiş portta anlam korunarak Türkçeleştirilir.
