# 4. Metin ve İkon Bileşenleri

Metin ve ikon bileşenleri Zed UI içinde en sık kullandığın yapı taşlarıdır. Başlık, etiket, arama sonucu, durum satırı, liste öğesi, toolbar veya bildirim gibi sahnelerin çoğu bu parçalarla başlar. Bu yüzden bir ekran kurarken ilk soru çoğu zaman şudur: Bu metin normal bir `Label` mı olmalı, daha güçlü bir `Headline` mı gerektiriyor, yanına hangi `Icon` eşlik etmeli?

Genel tercih sırası şöyle:

- Yapısal bir başlık için `Headline`'ı kullanırsın.
- Normal UI metni için `Label` yeterlidir ve ilk akla gelen seçenektir.
- Hazır label modeli ihtiyacını karşılamıyorsa, sınırlı bir özel metin yüzeyi olarak `LabelLike`'ı tercih edebilirsin.
- Arama veya fuzzy match sonucunda eşleşen karakterleri vurgulamak için `HighlightedLabel` vardır.
- Bir işlem sürerken metinle geri bildirim vermek için `LoadingLabel`'ı kullanırsın.
- Sadece bir yükleme göstergesi gerekiyorsa `SpinnerLabel` daha uygundur.
- Simgeler için `Icon` temel yapı taşıdır; bir simgenin üstünde durum işareti gerektiğinde ise `DecoratedIcon` ve `IconDecoration` ikilisi devreye girer.

## Label

Kaynak:

- Tanım: `ui` crate'i
- Ortak stil yüzeyi: `ui` crate'i
- Export: `ui::Label`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: `impl Component for Label`.

Ne zaman kullanırsın:

- Buton dışındaki kısa UI metinleri, açıklamalar, metadata satırları, durum metinleri ve liste satırı metinleri için.
- Tema ile uyumlu bir renk, boyut, ağırlık ve truncation davranışı gereken hemen her yerde.
- Metin içinde backtick karakterleriyle işaretlenmiş küçük kod parçalarını göstermek için `render_code_spans()` yardımcısı vardır; backtick'le sarılı bölümler otomatik olarak buffer fontuyla ve hafif arka planla vurgulanır.

Ne zaman kullanmazsın:

- Ekran veya bölüm başlığı gerektiğinde `Headline` daha uygun bir yüzeydir; başlıklara ait tipografi davranışını otomatik getirir.
- Metnin bir kısmı arama sonucuna göre vurgulanacaksa `HighlightedLabel`'ı tercih edersin; bu, Label'ın yapamayacağı bir iştir.
- Tamamen özel bir zengin metin veya çok biçimli uzun bir içerik gerekiyorsa, GPUI'nin `StyledText` ailesi veya doğrudan text primitive'leri daha esnektir.

Temel API:

- Constructor: `Label::new(label: impl Into<SharedString>)`.
- Sık builder'lar: `.size(LabelSize::...)`, `.color(Color::...)`, `.weight(FontWeight::...)`, `.line_height_style(...)`, `.italic()`, `.underline()`, `.strikethrough()`, `.alpha(f32)`, `.truncate()`, `.truncate_start()`, `.single_line()`, `.buffer_font(cx)`, `.inline_code(cx)`, `.render_code_spans()`.
- Mutator: `.set_text(text: impl Into<SharedString>)` çağrısı `&mut self` üzerinden label metnini günceller. `Label` örneği view alanında saklanıyorsa, render dışından yeni bir `Label` üretmeden mevcut örneğin metnini değiştirmek için bunu kullanırsın. Bu metodu builder zincirinde değil, daha önce oluşturduğun bir örnek üzerinde çağırırsın.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`, `.flex_shrink()`, `.flex_shrink_0()` ile çeşitli margin style yöntemleri.
- Trait: `LabelCommon`.

Davranış:

- `RenderOnce` implement eder.
- `LabelCommon` ayarlarını arka planda `LabelLike` üzerinden uygular; yani Label görsel olarak `LabelLike`'ın hazır bir şekli gibi düşünülebilir.
- `single_line()` çağrısı, metin içindeki newline karakterlerini tek satırda görünür olacak biçimde dönüştürür; çok satırlı bir metnin satırlara bölünmesini engeller.
- `render_code_spans()` çağrısı, metindeki eşleşen backtick çiftlerini kaldırır ve bu aralıkları buffer fontuyla, element arka plan rengiyle vurgular. Sonuç olarak "`zed --new` çalıştır" gibi bir metinde sadece `zed --new` kısmı kod gibi görünür.

Örnekler:

```rust
use ui::prelude::*;

