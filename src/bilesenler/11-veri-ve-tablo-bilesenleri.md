# 11. Veri ve Tablo Bileşenleri

Zed UI tarafında tabloya ihtiyaç duyulduğunda ana giriş noktası `Table` bileşenidir. Küçük ve sabit satırlı tablolar doğrudan `.row(...)` çağrılarıyla kurarsın. Satır sayısı büyüdüğünde ise tablo, GPUI'nin sanallaştırılmış liste altyapısına bağlanan `.uniform_list(...)` veya `.variable_row_height_list(...)` çağrılarıyla render edersin. Yani tablo tek bir kalıba sıkışmaz; satır modeline göre üç farklı kullanım biçimi sunar.

## GPUI uniform_list ile köprü

`Table::uniform_list(...)` ve Bölüm 9'daki büyük listeler GPUI'nin `uniform_list(...)` elementine bağlanır. Bu element yalnızca görünür satır aralığını render eder; böylece binlerce satırlık listeler gereksiz render maliyeti yaratmadan ekrana basılabilir. Kullanırken şu kurallara dikkat edersin:

- `uniform_list(id, item_count, |range, window, cx| Vec<AnyElement>)` imzası bir id ile bir satır sayısı alır; kalan kısımda yalnızca görünür `range` için satırlar üretilir. Aralık içindeki indeks dizisi `range.map(|indeks| ...)` ifadesiyle dolaşılır.
- Satır yüksekliğinin homojen olması beklersin. İçerik her satırda farklı bir yükseklik gerektiriyorsa, GPUI tarafındaki `list(...)` elementi ve `ListState` ile çalışan `Table::variable_row_height_list(...)` daha uygun bir seçim olur.
- Scroll davranışı için `UniformListScrollHandle` değerini view yapısında saklar ve `.track_scroll(&handle)` ile bağlarsın. Tablo tarafında `Table::interactable(...)` çağrısı kullanıldığında bu, içerideki `TableInteractionState` üzerinden yönetirsin.
- `with_sizing_behavior(ListSizingBehavior::Infer)`, listenin içeriğine göre yükseklik hesaplatır. `Auto` ise liste için sabit bir ölçü hesaplatmaz; boyut kararını üst layout ve flex akışına bırakırsın.
- `with_decoration(...)` slot'una `IndentGuides` ve `StickyItems` gibi süslemeleri bağlarsın; bu süslemelerin `UniformListDecoration` trait'ini implement etmesi gerekir.

![Tablo Satır Modeli Seçimi](assets/tablo-satir-modeli.svg)

Karar matrisi:

| Satır modeli | Kullanım |
| :-- | :-- |
| Sabit, az satır | `List::new()` ile `ListItem::new(...)`; scroll doğrudan üst öğe içinde yaparsın. |
| Sabit yükseklik, çok satır | `uniform_list(id, count, ...)` veya `Table::uniform_list(...)`. |
| Değişken yükseklik, çok satır | `gpui::list(...) + ListState` veya `Table::variable_row_height_list(...)`. |
| Hiyerarşik ya da sticky üst öğe | `uniform_list(...)` ile birlikte `IndentGuides` ve `StickyItems`. |

`gpui::ListAlignment` (`Top`, `Bottom`) ve `ListSizingBehavior` (`Infer`, `Auto`) için tip referansları `gpui` crate'inde tanımlıdır. UI tarafındaki `Table`, sanallaştırılmış satırlarda `Auto` kullanır; `project_panel` gibi ağaç listelerinde `Infer` örneğini görürsün.

Bu ailede tablo kurarken üç karar birlikte düşünülür; biri değiştiğinde diğerleri de genellikle etkilenir:

- **Satır modeli:** sabit bir satır listesi mi, sabit yükseklikli sanallaştırılmış bir liste mi, yoksa değişken yükseklikli sanallaştırılmış bir liste mi.
- **Kolon genişliği modeli:** otomatik, explicit, redistributable veya resizable.
- **Etkileşim modeli:** sadece görsel bir tablo mu, yoksa odak, scroll ve resize durumu tutan interactable bir tablo mu.

## Table

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Table`, `ui::UncheckedTableRow`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Table`.

Ne zaman kullanırsın:

- Header, satır border'ları, striped görünüm ve kolon hizası gereken veri görünümleri için.
- Satır sayısı büyüdüğünde sanallaştırma üzerinden performanslı bir şekilde render almak gerektiğinde.
- Kolon genişliklerinin tek API üzerinden yönetilmesi istendiğinde.

Ne zaman kullanmazsın:

- Tek kolonlu seçim listelerinde `List` ile `ListItem` çok daha uygundur.
- Hiyerarşik veri için `TreeViewItem` doğru yüzeydir.
- Form satırları veya toolbar bilgileri için tablo yerine `h_flex()` veya `v_flex()` ile açık bir layout kurmak genellikle daha okunur olur.

Temel API:

- Constructor: `Table::new(cols)`.
- Header: `.header(headers)`.
- Sabit satır: `.row(items)`.
- Sanallaştırılmış sabit yükseklikli satırlar: `.uniform_list(id, row_count, render_item_fn)`.
- Sanallaştırılmış değişken yükseklikli satırlar: `.variable_row_height_list(row_count, list_state, render_row_fn)`.
- Görsel builder'lar: `.striped()`, `.hide_row_borders()`, `.hide_row_hover()`, `.no_ui_font()`, `.disable_base_style()`.
- Genişlik: `.width(width)`, `.width_config(config)`.
- Sabit ilk kolonlar: `.pin_cols(n)`.
- Etkileşim: `.interactable(&table_interaction_state)`.
- Satır özelleştirme: `.map_row(callback)`.
- Boş durum: `.empty_table_callback(callback)`.

Davranış:

- `cols`, tablo satırlarının ve header'ın beklenen kolon sayısıdır.
- `.header(...)` ve `.row(...)` içine verilen `Vec<T>` içeride bir `TableRow<T>` değerine çevrilir. Eleman sayısı `cols` ile eşleşmezse panic oluşur.
- Varsayılan hücre stili `px_1()`, `py_0p5()`, `whitespace_nowrap()`, `text_ellipsis()` ve `overflow_hidden()` özelliklerini uygular.
- `.disable_base_style()` çağrısı hücre baz stilini kapatır. CSV önizleme gibi her hücrenin kendi layout'unu taşıdığı durumlarda kullanırsın.
- `.row(...)` yalnızca tablo sabit satır modundayken satır ekler. Tablo `.uniform_list(...)` veya `.variable_row_height_list(...)` ile kurulduysa satırlar bir closure üzerinden üretilir.
- `.map_row(...)`, tablonun ürettiği `Stateful<Div>` satır kapsayıcısını alır. Bu sayede seçili satır, hover durumu, sağ tık veya özel tıklama davranışı gibi ek davranışlar eklemek mümkün hale gelir.
- `.pin_cols(n)`, ilk `n` kolonu yatay scroll sırasında görünür tutar. Kaynakta yalnızca `ColumnWidthConfig::Resizable` ile desteklenir; `n == 0` veya `n >= cols` durumunda tablo tek bölümlü normal bir layout'a döner.
- Pinned layout'ta header, satırlar ve resize overlay aynı yatay `ScrollHandle`'ı izler. Pinned kolonlar, scrollable kolonlarla aynı list item içinde render edildiği için değişken yükseklikli satırlarda iki tarafın yüksekliği ayrışmaz. Bu nedenle `.pin_cols(...)` kullanılırken tablonun `.interactable(...)` ile bağlanması pratikte zorunlu hâle gelir.

Minimum örnek:

```rust
use ui::{Table, prelude::*};

fn model_tablosu_render() -> impl IntoElement {
    Table::new(3)
        .width(px(520.))
        .header(vec!["Model", "Sağlayıcı", "Durum"])
        .row(vec!["gpt-5.2", "OpenAI", "Hazır"])
        .row(vec!["claude-sonnet", "Anthropic", "Anahtar gerekiyor"])
        .row(vec!["local-llm", "Ollama", "Çevrim dışı"])
        .striped()
}
```

Karışık hücre içeriği gerekiyorsa, her hücrenin `.into_any_element()` çağrısıyla aynı tipe çevrilmesi yeterlidir:

```rust
use ui::{Button, ButtonStyle, Indicator, Table, prelude::*};

fn paket_satiri_tablosu_render() -> impl IntoElement {
    Table::new(4)
        .width(px(720.))
        .header(vec![
            "Durum".into_any_element(),
            "Paket".into_any_element(),
            "Sürüm".into_any_element(),
            "Eylem".into_any_element(),
        ])
        .row(vec![
            Indicator::dot().color(Color::Success).into_any_element(),
            Label::new("rust-analyzer").truncate().into_any_element(),
            Label::new("1.0.0").color(Color::Muted).into_any_element(),
            Button::new("rust-analyzer-ac", "Aç")
                .style(ButtonStyle::Subtle)
                .into_any_element(),
        ])
}
```

Sabit yükseklikli büyük bir liste için tablo `.uniform_list(...)` ile kurarsın. Burada satır sayısı view içinde tutulur ve sadece görünür aralık render edersin:

```rust
use gpui::Entity;
use ui::{Table, TableInteractionState, prelude::*};

#[derive(Clone)]
struct PaketSatiri {
    ad: SharedString,
    surum: SharedString,
    etkin: bool,
}

struct PaketTablosu {
    tablo_durumu: Entity<TableInteractionState>,
    satirlar: Vec<PaketSatiri>,
}

impl PaketTablosu {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            tablo_durumu: cx.new(|cx| TableInteractionState::new(cx)),
            satirlar: Vec::new(),
        }
    }
}

impl Render for PaketTablosu {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let satirlar = self.satirlar.clone();

        Table::new(3)
            .interactable(&self.tablo_durumu)
            .striped()
            .header(vec!["Paket", "Sürüm", "Durum"])
            .uniform_list("paket-tablosu", satirlar.len(), move |aralik, _window, _cx| {
                aralik
                    .map(|indeks| {
                        let satir = &satirlar[indeks];
                        vec![
                            Label::new(satir.ad.clone()).truncate().into_any_element(),
                            Label::new(satir.surum.clone())
                                .color(Color::Muted)
                                .into_any_element(),
                            Label::new(if satir.etkin { "Etkin" } else { "Devre dışı" })
                                .into_any_element(),
                        ]
                    })
                    .collect()
            })
    }
}
```

