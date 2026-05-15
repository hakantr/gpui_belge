# Platform titlebar render akışı ve pencere kontrolleri

Bu bölümden itibaren doğrudan başlık çubuğunun render davranışına giriyoruz. Pencere nasıl sürükleniyor? Linux, Windows ve macOS farkları nerede ortaya çıkıyor? Close, minimize ve maximize butonları hangi mekanizmalarla uygulamaya bağlanıyor? Önceki bölümlerde kurulan katmanlar burada somut davranışa dönüşür.

## 11. Davranış modeli

### Sürükleme

Ana titlebar yüzeyi `WindowControlArea::Drag` etiketiyle işaretlenir. Bu etiket, alanı platforma "sürüklenebilir başlık" olarak tanıtır. Buna ek olarak sol mouse down ve mouse move olaylarının zincirinde `window.start_window_move()` çağrısı tetiklenir. Bu iki mekanizma birlikte çalışır. Yalnızca işaretleme yapmak ya da yalnızca manuel çağrıya güvenmek yeterli olmaz.

Başlık çubuğuna yerleştirilen interaktif elementler, kendi mouse down/click olaylarında propagation'ı durdurmalıdır. Buna butonlar, menü tetikleyicileri ve arama kutuları dahildir. Aksi halde aynı tıklama hem ilgili element hem de altındaki "sürükle" yüzeyi tarafından algılanır. Sonuçta kullanıcı menüye basmak isterken pencereyi yanlışlıkla sürükleyebilir.

`should_move` bayrağı sürükleme akışının merkezindedir. Kaynakta `platform_title_bar.rs:200-220` aralığında dört farklı noktada güncellenir:

- `on_mouse_down(Left, ...)` çağrısında `should_move` `true` yapılır; yani "olası bir drag başlayabilir" durumu işaretlenir.
- `on_mouse_move(...)` içinde, `should_move` `true` ise **önce** bayrak `false`'a çekilir, **sonra** `window.start_window_move()` çağrılır. Sıralama önemlidir: tetikleyici tek-atışlıktır. Bir kez ateşlendikten sonra tekrar çalışması için yeni bir mouse_down zinciri gerekir.
- `on_mouse_up(Left, ...)` olayında `should_move` yine `false` yapılır. Bu, drag hiç başlamamış olsa bile state'in temiz kalmasını sağlar.
- `on_mouse_down_out(...)` olayında da `should_move` `false` yapılır. Bu sayede başlık çubuğunun dışına tıklanması durumunda bayrak geriden gelip ileride başka bir drag'i tetiklemez; state sızıntısı önlenmiş olur.

Linux pencere kontrol katmanı, **üç ayrı `stop_propagation()` noktası** kullanır. Bu üç nokta tek tek bakıldığında kolayca gözden kaçar. Dağınık satırlara yayıldıkları için `rg` çıktısı tek başına resmi toparlamaz; awk taramasıyla birlikte okumak daha güvenlidir:

| Yer | Olay | Kaynak | Neyi engeller? |
| :-- | :-- | :-- | :-- |
| `LinuxWindowControls` h_flex container | `on_mouse_down(Left)` | `platform_linux.rs:50` | Buton grubuna basıldığında titlebar drag başlamasını. |
| `WindowControl` (her buton) | `on_mouse_move` | `platform_linux.rs:228` | Buton üzerinde mouse gezerken titlebar drag tetiklenmesini. |
| `WindowControl` `on_click` callback gövdesi | `cx.stop_propagation()` ilk satır | `platform_linux.rs:230` | Click event'inin yukarı kabarıp başka handler'lara ulaşmasını. Action dispatch'inden ÖNCE çalışır. |

Bu üç engel birlikte yoksa üç ayrı sorun doğar. Önce, butonun üstüne yapılan mouse_down olayı alttaki sürükleme yüzeyini tetikler ve pencere drag'e başlar. Sonra, buton üzerindeki mouse hareketi yine drag'i ateşleyebilir. Son olarak close action dispatch edilirken aynı click `PlatformTitleBar` katmanına kadar kabarır ve `should_move = true` bayrağını set eder. Bu yüzden port hedefinde bu üç noktanın her birine **eşdeğer engeller** yerleştirilir. Eksik kalan tek bir nokta bile davranışı bozar.

