# 12. Geri Bildirim ve Durum Göstergeleri

Geri bildirim bileşenleri, kullanıcıya uygulamanın o anki durumunu bildirir. Bilgi, başarı, uyarı, hata, ilerleme, sayaç veya dikkat gerektiren kararlar bu grubun çatısı altına girer. Hepsi aynı tema belirteçlerini (tokens) paylaşır, fakat görsel yoğunlukları farklıdır. Bu yüzden öncelikle mesajın ne kadar dikkat çekmesi gerektiğine karar verilir, ardından uygun yüzey seçilir:

- `Banner`: Sayfa veya panel üstünde kısa ve akışı bölmeyen bir mesaj vermek için kullanılır.
- `Callout`: İçerik akışı içinde, kullanıcının okuması ve gerekirse karar vermesi beklenen daha açıklayıcı bir mesaj için kullanılır.
- `Modal`: Kendi modal içeriğini kurmak için bir iskelet sağlar.
- `AlertModal`: Kısa karar akışları veya uyarı diyalogları için kullanılır.
- `AnnouncementToast`: Yeni özellik veya duyuru kartıdır; yaşam döngüsü üst bildirim sistemi tarafından yönetilir.
- `CountBadge`, `Indicator`, `ProgressBar`, `CircularProgress`: Küçük durum ve ilerleme göstergeleridir.
- `ActivityIndicator`: Çalışma alanı durum (workspace status) alanında LSP, debug, git, dosya sistemi, extension ve formatlama aktivitelerini tek bir kompakt tetikleyici altında toplar.

![Geri Bildirim Yüzeyi Seçimi](assets/feedback-yuzey-secimi.svg)

## Severity

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Severity`.
- Prelude: `ui::prelude::*` içinde otomatik gelir.

Tavsiye Edilen Kullanım Alanları:

- Bir mesajın tonunu `Info`, `Success`, `Warning` veya `Error` olarak tek bir enum üzerinden seçmek için.
- `Banner` ve `Callout` gibi bileşenlerde ikon, arka plan ve sınır renginin otomatik olarak eşleşmesi gerektiğinde.

Davranış:

- `Banner` ve `Callout`, severity değerinden ikon ile durum renklerini türetir.
- `Info` için sade bir `info_background` tonu ve sönük (muted) ikon rengi seçilir; `Success` yeşil, `Warning` sarı, `Error` kırmızı durum belirteçlerini kullanır.
- Severity, kullanıcıya gösterilen mesajın yerine geçmez. Mesaj yine kısa ve açık olmalıdır. Bir aksiyon gerekiyorsa, bu aksiyon ayrı bir buton alanına (slot) yerleştirilir.

## Banner

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Banner`.
- İlgili tipler: `ui::Severity`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Banner`.

Tavsiye Edilen Kullanım Alanları:

- Sayfa veya panel içinde kısa bir bilgi, başarı, uyarı veya hata mesajı göstermek için.
- Kullanıcıyı akıştan koparmadan bir CTA (eyleme çağrı) veya düzeltme aksiyonu sunmak için.
- Bir içeriğin üstünde ya da ilgili bölümün başında engelleyici olmayan (non-blocking) bir mesaj konumlandırmak için.

Tercih Edilmemesi Gereken Durumlar:

- Uzun açıklama, madde listesi veya ayrıntılı bir karar gerekiyorsa `Callout` daha uygun bir yüzeydir.
- Kullanıcının devam etmeden önce karar vermesi zorunluysa `AlertModal` daha doğru bir araçtır.
- Kısa süreli bir global bildirim yaşam döngüsü gerekiyorsa, uygulama bildirim altyapısı ile uygun bildirim görünümü (view) birlikte kullanılır.

Temel API:

- `Banner::new()`.
- `.severity(Severity)`.
- `.action_slot(element)`.
- `.wrap_content(bool)`.
- ParentElement: `.child(...)`, `.children(...)`.

Davranış:

- Varsayılan severity değeri `Severity::Info`'dur.
- Severity'ye göre ikon, arka plan ve sınır rengi seçilir.
- `action_slot(...)` verildiğinde, banner sağ tarafta bir aksiyon alanı açar ve içerik iç kenar boşluğu (padding) bu yapıya göre düzenlenir.
- `.wrap_content(true)`, dar alanlarda içeriğin alt satıra kırılmasına izin verir.

Örnek:

```rust
use ui::{Banner, Button, Icon, IconName, IconSize, Severity, prelude::*};

fn senkron_banner_render() -> impl IntoElement {
    Banner::new()
        .severity(Severity::Info)
        .child(Label::new("Senkronizasyon sürüyor"))
        .action_slot(
            Button::new("senkronizasyonu-gor", "Görüntüle")
                .end_icon(Icon::new(IconName::ArrowUpRight).size(IconSize::Small)),
        )
}
```

Çok satırlı içerik gerekirse `wrap_content(true)` çağrısı satır kırılmasına izin verir:

```rust
use ui::{Banner, Severity, prelude::*};