fn dosya_ust_verisini_render_et(yol: SharedString) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_1()
        .child(Label::new(yol).size(LabelSize::Small).color(Color::Muted).truncate())
        .child(Label::new("değiştirildi").size(LabelSize::Small).color(Color::Warning))
}
```

```rust
use ui::prelude::*;

fn komut_ipucunu_render_et() -> impl IntoElement {
    Label::new("Yeni pencere açmak için `zed --new` çalıştır.")
        .render_code_spans()
        .size(LabelSize::Small)
        .color(Color::Muted)
}
```

Zed içinden kullanım örnekleri:

- `recent_projects` crate'i: proje adı, branch ve path metinlerinde `Label` ve `HighlightedLabel` birlikte kullanılır.
- `remote_connection` crate'i: uyarı ve durum satırlarında `Icon` ve `Label` kompozisyonu geçer.
- `git_ui` crate'i: status, commit ve branch metadata'larında `Label` oldukça yoğun biçimde kullanılır.

Dikkat edeceğin noktalar:

- Uzun bir metni dar bir kapsayıcı içine yerleştirdiğinde `.truncate()` veya `.truncate_start()` çağrısını eklemen gerekir; aksi halde satır taşması layout'u bozabilir.
- `Label::new(format!(...))` pratik bir kısayoldur. Ancak sık render edilen listelerde hazır `SharedString` veya önceden ürettiğin bir metni kullanman, gereksiz bellek ayırmayı azaltır ve render maliyetini düşürür.
- Tüm satırı monospace yapman gerekiyorsa `.buffer_font(cx)` veya `.inline_code(cx)` çağırırsın; yalnızca backtick içindeki bölümleri vurgulaman gerekiyorsa `.render_code_spans()` daha doğru bir seçimdir.

## LabelLike

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::LabelLike`
- Prelude: Hayır; `use ui::LabelLike;` satırını ayrıca eklersin.
- Preview: `impl Component for LabelLike`.

Ne zaman kullanırsın:

- `Label` veya `HighlightedLabel` yeterli olmadığında, ama yine de `LabelCommon`'ın getirdiği renk, boyut, ağırlık ve truncation kurallarını koruman gerektiğinde.
- Birden fazla child element içeren ve yine de bir label gibi davranan küçük satır içi kompozisyonlarda.

Ne zaman kullanmazsın:

- Düz metin için `Label`, arama vurgusu için `HighlightedLabel` daha tutarlı ve daha kısıtlı bir yüzey sunar. Bu kısıtlama çoğu zaman avantajdır; tasarımın gereksiz yere dağılmasını engeller.
- Komple özel bir zengin metin, editor metni veya seçilebilir metin gerekiyorsa GPUI'nin text primitive'leri daha uygun olabilir.

Temel API:

- Constructor: `LabelLike::new()`.
- `LabelCommon`: `.size(...)`, `.color(...)`, `.weight(...)`, `.line_height_style(...)`, `.italic()`, `.underline()`, `.strikethrough()`, `.alpha(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`, `.inline_code(cx)`.
- Ek builder: `.truncate_start()`.
- `ParentElement` implement eder; `.child(...)` ve `.children(...)` kabul eder.
- `LineHeightStyle`: `TextLabel` varsayılan label/buffer line-height davranışını verir; `UiLabel` ise line-height değerini `1` yapan daha kompakt bir UI etiketi davranışını seçer.

Küçük tip yüzeyleri:

| API | Rol |
| :-- | :-- |
| `LabelCommon` | Label ailesinin ortak tipografi builder trait'idir; `size`, `color`, `weight`, `line_height_style`, truncation ve inline code davranışını aynı sözleşmeyle taşır. |
| `LineHeightStyle` | `TextLabel` ile normal label line-height'ını, `UiLabel` ile daha sıkı UI etiketi line-height'ını seçer. |

Davranış:

- `RenderOnce` implement eder.
- `Label` ailesinin kullandığı iç stil yüzeyidir; UI font ağırlığı, semantik `Color` ve `LabelSize` değerlerini aynı şekilde uygular.
- Serbestçe child kabul ettiği için tutarsız bir tipografi üretmek kolaylaşır; bu yüzden kullanımını hazır label'ların yetmediği durumlarla sınırlı tutarsın.

Örnek:

```rust
use ui::prelude::*;
use ui::LabelLike;

fn satir_ici_ipucunu_render_et(eylem: SharedString, cx: &App) -> impl IntoElement {
    LabelLike::new()
        .size(LabelSize::Small)
        .color(Color::Muted)
        .child("Bas: ")
        .child(Label::new(eylem).inline_code(cx))
}
```

## Headline

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Headline`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: `impl Component for Headline`.

Ne zaman kullanırsın:

- Modal başlığı, panel başlığı, onboarding başlığı veya bölüm başlığı gibi, görsel bir hiyerarşi kuran kısa metinler için.

Ne zaman kullanmazsın:

- Satır içi metadata, küçük açıklama veya gövde metni için `Label` daha doğru bir araçtır; Headline o ölçeğe göre fazla iddialı kalır.
- Çok renkli veya zengin metin bir başlık gerekiyorsa `Label`, `StyledText` veya özel bir element kompozisyonu daha açık bir çözüm sunar.

Temel API:

- Constructor: `Headline::new(text: impl Into<SharedString>)`.
- Builder yöntemleri: `.size(HeadlineSize::...)`, `.color(Color::...)`.
- Boyutlar: `XSmall`, `Small`, `Medium`, `Large`, `XLarge`.

Davranış:

- `RenderOnce` implement eder.
- UI fontunu kullanır.
- `HeadlineSize` değeri rem tabanlı bir font size ve sabit bir headline line-height üretir.

Örnek:

```rust
use ui::prelude::*;

