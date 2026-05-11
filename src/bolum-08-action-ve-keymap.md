# 8. Action ve Keymap

---

## 8.1. Action Sistemi Derinlemesine

Kaynak: `crates/gpui/src/action.rs`, `key_dispatch.rs`.

**Action**, GPUI'de adlandırılmış bir komut mesajıdır: "Save", "OpenFile", "GoToLine 42" gibi. Action'lar her zaman bir focus ağacı boyunca akar (focused element'ten root'a doğru); klavyeden, menüden veya programatik dispatch'ten geldiklerinde aynı yolu izler. Bu sayede aynı komut için klavye kısayolu, menü öğesi ve buton tıklaması tek bir handler'a bağlanır. Action sistemi üç parçadan oluşur: action tanımı, dispatch, ve `on_action` listener'ı.

### Action tanımının iki yolu

**Veri taşımayan action** (en sık karşılaşılan):

```rust
use gpui::actions;
actions!(my_namespace, [Save, Close, Reload]);
```

`actions!` makrosu her isim için bir unit struct ve `Action` implementasyonu üretir; namespace ile birlikte `my_namespace::Save` adıyla registry'ye kaydolur. Registry her action'a runtime'da string adıyla erişebilmek için kullanılır (örn. komut paletinden).

**Veri taşıyan action** (parametre alan komutlar):

```rust
use gpui::Action;

#[derive(Clone, PartialEq, serde::Deserialize, schemars::JsonSchema, Action)]
#[action(namespace = editor)]
pub struct GoToLine { pub line: u32 }
```

`#[action(...)]` attribute'üyle kontrol sağlanır: `namespace`, `name`, `no_json`, `no_register`, `deprecated_aliases`, `deprecated`. Varsayılan davranış action'ın `Deserialize` ve `JsonSchema` derive etmesidir (keymap dosyasından JSON ile inşa edilebilsin diye); pure-code action için `no_json`, registry'ye otomatik kaydı atlamak için `no_register` kullanılır. Detaylar 8.2'de.

### Dispatch yolları

Bir action üç farklı şekilde dispatch edilir:

- `window.dispatch_action(action.boxed_clone(), cx)` — Focused element'ten root'a doğru bubble eder.
- `focus_handle.dispatch_action(&action, window, cx)` — Belirli bir focus handle'dan başlatır (örn. arka plandaki belirli bir view'a komut göndermek).
- **Keymap eşleştirmesi** — Klavye kısayolu binding'iyle eşleşen action otomatik dispatch edilir; aşağıda anlatılır.

### Listener kaydı

Action'ı yakalamak için element üzerinde `on_action` veya `capture_action` kullanılır:

```rust
.on_action(cx.listener(|this, action: &GoToLine, window, cx| {
    this.go_to(action.line);
    cx.notify();
}))
.capture_action(cx.listener(handler)) // capture phase
```

İki listener tipi `DispatchPhase` farkıyla ayrılır:

- **`Capture`** — Root'tan focused element'e doğru iner. Pencere genelinde dinleyicilerin önce yakalaması için.
- **`Bubble`** — Focused element'ten root'a doğru çıkar; **varsayılan davranış**. Action handler'ları bubble fazında varsayılan olarak propagation'ı durdurur — yani bir handler action'ı yakalarsa parent listener'lara ulaşmaz. Tersi gerekiyorsa handler içinde `cx.propagate()` çağrılır.

### Keybinding

Action'ı bir klavye kısayoluna bağlamak `cx.bind_keys` ile yapılır:

```rust
cx.bind_keys([
    KeyBinding::new("cmd-s", Save, Some("Workspace")),
    KeyBinding::new("ctrl-g", GoToLine { line: 0 }, Some("Editor")),
]);
```

Üçüncü parametre **context predicate**'idir; bu kısayolun yalnızca belirli bir UI bağlamında (örn. Editor odakta iken) aktif olmasını sağlar.

### Context predicate gramer

Kaynak: `crates/gpui/src/keymap/context.rs:172,360+`.

- `Editor` — Context stack'te `Editor` identifier'ı var.
- `Editor && !ReadOnly` — Birleştirme ve negasyon.
- `Workspace > Editor` — `>` operatörü descendant predicate'idir; "`Editor` aktif ve onun parent dispatch path'inde `Workspace` var" anlamına gelir.
- `mode == insert` — Eşitlik. `KeyContext::set("mode", "insert")` ile yazılan key/value değerine bakar.
- `mode != normal` — Eşitsizlik.
- `(Editor || Terminal) && !ReadOnly` — Parantezle gruplama.

