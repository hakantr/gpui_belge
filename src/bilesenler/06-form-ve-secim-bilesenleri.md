# 6. Form ve Seçim Bileşenleri

Bu bölüm, kullanıcıdan değer alan veya var olan bir ayarı değiştiren kontrolleri anlatır. Butonlardan hemen sonra gelmesinin sebebi de budur: checkbox, switch ve giriş alanları aynı olay modeline yaslanır; ayrıca önceki bölümlerdeki label ve icon düzenini tekrar kullanır. Butonların çalışma şeklini anladıysan, bu kontrollerin arkasındaki fikir tanıdık gelecektir.

Hangi durumda hangisini seçeceğini belirlemek için şu ayrım iş görür:

![Form Kontrolü Seçimi](assets/form-kontrolu-secimi.svg)

- Birbirinden bağımsız çoklu bir seçim varsa `Checkbox` doğru araçtır.
- Bir ayarı aç/kapat anlamı taşıyan tek bir değer için `Switch` daha uygundur.
- Label, açıklama ve switch birlikte düzenli bir tek satır ayar olarak görünecekse `SwitchField` bu üçlüyü tek seferde kurarsın.
- Tek satır metin girişi için ise `ui_input::InputField` kullanırsın.

Bu kontrollerin hepsi için ortak kural şudur: görsel durum ile uygulama durumunu birbirinden ayrı düşünürsün. Checkbox, switch veya giriş alanı yalnızca o anki durumu ekrana yansıtır. Gerçek değeri view durumunda veya uygulama modelinde tutar, işleyici içinde güncellersin. Bu ayrımı net tutmak, sahnenin tutarlı kalmasını sağlar.

## Checkbox

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Checkbox`, `ui::checkbox`, `ui::ToggleStyle`
- Prelude: Hayır; `Checkbox` ve `ToggleStyle` için ayrıca import edersin.
- `ToggleState` ise prelude içinde otomatik gelir.
- Preview: `impl Component for Checkbox`.

Ne zaman kullanırsın:

- Bir listedeki her seçimin diğerlerinden bağımsız olduğu durumlarda.
- Çoklu izin, filtre, staged file ve özellik kabiliyeti gibi birden fazla değerin aynı anda seçilebileceği yapılarda.
- Üst seviye bir seçimin alt öğelerinin yalnızca bir kısmı seçiliyse `ToggleState::Indeterminate` ile bu kısmi durumu göstermek için.

Ne zaman kullanmazsın:

- Yalnızca tek bir ayarı açıp kapatma durumu söz konusuysa `Switch` veya `SwitchField` çok daha açık bir niyet ifade eder.
- Karşılıklı olarak birbirini dışlayan seçenekler için `ToggleButtonGroup`, `DropdownMenu` veya bir menü girdisi daha doğru yüzeydir.
- Sadece pasif bir durum göstergesi gerekiyorsa `Indicator`, `Icon` ya da `.visualization_only(true)` ile etkileşimsizleştirilmiş bir checkbox düşünebilirsin.

Temel API:

- Constructor: `Checkbox::new(id, checked: ToggleState)`.
- Yardımcı constructor: `checkbox(id, toggle_state)`.
- Builder'lar: `.disabled(bool)`, `.placeholder(bool)`, `.fill()`, `.visualization_only(bool)`, `.style(ToggleStyle)`, `.elevation(...)`, `.tooltip(...)`, `.label(...)`, `.label_size(...)`, `.label_color(...)`, `.on_click(...)`, `.on_click_ext(...)`.
- Statik ölçü yardımcısı: `Checkbox::container_size() -> Pixels` checkbox kutusu için kullanılan sabit yan ölçüsünü (`px(20.0)`) döndürür; bir checkbox satırını diğer kontrollerle hizalamak gerektiğinde başvurduğun değerdir.
- `ToggleStyle`: `Ghost`, `ElevationBased(ElevationIndex)`, `Custom(Hsla)`.

Davranış:

- `RenderOnce` implement eder.
- `ToggleState::Selected` için `IconName::Check`, `ToggleState::Indeterminate` için ise `IconName::Dash` ikonunu çizer.
- Click işleyicisine mevcut durum değil, `self.toggle_state.inverse()` gönderirsin. Yani işleyici her zaman hedef durumu alır.
- `ToggleState::Indeterminate.inverse()` çağrısının sonucu `Selected` olur; bu sayede kısmi seçimden tıklama ile tam seçime geçilir.
- `disabled(true)` click işleyicisini devre dışı bırakır.
- `visualization_only(true)` pointer ve hover davranışını kaldırır, ama bileşeni disabled gibi soluk renkle göstermez; yalnızca dokunulamaz hale getirir.

Örnek:

```rust
use ui::prelude::*;
use ui::{Checkbox, Tooltip};

