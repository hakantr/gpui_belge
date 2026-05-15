# Native pencere sekmeleri

Native pencere sekmeleri (özellikle macOS'taki sistem sekmeleri),
başlık çubuğunun en karmaşık parçasıdır. Bu konu, ayrı bir aşama
olarak ele alınır; çünkü kararlar tek başına değil, üç parçanın
birlikte düşünülmesiyle verilir: controller state'i, platform çağrıları
ve drag/drop hedefleri. Bu üçü ayrı ayrı yazılırsa parçalar arasında
uyumsuzluk kaçınılmaz olur.

## 14. System window tabs

`PlatformTitleBar::init(cx)` çağrısı, alt katmandaki
`SystemWindowTabs::init(cx)` fonksiyonunu da tetikler. Bu kurulum iki
iş yapar:

1. `WorkspaceSettings::use_system_window_tabs` ayarını izlemeye başlar
   ve pencerelerin `tabbing_identifier` değerlerini ayar değiştikçe
   günceller. İzleme `cx.observe_global::<SettingsStore>(...)` ile
   kurulur, `system_window_tabs.rs:59-94` aralığında çalışır ve
   subscription `.detach()` ile crate ömrü boyunca canlı tutulur.
2. Yeni açılan `Workspace` entity'leri için bir action renderer
   kaydeder. Kayıt `cx.observe_new(|workspace: &mut Workspace, ...|)`
   bloğunda yapılır (`system_window_tabs.rs:96-139`) ve şu dört
   action'ı bağlar: `ShowNextWindowTab`, `ShowPreviousWindowTab`,
   `MoveTabToNewWindow`, `MergeAllWindows`.

**Burada gözden kaçırılmaması gereken kritik bir binding farkı
vardır.** Bu action'lar `workspace.register_action(...)` ile değil,
**`workspace.register_action_renderer(...)`** ile bağlanır
(`system_window_tabs.rs:97`). İki API arasındaki fark, hem zamanlama
hem de kapsam açısından önemlidir:

| API | Bağlama zamanı | Kapsam | Yan etki |
| :-- | :-- | :-- | :-- |
| `register_action` | Setup-time | Workspace entity'sinin tüm yaşam süresi | Sabit binding. |
| `register_action_renderer` | Her render'da | O frame'de oluşturulan `div` element'inde | Conditional binding: `tabs.len() > 1` veya `tab_groups.len() > 1` koşulları sağlanmazsa o frame'de action **bind edilmez**. |

Pratik sonuç şudur: `ShowNextWindowTab` action'ı, bir workspace
içinde birden fazla tab açık olduğunda çalışır; tek tab varken
çağrılsa bile bir etki üretmez. Çünkü runtime'da action map o frame
için otomatik olarak farklı bir şekilde kurulur. Port hedefinde
"Workspace" kavramı doğrudan yoksa bu desen birebir taşınamaz; ama
"her render'da action handler'ları koşullu olarak yeniden bağla"
prensibini koruyacak bir mekanizma kurulması zorunludur. Aksi halde
tek tab varken bile sekme dolaşma action'ı çalışıyormuş gibi
görünür ve test edilemez davranışlar oluşur.

Ayrıca bu API'nin ek bir kısıtı vardır: `register_action_renderer`
bağlandığı `Workspace` entity'sine kilitlendiği için, **bu
action'lar yalnızca bir workspace içindeyken dispatch edilebilir**.
Workspace bağlamı dışındaki pencereler (örneğin standalone bir
settings penceresi) bu action'ları hiç görmez.

### Sekme butonları

`SystemWindowTabs` içindeki sekme kapatma yollarının tamamı, ortak
olarak **`workspace::CloseWindow` sabit action'ını** dispatch eder.
Bu yolların kaç tane olduğunu görmek için `Box::new\(CloseWindow\)`
deseniyle yapılan awk taraması altı farklı çağrı noktası ortaya çıkarır:

| # | Yer | Tetikleyici | Hedef pencere |
| - | :-- | :-- | :-- |
| 1 | `system_window_tabs.rs:232` | Tab üzerinde middle-click (aktif tab) | Mevcut pencere |
| 2 | `system_window_tabs.rs:235` | Tab üzerinde middle-click (başka tab) | `item.handle.update(...)` ile o pencere |
| 3 | `system_window_tabs.rs:262` | Tab close (X) butonu click (aktif tab) | Mevcut pencere |
| 4 | `system_window_tabs.rs:265` | Tab close (X) butonu click (başka tab) | `item.handle.update(...)` ile o pencere |
| 5 | `system_window_tabs.rs:296` | Right-click → "Close Tab" | `handle_right_click_action` ile tab handle'ı |
| 6 | `system_window_tabs.rs:308` | Right-click → "Close Other Tabs" | Her diğer tab handle'ı |

Bu altı yolun her birinde **aynı sabit action dispatch edilir** ve
dış crate'in verdiği `close_action` prop'u bu kapatma yollarına
ulaşmaz. Dışarıdan gelen close action yalnızca Linux tarafındaki
`LinuxWindowControls`/`WindowControl` zincirinde işlem görür. Port
hedefinde sekme kapatma davranışını farklılaştırmak istendiğinde, bu
altı çağrı noktasının her biri ayrı ayrı override edilmek zorundadır;
tek bir flag açıp kapatmak bütün bu noktaları aynı anda
değiştirmeye yetmez.

**Cross-window dispatch deseni**, yani
`handle.update(cx, |_, window, cx| { ... })` çağrı zinciri, bu
sekme yollarının dördünde merkezi rol oynar. Bu dördü, çağrı anında
"**hedef pencere mevcut pencere mi?**" sorusunu sorar; değilse
`item.handle.update(cx, |_view, window, cx| { window.dispatch_action(...) })`
yapısıyla tab'ın `AnyWindowHandle`'ı üzerinden ilgili pencerenin
context'ine geçilir ve action o pencerede dispatch edilir. Aynı
`handle\.update\(` deseninin awk taraması altı çağrı noktası
açığa çıkarır:

| Yer | Bağlam |
| :-- | :-- |
| `system_window_tabs.rs:77` | Settings observer'da her pencere için `set_tabbing_identifier` ve tab listesi yenileme |
| `system_window_tabs.rs:226` | Tab click → o pencereyi `activate_window()` |
| `system_window_tabs.rs:234` | Middle-click close başka tab → o pencereye `CloseWindow` |
| `system_window_tabs.rs:264` | X butonu click başka tab → o pencereye `CloseWindow` |
| `system_window_tabs.rs:377` | `handle_right_click_action` helper'ı (Close Tab/Close Other Tabs context menu) |
| `system_window_tabs.rs:439` | Tab bar dışına drop → o pencerede `move_tab_to_new_window()` |

Bu çağrıların hepsi `let _ = handle.update(...)` deyimine sarılıdır.
Bunun sebebi, `update()` fonksiyonunun `Result<R, ()>` döndürmesidir;
yani çağrı sırasında pencere zaten kapanmış olabilir. Bu durumda
sonuç bilinçli olarak yutulur ve hata fırlatılmaz. Port hedefinde aynı
deseni karşılamak için üç şey birlikte sağlanmalıdır:
(1) her tab metadata yapısı bir handle veya proxy taşımalıdır;
(2) cross-window işlemler bu proxy üzerinden ilgili pencerenin
context'ine girip işi orada yapmalıdır;
(3) proxy çağrısı **fail-soft** davranmalı, hedef pencere ortadan
kalkmışsa sessizce geçilmelidir. Bu üç kural birlikte uygulanmadığı
sürece, kapanmış pencerelere yapılan çağrılar uygulamanın çökmesine
yol açabilir.

**Conditional Option idiom'u**, `platform_title_bar.rs` içinde
`248-255` ve `299-306` aralıklarında geçer. Sol ve sağ kontroller
şu desenle dahil edilir:
`show_X_controls.then(|| render_X_window_controls(...)).flatten()`.

Bu desenin işleyişi şöyledir: `bool::then(|| fn)` ifadesi, boolean
`true` ise `Some(fn())` döner, `false` ise `None` döner.
`render_X_window_controls` fonksiyonu zaten `Option<AnyElement>`
döndürdüğü için, dış sarmal `Option<Option<...>>` olur ve `.flatten()`
ile tek seviye `Option`'a indirgenir. Burada gözden kaçabilecek bir
yan etki vardır: `then` closure'u, boolean `true` olduğunda gövdesini
çalıştırır ve gövde içinde **clone işlemi** gerçekleşir. Bu, ileride
bahsedilecek `boxed_clone` zincirindeki adım 2 ve 3'ün her render'da
neden çalıştığının doğrudan nedenidir. Aynı sonucu daha açık biçimde
`if show_X { Some(render_X(...)) } else { None }` ifadesiyle de yazmak
mümkündür; `then().flatten()` formu yalnızca daha kısadır, ek bir
avantaj sağlamaz.

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

Bu yapıda dört menu entry'sinin her biri ayrı bir
`move |window, cx| {...}` closure'u alır. Her closure'ın gövdesinde
ortak olarak `Self::handle_right_click_action(cx, window,
&tabs_clone, |tab| predicate, |window, cx| body)` çağrısı yapılır.
Buradan doğan ilginç bir bellek davranışı vardır: `tabs` vec'i
**dört defa clone'lanır** (`tabs.clone()`, `other_tabs.clone()`,
`move_tabs.clone()`, `merge_tabs.clone()` —
`system_window_tabs.rs:283-286`). Bunun nedeni her closure'ın kendi
owned kopyasına ihtiyaç duymasıdır; reference olarak paylaşmak,
closure lifetime'larıyla çakışır. Port hedefinde aynı builder kalıbı
kullanılır:
`right_click_menu(id).trigger(trigger_fn).menu(menu_builder_fn)`
zinciri kurulur ve `menu()` callback'i içinde `ContextMenu::build`
ile entry'ler eklenir.

