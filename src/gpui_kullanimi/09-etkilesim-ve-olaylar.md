# Etkileşim ve Olaylar

---

## Klavye Odağı, Odak Kaybı ve Klavye Olayları

Klavye odağı GPUI'de `FocusHandle` ile temsil edilir. Bir view'un odak alıp verebilmesi için kendine ait bir handle tutması ve çizim sırasında bu handle'ı elemente bağlaması gerekir.

```rust
struct Gorunum {
    odak_tutamagi: FocusHandle,
}

impl Gorunum {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            odak_tutamagi: cx.focus_handle(),
        }
    }
}
```

Çizim zincirinde handle'ı element'e bağlarsın; isteğe bağlı olarak `focus-visible` stili eklersin:

```rust
div()
    .track_focus(&self.odak_tutamagi)
    .focus_visible(|stil| stil.border_color(cx.theme().colors().border_focused))
```

Programatik olarak odak vermek için handle'ın kendisini veya `cx.focus_view` çağrısını kullanırsın:

```rust
self.odak_tutamagi.focus(window, cx);
// veya
cx.focus_view(&alt_varlik, window);
```

**Odak sorguları.** Mevcut odak durumunu kontrol etmek için üç temel soru ve üç karşılık gelen metot vardır:

- `focus_handle.is_focused(window)` — handle doğrudan odakta mı?
- `focus_handle.contains_focused(window, cx)` — bu handle veya altındaki bir düğüm odakta mı?
- `focus_handle.within_focused(window, cx)` — bu handle odakta olan düğümün içinde mi?

**Odak olayları.** Odakla ilgili değişimleri dinlemek için ayrı abonelik metotları mevcuttur:

- `cx.on_focus(handle, window, ...)` — handle doğrudan odak aldı.
- `cx.on_focus_in(handle, window, ...)` — handle veya bir alt öğe odak aldı.
- `cx.on_blur(handle, window, ...)` — handle odak kaybetti.
- `cx.on_focus_out(tutamac, window, |gorunum, olay, window, cx| ...)` — handle veya bir alt öğe odak dışına çıktı; geri çağrı view verisini alır ve `FocusOutEvent` içinden odağı kaybeden handle'a (`olay.blurred`) erişebilirsin.
- `window.on_focus_out(tutamac, cx, |olay, window, cx| ...)` — aynı olayın view verisi almayan, daha düşük seviyeli `Window` varyantıdır; sonucu `Subscription` olarak döner.
- `cx.on_focus_lost(window, ...)` — pencere içinde hiçbir handle odakta kalmadığında çalışır.

`WindowFocusEvent::is_focus_in(focus_id)` ve `WindowFocusEvent::is_focus_out(focus_id)`, önceki ve mevcut focus path'lerini karşılaştırır. Bir parent focus handle altındaki çocuk odağa geçerken yalnız path'e yeni giren handle için `is_focus_in`, path'ten çıkan handle için `is_focus_out` anlamlıdır; bu yüzden modal, form grubu veya nested picker gibi alt odak ağacı olan bileşenlerde düz eşitlik kontrolünden daha güvenilir sonuç verir.

**Klavye action akışı.** Tuşların action'a bağlanması birkaç adımdan oluşur; bu adımları her özel kısayol için tekrarlarsın:

1. `actions!(namespace, [ActionA, ActionB])` veya `#[derive(Action)]` + `#[action(...)]` ile action tanımı yaparsın.
2. Element ağacında `.key_context("context-name")` belirtirsin; bu sayede action yalnızca uygun bağlamda yönlendirilir.
3. `cx.bind_keys([KeyBinding::new("cmd-k", ActionA, Some("context-name"))])` ile kısayolu kaydedersin.
4. Dinleyici için `.on_action(...)`, `.capture_action(...)` veya `cx.on_action(...)`'i kullanırsın.

**Olay yayılımı.** GPUI olay yayılımı varsayılan olarak yukarı doğru ilerler. İki yardımcı bu davranışı kontrol eder:

- Fare ve tuş olay dinleyicileri olayı varsayılan olarak yukarıya iletir.
- `cx.stop_propagation()`, arkadaki veya üstteki dinleyicilere olayın ulaşmasını keser.
- Action `bubble` aşamasında dinleyiciler varsayılan olarak yayılımı durdurur; gerekirse `cx.propagate()` ile devam ettirebilirsin.

## Fare, Sürükle-Bırak ve Hitbox

![Hitbox ve Sürükle-Bırak State Machine](assets/hitbox-surukle-birak.svg)

Element seviyesindeki etkileşim API'leri tek bir fluent zincir içinde toplanır; doğru metodu seçmek için önce etkileşimin hangi sınıfa girdiğini ayırırsın:

- **Tıklama ve temel fare hareketi:** `.on_click(...)`, mouse down/up aynı hedefte eşleştiğinde `ClickEvent` üretir; buton gibi komut yüzeylerinde bunu kullanırsın. `.on_mouse_down(...)`, `.on_mouse_up(...)` ve `.on_mouse_move(...)` doğrudan fare olaylarını dinler; sürükleme başlatma, özel basılı durum veya anlık imleç takibi gerektiğinde seçilir.
- **Dışarı tıklama/kapatma akışı:** `.on_mouse_down_out(...)` ve `.on_mouse_up_out(...)`, fare olayı element hitbox'ının dışında gerçekleştiğinde capture aşamasında çalışır. Popover, menü veya modal dışına tıklanınca `DismissEvent` yaymak için bu aile kullanılır.
- **Kaydırma ve gesture:** `.on_scroll_wheel(...)`, hitbox kaydırma alabiliyorsa scroll olayını dinler; düz hover kontrolünden daha güvenilirdir. `.on_pinch(...)`, trackpad pinch gibi yakınlaştırma gesture'larını yakalar.
- **Sürükleme ve bırakma:** `.on_drag_move::<T>(...)`, sürükleme element sınırı dışına çıksa bile aynı tipteki aktif drag boyunca hareket bilgisi verir; resize veya split handle gibi klasik drop olmayan sürüklemelerde kullanılır. `.drag_over::<T>(...)` kabul edilebilir sürükleme hedefi üstündeyken geçici stil üretir; `.can_drop(...)` hedefin bırakmayı kabul edip etmeyeceğine karar verir; `.on_drop::<T>(...)` başarılı bırakma tamamlandığında çalışır.
- **Arkayı engelleme ve imleç:** `.occlude()` arkadaki fare etkileşimlerini kapatır; scroll'un arkaya geçmesi gereken üst katmanlarda `.block_mouse_except_scroll()` daha doğru seçimdir. `.cursor_pointer()` hazır işaretçi stilini verir; `.cursor(...)` özel `CursorStyle` gerektiğinde kullanılır.

