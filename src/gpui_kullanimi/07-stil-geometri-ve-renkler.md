# Stil, Geometri ve Renkler

---

## Styled

`Styled`, `gpui` paketi içerisindeki ortak stil trait'idir. `style(&mut self) -> &mut StyleRefinement` şeklinde zorunlu bir metot barındırır. GPUI çekirdeğindeki `Div`, `Img`, `Svg`, `Canvas`, `List`, `UniformList` ve `Surface` bileşenleri bu trait aracılığıyla aynı akıcı (fluent) stil sözlüğünden faydalanır. Benzer şekilde, Zed UI bileşenlerinin büyük kısmı da kendi stil alanlarını bu ortak arayüze bağlar.

GPUI stil sistemi CSS ve TailwindCSS prensiplerine benzeyen akıcı metot zincirlerinden oluşur. Arka planda Rust veri tipleri yer aldığı için, hangi özelliğin hangi değeri kabul ettiği derleme aşamasında doğrulanmış olur. Örnek bir stil zinciri şu şekildedir:

```rust
div()
    .bg(rgb(0xff0000))
    .rounded_sm()
    .p_2()
    .child("Merhaba")
```

`Styled` oldukça geniş bir API yüzeyi sağlamaktadır. Her bir yön, kenar veya ölçek yardımcısı için ayrı başlıklar açmak yerine, temel yardımcı metotlar aşağıdaki tabloda özetlenmiştir. Belirgin davranış farkı barındıran yapılar ise tablonun ardından detaylandırılmıştır.

| Stil Ailesi | `Styled` Fluent Metotları | Temel İşlevi |
|---|---|---|
| Görünürlük ve Ekran | `block`, `flex`, `grid`, `hidden`, `visible`, `invisible` | Elementin yerleşim (layout) akışına katılımını ve görünürlüğünü belirler. |
| Boyutlar (Dimensions) | `w`, `h`, `size`, `min_w`, `min_h`, `min_size`, `max_w`, `max_h`, `max_size`, `w_*`, `h_*`, `size_*`, `min_w_*`, `min_h_*`, `max_w_*`, `max_h_*`, `size_full`, `h_auto` | Genişlik, yükseklik, alt/üst sınırları ve hazır ölçeklendirme değerlerini tanımlar. |
| Dış Boşluk (Margin) | `m`, `mx`, `my`, `mt`, `mr`, `mb`, `ml`, `m_*`, `mx_*`, `my_*`, `mt_*`, `mr_*`, `mb_*`, `ml_*`, `m_neg_*`, `mx_neg_*`, `my_neg_*`, `mt_neg_*`, `mr_neg_*`, `mb_neg_*`, `ml_neg_*` | Element dış boşluklarını belirler. x/y eksenleri, t/r/b/l ise sırasıyla üst, sağ, alt ve sol kenarları temsil eder. Negatif değerler de desteklenir. |
| İç Boşluk (Padding) | `p`, `px`, `py`, `pt`, `pr`, `pb`, `pl`, `p_*`, `px_*`, `py_*`, `pt_*`, `pr_*`, `pb_*`, `pl_*` | Element iç boşluklarını tanımlar. Margin ailesinden farklı olarak padding üzerinde otomatik (auto) ve negatif değerler kullanılamaz. |
| Konumlandırma | `relative`, `absolute`, `inset`, `top`, `right`, `bottom`, `left`, `inset_*`, `top_*`, `right_*`, `bottom_*`, `left_*`, `inset_neg_*`, `top_neg_*`, `right_neg_*`, `bottom_neg_*`, `left_neg_*` | Konumlandırma kipini (`absolute`/`relative`) ve dört yöndeki öteleme (offset) değerlerini atar; `top` yukarıdan, `right` sağdan, `bottom` aşağıdan, `left` soldan hizalar. |
| Flex Yönü ve Davranışı | `flex_row`, `flex_row_reverse`, `flex_col`, `flex_col_reverse`, `flex_1`, `flex_auto`, `flex_initial`, `flex_none`, `flex_basis`, `flex_grow`, `flex_grow_0`, `flex_grow_1`, `flex_shrink`, `flex_shrink_0`, `flex_shrink_1`, `flex_wrap`, `flex_wrap_reverse`, `flex_nowrap` | Flex konteyner akış yönünü, satır taşma (wrap) davranışlarını ve alt öğelerin büyüme/küçülme kurallarını yapılandırır. |
| Hizalama Kontrolleri | `items_start`, `items_end`, `items_center`, `items_baseline`, `items_stretch`, `self_start`, `self_end`, `self_flex_start`, `self_flex_end`, `self_center`, `self_baseline`, `self_stretch`, `justify_start`, `justify_end`, `justify_center`, `justify_between`, `justify_around`, `justify_evenly`, `content_normal`, `content_start`, `content_end`, `content_center`, `content_between`, `content_around`, `content_evenly`, `content_stretch` | Flex/Grid eksenlerinde alt öğelerin, elementin kendisinin veya çok satırlı blokların yerleşim koordinatlarını düzenler. |
| Ara Boşluk (Gap) | `gap`, `gap_x`, `gap_y`, `gap_*`, `gap_x_*`, `gap_y_*` | Alt öğeler arasında bırakılacak genel, yatay veya dikey boşluk miktarını tanımlar. |
| Kenarlık ve Yuvarlama | `border`, `border_t`, `border_r`, `border_b`, `border_l`, `border_x`, `border_y`, `border_*`, `border_t_*`, `border_r_*`, `border_b_*`, `border_l_*`, `border_x_*`, `border_y_*`, `border_color`, `border_dashed`, `rounded`, `rounded_*` | Kenarlık kalınlıkları, kenarlık renkleri/stilleri ve köşe yuvarlama yarıçapı değerlerini ayarlar. |
| Gölge ve Opaklık | `shadow`, `shadow_none`, `shadow_2xs`, `shadow_xs`, `shadow_sm`, `shadow_md`, `shadow_lg`, `shadow_xl`, `shadow_2xl`, `opacity` | Hazır gölge şablonlarını, özel `BoxShadow` listelerini ve element şeffaflık derecesini (opacity) belirler. |
| Arka Plan ve Metin | `bg`, `text_style`, `text_color`, `text_bg`, `text_size`, `text_xs`, `text_sm`, `text_base`, `text_lg`, `text_xl`, `text_2xl`, `text_3xl`, `text_ellipsis`, `text_ellipsis_start`, `text_overflow`, `text_align`, `text_left`, `text_center`, `text_right`, `truncate`, `line_clamp`, `font`, `font_weight`, `font_family`, `font_features`, `italic`, `not_italic`, `underline`, `line_through`, `text_decoration_none`, `text_decoration_color`, `text_decoration_solid`, `text_decoration_wavy`, `text_decoration_*`, `line_height`, `whitespace_normal`, `whitespace_nowrap` | Arka plan renklerini, yazı tiplerini, metin hizalamalarını ve süslemelerini hiyerarşik yazı stili alanlarına yazar. |
| İmleç ve Taşma (Overflow) | `cursor`, `cursor_*`, `cursor_default`, `cursor_pointer`, `cursor_text`, `cursor_move`, `cursor_not_allowed`, `cursor_context_menu`, `cursor_crosshair`, `cursor_vertical_text`, `cursor_alias`, `cursor_copy`, `cursor_no_drop`, `cursor_grab`, `cursor_grabbing`, `overflow_hidden`, `overflow_x_hidden`, `overflow_y_hidden`, `scrollbar_width` | Fare imlecinin görsel şeklini, taşma durumlarında içeriğin kırpılmasını ve kaydırma çubuğu alanlarını denetler. |
| Grid ve En-Boy Oranı | `aspect_ratio`, `aspect_square`, `grid_cols`, `grid_cols_min_content`, `grid_cols_max_content`, `grid_rows`, `col_start`, `col_end`, `col_span`, `col_span_full`, `row_start`, `row_end`, `row_span`, `row_span_full` | Grid ızgara şablonlarını, en-boy oranlarını (`Aspect`) ve hücre yerleşim koordinatlarını yapılandırır; arka planda `GridTemplate`, `TemplateColumnMinSize` ve `GridPlacement` veri yapılarını kullanır. |

