# Metin Sistemi

## Sürüm Analiz Raporu

- [x] Doğrulanan metin yüzeyi: `LineWrapper::is_word_char` kapsamındaki non-breaking glue karakterleri ve satır sarma davranışı.
- [x] Kaynak doğrulama dosyası: `crates/gpui/src/text_system/line_wrapper.rs`.
- [x] Güncel doğrulama: `MarkdownElement` link içindeki görsellerde tıklama hedefini çevreleyen bağlantıya yönlendirir; tekil görsel fallback'i görsel URL'sini açar.

---

## Metin, Font ve Ölçüm

GPUI metin sisteminin temel veri yapıları `gpui` paketi, `style` modülü ve `elements/text` bileşenleri altında toplanmıştır. Metinlerin ekrana doğru ve net biçimde çizilebilmesi için stil, yazı tipi (font) ve ölçüm veri yapıları bütünleşik bir hiyerarşide çalışır:

![GPUI Metin Sistemi Bileşen Hiyerarşisi](assets/metin-sistemi-hiyerarsisi.svg)

- `TextStyle`: Yazı rengi, yazı tipi ailesi, boyutu, satır yüksekliği, kalınlık (weight), stil (italik vb.), metin dekorasyonları (alt çizgi vb.), harf boşlukları, taşma ve hizalama kuralları gibi metnin genel görsel niteliklerini tanımlar.
- `HighlightStyle`: Metnin belirli byte aralıklarına uygulanacak kısmi (`partial`) biçimlendirmeleri temsil eder; temel metin stilinin (base style) üzerine bindirilir.
- `TextRun`: Belirli bir metin parçasının UTF-8 byte uzunluğunu, ilişkili fontunu ve renk/dekorasyon detaylarını taşır. Ağaçtaki tüm run yapılarının uzunluk toplamı, metnin byte uzunluğuyla tam olarak eşleşmek zorundadır.
- `StyledText`: Bir `SharedString` metnini; run tanımları, stil vurguları ve yazı tipi ezmeleriyle bir araya getirerek ekranda çizer.
- `InteractiveText`: Karakter veya belirli aralıklar bazında fare tıklamaları, hover (üzerine gelme) etkileşimleri ve ipucu (tooltip) davranışları sunar.
- `Font`, `FontWeight`, `FontStyle`, `FontFeatures`, `FontFallbacks`: Yazı tipi seçimlerini ve OpenType özelliklerini yapılandırmada rol alan yardımcı veri modelleridir.

| Yapı / Tip | Desteklenen Nitelikler | Temel İşlevi |
| :-- | :-- | :-- |
| `TextRun` | `len`, font/stil/vurgu alanları | `StyledText` bünyesinde belirli byte aralıklarına özgü görsel stil ve font tanımlarını taşır; toplam run uzunluğunun metnin byte uzunluğuyla tutarlı olması zorunludur. |

Metin stilleri ile vurgu aralıklarının birleşimi pratik olarak şu şablonda kodlanır:

```rust
let metin = StyledText::new("Hata: eksik alan")
    .with_highlights([(0..5, HighlightStyle {
        color: Some(rgb(0xff0000).into()),
        font_weight: Some(FontWeight::BOLD),
        ..Default::default()
    })]);

div()
    .text_size(rems(0.875))
    .font_family(".SystemUIFont")
    .line_height(relative(1.4))
    .child(metin)
```

**Metin Ölçümü ve Yerleşim.** Metnin kapladığı alanlar ve aktif stil verileri şu pencereler arası arayüzler vasıtasıyla sorgulanır:

- `window.text_style()`: O anki element hiyerarşisinde devralınan (inherited) aktif metin stilini döndürür.
- `window.text_system()`: Pencereye bağlı olan `WindowTextSystem` örneğini sağlar.
- `App::text_system()`: Uygulama genelindeki global `TextSystem` yapısına erişim sunar.
- `TextStyle::to_run(len)`: Devralınan stili referans alarak yeni bir run parçası üretir.
- `TextStyle::line_height_in_pixels(rem_size)`: Satır yüksekliği (line-height) değerini piksel cinsine dönüştürür.
- `window.line_height()`: Aktif metin stiline göre hesaplanan güncel satır yüksekliğini verir.

