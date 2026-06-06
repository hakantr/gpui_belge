# Pratik kontrol listesi

Bu bölüm, önceki bölümlerde sunulan açıklamaların özünü tek bir odak noktasında bir araya getirir. Varlık altyapısını kurarken, genişletirken veya olası bir sorunu çözmeye çalışırken dikkat edilmesi gereken kritik detayları kısa maddeler halinde inceleyebilirsin. Tipik karar noktaları ve son kontrol adımları da aynı başlık altında yer alır. Temel amaç, rehberin tamamını sıfırdan okumaya gerek kalmadan hızlıca başvurulabilecek pratik bir referans özeti sunmaktır.

---

## 1. Kuruluş sırasında dikkat edilecekler

Varlık hattı, uygulamanın başlatılma (bootstrap) akışında belirli ve katı bağımlılıklara sahiptir. Zed'in `main.rs` dosyasındaki gerçek kuruluş sırası genel olarak şu şekildedir: Varlık kaynağı en başta sisteme tanıtılır, ardından ayarlar (`settings`) yüklenir, tema sistemi ise ayarlar ve eklenti (extension) altyapısının kurulmasının ardından devreye girer. Prompt şablonları daha sonra Handlebars şablon motoruna kaydedilir. Font yükleme işlemleri ise pencere henüz oluşturulmadan ve `Editor`/`Workspace` ilklemelerinden hemen önce gerçekleştirilir. Dolayısıyla, tek doğru yaklaşım aşağıdaki sıralama olmamakla birlikte, bu bağımlılık ilişkilerinin korunması zorunludur:

1. **`Application::with_platform(...).with_assets(Assets)`** — Varlık kaynağı `App` bağlamına bağlanır. Bu çağrı yapılmadığı takdirde `cx.asset_source()` metodu boş bir `()` (birim tipi) döner ve `list` ile `load` çağrıları herhangi bir sonuç vermez.
2. **`settings::init(cx)`** — `SettingsStore` yapısı `default_settings()` çıktısı kullanılarak kurulur. `asset_str::<SettingsAssets>("settings/default.json")` çağrısı bu aşamada fail-fast (erken hata veren) paketleme sözleşmesine bağlıdır; ilgili dosya ikili dosya (binary) içerisine gömülmemişse uygulama başlatılamaz.
3. **`theme_settings::init(LoadThemes::All(Box::new(Assets)), cx)`** — Tema sistemi kurulur, `ThemeRegistry` yapısı küresel (global) duruma yerleştirilir ve gömülü temaların yükleme işlemi başlatılır. Ayar durumlarına bağlı çalışan tema seçiminin hatasız gerçekleşmesi için `settings::init` çağrısının bu adımdan önce tamamlanmış olması gerekir.
4. **`PromptBuilder::load(fs, ..., cx)`** — Prompt şablonları Handlebars motoruna kaydedilir. Dosya sistemi izleyicisi (file system watcher) arka planda geçersiz kılma (override) dizinini izlemeye başlar.
5. **`load_embedded_fonts(cx)` (veya `Assets.load_fonts(cx)`)** — `TextSystem` üzerine gömülü fontlar yüklenir. Bu işlemin mutlaka pencere açılmadan **önce** gerçekleştirilmesi gerekir; aksi takdirde ilk çizim karesinde (frame) fontlar yedek sisteme (fallback) düşer.
6. **`cx.open_window(...)`** — Pencere açıldıktan sonra kullanıcı arayüzü (UI) render hattı SVG ikonlarını okumaya başlar. Bu aşamada varlık hattının önceki adımlarının tamamlanmış olması beklenir.

**Kontrol:** Uygulama başarıyla çalıştığı halde ikonlar ekranda görünmüyorsa `with_assets` bağlantısını doğrulamalısın. Fontlar beklenen aileyle render edilmiyorsa, `load_embedded_fonts` çağrısının pencere açılmadan **önce** yapıldığından emin olman gerekir.

---

## 2. RustEmbed kalıplarını tutarlı tutmak

`#[include]` ve `#[exclude]` direktifleri paketleme işlemine dahil edilecek dosya kümesini belirler. `release` veya `debug-embed` modunda içerikler ikili dosya (binary) içerisine gömülürken, normal `debug` modunda aynı eşleşme kuralları dosya sisteminden dinamik okuma yapmak için kullanılır. Bu süreçte dikkat edilmesi gereken kritik noktalar şunlardır:

- **Exclude (Hariç Tutma) Önceliklidir:** `RustEmbed` include ve exclude kalıplarını `globset` kütüphanesi vasıtasıyla ayrı kümeler halinde değerlendirir. Herhangi bir exclude eşleşmesi, include kurallarını doğrudan ezer. Direktiflerin yazılış sırası 'ilk eşleşen kazanır' mantığına göre çalışmaz.
- **Glob Kalıplarına Dikkat Edin:** `RustEmbed` tarafından kullanılan `globset::Glob::new` yapısı, varsayılan ayarlarında `*` karakterinin yol ayırıcılarını da eşlemesine izin verebilir. Zed bünyesindeki `#[include = "keymaps/*"]` kalıbının platform alt dizinlerini de kapsayabilmesi bu sayede mümkün olur. Yine de yeni yazılacak özyinelemeli (recursive) kurallarda `**/*` kalıbının tercih edilmesi, geliştiricinin niyetini daha net yansıtır.
- **`*.DS_Store` Dosyalarını Hariç Tutmak:** macOS Finder penceresi bu gizli dosyaları otomatik olarak üretir. Eğer include kalıbı çok geniş tutulursa, bu gereksiz dosyalar ikili dosya (binary) içerisine sızabilir.
- **Derleme Önbelleği (Cache) Geçersiz Kılma Sorunu:** `RustEmbed` yapısının dosya değişikliklerini izleyemediği uç durumlarda, eski varlık içerikleri ikili dosya içinde kalabilir. Belirgin bir varlık değişikliği yapılmasına rağmen beklenen güncel durum gözlemlenemiyorsa, `cargo clean -p assets` (veya ilgili crate ismiyle) komutunu çalıştırarak önbelleği temizlemen gerekir.

**Kontrol:** Yeni bir varlık eklendiği halde çalışma zamanında (runtime) erişilemiyorsa sırasıyla şu üç adımı doğrulaman gerekir: (a) Dosya `assets/` dizini altında doğru konumda mı? (b) `RustEmbed` include kalıbı bu hedef klasörü kapsıyor mu? (c) İlgili crate yeniden derlendi mi?

**Eksik Yol Davranışı:** `Assets::load` metodu, eksik veya bulunamayan bir dosya için `Ok(None)` değeri dönmez; bunun yerine yüklenemeyen dosya yolunu bağlam (context) bilgisine ekleyen ayrıntılı bir hata üretir. `Ok(None)` davranışı yalnızca boş `()` varlık kaynağı veya bunu özel olarak tercih eden özelleştirilmiş `AssetSource` uygulamaları için geçerlidir. Log kayıtlarında bu tür bir varlık yükleme hatasıyla karşılaşılıyorsa, sorun genellikle uyumsuz yollardan, eksik dosyalardan veya include kalıplarının hatalı tanımlanmasından kaynaklanır.

---

## 3. SVG ikon ekleme akışı

Yeni bir ikon eklerken takip edilmesi ve kontrol edilmesi gereken adımlar şunlardır:

1. SVG dosyası **monochromatic (tek renkli)** yapıda olmalı ve renk dolgusu için `currentColor` değerini kullanmalıdır. Aksi takdirde, sistemin `text_color` üzerinden yapacağı renklendirme işlemleri beklenmedik sonuçlar doğurur.
2. İlgili dosyayı `assets/icons/snake_case_isim.svg` biçiminde adlandırarak konumlandırman gerekir.
3. `icons` crate'i bünyesindeki `IconName` enum yapısına `CamelCase` formatında yeni bir varyant eklemelisin. Varyantların enum içerisindeki sırasını alfabetik tutmak, zorunlu bir derleme gereksinimi olmasa da kodun okunabilirliği açısından tercih edilen bir standarttır.
4. Kod katmanında bu ikonu `Icon::new(IconName::YeniIkon)` şeklinde çağırarak kullanabilirsin.

**Dikkat Edilmesi Gereken Hususlar:**

