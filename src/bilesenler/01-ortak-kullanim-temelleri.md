# 1. Ortak Kullanım Temelleri

Zed UI bileşenleri, GPUI element modelinin üstüne kurulan daha dar ve daha tutarlı bir tasarım sistemi katmanıdır. Altta GPUI'nin temel parçaları durur: `div()`, `Render`, `RenderOnce`, `IntoElement`, `Styled`, `ParentElement` ve olay işleyicileri. Zed'in `ui` crate'i ise bu temeli gündelik ekran kodunda daha kolay kullanılacak hale getirir. `Button`, `Label`, `Icon`, `Color`, `Severity`, `ButtonStyle` ve `ToggleState` gibi tipler bu üst katmanın parçasıdır. Bu tipler yalnızca kısa isimler değildir; renk, boyut, odak, aralık ve görsel tutarlılık için ortak bir dil sağlar.

## Import düzeni

Zed içinde yeni UI kodu yazılırken çoğu dosyaya tek bir import ile başlanır:

```rust
use ui::prelude::*;
```

`ui::prelude::*` modülü, `gpui::prelude::*` kapsamını da beraberinde getirir ve üstüne Zed tasarım sisteminde sık kullanılan tipleri ekler. Bu sayede sıradan bir view veya küçük bileşen örneğinde `Button`, `Icon`, `Label`, `Color`, `h_flex`, `v_flex`, `Context`, `Window`, `App`, `SharedString`, `AnyElement` ve `RenderOnce` için ayrı ayrı `use` satırı yazılmasına gerek kalmaz. Tüm bu tipler prelude üzerinden hazır olarak sunulur.

Prelude her yapıyı kapsamaz. Daha özel bileşenler için açık (explicit) import yapılması gerekir:

```rust
use ui::prelude::*;
use ui::{Callout, ContextMenu, DropdownMenu, List, ListItem, Tooltip};
```

`gpui::prelude::*` yalnızca ham GPUI primitive'leriyle çalışırken yeterli olur. Zed UI bileşenleri kullanılacaksa `ui::prelude::*` import'unu tercih edilmesi gerekir. Aksi halde tasarım token'ları ve ortak bileşen trait'leri eksik kalır; bazı builder metotlarına erişilemez.

## Prelude ve Bileşen Önizleme Import Sınırı

`ui::prelude::*`, çalışma zamanında UI geliştirirken kullanılan bir kısa yoldur. `ActiveTheme`, `DynamicSpacing`, `RegisterComponent`, `Button`, `Icon`, `Label`, `Color`, `Severity`, `ToggleState` gibi ortak trait'leri ve sık kullanılan GPUI tiplerini tek bir import altında toplar. Bu nedenle, normal bir uygulama ekranında önce `use ui::prelude::*;` yazılır, ardından yalnızca özel ihtiyaç duyulan bileşenler için ek import'lar eklenir.

`ui::component_prelude::*` ise çalışma zamanı ekran kodu geliştirmek yerine, bileşen önizleme veya bileşen galerisi kaydı oluştururken tercih edilir. Bu prelude; `Component`, `ComponentId`, `ComponentScope`, `ComponentStatus`, `RegisterComponent`, `Documented`, `single_example`, `example_group` ve `example_group_with_title` gibi önizleme sistemine ait yardımcı araçları getirir. Üretim aşamasındaki bir UI'da butonu render etmek için `component_prelude` gerekmez; önizleme yazarken ise `RegisterComponent` ve `Documented` derive makroları aynı dosyada kısa import yardımıyla kullanılabilir.

`ui::prelude` ve `ui::component_prelude` yapılarını aynı dosyada karıştırmadan önce dosyanın üstlendiği rolün netleştirilmesi gerekir. Dosya gerçek bir Zed ekranı render ediyorsa `ui::prelude::*` kullanımı yeterlidir. Eğer dosya yalnızca önizleme kaydına örnek ekleme amacı taşıyorsa `ui::component_prelude::*` dahil edilebilir. Aksi takdirde, bileşen kayıt (registry) API'leri sanki çalışma zamanı UI bağımlılığıymış gibi görünerek kafa karışıklığına yol açabilir.

| Prelude | İçerik | Kullanım yeri |
| :-- | :-- | :-- |
| `component_prelude` | `Component`, `ComponentId`, `ComponentScope`, `ComponentStatus`, `RegisterComponent`, `Documented`, `single_example`, `example_group`, `example_group_with_title` | Bileşen önizleme/galeri kaydı yazarken. |
| `single_example` | tek `ComponentExample` üretir | Tek varyantlı önizleme slotu. |
| `example_group` | başlıksız `ComponentExampleGroup` üretir | Birden fazla önizleme örneğini aynı blokta toplar. |
| `example_group_with_title` | başlıklı `ComponentExampleGroup` üretir | Varyantları başlıklı bir grup altında gösterir. |

## Render modeli

Zed UI bileşenlerinin büyük bir kısmı `RenderOnce` trait'ini implement eder. Bu model, kendi içinde durum (state) barındırmayan ve builder zinciriyle kurulan küçük UI parçaları için son derece uygundur. Bileşen render sırasında üretilerek ekrana çizilir ve görevini tamamlar; bir sonraki render aşamasına saklanan bağımsız bir durumu bulunmaz:

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
                    Label::new("Kaydedildi")
                        .size(LabelSize::Small)
                        .color(Color::Muted),
                ),
        )
}
```

View durumu (state) saklayan ekran parçalarında ise `Render` tercih edilir. Bu senaryoda view, kendi alanlarında durum bilgisi barındırır ve bu bilgi kullanıcı etkileşimine bağlı olarak güncellenir. Etkileşim view durumunu değiştirdiğinde, ekrana çizilen çıktının da yenilenmesi için `cx.notify()` çağrısı yapılması gerekir. Bu çağrı atlandığında durum değişmiş olsa bile kullanıcı eski render çıktısını görmeye devam eder:

```rust
use ui::prelude::*;