**`TextSystem` Ölçüm Katmanı.** `TextSystem` yapısı, yerel işletim sistemi metin motorunun ve yazı tipi önbelleklerinin asıl yöneticisidir. `TextSystem::new(platform_text_system)` çağrısı yalnızca düşük seviyeli platform testlerinde veya FFI entegrasyonlarında tercih edilir; standart kod akışında ise bu sisteme `App::text_system()` veya `Window::text_system()` üzerinden erişilir. Sistem bünyesindeki ölçüm metotları şu şekilde sınıflandırılır:

- **Font Keşfi ve Çözümleme:** `all_font_names()`, `add_fonts(...)`, `resolve_font(...)` ve `get_font_for_id(...)`.
- **Glif (Glyph) ve Satır Ölçümü:** `bounding_box(...)`, `typographic_bounds(...)`, `advance(...)` ve `layout_width(...)`.
- **Em/Ch Ölçümleri:** `em_width(...)`, `em_advance(...)`, `ch_width(...)` ve `ch_advance(...)`.
- **Font Metrikleri:** `units_per_em(...)`, `cap_height(...)`, `x_height(...)`, `ascent(...)`, `descent(...)` ve `baseline_offset(...)`.
- **Metin Satır Sarma Altyapısı:** `line_wrapper(...)` fonksiyonu, aynı font ailesi ve yazı boyutu için önbellek havuzundan (wrapper pool) en uygun `LineWrapper` nesnesini çeker.

Bu metotlar; özel bir kod editörü, metin ölçüm havuzları veya özel metin render motorları tasarlanırken değerlidir. Standart metin etiketlerinde veya paragraflarda `div().child(...)`, `StyledText` veya `InteractiveText` yapıları ile fluent stil metotlarının kullanılması önerilir.

**`WindowTextSystem` Yapısı.** Pencere bağlamına bağlı olan bu sistem; `shape_line(...)`, `shape_line_by_hash(...)`, `shape_text(...)`, `layout_line(...)`, `try_layout_line_by_hash(...)`, `layout_line_by_hash(...)`, `layout_width(...)` ve `em_layout_width(...)` metotlarıyla metin şekillendirme (text shaping) ve layout önbelleklerini koordine eder. Hash değerine göre çalışan varyantlar, aynı metin ve stil ikilisi tekrar ölçüldüğünde hesaplama yapmadan önbelleği (layout cache) devreye sokar. Metin ölçümlerinin ekran karesine veya pencerenin aktif ölçeğine (dpi scale) bağlı olduğu senaryolarda `WindowTextSystem` tercih edilmelidir; genel yazı tipi keşiflerinde ise `TextSystem` yapısı yeterlidir.

**Yazı Tipi (Font) Yardımcıları.** Halka açık `Font` veri modelinde `family` birincil font ailesi adını, `features` OpenType özellik setini, `fallbacks` kullanıcı yedek font zincirini, `style` ve `weight` ise fontun italik/kalınlık varyantlarını taşır. `Font::bold()` ve `Font::italic()` metotları mevcut font modeline kalınlık veya italik varyantlarını uygular. `FontFallbacks::from_fonts(...)` yedek font zincirleri oluştururken, `fallback_list()` ise bu listeyi okur. `FontFeatures::disable_ligatures()`, `tag_value_list()` ve `is_calt_enabled()` işlevleri OpenType ligatür (bitişik harf) listelerini yönetir; bu özellikler kod editörleri gibi ligatür etkileşimlerinin hassas yönetildiği alanlarda önem taşır. Standart arayüz tasarımlarında bu detaylar doğrudan tema ayarlarına bırakılır.

