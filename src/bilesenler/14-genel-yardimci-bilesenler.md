# 14. Genel Yardımcı Bileşenler

Bu bölümdeki bileşenler tek bir amaca hizmet eden küçük yapı taşlarıdır. Çoğunlukla görsel bir yardımcı, klavye ipucu veya navigation yüzeyi sunarlar. Liste satırı, toolbar, panel başlığı veya empty state gibi alanlarda önceki bölümlerdeki büyük bileşenlerin yanında sık kullanılırlar. Küçük görünseler de ekranın okunabilirliğini ve etkileşim kalitesini doğrudan etkilerler.

Bu aileyi kullanırken üç ayrımı akılda tutmak işinizi kolaylaştırır:

- `ui::KeyBinding` ile `gpui::KeyBinding` aynı adı taşısa da farklı şeylerdir. UI tarafındaki bileşen shortcut'ı görsel olarak render eder; GPUI tarafındaki tip ise keymap'e bir binding tanımlar.
- `Image` adında public bir Zed UI component'i yoktur. Bundled SVG için `Vector` kullanılır; raster veya dış kaynaklı görsel için GPUI tarafındaki `img(...)` ve `ImageSource` yüzeyi devreye girer.
- Disclosure, Chip ve DiffStat gibi kompakt parçalar liste veya toolbar içinde kullanılırken parent container'a `min_w_0` ve uygun gap'ler vermek taşma kontrolünü ciddi biçimde kolaylaştırır.

## Chip

Kaynak:

- Tanım: `../zed/crates/ui/src/components/chip.rs`
- Export: `ui::Chip`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Chip`.

Ne zaman kullanılır:

- Filtre, plan adı, provider tipi, branch adı, metadata veya küçük bir status label'ı göstermek için.
- İkon ile kısa label kombinasyonunu düşük vurgu ile göstermek için.

Ne zaman kullanılmaz:

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

- Varsayılan label size `LabelSize::XSmall`'dur.
- Label, buffer font ile render edilir.
- `.truncate()` parent içinde shrink edilmesine izin verir; uzun chip metinlerinde bu davranışın açık olması önerilir.
- Tooltip closure'ı bir `AnyView` döndürür.

Örnek:

```rust
use ui::{Chip, IconName, prelude::*};

