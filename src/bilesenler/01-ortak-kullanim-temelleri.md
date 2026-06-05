# 1. Ortak Kullanım Temelleri

Zed UI bileşenleri, GPUI element modelinin üstüne kurulan daha dar ve daha tutarlı bir tasarım sistemi katmanıdır. Altta GPUI'nin temel parçaları durur: `div()`, `Render`, `RenderOnce`, `IntoElement`, `Styled`, `ParentElement` ve olay işleyicileri. Zed'in `ui` crate'i ise bu temeli gündelik ekran kodunda daha kolay kullanılacak hale getirir. `Button`, `Label`, `Icon`, `Color`, `Severity`, `ButtonStyle` ve `ToggleState` gibi tipler bu üst katmanın parçasıdır. Bu tipler yalnızca kısa isimler değildir; renk, boyut, odak, aralık ve görsel tutarlılık için ortak bir dil sağlar.

## Import düzeni

Zed içinde yeni UI kodu yazarken çoğu dosyaya tek bir import ile başlarsın:

```rust
use ui::prelude::*;
```

`ui::prelude::*`, `gpui::prelude::*` içeriğini de getirir ve üstüne Zed tasarım sisteminde sık kullanılan tipleri ekler. Bu yüzden sıradan bir view veya küçük bileşen örneğinde `Button`, `Icon`, `Label`, `Color`, `h_flex`, `v_flex`, `Context`, `Window`, `App`, `SharedString`, `AnyElement` ve `RenderOnce` için ayrı ayrı `use` satırı yazmana gerek kalmaz. Bunlar prelude üzerinden hazır gelir.

Prelude her şeyi getirmez. Daha özel kalan bileşenler için açık import gerekir:

```rust
use ui::prelude::*;
use ui::{Callout, ContextMenu, DropdownMenu, List, ListItem, Tooltip};
```

`gpui::prelude::*` yalnızca ham GPUI primitive'leriyle çalışırken yeterli olur. Zed UI bileşenlerini kullanacaksan tercih ettiğin yol `ui::prelude::*` olmalıdır. Aksi halde tasarım token'ları ve ortak bileşen trait'leri eksik kalır; bazı builder metotları görünmez.

## Prelude ve Bileşen Önizleme Import Sınırı

`ui::prelude::*`, çalışma zamanı UI yazarken kullandığın kısa yoldur. `ActiveTheme`, `DynamicSpacing`, `RegisterComponent`, `Button`, `Icon`, `Label`, `Color`, `Severity`, `ToggleState`, ortak trait'ler ve sık kullanılan GPUI tiplerini aynı import altında toplar. Bu yüzden normal uygulama ekranında önce `use ui::prelude::*;` yazılır, sonra yalnız özel bileşenler için ek import yapılır.

`ui::component_prelude::*` ise çalışma zamanı ekran kodu için değil, bileşen önizleme veya bileşen galerisi kaydı yazarken kullanılır. Bu prelude `Component`, `ComponentId`, `ComponentScope`, `ComponentStatus`, `RegisterComponent`, `Documented`, `single_example`, `example_group` ve `example_group_with_title` gibi önizleme sistemine ait yardımcıları getirir. Üretim UI'da bir butonu render etmek için `component_prelude` gerekmez; önizleme yazarken ise `RegisterComponent` derive'ı ve `Documented` derive'ı aynı dosyada kısa importla kullanılabilir.

`ui::prelude` ve `ui::component_prelude` ikisini aynı dosyada karıştırmadan önce dosyanın rolünü netleştirmen gerekir. Dosya gerçek bir Zed ekranı render ediyorsa `ui::prelude::*` yeterlidir. Dosya yalnız önizleme kaydına örnek ekliyorsa `ui::component_prelude::*` eklenir. Aksi halde bileşen registry API'leri, çalışma zamanı UI bağımlılığıymış gibi görünür ve okuyucu için yanlış bir model oluşur.

| Prelude | İçerik | Kullanım yeri |
| :-- | :-- | :-- |
| `component_prelude` | `Component`, `ComponentId`, `ComponentScope`, `ComponentStatus`, `RegisterComponent`, `Documented`, `single_example`, `example_group`, `example_group_with_title` | Bileşen önizleme/galeri kaydı yazarken. |
| `single_example` | tek `ComponentExample` üretir | Tek varyantlı önizleme slotu. |
| `example_group` | başlıksız `ComponentExampleGroup` üretir | Birden fazla önizleme örneğini aynı blokta toplar. |
| `example_group_with_title` | başlıklı `ComponentExampleGroup` üretir | Varyantları başlıklı bir grup altında gösterir. |

