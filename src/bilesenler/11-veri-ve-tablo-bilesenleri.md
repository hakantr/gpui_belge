# 11. Veri ve Tablo Bileşenleri

Zed UI tarafında tablo ihtiyacı için ana giriş noktası `Table` bileşenidir.
Küçük ve sabit satırlı tabloları doğrudan `.row(...)` ile, büyük tabloları ise
GPUI'nin sanallaştırılmış liste altyapısına bağlanan `.uniform_list(...)` veya
`.variable_row_height_list(...)` ile render eder.

## GPUI uniform_list ile köprü

`Table::uniform_list(...)` ve Bölüm 9'daki büyük listeler aslında GPUI'nin
`uniform_list(...)` elementine bağlanır. Bu element, görünür satır aralığını
parça parça render ederek binlerce satırlı listeleri performans kaybı olmadan
gösterir. Kullanım kuralları:

- `uniform_list(id, item_count, |range, window, cx| Vec<AnyElement>)`: id ve
  satır sayısını alır, kalan kısım yalnızca görünür `range` için satırları
  üretir. Range içindeki indeks dizisi `range.map(|ix| ...)`.
- Satır yüksekliği homojen olmalıdır; içerik her satırda farklı yükseklik
  istiyorsa GPUI `list(...)` elementi ve `ListState` ile çalışan
  `Table::variable_row_height_list(...)` daha uygundur.
- Scroll davranışı için `UniformListScrollHandle` view struct'ında saklanır
  ve `.track_scroll(&handle)` ile bağlanır. `Table::interactable(...)`
  davranışı bunu kendi `TableInteractionState`'inde yönetir.
- `with_sizing_behavior(ListSizingBehavior::Infer)`, listenin içeriğine göre
  yükseklik almasını sağlar; `Fill` parent yüksekliğini kullanır.
- `with_decoration(...)` slotuna `IndentGuides`, `StickyItems` gibi
  decoration'lar bağlanır; bu decorations `UniformListDecoration` trait'ini
  implement etmelidir.

Karar matrisi:

| Satır modeli | Kullanım |
| :-- | :-- |
| Sabit, az satır | `List::new()` + `ListItem::new(...)`; doğrudan parent içinde scroll. |
| Sabit yükseklik, çok satır | `uniform_list(id, count, ...)` veya `Table::uniform_list(...)`. |
| Değişken yükseklik, çok satır | `gpui::list(...) + ListState` veya `Table::variable_row_height_list(...)`. |
| Hiyerarşik / sticky parent | `uniform_list(...)` + `IndentGuides` + `StickyItems`. |

`gpui::ListAlignment` (`Top`, `Bottom`) ve `ListSizingBehavior`
(`Fill`, `Infer`) için tip referansları `gpui` crate'inde tanımlıdır; UI
tarafında bunları kullanan örnekler `crates/keymap_editor`, `crates/csv_preview`
ve `crates/project_panel` içinde yer alır.

Bu ailede üç karar birlikte düşünülmelidir:

- Satır modeli: sabit satır listesi, sabit yükseklikli sanallaştırılmış liste
  veya değişken yükseklikli sanallaştırılmış liste.
- Kolon genişliği modeli: otomatik, explicit, redistributable veya resizable.
- Etkileşim modeli: sadece görsel tablo veya focus/scroll/resize state'i olan
  interactable tablo.

## Table

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::Table`, `ui::UncheckedTableRow`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Table`

Ne zaman kullanılır:

- Header, satır border'ları, striped görünüm ve kolon hizası gereken veri
  görünümleri için.
- Satır sayısı büyüdüğünde sanallaştırma üzerinden performanslı tablo render
  etmek için.
- Kolon genişliklerinin tek API üzerinden yönetilmesini istediğiniz durumlarda.

Ne zaman kullanılmaz:

- Tek kolonlu seçim listelerinde `List` / `ListItem` daha uygundur.
- Hiyerarşik veri için `TreeViewItem` kullanın.
- Form satırları veya toolbar bilgisi için tablo yerine `h_flex()` / `v_flex()`
  ile daha açık layout kurun.

Temel API:

- Constructor: `Table::new(cols)`
- Header: `.header(headers)`
- Sabit satır: `.row(items)`
- Sanallaştırılmış sabit yükseklikli satırlar:
  `.uniform_list(id, row_count, render_item_fn)`
