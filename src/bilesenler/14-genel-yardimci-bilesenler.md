# 14. Genel Yardımcı Bileşenler

Bu bölümdeki bileşenler tek bir amaca hizmet eden küçük yapı taşlarıdır. Çoğunlukla görsel bir yardımcı, klavye ipucu veya gezinti yüzeyi sunarlar. Liste satırı, araç çubuğu, panel başlığı veya boş durum gibi alanlarda önceki bölümlerdeki büyük bileşenlerin yanında sıkça tercih edilirler. Küçük görünseler de ekranın okunabilirliğini ve etkileşim kalitesini doğrudan etkilerler.

Bu aileyi kullanırken üç ayrımı akılda tutmak işi kolaylaştırır:

- `ui::KeyBinding` ile `gpui::KeyBinding` aynı adı taşısa da farklı yapılardır. UI tarafındaki bileşen kısayolu görsel olarak render eder; GPUI tarafındaki tip ise keymap'e bir binding tanımlar.
- `Image` adında dışa açık bir Zed UI bileşeni yoktur. Paketlenmiş SVG için `Vector` kullanılır; raster veya dış kaynaklı görsel için GPUI tarafındaki `img(...)` ve `ImageSource` arayüzü devreye girer.
- Disclosure, Chip ve DiffStat gibi kompakt parçalar liste veya araç çubuğu içinde kullanılırken üst kapsayıcıya `min_w_0` ve uygun gap'ler (boşluklar) tanımlanması taşma kontrolünü ciddi biçimde kolaylaştırır.

## Chip

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Chip`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Chip`.

Tavsiye Edilen Kullanım Alanları:

- Filtre, plan adı, sağlayıcı tipi, dal adı, üstveri (metadata) veya küçük bir durum etiketi göstermek için.
- İkon ile kısa etiket kombinasyonunu düşük vurguyla sunmak için.

Tercih Edilmemesi Gereken Durumlar:

- Etkileşimli bir menü butonu için `Button` veya `DropdownMenu` daha uygundur.
- Uzun bir açıklama veya paragraf için `Label` doğru yüzeydir.

Temel API:

- `Chip::new(label)`.
- `.label_color(Color)`.
- `.label_size(LabelSize)`.
- `.icon(IconName)`.
- `.icon_color(Color)`.
- `.bg_color(Hsla)`.
- `.border_color(Hsla)`.
- `.height(Pixels)`.
- `.truncate()`.
- `.tooltip(...)`.

Davranış:

- Varsayılan etiket boyutu `LabelSize::XSmall`'dur.
- Etiket, buffer yazı tipi (font) ile render edilir.
- `.truncate()` üst öğe içinde küçülmesine izin verir; uzun chip metinlerinde bu davranışın açık olması önerilir.
- Tooltip closure'ı bir `AnyView` döndürür.

Örnek:

```rust
use ui::{Chip, IconName, prelude::*};

fn dal_etiketi_render(dal: SharedString) -> impl IntoElement {
    Chip::new(dal)
        .icon(IconName::GitBranch)
        .icon_color(Color::Muted)
        .label_color(Color::Muted)
        .truncate()
}
```

Zed içinden kullanım örnekleri:

- `extensions_ui` crate'i: Eklenti yetenek (capability) etiketleri.
- `agent_ui` crate'i: Dil modeli üstverisi ve maliyet bilgisi.
- `title_bar` crate'i: Plan adı gösterimi.

Dikkat Edilmesi Gereken Hususlar:

- Chip küçük bir bilgi kapsülüdür; birincil eylem (primary action) yerine kullanılmamalıdır.
- Özel arka plan kullanılıyorsa sınır (border) renginin de bu seçimle uyumlu olması görsel tutarlılığı korur.
- Dar bir araç çubuğu içinde `.truncate()` olmadan uzun bir etiket kullanmak yerleşimi bozabilir.

## DiffStat

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::DiffStat`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for DiffStat`.

Tavsiye Edilen Kullanım Alanları:

- Eklenen ve silinen satır sayılarını kompakt biçimde göstermek için.
- Commit, dal, thread veya dosya diff üstverisinin yanında sunmak amacıyla.

Tercih Edilmemesi Gereken Durumlar:

- Ayrıntılı bir dosya diff görünümü için bu bileşen yeterli değildir.
- Yalnızca toplam değişiklik sayısı gerekiyorsa bir `Label` veya `CountBadge` daha doğru bir araç olur.

Temel API:

- `DiffStat::new(id, added, removed)`.
- `.label_size(LabelSize)`.
- `.tooltip(text)`.

Davranış:

- Ekleme (added) değeri `Color::Success`, silme (removed) değeri ise `Color::Error` ile render edilir.
- DiffStat, silme etiketini rakam genişliğinde bir tire (figure dash, `U+2012`) ile ince boşluğu birleştirerek biçimlendirir; ekleme etiketini ise düz bir artı (`+`) ile ince boşluğu birleştirerek yazar.
- Tooltip verildiğinde `Tooltip::text(...)` bağlanır.

