# 11. Asset, Image, Path ve Çizim

---

## 11.1. Asset, Image ve SVG Yükleme

Kaynak: `crates/gpui/src/asset_cache.rs`, `assets.rs`, `elements/img.rs`, `svg.rs`.

Bir uygulamada icon, font, image gibi varlıklar (asset) farklı yerlerden gelebilir: binary'ye gömülü olabilir, diskten okunabilir, ağdan indirilebilir. GPUI bu kaynakları soyutlayan üç katmanlı bir sistem kullanır: **`Asset` trait** async loader sözleşmesini, **`Resource` enum** kaynağın nereden geleceğini, **`AssetSource` trait** gömülü asset'lerin nasıl çözümleneceğini belirler. Element seviyesinde (`img`, `svg`) bu katmanlar şeffaf çalışır — kullanıcı sadece bir kaynak verir, sistem doğru yoldan yükler.

### `Asset` trait

```rust
trait Asset {
    type Source: ...;
    type Output: ...;
    fn load(source: Self::Source, cx: &mut App) -> impl Future<Output = Self::Output>;
}
```

### Kaynak gösterimi (`Resource`)

- **`Resource::Path(Arc<Path>)`** — Dosya sistemi yolu.
- **`Resource::Uri(SharedUri)`** — `http://`, `https://`, `file://` URI.
- **`Resource::Embedded(SharedString)`** — `AssetSource` içine gömülü asset (örn. `RustEmbed`).

`AssetSource` trait, `App::with_assets` ile kurulan global asset provider'dır. `crates/assets` Zed binary'sinde `RustEmbed` ile SVG/icon'ları binary'ye dahil eder. Kurulu kaynak gerekirse `cx.asset_source()` ile okunur; sıradan UI kodu bunu doğrudan kullanmaz, bunun yerine `Resource::Embedded`, `svg().path(...)` veya `window.use_asset` üzerinden çalışır.

### Image element

```rust
img(PathBuf::from("path/to/icon.png"))
    .w(px(24.))
    .h(px(24.))
    .object_fit(ObjectFit::Contain)
    .with_loading(|| div().bg(rgb(0xeeeeee)).into_any_element())
    .with_fallback(|| div().bg(rgb(0xffeeee)).into_any_element())
```

`img(impl Into<ImageSource>)` çağrısı çeşitli kaynak tiplerini kabul eder; `ImageSource` varyantları:

- **`Resource(Resource)`** — Yukarıdaki enum.
- **`Render(Arc<RenderImage>)`** — Önceden raster edilmiş frame'ler.
- **`Image(Arc<Image>)`** — Encoded bytes (PNG/JPEG/WebP).
- **`Custom(Arc<dyn Fn(&mut Window, &mut App) -> Option<Result<Arc<RenderImage>, ImageCacheError>>>)`** — Tamamen özel yükleme.

URL string otomatik olarak `Uri` parse edilir; URL olmayan `&str` veya `String` ise `Resource::Embedded` sayılır ve `AssetSource` içinden aranır. Dosya sistemi yolu için `Path`, `PathBuf` veya `Arc<Path>` doğrudan geçirilir — bu tip ayrımı kritiktir, aksi halde yanlış kaynaktan arama yapılır.

### SVG

```rust
svg().path("icons/check.svg").size(px(16.)).text_color(rgb(0x000000))
```

SVG yolu `AssetSource`'tan okunur. `text_color`, SVG dosyasındaki `currentColor` referanslarını boyamak için kullanılır; bu sayede aynı icon farklı tema renkleriyle yeniden boyatılabilir. Custom path string yerine `IconName::path()` derive sonucu da geçirilebilir; Zed'de tipik kullanım `Icon::new(IconName::Check)` biçimindedir.

### Cache davranışı

Asset yükleme iki seviyeli cache ile yapılır:

- **`window.use_asset::<A>(source, cx)`** — Aynı source için tek bir async load task'ı paylaşılır; tamamlandığında current view yeniden çizdirilir.
- **`ImageCache`** — Decode edilmiş `RenderImage` byte'larını tutar; ağaç bazında `.image_cache(&entity)` veya `image_cache(retain_all("id"))` ile yerleştirilir.

Hata loglama otomatiktir; `ImgResourceLoader = AssetLogger<...>` decode/load hatalarını yakalar.

### Tuzaklar