fn saglayici_uyari_banner_render() -> impl IntoElement {
    Banner::new()
        .severity(Severity::Warning)
        .wrap_content(true)
        .child(
            Label::new(
                "Bu ayar seçili sağlayıcı için kullanılamaz.",
            )
            .size(LabelSize::Small),
        )
}
```

Zed içinden kullanım örnekleri:

- `extensions_ui` crate'i: Eklenti yükleme teşvikleri ve kayıt geçişi (registry migration) banner'ları.
- `settings_ui` crate'i: Ayar sayfası uyarıları.
- `language_models` crate'i: Dil modeli sağlayıcı durum mesajları.

Dikkat Edilmesi Gereken Hususlar:

- Banner içeriği kısa tutulmalıdır. Birden fazla paragraf veya liste gerektiren içerikler için `Callout` daha uygundur.
- `action_slot(...)` içinde birden çok aksiyon yer alacaksa, `h_flex().gap_1()` ile açık bir aralık kurulması okunabilirliği artırır.
- Banner, modal içindeki karar alanı gibi kullanılmamalıdır. Modal kararları footer aksiyonlarıyla verilir.

## Callout

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Callout`, `ui::BorderPosition`.
- İlgili tipler: `ui::Severity`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Callout`.

Tavsiye Edilen Kullanım Alanları:

- İçerik içinde kullanıcının okuması gereken bir açıklamayı, sınırlamayı veya kararı göstermek için.
- Başlığı, açıklamayı, aksiyonu ve kapatma (dismiss) kontrolünü tek bir yüzeyde toplamak için.
- Markdown veya özel bir element gibi metin dışı bir açıklama içeriği gerekiyorsa `description_slot(...)` ile tasarlamak için.

Tercih Edilmemesi Gereken Durumlar:

- Yalnızca tek satırlık bir sayfa üstü mesaj için `Banner` çok daha uygundur.
- Global ve geçici bir bildirim için bir bildirim sunucusu (notification host) kullanılır.
- Bloklayıcı bir karar gerekiyorsa `AlertModal` doğru yüzeydir.

Temel API:

- `Callout::new()`.
- `.severity(Severity)`.
- `.icon(IconName)`.
- `.title(text)`.
- `.description(text)`.
- `.description_slot(element)`.
- `.actions_slot(element)`.
- `.dismiss_action(element)`.
- `.line_height(px)`.
- `.border_position(BorderPosition::Top | BorderPosition::Bottom)`.

Callout kenar seçimi:

| API | Rol |
| :-- | :-- |
| `BorderPosition` | Callout border çizgisinin `Top` veya `Bottom` tarafında görüneceğini seçer. |

Davranış:

- Varsayılan severity `Severity::Info`'dur.
- `.icon(...)` çağrılmadığında ikon alanı render edilmez. Çağrıldığında mevcut render akışında görünen ikon adı ve rengi severity'den türetilir; verilen `IconName` alanın gösterileceğini belirtir.
- `.description_slot(...)` ile `.description(...)` aynı anda verildiğinde slot önceliklidir.
- Açıklama alanı `max_h_32()` ve `overflow_y_scroll()` özelliklerini kullanır; bu sayede uzun bir içerikte callout bileşeninin yüksekliği kontrol altında tutulur.
- Aksiyon ve dismiss slot'ları başlık satırının sağında render edilir.

Örnek:

```rust
use ui::{Button, Callout, IconButton, IconName, IconSize, Severity, prelude::*};

fn yeniden_dene_callout_render() -> impl IntoElement {
    Callout::new()
        .severity(Severity::Warning)
        .icon(IconName::Warning)
        .title("Bağlantı başarısız")
        .description("10 saniye içinde yeniden denenecek. Sorun sürerse ağ ayarlarını kontrol et.")
        .actions_slot(Button::new("simdi-yeniden-dene", "Şimdi yeniden dene").label_size(LabelSize::Small))
        .dismiss_action(
            IconButton::new("yeniden-deneme-uyarisini-kapat", IconName::Close).icon_size(IconSize::Small),
        )
}
```

Özel bir açıklama içeriği gerekiyorsa `description_slot(...)` ile çok satırlı veya kompozit bir yapı verilebilir:

```rust
use ui::{Callout, IconName, Severity, prelude::*};

fn izin_callout_render() -> impl IntoElement {
    Callout::new()
        .severity(Severity::Error)
        .icon(IconName::XCircle)
        .title("İzin reddedildi")
        .description_slot(
            v_flex()
                .gap_1()
                .child(Label::new("Seçili komut bu çalışma alanında çalıştırılamaz."))
                .child(Label::new("İzin vermek için çalışma alanı ayarlarını aç.").color(Color::Muted)),
        )
}
```

Zed içinden kullanım örnekleri:

- `agent_ui` crate'i: Yapay zeka temsilcisi yeniden deneme, token ve araç kullanımı uyarıları.
- `zed` crate'i: Görsel test durum mesajları.

Dikkat Edilmesi Gereken Hususlar:

- `Callout` içeriği normal akış içinde yer alır; görünüm alanını (viewport) kaplayan bir katman (overlay) gibi davranmaz.
- İkon gösterilmesi gerekiyorsa `.icon(...)` çağrısının açıkça yapılması gerekir.
- Açıklama alanına (description slot) kaydırma yapan karmaşık bir içerik yerleştirildiğinde, içerideki metinlerin `min_w_0()` ve `.truncate()` davranışları ayrıca düşünülmelidir.

## Modal

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Modal`, `ui::ModalHeader`, `ui::ModalRow`, `ui::ModalFooter`, `ui::Section`, `ui::SectionHeader`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan `impl Component` yoktur.