fn panel_basligini_render_et() -> impl IntoElement {
    v_flex()
        .gap_0p5()
        .child(Headline::new("Uzantılar").size(HeadlineSize::Large))
        .child(
            Label::new("Kurulu dil uzantılarını yönet.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
}
```

Zed içinden kullanım örnekleri:

- `extensions_ui` crate'i: extension başlıkları ve sayfa başlıkları.
- `ui` crate'i: modal header içinde.
- `workspace` crate'i: typography preview alanı.

Dikkat edeceğin noktalar:

- `Headline::color(...)` builder'ı alanı günceller, fakat render çıktısı tema text rengini kullanır. Renkli bir başlık davranışı gerekiyorsa `Label` veya özel bir `div()` kompozisyonu ile açık renk uygulaman daha güvenli olur.

## TextSize ve StyledTypography

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::TextSize`, `ui::StyledTypography`.
- Prelude: `ui::prelude::*` içinde otomatik gelir.

Ne zaman kullanırsın:

- `Label` veya `Headline` yerine doğrudan `div()`, `h_flex()` ya da özel bir kapsayıcı üzerinde metin render edeceksen.
- Aynı düz elementin UI fontu, buffer fontu veya kullanıcının ayarladığı editor font size'ı ile hizalanması gerekiyorsa.
- Bir ölçüyü rem olarak değil de pixel olarak okumak gerekiyorsa `TextSize::pixels(cx)` ile.

Ne zaman kullanmazsın:

- Normal kısa UI metni için önce `Label` düşünülür; `Label` zaten doğru font ve size sözleşmesini taşır.
- Başlık için `Headline` daha doğru bir semantik verir.
- Layout aralığı hesaplamak için `TextSize` kullanılmaz; aralık tarafında `DynamicSpacing`, `px(...)` veya `rems_from_px(...)` tercih edilir.

Temel API:

- `StyledTypography` yöntemleri: `.font_ui(cx)`, `.font_buffer(cx)`, `.text_ui_lg(cx)`, `.text_ui(cx)`, `.text_ui_sm(cx)`, `.text_ui_xs(cx)`, `.text_ui_size(size, cx)`, `.text_buffer(cx)`.
- `TextSize`: `Large`, `Default`, `Small`, `XSmall`, `Ui`, `Editor`.
- `TextSize::rems(cx) -> Rems`: text size değerini rem olarak verir.
- `TextSize::pixels(cx) -> Pixels`: aynı semantik boyutu pixel olarak verir; özellikle canvas veya ölçü hesabı yapan düşük seviyeli render kodunda kullanışlıdır.

Davranış:

- `TextSize::Ui`, kullanıcının `ui_font_size` ayarından gelir.
- `TextSize::Editor`, kullanıcının `buffer_font_size` ayarından gelir.
- `font_ui(cx)` ve `font_buffer(cx)`, sadece boyutu değil font family seçimini de temadan alır. Bu yüzden yalnız `.text_size(...)` çağırmak ile aynı şey değildir.

Örnek:

```rust
use ui::prelude::*;

fn ozel_aciklamayi_render_et(cx: &App) -> impl IntoElement {
    div()
        .font_ui(cx)
        .text_ui_sm(cx)
        .text_color(Color::Muted.color(cx))
        .child("Son güncelleme az önce")
}
```

Dikkat edeceğin noktalar:

- `StyledTypography`, `Styled` implement eden elementlere otomatik gelir. Ayrıca bir wrapper trait implement etmene gerek yoktur.
- `TextSize::pixels(cx)` değerini metin render dışında kullanırken, UI scale değiştiğinde bu değerin de değişeceğini hesaba katman gerekir.

## HighlightedLabel

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::HighlightedLabel`
- Prelude: Hayır; `use ui::HighlightedLabel;` satırını ayrıca eklersin.
- Preview: `impl Component for HighlightedLabel`.

Ne zaman kullanırsın:

- Fuzzy search, picker, dosya veya branch arama sonucu ile filtrelenmiş liste satırlarında eşleşen karakterleri vurgulamak için.

Ne zaman kullanmazsın:

- Vurgulanacak bir aralık yoksa normal `Label` daha basit bir çözüm sunar; HighlightedLabel'ın getirdiği ekstra yüzeye gerek kalmaz.
- Vurgu byte pozisyonları yerine semantik span veya zengin metin üzerinden geliyorsa, doğrudan `StyledText`'i kullanmak daha esnektir.

Temel API:

- Constructor: `HighlightedLabel::new(label, highlight_indices)`.
- Range constructor: `HighlightedLabel::from_ranges(label, highlight_ranges)`.
- Düşük seviye yardımcı: `highlight_ranges(text: &str, indices: &[usize], style: HighlightStyle) -> Vec<(Range<usize>, HighlightStyle)>`. Ardışık byte indekslerini char sınırlarına oturmuş tek bir range içinde birleştirir. `HighlightedLabel` içeride bu fonksiyonu kullanır; aynı dönüşümün `StyledText` veya başka zengin metin yüzeylerinde de tekrar etmen gerektiğinde bu yardımcıyı doğrudan import edebilirsin.
- Okuma yöntemleri: `.text()`, `.highlight_indices()`.
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`, `.line_height_style(...)`, `.italic()`, `.underline()`, `.strikethrough()`, `.alpha(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`, `.inline_code(cx)`.
- `.truncate_start()`: etiketi baştan kırpar, sonunu görünür tutar. İçeride taban `Label`'ın `truncate_start()` ayarını yazar; dosya yolu veya branch adı gibi anlamlı kısmı sonda olan eşleşme satırlarında tercih edersin.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`, `.flex_shrink()`, `.flex_shrink_0()`.

Vurgu yardımcısı:

| API | Rol |
| :-- | :-- |
| `highlight_ranges` | Byte indekslerinden char sınırlarına güvenli şekilde oturan `Range<usize>` listesi üretir; hazır `HighlightedLabel` dışında özel `StyledText` kompozisyonlarında kullanılır. |

Davranış:

- `RenderOnce` implement eder.
- Vurgular tema accent text rengiyle çizilir.
- `highlight_indices` parametresi UTF-8 byte pozisyonlarıdır. `new(...)` `#[track_caller]` ile işaretlenmiştir; geçersiz bir byte sınırı içeren indeks tespit edilirse `debug_panic!` tetiklenir ve tüm vurgu listesi silinir — hata ayıklama derlemelerinde programı durdurur, yayın derlemelerinde ise boş vurguyla devam eder. Böylece geçersiz bir indeks yüzünden canlı ortamda çökme yaşanmaz; ancak indeks kaynağının düzeltilmesi gerekir.

Örnekler:

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn arama_sonucunu_render_et(vurgu_indeksleri: Vec<usize>) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_2()
        .child(Icon::new(IconName::MagnifyingGlass).size(IconSize::Small))
        .child(
            HighlightedLabel::new("Son Projeyi Aç", vurgu_indeksleri)
                .size(LabelSize::Small)
                .truncate()
                .flex_1(),
        )
}
```

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_prefix_match() -> impl IntoElement {
    HighlightedLabel::from_ranges("workspace settings", vec![0..9])
        .size(LabelSize::Small)
}
```

Zed içinden kullanım örnekleri:

- `recent_projects` crate'i: son projelerde proje adı eşleşmeleri.
- `git_ui` crate'i: branch adı eşleşmeleri.
- `outline_panel` crate'i: sembol ve path eşleşmeleri.

Dikkat edeceğin noktalar:

- `highlight_indices` bir karakter sırası değil, byte offset listesidir. Türkçe ya da emoji gibi çok byte'lı karakterler içeren metinlerde rastgele indeks üretmek geçersiz sınır sorununa yol açabilir. Bu yüzden matcher'dan gelen byte pozisyonlarını veya `from_ranges` ile verdiğin geçerli byte aralıklarını kullanman gerekir.
- Geçersiz bir indeks yayın derlemelerinde vurgu listesini silerek devam eder; içerik görünmeye devam eder ama hiç vurgu yapılmaz. Hata ayıklama derlemelerinde ise `debug_panic!` aracılığıyla kod konumu (`#[track_caller]`) da belirtilerek işlemi durdurur. Birçok yerden gelen indeksleri birleştiriyorsan hangi çağrı yerinin tetiklediğini görmek için bu bilgiden yararlanırsın.

## LoadingLabel

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::LoadingLabel`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: Doğrudan `impl Component for LoadingLabel` yok.

Ne zaman kullanırsın:

- Bir async işlem sürerken metni kademeli olarak gösteren ve sonunda nokta animasyonu yapan kısa durum etiketleri için.
- `"Kimlik bilgileri yükleniyor"`, `"Bağlanıyor"`, `"Commit üretiliyor"` gibi tek satırlık durum mesajları için uygun bir yüzeydir.

Ne zaman kullanmazsın:

- Yalnızca bir ikon veya spinner gerekiyorsa `SpinnerLabel` ya da animasyonlu bir `Icon` daha doğrudan bir çözümdür.
- Belirli bir ilerleme oranı varsa `ProgressBar` veya `CircularProgress` bileşenleri kullanıcıyı daha doğru bilgilendirir.

Temel API:

- Constructor: `LoadingLabel::new(text)`.
- `LabelCommon` builder'ları: `.size(...)`, `.weight(...)`, `.line_height_style(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`, `.inline_code(cx)`.

Davranış:

- `RenderOnce` implement eder.
- İlk animasyon adımında metni soldan sağa kademeli olarak görünür hâle getirir; sonraki animasyon adımında ise metnin sonuna sırayla `.`, `..`, `...` ekleyerek bunu tekrarlar.
- Render sırasında label rengini son aşamada `Color::Muted` olarak ayarlar.

Örnek:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn kimlik_bilgileri_yukleniyor_render_et() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::new().size(LabelSize::Small))
        .child(LoadingLabel::new("Kimlik bilgileri yükleniyor").size(LabelSize::Small))
}
```

Dikkat edeceğin noktalar:

- `LoadingLabel` render sırasında `Color::Muted` uygular. Renge güvenmen gerekiyorsa düz `Label` ve yanına ayrı bir spinner kompozisyonu kurman daha güvenli olur.
- Bu bileşen bir async task başlatmaz; yalnızca görsel bir animasyon sağlar. Asıl işi başka bir yerde yönetirsin.

## SpinnerLabel

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::SpinnerLabel`
- Prelude: Hayır; `use ui::SpinnerLabel;` satırını ayrıca eklersin.
- Preview: `impl Component for SpinnerLabel`.

Ne zaman kullanırsın:

- Kompakt alanlarda metinsiz bir yükleme göstergesi gerektiğinde.
- Bir label ile aynı hizalamada ve text size'a bağlı bir spinner ihtiyacın olduğunda.

Ne zaman kullanmazsın:

- İkon semantiği veya dönen bir simge gerekiyorsa `Icon::new(IconName::LoadCircle)` ve GPUI'nin animasyon yardımcıları daha uygun bir çözüm sunar.
- İlerleme oranını biliyorsan ilerleme bileşenleri kullanıcıya çok daha açıklayıcı bir geri bildirim verir.

Temel API:

- Constructor: `SpinnerLabel::new()`.
- Varyantlar: `SpinnerLabel::dots()`, `SpinnerLabel::dots_variant()`, `SpinnerLabel::sand()`, `SpinnerLabel::with_variant(SpinnerVariant::...)`.
- `SpinnerVariant`: `Dots`, `DotsVariant`, `Sand`.
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`, `.alpha(...)`.

Spinner varyantları:

| API | Rol |
| :-- | :-- |
| `SpinnerVariant` | `Dots`, `DotsVariant` ve `Sand` seçenekleriyle animasyon frame ailesini seçer; detaylı durum taşımaz. |

Davranış:

- `RenderOnce` implement eder.
- Unicode frame dizilerini `Animation::new(duration).repeat()` ile sürekli döndürür.
- Varsayılan rengi `Color::Muted` olan bir `Label`'ın üstünde kuruludur.

Örnek:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn kompakt_doner_gostergeyi_render_et() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::sand().size(LabelSize::Small).color(Color::Accent))
        .child(Label::new("İndeksleniyor").size(LabelSize::Small).color(Color::Muted))
}
```

## Icon, IconName ve IconSize

Kaynak:

- `Icon`, `IconSize`, `AnyIcon`, `IconWithIndicator`: `ui` crate'i.
- `IconName`: `icons` crate'i, `ui::IconName` adıyla re-export edilir.
- Export: `ui::Icon`, `ui::IconName`, `ui::IconSize`.
- Prelude: `Icon`, `IconName`, `IconSize` otomatik gelir.
- Preview: `impl Component for Icon`.

Ne zaman kullanırsın:

- Toolbar, liste öğesi, durum satırı, tab, menu ve button içindeki semantik simgeler için.
- Tema rengine bağlı tek renk SVG ikonları için.
- Harici bir ikon teması veya provider SVG'si gerektiğinde `from_path` ile `from_external_svg` constructor'ları devreye girer.

Ne zaman kullanmazsın:

- Büyük raster görseller için GPUI'nin `img(...)` / `ImageSource` yüzeyini veya `Avatar` ve `Vector` gibi daha uygun bileşenleri tercih edersin.
- Simgenin yanında bir badge veya durum işareti gerekiyorsa, çıplak `Icon` yerine `DecoratedIcon`, `IconWithIndicator` veya ilgili bileşenin slot yüzeyini düşünürsün.

Temel API:

- `Icon::new(icon_name)`.
- `Icon::from_path(path)`.
- `Icon::from_external_svg(svg_path)`.
- `.size(IconSize::...)`.
- `.color(Color::...)`.
- `IconSize`: `Indicator` 10px, `XSmall` 12px, `Small` 14px, `Medium` 16px (varsayılan), `XLarge` 48px, ayrıca `Custom(Rems)` özel boyut için.
- Ölçü yardımcıları: `IconSize::rems() -> Rems`, `IconSize::square(window, cx) -> Pixels` (ikonu ve simetrik padding'i içeren kare ölçüyü verir) ve `IconSize::square_components(window, cx) -> (Pixels, Pixels)` (ikon ölçüsü ile tek taraf padding'ini ayrı ayrı döndürür). `IconButtonShape::Square` ve özel ikon konteynerlerinin hizalamasında işine yarar.
- `IconName::path()` gömülü ikonun `icons/<name>.svg` yolunu döndürür.

Davranış:

- `RenderOnce` implement eder.
- `Icon::new` gömülü SVG'yi kullanır ve rengi `text_color` üzerinden uygular.
- `from_path` için `icons/` ile başlayan yollar gömülü SVG olarak işlenir; diğer yollar ise harici raster image olarak ele alınır.
- `from_external_svg` ise harici SVG path'ini `svg().external_path(...)` ile çizer.

Örnekler:

```rust
use ui::prelude::*;

