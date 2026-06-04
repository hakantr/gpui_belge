# Ürün titlebar'ı ve uygulamaya bağlama

Platform kabuğu hazır hale geldikten sonra sıra üst katmana gelir. Ürünün kendi başlık içeriği, yan panel bilgisi, menüleri ve uygulama kabuğu bu kabuğa bağlanır. Bu bölüm, "platform kabuğu çalışıyor" noktasından "kullanıcının gördüğü tam başlık çubuğu hazır" noktasına geçişi anlatır.

![Ürün titlebar durum haritası](assets/product-titlebar-state.svg)

## 15. Yan panel ve Workspace etkileşimi

`PlatformTitleBar`, isteğe bağlı olarak bir `MultiWorkspace` zayıf referansı alabilir. Bu referansın tek amacı vardır: başlık çubuğundaki pencere kontrollerinin yan panel ile görsel olarak çakışmasını önlemek. Bu görev için yapılanlar şunlardır:

- Sol yan panel açıksa, sol taraftaki pencere kontrolleri gizlenir.
- Sağ yan panel açıksa, sağ taraftaki pencere kontrolleri gizlenir.
- CSD köşe yuvarlama, yan panelin temas ettiği tarafta kapatılır; böylece köşedeki gölge ve yuvarlama paneli kesip rahatsız edici bir görünüm vermez.

Zed'de bu bilgi `SidebarRenderState { open, side }` tipinde gelir. Port hedefinde sol veya sağ panel varsa, aynı soyutlamanın daha küçük bir tipe indirgenmesi yeterli olur:

```rust
#[derive(Default, Clone, Copy)]
struct KabukYanPanelDurumu {
    acik: bool,
    taraf: YanPanelTarafi,
}
```

Yan panel kavramının hiç bulunmadığı bir uygulamada bu alan tamamen kaldırılabilir. Alternatif olarak her zaman varsayılan durum döndüren bir implementasyon da verilebilir.

`PlatformTitleBar::is_multi_workspace_enabled(cx)` fonksiyonu Zed'de ilginç biçimde yalnız `DisableAiSettings` ayarı üzerinden değer üretir. İsim ürün açısından kafa karıştırıcıdır; davranış ise aslında bir özellik bayrağı gibi çalışır. Fakat pencere kontrollerinin gizlenmesinde kullanılan gerçek `SidebarRenderState`, `MultiWorkspace::sidebar_render_state(cx)` üzerinden gelir; burada `open` değeri `self.sidebar_open() && self.multi_workspace_enabled(cx)` şeklinde hesaplanır ve `MultiWorkspace::multi_workspace_enabled(cx)` hem `DisableAiSettings::disable_ai` hem de `AgentSettings::enabled` değerine bakar. Yani Zed'de ürün başlığı tarafındaki yardımcı ile yan panel durumunun tam kaynakları aynı değildir. Port hedefinde bu kontrolün `UygulamaAyarlari::coklu_calisma_alani` veya `KabukAyarlari::yan_panel_etkin` gibi doğrudan anlaşılır tek bir ayar ailesine bağlanması daha iyi olur.

Zed'in ürün modelinde klasör ve proje açma davranışı şöyle çalışır: varsayılan olarak yeni pencere açılmaz. Klasör veya proje, mevcut pencerenin thread yan paneline eklenir. `File > Open`, `File > Open Recent`, klasör sürükleme ve komut satırında `zed ~/proje` çağrısı gibi yolların hepsi aynı pencere içinde çalışma alanı değişikliğine yol açabilir. Yeni pencere açmak için Open Recent'ta Cmd/Ctrl+Enter ya da CLI tarafında `zed -n` kullanırsın. `cli_default_open_behavior` varsayılan olarak `existing_window` kaldığı sürece, CLI üzerinden yapılan açılışlar da mevcut pencere/yan panel yolunu takip eder.

`OpenMode::Activate` da `OpenMode::NewWindow` gibi pencereyi öne alır. Bu, üst bar için küçük ama önemli bir sözleşmedir: proje mevcut pencereye eklense bile "aktif proje değişti" olayı pasif bir durum değişimi gibi ele alınmaz. Port hedefinde proje/yan panel aktivasyonu yapıldığında titlebar başlığı, aktif worktree bilgisi ve pencere etkin/etkin olmayan renkleri aynı render turunda güncellenmelidir; `Activate` modunda pencere aktivasyonu atlanmaz.

