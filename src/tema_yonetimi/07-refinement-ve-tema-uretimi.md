# Refinement ve tema üretimi

Content katmanından son Theme nesnesine giden merge, default türetme ve baseline uygulama sırası burada tamamlanır.

---

## 29. Content → Refinement → Theme akışı

**Kaynak modül:** `kvs_tema/src/refinement.rs`.

Üç katmanlı boru hattının orta halkası. Davranışı **stateless** ve
**deterministic**: aynı `Content` aynı `Refinement`'ı üretir.

### Üç katmanın rolü

| Katman | Tip | Soru | Üretildiği yer |
|--------|-----|------|----------------|
| **Content** | `Option<String>` alanlar | Kullanıcı bu alanı yazdı mı? | JSON parse (Bölüm V) |
| **Refinement** | `Option<Hsla>` alanlar | Yazdıysa parse edilebildi mi? | `refinement.rs` (Konu 30) |
| **Theme** | `Hsla` alanlar | Sonuç ne? | `Theme::from_content` (Konu 32) |

### Neden iki ayrı `Option` katmanı?

İlk akla gelen: "Madem string'i Hsla'ya çevireceğiz, neden tek katmanda
yapmayalım?"

**Cevap:** İki **farklı hata türünü** ayırt etmek gerek:

- **Tip-yapısal hata** (Content katmanı): JSON anahtarı yanlış, tip
  yanlış, bilinmeyen enum variant. Serde bunu deserialize sırasında
  yakalar. `treat_error_as_none` (Konu 22) ile `None`'a düşer.
- **Değer-içerik hatası** (Refinement katmanı): String var ama hex
  değil (`"rebeccapurple"`), veya hex'in formatı bozuk (`"#zzz"`).
  `try_parse_color` döner `Err`; refinement bunu sessizce `None`'a yutar.

İki katman = her hata kendi katmanında durdurulur; üst katmanları
kirletmez.

### Akış görünümü — örnek bir alan

Kullanıcı tema JSON'unda:

```json
"border.variant": "#363c46ff"
```

Adım adım:

**1. Content katmanı** (Bölüm V):

```rust
ThemeColorsContent {
    border_variant: Some("#363c46ff".to_string()),
    border: None,                  // JSON'da yok
    border_focused: None,
    // ...
}
```

**2. Refinement katmanı** (Konu 30):

```rust
ThemeColorsRefinement {
    border_variant: Some(hsla(...)),   // try_parse_color başarılı
    border: None,                       // Content'te None idi
    border_focused: None,
    // ...
}
```

**3. Theme katmanı** (Konu 32):

```rust
let mut theme = baseline.clone();
theme.styles.colors.refine(&refinement);
// theme.styles.colors.border_variant = kullanıcının değeri
// theme.styles.colors.border        = baseline'ın değeri (None idi)
```

### Refinement katmanının üç dönüşümü

`refinement.rs` modülünün sorumlulukları:

1. **String → Hsla**: `theme_colors_refinement`, `status_colors_refinement`,
   ve dolaylı olarak `accents`/`players`/`syntax` (Theme::from_content
   içinde).
2. **Türetme** (`apply_status_color_defaults`): fg verilmiş ama bg
   verilmemiş status alanlarına %25 alpha bg üretir.
3. **Refineable çağrısı**: `baseline.refine(&refinement)` ile baseline'ı
   günceller. (Bu adım Konu 32'da; refinement.rs `refine` çağrısı
   yapmaz, sadece Refinement üretir.)

### Modülün dış arayüzü

`refinement.rs` kararlı dış API'leri (Zed `crates/theme_settings/src/schema.rs`
paritesinde):

```rust
pub fn theme_colors_refinement(
    this: &ThemeColorsContent,
    status_colors: &StatusColorsRefinement,
    is_light: bool,
) -> ThemeColorsRefinement;
pub fn status_colors_refinement(c: &StatusColorsContent) -> StatusColorsRefinement;
pub fn apply_status_color_defaults(r: &mut StatusColorsRefinement);
pub fn apply_theme_color_defaults(
    r: &mut ThemeColorsRefinement,
    player_colors: &PlayerColors,
);
pub fn syntax_overrides(
    style: &ThemeStyleContent,
) -> Vec<(String, gpui::HighlightStyle)>;
```