Yukarıdaki akıcı metotların büyük kısmı `Styled` trait gövdesinde el ile kodlanmamıştır; derleme sürecinde bir dizi proc-macro tarafından otomatik olarak üretilir. `gpui` paketi içerisinden çağrılan bu makrolar, `gpui_macros` paketi vasıtasıyla her bir çağrı için çok sayıda metot varyantı oluşturur. Hangi makronun hangi metotları ürettiği aşağıdaki tabloda detaylandırılmıştır:

| Üretici Makro (`gpui_macros::...!()`) | Üretilen Akıcı Metotlar (Styled Trait Üyesi Olarak) |
|---|---|
| `visibility_style_methods!()` | `visible()`, `invisible()` |
| `margin_style_methods!()` | `m_*` ile birlikte `mt_`, `mb_`, `my_`, `mx_`, `ml_`, `mr_` ve bunların aralık ölçekleri ile `auto` varyantları (örneğin `mt_auto()`) |
| `padding_style_methods!()` | `p_*`, `pt_`, `pb_`, `py_`, `px_`, `pl_`, `pr_` (margin ailesinin padding karşılıkları) |
| `position_style_methods!()` | `relative()`, `absolute()` ve konumlandırma öteleme metotları: `inset`, `top`, `bottom`, `left`, `right` |
| `overflow_style_methods!()` | `overflow_hidden()`, `overflow_x_hidden()`, `overflow_y_hidden()` |
| `cursor_style_methods!()` | `cursor(CursorStyle)`, `cursor_default()`, `cursor_pointer()`, `cursor_text()`, `cursor_move()`, `cursor_not_allowed()`, `cursor_context_menu()`, `cursor_crosshair()`, `cursor_vertical_text()`, `cursor_alias()`, `cursor_copy()`, `cursor_no_drop()`, `cursor_grab()`, `cursor_grabbing()` ve yeniden boyutlandırma yön imleçleri (örneğin `cursor_ew_resize()`) |
| `border_style_methods!()` | `border_color(C)` rengi ve `border_*` kalınlık metotları (`border_*`, `border_t_*`, vb.) ile kalınlık sonekleri (`_0`, `_1`, `_2`, `_4`, `_8`, vb.) |
| `box_shadow_style_methods!()` | `shadow(Vec<BoxShadow>)`, `shadow_none()`, `shadow_2xs()`, `shadow_xs()`, `shadow_sm()`, `shadow_md()`, `shadow_lg()`, `shadow_xl()`, `shadow_2xl()` |

Bu makrolar, `gpui_macros` paketi üzerinden dışa aktarılır ve dolaylı olarak `gpui` paket kökünden de erişilebilir kılınır. Uygulama geliştirme süreçlerinde bu makroların manuel çağrılmasına gerek yoktur; zira akıcı stil metotları `Styled` trait'inin yerleşik birer üyesidir ve bu trait'i uygulayan her nesne bu metotlara otomatik olarak sahip olur.

Flex faktörlerinin belirlenmesinde iki temel yaklaşım izlenir: Özel oranların hedeflendiği durumlarda `flex_grow(2.0)` veya `flex_shrink(0.5)` gibi doğrudan faktör değerleri atanır. CSS standartlarındaki `flex-grow: 1` ve `flex-shrink: 1` davranışları için ise `flex_grow_1()` ve `flex_shrink_1()` metotlarından yararlanılır. Büyüme veya küçülmeyi tamamen devre dışı bırakmak amacıyla `flex_grow_0()` ve `flex_shrink_0()` metotları kullanılırken; boyutu tamamen sabitlenmiş öğelerde `flex_none()` çağrısı grow, shrink ve basis ayarlarını bir arada yapılandırır.

### `BoxShadow` Yapılandırması

`BoxShadow` veri yapısı, gölgenin içe mi yoksa dışa mı çizileceğini belirleyen `inset: bool` alanını barındırır. Hazır sunulan `shadow_sm()`, `shadow_md()` ve benzeri yardımcı metotlar varsayılan olarak dış gölge (drop shadow) üretir; iç gölge (inset shadow) gereksinimlerinde ise doğrudan `BoxShadow` tanımı oluşturulmalıdır. `Style::paint(...)` render süreci dış gölgeleri arka plan ve kenarlıklardan önce, iç gölgeleri ise elementin kendi arka plan çiziminin ardından, alt öğe içeriklerinin çizilmesinden ise önce işleme alır.

| Nitelik | Temel İşlevi |
|---|---|
| `color` | Gölgenin renk tonunu belirler. |
| `offset` | Gölgenin X ve Y yönündeki kayma koordinatıdır. |
| `blur_radius` | Gölge yumuşatma/bulanıklık yarıçapıdır. |
| `spread_radius` | Gölgenin sınır genişleme/yayılma miktarıdır. |
| `inset` | `true` ise iç gölge (inset), `false` ise dış gölge (drop shadow) çizer. |

```rust
let ic_golge = BoxShadow {
    color: black().opacity(0.18),
    offset: point(px(0.), px(1.)),
    blur_radius: px(4.),
    spread_radius: px(0.),
    inset: true,
};

div()
    .rounded_md()
    .bg(rgb(0xffffff))
    .shadow(vec![ic_golge])
    .child("İç gölgeli alan")
```