## Render modeli

Zed UI bileşenlerinin büyük kısmı `RenderOnce` implement eder. Bu model, kendi içinde durum taşımayan ve builder zinciriyle kurulan küçük UI parçaları için uygundur. Bileşen o render sırasında üretilir, ekrana çizilir ve işi biter; bir sonraki render'a sakladığı ayrı bir durum yoktur:

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

View durumu tutan ekran parçalarında ise `Render` kullanırsın. Bu durumda view, kendi alanlarında durum bilgisi saklar ve kullanıcı etkileşimine göre bu bilgi değişir. Etkileşim view durumunu değiştirdiyse, ekrana çizilen çıktının da yenilenmesi için `cx.notify()` çağırman gerekir. Bu çağrı eksik kaldığında durum değişmiş olur, fakat kullanıcı aynı eski render sonucunu görmeye devam eder:

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

`ElementId`, bileşen durumu ve hitbox takibi için kullanılan sabit kimliktir. Button, tab, list item, table row ve toggle gibi etkileşimli bileşenlere anlamlı ve birbiriyle çakışmayan bir id vermen beklenir. Aksi halde GPUI hangi elementin hangi durumu taşıdığını ayırt etmekte zorlanır.

`SharedString`, UI metinleri için tercih ettiğin string tipidir. `&'static str`, `String` veya `Arc<str>` kaynaklı metinleri, gereksiz bir kopya üretmeden elementlere taşımana yarar. Render sırasında her metnin tekrar tekrar kopyalanması yerine paylaşılan bir referans üzerinden hareket edersin.

`AnyElement`, farklı somut element tiplerini tek bir slotta tutman gerektiğinde kullanırsın. Örneğin bir list item'in başlangıç slotu bazen `Icon`, bazen özel bir `div()` olabilir. Bu çeşitliliği `AnyElement` ile aynı tipin arkasında toplarsın. Buna karşılık public builder API'si generic bir `impl IntoElement` kabul ediyorsa, çağıran tarafın özellikle `AnyElement` üretmesine gerek yoktur; dönüşüm zaten builder tarafından yapılır.

`AnyView`, entity tabanlı ve dinamik view döndüren tooltip, popover veya önizleme gibi API'lerde sık kullanacağın bir tiptir. Bir view'in yaşam döngüsü GPUI entity sistemi tarafından yönetiliyorsa, elementten daha uygun olan yüzey `AnyView`'dir; çünkü entity yaşam döngüsü ile element yaşam döngüsü farklı çalışır.

`Entity<ContextMenu>`, `DropdownMenu` ve menü tabanlı popup'larda sıkça görürsün. Menü içeriği odak, odak kaybı ve action dispatch davranışı taşıdığı için düz bir `AnyElement` yerine entity olarak tutulur; bu sayede menüye dair durumlar bir frame'den diğerine korunur:

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

`Color`, tema bağımsız metin ve ikon rengi seçmek için kullandığın ana semantik token'dır. `Color::Default`, `Muted`, `Hidden`, `Disabled`, `Placeholder`, `Accent`, `Info`, `Success`, `Warning`, `Error`, `Hint`, `Created`, `Modified`, `Deleted`, `Conflict`, `Ignored`, `Debugger`, `Player(u32)`, `Selected` ve version-control renkleri etkin temadan gerçek HSLA değerine çevrilir. Kod "uyarı rengi istiyorum" der; o uyarının açık temada mı koyu temada mı nasıl görüneceğine tema karar verir.

Version control variant'ları açık adlarıyla `VersionControlAdded`, `VersionControlModified`, `VersionControlDeleted`, `VersionControlConflict` ve `VersionControlIgnored` olarak gelir. Diff veya file status UI'larında genel `Created`/`Modified` yerine bu açık adları tercih edersin; bu sayede diff yüzeyleri tema değişikliklerinde tutarlı kalır.

Özel HSLA gerektiğinde `Color::Custom`'ı kullanabilirsin. Yine de tutarlılık için önce semantik renkleri düşünmen gerekir; özel renge geçmek istisna kabul edilir. `Color` ayrıca `Component` önizlemesi olan bir tasarım token'ıdır. Bu sayede bileşen galerisi içinde tema renklerini yan yana karşılaştırabilirsin.