Windows tarafında aynı amaca hizmet eden daha kısa bir ifade vardır: `.occlude()` çağrısı (`platform_windows.rs:128`). Bu çağrı, caption butonu üzerindeki mouse event'lerinin alt katmanlara sızmasını engeller. Linux'taki üç ayrı `stop_propagation()` çağrısının yaptığı işi Windows tarafında bu tek çağrı toparlar.

### Fullscreen render ayrımı

Fullscreen yalnızca görsel bir detay değildir. Başlık çubuğuna hangi child'ların ekleneceğini de değiştirir (`platform_title_bar.rs:243-320`). `window.is_fullscreen()` `true` döndüğünde sol tarafa macOS trafik ışığı padding'i de Linux sol pencere kontrolleri de eklenmez. Bunların yerine yalnızca `.pl_2()` fallback değeri kullanılır.

Aynı render zincirinde sağ taraf bloğu da `when(!window.is_fullscreen(), ...)` koruyucusunun arkasındadır. Başka bir deyişle fullscreen'de sağ caption kontrolleri ve Linux CSD'deki sağ tık sistem pencere menüsü kurulmaz. `SystemWindowTabs` child'ı ise bu koşulun dışında kalır; fullscreen olsun ya da olmasın titlebar'ın altına eklenmeye devam eder (`platform_title_bar.rs:322-325`).

Port hedefinde bu ayrım "fullscreen olunca padding'i değiştir" kadar basit ele alınmamalıdır. Fullscreen aynı anda hem sol/sağ pencere kontrol render'ını etkiler hem de Linux CSD'deki `window.show_window_menu(...)` bağını devre dışı bırakır. Bu yüzden tek bir genel kural yazmak yerine, etkilenen alanlar tek tek düşünülür.

### macOS trafik ışığı boşluğu

macOS tarafında sol boşluk iki ayrı kaynaktan gelir. Pencere açılırken `TitlebarOptions.traffic_light_position` değeri `Some(point(px(9.0), px(9.0)))` olarak verilir; bu native trafik ışıklarının pencere içindeki konumunu belirler. Render sırasında ise ürün child'larının bu alana girmemesi için `TRAFFIC_LIGHT_PADDING` kadar sol padding uygulanır. Bu sabit `ui/src/utils/constants.rs` içinde, `macos_sdk_26` cfg'i açıksa `78.0`, değilse `71.0` olarak tanımlıdır. Yani `traffic_light_position` ile `TRAFFIC_LIGHT_PADDING` aynı şey değildir: ilki native butonların konumu, ikincisi custom titlebar içeriğinin başlayacağı güvenli boşluktur.

### Çift tıklama

Çift tıklama davranışı Zed kaynağında platforma göre farklı işlenir:

- macOS'ta `window.titlebar_double_click()` çağrılır.
- Linux/FreeBSD'de `window.zoom_window()` çağrılır.
- Windows'ta davranış uygulamadan değil, doğrudan platform caption ve hit-test katmanından beklenir.

Port hedefinde çift tıklamanın maximize yerine örneğin minimize gibi farklı bir davranış izlemesi istenirse, bu nokta dışarıdan parametreleştirilecek şekilde tasarlanmalıdır. Aksi halde davranış sabit kalır ve sonradan değiştirmek zorlaşır.

macOS tarafında `window.titlebar_double_click()` çağrısının her zaman "zoom" anlamına geldiği sanılmamalıdır. `gpui_macos` platform implementasyonu çağrı anında `NSGlobalDomain/AppleActionOnDoubleClick` değerini okur ve buna göre davranır. Değer `"None"` ise hiçbir şey yapmaz. `"Minimize"` için `miniaturize_` çağrılır. `"Maximize"` ve `"Fill"` için `zoom_` çağrılır. Bilinmeyen bir değer geldiğinde de varsayılan olarak yine `zoom_` çalışır (`gpui_macos/src/window.rs:1668-1712`). Buna karşılık Linux tarafındaki `window.zoom_window()` çağrısı bu macOS kullanıcı ayarını taklit etmez; her durumda doğrudan maximize/restore davranışını uygular.