`Styled` trait yapısı bünyesinde ayrıca `gpui_macros::style_helpers!()` makro çağrısı yer alır. Bu makro `#[doc(hidden)]` özniteliğiyle gizlendiği için standart kütüphane dökümantasyon listelerinde doğrudan sergilenmez. `w_*`, `h_*`, `size_*`, `min_size_*`, `min_w_*`, `min_h_*`, `max_size_*`, `max_w_*`, `max_h_*`, `gap_*`, `gap_x_*`, `gap_y_*` ve `rounded_*` gibi stil ailelerinin tamamı bu dahili makro tarafından üretilir.

Özel tasarlanan element sınıflarında `Styled` uygulandığında bu metotların tamamı otomatik olarak kazanılır; dolayısıyla makroların yeniden çağrılmasına gerek yoktur. Yalnızca GPUI mimarisinin kendisine benzer yeni bir stil çerçevesi (style framework) yazılacağı durumlarda, paralel bir `Styled` benzeri trait için bu makroların yeni arayüz gövdesinde çağrılması gerekebilir. Buradaki `method_visibility` parametresi, üretilen metotların genel (`public`) ya da paket içi (`pub(crate)`) görünürlük düzeylerini ayarlar.

**Tasarım Karar Rehberi.** Stil zincirleri tasarlanırken şu pratik kurallara uyulması önerilir:

- Görünüm çıktıları dinamik verilere bağlıysa, `Render` gövdesinde akıcı `.when(...)` koşullarından yararlanılmalıdır; stil özelliklerini sonradan eylem kodlarıyla (imperative) güncellenmeye çalışılmamalıdır.
- Kaydırma (scroll), klavye odağı (focus), ipuçları (tooltips) veya animasyon gibi ekran kareleri arasında durum korunması gereken elementlerin kimlikleri (IDs) mutlaka sabit tutulmalıdır; aksi halde bu veriler render döngüleri arasında kaybolur.
- Kapsayıcı üst öğenin yerleşim genişliği belirsiz (belirlenmemiş) olduğunda metin taşmaları, görsellerin en-boy oranları ve mutlak konumlandırılmış (`absolute`) alt öğelerin yerleşimleri beklenmeyen sonuçlar doğurabilir. Bu nedenle üst öğelerin boyut sınırlarının önceden belirginleştirilmesi önerilir.
- Kartlar, araç çubukları veya liste satırları gibi tekrar eden arayüz parçalarında boyutlar `min/max` veya `aspect_ratio` ile sınırlandırılmalıdır; etkileşim (hover) veya yüklenme durumlarının sayfa düzeninde kaymalara yol açmaması arayüz kararlılığı açısından kritik bir kuraldır.

## Geometri Tipleri ve Birim Yönetimi

### `Pixels`, `ScaledPixels` ve `DevicePixels` Ayrımı

GPUI yerleşim ve render süreçlerinde üç farklı piksel birimi kullanır. Ekran ölçeklendirmeleri değiştiğinde hangi birimin hangi katmanda devreye girdiğini bilmek, olası hizalama ve netlik hatalarının önüne geçer:

![GPUI Piksel Birimi Katmanları](assets/piksel-birimleri.svg)

- `Pixels(f32)`: Ölçekten bağımsız mantıksal piksel birimidir. Uygulama arayüz kodlarında neredeyse her zaman bu birim tercih edilir.
- `ScaledPixels(f32)`: Mantıksal pencerelerin ölçek katsayısıyla (`Pixels * window.scale_factor()`) çarpılmış halidir. Düşük seviyeli çizim motoruna (renderer) iletilen değerdir.
- `DevicePixels(i32)`: Fiziksel ekran cihaz pikselidir; doku (texture) boyutlarında ve görsel varlıkların (assets) ham çözünürlüklerinde kullanılır.

Yardımcı yapıcı fonksiyonlar şu şekildedir:

```rust
let piksel = px(12.0);             // Pixels
let rem = rems(1.5);               // Rems
let nokta = point(px(10.), px(20.)); // Point<Pixels>
let boyut = size(px(100.), px(40.)); // Size<Pixels>
let sinirlar = Bounds::from_corners(point(px(0.), px(0.)), point(px(100.), px(100.)));
```

Bu yardımcıların ürettikleri temel veri tipleri ve kullanım alanları aşağıda özetlenmiştir:

| Yardımcı Fonksiyon | Ürettiği Değer | Temel Kullanım Alanı |
|---|---|---|
| `px(value)` | `Pixels` | Mantıksal piksel değeri üretir. |
| `rems(value)` | `Rems` | Kök font boyutuna göre ölçeklenen uzunluk üretir. |
| `relative(fraction)` | `DefiniteLength::Fraction` | Üst öğe boyutunun belirli bir kesri oranında ölçü verir. |
| `percentage(value)` | `Percentage` | 0.0 - 1.0 aralığındaki yüzdelik oranları temsil eder. |
| `radians(value)` | `Radians` | Dönüşüm (rotation) ve dairesel çizimler için radyan değeri taşır. |
| `point(x, y)` | `Point<T>` | İki eksenli koordinat üretir. |
| `size(width, height)` | `Size<T>` | Genişlik ve yükseklik boyut çifti üretir. |
| `bounds(origin, size)` | `Bounds<T>` | Başlangıç noktası (origin) ve boyut ile sınır dikdörtgeni üretir. |

### `Rems`, `AbsoluteLength`, `DefiniteLength` ve `Length`

Mantıksal piksellerin dışındaki uzunluk tipleri, farklı yerleşim ihtiyaçlarına göre ayrılmıştır:

- `Rems(f32)`: Kök yazı tipi boyutuna göre ölçeklenir (Zed bünyesinde `theme.ui_font_size` değerine bağlıdır). `.text_sm()` veya `.gap_2()` gibi otomatik stil yardımcıları, genellikle arka planda Rems üzerinden mantıksal piksellere dönüşüm yapar.
- `AbsoluteLength`: `Pixels` veya `Rems` mutlak uzunluk varyantlarını barındırır.
- `DefiniteLength`: Kesin bir mutlak uzunluğu (`Absolute`) veya üst öğeye oranlı bir kesri (`Fraction`) temsil eder.
- `Length`: Kesin bir uzunluk değerini (`Definite`) ya da yerleşim motorunun kendisinin hesaplayacağı otomatik (`Auto`) modu tanımlar.

| Veri Yapısı | Desteklenen Metotlar | Temel Görevi |
|---|---|---|
| `AbsoluteLength` | `is_zero`, `to_pixels`, `to_rems` | Mutlak uzunluğu piksel/rem ayrımıyla taşır ve gerektiğinde dönüşüm yapar. |
| `DefiniteLength` | `to_pixels` | Auto olmayan, kesin veya parent oranlı uzunluk değeridir. |
| `Length` | `Definite`, `Auto` | Stil alanlarında kesin ölçü veya layout tarafından hesaplanan auto ölçüyü ayırır. |

