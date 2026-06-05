# 14. Genel Yardımcı Bileşenler

Bu bölümdeki bileşenler tek bir amaca hizmet eden küçük yapı taşlarıdır. Çoğunlukla görsel bir yardımcı, klavye ipucu veya gezinti yüzeyi sunarlar. Liste satırı, araç çubuğu, panel başlığı veya boş durum gibi alanlarda önceki bölümlerdeki büyük bileşenlerin yanında sık kullanılırlar. Küçük görünseler de ekranın okunabilirliğini ve etkileşim kalitesini doğrudan etkilerler.

Bu aileyi kullanırken üç ayrımı akılda tutmak işini kolaylaştırır:

- `ui::KeyBinding` ile `gpui::KeyBinding` aynı adı taşısa da farklı şeylerdir. UI tarafındaki bileşen kısayolu görsel olarak render eder; GPUI tarafındaki tip ise keymap'e bir binding tanımlar.
- `Image` adında dışa açık bir Zed UI bileşeni yoktur. Paketlenmiş SVG için `Vector` kullanılır; raster veya dış kaynaklı görsel için GPUI tarafındaki `img(...)` ve `ImageSource` yüzeyi devreye girer.
- Disclosure, Chip ve DiffStat gibi kompakt parçalar liste veya araç çubuğu içinde kullanılırken üst kapsayıcıya `min_w_0` ve uygun gap'ler vermek taşma kontrolünü ciddi biçimde kolaylaştırır.

## Chip

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Chip`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Chip`.

Ne zaman kullanırsın:

- Filtre, plan adı, sağlayıcı tipi, dal adı, üstveri veya küçük bir durum etiketi göstermek için.
- İkon ile kısa etiket kombinasyonunu düşük vurgu ile göstermek için.

Ne zaman kullanmazsın:

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
- Etiket, buffer font ile render edilir.
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

- `extensions_ui` crate'i: extension capability etiketleri.
- `agent_ui` crate'i: model üstverisi ve maliyet bilgisi.
- `title_bar` crate'i: plan adı gösterimi.

Dikkat edeceğin noktalar:

- Chip küçük bir bilgi kapsülüdür; birincil eylem yerine kullanmaman gerekir.
- Özel arka plan kullanılıyorsa border renginin de bu seçimle uyumlu olması görsel tutarlılığı korur.
- Dar bir araç çubuğu içinde `.truncate()` olmadan uzun bir etiket kullanmak yerleşimi bozabilir.

## DiffStat

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::DiffStat`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for DiffStat`.

Ne zaman kullanırsın:

- Eklenen ve silinen satır sayılarını kompakt biçimde göstermek için.
- Commit, dal, thread veya dosya diff üstverisinin yanında.

Ne zaman kullanmazsın:

- Ayrıntılı bir dosya diff görünümü için bu bileşen yeterli değildir.
- Yalnızca toplam değişiklik sayısı gerekiyorsa bir `Label` veya `CountBadge` daha doğru bir araç olur.

Temel API:

- `DiffStat::new(id, added, removed)`.
- `.label_size(LabelSize)`.
- `.tooltip(text)`.

Davranış:

- Added değeri `Color::Success`, removed değeri ise `Color::Error` ile render edilir.
- Removed etiketi görsel olarak typographic minus karakterini kullanır.
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

- `agent_ui` crate'i: tool result ve thread değişiklik özetleri.
- `git_ui` crate'i: project diff üstverisi.
- `git_graph` crate'i: commit üstverisi.

Dikkat edeceğin noktalar:

- Verilen `id` değerinin sabit olması beklenir; aynı listede tekrar eden bir id kullanmak hatalı davranışa yol açar.
- Sıfır değerlerinin gösterilip gösterilmeyeceğine üst öğe karar verir; bileşen kendiliğinden gizlemez.

## Disclosure

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Disclosure`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Disclosure`.

Ne zaman kullanırsın:

- Açılır veya kapanır bir bölüm, bir tree satırı ya da bir detay satırı için chevron butonu gerektiğinde.
- Üst öğenin açılma durumunu tuttuğu kontrollü bir toggle için.

