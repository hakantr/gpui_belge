# Etkileşim ve Olaylar

---

## Focus, Blur ve Keyboard

Klavye odağı GPUI'de `FocusHandle` ile temsil edilir. Bir view'in odak alıp
verebilmesi için kendine ait bir handle tutması ve render sırasında bu handle'ı
elemente bağlaması gerekir.

```rust
struct View {
    focus_handle: FocusHandle,
}

impl View {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            focus_handle: cx.focus_handle(),
        }
    }
}
```

Render zincirinde handle element'e bağlanır; isteğe bağlı olarak focus-visible
stil eklenir:

```rust
div()
    .track_focus(&self.focus_handle)
    .focus_visible(|style| style.border_color(cx.theme().colors().border_focused))
```

Programatik olarak odak vermek için handle'ın kendisi veya `cx.focus_view`
çağrısı kullanılır:

```rust
self.focus_handle.focus(window, cx);
// veya
cx.focus_view(&child_entity, window);
```

**Focus sorguları.** Mevcut odak durumunu kontrol etmek için üç temel soru ve
üç karşılık gelen metot vardır:

- `focus_handle.is_focused(window)` — handle doğrudan odakta mı?
- `focus_handle.contains_focused(window, cx)` — bu handle veya altındaki bir
  düğüm odakta mı?
- `focus_handle.within_focused(window, cx)` — bu handle odakta olan düğümün
  içinde mi?

**Focus olayları.** Odakla ilgili değişimleri dinlemek için ayrı subscription
metotları mevcuttur:

- `cx.on_focus(handle, window, ...)` — handle doğrudan odak aldı.
- `cx.on_focus_in(handle, window, ...)` — handle veya bir descendant odak aldı.
- `cx.on_blur(handle, window, ...)` — handle odak kaybetti.
- `cx.on_focus_out(handle, window, |this, event, window, cx| ...)` — handle
  veya descendant odak dışına çıktı; callback view state alır ve
  `FocusOutEvent` içinden blur'lanan handle'a (`event.blurred`) erişilebilir.
- `window.on_focus_out(handle, cx, |event, window, cx| ...)` — aynı olayın
  view state almayan, daha düşük seviyeli `Window` varyantı; sonucu
  `Subscription` olarak döner.
- `cx.on_focus_lost(window, ...)` — pencere içinde hiçbir handle odakta
  kalmadığında çalışır.

**Keyboard action akışı.** Tuşların action'a bağlanması birkaç adımdan
oluşur; bu adımlar her özel kısayol için tekrarlanır:

1. `actions!(namespace, [ActionA, ActionB])` veya `#[derive(Action)]` +
   `#[action(...)]` ile action tanımı yapılır.
2. Element ağacında `.key_context("context-name")` belirtilir; bu sayede
   action yalnızca uygun bağlamda dispatch edilir.
3. `cx.bind_keys([KeyBinding::new("cmd-k", ActionA, Some("context-name"))])`
   ile binding kaydedilir.
4. Handler için `.on_action(...)`, `.capture_action(...)` veya
   `cx.on_action(...)` kullanılır.

**Event propagation.** GPUI olay yayılımı varsayılan olarak yukarı doğru
ilerler. İki helper bu davranışı kontrol eder:

- Mouse ve key event handler'ları varsayılan olarak propagate eder.
- `cx.stop_propagation()` daha arkadaki veya üstteki handler'lara olayın
  ulaşmasını keser.
- Action bubble fazında handler'lar varsayılan olarak propagation'ı durdurur;
  gerekirse `cx.propagate()` ile devam ettirilebilir.

## Mouse, Drag, Drop ve Hitbox

Element seviyesindeki etkileşim API'leri tek bir fluent zincir içinde
toplanır; aşağıdaki metotlar farklı mouse olaylarına ve drag-drop kalıplarına
karşılık gelir:

- `.on_click(...)`
- `.on_mouse_down(...)`, `.on_mouse_up(...)`, `.on_mouse_move(...)`
- `.on_mouse_down_out(...)`, `.on_mouse_up_out(...)`
- `.on_scroll_wheel(...)`
- `.on_pinch(...)`
- `.on_drag_move::<T>(...)`
- `.drag_over::<T>(...)`
- `.on_drop::<T>(...)`
- `.can_drop(...)`
- `.occlude()` veya `.block_mouse_except_scroll()`
- `.cursor_pointer()`, `.cursor(...)`

Pencere kontrol hitbox'ı isteniyorsa fluent API üzerinden işaretlenir:

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
```

Özel resize ve cursor davranışı için `canvas` ile hitbox eklemek Zed'deki
client decoration deseninin tipik bir örneğidir:

```rust
canvas(
    |bounds, window, _cx| {
        window.insert_hitbox(bounds, HitboxBehavior::Normal)
    },
    |_bounds, hitbox, window, _cx| {
        window.set_cursor_style(CursorStyle::ResizeLeftRight, &hitbox);
    },
)
```

Burada `canvas` imzası
`prepaint: FnOnce(Bounds<Pixels>, &mut Window, &mut App) -> T` ve
`paint: FnOnce(Bounds<Pixels>, T, &mut Window, &mut App)` şeklindedir. İkinci
closure'da ilk pozisyonel argüman `bounds`'tur (kullanılmıyorsa `_bounds`),
ikinci argüman ise prepaint'in döndürdüğü değerdir (örnekteki `hitbox`).
`set_cursor_style` hitbox'a referans aldığı için `&hitbox` şeklinde geçilir.

## Drag ve Drop İçerik Üretimi

`crates/gpui/src/elements/div.rs:572+` ve `1271+`.

GPUI'da drag sırasında, sürüklenen elementin yerine ayrı bir "ghost" view
oluşturulur ve mouse ile birlikte bu view hareket eder:

```rust
div()
    .id("draggable")
    .on_drag(payload.clone(), |payload, mouse_offset, window, cx| {
        cx.new(|_| GhostView::for_payload(payload.clone(), mouse_offset))
    })
```

İmza şu şekildedir:

```rust
fn on_drag<T, W>(
    self,
    value: T,
    constructor: impl Fn(&T, Point<Pixels>, &mut Window, &mut App) -> Entity<W> + 'static,
) -> Self
where
    T: 'static,
    W: 'static + Render;
```

- `value: T` — drag payload tipidir; alıcı tarafta `on_drop::<T>` ile aynı
  tipe bağlanır.
- `constructor` — her drag başlangıcında ghost view üretir; mouse offset'i
  payload'a göre konumlandırır.
- `W: Render` — ghost'un kendi entity'sidir; standart render gibi davranır.

**Drop tarafı.** Alıcı element kabul edilebilirlik kontrolünü, stilini ve
listener'ını ayrı ayrı tanımlar:

```rust
div()
    .drag_over::<MyPayload>(|style, payload, window, cx| {
        style.bg(rgb(0xeeeeee))
    })
    .can_drop(|payload, window, cx| {
        payload
            .downcast_ref::<MyPayload>()
            .is_some_and(|payload| payload.is_compatible(window, cx))
    })
    .on_drop::<MyPayload>(cx.listener(|this, payload: &MyPayload, window, cx| {
        this.accept(payload.clone());
        cx.notify();
    }))
