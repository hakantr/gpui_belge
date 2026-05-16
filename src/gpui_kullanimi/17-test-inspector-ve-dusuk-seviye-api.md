# Test, Inspector ve Düşük Seviye API

---

## Test Rehberi

GPUI test yazımında izlenen genel disiplinler şunlardır:

- `#[gpui::test]` makrosu ve `TestAppContext` kullanılır.
- Pencere gerektiğinde test context'inin offscreen veya window helper'ları tercih edilir.
- Async timer için `cx.background_executor().timer(duration).await` çağrısı kullanılır.
- UI action testlerinde keybinding ve action dispatch doğrudan test edilir.
- Görsel test gerektiğinde `VisualTestContext` ve headless renderer desteği kontrol edilir.
- Element debug bounds gerektiğinde test-support altında `.debug_selector(...)` eklenir.
- `gpui` `proptest` feature'ı açıkken `Hsla` için `Arbitrary` implementasyonu ve `Hsla::opaque_strategy()` helper'ı bulunur. Renk veya kontrast property testlerinde alfa 1.0 olan rastgele renk üretmek için bu helper kullanılır.

**Testlerde kaçınılan kalıplar.** Aşağıdaki desenler test sonuçlarını güvenilmez yapar:

- `smol::Timer::after(...)` çağrısıyla `run_until_parked()` beklemek.
- `unwrap()` ile test dışı üretim yoluna panik taşımak.
- Async hata sonuçlarını `let _ = ...` ile sessizce yutmak.

## Test Bağlamları ve Simülasyon

`crates/gpui/src/app/test_context.rs`, `crates/gpui/src/app/visual_test_context.rs`.

`#[gpui::test]` makrosu bir `TestAppContext` sağlar. Görsel test için `add_window` bir `WindowHandle<V>` döndürür ve `VisualTestContext` ile sürülür. İsim benzerliğine dikkat: `VisualTestContext` test penceresini kendi içinde tutar; macOS `test-support` altındaki `VisualTestAppContext` ise window handle'ı açık argüman olarak alan ayrı bir bağlamdır.

```rust
#[gpui::test]
fn test_save(cx: &mut TestAppContext) {
    let window = cx.add_window(|window, cx| cx.new(|cx| Editor::new(window, cx)));

    cx.simulate_keystrokes(window, "cmd-s");
    cx.run_until_parked();

    window.read_with(cx, |editor, _| {
        assert!(editor.is_clean);
    });
}
```

**Sık kullanılan API'ler.** Test akışında en çok karşılaşılan yardımcılar:

- `cx.add_window(|window, cx| cx.new(...))` — yeni bir offscreen pencere açar.
- `cx.simulate_keystrokes(window, "cmd-s left")` — boşlukla ayrılmış keystroke dizisi simüle eder.
- `cx.simulate_input(window, "hello")` — text input simulasyonu yapar.
- `cx.dispatch_action(window, action)`.
- `cx.run_until_parked()` — tüm pending future ve task tamamlanana kadar sürer.
- `cx.background_executor.advance_clock(duration)` — deterministik timer ilerletme.
- `cx.background_executor.run_until_parked()` — test executor'ında yalnızca background sürer.
- `window.update(cx, |view, window, cx| ...)` — pencere içi state mutate eder.

`add_window_view` veya `add_empty_window` ile alınan `VisualTestContext` pencere bağlamını taşıdığı için bazı metotları window argümanı almadan çağrılabilir:

- `cx.simulate_keystrokes("cmd-p")` ve `cx.simulate_input("hello")` — `self.window`'u kullanır.
- `cx.dispatch_action(action)` — yine `self.window` üzerinden dispatch eder.
- `cx.run_until_parked()`, `cx.window_title()`, `cx.document_path()` — window-less helper'lardır.

Mouse simülasyon metotları `VisualTestContext` üzerinde de `self.window` ile çalışır ve window argümanı almaz (`test_context.rs:764-809`):

- `cx.simulate_mouse_move(position, button, modifiers)`
- `cx.simulate_mouse_down(position, button, modifiers)`
- `cx.simulate_mouse_up(position, button, modifiers)`
- `cx.simulate_click(position, modifiers)`

Pencere argümanı isteyen helper'lar `TestAppContext` üzerindeki `simulate_keystrokes(window, ...)`, `simulate_input(window, ...)`, `dispatch_action(window, ...)` ve `dispatch_keystroke(window, ...)` ailesidir. `VisualTestContext` bu window handle'ını kendi içinde tuttuğu için aynı klavye ve action helper'larını window-less sarmallar olarak sunar. `VisualTestAppContext` ise `simulate_keystrokes(window, ...)`, `simulate_mouse_move(window, ...)`, `simulate_click(window, ...)` ve `dispatch_action(window, ...)` biçimindeki window argümanlı formu kullanır.

**Pratik kurallar.** Test akışında dikkat edilmesi gerekenler:

- Gerçek tutarlılık için `smol::Timer` yerine `cx.background_executor.timer(d)` tercih edilir.
- `run_until_parked` ile `advance_clock` kombine edilirken önce clock ilerletilir, sonra park beklenir. `VisualTestContext` `TestAppContext`'in içine deref ettiği için normal yolda `cx.background_executor.advance_clock(d)` kullanılır; doğrudan `advance_clock(d)` helper'ı `VisualTestAppContext` üzerinde yer alır.
- Async test için `#[gpui::test]` `async fn(cx: &mut TestAppContext)` formunu destekler; foreground task'ları orada `cx.spawn` ile kurulur.
- Pencerenin gerçekten render edilmesi için `VisualTestContext::draw(...)`, `TestApp::draw()` veya doğrudan `window.draw(cx).clear()` kullanan bir pencere update'i gerekebilir; aksi halde debug bounds veya layout bilgisi üretilmez.

**Tuzaklar.** Test simulasyonunda atlanan noktalar:

- `simulate_keystrokes` action dispatch'i tetikler ancak keymap binding'i kayıtlı olmalıdır; testte `cx.bind_keys([...])` çağırılmadığında beklenen action ulaşmaz.
- `run_until_parked` zamanı ilerletmez; yalnız pending future'ları sürer. Timer beklendiğinde `advance_clock` da yapılmalıdır.
- `dispatch_action` focus tree'de action handler bulamadığında sessizce no-op olur; view'in gerçekten focused olduğundan emin olunmalıdır.

---

## Inspector ve Debug Yardımcıları

`crates/gpui/src/inspector.rs` (feature: `inspector`).

`gpui` crate'i `inspector` feature ile (veya `debug_assertions` açıkken) derlendiğinde dev tool entegrasyonu sağlar:

