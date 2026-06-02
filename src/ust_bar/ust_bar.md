# Üst Bar

Bu rehber, Zed'in `title_bar` crate'ini, yani kullanıcıya görünen **ürün başlık çubuğunu** GPUI tabanlı bir uygulamaya lisans-temiz biçimde taşımak için hazırlanmıştır. `title_bar`, alttaki platform kabuğunu (`platform_title_bar`) `pub use` ile yeniden dışa aktarır ve onun üstüne Zed'e özgü ürün katmanını kurar: uygulama menüsü, proje ve kullanıcı menüleri, git branch göstergesi, collab/ekran paylaşımı kontrolleri, abonelik plan chip'i, güncelleme bildirimi ve onboarding banner'ı.

> **Kapsam ayrımı.** Pencere kabuğu, sürükleme alanı, Linux/Windows pencere kontrolleri ve native pencere sekmeleri gibi platforma özgü davranışlar bu bölümün konusu değildir; onlar [Platform Üst Barı](../platform_ust_bar/platform_ust_bar.md) bölümünde işlenir. Bu bölüm yalnız `title_bar` crate'inin ürün yüzeyini anlatır.

> **Bağımlılık uyarısı.** `title_bar`, `platform_title_bar`'ın aksine `call`, `client` ve `remote` gibi Zed'in işbirliği/hesap yığınına bağlıdır. Bir geliştirici bu crate'i kendi uygulamasında kullandığında bu yığını da projesine taşır. Çoğu uygulama için doğru yaklaşım, `title_bar`'a doğrudan bağımlanmak yerine bu bölümdeki kalıpları kendi ürün başlık entity'sine **port etmektir**.

## Ürün yüzeyi (`title_bar` crate'i)

| API | Tür | Konu |
| :-- | :-- | :-- |
| `TitleBar` | struct | Ürün başlık çubuğunu birleştiren ana entity. |
| `title_bar::init` | fn | Crate kurulum çağrısı. |
| `ToggleProjectMenu`, `ToggleUserMenu`, `SwitchBranch` | action struct | Menü ve branch aksiyonları. |
| `collab::{toggle_mute, toggle_deafen, toggle_screen_sharing}` | fn | Çağrı/oda kontrolleri. |
| `SimulateUpdateAvailable` | action struct | Güncelleme bildirimi testi. |
| `restore_banner` | fn | Onboarding banner'ı geri getirme. |
| Pencere sekmesi action'ları | reexport | `platform_title_bar`'tan: `DraggedWindowTab`, `MergeAllWindows`, `MoveTabToNewWindow`, `ShowNextWindowTab`, `ShowPreviousWindowTab`. |

> Not: `application_menu` ve `update_version` Zed kaynağında **private modüldür** (`mod application_menu;`); `ApplicationMenu` ve `UpdateVersion` tipleri crate dışına açılmaz. Bunlar `TitleBar` içinde child entity olarak kullanılır ve bu bölümde davranışlarıyla anlatılır, dış API olarak değil.

## Bölümler

> Bu bölümün ayrıntılı konu sayfaları, faz planındaki **Üst Bar (title_bar ürün katmanı) içerik üretimi** fazında kaynaktan doğrulanarak yazılacaktır. Planlanan başlıklar:

1. Hedef, kapsam ve lisans
2. Kaynak haritası ve `platform_title_bar` köprüsü
3. `TitleBar` entity'si: kuruluş, `init` ve render iskeleti
4. Uygulama menüsü ve proje/kullanıcı menüleri
5. Git branch, proje host ve restricted mode göstergeleri
6. Collab ve ekran paylaşımı kontrolleri
7. Plan chip, kullanıcı menüsü ve sign-in
8. Güncelleme bildirimi ve onboarding banner
9. Pratik uygulama ve port
10. Referans ve doğrulama
