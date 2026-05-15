# Proje iskeleti ve bağımlılıklar

Kaynak haritası anlaşıldıktan sonra lisans-temiz crate sınırlarını, klasörleri ve dependency grafiğini kur.

## 7. Crate yapısı ve klasör yerleşimi

Platform title bar **iki crate** olarak konumlanır; tema sisteminin
`kvs_tema` + `kvs_syntax_tema` ayrımıyla aynı zihniyet.

| Crate | Sorumluluk | Lisans |
|-------|-----------|--------|
| `kvs_titlebar` | `PlatformTitleBar`, platform-spesifik buton tipleri, native tabs, `WindowControlArea` mirror'ları, `TitleBarController` trait | senin lisansın |
| `kvs_app_titlebar` | Ürün başlık içeriği (menü, proje adı, kullanıcı UI, status chip'leri) | senin lisansın |

> **Crate adlandırma:** `kvs_*` prefix bu rehberde örnek. Kendi projende
> `app_titlebar`, `core_titlebar` veya istediğin adı ver; rehber kalıpları
> aynı kalır.

### Neden iki crate?

**Bağımsız test ve evrim:**

- `kvs_titlebar` platform kabuğunu içerir → Zed'in `platform_title_bar`
  sync turlarında değişen tek crate olur.
- `kvs_app_titlebar` ürünün başlık içeriğini içerir → uygulamanın UI
  tasarım kararlarına bağlı; Zed evriminden etkilenmez.
- İkisi ayrı crate olunca **derleme süresi** ve **bağımlılık grafiği**
  net kalır; platform kabuğu sadece `gpui`'ye, ürün başlığı tema/menu
  crate'lerine bağlanır.

**Lisans izolasyonu:**

- `kvs_titlebar` Zed `platform_title_bar` davranışını mirror eder; doc
  comment, isim seçimi gibi konularda lisans-temizliğe en çok özen
  gerektiren crate burası.
- `kvs_app_titlebar` tamamen senin tasarım dilin; Zed davranışı sızıntısı
  yoktur.

### Klasör yerleşimi

```
~/github/
├── gpui_belge/                       ← rehber + aktarım günlüğü + drift script
│   ├── platform_title_bar_rehberi.md
│   ├── platform_title_bar_aktarimi.md
│   └── platform_title_bar_kaymasi_kontrol.sh
├── zed/                              ← referans kaynak
└── kvs_ui/                           ← senin uygulaman
    ├── Cargo.toml                    ← workspace
    └── crates/
        ├── kvs_titlebar/
        │   ├── Cargo.toml
        │   ├── DECISIONS.md          ← Zed'den farklılıkların kaydı
        │   ├── src/
        │   │   ├── kvs_titlebar.rs       ← lib kökü (mod.rs değil)
        │   │   ├── platform_title_bar.rs ← PlatformTitleBar entity
        │   │   ├── platforms/
        │   │   │   ├── platform_linux.rs    ← LinuxWindowControls
        │   │   │   ├── platform_windows.rs  ← WindowsWindowControls
        │   │   │   └── platform_macos.rs    ← macOS davranış helper'ları
        │   │   ├── system_window_tabs.rs ← native pencere sekmeleri
        │   │   ├── controller.rs         ← TitleBarController trait
        │   │   └── style.rs              ← WindowControlStyle helper
        │   └── tests/
        │       ├── controller_mock.rs    ← Mock TitleBarController
        │       └── render_smoke.rs       ← Headless render testleri
        ├── kvs_app_titlebar/
        │   ├── Cargo.toml
        │   ├── src/
        │   │   ├── kvs_app_titlebar.rs   ← lib kökü
        │   │   ├── app_title_bar.rs      ← AppTitleBar entity (Zed'in TitleBar'ı muadili)
        │   │   ├── menu.rs               ← uygulama menüsü
        │   │   ├── project_picker.rs     ← proje/doküman adı widget'ı
        │   │   └── user_menu.rs          ← kullanıcı menüsü (opsiyonel)
        │   └── tests/
        └── kvs_tema/                ← tema rehberinden
            └── ...
```

### Modül adlandırma kuralı

Lib kökü `mod.rs` yerine **crate adıyla aynı isimli dosya** (örn.
`kvs_titlebar.rs`). Bu, editör başlığında hangi dosyayı düzenlediğini
görmeni sağlar; Zed projesinin kendi konvansiyonu da budur (tema
rehberi Konu 4 ile aynı).

### `DECISIONS.md`

Her crate kendi karar günlüğünü tutar. Zed'den farklı yaptığın her şey
burada gerekçesiyle kayıt altına alınır. Örnek ilk giriş:

```markdown
# kvs_titlebar karar günlüğü

## YYYY-MM-DD — İlk pin

- Pin: <Zed kısa SHA> (bkz. ../../gpui_belge/platform_title_bar_aktarimi.md)
- Crate yapısı: kvs_titlebar (platform kabuğu) + kvs_app_titlebar (ürün başlığı)
- TitleBarController trait: uygulama action / sidebar / button_layout
  sorularını trait üzerinden alır (Zed'in workspace doğrudan referansı
  yerine)
- SystemWindowTabs: ilk sürümde **kapalı** (feature flag default off);
  uygulama native tab desteğine ihtiyaç doğunca açılacak
- macOS double-click davranışı: sistem default'a teslim edilir; ayar
  override'ı yapılmaz (gerekirse Konu 11'e göre eklenir)
- Linux CSD: WindowDecorations::Client desteklenir; CSD sarmalı
  (client_side_decorations muadili) ayrı bir helper olarak yazılır
```

`DECISIONS.md`'yi her sync turunda ve mimari kararda **güncelle**. 6 ay
sonraki sen sana minnettar olur.

### Modüllerin sorumluluk haritası

| Modül | İçerir | Dış API mı? |
|-------|--------|-------------|
| `kvs_titlebar.rs` (lib kökü) | Re-export'lar, `PlatformTitleBar`, `TitleBarController` | Evet |
| `platform_title_bar.rs` | `PlatformTitleBar`, render fonksiyonları, `render_left_window_controls`, `render_right_window_controls` | Evet |
| `platforms/platform_linux.rs` | `LinuxWindowControls`, `WindowControl`, `WindowControlStyle` | Evet (kararsız) |
| `platforms/platform_windows.rs` | `WindowsWindowControls` | Evet (kararsız) |
| `platforms/platform_macos.rs` | macOS davranış helper'ları (genelde trivial) | Crate-içi |
| `system_window_tabs.rs` | `SystemWindowTabs`, `SystemWindowTabController`, native tab davranışı | Evet (kararsız) |
| `controller.rs` | `TitleBarController` trait, ilgili veri tipleri (`ShellSidebarState`, vs.) | Evet |
| `style.rs` | `WindowControlStyle` builder helper'ı | Crate-içi (veya kararsız public) |

"Dış API" sütununda "kararsız" işareti olan modüller (platform-spesifik
butonlar, native tabs) Zed sync turlarında değişme olasılığı yüksek
olan parçalar; tüketici doğrudan bunlara dayanırsa breaking change'e
açıktır. Public API kararlılık seviyeleri Bölüm IX/Konu 21'de detaylı.

---

## 8. Bağımlılık matrisi

`kvs_titlebar/Cargo.toml`:

```toml
[package]
name = "kvs_titlebar"
version = "0.1.0"
edition = "2021"
license = "MIT"            # veya Apache-2.0 — kendi seçimin
publish = false

[lib]
path = "src/kvs_titlebar.rs" # mod.rs değil

[dependencies]
# Zed workspace (Apache-2.0; publish = false uyarısı için Konu 3)
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }

# Aile içi crate'ler
kvs_tema = { path = "../kvs_tema" }

# Üçüncü taraf
anyhow = "1"
serde = { version = "1", features = ["derive"] }
```

`kvs_app_titlebar/Cargo.toml`:

```toml
[package]
name = "kvs_app_titlebar"
version = "0.1.0"
edition = "2021"
license = "MIT"
publish = false

[lib]
path = "src/kvs_app_titlebar.rs"

[dependencies]
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }
kvs_titlebar = { path = "../kvs_titlebar" }
kvs_tema = { path = "../kvs_tema" }

anyhow = "1"
```

### Her dependency'nin rolü

| Crate | Rol | Tema'da/title bar'da tipik kullanım |
|-------|-----|--------------------------------------|
| `gpui` | UI çatısı, pencere API'leri | `WindowOptions`, `WindowControlArea`, `WindowButtonLayout`, `Window` methodları, `App`/`Context` |
| `kvs_tema` | Tema renkleri | `cx.theme().colors().title_bar_background` |
| `kvs_titlebar` (kvs_app_titlebar için) | Platform kabuğu | `PlatformTitleBar`, `TitleBarController` trait |
| `anyhow` | Hata propagation | Tema/state init hatalarını caller'a iletmek |
| `serde` | Settings deserialize | `WindowButtonLayout` ayarını kullanıcı config'inden okumak |

### Zed bağımlılığı → port karşılığı tablosu

Zed'in `platform_title_bar` ve `title_bar` crate'leri aşağıdaki Zed-içi
crate'lere bağlanır. Port ederken bunları **kendi karşılıklarınla
değiştir**:

| Zed bağımlılığı | Bu rehberdeki port karşılığı |
|-----------------|------------------------------|
| `workspace::Workspace` | Uygulamanın kendi shell state'i (örn. `AppShell` entity'si) |
| `workspace::CloseWindow` | `TitleBarController::close_action()` üzerinden gelen action |
| `workspace::MultiWorkspace` | `TitleBarController::sidebar_state()` (opsiyonel) |
| `workspace::client_side_decorations` | Kendi CSD sarmalı (Konu 9) |
| `zed_actions::OpenRecent { create_new_window: true }` | `TitleBarController::new_window_action()` |
| `WorkspaceSettings::use_system_window_tabs` | `TitleBarController::use_system_window_tabs(cx)` |
| `ItemSettings::close_position`, `ItemSettings::show_close_button` | Senin kendi `TabSettings` veya app config |
| `DisableAiSettings` | Senin kendi feature flag'in (`SidebarSettings::enabled` vb.) |
| `feature_flags::FeatureFlagAppExt`, `SkillsFeatureFlag` (`title_bar/Cargo.toml` ve `title_bar.rs`) | Kendi feature flag altyapısı; `cx.has_flag::<FooFlag>()` benzeri bir yardımcı veya boolean ayar ile değiştirilir. Zed `title_bar` crate'i bu bağımlılığı `OnboardingBanner` görünürlüğünü kapatıp açmak için kullanır. |
| `zed_actions::agent::OpenRulesToSkillsMigrationInfo` | Ürünün kendi duyuru/migration modalı action'ı; banner tıklandığında dispatch edilir. |
| `theme::Theme::colors()::title_bar_background` | `kvs_tema::ActiveTheme` + `cx.theme().colors().title_bar_background` |
| `theme::Theme::colors()::title_bar_inactive_background` | `cx.theme().colors().title_bar_inactive_background` |
| `ui::prelude::*`, `ui::IconButton`, `ui::Tooltip` | Kendi UI bileşen kütüphanen |
| `zed::ReleaseChannel::global(cx).app_id()` | Senin `AppState::app_id()` |