`Severity`, mesaj ve feedback bileşenlerinde durum seviyesini ifade eder: `Info`, `Success`, `Warning`, `Error`. `Banner` ve `Callout` gibi bileşenler bu seviyeyi arka plan, ikon ve vurgu rengine otomatik olarak bağlar; aynı "warning" seviyesi her yerde aynı görsel dile çevrilir.

`IconName`, `icons` crate'inde tanımlanan gömülü ikon adıdır ve `Icon::new(IconName::Check)` şeklinde kullanırsın. Harici bir ikon teması veya kendi SVG'i kullanman gereken durumlar için `Icon::from_path(...)` ve `Icon::from_external_svg(...)` yardımcıları mevcuttur.

Boyut token'larını bileşen ailesine göre seçersin:

- Metin için `LabelSize`, başlık için `HeadlineSize`'ı kullanırsın.
- İkon için `IconSize` vardır.
- Buton için `ButtonSize` ölçeği geçerlidir.
- Progress veya özel çizim yüzeylerinde, gerektiğinde `Pixels` veya `Rems`'i doğrudan kullanabilirsin.

Buton görünümü için `ButtonStyle`'ı kullanırsın. `Subtle` varsayılan seçimdir ve sade buton ihtiyaçlarının çoğunu karşılar. `Filled` daha güçlü vurgu gerektiren yerlerde, `Tinted(TintColor::...)` semantik durumlarda (örneğin uyarı veya başarı), `Outlined` ve `OutlinedGhost` ise ikincil eylemler için uygundur.

Toggle durumunu `ToggleState` ile ifade edersin. `bool` doğrudan `ToggleState`'e dönüşebilir; üç durumlu seçim gerektiğinde `ToggleState::Indeterminate` veya `ToggleState::from_any_and_all(any_checked, all_checked)`'ı kullanırsın. İkinci fonksiyon, "alt öğelerin bir kısmı seçili" gibi karışık durumları otomatik olarak doğru duruma çevirir.

Transparent veya blurred tema kullanan pencere yüzeylerinde arka plan davranışını ayırmak için `ui::theme_is_transparent(cx)` yardımcı fonksiyonu bulunur. Etkin `WindowBackgroundAppearance` değeri `Transparent` veya `Blurred` ise `true` döner ve özel yüzeylerde opak bir yedek gerekip gerekmediğine bu değere göre karar verirsin.

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
| `EDITOR_SCROLLBAR_WIDTH` | `ScrollbarStyle::Editor.to_pixels()` | Editor scrollbar genişliğini panel ve tablo yüzeyleriyle hizalamak için kullanılır. |
| `TRAFFIC_LIGHT_PADDING` | macOS SDK sürümüne göre `71.0` veya `78.0` | macOS pencere kontrol butonları için ayrılacak sol titlebar boşluğudur. |
| `theme_is_transparent` | `cx` üzerinden pencere arka plan görünümünü okur | Transparent/blurred pencere yüzeylerinde opak yedek gerekip gerekmediğini söyler. |

## Spacing token'ları (`DynamicSpacing`)

Padding, margin ve gap değerleri için her yerde elle `px(...)` veya `rems(...)` yazmak yerine, `ui` crate'inde tanımlı `DynamicSpacing` ölçeğini tercih etmen daha doğru olur. Bu enum, kullanıcının UI yoğunluk ayarına (`Compact`, `Default`, `Comfortable`) göre tek noktadan ölçek değiştirir. Uygulama yoğunluğu değiştiğinde aralık değerleri de aynı kurala bağlı olarak uyum sağlar.

- Adlandırma: `Base00`, `Base01`, `Base02`, `Base03`, `Base04`, `Base06`, `Base08`, `Base12`, `Base16`, `Base20`, `Base24`, `Base32`, `Base40`, `Base48`. `BaseXX` içindeki `XX`, varsayılan yoğunluktaki yaklaşık pixel değeridir (`Base04 ≈ 4px`, `Base16 ≈ 16px`).
- Kullanım: `.gap(DynamicSpacing::Base02.px(cx))` veya `.p(DynamicSpacing::Base06.rems(cx))` şeklindedir.
- Üç değer manuel verdiğinde (örneğin `(1, 1, 2)`) yoğunluğa göre değişir; tek değer verdiğinde ise `(n-4, n, n+4)` formülü otomatik uygulanır.
- Mevcut UI yoğunluğunu `ui::ui_density(cx)` ile sorgulayabilirsin. Bu dönen değeri yalnızca görsel kararlar için kullanırsın; doğrudan aralık hesabı yapmak için değil, çünkü asıl ölçek `DynamicSpacing` üzerinden zaten yönetilir.

