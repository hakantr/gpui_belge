# Bölüm IX — Etkileşim ve Olaylar

---

## Focus, Blur ve Keyboard


Focus handle:

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

Render:

```rust
div()
    .track_focus(&self.focus_handle)
    .focus_visible(|style| style.border_color(cx.theme().colors().border_focused))
```

Focus vermek:

```rust
self.focus_handle.focus(window, cx);
// veya
cx.focus_view(&child_entity, window);
```

Focus sorguları:

- `focus_handle.is_focused(window)`: handle doğrudan focused mı?
- `focus_handle.contains_focused(window, cx)`: bu handle veya descendant focused mı?
- `focus_handle.within_focused(window, cx)`: bu handle focused node'un içinde mi?

Focus olayları:

- `cx.on_focus(handle, window, ...)`: handle doğrudan focus aldı.
- `cx.on_focus_in(handle, window, ...)`: handle veya descendant focus aldı.
- `cx.on_blur(handle, window, ...)`: handle focus kaybetti.
- `cx.on_focus_out(handle, window, |this, event, window, cx| ...)`: handle veya
  descendant focus dışına çıktı; callback view state alır ve `FocusOutEvent`
  içinden blur'lanan handle'a (`event.blurred`) erişilebilir.
- `window.on_focus_out(handle, cx, |event, window, cx| ...)`: aynı olayın view
  state almayan düşük seviyeli `Window` varyantı; geri çağrımı `Subscription`
  olarak döner.
- `cx.on_focus_lost(window, ...)`: pencere içinde focus kalmadı.

Keyboard action akışı:

1. `actions!(namespace, [ActionA, ActionB])` veya `#[derive(Action)]` +
   `#[action(...)]` ile action tanımla.
2. Element ağacında `.key_context("context-name")` belirt.
3. `cx.bind_keys([KeyBinding::new("cmd-k", ActionA, Some("context-name"))])`.
4. Handler için `.on_action(...)`, `.capture_action(...)` veya `cx.on_action(...)` kullan.

Event propagation:

- Mouse/key event handler'lar default propagate eder.
- `cx.stop_propagation()` daha arkadaki/üstteki handler'lara gitmesini keser.
- Action bubble phase'de handler'lar default propagation'ı durdurur; gerekirse
  `cx.propagate()` kullanılır.

## Mouse, Drag, Drop ve Hitbox


Element interactivity:

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

Pencere kontrol hitbox'ı:

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
```

Custom resize/cursor için `canvas` ile hitbox eklemek Zed'deki client decoration
desenidir:

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

Burada `canvas` imzası `prepaint: FnOnce(Bounds<Pixels>, &mut Window, &mut App) -> T`
ve `paint: FnOnce(Bounds<Pixels>, T, &mut Window, &mut App)` şeklindedir; ikinci
closure'da ilk pozisyonel argüman `bounds` (kullanılmıyorsa `_bounds`), ikinci
argüman ise prepaint'in döndürdüğü değer (`hitbox`) olur. `set_cursor_style`
hitbox'a referans ister; bu yüzden `&hitbox` geçilir.

## Drag ve Drop İçerik Üretimi


`crates/gpui/src/elements/div.rs:572+` ve `1271+`.

GPUI'de drag, drag edilen elementin yerine ayrı bir "ghost" view oluşturur ve
mouse'u onun ile takip eder.

```rust
div()
    .id("draggable")
    .on_drag(payload.clone(), |payload, mouse_offset, window, cx| {
        cx.new(|_| GhostView::for_payload(payload.clone(), mouse_offset))
    })
