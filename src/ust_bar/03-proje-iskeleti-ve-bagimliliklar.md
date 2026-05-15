# Proje iskeleti ve bağımlılıklar

Kaynak haritası bir kez oturduktan sonra sıra ürünün kendi tarafına
gelir: hangi crate'ler oluşturulacak, hangi klasör hangi sorumluluğu
taşıyacak ve bağımlılık grafiği hangi yönde akacak. Bu bölüm, ileride
açılan her dosyanın hangi katmana ait olduğunun bir bakışta
anlaşılabilmesi için fiziksel iskeleti döşer; aynı zamanda lisans
sınırının bu iskelet üzerinde nereye düştüğünü de net biçimde gösterir.

## 7. Crate yapısı ve klasör yerleşimi

Platform title bar, tek crate olarak değil **iki ayrı crate** olarak
konumlanır. Bu ayrım yapay değildir; tema sisteminin
`kvs_tema` + `kvs_syntax_tema` bölünmesindeki mantığın aynısı burada
da geçerlidir.

| Crate | Sorumluluk | Lisans |
|-------|-----------|--------|
| `kvs_titlebar` | `PlatformTitleBar`, platform-spesifik buton tipleri, native tabs, `WindowControlArea` mirror'ları, `TitleBarController` trait | senin lisansın |
| `kvs_app_titlebar` | Ürün başlık içeriği (menü, proje adı, kullanıcı UI, status chip'leri) | senin lisansın |

> **Crate adlandırma:** Bu rehber boyunca kullanılan `kvs_*` öneki
> yalnızca örnektir. Pratikte bu adın yerine `app_titlebar`,
> `core_titlebar` ya da projeye uygun başka bir ad seçilebilir;
> rehberdeki kalıplar isimden bağımsız olarak aynı şekilde uygulanır.

### Neden iki crate?

**Bağımsız test edilebilme ve evrim:**

- `kvs_titlebar` yalnızca platform kabuğunu içerir. Bu sayede Zed'in
  `platform_title_bar` crate'iyle yapılan sync turlarında değişiklik
  alan tek crate burası olur; ürün crate'i sync'ten etkilenmez.
- `kvs_app_titlebar` ise ürünün başlık içeriğini taşır. Bu içerik
  uygulamanın UI tasarım kararlarına bağlıdır ve Zed'in evrimi ile
  doğrudan ilişkilenmez.
- İkisinin ayrı crate'ler olması **derleme süresini** ve **bağımlılık
  grafiğini** net tutar: platform kabuğu yalnızca `gpui`'ye yaslanır,
  ürün başlığı ise tema ve menü crate'lerine bağlanır. Karışıklık
  oluşmaz.

**Lisans izolasyonu:**

- `kvs_titlebar`, Zed'in `platform_title_bar` davranışını mirror eder.
  Doc comment yazımı, fonksiyon isimlendirmesi gibi konularda lisans
  hassasiyeti en çok bu crate'te kendini gösterir.
- `kvs_app_titlebar` ise tamamen ürünün kendi tasarım dilinde yaşar.
  Bu crate'in içine Zed davranışından herhangi bir sızıntı olmaz;
  böylece olası bir lisans tartışmasında temas yüzeyi daralır.

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

Lib kökü olarak `mod.rs` değil, **crate ile aynı isimli dosya**
seçilir (örn. `kvs_titlebar.rs`). Pratik nedeni şudur: editörde
dosyaların sekmelerinde "mod.rs" tekrarları çoğalınca hangi
crate'in kökünün açık olduğu kolay kolay anlaşılmaz; farklı isimler
ise sekme başlığından bile ayırt edilir. Bu aynı zamanda Zed
projesinin kendi konvansiyonudur; tema rehberi Konu 4 ile birebir
örtüşür.

### `DECISIONS.md`

Her crate kendi içinde bir karar günlüğü tutar. Zed'den farklı
yapılan tüm seçimler, küçük dahi olsa, gerekçesiyle birlikte bu
dosyada kayda alınır. Aşağıda örnek bir ilk giriş gösterilmiştir:

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

`DECISIONS.md` dosyası her sync turunda ve her mimari karar
sonrasında **güncellenir**. Bu disiplin pahalı görünebilir; ancak
aradan altı ay geçtiğinde "biz bu kararı neden almıştık?" sorusuna
cevap aranırken günlüğün varlığı çok büyük zaman tasarrufu sağlar.

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

"Dış API" sütununda "kararsız" işareti olan modüller, yani
platform-spesifik butonlar ve native tabs gibi parçalar, Zed sync
turlarında değişme ihtimali yüksek bölgelerdir. Tüketici kod
doğrudan bunlara yaslanırsa olası bir Zed güncellemesinde breaking
change yaşayabilir; bu nedenle kararsız API'lere bağlanırken yüzeyin
geniş tutulmaması, mümkünse arada ince bir adaptör katmanı
bırakılması tavsiye edilir. Public API kararlılık seviyelerinin
detaylı tablosu Bölüm IX, Konu 21'de yer alır.

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

Zed'in `platform_title_bar` ve `title_bar` crate'leri, çalışmak için
Zed iç ekosistemindeki birtakım crate'lere yaslanır. Port sırasında
bu bağımlılıklar olduğu gibi taşınmaz; bunların her birinin yerine
ürünün kendi tarafında bir karşılık geçirilir. Aşağıdaki tablo bu
eşleştirmenin yol haritasını verir:

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

- **`gpui`** git `branch = "main"` üzerinden takip edilir. Belirli
  bir commit'e sabitlemek gerekirse `rev = "..."` alanı eklenir.
  Üst bar için en kritik tipler ve metotlar şunlardır:
  `WindowControlArea`, `WindowButtonLayout`, `TitlebarOptions`,
  `Window::start_window_move`. Her sync turunda öncelikle bu imzaların
  değişip değişmediği kontrol edilir; çünkü buralardaki en küçük bir
  değişiklik bile alt katmanı doğrudan etkiler.
- **`kvs_tema`** tema rehberinde detaylı anlatılan crate'tir. Aynı
  workspace'in parçası olduğu için git dependency yerine path
  dependency yeterli olur; bu, geliştirme sırasında değişiklik akışını
  hızlandırır.

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

Bu grafiğin yönü tersine işlemez. Yani `gpui` asla `kvs_titlebar`'a
bağlanmaz; `kvs_titlebar` da asla `kvs_app_titlebar`'a bağlanmaz. Bu
kural keyfi değildir; Zed upstream'inde bir değişiklik olduğunda
etkilenme yüzeyini sınırlamak için konulmuştur. Aşağı yönlü
bağımlılık demek, üstteki bir değişikliğin alttakileri tetiklemesi
demek; yön ters çevrilirse en alttaki Zed crate'i bile dolaylı
olarak ürün crate'lerini tetikler hâle gelir.

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

Bu iskelette `platforms` modülü, `pub mod platforms` yerine `mod
platforms` + re-export biçiminde tanımlanır. Tercih nedeni
okunabilirliktir: tüketici kodun
`platforms::platform_linux::LinuxWindowControls` gibi iç içe geçmiş
yolları yazması karışık görünür; bunun yerine düz
`kvs_titlebar::LinuxWindowControls` çağrısı çok daha rahat okunur.

### Bağımlılık denetim CI'ı

Transit bir GPL bağımlılığının dolaylı yoldan projeye sızması
ihtimaline karşı, denetim `cargo-deny` ile yapılır. Aşağıdaki
`deny.toml` kalıbı bu denetimin çekirdeğini oluşturur:

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

CI workflow'una aşağıdaki adım eklenir:

```yaml
- name: License check
  run: cargo deny check licenses bans
```

**Bölüm III çıkış kriteri:** `cargo check -p kvs_titlebar -p
kvs_app_titlebar` komutu temiz çalışır. Bu aşamada tiplerin gövdeleri
boş veya `unimplemented!()` olabilir; önemli olan modül ağacının
iskeletinin hazır olması, derlemenin sorunsuz akması ve
lisans-temiz dependency listesinin `cargo deny` tarafından
doğrulanmış olmasıdır. Bu üç koşul birden sağlandığında platform
kabuğunun gerçek davranışını yazmaya geçmek için zemin hazırdır.

