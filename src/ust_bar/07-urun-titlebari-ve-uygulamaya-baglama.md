# Ürün titlebar'ı ve uygulamaya bağlama

Platform kabuğu hazır hâle geldikten sonra sıra üst katmana gelir.
Ürünün kendi başlık içeriği, sidebar bilgisi, menüleri ve uygulama
shell'i bu hazır kabuğa bağlanır. Bu bölüm, "platform kabuğu artık
çalışıyor" noktasından "kullanıcının gördüğü tam başlık çubuğu"
noktasına geçişi anlatır.

## 15. Sidebar ve workspace etkileşimi

`PlatformTitleBar`, isteğe bağlı olarak bir `MultiWorkspace` zayıf
referansı alabilir. Bu referansın tek amacı vardır: başlık çubuğundaki
pencere kontrollerinin yan paneldeki sidebar ile görsel olarak
çakışmasını önlemek. Bu görev için yapılanlar şunlardır:

- Sol sidebar açıksa, sol taraftaki pencere kontrolleri gizlenir.
- Sağ sidebar açıksa, sağ taraftaki pencere kontrolleri gizlenir.
- CSD köşe yuvarlama, sidebar'ın temas ettiği tarafta kapatılır;
  böylece köşedeki gölge ve yuvarlama paneli kesip rahatsız edici bir
  görünüm vermez.

Zed'de bu bilgi `SidebarRenderState { open, side }` tipinde gelir.
Port hedefinde sol veya sağ panel varsa, aynı soyutlamanın daha küçük
bir tipe indirgenmesi yeterli olur:

```rust
#[derive(Default, Clone, Copy)]
struct ShellSidebarState {
    open: bool,
    side: SidebarSide,
}
```

Sidebar kavramının hiç bulunmadığı bir uygulamada bu alan tamamen
kaldırılabilir, veya alana her zaman default state döndüren bir
implementation verilebilir.

`PlatformTitleBar::is_multi_workspace_enabled(cx)` fonksiyonu, Zed'de
ilginç bir biçimde `DisableAiSettings` ayarı üzerinden değer üretir.
İsim ürün açısından kafa karıştırıcı görünse de davranış aslında bir
feature flag işlevi görür. Port hedefinde bu kontrolün
`AppSettings::multi_workspace` veya `ShellSettings::sidebar_enabled`
gibi doğrudan ve anlaşılır biçimde isimlendirilmiş bir ayarla
değiştirilmesi tavsiye edilir.