struct AyarSatiri {
    etkin: bool,
}

impl Render for AyarSatiri {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        h_flex()
            .gap_2()
            .child(Label::new("Tanılamaları etkinleştir"))
            .child(
                IconButton::new("tanilama-gecis", IconName::Check)
                    .toggle_state(self.etkin)
                    .on_click(cx.listener(|this: &mut AyarSatiri, _, _, cx| {
                        this.etkin = !this.etkin;
                        cx.notify();
                    })),
            )
    }
}
```

## Temel veri tipleri

`ElementId`, bileşen durumu ve hitbox takibi için kullanılan sabit kimliktir. `Button`, `Tab`, `ListItem`, `TableRow` ve toggle gibi etkileşimli bileşenlere anlamlı ve birbiriyle çakışmayan benzersiz bir ID tanımlanması gerekir. Aksi takdirde GPUI, hangi elementin hangi durumu taşıdığını ayırt etmekte zorlanacaktır.

`SharedString`, UI metinleri için tercih edilen string tipidir. `&'static str`, `String` veya `Arc<str>` kaynaklı metinlerin, gereksiz bellek kopyalamaları (allocation) yapılmadan elementlere taşınmasını sağlar. Render sırasında her metnin tekrar kopyalanması yerine, paylaşılan bir referans üzerinden işlem gerçekleştirilir.

`AnyElement`, farklı somut element tiplerinin tek bir slotta tutulması gerektiğinde kullanılır. Örneğin bir `ListItem`'in başlangıç slotu bazen `Icon`, bazen de özel bir `div()` olabilir. Bu çeşitlilik `AnyElement` ile aynı arayüzün arkasında toplanabilir. Buna karşılık public builder API'si generic bir `impl IntoElement` kabul ediyorsa, çağıran tarafın özellikle `AnyElement` üretmesine gerek yoktur; ilgili dönüşüm builder metodu tarafından otomatik olarak gerçekleştirilir.

`AnyView`, entity tabanlı çalışan ve dinamik view döndüren tooltip, popover veya önizleme benzeri API'lerde sıklıkla tercih edilen bir tiptir. Bir view'in yaşam döngüsü GPUI entity sistemi tarafından yönetildiğinde, entity yaşam döngüsü element yaşam döngüsünden farklı çalıştığı için `AnyView` kullanımı çok daha uygundur.

`Entity<ContextMenu>`, `DropdownMenu` ve menü tabanlı popup pencerelerinde sıklıkla karşımıza çıkar. Menü içeriği odaklanma, odak kaybı ve eylem tetikleme (action dispatch) davranışlarına sahip olduğu için düz bir `AnyElement` yerine entity olarak yönetilir. Böylece menüye ait durumlar bir kareden (frame) diğerine korunur:

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

`Color`, temadan bağımsız şekilde metin ve ikon rengi seçmek için kullanılan temel semantik token'dır. `Color::Default`, `Muted`, `Hidden`, `Disabled`, `Placeholder`, `Accent`, `Info`, `Success`, `Warning`, `Error`, `Hint`, `Created`, `Modified`, `Deleted`, `Conflict`, `Ignored`, `Debugger`, `Player(u32)`, `Selected` ve sürüm kontrol (version control) renkleri, etkin temaya göre gerçek HSLA değerine dönüştürülür. Kod düzeyinde yalnızca "uyarı rengi" talep edilir; bu uyarının açık veya koyu temada nasıl görüneceğine ise aktif tema karar verir.

Sürüm kontrol varyantları açık adlarıyla `VersionControlAdded`, `VersionControlModified`, `VersionControlDeleted`, `VersionControlConflict` ve `VersionControlIgnored` olarak tanımlıdır. Diff veya dosya durumu (file status) arayüzlerinde genel `Created`/`Modified` yerine bu spesifik adların tercih edilmesi, diff yüzeylerinin tema değişikliklerinde tutarlı kalmasını sağlar.

Özel bir HSLA değeri gerektiğinde `Color::Custom` kullanılabilir. Ancak görsel tutarlılığı korumak adına öncelikle semantik renk seçeneklerinin değerlendirilmesi; özel renklere geçişin istisnai bir durum olarak kabul edilmesi gerekir. `Color` aynı zamanda `Component` önizlemesine sahip bir tasarım token'ıdır. Bu sayede bileşen galerisi içinde tema renklerini yan yana karşılaştırmak mümkündür.

`Severity`, mesaj ve geri bildirim (feedback) bileşenlerinde durum seviyesini ifade eder: `Info`, `Success`, `Warning`, `Error`. `Banner` ve `Callout` gibi bileşenler bu seviyeyi arka plan, ikon ve vurgu rengine otomatik olarak bağlayarak aynı önem derecesinin her yerde tutarlı bir görsel dille sunulmasını sağlar.

`IconName`, `icons` crate'i içinde tanımlanan gömülü ikon adıdır ve `Icon::new(IconName::Check)` şeklinde kullanılır. Harici bir ikon teması veya özel bir SVG dosyası kullanılması gereken durumlar için `Icon::from_path(...)` ve `Icon::from_external_svg(...)` yardımcı metotları sunulmuştur.

Boyut token'ları bileşen ailesine göre seçilir:

- Metin için `LabelSize`, başlıklar için `HeadlineSize` kullanılır.
- İkon boyutları için `IconSize` enum'ı mevcuttur.
- Butonlar için `ButtonSize` ölçeği geçerlidir.
- İlerleme (progress) veya özel çizim yüzeylerinde, gerektiğinde `Pixels` veya `Rems` doğrudan tanımlanabilir.