Örnek:

```rust
use ui::{DiffStat, prelude::*};

fn dosya_degisiklik_ozeti_render() -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(Label::new("src/main.rs").truncate())
        .child(DiffStat::new("main-rs-diff", 12, 3).tooltip("12 ekleme, 3 silme"))
}
```

Zed içinden kullanım örnekleri:

- `agent_ui` crate'i: Araç sonucu (tool result) ve thread değişiklik özetleri.
- `git_ui` crate'i: Proje diff üstverisi.
- `git_graph` crate'i: Commit üstverisi.

Dikkat Edilmesi Gereken Hususlar:

- Verilen `id` değerinin sabit olması beklenir; aynı listede tekrar eden bir kimlik (id) kullanmak hatalı davranışa yol açar.
- Sıfır değerlerinin gösterilip gösterilmeyeceğine üst öğe karar verir; bileşen kendiliğinden gizlemez.

## Disclosure

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Disclosure`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Disclosure`.

Tavsiye Edilen Kullanım Alanları:

- Açılır veya kapanır bir bölüm, bir ağaç (tree) satırı ya da bir detay satırı için chevron butonu gerektiğinde.
- Üst öğenin açılma durumunu tuttuğu kontrollü bir toggle eylemi için.

Tercih Edilmemesi Gereken Durumlar:

- Tam satır bir ağaç davranışı gerekiyorsa `TreeViewItem` çok daha hazır bir altyapı sağlar.
- Yalnızca görsel bir chevron yeterliyse, bir `Icon` daha sade bir çözüm sunar.

Temel API:

- `Disclosure::new(id, is_open)`.
- `.on_toggle_expanded(handler)`.
- `.opened_icon(IconName)`.
- `.closed_icon(IconName)`.
- `.disabled(bool)`.
- `.tooltip(|window, cx| ...)`: Chevron butonuna, kapanıp açılma niyetini anlatan bir tooltip view bağlar. Closure her gösterimde `AnyView` döndürür ve tooltip'i altta üretilen `IconButton`'a iletir.
- `Clickable`: `.on_click(...)`, `.cursor_style(...)`.
- `Toggleable`: `.toggle_state(selected)`.
- `VisibleOnHover`: `.visible_on_hover(group_name)`.

Davranış:

- Açıkken varsayılan ikon `ChevronDown`; kapalıyken `ChevronRight`'tır.
- Render sonucu bir `IconButton` üzerinden gelir.
- `is_open` değeri bileşen içinde tutulan bir durum değildir; üst öğe her render işleminde güncel değeri vermelidir.
- **`Clickable::on_click` ve `on_toggle_expanded` aynı alanı yazar.** Kaynak implementasyon `on_click`'i `self.on_toggle_expanded = Some(Arc::new(handler))` olarak depolar; bu yüzden iki metot birlikte çağrılırsa **sonuncu** kazanır. Karışıklığı önlemek için yalnızca birinin kullanılması önerilir.

Örnek:

```rust
use ui::{Disclosure, prelude::*};

fn acilir_baslik_render(acik_mi: bool) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            Disclosure::new("gelismis-toggle", acik_mi)
                .on_click(|_, _window, cx| cx.stop_propagation()),
        )
        .child(Label::new("Gelişmiş"))
}
```

Zed içinden kullanım örnekleri:

- `ui` crate'i: Ağaç öğesi genişletme (tree item expansion).
- `agent_ui` crate'i: Plan, kuyruk ve düzenleme detay açılımları.
- `repl` crate'i: JSON düğüm genişletme (node expansion).

Dikkat Edilmesi Gereken Hususlar:

- Toggle durumu üst öğede tutulur ve tıklama işleyicisi bu durumu güncellemekle yükümlüdür.
- `visible_on_hover(...)` kullanıldığında üst elementte aynı grup adının (group name) tanımlanmış olması gerekir.

## GradientFade

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::GradientFade`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Hayır.

Tavsiye Edilen Kullanım Alanları:

- Sağ kenarda taşan bir içerik veya üzerine gelindiğinde beliren (hover) eylem alanı üzerinde yumuşak bir solma (fade) katmanı gerektiğinde.
- Kenar çubuğu satırı gibi tek satırda üstveri ile eylem geçişini maskelemek için.

Tercih Edilmemesi Gereken Durumlar:

- Genel bir arka plan dekorasyonu için bu bileşen tasarlanmamıştır.
- Kaydırma çubuğu (scrollbar) veya gerçek bir kırpma (clipping) işleminin yerine geçecek şekilde kullanılması doğru olmaz.

Temel API:

- `GradientFade::new(base_bg, hover_bg, active_bg)`.
- `.width(Pixels)`.
- `.right(Pixels)`.
- `.gradient_stop(f32)`.
- `.group_name(name)`.

Davranış:

- Mutlak konumlandırmalıdır (absolute); `top_0()`, `h_full()` ve sağ kenara bağlıdır.
- Renkleri uygulama arka planıyla harmanlayarak opaklık etkisi oluşturmaya çalışır.
- `group_name(...)` verildiğinde, üst öğenin hover veya active durumunda solma rengi otomatik olarak değişir.

Örnek:

```rust
use ui::{GradientFade, prelude::*};

