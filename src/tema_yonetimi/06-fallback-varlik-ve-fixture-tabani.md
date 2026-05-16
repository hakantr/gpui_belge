# Fallback, varlık ve fixture tabanı

Tema üretmeye başlamadan önce üç temel zemin kurulmalıdır: lisans açısından
temiz fallback tema, uygulamayla gelen built-in asset'ler ve test fixture
tabanı. Refinement akışı bu baseline'ın üzerine uygulanır. Bu yüzden burada
verilen kararlar sonraki bölümlerin dayandığı zemini oluşturur.

---

## 25. Fallback tema tasarımı

**Kaynak modül:** `kvs_tema/src/fallback.rs`.

Fallback temalar runtime için bir **güvenlik ağıdır**. Kullanıcı temasının
yüklenmesi başarısız olsa bile uygulama açılabilmelidir. Bu yüzden registry'de
her zaman en az **iki tema** hazır bulunur: biri light, biri dark (Bölüm
VIII/Konu 36).

### Rol ve sözleşme

| Soru | Cevap |
|------|-------|
| Kaç adet fallback bulunur? | **2 — `kvs_default_dark` ve `kvs_default_light`** |
| Kim ne zaman çağırır? | `kvs_tema::init` (Bölüm VIII/Konu 36); ayrıca `Theme::from_content` çağrısında baseline argümanı olarak |
| Lisans? | **Uygulamanın kendi lisansı** — Zed'in paletini taşımak yasaktır (Bölüm I/Konu 3) |
| Hangi alan eksik kalabilir? | **Hiçbiri** — tüm ThemeColors/StatusColors alanları açık değer almalıdır |
| Ne zaman değişir? | Tasarım dili veya izlenen Zed tema sözleşmesi yeni bir alan gerektirdiğinde |

### Palet seçimi disiplini

Zed'in `default_colors.rs` dosyasındaki HSL değerleri **GPL-3 telif
altındadır**. Bunlar birebir kopyalanamaz. Güvenli ilerlemek için iki yol
vardır:

**1. Sıfırdan tasarım:** Tek bir "anchor hue" belirlenir ve türetme kuralları
bu ana rengin üzerine kurulur.

```rust
pub fn kvs_default_dark() -> Theme {
    // Anchor renkler — tüm türetmelerin başlangıcı
    let anchor_hue = 220.0;  // mavi-gri (tasarımcının kendi seçimi)
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

**Anchor hue stratejisi:** Tüm nötr renkler (bg/surface/elevated/text/border)
aynı hue'dan beslenir; yalnızca **lightness** değişir. Bu monokrom temel,
temanın dağınık görünmesini engeller ve tutarlı bir zemin sağlar.

**2. Açık lisanslı paletten esinlenme:** Tailwind, Catppuccin, Nord,
Solarized gibi paletlerin HSL değerleri **public domain veya açık lisanslı**
olabilir. Bu kaynaklar kullanılabilir; ancak şu üç nokta gözetilmelidir:

- Lisans dosyasının `LICENSES/` altına eklenmesi.
- Esin kaynağının tema atıflarında belirtilmesi.
- HSL değerlerinin birebir kopyalanması yerine **ondalık hassasiyetinin
  farklılaştırılması** (kararın bağımsız bir tasarım kararı olduğunun
  görünür kılınması).

### Türetme kalıpları

Baz renklerden `opacity()` ile varyant üretmek, tutarlılığı doğal şekilde
sağlar:

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
    element_active: elevated.opacity(0.8),     // basılınca hafif soluklaşma
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
    text_placeholder: text_muted.opacity(0.7),  // muted'un daha solgun hali
    text_disabled: text_muted.opacity(0.5),
    text_accent: accent,
    icon: text,                                 // metin ile aynı
    icon_muted: text_muted,
    icon_disabled: text_muted.opacity(0.5),
    // ... kalan tüm alanlar
}
```

**Görülen örüntüler:**

- `border` / `border_variant` / `border_disabled` → tek bir border anchor
  ve opacity türevleri.
- `element_*` / `ghost_element_*` → surface, elevated ve accent
  karışımları.
