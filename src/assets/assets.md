# Varlık yönetimi

Bu konu, Zed uygulamasındaki varlık altyapısının nasıl kurulduğunu ve uygulamaya nasıl bağlandığını bölüm bölüm açıklar. Amaç sadece `RustEmbed` ile bir klasörü paketlemekle sınırlı değildir. Font, ikon, görsel, ses, prompt şablonu, tema JSON'u ve klavye haritası gibi farklı varlık türleri tek bir `AssetSource` sözleşmesi üzerinden akar. Bölümün temel odağı; bu sözleşmenin GPUI çalışma zamanına, SVG render hattına, ses hattına ve ayar/tema sistemine nasıl entegre edildiğini netleştirmektir. `RustEmbed` yapısı release derlemelerinde gömülü byte üretirken, normal debug derlemelerinde aynı API ile dosya sisteminden dinamik okuma yapabildiğinden her iki davranış modeli de ayrıntılı olarak ele alınmaktadır.

Okuma sırası bilinçli olarak belirli bir mantık çerçevesinde düzenlenmiştir. Öncelikle kapsam ve klasör topolojisi netleştirilir, ardından `AssetSource` sözleşmesi ile `RustEmbed` entegrasyonu kurgulanır. Bu temel yapı oturduktan sonra font, ikon, görsel ve ses gibi binary varlıkların tüketim yolları sırasıyla ele alınır. Son bölümler ise JSON tabanlı varlıkları (tema, keymap, settings, badge) ve test/headless ortamlardaki alternatif ikame stratejilerini özetler.

## Bölümler

1. [Hedef, kapsam, lisans ve klasör topolojisi](01-hedef-kapsam-lisans-ve-topoloji.md) Varlık altyapısının neyi kapsadığını ve hangi klasörlerin hangi tüketici tarafından okunduğunu açıklar. GPL sınırını ve dosya yerleşimi kararlarını da netleştirir.

2. [AssetSource sözleşmesi ve RustEmbed entegrasyonu](02-asset-source-ve-rust-embed.md) GPUI'nin `AssetSource` trait'ini, `RustEmbed` derive macro'sunu, `Application::with_assets` zincirini ve list/load davranışını anlatır.

3. [Fontların paketlenmesi ve yüklenmesi](03-font-yukleme.md) Gömülü font dosyalarının `load_embedded_fonts` ile `TextSystem`'e nasıl aktarıldığını, USVG fontdb'sine eklendiğini ve generic family çözümleme kuralını açıklar.

4. [İkon sistemi ve SVG render hattı](04-icon-ve-svg-sistemi.md) `IconName` registry'sini, `Icon` bileşeninin embedded/external/raster ayrımını, `svg()` element'ini, knockout ikonlarını ve `SvgRenderer` davranışını ele alır.

5. [Görsel ve raster varlık akışı](05-image-ve-raster-varlik.md) `images/` klasörünü, `VectorName` registry'sini, `img()` element'ini, `Resource` enum'unu, `ImageAssetLoader` ve `Asset` trait'inin asenkron yükleme modelini gösterir.

6. [Ses ve diğer binary varlıklar](06-sound-ve-binary-varlik.md) `sounds/` klasöründeki WAV dosyalarının `Audio::play_sound` üzerinden tüketini, `Sound` enum eşlemesini ve source cache davranışını açıklar. `prompts/` klasöründeki Handlebars şablonlarının handlebars motoruna nasıl kaydedildiğini de gösterir.

7. [JSON varlıkları: tema, keymap, settings, badge](07-json-varlik-akisi.md) Tema JSON'larının `load_bundled_themes` üzerinden registry'ye nasıl aktığını açıklar. `SettingsAssets`'in keymap ve settings dosyalarını `asset_str` ile nasıl okuduğunu ve `badge/` klasörünün uygulama dışı kullanım amacını da toplar.

8. [Test, headless ve dış asset kaynakları](08-test-headless-ve-dis-asset.md) `()` boş `AssetSource` davranışını, `TestApp::with_text_system_and_assets` yolunu, `load_test_fonts` yardımını ve filesystem'den dış SVG/path yüklemenin nasıl yapıldığını gösterir.

9. [Pratik kontrol listesi](09-pratik-kontrol-listesi.md) Yaygın dikkat noktalarını (eksik `#[include]`, MIME karışıklığı, knockout eşleşmesi, kullanılmayan asset şişmesi vb.), build davranışını ve son kontrol listesini kısa maddeler halinde verir.

## Okuma önerisi

İlk defa okuyacak olanlar için 1-4 arası bölümlerin sırayla takip edilmesi önerilir; nitekim varlık altyapısının temeli bu bölümlerde kurulur. Mevcut bir uygulamaya yalnızca ikon eklemek isteyen bir geliştirici için 1, 2 ve 4. bölümler yeterli bir rehberlik sunar. Ses veya görsel hatları inşa ediliyorsa 5 ve 6. bölümler doğrudan pratik uygulamalar barındırır. Tema ve keymap entegrasyonu için 7. bölüm, headless test ortamları için ise 8. bölüm referans olarak kullanılabilir. 9. bölüm ise, uygulamanın ilk varlık entegrasyonu tamamlandıktan sonra olası sapma noktalarını yakalamak üzere tasarlanmış son kontrol listesidir.