Parser yalnızca şu operatörleri tanır: `>`, `&&`, `||`, `==`, `!=`, `!`. `in (a, b)`, `not in`, fonksiyon çağrısı gibi syntax'lar yoktur. Vim mod kombinasyonları için `mode == normal || mode == visual` yazılır.

`.key_context("Editor")` çağrısı element ağacına context push eder; child'lar üst context'lerin hepsini görür. Aynı binding birden çok context'te eşleşirse **en derin (en spesifik) context kazanır**.

### Tuzaklar

- **Action register edilmeden binding atılırsa keymap parse hata verir.** `actions!` veya `#[derive(Action)]` makrosunun, binding yüklenmeden önce derlenmiş ve registry'ye girmiş olması gerekir.
- **Bubble fazında handler `cx.propagate()` çağırmazsa parent action handler'lara ulaşmaz.** Action listener'ları default olarak action'ı tükettiği için, parent'a düşmesi istenen senaryolarda propagate açıkça çağrılır.
- **Aynı action ismi iki crate'te tanımlanırsa registry collision olur ve startup'ta panic edilir.** Namespace bu çakışmayı önlemek için zorunludur.
- **Zed runtime'ında bilinmeyen action ismi** keymap'te warning log üretir, panic değildir; eski keymap dosyaları yeni sürümde bozulmaz.

## 8.2. Action Makro Detayları, `register_action!` ve Deprecated Alias

`#[derive(Action)]` ve `actions!` makroları çoğu kullanım için yeterlidir. Ancak action sözleşmesinin altında bir trait, runtime introspection için bazı method'lar ve manuel inventory kaydı gibi köşe taşları vardır; özel akışlarda (manuel `Action` impl'i, deprecated migration, derive olmayan dinamik action) bu detaylar gerekir.

### `Action` trait'inin yüzeyi

Kaynak: `crates/gpui/src/action.rs:117+`.

```rust
pub trait Action: Any + Send {
    fn boxed_clone(&self) -> Box<dyn Action>;
    fn partial_eq(&self, other: &dyn Action) -> bool;
    fn name(&self) -> &'static str;
    fn name_for_type() -> &'static str where Self: Sized;
    fn build(value: serde_json::Value) -> Result<Box<dyn Action>>
        where Self: Sized;
    fn action_json_schema(_: &mut SchemaGenerator) -> Option<Schema>
        where Self: Sized { None }
    fn deprecated_aliases() -> &'static [&'static str]
        where Self: Sized { &[] }
    fn deprecation_message() -> Option<&'static str>
        where Self: Sized { None }
    fn documentation() -> Option<&'static str>
        where Self: Sized { None }
}
```

`name(&self)` ve `name_for_type()` farkı pratiktir:

- `name(&self)` — runtime ad; dinamik bir action ile çalışılırken (`Box<dyn Action>` üzerinden) okunur.
- `name_for_type()` — static ad; registration ve schema lookup gibi compile-time bilgi gereken yerlerde kullanılır.

### `#[action(...)]` attribute'leri

`#[derive(Action)]` üzerinde verilen attribute'ler, action'ın registry'ye nasıl kaydolacağını ve hangi özelliklerinin açık olacağını kontrol eder:

- **`namespace = my_crate`** — Action adını `my_crate::Save` formuna getirir; çakışmayı önler.
- **`name = "OpenFile"`** — Namespace içinde özel ad ver (default struct adıdır).
- **`no_json`** — `Deserialize` ve `JsonSchema` derive zorunluluğunu kaldırır; `build()` her zaman hata döner, `action_json_schema()` `None`. Pure-code action'lar (keymap dosyasından çağrılmayacak, sadece kod içinden dispatch edilecek; örn. `RangeAction { start: usize }`) için kullanılır.
- **`no_register`** — Inventory üzerinden otomatik kaydı atlar. Trait'i elle implemente ederken veya conditional kayıt yapılırken (feature flag arkasında) gereklidir.
- **`deprecated_aliases = ["editor::OldName", "old::Name"]`** — Keymap'te eski isimle yazılmış binding'i hâlâ kabul ederken kullanıcıya warning gösterir. Action yeniden adlandırıldığında geriye uyumluluk için.
- **`deprecated = "message"`** — Action'ın kendisini deprecated işaretler. `deprecation_message()` bu metni döndürür; UI tarafında kullanıcıya gösterilir.

