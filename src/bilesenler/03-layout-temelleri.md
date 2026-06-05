# 3. Layout Temelleri

Layout yardımcıları, GPUI'nin `div()` çağrısının üstüne Zed'de sık kullanılan flex ve ayırıcı kalıplarını ekleyen küçük yapı taşlarıdır. Bunlar tam anlamıyla yüksek seviye bileşen sayılmaz. Daha çok, layout kurarken sürekli tekrar eden stil zincirlerini kısa ve okunur hale getirmek için vardır. İçerik semantiği taşımazlar, kendi başlarına durum yönetmezler; işleri görsel düzeni hızlı ve tutarlı biçimde kurmaktır.

Hangi durumda hangisini seçeceğini düşünürken şu yol haritası işine yarar:

![Layout Yardımcısı Seçimi](assets/layout-yardimcilari.svg)

- Satır düzeni ve dikey eksende otomatik ortalama gerekiyorsa `h_flex()` ilk akla gelen seçenektir.
- Kolon düzeni gerektiğinde `v_flex()`'i kullanırsın.
- Birbirine yakın oturması gereken küçük ve tutarlı boşluklu satır içi gruplar için `h_group*` ailesi daha uygundur.
- Küçük ve tutarlı boşluklu dikey gruplar için `v_group*` benzer rolü dikey yönde üstlenir.
- Bölüm, toolbar veya panel ayrımı için `Divider` doğru araçtır.
- Yalnızca tek seferlik özel bir layout gerekiyorsa, doğrudan `div()` ve GPUI'nin style builder'ları yeterli kalır.

## h_flex ve v_flex

Kaynak:

- Tanım: `ui` crate'i
- Altyapı: `ui` crate'i
- Export: `ui::h_flex`, `ui::v_flex`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanırsın:

- Bileşenleri satır veya kolon içinde hızlıca hizalamak için.
- Buton toolbar'ları, metadata satırları, icon ile label kombinasyonları ve panel içerik düzenleri için en sık başvurduğun iki yardımcıdır.

Ne zaman kullanmazsın:

- Aslında semantik bir bileşen gerekiyorsa (yani bir satır sadece bir layout değil, bir liste öğesi veya bir buton gibi anlam taşıyorsa) `ListItem`, `ButtonLike`, `Tab`, `Modal` gibi daha yüksek seviyeli bileşenler önceliklidir.
- Sadece tek bir stil ihtiyacı varsa, doğrudan `div()` kullanmak okuyucu açısından daha açık bir tercih olabilir; gereksiz bir yardımcı kullanmak yerine niyetini açıkça yazarsın.

Temel API:

- `h_flex() -> Div`
- `v_flex() -> Div`
- Aynı davranışı herhangi bir `Styled` üzerinde `.h_flex()` ve `.v_flex()` metod biçimiyle de kullanabilirsin; yani var olan bir builder zincirine sonradan ekleyebilirsin.

Davranış:

- `h_flex()` kaynakta `div().h_flex()` çağırır.
- `StyledExt::h_flex()` arka planda sırasıyla `.flex()`, `.flex_row()` ve `.items_center()` uygular.
- `v_flex()` kaynakta `div().v_flex()` çağırır.
- `StyledExt::v_flex()` ise `.flex()` ve `.flex_col()` uygular.
- Her iki yardımcı da yalnızca layout stilini ayarlar. Gap, width, overflow ve responsive davranışı ayrıca tanımlarsın; bunlar otomatik olarak verilmez.

İlk örnek, yatay bir durum kümesini aynı satırda toplar:

```rust
use ui::prelude::*;
use ui::Tooltip;

fn arac_cubugu_basligini_render_et(yol: SharedString) -> impl IntoElement {
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
                .child(Label::new(yol).truncate()),
        )
        .child(
            IconButton::new("arac-cubugu-yenile", IconName::RotateCw)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Yenile")),
        )
}
```

Dikkat edeceğin noktalar:

- `h_flex()` varsayılan olarak `items_center()` uygular. Üstten hizalama gerektiğinde bunu `.items_start()` ile override etmen gerekir.
- Uzun metin taşıyan h-flex satırlarında üst elemana `.min_w_0()` ve etiket elemanına `.truncate()` eklemen beklenir; aksi halde flex algoritması metni kısaltmak yerine satırı taşırabilir.
- `v_flex()` kendiliğinden gap eklemez. Dikey boşluğu `.gap_*()` ya da padding ile açıkça kurman gerekir.