Ne zaman kullanmazsın:

- Tam satır bir tree davranışı gerekiyorsa `TreeViewItem` çok daha hazır bir davranış sağlar.
- Yalnızca görsel bir chevron yeterliyse, bir `Icon` daha sade bir çözüm sunar.

Temel API:

- `Disclosure::new(id, is_open)`.
- `.on_toggle_expanded(handler)`.
- `.opened_icon(IconName)`.
- `.closed_icon(IconName)`.
- `.disabled(bool)`.
- `.tooltip(|window, cx| ...)`: chevron butonuna, kapanıp açılma niyetini anlatan bir tooltip view bağlar. Closure her gösterimde `AnyView` döndürür ve tooltip'i altta üretilen `IconButton`'a iletir.
- `Clickable`: `.on_click(...)`, `.cursor_style(...)`.
- `Toggleable`: `.toggle_state(selected)`.
- `VisibleOnHover`: `.visible_on_hover(group_name)`.

Davranış:

- Açıkken default ikon `ChevronDown`; kapalıyken `ChevronRight`'tır.
- Render sonucu bir `IconButton` üzerinden gelir.
- `is_open` değeri bileşen içinde tutulan bir durum değildir; üst öğe her render'da güncel değeri vermelidir.
- **`Clickable::on_click` ve `on_toggle_expanded` aynı slotu yazar.** Kaynak implementasyon `on_click`'i `self.on_toggle_expanded = Some(Arc::new(handler))` olarak depolar; bu yüzden iki metod birlikte çağrılırsa **sonuncu** kazanır. Karışıklığı önlemek için yalnızca birinin kullanılması önerilir.

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

- `ui` crate'i: tree item expansion.
- `agent_ui` crate'i: plan, queue ve edit detay açılımları.
- `repl` crate'i: JSON node expansion.

Dikkat edeceğin noktalar:

- Toggle durumu üst öğede tutulur ve click işleyicisi bu durumu güncellemekle yükümlüdür.
- `visible_on_hover(...)` kullanıldığında üst elementte aynı group name'in tanımlanmış olması gerekir.

## GradientFade

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::GradientFade`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: Hayır.

Ne zaman kullanırsın:

- Sağ kenarda taşan bir içerik veya hover eylem alanı üzerinde yumuşak bir fade katmanı gerektiğinde.
- Sidebar satırı gibi tek satırda üstveri ile eylem geçişini maskelemek için.

Ne zaman kullanmazsın:

- Genel bir arka plan dekorasyonu için bu bileşen tasarlanmamıştır.
- Scrollbar veya gerçek bir clipping'in yerine geçecek şekilde kullanılması doğru olmaz.

Temel API:

- `GradientFade::new(base_bg, hover_bg, active_bg)`.
- `.width(Pixels)`.
- `.right(Pixels)`.
- `.gradient_stop(f32)`.
- `.group_name(name)`.

Davranış:

- Absolute pozisyonludur; `top_0()`, `h_full()` ve sağ kenara bağlıdır.
- Renkleri app arka planıyla blend ederek opaklık etkisi yaratmaya çalışır.
- `group_name(...)` verildiğinde, üst öğe hover veya active durumunda gradient rengi otomatik olarak değişir.

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

- `ui` crate'i: eylem alanı ve üstveri fade katmanı.
- `sidebar` crate'i: sidebar satır hover fade.

Dikkat edeceğin noktalar:

- Üst elemanın `relative()` ve `overflow_hidden()` olması gerekir; aksi halde fade beklenen konuma oturmaz.
- Fade gerçek bir yerleşim alanı ayırmaz. Eylem alanı veya sonda görünen içerik için ayrıca padding ya da boşluk bırakılması gerekir.

## Divider ve group yardımcıları

Kaynak:

- Divider: `ui` crate'i
- Group yardımcıları: `ui` crate'i
- Export: `ui::Divider`, `ui::DividerColor`, `ui::divider`, `ui::vertical_divider`, `ui::h_flex`, `ui::v_flex`, `ui::h_group*`, `ui::v_group*`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Divider`.