- `text_*` / `icon_*` → tek bir text + muted anchor üzerinden opacity
  türetmeleri.

Bu disiplin sayesinde yeni bir alan geldiğinde "hangi anchor'dan türetilmeli?"
sorusu hızlıca cevaplanır.

### Status renkleri için ayrı fonksiyon

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

        // 14 × 3 = 42 alan — her birinin açık bir değer alması gerekir.
        // conflict, created, deleted, hidden, hint, ignored, modified,
        // predictive, renamed, unreachable
        ..elinde_olmayan_default()  // ← YANLIŞ, aşağıdaki nota bakılır
    }
}
```

> **Uyarı:** Eksik alanlar `..unsafe { std::mem::zeroed() }` veya
> `..Default::default()` ile **doldurulmamalıdır**. `Hsla::default()` =
> `(0, 0, 0, 0)` değerini verir ve bu UI'da görünmez. **Tüm 42 alanın açık
> değerle doldurulması** beklenir. Geriye kalan 10 status (conflict, created,
> deleted, hidden vb.) için de aynı kalıp tekrarlanır. Seçilen anchor'lar
> (red, green, yellow, blue) çoğu durumda yeterlidir; her status bu anchor'lardan
> birine map edilebilir. Örneğin `modified = yellow`, `deleted = red`,
> `created = green`.

**Light eşleniği** (`status_colors_light()`): Aynı anchor renkler kullanılır.
Yalnızca **lightness değerleri biraz koyulaşır**; böylece light background
üzerinde okunaklılık korunur. Background ve border opacity'leri de light
zemine göre biraz daha düşük tutulur.

```rust
fn status_colors_light() -> StatusColors {
    // Light bg üzerinde kontrast için lightness 0.45–0.50 (dark'ta 0.55–0.60)
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

**Light ile dark status renk kuralları:**

| Boyut | Dark | Light |
|-------|------|-------|
| Foreground lightness | 0.55–0.60 | 0.40–0.50 (koyu bg'ye karşı doygun) |
| Background opacity | 0.20 | 0.15 (light yüzeyde aşırı dolgu olmaması için) |
| Border opacity | 0.50 | 0.40 |
| Saturation | aynı (her iki tarafta da doygunluk korunur) |

### Syntax fallback — temel kategoriler

`SyntaxTheme::new(vec![])` ile boş bir liste verilirse kod görünümünde tüm
token'lar varsayılan text rengiyle çizilir. Sonuç renksiz ve okunması zor bir
kod görünümüdür. En azından **8 temel kategorinin** doldurulması iyi bir
başlangıçtır:

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

**Bu kategoriler tree-sitter dilleri arasında ortaktır**: `comment`,
`string`, `keyword`, `number`, `function`, `type`, `constant`, `variable`.
Zed'in `languages/*/highlights.scm` dosyalarında bu adlar kullanılır.
Kullanıcı teması `function.builtin` veya `string.escape` gibi daha zengin
kategorilere genişleyebilir. Fallback ise garanti edilen minimum kategori
setini sunar.

### Player ve accent fallback

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

- **Player listesinde en az 1 girdi bulunmalıdır** (Bölüm IV/Konu 15) —
  aksi halde `local()` çağrısı panic atar.
- **Accents listesinde en az 1 girdi bulunmalıdır**. Aksi takdirde
  `color_for_index(idx)` modulo'da `len() == 0` paniğine yol açar. Zed
  kaynağında `Default::default()` `Self::dark()` döndürdüğü için bu liste her
  zaman 13 elemanlıdır.
- **Syntax boş bir `Vec` ile başlatılabilir**. `SyntaxTheme::new`'a boş tuple
  iter geçirilmesinde teknik olarak sakınca yoktur. Bu durumda runtime
  `style_for_name` çağrısı her zaman `None` döndürür.

### Light tema simetrisi

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

- Aynı `anchor_hue` (örneğin 220°) — light ve dark arasında **renk
  ailesi tutarlı** kalır.
- Lightness değerleri tersine çevrilir: dark'ta 0.12 olan bg, light'ta
  0.98 olur.
- Saturation çoğunlukla aynı tutulur; kullanıcı baktığında "aynı tema, ters
  mod" hissini almalıdır.
- Accent için dark'taki hue (örn. 210°) light'ta biraz **daha koyu**
  konumlanır (l=0.50 yerine 0.60) — light bg üzerinde okunaklılık için.

### Fallback test örneği

```rust
#[test]
fn fallback_temalari_tam_dolu() {
    let dark = kvs_default_dark();
    let light = kvs_default_light();

    // Hiçbir alan default/sıfır olmamalı
    assert_ne!(dark.colors().background, gpui::Hsla::default());
    assert_ne!(dark.colors().text, gpui::Hsla::default());
    assert_ne!(dark.status().error, gpui::Hsla::default());

    // Player ve accent en az 1 girdi taşımalı
    assert!(!dark.players().0.is_empty());
    assert!(!dark.accents().0.is_empty());

    // Appearance tutarlı olmalı
    assert_eq!(dark.appearance, Appearance::Dark);
    assert_eq!(light.appearance, Appearance::Light);

    // İsimler benzersiz olmalı
    assert_ne!(dark.name, light.name);
}
```

### Tuzaklar

1. **`Default::default()` ile eksik alanların doldurulması**:
   `Hsla::default()` görünmezdir. 150 + 42 alanın tamamının açık bir
   değerle doldurulması gerekir.
2. **`unsafe { std::mem::zeroed() }` kullanımı**: Sonuç yine sıfır `Hsla`
   olur. Şablon kodda görüldüğünde silinmeli, gerçek kodda hiç
   kullanılmamalıdır.
3. **Anchor olmadan rastgele HSL**: Her alan için farklı hue/saturation
   = dağınık bir tema demektir. Anchor hue + opacity disiplini şarttır.
4. **`palette` sürümünün sabitlenmemesi**: Aynı `hsla(0.583, 0.10, 0.12)`
   ifadesi, farklı `palette` major sürümlerinde **ufak miktarda farklı
   sRGB** üretebilir. Cargo.lock dosyası ile kullanılan sürümün
   sabitlenmesi yerinde olur.
5. **Zed'in `default_colors.rs` HSL değerlerini birebir kopyalamak**:
   GPL-3 ihlali demektir (Bölüm I/Konu 3). Bağımsız anchor değerleri
   seçilmesi gerekir.
6. **Light temasını dark'tan otomatik türetmek**: `l = 1.0 - dark_l`
   gibi formüller **çalışmaz** — gözün light ve dark algısı doğrusal
   değildir. Light tema, ayrı bir tasarım kararı olarak yazılır.
7. **`syntax: Arc::new(SyntaxTheme::new(vec![]))` ile yetinmek**:
   Fallback olarak boş syntax kabul edilir; ancak UI'da kod gösteriliyorsa
   en azından 5–10 temel kategori (comment, string, keyword, number,
   function) doldurulmalıdır. `Theme.styles.syntax` alanı
   `Arc<SyntaxTheme>` tipi beklediği için, içerik boş olsa bile
   `Arc::new(...)` sarması zorunludur.

---

## 26. Built-in tema bundling ve `AssetSource`

Built-in temalar, uygulama ile **birlikte dağıtılan** JSON tema dosyalarıdır.
Bunları paketlemek için üç strateji vardır; seçim ihtiyaca göre yapılır.

### Strateji 1: Diskten yükleme (en basit)

Geliştirme aşamasında ve dev build'lerde genellikle yeterlidir.
`assets/themes/` dizinindeki tüm JSON dosyaları runtime'da okunur:

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

**Akış:**

- Her dosya bir `ThemeFamilyContent` taşır; ailedeki light + dark varyantlar
  ayrılır.
- `theme_content.appearance` değerine göre uygun baseline seçilir
  (Bölüm VIII/Konu 35 reload akışı ile aynı mantık).
- Bir tema dosyasından hata gelse bile diğerlerinin yüklenmeye devam
  etmesi isteniyorsa `try_into`/`continue` deseni kullanılabilir:

```rust
for entry in entries.flatten() {
    if let Err(e) = process_theme_file(entry.path(), registry) {
        tracing::warn!("tema yükleme atlandı: {} ({})", entry.path().display(), e);
        continue;
    }
}
```

**Avantajlar:**

- Sıfır build-time iş yükü.
- Dev'de tema dosyalarını editör ile anlık değiştirip uygulamayı yeniden
  başlatma kolaylığı.

**Dezavantajlar:**

- Binary tek dosya olarak dağıtılmaz; dağıtım sırasında klasör
  yapısının korunması gerekir.
- `themes_dir` yolunun binary'nin nereden çağrıldığına göre çözülmesi
  gerekir.

### Strateji 2: `RustEmbed` ile derleme zamanı gömme

Production binary'lerinde yaygın olarak tercih edilir. Tema dosyaları
**derleme zamanında** binary'ye gömülür; runtime'da disk erişimi gerekmez.

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

- Single-binary dağıtım kolaylığı.
- Çalışma zamanında disk erişimi olmadığı için hızlı init süresi.

**Dezavantajlar:**

- Tema değiştirmek için yeniden derleme gerekir.
- Build süresi artar (her tema dosyası binary'ye girer).
- `debug-embed` özelliği ile dev modda dosyalardan, release modunda ise
  embed davranışı elde edilir.

### Strateji 3: `gpui::AssetSource` entegrasyonu

GPUI'nin kendi asset sistemi kullanılacaksa, özellikle SVG ve icon'larla
tutarlı bir asset pipeline hedefleniyorsa, bu strateji seçilebilir.

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
            // Tema dosyaları AssetSource üzerinden okunabilir
            // ...
        });
}
```

GPUI'nin `cx.asset_source()` API'sı ile tema dosyalarına
`Resource::Embedded(...)` üzerinden erişim mümkün olur:

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

- Icon, SVG ve font ile tutarlı tek bir API.
- Asset cache ve loading davranışının GPUI tarafından yönetilmesi.

**Dezavantajlar:**

- `AssetSource` impl boilerplate'i.
- GPUI sürüm değişimlerinde trait imzasının kayma ihtimali (rehber.md
  #62).

### Karar matrisi

| İhtiyaç | Strateji |
|---------|----------|
| Dev/prototip; tema'ların editörden anlık değiştirilmesi | **1 — diskten** |
| Production single-binary dağıtım, az sayıda tema (<20) | **2 — RustEmbed** |
| GPUI asset pipeline ile tutarlı; tema sayısı çok veya kullanıcı eklenebilir | **3 — AssetSource** |
| Karma kullanım: built-in + kullanıcı tema dizini | Strateji 2 + ek kullanıcı dizin yüklemesi |

### Hot reload (file watcher)

Dev modda tema dosyasını editörden değiştirip uygulamayı yeniden başlatmadan
görmek istenirse:

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

> **Production'da kapatılması gerekir.** Hot reload yalnızca dev tarafında
> kolaylık sağlar. Production kullanıcısı tema dosyasını bu yoldan elle
> değiştirmez. Bu kolaylığın `#[cfg(debug_assertions)]` ile gate edilmesi
> yerinde olur.