## h_group ve v_group

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::h_group_sm`, `ui::h_group`, `ui::h_group_lg`, `ui::h_group_xl`, `ui::v_group_sm`, `ui::v_group`, `ui::v_group_lg`, `ui::v_group_xl`
- Prelude: `ui::prelude::*` içinde otomatik gelir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanırsın:

- Birbirine yakın durması gereken küçük ikon, label, badge veya buton grupları için.
- Tekrarlanan ve kompakt aralık değerlerini aynı yardımcı üzerinden korumak, yani aynı ölçeği farklı yerlerde tek bir kelimeyle ifade etmek için.

Ne zaman kullanmazsın:

- Ana sayfa veya panel yerleşimi için `h_flex()` / `v_flex()` daha açık bir niyet ifadesidir; group yardımcıları o ölçekte boşluk için tasarlanmamıştır.
- Büyük bir bölümde geniş boşluklar gerekiyorsa group yardımcılarındaki aralık değerleri küçük kalır. Bu durumda `.gap_4()` gibi açık ölçekler daha anlaşılır ve daha tutarlı sonuç verir.

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

- `h_group*` yardımcıları `items_center()` eklemez. Satırdaki elemanların dikey hizası bir konu olarak öne çıkıyorsa `.items_center()` veya `.items_start()` çağrılarını elle eklemen gerekir.
- `v_group*` yardımcıları otomatik olarak `flex_col()` ekler; yani dikey istif baştan kurulmuş gelir.
- Yardımcı isimleri aralık ölçeğini doğrudan anlatır: `sm` küçük boşluk, isimsiz varyant varsayılan, `lg` biraz daha büyük, `xl` ise bu yardımcı ailesindeki en geniş ölçeği ifade eder. Daha geniş bir boşluk istiyorsan bu sabit ölçeklere bağlı kalmaz, `.gap_4()` gibi açık bir değer kurarsın.

Örnek:

```rust
use ui::prelude::*;
use ui::Indicator;

fn durum_kumesini_render_et(sayi: usize) -> impl IntoElement {
    h_group()
        .items_center()
        .child(Indicator::dot().color(Color::Success))
        .child(Label::new("Eşitlendi").size(LabelSize::Small).color(Color::Muted))
        .child(Label::new(format!("{sayi} değişiklik")).size(LabelSize::Small).color(Color::Muted))
}
```

İkinci örnek, dar bir üst veri bloğunu dikey istif olarak kurar:

```rust
use ui::prelude::*;

fn ust_veri_istifini_render_et(dal: SharedString, yol: SharedString) -> impl IntoElement {
    v_group_sm()
        .min_w_0()
        .child(Label::new(dal).size(LabelSize::Small).truncate())
        .child(Label::new(yol).size(LabelSize::Small).color(Color::Muted).truncate())
}
```

Dikkat edeceğin noktalar:

- `h_group*` ve `v_group*` bir bileşen değildir; yalnızca düz bir `Div` döndürür.
- Group yardımcılarını iç içe fazla kullanmak yerleşimi zamanla belirsizleştirir. Ana kapsayıcı için `h_flex` veya `v_flex`, küçük alt kümeler için group yardımcı kullanımı, bu hiyerarşinin okunabilir kalmasını sağlar.

## Divider

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Divider`, `ui::DividerColor`, `ui::divider`, `ui::vertical_divider`
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Divider`.

Ne zaman kullanırsın:

- Panel, modal, toolbar veya listede görsel bir ayırıcı çizmek için.
- Aynı kapsayıcı içinde iki içeriği ince bir border rengiyle ayırmak için.
- Kesik çizgili bir ayırıcı gerekiyorsa, dashed constructor'lar ile.

Ne zaman kullanmazsın:

- `ContextMenu` içinde bir ayırıcıya ihtiyaç varsa `ContextMenu::separator()` doğru yüzeydir; menü kendi separator API'sini sağlar.
- Sadece bir boşluk gerekiyorsa divider yerine margin veya gap kullanmak daha doğru bir tercihtir; çünkü divider görsel bir çizgi de getirir.
- Tablo ya da listede satırları ayıran semantik bir ayırıcı gerekiyorsa, ilgili bileşenin kendi border veya ayırıcı davranışını kullanırsın.

Temel API:

- Helper constructor'lar: `divider()`, `vertical_divider()`.
- Associated constructor'lar: `Divider::horizontal()`, `Divider::vertical()`, `Divider::horizontal_dashed()`, `Divider::vertical_dashed()`.
- Builder'lar: `.inset()`, `.color(DividerColor)`.
- `DividerColor`: `Border`, `BorderFaded`, `BorderVariant` (varsayılan).

Davranış:

- Varsayılan renk `DividerColor::BorderVariant`'tır; yani ayırıcı sahnenin içine fazla bağırmaz.
- Solid divider arka planda `Divider::render_solid(base, cx)` ile `bg(...)` uygulanarak çizilir.
- Dashed divider ise `Divider::render_dashed(base)` içinde `canvas(...)` ve `PathBuilder::stroke(px(1.)).dash_array(...)` kullanılarak çizilir; bu yüzden solid'e göre daha pahalı bir çizim yapar.
- Horizontal divider geometri olarak `min_w_0().h_px().w_full()`, vertical divider ise `min_w_0().w_px().h_full()` kullanır.
- `.inset()` çağrısı horizontal divider'da `mx_1p5()`, vertical divider'da `my_1p5()` ekler; yani kenarlardan içeri çekme davranışı sağlar.
- Vertical divider'ın görünür olabilmesi için parent kapsayıcının belirli bir yüksekliği olması veya yüksekliğin içerikten otomatik türemesi gerekir; aksi halde dikey çizgi 0 boy alıp kaybolur.

Örnek:

```rust
use ui::prelude::*;
use ui::{Divider, DividerColor};