Buton görünümleri için `ButtonStyle` kullanılır. `Subtle` varsayılan seçenektir ve sade buton ihtiyaçlarının büyük kısmını karşılar. `Filled` daha güçlü bir vurgu gerektiren yerlerde tercih edilirken, `Tinted(TintColor::...)` semantik durumlarda (örneğin uyarı veya başarı), `Outlined` ve `OutlinedGhost` ise ikincil eylemler için son derece uygundur.

Toggle durumu `ToggleState` ile temsil edilir. Bir `bool` değeri doğrudan `ToggleState`'e dönüştürülebilir; üç durumlu seçim gerektiğinde ise `ToggleState::Indeterminate` veya `ToggleState::from_any_and_all(any_checked, all_checked)` kullanılır. Bu ikinci fonksiyon, "alt öğelerin bir kısmı seçili olması" gibi karmaşık senaryoları otomatik olarak doğru duruma dönüştürür.

Şeffaf veya bulanıklaştırılmış (transparent/blurred) temalar kullanan pencere yüzeylerinde arka plan davranışını ayırt etmek amacıyla `ui::theme_is_transparent(cx)` yardımcı fonksiyonu sunulmuştur. Etkin `WindowBackgroundAppearance` değeri `Transparent` veya `Blurred` ise fonksiyon `true` döner ve özel yüzeylerde opak bir yedek katman gerekip gerekmediğine bu sonuca göre karar verilir.

### Ortak token yüzeyi

Token enum'larının çoğu tek başına uzun anlatım gerektirmez; hangi aileye ait oldukları ve hangi değerleri taşıdıkları aşağıdaki tabloda yeterince açıktır:

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `ButtonSize` | buton ailesinin boyut varyantları | Button, IconButton ve yakın akraba kontrollerde tutarlı yükseklik/aralık seçer. |
| `ButtonStyle` | `Subtle`, `Filled`, `Tinted`, `Outlined`, `OutlinedGhost` ve ilgili varyantlar | Butonun vurgu düzeyini ve semantik rengini belirler. |
| `TintColor` | semantik tint renkleri | `ButtonStyle::Tinted(...)` gibi yüzeylerde uyarı, başarı veya bilgi rengi seçer. |
| `ToggleState` | `Selected`, `Unselected`, `Indeterminate`, `from_any_and_all` | İkili veya üç durumlu seçim modelini taşır. |
| `LabelSize` | label ailesinin metin boyutları | `Label` ve label benzeri bileşenlerde metin ölçeği seçer. |
| `HeadlineSize` | headline ailesinin başlık boyutları | `Headline` için başlık ölçeği seçer. |
| `ScrollbarStyle` | `Regular`, `Editor` | Scrollbar'ın görsel genişlik ve stil modelini belirler. |
| `BASE_REM_SIZE_IN_PX` | `16.0` | Rem tabanlı UI hesapları için referans piksel değeridir. |
| `EDITOR_SCROLLBAR_WIDTH` | `ScrollbarStyle::Editor.to_pixels()` | Editor scrollbar genişliğini panel ve tablo yüzeyleriyle hizalamak amacıyla kullanılır. |
| `TRAFFIC_LIGHT_PADDING` | macOS SDK sürümüne göre `71.0` veya `78.0` | macOS pencere kontrol butonları için ayrılacak sol titlebar boşluğudur. |
| `theme_is_transparent` | `cx` üzerinden pencere arka plan görünümünü okur | Transparent/blurred pencere yüzeylerinde opak yedek gerekip gerekmediğini söyler. |

## Spacing token'ları (`DynamicSpacing`)

Padding, margin ve gap değerleri için her yerde elle `px(...)` veya `rems(...)` tanımlamak yerine, `ui` crate'i içinde yer alan `DynamicSpacing` ölçeğinin tercih edilmesi daha doğru bir yaklaşımdır. Bu enum, kullanıcının arayüz yoğunluk ayarına (`Compact`, `Default`, `Comfortable`) göre tek bir noktadan ölçeklendirmeyi değiştirir. Uygulama yoğunluğu güncellendiğinde, aralık değerleri de bu kurala bağlı olarak otomatik uyum sağlar.

- Adlandırma: `Base00`, `Base01`, `Base02`, `Base03`, `Base04`, `Base06`, `Base08`, `Base12`, `Base16`, `Base20`, `Base24`, `Base32`, `Base40`, `Base48` şeklinde tanımlıdır. `BaseXX` içindeki `XX` ifadesi, varsayılan yoğunluktaki yaklaşık piksel değerini belirtir (`Base04 ≈ 4px`, `Base16 ≈ 16px`).
- Kullanım: `.gap(DynamicSpacing::Base02.px(cx))` veya `.p(DynamicSpacing::Base06.rems(cx))` biçimindedir.
- Manuel olarak üç değer tanımlandığında aralıklar yoğunluğa göre uyarlanır; tek bir değer girildiğinde ise `(n-4, n, n+4)` formülü otomatik olarak uygulanır.
- Mevcut arayüz yoğunluğu `ui::ui_density(cx)` ile sorgulanabilir. Dönen bu değer, doğrudan aralık hesaplamaları yapmak yerine yalnızca özel görsel kararlar almak amacıyla kullanılmalıdır; çünkü asıl aralık ölçeği `DynamicSpacing` üzerinden otomatik olarak yönetilmektedir.

Spacing macro yüzeyi:

| API | Rol |
| :-- | :-- |
| `derive_dynamic_spacing` | Spacing enum'larının yoğunluk varyantlarına göre `px(cx)` ve `rems(cx)` gibi yardımcılarını üretir; normal bileşen kodunda doğrudan çağrılmaması gerekir. |