- **Uyumsuz Dosya Adlandırması:** Eğer dosya adı `YeniIkon.svg` gibi CamelCase biçiminde kaydedilirse, `IconName::path()` metodu çalışma zamanında `snake_case` bir yol üreteceği için dosya sistemde bulunamaz.
- **Eksik Boyut Bilgisi:** `width`, `height` ve `viewBox` özniteliklerinin üçü birden eksikse, `SvgRenderer` motoru ikon boyutunu sıfır olarak çözümler ve çizim (render) işlemi başarısız olur. `usvg` kütüphanesi, `width` ve `height` belirtilmediğinde bunları `%100` kabul eder; yani tek başına `viewBox` bulunmasa bile, boyutları tanımlanmış bir SVG render edilebilir. Yine de ikonun düzgün ölçeklenmesi için `viewBox="0 0 16 16"` gibi bir öznitelik tanımı yapılması önerilir. Asıl çizim hatası, üç göstergenin de bulunmadığı ya da hesaplanan boyutun sıfır veya negatif çıktığı durumlarda meydana gelir.
- **Sabit Piksel Boyutları:** SVG dosyasındaki `width` ve `height` özniteliklerinin piksel cinsinden sabit değerlere sahip olması durumunda render edilen boyut küçük kalabilir. En sağlıklı yöntem bu öznitelikleri `width="100%" height="100%"` olarak ayarlamak veya tamamen kaldırmaktır; ikonun asıl boyutunu element seviyesinde `Icon::size` metoduyla belirleyebilirsin.

**Renkli SVG Kullanımı:** `svg().path(...)`, `Icon` ve `Vector` yolları `Window::paint_svg` fonksiyonu üzerinden bir alfa maskesi (alpha mask) oluşturur ve içeriği tek bir renge boyar. Eğer renkli bir SVG veya kurumsal bir logo çizdirilmek isteniyorsa, `img("images/urun_logosu.svg")` yolu tercih edilmelidir; bu yaklaşım SVG dosyasını tam renkli bir `RenderImage` olarak pikselleştirir (rasterize eder).

---

## 4. Knockout ikonlarında çift dosya kuralı

`IconDecoration` yapısı her süsleme türü için **iki adet SVG** dosyasına ihtiyaç duyar:

- `icons/knockouts/<isim>_fg.svg` — Süslemenin asıl ön plan görseli.
- `icons/knockouts/<isim>_bg.svg` — Arka plan kazıma maskesi.

`KnockoutIconName` enum yapısına yeni bir varyant eklenirken bu iki dosyanın da dizine yerleştirilmesi gerekir. Tek bir dosyanın eksik olması durumunda, sistem çalışma zamanında `_fg` veya `_bg` bileşenlerinden birini boş bırakır ve beklenen görsel maskeyi üretemez.

`_bg` dosyası, `_fg` dosyasıyla benzer bir silüete sahip olmakla birlikte, altındaki ikonda temiz bir alan açmak (kazımak) amacıyla biraz daha kalın çizilir. Piksel cinsinden kalınlık farkının çok küçük tutulması (1-2 piksel) önemlidir; aksi takdirde süsleme ile ana ikon arasında estetik olmayan geniş bir boşluk meydana gelir.

---

## 5. Font ekleme ve generic family yedeği

Yeni bir font entegre ederken iki farklı tüketici noktasını güncellemek gerekir:

- `assets/fonts/<aile>/` dizini altına `.ttf` dosyalarını yerleştirmelisin. `load_embedded_fonts` fonksiyonu bu dizinde özyinelemeli (recursive) bir tarama yaparak dosyaları otomatik olarak keşfeder.
- `gpui` crate'i altındaki `load_bundled_fonts` listesinin güncellenme ihtiyacını değerlendirmelisin. Eğer bu fontun SVG çizimleri içinde de kullanılmasını hedefliyorsan ilgili dosya yolunu bu listeye eklemen gerekir; aksi halde yeni fontu yalnızca `TextSystem` tanıyacaktır.

**Lisans Dosyalarının Sağlanması:** SIL Open Font License (OFL) ile lisanslanmış fontlar için lisans metni (`OFL.txt` veya `license.txt`) mutlaka font klasörünün içerisine dahil edilmelidir. Bu belgeler `.ttf` filtresi tarafından otomatik olarak süzüldüğü için `TextSystem` belleğine yüklenmez; fakat dağıtılabilir varlık paketinin (asset bundle) içinde yer alarak yasal gereksinimleri karşılar.

**Genel Yazı Tipi Ailesi (Generic Family) Yedekleri:** SVG çizimlerinde `font-family="sans-serif"` veya `font-family="monospace"` gibi genel tanımlar kullanılıyorsa ve özellikle Linux sistemlerde çizim hataları yaşanıyorsa, `fix_generic_font_families` fonksiyonundaki yedek eşleme kurallarını güncellemek gerekir. Eğer yeni eklenen bir font ailesini varsayılan sistem yedeği haline getirmek istiyorsan, ilgili eşleme bloğuna ekleme yapmalısın.

