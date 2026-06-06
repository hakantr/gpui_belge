# Komut Paleti

`command_palette` ve `command_palette_hooks` crate'leri, çalışma alanı katmanının üzerinde yer alarak eylem (action) keşfi ve eylemlerin tetiklenmesi için ortak bir modal arayüz sunar. Zed başlangıç (startup) sürecinde `command_palette::init(cx)` ve `command_palette_hooks::init(cx)` çağrıları yapılır; filtre global'i de bu çağrı esnasında kurulur.

---

## CommandPaletteFilter

`CommandPaletteFilter`, komut paletinde hangi namespace (ad uzayı) ve action tiplerinin görüneceğini kontrol eden global bir filtredir. Üç set üzerinden çalışır:

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

`update_global` metodu, global filtre mevcut değilse yenisini oluşturmaz; `cx.has_global` kontrolünden sonra çalışır ve global mevcut değilse no-op (işlemsiz) kalır. Bu nedenle command palette crate'i kullanılmadan doğrudan hook crate'ine erişiliyorsa, öncesinde `command_palette_hooks::init(cx)` çağrısının yapılması gerekir.

**Filtre Yönetimi.** Komut paletinde hangi eylemlerin görünür kalacağı filtre üzerinden ayarlanır:

- `is_hidden(&eylem) -> bool` — Belirli bir action, namespace veya tip olarak gizlenmişse `true` döner. Komut paleti arayüzü bu sonuca göre ilgili eylemi göstermeden atlar. `shown_action_types` setine eklenen tipler, namespace gizli olsa dahi görünür kalır.
- `hide_namespace(&'static str)` / `show_namespace(&'static str)` — Bir namespace kapsamındaki tüm action'ları gizler veya gösterir (örneğin başsız paneller için).
- `hide_action_types(impl IntoIterator<Item = &TypeId>)` ve `show_action_types(impl IntoIterator<Item = &TypeId>)` — Belirli action tiplerini topluca yönetmeye yarar. `hide_action_types` metodu tipi `hidden_action_types` setine ekler ve `shown_action_types` setinden çıkarır; `show_action_types` ise bu işlemin tersini yapar.

Tipik bir kullanım senaryosu, `CommandPaletteFilter::update_global(cx, |filtre, _| { ... })` bloğu içinde hem `hide_namespace` hem de `hide_action_types` metotlarını çağırarak, özellik bayrağına (feature flag) bağlı komut görünürlüğünü tek seferde değiştirmektir. Örneğin Vim entegrasyonu, vim modu etkinleştirildiğinde `vim` namespace'ini görünür kılar ve mod kapatıldığında bu namespace'i tekrar gizler.

---

## CommandAliases (WorkspaceSettings)

`WorkspaceSettings::command_aliases: HashMap<String, ActionName>` yapısı, komut takma adlarını yönetir. Kullanıcı ayarları JSON dosyasına `"command_aliases": { "ag": "search::ToggleSearch" }` yazıldığında, komut paleti arama sorgusu tam olarak `ag` olduğunda bunu otomatik olarak `search::ToggleSearch` metnine dönüştürür. Bu dönüşüm fuzzy (bulanık) eşleştirme ve interceptor çağrılarından önce gerçekleştirilir; alias (takma ad) doğrudan bir action nesnesi üretmez, yalnızca palet sorgusunu canonical (standart) action adına yaklaştırır. Yeni bir eylem uygulandığında alias, kullanıcının kısa sorgular yazarak komutlara hızlı erişmesini sağlayan bir palet kısayolu olarak düşünülmelidir. Keymap tarafında ise her zaman canonical action adının kullanılması gerekir.

`WorkspaceSettings` aynı zamanda tab ve dock davranışları için `max_tabs`, `bottom_dock_layout`, `resize_all_panels_in_dock`, `close_panel_on_toggle`, `zoomed_padding` ve `active_pane_modifiers` alanlarını; pencere yaşam döngüsü için `confirm_quit`, `when_closing_with_no_tabs`, `on_last_window_closed`, `restore_on_startup`, `restore_on_file_reopen`, `close_on_file_delete`, `window_decorations` ve `use_system_window_tabs` kararlarını taşır. Prompt ve render politikası `use_system_prompts`, `use_system_path_prompts`, `text_rendering_mode` ve `show_call_status_icon` alanlarından okunur; split yönü de `pane_split_direction_horizontal` ve `pane_split_direction_vertical` ile workspace settings katmanında kalır.

---

## CommandInterceptor

