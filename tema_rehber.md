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
7. Metin/font tipleri: `SharedString`, `HighlightStyle`, `FontStyle`, `FontWeight`
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

Tema sistemi GPUI'nin tip yüzeyinin **dar bir alt kümesini** kullanır.
Bu bölüm, dokunduğun her tipi tek yerde toplar: hangi modülden geldiği,
kabul ettiği değerler, runtime davranışı, tema-içi kullanım deseni ve
yaygın tuzaklar.

---

### 6. Renk tipleri: `Hsla`, `Rgba` ve constructor'lar

**Kaynak:** `gpui::color` (re-export'lu:
`use gpui::{Hsla, Rgba, hsla, rgb, rgba};`).

GPUI'nin iki temel renk tipi var; tema sözleşmesi **`Hsla`'yı birinci
sınıf** kabul eder.

**`Hsla`** — Hue/Saturation/Lightness/Alpha:

```rust
pub struct Hsla {
    pub h: f32,  // 0.0 .. 1.0 — normalize hue (0=kırmızı, 1/3=yeşil, 2/3=mavi)
    pub s: f32,  // 0.0 .. 1.0 — doygunluk
    pub l: f32,  // 0.0 .. 1.0 — açıklık (0=siyah, 0.5=salt renk, 1=beyaz)
    pub a: f32,  // 0.0 .. 1.0 — alpha
}
```

> **Hue 0-1 aralığı, 0-360° değil.** CSS'ten alıştığın
> `hsl(210, 75%, 60%)` Rust'ta `hsla(210.0 / 360.0, 0.75, 0.60, 1.0)`
> olur. En yaygın hata bu.

**`Rgba`** — sRGB renk uzayı (genelde hex parse'tan üretilir):

```rust
pub struct Rgba { pub r: f32, pub g: f32, pub b: f32, pub a: f32 }
```

**Constructor tablosu:**

| Çağrı | Sonuç | Notlar |
|-------|-------|--------|
| `hsla(h, s, l, a)` | `Hsla` | Free function, en yaygın yol. |
| `rgb(0xff0000)` | `Rgba` | 24-bit RGB; alpha 1.0. |
| `rgba(0xff000080)` | `Rgba` | 32-bit RGBA; son byte alpha. |
| `opaque_grey(0.5, 1.0)` | `Hsla` | `(lightness, alpha)`. |
| `Rgba::try_from("#1c2025ff")` | `Result<Rgba>` | Hex parse; alpha eksik ise 1.0. |
| `black()`, `white()` | `Hsla` | `(0,0,0,1)` / `(0,0,1,1)`. |
| `transparent_black()` | `Hsla` | `(0,0,0,0)` — gradient ucu için ideal. |
| `transparent_white()` | `Hsla` | `(0,0,1,0)`. |
| `red()`, `blue()`, `yellow()` | `Hsla` | Doygun temel renkler (lightness 0.5). |
| `green()` | `Hsla` | **Lightness 0.25** — diğerlerinden farklı (koyu yeşil). |

**`Hsla` metotları (sık kullanılanlar):**

- `color.opacity(0.5) -> Hsla` — alpha'yı `* factor` ile çarpar; yeni
  `Hsla` döner.
- `color.alpha(0.3) -> Hsla` — alpha'yı doğrudan **set** eder.
- `color.fade_out(0.3)` — in-place alpha azaltma (`&mut self`).
- `color.blend(other) -> Hsla` — pre-multiplied alpha karışım.
- `color.grayscale() -> Hsla` — doygunluğu sıfırlar.
- `color.to_rgb() -> Rgba` — Hsla → Rgba.
- `color.is_transparent()`, `color.is_opaque()` — alpha kontrolü.

**Renk parse boru hattı (`try_parse_color`):**

```rust
pub fn try_parse_color(s: &str) -> anyhow::Result<Hsla> {
    let rgba = gpui::Rgba::try_from(s)?;                       // 1. hex → Rgba
    let srgba = palette::rgb::Srgba::from_components(
        (rgba.r, rgba.g, rgba.b, rgba.a)
    );                                                          // 2. Rgba → palette::Srgba
    let hsla = palette::Hsla::from_color(srgba);               // 3. sRGB → HSL
    Ok(gpui::hsla(
        hsla.hue.into_positive_degrees() / 360.0,              // 4. palette HSL → gpui Hsla
        hsla.saturation,
        hsla.lightness,
        hsla.alpha,
    ))
}
```

Üç katman çevirme: GPUI `Rgba` → palette `Srgba` → palette `Hsla` →
GPUI `Hsla`. Orta katman `palette` crate'i gerekli çünkü GPUI Rgba'dan
Hsla'ya direkt convert sağlamaz.

**Tema'da kullanım:**

```rust
pub struct ThemeColors {
    pub background: Hsla,
    pub border: Hsla,
    // ...
}
```

Tüm renk alanları `Hsla`. JSON'da string olarak gelen renkler
`try_parse_color` üzerinden `Hsla`'ya çevrilir.

**Tuzaklar:**

1. **Hue 0-360 yazmak**: `hsla(210.0, ...)` derken aslında `210 mod 1 =
   0` (kırmızıya yakın) hesaplanır. **Mutlaka `/ 360.0`** ile böl.
2. **`Default::default()` görünmez**: `Hsla::default()` = `(0, 0, 0, 0)`.
   UI'da hiçbir şey görünmez. Status renklerinde
   `unsafe { std::mem::zeroed() }` ile struct doldurmak da aynı tuzağa
   düşer.
3. **`opacity` vs `alpha`**: `opacity(0.5)` mevcut alpha'yı `0.5 ile çarpar`;
   `alpha(0.5)` direkt 0.5'e set eder. Yarı şeffaftan tam şeffaf yapmak
   için `opacity(0)` çalışmaz, `alpha(0)` veya `transparent_black()`
   gerekir.
4. **`green()` farklı**: Lightness 0.5 yerine 0.25; fallback renkler
   oluştururken bunu göz önünde bulundur.
5. **sRGB ↔ HSL kayması**: Aynı hex iki farklı `palette` major
   versiyonunda ufak miktarda farklı `Hsla` üretebilir. Fixture
   testleriyle doğrula; `palette` versiyonunu pin'le.

---

### 7. Metin/font tipleri: `SharedString`, `HighlightStyle`, `FontStyle`, `FontWeight`

#### `SharedString`

**Kaynak:** `gpui::SharedString` (alt seviyede `gpui_shared_string` crate).

`Arc<str>` veya `&'static str` taşıyan **ucuz klonlanan** immutable string.
Render her frame yeniden çalıştığı için `String::clone()` her seferinde
allocation; `SharedString::clone()` sadece `Arc` refcount artırır.

**Constructor'lar:**

```rust
let a: SharedString = "kvs default dark".into();              // From<&str>
let b: SharedString = SharedString::from("kvs default");      // From<&str>
let c: SharedString = String::from("dynamic").into();         // From<String>
let d: SharedString = std::borrow::Cow::Borrowed("x").into(); // From<Cow<str>>
```

**Sık kullanılan davranışlar:**

- `Clone` — Arc refcount; allocation yok.
- `Deref<Target=str>` — `&str` methodları doğrudan: `s.starts_with("..")`,
  `s.len()`.
- `Display + Debug + AsRef<str>`.
- `Eq + Hash` — `HashMap<SharedString, ...>` key olarak kullanılabilir
  (registry deseni).
- `PartialOrd + Ord` — sıralanabilir.

**Tema'da kullanım:**

```rust
pub struct Theme {
    pub name: SharedString,           // "Kvs Default Dark"
    // ...
}

pub struct ThemeFamily {
    pub name: SharedString,
    pub author: SharedString,
    // ...
}

pub struct ThemeNotFound(pub SharedString);
```

Hepsi `SharedString`. Sebebi: registry'de map key ve değer hem clone'lanır
hem hash'lenir; her noktada `String::clone()` allocation = kümülatif
maliyet.

**Tuzaklar:**

1. **`SharedString::from(String)` bir kez allocate**: İlk dönüşüm
   allocation yapar; sonraki klonlar ücretsiz. Hot path'te tekrar
   tekrar `String` üretme.
2. **Case sensitive**: "Kvs Default" ve "kvs default" iki farklı key.
   Registry `get` çağrılarında **birebir** isim gerek.
3. **`to_string()` allocation**: Yeni `String` üretir. Gerekmiyorsa
   `.as_ref()` veya `Display` ile yaz.

#### `HighlightStyle`

**Kaynak:** `gpui::HighlightStyle` (`text_system.rs`).

Bir syntax token'a uygulanacak görünüm sözleşmesi. Tüm alanlar
opsiyonel:

```rust
pub struct HighlightStyle {
    pub color: Option<Hsla>,
    pub background_color: Option<Hsla>,
    pub font_style: Option<FontStyle>,
    pub font_weight: Option<FontWeight>,
    pub underline: Option<UnderlineStyle>,
    pub strikethrough: Option<StrikethroughStyle>,
    pub fade_out: Option<f32>,
}
```

- `None` = "üst stilden devral". Editor birden fazla katmanı sırayla
  `refine` eder; `None` katmanı alttakini korur, `Some` katmanı override
  eder.
- `Default::default()` → tüm alanlar `None` (nötr).

**Tema'da kullanım** (`Theme::from_content` içinde):

```rust
fn highlight_style(s: &HighlightStyleContent) -> HighlightStyle {
    HighlightStyle {
        color: s.color.as_deref().and_then(|s| try_parse_color(s).ok()),
        background_color: s.background_color.as_deref()
            .and_then(|s| try_parse_color(s).ok()),
        font_style: s.font_style.map(|fs| match fs {
            FontStyleContent::Normal => FontStyle::Normal,
            FontStyleContent::Italic => FontStyle::Italic,
            FontStyleContent::Oblique => FontStyle::Oblique,
        }),
        font_weight: s.font_weight.map(|w| FontWeight(w.0)),
        ..Default::default()
    }
}
```

→ Üretilen `HighlightStyle`'lar `Vec<(String, HighlightStyle)>` olarak
`SyntaxTheme.highlights`'a girer.

#### `FontStyle`

```rust
pub enum FontStyle { Normal, Italic, Oblique }
```

- Tema JSON anahtarı: `"font_style": "italic"` (snake_case).
- `.italic()` fluent kısayolu element üzerinde `Italic`'e set eder.
- `Default` = `Normal`.

#### `FontWeight`

```rust
pub struct FontWeight(pub f32);
```

CSS weight değerleriyle birebir, sabit olarak tanımlı:

| Sabit | Değer | CSS karşılığı |
|-------|-------|---------------|
| `FontWeight::THIN` | 100.0 | thin |
| `FontWeight::EXTRA_LIGHT` | 200.0 | extra-light |
| `FontWeight::LIGHT` | 300.0 | light |
| `FontWeight::NORMAL` | 400.0 | normal (default) |
| `FontWeight::MEDIUM` | 500.0 | medium |
| `FontWeight::SEMIBOLD` | 600.0 | semibold |
| `FontWeight::BOLD` | 700.0 | bold |
| `FontWeight::EXTRA_BOLD` | 800.0 | extra-bold |
| `FontWeight::BLACK` | 900.0 | black |

`FontWeight::ALL` tüm değerleri sırayla taşır (iter için).

Tema JSON anahtarı: `"font_weight": 700` veya `"font_weight": 700.0`
(`FontWeightContent` `transparent` newtype olduğu için sayı kabul eder).

**Tuzaklar:**

1. **`HighlightStyle` katman karışımı**: Editor semantic highlight +
   tree-sitter highlight'ı **birleştirir**. Tema'da `Italic` versen bile
   semantic katman `Some(Normal)` döndürürse italik kaybolur. Bu davranış
   tema tarafının kontrolünde değil.
2. **`FontWeight(700.0)` vs `FontWeight::BOLD`**: Davranış aynı,
   okunabilirlik farklı. Sabit kullan.
3. **`underline`, `strikethrough`, `fade_out` atlamak**: Tema sözleşmesinde
   de var; `highlight_style` fonksiyonunun mevcut versiyonu sadece 4 alan
   handle ediyor. Tam parite için Content tarafında bu alanları da topla
   (Temel ilke).
4. **`FontStyle::Oblique`**: Çoğu OS font'unda Italic ile aynı render
   edilir ama bazılarında ayrı bir glyph seti olabilir. Tema yazarına
   "Italic seçtim ama Oblique göründü" gibi bir bildirim gelirse font
   katmanına bak.

---

### 8. Pencere: `WindowBackgroundAppearance`, `WindowAppearance`

İki ayrı pencere konsepti: tema yazarının seçtiği **arka plan tipi** ve
sistemin verdiği **light/dark modu**.

#### `WindowBackgroundAppearance`

**Kaynak:** `gpui::WindowBackgroundAppearance` (`window.rs`).

Tema JSON'unda `"background.appearance"` alanından gelir:

```rust
pub enum WindowBackgroundAppearance {
    Opaque,
    Transparent,
    Blurred,
}
```

| Değer | Davranış | Platform notu |
|-------|----------|---------------|
| `Opaque` (default) | Pencere arka planı tam dolu; altındaki masaüstü görünmez. | Her yerde çalışır. |
| `Transparent` | Pencere altındaki masaüstü/diğer pencereler doğrudan görünür. Tema'nın `background` rengi alpha < 1 olmalı. | macOS, Windows, Wayland evet. X11 compositor'a bağlı. |
| `Blurred` | macOS Mica/Vibrancy benzeri blur. | macOS evet, Windows 11 evet, Linux kısıtlı (Wayland: layer-shell). |

**Tema'da yer:**

```rust
pub struct ThemeStyles {
    pub window_background_appearance: WindowBackgroundAppearance,
    // ...
}
```

JSON Content tarafında `WindowBackgroundContent` (`Opaque`/`Transparent`/
`Blurred`) karşılığı ile map'lenir.

**Pencere açılırken aktarma:**

```rust
WindowOptions {
    window_background: cx.theme().styles.window_background_appearance,
    // ...
}
```

`open_window` argümanı olarak verilir; pencere yönetici bu tipte oluşturur.

**Runtime değişim:** Pencere açıldıktan sonra arka plan tipini değiştirmek
için `window.set_background_appearance(new_appearance)` çağrılır.

#### `WindowAppearance`

**Kaynak:** `gpui::WindowAppearance` (`platform.rs:1604`).

```rust
pub enum WindowAppearance {
    Light,         // macOS: aqua
    VibrantLight,  // macOS: NSAppearanceNameVibrantLight
    Dark,          // macOS: darkAqua
    VibrantDark,   // macOS: NSAppearanceNameVibrantDark
}
```

`Vibrant*` varyantları macOS'a özgüdür; diğer platformlarda üretilmez
ama enum hep dört değeri taşır. Tema seçim mantığında ikilik
(`Light`/`Dark`) yeterli; vibrancy ayrı bir vektör.

**Erişim:**

- `cx.window_appearance() -> WindowAppearance` — uygulama düzeyi (sistem
  tercihi).
- `window.appearance() -> WindowAppearance` — bu pencerenin gerçek
  görünümü (parent override edebilir).
- `window.observe_window_appearance(|window, cx| ...)` — değişimi izle
  (Subscription döner; `.detach()` zorunlu).
- `cx.observe_window_appearance(window, |this, window, cx| ...)` — view
  state içinden izle.

**Tema'da kullanım** (`SystemAppearance::init`):

```rust
let appearance = match cx.window_appearance() {
    WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
    WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
};
```

Sistem light/dark'a göre `Appearance::Dark` veya `Appearance::Light`
seçilir; tema registry'den uygun isim alınır.

**Sistem değişimini takip eden Zed-tarzı desen:**

```rust
cx.observe_window_appearance(window, |_, window, cx| {
    let appearance = window.appearance();
    // SystemAppearance'ı güncelle, tema'yı reload et
    // ...
}).detach();
```

`.detach()` zorunlu — Subscription drop olursa observer ölür.

**Tuzaklar:**

1. **`Transparent` + opaque bg**: `WindowBackgroundAppearance::Transparent`
   seçildi ama tema'nın `colors.background` alpha'sı 1.0. Sonuç: pencere
   yine opak görünür. Transparent için bg alpha < 1 olmalı.
2. **`Blurred` platform fallback**: Linux X11'de blur desteklenmiyorsa
   GPUI sessizce opaque'a düşer. Tema yazarına platform-aware fallback
   uyarısı vermek geliştirici görevi.
3. **`Vibrant*` branch atlamak**: `match cx.window_appearance()` yazarken
   sadece `Light`/`Dark` ele alıp `Vibrant*` unutursan compiler hatası
   verir; `_ => ...` ile geçiyorsan macOS davranışı yanlış olabilir.
4. **`window.set_background_appearance` sistem mod'unu değiştirmez**:
   Yalnız pencere düzeyi; sistem light/dark moduna dokunmaz.
5. **Açıldıktan sonra blur eklemek**: GPU resource yeniden alocate; ilk
   frame görsel olarak titreyebilir.

---

### 9. Bağlam tipleri: `App`, `Context<T>`, `Window`, `BorrowAppContext`

GPUI'de **bağlam** (`cx`) = hangi kaynaklara erişebileceğini belirleyen
parametre. Tema sistemi `App` ve `Context<T>` ile çalışır; `Window`'a
doğrudan dokunmaz.

#### `App`

Uygulama düzeyi state:

```rust
fn init(cx: &mut App) { /* ... */ }
```

**Tema sisteminin `App` üzerinden eriştikleri:**

- `cx.global::<T>() -> &T` — okuma; yoksa panic.
- `cx.try_global::<T>() -> Option<&T>` — okuma; yoksa `None`.
- `cx.set_global::<T>(value)` — kurma/üzerine yazma.
- `cx.update_global::<T, _>(|t, cx| ...)` — mutate; yoksa panic.
- `cx.has_global::<T>() -> bool` — kontrol.
- `cx.window_appearance() -> WindowAppearance` — sistem mod sorgu.
- `cx.refresh_windows()` — açık tüm pencereleri yeniden render et.

#### `Context<T>`

Bir `Entity<T>` (View, Model) güncellenirken gelir:

```rust
impl Render for AnaPanel {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let theme = cx.theme();   // ← Context<T> üzerinde de çalışır
        div().bg(theme.colors.background)
    }
}
```

**Önemli özellik:** `Context<T>: Deref<Target = App>`. Yani `App`'in tüm
methodları `Context<T>` üzerinde de çalışır. `cx.theme()` çağrısının
hangi bağlamda olduğun fark etmez.

**`Context<T>` ekstra metotları (tema-dışı, kıyas için):**

- `cx.notify()` — bu entity'nin re-render'ını tetikler.
- `cx.emit(event)` — entity event yayar.
- `cx.spawn(...)` — async task.
- `cx.subscribe(...)`, `cx.observe(...)` — entity'ler arası izleme.

Tema sistemi bu metotları **kendi içinde kullanmaz**. UI tüketicisi
(Bölüm VIII) entity'yi temaya bağlamak istediğinde `cx.notify()` çağırır.

#### `Window`

Pencere düzeyi state. Tema sistemi `Window` parametresini doğrudan almaz;
çağrıldığı GPUI fonksiyonlar `App`/`Context<T>` üzerinden geçer. İstisna:

- Sistem appearance değişimini izlerken
  `window.observe_window_appearance(...)` veya
  `cx.observe_window_appearance(window, ...)` — `Window` referansı gerekir.

#### `BorrowAppContext` trait

`App`, `Context<T>`, `AsyncApp`, `AsyncWindowContext` hepsi bu trait'i
implement eder:

```rust
pub trait BorrowAppContext {
    fn update_global<G: Global, R>(&mut self, f: impl FnOnce(&mut G, &mut App) -> R) -> R;
    fn set_global<G: Global>(&mut self, global: G);
    // (has_global, try_global App trait'inde)
}
```

Tema sisteminin global yönetimi bu trait üzerinden çalışır. Aynı
`set_theme(cx)` çağrısı hem `App`'ten hem `Context<T>`'den hem async
context'ten geçerlidir.

**Trait uyum tablosu (tema açısından):**

| Bağlam | `cx.theme()` | `set_global` | `cx.notify()` | `cx.window_appearance()` |
|--------|--------------|--------------|---------------|---------------------------|
| `&App` | ✓ | ✗ (mut gerek) | ✗ | ✓ |
| `&mut App` | ✓ | ✓ | ✗ | ✓ |
| `&Context<T>` | ✓ | ✗ | ✗ | ✓ |
| `&mut Context<T>` | ✓ | ✓ | ✓ | ✓ |
| `&AsyncApp` | `try_global` ile | ✗ | ✗ | `window` üzerinden |

**Tuzaklar:**

1. **`cx.theme()` panic potansiyeli**: `GlobalTheme` set edilmemişse
   panic. `kvs_tema::init(cx)` uygulama başında en erken çağrılmalı.
2. **`Context<T>` içinden `set_global`**: Çalışır ama tema değişimi
   tüm view'ları etkilediğinden bireysel entity'den tetiklemek mantıksız
   — tema değişim akışını `App` düzeyinde tut.
3. **AsyncApp'ten tema erişimi**: `&App` yerine `WeakEntity` ve `update`
   kullan; tema durumu okuma anında değişebilir.
4. **`Window` referansını saklamak**: Pencere kapanırsa stale handle.
   `WindowHandle<T>` veya `WeakEntity` tercih edilir.

---

### 10. `Global` trait ve `cx.set_global / update_global / refresh_windows`

GPUI'de **global state** = `App` içinde tip ile indekslenen tek instance.
Tema sistemi üç global tutar.

**`Global` trait** — marker, methodsuz:

```rust
pub trait Global: 'static {}
```

- Tek gereksinim: `'static` (referans tutmayan, sahipli tip).
- Her tip için `impl Global for MyTip {}` yeterli.

**Newtype deseni (zorunlu pratik):**

```rust
struct GlobalThemeRegistry(Arc<ThemeRegistry>);
impl Global for GlobalThemeRegistry {}
```

→ `Arc<ThemeRegistry>` tipini doğrudan global yapmak yerine **newtype'a
sarma**. Sebep: `Arc<ThemeRegistry>` başka yerde de geçebilir; global
anahtarı `GlobalThemeRegistry` ayrı tutarak çakışma engellenir.

**API methodları (`BorrowAppContext`):**

| Method | Davranış | Yoksa |
|--------|----------|-------|
| `cx.set_global(g)` | Kurar veya üzerine yazar | OK |
| `cx.update_global::<G, _>(\|g, cx\| ...)` | Mutate eder | **Panic** |
| `cx.has_global::<G>()` | Kontrol | `false` |
| `cx.try_global::<G>()` | Okuma | `None` |
| `cx.global::<G>()` | Okuma | **Panic** |

**`init`-or-`update` deseni** (tema sisteminin tutarlı kullanımı):

```rust
pub fn set_theme(cx: &mut App, theme: Arc<Theme>) {
    if cx.has_global::<Self>() {
        cx.update_global::<Self, _>(|this, _| this.theme = theme);
    } else {
        cx.set_global(Self { theme });
    }
}
```

→ İlk çağrıda `set_global`, sonraki çağrılarda `update_global`. Bu desen
tema sistemi sınırları dışında da global state için idiomatik.

#### Tema sisteminin üç global'i

| Global | İçerik | Kim kurar | Kim okur |
|--------|--------|-----------|----------|
| `GlobalThemeRegistry` | `Arc<ThemeRegistry>` | `ThemeRegistry::set_global` | `ThemeRegistry::global(cx)` |
| `GlobalTheme` | `Arc<Theme>` (aktif) | `GlobalTheme::set_theme` | `cx.theme()` (`ActiveTheme` trait) |
| `GlobalSystemAppearance` | `SystemAppearance` | `SystemAppearance::init` | `SystemAppearance::global(cx)` |

#### `cx.refresh_windows()`

Tüm açık pencereleri **yeniden render** eder:

```rust
pub fn temayi_degistir(ad: &str, cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;
    GlobalTheme::set_theme(cx, yeni);
    cx.refresh_windows();   // ← tüm UI'yı yenile
    Ok(())
}
```

**Neden gerekli?** GPUI'nin `cx.notify()` lokal bir Entity'yi yeniden
render tetikler. Tema değişikliği **her** view'ı etkilediği için global
tetikleme gerekir. `cx.notify()` tek tek view'lara çağırmak hem dağınık
hem pratik değil.

**Davranış:**

- Tüm açık pencerelerde view ağacı yeniden inşa edilir (next frame).
- Pencerelere özel state (focus, scroll) korunur.
- GPU resource'lar reuse edilir; sadece layout + paint tekrar çalışır.

**Tuzaklar:**

1. **Init sıralaması**: `cx.theme()` `GlobalTheme` set edilmeden
   çağrılırsa panic. `kvs_tema::init(cx)` ana akışta en erken çağrılır.
2. **`set_global` çakışması**: Aynı tipi tekrar set'lemek mevcut global'i
   siler. Tema dışı bir global state'i de aynı tipte koyma.
3. **`refresh_windows` çağırmamak**: En yaygın bug — tema değişti ama UI
   eski renkte. `set_theme` her zaman `refresh_windows` ile eşleşmeli;
   helper fonksiyona sar.
4. **`update_global` içinde `set_global`**: Aynı tipte re-entrancy
   hatası. Update callback içinde sadece field mutate et, yeni
   set'leme.
5. **`detach()` unutmak observer'da**: `cx.observe_window_appearance(...)`
   çağrısı `Subscription` döner; `.detach()` çağrılmazsa Subscription
   drop olur ve observer ölür.

---

### 11. `refineable::Refineable` derive davranışı

**Kaynak:** `refineable` crate (Zed workspace, Apache-2.0).

`#[derive(Refineable)]` her struct için, alanları `Option<T>` olan bir
**ikiz `*Refinement` tipi** üretir; sonra `original.refine(&refinement)`
ile birleştirilir.

#### Derive davranışı

**Input:**

```rust
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct StatusColors {
    pub error: Hsla,
    pub error_background: Hsla,
    pub error_border: Hsla,
}
```

**Üretilen output** (otomatik, görmezsin):

```rust
#[derive(Default, Clone, Debug, serde::Deserialize)]
pub struct StatusColorsRefinement {
    pub error: Option<Hsla>,
    pub error_background: Option<Hsla>,
    pub error_border: Option<Hsla>,
}

impl Refineable for StatusColors {
    type Refinement = StatusColorsRefinement;

    fn refine(&mut self, refinement: &Self::Refinement) {
        if let Some(v) = &refinement.error { self.error = *v; }
        // ... her alan
    }

    fn refined(mut self, refinement: Self::Refinement) -> Self {
        self.refine(&refinement);
        self
    }
    // ... is_superset_of, subtract, from_cascade, is_empty
}
```

#### `#[refineable(...)]` attribute parametreleri

Listedeki itemlar **Refinement tipine eklenecek derive'lardır**:

```rust
#[refineable(Debug, serde::Deserialize)]
```

→ Refinement tipi `Default + Clone` zaten taşıyor; üstüne `Debug` ve
`serde::Deserialize` eklenir.

Tema sözleşmesinde kullandıklarımız:
- `Debug` — log/test çıktısı.
- `serde::Deserialize` — refinement JSON'dan deserialize edilebilirse.

#### `Refineable` trait yüzeyi (tam)

```rust
pub trait Refineable: Clone {
    type Refinement: Refineable<Refinement = Self::Refinement> + IsEmpty + Default;

    fn refine(&mut self, refinement: &Self::Refinement);
    fn refined(self, refinement: Self::Refinement) -> Self;
    fn from_cascade(cascade: &Cascade<Self>) -> Self where Self: Default + Sized;
    fn is_superset_of(&self, refinement: &Self::Refinement) -> bool;
    fn subtract(&self, refinement: &Self::Refinement) -> Self::Refinement;
}

pub trait IsEmpty {
    fn is_empty(&self) -> bool;
}
```

Tema sisteminin kullandığı yüzey **dar**: `refine` ve `refined`. `Cascade`,
`is_superset_of`, `subtract`, `is_empty` arabirimleri sözleşmenin parçası
ama tema akışında çağrılmaz (Zed de bunların çoğunu kullanmaz).

#### Davranış kuralları

- **Alan-bazlı, recursive değil**: Nested struct alanı varsa, onun da
  `Refineable` olması gerek. Macro otomatik olarak iç içe `refine`
  çağırmaz; manuel orchestration `Theme::from_content` içinde.
- **`Some(v)` override, `None` koruma**: JSON deserializasyonu sırasında
  verilmeyen alan `None` olarak gelir; baseline korunur.
- **`Copy` alanlar için `*v`**: `Hsla` gibi Copy tipler için macro deref
  eder. Non-Copy alanlar için `.clone()` (versiyona göre).
- **`Refinement`'in kendisi `Refineable`**: İki refinement'i zincirleme
  birleştirmek mümkün (`refine_a.refine(&refine_b)`); tema sisteminin
  şimdilik kullanmadığı bir kapasite.

#### Tema'da nerede kullanılır

- `ThemeColors` ve `StatusColors` `#[derive(Refineable)]` ile işaretlenir
  → `ThemeColorsRefinement`, `StatusColorsRefinement` otomatik üretilir.
- `Theme::from_content`:
  1. Baseline `Theme`'i klonlar.
  2. Content'ten refinement üretir (`theme_colors_refinement`,
     `status_colors_refinement`).
  3. `apply_status_color_defaults` ile türetme uygular.
  4. `colors.refine(&refinement)` ile birleştirir.

Eksik alanlar baseline'dan, dolu alanlar kullanıcı temasından gelir.

#### `Cascade` (bilgi — tema'da kullanılmaz)

`refineable` crate'i çok katmanlı (3+) refinement yığını için
`Cascade<S>` ve `CascadeSlot` sunar:

```rust
pub struct Cascade<S: Refineable>(Vec<Option<S::Refinement>>);
pub struct CascadeSlot(usize);
```

Tema sistemi bunu kullanmaz; iki katman (baseline + kullanıcı) yeterli.
GPUI'nin `Interactivity` katmanı da `Cascade` yerine
`Option<Box<StyleRefinement>>` alanları tutuyor — yani 3+ katman ihtiyacı
gerçekte nadir. Bilgi olarak ihtiyaç doğarsa hazır.

#### Tuzaklar

1. **`#[refineable(...)]` unutmak**: Eklemezsen Refinement tipi sadece
   `Default + Clone` taşır. Serde için manuel
   `#[refineable(serde::Deserialize)]` gerekir.
2. **Public/private uyumsuzluğu**: `pub struct ThemeColors` ise Refinement
   tipi de `pub struct ThemeColorsRefinement`. Visibility macro tarafından
   kopyalanır.
3. **`refine` vs `refined`**: İlki `&mut self`, ikincisi sahip alır.
   `Hsla` gibi küçük alanlar için `refine` her zaman doğru seçim.
4. **Nested struct'lar için manuel orchestration**: `Theme.styles.colors`
   gibi katmanlar Refineable kendiliğinden recursive birleştirmez.
   `Theme::from_content` her alt struct için ayrı `refine` çağırır.
5. **`refineable` `publish = false`**: Crates.io'ya yayınlanan bir
   crate'in bu derive'ı kullanması için fork veya vendor şart (bkz.
   Konu 3).
6. **Refinement tipi `Default` zorunlu**: `..Default::default()`
   yazmazsan tüm alanları açıkça vermek gerekir. Macro `Default`
   türetiyor, kullan.

---

## Bölüm III — Veri sözleşmesi tipleri

