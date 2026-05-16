# 1. Ortak Kullanım Temelleri

Zed UI bileşenleri, GPUI element modelinin üstüne kurulan daha dar ve daha tutarlı bir tasarım sistemi katmanıdır. Altta GPUI'nin temel parçaları durur: `div()`, `Render`, `RenderOnce`, `IntoElement`, `Styled`, `ParentElement` ve event handler'lar bu temel katmandan gelir. Zed'in `ui` crate'i ise bu temeli gündelik ekran kodunda daha kolay kullanılacak hale getirir. `Button`, `Label`, `Icon`, `Color`, `Severity`, `ButtonStyle` ve `ToggleState` gibi tipler bu üst katmanın parçasıdır. Bu tipler yalnızca kısa isimler değildir; renk, boyut, focus, spacing ve görsel tutarlılık için ortak bir dil sağlar.

## Import düzeni

Zed içinde yeni UI kodu yazarken çoğu dosya tek bir import ile başlar:

```rust
use ui::prelude::*;
```

`ui::prelude::*`, `gpui::prelude::*` içeriğini de getirir ve üstüne Zed tasarım sisteminde sık kullanılan tipleri ekler. Bu yüzden sıradan bir view veya küçük component örneğinde `Button`, `Icon`, `Label`, `Color`, `h_flex`, `v_flex`, `Context`, `Window`, `App`, `SharedString`, `AnyElement` ve `RenderOnce` için ayrı ayrı `use` satırı yazmanız gerekmez. Bunlar prelude üzerinden hazır gelir.

Prelude her şeyi getirmez. Daha özel kalan bileşenler için açık import gerekir:

```rust
use ui::prelude::*;
use ui::{Callout, ContextMenu, DropdownMenu, List, ListItem, Tooltip};
```

`gpui::prelude::*` yalnızca ham GPUI primitive'leriyle çalışırken yeterli olur. Zed UI bileşenleri kullanılacaksa tercih edilen yol `ui::prelude::*` olmalıdır. Aksi halde tasarım token'ları ve ortak component trait'leri eksik kalır; bazı builder metodları görünmez.

## Render modeli

Zed UI bileşenlerinin büyük kısmı `RenderOnce` implement eder. Bu model, kendi içinde state taşımayan ve builder zinciriyle kurulan küçük UI parçaları için uygundur. Bileşen o render sırasında üretilir, ekrana çizilir ve işi biter; bir sonraki render'a sakladığı ayrı bir durum yoktur:

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

View state'i tutan ekran parçalarında ise `Render` kullanılır. Bu durumda view, kendi alanlarında durum bilgisi saklar ve kullanıcı etkileşimine göre bu bilgi değişir. Etkileşim view state'ini değiştirdiyse, ekrana çizilen çıktının da yenilenmesi için `cx.notify()` çağrılmalıdır. Bu çağrı unutulursa state değişmiş olur, fakat kullanıcı aynı eski render sonucunu görmeye devam eder:

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

`ElementId`, component state'i ve hitbox takibi için kullanılan kararlı kimliktir. Button, tab, list item, table row ve toggle gibi etkileşimli bileşenlere anlamlı ve birbiriyle çakışmayan bir id verilmesi beklenir. Aksi halde GPUI hangi elementin hangi state'i taşıdığını ayırt etmekte zorlanır.

`SharedString`, UI metinleri için tercih edilen string tipidir. `&'static str`, `String` veya `Arc<str>` kaynaklı metinleri, gereksiz bir kopya üretmeden elementlere taşımaya yarar. Render sırasında her metnin tekrar tekrar kopyalanması yerine paylaşılan bir referans üzerinden hareket edilir.

`AnyElement`, farklı somut element tiplerini tek bir slotta tutmak gerektiğinde kullanılır. Örneğin bir list item'in start slot'u bazen `Icon`, bazen özel bir `div()` olabilir. Bu çeşitlilik `AnyElement` ile aynı tipin arkasında toplanır. Buna karşılık public builder API'si generic bir `impl IntoElement` kabul ediyorsa, çağıran tarafın özellikle `AnyElement` üretmesine gerek yoktur; dönüşüm zaten builder tarafından yapılır.