Bu davranış `PlatformTitleBar` render sözleşmesini değiştirmez. Zayıf `MultiWorkspace` referansı platform kabuğu için yalnızca tek bir işe yarar: yan panel tarafındaki pencere kontrol çakışmasını çözmek. Ürün titlebar'ı için ise kural farklıdır. Aktif proje veya çalışma alanı, pencere değişmeden de değişebilir. Bu yüzden proje adı, worktree bilgisi, yan panel tarafı ve başlık içeriği `Window` yaşam döngüsüne bağlanmaz. Aktif `MultiWorkspace::workspace()` durumuna gözlemci yerleştirilerek güncellenir. Aksi halde proje değiştiği halde başlıkta güncel olmayan isim görünmeye devam eder.

"Yan panel açık mı?" sorusu ile "açık proje var mı?" sorusu birbirine karıştırılmaz. Boş çalışma alanlarında yeni thread veya terminal oluşturma işlemi iş yapmadan dönebilir (`no-op`). Buna rağmen yan panelin açık/kapalı durumu ve sol/sağ konumu, başlık çubuğu kontrol çakışmasını çözmek için ayrı bir render durumu olarak tutulur. Bu iki durum aynı bayrak altında birleştirilirse pencere kontrolleri yanlış durumda gizlenir.

## 16. Başlık çubuğuna içerik yerleştirme

`PlatformTitleBar` kendi başına yalnızca platform kabuğunu sağlar. Kullanıcının gördüğü gerçek başlık içeriği bu tipin sorumluluğunda değildir. Zed'in gerçek ürün başlığı `title_bar` crate'indeki `TitleBar` tarafından üretilir. Bu üst katman platform kabuğuna çocuk element olarak şunları geçirir:

- Uygulama menüsü.
- Proje adı / son projeler açılır paneli.
- Git dal adı ve durum ikonu.
- Kısıtlı mod göstergesi.
- Kullanıcı menüsü, oturum açma butonu, plan çipi, güncelleme bildirimi.
- İşbirliği/ekran paylaşımı göstergeleri.
- Özellik bayrağına bağlı ilk karşılama/duyuru bantları.
- Güncelleme bildirimi ipucu (`Sürüme Güncelle: ...` gibi).

Güncelleme ipucunun biçimi, `version_tooltip_message` fonksiyonunda oluşturulur. Sürüm semantik ise `SemanticVersion::to_string()` çıktısı kullanırsın. Commit SHA durumunda ise `AppCommitSha::full()` ile kısaltılmamış 40 karakterlik hash döner. Port hedefinde bu etiket `"Sürüme Güncelle:"` gibi Türkçe bir önekle yazılır; ayrıca uzun metnin tek satıra sığacağı varsayılmaz. `Tooltip::text` veya muadili bir mekanizmada genişlik sınırı düşünülür. Aksi halde ipucu taşıp ekran kenarında okunmaz hale gelebilir.

Güncelleme bildiriminin görsel kabuğu `ui` crate'indeki `UpdateButton` tipidir. `UpdateVersion::Render`, otomatik güncelleme durumuna göre beş kurucudan birini seçer: `checking`, `downloading`, `installing`, `updated`, `errored`. Bunlardan ilk üçü tıklamaya kapalıdır; kurucularında `disabled(true)` çağrılır ve render edilen düğme `disabled` bayrağına geçer. Port hedefinde karşılık gelen kullanıcı metinleri `"Zed güncellemeleri denetleniyor…"`, `"Güncelleme indiriliyor…"`, `"Güncelleme kuruluyor…"` gibi Türkçe yazılır.

Bu üç durumda butonun sınır rengi `colors().border` üzerinden gelir. `updated` ve `errored` durumlarında ise sınır `colors().text.opacity(0.15)` ile çizilir. İkonografi de aynı şekilde durum-koşullu seçilir: `Checking` ve `Installing` `IconName::LoadCircle` ile iki turluk bir dönüş animasyonu uygular, `Downloading` durağan `Download` ikonu kullanır, `errored` ise uyarı rengiyle `Warning` ikonunu gösterir ve kapatma tutamağı ekler. Port hedefindeki hata görünür metni `"Güncelleme Başarısız"` gibi Türkçe olmalıdır.

