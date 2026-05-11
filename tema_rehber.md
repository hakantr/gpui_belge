# Zed Uyumlu Tema Yönetim Sistemi — Geliştirici Rehberi

Bu rehber, **GPUI tabanlı kendi uygulaman için Zed-tarzı bir tema yönetim
sistemini sıfırdan kurmana** yardım eder. Hedef: Zed'in `crates/theme` crate'ini
**doğrudan kullanmadan** (GPL-3 lisans nedeniyle), aynı kullanıcı deneyimini
veren, **Zed JSON tema dosyalarını birebir parse edebilen**, lisans açısından
temiz bir tema sistemi inşa etmek.

> **Eşlik eden dosyalar:** `tema_aktarimi.md` (upstream pin/sync günlüğü)
> ve `tema_kaymasi_kontrol.sh` (drift raporu). Bu rehber **mimari, sözleşme
> ve kod** tarafına odaklanır; uzun vadeli senkron disiplini için onlara
> bakın.

> **Anlatım biçimi:** Rehber, GPUI ana referansı `rehber.md`'nin tarzını
> izler — her konu kendi başına okunabilir; kullanılan tipi, hangi modülden
> geldiğini, neyi kabul ettiğini, runtime davranışını ve yaygın tuzakları
> tek yerde toplar. Faz tabanlı eski yapıdan konu tabanlı referans yapıya
> aktarım sürmektedir; geçici olarak "Ek" bölümünde eski içerik korunur.

---

## İçindekiler

