# 14. Girdi, Sistem ve Menü

---

## 14.1. Input, Clipboard, Prompt ve Platform Servisleri

Bu bölüm GPUI'de UI öğelerine bağlanan girdi event ailesi, pano (clipboard) erişimi, prompt diyalogları, dosya seçici ve diğer platform servislerinin pratik bir özetini sunar. Odak ve dispatch ayrıntıları [Etkileşim](./bolum-07-etkilesim.md), action/keymap ayrıntıları ise [Action ve Keymap](./bolum-08-action-ve-keymap.md) bölümünde anlatılır; burada günlük kullanımda gereken yüzeyler tek yerde toplanır.

### UI öğesi event ailesi

Bir UI öğesi üzerine zincirleme eklenen event dinleyicileri kategorilere göre:

- **Klavye**: `.on_key_down`, `.capture_key_down`, `.on_key_up`, `.capture_key_up`.
- **Mouse**: `.on_mouse_down`, `.capture_any_mouse_down`, `.on_mouse_up`, `.capture_any_mouse_up`, `.on_mouse_move`, `.on_mouse_down_out`, `.on_mouse_up_out`, `.on_click`, `.on_hover`.
- **Gesture/scroll**: `.on_scroll_wheel`, `.on_pinch`, `.capture_pinch`.
- **Drag/drop**: `.on_drag`, `.on_drag_move`, `.on_drop`.
- **Action**: `.capture_action::<A>`, `.on_action::<A>`, `.on_boxed_action`.

Event tipleri `interactive.rs` ve `platform.rs` içindedir: `KeyDownEvent`, `KeyUpEvent`, `MouseDownEvent`, `MouseUpEvent`, `MouseMoveEvent`, `MousePressureEvent`, `ScrollWheelEvent`, `PinchEvent`, `FileDropEvent`, `ExternalPaths`, `ClickEvent`. Scroll için pratik yardımcılar: `ScrollDelta::pixel_delta(line_height)` satır tabanlı scroll'u piksele çevirir; `coalesce` aynı yöndeki ardışık delta'ları birleştirir.

### Clipboard (pano)

Sistem panosuna metin yazma ve okuma:

```rust
cx.write_to_clipboard(ClipboardItem::new_string("metin".to_string()));

if let Some(item) = cx.read_from_clipboard()
    && let Some(text) = item.text()
{
    // kullan
}
```

`ClipboardItem` birden çok `ClipboardEntry` taşıyabilir: `String`, `Image`, `ExternalPaths`. String entry'sine metadata eklemek için `new_string_with_metadata` veya `new_string_with_json_metadata` kullanılır (örn. kopyalanan kaynağın URL'si). Linux/FreeBSD primary selection (X11 orta-tıkla yapıştır) için `read_from_primary`/`write_to_primary`; macOS Find pasteboard (Cmd+E arama panosu) için `read_from_find_pasteboard`/`write_to_find_pasteboard` cfg-gated API'leri vardır.

### Prompt ve dosya seçici

- **`window.prompt(level, message, detail, answers, cx) -> oneshot::Receiver<usize>`** — Sistem prompt diyaloğu açar; seçilen buton index'ini async olarak döndürür (14.2'de detayı).
- **`cx.set_prompt_builder(...)`** — Özel GPUI prompt UI'ı kurar; `reset_prompt_builder` yerel/varsayılan akışa döner.
- **`cx.prompt_for_paths(PathPromptOptions { files, directories, multiple, prompt })`** — Dosya/dizin seçici açar.
- **`cx.prompt_for_new_path(directory, suggested_name)`** — "Farklı Kaydet" diyaloğu açar.
- **`cx.open_url(url)`, `cx.register_url_scheme(scheme)`, `cx.reveal_path(path)`, `cx.open_with_system(path)`** — URL açma, sistem URL şeması kaydı, dosyayı işletim sisteminin dosya yöneticisinde gösterme, varsayılan uygulamayla açma.
- **Credential store**: `cx.write_credentials(url, username, password)`, `cx.read_credentials(url)`, `cx.delete_credentials(url)` — Sistem anahtarlığı async `Task<Result<_>>` döndürür.
- **Uygulama yolu ve sistem bilgisi**: `cx.app_path()`, `cx.path_for_auxiliary_executable(name)`, `cx.compositor_name()`, `cx.should_auto_hide_scrollbars()`.
- **Restart ve HTTP**: `cx.set_restart_path(path)`, `cx.restart()`, `cx.http_client()`, `cx.set_http_client(client)`.

