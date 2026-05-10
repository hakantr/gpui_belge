# 20. Komut Paleti ve Picker

---

## 20.1. CommandPalette: Filter, Aliases ve Interceptor

`crates/command_palette_hooks/` global'leri komut paleti UX'ini şekillendirir.
UI'ı yazmadan önce bu global'leri tanımak gerekir, çünkü odaktaki elementten
toplanan action listesi, görünürlük filtresi ve alternatif komut sonuçları bu
katmandan geçer. Zed başlangıcında `command_palette::init(cx)`,
`command_palette_hooks::init(cx)` çağırır; filtre global'i bu çağrıyla kurulur.

#### CommandPaletteFilter

```rust
pub struct CommandPaletteFilter {
    hidden_namespaces: HashSet<&'static str>,
    hidden_action_types: HashSet<TypeId>,
    shown_action_types: HashSet<TypeId>,
}
```

Erişim:

- `CommandPaletteFilter::try_global(cx) -> Option<&Self>`
- `CommandPaletteFilter::global_mut(cx) -> &mut Self`
- `CommandPaletteFilter::update_global(cx, |filter, cx| ...)`

`update_global` global yoksa yeni global oluşturmaz; `cx.has_global` kontrolünden
sonra çalışır ve global yoksa no-op olur. Bu nedenle kendi test/app
kurulumunda command palette crate'ini kullanmadan yalnızca hook crate'ine
erişiyorsan önce `command_palette_hooks::init(cx)` çağırman gerekir.

Filtre yönetimi:

- `is_hidden(&action) -> bool`: belirli action namespace veya tip olarak gizliyse
  true. Komut paleti UI'ı bu sonuca göre gösterimi atlar. `shown_action_types`
  içinde olan tipler namespace gizli olsa bile görünür kalır.
- `hide_namespace(&'static str)` / `show_namespace(&'static str)`: bir namespace'in
  tüm action'larını gizle/göster (örn. headless paneller için).
- `hide_action_types(impl IntoIterator<Item = &TypeId>)` /
  `show_action_types(impl IntoIterator<Item = &TypeId>)`: belirli action tiplerini
  topluca yönetir. `hide_action_types` tipi `hidden_action_types` içine ekler ve
  `shown_action_types` içinden çıkarır; `show_action_types` bunun tersini yapar.

Tipik kullanım `CommandPaletteFilter::update_global(cx, |filter, _| { ... })`
içinde aynı anda hem `hide_namespace` hem `hide_action_types` çağırarak feature
flag tabanlı komut görünürlüğünü tek seferde değiştirmektir. Vim entegrasyonu
vim modu açıldığında `vim` namespace'ini gösterir ve modu kapatınca tekrar
gizler.

#### CommandAliases (WorkspaceSettings)

`WorkspaceSettings::command_aliases: HashMap<String, ActionName>`. Kullanıcı
JSON'una `"command_aliases": { "ag": "search::ToggleSearch" }` yazınca komut
paleti query tam olarak `ag` olduğunda sorguyu `search::ToggleSearch` string'ine
çevirir. Bu çeviri fuzzy eşleşme ve interceptor çağrısından önce yapılır; alias
bir action nesnesi üretmez, yalnızca palette sorgusunu canonical action adına
yaklaştırır. Yeni komut sunarken alias sözleşmesini bozmaktan kaçın; eski adları
keymap tarafında desteklemek için `#[action(deprecated_aliases = [...])]`, komut
paleti kullanıcı sorgusu içinse `command_aliases` kullanılır.

#### CommandInterceptor

Komut paletindeki "tam string'i komuta dönüştür" davranışı (örn. vim ex
komutları, line jump `:42`) `GlobalCommandPaletteInterceptor` üzerinden çalışır:

```rust
GlobalCommandPaletteInterceptor::set(cx, |query, workspace, cx| {
    parse_query_to_actions(query, workspace, cx)
});
```

İmzalar:

- `set(cx, Fn(&str, WeakEntity<Workspace>, &mut App) -> Task<CommandInterceptResult>)`
- `clear(cx)`: interceptor'ı kaldırır.
- `intercept(query, workspace, cx) -> Option<Task<CommandInterceptResult>>`:
  komut paleti UI'ı her tuş vuruşunda çağırır.