Değişken yükseklikli satırlarda ise `ListState` ile birlikte `.variable_row_height_list(...)` kullanırsın. Veri her değiştiğinde durumu `reset(...)` veya uygun bir `splice(...)` ile güncellemen gerekir:

```rust
use gpui::{Entity, ListAlignment, ListState};
use ui::{Table, TableInteractionState, prelude::*};

#[derive(Clone)]
struct GunlukSatiri {
    seviye: SharedString,
    mesaj: SharedString,
}

struct GunlukTablosu {
    tablo_durumu: Entity<TableInteractionState>,
    liste_durumu: ListState,
    satirlar: Vec<GunlukSatiri>,
}

impl GunlukTablosu {
    fn new(satirlar: Vec<GunlukSatiri>, cx: &mut Context<Self>) -> Self {
        Self {
            tablo_durumu: cx.new(|cx| TableInteractionState::new(cx)),
            liste_durumu: ListState::new(satirlar.len(), ListAlignment::Top, px(100.)),
            satirlar,
        }
    }

    fn satirlari_degistir(&mut self, satirlar: Vec<GunlukSatiri>, cx: &mut Context<Self>) {
        self.liste_durumu.reset(satirlar.len());
        self.satirlar = satirlar;
        cx.notify();
    }
}

impl Render for GunlukTablosu {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let satirlar = self.satirlar.clone();

        Table::new(2)
            .interactable(&self.tablo_durumu)
            .header(vec!["Seviye", "Mesaj"])
            .variable_row_height_list(satirlar.len(), self.liste_durumu.clone(), move |indeks, _, _| {
                let satir = &satirlar[indeks];
                vec![
                    Label::new(satir.seviye.clone()).color(Color::Muted).into_any_element(),
                    div()
                        .whitespace_normal()
                        .child(Label::new(satir.mesaj.clone()))
                        .into_any_element(),
                ]
            })
    }
}
```

Zed içinden kullanım örnekleri:

- `ui` crate'i: bileşen önizlemesindeki basit, striped ve karışık içerikli tablo örnekleri.
- `keymap_editor` crate'i: keymap tablosu, `uniform_list`, `TableInteractionState` ve redistributable kolonlar.
- `csv_preview` crate'i: CSV için `ResizableColumnsState`, `disable_base_style()` ve iki farklı render mekanizması. İlk kolon `pin_cols(1)` ile yatay scroll sırasında sabitlenir.
- `edit_prediction_ui` crate'i: metadata için küçük, UI fontu kapatılmış bir tablo.

Dikkat edeceğin noktalar:

- Header ve tüm satırların aynı kolon sayısında olması gerekir.
- Bir `Vec` içinde farklı element tipleri kullanılıyorsa, her hücrenin `.into_any_element()` çağrısıyla aynı tipe çevrilmesi gerekir.
- Büyük veri setlerinde `.row(...)` ile binlerce satır eklemek beklenmez; bu durumda `.uniform_list(...)` veya `.variable_row_height_list(...)` doğru tercihtir.
- `variable_row_height_list` için kullanılan `ListState`, satır sayısıyla senkron tutman gerekir. Veri sayısı değiştiğinde `reset(...)` veya uygun `splice(...)` çağrısı yaparsın.

## TableInteractionState

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::TableInteractionState`.
- Prelude: Hayır; ayrıca import edersin.
- Render modeli: `Entity<TableInteractionState>` olarak view durumunda tutarsın.

Ne zaman kullanırsın:

- Tablo kendi içinde dikey kaydırma yapacaksa.
- Kolon resize handle'ları kullanılacaksa.
- Tablonun odak handle'ı, scroll offset'i veya özel scrollbar ayarı dışarıdan yönetilecekse.

Temel API:

- `TableInteractionState::new(cx)`.
- `.with_custom_scrollbar(scrollbars)`.
- `.scroll_offset() -> Point<Pixels>`.
- `.set_scroll_offset(offset)`.
- `TableInteractionState::listener(&entity, callback)`.

Davranış:

- `focus_handle`, `scroll_handle`, `horizontal_scroll_handle` ve isteğe bağlı bir `custom_scrollbar` taşır.
- `.interactable(&state)` verilmedikçe tablo scroll ve odak durumunu bu entity'ye bağlamaz.
- Yatay scroll, tablo genişliği modeline bağlıdır. Sabit bir toplam genişlik veya `ResizableColumnsState` yoksa, tablo genellikle kapsayıcıya sığacak şekilde davranır.
- `Table::pin_cols(...)` kullanılan bir resizable tabloda aynı `horizontal_scroll_handle`, header'ın ve her satırın scrollable bölümünü kilitli tutmak için kullanırsın.
- `with_custom_scrollbar(...)`, Zed ayarlarından gelen scrollbar davranışını tabloya taşımak için tercih edersin.

Örnek:

```rust
use gpui::Entity;
use ui::{ScrollAxes, Scrollbars, Table, TableInteractionState, prelude::*};

struct DenetimTablosu {
    tablo_durumu: Entity<TableInteractionState>,
}