### Bölüm I — Mimari ve İlkeler
1. [Üç katmanlı yaklaşım ve büyük resim](#1-üç-katmanlı-yaklaşım-ve-büyük-resim)
2. [Temel ilke: veri sözleşmesinde dışlama yok](#2-temel-ilke-veri-sözleşmesinde-dışlama-yok)
3. [Lisans-temiz çalışma protokolü](#3-lisans-temiz-çalışma-protokolü)
4. [Crate yapısı ve klasör yerleşimi](#4-crate-yapısı-ve-klasör-yerleşimi)
5. [Bağımlılık matrisi](#5-bağımlılık-matrisi)

### Bölüm II — GPUI'nin tema için kullanılan yüzeyi
6. Renk tipleri: `Hsla`, `Rgba` ve constructor'lar
7. Metin/font tipleri: `HighlightStyle`, `FontStyle`, `FontWeight`
8. Pencere: `WindowBackgroundAppearance`, `WindowAppearance`
9. Bağlam tipleri: `App`, `Context<T>`, `Window`, `BorrowAppContext`
10. `Global` trait ve `cx.set_global / update_global / refresh_windows`
11. `refineable::Refineable` derive davranışı

### Bölüm III — Veri sözleşmesi tipleri
12. `Theme` ve `ThemeStyles` üst yapısı
13. `ThemeColors` alan kataloğu
14. `StatusColors`: fg/bg/border üçlüsü deseni
15. `PlayerColors`, `PlayerColor`, slot semantiği
16. `AccentColors`, `SystemColors`, `Appearance`
17. `ThemeFamily`, `SyntaxTheme`, `IconTheme`

### Bölüm IV — JSON şeması katmanı
18. `ThemeContent` ve serde flatten/rename desenleri
19. `*Content` tiplerinin opsiyonellik felsefesi
20. `try_parse_color`: hex → `Hsla` boru hattı
21. Hata tolerans: `treat_error_as_none`, `deny_unknown_fields` tuzağı
22. JSON anahtar konvansiyonu (dot vs snake_case)

### Bölüm V — Refinement katmanı
23. Content → Refinement → Theme akışı
24. `theme_colors_refinement`, `status_colors_refinement` deseni
25. `apply_status_color_defaults`: %25 alpha türetme kuralı
26. `Theme::from_content` birleşik akış

### Bölüm VI — Runtime katmanı
27. `ThemeRegistry`: API yüzeyi ve thread safety
28. `GlobalTheme` ve `ActiveTheme` trait
29. `SystemAppearance` ve sistem mod takibi
30. `init()`: kuruluş sırası ve fallback yükleme
31. Tema değiştirme ve `cx.refresh_windows()`

### Bölüm VII — Varlık ve test
32. Fallback tema tasarımı
33. Built-in tema bundling ve `AssetSource`
34. Fixture testleri ve JSON sözleşme doğrulama
35. Lisans doğrulama akışı

### Bölüm VIII — Tüketim ve dış API
36. `cx.theme()` ile bileşen renklendirme
37. Hover / active / disabled / selected / ghost desenleri
38. Public API kataloğu ve crate-içi sınır
39. Test ortamında tema mock'lama

### Bölüm IX — Pratik
40. Sınama listesi
41. Yaygın tuzaklar
42. Reçeteler

---

## Bölüm I — Mimari ve İlkeler

---

### 1. Üç katmanlı yaklaşım ve büyük resim

**Kaynak yön:** Aşağıdan yukarıya — veri sözleşmesi en alttadır ve mirror
disiplini ister; üst katmanlar tasarım özgürlüğüyle yazılır.

```
┌─────────────────────────────────────────────────────────────────┐
│  Runtime (kendi kodun, Zed'le 1:1 olmak zorunda değil)          │
│  - ThemeRegistry    - GlobalTheme    - ActiveTheme trait        │
│  - SystemAppearance - set_theme      - cx.theme()               │
├─────────────────────────────────────────────────────────────────┤
│  Refinement / dönüşüm (Zed davranışını öğreniyor, yeniden yaz)  │
│  - Content → Refinement → Theme akışı                           │
│  - apply_status_color_defaults, apply_theme_color_defaults      │
├─────────────────────────────────────────────────────────────────┤
│  Veri sözleşmesi (Zed JSON'larını parse için MIRROR)            │
│  - Theme, ThemeColors, StatusColors, PlayerColors, AccentColors │
│  - ThemeContent, ThemeColorsContent (JSON anahtarları)          │
└─────────────────────────────────────────────────────────────────┘
```

**Veri sözleşmesi (en alt katman) — `mirror`:** Zed'in JSON tema dosyalarını
birebir parse edebilmek için struct'lar. Alan adları, JSON anahtarları,
opsiyonellik dereceleri — hepsi Zed'in `crates/theme/src/styles/` ve
`crates/settings_content/src/theme.rs` ile **aynı şekilde** yazılır.
Yaratıcılık yok; sadece sözleşme parite. Bölüm III ve IV bu katmanı
ele alır.

**Refinement (orta katman) — `davranış`:** Kullanıcının yazdığı tema
(genelde eksik alanlar içeren JSON) ile baseline tema (fallback)
birleştirme mantığı. Zed'in `refineable` crate'inin sağladığı `Refineable`
derive macro'su her struct için `Option<T>` alanlı ikiz bir `*Refinement`
tipi üretir; bunu `original.refine(&refinement)` ile uygularsın. Ek
olarak, foreground rengi verilmiş ama background verilmemiş durumları
otomatik türeten yardımcılar (`apply_status_color_defaults`) bu
katmandadır. Davranışı Zed'den **öğrenirsin**, ama kodunu kendi
sözcüklerinle yazarsın (GPL-3 nedeniyle birebir kopyalama yok). Bölüm V
bu katmanı ele alır.

**Runtime (en üst katman) — `senin tasarımın`:** `cx.theme()` ile aktif
temayı sorgulama, `set_theme` ile değiştirme, sistem light/dark modunu
izleme. Bu katman tamamen senin tasarımındır — Zed'in
`crates/theme_settings/` veya `crates/theme_selector/` crate'lerini
taklit etmek zorunda değilsin. Kendi config sisteminle, kendi UI'nla
entegre edersin. Bölüm VI bu katmanı ele alır.

**Bağımlılık yönü:**

```
Runtime  ──depends on──>  Refinement  ──depends on──>  Veri sözleşmesi
                                                       │
                                                       └─> gpui, refineable, collections
```

Ters yön yasak: veri sözleşmesi asla refinement'a, refinement asla
runtime'a referans vermez. Bu, üst katmanları değiştirirken alt
katmanların hareketsiz kalmasını garanti eder.

**Lisans katmanlama:**

| Katman | Lisans tarafı |
|--------|---------------|
| Veri sözleşmesi | Alan adları ve JSON anahtarları telif kapsamında değil; mirror serbest |
| Refinement | Davranış öğrenilir, kod kendi sözcüklerinizle yazılır (GPL-3 kod gövdesi kopyalama yasak) |
| Runtime | Tamamen sizin; Zed'in `theme_settings`/`theme_selector` koduyla hiçbir ilgisi yok |

---

### 2. Temel ilke: veri sözleşmesinde dışlama yok

Zed'in JSON tema sözleşmesindeki **hiçbir alan kasıtlı olarak
dışlanmaz**: `terminal_ansi_*`, editor diff hunk, debugger, vcs, vim,
panel, scrollbar, tab, search, icon theme — tümü mirror struct'larında
**alan olarak bulunur**.

**Gerekçe:**

- Bu rehber tüm Zed alanlarını destekleyecek bir uygulama varsayar.
  Geliştiricinin hangi özellikleri (terminal, debugger, diff görünümü
  vs.) ileride ekleyip eklemeyeceğini önceden bilemeyiz; varsayılan
  "hepsi eklenir".
- Eksik bir alan, Zed JSON'unda göründüğünde sessizce kaybolur ya da
  `deny_unknown_fields` açıksa deserialize hatası verir.
- UI'da okunmadığı sürece bir alanın struct'ta bulunması **sıfır
  maliyettir** — değer baseline'dan veya kullanıcı temasından dolar,
  sadece kullanılmaz.

**Dışlama kararı kalıcı ve kesin bir sebep gerektirir** (örn. lisans
çakışması, platforma özgü kısıt). "Henüz UI'da kullanmıyorum" geçerli
bir dışlama sebebi değildir.

**Karar günlüğü:** Bir alanı dışlamak için sebep gerçekten haklıysa,
kaydı `tema_aktarimi.md`'nin "Senkron edilMEYEN" bölümüne **tarih +
gözden geçirme koşuluyla** beraber yazılır. Bu kayıt olmadan dışlama
yapma; aksi takdirde 6 ay sonra "neden bu alan yok?" sorusu cevapsız
kalır.

**Kontrol listesi:** Bir struct'a alan eklemeye karar verirken üç soru:

1. Zed sözleşmesinde var mı? → Var ise **ekle**, içerik karar gerektirmez.
2. Mevcut UI'da okunuyor mu? → Okunmuyorsa da **ekle**; "henüz" geçerli
   değil.
3. Kalıcı dışlama gerekçesi var mı? → Varsa `tema_aktarimi.md`'ye yaz,
   sonra atla.

---

### 3. Lisans-temiz çalışma protokolü

Zed'in tema sistemi **GPL-3.0-or-later** lisanslıdır. Kod gövdesi
kopyalanamaz; ancak alan adları, JSON anahtarları ve sözleşme şeması
(yani struct'ların layout'u) telif kapsamında değildir ve mirror
edilebilir.

**Yapılabilir / Yapılamaz:**

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| Alan adlarını okuyup yeniden yazmak | Kod gövdesini kopyalamak |
| JSON anahtarlarını birebir mirror etmek | Default renk paletini (`default_colors.rs` HSL değerleri) taşımak |
| Doc comment'i kendi sözcüklerinle yazmak | Doc comment'i kelime kelime kopyalamak |
| Refinement davranışını anlayıp kendi versiyonunu kodlamak | `fallback_themes.rs`'nin algoritmasını birebir taşımak |
| Fixture testleri için MIT/Apache lisanslı tema JSON'larını kopyalamak (lisansla beraber) | Lisans dosyası olmadan tema JSON'u taşımak |

**Güvenli dependency'ler (hepsi Apache-2.0, Zed workspace'inden alınabilir):**

- `gpui` — UI çatısı; `Hsla`, `SharedString`, `HighlightStyle`,
  `App`/`Context`/`Window`, `Global` trait gibi tip ve servisleri sağlar.
- `refineable` — `#[derive(Refineable)]` macro; her struct için
  `Option<T>` alanlı `*Refinement` ikizi üretir.
- `collections` — Deterministik iteration sıralı `HashMap`/`IndexMap`
  wrapper'ları.

**GPL-3 crate'ler (`theme`, `syntax_theme`, `theme_settings`,
`theme_selector`, `theme_importer`, `theme_extension`):** Sadece referans
için **okunur**. Asla `Cargo.toml`'a dependency olarak eklenmez. Bu kural
keskindir; ihlal edersen ürettiğin uygulama GPL-3 sözleşmesi altına
girer.

**Publishing uyarısı:** `gpui`, `refineable`, `collections` Zed
workspace'inde `publish = false` ile işaretlidir. Yani crates.io
üzerinden yayınladığın bir crate'in dependency listesinde git/path dep
olarak bunlar olamaz. Üç çözüm:

1. **Vendor:** Kaynak kodu kendi monorepo'na kopyala (lisans + atribusyon
   koru).
2. **Fork yayınla:** `gpui` ve `refineable`'ı kendi adınla crates.io'ya
   yayınla.
3. **Sadece dahili kullan:** Uygulaman binary olarak dağıtılıyorsa
   (kütüphane değil), git dep yeterli.

**Doc comment yazımı:** Zed kaynak dosyasındaki bir struct alanını mirror
ediyorsan, doc comment'i **kendi sözcüklerinle** yaz. Aynı cümleyi
kullanma. Örnek:

```rust
// Zed'de (mirror EDİLMEZ):
/// The color used for the background of a fill element.

// Sizde (mirror EDİLİR, yeniden yazılmış):
/// Dolu (fill) bir element'in arka plan rengi.
pub border: Hsla,
```

---

### 4. Crate yapısı ve klasör yerleşimi

Tema sistemi **iki crate** olarak konumlanır:

| Crate | Sorumluluk | Lisans |
|-------|-----------|--------|
| `kvs_tema` | `Theme`, `ThemeColors`, `IconTheme`, JSON schema, registry, runtime | senin lisansın |
| `kvs_syntax_tema` | `SyntaxTheme` — kod renkleri | senin lisansın |

> **Crate adlandırma:** Bu rehberde `kvs_*` prefix'i örnek olarak
> kullanılır. Kendi projende `app_tema`, `core_tema` veya istediğin adı
> ver; rehber kalıpları aynı kalır.

**Neden iki crate?** Syntax theme bağımsız bir paket — bir uygulama UI
temasına ihtiyaç duyabilir ama syntax highlighting'e duymayabilir
(veya tersi). Ayrıca syntax theme ileride `tree-sitter` gibi farklı
dep'lere açılabilir; bunu UI tema crate'inden izole tutmak derleme
süresini ve API yüzeyini sade tutar.

**Klasör yerleşimi:**

```
~/github/
├── gpui_belge/                  ← bu rehber + sync dosyaları
│   ├── tema_rehber.md
│   ├── tema_aktarimi.md
│   └── tema_kaymasi_kontrol.sh
├── zed/                         ← referans kaynak
└── kvs_ui/                      ← senin uygulaman
    ├── Cargo.toml               ← workspace
    └── crates/
        ├── kvs_tema/
        │   ├── Cargo.toml
        │   ├── DECISIONS.md     ← Zed'den farklılıkların kaydı
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
        │   │   └── fallback.rs  ← kendi default temaların
        │   └── tests/
        │       ├── fixtures/
        │       │   ├── one-dark.json   ← Zed'den, MIT lisanslı
        │       │   └── kvs-default.json
        │       └── parse_fixture.rs
        └── kvs_syntax_tema/
            ├── Cargo.toml
            └── src/kvs_syntax_tema.rs
```

**Modül adlandırma kuralı:** Lib kökü `mod.rs` yerine **crate adıyla aynı
isimli dosya** (örn. `kvs_tema.rs`). Bu, editör başlığında hangi
dosyayı düzenlediğini görmeni sağlar; Zed projesinin kendi konvansiyonu
da budur.

**`DECISIONS.md`:** Her crate kendi karar günlüğünü tutar. Zed'den farklı
yaptığın her şey burada gerekçesiyle kayıt altına alınır. Örnek ilk
giriş:

```markdown
# Tema sistemi karar günlüğü

## 2026-05-11 — İlk pin

- Pin: db6039d815 (bkz. ../../gpui_belge/tema_aktarimi.md)
- Crate yapısı: kvs_tema + kvs_syntax_tema (Zed'in theme + syntax_theme'i karşılığı)
- Settings entegrasyonu: kendi config sistemimize bağlı (theme_settings karşılığı yok)
- IconTheme: kvs_tema kapsamında; `icon_theme.rs` modülü Zed'in
  `crates/theme/src/icon_theme.rs` sözleşmesini alan paritesiyle mirror eder
- Tüm Zed alan grupları (editor, terminal_ansi, debugger, diff hunk, vcs, vim)
  struct'larda yer alır; UI'da okunmasalar bile dahil (Temel ilke gereği)
```

`DECISIONS.md`'yi her sync turunda ve mimari kararda **güncelle**. 6 ay
sonraki sen sana minnettar olur.

**Modüllerin sorumluluk haritası:**

| Modül | İçerir | Dış API mı? |
|-------|--------|-------------|
| `kvs_tema.rs` (lib kökü) | Re-export'lar, `Theme`, `ThemeStyles`, `Appearance`, `ThemeFamily` | Evet |
| `styles/colors.rs` | `ThemeColors` | Evet |
| `styles/status.rs` | `StatusColors` | Evet |
| `styles/players.rs` | `PlayerColors`, `PlayerColor` | Evet |
| `styles/accents.rs` | `AccentColors` | Evet |
| `styles/system.rs` | `SystemColors` | Evet |
| `schema.rs` | `*Content` tipleri, `try_parse_color` | Evet (kararsız) |
| `refinement.rs` | `*_refinement()` fonksiyonları, `apply_*_defaults` | Crate-içi |
| `registry.rs` | `ThemeRegistry`, `ThemeNotFound` | Evet |
| `runtime.rs` | `GlobalTheme`, `ActiveTheme` trait, `SystemAppearance`, `init` | Evet |
| `icon_theme.rs` | `IconTheme` ve içerik tipleri | Evet |
| `fallback.rs` | `kvs_default_dark()`, `kvs_default_light()` | Evet |

"Dış API" sütununda "kararsız" işareti olan modül (`schema.rs`) tip
yüzeyi sync turlarında değişebilir; tüketici bu modüle doğrudan dayanırsa
breaking change yaşar.

---

### 5. Bağımlılık matrisi

`kvs_tema/Cargo.toml`:

```toml
[package]
name = "kvs_tema"
version = "0.1.0"
edition = "2021"
license = "MIT"          # veya Apache-2.0 — kendi seçimin
publish = false

[lib]
path = "src/kvs_tema.rs" # mod.rs değil

[dependencies]
# Zed workspace (Apache-2.0; publish = false uyarısı için bkz. Konu 3)
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }
refineable = { git = "https://github.com/zed-industries/zed", branch = "main" }
collections = { git = "https://github.com/zed-industries/zed", branch = "main" }

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
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }
```

Syntax crate'in tek bağımlılığı `gpui` — sadece `HighlightStyle` ve renk
tipleri için. Bu izolasyon kasıtlı; ileride syntax'a `tree-sitter`
eklersen UI tema crate'i etkilenmez.

**Her dependency'nin rolü ve kabul ettiği değer:**

| Crate | Rol | Tipik kullanım |
|-------|-----|----------------|
| `gpui` | Renk + bağlam tipleri | `Hsla`, `Rgba`, `SharedString`, `HighlightStyle`, `App`, `Global`, `WindowBackgroundAppearance`, `WindowAppearance` |
| `refineable` | Derive macro | `#[derive(Refineable)]` + `#[refineable(...)]` attribute'leri (Bölüm II/Konu 11) |
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
| `thiserror` | Hata türetme | `#[derive(Error)] ThemeNotFound` |
| `uuid` | Unique id | `Theme::from_content` içinde tema id'si |

**Versiyon pinleme tavsiyesi:**

- **`palette` major versiyonu Zed'in kullandığıyla aynı olmalı.** Aksi
  halde HSL dönüşümü ufak miktarda kayabilir ve testler upstream
  fixture'larıyla eşleşmez. Pin commit'indeki Zed `Cargo.lock`
  dosyasından kontrol et:

  ```sh
  grep -A1 '"palette"' ../zed/Cargo.lock | head -4
  ```

- **`serde_json_lenient`** Zed'in kullandığıyla uyumlu olmalı; major
  versiyon değişimi yorum/trailing comma parse davranışını değiştirebilir.

- **`gpui`, `refineable`, `collections`** git `branch = "main"` ile takip
  ediliyor; bunu **pin commit'e** (`tema_aktarimi.md`'deki SHA'ya)
  sabitlemek istersen `rev = "db6039d815..."` kullan. Sync turunda bu
  SHA güncellenir:

  ```toml
  gpui = { git = "https://github.com/zed-industries/zed", rev = "db6039d815893750ad45e548d6a7c1a64bba5d2a" }
  ```

  Branch tracking, en güncel davranışı almanı sağlar ama her `cargo
  update` derlemeyi bozabilir. Rev pin, kararlılık verir ama sync
  turlarında bilinçli güncelleme gerektirir. **Önerim:** baseline'da
  branch, production'da rev.

**Bağımlılık akış grafiği:**

```
kvs_tema  ──depends on──>  gpui, refineable, collections, kvs_syntax_tema
                           palette, parking_lot, serde, serde_json_lenient,
                           indexmap, schemars, thiserror, anyhow, uuid

kvs_syntax_tema  ──depends on──>  gpui

gpui, refineable, collections  ──published from──>  zed workspace (Apache-2.0)
```

Bu grafiğin yönü tersine işlemez; `gpui` asla `kvs_tema`'ya bağlanmaz.
Bu kural, Zed'in upstream'inde değişiklik olduğunda senin tema crate'inin
etkilenmesini sınırlar — değişiklik sadece üç vektörden gelir: **tip
imzası**, **davranış**, **isim/yol değişimi**.

**Lib kökü iskeleti (`src/kvs_tema.rs`):**

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

mod fallback;
mod icon_theme;
mod refinement;
mod registry;
mod runtime;
mod schema;
mod styles;

pub use crate::icon_theme::*;
pub use crate::refinement::*;
pub use crate::registry::*;
pub use crate::runtime::*;
pub use crate::schema::*;
pub use crate::styles::*;

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
    pub styles: ThemeStyles,
}

#[derive(Clone, Debug, PartialEq)]
pub struct ThemeStyles {
    pub window_background_appearance: gpui::WindowBackgroundAppearance,
    pub system: SystemColors,
    pub colors: ThemeColors,
    pub status: StatusColors,
    pub player: PlayerColors,
    pub accents: AccentColors,
    pub syntax: Arc<kvs_syntax_tema::SyntaxTheme>,
}

pub struct ThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<Theme>,
}
```

**Bölüm I çıkış kriteri:** `cargo check -p kvs_tema -p kvs_syntax_tema`
yeşil. Tipler tanımlı (alanları boş olsa bile derleniyor); modül
ağacının iskeleti hazır.

---

## Bölüm II — GPUI'nin tema için kullanılan yüzeyi

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: tema'nın doğrudan
dokunduğu GPUI tipleri — `Hsla`, `Rgba`, `SharedString`, `HighlightStyle`,
`FontStyle`, `FontWeight`, `WindowBackgroundAppearance`, `WindowAppearance`,
`App`, `Context`, `Window`, `Global` trait ve
`refineable::Refineable` derive davranışı. Her tip için: kaynak modül,
kabul ettiği değerler, runtime davranışı, tema-kullanım örneği,
tuzaklar.)_

---

## Bölüm III — Veri sözleşmesi tipleri

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `Theme`, `ThemeStyles`,
`ThemeColors` (tam alan kataloğu gruplar halinde), `StatusColors`,
`PlayerColors`, `AccentColors`, `SystemColors`, `Appearance`, `ThemeFamily`,
`SyntaxTheme`, `IconTheme`.)_

---

## Bölüm IV — JSON şeması katmanı

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `ThemeContent`,
`*Content` tipleri, `try_parse_color`, hata toleransı, JSON anahtar
konvansiyonu.)_

---

## Bölüm V — Refinement katmanı

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: Content → Refinement →
Theme akışı, `theme_colors_refinement`, `apply_status_color_defaults`,
`Theme::from_content`.)_

---

## Bölüm VI — Runtime katmanı

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `ThemeRegistry`,
`GlobalTheme`, `ActiveTheme` trait, `SystemAppearance`, `init()`, tema
değiştirme.)_

---

## Bölüm VII — Varlık ve test

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: fallback tasarımı,
built-in bundling, `AssetSource`, fixture testleri, lisans doğrulama.)_

---

## Bölüm VIII — Tüketim ve dış API

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `cx.theme()` desenleri,
varyantlar, public API kataloğu, test mock'lama.)_

---

## Bölüm IX — Pratik

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: sınama listesi, yaygın
tuzaklar, reçeteler.)_

---

# Ek (geçici): Faz tabanlı eski içerik

> **Not:** Aşağıdaki içerik bölüm bölüm yeni yapıya taşınmaktadır.
> Taşıma tamamlandıkça ilgili alt başlıklar bu ekten kaldırılır. Eski
> referansları kırmamak için geçici olarak korunur.

---

## Faz 1 — Çekirdek tipler

Hedef: Zed'in `crates/theme/src/styles/` altındaki tüm struct'ları
**alan paritesiyle** yansıtmak. Doc comment'lerini kendi sözcüklerinle yaz.

### 1.1 `styles.rs` — modül kökü

```rust
mod accents;
mod colors;
mod players;
mod status;
mod system;