---

## 6. Ses varlığı ekleme

Ses varlığı ekleme süreci şu adımlardan oluşur:

1. WAV uzantılı ses dosyasını `assets/sounds/<dosya_adi>.wav` yoluna yerleştirmelisin. Ses çözücü motor (`rodio::Decoder`) yalnızca PCM kodlamalı WAV formatını destekler; dolayısıyla başka formatlar kullanılmamalıdır.
2. `audio` crate'i bünyesindeki `Sound` enum yapısına yeni varyantı eklemelisin.
3. `Sound::file` metodundaki `match` bloğuna `Self::YeniSes => "yeni_ses"` eşlemesini girmelisin.

**Kontrol Adımları:**

- `match` bloğu tüm enum varyantlarını kapsamazsa Rust derleyicisi eksik eşleme kolunu tespit ederek derleme hatası üretir.
- Dosya formatında veya kodlamada bir uyumsuzluk yaşanırsa `Decoder::new` fonksiyonu hata döner; bu durumda `Audio::play_sound` sistemi hatayı günlüğe (log) kaydeder ve süreci sessizce devam ettirir. Ses duyulmadığında ilk olarak log kayıtları incelenmelidir.
- WAV dosyasının örnekleme hızı (sample rate) uygulamanın ses motoruyla uyumlu olmalıdır (Zed varsayılan olarak `SAMPLE_RATE: nz!(48000)` kullanır); aksi takdirde ses hattı yeniden örnekleme (resampling) yapar ve bu durum seste gecikmeye veya bozulmalara yol açabilir.

---

## 7. Tema JSON dosyalarını ayıklamak

Yeni bir tema entegre ederken izlenmesi gereken adımlar şunlardır:

- Tema dosyasını `assets/themes/<tema_ailesi>/<tema_ailesi>.json` yoluna kaydetmelisin (aile adı, klasör ve dosya adı ile birebir aynı olmalıdır).
- İlgili tema ailesine ait `LICENSE` dosyasını klasör içine yerleştirmeli ve `themes/LICENSES/` dizini altına gerekli atıfları (attribution) eklemelisin.
- JSON dosyasının veri şeması, Zed bünyesindeki `ThemeFamilyContent` struct yapısıyla tam bir uyum (parity) içinde olmalıdır. Eksik alanlar `refine_theme_family` yardımcı işlevi tarafından doldurulabilir; ancak şemada tanımlanmamış bilinmeyen alanlar `serde` ayrıştırıcısı tarafından reddedilebilir.

**Dikkat Edilmesi Gereken Noktalar:**

- **Görünüm Ayarı (`appearance`):** Bu alanın mutlaka `"light"` veya `"dark"` değerlerinden birini alması gerekir; aksi takdirde ayrıştırma işlemi başarısız olur ve tema yüklenemez.
- **Sondaki Virgüller (Trailing Commas):** JSON standardı gereği dosya sonunda veya eleman aralarında fazladan virgül bulunması, `serde_json` kütüphanesinin katı mod kuralları nedeniyle ayrıştırma hatasına yol açar.
- **Eksik Renk Tanımları:** Tema dosyasının `style` alanındaki `colors` bloğunda bazı renklerin eksik olması durumunda otomatik zenginleştirme (refinement) mekanizması devreye girer. Bu durum derleme veya çalışma hatası üretmez; ancak varsayılan temadan devralınan renkler arayüzde beklenmedik tonlara neden olabilir.

**Hata Tespiti:** Gömülü temaları yükleyen kod blokları oluşan hataları günlüğe (log) kaydeder ancak uygulamanın çalışmasını durdurmaz. Log dosyalarında belirli bir temanın ayrıştırılamadığını belirten bir hata kaydı bulunuyorsa, ilgili JSON dosyasının şeması kontrol edilmelidir. Diğer geçerli temalar sorunsuz yüklenmeye devam eder.

---

## 8. Settings ve keymap dosyalarını değiştirmek

Uygulama ayarlarını (`settings`) barındıran JSON dosyaları üzerinde değişiklik yaparken şunlara dikkat edilmelidir:

- **Varsayılan Ayarlar (`default.json`):** Bu dosyadaki herhangi bir değişiklik tüm kullanıcıları doğrudan etkiler. Bu nedenle geri dönük uyumluluk (backwards compatibility) mutlaka gözetilmelidir. Mevcut bir ayarın varsayılan değerini değiştirmek, kullanıcıların çalışma alışkanlıklarını etkileyebilir.
- **İlk Kurulum Şablonları (`initial_*.json`):** Bu dosyalardaki değişiklikler yalnızca uygulamayı ilk kez kuran yeni kullanıcılar için geçerli olur. Mevcut kullanıcıların kendi özelleştirdikleri ayar dosyaları bu süreçten etkilenmez.
- **Zorunlu Alanlar:** JSON şemasındaki alanlar `serde` ile çözümlenirken `Option<T>` sarmalayıcısına sahip olmayan alanlar zorunlu kabul edilir. Bu alanların boş veya eksik bırakılması uygulamanın başlatılmasını engelleyebilir.

Kısayol eşleme (`keymap`) dosyalarını güncellerken dikkat edilecekler:

- **Platform Özgü Dosyalar:** İşletim sistemlerine özel kısayollar (`default-macos.json`, `default-linux.json`, `default-windows.json`) ayrı dosyalarda yönetilir. Yeni bir kısayolun her üç platformda da geçerli olması isteniyorsa, üç dosyanın da güncellenmesi gerekir.
- **Editör Emülasyon Paketleri:** JetBrains veya VS Code gibi popüler editörlerin tuş kombinasyonlarını taklit eden dosyalar (`keymaps/macos/jetbrains.json` vb.) isteğe bağlıdır; kullanıcılar bu paketleri `BaseKeymap` ayarı üzerinden aktif hale getirebilirler.
- **Kullanıcı Şablonu (`initial.json`):** Bu dosya, kullanıcının kendi kısayol dosyasını ilk açtığında karşılaşacağı taslaktır. Buraya rehberlik etmesi amacıyla örnek kısayollar eklenebilir, ancak herhangi bir bağlayıcılığı bulunmaz.

---

## 9. Varlık boyutunun binary üzerindeki etkisi

`release` veya `debug-embed` derleme modlarında tüm varlıklar `RustEmbed` vasıtasıyla doğrudan ikili dosyaya (binary) gömüldüğünden, eklenen her dosya binary boyutunu doğrudan artırır. Normal `debug` modunda dosyalar çalışma zamanında yerel dosya sisteminden okunsa dahi, release paket boyutu projeksiyonlarının aynı varlık kümesi üzerinden hesaplanması gerekir. Tipik varlık boyutları şu şekildedir:

| Varlık Türü | Tipik Boyut | Adet | Toplam Boyut Etkisi |
|-------------|-------------|------|--------------------|
| Font (.ttf) | 100-200 KB | 8 dosya (Zed varsayılanı) | ~1.5 MB |
| İkon (.svg) | 1-5 KB | ~400 dosya | ~1 MB |
| Tema (.json) | 50-200 KB | 3 adet aile dosyası | ~1-2 MB |
| Ses (.wav) | 10-100 KB | 8 dosya | ~500 KB |

Gömülü tema ailesi olarak varsayılan pakette yalnızca üç adet JSON dosyası (Ayu, Gruvbox, One) yer alır. Her dosyanın içerisinde ilgili tema ailesine ait birden fazla varyant (örneğin açık ve koyu sürümler) bulunabildiğinden, etkinleştirilen tema sayısı fiziksel dosya sayısından çok daha fazladır.

Zed ikili dosyasındaki toplam gömülü varlık boyutu yaklaşık 5-10 MB civarındadır. Bu hacim, modern bir masaüstü uygulaması için oldukça makul bir paydır. Ancak daha küçük bir binary boyutu hedeflendiği durumlarda şu optimizasyon yöntemleri uygulanabilir:

- WAV ses dosyaları OGG veya Opus formatlarına dönüştürülebilir (bu sayede 5 ila 10 kat sıkıştırma elde edilebilir).
- Font dosyaları için alt kümeler (font subsetting) oluşturularak yalnızca uygulamada kullanılan karakterlerin binary'ye dahil edilmesi sağlanabilir.
- Tema dosyaları sıkıştırılmış (gzip) olarak saklanıp çalışma zamanında belleğe açılabilir. Bu yöntem başlatma süresine milisaniyeler düzeyinde ufak bir yük getirse de ikili dosya boyutunu düşürmeye yardımcı olur.

Bu optimizasyonlar Zed projesinin varsayılan olarak tercih etmediği, isteğe bağlı yöntemlerdir. Standart release akışında belirlenen varlık kümesi ham (uncompressed) şekilde binary içerisine gömülür.

