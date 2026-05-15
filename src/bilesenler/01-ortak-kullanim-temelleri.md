# 1. Ortak Kullanım Temelleri

Zed UI bileşenleri, GPUI element modelinin üstüne yerleşen daha kısıtlı ve daha
tutarlı bir tasarım sistemi katmanıdır. `div()`, `Render`, `RenderOnce`,
`IntoElement`, `Styled`, `ParentElement` ve event handler'lar GPUI'den gelir;
`Button`, `Label`, `Icon`, `Color`, `Severity`, `ButtonStyle`, `ToggleState`
gibi tipler ise Zed'in UI crate'inde tanımlıdır.

## Import düzeni

Zed içinde yeni UI kodu yazarken başlangıç import'u genellikle şudur:

```rust
use ui::prelude::*;
```

`ui::prelude::*`, `gpui::prelude::*` içeriğini de getirir ve bunun üstüne Zed
tasarım sistemiyle sık kullanılan tipleri ekler. Bu yüzden sıradan bir view veya
component örneğinde `Button`, `Icon`, `Label`, `Color`, `h_flex`, `v_flex`,
`Context`, `Window`, `App`, `SharedString`, `AnyElement` ve `RenderOnce` için ayrı
import gerekmez.

Prelude her şeyi getirmez. Daha özel bileşenleri açıkça import edin:

```rust
use ui::prelude::*;
use ui::{Callout, ContextMenu, DropdownMenu, List, ListItem, Tooltip};
```

`gpui::prelude::*` yalnızca GPUI primitive'leriyle çalışırken yeterlidir. Zed UI
bileşenleriyle çalışırken `ui::prelude::*` tercih edilmelidir; aksi halde
tasarım token'ları ve ortak component trait'leri eksik kalır.

## Render modeli

Zed UI bileşenlerinin çoğu `RenderOnce` implement eder. Bu model, state taşımayan
ve builder zinciriyle kurulan küçük UI parçaları için uygundur:

```rust
use ui::prelude::*;

fn render_status_title() -> impl IntoElement {
    v_flex()
        .gap_1()
        .child(Headline::new("Project Settings").size(HeadlineSize::Medium))
        .child(
            h_flex()
                .gap_1()
                .child(
                    Icon::new(IconName::Check)
                        .size(IconSize::Small)
                        .color(Color::Success),
                )
                .child(
                    Label::new("Saved")
                        .size(LabelSize::Small)
                        .color(Color::Muted),
                ),
        )
}
```

View state'i tutan ekran parçalarında `Render` kullanılır. Kullanıcı etkileşimi
view state'i değiştiriyorsa, render çıktısının yenilenmesi için `cx.notify()`
çağrılmalıdır:

```rust
use ui::prelude::*;

struct SettingsRow {
    enabled: bool,
}

impl Render for SettingsRow {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        h_flex()
            .gap_2()
            .child(Label::new("Enable diagnostics"))
            .child(
                IconButton::new("toggle-diagnostics", IconName::Check)
                    .toggle_state(self.enabled)
                    .on_click(cx.listener(|this: &mut SettingsRow, _, _, cx| {
                        this.enabled = !this.enabled;
                        cx.notify();
                    })),
            )
    }
}
```

## Temel veri tipleri

`ElementId`, component state'i ve hitbox takibi için kullanılan kararlı kimliktir.
Button, tab, list item, table row ve toggle gibi etkileşimli bileşenlerde anlamlı
ve çakışmayan id kullanın.

`SharedString`, UI metinleri için tercih edilen string tipidir. `&'static str`,
`String` veya `Arc<str>` kaynaklı metinleri gereksiz kopya üretmeden elementlere
taşımaya yarar.

`AnyElement`, farklı concrete element tiplerini tek slotta saklamak gerektiğinde
kullanılır. Örneğin bir list item'in start slot'u bazen `Icon`, bazen özel bir
`div()` olabilir. Public builder API'si generic `impl IntoElement` kabul ediyorsa
çağıran tarafta `AnyElement` üretmeye gerek yoktur.

