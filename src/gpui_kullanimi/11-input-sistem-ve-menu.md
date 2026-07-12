# Girdi, Sistem ve Menü

## Sürüm Analiz Raporu

- [x] Doğrulanan girdi köprüsü: `PlatformInputHandler::{set_selected_text_range, element_bounds, text_length_utf16}`, bunların `InputHandler` ve `EntityInputHandler` karşılıkları.
- [x] Doğrulanan olay yüzeyi: `TouchEvent`, `TouchClickEvent`, `ClickEvent::Touch` ve `PlatformInput::Touch`.
- [x] Kaynak doğrulama dosyaları: `crates/gpui/src/platform.rs`, `crates/gpui/src/input.rs` ve `crates/gpui/src/interactive.rs`; imzalar rust-analyzer ile doğrulandı.

---

## Girdi, Pano, Prompt ve Platform Servisleri

Element seviyesinde GPUI birçok girdi olayını tek tipli bir fluent API üzerinden açar. Olay metotlarını tek tek ezberlemek yerine, hangi girdi sınıfının yakalandığı ve dispatch (yönlendirme) aşaması birlikte düşünülmelidir:

![GPUI Element Girdi Olay Kategorileri](assets/girdi-olay-kategorileri.svg)

- **Klavye:** `.on_key_down` ve `.on_key_up` odak yolunda bubble aşamasında çalışır; bunlar bileşenin kendi tuş davranışı için tercih edilir. `.capture_key_down` ve `.capture_key_up` aynı olayları kökten hedefe giderken yakalar; modal veya genel engelleme gibi üst seviyeden karar verilmesi gereken durumlarda ise capture (yakalama) metotları seçilmelidir.
- **Fare:** Hitbox üzerindeki temel fare hareketlerini dinlemek amacıyla `.on_mouse_down`, `.on_mouse_up` ve `.on_mouse_move` metotları kullanılır. `.capture_any_mouse_down` ve `.capture_any_mouse_up` buton ayrımı gözetmeksizin capture aşamasında devreye girer. Popover veya modal gibi dışarı tıklanıldığında kapanması gereken alanlarda `.on_mouse_down_out` ve `.on_mouse_up_out` tercih edilir. `.on_click` basma ve bırakma eylemlerinin aynı hedef üzerinde tamamlandığı durumlarda, `.on_hover` ise hover durumunun view verisine taşınmasında tetiklenir.
- **Hareket ve scroll:** `.on_scroll_wheel` scroll alabilen hitbox üstünde wheel veya trackpad delta'sını işler. `.on_pinch` yakınlaştırma gesture'ını bubble aşamasında yakalar; `.capture_pinch` ise aynı hareketin üst katmanlar tarafından öncelikli olarak dinlenmesi istendiğinde tercih edilir.
- **Sürükle-bırak:** `.on_drag` sürükleme yükünü ve hayalet (ghost) view'u başlatır. `.on_drag_move` aktif sürükleme boyunca hareket bilgisi sağlar; bu metottan yeniden boyutlandırma veya split handle gibi drop içermeyen sürükleme senaryolarında da yararlanılır. `.on_drop` ise aynı tipteki sürükleme yükü hedefe bırakıldığında tetiklenir.
- **Action:** `.capture_action::<A>` action'ı kökten hedefe giden aşamada yakalar. `.on_action::<A>` odaklanan elementten köke yönelen standart action dinleyicisidir. `.on_boxed_action` ise tipin derleme zamanında (compile-time) bilinmediği kayıt veya yönlendirme katmanlarında tercih edilir.