fn solan_satir_render(cx: &App) -> impl IntoElement {
    let taban = cx.theme().colors().panel_background;
    let uzerine_gelme = cx.theme().colors().element_hover;

    h_flex()
        .group("ustveri-satiri")
        .relative()
        .overflow_hidden()
        .child(Label::new("Eyleme yakın yerde solan çok uzun bir üstveri değeri").truncate())
        .child(
            GradientFade::new(taban, uzerine_gelme, uzerine_gelme)
                .width(px(64.))
                .group_name("ustveri-satiri"),
        )
}
```

Zed içinden kullanım örnekleri:

- `ui` crate'i: Eylem alanı ve üstveri solma katmanı.
- `sidebar` crate'i: Kenar çubuğu satırı üzerine gelme solması.

Dikkat Edilmesi Gereken Hususlar:

- Üst elemanın `relative()` ve `overflow_hidden()` olması gerekir; aksi halde solma efekti beklenen konuma oturmaz.
- Solma efekti gerçek bir yerleşim alanı ayırmaz. Eylem alanı veya sonda görünen içerik için ayrıca kenar boşluğu (padding) ya da boşluk bırakılması gerekir.

## Divider ve Grup Yardımcıları

Kaynak:

- Divider: `ui` crate'i
- Grup yardımcıları: `ui` crate'i
- Export: `ui::Divider`, `ui::DividerColor`, `ui::divider`, `ui::vertical_divider`, `ui::h_flex`, `ui::v_flex`, `ui::h_group*`, `ui::v_group*`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Divider`.

Tavsiye Edilen Kullanım Alanları:

- Aynı panel içinde iki görsel grubu ince bir çizgiyle ayırmak için `Divider`.
- Araç çubukları, üstveriler veya kısa yığın düzenlerinde tutarlı küçük boşluklar için `h_group*` ve `v_group*`.
- Basit yardımcı fonksiyonuyla hızlı bölücü üretmek için `divider()` veya `vertical_divider()`.

Tercih Edilmemesi Gereken Durumlar:

- Menü içindeki ayrım için `ContextMenu::separator()` kullanılır; menü ayırıcısı odak ve öğe ölçüleriyle uyumlu gelir.
- Liste bölüm başlığı gerekiyorsa `ListHeader` veya `ListSubHeader` daha doğru semantiktir.
- Genel sayfa bölümlerini ayırmak için büyük dekoratif çizgiler eklemek yerine yerleşim boşluğu ve gerçek bölüm (section) başlığı tercih edilir.

Temel API:

- `Divider::horizontal()`, `Divider::vertical()`, `Divider::horizontal_dashed()`, `Divider::vertical_dashed()`.
- `.inset()` divider'ın kendi yönüne göre iç kenar boşluğu (margin) uygular.
- `.color(DividerColor::Border | BorderFaded | BorderVariant)`.
- `Divider` `Styled` uygular; `.inset()`/`.color(...)` dışındaki genişlik, kenar boşluğu gibi yerleşim ince ayarları doğrudan `gpui` stil zinciriyle eklenir.
- `divider()` yatay solid divider, `vertical_divider()` dikey solid divider döndürür.
- `h_flex()` yatay bir esnek kutu kapsayıcısı döndürür ve `items_center()` uygular. `v_flex()` ise dikey bir esnek kutu kapsayıcısı döndürür. Bunlar sırasıyla `div().h_flex()` ve `div().v_flex()` çağrılarını daha okunabilir hale getiren temel kısayollardır.
- `h_group_sm()`, `h_group()`, `h_group_lg()`, `h_group_xl()` sırasıyla yaklaşık 2px, 4px, 6px, 8px yatay boşluk (gap) verir.
- `v_group_sm()`, `v_group()`, `v_group_lg()`, `v_group_xl()` aynı ölçeği dikey esnek kutu kapsayıcısı için uygular.

Divider ve grup yardımcıları tablosu:

| API | Rol |
| :-- | :-- |
| `DividerColor` | Bölücü rengini `Border`, `BorderFaded` veya `BorderVariant` tema belirteçlerinden seçer. |
| `divider` | Yatay solid divider üretir; kısa araç çubuğu veya panel ayrımlarında `Divider::horizontal()` kısayoludur. |
| `vertical_divider` | Dikey solid divider üretir; üst öğe yüksekliği belirli ise araç çubuğu ayrımı için kullanılır. |
| `v_group_sm` | Dikey esnek kutu kapsayıcısına küçük, yaklaşık 2px boşluk verir. |
| `v_group_lg` | Dikey esnek kutu kapsayıcısına orta-büyük, yaklaşık 6px boşluk verir. |
| `v_group_xl` | Dikey esnek kutu kapsayıcısına büyük, yaklaşık 8px boşluk verir. |

