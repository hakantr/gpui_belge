# Temeller

---

## Büyük Resim

GPUI, birbirinin üzerine kurulan üç katmandan oluşur. Her katman bir alttakinin üzerine binip bir üsttekine daha sade bir arayüz sunar. Böylece uygulama geliştirirken hangi sorumluluğun hangi katmanda çözüleceğinin belirlenmesi kolaylaşır.

![GPUI Katman Mimarisi](assets/mimari.svg)

1. **Platform katmanı.** İşletim sistemine doğrudan dokunan kısımdır. GPUI; macOS, Windows, Linux, web ve test ortamlarını aynı ortak arayüzün arkasında gizler. Uygulama kodunun "pencere aç", "girdi al", "ekrana çiz" gibi istekleri ortak bir sözleşme ile aktarılır. Bu sözleşmeyi `Platform` ve `PlatformWindow` trait'leri taşır. Pencere oluşturma, ekran listesi, pano (`clipboard`), sürükle-bırak, sistem zili ve dosya seçici gibi platforma özgü yetenekler bu iki trait üzerinden açılır. Bu trait'lerin macOS, Windows, Linux, web ve test arka uçlarını GPUI/Zed tarafındaki platform crate'leri uygular; geliştirdiğin uygulama kodu normalde aynı `App`, `Window` ve element API'siyle konuşur. Böylece her platform için ayrı bir pencere ve arayüz katmanı yazmak yerine, GPUI'nin sağladığı bu ortak soyutlama katmanı üzerinde geliştirme yapman mümkündür.

2. **Uygulama/durum katmanı.** Uygulamanın yaşam döngüsü ve bellekteki tüm durum burada yaşar. `Application` süreç başlangıcını ve olay döngüsünü (`event loop`) yönetir. `App` uygulama genelindeki duruma erişilen ana kapıdır. `Context<T>`, belirli bir varlık güncellenirken `App`'in üstüne eklenen daha geniş bir bağlamdır. `Entity<T>` ve `WeakEntity<T>` ise dinamik bellekte tutulan durum kutularına güçlü ve zayıf erişim sağlar. Hem `Task` hem de `Subscription`, ilişkili değer elden çıkarıldığında (bellekten düştüğünde) arka plandaki görevi veya aboneliği otomatik olarak sonlandırıp temizleyen sahiplik (RAII) araçlarıdır. `Global` uygulama açık kaldığı sürece tek kopya kalması gereken kaynaklar içindir. Olay sistemi ise varlıklar arasında tip güvenli bir mesajlaşma köprüsü oluşturur.

3. **Render/element katmanı.** Ekrandaki ağacı üretip çizen kısımdır. `Render` trait'i, kendi verisini taşıyan entity'lerin her ekran karesinde yeni bir element ağacı üretmesini sağlar. `RenderOnce` ve `IntoElement` ise yeniden kullanılabilir, kendi kalıcı verisini taşımayan bileşenleri tanımlar. `Element` trait'i yerleşim ile çizim sözleşmesinin kendisidir. `div`, `canvas`, `list`, `uniform_list`, `img`, `svg`, `anchored` ve `surface` (yalnız macOS) bu trait'in hazır uygulamalarıdır. Bu elementlerin üzerine, GPUI'nin sunduğu `Styled` ve `InteractiveElement` zincirleri eklenir. Flexbox/grid yerleşim kuralları, renk tanımları, tıklama, sürükleme, klavye odağı ve kaydırma (scroll) gibi tüm görsel ve etkileşimli davranışlar bu zincirler vasıtasıyla yapılandırılır.

Zed bu üç katmanın üstüne kendi tasarım sistemini koyar. Bunlar GPUI'nin parçası değil; GPUI üzerine yazılmış son kullanıcı bileşenleridir:

- `ui` — Button, Icon, Label, Modal, ContextMenu, Tooltip, Tab, Table, Toggle ve benzeri yeniden kullanılan bileşenleri barındırır. Bileşen kiti, tutarlı bir görsel dil ve ortak davranış kalıbı sunar; böylece uygulama içi ekranları bu kiti temel alarak hızlıca inşa etmek mümkündür. Zed uygulama kodu çoğu zaman `use ui::prelude::*;` ile başlar. Bu prelude GPUI çekirdek trait'lerini ve Zed'in sık kullanılan UI bileşenlerini birlikte getirir. Yalnız çekirdek GPUI örneği yazarken `gpui::prelude::*` yeterli olabilir.

  ```rust
  use ui::prelude::*; // Zed UI + GPUI çekirdek trait'leri
  ```