- Sanallaştırılmış değişken yükseklikli satırlar:
  `.variable_row_height_list(row_count, list_state, render_row_fn)`
- Görsel builder'lar: `.striped()`, `.hide_row_borders()`, `.hide_row_hover()`,
  `.no_ui_font()`, `.disable_base_style()`
- Genişlik: `.width(width)`, `.width_config(config)`
- Sabit ilk kolonlar: `.pin_cols(n)`
- Etkileşim: `.interactable(&table_interaction_state)`
- Satır özelleştirme: `.map_row(callback)`
- Boş durum: `.empty_table_callback(callback)`

Davranış:

- `cols`, tablo satırlarının ve header'ın beklenen kolon sayısıdır.
- `.header(...)` ve `.row(...)` içine verilen `Vec<T>`, içeride `TableRow<T>`'a
  çevrilir. Eleman sayısı `cols` ile eşleşmezse panic oluşur.
- Varsayılan hücre stili `px_1()`, `py_0p5()`, `whitespace_nowrap()`,
  `text_ellipsis()` ve `overflow_hidden()` uygular.
- `.disable_base_style()` hücre baz stilini kapatır. CSV önizleme gibi her
  hücrenin kendi layout'unu taşıdığı durumlarda kullanılır.
- `.row(...)`, sadece tablo sabit satır modundayken satır ekler. Tablo
  `.uniform_list(...)` veya `.variable_row_height_list(...)` ile kurulduktan
  sonra satırlar closure üzerinden üretilir.
- `.map_row(...)`, tablonun oluşturduğu `Stateful<Div>` satır container'ını
  alır; seçili satır, hover state'i, sağ tık veya özel click davranışı eklemek
  için uygundur.
- `.pin_cols(n)`, ilk `n` kolonu yatay scroll sırasında görünür tutar.
  Kaynakta yalnızca `ColumnWidthConfig::Resizable` ile desteklenir; `n == 0`
  veya `n >= cols` olduğunda tablo tek bölümlü normal layout'a döner.
- Pinned layout'ta header, satırlar ve resize overlay aynı horizontal
  `ScrollHandle`'ı izler. Bu nedenle `.pin_cols(...)` kullanırken tabloyu
  `.interactable(...)` ile bağlamak pratikte zorunludur.

Minimum örnek:

```rust
use ui::{Table, prelude::*};

fn render_model_table() -> impl IntoElement {
    Table::new(3)
        .width(px(520.))
        .header(vec!["Model", "Provider", "Status"])
        .row(vec!["gpt-5.2", "OpenAI", "Ready"])
        .row(vec!["claude-sonnet", "Anthropic", "Needs key"])
        .row(vec!["local-llm", "Ollama", "Offline"])
        .striped()
}
```

Karışık hücre içeriği:

```rust
use ui::{Button, ButtonStyle, Indicator, Table, prelude::*};

fn render_package_row_table() -> impl IntoElement {
    Table::new(4)
        .width(px(720.))
        .header(vec![
            "State".into_any_element(),
            "Package".into_any_element(),
            "Version".into_any_element(),
            "Action".into_any_element(),
        ])
        .row(vec![
            Indicator::dot().color(Color::Success).into_any_element(),
            Label::new("rust-analyzer").truncate().into_any_element(),
            Label::new("1.0.0").color(Color::Muted).into_any_element(),
            Button::new("open-rust-analyzer", "Open")
                .style(ButtonStyle::Subtle)
                .into_any_element(),
        ])
}
```

Sabit yükseklikli büyük liste:

```rust
use gpui::Entity;
use ui::{Table, TableInteractionState, prelude::*};

#[derive(Clone)]
struct PackageRow {
    name: SharedString,
    version: SharedString,
    enabled: bool,
}

struct PackagesTable {
    table_state: Entity<TableInteractionState>,
    rows: Vec<PackageRow>,
}

impl PackagesTable {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            rows: Vec::new(),
        }
    }
}

impl Render for PackagesTable {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let rows = self.rows.clone();

        Table::new(3)
            .interactable(&self.table_state)
            .striped()
            .header(vec!["Package", "Version", "State"])
            .uniform_list("packages-table", rows.len(), move |range, _window, _cx| {
                range
                    .map(|index| {
                        let row = &rows[index];
                        vec![
                            Label::new(row.name.clone()).truncate().into_any_element(),
                            Label::new(row.version.clone())
                                .color(Color::Muted)
                                .into_any_element(),
                            Label::new(if row.enabled { "Enabled" } else { "Disabled" })
                                .into_any_element(),
                        ]
                    })
                    .collect()
            })
    }
}
```

