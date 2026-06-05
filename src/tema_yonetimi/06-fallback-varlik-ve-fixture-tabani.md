# Yedek tema, varlık ve örnek veri tabanı

Tema üretmeye başlamadan önce üç temel zemin kurman gerekir: lisans açısından temiz yedek tema, uygulamayla gelen yerleşik varlıklar ve test örnek veri tabanı. Refinement akışını bu tabanın üzerine uygularsın. Bu yüzden burada verilen kararlar sonraki bölümlerin dayandığı zemini oluşturur.

---

## 25. Yedek tema tasarımı

**Kaynak modül:** `kvs_tema/src/fallback.rs`.

Yedek temalar çalışma zamanı için bir **güvenlik ağıdır**. Kullanıcı temasının yüklenmesi başarısız olsa bile uygulama açılabilmelidir. Bu yüzden tema kaydında her zaman en az **iki tema** hazır bulunur: biri açık, biri koyu.

### Rol ve sözleşme

| Soru | Cevap |
| ------ | ------- |
| Kaç adet yedek tema bulunur? | **2 — `kvs_default_dark` ve `kvs_default_light`** |
| Kim ne zaman çağırır? | `kvs_tema::init`; ayrıca `Theme::from_content` çağrısında taban argümanı olarak |
| Lisans? | **Uygulamanın kendi lisansı** — Zed'in paletini taşımak yasaktır |
| Hangi alan eksik kalabilir? | **Hiçbiri** — tüm `ThemeColors`/`StatusColors` alanları açık değer almalıdır |
| Ne zaman değişir? | Tasarım dili veya izlenen Zed tema sözleşmesi yeni bir alan gerektirdiğinde |

### Palet seçimi disiplini

Zed'in `default_colors` dosyasındaki HSL değerleri **GPL-3 telif altındadır**. Bunlar birebir kopyalanamaz. Güvenli ilerlemek için iki yol vardır:

**1. Sıfırdan tasarım:** Tek bir "çapa hue" belirlenir ve türetme kuralları bu ana rengin üzerine kurarsın.

```rust
pub fn kvs_default_dark() -> Theme {
    // Çapa renkler — tüm türetmelerin başlangıcı
    let ana_renk_tonu = 220.0;  // mavi-gri (tasarımcının kendi seçimi)
    let arka_plan     = hsla(ana_renk_tonu / 360.0, 0.10, 0.12, 1.0);
    let yuzey         = hsla(ana_renk_tonu / 360.0, 0.10, 0.15, 1.0);
    let yukseltilmis  = hsla(ana_renk_tonu / 360.0, 0.10, 0.18, 1.0);
    let metin         = hsla(ana_renk_tonu / 360.0, 0.05, 0.92, 1.0);
    let soluk_metin   = hsla(ana_renk_tonu / 360.0, 0.05, 0.65, 1.0);
    let kenarlik      = hsla(ana_renk_tonu / 360.0, 0.10, 0.25, 1.0);
    let vurgu         = hsla(210.0 / 360.0, 0.75, 0.60, 1.0);

    Theme { /* ... */ }
}
```

**Çapa hue stratejisi:** Tüm nötr renkler (arka plan/yüzey/yükseltilmiş/metin/kenarlık) aynı hue'dan beslenir; yalnızca **lightness** değişir. Bu monokrom temel, temanın dağınık görünmesini engeller ve tutarlı bir zemin sağlar.

**2. Açık lisanslı paletten esinlenme:** Tailwind, Catppuccin, Nord, Solarized gibi paletlerin HSL değerleri **public domain veya açık lisanslı** olabilir. Bu kaynakları kullanabilirsin; ancak şu üç nokta gözetilmelidir:

- Lisans dosyasının `LICENSES/` altına eklenmesi.
- Esin kaynağının tema atıflarında belirtilmesi.
- HSL değerlerinin birebir kopyalanması yerine **ondalık hassasiyetinin farklılaştırılması** (kararın bağımsız bir tasarım kararı olduğunun görünür kılınması).

### Türetme kalıpları

Baz renklerden `opacity()` ile varyant üretmek, tutarlılığı doğal şekilde sağlar:

```rust
ThemeColors {
    background: arka_plan,
    surface_background: yuzey,
    elevated_surface_background: yukseltilmis,
    border: kenarlik,
    border_variant: kenarlik.opacity(0.5),      // %50 alpha
    border_focused: vurgu,                      // vurgu tam
    border_selected: vurgu.opacity(0.5),        // vurgu yarı
    border_transparent: hsla(0., 0., 0., 0.),  // tamamen şeffaf
    border_disabled: kenarlik.opacity(0.3),     // devre dışı için soluk
    element_background: yuzey,
    element_hover: yukseltilmis,                // bir tık yukarı
    element_active: yukseltilmis.opacity(0.8),  // basılınca hafif soluklaşma
    element_selected: vurgu.opacity(0.3),       // seçim arka planı
    element_selection_background: vurgu.opacity(0.25),  // durum ön plan/arka planıyla uyumlu
    element_disabled: yuzey.opacity(0.5),
    // ghost = şeffaf arka planlı element
    ghost_element_background: hsla(0., 0., 0., 0.),
    ghost_element_hover: yukseltilmis,
    ghost_element_active: yukseltilmis.opacity(0.8),
    ghost_element_selected: vurgu.opacity(0.3),
    ghost_element_disabled: hsla(0., 0., 0., 0.),
    drop_target_background: vurgu.opacity(0.2),
    drop_target_border: vurgu,
    text: metin,
    text_muted: soluk_metin,
    text_placeholder: soluk_metin.opacity(0.7),
    text_disabled: soluk_metin.opacity(0.5),
    text_accent: vurgu,
    icon: metin,                                // metin ile aynı
    icon_muted: soluk_metin,
    icon_disabled: soluk_metin.opacity(0.5),
    // ... kalan tüm alanlar
}
```

**Görülen örüntüler:**

- `border` / `border_variant` / `border_disabled` → tek bir kenarlık çapası ve opacity türevleri.
- `element_*` / `ghost_element_*` → yüzey, yükseltilmiş yüzey ve vurgu karışımları.
- `text_*` / `icon_*` → tek bir metin + soluk metin çapası üzerinden opacity türetmeleri.

Bu disiplin sayesinde yeni bir alan geldiğinde "hangi çapadan türetilmeli?" sorusu hızlıca cevaplanır.

### Durum renkleri için ayrı fonksiyon