Bu bölüm tema sözleşmesinin **en alt katmanını** ele alır: Zed'in JSON
tema dosyalarını birebir parse edebilmek için tutulan struct'lar.
Tipler "ne mirror edilir, hangi alanlar opsiyonel, nasıl üst üste
binerler" sorularına cevap verir. Her tip için: yapı, alan listesi /
grupları, davranış, JSON anahtarı (Bölüm IV'te derinleşir), tuzaklar.

> **Hatırlatma:** "Temel ilke" (Konu 2) gereği bu bölümün her struct'ı
> Zed'in karşılığında ne varsa **tamamını** alan olarak içerir. Eksik
> alan = sözleşme delinmesi.

---

### 12. `Theme` ve `ThemeStyles` üst yapısı

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

Tema'nın **üst düzey** sözleşmesi iki ayrı struct'a bölünür: `Theme`
(metadata + styles) ve `ThemeStyles` (tüm renk/stil grupları).

```rust
pub struct Theme {
    pub id: String,
    pub name: SharedString,
    pub appearance: Appearance,
    pub styles: ThemeStyles,
}

pub struct ThemeStyles {
    pub window_background_appearance: WindowBackgroundAppearance,
    pub system: SystemColors,
    pub colors: ThemeColors,
    pub status: StatusColors,
    pub player: PlayerColors,
    pub accents: AccentColors,
    pub syntax: Arc<kvs_syntax_tema::SyntaxTheme>,
}
```

#### Alan-alan davranış

| Alan | Tip | Niye böyle |
|------|-----|------------|
| `id` | `String` | Unique tema id; runtime'da `uuid::Uuid::new_v4()` üretilir. Map key değil; hash ihtiyacı yok. |
| `name` | `SharedString` | İnsan-okunabilir ad (örn. "Kvs Default Dark"). Registry map key, çok klonlanır → `Arc<str>` ucuzluğu (bkz. Konu 7). |
| `appearance` | `Appearance` | `Light` veya `Dark`. UI tarafının sistem moduna göre tema seçmesini sağlar. |
| `styles` | `ThemeStyles` | Tüm renk grupları. Ayrı struct olması: `Theme`'i Clone'larken `styles`'ın boyutunu (~150 `Hsla` + diğerleri) tek alan altında tutar. |

#### `ThemeStyles` alt katmanları

| Alt katman | Tip | Bölüm referansı |
|-----------|-----|-----------------|
| `window_background_appearance` | `WindowBackgroundAppearance` | Bölüm II/Konu 8 |
| `system` | `SystemColors` | Konu 16 |
| `colors` | `ThemeColors` | Konu 13 |
| `status` | `StatusColors` | Konu 14 |
| `player` | `PlayerColors` | Konu 15 |
| `accents` | `AccentColors` | Konu 16 |
| `syntax` | `Arc<SyntaxTheme>` | Konu 17 |

#### `Arc<SyntaxTheme>` neden Arc?

`SyntaxTheme` `Vec<(String, HighlightStyle)>` taşır — boy büyük (50-200
girdi). Tema değişirken syntax bölümü diğer alanlardan **bağımsız**
güncellenebilir; `Arc` sayesinde aynı syntax birden fazla `Theme`
varyantı arasında paylaşılabilir (örn. light/dark sadece UI renklerinde
farklı, syntax aynı olabilir).

Diğer alt katmanlar (`ThemeColors`, `StatusColors`, vs.) `Arc` ile
sarılmamış — küçük (her biri max ~150 `Hsla`), ve baseline ile her
varyant için ayrı klon zaten gerek.

#### Erişim desenleri

```rust
let theme = cx.theme();                          // &Arc<Theme>
let bg = theme.styles.colors.background;         // doğrudan alan
let muted = theme.styles.colors.text_muted;
let error = theme.styles.status.error;
let local = theme.styles.player.local().cursor;
```

> **Zed eşdeğeri:** Zed'de `theme.colors()`, `theme.status()` gibi
> accessor metotları var (`crates/theme/src/theme.rs`). `kvs_tema`'da
> opsiyonel olarak ekleyebilirsin; kıyaslı API:
>
> ```rust
> impl Theme {
>     pub fn colors(&self) -> &ThemeColors { &self.styles.colors }
>     pub fn status(&self) -> &StatusColors { &self.styles.status }
>     pub fn players(&self) -> &PlayerColors { &self.styles.player }
>     pub fn syntax(&self) -> &Arc<SyntaxTheme> { &self.styles.syntax }
> }
> ```
>
> Bu accessor'lar `theme.styles.colors.x` yerine `theme.colors().x`
> yazmanı sağlar; iç düzen değişirse tüketici kodu etkilenmez.

#### `Theme` clone stratejisi

`Theme` tek seferde `~150 × Hsla (16 byte) + birkaç enum + Arc + String`
≈ **2.5-3 KiB**. Her `cx.theme()` çağrısı `&Arc<Theme>` döner; clone
ücretsiz. Asla `Theme::clone()` yazmaktan kaçın — `GlobalTheme.theme`
zaten `Arc<Theme>` tutuyor.

#### Tuzaklar

1. **`id` yerine `name` map key**: `name` `SharedString` ve registry key
   olarak kullanılır. `id` (uuid) sadece tema-içi tanım için; karıştırma.
2. **`styles` alanını dış API yapmak**: Iç düzen sync turunda değişebilir.
   Tüketici `theme.styles.colors.x` yerine `theme.colors().x` kullansın
   diye accessor sağla (yukarıdaki opsiyonel kalıp).
3. **`appearance` runtime'da değişmez**: Bir tema *Light* olarak yüklendi
   diye runtime'da Dark olarak yeniden işlenmez. Tema değiştirmek için
   `set_theme` ile yeni tema yükle.
4. **`SystemColors::default()` ile dolu kalsın**: Tema yazarı sistem
   renklerini özelleştirmek istemiyorsa `Default::default()` yeterli;
   bazı geliştiriciler bu alanı atlayıp `unsafe zeroed` ile karıştırıp
   görünmez kılar.

---

### 13. `ThemeColors` alan kataloğu

**Kaynak modül:** `kvs_tema/src/styles/colors.rs`.

UI renk paletinin tamamı tek struct'ta toplanır. **Alan sayısı ~150**
(Zed sürümüne göre değişir; sync turunda güncelle).

```rust
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct ThemeColors {
    /* ~150 alan, gruplara ayrılmış */
}
```

`#[derive(Refineable)]` otomatik olarak `ThemeColorsRefinement` ikizini
üretir (bkz. Konu 11).

#### Alan grupları (semantik kategoriler)

Aşağıdaki tablo, alan adlandırma prefix'lerini ve **işlevsel rolünü**
toplar. Zed'in `crates/theme/src/styles/colors.rs` dosyasındaki sıralama
korunur; eksik alan = sözleşme delinmesi (Konu 2).

| Grup | Prefix / örnek | Rol | Yaklaşık alan sayısı |
|------|----------------|-----|---------------------|
| **Kenarlıklar** | `border`, `border_variant`, `border_focused`, `border_selected`, `border_transparent`, `border_disabled` | Çevre çizgileri ve focus/selection durumları | 6 |
| **Yüzeyler** | `background`, `surface_background`, `elevated_surface_background` | Pencere/panel/popover katmanlama | 3 |
| **Etkileşimli element** | `element_background`, `element_hover`, `element_active`, `element_selected`, `element_selection_background`, `element_disabled`, `drop_target_background`, `drop_target_border` | Button/clickable durumları | 8 |
| **Ghost element** | `ghost_element_background`, `ghost_element_hover`, `ghost_element_active`, `ghost_element_selected`, `ghost_element_disabled` | Şeffaf bg ile element durumları (toolbar icon vs.) | 5 |
| **Metin** | `text`, `text_muted`, `text_placeholder`, `text_disabled`, `text_accent` | Ön plan renkleri | 5 |
| **Icon** | `icon`, `icon_muted`, `icon_disabled` | Icon ön plan renkleri | 3 |
| **Editor** | `editor_*` (background, foreground, line_number, active_line_background, highlighted_line_background, wrap_guide, document_highlight_*) | Kod editör katmanı | ~12-20 |
| **Editor diff hunk** | `editor_indicator_*`, `version_control_*` veya hunk-spesifik alanlar | Diff/inline blame görünümü | ~5-10 |
| **Terminal ANSI** | `terminal_ansi_black`, `terminal_ansi_red`, ..., `terminal_ansi_bright_white` (8 renk × 2 normal/bright = 16) | Terminal renkleri | 16-20 |
| **Panel** | `panel_background`, `panel_focused_border`, `panel_indent_guide_*` | Sidebar/panel kromu | ~5 |
| **Status bar** | `status_bar_background` | Alt durum çubuğu | 1-2 |
| **Title bar** | `title_bar_background`, `title_bar_inactive_background`, `title_bar_border` | Pencere başlığı | ~3 |
| **Tab** | `tab_bar_background`, `tab_active_background`, `tab_inactive_background` | Editor tab şeridi | ~5 |
| **Search** | `search_match_background` | Arama vurgusu | ~2 |
| **Scrollbar** | `scrollbar_*` (track, thumb, thumb_hover, thumb_active, thumb_border) | Kaydırma çubuğu | ~5 |
| **Debugger** | `debugger_accent`, `debugger_paused`, vs. | Debug oturumu | ~3-5 |
| **VCS** | `version_control_added`, `_modified`, `_deleted`, `_conflict_marker_*` | Git/VCS göstergeleri | ~6-10 |
| **Vim** | `vim_yank_*`, `vim_mode_*` | Vim modu vurgusu | ~2-4 |
| **Pane group** | `pane_group_border`, `pane_focused_border` | Editor pane sınırları | ~2 |

> **Bu tablo "yaklaşık" sayılarla çalışır** çünkü Zed her sync turunda
> alan ekler/kaldırır. Tam liste için `../zed/crates/theme/src/styles/colors.rs`
> ve `../zed/crates/settings_content/src/theme.rs` dosyalarını referans
> al; sync turunda mirror et.

#### Naming convention

| Konum | Stil | Örnek |
|-------|------|-------|
| Rust alan adı | `snake_case` | `border_variant`, `terminal_ansi_red` |
| JSON anahtarı | `dot.separated` | `border.variant`, `terminal.ansi.red` |
| Bağlantı | `#[serde(rename = "border.variant")]` | (Bölüm IV/Konu 22) |

#### `Refineable` davranışı

`ThemeColors` `Refineable` türettiği için her alan için
`ThemeColorsRefinement` içinde `Option<Hsla>` üretilir. `from_content`
akışında:

1. Baseline `ThemeColors` klonlanır.
2. Kullanıcı temasından `ThemeColorsRefinement` üretilir.
3. `baseline.refine(&refinement)` ile birleştirilir.

Eksik alanlar baseline'dan gelir; kullanıcı verdiği alanlar override
eder.

#### Tuzaklar

1. **Sıra önemli (sözleşme açısından değil ama disiplin açısından)**:
   Zed'in dosyasındaki sıralamayı korumak sync turunda diff'i okumayı
   kolaylaştırır. Alfabetik sıralamak hata.
2. **Grup yorumlarını silmek**: `// Kenarlıklar`, `// Yüzeyler` gibi
   semantik yorumlar grup sınırını gösterir; sync turunda yeni grup
   eklenirken (örn. Zed `inlay_hint_*` ekledi) bu yorumlar referans
   noktası.
3. **Yeni grup ekleyince TOC güncellememek**: Bu rehberin Konu 13 tablosu
   her sync turunda gözden geçirilmeli; yeni grup eklendiyse buraya
   sat ekle.
4. **Editor / debugger / vcs alanlarını dışlamak**: "Henüz editor yok" =
   geçerli dışlama sebebi değil (Konu 2). Hepsini ekle, UI'da okumayı
   sonraya bırak.
5. **`Option<Hsla>` alanları**: ThemeColors `Hsla` (Option değil). Eksik
   alan baseline'dan dolar — refinement katmanı bunu yönetir. ThemeColors
   içinde Option kullanmaya çalışırsan refinement deseni bozulur.

---

### 14. `StatusColors`: fg/bg/border üçlüsü deseni

**Kaynak modül:** `kvs_tema/src/styles/status.rs`.

Diagnostic ve VCS durum renklerini taşır. Her durum için **üç alan**:
foreground (`<ad>`), background (`<ad>_background`), border
(`<ad>_border`).

```rust
#[derive(Refineable, Clone, Debug, PartialEq)]
#[refineable(Debug, serde::Deserialize)]
pub struct StatusColors {
    pub error: Hsla,
    pub error_background: Hsla,
    pub error_border: Hsla,
    pub warning: Hsla,
    pub warning_background: Hsla,
    pub warning_border: Hsla,
    // ... 14 status × 3 = 42 alan
}
```

#### 14 status tipi

| Status | Kullanım |
|--------|----------|
| `conflict` | Git merge conflict markeri |
| `created` | Yeni eklenmiş satır/dosya |
| `deleted` | Silinmiş satır/dosya |
| `error` | Diagnostic hata seviyesi |
| `hidden` | Gizli/atlanmış öğeler |
| `hint` | Diagnostic hint seviyesi (en düşük) |
| `ignored` | `.gitignore` ile dışlanmış |
| `info` | Diagnostic info seviyesi |
| `modified` | Değiştirilmiş satır/dosya |
| `predictive` | Tahmin (örn. AI completion) |
| `renamed` | Adı değiştirilmiş dosya |
| `success` | Başarılı işlem göstergesi |
| `unreachable` | Erişilemez kod yolu |
| `warning` | Diagnostic uyarı seviyesi |

**Toplam:** 14 × 3 = **42 alan**.

#### Üçlü deseni

Her status üçlüsü tutarlı:

```rust
pub <name>: Hsla,             // foreground — ana renk (icon, metin)
pub <name>_background: Hsla,  // arka plan — vurgu/highlight bg
pub <name>_border: Hsla,      // kenar — outline/divider
```

Tema yazarı sık sık sadece foreground'u verir; `_background` ve
`_border` türetilir.

#### Türetme önizleme (`apply_status_color_defaults`)

`refinement.rs` içindeki yardımcı, **foreground verilmiş ama background
verilmemiş** durumda `_background`'u foreground'un **%25 alpha**'lı
versiyonundan türetir:

```rust
pub fn apply_status_color_defaults(r: &mut StatusColorsRefinement) {
    let pairs = &mut [
        (&mut r.deleted, &mut r.deleted_background),
        (&mut r.created, &mut r.created_background),
        (&mut r.modified, &mut r.modified_background),
        (&mut r.conflict, &mut r.conflict_background),
        (&mut r.error, &mut r.error_background),
        (&mut r.hidden, &mut r.hidden_background),
    ];
    for (fg, bg) in pairs {
        if bg.is_none() && let Some(fg) = fg.as_ref() {
            **bg = Some(fg.opacity(0.25));
        }
    }
}
```

Detaylar Bölüm V/Konu 25'te. Burada bilinmesi gereken: **fg-only**
JSON temaları baseline'ın `_background` değerleriyle karışmaz — fg'den
türetilir.

#### JSON şeması

```json
{
  "error": "#ff5555ff",
  "error.background": "#ff555520",
  "error.border": "#ff555580",
  "warning": "#ffaa00ff"
}
```

> **Not:** JSON anahtarında `.background` kullanılır (`error.background`),
> Rust alan adında `_background` (`error_background`).
> `#[serde(rename = "error.background")]` ile bağlanır.

#### Tüm alanlar Hsla, hiçbiri Option değil

ThemeColors gibi `StatusColors` de her alanı `Hsla` tutar. Eksik alanlar
refinement katmanında handle edilir (`StatusColorsRefinement` her alanı
`Option<Hsla>` yapar otomatik).

#### Tuzaklar

1. **Türetme kuralı atlanırsa**: Kullanıcı sadece `error` verirse ve
   `apply_status_color_defaults` çağrılmazsa, `error_background`
   baseline'dan kalır. Sonuç: kullanıcı temasının ana rengi var ama
   bg eski temanın yarı-saydam mavisi. UI karışık görünür.
2. **14 status'un tamamını dahil etmek**: Tema yazarı sadece `error` ve
   `warning` kullansa bile struct'ta `predictive`, `unreachable`,
   `renamed` vs. **olmak zorunda** (Konu 2). UI'da okumayan alan
   sıfır maliyet.
3. **`_background` ve `_border` farklı türetilebilir**: %25 alpha bg
   için makul; border için %50 alpha daha doğal. Yardımcı fonksiyon
   sadece `_background` için tanımlı — `_border` için ayrı türetme
   istiyorsan ek fonksiyon yaz.
4. **Zed yeni status tipi eklerse**: Sync turunda yeni tipi yakala,
   üçlüyü ekle, `apply_status_color_defaults`'a kaydet (eğer
   foreground-only türetme makulsa).

---

### 15. `PlayerColors`, `PlayerColor`, slot semantiği

**Kaynak modül:** `kvs_tema/src/styles/players.rs`.

"Player" terimi Zed'in collaboration sisteminden gelir: çoklu kullanıcının
aynı dosyada eş zamanlı düzenlemesinde her kullanıcıya farklı **cursor**,
**selection** ve **background** rengi atanır. Single-player uygulamada
da kullanışlı (multi-cursor görünümü).

```rust
#[derive(Clone, Debug, PartialEq)]
pub struct PlayerColor {
    pub cursor: Hsla,
    pub background: Hsla,
    pub selection: Hsla,
}

#[derive(Clone, Debug, PartialEq, Default)]
pub struct PlayerColors(pub Vec<PlayerColor>);
```

#### `PlayerColor` alanları

| Alan | Rol |
|------|-----|
| `cursor` | Kullanıcının imleç rengi (tam opak). |
| `background` | Avatar/etiket arka planı (yarı saydam). |
| `selection` | Bu kullanıcının metin seçim arka planı (yarı saydam). |

#### Slot semantiği

`PlayerColors(Vec<PlayerColor>)` sıralı bir liste. **Index 0 yerel
kullanıcıya rezerve**; sonraki index'ler katılımcı (participant)
slotları.

```rust
impl PlayerColors {
    pub fn local(&self) -> PlayerColor {
        self.0.first().cloned().unwrap_or(/* siyah fallback */)
    }

    pub fn color_for_participant(&self, participant_index: u32) -> PlayerColor {
        let len = self.0.len().max(1);
        let idx = (participant_index as usize) % len;
        self.0.get(idx).cloned().unwrap_or_else(|| self.local())
    }
}
```

**Davranış kuralları:**

- Liste boşsa `local()` siyah fallback döner. Bu **UI'da görünmez** —
  fallback temalarda her zaman en az bir `PlayerColor` doldur.
- `color_for_participant(N)` modulo behavior: 8 player slot varsa
  9. participant slot 1'i yeniden kullanır (`9 % 8 = 1`).
- `unwrap_or_else(|| self.local())` — `get(idx)` zaten `Some` döner çünkü
  `idx = N % len`, ama type system için fallback şart.

#### JSON şeması

```json
{
  "players": [
    { "cursor": "#22d3eeff", "background": "#22d3ee40", "selection": "#22d3ee20" },
    { "cursor": "#a78bfaff", "background": "#a78bfa40", "selection": "#a78bfa20" }
  ]
}
```

`players` boş array gelirse refinement deseni baseline'ın liste'sini
korur (`Theme::from_content` içinde bunu kontrol eder).

#### Kullanım örnekleri

```rust
// Yerel kullanıcının imleci
let yerel = cx.theme().styles.player.local();
div().bg(yerel.cursor)

// 3. katılımcının seçimi
let katilimci = cx.theme().styles.player.color_for_participant(3);
div().bg(katilimci.selection)
```

#### Tuzaklar

1. **Boş `PlayerColors`**: `Vec` boşsa `local()` siyah fallback verir =
   ekranda görünmez. Fallback temalarda **en az bir slot** doldur:
   ```rust
   PlayerColors(vec![PlayerColor { cursor: accent, ... }])
   ```
2. **`color_for_participant(0)` ile `local()`**: Aynı sonucu verir mi?
   Evet, çünkü `0 % len = 0` ve index 0 local. Ama anlamsal olarak
   `local()` daha net.
3. **Modulo yerine clamp düşünmek**: Modulo kasıtlı — slot sayısı yetmezse
   "sarmal" davranır. Clamp seçseydin son slot tüm fazla katılımcılarda
   aynı renk olurdu = ayırt edilemez.
4. **`cursor` alpha**: Çoğunlukla 1.0 (tam opak); `background` ve
   `selection` yarı saydam. Tüm üçü opak yaparsan metin görünmez olur.
5. **Tema yazarının `players` atlaması**: `players: []` veya alan yok =
   baseline'ın player paleti korunur. Bu kasıtlı; her tema kendi player
   paletini vermek zorunda değil.

---

### 16. `AccentColors`, `SystemColors`, `Appearance`

Bu üç tip tema'nın **kromatik altyapısını** tamamlar: dönen accent
listesi, platforma özgü sabitler, ve tema modunun nominal işareti.

#### `AccentColors`

**Kaynak modül:** `kvs_tema/src/styles/accents.rs`.

Tema'nın "vurgu" renkleri — rotation list (örn. çoklu chip, etiket, label).

```rust
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

**Davranış:**

- Boş ise `gpui::blue()` fallback.
- Modulo döner — accent listesi tükenince başa sarar.

**JSON şeması:**

```json
{
  "accents": ["#22d3eeff", "#a78bfaff", "#f59e0bff", null]
}
```

`null` girdiler `Vec<Option<String>>` olarak `*Content` tipine girer;
parse hatası olanlar `filter_map` ile elenir (`Theme::from_content`
içinde).

**Tema'da kullanım:**

```rust
let chip_color = cx.theme().styles.accents.color_for(chip_index);
```

Etiket/chip listesinde her etiket için index gönderirsin; renk otomatik
döner.

#### `SystemColors`

**Kaynak modül:** `kvs_tema/src/styles/system.rs`.

Tema-bağımsız platform sabitleri. **Tüm temalarda aynı değer**; tema
yazarı override edebilir ama genelde edilmez.

```rust
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

**Alanlar:**

| Alan | Rol |
|------|-----|
| `transparent` | `hsla(0,0,0,0)` sabiti — `transparent_black()` ile aynı, alan olarak da bulundurulur. |
| `mac_os_traffic_light_red` | macOS pencere kapatma butonu rengi (kırmızı). |
| `mac_os_traffic_light_yellow` | Minimize butonu rengi (sarı). |
| `mac_os_traffic_light_green` | Maximize/fullscreen butonu rengi (yeşil). |

Custom titlebar yazıyorsan (rehber.md #27) traffic light butonlarını
elle çizersin; renkler bu alanlardan gelir.

**Tema'da kullanım:**

```rust
// SystemColors::default() kullanıldığı sürece elle inşa etmeye gerek yok
ThemeStyles {
    system: SystemColors::default(),
    // ...
}
```

#### `Appearance`

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

```rust
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
```

**Tema'da rol:** Tema'nın **nominal modu**. Sistem light/dark mod
sinyalinden farklı:

| Tip | Anlam | Kaynak |
|-----|-------|--------|
| `Appearance` | "Bu tema light mi dark mı?" | Tema JSON'undaki `"appearance"` alanı |
| `WindowAppearance` (Bölüm II/Konu 8) | "OS şu an light mı dark mı?" | `cx.window_appearance()` |

İkisi **eşleşmek zorunda değil** — kullanıcı sistem dark modda ama
explicit olarak light tema seçmiş olabilir.

**JSON anahtarı:** `"appearance": "light"` veya `"appearance": "dark"`.

**Kullanım:**

```rust
let active = cx.theme();
if active.appearance.is_light() {
    // light-spesifik logo varyantı, vs.
}
```

#### Tuzaklar

1. **`AccentColors` boş başlatmak**: Fallback `gpui::blue()` döner ama
   tema yazarı muhtemelen kendi mavi tonu farklı. Fallback temalarda
   en az 4-6 accent doldur.
2. **`SystemColors`'u sıfır bırakmak**: `Default::default()` kullan; elle
   doldurursan macOS traffic light renkleri elle hesaplaman gerekir.
3. **`Appearance` ile `WindowAppearance` karıştırmak**: İlki tema'nın
   nominal modu, ikincisi sistem modu. Sistem'den tema seçimi yaparken
   ikisini birbirine atama:
   ```rust
   // YANLIŞ:
   let app_appearance: Appearance = cx.window_appearance().into();  // direkt cast yok
   // DOĞRU:
   let app_appearance = match cx.window_appearance() {
       WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
       WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
   };
   ```
4. **`#[serde(rename_all = "snake_case")]` `Appearance`'ta**: JSON'da
   `"light"`/`"dark"` (küçük harf). Variant adları büyük başlangıçlı
   (`Light`/`Dark`) ama snake_case rename ile JSON'a `"light"` yazılır.
5. **`AccentColors::color_for(u32)` overflow**: `u32::MAX` versen modulo
   güvenli — usize'a cast'te 64-bit platformda taşma yok. 32-bit
   platformda dikkat ama nadir.

---

### 17. `ThemeFamily`, `SyntaxTheme`, `IconTheme`

Bu üç tip tema'nın **toplama ve uzantı** boyutunu taşır: bir paket
içinde birden fazla varyant, syntax token'larının ayrı sözleşmesi, ve
icon tema sözleşmesi.

#### `ThemeFamily`

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

```rust
pub struct ThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<Theme>,
}
```

**Rol:** Bir **paket** içinde birden fazla tema varyantı taşır. Örnek:
"One" ailesi → `One Light` ve `One Dark` themes. Zed'in `assets/themes/`
altındaki her JSON dosyası bir `ThemeFamily` deserialize'ı.

**Alan rolleri:**

| Alan | Rol |
|------|-----|
| `id` | Paket id (uuid veya stable id). |
| `name` | Paket adı (örn. "One"). |
| `author` | Paketin yazarı (örn. "Zed Industries"). |
| `themes` | Bu pakette yer alan tüm varyantlar (light + dark). |

**JSON şeması:**

```json
{
  "name": "One",
  "author": "Zed Industries",
  "themes": [
    { "name": "One Light", "appearance": "light", "style": { ... } },
    { "name": "One Dark", "appearance": "dark", "style": { ... } }
  ]
}
```

**Registry'ye yükleme:**

```rust
let family: ThemeFamilyContent = serde_json_lenient::from_slice(&bytes)?;
for theme_content in family.themes {
    let theme = Theme::from_content(theme_content, &baseline);
    registry.insert(theme);
}
```

Aile metadata'sı registry'ye geçmez — sadece tek tek `Theme`'ler
kaydedilir. Aile bilgisi `Theme.id` veya ek metadata tablosunda
saklanmak istenirse opsiyonel.

#### `SyntaxTheme`

**Kaynak crate:** `kvs_syntax_tema` (`kvs_syntax_tema/src/kvs_syntax_tema.rs`).

```rust
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

**Yapı:**

- `Vec<(String, HighlightStyle)>` — **sıralı** liste. `IndexMap` değil
  `Vec` çünkü:
  1. JSON'dan gelirken `IndexMap<String, HighlightStyleContent>` parse
     edilir (Bölüm IV/Konu 18); runtime'a `Vec`'e çevrilir.
  2. Token lookup nadir; her render hot path'te değil.
  3. `Vec` daha basit hash gerektirmeden sıralı erişim.

- **İlk eşleşme kazanır** — `style_for` linear search, find döner.
  Aynı capture iki kez varsa ilki etkin.

**JSON şeması:**

```json
{
  "syntax": {
    "comment": { "color": "#8b9eb999", "font_style": "italic" },
    "string":  { "color": "#a1c181ff" },
    "keyword": { "color": "#c678ddff", "font_weight": 700 }
  }
}
```

JSON'da object — sıra korunur (`IndexMap` ile). Rust runtime'a `Vec`
olarak alınır.

**`new()` factory `Arc` döner:**

```rust
let syntax = SyntaxTheme::new(highlights);   // Arc<SyntaxTheme>
```

Tema sisteminin tek `Arc`-sarmalanmış alt katmanı (bkz. Konu 12). Sebep:
syntax değişiminin diğer alanlardan bağımsız güncellenebilmesi ve
paylaşılabilmesi.

**Tema'da kullanım:**

```rust
let style = cx.theme().styles.syntax.style_for("comment");
// veya
let syntax: &Arc<SyntaxTheme> = &cx.theme().styles.syntax;
for (name, style) in &syntax.highlights {
    // ...
}
```

Editor entegrasyonu Bölüm VIII'de.

#### `IconTheme`

**Kaynak modül:** `kvs_tema/src/icon_theme.rs`.

Tema sistemi UI renklerinin yanı sıra **icon tema sözleşmesini** de
mirror eder ("Temel ilke" gereği — Konu 2). `IconTheme` Zed'in
`crates/theme/src/icon_theme.rs` dosyasındaki yapıya alan paritesiyle
yazılır.

**Tipik şema (Zed sözleşmesinden):**

```rust
pub struct IconTheme {
    pub id: String,
    pub name: SharedString,
    pub appearance: Appearance,
    pub directory_icons: DirectoryIcons,
    pub chevron_icons: ChevronIcons,
    pub file_stems: HashMap<String, String>,    // "Cargo.toml" → "icon-id"
    pub file_suffixes: HashMap<String, String>, // "rs" → "icon-id"
    pub file_icons: HashMap<String, IconDefinition>,
}
```

> **Uyarı:** Yukarıdaki şema **referans** niteliğindedir. Tam alan listesi
> ve alt struct'ların imzası için `../zed/crates/theme/src/icon_theme.rs`
> dosyasına bak ve sync turunda (`tema_aktarimi.md`) bu konuyu güncelle.
> Icon tema sözleşmesi UI renk sözleşmesinden daha hızlı evrilebilir.

**Rol:** Dosya/dizin/chevron icon'larının **kaynağını** tutar; UI sadece
icon id'sini bilir, asıl SVG/PNG asset registry'sinden gelir.

**Tema sözleşmesindeki yer:** Icon tema, UI tema (`Theme`) ile **kardeş**
bir kavram — `Theme.styles` içine girmez. Ayrı registry tutulabilir
(`IconThemeRegistry`) veya `ThemeRegistry`'nin metotlarına eklenir.

**JSON şeması (referans):**

```json
{
  "name": "Material Icons",
  "themes": [{
    "name": "Material",
    "appearance": "dark",
    "directory_icons": { ... },
    "chevron_icons": { ... },
    "file_stems": { "Cargo.toml": "rust-cargo" },
    "file_suffixes": { "rs": "rust", "toml": "settings" },
    "file_icons": { "rust": { "path": "icons/rust.svg" } }
  }]
}
```

**Bu rehberin scope'u:** Icon tema'nın **mirror edileceği** (alan
paritesi), **dışlanmayacağı** (Konu 2). Tam implementasyon, JSON şeması,
asset yükleme akışı ayrı bir konu olarak Bölüm VII'de işlenecek (icon
asset bundling).

#### Tuzaklar

1. **`ThemeFamily.id` kullanılmıyorsa**: Registry sadece `Theme`'leri
   isim üzerinden indeksliyor. `ThemeFamily.id` runtime'da neredeyse hiç
   sorgulanmıyor — saklamak isimsel/debug; ekstra metadata için
   gerekmiyorsa atlayabilirsin (ama Zed paritesi için tut).
2. **`SyntaxTheme::new()` doğrudan `Arc`**: `Arc::new(SyntaxTheme { ... })`
   yerine `SyntaxTheme::new(...)` çağır. Factory `Arc`'a sarar; ayrıca
   tutarlı imza.
3. **`SyntaxTheme.highlights` `HashMap` yapmak**: Token sırası anlamlı
   (ilk eşleşme kazanır). `HashMap` sırayı bozar; `Vec` veya `IndexMap`
   kullan. `IndexMap` parse zamanı, `Vec` runtime.
4. **`IconTheme` `Theme`'in içine koymak**: İki ayrı sözleşme. Birbirine
   bağlamak (`Theme.icon: IconTheme`) sync disiplinini bozar — Zed
   ikisini ayrı tutuyor, biz de tutmalıyız.
5. **`IconTheme` mirror'unu ertelemek**: "Henüz icon tema kullanmıyorum"
   = geçerli dışlama değil (Konu 2). Struct'ı tanımla, runtime
   implementasyonu sonraya bırak (`unimplemented!()` ile placeholder).

---

## Bölüm IV — JSON şeması katmanı

Bu bölüm tema sözleşmesinin **JSON tarafını** ele alır: Zed'in tema
dosyalarını okuyabilen Content tipleri, opsiyonellik kuralları, renk
parse boru hattı, hata toleransı ve JSON anahtar konvansiyonu.

> **Katmanlama hatırlatması (Bölüm I/Konu 1):**
>
> ```
> JSON dosya  →  *Content (opsiyonel string)  →  *Refinement (opsiyonel Hsla)  →  Theme (Hsla)
>                ↑ Bölüm IV                       ↑ Bölüm V                       ↑ Bölüm III
> ```
>
> Content katmanı **deserialize edilebilirlik**'i, Refinement katmanı
> **birleştirilebilirlik**'i, Theme katmanı **runtime erişimi**ni hedefler.

---

### 18. `ThemeContent` ve serde flatten/rename desenleri

**Kaynak modül:** `kvs_tema/src/schema.rs`.

JSON tema dosyalarını parse edebilen tip hiyerarşisi. Üç seviye:

```
ThemeFamilyContent      ← dosya kökü, "themes" array taşır
└── ThemeContent        ← bir tema varyantı (light veya dark)
    └── ThemeStyleContent ← tüm renk grupları flat yapıda
        ├── ThemeColorsContent  (flatten)
        ├── StatusColorsContent (flatten)
        ├── Vec<PlayerColorContent>
        ├── IndexMap<String, HighlightStyleContent>  (syntax)
        └── Option<WindowBackgroundContent>
```

#### Tip imzaları

```rust
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
```

#### `#[serde(flatten)]` — alt struct'ları aynı seviyeye açar

JSON dosyasında `style` objesi içinde **150+ alan düz olarak**
listelenir; iç içe `"colors": { ... }` yoktur. Bunu Rust'ta tutarken
mantıksal olarak grup ayrı struct'larda (`ThemeColorsContent`,
`StatusColorsContent`); ama JSON parse'ı sırasında **aynı seviyede**
deserialize edilirler. `#[serde(flatten)]` bu mapping'i sağlar.

**Davranış:**

```rust
ThemeStyleContent {
    #[serde(flatten, default)]
    pub colors: ThemeColorsContent,    // "background", "border", ...
    #[serde(flatten, default)]
    pub status: StatusColorsContent,   // "error", "warning", ...
    // ...
}
```

JSON:

```json
"style": {
  "background": "#000",       // ← ThemeColorsContent.background
  "border": "#111",           // ← ThemeColorsContent.border
  "error": "#f00",            // ← StatusColorsContent.error
  "warning": "#fa0"           // ← StatusColorsContent.warning
}
```

Iki ayrı struct'ın alanları **aynı JSON object'inde** karışık halde
deserialize edilir. Çakışan anahtar olamaz; `ThemeColorsContent`'in
"error" alanı yoksa (`StatusColorsContent`'te var) çakışma da yok.

#### `#[serde(rename = "...")]` — alan adı eşleme

Rust alan adı snake_case, JSON anahtarı dot.separated:

```rust
#[serde(rename = "border.variant")]
pub border_variant: Option<String>,
```

Detay Konu 22'de.

#### `#[serde(rename_all = "snake_case")]` — enum variant adları

`AppearanceContent`, `WindowBackgroundContent`, `FontStyleContent` gibi
**enum'lar** için variant adlarını JSON'a `snake_case` aktarmak:

```rust
#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AppearanceContent {
    Light,
    Dark,
}
```

→ JSON'da `"appearance": "light"` (Variant adı `Light` ama JSON'da
küçük harf). `rename_all = "snake_case"` her variant için tek tek
`rename` yazma yükünü ortadan kaldırır.

#### `#[serde(transparent)]` — newtype'ı saydamlaştır

```rust
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct FontWeightContent(pub f32);
```

