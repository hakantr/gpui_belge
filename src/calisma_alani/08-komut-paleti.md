# Komut Paleti

`command_palette` ve `command_palette_hooks` crate'leri çalışma alanı katmanının üstüne, action keşfi ve action çalıştırma için ortak bir modal arayüz koyar. Zed başlangıcında `command_palette::init(cx)` `command_palette_hooks::init(cx)` çağırır; filtre global'i bu çağrı sırasında kurarsın.

---

## CommandPaletteFilter

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `CommandPaletteFilter` | Metotlar | `global_mut`, `hide_action_types`, `hide_namespace`, `is_hidden`, `show_action_types`, `show_namespace`, `try_global` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


`CommandPaletteFilter`, komut paletinde hangi namespace'lerin ve action tiplerinin görüneceğini kontrol eden global bir filtredir. Üç set üzerinden çalışır:

```rust
pub struct CommandPaletteFilter {
    hidden_namespaces: HashSet<&'static str>,
    hidden_action_types: HashSet<TypeId>,
    shown_action_types: HashSet<TypeId>,
}
```

Erişim noktaları şunlardır:

- `CommandPaletteFilter::try_global(cx) -> Option<&Self>`
- `CommandPaletteFilter::global_mut(cx) -> &mut Self`
- `CommandPaletteFilter::update_global(cx, |filtre, cx| ...)`

`update_global` global yoksa yenisini oluşturmaz; `cx.has_global` kontrolünden sonra çalışır ve global mevcut değilse no-op kalır. Bu nedenle command palette crate'i kullanılmadan yalnızca hook crate'ine erişiliyorsa önce `command_palette_hooks::init(cx)` çağrılmalıdır.

**Filtre yönetimi.** Komut paletinde hangi action'ların görünür kalacağı filtre üzerinden ayarlanır:

- `is_hidden(&eylem) -> bool` — belirli action namespace veya tip olarak gizliyse `true` döner. Komut paleti UI'ı bu sonuca göre gösterimi atlar. `shown_action_types` içine alınmış tipler, namespace gizli olsa bile görünür kalır.
- `hide_namespace(&'static str)` / `show_namespace(&'static str)` — bir namespace'in tüm action'larını gizler veya gösterir (örneğin başsız paneller için).
- `hide_action_types(impl IntoIterator<Item = &TypeId>)` ve `show_action_types(impl IntoIterator<Item = &TypeId>)` — belirli action tiplerini topluca yönetir. `hide_action_types` tipi `hidden_action_types` setine ekler ve `shown_action_types` setinden çıkarır; `show_action_types` ise tersini yapar.

Tipik bir kullanım, `CommandPaletteFilter::update_global(cx, |filtre, _| { ... })` bloğu içinde aynı anda hem `hide_namespace` hem `hide_action_types` çağırarak özellik bayrağı tabanlı komut görünürlüğünü tek seferde değiştirmektir. Örneğin Vim entegrasyonu, vim modu açıldığında `vim` namespace'ini gösterir ve modu kapandığında tekrar gizler.

---

## CommandAliases (WorkspaceSettings)

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `WorkspaceSettings` | Alanlar 1 | `active_pane_modifiers`, `autosave`, `bottom_dock_layout`, `cli_default_open_behavior`, `close_on_file_delete`, `close_panel_on_toggle`, `command_aliases`, `confirm_quit`, `drop_target_size`, `focus_follows_mouse`, `max_tabs`, `on_last_window_closed`, `pane_split_direction_horizontal`, `pane_split_direction_vertical`, `resize_all_panels_in_dock`, `restore_on_file_reopen`, `restore_on_startup` | Public veri alanları; runtime, stil veya ayar sözleşmesinin taşınan parçalarıdır. |
| `WorkspaceSettings` | Alanlar 2 | `show_call_status_icon`, `text_rendering_mode`, `use_system_path_prompts`, `use_system_prompts`, `use_system_window_tabs`, `when_closing_with_no_tabs`, `window_decorations`, `zoomed_padding` | Workspace davranışı, prompt/pencere politikası ve görünüm ayarlarının kalan alanlarıdır. |


