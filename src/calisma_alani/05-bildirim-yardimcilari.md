# Bildirim Yardımcıları ve Async Hata Gösterimi

Bildirim sistemi sadece `show_notification` çağrısından ibaret değildir. Çalışma alanı dışı app seviyesinde bildirim ve async hata yayılımı için ek yardımcı trait'ler bulunur.

---

## App-level notification

Aktif çalışma alanı olup olmadığına bakmadan bildirim göstermek için:

- `show_app_notification(id, cx, build)` — aktif çalışma alanı varsa orada, yoksa tüm çalışma alanlarında notification gösterir.
- `dismiss_app_notification(id, cx)` — aynı id'li app notification'ları kapatır.
- `NotificationFrame` — başlık, içerik, suppress/close butonu ve suffix kompoze etmek için kullanılan standart çerçeve.
- `simple_message_notification::MessageNotification` — birincil/ikincil mesaj, ikon, tıklama işleyicisi, close/suppress ve "more info" URL gibi hazır alanlar sağlar.

---

## Hata yayılımı

Async ve çalışma alanı bağlamlarındaki hatalar için yardımcılar şu şekildedir:

- `NotifyResultExt::notify_err(workspace, cx)` — `Result` hata olduğunda çalışma alanı notification gösterir ve `None` döndürür.
- `notify_workspace_async_err(weak_workspace, async_cx)` — async task içinde weak workspace'e hata notification gönderir.
- `notify_app_err(cx)` — aktif çalışma alanı yoksa app seviyesinde notification gösterir.
- `NotifyTaskExt::detach_and_notify_err(workspace, window, cx)` — `Task<Result<...>>` sonucunu pencere üzerinde spawn eder ve hatayı çalışma alanı notification'a çevirir.
- `DetachAndPromptErr::prompt_err` ve `detach_and_prompt_err` — `anyhow::Result` task'ını prompt tabanlı bir kullanıcı hatasına çevirir.

---

## Kullanım seçimi

Hangi yardımcının seçileceği bağlama göre belirlersin:

- Kullanıcı aksiyonunun sonucu doğrudan çalışma alanı içinde görünmeliyse `notify_err` veya `detach_and_notify_err`.
- Kritik onay ya da seçim gerekiyorsa `detach_and_prompt_err`.
- Çalışma alanı yokken de görünmesi gereken startup veya global hata için `notify_app_err` veya `show_app_notification`.

**Bildirim API kapsamı.** Aşağıdaki tip ve fonksiyonlar aynı notification hattında çalışır:

| API | Rol |
|-----|-----|
| `notifications` | Notification listesi, app-level notification ve async hata yardımcılarının modül sınırıdır. |
| `NotificationFrame` | Başlık, içerik, suffix, suppress ve close butonlarını standart bir bildirim çerçevesinde birleştirir. |
| `simple_message_notification` | Hazır mesaj notification view'ini barındıran alt modüldür. |
| `MessageNotification` | Birincil/ikincil mesaj, ikon, click handler, close/suppress ve more-info URL alanlarını builder metodlarıyla kurar. |
| `NotificationId` | `unique`, `composite` ve `named` yardımcılarıyla bildirim dedupe kimliği üretir. |
| `NotifyResultExt` | `Result` değerini workspace veya app notification'a çeviren extension trait'tir. |
| `NotifyTaskExt` | `Task<Result<_>>` sonucunu spawn edip hatayı notification olarak gösterir. |
| `DetachAndPromptErr` | Async sonucu prompt tabanlı kullanıcı hatasına çevirir; `prompt_err` beklenebilir, `detach_and_prompt_err` arka plana bırakılır. |
| `show_app_notification` | Aktif workspace varsa orada, yoksa tüm workspace'lerde app-level notification gösterir. |
| `dismiss_app_notification` | Aynı id'li app-level notification kayıtlarını kaldırır. |
| `SuppressEvent` | Notification view'den workspace'e "bu bildirimi bastır" kararını taşır. |

---

## Tuzaklar

Bildirim yardımcılarında atlanan noktalar:

- `detach_and_log_err` yalnızca loglar; kullanıcıya görünür bir hata isteniyorsa çalışma alanı notification veya prompt yardımcılarından biri tercih edersin.
- `show_app_notification` aynı id ile birden fazla çalışma alanında gösterim yapabilir; id `NotificationId::named` veya `composite` ile bilinçli seçmen gerekir.
- `MessageNotification` tıklama işleyicileri `Window` ve `App` alır; çalışma alanı durumu gerekiyorsa weak çalışma alanı veya entity yakalanır ve düşmüş olma ihtimali ele alırsın.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `NotificationFrame`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new`, `on_close`, `show_close_button`, `show_suppress_button`, `with_content`, `with_suffix`, `with_title` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `MessageNotification`

| Grup | API | Not |
|---|---|---|
| Metotlar 1 | `dismiss`, `more_info_message`, `more_info_url`, `new`, `new_from_builder`, `primary_icon`, `primary_icon_color`, `primary_message` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 2 | `primary_on_click`, `primary_on_click_arc`, `secondary_icon`, `secondary_icon_color`, `secondary_message`, `secondary_on_click`, `secondary_on_click_arc`, `show_close_button` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 3 | `show_suppress_button`, `with_title` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `NotifyResultExt`

| Grup | API | Not |
|---|---|---|
| Trait assoc type | `Ok` | Trait sözleşmesinin public ilişkili tipleridir. |
| Trait metotları | `notify_app_err`, `notify_err`, `notify_workspace_async_err` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `NotifyTaskExt`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `detach_and_notify_err` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `DetachAndPromptErr`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `detach_and_prompt_err`, `prompt_err` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

<!-- phase14-api-anchor:end -->
