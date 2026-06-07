# Hedef, kapsam ve lisans

Ürün başlık çubuğuna geçmeden önce neyin port edildiğinin, hangi sorumluluğun bu katmana ait olduğunun ve lisans sınırının nereden geçtiğinin netleştirilmesi gerekir. Platform Üst Barı bölümünde platform kabuğunun "davranış paritesi" peşinde olduğunu görmüştük. Ürün başlığı katmanı ise farklıdır: Burada Zed'in kendi ürün kararları devreye girer ve bu kararların birebir taşınması beklenmez.

## 1. Ürün başlığı katmanı nedir, ne değildir

Zed'in başlık çubuğu iki ayrı crate'in üst üste binmesinden oluşur:

- **`platform_title_bar`** — Pencere kabuğu. Sürükleme alanı, Linux/Windows pencere kontrolleri, macOS trafik ışığı boşluğu, yerel pencere sekmeleri. Bu katman [Platform Üst Barı](../platform_ust_bar/platform_ust_bar.md) bölümünde anlatılmaktadır.
- **`title_bar`** — Ürün başlığı. `platform_title_bar`'ı re-export (yeniden dışa aktarım) ile dışa aktarıp onun üstüne Zed'in kullanıcıya gösterdiği içeriği inşa eder: Proje adı ve menüsü, Git dal göstergesi, uygulama menüsü, kullanıcı menüsü, işbirliği kontrolleri, abonelik planı çipi, güncelleme bildirimi ve ilk karşılama duyuru bandı.

Bu ayrım rastgele değildir. Platform kabuğu "pencere nasıl davranır" sorusunu yanıtlar; ürün başlığı ise "kullanıcı başlıkta neyi görür ve neye tıklar" sorusunu yanıtlar. Birincisi her uygulamada aynı kalmalıdır; ikincisi her uygulamada tamamen farklıdır.

```text
┌──────────────────────────────────────────────────────────────┐
│  title_bar (ürün başlığı — Zed'e özgü)                        │
│  - TitleBar entity: tüm ürün parçalarını birleştirir          │
│  - Proje/dal/sunucu göstergeleri, uygulama menüsü             │
│  - Kullanıcı menüsü, oturum açma, plan çipi                   │
│  - İşbirliği kontrolleri, güncelleme bildirimi, duyuru bandı  │
│  - Görünürlük TitleBarSettings ile yönetilir                  │
├──────────────────────────────────────────────────────────────┤
│  platform_title_bar (platform kabuğu — genel)                 │
│  - PlatformTitleBar: TitleBar bunu çocuk olarak besler        │
│  - Sürükleme, pencere kontrolleri, yerel sekmeler             │
│  └──────────────────────────────────────────────────────────────┘
```

## 2. Neden ayrı bir crate

`title_bar` crate'i `platform_title_bar`'dan çok daha ağır bir bağımlılık grafiğine sahiptir. Çünkü ürün başlığı; aktif çağrıyı (`call`), oturum ve hesap bilgisini (`client`, `cloud_api_types`), proje ve git deposunu (`project`), otomatik güncellemeyi (`auto_update`) ve ürün ayarlarını (`settings`, `agent_settings`) bilmek zorundadır.

Bu bağımlılıklar, ürün başlığının neden ayrı tutulduğunu da açıklar: Platform kabuğu daha çok pencere kabuğu, tema, ayar ve workspace köprüsüne yaslanırken; ürün başlığı Zed'in hesap, çağrı, proje, uzak bağlantı, güncelleme ve bildirim yığınına dokunur. Bu yığını taşımadan ürün başlığını birebir kullanmak mümkün değildir. Bu yüzden bir geliştirici için doğru yaklaşım genellikle **kalıbı öğrenip kendi ürün başlığını yazmaktır**.

## 3. Üç port yaklaşımı

| Yaklaşım | Sonuç | Kullanım Koşulu |
| :-- | :-- | :-- |
| Doğrudan `title_bar` bağımlılığı | Tüm Zed işbirliği/hesap/güncelleme yığını projeye gelir; uygulama pratikte Zed ürün modeline bağlanmış olur | Zed ekosistemi içinde, GPL hedefiyle çalışılıyorsa |
| `TitleBar`'ı projeye dahil et | Aynı yığın yine gelir; bakım yükü geliştiriciye geçer | Nadiren mantıklıdır |
| Kalıbı kendi ürün başlığına yaz | Yalnızca ihtiyaç duyulan parçaların (proje adı, menü, kullanıcı) özel bir tasarımla kurulması mümkündür | **Lisans-temiz ve bağımsız hedef için doğru yol** |

Bu rehber üçüncü yolu anlatır. İşbirliği, plan çipi ve güncelleme gibi Zed'e özgü parçalar çoğu uygulamada hiç bulunmaz; bunların anlatımı "bu yüzeyin özel olarak kurulması tercih edildiğinde Zed nasıl kuruyor" perspektifiyle okunmalıdır.

## 4. Lisans

`title_bar` crate'i de `platform_title_bar` gibi **GPL-3.0-or-later** lisanslıdır. Kod gövdesi kopyalanamaz; ancak gözlemlenebilir davranış ve API imzalarının özgün kelimelerle yeniden kurulması mümkündür. Bu rehberdeki örneklerin tamamı bu kuralı izler: "Zed başlıkta proje adını şu sözleşmeyle gösteriyor" gözlemi yasak değildir; ama `title_bar` crate'indeki bir fonksiyonun gövdesini birebir taşımak ihlaldir.

Ürün başlığında lisans hassasiyeti pratikte daha düşüktür; çünkü ürün içeriği zaten özel bir tasarımla yeniden yazılır. Yine de proje/dal/menü gibi parçaları Zed'den birebir uyarlarken aynı GPL sınırını gözetmek gerekir.

## 5. Bu bölümün kapsamı

Bu bölüm `title_bar` crate'inin ürün yüzeyini kaynaktan doğrulanmış davranışıyla anlatır:

- `TitleBar` entity'sinin kuruluşu, `init` akışı ve iki render modu.
- `TitleBarSettings` ile görünürlük yönetimi ve uygulama menüsü (`ApplicationMenu`).
- Proje adı, Git dalı, uzak sunucu ve kısıtlı mod göstergeleri.
- İşbirliği (mikrofon, dinlemeyi kapatma, ekran paylaşımı, katılımcı listesi) kontrolleri.
- Kullanıcı menüsü, oturum açma, plan çipi, güncelleme bildirimi ve ilk karşılama duyuru bandı.
- Pratik port önerileri ve davranış doğrulama listesi.

Pencere kontrolleri, sürükleme ve yerel sekmeler bu bölümün dışındadır; onlar için [Platform Üst Barı](../platform_ust_bar/platform_ust_bar.md) bölümüne başvurulur.

---