`AnyView`, entity tabanlı ve dinamik view döndüren tooltip, popover veya preview
gibi API'lerde görülür. Bir view'in yaşam döngüsü GPUI entity sistemi tarafından
yönetiliyorsa `AnyView` elemente göre daha uygun yüzeydir.

`Entity<ContextMenu>`, `DropdownMenu` ve menü tabanlı popup'larda sık görülür.
Menü içeriği focus, blur ve action dispatch davranışı taşıdığı için düz
`AnyElement` yerine entity olarak tutulur:

```rust
use ui::prelude::*;
use ui::ContextMenu;

fn build_sort_menu(window: &mut Window, cx: &mut App) -> Entity<ContextMenu> {
    ContextMenu::build(window, cx, |menu, _, _| {
        menu.header("Sort by")
            .entry("Name", None, |_, _| {})
            .entry("Modified", None, |_, _| {})
    })
}
```

## Tasarım token'ları

`Color`, tema bağımsız semantik metin ve ikon rengi seçmek için kullanılır.
`Color::Default`, `Muted`, `Hidden`, `Disabled`, `Placeholder`, `Accent`,
`Info`, `Success`, `Warning`, `Error`, `Hint`, `Created`, `Modified`,
`Deleted`, `Conflict`, `Ignored`, `Debugger`, `Player(u32)`, `Selected` ve
version-control renkleri etkin temadan gerçek HSLA değerine çevrilir. Version
control variant'ları açık adlarıyla `VersionControlAdded`,
`VersionControlModified`, `VersionControlDeleted`, `VersionControlConflict` ve
`VersionControlIgnored` olarak gelir; diff/file status UI'larında genel
`Created`/`Modified` yerine bunları tercih edin. Özel HSLA gerektiğinde
`Color::Custom` vardır, ancak tutarlılık için semantik renkler önceliklidir.
`Color` ayrıca `Component` preview'ı olan bir tasarım token'ıdır;
gallery'de tema renklerini karşılaştırmak için kullanılabilir.

`Severity`, mesaj ve feedback bileşenlerinde durum seviyesini ifade eder:
`Info`, `Success`, `Warning`, `Error`. `Banner` ve `Callout` gibi bileşenler bu
seviyeyi arka plan, ikon ve vurgu rengine bağlar.

`IconName`, `crates/icons/src/icons.rs` içinde tanımlanan gömülü ikon adıdır.
`Icon::new(IconName::Check)` gibi kullanılır. Harici ikon teması veya SVG gerektiğinde
`Icon::from_path(...)` ve `Icon::from_external_svg(...)` vardır.

Boyut token'larını component ailesine göre seçin:

- Metin için `LabelSize` ve başlık için `HeadlineSize`.
- İkon için `IconSize`.
- Buton için `ButtonSize`.
- Progress veya özel çizim yüzeylerinde gerektiğinde `Pixels` veya `Rems`.

Buton görünümü için `ButtonStyle` kullanılır. `Subtle` varsayılan seçimdir,
`Filled` daha güçlü vurgu için, `Tinted(TintColor::...)` semantik durumlar için,
`Outlined` ve `OutlinedGhost` ikincil eylemler için uygundur.

Toggle state'i `ToggleState` ile ifade edilir. `bool` doğrudan `ToggleState`'e
dönüşebilir; üç durumlu seçimlerde `ToggleState::Indeterminate` veya
`ToggleState::from_any_and_all(any_checked, all_checked)` kullanın.

Transparent veya blurred tema kullanan pencere yüzeylerinde arka plan davranışını
ayırmak için `ui::theme_is_transparent(cx)` yardımcı fonksiyonunu kullanın. Bu
fonksiyon etkin `WindowBackgroundAppearance` değeri `Transparent` veya `Blurred`
ise `true` döner; custom yüzeylerde opak fallback gerekip gerekmediğini seçmek
için uygundur.

## Spacing token'ları (`DynamicSpacing`)