**Performans İpucu: `SharedString`.** GPUI, metin kabul eden birçok API metodunda `SharedString` yapısını kullanır. Bu veri tipi `gpui_shared_string` paketi altında tanımlıdır ve arka planda `SmolStr` ile desteklenen, kopyalama maliyeti son derece düşük (cheaply cloneable) bir metin taşıyıcısıdır. Bir bileşende aynı metin etiketi birden fazla render döngüsünde kullanılıp alt bileşenlere aktarıldığında, her seferinde yeni bir `String` üretmek yerine mevcut `SharedString` referansı klonlanır. Bu nedenle, görünümlerin metin barındıran alanlarının `SharedString` tipinde tanımlanması ve parametre kabul edilirken `"Kaydet".into()` kısayolundan yararlanılması önerilir:

```rust
struct EtiketGorunumu {
    metin: SharedString,
}

impl EtiketGorunumu {
    fn metni_guncelle(&mut self, yeni_metin: impl Into<SharedString>, cx: &mut Context<Self>) {
        self.metin = yeni_metin.into();
        cx.notify(); // Değişikliği ekrana yansıtmak amacıyla
    }
}

impl Render for EtiketGorunumu {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        div().child(self.metin.clone())
    }
}
```

Metot imzalarındaki `impl Into<SharedString>` yapısı sadece bir yazım kolaylığı sunmakla kalmaz; aynı zamanda `&'static str`, `String` veya mevcut bir `SharedString` değerinin herhangi bir ek işleme gerek kalmaksızın doğrudan kabul edilmesini sağlar. Statik metinlerde string literal atamaları yeterliyken; görünüm alanlarında saklanan veya sıkça kopyalanan metinlerde `SharedString` kullanılması bellek kopyalamalarını minimuma indirir.

**Dikkat Edilmesi Gereken Hususlar.** Metin sistemleri yapılandırılırken gözden kaçabilecek kritik detaylar şunlardır:

- Görsel vurgu (highlights) ve yazı tipi ezme (override) aralıkları byte aralıkları cinsinden ifade edilir. Bu aralıkların UTF-8 karakter sınırlarına tam oturması zorunludur. `with_highlights(...)` ve `with_font_family_overrides(...)` metodları hatalı sınır tanımlarını hata ayıklama derlemelerinde `debug_assert!` ile yakalar; `with_runs(...)` çağrısı ise run uzunluklarının metni tam olarak tüketmediği durumlarda `panic` hatasına yol açar. Çok dilli metin yapılarında karakter veya grapheme sınırlarının byte sınırlarına dönüşümü el ile ve dikkatlice yapılmalıdır.
- `SharedString` bellek kopyalama maliyetlerini düşürür; bu yüzden çizim hiyerarşisindeki alt öğelerde `String` yerine bu tip tercih edilmelidir.
- `text_ellipsis`, `text_ellipsis_start`, `text_ellipsis_middle`, `line_clamp` ve `white_space` gibi metin taşma (overflow) davranışları doğrudan elementlerin yerleşim genişliklerine bağlıdır. Üst öğenin genişliği belirsiz kaldığında metin kırpma işlemleri beklendiği gibi çalışmaz.
- Metinlerin sonuna üç nokta (`...`) eklenerek yapılan kırpmalarda, kırpma sınırındaki boşluklar ve ASCII noktalama işaretleri otomatik temizlenir; böylelikle `"başlık -..."` yerine çok daha temiz `"başlık..."` çıktısı elde edilir. Metnin başlangıcından itibaren kırpma yapılması hedeflendiğinde ise `TruncateFrom::Start` yapılandırması tercih edilmelidir.
- Dosya adı, yol, branch veya sekme başlığı gibi hem başlangıç hem de son kısmı anlam taşıyan metinlerde `text_ellipsis_middle()` kullanılır. Bu metot arka planda `TextOverflow::TruncateMiddle(ELLIPSIS)` değerini yazar ve `"uzun-dosya-adi.rs"` gibi değerleri kapsayıcı genişliğine göre `"uzun-...adi.rs"` biçimine yaklaştırır. Baştan kırpma yalnız son segment önemliyse, ortadan kırpma ise uzantı veya ayırt edici son ek korunacaksa daha uygundur.
- Satır sarma hesabında `NNBSP` (`U+202F`), `NBSP` (`U+00A0`) ve kırılmaz tire (`U+2011`) kelime parçalarını birbirine bağlayan karakterler olarak değerlendirilir; bu karakterlerin çevresinde normal boşluk gibi satır kırma yapılmaz.
- `line_clamp` ile `wrap_width` nitelikleri birlikte etkinleştirildiğinde `LineWrapper::truncate_wrapped_line` işlevi devreye girer. Bu mekanizma kırpma noktasını kelime sınırlarını da hesaba katarak hesaplar: Satırları tek bir geçişte işlerken hem sarım (wrapping) sınırlarını hem de kırpma noktalarını eş zamanlı takip eder; dolayısıyla kırpma işlemi basit bir piksel boyutu bütçesiyle değil, gerçek görsel sarım düzenine göre hizalanır. Kelime sınırlarında satır sarma işlemi yalnızca son satırdan önceki satırlarda etkindir. Son satırdaki kesmeler kelime sınırına uymayabilir; üç noktanın sığabileceği son karaktere kadar kesme yapılır ve ardıl boşluklar temizlenir.
- Uygulamanın genel metin render kipi `cx.set_text_rendering_mode(...)` aracılığıyla `PlatformDefault`, `Subpixel` ve `Grayscale` modları arasında değiştirilebilir. Subpixel akışı tercih edildiğinde, her bir glif için yatay eksende `gpui::SUBPIXEL_VARIANTS_X: u8 = 4`, dikey eksende ise `gpui::SUBPIXEL_VARIANTS_Y: u8 = 1` farklı varyant çizim atlasında rasterize edilir; yani glif atlası boyutu yatay subpixel konumuna duyarlıdır.
- Linux WGPU tabanlı metin motorunda (`CosmicTextSystem`), `Font.fallbacks` yedek font listesi önbellek anahtarına dahil edilir ve `layout_line` aşamasında yedek yazı tipleri grapheme cluster sınırları korunarak uygulanır. ASCII karakterlerinde her zaman birincil yazı tipi tercih edilirken, combining mark ve ZWJ emoji cluster'ları yedek font sınırlarında bölünmez.