`CommandInterceptResult`:

```rust
pub struct CommandInterceptResult {
    pub results: Vec<CommandInterceptItem>,
    pub exclusive: bool, // true ise normal action eşleşmeleri gizlenir
}

pub struct CommandInterceptItem {
    pub action: Box<dyn Action>,
    pub string: String,             // palette'te gösterilecek metin
    pub positions: Vec<usize>,      // highlight pozisyonları
}
```

Tipik akış: vim modu açıkken `:w<CR>` gibi komutları intercept edip
`SaveActiveItem` action'ına çevirir; başka extension/agent tipi de aynı
mekanizmayı kullanır. Komut paleti, interceptor sonuçlarını normal fuzzy action
eşleşmeleriyle birleştirir. Aynı action zaten normal eşleşmelerde varsa
interceptor sonucu eklenmeden önce normal sonuçtan çıkarılır. `exclusive = true`
ise yalnızca interceptor sonuçları gösterilir; `exclusive = false` ise
interceptor sonuçları listenin başına eklenip normal eşleşmeler arkadan gelir.

#### Action Documentation ve Deprecation Mesajları

Action trait'inin `documentation()`, `deprecation_message()` ve
`deprecated_aliases()` yüzeyi command palette ile karıştırılmamalıdır:

- Komut paleti satırında şu anda humanized action adı ve mevcut keybinding
  gösterilir; action documentation/deprecation mesajı palette satırında ayrı
  bir açıklama olarak render edilmez.
- `#[action(deprecated_aliases = ["foo::OldName"])]` eski adı
  `ActionRegistry::build_action` içinde hala inşa edilebilir yapar ve keymap JSON
  schema/uyarı akışına yansır. Komut paleti ise `window.available_actions(cx)`
  ile odaktaki dispatch path'ten action tiplerini toplar ve
  `build_action_type(type_id)` ile canonical action adını üretir; eski alias'ı
  ayrı palette satırı olarak listelemez.
- Doc comment yazmak yine önemlidir: derive macro bunu `documentation()`'a
  çevirir ve keymap editor/JSON schema gibi action keşif yüzeyleri bu bilgiyi
  kullanır.
- `#[action(deprecated = "...")]` de keymap schema/uyarı akışını besler. Komut
  paleti kullanıcı sorgusuna eski kısa ad vermek istiyorsan
  `WorkspaceSettings::command_aliases` kullanmalısın.

#### Tuzaklar

- `CommandPaletteFilter` global state'tir; testlerde bir feature açıp kapatınca
  sonraki test başlamadan reset etmen gerekebilir.
- `hide_action_types` ile gizlenen tip register edilmiş olmalı; aksi halde
  filtreye eklendiği halde komut paleti listesinde zaten görünmez.
- `Interceptor::set` mevcut interceptor'ı ezer; çoklu kaynak gerekiyorsa zinciri
  kendi koduna kuracaksın (örn. önce vim, başarısızsa AI agent gibi).
- `CommandInterceptResult::exclusive = true` yoğunlukla kullanılırsa kullanıcı
  normal action listesinden komutlara ulaşamaz; gerçekten "tek doğru sonuç var"
  iken set et.

## 20.2. CommandPalette Runtime Akışı, Fuzzy Arama ve Geçmiş

`crates/command_palette/src/command_palette.rs` Zed'in gerçek komut paleti
akışıdır. Başlatma ve açma sırası:

1. `command_palette::init(cx)` hook global'lerini kurar ve
   `cx.observe_new(CommandPalette::register).detach()` ile her yeni
   `Workspace` için `zed_actions::command_palette::Toggle` action'ını register
   eder.
2. `CommandPalette::toggle(workspace, query, window, cx)` mevcut focus handle'ı
   alır. Focus yoksa palette açılmaz. Sonra `workspace.toggle_modal(...)` ile
   `CommandPalette` modal view olarak oluşturulur.
3. `CommandPalette::new(previous_focus_handle, query, workspace, window, cx)`
   `window.available_actions(cx)` çağırır. Bu liste bütün registry değil, odaktaki
   dispatch path üzerinde `.on_action(...)` ile bağlanmış action'lar ve global
   action listener'larıdır.