Padding, margin ve gap değerleri için elle `px(...)` veya `rems(...)` yazmak
yerine `crates/ui/src/styles/spacing.rs` içinde tanımlı `DynamicSpacing`
ölçeğini tercih edin. Bu enum kullanıcının UI yoğunluk ayarına (`Compact`,
`Default`, `Comfortable`) göre tek noktadan ölçek değiştirir.

- Adlandırma: `Base00`, `Base01`, `Base02`, `Base03`, `Base04`, `Base06`,
  `Base08`, `Base12`, `Base16`, `Base20`, `Base24`, `Base32`, `Base40`,
  `Base48`. `BaseXX`, `XX` değeri varsayılan yoğunlukta yaklaşık pixel
  değeridir (`Base04 ≈ 4px`, `Base16 ≈ 16px`).
- Kullanım: `.gap(DynamicSpacing::Base02.px(cx))`,
  `.p(DynamicSpacing::Base06.rems(cx))`.
- Üç değer manuel verildiğinde (örn. `(1, 1, 2)`) yoğunluğa göre değişir;
  tek değer verilirse `(n-4, n, n+4)` formülü uygulanır.
- Mevcut ui density'i `ui::ui_density(cx)` ile sorgulayabilirsiniz; bu döner
  değer yalnızca görsel kararlar için kullanılmalı, doğrudan spacing
  hesaplamak için değil.

Sabit aralık gerektiğinde `gap_0p5`, `gap_1`, `gap_1p5`, `gap_2` gibi GPUI
yardımcıları yeterlidir; bu sabitler `h_group*` ve `v_group*` helper'larının
arkasında kullanılır.

## Yükseklik / elevation token'ları (`ElevationIndex`)

`crates/ui/src/styles/elevation.rs`'teki `ElevationIndex`, bir yüzeyin görsel
"z-axis" konumunu ifade eder. Doğru elevation, doğru shadow, background ve
border kombinasyonunu otomatik üretir.

- `Background`: uygulamanın en alt zemini.
- `Surface`: paneller, pane'ler, ana yüzey container'ları.
- `EditorSurface`: editable buffer yüzeyleri (genelde `Surface` ile aynı renk).
- `ElevatedSurface`: popover, dropdown gibi paneller üstünde yer alan yüzeyler.
- `ModalSurface`: dialog, alert, modal gibi uygulamayı geçici olarak kilitleyen
  yüzeyler.

Pratik builder'lar `StyledExt` üzerinden gelir:

- `.h_flex()` ve `.v_flex()`: herhangi bir `Styled` elementi yatay/dikey flex
  container'a çevirir; `h_flex` ayrıca `items_center()` uygular.
- `.elevation_1(cx)` ve `.elevation_1_borderless(cx)`: hafif yükseltilmiş yüzey.
- `.elevation_2(cx)` ve `.elevation_2_borderless(cx)`: popover, popovermenu,
  tooltip yüzeyi.
- `.elevation_3(cx)` ve `.elevation_3_borderless(cx)`: modal ve announcement
  yüzeyi.
- `.border_primary(cx)` ve `.border_muted(cx)`: tema `border` ve
  `border_variant` renklerini doğrudan `border_color(...)` olarak uygular.
- `.debug_bg_red()`, `.debug_bg_green()`, `.debug_bg_blue()`,
  `.debug_bg_yellow()`, `.debug_bg_cyan()`, `.debug_bg_magenta()`: layout
  geliştirirken geçici arka plan rengi verir. Production UI'da bırakılmamalıdır.

`Popover` `.elevation_2(cx)`, `AnnouncementToast` `.elevation_3(cx)` kullanır.
Kendi modal/dialog yüzeyini elden kurarken aynı yardımcıları çağırın; aksi
halde shadow ve background görsel tutarlılığı bozulur.

## Platform stili (`PlatformStyle`)

`crates/ui/src/styles/platform.rs`'teki `PlatformStyle`, render kararlarını
işletim sistemine göre soyutlamak için kullanılır.