impl DenetimTablosu {
    fn new(cx: &mut Context<Self>) -> Self {
        let tablo_durumu = cx.new(|cx| {
            TableInteractionState::new(cx)
                .with_custom_scrollbar(Scrollbars::new(ScrollAxes::Both))
        });

        Self { tablo_durumu }
    }

    fn tablo_render(&self) -> impl IntoElement {
        Table::new(2)
            .interactable(&self.tablo_durumu)
            .header(vec!["Zaman", "Olay"])
            .row(vec!["09:42", "Proje açıldı"])
    }
}
```

Zed içinden kullanım örnekleri:

- `keymap_editor` crate'i: özel scrollbar ile interactable bir keymap tablosu.
- `csv_preview` crate'i: CSV önizleme scroll durumu.
- `git_ui` crate'inin `git_graph` modülü: tablo odak handle'ını selection davranışıyla birleştiren örnek.

Dikkat edeceğin noktalar:

- `TableInteractionState` doğrudan bir struct alanı olarak değil, bir `Entity` içinde tutman gerekir.
- Scroll offset elle set ediliyorsa, aynı frame içinde veri sayısının veya liste durumunun değişiklikleriyle çakışmamasına dikkat edersin.
- Focus davranışı gerekiyorsa, `focus_handle` alanı public olduğu için Zed'deki örnekler gibi `tab_index(...)` veya `tab_stop(...)` ile yapılandırılabilir.

## ColumnWidthConfig

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ColumnWidthConfig`, `ui::StaticColumnWidths`.
- Prelude: Hayır; ayrıca import edersin.

Ne zaman kullanırsın:

- Kolonların otomatik, oranlı, explicit veya kullanıcı tarafından yeniden boyutlandırılabilir olmasını seçmek için.
- Sanallaştırılmış bir tabloda yatay sizing davranışını doğru kurmak için.

Temel API:

- `ColumnWidthConfig::auto()`: kolonlar ve tablo otomatik olarak genişler.
- `ColumnWidthConfig::auto_with_table_width(width)`: `.width(width)` ile aynı davranış; tablo genişliği sabit, kolonlar ise otomatik şekillenir.
- `ColumnWidthConfig::explicit(widths)`: her kolon için explicit bir `DefiniteLength` alır.
- `ColumnWidthConfig::redistributable(columns_state)`: toplam alan korunarak kolonlar yeniden paylaştırılır.
- `ColumnWidthConfig::Resizable(columns_state)`: kolonlar mutlak bir genişlik taşır ve tablo toplam genişliği kolon toplamına göre değişir.
- `ColumnWidthConfig::table_width(window, cx)`: tablo kapsayıcısının kullanacağı toplam genişliği döndürür. `Resizable` modunda kolon genişliklerini rem boyutuyla piksele çevirip toplar; diğer modlarda konfigürasyondaki sabit tablo genişliğini kullanır.
- `ColumnWidthConfig::list_horizontal_sizing(window, cx)`: tablo satırlarını taşıyan `uniform_list` için yatay sizing davranışını üretir. Auto, explicit, redistributable ve resizable modların yatay scroll/fill kararını aynı noktadan verir.

Genişlik taşıyıcıları:

| API | Rol |
| :-- | :-- |
| `StaticColumnWidths` | Statik satırlı tabloda kolon genişliğinin otomatik mi (`Auto`) yoksa explicit `TableRow<DefiniteLength>` ile mi geleceğini belirtir. |
| `TableResizeBehavior` | Kolon resize davranışını seçer: `None` resize'ı kapatır, `Resizable` varsayılan minimumla açar, `MinSize(f32)` özel minimum eşik uygular. |

Explicit genişlik örneği:

```rust
use ui::{ColumnWidthConfig, Table, prelude::*};

fn acik_genislikli_tablo_render() -> impl IntoElement {
    Table::new(3)
        .width_config(ColumnWidthConfig::explicit(vec![
            DefiniteLength::Absolute(AbsoluteLength::Pixels(px(96.))),
            DefiniteLength::Fraction(0.35),
            DefiniteLength::Fraction(0.65),
        ]))
        .header(vec!["Tür", "Ad", "Yol"])
        .row(vec!["Dosya", "main.rs", "crates/app/src/main.rs"])
}
```

Dikkat edeceğin noktalar:

- `.width(width)` aslında `ColumnWidthConfig::auto_with_table_width(width)` ifadesinin kısaltmasıdır. Resize gerekiyorsa `.width_config(...)` doğrudan kullanırsın.
- `explicit(widths)` içinde `widths.len()` ile tablo kolon sayısının birbirine eşit olması gerekir.
- `Resizable` için associated bir constructor yoktur; enum varyantı doğrudan `ColumnWidthConfig::Resizable(entity)` biçiminde kullanırsın.
- `Table::pin_cols(n)` yalnızca `ColumnWidthConfig::Resizable(entity)` ile anlamlı ve destekli kullanımdır. `Auto`, `Explicit` ve `Redistributable` modlarında pinned split davranışına güvenmezsin.
- Pinned layout'ta pinned bölümün resize divider'ları yalnızca görsel çizgi olarak render edilir; sürükleme etkileşimi scrollable bölümün divider'larında kalır. Header hücresine çift tıklama ile kolon reset davranışı ise `HeaderResizeInfo` üzerinden çalışmaya devam eder.

