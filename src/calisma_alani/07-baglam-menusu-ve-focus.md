# Item Ayarları, Bağlam Menüsü ve Focus-Follows-Mouse

Zed UI kodunda sık görülen ama GPUI çekirdeği olmayan birkaç yardımcı katman daha vardır; bunlar item davranışı, bağlam menüsü ve focus-follows-mouse gibi konuları kapsar.

---

## Item Ayarları ve SaveIntent

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
- `ContextMenuEntry` label, icon, checked/toggle, action, disabled, secondary işleyici, documentation aside ve end-slot gibi alanları taşır.
- `ContextMenu::build(window, cx, |menu, window, cx| ...)` menü entity'sini üretir.
- `menu.context(focus_handle)` menü action'larının çalışacağı odak bağlamını ve keybinding görüntüsünü belirler.

`PopoverMenu<M: ManagedView>` anchor element ile yönetilen menü view'ini bağlar:

- `PopoverMenu::new(id)`, `.menu(...)`, `.with_handle(handle)`, `.anchor(...)`, `.attach(...)`, `.offset(...)`, `.full_width(...)`, `.on_open(...)`.
- `PopoverMenuHandle<M>` menüyü dışarıdan açmak, kapatmak ya da aç-kapat yapmak ve menünün açık mı odaklı mı olduğunu sorgulamak için saklarsın; genel yüzeyi `show`/`hide`/`toggle`/`is_deployed`/`is_focused`/`refresh_menu` ile sınırlıdır, açık menü entity'sine erişim vermez.
- Konumlandırma ile odaklama iki ayrı mekanizmadır. Anchor'a bağlı çocuk elemanın sınırları bir çizim geçişinde `window.layout_bounds(...)` ile yakalanıp eleman durumunda saklanır; menü bir sonraki düzen geçişinde bu sınırlardan konumlandırılır. Çift `on_next_frame` deseni ise konumlandırmayla ilgili değildir: ertelenmiş çizilen menü çizildikten sonra menünün focus handle'ını odaklayarak sekme düğmelerinin titremesini önler.

---

## İstemci tarafı uygulama menüsü (çapraz referans)

İstemci tarafı uygulama menüsü (`ApplicationMenu`), `workspace` crate'ine değil `title_bar` ürün katmanına aittir; kaynakta da private bir modülde durduğu için dış API değildir. Davranışı (menü kaynağı, `OpenApplicationMenu`, klavye gezinmesi, menü modu) [Üst Bar](../ust_bar/ust_bar.md) bölümünde anlatılır. Burada yalnız ayrımı not ediyoruz: yukarıda anlatılan `ContextMenu`/`PopoverMenu` genel `ui` bileşenleridir ve her yüzeyde kullanılır; uygulama menüsü ise yalnız ürün başlığında kurarsın.

---

## FocusFollowsMouse

`FocusFollowsMouse` trait'i `StatefulInteractiveElement` üzerine eklersin:

```rust
oge.focus_follows_mouse(WorkspaceSettings::get_global(cx).focus_follows_mouse, cx)
```

- Ayar açık olduğunda hover girişi sırasında hedef `AnyWindowHandle + FocusHandle` global duruma yazılır.
- Debounce için `cx.background_executor().timer(settings.debounce).await` kullanırsın.
- Debounce sonunda `cx.update_window(window, |_, window, cx| window.focus(&focus, cx))` çağırırsın.
- Daha spesifik bir alt focus hedefi varken üst hover'ın bunu ezmesi istenmediğinde `focus_handle.contains(existing, window)` kontrolü yaparsın.

---

## Dikkat Noktaları

Bu yardımcı katmanlarda dikkat edilmesi gerekenler:

- Bağlam menüsü action'ları odaktaki element context'ine göre etkin veya disabled olur; menüyü odak bağlamı olmadan kurarsan bazı action'lar görünür ama çalışmayabilir.
- Focus-follows-mouse global debounce durumu kullanır; aynı anda birden çok hover hedefi yarışabilir, bu nedenle daha spesifik alt kontrolü koruman gerekir.