pub use accents::*;
pub use colors::*;
pub use players::*;
pub use status::*;
pub use system::*;
```

### 1.2 `styles/colors.rs` — UI renkleri (~150 alan)

Zed'deki tam liste için `../zed/crates/theme/src/styles/colors.rs`'a bak.
Buradan sıralı **mirror** yap. Aşağıda ilk 30 alan + örnek pattern var.

```rust
use gpui::Hsla;
use refineable::Refineable;

/// UI renk paleti. Alan listesi Zed'in ThemeColors'ı ile birebir paralel.
///
/// Refineable derive, her alanı Option<T> olarak içeren
/// `ThemeColorsRefinement` struct'ını otomatik üretir.
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct ThemeColors {
    // Kenarlıklar -----------------------------------------------------------
    pub border: Hsla,
    pub border_variant: Hsla,
    pub border_focused: Hsla,
    pub border_selected: Hsla,
    pub border_transparent: Hsla,
    pub border_disabled: Hsla,

    // Yüzeyler --------------------------------------------------------------
    pub elevated_surface_background: Hsla,
    pub surface_background: Hsla,
    pub background: Hsla,

    // Etkileşimli element durumları ----------------------------------------
    pub element_background: Hsla,
    pub element_hover: Hsla,
    pub element_active: Hsla,
    pub element_selected: Hsla,
    pub element_selection_background: Hsla,
    pub element_disabled: Hsla,

    pub drop_target_background: Hsla,
    pub drop_target_border: Hsla,

    // Ghost (yüzey rengiyle aynı) elementler -------------------------------
    pub ghost_element_background: Hsla,
    pub ghost_element_hover: Hsla,
    pub ghost_element_active: Hsla,
    pub ghost_element_selected: Hsla,
    pub ghost_element_disabled: Hsla,

    // Metin -----------------------------------------------------------------
    pub text: Hsla,
    pub text_muted: Hsla,
    pub text_placeholder: Hsla,
    pub text_disabled: Hsla,
    pub text_accent: Hsla,

    // Icon ------------------------------------------------------------------
    pub icon: Hsla,
    pub icon_muted: Hsla,
    pub icon_disabled: Hsla,

    // ... (Zed'deki tüm alanları aynı sırayla buraya devam ettir)
    // editor_*, terminal_*, panel_*, status_bar_*, title_bar_*, tab_*,
    // search_*, scrollbar_*, debugger_*, vcs_*, vim_yank_*, ...
}
```

> **Editor / terminal_ansi / debugger / diff hunk / vcs / vim alanları**:
> Uygulamanda henüz karşılığı olmasa bile struct'a **dahil et**. Yoksa
> Zed JSON'unda bu alan geldiğinde sessizce kaybolur veya deserialize
> hatası verebilir. UI'da okumadığın sürece struct'ta bulunması sıfır
> maliyettir. Gerekçenin tamamı için **Temel ilke** bölümüne bak.

### 1.3 `styles/status.rs` — durum renkleri

```rust
use gpui::Hsla;
use refineable::Refineable;

