# Hedef, kapsam ve lisans

Ürün başlık çubuğuna geçmeden önce neyin port edildiğini, hangi sorumluluğun bu katmana ait olduğunu ve lisans sınırının nereden geçtiğini netleştirmek gerekir. Platform Üst Barı bölümünde platform kabuğunun "davranış paritesi" peşinde olduğunu görmüştük. Ürün başlığı katmanı ise farklıdır: burada Zed'in kendi ürün kararları devreye girer ve bu kararların birebir taşınması beklenmez.

## 1. Ürün başlığı katmanı nedir, ne değildir

Zed'in başlık çubuğu iki ayrı crate'in üst üste binmesinden oluşur:

- **`platform_title_bar`** — pencere kabuğu. Sürükleme alanı, Linux/Windows pencere kontrolleri, macOS trafik ışığı boşluğu, native pencere sekmeleri. Bu katman [Platform Üst Barı](../platform_ust_bar/platform_ust_bar.md) bölümünde anlatılır.
- **`title_bar`** — ürün başlığı. `platform_title_bar`'ı `pub use` ile yeniden dışa aktarıp onun üstüne Zed'in kullanıcıya gösterdiği içeriği kurar: proje adı ve menüsü, git branch göstergesi, uygulama menüsü, kullanıcı menüsü, collab kontrolleri, abonelik plan chip'i, güncelleme bildirimi ve onboarding banner'ı.

Bu ayrım rastgele değildir. Platform kabuğu "pencere nasıl davranır" sorusunu yanıtlar; ürün başlığı ise "kullanıcı başlıkta neyi görür ve neye tıklar" sorusunu yanıtlar. Birincisi her uygulamada aynı kalmalıdır; ikincisi her uygulamada tamamen farklıdır.

```text
┌──────────────────────────────────────────────────────────────┐
│  title_bar (ürün başlığı — Zed'e özgü)                        │
│  - TitleBar entity: tüm ürün parçalarını birleştirir          │
│  - Proje/branch/host göstergeleri, uygulama menüsü            │
│  - Kullanıcı menüsü, sign-in, plan chip                       │
│  - Collab kontrolleri, güncelleme bildirimi, banner           │
│  - Görünürlük TitleBarSettings ile yönetilir                  │
├──────────────────────────────────────────────────────────────┤
│  platform_title_bar (platform kabuğu — genel)                 │
│  - PlatformTitleBar: TitleBar bunu child olarak besler        │
│  - Sürükleme, pencere kontrolleri, native sekmeler            │
└──────────────────────────────────────────────────────────────┘
```

## 2. Neden ayrı bir crate

`title_bar` crate'i `platform_title_bar`'dan çok daha ağır bir bağımlılık grafiğine sahiptir. Çünkü ürün başlığı; aktif çağrıyı (`call`), oturum ve hesap bilgisini (`client`, `cloud_api_types`), proje ve git deposunu (`project`), otomatik güncellemeyi (`auto_update`) ve özellik bayraklarını (`feature_flags`) bilmek zorundadır.

Bu bağımlılıklar, ürün başlığının neden ayrı tutulduğunu da açıklar: platform kabuğu yalnız `gpui`, `theme` ve `settings`'e yaslanırken; ürün başlığı Zed'in neredeyse tüm ürün yığınına dokunur. Bu yığını taşımadan ürün başlığını birebir kullanmak mümkün değildir. Bu yüzden bir geliştirici için doğru yaklaşım genellikle **kalıbı öğrenip kendi ürün başlığını yazmaktır**.

## 3. Üç port yaklaşımı

| Yaklaşım | Sonuç | Kullanım koşulu |
| :-- | :-- | :-- |
| Doğrudan `title_bar` dependency | Tüm Zed collab/hesap/güncelleme yığını projeye gelir; uygulaman pratikte Zed ürün modeline bağlanır | Zed ekosistemi içinde, GPL hedefiyle çalışıyorsan |
| `TitleBar`'ı vendor'la | Aynı yığın yine gelir; bakım yükü sende | Nadiren mantıklıdır |
| Kalıbı kendi ürün başlığına yaz | Yalnız ihtiyacın olan parçaları (proje adı, menü, kullanıcı) kendi tasarımınla kurarsın | **Lisans-temiz ve bağımsız hedef için doğru yol** |

Bu rehber üçüncü yolu anlatır. Collab, plan chip ve güncelleme gibi Zed'e özgü parçalar çoğu uygulamada hiç bulunmaz; bunların anlatımı "bu yüzeyi kendin kurmak istersen Zed nasıl kuruyor" perspektifiyle okunur.

## 4. Lisans

`title_bar` crate'i de `platform_title_bar` gibi **GPL-3.0-or-later** lisanslıdır. Kod gövdesi kopyalanamaz; ancak gözlemlenebilir davranış ve API imzaları kendi kelimelerinle yeniden kurulabilir. Bu rehberdeki örneklerin tamamı bu kuralı izler: "Zed başlıkta proje adını şu sözleşmeyle gösteriyor" gözlemi yasak değildir; ama `title_bar` crate'indeki bir fonksiyonun gövdesini birebir taşımak ihlaldir.

Ürün başlığında lisans hassasiyeti pratikte daha düşüktür, çünkü ürün içeriğini zaten kendi tasarımınla yeniden yazarsın. Yine de proje/branch/menü gibi parçaları Zed'den birebir uyarlarken aynı GPL sınırını gözetmek gerekir.

## 5. Bu bölümün kapsamı

Bu bölüm `title_bar` crate'inin ürün yüzeyini kaynaktan doğrulanmış davranışıyla anlatır:

- `TitleBar` entity'sinin kuruluşu, `init` akışı ve iki render modu.
- `TitleBarSettings` ile görünürlük yönetimi ve uygulama menüsü (`ApplicationMenu`).
- Proje adı, git branch, uzak host ve restricted mode göstergeleri.
- Collab (mikrofon, deafen, ekran paylaşımı, katılımcı listesi) kontrolleri.
- Kullanıcı menüsü, sign-in, plan chip, güncelleme bildirimi ve onboarding banner.
- Pratik port önerileri ve davranış doğrulama listesi.

Pencere kontrolleri, sürükleme ve native sekmeler bu bölümün dışındadır; onlar için Platform Üst Barı bölümüne bakılır.