struct GizlilikAyarlari {
    tanilama_paylasimi: bool,
}

impl Render for GizlilikAyarlari {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Checkbox::new("tanilama-paylasimi-checkbox", self.tanilama_paylasimi.into())
            .label("Anonim tanılamaları paylaş")
            .label_size(LabelSize::Small)
            .tooltip(Tooltip::text("Çökme ve performans tanılamalarını iyileştirmeye yardımcı olur."))
            .on_click(cx.listener(|this: &mut GizlilikAyarlari, durum: &ToggleState, _, cx| {
                this.tanilama_paylasimi = durum.selected();
                cx.notify();
            }))
    }
}
```

Zed içinden kullanım örnekleri:

- `workspace` crate'i: güvenlik modalındaki seçim.
- `git_ui` crate'i: staged/unstaged seçimleri.
- `language_tools` crate'i: context menu içinde yer alan özel checkbox girdisi.

Dikkat edeceğin noktalar:

- İşleyiciye gelen durum mevcut durum değil, hedef durumdur. `self.tanilama_paylasimi = durum.selected()` gibi doğrudan uygulama durumuna yazarsın; tekrar tersine çevirmene gerek yoktur.
- Kısmi bir seçim gösteriliyorsa `ToggleState::from_any_and_all(...)` yardımcısını kullanırsan, manuel `if` koşullarına göre çok daha okunabilir bir sonuç alırsın.
- Checkbox bir label'a sahipse, click alanı tüm satıra yayılır. Satır içinde iç içe başka bir tıklanabilir element yer alacaksa, olay yayılımını bilinçli olarak ele alman gerekir.

## Switch

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Switch`, `ui::switch`, `ui::SwitchColor`, `ui::SwitchLabelPosition`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Switch`.

Ne zaman kullanırsın:

- Bir ayarı anında açıp kapatan, iki karşıt durumlu kontrollerde.
- Bir label gerekiyor ama uzun bir açıklama metni gerekmediği durumlarda.
- Toolbar veya kompakt ayar satırlarında.

Ne zaman kullanmazsın:

- Açıklama, tooltip ve switch'ten oluşan düzenli bir ayar satırı kuruluyorsa `SwitchField` daha bütünlüklü bir yüzey sağlar.
- Çoklu bir seçimde checkbox semantiği daha doğrudan bir anlatım sunar.

Temel API:

- Constructor: `Switch::new(id, state: ToggleState)`.
- Yardımcı constructor: `switch(id, toggle_state)`.
- Builder'lar: `.color(SwitchColor)`, `.disabled(bool)`, `.on_click(...)`, `.label(...)`, `.label_position(...)`, `.label_size(...)`, `.full_width(bool)`, `.key_binding(...)`, `.tab_index(...)`.
- `SwitchColor`: `Accent`, `Custom(Hsla)`.
- `SwitchLabelPosition`: `Start`, `End`.

Davranış:

- `ToggleState::Selected` açık, diğer durumlar kapalı görünür.
- Click işleyicisine `self.toggle_state.inverse()` gönderilir; yani Switch da Checkbox gibi hedef durumu taşır.
- `.label(...)` tek başına label'ı çizdirmez; label'ın görünmesi için ayrıca `.label_position(Some(SwitchLabelPosition::Start))` veya `.label_position(Some(SwitchLabelPosition::End))` verirsin.
- `full_width(true)` switch ile label'ı satır içinde iki uca doğru yayar; böylece label solda, switch sağda görünür.
- `tab_index(...)` verildiğinde switch odak görünür bir border kazanır ve klavye odak sırasına dahil olur.

Örnek:

```rust
use ui::prelude::*;
use ui::{Switch, SwitchLabelPosition};

struct EditorAyarlari {
    otomatik_kaydet: bool,
}

