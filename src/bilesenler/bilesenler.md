# Bileşenler

Bu bölüm, Zed'in `ui` katmanındaki bileşenleri GPUI temeliyle birlikte
anlatır. Amaç yalnızca hangi component'in hangi constructor ile üretildiğini
listelemek değil; bir ekranda hangi parçanın neden seçildiğini, state'in nerede
tutulduğunu ve kullanıcı etkileşiminden sonra render'ın nasıl güncellendiğini
anlaşılır hale getirmektir.

Belgeleri sırayla okumak en rahat yoldur. İlk bölümler ortak kavramları,
layout'u, metni, ikonları ve butonları kurar. Sonraki bölümlerde form
kontrolleri, menüler, listeler, tablolar, feedback bileşenleri ve daha özel AI
ve collaboration yüzeyleri anlatılır. En sonda da bu parçaların gerçek ekran
iskeletlerinde nasıl bir araya geldiğini gösteren örnekler ve API envanterleri
bulunur.

Okurken şu ayrımı akılda tutmak işinizi kolaylaştırır:

- GPUI primitive'leri `div()`, `Render`, `RenderOnce`, `ParentElement`,
  `Styled`, event handler'lar ve sanal liste gibi temel mekanikleri sağlar.
- Zed `ui` bileşenleri bu temel üstüne daha dar, daha tutarlı ve tema ile
  uyumlu bir tasarım sistemi kurar.
- Hazır bir Zed bileşeni ihtiyacı karşılıyorsa önce o kullanılır. Ham GPUI
  primitive'lerine genellikle özel layout, özel çizim, sanallaştırma veya hazır
  bileşenin kapsamadığı bir etkileşim gerektiğinde inilir.
- Bileşenlerin çoğu değeri kendi içinde saklamaz. Seçili satır, açık menü,
  pending task, hata mesajı veya progress gibi bilgiler view state'inde durur;
  component render sırasında bu bilgiyi alır ve ekrana yansıtır.
- Kullanıcının gördüğü bir state değiştiğinde `cx.notify()` çağrısı yapılır.
  Aksi halde model güncellense bile ekrandaki görünüm aynı kalabilir.

Bu rehberdeki örnekler kısa tutulsa da yalnızca "çalışan kod parçası" vermek
için yazılmadı. Her bölümde ne zaman kullanılır, ne zaman kullanılmaz, temel
API, davranış ve dikkat edilecek noktalar ayrı ayrı verilir. Böylece okuyucu
hem doğru bileşeni seçebilir hem de o bileşeni Zed'in beklediği kullanım
disipliniyle ekrana yerleştirebilir.
