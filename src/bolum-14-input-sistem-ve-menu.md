# 14. Input, Sistem ve Menü

---

## 14.1. Input, Clipboard, Prompt ve Platform Servisleri

Element event ailesi:

- Keyboard: `.on_key_down`, `.capture_key_down`, `.on_key_up`, `.capture_key_up`.
- Mouse: `.on_mouse_down`, `.capture_any_mouse_down`, `.on_mouse_up`,
  `.capture_any_mouse_up`, `.on_mouse_move`, `.on_mouse_down_out`,
  `.on_mouse_up_out`, `.on_click`, `.on_hover`.
- Gesture/scroll: `.on_scroll_wheel`, `.on_pinch`, `.capture_pinch`.
- Drag/drop: `.on_drag`, `.on_drag_move`, `.on_drop`.
- Action: `.capture_action::<A>`, `.on_action::<A>`, `.on_boxed_action`.

Event tipleri `interactive.rs` ve `platform.rs` içinde tanımlıdır:
`KeyDownEvent`, `KeyUpEvent`, `MouseDownEvent`, `MouseUpEvent`,
`MouseMoveEvent`, `MousePressureEvent`, `ScrollWheelEvent`, `PinchEvent`,
`FileDropEvent`, `ExternalPaths`, `ClickEvent`. `ScrollDelta::pixel_delta(line_height)`
line-based scroll'u pixel'e çevirir; `coalesce` aynı yöndeki delta'ları birleştirir.

Clipboard:

```rust
cx.write_to_clipboard(ClipboardItem::new_string("metin".to_string()));

if let Some(item) = cx.read_from_clipboard()
    && let Some(text) = item.text()
{
    // kullan
}
```

`ClipboardItem` birden çok `ClipboardEntry` taşıyabilir: `String`, `Image`,
`ExternalPaths`. String entry metadata'sı `new_string_with_metadata` veya
`new_string_with_json_metadata` ile yazılır. Linux/FreeBSD için primary selection
`read_from_primary`/`write_to_primary`, macOS Find pasteboard için
`read_from_find_pasteboard`/`write_to_find_pasteboard` cfg-gated API'lerdir.

Prompt ve dosya seçici:

- `window.prompt(level, message, detail, answers, cx) -> oneshot::Receiver<usize>`.
- `cx.set_prompt_builder(...)` custom GPUI prompt UI kurar; `reset_prompt_builder`
  native/default akışa döner.
- `cx.prompt_for_paths(PathPromptOptions { files, directories, multiple, prompt })`
  dosya/dizin seçici açar.
- `cx.prompt_for_new_path(directory, suggested_name)` save dialog açar.
- `cx.open_url(url)`, `cx.register_url_scheme(scheme)`, `cx.reveal_path(path)`,
  `cx.open_with_system(path)` platform servislerine gider.
- Platform credential store: `cx.write_credentials(url, username, password)`,
  `cx.read_credentials(url)`, `cx.delete_credentials(url)` async `Task<Result<_>>`
  döndürür.
- Uygulama yolu ve sistem bilgisi: `cx.app_path()`,
  `cx.path_for_auxiliary_executable(name)`, `cx.compositor_name()`,
  `cx.should_auto_hide_scrollbars()`.
- Restart ve HTTP client: `cx.set_restart_path(path)`, `cx.restart()`,
  `cx.http_client()`, `cx.set_http_client(client)`.

## 14.2. Prompt Builder, PromptHandle ve Fallback Prompt

`Window::prompt` platform dialog'u açar; platform prompt desteklemiyorsa veya
custom prompt builder set edilmişse GPUI içinde render edilen prompt kullanılır.

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

Prompt tipleri:

- `PromptLevel::{Info, Warning, Critical}` görsel önem seviyesidir.
- `PromptButton::ok(label)`, `cancel(label)`, `new(label)` sırasıyla ok/cancel
  ve generic action butonu üretir; `label()` ve `is_cancel()` okunabilir.
- `PromptResponse(pub usize)`: custom prompt view'in seçilen buton index'ini
  emit ettiği event.
- `Prompt`: `EventEmitter<PromptResponse> + Focusable` trait birleşimidir.
- `PromptHandle::with_view(view, window, cx)`: custom prompt entity'sini
  window'a bağlar, önceki focus'u kaydeder, prompt yanıtında focus'u geri verir.
- `fallback_prompt_renderer(...)`: `set_prompt_builder` ile default GPUI prompt
  render'ını zorlamak için kullanılabilir.

Custom builder:

```rust
cx.set_prompt_builder(|level, message, detail, actions, handle, window, cx| {
    let message = message.to_string();
    let detail = detail.map(ToString::to_string);
    let actions = actions.to_vec();
    let view = cx.new(|cx| MyPrompt::new(level, message, detail, actions, cx));
    handle.with_view(view, window, cx)
});
```

Tuzaklar:

- GPUI re-entrant prompt desteklemez; bir prompt açıkken aynı window'da ikinci
  prompt açma path'i tasarlanmalıdır.
- Custom prompt `Focusable` sağlamalıdır; aksi halde `PromptHandle::with_view`
  focus restore zincirini tamamlayamaz.
- Prompt sonucu buton label'ı değil, `answers` dizisindeki index'tir.

## 14.3. Uygulama Menüsü ve Dock

`crates/gpui/src/platform/app_menu.rs`.

Tipler:

- `Menu { name, items, disabled }`
- `MenuItem`:
  - `Separator`
  - `Submenu(Menu)`
  - `SystemMenu(OsMenu)` — macOS Services gibi sistem submenu'leri.
  - `Action { name, action, os_action, checked, disabled }`
- `OsAction`: `Cut`, `Copy`, `Paste`, `SelectAll`, `Undo`, `Redo`. Native edit
  menu eşlemesi için.

Builder örneği:

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

`MenuItem::action(name, action)` veri taşımayan unit struct action'lar için kısayoldur;
veri taşıyan action'larda da doğrudan action değerini geçebilirsin:
`MenuItem::action("Go To Line", GoToLine { line: 1 })`. Aynı menü modelinin
clone'lanması gerekiyorsa `Menu::owned()`/`MenuItem::owned()` kullanılır.

Diğer menü API'leri (`App` üzerinde):

- `cx.set_dock_menu(Vec<MenuItem>)` — macOS dock right-click menüsü; Windows'ta
  dock menu/jump list modelinin parçası.
- `cx.add_recent_document(path)` — macOS recent items.
- `cx.update_jump_list(menus, entries) -> Task<Vec<SmallVec<[PathBuf; 2]>>>` —
  Windows jump list'i günceller ve kullanıcının listeden kaldırdığı entry'leri
  task sonucu olarak döndürür. Zed `HistoryManager` bu sonucu history'den siler.
- `cx.get_menus()` — şu anda set edili menü modelini okur.

Platform davranışı:

- macOS native `NSMenu` ile çizilir; klavye kısayolları binding'lerden okunur.
- Windows ve Linux platform state'i `OwnedMenu` olarak saklar; Zed bu modeli
  uygulama içi menü/render katmanlarında kullanır.
- Linux dock menüsü backend'de `todo`/no-op'tur; dock/jump-list davranışı için
  platforma özel fallback gerekir.

Tuzak: Aynı action birden çok menü item'a bağlanırsa keymap'te tek shortcut
gösterilir. `os_action` yalnızca macOS native edit menu eşlemesini etkiler;
diğer platformlarda alelade action gibidir.


---