## RedistributableColumnsState

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::RedistributableColumnsState`.
- İlgili tipler: `ui::TableResizeBehavior`, `ui::HeaderResizeInfo`.
- Prelude: Hayır; ayrıca import edersin.

Ne zaman kullanırsın:

- Tablo kapsayıcı genişliği korunacak ve kullanıcı yalnızca kolonların birbirine göre oranını değiştirebilecekse.
- Keymap editor ve git graph gibi tabloda toplam alanın sabit kalması gereken yerlerde.
- Aynı tabloda hem oranlı hem mutlak başlangıç genişliklerinin kullanılması gerekiyorsa.

Ne zaman kullanmazsın:

- CSV veya spreadsheet benzeri bir tabloda kullanıcı tek bir kolonu genişletince toplam tablo genişliği de büyümeliyse, `ResizableColumnsState` çok daha uygundur.
- Yalnızca sabit oranlı kolon gerekiyorsa `ColumnWidthConfig::explicit(...)` çok daha basit bir çözümdür.

Temel API:

- `RedistributableColumnsState::new(cols, initial_widths, resize_behavior)`.
- `.cols()`.
- `.initial_widths()`.
- `.preview_widths()`.
- `.resize_behavior()`.
- `.widths_to_render()`.
- `.preview_fractions(rem_size)`.
- `.preview_column_width(column_index, window)`.
- `.cached_container_width()`.
- `.set_cached_container_width(width)`.
- `.commit_preview()`.
- `.reset_column_to_initial_width(column_index, window)`.

Davranış:

- Başlangıç genişlikleri `DefiniteLength` alır. Aynı tabloda `DefiniteLength::Fraction(...)` ile `DefiniteLength::Absolute(...)` birlikte kullanabilirsin.
- Drag sırasında `preview_widths` güncellenir; drop sonrasında `commit_preview()` çağrısıyla kalıcı genişliklere aktarılır.
- `Table` içinde `.interactable(...)` ve `.width_config(ColumnWidthConfig::redistributable(...))` birlikte kullanıldığında resize handle binding'i normal tablo için otomatik olarak yaparsın.
- `TableResizeBehavior::None`, ilgili divider yönünde resize yayılımını engeller.
- `TableResizeBehavior::Resizable`, varsayılan minimum sınırla resize'a izin verir.
- `TableResizeBehavior::MinSize(value)`, redistributable algoritmasında minimum kolon oranı olarak değerlendirilir.
- `TableResizeBehavior::is_resizable()` `None` dışındaki davranışlarda `true` döner. Header hücresinde resize handle çizimi veya cursor seçimi yaparken enum varyantlarını tekrar `match` etmek yerine bu soruyu sorarsın.

Örnek:

```rust
use gpui::Entity;
use ui::{
    ColumnWidthConfig, RedistributableColumnsState, Table, TableInteractionState,
    TableResizeBehavior, prelude::*,
};

struct KisayolTablosu {
    tablo_durumu: Entity<TableInteractionState>,
    kolonlar: Entity<RedistributableColumnsState>,
}

impl KisayolTablosu {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            tablo_durumu: cx.new(|cx| TableInteractionState::new(cx)),
            kolonlar: cx.new(|_cx| {
                RedistributableColumnsState::new(
                    4,
                    vec![
                        DefiniteLength::Absolute(AbsoluteLength::Pixels(px(36.))),
                        DefiniteLength::Fraction(0.42),
                        DefiniteLength::Fraction(0.28),
                        DefiniteLength::Fraction(0.30),
                    ],
                    vec![
                        TableResizeBehavior::None,
                        TableResizeBehavior::Resizable,
                        TableResizeBehavior::Resizable,
                        TableResizeBehavior::Resizable,
                    ],
                )
            }),
        }
    }

    fn tablo_render(&self) -> impl IntoElement {
        Table::new(4)
            .interactable(&self.tablo_durumu)
            .width_config(ColumnWidthConfig::redistributable(self.kolonlar.clone()))
            .header(vec!["", "Eylem", "Tuşlar", "Bağlam"])
            .empty_table_callback(|_, _| Label::new("Kısayol yok").into_any_element())
    }
}
```

Zed içinden kullanım örnekleri:

- `keymap_editor` crate'i: oranlı kolonlar ile resize edilebilir bir keybinding tablosu.
- `git_ui` crate'inin `git_graph` modülü: graph alanı ve commit tablosu aynı redistributable durum ile hizalanır.

Dikkat edeceğin noktalar:

- `cols`, `initial_widths.len()` ve `resize_behavior.len()` değerlerinin birbirine eşit olması gerekir.
- Normal bir `Table` kullanımında `bind_redistributable_columns(...)` ve `render_redistributable_columns_resize_handles(...)` çağırmaya gerek yoktur; `Table` bunu kendi wrapper'ında zaten yapar.
- Aynı kolon durumu farklı görsel bölgelerde paylaşılıyorsa, düşük seviyeli yardımcıları kullanmak gerekir.

## ResizableColumnsState

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ResizableColumnsState`.
- İlgili tipler: `ui::TableResizeBehavior`.
- Prelude: Hayır; ayrıca import edersin.

