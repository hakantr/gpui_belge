# 4. Metin ve İkon Bileşenleri

Metin ve ikon bileşenleri Zed UI içinde en sık kullanılan yapı taşlarıdır.
Başlık, etiket, arama sonucu, durum satırı, liste item'i, toolbar veya bildirim
gibi sahnelerin çoğu bu parçalarla başlar. Bu yüzden bir ekran kurarken ilk
soru çoğu zaman şudur: Bu metin normal bir `Label` mı olmalı, daha güçlü bir
`Headline` mı gerektiriyor, yanına hangi `Icon` eşlik etmeli?

Genel tercih sırası şöyle düşünülebilir:

- Yapısal bir başlık için `Headline` kullanılır.
- Normal UI metni için `Label` yeterlidir ve ilk akla gelen seçenektir.
- Hazır label modeli ihtiyacı karşılamıyorsa, sınırlı bir özel metin yüzeyi
  olarak `LabelLike` tercih edilebilir.
- Arama veya fuzzy match sonucunda eşleşen karakterleri vurgulamak için
  `HighlightedLabel` vardır.
- Bir işlem sürerken metinle geri bildirim vermek için `LoadingLabel`
  kullanılır.
- Sadece bir yükleme göstergesi gerekiyorsa `SpinnerLabel` daha uygundur.
- Simgeler için `Icon` temel yapı taşıdır; bir simgenin üstünde durum
  işareti gerektiğinde ise `DecoratedIcon` ve `IconDecoration` ikilisi
  devreye girer.

## Label

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/label.rs`
- Ortak stil yüzeyi: `../zed/crates/ui/src/components/label/label_like.rs`
- Export: `ui::Label`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: `impl Component for Label`.

Ne zaman kullanılır:

- Buton dışındaki kısa UI metinleri, açıklamalar, metadata satırları, durum
  metinleri ve liste satırı metinleri için.
- Tema ile uyumlu bir renk, boyut, ağırlık ve truncation davranışı gereken
  hemen her yerde.
- Metin içinde backtick karakterleriyle işaretlenmiş küçük kod parçalarını
  göstermek için `render_code_spans()` yardımcısı vardır; backtick'le
  sarılı bölümler otomatik olarak buffer fontuyla ve hafif arka planla
  vurgulanır.

Ne zaman kullanılmaz:

- Ekran veya bölüm başlığı gerektiğinde `Headline` daha uygun bir yüzeydir;
  başlıklara ait tipografi davranışını otomatik getirir.
- Metnin bir kısmı arama sonucuna göre vurgulanacaksa `HighlightedLabel`
  tercih edilir; bu Label'ın yapamayacağı bir iştir.
- Tamamen özel bir rich text veya çok biçimli uzun bir içerik gerekiyorsa,
  GPUI'nin `StyledText` ailesi veya doğrudan text primitive'leri daha esnektir.

Temel API:

- Constructor: `Label::new(label: impl Into<SharedString>)`.
- Sık builder'lar: `.size(LabelSize::...)`, `.color(Color::...)`,
  `.weight(FontWeight::...)`, `.italic()`, `.underline()`,
  `.strikethrough()`, `.alpha(f32)`, `.truncate()`, `.truncate_start()`,
  `.single_line()`, `.buffer_font(cx)`, `.inline_code(cx)`,
  `.render_code_spans()`.
- Mutator: `.set_text(text: impl Into<SharedString>)` çağrısı `&mut self`
  üzerinden label metnini günceller. `Label` örneği view alanında
  saklanıyorsa, render dışından yeni bir `Label` üretmeden mevcut örneğin
  metnini değiştirmek için kullanılır. Bu metod builder zincirinde değil,
  daha önce oluşturulmuş bir örnek üzerinde çağrılır.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`,
  `.flex_shrink()`, `.flex_shrink_0()` ile çeşitli margin style yöntemleri.
- Trait: `LabelCommon`.

