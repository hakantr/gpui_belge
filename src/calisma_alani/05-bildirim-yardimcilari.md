# Bildirim Yardımcıları ve Asenkron Hata Gösterimi

Bildirim sistemi sadece `show_notification` çağrısından ibaret değildir. Çalışma alanı dışındaki uygulama seviyesinde bildirimlerin yönetilmesi ve asenkron hata yayılımı için ek yardımcı trait'ler bulunur.

---

## Uygulama Seviyesi Bildirimler

Aktif bir çalışma alanı olup olmadığına bakılmaksızın bildirim göstermek için aşağıdaki yapılar kullanılır:

- `show_app_notification(id, cx, build)` — Bildirimi tüm mevcut `MultiWorkspace` pencerelerindeki çalışma alanlarına dağıtır ve yeni açılacak çalışma alanlarına da taşınması için uygulama seviyesinde kayıt altında tutar.
- `dismiss_app_notification(id, cx)` — Aynı kimliğe (id) sahip uygulama bildirimlerini global kayıttan ve tüm çalışma alanlarından kaldırır.
- `simple_message_notification::MessageNotification` — Standart bildirim görünümünü kurar: başlık, birincil/ikincil mesaj, içerik ikonu, eylem düğmeleri, kopyala düğmesi, kapatma/bastırma kontrolleri ve daha fazla bilgi bağlantısı gibi hazır alanları zincir metotlarıyla bir araya getirir.

---

## Hata Yayılımı (Error Propagation)

Asenkron süreçlerde ve çalışma alanı bağlamlarında oluşan hataları yönetmek için kullanılan yardımcılar şu şekildedir:

- `NotifyResultExt::notify_err(workspace, cx)` — `Result` bir hata (Err) döndürdüğünde, bunu çalışma alanında bir bildirim olarak gösterir ve geriye `None` döndürür.
- `notify_workspace_async_err(weak_workspace, async_cx)` — Asenkron bir görev içinde, zayıf workspace referansına hata bildirimi gönderir.
- `notify_app_err(cx)` — Hatayı, tüm çalışma alanlarına dağıtılacak şekilde uygulama seviyesinde bir bildirim olarak gösterir.
- `NotifyTaskExt::detach_and_notify_err(workspace, window, cx)` — `Task<Result<...>>` sonucunu pencere üzerinde spawn eder ve olası bir hatayı çalışma alanı bildirimine dönüştürür.
- `DetachAndPromptErr::prompt_err` ve `detach_and_prompt_err` — `anyhow::Result` görevini prompt tabanlı bir kullanıcı arayüzü hatasına dönüştürür.

---

## `workspace_error` Modülü ve Tipli Çalışma Alanı Hataları (WorkspaceError)

`Workspace::show_error<E: WorkspaceError + 'static>(err, cx)` bir hatayı **sahiplenerek** alır ve onu standart bir hata bildirimine çevirir. Hatanın bildirime nasıl döküleceğini `WorkspaceError` trait'i belirler:

```rust
pub trait WorkspaceError {
    fn primary_message(&self) -> SharedString;
    fn secondary_message(&self) -> Option<SharedString> { None }
    fn primary_action(&self) -> ErrorAction;
    fn secondary_action(&self) -> Option<ErrorAction> { None }
    fn severity(&self) -> ErrorSeverity;
}
```

`String`, `&'static str` ve `anyhow::Error` için hazır uygulamalar bulunur; bu tipler doğrudan `show_error`'a geçirilir ve `Critical` önem düzeyiyle tek bir "Dismiss" eylemi olarak gösterilir. Daha zengin bir hata için özel hata tipine `WorkspaceError` uygulanması yeterlidir.

| API | Rolü |
|-----|-----|
| `ErrorSeverity` | `Critical`, `Error`, `Warning` düzeylerini ayırır. `auto_dismiss_delay()` her düzeye otomatik kapanma süresi verir: `Critical` için `None` (kullanıcı kapatana kadar kalır), `Error` için 20 saniye, `Warning` için 10 saniye. |
| `ErrorAction` | Hata bildirimindeki bir eylem düğmesini tanımlar (`label`, opsiyonel `icon`, `tooltip`, `handler`). `ErrorAction::new(label, action)` bir `Action` tetikler; `ErrorAction::dismiss()` yalnız bildirimi kapatan "Dismiss" düğmesi üretir; `ErrorAction::link(label, url)` sona `ArrowUpRight` ikonu koyup bağlantıyı tarayıcıda açar. `.with_icon(...)`, `.with_end_icon(...)`, `.with_tooltip(...)` ile zincirlenir. `tooltip` alanı eylem verisinde taşınır; `MessageNotification::from_workspace_error(...)` dönüşümü bu alanı şu an düğme çizimine bağlamaz. Eylem ipucu gerekiyorsa özel `MessageNotification` kurulumu veya ayrı bir bildirim görünümü kullanılır. |
| `ErrorActionHandler` | Düğmeye basılınca çalışacak davranış: `Action(Box<dyn Action>)` ilgili action'ı gönderir, `Dismiss` yalnız bildirimi kapatır. |
| `ActionIcon` | Eylem düğmesi ikonunu konumuyla taşır: `ActionIcon::start(name)` etiketin solunda, `ActionIcon::end(name)` sağındadır. |
| `PortalError` | Linux'ta dosya açma portalı başarısız olduğunda kullanılan hazır tiptir; birincil eylemi belge bağlantısıdır. `show_error(workspace_error::PortalError::new(mesaj), cx)` biçiminde gösterilir. |

