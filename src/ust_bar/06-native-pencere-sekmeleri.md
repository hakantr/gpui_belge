# Bölüm VI — Native pencere sekmeleri

Native tab desteğini ayrı bir aşama olarak ele al; controller state'i, platform çağrıları ve drag/drop hedefleri birlikte düşünülür.

## 14. System window tabs

`PlatformTitleBar::init(cx)`, `SystemWindowTabs::init(cx)` çağırır. Bu kurulum
iki şeyi yapar:

1. `WorkspaceSettings::use_system_window_tabs` ayarını izler ve pencerelerin
   `tabbing_identifier` değerlerini günceller (`cx.observe_global::<SettingsStore>(...)`,
   `system_window_tabs.rs:59-94`, `.detach()` ile yaşatılır).
2. Yeni `Workspace` entity'leri için action renderer kaydeder
   (`cx.observe_new(|workspace: &mut Workspace, ...|)`, `system_window_tabs.rs:96-139`):
   `ShowNextWindowTab`, `ShowPreviousWindowTab`, `MoveTabToNewWindow`,
   `MergeAllWindows`.

**Önemli binding farkı:** Bu action'lar `workspace.register_action(...)` ile
değil, **`workspace.register_action_renderer(...)`** ile bağlanır
(`system_window_tabs.rs:97`). Fark:

| API | Bağlama zamanı | Kapsam | Yan etki |
| :-- | :-- | :-- | :-- |
| `register_action` | Setup-time | Workspace entity'sinin tüm yaşam süresi | Sabit binding. |
| `register_action_renderer` | Her render'da | O frame'de oluşturulan `div` element'inde | Conditional binding: `tabs.len() > 1` veya `tab_groups.len() > 1` koşulları sağlanmazsa o frame'de action **bind edilmez**. |

Yani `ShowNextWindowTab` bir Workspace'te birden fazla tab varken çalışır,
tek tabla çalışmaz; runtime'da action map otomatik olarak değişir. Port
hedefinde Workspace kavramı yoksa bu pattern bire bir taşınamaz; yerine
"her render'da action handler'ları conditional olarak yeniden bağla"
prensibini koruyacak bir mekanizma gerekir.

Ek kısıt: `register_action_renderer` `Workspace` entity'sine bağlı olduğu
için **action'lar yalnızca bir workspace içinde bulunulurken** dispatch
edilebilir. Workspace dışı pencere (örn. settings standalone) bu
action'ları görmez.

### Sekme butonları

`SystemWindowTabs` içindeki her sekme kapatma yolu **`workspace::CloseWindow`
sabit'ini** dispatch eder. awk `Box::new\(CloseWindow\)` taraması altı ayrı
çağrı yerini açığa çıkarır:

| # | Yer | Tetikleyici | Hedef pencere |
| - | :-- | :-- | :-- |
| 1 | `system_window_tabs.rs:232` | Tab üzerinde middle-click (aktif tab) | Mevcut pencere |
| 2 | `system_window_tabs.rs:235` | Tab üzerinde middle-click (başka tab) | `item.handle.update(...)` ile o pencere |
| 3 | `system_window_tabs.rs:262` | Tab close (X) butonu click (aktif tab) | Mevcut pencere |
| 4 | `system_window_tabs.rs:265` | Tab close (X) butonu click (başka tab) | `item.handle.update(...)` ile o pencere |
| 5 | `system_window_tabs.rs:296` | Right-click → "Close Tab" | `handle_right_click_action` ile tab handle'ı |
| 6 | `system_window_tabs.rs:308` | Right-click → "Close Other Tabs" | Her diğer tab handle'ı |

Bu altı yol da **aynı sabit action'ı dispatch eder** — yapılandırılamaz, dış
crate'in `close_action` prop'u buraya geçmez (yalnızca Linux
`LinuxWindowControls`/`WindowControl` zincirinde çalışır). Port hedefinde
sekme kapatma davranışını farklılaştırmak istiyorsanız bu altı çağrı
yerini ayrı ayrı override etmeniz gerekir; tek bir flag yetmez.

**Cross-window dispatch paterni** (`handle.update(cx, |_, window, cx| { ... })`):
sekmelerden 4'ü "**hedef pencere mevcut pencere mi?**" sorusunu sorar; değilse
`item.handle.update(cx, |_view, window, cx| { window.dispatch_action(...) })`
ile tab'ın `AnyWindowHandle` üzerinden o pencerenin context'ine geçer. awk
`handle\.update\(` taraması altı çağrı yerini açığa çıkarır:

| Yer | Bağlam |
| :-- | :-- |
| `system_window_tabs.rs:77` | Settings observer'da her pencere için `set_tabbing_identifier` ve tab listesi yenileme |
| `system_window_tabs.rs:226` | Tab click → o pencereyi `activate_window()` |
| `system_window_tabs.rs:234` | Middle-click close başka tab → o pencereye `CloseWindow` |
| `system_window_tabs.rs:264` | X butonu click başka tab → o pencereye `CloseWindow` |
| `system_window_tabs.rs:377` | `handle_right_click_action` helper'ı (Close Tab/Close Other Tabs context menu) |
| `system_window_tabs.rs:439` | Tab bar dışına drop → o pencerede `move_tab_to_new_window()` |

Tüm çağrılar `let _ = handle.update(...)` deyimine sarılıdır çünkü
`update()` `Result<R, ()>` döner (pencere zaten kapanmış olabilir);
sonuç bilinçli olarak yutulur. Port hedefinde aynı paterni karşılamak
için: (1) her tab metadata'sı bir handle/proxy taşımalı, (2) cross-window
işlemler bu proxy üzerinden o pencerenin context'ine girip işi orada
yapmalı, (3) proxy çağrısı **fail-soft** olmalı (pencere kaybolmuşsa
sessizce geç).

**Conditional Option idiom'u** (`platform_title_bar.rs:248-255` ve
`299-306`): sol/sağ kontroller `show_X_controls.then(|| render_X_window_controls(...)).flatten()`
deseniyle dahil edilir. `bool::then(|| fn)` true → `Some(fn())`, false →
`None`; `render_X_window_controls` zaten `Option<AnyElement>` döner;
böylece dış `Option<Option<...>>` `.flatten()` ile tek seviye Option'a
indirilir. **Yan etki**: `then` closure'u boolean true ise **clone'u
gerçekleştirir** — `boxed_clone` zincirindeki adım 2/3'ün her render'da
neden çalıştığının nedeni budur. `if show_X { Some(render_X(...)) } else
{ None }` aynı sonucu verir; `then().flatten()` sadece daha kısa.

Sağ tık menüsü `ui::right_click_menu(ix).trigger(...).menu(...)` builder
zinciriyle kurulur (`system_window_tabs.rs:279-343`). Yapı:

```rust
right_click_menu(ix)
    .trigger(|_, _, _| tab)               // tetikleyici element (tab'ın kendisi)
    .menu(move |window, cx| {
        ContextMenu::build(window, cx, move |mut menu, _, _| {
            menu = menu.entry("Close Tab", None, ...);
            menu = menu.entry("Close Other Tabs", None, ...);
            menu = menu.entry("Move Tab to New Window", None, ...);
            menu = menu.entry("Show All Tabs", None, ...);
            menu.context(focus_handle)     // focus capturing
        })
    })
```

Dört menu entry'sinin her biri ayrı bir `move |window, cx| {...}` closure
alır; her closure içinde `Self::handle_right_click_action(cx, window,
&tabs_clone, |tab| predicate, |window, cx| body)` çağrılır. Tabs vec'i
bu yüzden **dört kere clone'lanır** (`tabs.clone()`, `other_tabs.clone()`,
`move_tabs.clone()`, `merge_tabs.clone()` — `system_window_tabs.rs:283-286`):
her closure kendi owned kopyasına ihtiyaç duyar. Port hedefinde aynı
builder pattern: `right_click_menu(id).trigger(trigger_fn).menu(menu_builder_fn)`;
`menu()` callback'inde `ContextMenu::build` ile entry'ler eklenir.

Menü işlemleri:

- Close Tab (#5)
- Close Other Tabs (#6)
- Move Tab to New Window (`SystemWindowTabController::move_tab_to_new_window` + `window.move_tab_to_new_window()`, `system_window_tabs.rs:313-327`)
- Show All Tabs (`window.toggle_window_tab_overview()`, `system_window_tabs.rs:329-339`)

Alt sağdaki plus butonu `zed_actions::OpenRecent { create_new_window: true }`
dispatch eder (`system_window_tabs.rs:485-490`) — bu da hardcoded'tır. Kendi
uygulamanızda bu action büyük olasılıkla `NewWindow`, `OpenWorkspace` veya
`CreateDocumentWindow` olmalıdır.

İlk pencere açılışındaki native tab durumu bu observer'dan değil,
`zed::build_window_options(...)` içindeki `tabbing_identifier` alanından gelir
(`zed/src/zed.rs:331-373`). GPUI pencere bootstrap'i de platform
`tab_bar_visible()` ve `tabbed_windows()` sonuçlarını controller'a işler
(`gpui/src/window.rs:1295-1299`). `SystemWindowTabs::init(...)` içindeki
`observe_global::<SettingsStore>` ise `was_use_system_window_tabs` değerini
tutup yalnız ayar değiştiğinde çalışır; değer değişmediyse erken döner
(`system_window_tabs.rs:55-64`). Toggle true olduğunda controller yeniden
başlatılır, mevcut pencerelere `"zed"` identifier'ı ve tab listesi yazılır;
toggle false olduğunda mevcut pencerelerin identifier'ı `None` yapılır ama
controller `init` tekrar çağrılmaz (`system_window_tabs.rs:66-90`).

Render sırasında `SystemWindowTabController` global state'i okunur. Controller
aktif pencerenin sekme grubunu döndürür; yoksa current window tek sekme gibi
gösterilir.

Sekme çubuğu şu durumlarda boş döner:

- Platform `window.tab_bar_visible()` false ve controller görünür değilse.
- `use_system_window_tabs` false ve yalnızca bir sekme varsa.

**Önemli platform farkı:** `Platform::tab_bar_visible()`'in trait
default impl'i `false` döndürür (`gpui/src/platform.rs:658-660`); bu
default'u **yalnızca macOS** override eder. Linux ve Windows'ta birinci
koşulun ilk parçası daima `true`'dur, yani çubuğun görünür olması
**tamamen `SystemWindowTabController::is_visible(...)` state'ine**
bağlıdır. `is_visible` ise `self.visible == Some(true)` kontrolünü
yapar (`gpui/src/app.rs:395`); `visible` alanı `init_visible` veya
`set_visible` çağrılana kadar `None`'dur, dolayısıyla pencere ilk
açıldığında ve `on_toggle_tab_bar` callback'i tetiklenene kadar Linux
ve Windows'ta sekme çubuğu **default olarak gizli** kalır. macOS dışındaki
platformlarda sekme çubuğunun görünmesi için controller'ın açıkça görünür
duruma alınması gerekir; yalnız `tab_bar_visible` çağrısını aramak yeterli
değildir.

macOS native tabbing için `set_tabbing_identifier(Some(...))` yalnız pencereye
identifier yazmaz; `NSWindow::setAllowsAutomaticWindowTabbing:YES` de çağırır.
`None` geldiğinde aynı global izin `NO` yapılır ve pencerenin tabbing identifier'ı
`nil` olur (`gpui_macos/src/window.rs:1174-1191`). Zed'in
`SystemWindowTabs::init(cx)` içindeki settings observer'ı bu nedenle yalnız
controller state'ini değil macOS native tabbing politikasını da açıp kapatır.

**Drag/drop owner ve olay ayrımı:** `DraggedWindowTab` adını ve alanlarını
mirror etmek tek başına yeterli değildir. Kaynakta owner ve olay ayrımı şöyledir:

- `render_tab(...).on_drag(...)` `DraggedWindowTab` üretir ve
  `last_dragged_tab = Some(tab.clone())` yapar.
- Aynı tab bar üzerindeki `.on_drop(...)` yalnızca
  `SystemWindowTabController::update_tab_position(cx, dragged_tab.id, ix)`
  çağırır.
- Tab bar dışına sol mouse-up olursa `last_dragged_tab.take()` ile
  `SystemWindowTabController::move_tab_to_new_window(cx, tab.id)` ve platform
  `window.move_tab_to_new_window()` akışı çalışır.
- `merge_all_windows` drag payload'ından veya sağ tık "Show All Tabs" menüsünden
  gelmez; yalnız `MergeAllWindows` action renderer'ı controller + platform merge
  çağırır. Sağ tık "Show All Tabs" sadece `window.toggle_window_tab_overview()`
  çağırır (`system_window_tabs.rs:329-339`).

Bu nedenle native tab portunda drag/drop davranışı `DraggedWindowTab` alan
paritesiyle birlikte **olay hedefine göre** mirror edilmelidir.

Sekme drag payload tipi `DraggedWindowTab` (`system_window_tabs.rs:29`):

```rust
#[derive(Clone)]
pub struct DraggedWindowTab {
    pub id: WindowId,
    pub ix: usize,
    pub handle: AnyWindowHandle,
    pub title: String,
    pub width: Pixels,
    pub is_active: bool,
    pub active_background_color: Hsla,
    pub inactive_background_color: Hsla,
}
```

Drag/drop sırasında `on_drag(DraggedWindowTab, ...)` payload'ı bu struct'tır.
`DraggedWindowTab` aynı zamanda `Render` implement eder; drag preview bu
struct'ın `title`, `width`, `is_active`, `active_background_color` ve
`inactive_background_color` alanlarından çizilir. `last_dragged_tab` yalnızca
tab bar dışına bırakma ihtimalini yakalamak için geçici state'tir; başarılı
`on_drop` içinde `None` yapılır.
Preview render'ı label fontunu aktif temadaki `ThemeSettings::ui_font`
değerinden alır ve `Tab::container_height(cx)` yüksekliğini kullanır
(`system_window_tabs.rs:498-528`); drag ghost için ayrı bir sabit yükseklik
yoktur.

**Controller grup mutasyonları** (`gpui/src/app.rs:417-530`): Public imzalar
basit görünür, fakat state algoritması port için önemlidir.

| Fonksiyon | State davranışı |
| :-- | :-- |
| `update_tab_position(cx, id, ix)` | `id` hangi gruptaysa yalnız o grupta çalışır; `ix >= len` veya aynı pozisyon ise no-op. |
| `update_tab_title(cx, id, title)` | Önce mevcut title aynı mı diye immutable okur; aynıysa mutable global almadan döner. |
| `add_tab(cx, id, tabs)` | `tabs` içinde `id` yoksa no-op. Mevcut bir grup, `tabs` içindeki **id hariç** sorted id listesiyle eşleşirse current tab o gruba push edilir; eşleşme yoksa `tab_groups.len()` yeni grup id'si olarak kullanılıp gelen `tabs` komple eklenir. |
| `remove_tab(cx, id)` | Tab'ı bulduğu gruptan çıkarır, boş kalan grubu `retain` ile siler ve çıkarılan tab'ı döndürür. |
| `move_tab_to_new_window(cx, id)` | Önce `remove_tab`; sonra yeni grup id'si `max(existing_key) + 1`, grup yoksa `0`. |
| `merge_all_windows(cx, id)` | `id`'nin mevcut grubunu başlangıç grubu yapar; tüm grupları drain eder, başlangıç tab'larını tekrar eklememek için retain uygular ve sonucu group `0` olarak yazar. |

`select_next_tab` ve `select_previous_tab` yalnız mevcut grubun içinde döner ve
hedef tab'ın `AnyWindowHandle`'ı üzerinde `activate_window()` çağırır
(`gpui/src/app.rs:532-563`). Grup değiştirme action'ları ise
`get_next_tab_group_window` / `get_prev_tab_group_window` üzerinden çalışır;
bu fonksiyonlarda group key sırası `HashMap` key sırası olduğu için kaynakta
zaten "next/previous ne demek?" TODO'su vardır (`gpui/src/app.rs:326-360`).

**Tab genişliği ölçümü** (`system_window_tabs.rs:455-471`): Tab bar
render'ı bir görünmez `canvas` element içerir. `canvas` iki callback
alır (`gpui/src/elements/canvas.rs:10-13`): `prepaint: FnOnce(Bounds,
&mut Window, &mut App) -> T` ve `paint: FnOnce(Bounds, T, &mut Window,
&mut App)`. Burada prepaint boş bırakılır (`|_, _, _| ()`); ölçüm
**paint** callback'inde yapılır: `bounds.size.width / number_of_tabs
as f32` hesaplanıp `entity.update(cx, |this, cx| { this.measured_tab_width
= width; cx.notify() })` ile state'e yazılır. Yeni sekme eklenince/silinince
veya pencere yeniden boyutlanınca paint tekrar çağrılır, `measured_tab_width`
güncellenir ve sekmeler yeniden render olur (paint sırasındaki bu
side-effect bir sonraki frame'de geri-beslemeyi tetikler).
`number_of_tabs` `tab_items.len().max(1)` ile en az 1'e clamp'lenir
(`system_window_tabs.rs:420`) — sıfıra bölmeyi engeller. Port hedefinde
aynı geri-besleme döngüsü gerekir: aksi halde sekme genişliği `0px`
veya statik kalır.

**Sekme ölçüleri, close ayarı ve drop işaretleri**
(`system_window_tabs.rs:153-276`):

- Her tab'ın genişliği `measured_tab_width.max(rem_size * 10)` ile en az
  `10rem` yapılır; sadece canvas ölçümüne güvenilmez.
- Dış tab bar yüksekliği `Tab::container_height(cx)`, tek tab yüksekliği
  `Tab::content_height(cx)` ile gelir. `ui::Tab` bu değerleri
  `DynamicSpacing::Base32` ve `Base32 - 1px` olarak hesaplar
  (`ui/src/components/tab.rs:79-84`); portta sabit `32px` yazmak density
  değişimlerini kaçırır.
- `ItemSettings::close_position` `Left` / `Right` değerlerini taşır ve default
  `Right`'tır; `show_close_button` ise `Always` / `Hover` / `Hidden` ve default
  `Hover`'dır (`settings_content/src/workspace.rs:214-239`).
- `Hidden` durumunda close icon hiç eklenmez. Diğerlerinde absolute close alanı
  `.top_2().w_4().h_4()` ile çizilir; `Left` için `.left_1()`, `Right` için
  `.right_1()` uygulanır. `Hover` durumunda icon `visible_on_hover("tab")`
  ile yalnız tab hover'ında görünür.
- Close icon ve orta mouse up aynı `CloseWindow` action'ını dispatch eder;
  hedef aktif pencere değilse action ilgili tab'ın `AnyWindowHandle`'ı üzerinde
  çalıştırılır.
- Drag-over preview `drop_target_background` ve `drop_target_border` kullanır,
  önce border'ı sıfırlar; hedef index dragged index'ten küçükse sol `border_l_2`,
  büyükse sağ `border_r_2` gösterir. Aynı index üstünde yan çizgi yoktur.

Alt sağdaki plus bölgesi yalnız action değildir: `.h_full()`,
`DynamicSpacing::Base06.rems(cx)` yatay padding, üst/sol border ve muted small
plus icon ile render edilir (`system_window_tabs.rs:473-492`). Click akışı
`zed_actions::OpenRecent { create_new_window: true }` dispatch eder; bağımsız
uygulamada aynı görsel alanı koruyup action'ı kendi yeni pencere/workspace
akışınıza bağlayın.

**Controller akışı:**

```text
settings toggle true
  -> SystemWindowTabController::init(cx)
  -> mevcut pencereler için window.set_tabbing_identifier(Some("zed"))
  -> window.tabbed_windows() varsa platform listesini kullan
  -> yoksa SystemWindowTab::new(window.window_title(), window.window_handle())
  -> SystemWindowTabController::add_tab(cx, window_id, tabs)

tab drag aynı tab bar'a drop
  -> update_tab_position(cx, dragged_tab.id, target_ix)

tab drag tab bar dışına mouse-up
  -> move_tab_to_new_window(cx, dragged_tab.id)
  -> ilgili platform window.move_tab_to_new_window()

context menu / action
  -> MoveTabToNewWindow: controller + platform move
  -> right-click Show All Tabs: platform tab overview toggle; merge değil
  -> MergeAllWindows action: controller + platform merge
  -> ShowNext/PreviousWindowTab: controller tab handle'ını activate_window()
```

Kendi uygulamanızda native tab desteğini ilk aşamada istemiyorsanız:

- `PlatformTitleBar::init(cx)` çağrısını kaldırmak yerine, port edilen
  `PlatformTitleBar` içinde `SystemWindowTabs` child'ını feature flag ile kapatın.
- `tabbing_identifier` değerini `None` bırakın.
- Sekme action'larını kaydetmeyin.

Native tab desteğini koruyacaksanız:

- Her pencereye aynı uygulama tab group adı verin.
- `SystemWindowTabController::init(cx)` GPUI `App` init sırasında zaten
  kuruludur; settings toggle true olduğunda Zed bunu tekrar çağırıp controller
  state'ini temiz şekilde yeniden başlatır.
- Yeni açılan pencereleri controller'a `SystemWindowTab::new(title, handle)` ile
  bildirin.
- Sekme kapatma ve yeni pencere action'larını uygulama lifecycle'ınıza bağlayın.