### Renk

`title_bar_color` fonksiyonu çalıştığı platforma göre farklı davranır. Linux/FreeBSD tarafında aktif pencere için `title_bar_background` token'ı kullanılır. Pencere pasifse veya taşınıyorsa `title_bar_inactive_background` token'ına geçilir. Diğer platformlarda bu ayrım yapılmaz; doğrudan `title_bar_background` döner.

Bu davranışın amacı, başlık çubuğu ile alttaki sekme çubuğu arasındaki görsel ayrımı korumaktır. Port hedefinin tema sisteminde en az aşağıdaki token'ların tanımlı olması gerekir. Liste, `cx\.theme\(\)\.colors\(\)\.X` desenli awk taramasının tam çıktısıdır:

- `title_bar_background` — aktif Linux + tüm platformlar (`platform_title_bar.rs:66/71`, `system_window_tabs.rs:389`)
- `title_bar_inactive_background` — pasif/move durumundaki Linux (`platform_title_bar.rs:68`)
- `tab_bar_background` — native tab arka planı (`system_window_tabs.rs:390`)
- `border` — Linux tab kenarı ve plus butonu sınırı (`system_window_tabs.rs:181/353/479/525`)
- `ghost_element_background` — Linux `WindowControlStyle.background` default'u (`platform_linux.rs:120`)
- `ghost_element_hover` — Linux WindowControl + Windows non-close hover (`platform_linux.rs:121`, `platform_windows.rs:117`)
- `ghost_element_active` — Windows non-close active state (`platform_windows.rs:119`)
- `icon` — Linux WindowControl glyph rengi (`platform_linux.rs:122`)
- `icon_muted` — Linux WindowControl hover glyph rengi (`platform_linux.rs:123`)
- `text` — Windows caption glyph rengi default (`platform_windows.rs:118/120`)
- **`drop_target_background`** — **tab drag-over hedef vurgusu** (`system_window_tabs.rs:205`)
- **`drop_target_border`** — **tab drag-over kenar vurgusu** (`system_window_tabs.rs:206`)

Listenin sonundaki iki token (`drop_target_background` ve `drop_target_border`) özellikle önemlidir. Başka bir sekme sürüklenip mevcut bir sekmenin üzerine geldiğinde drop hedefi bu renklerle vurgulanır. Bu iki token tema'da tanımsız bırakılırsa drag-and-drop sırasındaki görsel geri bildirim kaybolur ve kullanıcı sekmeyi nereye bırakacağını anlayamaz.

### Yükseklik

Zed, başlık çubuğu yüksekliğini `platform_title_bar_height(window)` fonksiyonu üzerinden hesaplar:

- Windows'ta sabit `32px` değeri kullanılır.
- Diğer platformlarda hesap `1.75 * rem_size` formülüyle yapılır ve minimum `34px` değeriyle clamp'lenir.

Bu yükseklik değeri yalnızca başlık çubuğunda kullanılmaz. Windows pencere butonu yüksekliği ve diğer yardımcı başlık hizalamaları da **aynı kaynaktan** beslenmelidir. Farklı yerlere farklı sabitler yazılırsa hizalama bozulur ve bu hata sonradan piksel piksel kovalanır.

## 12. Buton yerleşimi ve ayar yönetimi

Linux/FreeBSD CSD tarafında pencere butonlarının sırası `WindowButtonLayout` tipiyle belirlenir. GPUI tarafındaki tip iki sabit slot dizisinden oluşur:

```rust
pub struct WindowButtonLayout {
    pub left: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE],
    pub right: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE],
}
```

`WindowButton` tipinin değerleri şu üçtür:

- `Minimize`
- `Maximize`
- `Close`

