# Proje iskeleti ve bağımlılıklar

Sözleşme sınırları netleştiğinde sıradaki iş, crate yapısını ve bağımlılık
tabanını kurmaktır. Sonraki bütün katmanlar bu iskeletin üzerine oturur. Bu
yüzden klasör yerleşimi ve dependency seçimleri yalnızca başlangıç detayı
değildir; ilerideki geliştirme hızını, test yükünü ve bakım maliyetini
doğrudan etkiler.

---

## 4. Crate yapısı ve klasör yerleşimi

Tema sistemi **iki crate** olarak konumlanır:

| Crate | Sorumluluk | Lisans |
|-------|-----------|--------|
| `kvs_tema` | `Theme`, `ThemeColors`, `IconTheme`, JSON schema, registry, runtime | uygulamanın kendi lisansı |
| `kvs_syntax_tema` | `SyntaxTheme` — kod renkleri | uygulamanın kendi lisansı |

> **Crate adlandırma:** Bu rehberde `kvs_*` prefix'i yalnızca bir örnek
> olarak kullanılır. Uygulama tarafında `app_tema`, `core_tema` veya farklı
> bir isim de tercih edilebilir; rehberin ortaya koyduğu kalıplar isim
> değişse de aynen geçerli kalır.

**Neden iki crate var?** Syntax theme, UI temasından ayrı yaşayabilen bir
pakettir. Bir uygulama UI temasına ihtiyaç duyup syntax highlighting'e ihtiyaç
duymayabilir; tersi de mümkün olabilir. Ayrıca syntax theme tarafı ileride
`tree-sitter` gibi farklı bağımlılıklara açılabilir. Bu olasılığı UI tema
crate'inden ayrı tutmak, hem derleme süresini hem de public API yüzeyini daha
sade bırakır.

**Klasör yerleşimi:**

```
~/github/
├── zed/                         ← referans kaynak
└── kvs_ui/                      ← uygulamanın kendi monorepo'su
    ├── Cargo.toml               ← workspace
    └── crates/
        ├── kvs_tema/
        │   ├── Cargo.toml
        │   ├── src/
        │   │   ├── kvs_tema.rs  ← lib kökü (mod.rs değil)
        │   │   ├── styles.rs
        │   │   ├── styles/
        │   │   │   ├── colors.rs
        │   │   │   ├── status.rs
        │   │   │   ├── players.rs
        │   │   │   ├── accents.rs
        │   │   │   └── system.rs
        │   │   ├── schema.rs    ← JSON Content tipleri
        │   │   ├── refinement.rs ← Content → Theme dönüşümü
        │   │   ├── registry.rs
        │   │   ├── runtime.rs   ← Global, ActiveTheme, init
        │   │   ├── icon_theme.rs ← IconTheme sözleşmesi
        │   │   └── fallback.rs  ← uygulamaya ait default temalar
        │   └── tests/
        │       ├── fixtures/
        │       │   ├── one-dark.json   ← Zed'den, MIT lisanslı
        │       │   └── kvs-default.json
        │       └── parse_fixture.rs
        └── kvs_syntax_tema/
            ├── Cargo.toml
            └── src/kvs_syntax_tema.rs
```

**Modül adlandırma kuralı:** Lib kökü `mod.rs` olarak değil, **crate adıyla
aynı isimli bir dosya** olarak tutulur; örneğin `kvs_tema.rs`. Böylece editör
başlığında hangi crate'in kök dosyasında çalışıldığı hemen görülür. Zed
projesinin kendi konvansiyonu da bu yöndedir.

**Modüllerin sorumluluk haritası:**