- `platform_title_bar` — platforma göre pencere kontrol butonlarını ve başlık çubuğu davranışını çizer. Linux ve Windows tarafında istemci tarafı süslemesi (`client-side decoration`) gerektiğinde başlık çubuğunu da bu paket üretir.

  ![platform_title_bar katmanı](assets/platform-titlebar-katmani.svg)

- `workspace` — ana çalışma alanını, istemci tarafı süslemesi gölgesini, pencere köşelerindeki yeniden boyutlandırma bölgelerini ve pencere içeriğini tek bir bütün halinde birleştirir. Uygulamanın iskeleti, panellerin yerleşimi ve pencere kromu burada toplanır.

  ![workspace kabuk katmanı](assets/workspace-kabuk-katmani.svg)

Kısacası alttan yukarıya doğru sıralama şöyle: platform → durum → çizim. Bu rehber önce bu üç GPUI katmanını açar; sonraki Zed UI, `platform_title_bar` ve `workspace` bölümlerinde ise Zed'in bu katmanları nasıl kullandığını referans alıp aynı yaklaşımları kendi geliştirdiğin GPUI uygulamalarına nasıl uyarlayabileceğini detaylandırır.

## GPUI Kavram Sözlüğü: Temel Kavramlara Giriş

Bu bölüm bir ezber tablosu değildir. GPUI'yi ilk kez okurken asıl zor olan şey, aynı anda birkaç farklı "dünya" ile karşılaşmaktır: çalışan uygulama, pencere, bellekte tutulan veri, her ekran karesinde yeniden kurulan element ağacı, async işler ve kullanıcı girdisi. Aşağıdaki sözlük, bu farklı dünyaları ve bunların birbiriyle olan ilişkilerini netleştirmek amacıyla hazırlanmıştır.

En kısa zihinsel model şu:

1. `Application` programı başlatır.
2. `App` çalışan uygulamanın ana belleği ve servis kapısıdır.
3. `App`, `Entity<T>` adı verilen kalıcı veri nesneleri oluşturur.
4. Bir pencerenin başlangıç view'u, yani kök view, genellikle `Render` trait'ini uygulayan bir `Entity<V>` olur.
5. `Render::render`, o anki veriyi geçici bir element ağacına çevirir.
6. `Element` ağacı yerleşim, çizim hazırlığı ve çizim aşamalarından geçer; sonra ekrana basılır.

Yani GPUI'de ekranda gördüğün şeyler doğrudan bellekte duran nesneler değildir. Bellekte kalıcı olan çoğunlukla `Entity<T>` içindeki veridir. Ekrandaki element ağacı ise her çizimde yeniden üretilen geçici bir tariftir. Bu temel ayrımın zihne erken yerleştirilmesi, ilerleyen bölümlerde karşılaşılacak neredeyse tüm API tasarım kararlarını ve mimari tercihleri anlamlandırmayı kolaylaştıracaktır.

### Uygulama ve Durum