Sabit ve değişmeyen bir aralık gerektiğinde `gap_0p5`, `gap_1`, `gap_1p5`, `gap_2` gibi GPUI yardımcıları yeterli olur. Bu sabitler aynı zamanda `h_group*` ve `v_group*` yardımcılarının arka planında da işlev görür.

## Yükseklik / elevation token'ları (`ElevationIndex`)

`ui` crate'i içindeki `ElevationIndex`, bir yüzeyin görsel dikey eksendeki ("z-axis") konumunu ifade eder. Doğru elevation seviyesi seçildiğinde gölge (shadow), arka plan (background) ve kenarlık (border) kombinasyonu birlikte uygulanır. Böylece her popover, modal veya panel için aynı görsel ayrıntıların manuel olarak ayarlanmasına gerek kalmaz.

- `Background`: uygulamanın en alt zemini.
- `Surface`: paneller, pane'ler ve ana yüzey kapsayıcıları.
- `EditorSurface`: editable buffer yüzeyleri içindir; arka planı `editor_background`'tan gelir ve uygulama zemini `Background` ile aynı tonu paylaşır, `Surface` ile değil.
- `ElevatedSurface`: popover ve dropdown gibi paneller üstünde yer alan yüzeyler.
- `ModalSurface`: dialog, alert, modal gibi uygulamayı geçici olarak kilitleyen yüzeyler.

Pratik builder'lar `StyledExt` üzerinden gelir:

- `.h_flex()` ve `.v_flex()`: herhangi bir `Styled` elementi yatay/dikey flex kapsayıcıya çevirir. `h_flex` ek olarak `items_center()` da uygular, böylece satır içi içerikler dikeyde otomatik ortalanır.
- `.elevation_1(cx)` ve `.elevation_1_borderless(cx)`: hafif yükseltilmiş yüzeyler için tercih edilir.
- `.elevation_2(cx)` ve `.elevation_2_borderless(cx)`: popover, popovermenu ve tooltip yüzeylerinde geçerlidir.
- `.elevation_3(cx)` ve `.elevation_3_borderless(cx)`: modal ve announcement yüzeyleri için yüksek elevation sağlar.
- `.border_primary(cx)` ve `.border_muted(cx)`: tema `border` ve `border_variant` renklerini doğrudan `border_color(...)` olarak uygular.
- `.debug_bg_red()`, `.debug_bg_green()`, `.debug_bg_blue()`, `.debug_bg_yellow()`, `.debug_bg_cyan()`, `.debug_bg_magenta()`: düzen geliştirme sırasında geçici arka plan renkleri tanımlar. Bu yardımcı metotların üretim kodunda (production UI) bırakılmaması gerekir; yalnızca yapının şekillendirilmesi aşamasında kolaylık sağlarlar.

`Popover` bileşeni `.elevation_2(cx)` kullanırken, `AnnouncementToast` `.elevation_3(cx)` ile çalışır. Özel modal veya diyalog yüzeyleri tasarlanırken aynı yardımcıların çağrılması son derece önemlidir; aksi takdirde gölge ve arka plan görsel tutarlılığını kaybederek ortak tasarım dilinin dışına çıkacaktır.

`ElevationIndex` doğrudan renk değerleri de döndürebilir. `ElevationIndex::on_elevation_bg(cx)` ilgili elevation üstünde yer alan dolu bir öğenin kullanacağı karşı yüzey rengini sunar; `ElevationIndex::darker_bg(cx)` ise mevcut yüzeye kıyasla daha koyu bir arka plan rengi belirler (zemin zaten koyuysa daha açık bir renge dönüş yapar). Bu iki metot, yalnızca özel bir bileşenin kendi yüzeyini ve içindeki öğeyi manuel olarak çizdiği durumlarda kullanılmalıdır; sıradan panel, popover ve modal pencereler için `.elevation_*` yardımcıları çok daha tutarlı sonuçlar verir.

## Ortak Bileşen Trait'leri

`ui` crate'i altında yer alan `clickable`, `disableable`, `fixed`, `styled_ext`, `toggleable`, `transformable`, `visible_on_hover` ve `animation_ext` modülleri, bileşenlerin ortak builder arayüzünü tanımlar. Geliştiriciler bu modülleri genellikle tek tek import etmez; ilgili trait, kullanılan bileşen veya prelude üzerinden doğrudan erişilebilir hale gelir. Yine de trait isimlerini bilmek yararlıdır, çünkü aynı builder metodu farklı bileşenlerde aynı davranışı temsil eder.

- `Clickable`: `.on_click(...)` ve `.cursor_style(...)` davranışının ortak sözleşmesidir. Buton, disclosure, popover trigger veya özel etkileşimli element aynı tıklama modeline bağlanır.
- `Disableable`: `.disabled(bool)` çağrısının ortak anlamını verir. Devre dışı durum yalnız renk değil, çoğu bileşende işleyici bağlanmaması veya etkileşimin kaldırılması demektir.
- `FixedWidth`: `.width(...)` ve `.full_width()` gibi genişlik kararlarının ortak yüzeyidir. Özellikle `Button`, `ButtonLike`, `IconButton` ve benzeri kontrollere aynı hizalama davranışını uygular.
- `Toggleable`: `.toggle_state(...)` ile seçili veya açık görünümü verir. Bu trait uygulama durumunu değiştirmez; view durumu yine işleyici içinde güncellenir.
- `VisibleOnHover`: parent `.group(name)` ile child `.visible_on_hover(name)` eşleşmesini kurar. Hover eylem butonlarında doğru grup adı tanımlanmazsa element beklenen anda görünmez.
- `StyledExt`: `.h_flex()`, `.v_flex()`, `.elevation_*`, `.border_primary(cx)` ve debug background yardımcılarını sağlar. Ham `div()` kodu yerine bu yardımcılar tutarlı aralık ve elevation yapısını korur.
- `Transformable`: doğrudan geliştirici tarafından import edilmez; mevcut public kullanım şekli `CommonAnimationExt` üzerinden dönen döndürme (rotate) animasyon yardımcılarıdır.

