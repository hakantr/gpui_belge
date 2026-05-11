# 13. Metin Sistemi

---

## 13.1. Text, Font ve Metin Ölçümü

GPUI'de metin tek bir "string"den ibaret değildir; renk, font ailesi, boyut, satır yüksekliği, dekorasyon ve taşma davranışı gibi birçok parametreyle birlikte değerlendirilir. Render sırasında platforma uygun glyph'lere dönüştürülür. Metnin parçaları farklı stillere sahip olabilir (örn. tek satırda farklı renkte iki kelime); bu parçalanmayı `TextRun` ve `HighlightStyle` tipleri tarif eder. Metin UI öğeleri bu yapı taşlarını alır, `WindowTextSystem` üzerinden ölçer ve çizer.

Ana tipler `crates/gpui/src/text_system.rs`, `style.rs` ve `elements/text.rs` içinde tanımlıdır:

- **`TextStyle`** — Renk, font ailesi, font boyutu, satır yüksekliği, ağırlık/stil, dekorasyon, boşluk, taşma, hizalama ve satır sınırlama gibi tüm metin görsel parametrelerini taşır.
- **`HighlightStyle`** — Belirli aralıklara uygulanan kısmi stil (sadece bazı alanları override eder).
- **`TextRun`** — UTF-8 byte uzunluğu + font + renk/dekorasyon birleşimi. **Run'ların toplam uzunluğu metnin byte uzunluğunu tam karşılamalıdır;** açıkta kalan byte panic yaratır.
- **`StyledText`** — `SharedString` + run/highlight/font override ile render edilen metin UI öğesi.
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

Burada `0..5` aralığı (`"Error"` kelimesi) kırmızı ve bold çizilir; geri kalan kısım üst UI öğesinden miras alınan stil ile çizilir.

### Metin ölçümü ve layout

- **`window.text_style()`** — Aktif miras alınmış metin stilini verir.
- **`window.text_system()`** — Pencereye bağlı `WindowTextSystem`'a erişir.
- **`App::text_system()`** — Global text system'a erişir.
- **`TextStyle::to_run(len)`** — Miras alınmış stilden `TextRun` üretir.
- **`TextStyle::line_height_in_pixels(rem_size)`** — Satır yüksekliği değerini piksele çevirir.
- **`window.line_height()`** — Aktif metin stiline göre satır yüksekliği.

### Tuzaklar

- **Highlight aralıkları byte aralığıdır;** UTF-8 karakter sınırlarına denk gelmek zorundadır. Çok-byte'lı karakter ortasına denk gelen aralık panic'e yol açar.
- **`SharedString` kopyalamayı azaltır;** render child'larında `String` yerine `SharedString` kullanmak her frame'deki allocation'ı engeller. Kullanım ayrımı [SharedString, SharedUri ve Ucuz Klonlanan Tipler](./bolum-05-stil-geometri-ve-renkler.md#54-sharedstring-shareduri-ve-ucuz-klonlanan-tipler) bölümünde anlatılır.
- **`text_ellipsis`, `line_clamp`, `white_space` gibi taşma davranışları layout genişliğine bağlıdır;** üst UI öğesinin genişliği belirsizse (örn. `flex` içinde `min-w-0` verilmemişse) metin kısaltma beklendiği gibi çalışmaz.
- **Uygulama genel text rendering modu `cx.set_text_rendering_mode(...)`** ile `PlatformDefault`, `Subpixel`, `Grayscale` arasında seçilir. Subpixel akışı her glyph için yatayda `gpui::SUBPIXEL_VARIANTS_X: u8 = 4`, dikeyde `gpui::SUBPIXEL_VARIANTS_Y: u8 = 1` farklı varyant rasterize eder (`text_system.rs:45,48`); yani glyph atlas boyutu yatay subpixel pozisyonuna duyarlı, dikey değildir.

## 13.2. StyledText, TextLayout ve InteractiveText

Basit, tek stilli metin `SharedString` olarak `.child(...)` çağrısına geçirilebilir; karmaşıklaştıkça (highlight, font override, tıklanabilir aralık, hover, tooltip) sırasıyla `StyledText` ve `InteractiveText` UI öğesi tipleri kullanılır. Bu bölüm her birinin sağladığı yüzeyleri ve ortak ölçüm sonucu olan `TextLayout` tipini açıklar.

### `StyledText`

```rust
let text = StyledText::new("Open settings")
    .with_highlights(vec![(0..4, highlight_style)])
    .with_font_family_overrides(vec![(5..13, "ZedMono".into())]);

let layout = text.layout().clone();
```

Önceden hesaplanmış `TextRun` listesi varsa `.with_highlights(...)` yerine `.with_runs(runs)` kullanılır — bu, run'ları her render'da yeniden üretmek yerine cache'lenmiş bir sonuçtan inşa etmek için uygundur. `.with_default_highlights(&default_style, ranges)` ise üst stilden miras almak yerine açıkça verilen bir `TextStyle`'ı baz alır.

### `TextLayout` — ölçüm sonucu

Ölçüm/prepaint sonrası elde edilen `TextLayout`, metnin ekrandaki gerçek konum bilgisini taşır. Click/hover gibi event işleyicileri bu bilgiyi kullanır:

- **`index_for_position(point) -> Result<usize, usize>`** — Piksel pozisyonundan UTF-8 byte index'i (farenin hangi karakter üzerinde olduğunu bulmak için).
- **`position_for_index(index) -> Option<Point<Pixels>>`** — Byte index'ten piksel konumu (cursor çizimi için).
- **`line_layout_for_index(index)`, `bounds()`, `line_height()`, `len()`, `text()`, `wrapped_text()`** — Satır, bounds ve metin meta verileri.

**Önemli:** `TextLayout` değerleri layout/prepaint yapılmadan okunursa panic edebilir; bu nedenle event işleyicisi ve after-layout yolunda kullanılır, render sırasında henüz ölçülmemiş layout'a güvenilmez.

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

Verilen aralıklar **byte index aralığıdır**; Unicode metinlerde karakter sınırlarını yanlış hesaplamak hover/click eşleşmesini bozar. Ayrıca `on_click` listener'ı yalnızca **fare basma ve bırakma aynı aralık içinde kaldığında** çalışır — bu, kullanıcının drag yaparken tıklamayı iptal etmesine olanak verir.


---
