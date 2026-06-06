# Bildirim Yardımcıları ve Async Hata Gösterimi

Bildirim sistemi sadece `show_notification` çağrısından ibaret değildir. Çalışma alanı dışındaki uygulama (app) seviyesinde bildirimlerin yönetilmesi ve asenkron (async) hata yayılımı için ek yardımcı trait'ler bulunur.

---

## App-level Notification (Uygulama Seviyesi Bildirimler)

Aktif bir çalışma alanı olup olmadığına bakılmaksızın bildirim göstermek için aşağıdaki yapılar kullanılır:

- `show_app_notification(id, cx, build)` — Bildirimi tüm mevcut `MultiWorkspace` pencerelerindeki çalışma alanlarına dağıtır ve yeni açılacak çalışma alanlarına da taşınması için uygulama seviyesinde kayıt altında tutar.
- `dismiss_app_notification(id, cx)` — Aynı kimliğe (id) sahip uygulama bildirimlerini global kayıttan ve tüm çalışma alanlarından kaldırır.
- `NotificationFrame` — Başlık, içerik, suppress (bastırma)/close (kapatma) butonu ve son ek (suffix) bileşenlerini bir araya getirmek için kullanılan standart çerçevedir.
- `simple_message_notification::MessageNotification` — Birincil/ikincil mesaj, ikon, tıklama işleyicisi, close/suppress ve "more info" (daha fazla bilgi) URL'si gibi hazır alanlar sağlar.

---

## Hata Yayılımı (Error Propagation)

Asenkron süreçlerde ve çalışma alanı bağlamlarında oluşan hataları yönetmek için kullanılan yardımcılar şu şekildedir:

- `NotifyResultExt::notify_err(workspace, cx)` — `Result` bir hata (Err) döndürdüğünde, bunu çalışma alanında bir bildirim olarak gösterir ve geriye `None` döndürür.
- `notify_workspace_async_err(weak_workspace, async_cx)` — Asenkron bir görev (async task) içinde, weak workspace referansına hata bildirimi gönderir.
- `notify_app_err(cx)` — Hatayı, tüm çalışma alanlarına dağıtılacak şekilde uygulama seviyesinde (app-level) bir bildirim olarak gösterir.
- `NotifyTaskExt::detach_and_notify_err(workspace, window, cx)` — `Task<Result<...>>` sonucunu pencere üzerinde spawn eder ve olası bir hatayı çalışma alanı bildirimine dönüştürür.
- `DetachAndPromptErr::prompt_err` ve `detach_and_prompt_err` — `anyhow::Result` görevini prompt tabanlı bir kullanıcı arayüzü hatasına dönüştürür.

---

## Kullanım Seçimi

Hangi yardımcının tercih edileceği, işlemin gerçekleştiği bağlama göre belirlenir:

- Kullanıcı eyleminin sonucu doğrudan çalışma alanı içinde gösterilmeliyse `notify_err` veya `detach_and_notify_err` kullanılır.
- Kritik bir onay ya da seçim yapılması gerekiyorsa `detach_and_prompt_err` tercih edilir.
- Hem mevcut hem de sonradan açılan çalışma alanlarında görünmesi gereken başlangıç (startup) hataları veya global hatalar için `notify_app_err` veya `show_app_notification` kullanılır.

**Bildirim API Kapsamı.** Aşağıdaki tip ve fonksiyonlar aynı bildirim hattı üzerinden çalışır:

| API | Rolü |
|-----|-----|
| `notifications` | Bildirim listesi, uygulama seviyesi bildirimler ve asenkron hata yardımcılarının sınırlarını çizen modüldür. |
| `NotificationFrame` | Başlık, içerik, suffix, suppress ve close butonlarını standart bir bildirim çerçevesinde birleştirir. |
| `simple_message_notification` | Hazır mesaj bildirim görünümünü barındıran alt modüldür. |
| `MessageNotification` | Birincil/ikincil mesaj, ikon, tıklama işleyicisi, close/suppress ve more-info URL alanlarını builder metotlarıyla kurar. |
| `NotificationId` | `unique`, `composite` ve `named` yardımcılarıyla bildirimlerin tekilleştirilmesini (deduplication) sağlayan kimlikler üretir. |
| `NotifyResultExt` | `Result` değerini workspace veya app bildirimine çeviren extension (genişletme) trait'idir. |
| `NotifyTaskExt` | `Task<Result<_>>` sonucunu spawn edip olası hataları bildirim olarak gösterir. |
| `DetachAndPromptErr` | Asenkron sonucu prompt tabanlı kullanıcı hatasına çevirir; `prompt_err` beklenebilir yapıdayken, `detach_and_prompt_err` işlemi arka planda yürütür. |
| `show_app_notification` | Uygulama seviyesindeki bildirimi tüm `MultiWorkspace` çalışma alanlarına dağıtır ve yeni workspace'ler için global kayıt altında tutar. |
| `dismiss_app_notification` | Aynı id'li uygulama seviyesindeki bildirim kayıtlarını ve workspace üzerindeki kopyalarını kaldırır. |
| `SuppressEvent` | Bildirim görünümünden workspace'e "bu bildirimi bastır" kararını iletir. |

---

## Dikkat Edilmesi Gereken Hususlar

Bildirim yardımcıları kullanılırken gözden kaçırılmaması gereken noktalar şunlardır:

- `detach_and_log_err` fonksiyonu hatayı yalnızca günlüğe (log) kaydeder; kullanıcıya görünür bir hata gösterilmesi isteniyorsa çalışma alanı bildirimleri veya prompt yardımcılarından biri tercih edilmelidir.
- `show_app_notification` aynı id ile birden fazla çalışma alanında gösterim yapabilir; bu nedenle id değerinin `NotificationId::named` veya `composite` ile bilinçli bir şekilde seçilmesi gerekir.
- `MessageNotification` tıklama işleyicileri `Window` ve bildirimin kendi `Context<Self>` bağlamını alır; çalışma alanının durumuna ihtiyaç duyuluyorsa weak çalışma alanı veya entity yakalanır ve bunların serbest bırakılmış (dropped) olma ihtimali ele alınır.
