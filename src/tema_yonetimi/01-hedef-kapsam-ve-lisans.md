# Hedef, kapsam ve lisans

Bu bölüm, tema sisteminin hangi amaçla kurulduğunu ve sınırlarının nerede
başlayıp nerede bittiğini netleştirir. Özellikle üç soru önemlidir: Hangi
parçalar Zed ile birebir uyumlu tutulacak, hangi parçalar uygulamaya özgü
kalacak ve GPL sınırı nereden geçecek? Sonraki bölümler bu cevapların üzerine
kurulur. Bu yüzden kararları burada açıkça koymak, aynı konuları ileride
tekrar tekrar açmadan ilerlemeyi sağlar.

---

## 1. Üç katmanlı yaklaşım ve büyük resim

**Okuma yönü:** Aşağıdan yukarıya. En altta veri sözleşmesi durur; burada
Zed'in JSON yapısıyla birebir uyum gerekir. Yukarı çıktıkça uygulamanın
kendi karar alanı genişler. Bu yüzden öğrenme sırası da en sıkı kuralların
olduğu yerden başlar, en serbest katmana doğru ilerler.

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

**Veri sözleşmesi (en alt katman) — `mirror`:** Bu katman, Zed'in JSON tema
dosyalarını kayıpsız okuyabilmek için kurulan struct katmanıdır. Alan adları,
JSON anahtarları ve hangi alanın opsiyonel olduğu; hepsi Zed'in
`crates/theme/src/styles/` ve `crates/settings_content/src/theme.rs`
dosyalarındaki yapıyla **aynı şekilde** yazılır. Burada yaratıcı davranılmaz;
hedef, sözleşme paritesini tam sağlamaktır. Bölüm IV ve V bu katmanı anlatır.

**Refinement (orta katman) — `davranış`:** Bu katman, kullanıcının yazdığı
temayı baseline tema ile birleştirir. Kullanıcı teması çoğu zaman eksik
alanlar içerir; fallback tema bu boşlukları doldurur. Zed'in `refineable`
crate'inden gelen `Refineable` derive macro'su, her struct için `Option<T>`
alanlı bir `*Refinement` ikizi üretir. Birleştirme de bu ikiz üzerinden
`original.refine(&refinement)` çağrısıyla yapılır. Foreground rengi var ama
background yok gibi yarı tanımlı durumları tamamlayan yardımcılar da
(`apply_status_color_defaults` ve benzerleri) bu katmandadır. Davranış
Zed'den **öğrenilir**, fakat kod bağımsız sözcüklerle yeniden yazılır; GPL-3
nedeniyle kod gövdesi birebir kopyalanmaz. Bölüm VII bu katmanı anlatır.

**Runtime (en üst katman) — `uygulama tasarımı`:** Aktif temayı `cx.theme()`
ile okumak, `GlobalTheme::update_theme` ile değiştirmek ve sistemin
light/dark modunu izlemek bu katmanın işidir. Bu bölüm tamamen uygulamanın
kendi tasarımına göre şekillenir. Zed'in `crates/theme_settings/` veya
`crates/theme_selector/` crate'lerini taklit etmek gerekmez. Entegrasyon,
uygulamanın kendi config sistemi ve kendi UI'ı üzerinden kurulur. Bölüm VIII
bu katmanı anlatır.

**Bağımlılık yönü:**

```
Runtime  ──depends on──>  Refinement  ──depends on──>  Veri sözleşmesi
                                                       │
                                                       └─> gpui, refineable, collections
```

Ters yön yasaktır: veri sözleşmesi refinement katmanına, refinement da runtime
katmanına referans vermez. Bu kural alt katmanları sakin tutar. Pratikte
anlamı şudur: alt katmandaki struct'lar bir kez oturduktan sonra, üst
katmandaki tasarım kararları onları kırmadan değiştirilebilir.

**Lisans katmanlama:**

| Katman | Lisans tarafı |
|--------|---------------|
| Veri sözleşmesi | Alan adları ve JSON anahtarları telif kapsamında değildir; mirror edilmesi serbesttir |
| Refinement | Davranış öğrenilir, kod bağımsız sözcüklerle yeniden yazılır (GPL-3 kod gövdesinin kopyalanması yasaktır) |
| Runtime | Tamamen uygulamaya özgüdür; Zed'in `theme_settings`/`theme_selector` koduyla hiçbir bağı yoktur |

---

## 2. Temel ilke: veri sözleşmesinde dışlama yok

Zed'in JSON tema sözleşmesindeki **hiçbir alan bilerek dışarıda
bırakılmaz**. `terminal_ansi_*`, editor diff hunk, debugger, vcs, vim, panel,
scrollbar, tab, search ve icon theme alanlarının tamamı mirror struct'larında
**alan olarak bulunur**. Kural basit görünür, ama rehberin geri kalanındaki
birçok kararı belirleyen ana eksen budur.

**Gerekçe:**

