# Bildirim Yardımcıları ve Async Hata Gösterimi

Bildirim sistemi sadece `show_notification` çağrısından ibaret değildir. Çalışma alanı dışı app seviyesinde bildirim ve async hata yayılımı için ek yardımcı trait'ler bulunur.

---

## App-level notification

Aktif çalışma alanı olup olmadığına bakmadan bildirim göstermek için:

- `show_app_notification(id, cx, build)` — bildirimi tüm mevcut `MultiWorkspace` pencerelerindeki çalışma alanlarına dağıtır ve yeni çalışma alanlarına da taşınması için app-level kayıt altında tutar.
- `dismiss_app_notification(id, cx)` — aynı id'li app notification'ları global kayıttan ve tüm çalışma alanlarından kaldırır.
- `NotificationFrame` — başlık, içerik, suppress/close butonu ve suffix kompoze etmek için kullanılan standart çerçeve.
- `simple_message_notification::MessageNotification` — birincil/ikincil mesaj, ikon, tıklama işleyicisi, close/suppress ve "more info" URL gibi hazır alanlar sağlar.

---

## Hata yayılımı

Async ve çalışma alanı bağlamlarındaki hatalar için yardımcılar şu şekildedir:

- `NotifyResultExt::notify_err(workspace, cx)` — `Result` hata olduğunda çalışma alanı notification gösterir ve `None` döndürür.
- `notify_workspace_async_err(weak_workspace, async_cx)` — async task içinde weak workspace'e hata notification gönderir.
- `notify_app_err(cx)` — hatayı app-level notification olarak tüm çalışma alanlarına dağıtılacak şekilde gösterir.
- `NotifyTaskExt::detach_and_notify_err(workspace, window, cx)` — `Task<Result<...>>` sonucunu pencere üzerinde spawn eder ve hatayı çalışma alanı notification'a çevirir.
- `DetachAndPromptErr::prompt_err` ve `detach_and_prompt_err` — `anyhow::Result` task'ını prompt tabanlı bir kullanıcı hatasına çevirir.

---

## Kullanım seçimi

Hangi yardımcının seçileceği bağlama göre belirlersin:

- Kullanıcı aksiyonunun sonucu doğrudan çalışma alanı içinde görünmeliyse `notify_err` veya `detach_and_notify_err`.
- Kritik onay ya da seçim gerekiyorsa `detach_and_prompt_err`.
- Mevcut ve sonradan açılan çalışma alanlarında görünmesi gereken startup veya global hata için `notify_app_err` veya `show_app_notification`.

**Bildirim API kapsamı.** Aşağıdaki tip ve fonksiyonlar aynı notification hattında çalışır:

| API | Rol |
|-----|-----|
| `notifications` | Notification listesi, app-level notification ve async hata yardımcılarının modül sınırıdır. |
| `NotificationFrame` | Başlık, içerik, suffix, suppress ve close butonlarını standart bir bildirim çerçevesinde birleştirir. |
| `simple_message_notification` | Hazır mesaj notification view'ini barındıran alt modüldür. |
| `MessageNotification` | Birincil/ikincil mesaj, ikon, click işleyicisi, close/suppress ve more-info URL alanlarını builder metodlarıyla kurar. |
| `NotificationId` | `unique`, `composite` ve `named` yardımcılarıyla bildirim dedupe kimliği üretir. |
| `NotifyResultExt` | `Result` değerini workspace veya app notification'a çeviren extension trait'tir. |
| `NotifyTaskExt` | `Task<Result<_>>` sonucunu spawn edip hatayı notification olarak gösterir. |
| `DetachAndPromptErr` | Async sonucu prompt tabanlı kullanıcı hatasına çevirir; `prompt_err` beklenebilir, `detach_and_prompt_err` arka plana bırakırsın. |
| `show_app_notification` | App-level bildirimi tüm `MultiWorkspace` çalışma alanlarına dağıtır ve yeni workspace'ler için global kayıt altında tutar. |
| `dismiss_app_notification` | Aynı id'li app-level notification kayıtlarını ve workspace kopyalarını kaldırır. |
| `SuppressEvent` | Notification view'den workspace'e "bu bildirimi bastır" kararını taşır. |

---

## Dikkat Noktaları

Bildirim yardımcılarında atlanması kolay noktalar:

- `detach_and_log_err` yalnızca loglar; kullanıcıya görünür bir hata isteniyorsa çalışma alanı notification veya prompt yardımcılarından biri tercih edersin.
- `show_app_notification` aynı id ile birden fazla çalışma alanında gösterim yapabilir; id `NotificationId::named` veya `composite` ile bilinçli seçmen gerekir.
- `MessageNotification` tıklama işleyicileri `Window` ve bildirimin kendi `Context<Self>` bağlamını alır; çalışma alanı durumu gerekiyorsa weak çalışma alanı veya entity yakalanır ve düşmüş olma ihtimali ele alırsın.
