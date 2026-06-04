# Platform Üst Barı

Bu rehber, Zed'in `platform_title_bar` crate'ini, yani platforma özgü pencere kabuğunu GPUI tabanlı bir uygulamaya lisans-temiz biçimde taşımak için hazırlanmıştır. Konu yalnızca "ekrana bir başlık çubuğu çizmek" değildir. Pencerenin sürüklenmesi, Linux ve Windows pencere butonları, macOS trafik ışıkları, yerel pencere sekmeleri, yan panel çakışmaları, tema renkleri ve uygulamanın kapat/yeni-pencere gibi iş kuralları birlikte düşünülür.

> **Kapsam ayrımı.** `platform_title_bar` yalnız platform kabuğunu (sürükleme alanı, pencere kontrolleri, yerel sekmeler) sağlar; `gpui`, `theme` ve `settings` dışında ağır bir bağımlılığı yoktur. Zed'in kullanıcıya görünen *ürün* başlık çubuğu ise ayrı bir crate olan `title_bar` tarafından bu kabuğun üstüne kurulur (uygulama menüsü, proje/kullanıcı menüleri, işbirliği, plan çipi, güncelleme bildirimi, ilk karşılama duyuru bandı). Ürün katmanı [Üst Bar](../ust_bar/ust_bar.md) bölümünde işlenir; bu bölüm yalnız platform kabuğunu anlatır.

Okuma sırası özellikle önemlidir. İlk bölümler sınırları koyar: neyin platform kabuğuna, neyin ürün başlığına, neyin uygulama durumuna ait olduğunu anlatır. Orta bölümler gerçek render akışına ve platform farklarına iner. Son bölümler ise port sırasında bakılacak kontrol listelerini, sık hataları ve kaynak doğrulama komutlarını toplar.

Bu belgede amaç içeriği kısaltmak değil, konunun okuyucuya yorulmadan geçmesini sağlamaktır. Bu yüzden her bölümde aynı ayrım korunur: önce kararın nedeni anlatılır, sonra ilgili API veya kaynak noktası gösterilir, en sonda da port sırasında kaçırılabilecek ayrıntılar işaretlenir.

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