### Tema dosyası yapısı

`assets/themes/` altında izlenen konvansiyon:

```
assets/themes/
├── one.LICENSE_MIT       ← <stem>.LICENSE_<tip>
├── ayu.LICENSE_MIT
├── README.md             ← Hangi tema hangi lisans
├── one.json              ← One Light + One Dark
└── ayu.json              ← Ayu varyantları
```

**Her tema dosyası bir `ThemeFamilyContent`'tir** — birden fazla varyant
(light + dark) içerebilir.

### Tuzaklar

1. **`themes_dir` working directory bağımlılığı**: Disk yüklemesinde
   `assets/themes` göreli bir yoldur; binary nereden çalıştırılırsa
   yola göre çözülür. **Mutlak yol** üretilmesi yerinde olur:
   ```rust
   let exe_dir = std::env::current_exe()?.parent().unwrap().to_path_buf();
   let themes_dir = exe_dir.join("assets").join("themes");
   ```
2. **`RustEmbed` derleme süresini şişirir**: Her tema dosyası binary'ye
   gömülür. 100 MB'lık bir tema klasörü 100 MB'lık binary'ye dönüşür.
   Ayıklama için include filtreleri kullanılabilir:
   ```toml
   #[derive(RustEmbed)]
   #[folder = "assets/"]
   #[include = "themes/*.json"]
   #[include = "themes/*.LICENSE_*"]
   ```
