# 3. Layout Temelleri

Layout yardımcıları, GPUI'nin `div()` çağrısı üstüne Zed'in sık kullandığı
flex ve separator kalıplarını ekleyen küçük katmanlardır. Bunlar tam
anlamıyla bir yüksek seviye component değildir; daha çok layout kurulurken
sürekli tekrarlanan stil dizilerini kısaltmak için var olan yapı taşlarıdır.
İçerik semantiği taşımazlar ve kendi başlarına bir state yönetimi
sağlamazlar; tek işleri görsel düzeni hızlı kurmaktır.

Hangi durumda hangisi tercih edilir sorusu için kabaca şöyle bir yol haritası
çıkarılabilir:

- Satır düzeni ve dikey eksende otomatik ortalama gerekiyorsa `h_flex()` ilk
  akla gelen seçenektir.
- Kolon düzeni gerektiğinde `v_flex()` kullanılır.
- Birbirine yakın oturması gereken küçük ve tutarlı boşluklu inline gruplar
  için `h_group*` ailesi daha uygundur.
- Küçük ve tutarlı boşluklu dikey gruplar için `v_group*` benzer rolü dikey
  yönde üstlenir.
- Section, toolbar veya panel ayrımı için `Divider` doğru araçtır.
- Yalnızca tek seferlik özel bir layout gerekiyorsa, doğrudan `div()` ve
  GPUI'nin style builder'ları yeterli kalır.

## h_flex ve v_flex

Kaynak:

- Tanım: `../zed/crates/ui/src/components/stack.rs`
- Altyapı: `../zed/crates/ui/src/traits/styled_ext.rs`
- Export: `ui::h_flex`, `ui::v_flex`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Bileşenleri satır veya kolon içinde hızlıca hizalamak için.
- Buton toolbar'ları, metadata satırları, icon ile label kombinasyonları ve
  panel içerik düzenleri için en sık başvurulan iki helper'dır.

Ne zaman kullanılmaz:

- Aslında semantik bir component gerekiyorsa (yani bir satır sadece bir
  layout değil, bir liste öğesi veya bir buton gibi anlam taşıyorsa)
  `ListItem`, `ButtonLike`, `Tab`, `Modal` gibi daha yüksek seviyeli
  bileşenler önceliklidir.
- Sadece tek bir stil ihtiyacı varsa, doğrudan `div()` kullanmak okuyucu
  açısından daha açık bir tercih olabilir; gereksiz bir helper kullanmak
  yerine niyet açıkça yazılır.

Temel API:

- `h_flex() -> Div`
- `v_flex() -> Div`
- Aynı davranış herhangi bir `Styled` üzerinde `.h_flex()` ve `.v_flex()`
  metod biçimiyle de kullanılabilir; yani var olan bir builder zincirine
  sonradan eklenebilir.

Davranış:

- `h_flex()` kaynakta `div().h_flex()` çağırır.
- `StyledExt::h_flex()` arka planda sırasıyla `.flex()`, `.flex_row()` ve
  `.items_center()` uygular.
- `v_flex()` kaynakta `div().v_flex()` çağırır.
- `StyledExt::v_flex()` ise `.flex()` ve `.flex_col()` uygular.
- Her iki helper da yalnızca layout stilini ayarlar. Gap, width, overflow ve
  responsive davranış ayrıca tanımlanır; bunlar otomatik olarak verilmez.

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

Dikkat edilecek noktalar:

- `h_flex()` varsayılan olarak `items_center()` uygular. Üstten hizalama
  gerektiğinde bunun `.items_start()` ile override edilmesi gerekir.
- Uzun metin taşıyan h-flex satırlarında parent elemana `.min_w_0()` ve
  label elemanına `.truncate()` eklenmesi beklenir; aksi halde flex algoritması
  metni kısaltmak yerine satırı taşırabilir.
- `v_flex()` kendiliğinden gap eklemez. Dikey boşluğun `.gap_*()` ya da
  padding ile açıkça kurulması gerekir.

## h_group ve v_group

Kaynak:

- Tanım: `../zed/crates/ui/src/components/group.rs`
- Export: `ui::h_group_sm`, `ui::h_group`, `ui::h_group_lg`,
  `ui::h_group_xl`, `ui::v_group_sm`, `ui::v_group`, `ui::v_group_lg`,
  `ui::v_group_xl`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Birbirine yakın durması gereken küçük ikon, label, badge veya buton
  grupları için.
- Tekrarlanan ve kompakt spacing değerlerini aynı helper üzerinden korumak,
  yani aynı ölçeği farklı yerlerde tek bir kelimeyle ifade etmek için.

Ne zaman kullanılmaz:

- Ana sayfa veya panel layout'u için `h_flex()` / `v_flex()` daha açık bir
  niyet ifadesidir; group helper'ları o ölçekte boşluk için tasarlanmaz.
- Büyük bir section'da geniş boşluklar gerekiyorsa, group helper'larındaki
  spacing değerleri çok küçük kalır; bunun yerine `.gap_4()` gibi explicit
  ölçeklerin kullanılması daha tutarlı sonuç verir.

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