Ne zaman kullanırsın:

- Aynı panel içinde iki görsel grubu ince bir çizgiyle ayırmak için `Divider`.
- Araç çubuğu, üstveri veya kısa stack düzenlerinde tutarlı küçük gap'ler için `h_group*` ve `v_group*`.
- Basit yardımcı fonksiyonuyla hızlı divider üretmek için `divider()` veya `vertical_divider()`.

Ne zaman kullanmazsın:

- Menü içindeki ayrım için `ContextMenu::separator()` kullanırsın; menu separator'ı focus ve öğe ölçüleriyle uyumlu gelir.
- Liste bölüm başlığı gerekiyorsa `ListHeader` veya `ListSubHeader` daha doğru semantiktir.
- Genel sayfa bölümü ayırmak için büyük dekoratif çizgiler eklemek yerine yerleşim boşluğu ve gerçek section başlığı tercih edilir.

Temel API:

- `Divider::horizontal()`, `Divider::vertical()`, `Divider::horizontal_dashed()`, `Divider::vertical_dashed()`.
- `.inset()` divider'ın kendi yönüne göre iç margin uygular.
- `.color(DividerColor::Border | BorderFaded | BorderVariant)`.
- `divider()` yatay solid divider, `vertical_divider()` dikey solid divider döndürür.
- `h_flex()` yatay bir flex kapsayıcı döndürür ve `items_center()` uygular. `v_flex()` ise dikey bir flex kapsayıcı döndürür. Bunlar sırasıyla `div().h_flex()` ve `div().v_flex()` çağrılarını daha okunur hale getiren temel kısayollardır.
- `h_group_sm()`, `h_group()`, `h_group_lg()`, `h_group_xl()` sırasıyla yaklaşık 2px, 4px, 6px, 8px yatay gap verir.
- `v_group_sm()`, `v_group()`, `v_group_lg()`, `v_group_xl()` aynı ölçeği dikey flex kapsayıcı için uygular.

Divider ve group yardımcı kapsamı:

| API | Rol |
| :-- | :-- |
| `DividerColor` | Divider rengini `Border`, `BorderFaded` veya `BorderVariant` tema token'ından seçer. |
| `divider` | Yatay solid divider üretir; kısa araç çubuğu veya panel ayrımlarında `Divider::horizontal()` kısayoludur. |
| `vertical_divider` | Dikey solid divider üretir; üst öğe yüksekliği belirliyse araç çubuğu ayrımı için kullanılır. |
| `v_group_sm` | Dikey flex kapsayıcıya küçük, yaklaşık 2px gap verir. |
| `v_group_lg` | Dikey flex kapsayıcıya orta-büyük, yaklaşık 6px gap verir. |
| `v_group_xl` | Dikey flex kapsayıcıya büyük, yaklaşık 8px gap verir. |

Davranış:

- Solid divider doğrudan tema border rengini arka plan olarak kullanır.
- Dashed divider, GPUI `canvas(...)` üzerinde `PathBuilder` ile çizilir; bu yüzden çizgi üst öğe sınırlarına bağlıdır.
- `h_flex()` ve `v_flex()` gap vermez. `h_flex()` yatay yönle birlikte `items_center()` uygular; `v_flex()` dikey yön seçer. Group yardımcıları ise aynı temel kapsayıcıya küçük sabit gap uygular. Başka renk veya border eklemezler.

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

Dikkat edeceğin noktalar:

- Dikey divider'ın görünmesi için üst öğenin yüksekliği belirli olmalıdır; aksi halde `h_full()` anlamlı bir alan bulamayabilir.
- Group yardımcıları yoğun ve kısa UI parçaları içindir. Form, modal veya liste section'larında `DynamicSpacing` ile açık boşluk seçmek daha okunabilir olur.

## Vector ve Görsel Kullanımı

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Vector`, `ui::VectorName`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Vector`.