Davranış:

- `RenderOnce` implement eder.
- `LabelCommon` ayarlarını arka planda `LabelLike` üzerinden uygular; yani
  Label görsel olarak `LabelLike`'ın hazır bir şekli gibi düşünülebilir.
- `single_line()` çağrısı, metin içindeki newline karakterlerini tek satırda
  görünür olacak biçimde dönüştürür; çok satırlı bir metnin satırlara
  bölünmesini engeller.
- `render_code_spans()` çağrısı, metindeki eşleşen backtick çiftlerini
  kaldırır ve bu aralıkları buffer fontuyla, element background rengiyle
  vurgular. Sonuç olarak "Run `zed --new`" gibi bir metinde sadece
  `zed --new` kısmı kod gibi görünür.

Örnekler:

```rust
use ui::prelude::*;

fn render_file_metadata(path: SharedString) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_1()
        .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate())
        .child(Label::new("modified").size(LabelSize::Small).color(Color::Warning))
}
```

```rust
use ui::prelude::*;

fn render_command_hint() -> impl IntoElement {
    Label::new("Run `zed --new` to open a fresh window.")
        .render_code_spans()
        .size(LabelSize::Small)
        .color(Color::Muted)
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/recent_projects/src/recent_projects.rs`: proje adı, branch
  ve path metinlerinde `Label` ve `HighlightedLabel` birlikte kullanılır.
- `../zed/crates/remote_connection/src/remote_connection.rs`: uyarı ve durum
  satırlarında `Icon` ve `Label` kompozisyonu geçer.
- `../zed/crates/git_ui/src/git_panel.rs`: status, commit ve branch
  metadata'larında `Label` oldukça yoğun biçimde kullanılır.

Dikkat edilecek noktalar:

- Uzun bir metin dar bir container içine yerleştirildiğinde `.truncate()`
  veya `.truncate_start()` çağrısının eklenmesi gerekir; aksi halde satır
  taşması layout'u bozabilir.
- `Label::new(format!(...))` pratik bir kısayoldur. Ancak sık render edilen
  listelerde hazır `SharedString` veya önceden üretilmiş bir metin kullanmak
  gereksiz allocation'ı azaltır ve render maliyetini düşürür.
- Tüm satırı monospace yapmak gerekiyorsa `.buffer_font(cx)` veya
  `.inline_code(cx)` çağrılır; yalnızca backtick içindeki bölümleri
  vurgulamak gerekiyorsa `.render_code_spans()` daha doğru bir seçimdir.

## LabelLike

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/label_like.rs`
- Export: `ui::LabelLike`
- Prelude: Hayır; `use ui::LabelLike;` satırı ayrıca eklenir.
- Preview: `impl Component for LabelLike`.

Ne zaman kullanılır:

- `Label` veya `HighlightedLabel` yeterli olmadığında, ancak yine de
  `LabelCommon`'ın getirdiği renk, boyut, ağırlık ve truncation kurallarının
  korunması gerektiğinde.
- Birden fazla child element içeren ve yine de bir label gibi davranan
  küçük inline kompozisyonlarda.

Ne zaman kullanılmaz:

- Düz metin için `Label`, arama vurgusu için `HighlightedLabel` daha tutarlı ve
  daha kısıtlı bir yüzey sunar. Bu kısıtlama çoğu zaman avantajdır; tasarımın
  gereksiz yere dağılmasını engeller.
- Komple özel bir rich text, editor metni veya seçilebilir metin gerekiyorsa
  GPUI'nin text primitive'leri daha uygun olabilir.

Temel API:

- Constructor: `LabelLike::new()`.
- `LabelCommon`: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.line_height_style(...)`, `.italic()`, `.underline()`, `.strikethrough()`,
  `.alpha(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.
- Ek builder: `.truncate_start()`.
- `ParentElement` implement eder; `.child(...)` ve `.children(...)` kabul
  eder.
- `LineHeightStyle`: `TextLabel` varsayılan label/buffer line-height
  davranışını verir; `UiLabel` ise line-height değerini `1` yapan daha kompakt
  bir UI etiketi davranışını seçer.

Davranış:

- `RenderOnce` implement eder.
- `Label` ailesinin kullandığı iç stil yüzeyidir; UI font ağırlığı, semantic
  `Color` ve `LabelSize` değerlerini aynı şekilde uygular.
- Serbestçe child kabul ettiği için tutarsız bir tipografi üretmek
  kolaylaşır; bu yüzden kullanımı hazır label'ların yetmediği durumlarla
  sınırlı tutulur.

Örnek:

```rust
use ui::prelude::*;
use ui::LabelLike;