### Versiyon pinleme tavsiyesi

- **`gpui` git `branch = "main"`** ile takip ediliyor; pin commit'e
  sabitlemek istersen `rev = "..."` kullan. Title bar için en kritik
  imzalar: `WindowControlArea`, `WindowButtonLayout`, `TitlebarOptions`,
  `Window::start_window_move`. Sync turunda bu imzaların değişip
  değişmediği kontrol edilir.
- **`kvs_tema`** tema rehberinde anlatılan crate; aynı workspace'in
  parçası olduğu için path dep yeterli.

### Bağımlılık akış grafiği

```
kvs_app_titlebar  ──depends on──>  kvs_titlebar, kvs_tema, gpui
                                    ↑
                                    │  AppTitleBar, child olarak
                                    │  PlatformTitleBar'a verilir
                                    │
kvs_titlebar  ──depends on──>  gpui, kvs_tema, anyhow, serde

kvs_tema  ──depends on──>  gpui, refineable, collections, palette, serde, ...

gpui  ──published from──>  zed workspace (Apache-2.0)
```

Bu grafiğin yönü tersine işlemez; `gpui` asla `kvs_titlebar`'a bağlanmaz.
`kvs_titlebar` asla `kvs_app_titlebar`'a bağlanmaz. Bu kural, Zed'in
upstream'inde değişiklik olduğunda etkilenme yüzeyini sınırlar.

