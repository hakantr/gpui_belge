# Pratik kontrol listesi

Bu bölüm, önceki bölümlerdeki açıklamaların özünü tek noktaya toplar. Asset altyapısını kurarken, genişletirken veya bir sorunu ararken sık karşılaşılan tuzakları kısa maddeler halinde görürsün. Tipik karar noktaları ve son kontrol adımları da aynı yerde durur. Amaç, sıfırdan rehberi yeniden okumadan referans olarak kullanılabilen bir özet sunmaktır.

---

## 1. Kuruluş sırasında dikkat edilecekler

Asset boru hattı uygulama başlatma akışında birkaç sert bağımlılığa sahiptir. Zed'in `main.rs` dosyasındaki gerçek sıra kabaca şöyledir: asset source en başta kurulur, settings erken yüklenir, tema sistemi settings ve extension altyapısından sonra gelir. Prompt şablonları daha sonra handlebars motoruna kaydedilir. Font yükleme ise pencere açılmadan önce, editor/workspace init'lerinden hemen önce çalışır. Yani tek doğru olan aşağıdaki sıra değil, bu bağımlılıkların korunmasıdır:

1. **`Application::with_platform(...).with_assets(Assets)`** — Asset source App'e bağlanır. Bu çağrı atlanırsa `cx.asset_source()` boş `()` döner ve `list/load` çağrıları sonuç vermez.
2. **`settings::init(cx)`** — `SettingsStore` `default_settings()` çıktısıyla kurarsın. `asset_str::<SettingsAssets>("settings/default.json")` çağrısı bu noktada panik atabilir; dosya binary'de olmazsa uygulama açılmaz.
3. **`theme_settings::init(LoadThemes::All(Box::new(Assets)), cx)`** — Tema sistemi kurulur; `ThemeRegistry` global state'e konur ve gömülü temalar yüklenir. Settings'e bakan tema seçimi için `settings::init` bundan önce tamamlanmış olmalıdır.
4. **`PromptBuilder::load(fs, ..., cx)`** — Prompt şablonları handlebars motoruna kaydedilir. Filesystem watcher arka planda override klasörünü izlemeye başlar.
5. **`load_embedded_fonts(cx)` (veya `Assets.load_fonts(cx)`)** — TextSystem'e fontlar yüklenir. Pencere açılmadan önce yapman gerekir; aksi halde ilk frame'de font fallback'e düşer.
6. **`cx.open_window(...)`** — Pencere açıldıktan sonra UI render hattı SVG ikonları okumaya başlar; asset boru hattının önceki adımları tamamlanmış olmalıdır.

**Kontrol:** Uygulama çökmüyor ama ikonlar görünmüyorsa `with_assets` çağrısı atlanmış olabilir. Font'lar yanlış render ediliyorsa `load_embedded_fonts` çağrısının pencere açılmadan **önce** yapılıp yapılmadığını kontrol et.

---

## 2. RustEmbed kalıplarını tutarlı tutmak

`#[include]` ve `#[exclude]` direktifleri paketlenecek dosya kümesini belirler; release/debug-embed modunda içerik binary'ye girer, normal debug modda ise aynı eşleşme filesystem'den okuma için kullanırsın. Tipik tuzaklar:

- **Exclude önceliklidir.** `rust-embed` 8.11, include ve exclude kalıplarını `globset` ile ayrı kümeler olarak değerlendirir; exclude eşleşmesi include'u ezer. Direktif sırası "ilk eşleşen kazanır" şeklinde çalışmaz.
- **Glob kalıbına dikkat.** RustEmbed'in kullandığı `globset::Glob::new` varsayılanında `*` path ayırıcısını da eşleyebilir; Zed'in `#[include = "keymaps/*"]` kalıbı bu yüzden platform alt dizinlerini kapsar. Yine de yeni recursive kalıplarda `**/*` kullanmak niyeti daha açık gösterir.
- **`*.DS_Store` exclude'unu unutmamak.** macOS finder bu gizli dosyaları üretir; include kalıbı geniş tutulduğunda binary'ye sızar.
- **Build cache invalidate sorunu.** `RustEmbed` dosya değişikliklerini izleyemediği durumlarda eski içerik gömülmüş kalır. Belirgin bir asset değişikliği sonrası beklenen davranış görünmüyorsa `cargo clean -p assets` (veya ilgili crate) ile cache temizlemek gerekir.