GPUI tarafındaki `WindowButton`, bu üç değerle birlikte dış API olarak kullanıma açıktır (`gpui/src/platform.rs:425-444`). Üzerinde `#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]` derive set'i vardır. `pub fn id(&self) -> &'static str` metodu ise varyantlara karşılık olarak `"minimize"`, `"maximize"` ve `"close"` stable element id'lerini döndürür. Bu id'ler Linux tarafındaki `WindowControl::new(...)` çağrılarında doğrudan kullanılır. Bu yüzden port hedefinde key/id uyumu korunmalıdır. Aksi halde Zed'le uyumlu olması beklenen element id'leri sapar ve test ya da araç bağlamalarında ince hatalar çıkar.

`WindowButtonLayout` tipi üç public öğeyle gelir (`gpui/src/platform.rs:457-486`):

| Öğe | İmza / değer | Davranış notu |
| :-- | :-- | :-- |
| `MAX_BUTTONS_PER_SIDE` | `pub const MAX_BUTTONS_PER_SIDE: usize = 3` | Her taraf en fazla üç slot tutar. |
| `WindowButtonLayout::linux_default` | `pub fn linux_default() -> Self` | Sol taraf boş, sağ taraf `Minimize, Maximize, Close`. Yalnız Linux/FreeBSD cfg'inde derlenir. |
| `WindowButtonLayout::parse` | `pub fn parse(layout_string: &str) -> Result<Self>` | GNOME tarzı `left:right` string'i okur; `:` yoksa sol boş, tüm string sağ taraf sayılır. |

`parse(...)` fonksiyonunda kolay atlanabilecek iki ince nokta vardır (`gpui/src/platform.rs:486-541`). İlki geçersiz isimlerin ele alınma biçimidir. String içinde tanınmayan adlar geçerse, en az bir geçerli buton bulunduğu sürece bu adlar **sessizce yok sayılır**. Yalnızca string'in tamamı geçersiz olduğunda hata döner. İkincisi tekrar davranışıdır. Aynı buton iki farklı tarafta veya aynı tarafın içinde tekrar edilirse, ilk görülen slot tutulur ve sonraki tekrarlar atlanır. Bu yüzden `"close,foo"` geçerli bir layout üretir; yalnız `"foo"` yazıldığında ise hata alınır.

Render tarafında bir tarafın "var olup olmadığı" yalnız o tarafın ilk slotuna bakılarak belirlenir. `render_left_window_controls(...)` için `button_layout.left[0].is_none()` ise tüm sol taraf `None` döner. Aynı kontrol `render_right_window_controls(...)` için `button_layout.right[0].is_none()` ile yapılır (`platform_title_bar.rs:132-135`, `163-166`). Bunun pratik sonucu şudur: manuel layout verilirken `[None, Some(Close), ...]` gibi bir dizi yazılırsa o taraf bütünüyle gizlenir, çünkü ilk slot boştur. İlk slot doluysa ve sonrasındaki slotlardan biri `None` ise, bu `None` slotlar `LinuxWindowControls` render'ındaki `filter_map(|b| *b)` adımıyla atlanır (`platform_linux.rs:31-34`); bütün taraf düşmez.

Zed'in ayar katmanı bu layout için üç farklı kullanım biçimi sunar:

| Ayar değeri | Sonuç |
| :-- | :-- |
| `platform_default` | Platform/desktop config takip edilir; `cx.button_layout()` fallback'i kullanılır. |
| `standard` | Zed Linux fallback'i: sağda minimize, maximize, close. |
| GNOME formatında string | Örneğin `"close:minimize,maximize"` veya `"close,minimize,maximize:"`. |

Uygulama katmanında bu ayar saklanacaksa izlenecek yol basittir. Kullanıcıdan gelen ayar değeri önce `WindowButtonLayout` tipine çevrilir. Ardından render sırasında `title_bar.set_button_layout(layout)` çağrısı yapılır. Bu iki adımdan biri atlanırsa ayar state'te durur ama render'a yansımaz.

Zed'in kendi `TitleBar` katmanı bu değişikliği `cx.observe_button_layout_changed(window, ...)` çağrısıyla dinler. Değişiklik geldiğinde hemen yeniden render tetikler. Port hedefinde desktop button layout değişiklikleri canlı izlenecekse aynı observer deseni kullanılır.

**`Platform::button_layout()` trait default'u `None` döner** (`gpui/src/platform.rs:162-164`). Bu default'u **yalnızca Linux/FreeBSD platform implementasyonu** override eder ve GTK/GNOME masaüstü ayarını (örneğin `gtk-decoration-layout`) okur. Bu nedenle `cx.button_layout()` çağrısı Windows ve macOS üzerinde her zaman `None` döner. Aynı şekilde `PlatformTitleBar::effective_button_layout(...)` de Linux + `Decorations::Client` kombinasyonu dışındaki tüm durumlarda `None` sonucunu verir (`platform_title_bar.rs:86-98`). Sonuç nettir: button layout ayar zinciri yalnızca Linux/FreeBSD CSD penceresinde anlamlıdır. Diğer platformlarda `set_button_layout(...)` çağrılsa bile görünür bir etki üretmez.

Linux tarafında bu değer, `gpui_linux` katmanının ortak state'inde başlangıçta `WindowButtonLayout::linux_default()` olarak tutulur (`gpui_linux/src/linux/platform.rs:143-150`). `Platform::button_layout()` çağrıldığında bu ortak state `Some(...)` sarmalanmış halde geri döner (`gpui_linux/src/linux/platform.rs:619-620`).

Canlı desktop değişikliği XDP üzerinden gelen `ButtonLayout` olayıyla yakalanır. Wayland ve X11 client'larının ikisi de gelen string'i `WindowButtonLayout::parse(...)` ile okur. Parse başarısız olursa yine `linux_default()` değerine düşer. Ardından her pencere için `window.set_button_layout()` çağrısı yapılır (`gpui_linux/src/linux/wayland/client.rs:636-645`, `gpui_linux/src/linux/x11/client.rs:493-500`). Bu çağrı `on_button_layout_changed` callback'ini tetikler. Zed `TitleBar::new(...)` içinde bu callback'i `cx.observe_button_layout_changed(window, ...)` üzerinden `cx.notify()` çağrısına bağlar (`title_bar/src/title_bar.rs:442`). Zincir şöyle ilerler: masaüstü ayarı değişir -> XDP olayı gelir -> string parse edilir -> pencere state'i güncellenir -> callback tetiklenir -> titlebar yeniden render olur.

## 13. Butonları uygulama katmanına bağlama

### Close davranışı

`PlatformTitleBar`, kendi render fonksiyonunun içinde close action'ı doğrudan şu şekilde sabitler:

```rust
let close_action = Box::new(workspace::CloseWindow);
```

Bu Zed'in kendi kullanımı için doğrudur. Ancak port hedefinde close butonunun farklı bir varlığı kapatması isteniyorsa bu sabitleme aşılmalıdır. Bunun üç yolu vardır:

1. `PlatformTitleBar` port edilirken bu tipe bir `close_action` alanı eklenir; her render'da bu alandan okunarak Zed'in sabit `workspace::CloseWindow` değeri yerine ürünün kendi action'ı geçirilir.
2. Zed'in `render_left_window_controls` ve `render_right_window_controls` serbest fonksiyonları doğrudan kullanılır ve bu fonksiyonlara argüman olarak ürünün kendi `Box<dyn Action>` değeri verilir.
3. Linux butonları doğrudan `LinuxWindowControls::new(...)` çağrısıyla üretilir ve close action'ı bu noktada verilir; üst sözleşme atlanır.

Örnek uygulama action eşleşmesi:

```rust
actions!(app, [CloseActiveWorkspace, NewWorkspaceWindow]);

