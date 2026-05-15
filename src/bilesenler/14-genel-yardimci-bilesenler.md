# 14. Genel Yardımcı Bileşenler

Bu bölümdeki bileşenler tek bir amaca hizmet eden, çoğu görsel yardımcı veya
klavye/navigasyon yüzeyi sunan yapı taşlarıdır. Bir liste satırı, toolbar,
panel başlığı veya empty state üzerinde sıkça birlikte kullanılırlar.

Genel kural:

- `ui::KeyBinding` ile `gpui::KeyBinding` isimleri farklıdır. UI bileşeni
  shortcut'ı görsel olarak render eder; GPUI tipi keymap'e binding tanımlar.
- `Image` adında public Zed UI component'i yoktur. Bundled SVG için `Vector`,
  raster veya dış görsel için GPUI `img(...)` / `ImageSource` kullanılır.
- Disclosure, Chip ve DiffStat gibi compact yapı taşlarını liste/toolbar
  içinde kullanırken parent container'a `min_w_0` ve uygun gap değerleri
  verilmesi taşma kontrolünü kolaylaştırır.

## Chip

Kaynak:

- Tanım: `../zed/crates/ui/src/components/chip.rs`
- Export: `ui::Chip`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Chip`

Ne zaman kullanılır:

- Filtre, plan adı, provider tipi, branch adı, metadata veya küçük status label'ı
  göstermek için.
- Icon + kısa label kombinasyonunu düşük vurgu ile göstermek için.

Ne zaman kullanılmaz:

- Etkileşimli menü butonu için `Button` / `DropdownMenu`.
- Uzun açıklama veya paragraf için `Label`.

Temel API:

- `Chip::new(label)`
- `.label_color(Color)`
- `.label_size(LabelSize)`
- `.icon(IconName)`
- `.icon_color(Color)`
- `.bg_color(Hsla)`
- `.border_color(Hsla)`
- `.height(Pixels)`
- `.truncate()`
- `.tooltip(...)`

Davranış:

- Varsayılan label size `LabelSize::XSmall`.
- Label buffer font ile render edilir.
- `.truncate()` parent içinde shrink etmeye izin verir; uzun chip metinlerinde
  kullanın.
- Tooltip closure `AnyView` döndürür.

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

Zed içinden kullanım:

- `../zed/crates/extensions_ui/src/extensions_ui.rs`: extension capability
  etiketleri.
- `../zed/crates/agent_ui/src/ui/model_selector_components.rs`: model metadata
  ve cost bilgisi.
- `../zed/crates/title_bar/src/plan_chip.rs`: plan adı gösterimi.

Dikkat edilecekler:

- Chip küçük bir bilgi kapsülüdür; primary action gibi kullanılmamalıdır.
- Custom background kullanıyorsanız border rengini de uyumlu seçin.
- Dar toolbar içinde `.truncate()` olmadan uzun label layout'u bozabilir.

## DiffStat

Kaynak:

- Tanım: `../zed/crates/ui/src/components/diff_stat.rs`
- Export: `ui::DiffStat`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for DiffStat`

Ne zaman kullanılır:

- Eklenen ve silinen satır sayılarını compact göstermek için.
- Commit, branch, thread veya file diff metadata'sı yanında.

Ne zaman kullanılmaz:

- Ayrıntılı file diff görünümü için.
- Sadece toplam değişiklik sayısı gerekiyorsa `Label` veya `CountBadge`.

Temel API:

- `DiffStat::new(id, added, removed)`
- `.label_size(LabelSize)`
- `.tooltip(text)`

Davranış:

- Added değeri `Color::Success`, removed değeri `Color::Error` ile render edilir.
- Removed label'ı typographic minus kullanır.
- Tooltip verilirse `Tooltip::text(...)` bağlanır.

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

Zed içinden kullanım:

- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: tool result ve
  thread değişiklik özetleri.
- `../zed/crates/git_ui/src/project_diff.rs`: project diff metadata'sı.
- `../zed/crates/git_graph/src/git_graph.rs`: commit metadata.

Dikkat edilecekler:

- `id` stabil olmalıdır; aynı listede tekrar eden id kullanmayın.
- Sıfır değerlerin gösterilip gösterilmeyeceğine parent karar vermelidir.

## Disclosure

Kaynak:

- Tanım: `../zed/crates/ui/src/components/disclosure.rs`
- Export: `ui::Disclosure`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Disclosure`

Ne zaman kullanılır:

- Açılır/kapanır bölüm, tree satırı veya detay satırı için chevron button
  gerektiğinde.
- Parent state'in açılma durumunu kontrol ettiği controlled toggle için.

Ne zaman kullanılmaz:

- Tam satır tree davranışı için `TreeViewItem` daha fazla hazır davranış sağlar.
- Sadece görsel chevron gerekiyorsa `Icon` yeterlidir.

Temel API:

- `Disclosure::new(id, is_open)`
- `.on_toggle_expanded(handler)`
- `.opened_icon(IconName)`
- `.closed_icon(IconName)`
- `.disabled(bool)`
- `Clickable`: `.on_click(...)`, `.cursor_style(...)`
- `Toggleable`: `.toggle_state(selected)`
- `VisibleOnHover`: `.visible_on_hover(group_name)`

Davranış:

- Açıkken default icon `ChevronDown`, kapalıyken `ChevronRight`.
- Render sonucu `IconButton` üzerinden gelir.
- `is_open` internal state değildir; parent her render'da güncel değeri verir.
- **`Clickable::on_click` ve `on_toggle_expanded` aynı slotu yazar.** Kaynak
  implementasyon `on_click`'i `self.on_toggle_expanded = Some(Arc::new(handler))`
  olarak depolar; bu yüzden ikisi birlikte çağrılırsa **sonuncu** kazanır.
  Karışıklık önlemek için yalnızca birini kullanın.

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

Zed içinden kullanım:

- `../zed/crates/ui/src/components/tree_view_item.rs`: tree item expansion.
- `../zed/crates/agent_ui/src/conversation_view/thread_view.rs`: plan, queue ve
  edit detay açılımları.
- `../zed/crates/repl/src/outputs/json.rs`: JSON node expansion.

Dikkat edilecekler:

- Toggle state'i parent'ta tutulmalı ve click handler parent state'i
  güncellemelidir.
- `visible_on_hover(...)` kullanıyorsanız parent aynı group name'i tanımlamalıdır.

## GradientFade

Kaynak:

- Tanım: `../zed/crates/ui/src/components/gradient_fade.rs`
- Export: `ui::GradientFade`
- Prelude: Hayır, ayrıca import edin.
- Preview: Hayır.

Ne zaman kullanılır:

- Sağ kenarda taşan içerik veya hover action alanı üstünde yumuşak fade overlay
  gerektiğinde.
- Sidebar item gibi tek satırda metadata/action geçişini maskelemek için.

Ne zaman kullanılmaz:

- Genel background dekorasyonu için.
- Scrollbar veya gerçek clipping yerine geçecek şekilde.

Temel API:

- `GradientFade::new(base_bg, hover_bg, active_bg)`
- `.width(Pixels)`
- `.right(Pixels)`
- `.gradient_stop(f32)`
- `.group_name(name)`

Davranış:

- Absolute positioned, `top_0()`, `h_full()` ve sağ kenara bağlıdır.
- Renkleri app background ile blend ederek opaklaştırmaya çalışır.
- `group_name(...)` verilirse parent hover/active durumunda gradient rengi değişir.

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

Zed içinden kullanım:

- `../zed/crates/ui/src/components/ai/thread_item.rs`: action slot ve metadata
  fade overlay.
- `../zed/crates/sidebar/src/sidebar.rs`: sidebar satır hover fade.

Dikkat edilecekler:

- Parent `relative()` ve `overflow_hidden()` olmalıdır.
- Fade gerçek layout alanı ayırmaz; action slot veya trailing content için ayrıca
  padding/space bırakın.

## Vector ve Görsel Kullanımı

Kaynak:

- Tanım: `../zed/crates/ui/src/components/image.rs`
- Export: `ui::Vector`, `ui::VectorName`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Vector`

Ne zaman kullanılır:

- Zed içinde paketlenmiş SVG görsellerini belirli boyutta render etmek için.
- Logo, stamp veya product mark gibi icon standardına uymayan vektörler için.

Ne zaman kullanılmaz:

- Standart simge için `Icon`.
- Kullanıcı avatarı için `Avatar`.
- Raster veya dış görsel için GPUI `img(...)` / `ImageSource`.

Temel API:

- `Vector::new(VectorName, width: Rems, height: Rems)`
- `Vector::square(VectorName, size: Rems)`
- `.color(Color)`
- `.size(Size<Rems>)`
- `CommonAnimationExt` üzerinden `.with_rotate_animation(duration)`; doğrudan
  `.transform(...)` Zed tüketici API'si olarak re-export edilmez.
- `VectorName`: `BusinessStamp`, `Grid`, `ProTrialStamp`, `ProUserStamp`,
  `StudentStamp`, `ZedLogo`, `ZedXCopilot`

Davranış:

- `VectorName::path()` `images/<name>.svg` yolu üretir.
- SVG `flex_none()`, width ve height rem değerleriyle render edilir.
- `.color(...)`, SVG `text_color(...)` üzerinden uygulanır.

Örnek:

```rust
use ui::{Vector, VectorName, prelude::*};

fn render_zed_mark() -> impl IntoElement {
    Vector::square(VectorName::ZedLogo, rems(3.)).color(Color::Accent)
}
```

Dikkat edilecekler:

- `Image` adında public Zed UI component'i yoktur; rehberde görsel ihtiyacı için
  `Vector`, `Avatar`, `Icon` ve GPUI `img(...)` ayrımı yapılmalıdır.
- `VectorName` yalnızca kaynakta tanımlı bundled asset'leri kapsar.

GPUI `img(...)` ve `ImageSource` (raster veya dış görsel için):

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

`Avatar::new` bu `Into<ImageSource>` zincirinin üzerinde durur; raw `img(...)`
kullanırken `flex_none()` ve sabit `size(...)` vermezseniz layout taşmaları
yaşanabilir. SVG ikon için her zaman `Icon` veya `Vector` tercih edilmelidir;
`img(...)` SVG path'lerini raster gibi muamele eder ve recolor edemez.

## KeyBinding

Kaynak:

- Tanım: `../zed/crates/ui/src/components/keybinding.rs`
- Export: `ui::KeyBinding`, `ui::Key`, `ui::KeyIcon`,
  `ui::render_keybinding_keystroke`, `ui::text_for_action`,
  `ui::text_for_keystrokes`, `ui::text_for_keybinding_keystrokes`,
  `ui::render_modifiers`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for KeyBinding`

Ne zaman kullanılır:

- UI içinde action'a bağlı shortcut göstermek için.
- Explicit keystroke dizisini platforma uygun tuş görseli olarak render etmek
  için.
- Tooltip, command palette veya ayar satırında klavye kısayolu göstermek için.

Ne zaman kullanılmaz:

- Keymap'e yeni binding tanımlamak için `gpui::KeyBinding` kullanılır.
- Sadece açıklama metni gerekiyorsa `text_for_action(...)` veya `Label`.

Temel API:

- `KeyBinding::for_action(action, cx)`
- `KeyBinding::for_action_in(action, focus_handle, cx)`
- `KeyBinding::new(action, focus_handle, cx)`
- `KeyBinding::from_keystrokes(keystrokes, vim_mode)`
- `.platform_style(PlatformStyle)`
- `.size(size)`
- `.disabled(bool)`
- `.has_binding(window)`
- `KeyBinding::set_vim_mode(cx, enabled)`
- `Key::new(key: impl Into<SharedString>, color: Option<Color>)` ve
  `KeyIcon::new(icon: IconName, color: Option<Color>)`: tekil tuş veya ikonlu
  tuş yüzeyi.
- `render_modifiers(modifiers: &Modifiers, platform_style: PlatformStyle,
  color: Option<Color>, size: Option<AbsoluteLength>, trailing_separator: bool)
  -> impl Iterator<Item = AnyElement>`: modifier dizisini platform stiline göre
  ikon/metin elementlerine çeviren düşük seviye helper. `trailing_separator`
  son modifier'dan sonra `+` ayırıcısı ekler.
- `text_for_keystroke(modifiers: &Modifiers, key: &str, cx: &App) -> String`:
  tek bir keystroke için platforma duyarlı metin üretir.

Davranış:

- Action source kullanıldığında window'daki en yüksek öncelikli binding aranır.
- Focus handle verilirse önce action için focus bağlamındaki binding aranır.
- Binding bulunamazsa `Empty` render edilir.
- Platform stili macOS için modifier icon'ları, Linux/Windows için metin ve `+`
  separator kullanır.

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

Dikkat edilecekler:

- `ui::KeyBinding` ile `gpui::KeyBinding` importlarını aynı dosyada kullanırken
  alias verin; aksi halde kod okunması zorlaşır.
- Action'a bağlı shortcut gösteriyorsanız binding bulunamama durumunu UI'da
  düşünün; component boş render edebilir.

## KeybindingHint

Kaynak:

- Tanım: `../zed/crates/ui/src/components/keybinding_hint.rs`
- Export: `ui::KeybindingHint`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for KeybindingHint`

Ne zaman kullanılır:

- Shortcut'ı prefix/suffix metniyle birlikte açıklamak için.
- Tooltip veya empty state içinde kısa klavye ipucu göstermek için.

Temel API:

- `KeybindingHint::new(keybinding, background_color)`
- `KeybindingHint::with_prefix(prefix, keybinding, background_color)`
- `KeybindingHint::with_suffix(keybinding, suffix, background_color)`
- `.prefix(text)`
- `.suffix(text)`
- `.size(Pixels)`

Davranış:

- Prefix/suffix italic buffer font ile render edilir.
- Keybinding parçası border, subtle background ve küçük shadow alır.
- Background color, theme text/accent renkleriyle blend edilerek hint yüzeyi
  oluşturulur.

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

Zed içinden kullanım:

- `../zed/crates/settings_ui/src/settings_ui.rs`: ayar UI kısayol ipuçları.
- `../zed/crates/git_ui/src/commit_modal.rs`: modal shortcut hint'i.

Dikkat edilecekler:

- `background_color` parent yüzeyine yakın seçilmelidir; hint kendi border ve
  fill rengini bu değerden türetir.
- Çok uzun prefix/suffix kullanmayın; kısa komut açıklaması için tasarlanmıştır.

## Navigable

Kaynak:

- Tanım: `../zed/crates/ui/src/components/navigable.rs`
- Export: `ui::Navigable`, `ui::NavigableEntry`
- Prelude: Hayır, ayrıca import edin.
- Preview: Hayır.

Ne zaman kullanılır:

- Scrollable view içinde `menu::SelectNext` / `menu::SelectPrevious` aksiyonlarıyla
  klavye gezintisi kurmak için.
- Focus handle ve scroll anchor listesini tek wrapper'a bağlamak için.

Temel API:

- `NavigableEntry::new(scroll_handle, cx)`
- `NavigableEntry::focusable(cx)`
- `Navigable::new(child: AnyElement)`
- `.entry(NavigableEntry)`
- `NavigableEntry` public alanları: `focus_handle` ve
  `scroll_anchor: Option<ScrollAnchor>`. `new(...)` scroll anchor'lı entry,
  `focusable(...)` ise `scroll_anchor: None` olan entry üretir.

Davranış:

- Entry ekleme sırası traversal sırasıdır.
- Select next/previous aksiyonları focused entry'yi bulur, hedef entry'nin
  focus handle'ını focus eder ve scroll anchor varsa görünür alana scroll eder.
- `NavigableEntry::focusable(...)` scroll anchor olmadan focusable entry üretir.

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

Dikkat edilecekler:

- Wrapper yalnızca action routing ve focus/scroll geçişini kurar; her child'ın
  kendisi focus track etmelidir.
- Entry listesi render edilen item sırasıyla aynı tutulmalıdır.

## ProjectEmptyState

Kaynak:

- Tanım: `../zed/crates/ui/src/components/project_empty_state.rs`
- Export: `ui::ProjectEmptyState`
- Prelude: Hayır, ayrıca import edin.
- Preview: Doğrudan `impl Component` yok.

Ne zaman kullanılır:

- Panel veya sidebar bir proje/worktree olmadan açıldığında aynı boş durum
  eylemlerini göstermek için.
- "Open Project" ve "Clone Repository" seçeneklerinin aynı focus, keybinding ve
  spacing düzeniyle görünmesini istediğiniz yerlerde.

Temel API:

- Constructor: `ProjectEmptyState::new(label, focus_handle, open_project_key_binding)`
- `.on_open_project(handler)`
- `.on_clone_repo(handler)`

Davranış:

- Render edilen root `v_flex()` içinde `track_focus(&focus_handle)` çağırır.
- Üst metni `Choose one of the options below to use the {label}` biçiminde
  üretir.
- İlk action `Button::new("open_project", "Open Project")` ve verilen
  `KeyBinding` ile render edilir; ikinci action
  `Button::new("clone_repo", "Clone Repository")` olarak gelir.
- İki action arasında `Divider::horizontal().color(DividerColor::Border)` ve
  küçük `or` label'ı kullanılır.

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

Zed içinden kullanım:

- `../zed/crates/project_panel/src/project_panel.rs`: worktree yokken project
  panel boş durumu.
- `../zed/crates/agent_ui/src/agent_panel.rs`: proje yokken agent panel boş
  durumu.
- `../zed/crates/git_ui/src/git_panel.rs`: worktree yokken git panel boş durumu.
- `../zed/crates/sidebar/src/sidebar.rs`: threads sidebar boş proje durumu.

Dikkat edilecekler:

- Bu component yalnızca iki standart proje eylemini render eder. Farklı action
  setleri veya açıklama metni gerekiyorsa özel `v_flex()` layout kurun.
- Handler verilmezse ilgili button render edilir ama click davranışı bağlanmaz.

