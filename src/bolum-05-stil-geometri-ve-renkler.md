# Bölüm V — Stil, Geometri ve Renkler

---

## 17. Style ve Layout Haritası

GPUI style sistemi CSS/Tailwind'e benzer fluent metotlardan oluşur, fakat Rust
tipleriyle daha nettir:

- Boyut: `w`, `h`, `size`, `min_w`, `max_w`, `flex_basis`, `size_full`,
  `h_auto`, `relative(f32)`, `px`, `rems`.
- Layout: `flex`, `grid`, `flex_row`, `flex_col`, `items_*`, `justify_*`,
  `content_*`, `gap_*`, `flex_wrap`, `flex_grow`, `flex_shrink`.
- Position: `relative`, `absolute`, `inset_*`, `top/right/bottom/left`,
  `z_index`.
- Overflow: plain style overflow ve stateful `.overflow_*_scroll()`.
- Background/border: `bg`, `border_*`, `border_color`, `rounded_*`,
  `box_shadow`, `opacity`.
- Text: `text_color`, `text_bg`, `text_size`, `text_*`, `font_family`,
  `font_weight`, `italic`, `line_height`, `text_ellipsis`, `line_clamp`.
- Interaction: `hover`, `active`, `focus`, `focus_visible`, `cursor_*`,
  `track_focus`, `key_context`, action/key/mouse handlers.
- Group styling: `.group("name")`, `group_hover(...)`, `group_active(...)` ve
  `group_drag_over::<T>(...)` aynı isimli interaction grubuna göre uygulanır.
- Grid placement: container için `grid_cols`, `grid_cols_min_content`,
  `grid_cols_max_content`, `grid_rows`; child için `col_start`, `col_end`,
  `col_span`, `col_span_full`, `row_start`, `row_end`, `row_span`,
  `row_span_full` kullanılır. Altta `GridTemplate`,
  `TemplateColumnMinSize` ve `GridPlacement::{Line, Span, Auto}` vardır.

Yukarıdaki fluent metotların büyük kısmı `Styled` trait body'sinde tek tek
yazılmaz; bir grup proc macro tarafından üretilir. `crates/gpui/src/styled.rs`
trait gövdesinde bu makrolar tek satır olarak invoke edilir, `gpui_macros`
crate'i ise her invoke için onlarca metot expand eder. Hangi macro hangi
metotları üretiyor:

| Proc macro (`gpui_macros::...!()`) | Üretilen fluent metotlar (Styled trait üyesi olarak) |
|---|---|
| `visibility_style_methods!()` | `visible()`, `invisible()` |
| `margin_style_methods!()` | `m_*` ile birlikte `mt_`, `mb_`, `my_`, `mx_`, `ml_`, `mr_` ve her birinin spacing scale + `auto` varyantları (`mt_auto()` gibi) |
| `padding_style_methods!()` | `p_*`, `pt_`, `pb_`, `py_`, `px_`, `pl_`, `pr_` (margin ailesinin padding karşılığı) |
| `position_style_methods!()` | `relative()`, `absolute()` ve positioned element offset prefix'leri: `inset`, `top`, `bottom`, `left`, `right` |
| `overflow_style_methods!()` | `overflow_hidden()`, `overflow_x_hidden()`, `overflow_y_hidden()` |
| `cursor_style_methods!()` | `cursor(CursorStyle)`, `cursor_default()`, `cursor_pointer()`, `cursor_text()`, `cursor_move()`, `cursor_not_allowed()`, `cursor_context_menu()`, `cursor_crosshair()`, `cursor_vertical_text()`, `cursor_alias()`, `cursor_copy()`, `cursor_no_drop()`, `cursor_grab()`, `cursor_grabbing()`, ve resize ailesi: `cursor_ew_resize()`, `cursor_ns_resize()`, `cursor_nesw_resize()`, `cursor_nwse_resize()`, `cursor_col_resize()`, `cursor_row_resize()`, `cursor_n_resize()`, `cursor_e_resize()`, `cursor_s_resize()`, `cursor_w_resize()` |
| `border_style_methods!()` | `border_color(C)` ve `border_*` width prefix'leri (`border_*`, `border_t_*`, `border_r_*`, `border_b_*`, `border_l_*`, `border_x_*`, `border_y_*`) × suffix tablosu (`_0`, `_1`, `_2`, `_4`, `_8`, vb.) |
| `box_shadow_style_methods!()` | `shadow(Vec<BoxShadow>)`, `shadow_none()`, `shadow_2xs()`, `shadow_xs()`, `shadow_sm()`, `shadow_md()`, `shadow_lg()`, `shadow_xl()`, `shadow_2xl()` |