Port hedefinde aynı bileşen kurulurken bu beş durumun her biri ayrı bir kurucu olarak ifade edilmelidir. Böylece ürün başlık çubuğu otomatik güncelleme durum makinesinin dilini doğrudan yansıtır ve durum geçişi sırasında butonun yanlışlıkla tıklanabilir kalması engellenir.

Ürün başlık çubuğu, duyuru bandı gibi içerikleri `TitleBar` katmanında yönetir; platform kabuğu bunları bilmez. `OnboardingBanner` mekanizması crate'te hazırdır (kurucu + `visible_when` koşulu + kalıcı kapatma), ancak güncel sürümde `TitleBar`'ın `banner` alanı `None` bırakılır; yani başlıkta fiilen bir duyuru bandı çizilmez. Bu mekanizmanın doğru durumu ve nasıl kurulacağı [Üst Bar](../ust_bar/ust_bar.md) bölümünde anlatılır. Port hedefinde bir duyuru bileşeni gerekiyorsa yeri `UygulamaBaslikCubugu` katmanıdır; platform kabuğuna eklenmez.

Port hedefinde aynı kalıbın kurulması tavsiye edilir. Platform titlebar yalnızca bir kabuk olarak tutulur. Ürünün anlamlı varlıklarının tamamı üst seviyede bir `UygulamaBaslikCubugu` veya `KabukBaslikCubugu` entity nesnesinde üretilir. Bu ayrım korunmadan platform kabuğunun içine ürün varlıkları doldurulmaya başlanırsa, önceki bölümlerde anlatılan katman ayrımı hızla bulanıklaşır.

Önerilen sorumluluk ayrımı şu şekildedir:

| Katman | Sorumluluk |
| :-- | :-- |
| `PlatformTitleBar` | Platform davranışı, sürükleme alanı, pencere kontrolleri, native sekmeler. |
| `UygulamaBaslikCubugu` | Uygulama adı, aktif çalışma alanı/doküman, menüler, kullanıcı eylemleri. |
| `UygulamaKabugu` | Pencere yerleşimi, CSD sarmalı, titlebar + içerik kompozisyonu. |
| `UygulamaDurumu` | Çalışma alanı, doküman, kullanıcı oturumu, ayar ve yaşam döngüsü eylemleri. |

Başlık çubuğu içeriğinde `justify_between` değiştiricisi kullanıldığı için çocuk elementleri sol, orta ve sağ grup olarak vermek pratiktir. Bu yaklaşım hem render kalıbına uyar hem de element yerleşimini bir bakışta okunur kılar:

```rust
let cocuklar = [
    h_flex()
        .id("baslik-sol")
        .gap_2()
        .child(uygulama_menusu)
        .child(proje_secici)
        .into_any_element(),
    h_flex()
        .id("baslik-sag")
        .gap_1()
        .child(senkron_durumu)
        .child(kullanici_menusu)
        .into_any_element(),
];

self.platform_baslik_cubugu.update(cx, |baslik_cubugu, _| {
    baslik_cubugu.set_children(cocuklar);
});
```

Etkileşimli çocuk elementlerde dikkat edilmesi gereken birkaç nokta vardır:

- Butonların ve açılır panel tetikleyicilerin tamamı tıklama ve fare basma olay yayılımını durdurmalıdır. Bunlar sürükleme yüzeyiyle aynı katmanda durduğu için olay yayılımı engellenmezse pencere sürüklemesi tetiklenebilir.
- Uzun metinler ya `truncate()` değiştiricisi ile kısaltılır ya da sabit bir `max_w(...)` değeriyle sınırlandırılır. Aksi halde uzun proje ya da dosya adları başlık çubuğunu taşırır.
- Sağ tarafta platform pencere butonlarının bulunabileceği akılda tutulmalıdır. Ürün butonlarının sağ iç boşluğu ve flex daralma davranışı bu olasılığa göre test edilir. Aksi halde pencere butonlarıyla çakışma yaşanır.
- Tam ekran modunda native pencere kontrolleri değişebileceği için macOS ve Windows davranışları ayrı ayrı doğrulanır. Tek bir platformda iyi çalışan yerleşim, diğer platformda tam ekran geçişinde bozulabilir.

## 17. Kendi uygulamana dahil etme

### Doğrudan Zed crate'iyle kullanım

