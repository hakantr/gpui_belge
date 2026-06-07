# 10. Tab Bileşenleri

Tab bileşenleri, arayüz üzerinde yatay bir gezinme yüzeyi inşa etmek amacıyla tercih edilir. `Tab` tek bir sekmeyi oluştururken, `TabBar` sekmelerin genelini, sol ile sağ kenarda konumlanan eylem alanlarını (action slots) ve yatay kaydırma (scroll) kapsayıcısını koordine eder. Hangi sekmenin seçili olduğu, aktif indeks değeri, kapatma davranışı ve sekme yerleşimi gibi kararları doğrudan ilgili görünüm (view) durumunda hesaplaman gerekir. Sekme bileşenleri bu yönetim mantığını kendi başlarına yürütmez.

Kullanım senaryolarına göre tercih kıstasları şu şekildedir:

- Yalnızca tekil bir sekme yüzeyi oluşturacaksan `Tab` kullanımı yeterli olur.
- Bir sekme koleksiyonu, sol veya sağ kenar araç çubuğu (toolbar) kontrolleri ve yatay kaydırma alanı bir arada çizeceksen `TabBar` en uygun üst yapıyı sunar.
- Dosya veya düzenleyici sekmelerindeki gibi bitişik kenarlık (border) hizalamalarının kritik olduğu durumlarda, her bir sekme için doğru `TabPosition` değerini ataman zorunludur.
- Sekme içeriğinde ikon, değişiklik durum göstergesi, kapatma veya sabitleme (pin) butonu gibi ek unsurlara ihtiyaç duyduğunda `start_slot(...)` ve `end_slot(...)` yardımcı metotlarından faydalanabilirsin.

## Tab

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Tab`, `ui::TabPosition`, `ui::TabCloseSide`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Tab`.

Tavsiye Edilen Kullanım Alanları:

- Düzenleyici (editor), panel (pane), önizleme paneli veya ayarlar ekranında yatay bir sekme dizilimi tasarlarken.
- Seçilmiş ve seçilmemiş sekmelerin Zed tema renk paletine tam uyum sağlamasını istediğinde.
- Sekmenin sol tarafında bir durum veya ikon, sağ tarafında ise kapatma ya da sabitleme (pin) gibi bir eylem butonunun yer almasını hedeflediğinde.

Tercih Edilmemesi Gereken Durumlar:

- Parçalı kontrol (segmented control) veya mod seçici arayüzler tasarlarken `ToggleButtonGroup` bileşenini kullanman daha doğru bir yaklaşımdır.
- Doğrudan içerik geçişi sağlamayan, sadece belirli araç çubuğu eylemlerini tetikleyen durumlarda standart `Button` ya da `IconButton` yeterli işlevselliği sunar.
- Dikey yönlü gezinme veya hiyerarşik listeleme senaryolarında `ListItem` ya da `TreeViewItem` tercih etmelisin.

Temel API:

- Constructor: `Tab::new(id)`.
- Builder'lar: `.position(TabPosition)`, `.close_side(TabCloseSide)`, `.start_slot(...)`, `.end_slot(...)`, `.toggle_state(bool)`.
- Ölçü yardımcıları: `Tab::content_height(cx)`, `Tab::container_height(cx)`.
- `TabPosition`: `First`, `Middle(Ordering)`, `Last` (`Middle` içindeki `Ordering`, ilgili sekmenin seçili sekmeye göre konumunu temsil eder).
- `TabCloseSide`: `Start`, `End`.
- `InteractiveElement` ve `StatefulInteractiveElement` trait'lerini implement eder. Bu sayede `.on_click(...)`, sürükle-bırak (drag/drop) ve tooltip gibi GPUI etkileşim kurucuları (builder) doğrudan kullanılabilir.

Tab yerleşim enum'ları:

| API | Rol |
| :-- | :-- |
| `TabPosition` | Sekmenin satırdaki ilk, orta veya son konumunu bildirir; `Middle(Ordering)` aktif sekmenin konumuna göre sol/sağ border davranışını belirler. |
| `TabCloseSide` | Kapatma veya aksiyon slot'unun `Start` ya da `End` tarafında görüneceğini seçer. |