> **Önemli:** `theme_colors_refinement` **üç parametre alır**, tek parametre
> değil. `status_colors` parametresi `version_control_added/deleted`
> alanlarının `status.created`/`status.deleted`'a düşmesi için gerekir;
> `is_light` parametresi `editor_diff_hunk_*` alanlarının appearance'a
> göre opacity sabiti seçmesini sağlar.

Crate-içi kararsız helper'lar:

```rust
fn color(s: &Option<String>) -> Option<gpui::Hsla>;  // tek-satır parse
```

> **Konu 4 (modül haritası)'nda `refinement.rs` "crate-içi" olarak
> işaretliydi.** Tek istisna: `apply_status_color_defaults` ve
> `*_refinement` fonksiyonları Theme::from_content tarafından çağrılır;
> ama tüketici (UI katmanı) bu modüle dokunmaz.

### Saflık ve test edilebilirlik

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

### Tuzaklar

1. **Refinement'i tüketici API'ye sızdırmak**: UI katmanı sadece `Theme`
   görmeli. `Refinement` tipini export etmek tüketici kodu Zed sözleşmesi
   evrim'ine bağlar; iç düzen değişince breaking change.
2. **Refinement'i klonlamak**: `Refinement` 150 `Option<Hsla>` alanı
   içerir; klon ucuz ama gereksiz. `&refinement` ile geç.
3. **`refine()` öncesi `apply_status_color_defaults`'u atlamak**:
   Türetme uygulanmazsa fg-only status temaları baseline'ın bg'sini
   tutar = kullanıcı renkleriyle uyumsuz görüntü. Şart (Konu 31).
4. **Refinement'ı global tutmak**: Refinement geçici bir nesne;
   `from_content` çağrısı içinde yaratılır, kullanılır, düşürülür.
   `static` veya `Arc` ile tutma — anlamsız.

---

## 30. `theme_colors_refinement`, `status_colors_refinement` deseni

İki yardımcı fonksiyon Content tipini Refinement tipine çevirir. **Tek
desenle** çalışır: her alanı `color()` helper'ından geçirir.

### `color()` helper — temel yapı taşı

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
   `Err` ise `None`. `try_parse_color` Konu 21'de.

`color()` `refinement.rs` modülünün **dahili** yardımcısı (`pub`
değil); her renk alanı için tek-satır mantığı tek yere toplar.

### `theme_colors_refinement` deseni

```rust
pub fn theme_colors_refinement(
    this: &ThemeColorsContent,
    status_colors: &StatusColorsRefinement,
    is_light: bool,
) -> ThemeColorsRefinement {
    // 1. Düz alanlar — her biri tek-satır parse:
    let border = color(&this.border);
    // ... border_variant, border_focused, border_selected, border_transparent,
    //     border_disabled, background, surface_background, ... (çoğu alan)

    // 2. Fallback zincirli alanlar — sözleşmenin asıl inceliği burada:
    let scrollbar_thumb_background = color(&this.scrollbar_thumb_background)
        .or_else(|| color(&this.deprecated_scrollbar_thumb_background));
    let scrollbar_thumb_active_background = color(&this.scrollbar_thumb_active_background)
        .or(scrollbar_thumb_background);
    let search_match_background = color(&this.search_match_background);
    let search_active_match_background = color(&this.search_active_match_background)
        .or(search_match_background);
    let version_control_added = color(&this.version_control_added).or(status_colors.created);
    let version_control_deleted = color(&this.version_control_deleted).or(status_colors.deleted);
    let pane_group_border = color(&this.pane_group_border).or(border);
    let panel_background = color(&this.panel_background);
    let element_hover = color(&this.element_hover);
    let panel_overlay_background = color(&this.panel_overlay_background)
        .or(panel_background.map(ensure_opaque));
    let panel_overlay_hover = color(&this.panel_overlay_hover)
        .or(panel_background
            .zip(element_hover)
            .map(|(p, h)| p.blend(h))
            .map(ensure_opaque));
    let minimap_thumb_background = color(&this.minimap_thumb_background)
        .or(scrollbar_thumb_background.map(ensure_non_opaque));
    // ... minimap_thumb_{hover,active}_background, minimap_thumb_border de
    //     scrollbar_thumb_*'tan türer.

    // 3. Appearance-tabanlı opacity sabitleri (`is_light` parametresi burada):
    let (hunk_fill, hunk_hollow_bg, hunk_hollow_border) = if is_light {
        (LIGHT_DIFF_HUNK_FILLED_OPACITY,        // 0.16
         LIGHT_DIFF_HUNK_HOLLOW_BACKGROUND_OPACITY,  // 0.08
         LIGHT_DIFF_HUNK_HOLLOW_BORDER_OPACITY)      // 0.48
    } else {
        (DARK_DIFF_HUNK_FILLED_OPACITY,         // 0.12
         DARK_DIFF_HUNK_HOLLOW_BACKGROUND_OPACITY,   // 0.06
         DARK_DIFF_HUNK_HOLLOW_BORDER_OPACITY)       // 0.36
    };
    // editor_diff_hunk_added_background, editor_diff_hunk_deleted_background
    // version_control_added/deleted * hunk_fill ile türetilir; hollow varyantları
    // hunk_hollow_bg ve hunk_hollow_border opacity'leri ile.

    ThemeColorsRefinement {
        border,
        border_variant: color(&this.border_variant),
        // ... düz alanlar
        scrollbar_thumb_background,
        scrollbar_thumb_active_background,
        search_match_background,
        search_active_match_background,
        version_control_added,
        version_control_deleted,
        pane_group_border,
        panel_overlay_background,
        panel_overlay_hover,
        minimap_thumb_background,
        // ... editor_diff_hunk_* alanları türetilmiş değerlerle
        ..Default::default()
    }
}
```

