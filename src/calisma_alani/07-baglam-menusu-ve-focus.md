# Item Ayarları, Bağlam Menüsü ve Focus-Follows-Mouse

Zed UI kodunda sıkça karşılaşılan ancak doğrudan GPUI çekirdeğine ait olmayan birkaç yardımcı katman daha bulunur; bu katmanlar item davranışları, bağlam menüleri (context menu) ve focus-follows-mouse (odağın fareyi takip etmesi) gibi işlevleri kapsar.

---

## Item Ayarları ve SaveIntent

Item ve tab (sekme) davranışlarını ayarlar sistemine bağlayan veri yapıları şunlardır:

- `ItemSettings` — `git_status`, `close_position`, `activate_on_close`, `file_icons`, `show_diagnostics` ve `show_close_button` alanlarını `tabs` ve `git` ayarlarından üretir.
- `PreviewTabsSettings` — Önizleme sekmelerinin (preview tab) kaynaklarını ayrı ayrı açıp kapatmayı sağlar: project panel, file finder, multibuffer, kod gezinmesi (code navigation) ve keep-preview gibi.
- `TabContentParams { detail, selected, preview, deemphasized }` — Sekme çizimine seçim, önizleme ve odak dışı (deemphasized) olma durumlarını taşır; `text_color()` metodu anlamsal bir `Color` döndürür.
- `TabTooltipContent::{Text, Custom}` — Sekme tooltip'ini (ipucu metni) düz metin veya özel bir görünüm (custom view) olarak tanımlar.
- `ItemBufferKind::{Multibuffer, Singleton, None}` — Sekme öğesinin (item) buffer (tampon bellek) ilişkisini sınıflandırır.

**Kaydetme ve Kapatma Akışı.** Dosya kaydetme ve kapatma süreçleri `SaveIntent` yapısı aracılığıyla yönlendirilir:

- Varyantları: `Save`, `FormatAndSave`, `SaveWithoutFormat`, `SaveAll`, `SaveAs`, `Close`, `Overwrite`, `Skip`.
- Pane kapatma eylemleri (`CloseActiveItem`, `CloseOtherItems`, `CloseAllItems` vb. action struct'ları) isteğe bağlı (optional) olarak bir `SaveIntent` taşır. Dosyanın düzenlenmiş (dirty) olması, formatlama veya çakışma (conflict) durumları bağımsız boolean alanlarla çoğaltılmak yerine doğrudan mevcut `SaveIntent` zincirine bağlanır.
- `SaveOptions { format, force_format, autosave }` — Item kaydetme uygulamasının düşük seviyeli karar paketidir.

**Item Action ve Ayar API Kapsamı.** Bu eylem ve ayar tipleri kendi başına uzun açıklamalar gerektirmez; üstlendikleri görevler aşağıdaki tabloda özetlenmiştir:

| API | Rolü |
|-----|-----|
| `CloseActiveItem` | Aktif pane öğesini kapatır; `save_intent` kaydetme stratejisini, `close_pinned` ise sabitlenmiş sekmelerin davranışını belirler. |
| `CloseOtherItems` | Aktif sekme dışındaki diğer tüm sekmeleri kapatır; `save_intent` ve `close_pinned` alanları aynı kuralları kullanır. |
| `CloseAllItems` | Pane içindeki tüm sekmeleri kapatır; kaydedilmemiş (dirty) dosyalar için yine `SaveIntent` zincirine başvurur. |
| `FormatAndSave` | Aktif öğeyi formatlamaya zorlayarak kaydeder. |
| `Save` | Aktif öğeyi `save_intent` seçeneğiyle kaydeder. |
| `SaveAll` | Açık olan tüm dosyaları kaydeder; isteğe bağlı `save_intent` ile kaydetme davranışı detaylandırılır. |
| `SaveAs` | Aktif öğe için yeni yol (path) isteme akışını başlatır. |
| `SaveWithoutFormat` | Kod formatlayıcıyı çalıştırmadan doğrudan kaydetme yolunu seçer. |
| `SaveOptions` | `format`, `force_format` ve `autosave` alanlarıyla item kaydetme uygulamasının düşük seviyeli karar parametrelerini taşır. |
| `PreviewTabsSettings` | Önizleme sekmelerini `enabled`, project panel, file finder, multibuffer ve code navigation ayarlarıyla açıp kapatmaya yarar. |
| `TabContentParams` | Sekme çiziminde `detail`, `selected`, `preview` ve `deemphasized` durumlarını taşır. |
| `TabTooltipContent` | Tooltip içeriğini düz metin veya özel bir view olarak temsil eder. |
| `ItemBufferKind` | `Multibuffer`, `Singleton`, `None` sınıflandırmasıyla öğenin tampon bellek bağını tanımlar. |
| `focus_follows_mouse` | Hover (üzerine gelme) hedefini belirli bir gecikmeyle (debounce) odak hedefi haline getiren modül ve trait ailesidir. |

---

## ContextMenu ve PopoverMenu

`ContextMenu`, bir `ManagedView` olarak modal ya da popover zincirine dahil edilir. İçerik modeli şu öğelerden oluşur:

- `ContextMenuItem::{Separator, Header, HeaderWithLink, Label, Entry, CustomEntry, Submenu}`.
- `ContextMenuEntry` — Etiket (label), ikon, checked/toggle durumu, action, disabled durumu, ikincil işleyici (secondary handler), dokümantasyon paneli (documentation aside) ve end-slot gibi alanları taşır.
- `ContextMenu::build(window, cx, |menu, window, cx| ...)` — Menü entity'sini üretir.
- `menu.context(focus_handle)` — Menü action'larının çalışacağı odak bağlamını ve klavye kısayolu (keybinding) görüntüsünü belirler.

`PopoverMenu<M: ManagedView>`, bir hedef elemana (anchor element) bağlı olarak yönetilen menü görünümünü bağlar:

- `PopoverMenu::new(id)`, `.menu(...)`, `.with_handle(handle)`, `.anchor(...)`, `.attach(...)`, `.offset(...)`, `.full_width(...)`, `.on_open(...)` metotlarıyla yapılandırılır.
- `PopoverMenuHandle<M>`, menüyü dışarıdan açmak, kapatmak ya da aç-kapat (toggle) yapmak ve menünün açık mı yoksa odaklanmış mı olduğunu sorgulamak amacıyla saklanır; genel arayüzü `show`, `hide`, `toggle`, `is_deployed`, `is_focused` ve `refresh_menu` metotları ile sınırlıdır ve açık olan menü entity'sine doğrudan erişim vermez.
- Konumlandırma ile odaklama iki ayrı mekanizmadır. Hedef elemanın (anchor) sınırları bir çizim geçişinde `window.layout_bounds(...)` ile yakalanıp eleman durumunda saklanır; menü bir sonraki düzen (layout) geçişinde bu sınırlar referans alınarak konumlandırılır. Çift `on_next_frame` deseni ise konumlandırmadan bağımsızdır; ertelenerek çizilen menü ekrana yansıdıktan sonra menünün focus handle'ını odaklayarak sekme düğmelerinin titremesini önler.

---

## İstemci Tarafı Uygulama Menüsü (Çapraz Referans)

İstemci tarafı uygulama menüsü (`ApplicationMenu`), `workspace` crate'ine değil `title_bar` ürün katmanına aittir. Kaynak kodda da özel (private) bir modülde yer aldığı için dışa açık bir API değildir. Davranışı (menü kaynağı, `OpenApplicationMenu`, klavye navigasyonu, menü modu) [Üst Bar](../ust_bar/ust_bar.md) bölümünde detaylandırılmıştır. Burada yalnızca aradaki ayrıma dikkat edilmelidir: yukarıda anlatılan `ContextMenu` ve `PopoverMenu` genel `ui` bileşenleridir ve her arayüzde kullanılabilir; uygulama menüsü ise yalnızca ürünün başlık çubuğunda kurulur.

---

## FocusFollowsMouse

`FocusFollowsMouse` trait'i, `StatefulInteractiveElement` üzerine eklenir:

```rust
oge.focus_follows_mouse(WorkspaceSettings::get_global(cx).focus_follows_mouse, cx)
```

- Ayar etkinleştirildiğinde, fare ile üzerine gelinen (hover) hedef `AnyWindowHandle + FocusHandle` bilgisi global duruma yazılır.
- Debounce (gecikme) süresi için `cx.background_executor().timer(settings.debounce).await` yapısı kullanılır.
- Bu gecikme süresinin sonunda `cx.update_window(window, |_, window, cx| window.focus(&focus, cx))` çağrısı gerçekleştirilir.
- Daha spesifik bir alt odak hedefi mevcutken üst düzey hover aksiyonunun bunu ezmesi istenmiyorsa `focus_handle.contains(existing, window)` kontrolü gerçekleştirilir.

---

## Dikkat Edilmesi Gereken Hususlar

Bu yardımcı katmanlarla çalışırken şu noktalara dikkat edilmesi önem taşır:

- Bağlam menüsü (context menu) eylemleri, odaklanmış eleman bağlamına (element context) göre etkinleşir veya devre dışı kalır. Eğer menü bir odak bağlamı olmadan kurulursa, bazı eylemler görünmesine rağmen çalışmayabilir.
- Focus-follows-mouse özelliği global bir debounce durumu kullanır. Aynı anda birden fazla hover hedefinin yarışması durumunda, daha spesifik alt kontrollerin korunması gerekir.