Davranış:

- Solid divider doğrudan tema sınır (border) rengini arka plan olarak kullanır.
- Dashed divider, GPUI `canvas(...)` üzerinde `PathBuilder` ile çizilir; bu yüzden çizgi üst öğe sınırlarına bağlıdır.
- `h_flex()` ve `v_flex()` boşluk vermez. `h_flex()` yatay yönle birlikte `items_center()` uygular; `v_flex()` dikey yön seçer. Grup yardımcıları ise aynı temel kapsayıcıya küçük sabit boşluklar uygular. Başka renk veya border eklemezler.

Örnek:

```rust
use ui::{Divider, DividerColor, h_group, prelude::*};

fn arac_cubugu_ayirici_render() -> impl IntoElement {
    h_group()
        .items_center()
        .child(IconButton::new("onceki", IconName::ArrowLeft))
        .child(Divider::vertical().color(DividerColor::BorderFaded).inset())
        .child(IconButton::new("sonraki", IconName::ArrowRight))
}
```

Dikkat Edilmesi Gereken Hususlar:

- Dikey divider'ın görünmesi için üst öğenin yüksekliği belirli olmalıdır; aksi halde `h_full()` hizalama için anlamlı bir alan bulamayabilir.
- Grup yardımcıları yoğun ve kısa UI parçaları içindir. Form, modal veya liste bölümlerinde (sections) `DynamicSpacing` ile açık boşluk seçmek daha okunabilir sonuçlar verir.

## Vector ve Görsel Kullanımı

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Vector`, `ui::VectorName`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Vector`.

Tavsiye Edilen Kullanım Alanları:

- Zed içinde paketlenmiş SVG görsellerini belirli bir boyutta render etmek için.
- Logo, damga veya ürün işareti gibi standart ikon ailesine girmeyen vektörler için.

Tercih Edilmemesi Gereken Durumlar:

- Standart bir simge için `Icon` doğru yüzeydir.
- Bir kullanıcı avatarı için `Avatar` kullanılır.
- Raster veya dış kaynaklı bir görsel için GPUI tarafındaki `img(...)` ile `ImageSource` devreye girer.

Temel API:

- `Vector::new(VectorName, width: Rems, height: Rems)`.
- `Vector::square(VectorName, size: Rems)`.
- `.color(Color)`.
- `.size(Size<Rems>)`.
- `CommonAnimationExt` üzerinden `.with_rotate_animation(duration)`.
- `VectorName`: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`, `StudentStamp`, `ZedLogo`, `ZedXCopilot`.

Vector enum yardımcıları:

| API | Rol |
| :-- | :-- |
| `VectorNameIter` | Önizleme ve doğrulama araçlarında paketlenmiş vektör adlarını dolaşmak için kullanılan iteratördür. |

Davranış:

- `VectorName::path()` çağrısı `images/<name>.svg` yolunu üretir.
- SVG, `flex_none()` ile birlikte verilen genişlik (width) ve yükseklik (height) rem değerleri üzerinden render edilir.
- Vector, `.color(...)` ayarını SVG'ye `text_color(...)` üzerinden uygular.

Örnek:

```rust
use ui::{Vector, VectorName, prelude::*};

fn zed_isareti_render() -> impl IntoElement {
    Vector::square(VectorName::ZedLogo, rems(3.)).color(Color::Accent)
}
```

Dikkat Edilmesi Gereken Hususlar:

- `Image` adında dışa açık bir Zed UI bileşeni yoktur. Rehberde bir görsel ihtiyacı varsa `Vector`, `Avatar`, `Icon` ve GPUI `img(...)` ayrımı yapılır.
- `VectorName` yalnızca kaynakta tanımlanmış olan paketlenmiş asset'leri kapsar; dışarıdan yeni isim eklenmez.

GPUI `img(...)` ve `ImageSource` (raster veya dış görsel için) şu şekilde kullanılır:

```rust
use gpui::{ImageSource, SharedUri, img};
use ui::prelude::*;

fn uzak_kucuk_gorsel_render() -> impl IntoElement {
    img(ImageSource::from(SharedUri::from(
        "https://zed.dev/img/banner.png",
    )))
    .size(px(96.))
    .rounded_md()
}