Spacing macro yüzeyi:

| API | Rol |
| :-- | :-- |
| `derive_dynamic_spacing` | Spacing enum'larının yoğunluk varyantlarına göre `px(cx)` ve `rems(cx)` gibi yardımcılarını üretir; normal bileşen kodunda doğrudan çağırmazsın. |

Sabit ve değişmeyen bir aralık gerektiğinde `gap_0p5`, `gap_1`, `gap_1p5`, `gap_2` gibi GPUI yardımcıları yeterlidir. Bu sabitler aynı zamanda `h_group*` ve `v_group*` yardımcılarının arkasında da kullanılır.

## Yükseklik / elevation token'ları (`ElevationIndex`)

`ui` crate'indeki `ElevationIndex`, bir yüzeyin görsel "z-axis" konumunu anlatır. Doğru elevation seçtiğinde shadow, background ve border kombinasyonu birlikte gelir. Böylece her popover, modal veya panel için aynı görsel ayrıntıları elden ayarlaman gerekmez.

- `Background`: uygulamanın en alt zemini.
- `Surface`: paneller, pane'ler ve ana yüzey kapsayıcıları.
- `EditorSurface`: editable buffer yüzeyleri; genellikle `Surface` ile aynı renge sahiptir.
- `ElevatedSurface`: popover ve dropdown gibi paneller üstünde yer alan yüzeyler.
- `ModalSurface`: dialog, alert, modal gibi uygulamayı geçici olarak kilitleyen yüzeyler.

Pratik builder'lar `StyledExt` üzerinden gelir:

- `.h_flex()` ve `.v_flex()`: herhangi bir `Styled` elementi yatay/dikey flex kapsayıcıya çevirir. `h_flex` ek olarak `items_center()` da uygular, böylece satır içi içerikler dikeyde otomatik ortalanır.
- `.elevation_1(cx)` ve `.elevation_1_borderless(cx)`: hafif yükseltilmiş bir yüzey için kullanırsın.
- `.elevation_2(cx)` ve `.elevation_2_borderless(cx)`: popover, popovermenu ve tooltip yüzeylerinde geçerlidir.
- `.elevation_3(cx)` ve `.elevation_3_borderless(cx)`: modal ve announcement yüzeyleri için yüksek elevation sağlar.
- `.border_primary(cx)` ve `.border_muted(cx)`: tema `border` ve `border_variant` renklerini doğrudan `border_color(...)` olarak uygular.
- `.debug_bg_red()`, `.debug_bg_green()`, `.debug_bg_blue()`, `.debug_bg_yellow()`, `.debug_bg_cyan()`, `.debug_bg_magenta()`: layout geliştirme sırasında geçici arka plan rengi verir. Bu yardımcıları üretim UI'da bırakmaman gerekir; yalnızca yapı şekillenirken yardımcı olur.

`Popover`, `.elevation_2(cx)` kullanır; `AnnouncementToast` ise `.elevation_3(cx)` ile çalışır. Kendi modal veya dialog yüzeyini elden kurarken aynı yardımcıları çağırman gerekir; aksi halde shadow ve background görsel tutarlılığı kaybeder; aynı dilin parçası gibi de durmaz.

`ElevationIndex` doğrudan renk de döndürebilir. `ElevationIndex::on_elevation_bg(cx)`, o elevation üstünde dolu bir öğenin kullanacağı karşı yüzey rengini verir; `ElevationIndex::darker_bg(cx)` ise mevcut yüzeye göre daha koyu bir arka plan arar, zemin zaten koyuysa daha açık yedeğe döner. Bu iki metodu ancak özel bir bileşen kendi yüzeyini ve içindeki dolu öğeyi elle çiziyorsa kullanırsın; sıradan panel, popover ve modal için `.elevation_*` yardımcıları daha tutarlı sonuç verir.

## Ortak Bileşen Trait'leri

`ui` crate'i altında görülen `clickable`, `disableable`, `fixed`, `styled_ext`, `toggleable`, `transformable`, `visible_on_hover` ve `animation_ext` modülleri, bileşenlerin ortak builder dilini kurar. Çoğu tüketici bu modülleri tek tek import etmez; ilgili trait, kullandığın bileşen veya prelude üzerinden zaten görünür olur. Yine de trait adını bilmek önemlidir, çünkü aynı builder farklı bileşenlerde aynı davranışı temsil eder.