## `StyledText`, `TextLayout` ve `InteractiveText`

Yalın metinler doğrudan `SharedString` formatında bir elementin alt öğesi (`.child(...)`) olarak ağaca eklenebilir. Ancak gelişmiş ölçüm operasyonları, aralık vurgulamaları, yazı tipi ezmeleri (overrides) veya tıklanabilir metin bölgeleri gerektiğinde `StyledText`; fare tıklamaları ve üzerine gelme (hover) olaylarında ise `InteractiveText` devreye girer.

**`StyledText` Kullanım Şablonu.** Metin vurguları ve yazı tipi ezmeleri (overrides) akıcı metotlar yardımıyla yapılandırılır:

```rust
let metin = StyledText::new("Ayarları aç")
    .with_highlights(vec![(0..9, vurgu_stili)])
    .with_font_family_overrides(vec![(0..13, "ZedMono".into())]);

let yerlesim = metin.layout().clone();
```

Önceden hesaplanmış `TextRun` listesi mevcut olduğunda, vurguları sonradan dinamik eklemek yerine doğrudan `.with_runs(runs)` metodu çağrılabilir. `with_default_highlights(&default_style, ranges)` ise üst öğenin stili yerine doğrudan iletilen bir `TextStyle` referansını baz alarak run parçaları üretir.

**Metin Yerleşimi (`TextLayout`).** Yerleşim (layout) veya prepaint aşamaları tamamlandıktan sonra elde edilen yerleşim nesnesi, metin koordinatları üzerinde şu sorguların yapılmasına olanak tanır:

- `index_for_position(point) -> Result<usize, usize>`: Piksel bazlı konum koordinatından metnin UTF-8 byte indeksini hesaplar.
- `position_for_index(index) -> Option<Point<Pixels>>`: Metnin byte indeksinden piksel koordinat karşılığını üretir.
- `line_layout_for_index(index) -> Option<Arc<WrappedLineLayout>>`: Verilen byte indeksini içeren satırın sarılmış yerleşim nesnesini döndürür.
- `line_layouts() -> SmallVec<[Arc<WrappedLineLayout>; 1]>`: Tüm satır yerleşimlerini kaynak sırasıyla döndürür; çok satırlı ölçüm, hit-test veya özel editor çizimlerinde toplu satır bilgisi gerektiğinde kullanılır.
- `bounds()`, `line_height()`, `len()`, `text()` ve `wrapped_text()` sorgularını yürütür.