Değişken yükseklikli satırlar:

```rust
use gpui::{Entity, ListAlignment, ListState};
use ui::{Table, TableInteractionState, prelude::*};

#[derive(Clone)]
struct LogRow {
    level: SharedString,
    message: SharedString,
}

struct LogTable {
    table_state: Entity<TableInteractionState>,
    list_state: ListState,
    rows: Vec<LogRow>,
}

impl LogTable {
    fn new(rows: Vec<LogRow>, cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            list_state: ListState::new(rows.len(), ListAlignment::Top, px(100.)),
            rows,
        }
    }

    fn replace_rows(&mut self, rows: Vec<LogRow>, cx: &mut Context<Self>) {
        self.list_state.reset(rows.len());
        self.rows = rows;
        cx.notify();
    }
}

impl Render for LogTable {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        let rows = self.rows.clone();

        Table::new(2)
            .interactable(&self.table_state)
            .header(vec!["Level", "Message"])
            .variable_row_height_list(rows.len(), self.list_state.clone(), move |index, _, _| {
                let row = &rows[index];
                vec![
                    Label::new(row.level.clone()).color(Color::Muted).into_any_element(),
                    div()
                        .whitespace_normal()
                        .child(Label::new(row.message.clone()))
                        .into_any_element(),
                ]
            })
    }
}
```

Zed içinden kullanım:

- `../zed/crates/ui/src/components/data_table.rs`: component preview içindeki
  basit, striped ve karışık içerikli tablo örnekleri.
- `../zed/crates/keymap_editor/src/keymap_editor.rs`: keymap tablosu,
  `uniform_list`, `TableInteractionState` ve redistributable kolonlar.
- `../zed/crates/csv_preview/src/renderer/render_table.rs`: CSV için
  `ResizableColumnsState`, `disable_base_style()` ve iki farklı render
  mekanizması; ilk kolon `pin_cols(1)` ile yatay scroll sırasında sabitlenir.
- `../zed/crates/edit_prediction_ui/src/edit_prediction_context_view.rs`:
  metadata için küçük, UI fontu kapatılmış tablo.

Dikkat edilecekler:

- Header ve tüm satırlar aynı kolon sayısında olmalıdır.
- `Vec` içinde farklı element tipleri kullanıyorsanız her hücreyi
  `.into_any_element()` ile aynı tipe çevirin.
- Büyük veri setlerinde `.row(...)` ile binlerce satır eklemeyin;
  `.uniform_list(...)` veya `.variable_row_height_list(...)` kullanın.
- `variable_row_height_list` için `ListState` satır sayısıyla senkron tutulmalıdır.
  Veri sayısı değiştiğinde `reset(...)` veya uygun `splice(...)` çağrısı yapın.

## TableInteractionState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::TableInteractionState`
- Prelude: Hayır, ayrıca import edin.
- Render modeli: `Entity<TableInteractionState>` olarak view state'inde tutulur.

Ne zaman kullanılır:

- Tablo kendi içinde dikey kaydırma yapacaksa.
- Kolon resize handle'ları kullanılacaksa.
- Tablo focus handle'ı, scroll offset'i veya özel scrollbar ayarı dışarıdan
  yönetilecekse.

Temel API:

- `TableInteractionState::new(cx)`
- `.with_custom_scrollbar(scrollbars)`
- `.scroll_offset() -> Point<Pixels>`
- `.set_scroll_offset(offset)`
- `TableInteractionState::listener(&entity, callback)`

Davranış:

- `focus_handle`, `scroll_handle`, `horizontal_scroll_handle` ve isteğe bağlı
  `custom_scrollbar` taşır.
- `.interactable(&state)` verilmedikçe tablo scroll/focus state'ini bu entity'ye
  bağlamaz.
- Yatay scroll, tablo genişliği modeline bağlıdır. Sabit toplam genişlik veya
  `ResizableColumnsState` yoksa tablo genellikle container'a sığacak şekilde
  davranır.
