# Bölüm VI — Fallback, varlık ve fixture tabanı

Tema üretmeden önce lisans-temiz fallback, built-in asset ve test fixture tabanını hazırla; refinement bu baseline üzerine uygulanır.

---

## 25. Fallback tema tasarımı

**Kaynak modül:** `kvs_tema/src/fallback.rs`.

Fallback temalar **runtime'ın güvenlik ağı**: kullanıcı tema yüklemesi
başarısız olsa bile uygulama açılır. Her zaman en az **iki tema**
(light + dark) registry'de bulunur (Bölüm VIII/Konu 36).

### Rol ve sözleşme

| Soru | Cevap |
|------|-------|
| Kaç adet fallback? | **2 — `kvs_default_dark` ve `kvs_default_light`** |
| Kim ne zaman çağırır? | `kvs_tema::init` (Bölüm VIII/Konu 36); ayrıca `Theme::from_content` baseline argümanı |
| Lisans? | **Senin lisansın** — Zed'in paletini taşımak yasak (Bölüm I/Konu 3) |
| Hangi alan eksik kalabilir? | **Hiçbiri** — tüm ThemeColors/StatusColors alanları açık değer almalı |
| Ne zaman değişir? | Tasarım dili veya izlenen Zed tema sözleşmesi yeni alan gerektirirse |

### Palet seçimi disiplini

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
- Esin kaynağını tema atıflarında belirt.
- HSL değerlerini doğrudan kopyala değil; **ondalık hassasiyetini farklılaştır**
  (kendi tasarım kararı olduğunu göster).

### Türetme kalıpları

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

Bu disiplin, yeni alan geldiğinde "hangi anchor'dan türetmeli" sorusunu
hızlı cevaplar.

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

### Syntax fallback — temel kategoriler

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

- **Player listesi en az 1 girdi** (Bölüm IV/Konu 15) — yoksa
  `local()` panic eder.
- **Accents en az 1 girdi** — yoksa `color_for_index(idx)` modulo'da
  `len() == 0` paniği üretir; Zed kaynağında `Default::default()`
  `Self::dark()` döndüğü için her zaman 13 elemandır.
- **Syntax boş Vec** kabul edilebilir — `SyntaxTheme::new`'a boş tuple
  iter geçirilir, runtime `style_for_name` her zaman `None` döner.

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

- Aynı `anchor_hue` (örn. 220°) — light ve dark arasında **renk
  ailesi tutarlı**.
- Lightness "tersine çevril": dark'ta 0.12 olan bg light'ta 0.98.
- Saturation çoğu zaman aynı; gözle bakıldığında "aynı tema, ters
  mod" hissi gerek.
- Accent için dark hue'su (örn. 210°) light'ta biraz **daha koyu**
  (l=0.50 vs 0.60) — light bg üzerinde okunaklılık için.

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

### Tuzaklar

1. **`Default::default()` ile eksik alan doldurmak**: Hsla::default() =
   görünmez. Tüm 150 + 42 alanı açık değerle doldur.
2. **`unsafe { std::mem::zeroed() }` kullanmak**: Aynı sonuç (sıfır
   Hsla). Şablon kodda görsen sil; gerçek kodda asla.
3. **Anchor olmadan rastgele HSL**: Her alan farklı hue/saturation
   = tema dağınık görünür. Anchor hue + opacity disiplini şart.
4. **`palette` versiyonu sabitlememek**: Aynı `hsla(0.583, 0.10, 0.12)`
   farklı `palette` major sürümünde **ufak miktarda farklı sRGB**
   üretebilir. Cargo.lock ile kullanılan sürümü sabitle.
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

## 26. Built-in tema bundling ve `AssetSource`

Built-in temalar = uygulama ile **birlikte dağıtılan** JSON tema
dosyaları. Üç bundling stratejisi var; ihtiyacına göre seç.