### `register_action!` makrosu

`#[derive(Action)]` kullanmadan `Action` trait'ini manuel implemente eden bir tip için inventory kaydı:

```rust
use gpui::register_action;

register_action!(Paste);
```

Bu makro yalnızca `inventory::submit!` çağrısı üretir; struct veya impl tanımına dokunmaz. `no_register` attribute'üyle birlikte kullanıldığında, ne zaman kayıt yapılacağı tamamen elle kontrol edilir (örn. plugin yüklendikten sonra kayıt).

### Runtime API'leri

Action ile runtime'da konuşmak için sık kullanılan method'lar:

- **`cx.is_action_available(&action) -> bool`** — Focused element path'inde bu action'ı dinleyen biri var mı? Menü item'larını veya buton state'lerini "disabled" hâle getirmek için idealdir.
- **`window.is_action_available(&action, cx)`** — Aynı sorgunun window-spesifik versiyonu.
- **`cx.dispatch_action(&action)`** — Focused window'a action yayınlar.
- **`window.dispatch_action(action.boxed_clone(), cx)`** — Window-spesifik dispatch.
- **`cx.build_action(name, json_value)`** — Keymap entry'sinden runtime action üretir; action'da schema yoksa veya argümanlar geçersizse `ActionBuildError` döner.

### Tuzaklar

- **`partial_eq` derive varsayılan olarak `PartialEq` impl'ini kullanır;** action struct'ında `PartialEq` derive eklemeyi unutmak karşılaştırmanın yanlış çalışmasına yol açabilir.
- **Aynı `name()` döndüren iki action register edilirse inventory startup'ta panic eder.** Namespace kullanmak bu çakışmayı önler — bu nedenle `actions!` her zaman namespace alır.
- **`deprecated_aliases` keymap parser tarafında eski adı yeni action'a yönlendirir; ancak Rust kodunda eski tipi referans etmeye devam edilirse iki ayrı tip oluşur ve registry'de çakışma çıkar.** Migration sırasında eski tip tamamen kaldırılır, yalnızca alias kalır.
- **`no_json` ile işaretli action keymap dosyasından çağrılamaz.** Sadece kod içinden `dispatch_action` ile tetiklenir; keymap'e yazılırsa parse hatası alınır.

## 8.3. Keymap, KeyContext ve Dispatch Stack

Bir action'ı tanımlamak ve keybinding'i bağlamak tek başına yetmez; binding'in tetiklenebilmesi için **focused element'in dispatch path'inde** ilgili context'in (örn. `Editor`, `Workspace`, `mode == insert`) ulaşılabilir olması şarttır. Bu bölüm context'lerin element ağacına nasıl yerleştirildiğini, binding tarafının predicate dilini ve runtime'da çalışan sorgu/eşleştirme API'lerini ele alır.

### Context yerleştirme

Bir element ağacında context, dispatch path'in o noktasından aşağıya doğru aktarılır. Child node'lar parent context'lerin tümünü görür.

```rust
div()
    .track_focus(&self.focus_handle)
    .key_context("Editor mode=insert")
    .on_action(cx.listener(|this, _: &Save, window, cx| {
        this.save(window, cx);
    }))
```

Burada `.key_context("Editor mode=insert")` `Editor` identifier'ı ve `mode = insert` key/value pair'i push eder; child'lar bu context içindeki binding'leri otomatik kullanabilir.

### Binding ekleme

```rust
cx.bind_keys([
    KeyBinding::new("cmd-s", Save, Some("Editor")),
    KeyBinding::new("ctrl-g", GoToLine { line: 0 }, Some("Workspace && !Editor")),
]);
```

### Önemli parçalar

