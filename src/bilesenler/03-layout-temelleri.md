# 3. Layout Temelleri

Layout yardımcıları, GPUI `div()` üzerine Zed'in sık kullanılan flex ve separator
kalıplarını ekler. Bunlar yüksek seviyeli component değil, layout kurarken tekrar
eden stil dizilerini kısaltan yapı taşlarıdır. İçerik semantiği veya state
yönetimi sağlamazlar.

Genel seçim rehberi:

- Satır düzeni ve dikey ortalama için `h_flex()`.
- Kolon düzeni için `v_flex()`.
- Küçük, tutarlı boşluklu inline gruplar için `h_group*`.
- Küçük, tutarlı boşluklu dikey gruplar için `v_group*`.
- Section, toolbar veya panel ayrımı için `Divider`.
- Sadece tek seferlik özel layout gerekiyorsa doğrudan `div()` + GPUI style
  builder'ları yeterlidir.

## h_flex ve v_flex

Kaynak:

- Tanım: `../zed/crates/ui/src/components/stack.rs`
- Altyapı: `../zed/crates/ui/src/traits/styled_ext.rs`
- Export: `ui::h_flex`, `ui::v_flex`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Bileşenleri satır veya kolon içinde hızlıca hizalamak için.
- Buton toolbar'ları, metadata satırları, icon + label kombinasyonları ve panel
  içerik düzenleri için.

Ne zaman kullanılmaz:

- Semantik component gerekiyorsa `ListItem`, `ButtonLike`, `Tab`, `Modal` gibi
  daha yüksek seviyeli bileşenler önceliklidir.
- Sadece tek stil gerekiyorsa doğrudan `div()` kullanmak daha açık olabilir.

Temel API:

- `h_flex() -> Div`
- `v_flex() -> Div`
- Aynı davranış herhangi bir `Styled` üzerinde `.h_flex()` ve `.v_flex()` olarak
  da kullanılabilir.

Davranış:

- `h_flex()` kaynakta `div().h_flex()` çağırır.
- `StyledExt::h_flex()` sırasıyla `.flex().flex_row().items_center()` uygular.
- `v_flex()` kaynakta `div().v_flex()` çağırır.
- `StyledExt::v_flex()` sırasıyla `.flex().flex_col()` uygular.
- Her ikisi de yalnızca layout stilini ayarlar; gap, width, overflow ve
  responsive davranış ayrıca verilmelidir.

Örnek:

```rust
use ui::prelude::*;
use ui::Tooltip;

fn render_toolbar_title(path: SharedString) -> impl IntoElement {
    h_flex()
        .w_full()
        .min_w_0()
        .justify_between()
        .gap_2()
        .child(
            h_flex()
                .min_w_0()
                .gap_1()
                .child(Icon::new(IconName::File).size(IconSize::Small).color(Color::Muted))
                .child(Label::new(path).truncate()),
        )
        .child(
            IconButton::new("toolbar-refresh", IconName::RotateCw)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Refresh")),
        )
}
```

Dikkat edilecekler:

- `h_flex()` varsayılan olarak `items_center()` uygular. Üstten hizalama
  gerekiyorsa `.items_start()` ile override edin.
- Uzun metin taşıyan h-flex satırlarında parent'a `.min_w_0()`, label'a
  `.truncate()` ekleyin.
- `v_flex()` gap vermez. Dikey boşluğu `.gap_*()` veya padding ile açıkça kurun.

## h_group ve v_group

Kaynak:

- Tanım: `../zed/crates/ui/src/components/group.rs`
- Export: `ui::h_group_sm`, `ui::h_group`, `ui::h_group_lg`,
  `ui::h_group_xl`, `ui::v_group_sm`, `ui::v_group`, `ui::v_group_lg`,
  `ui::v_group_xl`
- Prelude: `ui::prelude::*` içinde gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Birbirine yakın durması gereken küçük ikon, label, badge veya button grupları
  için.
- Tekrarlanan compact spacing değerlerini aynı helper üzerinden korumak için.

Ne zaman kullanılmaz:

- Ana sayfa/panel layout'u için `h_flex()` / `v_flex()` daha açık.
- Büyük section boşlukları için helper spacing'i çok küçüktür; explicit `.gap_4()`
  gibi değerler kullanın.

Temel API:

- `h_group_sm()` -> `div().flex().gap_0p5()`
- `h_group()` -> `div().flex().gap_1()`
- `h_group_lg()` -> `div().flex().gap_1p5()`
- `h_group_xl()` -> `div().flex().gap_2()`
- `v_group_sm()` -> `div().flex().flex_col().gap_0p5()`
- `v_group()` -> `div().flex().flex_col().gap_1()`
- `v_group_lg()` -> `div().flex().flex_col().gap_1p5()`
- `v_group_xl()` -> `div().flex().flex_col().gap_2()`

Davranış:

- `h_group*` helper'ları `items_center()` eklemez. Satırdaki elemanların dikey
  hizası önemliyse `.items_center()` veya `.items_start()` ekleyin.
- `v_group*` helper'ları `flex_col()` ekler.
- Helper isimleri spacing ölçeğini anlatır: `sm`, varsayılan, `lg`, `xl`.

Örnek:

```rust
use ui::prelude::*;
use ui::Indicator;

fn render_status_cluster(count: usize) -> impl IntoElement {
    h_group()
        .items_center()
        .child(Indicator::dot().color(Color::Success))
        .child(Label::new("Synced").size(LabelSize::Small).color(Color::Muted))
        .child(Label::new(format!("{count} changes")).size(LabelSize::Small).color(Color::Muted))
}
```

```rust
use ui::prelude::*;

fn render_metadata_stack(branch: SharedString, path: SharedString) -> impl IntoElement {
    v_group_sm()
        .min_w_0()
        .child(Label::new(branch).size(LabelSize::Small).truncate())
        .child(Label::new(path).size(LabelSize::Small).color(Color::Muted).truncate())
}
```

Dikkat edilecekler:

- `h_group*` ve `v_group*` component değildir; sadece `Div` döndürür.
- Group helper'larını iç içe fazla kullanmak layout'u belirsizleştirir. Ana
  container için `h_flex` / `v_flex`, küçük alt kümeler için group helper
  kullanın.

## Divider

Kaynak:

- Tanım: `../zed/crates/ui/src/components/divider.rs`
- Export: `ui::Divider`, `ui::DividerColor`, `ui::divider`,
  `ui::vertical_divider`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Divider`

Ne zaman kullanılır:

- Panel, modal, toolbar veya listede görsel ayırıcı çizmek için.
- Aynı container içinde iki içeriği ince border rengiyle ayırmak için.
- Dashed separator gerekiyorsa dashed constructor'lar ile.

Ne zaman kullanılmaz:

- `ContextMenu` içinde separator gerekiyorsa `ContextMenu::separator()`.
- Sadece boşluk gerekiyorsa divider yerine margin/gap kullanın.
- Tablo veya listede semantic row separator gerekiyorsa ilgili component'in
  kendi border/separator davranışını tercih edin.

Temel API:

- Helper constructor'lar: `divider()`, `vertical_divider()`
- Associated constructor'lar: `Divider::horizontal()`, `Divider::vertical()`,
  `Divider::horizontal_dashed()`, `Divider::vertical_dashed()`
- Builder'lar: `.inset()`, `.color(DividerColor)`
- `DividerColor`: `Border`, `BorderFaded`, `BorderVariant`

Davranış:

- Varsayılan renk `DividerColor::BorderVariant`.
- Solid divider `bg(...)` ile çizilir.
- Dashed divider `canvas(...)` ve `PathBuilder::stroke(px(1.)).dash_array(...)`
  ile çizilir.
- Horizontal divider `h_px().w_full()`; vertical divider `w_px().h_full()` kullanır.
- `.inset()` horizontal için `mx_1p5()`, vertical için `my_1p5()` uygular.
- Vertical divider'ın görünür olması için parent container'ın yüksekliği belirli
  veya içerikten türetilmiş olmalıdır.

Örnek:

```rust
use ui::prelude::*;
use ui::{Divider, DividerColor};

fn render_settings_section() -> impl IntoElement {
    v_flex()
        .gap_3()
        .child(Label::new("Editor").size(LabelSize::Small).color(Color::Muted))
        .child(Divider::horizontal().color(DividerColor::BorderFaded))
        .child(Label::new("Format on save"))
}
```

```rust
use ui::prelude::*;
use ui::{Divider, DividerColor};

fn render_split_toolbar() -> impl IntoElement {
    h_flex()
        .h_8()
        .gap_2()
        .child(Button::new("run", "Run"))
        .child(Divider::vertical().color(DividerColor::Border))
        .child(Button::new("debug", "Debug"))
}
```

Zed içinden kullanım:

- `../zed/crates/settings_ui/src/settings_ui.rs`: section alt border'ları.
- `../zed/crates/recent_projects/src/recent_projects.rs`: proje grupları ve
  toolbar ayrımları.
- `../zed/crates/git_ui/src/project_diff.rs`: diff toolbar vertical divider'ları.

Dikkat edilecekler:

- Divider layout değil, görsel ayrımdır. Çok sık kullanıldığında UI kalabalık
  görünür; section hiyerarşisi için önce spacing ve başlık kullanın.
- Dashed divider özel canvas çizimi yapar. Basit ayrım için solid divider daha
  ucuz ve tutarlıdır.

## Layout Kompozisyon Örnekleri

Panel iskeleti:

```rust
use ui::prelude::*;
use ui::{Divider, Tooltip};

fn render_panel_shell(title: SharedString) -> impl IntoElement {
    v_flex()
        .size_full()
        .child(
            h_flex()
                .h_8()
                .px_2()
                .justify_between()
                .child(Label::new(title).truncate())
                .child(
                    IconButton::new("panel-close", IconName::Close)
                        .icon_size(IconSize::Small)
                        .tooltip(Tooltip::text("Close panel")),
                ),
        )
        .child(Divider::horizontal())
        .child(v_flex().flex_1().min_h_0().p_2().gap_2())
}
```

Inline metadata:

```rust
use ui::prelude::*;

fn render_branch_metadata(branch: SharedString, ahead: usize) -> impl IntoElement {
    h_group_sm()
        .items_center()
        .child(Icon::new(IconName::GitBranch).size(IconSize::Small).color(Color::Muted))
        .child(Label::new(branch).size(LabelSize::Small).truncate())
        .child(Label::new(format!("ahead {ahead}")).size(LabelSize::Small).color(Color::Muted))
}
```