Pencere kontrol hitbox'ı istiyorsan fluent API üzerinden işaretlersin:

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
```

Özel yeniden boyutlandırma ve imleç davranışı için `canvas` ile hitbox eklemek, Zed'deki istemci tarafı pencere süslemesi (`client decoration`) deseninin tipik bir örneğidir:

```rust
canvas(
    |sinirlar, window, _cx| {
        window.insert_hitbox(sinirlar, HitboxBehavior::Normal)
    },
    |_sinirlar, isabet_kutusu, window, _cx| {
        window.set_cursor_style(CursorStyle::ResizeLeftRight, &isabet_kutusu);
    },
)
```

Burada `canvas` imzası `prepaint: FnOnce(Bounds<Pixels>, &mut Window, &mut App) -> T` ve `paint: FnOnce(Bounds<Pixels>, T, &mut Window, &mut App)` şeklindedir. İkinci closure'da ilk pozisyonel argüman `bounds`'tur (kullanılmıyorsa `_bounds`), ikinci argüman ise prepaint'in döndürdüğü değerdir (örnekteki `hitbox`). `set_cursor_style` hitbox'a referans aldığı için `&hitbox` şeklinde geçirirsin.

## Olay Tipleri ve PlatformInput Modeli

Element listener'ları çoğu zaman olay tipini senin yerine seçer; yine de özel element, test olayı veya platform input çevirimi yazarken GPUI olay ailesini bilmen gerekir.

**Trait sınıfları.** `InputEvent`, `KeyEvent`, `MouseEvent` ve `GestureEvent` olayların ortak davranışlarını ayırır. Klavye olayları `to_platform_input()` ile `PlatformInput` değerine dönüşebilir; fare ve gesture olayları da platformdan gelen ham girdiyi GPUI dispatch ağacına taşıyan aynı modelin parçasıdır. Uygulama kodunda bu trait'leri implement etmek yerine `.on_key_down(...)`, `.on_mouse_down(...)`, `.on_scroll_wheel(...)` gibi element metotlarını kullanırsın.

**Klavye olayları.** `KeyDownEvent`, `KeyUpEvent`, `ModifiersChangedEvent`, `KeyboardClickEvent`, `KeyboardButton` ve `PlatformInput` klavye akışını tanımlar. `ModifiersChangedEvent` doğrudan `Modifiers`'a deref eder; bu yüzden `olay.secondary()` gibi çağrılar çalışır. Kısayol yönlendirmesi gerekiyorsa ham `KeyDownEvent` yerine action/keymap modelini tercih edersin; metin girdisi gerekiyorsa IME için `InputHandler` yoluna geçersin.

**Fare ve gesture olayları.** `MouseDownEvent`, `MouseUpEvent`, `MouseMoveEvent`, `MouseClickEvent`, `MouseExitEvent`, `MousePressureEvent`, `MouseButton`, `PressureStage`, `ScrollWheelEvent`, `ScrollDelta`, `PinchEvent`, `TouchPhase` ve `NavigationDirection` işaretçi ve hareket girdilerini taşır. `MouseDownEvent::is_focusing()` ve `MouseUpEvent::is_focusing()` sol tuş akışının odağı taşıyıp taşımayacağını açıkça söyler; `MouseMoveEvent::dragging()` ise hareket sırasında bir mouse button basılı mı sorusunu cevaplar. `ClickEvent` tıklama sayısını ve basma/bırakma eşleşmesini temsil eder; `.on_click(...)` bunu üretir. `ClickEvent::standard_click()`, sol mouse veya klavye click yolunu; `ClickEvent::is_right_click()` ve `ClickEvent::is_middle_click()` alternatif mouse butonlarını; `ClickEvent::is_keyboard()` klavye kaynaklı click'i; `ClickEvent::first_focus()` ise mouse click'in ilk odak kazandıran click olup olmadığını ayırır. `ScrollDelta::pixel_delta(line_height)` satır tabanlı scroll değerini piksele çevirir; `ScrollDelta::precise()` trackpad gibi hassas piksel girdisiyle satır tabanlı wheel girdisini ayırır; `coalesce(...)` aynı yöndeki delta'ları birleştirir.

**Modifier asimetrisi.** `ModifiersChangedEvent`, `ScrollWheelEvent`, `PinchEvent` ve `MouseExitEvent` `Deref<Target = Modifiers>` taşır; bu dört olayda `olay.secondary()` doğrudan çalışır. `MouseDownEvent`, `MouseUpEvent` ve `MouseMoveEvent` ise deref etmez, yalnız `olay.modifiers` alanını verir. Bu farkı callback yazarken net tutarsın; fare basma/taşıma olaylarında `olay.modifiers.secondary()` biçimini kullanırsın.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `AsKeystroke` | `as_keystroke` | `Keymap` ve dispatch yardımcılarının `Keystroke` benzeri girdileri tek arayüzden okumasını sağlar. |
| `KeybindingKeystroke` | fiziksel/karakter eşleşme verisi | Keymap tarafında gerçek basılan tuş ile beklenen binding arasındaki karşılaştırmayı taşır. |
| `KeyDownEvent`, `KeyUpEvent` | `keystroke`, `is_held`, `prefer_character_input`; release keystroke | Platform klavye basma/bırakma olaylarıdır; action dispatch veya metin girdisi katmanına çevrilir. |
| `ModifiersChangedEvent` | `modifiers`, `capslock`, `Deref<Target = Modifiers>` | Modifier state değişimini taşır; `olay.secondary()` gibi `Modifiers` metotları doğrudan çağrılabilir. |
| `PlatformInput` | `KeyDown`, `KeyUp`, `ModifiersChanged`, `MouseDown`, `MouseUp`, `MouseMove`, `MousePressure`, `MouseExited`, `ScrollWheel`, `Pinch`, `FileDrop` | Platformdan gelen ham keyboard, mouse, gesture ve dosya bırakma olaylarını tek enum altında dispatch ağacına taşır. |
| `ClickEvent` | `Mouse`, `Keyboard`, `modifiers`, `position`, `is_right_click`, `standard_click`, `first_focus`, `click_count` | `.on_click(...)` için mouse ve klavye click kaynaklarını tek enum altında toplar. |
| `MouseButton` | `Left`, `Right`, `Middle`, `Navigate(Back/Forward)`, `all` | Fare butonu ve navigation button modelidir. |
| `MousePressureEvent`, `PressureStage` | `pressure`, `stage`, `position`, `modifiers`; `Zero`, `Normal`, `Force` | Force-sensitive trackpad basınç bilgisini taşır. |
| `ScrollDelta` | `Pixels`, `Lines`, `precise`, `pixel_delta`, `coalesce` | Scroll wheel/trackpad delta'sını piksel veya satır olarak temsil eder. |
| `UTF16Selection` | UTF-16 tabanlı seçim aralığı | Platform text input/IME köprüsünde seçili metin aralığını taşır. |
| `EntityInputHandler`, `ElementInputHandler` | view input handler trait'i ve element sarmalayıcısı | IME, printable key ve seçili metin sınırı gibi soruları view'ın `InputHandler` uygulamasına bağlar. |
| `FocusOutEvent` | `blurred: WeakFocusHandle` | Focus dışına çıkış aboneliğinde odağı kaybeden handle'ın zayıf referansını verir. |
| `actions` | macro | Veri taşımayan action unit struct'larını ve kayıt altyapısını üretir; olay/kısayol sisteminin kısa tanım yoludur. |

**Tuzaklar.** Platform input modeline inerken dikkat edeceğin noktalar:

- Metin girişi için ham `KeyDownEvent` yeterli değildir; IME ve dead-key dilleri için `InputHandler` gerekir.
- `ClickEvent` yalnız mouse down ve mouse up aynı tıklama hedefinde kaldığında oluşur; sürüklemeye dönen akışta click listener bekleme.
- Scroll ve pinch olaylarında modifier bilgisini doğrudan olay üzerinden okuyabilirsin, ama mouse move/down/up için aynı kısayol geçerli değildir.

## Sürükleme ve Bırakma İçeriği Üretimi

GPUI'da sürükleme sırasında, sürüklenen elementin yerine ayrı bir hayalet (`ghost`) view oluşur ve fare ile birlikte bu view hareket eder:

```rust
div()
    .id("suruklenebilir")
    .on_drag(yuk.clone(), |yuk, fare_kaymasi, _window, cx| {
        cx.new(|_| HayaletGorunum::yuk_icin(yuk.clone(), fare_kaymasi))
    })
```

İmza şöyledir:

```rust
fn on_drag<T, W>(
    self,
    deger: T,
    kurucu: impl Fn(&T, Point<Pixels>, &mut Window, &mut App) -> Entity<W> + 'static,
) -> Self
where
    T: 'static,
    W: 'static + Render;