- **URL parse başarısızsa string embedded asset sayılır.** Gerçek dosya yolu vermek için `PathBuf` kullanılmazsa yanlış kaynaktan arama yapılır ve "asset not found" hatası alınır.
- **`Custom` closure `'static` olmalıdır.** `Window`/`App` referansları yalnızca closure çağrısının parametresi olarak kullanılır; closure dışına taşınamaz.
- **`with_fallback` yalnızca yükleme tamamlandığında ve **hata oluştuysa** fallback'i render eder.** Hâlâ yükleniyor durumunda fallback gösterilmez.
- **`with_loading` yükleme 200 ms'den uzun sürerse loading fallback'i gösterir.** Bu eşik `gpui::LOADING_DELAY: Duration` const'ında tanımlıdır (`elements/img.rs:31`); kendi delayed-fallback akışında aynı değer ödünç alınabilir.
- **`RenderImage` GIF/animated WebP için `frame_count()` ve `delay(frame_index)` sağlar;** `img` element'i aktif pencerede frame ilerletir ve animation frame ister.

## 11.2. Asset, ImageCache ve Surface Boru Hattı

Asset katmanının üç seviyesi (11.1'de tanımlandı) image yükleme ve cache pipeline'ında birlikte çalışır: `AssetSource` byte'ları sağlar, `Asset` async loader rolünü oynar, `Resource` ise kaynak adresini taşır. Bu bölüm image cache'inin nasıl yerleştirildiğini, `RetainAllImageCache`'in davranışını, custom cache yazımını ve `Surface` adlı ayrı pipeline'ı kapsar.

### Image cache yerleştirme

Cache element ağacına iki yolla bağlanır — bağlamı netleştirmek için tercih edilen şekil ortama göre değişir:

```rust
div()
    .image_cache(retain_all("avatars"))
    .child(img(avatar_uri.clone()).object_fit(ObjectFit::Cover))
```

Alternatif wrapper element:

```rust
image_cache(retain_all("preview-cache"))
    .child(img(preview_path.clone()))
```

### `RetainAllImageCache`

Bu hazır cache "yüklediğin her şeyi sakla" politikasını uygular. Küçük ve sınırlı asset setleri için (avatar listesi, sabit ikon seti) uygundur.

- **`RetainAllImageCache::new(cx)`** — Entity cache oluşturur.
- **`retain_all(id)`** — Element-local cache provider üretir.
- **`load(resource, window, cx)`** — Sonuç hazır değilse `None`, hazırsa `Some(Result<Arc<RenderImage>, ImageCacheError>)` döndürür.
- Cache release edilirken `cx.drop_image(...)` çağrılır; GPU image kaynakları serbest bırakılır.

### Custom cache

Eviction politikası, boyut sınırı veya özel yükleme stratejisi gerekiyorsa `ImageCache` trait'i elle uygulanır:

```rust
impl ImageCache for MyImageCache {
    fn load(
        &mut self,
        resource: &Resource,
        window: &mut Window,
        cx: &mut App,
    ) -> Option<Result<Arc<RenderImage>, ImageCacheError>> {
        self.load_or_poll(resource, window, cx)
    }
}
```

### Surface — platform-native pipeline

`Surface` image cache'inden tamamen ayrı bir yol izler. macOS'ta `CVPixelBuffer` gibi platforma özgü surface kaynaklarını doğrudan çizmek için kullanılır (örn. video frame'i, harici GPU surface'i, AVFoundation çıktısı):

```rust
surface(buffer).object_fit(ObjectFit::Cover)
```

Altta `window.paint_surface(...)` boru hattını kullanır; image asset cache'iyle paylaşmaz. Şu anda platforma bağımlıdır (macOS odaklı).

### Tuzaklar

- **Cache ID'si değişirse decode edilmiş image state'i düşer.** Aynı asset için aynı ID kullanmak yeniden decode maliyetinden kaçınır.
- **`img("literal")` URL değilse embedded resource olarak yorumlanır;** filesystem yolu için `PathBuf` veya `Arc<Path>` verilmesi gerekir (11.1'deki uyarı).
- **`RetainAllImageCache` sınırsız büyüyebilir.** Çok büyük veya sürekli değişen image setlerinde (örn. infinite scroll'da görsel listesi) eviction stratejisi olan custom `ImageCache` yazılır.

## 11.3. Path Çizimi ve Custom Drawing

Kaynak: `crates/gpui/src/path_builder.rs`, `scene.rs`, `elements/canvas.rs`.

GPUI sıradan element ağacının vermediği özgür çizim için `canvas` elementi ve `PathBuilder` API'sini sağlar. `canvas` iki closure alır (prepaint ve paint); `PathBuilder` ise lyon tessellator'ı kullanarak vektör path'leri GPU üçgenlerine çevirir. Bu pipeline custom resize handle, custom progress bar, ikon türetme, dekoratif çizim gibi durumlar içindir.

```rust
canvas(
    |bounds, window, _cx| {
        // prepaint: hitbox, layout-zamanlı state
        window.insert_hitbox(bounds, HitboxBehavior::Normal)
    },
    |bounds, _hitbox, window, _cx| {
        // paint: window.paint_path(...) çağrıları
        let mut path = PathBuilder::fill();
        path.move_to(bounds.origin);
        path.line_to(bounds.bottom_left());
        path.line_to(bounds.bottom_right());
        path.close();
        if let Ok(built) = path.build() {
            window.paint_path(built, rgb(0x4f46e5));
        }
    },
)
.size_full()
```

`PathBuilder`:

- `PathBuilder::fill()` ya da `PathBuilder::stroke(width)` ile başlat.
- `move_to(point)`, `line_to(point)`, `curve_to(to, ctrl)`,
  `cubic_bezier_to(to, control_a, control_b)`, `arc_to(radii, x_rotation,
  large_arc, sweep, to)`, `relative_arc_to(...)`, `add_polygon(...)`, `close()`.
- `dash_array(&[Pixels])` yalnızca stroke path'lerde anlamlıdır; odd sayıda değer
  verilirse SVG/CSS davranışı gibi liste iki kez tekrarlanır.
- `transform(...)`, `translate(point)`, `scale(f32)`, `rotate(degrees)` path'i
  build öncesi dönüştürür.
- `build()` → tessellated `Path<Pixels>` döner; `?` ile hata yay.

Tessellator parametreleri (`PathStyle`, `FillOptions`, `StrokeOptions`,
`FillRule`):

GPUI bu tipleri lyon'dan re-export eder
(`pub use lyon::tessellation::{FillOptions, FillRule, StrokeOptions}`,
`path_builder.rs:11-12`). `PathBuilder.style: PathStyle` alanı public'tir; iki
varyantı vardır:

```rust
pub enum PathStyle {
    Stroke(StrokeOptions),
    Fill(FillOptions),
}
```

Default constructor'lar default lyon parametrelerini set eder
(`PathBuilder::fill()` → `FillOptions::default()`; `PathBuilder::stroke(width)`
→ `StrokeOptions::default().with_line_width(width.0)`). Bu seçenekleri
özelleştirmek istersen `path.style` alanını doğrudan değiştir veya path inşa
ettikten sonra yeni `PathStyle` ata:

- `FillOptions`: `tolerance` (flattening hassasiyeti, default 0.1), `fill_rule`
  (`FillRule::{EvenOdd, NonZero}`, SVG `fill-rule` semantiği; default
  **`EvenOdd`** — `lyon_tessellation::FillOptions::DEFAULT_FILL_RULE`),
  `sweep_orientation` (default `Orientation::Vertical`),
  `handle_intersections` (default `true`). Hızlı yardımcılar:
  `FillOptions::even_odd()`, `FillOptions::non_zero()`,
  `FillOptions::tolerance(t)`.
- `StrokeOptions`: `line_width` (default 1.0), `start_cap` ve `end_cap` (her
  sub-path için başlangıç/bitiş cap'i, default `LineCap::Butt`), `line_join`
  (default `LineJoin::Miter`), `miter_limit` (default 4.0), `tolerance`
  (default 0.1). Tüm bu sabitler
  `lyon_tessellation::StrokeOptions::{DEFAULT_LINE_CAP, DEFAULT_LINE_JOIN,
  DEFAULT_MITER_LIMIT, DEFAULT_LINE_WIDTH, DEFAULT_TOLERANCE}` const'larında
  görünür.
- `FillRule::EvenOdd` (lyon ve gpui default'u): SVG even-odd kuralı; iç içe
  path'lerde delik üretir. İki üst üste binen kapalı path'in çakışan bölgesi
  şeffaf olur.
  `FillRule::NonZero`: SVG non-zero winding kuralı; yön kombinasyonuna göre
  kapsama hesaplar, çakışan path'ler genelde dolu kalır. Karmaşık kompozit
  shape'ler için kasıtlı olarak `non_zero()` seçilir.

Lyon API'sine inmek istersen `lyon::tessellation::FillOptions::tolerance(0.5)`
gibi builder zincirleri kullanılabilir; gpui bu builder'ları olduğu gibi
yeniden export ettiği için ek wrapper'a ihtiyacın yoktur.

Window paint API'leri:

- `window.paint_path(path, color)`
- `window.paint_quad(quad)`: `fill(bounds, ...).border(...)` shorthand.
- `window.paint_strikethrough(...)`, `paint_underline(...)`
- `window.paint_image(...)`: raster image draw.
- `window.paint_layer(bounds, |window| ...)`: aynı draw order'da toplanan geometri
  için yeni layer açar; genellikle performans ve overdraw kontrolü için kullanılır.

Tuzaklar:

- Tessellation pahalıdır; her frame yeni path inşa etmek FPS'i düşürür. Mümkünse
  prepaint'te build edip paint'te yalnızca çiz.
- Path bounds dışına taşan kısım clip'lenmez; `paint_layer` ile manuel clipping yap.
- Stroke genişliği logical Pixels'dir; DPI yüksek ekranda çok ince kalmasın diye
  `px(1.0).max(...)` ile zemin tut.

## 11.4. Anchored ve Popover Konumlandırma

Kaynak: `crates/gpui/src/elements/anchored.rs`.

`anchored()` elementi, child'ın belirli bir noktaya sabitlenmesini sağlar; layout akışında parent bounds'unu yok sayar ve absolute positioning gibi davranır. Tooltip, popover, context menu, dropdown gibi UI parçalarının altında bu element çalışır. Konumlandırmanın temel mantığı: child'ın **anchor noktası** (örn. üst-sol köşesi) verilen **position**'a hizalanır; pencere kenarına yetişirse `snap`/`flip` davranışları devreye girer.

### Tipik kullanım

```rust
anchored()
    .anchor(Anchor::TopLeft)
    .position(point(px(120.), px(80.)))
    .offset(point(px(0.), px(4.)))
    .snap_to_window_with_margin(Edges::all(px(8.)))
    .child(menu_view.into_any_element())
```

### API

- **`anchor(Anchor)`** — Child'ın hangi referans noktasının `position`'a hizalanacağını belirler. `Anchor` varyantları: `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`, `TopCenter`, `BottomCenter`, `LeftCenter`, `RightCenter`. Örnek: dropdown bir butonun **altında** açılacaksa `Anchor::TopLeft` + position butonun alt-sol köşesi olarak verilir.
- **`position(point)`** — Anchor noktasının ekrandaki konumu (window veya local koordinatlarda).
- **`offset(point)`** — Hizalama sonrası ek kayma (örn. küçük spacing).
- **`position_mode(AnchoredPositionMode::Window | Local)`** — Koordinat referansı: `Window` pencere içi mutlak konum, `Local` parent content origin'e göreli.
- **`snap_to_window()` ve `snap_to_window_with_margin(Edges)`** — Pencere dışına taşıyorsa aynı anchor'ı koruyarak pencere içine kaydırır.

### `AnchoredFitMode`

Pencerede yer kalmadığında child'ın nasıl davranacağı:

- **`SwitchAnchor` (default)** — Yetersiz alanda anchor'ı tersine çevirir (örn. altta yer yoksa üste açılır).
- **`SnapToWindow`** — Aynı köşede kalır, pencere kenarına oturur.
- **`SnapToWindowWithMargin(Edges)`** — Marjin bırakarak pencere kenarına oturur.

### Tuzaklar

- **Position `Local` modda parent'ın content origin'ine görelidir;** `Window` modda **pencere içi** koordinatlardır (ekran mutlak değil).
- **Snap fonksiyonları arasında en son çağrılan kazanır.** `snap_to_window()` ve `snap_to_window_with_margin()` aynı element üzerinde sıralı çağrılırsa son set olan etkili olur.
- **Anchored child kendi içinde overflow `Visible` davranır;** içerik penceredeki alanı taşırsa scroll otomatik gelmez, ekstra wrapper (`div().overflow_y_scroll()`) eklenmelidir.

## 11.5. PaintQuad, Window Paint Primitives ve BorderStyle

Element ağacı seviyesinden bir kademe altta, `canvas` veya custom `Element::paint` içinde doğrudan GPU'ya primitive'ler gönderilir. Bu primitive'ler arka plan dolgusu, çerçeveli kutu, gölge, image, SVG, glyph gibi her temel çizim parçasının altyapısıdır. Aşağıda paint fazında çağrılabilen başlıca primitive'ler ve `PaintQuad` builder'ı ele alınır.

```rust
window.paint_quad(fill(bounds, rgb(0xeeeeee)));

window.paint_quad(
    quad(
        bounds,
        Corners::all(px(8.)),                  // corner_radii
        rgb(0xffffff),                         // background
        Edges::all(px(1.)),                    // border_widths
        rgb(0xdddddd),                         // border_color
        BorderStyle::Solid,                    // veya Dashed
    ),
);

window.paint_quad(outline(bounds, rgb(0xff0000), BorderStyle::Solid));
```

`PaintQuad` builder yardımcıları (`window.rs:5848+`):

- `.corner_radii(impl Into<Corners<Pixels>>)`
- `.border_widths(impl Into<Edges<Pixels>>)`
- `.border_color(impl Into<Hsla>)`
- `.background(impl Into<Background>)`

Diğer paint API'leri:

- `window.paint_path(Path<Pixels>, impl Into<Background>)`: tessellated path.
- `window.paint_underline(Point, width, &UnderlineStyle)`: text underline.
- `window.paint_strikethrough(Point, width, &StrikethroughStyle)`.
- `window.paint_glyph(...)`: tek glyph rasterize ve çizim. Genellikle TextLayout
  zaten kullanır; nadiren elle çağrılır.
- `window.paint_emoji(...)`: emoji renk glyph.
- `window.paint_image(bounds, corner_radii, RenderImage, ...)`: raster image.
- `window.paint_svg(bounds, path, data, transformation, color, cx)`: monochrome
  SVG mask'i, `SvgRenderer` atlas cache'i üzerinden.
- `window.paint_surface(bounds, CVPixelBuffer)`: macOS-only native surface.
- `window.paint_shadows(bounds, corner_radii, &[BoxShadow])`: drop shadow set.
- `window.paint_layer(bounds, |window| ...)`: aynı bounds üzerinde clip ile yeni
  render katmanı; overflow gizleme ve transform için.

`BorderStyle` (`crates/gpui/src/scene.rs:544`): `Solid` ve `Dashed`.
`Corners<P>`, `Edges<P>`, `Bounds<P>`, `Hsla`, `Background` zaten bilinen
geometri/renk tipleridir; her builder bunlara `Into` üzerinden kabul eder.

Tuzaklar:

- `paint_*` çağrıları yalnızca `Element::paint` fazında geçerlidir; prepaint veya
  layout'ta panic verir.
- `paint_path` her frame yeniden tessellate edersen FPS düşer; mümkünse path
  prepaint'te oluştur ve element state'inde sakla.
- `paint_layer` clip'lediği için içerik bounds dışına taşan kısımlar gizlenir;
  shadow gibi taşan efektler için layer dışında çiz.
- `border_widths` dört kenara ayrı değer verebilir (`Edges { top, right, bottom, left }`);
  düz bir değer verirsen `Edges::all(px(1.))`.

## 11.6. Window Drawing Context Stack, Asset Fetch ve SVG Transform

Custom element yazarken `Window` sadece paint primitive çağırılan yer değildir; draw fazları boyunca **aktif style, offset, clipping ve asset yükleme bağlamını** taşır. Bu bağlamlar bir stack üzerinden push/pop edilir; örneğin bir `with_text_style(...)` çağrısı, kapsadığı closure boyunca text style stack'ine bir refinement ekler, çıkışta kaldırır. Bu yaklaşım nested context'leri (örn. inner panel kendi rem size'ını ayarlayabilir) doğal olarak destekler.

### Context stack yardımcıları

- `window.with_text_style(Some(TextStyleRefinement), |window| ...)`: aktif text
  style stack'ine refinement ekler. İçeride `window.text_style()` birleşmiş
  sonucu verir.
- `window.with_rem_size(Some(px(...)), |window| ...)`: rem override stack'i;
  `window.rem_size()` içeride override değerini döndürür.
- `window.set_rem_size(px(...))`: pencerenin base rem değerini kalıcı değiştirir.
- `window.with_content_mask(Some(ContentMask { bounds }), |window| ...)`:
  mevcut mask ile intersection alır; paint/prepaint içindeki `content_mask()`
  bu aktif clip'i verir.
- `window.with_image_cache(Some(cache), |window| ...)`: child ağacı için aktif
  image cache stack'ini değiştirir. `ImageCacheElement` ve `Div` background
  image path'leri bunu kullanır; normal component kodu çoğunlukla
  `image_cache(retain_all(...))` fluent API'sini kullanır.
- `window.with_element_offset(offset, |window| ...)` ve
  `with_absolute_element_offset(offset, |window| ...)`: prepaint sırasında child
  offset'ini değiştirir. Scroll/list implementasyonlarının hitbox ve layout
  koordinatlarını doğru üretmesi buna dayanır.
- `window.element_offset()`: prepaint sırasında aktif offset'i okur.
- `window.transact(|window| -> Result<_, _> { ... })`: prepaint yan etkilerini
  deneme amaçlı yapar; closure `Err` dönerse hitbox/tooltip/dispatch/layout
  kayıtları eski index'e truncate edilir.

Frame/paint yardımcıları:

- `window.set_window_cursor_style(style)`: hitbox'a bağlı olmayan, tüm pencere
  için cursor request'i; paint fazında çağrılır ve hitbox cursor'larından önceliklidir.
- `window.set_tooltip(AnyTooltip) -> TooltipId`: tooltip request'i prepaint
  fazında kaydedilir.
- `window.paint_svg(...)`: `SvgRenderer` ve sprite atlas üzerinden monochrome SVG
  mask'i çizer. SVG'yi her zaman hedef boyutun
  `gpui::SMOOTH_SVG_SCALE_FACTOR: f32 = 2.0` (`svg_renderer.rs:81`) katı
  çözünürlükte rasterize edip tekrar küçültür; bu yüzden `paint_svg` çağrısı
  küçük icon boyutlarında bile yumuşak kenar üretir. `paint_image` decode
  edilmiş raster frame, `paint_surface` ise macOS native surface içindir.

Generic asset yükleme:

```rust
if let Some(result) = window.use_asset::<MyAsset>(&source, cx) {
    render_loaded(result, window, cx);
}
```

- `window.use_asset::<A>(&source, cx) -> Option<A::Output>`: load bitmediyse
  `None` döner ve ilk load tamamlanınca current view'i next frame'de notify eder.
- `window.get_asset::<A>(&source, cx) -> Option<A::Output>`: cache'i poll eder,
  ama tamamlandığında view redraw planlamaz.
- `cx.fetch_asset::<A>(&source) -> (Shared<Task<A::Output>>, bool)`: daha düşük
  seviye ortak task cache'i; aynı asset type/source için tek `Asset::load`
  future'ı paylaşılır.
- `AssetLogger<T>` `Asset<Output = Result<R, E>>` yükleyicisini sarar ve error
  sonucunu loglar.

SVG transform:

```rust
svg()
    .path("icons/check.svg")
    .with_transformation(
        Transformation::rotate(radians(0.2))
            .with_scaling(size(1.2, 1.2))
            .with_translation(point(px(2.), px(0.))),
    )
```

- `svg().path(...)`: embedded `AssetSource` içinden SVG okur.
- `svg().external_path(...)`: filesystem path'i okur.
- `Transformation::{scale, translate, rotate}` ve
  `with_scaling/with_translation/with_rotation` sadece çizimi etkiler; hitbox ve
  layout boyutu değişmez.
- Lower-level `TransformationMatrix::{unit, translate, rotate, scale}` scene
  primitive'lerinde kullanılır.
- `SvgSize` `SvgRenderer` render isteğinin raster boyutunu tanımlar:
  `Size(Size<DevicePixels>)` mutlak boyut, `ScaleFactor(f32)` SVG'nin
  bildirdiği boyuta çarpan uygular.

Tuzaklar:

- `with_content_mask` sadece clip mask'idir; hitbox veya layout'u otomatik
  küçültmez.
- `use_asset` redraw'ı current view entity'sine bağlar; view dışı helper'da
  çağırıyorsan current view beklentisini bozma.
- SVG transformation görsel olarak döndürür/ölçekler, fakat pointer hitbox'ı
  eski layout rect'inde kalır.


---