```

**API.** Drag-drop akışı için kullanılan başlıca metotlar şunlardır:

- `.on_drag::<T, W>(value, ctor)` — drag başlatır.
- `.drag_over::<T>(|style, payload, window, cx| -> StyleRefinement)` — hover
  sırasında uygulanan stil refinement.
- `.can_drop(|payload: &dyn Any, window, cx| -> bool)` — drop kabul edilip
  edilmeyeceğine karar verir. Tip kontrolü için `downcast_ref::<T>()`
  kullanılır.
- `.on_drop::<T>(listener)` — drop tamamlandığında çalışır.
- `.on_drag_move::<T>(listener)` — drag süresince mouse pozisyonu bilgisi
  verir.
- `cx.has_active_drag()` — app genelinde aktif bir drag olup olmadığını
  döner.
- `cx.active_drag_cursor_style()` — aktif drag cursor override değeri.
- `cx.stop_active_drag(window)` — aktif drag'i temizler, pencereyi refresh
  için planlar ve gerçekten bir drag varsa `true` döner. Escape/cancel
  yollarında kullanılır.

**Harici sürükleme.** Dosya sisteminden sürükleyip bırakma akışı için
`FileDropEvent` ve `ExternalPaths` tipleri kullanılır. Platform
`FileDropEvent::Entered/Pending/Submit/Exited` üretir; `Window::dispatch_event`
bu olayları dahili `active_drag` durumuna ve `ExternalPaths` payload'ına
çevirir. UI tarafında normal drag/drop API'siyle yakalanır:

```rust
div()
    .on_drag_move::<ExternalPaths>(cx.listener(|this, event, window, cx| {
        let paths = event.drag(cx).paths();
        this.preview_external_drop(paths, event.bounds, window, cx);
    }))
    .on_drop(cx.listener(|this, paths: &ExternalPaths, window, cx| {
        this.handle_external_paths_drop(paths, window, cx);
    }))
```

`ExternalPaths::paths()` `&[PathBuf]` döner. Ghost view dosya ikonları olarak
platform tarafından çizilir; GPUI tarafındaki `Render for ExternalPaths`
bilerek `Empty` döndürür.

**Tuzaklar.** Drag-drop yazarken karşılaşılan yaygın hatalar:

- Drag edilen tip `T: 'static` olmalıdır; lifetime taşıyan tipler kabul
  edilmez.
- Aynı element üzerinde `on_drag` iki kez çağrıldığında panic oluşur
  ("calling on_drag more than once on the same element is not supported").
- Ghost view her drag'de yeni bir `cx.new(...)` ile yaratılır; constructor
  içinde yan etkiden kaçınılmalıdır.
- `can_drop` `false` döndüğünde `drag_over` ve `group_drag_over` stilleri
  uygulanmaz, `on_drop` çağrılmaz. Kabul edilmeyen hedef için ayrı bir görsel
  geri bildirim gösterilecekse `on_drag_move` kullanılır.

## Hitbox, Cursor, Pointer Capture ve Autoscroll

Hitbox, mouse hit-test ve cursor davranışının temelidir. Element handler'ları
çoğu zaman hitbox'ı arka planda kurar; bu API doğrudan özel canvas veya özel
element yazılırken devreye girer.

```rust
let hitbox = window.insert_hitbox(bounds, HitboxBehavior::Normal);
if hitbox.is_hovered(window) {
    window.set_cursor_style(CursorStyle::PointingHand, &hitbox);
}
```

**Davranış tipleri.** Hitbox'ın arka planda kalan başka hitbox'larla ilişkisi
`HitboxBehavior` ile ifade edilir:

- `HitboxBehavior::Normal` — arkadaki hitbox'ları etkilemez.
- `HitboxBehavior::BlockMouse` — arkadaki mouse, hover, tooltip ve scroll
  hitbox davranışlarını bloke eder. `.occlude()` bu davranışı kullanır.
- `HitboxBehavior::BlockMouseExceptScroll` — arkadaki mouse interaction'ı
  bloke eder ama scroll'un geçmesine izin verir.
  `.block_mouse_except_scroll()` bu davranışı kullanır.

**Pointer capture.** Sürükleme veya resize gibi senaryolarda mouse bounds
dışına çıksa bile olayları almaya devam etmek için pointer capture kullanılır:

```rust
window.capture_pointer(hitbox.id);
// drag/resize bittiğinde
window.release_pointer();
```

