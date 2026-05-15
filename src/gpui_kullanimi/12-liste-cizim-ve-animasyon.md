# Bölüm XII — Liste, Çizim ve Animasyon

---

## ScrollHandle ve Scroll Davranışı


`crates/gpui/src/elements/div.rs:3387+`.

`ScrollHandle`, scroll offset'ini paylaşılabilir bir handle olarak temsil eder.
`Rc<RefCell<ScrollHandleState>>` üzerinden çalışır, view'lar arasında klonlanabilir.

Public API:

- `ScrollHandle::new()`
- `offset() -> Point<Pixels>`: anlık scroll konumu.
- `max_offset() -> Point<Pixels>`
- `top_item()`, `bottom_item()`: görünür ilk/son child item dizini.
- `bounds()`: scroll container bounds.
- `bounds_for_item(ix)`: child bounds.
- `scroll_to_item(ix)`, `scroll_to_top_of_item(ix)`: prepaint zamanında istenen
  item'a scroll eder.
- `scroll_to_bottom()`
- `set_offset(point)`: offset'i doğrudan ayarlar. Offset içerik origin'inin
  parent origin'ine uzaklığıdır; aşağı kaydıkça Y genelde negatife gider.
- `logical_scroll_top()`, `logical_scroll_bottom()`: görünür child index'i ve
  child içi pixel offset'i döndürür.
- `children_count()`: scroll edilen child sayısı.

Element üzerine bağlama:

```rust
let handle = ScrollHandle::new();

div()
    .id("list")
    .overflow_y_scroll()
    .track_scroll(&handle)
    .child(/* ... */)
```

`overflow_scroll`, `overflow_x_scroll`, `overflow_y_scroll` `StatefulInteractiveElement`
metotlarıdır; pratikte önce `.id(...)` çağırıp `Stateful<Div>` üretmen gerekir.
Overflow `Scroll` olduğunda input wheel/touch event'i bu container içinde tüketilir.
`track_scroll` aynı handle'ı render geçişleri arasında bağlar; aynı handle başka
yerden okunabilir ve değiştirilebilir.

`ScrollAnchor` (`div.rs:3332+`) bir handle ile çalışan helper'dır; immediate child
olmasa bile belirli bir element'in görünür kalmasını ister:

```rust
let anchor = ScrollAnchor::for_handle(handle.clone());
anchor.scroll_to(window, cx);
```

Tuzaklar:

- `id(...)` çağırmadan `overflow_*_scroll` çalışmaz; element interaktif değildir.
- `track_scroll` çağırılmadan handle değerleri eski kalır; offset güncel olmaz.
- Klavye ile scroll dispatch için `.on_key_down(...)` veya action ile
  `scroll_to_item` çağrılır; otomatik klavye scroll yoktur.

Liste elementlerinde ayrı state/handle tipleri vardır:

- `ListState`: `scroll_by`, `scroll_to`, `scroll_to_reveal_item`, `scroll_to_end`,
  `set_follow_mode(FollowMode::Tail)`, `logical_scroll_top`,
  `is_scrolled_to_end`, `is_following_tail`.
- `UniformListScrollHandle`: `scroll_to_item(..., ScrollStrategy)`,
  `scroll_to_item_strict`, `scroll_to_item_with_offset`,
  `scroll_to_item_strict_with_offset`, `logical_scroll_top_index`,
  `is_scrolled_to_end`, `scroll_to_bottom`.

Büyük listelerde doğrudan `ScrollHandle` yerine bu listeye özel
`ListState`/`UniformListScrollHandle` API'lerini kullanmak doğru sonuç verir.

## List ve UniformList Sanallaştırma


GPUI'de büyük listeler için iki çekirdek element vardır:

- `list(state, render_item)`: item yükseklikleri farklı olabilir. Ölçüm cache'i
  `ListState` içindedir.
- `uniform_list(id, item_count, render_range)`: tüm item'lar aynı yükseklikteyse
  daha hızlıdır; ilk/örnek item ölçülür ve görünür range çizilir.

Değişken yükseklikli liste:

```rust
struct LogView {
    rows: Vec<Row>,
    list_state: ListState,
}

impl LogView {
    fn new() -> Self {
        Self {
            rows: Vec::new(),
            list_state: ListState::new(0, ListAlignment::Top, px(300.)),
        }
    }

    fn replace_rows(&mut self, rows: Vec<Row>, cx: &mut Context<Self>) {
        self.rows = rows;
        self.list_state.reset(self.rows.len());
        cx.notify();
    }
}
```

Render:

```rust
list(self.list_state.clone(), |ix, window, cx| {
    render_row(ix, window, cx).into_any_element()
})
.with_sizing_behavior(ListSizingBehavior::Auto)
```

`ListState` yönetimi:

- `new(item_count, alignment, overdraw)`: builder.
- `measure_all()` (consuming): `ListMeasuringBehavior::Measure(false)` set ederek
  scrollbar boyutunun yalnızca render edilmiş elementlere değil, **tüm liste**
  ölçümüne dayanmasını sağlar.
- `item_count() -> usize`: o anki item sayısı.
- `reset(count)`: tüm item seti değişti.
- `splice(old_range, count)`: aralık değişti; scroll offset'i korunur.
- `splice_focusable(old_range, focus_handles)`: focusable item'ları sanallaştırırken
  focus handle dizisi geçilir; aksi halde görünür olmayan focused item render
  dışı kalabilir.
- `remeasure()`: font/theme gibi tüm yükseklikleri etkileyen değişim.
- `remeasure_items(range)`: streaming text veya lazy content gibi belirli item'lar.
- `set_follow_mode(FollowMode::Tail)`: chat/log gibi tail-follow davranışı.
- `is_following_tail() -> bool`: aktif takip durumu.
- `is_scrolled_to_end() -> Option<bool>`: en alta scroll mu? `None` henüz layout
  yapılmamışsa.
- `scroll_by(distance)`, `scroll_to_end()`, `scroll_to(ListOffset)`,
  `scroll_to_reveal_item(ix)`.
- `logical_scroll_top() -> ListOffset`: aktif scroll konumu.
- `bounds_for_item(ix) -> Option<Bounds<Pixels>>`: render edilmişse item rect'i.
- `set_scroll_handler(...)`: görünür range ve follow state takibi.

Custom scrollbar API'si (kendi scrollbar widget'ını yazıyorsan; `ui::Scrollbars`
zaten bu metotlar üzerinde kuruludur):

- `viewport_bounds() -> Bounds<Pixels>`: en son layout edilmiş viewport rect'i.
- `scroll_px_offset_for_scrollbar() -> Point<Pixels>`: scrollbar için adapte
  edilmiş güncel scroll konumu.
- `max_offset_for_scrollbar() -> Point<Pixels>`: ölçülmüş item'lara göre maksimum
  scroll. Drag sırasında bu değer sabit kalır ki scrollbar sıçramasın.
- `set_offset_from_scrollbar(point)`: scrollbar drag/click'inden gelen offset'i
  uygular.
- `scrollbar_drag_started()` / `scrollbar_drag_ended()`: drag sırasında overdraw
  ölçümünden kaynaklı yükseklik dalgalanmasını dondurmak/serbest bırakmak için.
  Drag'a girerken started, bırakırken ended çağırmazsan scrollbar drag boyunca
  beklenmedik şekilde sürünebilir.
- `is_scrollbar_dragging() -> bool`: `scrollbar_drag_started` ile
  `scrollbar_drag_ended` arasındaki manuel drag durumunu okur. Wheel/trackpad
  scroll'u ile scrollbar thumb drag'ini ayırmak ve drag sırasında otomatik
  tail-follow davranışını bastırmak için kullanılır.
- `set_offset_from_scrollbar(point)` tarafında scroll offset'inin
  Y bileşeni içerik yukarı kaydıkça negatiftir; custom scrollbar yazarken
  pozitif "başlangıçtan uzaklık" yerine `point(px(0.), -distance)` üret. Drag
  sırasında içerik büyürse başlangıçtaki content height dondurulur; thumb frozen
  bottom'a sürüklenirse `FollowMode::Tail` tekrar `is_following = true` olur.

Uniform liste:

```rust
let scroll_handle = self.scroll_handle.clone();

uniform_list("search-results", self.items.len(), move |range, window, cx| {
    range
        .map(|ix| render_result(ix, window, cx))
        .collect()
})
.track_scroll(&scroll_handle)
.with_width_from_item(Some(0))
```

