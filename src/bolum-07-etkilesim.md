# 7. Etkileşim

---

## 7.1. Focus, Blur ve Keyboard

Focus (odak), bir pencerede klavye olaylarının ve action'ların hangi UI öğesine gideceğini belirler. GPUI bunu **`FocusHandle` (odak tutamacı)** ile yönetir. Odak tutamacı, görünüm (`view`) ile render edilen UI öğesi (`element`) arasında kararlı bir kimlik kurar: tutamaç görünüm durumunda (`view state`) saklanır, render fonksiyonunda bir UI öğesine `track_focus` ile bağlanır, ardından klavye girdisi ve action dispatch bu tutamaç üzerinden yürür.

### Terimler

Bu bölümde İngilizce tip adları korunur, ama okurken şu Türkçe karşılıklarla düşünmek daha kolaydır:

- **Handle / tutamaç** — Bir şeyi doğrudan taşımak yerine ona erişmek veya onu işaret etmek için saklanan değer. Örneğin `FocusHandle`, "hangi UI öğesi odakla ilişkilidir?" bilgisini tutar.
- **Entity / varlık** — GPUI'de durum (`state`) tutan görünüm (`view`) veya model kaydı. Genellikle `cx.new(...)` ile oluşturulur; dışarıdan `Entity<T>` veya `WeakEntity<T>` gibi tiplerle tutulur.
- **View / görünüm** — Kullanıcıya çizilecek arayüz parçasını üreten Rust tipi.
- **Element / UI öğesi** — `render` fonksiyonunun ürettiği somut arayüz düğümü; `div()`, metin, buton veya özel UI öğesi olabilir.
- **State / durum** — Bir görünümün sakladığı değişebilir alanlar. Örneğin `focus_handle` alanı görünüm durumunun (`view state`) parçasıdır.

### Odak tutamacı oluşturma ve bağlama

Odak tutamacı, görünüm varlığı oluşturulurken bir kez alınır ve görünüm durumunda (`view state`) tutulur:

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

Render fonksiyonunda hangi UI öğesinin bu odak tutamacına karşılık geldiği `track_focus` ile söylenir; `focus_visible` ise klavye ile odaklanıldığında (mouse ile değil) uygulanan stildir — accessibility için kritiktir:

```rust
div()
    .track_focus(&self.focus_handle)
    .focus_visible(|style| style.border_color(cx.theme().colors().border_focused))
```

Programatik olarak odaklamak için:

```rust
self.focus_handle.focus(window, cx);
// veya başka bir görünümü odakla:
cx.focus_view(&child_entity, window);
```

### Focus sorguları

Bir odak tutamacı hakkında üç soru farklı method'larla yanıtlanır:

- `focus_handle.is_focused(window)` — Tutamaç **doğrudan** odakta mı?
- `focus_handle.contains_focused(window, cx)` — Tutamaç veya **alt öğelerinden biri** odakta mı? (Kapsayıcı öğenin "içimde odak var mı" sorusu.)
- `focus_handle.within_focused(window, cx)` — Bu tutamaç, odakta olan düğümün **içinde** mi? (Alt öğenin "üst öğem odakta mı" sorusu.)

### Focus olayları

- `cx.on_focus(handle, window, ...)` — Tutamaç doğrudan odak aldığında çalışır.
- `cx.on_focus_in(handle, window, ...)` — Tutamaç veya alt öğelerinden biri odak aldığında.
- `cx.on_blur(handle, window, ...)` — Tutamaç odağı kaybettiğinde.
- `cx.on_focus_out(handle, window, |this, event, window, cx| { ... })` — Tutamaç veya alt öğelerinden biri odak dışına çıktığında; callback görünüm durumunu alır ve `FocusOutEvent` üzerinden blur'lanan tutamaca (`event.blurred`) erişilebilir.
- `window.on_focus_out(handle, cx, |event, window, cx| { ... })` — Aynı olayın görünüm durumu almayan düşük seviyeli `Window` varyantı; geri dönüşü `Subscription` olarak verir.
- `cx.on_focus_lost(window, ...)` — Pencere içinde hiçbir UI öğesi odakta değilse (modal kapandı, pencere ilk açıldı vb.).