| Trait veya modül | Builder/metot yüzeyi | Kısa anlamı |
| :-- | :-- | :-- |
| `Clickable` | `on_click`, `cursor_style` | Ortak tıklama callback'i ve cursor davranışı. |
| `Disableable` | `disabled` | Etkileşimi ve disabled görsel durumu birlikte yönetir. |
| `FixedWidth` | `width`, `full_width` | Kontrol genişliğini sabit veya full-width yapar. |
| `Toggleable` | `toggle_state` | Seçili/açık görünümünü view durumundan alır. |
| `VisibleOnHover` | `visible_on_hover` | Parent group hover durumuna göre child görünürlüğünü değiştirir. |
| `StyledExt` | `h_flex`, `v_flex`, `elevation_*`, `border_primary`, `border_muted`, `debug_bg_*` | Styled elementlere Zed UI'ya özgü layout/elevation yardımcıları ekler. |
| `Transformable` | `transform` | Public kullanımda doğrudan değil, `CommonAnimationExt` bound'u üzerinden kullanılır. |
| `clickable` | modül export'u | `Clickable` trait'inin kaynak modülüdür. |
| `disableable` | modül export'u | `Disableable` trait'inin kaynak modülüdür. |
| `fixed` | modül export'u | `FixedWidth` trait'inin kaynak modülüdür. |
| `styled_ext` | modül export'u | `StyledExt` trait'inin kaynak modülüdür. |
| `styled_ext_reflection` | inspector/debug reflection modülü | `StyledExt` yardımcılarını inspector yansıma katmanına görünür kılan debug amaçlı modüldür; üretim UI kodunun doğrudan import ettiği bir yüzey değildir. |
| `toggleable` | modül export'u | `Toggleable` trait'inin kaynak modülüdür. |
| `visible_on_hover` | modül export'u | `VisibleOnHover` trait'inin kaynak modülüdür. |
| `animation_ext` | modül export'u | `CommonAnimationExt` ve animasyon yardımcı extension yüzeyinin kaynak modülüdür. |

Bu trait'ler normal şartlarda doğrudan düşünülmek zorunda değildir. Sadece hazır bir `Button`, `ListItem` veya `DropdownMenu` kuruluyorsa, bileşenin kendi içindeki builder listesi yeterli olur. Ortak trait ayrımına ancak aynı davranışı birden fazla bileşen ailesinde tutarlı bir biçimde uygularken veya özel bir bileşen geliştirirken ihtiyaç duyulur.

## Platform stili (`PlatformStyle`)

`ui` crate'i içindeki `PlatformStyle`, işletim sistemine bağlı render kararlarını tek bir noktada toplamak için kullanılır. `cfg!` makrolarını veya platform tespit mantığını her bileşene ayrı ayrı dağıtmak yerine, platforma göre değişen davranışlar bu enum üzerinden tanımlanır.

- Değerler: `Mac`, `Linux`, `Windows`.
- Mevcut platform bilgisi için `PlatformStyle::platform()` (const fn) çağrısı yapılır.
- `KeyBinding::platform_style(...)`, modifier tuşunu ikon olarak mı yoksa metin olarak mı göstereceğini bu enum'a bakarak seçer.

Platforma özel bir davranış kurarken `cfg!` makrolarını her yerde tekrar etmek yerine, `PlatformStyle::platform()` dönüş değerini tek bir noktada saklanması önerilir. Bu yaklaşım testlerde bu değeri override etmeyi de kolaylaştırır.

## Tipografi yardımcıları (`StyledTypography`, `TextSize`)

`ui` crate'i, `Headline` ve `Label` dışında düz `div()` öğeleri üzerine de temayla uyumlu tipografi uygulamak için `StyledTypography` trait'ini sunar. `Styled` implement eden her tip otomatik olarak bu trait'i de devralır; ayrıca bir derive veya impl yazılması gerekmez.

Sık kullanılan yöntemler şu şekildedir:

- `.font_ui(cx)` ve `.font_buffer(cx)`: tema UI fontunu veya buffer (editor) fontunu uygular.
- `.text_ui_lg(cx)`, `.text_ui(cx)`, `.text_ui_sm(cx)`, `.text_ui_xs(cx)`: sırasıyla `Large`, `Default`, `Small`, `XSmall` boyutlarını seçer.
- `.text_buffer(cx)`: kullanıcının buffer font size'ını uygular; yani editor yazısı ne büyüklükte ise metin juga o büyüklükte basılır.
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

`Label` ve `Headline` zaten doğru tipografiyi uygular; dolayısıyla ek bir çağrıya gerek yoktur. Ancak `div()` veya `h_flex()` gibi temel yapı taşlarına doğrudan metin yazıldığında `font_ui` and `text_ui_*` çağrılarının atlanmaması gerekir. Aksi halde font ailesi sistem varsayılanlarından devralınır, tema değişiklikleri arayüze yansımaz ve metin temanın geri kalanından kopuk görünmeye başlar.

Viewport birimleri için `vw(percent)` ve `vh(percent)` yardımcıları tanımlıdır. Bunlar GPUI uzunluk (length) değerini viewport genişliği veya yüksekliği üzerinden dinamik olarak üretir. Genellikle tam ekran kaplamalar (overlay), önizleme alanları (canvas) veya modal sunucuları (host) gibi ekran oranına bağlı yüzeylerde tercih edilir. Sıradan satır, buton, etiket veya panel aralıkları için `vw`/`vh` kullanımı tercih edilmez; bu alanlarda `DynamicSpacing`, `rems_from_px(...)`, `px(...)` veya bileşene özgü boyut token'ları çok daha öngörülebilir sonuçlar sunar.