impl Render for EditorAyarlari {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        Switch::new("otomatik-kaydet-switch", self.otomatik_kaydet.into())
            .label("Otomatik kaydet")
            .label_position(Some(SwitchLabelPosition::Start))
            .full_width(true)
            .on_click(cx.listener(|this: &mut EditorAyarlari, durum: &ToggleState, _, cx| {
                this.otomatik_kaydet = durum.selected();
                cx.notify();
            }))
    }
}
```

Dikkat edeceğin noktalar:

- `ToggleState::Indeterminate`, switch için ayrı bir görsel ara durum üretmez. Switch açık/kapalı anlamı taşıdığı için durumun çoğunlukla `bool` üzerinden üretilmesi daha tutarlı bir tercihtir.
- Disabled bir switch, dış kapsayıcıda pointer cursor'ı tamamen kaldırmaz. Kullanıcıya neden disabled olduğunu anlatmak gerekiyorsa satıra kısa bir açıklama veya tooltip eklemek bu boşluğu kapatır.

## SwitchField

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::SwitchField`
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for SwitchField`.

Ne zaman kullanırsın:

- Ayar ekranlarında label, açıklama ve switch'in bir arada gösterileceği durumlarda.
- Tek satırda sağda switch, solda metinsel bağlam isteyen seçeneklerde.
- Bir tooltip ikonuyla ek bilgi verilmesi gereken ayarlarda.

Ne zaman kullanmazsın:

- Yalnızca kompakt bir switch gerekiyorsa `Switch` daha sade bir yüzey sunar.
- Birden fazla bağımsız seçim varsa bir `Checkbox` listesi daha doğru bir ifade biçimidir.

Temel API:

- Constructor: `SwitchField::new(id, label, description, toggle_state, on_click)`.
- `label`: `Option<impl Into<SharedString>>`.
- `description`: `Option<SharedString>`.
- `toggle_state`: `impl Into<ToggleState>`.
- Builder'lar: `.description(...)`, `.disabled(bool)`, `.color(...)`, `.tooltip(...)`, `.tab_index(...)`.

Davranış:

- `RenderOnce` implement eder.
- Kapsayıcının kendisine yapılan tıklama ile iç switch'e yapılan tıklama, aynı `on_click` geri çağrısını hedef durum ile çağırır; yani satırın herhangi bir yerine tıklamak da switch'i toggle eder.
- Tooltip verildiğinde label'ın yanında bir `IconButton::new("tooltip_button", IconName::Info)` render edersin. Bu ikonun click işleyicisi boştur; yani bilgi ikonuna tıklamak switch'i toggle etmez, yalnızca bilgi göstergesi olarak durur.
- Açıklama verildiğinde, muted renkli bir label olarak çizersin.

Örnek:

```rust
use ui::prelude::*;
use ui::{SwitchField, Tooltip};

struct AsistanAyarlari {
    hizli_mod: bool,
}