→ JSON'da `{ "font_weight": { "0": 700 } }` yerine doğrudan
`{ "font_weight": 700 }`. Newtype'ın sarmaladığı tek alan saydam
gösterilir; JSON tüketicisi `FontWeightContent`'in newtype olduğunu
bilmez.

#### `#[serde(default)]` — eksik alana default değer

```rust
#[serde(flatten, default)]
pub colors: ThemeColorsContent,
```

JSON'da `colors` yok ise `ThemeColorsContent::default()` çağrılır =
tüm alanlar `None`. `default` annotation her bireysel alan için de
verilebilir:

```rust
#[serde(default)]
pub players: Vec<PlayerColorContent>,    // Yoksa boş Vec
```

#### Hiyerarşik özet

| Attribute | Etkisi | Tema'da örnek |
|-----------|--------|---------------|
| `#[serde(flatten)]` | Alt struct'ı aynı seviyede aç | `ThemeColorsContent`/`StatusColorsContent` flatten ile düz |
| `#[serde(rename = "x.y")]` | Alan adını bağla | `border_variant` ↔ `"border.variant"` |
| `#[serde(rename_all = "snake_case")]` | Tüm variant'lara uygula | `AppearanceContent::Light` ↔ `"light"` |
| `#[serde(transparent)]` | Newtype'ı saydamlaştır | `FontWeightContent(700.0)` ↔ `700` |
| `#[serde(default)]` | Eksik alana default | `players: []` veya yok ise boş Vec |
| `#[serde(deserialize_with = "fn")]` | Custom deserializer | `treat_error_as_none` (Konu 21) |

#### Tuzaklar

1. **`flatten` çakışması**: İki flatten'li struct'ın aynı isimli alanı
   olursa hangisinin önce parse edileceği tanımsız. Tema'da bu çakışma
   olmamalı; sözleşmede `ThemeColorsContent` ve `StatusColorsContent`
   alanları kesişmez.
2. **`flatten` performansı**: Serde flatten serde_derive'ın daha ağır
   üretimine yol açar. Tema deserialize hot path'te olmadığı için sorun
   değil; ama settings/config gibi sık çağrılan struct'ta dikkat.
3. **`rename` + alan-bazlı `default` çakışması**: `#[serde(rename =
   "x.y", default)]` doğru yazım; iki annotation tek `serde` parantezi
   içinde virgülle.
4. **`Serialize` türetmek opsiyonel**: Tema yalnız deserialize ediyorsa
   `Serialize` türetmeye gerek yok; ama `schemars::JsonSchema` veya
   round-trip test istiyorsan tut.
5. **`JsonSchema` türetimi**: `schemars` IDE auto-complete için tema
   dosyalarına JSON schema export edebilir. Türetim ücretsiz değil
   (compile time); kullanmıyorsan kaldır.

---

### 19. `*Content` tiplerinin opsiyonellik felsefesi

Content tipleri **tek bir kuralı** izler: her renk alanı `Option<String>`,
her enum alanı `Option<EnumContent>`. Hiçbir renk alanı sıkı tipli
`Hsla` veya zorunlu `String` değil.

#### Üç gerekçe

**1. Kullanıcı her alanı yazmak zorunda değil.**

Zed temalarında tipik bir tema dosyası 150 alandan 30-50 tanesini yazar;
gerisi baseline'dan dolar. Eksik alanlar parse hatası vermek yerine
`None` olarak gelmeli — refinement katmanı (Bölüm V) hangi alanın
override edildiğini, hangisinin baseline'dan kalacağını
`Some`/`None`'a göre ayırır.

**2. Renk parse hatası tüm temayı bozmamalı.**

```json
{
  "background": "#1c2025ff",     // ← geçerli
  "border": "rebeccapurple",     // ← geçersiz (named color, hex değil)
  "text": "#c8ccd4ff"            // ← geçerli
}
```

Eğer `border: String` (zorunlu) olsaydı, bir tek hatalı alan tüm temayı
hata ile yüklenmez yapar. `border: Option<String>` ile string olarak
gelir, sonra `try_parse_color` Result döner; başarısız ise refinement
`None`'a düşer ve baseline kullanılır.

**3. Tip sözleşmesi sürüm-bağımsız.**

Yarın Zed bir alana yeni bir varyant ekler (örn. `FontStyle::SemiOblique`).
Sen sync turuna gelmeden `font_style: "semi_oblique"` parse'ı patlar.
**Eğer `font_style: Option<FontStyleContent>`** ise, `treat_error_as_none`
deserializer'ı (Konu 21) bilinmeyen variant'ı `None`'a düşürür ve tema
yüklemeye devam eder.

#### İki katmanlı opsiyonellik

```
JSON          Content              Refinement       Theme
─────────────────────────────────────────────────────────
"#1c2025ff"   Some("#1c2025ff")   Some(Hsla(..))   Hsla(..)
"bozuk"       Some("bozuk")       None             baseline'dan
yok           None                 None             baseline'dan
```

**Görsel:**

- `Option<String>` katmanı = "kullanıcı bu alanı yazdı mı?"
- `Option<Hsla>` katmanı = "yazdıysa parse edilebildi mi?"

İki katman, iki ayrı hata türünü ayırt eder:

| Senaryo | Content katmanı | Refinement katmanı | Sonuç |
|---------|-----------------|--------------------|---------|
| Alan yok | `None` | `None` | Baseline |
| Alan var, geçerli hex | `Some("#...")` | `Some(Hsla(...))` | Kullanıcı override |
| Alan var, geçersiz hex | `Some("bozuk")` | `None` | Baseline (sessizce) |
| Alan var, geçerli ama farklı tip | `Some("...")` | `None` | Baseline (sessizce) |

#### `Default::default()` her Content tipinde

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    pub border: Option<String>,
    pub border_variant: Option<String>,
    // ...
}
```

`Default` türetilir; tüm alanlar `Option<_>` olduğu için default = tüm
`None`. `#[serde(default)]` struct seviyesinde tüm alanlara uygulanır.

Bu sayede JSON'da bütün bir struct (`colors`, `status`, vs.) eksik
olabilir; serde flatten katmanı `Default::default()` çağırır ve devam
eder.

#### `Option<String>` neden `Option<Hsla>` değil?

İlk akla gelen: "Madem string'i Hsla'ya çevireceğiz, baştan
`Option<Hsla>` neden olmasın?"

**Cevap:** Serde'in JSON'dan `Hsla`'ya doğrudan deserialize yolu yok.
GPUI `Hsla` için manuel `Deserialize` impl gerekirdi, ki bu da hex
string parse logic'ini struct attribute'una sokar = test edilemez,
hata mesajı kötü.

Mevcut yaklaşımda:
1. Serde sadece "string olarak al" der.
2. `try_parse_color` ayrı bir fonksiyon — birim test edilebilir.
3. Hatalı renk = string olarak content'te kalır; Refinement aşamasında
   sessizce `None`'a düşer.

Bu **sorumluluk ayrımı** sağlam: serde "yapı doğru mu?" sorusunu cevaplar,
parser "değer geçerli mi?" sorusunu cevaplar.

#### Tuzaklar

1. **`String` (Option olmadan) kullanmak**: Zorunlu alan = bir eksik alan
   tüm temayı patlatır. Sözleşmeye uygun değil.
2. **`Option<Hsla>` kullanmak (parse'ı Deserialize'a sokmak)**: Custom
   Deserialize implementasyonu test edilemez, hata mesajı kötü, parser
   katmanını sözleşmeye gömer. Mevcut iki-katman yaklaşımı tercih.
3. **`Default::default()` alanı atlamak**: `#[derive(Default)]` olmayan
   Content tipi `#[serde(default)]` kullanamaz; struct seviyesi default
   şart.
4. **`Default` ile dolu Hsla beklemek**: Content tipinin Default'u tüm
   `None` döner. Default'tan Theme inşa edilmez; refinement aşaması
   baseline ile birleştirir. "Boş tema dosyasını yüklemek = baseline"
   bilinçli.
5. **Bilinmeyen enum'a panic**: `font_style: "semi_oblique"` —
   `FontStyleContent` `SemiOblique`'i tanımıyor. Default deserialize
   panic. Çözüm: `treat_error_as_none` (Konu 21).

---

### 20. `try_parse_color`: hex → `Hsla` boru hattı

**Kaynak:** `kvs_tema/src/schema.rs` veya `kvs_tema/src/refinement.rs`
(yerleşimi kararsız).

JSON'dan gelen hex string'i runtime `Hsla`'ya çeviren tek fonksiyon:

```rust
use gpui::Hsla;
use palette::FromColor;

pub fn try_parse_color(s: &str) -> anyhow::Result<Hsla> {
    let rgba = gpui::Rgba::try_from(s)?;
    let srgba = palette::rgb::Srgba::from_components(
        (rgba.r, rgba.g, rgba.b, rgba.a)
    );
    let hsla = palette::Hsla::from_color(srgba);

    Ok(gpui::hsla(
        hsla.hue.into_positive_degrees() / 360.0,
        hsla.saturation,
        hsla.lightness,
        hsla.alpha,
    ))
}
```

#### Boru hattı 4 adım

```
"#1c2025ff"  →  gpui::Rgba  →  palette::Srgba  →  palette::Hsla  →  gpui::Hsla
  hex string    (1) parse      (2) reinterpret    (3) color-space   (4) normalize
```

**Adım 1 — Hex string'i parse:**

```rust
let rgba = gpui::Rgba::try_from(s)?;
```

`gpui::Rgba::try_from` aşağıdaki formatları kabul eder:

- `#RRGGBB` — 6 hex, alpha = 1.0
- `#RRGGBBAA` — 8 hex, alpha açıkça verilir
- `RRGGBB` (# olmadan) — `#` opsiyonel
- (büyük/küçük harf duyarsız — `#1c2025FF` ve `#1C2025ff` aynı)

Hata durumları:

- Geçersiz hex (`#zzz`): `Err`.
- Uzunluk uyumsuz (`#abc` 3 hex): `Err` (3-hex shorthand desteklenmez).
- Boş string: `Err`.

**Adım 2 — `Rgba` → `palette::Srgba`:**

```rust
let srgba = palette::rgb::Srgba::from_components(
    (rgba.r, rgba.g, rgba.b, rgba.a)
);
```

GPUI'nin `Rgba` tipi ile palette crate'inin `Srgba` tipi **aynı bellek
düzenine sahip** ama farklı crate'lerde. `from_components` tuple alıp
struct'a yerleştirir; veri kopyası yok denecek kadar küçük (4 × f32).

**Adım 3 — sRGB → HSL color space:**

```rust
let hsla = palette::Hsla::from_color(srgba);
```

`palette::Hsla` ve `palette::Srgba` farklı renk uzayında — sRGB cube'den
HSL silindirine matematiksel dönüşüm. `palette` crate'inin asıl işi
burada.

**Adım 4 — `palette::Hsla` → `gpui::Hsla`:**

```rust
gpui::hsla(
    hsla.hue.into_positive_degrees() / 360.0,
    hsla.saturation,
    hsla.lightness,
    hsla.alpha,
)
```

İki crate'in `Hsla` yapısı **uyumsuz**:

| Alan | palette | gpui |
|------|---------|------|
| `hue` | Derece (0-360°), `palette::RgbHue` newtype | Normalize (0.0-1.0), düz `f32` |
| `saturation` | 0.0-1.0 | 0.0-1.0 |
| `lightness` | 0.0-1.0 | 0.0-1.0 |
| `alpha` | 0.0-1.0 | 0.0-1.0 |

`hue.into_positive_degrees()` negatif değerleri 0-360'a normalize eder
(`-30°` → `330°`); `/ 360.0` ile GPUI normalize uzayına çekilir.

#### Dönüş tipi: `Result<Hsla>`, Caller'da `Option<Hsla>`

`anyhow::Result<Hsla>` döner. Çağıran taraf hatayı `Option`'a yutuyor:

```rust
fn color(s: &Option<String>) -> Option<gpui::Hsla> {
    s.as_deref().and_then(|s| try_parse_color(s).ok())
}
```

Bu desen Bölüm V/Konu 24'te detaylı: `Some(geçersiz hex) → None`.

#### Test ve idempotans

`try_parse_color` saf (deterministic) ve test edilebilir:

```rust
#[test]
fn parse_solid_red() {
    let c = try_parse_color("#ff0000ff").unwrap();
    assert!((c.h - 0.0).abs() < 1e-3);
    assert!((c.s - 1.0).abs() < 1e-3);
    assert!((c.l - 0.5).abs() < 1e-3);
    assert!((c.a - 1.0).abs() < 1e-3);
}

#[test]
fn rejects_named_color() {
    assert!(try_parse_color("red").is_err());
}
```

#### `palette` versiyonu önemli

`palette` major sürüm farkı color-space dönüşümünü değiştirebilir; aynı
hex farklı `Hsla` üretir. Bu yüzden:

- `tema_aktarimi.md`'deki pin Zed'in kullandığı `palette` sürümüyle
  uyumlu olmalı (Bölüm I/Konu 5).
- Fixture testleri `assert_eq!(...)` yerine `assert!((a - b).abs() <
  epsilon)` ile yazılır — küçük floating-point kayması beklenir.

#### Performans

Her renk alanı için tek bir `try_parse_color` çağrısı; bir tema ~150
renk için ~150 fonksiyon çağrısı. Tek tema yüklemesi mikrosaniye
düzeyinde. Hot path değil.

#### Tuzaklar

1. **3-hex shorthand desteksiz**: `#abc` (CSS shorthand) parse edilmez.
   Zed temalarında kullanılmaz, ama kullanıcı temasında karşılaşılırsa
   parse hatası.
2. **`palette` ihmali**: Manuel sRGB → HSL dönüşümü yazmak (palette
   olmadan) Zed davranışından sapar. Kullan.
3. **Negatif hue korunması**: `palette::Hsla::from_color` bazen `hue =
   -30°` döndürür; `into_positive_degrees()` zorunlu, atla = `h = -30/360
   = -0.083` ki GPUI bunu 0.917'ye sarmaz, **clamp eder**.
4. **`alpha = 0.0` hata gibi görünür**: Geçerli bir tema rengi (örn.
   `transparent_black`) alpha 0 olabilir. `try_parse_color` Ok döner,
   `Hsla.a = 0.0`. UI'da görünmez ama parse hatası değil — fark et.
5. **Refinement aşamasında hata yutmak**: `try_parse_color(s).ok()`
   hata mesajını siler. Debug için log: `try_parse_color(s).inspect_err(
   |e| tracing::warn!("bad color: {}", e)).ok()`.

---

### 21. Hata tolerans: `treat_error_as_none`, `deny_unknown_fields` tuzağı

Tema sözleşmesinin **forward compatibility** prensibi: gelecekte Zed
yeni bir alan veya yeni bir enum varyantı eklerse, eski kod **patlaması
yerine sessizce göz ardı etmeli**. İki ayrı vektör var: bilinmeyen
**alanlar** ve bilinmeyen **değerler**.

#### Vektör 1: Bilinmeyen alanlar — `deny_unknown_fields` YASAK

Serde varsayılan olarak bilinmeyen alanları **görmezden gelir**. Yeni
bir alan JSON'da göründüğünde mevcut Content struct'ı onu sessizce
atlar. **Bu davranış tam istediğimiz.**

```rust
// YASAK:
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]   // ← Zed yeni alan eklerse parse PATLAR
pub struct ThemeColorsContent { ... }

// DOĞRU:
#[derive(Deserialize)]
// deny_unknown_fields YOK — bilinmeyen alan göz ardı edilir
pub struct ThemeColorsContent { ... }
```

**Senaryo:** Zed `inlay_hint_background` alanı ekledi. Sen henüz mirror
etmedin. JSON'da bu anahtar var:

- `deny_unknown_fields` AÇIK: Tüm tema yüklemesi `Err("unknown field
  inlay_hint_background")`. Kullanıcı tema açamaz.
- `deny_unknown_fields` KAPALI (default): Alan sessizce atlanır. Tema
  yüklenir, sadece o alanın özelliği etkisiz. Sync turunda eklenir.

**Bu kural keskin:** Tema sözleşmesinin **hiçbir** Content tipinde
`deny_unknown_fields` kullanma.

#### Vektör 2: Bilinmeyen enum değerleri — `treat_error_as_none`

Enum alanlar için varsayılan davranış farklı: serde bilinmeyen variant
gördüğünde `Err` döner.

**Senaryo:** Zed `FontStyle::SemiOblique` ekledi. JSON: `"font_style":
"semi_oblique"`. Sen `FontStyleContent` mirror'unda bu variant yok.

- Standart deserialize: `Err("unknown variant semi_oblique, expected one
  of normal, italic, oblique")`. Tüm tema patlar.
- `treat_error_as_none` ile: Alan `None`'a düşer, devam eder.

**Custom deserializer implementasyonu:**

```rust
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

**Mekanizma:**

1. Önce alanı `serde_json::Value` olarak alır (her zaman başarılı, çünkü
   `Value` herhangi bir JSON'u alır).
2. `T::deserialize(value)` ile asıl tipe çevirir.
3. Başarılı: `Ok(Some(t))`. Başarısız: `Ok(None)` — hata yutulur.

**Kullanım:**

```rust
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
```

> **Notlar:**
>
> - `color` alanı `treat_error_as_none` kullanmaz çünkü `String` zaten
>   bilinmeyen değer kavramına sahip değil — herhangi bir string parse
>   edilir, içerik kontrolü `try_parse_color`'a düşer.
> - `font_style` ve `font_weight` `treat_error_as_none` ister çünkü
>   bunlar enum/newtype — bilinmeyen variant veya yanlış tip parse'ı
>   patlatır.
> - `#[serde(default, deserialize_with = "...")]` — iki annotation **tek
>   `serde` parantezi** içinde virgülle ayrılır.

#### Hata tolerans matrisi

| Senaryo | Default davranış | İstediğimiz | Çözüm |
|---------|------------------|-------------|-------|
| Bilinmeyen alan | Görmezden gelir | Görmezden gelinsin | Hiçbir şey yapma (`deny_unknown_fields` ekleme) |
| Bilinmeyen enum variant | Err | None'a düş | `deserialize_with = "treat_error_as_none"` |
| Yanlış tip (örn. number bekleniyor, string geldi) | Err | None'a düş | `deserialize_with = "treat_error_as_none"` |
| Hex parse hatası | (Content katmanı string olarak alır) | None'a düş | Refinement katmanında `try_parse_color(s).ok()` |
| `null` değer | None | None | Default davranış uyar |

#### Test örnekleri

```rust
#[test]
fn unknown_field_does_not_break() {
    let json = r#"{
        "name": "Test", "author": "x",
        "themes": [{
            "name": "T", "appearance": "dark",
            "style": {
                "background": "#000000ff",
                "future.unknown.field": "#ffffffff"   // ← yeni alan
            }
        }]
    }"#;
    let family: ThemeFamilyContent =
        serde_json_lenient::from_str(json).unwrap();   // parse oluyor
}

#[test]
fn unknown_font_style_falls_to_none() {
    let json = r#"{ "color": "#000", "font_style": "semi_oblique" }"#;
    let h: HighlightStyleContent = serde_json::from_str(json).unwrap();
    assert!(h.font_style.is_none());                   // bilinmeyen → None
    assert!(h.color.is_some());                        // diğer alan etkilenmez
}
```

#### Tuzaklar

1. **`deny_unknown_fields` cazibesi**: "Daha sıkı validation iyi" mantığı
   yanlış. Sözleşme **yaşayan**; sıkı validation = breaking change'lerde
   acı.
2. **`treat_error_as_none` her yerde**: Sadece enum/newtype'lar için
   gerekli. `Option<String>` zaten "yanlış değer" kavramına sahip değil;
   gereksiz boilerplate eklenir.
3. **Hata yutmayı sessizce yapmak**: Production'da `tracing::warn!` ile
   log et — kullanıcı tema dosyasındaki tipo'yu fark etmesin diye değil,
   debug için. Default log kapalı tut.
4. **`#[serde(default)]` unutmak**: `deserialize_with` yazıldığında
   default davranış değişir; `default` annotation şart, yoksa alan yoksa
   hata.
5. **`serde_json::Value` performans**: `treat_error_as_none` her alanı
   bir kez `Value`'ya, sonra tipe çevirir = iki kez parse. Hot path
   değil, tema yüklemesi nadir. Sorun değil.

---

### 22. JSON anahtar konvansiyonu (dot vs snake_case)

Tema JSON dosyalarında alan adları **dot.separated** yazılır; Rust
alan adları **snake_case**. İki konvansiyon `#[serde(rename = "...")]`
ile bağlanır.

#### Konvansiyon

| Konum | Stil | Örnek |
|-------|------|-------|
| Zed JSON dosyası | `dot.separated` | `border.variant`, `element.hover`, `text.muted`, `terminal.ansi.red` |
| Rust alan adı | `snake_case` | `border_variant`, `element_hover`, `text_muted`, `terminal_ansi_red` |
| `#[serde(rename = "...")]` | Bağlantı | `#[serde(rename = "border.variant")]` |

#### Mekanizma

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    #[serde(rename = "border")]
    pub border: Option<String>,

    #[serde(rename = "border.variant")]
    pub border_variant: Option<String>,

    #[serde(rename = "border.focused")]
    pub border_focused: Option<String>,

    #[serde(rename = "element.hover")]
    pub element_hover: Option<String>,
    // ...
}
```

**Her alan için ayrı `rename`** — `rename_all` snake_case ↔ dot dönüşümü
sağlayamaz (serde'in rename_all'u kebab-case, camelCase, PascalCase,
SCREAMING_SNAKE_CASE destekler; dot ayrımı yoktur). Yani her alan elle
işaretlenir.

#### Hiyerarşi gösterimi

Dot konvansiyonu Zed JSON'unun **görsel hiyerarşisini** korur:

```json
{
  "background": "#000",                  // genel arka plan
  "background.appearance": "opaque",     // pencere arka plan tipi
  "border": "#111",                      // ana border
  "border.variant": "#222",              // alternatif border
  "border.focused": "#3a8",              // focus durumunda border
  "border.disabled": "#444",             // disabled durumunda border
  "element.hover": "#332",               // element üzerinde hover
  "element.active": "#443",              // element basılı
  "element.selected": "#a83",            // element seçili
  "terminal.ansi.red": "#f00",           // terminal ANSI 8 kırmızı
  "terminal.ansi.bright_red": "#f44"     // terminal ANSI bright kırmızı
}
```

Tek bir alfabetik sıralama ile **mantıksal gruplar** yan yana gelir —
`border` ailesinin tamamı, `element` ailesinin tamamı, `terminal.ansi`
ailesinin tamamı. Snake_case'te bu sıralama bozulurdu (`border_variant`,
`border_focused`, `border_disabled` alfabetik olarak `disabled`,
`focused`, `variant` sırasında dağılır).

#### Çift altçizgi konvansiyonu (boundary case)

Bazı alanlar **iki seviye** dot konvansiyon taşır:

| JSON | Rust |
|------|------|
| `terminal.ansi.red` | `terminal_ansi_red` |
| `terminal.ansi.bright_red` | `terminal_ansi_bright_red` |
| `version_control.added` | `version_control_added` |

Yani: dot **alt seviye ayrımı**, underscore **kelime ayrımı**. JSON
anahtarındaki underscore Rust adında korunur:

```json
"terminal.ansi.bright_red": "#ff5555"
```

```rust
#[serde(rename = "terminal.ansi.bright_red")]
pub terminal_ansi_bright_red: Option<String>,
```

#### Status renklerinde özel durum

`StatusColors`'ta `_background` ve `_border` Rust suffix'leri JSON'da
**ayrı dot seviyesi** olur:

| Rust alan | JSON anahtarı |
|-----------|---------------|
| `error` | `error` |
| `error_background` | `error.background` |
| `error_border` | `error.border` |
| `success_background` | `success.background` |

```rust
#[serde(rename = "error")]
pub error: Option<String>,

#[serde(rename = "error.background")]
pub error_background: Option<String>,

#[serde(rename = "error.border")]
pub error_border: Option<String>,
```

#### Pratik liste

Yaygın renk grupları için Rust ↔ JSON eşlemesi:

| Rust | JSON |
|------|------|
| `border` | `border` |
| `border_variant` | `border.variant` |
| `border_focused` | `border.focused` |
| `border_selected` | `border.selected` |
| `border_transparent` | `border.transparent` |
| `border_disabled` | `border.disabled` |
| `surface_background` | `surface.background` |
| `elevated_surface_background` | `elevated_surface.background` |
| `element_background` | `element.background` |
| `element_hover` | `element.hover` |
| `element_active` | `element.active` |
| `element_selected` | `element.selected` |
| `element_disabled` | `element.disabled` |
| `ghost_element_background` | `ghost_element.background` |
| `text_muted` | `text.muted` |
| `text_placeholder` | `text.placeholder` |
| `text_accent` | `text.accent` |
| `icon_muted` | `icon.muted` |
| `terminal_ansi_red` | `terminal.ansi.red` |
| `terminal_ansi_bright_red` | `terminal.ansi.bright_red` |
| `error_background` | `error.background` |
| `version_control_added` | `version_control.added` |

> **Kaynak doğrulama:** Bu tablo Zed'in
> `../zed/crates/settings_content/src/theme.rs` dosyasındaki
> `#[serde(rename = "...")]` annotation'larıyla **birebir eşleşmeli**.
> Sync turunda yeni alanlar gelirse tabloyu güncelle. Şüphe varsa
> kaynak dosyaya bak.

#### Tuzaklar

1. **`rename` olmadan snake_case beklemek**: `border_variant` (Rust)
   yazıp `rename` koymazsan, serde JSON'da `"border_variant"` bekler.
   Zed JSON'unda `"border.variant"` yazıyor → alan **sessizce boş kalır**
   (`None`). En yaygın hata.
2. **`rename` typo'su**: `#[serde(rename = "boder.variant")]` (typo'lu).
   Compile hatası olmaz, parse'ta alan boş kalır. Test fixture ile
   yakalanır.
3. **`rename_all` snake_case'e güvenmek**: `#[serde(rename_all =
   "snake_case")]` Rust ↔ snake_case JSON dönüşümü için; dot konvansiyonu
   için **işe yaramaz**. Her alanı elle işaretle.
4. **Dot içinde alanı tek kelime sanmak**: `border.variant` Rust'ta iki
   alan değil tek alan (`border_variant`). Dot kelime ayırıcı değil, dot
   hiyerarşi ayırıcı.
5. **`status.error` yerine `error.status`**: Status renklerinde JSON
   prefix `error.background`, **`status.error_background` değil**.
   StatusColors flatten ile düz seviyeye açılır; "status" anahtarı
   yoktur. Aynı şey `colors.background` yerine `background` için de
   geçerli.
6. **JSON 'da hem `border_variant` hem `border.variant` yazmak**:
   Kullanıcı temasında bu iki anahtar görünürse hangisinin kazanacağı
   tanımsız. Geliştirici doc'unda **sadece dot konvansiyonu**'nu önder.

---

## Bölüm V — Refinement katmanı

Refinement, **JSON dosyasından gelen opsiyonel string renkleri** ile
**runtime'da kullanılacak tam tipli `Theme`** arasında köprü kuran orta
katmandır. İki temel iş yapar: opsiyonelliği `Hsla`'ya dönüştürür ve
baseline tema ile kullanıcı temasını birleştirir.

> **Mimari hatırlatma (Konu 1):**
>
> ```
> *Content (Option<String>)        ←  Bölüm IV
>      │
>      │  theme_colors_refinement / status_colors_refinement
>      ▼
> *Refinement (Option<Hsla>)       ←  Konu 24
>      │
>      │  apply_status_color_defaults (türetme kuralları)
>      ▼
> *Refinement (Option<Hsla>, türetilmiş)  ← Konu 25
>      │
>      │  baseline.refine(&refinement)    (refineable crate)
>      ▼
> Theme (Hsla)                     ←  Bölüm III
> ```
>
> Refinement katmanı **saf veri dönüşümü**: GPUI runtime'ı veya pencere
> bilmez; sadece tip dönüştürür ve `Refineable` trait'ini çağırır.

---

### 23. Content → Refinement → Theme akışı

**Kaynak modül:** `kvs_tema/src/refinement.rs`.

Üç katmanlı boru hattının orta halkası. Davranışı **stateless** ve
**deterministic**: aynı `Content` aynı `Refinement`'ı üretir.

#### Üç katmanın rolü

| Katman | Tip | Soru | Üretildiği yer |
|--------|-----|------|----------------|
| **Content** | `Option<String>` alanlar | Kullanıcı bu alanı yazdı mı? | JSON parse (Bölüm IV) |
| **Refinement** | `Option<Hsla>` alanlar | Yazdıysa parse edilebildi mi? | `refinement.rs` (Konu 24) |
| **Theme** | `Hsla` alanlar | Sonuç ne? | `Theme::from_content` (Konu 26) |

#### Neden iki ayrı `Option` katmanı?

İlk akla gelen: "Madem string'i Hsla'ya çevireceğiz, neden tek katmanda
yapmayalım?"

**Cevap:** İki **farklı hata türünü** ayırt etmek gerek:

- **Tip-yapısal hata** (Content katmanı): JSON anahtarı yanlış, tip
  yanlış, bilinmeyen enum variant. Serde bunu deserialize sırasında
  yakalar. `treat_error_as_none` (Konu 21) ile `None`'a düşer.
- **Değer-içerik hatası** (Refinement katmanı): String var ama hex
  değil (`"rebeccapurple"`), veya hex'in formatı bozuk (`"#zzz"`).
  `try_parse_color` döner `Err`; refinement bunu sessizce `None`'a yutar.

İki katman = her hata kendi katmanında durdurulur; üst katmanları
kirletmez.

#### Akış görünümü — örnek bir alan

Kullanıcı tema JSON'unda:

```json
"border.variant": "#363c46ff"
```

Adım adım:

**1. Content katmanı** (Bölüm IV):

```rust
ThemeColorsContent {
    border_variant: Some("#363c46ff".to_string()),
    border: None,                  // JSON'da yok
    border_focused: None,
    // ...
}
```

**2. Refinement katmanı** (Konu 24):

```rust
ThemeColorsRefinement {
    border_variant: Some(hsla(...)),   // try_parse_color başarılı
    border: None,                       // Content'te None idi
    border_focused: None,
    // ...
}
```

**3. Theme katmanı** (Konu 26):

```rust
let mut theme = baseline.clone();
theme.styles.colors.refine(&refinement);
// theme.styles.colors.border_variant = kullanıcının değeri
// theme.styles.colors.border        = baseline'ın değeri (None idi)
```

#### Refinement katmanının üç dönüşümü

`refinement.rs` modülünün sorumlulukları:

1. **String → Hsla**: `theme_colors_refinement`, `status_colors_refinement`,
   ve dolaylı olarak `accents`/`players`/`syntax` (Theme::from_content
   içinde).
2. **Türetme** (`apply_status_color_defaults`): fg verilmiş ama bg
   verilmemiş status alanlarına %25 alpha bg üretir.
3. **Refineable çağrısı**: `baseline.refine(&refinement)` ile baseline'ı
   günceller. (Bu adım Konu 26'da; refinement.rs `refine` çağrısı
   yapmaz, sadece Refinement üretir.)

#### Modülün dış arayüzü

`refinement.rs` kararlı dış API'leri:

```rust
pub fn theme_colors_refinement(c: &ThemeColorsContent) -> ThemeColorsRefinement;
pub fn status_colors_refinement(c: &StatusColorsContent) -> StatusColorsRefinement;
pub fn apply_status_color_defaults(r: &mut StatusColorsRefinement);
```

Crate-içi kararsız helper'lar:

```rust
fn color(s: &Option<String>) -> Option<gpui::Hsla>;  // tek-satır parse
```

> **Konu 4 (modül haritası)'nda `refinement.rs` "crate-içi" olarak
> işaretliydi.** Tek istisna: `apply_status_color_defaults` ve
> `*_refinement` fonksiyonları Theme::from_content tarafından çağrılır;
> ama tüketici (UI katmanı) bu modüle dokunmaz.

#### Saflık ve test edilebilirlik

Refinement katmanı **dış dünyaya hiç dokunmaz**:

- GPU/render API yok.
- `App`/`Context` yok.
- I/O yok.
- Lock/global state yok.

→ Birim testler tamamen unit-test edilebilir:

```rust
#[test]
fn empty_content_produces_empty_refinement() {
    let r = theme_colors_refinement(&ThemeColorsContent::default());
    assert!(r.border.is_none());
    assert!(r.background.is_none());
}