- **`KeyContext::parse("Editor mode = insert")`** — String'den context üretir.
- **`KeyContext::new_with_defaults()`** — Default context set'iyle başlar. `primary()`, `secondary()` parse edilen ana/ek context entry'lerine erişir; `is_empty()`, `clear()`, `extend(&other)`, `add(identifier)`, `set(key, value)`, `contains(key)`, `get(key)` düşük seviyeli context inşa/sorgu yüzeyidir.
- **`KeyBindingContextPredicate`** — Binding tarafındaki predicate dili (`Editor`, `mode == insert`, `!Terminal`, `Workspace > Editor`, `A && B`, `A || B`).
- **`KeyBindingContextPredicate::parse(source)`** — Predicate'i üretir. `eval(context_stack)` bool eşleşme, `depth_of(context_stack)` en derin eşleşme derinliği, `is_superset(&other)` keymap önceliği ve conflict analizinde kullanılır. `eval_inner(...)` public olsa da parser/validator gibi düşük seviyeli kodlar içindir; sıradan component kodu çağırmaz.
- **`Keymap::bindings_for_input(input, context_stack)`** — Eşleşen action'ları ve pending multi-stroke durumunu döndürür.
- **`Keymap::possible_next_bindings_for_input(input, context_stack)`** — Mevcut chord prefix'ini takip edebilecek binding'leri precedence sırasıyla verir.
- **`Keymap::version() -> KeymapVersion`** — Binding seti değiştikçe artan sayaçtır; keybinding UI cache'lerinde invalidation anahtarı olarak kullanılır.
- **`Keymap::new(bindings)`, `add_bindings(...)`, `bindings()`, `bindings_for_action(action)`, `all_bindings_for_input(input)`, `clear()`** — Ham keymap tablosu üzerinde kurma/sorgulama/reset yüzeyi. Uygulama kodu çoğu zaman `cx.bind_keys(...)` ve settings loader tercih eder; bu method'lar test, validator, diagnostic ve özel keymap UI için doğrudan kullanılır.
- **`window.context_stack()`** — Focused node'dan root'a dispatch path context'lerini döndürür.
- **`window.keystroke_text_for(&action)`** — UI'da gösterilecek en yüksek öncelikli binding string'i (menüdeki "Ctrl+S" gibi).
- **`window.possible_bindings_for_input(&[keystroke])`** — Chord/pending yardım UI'ları için kullanılır.
- **`cx.key_bindings() -> Rc<RefCell<Keymap>>`** — Keymap'e düşük seviyeli erişim. Production kodda mümkünse `bind_keys`, keymap dosyası ve validator akışı kullanılır; bu handle test/diagnostic ve özel keymap UI için uygundur.
- **`cx.clear_key_bindings()`** — Tüm binding'leri temizler ve pencereleri refresh için planlar; sıradan uygulama akışında değil, test/reset path'lerinde kullanılır.

### Öncelik kuralları

- **Context path'te daha derin eşleşme daha yüksek önceliklidir.** Yani `Editor` binding'i, `Workspace` binding'ini bastırır (Editor daha içeride olduğu için).
- **Aynı derinlikte sonra eklenen binding önce gelir.** User keymap bu yüzden built-in binding'leri ezebilir; default'lar önce yüklenir, user override'ları sonra.
- **`NoAction` ve `Unbind` binding'leri** belirli bir kısayolu devre dışı bırakmak için kullanılır (detaylar 8.6'da).
- **Printable input IME'ye gidecekse keybinding yakalamayı geriye çekebilir.** `InputHandler::prefers_ime_for_printable_keys` `true` olduğunda printable tuşlar binding sistemine değil önce IME'ye gider. `EntityInputHandler` kullanan view'larda bu değer `ElementInputHandler` tarafından `accepts_text_input` sonucundan türetilir; ayrı karar gerekiyorsa raw `InputHandler` yazılır.

### Tuzaklar

- **`.key_context(...)` olmayan bir subtree'de context predicate'li binding çalışmaz.** Binding eklenmeden önce element ağacına ilgili context'in yerleştirildiğinden emin olunmalıdır.
- **Handler focus path'te değilse action bubble oraya ulaşmaz.** Global etkili handler için `cx.on_action(...)`, belirli element için `.on_action(...)` kullanılır.
- **`KeyBinding::new` parse hatasında panic edebilir;** kullanıcı JSON'undan yükleme yaparken `KeyBinding::load` ve düzgün hata raporlaması tercih edilir.
- **`KeyBinding::load(keystrokes, action, context_predicate, use_key_equivalents, action_input, keyboard_mapper)`** fallible loader'dır; `KeyBindingKeystroke` mapping'ini de burada kurar. `context_predicate` `Option<Rc<KeyBindingContextPredicate>>`, `action_input` `Option<SharedString>` alır; hata durumunda `InvalidKeystrokeError` döner. Runtime'da `with_meta(...)` / `set_meta(...)` binding'in hangi keymap katmanından geldiğini taşır; `match_keystrokes(...)` tam/pending eşleşmeyi, `keystrokes()`, `action()`, `predicate()`, `meta()`, `action_input()` getter'ları diagnostic ve command/keymap UI'ı besler.