Tavsiye Edilen Kullanım Alanları:

- Modal içeriğini Zed'in header, section ve footer düzeniyle kurmak için.
- Çok bölümlü bir ayar, form veya seçim akışı oluşturulurken.
- Kaydırma tutamacı (scroll handle) dışarıdan yönetilen bir modal gövdesi (body) gerektiğinde.

Tercih Edilmemesi Gereken Durumlar:

- Kısa bir uyarı ve iki aksiyonlu bir karar için `AlertModal` daha az kodla doğru davranışı sunar.
- Modal dışı bir panel veya sayfa düzeni için `v_flex()` ile birlikte `Section` dışında bir yerleşim daha uygun olur.

Temel API:

- `Modal::new(id, scroll_handle)`.
- `.header(ModalHeader)`.
- `.section(Section)`.
- `.footer(ModalFooter)`.
- `.show_dismiss(bool)`.
- `.show_back(bool)`.
- ParentElement: `.child(...)`, `.children(...)`.
- `ModalHeader::new().headline(...).description(...).icon(...).show_dismiss_button(...).show_back_button(...)`.
- `ModalFooter::new().start_slot(...).end_slot(...)`.
- `Section::new()`, `Section::new_contained()`, `.contained(bool)`, `.header(...)`, `.meta(...)`, `.padded(bool)`.
- `SectionHeader::new(label).end_slot(...)`.
- `ModalRow::new()`.

Modal alt yapı taşları:

| API | Rol |
| :-- | :-- |
| `ModalHeader` | Modal başlığını, açıklamasını, ikonunu ve kapatma/geri buton görünürlüğünü yönetir. |
| `ModalRow` | Bölüm (section) içinde tek satırlık ayar veya içerik satırı kurmak için üst element yüzeyidir. |
| `ModalFooter` | Modal alt aksiyon alanını `start_slot` ve `end_slot` ile düzenler. |
| `Section` | Modal veya panel içinde kenar boşluğu atanmış ya da sınırlandırılmış (padded/contained) alt bölüm yüzeyi oluşturur. |
| `SectionHeader` | Bölüm başlığı ve opsiyonel sağ alan için küçük başlık bileşenidir. |

Davranış:

- Modal kökü `size_full()`, `flex_1()` ve `overflow_hidden()` kullanır; modal kapsayıcısı genellikle üst katman (overlay) tarafından sağlanır.
- `scroll_handle` verildiğinde gövde `overflow_y_scroll()` ve `track_scroll(...)` ile bağlanır.
- `show_dismiss(true)` ve `show_back(true)`, başlıkta Zed'in `menu::Cancel` aksiyonunu tetikleyen ikon butonları üretir.
- `Section::new_contained()` kenarlıklı bir iç yüzey oluşturur; normal `Section` ise daha düz bir akış sağlar.

Örnek:

```rust
use ui::{
    Button, Modal, ModalFooter, ModalHeader, ModalRow, Section, SectionHeader, prelude::*,
};

fn proje_ayarlari_modal_render() -> impl IntoElement {
    Modal::new("proje-ayarlari-modal", None)
        .show_dismiss(true)
        .header(
            ModalHeader::new()
                .headline("Proje ayarları")
                .description("Değişiklikler geçerli çalışma alanına uygulanır."),
        )
        .section(
            Section::new()
                .header(SectionHeader::new("Davranış"))
                .child(
                    ModalRow::new()
                        .child(Label::new("Kaydederken biçimlendir").flex_1())
                        .child(Label::new("Etkin").color(Color::Muted)),
                ),
        )
        .footer(ModalFooter::new().end_slot(Button::new("ayarlari-kaydet", "Kaydet")))
}
```

Modal Yaşam Döngüsü ve Çalışma Alanı Entegrasyonu:

Zed UI tarafındaki `Modal` bileşeni yalnızca bir içerik iskeletidir. Bir modal'ın açılıp kapanma davranışı bu bileşenin değil; asıl olarak `workspace::ModalLayer` ile `workspace::ModalView` trait'inin sorumluluğundadır.

```rust
use gpui::{Entity, ManagedView};
use ui::{Modal, ModalFooter, ModalHeader, Section, prelude::*};
use workspace::{ModalView, Workspace};

struct ProjeAyarlariModal {
    odak_handle: gpui::FocusHandle,
}

impl gpui::EventEmitter<gpui::DismissEvent> for ProjeAyarlariModal {}

impl gpui::Focusable for ProjeAyarlariModal {
    fn focus_handle(&self, _cx: &App) -> gpui::FocusHandle {
        self.odak_handle.clone()
    }
}

impl ManagedView for ProjeAyarlariModal {}
impl ModalView for ProjeAyarlariModal {}

impl Render for ProjeAyarlariModal {
    fn render(&mut self, _window: &mut Window, _cx: &mut Context<Self>) -> impl IntoElement {
        Modal::new("proje-ayarlari-modal", None)
            .header(ModalHeader::new().headline("Proje ayarları"))
            .section(Section::new().child(Label::new("…")))
            .footer(ModalFooter::new().end_slot(Button::new("kapat", "Kapat")))
    }
}

fn proje_ayarlarini_ac(
    workspace: &mut Workspace,
    window: &mut Window,
    cx: &mut Context<Workspace>,
) {
    workspace.toggle_modal::<ProjeAyarlariModal, _>(window, cx, |_window, cx| {
        ProjeAyarlariModal {
            odak_handle: cx.focus_handle(),
        }
    });
}
```