### Strateji 1: Diskten yükleme (en basit)

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
- `theme_content.appearance`'a göre uygun baseline seçilir (Bölüm VIII/Konu 35 reload akışı ile aynı).
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

### Strateji 2: `RustEmbed` ile derleme zamanı gömme

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

### Strateji 3: `gpui::AssetSource` entegrasyonu

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

### Karar matrisi

| İhtiyaç | Strateji |
|---------|----------|
| Dev/prototip; tema'ları editörden anlık değiştirme | **1 — diskten** |
| Production single-binary dağıtım, tema sayısı az (<20) | **2 — RustEmbed** |
| GPUI asset pipeline ile tutarlı; tema sayısı çok veya kullanıcı eklenebilir | **3 — AssetSource** |
| Karma: built-in + kullanıcı tema dizini | Strateji 2 + ek kullanıcı dizin yüklemesi |

### Hot reload (file watcher)

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

### Tema dosyası yapısı

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

### Tuzaklar

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
   `cx.update(|cx| ...)` ile sync bağlama düş (Bölüm IX/Konu 39).
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

## 27. Tema asset lisans sınırları

Üç farklı lisans hattını ayrı ayrı izle: **bağımlılıklar** (kod), **Zed
tema fixture'ları** (data), ve **fallback paleti** (kendi tasarım
kararın).

### Lisans matrisi

| Kaynak | Tip | Lisans | Sözleşme |
|--------|-----|--------|----------|
| `gpui` (Zed workspace) | Code dependency | Apache-2.0 | Doğrudan dep olarak kullan |
| `refineable` | Code dependency | Apache-2.0 | Doğrudan dep |
| `collections` | Code dependency | Apache-2.0 | Doğrudan dep |
| Zed `theme`/`syntax_theme` | Code reference | GPL-3.0-or-later | **Mirror, kopyalama** (Bölüm I/Konu 3) |
| Zed `theme_settings`/`theme_selector` | Code reference | GPL-3.0-or-later | **Sadece referans, dep yok** |
| Zed tema JSON'ları | Data fixture | Tema-özel (MIT/Apache/GPL) | **Lisans dosyasıyla beraber kopyala** |
| `default_colors.rs` HSL değerleri | Design data | GPL-3.0-or-later | **Kopyalama; kendi paletini seç** |

### Zed tema lisansları

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
3. `LICENSE_GPL*` ile başlayan dosya bundled tema varlıklarına dahil
   edilmez.
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

Dosya adı `LICENSE` ise içeriği tema ile birlikte saklanır; MIT/Apache/BSD
gibi uyumlu lisanslar bundle içine alınabilir, GPL veya belirsiz lisanslı
tema dosyaları bundle'a dahil edilmez. Her bundled tema için kaynak repo,
yol, lisans ve telif bilgisi atıf dosyasında yer almalıdır.

### Fallback paleti lisans hatırlatması

Bölüm I/Konu 3 ve Konu 25'de işlendi; özetle:

- Zed'in `default_colors.rs` HSL değerlerini **birebir kopyalama**.
- Açık lisanslı paletten esinlen (Tailwind, Catppuccin, Nord, Solarized),
  esin kaynağını atıf metninde belirt.
- `kvs_default_dark` ve `kvs_default_light` **senin tasarım kararın**;
  lisansı senin lisansın (MIT/Apache vs.).

### Tuzaklar

1. **Lisans dosyasını "sonra ekleyeyim"**: Build sırasında binary'ye
   tema JSON'u girer ama LICENSE girmezse **dağıtım anında lisans
   ihlali** oluşur.
2. **`LICENSE_GPL` görmezden gelmek**: Tema dosyasındaki HSL'leri
   "sadece JSON" zannetmek = telif ihlali. GPL temaları **kullanma**.
3. **Atıf README'sini güncellememek**: Yeni tema ekleyip atıf eklemezsen
   "kim hangi tema'yı yazdı?" sorusu cevapsız; lisansın "telif sahibi
   gösterimi" şartı ihlal.