3. **Async yüklemede `cx` lifetime'ı**: `cx.spawn` içinde `AsyncApp`
   bulunur; sync bağlamaya geçmek için `cx.update(|cx| ...)` kullanılır
   (Bölüm IX/Konu 39).
4. **Aynı isim çakışması**: Bundled "One Dark" teması ile kullanıcının
   "One Dark" teması karşılaştığında, kullanıcı teması **üzerine yazar**
   (`insert` semantiği). Bu davranış bilinçlidir; kullanıcının
   modifikasyonu önceliklidir.
5. **`baseline` seçiminin atlanması**: Dark bir temanın baseline'ı yanlış
   biçimde light olarak verilirse, eksik alanlar light değerlerden gelir
   ve görsel olarak uyumsuz bir tema ortaya çıkar. Baseline'ın
   `appearance` değerine göre seçilmesi şarttır.
6. **`include_bytes!` yerine `RustEmbed`**: `include_bytes!` tek dosya
   gömme için yeterlidir; onlarca tema için `RustEmbed` tek bir macro
   çağrısıyla aynı işi yapar.
7. **Hot reload'un production'da açık kalması**: File watcher CPU/IO
   maliyetinin yanı sıra güvenlik açısından da risk taşır (kullanıcı path
   injection). `cfg(debug_assertions)` ile gate edilmesi tercih edilir.