`ModalView` trait sözleşmesi şu maddeleri kapsar:

- `ManagedView` üzerinden gelen `Render + Focusable + EventEmitter<DismissEvent>` zorunluluğu.
- `on_before_dismiss(window, cx) -> DismissDecision`: Kapanmadan önce bir doğrulama veya kullanıcı onayı istenebilir. `DismissDecision::Pending` kapanmayı erteler; `DismissDecision::Dismiss(false)` ise iptal eder.
- `fade_out_background(&self) -> bool`: Ekrandaki diğer içeriği soluklaştırmak için geçersiz kılınabilir (override edilebilir).
- `render_bare(&self) -> bool`: Çalışma alanı tarafındaki `ModalLayer`'ın varsayılan yükseklik (elevation) yüzeyini atlamak gerektiğinde kullanılır.

`Workspace::toggle_modal::<V, _>(window, cx, build_fn)` çağrısı, aynı modal türü zaten açıksa onu kapatır; farklı bir modal açıksa onu kapatıp yenisini açar. `ModalLayer`, kapatma (dismiss) olayını dinler ve odağı önceki elemana otomatik olarak geri verir.

Dikkat Edilmesi Gereken Hususlar:

- `Modal` yalnızca bir içerik iskeletidir; açma ve kapama yaşam döngüsü modal barındırıcısı (host) veya üst görünüm üzerinden yönetilir.
- Header'daki dismiss ve back butonları `menu::Cancel` eylemini tetikler; bu aksiyonun üst bağlamda (context) ele alınması gerekir.
- Bölüm (section) içinde çok sayıda ayar satırı yer alıyorsa, gövde için bir kaydırma tutamacı (scroll handle) atanmalıdır.
- `Modal`, bir `AlertModal` yerine kullanılsa bile yine de çalışma alanı üzerinden `toggle_modal` ile sunulur; ayrı bir katman altyapısı kurmaya gerek yoktur.

## AlertModal

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::AlertModal`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for AlertModal`.

Tavsiye Edilen Kullanım Alanları:

- Kullanıcıdan kısa bir onay veya iptal kararı almak için.
- Güvenlik, silme veya çalışma alanına güvenme (workspace trust) gibi devam etmeden önce anlaşılması gereken uyarılar için.
- Özel bir header veya footer gerekse de modal iskeletini hızlıca kurmak için.

Tercih Edilmemesi Gereken Durumlar:

- Engelleyici olmayan bir bilgi mesajı için `Banner` veya `Callout` çok daha doğrudan bir araçtır.
- Çok bölümlü bir ayar formu için `Modal` daha uygundur.
- Yeni özellik duyurusu için `AnnouncementToast` daha doğru bir yüzeydir.

Temel API:

- `AlertModal::new(id)`.
- `.title(text)`.
- `.header(element)`.
- `.footer(element)`.
- `.primary_action(label)`.
- `.dismiss_label(label)`.
- `.width(width)`.
- `.key_context(context)`.
- `.on_action::<A>(listener)`.
- `.track_focus(&focus_handle)`.
- ParentElement: `.child(...)`, `.children(...)`.

Davranış:

- Varsayılan genişlik `px(440.)`'tır.
- `.title(...)` verildiğinde küçük bir `Headline` içeren bir varsayılan başlık üretilir.
- `.primary_action(...)` veya `.dismiss_label(...)` verildiğinde varsayılan bir altlık üretilir. Etiket verilmediği durumda birincil metin `"Ok"`, kapatma metni ise `"Cancel"` olur.
- Varsayılan altlık butonları yalnızca görünümü kurar; karar akışı Zed eylem sistemi üzerinden `.on_action(...)` veya üst yaşam döngüsü ile bağlanır.
- `.header(...)` ve `.footer(...)` verildiğinde, varsayılan başlık veya altlık yerine tamamen özel bir element render edilir.

Örnek:

```rust
use ui::{AlertModal, prelude::*};

fn proje_silme_uyarisi_render() -> impl IntoElement {
    AlertModal::new("proje-silme-uyarisi")
        .title("Proje silinsin mi?")
        .child("Bu işlem projeyi son projeler listesinden kaldırır.")
        .primary_action("Sil")
        .dismiss_label("İptal")
}
```

Özel bir header gerektiğinde, hem `width(...)` hem de `header(...)` ile modal'a kendi görsel kimliği verilebilir:

```rust
use ui::{AlertModal, Icon, IconName, prelude::*};

fn sinirli_calisma_alani_uyarisi_render(cx: &App) -> impl IntoElement {
    AlertModal::new("sinirli-calisma-alani-uyarisi")
        .width(rems(40.))
        .header(
            v_flex()
                .p_3()
                .gap_1()
                .bg(cx.theme().colors().editor_background.opacity(0.5))
                .border_b_1()
                .border_color(cx.theme().colors().border_variant)
                .child(
                    h_flex()
                        .gap_2()
                        .child(Icon::new(IconName::Warning).color(Color::Warning))
                        .child(Label::new("Tanınmayan çalışma alanı")),
                ),
        )
        .child("Kısıtlı mod, çalışma alanı komutlarının otomatik çalışmasını engeller.")
        .primary_action("Çalışma alanına güven")
        .dismiss_label("Kısıtlı kal")
}
```

Zed içinden kullanım örnekleri:

- `workspace` crate'i: Kısıtlı çalışma alanı karar akışı; `key_context`, `track_focus` ve `.on_action(...)` özellikleri birlikte kullanılır.
- `ui` crate'i: Temel ve özel başlık (header) önizleme örnekleri.

Dikkat Edilmesi Gereken Hususlar:

- `AlertModal` kısa ve karar odaklı tutulmalıdır. Birden fazla bölüm (section) gerekiyorsa doğru araç `Modal`'dır.
- Tehlikeli aksiyonlarda birincil etiketin (primary label) net olması beklenir; `"Ok"` yerine doğrudan eylemi anlatan bir metin tercih edilir.
- Odak ve klavye eylemi davranışı gerekiyorsa `key_context(...)` ile `track_focus(...)` bağlanmadan yalnızca görsel bir modal üretilmesi doğru değildir; aksi halde modal klavye ile etkileşime giremez.

## AnnouncementToast

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::AnnouncementToast`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for AnnouncementToast`.

Tavsiye Edilen Kullanım Alanları:

- Yeni özellik, önemli değişiklik veya üründeki görünür duyuruları kart biçiminde göstermek için.
- İllüstrasyon, başlık, açıklama, madde listesi ve iki aksiyonlu duyuru gerektiğinde.

Tercih Edilmemesi Gereken Durumlar:

- Hata, yeniden deneme veya satır içi (inline) bir durum mesajı için `Banner` ya da `Callout` daha uygundur.
- Basit bir toast ihtiyacı için üst bildirim sisteminin daha küçük görünümü kullanılır.
- Kullanıcının devam etmeden karar vermesi gerekiyorsa `AlertModal` daha doğru bir yüzeydir.

Temel API:

- `AnnouncementToast::new()`.
- `.illustration(element)`.
- `.heading(text)`.
- `.description(text)`.
- `.bullet_item(element)`.
- `.bullet_items(items)`.
- `.primary_action_label(text)`.
- `.primary_on_click(handler)`.
- `.secondary_action_label(text)`.
- `.secondary_on_click(handler)`.
- `.dismiss_on_click(handler)`.

Davranış:

- Varsayılan primary label `"Try Now"`, secondary label ise `"Learn More"` olarak gelir.
- Tıklama işleyicileri boş bir varsayılan closure ile gelir; gerçek davranışın bağlanması üst görünümün dismiss veya yönlendirme (navigation) geri çağrıları üzerinden olur.
- Kök eleman `occlude()`, `relative()`, `w_full()` ve `elevation_3(cx)` kullanır.
- Sağ üstte bir kapatma ikon butonu render edilir; dismiss yaşam döngüsü `.dismiss_on_click(...)` geri çağrısına bırakılır.

Örnek:

```rust
use ui::{AnnouncementToast, ListBulletItem, prelude::*};

fn ozellik_duyurusu_render() -> impl IntoElement {
    div().w_80().child(
        AnnouncementToast::new()
            .heading("Paralel agent'lar")
            .description("Birden çok agent thread'ini projeler arasında çalıştır.")
            .bullet_item(ListBulletItem::new("Agent'ları izole worktree'lerde başlat"))
            .bullet_item(ListBulletItem::new("Tab değiştirmeden ilerlemeyi gözden geçir"))
            .primary_action_label("Şimdi dene")
            .primary_on_click(|_, _window, cx| cx.open_url("https://zed.dev"))
            .secondary_action_label("Daha fazla bilgi")
            .secondary_on_click(|_, _window, cx| cx.open_url("https://zed.dev/docs"))
            .dismiss_on_click(|_, _window, _cx| {}),
    )
}
```

Zed içinden kullanım örnekleri:

- `auto_update_ui` crate'i: Güncelleme duyuru görünümü; tıklama işleyicileri telemetri, URL ve kapatma geri çağrılarıyla bağlanır.

Dikkat Edilmesi Gereken Hususlar:

- `AnnouncementToast` tek başına bildirim yaşam döngüsünü yönetmez. Kapatma, gizleme veya yönlendirme davranışının üst bildirim görünümü içinde uygulanması gerekir.
- Madde sayısı sınırlı tutulur; çok uzun bir duyuru kartı kullanıcıyı akıştan koparır.
- İllüstrasyon eklendiğinde toast'ın üstünde render edilir ve gövdeden kenarlık (border) ile ayrılır.

## Notification Modülü

Kaynak:

- Modül: `ui` crate'i
- Export: `ui::AlertModal`, `ui::AnnouncementToast`.
- Prelude: Hayır.