`MessageNotification::from_workspace_error(error, cx)` aynı dönüşümü doğrudan bir bildirim görünümü olarak verir: içerik ikonunu `Warning`/`Error` rengine, eylem düğmesini `Outlined` biçemine kurar, birincil iletiyi kopyalanabilir yapar, bastırma düğmesini kapatır ve önem düzeyine göre otomatik kapanmayı bağlar. İkincil mesaj varsa onu birincil iletinin altına ikincil içerik olarak yerleştirir; `ErrorAction::tooltip` verisini ise düğme ipucu olarak çizmez.

**`MessageNotification` Kurucu Yüzeyi.** Standart mesaj bildirimi şu zincir metotlarıyla ayrıntılandırılır:

| Metot grubu | API |
|-----|-----|
| İçerik kurma | `MessageNotification::new(message, cx)`, `MessageNotification::new_from_builder(cx, content)` |
| Başlık ve gövde | `.with_title(title)`, `.content_icon(icon, color)`, `.secondary_content(text)`, `.copy_text(text)` |
| Birincil eylem | `.primary_message(message)`, `.primary_icon(icon)`, `.primary_end_icon(icon)`, `.primary_icon_color(color)`, `.primary_on_click(handler)`, `.primary_on_click_arc(handler)` |
| İkincil eylem | `.secondary_message(message)`, `.secondary_icon(icon)`, `.secondary_end_icon(icon)`, `.secondary_icon_color(color)`, `.secondary_on_click(handler)`, `.secondary_on_click_arc(handler)` |
| Ek bilgi | `.more_info_message(message)`, `.more_info_url(url)` |
| Görünürlük ve kapanış | `.button_style(style)`, `.show_close_button(show)`, `.show_suppress_button(show)`, `.dismiss(cx)`, `.from_workspace_error(error, cx)` |

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
| `simple_message_notification` | Hazır mesaj bildirim görünümünü barındıran alt modüldür. |
| `MessageNotification` | Birincil/ikincil mesaj, ikon, tıklama işleyicisi, kapatma/bastırma ve daha fazla bilgi bağlantısı alanlarını zincir metotlarıyla kurar. `content_icon(icon, color)` gövdenin soluna ikon, `secondary_content(text)` birincil iletinin altına açıklama, `copy_text(text)` başlığa kopyala düğmesi, `button_style(style)` eylem düğmelerine biçem, `primary_end_icon`/`secondary_end_icon` düğme ikonunu etiketin sağına ekler. `from_workspace_error(error, cx)` bir `WorkspaceError`'dan tam bildirim üretir. |
| `WorkspaceError` | Bir hatanın birincil/ikincil mesajını, eylemlerini ve önem düzeyini bildirime nasıl döktüğünü belirleyen trait'tir; `String`, `&'static str` ve `anyhow::Error` için hazır uygulaması vardır. |
| `ErrorAction`, `ErrorActionHandler`, `ActionIcon`, `ErrorSeverity`, `PortalError` | Hata bildirimi eylem düğmelerini, basınca çalışacak davranışı, düğme ikonu konumunu, önem düzeyine bağlı otomatik kapanmayı ve hazır portal hatasını taşır. |
| `NotificationId` | `unique`, `composite` ve `named` yardımcılarıyla bildirimlerin tekilleştirilmesini (deduplication) sağlayan kimlikler üretir. |
| `NotifyResultExt` | `Result` değerini workspace veya uygulama bildirimine çeviren genişletme trait'idir. |
| `NotifyTaskExt` | `Task<Result<_>>` sonucunu spawn edip olası hataları bildirim olarak gösterir. |
| `DetachAndPromptErr` | Asenkron sonucu prompt tabanlı kullanıcı hatasına çevirir; `prompt_err` beklenebilir yapıdayken, `detach_and_prompt_err` işlemi arka planda yürütür. |
| `show_app_notification` | Uygulama seviyesindeki bildirimi tüm `MultiWorkspace` çalışma alanlarına dağıtır ve yeni workspace'ler için global kayıt altında tutar. |
| `dismiss_app_notification` | Aynı id'li uygulama seviyesindeki bildirim kayıtlarını ve workspace üzerindeki kopyalarını kaldırır. |
| `SuppressEvent` | Bildirim görünümünden workspace'e "bu bildirimi bastır" kararını iletir. |

---

## Dikkat Edilmesi Gereken Hususlar

Bildirim yardımcıları kullanılırken gözden kaçırılmaması gereken noktalar şunlardır:

- `detach_and_log_err` fonksiyonu hatayı yalnızca günlüğe (log) kaydeder; kullanıcıya görünür bir hata gösterilmek isteniyorsa çalışma alanı bildirimleri veya prompt yardımcılarından birinin tercih edilmesi gerekir.
- `show_app_notification` aynı id ile birden fazla çalışma alanında gösterim yapabilir; bu nedenle id değerinin `NotificationId::named` veya `composite` ile bilinçli bir şekilde seçilmesi gerekir.
- `MessageNotification` tıklama işleyicileri `Window` ve bildirimin kendi `Context<Self>` bağlamını alır; çalışma alanının durumuna ihtiyaç duyuluyorsa zayıf çalışma alanı veya entity yakalanması ve bunların serbest bırakılmış olma ihtimalinin ele alınması gerekir.