#[test]
fn invalid_hex_is_swallowed_to_none() {
    let c = ThemeColorsContent {
        border: Some("not-a-color".to_string()),
        ..Default::default()
    };
    let r = theme_colors_refinement(&c);
    assert!(r.border.is_none());
}
```

#### Tuzaklar

1. **Refinement'i tüketici API'ye sızdırmak**: UI katmanı sadece `Theme`
   görmeli. `Refinement` tipini export etmek tüketici kodu Zed sözleşmesi
   evrim'ine bağlar; iç düzen değişince breaking change.
2. **Refinement'i klonlamak**: `Refinement` 150 `Option<Hsla>` alanı
   içerir; klon ucuz ama gereksiz. `&refinement` ile geç.
3. **`refine()` öncesi `apply_status_color_defaults`'u atlamak**:
   Türetme uygulanmazsa fg-only status temaları baseline'ın bg'sini
   tutar = kullanıcı renkleriyle uyumsuz görüntü. Şart (Konu 25).
4. **Refinement'ı global tutmak**: Refinement geçici bir nesne;
   `from_content` çağrısı içinde yaratılır, kullanılır, düşürülür.
   `static` veya `Arc` ile tutma — anlamsız.

---

### 24. `theme_colors_refinement`, `status_colors_refinement` deseni

İki yardımcı fonksiyon Content tipini Refinement tipine çevirir. **Tek
desenle** çalışır: her alanı `color()` helper'ından geçirir.

#### `color()` helper — temel yapı taşı

```rust
fn color(s: &Option<String>) -> Option<gpui::Hsla> {
    s.as_deref().and_then(|s| try_parse_color(s).ok())
}
```

**Davranış:**

```
Option<String>  →  Option<Hsla>
─────────────────────────────────
None            →  None
Some("...")     →  Some(hsla(...))  (parse başarılı)
Some("bozuk")   →  None             (parse hatası yutulur)
```

Üç dal:

1. `s.as_deref()`: `&Option<String>` → `Option<&str>`. Klonsuz, sıfır
   maliyet.
2. `and_then(|s| try_parse_color(s).ok())`: `Some(s)` ise parse dene;
   `Err` ise `None`. `try_parse_color` Konu 20'de.

`color()` `refinement.rs` modülünün **dahili** yardımcısı (`pub`
değil); her renk alanı için tek-satır mantığı tek yere toplar.

#### `theme_colors_refinement` deseni

```rust
pub fn theme_colors_refinement(c: &ThemeColorsContent) -> ThemeColorsRefinement {
    ThemeColorsRefinement {
        border: color(&c.border),
        border_variant: color(&c.border_variant),
        border_focused: color(&c.border_focused),
        border_selected: color(&c.border_selected),
        border_transparent: color(&c.border_transparent),
        border_disabled: color(&c.border_disabled),

        background: color(&c.background),
        surface_background: color(&c.surface_background),
        elevated_surface_background: color(&c.elevated_surface_background),

        element_background: color(&c.element_background),
        element_hover: color(&c.element_hover),
        // ... ~150 alan, hepsi aynı kalıpta

        ..Default::default()
    }
}
```

**Yapı kuralları:**

- **Her alan tek satır**: `<alan_adi>: color(&c.<alan_adi>),`
- **`..Default::default()` zorunlu**: Macro üretilen Refinement tipinin
  tüm alanlarını açıkça vermek istemiyorsan default fallback gerek. Tema
  sözleşmesi büyüdükçe (Zed yeni alan ekledikçe) bu kalıp esneklik
  sağlar — yeni alanı mirror etmeden önce de derleme bozulmaz.

> **Sync turunda dikkat:** Zed yeni bir alan eklediğinde (`new_color`),
> Refinement tipinde otomatik olarak `new_color: Option<Hsla>` belirir.
> `..Default::default()` sayesinde `theme_colors_refinement` derlenmeye
> devam eder; ama **yeni alanı eklemezsen kullanıcı temasındaki değer
> sessizce kaybolur** (sözleşme delinmesi). Sync turunda manuel ekleme
> şart.

#### `status_colors_refinement` deseni

```rust
pub fn status_colors_refinement(c: &StatusColorsContent) -> StatusColorsRefinement {
    StatusColorsRefinement {
        conflict: color(&c.conflict),
        conflict_background: color(&c.conflict_background),
        conflict_border: color(&c.conflict_border),

        created: color(&c.created),
        created_background: color(&c.created_background),
        created_border: color(&c.created_border),

        // ... 14 status × 3 alan = 42 alan, hepsi color() üzerinden

        ..Default::default()
    }
}
```

Aynı kalıp. Her status üçlüsü (fg, bg, border) ayrı satır.

#### Neden macro veya `From` impl değil?

İlk akla gelen: "Bu kadar tekrarlı kod için macro yazılır."

**Karşı argüman:**

- **Görsel arama**: Bir alanın refinement'ta nasıl handle edildiğini
  bulmak için `grep "border_variant"` yeterli. Macro varsa bu zincir
  saklı.
- **Mirror disiplini**: Sync turunda yeni alan geldiğinde manuel ekleme
  zorunluluğu **iyi bir şey**. Macro otomatik üretirse alanı eklemeyi
  unutmak kolay; refinement boş döner.
- **Derleme süresi**: Üç ek satır × 150 alan = 450 satır kod. Macro
  proc-macro derleme süresinden daha hızlı.
- **IDE deneyimi**: `color(&c.border_variant)` üzerine "go to
  definition" Content alanına gider; macro üzerinde IDE indirgemeleri
  öğrenmiyor.

Zed kendi `refinement.rs`'sinde de macro kullanmaz; aynı tek-satır
desenidir.

#### `From` trait impl alternatifi

```rust
impl From<&ThemeColorsContent> for ThemeColorsRefinement { ... }
```

Çalışır, ama:

- Trait nesnesi olarak çağırmak kafa karıştırıcı: `let r:
  ThemeColorsRefinement = (&content.colors).into();` yerine
  `theme_colors_refinement(&content.colors)` daha net.
- Birden fazla Refinement tipi var (ThemeColors + StatusColors); her biri
  ayrı `From` impl gerekir, dosyada `From` trait'ler arasında kaybolur.

Mevcut fonksiyon yaklaşımı **görünür dış API**. Refinement modülünün
yaptığı işin tüm yüzeyi üç fonksiyon imzasıyla okunur.

#### `accents`, `players`, `syntax` neden burada değil?

Bu üç katman `*Content` opsiyonelliği değil, **liste/map** sözleşmesi
taşır. Tek alan-bazlı refinement yetmez; `Theme::from_content` içinde
inline işlenir:

- `accents: Vec<Option<String>>` — refinement değil, **boş ise baseline
  / dolu ise listeyi yeniden parse** kararı (Konu 26).
- `players: Vec<PlayerColorContent>` — aynı boş/dolu kararı.
- `syntax: IndexMap<String, HighlightStyleContent>` — `Vec<(String,
  HighlightStyle)>` üretimi.

Bunlar `*_refinement` fonksiyonu altında modellenmez çünkü `Refineable`
derive `Vec` veya `IndexMap` üzerinde nasıl davranacağını bilmez
(`Refinement = Option<Vec<...>>` mı, yoksa `Vec<Option<...>>` mı?).
Inline işleme daha basit.

#### Tuzaklar

1. **`color(c.border)` yerine `color(&c.border)`**: Helper `&Option<String>`
   bekler, `Option<String>` değil. Move alma istemezsin; clone'lu reflex.
2. **`..Default::default()` atlamak**: Yeni alan eklenince derleme bozulur.
   Atlama; zaten verilen alanları override etmez.
3. **`as_deref` yerine `as_ref().map(String::as_str)`**: Aynı sonuç,
   uzun yazım. `as_deref()` idiomatik.
4. **Hata loglaması**: Parse hatası sessizce `None`'a düşer. Production
   debug için:
   ```rust
   fn color(s: &Option<String>) -> Option<gpui::Hsla> {
       s.as_deref().and_then(|s| {
           try_parse_color(s)
               .inspect_err(|e| tracing::warn!("color parse failed: {}", e))
               .ok()
       })
   }
   ```
   Default'ta sessiz tut; opt-in log.
5. **`status_colors_refinement` 42 alanı yazmamak**: 14 × 3 = 42 alan
   var; kısayol yok. `..Default::default()` ile eksik alanları tutmaya
   güvenme — refinement uygulanmaz, kullanıcı temasıyla baseline arasında
   sessiz tutarsızlık çıkar.

---

### 25. `apply_status_color_defaults`: %25 alpha türetme kuralı

`StatusColors` sözleşmesinin özel bir davranışı var: tema yazarı bir
durum için **sadece foreground** verirse, **background**'u otomatik
olarak **%25 alpha**'lı versiyonundan türetmeli. Bu kural Zed'in
tema davranışıyla **birebir tutmak için** gerekli — yoksa kullanıcı
temaları yarı-baseline yarı-yeni karışım renklere düşer.

#### Kural

**Eğer:** Refinement'ta `<status>` foreground `Some(fg)` ama
`<status>_background` `None` ise,
**Yap:** `<status>_background = Some(fg.opacity(0.25))`.

```rust
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

#### Hangi status için türetme uygulanır?

**6 status:** `deleted`, `created`, `modified`, `conflict`, `error`,
`hidden`.

| Status | Türetme uygulanır mı | Neden |
|--------|---------------------|-------|
| `deleted` | ✓ | VCS göstergesi — fg/bg ilişkisi anlamlı |
| `created` | ✓ | VCS göstergesi |
| `modified` | ✓ | VCS göstergesi |
| `conflict` | ✓ | VCS göstergesi |
| `error` | ✓ | Diagnostic — error vurgusu fg'den türetilebilir |
| `hidden` | ✓ | Gizli öğeler için fade |
| `hint` | ✗ | Diagnostic — bg genelde transparan veya farklı |
| `info` | ✗ | Diagnostic — bg ayrı tema |
| `success` | ✗ | UI feedback — bg kullanıcıya net |
| `warning` | ✗ | Diagnostic — bg ayrı tema |
| `predictive` | ✗ | AI tahmin — özel renk |
| `ignored` | ✗ | VCS — bg genelde transparan |
| `renamed` | ✗ | VCS — bg uyumsuz türetmiş olur |
| `unreachable` | ✗ | Kod — bg genelde transparan |

> **Bu seçim Zed'in `refine_theme_family` davranışını birebir kopyalar.**
> Listeyi değiştirmek istiyorsan Zed kaynağına bak (`crates/theme/...`)
> ve gerekçeyi `DECISIONS.md`'ye yaz.

#### `_border` türetilmez

Sadece `_background` türetilir; `_border` `None` ise baseline'dan kalır.
Tema yazarı `error: "#ff5555"` yazarsa:

- `error` = `Some(hsla(...))`
- `error_background` = türetildi (`#ff555540` benzeri)
- `error_border` = baseline'dan (eğer tema yazarı vermediyse)

Bu kasıtlı — border renginin %50 alpha versiyonu makul olmayabilir;
ayrı bir kararla yazılması beklenir.

#### Mekanizma detayı

```rust
let pairs: &mut [(&mut Option<_>, &mut Option<_>)] = &mut [
    (&mut r.deleted, &mut r.deleted_background),
    // ...
];
```

**`&mut Option<_>` çiftleri**: Rust borrow checker'ı aynı struct'tan
birden fazla `&mut` referans almayı yasaklar; ama farklı **alanlar**
olduğu için izinli. `pairs` array'i bu çiftleri tek slice'ta toplar.

```rust
for (fg, bg) in pairs {
    if bg.is_none() && let Some(fg) = fg.as_ref() {
        **bg = Some(fg.opacity(0.25));
    }
}
```

- `bg.is_none()`: bg verilmemiş.
- `let Some(fg) = fg.as_ref()`: if-let chain (Rust 2024) — fg verilmişse.
- `**bg = ...`: `bg` `&mut &mut Option<Hsla>` (içeri çıkarmak için iki
  deref); değer set ediliyor.
- `fg.opacity(0.25)`: `Hsla::opacity` Konu 6'da.

#### Çağrı yeri

`apply_status_color_defaults` `Theme::from_content` içinde **sadece bir
yerde** çağrılır:

```rust
let mut status_refinement = status_colors_refinement(&content.style.status);
apply_status_color_defaults(&mut status_refinement);  // ← burada
let mut status = baseline.styles.status.clone();
status.refine(&status_refinement);
```

Sırlama:
1. Content'ten refinement üret (Konu 24).
2. Refinement'a türetme uygula (Konu 25).
3. Baseline'a refinement uygula (Konu 26).

#### `theme_color_defaults` muadili?

`ThemeColors` (status değil, normal renkler) için bir türetme yardımcısı
**yoktur**. Sebep: UI renklerinde fg/bg ilişkisi yoktur; `border_variant`
ve `surface_background` farklı alanlardır. Türetme yapay kalır.

Zed'de `apply_theme_color_defaults` adında bir fonksiyon **var**, ama
yaptığı şey tek bir özel durum (`element_selection_background = text_accent
* 0.25` gibi); senin sözleşmenin sadeliği bunu pas geçer. Sync turunda
yeni türetme görürsen değerlendir.

#### Test örnekleri

```rust
#[test]
fn fg_only_derives_bg() {
    let mut r = StatusColorsRefinement::default();
    r.error = Some(gpui::hsla(0.0, 0.8, 0.5, 1.0));
    // error_background None

    apply_status_color_defaults(&mut r);

    assert!(r.error_background.is_some());
    let bg = r.error_background.unwrap();
    assert!((bg.a - 0.25).abs() < 1e-6);
    // h, s, l fg ile aynı
    assert_eq!(bg.h, r.error.unwrap().h);
}

#[test]
fn explicit_bg_is_preserved() {
    let mut r = StatusColorsRefinement::default();
    r.error = Some(gpui::hsla(0.0, 0.8, 0.5, 1.0));
    r.error_background = Some(gpui::hsla(0.0, 0.0, 0.0, 0.5)); // siyah yarı

    apply_status_color_defaults(&mut r);

    let bg = r.error_background.unwrap();
    assert_eq!(bg.h, 0.0);  // override edilmedi
    assert_eq!(bg.l, 0.0);
}

#[test]
fn neither_fg_nor_bg() {
    let mut r = StatusColorsRefinement::default();
    // error ve error_background None

    apply_status_color_defaults(&mut r);

    assert!(r.error.is_none());
    assert!(r.error_background.is_none());  // hâlâ None
}
```

#### Tuzaklar

1. **`opacity(0.25)` yerine `alpha(0.25)`**: `opacity(x)` mevcut alpha'yı
   `* x` ile çarpar; `alpha(x)` direkt set eder. Foreground genelde
   alpha 1.0 olduğu için ikisi de aynı sonucu verir ama prensipte
   farklı. Zed kullanır `opacity`; biz de.
2. **6 status'u listede unutmak**: Eksik kalan status (örn. `modified`
   eklenmedi) için türetme çalışmaz; kullanıcı sadece fg yazsa bg
   baseline'dan gelir. Liste tam olmalı.
3. **`pairs` slice'ı tekrar kullanmak**: `&mut [...]` literal her çağrıda
   yeniden üretilir; performans değil. Hot path değil.
4. **`if-let chain` syntax**: `if bg.is_none() && let Some(fg) = fg.as_ref()`
   Rust 2024 edition syntax'ı. Edition < 2024 ise nested `if let` yaz:
   ```rust
   if bg.is_none() {
       if let Some(fg) = fg.as_ref() {
           **bg = Some(fg.opacity(0.25));
       }
   }
   ```
5. **`_border` türetmesi eklemek**: Sözleşme dışı — kullanıcı temasıyla
   uyumsuz görüntü riski. Eklemek istiyorsan ayrı bir karar (DECISIONS.md).
6. **Türetme sırası**: `apply_status_color_defaults` `refine()`'dan
   **önce** çağrılmalı. Sonra çağırırsan baseline'ın `_background`
   değeri zaten yazılmıştır; türetme yerini bulamaz.

---

### 26. `Theme::from_content` birleşik akış

**Kaynak modül:** `kvs_tema/src/refinement.rs` veya `kvs_tema.rs` (lib
kökü). Yerleşim kararsız ama tek bir `impl Theme` bloğu.

Refinement katmanının **dışa dönük tek fonksiyonu**. Tek argümanla
çağrılır: kullanıcı tema içeriği + baseline tema. Üretir: tam bir
`Theme`.

```rust
impl Theme {
    pub fn from_content(content: ThemeContent, baseline: &Theme) -> Self { ... }
}
```

**İmza ayrıntısı:**

- `content: ThemeContent` — **sahip alır** (move). Caller çağrı sonrası
  Content'i kullanamaz; ama bu Content tipi zaten throw-away (parse
  sonrası kullanmazsın).
- `baseline: &Theme` — **referans**. Baseline registry'de durur;
  klonlamak gerekirse fonksiyon içinde `.clone()` çağrılır.
- Dönüş: `Self` (`Theme`).

#### 6 adımlı akış

```rust
pub fn from_content(content: ThemeContent, baseline: &Theme) -> Self {
    // 1. Appearance dönüşümü
    let appearance = match content.appearance {
        AppearanceContent::Light => Appearance::Light,
        AppearanceContent::Dark => Appearance::Dark,
    };

    // 2. Renk refinement'larını üret + türetme uygula
    let mut color_refinement = theme_colors_refinement(&content.style.colors);
    let mut status_refinement = status_colors_refinement(&content.style.status);
    apply_status_color_defaults(&mut status_refinement);

    // 3. Baseline'ı klonla, refinement uygula
    let mut colors = baseline.styles.colors.clone();
    colors.refine(&color_refinement);

    let mut status = baseline.styles.status.clone();
    status.refine(&status_refinement);

    // 4. Accents: boş ise baseline, dolu ise parse
    let accents = if content.style.accents.is_empty() {
        baseline.styles.accents.clone()
    } else {
        AccentColors(
            content.style.accents.iter()
                .filter_map(|c| c.as_deref().and_then(|s| try_parse_color(s).ok()))
                .collect(),
        )
    };

    // 5. Players: boş ise baseline, dolu ise alan-bazlı parse
    let player = if content.style.players.is_empty() {
        baseline.styles.player.clone()
    } else {
        PlayerColors(
            content.style.players.iter().map(|p| PlayerColor {
                cursor: p.cursor.as_deref()
                    .and_then(|s| try_parse_color(s).ok())
                    .unwrap_or(baseline.styles.player.local().cursor),
                background: p.background.as_deref()
                    .and_then(|s| try_parse_color(s).ok())
                    .unwrap_or(baseline.styles.player.local().background),
                selection: p.selection.as_deref()
                    .and_then(|s| try_parse_color(s).ok())
                    .unwrap_or(baseline.styles.player.local().selection),
            }).collect(),
        )
    };

    // 6. Syntax: IndexMap → Vec<(String, HighlightStyle)>
    let syntax_highlights = content.style.syntax.iter()
        .map(|(name, style)| (name.clone(), highlight_style(style)))
        .collect();
    let syntax = SyntaxTheme::new(syntax_highlights);

    // 7. Pencere bg: enum eşleme veya baseline'dan
    let window_background_appearance = match content.style.window_background_appearance {
        Some(WindowBackgroundContent::Opaque) => WindowBackgroundAppearance::Opaque,
        Some(WindowBackgroundContent::Transparent) => WindowBackgroundAppearance::Transparent,
        Some(WindowBackgroundContent::Blurred) => WindowBackgroundAppearance::Blurred,
        None => baseline.styles.window_background_appearance,
    };

    // 8. Theme yapısını topla
    Self {
        id: uuid::Uuid::new_v4().to_string(),
        name: SharedString::from(content.name),
        appearance,
        styles: ThemeStyles {
            window_background_appearance,
            system: baseline.styles.system.clone(),  // SystemColors hep baseline
            colors,
            status,
            player,
            accents,
            syntax,
        },
    }
}
```

#### Adım adım davranış

**Adım 1 — Appearance enum dönüşümü.**

`AppearanceContent::Light` (Bölüm IV) → `Appearance::Light` (Bölüm III).
İki ayrı enum tipi: Content tipi serde için, Theme tipi runtime için.
Doğrudan cast yok; explicit match.

**Adım 2 — Renk refinement'ları + türetme.**

`theme_colors_refinement` ve `status_colors_refinement` Konu 24'te.
`apply_status_color_defaults` Konu 25'te. Sıralama: refinement'lar
**sonra** türetme.

**Adım 3 — Baseline.refine().**

```rust
let mut colors = baseline.styles.colors.clone();
colors.refine(&color_refinement);
```

`Refineable::refine` (Bölüm II/Konu 11) — `Some` alanları override eder,
`None` baseline'dan kalır.

**`.clone()` neden?** `baseline: &Theme` immutable; doğrudan üzerinde
`refine` çağıramayız. Baseline registry'de paylaşıldığı için
modifiye edilemez; her tema kendi kopyasını alır.

**Maliyet:** `ThemeColors` ~150 `Hsla` = 150 × 16 byte = 2.4 KiB klon.
`StatusColors` 42 alan = ~700 byte. Toplam ~3 KiB per tema, yüklenirken
bir kez. Hot path değil.

**Adım 4 — Accents: boş/dolu kararı.**

```rust
let accents = if content.style.accents.is_empty() {
    baseline.styles.accents.clone()       // tema vermedi → baseline
} else {
    AccentColors(content.style.accents.iter()
        .filter_map(|c| c.as_deref().and_then(|s| try_parse_color(s).ok()))
        .collect())                        // tema verdi → parse et
};
```

**Önemli:** Accents için **alan-bazlı refinement değil, liste-bazlı**.
Tema yazarı `accents: []` veya alan yazmadıysa baseline korunur; bir
veya daha fazla accent yazdıysa **tamamen yeni liste**.

`filter_map`: `Vec<Option<String>>`'ten `Vec<Hsla>`'ya. Null girdiler ve
parse hataları **sessizce elenir** (mevcut indekslemeyi bozar).

> **Tuzak:** Tema yazarı `accents: ["#aaa", null, "#bbb"]` yazarsa,
> beklenen davranış [accent[0]=#aaa, accent[1]=null=skip, accent[2]=#bbb]
> olabilir. Mevcut kod `filter_map` ile null'ları **eler** = [#aaa, #bbb].
> İndeksleme kayar; #bbb şu an accent index 1. Bu Zed davranışıyla
> uyumlu mu? Zed kaynağına bak; uyumsuzluk varsa düzelt.

**Adım 5 — Players: alan-bazlı.**

```rust
PlayerColors(content.style.players.iter().map(|p| PlayerColor {
    cursor: p.cursor.as_deref()
        .and_then(|s| try_parse_color(s).ok())
        .unwrap_or(baseline.styles.player.local().cursor),
    // background, selection aynı kalıp
}).collect())
```

PlayerColor 3 alanı (cursor/background/selection) ayrı parse; her birinin
fallback'i **baseline'ın local player'ı**. Bu çakışmaya dikkat:

- Tema yazarı `players: [{ "cursor": "#abc" }, { "cursor": "#def" }]`
  yazdı.
- Player 0'ın cursor'u #abc, background ve selection baseline.local()'tan.
- Player 1'in cursor'u #def, background ve selection **yine baseline.local()'tan**.

Yani tüm player slot'larının fallback'i tek bir kaynaktan (local) gelir.
Tek tek slot'lara ayrı fallback **yok**. Bu Zed davranışıyla aynı; istisnai
bir tasarım kararı.

**Adım 6 — Syntax: `IndexMap` → `Vec<(String, HighlightStyle)>`.**

Content tarafında `IndexMap<String, HighlightStyleContent>` (sıra
korunur). Runtime tarafında `Vec<(String, HighlightStyle)>`. `highlight_style`
helper (Konu 7) her `HighlightStyleContent`'i `HighlightStyle`'a çevirir.

`SyntaxTheme::new()` `Arc`'a sarar; runtime'da paylaşılabilir.

**Adım 7 — Pencere bg: enum dönüşüm veya fallback.**

```rust
match content.style.window_background_appearance {
    Some(...) => /* Content variant'ından GPUI variant'ına */,
    None => baseline.styles.window_background_appearance,
}
```

Tema yazarı vermediyse baseline'dan; verdiyse Content enum'undan GPUI
enum'una explicit match.

**Adım 8 — Theme yapısını topla.**

- `id`: `uuid::Uuid::new_v4().to_string()` — her seferinde yeni unique
  id. Aynı tema iki kez yüklenirse iki farklı id alır; runtime'da
  ayırt etmek için (genelde gerekmez).
- `name`: `SharedString::from(content.name)`. Content'in `name: String`
  alanı klonsuz `SharedString`'e sarmalanır.
- `appearance`: Adım 1.
- `styles.system`: Baseline'dan klonlanır (tema yazarı sistem renklerini
  override etmez).
- Diğerleri: Adım 3-7'den.

#### Edge case'ler