Ne zaman kullanırsın:

- Her kolonun mutlak genişliği ayrı ayrı değişecekse.
- Kullanıcı bir kolonu büyüttüğünde tablonun toplam genişliği büyümeli ve yatay scroll devreye girmeliyse.
- CSV, spreadsheet veya geniş veri önizlemeleri gibi senaryolar için.

Temel API:

- `ResizableColumnsState::new(cols, initial_widths, resize_behavior)`.
- `.cols()`.
- `.resize_behavior()`.
- `.set_column_configuration(col_idx, width, resize_behavior)`.
- `.reset_column_to_initial_width(col_idx)`.

Davranış:

- Başlangıç genişlikleri `AbsoluteLength` alır.
- Resize edilen kolonun genişliği değişir; komşu kolonlardan oran çalınmaz.
- `ColumnWidthConfig::Resizable(entity)` ile tablo toplam genişliğini kolon genişliklerinin toplamı üzerinden hesaplar.
- `TableResizeBehavior::MinSize(value)` değeri, resizable algoritmasında rem tabanlı bir minimum eşik olarak uygularsın.

Örnek:

```rust
use gpui::Entity;
use ui::{
    ColumnWidthConfig, ResizableColumnsState, Table, TableInteractionState,
    TableResizeBehavior, prelude::*,
};

struct CsvBenzeriTablo {
    tablo_durumu: Entity<TableInteractionState>,
    kolonlar: Entity<ResizableColumnsState>,
}

impl CsvBenzeriTablo {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            tablo_durumu: cx.new(|cx| TableInteractionState::new(cx)),
            kolonlar: cx.new(|_cx| {
                ResizableColumnsState::new(
                    3,
                    vec![
                        AbsoluteLength::Pixels(px(56.)),
                        AbsoluteLength::Pixels(px(180.)),
                        AbsoluteLength::Pixels(px(320.)),
                    ],
                    vec![
                        TableResizeBehavior::None,
                        TableResizeBehavior::Resizable,
                        TableResizeBehavior::MinSize(8.),
                    ],
                )
            }),
        }
    }

    fn tablo_render(&self) -> impl IntoElement {
        Table::new(3)
            .interactable(&self.tablo_durumu)
            .width_config(ColumnWidthConfig::Resizable(self.kolonlar.clone()))
            .pin_cols(1)
            .header(vec!["#", "Ad", "Değer"])
            .row(vec!["1", "dil", "Rust"])
    }
}
```

Zed içinden kullanım örnekleri:

- `csv_preview` crate'i: CSV kolon durumu `ResizableColumnsState` ile tutarsın.
- `csv_preview` crate'i: tablo `ColumnWidthConfig::Resizable(...)` ile render edersin.

Dikkat edeceğin noktalar:

- Bu model yatay scroll üretebilir; bu yüzden tablonun `.interactable(...)` ile bağlanması gerekir.
- Kolon sayısı değişirse, eski durumu güncellemek yerine yeni bir `ResizableColumnsState` oluşturmak çok daha net bir tercih olur.
- `set_column_configuration(...)`, çalışma zamanında tek bir kolonun başlangıç ve mevcut genişliğini birlikte günceller.
- İlk kolonun satır numarası veya seçim sütunu gibi her zaman görünür kalması gerekiyorsa, `ColumnWidthConfig::Resizable(entity)` ile birlikte `Table::pin_cols(n)` kullanırsın. Zed CSV önizlemesi ilk kolonu bu şekilde sabitler. Kullanıcı pinned bölümdeki divider'ı sürükleyemez; boyut değiştirme ihtiyacı scrollable kolonlarda beklenir veya kolon konfigürasyonu durum üzerinden güncellersin.

## TableRow ve UncheckedTableRow

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::table_row::TableRow`.
- Alias: `ui::UncheckedTableRow<T> = Vec<T>`.
- Prelude: Hayır.

Ne zaman kullanırsın:

- Düşük seviye tablo yardımcılarına doğrulanmış bir satır verilmesi gerektiğinde.
- Kolon sayısı değişmezinin tek bir noktada kontrol edilmesi istendiğinde.
- Tablo dışındaki veri motorlarında satırların rectangular biçimde tutulması gerektiğinde.

Temel API:

- `TableRow::from_vec(data, expected_length)`.
- `TableRow::try_from_vec(data, expected_length)`.
- `TableRow::from_element(element, length)`.
- `.cols()`.
- `.get(col)`, `.expect_get(col)`.
- `.as_slice()`, `.into_vec()`.
- `.map(...)`, `.map_ref(...)`, `.map_cloned(...)`.

Davranış:

- `from_vec(...)` uzunluk eşleşmezse panic üretir.
- `try_from_vec(...)`, uzunluk hatasını `Result::Err` olarak döndürür.
- `Table::header(...)`, `Table::row(...)`, `.uniform_list(...)` ve `.variable_row_height_list(...)` public API'sinde `Vec<T>` kabul eder; `TableRow` dönüşümü içeride yaparsın.
- `IntoTableRow` trait'i, `Vec<T>` için tek bir `.into_table_row(expected_length)` yöntemi sağlar; uzunluk eşleşmezse panic üretir. Kaynakta `Table` bunu içeride kullandığı için normal kullanımda import etmeye gerek yoktur. Düşük seviyeli yardımcılara inildiğinde ise `use ui::table_row::IntoTableRow as _;` ifadesiyle çağrılabilir. Doğrulanmış (`Result` döndüren) bir dönüşüm için ise doğrudan `TableRow::try_from_vec(data, expected_length)` kullanılır; `try_into_table_row` adlı bir trait yöntemi yoktur.

Satır doğrulama API'leri:

| API | Rol |
| :-- | :-- |
| `table_row` | `TableRow` ve `IntoTableRow` düşük seviye modülünü taşır; normal `Table` kullanımında doğrudan modüle inmen gerekmez. |
| `IntoTableRow` | `Vec<T>` değerini beklenen kolon sayısıyla doğrulanmış `TableRow<T>` değerine çeviren trait'tir. |

Örnek:

```rust
use ui::{AnyElement, table_row::TableRow};