## 8.4. DispatchPhase, Event Propagation ve DispatchEventResult

Mouse, klavye ve action olayları element ağacında **iki fazda** akar. Bu fazlar, bir event'in önce dış katmanlardan yakalanmasına (örn. pencere genelinde shortcut izleme) sonra hedef element'te işlenmesine ya da hedeften başlayıp dışa doğru bubble etmesine izin verir.

```rust
pub enum DispatchPhase {
    Capture, // root → focused
    Bubble,  // focused → root (default)
}
```

`Window::on_mouse_event`, `on_key_event`, `on_modifiers_changed` listener'ları faza göre çağrılır. Element fluent API'lerinde `.on_*` ailesi bubble fazına, `.capture_*` ailesi capture fazına bağlanır.

### Propagation kontrol bayrakları

Kaynak: `crates/gpui/src/app.rs:2021+`.

- **`cx.stop_propagation()`** — Aynı tipteki diğer handler'ların çağrılmasını keser. Mouse event'inde z-index'te alttaki katman, key event'inde ağaçta üst element çağrılmaz.
- **`cx.propagate()`** — Bir önceki `stop_propagation()` etkisini geri alır. Action handler'ları bubble fazında **default olarak propagation'ı durdurur**; parent action handler'larının da çalışması isteniyorsa handler içinden `cx.propagate()` çağrılır.
- **`window.prevent_default()` / `window.default_prevented()`** — Aynı dispatch içinde default element davranışını bastıran pencere bayrağıdır. En görünür kullanımı, mouse down sırasında parent focus transferini engellemektir (örn. drag handle'a tıklamak focus'u parent panel'e transfer etmesin diye).

### Platform tarafına dönen sonuç

Bir dispatch tamamlandığında GPUI platforma sonucu yapısal olarak iletir:

```rust
pub struct DispatchEventResult {
    pub propagate: bool,         // hâlâ bubble ediliyorsa true
    pub default_prevented: bool, // GPUI default davranışı bastırıldı mı
}
```

`PlatformWindow::on_input` callback'i `Fn(PlatformInput) -> DispatchEventResult` döndürür. Mevcut platform backend'lerinde "event işlendi mi?" kararı esas olarak `propagate` üzerinden alınır (`!propagate` handled anlamına gelir). `default_prevented` ise GPUI dispatch ağacındaki default element davranışını ve test/diagnostic sonucunu taşır; platform default action kontrolü gibi genel bir API olarak yorumlanmadan, handler'ın açıkça kontrol ettiği yerlerde anlamlandırılır.

### Pratik akış

1. Element listener fire eder, view state'i günceller, gerekirse `cx.notify()` çağrılır.
2. Listener event'i tüketmek istiyorsa `cx.stop_propagation()` çağrılır.
3. Action handler default'tan kaynaklı durdurmayı geri almak istiyorsa `cx.propagate()` ile bubble yeniden açılır.
4. Default focus transferi gibi GPUI içi davranış bastırılmak isteniyorsa `window.prevent_default()` çağrılır.

### Tuzaklar

- **`capture_*` handler'ları focus path'i bilinmeden çalışır.** Pencere geneli shortcut veya observer için uygundur; ancak state mutate edilecekse focused element runtime'da kontrol edilir (yanlış view'a yazma riski olmasın diye).
- **Action propagation davranışı mouse/key event'lerden tersine çalışır.** Yeni action handler'ı yazarken refleksle `stop_propagation` koymak parent action handler'larını sessizce öldürebilir; çoğu zaman default davranış (otomatik durma) zaten doğru sonucu verir.
- **`default_prevented` genel bir platform cancellation API'si değildir.** Hangi davranışı durdurduğunu anlamak için ilgili element veya window handler'ının `window.default_prevented()` kontrolü yapıp yapmadığına bakılmalıdır; aksi halde flag set edilir ama hiçbir şey değişmez.

## 8.5. Action ve Keymap Runtime Introspection

Önceki bölümler action tanımlama ve dispatch'i ele aldı. Bu bölüm runtime introspection yüzeyini özetler: çalışan uygulamada hangi action'ların kayıtlı olduğunu, hangilerinin o anda kullanılabilir olduğunu, hangi binding'lerin hangi kısayola karşılık geldiğini sorgulayan API'ler. Bunlar özellikle komut paleti (kullanıcıya filtrelenebilir action listesi), keymap UI (binding düzenleme), menü item disable/enable kontrolü ve geliştirici diagnostiği için gereklidir.