Bu makrolar `pub` (proc) macro olarak `gpui_macros` crate'inden export edilir
ve `gpui::{visibility_style_methods, margin_style_methods, ...}` üzerinden de
yeniden re-export edilir. Doğrudan uygulama kodu çağırmaz — fluent metotlar
zaten `Styled` trait'inin parçası olduğu için her `Styled` impl'i otomatik
sahip olur.

`Styled` trait içinde ayrıca `gpui_macros::style_helpers!()` çağrısı vardır, fakat
bu proc macro `#[doc(hidden)]` olduğu ve `gpui` crate kökünden re-export
edilmediği için `target/doc/gpui/all.html` macro listesinde yer almaz. `w_*`,
`h_*`, `size_*`, `min_size_*`, `min_w_*`, `min_h_*`, `max_size_*`, `max_w_*`,
`max_h_*`, `gap_*`, `gap_x_*`, `gap_y_*` ve `rounded_*` aileleri bu internal
macrodan gelir.

Custom bir element için `Styled` impl ediyorsan trait'in tüm metotları
otomatik miras kalır; bu makroları yeniden invoke etmek gerekmez. Yalnız
GPUI'nin kendisi gibi yeni bir style framework yazıyorsan (paralel bir
`Styled` benzeri trait için) bu macro'ları kendi trait'inin içinde invoke
edebilirsin — `method_visibility` parametresi public/pub(crate) ayarına izin
verir.

Pratik kararlar:

- Görünüm state'e bağlıysa `Render` içinde koşullu `.when(...)` kullan; style'ı
  sonradan imperative değiştirmeye çalışma.
- Scroll, focus, tooltip, animation gibi stateful elementlerde ID stabil olmalıdır.
- Parent layout genişliği belirsizse text overflow, image aspect ratio ve absolute
  child konumu beklediğin sonucu vermeyebilir.
- Kart/toolbar/list gibi tekrar eden UI'da boyutları `min/max/aspect_ratio` ile
  sabitle; hover veya loading state layout shift üretmemeli.

## 18. Geometri Tipleri ve Birim Yönetimi

`crates/gpui/src/geometry.rs`.

GPUI üç farklı pixel birimi kullanır:

- `Pixels(f32)`: scale-bağımsız mantıksal piksel. UI kodunda neredeyse her zaman
  bu kullanılır.
- `ScaledPixels(f32)`: `Pixels * window.scale_factor()`. Renderer'a iletilen değer.
- `DevicePixels(i32)`: fiziksel cihaz pikseli. Asset/texture boyutlarında kullanılır.

Yardımcılar:

```rust
let p = px(12.0);                  // Pixels
let r = rems(1.5);                 // Rems
let p2 = point(px(10.), px(20.));  // Point<Pixels>
let s = size(px(100.), px(40.));   // Size<Pixels>
let b = Bounds::from_corners(point(px(0.), px(0.)), point(px(100.), px(100.)));
```

Diğer birimler:

- `Rems(f32)`: kök font boyutuna görelidir (Zed'de `theme.ui_font_size` ile bağlı).
  `.text_sm()`, `.gap_2()` gibi makro üretilen helper'lar genelde Rems üzerinden
  Pixels üretir.
- `AbsoluteLength`: `Pixels` veya `Rems`.
- `DefiniteLength`: `Absolute(AbsoluteLength)` veya `Fraction(f32)`.
- `Length`: `Definite(DefiniteLength)` veya `Auto`.

Stil API'leri Length kabul eder:

```rust
div().w(px(120.))           // Pixels
    .min_h(rems(2.))        // Rems
    .flex_basis(relative(0.5)) // Fraction
    .h_auto()
```

Generic container'lar `Point<T>`, `Size<T>`, `Bounds<T>`, `Edges<T>`, `Corners<T>`
çoğu metot için aritmetik destekler (`+`, `-`, `*`, `/`).

Kaynakta public inherent metot yüzeyi:

- `Point<T>`: `map`, `scale`, `magnitude`, `relative_to`, `max`, `min`, `clamp`.
- `Size<T>`: `new`, `map`, `center`, `scale`, `max`, `min`, `full`, `auto`,
  `to_pixels`, `to_device_pixels`.
- `Bounds<T>`: `centered`, `maximized`, `new`, `from_corners`,
  `from_anchor_and_size`, `centered_at`, `top_center`, `bottom_center`,
  `left_center`, `right_center`, `intersects`, `center`, `half_perimeter`,
  `dilate`, `extend`, `inset`, `space_within`, `top`, `bottom`, `left`,
  `right`, `top_right`, `bottom_right`, `bottom_left`, `corner`, `contains`,
  `is_contained_within`, `map`, `map_origin`, `map_size`, `localize`,
  `is_empty`, `scale`, `to_device_pixels`, `to_pixels`.
- `Edges<T>`: `all`, `map`, `any`, `auto`, `zero`, `to_pixels`, `scale`, `max`.
  Birden fazla `zero`/`to_pixels` impl'i farklı generic specialization'lardan
  gelir.
- `Corners<T>`: `all`, `corner`, `to_pixels`, `scale`, `max`,
  `clamp_radii_for_quad_size`, `map`.
- Birim wrapper'ları: `Pixels::{as_f32, floor, round, ceil, scale, pow, abs,
  signum, to_f64}`, `ScaledPixels::{as_f32, floor, round, ceil}`,
  `Rems::{is_zero, to_pixels, to_rems}`, `DevicePixels::to_bytes`.

Hazır oran sabitleri:

- `phi() -> DefiniteLength` (`geometry.rs:3698`): altın oranı `relative(1.618_034)`
  olarak döndürür — yani parent'ın **1.618 katı**, %50 değil. GPUI'nin kendisi
  default `TextStyle::line_height` değeri olarak `phi()` kullanır
  (`style.rs:451`); yani bir font için satır yüksekliği `font_size * 1.618`'dir.
  Layout oranlamada (örn. golden-ratio iki sütun) parent'ın katı olarak
  istenirse aynı sabit kullanılabilir.

Tuzaklar:

- `Bounds::contains(point)` half-open intervallere göre çalışır; sınır pikseli
  `false` dönebilir.
- `Pixels` ile `ScaledPixels` aritmetiği `From`/`Into` üzerinden açık konversiyon
  ister; örtük çevrilmez.
- `point(x, y)` argument sırası önce X sonra Y'dir; `size(width, height)` de aynı.

## 19. Renkler, Gradient ve Background

`crates/gpui/src/color.rs` ve `colors.rs`.

İki temel tip:

- `Rgba { r, g, b, a }`: 0.0–1.0 aralığında bileşenler.
- `Hsla { h, s, l, a }`: 0.0–1.0 aralığında bileşenler.

Constructor'lar:

```rust
let red = rgb(0xff0000);                    // Rgba, alfa 1.0
let translucent = rgba(0xff000080);         // 0xRRGGBBAA
let h = hsla(0.0, 1.0, 0.5, 1.0);           // saf kırmızı
let grey = opaque_grey(0.5, 1.0);           // gri yardımcısı
```

Hazır renk sabitleri (hepsi `pub const fn ... -> Hsla`, `color.rs:344+`):

| Fonksiyon | HSLA değeri | Not |
|---|---|---|
| `black()` | `(0.0, 0.0, 0.0, 1.0)` | Saf siyah |
| `white()` | `(0.0, 0.0, 1.0, 1.0)` | Saf beyaz |
| `transparent_black()` | `(0.0, 0.0, 0.0, 0.0)` | Tam saydam siyah — gradient ucu olarak kullanışlı |
| `transparent_white()` | `(0.0, 0.0, 1.0, 0.0)` | Tam saydam beyaz |
| `red()` | `(0.0, 1.0, 0.5, 1.0)` | %100 doygun kırmızı |
| `blue()` | `(0.666…, 1.0, 0.5, 1.0)` | %100 doygun mavi |
| `yellow()` | `(0.166…, 1.0, 0.5, 1.0)` | %100 doygun sarı |
| `green()` | `(0.333…, 1.0, **0.25**, 1.0)` | Diğerlerinden farklı: lightness 0.25 (koyu yeşil) |

Bunlar Zed tasarım sisteminden bağımsızdır; tema renkleri için `cx.theme().colors()`
kullan. Debug placeholder, GPU shader test'i veya tema-bağımsız palette örneği
gerekirse bu sabitler hazır gelir. `transparent_black()` `linear_gradient` ucu
olarak en yaygın kullanılan tek-parça çağrısıdır (ör. fade-out maskeleri).

Sık kullanılan metotlar (`color.rs:472+`):

- `is_transparent()`, `is_opaque()`
- `opacity(factor)`: alfayı çarpar.
- `alpha(a)`: alfayı doğrudan ayarlar.
- `fade_out(factor)`: in-place alfa azaltma.
- `blend(other)`: pre-multiplied alpha ile karıştırır.
- `grayscale()`: doygunluğu sıfırlar.
- `to_rgb()`: Hsla → Rgba.

Background tipi (`color.rs:763+`) sadece düz renk değildir:

```rust
solid_background(rgb(0xffffff))
linear_gradient(
    angle_deg,
    linear_color_stop(rgb(0x000000), 0.0),
    linear_color_stop(rgb(0xffffff), 1.0),
)
checkerboard(rgb(0xeeeeee), 8.0)
pattern_slash(rgb(0xff0000), 2.0, 6.0)
```

`linear_gradient(...).color_space(ColorSpace::Oklab)` ile renk uzayı seçilebilir;
`opacity(factor)` her stop'a uygulanır. `Background::as_solid()` yalnızca düz
renk background için `Some(Hsla)` döndürür; gradient/pattern için `None` döner.

`.bg(impl Into<Background>)` her style fluent API'sinde mevcut. Düz `Hsla` da
`Into<Background>` implement eder, bu yüzden `.bg(theme.colors().panel_background)`
tipik kullanımdır.

Pratik notlar:

- Alfa = 0 fakat opaque arka planın üzerine çiziyorsan temadaki opak rengi tercih et.
- Gradient stop'lar `0.0` ve `1.0` arasında sıralı vermeli; aksi halde GPU shader'ı
  beklenmedik dağılım verebilir.
- Hsla'da hue 1.0'a sarılmaz (clamp'lenir); rotasyon için `hue + delta` modulo 1.0
  ile hesapla.

## 20. SharedString, SharedUri ve Ucuz Klonlanan Tipler

`SharedString` GPUI'nin `gpui_shared_string` re-export'udur; `SharedUri`
`crates/gpui/src/shared_uri.rs` içinde bu string tipini sarar.

UI ağacı her render'da yeniden oluşturulduğu için string ve URI kopyalama maliyeti
hızla birikir. GPUI bunun için `Arc` tabanlı tipler sunar:

- `SharedString`: `&'static str` veya `Arc<str>`. `Clone` ucuzdur (ref-count).
  `Display`, `AsRef<str>`, `Into<SharedString>` impl'ler mevcuttur. `&'static str`,
  `String` ve `Cow<'_, str>` ücretsizce dönüşür.