`AnyView`, entity tabanlı ve dinamik view döndüren tooltip, popover veya preview gibi API'lerde sık karşılaşılan bir tiptir. Bir view'in yaşam döngüsü GPUI entity sistemi tarafından yönetiliyorsa, elementten daha uygun olan yüzey `AnyView`'dir; çünkü entity yaşam döngüsü ile element yaşam döngüsü farklı çalışır.

`Entity<ContextMenu>`, `DropdownMenu` ve menü tabanlı popup'larda sıkça görülür. Menü içeriği focus, blur ve action dispatch davranışı taşıdığı için düz bir `AnyElement` yerine entity olarak tutulur; bu sayede menüye dair durumlar bir frame'den diğerine korunur:

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

`Color`, tema bağımsız metin ve ikon rengi seçmek için kullanılan ana semantik token'dır. `Color::Default`, `Muted`, `Hidden`, `Disabled`, `Placeholder`, `Accent`, `Info`, `Success`, `Warning`, `Error`, `Hint`, `Created`, `Modified`, `Deleted`, `Conflict`, `Ignored`, `Debugger`, `Player(u32)`, `Selected` ve version-control renkleri etkin temadan gerçek HSLA değerine çevrilir. Kod "uyarı rengi istiyorum" der; o uyarının açık temada mı koyu temada mı nasıl görüneceğine tema karar verir.

Version control variant'ları açık adlarıyla `VersionControlAdded`, `VersionControlModified`, `VersionControlDeleted`, `VersionControlConflict` ve `VersionControlIgnored` olarak gelir. Diff veya file status UI'larında genel `Created`/`Modified` yerine bu açık adlar tercih edilir; bu sayede diff yüzeyleri tema değişikliklerinde tutarlı kalır.

Özel HSLA gerektiğinde `Color::Custom` kullanılabilir. Yine de tutarlılık için önce semantik renkler düşünülmelidir; özel renge geçmek istisna kabul edilir. `Color` ayrıca `Component` preview'ı olan bir tasarım token'ıdır. Bu sayede component gallery içinde tema renkleri yan yana karşılaştırılabilir.

`Severity`, mesaj ve feedback bileşenlerinde durum seviyesini ifade eder: `Info`, `Success`, `Warning`, `Error`. `Banner` ve `Callout` gibi bileşenler bu seviyeyi arka plan, ikon ve vurgu rengine otomatik olarak bağlar; aynı "warning" seviyesi her yerde aynı görsel dile çevrilir.

`IconName`, `crates/icons/src/icons.rs` içinde tanımlanan gömülü ikon adıdır ve `Icon::new(IconName::Check)` şeklinde kullanılır. Harici bir ikon teması veya kendi SVG'i kullanılması gereken durumlar için `Icon::from_path(...)` ve `Icon::from_external_svg(...)` yardımcıları mevcuttur.

Boyut token'ları component ailesine göre seçilir:

- Metin için `LabelSize`, başlık için `HeadlineSize` kullanılır.
- İkon için `IconSize` vardır.
- Buton için `ButtonSize` ölçeği geçerlidir.
- Progress veya özel çizim yüzeylerinde, gerektiğinde `Pixels` veya `Rems` doğrudan kullanılabilir.

Buton görünümü için `ButtonStyle` kullanılır. `Subtle` varsayılan seçimdir ve sade buton ihtiyaçlarının çoğunu karşılar. `Filled` daha güçlü vurgu gerektiren yerlerde, `Tinted(TintColor::...)` semantik durumlarda (örneğin uyarı veya başarı), `Outlined` ve `OutlinedGhost` ise ikincil eylemler için uygundur.