- `InspectorElementId` — her element için `(file, line, instance)` tabanlı kimlik.
- `InspectorElementPath` (`inspector.rs:30`) — bir elementin `GlobalElementId` zincirini ve construction'dan gelen `&'static Location` source location'ını birleştiren kimlik. Element seçildiğinde inspector UI'ı bu path üzerinden source link gösterir. Hem alanları hem `Clone` impl'i feature gate altındadır.
- Element source location `#[track_caller]` ile yakalanır ve `InspectorElementPath.source_location` alanına yazılır.
- Element seçimi pencerede `Inspector` global state üzerinden tetiklenir.
- `Window::toggle_inspector(cx)` inspector panelini açar veya kapatır.
- `Window::with_inspector_state(...)` aktif elemente özel geçici inspector state'i tutar.
- `App::set_inspector_renderer(InspectorRenderer)` inspector UI'ını bağlar. `InspectorRenderer` (`inspector.rs:55`) şu type alias'tır:

  ```rust
  pub type InspectorRenderer =
      Box<dyn Fn(&mut Inspector, &mut Window, &mut Context<Inspector>) -> AnyElement>;
  ```

  Inspector panelinin içeriği bu closure tarafından üretilir; argümanlar Inspector state, ait olduğu Window ve Inspector için Context'tir.
- `App::register_inspector_element(...)` belirli bir element tipinin inspector panel render'ını kaydeder; element seçildiğinde state için custom UI çizilir.

**Reflection katmanı.** `Styled` metotlarını çalışma zamanında listeleyebilmek için bir reflection mekanizması vardır. `Styled` trait `cfg(any(feature = "inspector", debug_assertions))` altında `#[gpui_macros::derive_inspector_reflection]` ile işaretlenir (`styled.rs:18-21`). Bu macro yan etki olarak iki API üretir:

- **`gpui::styled_reflection`** — proc macro çıktısı modül.
  - `pub fn methods<T: Styled + 'static>() -> Vec<FunctionReflection<T>>` — `Styled` trait'inin tüm reflectable metotlarını belirli bir somut tip için sarar.
  - `pub fn find_method<T: Styled + 'static>(name: &str) -> Option<FunctionReflection<T>>` — aynı listeyi isim eşleşmesine göre filtreler.
- **`gpui::inspector_reflection::FunctionReflection<T>`** (`inspector.rs:233`):

  ```rust
  pub struct FunctionReflection<T> {
      pub name: &'static str,
      pub function: fn(Box<dyn Any>) -> Box<dyn Any>,
      pub documentation: Option<&'static str>,
      pub _type: PhantomData<T>,
  }
  ```

  `documentation` alanı trait metodunun `///` doc yorumundan çıkarılır (`gpui_macros::extract_doc_comment`). Inspector UI bu metni markdown olarak render eder — örneğin `inspector_ui/src/div_inspector.rs:670` Styled metodu autocomplete'inde `CompletionDocumentation::MultiLineMarkdown` formuna sarar. Tailwind doc linki gibi ham bağlantılar da bu yolla hyperlink olur.
- `FunctionReflection::invoke(value: T) -> T` — metodu çalışma zamanında çağırır; inspector "method picker" akışında kullanıcı bir style metodunu seçtiğinde mevcut elementin `StyleRefinement`'ı bu invoke ile dönüştürülür.

Üretim build'inde inspector kodu sıfır maliyetlidir; reflection modülü ve `FunctionReflection` da feature gate'in dışında derlenmediği için release Zed binary'sinde bulunmaz.

**Diğer debug yardımcıları.** Inspector dışında küçük yardımcılar da mevcuttur:

- `div().debug_selector(|| "my-button")` — test ve inspector'da selector atar.
- `crates/gpui/src/profiler.rs` — executor task timing buffer'ları; runtime'da `gpui::profiler::set_enabled(true)` ile açılır ve thread timing delta'ları `ProfilingCollector` ile okunur.
- `RUST_LOG=gpui=debug` ile event/key dispatch log seviyesi yükselir.
- `debug_selector` değerleri testte `VisualTestContext::debug_bounds(selector)` üzerinden okunur; üretim overlay'i için ayrı bir env bayrağı gerekir.

## Default Colors, GPU Specs ve Platform Diagnostics

Tema sistemi dışındaki küçük ama pratik platform yüzeyleri burada toplanır:

- `Colors::for_appearance(window)` — `WindowAppearance::Light` veya `VibrantLight` için light, `Dark` veya `VibrantDark` için dark varsayılan palet döndürür.
- `Colors::light()`, `Colors::dark()`, `Colors::get_global(cx)` — GPUI örneklerinde ve base component'lerde kullanılan framework renkleri. Zed uygulama UI'ında esas kaynak `cx.theme().colors()`'dur.
- `DefaultColors` trait'i `cx.default_colors()` kısayolunu sağlar; bunun için `GlobalColors(Arc<Colors>)` global state olarak set edilmiş olmalıdır.
- `DefaultAppearance::{Light, Dark}` `WindowAppearance` değerinden türetilir ve base GPUI renk setini seçmek için kullanılır.
- `window.gpu_specs() -> Option<GpuSpecs>` — Linux/Vulkan tarafında GPU/driver bilgisini ve software emulation durumunu verir; macOS ve Windows'ta şu anda `None` dönebilir.
- `window.set_window_edited(true)` — platform seviyesinde "dirty document" göstergesi.
- `window.set_document_path(Some(path))` — macOS'ta `AXDocument` accessibility property değerini ayarlar.
- `window.play_system_bell()` — platform alert sesi.
- `window.window_title()`, `titlebar_double_click()`, `tabbed_windows()`, `merge_all_windows()`, `move_tab_to_new_window()`, `toggle_window_tab_overview()`, `set_tabbing_identifier(...)` — macOS'a özgü pencere ve tab entegrasyonlarıdır.
- `window.input_latency_snapshot()` — `input-latency-histogram` feature'ı açıkken input-to-frame ve mid-frame input histogramlarını döndürür.

Bu API'ler tema veya pencere oluşturma akışının merkezinde değildir; ancak diagnostic ekranları, test harness'ları, macOS doküman pencereleri ve platforma duyarlı davranışlarda rehbere dahildir.

## Window Runtime Snapshot, Layout Ölçümü ve Frame Zamanlama

Zed'in `workspace` ve `ui` katmanlarında sık görülen bazı `Window` çağrıları render çıktısı üretmez. O anki pencere veya input durumunu okumak ya da işi doğru frame fazına taşımak için kullanılır.

**Anlık input snapshot'ı.** Modifier, capslock ve mouse durumu pencere üzerinden okunabilir:

- `window.modifiers() -> Modifiers` — o an basılı modifier'ları verir. Zed'de Shift/Alt/Ctrl ile notification suppress, pane clone veya quick action preview davranışı değiştirmek için kullanılır.
- `window.capslock() -> Capslock` — capslock durumunu okur.
- `window.mouse_position() -> Point<Pixels>` — pointer'ın pencere içi konumu. Context menu ve right-click menu konumlandırmasında doğrudan kullanılır.
- `window.last_input_was_keyboard() -> bool` — focus-visible kararlarında ana sinyaldir; pointer ile odaklanan elemente gereksiz focus ring çizmemek için.
- `window.is_window_hovered() -> bool` — tooltip, popover veya hover overlay'i pencere dışına çıktığında kapatmak gibi durumlarda kullanılır.

