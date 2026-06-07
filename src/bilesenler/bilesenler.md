# Bileşenler

Bu bölüm, mevcut Zed `ui` katmanındaki bileşenleri GPUI temeliyle birlikte anlatır. Amaç yalnızca hangi bileşenin hangi constructor ile üretildiğini listelemek değildir. Bir ekranda hangi parçanın neden seçildiğini, durumun nerede tutulduğunu ve kullanıcı etkileşiminden sonra render'ın nasıl güncellendiğini anlaşılır hale getirmek de hedeflenir.

Belgeleri sırayla okumak en rahat yoldur. İlk bölümler ortak kavramları, layout'u, metni, ikonları ve butonları kurar. Sonraki bölümlerde form kontrolleri, menüler, listeler, tablolar, feedback bileşenleri ve daha özel AI ve collaboration yüzeyleri anlatılır. En sonda da bu parçaların gerçek ekran iskeletlerinde nasıl bir araya geldiğini gösteren örnekler bulunur.

Okurken şu ayrımı akılda tutmak süreci kolaylaştıracaktır:

- GPUI primitive'leri `div()`, `Render`, `RenderOnce`, `ParentElement`, `Styled`, event handler'lar ve sanal liste gibi temel mekanikleri sağlar.
- Zed `ui` bileşenleri bu temel üstüne daha dar, daha tutarlı ve tema ile uyumlu bir tasarım sistemi kurar.
- Hazır bir Zed bileşeni ihtiyacını karşılıyorsa öncelikle onu kullanmayı tercih etmek önerilir. Ham GPUI primitive'lerine genellikle özel düzen (layout), özel çizim, sanallaştırma veya hazır bileşenin kapsamadığı bir etkileşim gerektiğinde başvurulması gerekir.
- Bileşenlerin çoğu değeri kendi içinde saklamaz. Seçili satır, açık menü, pending task, hata mesajı veya ilerleme gibi bilgiler view durumunda durur; bileşen render sırasında bu bilgiyi alır ve ekrana yansıtır.
- Kullanıcının gördüğü bir durum değiştiğinde `cx.notify()` çağrısı yapılması gerekir. Aksi halde model güncellense bile ekrandaki görünümün eski kalması olasıdır.

Bu rehberdeki örnekler kısa tutulsa da yalnızca "çalışan kod parçası" sunmak amacıyla yazılmamıştır. Her bölümde bileşenin ne zaman kullanılacağı, ne zaman tercih edilmemesi gerektiği, temel API yapısı, davranış özellikleri ve dikkat edilmesi gereken noktalar ayrıntılı bir biçimde açıklanır. Böylece doğru bileşeni seçerek ilgili bileşeni Zed'in beklediği kullanım disipliniyle ekrana yerleştirmek mümkün olur.