| Senaryo | Davranış |
|---------|----------|
| Tüm Content tipleri default (boş tema) | Tüm renkler baseline'dan; `name` boş String → boş `SharedString` |
| `appearance: "dark"` ama baseline light tema | `appearance = Dark`, renkler baseline light'tan (mixed); kullanıcı temasıdır |
| Aynı baseline ile iki kez `from_content` | İki ayrı `Theme` (farklı `id`); değerler aynı |
| `syntax: {}` | Boş `Vec<...>` → `Arc<SyntaxTheme>` ama içi boş |
| `accents: [null, null]` | Boş `AccentColors` (filter_map null'ları eler) |
| `players: []` | `player = baseline.styles.player.clone()` |
| `players: [{}]` | 1 PlayerColor, üç alanı da baseline.local'dan |

#### Performans profili

| Adım | Maliyet | Not |
|------|---------|-----|
| Appearance match | <1 µs | Trivial |
| Refinement üretim (2 fn) | ~10-30 µs | 150 + 42 alan, her biri Option-and_then |
| `apply_status_color_defaults` | <1 µs | 6 iterasyon |
| `clone() + refine()` × 2 | ~5-10 µs | Memcpy + 192 conditional write |
| Accents/Players/Syntax | ~5-20 µs | Map sayısına bağlı |
| Toplam | **~25-60 µs** | Tema yüklemesi başına |

100 tema yüklensin = ~5 ms. Hot path değil.

#### Çağrı yerleri

`Theme::from_content` iki yerden çağrılır:

1. **Bundled tema yükleme** (Bölüm VII): `assets/themes/*.json` →
   `ThemeFamilyContent` → her `ThemeContent` için `from_content`.
2. **Kullanıcı tema yükleme** (runtime API): Kullanıcı bir tema dosyası
   ekledi → `serde_json_lenient::from_str` → `from_content`.

Test fixture'larında da kullanılır:

```rust
#[test]
fn parses_zed_one_dark() {
    let json = include_str!("fixtures/one-dark.json");
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
    let baseline = fallback::kvs_default_dark();
    for theme_content in family.themes {
        let theme = Theme::from_content(theme_content, &baseline);
        assert!(!theme.name.is_empty());
    }
}
```

#### Tuzaklar

1. **Baseline'ı yanlış appearance seçmek**: Light tema yüklerken
   dark baseline kullanırsan, kullanıcının vermediği alanlar dark
   baseline'dan gelir = uyumsuz görüntü. Çağıran kod baseline'ı
   `content.appearance`'a göre seçmeli:
   ```rust
   let baseline = match content.appearance {
       AppearanceContent::Light => fallback::kvs_default_light(),
       AppearanceContent::Dark => fallback::kvs_default_dark(),
   };
   ```
2. **`from_content`'i her render'da çağırmak**: Hot path değil ama
   gereksiz. Tema yüklenirken bir kez; cache et.
3. **`uuid` dependency'sini unutmak**: Cargo.toml'a `uuid = { version =
   "1", features = ["v4"] }` ekle. Bölüm I/Konu 5 listesinde.
4. **`SystemColors`'u override etmek**: Sözleşmede SystemColors tema
   yazarı tarafından override edilmez. Şu an Content tipinde yer yok;
   isteseler de yazamazlar. Bu kasıtlı.
5. **`Theme.id` üzerinden equality**: İki tema farklı id ama aynı
   içerik = farklı sayılır. Equality için `name` veya `styles`
   karşılaştır.
6. **Accents `filter_map` null davranışı belirsizliği**: Zed'in tam
   davranışını fixture testleriyle doğrula; sync turunda Zed davranışı
   değişirse buraya not düş.
7. **`from_content` panic potansiyeli**: Mevcut implementasyonda panic
   yok. Ama `unwrap` ekleyenler dikkat: tema yüklemesi panic edemez,
   sessizce baseline'a düşmeli.

---

## Bölüm VI — Runtime katmanı

Runtime katmanı tema sözleşmesinin **uygulamayla buluştuğu** yerdir.
Üç sorumluluğu var: tema **kataloğu** tutmak (registry), **aktif tema**
yi sorgulanır kılmak (global + trait), **sistem mod**'unu izlemek
(SystemAppearance). Bu katmanın yazılışı **tamamen senin tasarımındır**
— Zed'in `theme_settings` ve `theme_selector` crate'lerini taklit etmek
zorunda değilsin (Bölüm I/Konu 1).

> **Mimari yön:** Runtime, refinement'a ve veri sözleşmesine **bağımlı**;
> ters yön yasak. `ThemeRegistry` `Theme` döner; `Theme` registry'den
> haberdar değil.

---

### 27. `ThemeRegistry`: API yüzeyi ve thread safety

**Kaynak modül:** `kvs_tema/src/registry.rs`.

Yüklü temaların ad-bazlı kataloğu. Thread-safe read/write erişim;
runtime'ın tek "tema veritabanı"sı.

#### Yapı

```rust
use parking_lot::RwLock;
use std::sync::Arc;
use collections::HashMap;
use gpui::SharedString;

pub struct ThemeRegistry {
    themes: RwLock<HashMap<SharedString, Arc<Theme>>>,
}
```

**Üç katmanlı sarmalama:**

1. **`Arc<Theme>`** — Her tema paylaşılabilir; klon ucuz (refcount).
   `cx.theme()` `&Arc<Theme>` döner; UI binlerce kez çağırır.
2. **`HashMap<SharedString, _>`** — Ad bazlı O(1) lookup. `SharedString`
   key (Bölüm II/Konu 7); klonsuz hashleme.
3. **`RwLock<...>`** — Çoklu okuyucu, tek yazıcı. Tema okuma sık
   (render path); yazma nadir (init + reload).

> **Neden `parking_lot::RwLock`?** `std::sync::RwLock` daha yavaş ve
> daha büyük; ayrıca poisoned-on-panic davranışı zorunlu unwrap'lere
> yol açar. `parking_lot::RwLock`:
> - ~2× hızlı kilit-açma
> - Daha küçük bellek ayak izi
> - Poison yok — panic sonrası lock kullanılabilir
> - `read()`/`write()` doğrudan guard döner; `unwrap()` gereksiz

#### `ThemeNotFound` hata tipi

```rust
use thiserror::Error;

#[derive(Debug, Error)]
#[error("tema bulunamadı: {0}")]
pub struct ThemeNotFound(pub SharedString);
```

- `thiserror` `Display + std::error::Error` derive eder.
- Tek alanlı newtype — hata mesajı `"tema bulunamadı: Kvs Default Dark"`.
- Hata propagation kolay: `?` operatörü ile `anyhow::Result<...>` veya
  başka error chain'e dönüşebilir.

#### Global wrapper

```rust
#[derive(Default)]
struct GlobalThemeRegistry(Arc<ThemeRegistry>);
impl Global for GlobalThemeRegistry {}
```

`Arc<ThemeRegistry>`'yi `App` global'i yapmak için newtype (Bölüm II/Konu
10). Doğrudan `Arc<ThemeRegistry>` global yapamazsın çünkü:

- `Arc<T>` zaten `'static + Send + Sync` ama global key olarak `Arc`
  kullanmak başka yerlerde `Arc<ThemeRegistry>` taşıyan kodla çakışır.
- Newtype, **bu özel registry'nin global anahtarı** olduğunu garantiler.

#### Public API yüzeyi

```rust
impl ThemeRegistry {
    pub fn new() -> Self;
    pub fn global(cx: &App) -> Arc<Self>;
    pub fn set_global(cx: &mut App, registry: Arc<Self>);
    pub fn insert(&self, theme: Theme);
    pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFound>;
    pub fn list_names(&self) -> Vec<SharedString>;
}
```

**Her method'un davranışı:**

| Method | İmza | Davranış | Lock |
|--------|------|----------|------|
| `new` | `() -> Self` | Boş registry kurar | Yok |
| `global` | `(cx: &App) -> Arc<Self>` | Aktif registry'yi döner; yoksa **panic** | App global okuma |
| `set_global` | `(cx: &mut App, registry: Arc<Self>)` | Global'i kurar veya üzerine yazar | App global yazma |
| `insert` | `(&self, theme: Theme) -> ()` | Tema'yı `name` key'i ile ekler; aynı isimde varsa **üzerine yazar** | Write |
| `get` | `(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFound>` | Tema'yı clone'lar (Arc); yoksa hata | Read |
| `list_names` | `(&self) -> Vec<SharedString>` | Tüm tema adlarını sıralı liste olarak döner | Read |

#### Davranış detayları

**`insert` üzerine yazma:**

```rust
pub fn insert(&self, theme: Theme) {
    self.themes
        .write()
        .insert(theme.name.clone(), Arc::new(theme));
}
```

`HashMap::insert` aynı key varsa eski değeri **drop eder**. Kullanıcı
"My Theme" adıyla iki tema yükledi → ikincisi birinciyi siler. Bu
davranış **kasıtlı** — kullanıcının "tema güncelleme" reflexi (aynı
adla yeniden yükleme).

**`get` clone semantiği:**

```rust
pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFound> {
    self.themes
        .read()
        .get(name)
        .cloned()    // Arc<Theme> → ucuz klon
        .ok_or_else(|| ThemeNotFound(name.to_string().into()))
}
```

`cloned()` `Arc<Theme>`'i clone'lar — sadece refcount artırır. Caller
kendi `Arc<Theme>` instance'ına sahip olur; registry'nin storage'ı
bağımsız.

**`list_names` sıralama:**

```rust
pub fn list_names(&self) -> Vec<SharedString> {
    let mut names: Vec<_> = self.themes.read().keys().cloned().collect();
    names.sort();
    names
}
```

`HashMap` sırasız; `sort()` deterministik liste sunar. UI'da tema
seçici dropdown'u alfabetik sıralı görünür.

#### Thread safety semantiği

- `&ThemeRegistry`'den (paylaşımlı) **okunabilir ve yazılabilir**.
  `RwLock` iç-mutabilite veriyor; `&self` yetiyor `insert` için bile.
- `Arc<ThemeRegistry>` **`Send + Sync`** çünkü `RwLock` her ikisini
  veriyor.
- Lock hold süresi minimal — `insert`/`get` tek HashMap operation'u.
  Race condition yok.

> **Kilit zinciri uyarısı:** `registry.read()` guard'ı tutarken başka
> bir kilide girmek (örn. `GlobalTheme`) **deadlock riski** taşır.
> Tema değişim akışında: önce `registry.get()` çağır, döneni `Arc`
> olarak al, lock düşür, sonra `GlobalTheme::set_theme(...)` çağır.
> Mevcut API zaten bu deseni teşvik ediyor.

#### Zed'in genişletilmiş API kıyaslaması

Zed'in `ThemeRegistry`'sinde ek metodlar var (rehber.md #94):

| Metod | Zed | Bu rehber | Neden? |
|-------|-----|-----------|--------|
| `default_global`, `try_global` | ✓ | ✗ (henüz) | Init/test için gerekli olunca ekle |
| `insert_theme_families` | ✓ | ✗ | `for family.themes { insert(...) }` ile yapılır |
| `remove_user_themes` | ✓ | ✗ | Dinamik tema kaldırma — ihtiyaç doğunca |
| `list` (ThemeMeta) | ✓ | ✗ | UI dropdown'u için zengin metadata |
| `assets()` | ✓ | ✗ | Bundled asset source — Bölüm VII |
| `list_icon_themes`, `get_icon_theme`, `load_icon_theme` | ✓ | ✗ | Icon tema runtime — Bölüm VII |
| `extensions_loaded()` | ✓ | ✗ | Extension yüklenme bayrağı |

**Karar:** Minimum başla, ihtiyaca göre ekle. Eklediğin her metod
sözleşmenin parçası olur; `DECISIONS.md`'ye yaz.

#### Tuzaklar

1. **`get(name: &str)` vs `get(&SharedString)`**: İmza `&str` aldığı
   için caller'lar `&"...".into()` yazmaz; `"...".into()` veya literal
   geçer. HashMap key `SharedString` ama `Borrow<str>` impl'i sayesinde
   `&str` ile lookup çalışır.
2. **`insert` race condition**: İki thread aynı anda aynı isimle insert
   yaparsa hangisinin kazanacağı tanımsız — `RwLock::write()` sıraya
   sokar, son giren kazanır. Bu mantıken kabul edilebilir.
3. **`global(cx)` panic**: Registry init edilmemişse panic. `kvs_tema::init()`
   uygulama başında çağrılmalı. Test ortamında `set_global` manuel.
4. **`Arc<ThemeRegistry>`'i parametre olarak almak vs `cx`**: API
   `ThemeRegistry::global(cx)` deseni; `&Arc<ThemeRegistry>` parametre
   geçmek de mümkün ama tüketici kodunu bağlar. Genelde `cx` üzerinden
   eriş.
5. **`SharedString` case sensitive**: "Kvs Default" ve "kvs default" iki
   ayrı key (Bölüm II/Konu 7).
6. **Registry boş başlatmak ama default tema set etmek**: `set_global`
   sonrası `GlobalTheme::set_theme(cx, default)` çağrısı şart. Aksi
   halde `cx.theme()` panic eder.

---

### 28. `GlobalTheme` ve `ActiveTheme` trait

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`GlobalTheme` aktif temayı taşıyan global. `ActiveTheme` trait'i `cx.theme()`
ergonomisini sağlar.

#### `GlobalTheme` yapısı

```rust
use gpui::{App, BorrowAppContext, Global};
use std::sync::Arc;

pub struct GlobalTheme {
    theme: Arc<Theme>,
}
impl Global for GlobalTheme {}
```

`Theme` doğrudan global yapılmaz; newtype wrapper (Bölüm II/Konu 10
kuralı). `theme` alanı private — dışarıdan `set_theme`/`theme` metotları
ile erişim.

#### `GlobalTheme` API

```rust
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
```

**`theme(cx)`:**

- `cx.global::<Self>()` global'i okur; yoksa panic.
- `&Arc<Theme>` döner — clone'a gerek yok; caller refcount artırmadan
  okur.

**`set_theme(cx, theme)`:**

`init-or-update` deseni (Bölüm II/Konu 10):

- `has_global` ile kontrol; ilk çağrıda `set_global`.
- Sonraki çağrılarda `update_global` — mevcut instance mutate edilir,
  `Drop` çalışmaz (eski `Arc<Theme>` refcount azalır, başkası
  tutmuyorsa drop).

> **Neden `update_global` mutate yerine yeni `set_global` değil?**
> İki davranış görünür aynı ama:
> - `set_global` global tipini **kontrolsüz değiştirir** — observer'lar
>   bilgilendirilmez.
> - `update_global` callback içinde GPUI'nin observer mekanizması
>   tetiklenir (örn. `cx.observe_global::<GlobalTheme>(|_, _| {})`).
>
> Tema değişim observer'ı yoksa fark yok; ama olur diye `update_global`
> tercih.

#### `ActiveTheme` trait

```rust
pub trait ActiveTheme {
    fn theme(&self) -> &Arc<Theme>;
}

impl ActiveTheme for App {
    fn theme(&self) -> &Arc<Theme> {
        GlobalTheme::theme(self)
    }
}
```

**Mantık:**

- Trait, **extension method** sağlar — `App` üzerinde `cx.theme()` çağrısı
  mümkün hale gelir.
- `Context<T>: Deref<Target = App>` (Bölüm II/Konu 9) sayesinde
  `cx.theme()` `Context<T>` üzerinden de çalışır — trait impl'ine gerek
  yok; deref coercion yeterli.
- `AsyncApp` üzerinde `theme()` çalışmaz çünkü `AsyncApp` `&App`'e
  doğrudan deref etmez; gerekirse `cx.try_global::<GlobalTheme>()`
  manuel.

#### Tüketici tarafı kullanımı

```rust
use kvs_tema::ActiveTheme;

impl Render for AnaPanel {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let tema = cx.theme();   // &Arc<Theme>
        div()
            .bg(tema.styles.colors.background)
            .text_color(tema.styles.colors.text)
    }
}
```

`use kvs_tema::ActiveTheme;` zorunlu — trait method'u görünür olmaz
import olmadan. Tipik pattern: prelude module ekle.

```rust
// kvs_tema/src/prelude.rs (opsiyonel)
pub use crate::runtime::ActiveTheme;
pub use crate::Theme;
```

```rust
use kvs_tema::prelude::*;  // tek satırlık import
```

#### Accessor metotları (opsiyonel)

`cx.theme().styles.colors.x` uzun. Konu 12'deki opsiyonel accessor'lar
ile kısaltılır:

```rust
impl Theme {
    pub fn colors(&self) -> &ThemeColors { &self.styles.colors }
    pub fn status(&self) -> &StatusColors { &self.styles.status }
    pub fn players(&self) -> &PlayerColors { &self.styles.player }
}
```

Sonuç:

```rust
.bg(cx.theme().colors().background)
.text_color(cx.theme().colors().text)
```

#### Subscribe pattern (observer)

UI bileşeni tema değişimini izlemek isterse:

```rust
impl AnaPanel {
    fn new(cx: &mut Context<Self>) -> Self {
        // Tema değişince notify
        cx.observe_global::<GlobalTheme>(|_, cx| cx.notify()).detach();
        Self
    }
}
```

`cx.observe_global` `Subscription` döner; `.detach()` zorunlu yoksa
observer ölür.

Ama dikkat: `cx.refresh_windows()` (Konu 31) zaten tüm view'ları yeniden
çiziyor; explicit observer çoğu zaman gereksiz. Sadece tema değişiminde
özel state güncellemek istiyorsan kur.

#### Tuzaklar

1. **`theme(&Arc<Theme>)` clone**: `cx.theme()` zaten `&Arc<Theme>`
   döndürüyor; üzerinde `.clone()` çağırırsan gereksiz refcount artışı.
   `let tema = cx.theme();` direkt yeterli.
2. **`use kvs_tema::ActiveTheme` unutmak**: Trait import edilmemişse
   `cx.theme()` "method not found" hatası. Prelude kullan.
3. **`set_theme` callback boş**: `update_global::<Self, _>(|this, _| ...)`
   callback'inde sadece field mutate et; başka global'i set etmeye
   çalışırsan re-entrancy panic.
4. **Theme parametresini `Theme` yapmak**: `set_theme(cx, theme: Theme)`
   yazsaydın her çağrıda klon olurdu. `Arc<Theme>` zorunlu.
5. **`observe_global` `.detach()` unutmak**: Subscription drop olursa
   observer ölür; tema değişince bileşen yenilenmez.

---

### 29. `SystemAppearance` ve sistem mod takibi

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

OS'un light/dark mod tercihini taşır. Tema seçim mantığı bunu okur ve
uygun varyantı yükler.

#### Yapı

```rust
#[derive(Clone, Copy)]
pub struct SystemAppearance(pub Appearance);

struct GlobalSystemAppearance(SystemAppearance);
impl Global for GlobalSystemAppearance {}
```

- `SystemAppearance(pub Appearance)` — `Appearance` (Bölüm III/Konu 16)
  newtype'ı.
- `Copy` çünkü `Appearance` `Copy`. Ucuz değer-geçirim.
- `GlobalSystemAppearance` global wrapper.

> **Neden `Appearance` doğrudan global değil?** `Appearance` enum'u
> başka anlamlarda da kullanılır (tema'nın nominal modu, JSON deserialize
> hedefi). Global anahtarı **sistem-spesifik** kalsın: `SystemAppearance`
> sadece "OS şu an ne diyor?" sorusunu cevaplar.

#### API

```rust
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
```

**`init(cx)`:**

- `cx.window_appearance()` (Bölüm II/Konu 8) sorgular.
- `WindowAppearance` 4 variant'tan birini döner; `Vibrant*` macOS-özgü
  ama tema seçiminde Light/Dark ile aynı kategoride.
- Match ifadesi dört variant'ı iki kategoride birleştirir.
- `set_global` ile kurulur.

**`global(cx)`:**

- `cx.global::<GlobalSystemAppearance>()` → `&GlobalSystemAppearance`.
- `.0` newtype'ı açar — `SystemAppearance` `Copy` olduğu için değer
  döner.

#### Sistem mod değişimini izleme (Zed deseni)

`init` sadece **başlangıçta** çağrılır. OS theme değişimini takip etmek
için observer şart:

```rust
use gpui::WindowAppearance;
use std::sync::Arc;

pub fn observe_system_appearance(
    window: &mut Window,
    cx: &mut Context<impl 'static>,
) {
    cx.observe_window_appearance(window, |_, window, cx| {
        let new_appearance = match window.appearance() {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
        };

        // Global güncelle
        cx.set_global(GlobalSystemAppearance(SystemAppearance(new_appearance)));

        // Sistem moduna göre tema seç (opsiyonel)
        // ...
    }).detach();
}
```

> **`.detach()` zorunlu:** `cx.observe_window_appearance` `Subscription`
> döner; drop edilirse observer ölür (Bölüm II/Konu 10 tuzak 5).

#### Sistem'den tema seçme örneği

`SystemAppearance` okuyup uygun temayı yüklemek:

```rust
pub fn sistemden_tema_sec(cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let ad = match SystemAppearance::global(cx).0 {
        Appearance::Dark => "Kvs Default Dark",
        Appearance::Light => "Kvs Default Light",
    };
    GlobalTheme::set_theme(cx, registry.get(ad)?);
    cx.refresh_windows();
    Ok(())
}
```

> **Tema adı sabit string olarak yazmak:** "Kvs Default Dark"
> tipo'ya açık. Production'da:
> - Sabitler modülü: `pub const DEFAULT_DARK: &str = "Kvs Default Dark";`
> - Veya kullanıcı ayarlarından (`SettingsTema { dark_default: String,
>   light_default: String }`).

#### `Appearance` vs `SystemAppearance` vs `WindowAppearance` ayrımı

| Tip | Anlamı | Kaynak |
|-----|--------|--------|
| `WindowAppearance` (GPUI) | OS'un raporladığı raw mode (Light/Dark/Vibrant*) | `cx.window_appearance()` |
| `SystemAppearance` (tema) | OS modunun **iki kategoriye** indirgenmiş hali (Light/Dark) | `SystemAppearance::init` |
| `Appearance` (tema) | Bir **tema'nın nominal modu** | `Theme.appearance` |

Üçü farklı kavramlar; karıştırma:

- Kullanıcı sistem Dark modda ama explicit Light tema seçti →
  `SystemAppearance::Dark` ve `cx.theme().appearance == Light`.
- macOS Vibrant'a geçti → `WindowAppearance::VibrantDark` ama
  `SystemAppearance::Dark` (kategori indirme).

#### Tuzaklar

1. **`init` tek seferlik**: Sistem mod değişirse `init` tekrar
   çağrılmaz. Observer kur.
2. **`SystemAppearance` `Copy` ama `GlobalSystemAppearance` değil**:
   Newtype `Copy` türetmez (`Global` `Copy` gerektirmez); ama içindeki
   `SystemAppearance` Copy olduğu için `.0` `Copy` döner. Bu kasıtlı.
3. **Vibrant variant'ları görmezden gelmek**: `match` ifadesinde `_ =>
   Light` veya `_ => Dark` yazmak macOS'ta yanlış kategori. Tüm 4
   variant'ı listele.
4. **Sistem moduna **zorla** uymak**: Kullanıcı manuel tema seçmiş
   olabilir; sistem mod değişimini direkt uygulamak kullanıcı tercihini
   ezer. Ayar:
   ```rust
   pub struct AyarlarTema {
       pub mod_takibi: bool,  // false ise sistem mod'unu yok say
       pub ad: Option<String>,
   }
   ```
5. **`SystemAppearance` `Default` türetilmez**: Init'siz erişim panic.
   Init sırası `init()` fonksiyonu içinde garantili.

---

### 30. `init()`: kuruluş sırası ve fallback yükleme

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`kvs_tema::init(cx)` — runtime'ın **tek giriş noktası**. Uygulamanın
başında, pencere açılmadan **mutlaka** çağrılır.

#### Tam kod

```rust
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

#### 5 adımlı kuruluş

**Adım 1 — `SystemAppearance::init(cx)`:**

Sistem mod sorgulanır ve global kurulur. **İlk** adım çünkü bundan
sonraki adımlar isterse sistem mod'una bakabilir (`init` sırasında değil
ama observer eklenirken).

**Adım 2 — Registry yaratma:**

```rust
let registry = Arc::new(ThemeRegistry::new());
```

Boş registry. `Arc` çünkü global'e konacak.

**Adım 3 — Fallback temaları insert:**

```rust
registry.insert(crate::fallback::kvs_default_dark());
registry.insert(crate::fallback::kvs_default_light());
```

İki "default" tema her zaman registry'de. Sebebi:

- Kullanıcı tema yükleme akışı bozulursa bile **uygulama yine çalışır**.
- `cx.theme()` panic edemez; her zaman geçerli bir tema olur.
- Sistem light/dark mod değişiminde her zaman bir hedef tema var.

**Adım 4 — Default seçimi:**

```rust
let default = registry
    .get("Kvs Default Dark")
    .expect("default tema kayıtlı olmalı");
```

`.expect()` kullanımı kasıtlı — bu **mantıksal invariant**: az önce
insert ettik, eksik olamaz. Eksikse programatik hata (typo); panic
acceptable.

> Alternatif: `SystemAppearance` baz alarak başlangıç temasını seç:
> ```rust
> let default_name = match SystemAppearance::global(cx).0 {
>     Appearance::Dark => "Kvs Default Dark",
>     Appearance::Light => "Kvs Default Light",
> };
> let default = registry.get(default_name).expect("...");
> ```
> Bu sürüm OS mod'unu hemen yansıtır. Tercih senin; varsayılan dark
> bilinçli karar olabilir.

**Adım 5 — Global'leri kur:**

```rust
ThemeRegistry::set_global(cx, registry);
GlobalTheme::set_theme(cx, default);
```

Sıra önemli mi? **Hayır** — iki global birbirine bağımlı değil. Ama
mantıksal sıra: önce registry (kataloğu kur), sonra aktif tema (kataloğdan
seç).

#### Çağrı yeri

`gpui::Application` kurulurken, pencere açılmadan **mutlaka**:

```rust
use gpui::{Application, App};

fn main() {
    Application::new().run(|cx: &mut App| {
        // 1. Tema sistemini başlat
        kvs_tema::init(cx);

        // 2. Başka init'ler (settings, key bindings, vs.)
        // ...

        // 3. Pencere aç — render içinde cx.theme() artık güvenli
        cx.open_window(WindowOptions {
            // window_background dahil tema kullanılır
            window_background: cx.theme().styles.window_background_appearance,
            ..Default::default()
        }, |w, cx| {
            cx.new(|cx| AnaPanel::new(cx))
        }).unwrap();
    });
}
```

#### Hata davranışları

| Hata | Davranış | Önlem |
|------|----------|-------|
| Fallback tema yüklenmediyse | `expect` panic | Code review — `kvs_default_*` fonksiyonları statically erişilebilir; runtime hatası imkansız |
| `cx.window_appearance()` panic eder mi? | Hayır, default `Light` döner | — |
| `cx` zaten init edilmiş ise (`init` iki kez çağrıldı) | `set_global` sessizce üzerine yazar; eski registry/theme drop | İki kez çağırma, mantıksız |
| `kvs_tema::init` çağrılmadan `cx.theme()` | Panic: "global not found" | Init'i ilk satıra koy |

#### Genişletilmiş init varyasyonları

**1. Bundled tema yükleme:**

```rust
pub fn init_with_bundled(cx: &mut App) {
    init(cx);  // Mevcut init

    // Bundled tema'ları ekle (Bölüm VII)
    let registry = ThemeRegistry::global(cx);
    if let Err(e) = load_bundled_themes(&registry) {
        tracing::warn!("bundled tema yükleme hatası: {}", e);
    }
}
```

`init`'ın temel kontratı korunur; bundled yükleme **opsiyonel**. Hata
olsa bile uygulama açılır (fallback temalar yeterli).

**2. Async user theme load:**

```rust
pub fn init_with_user_themes(cx: &mut App, user_theme_dir: PathBuf) {
    init(cx);

    cx.spawn(async move |cx| {
        let entries = std::fs::read_dir(&user_theme_dir)?;
        for entry in entries.flatten() {
            let bytes = std::fs::read(entry.path())?;
            let family: ThemeFamilyContent = serde_json_lenient::from_slice(&bytes)?;
            cx.update(|cx| {
                let registry = ThemeRegistry::global(cx);
                let baseline = fallback::kvs_default_dark();
                for theme_content in family.themes {
                    registry.insert(Theme::from_content(theme_content, &baseline));
                }
            })?;
        }
        anyhow::Ok(())
    }).detach_and_log_err(cx);
}
```

User theme yükleme **disk I/O** içerdiğinden async; init'ı bloklamaz.

#### Test senaryoları

```rust
#[gpui::test]
fn init_kurar_fallback_temalari(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);

        let registry = ThemeRegistry::global(cx);
        let names = registry.list_names();
        assert!(names.iter().any(|n| n.as_ref() == "Kvs Default Dark"));
        assert!(names.iter().any(|n| n.as_ref() == "Kvs Default Light"));

        let theme = cx.theme();
        assert_eq!(theme.name.as_ref(), "Kvs Default Dark");
    });
}
```

#### Tuzaklar

1. **`init`'i pencere içinde çağırmak**: `Context<T>::update` callback'inde
   `init(cx)` mantıksız — pencere zaten render başladığında `cx.theme()`
   çağırıyor. Init Application root'unda.
2. **`init` async yapmak**: `init` `&mut App` alıyor; async olamaz. Async
   yükleme (kullanıcı tema dosyaları, network) `spawn` ile **init
   sonrası**.
3. **Birden fazla `init` çağrısı**: İdempotent değil — registry ve aktif
   tema sıfırlanır. Yapma.
4. **`init` yokken `cx.theme()`**: Panic mesajı `"global not found:
   GlobalTheme"`. Hata mesajı uyarıcı; init'i ekle.
5. **Default tema seçiminde fallback olmadan**: `registry.get("Yok").expect()`
   panic. Sadece insert ettiğin temaları seç.
6. **Fallback'leri kaldırmak**: User theme'ler yüklendikten sonra
   "Kvs Default *" temaları gereksiz görünebilir; **kaldırma**.
   Kullanıcı temasının yüklemesi başarısız olduğunda son çare.

---

### 31. Tema değiştirme ve `cx.refresh_windows()`

Tema değişimi **iki adımlık** bir işlem: aktif tema güncelle +
pencereleri yenile. Eksik bırakırsan UI eski renkte kalır.

#### Temel akış

```rust
pub fn temayi_degistir(ad: &str, cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;       // 1. Tema lookup
    GlobalTheme::set_theme(cx, yeni);   // 2. Global güncelle
    cx.refresh_windows();                // 3. UI yenile
    Ok(())
}
```

#### Adım adım

**Adım 1 — Registry lookup:**

```rust
let registry = ThemeRegistry::global(cx);
let yeni = registry.get(ad)?;
```

- `registry.get(ad)` `Result<Arc<Theme>, ThemeNotFound>` döner.
- `?` operatörü hatayı caller'a propagate eder.
- Tema bulunamazsa `ThemeNotFound` döner — caller bunu loglar veya UI'da
  gösterir (toast: "Tema bulunamadı: X").

**Adım 2 — Global update:**

```rust
GlobalTheme::set_theme(cx, yeni);
```

`init-or-update` pattern (Konu 28). İlk çağrıda kurar, sonraki çağrılarda
mutate eder. `observe_global::<GlobalTheme>` observer'ları (varsa)
tetiklenir.

**Adım 3 — `cx.refresh_windows()`:**

```rust
cx.refresh_windows();
```

(Bölüm II/Konu 10).

#### `cx.refresh_windows()` semantiği

| Davranış | Etki |
|----------|------|
| Açık tüm pencerelere `refresh` mesajı gönderir | Sonraki frame'de tüm view ağacı yeniden inşa edilir |
| Pencerelere özel state (focus, scroll, selection) | **Korunur** |
| GPU resource (textures, font atlas) | **Reuse** edilir; sadece layout + paint tekrar |
| `cx.notify()` ile fark | `notify()` lokal entity, `refresh_windows()` global tüm pencereler |

**Maliyet:**

- Frame budget tipik 16 ms (60 fps); refresh maliyeti ~2-5 ms (içerik
  karmaşıklığına bağlı).
- Kullanıcı tema değiştirir, bir frame geçer, yeni renk görünür.
  Gözlemlenebilir gecikme yok.

#### Helper fonksiyon önerisi

`temayi_degistir`'i helper olarak sar — her tüketici kod tekrar
yazmasın:

```rust
// kvs_tema/src/runtime.rs (public API)
pub fn temayi_degistir(ad: &str, cx: &mut App) -> Result<(), ThemeNotFound> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;
    GlobalTheme::set_theme(cx, yeni);
    cx.refresh_windows();
    Ok(())
}
```

Tüketici:

```rust
use kvs_tema::temayi_degistir;

fn handle_tema_secimi(secilen: &str, cx: &mut App) {
    if let Err(e) = temayi_degistir(secilen, cx) {
        // toast: "Tema değiştirilemedi: ..."
    }
}
```

#### Settings köprüsü

Kullanıcının config dosyasından gelen tema adını uygulamak:

```rust
#[derive(serde::Deserialize)]
pub struct AyarlarTema {
    pub ad: String,
}

pub fn ayarlardan_tema_uygula(
    ayar: &AyarlarTema,
    cx: &mut App,
) -> anyhow::Result<()> {
    temayi_degistir(&ayar.ad, cx)?;
    Ok(())
}
```

Config dosyası (örn. `~/.config/kvs/settings.json`):

```json
{
  "tema": { "ad": "One Dark" }
}
```

Settings observer (kendi config sisteminden) tema alanı değişince
`ayarlardan_tema_uygula` çağırır.

#### Sistem mod takipli otomatik tema

```rust
pub fn observe_system_mod_ile_tema_takibi(
    window: &mut Window,
    cx: &mut Context<impl 'static>,
) {
    cx.observe_window_appearance(window, |_, window, cx| {
        let kategori = match window.appearance() {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
        };

        // SystemAppearance güncelle
        cx.set_global(GlobalSystemAppearance(SystemAppearance(kategori)));

        // Mevcut tema'nın appearance'ı sistemle uyumlu mu?
        let mevcut = cx.theme();
        if mevcut.appearance != kategori {
            let ad = match kategori {
                Appearance::Dark => "Kvs Default Dark",
                Appearance::Light => "Kvs Default Light",
            };
            let _ = temayi_degistir(ad, cx);
        }
    }).detach();
}
```

> **Kullanıcı tercihini ezme uyarısı:** Bu fonksiyon sistem değişiminde
> otomatik tema değiştirir = kullanıcının manuel seçimi sistem
> değişiminde kaybolur. Production'da bir `ayar.mod_takibi: bool`
> bayrağı ile koşullu çalıştır.

#### Tema reload

Kullanıcı tema dosyasını editörden değiştirir → uygulama yeniden okur:

```rust
pub fn temayi_yeniden_yukle(
    yol: &Path,
    cx: &mut App,
) -> anyhow::Result<()> {
    let bytes = std::fs::read(yol)?;
    let family: ThemeFamilyContent = serde_json_lenient::from_slice(&bytes)?;

    let baseline_dark = fallback::kvs_default_dark();
    let baseline_light = fallback::kvs_default_light();

    let registry = ThemeRegistry::global(cx);
    for theme_content in family.themes {
        let baseline = match theme_content.appearance {
            AppearanceContent::Dark => &baseline_dark,
            AppearanceContent::Light => &baseline_light,
        };
        let theme = Theme::from_content(theme_content, baseline);
        registry.insert(theme);   // Aynı isim üzerine yazar
    }

    // Aktif tema yeniden yüklendi mi? Re-set ile observer'ları tetikle.
    let aktif_ad = cx.theme().name.clone();
    if let Ok(yeni) = registry.get(&aktif_ad) {
        GlobalTheme::set_theme(cx, yeni);
        cx.refresh_windows();
    }

    Ok(())
}
```

**Akış:**

1. Disk'ten oku, parse et.
2. Her tema variant'ı için uygun baseline seç (light → light baseline).
3. `registry.insert` üzerine yazar — aynı isimle güncellenir.
4. Aktif tema yeniden yüklendiyse `set_theme + refresh_windows`.

#### Performans

| Operasyon | Süre | Hot path? |
|-----------|------|-----------|
| `registry.get(name)` | O(1) HashMap lookup | Sık (her tema değişimde) |
| `set_theme` | Global update + observer trigger | Sık |
| `refresh_windows` | Tüm açık view ağaçları | Sık |
| `Theme::from_content` (reload) | ~25-60 µs (Konu 26) | Nadir |
| Tek tema değişimi toplam | ~2-5 ms (next frame'de görünür) | Kullanıcı tetikler |

#### Tuzaklar

1. **`refresh_windows` çağırmamak**: En yaygın bug. UI eski renkte kalır
   ta ki sonraki etkileşime kadar (örn. hover). Helper fonksiyona sar.
2. **`cx.notify()` ile yetinmek**: `notify` lokal entity — tüm view'ları
   yenilemez. Tema için `refresh_windows` şart.
3. **`registry.get` `unwrap`**: Hata UI'da görünmeli, panic etmemeli.
   `?` ile propagate veya match.
4. **Sistem mod takipli akışta kullanıcı tercihini ezmek**: `ayar.mod_takibi`
   bayrağı ile koşullu çalıştır.
5. **Reload sonrası `aktif_ad` lookup yine başarısız**: Tema dosyasından
   o isim silindi. `get(&aktif_ad).is_err()` ise default fallback'e
   düş:
   ```rust
   match registry.get(&aktif_ad) {
       Ok(t) => GlobalTheme::set_theme(cx, t),
       Err(_) => {
           tracing::warn!("aktif tema silindi, fallback'e dönülüyor");
           let fallback = registry.get("Kvs Default Dark").unwrap();
           GlobalTheme::set_theme(cx, fallback);
       }
   }
   cx.refresh_windows();
   ```
6. **Frame budget aşımı**: Çok karmaşık UI'da `refresh_windows` 16 ms'yi
   aşabilir; bir frame skip görünebilir. Profile et; gerçek bir bug.
7. **Async reload'da `cx` lifetime**: `cx.spawn` içinde `cx`
   `AsyncApp`; `cx.update(|cx| ...)` ile sync bağlama düş.

---

## Bölüm VII — Varlık ve test

Bu bölüm tema sisteminin **runtime dışı ekosistemini** ele alır:
fallback temaların kendi paletini tasarlama, dağıtılan JSON
temalarının nasıl paketlendiği, fixture testleriyle sözleşme
doğrulaması ve lisans denetim akışı.

> **Mimari yön:** Bu katman tema sözleşmesini **doldurur** ama **şekil
> vermez** — runtime, refinement ve veri sözleşmesi katmanları
> değişmeden kalır. Fallback ve bundle'lı temalar `Theme::from_content`
> ve registry'nin **tüketicisi**dir.

---

### 32. Fallback tema tasarımı

**Kaynak modül:** `kvs_tema/src/fallback.rs`.

Fallback temalar **runtime'ın güvenlik ağı**: kullanıcı tema yüklemesi
başarısız olsa bile uygulama açılır. Her zaman en az **iki tema**
(light + dark) registry'de bulunur (Bölüm VI/Konu 30).

#### Rol ve sözleşme

| Soru | Cevap |
|------|-------|
| Kaç adet fallback? | **2 — `kvs_default_dark` ve `kvs_default_light`** |
| Kim ne zaman çağırır? | `kvs_tema::init` (Bölüm VI/Konu 30); ayrıca `Theme::from_content` baseline argümanı |
| Lisans? | **Senin lisansın** — Zed'in paletini taşımak yasak (Bölüm I/Konu 3) |
| Hangi alan eksik kalabilir? | **Hiçbiri** — tüm ThemeColors/StatusColors alanları açık değer almalı |
| Ne zaman değişir? | Tasarım dili güncellenirse veya sync turunda yeni alan gelirse |

#### Palet seçimi disiplini

Zed'in `default_colors.rs`'sindeki HSL değerleri **GPL-3 telif altında**.
Birebir kopyalama yasak. İki yol:

**1. Sıfırdan tasarla:** Tek "anchor hue" seç, türetme kuralları kur.

```rust
pub fn kvs_default_dark() -> Theme {
    // Anchor renkler — tüm türetmelerin başlangıcı
    let anchor_hue = 220.0;  // mavi-gri (kendi seçimin)
    let bg          = hsla(anchor_hue / 360.0, 0.10, 0.12, 1.0);  // ana arka plan
    let surface     = hsla(anchor_hue / 360.0, 0.10, 0.15, 1.0);  // panel
    let elevated    = hsla(anchor_hue / 360.0, 0.10, 0.18, 1.0);  // popup
    let text        = hsla(anchor_hue / 360.0, 0.05, 0.92, 1.0);  // birincil metin
    let text_muted  = hsla(anchor_hue / 360.0, 0.05, 0.65, 1.0);  // ikincil metin
    let border      = hsla(anchor_hue / 360.0, 0.10, 0.25, 1.0);  // çerçeve
    let accent      = hsla(210.0       / 360.0, 0.75, 0.60, 1.0); // mavi vurgu

    Theme { /* ... */ }
}
```

**Anchor hue stratejisi**: Tüm "nötr" renkler (bg/surface/elevated/text/border)
aynı hue'dan; sadece **lightness** değişir. Bu monokromatik temel
profesyonel görünüm verir.

**2. Açık-lisanslı palet'ten esinlen:** Tailwind, Catppuccin, Nord,
Solarized — bu paletlerin HSL değerleri **public domain veya açık
lisanslı**. Kullan ama:

- Lisans dosyasını `LICENSES/` altına ekle.
- `DECISIONS.md`'ye "kvs_default_dark Tailwind slate-* paletinden
  esinlendi" yaz.
- HSL değerlerini doğrudan kopyala değil; **ondalık hassasiyetini farklılaştır**
  (kendi tasarım kararı olduğunu göster).

#### Türetme kalıpları

`opacity()` ile baz renklerden varyant türetmek tutarlılık sağlar:

```rust
ThemeColors {
    background: bg,
    surface_background: surface,
    elevated_surface_background: elevated,
    border,
    border_variant: border.opacity(0.5),       // %50 alpha
    border_focused: accent,                     // accent tam
    border_selected: accent.opacity(0.5),       // accent yarı
    border_transparent: hsla(0., 0., 0., 0.),  // tamamen şeffaf
    border_disabled: border.opacity(0.3),       // disabled için soluk
    element_background: surface,
    element_hover: elevated,                    // bir tık yukarı
    element_active: elevated.opacity(0.8),     // basılınca hafif soluklaş
    element_selected: accent.opacity(0.3),     // selection bg
    element_selection_background: accent.opacity(0.25),  // status fg/bg ile uyumlu
    element_disabled: surface.opacity(0.5),
    // ghost = transparan bg ile element
    ghost_element_background: hsla(0., 0., 0., 0.),
    ghost_element_hover: elevated,
    ghost_element_active: elevated.opacity(0.8),
    ghost_element_selected: accent.opacity(0.3),
    ghost_element_disabled: hsla(0., 0., 0., 0.),
    drop_target_background: accent.opacity(0.2),
    drop_target_border: accent,
    text,
    text_muted,
    text_placeholder: text_muted.opacity(0.7),  // muted'un daha solu
    text_disabled: text_muted.opacity(0.5),
    text_accent: accent,
    icon: text,                                 // metin ile aynı
    icon_muted: text_muted,
    icon_disabled: text_muted.opacity(0.5),
    // ... kalan tüm alanlar
}
```

**Pattern:**

- `border`/`border_variant`/`border_disabled` → tek border anchor + opacity
- `element_*`/`ghost_element_*` → surface/elevated/accent karışımı
- `text_*`/`icon_*` → tek text + muted anchor + opacity

Bu disiplin, sync turunda yeni alan gelirse "hangi anchor'dan türetmeli"
sorusunu hızlı cevaplar.

#### Status renkleri için ayrı fonksiyon

```rust
fn status_colors_dark() -> StatusColors {
    let red    = hsla(0.0   / 360.0, 0.7,  0.6,  1.0);
    let green  = hsla(140.0 / 360.0, 0.45, 0.55, 1.0);
    let yellow = hsla(45.0  / 360.0, 0.85, 0.6,  1.0);
    let blue   = hsla(210.0 / 360.0, 0.7,  0.6,  1.0);

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

        // 14 × 3 = 42 alan — her birini açık değerle doldur
        // conflict, created, deleted, hidden, hint, ignored, modified,
        // predictive, renamed, unreachable
        ..elinde_olmayan_default()  // ← YANLIŞ, aşağıya bak
    }
}
```

> **Uyarı:** `..unsafe { std::mem::zeroed() }` veya `..Default::default()`
> ile eksik alan **doldurmayın**. `Hsla::default()` = `(0, 0, 0, 0)` =
> UI'da görünmez. **Tüm 42 alanı tek tek açık değerle doldurun.** Diğer
> 10 status (conflict, created, deleted, hidden, vs.) için aynı kalıbı
> tekrarlayın — çıkardığım anchor'lar (red, green, yellow, blue) yeterli;
> her status anchor'lardan birine map'lensin (örn. `modified = yellow`,
> `deleted = red`, `created = green`).

#### Player ve accent fallback

```rust
ThemeStyles {
    // ...
    player: PlayerColors(vec![PlayerColor {
        cursor: accent,
        background: accent.opacity(0.2),
        selection: accent.opacity(0.3),
    }]),
    accents: AccentColors(vec![accent]),
    syntax: SyntaxTheme::new(vec![]),
}
```

- **Player listesi en az 1 girdi** (Bölüm III/Konu 15) — yoksa
  `local()` siyah fallback verir.
- **Accents en az 1 girdi** — yoksa `color_for(idx)` `gpui::blue()`
  döner.
- **Syntax boş Vec** kabul edilebilir — syntax highlighting
  kullanmıyorsan render bu vec'i atlar.

#### Light tema simetrisi

```rust
pub fn kvs_default_light() -> Theme {
    let bg          = hsla(220.0 / 360.0, 0.10, 0.98, 1.0);  // çok açık
    let surface     = hsla(220.0 / 360.0, 0.10, 0.95, 1.0);
    let elevated    = hsla(220.0 / 360.0, 0.10, 0.92, 1.0);
    let text        = hsla(220.0 / 360.0, 0.10, 0.10, 1.0);  // çok koyu
    let text_muted  = hsla(220.0 / 360.0, 0.05, 0.40, 1.0);
    let border      = hsla(220.0 / 360.0, 0.10, 0.85, 1.0);
    let accent      = hsla(210.0 / 360.0, 0.75, 0.50, 1.0);  // light için biraz daha koyu mavi

    Theme {
        id: "kvs-default-light".into(),
        name: "Kvs Default Light".into(),
        appearance: Appearance::Light,
        styles: ThemeStyles {
            window_background_appearance: WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors { /* aynı alan listesi, lightness tersine */ },
            status: status_colors_light(),
            player: /* ... */,
            accents: /* ... */,
            syntax: /* ... */,
        },
    }
}
```

**Simetri kuralları:**

- Aynı `anchor_hue` (örn. 220°) — light ve dark arasında **renk
  ailesi tutarlı**.
- Lightness "tersine çevril": dark'ta 0.12 olan bg light'ta 0.98.
- Saturation çoğu zaman aynı; gözle bakıldığında "aynı tema, ters
  mod" hissi gerek.
- Accent için dark hue'su (örn. 210°) light'ta biraz **daha koyu**
  (l=0.50 vs 0.60) — light bg üzerinde okunaklılık için.

#### Fallback test reçetesi

```rust
#[test]
fn fallback_temalari_tam_dolu() {
    let dark = kvs_default_dark();
    let light = kvs_default_light();

    // Hiçbir alan default/sıfır olmamalı
    assert_ne!(dark.styles.colors.background, gpui::Hsla::default());
    assert_ne!(dark.styles.colors.text, gpui::Hsla::default());
    assert_ne!(dark.styles.status.error, gpui::Hsla::default());

    // Player ve accent en az 1 girdi
    assert!(!dark.styles.player.0.is_empty());
    assert!(!dark.styles.accents.0.is_empty());

    // Appearance tutarlı
    assert_eq!(dark.appearance, Appearance::Dark);
    assert_eq!(light.appearance, Appearance::Light);

    // İsimler benzersiz
    assert_ne!(dark.name, light.name);
}
```

#### Tuzaklar

1. **`Default::default()` ile eksik alan doldurmak**: Hsla::default() =
   görünmez. Tüm 150 + 42 alanı açık değerle doldur.
2. **`unsafe { std::mem::zeroed() }` kullanmak**: Aynı sonuç (sıfır
   Hsla). Şablon kodda görsen sil; gerçek kodda asla.
3. **Anchor olmadan rastgele HSL**: Her alan farklı hue/saturation
   = tema dağınık görünür. Anchor hue + opacity disiplini şart.
4. **`palette` versiyonu pin'lememek**: Aynı `hsla(0.583, 0.10, 0.12)`
   farklı `palette` major sürümünde **ufak miktarda farklı sRGB**
   üretebilir. Cargo.lock pin'le veya `tema_aktarimi.md` palette pin'i
   kontrol et.
5. **Zed'in `default_colors.rs` HSL'ini birebir kopyalamak**: GPL-3
   ihlali (Bölüm I/Konu 3). Kendi anchor'larını seç.
6. **Light tema'yı dark'tan otomatik türetmek**: "`l = 1.0 - dark_l`"
   gibi formüller **çalışmaz** — gözün light vs dark algısı doğrusal
   değil. Light tema'yı ayrı bir tasarım kararı olarak yaz.
7. **`syntax: SyntaxTheme::new(vec![])` bırakmak**: Fallback'te boş
   syntax kabul, ama UI'da kod gösteriliyorsa syntax token'ları için
   en azından 5-10 temel kategori doldur (comment, string, keyword,
   number, function).

---

### 33. Built-in tema bundling ve `AssetSource`

Built-in temalar = uygulama ile **birlikte dağıtılan** JSON tema
dosyaları. Üç bundling stratejisi var; ihtiyacına göre seç.

#### Strateji 1: Diskten yükleme (en basit)

Geliştirme aşamasında ve dev build'lerde yeterli. `assets/themes/`
dizinindeki tüm JSON'lar runtime'da okunur:

```rust
use std::path::Path;

pub fn load_bundled_themes(
    registry: &kvs_tema::ThemeRegistry,
    themes_dir: &Path,
) -> anyhow::Result<()> {
    let baseline_dark = kvs_tema::fallback::kvs_default_dark();
    let baseline_light = kvs_tema::fallback::kvs_default_light();

    let entries = std::fs::read_dir(themes_dir)?;
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.extension().is_some_and(|e| e == "json") {
            continue;
        }
        let bytes = std::fs::read(&path)?;
        let family: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&bytes)
                .with_context(|| format!("tema parse: {}", path.display()))?;

        for theme_content in family.themes {
            let baseline = match theme_content.appearance {
                kvs_tema::AppearanceContent::Dark => &baseline_dark,
                kvs_tema::AppearanceContent::Light => &baseline_light,
            };
            registry.insert(kvs_tema::Theme::from_content(theme_content, baseline));
        }
    }
    Ok(())
}
```

**Yapı:**

- Her dosya bir `ThemeFamilyContent`; ailedeki light + dark varyantlar
  ayrılır.
- `theme_content.appearance`'a göre uygun baseline seçilir (Bölüm VI/Konu
  31 reload akışı ile aynı).
- Hata bir tema dosyasından gelse bile diğerleri yüklenmeye devam et
  istiyorsan `try_into`/`continue` kullan:

```rust
for entry in entries.flatten() {
    if let Err(e) = process_theme_file(entry.path(), registry) {
        tracing::warn!("tema yükleme atlandı: {} ({})", entry.path().display(), e);
        continue;
    }
}
```

**Avantajlar:**

- Sıfır build-time iş.
- Dev'de tema dosyalarını editör'le anlık değiştirip yeniden başlatma.

**Dezavantajlar:**

- Binary tek dosya değil; dağıtımda klasör yapısı korunmalı.
- `themes_dir` yolunu binary'nin nereden çağrıldığına göre çözmek
  gerekir.

#### Strateji 2: `RustEmbed` ile derleme zamanı gömme

Production binary'lerde yaygın. Tema dosyaları **derleme zamanında**
binary'ye gömülür; runtime'da disk gerekmez.

`Cargo.toml`:

```toml
[dependencies]
rust-embed = { version = "8", features = ["debug-embed"] }
```

`kvs_ui/src/assets.rs`:

```rust
use rust_embed::RustEmbed;

#[derive(RustEmbed)]
#[folder = "assets/"]
pub struct EmbeddedAssets;
```

Yükleme:

```rust
pub fn load_bundled_themes(registry: &kvs_tema::ThemeRegistry) -> anyhow::Result<()> {
    let baseline_dark = kvs_tema::fallback::kvs_default_dark();
    let baseline_light = kvs_tema::fallback::kvs_default_light();

    for path in EmbeddedAssets::iter().filter(|p| p.starts_with("themes/") && p.ends_with(".json")) {
        let file = EmbeddedAssets::get(&path)
            .ok_or_else(|| anyhow::anyhow!("embedded asset missing: {}", path))?;

        let family: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&file.data)?;

        for theme_content in family.themes {
            let baseline = match theme_content.appearance {
                kvs_tema::AppearanceContent::Dark => &baseline_dark,
                kvs_tema::AppearanceContent::Light => &baseline_light,
            };
            registry.insert(kvs_tema::Theme::from_content(theme_content, baseline));
        }
    }
    Ok(())
}
```

**Avantajlar:**

- Single-binary dağıtım.
- Çalışma zamanı disk erişimi yok = hızlı init.

**Dezavantajlar:**

- Tema değiştirmek için yeniden derleme.
- Build süresi artar (her tema dosyası binary'ye girer).
- `debug-embed` özelliği ile dev modda dosyalardan, release'de embed
  davranışı.

#### Strateji 3: `gpui::AssetSource` entegrasyonu

GPUI'nin kendi asset sistemini kullanmak istersen — özellikle SVG/icon
ile tutarlı asset pipeline'ı için.

```rust
use gpui::AssetSource;

pub struct KvsAssets;

impl AssetSource for KvsAssets {
    fn load(&self, path: &str) -> gpui::Result<Option<std::borrow::Cow<'static, [u8]>>> {
        EmbeddedAssets::get(path)
            .map(|f| Some(std::borrow::Cow::Owned(f.data.into_owned())))
            .ok_or_else(|| anyhow::anyhow!("asset not found: {}", path).into())
    }

    fn list(&self, path: &str) -> gpui::Result<Vec<gpui::SharedString>> {
        Ok(EmbeddedAssets::iter()
            .filter(|p| p.starts_with(path))
            .map(|p| p.to_string().into())
            .collect())
    }
}

// Uygulama girişinde:
fn main() {
    gpui::Application::new()
        .with_assets(KvsAssets)
        .run(|cx| {
            kvs_tema::init(cx);
            // Tema'lar AssetSource'tan okunabilir
            // ...
        });
}
```

GPUI'nin `cx.asset_source()` ile tema dosyalarına `Resource::Embedded(...)`
üzerinden erişebilirsin:

```rust
pub fn load_via_asset_source(
    registry: &kvs_tema::ThemeRegistry,
    cx: &App,
) -> anyhow::Result<()> {
    let assets = cx.asset_source();
    let theme_paths = assets.list("themes/")?;

    for path in theme_paths {
        if !path.ends_with(".json") { continue; }
        let bytes = assets.load(&path)?
            .ok_or_else(|| anyhow::anyhow!("asset missing: {}", path))?;

        let family: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&bytes)?;

        let baseline = kvs_tema::fallback::kvs_default_dark();
        for tc in family.themes {
            registry.insert(kvs_tema::Theme::from_content(tc, &baseline));
        }
    }
    Ok(())
}
```

**Avantajlar:**

- Icon, SVG, font ile tutarlı tek API.
- Asset cache ve loading davranışı GPUI tarafından yönetilir.

**Dezavantajlar:**

- AssetSource impl boilerplate'i.
- GPUI versiyon değişiminde trait imzası kayabilir (rehber.md #62).

#### Karar matrisi

| İhtiyaç | Strateji |
|---------|----------|
| Dev/prototip; tema'ları editörden anlık değiştirme | **1 — diskten** |
| Production single-binary dağıtım, tema sayısı az (<20) | **2 — RustEmbed** |
| GPUI asset pipeline ile tutarlı; tema sayısı çok veya kullanıcı eklenebilir | **3 — AssetSource** |
| Karma: built-in + kullanıcı tema dizini | Strateji 2 + ek kullanıcı dizin yüklemesi |

#### Hot reload (file watcher)

Dev modda tema dosyasını editörden değiştirip uygulamayı yeniden
başlatmadan görmek istersen:

```rust
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use std::path::PathBuf;

pub fn init_hot_reload(
    themes_dir: PathBuf,
    cx: &mut App,
) -> anyhow::Result<()> {
    let (tx, rx) = std::sync::mpsc::channel();
    let mut watcher = notify::recommended_watcher(tx)?;
    watcher.watch(&themes_dir, RecursiveMode::NonRecursive)?;

    cx.spawn(async move |cx| {
        loop {
            match rx.recv() {
                Ok(Ok(event)) if event.kind.is_modify() => {
                    for path in event.paths {
                        cx.update(|cx| {
                            let _ = kvs_tema::temayi_yeniden_yukle(&path, cx);
                        })?;
                    }
                }
                _ => {}
            }
        }
    }).detach();

    Ok(())
}
```

> **Production'da kapatın.** Hot reload tek dev kolaylığı; production
> kullanıcısı tema dosyasını manuel değiştirmez. `#[cfg(debug_assertions)]`
> ile gate'le.

#### Tema dosyası yapısı

`assets/themes/` altında konvansiyon:

```
assets/themes/
├── LICENSE_MIT           ← Zed'den alınan MIT temaların lisansı
├── LICENSE_APACHE        ← Apache lisanslı temaların lisansı
├── README.md             ← Hangi tema hangi lisans
├── one.json              ← One Light + One Dark
├── solarized.json        ← Solarized Light + Dark
└── monokai.json          ← Monokai
```

**Her tema dosyası bir `ThemeFamilyContent`** — birden fazla varyant
(light + dark) içerebilir.

#### Tuzaklar

1. **`themes_dir` working directory bağımlılığı**: Disk yükleme'de
   `assets/themes` relative path; binary nereden çalıştırılırsa oraya
   göre çözülür. **Mutlak yol** üret:
   ```rust
   let exe_dir = std::env::current_exe()?.parent().unwrap().to_path_buf();
   let themes_dir = exe_dir.join("assets").join("themes");
   ```
2. **`RustEmbed` derleme süresini şişirmek**: Her tema dosyası binary'ye
   gömülür. 100 MB tema klasörü = 100 MB binary. Ayıklama:
   ```toml
   #[derive(RustEmbed)]
   #[folder = "assets/"]
   #[include = "themes/*.json"]
   #[include = "themes/LICENSE_*"]
   ```
3. **Async yükleme'de `cx` lifetime**: `cx.spawn` içinde `AsyncApp`;
   `cx.update(|cx| ...)` ile sync bağlama düş (Bölüm VI/Konu 31).
4. **Aynı isim çakışması**: Bundled tema "One Dark" + kullanıcı tema
   "One Dark" — kullanıcı tema **üzerine yazar** (`insert` semantiği).
   Bilinçli; kullanıcının modifikasyonu öncelikli.
5. **`baseline` seçimi atlamak**: Dark tema'nın baseline'ı light yapılırsa
   eksik alanlar light değerlerden gelir = uyumsuz görüntü. Mutlaka
   `appearance`'a göre baseline seç.
6. **`include_bytes!` yerine `RustEmbed`**: `include_bytes!` tek dosya;
   onlarca tema için `RustEmbed` tek macro çağrısı.
7. **Hot reload production'da açık**: File watcher CPU/IO maliyeti +
   güvenlik riski (kullanıcı path injection). `cfg(debug_assertions)`
   ile gate.

---

### 34. Fixture testleri ve JSON sözleşme doğrulama

**Kaynak dizin:** `kvs_tema/tests/fixtures/`.

Fixture testleri = **gerçek Zed tema JSON'larını** kullanarak sözleşme
parite'sini doğrular. Tek bir parse hatası sözleşmenin delindiğini
gösterir.

#### Dizin yapısı

```
kvs_tema/tests/
├── fixtures/
│   ├── one-dark.json           ← Zed assets/themes/one/one.json (MIT)
│   ├── one-light.json          ← Aynı paket, light variant
│   ├── solarized.json          ← Zed solarized (MIT)
│   ├── LICENSE_MIT             ← Zed'den kopyalanan lisans
│   ├── README.md               ← Fixture kaynak ve lisans tablosu
│   └── synthetic/
│       ├── empty.json          ← Boş tema (test için sentetik)
│       ├── unknown_field.json  ← Bilinmeyen alan
│       └── invalid_color.json  ← Geçersiz hex
├── parse_fixture.rs            ← Zed tema'ları parse edebiliyor mu?
├── synthetic.rs                ← Sentetik testler
└── refinement.rs               ← Refinement davranış testleri
```

#### `tests/parse_fixture.rs` — gerçek tema testleri

```rust
use kvs_tema::{schema::ThemeFamilyContent, Theme, fallback};

fn baseline_dark() -> Theme {
    fallback::kvs_default_dark()
}

fn baseline_light() -> Theme {
    fallback::kvs_default_light()
}

#[test]
fn parses_zed_one_dark() {
    let json = include_str!("fixtures/one-dark.json");
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json)
        .expect("Zed one.json deserialize edilemedi");

    assert_eq!(family.name, "One");
    assert!(!family.themes.is_empty());

    for theme_content in family.themes {
        let baseline = match theme_content.appearance {
            kvs_tema::AppearanceContent::Dark => baseline_dark(),
            kvs_tema::AppearanceContent::Light => baseline_light(),
        };
        let theme = Theme::from_content(theme_content, &baseline);

        assert!(!theme.name.is_empty());
        // Baseline'dan farklı bir bg üretilmiş olmalı
        assert_ne!(theme.styles.colors.background, gpui::Hsla::default());
    }
}

#[test]
fn parses_zed_solarized() {
    let json = include_str!("fixtures/solarized.json");
    let _: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
}
```

**Pattern:**

- `include_str!` derleme zamanında dosyayı stringe gömer.
- `serde_json_lenient` — Zed JSON'unda yorum/trailing comma toleransı.
- `from_content` çağrısı ile **tam akış** test edilir (parse + refinement
  + Theme yapısı).

#### `tests/synthetic.rs` — kenar durumlar

```rust
use kvs_tema::{schema::ThemeFamilyContent, Theme, fallback};

#[test]
fn empty_theme_uses_baseline() {
    let json = r#"{
        "name": "Empty",
        "author": "x",
        "themes": [{
            "name": "Empty Theme",
            "appearance": "dark",
            "style": {}
        }]
    }"#;
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
    let baseline = fallback::kvs_default_dark();
    let theme = Theme::from_content(
        family.themes.into_iter().next().unwrap(),
        &baseline,
    );

    // Tüm renkler baseline'dan gelmeli
    assert_eq!(theme.styles.colors.background, baseline.styles.colors.background);
    assert_eq!(theme.styles.status.error, baseline.styles.status.error);
}

#[test]
fn unknown_field_does_not_break() {
    let json = r#"{
        "name": "Test", "author": "x",
        "themes": [{
            "name": "T", "appearance": "dark",
            "style": {
                "background": "#000000ff",
                "future.unknown.field": "#ffffffff"
            }
        }]
    }"#;
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
    let baseline = fallback::kvs_default_dark();
    let _ = Theme::from_content(
        family.themes.into_iter().next().unwrap(),
        &baseline,
    );
}

#[test]
fn invalid_hex_falls_to_baseline() {
    let json = r#"{
        "name": "T", "author": "x",
        "themes": [{
            "name": "T", "appearance": "dark",
            "style": { "background": "not-a-color" }
        }]
    }"#;
    let family: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
    let baseline = fallback::kvs_default_dark();
    let theme = Theme::from_content(
        family.themes.into_iter().next().unwrap(),
        &baseline,
    );

    // Geçersiz hex → baseline'dan
    assert_eq!(theme.styles.colors.background, baseline.styles.colors.background);
}

#[test]
fn unknown_enum_variant_falls_to_none() {
    let json = r#"{
        "color": "#000",
        "font_style": "semi_oblique"
    }"#;
    let h: kvs_tema::schema::HighlightStyleContent =
        serde_json::from_str(json).unwrap();
    assert!(h.color.is_some());
    assert!(h.font_style.is_none());  // bilinmeyen variant → None
}
```

#### `tests/refinement.rs` — refinement davranışları

```rust
use kvs_tema::*;

#[test]
fn status_color_derives_background_from_foreground() {
    use kvs_tema::schema::StatusColorsContent;
    let mut content = StatusColorsContent::default();
    content.error = Some("#ff5555ff".to_string());
    // error_background None

    let mut refinement = status_colors_refinement(&content);
    apply_status_color_defaults(&mut refinement);

    assert!(refinement.error.is_some());
    let bg = refinement.error_background.unwrap();
    assert!((bg.a - 0.25).abs() < 1e-6);
}

#[test]
fn refine_overrides_only_some_fields() {
    let baseline = fallback::kvs_default_dark();
    let mut colors = baseline.styles.colors.clone();

    let refinement = ThemeColorsRefinement {
        border: Some(gpui::hsla(0.5, 1.0, 0.5, 1.0)),
        ..Default::default()
    };

    let original_bg = colors.background;
    colors.refine(&refinement);

    assert_ne!(colors.border, baseline.styles.colors.border);  // override
    assert_eq!(colors.background, original_bg);                 // korundu
}
```

#### Yeni bir Zed tema fixture eklerken

**Adım 1 — Lisans doğrula:**

```sh
# Zed kaynağındaki lisans dosyasına bak
ls ../zed/assets/themes/one/
# LICENSE_MIT one.json
```

`LICENSE_MIT` → kullanılabilir. `LICENSE_GPL` veya lisans yoksa
**kullanma**.

**Adım 2 — Kopyala:**

```sh
cp ../zed/assets/themes/one/one.json tests/fixtures/one-dark.json
cp ../zed/assets/themes/one/LICENSE_MIT tests/fixtures/LICENSE_MIT
```

**Adım 3 — Atıf:**

`tests/fixtures/README.md`'ye satır ekle:

```markdown
| Dosya | Kaynak | Lisans | Atıf |
|-------|--------|--------|------|
| `one-dark.json` | `zed/assets/themes/one/one.json` | MIT | © Zed Industries |
```

**Adım 4 — Test ekle:**

```rust
#[test]
fn parses_zed_one_dark() {
    let json = include_str!("fixtures/one-dark.json");
    let _: ThemeFamilyContent = serde_json_lenient::from_str(json).unwrap();
}
```

**Adım 5 — Sync turunda doğrula:**

Her `tema_aktarimi.md` sync turunda fixture dosyalarını yeniden
kopyala — Zed JSON'unda yeni alan eklenmiş mi diye `unknown_field_does_not_break`
testi yetmez; gerçek tema dosyası tüm alanları içerir.

#### Test çalıştırma

```sh
# Tüm tema testleri
cargo test -p kvs_tema

# Sadece fixture
cargo test -p kvs_tema --test parse_fixture

# Verbose çıktı
cargo test -p kvs_tema -- --nocapture

# Tek bir test
cargo test -p kvs_tema parses_zed_one_dark
```

#### `gpui::TestAppContext` ile runtime testleri

Pencere açmaya gerek olmayan runtime testleri:

```rust
use gpui::TestAppContext;

#[gpui::test]
fn init_kurar_fallback_temalari(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);

        let registry = kvs_tema::ThemeRegistry::global(cx);
        assert!(registry.list_names().contains(&"Kvs Default Dark".into()));

        let theme = cx.theme();
        assert_eq!(theme.name.as_ref(), "Kvs Default Dark");
    });
}

#[gpui::test]
fn tema_degistir_aktifi_gunceller(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);

        kvs_tema::temayi_degistir("Kvs Default Light", cx).unwrap();

        let theme = cx.theme();
        assert_eq!(theme.appearance, kvs_tema::Appearance::Light);
    });
}
```

`gpui::test` attribute pencere/UI sürmez; `TestAppContext` headless
context. Tema runtime'ı bunda %100 test edilebilir.

#### Test stratejisi özeti

| Test türü | Hedef | Dosya |
|-----------|-------|-------|
| Gerçek tema parse | Sözleşme parite | `parse_fixture.rs` |
| Sentetik kenar durum | `treat_error_as_none`, bilinmeyen alan, geçersiz hex | `synthetic.rs` |
| Refinement davranış | `apply_status_color_defaults`, `refine` | `refinement.rs` |
| Runtime kurulum | `init`, `temayi_degistir`, registry | `runtime.rs` ile `TestAppContext` |
| Fallback bütünlüğü | Tüm alanlar dolu | `fallback.rs` |

#### Tuzaklar

1. **`include_str!` mutlak yol**: Path test dosyasına göredir; `include_str!("fixtures/one-dark.json")`
   `tests/fixtures/...` olarak çözülür. Mutlak yol verme.
2. **Fixture lisansını unutmak**: Dosyayı kopyalarken `LICENSE_*`'ı
   atlama. CI'da otomatik kontrol et:
   ```sh
   ls tests/fixtures/LICENSE_* 1>/dev/null || (echo "lisans dosyası yok!" && exit 1)
   ```
3. **Test'lerin `init`'i**: `kvs_tema::init(cx)` her test başında
   manuel çağır; auto-setup yok. `TestAppContext::update` callback'i
   içinde.
4. **`assert_eq!` Hsla karşılaştırma**: Floating point eşitlik tehlikeli.
   `assert!((a.h - b.h).abs() < 1e-6)` ile epsilon karşılaştır.
5. **`#[gpui::test]` vs `#[test]`**: GPUI runtime testleri `gpui::test`;
   pure sözleşme testleri `test`. Karıştırma; gereksiz overhead.
6. **Fixture dosyasını yerinde değiştirmek**: Test patches fixture =
   testler kendi datasını yazıp doğruluyor. Fixture dosyaları
   **read-only**; sentetik kenar durumları ayrı dosya/inline string.
7. **Sync turunda fixture'ı güncellememek**: Yeni Zed alanları geldi
   ama fixture eski. `unknown_field_does_not_break` testi yetmez —
   yeni alanların doğru parse edildiğini ancak yeni fixture gösterir.

---

### 35. Lisans doğrulama akışı

Üç farklı lisans hattını ayrı ayrı izle: **bağımlılıklar** (kod), **Zed
tema fixture'ları** (data), ve **fallback paleti** (kendi tasarım
kararın).

#### Lisans matrisi

| Kaynak | Tip | Lisans | Sözleşme |
|--------|-----|--------|----------|
| `gpui` (Zed workspace) | Code dependency | Apache-2.0 | Doğrudan dep olarak kullan |
| `refineable` | Code dependency | Apache-2.0 | Doğrudan dep |
| `collections` | Code dependency | Apache-2.0 | Doğrudan dep |
| Zed `theme`/`syntax_theme` | Code reference | GPL-3.0-or-later | **Mirror, kopyalama** (Bölüm I/Konu 3) |
| Zed `theme_settings`/`theme_selector` | Code reference | GPL-3.0-or-later | **Sadece referans, dep yok** |
| Zed tema JSON'ları | Data fixture | Tema-özel (MIT/Apache/GPL) | **Lisans dosyasıyla beraber kopyala** |
| `default_colors.rs` HSL değerleri | Design data | GPL-3.0-or-later | **Kopyalama; kendi paletini seç** |

#### Zed tema lisansları

Zed'in `assets/themes/` dizininde **her tema kendi lisansını** taşır.
Aynı dizin altında birden fazla lisans dosyası olabilir:

```
zed/assets/themes/
├── one/
│   ├── LICENSE_MIT
│   └── one.json
├── solarized/
│   ├── LICENSE_MIT
│   └── solarized.json
├── monokai/
│   ├── LICENSE_GPL          ← GPL — kullanılamaz
│   └── monokai.json
└── tokyo-night/
    ├── LICENSE_APACHE
    └── tokyo-night.json
```

**Kontrol komutu:**

```sh
# Hangi temalar hangi lisansta?
find ../zed/assets/themes -name "LICENSE_*" | sort
```

`LICENSE_GPL` görürsen o tema senin için yasak; `LICENSE_MIT` /
`LICENSE_APACHE` → kullanılabilir.

#### Yeni tema eklerken kontrol listesi

```sh
# 1. Lisans dosyasını oku
cat ../zed/assets/themes/<tema>/LICENSE_*

# 2. Lisans uygunsa kopyala (tema + lisans birlikte)
cp ../zed/assets/themes/<tema>/<tema>.json kvs_ui/assets/themes/
cp ../zed/assets/themes/<tema>/LICENSE_* kvs_ui/assets/themes/

# 3. Atıf metnini güncelle
$EDITOR kvs_ui/assets/themes/README.md

# 4. Fixture testlerine ekle (test edilecekse)
$EDITOR kvs_tema/tests/parse_fixture.rs
```

#### Atıf README'si

`kvs_ui/assets/themes/README.md`:

```markdown
# Built-in temalar — kaynak ve lisans

Bu dizindeki tema JSON'ları aşağıdaki kaynaklardan alındı.

| Dosya | Kaynak repo | Yol | Lisans | Telif |
|-------|-------------|-----|--------|-------|
| `one.json` | github.com/zed-industries/zed | `assets/themes/one/one.json` | MIT | © Zed Industries |
| `solarized.json` | github.com/zed-industries/zed | `assets/themes/solarized/solarized.json` | MIT | © Ethan Schoonover |
| `tokyo-night.json` | github.com/zed-industries/zed | `assets/themes/tokyo-night/...` | Apache-2.0 | © Tokyo Night contributors |

## Senkron tarihi

Son senkron: 2026-05-11 (Zed pin `db6039d815`). Bkz.
`../../gpui_belge/tema_aktarimi.md`.
```

#### CI'da lisans doğrulama

```sh
#!/bin/sh
# scripts/check_theme_licenses.sh
set -e

THEMES_DIR="kvs_ui/assets/themes"
FIXTURES_DIR="kvs_tema/tests/fixtures"

# Her dizinde en az bir LICENSE_* dosyası olmalı
for dir in "$THEMES_DIR" "$FIXTURES_DIR"; do
    if ! ls "$dir"/LICENSE_* 1>/dev/null 2>&1; then
        echo "HATA: $dir altında lisans dosyası yok"
        exit 1
    fi
done

# GPL lisansı yasak
if ls "$THEMES_DIR"/LICENSE_GPL* 1>/dev/null 2>&1; then
    echo "HATA: $THEMES_DIR altında GPL tema bulundu — kaldır"
    exit 1
fi

# README atıf tablosu var mı
[ -f "$THEMES_DIR/README.md" ] || (echo "atıf README eksik" && exit 1)

echo "lisans kontrolü ✓"
```

CI workflow'una ekle (`.github/workflows/ci.yml`):

```yaml
- name: Tema lisans kontrolü
  run: ./scripts/check_theme_licenses.sh
```

#### Sync turunda lisans denetimi

Her `tema_aktarimi.md` sync turunda:

1. **Yeni eklenen Zed tema'ları kontrol et:**
   ```sh
   awk '/^pub fn/ || /LICENSE_/' ../zed/assets/themes/*/LICENSE_* 2>/dev/null
   diff <(ls /eski/zed/assets/themes) <(ls ../zed/assets/themes)
   ```
2. **Lisansı değişmiş temalar var mı?** Bir tema dosyası kaldı ama
   `LICENSE_MIT` → `LICENSE_GPL` oldu = kullanmaya devam edemezsin.
   Kaldır.
3. **README'yi güncelle:** Yeni eklenmiş/kaldırılmış tema satırları.

#### Dependency lisans denetimi

`cargo` ile direct/transitive lisansları listele:

```sh
# cargo-license eklentisi
cargo install cargo-license
cargo license --json | jq '.[] | {name, license}'
```

GPL-3 bulursan → o dependency'i kaldır veya alternatife geç.

`deny.toml` ile CI'da bloklama:

```toml
[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause", "MPL-2.0"]
deny = ["GPL-3.0", "GPL-2.0", "AGPL-3.0"]
```

```sh
cargo install cargo-deny
cargo deny check licenses
```

#### Fallback paleti lisans hatırlatması

Bölüm I/Konu 3 ve Konu 32'de işlendi; özetle:

- Zed'in `default_colors.rs` HSL değerlerini **birebir kopyalama**.
- Açık lisanslı paletten esinlen (Tailwind, Catppuccin, Nord, Solarized),
  esinlendiğin paleti `DECISIONS.md`'ye yaz.
- `kvs_default_dark` ve `kvs_default_light` **senin tasarım kararın**;
  lisansı senin lisansın (MIT/Apache vs.).

#### Lisans dökümantasyonu

Üç doküman senkron tutulur:

| Doküman | İçerik | Güncellenme |
|---------|--------|-------------|
| `kvs_tema/Cargo.toml` `license = "MIT"` | Kendi crate lisansın | Tek seferlik karar |
| `kvs_ui/assets/themes/README.md` | Built-in tema atıfları | Yeni tema eklenince |
| `kvs_tema/tests/fixtures/README.md` | Fixture atıfları | Fixture eklenince/sync |
| `DECISIONS.md` | Fallback palet esinlenme kaynağı | İlk pin'de + revizyonda |
| `tema_aktarimi.md` | Sync turunda lisans kontrolü notu | Her sync turunda |

#### Tuzaklar

1. **Lisans dosyasını "sonra ekleyeyim"**: Build sırasında binary'ye
   tema JSON'u girer ama LICENSE girmezse **dağıtım anında lisans
   ihlali**. CI'da kontrol et.
2. **`LICENSE_GPL` görmezden gelmek**: Tema dosyasındaki HSL'leri
   "sadece JSON" zannetmek = telif ihlali. GPL temaları **kullanma**.
3. **Atıf README'sini güncellememek**: Yeni tema ekleyip atıf eklemezsen
   "kim hangi tema'yı yazdı?" sorusu cevapsız; lisansın "telif sahibi
   gösterimi" şartı ihlal.
4. **Cargo dep'lerinde GPL**: Yanlışlıkla GPL bir crate eklersen
   uygulamanın **tamamı** GPL'e tabi olur. `cargo-deny` ile kontrol et.
5. **`palette`/`refineable` lisans karıştırması**: `palette` MIT/Apache
   dual; `refineable` Apache-2.0. Hangi crate hangi lisans, `cargo
   license` ile teyit et — manuel hatırlamaya güvenme.
6. **Fixture dosyasını fork'tan almak**: Tema JSON Zed'in **upstream**
   reposundan alınmalı; bir fork'tan kopyalarsan o fork'un lisans
   değişikliği veya patch'i de gelir. `tema_aktarimi.md` pin'inden
   tut.
7. **Hot reload yolundan kullanıcı dosyası**: Kullanıcının `~/.config/kvs/themes/`
   dizinine koyduğu tema = kullanıcının kendi sorumluluğu; senin lisans
   matrisin etkilenmez. Built-in vs user'ı ayrı tut.

---

## Bölüm VIII — Tüketim ve dış API

Bu bölüm tema sisteminin **dış tüketicilerle** olan sözleşmesini ele
alır: UI bileşenlerinin temayı nasıl okuduğu, etkileşim durumları için
hangi alanları kullandığı, hangi tiplerin dış API olarak kararlı,
hangilerinin crate-içi, ve test ortamında temanın nasıl izole
edileceği.

> **Sınır kuralı:** Tüketici (UI bileşeni, başka crate) sadece
> **`pub use`'la dışa açılan tipleri** kullanır. Refinement katmanı
> ve şema iç implementasyon detayları — bunlara dayanmak crate'in sync
> evriminden etkilenmeye yol açar.

---

### 36. `cx.theme()` ile bileşen renklendirme

**Tüketici sözleşmesi:** UI bileşenleri tema değerlerine `cx.theme()`
üzerinden erişir. Bu çağrı `&Arc<Theme>` döner — klonsuz, allocation
yok.

#### Temel kalıp

```rust
use gpui::{div, prelude::*, App, Window, Context};
use kvs_tema::ActiveTheme;

struct AnaPanel;

impl Render for AnaPanel {
    fn render(
        &mut self,
        _w: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let tema = cx.theme();
        div()
            .bg(tema.styles.colors.background)
            .text_color(tema.styles.colors.text)
            .border_1()
            .border_color(tema.styles.colors.border)
            .p_4()
            .child("Merhaba")
    }
}
```

**Üç gerek:**

1. **`use kvs_tema::ActiveTheme;`** — trait import edilmemişse `cx.theme()`
   "method not found" hatası verir.
2. **`let tema = cx.theme();`** — `&Arc<Theme>` döndüğü için `&self`
   borrow gibi davranır; render içinde tek seferlik bağlama.
3. **Alan erişimi** — `tema.styles.colors.background` veya (opsiyonel
   accessor varsa) `tema.colors().background`.

#### Erişim yolları kıyaslaması

```rust
// 1. Doğrudan alan zinciri (Bölüm III/Konu 12)
let bg = tema.styles.colors.background;
let muted = tema.styles.colors.text_muted;
let error = tema.styles.status.error;
let local = tema.styles.player.local().cursor;

// 2. Accessor metotları (önerilen — iç düzen değişimine dirençli)
let bg = tema.colors().background;
let error = tema.status().error;
```

**Accessor metotları neden tercih?** `styles` alanının iç düzeni sync
turunda değişebilir (örn. `colors` ve `status` ayrıştırılır). Accessor
yöntemi sözleşmeyi `theme.colors()` üzerinde sabitler; tüketici kodu
etkilenmez.

#### Prelude modül deseni

`kvs_tema` her render dosyasında üç import gerektirebilir:

```rust
use kvs_tema::ActiveTheme;
use kvs_tema::Theme;
use kvs_tema::Appearance;
```

Prelude modül bunu tek satıra indirir:

```rust
// kvs_tema/src/prelude.rs
pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily, ThemeStyles};
pub use crate::styles::*;
```

Tüketici:

```rust
use kvs_tema::prelude::*;
```

> **`gpui::prelude` ile çakışma:** GPUI'nin `prelude::*`'ı `Render`
> ve fluent API trait'lerini getirir. `kvs_tema::prelude::*`'ı yanına
> koyarsan iki ayrı `use` satırı:
> ```rust
> use gpui::{prelude::*, div, App, Window, Context};
> use kvs_tema::prelude::*;
> ```

#### Stateless okuma vs cached değer

```rust
// (A) Stateless — her render'da tema okur
impl Render for X {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div().bg(cx.theme().colors().background)
    }
}

// (B) Cached — state'te tutar
struct X {
    bg: Hsla,
}
impl X {
    fn new(cx: &mut Context<Self>) -> Self {
        Self { bg: cx.theme().colors().background }
    }
}
impl Render for X {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        div().bg(self.bg)  // ← tema değişirse güncellenmez!
    }
}
```

**Her zaman (A) — stateless.** `cx.refresh_windows()` (Bölüm VI/Konu
31) view'ı yeniden çağırır; tema yeni değerlerle okunur. (B) tema
değişimine **kapalı** — eski rengi tutar; bug.

İstisna: render içinde **hesaplanmış değer** (örn. `bg.opacity(0.5)`)
performans için cache edilebilir; ama `cx.theme()` çağrısı zaten
allocation'suz, cache gereksiz.

#### Birden fazla alan okuma

`cx.theme()` çağrısını **bir kez yap**, türeyenleri lokal bind et:

```rust
// İYİ
let tema = cx.theme();
let colors = tema.colors();
let status = tema.status();

div()
    .bg(colors.background)
    .text_color(colors.text)
    .border_color(if has_error { status.error } else { colors.border })

// KÖTÜ (her çağrı `cx.global` lookup)
div()
    .bg(cx.theme().colors().background)
    .text_color(cx.theme().colors().text)
    .border_color(if has_error {
        cx.theme().status().error
    } else {
        cx.theme().colors().border
    })
```

Tekrar maliyeti pratikte düşük (`cx.global` HashMap lookup), ama
okunabilirlik için tek bağlama.

#### Bileşen tasarım reçetesi

UI bileşenleri için **tema okuma sözleşmesi**:

```rust
use kvs_tema::prelude::*;

struct Button {
    label: SharedString,
    on_click: Box<dyn Fn(&mut Window, &mut App)>,
}

impl Render for Button {
    fn render(
        &mut self,
        _w: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let colors = cx.theme().colors();

        div()
            .px_3()
            .py_2()
            .bg(colors.element_background)
            .text_color(colors.text)
            .rounded_md()
            .border_1()
            .border_color(colors.border)
            .child(self.label.clone())
    }
}
```

**Sözleşme noktaları:**

- Bileşen kendi içinde tema okur — parent'tan renk parametre olarak
  almaz.
- Bileşen `Theme` tipini import etmez; sadece `ActiveTheme` trait'ini
  (prelude ile).
- Bileşen state'inde `Hsla` tutmaz — her render fresh okur.

#### Tuzaklar

1. **`use kvs_tema::ActiveTheme;` unutmak**: `cx.theme()` "method not
   found" hatası. En yaygın import bug'ı. Prelude kullan.
2. **`cx.theme().clone()`**: `&Arc<Theme>` zaten ucuz; `.clone()`
   refcount artırır ama referans yeterli. Gereksiz.
3. **Bileşen state'inde renk cache'lemek**: Tema değişiminde stale.
   Stateless oku.
4. **`tema.styles.colors.X` zinciri**: Tutarlılık iyi ama accessor
   metotları yoksa iç düzen sızıntısı. Accessor ekle (`theme.colors()`).
5. **Render dışında `cx.theme()`**: `&mut Context<Self>` `App`'ten
   `cx.theme()` çağırmana izin verir; ama render fazı dışında çağrı
   genelde yanlış soyutlama — bileşen state'i tutar, theme değişiminde
   yeniden okunmaz. Render fazına bağla.
6. **`Context<T>` yerine `&Window`**: `Window` üzerinden `cx.theme()`
   yok; `Window` `App` deref etmez. Render imzası `(&mut Window, &mut
   Context<Self>)` — iki parametre ayrı.

---

### 37. Hover / active / disabled / selected / ghost desenleri

GPUI'nin fluent API'si etkileşim durumları için `.hover()`, `.active()`
ve `Interactivity` katmanı sağlar. Tema'da her durum için **özel
alanlar** var; nasıl eşleneceği sözleşmenin bir parçası.

#### Etkileşim alanları eşlemesi

```
ThemeColors:
├── element_background    ← varsayılan
├── element_hover         ← .hover(|s| s.bg(...))
├── element_active        ← .active(|s| s.bg(...))
├── element_selected      ← seçili state (uygulama mantığı)
├── element_selection_background  ← metin seçim bg
├── element_disabled      ← disabled state
│
├── ghost_element_background  ← transparan varyant
├── ghost_element_hover
├── ghost_element_active
├── ghost_element_selected
└── ghost_element_disabled
```

#### Temel etkileşim deseni

```rust
use gpui::{div, prelude::*};
use kvs_tema::prelude::*;

impl Render for InteractiveButton {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let colors = cx.theme().colors();

        div()
            .id("btn")                              // ← Interactivity için ID şart
            .px_3()
            .py_2()
            .bg(colors.element_background)
            .text_color(colors.text)
            .rounded_md()
            .hover(|s| s.bg(colors.element_hover))
            .active(|s| s.bg(colors.element_active))
            .child("Click")
    }
}
```

**Önemli:**

- `.id(...)` çağrısı **şart** — Interactivity (hover/active/click)
  bileşeni stateful, ID olmadan GPUI durumu tanıyamaz.
- `.hover(|s| ...)`, `.active(|s| ...)` — `StyleRefinement` callback'i
  (Bölüm II/Konu 11). Bu refinement element üstüne layer'lanır.

#### Hover varyantları

```rust
// 1. Tek alan değişimi
div().bg(colors.element_background)
    .hover(|s| s.bg(colors.element_hover))

// 2. Hover'da border ekleme
div().border_1().border_color(colors.border)
    .hover(|s| s.border_color(colors.border_focused))

// 3. Hover'da text rengi değişimi
div().text_color(colors.text_muted)
    .hover(|s| s.text_color(colors.text))
```

#### Active (basılı) state

```rust
div()
    .bg(colors.element_background)
    .hover(|s| s.bg(colors.element_hover))
    .active(|s| s.bg(colors.element_active))
```

**Sıralama önemli:** GPUI önce hover, sonra active uygular. Active'de
verdiğin alan, hover'ın üstüne yazılır. Active state, mouse button
basılıyken aktif.

#### Disabled state

GPUI'nin doğrudan `.disabled(|s| ...)` callback'i yok; durum mantığını
sen yönetirsin:

```rust
let bg = if self.is_disabled {
    colors.element_disabled
} else {
    colors.element_background
};

let text = if self.is_disabled {
    colors.text_disabled
} else {
    colors.text
};

div()
    .id("btn")
    .bg(bg)
    .text_color(text)
    .when(!self.is_disabled, |this| {
        this.hover(|s| s.bg(colors.element_hover))
            .active(|s| s.bg(colors.element_active))
            .on_click(/* ... */)
    })
```

`.when(cond, |this| ...)` — koşullu fluent. Disabled'da hover/active
ve click handler atlanır.

> **Alternatif:** `element_disabled` zaten "soluk" rengi taşır; hover
> davranışını disabled'da tamamen kapatmak yerine sadece görsel
> feedback'i farklılaştırmak yeterli olabilir. Tasarım kararına bağlı.

#### Selected state

Seçili öğeler için **uygulama mantığı** durumu tanır; tema sadece
rengini sağlar:

```rust
struct ListItem {
    label: SharedString,
    is_selected: bool,
}

impl Render for ListItem {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let colors = cx.theme().colors();

        let bg = if self.is_selected {
            colors.element_selected
        } else {
            colors.element_background
        };

        div()
            .id(SharedString::from(format!("item-{}", self.label)))
            .px_3().py_2()
            .bg(bg)
            .text_color(colors.text)
            .hover(|s| s.bg(colors.element_hover))
            .child(self.label.clone())
    }
}
```

> **`element_selected` vs `element_selection_background`:**
> - `element_selected` = bir liste öğesinin seçili durumu.
> - `element_selection_background` = metin seçimi (highlight) arka planı.
> İkisi farklı; karıştırma.

#### Ghost element family

"Ghost" = transparan arka planlı element; toolbar icon button gibi
yüzeye yapışmış görünüm.

```rust
div()
    .id("toolbar-btn")
    .p_2()
    .bg(colors.ghost_element_background)         // transparan
    .text_color(colors.icon)
    .hover(|s| s.bg(colors.ghost_element_hover)) // hover'da görünür ol
    .active(|s| s.bg(colors.ghost_element_active))
```

`ghost_element_background` genelde `hsla(0, 0, 0, 0)` (tamamen şeffaf).
Hover'da `ghost_element_hover` (genelde `elevated_surface_background`'a
yakın) görünür hale gelir.

**Ne zaman ghost kullan?**

| Durum | element | ghost_element |
|-------|---------|---------------|
| Toolbar icon button | | ✓ |
| Form button | ✓ | |
| Sidebar item | | ✓ (genelde) |
| Modal action | ✓ | |
| Tab şeridi | | ✓ |
| Dropdown trigger | ✓ | |

**Genel kural:** Element'in **kendine ait kromu** olacaksa (border,
visible bg) → `element_*`. Yüzeye yapışmış, sadece hover/active'de
görünüyorsa → `ghost_element_*`.