## Animasyon yardımcıları

`ui` crate'i, küçük UI animasyonlarını standart süreler ve yönlerle kurmak için bir trait sağlar. Amaç, her yerde ayrı ayrı animasyon parametresi yazmak yerine ortak ve tutarlı bir sözlük kullanmaktır.

- `AnimationDuration`: `Instant` (50ms), `Fast` (150ms), `Slow` (300ms).
- `AnimationDirection`: `FromBottom`, `FromLeft`, `FromRight`, `FromTop`.
- `DefaultAnimations` trait yöntemleri: `.animate_in(direction, fade_in)`, `.animate_in_from_bottom(fade)`, `.animate_in_from_top(fade)`, `.animate_in_from_left(fade)`, `.animate_in_from_right(fade)` şeklindedir.

`DefaultAnimations`, `Styled + Element` implement eden her tipe otomatik olarak bağlanır; bu nedenle ek bir import yapılması gerekmez. Daha karmaşık animasyon senaryolarında ise GPUI'nin `Animation`, `AnimationExt`, `with_animation(...)` and `with_animations(...)` yapıları doğrudan kullanılabilir. `LoadingLabel`, `SpinnerLabel`, `AiSettingItem` ve `ThreadItem::Running` durumu, bu daha düşük seviyeli yöntemlerle animasyon uygulayan örneklere örnek gösterilebilir.

`ui::CommonAnimationExt` prelude kapsamına dahil değildir, ancak crate kökünden export edilir. `use ui::CommonAnimationExt as _;` şeklinde import edildiğinde, `Transformable` implement eden bileşenlere `.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id, duration)` yardımcı metotları eklenir. Bir liste içinde ya da tekrarlı bir öğe (item) içinde aynı animasyon birden fazla kez render edilecekse, anahtarlı (keyed) varyantın seçilmesi önerilir. Varsayılan varyant, çağrı yerini (call site) element ID olarak aldığı için aynı sahnede tekrarlandığında çakışma yaşanabilir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `AnimationDuration` | `Instant`, `Fast`, `Slow` | Standart UI animasyon sürelerini taşır. |
| `AnimationDirection` | `FromBottom`, `FromLeft`, `FromRight`, `FromTop` | Giriş animasyonunun hangi yönden başlayacağını belirler. |
| `DefaultAnimations` | `animate_in`, `animate_in_from_bottom`, `animate_in_from_top`, `animate_in_from_left`, `animate_in_from_right` | Styled elementlere standart giriş animasyonları ekler. |

## `CommonAnimationExt` ve transform kısıtı

`ui` crate'i içindeki `Transformable`, kaynak kodda `pub trait` olarak yer alır; fakat `ui` tarafından crate köküne re-export edilmez ve `ui::prelude::*` içinde bulunmaz. Bu nedenle geliştirici kodu için doğrudan çağrılacak metot `.transform(...)` değildir; bu metodu doğrudan çağırmaya çalışmak, derleme aşamasında trait'in import edilememesi hatasıyla sonuçlanır.

Pratik kullanımda geliştirici tarafına açılan arayüz `ui::CommonAnimationExt` üzerinden sağlanır:

```rust
use ui::{CommonAnimationExt as _, prelude::*};

fn render_loading_icon() -> impl IntoElement {
    Icon::new(IconName::LoadCircle)
        .size(IconSize::Small)
        .with_rotate_animation(2)
}
```

`Icon` ve `Vector` yapıları arka planda `Transformable` implement eder; bu kısıt (bound) sayesinde `.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id, duration)` çağrıları çalışır. Mevcut Zed API yüzeyinde geliştiriciye sunulan arayüz `ui::CommonAnimationExt` üzerinden sağlanır; `.transform(...)` metodunu ise doğrudan genel bir kullanım yöntemi olarak ele almamak gerekir.

## `ui::utils` modülü

`ui` crate'i genel kullanıma açık bir alt modüldür; `is_light`, `reveal_in_file_manager_label` ve `capitalize` doğrudan bu düzeyde yer alır, diğer yardımcı araçlar ise `ui::utils::*` alt modülü altından re-export edilir. Bu yardımcılar `ui` crate kökünden ayrıca dışa aktarılmaz; doğru erişim yolları `ui::utils::is_light`, `ui::utils::WithRemSize`, `ui::utils::FormatDistance` gibi alt modül yollarıdır. Buna karşın `BASE_REM_SIZE_IN_PX`, `EDITOR_SCROLLBAR_WIDTH`, `theme_is_transparent` ve `ui_density` ise styles/components dışa aktarım zinciri üzerinden doğrudan `ui::...` kökünden erişilebilir durumdadır; bu fark, sembolün hangi modülde tanımlandığına göre şekillenir.

Temalama ve görsel:

- `is_light(cx: &mut App) -> bool`: etkin temanın açık mı koyu mu olduğunu belirtir. Özel tuval (canvas) çizimlerinde uygun bir kaplama (overlay) rengi seçmek için oldukça kullanışlıdır.
- `theme_is_transparent(cx)` (styles modülünde): transparent veya blurred pencere arka planı için aynı işi yapar; arka plan davranışına bakar.

İçerik ve etiket yardımcıları:

- `capitalize(str: &str) -> String`: ilk karakteri büyük harfe çevirip yeni bir `String` döndürür. Yerel ayar duyarlı değildir; hızlıca bir UI etiketini normalize etmek için tasarlanmıştır.
- `reveal_in_file_manager_label(is_remote: bool) -> &'static str`: macOS işletim sisteminde `"Reveal in Finder"`, Windows'ta `"Reveal in File Explorer"`, diğer platformlarda ise `"Reveal in File Manager"` etiketini döndürür. `is_remote` değeri true ise uzak dosyalarda yerel platform dosya yöneticisi anlamlı olamayacağı için her durumda genel etiket döndürülür.