**Yapı kuralları:**

- **Düz alanlar**: `<alan_adi>: color(&this.<alan_adi>),` (alanların çoğunluğu)
- **Fallback zincirli alanlar**: Bazı alanlar doğrudan `color(...)`
  çağrısından değil, öncelikli fallback zincirinden değer alır. Kanonik
  liste:

| Alan | Düşüş sırası |
|------|--------------|
| `scrollbar_thumb_background` | `→ deprecated_scrollbar_thumb_background` |
| `scrollbar_thumb_active_background` | `→ scrollbar_thumb_background` |
| `search_active_match_background` | `→ search_match_background` |
| `version_control_added` | `→ status_colors.created` |
| `version_control_deleted` | `→ status_colors.deleted` |
| `pane_group_border` | `→ border` |
| `panel_overlay_background` | `→ ensure_opaque(panel_background)` |
| `panel_overlay_hover` | `→ ensure_opaque(panel_background.blend(element_hover))` |
| `minimap_thumb_background` | `→ ensure_non_opaque(scrollbar_thumb_background)` |
| `minimap_thumb_hover_background` | `→ ensure_non_opaque(scrollbar_thumb_hover_background)` |
| `minimap_thumb_active_background` | `→ ensure_non_opaque(scrollbar_thumb_active_background)` |
| `minimap_thumb_border` | `→ scrollbar_thumb_border` |
| `editor_document_highlight_bracket_background` | `→ editor_document_highlight_read_background` |
| `editor_diff_hunk_added_background` | `→ version_control_added × hunk_fill (light=0.16 / dark=0.12)` |
| `editor_diff_hunk_added_hollow_background` | `→ version_control_added × hunk_hollow_bg (0.08 / 0.06)` |
| `editor_diff_hunk_added_hollow_border` | `→ version_control_added × hunk_hollow_border (0.48 / 0.36)` |
| `editor_diff_hunk_deleted_background` | `→ version_control_deleted × hunk_fill` |
| `editor_diff_hunk_deleted_hollow_background` | `→ version_control_deleted × hunk_hollow_bg` |
| `editor_diff_hunk_deleted_hollow_border` | `→ version_control_deleted × hunk_hollow_border` |
| `version_control_modified` | `→ status_colors.modified` |
| `version_control_renamed` | `→ status_colors.modified` |
| `version_control_conflict` | `→ status_colors.ignored` |
| `version_control_ignored` | `→ status_colors.ignored` |
| `version_control_conflict_marker_ours` | `→ deprecated version_control_conflict_ours_background` |
| `version_control_conflict_marker_theirs` | `→ deprecated version_control_conflict_theirs_background` |
| `vim_yank_background` | `→ editor_document_highlight_read_background` |
| `vim_helix_jump_label_foreground` | `→ status_colors.error` |