---

## 27. Tema asset lisans sınırları

Üç lisans hattı ayrı ayrı izlenmelidir: **bağımlılıklar** (kod), **Zed tema
fixture'ları** (data) ve **fallback paleti** (uygulamanın kendi tasarım
kararı).

### Lisans matrisi

| Kaynak | Tip | Lisans | Sözleşme |
|--------|-----|--------|----------|
| `gpui` (Zed workspace) | Code dependency | Apache-2.0 | Doğrudan dep olarak kullanılır |
| `refineable` | Code dependency | Apache-2.0 | Doğrudan dep |
| `collections` | Code dependency | Apache-2.0 | Doğrudan dep |
| Zed `theme` / `syntax_theme` | Code reference | GPL-3.0-or-later | **Mirror edilir, kopyalanmaz** (Bölüm I/Konu 3) |
| Zed `theme_settings` / `theme_selector` | Code reference | GPL-3.0-or-later | **Yalnızca referans için okunur, dep olarak alınmaz** |
| Zed tema JSON'ları | Data fixture | Tema-özel (MIT/Apache/GPL) | **Lisans dosyasıyla birlikte kopyalanır** |
| `default_colors.rs` HSL değerleri | Design data | GPL-3.0-or-later | **Kopyalanmaz; bağımsız palet seçilir** |

### Zed tema lisansları

Zed'in `assets/themes/` dizininde **her tema kendi alt dizininde** ve kendi
lisansıyla tutulur:

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

**Bundle adlandırma konvansiyonu:**

Tüm temalar Zed'in alt dizin yapısı yerine **düz bir dizinde** tutuluyorsa,
lisans dosyalarının çakışmaması için her dosya tema adıyla
isimlendirilmelidir:

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
   `<stem>.LICENSE_<tip>` dosyasının bulunması gerekir.
2. `<tip>` SPDX kodlarının kısa karşılığı olur: `MIT`, `APACHE`, `BSD3`,
   `MPL2` gibi.
3. `LICENSE_GPL*` ile başlayan dosyalar bundled tema varlıklarına dahil
   edilmez.
4. `README.md` zorunludur — atıf tablosu (telif sahibi, kaynak repo, SPDX
   kodu) burada yer alır.

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