| Helper | Tür | Kısa anlamı |
| :-- | :-- | :-- |
| `apca_contrast` | fonksiyon | Metin ve arka plan rengi için APCA Lc kontrastını hesaplar. |
| `calculate_contrast_ratio` | fonksiyon | WCAG 2 kontrast oranını hesaplar. |
| `ensure_minimum_contrast` | fonksiyon | Foreground rengin lightness değerini APCA eşiğini sağlayacak şekilde ayarlar. |
| `capitalize` | fonksiyon | İlk karakteri büyük harfe çevirir. |
| `reveal_in_file_manager_label` | fonksiyon | Platforma uygun dosya yöneticisinde gösterme etiketini döndürür. |
| `format_distance` | fonksiyon | İki tarih arasını insan okunur süre metnine çevirir. |
| `format_distance_from_now` | fonksiyon | Verilen zamanı `Local::now()` ile karşılaştırarak süre metni üretir. |
| `theme_is_transparent` | fonksiyon | Etkin pencere arka planı transparent/blurred mı diye bakar. |
| `vh` | fonksiyon | Viewport yüksekliğine göre `Length` üretir. |
| `vw` | fonksiyon | Viewport genişliğine göre `Length` üretir. |

Layout ve ölçü yardımcıları:

- `BASE_REM_SIZE_IN_PX: f32 = 16.0` (`styles/units`): rem tabanlı hesaplamalarda referans değer olarak kullanılır.
- `EDITOR_SCROLLBAR_WIDTH: Pixels` (`components/scrollbar`): `ScrollbarStyle::Editor.to_pixels()` sabitidir. Editor görseliyle gelen scrollbar genişliğini diğer panellerle hizalamak gerektiğinde başvurulan değerdir.
- `TRAFFIC_LIGHT_PADDING: f32`: macOS pencere kontrolleri (kapat, küçült, büyüt) için title bar'da ayrılması gereken sol padding boşluğunu ifade eder. SDK 26 öncesi 71px, sonrası 78px sabit değer alır.
- `platform_title_bar_height(window: &Window) -> Pixels`: Windows'ta sabit 32px, diğer platformlarda `1.75 * window.rem_size()` (minimum 34px) döndürür.
- `inner_corner_radius(parent_radius, parent_border, parent_padding, self_border) -> Pixels`: iç içe geçmiş yuvarlatılmış köşelerde alt (child) elemanın köşe yarıçapını (radius) hesaplar; dış elemanın yarıçapına göre iç köşenin görsel olarak doğru konumlanmasını sağlar.
- `CornerSolver::new(root_radius, root_border, root_padding)` ve `.add_child(border, padding).corner_radius(level)`: çok seviyeli iç içe yerleşimlerde (nesting) aynı geometrik problemin toplu çözümünü sunar. Tek bir elemanın değil, tüm hiyerarşik zincirin tek seferde hesaplanması gerektiğinde tercih edilir.
- `SearchInputWidth::THRESHOLD_WIDTH` / `MAX_WIDTH` (her ikisi de 1200px) ve `SearchInputWidth::calc_width(container_width)`: arama input'unun kapsayıcı genişliğine göre nasıl yayılacağı veya nerede sınırlanacağıyla ilgilenir.
- `WithRemSize::new(rem_size)`: alt ağaca farklı bir rem boyutunu zorla uygulayan bir elementtir. Kendi ölçeklemesini yöneten ayarlar önizlemesi (settings preview) benzeri alanlarda tercih edilir. `.occlude()` ile işaretçi olaylarının (pointer events) elemana ulaşması da engellenebilir.

Tasarım ve renk kontrastı:

- `calculate_contrast_ratio(fg: Hsla, bg: Hsla) -> f32`: WCAG 2 standardına göre kontrast oranını hesaplar.
- `apca_contrast(text_color: Hsla, background_color: Hsla) -> f32`: APCA Lc (lightness contrast) ölçeğini döndürür. Pozitif değer normal polarity (koyu metin, açık arka plan), negatif değer ters polarity anlamına gelir. Tipik eşikler: `Lc 45` büyük ve akıcı metin (36px ve üstü) için minimum, `Lc 60` diğer içerik metni için minimum, `Lc 75` gövde metni için minimum, `Lc 90` ise gövde metni için tercih edilen değerdir.
- `ensure_minimum_contrast(foreground: Hsla, background: Hsla, minimum_apca_contrast: f32) -> Hsla`: foreground rengin lightness değerini ayarlayarak verilen APCA eşiğini sağlayan en yakın rengi döndürür. Tema türetimi sırasında hesaplanan renklerin okunabilir kalmasını garantilemek için en uygun yoldur.

Tarih farkı yardımcıları (`format_distance` modülü):

