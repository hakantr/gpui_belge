# Pratik kontrol listesi

Bu bölüm, önceki bölümlerdeki açıklamaların özünü tek noktaya toplar. Varlık altyapısını kurarken, genişletirken veya bir sorunu ararken dikkat edilmesi gereken noktaları kısa maddeler halinde görürsün. Tipik karar noktaları ve son kontrol adımları da aynı yerde durur. Amaç, sıfırdan rehberi yeniden okumadan referans olarak kullanılabilen bir özet sunmaktır.

---

## 1. Kuruluş sırasında dikkat edilecekler

Varlık hattı uygulama başlatma akışında birkaç sert bağımlılığa sahiptir. Zed'in `main.rs` dosyasındaki gerçek sıra kabaca şöyledir: varlık kaynağı en başta kurulur, settings erken yüklenir, tema sistemi settings ve extension altyapısından sonra gelir. Prompt şablonları daha sonra handlebars motoruna kaydedilir. Font yükleme ise pencere açılmadan önce, editor/workspace init'lerinden hemen önce çalışır. Yani tek doğru olan aşağıdaki sıra değil, bu bağımlılıkların korunmasıdır:

1. **`Application::with_platform(...).with_assets(Assets)`** — Varlık kaynağı `App`'e bağlanır. Bu çağrı yoksa `cx.asset_source()` boş `()` döner ve `list/load` çağrıları sonuç vermez.
2. **`settings::init(cx)`** — `SettingsStore` `default_settings()` çıktısıyla kurarsın. `asset_str::<SettingsAssets>("settings/default.json")` çağrısı bu noktada fail-fast paketleme kontratına bağlıdır; dosya binary'de olmazsa uygulama açılmaz.
3. **`theme_settings::init(LoadThemes::All(Box::new(Assets)), cx)`** — Tema sistemi kurulur; `ThemeRegistry` global duruma konur ve gömülü temalar yüklenir. Settings'e bakan tema seçimi için `settings::init` bundan önce tamamlanmış olmalıdır.
4. **`PromptBuilder::load(fs, ..., cx)`** — Prompt şablonları handlebars motoruna kaydedilir. Dosya sistemi izleyicisi arka planda geçersiz kılma klasörünü izlemeye başlar.
5. **`load_embedded_fonts(cx)` (veya `Assets.load_fonts(cx)`)** — `TextSystem`'e fontlar yüklenir. Pencere açılmadan önce yapman gerekir; aksi halde ilk karede font yedek değere düşer.
6. **`cx.open_window(...)`** — Pencere açıldıktan sonra UI render hattı SVG ikonları okumaya başlar; varlık hattının önceki adımları tamamlanmış olmalıdır.

**Kontrol:** Uygulama çalışıyor ama ikonlar görünmüyorsa `with_assets` bağlantısını kontrol et. Font'lar beklenen aileyle render edilmiyorsa `load_embedded_fonts` çağrısının pencere açılmadan **önce** yapılıp yapılmadığını kontrol et.

---

## 2. RustEmbed kalıplarını tutarlı tutmak

`#[include]` ve `#[exclude]` direktifleri paketlenecek dosya kümesini belirler; release/debug-embed modunda içerik binary'ye girer, normal debug modda ise aynı eşleşme dosya sisteminden okuma için kullanırsın. Dikkat edilmesi gereken yerler:

- **Exclude önceliklidir.** `rust-embed` 8.11, include ve exclude kalıplarını `globset` ile ayrı kümeler olarak değerlendirir; exclude eşleşmesi include'u ezer. Direktif sırası "ilk eşleşen kazanır" şeklinde çalışmaz.
- **Glob kalıbına dikkat.** RustEmbed'in kullandığı `globset::Glob::new` varsayılanında `*` yol ayırıcısını da eşleyebilir; Zed'in `#[include = "keymaps/*"]` kalıbı bu yüzden platform alt dizinlerini kapsar. Yine de yeni özyinelemeli kalıplarda `**/*` kullanmak niyeti daha açık gösterir.
- **`*.DS_Store` exclude'unu eklemek.** macOS finder bu gizli dosyaları üretir; include kalıbı geniş tutulduğunda binary'ye sızar.
- **Derleme cache'i geçersiz kılma sorunu.** `RustEmbed` dosya değişikliklerini izleyemediği durumlarda eski içerik gömülmüş kalır. Belirgin bir varlık değişikliği sonrası beklenen davranış görünmüyorsa `cargo clean -p assets` (veya ilgili crate) ile cache temizlemek gerekir.

