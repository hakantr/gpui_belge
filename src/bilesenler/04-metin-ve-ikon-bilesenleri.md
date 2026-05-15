# 4. Metin ve İkon Bileşenleri

Metin ve ikon bileşenleri Zed UI içinde en sık kullanılan yapı taşlarıdır. Başlık,
etiket, arama sonucu, durum satırı, liste item'i, toolbar ve bildirim gibi çoğu
kompozisyon bu bileşenlerden başlar.

Genel kural:

- Yapısal başlık için `Headline`.
- Normal UI metni için `Label`.
- Hazır label slot modeli yetmediğinde, sınırlı custom metin yüzeyi için
  `LabelLike`.
- Arama veya fuzzy match vurgusu için `HighlightedLabel`.
- İşlem devam ederken metinle geri bildirim vermek için `LoadingLabel`.
- Yalnızca yükleme göstergesi gerektiğinde `SpinnerLabel`.
- Simgeler için `Icon`; simgenin üstünde durum işareti gerekiyorsa
  `DecoratedIcon` ve `IconDecoration`.

## Label

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/label.rs`
- Ortak stil yüzeyi: `../zed/crates/ui/src/components/label/label_like.rs`
- Export: `ui::Label`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: `impl Component for Label`

Ne zaman kullanılır:

- Buton dışındaki kısa UI metinleri, açıklamalar, metadata, durum metinleri ve
  liste satırı metinleri için.
- Tema ile uyumlu renk, boyut, ağırlık ve truncation gereken her yerde.
- Metin içinde backtick ile işaretlenmiş küçük kod parçalarını göstermek için
  `render_code_spans()`.

Ne zaman kullanılmaz:

- Ekran veya bölüm başlığı gerekiyorsa `Headline` daha uygun.
- Metnin bir kısmı arama sonucuna göre vurgulanacaksa `HighlightedLabel`
  kullanılmalı.
- Tamamen özel rich text veya çok biçimli uzun içerik gerekiyorsa GPUI'nin
  `StyledText` / text primitive'leri daha doğrudan olabilir.

Temel API:

- Constructor: `Label::new(label: impl Into<SharedString>)`
- Sık builder'lar: `.size(LabelSize::...)`, `.color(Color::...)`,
  `.weight(FontWeight::...)`, `.italic()`, `.underline()`, `.strikethrough()`,
  `.alpha(f32)`, `.truncate()`, `.truncate_start()`, `.single_line()`,
  `.buffer_font(cx)`, `.inline_code(cx)`, `.render_code_spans()`.
- Mutator: `.set_text(text: impl Into<SharedString>)` `&mut self` üzerinden
  label metnini günceller; `Label` view alanında saklanıyorsa render dışından
  yeni `Label` üretmeden metni değiştirmek için kullanılır. Builder zincirinde
  değil, mevcut instance üzerinde çağrılır.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`,
  `.flex_shrink()`, `.flex_shrink_0()` ve margin style yöntemleri.
- Trait: `LabelCommon`.

Davranış:

- `RenderOnce` implement eder.
- `LabelCommon` ayarlarını `LabelLike` üzerinden uygular.
- `single_line()` newline karakterlerini tek satırda gösterilecek şekilde
  dönüştürür.
- `render_code_spans()` metindeki eşleşen backtick çiftlerini kaldırır ve bu
  aralıkları buffer fontuyla, element background rengiyle vurgular.

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

Zed içinden kullanım:

- `../zed/crates/recent_projects/src/recent_projects.rs`: proje adı, branch ve path
  metinlerinde `Label` ve `HighlightedLabel` birlikte kullanılır.
- `../zed/crates/remote_connection/src/remote_connection.rs`: uyarı ve durum
  satırlarında `Icon` + `Label` kompozisyonu kullanılır.
- `../zed/crates/git_ui/src/git_panel.rs`: status, commit ve branch
  metadata'larında `Label` yoğun biçimde kullanılır.

Dikkat edilecekler:

- Uzun metni dar container içinde kullanırken `.truncate()` veya
  `.truncate_start()` ekleyin; aksi halde satır taşması layout'u bozabilir.
