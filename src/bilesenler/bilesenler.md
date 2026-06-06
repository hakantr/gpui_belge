# Bileşenler

Bu bölüm, mevcut Zed `ui` katmanındaki bileşenleri GPUI temeliyle birlikte anlatır. Amaç yalnızca hangi bileşenin hangi constructor ile üretildiğini listelemek değildir. Bir ekranda hangi parçanın neden seçildiğini, durumun nerede tutulduğunu ve kullanıcı etkileşiminden sonra render'ın nasıl güncellendiğini anlaşılır hale getirmek de amaçlanır.

Belgeleri sırayla okumak en rahat yoldur. İlk bölümler ortak kavramları, layout'u, metni, ikonları ve butonları kurar. Sonraki bölümlerde form kontrolleri, menüler, listeler, tablolar, feedback bileşenleri ve daha özel AI ve collaboration yüzeyleri anlatılır. En sonda da bu parçaların gerçek ekran iskeletlerinde nasıl bir araya geldiğini gösteren örnekler bulunur.

Okurken şu ayrımı akılda tutmak işini kolaylaştırır:

- GPUI primitive'leri `div()`, `Render`, `RenderOnce`, `ParentElement`, `Styled`, event handler'lar ve sanal liste gibi temel mekanikleri sağlar.
- Zed `ui` bileşenleri bu temel üstüne daha dar, daha tutarlı ve tema ile uyumlu bir tasarım sistemi kurar.
- Hazır bir Zed bileşeni ihtiyacını karşılıyorsa önce onu kullanırsın. Ham GPUI primitive'lerine genellikle özel layout, özel çizim, sanallaştırma veya hazır bileşenin kapsamadığı bir etkileşim gerektiğinde inersin.
- Bileşenlerin çoğu değeri kendi içinde saklamaz. Seçili satır, açık menü, pending task, hata mesajı veya ilerleme gibi bilgiler view durumunda durur; bileşen render sırasında bu bilgiyi alır ve ekrana yansıtır.
- Kullanıcının gördüğü bir durum değiştiğinde `cx.notify()` çağrısı yaparsın. Aksi halde model güncellense bile ekrandaki görünüm aynı kalabilir.

Bu rehberdeki örnekler kısa tutulsa da yalnızca "çalışan kod parçası" vermek için yazılmadı. Her bölümde ne zaman kullanırsın, ne zaman kullanılmaz, temel API, davranış ve dikkat edeceğin noktalar ayrı ayrı verirsin. Böylece hem doğru bileşeni seçebilirsin hem de o bileşeni Zed'in beklediği kullanım disipliniyle ekrana yerleştirebilirsin.
