# Bölüm VIII — Action ve Keymap

---

## 44. Action Sistemi Derinlemesine

`crates/gpui/src/action.rs`, `key_dispatch.rs`.

Action tanımının iki ana yolu vardır.

Veri taşımayan action:

```rust
use gpui::actions;
actions!(my_namespace, [Save, Close, Reload]);
```

`actions!` makrosu her isim için unit struct ve `Action` impl üretir; namespace
`my_namespace::Save` adıyla registry'ye kaydolur.

Veri taşıyan action:

```rust
use gpui::Action;

#[derive(Clone, PartialEq, serde::Deserialize, schemars::JsonSchema, Action)]
#[action(namespace = editor)]
pub struct GoToLine { pub line: u32 }
```

`#[action(namespace = ..., name = "...", no_json, no_register,
deprecated_aliases = [...], deprecated = "...")]` attribute'leri kontrol sağlar.
Default olarak `Deserialize` derive edilmesi ve `JsonSchema` implement edilmesi
beklenir; pure code action için `no_json` kullan, register edilmesini
istemiyorsan `no_register` ekle.

Dispatch:

- `window.dispatch_action(action.boxed_clone(), cx)`: focused element'ten root'a doğru
  bubble.
- `focus_handle.dispatch_action(&action, window, cx)`: belirli handle'dan başlatır.
- Keymap girdileri eşleştiğinde otomatik dispatch edilir.

Listener kaydı:

```rust
.on_action(cx.listener(|this, action: &GoToLine, window, cx| {
    this.go_to(action.line);
    cx.notify();
}))
.capture_action(cx.listener(handler)) // capture phase
```

`DispatchPhase`:

- `Capture`: root'tan focused element'e doğru.
- `Bubble`: focused element'ten root'a doğru. Default; action handler'lar burada
  default olarak propagation'ı durdurur. Aksi gerekiyorsa içinde `cx.propagate()`.

Keybinding:

```rust
cx.bind_keys([
    KeyBinding::new("cmd-s", Save, Some("Workspace")),
    KeyBinding::new("ctrl-g", GoToLine { line: 0 }, Some("Editor")),
]);
```

Context predicate gramer (`crates/gpui/src/keymap/context.rs:172,360+`):

- `Editor` — context stack'te `Editor` identifier'ı var.
- `Editor && !ReadOnly` — birleştirme + negasyon.
- `Workspace > Editor` — `>` operatörü "Editor parent dispatch path'inde Workspace
  altında" anlamına gelen descendant predicate'idir.
- `mode == insert` — eşitlik (`KeyContext::set("mode", "insert")` ile yazılan
  key/value değerine bakar).
- `mode != normal` — eşitsizlik.
- `(Editor || Terminal) && !ReadOnly` — parantezle gruplama.

Gerçek parser yalnızca şu operatörleri tanır: `>`, `&&`, `||`, `==`, `!=`, `!`.
`in (a, b)`, `not in`, fonksiyon çağrısı gibi syntax'lar yoktur. Vim modu gibi
çoklu seçenek için `mode == normal || mode == visual` yazılır.

`.key_context("Editor")` ile element ağaca context push eder; child'lar üst
context'leri görür. Aynı binding birden çok context'te match ederse en
spesifik (en derin) context kazanır.

Tuzaklar:

- Action register edilmeden binding atılırsa keymap parse hata verir; `actions!`
  veya `#[derive(Action)]` mutlaka ana modülde derlenmiş olmalı.
- Bubble fazında handler `cx.propagate()` çağırmazsa parent action handler'lara
  ulaşmaz (default davranış).
- Aynı action ismi iki crate'te tanımlanırsa registry collision olur; namespace zorunlu.
- Zed runtime'da bilinmeyen action ismi keymap'te warning log üretir, panic değil.

## 45. Action Makro Detayları, register_action! ve Deprecated Alias

`#[derive(Action)]` ve `actions!` makrosu çoğu zaman yeterlidir, ancak action
sözleşmesinin ek köşe taşları vardır.

#### `Action` trait'inin gerçek yüzeyi (`crates/gpui/src/action.rs:117+`)

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

`name(&self)` runtime ad, `name_for_type()` static ad — runtime polymorphism
gerekirse ilkini, registration'da ikincisini kullan.

#### `#[action(...)]` attribute'leri

`#[derive(Action)]` üzerinde:

- `namespace = my_crate`: action adını `my_crate::Save` formuna çevirir.
- `name = "OpenFile"`: namespace içinde özel ad.
- `no_json`: `Deserialize`/`JsonSchema` derive zorunluluğunu kaldırır;
  `build()` her zaman hata döndürür, `action_json_schema()` `None`.
  Pure-code action (örn. `RangeAction { start: usize }`) için kullan.
- `no_register`: inventory üzerinden otomatik kaydı atlar; trait'i elle
  uygularken veya conditional kayıt yaparken gerekir.
- `deprecated_aliases = ["editor::OldName", "old::Name"]`: keymap'te eski adı
  kabul ederken kullanıcıya warning üretmek için.
- `deprecated = "message"`: action'ın kendisini deprecated işaretler;
  `deprecation_message()` bu metni döndürür.

#### `register_action!` makrosu

`#[derive(Action)]` kullanmadan `Action`'u manuel implement ediyorsan, action'ın
inventory'e girmesi için:

```rust
use gpui::register_action;

register_action!(Paste);
```

Bu makro yalnızca `inventory::submit!` çağrısı üretir; struct/impl tanımına
dokunmaz. `no_register` ile birleştiği takdirde elle ne zaman register
edileceğini sen belirlersin.

#### Action runtime API'leri

- `cx.is_action_available(&action) -> bool`: focused element path'te bu action'ı
  dinleyen biri var mı? Menü item'larını disable etmek için ideal.
- `window.is_action_available(&action, cx)`: window-spesifik versiyon.
- `cx.dispatch_action(&action)`: focused window'a yayınla.
- `window.dispatch_action(action.boxed_clone(), cx)`: window-spesifik.
- `cx.build_action(name, json_value)`: keymap entry'sinden runtime action üretir;
  schema yoksa `ActionBuildError` döner.

#### Tuzaklar

- `partial_eq` derive default'ta `PartialEq` impl'i kullanır; derive ekleme
  unutulursa karşılaştırma yanlış sonuç verebilir.
- Aynı `name()` döndüren iki action register edilirse inventory startup'ta
  panic eder; namespace kullanmak çakışmayı önler.
- `deprecated_aliases` keymap parser'ı eski adı yeni action'a yönlendirir, ama
  Rust kodunda eski tipi referans etmeye devam edersen iki tanım çakışır.
- `no_json` action'ı keymap dosyasından çağıramazsın; sadece kod içinden
  `dispatch_action` ile tetiklenir.

## 46. Keymap, KeyContext ve Dispatch Stack

Action tanımlamak tek başına yetmez; keybinding'in çalışması için focused element
dispatch path'inde uygun `KeyContext` bulunmalıdır.

Context koyma:

```rust
div()
    .track_focus(&self.focus_handle)
    .key_context("Editor mode=insert")
    .on_action(cx.listener(|this, _: &Save, window, cx| {
        this.save(window, cx);
    }))
```

Binding ekleme:

```rust
cx.bind_keys([
    KeyBinding::new("cmd-s", Save, Some("Editor")),
    KeyBinding::new("ctrl-g", GoToLine { line: 0 }, Some("Workspace && !Editor")),
]);
```

Önemli parçalar:

- `KeyContext::parse("Editor mode = insert")`: elementin bağlamını üretir.
- `KeyContext::new_with_defaults()`: default context set'iyle başlar.
  `primary()`, `secondary()` parse edilen ana/ek context entry'lerine erişir;
  `is_empty()`, `clear()`, `extend(&other)`, `add(identifier)`, `set(key, value)`,
  `contains(key)` ve `get(key)` düşük seviyeli context inşa/sorgu yüzeyidir.
- `KeyBindingContextPredicate`: binding tarafındaki predicate dilidir:
  `Editor`, `mode == insert`, `!Terminal`, `Workspace > Editor`,
  `A && B`, `A || B`.
- `KeyBindingContextPredicate::parse(source)` predicate'i üretir.
  `eval(context_stack)` bool eşleşme, `depth_of(context_stack)` en derin eşleşme
  derinliği, `is_superset(&other)` ise keymap önceliği ve conflict analizinde
  kullanılır. `eval_inner(...)` public olsa da parser/validator gibi düşük
  seviyeli kodlar içindir; normal component kodu doğrudan çağırmaz.