**Kontrol:** Varlık eklendi ama çalışma zamanında görünmüyorsa şu üç şey ardarda doğrulanır: (a) dosya `assets/` altında doğru yerde mi, (b) `RustEmbed` include kalıbı bu klasörü kapsıyor mu, (c) ilgili crate yeniden derlendi mi?

**Eksik yol davranışı:** `Assets::load` eksik dosyada `Ok(None)` dönmez; yüklenemeyen yolu bağlam olarak ekleyen bir hata üretir. `Ok(None)` davranışı boş `()` kaynağı veya bunu özellikle seçen özel `AssetSource` implementasyonları içindir. Log'da bu türden bir varlık yükleme hatası görülüyorsa kaynak genellikle uyumsuz yol, eksik dosya veya include kalıbıdır.

---

## 3. SVG ikon ekleme akışı

İkon eklerken kontrol edilecek adımlar:

1. SVG dosyası **monochrome** ve `currentColor` kullanan biçimde olmalıdır. Aksi halde `text_color` ile boyama beklenmedik sonuç verir.
2. Dosyayı `assets/icons/snake_case_isim.svg` olarak koyarsın.
3. `icons` crate'indeki `IconName` enum'una `CamelCase` varyantı eklersin. Sıralama enum içinde alfabetik tutulur; bu bir derleme gereksinimi değil okuma kolaylığı için tercih edilen bir kural.
4. Kod tarafında `Icon::new(IconName::YeniIkon)` ile kullanırsın.

**Dikkat edilmesi gereken yerler:**

- Dosya adı CamelCase yazıldı (örneğin `YeniIkon.svg`): `IconName::path()` `snake_case` üretir, dosya bulunmaz.
- SVG'de boyut göstergesi hiç yok: `width`, `height` ve `viewBox` üçü birden eksikse `SvgRenderer` boyutu sıfır çözer ve render başarısız olur. usvg, `width`/`height` verilmemişse bunları `100%` varsayar; tek başına `viewBox` olmadan da, ölçüleri belirtilmiş bir SVG render olur. Yine de `viewBox="0 0 16 16"` gibi bir tanım doğru ölçeklenme için güçlü biçimde önerilir; gerçek başarısızlık (sıfır boyut) üç göstergenin de bulunmadığı ya da boyutun sıfıra veya negatife indiği durumda doğar.
- SVG `width` ve `height` öznitelikleri piksel cinsinden sabit: render boyutu küçük kalır. `width="100%" height="100%"` veya tamamen kaldırmak doğrudur; boyutu element seviyesinde `Icon::size` ile verirsin.

**Renkli SVG notu:** `svg().path(...)`, `Icon` ve `Vector` yolları `Window::paint_svg` üzerinden alpha mask üretir ve tek renkle boyar. Renkli SVG veya logo gerekiyorsa `img("images/foo.svg")` yolunu kullan; bu yol SVG'yi tam renkli `RenderImage` olarak rasterleştirir.

---

## 4. Knockout ikonlarında çift dosya kuralı

`IconDecoration` her süsleme türü için **iki SVG** ister:

- `icons/knockouts/<isim>_fg.svg` — süslemenin asıl şekli
- `icons/knockouts/<isim>_bg.svg` — arka maske

`KnockoutIconName` enum'una yeni bir varyant eklenirken her iki dosyanın da konulması gerekir; tek dosyalı süsleme çalışma zamanında `_fg` veya `_bg` taraflarından birini boş bırakır ve beklenen maskeyi üretmez.

`_bg` dosyası `_fg` dosyasıyla aynı silüete sahip ama biraz daha kalındır; arka maskenin altındaki ikonu kazımak için. Piksel sapması küçük olmalıdır (1-2 px), aksi halde süsleme ile ikon arasında gözle görülür bir aralık oluşur.

---

## 5. Font ekleme ve generic family yedeği

Font eklerken iki ayrı tüketiciyi güncellersin:

- `assets/fonts/<aile>/` altına `.ttf` dosyaları koyarsın; `load_embedded_fonts` özyinelemeli listeleme yaparak otomatik bulur.
- `gpui` crate'indeki `load_bundled_fonts` listesini güncellemen gerekip gerekmediğini değerlendirirsin. SVG'lerde bu fontun kullanılacağını düşünüyorsan yol eklersin; aksi halde fontu sadece `TextSystem` görür.

**Dikkat edilmesi gereken lisans ayrıntısı:** OFL ile lisanslı font'lar için lisans dosyası (`OFL.txt` veya `license.txt`) font klasörünün içine konmalıdır. Bu dosyalar `.ttf` filtresi tarafından dışlandığı için `TextSystem`'e yüklenmez ama varlık paketinde durur ve dağıtım gereksinimini karşılar.