- `Label::new(format!(...))` pratik olsa da sık render edilen listelerde hazır
  `SharedString` veya önceden üretilmiş metin kullanmak gereksiz allocation'ı
  azaltır.
- Tüm satırı monospace yapmak için `.buffer_font(cx)` veya `.inline_code(cx)`;
  yalnızca backtick içindeki parçaları vurgulamak için `.render_code_spans()`
  kullanın.

## LabelLike

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/label_like.rs`
- Export: `ui::LabelLike`
- Prelude: Hayır, `use ui::LabelLike;` ekleyin.
- Preview: `impl Component for LabelLike`

Ne zaman kullanılır:

- `Label` veya `HighlightedLabel` yeterli değilse, ama yine de `LabelCommon`
  renk/boyut/ağırlık/truncation kurallarını koruyan özel bir metin yüzeyi
  gerekiyorsa.
- Birden fazla child element içeren, label gibi davranan küçük inline
  kompozisyonlarda.

Ne zaman kullanılmaz:

- Düz metin için `Label`, arama vurgusu için `HighlightedLabel` daha tutarlı ve
  daha kısıtlıdır.
- Komple özel rich text, editor metni veya selectable text gerekiyorsa GPUI text
  primitive'leri daha uygun olabilir.

Temel API:

- Constructor: `LabelLike::new()`
- `LabelCommon`: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.line_height_style(...)`, `.italic()`, `.underline()`, `.strikethrough()`,
  `.alpha(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.
- Ek builder: `.truncate_start()`
- `ParentElement` implement eder; `.child(...)` ve `.children(...)` alır.
- `LineHeightStyle`: `TextLabel` varsayılan label/buffer line-height davranışı,
  `UiLabel` ise line-height `1` olan kompakt UI etiketi davranışıdır.

Davranış:

- `RenderOnce` implement eder.
- `Label` ailesinin kullandığı iç stil yüzeyidir; UI font weight'i, semantic
  `Color` ve `LabelSize` değerlerini aynı şekilde uygular.
- Serbest child kabul ettiği için tutarsız tipografi üretmek kolaydır; hazır
  label'ların yetmediği durumlarla sınırlayın.

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
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: `impl Component for Headline`

Ne zaman kullanılır:

- Modal başlığı, panel başlığı, onboarding başlığı ve section başlığı gibi görsel
  hiyerarşi kuran kısa metinler için.

Ne zaman kullanılmaz:

- Satır içi metadata, küçük açıklama veya body metni için `Label` kullanın.
- Çok renkli veya rich text başlık gerekiyorsa `Label`, `StyledText` veya özel
  element kompozisyonu daha açıktır.

Temel API:

- Constructor: `Headline::new(text: impl Into<SharedString>)`
- Builder yöntemleri: `.size(HeadlineSize::...)`, `.color(Color::...)`
- Boyutlar: `XSmall`, `Small`, `Medium`, `Large`, `XLarge`.

Davranış:

- `RenderOnce` implement eder.
- UI fontunu kullanır.
- `HeadlineSize` rem tabanlı font size ve sabit headline line-height üretir.

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

Zed içinden kullanım:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension başlıkları ve
  sayfa başlıkları.
- `../zed/crates/ui/src/components/modal.rs`: modal header içinde.
- `../zed/crates/workspace/src/theme_preview.rs`: typography preview alanında.

Dikkat edilecekler:

- Mevcut kaynakta `Headline::color(...)` alanı set eder, ancak `render` içinde
  renk olarak doğrudan `cx.theme().colors().text` kullanılır. Renkli başlık
  davranışına ihtiyaç varsa kaynak değişene kadar `Label` veya özel `div()`
  kompozisyonuyla açık renk uygulayın.

## HighlightedLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/highlighted_label.rs`
- Export: `ui::HighlightedLabel`
- Prelude: Hayır, `use ui::HighlightedLabel;` ekleyin.
- Preview: `impl Component for HighlightedLabel`

Ne zaman kullanılır:

- Fuzzy search, picker, dosya/branch arama sonucu ve filtrelenmiş liste
  satırlarında eşleşen karakterleri vurgulamak için.

Ne zaman kullanılmaz:

- Vurgulanacak aralık yoksa normal `Label` daha basit.
- Vurgu byte pozisyonları yerine semantic span veya rich text gerekiyorsa
  doğrudan `StyledText` kullanmak daha esnek olabilir.

Temel API:

- Constructor: `HighlightedLabel::new(label, highlight_indices)`
- Range constructor: `HighlightedLabel::from_ranges(label, highlight_ranges)`
- Düşük seviye yardımcı:
  `highlight_ranges(text: &str, indices: &[usize], style: HighlightStyle)
  -> Vec<(Range<usize>, HighlightStyle)>`. Ardışık byte indekslerini char
  sınırlarına oturmuş tek bir range içinde birleştirir. `HighlightedLabel`
  bunu içeride kullanır; aynı dönüşümü `StyledText` veya custom rich text
  yüzeylerinde tekrar etmek için import edebilirsiniz.
- Okuma yöntemleri: `.text()`, `.highlight_indices()`
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.italic()`, `.underline()`, `.truncate()`, `.single_line()`.
- Layout yardımcıları: `.flex_1()`, `.flex_none()`, `.flex_grow()`,
  `.flex_shrink()`, `.flex_shrink_0()`.

Davranış:

- `RenderOnce` implement eder.
- Vurgular tema accent text rengiyle çizilir.
- `highlight_indices` UTF-8 byte pozisyonlarıdır. `new(...)`, her pozisyonun
  geçerli char boundary olup olmadığını assert eder.

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

Zed içinden kullanım:

- `../zed/crates/recent_projects/src/recent_projects.rs`: son projelerde proje
  adı eşleşmeleri.
- `../zed/crates/git_ui/src/branch_picker.rs`: branch adı eşleşmeleri.
- `../zed/crates/outline_panel/src/outline_panel.rs`: sembol ve path
  eşleşmeleri.

Dikkat edilecekler:

- `highlight_indices` karakter sırası değil byte offset listesidir. Türkçe veya
  emoji gibi çok byte'lı karakterlerde rasgele indeks üretmeyin; matcher'dan
  gelen byte pozisyonlarını veya `from_ranges` ile geçerli byte aralıklarını
  kullanın.
- `new(...)` geçersiz UTF-8 sınırında panic eden `assert!` içerir. Kullanıcı
  girdisinden üretilen pozisyonları önce doğrulamak gerekir.

## LoadingLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/loading_label.rs`
- Export: `ui::LoadingLabel`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: Doğrudan `impl Component for LoadingLabel` yok.

Ne zaman kullanılır:

- Bir async işlem sürerken metni kademeli gösteren ve sonunda nokta animasyonu
  yapan kısa durum label'ları için.
- "Loading credentials", "Connecting", "Generating commit" gibi tek satırlık
  durumlar için.

Ne zaman kullanılmaz:

- Sadece ikon/spinner gerekiyorsa `SpinnerLabel` veya animasyonlu `Icon`.
- Belirli progress oranı varsa `ProgressBar` veya `CircularProgress`.

Temel API:

- Constructor: `LoadingLabel::new(text)`
- `LabelCommon` builder'ları: `.size(...)`, `.weight(...)`,
  `.line_height_style(...)`, `.truncate()`, `.single_line()`, `.buffer_font(cx)`,
  `.inline_code(cx)`.

Davranış:

- `RenderOnce` implement eder.
- İlk animasyonda metni soldan sağa görünür hale getirir; sonraki animasyonda
  metne `.`, `..`, `...` ekleyerek tekrar eder.
- Render sırasında label rengini `Color::Muted` yapar.

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

Dikkat edilecekler:

- Kaynakta `LoadingLabel` `LabelCommon::color(...)` implement eder, ancak render
  içinde son aşamada `Color::Muted` uygular. Renge güvenmeniz gerekiyorsa normal
  `Label` ve ayrı spinner kompozisyonu kullanın.
