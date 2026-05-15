# Bölüm VIII — Metin Sistemi

---

## Text, Font ve Metin Ölçümü


Ana tipler `crates/gpui/src/text_system.rs`, `style.rs` ve
`elements/text.rs` içinde:

- `TextStyle`: renk, font family, font size, line height, weight/style,
  decoration, whitespace, overflow, align, line clamp.
- `HighlightStyle`: belirli range'lere uygulanacak partial stil.
- `TextRun`: UTF-8 byte uzunluğu + font + renk/dekorasyon. Run toplam uzunluğu
  metin byte uzunluğunu tam karşılamalıdır.
- `StyledText`: `SharedString` + run/highlight/font override ile render edilir.
- `InteractiveText`: character/range bazlı click, hover ve tooltip sağlar.
- `Font`, `FontWeight`, `FontStyle`, `FontFeatures`, `FontFallbacks`.

Örnek:

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

Metin ölçümü ve layout:

- `window.text_style()` aktif inherited style'ı verir.
- `window.text_system()` pencereye bağlı `WindowTextSystem`'dır.
- `App::text_system()` global text system'a erişir.
- `TextStyle::to_run(len)` inherited style'dan run üretir.
- `TextStyle::line_height_in_pixels(rem_size)` line-height değerini pixel'e çevirir.
- `window.line_height()` aktif text style'a göre satır yüksekliği döndürür.

Tuzaklar:

- Highlight range'leri byte range'dir; UTF-8 char boundary olmalıdır.
- `SharedString` kopyalamayı azaltır; render child'larında `String` yerine tercih et.
- `text_ellipsis`, `line_clamp`, `white_space` gibi overflow davranışları layout
  genişliğine bağlıdır; parent width belirsizse truncation beklediğin gibi çalışmaz.
- Uygulama genel text rendering modu `cx.set_text_rendering_mode(...)` ile
  `PlatformDefault`, `Subpixel`, `Grayscale` arasında seçilir. Subpixel akışı
  her glyph için yatayda `gpui::SUBPIXEL_VARIANTS_X: u8 = 4`, dikeyde
  `gpui::SUBPIXEL_VARIANTS_Y: u8 = 1` farklı varyant rasterize eder
  (`text_system.rs:45,48`); yani glyph atlas boyutu yatay subpixel pozisyonuna
  duyarlı, dikey değil.
- WGPU/Linux text backend'i (`CosmicTextSystem`) `Font.fallbacks` değerini font
  cache key'ine dahil eder ve `layout_line` içinde kullanıcı fallback zincirini
  grapheme cluster sınırlarını koruyarak uygular. ASCII karakterlerde primary font
  tercih edilir; combining mark ve ZWJ emoji cluster'ları fallback span'i içinde
  bölünmez. Custom font fallback ayarı debug ederken yalnız family adını değil
  fallback listesini de cache/ölçüm girdisi say.

## StyledText, TextLayout ve InteractiveText


Basit metin `SharedString` olarak child verilebilir; ölçüm, highlight,
font override veya tıklanabilir aralık gerekiyorsa `StyledText` kullanılır.

`StyledText`:

```rust
let text = StyledText::new("Open settings")
    .with_highlights(vec![(0..4, highlight_style)])
    .with_font_family_overrides(vec![(5..13, "ZedMono".into())]);

let layout = text.layout().clone();
```

Precomputed `TextRun` varsa delayed highlight yerine `.with_runs(runs)` kullan;
`with_default_highlights(&default_style, ranges)` ise parent style yerine açık
bir `TextStyle` baz alarak run üretir.

Ölçüm/prepaint sonrası `TextLayout`:

- `index_for_position(point) -> Result<usize, usize>`: piksel pozisyonundan
  UTF-8 byte index'i.
- `position_for_index(index) -> Option<Point<Pixels>>`: byte index'ten piksel.
- `line_layout_for_index(index)`, `bounds()`, `line_height()`, `len()`,
  `text()`, `wrapped_text()`.

`TextLayout` değerleri layout/prepaint yapılmadan okunursa panic edebilir; bu
nedenle event handler veya after-layout path'inde kullanılır, render sırasında
ölçülmemiş layout'a güvenilmez.

`InteractiveText`:

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

Aralıklar byte index aralığıdır; Unicode metinde character sınırlarını yanlış
hesaplamak hover/click eşleşmesini bozabilir. `on_click` yalnızca mouse down ve
mouse up aynı verilen range içinde kaldığında listener çağırır.

Markdown render davranışı:

- Markdown image render'ı `StyledImage::with_fallback` kullanarak yüklenemeyen
  görsel için tıklanabilir "Failed to Load: ..." fallback'i üretir. Fallback
  label'ı önce alt text'i, yoksa hedef URL'yi kullanır ve click ile `cx.open_url`
  çağırır.
- Mermaid code block'ları yalnız kapanmış fenced block ise diagram olarak
  çıkarılır. ` ```mermaid` yanında fenced source path uzantısı `.mermaid` veya
  `.mmd` olan bloklar da diagram sayılır.
- Mermaid diagram UI'ı preview/code tab'ları ve kopyalama butonu gösterebilir;
  render başarısızsa veya henüz tamamlanmadıysa source code görünümü fallback
  olarak gösterilir.

---

---

