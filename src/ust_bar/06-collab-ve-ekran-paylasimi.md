# İşbirliği ve ekran paylaşimi kontrolleri

`collab` modülü, başlık çubuğunun en çok Zed'e özgü olan parçasıdır. Aktif bir çağrı/oda sırasında mikrofon, dinleme, ekran paylaşımı ve katılımcı listesini başlıkta yönetir. Bu modül crate dışına açık durumdadır (`pub mod collab`), ama sunduğu arayüz tamamen Zed'in işbirliği altyapısına (`call`, `client`, LiveKit odası) bağlıdır.

> **Port Uyarısı:** Bu bölümdeki davranış, kendi uygulamanda **büyük olasılıkla hiç bulunmaz**. Bir işbirliği/çağrı özelliğin yoksa bu arayüzü tamamen atlayabilirsin. Varsa bile, altyapın Zed'in `ActiveCall`/oda modelinden farklı olacağı için burada anlatılan kalıp doğrudan taşınmaz; yalnızca "Zed bu kontrolleri hangi sözleşmeyle başlığa koyuyor" perspektifiyle okunmalıdır.

## 1. Üç geçiş fonksiyonu

Modülün dışa açık çekirdeği üç fonksiyondur:

```rust
pub fn toggle_mute(cx: &mut App)
pub fn toggle_deafen(cx: &mut App)
pub fn toggle_screen_sharing(
    screen: anyhow::Result<Option<Rc<dyn ScreenCaptureSource>>>,
    window: &mut Window,
    cx: &mut App,
)
```

- **`toggle_mute`** — Uygulama geneli `ActiveCall` üzerinden aktif odayı bulur ve mikrofonu aç/kapat yapar. Mikrofonu kapatma, "ben konuşamam ama dinlerim" anlamına gelir.
- **`toggle_deafen`** — Aynı yoldan odanın dinlemeyi kapatma durumunu çevirir. Dinlemeyi kapatma, "kimseyi duymam" anlamına gelir; mikrofonu kapatmaktan farkı gelen sesi de kesmesidir.
- **`toggle_screen_sharing`** — Bir ekran/pencere kaynağı (`ScreenCaptureSource`) alır. Aktif oda yoksa erken döner. Verilen kaynak zaten paylaşılıyorsa paylaşımı durdurur; farklı bir kaynaksa öncekini durdurup yenisini başlatır. Paylaşım başlatma asenkron bir görevle yapılır ve hata durumunda kullanıcıya bilgi verilir.

Üçü de durumu doğrudan odaya yazar; değişiklik oda üzerinden tüm katılımcılara yayılır. Başlıktaki butonlar yalnızca bu fonksiyonları çağıran tetikleyicilerdir.

## 2. Katılımcı listesi

Aktif çağrıda başlık, projeye bağlı katılımcıları küçük avatarlarla gösterir. Her avatarın görünümü katılımcının durumunu yansıtır:

- Konuşan katılımcının avatarı vurgulu bir kenarlıkla çevrilir.
- Mikrofonu kapalı olan katılımcıda bir sessizlik göstergesi belirir.
- Projede fiziksel olarak bulunmayan katılımcı soluk, gri tonlu olarak çizilir.
- Bir katılımcıyı takip edenler, o avatarın etrafında bir avatar yığını olarak gösterilir; kalabalıksa "+N" etiketiyle özetlenir.

Uzak bir katılımcıya tıklamak takip etme/takibi bırakma davranışını çevirir. Bu liste, işbirliği oturumunun başlıktaki canlı özetidir.

## 3. Çağrı kontrol butonları

Çağrı sırasında sağ grupta bir dizi kontrol butonu çizilir. Hangilerinin görüneceği oda ve izin durumuna bağlıdır:

| Buton | Koşul | Davranış |
| :-- | :-- | :-- |
| Çağrıdan Ayrıl | Her zaman | Çağrıdan ayrılır (`ActiveCall` çağrı kapatma). |
| Bağlantı kalitesi | Her zaman | Sinyal ikonu + renk; ipucunda gecikme, jitter, paket kaybı ve girdi gecikmesi istatistikleri. |
| Projeyi Paylaş / Paylaşımı Durdur | Proje yerel, paylaşılabiliyor ve uzak bağlantı kuruluyor değilse | Projeyi paylaşır veya paylaşımı durdurur; bazı kanal kurallarında devre dışı olabilir. |
| Mikrofonu Kapat / Aç | Mikrofon kullanılabiliyorsa | `toggle_mute`; mikrofon kapalıyken seçili görünür. |
| Dinlemeyi Kapat / Aç | Her zaman | `toggle_deafen`; ipucu dinlemeyi kapatma ve mikrofonu açma ilişkisini açıklar. |
| Ekran paylaşımı | Mikrofon + ekran paylaşımı destekliyse | `toggle_screen_sharing`; platforma göre tek buton veya açılır menülü buton. |

## 4. Ekran paylaşımı: platform farkı

Ekran paylaşımı butonunun yapısı platforma göre değişir:

- **Wayland (Linux)** tarafında buton sadeleştirilir: Doğrudan paylaşımı başlatan/durduran tek bir buton kullanılır, kaynak seçim açılır paneli yoktur (Wayland'ın kendi portal tabanlı kaynak seçimi devreye gelir).
- **Diğer platformlarda** buton ikiye ayrılır: Ana buton varsayılan ekranı otomatik seçip paylaşımı başlatır; yanındaki açılır ok, sistemdeki tüm ekran/pencere kaynaklarını listeleyen bir açılır panel açar.

Açılır panel içindeki her kaynak; bir ikon, bir ad (örneğin `"HDMI-1"` veya port edilen arayüzde `"Pencere: …"`) ve çözünürlük etiketiyle çizilir. Şu an paylaşılan kaynak vurgulu renkle işaretlenir. Bir kaynağa tıklamak `toggle_screen_sharing` çağrısıyla paylaşımı o kaynağa geçirir.

## 5. `ActiveCall` ve oda entegrasyonu

Tüm bu arayüz, uygulama geneli `ActiveCall` entity'si üzerinden tek bir aktif odaya erişir. Mikrofon, dinlemeyi kapatma ve paylaşım durumları odadan okunur (`is_muted`, `is_deafened`, `is_sharing_screen` gibi) ve oda üzerinde değiştirilir. Katılımcılar, takip ilişkileri ve bağlantı istatistikleri de aynı odadan gelir. Kullanıcı kimliği ve avatarlar `UserStore`'dan, eş kimliği `Client`'tan beslenir.

`TitleBar`, aktif çağrı değiştiğinde yeniden render için `ActiveCall`'a abone olur; ayrıca çağrı sırasında bağlantı teşhisini ayrı bir abonelik ile izler. Böylece konuşma durumu, katılımcı girişi/çıkışı ve bağlantı kalitesi başlıkta canlı olarak güncellenir.

## 6. Port hedefi için

Bu modülün öğrettiği genel yaklaşım, kontrol mantığının küçük, durum-yazan fonksiyonlara (`toggle_mute` gibi) toplanması ve başlık butonlarının yalnızca bu fonksiyonları çağıran ince tetikleyiciler olmasıdır. Bu ayrım, aynı işlemin hem butondan hem klavye kısayolundan hem de menüden tetiklenebilmesini sağlar.

Ancak somut arayüz tamamen Zed'in çağrı altyapısına bağlıdır:

- `ActiveCall` ve oda kavramı Zed'in `call` crate'ine özgüdür; senin uygulamanda karşılığı muhtemelen tamamen farklı bir WebRTC/çağrı sağlayıcısıdır.
- Ekran yakalama (`ScreenCaptureSource`) platforma özel bir API'dir; kendi uygulamanda kendi yakalama yığını tercih edilir.
- Katılımcı listesi, takip ve kanal görünürlüğü Zed'in işbirliği ürün modelidir.

Bu yüzden bir işbirliği özelliği eklemiyorsan bu bölümün tamamı kapsam dışıdır. Eklesen bile, buradaki değer kodun kendisi değil; "Çağrı durumunu başlıkta hangi butonlarla, hangi koşullarla ve hangi görsel geri bildirimle özetlemeli?" sorusuna Zed'in verdiği cevaptır.

---