- **`..Default::default()` zorunlu**: Macro üretilen Refinement tipinin
  tüm alanlarını açıkça vermek istemiyorsan default fallback gerek. Tema
  sözleşmesi büyüdükçe (Zed yeni alan ekledikçe) bu kalıp esneklik
  sağlar — yeni alanı mirror etmeden önce de derleme bozulmaz.
- **`ensure_opaque` / `ensure_non_opaque`** crate-içi yardımcılar:
  `ensure_opaque` alpha'yı her zaman `1.0` yapar; `ensure_non_opaque`
  alpha `0.7` üstündeyse `0.7`'ye indirir, `<= 0.7` değerleri olduğu gibi
  bırakır. Mirror tarafta aynı isimle bekle veya `kvs_renk` modülüne
  yerleştir.

> **Yeni alan semantiği:** `ThemeColors` tarafına `new_color` alanı
> eklendiğinde macro `ThemeColorsRefinement` içinde otomatik olarak
> `new_color: Option<Hsla>` üretir. `..Default::default()` derlemeyi korur,
> fakat alan `theme_colors_refinement` içinde açıkça doldurulmazsa kullanıcı
> temasındaki değer runtime'a taşınmaz.

### `status_colors_refinement` deseni

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

### Neden macro veya `From` impl değil?

İlk akla gelen: "Bu kadar tekrarlı kod için macro yazılır."

**Karşı argüman:**

- **Görsel arama**: Bir alanın refinement'ta nasıl handle edildiğini
  bulmak için `grep "border_variant"` yeterli. Macro varsa bu zincir
  saklı.
- **Alan görünürlüğü**: Yeni alan geldiğinde manuel ekleme zorunluluğu
  alanın refinement zincirinde görünür kalmasını sağlar. Macro otomatik
  üretirse alanı doldurmayı unutmak kolaydır; refinement boş döner.
- **Derleme süresi**: Üç ek satır × 150 alan = 450 satır kod. Macro
  proc-macro derleme süresinden daha hızlı.
- **IDE deneyimi**: `color(&c.border_variant)` üzerine "go to
  definition" Content alanına gider; macro üzerinde IDE indirgemeleri
  öğrenmiyor.

Zed kendi `refinement.rs`'sinde de macro kullanmaz; aynı tek-satır
desenidir.

### `From` trait impl alternatifi

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

### `accents`, `players`, `syntax` neden burada değil?

Bu üç katman `*Content` opsiyonelliği değil, **liste/map** sözleşmesi
taşır. Tek alan-bazlı refinement yetmez; `Theme::from_content` içinde
inline işlenir:

- `accents: Vec<Option<String>>` — refinement değil, **boş ise baseline
  / dolu ise listeyi yeniden parse** kararı (Konu 32).
- `players: Vec<PlayerColorContent>` — aynı boş/dolu kararı.
- `syntax: IndexMap<String, HighlightStyleContent>` — `Vec<(String,
  HighlightStyle)>` üretimi.

Bunlar `*_refinement` fonksiyonu altında modellenmez çünkü `Refineable`
derive `Vec` veya `IndexMap` üzerinde nasıl davranacağını bilmez
(`Refinement = Option<Vec<...>>` mı, yoksa `Vec<Option<...>>` mı?).
Inline işleme daha basit.

### Tuzaklar

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

## 31. `apply_status_color_defaults` ve `apply_theme_color_defaults`: %25 alpha türetme kuralı

`StatusColors` sözleşmesinin özel bir davranışı var: tema yazarı bir
durum için **sadece foreground** verirse, **background**'u otomatik
olarak **%25 alpha**'lı versiyonundan türetmeli. Bu kural Zed'in
tema davranışıyla **birebir tutmak için** gerekli — yoksa kullanıcı
temaları yarı-baseline yarı-yeni karışım renklere düşer.

### Kural

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

### Hangi status için türetme uygulanır?

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
> ve değişikliği yerel API genişletmesi olarak ele al.

### `_border` türetilmez

Sadece `_background` türetilir; `_border` `None` ise baseline'dan kalır.
Tema yazarı `error: "#ff5555"` yazarsa:

- `error` = `Some(hsla(...))`
- `error_background` = türetildi (`#ff555540` benzeri)
- `error_border` = baseline'dan (eğer tema yazarı vermediyse)

Bu kasıtlı — border renginin %50 alpha versiyonu makul olmayabilir;
ayrı bir kararla yazılması beklenir.