Komut paletindeki "tam sorguyu doğrudan komuta dönüştürme" davranışı (örneğin Vim ex komutları veya satıra atlama `:42` gibi) `GlobalCommandPaletteInterceptor` aracılığıyla çalışır:

```rust
GlobalCommandPaletteInterceptor::set(cx, |sorgu, calisma_alani, cx| {
    sorgudan_eylemlere_ayristir(sorgu, calisma_alani, cx)
});
```

Arayüz imzaları şu şekildedir:

- `set(cx, Fn(&str, WeakEntity<Workspace>, &mut App) -> Task<CommandInterceptResult>)`
- `clear(cx)` — Interceptor'ı kaldırır.
- `intercept(sorgu, calisma_alani, cx) -> Option<Task<CommandInterceptResult>>` — Komut paleti arayüzü tarafından her tuş vuruşunda tetiklenir.

`CommandInterceptResult` yapısı şu şekildedir:

```rust
pub struct CommandInterceptResult {
    pub results: Vec<CommandInterceptItem>,
    pub exclusive: bool, // true ise normal fuzzy action eşleşmeleri gizlenir
}

pub struct CommandInterceptItem {
    pub action: Box<dyn Action>,
    pub string: String,             // palette gösterilecek metin
    pub positions: Vec<usize>,      // vurgulanacak karakterlerin konumları
}
```

Tipik çalışma akışı şu şekildedir: Vim modu açıkken `:w<CR>` benzeri komutlar intercept edilip (kesilip) `VimSave` gibi Vim'e özgü action'lara veya `workspace::Save`/`workspace::CloseActiveItem` gibi genel çalışma alanı action'larına dönüştürülür. Benzer şekilde diğer extension veya agent türleri de bu mekanizmayı kullanır. Komut paleti, interceptor sonuçlarını normal fuzzy action eşleşmeleriyle birleştirir. Aynı action zaten normal eşleşmeler içinde yer alıyorsa, interceptor sonucu listeye eklenmeden önce normal sonuçlar arasından çıkarılır. `exclusive = true` olduğunda yalnızca interceptor sonuçları gösterilir; `exclusive = false` ise interceptor sonuçları listenin en başına eklenir ve normal eşleşmeler listenin devamında gelir.

---

## Action Documentation

Action trait'inin `documentation()` yüzeyi komut paleti arayüzü ile karıştırılmamalıdır:

- Komut paleti satırında şu anda insan tarafından okunabilir (humanized) action adı ve atanmışsa mevcut klavye kısayolu gösterilir; action documentation (eylem belgelendirmesi) palet satırında ayrı bir açıklama alanı olarak çizilmez.
- Komut paleti, `window.available_actions(cx)` aracılığıyla odaklanılmış dispatch path (gönderim yolu) üzerindeki action nesnelerini toplar. Standart ad doğrudan `action.name()` üzerinden alınırken, palet satırında görünen format `humanize_action_name(...)` yardımıyla oluşturulur.
- Kod içi doc yorumlarının (documentation comments) yazılması yine de kritik önem taşır; derive makrosu bu yorumları `documentation()` üzerinden dışa açar ve keymap editörü ile JSON şeması gibi action keşif arayüzleri bu verileri kullanır.

---

## Çalışma Zamanı Akışı

Zed'in gerçek komut paleti çalışma akışı, başlatma ve açılma adımlarında şu şekilde işler:

1. `command_palette::init(cx)` metodu hook global'lerini kurar ve `cx.observe_new(CommandPalette::register).detach()` ile her yeni `Workspace` için `Toggle` action'ına bir işleyici bağlar (`workspace.register_action(...)`). Action tipinin kendisi `zed_actions::command_palette` içinde `actions!` makrosuyla zaten tanımlanmıştır; `register` adımı yalnızca bu tipe bir işleyici ekler.
2. `CommandPalette::toggle(calisma_alani, sorgu, window, cx)` çağrısı mevcut focus handle (odak handle'ı) bilgisini alır. Eğer odaklanılmış bir öğe yoksa palet açılmaz. Odak mevcutsa, `calisma_alani.toggle_modal(...)` ile `CommandPalette` modal görünüm (modal view) olarak oluşturulur.
3. `CommandPalette::new(onceki_odak_tutamagi, sorgu, calisma_alani, window, cx)` yapılandırıcısı `window.available_actions(cx)` metodunu çağırır. Bu liste tüm sistem registry'sini kapsamaz; yalnızca odaklanılmış dispatch path üzerinde `.on_action(...)` ile bağlı action'ları ve global action dinleyicilerini içerir.
4. Her action `CommandPaletteFilter::is_hidden` filtresinden geçirilir; filtreyi geçen action'lar `humanize_action_name(action.name())` sonucuna göre `Command { name, action }` yapısına dönüştürülür.
5. Arayüz `Picker::uniform_list(temsilci, window, cx)` ile kurulur; ardından başlangıç sorgusu `secici.set_query(sorgu, window, cx)` ile arama kutusuna yazılır.

`CommandPalette::set_query(sorgu, window, cx)` metodu açık olan palette sorguyu programatik olarak günceller. `CommandPaletteDelegate` dışa açık bir tiptir ve `Picker` delegate davranışlarını taşır; normal çalışma akışında doğrudan elle kurulmaz, `CommandPalette::toggle` üzerinden dolaylı olarak oluşturulur.

**Arama Akışı.** Arama sorgusu birkaç aşamadan geçerek işlenir:

- `humanize_action_name("editor::GoToDefinition")` dönüşümü sonucu `"editor: go to definition"` metnini üretir; `go_to_line::Deploy` gibi snake_case adlar boşluklu hale getirilir.
- `normalize_action_query(girdi)` metodu metni kırpar, ardışık boşlukları tek boşluğa indirir, `_` karakterlerini boşluğa çevirir ve arama kolaylığı için ardışık `::` kullanımlarını sadeleştirir.
- `WorkspaceSettings::command_aliases` tam sorgu eşleşmelerini canonical action adı string'ine dönüştürür.
- Sorgu bir Zed bağlantısı ise (`parse_zed_link`), palette `OpenZedUrl { url }` action'ı bir interceptor sonucu gibi listeye dahil edilir.
- Normal komut listesi, arka plan executor'ı üzerinde `fuzzy_nucleo::match_strings_async(..., Case::Smart, LengthPenalty::On, 10000, ...)` ile eşleştirilir. Eşleştirmeye giren komut havuzu ilk aşamada tıklanma sayısına (hit count), ardından alfabetik isimlerine göre sıralanır; fakat sonuç listesinin nihai sıralamasını birincil olarak fuzzy skoru belirler. Hit sayısı ve alfabetik sıra yalnızca boş sorgularda ve fuzzy skorunun eşitliği durumunda, eşitliği bozan ikincil ölçüt olarak devreye girer.
- Interceptor sonucu mevcutsa, `matches_updated` içerisinde normal eşleşmelerle birleştirilir; mükerrer action'lar `Action::partial_eq` ile ayıklanır.

**Geçmiş ve Sıralama.** `CommandPaletteDB` SQLite veritabanı, çalıştırılan komut geçmişini saklar:

- SQLite domain adı `CommandPaletteDB` ve ilgili tablo `command_invocations` olarak adlandırılır.
- `write_command_invocation(command_name, user_query)` fonksiyonu çalıştırılan komutu ve kullanıcının yazdığı sorguyu veritabanına kaydeder. Tablodaki kayıt sayısı 1000'i aştığında en eski kayıt otomatik olarak silinir.
- `get_command_usage(command)` metodu tek bir komut için kullanım sayısını ve son kullanım zamanını döndürür.
- `list_commands_used()` metodu komut başına toplam tetiklenme sayısı ile son kullanım zamanını listeler; palet ilk açıldığında kullanım sayısı yüksek olan komutlar üst sıralarda listelenir.
- `list_recent_queries()` boş olmayan kullanıcı sorgularını son kullanım zamanına göre getirir. Sorgular `GROUP BY user_query` ile yinelenenleri eleyecek şekilde gruplanır; böylece her sorgu tekil `user_query` olarak bir kez döner. Veritabanı sonuçları eskiden yeniye doğru sıralanır, picker ise geçmişte gezinirken aynı öneke sahip son kayıtlara sondan geriye doğru erişir.

**Onay Davranışı.** Onaylama akışları iki şekilde işler:

- Standart onaylama akışı, seçili komutu alır, telemetry'ye `source = "command palette"` bilgisiyle yazar, `CommandPaletteDB` kaydını bir arka plan görevi olarak başlatır, önceden odaklanılmış olan öğeye geri odaklanır, modal pencereyi kapatır ve `window.dispatch_action(action, cx)` çağrısını gerçekleştirir.
- İkincil onaylama akışı, seçili action'ın canonical adını `String` olarak alır ve `zed_actions::ChangeKeybinding { action: action_name.to_string() }` action'ını gönderir (dispatch eder). Buradaki `action` alanı bir action nesnesi değil, registry isim string'idir (örneğin `"editor::GoToDefinition"`); keymap editörü bu string'i alarak kısayol atama akışını başlatır. Footer (alt bilgi) alanındaki buton ise `ChangeKeybinding` eylemini doğrudan değil, `menu::SecondaryConfirm` aracılığıyla gönderir; bu da aynı ikincil onay yolunu tetikler. Butonun üzerindeki etiket, seçili action'ın mevcut kısayol durumuna göre dinamikleşir: kısayol zaten tanımlıysa `"Change Keybinding…"`, yoksa `"Add Keybinding…"` gösterilir.
- `finalize_update_matches` metodu, bekleyen arka plan sonuçlarını en fazla çok kısa bir süre ön planda bekletebilir; bu sayede palet ilk açılırken listenin boş kalıp titremesi önlenir ve otomasyon testleri sırasında erken enter tuşuna basılması durumunda oluşabilecek hatalar azaltılır.

---

## Dışa Açık API Kapsamı

Komut paleti katmanındaki dışa açık API bileşenleri ve kullanım alanları aşağıdaki tabloda özetlenmiştir:

| API | Görevi |
| ----- | ------- |
| `command_palette` | Workspace modalı olarak çalışan komut paleti arayüzünün crate ve modül sınırıdır. |
| `command_palette::init` | Hook global'lerini kurar ve yeni `Workspace` entity'leri için `zed_actions::command_palette::Toggle` action'ını kaydeder. |
| `CommandPalette` | `ModalView`, `Focusable`, `Render` ve `EventEmitter<DismissEvent>` trait'lerini uygular; dış tüketimde `toggle` ve `set_query` metotları önem taşır. |
| `CommandPalette::toggle` | Önceki odak handle'ını saklar, workspace modal katmanında paleti açar ve başlangıç sorgusunu `Picker` editörüne aktarır. |
| `CommandPalette::set_query` | Açık palette sorguyu dışarıdan programatik olarak değiştirir; UI testleri ve "paleti belirli aramayla aç" akışları için kullanılır. |
| `CommandPaletteDelegate` | Komut listesi, fuzzy sonuçlar, interceptor sonuçları, seçim ve geçmiş sorgu durumlarını taşır; `CommandPalette::toggle` üzerinden dolaylı olarak oluşturulur. |
| `humanize_action_name` | `editor::GoToDefinition` gibi canonical action adlarını palette okunabilir formata dönüştürür. |
| `normalize_action_query` | `_` karakterlerini boşluğa çevirir, ardışık boşlukları ve `::` tekrarlarını sadeleştirir. |
| `command_palette_hooks` | Filtre ve interceptor global'lerini UI modüllerinden ayrıştıran hook crate'idir. |
| `CommandPaletteFilter` | Namespace ve action tipi tabanlı gizleme/gösterme kararlarını yönetir. |
| `CommandInterceptItem` | Tetiklenecek `action`, görüntülenecek `string` ve vurgu konumlarını belirten `positions` alanlarını taşır. |
| `CommandInterceptResult` | `results` listesini ve normal fuzzy sonuçların gizlenip gizlenmeyeceğini belirleyen `exclusive` bayrağını taşır. |
| `GlobalCommandPaletteInterceptor` | `set`, `clear` ve `intercept` metotlarıyla sorgu metnini özel action sonuçlarına dönüştürmek için kullanılır. |

---

## Dikkat Edilmesi Gereken Hususlar

Filtre ve interceptor mekanizmaları kullanılırken dikkat edilmesi gereken hassas noktalar şunlardır:

- `CommandPaletteFilter` global bir durumdur; testlerde belirli bir özellik etkinleştirildiğinde, bir sonraki test senaryosuna geçilmeden önce bu durumun sıfırlanması gerekebilir.
- `hide_action_types` ile gizlenen tiplerin sistem registry'sine kaydedilmiş olması gerekir; aksi takdirde filtreye eklenmiş olsalar dahi komut paleti listesinde zaten görüntülenmezler.
- `Interceptor::set` çağrısı, mevcut interceptor'ı üzerine yazarak iptal eder; eğer çoklu veri kaynağı gerekiyorsa, zincirleme yapının kendi kod yapısında kurulması gerekir (örneğin önce Vim, başarısız olunursa AI agent interceptor'ının tetiklenmesi gibi).
- `CommandInterceptResult::exclusive = true` ayarı yoğun şekilde kullanıldığında, kullanıcı normal action listesindeki komutlara erişemez; bu nedenle ilgili bayrağın yalnızca gerçekten "tek ve kesin doğru sonuç var" senaryolarında etkinleştirilmesi gerekir.