fn yerel_kucuk_gorsel_render() -> impl IntoElement {
    img(ImageSource::from(std::path::Path::new("/tmp/preview.png")))
        .size(px(96.))
        .rounded_md()
}
```

`ImageSource` aşağıdaki kaynaklardan otomatik dönüşür:

| Kaynak | Notlar |
| :-- | :-- |
| `&str`, `String`, `SharedString` | URL ise `Resource::Uri` olarak asenkron yüklenir; URL değilse embedded resource adı olarak değerlendirilir. |
| `SharedUri` | Tip güvenli URL gösterimi sağlar; `Avatar::new("https://...")` URL string'iyle örtük olarak aynı kaynak türüne gider. |
| `&Path`, `PathBuf`, `Arc<Path>` | Dosya sistemi yolu olarak `Resource::Path` üzerinden okunur. |
| `Arc<RenderImage>`, `Arc<Image>` | Önceden hazırlanmış/cached image verisini doğrudan taşır. |
| `Fn(&mut Window, &mut App) -> Option<Result<Arc<RenderImage>, ImageCacheError>>` | Çağrı sırasında dinamik kaynak üretmek için kullanılır. |

`Avatar::new`, bu `Into<ImageSource>` zincirinin üzerine kuruludur. Ham bir `img(...)` kullanılırken `flex_none()` ve sabit bir `size(...)` verilmediğinde yerleşim taşmaları yaşanması olasıdır. SVG bir ikon için her zaman `Icon` veya `Vector` tercih edilir; `img(...)` SVG yollarını raster gibi ele aldığından yeniden renklendirme (recolor) yapamaz.

## KeyBinding

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::KeyBinding`, `ui::Key`, `ui::KeyIcon`, `ui::render_keybinding_keystroke`, `ui::text_for_action`, `ui::text_for_keystrokes`, `ui::text_for_keybinding_keystrokes`, `ui::render_modifiers`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for KeyBinding`.

Tavsiye Edilen Kullanım Alanları:

- UI içinde bir action'a bağlı kısayol göstermek için.
- Açıkça verilen bir keystroke dizisini platforma uygun tuş görseli olarak render etmek için.
- Tooltip, komut paleti (command palette) veya bir ayar satırında klavye kısayolu göstermek için.

Tercih Edilmemesi Gereken Durumlar:

- Keymap'e yeni bir binding tanımlamak için `gpui::KeyBinding` kullanılır; UI tarafındaki tip bu amaç için değildir.
- Yalnızca açıklayıcı bir metin gerekiyorsa `text_for_action(...)` veya bir `Label` daha uygundur.

Temel API:

- `KeyBinding::for_action(action, cx)`.
- `KeyBinding::for_action_in(action, focus_handle, cx)`.
- `KeyBinding::new(action, focus_handle, cx)`.
- `KeyBinding::from_keystrokes(keystrokes, vim_mode)`.
- `.platform_style(PlatformStyle)`.
- `.size(size)`.
- `.disabled(bool)`.
- `.has_binding(window)`.
- `KeyBinding::set_vim_mode(cx, enabled)`.
- `Key::new(key: impl Into<SharedString>, color: Option<Color>)` ve `KeyIcon::new(icon: IconName, color: Option<Color>)`: Tekil tuş veya ikonlu tuş yüzeyi.
- `render_modifiers(modifiers: &Modifiers, platform_style: PlatformStyle, color: Option<Color>, size: Option<AbsoluteLength>, trailing_separator: bool) -> impl Iterator<Item = AnyElement>`: Modifier dizisini platform stiline göre ikon veya metin elementlerine çeviren düşük seviyeli yardımcı. `trailing_separator`, son modifier'dan sonra bir ayırıcı ekler; ancak bu ayırıcı yalnızca Linux ve Windows stilinde `+` olduğundan, macOS stilinde ayırıcı bulunmaz ve bayrak burada etkisiz kalır.
- `text_for_keystroke(modifiers: &Modifiers, key: &str, cx: &App) -> String`: Tek bir keystroke için platforma duyarlı bir metin üretir.

Keybinding yardımcı yüzeyi:

| API | Rol |
| :-- | :-- |
| `Key` | Tekil metinsel tuş kapsülünü render eder; `.size(...)` ile ölçüsü ayarlanır. |
| `KeyIcon` | Tuş kapsülü içinde ikon render eder; platform stili ikon gerektirdiğinde kullanılır. |
| `render_keybinding_keystroke` | Tek bir `KeybindingKeystroke` değerini platforma uygun tuş elementleri dizisine çevirir. |
| `render_modifiers` | Modifier listesini macOS'ta ikon, diğer platformlarda metin ve separator olarak render eder. |
| `text_for_action` | Bir eylem için geçerli binding metnini eylem haritası (action map) üzerinden üretir. |
| `text_for_keystrokes` | Keystroke dizisini platforma uygun okunabilir metne çevirir. |
| `text_for_keybinding_keystrokes` | `KeybindingKeystroke` koleksiyonunu kullanıcıya gösterilecek kısayol metnine dönüştürür. |
| `text_for_keystroke` | Tek bir modifier/key çiftinden platforma uygun kısayol metni üretir. |

Davranış:

- Eylem kaynağı (action source) kullanıldığında penceredeki en yüksek öncelikli binding aranır.
- Bir focus handle verildiğinde, action için önce odak bağlamındaki binding aranır.
- Binding bulunamadığında `Empty` render edilir.
- Platform stili macOS için modifier ikonlarını, Linux ve Windows için ise metin ve `+` ayırıcılarını kullanır.
- `.platform_style(...)` alanı set eder, ancak mevcut render gövdesi doğrudan `PlatformStyle::platform()` kullanır. Belirli bir platform stilini zorlamak istediğinizde düşük seviyeli `render_keybinding_keystroke(...)` veya `render_modifiers(...)` yardımcılarına platform stilini açıkça verirsiniz.
- `.has_binding(window)` mevcut kaynakta yalnız focus handle'lı eylem kaynağı için `true` dönebilir; `for_action(...)` ile focus handle verilmeden oluşturulan bileşende render yine binding arar, ancak `has_binding(...)` kontrolü `false` kalır.

Örnek:

```rust
use gpui::{AnyElement, KeybindingKeystroke, Keystroke};
use ui::{KeyBinding, prelude::*};

