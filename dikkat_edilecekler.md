# Dikkat Edilecekler — Rehber Denetim Bulguları ve Yazım Disiplini

Bu dosya, `gpui_belge` deposundaki rehberlerin (`bilesen_rehberi.md`,
`tema_rehber.md`, `rehber.md`, `platform_title_bar_rehberi.md`) sistemli
denetimi sırasında tespit edilen hata kalıplarını, somut bulguları ve yeni
rehber yazımı/güncellemesi için izlenmesi gereken disiplini toplar.

Amaç: aynı hatanın bir daha yapılmaması ve gelecekte rehber yazılırken
veya güncellenirken kontrol listesi olarak kullanılması.

---

## 1. Hata Kategorileri

Beş rehber denetiminden çıkan, **tekrar eden** dört kategori. Bu kalıplar
gelecekte rehber yazılırken/güncellenirken aktif olarak aranmalıdır.

### Kategori A — Tahminle imza yazma

**Tanım:** Public tipin alan listesini, metodun argüman tipini veya
dönüş tipini kaynak doğrulaması yapmadan, "muhtemelen şöyledir" varsayımıyla
yazma.

**Örnekler:**
- `AccentColors(pub Vec<Hsla>)` yazıldı; gerçek `Arc<[Hsla]>`
  (`tema_rehber.md` Konu 16'da düzeltildi).
- `apply_theme_color_defaults(refinement, Appearance)` yazıldı; gerçek
  imza `(refinement, &PlayerColors)` (`tema_rehber.md` Konu 43.6).
- `ThemeRegistry::new()` argümansız varsayıldı; gerçek `new(Box<dyn AssetSource>)`
  (`tema_rehber.md` Konu 27).
- `ThemeColorField::ALL` const'u uyduruldu; gerçek `strum::IntoEnumIterator`
  (`tema_rehber.md` Konu 43.4).
- `ColorScales` içinde `neutral` alanı uyduruldu; gerçek yapı `gray`,
  `mauve`, `slate`, `sage`, `olive`, `sand` ailelerine ayrılmış
  (`tema_rehber.md` Konu 43.5).

**Önleyici disiplin:** Her builder/imza/alan listesi `grep -nE 'pub fn |pub struct'`
ile kaynak dosyadan kopyalanmalı veya satır numarasıyla referans verilmeli.

### Kategori B — Yanlış metot adı

**Tanım:** Bir bileşenin metot adını tahmin etme; benzer adlı bir
metot olduğu için ona dayanarak yanlış ad yazma.

**Örnekler:**
- `AccentColors::color_for` yazıldı; gerçek metot `color_for_index`
  (`tema_rehber.md` Konu 16).
- `SyntaxTheme::style_for` yazıldı; gerçek metot `style_for_name`
  (`tema_rehber.md` Konu 17).
- `ThemeNotFound` / `IconThemeNotFound` (suffix yok) yazıldı; gerçek
  `ThemeNotFoundError` / `IconThemeNotFoundError` (`tema_rehber.md` Konu 27).
- `ThemeRegistry::insert(theme)` çağrısı uyduruldu; gerçek API
  `insert_themes(themes)` veya `insert_theme_families(families)`
  (`tema_rehber.md` Konu 27; rehberde 9 stale çağrı düzeltildi).

**Önleyici disiplin:** Metot adı yazarken `grep -n 'pub fn ' kaynak.rs |
grep ad_parçası` ile gerçek adı doğrula.

### Kategori C — Yanlış davranış yorumu

**Tanım:** Bir bileşenin davranışını kaynak koda bakmadan, makul
varsayımla anlatma.

**Örnekler:**
- `SyntaxTheme::new(...)` `Arc<Self>` döner yazıldı; gerçek dönüş `Self`,
  Arc sarması caller tarafında (`tema_rehber.md` Konu 17).
- `apply_theme_color_defaults` "appearance'a göre genel renk doldurucu"
  diye anlatıldı; gerçekte yalnızca `element_selection_background`
  fallback'ini dolduran tek satırlık fonksiyon (`tema_rehber.md` Konu 43.6).
- `Appearance` ile `WindowAppearance` arasında "direkt cast yok" iddia
  edildi; gerçekte `From<WindowAppearance> for Appearance` impl'i var,
  doğrudan `.into()` çalışır (`tema_rehber.md` Konu 16).
- `WindowHandle::is_active(cx)` `bool` döner gibi gösterildi; gerçek
  dönüş `Option<bool>` (`rehber.md` Konu 9).

**Önleyici disiplin:** Davranış iddiası yazarken implementasyona
`grep -nA N 'pub fn ad'` ile bak. Özellikle if/match dallarını oku.

### Kategori D — Yanlış trait üyeliği

**Tanım:** Bir metodun ait olduğu trait'i tahmin etme; supertrait
zincirini veya inherent impl bloğunu karıştırma.

**Örnekler:**
- `ButtonCommon` trait'inde `.key_binding(...)` ve `.key_binding_position(...)`
  taşıdığı iddia edildi; gerçekte bu iki metot **Button struct'ının
  inherent impl bloğunda** — trait'te değil. `IconButton`, `ButtonLike`,
  `SplitButton` üzerinde **çalışmaz** (`bilesen_rehberi.md` Konu 4).
- `ActiveTheme` trait'inde `icon_theme()` metodu olduğu iddia edildi;
  gerçekte trait yalnızca `theme()` taşır. `cx.icon_theme()` doğrudan
  çalışmaz, `GlobalTheme::icon_theme(cx)` kullanılır (`tema_rehber.md`
  Konu 28).

**Önleyici disiplin:** Trait imzasını rehbere yazarken `grep -nA M
'pub trait Ad' kaynak.rs` ile **tam trait gövdesini** kontrol et;
struct'ın inherent metotları ile trait metotlarını karıştırma.

### Kategori E — Eksik public yüzey

**Tanım:** Kaynakta `pub` olan bir tip veya metot rehberde hiç
geçmiyor. Yazan kişi modülün tüm public yüzeyini taramamış.

**Örnekler:**
- `ParallelAgentsIllustration` AI bileşen olarak public ama rehberde yoktu
  (`bilesen_rehberi.md` denetiminde eklendi).
- `ComponentRegistry`, `ComponentMetadata`, `ComponentStatus`, `ComponentId`,
  `register_component`, `empty_example`, `ComponentExample`,
  `ComponentExampleGroup`, `ComponentFn` — component preview registry
  ekosistemi tamamen eksikti (`bilesen_rehberi.md` denetiminde eklendi).
- `ErasedEditor` trait metotları ve `ErasedEditorEvent` event tipi
  belgelenmemişti (`bilesen_rehberi.md` Konu 5/InputField).
- `DiagnosticColors`, `LoadThemes`, `ThemeSettingsProvider`, `UiDensity`,
  `ColorScale`, `all_theme_colors`, `ThemeColorField`,
  `apply_theme_color_defaults`, `deserialize_icon_theme`,
  `FontFamilyCache` — tema crate'inden 10 önemli public tip eksikti
  (`tema_rehber.md` Konu 43.1-43.9 olarak eklendi).
- `DraggedWindowTab` — native tab drag payload tipi belgelenmemişti
  (`platform_title_bar_rehberi.md` Konu 10'a eklendi).

**Önleyici disiplin:** Her rehberin **prosedürel kapsam doğrulaması**
bölümü olmalı (örn. `bilesen_rehberi.md:8989`). Aşağıdaki Bölüm 5'teki
komutları rehbere ekle ve çıktı boş diff verecek şekilde tut.

### Kategori F — Liste vermekten kaçınma

**Tanım:** "X adet alan/variant var" yazıp listenin kendisini vermemek;
"yaklaşık ~150 alan", "14 × 3 = 42 alan" gibi belirsiz ifadelerle
geçmek.

**Örnekler:**
- `StatusColors` "14 × 3 = 42 alan" yazılmış ama tam liste yokmuş;
  pin SHA için kullanıcı tam listeyi sonradan ekledi (`tema_rehber.md`
  Konu 14).
- `ThemeColorField::ALL.len()` için "143" sayısı uyduruldu; gerçek
  `strum::IntoEnumIterator` 111 alanı taşıyor (`tema_rehber.md` Konu 43.4).
- `ToggleButtonGroupStyle/Size` variant listeleri eksikti
  (`bilesen_rehberi.md` Konu 4).

**Önleyici disiplin:** Sayı yerine listenin kendisini ver. Pin SHA'ya
bağlı sayısal iddialar `tema_aktarimi.md` sözleşmesine bağlanmalı.

---

## 2. Rehber Bazlı Bulgu Tablosu

| Rehber | Hata sayısı | En kritik hata | Karakter |
|---|---|---|---|
| `tema_rehber.md` | ~10 ciddi | `AccentColors` tipi `Vec` vs `Arc<[T]>`; `apply_theme_color_defaults` imzası | Kullanıcı kendi crate'ini tasarlarken tahminle yazılmış (Kategoriler A-E hepsi) |
| `bilesen_rehberi.md` | ~3 | `ButtonCommon` trait'inin `key_binding` taşıdığı varsayımı (Kategori D) | Builder yüzeyi büyük ölçüde doğru; trait sınırı karıştırılmış |
| `rehber.md` | ~2 | `WindowHandle::is_active` `Option<bool>` döner; `window_id()` inherent metot olarak yok (Kategori C) | Davranış iddiaları büyük ölçüde doğru; örnek kod bloklarında imza varsayımı |
| `platform_title_bar_rehberi.md` | 1 eksiklik | `DraggedWindowTab` belgelenmemişti (Kategori E) | Davranış iddiaları satır numaralarıyla referanslı; en doğru rehber |

**Eğilim:** Crate küçüldükçe ve "doğrulama komutları" bölümü olduğunda
hata sayısı düşüyor. Tema rehberinde 10 hata varken platform_title_bar
rehberinde sadece 1 küçük eksiklik kaldı.

---

## 3. Yazım/Güncelleme Disiplini

Yeni bir rehber yazarken veya mevcut rehberi güncellerken bu sırayı
izle. Her madde önceki denetimlerden öğrenilmiş bir kalıbı önler.

### 3.1 Constructor ve builder imzaları

- Her `pub fn ad(...)` imzasını `grep -n 'pub fn ad' kaynak.rs` ile
  doğrudan kopyala.
- Argüman tipi `impl Into<X>` mi yoksa `X` mi karıştırma; her ikisi
  çağrı tarafında benzer görünür ama type inference için fark eder.
- Dönüş tipi `Self` mi, `Arc<Self>` mi, `Option<T>` mi — kaynaktan
  doğrula. (`SyntaxTheme::new` ve `WindowHandle::is_active` hataları
  bu kalıptan).

### 3.2 Trait imzaları

- Trait gövdesini **tam** kontrol et: `grep -nA M 'pub trait Ad'
  kaynak.rs`.
- Supertrait zincirini ayırt et: `pub trait ButtonCommon: Clickable +
  Disableable` derken, trait'in **kendi metotları** ile supertrait'ten
  inherited olanları karıştırma.
- Trait'in metotları ile struct'ın inherent (`impl Struct`) metotlarını
  karıştırma. `Button` struct'ı hem `ButtonCommon` trait'inden hem
  kendi `impl Button {}` bloğundan metot taşır; rehber bu ayrımı
  korumalı.

### 3.3 Enum variant listeleri

- Variant'ların **tam listesi** verilmeli, yorumla geçilmemeli.
- `#[default]` derive'ı varsa hangi variant olduğunu belirt.
- Variant tuple/struct alanları varsa kaynak imzayla bire bir göster
  (`Custom(Hsla)`, `Tinted(TintColor)`, vb.).
- 17+ variantlı enumlarda (örn. `CursorStyle`, `ComponentScope`) tam
  listenin tek bir code block içinde verilmesi tercih edilir.

### 3.4 Davranış iddiaları

- "X yaparsa Y olur" iddiası yazılırken kaynak dosyadaki implementasyona
  bak: `grep -nA N 'pub fn ad' kaynak.rs`.
- İf/match dallarını oku — özellikle "disabled durumda", "selected
  durumda", "x mode'da" gibi koşullar.
- "X dönerse Y olur" iddiası yazılırken dönen tipi kontrol et;
  `Option<bool>` ile `bool` arasındaki fark kullanıcının kodu
  derlenmediğinde anlamlı bir bug.

### 3.5 Public yüzey kapsamı

- Rehbere başlamadan önce hedef crate'in `pub` adlarını tara:

  ```sh
  rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
    ../zed/crates/HEDEF_CRATE/src -g '*.rs' \
    | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
    | sort -u
  ```

- Rehber yazımı bittikten sonra **tekrar tara** ve rehber içinde
  geçmeyen adı raporla:

  ```sh
  while read name; do
    rg -q "\\b${name}\\b" REHBER.md || echo "EKSİK: ${name}"
  done < /tmp/pub_names.txt
  ```

- Çıktı boş diff vermiyorsa ya rehbere ekle ya da "kasıtlı atlama
  listesi"ne yaz (örn. `bilesen_rehberi.md:9008`).

### 3.6 Örnek kod blokları

- Örnek kod bloğu yazarken **tüm imzalardan emin ol**: constructor
  argümanları, dönüş tipi, trait import'u.
- `let id = handle.window_id();` gibi tek satırlık örnek bile
  derlenmeden yazılırsa kullanıcı için bug oluşturur.
- Mümkünse örnek kod bloklarını `cargo check --example` formuna sok
  veya en azından mental olarak `rustc` çalıştır.

### 3.7 Sayı vs liste

- "X adet alan/variant var" yazma; listeyi ver veya verme.
- Sayısal iddialar (özellikle pin SHA bağımlı) `tema_aktarimi.md` sync
  disiplinine bağlanmalı.

---

## 4. Prosedürel Kontrol Komutları (her rehber için)

### 4.1 `bilesen_rehberi.md`

```sh
# UI crate public adları
rg -o '^pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)' \
  ../zed/crates/ui/src/components \
  ../zed/crates/ui/src/styles \
  ../zed/crates/ui/src/traits \
  ../zed/crates/ui/src/utils.rs \
  ../zed/crates/ui/src/utils \
  -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/ui_pub.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/ui_pub.txt

# GPUI elements public adları
rg -o '^pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)' \
  ../zed/crates/gpui/src/elements -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/gpui_el_pub.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/gpui_el_pub.txt

# component + ui_input crate'leri
rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
  ../zed/crates/component/src ../zed/crates/ui_input/src -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/comp_in_pub.txt

while read name; do
  rg -q "\\b${name}\\b" bilesen_rehberi.md || echo "${name}"
done < /tmp/comp_in_pub.txt
```

**Bilinen kasıtlı atlamalar:** `InputFieldStyle` (private alanlı public
struct), `COMPONENT_DATA` (LazyLock global).

### 4.2 `tema_rehber.md`

```sh
rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
  ../zed/crates/theme/src ../zed/crates/syntax_theme/src \
  -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/theme_pub.txt

while read name; do
  rg -q "\\b${name}\\b" tema_rehber.md || echo "${name}"
done < /tmp/theme_pub.txt
```

**Bilinen kasıtlı atlamalar:** `one_dark` (cfg-test helper).

### 4.3 `rehber.md`

```sh
rg -o '^pub (struct|enum|trait|fn|type) ([A-Za-z0-9_]+)' \
  ../zed/crates/gpui/src -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/gpui_pub.txt

while read name; do
  rg -q "\\b${name}\\b" rehber.md || echo "${name}"
done < /tmp/gpui_pub.txt
```

### 4.4 `platform_title_bar_rehberi.md`

```sh
rg -o '^pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)' \
  ../zed/crates/platform_title_bar/src -g '*.rs' \
  | sed -E 's/.*pub (struct|enum|trait|fn|type|const|static) ([A-Za-z0-9_]+)/\2/' \
  | sort -u > /tmp/tb_pub.txt

while read name; do
  rg -q "\\b${name}\\b" platform_title_bar_rehberi.md || echo "${name}"
done < /tmp/tb_pub.txt
```

### 4.5 Tüm rehberler için ortak komut

Yeni bir bileşen/tip eklendiğinde tüm rehberleri tek tarama ile kontrol:

```sh
for rehber in bilesen_rehberi.md tema_rehber.md rehber.md platform_title_bar_rehberi.md; do
  echo "=== ${rehber} ==="
  # rehbere göre ilgili crate listesini yukarıdaki bloklardan al
done
```

---

## 5. CI Adımı Önerisi

Hata kalıbı dersi: **rehber içindeki örnek kod bloklarının derlenebilir
olmaması en yaygın kullanıcı bug'ı kaynağıdır.** Aşağıdaki CI adımı bu
kalıbı tamamen önler.

### 5.1 Örnek kod bloklarını derlet

Her rehberin örneklerini `examples/rehber_ad_xx.rs` formuna sok ve CI'da
`cargo check --example` çalıştır:

```yaml
- name: Rehber örnekleri derlenir mi?
  run: |
    cargo check --workspace --examples
```

Bu sayede:
- `let id = handle.window_id();` (gerçekte derlenmez) PR'da yakalanır.
- `registry.insert(theme)` (gerçekte `insert_themes`) PR'da yakalanır.
- `AccentColors(vec![accent])` (gerçek tip `Arc<[Hsla]>`) PR'da
  yakalanır.

### 5.2 Public yüzey diff'i

CI'da her rehber için public ad tarama komutunu çalıştır; boş diff
beklenir. Çıktı varsa PR fail eder.

### 5.3 Pin SHA güncelleme akışı

Pin SHA bağımlı sayısal iddialar (örn. "111 alan", "143 alan",
"42 alan") için ayrı CI job:

```yaml
- name: Sayısal iddialar pin'le uyumlu mu?
  run: cargo test -p kvs_tema -- field_counts
```

Test:
```rust
#[test]
fn theme_color_field_count() {
    assert_eq!(ThemeColorField::iter().count(), 111);
}
```

---

## 6. Geriye Dönük Düzeltme Sırası

Eğer bir rehberi tekrar denetlersen şu sırayı izle (en yüksek
hata-yoğunluğu olan kategoriden başla):

1. **Constructor + builder imzaları** — `grep -nE 'pub fn ' kaynak.rs`
   çıktısını rehberle karşılaştır.
2. **Trait imzaları** — `grep -nA M 'pub trait '` ile tam gövde oku.
3. **Enum variant listeleri** — `grep -nA N 'pub enum '` ile tüm
   variantları tara.
4. **Davranış iddiaları** — implementasyon kodunu oku, if/match
   dallarını doğrula.
5. **Public yüzey kapsamı** — Bölüm 4'teki komutları çalıştır, boş
   diff bekle.
6. **Örnek kod blokları** — her örneği bir kez `cargo check` ile
   derlet (varsa).

---

## 7. Memory ve Kayıt Disiplini

Bu dosyaya yeni bulgu eklenirken:

- **Tarih ve denetim turu** belirt (örn. "2026-05-12 — beş rehber
  denetimi").
- **Kategori** ile etiketle (A-F'den birini seç).
- **Somut örnek** ver (dosya:satır referansı dahil).
- **Önleyici disiplin** öner — bu hata bir daha nasıl önlenir?

Rehber yazarken/güncellerken bu dosyayı **önce oku**; en yaygın hata
kalıplarına karşı dikkatli ol.

---

## 8. Bu Dosyanın Bakım Sözleşmesi

- Yeni bir rehber denetimi yapılırsa bulgular yukarıdaki kategorilere
  eklenir.
- "Bölüm 4 — Prosedürel Kontrol Komutları"na yeni rehber için tarama
  bloğu eklenir.
- Tekrar eden hatalar varsa "Bölüm 1 — Hata Kategorileri" listesi
  genişletilir.
- "Bilinen kasıtlı atlamalar" alt notu güncellenir.