### Lib kökü iskeleti (`kvs_titlebar/src/kvs_titlebar.rs`)

```rust
//! kvs_titlebar — Zed-uyumlu, lisans-temiz platform title bar.

mod controller;
mod platform_title_bar;
mod platforms;
mod style;
mod system_window_tabs;

pub use crate::controller::*;
pub use crate::platform_title_bar::*;
pub use crate::platforms::*;
pub use crate::system_window_tabs::*;

// style modülü crate-içi tutulabilir; sadece WindowControlStyle public ise re-export
pub use crate::style::WindowControlStyle;
```

`platforms` modülünü `pub mod platforms` yerine `mod platforms` + re-export
seçtim çünkü `platforms::platform_linux::*` gibi nested path tüketici için
karışık; düz `kvs_titlebar::LinuxWindowControls` daha okunabilir.

### Bağımlılık denetim CI'ı

`cargo-deny` ile transit GPL bağımlılık girişini engelle (`deny.toml`):

```toml
[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause", "MPL-2.0", "ISC", "Unicode-DFS-2016"]
deny = ["GPL-3.0", "GPL-2.0", "AGPL-3.0", "LGPL-3.0"]

[bans]
# Zed'in GPL crate'lerini kazara dep olarak ekleme
deny = [
    { name = "platform_title_bar" },
    { name = "title_bar" },
    { name = "workspace" },
    { name = "theme" },
    { name = "theme_settings" },
    { name = "theme_selector" },
    { name = "zed_actions" },
]
```

CI workflow'una ekle:

```yaml
- name: License check
  run: cargo deny check licenses bans
```

**Bölüm III çıkış kriteri:** `cargo check -p kvs_titlebar -p kvs_app_titlebar`
yeşil. Tipler tanımlı (alanları boş veya `unimplemented!()` olsa bile);
modül ağacının iskeleti hazır; lisans-temiz dep listesi `cargo deny` ile
doğrulanıyor.