**Generic family yedeği:** Eğer SVG'lerde `font-family="sans-serif"` veya `font-family="monospace"` kullanılıyorsa ve Linux'ta render sorunu görülüyorsa `fix_generic_font_families` fonksiyonundaki yedek eşleme güncellenmelidir. Yeni eklenen bir font ailesi varsayılan eşleme haline getirilmek istenirse oraya girer.

---

## 6. Ses ekleme

Ses ekleme akışı şudur:

1. WAV dosyasını `assets/sounds/<dosya_adi>.wav` olarak koyarsın. `rodio::Decoder` yalnızca WAV (PCM) çözer; başka format kullanılmaz.
2. `audio` crate'indeki `Sound` enum'una varyant eklersin.
3. `Sound::file` `match` bloğuna `Self::YeniSes => "yeni_ses"` satırını girersin.

**Kontrol:**

- `match` bloğu kapsayıcı değilse derleme hatası verir; derleyici eksik kolu zaten yakalar.
- Dosya format sorunu durumunda `Decoder::new` hata döner; `Audio::play_sound` log'a düşer ve sessizce devam eder. Çıktı duyulmuyorsa log'lar incelenmelidir.
- WAV dosyasının örnekleme oranı uygulamayla uyumlu olmalı (Zed `SAMPLE_RATE: nz!(48000)` kullanır); aksi halde ses hattı resample yapar veya bozulma olur.

---

## 7. Tema JSON dosyalarını ayıklamak

Yeni tema eklerken:

- Dosyayı `assets/themes/<aile>/<aile>.json` olarak koyarsın (aile adı klasör ve dosya adında aynı tutulur).
- Aile için `LICENSE` dosyasını klasöre koyarsın; `themes/LICENSES/` altına atribusyon eklersin.
- JSON sözleşmesi Zed'in `ThemeFamilyContent` struct'ıyla parite olmalıdır. Eksik alanlar `refine_theme_family` tarafından doldurulur ama bilinmeyen alanlar serde tarafından reddedilebilir.

**Dikkat edilmesi gereken yerler:**

- `appearance` alanı `"light"` veya `"dark"` dışında bir değere sahip: ayrıştırma başarısız olur, tema yüklenmez.
- JSON'da sondaki virgül var: `serde_json` katı modda reddeder.
- `style` alanındaki `colors` blokunda eksik renk: refinement yedeği devreye girer; pratik bir sorun yaratmaz ama varsayılan temadan miras alan renkler beklenmedik olabilir.

**Tema yüklenmediği zaman tespiti:** gömülü tema yükleme yolu hatayı loglar ama uygulamayı durdurmaz. Log'da bir tema dosyasının ayrıştırılamadığını bildiren bir kayıt görünüyorsa o dosyada sorun vardır; geri kalan temalar çalışmaya devam eder.

---

## 8. Settings ve keymap dosyalarını değiştirmek

Settings JSON'unu değiştirirken:

- `default.json` değişimi tüm kullanıcıları etkiler; geri uyumluluk düşünmen gerekir. Mevcut bir ayarın varsayılanını değiştirmek kullanıcı davranışını doğrudan etkiler.
- `initial_*.json` değişimi yalnızca yeni kullanıcıları etkiler. Mevcut kullanıcının dosyası geçersiz kılınmaz.
- JSON sözleşmesi `serde` ile ayrıştırıldığı için `Option<T>` olmayan alanlar zorunludur; eksik bırakmak uygulamayı açtırmaz.

Keymap dosyalarını değiştirirken:

- Platforma özgü dosyalar (`default-macos.json`, `default-linux.json`, `default-windows.json`) ayrı ayrı yönetilir. Aynı kısayolu üç platforma da eklemek için üç dosyayı da güncellemek gerekir.
- Editor emülasyon paketleri (`keymaps/macos/jetbrains.json` vb.) opsiyoneldir; kullanıcı `BaseKeymap` ayarı ile seçer.
- `initial.json` kullanıcının ilk keymap dosyası şablonudur; örnek kısayollar koyarsın ama hiçbir bağlayıcı kural yoktur.

---

## 9. Varlık boyutunun binary üzerindeki etkisi

Release/debug-embed build'de varlıklar `RustEmbed` ile binary'ye gömüldüğü için her dosyayı binary boyutuna eklersin. Normal debug build'de dosyalar dosya sisteminden okunsa da release paket boyutu hesabını aynı varlık kümesi üzerinden yapman gerekir. Tipik büyüklükler:

| Varlık türü | Tipik boyut | Adet | Toplam etki |
|-------------|-------------|------|-------------|
| Font (.ttf) | 100-200 KB | 8 dosya (Zed'de) | ~1.5 MB |
| Icon (.svg) | 1-5 KB | ~400 dosya | ~1 MB |
| Tema (.json) | 50-200 KB | 3 aile dosyası | ~1-2 MB |
| Ses (.wav) | 10-100 KB | 8 dosya | ~500 KB |

Gömülü tema ailesi olarak yalnızca üç JSON dosyası (ayu, gruvbox, one) gelir; her dosyanın içinde aynı ailenin birden çok teması (örneğin açık ve koyu varyantlar) barınabildiği için yüklenen tema sayısı dosya sayısından fazladır.

Toplam varlık boyutu Zed binary'sinde 5-10 MB civarındadır. Bu, modern bir desktop uygulaması için kabul edilebilir bir bedeldir; ancak küçük binary'ler hedeflenirse:

- WAV dosyaları OGG/Opus'a dönüştürülebilir (yaklaşık 5-10 kat sıkıştırma).
- Font alt kümeleri (subset) oluşturulup yalnızca kullanılan karakterler tutulabilir.
- Tema dosyaları gzip'lenip çalışma zamanında açılabilir; bu ödünleşim başlatma süresinde milisaniyeler eklerken binary boyutunu küçültür.

Bu optimizasyonlar Zed'in yapmadığı tercihlerdir; release için standart davranış "seçilen varlık kümesi ham olarak gömülür"dür.

---

## 10. Cargo crate sınırlarını sakin tutmak

Varlık hattının crate organizasyonu net bir desene oturur:

- `assets` — `Assets` struct'ı. Yalnızca `RustEmbed` makrosunu çağırır; başka bir bağımlılık almaz.
- `settings` — `SettingsAssets` struct'ı + keymap/settings varsayılan API'leri. `gpui` ve `assets`'ten bağımsızdır.
- `icons` — `IconName` enum'u. Yalnızca `strum` ve `serde` üzerine kuruludur; başka bağımlılık almaz.
- `theme` — `ThemeRegistry`, `Theme`. `gpui::AssetSource` ile çalışır ama `Assets` struct'ını bilmez.
- `audio` — `Sound` enum'u + `Audio::play_sound`. `cx.asset_source()` üzerinden okur.
- `ui` — `Icon`, `Vector` bileşenleri. `icons` ve `gpui` üzerine kurarsın.

Bu hiyerarşinin bozulması (örneğin `icons`'a `gpui` bağımlılığı eklemek) iki sorun yaratır:

1. **Döngüsel bağımlılık riski.** `gpui` ileride `icons`'u kullanmak isterse döngü oluşur.
2. **Yeniden derleme maliyeti.** Düşük seviyede crate'lerin bağımlılıkları arttıkça artımlı derleme maliyeti büyür.

Yeni bir varlık türü eklerken doğru crate'i seçmek bu hiyerarşiyi korur.

---

## 11. Son kontrol listesi

Varlık altyapısı çalıştırıldıktan sonra geçilmesi gereken son sağlamlık testleri:

- [ ] `with_assets(Assets)` çağrısı `Application::with_platform` zincirine eklenmiş mi?
- [ ] `load_embedded_fonts(cx)` pencere açılmadan **önce** çağrılıyor mu?
- [ ] `theme_settings::init(LoadThemes::All(Box::new(Assets)), cx)` (veya muadili) ile tema sistemi başlatılmış mı?
- [ ] `settings::init(cx)` çağrısı önce yapılıp, sonra `default_settings()` ile varsayılanlar yüklü mü?
- [ ] Yeni eklenen her ikon için `IconName` varyantı var mı? Dosya adı snake_case mı?
- [ ] Yeni eklenen her ses için `Sound` enum'u, `Sound::file` eşlemesi ve WAV dosyası senkron mu?
- [ ] Yeni eklenen her tema için JSON'da `appearance` doğru mu, LICENSE dosyası eklenmiş mi?
- [ ] Yeni font'lar için `.ttf` uzantısı ve OFL/lisans dosyası klasörde mi?
- [ ] Test ortamında varlık gerekiyorsa `with_text_system_and_assets` (veya `with_asset_source`) çağrısı kullanılmış mı?
- [ ] Dosya sisteminden okunan yollar için symlink ve canonicalization doğrulaması var mı?

Bu liste tamamlandığında varlık hattı tipik üretim ve test senaryolarını karşılayacak şekilde kurulmuş olur.

---