4. **Cargo dep'lerinde GPL**: Yanlışlıkla GPL bir crate eklersen
   uygulamanın **tamamı** GPL'e tabi olur.
5. **`palette`/`refineable` lisans karıştırması**: `palette` MIT/Apache
   dual; `refineable` Apache-2.0. Bundle ve NOTICE metni bu ayrımı doğru
   yansıtmalıdır.
6. **Fixture dosyasını fork'tan almak**: Tema JSON Zed'in **upstream**
   reposundan alınmalı; bir fork'tan kopyalarsan o fork'un lisans
   değişikliği veya patch'i de gelir.
7. **Hot reload yolundan kullanıcı dosyası**: Kullanıcının `~/.config/kvs/themes/`
   dizinine koyduğu tema = kullanıcının kendi sorumluluğu; senin lisans
   matrisin etkilenmez. Built-in vs user'ı ayrı tut.

---

## 28. JSON schema ve fixture sözleşmesi

**Kaynak dizin:** `kvs_tema/tests/fixtures/`.

Fixture dosyaları, gerçek tema JSON biçimini temsil eden örnek veridir.
Bu dosyalar `ThemeFamilyContent`, refinement ve runtime dönüşümünün aynı
JSON sözleşmesini paylaştığını görünür kılar.

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
├── parse_fixture.rs            ← Zed tema'ları parse edebiliyor mu?
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

**Pattern:**

- `include_str!` derleme zamanında dosyayı stringe gömer.
- `serde_json_lenient` — Zed JSON'unda yorum/trailing comma toleransı.
- `from_content` çağrısı ile **tam akış** test edilir (parse + refinement
  + Theme yapısı).

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
`Hsla::opaque_strategy()` desteği taşır. Renk türetme ve kontrast
helper'ları yazıyorsan sentetik tekil örnekler yerine property test ekle:

- `Hsla::opaque_strategy()` alpha'yı `1.0` tutar; contrast testlerinde
  şeffaflık kaynaklı belirsizliği kaldırır.
- `any::<Hsla>()` alpha dahil tüm kanalları `0.0..=1.0` aralığında üretir;
  parse/refinement yuvarlama ve alpha davranışı testlerinde kullanılır.
- Bu API yalnız `gpui` `proptest` feature'ı ile gelir. Mirror testlerinde
  dev-dependency feature set'ini buna göre aç; production build'e taşıma.

Örnek kullanım alanı: Mermaid `accent_fill_and_text` benzeri bir helper'ın
light ve dark appearance'ta minimum kontrastı koruduğunu rastgele opak
renklerle doğrulamak.

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

`gpui::test` attribute pencere/UI sürmez; `TestAppContext` headless
context. Tema runtime'ı bunda %100 test edilebilir.

### Test stratejisi özeti

| Test türü | Hedef | Dosya |
|-----------|-------|-------|
| Gerçek tema parse | Sözleşme parite | `parse_fixture.rs` |
| Sentetik kenar durum | `treat_error_as_none`, bilinmeyen alan, geçersiz hex | `synthetic.rs` |
| Refinement davranış | `apply_status_color_defaults`, `refine` | `refinement.rs` |
| Runtime kurulum | `init`, `temayi_degistir`, registry | `runtime.rs` ile `TestAppContext` |
| Fallback bütünlüğü | Tüm alanlar dolu | `fallback.rs` |

### Tuzaklar

1. **`include_str!` mutlak yol**: Path test dosyasına göredir; `include_str!("fixtures/one-dark.json")`
   `tests/fixtures/...` olarak çözülür. Mutlak yol verme.
2. **Fixture lisansını unutmak**: Dosyayı kopyalarken `*.LICENSE_*`'ı
   atlama; fixture JSON'u ile lisans dosyası birlikte tutulur.
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
7. **Fixture'ı eski sözleşmede bırakmak**: Yeni Zed alanları geldi ama
   fixture eski kaldıysa gerçek tema örneği yeni alanları temsil etmez.

---

