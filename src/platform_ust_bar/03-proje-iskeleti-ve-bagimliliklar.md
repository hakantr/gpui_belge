# Proje iskeleti ve bağımlılıklar

Kaynak haritası netleştikten sonra sıra ürün tarafındaki yapıya gelir. Hangi crate'ler oluşturulacak, hangi klasör hangi sorumluluğu taşıyacak ve bağımlılık grafiği hangi yönde akacak? Bu bölüm, söz konusu sorulara cevap sunmaktadır. Amaç, ileride açılan bir dosyanın hangi katmana ait olduğunun hızlıca anlaşılmasıdır. Aynı zamanda lisans sınırının bu iskelet üzerinde nereye düştüğü de görünür hale gelir.

## 7. Crate yapısı ve klasör yerleşimi

Platform titlebar tek crate olarak değil, **iki ayrı crate** olarak konumlanır. Bu ayrım yapay değildir. Tema sistemindeki `kvs_tema` + `kvs_syntax_tema` bölünmesinde kullanılan mantık burada da geçerlidir.

| Crate | Sorumluluk | Lisans |
| ------- | ----------- | -------- |
| `kvs_titlebar` | `PlatformTitleBar`, platforma özgü buton tipleri, native sekmeler, `WindowControlArea` mirror'ları, port-özgü `TitleBarController` trait'i (Zed'de karşılığı yoktur) | Uygulama Lisansı |
| `kvs_app_titlebar` | Ürün başlık içeriği (menü, proje adı, kullanıcı UI, durum çipleri) | Uygulama Lisansı |

> **Crate Adlandırma:** Bu rehberde kullanılan `kvs_*` öneki yalnızca örnektir. Pratikte bunun yerine `uygulama_titlebar`, `cekirdek_titlebar` ya da projeye uygun başka bir ad seçilebilir. Rehberdeki kalıplar, isimden bağımsız olarak aynı şekilde uygulanmalıdır.

### Neden iki crate?

**Bağımsız test edilebilme ve evrim:**

- `kvs_titlebar` yalnızca platform kabuğunu içerir. Zed'in `platform_title_bar` crate'iyle senkronize edilirken değişiklik alan ana crate burası olur. Ürün crate'i bu süreçten doğrudan etkilenmez.
- `kvs_app_titlebar` ürünün başlık içeriğini taşır. Bu içerik uygulamanın UI tasarım kararlarına bağlıdır; Zed'in platform titlebar evrimiyle birebir aynı hızda değişmek zorunda değildir.
- İki crate ayrımı **derleme süresini** ve **bağımlılık grafiğini** okunur tutar. Platform kabuğu ağırlıklı olarak `gpui`'ye yaslanır; ürün başlığı ise tema, menü ve ürün durumuyla konuşur. Bu ayrım karışıklığı azaltır.

**Lisans izolasyonu:**

- `kvs_titlebar`, Zed'in `platform_title_bar` davranışını mirror eder. Belge yorumu yazımı ve fonksiyon gövdesi gibi konularda lisans hassasiyeti en çok bu crate'te hissedilir.
- `kvs_app_titlebar` ise ürünün kendi tasarım dilinde yaşar. Bu crate'e Zed ürün davranışından parça taşınmaz. Böylece olası bir lisans tartışmasında temas yüzeyi dar kalır.

### Klasör yerleşimi

```text
~/github/
├── gpui_belge/                       ← rehber + aktarım günlüğü + kayma betiği
│   ├── platform_title_bar_rehberi.md
│   ├── platform_title_bar_aktarimi.md
│   └── platform_title_bar_kaymasi_kontrol.sh
├── zed/                              ← referans kaynak
└── kvs_ui/                           ← uygulama klasörü
    ├── Cargo.toml                    ← workspace
    └── crates/
        ├── kvs_titlebar/
        │   ├── Cargo.toml
        │   ├── DECISIONS.md          ← Zed'den farklılıkların kaydı
        │   ├── src/
        │   │   ├── kvs_titlebar.rs       ← lib kökü (mod.rs değil)
        │   │   ├── platform_title_bar.rs ← PlatformTitleBar entity
        │   │   ├── platforms/
        │   │   │   ├── platform_linux.rs    ← LinuxWindowControls + WindowControlStyle
        │   │   │   └── platform_windows.rs  ← WindowsWindowControls
        │   │   │       (macOS için ayrı dosya yoktur; davranış ana render
        │   │   │        gövdesinde PlatformStyle::Mac dallarında satır içidir)
        │   │   ├── system_window_tabs.rs ← native pencere sekmeleri
        │   │   ├── controller.rs         ← port-özgü TitleBarController trait'i (Zed'de yok)
        │   │   └── style.rs              ← port-özgü WindowControlStyle sarmalı (Zed'de yok)
        │   └── tests/
        │       ├── controller_mock.rs    ← Sahte TitleBarController
        │       └── render_smoke.rs       ← Headless render duman testleri
        ├── kvs_app_titlebar/
        │   ├── Cargo.toml
        │   ├── src/
        │   │   ├── kvs_app_titlebar.rs   ← lib kökü
        │   │   ├── app_title_bar.rs      ← AppTitleBar entity (Zed'in TitleBar'ı muadili)
        │   │   ├── menu.rs               ← uygulama menüsü
        │   │   ├── project_picker.rs     ← proje/doküman adı bileşeni
        │   │   └── user_menu.rs          ← kullanıcı menüsü (opsiyonel)
        │   └── tests/
        └── kvs_tema/                ← tema rehberinden
            └── ...
```

### Modül adlandırma kuralı

Lib kökü olarak `mod.rs` değil, **crate ile aynı isimli dosya** seçilir (örn. `kvs_titlebar.rs`). Bunun pratik bir nedeni vardır: Editörde birden fazla "mod.rs" sekmesi açıldığında hangi crate'in köküne bakıldığını anlamak zorlaşır. Crate aduyla açılan dosyalar ise sekme başlığından bile ayırt edilebilir. Bu aynı zamanda Zed projesinin kendi konvansiyonudur. Tema rehberi ilgili bölüm ile de örtüşür.

### `DECISIONS.md`

Her crate kendi içinde bir karar günlüğü tutar. Zed'den farklı yapılan tüm seçimler, küçük görünse bile, gerekçesiyle birlikte bu dosyaya yazılır. Aşağıda örnek bir ilk giriş yer alır:

```markdown
# kvs_titlebar karar günlüğü

## YYYY-MM-DD — İlk pin

- Pin: <Zed kısa SHA> (bkz. ../../gpui_belge/platform_title_bar_aktarimi.md)
- Crate yapısı: kvs_titlebar (platform kabuğu) + kvs_app_titlebar (ürün başlığı)
- TitleBarController trait: uygulama eylemi / yan panel / buton yerleşimi
  sorularını trait üzerinden alır (Zed'in workspace doğrudan referansı
  yerine)
- SystemWindowTabs: ilk sürümde **kapalı** (özellik bayrağı varsayılan kapalı);
  uygulama native tab desteğine ihtiyaç doğunca açılacak
- macOS double-click davranışı: sistem varsayılanına teslim edilir; ayar
  geçersiz kılması yapılmaz (gerekirse ilgili bölüme göre eklenir)
- Linux CSD: WindowDecorations::Client desteklenir; CSD sarmalı
  (client_side_decorations muadili) ayrı bir yardımcı olarak yazılır
```

`DECISIONS.md` dosyası her Zed güncellemesinde ve her mimari karar sonrasında **güncellenir**. Bu disiplin ilk bakışta zahmetli görünebilir. Fakat aradan altı ay geçtiğinde "biz bu kararı neden almıştık?" sorusunun cevabı bu günlükte duruyorsa ciddi zaman kazandırır.

### Modüllerin sorumluluk haritası

| Modül | İçerir | Dış API mı? |
| ------- | -------- | ------------- |
| `kvs_titlebar.rs` (lib kökü) | Yeniden dışa açılanlar, `PlatformTitleBar`, `TitleBarController` | Evet |
| `platform_title_bar.rs` | `PlatformTitleBar`, render fonksiyonları, `render_left_window_controls`, `render_right_window_controls` | Evet |
| `platforms/platform_linux.rs` | `LinuxWindowControls`, `WindowControl`, `WindowControlStyle` | Evet (kararsız) |
| `platforms/platform_windows.rs` | `WindowsWindowControls` | Evet (kararsız) |
| (macOS — ayrı dosya yok) | Zed'de macOS davranışı ayrı dosyada değildir; ana `render` gövdesinde `PlatformStyle::Mac` dallarında satır içidir | — |
| `system_window_tabs.rs` | `SystemWindowTabs`, `DraggedWindowTab`, native tab davranışı (`gpui::SystemWindowTabController` burada tanımlanmaz, yalnızca kullanılır) | Evet (kararsız) |
| `controller.rs` (port-özgü; Zed'de yok) | `TitleBarController` trait'i ve ilgili veri tipleri; Zed'deki gerçek karşılık sidebar durumu için `workspace::SidebarRenderState` / `SidebarSide`'dır | Evet |
| `style.rs` (port-özgü; Zed'de yok) | `WindowControlStyle` builder yardımcısı; Zed'de bu tip ayrı `style.rs`'te değil `platforms/platform_linux.rs` içindedir | Crate-içi (veya kararsız public) |

"Dış API" sütununda "kararsız" yazan modüller, Zed güncellemelerinde değişme ihtimali yüksek alanlardır. Platforma özel butonler ve native sekmeler bu gruba girer. Tüketici kod doğrudan bu yüzeylere yaslanırsa bir Zed güncellemesinde kırıcı değişiklik yaşayabilir. Bu yüzden kararsız API'lere bağlanırken yüzeyi dar tutmak ve mümkünse araya ince bir adaptör koymak daha sağlıklıdır. Public API kararlılık seviyelerinin detaylı tablosu ilgili bölümde yer alır.

---

## 8. Bağımlılık matrisi

`kvs_titlebar/Cargo.toml`:

```toml
[package]
name = "kvs_titlebar"
version = "0.1.0"
edition = "2024"
license = "MIT"            # veya Apache-2.0 — tercihe bağlı
publish = false

[lib]
path = "src/kvs_titlebar.rs" # mod.rs değil

[dependencies]
# Zed workspace (Apache-2.0; pinleme ve yayınlama notları için ilgili bölüm)
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }

# Aile içi crate'ler
kvs_tema = { path = "../kvs_tema" }

# Üçüncü taraf — port'a özgü, opsiyonel.
# Zed'in platform_title_bar crate'i ne anyhow ne de serde kullanır
# (render bileşenidir, hata yaymaz; WindowButtonLayout serde ile değil,
# platform dekorasyon düzeninden parse ile üretilir). İhtiyaç
# duyulması durumunda eklenebilir.
# anyhow = "1"
# serde = { version = "1", features = ["derive"] }
```

`kvs_app_titlebar/Cargo.toml`:

```toml
[package]
name = "kvs_app_titlebar"
version = "0.1.0"
edition = "2024"
license = "MIT"
publish = false

[lib]
path = "src/kvs_app_titlebar.rs"

[dependencies]
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }
kvs_titlebar = { path = "../kvs_titlebar" }
kvs_tema = { path = "../kvs_tema" }

# anyhow port'a özgü ve opsiyoneldir; Zed'in karşılık gelen crate'i kullanmaz.
# anyhow = "1"
```

### Her bağımlılığın rolü

| Crate | Rol | Tema'da/titlebar'da tipik kullanım |
| ------- | ----- | -------------------------------------- |
| `gpui` | UI çatısı, pencere API'leri | `WindowOptions`, `WindowControlArea`, `WindowButtonLayout`, `Window` metotları, `App`/`Context` |
| `kvs_tema` | Tema renkleri | `cx.theme().colors().title_bar_background` |
| `kvs_titlebar` (kvs_app_titlebar için) | Platform kabuğu | `PlatformTitleBar`, `TitleBarController` trait |
| `anyhow` (port'a özgü, opsiyonel) | Zed'in `platform_title_bar` crate'i kullanmaz (render bileşenidir, hata yaymaz). Başlatma hatalarını çağırana iletmek amacıyla eklenebilir. |
| `serde` (port'a özgü, opsiyonel) | Zed'in `platform_title_bar` crate'i kullanmaz. `WindowButtonLayout` serde ile okunmaz; gpui'de platform dekorasyon düzeninden (`gtk-decoration-layout`) `WindowButtonLayout::parse` ile üretilir ve `App::button_layout()` ile alınır |

### Zed bağımlılığı → port karşılığı tablosu

Zed'in `platform_title_bar` ve `title_bar` crate'leri, çalışmak için Zed ekosistemindeki bazı crate'lere yaslanır. Port sırasında bu bağımlılıklar olduğu gibi taşınmaz. Her birinin yerine ürün tarafında bir karşılık geçirilir. Aşağıdaki tablo bu eşleştirmenin yol haritasını verir:

| Zed Bağımlılığı | Bu Rehberdeki Port Karşılığı |
| ----------------- | ------------------------------ |
| `workspace::Workspace` | Uygulamanın kendi shell durumu (örn. `UygulamaKabugu` entity'si) |
| `workspace::CloseWindow` | `TitleBarController::kapat_eylemi()` üzerinden gelen eylem |
| `workspace::MultiWorkspace` | `TitleBarController::sidebar_state()` (opsiyonel) |
| `workspace::client_side_decorations` | Uygulamaya özgü CSD sarmalı |
| `zed_actions::OpenRecent { create_new_window: true }` | `TitleBarController::new_window_action()` |
| `WorkspaceSettings::use_system_window_tabs` | `TitleBarController::use_system_window_tabs(cx)` |
| `ItemSettings::close_position`, `ItemSettings::show_close_button` | Uygulamaya özgü `SekmeAyarlari` veya uygulama yapılandırması |
| `DisableAiSettings` | Uygulamaya özgü özellik bayrağı (`SidebarSettings::enabled` vb.). Zed'de bu bayrak üst barda çok-workspace/sidebar render durumunu kapatır: `is_multi_workspace_enabled`, `!disable_ai` döndürür ve böylece sidebar render durumu (`sidebar_render_state`) yalnız bayrak kapalıyken üretilir |
| `TitleBarSettings::show_onboarding_banner`, `OnboardingBanner::visible_when(...)` | Banner görünürlük ayarı veya özellik bayrağı koşulu. Güncel Zed'de `TitleBar::new` başlangıçta `banner = None` kurar; banner bağlanacaksa ürün katmanı bunu bilinçli ekler. |
| `BannerDetails::action` | Ürünün kendi duyuru/migration modali eylemi; banner tıklandığında gönderilir. |
| `theme::Theme::colors()::title_bar_background` | `kvs_tema::ActiveTheme` + `cx.theme().colors().title_bar_background` |
| `theme::Theme::colors()::title_bar_inactive_background` | `cx.theme().colors().title_bar_inactive_background` |
| `ui::prelude::*`, `ui::IconButton`, `ui::Tooltip` | Uygulamaya özgü UI bileşen kütüphanesi |
| `zed::ReleaseChannel::global(cx).app_id()` | `UygulamaDurumu::app_id()` |

### Versiyon pinleme tavsiyesi

- **`gpui`** git `branch = "main"` üzerinden takip edilir. Belirli bir commit'e sabitlemek gerekirse `rev = "..."` alanı eklenir. Üst bar için en kritik tipler ve metotlar şunlardır: `WindowControlArea`, `WindowButtonLayout`, `WindowButton`, `MAX_BUTTONS_PER_SIDE`, `TitlebarOptions`, `Window::start_window_move`, `SystemWindowTabController`. Her Zed güncellemesinde öncelikle bu imzalar kontrol edilmelidir. Çünkü buradaki küçük bir değişiklik bile alt katmanı doğrudan etkiler.
- **`kvs_tema`** tema rehberinde detaylı anlatılan crate'tir. Aynı workspace'in parçası olduğu için git bağımlılığı yerine path bağımlılığı yeterlidir. Bu tercih geliştirme sırasında değişiklik akışını hızlandırır.

### Bağımlılık akış grafiği

```text
kvs_app_titlebar  ──bağlanır──>  kvs_titlebar, kvs_tema, gpui
                                    ↑
                                    │  AppTitleBar, çocuk olarak
                                    │  PlatformTitleBar'a verilir
                                    │
kvs_titlebar  ──bağlanır──>  gpui, kvs_tema
                             (anyhow/serde port'a özgü, opsiyonel; Zed karşılığı kullanmaz)

kvs_tema  ──bağlanır──>  gpui, refineable, collections, palette, serde, ...

gpui  ──yayımlandığı kaynak──>  zed workspace (Apache-2.0)
```

Bu grafiğin yönü tersine işlemez. Yani `gpui` asla `kvs_titlebar`'a bağlanmaz; `kvs_titlebar` da asla `kvs_app_titlebar`'a bağlanmaz. Bu kural keyfi değildir. Zed upstream'inde bir değişiklik olduğunda etkilenme yüzeyini sınırlamak için vardır. Bağımlılık yönü ters çevrilirse en alttaki Zed kaynaklı bir değişiklik bile dolaylı olarak ürün crate'lerini tetikler hale gelir.

### Lib kökü iskeleti

```rust
//! kvs_titlebar — Zed-uyumlu, lisans-temiz platform titlebar.

mod controller;
mod platform_title_bar;
mod platforms;
mod style;
mod system_window_tabs;

pub use crate::controller::*;
pub use crate::platform_title_bar::*;
pub use crate::platforms::*;
pub use crate::system_window_tabs::*;

// style modülü crate-içi tutulabilir; sadece WindowControlStyle public ise yeniden dışa aç
pub use crate::style::WindowControlStyle;
```

Bu iskelette `platforms` modülünü `mod platforms` + yeniden dışa açma kalıbıyla açmak bir **port tercihidir**. Zed'in kendisi bu modülü doğrudan `pub mod platforms;` ile açar; yani bu kalıp Zed konvansiyonu değil, okunabilirlik için alınan bir karardır. Gerekçesi şudur: Tüketici kodun `platforms::platform_linux::LinuxWindowControls` gibi iç içe yollar yazması gereksiz kalabalık yaratır. Yeniden dışa açma ile `kvs_titlebar::LinuxWindowControls` daha rahat okunur. Zed'in doğrudan yolunun tercih edilmesi durumunda `pub mod platforms;` yazılıp re-export işlemi kaldırılabilir.

### Bağımlılık denetim CI'ı

Geçişli bir GPL bağımlılığının dolaylı yoldan projeye sızma ihtimaline karşı denetim `cargo-deny` aracı ile gerçekleştirilir. Aşağıdaki `deny.toml` kalıbı bu denetimin çekirdeğini oluşturur:

```toml
[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause", "MPL-2.0", "ISC", "Unicode-DFS-2016"]
deny = ["GPL-3.0", "GPL-2.0", "AGPL-3.0", "LGPL-3.0"]

[bans]
# Zed'in GPL crate'lerini istemeden bağımlılık olarak ekleme
deny = [
    { name = "platform_title_bar" },
    { name = "title_bar" },
    { name = "workspace" },
    { name = "project" },
    { name = "settings" },
    { name = "theme" },
    { name = "theme_settings" },
    { name = "theme_selector" },
    { name = "ui" },
    { name = "zed_actions" },
]
```

CI iş akışına aşağıdaki adım eklenmelidir:

```yaml
- name: Lisans kontrolü
  run: cargo deny check licenses bans
```

**İlgili bölüm çıkış kriteri:** `cargo check -p kvs_titlebar -p kvs_app_titlebar` komutu temiz çalışmalıdır. Bu aşamada tiplerin gövdeleri minimal, derlenen stub uygulamalar olabilir; önemli olan modül ağacının hazır olması, derlemenin sorunsuz akması ve lisans-temiz bağımlılık listesinin `cargo deny` tarafından doğrulanmasıdır. Bu üç koşul sağlandığında platform kabuğunun gerçek davranışını yazmak için zemin hazırdır.

---
