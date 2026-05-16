# Metin Sistemi

---

## Text, Font ve Metin Ölçümü

Metin sisteminin ana tipleri `crates/gpui/src/text_system.rs`, `style.rs` ve
`elements/text.rs` içinde toplanır. Bir metni doğru çizebilmek için stil,
font ve ölçüm tipleri birlikte çalışır; her birinin sorumluluğu birbirinden
ayrıdır:

- `TextStyle` — renk, font family, font size, line height, weight/style,
  decoration, whitespace, overflow, align ve line clamp gibi metin
  genelindeki görünüm parametrelerini taşır.
- `HighlightStyle` — belirli aralıklara uygulanacak kısmi (partial) stildir;
  base style'ın üstüne biner.
- `TextRun` — UTF-8 byte uzunluğu + font + renk/dekorasyon bilgisini taşır.
  Run'ların toplam uzunluğu metnin byte uzunluğunu tam olarak karşılamak
  zorundadır.
- `StyledText` — `SharedString` ile birlikte run, highlight ve font
  override'larını birleştirerek render edilir.
- `InteractiveText` — karakter veya aralık bazlı click, hover ve tooltip
  davranışı sağlar.
- `Font`, `FontWeight`, `FontStyle`, `FontFeatures`, `FontFallbacks` —
  font seçimi ve özelliklerini tanımlayan yardımcı tiplerdir.

Pratikte stil + highlight birleşimi şu kalıbı çıkarır:

```rust
let text = StyledText::new("Error: missing field")
    .with_highlights([(0..5, HighlightStyle {
        color: Some(rgb(0xff0000).into()),
        font_weight: Some(FontWeight::BOLD),
        ..Default::default()
    })]);

div()
    .text_size(rems(0.875))
    .font_family(".SystemUIFont")
    .line_height(relative(1.4))
    .child(text)
```

**Metin ölçümü ve layout.** Metnin yer kaplama biçimi ve aktif stilin değeri
aşağıdaki noktalardan okunur:

- `window.text_style()` — o anda kalıtılan (inherited) aktif metin stilini
  verir.
- `window.text_system()` — pencereye bağlı `WindowTextSystem` örneği.
- `App::text_system()` — global text system'a erişimi sağlar.
- `TextStyle::to_run(len)` — kalıtılan stilden run üretir.
- `TextStyle::line_height_in_pixels(rem_size)` — line-height değerini
  piksele çevirir.
- `window.line_height()` — aktif metin stiline göre satır yüksekliğini
  döndürür.

**Tuzaklar.** Metin sisteminde dikkat edilmesi gereken birkaç önemli nokta:

- Highlight range'leri byte aralığıdır; mutlaka UTF-8 karakter sınırlarına
  oturmalıdır. Çok-byte'lı karakterlerin ortasına denk gelen range hata
  üretir.
- `SharedString` kopyalama maliyetini azaltır; render child'larında `String`
  yerine bu tip tercih edilir.
- `text_ellipsis`, `line_clamp` ve `white_space` gibi overflow davranışları
  layout genişliğine bağlıdır; parent'ın genişliği belirsizse truncation
  beklenen biçimde çalışmaz.
- Uygulamanın genel metin rendering modu `cx.set_text_rendering_mode(...)`
  ile `PlatformDefault`, `Subpixel` ve `Grayscale` arasında seçilir.
  Subpixel akışında her glyph için yatayda
  `gpui::SUBPIXEL_VARIANTS_X: u8 = 4`, dikeyde
  `gpui::SUBPIXEL_VARIANTS_Y: u8 = 1` farklı varyant rasterize edilir
  (`text_system.rs:45,48`); başka bir deyişle glyph atlas boyutu yatay
  subpixel pozisyonuna duyarlıdır, dikey pozisyonda değildir.