- `Table::pin_cols(...)` kullanılan resizable tabloda aynı
  `horizontal_scroll_handle`, header'ın ve her satırın scrollable bölümünü
  kilitli tutmak için kullanılır.
- `with_custom_scrollbar(...)`, Zed ayarlarından gelen scrollbar davranışını
  tabloya taşımak için kullanılır.

Örnek:

```rust
use gpui::Entity;
use ui::{ScrollAxes, Scrollbars, Table, TableInteractionState, prelude::*};

struct AuditTable {
    table_state: Entity<TableInteractionState>,
}

impl AuditTable {
    fn new(cx: &mut Context<Self>) -> Self {
        let table_state = cx.new(|cx| {
            TableInteractionState::new(cx)
                .with_custom_scrollbar(Scrollbars::new(ScrollAxes::Both))
        });

        Self { table_state }
    }

    fn render_table(&self) -> impl IntoElement {
        Table::new(2)
            .interactable(&self.table_state)
            .header(vec!["Time", "Event"])
            .row(vec!["09:42", "Project opened"])
    }
}
```

Zed içinden kullanım:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: custom scrollbar ile
  interactable keymap tablosu.
- `../zed/crates/csv_preview/src/csv_preview.rs`: CSV önizleme scroll state'i.
- `../zed/crates/git_graph/src/git_graph.rs`: tablo focus handle'ını selection
  davranışıyla birleştiren örnek.

Dikkat edilecekler:

- `TableInteractionState` doğrudan struct alanı olarak değil, `Entity` içinde
  tutulmalıdır.
- Scroll offset'i elle set ediyorsanız, aynı frame içinde veri sayısı ve liste
  state'i değişiklikleriyle çakıştırmayın.
- Focus davranışı gerekiyorsa `focus_handle` alanı public olduğu için Zed'deki
  örnekler gibi `tab_index(...)` / `tab_stop(...)` ile yapılandırılabilir.

## ColumnWidthConfig

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::ColumnWidthConfig`, `ui::StaticColumnWidths`
- Prelude: Hayır, ayrıca import edin.

Ne zaman kullanılır:

- Kolonların otomatik, oranlı, explicit veya kullanıcı tarafından yeniden
  boyutlandırılabilir olmasını seçmek için.
- Sanallaştırılmış tabloda yatay sizing davranışını doğru kurmak için.

Temel API:

- `ColumnWidthConfig::auto()`: kolonlar ve tablo otomatik genişler.
- `ColumnWidthConfig::auto_with_table_width(width)`: `.width(width)` ile aynı
  davranış; tablo genişliği sabit, kolonlar otomatik.
- `ColumnWidthConfig::explicit(widths)`: her kolon için explicit
  `DefiniteLength`.
- `ColumnWidthConfig::redistributable(columns_state)`: toplam alan korunarak
  kolonlar yeniden paylaştırılır.
- `ColumnWidthConfig::Resizable(columns_state)`: kolonlar mutlak genişlik taşır,
  tablo toplam genişliği kolon toplamıyla değişir.

Explicit genişlik örneği:

```rust
use ui::{ColumnWidthConfig, Table, prelude::*};

fn render_explicit_width_table() -> impl IntoElement {
    Table::new(3)
        .width_config(ColumnWidthConfig::explicit(vec![
            DefiniteLength::Absolute(AbsoluteLength::Pixels(px(96.))),
            DefiniteLength::Fraction(0.35),
            DefiniteLength::Fraction(0.65),
        ]))
        .header(vec!["Kind", "Name", "Path"])
        .row(vec!["File", "main.rs", "crates/app/src/main.rs"])
}
```

Dikkat edilecekler:

- `.width(width)` sadece `ColumnWidthConfig::auto_with_table_width(width)`
  kısaltmasıdır. Resize gerekiyorsa `.width_config(...)` kullanın.
- `explicit(widths)` içindeki `widths.len()` tablo kolon sayısıyla aynı olmalıdır.
- `Resizable` için associated constructor yoktur; enum varyantı doğrudan
  `ColumnWidthConfig::Resizable(entity)` olarak kullanılır.
- `Table::pin_cols(n)` yalnızca `ColumnWidthConfig::Resizable(entity)` ile
  anlamlıdır; `Auto`, `Explicit` ve `Redistributable` modlarında pinned split
  layout devreye girmez.

## RedistributableColumnsState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/redistributable_columns.rs`
- Export: `ui::RedistributableColumnsState`
- İlgili tipler: `ui::TableResizeBehavior`, `ui::HeaderResizeInfo`
- Prelude: Hayır, ayrıca import edin.