`TextLayout` verileri yerleşim veya prepaint aşamaları tamamlanmadan önce okunmaya çalışılırsa çalışma zamanında hataya (`panic`) yol açabilir. Bu nedenle, ölçüm sonuçlarına bağımlı olan kod blokları olay işleyicileri (event handlers) veya yerleşim sonrası akışlarda çalıştırılmalıdır.

**Satır ve Sarma Alt Veri Yapıları:**

- `FontId`, `FontFamilyId`, `GlyphId`, `RenderGlyphParams` ve `GlyphRasterData`: Glif rasterizasyon kimlikleri ve alt parametreleridir; uygulama durum verisi olarak saklanmamalıdır.
- `FontMetrics`: `ascent()`, `descent()`, `line_gap()`, `underline_position()`, `underline_thickness()`, `cap_height()` ve `x_height()` metotlarıyla yazı tipinin metrik detaylarını sağlar.
- `ShapedLine`: `len()`, `width()`, `paint()`, `paint_background()` ve `split_at()` metotlarıyla şekillendirilmiş tek bir satırı yönetir.
- `WrappedLine`: `len()`, `paint()` ve `paint_background()` metotlarıyla ekrana sarılmış satır çıktısını çizer.
- `LineLayout`: `index_for_x(...)`, `closest_index_for_x(...)` ve `x_for_index(...)` metotlarıyla tek bir satır üzerinde piksel ile byte indeksi arasındaki dönüşümleri hesaplar.
- `WrappedLineLayout`: `len()`, `width()`, `size()`, `wrap_boundaries()`, `index_for_position(...)` ve `position_for_index(...)` metotlarıyla çok satırlı yerleşim detaylarını sorgular.
- `LineWrapper`: `wrap_line()`, `should_truncate_line()` ve `truncate_line()` metotlarıyla metin sarma ve kırpma sınırlarını belirler. Satır sarma işlemlerinde uygulanabilecek girinti sınırı `LineWrapper::MAX_INDENT` sabitiyle 256 piksel olarak sınırlandırılmıştır; bu sınır yerleşim hesaplamalarının taşmasını (layout overflow) engellemek amacıyla konulmuştur. Kelime karakteri sınıflandırması ASCII/Latin/Cyrillic/Bengali aralıklarının yanında dar bölünmez boşluk `U+202F`, bölünmez boşluk `U+00A0` ve bölünmez tire `U+2011` karakterlerini de kapsar; bu karakterler iki yanındaki metni aynı kelime grubu içinde tutar.

`LineLayoutCache`, aynı satır yerleşimlerini ekran karesi çizimi (frame) sırasında yeniden kullanan dahili bir önbellek yapısıdır; uygulama kodlarında doğrudan çağrılması gerekmez. Yüksek hacimli metin ölçüm gereksinimlerinde veya özel metin editörü tasarımlarında `WindowTextSystem` arayüzünün sunduğu `layout_line(...)`, `shape_line(...)` veya bunların hash tabanlı varyantları (`layout_line_by_hash(...)`, `shape_line_by_hash(...)`) tercih edilmelidir.

**Unicode Sınır Yönetimi.** `LineFragment`, `WrapBoundary`, `ShapedRun` ve `FontRun` gibi yapılar metnin Unicode ve font run parçalarını taşır. Çok dilli metin yapılarında string dilimleme (slice) işlemlerinin doğrudan ham byte sınırları üzerinden yapılması hatalı sonuçlar doğurabileceğinden, aralıkların Unicode standartlarına ve grapheme sınırlarına uygunluğu gözetilmelidir.