Hangi yapı seçilirse seçilsin, `RustEmbed`/`AssetSource` filtreleri buna göre
güncellenmelidir. `include = "themes/**/*.json"` ile
`include = "themes/*.json"` aynı şeyi kapsamaz. Bu rehberin örnekleri **düz
dizin** yapısını varsayar; alt dizin tercih edilirse path manipülasyonu da
farklılaşır.

Dosya adı `LICENSE` olduğunda içerik tema ile birlikte saklanır. MIT, Apache
ve BSD gibi uyumlu lisanslar bundle içine alınabilir. GPL veya lisansı belirsiz
tema dosyaları ise bundle'a dahil edilmez. Her bundled tema için kaynak repo,
yol, lisans ve telif bilgisi atıf dosyasında yer almalıdır.

### Fallback paleti lisans hatırlatması

Bu konu Bölüm I/Konu 3 ile Konu 25'te işlenmişti; özet olarak:

- Zed'in `default_colors.rs` HSL değerleri **birebir kopyalanmaz**.
- Açık lisanslı paletten (Tailwind, Catppuccin, Nord, Solarized)
  esinlenilebilir; esin kaynağının atıf metninde belirtilmesi gerekir.
- `kvs_default_dark` ve `kvs_default_light` **uygulamanın kendi tasarım
  kararıdır**; lisansı da uygulamanın lisansıyla (MIT/Apache vb.)
  uyumludur.

### Tuzaklar

1. **Lisans dosyasını "sonradan eklemek"**: Build sırasında binary'ye
   tema JSON'u girer ama LICENSE girmezse, **dağıtım anında lisans
   ihlali** oluşur.
2. **`LICENSE_GPL` görmezden gelmek**: Tema dosyasındaki HSL
   değerlerinin "yalnızca JSON" olarak görülmesi telif ihlaline yol açar.
   GPL temalarının kullanılmaması gerekir.
3. **Atıf README'sinin güncellenmemesi**: Yeni bir tema eklendikten sonra
   atıf eklenmediğinde, "hangi tema kim tarafından yazıldı?" sorusu
   cevapsız kalır; lisansın "telif sahibi gösterimi" şartı ihlal edilmiş
   olur.
4. **Cargo dep'lerinde GPL kullanmak**: Yanlışlıkla GPL bir crate
   eklendiğinde uygulamanın **tamamı** GPL'e tabi hale gelir.
5. **`palette` / `refineable` lisans karıştırması**: `palette` MIT/Apache
   dual lisanslıdır; `refineable` Apache-2.0'dır. Bundle ve NOTICE metni
   bu ayrımı doğru yansıtmalıdır.
6. **Fixture dosyasını bir fork'tan almak**: Tema JSON'larının Zed'in
   **upstream** reposundan alınması gerekir; bir fork'tan kopyalandığında
   o fork'un lisans değişikliği veya patch'leri de bulaşır.
7. **Hot reload yolundan kullanıcı dosyası**: Kullanıcının
   `~/.config/kvs/themes/` dizinine koyduğu tema kullanıcının kendi
   sorumluluğundadır; uygulamanın lisans matrisini etkilemez. Built-in
   ile user kaynakları ayrı tutulmalıdır.

---

## 28. JSON schema ve fixture sözleşmesi

**Kaynak dizin:** `kvs_tema/tests/fixtures/`.

Fixture dosyaları, gerçek tema JSON biçimini temsil eden örnek verilerdir.
Bu dosyalar `ThemeFamilyContent`, refinement ve runtime dönüşümünün aynı JSON
sözleşmesini paylaştığını görünür kılar.