### Mekanizma detayı

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

### Çağrı yeri

`apply_status_color_defaults` `Theme::from_content` içinde **sadece bir
yerde** çağrılır:

```rust
let mut status_refinement = status_colors_refinement(&content.style.status);
apply_status_color_defaults(&mut status_refinement);  // ← burada
let mut status = baseline.styles.status.clone();
status.refine(&status_refinement);
```

Sırlama:
1. Content'ten refinement üret (Konu 30).
2. Refinement'a türetme uygula (Konu 31).
3. Baseline'a refinement uygula (Konu 32).

### `theme_color_defaults` muadili?

`ThemeColors` (status değil, normal renkler) için bir türetme yardımcısı
**yoktur**. Sebep: UI renklerinde fg/bg ilişkisi yoktur; `border_variant`
ve `surface_background` farklı alanlardır. Türetme yapay kalır.

Zed'de `apply_theme_color_defaults` adında bir fonksiyon **var**, fakat
tam davranışı Konu 31'da işlenir: yalnızca `element_selection_background`
alanını türetir, kaynak `player_colors.local().selection` rengidir (text_accent
veya başka bir alan değil); kaynak rengin alpha'sı `1.0` ise sonuç alpha'sı
`0.25`'e çekilir, aksi halde olduğu gibi atanır. Yani sabit bir `× 0.25`
formülü **değildir**; alpha < 1.0 olan player selection'ı aynen kopyalanır.
`apply_theme_color_defaults` tarafındaki ek türetme kuralları Konu 31'da
ayrıca anlatılır.

### Test örnekleri

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

### Tuzaklar

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
   uyumsuz görüntü riski. Eklemek yerel API genişletmesidir.
6. **Türetme sırası**: `apply_status_color_defaults` `refine()`'dan
   **önce** çağrılmalı. Sonra çağırırsan baseline'ın `_background`
   değeri zaten yazılmıştır; türetme yerini bulamaz.

### `apply_theme_color_defaults` — refinement default'ları

**Kaynak:** `crates/theme/src/fallback_themes.rs:47`.

Konu 31'te `apply_status_color_defaults`'un %25 alpha türetme kuralını
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
  bir genişletme yapılacaksa Zed referansından bağımsız uygulama kararı olarak
  ele alınmalıdır.

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
merged.refine(&user_refinement);  // Konu 31 birleştirme