- `Keymap::bindings_for_input(input, context_stack)`: eşleşen action'ları ve
  pending multi-stroke durumunu döndürür.
- `Keymap::possible_next_bindings_for_input(input, context_stack)`: mevcut
  chord prefix'ini takip edebilecek binding'leri precedence sırasıyla verir.
- `Keymap::version() -> KeymapVersion`: binding set'i değiştikçe artan sayaçtır;
  keybinding UI cache'lerinde invalidation anahtarı olarak kullanılabilir.
- `Keymap::new(bindings)`, `add_bindings(bindings)`, `bindings()`,
  `bindings_for_action(action)`, `all_bindings_for_input(input)` ve `clear()`
  ham keymap tablosunu kurma/sorgulama/reset yüzeyidir. Uygulama akışında çoğu
  zaman `cx.bind_keys(...)` ve settings loader tercih edilir; bu metotlar test,
  validator, diagnostic ve özel keymap UI için doğrudan kullanılır.
- `window.context_stack()`: focused node'dan root'a dispatch path context'leri.
- `window.keystroke_text_for(&action)`: UI'da gösterilecek en yüksek öncelikli
  binding string'i.
- `window.possible_bindings_for_input(&[keystroke])`: chord/pending yardım UI'ları
  için kullanılabilir.
- `cx.key_bindings() -> Rc<RefCell<Keymap>>`: keymap'e düşük seviyeli erişim.
  Production kodunda mümkünse `bind_keys`, keymap dosyası ve validator akışı
  kullan; bu handle test/diagnostic ve özel keymap UI için uygundur.
- `cx.clear_key_bindings()`: tüm binding'leri temizler ve windows refresh planlar;
  normal uygulama akışında değil test/reset path'lerinde kullanılır.

Öncelik:

- Context path'te daha derin eşleşme daha yüksek önceliklidir.
- Aynı derinlikte sonra eklenen binding önce gelir; user keymap bu yüzden built-in
  binding'leri ezebilir.
- `NoAction` ve `Unbind` binding'leri devre dışı bırakma için kullanılır.
- Printable input IME'ye gidecekse `InputHandler::prefers_ime_for_printable_keys`
  keybinding yakalamayı geriye çekebilir. `EntityInputHandler` kullanan view'larda
  bu değer `ElementInputHandler` tarafından `accepts_text_input` sonucundan
  türetilir; ayrı karar gerekiyorsa raw `InputHandler` yaz.

Tuzaklar:

- `.key_context(...)` olmayan subtree'de context predicate'li binding çalışmaz.
- Handler focus path'te değilse action bubble oraya ulaşmaz; global handler için
  `cx.on_action(...)`, local handler için element `.on_action(...)` kullan.
- `KeyBinding::new` parse hatasında panic edebilir; kullanıcı JSON'undan yükleme
  yaparken `KeyBinding::load` ve error reporting tercih edilir.
- `KeyBinding::load(keystrokes, action, context_predicate, use_key_equivalents,
  action_input, keyboard_mapper)` fallible loader'dır; `KeyBindingKeystroke`
  mapping'ini de burada kurar. `context_predicate` `Option<Rc<KeyBindingContextPredicate>>`,
  `action_input` ise `Option<SharedString>` alır ve hata durumunda
  `InvalidKeystrokeError` döner. Runtime'da `with_meta(...)`/`set_meta(...)`
  binding'in hangi keymap katmanından geldiğini taşır; `match_keystrokes(...)`
  tam/pending eşleşmeyi, `keystrokes()`, `action()`, `predicate()`, `meta()` ve
  `action_input()` getter'ları diagnostic ve command/keymap UI'ı besler.

## 47. DispatchPhase, Event Propagation ve DispatchEventResult

Mouse, key ve action olayları element ağacında iki fazda akar:

```rust
pub enum DispatchPhase {
    Capture, // root → focused
    Bubble,  // focused → root (default)
}
```

`Window::on_mouse_event`, `on_key_event`, `on_modifiers_changed` listener'ları
faza göre çağrılır. Element fluent API'lerinde `.on_*` ailesi bubble fazına,
`.capture_*` ailesi capture fazına bağlanır.

Kontrol bayrakları (`crates/gpui/src/app.rs:2021+`):