| Kavram | Basit karşılık | Ne işe yarar? | İlk okurken dikkat |
|---|---|---|---|
| `Application` | Programın dış kabı | `main` tarafında platformu, asset kaynağını ve olay döngüsünü (`event loop`) kurar. Uygulama hazır olduğunda `run` geri çağrısı içinde sisteme `&mut App` döndürür. | Uygulama yaşam döngüsünde genellikle başlangıç sırasında bir kez kurulması yeterlidir. Yeni ekran veya pencere özellikleri geliştirmek için sıfırdan bir `Application` oluşturmak yerine, mevcut `App` ve `Window` bağlamları üzerinden hareket edilir. |
| `App` | Çalışan uygulamanın merkezi | Uygulama genelindeki verilere, pencerelere, entity listesine, kısayol tablosuna, async çalıştırıcılara, platform servislerine ve asset sistemine erişim sağlar. | `cx` adı bir zorunluluk değil, GPUI/Zed kodlarında bağlam değişkeni için yaygın kullanılan bir isimlendirme tercihidir. Aynı ad farklı bağlamlarda farklı tipi gösterebilir: bazen yalnızca `App`, bazen de bir entity'ye bağlı `Context<T>` olur. |
| `Global` | Her yerden erişilen ortak veri | Tema, ayarlar, uygulama oturumu veya tüm pencerelerin paylaşması gereken servisler gibi uygulama açık kaldığı sürece tek kopya durması gereken veriler için kullanılır. | Yalnızca tek bir panele özgü olan arama metinleri, seçili satır indisleri veya bileşen görünürlük durumları gibi lokal bilgiler `Global` altında tutulmamalıdır; bu tür veriler, ilgili paneli yöneten ve genellikle bir `Entity<T>` içerisinde barındırılan Rust veri yapısının kendi alanlarında saklanır. |
| `Entity<T>` | Tipli, kalıcı veri kaydı | `T` tipindeki bir değeri GPUI'nin dahili entity listesinde saklar. Veri üzerindeki okuma ve güncelleme işlemleri sırasıyla `varlik.read(cx)` ve `varlik.update(cx, ...)` metotlarıyla gerçekleştirilir. | `Entity<T>` ekrandaki kutu veya buton değildir; ekrana ne çizileceğini belirleyen veriyi tutar. |
| `WeakEntity<T>` | Entity'yi hayatta tutmayan referans | Asenkron görevler, olay abonelikleri veya nesneler arasındaki döngüsel bağımlılıkların çözümü gibi durumlarda, hedef entity'ye güvenle geri dönebilmek amacıyla kullanılır; ancak güçlü referansların aksine nesneyi bellekte canlı tutma özelliği yoktur. | Kullanıcının pencereyi kapatması veya entity'nin bellekten düşmesi durumlarında `upgrade` veya `update` çağrılarının başarısız (`Err`/`None`) dönebileceği göz önünde bulundurulmalıdır. |
| `Context<T>` | Bir entity üzerinde çalışırken gelen bağlam | Bir `Entity<T>` güncellenirken veya çizim çıktısı üretilirken aktif hale gelir. `App` yeteneklerine ek olarak `cx.notify()`, `cx.emit(...)`, `cx.observe(...)`, `cx.subscribe(...)` ve `cx.spawn(...)` gibi o entity'ye özel metotları açar. | Entity içindeki veri değişimlerinin ekrana anında yansıması isteniyorsa, güncelleme bloğunun (update) sonunda `cx.notify()` ile pencereyi yeniden çizime zorlamak gerekir. |
| `EventEmitter<E>` | Entity'nin olay duyurması | Bir entity'nin dış dünyaya `E` tipinde olaylar (event) fırlatabileceğini beyan eder. Bu sayede diğer bileşenler ilgili olayları dinleyip tepki verebilir. | Bu mekanizma web tarayıcılarındaki DOM olay yayılımına benzemez; tamamen entity'ler arası tip güvenli bir mesajlaşma modelidir. |
| `Subscription` | Dinleyici kaydının ömrü | Aboneliklerin, olay gözlemcilerinin (observe) veya dinleyici kayıtlarının ömrünü yönetir. `Subscription` nesnesi bellekten düştüğünde dinleme işlemi otomatik olarak sonlandırılır. | Elde edilen `Subscription` nesnesi bir struct alanında veya canlı bir değişkende saklanmadığı takdirde, kapsam dışına çıktığı an abonelik sonlanır. |
| `Task<T>` | İptal edilebilir async iş | Ön plan veya arka plan çalıştırıcısında (executor) yürütülen asenkron bir future işlemini temsil eder. | `Task` nesnesi bellekten silindiğinde temsil ettiği asenkron iş otomatik olarak iptal edilir. İşin arka planda tamamlanması isteniyorsa, nesne bir struct alanında saklanmalı veya `detach` metoduyla bağımsız bırakılmalıdır. |
| `AsyncApp` | `await` sonrasına taşınabilen app bağlamı | Asenkron bloklar içerisinden ana iş parçacığındaki (main thread) `App` durumuna güvenli şekilde erişim sağlamaya yarar. | `await` adımı sırasında pencere veya entity'nin kapanmış olma ihtimali nedeniyle, asenkron bağlamdaki işlemler genellikle hata (`Result`) döndürür. |

### Pencere ve Kullanıcı Girdisi