fn render_inline_hint(action: SharedString, cx: &App) -> impl IntoElement {
    LabelLike::new()
        .size(LabelSize::Small)
        .color(Color::Muted)
        .child("Press ")
        .child(Label::new(action).inline_code(cx))
}
```

## Headline

Kaynak:

- Tanım: `../zed/crates/ui/src/styles/typography.rs`
- Export: `ui::Headline`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: `impl Component for Headline`.

Ne zaman kullanılır:

- Modal başlığı, panel başlığı, onboarding başlığı veya section başlığı
  gibi, görsel bir hiyerarşi kuran kısa metinler için.

Ne zaman kullanılmaz:

- Satır içi metadata, küçük açıklama veya gövde metni için `Label` daha
  doğru bir araçtır; Headline o ölçeğe göre fazla iddialı kalır.
- Çok renkli veya rich text bir başlık gerekiyorsa `Label`, `StyledText`
  veya özel bir element kompozisyonu daha açık bir çözüm sunar.

Temel API:

- Constructor: `Headline::new(text: impl Into<SharedString>)`.
- Builder yöntemleri: `.size(HeadlineSize::...)`, `.color(Color::...)`.
- Boyutlar: `XSmall`, `Small`, `Medium`, `Large`, `XLarge`.

Davranış:

- `RenderOnce` implement eder.
- UI fontunu kullanır.
- `HeadlineSize` değeri rem tabanlı bir font size ve sabit bir headline
  line-height üretir.

Örnek:

```rust
use ui::prelude::*;