impl Render for AsistanAyarlari {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        SwitchField::new(
            "hizli-mod",
            Some("Hızlı mod"),
            Some("Rutin düzenlemelerde daha hızlı yanıtları tercih et.".into()),
            self.hizli_mod,
            cx.listener(|this: &mut AsistanAyarlari, durum: &ToggleState, _, cx| {
                this.hizli_mod = durum.selected();
                cx.notify();
            }),
        )
        .tooltip(Tooltip::text("Bu ayar yeni isteklerin davranışını değiştirir."))
    }
}
```

Dikkat edeceğin noktalar:

- `SwitchField`, tam genişlikte bir ayar satırı davranışı kurarsın. Toolbar gibi dar alanlarda bu fazla yer kaplar; orada doğrudan `Switch` tercih edersin.
- Tooltip yalnızca label varlığında görsel bir ikonla birlikte çizilir; label'sız kullanımda tooltip görünmez.

Ortak `ToggleState` modeli:

| Varyant | Anlam | Not |
| :-- | :-- | :-- |
| `Unselected` | Kapalı / seçili değil | `Default` varyantıdır; `false.into()` bu değeri üretir |
| `Indeterminate` | Kısmi seçim | Checkbox'ta görsel ara durum üretir; switch'te ayrı bir ara durum beklenmez |
| `Selected` | Açık / seçili | `true.into()` bu değeri üretir |

Yardımcılar: `.inverse()`, `ToggleState::from_any_and_all(any_checked, all_checked)`, `.selected()`, `From<bool>`. Bunlardan `from_any_and_all`, alt seçimlerin sayısına göre üst durumun otomatik olarak doğru varyanta oturmasını sağlar.

Form ve toggle yardımcı API'leri:

| API | Rol |
| :-- | :-- |
| `checkbox` | `Checkbox::new(id, toggle_state)` için kısa constructor'dır; görsel ve işleyici davranışı `Checkbox` ile aynıdır. |
| `switch` | `Switch::new(id, toggle_state)` için kısa constructor'dır; iki durumlu ayar satırlarında sade kullanım sağlar. |
| `ToggleStyle` | Checkbox ve benzeri toggle yüzeylerinde `Ghost`, `ElevationBased(ElevationIndex)` veya `Custom(Hsla)` görünümünü seçer. |
| `SwitchColor` | Switch açık durum rengini `Accent` ya da `Custom(Hsla)` olarak belirler. |
| `SwitchLabelPosition` | Switch label'ının `Start` veya `End` tarafında duracağını seçer. |

## InputField (`ui_input`)

Kaynak:

- Tanım: `ui_input` crate'i
- Export: `ui_input::InputField`
- Prelude: Hayır; `use ui_input::InputField;` ayrıca eklersin.
- Preview: `impl Component for InputField`.

Ne zaman kullanırsın:

- Arama girişi, API key alanı, ayar formu veya modal içi tek satır metin girişi gerektiğinde.
- Editor tabanlı gerçek metin girişi davranışı, odak handle'ı, placeholder, masked değer ve tab sırası desteği istendiğinde.

Ne zaman kullanmazsın:

- Yalnızca statik bir metin göstermek için `Label` daha basit ve doğru bir çözümdür.
- Çok satırlı veya editor özellikleri gerektiren bir içerik için doğrudan editor tabanlı bir view kullanmak gerekir.
- `ui` içine bağımlılık eklerken `ui_input`'u çözüm olarak düşünmemen gerekir; `ui_input`, editor crate'ine bağımlı olduğu için ayrı bir crate olarak tutulur ve bu sınırı korumak istersin.

Temel API:

- Constructor: `InputField::new(window, cx, placeholder_text)`.
- Builder'lar: `.start_icon(IconName)`, `.label(...)`, `.label_size(...)`, `.label_min_width(...)`, `.tab_index(...)`, `.tab_stop(bool)`, `.masked(bool)`.
- Okuma/yazma: `.text(cx)`, `.is_empty(cx)`, `.clear(window, cx)`, `.set_text(text, window, cx)`, `.set_masked(masked, window, cx)`.
- Düşük seviye erişim: `.editor() -> &Arc<dyn ErasedEditor>`.

Davranış:

- `Render` ve `Focusable` implement eder; genellikle `Entity<InputField>` olarak view durumunda tutarsın.
- `InputField::new(...)` çağrısı, `ui_input::ERASED_EDITOR_FACTORY` fabrika fonksiyonunun önceden kurulmuş olmasını bekler. Zed çalışma zamanı bu fabrikayı editor entegrasyonu sırasında hazırlar.
- `.masked(true)` verildiğinde sağda bir show/hide `IconButton` render edilir ve bu butona tıklamak maske durumunu günceller.
- Odak görünümü editor odak handle'ına bağlı border rengiyle çizersin.

Örnek:

```rust
use gpui::Entity;
use ui::prelude::*;
use ui_input::InputField;