- `Clickable`: `.on_click(...)` ve `.cursor_style(...)` davranışının ortak sözleşmesidir. Buton, disclosure, popover trigger veya özel etkileşimli element aynı tıklama modeline bağlanır.
- `Disableable`: `.disabled(bool)` çağrısının ortak anlamını verir. Devre dışı durum yalnız renk değil, çoğu bileşende işleyici bağlanmaması veya etkileşimin kaldırılması demektir.
- `FixedWidth`: `.width(...)` ve `.full_width()` gibi genişlik kararlarının ortak yüzeyidir. Özellikle `Button`, `ButtonLike`, `IconButton` ve benzeri kontrollere aynı hizalama davranışını uygular.
- `Toggleable`: `.toggle_state(...)` ile seçili veya açık görünümü verir. Bu trait uygulama durumunu değiştirmez; view durumu yine işleyici içinde güncellenir.
- `VisibleOnHover`: parent `.group(name)` ile child `.visible_on_hover(name)` eşleşmesini kurar. Hover action butonlarında doğru group adı verilmezse element beklenen anda görünmez.
- `StyledExt`: `.h_flex()`, `.v_flex()`, `.elevation_*`, `.border_primary(cx)` ve debug background yardımcılarını sağlar. Ham `div()` kodu yerine bu yardımcılar tutarlı aralık ve elevation dilini korur.
- `Transformable`: doğrudan tüketici import'u olarak ele alınmaz; mevcut public kullanım yolu `CommonAnimationExt` üzerinden dönen rotate animation yardımcılarıdır.

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

Bu trait'leri ne zaman doğrudan düşünmezsin? Sadece hazır bir `Button`, `ListItem` veya `DropdownMenu` kuruyorsan bileşenin kendi bölümündeki builder listesi yeterlidir. Ortak trait ayrımına ancak aynı davranışı birden fazla bileşen ailesinde tutarlı uygularken veya özel bileşen yazarken ihtiyaç duyarsın.

## Platform stili (`PlatformStyle`)

`ui` crate'indeki `PlatformStyle`, işletim sistemine bağlı render kararlarını tek bir yerde toplamak için kullanırsın. `cfg!` makrolarını veya platform tespitini her bileşene dağıtmak yerine, platforma göre değişen davranışları bu enum üzerinden ifade edersin.

- Değerler: `Mac`, `Linux`, `Windows`.
- Mevcut platform için `PlatformStyle::platform()` (const fn) çağırırsın.
- `KeyBinding::platform_style(...)`, modifier tuşunu ikon olarak mı yoksa metin olarak mı göstereceğini bu enum'a bakarak seçer.

Platforma özel bir davranış kurarken `cfg!` makrolarını her yerde tekrar etmek yerine, `PlatformStyle::platform()` dönüş değerini tek bir noktada saklaman önerilir. Bu yaklaşım testlerde bu değeri override etmeyi de kolaylaştırır.

## Tipografi yardımcıları (`StyledTypography`, `TextSize`)

`ui` crate'i, `Headline` ve `Label` dışında düz `div()` üzerine de tema tutarlı tipografi uygulamak için `StyledTypography` trait'ini sağlar. `Styled` implement eden her tip otomatik olarak bu trait'i de devralır; ayrıca derive veya impl yazman gerekmez.

Sık kullandığın yöntemler şu şekildedir:

- `.font_ui(cx)` ve `.font_buffer(cx)`: tema UI fontunu veya buffer (editor) fontunu uygular.
- `.text_ui_lg(cx)`, `.text_ui(cx)`, `.text_ui_sm(cx)`, `.text_ui_xs(cx)`: sırasıyla `Large`, `Default`, `Small`, `XSmall` boyutlarını seçer.
- `.text_buffer(cx)`: kullanıcının buffer font size'ını uygular; yani editor yazısı ne büyüklükte ise metin de o büyüklükte basılır.
- `.text_ui_size(TextSize::Editor, cx)` ile serbest seçim de yapabilirsin.

`TextSize` değerleri ve karşılık geldikleri rem değerleri aşağıdaki gibidir (16px = 1rem kabulü altında):