### Klavye action akışı

Klavye kısayollarının görünüme ulaşması dört adımdan geçer:

1. **Action tanımla** — `actions!(namespace, [ActionA, ActionB])` veya `#[derive(Action)] + #[action(...)]` makrosu.
2. **Bağlam belirt** — UI öğesi ağacında `.key_context("context-name")` ile o alt-ağacın bağlam adını söyle.
3. **Binding kaydet** — `cx.bind_keys([KeyBinding::new("cmd-k", ActionA, Some("context-name"))])`.
4. **İşleyici yaz** — `.on_action(...)`, `.capture_action(...)` veya `cx.on_action(...)` ile action geldiğinde çalışacak kodu bağla.

Action tanımı, keybinding ve dispatch stack akışı [Action ve Keymap](./bolum-08-action-ve-keymap.md) bölümünde devam eder.

### Olay yayılımı

Mouse ve klavye olayları bir alt UI öğesinden yukarı doğru "bubble" eder, action'lar ise bağlam ağacında ilerler. Propagation kontrolü iki yönlüdür:

- Mouse/key event işleyicileri **varsayılan olarak propagate eder**; bir işleyici olayı yakalasa da üstteki/arkadaki işleyiciler de tetiklenir.
- `cx.stop_propagation()` arkadaki/üstteki işleyicilere gitmeyi keser.
- Action işleyicileri bubble phase'de **varsayılan olarak propagation'ı durdurur** (action o işleyici tarafından yönetildiği sayılır); ihtiyaç olursa `cx.propagate()` ile devam ettirilir.

## 7.2. Mouse, Drag, Drop ve Hitbox

