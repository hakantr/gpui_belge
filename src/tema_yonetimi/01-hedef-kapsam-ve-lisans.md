# Hedef, kapsam ve lisans

Önce sistemin neden var olduğunu, hangi parçaları birebir mirror edeceğini ve GPL sınırını netleştir.

---

## 1. Üç katmanlı yaklaşım ve büyük resim

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
Yaratıcılık yok; sadece sözleşme parite. Bölüm IV ve V bu katmanı
ele alır.

**Refinement (orta katman) — `davranış`:** Kullanıcının yazdığı tema
(genelde eksik alanlar içeren JSON) ile baseline tema (fallback)
birleştirme mantığı. Zed'in `refineable` crate'inin sağladığı `Refineable`
derive macro'su her struct için `Option<T>` alanlı ikiz bir `*Refinement`
tipi üretir; bunu `original.refine(&refinement)` ile uygularsın. Ek
olarak, foreground rengi verilmiş ama background verilmemiş durumları
otomatik türeten yardımcılar (`apply_status_color_defaults`) bu
katmandadır. Davranışı Zed'den **öğrenirsin**, ama kodunu kendi
sözcüklerinle yazarsın (GPL-3 nedeniyle birebir kopyalama yok). Bölüm VII
bu katmanı ele alır.

**Runtime (en üst katman) — `senin tasarımın`:** `cx.theme()` ile aktif
temayı sorgulama, `GlobalTheme::update_theme` ile değiştirme, sistem light/dark modunu
izleme. Bu katman tamamen senin tasarımındır — Zed'in
`crates/theme_settings/` veya `crates/theme_selector/` crate'lerini
taklit etmek zorunda değilsin. Kendi config sisteminle, kendi UI'nla
entegre edersin. Bölüm VIII bu katmanı ele alır.

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

## 2. Temel ilke: veri sözleşmesinde dışlama yok

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
bir dışlama sebebi değildir; Zed sözleşmesinde yer alan alan, tüketici
UI tarafından okunmasa bile mirror struct'ında bulunur.

---

## 3. Lisans sınırları

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