**Kontrol:** Asset eklendi ama runtime'da görünmüyorsa şu üç şey ardarda doğrulanır: (a) dosya `assets/` altında doğru yerde mi, (b) `RustEmbed` include kalıbı bu klasörü kapsıyor mu, (c) ilgili crate yeniden derlendi mi?

**Eksik path davranışı:** `Assets::load` eksik dosyada `Ok(None)` dönmez; `loading asset at path ...` context'iyle hata üretir. `Ok(None)` davranışı boş `()` kaynağı veya bunu özellikle seçen custom `AssetSource` implementasyonları içindir. Log'da bu mesaj görülüyorsa sorun genellikle yanlış path, eksik dosya veya include kalıbıdır.

---

## 3. SVG ikon ekleme akışı

İkon eklerken sıkça unutulan adımlar:

1. SVG dosyası **monochrome** ve `currentColor` kullanan biçimde olmalıdır. Aksi halde `text_color` ile boyama beklenmedik sonuç verir.
2. Dosya `assets/icons/snake_case_isim.svg` olarak konur.
3. `crates/icons/src/icons.rs` içindeki `IconName` enum'una `CamelCase` varyantı eklersin. Sıralama enum içinde alfabetik tutulur; bu bir derleme gereksinimi değil okuma kolaylığı için tercih edilen bir kural.
4. Kod tarafında `Icon::new(IconName::YeniIkon)` ile kullanırsın.

**Sık görülen hatalar:**

- Dosya adı CamelCase yazıldı (örneğin `YeniIkon.svg`): `IconName::path()` `snake_case` üretir, dosya bulunmaz.
- SVG `viewBox` tanımı yok: `SvgRenderer` boyutu hesaplayamaz, render başarısız olur. `viewBox="0 0 16 16"` gibi bir tanım her SVG için zorunludur.
- SVG `width` ve `height` öznitelikleri pixel cinsinden sabit: render boyutu küçük kalır. `width="100%" height="100%"` veya tamamen kaldırmak doğrudur; size element seviyesinde `Icon::size` ile verirsin.

**Renkli SVG notu:** `svg().path(...)`, `Icon` ve `Vector` yolları `Window::paint_svg` üzerinden alpha mask üretir ve tek renkle boyar. Renkli SVG veya logo gerekiyorsa `img("images/foo.svg")` yolunu kullan; bu yol SVG'yi tam renkli `RenderImage` olarak rasterleştirir.

---

## 4. Knockout ikonlarında çift dosya kuralı

`IconDecoration` her süsleme türü için **iki SVG** ister:

- `icons/knockouts/<isim>_fg.svg` — süslemenin asıl şekli
- `icons/knockouts/<isim>_bg.svg` — arka maske

`KnockoutIconName` enum'una yeni bir varyant eklenirken her iki dosyanın da konulması gerekir; tek dosyalı süsleme runtime'da `_fg` veya `_bg` taraflarından birini boş bırakır ve ikonu yanlış maskeler.

`_bg` dosyası `_fg` dosyasıyla aynı silüete sahip ama biraz daha kalındır; arka maskenin altındaki ikonu kazımak için. Pixel sapması küçük olmalıdır (1-2 px), aksi halde süsleme ile ikon arasında gözle görülür bir aralık oluşur.

---

## 5. Font ekleme ve generic family fallback'i

Font eklerken iki ayrı tüketici güncellenir:

- `assets/fonts/<aile>/` altına `.ttf` dosyaları konur; `load_embedded_fonts` recursive listeleme yaparak otomatik bulur.
- `crates/gpui/src/svg_renderer.rs` içindeki `load_bundled_fonts` listesinin güncellenmesi gerekip gerekmediği değerlendirilir. SVG'lerde bu fontun kullanılacağı düşünülüyorsa path eklenmeli; aksi halde fontu sadece `TextSystem` görür.

**Sık unutulan ayrıntı:** OFL ile lisanslı font'lar için lisans dosyası (`OFL.txt` veya `license.txt`) font klasörünün içine konmalıdır. Bu dosyalar `.ttf` filtresi tarafından dışlandığı için TextSystem'e yüklenmez ama asset paketinde durur ve dağıtım gereksinimini karşılar.

