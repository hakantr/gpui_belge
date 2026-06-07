# Pratik uygulama

Önceki bölümlerde anlatılan parçalar bir araya geldiğinde günlük geliştirmede en çok ihtiyaç duyulan üç alan öne çıkar: Nereden özelleştirme yapılacağı, platform bazında neyin kontrol edileceği ve dikkat isteyen durumların nerede doğduğu. Bu bölüm, söz konusu üç başlığı pratik bir başvuru kaynağı olarak bir araya getirir.

## 18. Özelleştirme noktaları

Aşağıdaki tablo, üst barda en sık değiştirilen davranışların hangi dosya veya alanda ele alındığını göstermektedir. Yeni bir özelleştirme ihtiyacı doğduğunda öncelikle bu tabloya başvurulabilir; buradaki yönlendirmeler ilgili kod bloklarının yerini gösterir:

| İhtiyaç | Değiştirilecek Yer |
| :-- | :-- |
| Kapat butonu farklı bir eylem göndermeli | `PlatformTitleBar` içine `close_action` alanı eklenir veya doğrudan serbest render fonksiyonları kullanılır. |
| Linux buton sırası ayardan gelmeli | `set_button_layout(...)` çağrısı uygulamanın ayar durumuna bağlanır; ayar değiştikçe yeniden render tetiklenir. |
| Linux butonlarının ikonu/rengi değişmeli | `WindowControlStyle` veya `WindowControlType::icon()` port karşılığında değişiklik gerçekleştirilir. |
| Windows kapatma üzerine gelme rengi farklı olmalı | `platform_windows.rs` içindeki `WindowsCaptionButton::Close` (crate-içi enum) renkleri değiştirilir. Tip public değildir; port hedefinde aynı dört varyant kendi enum yapısıyla yeniden yazılır. |
| Başlık çubuğu yüksekliği değişmeli | `platform_title_bar_height` karşılığı port edilir ve tüm başlık çubuğu/kontrol kullanımlarında aynı değer kullanılır. |
| Yerel sekmeler kapatılmalı | `SystemWindowTabs` render çocuk bileşeni özellik bayrağı ile boş döndürülür; denetleyici kaldırılmaz, böylece ihtiyaç doğduğunda etkinleştirmek kolaydır. |
| Sekme artı butonu yeni pencere açmalı | `zed_actions::OpenRecent` yerine uygulamanın kendi `YeniPencere` eylemi gönderilir. |
| Yan panel açıkken kontroller gizlenmemeli | `sidebar_render_state` ve `show_left/right_controls` koşulları değiştirilir. |
| Ürün duyuru bandı gösterilmeli | `UygulamaBaslikCubugu` içinde `OnboardingBanner` muadili bir çocuk bileşen kurulur; görünürlük bir ayar koşulu (`show_onboarding_banner`) ile kalıcı saklanan kapatılma durumundan gelir, platform kabuğuna taşınmaz. |
| Güncelleme ipucu değişmeli | `UpdateVersion` muadili bileşendeki ipucu üreticisi güncellenir; kaynak davranıştaki `"Update to Version:"` öneki ve tam SHA bilgisi korunur. |
| Güncelleme butonunun durumları ayrıştırılmalı | `UpdateButton` muadilinde `checking`, `downloading`, `installing`, `updated`, `errored` için ayrı kurucular tutulur; `checking` ve `installing` durumları döner `LoadCircle` ikonuyla, `downloading` durumu `Download` ikonuyla ve ilk üç durum `disabled(true)` ile işaretlenir. |
| Sağ tık pencere menüsü kapatılmalı | Linux CSD'deki `window.show_window_menu(ev.position)` bağı kaldırılır veya bir ayara bağlanır. |
| Çift tıklama maximize yerine farklı bir eylem olmalı | Platform tıklama işleyicileri ürünün kendi eylemine yönlendirilir; macOS sistem davranışına bilinçli olarak müdahale edildiği not edilmelidir. |

## 19. Kontrol listesi

Aşağıdaki listeler, üst bar entegrasyonu tamamlandıktan sonra hızlıca gözden geçirilmesi gereken maddeleri toplamaktadır. Bunlar pratik bir son kontrol denetimi gibi kullanılabilir. Her madde kabaca bir kod parçasına veya teste karşılık gelir.

### Genel

