# 5. Stil, Geometri ve Renkler

---

## 5.1. Style ve Layout Haritası

GPUI'nin style sistemi, CSS/Tailwind'e benzer fluent (zincirleme) method'lardan oluşur. Fark, bunların Rust tip sistemiyle yazılmış olmasıdır: birçok yanlış birim veya uyumsuz değer derleme zamanında yakalanır; runtime'da CSS benzeri sessiz geçersiz stil üretme ihtimali azalır. `Styled` trait'ini implemente eden her UI öğesi (`element`) bu method zincirinden faydalanır: `div()` gibi yerleşik elementler, `RenderOnce` bileşenleri ve Zed UI tipleri dahil.

Style method'larının ana grupları ve hangi amaca hizmet ettikleri:

- **Boyut**: `w`, `h`, `size`, `min_w`, `max_w`, `flex_basis`, `size_full`, `h_auto`, `relative(f32)`, `px`, `rems`.
- **Layout (yerleşim)**: `flex`, `grid`, `flex_row`, `flex_col`, `items_*`, `justify_*`, `content_*`, `gap_*`, `flex_wrap`, `flex_grow`, `flex_shrink`.
- **Konum**: `relative`, `absolute`, `inset_*`, `top` / `right` / `bottom` / `left`, `z_index`.
- **Overflow**: düz `overflow_*` (örn. gizleme/kesme) ve stateful `.overflow_*_scroll()` (kaydırma).
- **Arkaplan ve çerçeve**: `bg`, `border_*`, `border_color`, `rounded_*`, `box_shadow`, `opacity`.
- **Metin**: `text_color`, `text_bg`, `text_size`, `text_*`, `font_family`, `font_weight`, `italic`, `line_height`, `text_ellipsis`, `line_clamp`.
- **Etkileşim**: `hover`, `active`, `focus`, `focus_visible`, `cursor_*`, `track_focus`, `key_context`, action/key/mouse handler'ları.
- **Grup stillemesi**: `.group("name")` ile bir UI öğesi grup adı alır; `group_hover(...)`, `group_active(...)`, `group_drag_over::<T>(...)` ise aynı isimli gruba göre child stilleri uygular. Parent hover/active durumuna göre child'ı stillemek için kullanılır.
- **Grid yerleşimi**: container için `grid_cols`, `grid_cols_min_content`, `grid_cols_max_content`, `grid_rows`; child için `col_start`, `col_end`, `col_span`, `col_span_full`, `row_start`, `row_end`, `row_span`, `row_span_full`. Altta `GridTemplate`, `TemplateColumnMinSize` ve `GridPlacement::{Line, Span, Auto}` tipleri çalışır.

### Style method'larının nereden geldiği

Bu fluent method'ların büyük kısmı `Styled` trait gövdesinde tek tek yazılmaz; `crates/gpui/src/styled.rs` içinde bir grup proc macro çağrısı vardır ve `gpui_macros` crate'i her çağrı için onlarca method genişletir. Hangi makronun hangi method'ları ürettiği:

| Proc macro (`gpui_macros::...!()`) | Üretilen fluent method'lar (`Styled` trait üyesi olarak) |
|---|---|
| `visibility_style_methods!()` | `visible()`, `invisible()` |
| `margin_style_methods!()` | `m_*` ile birlikte `mt_`, `mb_`, `my_`, `mx_`, `ml_`, `mr_` ve her birinin spacing scale + `auto` varyantları (`mt_auto()` gibi) |
| `padding_style_methods!()` | `p_*`, `pt_`, `pb_`, `py_`, `px_`, `pl_`, `pr_` (margin ailesinin padding karşılığı) |
| `position_style_methods!()` | `relative()`, `absolute()` ve konumlandırılmış UI öğesi offset prefix'leri: `inset`, `top`, `bottom`, `left`, `right` |
| `overflow_style_methods!()` | `overflow_hidden()`, `overflow_x_hidden()`, `overflow_y_hidden()` |
| `cursor_style_methods!()` | `cursor(CursorStyle)`, `cursor_default()`, `cursor_pointer()`, `cursor_text()`, `cursor_move()`, `cursor_not_allowed()`, `cursor_context_menu()`, `cursor_crosshair()`, `cursor_vertical_text()`, `cursor_alias()`, `cursor_copy()`, `cursor_no_drop()`, `cursor_grab()`, `cursor_grabbing()`, ve resize ailesi: `cursor_ew_resize()`, `cursor_ns_resize()`, `cursor_nesw_resize()`, `cursor_nwse_resize()`, `cursor_col_resize()`, `cursor_row_resize()`, `cursor_n_resize()`, `cursor_e_resize()`, `cursor_s_resize()`, `cursor_w_resize()` |
| `border_style_methods!()` | `border_color(C)` ve `border_*` width prefix'leri (`border_*`, `border_t_*`, `border_r_*`, `border_b_*`, `border_l_*`, `border_x_*`, `border_y_*`) × suffix tablosu (`_0`, `_1`, `_2`, `_4`, `_8`, vb.) |
| `box_shadow_style_methods!()` | `shadow(Vec<BoxShadow>)`, `shadow_none()`, `shadow_2xs()`, `shadow_xs()`, `shadow_sm()`, `shadow_md()`, `shadow_lg()`, `shadow_xl()`, `shadow_2xl()` |