- `h_group*` helper'ları `items_center()` eklemez. Satırdaki elemanların
  dikey hizası bir konu olarak öne çıkıyorsa `.items_center()` veya
  `.items_start()` çağrılarının elle eklenmesi gerekir.
- `v_group*` helper'ları otomatik olarak `flex_col()` ekler; yani dikey
  istif baştan kurulmuş gelir.
- Helper isimleri spacing ölçeğini doğrudan anlatır: `sm` küçük boşluk,
  isimsiz varyant varsayılan, `lg` biraz daha büyük, `xl` ise grubun
  içerebileceği en geniş boşluğu ifade eder.

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

Dikkat edilecek noktalar:

- `h_group*` ve `v_group*` bir component değildir; yalnızca düz bir `Div`
  döndürür.
- Group helper'larının iç içe fazla kullanılması layout'u zamanla
  belirsizleştirir. Ana container için `h_flex` veya `v_flex`, küçük alt
  kümeler için group helper kullanımı, bu hiyerarşinin okunabilir kalmasını
  sağlar.

## Divider

Kaynak:

- Tanım: `../zed/crates/ui/src/components/divider.rs`
- Export: `ui::Divider`, `ui::DividerColor`, `ui::divider`,
  `ui::vertical_divider`
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Divider`.

Ne zaman kullanılır:

- Panel, modal, toolbar veya listede görsel bir ayırıcı çizmek için.
- Aynı container içinde iki içeriği ince bir border rengiyle ayırmak için.
- Dashed (kesik çizgili) bir separator gerekiyorsa, dashed constructor'lar
  ile.

Ne zaman kullanılmaz:

- `ContextMenu` içinde bir ayırıcıya ihtiyaç varsa `ContextMenu::separator()`
  doğru yüzeydir; menü kendi separator API'sini sağlar.
- Sadece bir boşluk gerekiyorsa divider yerine margin veya gap kullanmak
  daha doğru bir tercihtir; çünkü divider görsel bir çizgi de getirir.
- Tablo ya da listede satırları ayıran bir semantic separator gerekiyorsa,
  ilgili component'in kendi border veya separator davranışı kullanılır.

Temel API:

- Helper constructor'lar: `divider()`, `vertical_divider()`.
- Associated constructor'lar: `Divider::horizontal()`, `Divider::vertical()`,
  `Divider::horizontal_dashed()`, `Divider::vertical_dashed()`.
- Builder'lar: `.inset()`, `.color(DividerColor)`.
- `DividerColor`: `Border`, `BorderFaded`, `BorderVariant`.

Davranış:

- Varsayılan renk `DividerColor::BorderVariant`'tır; yani ayırıcı sahnenin
  içine fazla bağırmaz.
- Solid divider arka planda `bg(...)` ile çizilir.
- Dashed divider ise `canvas(...)` ve
  `PathBuilder::stroke(px(1.)).dash_array(...)` kullanılarak çizilir; bu
  yüzden solid'e göre daha pahalı bir çizim yapar.
- Horizontal divider geometri olarak `h_px().w_full()`, vertical divider ise
  `w_px().h_full()` kullanır.
- `.inset()` çağrısı horizontal divider'da `mx_1p5()`, vertical divider'da
  `my_1p5()` ekler; yani kenarlardan içeri çekme davranışı sağlar.
- Vertical divider'ın görünür olabilmesi için parent container'ın belirli
  bir yüksekliği olmalı veya yüksekliği içerikten otomatik türetilmelidir;
  aksi halde dikey çizgi 0 boy alıp kaybolur.

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

Zed içinden kullanım örnekleri:

- `../zed/crates/settings_ui/src/settings_ui.rs`: section alt border'ları.
- `../zed/crates/recent_projects/src/recent_projects.rs`: proje grupları ve
  toolbar ayrımları.
- `../zed/crates/git_ui/src/project_diff.rs`: diff toolbar üzerindeki dikey
  divider'lar.

Dikkat edilecek noktalar:

- Divider bir layout aracı değildir; tamamen görsel bir ayrım için vardır.
  Çok sık kullanıldığında UI hızla kalabalıklaşır; section hiyerarşisini
  öncelikle spacing ve başlıklar üzerinden kurmak daha sade bir sonuç
  verir, divider en son ihtiyaç hâline getirilir.
- Dashed divider, kesik çizgi efektini elde edebilmek için özel bir canvas
  çizimi yapar. Basit bir ayrım yeterliyse solid divider hem daha ucuz hem
  de görsel olarak daha tutarlı bir seçimdir.

## Layout Kompozisyon Örnekleri

Panel iskeleti, üstte bir başlık satırı, altında bir ayırıcı ve geri kalan
alanı dolduran bir içerik bölgesi içerir. Aşağıdaki örnek bu üç parçayı
nasıl bir araya getirebileceğini gösterir:

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

Inline metadata için ise küçük bir ikon, bir branch adı ve bir ahead sayacı
gibi yan yana duran küçük parçaları bir `h_group_sm()` içinde toplamak
yeterlidir. Bu örnek, group helper'larının küçük ölçekli inline
kompozisyonlarda nasıl rahat bir okuma sağladığını ortaya koyar:

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