fn durum_ikonunu_render_et() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(Icon::new(IconName::Check).size(IconSize::Small).color(Color::Success))
        .child(Label::new("Hazır").size(LabelSize::Small).color(Color::Muted))
}
```

```rust
use ui::prelude::*;

fn render_tool_icon_from_embedded_path() -> impl IntoElement {
    Icon::from_path(IconName::ToolWeb.path())
        .size(IconSize::Small)
        .color(Color::Muted)
}
```

Zed içinden kullanım örnekleri:

- `remote_connection` crate'i: warning ve loading status satırları.
- `ai_onboarding` crate'i: `Icon::new(...)` ve `Icon::from_external_svg(...)` ile provider ikonları.
- `editor` crate'i: dosya ve outline ikonları için `Icon::from_path(...)`.

Dikkat edeceğin noktalar:

- Kullanacağın `IconName` değerinin `icons` crate'inde tanımlı olup olmadığını kontrol etmen gerekir; aksi halde derleme hatası alırsın. Uzak depo servisleri için `Bitbucket`, `Codeberg`, `Forgejo`, `Gitea`, `Gitlab`; kod bloğu sarım durumu için `TextWrap` ve `TextUnwrap` kullanırsın.
- `IconSize::Custom(rems(...))` teknik olarak mümkün olsa da, tasarım sistemiyle tutarlılık açısından standart boyutları tercih etmen önerilir.
- Harici raster path'lerinde SVG recolor davranışı beklememen gerekir; `from_path`, `icons/` dışındaki yolu image olarak işler ve tema renginden bağımsız olarak basar.

## IconWithIndicator ve AnyIcon

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::IconWithIndicator`, `ui::AnyIcon`.
- Prelude: Hayır; ayrıca import edersin.

