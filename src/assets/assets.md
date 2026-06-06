# Varlık yönetimi

Bu konu, Zed uygulamasındaki varlık altyapısının nasıl kurulduğunu ve uygulamaya nasıl bağlandığını bölüm bölüm anlatır. Amaç sadece `RustEmbed` ile bir klasörü paketlemek değildir. Font, ikon, görsel, ses, prompt şablonu, tema JSON'u ve klavye haritası gibi farklı varlık türleri tek bir `AssetSource` sözleşmesi üzerinden akar. Bölümün odağı, bu sözleşmenin GPUI çalışma zamanına, SVG render hattına, ses hattına ve ayar/tema sistemine nasıl bağlandığını netleştirmektir. `RustEmbed` release build'de gömülü byte üretirken normal debug build'de aynı API ile dosya sisteminden okuma yapabildiği için iki davranış da ayrıca belirtilir.

Okuma sırası bilinçli olarak aşağıdaki gibi düzenlenmiştir. Önce kapsam ve klasör topolojisi netleşir, sonra `AssetSource` sözleşmesi ile `RustEmbed` entegrasyonu kurarsın. Bu temel oturduktan sonra font, ikon, görsel ve ses gibi binary varlıkların tüketim yolları sırayla işlersin. Son bölümler JSON tabanlı varlıkları (tema, keymap, settings, badge) ve test/headless ortamlardaki ikame stratejilerini toparlar.

## Bölümler

1. [Hedef, kapsam, lisans ve klasör topolojisi](01-hedef-kapsam-lisans-ve-topoloji.md) Varlık altyapısının neyi kapsadığını ve hangi klasörlerin hangi tüketici tarafından okunduğunu açıklar. GPL sınırını ve dosya yerleşimi kararlarını da netleştirir.

2. [AssetSource sözleşmesi ve RustEmbed entegrasyonu](02-asset-source-ve-rust-embed.md) GPUI'nin `AssetSource` trait'ini, `RustEmbed` derive macro'sunu, `Application::with_assets` zincirini ve list/load davranışını anlatır.

3. [Fontların paketlenmesi ve yüklenmesi](03-font-yukleme.md) Gömülü font dosyalarının `load_embedded_fonts` ile `TextSystem`'e nasıl aktarıldığını, USVG fontdb'sine eklendiğini ve generic family çözümleme kuralını açıklar.

4. [İkon sistemi ve SVG render hattı](04-icon-ve-svg-sistemi.md) `IconName` registry'sini, `Icon` bileşeninin embedded/external/raster ayrımını, `svg()` element'ini, knockout ikonlarını ve `SvgRenderer` davranışını ele alır.

5. [Görsel ve raster varlık akışı](05-image-ve-raster-varlik.md) `images/` klasörünü, `VectorName` registry'sini, `img()` element'ini, `Resource` enum'unu, `ImageAssetLoader` ve `Asset` trait'inin asenkron yükleme modelini gösterir.

6. [Ses ve diğer binary varlıklar](06-sound-ve-binary-varlik.md) `sounds/` klasöründeki WAV dosyalarının `Audio::play_sound` üzerinden tüketimini, `Sound` enum eşlemesini ve source cache davranışını açıklar. `prompts/` klasöründeki Handlebars şablonlarının handlebars motoruna nasıl kaydedildiğini de gösterir.

7. [JSON varlıkları: tema, keymap, settings, badge](07-json-varlik-akisi.md) Tema JSON'larının `load_bundled_themes` üzerinden registry'ye nasıl aktığını açıklar. `SettingsAssets`'in keymap ve settings dosyalarını `asset_str` ile nasıl okuduğunu ve `badge/` klasörünün uygulama dışı kullanım amacını da toplar.

8. [Test, headless ve dış asset kaynakları](08-test-headless-ve-dis-asset.md) `()` boş `AssetSource` davranışını, `TestApp::with_text_system_and_assets` yolunu, `load_test_fonts` yardımını ve filesystem'den dış SVG/path yüklemenin nasıl yapıldığını gösterir.

9. [Pratik kontrol listesi](09-pratik-kontrol-listesi.md) Yaygın dikkat noktalarını (eksik `#[include]`, MIME karışıklığı, knockout eşleşmesi, kullanılmayan asset şişmesi vb.), build davranışını ve son kontrol listesini kısa maddeler halinde verir.

## Okuma önerisi

İlk kez okuyan biri için 1-4 arası bölümler sıralı izlenmelidir; çünkü varlık altyapısının temeli bu bölümlerde oturur. Mevcut bir uygulamaya yalnızca ikon eklemek isteyen okuyucu için 1, 2 ve 4. bölümler yeterlidir. Ses veya görsel hattı kuruluyorsa 5 ve 6. bölümler doğrudan pratik karşılığa sahiptir. Tema ve keymap entegrasyonu için 7. bölüm, headless test ortamı için 8. bölüm referans olarak kullanabilirsin. 9. bölüm uygulamanın ilk varlık entegrasyonu tamamlandıktan sonra sapma noktalarını yakalamak için son kontrol noktasıdır.
