# Tema Yönetimi

Bu konu, Zed uyumlu bir tema sistemini sıfırdan kurmak için izlenecek yolu bölüm bölüm anlatır. Amaç yalnızca JSON parse eden bir yapı kurmak değildir; lisans sınırları temiz, runtime (çalışma zamanı) davranışı anlaşılır, test edilebilir ve UI tarafından rahat tüketilen bir tema altyapısı oluşturmaktır.

Okuma sırası bilinçli olarak aşağıdaki gibi düzenlenmiştir. Önce kapsam ve lisans sınırı netleşir, ardından proje iskeleti kurulur. GPUI tipleri ve runtime veri modeli anlaşıldıktan sonra JSON sözleşmesi, refinement (zenginleştirme), registry (kayıt defteri), ayar entegrasyonu ve UI tüketimi gelir. Son iki bölüm ise public API ile test ortamını toparlar ve pratik kontrol listesi sunar.

## Bölümler

1. [Hedef, Kapsam ve Lisans](01-hedef-kapsam-ve-lisans.md) — Tema sisteminin neyi mirror (yansıtma) edeceğini, hangi katmanda özgür davranılacağını ve GPL sınırının nereden geçtiğini açıklar.

2. [Proje İskeleti ve Bağımlılıklar](02-proje-iskeleti-ve-bagimliliklar.md) — `kvs_tema` ve `kvs_syntax_tema` ayrımını, klasör yerleşimini ve bağımlılık (dependency) kararlarını toplar.

3. [GPUI'nin Tema için Kullanılan Yüzeyi](03-gpui-tema-yuzeyi.md) — `Hsla`, `SharedString`, `HighlightStyle`, pencere görünümü, global state ve `Refineable` gibi temel GPUI tiplerini anlatır.

4. [Runtime Veri Modeli](04-runtime-veri-modeli.md) — `Theme`, `ThemeColors`, `StatusColors`, player/accent renkleri, syntax tema ve icon tema modelleri kurulur.

5. [JSON Sözleşmesi ve Parse Katmanı](05-json-sozlesmesi-ve-parse-katmani.md) — Zed tema JSON'larının serde ile nasıl okunacağını, opsiyonellik kuralını ve hata toleransını açıklar.

6. [Fallback, Varlık ve Fixture Tabanı](06-fallback-varlik-ve-fixture-tabani.md) — Lisans-temiz fallback tema tasarımını, asset bundling (varlık paketleme) seçeneklerini ve test fixture düzenini ele alır.

7. [Refinement ve Tema Üretimi](07-refinement-ve-tema-uretimi.md) — `Content -> Refinement -> Theme` akışını, default türetme kurallarını ve `Theme::from_content` sırasını anlatır.

8. [Runtime Kuruluşu ve Tema Seçimi](08-runtime-kurulusu-ve-tema-secimi.md) — `ThemeRegistry`, `GlobalTheme`, `SystemAppearance`, `init`, `LoadThemes` ve `cx.refresh_windows()` akışını açıklar.

9. [Ayarlar ve Yoğunluk Entegrasyonu](09-ayarlar-ve-yogunluk-entegrasyonu.md) — Tema seçim ayarlarını, provider sınırını, font override davranışını ve `UiDensity` sözleşmesi kurulur.

10. [UI Tüketimi ve Etkileşim Renkleri](10-ui-tuketimi-ve-etkilesim-renkleri.md) — Bileşenlerin `cx.theme()` ile tema okumasını ve hover/active/disabled gibi etkileşim renklerini nasıl seçeceğini gösterir.

11. [Dış API ve Test Ortamı](11-dis-api-ve-test-ortami.md) — Dışa açık API sınırını, crate-içi kalması gereken parçaları ve test ortamında tema mock'lama stratejilerini toplar.

12. [Pratik Kontrol Listesi](12-pratik-kontrol-listesi.md) — Yaygın dikkat noktalarını, mirror kararlarını ve son kontrol listesini kısa maddeler halinde verir.

## Okuma Önerisi

İlk kez okuyorsanız 1-8 arası bölümleri sırayla takip etmek en sağlıklı yoldur. Mevcut bir uygulamaya tema sistemi ekliyorsanız 1, 2, 5, 7 ve 8. bölümler önce okunmalıdır. UI bileşenleri yazıyorsanız 10. bölüm doğrudan pratik ihtiyaçlara cevap verir. Test veya dışa açık API sınırı üzerinde çalışıyorsanız 11 ve 12. bölümler kontrol noktası olarak kullanılabilir.