**Render ve prepaint sırasında current view ile layout.** Layout ölçümlerine ve view kimliğine ulaşmak için aşağıdaki helper'lar sağlanır:

- `window.current_view() -> EntityId` — şu anda render, prepaint veya paint edilen view entity'sidir. `request_animation_frame`, `use_asset` ve hover/indent-guide gibi delayed notify akışları bu id'ye bağlanır. Yalnız draw fazlarında anlamlıdır; uzun süre saklanacak bir domain id gibi ele alınmamalıdır.
- `window.request_layout(style, children, cx) -> LayoutId` — özel element'in taffy layout ağacına node eklemesidir.
- `window.request_measured_layout(style, measure) -> LayoutId` — text veya dinamik ölçüm gerektiren elementlerde layout zamanında ölçüm closure'ı sağlar.
- `window.compute_layout(layout_id, available_space, cx)` — verilen layout node'u için hesaplamayı tetikler.
- `window.layout_bounds(layout_id) -> Bounds<Pixels>` — hesaplanan bounds'u pencere koordinatlarında döndürür. Popover ve right-click menu gibi bileşenler anchor bounds'ı öğrenmek için bunu prepaint sırasında okur.
- `window.pixel_snap(...)`, `pixel_snap_f64(...)`, `pixel_snap_point(...)`, `pixel_snap_bounds(...)` — mantıksal pikseli device pixel grid'e hizalar. İnce çizgi, indent guide ve overlay border'larında bulanıklığı azaltmak için kullanılır.

**Frame zamanlama araçları.** Aynı frame yerine sonraki frame'e iş taşımak için üç ana helper grubu vardır:

```rust
window.on_next_frame(|window, cx| {
    window.refresh();
});

cx.on_next_frame(window, |this, window, cx| {
    this.remeasure(window, cx);
});

window.defer(cx, |window, cx| {
    window.dispatch_action(MyAction.boxed_clone(), cx);
});
```

- `window.on_next_frame(...)` — mevcut frame tamamlandıktan sonraki frame'de çalışır. Layout sonucu, hitbox veya popover konumu bir frame sonra bilinecekse doğru araçtır. Zed UI'da bazı menü konumlandırmaları iki kez `on_next_frame` kullanır; ilk frame anchor veya layout bilgisini, ikinci frame menu entity'sinin kendi bounds'unu stabilize eder.
- `Context<T>::on_next_frame(window, |this, window, cx| ...)` — aynı işin current entity'ye bağlı helper'ıdır; callback içine entity update context'i gelir.
- `window.request_animation_frame()` — sürekli animasyon, GIF veya animated image için yeni frame ister. Bir view içinde çağrıldığında current view'i sonraki frame'de notify eder.
- `cx.defer(...)`, `window.defer(cx, ...)`, `cx.defer_in(window, ...)` — mevcut effect cycle bittikten sonra çalışır. Entity zaten update stack'inde olduğunda reentrant update panic'inden kaçınmak ya da focus/menu dispatch'ini stack boşalınca yapmak için kullanılır. Layout ölçümü gerektiğinde `defer` yerine `on_next_frame` tercih edilir.

**Low-level custom element hook'ları.** Element implementasyonu yazılırken kullanılan dispatch ve hitbox API'leri:

- `window.insert_window_control_hitbox(area, hitbox)` — paint fazında platform control hitbox'ı kaydeder; Windows custom titlebar'da min, max, close ve drag alanları için kullanılır.
- `window.set_key_context(context)` — paint fazında current dispatch node'una keybinding context bağlar. Element API'deki `.key_context(...)` bunun sarmalıdır.
- `window.set_focus_handle(&focus_handle, cx)` — prepaint fazında current dispatch node'unu focus handle ile ilişkilendirir. Element API'deki `.track_focus(...)` çoğu uygulama kodunda daha doğru seviyedir.
- `window.set_view_id(view_id)` — prepaint fazında dispatch veya cache node'una view id bağlar. Kaynak yorumunda kaldırılması planlanan düşük seviyeli bir kaçış yolu olarak işaretlidir; normal view render akışında kullanılmamalıdır.
- `window.bounds_changed(cx)` — platform resize/move callback'inin yaptığı state yenileme ve observer notify işlemini tetikler. Platform/test altyapısı içindir; uygulama kodunda resize simülasyonu dışında çağrılmamalıdır.

## App/Window Low-level Servisleri: Platform, Text, Palette ve Atlas

Bu küçük API'ler ana render modelinin parçası değildir; ancak Zed başlangıcı, editor text davranışı ve image cache gibi yerlerde devreye girer.

**Application ve platform kurulumu.** Application yapıcısı tek seçimle gelir; platform helper'ları ise üst katmanda yaygın olarak kullanılır:

- `Application::with_platform(Rc<dyn Platform>)` Application kurmak için tek yapıcıdır; `Application::new()` diye sade bir constructor yoktur.
- Üretim kodu genellikle bu yapıcıyı doğrudan çağırmaz; `gpui_platform` yardımcıları kullanılır:
  - `gpui_platform::application()` → `Application::with_platform(current_platform(false))`.
  - `gpui_platform::headless()` → `Application::with_platform(current_platform(true))`.
  - Hedef tek thread wasm ise `gpui_platform::single_threaded_web()` aynı desenin web varyantıdır.
- Test koşumunda `Application::with_platform(test_platform)` ile `TestPlatform` veya `VisualTestPlatform` enjekte edilir; `Application::run` GPUI'a sahipliği geçirip event loop'u sürer.
- `Application::with_assets(Assets)` embedded asset kaynağını bağlar; `svg()`, `window.use_asset` ve bundled resource yüklemeleri buna dayanır. SVG rasterizer da bu çağrıdan sonra reset edilir.
- `Application::with_http_client(Arc<dyn HttpClient>)` çalışma zamanı HTTP istemcisini bağlar; varsayılan `NullHttpClient` instance'tır.
- Headless testlerde `HeadlessAppContext::with_platform(...)` aynı fikrin test harness sürümüdür; UI penceresi açmadan App, executor ve platform servislerini kurar.

**Text ve render servisleri.** Metin rendering tarafında ek API'ler şu işleri yapar:

- `cx.set_text_rendering_mode(mode)` ve `cx.text_rendering_mode()` uygulama genelindeki text rendering modunu yönetir. Zed startup'ta ayarlardan gelen değeri buraya yazar.
- `TextRenderingMode::{PlatformDefault, Subpixel, Grayscale}` desteklenir. `PlatformDefault` text system tarafında platformun önerdiği gerçek moda çözülür; ölçüm ve paint path'inde enum doğrudan string ayar gibi ele alınmamalıdır.
- `cx.svg_renderer() -> SvgRenderer` düşük seviyeli SVG rasterizer handle'ını verir. Uygulama elementleri çoğunlukla `svg()` veya `window.paint_svg(...)` kullanır; cache/renderer entegrasyonu yazılırken doğrudan erişim gerekebilir.
- `window.show_character_palette()` platform karakter paletini açar. Editor tarafındaki `show_character_palette` action'ı bu çağrıya iner.

**Image atlas ve kaynak bırakma.** GPU atlas sızıntısı olmaması için image release callback'leri özel helper'lar sağlar:

- `window.drop_image(Arc<RenderImage>) -> Result<()>` — current window sprite atlas'ından image kaynağını bırakır.
- `cx.drop_image(image, current_window)` — tüm pencerelerde atlas temizliği yapar. Current window update edilirken `App.windows` içinden geçici olarak çıkmış olabileceği için `Some(window)` argümanı ayrıca verilir.
- Zed/GPUI image cache release callback'leri atlas sızıntısı olmasın diye bu API'leri kullanır; normal `img()`/`svg()` kullanımında elle çağrılması gerekmez.

**Pencere ve platform küçük servisleri.** Pencere bağlamında erişilebilen yardımcılar:

- `window.display(cx) -> Option<Rc<dyn PlatformDisplay>>` — pencerenin bulunduğu display'i platform display listesiyle eşler.
- `window.show_character_palette()`, `window.play_system_bell()`, `window.set_window_edited(...)`, `window.set_document_path(...)` gibi çağrılar platform entegrasyonudur; cross-platform davranış platform trait implementasyonuna bağlıdır.
- `window.gpu_specs()` ve feature-gated `window.input_latency_snapshot()` diagnostic ekranlar veya performans analizi içindir; uygulama state akışının kaynağı olarak kullanılmamalıdır.

**Tuzaklar.** Bu low-level servisleri yanlış kullanmak görünmez sorunlar üretir:

- `cx.svg_renderer()` veya `cx.drop_image(...)` gibi düşük seviye servisleri component API yerine kullanmak ownership ve cache sorumluluğunu da çağırana yükler.
- `Application::with_platform` üretimde tek platform seçimini startup'ta yapar; çalışma zamanında platform değiştirme mekanizması değildir.
- `show_character_palette` her platformda gerçek bir UI açmayabilir; platform implementasyonu no-op olabilir.

## CursorStyle, FontWeight ve Sabit Enum Tabloları

Aşağıdaki sabitler her seferinde araştırılmak yerine tek noktada toplanır. Sık başvurulan platform enum'ları ve hangi alanda anlam taşıdıkları kısaca özetlenir.

#### `CursorStyle` (`crates/gpui/src/platform.rs:1745+`)

CSS cursor karşılıklarıyla birlikte:

- `Arrow` (default)
- `IBeam`, `IBeamCursorForVerticalLayout` — metin girişi.
- `Crosshair`
- `OpenHand` (`grab`), `ClosedHand` (`grabbing`)
- `PointingHand` (`pointer`)
- `ResizeLeft`, `ResizeRight`, `ResizeLeftRight` — yatay resize.
- `ResizeUp`, `ResizeDown`, `ResizeUpDown` — dikey resize.
- `ResizeUpLeftDownRight`, `ResizeUpRightDownLeft` — köşe resize.
- `ResizeColumn`, `ResizeRow` — tablo veya grid resize.
- `OperationNotAllowed` (`not-allowed`)
- `DragLink` (`alias`), `DragCopy` (`copy`)
- `ContextualMenu` (`context-menu`)

Element üzerinde `.cursor(CursorStyle::PointingHand)` ya da kısayollar `.cursor_pointer()`, `.cursor_text()`, `.cursor_grab()`, `.cursor_default()` kullanılır.

#### `FontWeight` (`crates/gpui/src/text_system.rs:871+`)

CSS weight değerleriyle birebir:

- `THIN` (100), `EXTRA_LIGHT` (200), `LIGHT` (300)
- `NORMAL` (400, default), `MEDIUM` (500)
- `SEMIBOLD` (600), `BOLD` (700)
- `EXTRA_BOLD` (800), `BLACK` (900)

`FontWeight::ALL` dizisi tüm değerleri sırasıyla taşır. UI bileşenlerinde genellikle `FontWeight::SEMIBOLD` ve `FontWeight::BOLD` tercih edilir.

#### `FontStyle`

`Normal`, `Italic`, `Oblique`. `.italic()` fluent kısayolu Italic'e set eder.

#### `WindowControlArea` (`crates/gpui/src/window.rs:564`)

`Drag`, `Close`, `Max`, `Min`. Custom bir titlebar yazarken Windows native hit-test için zorunludur.

#### `HitboxBehavior` (`crates/gpui/src/window.rs:692`)

`Normal`, `BlockMouse`, `BlockMouseExceptScroll`. `.occlude()` ve `.block_mouse_except_scroll()` element kısayolları sırasıyla son ikisini set eder.

#### `BorderStyle` (`crates/gpui/src/scene.rs:544`)

`Solid`, `Dashed`. `Style::border_style` veya `paint_quad` ile geçirilir.

#### `Anchor`, `Corners` ve Layer-shell `Anchor`

Anchored elementte kullanılan tip `gpui::Anchor`'dır: `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`, `TopCenter`, `BottomCenter`, `LeftCenter`, `RightCenter`.

`Corners<T>` farklı bir tiptir; border radius ve quad köşe yarıçapları içindir. Layer-shell modülündeki `Anchor` ise bitflag yapısındadır (`TOP | BOTTOM | LEFT | RIGHT`) ve anchored element `Anchor`'ı ile karıştırılmamalıdır.

#### `ResizeEdge` (`crates/gpui/src/platform.rs:358`)

`Top`, `Bottom`, `Left`, `Right`, `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight`. `window.start_window_resize(edge)` argümanı olarak verilir.

## Kalan GPUI Tipleri: Dış API ve Crate-İçi Sınır

Bu bölüm iki farklı yüzeyi ayırır: `crates/gpui/src/gpui.rs` üzerinden dışarı export edilen public API ve private modüllerde `pub` tanımlanmış olsa da yalnız crate içinde erişilebilen taşıyıcılar. `pub` kelimesi tek başına dış API anlamına gelmez; dış kullanıcı açısından asıl sınır `gpui.rs` içindeki `pub use ...` / `pub(crate) use ...` kararlarıdır.

#### Style ve Layout Enumları

`style.rs` tarafındaki temel enum ve type alias'lar `Styled` fluent metotlarının arkasındaki ham değerlerdir:

- Hizalama: `AlignItems`, `AlignSelf`, `JustifyItems`, `JustifySelf`, `AlignContent`, `JustifyContent`.
- Flex: `FlexDirection`, `FlexWrap`.
- Görünürlük ve metin: `Visibility`, `WhiteSpace`, `TextOverflow`, `TextAlign`.
- Dolgu: `Fill` (`style.rs:808`); şu anda tek varyantı `Color(Background)`'tır. Tek varyantlı bir enum olmasının nedeni gelecekte ek dolgu tipleri (örneğin örüntü tabanlı fill) eklenebilmesi için API'yi sabit tutmaktır. Solid renk dışında bir şey üretmek gerektiğinde `Background` tipinin `linear_gradient`, `pattern_slash` veya `checkerboard` constructor'ları kullanılır.
- Debug: `DebugBelow`, yalnız `debug_assertions` altında derlenir; `debug_below` styling'ini custom element içinden okumak için global marker olarak kullanılır.

Uygulama kodunda genellikle bu enum'lar doğrudan inşa edilmez. `.items_center()`, `.justify_between()`, `.flex_col()`, `.whitespace_nowrap()`, `.text_ellipsis()` gibi helper metotlar kullanılır. Özel element veya style refinement yazılırken ham enum'lara ihtiyaç duyulur.

#### Geometri Yardımcıları

`geometry.rs` public yüzeyindeki düşük seviye yardımcılar:

- `Axis` ve `Along` — yatay/dikey eksene göre `Point`, `Size`, `Bounds` gibi tiplerden ilgili boyutu seçmek için kullanılır.
- `Half` ve `IsZero` — generic geometri hesaplarında yarıya bölme ve sıfır testi sağlayan trait'lerdir.
- `Radians`/`radians(value)` ve `Percentage`/`percentage(value)` — transform, gradient ve responsive ölçü değerlerini tip-güvenli taşır.
- `GridLocation` ve `GridPlacement` — `.grid_row(...)`, `.grid_col(...)`, `.grid_area(...)` gibi style metotlarının ham grid yerleşim girdisidir.
- `PathStyle` — path çiziminde fill veya stroke stil seçimini taşır.

Bu tipler özellikle custom layout hesaplarında, canvas ve path çiziminde ve grid placement değerlerinin programatik üretiminde kullanılır.

#### Element ve Frame-State Taşıyıcıları

Bazı public tipler element ağacının layout, prepaint ve paint fazları arasında state taşır:

- `Drawable<E>`, `Canvas<T>`, `AnimationElement<E>`, `Svg`, `Img`, `SurfaceSource`.
- `AnchoredState`, `DivFrameState`, `DivInspectorState`, `ImgLayoutState`, `ListPrepaintState`, `InteractiveTextState`, `UniformListFrameState`, `UniformListScrollState`.
- `InteractiveElementState`, `ElementClickedState`, `ElementHoverState`, `GroupStyle`, `DragMoveEvent<T>`.
- `DeferredScrollToItem`, `ItemSize`, `UniformListDecoration`, `ListScrollEvent`, `ListMeasuringBehavior`, `ListHorizontalSizingBehavior`.

Normal uygulama kodunda bu state tipleri çoğunlukla doğrudan tutulmaz; `div()`, `canvas(...)`, `img(...)`, `svg()`, `list(...)`, `uniform_list(...)`, `anchored()`, `deferred(...)` ve ilgili element builder'ları bunları üretir. Custom element implementasyonu yazılırken `Element::request_layout`, `Element::prepaint` ve `Element::paint` dönüş değerlerinde bu taşıyıcıların benzer desenleri izlenir.

#### Input Event Tipleri

`interactive.rs` event ailesi:

- Trait sınıfları: `InputEvent`, `KeyEvent`, `MouseEvent`, `GestureEvent`.
- Klavye: `ModifiersChangedEvent`, `KeyboardClickEvent`, `KeyboardButton`.
- Mouse: `MouseClickEvent`, `MouseExitEvent`, `PressureStage`.
- Dokunma ve gesture: `TouchPhase`, `NavigationDirection`.
- Hitbox: `HitboxId` rendered frame içinde hitbox'ı tanımlayan opaque id'dir; uygulama kodu genellikle `Hitbox` handle'ı ve `window.hitbox(...)` sonucu ile çalışır.
- Drag/drop tarafında `ExternalPaths` ve `FileDropEvent` "Drag ve Drop İçerik Üretimi" başlığında ayrıca ele alınmıştır.

Element callback'lerinde concrete event tipi çoğunlukla otomatik gelir: `.on_mouse_down(|event, window, cx| ...)`, `.on_scroll_wheel(...)`, `.on_modifiers_changed(...)` gibi. Synthetic test event'i veya platform input çevirimi yazılırken `InputEvent::to_platform_input()` hattı önemlidir.

**Modifiers deref aliasing (asimetrik).** Aşağıdaki dört event açıkça `impl Deref for X { type Target = Modifiers; }` taşır (`crates/gpui/src/interactive.rs:77`, `:450`, `:502`, `:590`):

- `ModifiersChangedEvent`
- `ScrollWheelEvent`
- `PinchEvent`
- `MouseExitEvent`

Bu sayede `Modifiers` üzerindeki tüm `&self` metotları — `secondary()`, `modified()`, `number_of_modifiers()`, `is_subset_of(...)` ve `control`, `alt`, `shift`, `platform`, `function` alanları — bu dört event üzerinde doğrudan çağrılabilir. "Keystroke, Modifiers ve Platform Bağımsız Kısayollar" başlığındaki kısayollar (`Modifiers::command_shift()` vb.) ise `Modifiers` üzerinde **inherent associated function**'dır; event üzerinden çağrılmaz, ayrı bir `Modifiers` üretmek için kullanılır.

`MouseDownEvent`, `MouseUpEvent` ve `MouseMoveEvent` Deref **etmez**; yalnız `modifiers: Modifiers` alanını ifşa eder. Bu nedenle bu üç event'te `event.modifiers.secondary()` yazılır; dört Deref'li event'te ise hem `event.modifiers.secondary()` hem `event.secondary()` çalışır. Asimetri kasıtlıdır: Deref'li dörtlü "input'un modifier şapkası budur" semantiğini taşır; mouse press/move event'leri ise modifier'ı yalnız yan veri olarak saklar.

#### Image, SVG ve Cache Taşıyıcıları

Image ve SVG hattında public ama genelde framework tarafından taşınan tipler:

- `ImageId`, `ImageFormat`, `ClipboardString`.
- `ImageFormatIter` — `ImageFormat` üzerindeki `#[derive(EnumIter)]` (`platform.rs:1973`) ile otomatik üretilen iterator tipidir. Uygulama kodu doğrudan adlandırmaz; `ImageFormat::iter()` (strum'dan) bu tipi döndürür. `from_mime_type` fonksiyonu kendi içinde `Self::iter().find(...)` ile clipboard içeriğini "olası en yaygın formattan başlayarak" eşleştirir; varyant sırası — Png, Jpeg, Webp, Gif, Svg, Bmp, Tiff, Ico, Pnm — kasıtlıdır ve iter sonucunu doğrudan etkiler.
- `ImageStyle`, `ImageAssetLoader`, `ImageCacheProvider`, `AnyImageCache`, `ImageCacheItem`, `ImageLoadingTask`, `RetainAllImageCacheProvider`.
- `RenderImageParams` ve `RenderSvgParams` — renderer'a verilecek rasterization parametrelerini taşır.

Uygulama seviyesinde çoğunlukla `img(source)`, `svg().path(...)`, `image_cache(retain_all(id))`, `window.use_asset(...)`, `window.paint_image(...)` ve `window.paint_svg(...)` kullanılır. Cache implementasyonu yazılırken `ImageCacheProvider -> ImageCache -> ImageCacheItem` zincirine inilir.

#### Platform, Dispatcher, Atlas ve Renderer Sınırı

Platform implementasyonu veya headless renderer yazılmadığı sürece aşağıdaki tipler uygulama kodunda nadiren doğrudan kullanılır:

- Display ve diagnostic: `DisplayId`, `ThermalState`, `SourceMetadata`, `RequestFrameOptions`, `WindowParams`, `InputLatencySnapshot`.
- Dispatcher ve executor: rustdoc public yüzeyinde `Scope`, `FallibleTask`, `SchedulerForegroundExecutor` ve `RunnableMeta` görünür. Buna ek olarak platform sınırında `#[doc(hidden)]` tutulan `PlatformDispatcher`, `RunnableVariant` (`Runnable<RunnableMeta>` type alias'ı) ve `TimerResolutionGuard` vardır; bunlar `target/doc/gpui/all.html` listesinde görünmez ve uygulama API'si olarak kullanılmamalıdır. Detay:
  - `RunnableMeta { location: &'static Location<'static> }` (`scheduler/src/scheduler.rs:59`) — her scheduled task'a iliştirilen debug meta verisi. `track_caller` ile yakalanan kaynak konumunu taşır; profiler ve log akışı doc-hidden `RunnableVariant` üzerinden bu alana ulaşır.
  - `FallibleTask<T>` (`scheduler/src/executor.rs:250`) — `Task::fallible(self)` çağrısının döndürdüğü sarmalayıcı. Future olarak poll edildiğinde `Option<T>` döner; iptal edilirse panik atmaz, `None` üretir. `must_use` işaretli olduğu için sessizce drop edilirse derleme uyarısı verir.
  - `SchedulerForegroundExecutor` — `gpui::executor.rs:10` `pub use scheduler::ForegroundExecutor as SchedulerForegroundExecutor` re-export'udur. GPUI tarafındaki `ForegroundExecutor` bunun üzerinde bir sarmaldır; ham scheduler handle'ına `ForegroundExecutor::scheduler_executor()` (`executor.rs:369`) çağrısıyla inilir, `BackgroundExecutor::scheduler_executor()` de paralel `scheduler::BackgroundExecutor` döner. Uygulama kodu genelde `cx.foreground_executor()` veya `cx.background_executor()` kullanır; scheduler handle yalnız scheduler crate'iyle doğrudan etkileşim gerektiğinde çekilir.
- Text ve keyboard: `PlatformTextSystem`, `NoopTextSystem`, `PlatformKeyboardLayout`, `PlatformKeyboardMapper`, `DummyKeyboardMapper`, `PlatformInputHandler`.
- GPU atlas: `PlatformAtlas`, `AtlasKey`, `AtlasTextureList<T>`, `AtlasTile`, `AtlasTextureId`, `AtlasTextureKind`, `TileId`.
- Headless ve screen capture: `PlatformHeadlessRenderer`, `scap_screen_sources(...)`.
- Test platformu: `TestDispatcher`, `TestScreenCaptureSource`, `TestScreenCaptureStream`, `TestWindow`.
- İç scheduler: `PlatformScheduler` modül içinde public olsa da crate kökünden normal uygulama API'si olarak export edilen bir yüzey değildir.

Bu tiplerin doğru sahibi `gpui_platform` implementasyonlarıdır. Zed uygulama katmanında genellikle `cx.platform()`, `cx.text_system()`, `cx.svg_renderer()`, `window.drop_image(...)`, `window.input_latency_snapshot()` veya "Headless, Screen Capture ve Test Renderer" başlığındaki API'ler üzerinden dolaylı erişim sağlanır.

#### Scene, Primitive ve Crate-İçi Arena Taşıyıcıları

`scene.rs`, `arena.rs` ve `taffy.rs` renderer ve layout boru hattının alt katmanıdır:

- Scene tarafı dış API'ye re-export edilir: `Scene`, `Primitive`, `PrimitiveBatch`, `DrawOrder`, `Quad`, `Underline`, `Shadow`, `PaintSurface`, `MonochromeSprite`, `SubpixelSprite`, `PolychromeSprite`, `PathId`, `PathVertex<P>`, `PathVertex_ScaledPixels`.
- Layout tarafında `AvailableSpace` ve `LayoutId` crate kökünden public olarak export edilir. `TaffyLayoutEngine` ise `taffy` private modülünde `pub struct` olsa da `gpui.rs` yalnız `use taffy::TaffyLayoutEngine` yaptığı için dış API değildir.
- Arena tarafında `Arena` ve `ArenaBox<T>` `arena` private modülünde `pub` olarak tanımlanır; ancak `gpui.rs` bunları `pub(crate) use arena::*` ile yalnız crate içine açar; dış uygulama kodunun API'si değildir.

Uygulama kodu genellikle bu tipleri elle üretmez. `Element` implementasyonları `window.paint_quad`, `window.paint_image`, `window.paint_path`, `window.paint_layer` gibi API'ler üzerinden scene'e primitive ekler. Arena yönetimi `Window::draw` boyunca dahili olarak yapılır; arena'yı açıp kapatan `ElementArenaScope` da `window.rs` içinde `pub(crate)` olduğu için uygulama kodu doğrudan kullanmaz, `AnyElement`/`Element` API'leri üzerinden çalışır.

**Scene public metot envanteri.** Aşağıdaki metotlar scene seviyesinde doğrudan erişilebilir:

- `Scene` — `clear`, `len`, `push_layer`, `pop_layer`, `insert_primitive`, `replay`, `finish`, `batches`.
- `Primitive` — `bounds`, `content_mask`.
- `TransformationMatrix` — `unit`, `translate`, `rotate`, `scale`, `compose`, `apply`.
- `Path` — `new`, `scale`, `move_to`, `line_to`, `curve_to`, `push_triangle`, `clipped_bounds`.

#### Text System ve Line Layout Taşıyıcıları

`text_system.rs` ve alt modülleri font shaping, wrapping ve glyph rasterization verilerini public tiplerle taşır:

- Font ve glyph kimlikleri: `TextSystem`, `FontId`, `FontFamilyId`, `GlyphId`, `FontMetrics`, `RenderGlyphParams`, `GlyphRasterData`.
- Satır shaping: `ShapedLine`, `ShapedRun`, `ShapedGlyph`, `LineLayout`, `WrappedLine`, `WrappedLineLayout`, `FontRun`.
- Wrapping: `LineWrapper`, `LineWrapperHandle`, `LineFragment`, `Boundary`, `WrapBoundary`, `TruncateFrom`.
- Decoration: `DecorationRun`.

Normal UI kodu bunlara `window.text_system()`, `window.line_height()`, `window.text_style()`, `StyledText`, `TextLayout` ve `InteractiveText` üzerinden dokunur. Custom text renderer veya editor seviyesinde ölçüm kodu yazılırken ham tiplere ihtiyaç duyulur.

**Text public metot envanteri.** Metin alt katmanında doğrudan çağrılabilen API'ler şunlardır:

- `TextSystem` — `new`, `all_font_names`, `add_fonts`, `get_font_for_id`, `resolve_font`, `bounding_box`, `typographic_bounds`, `advance`, `layout_width`, `em_width`, `em_advance`, `em_layout_width`, `ch_width`, `ch_advance`, `units_per_em`, `cap_height`, `x_height`, `ascent`, `descent`, `baseline_offset`, `line_wrapper`.
- `WindowTextSystem` — `new`, `shape_line`, `shape_line_by_hash`, `shape_text`, `layout_line`, `try_layout_line_by_hash`, `layout_line_by_hash`.
- `Font` — `bold`, `italic`.
- `FontMetrics` — `ascent`, `descent`, `line_gap`, `underline_position`, `underline_thickness`, `cap_height`, `x_height`, `bounding_box`.
- `ShapedLine` — `len`, `width`, `with_len`, `paint`, `paint_background`, `split_at`.
- `WrappedLine` — `len`, `paint`, `paint_background`.
- `LineLayout` — `index_for_x`, `closest_index_for_x`, `x_for_index`, `font_id_for_index`.
- `WrappedLineLayout` — `len`, `width`, `size`, `ascent`, `descent`, `wrap_boundaries`, `font_size`, `runs`, `index_for_position`, `closest_index_for_position`, `position_for_index`.
- `LineWrapper` — `wrap_line`, `should_truncate_line`, `truncate_line`.
- `FontFeatures` — `disable_ligatures`, `tag_value_list`, `is_calt_enabled`.
- `FontFallbacks` — `fallback_list`, `from_fonts`.

#### Profiler, Queue ve Global Traitleri

Performans ve queue altyapısındaki public taşıyıcılar:

- Profiler: `TaskTiming`, `ThreadTaskTimings`, `ThreadTimings`, `ThreadTimingsDelta`, `GlobalThreadTimings`, `GuardedTaskTimings`, `SerializedLocation`, `SerializedTaskTiming`, `SerializedThreadTaskTimings`.
- Priority queue: `SendError<T>`, `RecvError`, `Iter<T>`, `TryIter<T>`.
- Global helper trait'leri: `ReadGlobal`, `UpdateGlobal`.

Profiler tipleri `gpui::profiler` yüzeyinden task veya thread zamanlamalarını okumak ve serialize etmek için kullanılır. Queue hata ve iterator tipleri `PriorityQueueSender`/`PriorityQueueReceiver` kullanıldığında görünür. `ReadGlobal` ve `UpdateGlobal` trait'leri global state okuma ve güncelleme kısayollarını sağlar; uygulama kodunda çoğu zaman doğrudan `cx.global`, `cx.read_global` veya `cx.update_global` çağrıları yeterlidir.

#### Prompt Renderer Taşıyıcıları

Prompt katmanında iki ek tip vardır:

- `RenderablePromptHandle` — prompt sonucunu özel `RenderOnce` UI ile gösterebilen handle.
- `FallbackPromptRenderer` — platform native prompt yoksa GPUI içinde fallback prompt render etmek için kullanılan renderer hook'u.

Uygulama tarafında çoğu zaman `cx.prompt(...)`, `cx.prompt_for_path(...)`, `cx.prompt_for_new_path(...)` ve `PromptBuilder` yeterlidir; custom platform veya headless prompt davranışı yazılırken bu taşıyıcılara inilir.

#### Menu, Keymap, Action ve Test Taşıyıcıları

Doğrudan kullanıcı akışında nadiren görünen public yardımcılar:

- Menu: `SystemMenuType`, `OwnedOsMenu`.
- Keymap: `KeymapVersion`, `BindingIndex`, `KeyBindingMetaIndex`, `ContextEntry`.
- Tab sırası: `TabStopOperation` `tab_stop.rs` içinde `pub enum` olsa da modül `gpui.rs` tarafından `pub(crate) use tab_stop::*` ile açılır; dış API değildir. Focus traversal için dış kod `FocusHandle`, `tab_stop`, `tab_group` ve `tab_index` API'lerini kullanır.
- Action registry: `MacroActionBuilder`, `MacroActionData`, `generate_list_of_all_registered_actions()`.
- Test: `TestAppWindow<V>` ve macOS `test-support` için `VisualTestAppContext`.
- App internals: `AppCell`, `AppRef`, `AppRefMut`, `ArenaClearNeeded`, `KeystrokeEvent`, `AnyDrag`, `LeakDetectorSnapshot`.

`generate_list_of_all_registered_actions()` action registry'yi dokümantasyon, komut paleti veya test doğrulaması için tarar. `AppCell`/`AppRef`/`AppRefMut` normal uygulama kodunun sahiplenmesi gereken tipler değildir; `App`, `Context<T>` ve async context'ler üzerinden çalışmak doğru sınırdır.

#### Küçük Public Fonksiyonlar

- `guess_compositor()` — Linux/Wayland/X11 compositor adını tahmin eder; "Platform Servisleri" başlığındaki `cx.compositor_name()` akışının düşük seviyeli yardımcısıdır.
- `get_gamma_correction_ratios(gamma)` — atlas/glyph rendering gamma düzeltme oranlarını üretir; tema rengi seçmek için kullanılmaz.
- `LinearColorStop` — gradient stop verisidir; `linear_gradient(...)` helper'ları bunu üretir.
- `combine_highlights(...)` — text highlight katmanlarını birleştirir; editor ve text rendering hattında kullanılır.
- `hash(data)` — asset cache anahtarı üretimi için yardımcıdır.
- `percentage(value)` — `Percentage` constructor helper'ıdır.
- `scap_screen_sources(...)` — screen capture kaynaklarını platforma göre toplar; uygulama kodunda çoğu zaman `cx.screen_capture_sources(...)` tercih edilir.

#### Constants ve Type Aliases

`target/doc/gpui/all.html` altında ayrı listelenen sabitler:

- `DEFAULT_WINDOW_SIZE = 1536x1095` — `WindowOptions.window_bounds` verilmediğinde default placement için kullanılan ana pencere boyutu.
- `DEFAULT_ADDITIONAL_WINDOW_SIZE = 900x750` — settings veya rules library gibi ek işlevsel pencereler için önerilen minimum oranlı boyut.
- `KEYSTROKE_PARSE_EXPECTED_MESSAGE` — `InvalidKeystrokeError` mesajının "beklenen modifier + key" açıklaması.
- `LOADING_DELAY = 200ms` — `img()` elementinin loading state'i göstermeden önce beklediği süre.
- `MAX_BUTTONS_PER_SIDE = 3` — `WindowButtonLayout` içinde bir tarafta tutulabilecek native control button slot sayısı.
- `SHUTDOWN_TIMEOUT = 100ms` — `Context::on_app_quit` future'larının app quit sırasında çalışabileceği süre.
- `SMOOTH_SVG_SCALE_FACTOR = 2.0` — SVG'leri daha yumuşak raster etmek için kullanılan yüksek çözünürlük scale'i.
- `SUBPIXEL_VARIANTS_X = 4`, `SUBPIXEL_VARIANTS_Y = 1` — glyph atlas subpixel rasterization varyant sayıları.

Type alias'lar:

- `AlignSelf = AlignItems`, `JustifyItems = AlignItems`, `JustifySelf = AlignItems`, `JustifyContent = AlignContent` — style enum alias'ları.
- `DrawOrder = u32` — scene layer/primitive sıralama anahtarı.
- `ImageLoadingTask = Shared<Task<Result<Arc<RenderImage>, ImageCacheError>>>` — image cache loader task tipi.
- `ImgResourceLoader = AssetLogger<ImageAssetLoader>` — `img()` elementinin asset loader alias'ı.
- `InspectorRenderer = Box<dyn Fn(&mut Inspector, &mut Window, &mut Context<Inspector>) -> AnyElement>` — `App::set_inspector_renderer(...)` ile kurulan inspector UI renderer callback'i.
- `PathVertex_ScaledPixels = PathVertex<ScaledPixels>` — scene path vertex alias'ı.
- `Result = anyhow::Result` — crate kök hata alias'ı.
- `Transform = lyon::math::Transform` — path builder transform alias'ı.

Renk ve geometri kısa fonksiyonları:

- Renk: `rgb(0xRRGGBB)`, `rgba(0xRRGGBBAA)`, `hsla(h, s, l, a)`, `black()`, `white()`, `red()`, `green()`, `blue()`, `yellow()`, `transparent_black()`, `transparent_white()`, `opaque_grey(l, a)`.
- Background: `solid_background(color)`, `linear_color_stop(color, percentage)`, `linear_gradient(angle, from, to)`, `pattern_slash(color, width, interval)`, `checkerboard(color, size)`.
- Geometri: `point(x, y)`, `size(width, height)`, `px(f32)`, `rems(f32)`, `relative(f32)`, `percentage(f32)`, `radians(f32)`, `auto()`, `phi()`.

#### Kök Re-export ve Makro Yüzeyi

`gpui.rs` crate kökünde yalnız GPUI modüllerini değil, bazı yardımcı crate'leri de yeniden export eder:

- `Result` — `anyhow::Result` alias'ıdır; GPUI API'leriyle aynı hata tipini kullanmak için tercih edilir.
- `ArcCow` — `gpui_util::arc_cow::ArcCow`; clone maliyeti düşük copy-on-write paylaşımlı veri taşımak içindir.
- `FutureExt` ve `Timeout` — `future.with_timeout(duration, executor)` zincirinin trait ve hata tipidir. Zincirin döndürdüğü future wrapper tipi `WithTimeout<T>`'dir.
- `block_on` — `pollster::block_on`; sync köprü gerektiğinde foreground olmayan küçük future'lar için kullanılır.
- `ctor` — inventory veya action registration gibi startup registration desenleri için yeniden export edilir.
- `http_client` — GPUI platform HTTP client trait'lerine crate kökünden erişim sağlar.
- `proptest` — yalnız `test-support` veya test build'lerinde property test yardımcılarını export eder.
- Makrolar: `Action`, `IntoElement`, `AppContext`, `VisualContext`, `register_action`, `test`, `property_test`. `gpui.rs` ayrıca `Render` derive'ını da re-export eder; ancak macro kaynağında `#[doc(hidden)]` olduğu için `target/doc/gpui/all.html` içinde listelenmez ve `derive.Render.html` sayfası üretilmez. Bu derive yalnız boş bir `Render` impl'i üretir; `render` gövdesi `gpui::Empty` döndürür. Gerçek UI üreten view'lerde manuel `impl Render` yazılır.

Rustdoc listesindeki `Action`, `IntoElement`, `Refineable`, `AppContext` ve `VisualContext` kısa adları tek bir öğe değildir; trait ve derive macro yüzeyleri ayrı namespace'lerde yaşar. `#[derive(AppContext)]` struct içinde `#[app]` ile işaretlenmiş `&mut App` alanını bulur ve `AppContext` metotlarını o alana delege eder. `#[derive(VisualContext)]` hem `#[app]` hem `#[window]` ister; `VisualContext` için `type Result<T> = T` üretir, `window_handle`, `update_window_entity`, `new_window_entity`, `replace_root_view` ve `focus` çağrılarını ilgili `App`/`Window` alanlarına indirir. `prelude::IntoElement`, `prelude::Refineable` ve `prelude::VisualContext` rustdoc'ta görünen derive macro alias'larıdır; yeni bir trait veya farklı bir runtime davranışı değildir.

Bu re-export'lar yeni bir API anlamına gelmez; modüllerde anlatılan aynı yüzeyin crate kökünden ergonomik erişimidir. Özellikle `property_test` ve `proptest` yalnız test kodunda, `ctor` ise registration altyapısı gibi dar alanlarda kullanılır.

Test helper fonksiyonları `gpui::test` modülünde toplanır: `seed_strategy()`, `apply_seed_to_proptest_config(...)`, `run_test_once(...)`, `run_test(...)` ve `Observation<T>`. Bunlar `#[gpui::test]` ve `#[gpui::property_test]` makrolarının altyapısıdır; normal uygulama kodu çağırmaz.

Profiler helper'ları `add_task_timing(...)` ve `get_current_thread_task_timings()` thread-local task timing toplama için kullanılır. Text fallback helper'ları `font_name_with_fallbacks(...)` ve `font_name_with_fallbacks_shared(...)` platform font ailesi fallback adını döndürür. `swap_rgba_pa_to_bgra(...)` premultiplied RGBA byte buffer'ını platform BGRA düzenine çevirmek için renk veya bitmap alt katmanında kullanılır.

---