fn render_panel_title() -> impl IntoElement {
    v_flex()
        .gap_0p5()
        .child(Headline::new("Extensions").size(HeadlineSize::Large))
        .child(
            Label::new("Manage installed language extensions.")
                .size(LabelSize::Small)
                .color(Color::Muted),
        )
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension başlıkları
  ve sayfa başlıkları.
- `../zed/crates/ui/src/components/modal.rs`: modal header içinde.
- `../zed/crates/workspace/src/theme_preview.rs`: typography preview alanı.

Dikkat edilecek noktalar:

- Mevcut kaynakta `Headline::color(...)` alanı set eder, ancak `render`
  içinde renk olarak doğrudan `cx.theme().colors().text` kullanılır. Yani
  Headline'a verilen renk şu an pratikte yansımıyor. Renkli bir başlık
  davranışı gerekiyorsa kaynak güncellenene kadar `Label` veya özel bir
  `div()` kompozisyonu ile açık renk uygulamak daha güvenli bir tercihtir.

## HighlightedLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/highlighted_label.rs`
- Export: `ui::HighlightedLabel`
- Prelude: Hayır; `use ui::HighlightedLabel;` ayrıca eklenir.
- Preview: `impl Component for HighlightedLabel`.

Ne zaman kullanılır:

- Fuzzy search, picker, dosya veya branch arama sonucu ile filtrelenmiş
  liste satırlarında eşleşen karakterleri vurgulamak için.

Ne zaman kullanılmaz:

- Vurgulanacak bir aralık yoksa normal `Label` daha basit bir çözüm sunar;
  HighlightedLabel'ın getirdiği ekstra yüzeye gerek kalmaz.
- Vurgu byte pozisyonları yerine semantic span veya rich text üzerinden
  geliyorsa, doğrudan `StyledText` kullanmak daha esnektir.

Temel API:

- Constructor: `HighlightedLabel::new(label, highlight_indices)`.
- Range constructor: `HighlightedLabel::from_ranges(label, highlight_ranges)`.
- Düşük seviye yardımcı:
  `highlight_ranges(text: &str, indices: &[usize], style: HighlightStyle)
  -> Vec<(Range<usize>, HighlightStyle)>`. Ardışık byte indekslerini char
  sınırlarına oturmuş tek bir range içinde birleştirir. `HighlightedLabel`
  içeride bu fonksiyonu kullanır; aynı dönüşümün `StyledText` veya başka
  rich text yüzeylerinde de tekrar edilmesi gerektiğinde bu yardımcı
  doğrudan import edilebilir.
- Okuma yöntemleri: `.text()`, `.highlight_indices()`.
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.italic()`, `.underline()`, `.truncate()`, `.single_line()`.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`,
  `.flex_shrink()`, `.flex_shrink_0()`.

Davranış:

- `RenderOnce` implement eder.
- Vurgular tema accent text rengiyle çizilir.
- `highlight_indices` parametresi UTF-8 byte pozisyonlarıdır. `new(...)`,
  her bir pozisyonun geçerli bir char boundary'sine denk gelip gelmediğini
  assert eder; aksi halde panic oluşur.

Örnekler:

```rust
use ui::prelude::*;
use ui::HighlightedLabel;

fn render_search_result(highlight_indices: Vec<usize>) -> impl IntoElement {
    h_flex()
        .min_w_0()
        .gap_2()
        .child(Icon::new(IconName::MagnifyingGlass).size(IconSize::Small))
        .child(
            HighlightedLabel::new("Open Recent Project", highlight_indices)
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

- `../zed/crates/recent_projects/src/recent_projects.rs`: son projelerde
  proje adı eşleşmeleri.
- `../zed/crates/git_ui/src/branch_picker.rs`: branch adı eşleşmeleri.
- `../zed/crates/outline_panel/src/outline_panel.rs`: sembol ve path
  eşleşmeleri.

Dikkat edilecek noktalar:

- `highlight_indices` bir karakter sırası değil, byte offset listesidir.
  Türkçe ya da emoji gibi çok byte'lı karakterler içeren metinlerde
  rastgele indeks üretmek panic'e yol açabilir. Bu nedenle matcher'dan
  gelen byte pozisyonlarının veya `from_ranges` ile verilen geçerli byte
  aralıklarının kullanılması gerekir.
- `new(...)` geçersiz bir UTF-8 sınırında panic eden bir `assert!` içerir.
  Kullanıcı girdisinden türetilmiş pozisyonların önceden doğrulanması
  gerekir; aksi halde çalışma anında crash riski oluşur.

## LoadingLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/loading_label.rs`
- Export: `ui::LoadingLabel`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: Doğrudan `impl Component for LoadingLabel` yok.

Ne zaman kullanılır:

- Bir async işlem sürerken metni kademeli olarak gösteren ve sonunda nokta
  animasyonu yapan kısa durum label'ları için.
- "Loading credentials", "Connecting", "Generating commit" gibi tek
  satırlık durum mesajları için uygun bir yüzeydir.

Ne zaman kullanılmaz:

- Yalnızca bir ikon veya spinner gerekiyorsa `SpinnerLabel` ya da
  animasyonlu bir `Icon` daha doğrudan bir çözümdür.
- Belirli bir progress oranı varsa `ProgressBar` veya `CircularProgress`
  bileşenleri kullanıcıyı daha doğru bilgilendirir.

Temel API:

- Constructor: `LoadingLabel::new(text)`.
- `LabelCommon` builder'ları: `.size(...)`, `.weight(...)`,
  `.line_height_style(...)`, `.truncate()`, `.single_line()`,
  `.buffer_font(cx)`, `.inline_code(cx)`.

Davranış:

- `RenderOnce` implement eder.
- İlk animasyon adımında metni soldan sağa kademeli olarak görünür hâle
  getirir; sonraki animasyon adımında ise metnin sonuna sırayla `.`, `..`,
  `...` ekleyerek bunu tekrarlar.
- Render sırasında label rengini son aşamada `Color::Muted` olarak ayarlar.

Örnek:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn render_loading_credentials() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::new().size(LabelSize::Small))
        .child(LoadingLabel::new("Loading credentials").size(LabelSize::Small))
}
```

Dikkat edilecek noktalar:

- Kaynakta `LoadingLabel` `LabelCommon::color(...)` implement etmesine
  rağmen render içinde son aşamada her durumda `Color::Muted` uygular.
  Yani verilen renk yansımaz. Renge güven gerekiyorsa düz `Label` ve
  yanına ayrı bir spinner kompozisyonu kurmak daha güvenli bir tercihtir.
- Bu component bir async task başlatmaz; yalnızca görsel bir animasyon
  sağlar. Asıl iş başka bir yerde yönetilir.

## SpinnerLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/spinner_label.rs`
- Export: `ui::SpinnerLabel`
- Prelude: Hayır; `use ui::SpinnerLabel;` ayrıca eklenir.
- Preview: `impl Component for SpinnerLabel`.