## 14.2. Prompt Builder, PromptHandle ve Yedek Prompt

`Window::prompt` çağrısı, platform prompt diyaloğunu açar. Platform yerel prompt desteklemiyorsa veya `set_prompt_builder` ile özel bir UI bağlanmışsa GPUI içinde render edilen prompt kullanılır. Bu yapı, aynı `window.prompt(...)` API'sinin hem yerel macOS/Windows prompt'u hem de özel tasarımlı modal pencere ile çalışmasını sağlar.

```rust
let response = window.prompt(
    PromptLevel::Warning,
    "Unsaved changes",
    Some("Close without saving?"),
    &[PromptButton::cancel("Cancel"), PromptButton::ok("Close")],
    cx,
);

let selected_index = response.await?;
```

### Prompt tipleri

- **`PromptLevel::{Info, Warning, Critical}`** — Görsel önem seviyesi (icon ve renk farkı yaratır).
- **`PromptButton::ok(label)`, `cancel(label)`, `new(label)`** — Sırasıyla OK/Cancel/generic action butonu üretir. `label()` ve `is_cancel()` ile okunur.
- **`PromptResponse(pub usize)`** — Özel prompt görünümünün seçilen buton index'ini event olarak emit etmesi için tip.
- **`Prompt`** — `EventEmitter<PromptResponse> + Focusable` trait birleşimi; özel prompt varlığının (`entity`) sağlaması gerekenleri tanımlar.
- **`PromptHandle::with_view(view, window, cx)`** — Özel prompt varlığını pencereye bağlar, önceki odağı kaydeder, prompt yanıtında odağı eski yerine geri taşır.
- **`fallback_prompt_renderer(...)`** — `set_prompt_builder` içinde varsayılan GPUI prompt render'ını zorlamak için kullanılabilir.

### Özel builder

```rust
cx.set_prompt_builder(|level, message, detail, actions, handle, window, cx| {
    let message = message.to_string();
    let detail = detail.map(ToString::to_string);
    let actions = actions.to_vec();
    let view = cx.new(|cx| MyPrompt::new(level, message, detail, actions, cx));
    handle.with_view(view, window, cx)
});
```

Builder kapaması her `window.prompt(...)` çağrısında çalışır; istenirse uygulama temasına uygun bir prompt görünümü oluşturulur ve `handle.with_view(...)` ile pencereye bağlanır.

### Tuzaklar

- **GPUI re-entrant prompt desteklemez.** Bir prompt açıkken aynı pencerede ikinci prompt açılırsa davranış tanımsızdır; "ardışık prompt" akışı için cevap alındıktan sonra ikinci prompt açılır.
- **Özel prompt `Focusable` sağlamalıdır;** aksi halde `PromptHandle::with_view` odak geri yükleme zincirini tamamlayamaz ve kullanıcı odağı kaybeder.
- **Prompt sonucu buton label'ı değil, `answers` dizisindeki index'tir.** Yani sıralamayı değiştirmek programatik kontrolü bozar; buton sırası kullanıcı arayüzü tasarımıyla aynı kalmalıdır.

## 14.3. Uygulama Menüsü ve Dock

Kaynak: `crates/gpui/src/platform/app_menu.rs`.