/// Diagnostic ve VCS durum renkleri. Her durum için fg/bg/border üçlüsü.
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct StatusColors {
    pub conflict: Hsla,
    pub conflict_background: Hsla,
    pub conflict_border: Hsla,

    pub created: Hsla,
    pub created_background: Hsla,
    pub created_border: Hsla,

    pub deleted: Hsla,
    pub deleted_background: Hsla,
    pub deleted_border: Hsla,

    pub error: Hsla,
    pub error_background: Hsla,
    pub error_border: Hsla,

    pub hidden: Hsla,
    pub hidden_background: Hsla,
    pub hidden_border: Hsla,

    pub hint: Hsla,
    pub hint_background: Hsla,
    pub hint_border: Hsla,

    pub ignored: Hsla,
    pub ignored_background: Hsla,
    pub ignored_border: Hsla,

    pub info: Hsla,
    pub info_background: Hsla,
    pub info_border: Hsla,

    pub modified: Hsla,
    pub modified_background: Hsla,
    pub modified_border: Hsla,

    pub predictive: Hsla,
    pub predictive_background: Hsla,
    pub predictive_border: Hsla,

    pub renamed: Hsla,
    pub renamed_background: Hsla,
    pub renamed_border: Hsla,

    pub success: Hsla,
    pub success_background: Hsla,
    pub success_border: Hsla,

    pub unreachable: Hsla,
    pub unreachable_background: Hsla,
    pub unreachable_border: Hsla,

    pub warning: Hsla,
    pub warning_background: Hsla,
    pub warning_border: Hsla,
}
```

### 1.4 `styles/players.rs`

```rust
use gpui::Hsla;

#[derive(Clone, Debug, PartialEq)]
pub struct PlayerColor {
    pub cursor: Hsla,
    pub background: Hsla,
    pub selection: Hsla,
}

#[derive(Clone, Debug, PartialEq, Default)]
pub struct PlayerColors(pub Vec<PlayerColor>);

impl PlayerColors {
    /// Yerel (kullanıcı) renk slotu — index 0.
    pub fn local(&self) -> PlayerColor {
        self.0.first().cloned().unwrap_or(PlayerColor {
            cursor: gpui::black(),
            background: gpui::black(),
            selection: gpui::black().opacity(0.3),
        })
    }

    /// Belirli bir player slotu (collab veya örnek).
    pub fn color_for_participant(&self, participant_index: u32) -> PlayerColor {
        let len = self.0.len().max(1);
        let idx = (participant_index as usize) % len;
        self.0
            .get(idx)
            .cloned()
            .unwrap_or_else(|| self.local())
    }
}
```

### 1.5 `styles/accents.rs`

```rust
use gpui::Hsla;