- Bu component bir async task başlatmaz; yalnızca görsel animasyon sağlar.

## SpinnerLabel

Kaynak:

- Tanım: `../zed/crates/ui/src/components/label/spinner_label.rs`
- Export: `ui::SpinnerLabel`
- Prelude: Hayır, `use ui::SpinnerLabel;` ekleyin.
- Preview: `impl Component for SpinnerLabel`

Ne zaman kullanılır:

- Kompakt alanlarda metinsiz yükleme göstergesi gerektiğinde.
- Label ile aynı hizalamada, text size'a bağlı spinner gerektiğinde.

Ne zaman kullanılmaz:

- İkon semantiği veya dönen simge gerekiyorsa `Icon::new(IconName::LoadCircle)`
  ve GPUI animasyon helper'ları kullanılabilir.
- Progress oranı biliniyorsa progress bileşenleri daha açıklayıcıdır.

Temel API:

- Constructor: `SpinnerLabel::new()`
- Varyantlar: `SpinnerLabel::dots()`, `.dots_variant()`, `.sand()`,
  `SpinnerLabel::with_variant(SpinnerVariant::...)`
- `SpinnerVariant`: `Dots`, `DotsVariant`, `Sand`.
- `LabelCommon` builder'ları: `.size(...)`, `.color(...)`, `.weight(...)`,
  `.alpha(...)`.

Davranış:

- `RenderOnce` implement eder.
- Unicode frame dizilerini `Animation::new(duration).repeat()` ile döndürür.
- Varsayılan rengi `Color::Muted` olan bir `Label` tabanlıdır.

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
  `../zed/crates/ui/src/components/icon.rs`
- `IconName`: `../zed/crates/icons/src/icons.rs`, `ui::IconName` olarak
  re-export edilir.
- Export: `ui::Icon`, `ui::IconName`, `ui::IconSize`
- Prelude: `Icon`, `IconName`, `IconSize` gelir.
- Preview: `impl Component for Icon`

Ne zaman kullanılır:

- Toolbar, list item, status row, tab, menu ve button içindeki semantik simgeler
  için.
- Tema rengine bağlı tek renk SVG ikonları için.
- Harici ikon teması veya provider SVG'si gerektiğinde `from_path` /
  `from_external_svg`.

Ne zaman kullanılmaz:

- Büyük raster görseller için GPUI `img(...)` / `ImageSource` veya `Avatar` /
  `Vector` gibi daha uygun bileşenler kullanılmalı.
- Simgenin yanında badge/durum gerekiyorsa çıplak `Icon` yerine
  `DecoratedIcon`, `IconWithIndicator` veya ilgili component slot'u düşünülmeli.

Temel API:

- `Icon::new(icon_name)`
- `Icon::from_path(path)`
- `Icon::from_external_svg(svg_path)`
- `.size(IconSize::...)`
- `.color(Color::...)`
- `IconSize`: `Indicator` 10px, `XSmall` 12px, `Small` 14px, `Medium` 16px,
  `XLarge` 48px, `Custom(Rems)`.