---

## 10. Cargo crate sınırlarını sakin tutmak

Varlık yönetim hattının crate organizasyonu, bağımlılıkların temiz kalması için net bir katman yapısına sahiptir:

- **`assets` Crate'i:** `Assets` struct yapısını barındırır. Yalnızca `RustEmbed` makrosunu tetikler ve harici bir crate bağımlılığı içermez.
- **`settings` Crate'i:** `SettingsAssets` struct yapısı ile varsayılan kısayol/ayar API'lerini içerir. `gpui` ve `assets` crate'lerinden tamamen bağımsızdır.
- **`icons` Crate'i:** `IconName` enum tanımını barındırır. Yalnızca `strum` ve `serde` kütüphaneleri üzerine kuruludur; başka bir bağımlılık taşımaz.
- **`theme` Crate'i:** `ThemeRegistry` ve `Theme` yapılarını sunar. `gpui::AssetSource` arayüzü ile çalışır ancak somut `Assets` struct yapısı hakkında bilgi sahibi değildir.
- **`audio` Crate'i:** `Sound` enum yapısı ile `Audio::play_sound` fonksiyonunu içerir. Varlıkları `cx.asset_source()` üzerinden dinamik olarak okur.
- **`ui` Crate'i:** `Icon` ve `Vector` gibi kullanıcı arayüzü bileşenlerini barındırır. Tasarımı `icons` ve `gpui` katmanları üzerine inşa edilir.

Bu temiz hiyerarşinin bozulması (örneğin `icons` crate'ine `gpui` bağımlılığı eklenmesi) şu iki temel soruna yol açar:

1. **Döngüsel Bağımlılık (Circular Dependency) Riski:** `gpui` crate'inin ileride kendi içinde `icons` crate'ine ihtiyaç duyması durumunda çözülemeyen döngüsel bağımlılıklar oluşur.
2. **Yeniden Derleme (Recompilation) Maliyeti:** Alt katmanlarda yer alan crate'lerin bağımlılık ağacı genişledikçe, artımlı derleme (incremental build) süreleri belirgin şekilde uzar.

Yeni bir varlık türü entegre edilirken doğru hedef crate'in seçilmesi, bu modüler hiyerarşinin sağlıklı şekilde korunmasını sağlar.

---

## 11. Son kontrol listesi

Varlık altyapısı kurulup yapılandırıldıktan sonra doğrulanması gereken son sağlamlık kontrolleri şunlardır:

- [ ] `with_assets(Assets)` çağrısı `Application::with_platform` akışına düzgün şekilde bağlanmış mı?
- [ ] `load_embedded_fonts(cx)` çağrısı pencere açılmadan **önce** yürütülüyor mu?
- [ ] `theme_settings::init(LoadThemes::All(Box::new(Assets)), cx)` veya eşdeğeri bir çağrıyla tema sistemi başarıyla ilklendirilmiş mi?
- [ ] `settings::init(cx)` çağrısı öncelikli olarak çalıştırılıp varsayılan ayarlar `default_settings()` üzerinden yüklenmiş mi?
- [ ] Yeni eklenen her ikon için `IconName` enum varyantı oluşturulmuş ve ilgili SVG dosya adı `snake_case` standartlarına uydurulmuş mu?
- [ ] Yeni eklenen her ses varlığı için `Sound` enum varyantı, `Sound::file` eşleme kolu ve fiziksel WAV dosyası birbiriyle uyumlu mu?
- [ ] Yeni eklenen her tema için JSON dosyasında `appearance` alanı geçerli bir değere sahip mi ve `LICENSE` belgesi klasöre dahil edilmiş mi?
- [ ] Yeni gömülen fontlar için `.ttf` uzantısı korunmuş ve OFL lisans belgesi ilgili font dizinine eklenmiş mi?
- [ ] Headless test ortamlarında varlıklara erişim gerekiyorsa, `with_text_system_and_assets` (veya `with_asset_source`) test yardımcıları kullanılmış mı?
- [ ] Yerel dosya sisteminden okunan yollar için sembolik bağ (symlink) ve yol normalleştirme (canonicalization) kontrolleri yapılmış mı?

Bu kontrol listesindeki maddeler eksiksiz tamamlandığında, varlık yönetim hattı hem üretim (production) hem de test senaryolarını sağlıklı bir biçimde karşılayacak düzeye ulaşmış olur.

---