- `SharedUri`: aynı stratejiyle URI; `ImageSource::Resource(Resource::Uri(...))`
  burada `SharedUri` ister.

Render içinde `String` üretip clone etmek yerine entity state'de `SharedString`
sakla:

```rust
struct Header { title: SharedString }

impl Header {
    fn set_title(&mut self, title: impl Into<SharedString>, cx: &mut Context<Self>) {
        self.title = title.into();
        cx.notify();
    }
}

impl Render for Header {
    fn render(&mut self, _: &mut Window, _: &mut Context<Self>) -> impl IntoElement {
        div().child(self.title.clone())
    }
}
```

İlgili ucuz klon tipleri:

- `Arc<str>`, `Arc<Path>`, `Arc<[T]>`: GPUI sıkça `Arc` based slice/path bekler.
- `Hsla`/`Rgba`: `Copy` tipli, doğrudan değer geçirilir.
- `ElementId`: `Clone`, internal ID veya string varyantları taşır.

Tuzaklar:

- `SharedString::from(String)` çağrısı bir kez allocation yapar; sonraki klonlar
  ücretsiz. Hot path'te tekrar tekrar `String` üretmekten kaçın.
- `to_string()` çağrısı yeni `String` allocation üretir; gerekmiyorsa
  `as_ref()` veya `Display` ile yaz.
