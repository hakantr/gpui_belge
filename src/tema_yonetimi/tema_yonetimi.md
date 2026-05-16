# Tema yönetimi

Bu konu, Zed uyumlu bir tema sistemini sıfırdan kurmak için izlenecek yolu
bölüm bölüm anlatır. Amaç yalnızca JSON parse eden bir yapı kurmak değildir;
lisans sınırları temiz, runtime davranışı anlaşılır, test edilebilir ve UI
tarafından rahat tüketilen bir tema altyapısı oluşturmaktır.

Okuma sırası bilinçli olarak aşağıdaki gibi düzenlenmiştir. Önce kapsam ve
lisans sınırı netleşir, sonra proje iskeleti kurulur. GPUI tipleri ve runtime
veri modeli anlaşıldıktan sonra JSON sözleşmesi, refinement, registry,
settings entegrasyonu ve UI tüketimi gelir. Son iki bölüm ise public API ile
test ortamını toparlar ve pratik kontrol listesi sunar.

## Bölümler

1. [Hedef, kapsam ve lisans](01-hedef-kapsam-ve-lisans.md)
   Tema sisteminin neyi mirror edeceğini, hangi katmanda özgür davranılacağını
   ve GPL sınırının nereden geçtiğini açıklar.

2. [Proje iskeleti ve bağımlılıklar](02-proje-iskeleti-ve-bagimliliklar.md)
   `kvs_tema` ve `kvs_syntax_tema` ayrımını, klasör yerleşimini ve dependency
   kararlarını toplar.

3. [GPUI'nin tema için kullanılan yüzeyi](03-gpui-tema-yuzeyi.md)
   `Hsla`, `SharedString`, `HighlightStyle`, pencere görünümü, global state ve
   `Refineable` gibi temel GPUI tiplerini anlatır.

4. [Runtime veri modeli](04-runtime-veri-modeli.md)
   `Theme`, `ThemeColors`, `StatusColors`, player/accent renkleri, syntax tema
   ve icon tema modelini kurar.

5. [JSON sözleşmesi ve parse katmanı](05-json-sozlesmesi-ve-parse-katmani.md)
   Zed tema JSON'larının serde ile nasıl okunacağını, opsiyonellik kuralını ve
   hata toleransını açıklar.

6. [Fallback, varlık ve fixture tabanı](06-fallback-varlik-ve-fixture-tabani.md)
   Lisans-temiz fallback tema tasarımını, asset bundling seçeneklerini ve test
   fixture düzenini ele alır.

7. [Refinement ve tema üretimi](07-refinement-ve-tema-uretimi.md)
   `Content -> Refinement -> Theme` akışını, default türetme kurallarını ve
   `Theme::from_content` sırasını anlatır.

8. [Runtime kuruluşu ve tema seçimi](08-runtime-kurulusu-ve-tema-secimi.md)
   `ThemeRegistry`, `GlobalTheme`, `SystemAppearance`, `init`, `LoadThemes` ve
   `cx.refresh_windows()` akışını açıklar.

9. [Settings ve yoğunluk entegrasyonu](09-settings-ve-yogunluk-entegrasyonu.md)
   Tema seçim ayarlarını, provider sınırını, font override davranışını ve
   `UiDensity` sözleşmesini kurar.

10. [UI tüketimi ve etkileşim renkleri](10-ui-tuketimi-ve-etkilesim-renkleri.md)
    Bileşenlerin `cx.theme()` ile tema okumasını ve hover/active/disabled gibi
    etkileşim renklerini nasıl seçeceğini gösterir.

11. [Dış API ve test ortamı](11-dis-api-ve-test-ortami.md)
    Public API sınırını, crate-içi kalması gereken parçaları ve test ortamında
    tema mock'lama stratejilerini toplar.

12. [Pratik kontrol listesi](12-pratik-kontrol-listesi.md)
    Yaygın tuzakları, mirror kararlarını ve son kontrol listesini kısa
    maddeler halinde verir.

## Okuma önerisi

İlk kez okuyorsan 1-8 arası bölümleri sırayla takip etmek en sağlıklı yoldur.
Mevcut bir uygulamaya tema sistemi ekliyorsan 1, 2, 5, 7 ve 8. bölümler önce
okunmalıdır. UI bileşenleri yazıyorsan 10. bölüm doğrudan pratik ihtiyaçlara
cevap verir. Test veya public API sınırı üzerinde çalışıyorsan 11 ve 12.
bölümler kontrol noktası olarak kullanılabilir.