```

- `deger: T` — sürükleme yükünün (`payload`) tipidir; alıcı tarafta `on_drop::<T>` ile aynı tipe bağlanır.
- `constructor` — her sürükleme başlangıcında hayalet view üreten yapıcıdır; fare uzaklığını yüke göre konumlandırır.
- `W: Render` — hayaletin kendi entity'sidir; standart çizim gibi davranır.

**Bırakma tarafı.** Alıcı element kabul edilebilirlik kontrolünü, stilini ve dinleyicisini ayrı ayrı tanımlar:

```rust
div()
    .drag_over::<SuruklemeYuku>(|stil, _yuk, _window, _cx| {
        stil.bg(rgb(0xeeeeee))
    })
    .can_drop(|yuk, window, cx| {
        yuk
            .downcast_ref::<SuruklemeYuku>()
            .is_some_and(|yuk| yuk.uyumlu_mu(window, cx))
    })
    .on_drop::<SuruklemeYuku>(cx.listener(|gorunum, yuk: &SuruklemeYuku, _window, cx| {
        gorunum.kabul_et(yuk.clone());
        cx.notify();
    }))
```

**API.** Sürükle-bırak akışı için kullandığın başlıca metotlar şunlar:

- `.on_drag::<T, W>(deger, yapici)` — sürüklemeyi başlatır.
- `.drag_over::<T>(|style, payload, window, cx| -> StyleRefinement)` — hover sırasında uygulanan stil refinement'ı.
- `.can_drop(|payload: &dyn Any, window, cx| -> bool)` — bırakmanın kabul edilip edilmeyeceğine karar verir. Tip kontrolü için `downcast_ref::<T>()`'i kullanırsın.
- `.on_drop::<T>(listener)` — bırakma tamamlandığında çalışır.
- `.on_drag_move::<T>(listener)` — sürükleme süresince fare konumu bilgisi verir.
- `cx.has_active_drag()` — o an uygulamada (herhangi bir element üzerinde) bir sürükleme sürüyor mu, `true`/`false` döner. Asıl kullanımı **davranışı sürükleme durumuna göre kapılamaktır**: çakışan bir etkileşimi durdurmak (ör. araya bir drag girince scrollbar sürüklemesini iptal etmek), süren bir drag varken ikinci bir drag başlatmamak ya da yalnızca sürükleme sırasında bırakma bölgelerini vurgulamak için bakarsın.
- `cx.stop_active_drag(window)` — süren sürüklemeyi iptal eder: aktif drag varsa temizler, pencereyi yeniden çizime işaretler ve `true` döner; yoksa `false`. Tipik yeri `Cancel`/Escape akışıdır ("önce sürüklemeyi iptal et, yoksa sıradaki iptal davranışına geç"). İmleç stilini okuma/değiştirme aşağıda "İmleç" başlığındadır.

**Harici sürükleme.** Dosya sisteminden sürükleyip bırakma akışı için `FileDropEvent` ve `ExternalPaths` tipleri kullanılır. Platform `FileDropEvent::Entered/Pending/Submit/Exited` üretir; `Window::dispatch_event` bu olayları dahili `active_drag` durumuna ve `ExternalPaths` yüküne çevirir. UI tarafında normal sürükle-bırak API'siyle yakalarsın:

```rust
div()
    .on_drag_move::<HariciYollar>(cx.listener(|gorunum, olay, window, cx| {
        let yollar = olay.drag(cx).paths();
        gorunum.harici_birakmayi_onizle(yollar, olay.bounds, window, cx);
    }))
    .on_drop(cx.listener(|gorunum, yollar: &HariciYollar, window, cx| {
        gorunum.harici_yollari_birakmayi_isle(yollar, window, cx);
    }))
```

`ExternalPaths::paths()` `&[PathBuf]` döner. Hayalet view, dosya ikonları olarak platform tarafından çizilir; GPUI tarafındaki `Render for ExternalPaths` bilerek `Empty` döndürür.

**Tuzaklar.** Sürükle-bırak yazarken karşılaştığın yaygın hatalar:

- Sürüklenen tip `T: 'static` olmalıdır; ödünç alma süresi (`lifetime`) taşıyan tipler kabul edilmez.
- Aynı element üzerinde `on_drag`'i iki kez çağırdığında `panic` oluşur ("calling on_drag more than once on the same element is not supported").
- Hayalet view her sürüklemede yeni bir `cx.new(...)` ile yaratılır; yapıcı içinde yan etkiden kaçınman gerekir.
- `can_drop` `false` döndüğünde `drag_over` ve `group_drag_over` stilleri uygulanmaz, `on_drop` çağrılmaz. Kabul edilmeyen hedef için ayrı bir görsel geri bildirim göstereceksen `on_drag_move`'u kullanırsın.

## Hitbox, İmleç, İşaretçi Yakalama ve Otomatik Kaydırma

Hitbox, fare çarpışma testinin (`hit-test`) ve imleç davranışının temelidir. Element dinleyicileri çoğu zaman hitbox'ı arka planda kurar; bu API doğrudan özel `canvas` veya özel element yazarken devreye girer.

```rust
let isabet_kutusu = window.insert_hitbox(sinirlar, HitboxBehavior::Normal);
if isabet_kutusu.is_hovered(window) {
    window.set_cursor_style(CursorStyle::PointingHand, &isabet_kutusu);
}
```

**Davranış tipleri.** Hitbox'ın arka planda kalan başka hitbox'larla ilişkisini `HitboxBehavior` ile ifade edersin:

- `HitboxBehavior::Normal` — arkadaki hitbox'ları etkilemez.
- `HitboxBehavior::BlockMouse` — arkadaki fare, hover, ipucu (`tooltip`) ve scroll hitbox davranışlarını engeller. `.occlude()` bu davranışı kullanır.
- `HitboxBehavior::BlockMouseExceptScroll` — arkadaki fare etkileşimini engeller ama scroll'un geçmesine izin verir. `.block_mouse_except_scroll()` bu davranışı kullanır.

**İşaretçi yakalama.** Sürükleme veya yeniden boyutlandırma gibi senaryolarda fare element sınırlarının dışına çıksa bile olayları almaya devam etmek için işaretçi yakalama (`pointer capture`) kullanırsın:

```rust
window.capture_pointer(isabet_kutusu.id);
// sürükleme/yeniden boyutlandırma bittiğinde
window.release_pointer();
```

Yakalama aktifken ilgili hitbox üzerinde durulmuş (`hovered`) sayılır. Yeniden boyutlandırma tutamacı ve sürükleme etkileşimlerinde fare element sınırlarının dışına çıksa bile hareketi takip edebilirsin. `window.captured_hitbox()` aktif yakalama id'sini döndürür; özel element hata ayıklaması veya iç içe sürükleme verisini ayrıştırma dışında genelde kullanmazsın.

**Otomatik kaydırma.** Sürükleme sırasında görünür alanın kenarına yaklaşıldığında otomatik kaydırma talep etmek için iki yardımcı vardır:

- `window.request_autoscroll(bounds)` — sürükleme sırasında görünür alan kenarına yakın bölge için otomatik kaydırma talep eder.
- `window.take_autoscroll()` — scroll kapsayıcısı tarafında bu talebi tüketir.

**İmleç.** İmleç stilini hitbox veya pencere bağlamında ayarlarsın:

- `window.set_cursor_style(style, &hitbox)` — hitbox üzerinde durulmuşsa imleç stilini ayarlar.
- `window.set_window_cursor_style(style)` — pencere genelindeki imleç durumunu ayarlar.
- `cx.set_active_drag_cursor_style(style, window)` / `cx.active_drag_cursor_style()` — süren bir sürüklemenin imlecini değiştirir / okur. Sürükleme imleci başta sürüklenen elementin kendi `.cursor(...)` stilinden gelir; sürükleme sürerken hedefe göre güncellersin: geçerli hedefte `CursorStyle::DragCopy`, geçersizde `CursorStyle::OperationNotAllowed` vererek "buraya bırakırsan ne olur" geri bildirimini verirsin. Drag aktif değilken `set_active_drag_cursor_style` `false` döner ve bir şey yapmaz.

**Tuzaklar.** Hitbox ve imleç tarafında dikkat edeceğin noktalar:

- `Hitbox::is_hovered`, klavye girdi kipi sırasında `false` dönebilir; scroll dinleyicisi yazarken `should_handle_scroll`'u tercih edersin.
- Üst katman elementleri `.occlude()` kullanmazsa arkadaki butonlar hover ve tıklama almaya devam edebilir.
- İşaretçi yakalama serbest bırakılmadığında sonraki fare hareketlerinde yanlış hitbox üstte kalabilir.

## Tab Sırası ve Klavye Navigasyonu

Tab navigasyonunu `FocusHandle` üzerindeki iki bayrak yardımıyla kontrol edersin; ikisini de fluent zincirde okursun:

```rust
let tutamac = cx.focus_handle()
    .tab_stop(true)        // Tab tuşuyla durulabilir
    .tab_index(0);         // Sıralama yoluna katılır
```

**Sıralama kuralları.** Tab gezinme sırası, `TabStopMap` içindeki düğüm sıralamasına göre belirlenir:

1. Aynı grup içinde `tab_index` küçükten büyüğe sıralanır.
2. `tab_index` eşit olduğunda element ağaç sırası (DFS) belirleyicidir.
3. `tab_stop(false)` olan handle, sıradaki konumunu korur ama klavyeyle durak olmaz. Negatif `tab_index` özel olarak "devre dışı" anlamına gelmez; yalnızca sıralamada daha erken bir yol değeri üretir.

**Gruplar.** Bir grup tanımlamak için element tarafında `.tab_group()` kullanırsın; grubun sırası gerekiyorsa aynı elemente `.tab_index(index)` verirsin. `TabStopMap::begin_group` ve `end_group`, gezinme algoritmasının iç operasyonlarıdır; uygulama kodunda doğrudan çağırmazsın.

Düşük seviyeli karşılık `window.with_tab_group(Some(index), |window| ...)` çağrısıdır; `None` verirsen grup açılmadan closure çalışır. Normal bileşen kodunda `.tab_group()` fluent API'sini tercih edersin.

**`Window` üzerindeki yardımcılar.** Tab ve Shift-Tab davranışı pencere üzerinden yapılır:

- `window.focus_next(cx)` / `window.focus_prev(cx)` — Tab veya Shift-Tab geldiğinde çağırırsın.
- `window.focused(cx)` — o anki odak handle'ını verir.

**Özel girdi bileşeni.** Tab akışına dahil olacak özel bir girdi (`input`) bileşeni için:

```rust
div()
    .track_focus(&self.odak_tutamagi)
    .on_action(cx.listener(|gorunum, _: &menu::Confirm, window, cx| { ... }))
    .child(/* ... */)
```