Ne zaman kullanılır:

- Tablo container genişliğini koruyacak, kullanıcı sadece kolonların birbirine
  göre oranını değiştirecekse.
- Keymap editor ve git graph gibi tabloda toplam alan sabit kalmalıysa.
- Oranlı ve mutlak başlangıç genişliklerini aynı tabloda kullanmanız gerekiyorsa.

Ne zaman kullanılmaz:

- CSV veya spreadsheet benzeri tabloda kullanıcı tek kolonu genişletince toplam
  tablo genişliği de büyümeliyse `ResizableColumnsState` kullanın.
- Sadece sabit oranlı kolon gerekiyorsa `ColumnWidthConfig::explicit(...)` daha
  basittir.

Temel API:

- `RedistributableColumnsState::new(cols, initial_widths, resize_behavior)`
- `.cols()`
- `.initial_widths()`
- `.preview_widths()`
- `.resize_behavior()`
- `.widths_to_render()`
- `.preview_fractions(rem_size)`
- `.preview_column_width(column_index, window)`
- `.cached_container_width()`
- `.set_cached_container_width(width)`
- `.commit_preview()`
- `.reset_column_to_initial_width(column_index, window)`

Davranış:

- Başlangıç genişlikleri `DefiniteLength` alır; aynı tabloda
  `DefiniteLength::Fraction(...)` ve `DefiniteLength::Absolute(...)`
  kullanılabilir.
- Drag sırasında `preview_widths` güncellenir, drop sonrasında `commit_preview()`
  ile kalıcı genişliklere aktarılır.
- `Table` içinde `.interactable(...)` ve
  `.width_config(ColumnWidthConfig::redistributable(...))` birlikte
  kullanıldığında resize handle binding'i normal tablo için otomatik yapılır.
- `TableResizeBehavior::None`, ilgili divider yönünde resize yayılımını engeller.
- `TableResizeBehavior::Resizable`, varsayılan minimum sınırla resize'a izin
  verir.
- `TableResizeBehavior::MinSize(value)`, redistributable algoritmada minimum
  kolon oranı olarak kullanılır.

Örnek:

```rust
use gpui::Entity;
use ui::{
    ColumnWidthConfig, RedistributableColumnsState, Table, TableInteractionState,
    TableResizeBehavior, prelude::*,
};

struct KeyBindingTable {
    table_state: Entity<TableInteractionState>,
    columns: Entity<RedistributableColumnsState>,
}

impl KeyBindingTable {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            columns: cx.new(|_cx| {
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

    fn render_table(&self) -> impl IntoElement {
        Table::new(4)
            .interactable(&self.table_state)
            .width_config(ColumnWidthConfig::redistributable(self.columns.clone()))
            .header(vec!["", "Action", "Keystrokes", "Context"])
            .empty_table_callback(|_, _| Label::new("No keybindings").into_any_element())
    }
}
```

Zed içinden kullanım:

- `../zed/crates/keymap_editor/src/keymap_editor.rs`: oranlı kolonlar ve
  resize edilebilir keybinding tablosu.
- `../zed/crates/git_graph/src/git_graph.rs`: graph alanı ve commit tablosu aynı
  redistributable state ile hizalanır.

Dikkat edilecekler:

- `cols`, `initial_widths.len()` ve `resize_behavior.len()` aynı olmalıdır.
- Normal `Table` kullanımında `bind_redistributable_columns(...)` ve
  `render_redistributable_columns_resize_handles(...)` çağırmayın; `Table` bunu
  kendi wrapper'ında yapar.
- Aynı kolon state'ini farklı görsel bölgelerde paylaşıyorsanız, düşük seviye
  helper'ları kullanmanız gerekir.

## ResizableColumnsState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table.rs`
- Export: `ui::ResizableColumnsState`
- İlgili tipler: `ui::TableResizeBehavior`
- Prelude: Hayır, ayrıca import edin.