| Kavram | Basit karşılık | Ne işe yarar? | İlk okurken dikkat |
|---|---|---|---|
| `Window` | Tek pencerenin canlı bağlamı | Klavye odağı, imleç, pencere boyutu, IME, prompt, tıklama alanları, scroll, komut yönlendirme, yenileme ve düşük seviyeli çizim işlerini yönetir. | `App` uygulama geneline bakar; `Window` yalnızca o pencereye ait bilgiyi taşır. |
| `WindowHandle<V>` | Pencereyi sonradan bulmaya yarayan referans | Açılmış pencerenin en üst view'unu doğru Rust tipiyle okumak veya güncellemek amacıyla kullanılır. | Bu değer pencereye ulaşma yoludur; kendi başına çizim yapmaz. Çizim yine kök view'un `Render` çıktısından gelir. |
| `FocusHandle` | Klavye odağı kimliği | Bir view veya element grubunun klavye odağına katılmasını sağlar. `track_focus` ve tab navigasyonu bunun etrafında çalışır. | Element ağacı her çizimde yeniden kurulur; hangi parçanın odakta olduğu bu referans sayesinde takip edilir. |
| `Hitbox` | Mouse ile test edilen alan | Prepaint aşamasında kaydedilen dikdörtgen veya bölge üzerinden hover, tıklama, sürükleme gibi davranışların hedefini belirler. | Görsel olarak çizilmiş olmak tek başına tıklanabilir olmak demek değildir; hitbox gerekir. |
| `ScrollHandle` | Scroll konumunu tutan referans | Bir scroll alanının konumunu ve scroll davranışını ekran kareleri arasında korur. | Scroll konumu kaybolmasın isteniyorsa aynı alan için sabit bir element id'si kullanılır ve `ScrollHandle` uygun yerde saklanır. |
| `Action` | Kullanıcı komutu | Menü, kısayol veya komut paleti üzerinden gelen "kaydet", "sekmeyi kapat", "satırı seç" gibi niyeti temsil eder. | Action "şu tuşa basıldı" değil, "şu komut istendi" bilgisidir. |
| `Keymap` | Kısayol eşleme tablosu | Tuş kombinasyonlarını aktif bağlama göre action'lara bağlar. | Bir tuşa basıldığında GPUI önce klavye odağının hangi element ağacında olduğunu, sonra o ağacın `key_context` etiketlerini dikkate alır. Bu yüzden aynı kısayol editör bağlamında "satırı sil", terminal bağlamında "terminal girdisini temizle" gibi farklı action'lara çözülebilir. |

### Render ve Element Modeli

| Kavram | Basit karşılık | Ne işe yarar? | İlk okurken dikkat |
|---|---|---|---|
| View | Ekran parçasını yöneten Rust tipi | GPUI'de "view" çoğu zaman `Render` trait'ini uygulayan ve `Entity<V>` içinde tutulan bir Rust tipidir. Örneğin bir panelin seçili satırı veya açık menüsü bu tipin alanlarında durabilir. | View ayrı bir widget sınıfı değildir; veriyi tutan Rust tipi ile ekrana çizme metodunun birleşimidir. |
| Kök view | Pencerenin en üst view'u | Bir pencerenin çizim ağacı kök view'dan başlar. Pencere açılırken bu kök genellikle `Entity<V>` olarak oluşur. | Pencerenin ana içeriği kök view'dur; onun altında üretilen elementler her çizimde yeniden kurulur. |
| `Render` | View'u ekrana çeviren metot sözleşmesi | Bir `Entity<V>`'nin ekrana nasıl görüneceğini üretir. `render(&mut self, window, cx)` her çizim döngüsünde element ağacı döndürür. | `Render` trait'ini uygulayan tip genellikle kendi verisini alanlarında tutar ve o veriye göre element üretir. |
| `RenderOnce` | Tek seferlik bileşen tarifi | Kendi kalıcı verisini tutmayan, eldeki veriden element üreten küçük bileşenler için kullanılır. Zed UI bileşenlerinde sıklıkla karşılaşılır. | Nesne tüketilir (`self`); seçili satır, açık menü gibi kalıcı bilgileri tutmak için değil, tekrar kullanılabilir element tarifi yazmak içindir. |
| `IntoElement` | Element'e dönüşebilme | Bir değerin GPUI element ağacına katılabileceğini söyler. `String`, `div()`, Zed UI bileşenleri veya özel bileşenler bu yolla alt öğe olabilir. | Çoğu API `impl IntoElement` alır; bu yüzden farklı görünen birçok şey aynı `.child(...)` çağrısına girebilir. |
| `Element` | Yerleşim ve çizim yapan düğüm | `request_layout`, `prepaint` ve `paint` aşamalarını tanımlar. `div`, `canvas`, `list`, `img`, `svg` gibi hazır elementler bunun uygulamalarıdır. | Element ağacı kalıcı değildir; ekran karesi sonunda düşer ve sonraki çizimde yeniden kurulur. |
| `div()` | Temel kapsayıcı | Flex/grid yerleşimi, boşluk, kenarlık, arka plan, alt öğe ekleme ve interaktif davranışların çoğu burada başlar. | Web'deki `div` gibi düşünmek yardımcıdır, ama GPUI'nin Rust trait zinciriyle çalışır. |
| `Styled` | Stil zinciri | `.flex()`, `.p_2()`, `.bg(...)`, `.text_color(...)`, `.rounded_sm()` gibi stil metotlarını açar. | Stil metotları element tarifi oluşturur; seçili değer veya açık/kapalı durumu gibi kalıcı veri saklamaz. |
| `InteractiveElement` | Etkileşim zinciri | `.on_click(...)`, `.on_mouse_down(...)`, `.on_action(...)`, `.track_focus(...)`, `.key_context(...)` gibi kullanıcı girdisi metotlarını açar. | Bir elementin tıklama, klavye veya komut alabilmesi için ilgili hitbox, focus veya action bağlantısını kurmak gerekir. |
| `Animation` | Zaman tabanlı geçiş | Süre ve easing bilgisiyle değerleri ekran kareleri arasında yumuşak şekilde değiştirir. | Animasyonun devam etmesi için pencerenin yeni ekran karesi istemesi gerekir. |