Stil API'leri genel `Length` türünü kabul ettiği için, farklı birim tipleri aynı akıcı zincirde bir arada kullanılabilir:

```rust
div()
    .w(px(120.))               // Pixels (Mantıksal Piksel)
    .min_h(rems(2.))            // Rems (Kök Yazı Boyutuna Göreli)
    .flex_basis(relative(0.5)) // Fraction (Oransal Uzunluk)
    .h_auto()                  // Length::Auto (Otomatik Yükseklik)
```

### `Percentage`, `Radians`, `Half`, `IsZero`, `AvailableSpace` ve `LayoutId`

Bu yardımcı tipler stil zincirlerinde doğrudan geliştiriciye görünmez, ancak yerleşim motoru ve çizim hesaplamalarının ara değerlerini taşımak için kullanılır:

| Veri Yapısı | Kullanım Senaryosu |
|---|---|
| `Percentage` | Tam daire oranlarından `Radians` üretmek veya yüzdelik değerleri açık tipler halinde taşımak amacıyla kullanılır. |
| `Radians` | `TransformationMatrix::rotate(...)` metotlarında, path yaylarında ve SVG rotasyon hesaplarında yer alır. |
| `Half` | Sayısal veya geometrik değerlerin yarısını generic biçimde hesaplamayı sağlayan trait'dir. |
| `IsZero` | `Pixels`, `Rems`, `ScaledPixels`, `DevicePixels` gibi tiplerde sıfır kontrolü yapmayı ortaklaştırır. |
| `AvailableSpace` | Taffy yerleşim motorunun ölçüm süreçlerinde kesin alan veya minimum/maksimum boşluk bilgilerini taşır. |
| `LayoutId` | Taffy yerleşim ağacındaki düğüm kimlikleridir; uygulama düzeyinde kalıcı kimlik olarak kullanılmaz. |

| Arayüz / Yapı | Desteklenen Metotlar | Temel İşlevi |
|---|---|---|
| `Axis` | `Vertical`, `Horizontal`, `invert` | Ana yerleşim eksenini seçer ve karşı eksene geçişi (invert) sağlar. |
| `Along` | `along`, `apply_along` | Bir değeri verilen eksende okur veya yalnız o eksen doğrultusunda dönüştürür. |
| `Half` | `half` | İlgili değerin yarısını hesaplar. |
| `IsZero` | `is_zero` | Değerin sıfır olup olmadığını denetler. |
| `AvailableSpace` | `Definite`, `MinContent`, `MaxContent` | Layout ölçümünde kesin, min-content veya max-content alan bilgisini taşır. |

### `Point`, `Size`, `Bounds`, `Edges` ve `Corners`

Jenerik geometrik kapsayıcı tipleri olan `Point<T>`, `Size<T>`, `Bounds<T>`, `Edges<T>` ve `Corners<T>`, çoğu veri tipi için standart matematiksel operatör (`+`, `-`, `*`, `/`) aşırı yüklemelerini (operator overloading) destekler.

**Geometri Tiplerinin Sunduğu API Yüzeyi.** Geometri yapıları üzerinde yer alan ve yaygın kullanılan yardımcı fonksiyonlar ile alanlar şunlardır:

| Geometrik Yapı | Sunulan Metotlar ve Alanlar | Temel İşlevi |
|---|---|---|
| `Point<T>` | `x`, `y`, `new`, `map`, `scale`, `magnitude`, `relative_to`, `max`, `min`, `clamp` | Konum koordinatlarını dönüştürür, ölçekler ve sınırlar. |
| `Size<T>` | `width`, `height`, `new`, `map`, `center`, `scale`, `max`, `min`, `full`, `auto`, `to_pixels`, `to_device_pixels` | Genişlik/yükseklik boyut çiftlerini üretir ve dönüştürür. |
| `Bounds<T>` | `origin`, `size`, `centered`, `maximized`, `new`, `from_corners`, `from_anchor_and_size`, `centered_at`, `intersects`, `center`, `dilate`, `inset`, `contains`, `scale`, `to_pixels` | Dikdörtgen alanları, köşeleri, merkez koordinatlarını, kesişimleri ve alan dönüşümlerini hesaplar. |
| `Edges<T>` | `top`, `right`, `bottom`, `left`, `all`, `map`, `any`, `auto`, `zero`, `to_pixels` | Dört kenar boşluğu (padding/margin) veya inset değerini taşır. |
| `Corners<T>` | `top_left`, `top_right`, `bottom_right`, `bottom_left`, `all`, `corner`, `clamp_radii_for_quad_size`, `map` | Dört köşe yuvarlama yarıçapını ve köşe bazlı erişimleri yönetir. |
| `Pixels` | `as_f32`, `floor`, `round`, `ceil`, `scale`, `pow`, `abs` | Mantıksal piksel değerlerinde yuvarlama ve ham değer erişimleri sağlar. |
| `ScaledPixels` | `as_f32`, `floor`, `round`, `ceil` | Ölçeklenmiş piksel değerlerini çizim katmanına uygun biçimde yuvarlar. |
| `Rems` | `is_zero`, `to_pixels`, `half` | Rem değerlerini piksele dönüştürür ve sıfır/yarıya bölme kontrolleri sunar. |
| `DevicePixels` | `to_bytes` | Fiziksel piksel sayısından ekran bellek (buffer) byte miktarlarını hesaplar. |

### Altın Oran (`phi`) Sabiti

`geometry` modülündeki `phi() -> DefiniteLength` fonksiyonu, altın oran katsayısını `relative(1.618_034)` olarak döndürür; bu değer üst öğenin **1.618 katına** tekabül eder. GPUI, varsayılan `TextStyle::line_height` değeri olarak bu `phi()` sabiti kullanır; dolayısıyla bir yazı tipi için satır yüksekliği varsayılan olarak `font_size * 1.618` şeklinde hesaplanır. Arayüz yerleşim oranlamalarında (örneğin altın orana sahip iki sütunlu tasarımlarda) üst öğeye bağlı oransal yükseklikler veya genişlikler atamak için bu sabitten yararlanılabilir.

**Dikkat Edilmesi gereken Geometrik Detaylar.** Geometri hesaplamalarında sıkça yapılan hatalar şunlardır:

- `Bounds::contains(point)` kontrolü, sınır çizgilerinde yarı açık aralık kurallarına göre çalışır; dolayısıyla tam sınır pikseli üzerindeki koordinatlar için `false` döndürebilir.
- `Pixels` ile `ScaledPixels` tipleri arasındaki matematiksel işlemler için `From` veya `Into` trait'leri aracılığıyla açık (explicit) dönüştürme yapılması zorunludur; sistem otomatik gizli çevrim yapmaz.
- `point(x, y)` koordinat argümanlarının sırası önce X (yatay) ardından Y (dikey) şeklindedir; `size(width, height)` yapısı da aynı sıralama kuralına tabidir.