Uygulama menüsü; macOS'ta üst menü çubuğu, Windows ve Linux'ta uygulamanın kendi içinde çizilen menü olarak görünür. GPUI menü modeli platformdan bağımsız tek bir veri yapısıdır; her platform implementasyonu bu modeli kendi yerel menü API'sine çevirir. Dock menüsü, "son kullanılanlar" listesi ve Windows Jump List gibi yan sistemler de aynı modelin parçasıdır.

### Tipler

- **`Menu { name, items, disabled }`** — Bir menü (örn. "File", "Edit").
- **`MenuItem`** — Menü öğesi varyantları:
  - **`Separator`** — Ayırıcı çizgi.
  - **`Submenu(Menu)`** — İç içe menü.
  - **`SystemMenu(OsMenu)`** — macOS Services gibi sistem submenüleri.
  - **`Action { name, action, os_action, checked, disabled }`** — Tıklanabilir öğe; tetiklendiğinde action dispatch eder.
- **`OsAction`** — `Cut`, `Copy`, `Paste`, `SelectAll`, `Undo`, `Redo`. macOS yerel edit menüsüne özel eşleme için.

### Builder örneği

```rust
cx.set_menus(vec![
    Menu::new("Zed").items([
        MenuItem::action("About Zed", zed::About),
        MenuItem::Separator,
        MenuItem::action("Quit", workspace::Quit),
    ]),
    Menu::new("Edit").items([
        MenuItem::os_action("Undo", editor::Undo, OsAction::Undo),
        MenuItem::os_action("Redo", editor::Redo, OsAction::Redo),
        MenuItem::Separator,
        MenuItem::os_action("Cut", editor::Cut, OsAction::Cut),
        MenuItem::os_action("Copy", editor::Copy, OsAction::Copy),
        MenuItem::os_action("Paste", editor::Paste, OsAction::Paste),
        MenuItem::os_action("Select All", editor::SelectAll, OsAction::SelectAll),
    ]),
]);
```

`MenuItem::action(name, action)` veri taşımayan unit struct action'lar için kısayoldur; veri taşıyan action'larda da doğrudan action değeri geçirilir: `MenuItem::action("Go To Line", GoToLine { line: 1 })`. Aynı menü modeli farklı yerlerde clone'lanacaksa `Menu::owned()` / `MenuItem::owned()` kullanılır.

### Diğer menü API'leri (`App` üzerinde)

- **`cx.set_dock_menu(Vec<MenuItem>)`** — macOS Dock simgesinin sağ-tık menüsü; Windows'ta dock menu/jump list modelinin parçasıdır.
- **`cx.add_recent_document(path)`** — macOS "son kullanılanlar" listesine ekler.
- **`cx.update_jump_list(menus, entries) -> Task<Vec<SmallVec<[PathBuf; 2]>>>`** — Windows Jump List'i günceller ve kullanıcının listeden kaldırdığı entry'leri task sonucu olarak döndürür. Zed `HistoryManager` bu sonucu history'den temizlemek için kullanır.
- **`cx.get_menus()`** — Şu anda set edili menü modelini okur.

### Platform davranışı

- **macOS**: yerel `NSMenu` ile çizilir; klavye kısayolları binding'lerden okunur.
- **Windows ve Linux**: platform durumu `OwnedMenu` olarak saklar; Zed bu modeli uygulama içi menü/render katmanlarında kullanır.
- **Linux dock menüsü**: backend'de `todo`/no-op'tur; dock/jump-list davranışı için platforma özel yedek davranış gerekir.

### Tuzaklar

- **Aynı action birden çok menü item'a bağlanırsa keymap'te tek shortcut gösterilir.** Kullanıcı kafa karışıklığı yaratmamak için aynı action'a bağlı duplicate item'lardan kaçınılır.
- **`os_action` yalnızca macOS yerel edit menu eşlemesini etkiler;** diğer platformlarda sıradan bir action gibi davranır. Yani `OsAction::Cut` macOS dışında `Cmd+X` shortcut'ını otomatik üretmez.


---