4. Her action `CommandPaletteFilter::is_hidden` ile elenir ve görünen action'lar
   `humanize_action_name(action.name())` sonucuyla `Command { name, action }`
   haline getirilir.
5. UI `Picker::uniform_list(delegate, window, cx)` ile kurulur, sonra başlangıç
   query'si `picker.set_query(query, window, cx)` ile editöre yazılır.

Arama akışı:

- `humanize_action_name("editor::GoToDefinition")` sonucu
  `"editor: go to definition"` olur; `go_to_line::Deploy` gibi snake case adlar
  boşluklu hale gelir.
- `normalize_action_query(input)` trim yapar, ardışık whitespace'i tek boşluğa
  indirir, `_` karakterlerini boşluğa çevirir ve ardışık `::` yazımlarını arama
  için sadeleştirir.
- `WorkspaceSettings::command_aliases` tam query eşleşmesini canonical action adı
  string'ine çevirir.
- Query Zed link ise (`parse_zed_link`) palette `OpenZedUrl { url }` action'ını
  interceptor sonucu gibi listeye ekler.
- Normal command listesi background executor üzerinde
  `fuzzy_nucleo::match_strings_async(..., Case::Smart, LengthPenalty::On, 10000,
  ...)` ile eşleşir. Eşleşmeler hit count'a göre, sonra alfabetik ada göre
  sıralanmış komut havuzundan gelir.
- Interceptor sonucu varsa `matches_updated` içinde normal eşleşmelerle
  birleştirilir; duplicate action'lar `Action::partial_eq` ile ayıklanır.

Geçmiş ve sıralama `CommandPaletteDB` içindedir:

- SQLite domain adı `CommandPaletteDB`; tablo `command_invocations`.
- `write_command_invocation(command_name, user_query)` çalıştırılan komutu ve
  kullanıcının yazdığı sorguyu kaydeder. Tablo 1000 kayıt üstüne çıktığında en
  eski kayıt silinir.
- `list_commands_used()` komut başına invocation sayısı ve son kullanım zamanını
  döndürür; palette açılırken hit count yüksek olan komutlar önce sıralanır.
- `list_recent_queries()` boş olmayan kullanıcı sorgularını son kullanım zamanına
  göre getirir; command palette yukarı/aşağı gezinirken aynı prefix ile query
  geçmişine dönebilir.

Onay davranışı:

- Normal confirm seçili command'i alır, telemetry'ye
  `source = "command palette"` ile yazar, `CommandPaletteDB` kaydını background
  task olarak başlatır, eski focus handle'a geri odaklanır, modalı dismiss eder
  ve `window.dispatch_action(action, cx)` çağırır.
- Secondary confirm seçili action'ın canonical adını `String` olarak alıp
  `zed_actions::ChangeKeybinding { action: action_name.to_string() }` action'ını
  dispatch eder. Buradaki `action` alanı action nesnesi değil, registry name
  string'idir (örn. `"editor::GoToDefinition"`); keymap editor bu string'i alır
  ve binding ekleme akışını başlatır. Footer'daki "Add/Change Keybinding" butonu
  da aynı yolu kullanır.
- `finalize_update_matches` pending background sonucu en fazla kısa bir süre
  foreground'da bekleyebilir; bu, palette açılırken boş liste parlamasını ve
  otomasyon sırasında erken enter basılmasını azaltır.

## 20.3. Picker, PickerDelegate ve PickerPopoverMenu

`crates/picker/` command palette dışında da kullanılan genel seçim/arama
bileşenidir. Bir picker yazarken ana iş `PickerDelegate` implementasyonudur:

```rust
pub trait PickerDelegate: Sized + 'static {
    type ListItem: IntoElement;

    fn match_count(&self) -> usize;
    fn selected_index(&self) -> usize;
    fn set_selected_index(&mut self, ix: usize, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn placeholder_text(&self, window: &mut Window, cx: &mut App) -> Arc<str>;
    fn update_matches(&mut self, query: String, window: &mut Window, cx: &mut Context<Picker<Self>>) -> Task<()>;
    fn confirm(&mut self, secondary: bool, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn dismissed(&mut self, window: &mut Window, cx: &mut Context<Picker<Self>>);
    fn render_match(&self, ix: usize, selected: bool, window: &mut Window, cx: &mut Context<Picker<Self>>) -> Option<Self::ListItem>;
}
```