fn api_anahtari_girdisi_olustur(window: &mut Window, cx: &mut App) -> Entity<InputField> {
    cx.new(|cx| {
        InputField::new(window, cx, "sk-...")
            .label("API anahtarı")
            .start_icon(IconName::LockOutlined)
            .masked(true)
    })
}
```

Zed içinden kullanım örnekleri:

- `language_models` crate'i: API key girişi.
- `keymap_editor` crate'i: context ve action girişleri.
- `component_preview` crate'i: bileşen arama filtre girişi.

Düşük seviye yüzey — `ErasedEditor`:

`.editor()` çağrısıyla elde edilen `Arc<dyn ErasedEditor>` değeri, gerçek bir `Editor` view'una tip silmeli bir kapı sunar. Bu sayede `ui_input` crate'i `editor` crate'ine doğrudan bağımlı olmaz; editor entegrasyonu uygulama başlangıcında bir kez `ERASED_EDITOR_FACTORY: OnceLock<...>` üzerinden kurarsın:

`ui_input` köprü API'leri:

| API | Rol |
| :-- | :-- |
| `ERASED_EDITOR_FACTORY` | Çalışma zamanında gerçek editor adaptörünü sağlayan global fabrikadır; `InputField::new(...)` bu fabrika kurulduktan sonra çağırman gerekir. |
| `ErasedEditor` | Metin okuma/yazma, odak handle'ı, maskeleme, olay aboneliği ve render işlemlerini crate sınırını bozmadan sunan trait yüzeyidir. |
| `ErasedEditorEvent` | `BufferEdited` ve `Blurred` olaylarıyla giriş değişimi ve odak kaybını bildirir. |

```rust
// Uygulama başlangıcında (genellikle editor crate'inin init fonksiyonu kurar):
if ui_input::ERASED_EDITOR_FACTORY
    .set(|window, cx| Arc::new(OrnekEditorAdaptoru::new(window, cx)))
    .is_err()
{
    // Fabrika daha önce kurulduysa mevcut adaptörü kullanırsın.
}
```

`ErasedEditor` trait metodları:

| Metot | İmza | Kullanım |
| :-- | :-- | :-- |
| `text(cx)` | `(&self, &App) -> String` | Anlık metin değeri |
| `set_text(text, window, cx)` | `(&self, &str, &mut Window, &mut App)` | Programatik değer atama |
| `clear(window, cx)` | `(&self, &mut Window, &mut App)` | Tüm metni siler |
| `set_placeholder_text(text, window, cx)` | `(&self, &str, &mut Window, &mut App)` | Placeholder güncelleme |
| `move_selection_to_end(window, cx)` | `(&self, &mut Window, &mut App)` | İmleci sona taşır |
| `set_masked(masked, window, cx)` | `(&self, bool, &mut Window, &mut App)` | Şifre maskesi aç/kapat |
| `focus_handle(cx)` | `(&self, &App) -> FocusHandle` | Odak yönetimi |
| `subscribe(callback, window, cx)` | callback: `FnMut(ErasedEditorEvent, &mut Window, &mut App)`, `Subscription` döner | Olay aboneliği; geri çağrıya olay değerle taşınır |
| `render(window, cx)` | `(&self, &mut Window, &App) -> AnyElement` | Manuel render (InputField içeride çağırır) |
| `as_any()` | `&dyn Any` | Downcast için |

`ErasedEditorEvent` enum'u iki varyant taşır:

| Varyant | Ne zaman yayınlanır |
| :-- | :-- |
| `BufferEdited` | Kullanıcı metni değiştirdiğinde (yazma, silme, paste vb.) |
| `Blurred` | Editor odağı kaybettiğinde |

Değer değişimini takip etmek için view içinde bir abonelik kurman ve bunu saklaman gerekir. Abonelik drop edildiğinde geri çağrı ölür ve olay akışı durur:

```rust
use gpui::{Entity, Subscription};
use ui::prelude::*;
use ui_input::{ErasedEditorEvent, InputField};

struct ApiAnahtariFormu {
    giris: Entity<InputField>,
    gecerli_deger: String,
    _giris_aboneligi: Subscription,
}