`tab_stop(true)` olmadan handle yalnızca programatik olarak odak alır; klavyeyle ulaşılamaz. Erişilebilirlik ve form akışı için her interaktif elementin bir handle'a sahip olması beklenir.

## Metin Girdisi ve IME

Platform IME entegrasyonu `InputHandler` üzerinden çalışır. Düzenleyici benzeri metin alanlarının sağladığı metotlar üç soruya cevap verir: hangi metin seçili, IME hangi aralığı oluşturuyor ve platform aday penceresini nereye koymalı?

- `selected_text_range(ignore_disabled_input, ...)`, kullanıcının mevcut seçimini UTF-16 aralığı olarak döndürür. Seçim yoksa imleç konumunu sıfır uzunluklu aralıkla temsil edersin; metin girdisi devre dışıysa `ignore_disabled_input` kararını kendi bileşen politikanla birlikte ele alırsın.
- `marked_text_range(...)`, IME'nin henüz kesinleşmemiş işaretli metin aralığını verir. Japonca, Korece veya Çince gibi bileşimli girişlerde aday metin bu aralıkta yaşar.
- `text_for_range(range_utf16, adjusted_range, ...)`, platformun istediği UTF-16 aralığındaki metni döndürür. Aralık bileşenin gerçek sınırlarına uydurulursa `adjusted_range` ile düzeltilmiş aralığı bildirirsin.
- `replace_text_in_range(range, text, ...)`, kesinleşmiş metni seçili veya verilen aralığa yazar. Normal karakter ekleme ve paste akışı bu yoldan gelir.
- `replace_and_mark_text_in_range(range, new_text, new_selected_range, ...)`, yeni metni yazar ve aynı anda IME bileşim durumu olarak işaretler. Aday seçimi sürerken metin görünür olur ama henüz kalıcı seçim gibi ele alınmaz.
- `unmark_text(...)`, IME bileşim durumunu temizler; aday metin kesinleştiğinde veya iptal edildiğinde çağrılır.
- `bounds_for_range(range_utf16, ...)`, verilen UTF-16 aralığının ekran koordinatlarındaki dikdörtgenini döndürür. IME aday penceresinin imlecin yanında kalması buna bağlıdır.
- `character_index_for_point(point, ...)`, ekran noktasını UTF-16 karakter ofsetine çevirir. Platformun tıklama veya aday konumu sorgularında kullanılır.
- `accepts_text_input(...)`, bu handler'ın o anda metin eklemeyi kabul edip etmediğini söyler. `false` döndüğünde platform printable key akışını metin olarak içeri sokmayabilir.

Ham `InputHandler` uygulaması yazarken ayrıca `prefers_ime_for_printable_keys`'i üzerine yazabilirsin. Bununla birlikte yaygın view yolu olan `EntityInputHandler` + `ElementInputHandler` ikilisinde bu ayrı bir kanca (`hook`) değildir; mevcut sarmalayıcı, `prefers_ime_for_printable_keys` sorusunu `accepts_text_input` sonucunu kullanarak yanıtlar. IME ve kısayol önceliğinin `accepts_text_input`'tan bağımsız yönetilmesi gerekiyorsa doğrudan `InputHandler` uygulayan özel bir dinleyici yazarsın.

IME aday penceresinin doğru konumda kalması için imleç hareketinden sonra:

```rust
window.invalidate_character_coordinates();
```

Zed'de form tipindeki tek satırlık girdi için doğrudan düzenleyici yazmak yerine `ui_input::InputField`'i kullanırsın. Bu crate, düzenleyiciye (`editor`) bağlı olduğu için `ui` içinde değildir.

**`ui_input` genel yüzeyi.** Genel API üzerinde aşağıdaki öğeler bulunur:

- `pub use input_field::*`; ana bileşen `InputField`.
- `InputField::new(window, cx, placeholder_text)`, tek satırlık bir düzenleyici nesnesi ister ve yer tutucuyu (`placeholder`) hemen düzenleyiciye yazar.
- Builder ve metot zinciri: `.start_icon(IconName)`, `.label(...)`, `.label_size(LabelSize)`, `.label_min_width(Length)`, `.tab_index(isize)`, `.tab_stop(bool)`, `.masked(bool)`, `.is_empty(cx)`, `.editor()`, `.text(cx)`, `.clear(window, cx)`, `.set_text(text, window, cx)`, `.set_masked(masked, window, cx)`.
- `InputFieldStyle`, `pub` bir struct olarak görünür ancak alanları private'dır; dışarıdan stil üzerine yazma sözleşmesi değil, çizim içi tema anlık görüntüsüdür.
- `ErasedEditor` trait'i düzenleyici köprüsüdür; `text`, `set_text`, `clear`, `set_placeholder_text`, `move_selection_to_end`, `set_masked`, `focus_handle`, `subscribe`, `render`, `as_any` metotlarını içerir.
- `ErasedEditorEvent::{BufferEdited, Blurred}`, picker veya arama gibi üst bileşenlerin düzenleme ve odak kaybı akışını dinlemesi için yayınlanır.
- `ERASED_EDITOR_FACTORY: OnceLock<fn(&mut Window, &mut App) -> Arc<dyn ErasedEditor>>`, düzenleyici crate'i tarafından kurulur. Zed'de `editor` crate'i init akışında bu fabrika, `Editor::single_line(window, cx)` döndüren `ErasedEditorImpl` ile atanır. Fabrika atanmamışken `InputField::new` `panic` üretir; bu yüzden uygulama init sırasında, düzenleyici kurulumu tamamlandıktan sonra `InputField` üretimine güvenmen gerekir.