#[derive(Clone, Debug, PartialEq, Default)]
pub struct AccentColors(pub Vec<Hsla>);

impl AccentColors {
    pub fn color_for(&self, index: u32) -> Hsla {
        if self.0.is_empty() {
            return gpui::blue();
        }
        let idx = (index as usize) % self.0.len();
        self.0[idx]
    }
}
```

### 1.6 `styles/system.rs`

```rust
use gpui::{Hsla, hsla};

/// Tema-bağımsız sistem renkleri (macOS mavi vs).
#[derive(Clone, Debug, PartialEq)]
pub struct SystemColors {
    pub transparent: Hsla,
    pub mac_os_traffic_light_red: Hsla,
    pub mac_os_traffic_light_yellow: Hsla,
    pub mac_os_traffic_light_green: Hsla,
}

impl Default for SystemColors {
    fn default() -> Self {
        Self {
            transparent: hsla(0., 0., 0., 0.),
            mac_os_traffic_light_red: hsla(0.0139, 0.79, 0.65, 1.0),
            mac_os_traffic_light_yellow: hsla(0.0986, 0.84, 0.62, 1.0),
            mac_os_traffic_light_green: hsla(0.3194, 0.49, 0.55, 1.0),
        }
    }
}
```

### 1.7 `kvs_syntax_tema/src/kvs_syntax_tema.rs`

```rust
use gpui::HighlightStyle;
use std::sync::Arc;

/// Sözdizimi (token) renkleri. Sıralı liste; ilk eşleşme kazanır.
#[derive(Clone, Debug, PartialEq, Default)]
pub struct SyntaxTheme {
    pub highlights: Vec<(String, HighlightStyle)>,
}

impl SyntaxTheme {
    pub fn new(highlights: Vec<(String, HighlightStyle)>) -> Arc<Self> {
        Arc::new(Self { highlights })
    }

    pub fn style_for(&self, capture: &str) -> Option<HighlightStyle> {
        self.highlights
            .iter()
            .find(|(name, _)| name == capture)
            .map(|(_, style)| *style)
    }
}
```

**Faz 1 çıkış kriteri**: `cargo build -p kvs_tema` yeşil. Henüz JSON yok,
ama tip iskeleti ve refinement türleri (`ThemeColorsRefinement`,
`StatusColorsRefinement`) oluşmuş durumda. Bunu doğrula:

```rust
// tests'te
let _: kvs_tema::ThemeColorsRefinement = Default::default();
```

---

## Faz 2 — JSON şeması ve refinement

Bu fazın hedefi: bir Zed temasını (`one-dark.json` gibi) **birebir parse
edip** çalışan bir `Theme` üretmek.

### 2.1 JSON anahtar konvansiyonu

Zed JSON dosyalarında alan adları **dot-separated** (`border.variant`,
`element.hover`). Rust alan adları snake_case (`border_variant`). İkisini
`#[serde(rename = "...")]` ile bağlarsın.

```json
// one-dark.json (kısaltılmış)
{
  "name": "One",
  "author": "Zed Industries",
  "themes": [
    {
      "name": "One Dark",
      "appearance": "dark",
      "style": {
        "background": "#1c2025ff",
        "border": "#464b57ff",
        "border.variant": "#363c46ff",
        "element.hover": "#363c4680",
        "text": "#c8ccd4ff",
        "syntax": {
          "comment": { "color": "#8b9eb999", "font_style": "italic" },
          "string": { "color": "#a1c181ff" }
        }
      }
    }
  ]
}
```

### 2.2 `schema.rs` — Content tipleri

JSON sözleşmesi **opsiyonel string** renklerden oluşur. Sıkı tipli `Hsla` değil
— çünkü kullanıcı her alanı yazmak zorunda değil ve renk parse hatası tüm
temayı bozmamalı.

```rust
use indexmap::IndexMap;
use schemars::JsonSchema;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AppearanceContent {
    Light,
    Dark,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ThemeFamilyContent {
    pub name: String,
    pub author: String,
    pub themes: Vec<ThemeContent>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct ThemeContent {
    pub name: String,
    pub appearance: AppearanceContent,
    pub style: ThemeStyleContent,
}

/// `ThemeStyleContent` JSON'da düz (flat) görünür; renk grupları flatten ile
/// aynı seviyeye açılır.
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct ThemeStyleContent {
    #[serde(rename = "background.appearance", default)]
    pub window_background_appearance: Option<WindowBackgroundContent>,

    #[serde(default)]
    pub accents: Vec<Option<String>>,

    #[serde(flatten, default)]
    pub colors: ThemeColorsContent,

    #[serde(flatten, default)]
    pub status: StatusColorsContent,

    #[serde(default)]
    pub players: Vec<PlayerColorContent>,

    #[serde(default)]
    pub syntax: IndexMap<String, HighlightStyleContent>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum WindowBackgroundContent {
    Opaque,
    Transparent,
    Blurred,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    #[serde(rename = "border")]
    pub border: Option<String>,

    #[serde(rename = "border.variant")]
    pub border_variant: Option<String>,

    #[serde(rename = "border.focused")]
    pub border_focused: Option<String>,

    // ... Zed'in ThemeColorsContent'inin tüm alanlarını
    //     aynı serde(rename) anahtarlarıyla mirror et.
    //     Kaynak: ../zed/crates/settings_content/src/theme.rs:512
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct StatusColorsContent {
    pub conflict: Option<String>,
    pub conflict_background: Option<String>,
    pub conflict_border: Option<String>,

    pub created: Option<String>,
    pub created_background: Option<String>,
    pub created_border: Option<String>,

    // ... tüm status grupları
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct PlayerColorContent {
    pub cursor: Option<String>,
    pub background: Option<String>,
    pub selection: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct HighlightStyleContent {
    pub color: Option<String>,
    #[serde(default, deserialize_with = "treat_error_as_none")]
    pub background_color: Option<String>,
    #[serde(default, deserialize_with = "treat_error_as_none")]
    pub font_style: Option<FontStyleContent>,
    #[serde(default, deserialize_with = "treat_error_as_none")]
    pub font_weight: Option<FontWeightContent>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum FontStyleContent {
    Normal,
    Italic,
    Oblique,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct FontWeightContent(pub f32);

/// JSON deserializer'ları için: bilinmeyen değer hatasını None'a çevir.
/// Örnek: kullanıcı `font_weight: "bold"` yazsa bile parse devam etsin.
fn treat_error_as_none<'de, T, D>(deserializer: D) -> Result<Option<T>, D::Error>
where
    T: serde::Deserialize<'de>,
    D: serde::Deserializer<'de>,
{
    let value: serde_json::Value = serde::Deserialize::deserialize(deserializer)?;
    Ok(T::deserialize(value).ok())
}
```

> **`deny_unknown_fields` KULLANMA**. Zed yeni alan ekler, sen henüz mirror
> etmediysen tüm tema yüklenmesi patlar. Strict olmayan kalmak hayat
> kurtarır.

### 2.3 Renk parser — `schema.rs` devamı

```rust
use gpui::Hsla;
use palette::FromColor;

/// `"#1c2025ff"` → `Hsla`. Hata olursa Err döner; çağıran tarafta
/// `Option<Hsla>` olarak yutuluyor.
pub fn try_parse_color(s: &str) -> anyhow::Result<Hsla> {
    let rgba = gpui::Rgba::try_from(s)?;
    let srgba = palette::rgb::Srgba::from_components((rgba.r, rgba.g, rgba.b, rgba.a));
    let hsla = palette::Hsla::from_color(srgba);

    Ok(gpui::hsla(
        hsla.hue.into_positive_degrees() / 360.0,
        hsla.saturation,
        hsla.lightness,
        hsla.alpha,
    ))
}
```

### 2.4 `refinement.rs` — Content → Refinement → Theme

