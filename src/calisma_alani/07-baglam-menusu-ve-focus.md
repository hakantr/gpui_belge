# Item Ayarları, Bağlam Menüsü, ApplicationMenu ve Focus-Follows-Mouse

Zed UI kodunda sık görülen ama GPUI çekirdeği olmayan birkaç yardımcı katman daha vardır; bunlar item davranışı, bağlam menüsü, uygulama menüsü ve focus-follows-mouse gibi konuları kapsar.

---

## Item Ayarları ve SaveIntent

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `SaveIntent` | `deserialize` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `SaveIntent` | Varyantlar | `Overwrite`, `Skip` | Enum seçim değerleri; davranış farkı ilgili konu anlatımında verilir. |


Item ve tab davranışını ayarlar tarafına bağlayan tipler şunlardır:

- `ItemSettings` — `git_status`, `close_position`, `activate_on_close`, `file_icons`, `show_diagnostics`, `show_close_button` alanlarını `tabs` ve `git` ayarlarından üretir.
- `PreviewTabsSettings` — preview tab kaynaklarını ayrı ayrı açıp kapatır: project panel, file finder, multibuffer, kod gezinme, keep-preview gibi.
- `TabContentParams { detail, selected, preview, deemphasized }` — tab çizimine seçim, preview ve odak dışı durumu taşır; `text_color()` anlamsal `Color` döndürür.
- `TabTooltipContent::{Text, Custom}` — tab tooltip'ini string veya özel view olarak tanımlar.
- `ItemBufferKind::{Multibuffer, Singleton, None}` — item'in buffer ilişkisini sınıflandırır.

**Kaydetme ve kapatma akışı.** İşlemler `SaveIntent` ile yönlendirilir:

- Varyantlar: `Save`, `FormatAndSave`, `SaveWithoutFormat`, `SaveAll`, `SaveAs`, `Close`, `Overwrite`, `Skip`.
- Pane close action'ları `CloseActiveItem`, `CloseOtherItems`, `CloseAllItems` gibi action struct'larında optional `SaveIntent` taşır. Dirty/format/conflict davranışı doğrudan bool ile çoğaltılmaz; mevcut save intent zincirine bağlanılır.
- `SaveOptions { format, force_format, autosave }` item save uygulamasının düşük seviyeli karar paketidir.

**Item action ve ayar API kapsamı.** Bu action ve ayar tipleri kendi başına uzun bölüm gerektirmez; hangi davranışı açtıkları aşağıdaki gibi okunmalıdır.

| API | Rol |
|-----|-----|
| `CloseActiveItem` | Aktif pane item'ını kapatır; `save_intent` kaydetme stratejisini, `close_pinned` pinli tab davranışını belirler. |
| `CloseOtherItems` | Aktif item dışındaki item'ları kapatır; `save_intent` ve `close_pinned` aynı sözleşmeyi kullanır. |
| `CloseAllItems` | Pane içindeki tüm item'ları kapatır; dirty dosyalar için yine `SaveIntent` zincirine gider. |
| `FormatAndSave` | Aktif item'ı formatlamayı zorlayarak kaydeder. |
| `Save` | Aktif item'ı `save_intent` seçeneğiyle kaydeder. |
| `SaveAll` | Açık dosyaların tümünü kaydeder; optional `save_intent` ile davranış inceltilir. |
| `SaveAs` | Aktif item için yeni path isteme akışını başlatır. |
| `SaveWithoutFormat` | Formatlayıcı çalıştırmadan kaydetme yolunu seçer. |
| `SaveOptions` | `format`, `force_format`, `autosave` alanlarıyla item save uygulamasının düşük seviyeli karar paketidir. |
| `PreviewTabsSettings` | Preview tab kaynaklarını `enabled`, project panel, file finder, multibuffer ve code navigation alanlarıyla açıp kapatır. |
| `TabContentParams` | Tab çiziminde `detail`, `selected`, `preview`, `deemphasized` durumunu taşır. |
| `TabTooltipContent` | Tooltip'i düz metin veya özel view olarak temsil eder. |
| `ItemBufferKind` | `Multibuffer`, `Singleton`, `None` sınıflandırmasıyla item'in buffer bağını açıklar. |
| `focus_follows_mouse` | Hover hedefini debounce ile odak hedefi yapan modül/trait ailesidir. |

---

## ContextMenu ve PopoverMenu

`ContextMenu` `ManagedView` olarak modal/popover zincirine takılır. İçerik modeli şu öğelerden oluşur:

- `ContextMenuItem::{Separator, Header, HeaderWithLink, Label, Entry, CustomEntry, Submenu}`.
- `ContextMenuEntry` label, icon, checked/toggle, action, disabled, secondary handler, documentation aside ve end-slot gibi alanları taşır.
- `ContextMenu::build(window, cx, |menu, window, cx| ...)` menü entity'sini üretir.
- `menu.context(focus_handle)` menü action kullanabilirsinliği ve keybinding görüntüsü için belirli bir odak bağlamını kullanır.

`PopoverMenu<M: ManagedView>` anchor element ile yönetilen menü view'ini bağlar:

- `PopoverMenu::new(id)`, `.menu(...)`, `.with_handle(handle)`, `.anchor(...)`, `.attach(...)`, `.offset(...)`, `.full_width(...)`, `.on_open(...)`.
- `PopoverMenuHandle<M>` dışarıdan toggle, kapatma ve açık menü entity'sine erişmek için saklarsın.
- Popover konumlandırması `window.layout_bounds` ve çift `on_next_frame` desenini kullanabilir; anchor sınırları (`bounds`) ilk karede, menü sınırları bir sonraki karede bilinir.

---

## İstemci Tarafı ApplicationMenu

macOS dışındaki istemci tarafı application menüsü `title_bar::ApplicationMenu` ile çizilir:

- `ApplicationMenu::new(window, cx)` `cx.get_menus()` ile platform ve app menülerini okur; her üst seviye menü için bir `PopoverMenuHandle<ContextMenu>` saklar.
- `OpenApplicationMenu(String)` action'ı belirli menüyü açar.
- `ActivateMenuLeft` ve `ActivateMenuRight` client-side menü bar içinde yatay gezinmeyi sağlar.
- `ApplicationMenu` boş alt menüleri ve ardışık veya izleyen ayırıcıları temizler, sonra `OwnedMenuItem::{Action, Submenu, Separator, SystemMenu}` değerlerini işler. `Action`, `Submenu` ve `Separator` `ContextMenu` girişlerine dönüşür; `SystemMenu(_)` client-side context'te anlamlı olmadığı için yok sayılır.

---

## FocusFollowsMouse

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `FocusFollowsMouse` | `deserialize` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `FocusFollowsMouse` | Trait üyeleri | `focus_follows_mouse` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `FocusFollowsMouse` | Alanlar | `debounce`, `enabled` | Public veri alanları; runtime, stil veya ayar sözleşmesinin taşınan parçalarıdır. |


`FocusFollowsMouse` trait'i `StatefulInteractiveElement` üzerine eklersin:

```rust
oge.focus_follows_mouse(WorkspaceSettings::get_global(cx).focus_follows_mouse, cx)
```

- Ayar açık olduğunda hover girişi sırasında hedef `AnyWindowHandle + FocusHandle` global duruma yazılır.
- Debounce için `cx.background_executor().timer(settings.debounce).await` kullanırsın.
- Debounce sonunda `cx.update_window(window, |_, window, cx| window.focus(&focus, cx))` çağırırsın.
- Daha spesifik bir alt focus hedefi varken üst hover'ın bunu ezmesi istenmediğinde `focus_handle.contains(existing, window)` kontrolü yaparsın.

---

## Tuzaklar

Bu yardımcı katmanlarda dikkat edilmesi gerekenler:

- Bağlam menüsü action'ları odaktaki element context'ine göre enable veya disable olur; menü odak bağlamı olmadan kurulduğunda bazı action'lar görünür ama çalışmayabilir.
- ApplicationMenu platform menü çubuğu değildir; macOS yerel menüsü ayrı platform menü akışından gelir.
- Focus-follows-mouse global debounce durumu kullanır; aynı anda birden çok hover hedefi yarışabilir, bu nedenle daha spesifik alt kontrol kaldırılmamalıdır.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `SaveOptions`

| Grup | API | Not |
|---|---|---|
| Alanlar | `autosave`, `force_format`, `format` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PreviewTabsSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enable_keep_preview_on_code_navigation`, `enable_preview_file_from_code_navigation`, `enable_preview_from_file_finder`, `enable_preview_from_multibuffer`, `enable_preview_from_project_panel`, `enable_preview_multibuffer_from_code_navigation`, `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CloseActiveItem`

| Grup | API | Not |
|---|---|---|
| Alanlar | `close_pinned`, `save_intent` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CloseOtherItems`

| Grup | API | Not |
|---|---|---|
| Alanlar | `close_pinned`, `save_intent` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CloseAllItems`

| Grup | API | Not |
|---|---|---|
| Alanlar | `close_pinned`, `save_intent` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SaveAll`

| Grup | API | Not |
|---|---|---|
| Alanlar | `save_intent` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `Save`

| Grup | API | Not |
|---|---|---|
| Alanlar | `save_intent` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

<!-- phase14-api-anchor:end -->