```rust
fn durum_renkleri_koyu() -> StatusColors {
    let kirmizi = hsla(0.0   / 360.0, 0.7,  0.6,  1.0);
    let yesil   = hsla(140.0 / 360.0, 0.45, 0.55, 1.0);
    let sari    = hsla(45.0  / 360.0, 0.85, 0.6,  1.0);
    let mavi    = hsla(210.0 / 360.0, 0.7,  0.6,  1.0);

    StatusColors {
        error: kirmizi,
        error_background: kirmizi.opacity(0.2),
        error_border: kirmizi.opacity(0.5),

        warning: sari,
        warning_background: sari.opacity(0.2),
        warning_border: sari.opacity(0.5),

        info: mavi,
        info_background: mavi.opacity(0.2),
        info_border: mavi.opacity(0.5),

        success: yesil,
        success_background: yesil.opacity(0.2),
        success_border: yesil.opacity(0.5),

        // Kalan durumlar aynı çapalarla açıkça doldurulur:
        // conflict, created, deleted, hidden, hint, ignored, modified,
        // predictive, renamed, unreachable.
    }
}
```

> **Uyarı:** Eksik alanlar `..unsafe { std::mem::zeroed() }` veya `..Default::default()` ile **doldurulmamalıdır**. `Hsla::default()` = `(0, 0, 0, 0)` değerini verir ve bu UI'da görünmez. **Tüm 42 alanın açık değerle doldurulması** beklenir. Yukarıdaki blok kısaltılmıştır; gerçek `StatusColors` literal'inde kalan 10 durum (`conflict`, `created`, `deleted`, `hidden` vb.) için de aynı kalıp açıkça yazılır. Seçilen çapalar (`red`, `green`, `yellow`, `blue`) çoğu durumda yeterlidir; her durum bu çapalardan birine eşlenebilir. Örneğin `modified = yellow`, `deleted = red`, `created = green`.

**Açık eşleniği** (`durum_renkleri_acik()`): Aynı çapa renkler kullanırsın. Yalnızca **lightness değerleri biraz koyulaşır**; böylece açık arka plan üzerinde okunaklılık korunur. Arka plan ve kenarlık opacity'leri de açık zemine göre biraz daha düşük tutulur.

```rust
fn durum_renkleri_acik() -> StatusColors {
    // Açık arka planda kontrast için lightness 0.45–0.50 (koyuda 0.55–0.60)
    let kirmizi = hsla(0.0   / 360.0, 0.7,  0.45, 1.0);
    let yesil   = hsla(140.0 / 360.0, 0.45, 0.40, 1.0);
    let sari    = hsla(45.0  / 360.0, 0.85, 0.45, 1.0);
    let mavi    = hsla(210.0 / 360.0, 0.7,  0.45, 1.0);

    StatusColors {
        error: kirmizi,
        error_background: kirmizi.opacity(0.15), // açık arka planda alfa daha düşük
        error_border: kirmizi.opacity(0.4),

        warning: sari,
        warning_background: sari.opacity(0.15),
        warning_border: sari.opacity(0.4),

        info: mavi,
        info_background: mavi.opacity(0.15),
        info_border: mavi.opacity(0.4),

        success: yesil,
        success_background: yesil.opacity(0.15),
        success_border: yesil.opacity(0.4),

        // ... 14 × 3 = 42 alan — koyudaki çapa eşlemesi aynı,
        // sadece lightness ve opacity açık arka plana uyarlı
    }
}
```

**Light ile dark durum renk kuralları:**

| Boyut | Koyu | Açık |
| ------- | ------ | ------- |
| Ön plan lightness | 0.55–0.60 | 0.40–0.50 (koyu arka plana karşı doygun) |
| Arka plan opacity | 0.20 | 0.15 (açık yüzeyde aşırı dolgu olmaması için) |
| Border opacity | 0.50 | 0.40 |
| Saturation | aynı (her iki tarafta da doygunluk korunur) |

### Syntax yedeği — temel kategoriler

`SyntaxTheme::new(vec![])` ile boş bir liste verilirse kod görünümünde tüm token'lar varsayılan text rengiyle çizilir. Sonuç renksiz ve okunması zor bir kod görünümüdür. En azından **8 temel kategorinin** doldurulması iyi bir başlangıçtır:

```rust
fn sozdizimi_temasi_koyu(vurgu: Hsla, metin: Hsla, soluk_metin: Hsla) -> Arc<SyntaxTheme> {
    use gpui::{FontStyle, FontWeight, HighlightStyle};

    let kirmizi = hsla(0.0   / 360.0, 0.65, 0.65, 1.0);  // keyword
    let yesil   = hsla(140.0 / 360.0, 0.45, 0.60, 1.0);  // string
    let sari    = hsla(45.0  / 360.0, 0.80, 0.65, 1.0);  // type, function
    let camgobegi = hsla(190.0 / 360.0, 0.65, 0.65, 1.0); // number
    let mor     = hsla(280.0 / 360.0, 0.55, 0.70, 1.0);  // constant

    Arc::new(SyntaxTheme::new(vec![
        ("comment".into(), HighlightStyle {
            color: Some(soluk_metin),
            font_style: Some(FontStyle::Italic),
            ..Default::default()
        }),
        ("string".into(), HighlightStyle {
            color: Some(yesil),
            ..Default::default()
        }),
        ("keyword".into(), HighlightStyle {
            color: Some(kirmizi),
            font_weight: Some(FontWeight::BOLD),
            ..Default::default()
        }),
        ("number".into(), HighlightStyle {
            color: Some(camgobegi),
            ..Default::default()
        }),
        ("function".into(), HighlightStyle {
            color: Some(sari),
            ..Default::default()
        }),
        ("type".into(), HighlightStyle {
            color: Some(sari),
            ..Default::default()
        }),
        ("constant".into(), HighlightStyle {
            color: Some(mor),
            ..Default::default()
        }),
        ("variable".into(), HighlightStyle {
            color: Some(metin),
            ..Default::default()
        }),
    ]))
}
```

**Bu kategoriler tree-sitter dilleri arasında ortaktır**: `comment`, `string`, `keyword`, `number`, `function`, `type`, `constant`, `variable`. Zed'in `languages/*/highlights.scm` dosyalarındaki bu adları referans alırsın. Kullanıcı teması `function.builtin` veya `string.escape` gibi daha zengin kategorilere genişleyebilir. Yedek tema ise garanti edilen minimum kategori setini sunar.

### Player ve accent yedeği

```rust
ThemeStyles {
    // ...
    player: PlayerColors(vec![PlayerColor {
        cursor: vurgu,
        background: vurgu.opacity(0.2),
        selection: vurgu.opacity(0.3),
    }]),
    accents: AccentColors(Arc::from([vurgu].as_slice())),
    syntax: Arc::new(SyntaxTheme::new(Vec::<(String, HighlightStyle)>::new())),
}
```

- **Player listesinde en az 1 girdi bulunmalıdır** — boş listede `local()` çağrısı çalışma zamanında hata üretir.
- **Vurgu listesinde en az 1 girdi bulunmalıdır**. Boş listede `color_for_index(idx)` modulo hesabı yapılamaz. Zed kaynağında `Default::default()` `Self::dark()` döndürdüğü için bu liste her zaman 13 elemanlıdır.
- **Syntax boş bir `Vec` ile başlatılabilir**. `SyntaxTheme::new`'a boş tuple iter geçirilmesinde teknik olarak sakınca yoktur. Bu durumda çalışma zamanında `style_for_name` çağrısı her zaman `None` döndürür.