- WGPU/Linux metin backend'i (`CosmicTextSystem`) `Font.fallbacks` değerini
  font cache anahtarına dahil eder ve `layout_line` içinde kullanıcı
  fallback zincirini grapheme cluster sınırlarını koruyarak uygular. ASCII
  karakterlerinde primary font tercih edilir; combining mark ve ZWJ emoji
  cluster'ları fallback span'inin içinde bölünmez. Custom font fallback
  ayarı debug edilirken yalnız family adı değil fallback listesi de
  cache/ölçüm girdisi sayılmalıdır.

## StyledText, TextLayout ve InteractiveText

Basit bir metin doğrudan `SharedString` olarak bir element'in child'ı
verilebilir. Ölçüm, highlight, font override veya tıklanabilir aralık
gerektiğinde `StyledText` devreye girer; tıklama ve hover gerekiyorsa
`InteractiveText`'e geçilir.

**`StyledText` kullanımı.** Highlight ve font override'lar fluent zincire
eklenir:

```rust
let text = StyledText::new("Open settings")
    .with_highlights(vec![(0..4, highlight_style)])
    .with_font_family_overrides(vec![(5..13, "ZedMono".into())]);

let layout = text.layout().clone();
```

Önceden hesaplanmış `TextRun` listesi varsa highlight'ı geç (delayed) uygulamak
yerine `.with_runs(runs)` çağrısı yapılır; `with_default_highlights(&default_style, ranges)`
ise parent style yerine açık bir `TextStyle`'ı baz alarak run üretir.

**Ölçüm sonrası `TextLayout`.** Layout veya prepaint tamamlandıktan sonra elde
edilen layout nesnesi metin koordinatları üzerinde sorgu yapmaya izin verir:

- `index_for_position(point) -> Result<usize, usize>` — piksel pozisyonundan
  UTF-8 byte index'i.
- `position_for_index(index) -> Option<Point<Pixels>>` — byte index'ten
  piksel koordinatı.
- `line_layout_for_index(index)`, `bounds()`, `line_height()`, `len()`,
  `text()`, `wrapped_text()`.

`TextLayout` değerleri layout veya prepaint tamamlanmadan okunursa panic
üretebilir; bu nedenle ölçüm sonuçlarına ihtiyaç duyan kod event handler veya
after-layout yolunda çalışır. Render sırasında henüz ölçülmemiş bir layout'a
güvenilmez.

**`InteractiveText`.** Tıklama, hover ve tooltip ekleyen sarmalayıcıdır:

```rust
InteractiveText::new("settings-link", StyledText::new("Open settings"))
    .on_click(vec![0..13], |range_index, window, cx| {
        window.dispatch_action(OpenSettings.boxed_clone(), cx);
    })
    .on_hover(|index, event, window, cx| {
        update_hover(index, event, window, cx);
    })
    .tooltip(|index, window, cx| build_tooltip(index, window, cx))
```

Aralıklar yine byte index aralıklarıdır; Unicode metinde karakter sınırlarını
yanlış hesaplamak hover ve click eşleşmesini bozar. `on_click` yalnızca mouse
down ile mouse up aynı verilen range içinde kaldığında listener'ı tetikler;
yani bir aralıkta basıp başka bir aralıkta bırakmak click sayılmaz.

**Markdown render davranışı.** Markdown ekosistemi metin sisteminin üzerine
özel davranışlar bindirir; bunların bilinmesi sürpriz davranışları azaltır:

- Markdown image render'ı `StyledImage::with_fallback` kullanarak
  yüklenemeyen görsel için tıklanabilir bir "Failed to Load: ..." fallback'i
  üretir. Fallback label'ı önce alt text'i, yoksa hedef URL'yi kullanır; click
  ile `cx.open_url` çağrılır.
- Mermaid kod blokları yalnızca kapalı fenced block formatındaysa diyagram
  olarak çıkarılır. ` ```mermaid` etiketinin yanı sıra `.mermaid` veya
  `.mmd` uzantılı kaynak yolu işaret edilen bloklar da diyagram olarak
  sayılır.
- Mermaid diyagram UI'ı preview ve code tab'larını, ayrıca kopyalama
  butonunu gösterebilir; render başarısızsa veya henüz tamamlanmadıysa
  kaynak kodu görünümü fallback olarak çizilir.

---
