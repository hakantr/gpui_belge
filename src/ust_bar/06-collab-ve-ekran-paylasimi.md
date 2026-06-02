# Collab ve ekran paylaşımı kontrolleri

`collab` modülü, başlık çubuğunun en Zed'e özgü parçasıdır. Aktif bir çağrı (call/room) sırasında mikrofon, dinleme, ekran paylaşımı ve katılımcı listesini başlıkta yönetir. Bu modül crate dışına açıktır (`pub mod collab`), ama anlattığı yüzey tamamen Zed'in işbirliği altyapısına (`call`, `client`, room/LiveKit) bağlıdır.

> **Port uyarısı baştan:** Bu bölümdeki davranış, kendi uygulamanda **büyük olasılıkla hiç bulunmaz**. Bir işbirliği/çağrı özelliğin yoksa bu yüzeyi tamamen atlarsın. Varsa bile, altyapın Zed'in `ActiveCall`/room modelinden farklı olacağı için burada anlatılan kalıp doğrudan taşınmaz; yalnızca "Zed bu kontrolleri hangi sözleşmeyle başlığa koyuyor" perspektifiyle okunur.

## 1. Üç toggle fonksiyonu

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

- **`toggle_mute`** — global `ActiveCall` üzerinden aktif room'u bulur ve mikrofonu aç/kapat yapar. Mute "ben konuşamam ama dinlerim" anlamına gelir.
- **`toggle_deafen`** — aynı yoldan room'un deafen state'ini çevirir. Deafen "kimseyi duymam" anlamına gelir; mute'tan farkı gelen sesi de kesmesidir.
- **`toggle_screen_sharing`** — bir ekran/pencere kaynağı (`ScreenCaptureSource`) alır. Aktif room yoksa erken döner. Verilen kaynak zaten paylaşılıyorsa paylaşımı durdurur; farklı bir kaynaksa öncekini durdurup yenisini başlatır. Paylaşım başlatma asenkron bir görevle yapılır ve hata durumunda kullanıcıya bilgi verilir.

Üçü de durumu doğrudan room'a yazar; değişiklik room üzerinden tüm katılımcılara yayılır. Başlıktaki butonlar yalnız bu fonksiyonları çağıran tetikleyicilerdir.

## 2. Katılımcı listesi

Aktif çağrıda başlık, projeye bağlı katılımcıları küçük avatarlarla gösterir. Her avatarın görünümü katılımcının durumunu yansıtır:

- Konuşan katılımcının avatarı vurgulu bir kenarlıkla çevrilir.
- Mute olan katılımcıda bir mute göstergesi belirir.
- Projede fiziksel olarak bulunmayan katılımcı soluk (grayscale) çizilir.
- Bir katılımcıyı takip edenler, o avatarın etrafında bir facepile olarak gösterilir; kalabalıksa "+N" etiketiyle özetlenir.

Uzak bir katılımcıya tıklamak takip etme (follow/unfollow) davranışını çevirir. Bu liste, işbirliği oturumunun başlıktaki canlı özetidir.

## 3. Çağrı kontrol butonları

Çağrı sırasında sağ grupta bir dizi kontrol butonu çizilir. Hangilerinin görüneceği room ve izin durumuna bağlıdır:

| Buton | Koşul | Davranış |
| :-- | :-- | :-- |
| Leave Call | her zaman | Çağrıdan ayrılır (`ActiveCall` hang-up). |
| Bağlantı kalitesi | her zaman | Sinyal ikonu + renk; tooltip'te gecikme/jitter/paket kaybı istatistikleri. |
| Share/Unshare Project | proje paylaşılabiliyor ve yerelse | Projeyi paylaşır veya paylaşımı durdurur; bazı kanal kurallarında devre dışı olabilir. |
| Mute (mikrofon) | mikrofon kullanılabiliyorsa | `toggle_mute`; mute durumunda seçili görünür. |
| Deafen (ses) | her zaman | `toggle_deafen`; tooltip deafen/unmute ilişkisini açıklar. |
| Ekran paylaşımı | mikrofon + ekran paylaşımı destekliyse | `toggle_screen_sharing`; platforma göre tek buton veya açılır menülü buton. |

## 4. Ekran paylaşımı: platform farkı

Ekran paylaşımı butonunun yapısı platforma göre değişir:

- **Wayland (Linux)** tarafında buton sadeleştirilir: doğrudan paylaşımı başlatan/durduran tek bir buton kullanılır, kaynak seçim popover'ı yoktur (Wayland'ın kendi portal tabanlı kaynak seçimi devreye girer).
- **Diğer platformlarda** buton ikiye ayrılır: ana buton varsayılan ekranı otomatik seçip paylaşımı başlatır; yanındaki açılır ok, sistemdeki tüm ekran/pencere kaynaklarını listeleyen bir popover açar.

Popover içindeki her kaynak; bir ikon, bir ad (örneğin "HDMI-1" veya "Window: …") ve çözünürlük etiketiyle çizilir. Şu an paylaşılan kaynak vurgulu renkle işaretlenir. Bir kaynağa tıklamak `toggle_screen_sharing` çağrısıyla paylaşımı o kaynağa geçirir.

## 5. `ActiveCall` ve room entegrasyonu

Tüm bu yüzey, global `ActiveCall` entity'si üzerinden tek bir aktif room'a erişir. Mikrofon, deafen ve paylaşım durumları room'dan okunur (`is_muted`, `is_deafened`, `is_sharing_screen` gibi) ve room üzerinde değiştirilir. Katılımcılar, takip ilişkileri ve bağlantı istatistikleri de aynı room'dan gelir. Kullanıcı kimliği ve avatarlar `UserStore`'dan, peer kimliği `Client`'tan beslenir.

`TitleBar`, aktif çağrı değiştiğinde yeniden render için `ActiveCall`'a abone olur; ayrıca çağrı sırasında bağlantı tanılamasını ayrı bir subscription ile izler. Böylece konuşma durumu, katılımcı girişi/çıkışı ve bağlantı kalitesi başlıkta canlı güncellenir.

## 6. Port hedefi için

Bu modülün öğrettiği genel ders, kontrol mantığının küçük, durum-yazan fonksiyonlara (`toggle_mute` gibi) toplanması ve başlık butonlarının yalnız bu fonksiyonları çağıran ince tetikleyiciler olmasıdır. Bu ayrım, aynı işlemin hem butondan hem klavye kısayolundan hem de menüden tetiklenebilmesini sağlar.

Ancak somut yüzey tamamen Zed'in çağrı altyapısına bağlıdır:

- `ActiveCall` ve room kavramı Zed'in `call` crate'ine özgüdür; senin uygulamanda karşılığı muhtemelen tamamen farklı bir WebRTC/çağrı sağlayıcısıdır.
- Ekran yakalama (`ScreenCaptureSource`) platforma özel bir API'dir; kendi uygulamanda kendi yakalama yığınını kullanırsın.
- Katılımcı listesi, takip (follow) ve kanal görünürlüğü Zed'in işbirliği ürün modelidir.

Bu yüzden bir işbirliği özelliği eklemiyorsan bu bölümün tamamı kapsam dışıdır. Eklesen bile, buradaki değer kodun kendisi değil; "çağrı durumunu başlıkta hangi butonlarla, hangi koşullarla ve hangi görsel geri bildirimle özetlemeli" sorusuna Zed'in verdiği cevaptır.