Ne zaman kullanırsın:

- Zed içinde paketlenmiş SVG görsellerini belirli bir boyutta render etmek için.
- Logo, damga veya ürün işareti gibi standart ikon ailesine girmeyen vektörler için.

Ne zaman kullanmazsın:

- Standart bir simge için `Icon` doğru yüzeydir.
- Bir kullanıcı avatarı için `Avatar` kullanırsın.
- Raster veya dış kaynaklı bir görsel için GPUI tarafındaki `img(...)` ile `ImageSource` devreye girer.

Temel API:

- `Vector::new(VectorName, width: Rems, height: Rems)`.
- `Vector::square(VectorName, size: Rems)`.
- `.color(Color)`.
- `.size(Size<Rems>)`.
- `CommonAnimationExt` üzerinden `.with_rotate_animation(duration)`; doğrudan `.transform(...)` bir Zed tüketici API'si olarak re-export edilmez.
- `VectorName`: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`, `StudentStamp`, `ZedLogo`, `ZedXCopilot`.

Vector enum yardımcıları:

| API | Rol |
| :-- | :-- |
| `VectorNameIter` | `strum::EnumIter` çıktısıdır; önizleme ve doğrulama araçlarında paketlenmiş vector adlarını dolaşmak için kullanılır. |

Davranış:

- `VectorName::path()` çağrısı `images/<name>.svg` yolunu üretir.
- SVG `flex_none()` ile birlikte verilen width ve height rem değerleri üzerinden render edilir.
- `.color(...)` ayarı, SVG'ye `text_color(...)` üzerinden uygularsın.

Örnek:

```rust
use ui::{Vector, VectorName, prelude::*};