Mevcut `ui` kaynağında standalone bir `Notification` bileşeni yer almaz. `notification` dosyası yalnızca `alert_modal` ve `announcement_toast` modüllerini re-export eder. Çalışma zamanı bildirim kuyruğu, dismiss veya suppress olayları ve notification trait'leri Zed'in daha üst seviyeli bildirim altyapısında barındırılır.

Pratik sonuç şudur:

- UI bileşeni olarak `AlertModal` veya `AnnouncementToast` render edilir.
- Gösterme, saklama, kapatma ve tekrar göstermeme kararı üst bildirim görünümü (view) içinde yönetilir.
- Toast içindeki tıklama işleyicilerinde gerekirse telemetri, URL açma ve dismiss akışı birlikte bağlanır.

## CountBadge

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::CountBadge`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for CountBadge`.

Tavsiye Edilen Kullanım Alanları:

- İkon, sekme veya kompakt bir araç çubuğu öğesi üzerinde küçük bir sayaç göstermek için.
- Bildirim, hata, değişiklik veya bekleyen öğe sayısını küçük bir alanda belirtmek için.

Tercih Edilmemesi Gereken Durumlar:

- Sayısal değer ana içeriğin kendisiyse, bir `Label` veya tablo hücresi kullanılır.
- Durum sadece var/yok şeklindeyse `Indicator::dot()` daha sade bir ifadedir.

Temel API:

- `CountBadge::new(count)`.

Davranış:

- `count > 99` durumunda `"99+"` olarak gösterilir.
- `absolute()`, `top_0()` ve `right_0()` ile üst öğenin sağ üst köşesine yerleşir.
- Üst element `relative()` değilse, rozet (badge) beklenen konuma oturmaz.
- Arka plan rengi, editör arka planı ile hata durum renginin harmanlanmasıyla hesaplanır.

Örnek:

```rust
use ui::{CountBadge, IconButton, IconName, prelude::*};

fn bildirim_butonu_render(sayi: usize) -> impl IntoElement {
    div()
        .relative()
        .child(IconButton::new("bildirimler", IconName::Bell))
        .when(sayi > 0, |this| this.child(CountBadge::new(sayi)))
}
```

Zed içinden kullanım örnekleri:

- `workspace` crate'i: Panel öğesi üzerinde sayaç rozeti.
- `ui` crate'i: Sınırlandırılmış sayı önizlemesi.

Dikkat Edilmesi Gereken Hususlar:

- Üst öğenin tıklama alanı (hitbox) ile rozetin mutlak (absolute) konumunun birlikte düşünülmesi gerekir. Çok küçük ikon butonlarında rozet, tıklanabilir alanı görsel olarak kalabalıklaştırabilir.
- Rozet metni otomatik olarak sınırlandırıldığı (capped) için, gerçek tam sayının bir ipucu (tooltip) veya detay görünümünde gösterilmesi gerekebilir.

## Indicator

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Indicator`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Indicator`.

Tavsiye Edilen Kullanım Alanları:

- Küçük bir durum noktası, üst bar veya ikon tabanlı bir durum göstergesi gerektiğinde.
- Liste satırında bağlantı, kesme noktası (breakpoint), çelişki (conflict), aktif/aktif değil gibi hızlı taranabilir durumlar için.
- Bir ikon butonu veya liste öğesi yanında, dikkat çekmeyen bir durum işareti sunmak için.

Tercih Edilmemesi Gereken Durumlar:

- İşlem ilerlemesi için `ProgressBar` ya da `CircularProgress` kullanılır.
- Metinsel bir açıklama gerekiyorsa yanına bir `Label` eklenmelidir; indicator tek başına erişilebilir bir anlam taşımaz.

Temel API:

- `Indicator::dot()`.
- `Indicator::bar()`.
- `Indicator::icon(icon)`.
- `.color(Color)`.
- `.border_color(Color)`.

Davranış:

- Dot varyantı `w_1p5()`, `h_1p5()` ve `rounded_full()` kullanır.
- Bar varyantı `w_full()`, `h_1p5()` ve `rounded_t_sm()` kullanır; bu yüzden üst genişlik önemlidir.
- İkon göstergesi, ikonu `custom_size(rems_from_px(8.))` ile çok küçük bir biçimde render eder.
- `border_color(...)` yalnızca dot ve bar varyantları için bir kenarlık uygular.

Örnek:

```rust
use ui::{Indicator, prelude::*};

fn baglanti_durumu_render(bagli: bool) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            Indicator::dot().color(if bagli {
                Color::Success
            } else {
                Color::Error
            }),
        )
        .child(Label::new(if bagli { "Bağlı" } else { "Bağlı değil" }))
}
```

Zed içinden kullanım örnekleri:

- `workspace` crate'i: Durum çubuğu göstergesi.
- `debugger_ui` crate'i: Hata ayıklama oturum durumu.
- `keymap_editor` crate'i: Çakışma göstergesi.
- `title_bar` crate'i: Başlık çubuğu durum noktaları.

Dikkat Edilmesi Gereken Hususlar:

- Rengin `Color::Success`, `Warning`, `Error`, `Info` veya `Muted` gibi semantik belirteçlerden seçilmesi tutarlılığı korur.
- Gösterge (indicator) tek bilgi kaynağı olarak kullanılmamalıdır; özellikle hata ve uyarı durumlarında tooltip veya label ile anlamın belirtilmesi gerekir.

## ProgressBar

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ProgressBar`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for ProgressBar`.

Tavsiye Edilen Kullanım Alanları:

- İşlemin belirli bir `value / max_value` oranı varsa.
- Yatay alanda dosya indirme, kullanım limiti, senkronizasyon veya görev ilerlemesi göstermek için.

Tercih Edilmemesi Gereken Durumlar:

- İlerleme oranı bilinmiyorsa `LoadingLabel` veya `SpinnerLabel` çok daha uygundur.
- Çok dar bir satır içi alanda halka görünümü daha doğal duracaksa `CircularProgress` tercih edilir.

Temel API:

- `ProgressBar::new(id, value, max_value, cx)`.
- `.value(value)`.
- `.max_value(max_value)`.
- `.bg_color(hsla)`.
- `.fg_color(hsla)`.
- `.over_color(hsla)`.

Davranış:

- Doldurma genişliği `(value / max_value).clamp(0.02, 1.0)` formülüyle hesaplanır.
- `value > max_value` durumunda doldurma rengi `over_color` olur.
- Varsayılan ön plan rengi `cx.theme().status().info`'dur.
- `max_value` pozitif bir değer olmalıdır; sıfır veya anlamsız bir maksimum değer üretilmemelidir.

Örnek:

```rust
use ui::{ProgressBar, prelude::*};

fn kullanim_ilerlemesi_render(kullanilan: f32, limit: f32, cx: &App) -> impl IntoElement {
    v_flex()
        .gap_1()
        .child(
            h_flex()
                .justify_between()
                .child(Label::new("Kullanım"))
                .child(Label::new(format!("{kullanilan:.0} / {limit:.0}")).color(Color::Muted)),
        )
        .child(ProgressBar::new("kullanim-ilerlemesi", kullanilan, limit, cx))
}
```

Zed içinden kullanım örnekleri:

- `edit_prediction_ui` crate'i: Kullanım limiti ilerleme çubuğu.
- `ui` crate'i: Boş, kısmi ve dolu önizleme örnekleri.

Dikkat Edilmesi Gereken Hususlar:

- `value` ve `max_value` aynı birimde olmalıdır.
- İlerleme çubuğuna sadece renk yüklenmemeli; yanında bir etiket (label) veya ipucu (tooltip) ile bağlam sunulması okunabilirliği artırır.
- `value > max_value` durumu bilinçli bir sınır aşımı (over-limit) durumudur. Normal "işlem tamamlandı" durumu için `value == max_value` kullanılır.

## CircularProgress

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::CircularProgress`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for CircularProgress`.

Tavsiye Edilen Kullanım Alanları:

- Dar veya satır içi bir alanda belirli bir ilerleme oranını halka (ring) olarak göstermek için.
- Belirteç kullanımı, kompakt kota veya küçük durum gruplarında (status clusters).

Tercih Edilmemesi Gereken Durumlar:

- Geniş yatay bir alanda metinle birlikte ilerleme göstermek için `ProgressBar` daha okunaklı bir tercihtir.
- İlerleme oranı bilinmiyorsa spinner veya yükleme (loading) bileşeni kullanılır.

Temel API:

- `CircularProgress::new(value, max_value, size, cx)`.
- `.value(value)`.
- `.max_value(max_value)`.
- `.size(px)`.
- `.stroke_width(px)`.
- `.bg_color(hsla)`.
- `.progress_color(hsla)`.

Davranış:

- Tuval (canvas) üzerinde bir arka plan çemberi ve bir ilerleme yayı çizer.
- İlerleme üstten başlar ve saat yönünde ilerler.
- İlerleme oranı `(value / max_value).clamp(0.0, 1.0)` ile hesaplanır.
- `progress >= 0.999` olduğunda tam bir çember çizilir.
- Varsayılan çizgi kalınlığı (stroke width) `px(4.)`'tür.

Örnek:

```rust
use ui::{CircularProgress, prelude::*};

fn token_halkasi_render(kullanilan: f32, maks: f32, cx: &App) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            CircularProgress::new(kullanilan, maks, px(18.), cx)
                .stroke_width(px(2.))
                .progress_color(cx.theme().status().info),
        )
        .child(Label::new(format!("{kullanilan:.0}/{maks:.0}")).size(LabelSize::Small))
}
```

Zed içinden kullanım örnekleri:

- `agent_ui` crate'i: Yapay zeka temsilcisi belirteç kullanım halkaları.
- `ui` crate'i: Farklı yüzde değerleri için önizleme örnekleri.

Dikkat Edilmesi Gereken Hususlar:

- Halka küçük olduğunda, bir etiket veya ipucu olmadan oranı okumak zorlaşır.
- `max_value` pozitif bir değer olmalıdır.
- Aynı ekranda çok sayıda animasyonlu veya sık güncellenen tuval ilerleme göstergesi kullanılıyorsa, yeniden çizim (repaint) maliyeti hesaba katılmalıdır.