## Layout, Style ve Dönüşüm API Tamamlayıcıları

Stil ve geometri dökümanlarında geçen bazı veri tipleri doğrudan akıcı metot zincirlerinde görünmez. Ancak özel element sınıfları, tuval (canvas) yapıları, popover pencereleri veya düşük seviyeli render motoru entegrasyonları yazılırken bu tiplerle karşılaşılır:

### `AlignItems`, `AlignSelf`, `AlignContent`, `JustifyItems`, `JustifySelf` ve `JustifyContent`

Bu hizalama tipleri, akıcı metotların arka planındaki ham yerleşim modelini oluşturur. Uygulama geliştirilirken genellikle `.items_center()`, `.justify_between()` veya `.content_stretch()` gibi hazır yardımcılar tercih edilir; ancak özel bir element veya stil editörü tasarlanırken `Style` veri yapısının alanlarını doğrudan güncellemek gerekebilir:

| Hizalama Tipi | Desteklenen Varyantlar | Temel İşlevi |
|---|---|---|
| `AlignItems`, `AlignSelf`, `JustifyItems`, `JustifySelf` | `Start`, `End`, `FlexStart`, `FlexEnd`, `Center`, `Baseline`, `Stretch` | Tek satır veya tek bir öğenin hizalanma modelidir. `self` varyantları, parent (üst öğe) hizalama tercihlerini ezmek için kullanılır. |
| `AlignContent`, `JustifyContent` | `Start`, `End`, `FlexStart`, `FlexEnd`, `Center`, `Stretch`, `SpaceBetween`, `SpaceEvenly`, `SpaceAround` | Çok satırlı Flex/Grid içeriklerinin eksenler üzerindeki dağılım politikalarını belirler. |

### `Display`, `FlexDirection`, `FlexWrap`, `Visibility`, `WhiteSpace`, `TextOverflow`, `TextAlign`, `Overflow`, `Position` ve `Fill`

Bu enum veri yapıları; sayfa düzeni (layout), görünürlük, metin taşmaları ve şekil dolgusu (paint fill) kararlarını taşır:

| Yapı / Enum | Desteklenen Değerler | Temel İşlevi |
|---|---|---|
| `Display` | `Block`, `Flex`, `Grid`, `None` | Alt öğelerin yerleşim algoritmasını seçer; `None` öğeyi yerleşim akışından tamamen çıkarır. |
| `FlexDirection` | `Row`, `Column`, `RowReverse`, `ColumnReverse` | Flex konteynerin ana eksenini ve akış yönünü belirler. |
| `FlexWrap` | `NoWrap`, `Wrap`, `WrapReverse` | Flex öğelerin tek bir satırda mı kalacağını yoksa yeni satırlara mı taşacağını denetler. |
| `Visibility` | `Visible`, `Hidden` | Elementin çizimini açar veya kapatır; `Hidden` görünürlüğü kapatsa da kapladığı yerleşim alanını korur. |
| `WhiteSpace` | `Normal`, `Nowrap` | Metinlerin satır sonlarında alt satıra kırılıp kırılmayacağını belirler. |
| `TextOverflow` | `Truncate`, `TruncateStart` | Sığmayan uzun metinleri sondan veya baştan üç nokta koyarak kısaltır. |
| `TextAlign` | `Left`, `Center`, `Right` | Metinleri kapsayıcı kutu içinde sola, ortaya veya sağa hizalar. |
| `Overflow` | `Visible`, `Clip`, `Hidden`, `Scroll` | Taşma yapan alt öğelerin yerleşim ve kaydırma (scroll) sınırlarını belirler. |
| `Position` | `Relative`, `Absolute` | Konumlandırma ötelemelerinin normal akışa göre mi yoksa konumlandırılmış üst öğeye göre mi hesaplanacağını belirler. |
| `Fill` | `Color(Background)` | Şekil dolgu rengini `Background` yapısı üzerinden taşır. |

### `Style` ve `StyleRefinement`

`Style::text_style()` metodu aktif metin stilini türetir; `has_opaque_background()` opak zemin olup olmadığını denetler. `overflow_mask(...)` sınırlar ve rem boyutlarından overflow kırpma maskesini (clipping mask) üretir; `paint(bounds, window, cx, paint_child)` ise arka planı, kenarlıkları, `box_shadow` efektlerini ve alt öğeleri doğru çizim sırasıyla boyar. `align_items`, `align_self`, `align_content`, `justify_content` ve `flex_direction` alanları doğrudan Taffy yerleşim kararlarına iletilir. `allow_concurrent_scroll` ile `restrict_scroll_to_axis` kaydırma davranışlarını, `mouse_cursor` imleç stillerini, `grid_location` ise hücre yerleşimlerini yönetir. `StyleRefinement::grid_location_mut()` grid konumlandırma alanını oluşturup geri döndürür. Bu metotlar stil zincirinin alt katman mekanizmalarıdır; standart `div()` zincirlerinde el ile çağrılmasına gerek yoktur.

| Veri Yapısı | Desteklenen Metotlar | Temel İşlevi |
|---|---|---|
| `Style` | `text_style`, `has_opaque_background`, `overflow_mask`, `paint` | Çözümlenmiş nihai stilin metin, arka plan, taşma kırpması ve boyama davranışlarını yürütür. |
| `StyleRefinement` | `grid_location_mut`, `style` | Akıcı metot zincirinin biriktirdiği stil alanlarını taşır ve grid konum verilerini lazy (tembel) olarak oluşturur. |

### `ObjectFit` Yapısı

`ObjectFit::get_bounds(container, image_size)` fonksiyonu; görsellerin `Fill`, `Contain`, `Cover`, `ScaleDown` veya `None` davranışlarında container içerisine hangi dikdörtgen boyutlarıyla yerleşeceğini hesaplar. Standart görsel kullanımlarında `img(...).object_fit(...)` metodu yeterlidir; ancak özel bir `paint_image` veya surface elementi tasarlanırken geometrik hesaplamaların tekrarlanmaması amacıyla bu metot tercih edilmelidir.

| Varyant / Metot | Temel İşlevi |
|---|---|
| `Fill` | Görseli kapsayıcı alana sığacak şekilde esnetir. |
| `Contain` | Görselin tamamı görünecek şekilde, en-boy oranını koruyarak sığdırır. |
| `Cover` | Kapsayıcı alanı tamamen dolduracak şekilde resmi büyütür; taşan kısımlar kırpılabilir. |
| `ScaleDown` | Büyük boyutlu görselleri sığdıracak şekilde küçültür; görsel zaten küçükse orijinal boyutları korur. |
| `None` | Görselin orijinal boyutunu aynen korur. |
| `get_bounds` | Seçilen yerleşim davranışı için hedef `Bounds<Pixels>` koordinatlarını hesaplar. |