```

İmza:

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

- `value: T` drag payload tipidir; alıcı tarafta `on_drop::<T>` ile aynı tip ile
  bağlanır.
- `constructor` her drag başlangıcında ghost view üretir; mouse offset'i payload'a
  göre konumlandırır.
- `W: Render` ghost'un kendi entity'sidir; standart render gibi davranır.

Drop tarafı:

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

API:

- `.on_drag::<T, W>(value, ctor)`: drag başlat.
- `.drag_over::<T>(|style, payload, window, cx| -> StyleRefinement)`: hover sırasında
  uygulanan stil refinement.
- `.can_drop(|payload: &dyn Any, window, cx| -> bool)`: drop kabul edilip
  edilmeyeceği. Tip kontrolü gerekiyorsa `downcast_ref::<T>()` kullanılır.
- `.on_drop::<T>(listener)`: drop tamamlandı.
- `.on_drag_move::<T>(listener)`: drag süresince mouse pozisyonu.
- `cx.has_active_drag()`: app genelinde aktif drag var mı?
- `cx.active_drag_cursor_style()`: aktif drag cursor override'ı.
- `cx.stop_active_drag(window)`: aktif drag'i temizler, window refresh planlar ve
  gerçekten drag vardıysa `true` döndürür. Escape/cancel path'lerinde kullanılır.

Harici sürükleme (dosya sistem drag-in) için `FileDropEvent` ve `ExternalPaths`
akışı kullanılır. Platform `FileDropEvent::Entered/Pending/Submit/Exited`
üretir; `Window::dispatch_event` bunu dahili `active_drag` durumuna ve
`ExternalPaths` payload'ına çevirir. UI tarafında normal drag/drop API'siyle
yakalanır:

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

`ExternalPaths::paths()` `&[PathBuf]` döndürür. Ghost view platform tarafından
dosya ikonları olarak çizilir; GPUI tarafındaki `Render for ExternalPaths`
bilerek `Empty` döndürür.

Tuzaklar:

- Drag edilen tip `T: 'static` olmalıdır; lifetime taşıyan tip kabul edilmez.
- Aynı element üzerinde `on_drag` iki kez çağrılırsa panic ("calling on_drag more
  than once on the same element is not supported").
- Ghost view her drag'de yeni `cx.new(...)` ile yaratılır; yan etkilerden kaçın.
- `can_drop` false dönerse `drag_over`/`group_drag_over` stilleri uygulanmaz ve
  `on_drop` çağrılmaz; kabul edilmeyen hedefin visual feedback'ini ayrı state ile
  göstermen gerekiyorsa `on_drag_move` kullan.

## Hitbox, Cursor, Pointer Capture ve Autoscroll


Hitbox, mouse hit-test ve cursor davranışının temelidir. Element handler'ları çoğu
zaman bunu senin yerine kurar; custom canvas/element yazarken doğrudan kullanılır.

```rust
let hitbox = window.insert_hitbox(bounds, HitboxBehavior::Normal);
if hitbox.is_hovered(window) {
    window.set_cursor_style(CursorStyle::PointingHand, &hitbox);
}
```

Davranış tipleri:

- `HitboxBehavior::Normal`: arkadaki hitbox'ları etkilemez.
- `HitboxBehavior::BlockMouse`: arkadaki mouse, hover, tooltip ve scroll hitbox
  davranışlarını bloke eder; `.occlude()` bunu kullanır.
- `HitboxBehavior::BlockMouseExceptScroll`: arkadaki mouse interaction'ı bloke
  eder ama scroll seçimini geçirebilir; `.block_mouse_except_scroll()` bunu kullanır.

Pointer capture:

```rust
window.capture_pointer(hitbox.id);
// drag/resize bittiğinde
window.release_pointer();
```

Capture aktifken ilgili hitbox hovered sayılır; resize handle ve sürükleme
etkileşimlerinde mouse bounds dışına çıksa bile hareketi takip etmek için kullanılır.
`window.captured_hitbox()` aktif capture id'sini döndürür; custom element debug
veya nested drag state ayrıştırması dışında genelde gerekmez.

Autoscroll:

- `window.request_autoscroll(bounds)`: drag sırasında viewport kenarına yakın
  bölge için autoscroll talep eder.
- `window.take_autoscroll()`: scroll container tarafında talebi tüketir.

Cursor:

- `window.set_cursor_style(style, &hitbox)`: hitbox hovered ise cursor ayarlar.
- `window.set_window_cursor_style(style)`: window genel cursor state'i.
- `cx.set_active_drag_cursor_style(style, window)`: aktif drag payload'ı için
  cursor override.
- `cx.active_drag_cursor_style()` mevcut drag cursor'unu okur.

Tuzaklar:

- `Hitbox::is_hovered` keyboard input modality sırasında false dönebilir; scroll
  handler yazarken `should_handle_scroll` kullan.
- Overlay elementleri `.occlude()` kullanmazsa arkadaki butonlar hover/click
  almaya devam edebilir.
- Pointer capture release edilmezse sonraki mouse hareketlerinde yanlış hitbox
  hovered kalabilir.

## Tab Sırası ve Klavye Navigasyonu


`crates/gpui/src/tab_stop.rs`, `window.rs:397`.

Tab navigasyonu `FocusHandle` üzerindeki iki bayrakla kontrol edilir:

```rust
let handle = cx.focus_handle()
    .tab_stop(true)        // Tab tuşuyla durulabilir
    .tab_index(0);         // Sıra path'ine katılır
```

Tab traversal sırası TabStopMap içindeki node sıralamasına göre belirlenir:

1. Aynı grup içinde `tab_index` küçükten büyüğe.
2. `tab_index` eşitse element ağaç sırası (DFS).
3. `tab_stop(false)` olan handle sırada konum tutar ama klavyeyle durak olmaz.
   Negatif `tab_index` özel olarak "devre dışı" anlamına gelmez; sadece sıralamada
   daha erken bir path değeri üretir.

Grup oluşturmak için element tarafında `.tab_group()` kullanılır; grubun sırası
gerekiyorsa aynı elemente `.tab_index(index)` verilir. `TabStopMap::begin_group`
ve `end_group` internal traversal operasyonlarıdır; uygulama kodu genelde bunları
doğrudan çağırmaz.

Custom element yazarken low-level karşılığı `window.with_tab_group(Some(index),
|window| ...)` çağrısıdır; `None` verirsen grup açmadan closure'ı çalıştırır.
Normal component kodunda `.tab_group()` fluent API'si tercih edilir.

Window üzerindeki yardımcılar:

- `window.focus_next(cx)` / `window.focus_prev(cx)`: Tab/Shift-Tab sırasında çağrılır.
- `window.focused(cx)`: o anki odak handle'ı.

Custom input bileşeni yazıyorsan:

```rust
div()
    .track_focus(&self.focus_handle)
    .on_action(cx.listener(|this, _: &menu::Confirm, window, cx| { ... }))
    .child(/* ... */)
```

`tab_stop(true)` olmadan handle yalnızca programatik focus alır; klavyeyle
ulaşılamaz. Aksesibilite ve form akışı için her interaktif element bir handle'a
sahip olmalı.

## Text Input ve IME


Platform IME entegrasyonu `InputHandler` üzerinden çalışır. Editor benzeri metin
alanları şunları sağlamalıdır:

- `selected_text_range`
- `marked_text_range`
- `text_for_range`
- `replace_text_in_range`
- `replace_and_mark_text_in_range`
- `unmark_text`
- `bounds_for_range`
- `character_index_for_point`
- `accepts_text_input`

Ham `InputHandler` implementasyonu yazıyorsan ayrıca
`prefers_ime_for_printable_keys` override edilebilir. Ancak yaygın view yolu olan
`EntityInputHandler` + `ElementInputHandler` ikilisinde bu ayrı bir hook değildir;
mevcut wrapper `prefers_ime_for_printable_keys` için `accepts_text_input`
sonucunu kullanır. IME/keybinding önceliğini `accepts_text_input`'tan bağımsız
yönetmen gerekiyorsa doğrudan `InputHandler` implement eden özel handler yaz.

IME aday penceresini doğru yerde tutmak için:

```rust
window.invalidate_character_coordinates();
```

Zed'de form tipi tek satır input için doğrudan editor yazmak yerine
`ui_input::InputField` kullan. Bu crate editor'a bağlı olduğu için `ui` içinde
değildir.

`ui_input` public yüzeyi:

- `pub use input_field::*`; ana component `InputField`.
- `InputField::new(window, cx, placeholder_text)` tek satır editor instance'ı
  ister ve placeholder'ı hemen editor'a yazar.
- Builder/metotlar: `.start_icon(IconName)`, `.label(...)`,
  `.label_size(LabelSize)`, `.label_min_width(Length)`, `.tab_index(isize)`,
  `.tab_stop(bool)`, `.masked(bool)`, `.is_empty(cx)`, `.editor()`,
  `.text(cx)`, `.clear(window, cx)`, `.set_text(text, window, cx)`,
  `.set_masked(masked, window, cx)`.
- `InputFieldStyle` public struct olarak görünür ama alanları private; dışarıdan
  style override sözleşmesi değil, render içi tema snapshot'ıdır.
- `ErasedEditor` trait'i editor köprüsüdür: `text`, `set_text`, `clear`,
  `set_placeholder_text`, `move_selection_to_end`, `set_masked`,
  `focus_handle`, `subscribe`, `render`, `as_any`.
- `ErasedEditorEvent::{BufferEdited, Blurred}` picker/search gibi üst
  bileşenlerin edit/blur akışını dinlemesi için kullanılır.
- `ERASED_EDITOR_FACTORY: OnceLock<fn(&mut Window, &mut App) -> Arc<dyn
  ErasedEditor>>` editor crate tarafından kurulur. Zed'de
  `crates/editor/src/editor.rs` init akışında bu factory
  `Editor::single_line(window, cx)` döndüren `ErasedEditorImpl` ile set edilir.
  `InputField::new` factory unset ise panic eder; bu yüzden uygulama init
  sırası editor kurulumu tamamlandıktan sonra `InputField` oluşturmaya dayanır.

## Text Input Handler ve IME Derin Akış


Metin düzenleyen custom element yazıyorsan yalnızca key event dinlemek yeterli
değildir. IME, dead key, marked text ve candidate window için platforma
`InputHandler` vermen gerekir.

View tarafı:

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

Element paint sırasında:

```rust
window.handle_input(
    &focus_handle,
    ElementInputHandler::new(bounds, view_entity.clone()),
    cx,
);
```

Kurallar:

- Range değerleri UTF-16 offset'idir; Rust byte index'iyle karıştırma.
- `bounds_for_range` screen/candidate positioning için doğru absolute bounds
  döndürmelidir.
- Cursor/selection hareketinden sonra `window.invalidate_character_coordinates()`
  çağır; IME paneli yeni konuma taşınır.
- `accepts_text_input` false ise platform text insertion engellenebilir.
- Raw `InputHandler::prefers_ime_for_printable_keys` true ise non-ASCII IME
  aktifken printable tuşlar keybinding'den önce IME'ye gider. `ElementInputHandler`
  ile sarılan `EntityInputHandler` için GPUI bu kararı `accepts_text_input`
  üzerinden verir; trait'te ayrı bir override noktası yoktur.
- Window frame geçişinde platform input handler `Vec<Option<_>>` slot'ları
  `.pop()` ile kısaltılmaz; `.take()` ile boş slot bırakılıp bir sonraki frame'de
  aynı slot'a geri yerleştirilir. `reuse_paint` cached `paint_range` index'leri
  bu yüzden stabil kalır. Custom düşük seviye window/frame kodu yazarken input
  handler dizisinin uzunluğunu index cache'i varken değiştirme.

Tuzaklar:

- Sadece `.on_key_down` ile text editor yazmak IME ve dead-key dillerinde bozulur.
- UTF-16 range'i byte slice'a doğrudan uygulamak çok byte'lı karakterlerde panic
  veya yanlış seçim üretir.
- Input handler frame'e bağlıdır; focused element paint edilmezse platform input
  handler da düşer.

## Keystroke, Modifiers ve Platform Bağımsız Kısayollar


`crates/gpui/src/platform/keystroke.rs` klavye girdisinin normalized modelidir.
Keymap sadece action binding değildir; pending input, IME ve gösterim metni de
bu tiplerle taşınır.

Ana tipler:

- `Keystroke { modifiers, key, key_char }`: gerçek input. `key` basılan tuşun
  ASCII karşılığıdır (örn. option-s için `s`); `key_char` o tuşla üretilebilecek
  karakteri tutar (örn. option-s için `Some("ß")`, cmd-s için `None`). Asciiye
  çevrilemeyen layout'larda `key` yine ASCII fallback'idir, asıl yazılan
  karakter `key_char`'a düşer. Ayrı bir `ime_key` alanı yoktur.
- `KeybindingKeystroke`: binding dosyalarında görünen display modifier/key ile
  eşleşme için kullanılan sarıcı.
- `InvalidKeystrokeError`: parse hatası. Hatanın `Display` çıktısı
  `gpui::KEYSTROKE_PARSE_EXPECTED_MESSAGE: &str` const'ını şablon olarak
  kullanır (`platform/keystroke.rs:69`); kullanıcı keymap parser'ında aynı
  bekleyiş cümlesini göstermek istersen bu sabite bağlan.
- `Modifiers`: `control`, `alt`, `shift`, `platform`, `function` alanları.
- `AsKeystroke`: hem `Keystroke` hem display wrapper'ları üzerinden ortak
  keystroke erişimi sağlayan küçük trait.
- `Capslock { on }`: platform input snapshot'ında capslock durumunu taşır.

Kullanım:

```rust
let keystroke = Keystroke::parse("cmd-shift-p")?;
let text = keystroke.unparse();
let handled = window.dispatch_keystroke(keystroke, cx);
```

Modifier yardımcıları:

- `Modifiers::none()`, `command()`, `windows()`, `super_key()`,
  `secondary_key()`, `control()`, `alt()`, `shift()`, `function()`,
  `command_shift()`, `control_shift()`.
- `command()`, `windows()`, `super_key()` üçü de aynı şeyi yapar:
  `Modifiers { platform: true, .. }` üretir. Tek bir `platform` field'ı OS'a
  göre command (macOS), windows (Windows) veya super (Linux) anlamına gelir;
  bu üç constructor sadece kavramsal vurgu için ayrı isimle export edilir.
- `secondary_key()` macOS'ta command, Linux/Windows'ta control üretir; Zed'de
  platform bağımsız kısayol yazarken çoğu durumda doğru seçim budur.
- `modified()`, `secondary()`, `number_of_modifiers()`,
  `is_subset_of(&other)` input ayrıştırmada kullanılır.

IME:

- `Keystroke::is_ime_in_progress()` IME composition sırasında true döner.
- `window.dispatch_keystroke(...)` test/simülasyon path'inde
  `with_simulated_ime()` uygular; doğrudan lower-level event üretirken IME
  state'ini ayrıca düşünmek gerekir.

`KeybindingKeystroke` yüzeyi:

- `KeybindingKeystroke::new_with_mapper(inner, use_key_equivalents,
  keyboard_mapper)`: platform keyboard mapper üzerinden display key/modifier
  üretir. `from_keystroke(keystroke)` platform mapping yapmadan sarar.
  Windows'ta `new(inner, display_modifiers, display_key)` constructor'ı da vardır;
  macOS/Linux build'lerinde bu constructor yoktur.
- `inner()`, `modifiers()`, `key()` getter'ları display ve gerçek keystroke
  ayrımını saklar. Windows'ta `modifiers()`/`key()` display değerini döndürebilir;
  gerçek GPUI input'u için `inner()` okunur.
- `set_modifiers(...)`, `set_key(...)`, `remove_key_char()` ve `unparse()`
  keybinding editor/normalizer akışında kullanılır. `remove_key_char()` yalnız
  `inner.key_char = None` yapar; `key` alanını silmez.

Binding sorguları:

- `window.bindings_for_action(&Action)` ve `window.keystroke_text_for(&Action)`
  kullanıcıya gösterilecek kısayol metni için tercih edilir.
- `cx.all_bindings_for_input(&[Keystroke])` ve
  `window.possible_bindings_for_input(&[Keystroke])` multi-stroke veya prefix
  binding durumlarında kullanılabilir.
- `window.pending_input_keystrokes()` henüz tamamlanmamış input zincirini verir.

---

---