Menüye konulan dört işlem şunlardır:

- Close Tab (#5)
- Close Other Tabs (#6)
- Move Tab to New Window (`SystemWindowTabController::move_tab_to_new_window` + `window.move_tab_to_new_window()`, `system_window_tabs.rs:313-327`)
- Show All Tabs (`window.toggle_window_tab_overview()`, `system_window_tabs.rs:329-339`)

Sekme barının alt sağ köşesindeki plus butonu, click anında
`zed_actions::OpenRecent { create_new_window: true }` action'ını
dispatch eder (`system_window_tabs.rs:485-490`). Bu davranış da sabit
şekilde gömülüdür; port hedefinde bu noktanın değiştirilmesi büyük
ihtimalle gereklidir. Bağımsız bir uygulamada bu action genellikle
`NewWindow`, `OpenWorkspace` veya `CreateDocumentWindow` gibi ürünün
kendi action'ı ile değiştirilir.

İlk pencere açılışındaki native tab durumu, bu settings observer
zincirinden değil, çok daha önce işleyen başka bir yoldan beslenir:
`zed::build_window_options(...)` fonksiyonu içindeki `tabbing_identifier`
alanı bu rolü üstlenir (`zed/src/zed.rs:331-373`). GPUI'nin pencere
bootstrap aşaması ise platformun `tab_bar_visible()` ve
`tabbed_windows()` çağrılarının sonucunu doğrudan controller'a işler
(`gpui/src/window.rs:1295-1299`). Daha sonra çalışan
`SystemWindowTabs::init(...)` içindeki `observe_global::<SettingsStore>`
gözlemcisi, `was_use_system_window_tabs` değerini hafızasında tutar ve
yalnız ayar değiştiğinde tetiklenir; değer değişmediyse hemen erken
döner (`system_window_tabs.rs:55-64`).

Toggle değeri `true` olduğunda controller yeniden başlatılır; mevcut
tüm pencerelere `"zed"` identifier'ı ve tab listesi yazılır. Toggle
`false` olduğunda ise mevcut pencerelerin identifier'ı `None` yapılır,
ancak controller'ın `init` fonksiyonu tekrar çağrılmaz
(`system_window_tabs.rs:66-90`). Bu asimetri kasıtlıdır: native tab'i
devre dışı bırakmak kontrolcüyü temizlemekle değil, sadece pencere
identifier'larını çekmekle olur.

Render sırasında `SystemWindowTabController`'ın global state'i okunur.
Bu controller, aktif pencerenin ait olduğu sekme grubunu döndürür;
böyle bir grup yoksa, mevcut pencere tek sekme olarak gösterilir.

Sekme çubuğunun boş dönmesi iki durumda mümkündür:

- Platform `window.tab_bar_visible()` çağrısı `false` döner **ve**
  controller görünür durumda değildir.
- `use_system_window_tabs` ayarı `false` durumda ve yalnız bir sekme
  vardır.

**Burada önemli bir platform farkı yatar.** `Platform::tab_bar_visible()`
trait'inin default implementasyonu `false` döner
(`gpui/src/platform.rs:658-660`). Bu default'u **yalnızca macOS**
override eder. Bunun sonucu olarak, Linux ve Windows'ta yukarıdaki
ilk koşulun ilk parçası daima `true` olarak değerlendirilir; yani
sekme çubuğunun görünürlüğü **tamamen
`SystemWindowTabController::is_visible(...)` state'ine** bağlanır.
`is_visible` fonksiyonu da `self.visible == Some(true)` kontrolünü
yapar (`gpui/src/app.rs:395`); ancak `visible` alanı, `init_visible`
veya `set_visible` çağrılana kadar `None` durumdadır. Dolayısıyla
pencere ilk açıldığında ve `on_toggle_tab_bar` callback'i tetiklenmediği
sürece, Linux ve Windows'ta sekme çubuğu **varsayılan olarak gizli**
kalır. macOS dışındaki platformlarda sekme çubuğunun görünmesi için
controller'ın açıkça görünür duruma alınması gerekir; yalnızca
`tab_bar_visible` çağrısını aramak yetmez. Bu noktayı atlayan bir
port, "neden Linux'ta sekmeler hiç görünmüyor?" sorusuyla saatler
kaybedebilir.

macOS'taki native tabbing için `set_tabbing_identifier(Some(...))`
çağrısının yaptığı iş, yalnızca pencereye identifier yazmak değildir.
Aynı çağrı, paralel olarak `NSWindow::setAllowsAutomaticWindowTabbing:YES`
fonksiyonunu da çağırır. Ters yönde, `None` değeri geldiğinde aynı
global izin `NO` olarak set edilir ve pencerenin tabbing identifier'ı
`nil` yapılır (`gpui_macos/src/window.rs:1174-1191`). Bu yüzden Zed'in
`SystemWindowTabs::init(cx)` içindeki settings observer'ı yalnız
controller state'ini değil, aynı zamanda macOS'un native tabbing
politikasını da açıp kapatır.

**Drag/drop'ta owner ve olay ayrımı.** `DraggedWindowTab` tipinin
adını ve alanlarını mirror etmek başlı başına yeterli değildir; çünkü
sürükleme/bırakma davranışı, hangi alanda olay tetiklendiğine göre
farklı yollar izler. Kaynaktaki owner ve olay ayrımı şu şekildedir:

- `render_tab(...).on_drag(...)` çağrısı bir `DraggedWindowTab`
  payload'ı üretir ve `last_dragged_tab = Some(tab.clone())` ifadesiyle
  geçici state'i set eder.
- Aynı tab bar üzerinde tetiklenen `.on_drop(...)` çağrısı yalnızca
  `SystemWindowTabController::update_tab_position(cx, dragged_tab.id, ix)`
  fonksiyonunu çalıştırır; başka bir iş yapmaz. Burada hedef, mevcut
  bar içinde sekmenin yerini değiştirmektir.
- Tab bar dışında sol mouse-up gerçekleşirse, `last_dragged_tab.take()`
  ile state alınır ve iki şey arka arkaya çalışır: önce
  `SystemWindowTabController::move_tab_to_new_window(cx, tab.id)`,
  sonra platform tarafındaki `window.move_tab_to_new_window()` çağrısı.
- `merge_all_windows` ise drag payload'ı üzerinden veya sağ tık "Show
  All Tabs" menüsünden tetiklenmez. Yalnızca `MergeAllWindows` action
  renderer'ı, controller'daki merge fonksiyonunu ve platform merge
  çağrısını birlikte tetikler. Sağ tıktaki "Show All Tabs" ise yalnız
  `window.toggle_window_tab_overview()` çağrısı yapar
  (`system_window_tabs.rs:329-339`); merge işlemi değildir.

Bu farklar nedeniyle native tab portunda drag/drop davranışı sadece
`DraggedWindowTab` alanları paralel olarak taşınarak çözülmez; aynı
zamanda **olayın hangi hedefte gerçekleştiğine göre** mirror edilir.
"Drop nerede oldu?" sorusunun cevabına göre üç ayrı dal vardır ve bu
dalların hepsi ayrı kodlanır.

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

Drag/drop sürecinde `on_drag(DraggedWindowTab, ...)` çağrısının
payload'ı bu struct'tır. Aynı `DraggedWindowTab` tipi, aynı zamanda
`Render` trait'ini de implement eder; sürükleme önizlemesi, bu
struct'ın `title`, `width`, `is_active`, `active_background_color` ve
`inactive_background_color` alanlarından doğrudan çizilir.

`last_dragged_tab` alanı yalnızca geçici bir state'tir ve tek bir
amaca hizmet eder: sekmenin tab bar dışına bırakılma ihtimalini
yakalamak. Başarılı bir `on_drop` çağrısı tamamlandığında bu alan
`None` yapılır; aksi halde state sızıntısı oluşur.

Preview render'ı, etiket fontunu aktif tema üzerinden
`ThemeSettings::ui_font` değerinden alır ve yüksekliği
`Tab::container_height(cx)` ile hesaplar
(`system_window_tabs.rs:498-528`). Drag ghost'u için ayrı, sabit bir
yükseklik tutulmaz; önizleme her zaman gerçek sekmeye eşit boyda
çıkar.

**Controller grup mutasyonları** (`gpui/src/app.rs:417-530`). Bu
fonksiyonların public imzaları yüzeyde basit görünür; ama gövdedeki
state algoritması port hedefi için kritik öneme sahiptir. Aşağıdaki
tablo her bir fonksiyonun state üzerinde tam olarak ne yaptığını
gösterir:

| Fonksiyon | State davranışı |
| :-- | :-- |
| `update_tab_position(cx, id, ix)` | `id` hangi gruptaysa yalnız o grupta çalışır; `ix >= len` veya aynı pozisyon ise no-op. |
| `update_tab_title(cx, id, title)` | Önce mevcut title aynı mı diye immutable okur; aynıysa mutable global almadan döner. |
| `add_tab(cx, id, tabs)` | `tabs` içinde `id` yoksa no-op. Mevcut bir grup, `tabs` içindeki **id hariç** sorted id listesiyle eşleşirse current tab o gruba push edilir; eşleşme yoksa `tab_groups.len()` yeni grup id'si olarak kullanılıp gelen `tabs` komple eklenir. |
| `remove_tab(cx, id)` | Tab'ı bulduğu gruptan çıkarır, boş kalan grubu `retain` ile siler ve çıkarılan tab'ı döndürür. |
| `move_tab_to_new_window(cx, id)` | Önce `remove_tab`; sonra yeni grup id'si `max(existing_key) + 1`, grup yoksa `0`. |
| `merge_all_windows(cx, id)` | `id`'nin mevcut grubunu başlangıç grubu yapar; tüm grupları drain eder, başlangıç tab'larını tekrar eklememek için retain uygular ve sonucu group `0` olarak yazar. |

`select_next_tab` ve `select_previous_tab` fonksiyonları, yalnız
mevcut grubun içinde döner ve hedef sekmenin `AnyWindowHandle`'ı
üzerinde `activate_window()` çağırarak o pencereyi öne getirir
(`gpui/src/app.rs:532-563`). Grup değiştirme action'ları ise farklı
bir yoldan, `get_next_tab_group_window` ve `get_prev_tab_group_window`
fonksiyonları üzerinden işler. Burada dikkat çekici bir nokta var:
bu iki fonksiyonda grup key sırası, `HashMap` key sırası olduğu için
tutarlı bir "önce/sonra" tanımı yoktur. Kaynak kodunda zaten bu
duruma işaret eden bir "next/previous ne demek?" TODO yorumu mevcuttur
(`gpui/src/app.rs:326-360`). Port hedefinde grup geçişlerine deterministik
bir sıralama isteniyorsa, bu noktada `HashMap` yerine sıralı bir yapı
tercih edilir.

**Tab genişliği ölçümü**, `system_window_tabs.rs:455-471` aralığında
bulunan ince bir mekanizmadır. Tab bar render'ı, kullanıcıya hiç
görünmeyen bir `canvas` elementi içerir. Bu `canvas` tipi iki callback
alır (`gpui/src/elements/canvas.rs:10-13`):
`prepaint: FnOnce(Bounds, &mut Window, &mut App) -> T` ve
`paint: FnOnce(Bounds, T, &mut Window, &mut App)`.

Bu kullanımda `prepaint` boş bırakılır (`|_, _, _| ()`); asıl ölçüm
**`paint`** callback'inde yapılır. Burada `bounds.size.width /
number_of_tabs as f32` formülü ile bir sekme genişliği hesaplanır,
ardından bu değer `entity.update(cx, |this, cx| {
this.measured_tab_width = width; cx.notify() })` çağrısıyla state'e
yazılır.

Bu yapının döngüsel davranışı şu şekilde işler: yeni bir sekme
eklendiğinde, mevcut bir sekme silindiğinde veya pencere yeniden
boyutlandığında paint tekrar çağrılır; `measured_tab_width`
güncellenir ve sekmeler güncel genişlikle yeniden render olur.
Paint sırasında oluşturulan bu side-effect, bir sonraki frame'de
geri-beslemeyi tetikler.

Burada bölme hatasına karşı bir güvence vardır: `number_of_tabs`
ifadesi `tab_items.len().max(1)` ile en az 1'e clamp'lenir
(`system_window_tabs.rs:420`). Bu sayede sekme sayısı sıfır olduğunda
bile bölme işlemi güvenli kalır. Port hedefinde aynı geri-besleme
döngüsünün kurulması zorunludur; aksi halde sekme genişliği ya `0px`
çıkar ya da hiç güncellenmeyip statik kalır.

**Sekme ölçüleri, close ayarı ve drop işaretleri** konuları
`system_window_tabs.rs:153-276` aralığında birlikte ele alınır.
Burada gözlenmesi gereken altı detay vardır:

- Her sekmenin genişliği `measured_tab_width.max(rem_size * 10)`
  ifadesi ile **en az** `10rem` olacak şekilde clamp edilir. Yani
  yalnızca canvas ölçümüne güvenilmez; çok dar sekmelerin oluşmasının
  önüne geçilir.
- Dış tab bar yüksekliği `Tab::container_height(cx)`, tek sekmenin
  yüksekliği ise `Tab::content_height(cx)` üzerinden hesaplanır.
  `ui::Tab` bu iki değeri `DynamicSpacing::Base32` ve `Base32 - 1px`
  cinsinden üretir (`ui/src/components/tab.rs:79-84`). Port hedefinde
  bu değerlere sabit `32px` yazılırsa, dinamik density değişimleri
  doğru takip edilemez ve UI farklı yoğunluklarda bozulur.
- `ItemSettings::close_position` ayarı `Left` ve `Right` değerlerini
  alır; default olarak `Right`'tır. `show_close_button` ayarı ise
  `Always`, `Hover` ve `Hidden` değerlerini alır; default `Hover`'dır
  (`settings_content/src/workspace.rs:214-239`).
- `Hidden` durumunda close icon hiç eklenmez. Diğer durumlarda kapatma
  alanı `.top_2().w_4().h_4()` ölçüleriyle çizilir; `Left` ayarında
  `.left_1()`, `Right` ayarında `.right_1()` uygulanır. `Hover`
  durumunda icon `visible_on_hover("tab")` modifier'ı ile yalnız
  sekmenin üzerine gelindiğinde görünür hâle gelir.
- Close icon'una yapılan tıklama ile sekmenin ortasındaki mouse up
  olayı aynı `CloseWindow` action'ını dispatch eder. Hedef sekme,
  şu anki aktif pencereye ait değilse action o sekmenin
  `AnyWindowHandle`'ı üzerinden çalıştırılır.
- Drag-over preview'ı `drop_target_background` ve `drop_target_border`
  token'larını kullanır. Önce border tamamen sıfırlanır; hedef index
  sürüklenen indexten küçükse sol tarafa `border_l_2`, büyükse sağ
  tarafa `border_r_2` çizilir. Aynı index üstünde herhangi bir yan
  çizgi gösterilmez; bu, "sekme buraya zaten ait" durumunun görsel
  ifadesidir.

Alt sağdaki plus bölgesi, tek başına bir action sayılmaz. Görsel
olarak da kendine ait bir yapısı vardır: `.h_full()` ile dikeyde tüm
alana yayılır, `DynamicSpacing::Base06.rems(cx)` ile yatay padding
alır; üst ve sol kenarına border çizilir; içine muted small bir plus
ikonu yerleştirilir (`system_window_tabs.rs:473-492`). Click akışı,
yukarıda da bahsedildiği gibi
`zed_actions::OpenRecent { create_new_window: true }` action'ını
dispatch eder. Bağımsız bir uygulamada genellikle aynı görsel alan
korunur, ama action ürünün kendi yeni pencere veya workspace akışına
yönlendirilir.

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

Native tab desteği bir uygulamada ilk aşamada istenmiyorsa şu yol
izlenir:

- `PlatformTitleBar::init(cx)` çağrısı tamamen kaldırılmaz; bunun
  yerine port edilen `PlatformTitleBar` içindeki `SystemWindowTabs`
  child'ı feature flag ile kapatılır. Böylece native tab desteğinin
  geri açılması ileride kolay olur.
- Pencerelerin `tabbing_identifier` alanı `None` olarak bırakılır.
- Sekme action'ları workspace'e kaydedilmez.

Native tab desteği korunacaksa şu yol izlenir:

- Aynı tab grubuna ait pencerelerin hepsine tek bir tab group adı
  verilir.
- `SystemWindowTabController::init(cx)` çağrısı GPUI `App` init
  sırasında zaten kurulmuştur. Settings toggle `true` olduğunda Zed bu
  fonksiyonu tekrar çağırır ve controller state'i temiz biçimde
  yeniden başlatılır; manuel olarak tekrar tetiklenmesine gerek yoktur.
- Yeni açılan pencerelerin controller'a bildirilmesi için
  `SystemWindowTab::new(title, handle)` çağrısı kullanılır.
- Sekme kapatma ve yeni pencere action'ları uygulamanın lifecycle
  modeline doğrudan bağlanır; bunlar boş bırakılırsa native tab
  yüzeyi görünür ama çalışmaz duruma düşer.