Bu modülün işi: opsiyonel string renkleri olan `Content` tipini, opsiyonel
`Hsla` alanları olan `Refinement` tipine çevirmek. Sonra runtime tarafı
`baseline.refined(refinement)` ile birleştirir.

```rust
use crate::{
    schema::{try_parse_color, StatusColorsContent, ThemeColorsContent},
    StatusColorsRefinement, ThemeColorsRefinement,
};

/// Bir renk string'i Some(Hsla) ise parse et, parse hatası olursa None.
fn color(s: &Option<String>) -> Option<gpui::Hsla> {
    s.as_deref().and_then(|s| try_parse_color(s).ok())
}

pub fn theme_colors_refinement(c: &ThemeColorsContent) -> ThemeColorsRefinement {
    ThemeColorsRefinement {
        border: color(&c.border),
        border_variant: color(&c.border_variant),
        border_focused: color(&c.border_focused),
        // ... her alan için aynı tek-satır kalıbı
        ..Default::default()
    }
}

pub fn status_colors_refinement(c: &StatusColorsContent) -> StatusColorsRefinement {
    StatusColorsRefinement {
        conflict: color(&c.conflict),
        conflict_background: color(&c.conflict_background),
        conflict_border: color(&c.conflict_border),
        created: color(&c.created),
        created_background: color(&c.created_background),
        // ... tüm alanlar
        ..Default::default()
    }
}
```

### 2.5 Türetme: foreground'dan background

Zed kullanıcısı bir renk için sadece foreground verdiyse, background'u
%25 alpha'lı versiyondan **türetmek** beklenir:

```rust
use crate::StatusColorsRefinement;

/// Status renkleri için foreground varsa ve background yoksa,
/// background'u foreground'un %25 alpha'lı kopyası olarak türet.
pub fn apply_status_color_defaults(r: &mut StatusColorsRefinement) {
    let pairs: &mut [(&mut Option<_>, &mut Option<_>)] = &mut [
        (&mut r.deleted, &mut r.deleted_background),
        (&mut r.created, &mut r.created_background),
        (&mut r.modified, &mut r.modified_background),
        (&mut r.conflict, &mut r.conflict_background),
        (&mut r.error, &mut r.error_background),
        (&mut r.hidden, &mut r.hidden_background),
    ];

    for (fg, bg) in pairs {
        if bg.is_none()
            && let Some(fg) = fg.as_ref()
        {
            **bg = Some(fg.opacity(0.25));
        }
    }
}
```