### Action registry sorguları

- **`cx.build_action(name, data) -> Result<Box<dyn Action>, ActionBuildError>`** — String action adı ve opsiyonel JSON verisinden runtime action üretir. Komut paleti veya keymap loader bunu kullanır.
- **`cx.all_action_names() -> &[&'static str]`** — Kayıtlı tüm action adlarını döndürür. **Önemli ayrım:** registration, action'ın o an dispatch edilebilir olduğu anlamına gelmez; sadece tipin runtime'da bilindiğini gösterir.
- **`cx.action_schemas(generator)`** — Non-internal action adları ve JSON schema'ları.
- **`cx.action_schema_by_name(name, generator)`** — Tek bir action için schema. Üç sonuç durumu: `None` → action yok; `Some(None)` → action var ama JSON schema yok (`no_json` ile işaretli); `Some(Some(schema))` → schema mevcut.
- **`cx.deprecated_actions_to_preferred_actions()`, `cx.action_deprecation_messages()`, `cx.action_documentation()`** — Keymap validator, komut paleti ve migration mesajları için registry metadata'sı.

### Kullanılabilir action ve binding sorguları

Aşağıdaki method'lar focused element'in dispatch path'ini hesaba katar; "şu anda neye basılırsa ne olur?" sorusunu cevaplar.

- **`window.available_actions(cx)`** — Focused element dispatch path'indeki action listener'larını ve global listener'ları birleştirir. Menü/komut UI'ında "bu action şu anda yapılabilir mi?" sorusunun window-spesifik cevabıdır.
- **`window.on_action_when(condition, TypeId::of::<A>(), listener)`** — Paint fazında, current dispatch node'una conditional low-level action listener ekler. Element API'deki `.on_action(...)` / `.capture_action(...)` çoğu durumda daha okunur; bu method custom element yazılırken kullanılır.
- **`cx.is_action_available(&action)`, `window.is_action_available(&action, cx)`** — Bool kısayollar.
- **`window.is_action_available_in(&action, focus_handle)`** — Sorguyu belirli bir focus handle'ın dispatch path'inden yapar (örn. arka plandaki bir view için "bunda bu action var mı" sorusu).
- **`window.bindings_for_action(&action)`** — Focused context stack'e göre action'a giden binding'leri döndürür; display için son binding en yüksek öncelikli kabul edilir.
- **`window.highest_precedence_binding_for_action(&action)`** — Aynı sorgunun tek sonuçlu, daha ucuz versiyonu.
- **`window.bindings_for_action_in(&action, focus_handle)` ve `highest_precedence_binding_for_action_in(...)`** — Sorguyu belirli focus handle path'inden yapar.
- **`window.bindings_for_action_in_context(&action, KeyContext)`** — Tek bir elle verilmiş context'e göre sorgu (test/diagnostic için).
- **`window.highest_precedence_binding_for_action_in_context(...)`** — Aynının tek sonuçlu versiyonu.
- **`cx.all_bindings_for_input(&[Keystroke])`** — Context'e bakmadan, input dizisine kayıtlı tüm binding'leri listeler. Diagnostic kullanım içindir; UI display'i için context-aware sorgular tercih edilir.
- **`window.possible_bindings_for_input(&[Keystroke])`** — Multi-stroke/prefix akışında current context stack'e göre sıradaki aday binding'leri verir. Tam eşleşen action'ın dispatch sonucunu öğrenmek için normal `window.dispatch_keystroke(...)` akışı kullanılır; public `Window::bindings_for_input` helper'ı yoktur.
- **`window.pending_input_keystrokes()`, `window.has_pending_keystrokes()`** — Tamamlanmamış chord durumunu UI'da göstermek veya testte beklemek için.

### Global keystroke gözlemi

Pencere genelinde her keystroke'u izlemek veya dispatch'ten önce müdahale etmek için iki ayrı kanca vardır:

```rust
let after_dispatch = cx.observe_keystrokes(|event, window, cx| {
    log_key(event, window, cx);
});

let before_dispatch = cx.intercept_keystrokes(|event, window, cx| {
    if should_block(event) {
        cx.stop_propagation();
    }
});
```