Satır sarma sırasında bölünmez boşluk ve bölünmez tire ailesi normal boşluk gibi kırılma noktası oluşturmaz. Bu davranış; para birimi, ölçü birimi, kısaltma veya birleşik etiket gibi birlikte kalması gereken metin parçalarının dar kapsayıcılarda ayrışmasını engeller. Genişliği aşan çok uzun bir birliktelikte GPUI yine görsel sınırı korumak için zorunlu kırpma veya taşma kurallarına döner; ancak kelime sınırı adayı olarak bu glue karakterlerini seçmez.

**`InteractiveText` Yapısı.** Metne fare tıklamaları, hover durumları ve ipuçları ekleyen dinamik bir sarmalayıcıdır:

```rust
InteractiveText::new("ayarlar-baglantisi", StyledText::new("Ayarları aç"))
    .on_click(vec![0..13], |_aralik_sirasi, window, cx| {
        window.dispatch_action(AyarlariAc.boxed_clone(), cx);
    })
    .on_hover(|sira, olay, window, cx| {
        ustune_gelmeyi_guncelle(sira, olay, window, cx);
    })
    .tooltip(|sira, window, cx| ipucu_olustur(sira, window, cx))
```

Aralık tanımları byte indeks aralıklarıdır; Unicode metinlerde karakter sınırlarının yanlış hesaplanması tıklama ve hover olaylarının çakışmasına sebep olur. `.on_click` dinleyicisi, yalnızca fareye basılma (mouse down) ve fareyi bırakma (mouse up) eylemlerinin her ikisi de aynı tanımlanan byte aralığı içerisinde gerçekleştiğinde tetiklenir.

**Markdown Çizim Standartları.** Markdown dökümanlarının çizimi, metin sistemi üzerinde şu özel kurallara tabidir:

- Görsellerin çiziminde `StyledImage::with_fallback` yapısı tercih edilir. Tek başına duran yüklenemeyen görsellerde fallback alanı görsel URL'sini `cx.open_url` ile açar. Görsel bir markdown linkinin içindeyse yüklenen görsel ve fallback aynı sarmalayıcıdan çevreleyen link URL'sine gider; özel `on_url_click` handler'ı varsa önce o çalışır, yoksa `cx.open_url` kullanılır.
- Mermaid şema blokları yalnızca mühürlü fenced block (` ```mermaid `) formatındaysa veya dosya uzantıları `.mermaid`/`.mmd` olarak belirtilmişse grafik olarak render edilir. Çizimin henüz tamamlanmadığı veya başarısız olduğu durumlarda kaynak kod görünümü yedek olarak ekranda sergilenir.
- `CodeBlockRenderer::Default` yapısı; kod bloklarının kopyalama ve satır sarma butonlarının görünürlük kurallarını yönetir:

```rust
CodeBlockRenderer::Default {
    copy_button_visibility: CopyButtonVisibility::VisibleOnHover,
    wrap_button_visibility: WrapButtonVisibility::Hidden,
    border: false,
}
```

Kullanıcı satır sarma butonuna tıkladığında, `Markdown` veri modelinin `wrapped_code_blocks` kümesi güncellenir ve kod bloğu yatay kaydırma çubuğu (horizontal scroll) yerine kelime sarma (word wrap) moduna geçer.

- `.on_code_span_link` metoduyla satır içi kod bloklarına bağlantılar eklenebilir:

```rust
MarkdownElement::new(markdown, style)
    .on_code_span_link(|metin, _cx| {
        if metin.starts_with("fn ") {
            Some(format!("docs://api/{metin}").into())
        } else {
            None
        }
    })
```

Geri çağrı fonksiyonunun bir adres (`SharedString`) döndürdüğü durumlarda bağlantı stili, `None` döndürdüğünde ise standart kod stili uygulanır.

- `Markdown::first_code_block_language()` metodu, döküman içerisindeki ilk fenced kod bloğunun dilini `Option<Arc<Language>>` olarak döndürür; özellikle içeriklerin ilgili dil sunucularına iletilmesinde ve doğru sözdizimi vurgulamalarının (syntax highlighting) seçilmesinde kullanılır.