### Açık tema simetrisi

```rust
pub fn kvs_default_light() -> Theme {
    let arka_plan   = hsla(220.0 / 360.0, 0.10, 0.98, 1.0);  // çok açık
    let yuzey       = hsla(220.0 / 360.0, 0.10, 0.95, 1.0);
    let yukseltilmis = hsla(220.0 / 360.0, 0.10, 0.92, 1.0);
    let metin       = hsla(220.0 / 360.0, 0.10, 0.10, 1.0);  // çok koyu
    let soluk_metin = hsla(220.0 / 360.0, 0.05, 0.40, 1.0);
    let kenarlik    = hsla(220.0 / 360.0, 0.10, 0.85, 1.0);
    let vurgu       = hsla(210.0 / 360.0, 0.75, 0.50, 1.0);  // açık tema için biraz daha koyu mavi

    Theme {
        id: "kvs-default-light".into(),
        name: "Kvs Varsayılan Açık".into(),
        appearance: Appearance::Light,
        styles: ThemeStyles {
            window_background_appearance: WindowBackgroundAppearance::Opaque,
            system: SystemColors::default(),
            colors: ThemeColors { /* aynı alan listesi, lightness tersine */ },
            status: durum_renkleri_acik(),
            player: /* ... */,
            accents: /* ... */,
            syntax: /* ... */,
        },
    }
}
```

**Simetri kuralları:**

- Aynı `ana_renk_tonu` (örneğin 220°) — açık ve koyu arasında **renk ailesi tutarlı** kalır.
- Lightness değerleri tersine çevrilir: koyuda 0.12 olan arka plan, açıkta 0.98 olur.
- Saturation çoğunlukla aynı tutulur; kullanıcı baktığında "aynı tema, ters mod" hissini almalıdır.
- Vurgu için koyudaki hue (örn. 210°) açıkta biraz **daha koyu** konumlanır (l=0.50 yerine 0.60); açık arka plan üzerinde okunaklılık için.

### Yedek tema test örneği

```rust
#[test]
fn yedek_temalar_tam_dolu() {
    let koyu = kvs_default_dark();
    let acik = kvs_default_light();

    // Hiçbir alan varsayılan/sıfır olmamalı
    assert_ne!(koyu.colors().background, gpui::Hsla::default());
    assert_ne!(koyu.colors().text, gpui::Hsla::default());
    assert_ne!(koyu.status().error, gpui::Hsla::default());

    // Player ve accent en az 1 girdi taşımalı
    assert!(!koyu.players().0.is_empty());
    assert!(!koyu.accents().0.is_empty());

    // Appearance tutarlı olmalı
    assert_eq!(koyu.appearance, Appearance::Dark);
    assert_eq!(acik.appearance, Appearance::Light);

    // İsimler benzersiz olmalı
    assert_ne!(koyu.name, acik.name);
}
```

### Dikkat Noktaları

1. **`Default::default()` ile eksik alanların doldurulması**: `Hsla::default()` görünmezdir. 150 + 42 alanın tamamının açık bir değerle doldurulması gerekir.
2. **`unsafe { std::mem::zeroed() }` kullanımı**: Sonuç yine sıfır `Hsla` olur. Şablon kodda görüldüğünde silinmeli, gerçek kodda hiç kullanmaman gerekir.
3. **Çapa olmadan rastgele HSL**: Her alan için farklı hue/saturation = dağınık bir tema demektir. Çapa hue + opacity disiplini şarttır.
4. **`palette` sürümünün sabitlenmemesi**: Aynı `hsla(0.583, 0.10, 0.12)` ifadesi, farklı `palette` major sürümlerinde **ufak miktarda farklı sRGB** üretebilir. Cargo.lock dosyası ile kullanılan sürümün sabitlenmesi yerinde olur.
5. **Zed'in `default_colors` HSL değerlerini birebir kopyalamak**: GPL-3 ihlali demektir. Bağımsız çapa değerleri seçmen gerekir.
6. **Light temasını dark'tan otomatik türetmek**: `l = 1.0 - dark_l` gibi formüller **çalışmaz** — gözün light ve dark algısı doğrusal değildir. Light tema, ayrı bir tasarım kararı olarak yazılır.
7. **Boş syntax yedeği**: Yedek olarak boş syntax kabul edilir; ancak UI'da kod gösteriliyorsa en azından 5–10 temel kategori (`comment`, `string`, `keyword`, `number`, `function`) doldurman gerekir. `Theme.styles.syntax` alanı `Arc<SyntaxTheme>` tipi beklediği için, içerik boş olsa bile `Arc::new(...)` sarması zorunludur.

### Zed yedek public API karşılığı

Zed tarafında yedek aileyi üreten public fonksiyonun adı `zed_default_themes()`'dir. Bu fonksiyon bir `ThemeFamily` döndürür; `id` alanı `"zed-default"`, `name` alanı `"Zed Default"`, `themes` listesi yerleşik dark temayı, `scales` alanı da `default_color_scales()` çıktısını taşır.

Ayna uygulamada bu fonksiyonu birebir kopyalamazsın; lisans ve ürün kimliği nedeniyle kendi adınla, örneğin `kvs_default_themes()` biçiminde yazarsın. Ancak davranış sözleşmesi aynıdır:

- Tema kaydı boş başlamaz; en az bir geçerli `ThemeFamily` veya doğrudan `Theme` seti vardır.
- Yedek tema tüm `ThemeColors`, `StatusColors`, `PlayerColors`, `AccentColors`, `SystemColors` ve `SyntaxTheme` alanlarını tutarlı şekilde doldurur.
- `ThemeRegistry::new` veya `init` akışı bu yedek temayı ilk kaynak olarak ekler.
- `ColorScales` aynalanıyorsa `default_color_scales()` çıktısı aileye bağlanır; edilmiyorsa bu alan için yerel bir karar açıkça verilir.

`apply_status_color_defaults` ve `apply_theme_color_defaults` ise yedek tema üretiminden farklı bir katmandadır: bunlar kullanıcı temasından gelen eksik refinement alanlarını doldurur. `apply_status_color_defaults`, yalnızca `deleted`, `created`, `modified`, `conflict`, `error` ve `hidden` ön plan alanlarından eksik `*_background` alanlarını türetir; türetme alpha değeri `0.25` olan ön plan rengidir. `warning`, `info`, `success`, `hint` gibi tüm durum alanları bu yardımcı tarafından otomatik doldurulmaz.