#### Drop target (drag & drop)

```rust
div()
    .bg(colors.background)
    .when(self.is_drop_target_active, |this| {
        this.bg(colors.drop_target_background)
            .border_2()
            .border_color(colors.drop_target_border)
    })
```

Drop target alanları drag sırasında "burada bırak" feedback'i için.

#### Etkileşim alanı seçim akış şeması

```
Bileşen interactive mi?
├── Hayır → element_background (statik bg) + text
│
└── Evet
    ├── Yüzeye yapışmış mı? (toolbar/sidebar/tab)
    │   └── Evet → ghost_element_background + ghost_element_hover/active
    │
    └── Kendi kromu var mı? (button/card/modal)
        └── Evet → element_background + element_hover/active
```

#### Tuzaklar

1. **`.id()` atlamak**: Interactivity stateful — ID yoksa hover/active
   çalışmaz, "method not found" yerine sessiz başarısızlık.
2. **`.hover` callback'inde tema'ya tekrar erişmek**:
   ```rust
   .hover(|s| s.bg(cx.theme().colors().element_hover))  // ← cx burada yok
   ```
   `cx` callback dışında bağlandığı için burada erişilmez. Önceden
   bind et:
   ```rust
   let hover_bg = colors.element_hover;
   .hover(move |s| s.bg(hover_bg))
   ```