Sık override edilen davranışlar:

- `select_history(Direction, query, ...) -> Option<String>`: yukarı/aşağı okları
  default seçim yerine query geçmişinde gezdirmek için.
- `can_select(ix, ...)`, `select_on_hover()`, `selected_index_changed(...)`:
  seçilebilir satırları ve hover/selection yan etkilerini yönetir.
- `no_matches_text(...)`, `render_header(...)`, `render_footer(...)`:
  boş durum ve sabit üst/alt alanlar.
- `documentation_aside(...)` ve `documentation_aside_index()`: seçili/hover edilen
  öğe için sağda dokümantasyon paneli göstermek.
- `confirm_update_query(...)`, `confirm_input(...)`, `confirm_completion(...)`:
  enter'ın seçimi onaylamak yerine query'yi dönüştürdüğü veya literal input'u
  action'a çevirdiği picker türleri.
- `editor_position() -> PickerEditorPosition::{Start, End}`: arama editörünün
  listenin üstünde mi altında mı duracağını belirler.
- `finalize_update_matches(query, duration, ...) -> bool`: background matching'i
  kısa süre bloklayarak ilk render/confirm yarışını azaltır.

Constructor seçimi:

- `Picker::uniform_list(delegate, window, cx)`: aramalı picker; tüm satırlar aynı
  yükseklikteyse tercih edilir ve `gpui::uniform_list` kullanır.
- `Picker::list(delegate, window, cx)`: aramalı picker; satır yükseklikleri
  değişkense kullanılır.
- `Picker::nonsearchable_uniform_list(...)` ve `Picker::nonsearchable_list(...)`:
  arama editörü olmayan seçim listeleri.

Kullanılabilir ayarlar:

- `width(...)`, `max_height(...)`, `widest_item(...)`: ölçü ve liste genişliği.
- `show_scrollbar(bool)`: dış scrollbar gösterimi.
- `modal(bool)`: picker kendi başına modal gibi render ediliyorsa elevation verir;
  daha büyük bir modalın parçasıysa `false` yapılabilir.
- `list_measure_all()`: `ListState` tabanlı listede tüm öğeleri ölçmek için.
- `refresh(&mut self, window, cx)`, `update_matches_with_options(...,
  ScrollBehavior)`: match akışını dışarıdan tetikleyen mutable yardımcılar.
- `query(&self, cx: &App) -> String`: editördeki anlık sorguyu okur.
- `set_query(&self, query: &str, window: &mut Window, cx: &mut App)`: editör
  metnini değiştirir; `&self` aldığına dikkat — picker entity'sini `update`
  bloğunun içine sokmak şart değil, doğrudan picker referansından çağrılabilir.
  `cx` burada `Context<...>` değil `&mut App` olduğu için entity context
  gerekiyorsa update bloğundan dışarı çıkmak gerekebilir.

Action/key context:

- Render root `"Picker"` key context'ini kurar.
- `menu::SelectNext`, `menu::SelectPrevious`, `menu::SelectFirst`,
  `menu::SelectLast`, `menu::Cancel`, `menu::Confirm`,
  `menu::SecondaryConfirm`, `picker::ConfirmCompletion` ve `picker::ConfirmInput`
  action'larını dinler.
- Click confirm sırasında `cx.stop_propagation()` ve `window.prevent_default()`
  çağrılır; bu yüzden picker satırına tıklama dış elementlere sızmaz.

`PickerPopoverMenu<T, TT, P>` bir picker'ı `ui::PopoverMenu` içine koyan ince
sarmaldır. `new(picker, trigger, tooltip, anchor, cx)` picker'ın
`DismissEvent`'ini popover dismiss event'ine bağlar; `with_handle(...)` ve
`offset(...)` ile dış popover handle/konum ayarı yapılır. Picker bir toolbar
butonu veya popover tetikleyicisi arkasında açılacaksa doğrudan modal yerine bu
sarmalı kullan.


---