fn kaydet_kisayolu_render() -> AnyElement {
    let Ok(cozumlenen) = Keystroke::parse("cmd-s") else {
        return div().into_any_element();
    };
    let tus_vurusu = KeybindingKeystroke::from_keystroke(cozumlenen);

    KeyBinding::from_keystrokes(vec![tus_vurusu].into(), false).into_any_element()
}
```

Dikkat Edilmesi Gereken Hususlar:

- `ui::KeyBinding` ile `gpui::KeyBinding` aynı dosyada birlikte import edilirken ikisine de takma ad (alias) tanımlanması okunabilirliği artırır.
- Bir eyleme bağlı kısayol gösterilirken binding bulunamama durumunun UI'da düşünülmesi gerekir; çünkü bileşen bu durumda boş render edebilir.

## KeybindingHint

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::KeybindingHint`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for KeybindingHint`.

Tavsiye Edilen Kullanım Alanları:

- Bir kısayolu prefix veya suffix metniyle birlikte açıklamak için.
- Tooltip veya boş durum içinde kısa bir klavye ipucu göstermek için.

Temel API:

- `KeybindingHint::new(keybinding, background_color)`.
- `KeybindingHint::with_prefix(prefix, keybinding, background_color)`.
- `KeybindingHint::with_suffix(keybinding, suffix, background_color)`.
- `.prefix(text)`.
- `.suffix(text)`.
- `.size(Pixels)`.

Davranış:

- Prefix ve suffix metni italik buffer yazı tipi ile render edilir.
- Keybinding parçası bir border, subtle bir arka plan ve hafif bir gölge alır.
- Arka plan rengi, tema metni ve vurgu renkleriyle harmanlanarak ipucu yüzeyi oluşturulur.

Örnek:

```rust
use gpui::{AnyElement, KeybindingKeystroke, Keystroke};
use ui::{KeyBinding, KeybindingHint, prelude::*};

fn komut_ipucu_render(cx: &App) -> AnyElement {
    let Ok(cozumlenen) = Keystroke::parse("cmd-shift-p") else {
        return div().into_any_element();
    };
    let tus_vurusu = KeybindingKeystroke::from_keystroke(cozumlenen);
    let baglama = KeyBinding::from_keystrokes(vec![tus_vurusu].into(), false);

    KeybindingHint::new(baglama, cx.theme().colors().surface_background)
        .prefix("Komut paletini aç:")
        .into_any_element()
}
```

Zed içinden kullanım örnekleri:

- `settings_ui` crate'i: Ayar UI kısayol ipuçları.
- `git_ui` crate'i: Modal kısayol ipucu.

Dikkat Edilmesi Gereken Hususlar:

- `background_color` değerinin üst öğe yüzeyine yakın seçilmesi gerekir; hint kendi border ve fill rengini bu değerden türetir.
- Çok uzun bir prefix veya suffix yazılmaz; bileşen kısa komut açıklamaları için tasarlanmıştır.

## Navigable

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Navigable`, `ui::NavigableEntry`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Hayır.

Tavsiye Edilen Kullanım Alanları:

- Kaydırılabilir bir görünüm içinde `menu::SelectNext` ve `menu::SelectPrevious` aksiyonlarıyla bir klavye gezintisi kurmak için.
- Focus handle ve kaydırma çıpası (scroll anchor) listesini tek bir sarmalayıcıya (wrapper) bağlamak için.

Temel API:

- `NavigableEntry::new(scroll_handle, cx)`.
- `NavigableEntry::focusable(cx)`.
- `Navigable::new(child: AnyElement)`.
- `.entry(NavigableEntry)`.
- `NavigableEntry` dışa açık alanları: `focus_handle` ve `scroll_anchor: Option<ScrollAnchor>`. `new(...)` scroll anchor'lı bir entry üretir; `focusable(...)` ise `scroll_anchor: None` olan bir entry döndürür.

Navigable entry:

| API | Rol |
| :-- | :-- |
| `NavigableEntry` | Klavye traversal sırasında odaklanılacak tutamacı (focus handle) ve isteğe bağlı kaydırma çıpasını birlikte taşır. |

Davranış:

- Entry'lerin ekleme sırası, gezinti sırasıdır.
- `SelectNext` veya `SelectPrevious` eylemi odaklanmış girdiyi bulur, hedef girdinin odak tutamacına odaklanır ve bir scroll anchor varsa görünür alana kaydırma yapar.
- `NavigableEntry::focusable(...)`, scroll anchor olmadan odaklanılabilir bir girdi üretir.