Olay tipleri `interactive` içinde tanımlıdır: `KeyDownEvent`, `KeyUpEvent`, `MouseDownEvent`, `MouseUpEvent`, `MouseMoveEvent`, `MousePressureEvent`, `ScrollWheelEvent`, `PinchEvent`, `TouchEvent`, `TouchClickEvent`, `FileDropEvent`, `ExternalPaths`, `ClickEvent`. `PlatformInput::Touch` ham dokunmayı taşır; `ClickEvent::Touch` ise tanınmış dokunma tıklamasının tip sözleşmesidir. Mevcut yönlendirme sınırı [Dokunma Olayları ve Gesture Platform Sözleşmesi](09-etkilesim-ve-olaylar.md#dokunma-olayları-ve-gesture-platform-sözleşmesi) başlığında açıklanır. `ScrollDelta::pixel_delta(line_height)` satır tabanlı scroll değerini piksele dönüştürür; `coalesce` ise aynı yöndeki delta değerlerini birleştirir.

**Pano.** Panoya okuma ve yazma işlemleri pratik metot çağrılarıyla gerçekleştirilir:

```rust
cx.write_to_clipboard(ClipboardItem::new_string("metin".to_string()));

if let Some(oge) = cx.read_from_clipboard()
    && let Some(metin) = oge.text()
{
    // kullan
}
```

`ClipboardItem` birden çok `ClipboardEntry` taşıyabilir: `String`, `Image` veya `ExternalPaths`. `String` girdisine üst veri (metadata) eklenmek istendiğinde `new_string_with_metadata` veya `new_string_with_json_metadata` tercih edilir. `ClipboardItem::new_image(&image)` görseli pano girdisine dönüştürür; `ClipboardItem::into_entries()` ise öğeyi tüketerek sahipli `ClipboardEntry` iteratörü sağlar. Linux/FreeBSD için primary selection `read_from_primary`/`write_to_primary`; macOS Find pasteboard için `read_from_find_pasteboard`/`write_to_find_pasteboard`, `cfg` koşullu API'lerdir.

`ClipboardString` metnin yanı sıra isteğe bağlı biçim ve üst veri (metadata) de taşır. Düz metin verisine ulaşmak için `ClipboardString::text()` veya `ClipboardItem::text()` tercih edilmelidir; sahipli (owned) bir metin gerektiğinde ise `ClipboardString::into_text()` ile değer tüketilir. JSON formatındaki üst veriler için `ClipboardString::with_json_metadata(...)` yazma, `ClipboardString::metadata_json::<T>()` ise okuma amacıyla kullanılır. `ClipboardString::text_hash(text)` metodu macOS ve Windows pano köprülerinde metin içeriğinin değişip değişmediğini düşük maliyetle tespit etmek amacıyla tercih edilir. Üst veri kullanımı, yalnızca aynı uygulama ailesi içinde gelişmiş yapıştırma (rich paste) davranışları tasarlanırken anlam kazanır. Görsel veri barındıran pano girdilerinde `Image` ve `ImageFormat` boru hattı devreye girerken; standart metin kopyalama senaryoları için `ClipboardItem::new_string(...)` kullanımı yeterlidir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `ClipboardEntry` | `String(ClipboardString)`, `Image(Image)`, `ExternalPaths(ExternalPaths)` | `ClipboardItem` içindeki sahipli pano girdisi varyantıdır. |
| `ClickEvent` | `Mouse`, `Keyboard`, `Touch`; `is_secondary`, `standard_click`, `click_count` | Anlamsal tıklamanın kaynağını, sayısını ve birincil/ikincil etkinleştirme niyetini okumak için kullanılır. |
| `KeyDownEvent`, `KeyUpEvent` | key press/release olayı | Klavye listener ve test girdi simülasyonu tarafında ham key event modelidir. |
| `MousePressureEvent`, `ScrollDelta` | pressure ve scroll delta modeli | Gelişmiş pointer/scroll girdisini platformdan element listener'ına taşır. |
| `EntityInputHandler`, `ElementInputHandler` | input handler trait'i ve element bağlayıcısı | IME, UTF-16 seçim yazma/uzunluk sorgusu, element sınırları ve yazdırılabilir tuş kararlarını görünüm durumuna bağlar. |

**PlatformInputHandler Yapısı.** `PlatformInputHandler` platform penceresinin aktif metin girdi dinleyicisini temsil eden bir sarmalayıcı struct'tır. Uygulama düzeyinde bu yapının doğrudan saklanması gerekmez; `EntityInputHandler` ve `ElementInputHandler` görünümü platforma bağlar, `window.handle_input(...)` da kare içinde bu bağı kaydeder. Platform arka ucu ve GPUI pencere katmanı bu sarmalayıcı üzerinden `apple_press_and_hold_enabled()`, `dispatch_input(input, window, cx)`, `selected_bounds(window, cx)`, `set_selected_text_range(range_utf16)`, `element_bounds()`, `text_length_utf16()`, `query_accepts_text_input()` ve `query_prefers_ime_for_printable_keys()` çağrılarını yapar. Böylece platform; IME kabulünü, seçili metin sınırını, sistemin değiştirdiği seçimin uygulamaya geri yazılmasını, odaktaki element geometrisini, UTF-16 belge uzunluğunu ve yazdırılabilir tuşların IME'ye mi yoksa kısayollara mı yönlendirileceği kararını görünümün gerçek `InputHandler` uygulamasından alır. Doğrudan uygulanması gereken yapı `PlatformInputHandler` değil, bu sarmalayıcının içerisine alınan özel `InputHandler` uygulamasıdır.

`PlatformInputHandler::set_selected_text_range(...)` dönüş değeri olmadan etkin handler'ı günceller. `element_bounds()` ve `text_length_utf16()` ise bağlam güncellemesi başarısız olduğunda veya handler bilgi sağlamadığında `None` döndürür. `ElementInputHandler`, element sınırını kurucuda aldığı güncel `Bounds<Pixels>` değerinden; diğer iki davranışı `EntityInputHandler` görünümünden sağlar.

`selected_bounds(window, cx)`'in döndürdüğü sınır, IME aday penceresinin (composition popup) yerleştirileceği noktadır. Aktif bir composition (marked range) varsa bu nokta imlecin bulunduğu **görsel satırın başına** çapalanır: metot imleçten geriye doğru yürüyüp Y konumunun ilk değiştiği yeri (önceki satıra geçiş) bularak satır başını saptar, böyle bir kırılma yoksa marked range'in başını kullanır. Composition yoksa seçimin uç noktası (ters seçimde başlangıç, düz seçimde bitiş) tercih edilir. Aynı hesabı `window`/`cx` elinde olmadan yapılması gerekirse `ime_candidate_bounds(&mut self)` varyantı handler'ın kendi `marked_text_range`/`selected_text_range`/`bounds_for_range` metotlarıyla aynı sonucu üretir; iki varyant da ortak `compute_ime_candidate_bounds(marked_range, selection, bounds_for_range)` saf yardımcısına dayanır.

**Prompt ve dosya seçici.** Kullanıcıyla iletişim kuran platform diyalogları da bağlam üzerinden çalışır:

- `window.prompt(level, message, detail, answers, cx) -> oneshot::Receiver<usize>`
- `cx.set_prompt_builder(...)`, özel GPUI prompt UI'ını kurar; `reset_prompt_builder`, yerel veya varsayılan akışa döner.
- `cx.prompt_for_paths(PathPromptOptions { files, directories, multiple, prompt })`, dosya veya dizin seçici açar.
- `cx.prompt_for_new_path(directory, suggested_name)`, kaydetme diyaloğunu açar.
- `cx.open_url(url)`, `cx.register_url_scheme(scheme)`, `cx.reveal_path(path)`, `cx.open_with_system(path)`, platform servislerine gider.
- Platformun kimlik bilgisi deposu için `cx.write_credentials(url, username, password)`, `cx.read_credentials(url)` ve `cx.delete_credentials(url)` async `Task<Result<_>>` döndürür.
- Uygulama yolu ve sistem bilgisi için `cx.app_path()`, `cx.path_for_auxiliary_executable(name)`, `cx.compositor_name()`, `cx.should_auto_hide_scrollbars()`.
- Yeniden başlatma ve HTTP istemcisi tarafında `cx.set_restart_path(path)`, `cx.restart()`, `cx.http_client()` ve `cx.set_http_client(client)` bulunur.

`PathPromptOptions { files, directories, multiple, prompt }`, dosya seçici davranışını açıkça modellediği için kullanıcı ayarından gelen "dosya mı, dizin mi, ikisi birden mi?" kararını string parametrelerle taşımaktan daha güvenlidir. Platform bazı kombinasyonları desteklemeyebilir; `cx.can_select_mixed_files_and_dirs()` sonucuna göre dosya ve dizinlerin birlikte seçilebildiği akışlar için bir yedek (fallback) planı tasarlanmalıdır.

**Platform ve prompt davranışı.** Diyaloglarda platforma özgü davranışlar beklenmedik sonuçlar doğurabileceğinden, şu hususların göz önünde bulundurulması gerekir:

- macOS `Window::prompt` NSAlert akışında Return ilk butona, Escape iptal akışına gider; Space ile odak son "iptal olmayan ve varsayılan olmayan" butona taşınır. `"Kaydet / Kaydetme / İptal"` gibi üçlü prompt'larda orta seçenek klavyeyle erişilebilir kalır.
- Wayland'da pano ve primary selection yazılırken, tuş veya fare basma türüne göre süzülmüş seri yerine alınan en güncel compositor serisi kullanılır; aksi halde bazı compositor'lar seçim isteğini sessizce reddedebilir.
- `open_path_prompt` sonuç sıralaması `ProjectPanelSettings.sort_mode` ile uyumlu çalışır. Proje panelindeki "önce dizinler / önce dosyalar / karışık" seçimi, dosya yolu prompt'unun aday listesine de aynı sıralama mantığıyla yansıtılmalıdır.

## Prompt Builder, PromptHandle ve Fallback Prompt

`Window::prompt` platform diyalog penceresini açar. Platform prompt yapısını desteklemiyorsa veya özel bir prompt builder tanımlanmışsa GPUI içerisinde çizilen prompt tercih edilir:

```rust
let yanit = window.prompt(
    PromptLevel::Warning,
    "Kaydedilmemiş değişiklikler",
    Some("Kaydetmeden kapatılsın mı?"),
    &[PromptButton::cancel("İptal"), PromptButton::ok("Kapat")],
    cx,
);

let secilen_sira = yanit.await?;
```

**Prompt tipleri.** Prompt akışında kullanılan tipler şu rolleri üstlenir:

- `PromptLevel::{Info, Warning, Critical}` — görsel önem seviyesidir.
- `PromptButton::ok(label)`, `cancel(label)`, `new(label)` — sırasıyla ok, cancel ve genel action butonu üretir; `label()` ve `is_cancel()` okunabilir.
- `PromptResponse(pub usize)` — özel prompt view'unun seçilen buton indeksini yaydığı olaydır.
- `Prompt` — `EventEmitter<PromptResponse> + Focusable` trait birleşimidir.
- `PromptHandle::with_view(view, window, cx)` — özel prompt entity'sini pencereye bağlar, önceki odağı kaydeder ve prompt yanıtında odağı geri verir.
- `fallback_prompt_renderer(...)` — `set_prompt_builder` ile varsayılan GPUI prompt çizimini etkinleştirmek için tercih edilir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `PathPromptOptions` | `files`, `directories`, `multiple`, `prompt` | Dosya/dizin seçici davranışını tipli biçimde taşır. |
| `PromptLevel` | `Info`, `Warning`, `Critical` | Platform veya GPUI prompt'unun önem seviyesidir. |
| `PromptButton` | `Ok`, `Cancel`, `Other`, `ok`, `cancel`, `new`, `label`, `is_cancel` | Prompt cevap düğmelerinin etiket ve semantiğini taşır. |
| `PromptResponse` | seçilen buton indeksi | Özel prompt view'unun `EventEmitter` üzerinden yaydığı cevaptır. |
| `fallback_prompt_renderer` | fallback GPUI prompt builder | Sistem prompt'u kullanılmadığında GPUI içinde çizilen varsayılan prompt renderer'ını kurar. |

**Zed entegrasyonu** (`ui_prompt`):

- `ui_prompt::init(cx)`, `WorkspaceSettings::use_system_prompts` ayarını `SettingsStore` üzerinden gözlemler. Sistem prompt'ları açıksa `cx.reset_prompt_builder()` çağrılarak platform diyaloğuna düşülür; aksi halde `cx.set_prompt_builder(zed_prompt_renderer)` ile GPUI içindeki markdown destekli prompt akışına geçilir. Linux/FreeBSD dağıtımlarında sistem prompt yapısı yok sayılır ve daima Zed'in kendi çizimi tercih edilir.
- `ZedPromptRenderer`, `pub` bir struct'tır: `Markdown` entity'siyle mesaj ve detay metnini çizer; cancel ve confirm action'larını içeride yönlendirir. Uygulama kodu doğrudan oluşturmaz; yalnızca prompt builder fonksiyonu üzerinden yapılandırılır.

**Özel builder.** Tamamen özel bir prompt görsel akışı tanımlamak için builder kayda alınır:

```rust
cx.set_prompt_builder(|seviye, mesaj, ayrinti, eylemler, tutamac, window, cx| {
    let mesaj = mesaj.to_string();
    let ayrinti = ayrinti.map(ToString::to_string);
    let eylemler = eylemler.to_vec();
    let gorunum = cx.new(|cx| IstemGorunumu::new(seviye, mesaj, ayrinti, eylemler, cx));
    tutamac.with_view(gorunum, window, cx)
});
```

**Dikkat Noktaları.** Prompt yapıları ile çalışırken dikkat edilmesi gereken hususlar:

- GPUI iç içe (`re-entrant`) prompt desteklemez; bir prompt etkinken aynı pencerede ikinci bir prompt'un nasıl açılacağı ayrıca tasarlanmalıdır.
- Özel prompt `Focusable` sağlamalıdır; aksi halde `PromptHandle::with_view`, odak geri yükleme zincirini tamamlayamaz.
- Prompt sonucu buton etiketi değil, `answers` dizisindeki indekstir.

## Uygulama Menüsü ve Dock

Menü modeli birkaç ana tip etrafında şekillenir:

- `Menu { name, items, disabled }`
- `MenuItem`:
  - `Separator`
  - `Submenu(Menu)`
  - `SystemMenu(OsMenu)` — macOS Services gibi sistem alt menüleri.
  - `Action { name, action, os_action, checked, disabled }`
- `OsAction`: `Cut`, `Copy`, `Paste`, `SelectAll`, `Undo`, `Redo`. Yerel düzenleme menüsü eşlemelerinde tercih edilir.

**Builder örneği.** Üst seviye menü ağacı kurarken builder kalıbı şu şekildedir:

```rust
cx.set_menus(vec![
    Menu::new("Zed").items([
        MenuItem::action("Zed Hakkında", zed::About),
        MenuItem::Separator,
        MenuItem::action("Çık", workspace::Quit),
    ]),
    Menu::new("Düzenle").items([
        MenuItem::os_action("Geri Al", editor::Undo, OsAction::Undo),
        MenuItem::os_action("Yinele", editor::Redo, OsAction::Redo),
        MenuItem::Separator,
        MenuItem::os_action("Kes", editor::Cut, OsAction::Cut),
        MenuItem::os_action("Kopyala", editor::Copy, OsAction::Copy),
        MenuItem::os_action("Yapıştır", editor::Paste, OsAction::Paste),
        MenuItem::os_action("Tümünü Seç", editor::SelectAll, OsAction::SelectAll),
    ]),
]);
```

`MenuItem::action(name, action)`, bir action'ı menü öğesine bağlamanın doğrudan yoludur ve veri taşıyanlar dahil herhangi bir `Action` arayüzünü kabul eder. Veri taşıyan action'larda da doğrudan action değeri iletilebilir: `MenuItem::action("Satıra Git", SatiraGit { satir: 1 })`. Action öğesinin durumunu okumak için `MenuItem::is_checked()` ve `MenuItem::is_disabled()` metotları kullanılmaktadır; bu metotlar platform menüsünde checkmark ve devre dışı (disabled) görünümlerini üretirken işlevsellik sağlar. Yerel sistem alt menüsü gerektiğinde `MenuItem::os_submenu(...)` tercih edilir; macOS Services gibi platforma ait alt menüler normal action ağacından ayrı kalır. Aynı menü modelini klonlamak istenirse `Menu::owned()` ve `MenuItem::owned()` metotları kullanılır; bu dönüşüm platform tarafının sakladığı `OwnedMenu` / `OwnedMenuItem` modelini üretir.

**MenuItem tam modeli.** `MenuItem::submenu(menu)`, `separator()`, `action(name, action)`, `os_action(name, action, os_action)`, `os_submenu(name, menu_type)`, `checked(checked)` ve `disabled(disabled)` builder'ları aynı enum'un varyantlarını kurar. arayüz tarafında yeniden çizim yapılırken kaynak `MenuItem` değerini muhafaza etmek daha okunaklı bir yaklaşımdır. `SystemMenuType` ve `OwnedOsMenu` yerel sistem menülerini temsil eder; normal uygulama menüsü için `MenuItem::SystemMenu(OsMenu { name, menu_type })` veya hazır builder'lar yeterlidir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `MenuItem` | `Separator`, `Submenu`, `SystemMenu`, `Action`; builder ve `owned` | Menü öğelerinin ham enum modelidir. |
| `OsMenu`, `SystemMenuType` | `name`, `menu_type`; `Services` | macOS Services gibi sistem menülerini temsil eder. |
| `OsAction` | `Cut`, `Copy`, `Paste`, `SelectAll`, `Undo`, `Redo` | Yerel düzenleme eylemlerini platform menülerine bağlar. |
| `OwnedMenu`, `OwnedMenuItem`, `OwnedOsMenu` | sahipli menu/item/os menu modeli | Platform tarafında saklanmak üzere kopyalanabilir ve sahipli menü ağacı üretilmesini sağlar. |

**Diğer menü API'leri** (`App` üzerinde):

- `cx.set_dock_menu(Vec<MenuItem>)` — macOS dock sağ tıklama menüsü; Windows'ta dock menüsü veya jump list modelinin bir parçası olarak çalışır.
- `cx.add_recent_document(path)` — macOS'taki son kullanılan öğeler listesine ekler.
- `cx.update_jump_list(menus, entries) -> Task<Vec<SmallVec<[PathBuf; 2]>>>` — Windows jump list'ini günceller ve kullanıcının listeden kaldırdığı girişleri `Task` sonucu olarak döndürür. Zed `HistoryManager`, bu sonucu geçmişten siler.
- `cx.get_menus()` — şu an ayarlanmış menü modelini okur.

**Platform davranışı.** Aynı menü modeli her platformda farklı bir kanal aracılığıyla çizilir:

- macOS'ta yerel `NSMenu` ile çizilir; klavye kısayolları kısayol kayıtlarından okunur.
- Windows ve Linux, platform durumunu `OwnedMenu` olarak saklar; Zed bu modeli uygulama içi menü ve çizim katmanlarında kullanır.
- Linux dock menüsü arka uçta `todo` veya işlem yapmayan (`no-op`) durumdadır; dock veya jump-list davranışı için platforma özgü bir yedek (fallback) akış tasarlanmalıdır.

**Dikkat noktası.** Aynı action birden çok menü öğesine bağlandığında keymap'te tek bir kısayol gösterilir. `os_action` yalnızca macOS yerel düzenleme menüsü eşlemesini etkiler; diğer platformlarda sıradan bir action gibi davranır.

---