Ne zaman kullanırsın:

- Bir icon'un sağ alt köşesinde küçük bir durum noktası veya indicator göstermek için `IconWithIndicator`.
- Bir API hem düz `Icon` hem de animasyon sarılmış `AnimationElement<Icon>` kabul edecekse `AnyIcon`.

Ne zaman kullanmazsın:

- Daha büyük veya knockout etkili bir kaplama gerekiyorsa `DecoratedIcon` ve `IconDecoration` daha uygun olur.
- Metinsel sayaç için `CountBadge`, satır içi küçük durum için `Indicator` tek başına daha okunabilir olabilir.
- Sadece icon rengini değiştirmek için `AnyIcon` kullanmana gerek yoktur; düz `Icon::color(...)` yeterlidir.

Temel API:

- `IconWithIndicator::new(icon, indicator)`.
- `.indicator(Option<Indicator>)`.
- `.indicator_color(Color)`: mevcut indicator'ın rengini değiştirir; indicator yoksa no-op davranır.
- `.indicator_border_color(Option<Hsla>)`: sağ alt noktayı çevreleyen border rengini seçer.
- `AnyIcon::map(|icon| ...)`: içerideki düz veya animasyonlu icon'a aynı dönüşümü uygular.

Davranış:

- `IconWithIndicator`, root kapsayıcıyı `relative()` yapar ve indicator'ı sağ alt köşede absolute olarak yerleştirir.
- Border rengi verilmezse `elevated_surface_background` kullanılır; bu varsayılan, popover ve elevated yüzeylerde indicator'ın icon'dan ayrışmasını sağlar.
- `AnyIcon`, icon'un render tipini tek slotta tutmaya yarar. Public builder yüzeyi `impl Into<AnyIcon>` kabul ediyorsa çağıran taraf düz `Icon` verebilir; kendisi manuel enum kurmak zorunda kalmaz.