Toggle state'i `ToggleState` ile ifade edilir. `bool` doğrudan `ToggleState`'e dönüşebilir; üç durumlu seçim gerektiğinde `ToggleState::Indeterminate` veya `ToggleState::from_any_and_all(any_checked, all_checked)` kullanılır. İkinci fonksiyon, "alt öğelerin bir kısmı seçili" gibi karışık durumları otomatik olarak doğru state'e çevirir.

Transparent veya blurred tema kullanan pencere yüzeylerinde arka plan davranışını ayırmak için `ui::theme_is_transparent(cx)` yardımcı fonksiyonu bulunur. Etkin `WindowBackgroundAppearance` değeri `Transparent` veya `Blurred` ise `true` döner ve özel yüzeylerde opak bir fallback gerekip gerekmediğine bu değere göre karar verilir.

## Spacing token'ları (`DynamicSpacing`)

Padding, margin ve gap değerleri için her yerde elle `px(...)` veya `rems(...)` yazmak yerine, `crates/ui/src/styles/spacing.rs` içinde tanımlı `DynamicSpacing` ölçeğini tercih etmek daha doğru olur. Bu enum, kullanıcının UI yoğunluk ayarına (`Compact`, `Default`, `Comfortable`) göre tek noktadan ölçek değiştirir. Uygulama yoğunluğu değiştiğinde spacing değerleri de aynı kurala bağlı olarak uyum sağlar.

- Adlandırma: `Base00`, `Base01`, `Base02`, `Base03`, `Base04`, `Base06`, `Base08`, `Base12`, `Base16`, `Base20`, `Base24`, `Base32`, `Base40`, `Base48`. `BaseXX` içindeki `XX`, varsayılan yoğunluktaki yaklaşık pixel değeridir (`Base04 ≈ 4px`, `Base16 ≈ 16px`).
- Kullanım: `.gap(DynamicSpacing::Base02.px(cx))` veya `.p(DynamicSpacing::Base06.rems(cx))` şeklindedir.
- Üç değer manuel verildiğinde (örneğin `(1, 1, 2)`) yoğunluğa göre değişir; tek değer verildiğinde ise `(n-4, n, n+4)` formülü otomatik uygulanır.
- Mevcut ui density'si `ui::ui_density(cx)` ile sorgulanabilir. Bu dönen değer yalnızca görsel kararlar için kullanılmalıdır; doğrudan spacing hesabı yapmak için değil, çünkü asıl ölçek `DynamicSpacing` üzerinden zaten yönetilir.

Sabit ve değişmeyen bir aralık gerektiğinde `gap_0p5`, `gap_1`, `gap_1p5`, `gap_2` gibi GPUI yardımcıları yeterlidir. Bu sabitler aynı zamanda `h_group*` ve `v_group*` helper'larının arkasında da kullanılır.

## Yükseklik / elevation token'ları (`ElevationIndex`)

`crates/ui/src/styles/elevation.rs` içindeki `ElevationIndex`, bir yüzeyin görsel "z-axis" konumunu anlatır. Doğru elevation seçildiğinde shadow, background ve border kombinasyonu birlikte gelir. Böylece her popover, modal veya panel için aynı görsel ayrıntıları elden ayarlamak gerekmez.

- `Background`: uygulamanın en alt zemini.
- `Surface`: paneller, pane'ler ve ana yüzey container'ları.
- `EditorSurface`: editable buffer yüzeyleri; genellikle `Surface` ile aynı renge sahiptir.
- `ElevatedSurface`: popover ve dropdown gibi paneller üstünde yer alan yüzeyler.
- `ModalSurface`: dialog, alert, modal gibi uygulamayı geçici olarak kilitleyen yüzeyler.

Pratik builder'lar `StyledExt` üzerinden gelir:

- `.h_flex()` ve `.v_flex()`: herhangi bir `Styled` elementi yatay/dikey flex container'a çevirir. `h_flex` ek olarak `items_center()` da uygular, böylece satır içi içerikler dikeyde otomatik ortalanır.
- `.elevation_1(cx)` ve `.elevation_1_borderless(cx)`: hafif yükseltilmiş bir yüzey için kullanılır.
- `.elevation_2(cx)` ve `.elevation_2_borderless(cx)`: popover, popovermenu ve tooltip yüzeylerinde geçerlidir.
- `.elevation_3(cx)` ve `.elevation_3_borderless(cx)`: modal ve announcement yüzeyleri için yüksek elevation sağlar.
- `.border_primary(cx)` ve `.border_muted(cx)`: tema `border` ve `border_variant` renklerini doğrudan `border_color(...)` olarak uygular.
- `.debug_bg_red()`, `.debug_bg_green()`, `.debug_bg_blue()`, `.debug_bg_yellow()`, `.debug_bg_cyan()`, `.debug_bg_magenta()`: layout geliştirme sırasında geçici arka plan rengi verir. Bu yardımcılar production UI'da bırakılmamalı; yalnızca yapı şekillenirken yardımcı olur.

`Popover`, `.elevation_2(cx)` kullanır; `AnnouncementToast` ise `.elevation_3(cx)` ile çalışır. Kendi modal veya dialog yüzeyi elden kurulurken aynı yardımcıların çağrılması gerekir; aksi halde shadow ve background görsel tutarlılığı kaybeder ve aynı dilin parçası gibi durmaz.

## Platform stili (`PlatformStyle`)

`crates/ui/src/styles/platform.rs` içindeki `PlatformStyle`, işletim sistemine bağlı render kararlarını tek bir yerde toplamak için kullanılır. `cfg!` makrolarını veya platform tespitini her bileşene dağıtmak yerine, platforma göre değişen davranışlar bu enum üzerinden ifade edilir.

- Değerler: `Mac`, `Linux`, `Windows`.
- Mevcut platform için `PlatformStyle::platform()` (const fn) çağrılır.
- `KeyBinding::platform_style(...)`, modifier tuşunu ikon olarak mı yoksa metin olarak mı göstereceğini bu enum'a bakarak seçer.

Platforma özel bir davranış kurarken `cfg!` makrolarını her yerde tekrar etmek yerine, `PlatformStyle::platform()` dönüş değerinin tek bir noktada saklanması önerilir. Bu yaklaşım testlerde bu değeri override etmeyi de kolaylaştırır.

## Tipografi yardımcıları (`StyledTypography`, `TextSize`)

`crates/ui/src/styles/typography.rs`, `Headline` ve `Label` dışında düz `div()` üzerine de tema tutarlı tipografi uygulamak için `StyledTypography` trait'ini sağlar. `Styled` implement eden her tip otomatik olarak bu trait'i de devralır; ayrıca derive veya impl yazılması gerekmez.

Sık kullanılan yöntemler şu şekildedir:

- `.font_ui(cx)` ve `.font_buffer(cx)`: tema UI fontunu veya buffer (editor) fontunu uygular.
- `.text_ui_lg(cx)`, `.text_ui(cx)`, `.text_ui_sm(cx)`, `.text_ui_xs(cx)`: sırasıyla `Large`, `Default`, `Small`, `XSmall` boyutlarını seçer.
- `.text_buffer(cx)`: kullanıcının buffer font size'ını uygular; yani editor yazısı ne büyüklükte ise metin de o büyüklükte basılır.
- `.text_ui_size(TextSize::Editor, cx)` ile serbest seçim de yapılabilir.

`TextSize` değerleri ve karşılık geldikleri rem değerleri aşağıdaki gibidir (16px = 1rem kabulü altında):

| `TextSize` | rem | px |
| :-- | :-- | :-- |
| `Large` | `rems_from_px(16.)` | `16` |
| `Default` | `rems_from_px(14.)` | `14` |
| `Small` | `rems_from_px(12.)` | `12` |
| `XSmall` | `rems_from_px(10.)` | `10` |
| `Ui` | settings'teki ui_font_size | dinamik |
| `Editor` | settings'teki buffer_font_size | dinamik |