`UniformListScrollHandle`:

- `scroll_to_item(ix, ScrollStrategy::Nearest)`
- `scroll_to_item_strict(ix, ScrollStrategy::Center)`
- `scroll_to_item_with_offset(ix, strategy, offset)`
- `scroll_to_bottom()`
- `is_scrollable()`, `is_scrolled_to_end()`
- `y_flipped(true)`: item 0 altta olacak şekilde ters akış.

Karar:

- Item yükseklikleri gerçekten aynıysa `uniform_list`.
- Yükseklik değişebiliyorsa `list` ve doğru `splice`/`remeasure` çağrıları.
- Focusable item'lar sanallaştırılıyorsa `splice_focusable` ile focus handle ver;
  aksi halde görünür olmayan focused item render dışı kalabilir.


---

## Asset, Image ve SVG Yükleme


`crates/gpui/src/asset_cache.rs`, `assets.rs`, `elements/img.rs`, `svg.rs`.

`Asset` trait async loader sözleşmesidir:

```rust
trait Asset {
    type Source: ...;
    type Output: ...;
    fn load(source: Self::Source, cx: &mut App) -> impl Future<Output = Self::Output>;
}
```

Kaynak gösterimi:

- `Resource::Path(Arc<Path>)`
- `Resource::Uri(SharedUri)` — `http://`, `https://`, `file://` vb.
- `Resource::Embedded(SharedString)` — `AssetSource` üzerinden gömülü asset.

`AssetSource` trait `App::with_assets` ile kurulan global asset providerdır.
`crates/assets` Zed binary'sinde `RustEmbed` ile SVG/icons dahil eder.
Kurulu kaynak gerektiğinde `cx.asset_source()` ile okunabilir; çoğu UI kodu bunu
doğrudan değil `Resource::Embedded`, `svg().path(...)` veya `window.use_asset`
üzerinden kullanır.

Image element:

```rust
img(PathBuf::from("path/to/icon.png"))
    .w(px(24.))
    .h(px(24.))
    .object_fit(ObjectFit::Contain)
    .with_loading(|| div().bg(rgb(0xeeeeee)).into_any_element())
    .with_fallback(|| div().bg(rgb(0xffeeee)).into_any_element())
```

`img(impl Into<ImageSource>)` kabul eder. `ImageSource`:

- `Resource(Resource)`
- `Render(Arc<RenderImage>)` — önceden raster edilmiş frame'ler.
- `Image(Arc<Image>)` — encoded bytes (PNG/JPEG/WebP).
- `Custom(Arc<dyn Fn(&mut Window, &mut App) -> Option<Result<Arc<RenderImage>, ImageCacheError>>>)`

URL string otomatik `Uri` olarak parse edilir; URL olmayan `&str`/`String`
`Resource::Embedded` olur ve `AssetSource` içinden aranır. Dosya sistemi path'i
için `Path`, `PathBuf` veya `Arc<Path>` geçir.

SVG:

```rust
svg().path("icons/check.svg").size(px(16.)).text_color(rgb(0x000000))
```