- Bu rehber, tüm Zed alanlarını destekleyebilecek bir uygulamayı esas alır.
  Geliştiricinin terminal, debugger veya diff görünümü gibi özellikleri
  ileride ekleyip eklemeyeceği baştan bilinmez. Bu yüzden varsayılan tutum
  "hepsi eklenir" olmalıdır.
- Struct tarafında karşılığı bulunmayan bir alan, Zed JSON'unda
  göründüğünde ya sessizce kaybolur ya da `deny_unknown_fields` açık ise
  deserialize hatasına yol açar. Her iki sonuç da temaların güvenilir
  biçimde yüklenmesini bozar.
- Bir alanın struct içinde tutulmasının, UI tarafından okunmadığı sürece
  **hiçbir maliyeti yoktur** — değer baseline'dan veya kullanıcı temasından
  doldurulur ve yalnızca kullanılmadan bekler. Yani "ileride lazım olur"
  diye alan bırakmanın somut bir bedeli yoktur.

**Bir alanı dışarıda bırakmak için kalıcı ve net bir gerekçe gerekir.**
Örneğin bir lisans çakışması ya da platforma özgü bir kısıt böyle bir gerekçe
olabilir. "Henüz UI'da kullanılmıyor" yeterli değildir. Zed sözleşmesinde
yer alan bir alan, tüketici UI tarafından okunmasa bile mirror struct'ında
yerini korur.

---

## 3. Lisans sınırları

Zed'in tema sistemi **GPL-3.0-or-later** lisansına tabidir. Kod gövdesi
kopyalanamaz. Buna karşılık alan adları, JSON anahtarları ve sözleşme şeması
(yani struct'ların alan dizilimi) telif kapsamında değildir; bunlar mirror
edilebilir. Rehberin "neyi alıyoruz, neyi kendimiz yazıyoruz?" sorusuna
verdiği cevap bu ayrıma dayanır.

**Yapılabilir / Yapılamaz:**

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| Alan adlarını okuyup yeniden yazmak | Kod gövdesini birebir kopyalamak |
| JSON anahtarlarını birebir mirror etmek | Default renk paletini (`default_colors.rs` HSL değerleri) taşımak |
| Doc comment'i bağımsız bir anlatımla yeniden yazmak | Doc comment'i kelime kelime kopyalamak |
| Refinement davranışını anlayıp ayrı bir kodla yeniden yazmak | `fallback_themes.rs`'nin algoritmasını birebir taşımak |
| Fixture testleri için MIT/Apache lisanslı tema JSON'larını, lisans dosyasıyla birlikte kopyalamak | Lisans dosyası olmadan tema JSON'u taşımak |

**Güvenli dependency'ler (hepsi Apache-2.0; Zed workspace'inden alınabilir):**

- `gpui` — UI çatısıdır; `Hsla`, `SharedString`, `HighlightStyle`,
  `App`/`Context`/`Window` ve `Global` trait gibi tip ve servisleri sağlar.
- `refineable` — `#[derive(Refineable)]` macro'sunu sunar; her struct için
  `Option<T>` alanlı bir `*Refinement` ikizi üretir.
- `collections` — Deterministik iteration sırasına sahip `HashMap` ve
  `IndexMap` wrapper'larını barındırır.

**GPL-3 crate'ler (`theme`, `syntax_theme`, `theme_settings`,
`theme_selector`, `theme_importer`, `theme_extension`):** Bu crate'ler
yalnızca referans olarak **okunur**. `Cargo.toml` içine dependency olarak
eklenmez. Bu kural nettir; ihlal edilirse üretilen uygulama da GPL-3
sözleşmesinin altına girer ve bunu sonradan temizlemek zor, masraflı ve
zaman alan bir işe dönüşür.

**Publishing uyarısı:** `gpui`, `refineable` ve `collections` crate'leri Zed
workspace'inde `publish = false` ile işaretlenmiştir. Bu yüzden crates.io
üzerinden yayınlanacak bir crate, dependency listesinde bunları git veya path
dependency olarak taşıyamaz. Bu kısıtla çalışmak için üç yol vardır:

1. **Vendor:** Kaynak kod, lisans ve atribusyon dosyalarıyla birlikte
   uygulamanın kendi monorepo'suna kopyalanır.
2. **Fork yayınlama:** `gpui` ve `refineable` ayrı bir hesap adıyla
   crates.io üzerine yeniden yayınlanır.
3. **Yalnızca dahili kullanım:** Uygulama bir kütüphane olarak değil binary
   olarak dağıtılıyorsa Cargo.toml'da git dep tutmak yeterli olur; çünkü
   bu senaryoda crates.io yayını söz konusu değildir.

**Doc comment yazımı:** Zed kaynak dosyasındaki bir struct alanı mirror
edildiğinde, doc comment orijinaliyle birebir aynı bırakılmaz. Aynı anlam
**bağımsız sözcüklerle** yeniden yazılır. Örnek:

```rust
// Zed'deki orijinal (mirror EDİLMEZ):
/// The color used for the background of a fill element.

// Mirror sürümü (yeniden yazılmış):
/// Dolu (fill) bir element'in arka plan rengi.
pub border: Hsla,
```

---