- Değerler: `Mac`, `Linux`, `Windows`.
- Mevcut platformu öğrenmek için `PlatformStyle::platform()` (const fn).
- `KeyBinding::platform_style(...)` modifier ikonu vs. metin gösterimini
  bu enum'a göre seçer.

Platforma özel davranış kurarken `cfg!` makrolarını dağıtmak yerine
`PlatformStyle::platform()` döndüren değeri tek noktada saklayın; testlerde
bu değeri override etmek daha kolaydır.

## Tipografi yardımcıları (`StyledTypography`, `TextSize`)

`crates/ui/src/styles/typography.rs`, `Headline` ve `Label` dışında düz
`div()` üzerine de tema tutarlı tipografi uygulamak için `StyledTypography`
trait'ini sağlar. `Styled` implement eden her tip otomatik bu trait'i alır.

Sık kullanılan yöntemler:

- `.font_ui(cx)` ve `.font_buffer(cx)`: tema UI/buffer fontunu uygular.
- `.text_ui_lg(cx)`, `.text_ui(cx)`, `.text_ui_sm(cx)`, `.text_ui_xs(cx)`:
  `Large`, `Default`, `Small`, `XSmall` boyutlarını seçer.
- `.text_buffer(cx)`: kullanıcının buffer font size'ını uygular.
- `.text_ui_size(TextSize::Editor, cx)` gibi serbest seçim.

`TextSize` değerleri ve karşılık geldikleri rem değerleri (16px = 1rem):

| `TextSize` | rem | px |
| :-- | :-- | :-- |
| `Large` | `rems_from_px(16.)` | `16` |
| `Default` | `rems_from_px(14.)` | `14` |
| `Small` | `rems_from_px(12.)` | `12` |
| `XSmall` | `rems_from_px(10.)` | `10` |
| `Ui` | settings'teki ui_font_size | dinamik |
| `Editor` | settings'teki buffer_font_size | dinamik |

`Label` ve `Headline` zaten doğru tipografiyi uygular; `div()` veya `h_flex()`
gibi yapı taşlarına metin yazıyorsanız `font_ui` + `text_ui_*` çağırmadan
bırakmayın. Aksi halde font ailesi sistemden devralınır ve tema değişikliği
yansımaz.

## Animasyon yardımcıları

`crates/ui/src/styles/animation.rs` küçük UI animasyonlarını standart
süreler ve yönlerle kurmak için bir trait sağlar.

- `AnimationDuration`: `Instant` (50ms), `Fast` (150ms), `Slow` (300ms).
- `AnimationDirection`: `FromBottom`, `FromLeft`, `FromRight`, `FromTop`.
- `DefaultAnimations` trait yöntemleri: `.animate_in(direction, fade_in)`,
  `.animate_in_from_bottom(fade)`, `.animate_in_from_top(fade)`,
  `.animate_in_from_left(fade)`, `.animate_in_from_right(fade)`.

`DefaultAnimations`, `Styled + Element` implement eden her tipe otomatik
bağlanır. Daha karmaşık animasyonlar için GPUI'nin `Animation`,
`AnimationExt`, `with_animation(...)` ve `with_animations(...)` yapılarını
doğrudan kullanın; `LoadingLabel`, `SpinnerLabel`, `AiSettingItem` ve
`ThreadItem::Running` durumu bu yolla animasyon uygular.

`ui::CommonAnimationExt` prelude içinde değildir, ancak crate kökünden export
edilir. `use ui::CommonAnimationExt as _;` ile import edildiğinde
`Transformable` implement eden bileşenlere `.with_rotate_animation(duration)` ve
`.with_keyed_rotate_animation(id, duration)` yardımcılarını ekler. Liste veya
tekrarlı item içinde aynı animasyon birden çok kez render edilecekse keyed
varyantı kullanın; varsayılan varyant call site konumunu element id olarak alır.

## `CommonAnimationExt` ve transform kısıtı

`crates/ui/src/traits/transformable.rs` içindeki `Transformable`, kaynakta
`pub trait` olarak görünür, ancak `ui.rs` tarafından crate köküne re-export
edilmez ve `ui::prelude::*` içinde de yoktur. Bu yüzden tüketici kodu için
kararlı çağrı yüzeyi `.transform(...)` değildir.

