# 13. Text Sistemi

---

## 13.1. Text, Font ve Metin Ölçümü

GPUI'de metin tek bir "string"den ibaret değildir; renk, font ailesi, boyut, satır yüksekliği, dekorasyon, overflow gibi onlarca parametreyle bir araya gelir ve render sırasında platforma uygun glyph'lere dönüştürülür. Metnin parçaları farklı stillere sahip olabilir (örn. tek satırda farklı renkte iki kelime); bu parçalanmayı `TextRun` ve `HighlightStyle` tipleri tarif eder. Metin elementleri ise bu yapı taşlarını alır, `WindowTextSystem` üzerinden ölçer ve çizer.

Ana tipler `crates/gpui/src/text_system.rs`, `style.rs` ve `elements/text.rs` içinde tanımlıdır:

- **`TextStyle`** — Renk, font family, font size, line height, weight/style, decoration, whitespace, overflow, align, line clamp gibi tüm metin görsel parametrelerini taşır.
- **`HighlightStyle`** — Belirli aralıklara uygulanan kısmi stil (sadece bazı alanları override eder).
- **`TextRun`** — UTF-8 byte uzunluğu + font + renk/dekorasyon birleşimi. **Run'ların toplam uzunluğu metnin byte uzunluğunu tam karşılamalıdır;** açıkta kalan byte panic yaratır.
- **`StyledText`** — `SharedString` + run/highlight/font override ile render edilen metin elementi.
- **`InteractiveText`** — `StyledText`'in üstüne karakter/range bazlı tıklama, hover ve tooltip ekler.
- **`Font`, `FontWeight`, `FontStyle`, `FontFeatures`, `FontFallbacks`** — Font seçimi ve özelliklerini tanımlayan tipler.

### Tipik kullanım

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

Burada `0..5` aralığı (`"Error"` kelimesi) kırmızı ve bold; geri kalan kısım parent'tan miras alınan stil ile çizilir.

### Metin ölçümü ve layout

- **`window.text_style()`** — Aktif inherited text style'ını verir.
- **`window.text_system()`** — Pencereye bağlı `WindowTextSystem`'a erişir.
- **`App::text_system()`** — Global text system'a erişir.
- **`TextStyle::to_run(len)`** — Inherited style'dan `TextRun` üretir.
- **`TextStyle::line_height_in_pixels(rem_size)`** — Line-height değerini piksele çevirir.
- **`window.line_height()`** — Aktif text style'a göre satır yüksekliği.

### Tuzaklar

- **Highlight aralıkları byte aralığıdır;** UTF-8 karakter sınırlarına denk gelmek zorundadır. Çok-byte'lı karakter ortasına denk gelen aralık panic'e yol açar.
- **`SharedString` kopyalamayı azaltır;** render child'larında `String` yerine `SharedString` kullanmak her frame allocation'ını engeller (bkz. 5.4).
- **`text_ellipsis`, `line_clamp`, `white_space` gibi overflow davranışları layout genişliğine bağlıdır;** parent genişliği belirsizse (örn. `flex` içinde `min-w-0` verilmemişse) truncation beklendiği gibi çalışmaz.
- **Uygulama genel text rendering modu `cx.set_text_rendering_mode(...)`** ile `PlatformDefault`, `Subpixel`, `Grayscale` arasında seçilir. Subpixel akışı her glyph için yatayda `gpui::SUBPIXEL_VARIANTS_X: u8 = 4`, dikeyde `gpui::SUBPIXEL_VARIANTS_Y: u8 = 1` farklı varyant rasterize eder (`text_system.rs:45,48`); yani glyph atlas boyutu yatay subpixel pozisyonuna duyarlı, dikey değildir.

## 13.2. StyledText, TextLayout ve InteractiveText

Basit, tek stilli metin `SharedString` olarak `.child(...)` çağrısına geçirilebilir; karmaşıklaştıkça (highlight, font override, tıklanabilir aralık, hover, tooltip) sırasıyla `StyledText` ve `InteractiveText` element tipleri kullanılır. Bu bölüm her birinin sağladığı yüzeyleri ve ortak ölçüm sonucu olan `TextLayout` tipini açıklar.

### `StyledText`

```rust
let text = StyledText::new("Open settings")
    .with_highlights(vec![(0..4, highlight_style)])
    .with_font_family_overrides(vec![(5..13, "ZedMono".into())]);

let layout = text.layout().clone();
```

Önceden hesaplanmış `TextRun` listesi varsa `.with_highlights(...)` yerine `.with_runs(runs)` kullanılır — bu, run'ları her render'da yeniden üretmek yerine cache'lenmiş bir sonuçtan inşa etmek için uygundur. `.with_default_highlights(&default_style, ranges)` ise parent stil yerine açıkça verilen bir `TextStyle`'ı baz alır.

### `TextLayout` — ölçüm sonucu

Ölçüm/prepaint sonrası elde edilen `TextLayout`, metnin ekrandaki gerçek konum bilgisini taşır. Click/hover gibi event handler'lar bu bilgiyi kullanır:

- **`index_for_position(point) -> Result<usize, usize>`** — Piksel pozisyonundan UTF-8 byte index'i (mouse'un hangi karakter üzerinde olduğunu bulmak için).
- **`position_for_index(index) -> Option<Point<Pixels>>`** — Byte index'ten piksel konumu (cursor çizimi için).
- **`line_layout_for_index(index)`, `bounds()`, `line_height()`, `len()`, `text()`, `wrapped_text()`** — Satır, bounds ve metin meta verileri.

**Önemli:** `TextLayout` değerleri layout/prepaint yapılmadan okunursa panic edebilir; bu nedenle event handler ve after-layout path'inde kullanılır, render sırasında henüz ölçülmemiş layout'a güvenilmez.

### `InteractiveText`

`StyledText`'in üstüne tıklama, hover ve tooltip ekler. Tipik kullanım — bir bağlantı (link) metni:

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

Verilen aralıklar **byte index aralığıdır**; Unicode metinlerde karakter sınırlarını yanlış hesaplamak hover/click eşleşmesini bozar. Ayrıca `on_click` listener'ı yalnızca **mouse down ve mouse up aynı aralık içinde kaldığında** çalışır — bu, kullanıcının drag yaparken tıklamayı iptal etmesine olanak verir.


---

