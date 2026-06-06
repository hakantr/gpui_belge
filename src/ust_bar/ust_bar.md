# Ürün Üst Barı

Bu rehber, Zed'in `title_bar` crate'ini, yani kullanıcıya görünen **ürün başlık çubuğunu** GPUI tabanlı bir uygulamaya lisans kurallarına uygun şekilde taşımak amacıyla hazırlanmıştır. `title_bar`, alttaki platform kabuğunu (`platform_title_bar`) re-export (yeniden dışa aktarım) ile dışa sunar ve onun üzerine Zed'e özgü ürün katmanını inşa eder: Uygulama menüsü, proje ve kullanıcı menüleri, Git dal göstergesi, işbirliği/ekran paylaşımı kontrolleri, abonelik planı göstergesi, güncelleme bildirimi ve ilk karşılama duyuru bandı.

> **Kapsam Ayrımı:** Pencere kabuğu, sürükleme alanı, Linux/Windows pencere kontrolleri ve yerel pencere sekmeleri gibi platforma özgü davranışlar bu bölümün konusu değildir; bu konular [Platform Üst Barı](../platform_ust_bar/platform_ust_bar.md) bölümünde ele alınmaktadır. Bu bölüm yalnızca `title_bar` crate'inin ürün arayüzü yüzeyini açıklar.

> **Bağımlılık Uyarısı:** `title_bar`, `platform_title_bar`'ın aksine `call`, `client` ve `remote` gibi Zed'in işbirliği ve hesap yığına doğrudan bağımlıdır. Bir geliştirici bu crate'i kendi uygulamasında doğrudan kullandığında bu yığını da projesine taşımış olur. Çoğu uygulama için doğru yaklaşım, `title_bar`'a doğrudan bağımlanmak yerine bu bölümdeki kalıpları kendi ürün başlık entity'sine **port etmektir (taşımaktır)**.

## Bu bölümün okuma sözleşmesi

Ürün başlık çubuğu, platform kabuğunun aksine "evrensel davranış paritesi" peşinde değildir. Buradaki parçaların çoğu (işbirliği, plan göstergeleri, güncelleme bildirimi) Zed'in kendi ürün kararlarıdır ve birebir taşınmaları beklenmez. Bu yüzden her bölümde önce **parçanın ne işe yaradığı**, sonra **`TitleBar` içinde nasıl kurulup render edildiği**, en sonda da **kendi uygulamanda karşılığının nasıl kurulacağı** açıklanır. Amaç kodu kopyalamak değil; Zed'in ürün başlığını hangi sözleşmelerle kurduğunu öğrenip aynı modeli kendi tasarımınla yeniden yazmaktır.

## Ürün yüzeyi (`title_bar` crate'i)

| API | Tür | Konu |
| :-- | :-- | :-- |
| `TitleBar` | struct | Ürün başlık çubuğunu birleştiren ana entity. |
| `title_bar::init` | fn | Platform kabuğunu hazırlar ve her `Workspace` için `TitleBar` kurar. |
| `ToggleProjectMenu`, `ToggleUserMenu`, `SwitchBranch` | eylem struct'ı | Proje menüsü, kullanıcı menüsü ve dal değiştirme eylemleri. |
| `collab::{toggle_mute, toggle_deafen, toggle_screen_sharing}` | fn | Aktif çağrıda mikrofon, dinleme ve ekran paylaşımı kontrolleri. |
| `SimulateUpdateAvailable` | eylem struct'ı | Güncelleme bildirimi yüzeyini test etmek için hata ayıklama eylemi. |
| `restore_banner` | fn | Kapatılmış ilk karşılama duyuru bandını yeniden görünür yapar. |
| Pencere sekmesi eylemleri | yeniden dışa aktarım | `platform_title_bar`'dan: `DraggedWindowTab`, `MergeAllWindows`, `MoveTabToNewWindow`, `ShowNextWindowTab`, `ShowPreviousWindowTab`. |

> **Not:** `ApplicationMenu`, `UpdateVersion`, `OnboardingBanner`, `PlanChip` ve `TitleBarSettings` tipleri Zed kaynağında **özel modüllerdedir**; crate dışına açılmazlar. `TitleBar` içinde çocuk entity veya yardımcı olarak kullanılırlar. Bu bölüm onları dış API olarak değil, davranışlarıyla ele alır.

## Bölümler

1. [Hedef, kapsam ve lisans](01-hedef-kapsam-ve-lisans.md)
2. [Kaynak haritası ve `platform_title_bar` köprüsü](02-kaynak-haritasi-ve-kopru.md)
3. [`TitleBar` entity'si, `init` ve iki render modu](03-titlebar-entity-ve-render.md)
4. [Ayarlar ve uygulama menüsü](04-ayarlar-ve-uygulama-menusu.md)
5. [Proje, dal, sunucu ve kısıtlı mod göstergeleri](05-proje-branch-host-restricted.md)
6. [İşbirliği ve ekran paylaşımı kontrolleri](06-collab-ve-ekran-paylasimi.md)
7. [Kullanıcı menüsü, oturum açma, plan çipi, güncelleme ve duyuru bandı](07-kullanici-update-banner.md)
8. [Pratik uygulama, port ve doğrulama](08-pratik-uygulama-ve-dogrulama.md)