Pratikte kullanılabilir public yüzey `ui::CommonAnimationExt`'tir:

```rust
use ui::{CommonAnimationExt as _, prelude::*};

fn render_loading_icon() -> impl IntoElement {
    Icon::new(IconName::LoadCircle)
        .size(IconSize::Small)
        .with_rotate_animation(2)
}
```

`Icon` ve `Vector` içeride `Transformable` implement eder; bu bound sayesinde
`.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id,
duration)` çalışır. Doğrudan dönüşüm builder'ı gerekli olursa mirror tarafta
ya `Transformable` bilinçli biçimde re-export edilmeli ya da `Icon::transform`
/ `Vector::transform` gibi inherent builder eklenmelidir. Zed pin'inde bu doğrudan
tüketici API'si değildir.

## `ui::utils` modülü

`crates/ui/src/utils.rs` public alt modüldür; `is_light`,
`reveal_in_file_manager_label` ve `capitalize` doğrudan burada yaşar, geri
kalanlar alt modüllerden `ui::utils::*` altında re-export edilir. Bu yardımcılar
`ui` crate kökünden re-export edilmez; doğru çağrı yolu `ui::utils::is_light`,
`ui::utils::WithRemSize`, `ui::utils::FormatDistance` gibi alt modül yoludur.
`BASE_REM_SIZE_IN_PX`, `EDITOR_SCROLLBAR_WIDTH`, `theme_is_transparent` ve
`ui_density` ise styles/components re-export zinciri üzerinden `ui::...`
kökünden erişilebilir.

Temalama ve görsel:

- `is_light(cx: &mut App) -> bool`: etkin temanın açık/koyu olduğunu söyler;
  custom canvas çizimlerinde uygun overlay rengini seçmek için kullanın.
- `theme_is_transparent(cx)` (styles modülünde): transparent veya blurred
  pencere arka planı için aynı işi yapar.

İçerik ve etiket yardımcıları:

- `capitalize(str: &str) -> String`: ilk karakteri büyük harfe çevirip yeni
  `String` döndürür; locale-aware değil, hızlı UI label normalleştirme için.
- `reveal_in_file_manager_label(is_remote: bool) -> &'static str`: macOS için
  `"Reveal in Finder"`, Windows için `"Reveal in File Explorer"`, diğer
  durumlarda `"Reveal in File Manager"` döndürür. `is_remote` true ise her
  zaman generic etiket döner.

Layout ve ölçü yardımcıları:

- `BASE_REM_SIZE_IN_PX: f32 = 16.0` (`styles/units.rs`): rem tabanlı
  hesaplamalarda referans değer.
- `EDITOR_SCROLLBAR_WIDTH: Pixels` (`components/scrollbar.rs`):
  `ScrollbarStyle::Editor.to_pixels()` sabiti; editor görselli scrollbar
  genişliğini diğer panelle hizalamak için kullanın.
- `TRAFFIC_LIGHT_PADDING: f32`: macOS pencere kontrolleri (kapat/küçült/büyüt)
  için title bar'da ayrılması gereken sol padding; SDK 26 öncesi 71px, sonrası
  78px sabittir.
- `platform_title_bar_height(window: &Window) -> Pixels`: Windows'ta sabit
  32px, diğer platformlarda `1.75 * window.rem_size()` (minimum 34px) döndürür.
- `inner_corner_radius(parent_radius, parent_border, parent_padding, self_border)
  -> Pixels`: iç içe geçmiş yuvarlatılmış köşeler için child radius hesaplar.
- `CornerSolver::new(root_radius, root_border, root_padding)` ve
  `.add_child(border, padding).corner_radius(level)`: birden fazla seviyeli
  nesting için aynı problemin batch çözümü.
- `SearchInputWidth::THRESHOLD_WIDTH` / `MAX_WIDTH` (her ikisi 1200px) ve
  `SearchInputWidth::calc_width(container_width)`: arama input'unun container
  genişliğine göre yayılma/sınırlandırma davranışı.