Örnek:

```rust
use ui::{IconWithIndicator, Indicator, prelude::*};

fn render_online_icon() -> impl IntoElement {
    IconWithIndicator::new(
        Icon::new(IconName::Person).size(IconSize::Small),
        Some(Indicator::dot().color(Color::Success)),
    )
}
```

Dikkat edeceğin noktalar:

- `indicator_color(...)` çağrısı indicator yoksa yeni bir indicator oluşturmaz. Önce `Some(Indicator::dot())` vermen gerekir.
- Indicator'ın anlamını yalnız renge bırakmazsın. Kullanıcı durumu okuyacaksa yanında tooltip veya label kullanırsın.

## DecoratedIcon ve IconDecoration

Kaynak:

- `DecoratedIcon`: `ui` crate'i.
- `IconDecoration`, `IconDecorationKind`, `KnockoutIconName`: `ui` crate'i.
- Export: `ui::DecoratedIcon`, `ui::IconDecoration`, `ui::IconDecorationKind`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `DecoratedIcon` için vardır; `IconDecoration` tek başına bir preview taşımaz.

Ne zaman kullanırsın:

- Bir dosya veya tab ikonunun üstüne hata, devre dışı, silinmiş veya başka bir özel durum işaretini bindirmen gerektiğinde.
- İkonun üzerinde küçük bir `X`, `Dot` veya `Triangle` kaplaması gerektiğinde.

Ne zaman kullanmazsın:

- Basit bir durum noktası yeterli olduğunda `Indicator` veya `IconWithIndicator` daha sade ve doğrudan bir çözüm sağlar.
- Bir badge metni veya sayaç ifadesi gerekiyorsa `CountBadge` gibi bileşenler daha uygundur.

Temel API:

- `DecoratedIcon::new(icon, Option<IconDecoration>)`.
- `IconDecoration::new(kind, knockout_color, cx)`.
- `IconDecorationKind`: `X`, `Dot`, `Triangle`.
- `KnockoutIconName`: `XFg`, `XBg`, `DotFg`, `DotBg`, `TriangleFg`, `TriangleBg`. Bu enum knockout SVG path'lerini üretir; normal tüketici kodu genellikle bunun yerine `IconDecorationKind` ile çalışır.
- Decoration builder'ları: `.kind(...)`, `.color(hsla)`, `.knockout_color(hsla)`, `.knockout_hover_color(hsla)`, `.position(point)`, `.size(px)`, `.group_name(...)`.

Dekorasyon türleri:

| API | Rol |
| :-- | :-- |
| `IconDecorationKind` | Overlay biçimini seçer: `X` hata/silme, `Dot` küçük durum noktası, `Triangle` köşe uyarısı için kullanılır. |
| `IconDecorationKind::iter()` | `IconDecorationKind` varyantlarını preview veya doğrulama kodunda dolaşmak için `strum::IntoEnumIterator` üzerinden kullanılır. |
| `KnockoutIconName::iter()` | Knockout SVG enum varyantlarını listelemek için `strum::IntoEnumIterator` üzerinden kullanılır; normal bileşen tüketicisi genellikle doğrudan çağırmaz. |

Davranış:

- `DecoratedIcon` relative bir kapsayıcı oluşturur, icon boyutunu kapsayıcı boyutu olarak kullanır ve decoration'ı absolute bir kaplama olarak ekler.
- `IconDecoration`, knockout foreground/background SVG çiftiyle çalışır. `knockout_color` değerinin, ikonun üzerinde durduğu yüzey rengiyle eşleşmesi gerekir; çünkü knockout efekti tam olarak bu eşleşmeden doğar.
- `group_name(...)` verildiğinde knockout hover rengi group hover üzerinden değişir; vermediğin durumlarda hover style doğrudan elementin kendisine uygulanır.

Örnek:

```rust
use ui::prelude::*;
use ui::{DecoratedIcon, IconDecoration, IconDecorationKind};

fn render_file_with_error(cx: &App) -> impl IntoElement {
    let decoration = IconDecoration::new(
        IconDecorationKind::X,
        cx.theme().colors().surface_background,
        cx,
    )
    .color(Color::Error.color(cx));

    h_flex()
        .gap_2()
        .child(DecoratedIcon::new(
            Icon::new(IconName::FileDoc).color(Color::Muted),
            Some(decoration),
        ))
        .child(Label::new("schema.json").truncate())
}
```

Zed içinden kullanım örnekleri:

- `tab_switcher` crate'i: tab ikonları üzerine durum dekorasyonu bindirilir.
- `zed` crate'i: `ThreadItem` ikon dekorasyonu görsel testlerde kullanılır.

Dikkat edeceğin noktalar:

- `IconDecoration::color(...)` bir `Color` değil, doğrudan `Hsla` bekler. Semantik bir renkten türetmek için `Color::Error.color(cx)` gibi bir çağrı yaparsın.
- Decoration'ın knockout rengi arka planla eşleşmediğinde, kaplama çevresinde istenmeyen bir kenar görünebilir. Bu yüzden knockout rengini yüzey rengiyle birebir eşleştirmen önemlidir.
- Büyük ya da metin içeren durumlar için ikon dekorasyonu yerine satır içinde `Indicator`, `CountBadge` veya açıklayıcı bir `Label` kullanman daha okunabilir bir sonuç verir.

## Metin ve ikon kompozisyon örnekleri

Aşağıdaki örnekler, bu bölümdeki yapı taşlarının birlikte nasıl kullanıldığını gösterir. Önce bir durum satırı; ikon ve label birlikte durur ve durum koşuluna göre renk değişir:

```rust
use ui::prelude::*;

fn render_sync_status(message: SharedString, is_error: bool) -> impl IntoElement {
    let (icon, color) = if is_error {
        (IconName::Warning, Color::Error)
    } else {
        (IconName::Check, Color::Success)
    };

    h_flex()
        .min_w_0()
        .gap_1()
        .child(Icon::new(icon).size(IconSize::Small).color(color))
        .child(Label::new(message).size(LabelSize::Small).color(Color::Muted).truncate())
}
```

Bir arama sonucu satırında ise hem fuzzy eşleşmeli proje adı hem de küçültülmüş ikincil path satırı bir arada gösterilir. `HighlightedLabel` eşleşen byte aralıklarını otomatik olarak vurgular:

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_project_match(
    name: SharedString,
    path: SharedString,
    match_indices: Vec<usize>,
) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_2()
        .child(Icon::new(IconName::Folder).color(Color::Muted))
        .child(
            v_flex()
                .min_w_0()
                .child(HighlightedLabel::new(name, match_indices).truncate())
                .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate()),
        )
}
```

Bir yükleme satırı için ise `SpinnerLabel` ve `LoadingLabel` birlikte durduğunda hem bir spinner görüntüsü hem de kademeli metin animasyonu elde edersin:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn indeksleme_satirini_render_et() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::new().size(LabelSize::Small))
        .child(LoadingLabel::new("Proje indeksleniyor").size(LabelSize::Small))
}
```