Ne zaman kullanılır:

- Her kolonun mutlak genişliği ayrı ayrı değişecekse.
- Kullanıcı bir kolonu büyüttüğünde toplam tablo genişliği büyümeli ve yatay
  scroll devreye girmeliyse.
- CSV, spreadsheet veya geniş veri önizlemeleri için.

Temel API:

- `ResizableColumnsState::new(cols, initial_widths, resize_behavior)`
- `.cols()`
- `.resize_behavior()`
- `.set_column_configuration(col_idx, width, resize_behavior)`
- `.reset_column_to_initial_width(col_idx)`

Davranış:

- Başlangıç genişlikleri `AbsoluteLength` alır.
- Resize edilen kolonun genişliği değişir; komşu kolonlardan oran çalınmaz.
- `ColumnWidthConfig::Resizable(entity)` tablo toplam genişliğini kolon
  genişliklerinin toplamından hesaplar.
- `TableResizeBehavior::MinSize(value)`, resizable algoritmada rem tabanlı minimum
  eşik olarak uygulanır.

Örnek:

```rust
use gpui::Entity;
use ui::{
    ColumnWidthConfig, ResizableColumnsState, Table, TableInteractionState,
    TableResizeBehavior, prelude::*,
};

struct CsvLikeTable {
    table_state: Entity<TableInteractionState>,
    columns: Entity<ResizableColumnsState>,
}

impl CsvLikeTable {
    fn new(cx: &mut Context<Self>) -> Self {
        Self {
            table_state: cx.new(|cx| TableInteractionState::new(cx)),
            columns: cx.new(|_cx| {
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

    fn render_table(&self) -> impl IntoElement {
        Table::new(3)
            .interactable(&self.table_state)
            .width_config(ColumnWidthConfig::Resizable(self.columns.clone()))
            .pin_cols(1)
            .header(vec!["#", "Name", "Value"])
            .row(vec!["1", "language", "Rust"])
    }
}
```

Zed içinden kullanım:

- `../zed/crates/csv_preview/src/csv_preview.rs`: CSV kolon state'i
  `ResizableColumnsState` ile tutulur.
- `../zed/crates/csv_preview/src/renderer/render_table.rs`: tablo
  `ColumnWidthConfig::Resizable(...)` ile render edilir.

Dikkat edilecekler:

- Bu model yatay scroll üretebilir; tabloyu `.interactable(...)` ile bağlayın.
- Kolon sayısı değişirse eski state'i güncellemek yerine yeni
  `ResizableColumnsState` oluşturmak daha nettir.
- `set_column_configuration(...)`, runtime'da tek kolonun başlangıç ve mevcut
  genişliğini birlikte günceller.
- İlk kolonun row number veya seçim sütunu gibi her zaman görünür kalması
  gerekiyorsa `ColumnWidthConfig::Resizable(entity)` ile birlikte
  `Table::pin_cols(n)` kullanın. Zed CSV preview artık ilk kolonu bu şekilde
  sabitler.

## TableRow ve UncheckedTableRow

Kaynak:

- Tanım: `../zed/crates/ui/src/components/data_table/table_row.rs`
- Export: `ui::table_row::TableRow`
- Alias: `ui::UncheckedTableRow<T> = Vec<T>`
- Prelude: Hayır.

Ne zaman kullanılır:

- Düşük seviye tablo helper'larına doğrulanmış satır vermeniz gerekiyorsa.
- Kolon sayısı invariant'ını tek noktada kontrol etmek istiyorsanız.
- Tablo dışındaki veri motorlarında satırları rectangular biçimde tutmak
  istiyorsanız.

Temel API:

- `TableRow::from_vec(data, expected_length)`
- `TableRow::try_from_vec(data, expected_length)`
- `TableRow::from_element(element, length)`
- `.cols()`
- `.get(col)`, `.expect_get(col)`
- `.as_slice()`, `.into_vec()`
- `.map(...)`, `.map_ref(...)`, `.map_cloned(...)`

Davranış:

- `from_vec(...)`, uzunluk eşleşmezse panic oluşturur.
- `try_from_vec(...)`, uzunluk hatasını `Result::Err` olarak döndürür.
- `Table::header(...)`, `Table::row(...)`, `.uniform_list(...)` ve
  `.variable_row_height_list(...)` public API'de `Vec<T>` kabul eder; `TableRow`
  dönüşümü içeride yapılır.