`WorkspaceSettings::command_aliases: HashMap<String, ActionName>`. Kullanıcı JSON'una `"command_aliases": { "ag": "search::ToggleSearch" }` yazıldığında komut paleti, sorgu tam olarak `ag` olduğunda bunu `search::ToggleSearch` string'ine çevirir. Bu çeviri fuzzy eşleşme ve interceptor çağrısından önce yapılır; alias bir action nesnesi üretmez, yalnızca palet sorgusunu canonical action adına yaklaştırır. Yeni uygulamada alias, kullanıcının kısa sorgu yazmasını kolaylaştıran bir palet kısayolu olarak düşünmen gerekir. Keymap tarafında canonical action adı kullanman gerekir.

`WorkspaceSettings` aynı zamanda tab ve dock davranışı için `max_tabs`, `bottom_dock_layout`, `resize_all_panels_in_dock`, `close_panel_on_toggle`, `zoomed_padding` ve `active_pane_modifiers` alanlarını; pencere yaşam döngüsü için `confirm_quit`, `when_closing_with_no_tabs`, `on_last_window_closed`, `restore_on_startup`, `restore_on_file_reopen`, `close_on_file_delete`, `window_decorations` ve `use_system_window_tabs` kararlarını taşır. Prompt ve render politikası `use_system_prompts`, `use_system_path_prompts`, `text_rendering_mode` ve `show_call_status_icon` alanlarından okunur; split yönü de `pane_split_direction_horizontal` ve `pane_split_direction_vertical` ile workspace settings katmanında kalır.

---

## CommandInterceptor

Komut paletindeki "tam string'i komuta dönüştür" davranışı (örneğin Vim ex komutları, line jump `:42`) `GlobalCommandPaletteInterceptor` üzerinden çalışır:

```rust
GlobalCommandPaletteInterceptor::set(cx, |sorgu, calisma_alani, cx| {
    sorgudan_eylemlere_ayristir(sorgu, calisma_alani, cx)
});
```

İmzalar şu şekildedir:

- `set(cx, Fn(&str, WeakEntity<Workspace>, &mut App) -> Task<CommandInterceptResult>)`
- `clear(cx)` — interceptor'ı kaldırır.
- `intercept(sorgu, calisma_alani, cx) -> Option<Task<CommandInterceptResult>>` — komut paleti UI'ı her tuş vuruşunda çağırır.

`CommandInterceptResult` yapısı şu şekildedir:

```rust
pub struct CommandInterceptResult {
    pub results: Vec<CommandInterceptItem>,
    pub exclusive: bool, // true ise normal action eşleşmeleri gizlenir
}

pub struct CommandInterceptItem {
    pub action: Box<dyn Action>,
    pub string: String,             // palette'te gösterilecek metin
    pub positions: Vec<usize>,      // vurgu konumları
}
```

Tipik akış şudur: Vim modu açıkken `:w<CR>` gibi komutlar intercept edilip `SaveActiveItem` action'ına çevrilir. Benzer şekilde başka extension veya agent türleri de aynı mekanizmayı kullanır. Komut paleti interceptor sonuçlarını normal fuzzy action eşleşmeleriyle birleştirir. Aynı action zaten normal eşleşmelerde yer alıyorsa interceptor sonucu eklenmeden önce normal sonuçtan çıkarılır. `exclusive = true` olduğunda yalnız interceptor sonuçları gösterilir; `exclusive = false` ise interceptor sonuçları listenin başına eklenir ve normal eşleşmeler arkadan gelir.

---

## Action Documentation

Action trait'inin `documentation()` yüzeyi komut paleti ile karıştırılmamalıdır:

- Komut paleti satırında şu anda insancıllaştırılmış action adı ve mevcut keybinding görünür; action documentation palet satırında ayrı bir açıklama olarak çizilmez.
- Komut paleti `window.available_actions(cx)` ile odaktaki dispatch path'ten action tiplerini toplar; `build_action_type(type_id)` ile canonical action adını üretir.
- Doc yorumu yazımı yine önemlidir: derive makrosu bunu `documentation()` üzerinden ifşa eder ve keymap editörü ile JSON schema gibi action keşif yüzeyleri bu bilgiyi kullanır.

---

## Çalışma Zamanı Akışı

Zed'in gerçek komut paleti akışıdır. Başlatma ve açma sırası şu adımlarla işler:

1. `command_palette::init(cx)` hook global'lerini kurar ve `cx.observe_new(CommandPalette::register).detach()` ile her yeni `Workspace` için `zed_actions::command_palette::Toggle` action'ını kaydeder.
2. `CommandPalette::toggle(calisma_alani, sorgu, window, cx)` mevcut focus handle'ını alır. Focus yoksa palet açılmaz. Ardından `calisma_alani.toggle_modal(...)` ile `CommandPalette` modal view olarak oluşturulur.
3. `CommandPalette::new(onceki_odak_tutamagi, sorgu, calisma_alani, window, cx)` `window.available_actions(cx)` çağırır. Bu liste bütün registry değildir; odaktaki dispatch path üzerinde `.on_action(...)` ile bağlı action'lar ve global action dinleyicileridir.
4. Her action `CommandPaletteFilter::is_hidden` ile elenir ve görünen action'lar `humanize_action_name(action.name())` sonucuyla `Command { name, action }` haline getirilir.
5. UI `Picker::uniform_list(temsilci, window, cx)` ile kurulur; ardından başlangıç sorgusu `secici.set_query(sorgu, window, cx)` ile editöre yazılır.

`CommandPalette::set_query(sorgu, window, cx)` açık palette sorguyu programatik olarak günceller. `CommandPaletteDelegate` public bir tiptir ve `Picker` delegate davranışını taşır; normal tüketici akışında doğrudan kurulmaz, `CommandPalette::toggle` üzerinden oluşturulur.

**Arama akışı.** Sorgu birkaç aşamadan geçer:

- `humanize_action_name("editor::GoToDefinition")` sonucu `"editor: go to definition"` olur; `go_to_line::Deploy` gibi snake case adlar boşluklu hale gelir.
- `normalize_action_query(girdi)` kırpar, ardışık boşluğu tek boşluğa indirir, `_` karakterlerini boşluğa çevirir ve ardışık `::` yazımlarını arama için sadeleştirir.
- `WorkspaceSettings::command_aliases` tam sorgu eşleşmesini canonical action adı string'ine çevirir.
- Sorgu bir Zed bağlantısı ise (`parse_zed_link`) palette `OpenZedUrl { url }` action'ını interceptor sonucu gibi listeye ekler.
- Normal komut listesi arka plan executor'ı üzerinde `fuzzy_nucleo::match_strings_async(..., Case::Smart, LengthPenalty::On, 10000, ...)` ile eşleştirilir. Eşleşmeler hit sayısına göre, sonra alfabetik ada göre sıralanan komut havuzundan gelir.
- Interceptor sonucu varsa `matches_updated` içinde normal eşleşmelerle birleştirilir; tekrarlanan action'lar `Action::partial_eq` ile ayıklanır.

**Geçmiş ve sıralama.** `CommandPaletteDB` SQLite tablosu komut geçmişini tutar:

- SQLite domain adı `CommandPaletteDB`'dir; tablo `command_invocations`.
- `write_command_invocation(command_name, user_query)` çalıştırılan komutu ve kullanıcının yazdığı sorguyu kaydeder. Tablo 1000 kaydı geçtiğinde en eski kayıt silinir.
- `get_command_usage(command)` tek komut için kullanım sayısı ve son kullanım zamanını döndürür.
- `list_commands_used()` komut başına invocation sayısı ile son kullanım zamanını döndürür; palet açılırken hit sayısı yüksek komutlar önce sıralanır.
- `list_recent_queries()` boş olmayan kullanıcı sorgularını son kullanım zamanına göre getirir; komut paletinde yukarı/aşağı gezinilirken aynı önek ile sorgu geçmişine dönülebilir.

**Onay davranışı.** Onay akışları iki şekilde işler:

- Normal onay seçili komutu alır, telemetry'ye `source = "command palette"` ile yazar, `CommandPaletteDB` kaydını bir arka plan görevi olarak başlatır, önceden odakta olan handle'a geri odaklanır, modalı kapatır ve `window.dispatch_action(action, cx)` çağırır.
- İkincil onay seçili action'ın canonical adını `String` olarak alır ve `zed_actions::ChangeKeybinding { action: action_name.to_string() }` action'ını dispatch eder. Buradaki `action` alanı bir action nesnesi değil, registry name string'idir (örneğin `"editor::GoToDefinition"`); keymap editörü bu string'i alır ve bağlama ekleme akışını başlatır. Footer'daki "Add/Change Keybinding" butonu da aynı yolu kullanır.
- `finalize_update_matches` bekleyen arka plan sonucu en fazla kısa bir süre ön planda bekleyebilir; bu, palet açılırken boş liste titremesini ve otomasyon sırasında erken enter basma durumunu azaltır.

