# Hedef, kapsam ve lisans

Bu bölüm; sistemin neden var olduğunu, hangi parçalarının birebir mirror
edileceğini ve GPL sınırının tam olarak nereden geçtiğini netleştirmek için
ayrılmıştır. Geri kalan bölümler bu üç temel kararın üzerine inşa edilir;
bu yüzden buradaki seçimlerin sonraki bölümlerde defalarca yeniden açılması
yerine, bir kere oturtulup geçilmesi iş akışını belirgin biçimde
hafifletir.

---

## 1. Üç katmanlı yaklaşım ve büyük resim

**Okuma yönü:** Aşağıdan yukarıya. En altta veri sözleşmesi yer alır ve bu
katman mirror disiplini gerektirir; üstteki katmanlar ise giderek artan bir
tasarım özgürlüğüyle yazılır. Bu yüzden öğrenme sırası, kuralların en sıkı
olduğu yerden serbestliğin en yüksek olduğu yere doğru ilerler.

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
birebir parse edebilmek için kurulan struct katmanıdır. Alan adları, JSON
anahtarları ve opsiyonellik dereceleri; hepsi Zed'in
`crates/theme/src/styles/` ve `crates/settings_content/src/theme.rs`
dosyalarındaki yapıyla **aynı şekilde** yazılır. Bu katmanda yaratıcılığa
yer yoktur; tek hedef sözleşme paritesinin tam olarak sağlanmasıdır. Bölüm
IV ve V bu katmanı ele alır.

**Refinement (orta katman) — `davranış`:** Kullanıcının yazdığı tema
(genellikle eksik alanlar içeren bir JSON) ile baseline temayı (fallback)
birleştiren mantığı barındırır. Zed'in `refineable` crate'inden gelen
`Refineable` derive macro'su her struct için `Option<T>` alanlı ikiz bir
`*Refinement` tipi üretir; birleştirme bu ikiz üzerinden
`original.refine(&refinement)` çağrısıyla yapılır. Ayrıca foreground rengi
tanımlı ama background tanımsız gibi yarı belirlenmiş durumları otomatik
türeten yardımcılar (`apply_status_color_defaults` ve benzerleri) da bu
katmana aittir. Davranış Zed'den **öğrenilir**, ama kod bağımsız
sözcüklerle yeniden yazılır (GPL-3 nedeniyle birebir kopyalama söz konusu
değildir). Bölüm VII bu katmanı ele alır.

**Runtime (en üst katman) — `uygulama tasarımı`:** Aktif temayı
`cx.theme()` ile sorgulama, `GlobalTheme::update_theme` ile değiştirme ve
sistem light/dark modunu izleme gibi işler bu katmanda toplanır. Katmanın
tamamı uygulamanın kendi tasarımına bırakılmıştır; Zed'in
`crates/theme_settings/` veya `crates/theme_selector/` crate'lerini taklit
etme zorunluluğu yoktur. Entegrasyon, uygulamanın kendi config sistemi ve
kendi UI'ı üzerinden kurulur. Bölüm VIII bu katmanı ele alır.

**Bağımlılık yönü:**

```
Runtime  ──depends on──>  Refinement  ──depends on──>  Veri sözleşmesi
                                                       │
                                                       └─> gpui, refineable, collections
```

Ters yön yasaktır: veri sözleşmesi asla refinement katmanına, refinement de
asla runtime katmanına referans vermez. Bu kural sayesinde üst katmanlarda
değişiklik yapılırken alt katmanların hareketsiz kalması garanti altına
alınır. Pratikte bunun anlamı şudur: alt katmanlardaki struct'lar
sabitlendikten sonra, üst katmanlardaki tasarım kararları onları kırmadan
istenildiği gibi değiştirilebilir.

**Lisans katmanlama:**

| Katman | Lisans tarafı |
|--------|---------------|
| Veri sözleşmesi | Alan adları ve JSON anahtarları telif kapsamında değildir; mirror edilmesi serbesttir |
| Refinement | Davranış öğrenilir, kod bağımsız sözcüklerle yeniden yazılır (GPL-3 kod gövdesinin kopyalanması yasaktır) |
| Runtime | Tamamen uygulamaya özgüdür; Zed'in `theme_settings`/`theme_selector` koduyla hiçbir bağı yoktur |