## Metin Girdisi Dinleyicisi ve IME Derin Akışı

Metin düzenleyen özel bir element yazarken yalnızca tuş olayı dinlemek yeterli değildir. IME, ölü tuş (`dead key`), işaretli metin (`marked text`) ve aday penceresi için platforma `InputHandler` sağlaman gerekir.

**View tarafı.** Görece geniş bir trait yüzeyi vardır; sık kullanılan metotları şu şekilde uygularsın:

```rust
impl EntityInputHandler for EditorBenzeriGorunum {
    fn selected_text_range(
        &mut self,
        devre_disi_girdiyi_yoksay: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<UTF16Selection> {
        self.secim_utf16(devre_disi_girdiyi_yoksay, window, cx)
    }

    fn marked_text_range(
        &self,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<Range<usize>> {
        self.isaretli_aralik_utf16(window, cx)
    }

    fn unmark_text(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        self.isaretli_metni_temizle(window, cx);
    }

    // text_for_range, replace_text_in_range,
    // replace_and_mark_text_in_range, bounds_for_range,
    // character_index_for_point da uygulanır.
}
```

Element çizimi sırasında dinleyiciyi pencereye kaydedersin:

```rust
window.handle_input(
    &odak_tutamagi,
    ElementInputHandler::new(sinirlar, gorunum_varligi.clone()),
    cx,
);
```

**Kurallar.** IME entegrasyonunda sıkça gözden kaçan noktalar şunlar:

- Aralık (`Range`) değerleri UTF-16 ofsetidir; Rust byte index'iyle karıştırma.
- `bounds_for_range`, ekran veya aday penceresi konumlandırması için doğru mutlak sınırları döndürmelidir.
- İmleç veya seçim hareketinden sonra `window.invalidate_character_coordinates()` çağırırsın; aksi halde IME paneli yeni konuma taşınmaz.
- `accepts_text_input` `false` olduğunda platformun metin eklemesi engellenebilir.
- Ham `InputHandler::prefers_ime_for_printable_keys` `true` olduğunda, ASCII dışı IME aktifken yazdırılabilir tuşlar kısayoldan önce IME'ye gider. `ElementInputHandler` sarmalı `EntityInputHandler` için GPUI bu kararı `accepts_text_input` üzerinden verir; trait'te ayrı bir üzerine yazma noktası yoktur.
- Pencere ekran karesi geçişinde platform girdi dinleyicisi `Vec<Option<_>>` slot'ları `.pop()` ile kısaltılmaz; `.take()` ile boş slot bırakılır; bir sonraki ekran karesinde aynı slot'a geri yerleştirilir. `reuse_paint` önbelleğindeki `paint_range` indeksleri bu yüzden sabit kalır. Özel düşük seviyeli pencere veya ekran karesi kodu yazarken girdi dinleyicisi dizisinin uzunluğunu, indeks önbelleği varken değiştirme.

**Tuzaklar.** IME ile çalışırken sık yapılan hatalar:

- Yalnızca `.on_key_down` ile metin düzenleyici yazmak, IME ve ölü tuşlu (`dead key`) dillerde bozulur.
- UTF-16 aralığını doğrudan byte dilimine uygulamak, çok byte'lı karakterlerde `panic` ya da yanlış seçim üretir.
- Girdi dinleyicisi ekran karesine bağlıdır; odaktaki element çizilmediğinde platform girdi dinleyicisi de düşer.

## Keystroke, Modifiers ve Platform Bağımsız Kısayollar

`gpui` crate'i, klavye girdisinin normalize edilmiş modelini içerir. Keymap yalnızca action bağlama değildir; tamamlanmamış girdi, IME durumu ve gösterim metni de bu tiplerle taşınır.

**Ana tipler.** Klavye dünyasını ifade eden tipler birbirini destekleyecek şekilde tasarlanmıştır:

- `Keystroke { modifiers, key, key_char }` — gerçek tuş vuruşu. `key`, basılan tuşun ASCII karşılığıdır (örneğin `option-s` için `s`); `key_char` o tuşla üretilebilecek karakteri tutar (`option-s` için `Some("ß")`, `cmd-s` için `None`). ASCII'ye çevrilemeyen düzenlerde `key` yine ASCII karşılığı olur; asıl yazılan karakter `key_char`'a düşer. Ayrı bir `ime_key` alanı yoktur.
- `KeybindingKeystroke` — kısayol dosyalarında görünen görsel `modifier`/`key` ile eşleşme için kullandığın sarmalayıcı tip.
- `InvalidKeystrokeError` — ayrıştırma hatası. Hatanın `Display` çıktısı, `gpui::KEYSTROKE_PARSE_EXPECTED_MESSAGE: &str` sabitini şablon olarak kullanır (`platform/keystroke`); kullanıcı keymap ayrıştırıcısında aynı beklenti cümlesinin gösterilmesi için bu sabite bağlanırsın.
- `Modifiers` — `control`, `alt`, `shift`, `platform`, `function` alanları.
- `AsKeystroke` — hem `Keystroke` hem de görsel sarmalayıcılar üzerinden ortak keystroke erişimi sağlayan küçük trait.
- `Capslock { on }` — platform girdi anlık görüntüsünde Caps Lock durumunu taşır.