- **`observe_keystrokes`** — Action ve event mekanizmaları çözüldükten **sonra** çalışır; propagation durdurulduysa çağrılmaz. Log, telemetry, "key cast" overlay'i gibi pasif tüketim için uygundur.
- **`intercept_keystrokes`** — Dispatch'ten **önce** çalışır; burada `cx.stop_propagation()` çağırmak action dispatch'i engeller. Tutorial overlay'leri, kayıt modları gibi tüm input'u yakalama gereken senaryolarda kullanılır.

Her iki çağrı da `Subscription` döner; bu subscription kaybedilirse observer düşer (bkz. 3. Bölüm subscription kuralları).

### Tuzaklar

- **`all_action_names` içinde görünen action'ın o anda kullanılabilir olması garanti değildir.** UI enable/disable için `available_actions` veya `is_action_available` kullanılır; `all_action_names` yalnızca "kayıtlı mı?" sorusunu cevaplar.
- **Binding display ederken `cx.all_bindings_for_input` context stack'i hesaba katmaz.** Kullanıcıya gösterilecek kısayol için mümkün olduğunca window/focus-handle bazlı sorgu tercih edilir.
- **Interceptor'lar global etkilidir.** Modal'a özel key engelleme gerekiyorsa interceptor yerine element action/capture handler ile sınırlandırma yapılır; aksi halde diğer pencereler/durumlar da etkilenir.

## 8.6. Zed Keymap Dosyası, Validator ve Unbind Akışı

GPUI action/keybinding modeli Zed tarafında `settings::keymap_file` aracılığıyla kullanıcı dosyasına bağlanır. Bu bölüm runtime dispatch'ten farklı olarak, JSON yükleme, schema, validator ve dosya güncelleme tarafını kapsar. En kritik kısım iki sentinel action — `NoAction` ve `Unbind` — arasındaki farktır; bu ikisi keybinding'leri belirli kapsamlarda devre dışı bırakmak için kullanılır.

### Dosya modeli

- **`KeymapFile(Vec<KeymapSection>)`** — Top-level JSON array; her eleman bir context bölümüdür.
- **`KeymapSection`** — Context predicate ve binding/unbind map'lerini taşır. Alan görünürlüğü dengesizdir: yalnızca `pub context: String` dış erişime açıktır. `use_key_equivalents: bool`, `unbind: Option<IndexMap<...>>`, `bindings: Option<IndexMap<...>>`, `unrecognized_fields: IndexMap<...>` alanları **private**'tır. `KeymapFile` parser'ı bu alanlara crate içinden doğrudan erişir; dış kod yalnız `KeymapSection::bindings(&self)` getter'ını kullanabilir (`(keystroke, KeymapAction)` çiftlerini dönen tek public iterator; `keymap_file.rs:101`). `unbind` ve `use_key_equivalents` için bu sürümde ayrı public getter yoktur.
- **`KeymapAction(Value)`** — Eylem değerini temsil eder: `null`, `"action::Name"` veya `["action::Name", { ...args... }]` biçimi.
- **`UnbindTargetAction(Value)`** — `unbind` map'indeki hedef action değeri.
- **`KeymapFileLoadResult::{Success, SomeFailedToLoad, JsonParseFailure}`** — Dosyanın kısmen yüklenebildiği senaryoyu açıkça ayırır; kullanıcının bozuk bir entry'si tüm keymap'i çökertmesin diye.

### Yükleme

```rust
let keymap = KeymapFile::parse(&contents)?;
let result = KeymapFile::load(&contents, cx);
```

`load_asset(asset_path, source, cx)` bundled keymap dosyalarını yükler ve `KeybindSource` metadata'sı set edebilir. `load_panic_on_failure` yalnızca startup/test gibi "asset bozuksa devam etmeyelim" senaryoları içindir; production kodda kullanılmaz.

### Base keymap (preset şema)

Zed kullanıcıya tanıdık editörlerin shortcut şemalarını "base keymap" olarak sunar:

- `BaseKeymap::{VSCode, JetBrains, SublimeText, Atom, TextMate, Emacs, Cursor, None}`.
- Base, default, vim ve user binding'leri her biri `KeybindSource` metadata'sı taşır; keymap UI hangi binding'in nereden geldiğini bu metadata ile gösterir (örn. "VSCode default" veya "user override").

### Validator

Bazı action'ların belirli kullanım kuralları vardır (örn. argüman aralığı, geçerli enum değerleri). `KeyBindingValidator` bu kuralları zorlar:

- `KeyBindingValidator` — Belirli bir action tipi için binding doğrulaması yapar.
- `KeyBindingValidatorRegistration(pub fn() -> Box<dyn KeyBindingValidator>)` — Inventory ile toplanır; her action kendi validator'unu kayıt edebilir.
- Validator hatası `MarkdownString` döndürür; keymap UI bunu kullanıcıya açıklanabilir, link içerebilen bir mesaj olarak gösterir.

### Disable / unbind sentinel action'ları

GPUI iki ayrı sentinel action sağlar (`gpui::action.rs:425-453`); ikisinin de runtime davranışı **dispatch etmemek**'tir, fakat keymap dispatch tablosundaki işlevleri farklıdır:

#### `zed::NoAction`

`actions!(zed, [NoAction])` ile tanımlı, veri taşımaz. Keymap JSON'unda eylem değeri olarak `null` veya `"zed::NoAction"` yazılır:

```json
{ "context": "Editor", "bindings": { "cmd-p": null } }
```

Aynı keystroke'a daha düşük öncelikle bağlanmış action'lar bu context için iptal edilir; eşleşme `Keymap::resolve_binding` tarafında `disabled_binding_matches_context(...)` çağrısıyla **context-aware** olarak filtrelenir (`gpui/src/keymap.rs:120`). Yani `NoAction` belirli bir context predicate'i içinde tuşu sessize alır. Diğer context'lerde aynı kısayol hâlâ aktif kalır.

#### `zed::Unbind(SharedString)`

`derive(Action)` ile tanımlı; payload bir action adıdır. JSON formatı:

```json
["zed::Unbind", "editor::NewLine"]
```

Keymap parser'ı bu sentinel'ı gördüğünde aynı keystroke'a aynı action adıyla bağlı **tüm** binding'leri context'ten bağımsız olarak iptal eder (`keymap.rs:124-128`'deki `is_unbind` kolu). Örnek kullanım: `editor::NewLine` için `enter` tuşunu tüm context'lerde unbind etmek.

#### İkisinin pratik farkı

- `NoAction` → "bu tuş bu context'te hiçbir şey yapmasın."
- `Unbind` → "bu action'a giden bu tuşu **her yerde** kaldır."

#### Sentinel kontrol API'leri

- `gpui::is_no_action(&dyn Action) -> bool` (`action.rs:445`) — `as_any().is::<NoAction>()` ile downcast eder. Custom keymap UI veya komut paleti listesinde "(disabled)" göstergesi yerleştirmek için.
- `gpui::is_unbind(&dyn Action) -> bool` (`action.rs:450`) — Aynı şekilde `Unbind` instance'ını downcast eder.

`KeymapFile::update_keybinding` `KeybindUpdateOperation::Remove` için bu iki sentinel'i bağlama göre üretir: user binding'leri `Remove` doğrudan dosyadan siler; framework/default binding'leri ise kaldırılamadığı için kullanıcı keymap'ine `null` (NoAction) veya `["zed::Unbind", ...]` entry'si yazar (suppress eder).

### Dosya güncelleme

```rust
let updated = KeymapFile::update_keybinding(
    operation,
    keymap_contents,
    tab_size,
    keyboard_mapper,
)?;
```

- **`KeybindUpdateOperation::Add { source, from }`** — Yeni binding ekler.
- **`Replace { source, target, target_keybind_source }`** — User binding ise değiştirir; user dışı binding değişiyorsa "yeni binding ekle + eski binding'i suppress eden unbind yaz" formuna dönüşür.
- **`Remove { target, target_keybind_source }`** — User binding'i dosyadan siler; user dışı binding'i kaldırmak için `unbind` yazar.
- **`KeybindUpdateTarget`** — Action adı, opsiyonel action arguments, context ve `KeybindingKeystroke` dizisini taşır.

### Tuzaklar

- **`use_key_equivalents` yalnızca destekleyen platformlarda anlamlıdır.** Keyboard mapper verilmeden dosya güncelleme doğru keystroke string'i üretemez; örneğin macOS dışında bu seçenek görmezden gelinir.
- **Non-user (default/extension) binding'i "silmek" gerçek kaynağı değiştirmez.** Kullanıcı keymap'ine suppress eden `unbind` entry'si yazılır; gerçek default tanım yerinde kalır.
- **Kullanıcı JSON'u bozuksa `update_keybinding` dosyayı değiştirmez.** Parse başarıyla geçmeden güncelleme uygulanmaz; aksi halde mevcut JSON daha da kötü hâle gelir.


---