Örnek:

```rust
use gpui::ScrollHandle;
use ui::{Navigable, NavigableEntry, prelude::*};

fn gezilebilir_satirlar_render(scroll_handle: &ScrollHandle, cx: &App) -> impl IntoElement {
    let ilk = NavigableEntry::new(scroll_handle, cx);
    let ikinci = NavigableEntry::new(scroll_handle, cx);

    let content = v_flex()
        .child(div().track_focus(&ilk.focus_handle).child(Label::new("İlk")))
        .child(div().track_focus(&ikinci.focus_handle).child(Label::new("İkinci")));

    Navigable::new(content.into_any_element())
        .entry(ilk)
        .entry(ikinci)
}
```

Dikkat Edilmesi Gereken Hususlar:

- Sarmalayıcı (wrapper) yalnızca eylem yönlendirme (action routing) ile odak/kaydırma geçişini kurar; her çocuk öğenin kendisi yine `track_focus` ile odak takibi yapmalıdır.
- Girdi (entry) listesini, render edilen öğe sırasıyla aynı tutmak gerekir; aksi halde gezinti beklenmedik bir sıraya kayar.

## ProjectEmptyState

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ProjectEmptyState`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: Doğrudan `impl Component` yoktur.

Tavsiye Edilen Kullanım Alanları:

- Bir panel veya yan panel bir proje veya çalışma ağacı olmadan açıldığında aynı boş durum eylemlerini göstermek için.
- `"Open Project"` ve `"Clone Repository"` seçeneklerinin aynı odak, kısayol ve boşluk düzeniyle görünmesinin istendiği yerlerde.

Temel API:

- Constructor: `ProjectEmptyState::new(label, focus_handle, open_project_key_binding)`.
- `.on_open_project(handler)`.
- `.on_clone_repo(handler)`.

Davranış:

- Render edilen kök, bir `v_flex()` içinde `track_focus(&focus_handle)` çağrısı yapar.
- Üst metni `Choose one of the options below to use the {label}` biçiminde render eder.
- İlk eylemi `Button::new("open_project", "Open Project")` ve verilen `KeyBinding` ile render eder; ikinci eylem ise `Button::new("clone_repo", "Clone Repository")` olarak gelir.
- İki eylem arasında bir `Divider::horizontal().color(DividerColor::Border)` ile küçük bir `"or"` etiketi render eder.

Örnek:

```rust
use gpui::FocusHandle;
use ui::{KeyBinding, ProjectEmptyState, prelude::*};