Tipik kullanım, ayrıştırma, geri biçimleme ve yönlendirme zincirinde görünür:

```rust
let tus_vurusu = Keystroke::parse("cmd-shift-p")?;
let metin = tus_vurusu.unparse();
let islendi_mi = window.dispatch_keystroke(tus_vurusu, cx);
```

**Modifier yardımcıları.** Sık kullanılan modifier kombinasyonları için yapıcı fonksiyonlar mevcuttur:

- `Modifiers::none()`, `command()`, `windows()`, `super_key()`, `secondary_key()`, `control()`, `alt()`, `shift()`, `function()`, `command_shift()`, `control_shift()`.
- `command()`, `windows()` ve `super_key()` aslında aynı işi yapar: `Modifiers { platform: true, .. }` üretir. Tek bir `platform` alanı, işletim sistemine göre command (macOS), windows (Windows) veya super (Linux) anlamına gelir; bu üç yapıcı fonksiyon yalnızca kavramsal vurgu için farklı isimlerle dışa aktarılır.
- `secondary_key()`, macOS'ta command, Linux ve Windows'ta control üretir; Zed'de platformdan bağımsız kısayol yazarken çoğu durumda doğru seçim budur.
- `modified()`, `secondary()`, `number_of_modifiers()`, `is_subset_of(&other)`, girdi ayrıştırmada kullanırsın.

**IME.** Bileşimsel girdi sırasında özel bayraklar devreye girer:

- `Keystroke::is_ime_in_progress()` — IME bileşim (`composition`) sırasında `true` döner.
- `window.dispatch_keystroke(...)`, test ve simülasyon yolunda `with_simulated_ime()` uygular; doğrudan düşük seviyeli olay üretirken IME durumunu ayrıca düşünmen gerekir.

**`KeybindingKeystroke` yüzeyi.** Görsel ve gerçek keystroke ayrımı bu sarmalayıcı üzerinden yapılır:

- `KeybindingKeystroke::new_with_mapper(inner, use_key_equivalents, keyboard_mapper)` — platform klavye eşleyicisi üzerinden görsel `key` ve `modifier` üretir. `from_keystroke(keystroke)`, platform eşlemesi yapmadan sarar. Windows'ta `new(inner, display_modifiers, display_key)` yapıcısı da vardır; macOS ve Linux derlemelerinde bu yapıcı bulunmaz.
- `inner()`, `modifiers()`, `key()` okuyucuları (`getter`), görsel ile gerçek keystroke ayrımını saklar. Windows'ta `modifiers()` ve `key()` görsel değeri döndürebilir; gerçek GPUI girdisi için `inner()`'ı okursun.
- `set_modifiers(...)`, `set_key(...)`, `remove_key_char()` ve `unparse()`'ı, kısayol düzenleyici veya normalize edici akışında kullanırsın. `remove_key_char()` yalnızca `inner.key_char = None` yapar; `key` alanına dokunmaz.

**Kısayol sorguları.** Kullanıcıya gösterilecek kısayol metni ve aktif girdi zinciri için `window` üzerinde yardımcılar mevcuttur:

- `window.bindings_for_action(&Action)` ve `window.keystroke_text_for(&Action)`'ı, kullanıcıya gösterilecek kısayol metni için tercih edersin.
- `cx.all_bindings_for_input(&[Keystroke])` ve `window.possible_bindings_for_input(&[Keystroke])`'i, çoklu vuruş veya ön ek kısayolu durumlarında kullanırsın.
- `window.pending_input_keystrokes()`, henüz tamamlanmamış girdi zincirini verir.

## EventEmitter ve Özel Olaylar

GPUI'de view'lar kendi özel olaylarını tanımlayıp yayabilir (`emit`). Bunun için view struct'ının `EventEmitter` trait'ini uygulaması gerekir:

```rust
pub enum BenimOlayim {
    Kapatildi,
    Degisti(String),
}

impl EventEmitter<BenimOlayim> for Gorunum {}
```

Olayları yaymak ve dinlemek için şu yöntemleri kullanırsın:

- **Yayılım (Emit):** `cx.emit(BenimOlayim::Kapatildi)` çağrısı ile view kendi olayını yayınlar.
- **Dinleme (Subscribe):** Üst bileşen, alt bileşenin olaylarını `cx.subscribe` ile dinler:
  ```rust
  cx.subscribe(&alt_gorunum, |gorunum, alt_gorunum, olay, cx| {
      match olay {
          BenimOlayim::Kapatildi => println!("Kapandı"),
          BenimOlayim::Degisti(yeni_deger) => println!("Değer: {}", yeni_deger),
      }
  }).detach();
  ```

| Olay Tipi | Açıklama |
|---|---|
| `EventEmitter` olayları | View'un kendi tanımladığı iş mantığı olayları (örn. `Degisti`, `Kapatildi`). |
| Odak Olayları | Elementin odak alıp kaybetmesi durumunda çalışan `cx.on_focus`, `cx.on_blur` olayları. |
| Fare/Tuş Olayları | Element ağacında `.on_click`, `.on_mouse_down` veya kısayol basıldığında fırlatılan UI olayları. |

---