SVG path `AssetSource`'tan okunur. `text_color` SVG'deki `currentColor` referanslarını
boyamak için kullanılır. Custom path string yerine derive edilen `IconName::path()`
de geçirilebilir (Zed'de `Icon::new(IconName::Check)` doğrudan kullanılır).

Cache davranışı iki katmanlıdır: `window.use_asset::<A>(source, cx)` aynı source
için tek async load task'ını paylaşır ve tamamlanınca current view'i yeniden
çizdirir; `ImageCache` ise decode edilmiş `RenderImage`'ı tutar. Element bazında
`.image_cache(&entity)` veya ağacın üstünde `image_cache(retain_all("id"))`
kullanılabilir. Hata loglama `ImgResourceLoader = AssetLogger<...>` ile otomatiktir.

Tuzaklar:

- URL parse başarısızsa string embedded asset sayılır; gerçek dosya yolu için
  `PathBuf` kullanmadıysan yanlış kaynaktan arama yapılır.
- Custom closure `'static` olmalı; `Window`/`App` sadece closure çağrısında
  parametre olarak kullanılmalı.
- `with_fallback` yalnızca yükleme tamamlandığında ve hatalıysa fallback render eder.
- `with_loading` yükleme 200 ms'den uzun sürerse loading fallback'ini render
  eder. Bu eşik `gpui::LOADING_DELAY: Duration` const'ında tanımlıdır
  (`elements/img.rs:31`); kendi delayed-fallback akışın için aynı değeri
  ödünç alabilirsin.
- `RenderImage` GIF/animated WebP için `frame_count()` ve `delay(frame_index)`
  sağlar; `img` element'i aktif pencerede frame ilerletip animation frame ister.
- Path classifier veya settings güvenlik kontrolü yazarken macOS/Windows'un
  varsayılan case-insensitive dosya sistemlerini unutma.
  `util::paths::component_matches_ignore_ascii_case(component, ".zed")` gibi
  ASCII-insensitive helper kullan; `.ZED/settings.json` gibi varyantları düz
  `== ".zed"` karşılaştırmasıyla kaçırma.

## Asset, ImageCache ve Surface Boru Hattı


GPUI asset katmanı üç seviyelidir:

- `AssetSource`: embedded/static asset byte'larını sağlar.
- `Asset`: async loader trait'i; `Source -> Output`.
- `Resource`: image/svg kaynak adresi: `Uri(SharedUri)`, `Path(Arc<Path>)`,
  `Embedded(SharedString)`.

Image cache elementleri:

```rust
div()
    .image_cache(retain_all("avatars"))
    .child(img(avatar_uri.clone()).object_fit(ObjectFit::Cover))
```

Alternatif wrapper:

```rust
image_cache(retain_all("preview-cache"))
    .child(img(preview_path.clone()))
```

`RetainAllImageCache`:

- `RetainAllImageCache::new(cx)` entity cache oluşturur.
- `retain_all(id)` element-local cache provider oluşturur.
- `load(resource, window, cx)` sonuç hazır değilse `None`, hazırsa
  `Some(Result<Arc<RenderImage>, ImageCacheError>)` döndürür.
- Release sırasında `cx.drop_image(...)` ile GPU image kaynaklarını bırakır.

Custom cache gerektiğinde `ImageCache` trait'i uygulanır:

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

`Surface` ayrı bir yol izler: macOS'ta `CVPixelBuffer` gibi platform surface
kaynaklarını `surface(buffer).object_fit(...)` ile çizmek içindir. Genel image
asset cache'i yerine `window.paint_surface(...)` boru hattını kullanır ve şu anda
platforma bağlıdır.

Tuzaklar:

- Cache ID'si değişirse decode edilmiş image state'i düşer.
- `img("literal")` URL değilse embedded resource olarak yorumlanır; filesystem
  için `PathBuf`/`Arc<Path>` ver.
- Çok büyük veya sürekli değişen image setlerinde `RetainAllImageCache` sınırsız
  büyüyebilir; özel eviction stratejisi için kendi `ImageCache` implementasyonu yaz.

## Path Çizimi ve Custom Drawing


`crates/gpui/src/path_builder.rs`, `scene.rs`, `elements/canvas.rs`.

GPUI doğrudan path API yerine `canvas` elementi ve `PathBuilder` ile vektör çizim
sağlar. `PathBuilder` lyon tessellator wrapper'ıdır.

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

## Anchored ve Popover Konumlandırma


`crates/gpui/src/elements/anchored.rs`.

`anchored()` fonksiyonu bir `Anchored` builder döndürür:

```rust
anchored()
    .anchor(Anchor::TopLeft)
    .position(point(px(120.), px(80.)))
    .offset(point(px(0.), px(4.)))
    .snap_to_window_with_margin(Edges::all(px(8.)))
    .child(menu_view.into_any_element())
```

API:

- `anchor(Anchor)`: child'ın hangi referans noktasının `position`'a
  hizalanacağı. `Anchor` varyantları `TopLeft`, `TopRight`, `BottomLeft`,
  `BottomRight`, `TopCenter`, `BottomCenter`, `LeftCenter`, `RightCenter`.
- `position(point)`: anchor noktası (window veya local koordinatlarda).
- `offset(point)`: hizalama sonrası ek kayma.
- `position_mode(AnchoredPositionMode::Window)` veya
  `position_mode(AnchoredPositionMode::Local)`: koordinat referansı.
- `snap_to_window()` ve `snap_to_window_with_margin(Edges)`: pencere dışına taşıyorsa
  aynı anchor'ı koruyarak pencere içine kaydırır.

`AnchoredFitMode`:

- `SwitchAnchor` (default): yetersiz alanda tersine flip.
- `SnapToWindow`: aynı köşede kalır, pencere kenarına oturur.
- `SnapToWindowWithMargin(Edges)`: marjin bırakarak oturur.

Anchored element ağaca normal çocuk gibi eklenir, fakat layout fazında parent
bounds'unu yok sayar; absolute positioning gibi davranır. Tooltip, popover ve
ContextMenu altta bu element ile çalışır.

Tuzaklar:

- Position `Local` modda parent'ın content origin'ine görelidir; window modda
  ekranda mutlak değil, **pencere içi** koordinatlardır.
- Snap fonksiyonları arasında en son çağrılan kazanır.
- Anchored child kendi içinde overflow `Visible` davranır; içerik pencereyi taşırsa
  scroll için ekstra wrapper gerekir.

## PaintQuad, Window Paint Primitives ve BorderStyle


`canvas` ve custom `Element::paint` içinde GPU'ya gönderilen primitive'ler:

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

## Window Drawing Context Stack, Asset Fetch ve SVG Transform


Custom element yazarken `Window` yalnızca paint primitive çağırdığın yer değildir;
draw fazlarında aktif style, offset, clipping ve asset yükleme context'ini de
taşır.

Context stack yardımcıları:

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

## Animasyon Sistemi


Animasyon API `crates/gpui/src/elements/animation.rs` içindedir.

`Animation` üç alandan oluşur: `duration: Duration`, `oneshot: bool` (false ise
tekrar eder), `easing: Rc<dyn Fn(f32) -> f32>`. Inşa: `Animation::new(duration)`
linear easing ile tek seferlik animasyon oluşturur. `.repeat()` döngüye alır,
`.with_easing(fn)` easing değiştirir.

`AnimationExt` trait, herhangi bir `IntoElement` için iki metot ekler:

```rust
use gpui::{Animation, AnimationExt};
use std::time::Duration;

div()
    .size(px(100.))
    .with_animation(
        "grow",
        Animation::new(Duration::from_millis(500))
            .with_easing(gpui::ease_in_out),
        |el, delta| el.size(px(100. + 100. * delta)),
    )
```

Çoklu animasyon zinciri için `with_animations(id, vec![anim_a, anim_b],
|el, ix, delta| ...)`. Closure'a (element, animation_index, delta_in_animation)
parametreleri verilir; `ix` aktif animasyonun vec içindeki sırasıdır, `delta`
o animasyona göre 0..1 ilerlemedir. Sıralı/çoklu fazlı geçiş yazarken
`ix` ile `match` yapılır.

Yerleşik easing fonksiyonları (`crates/gpui/src/elements/animation.rs:211+`):
`linear`, `quadratic`, `ease_in_out`, `ease_out_quint()`, `bounce(inner)`,
`pulsating_between(min, max)`. `pulsating_between` yön değiştirerek değer döndürür
(loading indicator için ideal; `Animation::repeat()` ile birleştirilir).

Tuzaklar:

- Element ID render boyunca stabil olmalıdır; değişirse animasyon state sıfırlanır.
- Animator closure `'static` olduğundan dış state'i `Rc`/`Arc`/`clone` ile yakala.
- Repeat animasyonu `window.request_animation_frame()` ile bir sonraki frame'i ister;
  bu da mevcut view'i sonraki frame'de notify eder. Gerekmiyorsa oneshot bırak.
- Frame'ler arası progress değeri executor saatinden hesaplanır; normal
  `TestAppContext`/`VisualTestContext` testlerinde `cx.background_executor.advance_clock(...)`
  veya `TestApp::advance_clock(...)` kullan. macOS'a özel `VisualTestAppContext`
  üzerinde ayrıca doğrudan `advance_clock(...)` helper'ı vardır.

---

---