3. **Hover ve active sıralama tersine**: `.active(...).hover(...)` yazsan
   bile davranış aynı (refinement sırası belirlenmiş); ama okunabilirlik
   için `hover → active` sıralaması idiomatik.
4. **`element_disabled` ile `element_background.opacity(0.5)`**: İkisi
   farklı tasarım kararı. Tema yazarı disabled'a özel renk vermiş
   olabilir; `element_disabled` alanını kullan.
5. **`element_selected` her zaman dolu sanmak**: Refinement aşamasında
   `Some` ise dolu; tema yazarı vermediyse baseline'dan gelir. Fallback
   tema değerini açık doldur (Bölüm VII/Konu 32).
6. **Ghost ve element karıştırmak**: Toolbar'a `element_background`
   verirsen şeffaf kalmak yerine yüzey rengiyle dolar = tasarım dili
   kayar.
7. **Etkileşim durumlarını kontrast olmayan renklerle vermek**: `element_hover`
   ile `element_background` arasında yeterli lightness farkı yoksa
   kullanıcı hover'ı fark etmez. Tema testinde gözle bak.

---

### 38. Public API kataloğu ve crate-içi sınır

`kvs_tema` ve `kvs_syntax_tema` crate'lerinin **dışa açtığı** sözleşme
ile **iç implementasyon detayları** ayrımı. Bu sınır, tüketici kodun
sync turlarında bozulmaması için kritik.

#### Sınır felsefesi

| Kategori | Kararlı | Kim kullanır | Değişimde davranış |
|----------|---------|--------------|-------------------|
| **Public API (kararlı)** | ✓ | Tüketici UI bileşenleri | Major sürüm bump |
| **Public API (kararsız)** | Kısmen | İleri kullanıcı / extension yazarı | Minor sürüm değişebilir |
| **Crate-içi (`pub(crate)`)** | ✗ | Sadece `kvs_tema` modülleri | Patch sürümde değişebilir |

#### `kvs_tema` public API kataloğu

**Veri tipleri (kararlı):**

```rust
pub use crate::Theme;
pub use crate::ThemeStyles;
pub use crate::ThemeFamily;
pub use crate::Appearance;

pub use crate::styles::ThemeColors;
pub use crate::styles::StatusColors;
pub use crate::styles::PlayerColors;
pub use crate::styles::PlayerColor;
pub use crate::styles::AccentColors;
pub use crate::styles::SystemColors;

pub use crate::icon_theme::IconTheme;
```

**Runtime (kararlı):**

```rust
pub use crate::runtime::ActiveTheme;       // cx.theme() için trait
pub use crate::runtime::GlobalTheme;
pub use crate::runtime::SystemAppearance;
pub use crate::runtime::init;
pub use crate::runtime::temayi_degistir;   // helper fonksiyon
```

**Registry (kararlı):**

```rust
pub use crate::registry::ThemeRegistry;
pub use crate::registry::ThemeNotFound;
```

**Fallback (kararlı):**

```rust
pub use crate::fallback::kvs_default_dark;
pub use crate::fallback::kvs_default_light;
```

**Schema (KARARSIZ — extension/ileri kullanım için):**

```rust
pub use crate::schema::*;  // ThemeContent, ThemeColorsContent, ...
pub use crate::schema::try_parse_color;
```

> **Schema kararsız:** Bu tipler JSON sözleşmesini taşır; Zed sync
> turlarında yeni alan/enum eklenebilir. Tüketici doğrudan
> `ThemeColorsContent` kullanırsa yeni alan parse'ında derleme bozulabilir.
> Mecbur değilse kullanma; `Theme::from_content` üzerinden çalış.

**`kvs_syntax_tema` public API:**

```rust
pub use SyntaxTheme;
```

Tek tip. `HighlightStyle` GPUI'den geliyor; re-export gereksiz.

#### Crate-içi (NON-public) modüller

| Modül | İçerik | Erişim |
|-------|--------|--------|
| `refinement.rs` | `theme_colors_refinement`, `status_colors_refinement`, `apply_status_color_defaults`, `color()` helper | `pub(crate)` — sadece `Theme::from_content` çağırır |
| `runtime` iç detay | `GlobalThemeRegistry`, `GlobalSystemAppearance` newtype'ları | `pub(crate)` veya `pub(super)` |

**Neden gizli?** Refinement davranışı Zed'in evrimine bağlı. Türetme
kuralları (`apply_status_color_defaults`'ın 6 status listesi) sync
turunda değişebilir. Tüketici bu fonksiyonu doğrudan çağırırsa kontrolün
dışında bağlılık oluşturur.

#### Lib kökü yapısı (`kvs_tema/src/kvs_tema.rs`)

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

// Modüller (crate-içi)
pub(crate) mod refinement;   // Bölüm V
mod fallback;
mod icon_theme;
mod registry;
mod runtime;
mod schema;
mod styles;

// Public API yeniden ihraç
pub use icon_theme::*;
pub use registry::*;
pub use runtime::*;
pub use schema::*;     // KARARSIZ — schema tipleri ile birlikte
pub use styles::*;

// fallback re-export (sadece public fonksiyonlar)
pub mod fallback {
    pub use crate::fallback::{kvs_default_dark, kvs_default_light};
}

// Theme/ThemeStyles/ThemeFamily/Appearance lib kökünde tanımlı
pub use crate::{Theme, ThemeStyles, ThemeFamily, Appearance};
```

**Pattern:**

- `pub(crate) mod refinement` — `refinement.rs` modülü dışarıya kapalı,
  içeride paylaşılır.
- `pub use module::*` — kararlı tiplerin tüm-ihracı (`*` riski Konu
  4 tablosunda).
- `pub mod fallback` — fallback fonksiyonları namespace altında (`kvs_tema::fallback::kvs_default_dark`).

#### `prelude` modülü (önerilen)

```rust
// kvs_tema/src/prelude.rs
//! kvs_tema prelude — sık kullanılan tipleri tek import'a indirir.

pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily, ThemeStyles};
pub use crate::styles::{
    AccentColors, PlayerColor, PlayerColors,
    StatusColors, SystemColors, ThemeColors,
};
```

Tüketici:

```rust
use kvs_tema::prelude::*;
// Theme, ActiveTheme, ThemeColors, vs. hepsi mevcut
```

> **Prelude'a `ThemeRegistry`/`GlobalTheme` koymadık.** Bu tipler
> uygulama init/admin kodu içindir — UI bileşenleri kullanmaz. Render
> path'i prelude'unu hafif tut.

#### Versiyon politikası (semver)

`kvs_tema` `0.x.y` aşamasındayken:

| Değişim | Sürüm bump |
|---------|------------|
| Public API'ye yeni alan/fn ekleme | `0.x.y+1` (patch) |
| Public API'de breaking change (alan kaldır, signature değiştir) | `0.x+1.0` (minor) |
| Mimari değişim (modül adı, prelude içerik) | `0.x+1.0` |
| Crate-içi (`pub(crate)`) değişim | `0.x.y+1` |

`1.0` sonrası:

| Değişim | Sürüm bump |
|---------|------------|
| Yeni alan/fn | Minor |
| Breaking | Major |
| Bug fix | Patch |

#### Tüketici sözleşmesi

Tüketici kodu güvenle yapabileceği şeyler:

✓ `cx.theme().colors().background` okumak
✓ `kvs_tema::Theme`, `kvs_tema::ThemeColors` importlamak
✓ `ThemeRegistry::global(cx)` ile registry sorgulamak
✓ `kvs_tema::init(cx)` çağırmak
✓ `kvs_tema::temayi_degistir(ad, cx)` ile tema değiştirmek
✓ `kvs_tema::SystemAppearance::global(cx)` ile sistem mod sorgulamak

Tüketicinin yapmaması gerekenler:

✗ `kvs_tema::theme_colors_refinement(...)` doğrudan çağırmak (crate-içi)
✗ `kvs_tema::apply_status_color_defaults(...)` çağırmak (crate-içi)
✗ `kvs_tema::schema::ThemeColorsContent` üzerinde `match` yazmak (kararsız)
✗ `Theme.styles.colors.X` yerine `theme.colors().X` öner (iç düzen sızıntısı)
✗ `GlobalThemeRegistry`/`GlobalSystemAppearance` newtype'larına dokunmak

#### `pub(crate)` ile gerçek izolasyon

`pub use crate::refinement::*` yazdığında **`refinement` modülü public
olur** — istemediğin halde dışa açtın. `pub(crate) mod refinement;`
ile modülü gizli tut, `Theme::from_content` impl bloğunda direkt çağır:

```rust
// kvs_tema.rs
pub(crate) mod refinement;

// Theme::from_content impl içinde (crate-içi)
use crate::refinement::{theme_colors_refinement, ...};
```

`refinement.rs`'in fonksiyonları `pub` olabilir; modülün kendisi
`pub(crate)` olduğu için dışa görünmez. Çapraz API.

#### Tüketici API doğrulama testi

`cargo doc --no-deps` çalıştırıp **sadece istediğin tiplerin
göründüğünü** doğrula:

```sh
cargo doc -p kvs_tema --no-deps --open
```

Doc sayfasında `theme_colors_refinement` veya `apply_status_color_defaults`
görünüyorsa `pub use` zincirini gözden geçir; sızıntı var.

#### Tuzaklar

1. **`pub use crate::*`'da `refinement` yakalanmak**: `pub use
   crate::refinement::*` yazıp sonra modülü `pub(crate)` yapmak —
   compile hatası ("re-exporting private module"). İkisi tutarlı
   olmalı.
2. **`Theme.styles` alanını public yapmak (`pub`)**: Şu an public — iç
   düzen sızıyor. Accessor metotları sundun mu? `styles`'ı
   `pub(crate)` yap, sadece accessor'lardan oku.
3. **`schema::*` glob ile public yapmak**: Schema tiplerinin tamamı
   dışa açılır; gelecekte iç tipler eklersen otomatik public olurlar.
   Açık tek tek `pub use`:
   ```rust
   pub use crate::schema::{
       ThemeFamilyContent, ThemeContent, ThemeStyleContent,
       ThemeColorsContent, StatusColorsContent, PlayerColorContent,
       HighlightStyleContent, AppearanceContent, WindowBackgroundContent,
       FontStyleContent, FontWeightContent,
       try_parse_color,
   };
   ```
4. **Semver dışı değişim**: 0.x'te de tüketici beklentisi vardır.
   Breaking değişim minor bump olsa bile changelog yaz.
5. **`prelude::*` glob importları endüstri görüşü dışında**: Bazı
   stil rehberleri glob'u reddediyor. Tüketici karar verir; sen
   prelude'u sun, kullanmazsa elle import etsin.
6. **`pub` accessor metodu yazmamak**: `theme.colors().background`
   gibi accessor olmadan `styles` alanına doğrudan erişim zorunlu;
   iç düzen değişiminde tüm tüketici kırılır. Accessor şart.
7. **Public API'ye `kvs_default_dark` doğrudan koymak**: `pub use
   fallback::*` ile değil, namespace altında (`pub mod fallback {
   pub use crate::fallback::{...}; }`) — tüketici `kvs_tema::fallback::kvs_default_dark`
   yazar, niyet açık.

---

### 39. Test ortamında tema mock'lama

UI bileşenlerini test ederken **tüm tema sistemini** init etmek
pratik değil; sadece bileşenin renge ihtiyaç duyduğu kadar mock
tema kur.

#### Strateji 1: Tam init (`kvs_tema::init`)

En basit. Test'in başında tam runtime kur:

```rust
use gpui::TestAppContext;
use kvs_tema::ActiveTheme;

#[gpui::test]
fn button_uses_theme_colors(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);  // Fallback temaları kurar

        let theme = cx.theme();
        assert_eq!(theme.appearance, kvs_tema::Appearance::Dark);
        assert_ne!(theme.styles.colors.background, gpui::Hsla::default());
    });
}
```

**Avantaj:** Production akışına en yakın. Init bug'ları erken yakalanır.

**Dezavantaj:** Her test fallback tema oluşumu için ~50 µs harcar.
Yüzlerce test çalıştırıyorsan kümülatif.

#### Strateji 2: Manuel kurulum (özel tema değerleri)

Test'in özel renk değerlerine ihtiyacı varsa, manuel kur:

```rust
use std::sync::Arc;
use gpui::{TestAppContext, hsla};
use kvs_tema::{
    Theme, ThemeStyles, ThemeColors, StatusColors, PlayerColors, AccentColors,
    SystemColors, Appearance, ActiveTheme, GlobalTheme, ThemeRegistry,
};
use kvs_syntax_tema::SyntaxTheme;

fn test_theme(bg: gpui::Hsla, fg: gpui::Hsla) -> Theme {
    Theme {
        id: "test".into(),
        name: "Test Theme".into(),
        appearance: Appearance::Dark,
        styles: ThemeStyles {
            window_background_appearance: gpui::WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors {
                background: bg,
                text: fg,
                // ... diğer alanlar için dummy değer
                ..fallback_colors_dark()  // ← kalanlar fallback'ten
            },
            status: fallback_status_dark(),
            player: PlayerColors::default(),
            accents: AccentColors::default(),
            syntax: SyntaxTheme::new(vec![]),
        },
    }
}

#[gpui::test]
fn button_with_custom_theme(cx: &mut TestAppContext) {
    cx.update(|cx| {
        let red = hsla(0.0, 1.0, 0.5, 1.0);
        let white = hsla(0.0, 0.0, 1.0, 1.0);

        let registry = Arc::new(ThemeRegistry::new());
        registry.insert(test_theme(red, white));

        ThemeRegistry::set_global(cx, registry);
        GlobalTheme::set_theme(cx, /* arc */);

        let theme = cx.theme();
        assert_eq!(theme.styles.colors.background, red);
    });
}
```

> **`..fallback_colors_dark()` yapmak için:** `ThemeColors`'a `Default`
> türetmen veya yardımcı bir `fn fallback_colors_dark() -> ThemeColors`
> tanımlaman gerek. Mevcut yapıda `ThemeColors`'ın `Default`'u yok
> (tüm alanları zorunlu); test helper'ı yaz.

#### Strateji 3: `kvs_tema` test helper'ı

`kvs_tema/src/test.rs` (yeni modül, `#[cfg(any(test, feature = "test-util"))]`):

```rust
#[cfg(any(test, feature = "test-util"))]
pub mod test {
    use crate::*;
    use std::sync::Arc;

    /// Test için minimal tema kurar.
    pub fn init_test(cx: &mut gpui::App) {
        let registry = Arc::new(ThemeRegistry::new());
        registry.insert(test_theme());
        ThemeRegistry::set_global(cx, registry);
        GlobalTheme::set_theme(
            cx,
            ThemeRegistry::global(cx).get("Test").unwrap(),
        );
    }

    /// Yeniden kullanılabilir test tema'sı.
    pub fn test_theme() -> Theme {
        // Tüm alanları açık ama belirgin renklerle doldur
        // (debug için fark edilir)
        let red = gpui::hsla(0.0, 1.0, 0.5, 1.0);
        let green = gpui::hsla(0.333, 1.0, 0.5, 1.0);
        Theme {
            id: "test".into(),
            name: "Test".into(),
            appearance: Appearance::Dark,
            styles: ThemeStyles {
                colors: ThemeColors {
                    background: red,
                    border: green,
                    text: green,
                    // ... her alan benzersiz renkte (debug için)
                },
                // ...
            },
        }
    }
}
```

Tüketici (`kvs_ui/tests/...`):

```rust
[dev-dependencies]
kvs_tema = { path = "../kvs_tema", features = ["test-util"] }
```

```rust
use kvs_tema::test::init_test;

#[gpui::test]
fn render_uses_test_theme(cx: &mut TestAppContext) {
    cx.update(|cx| {
        init_test(cx);

        let theme = cx.theme();
        assert_eq!(theme.name.as_ref(), "Test");
    });
}
```

#### Snapshot test deseni

Tema değerlerinin **belirli yerlerde** kullanıldığını doğrulamak için:

```rust
use kvs_tema::test::{init_test, test_theme};

#[gpui::test]
fn button_renders_with_theme_background(cx: &mut TestAppContext) {
    cx.update(|cx| {
        init_test(cx);

        let theme = test_theme();
        let expected_bg = theme.styles.colors.element_background;

        let button = cx.new(|_| Button::new("OK".into()));

        // Element ağacını inspect et (test API'ları rehber.md #75'te)
        // Veya rendered scene'i query et:
        let render_output = /* ... */;
        assert!(render_output.contains_bg(expected_bg));
    });
}
```

> **GPUI test API'ları:** `TestAppContext::simulate_input`,
> `find_view`, vs. rehber.md #75'te detaylı. Render output'unu test
> etmek tema'nın doğru okunduğunu doğrular; tema'nın **kendi**
> doğruluğu için Bölüm VII fixture testleri yeterli.

#### Tema değişimi simülasyonu

```rust
#[gpui::test]
fn ui_updates_on_theme_change(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);
        let initial = cx.theme().name.clone();

        // Light'a geç
        kvs_tema::temayi_degistir("Kvs Default Light", cx).unwrap();

        let new_theme = cx.theme();
        assert_ne!(new_theme.name, initial);
        assert_eq!(new_theme.appearance, kvs_tema::Appearance::Light);
    });
}
```

#### Test'te `refresh_windows`

`TestAppContext` headless — açık pencere yok. `cx.refresh_windows()`
hata vermez ama hiçbir etkisi olmaz. Tema değişimini test ederken
`cx.theme()` çağrısı **yeni değeri** döner (global hemen güncellenmiş).