---

## 2. Temel ilke: veri sözleşmesinde dışlama yok

Zed'in JSON tema sözleşmesinde yer alan **hiçbir alan kasıtlı olarak
dışarıda bırakılmaz**: `terminal_ansi_*`, editor diff hunk, debugger, vcs,
vim, panel, scrollbar, tab, search, icon theme; bunların tamamı mirror
struct'larında **alan olarak bulunur**. Bu, görünüşte basit bir kural gibi
dursa da rehberin geri kalanındaki birçok kararı belirleyen ana eksendir.

**Gerekçe:**

- Bu rehber, tüm Zed alanlarını destekleyebilecek bir uygulamayı varsayar.
  Geliştiricinin hangi özellikleri (terminal, debugger, diff görünümü vb.)
  ileride ekleyip eklemeyeceği önceden bilinemediği için varsayılan tutum
  "hepsi eklenir" şeklindedir.
- Struct tarafında karşılığı bulunmayan bir alan, Zed JSON'unda
  göründüğünde ya sessizce kaybolur ya da `deny_unknown_fields` açık ise
  deserialize hatasına yol açar. Her iki sonuç da temaların güvenilir
  biçimde yüklenmesini bozar.
- Bir alanın struct içinde tutulmasının, UI tarafından okunmadığı sürece
  **hiçbir maliyeti yoktur** — değer baseline'dan veya kullanıcı temasından
  doldurulur ve yalnızca kullanılmadan bekler. Yani "ileride lazım olur"
  diye alan bırakmanın somut bir bedeli yoktur.

**Bir alanı dışarıda bırakma kararı kalıcı ve net bir gerekçe gerektirir**
(örneğin bir lisans çakışması ya da platforma özgü bir kısıt). "Henüz UI'da
kullanılmıyor" şeklindeki bir gerekçe yeterli sayılmaz; Zed sözleşmesinde
yer alan bir alan, tüketici UI tarafından okunmasa bile mirror struct'ında
yerini korur.

---

## 3. Lisans sınırları

Zed'in tema sistemi **GPL-3.0-or-later** lisansına tabidir. Kod gövdesinin
kopyalanmasına izin verilmez; ancak alan adları, JSON anahtarları ve
sözleşme şeması (yani struct'ların alan dizilimi) telif kapsamında
değildir ve mirror edilebilir. Bu ayrım, rehberin "neyi alıp neyi kendisi
yazacağı" sorusunun cevabını oluşturur.

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
yalnızca referans amacıyla **okunur**. `Cargo.toml` içine dependency olarak
asla eklenmez. Kural keskindir; ihlal edildiğinde üretilen uygulamanın
kendisi otomatik olarak GPL-3 sözleşmesinin altına girer ve geri dönüşü
oldukça zahmetli bir lisans temizliği gerektirir.

**Publishing uyarısı:** `gpui`, `refineable` ve `collections` crate'leri
Zed workspace'inde `publish = false` ile işaretlenmiştir. Bu yüzden
crates.io üzerinden yayınlanmak istenen bir crate'in dependency listesinde
bunlar git veya path dep olarak yer alamaz. Kısıtın etrafından dolaşmak
için üç yol vardır:

1. **Vendor:** Kaynak kod, lisans ve atribusyon dosyalarıyla birlikte
   uygulamanın kendi monorepo'suna kopyalanır.
2. **Fork yayınlama:** `gpui` ve `refineable` ayrı bir hesap adıyla
   crates.io üzerine yeniden yayınlanır.
3. **Yalnızca dahili kullanım:** Uygulama bir kütüphane olarak değil binary
   olarak dağıtılıyorsa Cargo.toml'da git dep tutmak yeterli olur; çünkü
   bu senaryoda crates.io yayını söz konusu değildir.

**Doc comment yazımı:** Zed kaynak dosyasındaki bir struct alanı mirror
edildiğinde, doc comment orijinaliyle birebir aynı tutulmaz; aynı anlam
**bağımsız sözcüklerle** yeniden yazılır. Örnek:

```rust
// Zed'deki orijinal (mirror EDİLMEZ):
/// The color used for the background of a fill element.

// Mirror sürümü (yeniden yazılmış):
/// Dolu (fill) bir element'in arka plan rengi.
pub border: Hsla,
```

---