Ne zaman kullanılır:

- Kompakt alanlarda metinsiz bir yükleme göstergesi gerektiğinde.
- Bir label ile aynı hizalamada ve text size'a bağlı bir spinner ihtiyacı
  olduğunda.

Ne zaman kullanılmaz:

- İkon semantiği veya dönen bir simge gerekiyorsa
  `Icon::new(IconName::LoadCircle)` ve GPUI'nin animasyon helper'ları daha
  uygun bir çözüm sunar.
- Progress oranı biliniyorsa progress bileşenleri kullanıcıya çok daha
  açıklayıcı bir geri bildirim verir.

Temel API:

- Constructor: `SpinnerLabel::new()`.
- Varyantlar: `SpinnerLabel::dots()`, `.dots_variant()`, `.sand()`,
  `SpinnerLabel::with_variant(SpinnerVariant::...)`.
- `SpinnerVariant`: `Dots`, `DotsVariant`, `Sand`.
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.alpha(...)`.

Davranış:

- `RenderOnce` implement eder.
- Unicode frame dizilerini `Animation::new(duration).repeat()` ile sürekli
  döndürür.
- Varsayılan rengi `Color::Muted` olan bir `Label`'ın üstünde kuruludur.

Örnek:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn render_compact_spinner() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::sand().size(LabelSize::Small).color(Color::Accent))
        .child(Label::new("Indexing").size(LabelSize::Small).color(Color::Muted))
}
```

## Icon, IconName ve IconSize

Kaynak:

- `Icon`, `IconSize`, `AnyIcon`, `IconWithIndicator`:
  `../zed/crates/ui/src/components/icon.rs`.
- `IconName`: `../zed/crates/icons/src/icons.rs`, `ui::IconName` adıyla
  re-export edilir.
- Export: `ui::Icon`, `ui::IconName`, `ui::IconSize`.
- Prelude: `Icon`, `IconName`, `IconSize` otomatik gelir.
- Preview: `impl Component for Icon`.

Ne zaman kullanılır:

- Toolbar, list item, status row, tab, menu ve button içindeki semantik
  simgeler için.
- Tema rengine bağlı tek renk SVG ikonları için.
- Harici bir ikon teması veya provider SVG'si gerektiğinde `from_path` ile
  `from_external_svg` constructor'ları devreye girer.

Ne zaman kullanılmaz:

- Büyük raster görseller için GPUI'nin `img(...)` / `ImageSource` yüzeyi
  veya `Avatar` ve `Vector` gibi daha uygun bileşenler tercih edilir.
- Simgenin yanında bir badge veya durum işareti gerekiyorsa, çıplak `Icon`
  yerine `DecoratedIcon`, `IconWithIndicator` veya ilgili component'in slot
  yüzeyi düşünülür.

Temel API:

- `Icon::new(icon_name)`.
- `Icon::from_path(path)`.
- `Icon::from_external_svg(svg_path)`.
- `.size(IconSize::...)`.
- `.color(Color::...)`.
- `IconSize`: `Indicator` 10px, `XSmall` 12px, `Small` 14px, `Medium`
  16px, `XLarge` 48px, ayrıca `Custom(Rems)` özel boyut için.
- Ölçü yardımcıları: `IconSize::rems() -> Rems`,
  `IconSize::square(window, cx) -> Pixels` (ikonu ve simetrik padding'i
  içeren kare ölçüyü verir) ve
  `IconSize::square_components(window, cx) -> (Pixels, Pixels)` (ikon
  ölçüsü ile tek taraf padding'ini ayrı ayrı döndürür).
  `IconButtonShape::Square` ve özel ikon konteynerlerinin hizalamasında
  işe yarar.
- `IconName::path()` gömülü ikonun `icons/<name>.svg` yolunu döndürür.

Davranış:

- `RenderOnce` implement eder.
- `Icon::new` gömülü SVG'yi kullanır ve rengi `text_color` üzerinden uygular.
- `from_path` için `icons/` ile başlayan yollar gömülü SVG olarak işlenir;
  diğer yollar ise harici raster image olarak ele alınır.
- `from_external_svg` ise harici SVG path'ini `svg().external_path(...)`
  ile çizer.

Örnekler:

```rust
use ui::prelude::*;

fn render_status_icon() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(Icon::new(IconName::Check).size(IconSize::Small).color(Color::Success))
        .child(Label::new("Ready").size(LabelSize::Small).color(Color::Muted))
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

- `../zed/crates/remote_connection/src/remote_connection.rs`: warning ve
  loading status satırları.
- `../zed/crates/ai_onboarding/src/agent_api_keys_onboarding.rs`:
  `Icon::new(...)` ve `Icon::from_external_svg(...)` ile provider ikonları.
- `../zed/crates/editor/src/element.rs`: dosya ve outline ikonları için
  `Icon::from_path(...)`.

Dikkat edilecek noktalar:

- Kullanılacak `IconName` değerinin `../zed/crates/icons/src/icons.rs`
  içinde tanımlı olup olmadığının kontrol edilmesi gerekir; aksi halde
  derleme hatası alınır.
- `IconSize::Custom(rems(...))` teknik olarak mümkün olsa da, tasarım
  sistemiyle tutarlılık açısından standart boyutların tercih edilmesi
  önerilir.
- Harici raster path'lerinde SVG recolor davranışı beklenmemelidir;
  `from_path`, `icons/` dışındaki yolu image olarak işler ve tema renginden
  bağımsız olarak basılır.

## DecoratedIcon ve IconDecoration

Kaynak:

- `DecoratedIcon`: `../zed/crates/ui/src/components/icon/decorated_icon.rs`.
- `IconDecoration`, `IconDecorationKind`, `KnockoutIconName`:
  `../zed/crates/ui/src/components/icon/icon_decoration.rs`.
- Export: `ui::DecoratedIcon`, `ui::IconDecoration`,
  `ui::IconDecorationKind`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `DecoratedIcon` için vardır; `IconDecoration` tek başına bir
  preview taşımaz.

Ne zaman kullanılır:

- Bir dosya veya tab ikonunun üstüne hata, devre dışı, silinmiş veya başka
  bir özel durum işaretinin bindirilmesi gerektiğinde.
- İkonun üzerinde küçük bir `X`, `Dot` veya `Triangle` overlay'i
  gerektiğinde.

Ne zaman kullanılmaz:

- Basit bir status noktası yeterli olduğunda `Indicator` veya
  `IconWithIndicator` daha sade ve doğrudan bir çözüm sağlar.
- Bir badge metni veya sayaç ifadesi gerekiyorsa `CountBadge` gibi
  bileşenler daha uygundur.

Temel API:

- `DecoratedIcon::new(icon, Option<IconDecoration>)`.
- `IconDecoration::new(kind, knockout_color, cx)`.
- `IconDecorationKind`: `X`, `Dot`, `Triangle`.
- `KnockoutIconName`: `XFg`, `XBg`, `DotFg`, `DotBg`, `TriangleFg`,
  `TriangleBg`. Bu enum knockout SVG path'lerini üretir; normal tüketici
  kodu genellikle bunun yerine `IconDecorationKind` ile çalışır.
- Decoration builder'ları: `.kind(...)`, `.color(hsla)`,
  `.knockout_color(hsla)`, `.knockout_hover_color(hsla)`,
  `.position(point)`, `.size(px)`, `.group_name(...)`.

Davranış:

- `DecoratedIcon` relative bir container oluşturur, icon boyutunu container
  size olarak kullanır ve decoration'ı absolute bir overlay olarak ekler.
- `IconDecoration`, knockout foreground/background SVG çiftiyle çalışır.
  `knockout_color` değerinin, ikonun üzerinde durduğu yüzey rengiyle
  eşleşmesi gerekir; çünkü knockout efekti tam olarak bu eşleşmeden doğar.
- `group_name(...)` verildiğinde knockout hover rengi group hover üzerinden
  değişir; verilmediği durumlarda hover style doğrudan elementin kendisine
  uygulanır.

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

- `../zed/crates/tab_switcher/src/tab_switcher.rs`: tab ikonları üzerine
  durum dekorasyonu bindirilir.
- `../zed/crates/zed/src/visual_test_runner.rs`: `ThreadItem` ikon
  dekorasyonu görsel testlerde kullanılır.

Dikkat edilecek noktalar:

- `IconDecoration::color(...)` bir `Color` değil, doğrudan `Hsla` bekler.
  Semantik bir renkten türetmek için `Color::Error.color(cx)` gibi bir
  çağrı yapılır.
- Decoration'ın knockout rengi arka planla eşleşmediğinde, overlay
  çevresinde istenmeyen bir kenar görünebilir. Bu yüzden knockout renginin
  yüzey rengiyle birebir eşleşmesi önemlidir.
- Büyük ya da metin içeren durumlar için ikon dekorasyonu yerine satır
  içinde `Indicator`, `CountBadge` veya açıklayıcı bir `Label` kullanmak
  daha okunabilir bir sonuç verir.

## Metin ve ikon kompozisyon örnekleri

Aşağıdaki örnekler, bu bölümdeki yapı taşlarının birlikte nasıl
kullanıldığını gösterir. Önce bir durum satırı; ikon ve label birlikte
durur ve durum koşuluna göre renk değişir:

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

Bir arama sonucu satırında ise hem fuzzy eşleşmeli proje adı hem de
küçültülmüş ikincil path satırı bir arada gösterilir. `HighlightedLabel`
eşleşen byte aralıklarını otomatik olarak vurgular:

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

Bir yükleme satırı için ise `SpinnerLabel` ve `LoadingLabel` birlikte
durduğunda hem bir spinner görüntüsü hem de kademeli metin animasyonu
elde edilir:

```rust
use ui::prelude::*;
use ui::SpinnerLabel;

fn render_indexing_row() -> impl IntoElement {
    h_flex()
        .gap_1()
        .child(SpinnerLabel::new().size(LabelSize::Small))
        .child(LoadingLabel::new("Indexing project").size(LabelSize::Small))
}
```