UI bileşeninin gerçekten yeniden render edilip edilmediğini test
etmek için `VisualTestContext` gerekir (rehber.md #75) — pencere açar,
render eder, snapshot karşılaştırır.

#### Tema mock'lamayı yanlış yapmak

```rust
// YANLIŞ: cx olmadan tema oluşturmak
let theme = Theme { /* ... */ };
let bg = theme.styles.colors.background;
let button_bg = bg;  // ← bileşen rendering'i ile bağlantısı yok
```

Bu test sadece `Theme` struct'ının kendi alanlarını doğrular — **tüketici
kodun cx.theme() çağrısının doğru çalıştığını test etmez**. UI test'i
istiyorsan `TestAppContext::update` ile global kur.

#### Test ortamı sınır listesi

| Test türü | Strateji | Bileşen |
|-----------|----------|---------|
| Sözleşme doğrulama (parse, refinement) | `#[test]` + fixture | Bölüm VII/Konu 34 |
| Runtime init/registry | `#[gpui::test]` + `init` | Strateji 1 |
| Bileşen tema okuma | `#[gpui::test]` + custom theme | Strateji 2 veya 3 |
| Visual snapshot (render output) | `VisualTestContext` | rehber.md #75 |
| Tema değişim akışı | `#[gpui::test]` + `temayi_degistir` | Konu 31 + bu konu |

#### Tuzaklar

1. **`kvs_tema::init(cx)` çağırmadan `cx.theme()`**: Panic. Her testin
   ilk satırı init veya manuel `set_theme`.
2. **`TestAppContext::run` yerine `update`**: Tema testleri sync; `update`
   doğru. `run` async event loop, gerek yok.
3. **`test_theme()` her testte yeniden kurmak**: `set_global` her seferinde
   üzerine yazar; cumulative bug yok ama performans. Test fixture olarak
   `Arc<Theme>` paylaş.
4. **`feature = "test-util"`'ı production'da açık bırakmak**: `#[cfg(any(test,
   feature = "test-util"))]` koşulu; release build'de kapanmalı. CI'da
   feature flag'lerini kontrol et.
5. **Test tema'sının tüm alanlarını sıfır bırakmak**: `unsafe { zeroed
   () }` ile dolduran test = production'da görünmez UI. Test'te bile
   tüm alanları açık değerle yaz; bug yakalama becerin yüksek olur.
6. **`refresh_windows` test'te etkisiz sanmak**: `TestAppContext`'te
   etkisiz ama global state güncel; test mantığı `cx.theme()` ile yeni
   değeri okur. `VisualTestContext` kullanıyorsan render'ı tetikler.
7. **Mock tema'nın `Theme.id` aynı**: Test'te birden fazla tema kurarsan
   farklı `id`'lerle (`"test-1"`, `"test-2"`); aksi halde `Theme.id`
   üzerinden equality test'i yaparsan yanlış sonuç.

---

## Bölüm IX — Pratik

Son bölüm: önceki sekiz bölümün uygulama kontrol noktalarını topluyor.
Sınama listesi `cargo` ve `git` adımlarıyla derleme/test durumunu
doğrular; yaygın tuzaklar tek satırlık özetlerle ilgili bölümlere
işaret eder; reçeteler günlük operasyonları (sync turu, yeni tema
eklenmesi, hot reload kurulumu, sürüm yükseltme) adım adım kodlar.

> **Kullanım sözleşmesi:** Bu bölüm referans niteliğinde. Önceki
> bölümleri **bilmek koşulu değil**; ama bir reçeteyi izlerken
> referans verilen Konu numarasına dön, "neden böyle" sorusunun
> cevabı orada.

---

### 40. Sınama listesi

Her geliştirme aşaması sonunda (yeni alan, yeni tema, sync turu, sürüm
güncelleme, vs.) bu listeyi gez. **Atlanan madde = ileride bir bug.**

#### Derleme

- [ ] `cargo build -p kvs_tema -p kvs_syntax_tema` — derleme yeşil.
- [ ] `cargo build --workspace` — uygulama tarafında entegrasyon kırık değil.
- [ ] `cargo clippy --all-targets --all-features -- -D warnings` — lint
      uyarılarını hata olarak işle.
- [ ] `cargo doc --no-deps -p kvs_tema` — doc derliyor, sadece dış API
      görünür (Bölüm VIII/Konu 38).
- [ ] `cargo fmt --check` — formatlama tutarlı.

#### Test

- [ ] `cargo test -p kvs_tema` — tüm tema testleri yeşil.
- [ ] `cargo test -p kvs_tema --test parse_fixture` — Zed gerçek temaları
      parse oluyor, panic yok (Bölüm VII/Konu 34).
- [ ] `cargo test -p kvs_tema --test synthetic` — bilinmeyen alan / geçersiz
      hex / bilinmeyen enum variant `None`'a düşüyor (Bölüm IV/Konu 21).
- [ ] `cargo test -p kvs_tema --test refinement` — `apply_status_color_defaults`
      fg→bg %25 alpha türetiyor (Bölüm V/Konu 25).
- [ ] `cargo test -p kvs_tema --features test-util` — `init_test`
      yardımcısı çalışıyor (Bölüm VIII/Konu 39).
- [ ] `cargo test --workspace` — UI tarafında tema entegrasyonu kırık değil.

#### Lisans / dağıtım

- [ ] `cargo license` veya `cargo deny check licenses` — GPL bağımlılık
      yok (Bölüm VII/Konu 35).
- [ ] `kvs_ui/assets/themes/LICENSE_*` — her bundle'lı tema için lisans
      dosyası mevcut.
- [ ] `kvs_ui/assets/themes/README.md` — atıf tablosu güncel.
- [ ] `kvs_tema/tests/fixtures/LICENSE_*` — her fixture için lisans.
- [ ] `kvs_tema/tests/fixtures/README.md` — fixture atıf tablosu güncel.

#### Sözleşme sağlığı

- [ ] `cargo expand -p kvs_tema styles::colors | grep -c "ThemeColorsRefinement"`
      → 1 (Refineable derive üretiyor).
- [ ] `cargo expand -p kvs_tema styles::status | grep -c "StatusColorsRefinement"`
      → 1.
- [ ] `ThemeColors` ve `StatusColors` her alan açıkça doldurulmuş;
      `unsafe { zeroed() }` yok (Bölüm VII/Konu 32).
- [ ] `Theme::from_content` panic etmiyor — bilinmeyen değerler sessizce
      `None`'a düşüyor (Bölüm V/Konu 26).
- [ ] `cx.theme()` `kvs_tema::init` öncesinde panic veriyor (positive
      test).

#### Runtime

- [ ] Örnek GPUI uygulamasında `cx.theme().colors().background` çalışıyor
      (Bölüm VIII/Konu 36).
- [ ] `kvs_tema::temayi_degistir("Kvs Default Light", cx)` sonrası
      `cx.refresh_windows()` çağrılıyor ve UI yeniden çiziyor (Bölüm VI/Konu
      31).
- [ ] Sistem light/dark mod değişimi gözlemleniyor (`observe_window_appearance`).
- [ ] Hot reload (dev'de) tema dosyasını editör'den değiştirince yansıyor
      (Bölüm VII/Konu 33).

#### Sync disiplini

- [ ] `tema_aktarimi.md`'deki pin Zed'in son commit'inden ≤8 hafta yaşlı
      (Bölüm I/Konu 1; aktarımı dosyası "Sync ritmi").
- [ ] `tema_kaymasi_kontrol.sh` çıktısında izlenen yollarda yeni commit
      yok veya gözden geçirildi.
- [ ] `DECISIONS.md` son sync turunda güncellendi.
- [ ] `tema_aktarimi.md` "Senkron turu geçmişi" tablosuna yeni satır
      eklendi.

#### Performans (opsiyonel benchmark)

- [ ] Tek tema yüklemesi (`Theme::from_content`) ~50 µs (Bölüm V/Konu 26).
- [ ] `cx.refresh_windows()` sonrası ilk frame ≤16 ms (60 fps budget).
- [ ] 100 tema yükleme < 10 ms.

---

### 41. Yaygın tuzaklar

Önceki bölümlerde dağınık olan tuzakları **tek yerde** toplar; her
madde bir-iki cümle özet + bölüm referansı. Detay için ilgili konuya
dön.

#### Sözleşme katmanı (Bölüm III, IV)

1. **`#[serde(deny_unknown_fields)]` kullanmak.** Zed yeni alan ekleyince
   parse patlar. **Asla kullanma.** → Konu 21.
2. **JSON'da snake_case beklemek.** Zed `border.variant` yazıyor;
   `#[serde(rename = "border.variant")]` şart, yoksa alan sessizce
   boş kalır. → Konu 22.
3. **`Option<Hsla>` yerine `Option<String>` kullanmak.** Sıkı tipli
   parse hatası tüm temayı bozar; iki katmanlı opsiyonellik (Content
   katmanı string + Refinement katmanı Hsla) sözleşmenin temeli. → Konu 19.
4. **Bir alan grubunu "şimdilik gerek yok" diye atlamak.** `terminal_ansi`,
   debugger, diff hunk, vcs, vim, icon theme — UI'da okumasan bile
   struct'ta bulunmalı. Aksi halde sözleşme delinmesi. → Konu 2 (Temel
   ilke), Konu 13.
5. **`#[refineable(...)]` attribute'u atlamak.** Refinement tipi sadece
   `Default + Clone` türetilir; serde/JSON deserialize'a kapanır. → Konu 11.

#### Refinement (Bölüm V)

6. **Türetme adımını atlayıp `refine`'a doğrudan gitmek.** Status'ta
   kullanıcı `error` yazdı ama `error_background` yok; baseline'dan
   gelen koyu/açık karışım çıkar. `apply_status_color_defaults` şart.
   → Konu 25.
7. **`color()` helper'ında hata mesajı yutmak.** Production debug için
   `inspect_err` ile log ekle; default tut kapalı. → Konu 24.
8. **Baseline'ı yanlış appearance ile seçmek.** Light tema yüklerken
   dark baseline = uyumsuz görüntü. `content.appearance`'a göre seç.
   → Konu 26.

#### Runtime (Bölüm VI)

9. **`cx.refresh_windows()` çağırmamak.** Tema değişti ama UI eski
   renkte kalır — en yaygın tema bug'ı. `set_theme + refresh_windows`
   her zaman çift. → Konu 31.
10. **`cx.notify()` ile yetinmek.** Tek view'ı yeniler; tema tüm
    pencerelerde geçerli. → Konu 31.
11. **`kvs_tema::init`'i atlamak.** `cx.theme()` panic eder. Uygulama
    girişinin **ilk** satırı. → Konu 30.
12. **`update_global` içinde `set_global`.** Re-entrancy panic. Update
    callback içinde sadece field mutate. → Konu 28.
13. **`observe_window_appearance`'da `.detach()` unutmak.** Subscription
    drop olur, observer ölür. → Konu 29.

#### GPUI tipleri (Bölüm II)

14. **Hue 0-360 yazmak.** GPUI hue 0-1 normalize; `hsla(210.0, ...)`
    aslında `hsla(210.0 / 360.0, ...)` olmalı. → Konu 6.
15. **`Hsla::default()` ile struct doldurmak.** `(0,0,0,0)` = görünmez.
    Tüm 150 + 42 alanı açık değerle yaz. → Konu 6, 32.
16. **`opacity` vs `alpha` karıştırmak.** `opacity(x)` `* x` çarpar;
    `alpha(x)` direkt set eder. → Konu 6.
17. **`use kvs_tema::ActiveTheme;` unutmak.** `cx.theme()` "method not
    found". Prelude kullan. → Konu 36.

#### Etkileşim (Bölüm VIII)

18. **`.id()` atlamak.** Interactivity stateful; ID yoksa hover/active
    çalışmaz, sessiz başarısızlık. → Konu 37.
19. **`element_selected` ile `element_selection_background` karıştırmak.**
    İlki liste öğesi seçimi, ikincisi metin highlight. → Konu 37.
20. **Ghost vs element grubunu karıştırmak.** Toolbar'da `element_*`
    kullanırsan yüzey rengiyle dolar = tasarım dili kayar. → Konu 37.

#### Bundling / lisans (Bölüm VII)

21. **`palette` versiyonunu Zed'le aynı tutmamak.** Renk dönüşümü kayar;
    fixture testleri kırılır. → Konu 5, 20.
22. **`refineable` dep'ini fork'lamadan production.** `publish = false`
    crates.io engelliyor; vendor veya fork şart. → Konu 3, 33.
23. **Zed `default_colors.rs` HSL'ini birebir kopyalamak.** GPL-3 ihlali.
    Kendi anchor'larını seç. → Konu 3, 32.
24. **Lisans dosyasını "sonra ekleyeyim" demek.** Bundled tema atıf
    eksik = telif ihlali. CI'da kontrol et. → Konu 35.
25. **GPL lisanslı fixture'ı atlamamak.** Tema JSON'unda HSL bile telif;
    sadece MIT/Apache lisanslı temaları fixture'a koy. → Konu 35.

#### Test (Bölüm VII/VIII)

26. **`#[gpui::test]` `cx.update` içinde init yapmamak.** Test başında
    `kvs_tema::init(cx)` veya `init_test(cx)`. → Konu 39.
27. **Hsla `assert_eq!` ile karşılaştırma.** Float eşitliği tehlikeli;
    epsilon karşılaştırma. → Konu 34.
28. **`feature = "test-util"` production'da açık.** `#[cfg(any(test,
    feature = "test-util"))]` koşulu; release'de kapanmalı. → Konu 39.

#### API yüzeyi (Bölüm VIII)

29. **`refinement.rs` modülünü public yapmak.** `pub use crate::refinement::*`
    sözleşmeyi sızdırır. `pub(crate) mod refinement;` zorunlu. → Konu 38.
30. **`schema::*` glob ile public.** Yeni iç tip otomatik public olur.
    Tek tek `pub use` yaz. → Konu 38.
31. **`Theme.styles` field'ı doğrudan public.** İç düzen sızıntısı;
    accessor metotları (`theme.colors()`) öner. → Konu 12, 36.

---

### 42. Reçeteler

Günlük operasyonların adım adım kodlanmış reçeteleri. Her reçete
**stand-alone**: ön bilgi olarak referans verdiği bölümlere bakarsan
yeterli.

#### Reçete 42.1 — Sync turu (her 6-8 haftada bir)

`tema_aktarimi.md`'deki disipline göre.

```sh
# 1. Drift raporu
cd ~/github/gpui_belge
./tema_kaymasi_kontrol.sh
# → İzlenen yollardaki commit listesini verir
```

```sh
# 2. Her commit'i tek tek incele
git -C ../zed show <sha> -- crates/theme/src/styles/colors.rs
git -C ../zed show <sha> -- crates/settings_content/src/theme.rs
```

```sh
# 3. Yeni alan eklendiyse → mirror struct'lara ekle
$EDITOR ../kvs_ui/crates/kvs_tema/src/styles/colors.rs
$EDITOR ../kvs_ui/crates/kvs_tema/src/schema.rs
$EDITOR ../kvs_ui/crates/kvs_tema/src/refinement.rs
```

```sh
# 4. Fixture'ı güncelle
cp ../zed/assets/themes/one/one.json \
   ../kvs_ui/crates/kvs_tema/tests/fixtures/one-dark.json

# 5. Test çalıştır
cd ../kvs_ui
cargo test -p kvs_tema
```

```sh
# 6. tema_aktarimi.md güncelle
cd ~/github/gpui_belge
$EDITOR tema_aktarimi.md
# - Mevcut durum tablosunda pin SHA + tarih + inceleyen
# - Senkron turu geçmişi tablosuna yeni satır
```

```sh
# 7. Tek commit
cd ../kvs_ui
git add crates/kvs_tema/
git commit -m "tema: Upstream sync to <yeni-kisa-sha>"

cd ../gpui_belge
git add tema_aktarimi.md
git commit -m "tema: Sync günlüğü güncellendi → <yeni-kisa-sha>"
```

> **Referans:** Bölüm I/Konu 1 (yapı), tema_aktarimi.md (disiplin).

#### Reçete 42.2 — Yeni built-in tema ekleme

Zed'den bir tema dosyasını uygulama bundle'ına dahil etmek.

```sh
# 1. Lisans doğrula
cat ../zed/assets/themes/tokyo-night/LICENSE_*
# → LICENSE_MIT veya LICENSE_APACHE olmalı; LICENSE_GPL ise kullanma
```

```sh
# 2. Tema + lisans kopyala
cp ../zed/assets/themes/tokyo-night/tokyo-night.json \
   kvs_ui/assets/themes/
cp ../zed/assets/themes/tokyo-night/LICENSE_MIT \
   kvs_ui/assets/themes/LICENSE_MIT.tokyo-night
```

```sh
# 3. Atıf README'sine ekle
$EDITOR kvs_ui/assets/themes/README.md
# | tokyo-night.json | zed/assets/themes/tokyo-night | MIT | © Tokyo Night |
```

```sh
# 4. Fixture testine ekle (opsiyonel)
cp ../zed/assets/themes/tokyo-night/tokyo-night.json \
   kvs_ui/crates/kvs_tema/tests/fixtures/
$EDITOR kvs_ui/crates/kvs_tema/tests/parse_fixture.rs
# #[test] fn parses_tokyo_night() { ... }
```

```sh
# 5. Test
cargo test -p kvs_tema
```

```sh
# 6. Lisans kontrol script'ini çalıştır
./scripts/check_theme_licenses.sh
```

> **Referans:** Bölüm VII/Konu 33-35.

#### Reçete 42.3 — Hot reload kurulumu (dev modu)

Tema dosyasını editörden değiştirip uygulamayı yeniden başlatmadan
görmek.

```toml
# Cargo.toml
[dependencies]
notify = "6"
```

```rust
// kvs_ui/src/dev/hot_reload.rs
#[cfg(debug_assertions)]
pub fn init_hot_reload(themes_dir: PathBuf, cx: &mut App) -> anyhow::Result<()> {
    use notify::{RecommendedWatcher, RecursiveMode, Watcher};

    let (tx, rx) = std::sync::mpsc::channel();
    let mut watcher: RecommendedWatcher = notify::recommended_watcher(tx)?;
    watcher.watch(&themes_dir, RecursiveMode::NonRecursive)?;

    // Watcher'ı drop'tan koru
    cx.set_global(WatcherHolder(Box::new(watcher)));

    cx.spawn(async move |cx| {
        while let Ok(Ok(event)) = rx.recv() {
            if !event.kind.is_modify() { continue; }
            for path in event.paths {
                if path.extension().is_some_and(|e| e == "json") {
                    cx.update(|cx| {
                        let _ = kvs_tema::temayi_yeniden_yukle(&path, cx);
                    }).ok();
                }
            }
        }
    }).detach();

    Ok(())
}

struct WatcherHolder(Box<dyn std::any::Any>);
impl gpui::Global for WatcherHolder {}
```

```rust
// kvs_ui/src/main.rs
fn main() {
    Application::new().run(|cx| {
        kvs_tema::init(cx);

        #[cfg(debug_assertions)]
        {
            let themes_dir = std::env::current_dir().unwrap().join("assets/themes");
            let _ = dev::hot_reload::init_hot_reload(themes_dir, cx);
        }

        // ... pencere aç
    });
}
```

> **Referans:** Bölüm VII/Konu 33.

#### Reçete 42.4 — Custom palette ile fallback yeniden tasarım

Yeni bir tasarım dili getirdin; `kvs_default_dark` ve `kvs_default_light`
güncellenecek.

```rust
// kvs_tema/src/fallback.rs (revize)
pub fn kvs_default_dark() -> Theme {
    // ANCHOR — tasarım dilinin tek hue başlangıcı
    let anchor_hue = 240.0;     // mor-mavi (önceki 220'den değişti)

    // Türetilen anchor renkler
    let bg          = hsla(anchor_hue / 360.0, 0.10, 0.10, 1.0);
    let surface     = hsla(anchor_hue / 360.0, 0.10, 0.13, 1.0);
    let elevated    = hsla(anchor_hue / 360.0, 0.10, 0.16, 1.0);
    let text        = hsla(anchor_hue / 360.0, 0.05, 0.94, 1.0);
    let text_muted  = hsla(anchor_hue / 360.0, 0.05, 0.60, 1.0);
    let border      = hsla(anchor_hue / 360.0, 0.10, 0.23, 1.0);

    // Aksent — kasıtlı olarak farklı hue
    let accent      = hsla(190.0 / 360.0, 0.80, 0.55, 1.0);  // cyan

    Theme {
        id: "kvs-default-dark".into(),
        name: "Kvs Default Dark".into(),
        appearance: Appearance::Dark,
        styles: ThemeStyles {
            window_background_appearance: WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors {
                background: bg,
                // ... opacity zinciri ile tüm 150 alan
            },
            status: status_colors_dark(),
            player: PlayerColors(vec![PlayerColor {
                cursor: accent,
                background: accent.opacity(0.2),
                selection: accent.opacity(0.3),
            }]),
            accents: AccentColors(vec![
                accent,
                hsla(330.0 / 360.0, 0.7, 0.6, 1.0),  // magenta
                hsla(60.0 / 360.0, 0.7, 0.6, 1.0),   // sarı
            ]),
            syntax: SyntaxTheme::new(vec![]),
        },
    }
}
```

```sh
# Doğrulama
cargo test -p kvs_tema fallback_temalari_tam_dolu
```

```sh
# DECISIONS.md'ye not düş
$EDITOR kvs_ui/crates/kvs_tema/DECISIONS.md
# ## YYYY-MM-DD — Palet yenilemesi
# - Anchor hue 220 → 240 (mor-mavi)
# - Accent: yeni cyan (#33b5d6)
# - Esinlenme: <kaynak palet/marka rehberi>
```

> **Referans:** Bölüm VII/Konu 32.

#### Reçete 42.5 — Tema farkı debug

Kullanıcı "tema X yüklenirse renk garip görünüyor" diyor. Neyin baseline'dan,
neyin tema'dan geldiğini ayırt et.

```rust
// kvs_tema/src/debug.rs (dev only)
#[cfg(feature = "debug-tools")]
pub fn diff_theme_against_baseline(
    theme: &Theme,
    baseline: &Theme,
) -> Vec<(String, gpui::Hsla, gpui::Hsla)> {
    let mut diffs = Vec::new();

    macro_rules! check {
        ($field:ident) => {
            if theme.styles.colors.$field != baseline.styles.colors.$field {
                diffs.push((
                    stringify!($field).to_string(),
                    baseline.styles.colors.$field,
                    theme.styles.colors.$field,
                ));
            }
        };
    }

    check!(background);
    check!(border);
    check!(text);
    // ... her alan
    diffs
}
```

```rust
#[gpui::test]
fn debug_zed_one_dark(cx: &mut TestAppContext) {
    cx.update(|cx| {
        let json = include_str!("fixtures/one-dark.json");
        let family: ThemeFamilyContent =
            serde_json_lenient::from_str(json).unwrap();
        let baseline = kvs_tema::fallback::kvs_default_dark();
        let theme = Theme::from_content(
            family.themes.into_iter().next().unwrap(),
            &baseline,
        );

        let diffs = diff_theme_against_baseline(&theme, &baseline);
        for (alan, base, kullanici) in &diffs {
            println!("{}: baseline={:?} → kullanıcı={:?}", alan, base, kullanici);
        }
        println!("Toplam {} alan değişti", diffs.len());
    });
}
```

Çıktı:

```
background: baseline=Hsla{...} → kullanıcı=Hsla{...}
border: baseline=Hsla{...} → kullanıcı=Hsla{...}
text_muted: baseline=Hsla{...} → kullanıcı=Hsla{...}
...
Toplam 87 alan değişti
```

> **Referans:** Bölüm V/Konu 26 (`Theme::from_content` davranışı).

#### Reçete 42.6 — Yeni alan ekleme (sync turunda)

Sync raporu Zed'in `inlay_hint_background` alanı eklediğini gösterdi.

```rust
// 1. ThemeColors'a alan ekle
// kvs_tema/src/styles/colors.rs
pub struct ThemeColors {
    // ... mevcut alanlar
    pub inlay_hint_background: Hsla,    // ← yeni
    pub inlay_hint_foreground: Hsla,    // ← yeni
}
```

```rust
// 2. ThemeColorsContent'e mirror alan ekle
// kvs_tema/src/schema.rs
pub struct ThemeColorsContent {
    // ... mevcut
    #[serde(rename = "inlay_hint.background")]
    pub inlay_hint_background: Option<String>,
    #[serde(rename = "inlay_hint.foreground")]
    pub inlay_hint_foreground: Option<String>,
}
```

```rust
// 3. theme_colors_refinement'a ekle
// kvs_tema/src/refinement.rs
pub fn theme_colors_refinement(c: &ThemeColorsContent) -> ThemeColorsRefinement {
    ThemeColorsRefinement {
        // ... mevcut
        inlay_hint_background: color(&c.inlay_hint_background),
        inlay_hint_foreground: color(&c.inlay_hint_foreground),
        ..Default::default()
    }
}
```

```rust
// 4. fallback'lere makul default değerler
// kvs_tema/src/fallback.rs
pub fn kvs_default_dark() -> Theme {
    // ...
    Theme {
        styles: ThemeStyles {
            colors: ThemeColors {
                // ...
                inlay_hint_background: text_muted.opacity(0.15),  // hafif
                inlay_hint_foreground: text_muted,
            },
            // ...
        },
    }
}
```

```sh
# 5. Test
cargo test -p kvs_tema

# 6. Fixture'da görünüyor mu kontrol et
grep -i "inlay_hint" kvs_tema/tests/fixtures/one-dark.json
# Eğer JSON'da varsa parse oluyor demektir
```

```rust
// 7. Bölüm 13 tablosuna ekle (rehber.md)
// Konu 13'teki ThemeColors grup tablosuna "Inlay hint" satırı
```

> **Referans:** Bölüm II/Konu 11, Bölüm III/Konu 13, Bölüm IV/Konu 22, Bölüm V/Konu 24.

#### Reçete 42.7 — Bileşen tema entegrasyon kontrol listesi

Yeni bir UI bileşeni yazdın (örn. `ListItem`); tema entegrasyonu doğru mu?

```rust
use kvs_tema::prelude::*;   // ✓ Import tek satırda

struct ListItem {
    label: SharedString,
    is_selected: bool,       // ✓ State'te tema rengi YOK
    is_disabled: bool,
}

impl Render for ListItem {
    fn render(
        &mut self,
        _w: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let colors = cx.theme().colors();   // ✓ Tek bağlama

        let bg = if self.is_selected {
            colors.element_selected           // ✓ Selected için ayrı alan
        } else {
            colors.ghost_element_background   // ✓ Liste = ghost
        };

        let text = if self.is_disabled {
            colors.text_disabled              // ✓ Disabled için ayrı alan
        } else {
            colors.text
        };

        div()
            .id(SharedString::from(format!("item-{}", self.label)))  // ✓ ID şart
            .px_3().py_1()
            .bg(bg)
            .text_color(text)
            .when(!self.is_disabled, |this| {                         // ✓ Disabled'da etkileşim kapalı
                this.hover(|s| s.bg(colors.ghost_element_hover))
                    .on_click(/* ... */)
            })
            .child(self.label.clone())
    }
}
```

Checklist:

- [ ] `use kvs_tema::prelude::*` mevcut
- [ ] State'te tema rengi (Hsla) tutulmuyor
- [ ] `cx.theme()` render başında tek seferlik bağlanıyor
- [ ] `selected` durumu için `element_selected` (veya `ghost_element_selected`)
- [ ] `disabled` durumu için `text_disabled` + etkileşim kapalı
- [ ] Hover/active için doğru aile (ghost vs element)
- [ ] `.id()` çağrısı interactive bileşende
- [ ] Tema değişimi snapshot testi var

> **Referans:** Bölüm VIII/Konu 36-37.

#### Reçete 42.8 — Sürüm yükseltme (`kvs_tema` 0.1 → 0.2)

Breaking change yapacaksın; sürüm bump + migration notu.

```toml
# kvs_tema/Cargo.toml
[package]
version = "0.2.0"   # 0.1.x → 0.2.0
```

```markdown
# kvs_tema/CHANGELOG.md (yeni dosya)
# Changelog

## [0.2.0] — YYYY-MM-DD

### Breaking
- `Theme.styles` alanı `pub(crate)`'a indirildi. Tüketici artık
  `theme.colors()`, `theme.status()` accessor'larını kullanmalı.
- `schema::ThemeColorsContent::inlay_hint_background` alanı eklendi
  (Zed sync).

### Added
- `Theme::colors()`, `Theme::status()`, `Theme::players()` accessor metotları.
- Inlay hint için fallback default değerler.

### Fixed
- `apply_status_color_defaults` artık `predictive` status'ünü de
  türetiyor.

## [0.1.0] — YYYY-MM-DD
- İlk yayın.
```

```rust
// MIGRATION.md (yeni)
// # 0.1 → 0.2 migrasyon

// ## `theme.styles` doğrudan erişim
// ÖNCE:
let bg = theme.styles.colors.background;

// SONRA:
let bg = theme.colors().background;

// ## `schema` yeni alanlar
// JSON'da `"inlay_hint.background"` artık tanınıyor; eski JSON dosyaları
// etkilenmez (sözleşme geriye uyumlu).
```

```sh
# Tüm tüketici kodu güncelle
rg -l "theme\.styles\." kvs_ui/ | xargs sed -i 's/theme\.styles\.colors\./theme.colors()./g'

# Test
cargo test --workspace
```

```sh
# Yayın
git tag v0.2.0
git push --tags
cargo publish -p kvs_syntax_tema
cargo publish -p kvs_tema   # sırası önemli, syntax önce
```

> **Referans:** Bölüm VIII/Konu 38 (semver).

#### Reçete 42.9 — Test ortamında özel tema kurma

Bir UI testinde bilinen renklere ihtiyacın var.

```rust
// kvs_ui/tests/button_test.rs
use gpui::TestAppContext;
use kvs_tema::*;
use std::sync::Arc;

fn install_test_theme(cx: &mut gpui::App) -> Arc<Theme> {
    let theme = Theme {
        id: "test".into(),
        name: "Test".into(),
        appearance: Appearance::Dark,
        styles: ThemeStyles {
            window_background_appearance: gpui::WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors {
                background: gpui::hsla(0.0, 1.0, 0.5, 1.0),     // kırmızı
                element_background: gpui::hsla(0.333, 1.0, 0.5, 1.0),  // yeşil
                element_hover: gpui::hsla(0.666, 1.0, 0.5, 1.0),       // mavi
                text: gpui::hsla(0.0, 0.0, 1.0, 1.0),                  // beyaz
                // ... tüm alanları açık değerle doldur (fallback helper'dan ödünç)
                ..extract_baseline_colors()
            },
            status: extract_baseline_status(),
            player: PlayerColors::default(),
            accents: AccentColors::default(),
            syntax: kvs_syntax_tema::SyntaxTheme::new(vec![]),
        },
    };

    let registry = Arc::new(ThemeRegistry::new());
    let arc_theme = Arc::new(theme);
    registry.insert((*arc_theme).clone());
    ThemeRegistry::set_global(cx, registry);
    GlobalTheme::set_theme(cx, arc_theme.clone());

    arc_theme
}

#[gpui::test]
fn button_uses_element_background(cx: &mut TestAppContext) {
    cx.update(|cx| {
        let theme = install_test_theme(cx);
        let green = gpui::hsla(0.333, 1.0, 0.5, 1.0);

        let button = cx.new(|_| Button::new("OK".into()));

        // Render output'unu inspect et (gpui test API)
        // ...
        assert_eq!(theme.styles.colors.element_background, green);
    });
}
```

> **Referans:** Bölüm VIII/Konu 39.

#### Reçete 42.10 — Kullanıcı tema dizini ekleme

`~/.config/kvs/themes/` altındaki tüm JSON'ları yükle (init sonrası).

```rust
// kvs_ui/src/themes.rs
use std::path::PathBuf;

pub fn user_theme_dir() -> Option<PathBuf> {
    dirs::config_dir()
        .map(|d| d.join("kvs").join("themes"))
}

pub async fn load_user_themes(cx: &mut gpui::AsyncApp) -> anyhow::Result<()> {
    let Some(dir) = user_theme_dir() else { return Ok(()); };
    if !dir.exists() { return Ok(()); }

    let mut entries = tokio::fs::read_dir(&dir).await?;
    while let Some(entry) = entries.next_entry().await? {
        let path = entry.path();
        if !path.extension().is_some_and(|e| e == "json") { continue; }

        let bytes = tokio::fs::read(&path).await?;
        let family: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&bytes)?;

        cx.update(|cx| {
            let registry = kvs_tema::ThemeRegistry::global(cx);
            let baseline_dark = kvs_tema::fallback::kvs_default_dark();
            let baseline_light = kvs_tema::fallback::kvs_default_light();

            for theme_content in family.themes {
                let baseline = match theme_content.appearance {
                    kvs_tema::AppearanceContent::Dark => &baseline_dark,
                    kvs_tema::AppearanceContent::Light => &baseline_light,
                };
                registry.insert(kvs_tema::Theme::from_content(
                    theme_content,
                    baseline,
                ));
            }
        })?;
    }
    Ok(())
}

// main.rs
fn main() {
    Application::new().run(|cx| {
        kvs_tema::init(cx);

        cx.spawn(async move |cx| {
            if let Err(e) = themes::load_user_themes(&mut cx).await {
                tracing::warn!("kullanıcı temaları yüklenemedi: {}", e);
            }
        }).detach();

        // ... pencere
    });
}
```

> **Referans:** Bölüm VI/Konu 30 (init genişletme), Bölüm VII/Konu 33.

---

# Son

Bu rehber `kvs_tema` ve `kvs_syntax_tema` crate'lerinin **tüm yüzeyini**
9 bölüm ve 42 konuda toplar. Üç temel kural:

1. **Veri sözleşmesinde dışlama yok** — Zed'in tüm alanları mirror edilir
   (Konu 2).
2. **Lisans-temiz çalışma** — kod gövdesi GPL'den kopyalanmaz, sadece
   sözleşme paritesi (Konu 3).
3. **Sync disiplini** — `tema_aktarimi.md` 6-8 haftada bir güncellenir,
   `DECISIONS.md` her kararla beraber yazılır.

Beklenmedik bir durum yaşarsan ilgili Konu'ya git; yoksa Bölüm IX'daki
tuzaklar listesi başlangıç noktasıdır.

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