Mouse etkileşimi `InteractiveElement` trait'i üzerinden çalışır. Bir UI öğesi üstüne event dinleyicileri zincirleme eklenir; mouse hareketi olduğunda GPUI hangi UI öğesinin hangi olayı alacağını **hitbox** kayıtlarına göre belirler. Hitbox'ın düşük seviyeli davranışı [Hitbox, Cursor, Pointer Capture ve Autoscroll](#74-hitbox-cursor-pointer-capture-ve-autoscroll) bölümünde ele alınır; bu bölüm sık kullanılan event ve davranışların özetidir.

### Sık kullanılan mouse/drag listener'ları

- **Tıklama**: `.on_click(...)`
- **Aşamalı tıklama**: `.on_mouse_down(...)`, `.on_mouse_up(...)`, `.on_mouse_move(...)` (mouse down ile mouse up arası tüm hareket).
- **UI öğesi dışına tıklama**: `.on_mouse_down_out(...)`, `.on_mouse_up_out(...)` (dropdown, popover dışına tıklayınca kapatma için).
- **Scroll/zoom**: `.on_scroll_wheel(...)`, `.on_pinch(...)`.
- **Drag akışı**: `.on_drag_move::<T>(...)`, `.drag_over::<T>(...)`, `.on_drop::<T>(...)`, `.can_drop(...)`; içerik üretimi ve payload modeli [Drag ve Drop İçerik Üretimi](#73-drag-ve-drop-içerik-üretimi) bölümünde açıklanır.
- **Mouse engelleme**: `.occlude()` (overlay altındaki tüm mouse'u keser), `.block_mouse_except_scroll()` (scroll'u geçirir, diğerlerini keser).
- **Cursor**: `.cursor_pointer()`, `.cursor(...)` ile UI öğesi hover durumundayken cursor şekli.

### Pencere kontrol hitbox'ı

Pencerenin başlık çubuğu olmadığında sürükleme/küçültme/büyütme bölgelerini işletim sistemine bildirmek için `window_control_area` kullanılır:

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
```

Bu, özellikle Windows'ta Aero Snap ve native sürükleme davranışının çalışmasını sağlar; pencere titlebar tarafı [Custom Titlebar Nasıl Tanımlanır](./bolum-06-pencere-yonetimi.md#66-custom-titlebar-nasıl-tanımlanır) bölümünde anlatılır.

### Custom hitbox ve cursor — `canvas` kullanımı

Yerleşik fluent API yerine düşük seviyeli `canvas` kullanılarak hitbox eklemek, Zed'deki client-side decoration paterninin temelidir. Resize tutamacı, dock divider, custom cursor bölgeleri bu yolla kurulur:

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

`canvas` iki closure alır:

- **Prepaint** kapaması imzası `FnOnce(Bounds<Pixels>, &mut Window, &mut App) -> T` — geri dönen `T`, paint fazına aktarılacak değerdir (bu örnekte `Hitbox`).
- **Paint** kapaması imzası `FnOnce(Bounds<Pixels>, T, &mut Window, &mut App)` — ikinci pozisyonel argüman prepaint'ten gelen değerdir.

`set_cursor_style` hitbox'a referans bekler (`&hitbox`); GPUI yalnızca o hitbox üzerinde olduğunda cursor'ı bu stile çevirir.

## 7.3. Drag ve Drop İçerik Üretimi

Kaynak: `crates/gpui/src/elements/div.rs:572+` ve `1271+`.

GPUI'de bir UI öğesi sürüklendiğinde UI öğesinin kendisi taşınmaz; bunun yerine **hayalet görünüm (`ghost view`)** adı verilen, mouse'u takip eden ayrı bir küçük görünüm oluşturulur. Drag süresince ekranda görünen şey bu hayalet görünümdür; asıl UI öğesi kaynak konumunda kalır. Bu yaklaşım drag sırasında kaynak görünümün layout'unu bozmaz ve birden fazla drop hedefi öngörmek için temiz bir model sunar.

### Drag başlatmak

```rust
div()
    .id("draggable")
    .on_drag(payload.clone(), |payload, mouse_offset, window, cx| {
        cx.new(|_| GhostView::for_payload(payload.clone(), mouse_offset))
    })
```

İmza ve parametrelerin anlamı:

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

- **`value: T`** — Drag payload'ı (taşınan veri). Alıcı taraf `on_drop::<T>` ile aynı tipi belirterek bu payload'a tipli erişir.
- **`constructor`** — Her drag başlangıcında hayalet görünümü (`ghost view`) üreten fonksiyon. Mouse offset'i, drag başladığı andaki mouse'un payload'a göre konumudur — örneğin "bu dosya ikonunun sol üstünden 5 piksel sağdan, 10 piksel aşağıdan tutuldu" bilgisi hayalet görünümü doğru noktada hizalamak için kullanılır.
- **`W: Render`** — Hayalet görünümün varlık içinde tutulan render tipidir; sıradan bir görünüm gibi render edilir.

### Drop tarafı

```rust
div()
    .drag_over::<MyPayload>(|style, payload, window, cx| {
        style.bg(rgb(0xeeeeee))     // hover sırasında arka plan değişir
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

API'lerin işlevleri:

- **`.on_drag::<T, W>(value, ctor)`** — Drag başlatır.
- **`.drag_over::<T>(|style, payload, window, cx| -> StyleRefinement)`** — Drop hedefi üzerinde hover sırasında uygulanan stil refinement'ı.
- **`.can_drop(|payload: &dyn Any, window, cx| -> bool)`** — Drop'un kabul edilip edilmeyeceğini belirler. Tip kontrolü `downcast_ref::<T>()` ile yapılır.
- **`.on_drop::<T>(listener)`** — Drop tamamlandığında çalışan callback.
- **`.on_drag_move::<T>(listener)`** — Drag süresince her mouse hareketi için tetiklenir (örn. autoscroll, live preview).
- **`cx.has_active_drag()`** — Uygulama genelinde herhangi bir aktif drag var mı.
- **`cx.active_drag_cursor_style()`** — Aktif drag için override edilmiş cursor.
- **`cx.stop_active_drag(window)`** — Aktif drag'ı temizler, window refresh'i planlar ve gerçekten drag varsa `true` döner. Escape tuşu veya iptal akışlarında kullanılır.

### Harici sürükleme (dosya sisteminden)

İşletim sisteminden uygulamaya dosya sürüklendiğinde (örn. Finder/Explorer'dan editor üzerine) ayrı bir akış işler. Platform sırasıyla `FileDropEvent::Entered`, `Pending`, `Submit`, `Exited` event'leri üretir; `Window::dispatch_event` bunları dahili `active_drag` durumuna ve `ExternalPaths` payload'ına çevirir. UI tarafında normal drag/drop API'siyle yakalanır:

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

`ExternalPaths::paths()` `&[PathBuf]` döndürür. Hayalet görünüm bu durumda işletim sistemi tarafından dosya ikonu olarak çizilir; GPUI tarafındaki `Render for ExternalPaths` bilerek `Empty` döner — ekrana iki kez dosya ikonu çizilmesin diye.

### Tuzaklar

- **Drag tipi `T: 'static` olmalıdır.** Lifetime taşıyan tip (örn. `&'a Foo`) kabul edilmez; payload sahiplenilebilir bir veri olmak zorundadır.
- **Aynı UI öğesi üzerinde `on_drag` iki kez çağrılırsa panic edilir** ("calling on_drag more than once on the same element is not supported"). Tek bir UI öğesi için tek bir drag kaynağı tanımlanır.
- **Hayalet görünüm her drag'de yeniden `cx.new(...)` ile yaratılır.** Constructor içinde yan etki yapılmaz (örn. global duruma yazma); aksi halde drag'in her başlangıcında yan etki tekrarlanır.
- **`can_drop` `false` döndüğünde `drag_over` / `group_drag_over` stilleri uygulanmaz ve `on_drop` çağrılmaz.** Kabul edilmeyen hedef için ayrı bir visual feedback (örn. "burada bırakılamaz" gri ton) gerekiyorsa `on_drag_move` üzerinden ayrı bir durum ile çizilir.

## 7.4. Hitbox, Cursor, Pointer Capture ve Autoscroll

**Hitbox**, ekrandaki bir bölgenin mouse hit-test'i ve cursor davranışı için "ben buradayım" diyerek pencereye kaydolan görünmez tepki alanıdır. Mouse hareketinde GPUI sıralı hitbox'lara bakarak hangi UI öğesinin hover'da olduğuna, hangi cursor'un gösterileceğine ve hangi event'in nereye gideceğine karar verir. Sıradan UI öğesi dinleyicileri (`.on_click`, `.cursor_pointer()` vs.) hitbox'ı arka planda kendileri kaydeder; düşük seviyeli kullanım custom `canvas` veya özel UI öğesi yazarken devreye girer.

```rust
let hitbox = window.insert_hitbox(bounds, HitboxBehavior::Normal);
if hitbox.is_hovered(window) {
    window.set_cursor_style(CursorStyle::PointingHand, &hitbox);
}
```

### Davranış tipleri

`HitboxBehavior`, bu hitbox'ın altında kalan diğer hitbox'lara ne yapacağını söyler:

- **`Normal`** — Arkadaki hitbox'ları etkilemez; tıklama olayları gerekirse arka tarafa düşmeye devam eder.
- **`BlockMouse`** — Arkadaki mouse, hover, tooltip ve scroll davranışlarını bloke eder. `.occlude()` fluent method'u bu davranışı kullanır (modal overlay'ler, popover backdrop için).
- **`BlockMouseExceptScroll`** — Arkadaki mouse interaction'ları bloke eder ama scroll wheel olayları geçer. `.block_mouse_except_scroll()` bu davranışı kullanır.

### Pointer capture (mouse'u kilitleme)

Resize, sürükleme veya slider gibi etkileşimlerde mouse bazen hitbox bounds'unun dışına çıkar; ancak kullanıcı hâlâ aynı UI öğesi üzerinde işlem yapıyor sayılmalıdır. Pointer capture, mouse hareketlerinin geçici olarak belirli bir hitbox'a kilitlenmesini sağlar:

```rust
window.capture_pointer(hitbox.id);
// drag/resize bittiğinde
window.release_pointer();
```

Capture aktifken ilgili hitbox hovered sayılır; mouse fiziksel olarak bounds dışına çıksa bile event akışı bu hitbox'a yönelir. `window.captured_hitbox()` aktif capture id'sini döndürür; özel UI öğesi debug'ı veya iç içe drag durumu ayrıştırması dışında pratik kodda nadiren kullanılır.

### Autoscroll

Bir scroll container içinde drag yapılırken kenara yaklaşıldığında scroll'un otomatik akmasını sağlar (örn. uzun listenin altına bir öğe sürüklerken liste otomatik kayar):

- `window.request_autoscroll(bounds)` — Drag tarafı, viewport kenarındaki bölge için autoscroll talep eder.
- `window.take_autoscroll()` — Scroll container tarafı talebi alır ve scroll konumunu günceller.

### Cursor stilini ayarlama

- `window.set_cursor_style(style, &hitbox)` — Mouse bu hitbox üzerindeyken kullanılacak cursor.
- `window.set_window_cursor_style(style)` — Pencere genelinde geçerli cursor durumu (hitbox bağımsız).
- `cx.set_active_drag_cursor_style(style, window)` — Aktif drag payload'ı için cursor override (örn. "kabul edilmez" cursor'u).
- `cx.active_drag_cursor_style()` — Mevcut drag cursor override'ını okur.

### Tuzaklar

- **`Hitbox::is_hovered` klavye input modality'de `false` dönebilir.** Kullanıcı klavyeyle gezinirken hover sahte tetiklenmesin diye. Scroll handler yazarken bunun yerine `should_handle_scroll` tercih edilir.
- **Overlay elementi `.occlude()` veya `.block_mouse_except_scroll()` kullanmazsa altındaki butonlar hover/click almaya devam eder.** Modal arkaplanları bu yüzden mouse'u blokelemelidir.
- **Pointer capture release edilmezse** sonraki mouse hareketlerinde yanlış hitbox hovered olarak işaretli kalır; tüm capture'lar `release_pointer()` ile sonlandırılmalıdır (event handler'ın hata yolunda bile).

## 7.5. Tab Sırası ve Klavye Navigasyonu

Kaynaklar: `crates/gpui/src/tab_stop.rs`, `window.rs:397`.

Klavye ile gezinme (Tab/Shift-Tab) her interaktif UI öğesine sırayla odak verebilmek için tasarlanmıştır. Bu sıralama her `FocusHandle` üzerinde tutulan iki bayrakla kontrol edilir: tutamaç Tab tuşunda durak olur mu, ve sırada hangi konumdadır.

```rust
let handle = cx.focus_handle()
    .tab_stop(true)        // Tab tuşuyla durulabilir
    .tab_index(0);         // Sıralama yolunda hangi konuma denk geliyor
```

### Sıralama kuralları

Tab traversal `TabStopMap` içindeki node sırasına göre belirlenir:

1. **Aynı grup içinde `tab_index` küçükten büyüğe** — `tab_index(0)` önce, `tab_index(1)` sonra.
2. **`tab_index` eşitse UI öğesi ağaç sırası (DFS)** — derinlik-öncelikli, yazıldığı sırada.
3. **`tab_stop(false)` olan tutamaç sırada konum tutar ama klavyeyle durak olmaz.** Programatik olarak odaklanabilir, kullanıcı Tab basarak buraya gelemez. Negatif `tab_index` özel olarak "devre dışı" anlamına *gelmez*; yalnızca sıralamada daha erken bir path değeri üretir.

### Grup oluşturmak

İlgili interaktif öğeler bir tab grubu altına alınarak Tab sırasının "alt-akış" gibi davranması sağlanır (örn. dialog içindeki form elemanları). UI öğesi tarafında `.tab_group()` ile grup açılır; grubun kendi sırası gerekiyorsa aynı UI öğesine ek olarak `.tab_index(index)` verilir.

`TabStopMap::begin_group` ve `end_group` ham traversal operasyonlarıdır; uygulama kodu bunları doğrudan çağırmaz. Özel UI öğesi yazılırken düşük seviyeli karşılık `window.with_tab_group(Some(index), |window| { ... })` çağrısıdır; `None` verildiğinde grup açılmadan closure çalıştırılır. Sıradan component kodunda `.tab_group()` fluent API'si tercih edilir.

### Window yardımcıları

- `window.focus_next(cx)` / `window.focus_prev(cx)` — Tab/Shift-Tab sırasında çağrılır; sıralamadaki bir sonraki/önceki tab stop'a geçer.
- `window.focused(cx)` — Şu anda odakta olan odak tutamacı.

### Custom input bileşeni örneği

```rust
div()
    .track_focus(&self.focus_handle)
    .on_action(cx.listener(|this, _: &menu::Confirm, window, cx| { ... }))
    .child(/* ... */)
```

Önemli nokta: `tab_stop(true)` olmayan tutamaç yalnızca programatik olarak odak alır; kullanıcı klavyeyle ulaşamaz. Accessibility ve form akışı açısından klavyeyle kullanılabilir her interaktif UI öğesinin Tab ile ulaşılabilir bir odak tutamacı bulunmalıdır.

## 7.6. Text Input ve IME

IME (Input Method Editor), kullanıcının fiziksel klavyeyle doğrudan üretemediği karakterleri (Çince, Japonca, Korece veya dead-key kullanan diller) girmesine olanak veren işletim sistemi katmanıdır. Kullanıcı bir tuşa basar, işletim sistemi bunu bir veya birkaç tuşluk "composition" sürecine alır, ardından oluşan karakter(ler)i uygulamaya gönderir. Bu süreçte aday pencere (candidate window) gösterilir, marked text alanında ön izleme yapılır ve son halinde metin commit edilir. GPUI bu akışı `InputHandler` trait'i üzerinden uygulamaya bağlar; metin alanı yazılırken bu trait implemente edilir.

Editor benzeri bir metin alanı şunları sağlamalıdır:

- `selected_text_range` — Mevcut seçimin/cursor'un aralığı.
- `marked_text_range` — IME tarafından geçici olarak işaretlenmiş (henüz commit edilmemiş) aralık.
- `text_for_range` — Belirli bir aralıktaki metin (IME aday penceresine gösterilecek bağlam için).
- `replace_text_in_range` — Belirli bir aralığı yeni metinle değiştir.
- `replace_and_mark_text_in_range` — Değiştir ve yeni metni "marked" olarak işaretle.
- `unmark_text` — Mevcut marked text'i normal metne çevir.
- `bounds_for_range` — Bir aralığın ekrandaki bounds'u (IME aday penceresinin konumu için).
- `character_index_for_point` — Ekranda verilen bir noktanın metin içindeki karakter offset'i.
- `accepts_text_input` — Bu UI öğesi şu anda text input alıyor mu (read-only mod kontrolü).

Ham `InputHandler` implementasyonu yazılırken `prefers_ime_for_printable_keys` da override edilebilir; ancak yaygın görünüm yolu olan `EntityInputHandler + ElementInputHandler` ikilisinde bu ayrı bir hook olarak görünmez. Mevcut wrapper `prefers_ime_for_printable_keys` için `accepts_text_input` sonucunu kullanır. IME/keybinding önceliğini `accepts_text_input`'tan bağımsız yönetmek gerekiyorsa doğrudan `InputHandler`'ı implemente eden özel bir handler yazılır.

IME aday penceresinin (composition popup) doğru noktada görüntülenmesi için cursor pozisyonu her değiştiğinde koordinatlar geçersiz kılınmalıdır:

```rust
window.invalidate_character_coordinates();
```

Zed'de form tipi tek satır input gerektiğinde sıfırdan editor yazmak yerine `ui_input::InputField` kullanılır. `InputField` editor'a bağımlı olduğu için `ui` crate'i içinde değildir; ayrı bir `ui_input` crate'inden gelir.

## 7.7. Text Input Handler ve IME Derin Akış

Metin düzenleyen özel bir UI öğesi yazıldığında yalnızca `.on_key_down` ile tuş yakalamak yeterli değildir. IME composition, dead-key dilleri (örn. Almanca'da `^` + `a` = `â`), marked text gösterimi ve aday penceresi konumlandırması için platforma bir `InputHandler` verilmelidir. Bu, işletim sisteminin metin düzenleyiciyle iki yönlü konuşmasını sağlar: platform hangi karakterin girileceğini sorar, uygulama da hangi aralığın seçili olduğunu, marked text aralığını ve cursor bounds'unu bildirir.

### Görünüm tarafı: `EntityInputHandler`

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

### UI öğesi paint sırasında handler'ı bağlama

Bu input handler'ın platform IME katmanına teslim edilmesi, ilgili UI öğesi paint edilirken yapılır:

```rust
window.handle_input(
    &focus_handle,
    ElementInputHandler::new(bounds, view_entity.clone()),
    cx,
);
```

`focus_handle` IME'nin hangi UI öğesi için aktif olduğunu belirler; `bounds` ekrandaki konumdur (aday penceresinin konumlandırılması için), `view_entity` ise asıl metin görünümüdür.

### Kurallar

- **Range değerleri UTF-16 offset'idir** — Rust byte index'iyle (`usize` byte) karıştırılmaz. Aynı string'in UTF-8 ve UTF-16 ofsetleri çok-byte'lı karakterlerde farklıdır.
- **`bounds_for_range` ekran/aday penceresi konumlandırması için doğru absolute bounds döndürmelidir.** Yanlış bounds, IME aday penceresinin yanlış yerde gösterilmesine yol açar.
- **Cursor/selection her hareket ettiğinde** `window.invalidate_character_coordinates()` çağrılır; IME paneli yeni konuma taşınır.
- **`accepts_text_input` `false` döndürdüğünde** platform metin insertion'ını engelleyebilir (read-only mod davranışı).
- **Ham `InputHandler::prefers_ime_for_printable_keys` `true` ise** ASCII olmayan IME aktifken printable tuşlar keybinding sistemine değil önce IME'ye gider. `ElementInputHandler` ile sarılan `EntityInputHandler` kullanıldığında GPUI bu kararı `accepts_text_input` sonucu üzerinden verir; trait üzerinde ayrı bir override noktası yoktur.

### Tuzaklar

- **Sadece `.on_key_down` ile text editor yazılması** IME composition'ı ve dead-key dilleri kırar. Türkçe `^`+`a` → `â`, Almanca `¨`+`u` → `ü`, tüm Asya dilleri composition tabanlıdır; bu akış `InputHandler` olmadan çalışmaz.
- **UTF-16 range'i byte slice'a doğrudan uygulamak** çok byte'lı karakterlerde panic veya yanlış seçim üretir. UTF-16 offset, içeride byte ofsetine dönüştürülür (`str::char_indices()` veya benzeri yardımcı ile).
- **Input handler her frame'de yeniden bağlanır.** Odaktaki UI öğesi paint edilmediği frame'lerde platform handler düşer; bu yüzden metin görünümünün görünür kalması gerekir (örn. scroll edilince ekrandan çıkmış olsa bile).

## 7.8. Keystroke, Modifiers ve Platform Bağımsız Kısayollar

Kaynak: `crates/gpui/src/platform/keystroke.rs`.

GPUI klavye girdisini her platforma özgü ham event olarak değil, **normalize edilmiş** bir model üzerinden ele alır. Bu normalleştirme keymap eşleştirmesi, pending input takibi, IME composition durumu ve kullanıcıya gösterilen kısayol metinlerinin hepsinin aynı tipler üzerinden akmasını sağlar.

### Ana tipler

- **`Keystroke { modifiers, key, key_char }`** — Gerçek girdi.
  - `key` basılan tuşun ASCII karşılığıdır (örn. option-s için `s`).
  - `key_char` o tuşla üretilebilecek karakteri tutar (örn. option-s için `Some("ß")`, cmd-s için `None`).
  - ASCII'ye çevrilemeyen layout'larda `key` yine ASCII yedeği olarak gelir; asıl yazılan karakter `key_char` alanına düşer.
  - Ayrı bir `ime_key` alanı yoktur — composition durumu ayrı bayrakla yönetilir.
- **`KeybindingKeystroke`** — Keymap dosyalarındaki display modifier/key ile gerçek girdi arasında eşleme yapan sarıcı. Aynı binding farklı klavye layout'larında farklı tuşlara denk gelebilir; bu sarıcı, kullanıcıya gösterilen metinle iç eşleştirmeyi ayırır.
- **`InvalidKeystrokeError`** — Parse hatası. Hatanın `Display` çıktısı `gpui::KEYSTROKE_PARSE_EXPECTED_MESSAGE: &str` const'ını şablon olarak kullanır (`platform/keystroke.rs:69`); kullanıcı keymap parser'ında aynı bekleyiş mesajını göstermek için bu sabite bağlanılır.
- **`Modifiers`** — `control`, `alt`, `shift`, `platform`, `function` alanlarını taşır. Hazır constructor'lar ve platform farkları [Modifier yardımcıları ve platform bağımsızlığı](#modifier-yardımcıları-ve-platform-bağımsızlığı) bölümünde listelenir.
- **`AsKeystroke`** — Hem `Keystroke` hem display wrapper'lar üzerinden ortak keystroke erişimi sağlayan küçük trait.
- **`Capslock { on }`** — Platform input snapshot'ında capslock durumunu taşıyan tip.

### Kullanım

```rust
let keystroke = Keystroke::parse("cmd-shift-p")?;     // string → Keystroke
let text = keystroke.unparse();                       // Keystroke → string ("cmd-shift-p")
let handled = window.dispatch_keystroke(keystroke, cx); // pencereye gönder
```

### Modifier yardımcıları ve platform bağımsızlığı

Modifier'lar için hazır constructor'lar mevcuttur: `Modifiers::none()`, `command()`, `windows()`, `super_key()`, `secondary_key()`, `control()`, `alt()`, `shift()`, `function()`, `command_shift()`, `control_shift()`.

- **`command()`, `windows()`, `super_key()` üçü de aynı şeyi yapar**: `Modifiers { platform: true, .. }` üretir. Tek bir `platform` field'ı işletim sistemine göre command (macOS), Windows tuşu (Windows) veya super (Linux) anlamına gelir; bu üç constructor sadece kavramsal vurgu için ayrı isimle export edilmiştir.
- **`secondary_key()` macOS'ta command, Linux/Windows'ta control üretir.** Bu, Zed'de platform bağımsız kısayol yazılırken çoğu durumda doğru seçimdir: macOS'taki Cmd+C, diğer platformlarda Ctrl+C'ye karşılık gelir.
- `modified()`, `secondary()`, `number_of_modifiers()`, `is_subset_of(&other)` input ayrıştırmada (örn. bir keymap binding'i mevcut input'un bir önekiyse?) kullanılır.

### IME ve dispatch

- `Keystroke::is_ime_in_progress()` IME composition sırasında `true` döner; bu durumda dispatch sırası farklı işletilir (composition'ı bozmamak için).
- `window.dispatch_keystroke(...)` test/simülasyon yolunda otomatik olarak `with_simulated_ime()` uygular; doğrudan düşük seviyeli event üretirken IME durumunun ayrıca düşünülmesi gerekir.

### `KeybindingKeystroke` yüzeyi

Keymap editör/normalizer akışlarında kullanılan ek API'ler:

- `KeybindingKeystroke::new_with_mapper(inner, use_key_equivalents, keyboard_mapper)` — Platform keyboard mapper üzerinden display key/modifier üretir.
- `from_keystroke(keystroke)` — Platform mapping uygulamadan sarar.
- Windows-özgü `new(inner, display_modifiers, display_key)` constructor'ı vardır; macOS/Linux build'lerinde bu constructor yoktur.
- `inner()`, `modifiers()`, `key()` getter'ları display ve gerçek keystroke ayrımını saklar. Windows'ta `modifiers()` ve `key()` display değerini döndürebilir; gerçek GPUI girdisi için `inner()` okunur.
- `set_modifiers(...)`, `set_key(...)`, `remove_key_char()`, `unparse()` keybinding editor/normalizer akışında kullanılır. `remove_key_char()` yalnız `inner.key_char = None` yapar; `key` alanını silmez.

### Binding sorguları

- `window.bindings_for_action(&Action)` ve `window.keystroke_text_for(&Action)` — Kullanıcıya gösterilecek kısayol metni için tercih edilir (menüde "Ctrl+S" gibi).
- `cx.all_bindings_for_input(&[Keystroke])` ve `window.possible_bindings_for_input(&[Keystroke])` — Multi-stroke veya prefix binding durumlarında (örn. Vim "g g") hangi binding'lerin eşleşebileceğini sorgular.
- `window.pending_input_keystrokes()` — Henüz tamamlanmamış input zincirini verir (chord başlatıldı ama bitirilmedi).


---