apply_theme_color_defaults(&mut merged, &player_colors);
apply_status_color_defaults(&mut status_merged);
```

Default uygulama refinement birleştirmesinden **sonra**, materyalize
etmeden **önce** gelir. Bu sıra, kullanıcı override'ı varsa onun korunmasını
ve sadece eksik (`None`) alanların doldurulmasını garantiler.

---

## 32. `Theme::from_content` birleşik akış

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

### 6 adımlı akış

```rust
pub fn from_content(content: ThemeContent, baseline: &Theme) -> Self {
    // 1. Appearance dönüşümü
    let appearance = match content.appearance {
        AppearanceContent::Light => Appearance::Light,
        AppearanceContent::Dark => Appearance::Dark,
    };

    // ---
    // Aşağıdaki adımlar Zed `refine_theme` (theme_settings.rs:275)
    // sırasını birebir takip eder. Sıra önemlidir:
    //   - status_refinement, theme_refinement'tan ÖNCE çünkü
    //     theme_colors_refinement(`status_colors`) ona ihtiyaç duyar.
    //   - player merge, theme_refinement'tan ÖNCE çünkü
    //     apply_theme_color_defaults(player) ona ihtiyaç duyar.
    // ---

    // 2a. Status refinement + %25 alpha türetme
    let mut status_refinement = status_colors_refinement(&content.style.status);
    apply_status_color_defaults(&mut status_refinement);

    // 2b. Baseline status'u refine et
    let mut status = baseline.styles.status.clone();
    status.refine(&status_refinement);

    // 3. Player merge — baseline player listesi üstüne idx-bazlı override
    let mut player = baseline.styles.player.clone();
    merge_player_colors(&mut player, &content.style.players);

    // 4a. Theme color refinement — 3 parametre: content + status_refinement + is_light
    let is_light = matches!(appearance, Appearance::Light);
    let mut color_refinement = theme_colors_refinement(
        &content.style.colors,
        &status_refinement,
        is_light,
    );

    // 4b. element_selection_background türetmesi (player.local().selection)
    apply_theme_color_defaults(&mut color_refinement, &player);

    // 4c. Baseline theme colors'u refine et
    let mut colors = baseline.styles.colors.clone();
    colors.refine(&color_refinement);

    // 5. Accents: boş ise baseline'a dokunma; dolu ise parse edilebilen
    //    renkleri topla. Zed paritesi (`merge_accent_colors`,
    //    theme_settings/src/theme_settings.rs:395): parse edilebilen renkler
    //    boş çıkarsa accent listesini değiştirme; aksi halde baseline
    //    `Arc<[Hsla]>`'i tamamen değiştir.
    let mut accents = baseline.styles.accents.clone();
    merge_accent_colors(&mut accents, &content.style.accents);

    // (Eski sürüm 5. adımdaki idx-bazlı player merge bu noktada ZATEN
    // çalıştırıldı — adım 3. Aşağıdaki kalan kod blokları sadece syntax
    // ve window bg adımlarını içerir.)
    // 6. Syntax listesini kur. Zed `refine_theme` burada
    //    `theme_settings/src/schema.rs::syntax_overrides` helper'ını
    //    çağırmaz; aynı dönüşümü inline yapıp `SyntaxTheme::new(...)`
    //    ile yeni syntax theme üretir. `SyntaxTheme::merge(...)`
    //    yalnız runtime theme override akışında kullanılır.
    let syntax_highlights = syntax_overrides(&content.style);
    let syntax = Arc::new(SyntaxTheme::new(syntax_highlights));

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

### Adım adım davranış

**Adım 1 — Appearance enum dönüşümü.**

`AppearanceContent::Light` (Bölüm V) → `Appearance::Light` (Bölüm IV).
İki ayrı enum tipi: Content tipi serde için, Theme tipi runtime için.
Doğrudan cast yok; explicit match.

**Adım 2 — Status refinement + %25 alpha türetme.**

`status_colors_refinement` Konu 30'te, `apply_status_color_defaults`
Konu 31'te. Türetme `theme_colors_refinement`'tan **önce** çalıştırılır,
çünkü `theme_colors_refinement` `version_control_added/deleted` alanları
için `status_refinement.created`/`status_refinement.deleted`'a düşer
(Konu 30 fallback tablosu).

**Adım 3 — Player merge.**

`merge_player_colors(&mut player, &content.style.players)` çağrısı
baseline player listesini idx başına field-bazlı override eder
(yukarıdaki kanonik akışta gösterildi). Bu adım theme color refinement'tan
**önce** olmalıdır, çünkü `apply_theme_color_defaults` `player.local().selection`
rengini okur (Konu 31).

**Adım 4 — Theme color refinement + türetme.**

`theme_colors_refinement(content, &status_refinement, is_light)` (3 parametre,
Konu 30'te imza tablosu); ardından `apply_theme_color_defaults(refinement, &player)`
(`element_selection_background` türetir). Sıra Zed paritesinde adım 2'den
sonra, baseline refinement'ından önce.

**Adım 4 (devam) — Baseline.refine() detayı.**

```rust
let mut colors = baseline.styles.colors.clone();
colors.refine(&color_refinement);
```

`Refineable::refine` (Bölüm III/Konu 11) — `Some` alanları override eder,
`None` baseline'dan kalır. `status.refine(&status_refinement)` Adım 2'de
benzer şekilde uygulanır.

**`.clone()` neden?** `baseline: &Theme` immutable; doğrudan üzerinde
`refine` çağıramayız. Baseline registry'de paylaşıldığı için
modifiye edilemez; her tema kendi kopyasını alır.

**Maliyet:** `ThemeColors` ~150 `Hsla` = 150 × 16 byte = 2.4 KiB klon.
`StatusColors` 42 alan = ~700 byte. Toplam ~3 KiB per tema, yüklenirken
bir kez. Hot path değil.

**Adım 3 (devam) — Player merge davranış detayı.**

```rust
let mut player = baseline.styles.player.clone();
merge_player_colors(&mut player, &content.style.players);
```

`merge_player_colors` kanonik akışın 3. adımıdır (status_refinement'tan
sonra, theme_colors_refinement'tan önce) ve aşağıdaki inceliklerle çalışır:

- Tema yazarı `players: [{ "cursor": "#abc" }, { "cursor": "#def" }]`
  yazdı.
- Player 0'ın cursor'u `#abc`, background ve selection **baseline player 0**'dan
  (baseline'ın `local()` slot'undan).
- Player 1'in cursor'u `#def`, background ve selection **baseline player 1**'den
  (slot semantiğine göre orange tonları).

Yani fallback **idx-başına** uygulanır, hepsi `local()`'dan değildir. Bu
davranış Zed `merge_player_colors` sözleşmesiyle eşleşir ve slot
semantiğini korur (Konu 15).

Player slot'u baseline kapasitesinden büyük bir idx ise (örn. baseline 8
slot, tema 10 slot tanımlamış) eksik fallback `PlayerColor::default()`
(siyah/şeffaf) ile doldurulur.

**Adım 5 — Accent merge.**

```rust
merge_accent_colors(&mut accents, &content.style.accents);
```

Zed kaynağı `theme_settings::theme_settings::merge_accent_colors`:

- `user_accent_colors.is_empty()` → baseline'a dokunmaz (`accents`
  baseline'dan klonlu kalır).
- Aksi halde parse edilebilen renkleri `filter_map` ile toplar; eğer
  toplam liste boş çıkarsa (hepsi null veya parse hatası) yine baseline'a
  dokunmaz. Liste en az 1 renk içeriyorsa `accents.0 = Arc::from(colors)`
  ile **baseline tamamen değiştirilir**.

> **Tuzak:** Tema yazarı `accents: ["#aaa", null, "#bbb"]` yazarsa,
> `merge_accent_colors` null'ları ve parse hatalarını eler:
> `accents = [#aaa, #bbb]`. İndeksleme kayar — `#bbb` artık accent
> index 1, baseline'daki orijinal index 2 değil. Zed bu davranışı
> bilinçli koruyor; mirror'da aynı semantiği bozmamak için
> `filter_map` zincirini dimdik kopyala.

**Adım 6 — Syntax: `IndexMap` → `Vec<(String, HighlightStyle)>` →
`Arc::new(SyntaxTheme::new(...))`.**

`theme_settings::schema::syntax_overrides` helper'ı (yukarıdaki Konu 30
imza tablosunda) Content tarafındaki `IndexMap<String, HighlightStyleContent>`'i
`Vec<(String, gpui::HighlightStyle)>`'a çevirir; `HighlightStyleContent`'in
4 alanı (`color`, `background_color`, `font_style`, `font_weight`) parse
edilir, gerisi `Default::default()`'tan gelir (underline, strikethrough,
fade_out vb.).