| Modül | İçerir | Dış API mı? |
|-------|--------|-------------|
| `kvs_tema.rs` (lib kökü) | Re-export'lar, `Theme`, `Appearance`, `ThemeFamily`; crate-içi `ThemeStyles` | Kısmen |
| `styles/colors.rs` | `ThemeColors` | Evet |
| `styles/status.rs` | `StatusColors` | Evet |
| `styles/players.rs` | `PlayerColors`, `PlayerColor` | Evet |
| `styles/accents.rs` | `AccentColors` | Evet |
| `styles/system.rs` | `SystemColors` | Evet |
| `schema.rs` | `*Content` tipleri, `try_parse_color` | Evet (kararsız) |
| `refinement.rs` | `*_refinement()` fonksiyonları, `apply_*_defaults` | Crate-içi |
| `registry.rs` | `ThemeRegistry`, `ThemeNotFoundError`, `IconThemeNotFoundError` | Evet |
| `runtime.rs` | `GlobalTheme`, `ActiveTheme` trait, `SystemAppearance`, `init` | Evet |
| `icon_theme.rs` | `IconTheme` ve içerik tipleri | Evet |
| `fallback.rs` | `kvs_default_dark()`, `kvs_default_light()` | Evet |

"Dış API" sütununda "kararsız" görünen `schema.rs`, Zed JSON sözleşmesinin
zamanla değişebilen yüzeyini taşır. Bu modüle doğrudan dayanan bir tüketici,
Zed tarafındaki değişiklikleri birinci elden hisseder ve breaking change ile
karşılaşabilir.

---

## 5. Bağımlılık matrisi

**Workspace kökü (`kvs_ui/Cargo.toml`):**

```toml
[workspace]
resolver = "2"
members = [
    "crates/kvs_tema",
    "crates/kvs_syntax_tema",
    # ... uygulama crate'leri
]

[workspace.dependencies]
# Zed workspace bağımlılıkları — alt crate'ler buradan inherit eder
gpui        = { git = "https://github.com/zed-industries/zed", branch = "main" }
refineable  = { git = "https://github.com/zed-industries/zed", branch = "main" }
collections = { git = "https://github.com/zed-industries/zed", branch = "main" }
```

Alt crate'ler bu bağımlılıkları `gpui = { workspace = true }` biçiminde
workspace'ten alır. Böylece kaynak güncellemesi tek bir noktadan yapılır ve
crate'ler arasında sürüm sapması oluşmaz.

`kvs_tema/Cargo.toml`:

```toml
[package]
name = "kvs_tema"
version = "0.1.0"
edition = "2021"
license = "MIT"          # veya Apache-2.0 — uygulamanın tercihine bağlı
publish = false

[lib]
path = "src/kvs_tema.rs" # mod.rs değil

[dependencies]
# Zed workspace (Apache-2.0; publish = false uyarısı için bkz. Konu 3)
gpui = { workspace = true }
refineable = { workspace = true }
collections = { workspace = true }

# Aile içi crate
kvs_syntax_tema = { path = "../kvs_syntax_tema" }

# Üçüncü taraf
anyhow = "1"
indexmap = { version = "2", features = ["serde"] }
palette = { version = "0.7", default-features = false, features = ["std"] }
parking_lot = "0.12"
schemars = "0.8"
serde = { version = "1", features = ["derive"] }
serde_json = "1"
serde_json_lenient = "0.2"
thiserror = "1"
uuid = { version = "1", features = ["v4"] }

[dev-dependencies]
# Headless GPUI test ortamı
gpui = { workspace = true, features = ["test-support"] }
# Refinement karşılaştırmaları için epsilon yardımcısı
approx = "0.5"

[features]
# Tüketici crate'ler için test helper'larını açar (Bölüm XI/Konu 44).
test-util = []
```

`kvs_syntax_tema/Cargo.toml`:

```toml
[package]
name = "kvs_syntax_tema"
version = "0.1.0"
edition = "2021"
license = "MIT"
publish = false

[lib]
path = "src/kvs_syntax_tema.rs"

[dependencies]
gpui = { workspace = true }
```

Syntax crate'in tek bağımlılığı `gpui` ile sınırlıdır. Buna yalnızca
`HighlightStyle` ve renk tipleri için ihtiyaç vardır. Bu izolasyon bilinçli
bir tercihtir: syntax tarafına ileride `tree-sitter` eklense bile UI tema
crate'i bu değişiklikten etkilenmez.