| `TextSize` | rem | px |
| :-- | :-- | :-- |
| `Large` | `rems_from_px(16.)` | `16` |
| `Default` | `rems_from_px(14.)` | `14` |
| `Small` | `rems_from_px(12.)` | `12` |
| `XSmall` | `rems_from_px(10.)` | `10` |
| `Ui` | settings'teki ui_font_size | dinamik |
| `Editor` | settings'teki buffer_font_size | dinamik |

`Label` ve `Headline` zaten doğru tipografiyi uygular; ek bir çağrıya gerek yoktur. Ancak `div()` veya `h_flex()` gibi yapı taşlarına doğrudan metin yazdığında `font_ui` ve `text_ui_*` çağrılarını atlamaman gerekir. Atlarsan font ailesi sistemden devralınır, tema değişiklikleri yansımaz ve metin temanın geri kalanından kopuk görünmeye başlar.

Viewport birimleri için `vw(percent)` ve `vh(percent)` yardımcıları vardır. Bunlar GPUI length değerini viewport genişliği veya yüksekliği üzerinden üretir. Tam ekran overlay, önizleme canvas'ı veya modal host gibi ekran oranına bağlı yüzeylerde kullanırsın. Normal satır, button, label veya panel aralığı için `vw`/`vh` tercih edilmez; bu alanlarda `DynamicSpacing`, `rems_from_px(...)`, `px(...)` veya bileşen boyut token'ları daha öngörülebilirdir.

## Animasyon yardımcıları

`ui` crate'i, küçük UI animasyonlarını standart süreler ve yönlerle kurmak için bir trait sağlar. Amaç, her yerde ayrı ayrı animasyon parametresi yazmak yerine ortak ve tutarlı bir sözlük kullanmaktır.

- `AnimationDuration`: `Instant` (50ms), `Fast` (150ms), `Slow` (300ms).
- `AnimationDirection`: `FromBottom`, `FromLeft`, `FromRight`, `FromTop`.
- `DefaultAnimations` trait yöntemleri: `.animate_in(direction, fade_in)`, `.animate_in_from_bottom(fade)`, `.animate_in_from_top(fade)`, `.animate_in_from_left(fade)`, `.animate_in_from_right(fade)`.

`DefaultAnimations`, `Styled + Element` implement eden her tipe otomatik olarak bağlanır; ekstra import gerekmez. Daha karmaşık animasyonlar gerektiğinde GPUI'nin `Animation`, `AnimationExt`, `with_animation(...)` ve `with_animations(...)` yapılarını doğrudan kullanabilirsin. `LoadingLabel`, `SpinnerLabel`, `AiSettingItem` ve `ThreadItem::Running` durumu bu daha düşük seviyeli yoldan animasyon uygulayan örneklerdir.

`ui::CommonAnimationExt` prelude'a dahil değildir, ancak crate kökünden export edilir. `use ui::CommonAnimationExt as _;` ile import ettiğinde, `Transformable` implement eden bileşenlere `.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id, duration)` yardımcıları eklenir. Bir liste içinde ya da tekrarlı bir item içinde aynı animasyon birden fazla kez render edilecekse keyed varyantı seçmen önerilir. Varsayılan varyant call site konumunu element id olarak aldığı için aynı sahnede tekrar edildiğinde çakışma yaşanabilir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `AnimationDuration` | `Instant`, `Fast`, `Slow` | Standart UI animasyon sürelerini taşır. |
| `AnimationDirection` | `FromBottom`, `FromLeft`, `FromRight`, `FromTop` | Giriş animasyonunun hangi yönden başlayacağını belirler. |
| `DefaultAnimations` | `animate_in`, `animate_in_from_bottom`, `animate_in_from_top`, `animate_in_from_left`, `animate_in_from_right` | Styled elementlere standart giriş animasyonları ekler. |

## `CommonAnimationExt` ve transform kısıtı

`ui` crate'indeki `Transformable`, kaynakta `pub trait` olarak görünür; ancak `ui` tarafından crate köküne re-export edilmez ve `ui::prelude::*` içinde de bulunmaz. Bu yüzden tüketici kodu için sabit çağrı yüzeyi `.transform(...)` değildir; doğrudan bu metodu çağırmaya çalışmak crate sınırında trait'i import edememekle sonuçlanır.

Pratikte kullanabildiğin public yüzey `ui::CommonAnimationExt`'tir:

```rust
use ui::{CommonAnimationExt as _, prelude::*};

fn render_loading_icon() -> impl IntoElement {
    Icon::new(IconName::LoadCircle)
        .size(IconSize::Small)
        .with_rotate_animation(2)
}
```