- `cx.stop_propagation()`: aynı tipteki diğer handler'ların çağrılmasını keser
  (mouse'ta z-index'te alt katman, key'de ağaçta üst element).
- `cx.propagate()`: bir önceki `stop_propagation()` etkisini geri alır. Action
  handler'lar bubble fazında default olarak propagation'ı durdurur, bu yüzden
  parent'a düşmesini istiyorsan handler içinden `cx.propagate()` çağır.
- `window.prevent_default()` / `window.default_prevented()`: aynı dispatch içinde
  default element davranışını bastıran pencere bayrağıdır. Mevcut kullanımın
  en görünür örneği mouse down sırasında parent focus transferini engellemektir.

Platform tarafına döndürülen sonuç:

```rust
pub struct DispatchEventResult {
    pub propagate: bool,        // hâlâ bubble ediliyorsa true
    pub default_prevented: bool, // GPUI default davranışı bastırıldı mı
}
```

`PlatformWindow::on_input` callback'i `Fn(PlatformInput) -> DispatchEventResult`
döndürür. Mevcut platform backend'lerinde "event işlendi mi?" kararı esas olarak
`propagate` üzerinden alınır (`!propagate` handled anlamına gelir).
`default_prevented` GPUI dispatch ağacındaki default element davranışını ve
test/diagnostic sonucu taşır; platform default action kontrolü gibi genelleme
yapmadan, handler'ın açıkça kontrol ettiği yerlerde anlamlandır.

Pratik akış:

1. Element listener fire eder, view state günceller, gerekirse `cx.notify()`.
2. Listener event'i tüketmek istiyorsa `cx.stop_propagation()` çağırır.
3. Action handler default davranışı korumak istiyorsa `cx.propagate()` ile
   bubble'ı yeniden açar.
4. Default focus transferi gibi GPUI içi davranış bastırılacaksa
   `window.prevent_default()` çağrılır.

Tuzaklar:

- `capture_*` handler'ları focus path bilinmeden çalışır; pencere global
  shortcut/observer için kullanılır, ama state mutate etmek istiyorsan focused
  element'i runtime'da kontrol et.
- Action propagation davranışı mouse/key event'lerden ters çalışır. Yeni action
  yazarken ezbere `stop_propagation` koymak parent action'larını öldürebilir.
- `default_prevented` genel bir platform cancellation API'si değildir; hangi
  davranışı durdurduğunu anlamak için ilgili element/window handler'ının
  `window.default_prevented()` kontrol edip etmediğine bak.

## 48. Action ve Keymap Runtime Introspection

Action tanımlama ve dispatch önceki bölümlerde var; Zed komut paleti, keymap UI
ve geliştirici diagnostikleri için runtime introspection yüzeyi ayrıca bilinmeli.

Action registry:

- `cx.build_action(name, data) -> Result<Box<dyn Action>, ActionBuildError>`:
  string action adı ve optional JSON verisinden runtime action üretir.
- `cx.all_action_names() -> &[&'static str]`: register edilmiş tüm action
  adlarını döndürür. Registration, action'ın element ağacında available olduğu
  anlamına gelmez.
- `cx.action_schemas(generator)`: non-internal action adları ve JSON schema'ları.
- `cx.action_schema_by_name(name, generator)`: tek action için schema döndürür;
  `None` action yok, `Some(None)` action var ama schema yok demektir.
- `cx.deprecated_actions_to_preferred_actions()`,
  `cx.action_deprecation_messages()`, `cx.action_documentation()`: keymap
  validator, command palette ve migration mesajları için registry metadata'sı.

Available action ve binding sorguları:

- `window.available_actions(cx)`: focused element dispatch path'indeki action
  listener'larını ve global action listener'larını birleştirir. Menü/komut UI'ında
  "bu action şu anda yapılabilir mi?" sorusunun window-spesifik cevabıdır.
- `window.on_action_when(condition, TypeId::of::<A>(), listener)`: paint fazında
  current dispatch node'una conditional low-level action listener ekler. Element
  API'deki `.on_action(...)`/`.capture_action(...)` genelde daha okunur; custom
  element yazmıyorsan bu seviyeye inme.
- `cx.is_action_available(&action)` ve `window.is_action_available(&action, cx)`:
  bool kısayollar.
- `window.is_action_available_in(&action, focus_handle)`: action availability
  sorgusunu belirli focus handle dispatch path'inden yapar.
- `window.bindings_for_action(&action)`: focused context stack'e göre action'a
  giden binding'leri döndürür; display için son binding en yüksek öncelikli kabul
  edilir.
- `window.highest_precedence_binding_for_action(&action)`: aynı sorgunun daha
  ucuz tek sonuç versiyonu.
- `window.bindings_for_action_in(&action, focus_handle)` ve
  `highest_precedence_binding_for_action_in(...)`: sorguyu belirli focus handle
  path'inden yapar.
- `window.bindings_for_action_in_context(&action, KeyContext)`: tek bir elle
  verilmiş context'e göre sorgu.
- `window.highest_precedence_binding_for_action_in_context(&action, KeyContext)`:
  aynı sorgunun tek sonuçlu en yüksek öncelik versiyonu.
- `cx.all_bindings_for_input(&[Keystroke])`: context'e bakmadan input dizisine
  kayıtlı tüm binding'leri listeler.
- `window.possible_bindings_for_input(&[Keystroke])`: multi-stroke/prefix akışında
  current context stack'e göre sıradaki aday binding'leri verir. Tam eşleşen
  action dispatch sonucunu öğrenmek için normal `window.dispatch_keystroke(...)`
  akışı kullanılmalıdır; public `Window::bindings_for_input` helper'ı yoktur.
- `window.pending_input_keystrokes()` ve `window.has_pending_keystrokes()`:
  tamamlanmamış key chord durumunu UI'da göstermek veya test etmek için.

Keystroke global gözlem:

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

- `observe_keystrokes` action/event mekanizmaları çözüldükten sonra çalışır ve
  propagation durdurulduysa çağrılmaz.
- `intercept_keystrokes` dispatch'ten önce çalışır; burada
  `cx.stop_propagation()` çağırmak action dispatch'i engeller.
- Her ikisi de `Subscription` döndürür; kaybedilirse observer düşer.

Tuzaklar:

- `all_action_names` içinde görünen action'ın o anda kullanılabilir olması
  garanti değildir; UI enable/disable için `available_actions` veya
  `is_action_available` kullan.
- Binding display ederken context stack'i hesaba katmayan `cx.all_bindings_for_input`
  yerine mümkünse window/focus handle bazlı sorgu kullan.
- Interceptor'lar global etkilidir; modal özelinde key engelleyeceksen mümkünse
  element action/capture handler ile sınırla.

## 49. Zed Keymap Dosyası, Validator ve Unbind Akışı

GPUI action/keybinding modeli Zed'de `settings::keymap_file` ile kullanıcı
dosyasına bağlanır. Bu bölüm runtime dispatch'ten farklı olarak JSON yükleme,
schema ve dosya güncelleme tarafını kapsar.

Dosya modeli:

- `KeymapFile(Vec<KeymapSection>)`: top-level JSON array.
- `KeymapSection`: context predicate ve binding/unbind map'lerini taşır. Alan
  görünürlüğü dengesizdir — yalnız `pub context: String` dış erişime açıktır;
  `use_key_equivalents: bool`, `unbind: Option<IndexMap<...>>`,
  `bindings: Option<IndexMap<...>>` ve `unrecognized_fields: IndexMap<...>`
  alanları **private**'tır. `KeymapFile` parser'ı bu alanlara crate içinden
  doğrudan erişir; dış kod yalnız `KeymapSection::bindings(&self)` getter'ını
  kullanabilir, bu da `(keystroke, KeymapAction)` çiftlerini dönen tek public
  iterator'dır (`keymap_file.rs:101`). `unbind` ve `use_key_equivalents` için
  ayrı public getter şu sürümde yoktur.
- `KeymapAction(Value)`: `null`, `"action::Name"` veya
  `["action::Name", { ...args... }]` biçimlerini temsil eder.
- `UnbindTargetAction(Value)`: `unbind` map'indeki hedef action değeri.
- `KeymapFileLoadResult::{Success, SomeFailedToLoad, JsonParseFailure}`:
  dosyanın kısmen yüklenebildiği senaryoyu açıkça ayırır.

Yükleme:

```rust
let keymap = KeymapFile::parse(&contents)?;
let result = KeymapFile::load(&contents, cx);
```

`load_asset(asset_path, source, cx)` bundled keymap dosyalarını yükler ve
`KeybindSource` metadata'sı set edebilir. `load_panic_on_failure` sadece
startup/test gibi "asset bozuksa devam etmeyelim" path'leri içindir.

Base keymap:

- `BaseKeymap::{VSCode, JetBrains, SublimeText, Atom, TextMate, Emacs, Cursor,
  None}`.
- Base/default/vim/user binding'leri `KeybindSource` metadata'sı taşır; UI
  hangi binding'in nereden geldiğini bu metadata ile gösterir.

Validator:

- `KeyBindingValidator`: belirli action type'ı için binding doğrulaması yapar.
- `KeyBindingValidatorRegistration(pub fn() -> Box<dyn KeyBindingValidator>)`
  inventory ile toplanır.
- Validator hatası `MarkdownString` döner; keymap UI bunu kullanıcıya
  açıklanabilir hata olarak gösterebilir.

Disable / unbind sentinel action'ları:

GPUI iki ayrı sentinel action sağlar (`gpui::action.rs:425-453`); ikisinin de
runtime davranışı **dispatch etmemek**, fakat keymap dispatch tablosundaki
işlevleri farklıdır:

- **`zed::NoAction`** — `actions!(zed, [NoAction])` ile tanımlı, veri taşımaz.
  Keymap JSON'unda eylem değeri olarak `null` veya `"zed::NoAction"` yazılır:

  ```json
  { "context": "Editor", "bindings": { "cmd-p": null } }
  ```

  Aynı keystroke'a daha düşük öncelikle bağlanmış action'lar bu context için
  iptal edilir; eşleşme `Keymap::resolve_binding` tarafında
  `disabled_binding_matches_context(...)` çağrısıyla **context-aware** olarak
  filtrelenir (`gpui/src/keymap.rs:120`). Yani `NoAction` belirli bir context
  predicate'i içinde tuşu sessize alır.

- **`zed::Unbind(SharedString)`** — `derive(Action)` ile tanımlı, payload bir
  action adıdır. JSON formatı:

  ```json
  ["zed::Unbind", "editor::NewLine"]
  ```

  Keymap parser'ı bu sentinel'ı gördüğünde aynı keystroke'a aynı action adıyla
  ileriden gelen tüm binding'leri **action context'inden bağımsız olarak**
  iptal eder (`keymap.rs:124-128`'deki `is_unbind` kolu). Yani `editor::NewLine`
  için `enter` tuşunu tüm context'lerde unbind etmek için kullanılır.

Sentinel kontrol API'leri:

- `gpui::is_no_action(&dyn Action) -> bool` (`action.rs:445`): `as_any().is::<NoAction>()`
  ile downcast eder. Custom keymap UI veya komut paleti listesinde
  "(disabled)" göstergesi koymak için kullanılabilir.
- `gpui::is_unbind(&dyn Action) -> bool` (`action.rs:450`): aynı şekilde
  `Unbind` instance'ını downcast eder.

`KeymapFile::update_keybinding` `KeybindUpdateOperation::Remove` için bu iki
sentinel'i bağlama göre üretir: user binding'leri `Remove` doğrudan dosyadan
siler, framework/default binding'leri ise sessize alabilmek için kullanıcı
keymap'ine `null` (NoAction) veya `["zed::Unbind", ...]` entry yazar.

Dosya güncelleme:

```rust
let updated = KeymapFile::update_keybinding(
    operation,
    keymap_contents,
    tab_size,
    keyboard_mapper,
)?;
```

- `KeybindUpdateOperation::Add { source, from }`: yeni binding ekler.
- `Replace { source, target, target_keybind_source }`: user binding ise değiştirir;
  user dışı binding değişiyorsa add + suppression unbind'e dönüştürebilir.
- `Remove { target, target_keybind_source }`: user binding'i dosyadan siler;
  user dışı binding'i kaldırmak için `unbind` yazar.
- `KeybindUpdateTarget` action adı, optional action arguments, context ve
  `KeybindingKeystroke` dizisini taşır.

Tuzaklar:

- `use_key_equivalents` yalnızca destekleyen platformlarda anlamlıdır; keyboard
  mapper verilmeden dosya güncelleme doğru keystroke string'i üretemez.
- Non-user binding'i "silmek" gerçek kaynağı değiştirmez; kullanıcı keymap'ine
  suppress eden `unbind` entry'si yazılır.
- Kullanıcı JSON'u bozuksa `update_keybinding` dosyayı değiştirmez; önce parse
  başarıyla geçmelidir.


---