### `Axis` ve `Along` Yapıları

`Axis` ve `Along` yapıları, yatay veya dikey doğrultu kararlarını generic hale getirir. `Axis::invert()` yatay ekseni dikey eksene (ya da tersine) çevirir; örneğin pencerelerin bölünmesi (split panes) veya yeniden boyutlandırma tutamaklarının eksen dönüşümlerinde kullanılır. `Along::Unit`, ilgili implementasyonun her eksende taşıdığı birim veri tipini belirtir. `Along::along(axis)` verilen eksendeki değeri okur, `Along::apply_along(axis, f)` ise yalnızca o eksen doğrultusunda dönüştürme yapar. `Anchor::opposite()` bir kenetlenme referansının tam karşısını, `Anchor::other_side_along(axis)` yalnızca belirtilen eksen boyunca karşı yönü döndürür; `Anchor::is_center()` ise yatay veya dikey merkezleme durumlarını ayırt eder. Kaydırma çubukları, popover pencereleri ve iki eksenli yerleşim yardımcıları tasarlanırken bu metotlar koordinat hesaplamalarını büyük ölçüde sadeleştirir.

### `GridTemplate`, `TemplateColumnMinSize`, `GridLocation` ve `GridPlacement`

`GridTemplate` yapısı, CSS standartlarındaki `repeat(<n>, minmax(_, 1fr))` benzeri ızgara izi şablonlarını tanımlar; `TemplateColumnMinSize` bu izlerin alabileceği minimum genişliği veya yüksekliği belirler. `GridLocation` bir öğenin grid içerisindeki satır/kolon koordinat aralığını tutar; her bir aralık ise `GridPlacement` değerlerinden oluşur.

| Veri Yapısı | Desteklenen Nitelikler | Temel İşlevi |
|---|---|---|
| `TemplateColumnMinSize` | `Zero`, `MinContent`, `MaxContent` | Grid izi minimum sınırının sıfır, min-content veya max-content olacağını belirler. |
| `GridTemplate` | `repeat`, `min_size` | Kaç ızgara izi üretileceğini ve minimum iz boyutlarını tanımlar. |
| `GridLocation` | `row`, `column` | Hücrenin grid içinde kapladığı satır ve kolon aralıklarını belirtir. |
| `GridPlacement` | `Line(i16)`, `Span(u16)`, `Auto` | Grid başlangıç/bitiş çizgilerini veya otomatik yerleşim verilerini taşır. |

### Düşük Seviyeli Ölçüm Yardımcıları

`MIN`, `MAX`, `ZERO`, `bounds(...)`, `union(...)` ve `Bounds::intersect(&other)` gibi yapılar, yerleşim motorunun alt katman yardımcılarıdır. `Bounds::intersect` iki dikdörtgenin kesiştiği ortak alanı hesaplar; kaydırma maskeleri (scroll mask), popover pencerelerinin görünürlük alanları veya tuval (canvas) kırpmaları üretilirken kullanılır.

### `PathBuilder` ve `PathStyle`

`PathBuilder::fill()` ve `stroke(width)` ile başlatılan çizim yolları; `move_to`, `line_to`, `curve_to`, `cubic_bezier_to`, `arc_to`, `relative_arc_to`, `add_polygon`, `close` ve `build` metotlarıyla tamamlanır. `PathBuilder::with_style(...)` işlevi, hazır oluşturulmuş builder'ın `PathStyle::{Fill, Stroke}` stil ayarlarını Lyon kütüphanesi seçenekleriyle yapılandırmaya olanak tanır. `PathBuilder::build_path(buf)` metodu, tessellator aşamasından gelen `VertexBuffers` değerlerini doğrudan `Path<Pixels>` geometrisine dönüştüren düşük seviyeli bir köprüdür; normal çizimlerde genellikle `build()` çağrısının içerisinden yürütülür.

| Çizim Yapısı | Desteklenen Metotlar | Temel İşlevi |
|---|---|---|
| `PathStyle` | `Fill`, `Stroke` | Tessellation (mozaikleme) işleminin dolgu mu yoksa çizgi mi üreteceğini belirler. |
| `PathBuilder` | `style`, `stroke`, `fill`, `move_to`, `line_to`, `curve_to`, `arc_to`, `close`, `build` | SVG tabanlı çizim komutlarını GPUI `Path<Pixels>` formatına dönüştürür. |

### `Path`, `Transformation` ve `TransformationMatrix`

`Path<Pixels>::new`, `scale`, `move_to`, `line_to`, `curve_to`, `push_triangle` ve `clipped_bounds` metotları, mozaiklenmiş (tessellated) çizim verileri üzerinde işlem yapar; bu seviye doğrudan çizim motorunun (renderer) işlem katmanını temsil eder. `Transformation` veri yapısı, SVG elementlerine özel ergonomik bir dönüşüm builder'ıdır; `TransformationMatrix::unit()`, `translate(...)`, `rotate(...)`, `scale(...)`, `compose(...)` ve `apply(...)` çağrıları sahne grafiklerine uygulanacak dönüşüm matrislerini üretir. Bu dönüşümler yalnızca görsel sunumu etkiler; yerleşim sınırlarını (layout bounds) veya etkileşim alanlarını (hitbox sizes) otomatik olarak güncellemez.

| Geometri Dönüşüm Yapısı | Desteklenen Metotlar | Temel İşlevi |
|---|---|---|
| `Path` | `vertices`, `bounds`, `new`, `scale`, `move_to`, `line_to`, `push_triangle`, `clipped_bounds` | Mozaiklenmiş (tessellated) çizim verilerini ve geometrik sınırları taşır. |
| `Transformation` | `scale`, `rotate`, `translate`, `with_scaling`, `with_translation` | SVG tabanlı dönüşüm tanımlarını akıcı builder formatında yönetir. |
| `TransformationMatrix` | `rotation_scale`, `translation`, `unit`, `translate`, `rotate`, `scale`, `compose` | Sahne elemanlarına uygulanacak olan matris verilerini saklar. |

## Renkler, Gradient ve Arka Plan Yönetimi

### `Rgba` ve `Hsla` Renk Tipleri

GPUI renk tanımlamalarını iki temel tipte ifade eder:

- `Rgba { r, g, b, a }`: Kırmızı, yeşil, mavi ve alfa bileşenleri 0.0 ile 1.0 aralığındadır.
- `Hsla { h, s, l, a }`: Hue (renk özü), doygunluk, parlaklık ve alfa bileşenleri 0.0 ile 1.0 aralığındadır.