impl ApiAnahtariFormu {
    fn new(window: &mut Window, cx: &mut Context<Self>) -> Self {
        let giris = cx.new(|cx| {
            InputField::new(window, cx, "sk-...")
                .label("API anahtarı")
                .masked(true)
        });

        let zayif = cx.weak_entity();
        let abonelik = giris.read(cx).editor().subscribe(
            Box::new(move |olay, window, cx| {
                zayif
                    .update(cx, |this: &mut Self, cx| match olay {
                        ErasedEditorEvent::BufferEdited => {
                            this.gecerli_deger = this.giris.read(cx).text(cx);
                            cx.notify();
                        }
                        ErasedEditorEvent::Blurred => {
                            // Doğrulama veya kaydetme
                        }
                    })
                    .ok();
            }),
            window,
            cx,
        );

        Self { giris, gecerli_deger: String::new(), _giris_aboneligi: abonelik }
    }
}
```

> **`_giris_aboneligi` saklamak şart.** `Subscription` drop edilirse geri çağrı ölür ve `BufferEdited` olayı tetiklenmez. Aynı kural diğer GPUI abonelikleri için de geçerlidir.

Dikkat edeceğin noktalar:

- `InputField` `RenderOnce` değildir; her render'da yeniden yaratmak yerine entity olarak saklanır ve view durumunda tutarsın.
- Metin değerini `field.read(cx).text(cx)` ile okursun. Değer değişimine tepki vereceksen yukarıdaki `subscribe` örneğini izler ve dönen `Subscription` değerini view alanında saklarsın.
- `ERASED_EDITOR_FACTORY` kurulmadan `InputField::new` çağrılırsa panic oluşur; bu yüzden editor crate'inin init fonksiyonunun uygulama başlangıcında çalıştığından emin olman gerekir.
- `label_min_width(...)` adında "label" ifadesi geçse de, kaynakta bu metod input kapsayıcısının `min_width` değerini ayarlar.

## Ayar UI Form Yüzeyi

Kaynak:

- Sayfa verisi: `settings_ui` crate'i.
- Renderer kayıtları: `settings_ui` crate'i.
- Tool izin kurulumu: `settings_ui` crate'i.

Davranış:

- `settings_ui::init_renderers(...)`, `settings::CompletionMenuItemKind` için açılır seçim renderer'ı kaydeder. Bu ayar `editor.completion_menu_item_kind` JSON yolu ile görünür; değerler `off` ve `symbol` olur.
- Ayar sayfasındaki `"Completion Menu Item Kind"` (tamamlama menüsü öğe türü) satırı, tamamlama menüsünde LSP öğe türü bilgisinin gösterilip gösterilmeyeceğini seçtirir. `off` öğe türünü gizler, `symbol` sözdizimi teması ile renklendirilmiş tek harfli rozet gösterir.
- `"Version Control / Git Hunks"` bölümünde `"Show Stage/Restore Buttons"` satırı `git.show_stage_restore_buttons` boolean ayarını yazar. Bu değer `false` olduğunda diff hunk üstündeki `"Stage"`, `"Unstage"` ve `"Restore"` butonları render edilmez.
- `"Araç İzinleri"` kurulum listesindeki `skill` aracı kaynakta `"Loading agent skill instructions"` açıklamasıyla gelir. Regex açıklaması skill adına değil, skill'in `SKILL.md` dosyasının mutlak yoluna göre eşleştiğini belirtir.
- Ayar araması boş sorguda filtre uygulamaz; sayfa listesi resetlenir. Tam eşleşme yolunda sorgu birden fazla kelime içerdiğinde, kelimelerin tamamının ilgili dokümandaki bir sözcük önekiyle eşleşmesi beklersin.

Dikkat edeceğin noktalar:

- Yeni enum tabanlı ayarlar için yalnızca `SettingItem` eklemek yetmez; ilgili enum'un `init_renderers(...)` içinde uygun renderer'a kaydedilmesi gerekir.
- Git hunk butonları ayarla kapatıldığında aynı aksiyonu ikinci bir buton ile geri ekleme. Kullanıcıya görünür yüzey ayar değerini doğrudan izlemelidir.

## Form Kompozisyon Örnekleri

Bir ayar satırı için tipik kompozisyon, `SwitchField`'ın etrafına bir `v_flex` koymak ve gerekirse birden fazla benzer satırı bu kolonda alt alta dizmektir. Aşağıdaki örnek tek bir satır gösterir:

```rust
use ui::prelude::*;
use ui::{SwitchField, Tooltip};

struct AyarlarGorunumu {
    kaydederken_bicimlendir: bool,
}

impl Render for AyarlarGorunumu {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_3()
            .child(
                SwitchField::new(
                    "kaydederken-bicimlendir",
                    Some("Kaydederken biçimlendir"),
                    Some("Dosyayı yazmadan önce etkin biçimlendiriciyi çalıştır.".into()),
                    self.kaydederken_bicimlendir,
                    cx.listener(|this: &mut AyarlarGorunumu, durum: &ToggleState, _, cx| {
                        this.kaydederken_bicimlendir = durum.selected();
                        cx.notify();
                    }),
                )
                .tooltip(Tooltip::text("Bu dil için yapılandırılan biçimlendiriciyi kullanır.")),
            )
    }
}
```