Zed'in `Workspace` crate'leri, settings kayıtları ve tema altyapısı projede zaten varsa entegrasyon iskeleti aşağıdaki gibidir. Bu yol, Zed'in uygulama başlangıç kurulumuna oldukça yakın bir ortam bekler. Zed'den bağımsız bir GPUI uygulamasında doğrudan kullanım pek pratik değildir; o senaryoda port yaklaşımı daha uygundur.

```rust
use gpui::{App, Context, Entity, Render, Window, div};
use platform_title_bar::PlatformTitleBar;
use ui::prelude::*;

pub fn baslat(cx: &mut App) {
    PlatformTitleBar::init(cx);
}

pub struct UygulamaKabugu {
    baslik_cubugu: Entity<PlatformTitleBar>,
}

impl UygulamaKabugu {
    pub fn new(cx: &mut Context<Self>) -> Self {
        Self {
            baslik_cubugu: cx.new(|cx| PlatformTitleBar::new("uygulama-baslik-cubugu", cx)),
        }
    }
}

impl Render for UygulamaKabugu {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let baslik = div()
            .id("baslik")
            .text_sm()
            .child("GPUI Uygulamam")
            .into_any_element();

        self.baslik_cubugu.update(cx, |baslik_cubugu, _| {
            baslik_cubugu.set_children([baslik]);
        });

        v_flex()
            .size_full()
            .child(self.baslik_cubugu.clone())
            .child(div().id("icerik").flex_1())
    }
}
```

Bu örnekte `set_children` çağrısının `render` fonksiyonu içinde yer aldığına dikkat et. Bunun nedeni daha önce anlatıldığı gibi, Zed kaynağında çocuk listesinin render sırasında `mem::take` ile tüketilmesidir. Entity oluşturulurken bir kez çocuk vermek yeterli olmaz; sonraki render geçişinde içerik tamamen kaybolur.

### Bağımsız GPUI uygulamasına port

Zed dışında bir uygulamada doğrudan `platform_title_bar` crate'ine bağımlanmak genellikle ağır gelir. Pek çok ek crate'in de projeye sürüklenmesine yol açar. Port edilirken aşağıdaki tabloda gösterilen değişimler yaparsın:

| Zed bağımlılığı | Port karşılığı |
| :-- | :-- |
| `workspace::CloseWindow` | Uygulamanın `PencereyiKapat`, `BelgeyiKapat`, `ProjeyiKapat` veya `CikisIstendi` eylemi. |
| `zed_actions::OpenRecent { create_new_window: true }` | Uygulamanın `YeniPencere` veya `CalismaAlaniniAc` eylemi. |
| `WorkspaceSettings::use_system_window_tabs` | Uygulama ayarındaki native sekme seçeneği. |
| `ItemSettings::{close_position, show_close_button}` | Sekme kapatma butonu konumu ve görünürlüğü için kendi ayar tipin. |
| `MultiWorkspace` ve `SidebarRenderState` | Sol/sağ panel açık mı bilgisini veren kendi kabuk durum tipin. |
| `DisableAiSettings` | Çoklu çalışma alanı veya yan panel davranışını açıp kapatan kendi özellik bayrağın. |
| `cx.theme().colors().title_bar_background` | Kendi tema sistemindeki titlebar token'ı. |

Pratik port sınırı şu şekilde özetlenebilir:

- `platform_title_bar.rs` dosyasının içinden Zed `Workspace` bağımlılıkları temizlenir; bu dosya yalnızca platform sözleşmesini ve `TitleBarController` sözleşmesini bilmeli, hiçbir `Workspace` tipiyle doğrudan ilgilenmemelidir.
- `system_window_tabs.rs` içindeki eylem ve settings kullanımları ürünün kendi eylem ve ayar tipleriyle değiştirilir. Bu maliyetli görünüyorsa native sekme desteği proje kararına göre kapalı başlatılır; ihtiyaç doğduğunda etkinleştirilir. Buradaki bağımlılıklar diğer parçalara göre daha geniştir.
- `platforms/platform_linux.rs` ve `platforms/platform_windows.rs` dosyaları diğer parçalara göre daha taşınabilirdir. Çoğu uygulamada bu dosyalar yalnız küçük değişikliklerle çalışır; özellikle Windows caption davranışı çoğunlukla olduğu gibi kalır.

---