Renk tanımlama çağrıları genellikle şu biçimlerde gerçekleştirilir:

```rust
let kirmizi = rgb(0xff0000);                // Rgba, alfa 1.0
let yari_saydam = rgba(0xff000080);         // 0xRRGGBBAA formatı
let hsl_rengi = hsla(0.0, 1.0, 0.5, 1.0);   // Saf kırmızı HSLA
let gri = opaque_grey(0.5, 1.0);            // Gri rengi yardımcısı
```

| Renk Yardımcıları | Temel İşlevi |
|---|---|
| `rgb(value)` | `0xRRGGBB` formatındaki hex değerinden opak `Rgba` üretir. |
| `rgba(value)` | `0xRRGGBBAA` formatındaki hex değerinden alfa dahil `Rgba` üretir. |
| `hsla(h, s, l, a)` | 0.0 - 1.0 aralığındaki bileşenlerden `Hsla` üretir. |
| `opaque_grey(value, opacity)` | Eşit RGB oranlarına sahip gri renk tonlu `Hsla` üretir. |
| `swap_rgba_pa_to_bgra(&mut [u8])` | Byte dilimini premultiplied-alpha RGBA formatından BGRA formatına yerinde dönüştürür. |

### Hazır Renk Sabitleri

Tümü `pub const fn ... -> Hsla` biçiminde tanımlanmış olan hazır renk sabitleri şunlardır:

| Renk Sabiti | HSLA Değer Karşılığı | Açıklaması |
|---|---|---|
| `black()` | `(0.0, 0.0, 0.0, 1.0)` | Saf opak siyah |
| `white()` | `(0.0, 0.0, 1.0, 1.0)` | Saf opak beyaz |
| `transparent_black()` | `(0.0, 0.0, 0.0, 0.0)` | Tamamen şeffaf siyah (gradient geçişleri için ideal) |
| `transparent_white()` | `(0.0, 0.0, 1.0, 0.0)` | Tamamen şeffaf beyaz |
| `red()` | `(0.0, 1.0, 0.5, 1.0)` | Doygun kırmızı |
| `blue()` | `(0.666…, 1.0, 0.5, 1.0)` | Doygun mavi |
| `yellow()` | `(0.166…, 1.0, 0.5, 1.0)` | Doygun sarı |
| `green()` | `(0.333…, 1.0, 0.25, 1.0)` | Lightness (parlaklık) değeri 0.25 olan koyu yeşil renk |

Bu sabitler Zed'in kendi tasarım sistemi temalarından bağımsızdır; dolayısıyla uygulama temasıyla uyumlu renkler için daima `cx.theme().colors()` arayüzü kullanılmalıdır. Hazır renk sabitleri daha çok hata ayıklama yer tutucularında (debug placeholders) veya test ortamlarında tercih edilir.

**Renk Yapıları Üzerindeki Yardımcı Metotlar:**

| Veri Yapısı | Desteklenen Metotlar | Temel İşlevi |
|---|---|---|
| `Rgba` | `r`, `g`, `b`, `a`, `blend` | RGBA bileşenlerini taşır ve renkleri alfa oranına göre birleştirir (blend). |
| `Hsla` | `h`, `s`, `l`, `a`, `is_transparent`, `fade_out`, `blend`, `grayscale`, `to_rgb` | Alfa geçişleri, gri ton dönüşümleri ve RGB format çevrimlerini yönetir. |

### `Background`, `ColorSpace` ve `LinearColorStop`

Pencere arka planları yalnızca düz renklerden ibaret değildir; gradient geçişleri ve görsel desenler de arka plan tanımı kapsamındadır:

```rust
solid_background(rgb(0xffffff))
linear_gradient(
    derece_acisi,
    linear_color_stop(rgb(0x000000), 0.0),
    linear_color_stop(rgb(0xffffff), 1.0),
)
checkerboard(rgb(0xeeeeee), 8.0)
pattern_slash(rgb(0xff0000), 2.0, 6.0)
```

| Arka Plan Yardımcıları | Temel İşlevi |
|---|---|
| `solid_background(color)` | Tek renkli opak/saydam `Background` üretir. |
| `linear_gradient(angle, from, to)` | İki renk durağına sahip doğrusal gradient `Background` üretir. |
| `linear_color_stop(color, percentage)` | `LinearColorStop` üretir; yüzde oranları 0.0 - 1.0 aralığındadır. |
| `checkerboard(color, size)` | Kareli desen (checkerboard) formatında `Background` üretir. |
| `pattern_slash(color, width, interval)` | Çapraz taramalı çizgi deseni formatında `Background` üretir. |
| `Background` | `as_solid`, `color_space`, `opacity`, `is_transparent` metotlarıyla düz renk sorgusu, renk uzayı denetimi ve saydamlık kontrolleri yapar. |
| `ColorSpace` | Gradient renk geçişlerinin hesaplanacağı renk uzayını (`Srgb` veya `Oklab`) seçer. |
| `LinearColorStop` | Gradient renk geçiş durağını ve yüzde konumunu temsil eder. |

`linear_gradient(...).color_space(ColorSpace::Oklab)` ile renk geçişlerinin Oklab renk uzayında yapılması sağlanabilir. `solid_background` dışındaki gradient ve desenli kullanımlarda `Background::as_solid()` çağrısı `None` döndürür. `.bg(impl Into<Background>)` stil metodu her `Styled` uygulamasında mevcuttur. Düz `Hsla` renkleri de `Into<Background>` trait'ini uyguladığından, `.bg(theme.colors().panel_background)` şeklinde atamalar sıklıkla tercih edilir.

**Renk ve Gradient Kullanım Kuralları:**

- Saydamlık (alfa) değeri 0 olan bir renk, opak bir arka plan üzerine çizildiğinde görsel olarak yine opak duracaktır; dolayısıyla gerçekten saydam arayüzler tasarlanmak istendiğinde üst katmanlardaki opak arka planların kaldırılması gerekir.
- `hsla(...)` yardımcısında hue (renk özü) değeri 1.0 sınırından sonra otomatik sarılmaz (`wrap` edilmez), kırpılır (`clamp`). Bu nedenle renk döndürme (rotation) işlemlerinde `hue + delta` değerinin modulo 1.0 formülüyle el ile hesaplanması gereklidir.

### `HighlightStyle` ve `combine_highlights`

`TextStyle::highlight(...)` metodu, çözümlenmiş yazı stillerine vurgu (highlight) stilleri uygular; `HighlightStyle::highlight(other)` ise iki farklı vurgu stilini birleştirir. `combine_highlights(...)` işlevi, metin aralıkları taşıyan çoklu vurgu katmanlarını bir araya getirmede rol oynar.