`Label` ve `Headline` zaten doğru tipografiyi uygular; ek bir çağrıya gerek yoktur. Ancak `div()` veya `h_flex()` gibi yapı taşlarına doğrudan metin yazıldığında `font_ui` ve `text_ui_*` çağrılarının atlanmaması gerekir. Atlanırsa font ailesi sistemden devralınır, tema değişiklikleri yansımaz ve metin temanın geri kalanından kopuk görünmeye başlar.

## Animasyon yardımcıları

`crates/ui/src/styles/animation.rs`, küçük UI animasyonlarını standart süreler ve yönlerle kurmak için bir trait sağlar. Amaç, her yerde ayrı ayrı animasyon parametresi yazmak yerine ortak ve tutarlı bir sözlük kullanmaktır.

- `AnimationDuration`: `Instant` (50ms), `Fast` (150ms), `Slow` (300ms).
- `AnimationDirection`: `FromBottom`, `FromLeft`, `FromRight`, `FromTop`.
- `DefaultAnimations` trait yöntemleri: `.animate_in(direction, fade_in)`, `.animate_in_from_bottom(fade)`, `.animate_in_from_top(fade)`, `.animate_in_from_left(fade)`, `.animate_in_from_right(fade)`.

`DefaultAnimations`, `Styled + Element` implement eden her tipe otomatik olarak bağlanır; ekstra import gerekmez. Daha karmaşık animasyonlar gerektiğinde GPUI'nin `Animation`, `AnimationExt`, `with_animation(...)` ve `with_animations(...)` yapıları doğrudan kullanılabilir. `LoadingLabel`, `SpinnerLabel`, `AiSettingItem` ve `ThreadItem::Running` durumu bu daha düşük seviyeli yoldan animasyon uygulayan örneklerdir.

`ui::CommonAnimationExt` prelude'a dahil değildir, ancak crate kökünden export edilir. `use ui::CommonAnimationExt as _;` ile import edildiğinde, `Transformable` implement eden bileşenlere `.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id, duration)` yardımcıları eklenir. Bir liste içinde ya da tekrarlı bir item içinde aynı animasyon birden fazla kez render edilecekse keyed varyantın seçilmesi önerilir; varsayılan varyant call site konumunu element id olarak aldığı için aynı sahnede tekrar edildiğinde çakışma yaşanabilir.

## `CommonAnimationExt` ve transform kısıtı

`crates/ui/src/traits/transformable.rs` içindeki `Transformable`, kaynakta `pub trait` olarak görünür; ancak `ui.rs` tarafından crate köküne re-export edilmez ve `ui::prelude::*` içinde de bulunmaz. Bu yüzden tüketici kodu için kararlı çağrı yüzeyi `.transform(...)` değildir; doğrudan bu metodu çağırmaya çalışmak crate sınırında trait'i import edememekle sonuçlanır.

Pratikte kullanılabilir public yüzey `ui::CommonAnimationExt`'tir:

```rust
use ui::{CommonAnimationExt as _, prelude::*};

fn render_loading_icon() -> impl IntoElement {
    Icon::new(IconName::LoadCircle)
        .size(IconSize::Small)
        .with_rotate_animation(2)
}
```

`Icon` ve `Vector` içeride `Transformable` implement eder; bu bound sayesinde `.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id, duration)` çağrıları çalışır. Eğer doğrudan bir dönüşüm builder'ı gerekli olursa, mirror tarafta ya `Transformable` bilinçli biçimde re-export edilmeli ya da `Icon::transform` / `Vector::transform` benzeri inherent bir builder eklenmelidir. Mevcut Zed pin'inde bu yüzey, doğrudan tüketici API'si olarak sunulmuyor.

## `ui::utils` modülü