fn hucreleri_dogrula(hucreler: Vec<AnyElement>, kolon_sayisi: usize) -> Option<TableRow<AnyElement>> {
    TableRow::try_from_vec(hucreler, kolon_sayisi).ok()
}
```

Dikkat edeceğin noktalar:

- Normal `Table` kullanımı sırasında `TableRow` üretmeye gerek yoktur.
- `expect_get(...)`, veri motoru değişmezi bozulduğunda erken hata vermek için uygundur; kullanıcı girdisinden gelen satırlarda `get(...)` daha güvenli bir seçim olur.

## Düşük Seviye Resize ve Render Yardımcıları

Kaynak:

- `render_table_row`: `ui` crate'i
- `render_table_header`: `ui` crate'i
- `TableRenderContext`: `ui` crate'i
- `HeaderResizeInfo`: `ui` crate'i
- `bind_redistributable_columns`: `ui` crate'i
- `render_redistributable_columns_resize_handles`: `ui` crate'i

Ne zaman kullanırsın:

- Tek bir `Table` yeterli değilse; örneğin header, graph alanı ve tablo gövdesi farklı kapsayıcılarda ama aynı kolon durumuyla hizalanacaksa.
- Resize handle'larının tablo dışındaki sibling elemanların üzerine bind edilmesi gerekiyorsa.
- Satır veya header render'ının `Table` dışındaki özel bir layout içinde yeniden kullanılması gerektiğinde.

Ne zaman kullanmazsın:

- Normal bir veri tablosu için bu yardımcılara inmeye gerek yoktur. `Table` zaten header, row, scroll ve resize binding'ini tek bir yerde yönetir.
- Sadece genişlik ayarlamak için `bind_redistributable_columns(...)` çağrılmaz; `ColumnWidthConfig` bu amaç için yeterlidir.

Temel API:

- `TableRenderContext::for_column_widths(column_widths, use_ui_font)`:
  - `column_widths`: `Option<TableRow<Length>>`. `None` verildiğinde hücreler sabit bir genişlik almaz. Redistributable veya resizable bir durum üzerinden geliyorsa `columns_state.read(cx).widths_to_render()` çağrısıyla beslenir.
  - `use_ui_font`: `true` olduğunda hücre içeriği `text_ui(cx)` ile çizilir; `false` olduğunda font ailesi üst öğeden miras alırsın. `Table::no_ui_font()` ile kapatılan davranışla aynıdır. CSV preview monospace bir görünüm için bu değeri `false` verir.
  - `striped`, `show_row_borders`, `show_row_hover`, `total_row_count`, `disable_base_cell_style`, `map_row`, `pinned_cols` ve `h_scroll_handle` alanları, `Default::default()` benzeri varsayılanlarla doldurulur. Özel bir görünüm gerekiyorsa `for_column_widths(...)` çıktısı alan alan değiştirilebilir.
- `render_table_header(headers, table_context, resize_info, entity_id, cx) -> AnyElement`.
- `render_table_row(row_index, items, table_context, window, cx)`.
- `HeaderResizeInfo::from_redistributable(&columns_state, cx)`.
- `HeaderResizeInfo::from_resizable(&columns_state, cx)`.
- `resize_behavior: TableRow<TableResizeBehavior>` public alanı, header hücresinin resizable olup olmadığını okumak için kullanırsın. İlgili kolon durumu public bir alan değildir; reset ve durum güncelleme için `reset_column(...)` çağırırsın.
- `bind_redistributable_columns(container, columns_state)`.
- `render_redistributable_columns_resize_handles(&columns_state, window, cx)`.

Düşük seviye tablo yardımcıları:

| API | Rol |
| :-- | :-- |
| `TableRenderContext` | Header ve satır render'ı için kolon genişlikleri, font seçimi, stripe/border/hover davranışı, pinned kolon ve yatay scroll handle bilgisini taşır. |
| `HeaderResizeInfo` | Header hücresinin resize davranışını ve kolon reset akışını bağlamak için redistributable veya resizable durumdan üretilir. |
| `bind_redistributable_columns` | Redistributable kolon durumunu drag preview ve drop commit davranışıyla kapsayıcıya bağlar. |
| `render_redistributable_columns_resize_handles` | Redistributable kolon divider/handle overlay'lerini üretir. |
| `render_table_header` | Doğrulanmış header hücreleri, render context ve opsiyonel resize bilgisiyle tablo header element'i üretir. |
| `render_table_row` | Satır indeksi, hücreler ve `TableRenderContext` üzerinden tablo gövde satırını render eder. |

Örnek:

```rust
use gpui::Entity;
use ui::{
    HeaderResizeInfo, RedistributableColumnsState, TableRenderContext,
    bind_redistributable_columns, render_redistributable_columns_resize_handles,
    render_table_header, table_row::TableRow, prelude::*,
};