**Her dependency'nin rolü ve kabul ettiği değer:**

| Crate | Rol | Tipik kullanım |
|-------|-----|----------------|
| `gpui` | Renk + bağlam tipleri | `Hsla`, `Rgba`, `SharedString`, `HighlightStyle`, `App`, `Global`, `WindowBackgroundAppearance`, `WindowAppearance` |
| `refineable` | Derive macro | `#[derive(Refineable)]` + `#[refineable(...)]` attribute'leri (Bölüm III/Konu 11) |
| `collections` | Map'ler | `HashMap` (deterministik iter), `IndexMap` |
| `kvs_syntax_tema` | Kardeş crate | `SyntaxTheme::new(highlights)` |
| `anyhow` | Hata propagation | `try_parse_color() -> anyhow::Result<Hsla>` |
| `indexmap` | Sıra koruyan map | `IndexMap<String, HighlightStyleContent>` (syntax'ta sıra anlamlı) |
| `palette` | Renk uzay dönüşümü | sRGB → HSL, `try_parse_color` içinde |
| `parking_lot` | Hızlı kilit | `RwLock<HashMap<...>>` registry'de |
| `schemars` | JSON schema export | IDE auto-complete için tema dosyalarına schema üretmek (opsiyonel) |
| `serde` | Deserialize çekirdek | Tüm `*Content` tipleri için |
| `serde_json` | Standart JSON | Programatik JSON üretimi |
| `serde_json_lenient` | Yorum/trailing comma toleranslı | Zed JSON dosyalarını parse etmek için **şart** |
| `thiserror` | Hata türetme | `#[derive(Error)] ThemeNotFoundError` |
| `uuid` | Unique id | `Theme::from_content` içinde tema id'si |
| `inventory` | Link-time static registration | Zed'de `#[derive(RegisterSetting)]` `inventory::submit!` ile setting tipini ekler; `SettingsStore::new` ise `inventory::iter` ile bunları toplar. Mirror tarafında `kvs_tema_ayarlari` setting'leri otomatik kayıt edilecekse zorunlu hale gelir — alternatifi, register listesini elle tutmaktır |
| `settings_macros` (Zed iç crate) | Derive ve attribute macro'ları | `RegisterSetting`, `MergeFrom`, `with_fallible_options`. Mirror tarafında `kvs_ayarlari_macros` veya benzeri ayrı bir crate kurulur (proc-macro crate'ler diğer crate tipleriyle aynı pakette tutulamaz) |
| `derive_more` | Newtype ergonomi türevleri | `FontSize` newtype'ında `derive_more::FromStr` ile `from_str` üretmek için (`settings_content/src/theme.rs:197`). Mirror tarafında opsiyoneldir; elle de implement edilebilir |
| `serde_path_to_error` | Parse hatasında field path | `settings_json::parse_json_with_comments` bu crate'i kullanır; hata mesajları `theme.colors.background: ...` biçiminde alan yolunu gösterir. Mirror tarafında kullanıcı deneyimi açısından tavsiye edilir |

**Sürüm uyumu:**

- **`palette` major versiyonu Zed'in kullandığıyla aynı tutulmalıdır.**
  Aksi durumda HSL dönüşümü çok küçük miktarda kayabilir ve tema renkleri
  referans JSON çıktısıyla birebir örtüşmeyebilir. Bu fark gözle zor
  seçilebilir, ama exact karşılaştırma yapan testleri bozar.

- **`serde_json_lenient`** Zed'in kullandığı sürümle uyumlu olmalıdır;
  major versiyon değişikliği yorum ve trailing comma parse davranışını
  değiştirebilir, bu da bazı geçerli Zed JSON dosyalarının aniden parse
  edilememesine yol açabilir.