- `IntoTableRow` trait'i `Vec<T>` için tek bir
  `.into_table_row(expected_length)` yöntemi sağlar; uzunluk eşleşmezse panic
  eder. Kaynakta `Table` bunu içeride kullandığı için normal kullanımda import
  gerekmez; düşük seviye helper'lara iniyorsanız
  `use ui::table_row::IntoTableRow as _;` ile çağırabilirsiniz. Doğrulanmış
  (`Result` döndüren) dönüşüm için doğrudan
  `TableRow::try_from_vec(data, expected_length)` kullanın; `try_into_table_row`
  trait yöntemi mevcut değildir.

Örnek:

```rust
use ui::{AnyElement, table_row::TableRow};

fn checked_cells(cells: Vec<AnyElement>, cols: usize) -> Option<TableRow<AnyElement>> {
    TableRow::try_from_vec(cells, cols).ok()
}
```

Dikkat edilecekler:

- Normal `Table` kullanımında `TableRow` üretmeniz gerekmez.
- `expect_get(...)`, veri motoru invariant'ı bozulduğunda erken hata vermek için
  uygundur; kullanıcı girdisiyle gelen satırlarda `get(...)` daha güvenlidir.

## Düşük Seviye Resize ve Render Helper'ları

Kaynak:

- `render_table_row`: `../zed/crates/ui/src/components/data_table.rs`
- `render_table_header`: `../zed/crates/ui/src/components/data_table.rs`
- `TableRenderContext`: `../zed/crates/ui/src/components/data_table.rs`
- `HeaderResizeInfo`: `../zed/crates/ui/src/components/redistributable_columns.rs`
- `bind_redistributable_columns`:
  `../zed/crates/ui/src/components/redistributable_columns.rs`
- `render_redistributable_columns_resize_handles`:
  `../zed/crates/ui/src/components/redistributable_columns.rs`

Ne zaman kullanılır:

- Tek `Table` yeterli değilse; örneğin header, graph alanı ve tablo gövdesi farklı
  container'larda ama aynı kolon state'iyle hizalanacaksa.
- Resize handle'larını tablo dışındaki sibling elementlerin üzerine bind etmek
  gerekiyorsa.
- Satır/header render'ını `Table` dışındaki özel bir layout içinde yeniden
  kullanmak istiyorsanız.

Ne zaman kullanılmaz:

- Normal veri tablosu için bu helper'lara inmeyin. `Table`, header, row,
  scroll ve resize binding'ini tek yerde yönetir.
- Sadece genişlik ayarlamak için `bind_redistributable_columns(...)` çağırmayın;
  `ColumnWidthConfig` yeterlidir.

Temel API:

- `TableRenderContext::for_column_widths(column_widths, use_ui_font)`
  - `column_widths`: `Option<TableRow<Length>>`. `None` verirse hücreler
    sabit genişlik almaz; redistributable/resizable bir state'ten geliyorsa
    `columns_state.read(cx).widths_to_render()` çağırın.
  - `use_ui_font`: `true` ise hücre içeriği `text_ui(cx)` ile çizilir; `false`
    ise font ailesi parent'tan miras alınır. `Table::no_ui_font()` ile kapatılan
    davranışın aynısıdır. CSV preview, monospace görünüm için `false` verir.
  - `striped`, `show_row_borders`, `show_row_hover`, `total_row_count`,
    `disable_base_cell_style`, `map_row`, `pinned_cols` ve `h_scroll_handle`
    alanları `Default::default()` benzeri varsayılanlarla doldurulur; özel
    görünüm gerekiyorsa `for_column_widths(...)` çıktısını alan alan
    değiştirebilirsiniz.
- `render_table_header(headers, table_context, resize_info, entity_id, cx) -> AnyElement`
- `render_table_row(row_index, items, table_context, window, cx)`
- `HeaderResizeInfo::from_redistributable(&columns_state, cx)`
- `HeaderResizeInfo::from_resizable(&columns_state, cx)`
  - `resize_behavior: TableRow<TableResizeBehavior>` public alanı header
    hücresinin resizable olup olmadığını okumak içindir. İlgili kolon state'i
    public alan değildir; reset ve state update için `reset_column(...)`
    çağırın.