fn bos_panel_render(
    focus_handle: FocusHandle,
    open_project_key_binding: KeyBinding,
) -> impl IntoElement {
    ProjectEmptyState::new("Proje Paneli", focus_handle, open_project_key_binding)
        .on_open_project(|_, window, cx| {
            window.dispatch_action(workspace::Open::default().boxed_clone(), cx);
        })
        .on_clone_repo(|_, window, cx| {
            window.dispatch_action(git::Clone.boxed_clone(), cx);
        })
}
```

Zed içinden kullanım örnekleri:

- `project_panel` crate'i: Proje çalışma ağacı (worktree) yokken proje paneli boş durumu.
- `agent_ui` crate'i: Proje yokken yapay zeka temsilcisi paneli boş durumu.
- `git_ui` crate'i: Çalışma ağacı yokken git paneli boş durumu.
- `sidebar` crate'i: Konuşma başlıkları (threads) kenar çubuğu boş proje durumu.

Dikkat Edilmesi Gereken Hususlar:

- Bu bileşen yalnızca iki standart proje eylemini render eder. Farklı aksiyon setleri veya farklı bir açıklama metni gerekiyorsa, özel bir `v_flex()` yerleşimi kurmak daha doğru bir tercih olur.
- İşleyici (handler) verilmediğinde ilgili buton yine render edilir ama tıklama davranışı bağlanmaz.

## UI Yardımcı Fonksiyonları ve Ölçü Araçları

Kaynak:

- Modül: `ui` crate'i
- Alt modüller: `utils/apca_contrast`, `utils/color_contrast`, `utils/constants`, `utils/corner_solver`, `utils/format_distance`, `utils/search_input`, `utils/with_rem_size`.
- Export: `ui::utils::*`.
- Prelude: Hayır; `use ui::utils::{...};` ile açıkça import edilir.

Tavsiye Edilen Kullanım Alanları:

- Tema açık/koyu bilgisini veya kontrast hesabını özel çizimlerde kullanmak için.
- Başlık çubuğu (title bar), köşe yuvarlama (corner radius), arama girdisi genişliği (search input width) veya rem ölçeği gibi düşük seviyeli yerleşim hesaplarında.
- Kullanıcıya göreceli tarih metni ya da platforma uygun "Reveal in ..." etiketi göstermek için.

Tercih Edilmemesi Gereken Durumlar:

- Hazır bileşen zaten bu hesabı yapıyorsa aynı davranışı dışarıda tekrar hesaplamaya gerek yoktur. Örneğin `Label`, `Button`, `Callout` ve `Banner` renk/token kararlarını kendi içlerinde verirler.
- Genel iş mantığı veya domain formatlama için `ui::utils` modülüne bağımlı hale gelinmez. Bu modül sadece UI kararları içindir.
- Yerelleştirmeye duyarlı (locale-aware) metin dönüşümü gerekiyorsa `capitalize(...)` yeterli değildir; sadece ilk karakteri büyütür.

Temel API:

- Tema ve metin: `is_light(cx)`, `reveal_in_file_manager_label(is_remote)`, `capitalize(str)`.
- Kontrast: `calculate_contrast_ratio(fg, bg)`, `apca_contrast(text_color, background_color)`, `ensure_minimum_contrast(foreground, background, minimum_apca_contrast)`.
- Title bar ölçüleri: `TRAFFIC_LIGHT_PADDING`, `MACOS_SDK_26_OR_LATER`, `platform_title_bar_height(window)`.
- Köşe yuvarlama hesapları: `inner_corner_radius(...)`, `CornerSolver::new(root_radius, root_border, root_padding).add_child(border, padding).corner_radius(level)`.
- Arama genişliği: `SearchInputWidth::THRESHOLD_WIDTH`, `SearchInputWidth::MAX_WIDTH`, `SearchInputWidth::calc_width(container_width)`.
- Rem geçersiz kılma: `WithRemSize::new(rem_size).occlude()`.
- Tarih metni: `DateTimeType::Naive(...)`, `DateTimeType::Local(...)`, `DateTimeType::to_naive()`, `FormatDistance::new(date, base_date)`, `FormatDistance::from_now(date)`, `.include_seconds(...)`, `.add_suffix(...)`, `.hide_prefix(...)`, `format_distance(...)`, `format_distance_from_now(...)`.

Utils alt modülleri:

| API | Rol |
| :-- | :-- |
| `color_contrast` | Kontrast oranı ve APCA tabanlı minimum kontrast hesaplarını taşıyan yardımcı modüldür. |
| `constants` | Başlık çubuğu kenar boşlukları ve platforma bağlı UI ölçü sabitlerini barındırır. |
| `search_input` | `SearchInputWidth` ile arama girdisi genişlik hesabını sağlar; arama girdisini kendisi render etmez. |
| `with_rem_size` | Alt ağacı farklı rem boyutu ile layout/prepaint etmek için `WithRemSize` yüzeyini sağlar. |

Davranış:

- `is_light(cx)`, etkin tema appearance değerini okur. Özel tuval (canvas) ya da görsel katmanı (image overlay) gibi hazır bileşenin kapsamadığı görsel hesaplamalarda kullanılır.
- APCA sonucu pozitifse koyu metin/açık arka plan, negatifse açık metin/koyu arka plan kutupsallığını (polarity) ifade eder. `ensure_minimum_contrast(...)`, ön plan parlaklık (lightness) değerini değiştirerek eşik sağlamaya çalışır.
- `platform_title_bar_height(window)`, Windows'ta 32px döndürür; diğer platformlarda rem boyutuna bağlı, minimum 34px olan bir değer üretir.
- `WithRemSize`, alt ağacı farklı bir rem boyutu ile layout/prepaint eder. `.occlude()` işaretçi olaylarının (pointer events) alt çocuklara ulaşmasını engeller.
- `FormatDistance` `Display` implement eder; kurucu (builder) zinciri sonunda `.to_string()` ile göreceli metne çevrilebilir.

Örnek:

```rust
use chrono::Local;
use ui::{
    prelude::*,
    utils::{DateTimeType, FormatDistance, SearchInputWidth},
    v_group,
};

fn arama_aciklamasi_render(kapsayici_genisligi: Pixels) -> impl IntoElement {
    let giris_genisligi = SearchInputWidth::calc_width(kapsayici_genisligi);
    let guncellenme_zamani = FormatDistance::from_now(DateTimeType::Local(Local::now()))
        .add_suffix(true)
        .to_string();

    v_group()
        .child(div().w(giris_genisligi).child(Label::new("Ara")))
        .child(Label::new(guncellenme_zamani).size(LabelSize::Small).color(Color::Muted))
}
```

Dikkat Edilmesi Gereken Hususlar:

- `format_distance_from_now(...)` çağrısı anlık olarak `Local::now()` okur. Kararlı (deterministic) test veya snapshot üretirken `FormatDistance::new(date, base_date)` kullanımı daha kontrollüdür.
- `SearchInputWidth::calc_width(...)` yalnızca genişlik hesabı yapar; girdiyi kendisi render etmez.
- `TRAFFIC_LIGHT_PADDING` değeri dışa açık `MACOS_SDK_26_OR_LATER` sabitine (macOS SDK 26 ve sonrası derlemelerde `true`) bağlıdır: doğruysa 78px, değilse 71px. Başlık çubuğu dışı genel kenar boşlukları için kullanılmamalıdır.