> Türetme kuralları olmadan kullanıcı temaları yarı-boş yüklenir (bg alanları
> baseline'dan gelir, fg değişmiş ama bg eski temaya ait kalır). Bu Zed'in
> beklenen davranışıyla **birebir tutmak gerek**.

### 2.6 `Theme::from_content` — birleşik akış

```rust
use std::sync::Arc;
use gpui::{HighlightStyle, SharedString, WindowBackgroundAppearance};
use refineable::Refineable;
use kvs_syntax_tema::SyntaxTheme;

use crate::{
    refinement::{
        apply_status_color_defaults, status_colors_refinement, theme_colors_refinement,
    },
    schema::{
        try_parse_color, AppearanceContent, FontStyleContent, FontWeightContent,
        HighlightStyleContent, ThemeContent, WindowBackgroundContent,
    },
    Appearance, AccentColors, PlayerColor, PlayerColors, Theme, ThemeStyles,
};

impl Theme {
    /// Bir Zed-uyumlu `ThemeContent`'i, baseline tema üzerine bindirerek
    /// tam bir `Theme`'e dönüştürür.
    pub fn from_content(content: ThemeContent, baseline: &Theme) -> Self {
        let appearance = match content.appearance {
            AppearanceContent::Light => Appearance::Light,
            AppearanceContent::Dark => Appearance::Dark,
        };

        let mut color_refinement = theme_colors_refinement(&content.style.colors);
        let mut status_refinement = status_colors_refinement(&content.style.status);
        apply_status_color_defaults(&mut status_refinement);

        let mut colors = baseline.styles.colors.clone();
        colors.refine(&color_refinement);

        let mut status = baseline.styles.status.clone();
        status.refine(&status_refinement);

        let accents = if content.style.accents.is_empty() {
            baseline.styles.accents.clone()
        } else {
            AccentColors(
                content
                    .style
                    .accents
                    .iter()
                    .filter_map(|c| c.as_deref().and_then(|s| try_parse_color(s).ok()))
                    .collect(),
            )
        };

        let player = if content.style.players.is_empty() {
            baseline.styles.player.clone()
        } else {
            PlayerColors(
                content
                    .style
                    .players
                    .iter()
                    .map(|p| PlayerColor {
                        cursor: p
                            .cursor
                            .as_deref()
                            .and_then(|s| try_parse_color(s).ok())
                            .unwrap_or(baseline.styles.player.local().cursor),
                        background: p
                            .background
                            .as_deref()
                            .and_then(|s| try_parse_color(s).ok())
                            .unwrap_or(baseline.styles.player.local().background),
                        selection: p
                            .selection
                            .as_deref()
                            .and_then(|s| try_parse_color(s).ok())
                            .unwrap_or(baseline.styles.player.local().selection),
                    })
                    .collect(),
            )
        };

        let syntax_highlights = content
            .style
            .syntax
            .iter()
            .map(|(name, style)| (name.clone(), highlight_style(style)))
            .collect();

        let syntax = SyntaxTheme::new(syntax_highlights);

        let window_background_appearance = match content.style.window_background_appearance {
            Some(WindowBackgroundContent::Opaque) => WindowBackgroundAppearance::Opaque,
            Some(WindowBackgroundContent::Transparent) => WindowBackgroundAppearance::Transparent,
            Some(WindowBackgroundContent::Blurred) => WindowBackgroundAppearance::Blurred,
            None => baseline.styles.window_background_appearance,
        };

        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name: SharedString::from(content.name),
            appearance,
            styles: ThemeStyles {
                window_background_appearance,
                system: baseline.styles.system.clone(),
                colors,
                status,
                player,
                accents,
                syntax,
            },
        }
    }
}

fn highlight_style(s: &HighlightStyleContent) -> HighlightStyle {
    HighlightStyle {
        color: s.color.as_deref().and_then(|s| try_parse_color(s).ok()),
        background_color: s
            .background_color
            .as_deref()
            .and_then(|s| try_parse_color(s).ok()),
        font_style: s.font_style.map(|fs| match fs {
            FontStyleContent::Normal => gpui::FontStyle::Normal,
            FontStyleContent::Italic => gpui::FontStyle::Italic,
            FontStyleContent::Oblique => gpui::FontStyle::Oblique,
        }),
        font_weight: s.font_weight.map(|w| gpui::FontWeight(w.0)),
        ..Default::default()
    }
}
```

### 2.7 Fixture testi — kritik kontrol noktası

`tests/fixtures/`'a Zed'den gerçek bir tema kopyala (Zed'in
`assets/themes/one/one.json`'u **MIT lisanslı** — `assets/themes/LICENSE_*`
dosyalarını kontrol et).

```rust
// tests/parse_fixture.rs
use kvs_tema::{schema::ThemeFamilyContent, Theme};

fn baseline() -> Theme {
    kvs_tema::fallback::kvs_default_dark()
}

#[test]
fn parses_zed_one_dark() {
    let json = include_str!("fixtures/one-dark.json");
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json)
        .expect("Zed one.json deserialize edilemedi");

    let baseline = baseline();
    for theme_content in family.themes {
        let theme = Theme::from_content(theme_content, &baseline);
        assert!(!theme.name.is_empty());
        // Baseline'dan gelen değerlerin bozulmadığını kontrol et:
        assert_ne!(theme.styles.colors.background, gpui::black());
    }
}

#[test]
fn unknown_field_does_not_break() {
    let json = r#"{
        "name": "Test",
        "author": "x",
        "themes": [{
            "name": "T",
            "appearance": "dark",
            "style": {
                "background": "#000000ff",
                "future.unknown.field": "#ffffffff"
            }
        }]
    }"#;
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
    let _ = Theme::from_content(family.themes.into_iter().next().unwrap(), &baseline());
}
```

**Faz 2 çıkış kriteri**:
- Zed'in `one-dark.json`'u parse oluyor, panic yok.
- Bilinmeyen alan tüm temayı bozmuyor.
- Sadece fg verilen status renkleri için bg türetiliyor.

---

## Faz 3 — Runtime ve global tema

Burada **özgürsün** — Zed'in `theme_settings`'sini taşımak zorunda değilsin.

### 3.1 `registry.rs`

```rust
use crate::Theme;
use collections::HashMap;
use gpui::{App, Global, SharedString};
use parking_lot::RwLock;
use std::sync::Arc;
use thiserror::Error;

#[derive(Debug, Error)]
#[error("tema bulunamadı: {0}")]
pub struct ThemeNotFound(pub SharedString);

pub struct ThemeRegistry {
    themes: RwLock<HashMap<SharedString, Arc<Theme>>>,
}

#[derive(Default)]
struct GlobalThemeRegistry(Arc<ThemeRegistry>);
impl Global for GlobalThemeRegistry {}

impl ThemeRegistry {
    pub fn new() -> Self {
        Self {
            themes: RwLock::new(HashMap::default()),
        }
    }

    pub fn global(cx: &App) -> Arc<Self> {
        cx.global::<GlobalThemeRegistry>().0.clone()
    }

    pub fn set_global(cx: &mut App, registry: Arc<Self>) {
        cx.set_global(GlobalThemeRegistry(registry));
    }

    pub fn insert(&self, theme: Theme) {
        self.themes
            .write()
            .insert(theme.name.clone(), Arc::new(theme));
    }

    pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFound> {
        self.themes
            .read()
            .get(name)
            .cloned()
            .ok_or_else(|| ThemeNotFound(name.to_string().into()))
    }

    pub fn list_names(&self) -> Vec<SharedString> {
        let mut names: Vec<_> = self.themes.read().keys().cloned().collect();
        names.sort();
        names
    }
}
```

### 3.2 `runtime.rs` — Global ve ActiveTheme

```rust
use crate::{registry::ThemeRegistry, Appearance, Theme};
use gpui::{App, BorrowAppContext, Global, WindowAppearance};
use std::sync::Arc;

pub struct GlobalTheme {
    theme: Arc<Theme>,
}
impl Global for GlobalTheme {}

impl GlobalTheme {
    pub fn theme(cx: &App) -> &Arc<Theme> {
        &cx.global::<Self>().theme
    }

    pub fn set_theme(cx: &mut App, theme: Arc<Theme>) {
        if cx.has_global::<Self>() {
            cx.update_global::<Self, _>(|this, _| this.theme = theme);
        } else {
            cx.set_global(Self { theme });
        }
    }
}

/// `cx.theme().colors().background` kullanımını mümkün kılan trait.
pub trait ActiveTheme {
    fn theme(&self) -> &Arc<Theme>;
}

impl ActiveTheme for App {
    fn theme(&self) -> &Arc<Theme> {
        GlobalTheme::theme(self)
    }
}

#[derive(Clone, Copy)]
pub struct SystemAppearance(pub Appearance);

struct GlobalSystemAppearance(SystemAppearance);
impl Global for GlobalSystemAppearance {}

impl SystemAppearance {
    pub fn init(cx: &mut App) {
        let appearance = match cx.window_appearance() {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
        };
        cx.set_global(GlobalSystemAppearance(SystemAppearance(appearance)));
    }

    pub fn global(cx: &App) -> Self {
        cx.global::<GlobalSystemAppearance>().0
    }
}

/// Tema sistemini başlat: registry kur, fallback temayı yükle, aktif yap.
pub fn init(cx: &mut App) {
    SystemAppearance::init(cx);

    let registry = Arc::new(ThemeRegistry::new());
    registry.insert(crate::fallback::kvs_default_dark());
    registry.insert(crate::fallback::kvs_default_light());

    let default = registry
        .get("Kvs Default Dark")
        .expect("default tema kayıtlı olmalı");

    ThemeRegistry::set_global(cx, registry);
    GlobalTheme::set_theme(cx, default);
}
```

### 3.3 Settings köprüsü (örnek)

```rust
// kvs_ui'nin kendi config sisteminde:
#[derive(serde::Deserialize)]
pub struct AyarlarTema {
    pub ad: String,
}

pub fn ayarlardan_tema_uygula(ayar: &AyarlarTema, cx: &mut gpui::App) -> anyhow::Result<()> {
    let registry = kvs_tema::ThemeRegistry::global(cx);
    let theme = registry.get(&ayar.ad)?;
    kvs_tema::GlobalTheme::set_theme(cx, theme);
    Ok(())
}
```

**Faz 3 çıkış kriteri**: Bir GPUI uygulamasında `cx.theme().colors().background`
çağrısı çalışıyor; `ayarlardan_tema_uygula` ile değiştirilebiliyor.

---

## Faz 4 — Built-in temalar

### 4.1 Kendi fallback'in — `fallback.rs`

Zed'in `fallback_themes.rs`'sini **birebir kopyalama**. Aynı paleti aynı
HSL değerleriyle yazmak telif riski. Kendi paletini seç. Aşağıda örnek bir
"kvs default dark":

```rust
use std::sync::Arc;
use gpui::{hsla, Hsla, WindowBackgroundAppearance};
use kvs_syntax_tema::SyntaxTheme;

use crate::{
    AccentColors, Appearance, PlayerColor, PlayerColors, StatusColors,
    SystemColors, Theme, ThemeColors, ThemeStyles,
};

pub fn kvs_default_dark() -> Theme {
    let bg = hsla(220.0 / 360.0, 0.10, 0.12, 1.0);
    let surface = hsla(220.0 / 360.0, 0.10, 0.15, 1.0);
    let elevated = hsla(220.0 / 360.0, 0.10, 0.18, 1.0);
    let text = hsla(220.0 / 360.0, 0.05, 0.92, 1.0);
    let text_muted = hsla(220.0 / 360.0, 0.05, 0.65, 1.0);
    let border = hsla(220.0 / 360.0, 0.10, 0.25, 1.0);
    let accent = hsla(210.0 / 360.0, 0.75, 0.60, 1.0);

    Theme {
        id: "kvs-default-dark".into(),
        name: "Kvs Default Dark".into(),
        appearance: Appearance::Dark,
        styles: ThemeStyles {
            window_background_appearance: WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors {
                background: bg,
                surface_background: surface,
                elevated_surface_background: elevated,
                border,
                border_variant: border.opacity(0.5),
                border_focused: accent,
                border_selected: accent.opacity(0.5),
                border_transparent: hsla(0., 0., 0., 0.),
                border_disabled: border.opacity(0.3),
                element_background: surface,
                element_hover: elevated,
                element_active: elevated.opacity(0.8),
                element_selected: accent.opacity(0.3),
                element_selection_background: accent.opacity(0.25),
                element_disabled: surface.opacity(0.5),
                ghost_element_background: hsla(0., 0., 0., 0.),
                ghost_element_hover: elevated,
                ghost_element_active: elevated.opacity(0.8),
                ghost_element_selected: accent.opacity(0.3),
                ghost_element_disabled: hsla(0., 0., 0., 0.),
                drop_target_background: accent.opacity(0.2),
                drop_target_border: accent,
                text,
                text_muted,
                text_placeholder: text_muted.opacity(0.7),
                text_disabled: text_muted.opacity(0.5),
                text_accent: accent,
                icon: text,
                icon_muted: text_muted,
                icon_disabled: text_muted.opacity(0.5),
                // ... kalan tüm alanlar için makul default'lar
            },
            status: status_colors_dark(),
            player: PlayerColors(vec![PlayerColor {
                cursor: accent,
                background: accent.opacity(0.2),
                selection: accent.opacity(0.3),
            }]),
            accents: AccentColors(vec![accent]),
            syntax: SyntaxTheme::new(vec![]),
        },
    }
}

fn status_colors_dark() -> StatusColors {
    let red = hsla(0.0 / 360.0, 0.7, 0.6, 1.0);
    let green = hsla(140.0 / 360.0, 0.45, 0.55, 1.0);
    let yellow = hsla(45.0 / 360.0, 0.85, 0.6, 1.0);
    let blue = hsla(210.0 / 360.0, 0.7, 0.6, 1.0);

    StatusColors {
        error: red,
        error_background: red.opacity(0.2),
        error_border: red.opacity(0.5),
        warning: yellow,
        warning_background: yellow.opacity(0.2),
        warning_border: yellow.opacity(0.5),
        info: blue,
        info_background: blue.opacity(0.2),
        info_border: blue.opacity(0.5),
        success: green,
        success_background: green.opacity(0.2),
        success_border: green.opacity(0.5),
        // ... kalan status alanları için aynı kalıp
        ..unsafe { std::mem::zeroed() } // GERÇEK KODDA: tüm alanları doldur
    }
}

pub fn kvs_default_light() -> Theme {
    // Aynı yapıyı light paletiyle yaz.
    todo!()
}
```

> Yukarıdaki `unsafe { std::mem::zeroed() }` **sadece şablon**. Gerçek kodda
> `StatusColors`'ın tüm alanlarını açık değerle doldur — `zeroed()`
> `Hsla(0,0,0,0)` üretir ki bu UI'da görünmez.

### 4.2 Opsiyonel: Zed JSON bundling

Zed'in built-in temalarını **kullanıcına sunmak** istiyorsan:

1. `../zed/assets/themes/LICENSE_GPL` veya `LICENSE_APACHE` dosyalarını oku —
   her tema kendi alt klasöründe ayrı lisansa sahip olabilir. **MIT lisanslı
   olanları seç**.
2. Seçtiğin JSON'ları `kvs_ui/assets/themes/` altına kopyala.
3. Lisans dosyalarını da kopyala ve kaynağı belirt.
4. Yükleme:

```rust
pub fn load_bundled_themes(registry: &kvs_tema::ThemeRegistry) -> anyhow::Result<()> {
    let baseline = kvs_tema::fallback::kvs_default_dark();
    let entries = std::fs::read_dir("assets/themes")?;
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().is_some_and(|e| e == "json") {
            let bytes = std::fs::read(&path)?;
            let family: kvs_tema::ThemeFamilyContent =
                serde_json_lenient::from_slice(&bytes)?;
            for theme_content in family.themes {
                registry.insert(kvs_tema::Theme::from_content(theme_content, &baseline));
            }
        }
    }
    Ok(())
}
```

---

## Faz 5 — UI tüketim örnekleri

### 5.1 `ActiveTheme` ile element renklendirme

```rust
use gpui::{div, prelude::*, App, Window, Context};
use kvs_tema::ActiveTheme;

struct AnaPanel;

impl Render for AnaPanel {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let tema = cx.theme();
        div()
            .bg(tema.colors.background)
            .text_color(tema.colors.text)
            .border_1()
            .border_color(tema.colors.border)
            .p_4()
            .child("Merhaba")
    }
}
```

### 5.2 Hover/aktif durum

```rust
div()
    .bg(cx.theme().colors.element_background)
    .hover(|s| s.bg(cx.theme().colors.element_hover))
    .active(|s| s.bg(cx.theme().colors.element_active))
```

### 5.3 Tema değiştirme

```rust
fn temayi_degistir(ad: &str, cx: &mut gpui::App) -> anyhow::Result<()> {
    let registry = kvs_tema::ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;
    kvs_tema::GlobalTheme::set_theme(cx, yeni);
    // Görünüm güncellemesi için view'ları notify et:
    cx.refresh_windows();
    Ok(())
}
```

### 5.4 Sistem açık/koyu mod takibi

```rust
pub fn sistemden_tema_sec(cx: &mut gpui::App) -> anyhow::Result<()> {
    let registry = kvs_tema::ThemeRegistry::global(cx);
    let ad = match kvs_tema::SystemAppearance::global(cx).0 {
        kvs_tema::Appearance::Dark => "Kvs Default Dark",
        kvs_tema::Appearance::Light => "Kvs Default Light",
    };
    kvs_tema::GlobalTheme::set_theme(cx, registry.get(ad)?);
    Ok(())
}
```

---

## Sınama listesi

Faz bittiğinde **her seferinde** bu listeyi gez:

- [ ] `cargo build -p kvs_tema -p kvs_syntax_tema` yeşil.
- [ ] `cargo clippy --all-targets -- -D warnings` yeşil.
- [ ] `tests/fixtures/one-dark.json` parse oluyor, panic yok.
- [ ] Bilinmeyen JSON alanı tüm temayı bozmuyor.
- [ ] Sadece fg verilen status renkleri için bg türetiliyor.
- [ ] `cx.theme().colors.background` örnek bir GPUI uygulamasında çalışıyor.
- [ ] `set_theme` ile değiştirme sonrası `cx.refresh_windows()` ile UI güncelleniyor.
- [ ] `tema_aktarimi.md`'deki pin hâlâ izlenen yollardaki HEAD'e yakın.

---

## Yaygın tuzaklar

1. **`#[serde(deny_unknown_fields)]` kullanmak**
   Zed yeni alan ekler, sen henüz mirror etmediysen tüm yüklemeler patlar.
   Asla kullanma.

2. **JSON'da nokta ayrımı yerine snake_case beklemek**
   Zed JSON'unda `border.variant` yazıyor; `#[serde(rename = "border.variant")]`
   şart. `border_variant` koyarsan alan sessizce boş kalır.

3. **`color.opacity(x)` yerine `color.alpha = x` yazmak**
   GPUI'de `Hsla.a` alanı public; ama `opacity(x)` çağırmak okunabilirlik
   için tercih edilir. İkisi de aynı sonucu verir.

4. **Türetme adımını atlayıp `refine`'a doğrudan gitmek**
   Status'ta kullanıcı sadece `created` verirse `created_background`
   baseline'dan gelir — kullanıcı temasıyla uyumsuz koyu/açık karışım çıkar.
   `apply_status_color_defaults` şart.

5. **Bir alan grubunu "şimdilik gerek yok" diye struct'tan çıkarmak**
   `terminal_ansi`, debugger, diff hunk, vcs, vim, icon theme — UI'da
   okumasan bile struct'ta bulunmalı (bkz. **Temel ilke**). Aksi takdirde
   Zed JSON'unda o alan geldiğinde sessizce kaybolur ve bir sonraki sync
   turunda fixture testleri anlamsız hatalarla patlar.

6. **`refineable` dep'ini fork'lamadan production'a gitmek**
   `publish = false` olduğu için crates.io dağıtımı yapamazsın. Erken
   karara bağla: ya vendor'la (kopyala) ya da fork'undan path/git dep.

7. **`Theme`'i `Clone` her yerde**
   `Theme` ~150 `Hsla` alanı içerir — `Arc<Theme>` kullan ve handle olarak
   geçir. `GlobalTheme` zaten `Arc<Theme>` tutuyor.

8. **`palette` versiyonunu Zed'le aynı tutmamak**
   `try_parse_color` Zed davranışına uymalı. `palette` major sürüm farkı,
   renkleri ufak miktarda kaydırabilir. Pin'i takip et.

9. **`cx.notify()` yerine `cx.refresh_windows()` çağırmamak**
   Tema değişikliği global state'i etkiler; her view'ı tek tek notify etmek
   pratik değil. `refresh_windows` tüm pencerelerin yeniden çizilmesini
   sağlar.

10. **Lisans hatırlatması: fallback paleti**
    Zed'in `default_colors.rs`'sindeki HSL değerlerini birebir taşıma.
    Kendi paletini tasarla; Tailwind, Catppuccin gibi açık-lisanslı
    paletlerden esinlenebilirsin.