### Dizin yapısı

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
├── parse_fixture.rs            ← Zed temaları parse edilebiliyor mu?
├── synthetic.rs                ← Sentetik testler
└── refinement.rs               ← Refinement davranış testleri
```

### `tests/parse_fixture.rs` — gerçek tema testleri

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

**Kalıp:**

- `include_str!` derleme zamanında dosya içeriğini stringe gömer.
- `serde_json_lenient`, Zed JSON'unda yer alan yorum ve trailing comma
  toleransını sağlar.
- `from_content` çağrısı ile **tam akış** test edilir: parse + refinement +
  `Theme` yapısı.

### `tests/synthetic.rs` — kenar durumlar

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

### `tests/refinement.rs` — refinement davranışları

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

### Property testleri — `Hsla::opaque_strategy`

`gpui::Hsla`, `proptest` feature'ı açıkken `Arbitrary` ve
`Hsla::opaque_strategy()` desteğini taşır. Renk türetme ve kontrast helper'ları
yazıldığında, tekil örnekler yerine property test yaklaşımı daha güçlü kapsama
sağlar:

- `Hsla::opaque_strategy()` alpha'yı `1.0` olarak tutar; bu da contrast
  testlerinde şeffaflık kaynaklı belirsizliği ortadan kaldırır.
- `any::<Hsla>()` alpha dahil tüm kanalları `0.0..=1.0` aralığında
  üretir; parse/refinement yuvarlama ve alpha davranış testlerinde
  kullanılır.
- Bu API yalnızca `gpui`'nin `proptest` feature'ı ile birlikte gelir.
  Mirror testlerinde dev-dependency feature setinin buna göre açılması;
  production build'e taşınmaması gerekir.

Örnek bir kullanım alanı: `accent_fill_and_text` benzeri bir helper'ın
light ve dark appearance'ta minimum kontrastı koruduğunun rastgele opak
renklerle doğrulanması.

### `gpui::TestAppContext` ile runtime testleri

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

`gpui::test` attribute'u pencere veya UI sürmez; `TestAppContext` headless bir
context'tir. Tema runtime'ı bu bağlam üzerinde test edilebilir kalır.

### Test stratejisi özeti

| Test türü | Hedef | Dosya |
|-----------|-------|-------|
| Gerçek tema parse | Sözleşme paritesi | `parse_fixture.rs` |
| Sentetik kenar durum | `treat_error_as_none`, bilinmeyen alan, geçersiz hex | `synthetic.rs` |
| Refinement davranışı | `apply_status_color_defaults`, `refine` | `refinement.rs` |
| Runtime kurulum | `init`, `temayi_degistir`, registry | `runtime.rs` + `TestAppContext` |
| Fallback bütünlüğü | Tüm alanların dolu olması | `fallback.rs` |

### Tuzaklar

1. **`include_str!` ile mutlak yol**: Path test dosyasına göre çözülür;
   `include_str!("fixtures/one-dark.json")` ifadesi `tests/fixtures/...`
   olarak yorumlanır. Mutlak yol verilmesi gerekmez.
2. **Fixture lisansının unutulması**: Dosya kopyalanırken `*.LICENSE_*`
   dosyalarının atlanmaması gerekir; fixture JSON'u ile lisans dosyası
   bir arada tutulur.
3. **Test'lerin `init` çağrısı**: `kvs_tema::init(cx)` her test başında
   elle çağrılır; otomatik bir setup mekanizması yoktur. Çağrı,
   `TestAppContext::update` callback'i içinde yapılır.
4. **`assert_eq!` ile Hsla karşılaştırması**: Floating point eşitlik
   yanıltıcı sonuçlara yol açabilir. `assert!((a.h - b.h).abs() < 1e-6)`
   gibi bir epsilon karşılaştırması tercih edilmelidir.
5. **`#[gpui::test]` ile `#[test]` arasındaki seçim**: GPUI runtime
   testleri `gpui::test`; pure sözleşme testleri ise `test` ile
   yazılır. Karıştırılması gereksiz bir overhead yaratır.
6. **Fixture dosyasının yerinde değiştirilmesi**: Test fixture'a yama
   uyguladığında, testler kendi datasını yazıp doğrulamış olur. Fixture
   dosyaları **read-only** kabul edilmelidir; sentetik kenar durumları ayrı
   dosyalarda veya inline string'lerde tutulur.
7. **Fixture'ın eski sözleşmede bırakılması**: Yeni Zed alanları
   eklendiğinde fixture eski halinde kalırsa, gerçek tema örneği yeni
   alanları temsil edemez ve testler bu yüzden parite konusunda
   yanıltıcı sonuçlar verebilir.

---