- **`gpui`, `refineable`, `collections`** git kaynağından alınır. Üretim
  ortamında daha kararlı bir davranış için `branch` yerine `rev` ile sabit
  bir commit referansı kullanılabilir:

  ```toml
  gpui = { git = "https://github.com/zed-industries/zed", rev = "6e8eaab25b5ac324e11a82d1563dcad39c84bace" }
  ```

  Branch tracking güncel davranışı takip etmeyi sağlar. `rev` ile sabitleme
  ise dependency yüzeyini daha öngörülebilir hale getirir. Buradaki seçim,
  "her zaman en yeni davranış" ile "her build aynı davranış" arasında yapılır.

**Bağımlılık akış grafiği:**

```
kvs_tema  ──depends on──>  gpui, refineable, collections, kvs_syntax_tema
                           palette, parking_lot, serde, serde_json_lenient,
                           indexmap, schemars, thiserror, anyhow, uuid

kvs_syntax_tema  ──depends on──>  gpui

gpui, refineable, collections  ──sourced from──>  zed workspace (Apache-2.0)
```

Bu grafiğin yönü tersine işlemez; `gpui` hiçbir zaman `kvs_tema`'ya bağlanmaz.
Bu kural sayesinde Zed'in upstream'inde bir değişiklik olduğunda tema crate'i
yalnızca üç yerden etkilenir: **tip imzası**, **davranış** ve **isim/yol
değişimi**. Böylece upstream'i takip ederken nereye bakılacağı baştan bellidir
ve beklenmedik geri etkiler azalır.

**Lib kökü iskeleti (`src/kvs_tema.rs`):**

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

pub(crate) mod refinement;   // crate-içi — Bölüm XI/Konu 43
pub mod fallback;            // namespace: `kvs_tema::fallback::kvs_default_dark`
mod icon_theme;
mod registry;
mod runtime;
mod schema;
mod styles;

// Kararlı dış API — glob ile ihraç
pub use crate::icon_theme::*;
pub use crate::registry::*;
pub use crate::runtime::*;
pub use crate::styles::*;

// Schema — kararsız ama deserialize için gerekli; tek tek ihraç,
// glob asla (yeni iç tip eklenince istemeden public olmasın).
pub use crate::schema::{
    AppearanceContent, FontStyleContent, FontWeightContent,
    HighlightStyleContent, PlayerColorContent, StatusColorsContent,
    ThemeColorsContent, ThemeContent, ThemeFamilyContent,
    ThemeStyleContent, WindowBackgroundContent,
    try_parse_color,
};

use gpui::SharedString;
use std::sync::Arc;

#[derive(Debug, PartialEq, Clone, Copy, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Appearance {
    Light,
    Dark,
}

impl Appearance {
    pub fn is_light(&self) -> bool {
        matches!(self, Self::Light)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct Theme {
    pub id: String,
    pub name: SharedString,
    pub appearance: Appearance,
    pub(crate) styles: ThemeStyles,   // accessor'lar üzerinden — Konu 12
}

#[derive(Clone, Debug, PartialEq)]
pub(crate) struct ThemeStyles {
    pub(crate) window_background_appearance: gpui::WindowBackgroundAppearance,
    pub(crate) system: SystemColors,
    pub(crate) colors: ThemeColors,
    pub(crate) status: StatusColors,
    pub(crate) player: PlayerColors,
    pub(crate) accents: AccentColors,
    pub(crate) syntax: Arc<kvs_syntax_tema::SyntaxTheme>,
}

// Accessor metotları — public okuma yolu (Konu 12, 41, 43)
impl Theme {
    pub fn colors(&self)  -> &ThemeColors   { &self.styles.colors }
    pub fn status(&self)  -> &StatusColors  { &self.styles.status }
    pub fn players(&self) -> &PlayerColors  { &self.styles.player }
    pub fn accents(&self) -> &AccentColors  { &self.styles.accents }
    pub fn system(&self)  -> &SystemColors  { &self.styles.system }
    pub fn syntax(&self)  -> &Arc<kvs_syntax_tema::SyntaxTheme> {
        &self.styles.syntax
    }
    pub fn window_background_appearance(&self) -> gpui::WindowBackgroundAppearance {
        self.styles.window_background_appearance
    }
}

pub struct ThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<Theme>,
}
```

---