## ActivityIndicator

Kaynak:

- Tanım: `activity_indicator` crate'i
- Export: `activity_indicator::ActivityIndicator`; `ui` crate kökünden re-export edilen genel bir bileşen değildir.
- Render modeli: `workspace::StatusItemView` olarak çalışma alanı durum alanına bağlanır.

Tavsiye Edilen Kullanım Alanları:

- Çalışma alanı genelinde devam eden LSP, debug, git, dosya sistemi, eklenti güncelleme veya formatlama hatası gibi aktiviteleri tek bir durum tetikleyicisinde göstermek için.
- Bir aktivite kullanıcı aksiyonu gerekiyorsa aynı tetikleyici üzerinden tıklama işleyicisi veya popover menü sunmak için.

Davranış:

- İçerik `ActivityIcon` ayrımıyla seçilir: Bilinmeyen süreli işler `LoadingSpinner`, statik durumlar ise `Icon(IconName)` taşır.
- Spinner görünümü doğrudan `Button::loading(true)` üzerinden gelir; bu yüzden yükleme durumunda başlangıç ikonu yerine `IconName::LoadCircle` çizilir.
- Uyarı, indirme ve benzeri statik durumlarda tetikleyici `Button::start_icon(...)` kullanır; ikon `Color::Muted` ile çizilir.
- Dil sunucusu (language server) iş listesi, tetikleyiciye yalnızca içerikte özel bir tıklama işleyicisi yoksa popover olarak bağlanır. Menü en az bir iptal edilebilir iş varsa açılır; iptal edilebilir girdiler `Close` ikonu ve `Cancel ...` etiketiyle render edilir.
- Ortam hatası (environment error), formatlama hatası veya eklenti hatası gibi durumlar kendi tıklama işleyicilerini taşıyorsa dil sunucusu iş menüsü aynı tetikleyiciye eklenmez.
- Eklenti yükleme ve kaldırma durumları yükleme çarkını (loading spinner) kullanır; eklenti yükseltme ve indirme durumları indirme ikonunu kullanır.

Dikkat Edilmesi Gereken Hususlar:

- `ActivityIndicator`, genel amaçlı bir ilerleme bileşeni değildir. Bir panel içinde belirli bir iş oranı göstermek için `ProgressBar`, kompakt oran için `CircularProgress`, bilinmeyen süreli yerel yükleme durumları için ise `Button::loading(...)` veya `SpinnerLabel` tercih edilir.
- Popover menüsünde yalnızca iptal edilebilir işler aksiyon üretir. İptal edilemeyen işler tek başına menüyü açtırmaz; bu yüzden kullanıcıya tıklanabilir bir görsel ipucu gerekiyorsa ilgili durumun `on_click` geri çağrısı açıkça bağlanır.

## Geri Bildirim Kompozisyon Örnekleri

Bir senkronizasyon sürecinde hem genel bir banner hem de yüzdeyi gösteren bir ilerleme çubuğu bir arada görünebilir:

```rust
use ui::{Banner, ProgressBar, Severity, prelude::*};

fn senkron_geri_bildirimi_render(ilerleme: f32, cx: &App) -> impl IntoElement {
    v_flex()
        .gap_2()
        .child(
            Banner::new()
                .severity(Severity::Info)
                .child(Label::new("Senkronizasyon sürüyor"))
                .child(Label::new("Uzak değişiklikler uygulanıyor.").color(Color::Muted)),
        )
        .child(ProgressBar::new("senkron-ilerlemesi", ilerleme, 1.0, cx))
}
```

Bir araç çubuğu üzerinde hem bir sayaç rozeti hem de küçük bir gösterge birlikte yer alabilir. Aşağıdaki örnek hem sayaç hem de hata durumu için yan yana bir kullanım gösterir:

```rust
use ui::{CountBadge, IconButton, IconName, Indicator, prelude::*};

fn inceleme_arac_cubugu_ogesi_render(sorun_sayisi: usize, hata_var: bool) -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(
            div()
                .relative()
                .child(IconButton::new("inceleme", IconName::Check))
                .when(sorun_sayisi > 0, |this| this.child(CountBadge::new(sorun_sayisi))),
        )
        .child(
            Indicator::dot().color(if hata_var {
                Color::Error
            } else {
                Color::Success
            }),
        )
}
```

Bütün bu bileşenlerin kullanım kararı için kısa bir özet işe yarar:

- Kısa, engelleyici olmayan ve sayfa veya panel üstü bir mesaj için `Banner`.
- İçerik içinde açıklama, aksiyon ve kapatma bir arada gerekiyorsa `Callout`.
- Çok bölümlü bir modal içerik için `Modal`.
- Kısa bir karar veya uyarı diyalogu için `AlertModal`.
- Yeni özellik duyurusu için `AnnouncementToast` ile bildirim yaşam döngüsü birlikte.
- Bir ikon üzerine sayaç yerleştirmek için `CountBadge`.
- Var/yok veya nokta düzeyinde bir durum bildirmek için `Indicator`.
- Belirli bir yatay ilerleme yüzdesi göstermek için `ProgressBar`.
- Belirli bir kompakt dairesel ilerleme göstermek için `CircularProgress`.