Zed'in ürün modelinde klasör ve proje açma davranışı şöyle çalışır:
varsayılan olarak yeni bir pencere açılmaz; klasör veya proje, mevcut
pencerenin threads sidebar'ına eklenir. `File > Open`, `File > Open
Recent`, klasör sürükleme ve komut satırında `zed ~/project` çağrısı
gibi yolların hepsi aynı pencere içinde workspace değişikliğine yol
açabilir. Yeni bir pencere açmak için Open Recent'ta Cmd/Ctrl+Enter
ya da CLI tarafında `zed -n` kullanılır. `cli_default_open_behavior`
varsayılan değeri `existing_window` olduğu sürece, CLI üzerinden
yapılan açılışlar da mevcut pencere/sidebar yolunu takip eder.

Bu davranış `PlatformTitleBar` render sözleşmesini değiştirmez. Zayıf
`MultiWorkspace` referansı, platform kabuğu için yalnızca tek bir işe
yarar: sidebar tarafındaki pencere kontrol çakışmasını çözmek. Buna
karşılık ürün titlebar'ı için kural farklıdır: aktif proje veya
workspace değişikliği, pencere değişmeden de gerçekleşebilir. Bu
yüzden proje adı, worktree bilgisi, sidebar tarafı ve başlık içeriği
`Window` lifecycle'ına bağlanmaz; aktif `MultiWorkspace::workspace()`
durumuna gözlemci yerleştirilerek güncellenir. Aksi halde proje
değişimi olduğu hâlde başlıkta eski isim görünmeye devam eder.

"Sidebar açık mı?" sorusu ile "açık proje var mı?" sorusu da birbirine
karıştırılmaz. Boş workspace'lerde yeni thread veya terminal oluşturma
işlemi no-op olabilir; ama buna rağmen sidebar'ın açık/kapalı durumu
ve sol/sağ konumu, titlebar kontrol çakışmasını çözmek için ayrı bir
render state olarak tutulur. Bu iki state aynı bayrak altında
birleştirilirse pencere kontrolleri yanlış durumda gizlenir.

## 16. Başlık çubuğuna içerik yerleştirme

`PlatformTitleBar` kendi başına yalnızca platform kabuğunu sağlar;
kullanıcının gördüğü gerçek başlık içeriği bu tipin sorumluluğunda
değildir. Zed'in gerçek ürün başlığı, `crates/title_bar/src/title_bar.rs`
dosyasındaki `TitleBar` tarafından üretilir. Bu üst katman, platform
kabuğuna child olarak şunları geçirir:

- Uygulama menüsü.
- Proje adı / recent projects popover.
- Git branch adı ve durum ikonu.
- Restricted mode göstergesi.
- Kullanıcı menüsü, sign-in butonu, plan chip, update bildirimi.
- Collab/screen share göstergeleri.
- Feature flag'e bağlı onboarding/announcement banner'ları.
- Update bildirimi tooltip'i (`Update to Version: ...` gibi).

Update tooltip'inin metin biçimi,
`crates/title_bar/src/update_version.rs:66-75` aralığındaki
`version_tooltip_message` fonksiyonunda oluşturulur. Sürüm semantik
ise `SemanticVersion::to_string()` çıktısı kullanılır; commit SHA
durumunda ise `AppCommitSha::full()` ile kısaltılmamış 40 karakterlik
hash döner. Önceki "`14d9a41…`" tarzı kısaltılmış gösterim
kaldırılmıştır. Tooltip metni her durumda `"Update to Version:"`
önekiyle başlar. Port hedefinde tooltip kabuğunu yazarken bu uzun
string'in tek satıra sığacağı varsayımı yapılmamalıdır;
`Tooltip::text` veya muadili bir mekanizmada genişlik sınırı düşünülür.
Aksi halde tooltip taşıp ekran kenarında okunmaz hâle gelebilir.

Port hedefinde aynı kalıbın kurulması tavsiye edilir: platform
titlebar yalnızca bir shell olarak tutulur; ürünün anlamlı
varlıklarının tamamı üst seviyede bir `AppTitleBar` veya
`ShellTitleBar` entity'sinde üretilir. Bu ayrımı korumadan platform
kabuğunun içine ürün varlıkları doldurulmaya başlandığında, daha
önceki bölümlerde anlatılan katman ayrımı çabuk bulanıklaşır.

Önerilen sorumluluk ayrımı şu şekildedir:

| Katman | Sorumluluk |
| :-- | :-- |
| `PlatformTitleBar` | Platform davranışı, drag alanı, pencere kontrolleri, native tabs. |
| `AppTitleBar` | Uygulama adı, aktif workspace/doküman, menüler, kullanıcı aksiyonları. |
| `AppShell` | Pencere layout'u, CSD sarmalı, titlebar + içerik kompozisyonu. |
| `AppState` | Workspace, doküman, user session, ayar ve lifecycle action'ları. |

Başlık çubuğu içeriğinde `justify_between` modifier'ı kullanıldığı
için child element'leri sol, orta ve sağ grup olarak vermek
pratiktir. Bu yaklaşım hem render kalıbına uyar hem de element
yerleşimini bakışta okunur kılar:

```rust
let children = [
    h_flex()
        .id("title-left")
        .gap_2()
        .child(app_menu)
        .child(project_picker)
        .into_any_element(),
    h_flex()
        .id("title-right")
        .gap_1()
        .child(sync_status)
        .child(user_menu)
        .into_any_element(),
];

self.platform_titlebar.update(cx, |title_bar, _| {
    title_bar.set_children(children);
});
```

Interaktif child element'lerde dikkat edilmesi gereken birkaç nokta
vardır:

- Butonların ve popover tetikleyicilerin tamamı, click ve mouse down
  propagation'ını durdurmalıdır. Bunlar drag yüzeyiyle aynı katmanda
  durduğu için propagation'ın engellenmemesi pencere sürüklemesini
  tetikler.
- Uzun metinler ya `truncate()` modifier'ı ile kısaltılır ya da
  sabit bir `max_w(...)` değeriyle sınırlandırılır. Aksi halde uzun
  proje ya da dosya adları başlık çubuğunu taşırır.
- Sağ tarafta platform pencere butonlarının bulunabileceği akılda
  tutulmalıdır. Ürün butonlarının sağ padding'i ve flex shrink
  davranışı bu olasılığa göre test edilir; aksi takdirde pencere
  butonlarıyla çakışma yaşanır.
- Fullscreen modunda native pencere kontrolleri değişebileceği için
  macOS ve Windows davranışları ayrı ayrı doğrulanır. Tek bir
  platformda iyi çalışan layout, diğer platformda fullscreen geçişinde
  bozulabilir.

## 17. Kendi uygulamaya dahil etme

### Doğrudan Zed crate'iyle kullanım

Zed'in workspace crate'leri, settings kayıtları ve tema altyapısı zaten
projede mevcutsa, entegrasyon iskeleti aşağıdaki gibidir. Bu yol, Zed'in
uygulama başlangıç kurulumuna oldukça yakın bir ortam bekler. Zed'den
bağımsız bir GPUI uygulamasında bu doğrudan kullanım pek pratik değildir;
o senaryoda port yaklaşımı daha uygun düşer.

```rust
use gpui::{App, Context, Entity, Render, Window, div};
use platform_title_bar::PlatformTitleBar;
use ui::prelude::*;