---

## Public API kapsamı

Komut paleti yüzeyinde her public taşıyıcı için ayrı öğretici başlık açmak gereksiz olur; çoğu tip paletin tek runtime akışındaki küçük bir rolü taşır. Aşağıdaki tablo, `command_palette` ve `command_palette_hooks` public yüzeyini doğal kullanım noktasına bağlar.

| API | Görev |
| ----- | ------- |
| `command_palette` | Workspace modalı olarak çalışan komut paleti UI'ının crate/modül sınırıdır. |
| `command_palette::init` | Hook global'lerini kurar ve yeni `Workspace` entity'leri için `zed_actions::command_palette::Toggle` action'ını kaydeder. |
| `CommandPalette` | `ModalView`, `Focusable`, `Render` ve `EventEmitter<DismissEvent>` davranışını taşır; public tüketimde `toggle` ve `set_query` önemlidir. |
| `CommandPalette::toggle` | Önceki focus handle'ını saklar, workspace modal layer içinde paleti açar ve başlangıç sorgusunu `Picker` editörüne verir. |
| `CommandPalette::set_query` | Açık palette sorguyu dışarıdan değiştirir; UI testleri ve "paleti belirli aramayla aç" akışları için kullanılır. |
| `CommandPaletteDelegate` | Komut listesi, fuzzy sonuçlar, interceptor sonucu, seçim ve geçmiş sorgu durumunu taşır; doğrudan kurulmak yerine `CommandPalette::toggle` üzerinden oluşur. |
| `humanize_action_name` | `editor::GoToDefinition` gibi canonical action adlarını palette okunur hale getirir. |
| `normalize_action_query` | `_` karakterlerini boşluğa çevirir, ardışık boşluk ve `::` tekrarlarını sadeleştirir. |
| `command_palette_hooks` | Filtre ve interceptor global'lerini UI crate'inden ayrıştıran hook crate'idir. |
| `CommandPaletteFilter` | Namespace ve action tipi bazlı gizleme/gösterme kararını verir. |
| `CommandInterceptItem` | `action`, görüntülenecek `string` ve vurgu `positions` alanlarını taşır. |
| `CommandInterceptResult` | `results` listesini ve normal sonuçların gösterilip gösterilmeyeceğini belirleyen `exclusive` bayrağını taşır. |
| `GlobalCommandPaletteInterceptor` | `set`, `clear` ve `intercept` ile sorgu string'ini özel action sonuçlarına çevirmek için kullanılır. |

`CommandInterceptItem` ve `CommandInterceptResult` alanları bu tabloda yeterince açıklanır: `action` çalıştırılacak gerçek action nesnesidir, `string` palette görünen metindir, `positions` vurgulama indeksleridir; `exclusive` true olduğunda normal action eşleşmeleri gizlenir.

---

## Tuzaklar

Filter ve interceptor kullanımında karşılaşılan yaygın sorunlar:

- `CommandPaletteFilter` global durumdur; testlerde bir özellik açıldığında sonraki test başlamadan sıfırlanması gerekebilir.
- `hide_action_types` ile gizlenen tipin kaydedilmiş olması gerekir; aksi halde filtreye eklenmesine rağmen komut paleti listesinde zaten görünmez.
- `Interceptor::set` mevcut interceptor'ı ezer; çoklu kaynak gerektiğinde zincirin kendi kodunda kurman gerekir (örneğin önce Vim, başarısızsa AI agent gibi).
- `CommandInterceptResult::exclusive = true` yoğun şekilde kullanıldığında kullanıcı normal action listesinden komutlara ulaşamaz; gerçekten "tek doğru sonuç var" durumunda ayarlanır.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `CommandPalette`

| Grup | API | Not |
|---|---|---|
| Metotlar | `set_query`, `toggle` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `CommandInterceptItem`

| Grup | API | Not |
|---|---|---|
| Alanlar | `action`, `positions`, `string` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CommandInterceptResult`

| Grup | API | Not |
|---|---|---|
| Alanlar | `exclusive`, `results` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GlobalCommandPaletteInterceptor`

| Grup | API | Not |
|---|---|---|
| Metotlar | `clear`, `intercept`, `set` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