- Format string her render'da çalışıyorsa `format!` sonucu da her frame allocation
  yapar; sonucu cache'lemek için entity state'te tut.

## 21. WindowAppearance ve Tema Modu

`crates/gpui/src/platform.rs:1604` içinde tanımlı:

```rust
pub enum WindowAppearance {
    Light,        // macOS: aqua
    VibrantLight, // macOS: NSAppearanceNameVibrantLight
    Dark,         // macOS: darkAqua
    VibrantDark,  // macOS: NSAppearanceNameVibrantDark
}
```

`Vibrant` varyantları macOS `NSAppearance` değerleriyle doğrudan eşleşir. Diğer
platformlar bu enum'u yine taşır, fakat vibrancy'nin gerçek etkisi platform
implementasyonuna bağlıdır. Sistem açık/koyu tercih ettiğinde GPUI bunu platform
appearance olarak yansıtır; kullanıcı manuel tema override yapmıyorsa Zed teması
bu sinyali takip eder.

Erişim:

- `cx.window_appearance() -> WindowAppearance`: uygulama-genel platform tercihi.
- `window.appearance() -> WindowAppearance`: pencerenin gerçek görünümü
  (parent override edebilir).
- `window.observe_window_appearance(|window, cx| ...)`: entity state'e gerek
  yoksa doğrudan pencere observer'ı.
- `cx.observe_window_appearance(window, |this, window, cx| ...)`: `Context<T>`
  içinden view state ile birlikte değişimi izle.
- `window.observe_button_layout_changed(...)` ve
  `cx.observe_button_layout_changed(window, ...)`: platform pencere kontrol
  butonu düzeni değiştiğinde çalışır.

Zed örüntüsü `crates/zed/src/main.rs` içinde tema seçimine bağlanır:

```rust
cx.observe_window_appearance(window, |_, window, cx| {
    let appearance = window.appearance();
    *SystemAppearance::global_mut(cx) = SystemAppearance(appearance.into());
    theme_settings::reload_theme(cx);
    theme_settings::reload_icon_theme(cx);
}).detach();
```

Tuzaklar:

- macOS dışında `VibrantLight`/`VibrantDark` üretilmez; eşleştirme tablosunda
  yine de tüm dört değeri ele al.
- Sistem temasını değiştirmek pencere açıldıktan sonra `window_background_appearance`
  değişimini tetiklemez; tema akışında manuel `window.set_background_appearance(...)`
  çağrısı gerekir.
- `Vibrant*` ile birlikte `WindowBackgroundAppearance::Blurred` eklenirse macOS'ta
  blur'un üzerine extra vibrancy bindirilir; tasarım sisteminde tek katman seç.


---