`Icon` ve `Vector` içeride `Transformable` implement eder; bu bound sayesinde `.with_rotate_animation(duration)` ve `.with_keyed_rotate_animation(id, duration)` çağrıları çalışır. Mevcut Zed API yüzeyinde doğrudan tüketici tarafına açılan çağrı `ui::CommonAnimationExt` üzerinden gelir; `.transform(...)`'ı ise public kullanım yolu olarak ele alman gerekmez.

## `ui::utils` modülü

`ui` crate'i public bir alt modüldür; `is_light`, `reveal_in_file_manager_label` ve `capitalize` doğrudan burada yaşar, geri kalan yardımcılar ise alt modüllerden `ui::utils::*` altında re-export edilir. Bu yardımcılar `ui` crate kökünden ayrıca re-export edilmez; doğru çağrı yolu `ui::utils::is_light`, `ui::utils::WithRemSize`, `ui::utils::FormatDistance` gibi alt modül yoludur. Buna karşılık `BASE_REM_SIZE_IN_PX`, `EDITOR_SCROLLBAR_WIDTH`, `theme_is_transparent` ve `ui_density` ise styles/components re-export zinciri üzerinden doğrudan `ui::...` kökünden erişilebilir; bu fark, sembolün hangi modülde tanımlandığına göre değişir.

Temalama ve görsel:

- `is_light(cx: &mut App) -> bool`: etkin temanın açık mı koyu mu olduğunu söyler. Custom canvas çizimlerinde uygun bir overlay rengi seçmek için kullanışlıdır.
- `theme_is_transparent(cx)` (styles modülünde): transparent veya blurred pencere arka planı için aynı işi yapar; arka plan davranışına bakar.

İçerik ve etiket yardımcıları:

- `capitalize(str: &str) -> String`: ilk karakteri büyük harfe çevirip yeni bir `String` döndürür. Yerel ayar duyarlı değildir; hızlıca bir UI etiketini normalize etmek için tasarlanmıştır.
- `reveal_in_file_manager_label(is_remote: bool) -> &'static str`: macOS'ta `"Reveal in Finder"`, Windows'ta `"Reveal in File Explorer"`, diğer platformlarda `"Reveal in File Manager"` döndürür. `is_remote` true ise her durumda genel etiket döner; çünkü uzak dosyada platform dosya yöneticisi anlamlı değildir.

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
- `EDITOR_SCROLLBAR_WIDTH: Pixels` (`components/scrollbar`): `ScrollbarStyle::Editor.to_pixels()` sabitidir. Editor görseliyle gelen scrollbar genişliğini diğer panelle hizalaman gerektiğinde başvurduğun değerdir.
- `TRAFFIC_LIGHT_PADDING: f32`: macOS pencere kontrolleri (kapat, küçült, büyüt) için title bar'da ayırman gereken sol padding'i ifade eder. SDK 26 öncesi 71px, sonrası 78px sabit değer alır.
- `platform_title_bar_height(window: &Window) -> Pixels`: Windows'ta sabit 32px, diğer platformlarda `1.75 * window.rem_size()` (minimum 34px) döndürür.
- `inner_corner_radius(parent_radius, parent_border, parent_padding, self_border) -> Pixels`: iç içe geçmiş yuvarlatılmış köşelerde child elemanın radius'unu hesaplar; dış elemanın radius'una göre iç köşenin doğru gözükmesini sağlar.
- `CornerSolver::new(root_radius, root_border, root_padding)` ve `.add_child(border, padding).corner_radius(level)`: birden fazla seviyeli nesting için aynı problemin toplu çözümünü verir. Tek elemanın değil, tüm zincirin bir kerede çözülmesi gerektiğinde tercih edersin.
- `SearchInputWidth::THRESHOLD_WIDTH` / `MAX_WIDTH` (her ikisi de 1200px) ve `SearchInputWidth::calc_width(container_width)`: arama input'unun kapsayıcı genişliğine göre nasıl yayılacağı veya nerede sınırlanacağıyla ilgilenir.
- `WithRemSize::new(rem_size)`: alt ağaca farklı bir rem boyutunu zorla uygulayan bir elementtir. Kendi ölçeklemesini yöneten settings preview gibi alanlarda kullanırsın. `.occlude()` ile pointer event'lerinin elemana ulaşmasını da engelleyebilirsin.

Erişilebilirlik ve renk kontrastı:

- `calculate_contrast_ratio(fg: Hsla, bg: Hsla) -> f32`: WCAG 2 standardına göre kontrast oranını hesaplar.
- `apca_contrast(text_color: Hsla, background_color: Hsla) -> f32`: APCA Lc (lightness contrast) ölçeğini döndürür. Pozitif değer normal polarity (koyu metin, açık arka plan), negatif değer ters polarity anlamına gelir. Tipik eşikler: `Lc 45` UI metni için minimum, `Lc 60` küçük metin için, `Lc 75` gövde metni için referans alırsın.
- `ensure_minimum_contrast(foreground: Hsla, background: Hsla, minimum_apca_contrast: f32) -> Hsla`: foreground rengin lightness değerini ayarlayarak verdiğin APCA eşiğini sağlayan en yakın rengi döndürür. Tema türetimi sırasında hesaplanan renklerin okunabilir kalmasını garantilemek için en uygun yoldur.

Tarih farkı yardımcıları (`format_distance` modülü):

- `DateTimeType::Naive(NaiveDateTime)` veya `DateTimeType::Local(DateTime<Local>)` iki olası kaynağı temsil eder. `.to_naive()` her ikisini de `NaiveDateTime`'a çevirir.
- `format_distance(date, base_date, include_seconds, add_suffix, hide_prefix) -> String`: iki tarih arasındaki mesafeyi "less than a minute ago", "about 2 hours ago", "3 months from now" gibi insan okuyabilir bir metne çevirir.
- `format_distance_from_now(datetime, include_seconds, add_suffix, hide_prefix) -> String`: aynı işi yapar, ancak `base_date` olarak otomatik `Local::now()` kullanılır.
- `FormatDistance::new(date, base_date).include_seconds(...).add_suffix(...) .hide_prefix(...)`: builder yüzeyidir; thread item, git commit ve activity feed gibi yerlerde tercih edersin. Yeni kod yazarken mevcut Zed çalışma ağacında kullanılan tarih formatlama yardımcılarıyla aynı çizgide kalman gerekir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `CornerSolver` | `new`, `add_child`, `corner_radius` | İç içe geçmiş border/padding zincirlerinde doğru child corner radius değerini hesaplar. |
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

UI olay işleyicilerinden veya async task'lardan dönen `Result` değerlerini sessizce yok saymaman gerekir. Bir hata oluştuğunda kullanıcının gerekirse bunu görmesi, geliştiricinin loglarda iz sürebilmesi ve view durumunun tutarlı kalması gerekir. Bu yüzden aynı kuralı her yerde izlemen önemlidir:

- Çağıran fonksiyon `Result` taşıyabiliyorsa hatayı `?` ile yayman en doğal yoldur.
- View içinde fire-and-forget bir task çalıştırdığında, hatanın log'a düşürülmesi için `task.detach_and_log_err(cx)`'i tercih edersin. Buna karşılık düz `task.detach()` hatayı sessizce yok eder ve sebebi sonradan tespit etmek mümkün olmaz.
- Async iş bitiminde view durumunun güncellenmesi gerekiyorsa, task'ı view struct'ı içinde `Task<anyhow::Result<()>>` alanı olarak saklaman ve task içinde `this.update(cx, ...)?` çağrısı ile entity'ye geri dönmen uygun bir desendir. Bu yaklaşım [Entegre Örnek Sayfaları](16-entegre-ornek-sayfalari.md)'ndaki "Ayarlar Paneli Satırı" örneğinde uygulanır.
- Tek seferlik bir async sonuç kullanıcıya gösterilecekse, hatayı `last_error: Option<SharedString>` gibi bir durum alanına yazıp `Callout` veya `Banner` ile sunmayı tercih edersin. Görsel durum değiştiği için ayrıca `cx.notify()` çağrısı da gerekir; aksi halde durum güncellense bile ekran yenilenmez.
- Panik üreten kısa yollar ve `let _ = ...?` yerine açık eşleştirme yapman beklenir. `let _ = ...` üretim kodunda yalnızca hatayı bilinçli olarak yok saydığın ender durumlarda kabul edilir; o durumlarda da nedenini yorum satırıyla belirtmen gerekir.

`anyhow::Result` ve `anyhow::Context`, Zed crate'lerinde standart hâle gelmiştir. `?` operatörü ile bir hata yayılırken mesaja `with_context(|| ...)` eklediğinde, log'da hatanın kaynağı çok daha anlaşılır biçimde görünür.
