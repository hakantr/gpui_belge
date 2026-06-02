# Üst Bar

Bu rehber, Zed'in `title_bar` crate'ini, yani kullanıcıya görünen **ürün başlık çubuğunu** GPUI tabanlı bir uygulamaya lisans-temiz biçimde taşımak için hazırlanmıştır. `title_bar`, alttaki platform kabuğunu (`platform_title_bar`) `pub use` ile yeniden dışa aktarır ve onun üstüne Zed'e özgü ürün katmanını kurar: uygulama menüsü, proje ve kullanıcı menüleri, git branch göstergesi, collab/ekran paylaşımı kontrolleri, abonelik plan chip'i, güncelleme bildirimi ve onboarding banner'ı.

> **Kapsam ayrımı.** Pencere kabuğu, sürükleme alanı, Linux/Windows pencere kontrolleri ve native pencere sekmeleri gibi platforma özgü davranışlar bu bölümün konusu değildir; onlar [Platform Üst Barı](../platform_ust_bar/platform_ust_bar.md) bölümünde işlenir. Bu bölüm yalnız `title_bar` crate'inin ürün yüzeyini anlatır.

> **Bağımlılık uyarısı.** `title_bar`, `platform_title_bar`'ın aksine `call`, `client` ve `remote` gibi Zed'in işbirliği/hesap yığınına bağlıdır. Bir geliştirici bu crate'i kendi uygulamasında kullandığında bu yığını da projesine taşır. Çoğu uygulama için doğru yaklaşım, `title_bar`'a doğrudan bağımlanmak yerine bu bölümdeki kalıpları kendi ürün başlık entity'sine **port etmektir**.

## Bu bölümün okuma sözleşmesi

Ürün başlık çubuğu, platform kabuğunun aksine "evrensel davranış paritesi" peşinde değildir. Buradaki parçaların çoğu (collab, plan chip, güncelleme bildirimi) Zed'in ürün kararlarıdır ve birebir taşınmaları beklenmez. Bu yüzden her bölümde önce **parçanın ne işe yaradığı**, sonra **`TitleBar` içinde nasıl kurulup render edildiği**, en sonda da **kendi uygulamanda karşılığını nasıl kurarsın** anlatılır. Amaç kodu kopyalamak değil; Zed'in ürün başlığını hangi sözleşmelerle kurduğunu öğrenip aynı modeli kendi tasarımınla yeniden yazmandır.

## Ürün yüzeyi (`title_bar` crate'i)

| API | Tür | Konu |
| :-- | :-- | :-- |
| `TitleBar` | struct | Ürün başlık çubuğunu birleştiren ana entity. |
| `title_bar::init` | fn | Platform kabuğunu hazırlar ve her `Workspace` için `TitleBar` kurar. |
| `ToggleProjectMenu`, `ToggleUserMenu`, `SwitchBranch` | action struct | Proje menüsü, kullanıcı menüsü ve branch değiştirme aksiyonları. |
| `collab::{toggle_mute, toggle_deafen, toggle_screen_sharing}` | fn | Aktif çağrıda mikrofon, dinleme ve ekran paylaşımı kontrolleri. |
| `SimulateUpdateAvailable` | action struct | Güncelleme bildirimi yüzeyini test etmek için debug aksiyonu. |
| `restore_banner` | fn | Kapatılmış onboarding banner'ını yeniden görünür yapar. |
| Pencere sekmesi action'ları | reexport | `platform_title_bar`'tan: `DraggedWindowTab`, `MergeAllWindows`, `MoveTabToNewWindow`, `ShowNextWindowTab`, `ShowPreviousWindowTab`. |

> Not: `ApplicationMenu`, `UpdateVersion`, `OnboardingBanner`, `PlanChip` ve `TitleBarSettings` tipleri Zed kaynağında **private modüldedir**; crate dışına açılmazlar. `TitleBar` içinde child entity veya yardımcı olarak kullanılırlar. Bu bölüm onları dış API olarak değil, davranışlarıyla anlatır.

## Bölümler

1. [Hedef, kapsam ve lisans](01-hedef-kapsam-ve-lisans.md)
2. [Kaynak haritası ve `platform_title_bar` köprüsü](02-kaynak-haritasi-ve-kopru.md)
3. [`TitleBar` entity'si, `init` ve iki render modu](03-titlebar-entity-ve-render.md)
4. [Ayarlar ve uygulama menüsü](04-ayarlar-ve-uygulama-menusu.md)
5. [Proje, branch, host ve restricted mode göstergeleri](05-proje-branch-host-restricted.md)
6. [Collab ve ekran paylaşımı kontrolleri](06-collab-ve-ekran-paylasimi.md)
7. [Kullanıcı menüsü, sign-in, plan chip, güncelleme ve banner](07-kullanici-update-banner.md)
8. [Pratik uygulama, port ve doğrulama](08-pratik-uygulama-ve-dogrulama.md)