- `PlatformTitleBar::init(cx)` çağrısının uygulama başlangıcında **yalnızca bir kez** yürütüldüğü kontrol edilir. İki kez çağrılması, gözlemcilerin çift çalışmasına yol açar.
- Pencerenin `WindowOptions.titlebar` alanının şeffaf başlık çubuğu değeriyle açıldığı doğrulanır.
- Linux CSD ihtiyacı varsa `WindowDecorations::Client` seçeneğinin talep edilip edilmediğine bakılır.
- CSD kullanılıyorsa pencere gölgesi, kenarlığı ve yeniden boyutlandırma davranışı için ayrı bir sarmalın uygulanıp uygulanmadığı kontrol edilir. Bu sarmal olmadan başlık çubuğu yine render olur, ancak pencere kenarı yerel hissettirmez.
- Başlık çubuğu çocuklarının her render geçişinde `set_children(...)` ile yenilendiği doğrulanır.
- Başlık çubuğu üzerindeki etkileşimli çocuk elementlerin sürükleme olay yayılımı ile çakışıp çakışmadığı test edilmeli; bir buton tıklamasının pencereyi sürüklemediğinden emin olunmalıdır.
- Tema token'larının aktif, pasif ve üzerine gelme durumlarının hepsini kapsayıp kapsamadığı kontrol edilir; eksik bir token render'da bariz görsel boşluklar bırakır.
- Ürün duyuru bantlarının `PlatformTitleBar` içine gömülmeden, `UygulamaBaslikCubugu` çocuk grubu olarak kurulup kurulmadığı kontrol edilir.
- Duyuru bantlarının görünürlüğünün başlangıçta tek sefer hesaplanmadığını, render sırasında güncel ayar koşulu ve kapatılma durumu ile gizlenip gösterildiği doğrulanır. Görünürlük `should_show = !dismissed && visible_when(cx)` biçiminde değerlendirilir; `visible_when` bir koşul kapanışıdır ve kapatılma durumu kalıcı olarak saklanır.
- Güncelleme ipucunun semantik sürüm için de SHA için de kaynak davranıştaki `"Update to Version:"` önekesini ve tam SHA bilgisini koruyup korumadığı kontrol edilir. Port görünür metinleri Türkçeyse bu veri ayrımı yerelleştirilmiş metinde de korunur.
- Güncelleme butonunun geçici durumları (`Checking for Zed Updates…`, `Downloading Zed Update…`, `Installing Zed Update…`) sırasında tıklamanın kapalı olduğu doğrulanır; `checking` ve `installing` durumlarında döner `LoadCircle` ikonunun her turu 2 saniyede tamamlayan sürekli (sonsuz tekrarlı) bir dönüş yaptığını, `downloading` durumunda ise `Download` ikonunun animasyonsuz olarak kullanıldığı kontrol edilir. Port görünür metinleri Türkçeyse bu durumlar `"Denetleniyor…"`, `"İndiriliyor…"`, `"Kuruluyor…"` gibi yazılır.
- Mevcut pencereye/yan panele proje açan `Activate` akışının pencereyi öne alıp almadığı ve başlık çubuğu durumunu güncelleyip güncellemediği test edilir.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı yoluyla `WindowButtonLayout` değerinin gelip gelmediği kontrol edilir.
- Sol ve sağ buton dizilerinin boş slotlarının doğru davrandığı test edilir (sol ve sağ buton dizilerinin ilk slotunun boş olması durumunda o tarafın tamamen gizlendiği dikkate alınmalıdır).
- Masaüstü yerleşimi değiştiğinde başlık çubuğunun otomatik olarak yeniden render edilip edilmediği doğrulanır.
- `window.window_controls()` yetenek sonucunun, minimize ve maximize desteğini doğru filtreleyip filtrelemediği sınanır.
- Sağ tık ile açılan sistem pencere menüsünün ürünün istediği davranışla uyumlu olup olmadığı kontrol edilir. Bazı uygulamalar bu menüyü tamamen kapatmayı tercih edebilir.

### Windows