`apply_theme_color_defaults`, `ThemeColorsRefinement` içinde yalnızca `element_selection_background` boşsa devreye girer. Kaynak renk `player_colors.local().selection` değeridir. Kaynak alpha `1.0` ise alpha `0.25` yapılır; kaynak zaten yarı saydamsa olduğu gibi kullanılır. Bu yüzden `element_selection_background = text_accent.opacity(0.25)` gibi başka bir formül yazmak Zed davranışıyla eşleşmez.

```rust
pub fn tema_renk_defaultlarini_uygula(
    renkler: &mut ThemeColorsRefinement,
    oyuncular: &PlayerColors,
) {
    apply_theme_color_defaults(renkler, oyuncular);
}
```

Bu iki yardımcının yeri yedek tema dosyasıdır, ama çağrıldıkları ana akış refinement ve tema üretimidir. Yerleşik yedek temayı yazarken alanları zaten tam doldurursun; yardımcılar asıl olarak kullanıcı JSON'u eksik alan verdiğinde anlam kazanır.

### `FontFamilyCache` — font ailesi listeleme önbelleği

`FontFamilyCache`, tema renk sözleşmesinin parçası değildir; buna rağmen `theme` crate public yüzeyinden re-export edilir ve `theme::init` sırasında global olarak kurulur. Amacı, `cx.text_system().all_font_names()` çağrısının pahalı sonucunu bir kez okuyup sonraki render'larda `SharedString` listesi olarak döndürmektir.

| API | Ne yapar | Ne zaman kullanılır |
| ----- | ---------- | --------------------- |
| `FontFamilyCache::init_global(cx)` | GPUI global'ine önbellek nesnesini yerleştirir. | Tema çalışma zamanı init sırasında. |
| `FontFamilyCache::global(cx)` | Global önbelleği `Arc<FontFamilyCache>` olarak döndürür. | Ayarlar UI'ı veya font seçici önbelleğe erişeceğinde. |
| `FontFamilyCache::list_font_families(cx)` | Liste yüklüyse önbellekten döndürür; değilse text system'dan okuyup önbelleğe yazar. | Font seçici açıldığında senkron ve kesin liste gerektiğinde. |
| `FontFamilyCache::try_list_font_families()` | Liste daha önce yüklenmişse `Some(Vec<SharedString>)`, değilse `None` döndürür. | Render'ı bloklamadan hazır önbellek kontrolü gerektiğinde. |
| `FontFamilyCache::prefetch(cx).await` | Font listesini async app üzerinden arka planda ısıtır. | Ayarlar ekranı açılmadan önce hazırlık yapmak istediğinde. |

Tüketici bileşen `list_font_families` çağrısını her render'da yapmamalıdır. Font seçici gibi bir yüzey açıldığında liste alınır, UI durumuna konur ve tema değişiminden bağımsız olarak kullanılır. Tema renkleri değiştiğinde font ailesi listesi değişmez; sistem fontları değiştiyse önbellek geçersiz kılma için ayrı bir uygulama kararı gerekir.

---

## 26. Yerleşik tema paketleme ve `AssetSource`

Yerleşik temalar, uygulama ile **birlikte dağıtılan** JSON tema dosyalarıdır. Bunları paketlemek için üç strateji vardır; seçim ihtiyaca göre yaparsın.

### Strateji 1: Diskten yükleme (en basit)

Geliştirme aşamasında ve geliştirme derlemelerinde genellikle yeterlidir. `assets/themes/` dizinindeki tüm JSON dosyaları çalışma zamanında okunur:

```rust
use std::path::Path;

pub fn diskten_temalari_yukle(
    kayit: &kvs_tema::ThemeRegistry,
    temalar_dizini: &Path,
) -> anyhow::Result<()> {
    let taban_koyu = kvs_tema::fallback::kvs_default_dark();
    let taban_acik = kvs_tema::fallback::kvs_default_light();

    let girdiler = std::fs::read_dir(temalar_dizini)?;
    for girdi in girdiler.flatten() {
        let yol = girdi.path();
        if !yol.extension().is_some_and(|uzanti| uzanti == "json") {
            continue;
        }
        let baytlar = std::fs::read(&yol)?;
        let aile: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&baytlar)
                .with_context(|| format!("tema ayrıştırma: {}", yol.display()))?;

        let temalar: Vec<kvs_tema::Theme> = aile
            .themes
            .into_iter()
            .map(|tema_icerigi| {
                let taban = match tema_icerigi.appearance {
                    kvs_tema::AppearanceContent::Dark => &taban_koyu,
                    kvs_tema::AppearanceContent::Light => &taban_acik,
                };
                kvs_tema::Theme::from_content(tema_icerigi, taban)
            })
            .collect();
        kayit.insert_themes(temalar);
    }
    Ok(())
}
```

**Akış:**

- Her dosya bir `ThemeFamilyContent` taşır; ailedeki light + dark varyantlar ayrılır.
- `tema_icerigi.appearance` değerine göre uygun taban seçilir (ilgili bölüm yeniden yükleme akışı ile aynı mantık).
- Bir tema dosyasından hata gelse bile diğerlerinin yüklenmeye devam etmesi isteniyorsa `try_into`/`continue` deseni kullanabilirsin:

```rust
for girdi in girdiler.flatten() {
    if let Err(hata) = tema_dosyasini_isle(girdi.path(), kayit) {
        tracing::warn!("tema yükleme atlandı: {} ({})", girdi.path().display(), hata);
        continue;
    }
}
```

**Avantajlar:**

- Sıfır derleme zamanı iş yükü.
- Geliştirmede tema dosyalarını editör ile anlık değiştirip uygulamayı yeniden başlatma kolaylığı.

**Dezavantajlar:**

- Binary tek dosya olarak dağıtılmaz; dağıtım sırasında klasör yapısının korunması gerekir.
- `temalar_dizini` yolunun binary'nin nereden çağrıldığına göre çözülmesi gerekir.

### Strateji 2: `RustEmbed` ile derleme zamanı gömme