**Generic family fallback'i:** Eğer SVG'lerde `font-family="sans-serif"` veya `font-family="monospace"` kullanılıyorsa ve Linux'ta render sorunu görülüyorsa `fix_generic_font_families` fonksiyonundaki fallback eşlemesi güncellenmelidir. Yeni eklenen bir font ailesi varsayılan eşleme haline getirilmek istenirse oraya girer.

---

## 6. Ses ekleme

Ses ekleme akışı şudur:

1. WAV dosyası `assets/sounds/<dosya_adi>.wav` olarak konur. `rodio::Decoder` PCM WAV ve LPCM destekler; başka format kullanılmaz.
2. `crates/audio/src/audio.rs` içindeki `Sound` enum'una varyant eklersin.
3. `Sound::file` match bloğuna `Self::YeniSes => "yeni_ses"` girilir.

**Kontrol:**

- Match bloğu exhaustive değilse derleme hatası verir; bu noktayı atlamak mümkün değildir.
- Dosya format sorunu durumunda `Decoder::new` hata döner; `Audio::play_sound` log'a düşer ve sessizce devam eder. Çıktı duyulmuyorsa log'lar incelenmelidir.
- WAV dosyasının örnekleme oranı uygulamayla uyumlu olmalı (Zed `SAMPLE_RATE: nz!(48000)` kullanır); aksi halde ses pipeline'ı resample yapar veya distorsiyon olur.

---

## 7. Tema JSON dosyalarını ayıklamak

Yeni tema eklerken:

- Dosya `assets/themes/<aile>/<aile>.json` olarak konur (aile adı klasör ve dosya adında aynı tutulur).
- Aile için `LICENSE` dosyası klasöre konur; `themes/LICENSES/` altına atribusyon eklersin.
- JSON sözleşmesi Zed'in `ThemeFamilyContent` struct'ıyla parite olmalıdır. Eksik alanlar `refine_theme_family` tarafından doldurulur ama bilinmeyen alanlar serde tarafından reddedilebilir.

**Sık görülen hatalar:**

- `appearance` alanı `"light"` veya `"dark"` dışında bir değere sahip: parse başarısız olur, tema yüklenmez.
- JSON'da trailing comma var: `serde_json` strict mode'da reddeder.
- `style` alanındaki `colors` blokunda eksik renk: refinement fallback'i devreye girer; pratik bir sorun yaratmaz ama default temadan miras alan renkler beklenmedik olabilir.

**Tema yüklenmediği zaman tespiti:** `load_bundled_themes` hata loglar ama uygulamayı durdurmaz. Log'da `failed to parse theme at path "..."` mesajı görünüyorsa o tema dosyasında sorun vardır; geri kalan temalar çalışmaya devam eder.

---

## 8. Settings ve keymap dosyalarını değiştirmek

Settings JSON'unu değiştirirken:

- `default.json` değişimi tüm kullanıcıları etkiler; geri uyumluluk düşünmen gerekir. Mevcut bir ayarın varsayılanını değiştirmek kullanıcı davranışını doğrudan etkiler.
- `initial_*.json` değişimi yalnızca yeni kullanıcıları etkiler. Mevcut kullanıcının dosyası override edilmez.
- JSON sözleşmesi `serde` ile parse edildiği için `Option<T>` olmayan alanlar zorunludur; eksik bırakmak uygulamayı açtırmaz.

Keymap dosyalarını değiştirirken:

- Platform-spesifik dosyalar (`default-macos.json`, `default-linux.json`, `default-windows.json`) ayrı ayrı yönetilir. Aynı kısayolu üç platforma da eklemek için üç dosyayı da güncellemek gerekir.
- Editor emülasyon paketleri (`keymaps/macos/jetbrains.json` vb.) opsiyoneldir; kullanıcı `BaseKeymap` setting'i ile seçer.
- `initial.json` kullanıcının ilk keymap dosyası şablonudur; örnek kısayollar konulur ama hiçbir bağlayıcı kural yoktur.

---

## 9. Asset boyutunun binary üzerindeki etkisi

Release/debug-embed build'de asset'ler `RustEmbed` ile binary'ye gömüldüğü için her dosya binary boyutuna eklersin. Normal debug build'de dosyalar filesystem'den okunsa da release paket boyutu hesabı aynı asset kümesi üzerinden yapman gerekir. Tipik büyüklükler:

| Varlık türü | Tipik boyut | Adet | Toplam etki |
|-------------|-------------|------|-------------|
| Font (.ttf) | 100-200 KB | 8 dosya (Zed'de) | ~1.5 MB |
| Icon (.svg) | 1-5 KB | 280+ dosya | ~1 MB |
| Tema (.json) | 50-200 KB | 10+ dosya | ~1-2 MB |
| Ses (.wav) | 10-100 KB | 8 dosya | ~500 KB |

Toplam asset boyutu Zed binary'sinde 5-10 MB civarındadır. Bu, modern bir desktop uygulaması için kabul edilebilir bir bedeldir; ancak küçük binary'ler hedeflenirse:

- WAV dosyaları OGG/Opus'a dönüştürülebilir (yaklaşık 5-10 kat sıkıştırma).
- Font alt kümeleri (subset) oluşturulup yalnızca kullanılan karakterler tutulabilir.
- Tema dosyaları gzip'lenip runtime'da decompress edilebilir; bu trade-off başlatma süresinde milisaniyeler eklerken binary boyutunu küçültür.

Bu optimizasyonlar Zed'in yapmadığı tercihlerdir; release için standart davranış "seçilen asset kümesi ham olarak gömülür"dür.

---

## 10. Cargo crate sınırlarını sakin tutmak

Asset boru hattının crate organizasyonu net bir desene oturur:

- `crates/assets` — `Assets` struct'ı. Yalnızca `RustEmbed` macro'sunu çağırır; başka bir bağımlılık almaz.
- `crates/settings` — `SettingsAssets` struct'ı + keymap/settings default API'leri. `gpui` ve `assets`'ten bağımsızdır.
- `crates/icons` — `IconName` enum'u. Yalnızca `strum` ve `serde` üzerine kuruludur; başka bağımlılık almaz.
- `crates/theme` — `ThemeRegistry`, `Theme`. `gpui::AssetSource` ile çalışır ama `Assets` struct'ını bilmez.
- `crates/audio` — `Sound` enum'u + `Audio::play_sound`. `cx.asset_source()` üzerinden okur.
- `crates/ui` — `Icon`, `Vector` bileşenleri. `icons` ve `gpui` üzerine kurarsın.

Bu hiyerarşinin bozulması (örneğin `crates/icons`'a `gpui` dependency eklemek) iki sorun yaratır:

1. **Döngüsel bağımlılık riski.** `gpui` ileride `icons`'u kullanmak isterse cycle olur.
2. **Yeniden derleme maliyeti.** Düşük seviyede crate'lerin bağımlılıkları arttıkça incremental build maliyeti büyür.

Yeni bir asset türü eklerken doğru crate'i seçmek bu hiyerarşiyi korur.

---

## 11. Son kontrol listesi

Asset altyapısı çalıştırıldıktan sonra geçilmesi gereken son sağlamlık testleri:

- [ ] `with_assets(Assets)` çağrısı `Application::with_platform` zincirine eklenmiş mi?
- [ ] `load_embedded_fonts(cx)` window açılmadan **önce** çağrılıyor mu?
- [ ] `theme::init(LoadThemes::All(Box::new(Assets)), cx)` (veya muadili) ile tema sistemi başlatılmış mı?
- [ ] `settings::init(cx)` çağrısı önce yapılıp, sonra `default_settings()` ile varsayılanlar yüklü mü?
- [ ] Yeni eklenen her ikon için `IconName` varyantı var mı? Dosya adı snake_case mı?
- [ ] Yeni eklenen her ses için `Sound` enum'u, `Sound::file` match'i ve WAV dosyası senkron mu?
- [ ] Yeni eklenen her tema için JSON'da `appearance` doğru mu, LICENSE dosyası eklenmiş mi?
- [ ] Yeni font'lar için `.ttf` uzantısı ve OFL/lisans dosyası klasörde mi?
- [ ] Test ortamında asset gerekiyorsa `with_text_system_and_assets` (veya `with_asset_source`) çağrısı kullanılmış mı?
- [ ] Filesystem'den okunan path'ler için symlink ve canonicalization doğrulaması var mı?

Bu liste tamamlandığında asset boru hattı tipik üretim ve test senaryolarını karşılayacak şekilde kurulmuş olur.

---