- Ölçü helper'ları: `IconSize::rems() -> Rems`,
  `IconSize::square(window, cx) -> Pixels` (icon ve simetrik padding'i içeren
  kare ölçüsü) ve `IconSize::square_components(window, cx) -> (Pixels, Pixels)`
  (icon ölçüsü ve tek taraf padding'i ayrı döner). `IconButtonShape::Square`
  ve custom icon konteyner hizalamalarında işe yarar.
- `IconName::path()` gömülü ikonun `icons/<name>.svg` yolunu döndürür.

Davranış:

- `RenderOnce` implement eder.
- `Icon::new` gömülü SVG kullanır ve rengi `text_color` üzerinden uygular.
- `from_path` için `icons/` ile başlayan yollar gömülü SVG, diğer yollar harici
  raster image olarak ele alınır.
- `from_external_svg` harici SVG path'ini `svg().external_path(...)` ile çizer.

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

Zed içinden kullanım:

- `../zed/crates/remote_connection/src/remote_connection.rs`: warning ve loading
  status satırları.
- `../zed/crates/ai_onboarding/src/agent_api_keys_onboarding.rs`:
  `Icon::new(...)` ve `Icon::from_external_svg(...)` provider ikonları.
- `../zed/crates/editor/src/element.rs`: dosya ve outline ikonları için
  `Icon::from_path(...)`.

Dikkat edilecekler:

- Kullanacağınız `IconName` değerinin `../zed/crates/icons/src/icons.rs` içinde
  bulunduğunu kontrol edin.
- `IconSize::Custom(rems(...))` mümkün olsa da tasarım sistemiyle tutarlılık için
  standart boyutları tercih edin.
- Harici raster path'lerinde SVG recolor davranışı beklemeyin; `from_path`
  `icons/` dışındaki yolu image olarak işler.

## DecoratedIcon ve IconDecoration

Kaynak:

- `DecoratedIcon`: `../zed/crates/ui/src/components/icon/decorated_icon.rs`
- `IconDecoration`, `IconDecorationKind`, `KnockoutIconName`:
  `../zed/crates/ui/src/components/icon/icon_decoration.rs`
- Export: `ui::DecoratedIcon`, `ui::IconDecoration`,
  `ui::IconDecorationKind`
- Prelude: Hayır, ayrıca import edin.
- Preview: `DecoratedIcon` için vardır; `IconDecoration` tek başına preview
  değildir.

Ne zaman kullanılır:

- Bir dosya veya tab ikonunun üstüne hata, devre dışı, silinmiş veya özel durum
  işareti bindirmek için.
- İkon üzerinde küçük `X`, `Dot` veya `Triangle` overlay'i gerektiğinde.

Ne zaman kullanılmaz:

- Basit status noktası yeterliyse `Indicator` veya `IconWithIndicator` daha
  sade olabilir.
- Badge metni veya sayaç gerekiyorsa `CountBadge` gibi bileşenler daha uygun.

Temel API:

- `DecoratedIcon::new(icon, Option<IconDecoration>)`
- `IconDecoration::new(kind, knockout_color, cx)`
- `IconDecorationKind`: `X`, `Dot`, `Triangle`
- `KnockoutIconName`: `XFg`, `XBg`, `DotFg`, `DotBg`, `TriangleFg`,
  `TriangleBg`. Bu enum knockout SVG path'lerini üretir; normal tüketici kodu
  genellikle `IconDecorationKind` ile çalışır.
- Decoration builder'ları: `.kind(...)`, `.color(hsla)`,
  `.knockout_color(hsla)`, `.knockout_hover_color(hsla)`, `.position(point)`,
  `.size(px)`, `.group_name(...)`.

Davranış:

- `DecoratedIcon` relative bir container oluşturur, icon boyutunu container size
  olarak kullanır ve decoration'ı absolute overlay olarak ekler.
- `IconDecoration`, knockout foreground/background SVG çiftini kullanır.
  `knockout_color`, ikonun üzerinde durduğu yüzey rengiyle eşleşmelidir.
- `group_name(...)` verilirse knockout hover rengi group hover üzerinden değişir;
  verilmezse doğrudan hover style uygulanır.

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

Zed içinden kullanım:

- `../zed/crates/tab_switcher/src/tab_switcher.rs`: tab ikonları üzerine durum
  dekorasyonu bindirilir.
- `../zed/crates/zed/src/visual_test_runner.rs`: `ThreadItem` ikon dekorasyonu
  görsel testlerinde kullanılır.

Dikkat edilecekler:

- `IconDecoration::color(...)` `Color` değil `Hsla` bekler; semantik renkten
  üretmek için `Color::Error.color(cx)` gibi çağırın.
- Decoration knockout rengi arka planla eşleşmezse overlay çevresinde istenmeyen
  kenar görünebilir.
- Büyük veya metin içeren durumlar için ikon dekorasyonu yerine satır içinde
  `Indicator`, `CountBadge` veya açıklayıcı `Label` kullanın.

## Metin ve ikon kompozisyon örnekleri

Durum satırı:

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

Arama sonucu:

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

Yükleme satırı:

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