- `DateTimeType::Naive(NaiveDateTime)` veya `DateTimeType::Local(DateTime<Local>)` iki olası kaynağı temsil eder. `.to_naive()` her ikisini de `NaiveDateTime`'a çevirir.
- `format_distance(date, base_date, include_seconds, add_suffix, hide_prefix) -> String`: iki tarih arasındaki mesafeyi "less than a minute ago", "about 2 hours ago", "3 months from now" gibi insan okuyabilir bir metne çevirir.
- `format_distance_from_now(datetime, include_seconds, add_suffix, hide_prefix) -> String`: benzer işlemi gerçekleştirir, fakat `base_date` parametresi olarak otomatik olarak `Local::now()` değerini temel alır.
- `FormatDistance::new(date, base_date).include_seconds(...).add_suffix(...).hide_prefix(...)`: builder arayüzüdür; genellikle iş parçacığı öğeleri (thread items), git commit kayıtları ve aktivite akışları (activity feed) gibi yerlerde tercih edilir. Yeni kod yazılırken Zed çalışma ağacı referans alınarak aynı tarih formatlama yardımcılarının tutarlı bir biçimde kullanılması önerilir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `CornerSolver` | `new`, `add_child`, `corner_radius` | İç içe geçmiş border/padding zincirlerde doğru child corner radius değerini hesaplar. |
| `SearchInputWidth` | `THRESHOLD_WIDTH`, `MAX_WIDTH`, `calc_width` | Arama input genişliğini kapsayıcı genişliğine göre sınırlar. |
| `WithRemSize` | `new`, `occlude` | Alt ağaç için özel rem boyutu ve pointer occlusion davranışı uygular. |
| `DateTimeType` | `Naive`, `Local`, `to_naive` | Tarih kaynağını local veya naive biçimde normalize eder. |
| `FormatDistance` | `new`, `from_now`, `include_seconds`, `add_suffix`, `hide_prefix`, `Display` | İnsan okunur tarih mesafesi metnini builder olarak üretir. |

## Crate kökü ve prelude hızlı kapsamı

Bu tablo, `ui` ve `ui_input` crate'lerinde başka konu dosyalarında kullanılan ama bileşenler bölümünün beklenen sahiplik alanında kısa anchor isteyen public yüzeyi toplar:

| API | Kısa anlamı |
| :-- | :-- |
| `component::init`, `component_preview::init` | Bileşen ve bileşen önizleme crate'lerinin GPUI uygulama başlangıcında çağrılan kayıt/kurulum girişleridir. |
| `prelude`, `ui`, `styles` | `ui` crate'inin ergonomik import, crate kökü ve style re-export kapılarıdır. |
| `App`, `Context`, `Window`, `AnyElement`, `Element`, `RenderOnce`, `Styled`, `ElementId` | GPUI'den `ui::prelude` üzerinden gelen temel render/context tipleridir. |
| `AbsoluteLength`, `DefiniteLength`, `Pixels`, `Rems`, `SharedString`, `Color`, `ActiveTheme` | UI bileşenlerinin ölçü, metin, renk ve tema erişiminde kullandığı prelude tipleridir. |
| `KnockoutIconName`, `VectorName` | Icon decoration ve raster/vector image seçiminde kullanılan public isim taşıyıcılarıdır. |
| `h_group_sm`, `h_group_lg`, `h_group_xl`, `indent_guides` | Grup layout ve indent guide factory yardımcılarıdır. |
| `inner_corner_radius`, `is_light`, `platform_title_bar_height`, `ui_density` | Corner, tema aydınlık/koyuluk, titlebar yüksekliği ve density okuma yardımcılarıdır. |
| `find_method`, `methods` | `StyledExt` reflection metadata'sında kullanılan method listeleme yardımcılarıdır; uygulama akışında doğrudan çağrı yüzeyi değildir. |
| `input_field`, `InputFieldStyle` | `ui_input` crate'inin input field modülü ve stil taşıyıcısıdır; form bileşenleri bu yüzeyi sarmalar. |

## Hata yönetimi

UI olay işleyicilerinden veya asenkron görevlerden (async tasks) dönen `Result` değerlerinin sessizce yok sayılmaması gerekir. Bir hata oluştuğunda kullanıcının gerektiğinde bunu görebilmesi, geliştiricinin loglarda iz sürebilmesi ve view durumunun tutarlı kalması büyük önem taşır. Bu nedenle, aynı prensibin tüm kod tabanında uygulanması gerekir:

- Çağıran fonksiyon `Result` taşıyabiliyorsa hatayı `?` ile yaymak en doğal yoldur.
- View içinde arka planda çalışıp sonucu beklenmeyen (fire-and-forget) bir görev yürütüldüğünde, oluşan hataların log kayıtlarına yazılması için `task.detach_and_log_err(cx)` metodu tercih edilmelidir. Buna karşılık düz `task.detach()` çağrısı hatayı sessizce yutar ve hatanın nedenini sonradan tespit etmeyi imkansız hale getirir.
- Asenkron işlemin tamamlanmasının ardından view durumunun güncellenmesi gerekiyorsa, ilgili görevi view struct'ı içinde `Task<anyhow::Result<()>>` alanı olarak saklamak ve görev gövdesinde `this.update(cx, ...)?` çağrısı ile entity bağlamına geri dönmek uygun bir tasarım kalıbıdır. Bu yaklaşım, [Entegre Örnek Sayfaları](16-entegre-ornek-sayfalari.md) altındaki "Ayarlar Paneli Satırı" örneğinde de görülebilir.
- Tek seferlik bir asenkron işlemin sonucu kullanıcıya gösterilecekse, olası hata durumunu `last_error: Option<SharedString>` benzeri bir durum alanına yazıp `Callout` veya `Banner` bileşenleri yardımıyla sunmak tercih edilir. Görsel durum değiştiği için ayrıca `cx.notify()` çağrısı yapılması gerekir; aksi takdirde durum güncellense bile ekran yenilenmeyecektir.
- Panik üreten kestirme yöntemler ve `let _ = ...?` kalıbı yerine açık desen eşleme (match veya if let) yapılması önerilir. `let _ = ...` kullanımı, üretim kodunda yalnızca hatanın bilinçli olarak yoksayıldığı nadir durumlarda kabul edilebilir; bu gibi durumlarda da gerekçenin bir yorum satırıyla açıklanması gerekir.

`anyhow::Result` ve `anyhow::Context` yapıları, Zed crate'leri içerisinde standart hale gelmiştir. `?` operatörü ile bir hata yukarı yayılırken hata mesajına `.with_context(|| ...)` eklendiğinde, log kayıtlarında hatanın asıl kaynağı çok daha anlaşılır bir biçimde görüntülenecektir.