Bu proc macro'lar `gpui_macros` crate'inden `pub` olarak export edilir ve `gpui::{visibility_style_methods, margin_style_methods, ...}` üzerinden re-export edilir. Uygulama kodunda doğrudan çağrılmaz; `Styled` trait'i her implementasyona bu method'ları sağladığı için, özel bir UI öğesi `Styled` implemente ettiğinde bu zincir hazır gelir.

`Styled` trait gövdesinde ayrıca `gpui_macros::style_helpers!()` çağrısı vardır. Bu macro `#[doc(hidden)]` olduğu ve `gpui` crate kökünden re-export edilmediği için `target/doc/gpui/all.html` listesinde görünmez. Aşağıdaki method aileleri bu dahili macro'dan üretilir: `w_*`, `h_*`, `size_*`, `min_size_*`, `min_w_*`, `min_h_*`, `max_size_*`, `max_w_*`, `max_h_*`, `gap_*`, `gap_x_*`, `gap_y_*`, `rounded_*`.

Özel bir UI öğesi için `Styled` implemente edildiğinde bu makroları yeniden çağırmak gerekmez; trait'in tüm method'ları o UI öğesinde kullanıma açılır. Makroların doğrudan çağrılmasının tek senaryosu GPUI'ye paralel yeni bir style framework yazmaktır (örn. başka bir `Styled` benzeri trait için). Bu durumda `method_visibility` parametresi public/`pub(crate)` ayarına izin verir.

### Pratik kararlar

- Görünüm bir duruma (`state`) bağlı değişiyorsa stil değişikliği render'ın içinde `.when(...)` ile koşullandırılır; UI öğesi çizildikten sonra style'ı imperative olarak değiştirmeye çalışmak GPUI'nin modeline uymaz.
- Scroll, focus, tooltip, animation gibi durum tutan (`stateful`) UI öğelerinin ID'leri stabil tutulur; ID değişmesi durumu sıfırlar.
- Parent layout genişliği belirsiz olduğunda text overflow, image aspect ratio ve absolute child konumu beklenen sonucu vermeyebilir; en azından bir `w(...)` veya `flex_basis(...)` ile referans değer verilir.
- Kart, toolbar, liste gibi tekrar eden UI'da boyutlar `min/max/aspect_ratio` ile sabitlenir; hover veya loading durumunda layout kayması (layout shift) yaşanmasın diye.

## 5.2. Geometri Tipleri ve Birim Yönetimi

Kaynak: `crates/gpui/src/geometry.rs`.

GPUI ekrandaki bir uzunluk için tek bir "pixel" tipiyle yetinmez; çünkü mantıksal piksel, ölçeklenmiş piksel ve gerçek cihaz pikseli birbirinden farklı kavramlardır. Üç ayrı pixel tipi vardır ve her birinin kullanım yeri ayrıdır:

- **`Pixels(f32)`** — ekran ölçeğinden (DPI/scale factor) bağımsız mantıksal piksel. UI kodunda neredeyse her zaman bu kullanılır; tasarım Retina'da da düşük DPI'da da aynı görünür.
- **`ScaledPixels(f32)`** — `Pixels * window.scale_factor()` ile elde edilir; renderer'a ölçeklenmiş uzunluk olarak iletilir. Uygulama kodunda nadiren elle inşa edilir.
- **`DevicePixels(i32)`** — fiziksel cihaz pikseli. Asset/texture boyutları, GPU buffer tahsisleri gibi cihaza yakın yerlerde kullanılır.

Birim oluşturma yardımcıları:

```rust
let p = px(12.0);                  // Pixels
let r = rems(1.5);                 // Rems
let p2 = point(px(10.), px(20.));  // Point<Pixels>
let s = size(px(100.), px(40.));   // Size<Pixels>
let b = Bounds::from_corners(point(px(0.), px(0.)), point(px(100.), px(100.)));
```

### Length aileleri

`Pixels` dışında stil sisteminin kabul ettiği başka uzunluk tipleri de vardır; bunlar `Length` enum'u altında birleşir:

- **`Rems(f32)`** — kök font boyutuna görelidir (Zed'de `theme.ui_font_size` değerine bağlanır). `.text_sm()`, `.gap_2()` gibi makro üretilen helper'lar genellikle Rems üzerinden Pixels üretir; bu sayede kullanıcının yazı boyutu değiştiğinde tüm UI orantılı küçülür veya büyür.
- **`AbsoluteLength`** — ya `Pixels` ya `Rems` taşır.
- **`DefiniteLength`** — `Absolute(AbsoluteLength)` veya `Fraction(f32)` olabilir. Fraction parent boyutunun belirli bir oranı demektir (`relative(0.5)` = %50).
- **`Length`** — `Definite(DefiniteLength)` veya `Auto`. `Auto`, layout motoru karar versin anlamındadır.

Stil API'leri `impl Into<Length>` kabul ettiği için bu tiplerin hepsi tek bir method'a geçirilebilir:

```rust
div().w(px(120.))           // Pixels
    .min_h(rems(2.))        // Rems
    .flex_basis(relative(0.5)) // Fraction (parent'ın %50'si)
    .h_auto()                  // Layout motoru karar versin
```

### Geometri container'ları

`Point<T>`, `Size<T>`, `Bounds<T>`, `Edges<T>`, `Corners<T>` generic container'lardır; aritmetik operatörler (`+`, `-`, `*`, `/`) çoğu kombinasyon için destekli olduğundan `bounds + offset`, `size * 2` gibi ifadeler doğrudan yazılabilir.

Public inherent method yüzeyi (referans amaçlı):

- **`Point<T>`**: `map`, `scale`, `magnitude`, `relative_to`, `max`, `min`, `clamp`.
- **`Size<T>`**: `new`, `map`, `center`, `scale`, `max`, `min`, `full`, `auto`, `to_pixels`, `to_device_pixels`.
- **`Bounds<T>`**: `centered`, `maximized`, `new`, `from_corners`, `from_anchor_and_size`, `centered_at`, `top_center`, `bottom_center`, `left_center`, `right_center`, `intersects`, `center`, `half_perimeter`, `dilate`, `extend`, `inset`, `space_within`, `top`, `bottom`, `left`, `right`, `top_right`, `bottom_right`, `bottom_left`, `corner`, `contains`, `is_contained_within`, `map`, `map_origin`, `map_size`, `localize`, `is_empty`, `scale`, `to_device_pixels`, `to_pixels`.
- **`Edges<T>`**: `all`, `map`, `any`, `auto`, `zero`, `to_pixels`, `scale`, `max`. Birden fazla `zero`/`to_pixels` impl'i farklı generic specialization'lardan gelir.
- **`Corners<T>`**: `all`, `corner`, `to_pixels`, `scale`, `max`, `clamp_radii_for_quad_size`, `map`.
- **Birim wrapper'ları**: `Pixels::{as_f32, floor, round, ceil, scale, pow, abs, signum, to_f64}`, `ScaledPixels::{as_f32, floor, round, ceil}`, `Rems::{is_zero, to_pixels, to_rems}`, `DevicePixels::to_bytes`.

### Hazır oran sabiti: `phi()`

`phi() -> DefiniteLength` (`geometry.rs:3698`), altın oranı `relative(1.618_034)` olarak döndürür. Burada dikkat çeken nokta `phi()`'nin bir oran *katı* (1.618 katı) belirttiği, yüzde değil. GPUI'nin kendisi default `TextStyle::line_height` değeri olarak `phi()` kullanır (`style.rs:451`); yani bir font için satır yüksekliği `font_size * 1.618` olarak hesaplanır. Layout tarafında aynı sabit kullanılabilir, ancak `relative(1.618_034)` uygulandığı eksende parent boyutundan büyük bir değer üretebileceği için bilinçli seçilmelidir.

### Tuzaklar

- `Bounds::contains(point)` half-open intervaller üzerinden çalışır; tam sınır pikseli `false` dönebilir. Tıklama hit-test'i yapılırken bunun farkında olunmalıdır.
- `Pixels` ile `ScaledPixels` aritmetiği örtük yapılmaz; aralarındaki dönüşüm `From`/`Into` ile *açıkça* yazılır. Bu kasıtlıdır — yanlış birim kullanımı tip sistemi tarafından yakalanır.
- `point(x, y)` ve `size(width, height)` argümanları **önce X (genişlik), sonra Y (yükseklik)** sırasıyla verilir; yaygın bir tuzak parametreleri ters geçirmektir.

## 5.3. Renkler, Gradient ve Background

Kaynak: `crates/gpui/src/color.rs` ve `colors.rs`.

GPUI'de renkler iki temel tip üzerinden temsil edilir. İkisi de bileşenlerini 0.0–1.0 aralığında tutar (0–255 değil); böylece farklı renk uzayları ve interpolasyon hesapları doğal akar.

- **`Rgba { r, g, b, a }`** — kırmızı/yeşil/mavi/alfa bileşenleri. Doğrudan piksel renkleri ve hex kaynaklı renkler için doğal tip.
- **`Hsla { h, s, l, a }`** — ton (hue) / doygunluk (saturation) / açıklık (lightness) / alfa. Tema palette'leri ve renk varyasyonları (örn. "aynı tonu biraz daha koyu") burada daha rahat ifade edilir.

Constructor'lar:

```rust
let red = rgb(0xff0000);                    // Rgba, alfa 1.0
let translucent = rgba(0xff000080);         // 0xRRGGBBAA, alfa 0x80
let h = hsla(0.0, 1.0, 0.5, 1.0);           // saf kırmızı (HSL)
let grey = opaque_grey(0.5, 1.0);           // gri yardımcısı
```

### Hazır renk sabitleri

Aşağıdaki fonksiyonlar `pub const fn ... -> Hsla` olarak tanımlıdır (`color.rs:344+`). Bunlar tema sisteminden **bağımsızdır** — debug placeholder, GPU shader testi, fade-out maske ucu veya tema yokluğunda yedek palette gerektiğinde elde hazır gelir. Tema renkleri için `cx.theme().colors()` kullanmak doğru yaklaşımdır.

| Fonksiyon | HSLA değeri | Not |
|---|---|---|
| `black()` | `(0.0, 0.0, 0.0, 1.0)` | Saf siyah |
| `white()` | `(0.0, 0.0, 1.0, 1.0)` | Saf beyaz |
| `transparent_black()` | `(0.0, 0.0, 0.0, 0.0)` | Tam saydam siyah — gradient ucu olarak en yaygın kullanım |
| `transparent_white()` | `(0.0, 0.0, 1.0, 0.0)` | Tam saydam beyaz |
| `red()` | `(0.0, 1.0, 0.5, 1.0)` | %100 doygun kırmızı |
| `blue()` | `(0.666…, 1.0, 0.5, 1.0)` | %100 doygun mavi |
| `yellow()` | `(0.166…, 1.0, 0.5, 1.0)` | %100 doygun sarı |
| `green()` | `(0.333…, 1.0, **0.25**, 1.0)` | Diğerlerinden farklı: lightness 0.25 (koyu yeşil) |

`transparent_black()` özellikle `linear_gradient` ucu olarak fade-out maskelerinde kullanılır (örn. metin sonunu silikleştirme efekti).

### Sık kullanılan renk method'ları (`color.rs:472+`)

- `is_transparent()`, `is_opaque()` — alfa durum sorgusu.
- `opacity(factor)` — mevcut alfayı `factor` ile çarpar (alfa azaltma).
- `alpha(a)` — alfayı doğrudan verilen değere ayarlar.
- `fade_out(factor)` — in-place alfa azaltma (mevcut nesneyi değiştirir).
- `blend(other)` — pre-multiplied alpha ile başka bir rengi karıştırır.
- `grayscale()` — doygunluğu sıfırlar; rengi tonlamadan kaldırır.
- `to_rgb()` — `Hsla` → `Rgba` dönüşümü.

### Background tipi

Bir alanın dolgusu yalnızca düz renk olmak zorunda değildir; `Background` (`color.rs:763+`) gradient ve desen seçeneklerini de barındırır:

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

- `linear_gradient(...).color_space(ColorSpace::Oklab)` ile renk uzayı seçilebilir (Oklab algısal olarak daha düzgün geçiş verir).
- `opacity(factor)` çağrısı gradient'taki tüm stop'lara birden uygulanır.
- `Background::as_solid()` yalnızca düz renk background için `Some(Hsla)` döndürür; gradient ve pattern için `None` döner. "Bu background tek renk mi" sorusu burada cevaplanır.

Her stil fluent API'sinde `.bg(impl Into<Background>)` method'u vardır ve düz `Hsla` da `Into<Background>` implementasyonuna sahiptir; bu yüzden tipik kullanım `.bg(theme.colors().panel_background)` biçiminde, açıkça `solid_background(...)` çağrısına gerek kalmadan yapılır.

### Pratik notlar

- Gradient veya fade maskesi üretirken tam saydam renklerin RGB bileşeni hâlâ interpolasyonu etkileyebilir. Arka plan opaksa, saydam uç rengi olarak genelde aynı tema renginin alpha'sı 0 olan varyantını kullanmak kenarlarda renk saçılması riskini azaltır.
- Gradient stop'ları `0.0` ile `1.0` arası, **sıralı** (artan) verilmelidir; sıra dışı verilen stop'lar GPU shader'ında beklenmedik dağılım üretebilir.
- `Hsla`'da hue 1.0'a sarılmaz, clamp'lenir; renk rotasyonu için `(hue + delta) % 1.0` ile elle modulo alınır.

## 5.4. SharedString, SharedUri ve Ucuz Klonlanan Tipler

UI ağacı her render'da yeniden oluşturulduğu için, render fonksiyonunun döndürdüğü yapıya geçirilen string ve URI'ler her frame'de kopyalanır. Sıradan `String` kullanıldığında bu kopyalama bir allocation demektir; saniyede 60+ frame ile çarpıldığında ciddi bir maliyet birikir. GPUI bu sorunu, `Arc` tabanlı paylaşımlı string ve URI tipleriyle çözer: bir kez allocate edilir, sonraki tüm clone'lar yalnızca referans sayacı artırır.

`SharedString` GPUI'nin `gpui_shared_string` re-export'udur; `SharedUri` ise `crates/gpui/src/shared_uri.rs` içinde aynı string tipini sarar.

- **`SharedString`** — içeride ya `&'static str` ya `Arc<str>` tutar. `Clone` ucuzdur (ref-count artışı). `Display`, `AsRef<str>`, `Into<SharedString>` implementasyonları mevcuttur; `&'static str`, `String` ve `Cow<'_, str>` kolayca dönüştürülür. String literal allocation yapmaz; sahip olunan `String` ise bir kez paylaşımlı temsile çevrilir.
- **`SharedUri`** — aynı stratejiyle URI. Örneğin `ImageSource::Resource(Resource::Uri(...))` burada `SharedUri` bekler; aynı asset URI'sinin tekrar tekrar görselleştirilmesi durumunda allocation çoğalmaz.

### Tipik kullanım

Render içinde `String` üretip clone etmek yerine varlık durumunda (`entity state`) `SharedString` saklamak, hot path allocation'ını yok eder:

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
        div().child(self.title.clone()) // sadece ref-count artar
    }
}
```

### İlgili ucuz klon tipleri

GPUI'de yaygın görülen, clone'lanması ucuz diğer tipler:

- **`Arc<str>`, `Arc<Path>`, `Arc<[T]>`** — GPUI birçok API'sinde `Arc` tabanlı slice veya path bekler; aynı buffer'ı paylaşan tutamaçlar (`handle`) üretir.
- **`Hsla` / `Rgba`** — `Copy` tipindedir; doğrudan değer olarak geçirilir, clone gerekmez.
- **`ElementId`** — `Clone` ucuzdur; içeride ya küçük bir sayısal ID ya `SharedString` taşır.

### Tuzaklar

- `SharedString::from(String)` çağrısı veriyi **bir kez** paylaşımlı temsile çevirir; sonraki tüm clone'lar yalnızca ref-count artırır. Hot path'te tekrar tekrar `String` oluşturup `SharedString`'e çevirmekten kaçınmak gerekir: başlangıçta bir kez dönüşüm yapılır, sonra `SharedString` saklanır.
- `to_string()` her çağrıldığında yeni bir `String` allocation üretir; gerekmediği yerde `as_ref()` veya `Display` üzerinden yazmak tercih edilir.
- Format string'ler her render'da çalışıyorsa `format!` sonucu da her frame allocation yapar; format'lanmış sonuç varlık durumunda (`entity state`) tutulup cache'lenir, render her seferde değer hesaplamaz.

## 5.5. WindowAppearance ve Tema Modu

`WindowAppearance`, işletim sisteminin o anki açık/koyu görünüm tercihini ifade eden enum'dur. Kullanıcı sistemden "Light" veya "Dark" seçtiğinde GPUI bunu pencereye yansıtır; tema motoru da bu sinyali takip ederek koyu/açık temaya geçer. Tanım `crates/gpui/src/platform.rs:1604`:

```rust
pub enum WindowAppearance {
    Light,        // macOS: aqua
    VibrantLight, // macOS: NSAppearanceNameVibrantLight
    Dark,         // macOS: darkAqua
    VibrantDark,  // macOS: NSAppearanceNameVibrantDark
}
```

`Vibrant` varyantları macOS `NSAppearance` değerleriyle birebir eşleşir; macOS'ta sistem materyalleri arkaplanı bulanıklaştırarak ("vibrancy") özel bir görünüm üretir. Diğer platformlar (Windows, Linux, web) bu enum'u taşımaya devam eder ama vibrancy'nin gerçek görsel etkisi platforma göre değişir veya hiç olmaz; bu yüzden tema logic'inde tüm dört değer için eşleştirme tanımlanır.

### Erişim ve abonelik

- **`cx.window_appearance() -> WindowAppearance`** — Uygulama genelinde platformun bildirdiği tercihi anlık olarak okur.
- **`window.appearance() -> WindowAppearance`** — Belirli bir pencerenin gerçek görünümünü okur; parent pencere (macOS modal hiyerarşisi) bu değeri override etmiş olabilir.
- **`window.observe_window_appearance(|window, cx| { ... })`** — Pencerenin görünümü değiştiğinde tetiklenen observer. Görünüm durumu (`view state`) gerektirmeyen, doğrudan pencere üzerinden kurulan abonelik.
- **`cx.observe_window_appearance(window, |this, window, cx| { ... })`** — Aynı abonelik bir `Context<T>` üzerinden kurulur; closure içinde `this: &mut T` ile görünüm durumuna erişilir. Tema bağımlı görünüm durumu da güncellenmesi gerekiyorsa bu form tercih edilir.
- **`window.observe_button_layout_changed(...)`** ve **`cx.observe_button_layout_changed(window, ...)`** — Platform pencere kontrol butonlarının (kapat–küçült–büyüt) düzeni değiştiğinde çalışır; custom title bar çizen kodda bu sıraya göre yeniden layout gerekir.

### Zed örüntüsü

`crates/zed/src/main.rs` içinde sistem görünümü değişimine bağlanan tipik kullanım:

```rust
cx.observe_window_appearance(window, |_, window, cx| {
    let appearance = window.appearance();
    *SystemAppearance::global_mut(cx) = SystemAppearance(appearance.into());
    theme_settings::reload_theme(cx);
    theme_settings::reload_icon_theme(cx);
}).detach();
```

Akış: kullanıcı sistemden temayı değiştirdiğinde callback çalışır → güncel appearance global olarak yazılır → tema ve ikon teması yeniden yüklenir. `detach()` ile observer'ın tutamacı bırakılır; bu observer uygulama yaşadığı sürece aktif kalsın diye.

### Tuzaklar

- `VibrantLight` / `VibrantDark` pratikte macOS `NSAppearance` değerleri için beklenir, ama enum bu varyantları platformdan bağımsız taşımaya devam eder. Tema eşleştirme tablosunda tüm dört değer (`Light`, `VibrantLight`, `Dark`, `VibrantDark`) ele alınır; aksi halde wildcard kullanılmayan `match` ifadelerinde Rust derleyicisi exhaustiveness hatası verir ve macOS'ta vibrancy'li pencerelerde tema yanlış uygulanabilir.
- **Sistem temasını değiştirmek `window_background_appearance`'ı otomatik tetiklemez.** Pencerenin background'u açıldıktan sonra appearance değişimine bağlı olarak kendiliğinden güncellenmez; tema akışında manuel olarak `window.set_background_appearance(...)` çağrılır.
- **`Vibrant*` ile `WindowBackgroundAppearance::Blurred` çakışır.** İkisi birlikte kullanıldığında macOS'ta iki ayrı materyal/bulanıklık etkisi üst üste binebilir. Tasarım sisteminde yalnızca bir katman tercih edilir.


---