fn render_branch_chip(branch: SharedString) -> impl IntoElement {
    Chip::new(branch)
        .icon(IconName::GitBranch)
        .icon_color(Color::Muted)
        .label_color(Color::Muted)
        .truncate()
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension capability etiketleri.
- `../zed/crates/agent_ui/src/ui/model_selector_components.rs`: model metadata ve cost bilgisi.
- `../zed/crates/title_bar/src/plan_chip.rs`: plan adı gösterimi.

Dikkat edilecek noktalar:

- Chip küçük bir bilgi kapsülüdür; primary action yerine kullanılmamalıdır.
- Custom background kullanılıyorsa border renginin de bu seçimle uyumlu olması görsel tutarlılığı korur.
- Dar bir toolbar içinde `.truncate()` olmadan uzun bir label kullanmak layout'u bozabilir.

## DiffStat

Kaynak:

- Tanım: `../zed/crates/ui/src/components/diff_stat.rs`
- Export: `ui::DiffStat`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for DiffStat`.

Ne zaman kullanılır:

- Eklenen ve silinen satır sayılarını kompakt biçimde göstermek için.
- Commit, branch, thread veya file diff metadata'sının yanında.

Ne zaman kullanılmaz:

- Ayrıntılı bir file diff görünümü için bu component yeterli değildir.
- Yalnızca toplam değişiklik sayısı gerekiyorsa bir `Label` veya `CountBadge` daha doğru bir araç olur.

Temel API:

- `DiffStat::new(id, added, removed)`.
- `.label_size(LabelSize)`.
- `.tooltip(text)`.

Davranış:

- Added değeri `Color::Success`, removed değeri ise `Color::Error` ile render edilir.
- Removed label'ı görsel olarak typographic minus karakterini kullanır.
- Tooltip verildiğinde `Tooltip::text(...)` bağlanır.

Örnek:

```rust
use ui::{DiffStat, prelude::*};

fn render_file_change_summary() -> impl IntoElement {
    h_flex()
        .gap_2()
        .items_center()
        .child(Label::new("src/main.rs").truncate())
        .child(DiffStat::new("main-rs-diff", 12, 3).tooltip("12 additions, 3 deletions"))
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: tool result ve thread değişiklik özetleri.
- `../zed/crates/git_ui/src/project_diff.rs`: project diff metadata'sı.
- `../zed/crates/git_graph/src/git_graph.rs`: commit metadata.

Dikkat edilecek noktalar:

- Verilen `id` değerinin stabil olması beklenir; aynı listede tekrar eden bir id kullanmak hatalı davranışa yol açar.
- Sıfır değerlerinin gösterilip gösterilmeyeceğine parent karar verir; bileşen kendiliğinden gizlemez.

## Disclosure

Kaynak:

- Tanım: `../zed/crates/ui/src/components/disclosure.rs`
- Export: `ui::Disclosure`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Disclosure`.

Ne zaman kullanılır:

- Açılır veya kapanır bir bölüm, bir tree satırı ya da bir detay satırı için chevron button gerektiğinde.
- Parent state'in açılma durumunu kontrol ettiği "controlled" bir toggle için.

Ne zaman kullanılmaz:

- Tam satır bir tree davranışı gerekiyorsa `TreeViewItem` çok daha hazır bir davranış sağlar.
- Yalnızca görsel bir chevron yeterliyse, bir `Icon` daha sade bir çözüm sunar.

Temel API:

- `Disclosure::new(id, is_open)`.
- `.on_toggle_expanded(handler)`.
- `.opened_icon(IconName)`.
- `.closed_icon(IconName)`.
- `.disabled(bool)`.
- `Clickable`: `.on_click(...)`, `.cursor_style(...)`.
- `Toggleable`: `.toggle_state(selected)`.
- `VisibleOnHover`: `.visible_on_hover(group_name)`.

Davranış:

- Açıkken default ikon `ChevronDown`; kapalıyken `ChevronRight`'tır.
- Render sonucu bir `IconButton` üzerinden gelir.
- `is_open` değeri internal bir state değildir; parent her render'da güncel değeri vermelidir.
- **`Clickable::on_click` ve `on_toggle_expanded` aynı slotu yazar.** Kaynak implementasyon `on_click`'i `self.on_toggle_expanded = Some(Arc::new(handler))` olarak depolar; bu yüzden iki metod birlikte çağrılırsa **sonuncu** kazanır. Karışıklığı önlemek için yalnızca birinin kullanılması önerilir.

Örnek:

```rust
use ui::{Disclosure, prelude::*};

fn render_collapsible_header(is_open: bool) -> impl IntoElement {
    h_flex()
        .gap_1()
        .items_center()
        .child(
            Disclosure::new("advanced-toggle", is_open)
                .on_click(|_, _window, cx| cx.stop_propagation()),
        )
        .child(Label::new("Advanced"))
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/ui/src/components/tree_view_item.rs`: tree item expansion.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: plan, queue ve edit detay açılımları.
- `../zed/crates/repl/src/outputs/json.rs`: JSON node expansion.

Dikkat edilecek noktalar:

- Toggle state'i parent'ta tutulur ve click handler bu state'i güncellemekle yükümlüdür.
- `visible_on_hover(...)` kullanıldığında parent elementte aynı group name'in tanımlanmış olması gerekir.

## GradientFade

Kaynak:

- Tanım: `../zed/crates/ui/src/components/gradient_fade.rs`
- Export: `ui::GradientFade`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: Hayır.

Ne zaman kullanılır:

- Sağ kenarda taşan bir içerik veya hover action alanı üzerinde yumuşak bir fade overlay gerektiğinde.
- Sidebar item gibi tek satırda metadata ile action geçişini maskelemek için.

Ne zaman kullanılmaz:

- Genel bir background dekorasyonu için bu bileşen tasarlanmamıştır.
- Scrollbar veya gerçek bir clipping'in yerine geçecek şekilde kullanılması doğru olmaz.

Temel API:

- `GradientFade::new(base_bg, hover_bg, active_bg)`.
- `.width(Pixels)`.
- `.right(Pixels)`.
- `.gradient_stop(f32)`.
- `.group_name(name)`.

Davranış:

- Absolute pozisyonludur; `top_0()`, `h_full()` ve sağ kenara bağlıdır.
- Renkleri app background ile blend ederek opaklık etkisi yaratmaya çalışır.
- `group_name(...)` verildiğinde, parent hover veya active durumunda gradient rengi otomatik olarak değişir.

Örnek:

```rust
use ui::{GradientFade, prelude::*};

fn render_fading_row(cx: &App) -> impl IntoElement {
    let base = cx.theme().colors().panel_background;
    let hover = cx.theme().colors().element_hover;

    h_flex()
        .group("metadata-row")
        .relative()
        .overflow_hidden()
        .child(Label::new("A very long metadata value that fades near the action").truncate())
        .child(
            GradientFade::new(base, hover, hover)
                .width(px(64.))
                .group_name("metadata-row"),
        )
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/ui/src/components/ai/thread_item.rs`: action slot ve metadata fade overlay.
- `../zed/crates/sidebar/src/sidebar.rs`: sidebar satır hover fade.

Dikkat edilecek noktalar:

- Parent elemanın `relative()` ve `overflow_hidden()` olması gerekir; aksi halde fade beklenen konuma oturmaz.
- Fade gerçek bir layout alanı ayırmaz. Action slot veya trailing content için ayrıca padding ya da boşluk bırakılması gerekir.

## Vector ve Görsel Kullanımı

Kaynak:

- Tanım: `../zed/crates/ui/src/components/image.rs`
- Export: `ui::Vector`, `ui::VectorName`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Vector`.

Ne zaman kullanılır:

- Zed içinde paketlenmiş SVG görsellerini belirli bir boyutta render etmek için.
- Logo, stamp veya product mark gibi standart ikon ailesine girmeyen vektörler için.

Ne zaman kullanılmaz:

- Standart bir simge için `Icon` doğru yüzeydir.
- Bir kullanıcı avatarı için `Avatar` kullanılır.
- Raster veya dış kaynaklı bir görsel için GPUI tarafındaki `img(...)` ile `ImageSource` devreye girer.

Temel API:

- `Vector::new(VectorName, width: Rems, height: Rems)`.
- `Vector::square(VectorName, size: Rems)`.
- `.color(Color)`.
- `.size(Size<Rems>)`.
- `CommonAnimationExt` üzerinden `.with_rotate_animation(duration)`; doğrudan `.transform(...)` bir Zed tüketici API'si olarak re-export edilmez.
- `VectorName`: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`, `StudentStamp`, `ZedLogo`, `ZedXCopilot`.

Davranış:

- `VectorName::path()` çağrısı `images/<name>.svg` yolunu üretir.
- SVG `flex_none()` ile birlikte verilen width ve height rem değerleri üzerinden render edilir.
- `.color(...)` ayarı, SVG'ye `text_color(...)` üzerinden uygulanır.

Örnek:

```rust
use ui::{Vector, VectorName, prelude::*};

fn render_zed_mark() -> impl IntoElement {
    Vector::square(VectorName::ZedLogo, rems(3.)).color(Color::Accent)
}
```

Dikkat edilecek noktalar:

- `Image` adında public bir Zed UI component'i yoktur. Rehberde bir görsel ihtiyacı varsa `Vector`, `Avatar`, `Icon` ve GPUI `img(...)` ayrımının yapılması beklenir.
- `VectorName` yalnızca kaynakta tanımlanmış olan bundled asset'leri kapsar; dışarıdan yeni isim eklenmez.

GPUI `img(...)` ve `ImageSource` (raster veya dış görsel için) şu şekilde kullanılır:

```rust
use gpui::{ImageSource, SharedUri, img};
use ui::prelude::*;

fn render_remote_thumbnail() -> impl IntoElement {
    img(ImageSource::from(SharedUri::from(
        "https://zed.dev/img/banner.png",
    )))
    .size(px(96.))
    .rounded_md()
}

fn render_local_thumbnail() -> impl IntoElement {
    img(ImageSource::from(std::path::Path::new("/tmp/preview.png")))
        .size(px(96.))
        .rounded_md()
}
```

`ImageSource` aşağıdaki kaynaklardan otomatik dönüşür:

| Kaynak | Notlar |
| :-- | :-- |
| `&str`, `String`, `SharedString` | URL veya yerel yol; URL ise asenkron yüklenir. |
| `SharedUri` | Tip güvenli URL gösterimi; `Avatar::new("https://...")` örtük bu yolu kullanır. |
| `&Path`, `Arc<Path>`, `PathBuf` | Dosya sistemi yolu; senkron olarak okunur. |
| `Arc<RenderImage>`, `Arc<Image>` | Önceden decode edilmiş image bytes. |
| `F: Fn(&mut Window, &mut App) -> ImageSource` | Çağrı sırasında dinamik kaynak üretmek için. |

`Avatar::new`, bu `Into<ImageSource>` zincirinin üzerine kuruludur. Ham bir `img(...)` kullanılırken `flex_none()` ve sabit bir `size(...)` verilmediğinde layout taşmaları yaşanması olasıdır. SVG bir ikon için her zaman `Icon` veya `Vector` tercih edilir; `img(...)` SVG path'lerini raster gibi muamele eder ve dolayısıyla recolor edemez.

## KeyBinding

Kaynak:

- Tanım: `../zed/crates/ui/src/components/keybinding.rs`
- Export: `ui::KeyBinding`, `ui::Key`, `ui::KeyIcon`, `ui::render_keybinding_keystroke`, `ui::text_for_action`, `ui::text_for_keystrokes`, `ui::text_for_keybinding_keystrokes`, `ui::render_modifiers`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for KeyBinding`.

Ne zaman kullanılır:

- UI içinde bir action'a bağlı shortcut göstermek için.
- Explicit bir keystroke dizisini platforma uygun tuş görseli olarak render etmek için.
- Tooltip, command palette veya bir ayar satırında klavye kısayolu göstermek için.

Ne zaman kullanılmaz:

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
- `render_modifiers(modifiers: &Modifiers, platform_style: PlatformStyle, color: Option<Color>, size: Option<AbsoluteLength>, trailing_separator: bool) -> impl Iterator<Item = AnyElement>`: bir modifier dizisini platform stiline göre ikon veya metin elementlerine çeviren düşük seviyeli helper. `trailing_separator`, son modifier'dan sonra bir `+` ayırıcısı ekler.
- `text_for_keystroke(modifiers: &Modifiers, key: &str, cx: &App) -> String`: tek bir keystroke için platforma duyarlı bir metin üretir.

Davranış:

- Action source kullanıldığında window'daki en yüksek öncelikli binding aranır.
- Bir focus handle verildiğinde, action için önce focus bağlamındaki binding aranır.
- Binding bulunamadığında `Empty` render edilir.
- Platform stili macOS için modifier ikonlarını, Linux ve Windows için ise metin ve `+` separator'larını kullanır.

Örnek:

```rust
use gpui::{AnyElement, KeybindingKeystroke, Keystroke};
use ui::{KeyBinding, prelude::*};

fn render_save_shortcut() -> AnyElement {
    let Ok(parsed) = Keystroke::parse("cmd-s") else {
        return div().into_any_element();
    };
    let keystroke = KeybindingKeystroke::from_keystroke(parsed);

    KeyBinding::from_keystrokes(vec![keystroke].into(), false).into_any_element()
}
```

Dikkat edilecek noktalar:

- `ui::KeyBinding` ile `gpui::KeyBinding` aynı dosyada birlikte import edilirken, ikisine de alias verilmesi okunabilirliği artırır.
- Bir action'a bağlı shortcut gösterilirken binding bulunamama durumunun UI'da düşünülmesi gerekir; çünkü component bu durumda boş render edebilir.

## KeybindingHint

Kaynak:

- Tanım: `../zed/crates/ui/src/components/keybinding_hint.rs`
- Export: `ui::KeybindingHint`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for KeybindingHint`.

Ne zaman kullanılır:

- Bir shortcut'ı prefix veya suffix metniyle birlikte açıklamak için.
- Tooltip veya empty state içinde kısa bir klavye ipucu göstermek için.

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

fn render_command_hint(cx: &App) -> AnyElement {
    let Ok(parsed) = Keystroke::parse("cmd-shift-p") else {
        return div().into_any_element();
    };
    let keystroke = KeybindingKeystroke::from_keystroke(parsed);
    let binding = KeyBinding::from_keystrokes(vec![keystroke].into(), false);

    KeybindingHint::new(binding, cx.theme().colors().surface_background)
        .prefix("Open command palette:")
        .into_any_element()
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/settings_ui/src/settings_ui.rs`: ayar UI kısayol ipuçları.
- `../zed/crates/git_ui/src/commit_modal.rs`: modal shortcut hint'i.

Dikkat edilecek noktalar:

- `background_color` parent yüzeyine yakın seçilmelidir; hint kendi border ve fill rengini bu değerden türetir.
- Çok uzun bir prefix veya suffix yazılmaması beklenir; bileşen kısa komut açıklamaları için tasarlanmıştır.

## Navigable

Kaynak:

- Tanım: `../zed/crates/ui/src/components/navigable.rs`
- Export: `ui::Navigable`, `ui::NavigableEntry`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: Hayır.

Ne zaman kullanılır:

- Scrollable bir view içinde `menu::SelectNext` ve `menu::SelectPrevious` aksiyonlarıyla bir klavye gezintisi kurmak için.
- Focus handle ve scroll anchor listesini tek bir wrapper'a bağlamak için.

Temel API:

- `NavigableEntry::new(scroll_handle, cx)`.
- `NavigableEntry::focusable(cx)`.
- `Navigable::new(child: AnyElement)`.
- `.entry(NavigableEntry)`.
- `NavigableEntry` public alanları: `focus_handle` ve `scroll_anchor: Option<ScrollAnchor>`. `new(...)` scroll anchor'lı bir entry üretir; `focusable(...)` ise `scroll_anchor: None` olan bir entry döndürür.

Davranış:

- Entry'lerin ekleme sırası, traversal sırasıdır.
- Select next veya previous aksiyonu focused entry'yi bulur, hedef entry'nin focus handle'ını focus eder ve bir scroll anchor varsa görünür alana scroll yapar.
- `NavigableEntry::focusable(...)`, scroll anchor olmadan focusable bir entry üretir.

Örnek:

```rust
use gpui::ScrollHandle;
use ui::{Navigable, NavigableEntry, prelude::*};

fn render_navigable_rows(scroll_handle: &ScrollHandle, cx: &App) -> impl IntoElement {
    let first = NavigableEntry::new(scroll_handle, cx);
    let second = NavigableEntry::new(scroll_handle, cx);

    let content = v_flex()
        .child(div().track_focus(&first.focus_handle).child(Label::new("First")))
        .child(div().track_focus(&second.focus_handle).child(Label::new("Second")));

    Navigable::new(content.into_any_element())
        .entry(first)
        .entry(second)
}
```

Dikkat edilecek noktalar:

- Wrapper yalnızca action routing ile focus/scroll geçişini kurar; her child'ın kendisi yine `track_focus` ile focus track etmelidir.
- Entry listesinin, render edilen item sırasıyla aynı tutulması gerekir; aksi halde gezinti beklenmedik bir sıraya kayar.

## ProjectEmptyState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/project_empty_state.rs`
- Export: `ui::ProjectEmptyState`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Bir panel veya sidebar bir proje veya worktree olmadan açıldığında aynı boş durum eylemlerini göstermek için.
- "Open Project" ve "Clone Repository" seçeneklerinin aynı focus, keybinding ve spacing düzeniyle görünmesinin istendiği yerlerde.

Temel API:

- Constructor: `ProjectEmptyState::new(label, focus_handle, open_project_key_binding)`.
- `.on_open_project(handler)`.
- `.on_clone_repo(handler)`.

Davranış:

- Render edilen root, bir `v_flex()` içinde `track_focus(&focus_handle)` çağrısı yapar.
- Üst metin `Choose one of the options below to use the {label}` biçiminde üretilir.
- İlk action `Button::new("open_project", "Open Project")` ve verilen `KeyBinding` ile render edilir; ikinci action ise `Button::new("clone_repo", "Clone Repository")` olarak gelir.
- İki action arasında bir `Divider::horizontal().color(DividerColor::Border)` ile küçük bir `or` label'ı kullanılır.

Örnek:

```rust
use gpui::FocusHandle;
use ui::{KeyBinding, ProjectEmptyState, prelude::*};

fn render_empty_panel(
    focus_handle: FocusHandle,
    open_project_key_binding: KeyBinding,
) -> impl IntoElement {
    ProjectEmptyState::new("Project Panel", focus_handle, open_project_key_binding)
        .on_open_project(|_, window, cx| {
            window.dispatch_action(workspace::Open::default().boxed_clone(), cx);
        })
        .on_clone_repo(|_, window, cx| {
            window.dispatch_action(git::Clone.boxed_clone(), cx);
        })
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/project_panel/src/project_panel.rs`: worktree yokken project panel boş durumu.
- `../zed/crates/agent_ui/src/agent_panel.rs`: proje yokken agent panel boş durumu.
- `../zed/crates/git_ui/src/git_panel.rs`: worktree yokken git panel boş durumu.
- `../zed/crates/sidebar/src/sidebar.rs`: threads sidebar boş proje durumu.

Dikkat edilecek noktalar:

- Bu bileşen yalnızca iki standart proje eylemini render eder. Farklı action setleri veya farklı bir açıklama metni gerekiyorsa, özel bir `v_flex()` layout kurmak daha doğru bir tercih olur.
- Handler verilmediğinde ilgili button yine render edilir ama click davranışı bağlanmaz.