- Caption button alanlarının `WindowControlArea::{Min, Max, Close}` olarak kaldığı doğrulanır; bu eşleme değişirse Windows yerel caption davranışıyla uyumsuzluk oluşur.
- Sağ taraftaki ürün butonlarının caption button hitbox'ları ile çakışmadığı test edilir.
- `platform_title_bar_height` değerinin Windows için `32px` varsayımını koruduğu veya bilinçli olarak değiştirildiği netleştirilmelidir.
- Kapat butonunun üzerine gelme renginin (Microsoft'un kırmızısı), tema politikasıyla uyumlu olup olmadığı kontrol edilir.

### macOS

- Trafik ışıkları için sol padding değerinin korunup korunmadığı doğrulanır.
- `traffic_light_position` ile başlık çubuğu çocuklarının çakışmadığı test edilir.
- Trafik ışıklarının başlangıç konumunun, pencere oluşturulurken `TitlebarOptions.traffic_light_position` ile verildiği; Zed'in kendisinin çalışma zamanında bu konumu yeniden ayarlamadığı bilinmelidir. Çalışma zamanında başlık çubuğu yüksekliği, duyuru bandı veya yoğunluk değişiyorsa yerel buton konumunu güncellemek porta özgü bir gerekliliktir; bu durumda `window.set_traffic_light_position(...)` çağrısıyla konumunun güncellendiği doğrulanır.
- Tam ekran ve yerel sekme davranışının ayrı senaryolarda doğru çalıştığı kontrol edilir; iki özelliğin birlikte etkinleştiği durumlar ayrıca test edilir.
- Çift tıklamanın sistem davranışına mı yoksa ürünün özel davranışına mı yönlendirileceğinin bilinçli olarak karara bağlanması gerekir.

### Yerel Sekmeler

- `tabbing_identifier` değerinin aynı tab grubuna ait tüm pencerelerde birbirinin aynısı olduğu doğrulanır.
- Sekme kapatma eyleminin kirli doküman veya çalışma alanı durumunu kontrol edip etmediği test edilir; bu kontrol yoksa kaydedilmemiş çalışmalar için ürünün koruma akışı devreye giremez.
- Sekmenin yeni bir pencereye taşınmasının ardından uygulama durumunun doğru pencerede oluştuğu doğrulanır.
- Artı butonunun ürünün istediği yeni pencere/çalışma alanı eylemini gönderip göndermediği test edilir; kaynak `OpenRecent` davranışı değiştirilecekse bu seçim bilinçli biçimde gerçekleştirilir.
- Sağ tık menüsündeki metinlerin ve eylemlerin ürünün diline ve davranışına göre uyarlanıp uyarlanmadığı kontrol edilir.

## 20. Dikkat Edilmesi Gereken Kullanımlar

Aşağıdaki liste, üst bar port edilirken dikkat isteyen kullanım noktalarını bir araya getirir. Her maddeyle birlikte ilgili kararın görünür sonucu da açıklanmıştır:

- `PlatformTitleBar` çocuk elementlerinin yalnızca kurucu sırasında verilmesi: Zed çocuk listesini render sırasında tükettiği için içerik sonraki render geçişinde kaybolur ve başlık çubuğu boş görünür.
- Linux CSD butonlarının gösterilip pencere yeniden boyutlandırma ve kenarlık sarmalının uygulanmaması: Başlık çubuğu çalışıyor gibi görünür; fakat pencere kenarı yerel hissettirmez ve gölge/yuvarlama gibi detaylar tasarım dışında kalır.
- Kapat butonunun uygulama yaşam döngüsüne bağlanmadan doğrudan pencereyi kapatması: Bu bağlantı yoksa kirli doküman uyarıları, arka plan görevleri veya çalışma alanı temizlik adımları devre dışı kalır; kullanıcı veri kaybı yaşayabilir.
- Windows butonlarının Linux'taki gibi tıklama işleyicisi ile yönetilmeye çalışılması: Windows implementasyonu yalnızca hit-test alanı sağlar; davranış platform caption katmanındadır. Buraya tıklama işleyicisi yerleştirilirse istenen tıklama davranışı hiç tetiklenmez.
- Yerel sekmeler açıkken `tabbing_identifier` verilmemesi: Bu bağlantı yoksa pencereler aynı yerel sekme grubunda birleşmez ve kullanıcı sekmelerin neden ayrı pencerelerde kaldığını anlayamaz.
- `DraggedWindowTab` yükünün yalnız bir alan listesi olarak birebir taşınması: Aynı sekme çubuğu üzerinde yapılan bırakma sekmenin yerini değiştirir. Sekme çubuğu dışına bırakma sekmeyi yeni pencereye taşır. Birleştirme ise ayrı bir eylem ve bağlam menüsü akışıdır. Bu üç dal ayrı kurulmazsa sürükle-bırak davranışının platform paritesi bozulur.
- `SystemWindowTabController` durumunun platform yerel sekme durumuyla aynı kaynak olarak ele alınması: Denetleyici, Zed tarafındaki UI ve eylem modelidir; gerçek platform çağrıları (`window.move_tab_to_new_window`, `window.merge_all_windows`) ayrıca gerçekleştirilir. İki tarafın senkron tutulması birlikte yürütülmezse görüntü ile sistem davranışı farklı düşer.
- Uygulamaya özgü menülerin doğrudan `PlatformTitleBar` içine gömülmesi: Daha temiz model, platform kabuğunu ayrı ve ürün başlık çubuğu içeriğini ayrı tutmaktır. Bu ayrım korunmadığında port edilen bileşen ürünün yapısına kilitlenir ve başka projede yeniden kullanılamaz hale gelir.
- Duyuru bantları gibi ürün duyurularının platform kabuğuna taşınması: Bu duyuru bantları özellik bayrağı, geçiş modalı ve ürün metniyle ilgilidir; doğru yerleri `UygulamaBaslikCubugu` katmanıdır.
- Güncelleme ipucunda eski `Version:` veya kısa SHA biçimini korumak: Zed davranışı tam SHA ve `"Update to Version:"` önekesini kullanır; yerelleştirilmiş portta da aynı veri ayrımı korunur.
- Güncelleme butonunun geçici durumlarını tıklanabilir bırakmak: `Checking for Zed Updates…`, `Downloading Zed Update…` ve `Installing Zed Update…` durumları `disabled(true)` ile gelir; bu bayrak korunmazsa kullanıcı yarım kalmış indirme sırasında tekrar tıklayıp aynı işi yeniden başlatabilir. Kaynak hata görünür metni `"Failed to Update"` biçimindedir; yerelleştirilmiş portta anlam korunarak Türkçeleştirilir.

---