### `Colors`, `GlobalColors`, `DefaultColors` ve `DefaultAppearance`

`Colors`, `GlobalColors`, `DefaultColors` ve `DefaultAppearance` yapıları, GPUI'nin yerleşik temel renk paletini taşır. `Colors::light()`, `dark()` veya `for_appearance(window)` metotları varsayılan sistem paletlerine erişim sunar. Zed uygulama arayüzlerinde ise asıl renk kaynağı her zaman tema sistemi üzerinden `cx.theme().colors()` olmalıdır.

| Temel Renk Yapısı | Desteklenen Metotlar | Temel İşlevi |
|---|---|---|
| `Colors` | `text`, `selected_text`, `background`, `disabled`, `border`, `container`, `dark`, `light` | GPUI varsayılan renk paletlerini saklar. |
| `GlobalColors` | `0` | `Arc<Colors>` yapısının global sarmalayıcısıdır. |
| `DefaultColors` | `default_colors` | `App` bağlamı üzerinden global varsayılan renklere erişim sağlar. |
| `DefaultAppearance` | `Light`, `Dark` | Varsayılan renk setinin açık/koyu mod durumunu taşır. |

## `SharedString`, `SharedUri` ve Ucuz Klonlanan Tipler

Arayüz ağaçları her ekran karesinde sıfırdan yeniden oluşturulduğu için, standart metin (`String`) ve adres (URI) kopyalama/bellek ayırma (allocation) maliyetleri performans kayıplarına yol açabilir. GPUI bu maliyetleri en aza indirmek amacıyla `Arc` tabanlı veri tipleri sunar:

- `SharedString`: `gpui_shared_string::SharedString` tipinin yeniden ihraç edilmiş halidir. Arka planda `SmolStr` ile desteklenir. `Clone`, `Display`, `AsRef<str>` ve standart Rust string tiplerinden `From` dönüşümlerini tam olarak destekler.
- `SharedUri`: Benzer stratejiyle URI verilerini saklar; görsel yükleme kaynaklarında (`ImageSource::Resource`) sıklıkla tercih edilir.

Render süreçlerinde her ekran karesinde dinamik `String` üretmek yerine, görünüm (view) durum verilerinde `SharedString` saklamak yaygın ve performanslı bir tasarım kalıbıdır:

```rust
struct Baslik {
    baslik: SharedString,
}

impl Baslik {
    fn basligi_ayarla(&mut self, baslik: impl Into<SharedString>, cx: &mut Context<Self>) {
        self.baslik = baslik.into();
        cx.notify();
    }
}

impl Render for Baslik {
    fn render(&mut self, _: &mut Window, _: &mut Context<Self>) -> impl IntoElement {
        div().child(self.baslik.clone())
    }
}
```

**Bellek Dostu Diğer Tipler:**

- `Arc<str>`, `Arc<Path>` ve `Arc<[T]>`: GPUI çekirdek API'leri bellek kopyalamalarını azaltmak için yoğun şekilde `Arc` paylaşımlı dilimleri bekler.
- `Hsla` ve `Rgba`: Kopyalanabilir (`Copy`) tipler oldukları için doğrudan değer olarak geçirilirler.
- `ElementId`: Hafif bir klonlama (`Clone`) maliyeti barındırır.

**Performans Kuralları:**

- `SharedString::from(String)` dönüşümü `SmolStr::from(text)` üzerinden yürütülür. Metinlerin sık yenilenen döngülerde sürekli yeniden üretilmesinden (string allocation) kaçınılmalıdır.
- `.to_string()` çağrısı bellekte tamamen yeni bir `String` alanı ayırır; zorunlu olmayan durumlarda bunun yerine `.as_ref()` veya doğrudan `Display` trait'i üzerinden okuma tercih edilmelidir.
- Metin biçimlendirme (`format!`) makroları her ekran karesinde çalıştığında bellek ayırma maliyeti oluşturur; bu nedenle biçimlendirilmiş metinler bildirim tetiklemeleri veya kullanıcı girdileriyle güncellendikten sonra görünüm durum verilerinde önbelleğe alınmalıdır.

## `WindowAppearance` ve Tema Modu

`WindowAppearance` enum yapısı sistemin görünüm modlarını temsil eder:

```rust
pub enum WindowAppearance {
    Light,
    VibrantLight,
    Dark,
    VibrantDark,
}
```

`Vibrant` varyantları, macOS işletim sisteminin yerel `NSAppearance` değerleriyle doğrudan eşleşir. Diğer platformlar da bu enum yapısını desteklemekle birlikte, vibrancy efektlerinin görsel karşılıkları hedef işletim sisteminin grafik motoruna bağlıdır. İşletim sistemi açık veya koyu mod tercihini değiştirdiğinde GPUI bu durumu platform görünümü sinyali olarak yansıtır ve Zed temaları da varsayılan olarak bu sinyali takip eder.

**Görünüm Sinyallerini İzleme:**

- `cx.window_appearance() -> WindowAppearance`: Uygulama genelindeki platform tercihlerini döndürür.
- `window.appearance() -> WindowAppearance`: Aktif pencerenin onaylanan gerçek görünümünü verir (üst öğeler bunu ezebilir).
- `window.observe_window_appearance(|window, cx| ...)`: Pencere düzeyinde görünüm değişikliklerini izler.
- `cx.observe_window_appearance(window, |gorunum, window, cx| ...)`: `Context<T>` içerisinden görünüm verileriyle birlikte değişiklikleri gözlemler.
- `window.observe_button_layout_changed(...)` ve `cx.observe_button_layout_changed(window, ...)`: Platform kontrol butonlarının (traffic lights vb.) dizilim düzeni değiştiğinde tetiklenir.

Zed kod tabanında, sistem görünüm modunun izlenmesi ve temaların güncellenmesi şu şekilde koordine edilir:

```rust
cx.observe_window_appearance(window, |_, window, cx| {
    let gorunum = window.appearance();
    *SystemAppearance::global_mut(cx) = SystemAppearance(gorunum.into());
    theme_settings::reload_theme(cx);
    theme_settings::reload_icon_theme(cx);
}).detach();
```

**Dikkat Edilmesi Gereken Sistem Detayları:**

- macOS dışında `VibrantLight` ve `VibrantDark` modları üretilmeyebilir; ancak platformlar arası kod uyumluluğu açısından eşleştirme bloklarında bu dört varyantın da ele alınması gereklidir.
- `observe_window_appearance` akışı tetiklendiğinde, Zed sistem görünümünü güncelleyerek temaları yeniden yükler. Pencere arka plan renklerinin eş zamanlı güncellenmesi için ise `SettingsStore` gözlemcileri aracılığıyla `window.set_background_appearance(cx.theme().window_background_appearance())` çağrısı haricen işletilir.
