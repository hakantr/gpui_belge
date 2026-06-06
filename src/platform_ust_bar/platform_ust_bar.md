# Platform Üst Barı

Bu rehber, Zed'in `platform_title_bar` crate'ini, yani platforma özgü pencere kabuğunu GPUI tabanlı bir uygulamaya lisans kurallarına uygun şekilde taşımak amacıyla hazırlanmıştır. Süreç yalnızca ekrana basit bir başlık çubuğu çizmekten ibaret değildir; pencerenin sürüklenmesi, Linux ve Windows pencere butonları, macOS trafik ışıkları, yerel pencere sekmeleri, yan panel çakışmaları, tema renkleri ve uygulamanın kapatma veya yeni pencere açma gibi iş kuralları bir bütün olarak ele alınır.

> **Kapsam Ayrımı:** `platform_title_bar` ekranda platform kabuğunu (sürükleme alanı, pencere kontrolleri, yerel sekmeler) sağlar. Zed bünyesindeki asıl crate; `workspace`, `project`, `zed_actions`, `ui`, `settings` ve `theme` gibi daha üst seviye Zed katmanlarına da bağımlıdır. Bu rehberin ana hedefi, gözlemlenebilir platform davranışını kendi uygulamanda daha dar kapsamlı bir denetleyici (controller) sözleşmesine taşımaktır. Zed'in kullanıcıya görünen *ürün* başlık çubuğu ise ayrı bir crate olan `title_bar` tarafından bu kabuğun üstüne inşa edilir (uygulama menüsü, proje/kullanıcı menüleri, işbirliği arayüzü, plan göstergesi, güncelleme bildirimi, ilk karşılama duyuru bandı). Ürün katmanı [Üst Bar](../ust_bar/ust_bar.md) bölümünde işlenir; bu bölüm ise yalnızca platform kabuğuna odaklanır.

Okuma sırası özellikle önemlidir. İlk bölümler sınırları netleştirir: Neyin platform kabuğuna, neyin ürün başlığına, neyin uygulama durumuna ait olduğunu açıklar. Orta bölümler gerçek render akışına ve platformlar arası farklılıklara odaklanır. Son bölümler ise taşıma (porting) sürecinde göz önünde bulundurulması gereken kontrol listelerini, dikkat isteyen kullanımları ve kaynak doğrulama adımlarını bir araya getirir.

Bu belgede amaç içeriği kısaltmak değil, konunun okuyucuya en anlaşılır şekilde aktarılmasını sağlamaktır. Bu yüzden her bölümde aynı ayrım korunur: Önce kararın nedeni açıklanır, sonra ilgili API veya kaynak noktası gösterilir, en sonunda da port süreci sırasında dikkat edilmesi gereken ayrıntılar işaretlenir.

## Bölümler

1. [Hedef, kapsam ve lisans](01-hedef-kapsam-ve-lisans.md)
2. [Zed kaynak haritası ve bağlantı modeli](02-zed-kaynak-haritasi-ve-baglanti-modeli.md)
3. [Proje iskeleti ve bağımlılıklar](03-proje-iskeleti-ve-bagimliliklar.md)
4. [Entegrasyon başlangıcı ve uygulama sözleşmesi](04-entegrasyon-baslangici-ve-uygulama-sozlesmesi.md)
5. [Platform başlık çubuğu render akışı ve pencere kontrolleri](05-platform-titlebar-render-akisi-ve-pencere-kontrolleri.md)
6. [Yerel pencere sekmeleri](06-native-pencere-sekmeleri.md)
7. [Ürün başlık çubuğu ve uygulamaya bağlama](07-urun-titlebari-ve-uygulamaya-baglama.md)
8. [Pratik uygulama](08-pratik-uygulama.md)
9. [Referans ve doğrulama](09-referans-ve-dogrulama.md)