- `WithRemSize::new(rem_size)`: alt ağaca farklı bir rem boyutunu zorla
  uygulayan element; settings preview gibi kendi ölçeklemesini yöneten
  alanlarda kullanılır. `.occlude()` ile pointer event'lerini engeller.

Erişilebilirlik ve renk kontrastı:

- `calculate_contrast_ratio(fg: Hsla, bg: Hsla) -> f32`: WCAG 2 standardı
  kontrast oranı.
- `apca_contrast(text_color: Hsla, background_color: Hsla) -> f32`: APCA Lc
  (lightness contrast) ölçeği; pozitif değer normal polarity (koyu metin/açık
  arka plan), negatif değer ters polarity. Tipik eşikler: `Lc 45` UI metni
  minimumu, `Lc 60` küçük metin, `Lc 75` gövde metni.
- `ensure_minimum_contrast(foreground: Hsla, background: Hsla,
  minimum_apca_contrast: f32) -> Hsla`: foreground'un lightness'ını
  ayarlayarak verilen APCA eşiğini sağlayan en yakın rengi döndürür; tema
  derived renklerin okunabilir kalmasını garantilemek için ideal.

Tarih farkı yardımcıları (`format_distance` modülü):

- `DateTimeType::Naive(NaiveDateTime)` veya `DateTimeType::Local(DateTime<Local>)`.
  `.to_naive()` her ikisini de `NaiveDateTime`'a çevirir.
- `format_distance(date, base_date, include_seconds, add_suffix, hide_prefix)
  -> String`: iki tarih arası mesafeyi "less than a minute ago", "about 2
  hours ago", "3 months from now" gibi metne çevirir.
- `format_distance_from_now(datetime, include_seconds, add_suffix,
  hide_prefix) -> String`: aynı şey ama `base_date` olarak `Local::now()`
  kullanır.
- `FormatDistance::new(date, base_date).include_seconds(...).add_suffix(...)
  .hide_prefix(...)`: builder yüzeyi; thread item, git commit ve activity
  feed'lerde tercih edilir. Kaynak yorumu bu modülün ileride `time_format`
  crate'ine taşınacağını söyler; yeni kodda `time_format` çözümlerine de göz
  atın.

## Hata yönetimi

UI olay işleyicilerinden veya async task'larından dönen `Result` değerleri
sessizce yutulmamalıdır. Tutarlı bir kuralı izleyin:

- Çağıran fonksiyon `Result` taşıyabiliyorsa hatayı `?` ile yayın.
- View içinde fire-and-forget bir task çalıştırıyorsanız hatayı log'a
  düşürmek için `task.detach_and_log_err(cx)` kullanın; `task.detach()` hatayı
  yok eder ve sebebi tespit edilemez.
- Async iş bitiminde view state'ini güncellemeniz gerekiyorsa task'ı view
  struct'ı içinde `Task<anyhow::Result<()>>` alanı olarak saklayın ve task
  içinde `this.update(cx, ...)?` ile entity'ye geri dönün. Bu pattern Bölüm
  15'te "Ayarlar Paneli Satırı" örneğinde uygulanır.
- Tek seferlik async sonucu kullanıcıya göstermeniz gerekiyorsa hatayı
  `last_error: Option<SharedString>` gibi bir state alanına yazıp
  `Callout` veya `Banner` ile sunun. Görsel state değiştiği için
  `cx.notify()` çağırmayı unutmayın.
- `unwrap()`, `expect(...)` ve `let _ = ...?` yerine açık eşleştirme yapın.
  `let _ =` üretim kodunda yalnızca hatayı bilinçli yok etmek istediğiniz
  ender durumlarda kabul edilir; o durumda da yorum satırıyla nedenini
  belirtin.

`anyhow::Result` ve `anyhow::Context` Zed crate'lerinde standarttır.
`?` operatörü ile hata yayıyorsanız mesaja `with_context(|| ...)` ekleyerek
log'da kaynağı görünür yapın.