fn ozel_tablo_basligi_render(
    kolonlar: &Entity<RedistributableColumnsState>,
    window: &mut Window,
    cx: &mut App,
) -> impl IntoElement {
    let genislikler = kolonlar.read(cx).widths_to_render();
    let baglam = TableRenderContext::for_column_widths(Some(genislikler), true);
    let resize_bilgisi = HeaderResizeInfo::from_redistributable(kolonlar, cx);

    bind_redistributable_columns(
        div()
            .relative()
            .child(render_table_header(
                TableRow::from_vec(
                    vec![
                        Label::new("Graf").into_any_element(),
                        Label::new("Açıklama").into_any_element(),
                        Label::new("Yazar").into_any_element(),
                    ],
                    3,
                ),
                baglam,
                Some(resize_bilgisi),
                Some(kolonlar.entity_id()),
                cx,
            ))
            .child(render_redistributable_columns_resize_handles(kolonlar, window, cx)),
        kolonlar.clone(),
    )
}
```

Zed içinden kullanım örnekleri:

- `git_ui` crate'inin `git_graph` modülü: graph canvas ve commit tablosu aynı redistributable kolon durumuyla hizalanır; header ve resize handle'ları düşük seviyeli yardımcılarla kurarsın.

Dikkat edeceğin noktalar:

- `bind_redistributable_columns(...)`, drag move sırasında preview width'i günceller ve drop sırasında commit eder.
- `render_redistributable_columns_resize_handles(...)`, kolon durumundan divider'ları üretir; kapsayıcının `relative()` olması handle yerleşimini çok daha öngörülebilir hâle getirir.
- `render_table_header(...)` içinde çift tıklama ile kolon reset davranışı `HeaderResizeInfo` üzerinden bağlanır.
- Header ve row için aynı `TableRenderContext` genişlik modelini kullanman gerekir; aksi halde hücreler hizalanmaz.
- Pinned kolonlu özel bir render akışı kuruluyorsa, `TableRenderContext.pinned_cols` ile `TableRenderContext.h_scroll_handle` birlikte ayarlanmalıdır. Normal `Table::pin_cols(...)` kullanımı bu iki alanı kendi içinde zaten doldurur. Scrollable satır ve header bölümleri `overflow_x_scroll()` ile aynı handle'ı takip eder; ayrıca resize sürükleme koordinatı bu yatay offset'e göre düzeltilir.

## Veri Tablosu Kompozisyon Örnekleri

Boş durumlu küçük bir tabloda `empty_table_callback(...)`, hiç satır yokken kullanıcıya açıklayıcı bir mesaj gösterir:

```rust
use ui::{Table, prelude::*};

fn bos_is_tablosu_render() -> impl IntoElement {
    Table::new(3)
        .width(px(560.))
        .header(vec!["İş", "Durum", "Süre"])
        .empty_table_callback(|_, _| {
            v_flex()
                .p_3()
                .gap_1()
                .child(Label::new("İş yok").color(Color::Muted))
                .child(Label::new("Kuyruğa alınan işler burada görünür").size(LabelSize::Small))
                .into_any_element()
        })
}
```

Satır seçimi için `map_row(...)` ile satır kapsayıcısının üzerinde özel bir görsel durum uygulayabilirsin. Aşağıdaki örnek seçili satıra arka plan rengi atar:

```rust
use ui::{Table, prelude::*};

fn secilebilir_satirlar_render(secili_indeks: Option<usize>) -> impl IntoElement {
    Table::new(2)
        .header(vec!["Ad", "Rol"])
        .row(vec!["Ada", "Yönetici"])
        .row(vec!["Linus", "Bakımcı"])
        .map_row(move |(indeks, satir), _window, cx| {
            satir.when(secili_indeks == Some(indeks), |satir| {
                satir.bg(cx.theme().colors().element_selected)
            })
            .into_any_element()
        })
}
```

Karar rehberi olarak şu kısa özet işe yarar:

- Az satır ve basit bir görünüm gerekiyorsa `Table::new(...).header(...).row(...)` yeterlidir.
- Çok satır ama tek satır yüksekliği varsa `.uniform_list(...)` doğru tercihtir.
- Çok satır ve multiline veya değişken içerik varsa `.variable_row_height_list(...)` kullanırsın.
- Kapsayıcı genişliği sabit kalmalı ama kolon oranları değişmeliyse `RedistributableColumnsState` devreye girer.
- Kolonlar mutlak genişlikte olacak ve yatay scroll oluşabilecekse `ResizableColumnsState` seçersin.
- Header, gövde ve ek görsel bölgeler aynı kolon durumunu paylaşacaksa düşük seviyeli render ve resize yardımcılarına inilir.