fn zed_isareti_render() -> impl IntoElement {
    Vector::square(VectorName::ZedLogo, rems(3.)).color(Color::Accent)
}
```

Dikkat edeceğin noktalar:

- `Image` adında dışa açık bir Zed UI bileşeni yoktur. Rehberde bir görsel ihtiyacı varsa `Vector`, `Avatar`, `Icon` ve GPUI `img(...)` ayrımının yapılması beklenir.
- `VectorName` yalnızca kaynakta tanımlanmış olan paketlenmiş asset'leri kapsar; dışarıdan yeni isim eklenmez.

GPUI `img(...)` ve `ImageSource` (raster veya dış görsel için) şu şekilde kullanırsın:

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

`Avatar::new`, bu `Into<ImageSource>` zincirinin üzerine kuruludur. Ham bir `img(...)` kullanılırken `flex_none()` ve sabit bir `size(...)` verilmediğinde yerleşim taşmaları yaşanması olasıdır. SVG bir ikon için her zaman `Icon` veya `Vector` tercih edilir; `img(...)` SVG path'lerini raster gibi muamele eder ve o yüzden recolor edemez.

## KeyBinding

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::KeyBinding`, `ui::Key`, `ui::KeyIcon`, `ui::render_keybinding_keystroke`, `ui::text_for_action`, `ui::text_for_keystrokes`, `ui::text_for_keybinding_keystrokes`, `ui::render_modifiers`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for KeyBinding`.

Ne zaman kullanırsın:

- UI içinde bir action'a bağlı kısayol göstermek için.
- Açıkça verilen bir keystroke dizisini platforma uygun tuş görseli olarak render etmek için.
- Tooltip, command palette veya bir ayar satırında klavye kısayolu göstermek için.

Ne zaman kullanmazsın:

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
- `Key::new(key: impl Into<SharedString>, color: Option<Color>)` ve `KeyIcon::new(icon: IconName, color: Option<Color>)`: tekil tuş veya ikonlu tuş yüzeyi.
- `render_modifiers(modifiers: &Modifiers, platform_style: PlatformStyle, color: Option<Color>, size: Option<AbsoluteLength>, trailing_separator: bool) -> impl Iterator<Item = AnyElement>`: bir modifier dizisini platform stiline göre ikon veya metin elementlerine çeviren düşük seviyeli yardımcı. `trailing_separator`, son modifier'dan sonra bir `+` ayırıcısı ekler.
- `text_for_keystroke(modifiers: &Modifiers, key: &str, cx: &App) -> String`: tek bir keystroke için platforma duyarlı bir metin üretir.

Keybinding yardımcı yüzeyi:

| API | Rol |
| :-- | :-- |
| `Key` | Tekil metinsel tuş kapsülünü render eder; `.size(...)` ile ölçüsü ayarlanır. |
| `KeyIcon` | Tuş kapsülü içinde icon render eder; platform stili ikon gerektirdiğinde kullanılır. |
| `render_keybinding_keystroke` | Tek bir `KeybindingKeystroke` değerini platforma uygun tuş elementleri dizisine çevirir. |
| `render_modifiers` | Modifier listesini macOS'ta ikon, diğer platformlarda metin ve separator olarak render eder. |
| `text_for_action` | Bir action için geçerli binding metnini action map üzerinden üretir. |
| `text_for_keystrokes` | Keystroke dizisini platforma uygun okunabilir metne çevirir. |
| `text_for_keybinding_keystrokes` | `KeybindingKeystroke` koleksiyonunu kullanıcıya gösterilecek kısayol metnine dönüştürür. |
| `text_for_keystroke` | Tek bir modifier/key çiftinden platforma uygun kısayol metni üretir. |

Davranış:

- Action source kullanıldığında window'daki en yüksek öncelikli binding aranır.
- Bir focus handle verildiğinde, action için önce focus bağlamındaki binding aranır.
- Binding bulunamadığında `Empty` render edilir.
- Platform stili macOS için modifier ikonlarını, Linux ve Windows için ise metin ve `+` separator'larını kullanır.
- `.platform_style(...)` alanı set eder, ancak mevcut render gövdesi doğrudan `PlatformStyle::platform()` kullanır. Belirli bir platform stilini zorlamak istediğinde düşük seviyeli `render_keybinding_keystroke(...)` veya `render_modifiers(...)` yardımcılarına platform stilini açıkça verirsin.
- `.has_binding(window)` mevcut kaynakta yalnız focus handle'lı action source için `true` dönebilir; `for_action(...)` ile focus handle verilmeden oluşturulan bileşende render yine binding arar, fakat `has_binding(...)` kontrolü `false` kalır.

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

Dikkat edeceğin noktalar:

- `ui::KeyBinding` ile `gpui::KeyBinding` aynı dosyada birlikte import edilirken, ikisine de alias verilmesi okunabilirliği artırır.
- Bir action'a bağlı kısayol gösterilirken binding bulunamama durumunun UI'da düşünmen gerekir; çünkü bileşen bu durumda boş render edebilir.

## KeybindingHint

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::KeybindingHint`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for KeybindingHint`.

Ne zaman kullanırsın:

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

- Prefix ve suffix metni italik buffer font ile render edilir.
- Keybinding parçası bir border, subtle bir background ve hafif bir shadow alır.
- Background color, theme text ve accent renkleriyle blend edilerek hint yüzeyi oluşturulur.

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

- `settings_ui` crate'i: ayar UI kısayol ipuçları.
- `git_ui` crate'i: modal kısayol ipucu.

Dikkat edeceğin noktalar:

- `background_color` üst öğe yüzeyine yakın seçmen gerekir; hint kendi border ve fill rengini bu değerden türetir.
- Çok uzun bir prefix veya suffix yazılmaması beklenir; bileşen kısa komut açıklamaları için tasarlanmıştır.

## Navigable

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Navigable`, `ui::NavigableEntry`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: Hayır.

Ne zaman kullanırsın:

- Scrollable bir view içinde `menu::SelectNext` ve `menu::SelectPrevious` aksiyonlarıyla bir klavye gezintisi kurmak için.
- Focus handle ve scroll anchor listesini tek bir wrapper'a bağlamak için.

Temel API:

- `NavigableEntry::new(scroll_handle, cx)`.
- `NavigableEntry::focusable(cx)`.
- `Navigable::new(child: AnyElement)`.
- `.entry(NavigableEntry)`.
- `NavigableEntry` dışa açık alanları: `focus_handle` ve `scroll_anchor: Option<ScrollAnchor>`. `new(...)` scroll anchor'lı bir entry üretir; `focusable(...)` ise `scroll_anchor: None` olan bir entry döndürür.

Navigable entry:

| API | Rol |
| :-- | :-- |
| `NavigableEntry` | Klavye traversal sırasında focus edilecek handle'ı ve opsiyonel scroll anchor'ı birlikte taşır. |

Davranış:

- Entry'lerin ekleme sırası, gezinti sırasıdır.
- SelectNext veya SelectPrevious aksiyonu focused entry'yi bulur, hedef entry'nin focus handle'ını focus eder ve bir scroll anchor varsa görünür alana scroll yapar.
- `NavigableEntry::focusable(...)`, scroll anchor olmadan focusable bir entry üretir.

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

Dikkat edeceğin noktalar:

- Wrapper yalnızca action routing ile focus/scroll geçişini kurar; her child'ın kendisi yine `track_focus` ile focus track etmelidir.
- Entry listesinin, render edilen öğe sırasıyla aynı tutulması gerekir; aksi halde gezinti beklenmedik bir sıraya kayar.