```rust
let syntax_highlights = syntax_overrides(&content.style);
let syntax = Arc::new(SyntaxTheme::new(syntax_highlights));
```

Zed `theme_settings::refine_theme` bu dönüşümü şu an inline yazar
(`theme_settings.rs:313-331`); `syntax_overrides(style)` helper'ı aynı
`IndexMap` → `Vec<(String, HighlightStyle)>` dönüşümünü verdiği için mirror
tarafta kullanılabilir. Buradaki kritik ayrım şudur:

- **Tam user theme yükleme** (`refine_theme_family` / `refine_theme`):
  syntax bölümü `SyntaxTheme::new(...)` ile kurulur. Baseline syntax üstüne
  field-bazlı merge yapılmaz. **Pratik sonuç:** Tema JSON'ında `syntax`
  bölümü boş veya eksikse `syntax_overrides` boş bir vec döner ve
  `SyntaxTheme::new([])` çağrılır — sonuç **tamamen boş syntax theme**.
  Editor renkleri için tema yazarı `syntax: { ... }` bloğunu mutlaka
  doldurmalıdır; aksi halde syntax highlight'sız bir editör çıkar.
- **Runtime theme override** (`ThemeSettings::apply_theme_overrides` →
  private `modify_theme`): mevcut `base_theme.styles.syntax` üstüne
  `SyntaxTheme::merge(base, syntax_overrides(theme_overrides))` uygulanır.
  Bu yol field-bazlı option-or birleştirir; override'da olmayan capture
  baseline'daki HighlightStyle'ı korur.

Bu yüzden `SyntaxTheme::merge` Konu 18'de ve override akışında kanonik
helper'dır, fakat Konu 32'daki tam JSON → `Theme` pipeline'ının son adımı
değildir. Bu ayrımı karıştırmak, user theme yüklemesinde olmayan baseline
syntax mirası varmış gibi dokümante eder.

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