### Görsel Veri, Ölçü ve Asset

| Kavram | Basit karşılık | Ne işe yarar? | İlk okurken dikkat |
|---|---|---|---|
| `Pixels` | Mantıksal piksel | Boyut, konum, padding ve sınır (`bounds`) değerlerinde kullanılan ana ölçü birimidir. | Fiziksel ekran pikseliyle bire bir aynı olmak zorunda değildir; scale factor devrededir. |
| `Hsla` / `Rgba` | Renk tipleri | UI renklerini HSLA veya RGBA uzayında taşır. | Zed tarafında çoğu renk doğrudan sabit değil, tema üzerinden gelir. |
| `Background` | Dolgu tanımı | Düz renk, gradient veya pattern gibi arka plan dolgularını temsil eder. | Renk ile dolgu aynı şey değildir; dolgu daha geniş bir tariftir. |
| `AssetSource` | Asset byte kaynağı | SVG, image, font veya paketlenmiş dosya gibi varlıkların nereden okunacağını uygulamaya söyler. | Başlangıçta `Application` üzerinde kurulur; elementler asset isterken bu kaynağa dayanır. |

### Hangi Kavramı Ne Zaman Aramak Gerekir?

- "Bu veri ekranda değişince görüntü de değişsin" isteniyorsa `Entity<T>`, `Context<T>` ve `cx.notify()` üçlüsüne bakılması gerekir.
- "Bu iş bir pencerenin klavye odağı, imleci, boyutu veya çizim aşaması ile ilgili" durumlar için `Window` tarafını incelemek faydalıdır.
- "Bu şey ekranda nasıl görünüyor?" sorusunun yanıtı `Render`, `RenderOnce`, `IntoElement`, `Element` ve `Styled` zincirine dayanır.
- "Kullanıcı bir komut verdi" deniyorsa `Action`, `Keymap`, klavye odağı ve `key_context` yapılarını birlikte değerlendirmek önerilir.
- "Asenkron iş bitince hâlâ aynı view var mı?" sorusu `Task<T>`, `WeakEntity<T>` ve `AsyncApp` ile ilgilidir.
- "Bu veri bütün uygulamanın ortak bilgisi mi, yoksa yalnızca tek bir ekran parçasının bilgisi mi?" ayrımı `Global` ile `Entity<T>` arasındaki temel mimari seçimi belirler.

Zed'in `ui` içindeki `Button`, `Icon`, `Label`, `Modal`, `Tooltip` gibi bileşenleri bu çekirdek kavramların üstüne kuruludur. GPUI veri ve durum yönetimi, pencere yapısı, element modeli, kullanıcı girdisi ve çizim altyapısını sunarken; Zed UI ise bu altyapıyı kullanarak ürün içerisinde tekrar edilen hazır arayüz bileşenlerini sağlar.

---