pub fn init(cx: &mut App) {
    PlatformTitleBar::init(cx);
}

pub struct AppShell {
    title_bar: Entity<PlatformTitleBar>,
}

impl AppShell {
    pub fn new(cx: &mut Context<Self>) -> Self {
        Self {
            title_bar: cx.new(|cx| PlatformTitleBar::new("app-title-bar", cx)),
        }
    }
}

impl Render for AppShell {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let title = div()
            .id("title")
            .text_sm()
            .child("My GPUI App")
            .into_any_element();

        self.title_bar.update(cx, |title_bar, _| {
            title_bar.set_children([title]);
        });

        v_flex()
            .size_full()
            .child(self.title_bar.clone())
            .child(div().id("content").flex_1())
    }
}
```

Bu örnekte `set_children` çağrısının `render` fonksiyonu içinde yer
aldığına dikkat edilmelidir. Bunun nedeni daha önceki bölümlerde
açıklandığı gibi, Zed kaynağında child listesinin render sırasında
`mem::take` ile tüketilmesidir. Entity oluşturulurken bir kez child
vermek yeterli olmaz; sonraki render'da içerik tamamen kaybolur.

### Bağımsız GPUI uygulamasına port

Zed dışında bir uygulamada doğrudan `platform_title_bar` crate'ine
bağımlanmak genellikle çok ağır gelir; pek çok ek crate'in de
sürüklenmesine yol açar. Port edilirken aşağıdaki tabloda gösterilen
değişimler yapılır:

| Zed bağımlılığı | Port karşılığı |
| :-- | :-- |
| `workspace::CloseWindow` | Uygulamanızın `CloseWindow`, `CloseDocument`, `CloseProject` veya `QuitRequested` action'ı. |
| `zed_actions::OpenRecent { create_new_window: true }` | Uygulamanızın `NewWindow` veya `OpenWorkspace` action'ı. |
| `WorkspaceSettings::use_system_window_tabs` | Uygulama ayarınızdaki native tab seçeneği. |
| `ItemSettings::{close_position, show_close_button}` | Sekme kapatma butonu konumu ve görünürlüğü için kendi ayar tipiniz. |
| `MultiWorkspace` ve `SidebarRenderState` | Sol/sağ panel açık mı bilgisini veren kendi shell state'iniz. |
| `DisableAiSettings` | Multi workspace veya sidebar davranışını açıp kapatan kendi feature flag'iniz. |
| `cx.theme().colors().title_bar_background` | Kendi tema sisteminizdeki titlebar token'ı. |

Pratik port sınırı şu şekilde özetlenebilir:

- `platform_title_bar.rs` dosyasının içinden Zed workspace
  bağımlılıkları temizlenir; bu dosya yalnızca platform sözleşmesini
  ve `TitleBarController` sözleşmesini bilmeli, hiçbir workspace
  tipiyle doğrudan ilgilenmemelidir.
- `system_window_tabs.rs` içindeki action ve settings kullanımları
  ürünün kendi action ve settings tipleriyle değiştirilir. Bu maliyetli
  görünüyorsa, ilk sürümde native tab desteği tamamen kapatılır ve
  sonradan açılır; çünkü buradaki bağımlılıklar diğer parçalara göre
  daha geniştir.
- `platforms/platform_linux.rs` ve `platforms/platform_windows.rs`
  dosyaları diğer parçalara göre daha taşınabilirdir. Çoğu uygulamada
  bu dosyalar yalnız küçük değişikliklerle çalışır; özellikle Windows
  caption davranışı çoğunlukla olduğu gibi kalır.

---