`crates/ui/src/utils.rs` public bir alt modüldür; `is_light`, `reveal_in_file_manager_label` ve `capitalize` doğrudan burada yaşar, geri kalan yardımcılar ise alt modüllerden `ui::utils::*` altında re-export edilir. Bu yardımcılar `ui` crate kökünden ayrıca re-export edilmez; doğru çağrı yolu `ui::utils::is_light`, `ui::utils::WithRemSize`, `ui::utils::FormatDistance` gibi alt modül yoludur. Buna karşılık `BASE_REM_SIZE_IN_PX`, `EDITOR_SCROLLBAR_WIDTH`, `theme_is_transparent` ve `ui_density` ise styles/components re-export zinciri üzerinden doğrudan `ui::...` kökünden erişilebilir; bu fark, sembolün hangi modülde tanımlandığına göre değişir.

Temalama ve görsel:

- `is_light(cx: &mut App) -> bool`: etkin temanın açık mı koyu mu olduğunu söyler. Custom canvas çizimlerinde uygun bir overlay rengi seçmek için kullanışlıdır.
- `theme_is_transparent(cx)` (styles modülünde): transparent veya blurred pencere arka planı için aynı işi yapar; arka plan davranışına bakar.

İçerik ve etiket yardımcıları:

- `capitalize(str: &str) -> String`: ilk karakteri büyük harfe çevirip yeni bir `String` döndürür. Locale-aware değildir; hızlıca bir UI label normalize etmek için tasarlanmıştır.
- `reveal_in_file_manager_label(is_remote: bool) -> &'static str`: macOS'ta `"Reveal in Finder"`, Windows'ta `"Reveal in File Explorer"`, diğer platformlarda `"Reveal in File Manager"` döndürür. `is_remote` true ise her durumda generic etiket döner; çünkü uzak dosyada platform finder'ı anlamlı değildir.

Layout ve ölçü yardımcıları:

- `BASE_REM_SIZE_IN_PX: f32 = 16.0` (`styles/units.rs`): rem tabanlı hesaplamalarda referans değer olarak kullanılır.
- `EDITOR_SCROLLBAR_WIDTH: Pixels` (`components/scrollbar.rs`): `ScrollbarStyle::Editor.to_pixels()` sabitidir. Editor görseliyle gelen scrollbar genişliğini diğer panelle hizalamak gerektiğinde başvurulan değerdir.
- `TRAFFIC_LIGHT_PADDING: f32`: macOS pencere kontrolleri (kapat, küçült, büyüt) için title bar'da ayrılması gereken sol padding'i ifade eder. SDK 26 öncesi 71px, sonrası 78px sabit değer alır.
- `platform_title_bar_height(window: &Window) -> Pixels`: Windows'ta sabit 32px, diğer platformlarda `1.75 * window.rem_size()` (minimum 34px) döndürür.
- `inner_corner_radius(parent_radius, parent_border, parent_padding, self_border) -> Pixels`: iç içe geçmiş yuvarlatılmış köşelerde child elemanın radius'unu hesaplar; dış elemanın radius'una göre iç köşenin doğru gözükmesini sağlar.
- `CornerSolver::new(root_radius, root_border, root_padding)` ve `.add_child(border, padding).corner_radius(level)`: birden fazla seviyeli nesting için aynı problemin toplu çözümünü verir. Tek elemanın değil, tüm zincirin bir kerede çözülmesi gerektiğinde tercih edilir.
- `SearchInputWidth::THRESHOLD_WIDTH` / `MAX_WIDTH` (her ikisi de 1200px) ve `SearchInputWidth::calc_width(container_width)`: arama input'unun container genişliğine göre nasıl yayılacağı veya nerede sınırlanacağıyla ilgilenir.
- `WithRemSize::new(rem_size)`: alt ağaca farklı bir rem boyutunu zorla uygulayan bir elementtir. Kendi ölçeklemesini yöneten settings preview gibi alanlarda kullanılır. `.occlude()` ile pointer event'lerinin elemana ulaşması da engellenebilir.

Erişilebilirlik ve renk kontrastı:

- `calculate_contrast_ratio(fg: Hsla, bg: Hsla) -> f32`: WCAG 2 standardına göre kontrast oranını hesaplar.
- `apca_contrast(text_color: Hsla, background_color: Hsla) -> f32`: APCA Lc (lightness contrast) ölçeğini döndürür. Pozitif değer normal polarity (koyu metin, açık arka plan), negatif değer ters polarity anlamına gelir. Tipik eşikler: `Lc 45` UI metni için minimum, `Lc 60` küçük metin için, `Lc 75` gövde metni için referans alınır.
- `ensure_minimum_contrast(foreground: Hsla, background: Hsla, minimum_apca_contrast: f32) -> Hsla`: foreground rengin lightness değerini ayarlayarak verilen APCA eşiğini sağlayan en yakın rengi döndürür. Tema türetimi sırasında hesaplanan renklerin okunabilir kalmasını garantilemek için en uygun yoldur.

Tarih farkı yardımcıları (`format_distance` modülü):

- `DateTimeType::Naive(NaiveDateTime)` veya `DateTimeType::Local(DateTime<Local>)` iki olası kaynağı temsil eder. `.to_naive()` her ikisini de `NaiveDateTime`'a çevirir.
- `format_distance(date, base_date, include_seconds, add_suffix, hide_prefix) -> String`: iki tarih arasındaki mesafeyi "less than a minute ago", "about 2 hours ago", "3 months from now" gibi insan okuyabilir bir metne çevirir.
- `format_distance_from_now(datetime, include_seconds, add_suffix, hide_prefix) -> String`: aynı işi yapar, ancak `base_date` olarak otomatik `Local::now()` kullanılır.
- `FormatDistance::new(date, base_date).include_seconds(...).add_suffix(...) .hide_prefix(...)`: builder yüzeyidir; thread item, git commit ve activity feed gibi yerlerde tercih edilir. Modülün kaynak yorumu, ileride `time_format` crate'ine taşınacağını söyler; bu yüzden yeni kod yazarken `time_format` çözümlerine de göz atılması faydalı olur.

## Hata yönetimi

UI olay işleyicilerinden veya async task'lardan dönen `Result` değerleri sessizce yok sayılmamalıdır. Bir hata oluştuğunda kullanıcının gerekirse bunu görmesi, geliştiricinin loglarda iz sürebilmesi ve view state'inin tutarlı kalması gerekir. Bu yüzden aynı kuralı her yerde izlemek önemlidir:

- Çağıran fonksiyon `Result` taşıyabiliyorsa hatanın `?` ile yayılması en doğal yoldur.
- View içinde fire-and-forget bir task çalıştırıldığında, hatanın log'a düşürülmesi için `task.detach_and_log_err(cx)` tercih edilir. Buna karşılık düz `task.detach()` hatayı sessizce yok eder ve sebebi sonradan tespit etmek mümkün olmaz.
- Async iş bitiminde view state'inin güncellenmesi gerekiyorsa, task'ın view struct'ı içinde `Task<anyhow::Result<()>>` alanı olarak saklanması ve task içinde `this.update(cx, ...)?` çağrısı ile entity'ye geri dönülmesi uygun bir pattern'dır. Bu yaklaşım Bölüm 15'te "Ayarlar Paneli Satırı" örneğinde uygulanır.
- Tek seferlik bir async sonuç kullanıcıya gösterilecekse, hatanın `last_error: Option<SharedString>` gibi bir state alanına yazılması ve `Callout` veya `Banner` ile sunulması tercih edilir. Görsel durum değiştiği için ayrıca `cx.notify()` çağrısı da gerekir; aksi halde state güncellense bile ekran yenilenmez.
- `unwrap()`, `expect(...)` ve `let _ = ...?` yerine açık eşleştirme yapılması beklenir. `let _ = ...` üretim kodunda yalnızca hatanın bilinçli olarak yok sayıldığı ender durumlarda kabul edilir; o durumlarda da nedeninin yorum satırıyla belirtilmesi gerekir.

`anyhow::Result` ve `anyhow::Context`, Zed crate'lerinde standart hâle gelmiştir. `?` operatörü ile bir hata yayılırken mesaja `with_context(|| ...)` eklendiğinde, log'da hatanın kaynağı çok daha anlaşılır biçimde görünür.
