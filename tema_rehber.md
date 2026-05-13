# Zed Uyumlu Tema Yönetim Sistemi — Geliştirici Rehberi

Bu rehber, **GPUI tabanlı kendi uygulaman için Zed-tarzı bir tema yönetim
sistemini sıfırdan kurmana** yardım eder. Hedef: Zed'in `crates/theme` crate'ini
**doğrudan kullanmadan** (GPL-3 lisans nedeniyle), aynı kullanıcı deneyimini
veren, **Zed JSON tema dosyalarını birebir parse edebilen**, lisans açısından
temiz bir tema sistemi inşa etmek.

> **Eşlik eden dosyalar:** `tema_aktarimi.md` (upstream pin/sync günlüğü)
> ve `tema_kaymasi_kontrol.sh` (Zed diff üretici). Bu rehber **mimari,
> sözleşme ve kod** tarafına odaklanır; uzun vadeli senkron disiplini için onlara
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
6. [Renk tipleri: `Hsla`, `Rgba` ve constructor'lar](#6-renk-tipleri-hsla-rgba-ve-constructorlar)
7. [Metin/font tipleri: `SharedString`, `HighlightStyle`, `FontStyle`, `FontWeight`](#7-metinfont-tipleri-sharedstring-highlightstyle-fontstyle-fontweight)
8. [Pencere: `WindowBackgroundAppearance`, `WindowAppearance`](#8-pencere-windowbackgroundappearance-windowappearance)
9. [Bağlam tipleri: `App`, `Context<T>`, `Window`, `BorrowAppContext`](#9-bağlam-tipleri-app-contextt-window-borrowappcontext)
10. [`Global` trait ve `cx.set_global / update_global / refresh_windows`](#10-global-trait-ve-cxset_global--update_global--refresh_windows)
11. [`refineable::Refineable` derive davranışı](#11-refineablerefineable-derive-davranışı)

### Bölüm III — Veri sözleşmesi tipleri
12. [`Theme` ve `ThemeStyles` üst yapısı](#12-theme-ve-themestyles-üst-yapısı)
13. [`ThemeColors` alan kataloğu](#13-themecolors-alan-kataloğu)
14. [`StatusColors`: fg/bg/border üçlüsü deseni](#14-statuscolors-fgbgborder-üçlüsü-deseni)
15. [`PlayerColors`, `PlayerColor`, slot semantiği](#15-playercolors-playercolor-slot-semantiği)
16. [`AccentColors`, `SystemColors`, `Appearance`](#16-accentcolors-systemcolors-appearance)
17. [`ThemeFamily`, `SyntaxTheme`, `IconTheme`](#17-themefamily-syntaxtheme-icontheme)

### Bölüm IV — JSON şeması katmanı
18. [`ThemeContent` ve serde flatten/rename desenleri](#18-themecontent-ve-serde-flattenrename-desenleri)
19. [`*Content` tiplerinin opsiyonellik felsefesi](#19-content-tiplerinin-opsiyonellik-felsefesi)
20. [`try_parse_color`: hex → `Hsla` boru hattı](#20-try_parse_color-hex--hsla-boru-hattı)
21. [Hata tolerans: `treat_error_as_none`, `deny_unknown_fields` tuzağı](#21-hata-tolerans-treat_error_as_none-deny_unknown_fields-tuzağı)
22. [JSON anahtar konvansiyonu (dot vs snake_case)](#22-json-anahtar-konvansiyonu-dot-vs-snake_case)

### Bölüm V — Refinement katmanı
23. [Content → Refinement → Theme akışı](#23-content--refinement--theme-akışı)
24. [`theme_colors_refinement`, `status_colors_refinement` deseni](#24-theme_colors_refinement-status_colors_refinement-deseni)
25. [`apply_status_color_defaults`: %25 alpha türetme kuralı](#25-apply_status_color_defaults-25-alpha-türetme-kuralı)
26. [`Theme::from_content` birleşik akış](#26-themefrom_content-birleşik-akış)

### Bölüm VI — Runtime katmanı
27. [`ThemeRegistry`: API yüzeyi ve thread safety](#27-themeregistry-api-yüzeyi-ve-thread-safety)
28. [`GlobalTheme` ve `ActiveTheme` trait](#28-globaltheme-ve-activetheme-trait)
29. [`SystemAppearance` ve sistem mod takibi](#29-systemappearance-ve-sistem-mod-takibi)
30. [`init()`: kuruluş sırası ve fallback yükleme](#30-init-kuruluş-sırası-ve-fallback-yükleme)
31. [Tema değiştirme ve `cx.refresh_windows()`](#31-tema-değiştirme-ve-cxrefresh_windows)

### Bölüm VII — Varlık ve test
32. [Fallback tema tasarımı](#32-fallback-tema-tasarımı)
33. [Built-in tema bundling ve `AssetSource`](#33-built-in-tema-bundling-ve-assetsource)
34. [Fixture testleri ve JSON sözleşme doğrulama](#34-fixture-testleri-ve-json-sözleşme-doğrulama)
35. [Lisans doğrulama akışı](#35-lisans-doğrulama-akışı)

### Bölüm VIII — Tüketim ve dış API
36. [`cx.theme()` ile bileşen renklendirme](#36-cxtheme-ile-bileşen-renklendirme)
37. [Hover / active / disabled / selected / ghost desenleri](#37-hover--active--disabled--selected--ghost-desenleri)
38. [Public API kataloğu ve crate-içi sınır](#38-public-api-kataloğu-ve-crate-içi-sınır)
39. [Test ortamında tema mock'lama](#39-test-ortamında-tema-mocklama)

### Bölüm IX — Pratik
40. [Sınama listesi](#40-sınama-listesi)
41. [Yaygın tuzaklar](#41-yaygın-tuzaklar)
42. [Reçeteler](#42-reçeteler)
43. [İleri öğeler: `ColorScale`, `UiDensity`, `LoadThemes`, `ThemeSettingsProvider`, reflection](#43-İleri-öğeler-colorscale-uidensity-loadthemes-themesettingsprovider-reflection)

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
│  - SystemAppearance - update_theme   - cx.theme()               │
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
temayı sorgulama, `GlobalTheme::update_theme` ile değiştirme, sistem light/dark modunu
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
│   ├── zed_commit_pin.txt
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

## 2026-05-12 — İlk pin

- Pin: 6e8eaab25b5a (bkz. ../../gpui_belge/zed_commit_pin.txt)
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

"Dış API" sütununda "kararsız" işareti olan modül (`schema.rs`) tip
yüzeyi sync turlarında değişebilir; tüketici bu modüle doğrudan dayanırsa
breaking change yaşar.

---

### 5. Bağımlılık matrisi

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

Alt crate'ler `gpui = { workspace = true }` ile inherit eder; pin
güncellemesi tek noktadan yapılır.

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
# Headless GPUI test ortamı (TestAppContext, #[gpui::test])
gpui = { workspace = true, features = ["test-support"] }
# Refinement birim testleri için epsilon karşılaştırma yardımcısı (opsiyonel)
approx = "0.5"

[features]
# Tüketici crate'ler için test helper'larını açar (Bölüm VIII/Konu 39).
# Release build'lerde açma; CI'da sadece test job'unda etkinleştir.
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
| `thiserror` | Hata türetme | `#[derive(Error)] ThemeNotFoundError` |
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
  ediliyor; bunu **pin commit'e** (`zed_commit_pin.txt` dosyasındaki SHA'ya)
  sabitlemek istersen `rev = "6e8eaab25b5a..."` kullan. Sync turunda bu
  SHA güncellenir:

  ```toml
  gpui = { git = "https://github.com/zed-industries/zed", rev = "6e8eaab25b5ac324e11a82d1563dcad39c84bace" }
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

gpui, refineable, collections  ──sourced from──>  zed workspace (Apache-2.0)
```

Bu grafiğin yönü tersine işlemez; `gpui` asla `kvs_tema`'ya bağlanmaz.
Bu kural, Zed'in upstream'inde değişiklik olduğunda senin tema crate'inin
etkilenmesini sınırlar — değişiklik sadece üç vektörden gelir: **tip
imzası**, **davranış**, **isim/yol değişimi**.

**Lib kökü iskeleti (`src/kvs_tema.rs`):**

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

pub(crate) mod refinement;   // crate-içi — Bölüm VIII/Konu 38
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

// Accessor metotları — public okuma yolu (Konu 12, 36, 38)
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

pub struct ThemeNotFoundError(pub SharedString);
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

→ Üretilen `HighlightStyle`'lar `Vec<(String, HighlightStyle)>` tuple
listesi olarak `SyntaxTheme::new(...)` constructor'ına geçirilir;
constructor stilleri internal `Vec<HighlightStyle>`'a, capture adlarını
`BTreeMap<String, usize>`'a ayrıştırır.

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
5. **`HighlightStyle::default()` nötr ama sentaks katmanında **görünmez**:**
   Tüm alanlar `None` (color dahil); SyntaxTheme'da bir kategori için
   `Default::default()` koymak token'ı şeffaf bırakır. `Hsla::default()`
   görünmezliğin renk tarafı; `HighlightStyle::default()` ise stil
   tarafının görünmezliğidir. Fallback syntax kurarken (Konu 32) her
   kategoriye en az `color: Some(...)` ver.

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
// kvs_tema/src/kvs_tema.rs
pub(crate) struct ThemeStyles {
    pub(crate) window_background_appearance: WindowBackgroundAppearance,
    // ...
}
// Theme accessor (Konu 12)
impl Theme {
    pub fn window_background_appearance(&self) -> WindowBackgroundAppearance {
        self.styles.window_background_appearance
    }
}
```

JSON Content tarafında `WindowBackgroundContent` (`Opaque`/`Transparent`/
`Blurred`) karşılığı ile map'lenir.

**Pencere açılırken aktarma:**

```rust
WindowOptions {
    window_background: cx.theme().window_background_appearance(),
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
`GlobalTheme::update_theme(cx, theme)` çağrısı hem `App`'ten hem
`Context<T>`'den hem async context'ten geçerlidir.

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
pub fn install_or_update_theme(cx: &mut App, theme: Arc<Theme>) {
    if cx.has_global::<GlobalTheme>() {
        GlobalTheme::update_theme(cx, theme);
    } else {
        // İlk kez kuruyoruz; icon teması da elimizde olmalı.
        let icon_theme = kvs_tema::ThemeRegistry::global(cx)
            .default_icon_theme()
            .expect("default icon tema kayıtlı olmalı");
        cx.set_global(GlobalTheme::new(theme, icon_theme));
    }
}
```

→ İlk çağrıda `set_global`, sonraki çağrılarda `update_global`. Bu desen
tema sistemi sınırları dışında da global state için idiomatik.

> **İsim çakışmasından kaçın:** `theme_settings::settings` modülünde
> `pub fn set_theme(current: &mut SettingsContent, …)` adında **ayrı bir
> public yardımcı** vardır (Konu 31). O fonksiyon kullanıcı ayar dosyasını
> mutate eder, runtime global'i değil; ikisini aynı ada bağlamak okuyucuyu
> yanıltır. Mirror tarafta runtime tarafının adı `update_theme` (Zed paritesi)
> veya `install_or_update_theme` gibi farklı bir kimlikte tutulmalıdır.

#### Tema sisteminin üç global'i

| Global | İçerik | Kim kurar | Kim okur |
|--------|--------|-----------|----------|
| `GlobalThemeRegistry` | `Arc<ThemeRegistry>` | `cx.set_global(GlobalThemeRegistry(...))` (Zed'de `pub(crate) ThemeRegistry::set_global` wrapper'ı bunu yapar) | `ThemeRegistry::global(cx)` |
| `GlobalTheme` | `Arc<Theme>` + `Arc<IconTheme>` (aktif) | `cx.set_global(GlobalTheme::new(...))`, sonra `update_theme` / `update_icon_theme` | `cx.theme()`, `GlobalTheme::icon_theme(cx)` |
| `GlobalSystemAppearance` | `SystemAppearance` | `SystemAppearance::init` | `SystemAppearance::global(cx)` |
| `BufferFontSize`, `UiFontSize`, `AgentUiFontSize`, `AgentBufferFontSize` | `Pixels` (override) | `adjust_*_font_size` çağrıları | `ThemeSettings::*_font_size(cx)` (override yoksa settings değerine düşer) |

#### `cx.refresh_windows()`

Tüm açık pencereleri **yeniden render** eder:

```rust
pub fn temayi_degistir(ad: &str, cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;
    GlobalTheme::update_theme(cx, yeni);
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
   eski renkte. `GlobalTheme::update_theme` (veya yerel sarmalayıcısı) her
   zaman `refresh_windows` ile eşleşmeli; helper fonksiyona sar.
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

- **Nested davranış explicit**: Macro normal alanları `Option<T>` yapıp
  değer geldiyse alanı değiştirir. Sadece alan üzerinde `#[refineable]`
  varsa nested refinement tipi kullanılır ve `self.field.refine(...)`
  çağrılır. `Theme.styles` gibi üst katmanlarda bunu istemiyorsan alanı
  işaretleme; manuel orchestration `Theme::from_content` içinde kalır.
- **`Some(v)` override, `None` koruma**: JSON deserializasyonu sırasında
  verilmeyen alan `None` olarak gelir; baseline korunur.
- **Override `clone()` tabanlıdır**: Macro normal alanlarda `value.clone()`
  üretir. `Hsla` gibi `Copy` tiplerde bu ucuz no-op davranışlıdır; non-Copy
  alanlarda gerçek clone çalışır. Refineable türettiğin struct'taki her
  wrapped alan `Clone` olmalı; aksi halde derive hata verir ("the trait
  `Clone` is not implemented for ...").
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
4. **Nested struct'lar için karar noktası**: Macro sadece `#[refineable]`
   işaretli alanlarda recursive birleştirir. `Theme.styles.colors` gibi
   katmanlarda bu ilişkiyi bilinçli kurmak istemiyorsan
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
    pub(crate) styles: ThemeStyles,   // accessor'lar üzerinden okunur
}

pub(crate) struct ThemeStyles {
    pub(crate) window_background_appearance: WindowBackgroundAppearance,
    pub(crate) system: SystemColors,
    pub(crate) colors: ThemeColors,
    pub(crate) status: StatusColors,
    pub(crate) player: PlayerColors,
    pub(crate) accents: AccentColors,
    pub(crate) syntax: Arc<kvs_syntax_tema::SyntaxTheme>,
}

// Tüketicinin tek okuma yolu — accessor metotları (Konu 36, 38)
impl Theme {
    pub fn colors(&self) -> &ThemeColors      { &self.styles.colors }
    pub fn status(&self) -> &StatusColors     { &self.styles.status }
    pub fn players(&self) -> &PlayerColors    { &self.styles.player }
    pub fn accents(&self) -> &AccentColors    { &self.styles.accents }
    pub fn system(&self) -> &SystemColors     { &self.styles.system }
    pub fn syntax(&self) -> &Arc<kvs_syntax_tema::SyntaxTheme> {
        &self.styles.syntax
    }
    pub fn appearance(&self) -> Appearance {
        self.appearance
    }
    pub fn window_background_appearance(&self) -> WindowBackgroundAppearance {
        self.styles.window_background_appearance
    }

    /// Lightness'i azaltarak renk koyulaştırır. İlk değer light tema,
    /// ikincisi dark tema modunda kullanılır; lightness alt sınırı 0.0.
    /// Zed paritesi (`crates/theme/src/theme.rs:288`).
    pub fn darken(&self, color: Hsla, light_amount: f32, dark_amount: f32) -> Hsla {
        let amount = match self.appearance {
            Appearance::Light => light_amount,
            Appearance::Dark => dark_amount,
        };
        let mut hsla = color;
        hsla.l = (hsla.l - amount).max(0.0);
        hsla
    }
}
```

> **Visibility kararı:** `styles` alanı `pub(crate)` — tüketici crate
> doğrudan `theme.styles.X` zinciri **yazamaz**; her okuma accessor
> üzerinden geçer. Gerekçesi: `ThemeStyles`'ın iç düzeni (alan adları,
> sıralama, alt-struct ayrımı) sync turlarında değişebilir; accessor
> arayüzü sözleşmeyi `theme.colors()` üzerinde **sabitler** ve iç düzen
> değişimi tüketici kodu kırmaz. Konu 38 bu kararı `pub` API kataloğu
> ile zorunlu kılar.

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
let theme = cx.theme();                       // &Arc<Theme>
let bg = theme.colors().background;           // accessor üzerinden
let muted = theme.colors().text_muted;
let error = theme.status().error;
let local = theme.players().local().cursor;
```

> **Zed eşdeğeri:** Zed'in `crates/theme/src/theme.rs` dosyasında da
> `theme.colors()`, `theme.status()` accessor'ları var. `kvs_tema`'da
> da aynı sözleşmeyi koruyoruz; accessor'lar yukarıdaki struct
> tanımının `impl Theme` bloğunda tanımlı (yukarı bak).
>
> Tüketici kod **hiçbir zaman** `theme.styles.X` yazmaz — `styles` alanı
> `pub(crate)`, crate dışından görünmez (Konu 38).

#### `Theme` clone stratejisi

`Theme` tek seferde `~150 × Hsla (16 byte) + birkaç enum + Arc + String`
≈ **2.5-3 KiB**. Her `cx.theme()` çağrısı `&Arc<Theme>` döner; clone
ücretsiz. Asla `Theme::clone()` yazmaktan kaçın — `GlobalTheme.theme`
zaten `Arc<Theme>` tutuyor.

#### Tuzaklar

1. **`id` yerine `name` map key**: `name` `SharedString` ve registry key
   olarak kullanılır. `id` (uuid) sadece tema-içi tanım için; karıştırma.
2. **`styles` alanını `pub` yapmak**: Sözleşme delinmesi — bu rehberin
   kararı `pub(crate)`. Tüketicinin tek okuma yolu accessor metotları
   (`theme.colors()`, `theme.status()`, vs.). İç düzen sync turunda
   değişebilir; accessor arayüzü `theme.colors()` üzerinde sabit kalır.
3. **`appearance` runtime'da değişmez**: Bir tema *Light* olarak yüklendi
   diye runtime'da Dark olarak yeniden işlenmez. Tema değiştirmek için
   `GlobalTheme::update_theme` ile yeni `Arc<Theme>` aktive et.
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
| **Editor** | `editor_*` (background, foreground, line_number, active_line_background, wrap_guide, document_highlight_*) | Kod editör katmanı | 18 |
| **Editor diff hunk** | `editor_diff_hunk_*` | Diff hunk background/border görünümü | 6 |
| **Terminal** | `terminal_background`, `terminal_foreground`, `terminal_ansi_*`, `terminal_ansi_dim_*` | Terminal foreground/background ve ANSI normal/bright/dim renkleri | 29 |
| **Panel** | `panel_background`, `panel_focused_border`, `panel_indent_guide_*` | Sidebar/panel kromu | ~5 |
| **Status bar** | `status_bar_background` | Alt durum çubuğu | 1-2 |
| **Title bar** | `title_bar_background`, `title_bar_inactive_background`, `title_bar_border` | Pencere başlığı | ~3 |
| **Tab** | `tab_bar_background`, `tab_active_background`, `tab_inactive_background` | Editor tab şeridi | ~5 |
| **Search** | `search_match_background` | Arama vurgusu | ~2 |
| **Scrollbar** | `scrollbar_thumb_*`, `scrollbar_track_*` | Kaydırma çubuğu | 6 |
| **Minimap** | `minimap_thumb_*` | Minimap kaydırma thumb'u | 4 |
| **Debugger** | `debugger_accent`, `editor_debugger_active_line_background` | Debug oturumu | 2 |
| **VCS** | `version_control_added`, `_modified`, `_deleted`, `_word_*`, `_conflict_marker_*` | Git/VCS göstergeleri | 10 |
| **Vim** | `vim_normal_*`, `vim_visual_*`, `vim_helix_*`, `vim_yank_background` | Vim/Helix modu vurgusu | 18 |
| **Pane group** | `pane_group_border`, `pane_focused_border` | Editor pane sınırları | ~2 |

> **Bu tablo "yaklaşık" sayılarla çalışır** çünkü Zed her sync turunda
> alan ekler/kaldırır. Tam liste için `../zed/crates/theme/src/styles/colors.rs`
> ve `../zed/crates/settings_content/src/theme.rs` dosyalarını referans
> al; sync turunda mirror et.

#### Tam alan paritesi (pin `6e8eaab25b5a`)

Bu liste, `zed_commit_pin.txt` dosyasındaki pin commit için `ThemeColors` runtime
alanlarının **eksiksiz** kataloğudur. Bu commit'te runtime struct'ı
143 adet `Hsla` alan taşır. `ThemeColorsContent` tarafında buna ek olarak
3 deprecated uyumluluk alanı vardır; onlar Bölüm IV/Konu 18'de ayrıca
belirtilir.

```text
border:
  border, border_variant, border_focused, border_selected,
  border_transparent, border_disabled

surface:
  elevated_surface_background, surface_background, background

element:
  element_background, element_hover, element_active, element_selected,
  element_selection_background, element_disabled,
  drop_target_background, drop_target_border

ghost_element:
  ghost_element_background, ghost_element_hover, ghost_element_active,
  ghost_element_selected, ghost_element_disabled

text:
  text, text_muted, text_placeholder, text_disabled, text_accent

icon:
  icon, icon_muted, icon_disabled, icon_placeholder, icon_accent

debugger:
  debugger_accent

chrome:
  status_bar_background, title_bar_background,
  title_bar_inactive_background, toolbar_background,
  tab_bar_background, tab_inactive_background, tab_active_background,
  search_match_background, search_active_match_background,
  panel_background, panel_focused_border, panel_indent_guide,
  panel_indent_guide_hover, panel_indent_guide_active,
  panel_overlay_background, panel_overlay_hover,
  pane_focused_border, pane_group_border

scrollbar:
  scrollbar_thumb_background, scrollbar_thumb_hover_background,
  scrollbar_thumb_active_background, scrollbar_thumb_border,
  scrollbar_track_background, scrollbar_track_border

minimap:
  minimap_thumb_background, minimap_thumb_hover_background,
  minimap_thumb_active_background, minimap_thumb_border

vim:
  vim_normal_background, vim_insert_background, vim_replace_background,
  vim_visual_background, vim_visual_line_background,
  vim_visual_block_background, vim_yank_background,
  vim_helix_jump_label_foreground, vim_helix_normal_background,
  vim_helix_select_background, vim_normal_foreground,
  vim_insert_foreground, vim_replace_foreground, vim_visual_foreground,
  vim_visual_line_foreground, vim_visual_block_foreground,
  vim_helix_normal_foreground, vim_helix_select_foreground

editor:
  editor_foreground, editor_background, editor_gutter_background,
  editor_subheader_background, editor_active_line_background,
  editor_highlighted_line_background, editor_debugger_active_line_background,
  editor_line_number, editor_active_line_number, editor_hover_line_number,
  editor_invisible, editor_wrap_guide, editor_active_wrap_guide,
  editor_indent_guide, editor_indent_guide_active,
  editor_document_highlight_read_background,
  editor_document_highlight_write_background,
  editor_document_highlight_bracket_background,
  editor_diff_hunk_added_background,
  editor_diff_hunk_added_hollow_background,
  editor_diff_hunk_added_hollow_border,
  editor_diff_hunk_deleted_background,
  editor_diff_hunk_deleted_hollow_background,
  editor_diff_hunk_deleted_hollow_border

terminal:
  terminal_background, terminal_foreground, terminal_bright_foreground,
  terminal_dim_foreground, terminal_ansi_background,
  terminal_ansi_black, terminal_ansi_bright_black, terminal_ansi_dim_black,
  terminal_ansi_red, terminal_ansi_bright_red, terminal_ansi_dim_red,
  terminal_ansi_green, terminal_ansi_bright_green, terminal_ansi_dim_green,
  terminal_ansi_yellow, terminal_ansi_bright_yellow,
  terminal_ansi_dim_yellow, terminal_ansi_blue,
  terminal_ansi_bright_blue, terminal_ansi_dim_blue,
  terminal_ansi_magenta, terminal_ansi_bright_magenta,
  terminal_ansi_dim_magenta, terminal_ansi_cyan,
  terminal_ansi_bright_cyan, terminal_ansi_dim_cyan,
  terminal_ansi_white, terminal_ansi_bright_white,
  terminal_ansi_dim_white

link:
  link_text_hover

version_control:
  version_control_added, version_control_deleted,
  version_control_modified, version_control_renamed,
  version_control_conflict, version_control_ignored,
  version_control_word_added, version_control_word_deleted,
  version_control_conflict_marker_ours,
  version_control_conflict_marker_theirs
```

**Parite testi:** Runtime alan sayısı, `ThemeColorsContent` alan sayısı
ve deprecated content farkları CI'da sayısal olarak doğrulanmalı (Konu
42.11). Bu listeyi elle güncellediğinde `tema_aktarimi.md` pin tarihi de
güncellenir.

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

Tam alan grupları:

```text
conflict, conflict_background, conflict_border
created, created_background, created_border
deleted, deleted_background, deleted_border
error, error_background, error_border
hidden, hidden_background, hidden_border
hint, hint_background, hint_border
ignored, ignored_background, ignored_border
info, info_background, info_border
modified, modified_background, modified_border
predictive, predictive_background, predictive_border
renamed, renamed_background, renamed_border
success, success_background, success_border
unreachable, unreachable_background, unreachable_border
warning, warning_background, warning_border
```

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

#### Editor için `DiagnosticColors` projeksiyonu

Zed'in `crates/theme/src/styles/status.rs:83` dosyasında `StatusColors`'un
yanında **`DiagnosticColors`** adında üç alanlı bir tip vardır:

```rust
pub struct DiagnosticColors {
    pub error: Hsla,
    pub warning: Hsla,
    pub info: Hsla,
}
```

**Rol:** Editor diagnostic'leri (squiggly underline, gutter işaretleri,
diagnostic popup) için **sıkıştırılmış** renk seti. `StatusColors` 42
alan taşırken `DiagnosticColors` editor render path'ine sadece foreground
renklerini sunar. Refinement zincirinde yer almaz — `StatusColors`'tan
**türetilir**:

```rust
impl Theme {
    pub fn diagnostic_colors(&self) -> DiagnosticColors {
        DiagnosticColors {
            error: self.status().error,
            warning: self.status().warning,
            info: self.status().info,
        }
    }
}
```

**Kullanım yeri:** Editor crate'i (`kvs_editor`) diagnostic render
sırasında `cx.theme().status().error` yerine `cx.theme().diagnostic_colors().error`
çağırabilir. Üç alanı bir kez kopyalamak, her render'da üç ayrı `status()`
erişiminden daha okunaklı.

**JSON sözleşmesinde yer almaz.** Tema dosyasında `diagnostic.error`
anahtarı yok; `error`, `warning`, `info` `StatusColors`'tan gelir.
`DiagnosticColors` saf runtime projeksiyonudur.

**Ne zaman kullanılır?**

- Editor diagnostic render: `error` squiggly, `warning` squiggly, `info`
  squiggly.
- Diagnostic popup başlığı (severity icon + renk).
- Gutter işareti yanındaki severity dot.

**Ne zaman kullanılmaz?**

- Modal/banner/toast: `StatusColors`'un üçlü desenini (fg/bg/border)
  kullan; `DiagnosticColors` bg/border vermez.
- File tree status (created/modified/deleted): bunlar diagnostic değil,
  vcs status — `StatusColors.modified` vs.

**Mirror disiplini:** Sync turunda Zed `DiagnosticColors`'a alan eklerse
(örn. `hint`), `kvs_tema`'ya aynısı eklenir. Şu an 3 alan; gelecekte
diagnostic severity'leri genişlerse buradan başla.

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

#[derive(Clone, Debug, PartialEq)]
pub struct PlayerColors(pub Vec<PlayerColor>);

impl Default for PlayerColors {
    fn default() -> Self {
        Self::dark()
    }
}
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

**Zed kaynak sözleşmesinin tüm metotları** (`crates/theme/src/styles/players.rs`):

```rust
impl PlayerColors {
    pub fn dark() -> Self { /* 8 player slot */ }
    pub fn light() -> Self { /* 8 player slot */ }

    /// İlk slot — yerel kullanıcı. Liste boşsa panic eder.
    pub fn local(&self) -> PlayerColor {
        *self.0.first().unwrap()
    }

    /// Agent slot — listenin son elemanı.
    pub fn agent(&self) -> PlayerColor {
        *self.0.last().unwrap()
    }

    /// Absent (yerelde olmayan) kullanıcı — agent ile aynı son slot.
    pub fn absent(&self) -> PlayerColor {
        *self.0.last().unwrap()
    }

    /// Read-only katılımcı — yerel renklerin grayscale projeksiyonu.
    pub fn read_only(&self) -> PlayerColor {
        let local = self.local();
        PlayerColor {
            cursor: local.cursor.grayscale(),
            background: local.background.grayscale(),
            selection: local.selection.grayscale(),
        }
    }

    /// Belirli bir katılımcı indeksine renk atar. Index 0 local slot'u
    /// atlar; modulo ile slot havuzu sarmal döner.
    pub fn color_for_participant(&self, participant_index: u32) -> PlayerColor {
        let len = self.0.len() - 1;
        self.0[(participant_index as usize % len) + 1]
    }
}
```

**Davranış kuralları:**

- Liste boşsa `local()`, `agent()`, `absent()`, `read_only()` ve
  `color_for_participant()` hepsi panic eder. Fallback temalarda her
  zaman en az bir `PlayerColor` doldur; collaboration/participant
  renkleri kullanılıyorsa en az iki slot gerekir.
- `color_for_participant(N)` local slot'u atlar: participant 0, liste index
  1'i kullanır. 8 slot varsa remote slotlar index 1-7 arasında döner.
- `agent()` ve `absent()` aynı slot'u döner (listenin sonu); semantik
  ayrımı tüketici tarafında yapılır — agent UI'sı vs. ofline kullanıcı.
- `read_only()` çağrı sırasında lokal slot'tan grayscale türetir;
  fallback temada lokal değer doluysa otomatik çalışır.
- Bu API boş/tek elemanlı listeyi tolere etmez; listeyi runtime'a
  getirmeden önce fallback veya fixture testleriyle garanti et.

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
let yerel = cx.theme().players().local();
div().bg(yerel.cursor)

// 3. katılımcının seçimi
let katilimci = cx.theme().players().color_for_participant(3);
div().bg(katilimci.selection)
```

#### Tuzaklar

1. **Boş `PlayerColors`**: `Vec` boşsa `local()` panic eder; tek slot
   varsa `color_for_participant` modulo-by-zero panikler. Fallback
   temalarda **en az bir local slot**, participant kullanıyorsan **en az
   iki slot** doldur:
   ```rust
   PlayerColors(vec![PlayerColor { cursor: accent, ... }])
   ```
2. **`color_for_participant(0)` ile `local()`**: Aynı sonucu verir mi?
   Hayır. `local()` index 0'dır; `color_for_participant(0)` index 1'i
   döndürür. Remote katılımcı renkleri local renkten ayrı tutulur.
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

**Zed kaynak sözleşmesi** (`crates/theme/src/styles/accents.rs`):

```rust
#[derive(Clone, Debug, Deserialize, PartialEq)]
pub struct AccentColors(pub Arc<[Hsla]>);

impl Default for AccentColors {
    fn default() -> Self {
        Self::dark()
    }
}

impl AccentColors {
    pub fn dark() -> Self { /* 13 elemanlı sabit liste */ }
    pub fn light() -> Self { /* 13 elemanlı sabit liste */ }

    pub fn color_for_index(&self, index: u32) -> Hsla {
        self.0[index as usize % self.0.len()]
    }
}
```

**Üç önemli sözleşme noktası:**

- İç tip `Arc<[Hsla]>` — `Vec<Hsla>` değil. Sözleşme `Arc<[T]>` üzerinden
  paylaşılır; klon ucuz, mutate edilmez.
- Lookup metodunun adı `color_for_index`, `color_for` değil.
- Boş liste için **fallback yok**: modulo lookup'u `len()` 0'sa panic
  eder. `Default::default()` `Self::dark()` döndüğü için varsayılan
  her zaman 13 elemanlıdır; tema yazarının `accents: []` vermesine de
  refinement katmanı izin vermez (Bölüm V/Konu 23).

**`kvs_tema`'da sözleşme:**

```rust
#[derive(Clone, Debug, Deserialize, PartialEq)]
pub struct AccentColors(pub Arc<[Hsla]>);

impl Default for AccentColors {
    fn default() -> Self {
        Self::dark()
    }
}

impl AccentColors {
    pub fn dark() -> Self { Self(Arc::from(default_dark_accents().as_slice())) }
    pub fn light() -> Self { Self(Arc::from(default_light_accents().as_slice())) }

    pub fn color_for_index(&self, index: u32) -> Hsla {
        self.0[index as usize % self.0.len()]
    }
}
```

**Davranış:**

- Modulo döner — accent listesi tükenince başa sarar.
- Boş liste durumu sözleşmeyle dışlanır; yine de defansif kod gerekiyorsa
  `Default::default()` ile fallback kur (sıfır eleman = panic riski).

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
let chip_color = cx.theme().accents().color_for_index(chip_index);
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
pub enum Appearance {
    Light,
    Dark,
}

impl Appearance {
    pub fn is_light(&self) -> bool {
        match self {
            Self::Light => true,
            Self::Dark => false,
        }
    }
}

impl From<WindowAppearance> for Appearance {
    fn from(value: WindowAppearance) -> Self {
        match value {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Self::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Self::Light,
        }
    }
}
```

> **Not:** Zed kaynağında `Appearance` `#[serde(rename_all = ...)]`
> kullanmaz; JSON anahtarında `"appearance": "light"` / `"dark"` üretmek
> için Content katmanı kendi `AppearanceContent` enum'unu taşır
> (Konu 18). Runtime `Appearance` deserialize ihtiyacı bu yüzden yok;
> ama `serde::Deserialize` derive edilmiştir (testler ve bazı içsel
> akışlar için).

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
   nominal modu, ikincisi sistem modu. Aralarında `From<WindowAppearance>
   for Appearance` impl'i vardır; `Vibrant*` variant'lar `Light`/`Dark`'a
   indirgenir. Doğrudan dönüşüm çalışır:
   ```rust
   let app_appearance: Appearance = cx.window_appearance().into();
   ```
   Sözleşme aynı kalsın diye `SystemAppearance::init` da bu `From` impl'ini
   içeride kullanır (Konu 29). "İki kategoriye indirgenmiş" davranışın
   tek kaynağı bu impl'dir.
4. **JSON'da `appearance` alanı için casing**: Runtime `Appearance` ile
   JSON'daki `AppearanceContent` ayrı tiplerdir. Content tarafı
   serializer ayarlarını taşır (Konu 18); runtime enum'unun rename
   politikası tüketici tarafında görünmez.
5. **`AccentColors::color_for_index(u32)` overflow**: `u32::MAX` versen
   modulo güvenli — usize'a cast'te 64-bit platformda taşma yok. 32-bit
   platformda dikkat ama nadir.
6. **`AccentColors` iç tipini `Vec<Hsla>` yapmak**: Sözleşme `Arc<[Hsla]>`.
   `Vec` yazarsan baseline'dan klon her tema variant'ında yeni alloc
   üretir; `Arc<[T]>` cheap-clone garantisini bozarsın.

---

### 17. `ThemeFamily`, `SyntaxTheme`, `IconTheme`

Bu üç tip tema'nın **toplama ve uzantı** boyutunu taşır: bir paket
içinde birden fazla varyant, syntax token'larının ayrı sözleşmesi, ve
icon tema sözleşmesi.

#### `ThemeFamily`

**Kaynak modül:** `kvs_tema/src/kvs_tema.rs` (lib kökü).

**Zed kaynak sözleşmesi** (`crates/theme/src/theme.rs:192`):

```rust
pub struct ThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<Theme>,
    /// Sözleşmenin sondan bir alanı — Zed'in `scale.rs` palet matrisi.
    /// Yorum: "This will be removed in the future."
    pub scales: ColorScales,
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
| `scales` | Aileye bağlı palet matrisi — `ColorScales` (43.5'te detay). |

> **`scales` alanı için karar:** Zed kaynağı bu alanı `"This will be
> removed in the future."` notuyla taşır. `kvs_tema` `ColorScale`
> mirror etmiyorsa (Konu 43.5 tavsiyesi) bu alan da alınmaz; mirror
> ediyorsa parite gereği aynı sıralamayla eklenir. Karar
> `DECISIONS.md`'ye yazılır.

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
let themes: Vec<Theme> = family.themes
    .into_iter()
    .map(|theme_content| Theme::from_content(theme_content, &baseline))
    .collect();
registry.insert_themes(themes);
```

Aile metadata'sı registry'ye geçmez — sadece tek tek `Theme`'ler
kaydedilir. Aile bilgisi `Theme.id` veya ek metadata tablosunda
saklanmak istenirse opsiyonel.

#### `SyntaxTheme`

**Kaynak crate:** `kvs_syntax_tema` (`kvs_syntax_tema/src/kvs_syntax_tema.rs`).
Zed'in `crates/syntax_theme/src/syntax_theme.rs` dosyasına paritelidir.

```rust
#[derive(Debug, PartialEq, Eq, Clone, Default)]
pub struct SyntaxTheme {
    highlights: Vec<HighlightStyle>,
    capture_name_map: BTreeMap<String, usize>,
}

impl SyntaxTheme {
    /// Yeni sözleşme: tuple iterator alır, `Self` döner (Arc DEĞİL).
    pub fn new(
        highlights: impl IntoIterator<Item = (String, HighlightStyle)>,
    ) -> Self { /* tuple'ları ayrıştırır, capture_name_map indexler */ }

    /// Highlight'ı index üzerinden okur.
    pub fn get(&self, highlight_index: impl Into<usize>) -> Option<&HighlightStyle>;

    /// Capture adıyla highlight lookup'u.
    pub fn style_for_name(&self, name: &str) -> Option<HighlightStyle>;

    /// İndekse karşılık gelen capture adını döner.
    pub fn get_capture_name(&self, idx: impl Into<usize>) -> Option<&str>;

    /// Capture adı için u32 highlight id'sini döner; "string.escape"
    /// gibi alt-kapsama "string" base prefix'i ile eşleşmesini sağlar.
    pub fn highlight_id(&self, capture_name: &str) -> Option<u32>;

    /// Base tema'yı kullanıcı override'ı ile birleştirir; entry boşsa
    /// base'i olduğu gibi döndürür.
    pub fn merge(
        base: Arc<Self>,
        user_syntax_styles: Vec<(String, HighlightStyle)>,
    ) -> Arc<Self>;

    #[cfg(any(test, feature = "test-support"))]
    pub fn new_test(colors: impl IntoIterator<Item = (&'static str, Hsla)>) -> Self;
    #[cfg(any(test, feature = "test-support"))]
    pub fn new_test_styles(
        colors: impl IntoIterator<Item = (&'static str, HighlightStyle)>,
    ) -> Self;
}
```

**Yapı kritik notları:**

- İki **private** alan: `highlights: Vec<HighlightStyle>` (sadece stil
  vektörü, capture adı YOK) ve `capture_name_map: BTreeMap<String,
  usize>` (capture adı → index). Eski API'deki `Vec<(String,
  HighlightStyle)>` artık yok; dış crate'ler `style_for_name`, `get`,
  `highlight_id` üzerinden okur.
- `new(...)` `Self` döner, **`Arc::new` sarmalamaz** — `Arc` sözleşmesi
  caller tarafında kurulur (`Arc::new(SyntaxTheme::new(...))`).
- `style_for_name` `BTreeMap` lookup'u; "ilk eşleşme kazanır" davranışı
  yok — anahtar uniq. Aynı capture iki kez verildiğinde `new`
  ikincisi haritada birinciyi ezer.
- `highlight_id` prefix-eşleşmeli aramaya izin verir: `"string.escape"`
  capture'ı, `"string"` highlight'ına düşer. Tree-sitter integration'da
  alt kapsama kuralı budur.

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

JSON'da object — sıra korunur (`IndexMap` ile). Rust runtime'a
`Vec<(String, HighlightStyle)>` tuple listesi olarak iletilir;
`SyntaxTheme::new` bu listeyi tüketip iki private alana (`highlights`
ve `capture_name_map`) ayırır.

**`new()` `Self` döner — `Arc` sarmalı caller tarafında:**

```rust
let syntax = Arc::new(SyntaxTheme::new(highlights));
```

`Theme` struct'ı içinde alan tipi `Arc<SyntaxTheme>`'dir. `Arc`
sözleşmesi `Theme` katmanında kurulur; `SyntaxTheme::new` API'si Zed
gibi `Self` döndürür (eski rehber sürümünde `Arc::new` içinde sarmalı
gösterilmişti — yanlış).

**Tema'da kullanım:**

```rust
// Capture adı ile lookup — BTreeMap O(log n)
let style = cx.theme().syntax().style_for_name("comment");

// Highlight id alıp index üzerinden okumak (tree-sitter integration)
let id = cx.theme().syntax().highlight_id("string.escape")?;
let style = cx.theme().syntax().get(id as usize)?;

// Capture adı index'ten geri okuma
let name = cx.theme().syntax().get_capture_name(0)?;
```

> **Alan iterasyonu eski örnek hatası:** Eski sürümde
> `for (name, style) in &syntax.highlights` örneği vardı; bu hem
> alanların private olması, hem de `highlights`'ın artık tuple değil
> `Vec<HighlightStyle>` olması nedeniyle derlenmez. Capture adlarına
> tek tek erişmek için `get_capture_name(idx)` döngüsü kullanın veya
> `highlight_id` ile arama yapın.

Editor entegrasyonu Bölüm VIII'de. `SyntaxTheme::merge(base, override)`
helper'ı override'ları base üstüne bindirip yeni `Arc` döner; tema
override'ları (Bölüm VI/Konu 31) bu helper'ı çağırır.

#### `IconTheme`

**Kaynak modül:** `kvs_tema/src/icon_theme.rs`.

Tema sistemi UI renklerinin yanı sıra **icon tema sözleşmesini** de
mirror eder ("Temel ilke" gereği — Konu 2). `IconTheme` Zed'in
`crates/theme/src/icon_theme.rs` dosyasındaki yapıya alan paritesiyle
yazılır.

**Runtime sözleşmesi:**

```rust
use std::sync::Arc;
use collections::HashMap;
use gpui::SharedString;

pub struct IconTheme {
    pub id: String,
    pub name: SharedString,
    pub appearance: Appearance,
    pub directory_icons: DirectoryIcons,
    pub named_directory_icons: HashMap<String, DirectoryIcons>,
    pub chevron_icons: ChevronIcons,
    pub file_stems: HashMap<String, String>,     // "Cargo.toml" → "icon-id"
    pub file_suffixes: HashMap<String, String>,  // "rs" → "icon-id"
    pub file_icons: HashMap<String, IconDefinition>,
}

pub struct DirectoryIcons {
    pub collapsed: Option<SharedString>,         // SVG/PNG yolu
    pub expanded: Option<SharedString>,
}

pub struct ChevronIcons {
    pub collapsed: Option<SharedString>,
    pub expanded: Option<SharedString>,
}

pub struct IconDefinition {
    pub path: SharedString,                       // asset altındaki dosya yolu
}

pub struct IconThemeFamily {
    pub id: String,
    pub name: SharedString,
    pub author: SharedString,
    pub themes: Vec<IconTheme>,
}
```

> **Uyarı:** Alan listesi Zed sözleşmesini takip eder; sync turunda
> (`tema_aktarimi.md`) yeni alan/struct gelirse `kvs_tema/src/icon_theme.rs`
> güncellenir. Icon tema sözleşmesi UI renk sözleşmesinden daha hızlı
> evrilebilir.

**JSON Content sözleşmesi:**

```rust
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct IconThemeFamilyContent {
    pub name: String,
    pub author: String,
    pub themes: Vec<IconThemeContent>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct IconThemeContent {
    pub name: String,
    pub appearance: AppearanceContent,
    #[serde(default)]
    pub directory_icons: DirectoryIconsContent,
    #[serde(default)]
    pub named_directory_icons: HashMap<String, DirectoryIconsContent>,
    #[serde(default)]
    pub chevron_icons: ChevronIconsContent,
    #[serde(default)]
    pub file_stems: HashMap<String, String>,
    #[serde(default)]
    pub file_suffixes: HashMap<String, String>,
    #[serde(default)]
    pub file_icons: HashMap<String, IconDefinitionContent>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct DirectoryIconsContent {
    pub collapsed: Option<String>,
    pub expanded: Option<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct ChevronIconsContent {
    pub collapsed: Option<String>,
    pub expanded: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct IconDefinitionContent {
    pub path: String,
}
```

`*Content` tiplerinin opsiyonellik felsefesi UI temasıyla aynı (Konu 19):
her alan ya `Option` ya da `#[serde(default)]` ile boş kabul edilir.

**Content → Runtime akışı:**

```rust
impl IconTheme {
    pub fn from_content(c: IconThemeContent) -> Self {
        Self {
            id: uuid::Uuid::new_v4().to_string(),
            name: SharedString::from(c.name),
            appearance: match c.appearance {
                AppearanceContent::Light => Appearance::Light,
                AppearanceContent::Dark => Appearance::Dark,
            },
            directory_icons: DirectoryIcons {
                collapsed: c.directory_icons.collapsed.map(SharedString::from),
                expanded: c.directory_icons.expanded.map(SharedString::from),
            },
            named_directory_icons: c.named_directory_icons.into_iter()
                .map(|(k, v)| (k, DirectoryIcons {
                    collapsed: v.collapsed.map(SharedString::from),
                    expanded: v.expanded.map(SharedString::from),
                }))
                .collect(),
            chevron_icons: ChevronIcons {
                collapsed: c.chevron_icons.collapsed.map(SharedString::from),
                expanded: c.chevron_icons.expanded.map(SharedString::from),
            },
            file_stems: c.file_stems,
            file_suffixes: c.file_suffixes,
            file_icons: c.file_icons.into_iter()
                .map(|(k, v)| (k, IconDefinition { path: v.path.into() }))
                .collect(),
        }
    }
}
```

UI temasından farklı: **refinement katmanı yok**. Icon tema'da
baseline+kullanıcı birleştirme deseni şu an gerek değil (kullanıcı kendi
icon tema'sını **bütünüyle** yazar, baseline ile karışım nadir). Mirror
disiplini gereği gelecekte gerekirse `IconThemeRefinement` türetilir.

**Rol:** Dosya/dizin/chevron icon'larının **kaynağını** tutar; UI sadece
icon id'sini bilir, asıl SVG/PNG asset registry'sinden gelir.

**Tema sözleşmesindeki yer:** Icon tema, UI tema (`Theme`) ile **kardeş**
bir kavram — `Theme.styles` içine **girmez**. Zed'e uyumlu runtime'da
ikisi aynı `ThemeRegistry` içinde farklı map'lerde tutulur:

```rust
struct ThemeRegistryState {
    themes: HashMap<SharedString, Arc<Theme>>,
    icon_themes: HashMap<SharedString, Arc<IconTheme>>,
    extensions_loaded: bool,
}

impl ThemeRegistry {
    pub fn insert_icon_theme(&self, icon_theme: IconTheme) { /* ... */ }
    pub fn get_icon_theme(&self, name: &str) -> Result<Arc<IconTheme>, IconThemeNotFoundError> { /* ... */ }
    pub fn list_icon_themes(&self) -> Vec<ThemeMeta> { /* ... */ }
    pub fn load_icon_theme(&self, family: IconThemeFamilyContent, icons_root: &Path) -> anyhow::Result<()> { /* ... */ }
}
```

Aktif icon tema ayrı bir `GlobalIconTheme` yerine `GlobalTheme` içinde
tutulur (Konu 28). Bu, tema seçimi ve icon tema seçimini aynı refresh
modeline bağlar: settings değişir → uygun `Theme` ve `IconTheme` registry'den
çözülür → `GlobalTheme::update_theme` / `update_icon_theme` çağrılır →
`cx.refresh_windows()`.

**JSON şeması:**

```json
{
  "name": "Material Icons",
  "author": "Material team",
  "themes": [{
    "name": "Material",
    "appearance": "dark",
    "directory_icons": {
      "collapsed": "icons/folder-closed.svg",
      "expanded":  "icons/folder-open.svg"
    },
    "named_directory_icons": {
      ".github": {
        "collapsed": "icons/folder-github.svg",
        "expanded":  "icons/folder-github-open.svg"
      }
    },
    "chevron_icons": {
      "collapsed": "icons/chevron-right.svg",
      "expanded":  "icons/chevron-down.svg"
    },
    "file_stems": { "Cargo.toml": "rust-cargo", "package.json": "npm" },
    "file_suffixes": { "rs": "rust", "ts": "typescript", "md": "markdown" },
    "file_icons": {
      "rust":       { "path": "icons/rust.svg" },
      "typescript": { "path": "icons/typescript.svg" },
      "markdown":   { "path": "icons/markdown.svg" }
    }
  }]
}
```

**Lookup mantığı (UI tüketicisi):**

```rust
pub fn icon_for_file(name: &str, icon_theme: &IconTheme) -> Option<&str> {
    // 1. Tam dosya adı (stem) eşleşmesi öncelikli
    if let Some(id) = icon_theme.file_stems.get(name) {
        return icon_theme.file_icons.get(id).map(|d| d.path.as_ref());
    }
    // 2. Uzantı bazlı eşleşme
    if let Some(ext) = std::path::Path::new(name)
        .extension()
        .and_then(|e| e.to_str())
    {
        if let Some(id) = icon_theme.file_suffixes.get(ext) {
            return icon_theme.file_icons.get(id).map(|d| d.path.as_ref());
        }
    }
    None
}
```

**Asset yükleme:** Icon path'leri (örn. `icons/rust.svg`) `AssetSource`
katmanından çözülür (Konu 33). `IconTheme` yalnız path'i tutar; SVG
parse'ı GPUI'nin `svg()` element çağrısında olur.

**Bundling akışı (Konu 33'ün parça-paralel akışı):**

```rust
pub fn load_bundled_icon_themes(
    registry: &ThemeRegistry,
) -> anyhow::Result<()> {
    for path in EmbeddedAssets::iter()
        .filter(|p| p.starts_with("icon_themes/") && p.ends_with(".json"))
    {
        let file = EmbeddedAssets::get(&path)
            .ok_or_else(|| anyhow::anyhow!("asset missing: {}", path))?;
        let family: IconThemeFamilyContent =
            serde_json_lenient::from_slice(&file.data)?;
        registry.load_icon_theme(family, Path::new("icon_themes/"))?;
    }
    Ok(())
}
```

**`kvs_tema::init` ile entegrasyon:**

`init` UI tema registry'sinin yanında icon tema registry'sini de
kurabilir. Bu opsiyonel — uygulama icon teması kullanmıyorsa atlanır:

```rust
pub fn init(cx: &mut App) {
    SystemAppearance::init(cx);

    // UI tema registry (Konu 30)
    let theme_registry = Arc::new(ThemeRegistry::new(Box::new(()) as Box<dyn AssetSource>));
    theme_registry.insert_themes([
        fallback::kvs_default_dark(),
        fallback::kvs_default_light(),
    ]);
    // set_global Zed'de pub(crate); kvs_tema'da mirror'da public yapmak
    // mümkün ama init helper kullanmak daha tutarlı (Konu 30).
    kvs_tema::init(LoadThemes::JustBase, cx);

    let theme_registry = ThemeRegistry::global(cx);
    let active_theme = theme_registry
        .get("Kvs Default Dark")
        .expect("default tema kayıtlı olmalı");
    let active_icon_theme = theme_registry
        .default_icon_theme()
        .expect("default icon tema kayıtlı olmalı");

    cx.set_global(GlobalTheme::new(active_theme, active_icon_theme));
}
```

#### Tuzaklar

1. **`ThemeFamily.id` kullanılmıyorsa**: Registry sadece `Theme`'leri
   isim üzerinden indeksliyor. `ThemeFamily.id` runtime'da neredeyse hiç
   sorgulanmıyor — saklamak isimsel/debug; ekstra metadata için
   gerekmiyorsa atlayabilirsin (ama Zed paritesi için tut).
2. **`SyntaxTheme::new()`'nun `Arc` döndüğünü varsaymak**: Zed sözleşmesi
   `Self` döner; `Arc` sözleşmesi caller tarafında kurulur
   (`Arc::new(SyntaxTheme::new(...))`). Eski rehber sürümünde "factory
   Arc'a sarar" yazıyordu — bu yanlış.
3. **`SyntaxTheme.highlights` alanına dışarıdan erişmek**: Alan private;
   tüketici sadece `style_for_name`, `get`, `get_capture_name`,
   `highlight_id` üzerinden okur. `IndexMap`/`HashMap` tartışması da
   tarihseldir: gerçek implementasyon iki ayrı yapı kullanır
   (`Vec<HighlightStyle>` + `BTreeMap<String, usize>`).
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
    #[serde(
        rename = "background.appearance",
        default,
        deserialize_with = "treat_error_as_none"
    )]
    pub window_background_appearance: Option<WindowBackgroundContent>,

    #[serde(default)]
    pub accents: Vec<AccentContent>,

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

#### Diğer Content tipleri — temel tanımlar ve tam alan haritası

`ThemeStyleContent`'in alt-tipleri:

```rust
// ─── Enum'lar — snake_case rename
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum AppearanceContent {
    Light,
    Dark,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum WindowBackgroundContent {
    Opaque,
    Transparent,
    Blurred,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(rename_all = "snake_case")]
pub enum FontStyleContent {
    Normal,
    Italic,
    Oblique,
}

// ─── Newtype — saydam
#[derive(Debug, Clone, Copy, Serialize, Deserialize, JsonSchema)]
#[serde(transparent)]
pub struct FontWeightContent(pub f32);

#[derive(Debug, Clone, Serialize, Deserialize, JsonSchema)]
pub struct AccentContent(pub Option<String>);

// ─── HighlightStyleContent (syntax token sözleşmesi)
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

// ─── PlayerColorContent (collaboration slot'ları)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
pub struct PlayerColorContent {
    pub cursor: Option<String>,
    pub background: Option<String>,
    pub selection: Option<String>,
}

// ─── ThemeColorsContent (UI renkleri — ~150 alan)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct ThemeColorsContent {
    pub border: Option<String>,
    #[serde(rename = "border.variant")]
    pub border_variant: Option<String>,
    #[serde(rename = "border.focused")]
    pub border_focused: Option<String>,
    #[serde(rename = "border.selected")]
    pub border_selected: Option<String>,
    #[serde(rename = "border.transparent")]
    pub border_transparent: Option<String>,
    #[serde(rename = "border.disabled")]
    pub border_disabled: Option<String>,

    pub background: Option<String>,
    #[serde(rename = "surface.background")]
    pub surface_background: Option<String>,
    #[serde(rename = "elevated_surface.background")]
    pub elevated_surface_background: Option<String>,

    #[serde(rename = "element.background")]
    pub element_background: Option<String>,
    #[serde(rename = "element.hover")]
    pub element_hover: Option<String>,
    #[serde(rename = "element.active")]
    pub element_active: Option<String>,
    #[serde(rename = "element.selected")]
    pub element_selected: Option<String>,
    #[serde(rename = "element.disabled")]
    pub element_disabled: Option<String>,

    pub text: Option<String>,
    #[serde(rename = "text.muted")]
    pub text_muted: Option<String>,
    #[serde(rename = "text.placeholder")]
    pub text_placeholder: Option<String>,
    #[serde(rename = "text.disabled")]
    pub text_disabled: Option<String>,
    #[serde(rename = "text.accent")]
    pub text_accent: Option<String>,

    pub icon: Option<String>,
    #[serde(rename = "icon.muted")]
    pub icon_muted: Option<String>,
    #[serde(rename = "icon.disabled")]
    pub icon_disabled: Option<String>,

    #[serde(rename = "terminal.ansi.black")]
    pub terminal_ansi_black: Option<String>,
    #[serde(rename = "terminal.ansi.red")]
    pub terminal_ansi_red: Option<String>,
    // ... 8 ANSI rengi × 3 (normal + bright + dim) = 24 alan
    // ... terminal background/foreground/bright_foreground/dim_foreground
    // ... editör, debugger, vcs, vim, panel, scrollbar, tab grupları
    // (tam liste: ThemeColors'taki ~150 alanın hepsi mirror edilir)
}

// Pin 6e8eaab25b5a için tam ThemeColorsContent alan haritası:
//
// border => "border"
// border_variant => "border.variant"
// border_focused => "border.focused"
// border_selected => "border.selected"
// border_transparent => "border.transparent"
// border_disabled => "border.disabled"
// elevated_surface_background => "elevated_surface.background"
// surface_background => "surface.background"
// background => "background"
// element_background => "element.background"
// element_hover => "element.hover"
// element_active => "element.active"
// element_selected => "element.selected"
// element_disabled => "element.disabled"
// element_selection_background => "element.selection_background"
// drop_target_background => "drop_target.background"
// drop_target_border => "drop_target.border"
// ghost_element_background => "ghost_element.background"
// ghost_element_hover => "ghost_element.hover"
// ghost_element_active => "ghost_element.active"
// ghost_element_selected => "ghost_element.selected"
// ghost_element_disabled => "ghost_element.disabled"
// text => "text"
// text_muted => "text.muted"
// text_placeholder => "text.placeholder"
// text_disabled => "text.disabled"
// text_accent => "text.accent"
// icon => "icon"
// icon_muted => "icon.muted"
// icon_disabled => "icon.disabled"
// icon_placeholder => "icon.placeholder"
// icon_accent => "icon.accent"
// debugger_accent => "debugger.accent"
// status_bar_background => "status_bar.background"
// title_bar_background => "title_bar.background"
// title_bar_inactive_background => "title_bar.inactive_background"
// toolbar_background => "toolbar.background"
// tab_bar_background => "tab_bar.background"
// tab_inactive_background => "tab.inactive_background"
// tab_active_background => "tab.active_background"
// search_match_background => "search.match_background"
// search_active_match_background => "search.active_match_background"
// panel_background => "panel.background"
// panel_focused_border => "panel.focused_border"
// panel_indent_guide => "panel.indent_guide"
// panel_indent_guide_hover => "panel.indent_guide_hover"
// panel_indent_guide_active => "panel.indent_guide_active"
// panel_overlay_background => "panel.overlay_background"
// panel_overlay_hover => "panel.overlay_hover"
// pane_focused_border => "pane.focused_border"
// pane_group_border => "pane_group.border"
// deprecated_scrollbar_thumb_background => "scrollbar_thumb.background"
// scrollbar_thumb_background => "scrollbar.thumb.background"
// scrollbar_thumb_hover_background => "scrollbar.thumb.hover_background"
// scrollbar_thumb_active_background => "scrollbar.thumb.active_background"
// scrollbar_thumb_border => "scrollbar.thumb.border"
// scrollbar_track_background => "scrollbar.track.background"
// scrollbar_track_border => "scrollbar.track.border"
// minimap_thumb_background => "minimap.thumb.background"
// minimap_thumb_hover_background => "minimap.thumb.hover_background"
// minimap_thumb_active_background => "minimap.thumb.active_background"
// minimap_thumb_border => "minimap.thumb.border"
// editor_foreground => "editor.foreground"
// editor_background => "editor.background"
// editor_gutter_background => "editor.gutter.background"
// editor_subheader_background => "editor.subheader.background"
// editor_active_line_background => "editor.active_line.background"
// editor_highlighted_line_background => "editor.highlighted_line.background"
// editor_debugger_active_line_background => "editor.debugger_active_line.background"
// editor_line_number => "editor.line_number"
// editor_active_line_number => "editor.active_line_number"
// editor_hover_line_number => "editor.hover_line_number"
// editor_invisible => "editor.invisible"
// editor_wrap_guide => "editor.wrap_guide"
// editor_active_wrap_guide => "editor.active_wrap_guide"
// editor_indent_guide => "editor.indent_guide"
// editor_indent_guide_active => "editor.indent_guide_active"
// editor_document_highlight_read_background => "editor.document_highlight.read_background"
// editor_document_highlight_write_background => "editor.document_highlight.write_background"
// editor_document_highlight_bracket_background => "editor.document_highlight.bracket_background"
// editor_diff_hunk_added_background => "editor.diff_hunk.added.background"
// editor_diff_hunk_added_hollow_background => "editor.diff_hunk.added.hollow_background"
// editor_diff_hunk_added_hollow_border => "editor.diff_hunk.added.hollow_border"
// editor_diff_hunk_deleted_background => "editor.diff_hunk.deleted.background"
// editor_diff_hunk_deleted_hollow_background => "editor.diff_hunk.deleted.hollow_background"
// editor_diff_hunk_deleted_hollow_border => "editor.diff_hunk.deleted.hollow_border"
// terminal_background => "terminal.background"
// terminal_foreground => "terminal.foreground"
// terminal_ansi_background => "terminal.ansi.background"
// terminal_bright_foreground => "terminal.bright_foreground"
// terminal_dim_foreground => "terminal.dim_foreground"
// terminal_ansi_black => "terminal.ansi.black"
// terminal_ansi_bright_black => "terminal.ansi.bright_black"
// terminal_ansi_dim_black => "terminal.ansi.dim_black"
// terminal_ansi_red => "terminal.ansi.red"
// terminal_ansi_bright_red => "terminal.ansi.bright_red"
// terminal_ansi_dim_red => "terminal.ansi.dim_red"
// terminal_ansi_green => "terminal.ansi.green"
// terminal_ansi_bright_green => "terminal.ansi.bright_green"
// terminal_ansi_dim_green => "terminal.ansi.dim_green"
// terminal_ansi_yellow => "terminal.ansi.yellow"
// terminal_ansi_bright_yellow => "terminal.ansi.bright_yellow"
// terminal_ansi_dim_yellow => "terminal.ansi.dim_yellow"
// terminal_ansi_blue => "terminal.ansi.blue"
// terminal_ansi_bright_blue => "terminal.ansi.bright_blue"
// terminal_ansi_dim_blue => "terminal.ansi.dim_blue"
// terminal_ansi_magenta => "terminal.ansi.magenta"
// terminal_ansi_bright_magenta => "terminal.ansi.bright_magenta"
// terminal_ansi_dim_magenta => "terminal.ansi.dim_magenta"
// terminal_ansi_cyan => "terminal.ansi.cyan"
// terminal_ansi_bright_cyan => "terminal.ansi.bright_cyan"
// terminal_ansi_dim_cyan => "terminal.ansi.dim_cyan"
// terminal_ansi_white => "terminal.ansi.white"
// terminal_ansi_bright_white => "terminal.ansi.bright_white"
// terminal_ansi_dim_white => "terminal.ansi.dim_white"
// link_text_hover => "link_text.hover"
// version_control_added => "version_control.added"
// version_control_deleted => "version_control.deleted"
// version_control_modified => "version_control.modified"
// version_control_renamed => "version_control.renamed"
// version_control_conflict => "version_control.conflict"
// version_control_ignored => "version_control.ignored"
// version_control_word_added => "version_control.word_added"
// version_control_word_deleted => "version_control.word_deleted"
// version_control_conflict_marker_ours => "version_control.conflict_marker.ours"
// version_control_conflict_marker_theirs => "version_control.conflict_marker.theirs"
// version_control_conflict_ours_background => "version_control_conflict_ours_background" (deprecated)
// version_control_conflict_theirs_background => "version_control_conflict_theirs_background" (deprecated)
// vim_normal_background => "vim.normal.background"
// vim_insert_background => "vim.insert.background"
// vim_replace_background => "vim.replace.background"
// vim_visual_background => "vim.visual.background"
// vim_visual_line_background => "vim.visual_line.background"
// vim_visual_block_background => "vim.visual_block.background"
// vim_yank_background => "vim.yank.background"
// vim_helix_jump_label_foreground => "vim.helix_jump_label.foreground"
// vim_helix_normal_background => "vim.helix_normal.background"
// vim_helix_select_background => "vim.helix_select.background"
// vim_normal_foreground => "vim.normal.foreground"
// vim_insert_foreground => "vim.insert.foreground"
// vim_replace_foreground => "vim.replace.foreground"
// vim_visual_foreground => "vim.visual.foreground"
// vim_visual_line_foreground => "vim.visual_line.foreground"
// vim_visual_block_foreground => "vim.visual_block.foreground"
// vim_helix_normal_foreground => "vim.helix_normal.foreground"
// vim_helix_select_foreground => "vim.helix_select.foreground"

// ─── StatusColorsContent (14 status × 3 = 42 alan)
#[derive(Debug, Clone, Default, Serialize, Deserialize, JsonSchema)]
#[serde(default)]
pub struct StatusColorsContent {
    pub error: Option<String>,
    #[serde(rename = "error.background")]
    pub error_background: Option<String>,
    #[serde(rename = "error.border")]
    pub error_border: Option<String>,

    pub warning: Option<String>,
    #[serde(rename = "warning.background")]
    pub warning_background: Option<String>,
    #[serde(rename = "warning.border")]
    pub warning_border: Option<String>,

    // ... 14 status (conflict, created, deleted, hidden, hint, ignored,
    // info, modified, predictive, renamed, success, unreachable) × üçlü
}
```

`ThemeColorsContent` pin `6e8eaab25b5a` için 146 `Option<String>` alan
taşır. Bunların 143'ü runtime `ThemeColors` alanlarına birebir gider;
3'ü eski tema JSON'larını kırmamak için content-only deprecated uyumluluk
alanıdır:

- `deprecated_scrollbar_thumb_background` (`scrollbar_thumb.background`)
  yeni `scrollbar_thumb_background` boşsa ona aktarılır.
- `version_control_conflict_ours_background` yeni
  `version_control_conflict_marker_ours` boşsa ona aktarılır.
- `version_control_conflict_theirs_background` yeni
  `version_control_conflict_marker_theirs` boşsa ona aktarılır.

Refinement üretirken yeni alan **her zaman önceliklidir**; deprecated
alan sadece fallback olarak kullanılır. Runtime `ThemeColors` içinde
deprecated alan tutulmaz.

**Davranış kuralları (özet):**

| Tip | Opsiyonellik | Yanlış değer davranışı |
|-----|--------------|------------------------|
| `AppearanceContent` | `ThemeContent.appearance` **zorunlu** | Deserialize hatası (tema tüm yüklenmez) |
| `WindowBackgroundContent` | `Option` + `treat_error_as_none` ile tolerans | `None` (baseline'dan) |
| `FontStyleContent` | `Option` + `treat_error_as_none` | `None` |
| `FontWeightContent` | `Option` + `treat_error_as_none`; `f32` newtype | `None` |
| `HighlightStyleContent.color` | `Option<String>` (geçersiz hex → refinement'ta `None`) | `None` |
| `HighlightStyleContent` (diğer) | `Option<...>` + `treat_error_as_none` | `None` |
| `PlayerColorContent` (3 alan) | hepsi `Option<String>` | Eksik alan baseline.local'dan |
| `ThemeColorsContent` (150 alan) | her biri `Option<String>` | Refinement → baseline |
| `StatusColorsContent` (42 alan) | her biri `Option<String>` | Refinement → baseline (fg→bg türetme uygulanır) |

> **`AppearanceContent` neden `Option` değil?** Bir tema'nın "Light mı
> Dark mı" sorusu **kritik**; eksikse renk seçimi anlamsız. Tema
> yazarı bu alanı yazmak zorunda — sözleşmenin tek zorunlu enum alanı.

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

#### `serde_json_lenient` ile JSON yazım kolaylığı

Zed tema dosyaları **standart JSON değil**: yorum satırları ve trailing
comma içerebilir. Bunları parse edebilmek için `serde_json_lenient`
kullanılır (Konu 5 bağımlılık matrisinde sabit).

**Desteklenen genişletmeler:**

```jsonc
{
  // Tek satır yorum (// ile başlar)
  "name": "My Theme",
  "author": "x",

  /* Çok satırlı yorum bloğu —
     açıklama, atıf, vs. */
  "themes": [{
    "name": "My Dark",
    "appearance": "dark",
    "style": {
      "background": "#1c2025ff",
      "border":     "#2a2f3aff",   // satır sonu yorumu da kabul
      "text":       "#c8ccd4ff",   // ← trailing comma yasal
    },
  }],   // ← array elemanı sonrası trailing comma
}       // ← object kapatması öncesi trailing comma
```

**Standart `serde_json` (lenient olmayan) bu JSON'u parse edemez:**
yorum satırı `Err("expected value")`, trailing comma `Err("trailing
comma")` verir. Zed tüm built-in temalarını yorum/trailing comma ile
yazıyor; bu yüzden `serde_json_lenient` **zorunlu**.

**Kullanım:**

```rust
let family: ThemeFamilyContent =
    serde_json_lenient::from_slice(&bytes)?;
// veya str için:
let family: ThemeFamilyContent =
    serde_json_lenient::from_str(json)?;
```

API yüzeyi `serde_json` ile uyumlu — sadece import farkı.

**Sınırlamalar:**

- Unquoted key (`{ name: "x" }`) **kabul edilmez** — JavaScript object
  literal değil, JSON.
- Single quote string (`'value'`) kabul edilmez.
- JSON5'in genişletmeleri tam olarak destekli değil; sadece yorum +
  trailing comma.

**Tuzak — yazma yönü:** Tema dosyasını sen yazıyorsan (test fixture,
fallback dump) `serde_json::to_string_pretty` çıktısı standart JSON'dur
(yorumsuz). Lenient sadece **okuma**da; yazılan çıktı sade JSON
formatındadır.

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

    // 4. Accents: boş ise baseline'a dokunma; dolu ise parse edilebilen
    //    renkleri topla. Zed paritesi (`merge_accent_colors`,
    //    theme_settings/src/theme_settings.rs:395): parse edilebilen renkler
    //    boş çıkarsa accent listesini değiştirme; aksi halde baseline
    //    `Arc<[Hsla]>`'i tamamen değiştir.
    let mut accents = baseline.styles.accents.clone();
    if !content.style.accents.is_empty() {
        let parsed: Vec<Hsla> = content.style.accents.iter()
            .filter_map(|c| c.0.as_deref().and_then(|s| try_parse_color(s).ok()))
            .collect();
        if !parsed.is_empty() {
            accents = AccentColors(Arc::from(parsed));
        }
    }

    // 5. Players: boş ise baseline, dolu ise IDX BAZLI merge.
    //    Zed paritesi: `merge_player_colors` (theme_settings/src/theme_settings.rs:356)
    //    her idx için **o idx'in baseline player'ı**nı koruyarak field
    //    bazında override eder; idx baseline'dan büyükse yeni
    //    `PlayerColor::default()` üstüne yazar. `.local()` (idx=0) ile
    //    tüm slot'ları doldurmak YANLIŞ — slot semantiği bozulur.
    let mut player = baseline.styles.player.clone();
    for (idx, p) in content.style.players.iter().enumerate() {
        let cursor = p.cursor.as_deref().and_then(|s| try_parse_color(s).ok());
        let background = p.background.as_deref().and_then(|s| try_parse_color(s).ok());
        let selection = p.selection.as_deref().and_then(|s| try_parse_color(s).ok());
        if let Some(slot) = player.0.get_mut(idx) {
            *slot = PlayerColor {
                cursor: cursor.unwrap_or(slot.cursor),
                background: background.unwrap_or(slot.background),
                selection: selection.unwrap_or(slot.selection),
            };
        } else {
            player.0.push(PlayerColor {
                cursor: cursor.unwrap_or_default(),
                background: background.unwrap_or_default(),
                selection: selection.unwrap_or_default(),
            });
        }
    }

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

**Adım 6 — Syntax: `IndexMap` → `Vec<(String, HighlightStyle)>` tuple
listesi → `SyntaxTheme`.**

Content tarafında `IndexMap<String, HighlightStyleContent>` (sıra
korunur). Runtime tarafında her entry tuple'a çevrilir; `highlight_style`
helper (Konu 7) her `HighlightStyleContent`'i `HighlightStyle`'a çevirir.
Tuple listesi `SyntaxTheme::new(...)` constructor'ına geçer; constructor
iç `Vec<HighlightStyle>` ve `BTreeMap<String, usize>` yapılarını üretir.

`SyntaxTheme::new()` `Self` döner; caller `Arc::new(SyntaxTheme::new(...))`
ile sarmalar. `Theme.styles.syntax` alanı `Arc<SyntaxTheme>` taşır,
böylece light/dark varyantları arasında syntax bölümü paylaşılabilir.

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

#### Zed paritesi: `refine_theme*`, `merge_*`, `load_user_theme`

Yukarıdaki `Theme::from_content` `kvs_tema`'nın tasarım önerisidir. Zed'de
aynı işi yapan **dört public fonksiyon** vardır
(`crates/theme_settings/src/theme_settings.rs`):

| Fonksiyon | Sorumluluk | Karşılık |
|-----------|------------|----------|
| `pub fn refine_theme(theme: &ThemeContent) -> Theme` | Tek `ThemeContent` → `Theme`. Baseline'ı `appearance`'a göre `ThemeColors::light`/`dark` ile alır, refinement + merge + parse pipeline'ını çalıştırır | `Theme::from_content` ile aynı 6 adım |
| `pub fn refine_theme_family(content: ThemeFamilyContent) -> ThemeFamily` | Tüm aileyi `refine_theme` ile çevirip `ThemeFamily { themes, scales: default_color_scales(), … }` üretir | Aile-bazlı yardımcı; tek tema için `refine_theme` yeterli |
| `pub fn merge_player_colors(&mut PlayerColors, &[PlayerColorContent])` | Adım 5'in kanonik implementasyonu (idx başına field bazında merge) | Yukarıdaki düzeltilmiş Adım 5 |
| `pub fn merge_accent_colors(&mut AccentColors, &[AccentContent])` | Adım 4'ün kanonik implementasyonu (parse edilen liste boş değilse `Arc<[Hsla]>`'i tamamen değiştir) | Yukarıdaki düzeltilmiş Adım 4 |

Ayrıca `pub fn load_user_theme(registry: &ThemeRegistry, bytes: &[u8]) -> Result<()>`
ve `pub fn deserialize_user_theme(bytes: &[u8]) -> Result<ThemeFamilyContent>`
fonksiyonları kullanıcı tema dosyasını disk'ten parse eden public yüzeydir:

```rust
// theme_settings/src/theme_settings.rs:225-251
pub fn load_user_theme(registry: &ThemeRegistry, bytes: &[u8]) -> Result<()> {
    let theme = deserialize_user_theme(bytes)?;
    let refined = refine_theme_family(theme);
    registry.insert_theme_families([refined]);
    Ok(())
}

pub fn deserialize_user_theme(bytes: &[u8]) -> Result<ThemeFamilyContent> {
    let theme_family: ThemeFamilyContent =
        serde_json_lenient::from_slice(bytes)?;

    for theme in &theme_family.themes {
        if theme.style.colors.deprecated_scrollbar_thumb_background.is_some() {
            log::warn!(
                r#"Theme "{name}" is using a deprecated style property: \
                   scrollbar_thumb.background. Use `scrollbar.thumb.background` \
                   instead."#,
                name = theme.name
            );
        }
    }
    Ok(theme_family)
}
```

Reçete 42.10 (kullanıcı tema dizini ekleme) mirror tarafında bu iki
fonksiyonu doğrudan kullanır:

```rust
pub fn kullanici_tema_yukle(
    registry: &ThemeRegistry,
    bytes: &[u8],
) -> anyhow::Result<()> {
    let aile = deserialize_user_theme(bytes)?;
    let refined = refine_theme_family(aile);
    registry.insert_theme_families([refined]);
    Ok(())
}
```

Deprecated alan uyarısı (`deprecated_scrollbar_thumb_background`) Zed'de
**log seviyesinde** kalır; parse hatası yapmaz. `kvs_tema` mirror'ında aynı
strateji uygulanır — deprecated alanlar `tracing::warn!` ile yazılır,
kullanıcının teması yine yüklenir.

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

Yüklü UI temalarının ve icon temalarının ad-bazlı kataloğu. Thread-safe
read/write erişim; runtime'ın tek "tema veritabanı"sı.

#### Yapı

```rust
use parking_lot::RwLock;
use std::sync::Arc;
use collections::HashMap;
use gpui::{AssetSource, SharedString};

#[derive(Debug, Clone)]
pub struct ThemeMeta {
    pub name: SharedString,
    pub appearance: Appearance,
}

struct ThemeRegistryState {
    themes: HashMap<SharedString, Arc<Theme>>,
    icon_themes: HashMap<SharedString, Arc<IconTheme>>,
    extensions_loaded: bool,
}

pub struct ThemeRegistry {
    state: RwLock<ThemeRegistryState>,
    assets: Box<dyn AssetSource>,
}
```

**Üç katmanlı sarmalama:**

1. **`Arc<Theme>` / `Arc<IconTheme>`** — Her tema paylaşılabilir; klon
   ucuz (refcount). Zed paritesinde `cx.theme()` ve
   `GlobalTheme::icon_theme(cx)` `&Arc<_>` döner.
2. **`HashMap<SharedString, _>`** — Ad bazlı O(1) lookup. `SharedString`
   key (Bölüm II/Konu 7); klonsuz hashleme.
3. **`RwLock<...>`** — Çoklu okuyucu, tek yazıcı. Tema okuma sık
   (render path); yazma nadir (init + reload).
4. **`AssetSource`** — Built-in tema ve icon theme asset'lerini aynı
   registry üstünden listeler/yükler; production bundling ile uyumlu.

> **Neden `parking_lot::RwLock`?** `std::sync::RwLock` daha yavaş ve
> daha büyük; ayrıca poisoned-on-panic davranışı zorunlu unwrap'lere
> yol açar. `parking_lot::RwLock`:
> - ~2× hızlı kilit-açma
> - Daha küçük bellek ayak izi
> - Poison yok — panic sonrası lock kullanılabilir
> - `read()`/`write()` doğrudan guard döner; `unwrap()` gereksiz

#### Hata tipleri

**Zed kaynak sözleşmesi** (`crates/theme/src/registry.rs:27`, `:32`):
hata tipi adları `ThemeNotFoundError` / `IconThemeNotFoundError` — sonunda
`Error` suffix'i. `kvs_tema` mirror'ında aynı isimler kullanılır:

```rust
use thiserror::Error;

#[derive(Debug, Error)]
#[error("tema bulunamadı: {0}")]
pub struct ThemeNotFoundError(pub SharedString);

#[derive(Debug, Error)]
#[error("icon tema bulunamadı: {0}")]
pub struct IconThemeNotFoundError(pub SharedString);
```

- `thiserror` `Display + std::error::Error` derive eder.
- Tek alanlı newtype — hata mesajı `"tema bulunamadı: Kvs Default Dark"`.
- Hata propagation kolay: `?` operatörü ile `anyhow::Result<...>` veya
  başka error chain'e dönüşebilir.

> **Eski rehber sürümünde `ThemeNotFound` / `IconThemeNotFound` (suffix
> olmadan) kullanılıyordu — yanlış.** Zed pariteli isim `Error` suffix'li.

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

Zed'in `crates/theme/src/registry.rs` dosyasındaki public yüzeye birebir
paralel. Önemli üç davranış farkı yorum satırlarında belirtildi:

```rust
impl ThemeRegistry {
    // KONSTRUKTOR: tek imza, AssetSource ZORUNLU.
    // `ThemeRegistry::new()` (argümansız) yok; testte
    // `Box::new(()) as Box<dyn AssetSource>` geçirilir.
    pub fn new(assets: Box<dyn AssetSource>) -> Self;

    pub fn global(cx: &App) -> Arc<Self>;
    pub fn default_global(cx: &mut App) -> Arc<Self>;
    pub fn try_global(cx: &mut App) -> Option<Arc<Self>>;

    // `set_global` Zed'de `pub(crate)`; `init()` içinde çağrılır.
    // Tüketici doğrudan değiştiremez — global'i kurmak için
    // `init(LoadThemes::..., cx)` kullanın (Konu 30).
    pub(crate) fn set_global(assets: Box<dyn AssetSource>, cx: &mut App);

    pub fn assets(&self) -> &dyn AssetSource;

    // TEK TEK Theme insert eden public API YOK.
    // Tek tema yüklemek için tek elemanlı koleksiyon geçirilir:
    //   registry.insert_themes([theme]);
    pub fn insert_theme_families(&self, families: impl IntoIterator<Item = ThemeFamily>);
    pub fn insert_themes(&self, themes: impl IntoIterator<Item = Theme>);
    pub fn remove_user_themes(&self, names: &[SharedString]);
    pub fn clear(&self);
    pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError>;
    pub fn list_names(&self) -> Vec<SharedString>;
    pub fn list(&self) -> Vec<ThemeMeta>;

    // Tek tek IconTheme insert eden public API DA YOK.
    // `load_icon_theme(family, root_dir)` aileden ekler;
    // `register_test_icon_themes` test-only.
    pub fn get_icon_theme(&self, name: &str) -> Result<Arc<IconTheme>, IconThemeNotFoundError>;
    pub fn default_icon_theme(&self) -> Result<Arc<IconTheme>, IconThemeNotFoundError>;
    pub fn list_icon_themes(&self) -> Vec<ThemeMeta>;
    pub fn remove_icon_themes(&self, names: &[SharedString]);
    pub fn load_icon_theme(
        &self,
        family: IconThemeFamilyContent,
        icons_root_dir: &Path,
    ) -> anyhow::Result<()>;

    pub fn extensions_loaded(&self) -> bool;
    pub fn set_extensions_loaded(&self);

    #[cfg(any(test, feature = "test-support"))]
    pub fn register_test_themes(&self, families: impl IntoIterator<Item = ThemeFamily>);
    #[cfg(any(test, feature = "test-support"))]
    pub fn register_test_icon_themes(&self, icon_themes: impl IntoIterator<Item = IconTheme>);
}
```

> **`ThemeRegistry::new` davranış notu:** Yapıcı kendi içinde
> `insert_theme_families([zed_default_themes()])` çağırır ve default icon
> theme'i de ekler. Yani `new` ile dönen registry hiçbir zaman tamamen
> boş değildir; mirror'da `kvs_default_themes()` ailesi otomatik
> yüklenmelidir.

**Her method'un davranışı:**

| Method | İmza | Davranış | Lock |
|--------|------|----------|------|
| `new` | `(assets: Box<dyn AssetSource>) -> Self` | `zed_default_themes()` ailesini ve default icon tema'yı yükleyerek registry kurar; asset zorunlu | Yok |
| `global` | `(cx: &App) -> Arc<Self>` | Aktif registry'yi döner; yoksa **panic** | App global okuma |
| `default_global` | `(cx: &mut App) -> Arc<Self>` | Yoksa default registry kurup döner | App global yazma |
| `try_global` | `(cx: &mut App) -> Option<Arc<Self>>` | Init edilmemişse `None` | App global okuma |
| `set_global` | `(assets, cx) -> ()` — `pub(crate)` | `init(...)` çağrısı içinden global'i kurar; tüketici çağıramaz | App global yazma |
| `insert_themes` | `(&self, themes)` | Her temayı `name` key'i ile ekler; aynı isimde varsa **üzerine yazar** | Write |
| `insert_theme_families` | `(&self, families)` | Ailelerdeki tüm temaları `insert_themes` ile ekler | Write |
| `remove_user_themes` | `(&self, names)` | Verilen ad listesindeki temaları kaldırır | Write |
| `clear` | `(&self)` | Tüm UI temalarını siler (icon temalar etkilenmez) | Write |
| `get` | `(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError>` | Tema'yı clone'lar (Arc); yoksa hata | Read |
| `list_names` | `(&self) -> Vec<SharedString>` | Tüm tema adlarını sıralı liste olarak döner | Read |
| `list` | `(&self) -> Vec<ThemeMeta>` | Selector için ad + appearance metadata'sı döner | Read |
| `get_icon_theme` | `(&self, name)` | Icon tema lookup | Read |
| `default_icon_theme` | `(&self)` | Default icon tema; yoksa `IconThemeNotFoundError` | Read |
| `list_icon_themes` | `(&self) -> Vec<ThemeMeta>` | Icon selector için metadata | Read |
| `load_icon_theme` | `(family, root)` | Icon path'lerini root'a göre çözerek ekler | Write |
| `extensions_loaded` | `() -> bool` | Extension temaları yüklendi mi bilgisi | Read |
| `register_test_themes` / `register_test_icon_themes` | `(&self, ...)` — `#[cfg(test-support)]` | Test feature'ı altında family/icon kayıtları | Write |

#### Davranış detayları

**`insert_themes` üzerine yazma:**

```rust
pub fn insert_themes(&self, themes: impl IntoIterator<Item = Theme>) {
    let mut state = self.state.write();
    for theme in themes.into_iter() {
        state.themes.insert(theme.name.clone(), Arc::new(theme));
    }
}
```

`HashMap::insert` aynı key varsa eski değeri **drop eder**. Kullanıcı
"My Theme" adıyla iki tema yükledi → ikincisi birinciyi siler. Bu
davranış **kasıtlı** — kullanıcının "tema güncelleme" reflexi (aynı
adla yeniden yükleme).

> Tek tema yüklemek için tek elemanlı koleksiyon geçirilir:
> `registry.insert_themes([theme]);` veya `registry.insert_themes(std::iter::once(theme));`.
> Zed'de tek tema için ayrı bir `insert(theme)` metodu yoktur; eski rehber
> sürümü bu metodu yanlış belgelemişti.

**`get` clone semantiği:**

```rust
pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError> {
    self.state
        .read()
        .themes
        .get(name)
        .cloned()    // Arc<Theme> → ucuz klon
        .ok_or_else(|| ThemeNotFoundError(name.to_string().into()))
}
```

`cloned()` `Arc<Theme>`'i clone'lar — sadece refcount artırır. Caller
kendi `Arc<Theme>` instance'ına sahip olur; registry'nin storage'ı
bağımsız.

**`list_names` sıralama:**

```rust
pub fn list_names(&self) -> Vec<SharedString> {
    let mut names: Vec<_> = self.state.read().themes.keys().cloned().collect();
    names.sort();
    names
}
```

`HashMap` sırasız; `sort()` deterministik liste sunar. UI'da tema
seçici dropdown'u alfabetik sıralı görünür. Picker/selector ad yanında
appearance da gösterecekse `list()` kullanır.

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
> olarak al, lock düşür, sonra `GlobalTheme::update_theme(...)` çağır.
> Mevcut API zaten bu deseni teşvik ediyor.

#### Zed uyumlu tamamlanmış API

Zed-benzeri selector/settings/icon-theme akışı isteniyorsa aşağıdaki
metodlar opsiyonel değil, public runtime sözleşmesidir:

| Metod | Gerekçe |
|-------|---------|
| `default_global`, `try_global` | Init/test ve lazy setup akışları. |
| `insert_theme_families` | Built-in, user ve extension temalarını aile halinde eklemek. |
| `remove_user_themes` | Kullanıcı tema dizini yeniden tarandığında eski kullanıcı temalarını temizlemek. |
| `list` (`ThemeMeta`) | Selector/picker için ad + appearance metadata'sı. |
| `assets()` | Built-in tema, icon, SVG ve lisans dosyalarını tek asset kaynağından yüklemek. |
| `list_icon_themes`, `get_icon_theme`, `load_icon_theme` | Icon theme selector ve aktif icon theme reload akışı. |
| `remove_icon_themes` | Extension/user icon theme yenileme. |
| `extensions_loaded`, `set_extensions_loaded` | Extension temaları gelmeden önce fallback'e sessiz düşme, geldikten sonra gerçek hata loglama. |

Bu metodlardan birini bilinçli olarak dışlarsan `tema_aktarimi.md`
"Senkron edilMEYEN" bölümüne yaz. "Şimdilik UI yok" dışlama gerekçesi
değildir; selector UI sonra gelse bile registry sözleşmesi hazır olmalı.

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
6. **Registry boş başlatmak ama aktif tema set etmemek**: registry
   `set_global` sonrası `cx.set_global(GlobalTheme::new(default, default_icon))`
   çağrısı şart. Aksi halde `cx.theme()` veya `GlobalTheme::icon_theme(cx)`
   panic eder.

---

### 28. `GlobalTheme` ve `ActiveTheme` trait

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`GlobalTheme` aktif UI temasını ve aktif icon temasını taşıyan global.
`ActiveTheme` trait'i Zed'de yalnızca `cx.theme()` ergonomisini sağlar.
Icon tema ayrı registry'de tutulsa bile aktif seçim aynı global
altında saklanır; böylece settings değişiminde UI ve icon refresh aynı
akıştan geçer.

#### `GlobalTheme` yapısı

```rust
use gpui::{App, BorrowAppContext, Global};
use std::sync::Arc;

pub struct GlobalTheme {
    theme: Arc<Theme>,
    icon_theme: Arc<IconTheme>,
}
impl Global for GlobalTheme {}
```

`Theme` ve `IconTheme` doğrudan global yapılmaz; newtype wrapper
(Bölüm II/Konu 10 kuralı). Alanlar private — dışarıdan
`theme`/`icon_theme` ve update metotlarıyla erişilir.

#### `GlobalTheme` API

```rust
impl GlobalTheme {
    pub fn new(theme: Arc<Theme>, icon_theme: Arc<IconTheme>) -> Self {
        Self { theme, icon_theme }
    }

    pub fn theme(cx: &App) -> &Arc<Theme> {
        &cx.global::<Self>().theme
    }

    pub fn icon_theme(cx: &App) -> &Arc<IconTheme> {
        &cx.global::<Self>().icon_theme
    }

    pub fn update_theme(cx: &mut App, theme: Arc<Theme>) {
        cx.update_global::<Self, _>(|this, _| this.theme = theme);
    }

    pub fn update_icon_theme(cx: &mut App, icon_theme: Arc<IconTheme>) {
        cx.update_global::<Self, _>(|this, _| this.icon_theme = icon_theme);
    }
}
```

**`theme(cx)`:**

- `cx.global::<Self>()` global'i okur; yoksa panic.
- `&Arc<Theme>` döner — clone'a gerek yok; caller refcount artırmadan
  okur.

**`icon_theme(cx)`:**

- Aktif icon tema'yı döner.
- File tree, picker, tabs ve explorer icon çözümü bu değeri okur.

**İlk kurulum:**

- Zed public API'de `set_theme_and_icon` metodu yoktur.
- `init` sırasında `cx.set_global(GlobalTheme::new(theme, icon_theme))`
  çağrılır.
- Global ilk kez kurulurken iki aktif değer de hazır olmalıdır.

**`update_theme` / `update_icon_theme`:**

`init-or-update` deseni (Bölüm II/Konu 10):

- `init` global'i `GlobalTheme::new` + `cx.set_global` ile kurar.
- Sonraki değişimler `update_global` ile yapılır — mevcut instance mutate edilir,
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

`kvs_tema` isterse yerel convenience metotları ekleyebilir; bunlar Zed
public yüzeyinde olmadığı için `DECISIONS.md`'de yerel genişletme olarak
işaretlenir. Önerilen adlandırma:

| Yerel ad | Davranış | Neden bu ad |
|----------|----------|-------------|
| `install_or_update_theme(cx, theme)` | `has_global`'a göre `set_global` veya `update_theme` çağırır | `set_theme` adı `theme_settings::settings::set_theme` (Konu 31) ile çakışır — namespace karışıklığı bug çıkarır |
| `install_or_update_icon_theme(cx, icon)` | Aynı desen, icon tarafı | Aynı gerekçe |
| `install_active(cx, theme, icon)` | `cx.set_global(GlobalTheme::new(...))` çağrısının okunabilir alias'ı | İlk init'i tek satıra indirir |

Init öncesinde `GlobalTheme::update_theme` ya da bu yerel sarmalayıcılar
çağrılırsa global yokluğu nedeniyle panic eder.

#### `ActiveTheme` trait

**Zed kaynak sözleşmesi** (`crates/theme/src/theme.rs:119`):

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

**Önemli sözleşme notu:** Zed'de `ActiveTheme` trait'i **yalnızca**
`theme()` metoduna sahiptir; `icon_theme()` trait'in parçası **değildir**.
Aktif icon tema'ya erişim `GlobalTheme::icon_theme(cx)` üzerinden
yapılır — `cx.icon_theme()` Zed paritesinde doğrudan çalışmaz.

**`kvs_tema` için iki seçenek:**

1. **Paritede kal** — trait'i Zed gibi tek metotlu tut; icon tema'ya
   `GlobalTheme::icon_theme(cx)` veya bağımsız `IconActiveTheme` trait
   üzerinden eriş:

   ```rust
   pub trait ActiveTheme {
       fn theme(&self) -> &Arc<Theme>;
   }

   pub trait IconActiveTheme {
       fn icon_theme(&self) -> &Arc<IconTheme>;
   }

   impl ActiveTheme for App {
       fn theme(&self) -> &Arc<Theme> { GlobalTheme::theme(self) }
   }
   impl IconActiveTheme for App {
       fn icon_theme(&self) -> &Arc<IconTheme> { GlobalTheme::icon_theme(self) }
   }
   ```

2. **`kvs_tema` ek metot olarak `icon_theme` koy** — Zed paritesini
   genişletmek anlamına gelir; `DECISIONS.md`'ye "trait'i iki metotla
   genişlettik, Zed'de tek metotlu" notu düşülmelidir.

Rehberin örnekleri Seçenek 1'i varsayar; aktif icon tema için
`GlobalTheme::icon_theme(cx)` kullanılır. Seçenek 2 uygulanırsa ilgili
çağrılar `cx.icon_theme()` olarak kısaltılabilir.

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
        let _icons = GlobalTheme::icon_theme(cx); // &Arc<IconTheme>
        div()
            .bg(tema.colors().background)
            .text_color(tema.colors().text)
    }
}
```

`use kvs_tema::ActiveTheme;` zorunlu — trait method'u görünür olmaz
import olmadan. Tipik pattern: prelude module ekle.

```rust
// kvs_tema/src/prelude.rs (opsiyonel)
pub use crate::runtime::ActiveTheme;
pub use crate::Theme;
pub use crate::IconTheme;
```

```rust
use kvs_tema::prelude::*;  // tek satırlık import
```

#### Accessor metotları

`styles` alanı crate-içi olduğu için tüketicinin kararlı okuma yolu
Konu 12'deki accessor'lardır:

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

Icon okuma:

```rust
let path = kvs_tema::icon_for_file("Cargo.toml", GlobalTheme::icon_theme(cx));
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
çiziyor; explicit observer çoğu zaman gereksiz. Sadece tema veya icon
tema değişiminde özel state güncellemek istiyorsan kur.

#### Tuzaklar

1. **`theme(&Arc<Theme>)` clone**: `cx.theme()` zaten `&Arc<Theme>`
   döndürüyor; üzerinde `.clone()` çağırırsan gereksiz refcount artışı.
   `let tema = cx.theme();` direkt yeterli.
2. **`use kvs_tema::ActiveTheme` unutmak**: Trait import edilmemişse
   `cx.theme()` "method not found" hatası. Prelude kullan.
3. **Global'i icon temasız kurmak**: Aktif icon tema yoksa explorer
   render'ı fallback path üretemez. `init` içinde default icon tema'yı
   mutlaka kur.
4. **`update_theme` callback boş**: `update_global::<Self, _>(|this, _| ...)`
   callback'inde sadece field mutate et; başka global'i set etmeye
   çalışırsan re-entrancy panic.
5. **Theme parametresini `Theme` yapmak**: `update_theme(cx, theme: Theme)`
   yazsaydın her çağrıda klon olurdu. `Arc<Theme>` zorunlu.
6. **`observe_global` `.detach()` unutmak**: Subscription drop olursa
   observer ölür; tema değişince bileşen yenilenmez.

---

### 29. `SystemAppearance` ve sistem mod takibi

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

OS'un light/dark mod tercihini taşır. Tema seçim mantığı bunu okur ve
uygun varyantı yükler.

#### Yapı

**Zed kaynak sözleşmesi** (`crates/theme/src/theme.rs:132`):

```rust
#[derive(Debug, Clone, Copy)]
pub struct SystemAppearance(pub Appearance);

impl Default for SystemAppearance {
    fn default() -> Self {
        Self(Appearance::Dark)
    }
}

impl std::ops::Deref for SystemAppearance {
    type Target = Appearance;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

#[derive(Default)]
struct GlobalSystemAppearance(SystemAppearance);

impl std::ops::Deref for GlobalSystemAppearance {
    type Target = SystemAppearance;
    fn deref(&self) -> &Self::Target { &self.0 }
}

impl std::ops::DerefMut for GlobalSystemAppearance {
    fn deref_mut(&mut self) -> &mut Self::Target { &mut self.0 }
}

impl Global for GlobalSystemAppearance {}
```

- `SystemAppearance(pub Appearance)` — `Appearance` (Bölüm III/Konu 16)
  newtype'ı; `Default` `Self(Appearance::Dark)` döner.
- `Deref<Target = Appearance>` impl'i sayesinde `system.is_light()` gibi
  Appearance metotları doğrudan çalışır — `.0` patlatmaya gerek yok.
- `Copy` çünkü `Appearance` `Copy`. Ucuz değer-geçirim.
- `GlobalSystemAppearance` `Default` türetir ve `Deref/DerefMut` ile
  newtype'ı tutucu olarak şeffaflaştırır.

> **Neden `Appearance` doğrudan global değil?** `Appearance` enum'u
> başka anlamlarda da kullanılır (tema'nın nominal modu, JSON deserialize
> hedefi). Global anahtarı **sistem-spesifik** kalsın: `SystemAppearance`
> sadece "OS şu an ne diyor?" sorusunu cevaplar.

#### API

```rust
impl SystemAppearance {
    /// Bağlamda yoksa default kurar; varsa pencere mevcut görünümünden
    /// günceller. Zed paritesi `default_global` + `From<WindowAppearance>`
    /// üzerinden çalışır.
    pub fn init(cx: &mut App) {
        *cx.default_global::<GlobalSystemAppearance>() =
            GlobalSystemAppearance(SystemAppearance(cx.window_appearance().into()));
    }

    /// Aktif sistem görünümünü döner; yoksa panic eder.
    pub fn global(cx: &App) -> Self {
        cx.global::<GlobalSystemAppearance>().0
    }

    /// Sistem görünümünü mutate etmek için. Pencere event'i veya test
    /// kurulumunda kullanılır.
    pub fn global_mut(cx: &mut App) -> &mut Self {
        cx.global_mut::<GlobalSystemAppearance>()
    }
}
```

> **`init` `default_global` ile çalışır:** `set_global` yerine
> `default_global` kullanıldığında, bağlamda global yoksa
> `Default::default()` (yani `SystemAppearance(Appearance::Dark)`)
> oluşturulup üstüne yazılır. İkinci `init` çağrısı eski global'i drop
> etmek yerine mevcut yerinde günceller — observer'lar tetiklenir.

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

#### Sistem mod değişimini izleme (public API)

`init` sadece **başlangıçta** çağrılır. OS theme değişimini takip etmek
için observer şart; ama observer kurmak `Window` referansı ister ve
`init` `&mut App` aldığı için bunu içeride yapamaz. Tüketici pencere
açıldıktan sonra ayrı bir public fonksiyon çağırır:

```rust
// kvs_tema/src/runtime.rs — public API
pub fn observe_system_appearance<V: 'static>(
    window: &mut Window,
    cx: &mut Context<V>,
) {
    cx.observe_window_appearance(window, |_, window, cx| {
        let new_appearance = match window.appearance() {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
        };

        // SystemAppearance global'ini güncelle
        cx.set_global(GlobalSystemAppearance(SystemAppearance(new_appearance)));

        // Tüketici tema değişimini de istiyorsa observe_global ile
        // ayrı subscribe eder; bu fonksiyon sadece sistem mod'unu
        // raporlar (politika kullanıcıya bırakılır).
    }).detach();
}
```

**Çağrı yeri — pencere açma callback'i:**

```rust
fn main() {
    Application::new().run(|cx| {
        kvs_tema::init(cx);   // Adım 1: SystemAppearance::init burada

        cx.open_window(WindowOptions::default(), |window, cx| {
            cx.new(|cx| {
                // Adım 2: pencere açıldıktan sonra observer kur
                kvs_tema::observe_system_appearance(window, cx);
                AnaPanel
            })
        }).unwrap();
    });
}
```

**İki adımlı kuruluşun gerekçesi:**

- **Adım 1 (`init`)**: Sistem mod'unun **anlık değerini** yakalar
  (`cx.window_appearance()` `&App` üzerinden çalışır).
- **Adım 2 (`observe_system_appearance`)**: Mod **değişimini** dinler
  (`cx.observe_window_appearance` `Window` ister).

Tüketici Adım 2'yi atlayabilir — sistem mod'u "set once" olarak kalır
ve uygulama yaşadığı sürece ilk değerinde donar. Bu kasıtlı bir seçim
olabilir; ama otomatik tema takibi isteniyorsa observer şart.

> **`.detach()` zorunlu:** `cx.observe_window_appearance` `Subscription`
> döner; drop edilirse observer ölür (Bölüm II/Konu 10 tuzak 5).
> `observe_system_appearance` fonksiyonu zaten `.detach()` çağırır;
> tüketicinin elle çağırmasına gerek yok.

#### Sistem'den tema seçme örneği

`SystemAppearance` okuyup uygun temayı yüklemek:

```rust
pub fn sistemden_tema_sec(cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let ad = match SystemAppearance::global(cx).0 {
        Appearance::Dark => "Kvs Default Dark",
        Appearance::Light => "Kvs Default Light",
    };
    GlobalTheme::update_theme(cx, registry.get(ad)?);
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
5. **`SystemAppearance::global(cx)` init'siz erişim panic**: Zed'de
   `SystemAppearance` `Default` (`Appearance::Dark`) türetir; ama
   `global(cx)` `cx.global::<...>` çağırdığı için bağlamda kayıt yoksa
   panic eder. `default_global(cx)` veya `init(cx)` ile önce kurun.
   Init sırası `init()` fonksiyonu içinde garantili.

---

### 30. `init()`: kuruluş sırası ve fallback yükleme

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`kvs_tema::init(cx)` — runtime'ın **tek giriş noktası**. Uygulamanın
başında, pencere açılmadan **mutlaka** çağrılır.

#### Tam kod

`kvs_tema::init` Zed paritesi için `LoadThemes` enum'unu alır (Konu
43.1):

```rust
pub fn init(themes_to_load: LoadThemes, cx: &mut App) {
    SystemAppearance::init(cx);

    let assets: Box<dyn AssetSource> = match themes_to_load {
        LoadThemes::JustBase => Box::new(()),
        LoadThemes::All(assets) => assets,
    };

    // `ThemeRegistry::new(assets)` zed_default_themes ailesini ve
    // default icon tema'yı kendi içinde yükler.
    let registry = Arc::new(ThemeRegistry::new(assets));
    registry.insert_themes([
        crate::fallback::kvs_default_dark(),
        crate::fallback::kvs_default_light(),
    ]);

    let default = registry
        .get("Kvs Default Dark")
        .expect("default tema kayıtlı olmalı");
    let default_icon = registry
        .default_icon_theme()
        .expect("default icon tema kayıtlı olmalı");

    // `ThemeRegistry::set_global` Zed'de `pub(crate)`. `kvs_tema`'da
    // mirror'da public yaparsan tüketici tarafa açık olur; aksi halde
    // global'i yalnızca bu `init` fonksiyonu kurar.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(default, default_icon));
}
```

#### 5 adımlı kuruluş

**Adım 1 — `SystemAppearance::init(cx)`:**

Sistem mod sorgulanır ve global kurulur. **İlk** adım çünkü bundan
sonraki adımlar isterse sistem mod'una bakabilir (`init` sırasında değil
ama observer eklenirken).

**Adım 2 — Registry yaratma:**

```rust
let registry = Arc::new(ThemeRegistry::new(assets));
```

`Arc` çünkü global'e konacak. `ThemeRegistry::new(assets)` `AssetSource`
zorunlu alır; testte `Box::new(()) as Box<dyn AssetSource>` geçirilir.
Yapıcı zaten içinde `insert_theme_families([zed_default_themes()])`
çağırır ve default icon tema'yı ekler — yani `new` ile dönen registry
hiç boş değildir.

**Adım 3 — Fallback temaları insert:**

```rust
registry.insert_themes([
    crate::fallback::kvs_default_dark(),
    crate::fallback::kvs_default_light(),
]);
```

İki "default" tema her zaman registry'de. Sebebi:

- Kullanıcı tema yükleme akışı bozulursa bile **uygulama yine çalışır**.
- `cx.theme()` ve `GlobalTheme::icon_theme(cx)` panic edemez; her zaman geçerli tema olur.
- Sistem light/dark mod değişiminde her zaman bir hedef tema var.

**Adım 4 — Default seçimi:**

```rust
let default = registry
    .get("Kvs Default Dark")
    .expect("default tema kayıtlı olmalı");
let default_icon = registry
    .default_icon_theme()
    .expect("default icon tema kayıtlı olmalı");
```

`.expect()` kullanımı kasıtlı — bu **mantıksal invariant**: az önce
UI fallback temalarını insert ettik ve registry default icon tema'yı
kurdu; eksik olamaz. Eksikse programatik hata (typo veya init bug'ı);
panic acceptable.

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
// ThemeRegistry::set_global Zed'de pub(crate) ve Box<dyn AssetSource>
// alır (içeride GlobalThemeRegistry newtype'ını oluşturur). Mirror tarafta
// newtype'ı kendin set ederek aynı sözleşmeyi kuruyorsun.
cx.set_global(GlobalThemeRegistry(registry.clone()));
cx.set_global(GlobalTheme::new(default, default_icon));
```

Sıra önemli: önce registry global kurulur, sonra aktif UI tema + aktif
icon tema aynı `GlobalTheme` içinde kurulur. `cx.theme()` ve
`GlobalTheme::icon_theme(cx)` bundan sonra güvenlidir.

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
            window_background: cx.theme().window_background_appearance(),
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
| `kvs_tema::init` çağrılmadan `cx.theme()` / `GlobalTheme::icon_theme(cx)` | Panic: "global not found" | Init'i ilk satıra koy |

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
                let themes: Vec<Theme> = family
                    .themes
                    .into_iter()
                    .map(|tc| Theme::from_content(tc, &baseline))
                    .collect();
                registry.insert_themes(themes);
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
    GlobalTheme::update_theme(cx, yeni); // 2. Global güncelle
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

- `registry.get(ad)` `Result<Arc<Theme>, ThemeNotFoundError>` döner.
- `?` operatörü hatayı caller'a propagate eder.
- Tema bulunamazsa `ThemeNotFoundError` döner — caller bunu loglar veya
  UI'da gösterir (toast: "Tema bulunamadı: X").

**Adım 2 — Global update:**

```rust
GlobalTheme::update_theme(cx, yeni);
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
pub fn temayi_degistir(ad: &str, cx: &mut App) -> Result<(), ThemeNotFoundError> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;
    GlobalTheme::update_theme(cx, yeni);
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

#### Settings / override / selector köprüsü

Zed-benzeri kontrol için tek bir `ad: String` yeterli değildir. Minimum
settings modeli şu dört özelliği taşır:

1. **Static seçim:** Tek tema adı her modda kullanılır.
2. **Dynamic seçim:** `mode + light + dark`; `mode=system` ise OS modu
   hangi adı seçeceğini belirler.
3. **Aktif tema override'ı:** Geçerli temanın üstüne geçici/deneysel
   `ThemeStyleContent` uygulanır.
4. **Tema bazlı override:** Belirli tema adına özel override map'i.

Zed'e denk settings sözleşmesi:

```rust
use std::{collections::HashMap, sync::Arc};

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(transparent)]
pub struct ThemeName(pub Arc<str>);

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(transparent)]
pub struct IconThemeName(pub Arc<str>);

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ThemeAppearanceMode {
    Light,
    Dark,
    #[default]
    System,
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(untagged)]
pub enum ThemeSelection {
    Static(ThemeName),
    Dynamic {
        #[serde(default)]
        mode: ThemeAppearanceMode,
        light: ThemeName,
        dark: ThemeName,
    },
}

#[derive(Clone, Debug, serde::Serialize, serde::Deserialize)]
#[serde(untagged)]
pub enum IconThemeSelection {
    Static(IconThemeName),
    Dynamic {
        #[serde(default)]
        mode: ThemeAppearanceMode,
        light: IconThemeName,
        dark: IconThemeName,
    },
}

pub const DEFAULT_LIGHT_THEME: &str = "One Light";
pub const DEFAULT_DARK_THEME: &str = "One Dark";

#[derive(Clone, Debug, Default, serde::Serialize, serde::Deserialize)]
#[serde(default)]
pub struct ThemeSettingsContent {
    // Font ve typography alanları Konu 43.2'de listelenir.
    pub theme: Option<ThemeSelection>,
    pub icon_theme: Option<IconThemeSelection>,

    #[serde(rename = "experimental.theme_overrides")]
    pub experimental_theme_overrides: Option<ThemeStyleContent>,

    pub theme_overrides: HashMap<String, ThemeStyleContent>,
}
```

Örnek kullanıcı config'i:

```jsonc
{
  "theme": {
    "mode": "system",
    "light": "One Light",
    "dark": "One Dark"
  },
  "icon_theme": {
    "mode": "system",
    "light": "Material Light",
    "dark": "Material Dark"
  },
  "experimental.theme_overrides": {
    "background": "#101216ff",
    "text": "#e6e8ebff"
  },
  "theme_overrides": {
    "One Dark": {
      "editor.active_line.background": "#222631ff"
    }
  }
}
```

Selection çözümleme fonksiyonları:

```rust
impl ThemeSelection {
    pub fn name(&self, system: Appearance) -> ThemeName {
        match self {
            Self::Static(name) => name.clone(),
            Self::Dynamic { mode, light, dark } => match mode {
                ThemeAppearanceMode::Light => light.clone(),
                ThemeAppearanceMode::Dark => dark.clone(),
                ThemeAppearanceMode::System => match system {
                    Appearance::Light => light.clone(),
                    Appearance::Dark => dark.clone(),
                },
            },
        }
    }

    pub fn mode(&self) -> Option<ThemeAppearanceMode> {
        match self {
            Self::Static(_) => None,
            Self::Dynamic { mode, .. } => Some(*mode),
        }
    }
}

impl IconThemeSelection {
    pub fn name(&self, system: Appearance) -> IconThemeName {
        match self {
            Self::Static(name) => name.clone(),
            Self::Dynamic { mode, light, dark } => match mode {
                ThemeAppearanceMode::Light => light.clone(),
                ThemeAppearanceMode::Dark => dark.clone(),
                ThemeAppearanceMode::System => match system {
                    Appearance::Light => light.clone(),
                    Appearance::Dark => dark.clone(),
                },
            },
        }
    }

    pub fn mode(&self) -> Option<ThemeAppearanceMode> {
        match self {
            Self::Static(_) => None,
            Self::Dynamic { mode, .. } => Some(*mode),
        }
    }
}
```

Tema uygulama akışı:

```rust
pub fn configured_theme(settings: &ThemeSettingsContent, cx: &mut App) -> Arc<Theme> {
    let registry = ThemeRegistry::global(cx);
    let system = SystemAppearance::global(cx).0;
    let selection = settings.theme.clone().unwrap_or_else(default_theme_selection);
    let name = selection.name(system);

    let mut theme = registry
        .get(&name.0)
        .or_else(|_| registry.get(default_theme_name(system)))
        .unwrap_or_else(|_| registry.get("Kvs Default Dark").unwrap());

    theme = apply_theme_overrides(theme, settings);
    theme
}

pub fn apply_theme_overrides(
    mut theme: Arc<Theme>,
    settings: &ThemeSettingsContent,
) -> Arc<Theme> {
    if let Some(overrides) = &settings.experimental_theme_overrides {
        let mut clone = (*theme).clone();
        modify_theme(&mut clone, overrides);
        theme = Arc::new(clone);
    }

    if let Some(overrides) = settings.theme_overrides.get(theme.name.as_ref()) {
        let mut clone = (*theme).clone();
        modify_theme(&mut clone, overrides);
        theme = Arc::new(clone);
    }

    theme
}
```

`modify_theme` aynı `Theme::from_content` refinement araçlarını kullanır:
`window_background_appearance` override edilir, `status_colors_refinement`
ve `theme_colors_refinement` uygulanır, player/accent listeleri merge
edilir, syntax override'ları mevcut syntax üstüne bindirilir. Override
işlemi registry'deki orijinal `Arc<Theme>`'i değiştirmez; clone üstünde
çalışır.

Settings observer:

```rust
pub fn observe_tema_ayarlari(cx: &mut App) {
    let mut prev_theme_name = current_theme_name(cx);
    let mut prev_icon_theme_name = current_icon_theme_name(cx);
    let mut prev_overrides = current_theme_overrides(cx);

    cx.observe_global::<AyarStore>(move |cx| {
        let theme_name = current_theme_name(cx);
        let icon_theme_name = current_icon_theme_name(cx);
        let overrides = current_theme_overrides(cx);

        if theme_name != prev_theme_name || overrides != prev_overrides {
            prev_theme_name = theme_name;
            prev_overrides = overrides;
            reload_theme_from_settings(cx);
        }

        if icon_theme_name != prev_icon_theme_name {
            prev_icon_theme_name = icon_theme_name;
            reload_icon_theme_from_settings(cx);
        }
    }).detach();
}
```

Tema seçici davranışı:

```text
liste kaynağı:
  ThemeRegistry::list() -> Vec<ThemeMeta { name, appearance }>

preview:
  seçici içinde highlight değişince GlobalTheme::update_theme ile
  geçici tema uygulanır, refresh_windows çağrılır

confirm:
  settings dosyası ThemeSelection olarak güncellenir:
    - Static ise seçilen ad tek değer olur
    - Dynamic ise seçilen temanın appearance'ına göre light/dark slot'u güncellenir
    - mode=system ve seçilen tema sistem görünümünden farklıysa mode light/dark'a çekilir

dismiss/cancel:
  açılıştaki tema adı saklanır; seçici kapanınca confirm edilmediyse
  eski tema geri yüklenir ve refresh_windows çağrılır
```

Bu modelle uygulama, Zed'deki gibi kullanıcıya hem "tek tema seç" hem de
"sistem moduna göre light/dark temaları ayrı tut" davranışını sunar.

#### Settings mutator helper'ları (Zed paritesi)

Zed `crates/theme_settings/src/settings.rs` içinde **runtime global'i değil**,
kullanıcı ayar dosyasının `SettingsContent` AST'ini güvenli mutate eden üç
public helper sunar:

```rust
// theme_settings::settings içinde:
pub fn set_theme(
    current: &mut SettingsContent,
    theme_name: impl Into<Arc<str>>,
    theme_appearance: Appearance,
    system_appearance: Appearance,
);

pub fn set_icon_theme(
    current: &mut SettingsContent,
    icon_theme_name: IconThemeName,
    appearance: Appearance,
);

pub fn set_mode(content: &mut SettingsContent, mode: ThemeAppearanceMode);
```

| Fonksiyon | İş yaptığı yer | Karar mantığı |
|-----------|----------------|---------------|
| `set_theme` | `settings.theme.theme` (`Option<ThemeSelection>`) | `Static` ise adı değiştirir, `Dynamic` ise `theme_appearance`'a göre `light`/`dark` slot'unu günceller. `mode == System` iken seçilen appearance sistem appearance'ından farklıysa `mode`'u seçilen tarafa kilitler |
| `set_icon_theme` | `settings.theme.icon_theme` | `Dynamic` modda mevcut mode'a göre `light`/`dark` slot'unu yazar; `Static`ta tek slot'u günceller. `Option<IconThemeSelection>` `None` ise `Static` ile başlatır |
| `set_mode` | `settings.theme.theme` | Mevcut `Static` seçimi `Dynamic { mode = System, light = DEFAULT_LIGHT_THEME, dark = DEFAULT_DARK_THEME }` ile değiştirir; mevcut `Dynamic` ise sadece `mode`'u günceller; `None` ise `Dynamic`'i baştan kurar |

**`kvs_tema` karşılığı:** Bu üç fonksiyon `kvs_tema` runtime API'sinin değil
selector / settings UI köprüsünün sorumluluğudur. Mirror crate yapısında
ya `kvs_tema_ayarlari` ya da `kvs_secici` modülünde tutulur. Selector
confirm akışında dosya yazma sırasını şu şekilde kurar:

```rust
pub fn confirm_selection(
    secilen: &ThemeMeta,
    cx: &mut App,
) -> anyhow::Result<()> {
    let system = SystemAppearance::global(cx).0;

    // 1. Önce in-memory SettingsContent'i mutate et.
    let mut content = SettingsStore::global(cx).user_settings_content().clone();
    set_theme(&mut content, secilen.name.clone(), secilen.appearance, system);

    // 2. Diske persist et (file watcher Konu 33 ile reload'u tetikler).
    SettingsStore::global(cx).write_user_settings(content)?;

    // 3. Observer (Konu 31) reload_theme'i çağırır; explicit
    //    GlobalTheme::update_theme + refresh_windows burada GEREKMEZ.
    Ok(())
}
```

**Tuzak:** Selector preview için `GlobalTheme::update_theme` + `refresh_windows`
çağrıldıysa ve kullanıcı confirm yerine dismiss seçerse, settings dosyası
yazılmamış olur ama runtime hâlâ önizleme temasını gösterir. Cancel akışında
preview öncesi tema adını saklayıp `GlobalTheme::update_theme(cx, eski)`
çağrısı yapılmalıdır.

#### `reload_theme` / `reload_icon_theme` — observer reaksiyonu

Zed `crates/theme_settings/src/theme_settings.rs` içinde iki public reload
helper'ı tanımlar:

```rust
pub fn reload_theme(cx: &mut App);
pub fn reload_icon_theme(cx: &mut App);
```

Davranış (`theme_settings.rs:185-196`):

1. `configured_theme(cx)` (veya `configured_icon_theme(cx)`) ile aktif
   seçimi ve override'ları yeniden çözer.
2. `GlobalTheme::update_theme` veya `update_icon_theme` ile global'i yazar.
3. `cx.refresh_windows()` çağırır.

Settings observer (`init` içindeki `cx.observe_global::<SettingsStore>`)
font size, theme name, icon theme name veya theme override'ların değiştiğini
fark edince ilgili reload helper'ını çağırır. **Yani Settings'i mutate etmek
otomatik olarak runtime'a yansır**; selector confirm akışında ek bir
`update_theme` çağrısına ihtiyaç yoktur (önizleme yazmıyorsa).

`kvs_tema` mirror tarafında bu iki fonksiyon `pub fn temayi_yeniden_yukle(cx)`
ve `pub fn icon_temayi_yeniden_yukle(cx)` olarak çıkar; observer'ı kuran
`init` fonksiyonu da Zed'deki `theme_settings::init`'in karşılığıdır.

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
    let themes: Vec<Theme> = family
        .themes
        .into_iter()
        .map(|theme_content| {
            let baseline = match theme_content.appearance {
                AppearanceContent::Dark => &baseline_dark,
                AppearanceContent::Light => &baseline_light,
            };
            Theme::from_content(theme_content, baseline)
        })
        .collect();
    registry.insert_themes(themes);  // Aynı isim üzerine yazar

    // Aktif tema yeniden yüklendi mi? Re-set ile observer'ları tetikle.
    let aktif_ad = cx.theme().name.clone();
    if let Ok(yeni) = registry.get(&aktif_ad) {
        GlobalTheme::update_theme(cx, yeni);
        cx.refresh_windows();
    }

    Ok(())
}
```

**Akış:**

1. Disk'ten oku, parse et.
2. Her tema variant'ı için uygun baseline seç (light → light baseline).
3. `registry.insert` üzerine yazar — aynı isimle güncellenir.
4. Aktif tema yeniden yüklendiyse `GlobalTheme::update_theme` + `refresh_windows`.

#### Performans

| Operasyon | Süre | Hot path? |
|-----------|------|-----------|
| `registry.get(name)` | O(1) HashMap lookup | Sık (her tema değişimde) |
| `GlobalTheme::update_theme` | Global update + observer trigger | Sık |
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
       Ok(t) => GlobalTheme::update_theme(cx, t),
       Err(_) => {
           tracing::warn!("aktif tema silindi, fallback'e dönülüyor");
           let fallback = registry.get("Kvs Default Dark").unwrap();
           GlobalTheme::update_theme(cx, fallback);
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

**Light eşleniği** (`status_colors_light()`): Aynı anchor renkleri,
**lightness biraz koyu** (light bg üzerinde okunaklılık için), bg ve
border opacity'leri korunur.

```rust
fn status_colors_light() -> StatusColors {
    // Light bg üzerinde kontrast için lightness 0.45-0.50 (dark'ta 0.55-0.60)
    let red    = hsla(0.0   / 360.0, 0.7,  0.45, 1.0);
    let green  = hsla(140.0 / 360.0, 0.45, 0.40, 1.0);
    let yellow = hsla(45.0  / 360.0, 0.85, 0.45, 1.0);
    let blue   = hsla(210.0 / 360.0, 0.7,  0.45, 1.0);

    StatusColors {
        error: red,
        error_background: red.opacity(0.15),     // light bg'de bg alpha daha düşük
        error_border: red.opacity(0.4),

        warning: yellow,
        warning_background: yellow.opacity(0.15),
        warning_border: yellow.opacity(0.4),

        info: blue,
        info_background: blue.opacity(0.15),
        info_border: blue.opacity(0.4),

        success: green,
        success_background: green.opacity(0.15),
        success_border: green.opacity(0.4),

        // ... 14 × 3 = 42 alan — dark'taki anchor map'i aynı,
        // sadece lightness ve opacity light bg'ye uyarlı
    }
}
```

**Light vs dark status renk kuralları:**

| Boyut | Dark | Light |
|-------|------|-------|
| Foreground lightness | 0.55-0.60 | 0.40-0.50 (koyu bg'ye karşı doygun) |
| Background opacity | 0.20 | 0.15 (light yüzeyde aşırı dolgu olmasın) |
| Border opacity | 0.50 | 0.40 |
| Saturation | aynı (her iki tarafta da doygunluk korunur) |

#### Syntax fallback — temel kategoriler

`SyntaxTheme::new(vec![])` ile boş bırakmak kod görünümünde tüm token'ları
varsayılan text rengiyle çizer; renksiz ve okunaksız. Minimum **8 temel
kategori** doldur:

```rust
fn syntax_theme_dark(accent: Hsla, text: Hsla, text_muted: Hsla) -> Arc<SyntaxTheme> {
    use gpui::{FontStyle, FontWeight, HighlightStyle};

    let red    = hsla(0.0   / 360.0, 0.65, 0.65, 1.0);   // keyword
    let green  = hsla(140.0 / 360.0, 0.45, 0.60, 1.0);   // string
    let yellow = hsla(45.0  / 360.0, 0.80, 0.65, 1.0);   // type, function
    let cyan   = hsla(190.0 / 360.0, 0.65, 0.65, 1.0);   // number
    let purple = hsla(280.0 / 360.0, 0.55, 0.70, 1.0);   // constant

    Arc::new(SyntaxTheme::new(vec![
        ("comment".into(), HighlightStyle {
            color: Some(text_muted),
            font_style: Some(FontStyle::Italic),
            ..Default::default()
        }),
        ("string".into(), HighlightStyle {
            color: Some(green),
            ..Default::default()
        }),
        ("keyword".into(), HighlightStyle {
            color: Some(red),
            font_weight: Some(FontWeight::BOLD),
            ..Default::default()
        }),
        ("number".into(), HighlightStyle {
            color: Some(cyan),
            ..Default::default()
        }),
        ("function".into(), HighlightStyle {
            color: Some(yellow),
            ..Default::default()
        }),
        ("type".into(), HighlightStyle {
            color: Some(yellow),
            ..Default::default()
        }),
        ("constant".into(), HighlightStyle {
            color: Some(purple),
            ..Default::default()
        }),
        ("variable".into(), HighlightStyle {
            color: Some(text),
            ..Default::default()
        }),
    ]))
}
```

**Kategoriler tüm tree-sitter dilleri için ortak**: `comment`, `string`,
`keyword`, `number`, `function`, `type`, `constant`, `variable` —
Zed'in tüm `languages/*/highlights.scm` dosyalarında bu adlar kullanılır.
Kullanıcı tema'sı daha zengin kategorilere genişletebilir (örn.
`function.builtin`, `string.escape`); fallback minimum garantili
8'lik liste.

#### Player ve accent fallback

```rust
ThemeStyles {
    // ...
    player: PlayerColors(vec![PlayerColor {
        cursor: accent,
        background: accent.opacity(0.2),
        selection: accent.opacity(0.3),
    }]),
    accents: AccentColors(Arc::from([accent].as_slice())),
    syntax: Arc::new(SyntaxTheme::new(Vec::<(String, HighlightStyle)>::new())),
}
```

- **Player listesi en az 1 girdi** (Bölüm III/Konu 15) — yoksa
  `local()` panic eder.
- **Accents en az 1 girdi** — yoksa `color_for_index(idx)` modulo'da
  `len() == 0` paniği üretir; Zed kaynağında `Default::default()`
  `Self::dark()` döndüğü için her zaman 13 elemandır.
- **Syntax boş Vec** kabul edilebilir — `SyntaxTheme::new`'a boş tuple
  iter geçirilir, runtime `style_for_name` her zaman `None` döner.

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
    assert_ne!(dark.colors().background, gpui::Hsla::default());
    assert_ne!(dark.colors().text, gpui::Hsla::default());
    assert_ne!(dark.status().error, gpui::Hsla::default());

    // Player ve accent en az 1 girdi
    assert!(!dark.players().0.is_empty());
    assert!(!dark.accents().0.is_empty());

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
7. **`syntax: Arc::new(SyntaxTheme::new(vec![]))` bırakmak**: Fallback'te
   boş syntax kabul, ama UI'da kod gösteriliyorsa syntax token'ları için
   en azından 5-10 temel kategori doldur (comment, string, keyword,
   number, function). `Theme.styles.syntax` alanı `Arc<SyntaxTheme>` tipi
   beklediği için boş bile olsa `Arc::new(...)` sarması zorunlu.

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

        let themes: Vec<kvs_tema::Theme> = family
            .themes
            .into_iter()
            .map(|theme_content| {
                let baseline = match theme_content.appearance {
                    kvs_tema::AppearanceContent::Dark => &baseline_dark,
                    kvs_tema::AppearanceContent::Light => &baseline_light,
                };
                kvs_tema::Theme::from_content(theme_content, baseline)
            })
            .collect();
        registry.insert_themes(themes);
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

        let themes: Vec<kvs_tema::Theme> = family
            .themes
            .into_iter()
            .map(|theme_content| {
                let baseline = match theme_content.appearance {
                    kvs_tema::AppearanceContent::Dark => &baseline_dark,
                    kvs_tema::AppearanceContent::Light => &baseline_light,
                };
                kvs_tema::Theme::from_content(theme_content, baseline)
            })
            .collect();
        registry.insert_themes(themes);
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

        let baseline_dark = kvs_tema::fallback::kvs_default_dark();
        let baseline_light = kvs_tema::fallback::kvs_default_light();
        let themes: Vec<kvs_tema::Theme> = family
            .themes
            .into_iter()
            .map(|tc| {
                let baseline = match tc.appearance {
                    kvs_tema::AppearanceContent::Dark => &baseline_dark,
                    kvs_tema::AppearanceContent::Light => &baseline_light,
                };
                kvs_tema::Theme::from_content(tc, baseline)
            })
            .collect();
        registry.insert_themes(themes);
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
├── one.LICENSE_MIT       ← <stem>.LICENSE_<tip>
├── ayu.LICENSE_MIT
├── README.md             ← Hangi tema hangi lisans
├── one.json              ← One Light + One Dark
└── ayu.json              ← Ayu varyantları
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
   #[include = "themes/*.LICENSE_*"]
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
│   ├── ayu.json                ← Zed assets/themes/ayu/ayu.json (MIT)
│   ├── one.LICENSE_MIT         ← Zed'den kopyalanan lisans
│   ├── ayu.LICENSE_MIT
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
        assert_ne!(theme.colors().background, gpui::Hsla::default());
    }
}

#[test]
fn parses_zed_ayu() {
    let json = include_str!("fixtures/ayu.json");
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
    assert_eq!(theme.colors().background, baseline.colors().background);
    assert_eq!(theme.status().error, baseline.status().error);
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
    assert_eq!(theme.colors().background, baseline.colors().background);
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
    let mut colors = baseline.colors().clone();

    let refinement = ThemeColorsRefinement {
        border: Some(gpui::hsla(0.5, 1.0, 0.5, 1.0)),
        ..Default::default()
    };

    let original_bg = colors.background;
    colors.refine(&refinement);

    assert_ne!(colors.border, baseline.colors().border);  // override
    assert_eq!(colors.background, original_bg);            // korundu
}
```

#### Yeni bir Zed tema fixture eklerken

**Adım 1 — Lisans doğrula:**

```sh
# Zed kaynağındaki lisans dosyasına bak
ls ../zed/assets/themes/one/
# LICENSE one.json
```

`LICENSE` dosyasının içeriği MIT/Apache/BSD gibi uyumlu lisans olmalı.
GPL veya lisans yoksa **kullanma**.

**Adım 2 — Kopyala:**

```sh
cp ../zed/assets/themes/one/one.json tests/fixtures/one-dark.json
cp ../zed/assets/themes/one/LICENSE tests/fixtures/one.LICENSE_MIT
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
2. **Fixture lisansını unutmak**: Dosyayı kopyalarken `*.LICENSE_*`'ı
   atlama. CI'da otomatik kontrol et:
   ```sh
   ls tests/fixtures/*.LICENSE_* 1>/dev/null || (echo "lisans dosyası yok!" && exit 1)
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

Zed'in `assets/themes/` dizininde **her tema kendi alt dizininde** ve
kendi lisansıyla tutulur:

```
zed/assets/themes/
├── one/
│   ├── LICENSE
│   └── one.json
├── ayu/
│   ├── LICENSE
│   └── ayu.json
└── gruvbox/
    ├── LICENSE
    └── gruvbox.json
```

**Kendi bundle'ında adlandırma konvansiyonu:**

Zed alt-dizin yapısını korumak yerine tüm tema'ları **düz dizinde**
tutuyorsan, lisans dosyalarının çakışmaması için tema adıyla son ek:

```
kvs_ui/assets/themes/
├── README.md                    ← atıf tablosu (zorunlu)
├── one.json
├── one.LICENSE_MIT              ← <tema-ad>.LICENSE_<tip>
├── ayu.json
├── ayu.LICENSE_MIT
├── gruvbox.json
└── gruvbox.LICENSE_MIT
```

**Konvansiyon kuralları:**

1. Her tema JSON dosyasının **aynı stem** (uzantı öncesi ad) ile bir
   `<stem>.LICENSE_<tip>` dosyası olmalı.
2. `<tip>` = `MIT`, `APACHE`, `BSD3`, `MPL2` gibi SPDX kodlarının kısa
   karşılığı.
3. `LICENSE_GPL*` ile başlayan dosya **bulunmaz** (CI kontrolü Konu
   sonunda).
4. `README.md` zorunlu — atıf tablosu (telif sahibi, kaynak repo, SPDX
   kodu).

**Alternatif:** Zed dizin yapısını birebir korumak (tema başına alt
dizin):

```
kvs_ui/assets/themes/
├── README.md
├── one/
│   ├── one.json
│   └── LICENSE
└── ayu/
    ├── ayu.json
    └── LICENSE
```

Hangi yapıyı seçtiysen `RustEmbed`/`AssetSource` filter'larını
güncelle (`include = "themes/**/*.json"` vs `include = "themes/*.json"`).
Bu rehberin örnekleri **düz dizin** yapısını varsayar; alt-dizin tercih
edilirse path manipülasyonu farklı.

**Kontrol komutu:**

```sh
# Hangi temalar hangi lisansta?
find ../zed/assets/themes -maxdepth 2 \( -name "LICENSE" -o -name "LICENSE_*" \) | sort
```

Dosya adı `LICENSE` ise içeriğini oku; MIT/Apache/BSD gibi uyumlu lisans
kullanılabilir, GPL veya belirsiz lisans kullanılamaz.

#### Yeni tema eklerken kontrol listesi

```sh
# 1. Lisans dosyasını oku
cat ../zed/assets/themes/<tema>/LICENSE

# 2. Lisans uygunsa kopyala (tema + lisans birlikte)
cp ../zed/assets/themes/<tema>/<tema>.json kvs_ui/assets/themes/
cp ../zed/assets/themes/<tema>/LICENSE kvs_ui/assets/themes/<tema>.LICENSE_MIT

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
| `one.json` | github.com/zed-industries/zed | `assets/themes/one/one.json` | MIT | ilgili `LICENSE` dosyası |
| `ayu.json` | github.com/zed-industries/zed | `assets/themes/ayu/ayu.json` | MIT | ilgili `LICENSE` dosyası |
| `gruvbox.json` | github.com/zed-industries/zed | `assets/themes/gruvbox/gruvbox.json` | MIT | ilgili `LICENSE` dosyası |

## Senkron tarihi

Son senkron: 2026-05-12 (Zed pin `6e8eaab25b5a`). Bkz.
`../../gpui_belge/zed_commit_pin.txt`.
```

#### CI'da lisans doğrulama

```sh
#!/bin/sh
# scripts/check_theme_licenses.sh
set -e

THEMES_DIR="kvs_ui/assets/themes"
FIXTURES_DIR="kvs_tema/tests/fixtures"

# Her .json dosyasının yanında aynı stem'li bir LICENSE_* dosyası olmalı
for dir in "$THEMES_DIR" "$FIXTURES_DIR"; do
    for json in "$dir"/*.json; do
        [ -e "$json" ] || continue
        stem="${json%.json}"
        # düz konvansiyon: <stem>.LICENSE_<tip>
        if ! ls "$stem".LICENSE_* 1>/dev/null 2>&1; then
            # alt-dizin konvansiyonu için fallback: <dir>/LICENSE veya <dir>/LICENSE_*
            subdir="$(dirname "$json")"
            if ! ls "$subdir"/LICENSE "$subdir"/LICENSE_* 1>/dev/null 2>&1; then
                echo "HATA: $json için lisans dosyası yok"
                exit 1
            fi
        fi
    done
done

# GPL lisansı yasak (dosya adı ve içerik kontrolü)
if find "$THEMES_DIR" "$FIXTURES_DIR" -type f \
    \( -name "*LICENSE_GPL*" -o -name "LICENSE_GPL*" \) | grep -q .; then
    echo "HATA: $THEMES_DIR altında GPL tema bulundu — kaldır"
    exit 1
fi
if find "$THEMES_DIR" "$FIXTURES_DIR" -type f \
    \( -name "LICENSE*" -o -name "*.LICENSE_*" \) \
    -exec grep -Eil "GNU GENERAL PUBLIC LICENSE|GPL-3|GPL-2" {} + | grep -q .; then
    echo "HATA: GPL içerikli lisans bulundu — kaldır"
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
   awk '/^The / || /^Copyright/ || /License/' ../zed/assets/themes/*/LICENSE 2>/dev/null
   diff <(ls /eski/zed/assets/themes) <(ls ../zed/assets/themes)
   ```
2. **Lisansı değişmiş temalar var mı?** Bir tema dosyası kaldı ama
   lisans içeriği MIT'den GPL'e döndü = kullanmaya devam edemezsin. Kaldır.
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
            .bg(tema.colors().background)
            .text_color(tema.colors().text)
            .border_1()
            .border_color(tema.colors().border)
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
3. **Alan erişimi** — `styles` crate-içi olduğu için tüketici
   `tema.colors().background` gibi accessor kullanır.

#### Erişim yolları kıyaslaması

```rust
// Accessor metotları (önerilen değil, dış crate için zorunlu)
let bg = tema.colors().background;
let muted = tema.colors().text_muted;
let error = tema.status().error;
let local = tema.players().local().cursor;
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
pub use crate::{Appearance, Theme, ThemeFamily};
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
4. **`tema.styles.colors.X` zinciri**: Dış crate için compile hatasıdır.
   Accessor kullan (`theme.colors()`).
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
pub use crate::Theme;            // accessor metotlarıyla okunur (Konu 12)
pub use crate::ThemeFamily;
pub use crate::Appearance;

pub use crate::styles::ThemeColors;
pub use crate::styles::StatusColors;
pub use crate::styles::PlayerColors;
pub use crate::styles::PlayerColor;
pub use crate::styles::AccentColors;
pub use crate::styles::SystemColors;

// Icon tema sözleşmesi (Konu 17)
pub use crate::icon_theme::{
    IconTheme, IconThemeFamily, IconDefinition,
    DirectoryIcons, ChevronIcons,
};
```

> **`ThemeStyles` listede YOK.** `Theme.styles` alanı `pub(crate)` —
> tüketici accessor'larla okur (`theme.colors()`, `theme.status()`).
> `ThemeStyles` tipini import etmek tüketici için anlamsız.

**Runtime (kararlı):**

```rust
pub use crate::runtime::ActiveTheme;             // cx.theme() için trait
pub use crate::runtime::GlobalTheme;
pub use crate::runtime::SystemAppearance;
pub use crate::runtime::init;
pub use crate::runtime::temayi_degistir;         // tek-yönlü helper (Konu 31)
pub use crate::runtime::temayi_yeniden_yukle;    // disk reload (Konu 31)
pub use crate::runtime::observe_system_appearance;  // pencere observer (Konu 29)
```

**Registry (kararlı):**

```rust
pub use crate::registry::{
    ThemeRegistry, ThemeMeta, ThemeNotFoundError, IconThemeNotFoundError,
};
```

**Fallback (kararlı, namespace altında):**

```rust
// kvs_tema::fallback::kvs_default_dark()
// kvs_tema::fallback::kvs_default_light()
pub mod fallback;   // pub modül; içeride sadece public fonksiyonlar
```

**Schema (KARARSIZ — extension/ileri kullanım için, tek tek ihraç):**

```rust
// Glob YASAK — yeni iç tip eklenince istemeden public olmaması için
// tek tek ihraç:
pub use crate::schema::{
    AppearanceContent, FontStyleContent, FontWeightContent,
    HighlightStyleContent, PlayerColorContent, StatusColorsContent,
    ThemeColorsContent, ThemeContent, ThemeFamilyContent,
    ThemeStyleContent, WindowBackgroundContent,
    try_parse_color,
};

// Icon tema Content tipleri (Konu 17)
pub use crate::icon_theme::{
    IconThemeContent, IconThemeFamilyContent,
    DirectoryIconsContent, ChevronIconsContent, IconDefinitionContent,
};
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

Konu 4'teki iskeletle **birebir aynı**. Burada özet:

```rust
//! kvs_tema — Zed-uyumlu, lisans-temiz tema sistemi.

// Crate-içi (gizli)
pub(crate) mod refinement;          // Bölüm V

// Namespace altında public (kvs_tema::fallback::*)
pub mod fallback;

// Private dosya modülleri, içeriği selektif ihraç edilir
mod icon_theme;
mod registry;
mod runtime;
mod schema;
mod styles;

// Glob ihraç — kararlı modüller (yeni iç tip neredeyse hep public istenir)
pub use crate::icon_theme::*;
pub use crate::registry::*;
pub use crate::runtime::*;
pub use crate::styles::*;

// Schema — KARARSIZ; tek tek ihraç, glob asla
pub use crate::schema::{
    AppearanceContent, FontStyleContent, FontWeightContent,
    HighlightStyleContent, PlayerColorContent, StatusColorsContent,
    ThemeColorsContent, ThemeContent, ThemeFamilyContent,
    ThemeStyleContent, WindowBackgroundContent,
    try_parse_color,
};

// Lib kökünde tanımlı tipler (zaten public)
// → Theme, ThemeFamily, Appearance
// → ThemeStyles tipi crate-içi; ihraç edilmez (Konu 12)
```

**Pattern:**

- `pub(crate) mod refinement` — `refinement.rs` modülü dışarıya kapalı,
  içeride paylaşılır.
- `pub use module::*` — kararlı modüller için tüm-ihracı; her iç tipin
  public olmasını istiyorsan glob; istemiyorsan tek tek.
- `pub use schema::{...}` — schema modülü için **glob YASAK** çünkü yeni
  iç implementasyon tipleri (mesela `serde` helper'ları) istemeden public
  olmasın.
- `pub mod fallback` — fallback fonksiyonları namespace altında
  (`kvs_tema::fallback::kvs_default_dark`). `fallback.rs` içinde sadece
  bu iki fonksiyon `pub`, diğer her şey `pub(super)` veya private.

#### `prelude` modülü (önerilen)

```rust
// kvs_tema/src/prelude.rs
//! kvs_tema prelude — sık kullanılan tipleri tek import'a indirir.

pub use crate::runtime::ActiveTheme;
pub use crate::{Appearance, Theme, ThemeFamily};
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
✓ `kvs_tema::temayi_yeniden_yukle(yol, cx)` ile disk'ten reload
✓ `kvs_tema::observe_system_appearance(window, cx)` ile sistem mod takibi
✓ `kvs_tema::SystemAppearance::global(cx)` ile sistem mod sorgulamak
✓ `GlobalTheme::icon_theme(cx)` ile aktif icon tema okumak
✓ `ThemeRegistry::global(cx).list_icon_themes()` ile icon tema seçeneklerini listelemek

Tüketicinin yapamayacağı şeyler (compile hatası):

✗ `theme.styles.colors.X` yazmak — `styles` `pub(crate)`, accessor şart
✗ `GlobalThemeRegistry`/`GlobalSystemAppearance` newtype'larına dokunmak
  (private)

Tüketicinin yapmaması gerekenler (compile geçer ama kötü pratik):

✗ `kvs_tema::ThemeColorsContent` üzerinde `match` yazmak — schema
  kararsız (Konu 18)
✗ `kvs_tema::try_parse_color(...)` doğrudan çağırmak — `Theme::from_content`
  zaten sarmalıyor
✗ Tema yüklerken `baseline`'ı yanlış appearance ile seçmek (Konu 26)

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
        assert_ne!(theme.colors().background, gpui::Hsla::default());
    });
}
```

**Avantaj:** Production akışına en yakın. Init bug'ları erken yakalanır.

**Dezavantaj:** Her test fallback tema oluşumu için ~50 µs harcar.
Yüzlerce test çalıştırıyorsan kümülatif.

#### Strateji 2: Manuel kurulum (özel tema değerleri)

Test'in özel renk değerlerine ihtiyacı varsa, manuel kur:

**Bu strateji `kvs_tema` crate'inin İÇİNDEN çalışır** — `Theme { styles:
... }` literal'i `pub(crate)` field'lara erişir. `kvs_tema/tests/`
(entegrasyon testleri) **dış crate** sayılır; oradan struct literal
yazılamaz. Bu manuel kurulum sadece `kvs_tema/src/test.rs` (Strateji 3)
veya `kvs_tema` modülünün kendi birim testlerinde kullanılır.

```rust
// kvs_tema/src/test.rs içinde (crate-içi)
use std::sync::Arc;
use gpui::hsla;
use crate::{
    Theme, ThemeStyles, ThemeColors, StatusColors, PlayerColors,
    AccentColors, SystemColors, Appearance,
};

pub(crate) fn test_theme(bg: gpui::Hsla, fg: gpui::Hsla) -> Theme {
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
            syntax: Arc::new(kvs_syntax_tema::SyntaxTheme::new(Vec::<(String, HighlightStyle)>::new())),
        },
    }
}
```

> **`..fallback_colors_dark()` yapmak için:** `ThemeColors`'a `Default`
> türetmen veya yardımcı bir `pub(crate) fn fallback_colors_dark() ->
> ThemeColors` tanımlaman gerek. Mevcut yapıda `ThemeColors`'ın
> `Default`'u yok (tüm alanları zorunlu); test helper'ı yaz.
>
> **Dış crate'ten test:** `kvs_ui/tests/`'te bu strateji çalışmaz;
> `feature = "test-util"` ile Strateji 3'ün public helper'ları çağrılır.

#### Strateji 3: `kvs_tema` test helper'ı

`kvs_tema/src/test.rs` (yeni modül, `#[cfg(any(test, feature = "test-util"))]`):

```rust
#[cfg(any(test, feature = "test-util"))]
pub mod test {
    use crate::*;
    use std::sync::Arc;

    /// Test için minimal tema kurar.
    pub fn init_test(cx: &mut gpui::App) {
        // ThemeRegistry::new artık AssetSource zorunlu — testte `()` kullanılır.
        let registry = Arc::new(ThemeRegistry::new(Box::new(()) as Box<dyn gpui::AssetSource>));
        registry.insert_themes([test_theme()]);
        let theme = registry.get("Test").unwrap();
        let icon_theme = registry.default_icon_theme().unwrap();
        // ThemeRegistry::set_global Zed'de pub(crate); test helper'ı
        // kvs_tema'nın test-support feature'ı altında public açar veya
        // doğrudan GlobalThemeRegistry newtype'ını cx.set_global ile kurar.
        cx.set_global(GlobalThemeRegistry(registry.clone()));
        cx.set_global(GlobalTheme::new(theme, icon_theme));
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
        let expected_bg = theme.colors().element_background;

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
// YANLIŞ: cx olmadan, struct literal ile tema oluşturmak
// (dış crate'te bu zaten derlenmez — `styles` pub(crate))
let theme = kvs_tema::fallback::kvs_default_dark();
let bg = theme.colors().background;
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
   ilk satırı init veya manuel `cx.set_global(GlobalTheme::new(...))`.
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
- [ ] `kvs_ui/assets/themes/*.LICENSE_*` — her bundle'lı tema için lisans
      dosyası mevcut.
- [ ] `kvs_ui/assets/themes/README.md` — atıf tablosu güncel.
- [ ] `kvs_tema/tests/fixtures/*.LICENSE_*` — her fixture için lisans.
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
- [ ] `tema_kaymasi_kontrol.sh` ile `../zed` önce `zed_commit_pin.txt`
      commit'ine temiz biçimde geri sabitlendi, sonra `git pull --ff-only`
      çalıştırıldı; üretilen `zed_farkları*.diff` incelendi ve tema, bileşen
      ve GPUI yüzeyini etkileyen değişiklikler rehberlere yansıtıldı.
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
   renkte kalır — en yaygın tema bug'ı. `GlobalTheme::update_theme +
   refresh_windows` her zaman çift. → Konu 31.
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
# 1. Zed'i pin'e geri sabitle, upstream'den çek ve diff üret
cd ~/github/gpui_belge
./tema_kaymasi_kontrol.sh
# → zed_farkları<timestamp>-<sha>.diff üretir
```

Script `../zed` içinde `git reset --hard <pin>`, `git clean -fd` ve
`git pull --ff-only` çalıştırır. Zed reposunda yerel çalışma tutulmaz; kaynak
upstream Zed'dir. Ignored dosyalar da silinecekse:

```sh
ZED_TEMIZLE_IGNORED=1 ./tema_kaymasi_kontrol.sh
```

```sh
# 2. Diff'i ve gerektiğinde commit'i tek tek incele
$EDITOR zed_farkları*.diff
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
# 6. zed_commit_pin.txt ve tema_aktarimi.md güncelle
cd ~/github/gpui_belge
git -C ../zed rev-parse HEAD > zed_commit_pin.txt
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
ls ../zed/assets/themes/one/LICENSE
# LICENSE içeriği MIT/Apache/BSD gibi uyumlu olmalı; GPL ise kullanma
LICENSE_FILE="../zed/assets/themes/one/LICENSE"
LICENSE_KIND="LICENSE_MIT"   # LICENSE içeriğinden doğrula
```

```sh
# 2. Tema + lisans kopyala — düz dizin konvansiyonu (Konu 35)
# <stem>.json + <stem>.LICENSE_<tip>
cp ../zed/assets/themes/one/one.json \
   kvs_ui/assets/themes/
cp "$LICENSE_FILE" \
   "kvs_ui/assets/themes/one.$LICENSE_KIND"
```

```sh
# 3. Atıf README'sine ekle
$EDITOR kvs_ui/assets/themes/README.md
# | one.json | zed/assets/themes/one | $LICENSE_KIND | © GitHub Inc. |
```

```sh
# 4. Fixture testine ekle (opsiyonel)
cp ../zed/assets/themes/one/one.json \
   kvs_ui/crates/kvs_tema/tests/fixtures/
cp "$LICENSE_FILE" \
   "kvs_ui/crates/kvs_tema/tests/fixtures/one.$LICENSE_KIND"
$EDITOR kvs_ui/crates/kvs_tema/tests/parse_fixture.rs
# #[test] fn parses_one() { ... }
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
            accents: AccentColors(Arc::from([
                accent,
                hsla(330.0 / 360.0, 0.7, 0.6, 1.0),  // magenta
                hsla(60.0 / 360.0, 0.7, 0.6, 1.0),   // sarı
            ].as_slice())),
            syntax: Arc::new(SyntaxTheme::new(Vec::<(String, HighlightStyle)>::new())),
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
            if theme.colors().$field != baseline.colors().$field {
                diffs.push((
                    stringify!($field).to_string(),
                    baseline.colors().$field,
                    theme.colors().$field,
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

**Dış crate'ten `Theme` inşa edemezsin** — `styles` `pub(crate)` (Konu
12). Test temasını kurmak için `kvs_tema`'nın `test-util` feature
helper'ları üzerinden geçilir (Konu 39).

```toml
# kvs_ui/Cargo.toml
[dev-dependencies]
kvs_tema = { path = "../kvs_tema", features = ["test-util"] }
```

```rust
// kvs_tema/src/test.rs — crate-içi helper (test-util feature)
#[cfg(any(test, feature = "test-util"))]
pub fn install_with_overrides(
    cx: &mut gpui::App,
    overrides: impl FnOnce(&mut ThemeColors),
) -> Arc<Theme> {
    let mut theme = crate::fallback::kvs_default_dark();
    // styles `pub(crate)` ama bu fonksiyon crate-içi — erişim yasal
    overrides(&mut theme.styles.colors);

    let registry = Arc::new(ThemeRegistry::new(Box::new(()) as Box<dyn gpui::AssetSource>));
    let arc_theme = Arc::new(theme);
    registry.insert_themes([(*arc_theme).clone()]);
    let active_theme = registry.get(arc_theme.name.as_ref()).unwrap();
    let icon_theme = registry.default_icon_theme().unwrap();
    // Zed'in `ThemeRegistry::set_global` helper'ı `pub(crate)`; mirror
    // tarafta newtype'ı doğrudan set ediyoruz.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(active_theme.clone(), icon_theme));
    active_theme
}
```

```rust
// kvs_ui/tests/button_test.rs — tüketici test
use gpui::TestAppContext;
use kvs_tema::test::install_with_overrides;
use kvs_tema::ActiveTheme;

#[gpui::test]
fn button_uses_element_background(cx: &mut TestAppContext) {
    cx.update(|cx| {
        let green = gpui::hsla(0.333, 1.0, 0.5, 1.0);
        let theme = install_with_overrides(cx, |colors| {
            colors.element_background = green;
        });

        let _button = cx.new(|_| Button::new("OK".into()));

        // Accessor üzerinden okuma — dış crate yolu
        assert_eq!(theme.colors().element_background, green);
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

/// Disk taramasını blocking olarak yapar; çağıran taraf
/// `cx.background_executor().spawn` ile UI thread'i bloklamadan
/// çalıştırır.
pub fn collect_user_theme_files() -> anyhow::Result<Vec<(PathBuf, Vec<u8>)>> {
    let Some(dir) = user_theme_dir() else { return Ok(vec![]); };
    if !dir.exists() { return Ok(vec![]); }

    let mut out = Vec::new();
    for entry in std::fs::read_dir(&dir)? {
        let entry = entry?;
        let path = entry.path();
        if !path.extension().is_some_and(|e| e == "json") { continue; }
        let bytes = std::fs::read(&path)?;
        out.push((path, bytes));
    }
    Ok(out)
}

/// Toplanan dosyaları registry'ye basar — `cx.update` içinde çağrılır.
pub fn install_user_themes(
    files: Vec<(PathBuf, Vec<u8>)>,
    cx: &mut gpui::App,
) -> anyhow::Result<()> {
    let registry = kvs_tema::ThemeRegistry::global(cx);
    let baseline_dark = kvs_tema::fallback::kvs_default_dark();
    let baseline_light = kvs_tema::fallback::kvs_default_light();

    for (path, bytes) in files {
        let family: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&bytes)
                .map_err(|e| anyhow::anyhow!("{}: {}", path.display(), e))?;
        let themes: Vec<kvs_tema::Theme> = family
            .themes
            .into_iter()
            .map(|theme_content| {
                let baseline = match theme_content.appearance {
                    kvs_tema::AppearanceContent::Dark => &baseline_dark,
                    kvs_tema::AppearanceContent::Light => &baseline_light,
                };
                kvs_tema::Theme::from_content(theme_content, baseline)
            })
            .collect();
        registry.insert_themes(themes);
    }
    Ok(())
}

// main.rs
fn main() {
    Application::new().run(|cx| {
        kvs_tema::init(cx);

        // Disk taramasını GPUI'nin background executor'ında çalıştır
        // (blocking IO UI thread'i durdurmasın; tokio dep gerektirmez).
        let task = cx.background_executor().spawn(async {
            themes::collect_user_theme_files()
        });

        cx.spawn(async move |cx| {
            match task.await {
                Ok(files) => {
                    let _ = cx.update(|cx| {
                        if let Err(e) = themes::install_user_themes(files, cx) {
                            tracing::warn!("kullanıcı tema yüklemesi: {}", e);
                        }
                    });
                }
                Err(e) => tracing::warn!("disk taraması: {}", e),
            }
        }).detach();

        // ... pencere
    });
}
```

> **Neden tokio değil?** GPUI'nin kendi `BackgroundExecutor`'ı var
> (smol tabanlı); ek bir runtime dependency'si gerek değil.
> `cx.background_executor().spawn` blocking IO için ayrı thread'e dispatch
> eder; sonuç `.await` ile geri gelir ve `cx.update` UI thread'inde
> registry'yi günceller.

> **Referans:** Bölüm VI/Konu 30 (init genişletme), Bölüm VII/Konu 33.

---

#### Reçete 42.11 — Schema üretimi ve CI parite kapısı

Tema sistemi tamamlandığında CI üç şeyi garanti etmeli:

- JSON schema dosyaları üretilmiş ve repo'da güncel.
- Fixture ve bundled tema JSON'ları parse + schema validation'dan geçiyor.
- `ThemeColors` / `ThemeColorsContent` alan paritesi yanlışlıkla kaymıyor.

**Schema export binary:**

```rust
// kvs_tema/src/bin/export_schema.rs
use schemars::schema_for;

fn main() -> anyhow::Result<()> {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("theme") => {
            let schema = schema_for!(kvs_tema::ThemeFamilyContent);
            println!("{}", serde_json::to_string_pretty(&schema)?);
        }
        Some("icon-theme") => {
            let schema = schema_for!(kvs_tema::IconThemeFamilyContent);
            println!("{}", serde_json::to_string_pretty(&schema)?);
        }
        _ => anyhow::bail!("usage: export_schema <theme|icon-theme>"),
    }
    Ok(())
}
```

**Repo'da tutulan çıktılar:**

```text
schemas/
├── theme-v0.2.0.json
└── icon-theme-v0.1.0.json
```

Tema dosyalarının başında public Zed şeması veya kendi dağıttığın yerel
şema URL'si bulunur:

```json
{
  "$schema": "https://zed.dev/schema/themes/v0.2.0.json",
  "name": "My Theme",
  "author": "KVS",
  "themes": []
}
```

Kendi uygulamana özel schema yayınlamıyorsan built-in dosyalarda yerel
relative path kullan:

```json
{ "$schema": "../../schemas/theme-v0.2.0.json" }
```

**Schema validation testi:**

```rust
// kvs_tema/tests/schema_validation.rs
use std::path::Path;

fn validate_theme_file(path: &Path) -> anyhow::Result<()> {
    let schema: serde_json::Value =
        serde_json::from_str(include_str!("../schemas/theme-v0.2.0.json"))?;
    let validator = jsonschema::validator_for(&schema)?;

    let text = std::fs::read_to_string(path)?;
    let value: serde_json::Value = serde_json_lenient::from_str(&text)?;
    validator.validate(&value)?;

    let _: kvs_tema::ThemeFamilyContent = serde_json_lenient::from_str(&text)?;
    Ok(())
}

#[test]
fn fixtures_match_schema() {
    for entry in std::fs::read_dir("tests/fixtures").unwrap() {
        let path = entry.unwrap().path();
        if path.extension().is_some_and(|e| e == "json") {
            validate_theme_file(&path).unwrap();
        }
    }
}
```

`Cargo.toml` test bağımlılığı:

```toml
[dev-dependencies]
jsonschema = "0.37.0"
```

**Alan paritesi testi:**

```rust
// kvs_tema/tests/theme_color_parity.rs
const THEME_COLOR_FIELDS: &[&str] = &[
    "border", "border_variant", "border_focused", "border_selected",
    "border_transparent", "border_disabled",
    // Konu 13'teki 143 alanın tamamı burada tutulur.
];

const THEME_COLOR_CONTENT_FIELDS: &[&str] = &[
    "border", "border_variant", "border_focused", "border_selected",
    "border_transparent", "border_disabled",
    // Konu 18'deki 146 alanın tamamı burada tutulur.
];

const THEME_COLOR_REFLECTION_FIELDS: &[&str] = &[
    "border", "border_variant", "border_focused", "border_selected",
    "border_transparent", "border_disabled",
    // Konu 43.4'teki ThemeColorField subset'inin 111 alanı burada tutulur.
];

const THEME_COLOR_REFLECTION_EXCLUDED_FIELDS: &[&str] = &[
    "debugger_accent",
    "editor_debugger_active_line_background",
    "editor_diff_hunk_added_background",
    "editor_diff_hunk_added_hollow_background",
    "editor_diff_hunk_added_hollow_border",
    "editor_diff_hunk_deleted_background",
    "editor_diff_hunk_deleted_hollow_background",
    "editor_diff_hunk_deleted_hollow_border",
    "editor_hover_line_number",
    "element_selection_background",
    "version_control_conflict_marker_ours",
    "version_control_conflict_marker_theirs",
    "version_control_word_added",
    "version_control_word_deleted",
    "vim_helix_jump_label_foreground",
    "vim_helix_normal_background",
    "vim_helix_normal_foreground",
    "vim_helix_select_background",
    "vim_helix_select_foreground",
    "vim_insert_background",
    "vim_insert_foreground",
    "vim_normal_background",
    "vim_normal_foreground",
    "vim_replace_background",
    "vim_replace_foreground",
    "vim_visual_background",
    "vim_visual_block_background",
    "vim_visual_block_foreground",
    "vim_visual_foreground",
    "vim_visual_line_background",
    "vim_visual_line_foreground",
    "vim_yank_background",
];

#[test]
fn theme_color_field_counts_match_zed_pin() {
    assert_eq!(THEME_COLOR_FIELDS.len(), 143);
    assert_eq!(THEME_COLOR_CONTENT_FIELDS.len(), 146);
    assert_eq!(THEME_COLOR_REFLECTION_FIELDS.len(), 111);
}

#[test]
fn only_deprecated_content_fields_are_extra() {
    let runtime: std::collections::BTreeSet<_> =
        THEME_COLOR_FIELDS.iter().copied().collect();
    let content: std::collections::BTreeSet<_> =
        THEME_COLOR_CONTENT_FIELDS.iter().copied().collect();
    let extra: Vec<_> = content.difference(&runtime).copied().collect();
    assert_eq!(
        extra,
        [
            "deprecated_scrollbar_thumb_background",
            "version_control_conflict_ours_background",
            "version_control_conflict_theirs_background",
        ]
    );
}

#[test]
fn reflection_fields_are_zed_subset() {
    let runtime: std::collections::BTreeSet<_> =
        THEME_COLOR_FIELDS.iter().copied().collect();
    let reflection: std::collections::BTreeSet<_> =
        THEME_COLOR_REFLECTION_FIELDS.iter().copied().collect();

    let invalid: Vec<_> = reflection.difference(&runtime).copied().collect();
    assert!(invalid.is_empty(), "unknown reflected fields: {invalid:?}");

    let excluded: Vec<_> = runtime.difference(&reflection).copied().collect();
    assert_eq!(excluded, THEME_COLOR_REFLECTION_EXCLUDED_FIELDS);
}
```

**CI job:**

```yaml
name: theme

on:
  pull_request:
  push:
    branches: [main]

jobs:
  theme:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dtolnay/rust-toolchain@stable
      - run: cargo test -p kvs_tema
      - run: cargo run -p kvs_tema --bin export_schema -- theme > schemas/theme-v0.2.0.json
      - run: cargo run -p kvs_tema --bin export_schema -- icon-theme > schemas/icon-theme-v0.1.0.json
      - run: git diff --exit-code schemas/
      - run: ./scripts/check_theme_licenses.sh
```

**Sync turu kapısı:** `tema_kaymasi_kontrol.sh`, `../zed` reposunu pin
commit'e temizce geri sabitleyip `git pull --ff-only` sonrası yeni Zed
commit'i gösteren bir `zed_farkları*.diff` üretirse CI parite sayıları
değiştirilmeden merge edilmemeli. Alan eklendiyse Konu 13 listesi, Konu 18
content haritası, refinement, fallback, fixture ve bu test sabitleri aynı
PR'da güncellenir.

---

### 43. İleri öğeler: `ColorScale`, `UiDensity`, `LoadThemes`, `ThemeSettingsProvider`, reflection

Bu konu Zed'in `crates/theme` crate'inde **public** olan ancak günlük tema
yüklemesi için zorunlu olmayan yardımcı tipleri toplar. Hepsi opsiyonel;
ama Zed paritesini hedefliyorsan veya gelişmiş özellik (tema editörü,
sistem mod takipli light/dark seçimi, settings dosyasından beslenen
selector) yazmak istiyorsan referans noktasıdır.

> **Mirror disiplini hatırlatması:** Bu öğelerden hangilerini ihraç
> ettiğini `DECISIONS.md`'ye yaz. "Şimdilik gerek yok" diye atlarsan
> ileride mirror'lama maliyeti artar (Bölüm I/Konu 2).

#### 43.1 `LoadThemes` — `init()` için yükleme modu enum'u

**Kaynak:** `crates/theme/src/theme.rs:81`.

Zed'in `init` fonksiyonu hangi temaların `crates/theme/assets/themes/`
altından yükleneceğini bir enum ile kontrol eder:

```rust
pub enum LoadThemes {
    /// Yalnızca fallback (built-in baseline) temalarını yükle
    JustBase,
    /// Tüm bundled tema dosyalarını da yükle
    All(Box<dyn AssetSource>),
}
```

**Karşılığı `kvs_tema`'da:**

```rust
pub enum LoadThemes {
    JustBase,
    All(Box<dyn gpui::AssetSource>),
}

pub fn init(themes_to_load: LoadThemes, cx: &mut App) {
    SystemAppearance::init(cx);

    // ThemeRegistry::new tek imza taşır: AssetSource zorunlu.
    let assets: Box<dyn gpui::AssetSource> = match &themes_to_load {
        LoadThemes::JustBase => Box::new(()),
        LoadThemes::All(assets) => dyn_clone::clone_box(&**assets),
    };
    let registry = Arc::new(ThemeRegistry::new(assets));

    registry.insert_themes([
        fallback::kvs_default_dark(),
        fallback::kvs_default_light(),
    ]);

    if let LoadThemes::All(assets) = themes_to_load {
        if let Err(e) = load_bundled_themes_from_asset_source(&registry, assets.as_ref()) {
            tracing::warn!("bundled tema yüklemesi başarısız: {}", e);
        }
    }

    let default = registry.get("Kvs Default Dark").expect("...");
    let default_icon = registry.default_icon_theme().expect("...");

    // Zed'de set_global pub(crate); mirror'da newtype'ı kendin set
    // edersin veya `init` içeride kalan tek çağıran olur.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(default, default_icon));
}
```

**Ne zaman `JustBase`?**

- Test ortamları (`#[gpui::test]` bağlamında bundled asset'lere gerek yok).
- Headless CLI / batch işler (registry sadece program içi kullanım).
- Minimal binary çıkışı (önyükleme süresini düşürmek).

**Ne zaman `All(...)`?**

- Production uygulama girişi.
- Geliştirme çalışmaları (bundled tema fixture'larıyla doğrulama).

**Yapısal not:** `LoadThemes::All(Box<dyn AssetSource>)` enum içinde
`AssetSource` taşır; `init` çağrısı sırasında `Application::new().with_assets(...)`
ile geçen aynı asset source'u tekrar geçmek zorunda değilsin —
`cx.asset_source()` üzerinden dolaylı erişim de olur. Hangi yolu
seçtiğini Bölüm VII/Konu 33'teki bundling stratejisi belirler.

#### 43.2 `ThemeSettingsProvider` — settings entegrasyon trait'i

**Kaynak:** `crates/theme/src/theme_settings_provider.rs:9`.

Zed'in son sürümlerinde `crates/theme` `crates/theme_settings`'i
**doğrudan tüketmez**; bunun yerine `ThemeSettingsProvider` adlı bir
trait sunar. Settings crate'i bu trait'i implement eder ve
`crates/theme` çalışma zamanında provider'ı sorgular. Bu, soyutlama
yönünü ters çevirir: tema crate'i settings'e bağımlı değil, settings
crate'i tema'ya bir hizmet sunar.

```rust
use gpui::{App, Font, Pixels};

pub trait ThemeSettingsProvider: Send + Sync + 'static {
    fn ui_font<'a>(&'a self, cx: &'a App) -> &'a Font;
    fn buffer_font<'a>(&'a self, cx: &'a App) -> &'a Font;
    fn ui_font_size(&self, cx: &App) -> Pixels;
    fn buffer_font_size(&self, cx: &App) -> Pixels;
    fn ui_density(&self, cx: &App) -> UiDensity;
}

pub fn set_theme_settings_provider(provider: Box<dyn ThemeSettingsProvider>, cx: &mut App);
pub fn theme_settings(cx: &App) -> &dyn ThemeSettingsProvider;
```

**Sözleşme sınırı:** Bu trait aktif tema adını veya aktif icon tema adını
döndürmez. Zed'de provider yalnızca typography/density okumaları için
vardır; selector state'i `ThemeSettingsContent.theme` ve
`ThemeSettingsContent.icon_theme` alanlarından çözülür. Önceki rehber
sürümündeki `agent_font_size`, `active_theme_name` ve
`active_icon_theme_name` metotları Zed public sözleşmesiyle eşleşmez.

**`kvs_tema`'da karşılığı:**

```rust
// kvs_tema/src/settings_provider.rs
use gpui::{App, Font, Pixels};

pub trait TemaAyarSaglayici: Send + Sync + 'static {
    fn ui_font<'a>(&'a self, cx: &'a App) -> &'a Font;
    fn buffer_font<'a>(&'a self, cx: &'a App) -> &'a Font;
    fn ui_font_size(&self, cx: &App) -> Pixels;
    fn buffer_font_size(&self, cx: &App) -> Pixels;
    fn ui_density(&self, cx: &App) -> UiDensity;
}

struct GlobalTemaAyarSaglayici(Box<dyn TemaAyarSaglayici>);
impl Global for GlobalTemaAyarSaglayici {}

pub fn set_tema_ayar_saglayici(provider: Box<dyn TemaAyarSaglayici>, cx: &mut App) {
    cx.set_global(GlobalTemaAyarSaglayici(provider));
}

pub fn tema_ayarlari(cx: &App) -> &dyn TemaAyarSaglayici {
    &*cx.global::<GlobalTemaAyarSaglayici>().0
}
```

**Bağlama akışı:**

```rust
// kvs_uygulama/src/main.rs
struct KvsAyarSaglayici;

impl TemaAyarSaglayici for KvsAyarSaglayici {
    fn ui_font<'a>(&'a self, cx: &'a App) -> &'a Font {
        &kvs_ayarlari::get(cx).ui_font
    }
    fn buffer_font<'a>(&'a self, cx: &'a App) -> &'a Font {
        &kvs_ayarlari::get(cx).buffer_font
    }
    fn ui_font_size(&self, cx: &App) -> Pixels {
        kvs_ayarlari::get(cx).ui_font_size
    }
    fn buffer_font_size(&self, cx: &App) -> Pixels {
        kvs_ayarlari::get(cx).buffer_font_size
    }
    fn ui_density(&self, cx: &App) -> UiDensity {
        kvs_ayarlari::get(cx).ui_density
    }
}

fn main() {
    Application::new().run(|cx| {
        kvs_tema::init(LoadThemes::All(Box::new(KvsAssets)), cx);
        kvs_ayarlari::init(cx);
        kvs_tema::set_tema_ayar_saglayici(Box::new(KvsAyarSaglayici), cx);
        // ...
    });
}
```

**Neden trait?**

- Tema crate'i settings crate'inin tipini bilmez — sadece davranışını
  sözleşme olarak alır.
- Test ortamında `MockTemaAyarSaglayici` enjekte edilir; gerçek settings
  store'u kurmaya gerek kalmaz.
- Settings dosya formatı değişirse (`config.toml` → `settings.json`)
  trait imzası aynı kalır.

**Konu 31 (`temayi_degistir`) ile ilişki:** `temayi_degistir` çağrıldığında
ayar dosyasının da güncellenmesi isteniyorsa `tema_ayarlari(cx)` üzerinden
mutable bir API tasarlanır — Zed'de bu `update_settings_file` tarafından
yapılır; `kvs_tema` settings crate'inin sözleşmesine bağımlı olmadığı
için bu çağrı **tüketici tarafında** kalır.

**`ThemeSettingsContent` alan modeli:**

`crates/settings_content/src/theme.rs` tarafındaki settings şeması provider'dan
daha geniştir; kullanıcı ayar dosyası burada temsil edilir. Pin
`6e8eaab25b5a` için `ThemeSettingsContent` 21 alan taşır:

```text
ui_font_size, ui_font_family, ui_font_fallbacks, ui_font_features,
ui_font_weight, buffer_font_family, buffer_font_fallbacks,
buffer_font_size, buffer_font_weight, buffer_line_height,
buffer_font_features, agent_ui_font_size, agent_buffer_font_size,
markdown_preview_font_family, markdown_preview_theme, theme, icon_theme,
ui_density, unnecessary_code_fade, experimental_theme_overrides,
theme_overrides
```

Bu alanların yardımcı tiplerini de şemaya dahil et:

| Tip | Rol | Kritik sözleşme |
|-----|-----|-----------------|
| `ThemeSettingsContent` | Kullanıcı settings dosyasındaki tema/font/density alanları | 21 alan; `#[serde(default)]` ve `MergeFrom` davranışı korunur |
| `FontSize` | `f32` pixel newtype | serialize ederken iki ondalık basamak |
| `FontFamilyName` | font family adı | `#[serde(transparent)]`, `Arc<str>` |
| `FontFeaturesContent` | OpenType feature map'i | 4 karakter alfanumerik key; boolean veya unsigned integer value |
| `BufferLineHeight` | `comfortable`, `standard`, `custom(f32)` | custom değer `>= 1.0` olmalı |
| `CodeFade` | gereksiz kod fade oranı | schema aralığı `0.0..=0.9` |
| `DEFAULT_LIGHT_THEME` / `DEFAULT_DARK_THEME` | settings fallback adları | `"One Light"` / `"One Dark"` tek kaynak olarak kalmalı |

`agent_ui_font_size` ve `agent_buffer_font_size` provider trait'inde
değildir; agent panel ayarı olarak settings katmanında kalır. `theme`,
`icon_theme`, `markdown_preview_theme`, `experimental.theme_overrides`
ve `theme_overrides` selector/override akışına gider; typography helper'ları
ise provider üzerinden `ui_font`, `buffer_font`, `ui_font_size`,
`buffer_font_size` ve `ui_density` okur.

#### 43.3 `UiDensity` — UI yoğunluk ayarı

**Kaynak:** `crates/theme/src/ui_density.rs:21`.

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UiDensity {
    Compact,
    #[default]
    Default,
    Comfortable,
}
```

**Rol:** Kullanıcının UI'da tercih ettiği yoğunluk — buton paddingleri,
liste item yükseklikleri, panel iç boşlukları bu enuma göre ölçeklenir.

**Tema sözleşmesindeki yeri:** `UiDensity` `Theme` içinde **yok** —
ayrı bir kullanıcı tercihi olarak `TemaAyarSaglayici` üzerinden okunur.
`ThemeColors` ile karıştırma; renk değil, boyut.

**Tüketici kullanım deseni:**

```rust
pub fn density_padding(density: UiDensity) -> Pixels {
    match density {
        UiDensity::Compact     => px(6.0),
        UiDensity::Default     => px(8.0),
        UiDensity::Comfortable => px(12.0),
    }
}

impl Render for Toolbar {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let density = kvs_tema::tema_ayarlari(cx).ui_density(cx);
        let colors = cx.theme().colors();

        div()
            .p(density_padding(density))
            .bg(colors.background)
            .child("...")
    }
}
```

**`bilesen_rehberi.md` ile köprü:** `DynamicSpacing::BaseXX.px(cx)`
helper'ı zaten `UiDensity`'i bilir — `ui::ui_density(cx)` ile şu anki
yoğunluk sorgulanır. Kendi component crate'in varsa `tema_ayarlari(cx).ui_density(cx)`
çağrısını GPUI spacing helper'larına bağla.

**JSON kullanıcı ayarı:**

```jsonc
{
  "ui_density": "comfortable"
}
```

#### 43.4 `all_theme_colors` ve `ThemeColorField` — reflection API

**Kaynak:** `crates/theme/src/styles/colors.rs:346` (`ThemeColorField` enum),
`crates/theme/src/styles/colors.rs:596` (`all_theme_colors` fn).

Tema editörü, color picker, debug inspector veya snapshot testi yazarken
tema renklerini **runtime'da listeyebilmek** istenir. Zed bunu iki yapıyla
sunar:

```rust
use strum::{AsRefStr, EnumIter, IntoEnumIterator};

/// Tema editörü/preview için seçilmiş reflection alt kümesi.
#[derive(EnumIter, Debug, Clone, Copy, AsRefStr)]
#[strum(serialize_all = "snake_case")]
pub enum ThemeColorField {
    Border,
    BorderVariant,
    // ... mevcut Zed pin'inde 111 variant
}

impl ThemeColors {
    pub fn color(&self, field: ThemeColorField) -> Hsla { /* match field */ }
    pub fn iter(&self) -> impl Iterator<Item = (ThemeColorField, Hsla)> + '_ { /* ... */ }
    pub fn to_vec(&self) -> Vec<(ThemeColorField, Hsla)> { /* ... */ }
}

/// Tüm tema renklerini key-value liste olarak döner
pub fn all_theme_colors(cx: &mut App) -> Vec<(Hsla, SharedString)> {
    let theme = cx.theme();
    ThemeColorField::iter()
        .map(|field| {
            let color = theme.colors().color(field);
            let name = field.as_ref().to_string();
            (color, SharedString::from(name))
        })
        .collect()
}
```

**Kritik parite düzeltmesi:** `ThemeColorField`, `ThemeColors`'taki her
alan için variant üretmez. Pin `6e8eaab25b5a` için runtime
`ThemeColors` 143 alan taşır; `ThemeColorField` ise 111 variant'lık
reflection alt kümesidir. Küme ilişkisi şudur:

```text
ThemeColorField labels ⊆ ThemeColors fields
ThemeColorField labels = 111
ThemeColors fields = 143
```

`ThemeColors` içinde olup Zed reflection API'sinde yer almayan 32 alan:

```text
debugger_accent
editor_debugger_active_line_background
editor_diff_hunk_added_background
editor_diff_hunk_added_hollow_background
editor_diff_hunk_added_hollow_border
editor_diff_hunk_deleted_background
editor_diff_hunk_deleted_hollow_background
editor_diff_hunk_deleted_hollow_border
editor_hover_line_number
element_selection_background
version_control_conflict_marker_ours
version_control_conflict_marker_theirs
version_control_word_added
version_control_word_deleted
vim_helix_jump_label_foreground
vim_helix_normal_background
vim_helix_normal_foreground
vim_helix_select_background
vim_helix_select_foreground
vim_insert_background
vim_insert_foreground
vim_normal_background
vim_normal_foreground
vim_replace_background
vim_replace_foreground
vim_visual_background
vim_visual_block_background
vim_visual_block_foreground
vim_visual_foreground
vim_visual_line_background
vim_visual_line_foreground
vim_yank_background
```

**`kvs_tema`'da karşılığı:**

```rust
// kvs_tema/src/styles/colors_reflection.rs
#[derive(Debug, Clone, Copy)]
pub enum ThemeColorField {
    Background,
    Border,
    // ... Zed reflection subset'indeki 111 alan için bir variant
}

impl ThemeColorField {
    // Zed mevcut pin'inde `ALL` const yok; `strum::IntoEnumIterator`
    // kullanılıyor. `kvs_tema` isterse makrodan `ALL` üretebilir.
    pub const ALL: &'static [ThemeColorField] = &[
        ThemeColorField::Background,
        ThemeColorField::Border,
        // ...
    ];

    pub fn label(&self) -> SharedString {
        match self {
            Self::Background => "background".into(),
            Self::Border     => "border".into(),
            // ...
        }
    }

    pub fn value(&self, colors: &ThemeColors) -> Hsla {
        match self {
            Self::Background => colors.background,
            Self::Border     => colors.border,
            // ...
        }
    }
}

pub fn all_theme_colors(cx: &mut App) -> Vec<(Hsla, SharedString)> {
    let colors = cx.theme().colors();
    ThemeColorField::ALL
        .iter()
        .map(|f| (f.value(colors), f.label()))
        .collect()
}
```

**Üretim disiplini:** İki farklı stratejiden birini seç, ama adını doğru
koy:

- **Zed paritesi:** `ThemeColorField` sadece Zed'in 111 alanlık reflection
  subset'ini mirror eder. `ThemeColors` alanları için ayrıca 143 alanlık
  runtime/content parite testi tutulur.
- **Yerel tam reflection:** `ThemeColorField` 143 alanın tamamını kapsar.
  Bu Zed'den bilinçli genişletmedir; `DECISIONS.md`'ye yazılır ve snapshot
  testlerinde `111` değil `143` beklenir.

Elle 111 ya da 143 alan yazmak yorucuysa derive makrosu yazılır:

```rust
#[derive(Refineable, ThemeColorReflect)]
pub struct ThemeColors { /* ... */ }
```

`ThemeColorReflect` derive makrosu `ThemeColorField` enum'unu, `label`
ve `value` impl'lerini otomatik üretir. Zed paritesi seçildiyse 32 alan
`#[theme_color_reflect(skip)]` benzeri bir attribute ile reflection dışı
bırakılır; aksi halde makro yerel genişletme üretir. Refinement makrosuyla
aynı crate (`ui_macros` veya `kvs_macros`) içinde tutulur.

**Kullanım yerleri:**

```rust
// Tema editörü ekranı
fn render_theme_editor(cx: &mut Context<ThemeEditor>) -> impl IntoElement {
    v_flex().children(
        kvs_tema::all_theme_colors(cx).into_iter().map(|(color, label)| {
            h_flex()
                .gap_2()
                .child(div().size(px(20.)).bg(color))
                .child(Label::new(label.clone()))
                .child(Label::new(format!("{:?}", color)))
        })
    )
}
```

```rust
// Snapshot testi
#[test]
fn theme_color_count_matches_zed_pin() {
    assert_eq!(ThemeColorField::ALL.len(), 111);
}
```

Bu test tek başına yeterli değildir; ayrıca `ThemeColorField` label'larının
tamamının gerçek `ThemeColors` alanı olduğunu ve dışarıda kalan 32 alanın
yukarıdaki listeyle birebir eşleştiğini doğrula. Aksi halde yeni eklenen
bir alan sessizce reflection dışında kalabilir veya yanlışlıkla reflection'a
eklenip Zed paritesi bozulabilir.

```rust
// Tema farkı raporu (Reçete 42.5)
let zed: Vec<_> = all_theme_colors_in(theme_a);
let user: Vec<_> = all_theme_colors_in(theme_b);
for ((a, label), (b, _)) in zed.iter().zip(user.iter()) {
    if a != b {
        println!("{}: {:?} → {:?}", label, a, b);
    }
}
```

#### 43.5 `ColorScale` ailesi — 12-adımlı palet sistemi

**Kaynak:** `crates/theme/src/scale.rs`.

Zed'in fallback temalarındaki renk üretim sistemi **Radix UI** color
scales modelinden esinlenir. Her renk ailesi 12 adımlı bir skala olarak
modellenir. Mevcut Zed pin'inde `neutral` alanı yoktur; nötr aileler
`gray`, `mauve`, `slate`, `sage`, `olive`, `sand` gibi ayrı scale set'ler
olarak tutulur. Adım numarası **semantik anlam** taşır:

```rust
pub struct ColorScaleStep(usize);

impl ColorScaleStep {
    pub const ONE: Self = Self(1);    // Ana arka plan
    pub const TWO: Self = Self(2);    // Subtle bg
    pub const THREE: Self = Self(3);  // Normal element bg
    pub const FOUR: Self = Self(4);   // Hover element bg
    pub const FIVE: Self = Self(5);   // Active element bg
    pub const SIX: Self = Self(6);    // Border
    pub const SEVEN: Self = Self(7);  // Strong border
    pub const EIGHT: Self = Self(8);  // Element focus ring
    pub const NINE: Self = Self(9);   // Solid background (accent)
    pub const TEN: Self = Self(10);   // Hover solid bg
    pub const ELEVEN: Self = Self(11);// Low-contrast text
    pub const TWELVE: Self = Self(12);// High-contrast text
}

pub struct ColorScale(Vec<Hsla>);    // 12 Hsla

impl ColorScale {
    pub fn step(&self, step: ColorScaleStep) -> Hsla { /* ... */ }
    pub fn step_1(&self) -> Hsla { /* ... */ }
    // ... step_12 kadar
}

pub struct ColorScaleSet {
    name: SharedString,
    light: ColorScale,
    light_alpha: ColorScale,
    dark: ColorScale,
    dark_alpha: ColorScale,
}

impl ColorScaleSet {
    pub fn new(
        name: impl Into<SharedString>,
        light: ColorScale,
        light_alpha: ColorScale,
        dark: ColorScale,
        dark_alpha: ColorScale,
    ) -> Self;

    pub fn name(&self) -> &SharedString;
    pub fn light(&self) -> &ColorScale;
    pub fn light_alpha(&self) -> &ColorScale;
    pub fn dark(&self) -> &ColorScale;
    pub fn dark_alpha(&self) -> &ColorScale;
    pub fn step(&self, cx: &App, step: ColorScaleStep) -> Hsla;
    pub fn step_alpha(&self, cx: &App, step: ColorScaleStep) -> Hsla;
}

pub struct ColorScales {
    pub gray: ColorScaleSet,
    pub mauve: ColorScaleSet,
    pub slate: ColorScaleSet,
    pub sage: ColorScaleSet,
    pub olive: ColorScaleSet,
    pub sand: ColorScaleSet,
    pub gold: ColorScaleSet,
    pub bronze: ColorScaleSet,
    pub brown: ColorScaleSet,
    pub yellow: ColorScaleSet,
    pub amber: ColorScaleSet,
    pub orange: ColorScaleSet,
    pub tomato: ColorScaleSet,
    pub red: ColorScaleSet,
    pub ruby: ColorScaleSet,
    pub crimson: ColorScaleSet,
    pub pink: ColorScaleSet,
    pub plum: ColorScaleSet,
    pub purple: ColorScaleSet,
    pub violet: ColorScaleSet,
    pub iris: ColorScaleSet,
    pub indigo: ColorScaleSet,
    pub blue: ColorScaleSet,
    pub cyan: ColorScaleSet,
    pub teal: ColorScaleSet,
    pub jade: ColorScaleSet,
    pub green: ColorScaleSet,
    pub grass: ColorScaleSet,
    pub lime: ColorScaleSet,
    pub mint: ColorScaleSet,
    pub sky: ColorScaleSet,
    pub black: ColorScaleSet,
    pub white: ColorScaleSet,
}
```

**Kullanım örneği (Zed `StatusColors::dark()`):**

```rust
impl StatusColors {
    pub fn dark() -> Self {
        Self {
            error: red().dark().step_9(),
            error_background: red().dark().step_9().opacity(0.25),
            error_border: red().dark().step_9(),
            // ...
        }
    }
}
```

`red()` `ColorScaleSet` döner; `.dark()` `ColorScale` seçer; `.step_9()`
solid accent rengini verir.

**`kvs_tema`'da ele alma seçenekleri:**

1. **Skala olmadan, doğrudan `hsla` ile:** Bölüm VII/Konu 32 zaten bu
   yolu anlatıyor. Az tema için yeterli; alanlar arası tutarlılığı
   "anchor hue + opacity" disiplini sağlar.

2. **Minimal scale (`step_*` helper'ları olmadan, sadece sabit):**

   ```rust
   pub struct KvsScale {
       pub step_1: Hsla,
       pub step_2: Hsla,
       // ...
       pub step_12: Hsla,
   }

   pub fn neutral_dark() -> KvsScale {
       KvsScale {
           step_1:  hsla(220.0 / 360.0, 0.06, 0.08, 1.0),
           step_2:  hsla(220.0 / 360.0, 0.06, 0.10, 1.0),
           step_3:  hsla(220.0 / 360.0, 0.06, 0.13, 1.0),
           // ... 12 adım
       }
   }
   ```

3. **Tam Radix-style scale (Zed pariteli):** `crates/theme/src/scale.rs`
   ve `crates/theme/src/default_colors.rs` mirror edilir. Bu **büyük**
   bir iş — `default_color_scales()` 33 renk ailesi için 12 adım ×
   light/dark/alpha matrisini taşır. Kendi temanı sıfırdan tasarlıyorsan
   **kullanma**; sadece Zed'in birebir paletini taklit istiyorsan bu yola
   gir (lisans-temizliği için HSL değerlerini bağımsız üretmen şart;
   Bölüm I/Konu 3).

**Tavsiye:** Çoğu uygulama için Seçenek 1 (Konu 32 anchor disiplini)
yeterli. ColorScale modeli **20+ tema variant** üretmesi gereken design
system'ler için anlamlı; tek dark + tek light için aşırı mühendislik.

**Public domain açık-lisanslı kaynaklar:**

- [Radix UI Colors](https://www.radix-ui.com/colors) — MIT lisansı,
  HSL değerleri açık.
- [Tailwind CSS palette](https://tailwindcss.com/docs/customizing-colors)
  — MIT lisansı.
- [Open Color](https://yeun.github.io/open-color/) — MIT lisansı.

Bunların HSL değerlerini referans alabilirsin; tema'da `ColorScale` ile
modellemek isteğe bağlı.

#### 43.6 `apply_theme_color_defaults` — refinement default'ları

**Kaynak:** `crates/theme/src/fallback_themes.rs:47`.

Konu 25'te `apply_status_color_defaults`'un %25 alpha türetme kuralını
işlemiştik. Zed'in `ThemeColors` için **ikinci** bir default uygulama
fonksiyonu da vardır:

```rust
pub fn apply_theme_color_defaults(
    theme_colors: &mut ThemeColorsRefinement,
    player_colors: &PlayerColors,
) {
    if theme_colors.element_selection_background.is_none() {
        let mut selection = player_colors.local().selection;
        if selection.a == 1.0 {
            selection.a = 0.25;
        }
        theme_colors.element_selection_background = Some(selection);
    }
}
```

**`kvs_tema`'da neden gerekli?**

- `ThemeColorsRefinement` `Option<Hsla>` alanları taşır; refinement
  zincirinde `None` kalan alanlar baseline'dan gelir.
- `element_selection_background` özel bir fallback kuralına sahiptir:
  kullanıcı veya tema bu alanı vermediyse lokal player selection rengi
  alınır; tam opaksa alpha `0.25` yapılır.
- Bu fonksiyon appearance tabanlı genel renk doldurucu değildir. Genel
  `border_disabled`, `text_disabled` gibi alanları otomatik üretmez; böyle
  bir genişletme yapılacaksa Zed pin'inden bağımsız uygulama kararı olarak
  `DECISIONS.md`'ye yazılmalıdır.

**Örnek implementasyon:**

```rust
pub fn apply_theme_color_defaults(
    r: &mut ThemeColorsRefinement,
    player_colors: &PlayerColors,
) {
    if r.element_selection_background.is_none() {
        let mut selection = player_colors.local().selection;
        if selection.a == 1.0 {
            selection.a = 0.25;
        }
        r.element_selection_background = Some(selection);
    }
}
```

**Çağrı sırası (`Theme::from_content` içinde):**

```rust
let baseline_refinement = ThemeColorsRefinement {
    background: Some(baseline.colors().background),
    // ... her alan baseline'dan dolu
    ..Default::default()
};
let user_refinement = theme_colors_refinement(&content.style.colors);

let mut merged = baseline_refinement;
merged.refine(&user_refinement);  // Konu 25 birleştirme

apply_theme_color_defaults(&mut merged, &player_colors);
apply_status_color_defaults(&mut status_merged);
```

Default uygulama refinement birleştirmesinden **sonra**, materyalize
etmeden **önce** gelir. Bu sıra, kullanıcı override'ı varsa onun korunmasını
ve sadece eksik (`None`) alanların doldurulmasını garantiler.

#### 43.7 `deserialize_icon_theme` — IconTheme JSON helper'ı

**Kaynak:** `crates/theme/src/theme.rs:286`.

Konu 17'de icon tema JSON yüklemesini gösterdik. Zed bu işi tek satır
helper'la sarmalar:

```rust
pub fn deserialize_icon_theme(bytes: &[u8]) -> anyhow::Result<IconThemeFamilyContent> {
    serde_json_lenient::from_slice(bytes).context("icon theme deserialize")
}
```

**`kvs_tema`'daki karşılığı:**

```rust
pub fn deserialize_icon_theme(bytes: &[u8]) -> anyhow::Result<IconThemeFamilyContent> {
    serde_json_lenient::from_slice(bytes)
        .with_context(|| "icon tema parse hatası")
}
```

Tek satırlık helper ama:

- `serde_json_lenient` import'unu tüketici crate'den gizler.
- Hata mesajını `anyhow::Context` ile zenginleştirir.
- Sync turunda parser değişirse (örn. `serde_json` ile `comments`
  feature'ı), helper içeride güncellenir; tüketici etkilenmez.

#### 43.8 `font_family_cache` — font ailesi önbellek (kısa not)

**Kaynak:** `crates/theme/src/font_family_cache.rs:18`.

Zed sistem font ailelerini her sorguda yeniden almak yerine bir global
önbellekte tutar:

```rust
pub struct FontFamilyCache {
    state: Arc<RwLock<FontFamilyCacheState>>,
}
```

**Rol:** Settings UI'da font seçici dropdown'u, kullanıcının makinasındaki
fontların listesini gösterir. OS sorgusu pahalı; cache asenkron olarak
init edilir ve sonrasında bellek üzerinden okunur.

Public yüzey:

```rust
impl FontFamilyCache {
    pub fn init_global(cx: &mut App);
    pub fn global(cx: &App) -> Arc<Self>;
    pub fn list_font_families(&self, cx: &App) -> Vec<SharedString>;
    pub fn try_list_font_families(&self) -> Option<Vec<SharedString>>;
    pub async fn prefetch(&self, cx: &gpui::AsyncApp);
}
```

**Tema sözleşmesindeki yer:** Yok — bu tip `kvs_tema` kapsamı dışında
kalabilir. Font ailesi listesini kullanan settings/picker bileşeni
gerekirse `kvs_settings` veya `kvs_ui` crate'inde benzer bir cache
implement edilir.

**Atlama gerekçesi:** Mirror disiplini (Konu 2) `Theme` ve içerdiği
tipleri zorunlu kılar; `FontFamilyCache` bir runtime önbelleği,
sözleşmenin parçası değil. `DECISIONS.md`'ye "FontFamilyCache mirror
edilmedi — kapsam dışı (UI/settings sorumluluğu)" yaz.

#### 43.8.1 Font ayarları runtime API'leri (`adjust_*`, `reset_*`, override global'leri)

**Kaynak modüller:**
`crates/theme_settings/src/settings.rs` ve
`crates/theme_settings/src/theme_settings.rs`.

Zed font ölçeklemesini iki katmanlı çalıştırır: ayar dosyasındaki taban
değer (`ThemeSettings.{ui,buffer,agent_ui,agent_buffer}_font_size`) ve
**runtime override global'leri**. Override global'i set edilmişse
`ThemeSettings::*_font_size(cx)` accessor'ı önce global'i okur, yoksa
settings değerine düşer; bu sayede kullanıcı `cmd-+`/`cmd--` ile font'u
geçici olarak büyütebilir ve settings dosyası yazılmaz.

```rust
// Override global'leri (Pixels newtype'ları):
pub struct BufferFontSize(Pixels);     // settings.rs içinde
pub struct UiFontSize(Pixels);         // settings.rs içinde
pub struct AgentUiFontSize(Pixels);    // settings.rs:108
pub struct AgentBufferFontSize(Pixels);// settings.rs:114

impl Global for BufferFontSize {}      // ... her biri için
```

Public yüzey:

```rust
// Düzenle (callback ile)
pub fn adjust_buffer_font_size(cx: &mut App, f: impl FnOnce(Pixels) -> Pixels);
pub fn adjust_ui_font_size(cx: &mut App, f: impl FnOnce(Pixels) -> Pixels);
pub fn adjust_agent_ui_font_size(cx: &mut App, f: impl FnOnce(Pixels) -> Pixels);
pub fn adjust_agent_buffer_font_size(cx: &mut App, f: impl FnOnce(Pixels) -> Pixels);

// Override'ı kaldır → settings değerine düş
pub fn reset_buffer_font_size(cx: &mut App);
pub fn reset_ui_font_size(cx: &mut App);
pub fn reset_agent_ui_font_size(cx: &mut App);
pub fn reset_agent_buffer_font_size(cx: &mut App);

// ±1 px convenience (theme_settings.rs:420, 426)
pub fn increase_buffer_font_size(cx: &mut App);
pub fn decrease_buffer_font_size(cx: &mut App);

// Yardımcılar (settings.rs)
pub fn clamp_font_size(size: Pixels) -> Pixels;
pub fn adjusted_font_size(size: Pixels, cx: &App) -> Pixels;
pub fn observe_buffer_font_size_adjustment<V: 'static>(
    cx: &mut Context<V>,
    f: impl FnMut(&mut V, &mut Context<V>) + 'static,
) -> Subscription;
pub fn setup_ui_font(window: &mut Window, cx: &mut App) -> gpui::Font;
```

`adjust_*` her zaman aynı 4 adımı izler:

1. `ThemeSettings::get_global(cx).*_font_size(cx)` (veya `*_font_size_settings()`)
   ile **mevcut baz değeri** oku.
2. `cx.try_global::<*FontSize>().map_or(base, |g| g.0)` ile override
   varsa onu, yoksa baz değeri al.
3. Callback'i çağır, sonucu `clamp_font_size` ile `[MIN_FONT_SIZE,
   MAX_FONT_SIZE]` aralığına sıkıştır, `cx.set_global(*FontSize(...))`.
4. `cx.refresh_windows()` çağır.

`reset_*` ise `cx.has_global::<*FontSize>()` ise `remove_global` + `refresh_windows`
çalıştırır; override yoksa no-op'tur (gereksiz redraw yapmaz).

**Settings observer ilişkisi:** `theme_settings::init` içindeki observer
ayar dosyasındaki taban değer değişince override'ı **otomatik olarak
sıfırlar** (`reset_*` çağırır). Yani kullanıcı `cmd-+` ile büyüttüğü font'u
elle settings dosyasını editlerse override drop olur — settings dosyası
"hakikat kaynağı" rolünü korur.

**`kvs_tema` karşılığı:** Bu API ailesi `kvs_tema` runtime crate'inin
değil, **settings/UI köprüsünün** sorumluluğudur. Mirror tarafında üç
strateji var:

| Strateji | Açıklama | Ne zaman |
|----------|----------|----------|
| Provider trait'i genişlet | `TemaAyarSaglayici`'a `adjust_*`/`reset_*` ekle | `kvs_tema` tüketicilerin font değişimini dinlemesi gerekiyorsa |
| Sade newtype mirror | `BufferFontSize` vb. global'leri `kvs_tema_ayarlari` crate'inde tut, `adjust_*`/`reset_*` orada implement et | Settings UI'sı bağımsız crate ise |
| Atla | UI yoksa hiç mirror etme | İlk sürümde, font picker gelmediyse |

`DECISIONS.md`'ye seçilen stratejiyi yaz; sözleşme parite bayrağı bu
fonksiyonların `kvs_tema` public API'sinde olmamasıdır.

#### 43.9 Son public yüzey taraması — küçük ama atlanabilir parçalar

Bu ek kontrol, `crates/theme/src` altındaki public ad ve metodların rehberde
geçip geçmediğini tarayarak bulundu. Aşağıdaki öğeler ana sözleşme kadar
büyük değildir, ama tema crate'i birebir mirror edilecekse karar verilmeden
bırakılmamalıdır.

**Hata kaynağı ve düzeltilen denetim mantığı:** Önceki tarama sadece
"isim rehberde geçiyor mu?" sorusunu sordu. Bu iki sınıf hatayı yakalamaz:

- `ThemeColorField` adının geçmesi, onun 143 `ThemeColors` alanının tamamını
  temsil ettiği anlamına gelmez; Zed'de 111 alanlık alt kümedir.
- `ui_font_size` veya `theme` gibi metod/alan adları birden fazla owner'da
  geçebilir; denetim `Owner::method` ve `Struct.field` düzeyinde yapılmalıdır.

Bundan sonra rehber güncellemesi üç ayrı ilişkiyi doğrular: public isim
varlığı, owner-metot eşleşmesi ve alan kümeleri arasındaki matematiksel
ilişki (`content = runtime + deprecated`, `reflection ⊆ runtime`).

| Öğe | Kaynak | Karar |
| :-- | :-- | :-- |
| `DEFAULT_DARK_THEME` (`theme.rs:45`) ve `DEFAULT_LIGHT_THEME`, `DEFAULT_DARK_THEME` (`settings_content/src/theme.rs:282-283`) | `theme.rs` + `settings_content` | İki ayrı tanım var: `theme.rs` yalnızca `DARK`'ı re-export eder, `settings_content` ikisini de tanımlar (`'One Light'` / `'One Dark'`). Mirror'da **tek kaynak**: `kvs_ayarlari_icerik::theme` sabitleri, `kvs_tema` `pub use` ile yeniden açar |
| `CLIENT_SIDE_DECORATION_ROUNDING`, `CLIENT_SIDE_DECORATION_SHADOW` (`px(10.0)`) | `theme.rs:48-50` | Tema renk sözleşmesi değil; client-side window decoration shadow/corner radius token'ı. `kvs_pencere`/`kvs_ui` tarafına ayrılır; değeri Zed pin'iyle birebir tut (`px(10.0)`) |
| `DEFAULT_ICON_THEME_NAME` | `icon_theme.rs` | Aktif icon theme fallback seçimi için gerekli; icon theme registry mirror ediliyorsa taşınmalı |
| `ThemeNotFoundError`, `IconThemeNotFoundError` | `registry.rs` | Registry public API'sinin typed error yüzeyi; string error'a düşürme |
| `zed_default_themes()` | `fallback_themes.rs` | Test/fallback family üretir; GPL kod gövdesi kopyalanmaz, bağımsız `kvs_default_themes()` yazılır |
| `default_color_scales()` | `default_colors.rs` | 33 scale set'lik palet matrisi; sadece `ColorScale` mirror kararı verilirse taşınır |
| `Theme::darken(color, light_amount, dark_amount)` | `theme.rs` | Appearance'a göre lightness azaltan yardımcı; component tarafında kullanılacaksa helper olarak mirror edilebilir |
| `SystemAppearance::global_mut(cx)` | `theme.rs` | Sistem görünümünü testte veya platform event'inde güncelleme kapısı |
| `ThemeRegistry::insert_themes`, `.clear()` | `registry.rs` | Test, import ve kullanıcı tema yenileme akışında gerekir |
| `ThemeRegistry::register_test_themes`, `.register_test_icon_themes` | `registry.rs` | `test-support` gated helper; üretim API'si olarak expose edilmez |
| `Redistributable değildir: FontFamilyCache` | `font_family_cache.rs` | Sözleşme dışı kalır, ama public metodları 43.8'de not edildi |
| `ThemeSettingsProvider::ui_font`, `.buffer_font` | `theme_settings_provider.rs` | Provider font objesini de verir; sadece font size/density değildir |
| `ThemeSettingsContent` typography alanları | `settings_content/src/theme.rs` | `FontSize`, `FontFamilyName`, `FontFeaturesContent`, `BufferLineHeight`, `CodeFade` Konu 43.2'ye eklendi |
| `ThemeSelection::mode`, `IconThemeSelection::mode` | `theme_settings/src/settings.rs` | Selector UI hangi slot'un aktif olduğunu göstermek için gerekir |
| `GlobalTheme::new`, `.update_theme`, `.update_icon_theme`, `.theme`, `.icon_theme` | `theme.rs` | Zed public API'sinin tamamı. `set_theme_and_icon`, `set_theme`, `set_icon_theme` metotları **yoktur** — set yerine `cx.set_global(GlobalTheme::new(...))` ile init, sonra `update_*` ile değişim |
| `theme_settings::settings::set_theme`, `set_icon_theme`, `set_mode` | `theme_settings/src/settings.rs:233-315` | Kullanıcı `SettingsContent`'i mutate eden public mutator helper'lar. Runtime global'i **değil**; selector confirm akışında dosya yazımından önce çağrılır. Mirror tarafında `kvs_secici` veya `kvs_tema_ayarlari` crate'inde yer alır |
| `theme_settings::settings::appearance_to_mode`, `default_theme` | `theme_settings/src/settings.rs:30, 89` | `Appearance` ↔ `ThemeAppearanceMode` köprüsü ve fallback ad seçimi; selector/observer akışında kullanılır |
| `theme_settings::theme_settings::reload_theme`, `reload_icon_theme`, `load_user_theme`, `deserialize_user_theme`, `refine_theme_family`, `refine_theme`, `merge_player_colors`, `merge_accent_colors`, `increase_buffer_font_size`, `decrease_buffer_font_size` | `theme_settings/src/theme_settings.rs:185-428` | Zed'in JSON→Theme pipeline'ının ve runtime tema reload akışının kanonik fonksiyonları. Konu 26 + Konu 31'de detaylı; bu satır 43.9 denetiminin köprüsü |
| `theme_settings::settings::adjust_buffer_font_size`, `reset_buffer_font_size`, `adjust_ui_font_size`, `reset_ui_font_size`, `adjust_agent_ui_font_size`, `reset_agent_ui_font_size`, `adjust_agent_buffer_font_size`, `reset_agent_buffer_font_size`, `clamp_font_size`, `adjusted_font_size`, `observe_buffer_font_size_adjustment`, `setup_ui_font` | `theme_settings/src/settings.rs` | Runtime font ölçekleme override global'leri ve helper'ları (Konu 43.8.1). Settings UI / shortcut tarafında kullanılır |
| `AgentUiFontSize`, `AgentBufferFontSize` newtype global'leri | `theme_settings/src/settings.rs:108, 114` | Agent panel font override'ı için `Global`-impl'lenmiş `Pixels` newtype'ları (Konu 43.8.1) |
| `theme_settings::schema::syntax_overrides`, `theme_colors_refinement`, `status_colors_refinement` | `theme_settings/src/schema.rs:2343-2540` | Content → Refinement dönüşüm fonksiyonlarının kanonik adları; Konu 24'te işlenir, doğrudan signature 43.9'da kayıt altında |
| `theme_settings::settings::BufferLineHeight` (`Comfortable`, `Standard`, `Custom(f32)`), `value()` | `theme_settings/src/settings.rs:340-369` | `Standard = 1.3`, `Comfortable = 1.618`, `Custom` doğrudan değer. Settings tarafında `f32 >= 1.0` kısıtı (`settings_content/src/theme.rs:452`) |
| `try_parse_color` (`theme/src/schema.rs:1171`) | `theme/src/schema.rs` | Konu 20'de detaylı; 43.9'da public helper olarak teyit edilir |
| `AppearanceContent` (`theme/src/schema.rs:1165`) | `theme/src/schema.rs` | JSON `appearance` alanının enum mirror'ı (`Light` / `Dark`); Konu 18'de kullanılır |

Küçük method yüzeyleri:

```rust
AccentColors::color_for_index(index)
PlayerColors::agent()
PlayerColors::absent()
PlayerColors::read_only()
ThemeColors::to_vec()
UiDensity::spacing_ratio()
ColorScale::step_4()
ColorScale::step_5()
ColorScale::step_6()
ColorScale::step_7()
ColorScale::step_8()
ColorScale::step_10()
ColorScale::step_11()
ColorScaleSet::step_alpha(cx, step)
ThemeSettingsProvider::ui_font(cx)
ThemeSettingsProvider::buffer_font(cx)
ThemeSelection::mode()
IconThemeSelection::mode()
ThemeSelection::name(system_appearance)
IconThemeSelection::name(system_appearance)
ThemeSettings::buffer_font_size(cx)
ThemeSettings::ui_font_size(cx)
ThemeSettings::agent_ui_font_size(cx)
ThemeSettings::agent_buffer_font_size(cx)
ThemeSettings::line_height()
ThemeSettings::apply_theme_overrides(arc_theme)
Theme::darken(color, light_amount, dark_amount)
BufferLineHeight::value()
default_theme(appearance) -> &'static str
appearance_to_mode(appearance) -> ThemeAppearanceMode
clamp_font_size(size) -> Pixels
adjusted_font_size(size, cx) -> Pixels
```

Bu metodlar rehberin ana akışını değiştirmez, fakat tema editörü, collab
renkleri, density ölçümü ve snapshot karşılaştırması yazarken eksik kalırsa
tüketici kodu yeniden Zed kaynağına dönmek zorunda kalır.

Kontrol komutları:

```sh
rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
  ../zed/crates/theme/src -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/theme_pub_names.txt

while read name; do
  rg -q "\\b${name}\\b" tema_rehber.md || echo "${name}"
done < /tmp/theme_pub_names.txt

rg -o '^\\s*pub fn ([A-Za-z0-9_]+)' \
  ../zed/crates/theme/src -g '*.rs' \
  | sed -E 's/.*pub fn ([A-Za-z0-9_]+)/\1/' \
  | sort -u > /tmp/theme_pub_methods.txt

while read name; do
  rg -q "\\b${name}\\b" tema_rehber.md || echo "${name}"
done < /tmp/theme_pub_methods.txt
```

Bu iki komut sadece kaba smoke test'tir. Asıl geçiş kriteri aşağıdaki
owner/metot ve alan kümesi kontrolleridir:

```sh
# Owner + method kontrolü: aynı metod adı farklı owner'da geçebilir.
rg -n '^impl |^\\s*pub fn |^\\s*pub async fn ' \
  ../zed/crates/theme/src ../zed/crates/theme_settings/src ../zed/crates/settings_content/src/theme.rs \
  -g '*.rs'

# Runtime ThemeColors alanları: pin 6e8eaab25b5a için 143.
awk '/^pub struct ThemeColors / {in_s=1; next} in_s && /^}/ {in_s=0} \
  in_s && /^[[:space:]]*pub [a-zA-Z0-9_]+: Hsla,/ { f=$2; sub(/:.*/, "", f); print f }' \
  ../zed/crates/theme/src/styles/colors.rs | sort -u > /tmp/theme_runtime_fields.txt

# JSON content alanları: runtime + 3 deprecated uyumluluk alanı.
awk '/^pub struct ThemeColorsContent / {in_s=1; next} in_s && /^}/ {in_s=0} \
  in_s && /^[[:space:]]*pub [a-zA-Z0-9_]+:/ { f=$2; sub(/:.*/, "", f); print f }' \
  ../zed/crates/settings_content/src/theme.rs | sort -u > /tmp/theme_content_fields.txt

# Reflection alanları: ThemeColorField label'ları runtime'ın alt kümesi olmalı.
awk '/^pub enum ThemeColorField / {in_e=1; next} in_e && /^}/ {in_e=0} \
  in_e && /^[[:space:]]*[A-Z][A-Za-z0-9]+,?$/ { v=$1; sub(/,/, "", v); print v }' \
  ../zed/crates/theme/src/styles/colors.rs \
  | perl -pe 's/([a-z0-9])([A-Z])/$1_$2/g; $_=lc' \
  | sort -u > /tmp/theme_reflection_fields.txt

wc -l /tmp/theme_runtime_fields.txt /tmp/theme_content_fields.txt /tmp/theme_reflection_fields.txt
comm -23 /tmp/theme_runtime_fields.txt /tmp/theme_content_fields.txt
comm -23 /tmp/theme_reflection_fields.txt /tmp/theme_runtime_fields.txt
comm -13 /tmp/theme_runtime_fields.txt /tmp/theme_content_fields.txt
comm -23 /tmp/theme_runtime_fields.txt /tmp/theme_reflection_fields.txt
```

Beklenen sonuç: `wc` çıktısı sırasıyla `143`, `146`, `111` olmalı.
İlk iki `comm` komutu çıktı üretmemeli. Üçüncü `comm` yalnızca
`deprecated_scrollbar_thumb_background`,
`version_control_conflict_ours_background` ve
`version_control_conflict_theirs_background` döndürmeli. Son `comm`,
Konu 43.4'te listelenen 32 reflection dışı alanı döndürmelidir.

---

#### 43 — Özet karar matrisi

| Zed öğesi | `kvs_tema` mirror gerekli mi? | Hangi sürümde? |
|-----------|-------------------------------|----------------|
| `LoadThemes` | Önerilir | Init API'yi finalize ederken |
| `ThemeSettingsProvider` | Settings entegrasyonu için **gerekli** | Tema selector / runtime ayar yapacaksan |
| `UiDensity` | Tema değil, settings — yine de mirror edilmesi gerekir | Spacing tutarlılığı için |
| `all_theme_colors` / `ThemeColorField` | Tema editörü/preview için **gerekli**, başka durumda opsiyonel | Tema editörü yazılırken |
| `ColorScale` ailesi | **Çoğu uygulama için gereksiz** | Sadece geniş tema variant matrisi gerekirse |
| `apply_theme_color_defaults` | Gerekli (Konu 25'in ikiz fonksiyonu) | İlk sürümde |
| `deserialize_icon_theme` | Trivial helper, sarmalama önerilir | Icon tema yüklerken |
| `FontFamilyCache` | Hayır — sözleşme dışı | — |
| `DiagnosticColors` | Editor render path'i kullanıyorsa **gerekli** | Editor entegre olduğunda |
| Registry sabitleri / typed error'lar | Registry mirror ediliyorsa **gerekli** | İlk registry sürümünde |
| `default_color_scales` / `zed_default_themes` | Karara bağlı | Fallback ve scale mirror kararında |

Yukarıdaki öğeleri ekleme/dışlama kararını her sync turunda yeniden
gözden geçir; `tema_aktarimi.md`'nin "Senkron edilMEYEN" tablosunda
"neden dışlandı" notunu güncel tut.

> **Referans:** Bölüm III/Konu 14 (DiagnosticColors detayı), Bölüm V/Konu
> 25 (apply_status_color_defaults), Bölüm VI/Konu 28-31 (runtime),
> Bölüm VII/Konu 32 (fallback tasarımı).

---

# Son

Bu rehber `kvs_tema` ve `kvs_syntax_tema` crate'lerinin **tüm yüzeyini**
9 bölüm ve 43 konuda toplar. Üç temel kural:

1. **Veri sözleşmesinde dışlama yok** — Zed'in tüm alanları mirror edilir
   (Konu 2).
2. **Lisans-temiz çalışma** — kod gövdesi GPL'den kopyalanmaz, sadece
   sözleşme paritesi (Konu 3).
3. **Sync disiplini** — `tema_aktarimi.md` 6-8 haftada bir güncellenir,
   `DECISIONS.md` her kararla beraber yazılır.

Beklenmedik bir durum yaşarsan ilgili Konu'ya git; yoksa Bölüm IX'daki
tuzaklar listesi başlangıç noktasıdır.

---