### Edge case'ler

| Senaryo | Davranış |
|---------|----------|
| Tüm Content tipleri default (boş tema) | Tüm renkler baseline'dan; `name` boş String → boş `SharedString` |
| `appearance: "dark"` ama baseline light tema | `appearance = Dark`, renkler baseline light'tan (mixed); kullanıcı temasıdır |
| Aynı baseline ile iki kez `from_content` | İki ayrı `Theme` (farklı `id`); değerler aynı |
| `syntax: {}` | Boş `Vec<...>` → `Arc<SyntaxTheme>` ama içi boş |
| `accents: [null, null]` | Boş `AccentColors` (filter_map null'ları eler) |
| `players: []` | `player = baseline.styles.player.clone()` |
| `players: [{}]` | 1 PlayerColor, üç alanı da baseline.local'dan |

### Performans profili

| Adım | Maliyet | Not |
|------|---------|-----|
| Appearance match | <1 µs | Trivial |
| Refinement üretim (2 fn) | ~10-30 µs | 150 + 42 alan, her biri Option-and_then |
| `apply_status_color_defaults` | <1 µs | 6 iterasyon |
| `clone() + refine()` × 2 | ~5-10 µs | Memcpy + 192 conditional write |
| Accents/Players/Syntax | ~5-20 µs | Map sayısına bağlı |
| Toplam | **~25-60 µs** | Tema yüklemesi başına |

100 tema yüklensin = ~5 ms. Hot path değil.

### Çağrı yerleri

`Theme::from_content` iki yerden çağrılır:

1. **Bundled tema yükleme** (Bölüm VI): `assets/themes/*.json` →
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

### Tuzaklar

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
   "1", features = ["v4"] }` ekle. Bölüm II/Konu 5 listesinde.
4. **`SystemColors`'u override etmek**: Sözleşmede SystemColors tema
   yazarı tarafından override edilmez. Şu an Content tipinde yer yok;
   isteseler de yazamazlar. Bu kasıtlı.
5. **`Theme.id` üzerinden equality**: İki tema farklı id ama aynı
   içerik = farklı sayılır. Equality için `name` veya `styles`
   karşılaştır.
6. **Accents `filter_map` null davranışı**: Zed davranışı parse edilemeyen
   veya `null` accent girdilerini eler; liste boş kalırsa baseline
   korunur.
7. **`from_content` panic potansiyeli**: Mevcut implementasyonda panic
   yok. Ama `unwrap` ekleyenler dikkat: tema yüklemesi panic edemez,
   sessizce baseline'a düşmeli.

### Zed paritesi: `refine_theme*`, `merge_*`, `load_user_theme`

Yukarıdaki `Theme::from_content` `kvs_tema`'nın tasarım önerisidir. Zed'de
aynı işi yapan **dört public fonksiyon** vardır
(`crates/theme_settings/src/theme_settings.rs`):

| Fonksiyon | Sorumluluk | Karşılık |
|-----------|------------|----------|
| `pub fn refine_theme(theme: &ThemeContent) -> Theme` | Tek `ThemeContent` → `Theme`. Baseline'ı `appearance`'a göre `ThemeColors::light`/`dark` ile alır, refinement + merge + parse pipeline'ını çalıştırır | `Theme::from_content` ile aynı 6 adım |
| `pub fn refine_theme_family(content: ThemeFamilyContent) -> ThemeFamily` | Tüm aileyi `refine_theme` ile çevirip `ThemeFamily { themes, scales: default_color_scales(), … }` üretir | Aile-bazlı yardımcı; tek tema için `refine_theme` yeterli |
| `pub fn merge_player_colors(&mut PlayerColors, &[PlayerColorContent])` | Adım 3'ün kanonik implementasyonu (idx başına field bazında merge) | Konu 32 Adım 3 |
| `pub fn merge_accent_colors(&mut AccentColors, &[AccentContent])` | Adım 5'in kanonik implementasyonu (parse edilen liste boş değilse `Arc<[Hsla]>`'i tamamen değiştir) | Konu 32 Adım 5 |

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

Kullanıcı tema dizini gibi runtime yükleme yolları bu iki fonksiyonu
doğrudan kullanabilir:

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