fn ayar_bolumunu_render_et() -> impl IntoElement {
    v_flex()
        .gap_3()
        .child(Label::new("Düzenleyici").size(LabelSize::Small).color(Color::Muted))
        .child(Divider::horizontal().color(DividerColor::BorderFaded))
        .child(Label::new("Kaydederken biçimlendir"))
}
```

```rust
use ui::prelude::*;
use ui::{Divider, DividerColor};

fn ayrili_arac_cubugunu_render_et() -> impl IntoElement {
    h_flex()
        .h_8()
        .gap_2()
        .child(Button::new("calistir", "Çalıştır"))
        .child(Divider::vertical().color(DividerColor::Border))
        .child(Button::new("hata-ayikla", "Hata ayıkla"))
}
```

Zed içinden kullanım örnekleri:

- `settings_ui` crate'i: bölüm alt kenarlıkları.
- `recent_projects` crate'i: proje grupları ve araç çubuğu ayrımları.
- `git_ui` crate'i: diff araç çubuğu üzerindeki dikey ayırıcılar.

Dikkat edeceğin noktalar:

- Divider bir yerleşim aracı değildir; tamamen görsel bir ayrım için vardır. Çok sık kullandığında UI hızla kalabalıklaşır; bölüm hiyerarşisini öncelikle aralık ve başlıklar üzerinden kurman daha sade bir sonuç verir, divider'ı en son ihtiyaç haline getirirsin.
- Kesik çizgili divider, kesik çizgi efektini elde edebilmek için özel bir canvas çizimi yapar. Basit bir ayrım yeterliyse düz divider hem daha ucuz hem de görsel olarak daha tutarlı bir seçimdir.

## Layout Kompozisyon Örnekleri

Panel iskeleti, üstte bir başlık satırı, altında bir ayırıcı ve geri kalan alanı dolduran bir içerik bölgesi içerir. Aşağıdaki örnek bu üç parçayı nasıl bir araya getirebileceğini gösterir:

```rust
use ui::prelude::*;
use ui::{Divider, Tooltip};

fn panel_kabugunu_render_et(baslik: SharedString) -> impl IntoElement {
    v_flex()
        .size_full()
        .child(
            h_flex()
                .h_8()
                .px_2()
                .justify_between()
                .child(Label::new(baslik).truncate())
                .child(
                    IconButton::new("panel-kapat", IconName::Close)
                        .icon_size(IconSize::Small)
                        .tooltip(Tooltip::text("Paneli kapat")),
                ),
        )
        .child(Divider::horizontal())
        .child(v_flex().flex_1().min_h_0().p_2().gap_2())
}
```

Satır içi üst veri için ise küçük bir ikon, bir dal adı ve bir önde olma sayacı gibi yan yana duran küçük parçaları bir `h_group_sm()` içinde toplaman yeterlidir. Bu örnek, group yardımcılarının küçük ölçekli satır içi kompozisyonlarda nasıl rahat bir okuma sağladığını ortaya koyar:

```rust
use ui::prelude::*;

fn dal_ust_verisini_render_et(dal: SharedString, onde: usize) -> impl IntoElement {
    h_group_sm()
        .items_center()
        .child(Icon::new(IconName::GitBranch).size(IconSize::Small).color(Color::Muted))
        .child(Label::new(dal).size(LabelSize::Small).truncate())
        .child(Label::new(format!("{onde} önde")).size(LabelSize::Small).color(Color::Muted))
}
```