Davranış:

- `RenderOnce`, `Toggleable` ve `ParentElement` trait'lerini uygular.
- `toggle_state(true)` çağrısı, aktif sekme renklerini ve kenarlık düzenini devreye sokar.
- `TabPosition`, aktif sekme etrafındaki kenarlıkları tayin eder. `Middle(Ordering)` varyantındaki `Ordering` değeri, ilgili sekmenin seçili sekmeye göre konumunu (sol veya sağ) belirtir. Bu konumsal bilgi, kenarlığın hangi tarafta render edileceğini belirler.
- `close_side(TabCloseSide::Start)` çağrısı, `start` ve `end` alanlarının (slot) yerleşim yönünü değiştirir. Çalışma alanı (workspace) sekmelerinde kapatma butonunun sol veya sağ tarafta konumlandırılmasını bu seçim üzerinden yönetebilirsin.
- Çocuk (child) içerik, `text_color(...)` niteliği tanımlanmış bir yatay esnek kutu (`h_flex`) içinde render edilir.

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

- `workspace` crate'i: Düzenleyici ve panel sekmelerinin kapatma, sürükleme, sabitleme ve sağ tık bağlam menüsü davranışlarıyla birlikte render edilmesi işlemlerinde kullanılır.
- Bileşen önizleme: `ui` crate'i.

Dikkat Edilmesi Gereken Hususlar:

- `Tab` bileşeni, aktif durumdaki sekmeyi kendi başına değiştirmez. Tıklama (click) işleyicisi içerisinde ilgili görünüm durumunu güncellemen ve ardından `cx.notify()` metodunu çağırman gerekir.
- `TabPosition` belirtilmediğinde sistem varsayılan olarak `First` değerini atar. Bu nedenle, çoklu bir sekme çubuğunda her sekme için konumu doğru hesaplaman gerekir; aksi takdirde kenarlıklar görsel olarak tutarsız görünecektir.
- Kapatma butonu gibi `end_slot` içerisine yerleştirilen kontroller için benzersiz ve sabit bir kimlik (id) ataman gerekir; aksi takdirde tıklama olaylarının yanlış elemanlara yönlendirilmesi olasıdır.
- Sekme etiketinin (label) aktif veya pasif metin rengini doğrudan miras almasını istiyorsan, çocuk öğe olarak yalın bir string geçmen yeterlidir. Özel bir etiket şablonu veya kısaltma kullandığında, metin rengini ayrıca kontrol etmen gerekir.
- Her bir sekmeye normal şartlarda sabit ve benzersiz bir kimlik (id) ataman gerekir; böylece sekmeler birbirlerinden net bir şekilde ayrışabilir. Boş veya geçersiz bir kimlik kullanımı desteklenmez; bu tür durumları yalnızca özel görsel vekiller (render proxy) gibi sınırlandırılmış alanlarda son çare olarak değerlendirebilirsin.

## TabBar

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::TabBar`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for TabBar`.

Tavsiye Edilen Kullanım Alanları:

- Birden fazla `Tab` öğesini tek bir sekme çubuğu yüzeyinde bir arada sunmak istediğinde.
- Sekmelerin solunda geri/ileri gezinme geçmişi, sağında ise yeni dosya oluşturma veya ayarlar menüsü gibi araç çubuğu (toolbar) eylemlerini konumlandırman gerektiğinde.
- Sekme listesinin yatay eksende taşma riski bulunduğunda ve kaydırma durumunu takip etmeyi planladığında.

Tercih Edilmemesi Gereken Durumlar:

- Tekil bir parçalı kontrol veya küçük bir çalışma modu seçici için `ToggleButtonGroup` daha uygun bir yapı sunar.
- Dikey yönlü gezinme veya ağaç yapısı gösterimleri için `List` ya da `TreeViewItem` tercih etmelisin.

Temel API:

- Constructor: `TabBar::new(id)`.
- Builder'lar: `.track_scroll(&ScrollHandle)`, `.start_child(...)`, `.start_children(...)`, `.end_child(...)`, `.end_children(...)`.
- Düşük seviyeli değiştirici metotlar: `.start_children_mut() -> &mut SmallVec<[AnyElement; 2]>` ve `.end_children_mut() -> &mut SmallVec<[AnyElement; 2]>`. Bu metotları, kurucu (builder) zinciri dışındaki bir üst durumdan başlangıç veya bitiş slot listesini el ile mutasyona uğratman gerektiğinde kullanabilirsin; ancak standart kompozisyon akışlarında genellikle tercih edilmez.
- `ParentElement` trait'ini implement eder; sekmeler `.child(...)` veya `.children(...)` metotlarıyla orta kısımdaki kaydırma alanına dahil edilir.

Davranış:

- `RenderOnce` trait'ini uygular.
- Başlangıç çocukları (`start_children`) mevcutsa sol tarafta esnemeyen (`flex-none`) bir alan oluşturulur ve bu alanın sekmelere bakan sağ sınırında bir kenarlık render edilir.
- Orta sekme alanı, `overflow_x_scroll()` özelliği etkinleştirilmiş bir yatay esnek kutu (`h_flex`) içerisinde çizilir.
- Bitiş çocukları (`end_children`) mevcutsa sağ tarafta esnemeyen bir alan konumlandırılır ve bu alanın sol sınırında kenarlık çizilir.
- `.track_scroll(...)` çağrısı, sekme kaydırma kapsayıcısına bir kaydırma tutamacı (`ScrollHandle`) bağlar.
- `TabBar`, içerdiği sekmelerin `TabPosition` veya seçilme durumlarını otomatik olarak hesaplamaz; bu veriyi görünüm (view) tarafında senin yönetmen gerekir.

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

- `workspace` crate'i: Tek satırlı, sabitlenmiş/serbest ve çift satırlı sekme çubuğu kompozisyonlarında kullanılır.
- Bileşen önizleme: `ui` crate'i.

Dikkat Edilmesi Gereken Hususlar:

- Başlangıç ve bitiş çocukları sekme kaydırma alanına dahil değildir. Bu nedenle global gezinme ve sekme eylemleri için ideal bir yerleşim sunar; sekmelerin kayma alanıyla karışmadan bağımsız bir bölgede kalması sağlanır.
- Sekmelerin taşma ihtimali varsa, bir `ScrollHandle` değerini görünüm durumunda tutman ve `.track_scroll(...)` metoduyla ilişkilendirmen gerekir.
- Sabitlenmiş (pinned) ve serbest (unpinned) sekmelerin farklı satırlarda gösterilmesi gerektiğinde, iki bağımsız `TabBar` bileşenini bir araya getirerek (compose ederek) kullanabilirsin. Zed içerisindeki çalışma alanı paneli (`Workspace Pane`) tam olarak bu yöntemi kullanmaktadır.

## Tab Kompozisyon Örnekleri

Aşağıdaki örnekte kapatma butonu sol tarafta konumlanmış bir sekme tasarımı yer almaktadır. `TabCloseSide::Start` seçeneğini aktif ettiğinde başlangıç ve bitiş alanlarının görsel yerleşimleri yer değiştirir:

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

Kaydırma tutamacı bağlanmış bir sekme çubuğu örneğinde ise kaydırma hareketini, görünüm durumunda barındırılan bir `ScrollHandle` referansı üzerinden kontrol edebilirsin:

```rust
use gpui::ScrollHandle;
use ui::prelude::*;
use ui::{Tab, TabBar};

struct KaydirilabilirTablar {
    kaydirma_tutamaci: ScrollHandle,
}

impl Render for KaydirilabilirTablar {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        TabBar::new("kaydirilabilir-tablar")
            .track_scroll(&self.kaydirma_tutamaci)
            .child(Tab::new("tab-bir").child("Bir"))
            .child(Tab::new("tab-iki").child("İki"))
    }
}
```