Capture aktifken ilgili hitbox hovered sayılır. Resize handle ve sürükleme
etkileşimlerinde mouse bounds dışına çıksa bile hareket takip edilebilir.
`window.captured_hitbox()` aktif capture id'sini döndürür; özel element
debug'ı veya iç içe drag state ayrıştırması dışında genelde kullanılmaz.

**Autoscroll.** Drag sırasında viewport kenarına yaklaşıldığında otomatik
kaydırma talep etmek için iki yardımcı vardır:

- `window.request_autoscroll(bounds)` — drag sırasında viewport kenarına
  yakın bölge için autoscroll talep eder.
- `window.take_autoscroll()` — scroll container tarafında bu talebi tüketir.

**Cursor.** İmleç stili hitbox veya pencere bağlamında ayarlanır:

- `window.set_cursor_style(style, &hitbox)` — hitbox hovered ise cursor
  stilini ayarlar.
- `window.set_window_cursor_style(style)` — pencere genelindeki cursor
  state.
- `cx.set_active_drag_cursor_style(style, window)` — aktif drag payload için
  cursor override.
- `cx.active_drag_cursor_style()` — mevcut drag cursor'unu okur.

**Tuzaklar.** Hitbox ve cursor tarafında dikkat edilecek noktalar:

- `Hitbox::is_hovered` keyboard input modality sırasında `false` dönebilir;
  scroll handler yazılırken `should_handle_scroll` tercih edilir.
- Overlay elementleri `.occlude()` kullanmazsa arkadaki butonlar hover ve
  click almaya devam edebilir.
- Pointer capture release edilmediğinde sonraki mouse hareketlerinde yanlış
  hitbox hovered kalabilir.

## Tab Sırası ve Klavye Navigasyonu

`crates/gpui/src/tab_stop.rs`, `window.rs:397`.

Tab navigasyonu `FocusHandle` üzerindeki iki bayrak yardımıyla kontrol edilir;
ikisi de fluent zincirde okunur:

```rust
let handle = cx.focus_handle()
    .tab_stop(true)        // Tab tuşuyla durulabilir
    .tab_index(0);         // Sıra path'ine katılır
```

**Sıralama kuralları.** Tab traversal sırası TabStopMap içindeki node
sıralamasına göre belirlenir:

1. Aynı grup içinde `tab_index` küçükten büyüğe sıralanır.
2. `tab_index` eşit olduğunda element ağaç sırası (DFS) belirleyicidir.
3. `tab_stop(false)` olan handle sırada konumunu korur ama klavyeyle durak
   olmaz. Negatif `tab_index` özel olarak "devre dışı" anlamına gelmez;
   yalnızca sıralamada daha erken bir path değeri üretir.

**Gruplar.** Bir grup tanımlamak için element tarafında `.tab_group()`
kullanılır; grubun sırası gerekiyorsa aynı elemente `.tab_index(index)`
verilir. `TabStopMap::begin_group` ve `end_group` traversal'ın internal
operasyonlarıdır; uygulama kodunda doğrudan çağrılmaz.

Düşük seviyeli karşılık `window.with_tab_group(Some(index), |window| ...)`
çağrısıdır; `None` verilirse grup açılmadan closure çalışır. Normal component
kodunda `.tab_group()` fluent API'si tercih edilir.

**Window üzerindeki yardımcılar.** Tab/Shift-Tab davranışı pencere üzerinden
yapılır:

- `window.focus_next(cx)` / `window.focus_prev(cx)` — Tab veya Shift-Tab
  geldiğinde çağrılır.
- `window.focused(cx)` — o anki odak handle'ını verir.

**Custom input bileşeni.** Tab akışına dahil olacak özel bir input için:

```rust
div()
    .track_focus(&self.focus_handle)
    .on_action(cx.listener(|this, _: &menu::Confirm, window, cx| { ... }))
    .child(/* ... */)
```