Üretim binary'lerinde yaygın olarak tercih edersin. Tema dosyaları **derleme zamanında** binary'ye gömülür; çalışma zamanında disk erişimi gerekmez.

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
pub struct GomuluVarliklar;
```

Yükleme:

```rust
pub fn gomulu_temalari_yukle(kayit: &kvs_tema::ThemeRegistry) -> anyhow::Result<()> {
    let taban_koyu = kvs_tema::fallback::kvs_default_dark();
    let taban_acik = kvs_tema::fallback::kvs_default_light();

    for yol in GomuluVarliklar::iter().filter(|yol| yol.starts_with("themes/") && yol.ends_with(".json")) {
        let dosya = GomuluVarliklar::get(&yol)
            .ok_or_else(|| anyhow::anyhow!("gömülü varlık eksik: {}", yol))?;

        let aile: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&dosya.data)?;

        let temalar: Vec<kvs_tema::Theme> = aile
            .themes
            .into_iter()
            .map(|tema_icerigi| {
                let taban = match tema_icerigi.appearance {
                    kvs_tema::AppearanceContent::Dark => &taban_koyu,
                    kvs_tema::AppearanceContent::Light => &taban_acik,
                };
                kvs_tema::Theme::from_content(tema_icerigi, taban)
            })
            .collect();
        kayit.insert_themes(temalar);
    }
    Ok(())
}
```

**Avantajlar:**

- Tek binary dağıtım kolaylığı.
- Çalışma zamanında disk erişimi olmadığı için hızlı kurulum süresi.

**Dezavantajlar:**

- Tema değiştirmek için yeniden derleme gerekir.
- Derleme süresi artar (her tema dosyası binary'ye girer).
- `debug-embed` özelliği ile geliştirme modunda dosyalardan, release profilinde ise gömülü varlık davranışı elde edilir.

### Strateji 3: `gpui::AssetSource` entegrasyonu

GPUI'nin kendi varlık sistemi kullanılacaksa, özellikle SVG ve ikonlarla tutarlı bir varlık hattı hedefleniyorsa, bu strateji seçebilirsin.

```rust
use gpui::AssetSource;

pub struct KvsVarliklari;

impl AssetSource for KvsVarliklari {
    fn load(&self, yol: &str) -> gpui::Result<Option<std::borrow::Cow<'static, [u8]>>> {
        GomuluVarliklar::get(yol)
            .map(|dosya| Some(std::borrow::Cow::Owned(dosya.data.into_owned())))
            .ok_or_else(|| anyhow::anyhow!("varlık bulunamadı: {}", yol).into())
    }

    fn list(&self, yol: &str) -> gpui::Result<Vec<gpui::SharedString>> {
        Ok(GomuluVarliklar::iter()
            .filter(|aday_yol| aday_yol.starts_with(yol))
            .map(|aday_yol| aday_yol.to_string().into())
            .collect())
    }
}

// Uygulama girişinde:
fn uygulamayi_baslat(platform: std::rc::Rc<dyn gpui::Platform>) {
    gpui::Application::with_platform(platform)
        .with_assets(KvsVarliklari)
        .run(|cx| {
            kvs_tema::init(cx);
            // Tema dosyaları AssetSource üzerinden okunabilir
            // ...
        });
}
```

GPUI'nin `cx.asset_source()` API'sı ile tema dosyalarını doğrudan aynı varlık kaynağından okuyabilirsin. `Resource::Embedded(...)` de bu kaynağı kullanan GPUI tüketicileriyle, örneğin gömülü görsel ve ikon yollarıyla, aynı paketleme düzenini paylaşır:

```rust
pub fn varlik_kaynagiyla_yukle(
    kayit: &kvs_tema::ThemeRegistry,
    cx: &App,
) -> anyhow::Result<()> {
    let varliklar = cx.asset_source();
    let tema_yollari = varliklar.list("themes/")?;

    for yol in tema_yollari {
        if !yol.ends_with(".json") {
            continue;
        }
        let baytlar = varliklar.load(&yol)?
            .ok_or_else(|| anyhow::anyhow!("varlık eksik: {}", yol))?;

        let aile: kvs_tema::ThemeFamilyContent =
            serde_json_lenient::from_slice(&baytlar)?;

        let taban_koyu = kvs_tema::fallback::kvs_default_dark();
        let taban_acik = kvs_tema::fallback::kvs_default_light();
        let temalar: Vec<kvs_tema::Theme> = aile
            .themes
            .into_iter()
            .map(|tema_icerigi| {
                let taban = match tema_icerigi.appearance {
                    kvs_tema::AppearanceContent::Dark => &taban_koyu,
                    kvs_tema::AppearanceContent::Light => &taban_acik,
                };
                kvs_tema::Theme::from_content(tema_icerigi, taban)
            })
            .collect();
        kayit.insert_themes(temalar);
    }
    Ok(())
}
```

**Avantajlar:**

- İkon, SVG ve font ile tutarlı tek bir API.
- Varlık önbelleği ve yükleme davranışının GPUI tarafından yönetilmesi.

**Dezavantajlar:**

- `AssetSource` impl şablon kodu.
- GPUI sürüm değişimlerinde trait imzasının kayma ihtimali (rehber.md #62).

### Karar matrisi

| İhtiyaç | Strateji |
| --------- | ---------- |
| Geliştirme/prototip; tema'ların editörden anlık değiştirilmesi | **1 — diskten** |
| Üretim için tek binary dağıtım, az sayıda tema (<20) | **2 — RustEmbed** |
| GPUI varlık hattıyla tutarlı; tema sayısı çok veya kullanıcı ekleyebilirsin | **3 — AssetSource** |
| Karma kullanım: yerleşik + kullanıcı tema dizini | Strateji 2 + ek kullanıcı dizin yüklemesi |

### Sıcak yeniden yükleme (dosya izleyici)

Geliştirme modunda tema dosyasını editörden değiştirip uygulamayı yeniden başlatmadan görmek istenirse:

```rust
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use std::path::PathBuf;

