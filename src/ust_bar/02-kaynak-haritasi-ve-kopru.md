# Kaynak haritası ve `platform_title_bar` köprüsü

Bu bölüm `title_bar` crate'inin parçalarını bir haritada toplar ve en kritik soruyu yanıtlar: ürün başlığı, alttaki platform kabuğuna tam olarak nasıl bağlanır? Bu köprü doğru anlaşılmadan ürün parçalarının nereye oturduğu havada kalır.

## 1. Ürün katmanının parça haritası

| Parça | Rol |
| :-- | :-- |
| `TitleBar` | Ürün başlığının ana entity'si. Tüm parçaları birleştirir ve her render geçişinde `PlatformTitleBar`'ı besler. |
| `ApplicationMenu` | İstemci tarafı uygulama menüsü (Dosya, Düzen, Görünüm…). Yalnız platform menüsü kullanılmadığında çizilir. |
| `collab` modülü | Aktif çağrı sırasındaki mikrofon, dinlemeyi kapatma, ekran paylaşımı ve katılımcı listesi yüzeyi. |
| `UpdateVersion` | Boştaki durum dışında otomatik güncelleme durumunu (`checking`, `downloading`, `installing`, `updated`, `errored`) gösteren entity. |
| `OnboardingBanner` | Özellik bayrağına bağlanabilen duyuru bandı altyapısı. Kaynak modül yorumu Skills duyurusunu anar; güncel `TitleBar::new` ise `banner = None` ile başlar. |
| `PlanChip` | Kullanıcının abonelik planını gösteren küçük etiket. |
| `TitleBarSettings` | Başlık çubuğunun hangi parçalarının görüneceğini belirleyen ayar tipi. |

Bu parçalardan yalnız `TitleBar`, `collab` modülü ve birkaç eylem (`ToggleUserMenu`, `ToggleProjectMenu`, `SwitchBranch`, `SimulateUpdateAvailable`, `UseClassicLayout`, `UseAgenticLayout`) ile `restore_banner` crate dışına açıktır. `ApplicationMenu`, `UpdateVersion`, `OnboardingBanner`, `PlanChip` ve `TitleBarSettings` özel modüllerde kalır; `TitleBar` bunları kendi içinde çocuk entity veya yardımcı olarak kullanır.

## 2. `platform_title_bar` köprüsü

`title_bar` crate'i, platform kabuğunu kendi kök yüzeyinden yeniden dışa aktarır. Böylece Zed içindeki tüketiciler hem platform sekmesi eylemlerini hem de `PlatformTitleBar` tipini `title_bar` üzerinden de alabilir:

```rust
pub use platform_title_bar::{
    self, DraggedWindowTab, MergeAllWindows, MoveTabToNewWindow, PlatformTitleBar,
    ShowNextWindowTab, ShowPreviousWindowTab,
};
```

Bu çift yüzey, iki katmanın bağımlılık yönünü de gösterir: `title_bar`, `platform_title_bar`'a bağımlıdır; tersi asla doğru değildir. Ürün başlığı platform kabuğunu kullanır, platform kabuğu ürün başlığını tanımaz.

## 3. Bağlanma modeli: `TitleBar` `PlatformTitleBar`'ı sahiplenir

Köprünün özü `TitleBar` struct'ının ilk alanındadır:

```rust
pub struct TitleBar {
    platform_titlebar: Entity<PlatformTitleBar>,
    // ... ürün alanları
}
```

`TitleBar`, `PlatformTitleBar` entity'sini **güçlü** olarak sahiplenir. Her render geçişinde önce ürün çocuklarını hazırlar, sonra bunları platform kabuğuna teslim eder. Teslim iki çağrıyla olur:

- `set_button_layout(...)` ile Linux/FreeBSD pencere butonu yerleşimini iletir (ayardan gelen değer).
- `set_children(...)` ile başlıkta görünecek ürün elementlerini iletir.

Bu noktada Platform Üst Barı bölümünde anlatılan kural devreye girer: `PlatformTitleBar`, kendisine verilen çocukları render sırasında tüketir. Bu yüzden `TitleBar`, çocuk listesini her render geçişinde yeniden kurar ve yeniden teslim eder. Bir defalık teslim yeterli olmaz.

## 4. İki katmanın sorumluluk sınırı

Köprüyü doğru kurmanın anahtarı, hangi kararın hangi katmana ait olduğunu karıştırmamaktır:

| Karar | Sahibi |
| :-- | :-- |
| Pencere sürükleniyor mu, butonlar nerede, yerel sekme açık mı? | `PlatformTitleBar` |
| Başlıkta proje adı, dal, kullanıcı menüsü görünüyor mu? | `TitleBar` |
| Menüler ayrı bir satıra mı taşınıyor? | `TitleBar` (ayara ve platforma göre) |
| Pencere arka plan rengi (aktif/pasif)? | `PlatformTitleBar` (tema token'ı) |
| Hangi ürün parçası gizli, hangisi açık? | `TitleBar` (`TitleBarSettings`) |

Port hedefinde bu sınır korunduğunda, platform kabuğunu hiç değiştirmeden ürün başlığını tamamen yeniden tasarlayabilirsin. Sınır bulanıklaşırsa — örneğin proje adı mantığı platform kabuğuna sızarsa — kabuk tek bir uygulamaya kilitlenir ve yeniden kullanılamaz hale gelir.

## 5. Port hedefi için köprü kalıbı

Kendi uygulamanda aynı köprüyü kurarken iki entity tutarsın: platform kabuğunu temsil eden `PlatformTitleBar` (veya port karşılığın) ve onu besleyen ürün başlığı entity'si. Ürün entity'si, her render geçişinde kendi çocuk grubunu hazırlar ve platform kabuğuna teslim eder:

```rust
struct UrunBasligi {
    platform_kabugu: Entity<PlatformTitleBar>,
    // proje, kullanıcı, ayar gibi ürün durumları
}

impl Render for UrunBasligi {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let sol_grup = self.sol_grubu_kur(cx);
        let sag_grup = self.sag_grubu_kur(cx);

        self.platform_kabugu.update(cx, |kabuk, _| {
            kabuk.set_children([sol_grup, sag_grup]);
        });

        self.platform_kabugu.clone()
    }
}
```

Bu iskelet, Zed'in `TitleBar` render'ının çekirdeğiyle aynı sözleşmeyi taşır. Sonraki bölümlerde bu çekirdeğin içine ürün parçalarını tek tek yerleştireceğiz.