`tab_stop(true)` olmadan handle yalnızca programatik olarak odak alır;
klavyeyle ulaşılamaz. Erişilebilirlik ve form akışı için her interaktif
elementin bir handle'a sahip olması beklenir.

## Text Input ve IME

Platform IME entegrasyonu `InputHandler` üzerinden çalışır. Editor benzeri
metin alanlarının aşağıdaki metot ailesini sağlaması gerekir:

- `selected_text_range`
- `marked_text_range`
- `text_for_range`
- `replace_text_in_range`
- `replace_and_mark_text_in_range`
- `unmark_text`
- `bounds_for_range`
- `character_index_for_point`
- `accepts_text_input`

Ham `InputHandler` implementasyonu yazıldığında ayrıca
`prefers_ime_for_printable_keys` override edilebilir. Bununla birlikte yaygın
view yolu olan `EntityInputHandler` + `ElementInputHandler` ikilisinde bu
ayrı bir hook değildir; mevcut wrapper `prefers_ime_for_printable_keys`
sorusunu `accepts_text_input` sonucunu kullanarak yanıtlar. IME ve
keybinding önceliğinin `accepts_text_input`'tan bağımsız yönetilmesi
gerekiyorsa doğrudan `InputHandler` implement eden özel bir handler yazılır.

IME aday penceresinin doğru konumda kalması için imleç hareketinden sonra:

```rust
window.invalidate_character_coordinates();
```

Zed'de form tipindeki tek satırlık input için doğrudan editor yazmak yerine
`ui_input::InputField` kullanılır. Bu crate editor'a bağlı olduğu için `ui`
içinde değildir.

**`ui_input` public yüzeyi.** Public API üzerinde aşağıdaki öğeler bulunur:

- `pub use input_field::*`; ana component `InputField`.
- `InputField::new(window, cx, placeholder_text)` tek satırlık bir editor
  instance'ı ister ve placeholder'ı hemen editor'a yazar.
- Builder ve metot zinciri: `.start_icon(IconName)`, `.label(...)`,
  `.label_size(LabelSize)`, `.label_min_width(Length)`, `.tab_index(isize)`,
  `.tab_stop(bool)`, `.masked(bool)`, `.is_empty(cx)`, `.editor()`,
  `.text(cx)`, `.clear(window, cx)`, `.set_text(text, window, cx)`,
  `.set_masked(masked, window, cx)`.
- `InputFieldStyle` public struct olarak görünür ancak alanları private;
  dışarıdan stil override sözleşmesi değil, render içi tema snapshot'ıdır.
- `ErasedEditor` trait'i editor köprüsüdür; `text`, `set_text`, `clear`,
  `set_placeholder_text`, `move_selection_to_end`, `set_masked`,
  `focus_handle`, `subscribe`, `render`, `as_any` metotlarını içerir.
- `ErasedEditorEvent::{BufferEdited, Blurred}` picker veya search gibi üst
  bileşenlerin edit ve blur akışını dinlemesi için yayınlanır.
- `ERASED_EDITOR_FACTORY: OnceLock<fn(&mut Window, &mut App) -> Arc<dyn
  ErasedEditor>>` editor crate tarafından kurulur. Zed'de
  `crates/editor/src/editor.rs` init akışında bu factory
  `Editor::single_line(window, cx)` döndüren `ErasedEditorImpl` ile set
  edilir. Factory unset iken `InputField::new` panic eder; bu nedenle uygulama
  init sırası editor kurulumu tamamlandıktan sonra `InputField` üretimine
  güvenmelidir.

## Text Input Handler ve IME Derin Akış

Metin düzenleyen özel bir element yazılırken yalnızca key event dinlemek
yeterli değildir. IME, dead key, marked text ve aday penceresi için platforma
`InputHandler` sağlanmalıdır.

**View tarafı.** Görece geniş bir trait yüzeyi vardır; sık kullanılan
metotlar şu şekilde implement edilir:

```rust
impl EntityInputHandler for EditorLikeView {
    fn selected_text_range(
        &mut self,
        ignore_disabled_input: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<UTF16Selection> {
        self.selection_utf16(ignore_disabled_input, window, cx)
    }

    fn marked_text_range(
        &self,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<Range<usize>> {
        self.marked_range_utf16(window, cx)
    }

    fn unmark_text(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        self.clear_marked_text(window, cx);
    }

    // text_for_range, replace_text_in_range,
    // replace_and_mark_text_in_range, bounds_for_range,
    // character_index_for_point da uygulanır.
}
```

Element paint sırasında handler pencereye kaydedilir:

```rust
window.handle_input(
    &focus_handle,
    ElementInputHandler::new(bounds, view_entity.clone()),
    cx,
);
```

**Kurallar.** IME entegrasyonunda sıkça gözden kaçan noktalar şunlardır:

- Range değerleri UTF-16 offset'idir; Rust byte index'iyle karıştırılmaz.
- `bounds_for_range` ekran veya aday penceresi konumlandırması için doğru
  mutlak bounds döndürmelidir.
- Cursor veya selection hareketinden sonra
  `window.invalidate_character_coordinates()` çağrılır; aksi halde IME
  paneli yeni konuma taşınmaz.
- `accepts_text_input` `false` olduğunda platformun metin eklemesi
  engellenebilir.
- Raw `InputHandler::prefers_ime_for_printable_keys` `true` olduğunda
  ASCII dışı IME aktifken yazdırılabilir tuşlar keybinding'den önce IME'ye
  gider. `ElementInputHandler` sarmalı `EntityInputHandler` için GPUI bu
  kararı `accepts_text_input` üzerinden verir; trait'te ayrı bir override
  noktası yoktur.
- Window frame geçişinde platform input handler `Vec<Option<_>>` slot'ları
  `.pop()` ile kısaltılmaz; `.take()` ile boş slot bırakılır ve bir sonraki
  frame'de aynı slot'a geri yerleştirilir. `reuse_paint` cached `paint_range`
  index'leri bu yüzden stabil kalır. Özel düşük seviye window/frame kodu
  yazılırken input handler dizisinin uzunluğu, index cache'i varken
  değiştirilmez.

**Tuzaklar.** IME ile çalışırken sık yapılan hatalar:

- Sadece `.on_key_down` ile metin editörü yazmak IME ve dead-key dillerinde
  bozulur.
- UTF-16 range'i doğrudan byte slice'a uygulamak çok-byte'lı karakterlerde
  panic ya da yanlış seçim üretir.
- Input handler frame'e bağlıdır; odak edilen element paint edilmediğinde
  platform input handler da düşer.

## Keystroke, Modifiers ve Platform Bağımsız Kısayollar

`crates/gpui/src/platform/keystroke.rs` klavye girdisinin normalize edilmiş
modelini içerir. Keymap yalnızca action binding değildir; tamamlanmamış input,
IME durumu ve gösterim metni de bu tiplerle taşınır.

**Ana tipler.** Klavye dünyasını ifade eden tipler birbirini destekleyecek
şekilde tasarlanmıştır:

- `Keystroke { modifiers, key, key_char }` — gerçek input. `key` basılan
  tuşun ASCII karşılığıdır (örneğin option-s için `s`); `key_char` o tuşla
  üretilebilecek karakteri tutar (option-s için `Some("ß")`, cmd-s için
  `None`). ASCII'ye çevrilemeyen layout'larda `key` yine ASCII fallback'i
  olur, asıl yazılan karakter `key_char`'a düşer. Ayrı bir `ime_key` alanı
  yoktur.
- `KeybindingKeystroke` — binding dosyalarında görünen display modifier/key
  ile eşleşme için kullanılan sarıcı tip.
- `InvalidKeystrokeError` — parse hatası. Hatanın `Display` çıktısı
  `gpui::KEYSTROKE_PARSE_EXPECTED_MESSAGE: &str` sabitini şablon olarak
  kullanır (`platform/keystroke.rs:69`); kullanıcı keymap parser'ında aynı
  beklenti cümlesinin gösterilmesi için bu sabite bağlanılır.
