# 10. Tab Bileşenleri

Tab bileşenleri yatay bir gezinme yüzeyi kurmak için kullanırsın. `Tab` tek bir sekmeyi çizer; `TabBar` ise sekmeleri, soldaki ve sağdaki action alanlarını ve yatay scroll kapsayıcısını birlikte düzenler. Seçili tab, aktif indeks, kapatma davranışı ve tab pozisyonu gibi bilgiler view durumu tarafından hesaplanır. Tab bileşenleri bu bilgiyi kendi başına üretmez.

Hangi durumda hangisini seçeceğin için kısa özet:

- Tek bir tab yüzeyi için `Tab` yeterlidir.
- Tab koleksiyonu, soldaki/sağdaki toolbar kontrolleri ve yatay scroll alanı birlikte çizilecekse `TabBar` doğru üst yapıdır.
- Dosya veya editor sekmeleri gibi bitişik border davranışının önemli olduğu durumlarda, her tab için doğru `TabPosition` değerini vermen gerekir.
- Tab içeriğinde icon, değişiklik göstergesi veya kapatma/pin butonu gerekiyorsa `start_slot(...)` ve `end_slot(...)` yardımcıları kullanırsın.

## Tab

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Tab`, `ui::TabPosition`, `ui::TabCloseSide`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Tab`.

Ne zaman kullanırsın:

- Editor, pane, önizleme veya ayar ekranında yatay bir sekme satırı çizilirken.
- Seçili ve seçili olmayan tabların Zed tema renkleriyle uyumlu görünmesi gerektiğinde.
- Tabın solunda bir durum veya icon, sağında kapatma/pin gibi action butonu bulunması istendiğinde.

Ne zaman kullanmazsın:

- Bir segmented control veya mod seçici için `ToggleButtonGroup` daha doğru bir araçtır.
- İçeriği değiştirmeyen basit toolbar eylemleri için `Button` veya `IconButton` yeterlidir.
- Dikey bir gezinme için `ListItem` veya `TreeViewItem` daha uygundur.

Temel API:

- Constructor: `Tab::new(id)`.
- Builder'lar: `.position(TabPosition)`, `.close_side(TabCloseSide)`, `.start_slot(...)`, `.end_slot(...)`, `.toggle_state(bool)`.
- Ölçü yardımcıları: `Tab::content_height(cx)`, `Tab::container_height(cx)`.
- `TabPosition`: `First`, `Middle(Ordering)`, `Last` (`Middle` içindeki `Ordering`, ilgili tabın seçili taba göre konumunu temsil eder).
- `TabCloseSide`: `Start`, `End`.
- `InteractiveElement` ve `StatefulInteractiveElement` implement eder; bu sayede `.on_click(...)`, drag/drop ve tooltip gibi GPUI etkileşim builder'ları doğrudan kullanabilirsin.

Tab yerleşim enum'ları:

| API | Rol |
| :-- | :-- |
| `TabPosition` | Tab'ın satırdaki ilk, orta veya son konumunu bildirir; `Middle(Ordering)` aktif tab'a göre sol/sağ border davranışını taşır. |
| `TabCloseSide` | Close veya aksiyon slot'unun `Start` ya da `End` tarafında görüneceğini seçer. |

Davranış:

- `RenderOnce`, `Toggleable` ve `ParentElement` implement eder.
- `toggle_state(true)`, aktif tab renklerini ve border düzenini seçer.
- `TabPosition` aktif tab çevresindeki border'ları belirler. `Middle(Ordering)` içindeki `Ordering`, ilgili tabın seçili taba göre solda mı yoksa sağda mı olduğunu anlatır; bu bilgi border'ın hangi tarafta görüneceğini etkiler.
- `close_side(TabCloseSide::Start)` çağrısı, start ve end slot'ların görsel tarafını değiştirir. Workspace sekmelerinde kapatma butonunun sol ya da sağ tarafta görünmesi bu seçim üzerinden uygularsın.
- Child içerik, `text_color(...)` atanmış bir `h_flex` içinde çizilir.

Örnek:

```rust
use ui::prelude::*;
use ui::{Tab, TabCloseSide, TabPosition, Tooltip};

fn tab_konumu(indeks: usize, aktif: usize, toplam: usize) -> TabPosition {
    if indeks == 0 {
        TabPosition::First
    } else if indeks + 1 == toplam {
        TabPosition::Last
    } else {
        TabPosition::Middle(indeks.cmp(&aktif))
    }
}

struct EditorTablari {
    aktif: usize,
}

impl EditorTablari {
    fn tab_render(
        &self,
        indeks: usize,
        toplam: usize,
        baslik: &'static str,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        Tab::new(("editor-tab", indeks))
            .position(tab_konumu(indeks, self.aktif, toplam))
            .close_side(TabCloseSide::End)
            .toggle_state(self.aktif == indeks)
            .start_slot(Icon::new(IconName::File).size(IconSize::Small).color(Color::Muted))
            .end_slot(
                IconButton::new(("editor-tab-kapat", indeks), IconName::Close)
                    .icon_size(IconSize::Small)
                    .tooltip(Tooltip::text("Sekmeyi kapat")),
            )
            .child(baslik)
            .on_click(cx.listener(move |this: &mut EditorTablari, _, _, cx| {
                this.aktif = indeks;
                cx.notify();
            }))
    }
}
```

Zed içinden kullanım örnekleri:

- `workspace` crate'i: editor/pane tab render'ı; close side, drag/drop, pinned tab ve sağ tık context menu davranışlarıyla birlikte uygularsın.
- Bileşen önizleme: `ui` crate'i.

Dikkat edeceğin noktalar:

- `Tab`, aktif tabı kendi başına değiştirmez. Click işleyicisi içinde view durumunu günceller, ardından `cx.notify()` çağırırsın.
- `TabPosition` verilmediğinde varsayılan değer `First` olur. Bu yüzden çoklu bir tab bar içinde her tab için doğru pozisyon hesaplanmalıdır; aksi halde border'lar tutarsız görünür.
- Close butonu gibi `end_slot` kontrolleri için ayrı ve sabit bir id kullanılması beklenir; aksi halde tıklamalar yanlış elemana yönlendirilebilir.
- Tab label'ının aktif veya pasif metin rengini doğrudan miras almasını istemek gerekiyorsa, basit bir string child kullanmak yeterlidir. Özel label veya kısaltma gerektiğinde renk davranışını ayrıca kontrol etmen gerekir.
- Bir tab'a normalde sabit ve benzersiz bir id verirsin; çoklu bir listede her tab'ın kendi id'siyle ayrışması beklenir. Boş bir id desteklenen bir kullanım değildir, yalnız özel render proxy'leri gibi sınırlı durumlarda son çare olarak düşünülür.

## TabBar

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::TabBar`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for TabBar`.

Ne zaman kullanırsın:

- Birden fazla `Tab` öğesinin ortak bir tab bar yüzeyinde gösterilmesi istendiğinde.
- Tabların solunda gezinme veya geçmiş, sağında oluşturma veya ayarlar gibi toolbar eylemleri yer alacaksa.
- Tab listesi yatayda taşma riski taşıyorsa ve scroll durumunun takip edilmesi gerekiyorsa.

Ne zaman kullanmazsın:

- Tek bir segment kontrol veya küçük bir mod seçici için `ToggleButtonGroup` çok daha doğru bir tercihtir.
- Dikey bir gezinme veya tree için `List` veya `TreeViewItem` daha uygundur.

Temel API:

- Constructor: `TabBar::new(id)`.
- Builder'lar: `.track_scroll(&ScrollHandle)`, `.start_child(...)`, `.start_children(...)`, `.end_child(...)`, `.end_children(...)`.
- Düşük seviye değiştiriciler: `.start_children_mut() -> &mut SmallVec<[AnyElement; 2]>` ve `.end_children_mut() -> &mut SmallVec<[AnyElement; 2]>`. Bunlar builder zinciri dışında, üst durum içinden start veya end slot listesinin elle değiştirilmesi gerektiğinde kullanırsın. Normal kompozisyonda tercih edilmezler.
- `ParentElement` implement eder; tablar `.child(...)` veya `.children(...)` ile orta scroll alanına eklersin.

Davranış:

- `RenderOnce` implement eder.
- Start children varsa, sol tarafta flex-none bir alan oluşturulur; bu alanın tablara bakan sağ kenarında bir border çizilir.
- Orta tab alanı `overflow_x_scroll()` kullanan bir `h_flex` içinde render edilir.
- End children varsa, sağ tarafta flex-none bir alan oluşturulur; bu alanın tablara bakan sol kenarında bir border çizilir.
- `.track_scroll(...)`, iç tab scroll kapsayıcısına bir scroll handle bağlar.
- TabBar, çocuk tabların `TabPosition` veya seçili durumunu hesaplamaz; bu sorumluluk view tarafına aittir.

Örnek:

```rust
use ui::prelude::*;
use ui::{Tab, TabBar, TabPosition, Tooltip};

fn tab_konumu(indeks: usize, aktif: usize, toplam: usize) -> TabPosition {
    if indeks == 0 {
        TabPosition::First
    } else if indeks + 1 == toplam {
        TabPosition::Last
    } else {
        TabPosition::Middle(indeks.cmp(&aktif))
    }
}

fn editor_tab_bari_render(aktif: usize) -> impl IntoElement {
    let toplam = 3;

    TabBar::new("editor-tab-bari")
        .start_child(
            IconButton::new("geri-git", IconName::ArrowLeft)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Geri")),
        )
        .start_child(
            IconButton::new("ileri-git", IconName::ArrowRight)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("İleri")),
        )
        .child(
            Tab::new("tab-main")
                .position(tab_konumu(0, aktif, toplam))
                .toggle_state(aktif == 0)
                .child("main.rs"),
        )
        .child(
            Tab::new("tab-lib")
                .position(tab_konumu(1, aktif, toplam))
                .toggle_state(aktif == 1)
                .child("lib.rs"),
        )
        .child(
            Tab::new("tab-ayarlar")
                .position(tab_konumu(2, aktif, toplam))
                .toggle_state(aktif == 2)
                .child("ayarlar.json"),
        )
        .end_child(
            IconButton::new("yeni-tab", IconName::Plus)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Yeni sekme")),
        )
}
```

Zed içinden kullanım örnekleri:

- `workspace` crate'i: tek satır, pinned/unpinned ve iki satırlı tab bar kompozisyonları.
- Bileşen önizleme: `ui` crate'i.

Dikkat edeceğin noktalar:

- Start ve end children, tab scroll alanına dahil değildir. Bu yüzden gezinme ve global tab eylemleri için uygundur; tabların kendisiyle karışmadan ayrı bir alanda yaşar.
- Tabların taşması bekleniyorsa, bir `ScrollHandle` değerini view durumunda saklar ve `.track_scroll(...)` ile bağlarsın.
- Pinned ile unpinned tabları ayrı satırlarda göstermek gerekiyorsa, iki ayrı `TabBar` compose edersin. Kaynakta workspace pane tam olarak bu yaklaşımı kullanır.

## Tab Kompozisyon Örnekleri

Aşağıdaki örnek kapatma butonu solda kalan bir tab gösterir. `TabCloseSide::Start` seçildiğinde start slot ile end slot'un görsel tarafları yer değiştirir:

```rust
use ui::prelude::*;
use ui::{Tab, TabCloseSide, TabPosition, Tooltip};

fn soldan_kapatmali_tab_render() -> impl IntoElement {
    Tab::new("onizleme-tab")
        .position(TabPosition::First)
        .close_side(TabCloseSide::Start)
        .toggle_state(true)
        .end_slot(
            IconButton::new("onizleme-tab-kapat", IconName::Close)
                .icon_size(IconSize::Small)
                .tooltip(Tooltip::text("Önizlemeyi kapat")),
        )
        .child("Önizleme")
}
```

Scroll handle bağlanmış bir tab bar örneğinde ise scroll davranışı view durumunda tutulan bir `ScrollHandle` üzerinden yönetilir:

```rust
use gpui::ScrollHandle;
use ui::prelude::*;
use ui::{Tab, TabBar};

struct KaydirilabilirTablar {
    kaydirma_tutamaci: ScrollHandle,
}

impl Render for KaydirilabilirTablar {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        TabBar::new("kaydirilabilir-tablar")
            .track_scroll(&self.kaydirma_tutamaci)
            .child(Tab::new("tab-bir").child("Bir"))
            .child(Tab::new("tab-iki").child("İki"))
    }
}
```