## ProjectEmptyState

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::ProjectEmptyState`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanırsın:

- Bir panel veya yan panel bir proje veya çalışma ağacı olmadan açıldığında aynı boş durum eylemlerini göstermek için.
- `"Open Project"` ve `"Clone Repository"` seçeneklerinin aynı odak, kısayol ve boşluk düzeniyle görünmesinin istendiği yerlerde.

Temel API:

- Constructor: `ProjectEmptyState::new(label, focus_handle, open_project_key_binding)`.
- `.on_open_project(handler)`.
- `.on_clone_repo(handler)`.

Davranış:

- Render edilen kök, bir `v_flex()` içinde `track_focus(&focus_handle)` çağrısı yapar.
- Üst metni `Choose one of the options below to use the {label}` biçiminde görürsün.
- İlk eylemi `Button::new("open_project", "Open Project")` ve verilen `KeyBinding` ile görürsün; ikinci eylem ise `Button::new("clone_repo", "Clone Repository")` olarak gelir.
- İki eylem arasında bir `Divider::horizontal().color(DividerColor::Border)` ile küçük bir `"or"` etiketi görürsün.

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

- `project_panel` crate'i: worktree yokken project panel boş durumu.
- `agent_ui` crate'i: proje yokken agent panel boş durumu.
- `git_ui` crate'i: worktree yokken git panel boş durumu.
- `sidebar` crate'i: threads sidebar boş proje durumu.

Dikkat edeceğin noktalar:

- Bu bileşen yalnızca iki standart proje eylemini render eder. Farklı action setleri veya farklı bir açıklama metni gerekiyorsa, özel bir `v_flex()` yerleşimi kurmak daha doğru bir tercih olur.
- Handler verilmediğinde ilgili buton yine render edilir ama tıklama davranışı bağlanmaz.

## UI yardımcı fonksiyonları ve ölçü araçları

Kaynak:

- Modül: `ui` crate'i
- Alt modüller: `utils/apca_contrast`, `utils/color_contrast`, `utils/constants`, `utils/corner_solver`, `utils/format_distance`, `utils/search_input`, `utils/with_rem_size`.
- Export: `ui::utils::*`.
- Prelude: Hayır; `use ui::utils::{...};` ile açık import yaparsın.

Ne zaman kullanırsın:

- Tema açık/koyu bilgisini veya contrast hesabını özel çizimlerde kullanmak için.
- Title bar, corner radius, search input width veya rem ölçeği gibi düşük seviyeli yerleşim hesaplarında.
- Kullanıcıya göreceli tarih metni ya da platforma uygun "Reveal in ..." etiketi göstermek için.

Ne zaman kullanmazsın:

- Hazır bileşen zaten bu hesabı yapıyorsa aynı davranışı dışarıda tekrar hesaplamazsın. Örneğin `Label`, `Button`, `Callout` ve `Banner` renk/token kararlarını içeride verir.
- Genel iş mantığı veya domain formatlama için `ui::utils` modülüne bağımlı hale gelinmez. Bu modül UI kararları içindir.
- Locale-aware metin dönüşümü gerekiyorsa `capitalize(...)` yeterli değildir; sadece ilk karakteri büyütür.

Temel API:

- Tema ve metin: `is_light(cx)`, `reveal_in_file_manager_label(is_remote)`, `capitalize(str)`.
- Kontrast: `calculate_contrast_ratio(fg, bg)`, `apca_contrast(text_color, background_color)`, `ensure_minimum_contrast(foreground, background, minimum_apca_contrast)`.
- Title bar ölçüleri: `TRAFFIC_LIGHT_PADDING`, `MACOS_SDK_26_OR_LATER`, `platform_title_bar_height(window)`.
- Corner hesapları: `inner_corner_radius(...)`, `CornerSolver::new(root_radius, root_border, root_padding).add_child(border, padding).corner_radius(level)`.
- Arama genişliği: `SearchInputWidth::THRESHOLD_WIDTH`, `SearchInputWidth::MAX_WIDTH`, `SearchInputWidth::calc_width(container_width)`.
- Rem override: `WithRemSize::new(rem_size).occlude()`.
- Tarih metni: `DateTimeType::Naive(...)`, `DateTimeType::Local(...)`, `DateTimeType::to_naive()`, `FormatDistance::new(date, base_date)`, `FormatDistance::from_now(date)`, `.include_seconds(...)`, `.add_suffix(...)`, `.hide_prefix(...)`, `format_distance(...)`, `format_distance_from_now(...)`.

Utils alt modülleri:

| API | Rol |
| :-- | :-- |
| `color_contrast` | Contrast ratio ve APCA tabanlı minimum contrast hesaplarını taşıyan yardımcı modüldür. |
| `constants` | Title bar padding ve platforma bağlı UI ölçü sabitlerini barındırır. |
| `search_input` | `SearchInputWidth` ile arama input'u genişlik hesabını sağlar; input'u kendisi render etmez. |
| `with_rem_size` | Alt ağacı farklı rem size ile layout/prepaint etmek için `WithRemSize` yüzeyini sağlar. |

Davranış:

- `is_light(cx)`, etkin tema appearance değerini okur. Özel canvas ya da image overlay gibi hazır bileşenin kapsamadığı görsel hesaplarda kullanılır.
- APCA sonucu pozitifse koyu metin/açık arka plan, negatifse açık metin/koyu arka plan polarity'sini ifade eder. `ensure_minimum_contrast(...)`, foreground lightness değerini değiştirerek eşik sağlamaya çalışır.
- `platform_title_bar_height(window)`, Windows'ta 32px döndürür; diğer platformlarda rem size'a bağlı, minimum 34px olan bir değer üretir.
- `WithRemSize`, alt ağacı farklı bir rem size ile layout/prepaint eder. `.occlude()` pointer event'lerinin alt çocuklara ulaşmasını engeller.
- `FormatDistance` `Display` implement eder; builder zinciri sonunda `.to_string()` ile göreceli metne çevrilebilir.

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

Dikkat edeceğin noktalar:

- `format_distance_from_now(...)` çağrısı anlık `Local::now()` okur. Deterministik test veya snapshot üretirken `FormatDistance::new(date, base_date)` daha kontrollüdür.
- `SearchInputWidth::calc_width(...)` yalnız genişlik hesabı yapar; input'u kendisi render etmez.
- `TRAFFIC_LIGHT_PADDING` değeri dışa açık `MACOS_SDK_26_OR_LATER` sabitine (macOS SDK 26 ve sonrası derlemelerde `true`) bağlıdır: doğruysa 78px, değilse 71px. Title bar dışı genel padding için kullanılmamalıdır.