- `Modifiers` — `control`, `alt`, `shift`, `platform`, `function` alanları.
- `AsKeystroke` — hem `Keystroke` hem display wrapper'ları üzerinden ortak
  keystroke erişimi sağlayan küçük trait.
- `Capslock { on }` — platform input snapshot'ında capslock durumunu taşır.

Tipik kullanım parse, unparse ve dispatch zincirinde görünür:

```rust
let keystroke = Keystroke::parse("cmd-shift-p")?;
let text = keystroke.unparse();
let handled = window.dispatch_keystroke(keystroke, cx);
```

**Modifier yardımcıları.** Sık kullanılan modifier kombinasyonları için
yapıcı fonksiyonlar mevcuttur:

- `Modifiers::none()`, `command()`, `windows()`, `super_key()`,
  `secondary_key()`, `control()`, `alt()`, `shift()`, `function()`,
  `command_shift()`, `control_shift()`.
- `command()`, `windows()` ve `super_key()` aslında aynı işi yapar:
  `Modifiers { platform: true, .. }` üretir. Tek bir `platform` field'ı OS'a
  göre command (macOS), windows (Windows) veya super (Linux) anlamına gelir;
  bu üç constructor yalnızca kavramsal vurgu için farklı isimlerle export
  edilir.
- `secondary_key()` macOS'ta command, Linux ve Windows'ta control üretir;
  Zed'de platform-bağımsız kısayol yazılırken çoğu durumda doğru seçim
  budur.
- `modified()`, `secondary()`, `number_of_modifiers()`,
  `is_subset_of(&other)` input ayrıştırmada kullanılır.

**IME.** Bileşimsel girdi sırasında özel bayraklar devreye girer:

- `Keystroke::is_ime_in_progress()` — IME composition sırasında `true` döner.
- `window.dispatch_keystroke(...)` test ve simülasyon yolunda
  `with_simulated_ime()` uygular; doğrudan düşük seviye event üretilirken
  IME state'inin ayrıca düşünülmesi gerekir.

**`KeybindingKeystroke` yüzeyi.** Display ve gerçek keystroke ayrımı bu
sarıcı üzerinden yapılır:

- `KeybindingKeystroke::new_with_mapper(inner, use_key_equivalents,
  keyboard_mapper)` — platform keyboard mapper üzerinden display key ve
  modifier üretir. `from_keystroke(keystroke)` platform mapping yapmadan
  sarar. Windows'ta `new(inner, display_modifiers, display_key)`
  constructor'ı da vardır; macOS ve Linux build'lerinde bu constructor
  bulunmaz.
- `inner()`, `modifiers()`, `key()` getter'ları display ile gerçek keystroke
  ayrımını saklar. Windows'ta `modifiers()` ve `key()` display değerini
  döndürebilir; gerçek GPUI input'u için `inner()` okunur.
- `set_modifiers(...)`, `set_key(...)`, `remove_key_char()` ve `unparse()`
  keybinding editor veya normalizer akışında kullanılır. `remove_key_char()`
  yalnızca `inner.key_char = None` yapar; `key` alanına dokunmaz.

**Binding sorguları.** Kullanıcıya gösterilecek kısayol metni ve aktif input
zinciri için window üzerinde yardımcılar mevcuttur:

- `window.bindings_for_action(&Action)` ve
  `window.keystroke_text_for(&Action)` kullanıcıya gösterilecek kısayol
  metni için tercih edilir.
- `cx.all_bindings_for_input(&[Keystroke])` ve
  `window.possible_bindings_for_input(&[Keystroke])` çoklu vuruş veya prefix
  binding durumlarında kullanılır.
- `window.pending_input_keystrokes()` henüz tamamlanmamış input zincirini
  verir.

---