- `bind_redistributable_columns(container, columns_state)`
- `render_redistributable_columns_resize_handles(&columns_state, window, cx)`

Örnek:

```rust
use gpui::Entity;
use ui::{
    HeaderResizeInfo, RedistributableColumnsState, TableRenderContext,
    bind_redistributable_columns, render_redistributable_columns_resize_handles,
    render_table_header, table_row::TableRow, prelude::*,
};

fn render_custom_table_header(
    columns: &Entity<RedistributableColumnsState>,
    window: &mut Window,
    cx: &mut App,
) -> impl IntoElement {
    let widths = columns.read(cx).widths_to_render();
    let context = TableRenderContext::for_column_widths(Some(widths), true);
    let resize_info = HeaderResizeInfo::from_redistributable(columns, cx);

    bind_redistributable_columns(
        div()
            .relative()
            .child(render_table_header(
                TableRow::from_vec(
                    vec![
                        Label::new("Graph").into_any_element(),
                        Label::new("Description").into_any_element(),
                        Label::new("Author").into_any_element(),
                    ],
                    3,
                ),
                context,
                Some(resize_info),
                Some(columns.entity_id()),
                cx,
            ))
            .child(render_redistributable_columns_resize_handles(columns, window, cx)),
        columns.clone(),
    )
}
```

Zed içinden kullanım:

- `../zed/crates/git_graph/src/git_graph.rs`: graph canvas ve commit tablosu aynı
  redistributable kolon state'iyle hizalanır; header ve resize handle'ları düşük
  seviye helper'larla kurulur.

Dikkat edilecekler:

- `bind_redistributable_columns(...)`, drag move sırasında preview width'i
  günceller ve drop sırasında commit eder.
- `render_redistributable_columns_resize_handles(...)`, kolon state'inden
  divider'ları üretir; container'ın `relative()` olması handle yerleşimini daha
  öngörülebilir yapar.
- `render_table_header(...)` içinde çift tıklama ile kolon reset davranışı
  `HeaderResizeInfo` üzerinden bağlanır.
- Header ve row için aynı `TableRenderContext` genişlik modeli kullanılmalıdır;
  aksi halde hücreler hizalanmaz.
- Pinned kolonlu özel render akışı kuruyorsanız `TableRenderContext.pinned_cols`
  ve `TableRenderContext.h_scroll_handle` birlikte ayarlanmalıdır. Normal
  `Table::pin_cols(...)` kullanımı bu iki alanı kendi içinde doldurur.

## Veri Tablosu Kompozisyon Örnekleri

Boş durumlu küçük tablo:

```rust
use ui::{Table, prelude::*};

fn render_empty_jobs_table() -> impl IntoElement {
    Table::new(3)
        .width(px(560.))
        .header(vec!["Job", "Status", "Duration"])
        .empty_table_callback(|_, _| {
            v_flex()
                .p_3()
                .gap_1()
                .child(Label::new("No jobs").color(Color::Muted))
                .child(Label::new("Queued jobs will appear here").size(LabelSize::Small))
                .into_any_element()
        })
}
```

Satır seçimi için `map_row(...)`:

```rust
use ui::{Table, prelude::*};

fn render_selectable_rows(selected_index: Option<usize>) -> impl IntoElement {
    Table::new(2)
        .header(vec!["Name", "Role"])
        .row(vec!["Ada", "Admin"])
        .row(vec!["Linus", "Maintainer"])
        .map_row(move |(index, row), _window, cx| {
            row.when(selected_index == Some(index), |row| {
                row.bg(cx.theme().colors().element_selected)
            })
            .into_any_element()
        })
}
```

Karar rehberi:

- Az satır, basit görünüm: `Table::new(...).header(...).row(...)`.
- Çok satır, tek satır yüksekliği: `.uniform_list(...)`.
- Çok satır, multiline veya değişken içerik: `.variable_row_height_list(...)`.
- Container genişliği sabit, kolon oranları değişsin: `RedistributableColumnsState`.
- Kolonlar mutlak genişlikli, yatay scroll olabilir: `ResizableColumnsState`.
- Header/gövde/ek görsel bölgeler aynı kolon state'ini paylaşacak:
  düşük seviye render ve resize helper'ları.