pub fn sicak_yeniden_yuklemeyi_baslat(
    temalar_dizini: PathBuf,
    cx: &mut App,
) -> anyhow::Result<()> {
    let (gonderici, alici) = std::sync::mpsc::channel();
    let mut izleyici = notify::recommended_watcher(gonderici)?;
    izleyici.watch(&temalar_dizini, RecursiveMode::NonRecursive)?;

    cx.spawn(async move |cx| {
        loop {
            match alici.recv() {
                Ok(Ok(olay)) if olay.kind.is_modify() => {
                    for yol in olay.paths {
                        cx.update(|cx| {
                            let _ = kvs_tema::temayi_yeniden_yukle(&yol, cx);
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

> **Üretimde kapatılması gerekir.** Sıcak yeniden yükleme yalnızca geliştirme tarafında kolaylık sağlar. Üretim kullanıcısı tema dosyasını bu yoldan elle değiştirmez. Bu kolaylığın `#[cfg(debug_assertions)]` ile sınırlandırılması yerinde olur.

### Tema dosyası yapısı

`assets/themes/` altında Zed'in izlediği konvansiyon tema başına alt dizindir:

```text
assets/themes/
├── LICENSES              ← toplu lisans notları
├── one/
│   ├── LICENSE
│   └── one.json          ← One Light + One Dark
└── ayu/
    ├── LICENSE
    └── ayu.json          ← Ayu varyantları
```

**Her tema dosyası bir `ThemeFamilyContent`'tir** — birden fazla varyant (light + dark) içerebilir.

### Dikkat Noktaları

1. **`temalar_dizini` çalışma dizini bağımlılığı**: Disk yüklemesinde `assets/themes` göreli bir yoldur; binary nereden çalıştırılırsa yola göre çözülür. **Mutlak yol** üretilmesi yerinde olur:
   ```rust
   let calistirilabilir_dizini = std::env::current_exe()?.parent()?.to_path_buf();
   let temalar_dizini = calistirilabilir_dizini.join("assets").join("themes");
   ```
2. **`RustEmbed` derleme süresini şişirir**: Her tema dosyası binary'ye gömülür. 100 MB'lık bir tema klasörü 100 MB'lık binary'ye dönüşür. Ayıklama için include filtreleri kullanabilirsin:
   ```toml
   #[derive(RustEmbed)]
   #[folder = "assets/"]
   #[include = "themes/**/*.json"]
   #[include = "themes/**/LICENSE"]
   #[include = "themes/LICENSES"]
   ```
3. **Async yüklemede `cx` lifetime'ı**: `cx.spawn` içinde `AsyncApp` bulunur; eşzamanlı bağlama geçmek için `cx.update(|cx| ...)` kullanılır.
4. **Aynı isim çakışması**: Yerleşik "One Dark" teması ile kullanıcının "One Dark" teması karşılaştığında, kullanıcı teması **üzerine yazar** (`insert` semantiği). Bu davranış bilinçlidir; kullanıcının modifikasyonu önceliklidir.
5. **Taban seçiminin görünür olması**: Dark bir temanın tabanı light olarak verilirse, eksik alanlar açık tema değerlerinden gelir ve görsel olarak uyumsuz bir tema ortaya çıkar. Tabanı `appearance` değerine göre seçmen gerekir.
6. **`include_bytes!` yerine `RustEmbed`**: `include_bytes!` tek dosya gömme için yeterlidir; onlarca tema için `RustEmbed` tek bir macro çağrısıyla aynı işi yapar.
7. **Sıcak yeniden yüklemenin üretimde açık kalması**: Dosya izleyici CPU/IO maliyetinin yanı sıra güvenlik açısından da risk taşır (kullanıcı yol enjeksiyonu). `cfg(debug_assertions)` ile sınırlandırılması tercih edersin.

---

## 27. Tema varlık lisans sınırları

Üç lisans hattı ayrı ayrı izlenmelidir: **bağımlılıklar** (kod), **Zed tema örnek verileri** (veri) ve **yedek palet** (uygulamanın kendi tasarım kararı).

### Lisans matrisi

| Tip | Lisans | Sözleşme |
| ----- | -------- | ---------- |
| Kod bağımlılığı | Apache-2.0 | Doğrudan bağımlılık olarak kullanılır |
| Kod bağımlılığı | Apache-2.0 | Doğrudan bağımlılık |
| Kod bağımlılığı | Apache-2.0 | Doğrudan bağımlılık |
| Kod referansı | GPL-3.0-or-later | **Aynalanır, kopyalanmaz** |
| Kod referansı | GPL-3.0-or-later | **Yalnızca referans için okunur, bağımlılık olarak alınmaz** |
| Veri örneği | Tema-özel (MIT/Apache/GPL) | **Lisans dosyasıyla birlikte kopyalanır** |
| Tasarım verisi | GPL-3.0-or-later | **Kopyalanmaz; bağımsız palet seçilir** |

### Zed tema lisansları

Zed'in `assets/themes/` dizininde **her tema kendi alt dizininde** ve kendi lisansıyla tutulur:

```text
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

**Düz dizin seçilirse paket adlandırma konvansiyonu:**

Tüm temalar Zed'in alt dizin yapısı yerine **düz bir dizinde** tutuluyorsa, lisans dosyalarının çakışmaması için her dosya tema adıyla isimlendirilmelidir:

```text
kvs_ui/assets/themes/
├── README.md                    ← atıf tablosu (zorunlu)
├── one.json
├── one.LICENSE_MIT              ← <tema-ad>.LICENSE_<tip>
├── ayu.json
├── ayu.LICENSE_MIT
├── gruvbox.json
└── gruvbox.LICENSE_MIT
```

**Düz dizin konvansiyon kuralları:**

1. Her tema JSON dosyasının **aynı stem** (uzantı öncesi ad) ile bir `<stem>.LICENSE_<tip>` dosyasının bulunması gerekir.
2. `<tip>` SPDX kodlarının kısa karşılığı olur: `MIT`, `APACHE`, `BSD3`, `MPL2` gibi.
3. `LICENSE_GPL*` ile başlayan dosyalar paketlenen tema varlıklarına dahil edilmez.
4. `README.md` zorunludur — atıf tablosu (telif sahibi, kaynak repo, SPDX kodu) burada yer alır.

**Alternatif:** Zed dizin yapısını birebir korumak (tema başına alt dizin):

```text
kvs_ui/assets/themes/
├── README.md
├── one/
│   ├── one.json
│   └── LICENSE
└── ayu/
    ├── ayu.json
    └── LICENSE
```

Hangi yapı seçilirse seçilsin, `RustEmbed`/`AssetSource` filtrelerini buna göre güncellemen gerekir. `include = "themes/**/*.json"` ile `include = "themes/*.json"` aynı şeyi kapsamaz. Bu rehberin ana örnekleri Zed'e yakın **tema başına alt dizin** yapısını varsayar; düz dizin tercih edilirse yol manipülasyonu ve lisans dosyası adları da farklılaşır.

Dosya adı `LICENSE` olduğunda içerik tema ile birlikte saklarsın. MIT, Apache ve BSD gibi uyumlu lisanslar paket içine alınabilir. GPL veya lisansı belirsiz tema dosyaları ise pakete dahil edilmez. Her paketlenen tema için kaynak repo, yol, lisans ve telif bilgisi atıf dosyasında yer almalıdır.

### Yedek palet lisans hatırlatması

Bu konu ilgili bölümlerde işlenmişti; özet olarak:

- Zed'in `default_colors` HSL değerleri **birebir kopyalanmaz**.
- Açık lisanslı paletten (Tailwind, Catppuccin, Nord, Solarized) esinlenilebilir; esin kaynağının atıf metninde belirtilmesi gerekir.
- `kvs_default_dark` ve `kvs_default_light` **uygulamanın kendi tasarım kararıdır**; lisansı da uygulamanın lisansıyla (MIT/Apache vb.) uyumludur.

### Dikkat Noktaları

1. **Lisans dosyasını "sonradan eklemek"**: Derleme sırasında binary'ye tema JSON'u girer ama LICENSE girmezse, **dağıtım anında lisans ihlali** oluşur.
2. **`LICENSE_GPL` görmezden gelmek**: Tema dosyasındaki HSL değerlerinin "yalnızca JSON" olarak görülmesi telif ihlaline yol açar. GPL temalarının kullanılmaması gerekir.
3. **Atıf README'sinin güncellenmemesi**: Yeni bir tema eklendikten sonra atıf eklenmediğinde, "hangi tema kim tarafından yazıldı?" sorusu cevapsız kalır; lisansın "telif sahibi gösterimi" şartı ihlal edilmiş olur.
4. **Cargo dep'lerinde GPL kullanımı**: GPL bir crate eklendiğinde uygulamanın **tamamı** GPL'e tabi hale gelir.
5. **`palette` / `refineable` lisans karıştırması**: `palette` MIT/Apache çift lisanslıdır; `refineable` Apache-2.0'dır. Paket ve NOTICE metni bu ayrımı doğru yansıtmalıdır.
6. **Örnek veri dosyasını bir fork'tan almak**: Tema JSON'larının Zed'in **upstream** reposundan alınması gerekir; bir fork'tan kopyalandığında o fork'un lisans değişikliği veya patch'leri de bulaşır.
7. **Sıcak yeniden yükleme yolundan kullanıcı dosyası**: Kullanıcının `~/.config/kvs/themes/` dizinine koyduğu tema kullanıcının kendi sorumluluğundadır; uygulamanın lisans matrisini etkilemez. Yerleşik kaynaklar ile kullanıcı kaynakları ayrı tutulmalıdır.

---

## 28. JSON şeması ve örnek veri sözleşmesi

**Kaynak dizin:** `kvs_tema/tests/fixtures/`.

Örnek veri dosyaları, gerçek tema JSON biçimini temsil eden verilerdir. Bu dosyalar `ThemeFamilyContent`, refinement ve çalışma zamanı dönüşümünün aynı JSON sözleşmesini paylaştığını görünür kılar.

### Dizin yapısı

```text
kvs_tema/tests/
├── fixtures/
│   ├── one-dark.json           ← Zed assets/themes/one/one.json (MIT)
│   ├── one-light.json          ← Aynı paket, light varyant
│   ├── ayu.json                ← Zed assets/themes/ayu/ayu.json (MIT)
│   ├── one.LICENSE_MIT         ← Zed'den kopyalanan lisans
│   ├── ayu.LICENSE_MIT
│   ├── README.md               ← Örnek veri kaynak ve lisans tablosu
│   └── synthetic/
│       ├── empty.json          ← Boş tema (test için sentetik)
│       ├── bilinmeyen_alan.json ← Bilinmeyen alan hata örneği
│       └── gecersiz_renk.json   ← Geçersiz hex
├── tema_ornekleri.rs           ← Zed temaları ayrıştırılabiliyor mu?
├── sentetik.rs                 ← Sentetik testler
└── iyilestirme.rs              ← Refinement davranış testleri
```

### `tests/tema_ornekleri` — gerçek tema testleri

```rust
use kvs_tema::{schema::ThemeFamilyContent, Theme, fallback};

fn taban_koyu() -> Theme {
    fallback::kvs_default_dark()
}

fn taban_acik() -> Theme {
    fallback::kvs_default_light()
}

#[test]
fn zed_one_koyu_ayristirir() -> anyhow::Result<()> {
    let json = include_str!("fixtures/one-dark.json");
    let aile: ThemeFamilyContent = serde_json_lenient::from_str(json)?;

    assert_eq!(aile.name, "One");
    assert!(!aile.themes.is_empty());

    for tema_icerigi in aile.themes {
        let taban = match tema_icerigi.appearance {
            kvs_tema::AppearanceContent::Dark => taban_koyu(),
            kvs_tema::AppearanceContent::Light => taban_acik(),
        };
        let tema = Theme::from_content(tema_icerigi, &taban);

        assert!(!tema.name.is_empty());
        // Tabandan farklı bir arka plan üretilmiş olmalı
        assert_ne!(tema.colors().background, gpui::Hsla::default());
    }

    Ok(())
}

#[test]
fn zed_ayu_ayristirir() -> anyhow::Result<()> {
    let json = include_str!("fixtures/ayu.json");
    let _: ThemeFamilyContent = serde_json_lenient::from_str(json)?;
    Ok(())
}
```

**Kalıp:**

- `include_str!` derleme zamanında dosya içeriğini stringe gömer.
- `serde_json_lenient`, Zed JSON'unda yer alan yorum ve sonda virgül toleransını sağlar.
- `from_content` çağrısı ile **tam akış** test edilir: ayrıştırma + refinement + `Theme` yapısı.

### `tests/synthetic` — kenar durumlar

```rust
use kvs_tema::{schema::ThemeFamilyContent, Theme, fallback};

#[test]
fn bos_tema_tabani_kullanir() -> anyhow::Result<()> {
    let json = r#"{
        "name": "Boş",
        "author": "Kvs",
        "themes": [{
            "name": "Boş Tema",
            "appearance": "dark",
            "style": {}
        }]
    }"#;
    let aile: ThemeFamilyContent = serde_json_lenient::from_str(json)?;
    let taban = fallback::kvs_default_dark();
    let tema_icerigi = aile
        .themes
        .into_iter()
        .next()
        .ok_or_else(|| anyhow::anyhow!("tema bulunamadı"))?;
    let tema = Theme::from_content(tema_icerigi, &taban);

    // Tüm renkler tabandan gelmeli
    assert_eq!(tema.colors().background, taban.colors().background);
    assert_eq!(tema.status().error, taban.status().error);
    Ok(())
}

#[test]
fn bilinmeyen_alan_reddedilir() -> anyhow::Result<()> {
    let json = r#"{
        "name": "Deneme", "author": "Kvs",
        "themes": [{
            "name": "Koyu Deneme", "appearance": "dark",
            "style": {
                "background": "#000000ff",
                "scrollbar_thumb.background": "#ffffffff"
            }
        }]
    }"#;
    let Err(hata) = tema_ailesini_kati_ayristir(json.as_bytes()) else {
        anyhow::bail!("sözleşme dışı anahtar kabul edildi");
    };
    assert!(hata.to_string().contains("bilinmeyen tema stil alanı"));
    Ok(())
}

#[test]
fn gecersiz_hex_tabana_duser() -> anyhow::Result<()> {
    let json = r#"{
        "name": "Deneme", "author": "Kvs",
        "themes": [{
            "name": "Koyu Deneme", "appearance": "dark",
            "style": { "background": "renk-degil" }
        }]
    }"#;
    let aile: ThemeFamilyContent = serde_json_lenient::from_str(json)?;
    let taban = fallback::kvs_default_dark();
    let tema_icerigi = aile
        .themes
        .into_iter()
        .next()
        .ok_or_else(|| anyhow::anyhow!("tema bulunamadı"))?;
    let tema = Theme::from_content(tema_icerigi, &taban);

    // Geçersiz hex -> tabandan
    assert_eq!(tema.colors().background, taban.colors().background);
    Ok(())
}

#[test]
fn bilinmeyen_enum_varyanti_none_olur() -> anyhow::Result<()> {
    let json = r#"{
        "color": "#000",
        "font_style": "semi_oblique"
    }"#;
    let vurgulama: kvs_tema::schema::HighlightStyleContent =
        serde_json::from_str(json)?;
    assert!(vurgulama.color.is_some());
    assert!(vurgulama.font_style.is_none());  // bilinmeyen varyant -> None
    Ok(())
}
```

### `tests/refinement` — refinement davranışları

```rust
use kvs_tema::*;

#[test]
fn durum_rengi_arka_plani_on_plandan_turetir() -> anyhow::Result<()> {
    use kvs_tema::schema::StatusColorsContent;
    let mut icerik = StatusColorsContent::default();
    icerik.error = Some("#ff5555ff".to_string());
    // error_background None

    let mut iyilestirme = status_colors_refinement(&icerik);
    apply_status_color_defaults(&mut iyilestirme);

    assert!(iyilestirme.error.is_some());
    let arka_plan = iyilestirme
        .error_background
        .ok_or_else(|| anyhow::anyhow!("error_background türetilmedi"))?;
    assert!((arka_plan.a - 0.25).abs() < 1e-6);
    Ok(())
}

#[test]
fn refine_yalniz_bazi_alanlari_gecersiz_kilar() {
    let taban = fallback::kvs_default_dark();
    let mut renkler = taban.colors().clone();

    let iyilestirme = ThemeColorsRefinement {
        border: Some(gpui::hsla(0.5, 1.0, 0.5, 1.0)),
        ..Default::default()
    };

    let ilk_arka_plan = renkler.background;
    renkler.refine(&iyilestirme);

    assert_ne!(renkler.border, taban.colors().border);  // geçersiz kılındı
    assert_eq!(renkler.background, ilk_arka_plan);       // korundu
}
```

### Özellik testleri — `Hsla::opaque_strategy`

`gpui::Hsla`, `proptest` özelliği açıkken `Arbitrary` ve `Hsla::opaque_strategy()` desteğini taşır. Renk türetme ve kontrast yardımcıları yazıldığında, tekil örnekler yerine özellik testi yaklaşımı daha güçlü kapsama sağlar:

- `Hsla::opaque_strategy()` alpha'yı `1.0` olarak tutar; bu da kontrast testlerinde şeffaflık kaynaklı belirsizliği ortadan kaldırır.
- `any::<Hsla>()` alpha dahil tüm kanalları `0.0..=1.0` aralığında üretir; ayrıştırma/refinement yuvarlama ve alpha davranış testlerinde kullanırsın.
- Bu API yalnızca `gpui`'nin `proptest` özelliği ile birlikte gelir. Ayna testlerinde geliştirme bağımlılığı özellik setinin buna göre açılması; üretim derlemesine taşınmaması gerekir.

Örnek bir kullanım alanı: `vurgu_dolgusu_ve_metin` benzeri bir yardımcının light ve dark appearance'ta minimum kontrastı koruduğunun rastgele opak renklerle doğrulanması.

### `gpui::TestAppContext` ile çalışma zamanı testleri

Pencere açmaya gerek olmayan çalışma zamanı testleri:

```rust
use gpui::TestAppContext;

#[gpui::test]
fn init_yedek_temalari_kurar(cx: &mut TestAppContext) -> anyhow::Result<()> {
    cx.update(|cx| -> anyhow::Result<()> {
        kvs_tema::init(cx);

        let kayit = kvs_tema::ThemeRegistry::global(cx);
        assert!(kayit.list_names().contains(&"Kvs Varsayılan Koyu".into()));

        let tema = cx.theme();
        assert_eq!(tema.name.as_ref(), "Kvs Varsayılan Koyu");
        Ok(())
    })?;
    Ok(())
}

#[gpui::test]
fn tema_degistir_aktifi_gunceller(cx: &mut TestAppContext) -> anyhow::Result<()> {
    cx.update(|cx| -> anyhow::Result<()> {
        kvs_tema::init(cx);

        kvs_tema::temayi_degistir("Kvs Varsayılan Açık", cx)?;

        let tema = cx.theme();
        assert_eq!(tema.appearance, kvs_tema::Appearance::Light);
        Ok(())
    })?;
    Ok(())
}
```

`gpui::test` attribute'u pencere veya UI sürmez; `TestAppContext` başsız bir bağlamdır. Tema çalışma zamanı bu bağlam üzerinde test edilebilir kalır.

### Test stratejisi özeti

| Test türü | Hedef | Dosya |
| ----------- | ------- | ------- |
| Gerçek tema ayrıştırma | Sözleşme paritesi | `tema_ornekleri` |
| Sentetik kenar durum | `treat_error_as_none`, bilinmeyen alan hatası, geçersiz hex | `synthetic` |
| Refinement davranışı | `apply_status_color_defaults`, `refine` | `refinement` |
| Çalışma zamanı kurulumu | `init`, `temayi_degistir`, kayit | `runtime` + `TestAppContext` |
| Yedek tema bütünlüğü | Tüm alanların dolu olması | `fallback` |

### Dikkat Noktaları

1. **`include_str!` ile mutlak yol**: Yol test dosyasına göre çözülür; `include_str!("fixtures/one-dark.json")` ifadesi `tests/fixtures/...` olarak yorumlanır. Mutlak yol verilmesi gerekmez.
2. **Örnek veri lisansının birlikte taşınması**: Dosya kopyalanırken `*.LICENSE_*` dosyalarını da taşıman gerekir; örnek veri JSON'u ile lisans dosyası bir arada tutulur.
3. **Test'lerin `init` çağrısı**: `kvs_tema::init(cx)` her test başında elle çağrılır; otomatik bir kurulum mekanizması yoktur. Çağrı, `TestAppContext::update` callback'i içinde yaparsın.
4. **`assert_eq!` ile Hsla karşılaştırması**: Floating point eşitlik yanıltıcı sonuçlara yol açabilir. `assert!((a.h - b.h).abs() < 1e-6)` gibi bir epsilon karşılaştırması tercih edilmelidir.
5. **`#[gpui::test]` ile `#[test]` arasındaki seçim**: GPUI çalışma zamanı testleri `gpui::test`; saf sözleşme testleri ise `test` ile yazılır. Karıştırılması gereksiz bir ek yük yaratır.
6. **Örnek veri dosyasının yerinde değiştirilmesi**: Test örnek verisine yama uyguladığında, testler kendi verisini yazıp doğrulamış olur. Örnek veri dosyaları **salt okunur** kabul edilmelidir; sentetik kenar durumları ayrı dosyalarda veya satır içi string'lerde tutulur.
7. **Örnek verinin hedef sözleşmeden sapması**: Örnek veri dosyaları seçilen Zed referansındaki alanları temsil etmelidir. Eski alias anahtarlar veya sözleşme dışı alanlar örnek veriye karışırsa testler parite konusunda yanıltıcı sonuçlar verebilir.

---