let close_action: Box<dyn Action> = Box::new(CloseActiveWorkspace);
let controls = platform_title_bar::render_right_window_controls(
    cx.button_layout(),
    close_action,
    window,
);
```

Close action'ının somut olarak neyi kapatacağı uygulama modeline bağlı olarak belirlenir. Aşağıdaki tablo en yaygın senaryoların karşılığını gösterir:

| Uygulama varlığı | Close action anlamı |
| :-- | :-- |
| Tek pencereli app | Pencereyi kapat veya quit on last window politikasını işlet. |
| Workspace tabanlı app | Aktif workspace'i kapat, son workspace ise pencereyi kapat. |
| Doküman tabanlı app | Aktif dokümanı kapat, kirli state varsa kaydetme modalı aç. |
| Çok hesaplı/dashboard app | Aktif tenant veya view değil, pencere/shell lifecycle'ını kapat. |

### Minimize ve maximize

Linux'ta `WindowControl`, minimize ve maximize işlemlerini doğrudan `Window` üzerinden yapar:

- `window.minimize_window()` çağrısı pencereyi simge durumuna küçültür.
- `window.zoom_window()` çağrısı maximize/restore davranışını tetikler.

Bu butonlar uygulamanın action katmanına hiç uğramaz. Maximize ya da minimize işleminden önce telemetry yazmak, bir policy çalıştırmak veya layout state'ini persist etmek gerekiyorsa `WindowControl` port edilir ve bu işlemler ürünün kendi action'larına yönlendirilir. Aksi halde "minimize öncesi pencere boyutunu kaydet" gibi bir mantığa fırsat verilmez.

Windows tarafında durum farklıdır. Butonlar click handler ile pencere fonksiyonu çağırmaz. Bunun yerine `WindowControlArea::{Min, Max, Close}` ile bir hit-test alanı üretirler ve davranışı platform caption katmanına bırakırlar. Bu yüzden Windows pencere butonlarının davranışını uygulamanın action katmanına çekmek Linux'a göre daha fazla platform uyarlaması ister. Tıklamanın hiç ulaşmadığı bir alana action yerleştirmek mümkün değildir.

`window.window_controls()` capability yüzeyi de platforma göre değişir. **`WindowControls` struct'ı dört alan taşır** (`gpui/src/platform.rs:402-413`): `fullscreen`, `maximize`, `minimize` ve `window_menu`. Dikkat çekici nokta şudur: bu yapıda `close` alanı **yoktur**. Bunun nedeni Zed'in "close her zaman desteklenir" tasarım kararıdır. `LinuxWindowControls` filter'ı içindeki koşulsuz `WindowButton::Close => true` kolu da bu kararın doğrudan yansımasıdır (`platform_linux.rs:38`).

`platform_title_bar` crate'i bu capability yapısından gerçekten üç alan okur: `minimize` ve `maximize` Linux buton filtresinde kullanılır; `window_menu` ise sağ tık ile açılan pencere menüsünde kullanılır. `fullscreen` alanı bu crate içinde hiç okunmaz. Alan vardır, ama burada işlevsel değildir.

Trait default'u (`WindowControls::default`, `gpui/src/platform.rs:413-422`) tüm capability'lerin desteklendiğini varsayar. Wayland tarafında ise `xdg_toplevel::Event::WmCapabilities` olayı geldiğinde önce bütün bayraklar `false` yapılır. Ardından compositor'ın bildirdiği `Maximize`, `Minimize`, `Fullscreen`, `WindowMenu` capability'leri tek tek `true` olarak set edilir (`gpui_linux/src/linux/wayland/window.rs:788-817`). Bu değer bir sonraki configure adımında `state.window_controls` içine alınır ve appearance callback'i üzerinden yeniden render tetiklenir (`gpui_linux/src/linux/wayland/window.rs:601-612`).

Bu mekanizmanın sonucu üç maddede özetlenir:

- `LinuxWindowControls`, minimize ve maximize butonlarını bu capability değerine göre filtreler; close ise her durumda render edilebilir (`platform_linux.rs:30-39`).
- Linux CSD titlebar üzerindeki sağ tık window menu handler'ı, ancak `supported_controls.window_menu` `true` olduğunda eklenir (`platform_title_bar.rs:309-315`).
- Port hedefinde `WindowControls::default()` değerinin kalıcı gerçek olduğu sanılmamalıdır. Özellikle Wayland'da capability configure olayı geldikten sonra bu değerler değişebilir ve render buna uyum sağlamalıdır.


---
