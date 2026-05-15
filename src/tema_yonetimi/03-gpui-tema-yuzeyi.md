# Bölüm III — GPUI'nin tema için kullanılan yüzeyi

Tema sistemi GPUI tipleriyle konuşur; renk, font, pencere ve global state yüzeyini veri modelinden önce öğren.

---

## 6. Renk tipleri: `Hsla`, `Rgba` ve constructor'lar

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
   versiyonunda ufak miktarda farklı `Hsla` üretebilir. Referans Zed
   sürümüyle aynı `palette` major versiyonunu kullan.

---

## 7. Metin/font tipleri: `SharedString`, `HighlightStyle`, `FontStyle`, `FontWeight`

### `SharedString`

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

### `HighlightStyle`

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
- `Eq` ve `Hash` `f32` `fade_out` için elle implement edilir (
  `f.to_be_bytes()` ile `u32`'ye çevrilir; `NaN`'ler `0`'a düşer).
- `Copy + Clone` — pahalı klon değil; tüple iterasyonunda kopyalayarak
  taşı.

### `UnderlineStyle` ve `StrikethroughStyle`

`HighlightStyle.underline` ve `.strikethrough` alanlarının iç tipleri
(`gpui::style`):

```rust
#[derive(Refineable, Copy, Clone, Default, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
pub struct UnderlineStyle {
    pub thickness: Pixels,    // kalınlık
    pub color: Option<Hsla>,  // None → text color
    pub wavy: bool,           // imla denetleyicisi gibi dalgalı çizgi
}

#[derive(Refineable, Copy, Clone, Default, Debug, PartialEq, Eq, Hash, Serialize, Deserialize, JsonSchema)]
pub struct StrikethroughStyle {
    pub thickness: Pixels,
    pub color: Option<Hsla>,
}
```

Tema JSON sözleşmesinde syntax stillerinin underline/strikethrough alanları
**doğrudan yoktur** — `refine_theme` / `modify_theme` syntax block'ta yalnız
`color`, `background_color`, `font_style`, `font_weight` parse eder
(`refine_theme`, `theme_settings.rs:313-329`); `underline/strikethrough/fade_out`
`Default::default()`'tan gelir (her zaman `None` / nötr). Yani **tema
yazarı bir syntax token'ı altı çizili gösteremez** — bu kısıtlama bilinçli
ve Zed referansında geçerli. Mirror'da aynı sınır tutulmalı; aksi halde tema
sözleşmesi şişirilir.

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

### `FontStyle`

```rust
pub enum FontStyle { Normal, Italic, Oblique }
```

- Tema JSON anahtarı: `"font_style": "italic"` (snake_case).
- `.italic()` fluent kısayolu element üzerinde `Italic`'e set eder.
- `Default` = `Normal`.

### `FontWeight`

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
   tarafının görünmezliğidir. Fallback syntax kurarken (Konu 25) her
   kategoriye en az `color: Some(...)` ver.

---

## 8. Pencere: `WindowBackgroundAppearance`, `WindowAppearance`

İki ayrı pencere konsepti: tema yazarının seçtiği **arka plan tipi** ve
sistemin verdiği **light/dark modu**.

### `WindowBackgroundAppearance`

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

### `WindowAppearance`

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

## 9. Bağlam tipleri: `App`, `Context<T>`, `Window`, `BorrowAppContext`

GPUI'de **bağlam** (`cx`) = hangi kaynaklara erişebileceğini belirleyen
parametre. Tema sistemi `App` ve `Context<T>` ile çalışır; `Window`'a
doğrudan dokunmaz.

### `App`

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

### `Context<T>`

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
(Bölüm X) entity'yi temaya bağlamak istediğinde `cx.notify()` çağırır.

### `Window`

Pencere düzeyi state. Tema sistemi `Window` parametresini doğrudan almaz;
çağrıldığı GPUI fonksiyonlar `App`/`Context<T>` üzerinden geçer. İstisna:

- Sistem appearance değişimini izlerken
  `window.observe_window_appearance(...)` veya
  `cx.observe_window_appearance(window, ...)` — `Window` referansı gerekir.

### `BorrowAppContext` trait

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

## 10. `Global` trait ve `cx.set_global / update_global / refresh_windows`

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
> public yardımcı** vardır (Konu 39). O fonksiyon kullanıcı ayar dosyasını
> mutate eder, runtime global'i değil; ikisini aynı ada bağlamak okuyucuyu
> yanıltır. Mirror tarafta runtime tarafının adı `update_theme` (Zed paritesi)
> veya `install_or_update_theme` gibi farklı bir kimlikte tutulmalıdır.

### Tema sisteminin üç global'i

| Global | İçerik | Kim kurar | Kim okur |
|--------|--------|-----------|----------|
| `GlobalThemeRegistry` | `Arc<ThemeRegistry>` | `cx.set_global(GlobalThemeRegistry(...))` (Zed'de `pub(crate) ThemeRegistry::set_global` wrapper'ı bunu yapar) | `ThemeRegistry::global(cx)` |
| `GlobalTheme` | `Arc<Theme>` + `Arc<IconTheme>` (aktif) | `cx.set_global(GlobalTheme::new(...))`, sonra `update_theme` / `update_icon_theme` | `cx.theme()`, `GlobalTheme::icon_theme(cx)` |
| `GlobalSystemAppearance` | `SystemAppearance` | `SystemAppearance::init` | `SystemAppearance::global(cx)` |
| `BufferFontSize`, `UiFontSize`, `AgentUiFontSize`, `AgentBufferFontSize` | `Pixels` (override) | `adjust_*_font_size` çağrıları | `ThemeSettings::*_font_size(cx)` (override yoksa settings değerine düşer). Zed public yüzeyinde yalnız agent newtype'ları re-export edilir; buffer/ui newtype'ları internal kalır |

### `cx.refresh_windows()`

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

## 11. `refineable::Refineable` derive davranışı

**Kaynak:** `refineable` crate (Zed workspace, Apache-2.0).

`#[derive(Refineable)]` her struct için, alanları `Option<T>` olan bir
**ikiz `*Refinement` tipi** üretir; sonra `original.refine(&refinement)`
ile birleştirilir.

### Derive davranışı

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

### `#[refineable(...)]` attribute parametreleri

Listedeki itemlar **Refinement tipine eklenecek derive'lardır**:

```rust
#[refineable(Debug, serde::Deserialize)]
```

→ Refinement tipi `Default + Clone` zaten taşıyor; üstüne `Debug` ve
`serde::Deserialize` eklenir.

Tema sözleşmesinde kullandıklarımız:
- `Debug` — log/test çıktısı.
- `serde::Deserialize` — refinement JSON'dan deserialize edilebilirse.

### Alan-bazlı sarmalama kuralları (`derive_refineable` davranışı)

Macro alan tipine göre üç farklı sarmalama yapar
(`refineable/derive_refineable/src/derive_refineable.rs:524-548`):

| Alan tipi (input) | Refinement'taki tip | Davranış |
|-------------------|---------------------|----------|
| Düz `T` (örn. `Hsla`, `Pixels`) | `Option<T>` | `Some(v)` → override, `None` → baseline korunur |
| `Option<T>` (zaten Option) | `Option<T>` **aynen** (tekrar sarmalanmaz) | Boş ↔ dolu durumu kullanıcı seviyesinden gelir; macro yeniden `Option<Option<T>>` üretmez |
| `#[refineable] U` (nested refineable) | `URefinement` (nested refinement tipi) | Recursive `refine` çağrılır |

`is_optional_field`
(`refineable/derive_refineable/src/derive_refineable.rs:512-522`) bu kararı
**alan tipinin son segmenti `Option` mu** kontrolüne dayandırır: `Option<T>`
sayılır, `core::option::Option<T>` sayılır, ama `MyOption<T>` veya
generic alias **sayılmaz** (false negative). Pratikte sorun çıkmaz, ama
mirror tarafta alan tipini `Option<T>` formunda yazmaya dikkat et.

**Refinement içi yuva (`type Refinement = Self::Refinement`):** Refinement
tipi kendisi de `Refineable` impl eder ve `type Refinement = Self::Refinement`
(yani Refinement'ın Refinement'ı yine kendisidir). Bu sabit-nokta sayesinde
`Cascade<S>` slot listesinde her slot aynı tip refinement taşır.

### `Refineable` trait yüzeyi (tam)

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

### Davranış kuralları

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

### Tema'da nerede kullanılır

- `ThemeColors` ve `StatusColors` `#[derive(Refineable)]` ile işaretlenir
  → `ThemeColorsRefinement`, `StatusColorsRefinement` otomatik üretilir.
- `Theme::from_content`:
  1. Baseline `Theme`'i klonlar.
  2. Content'ten refinement üretir (`theme_colors_refinement`,
     `status_colors_refinement`).
  3. `apply_status_color_defaults` ile türetme uygular.
  4. `colors.refine(&refinement)` ile birleştirir.

Eksik alanlar baseline'dan, dolu alanlar kullanıcı temasından gelir.

### `Cascade` (bilgi — tema'da kullanılmaz)

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

### Tuzaklar

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

