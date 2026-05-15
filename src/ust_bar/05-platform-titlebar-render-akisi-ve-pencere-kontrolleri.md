# Platform titlebar render akışı ve pencere kontrolleri

Bu bölümden itibaren konu doğrudan başlık çubuğunun render davranışına
odaklanır: pencere nasıl sürükleniyor, Linux/Windows/macOS farkları
nerede ortaya çıkıyor, close/minimize/maximize butonları hangi
mekanizmalarla uygulamaya bağlanıyor. Önceki bölümlerde kurulan
katmanların somut olarak nasıl davrandığı burada görünür hâle gelir.

## 11. Davranış modeli

### Sürükleme

Ana titlebar yüzeyi `WindowControlArea::Drag` etiketiyle işaretlenir;
bu, alanın "sürüklenebilir başlık" olarak platforma tanıtılmasını
sağlar. Buna ek olarak, sol mouse down ve move olaylarının zincirinde
`window.start_window_move()` çağrısı tetiklenir. Bu iki mekanizmanın
birlikte çalışması, başlık çubuğunun sürüklenmesinin tüm platformlarda
tutarlı biçimde işlemesini sağlar; tek başına ne işaretleme ne de
manuel çağrı yeterli olur.

Başlık çubuğuna yerleştirilen interaktif elementlerin (butonlar, menü
tetikleyicileri, arama kutuları gibi) kendi mouse down/click
olaylarında propagation'ı durdurması gerekir. Aksi takdirde aynı
tıklama hem ilgili buton hem de altındaki "sürükle" yüzeyi tarafından
algılanır ve davranışlar çakışmaya başlar; bu da kullanıcının bir
menüye basmak isterken pencereyi yanlışlıkla sürüklemesi gibi tuhaf
sonuçlar doğurur.

`should_move` bayrağı, sürükleme akışının kalbinde durur ve
`platform_title_bar.rs:200-220` aralığında dört farklı noktada
düzenlenir:

- `on_mouse_down(Left, ...)` çağrısında `should_move` `true` yapılır;
  yani "olası bir drag başlayabilir" durumu işaretlenir.
- `on_mouse_move(...)` içinde, eğer `should_move` `true` ise **önce**
  bayrak `false`'a çekilir, **sonra** `window.start_window_move()`
  çağrısı yapılır. Bu sıralama önemlidir: tetikleyici tek-atışlıktır,
  bir kez ateşlendiğinde tekrar tetiklenmesi için yeni bir
  mouse_down zincirine gerek vardır.
- `on_mouse_up(Left, ...)` olayında `should_move` yine `false` yapılır.
  Bu, drag hiç başlamamış olsa bile state'in temiz kalmasını sağlar.
- `on_mouse_down_out(...)` olayında da `should_move` `false` yapılır.
  Bu sayede başlık çubuğunun dışına tıklanması durumunda bayrak
  geriden gelip ileride başka bir drag'i tetiklemez; state sızıntısı
  önlenmiş olur.

Linux pencere kontrol katmanı, **üç ayrı `stop_propagation()` noktası**
kullanır. Bu üç nokta tek başına bakıldığında kolayca gözden kaçabilir;
awk taramasıyla çıkarılmaları gerekir, çünkü dağınık satırları
`rg` toparlayamaz:

| Yer | Olay | Kaynak | Neyi engeller? |
| :-- | :-- | :-- | :-- |
| `LinuxWindowControls` h_flex container | `on_mouse_down(Left)` | `platform_linux.rs:50` | Buton grubuna basıldığında titlebar drag başlamasını. |
| `WindowControl` (her buton) | `on_mouse_move` | `platform_linux.rs:228` | Buton üzerinde mouse gezerken titlebar drag tetiklenmesini. |
| `WindowControl` `on_click` callback gövdesi | `cx.stop_propagation()` ilk satır | `platform_linux.rs:230` | Click event'inin yukarı kabarıp başka handler'lara ulaşmasını. Action dispatch'inden ÖNCE çalışır. |

Bu üç engel birden olmadığında ortaya çıkan tablo şudur:
(1) butonun üstüne yapılan mouse_down olayı altındaki sürükleme
yüzeyini tetikler ve pencere drag'e başlar;
(2) buton üzerinde mouse hareketi olduğunda mouse_move yine drag'i
ateşler;
(3) close action dispatch edilirken aynı click `PlatformTitleBar`
katmanına kadar kabarır ve `should_move = true` bayrağını set eder.
Bu yüzden port hedefinde bu üç noktanın her birine **eşdeğer engeller**
yerleştirilir; eksik kalan tek bir nokta bile davranışı bozar.

Windows tarafında aynı amaca hizmet eden çok daha basit bir ifade
vardır: `.occlude()` çağrısı (`platform_windows.rs:128`). Bu tek
satırlık ifade, caption butonu üzerindeki tüm mouse event'lerinin alt
katmanlara sızmasını engeller. Linux'taki üç ayrı `stop_propagation()`
çağrısının yaptığı işi, Windows tarafında bu tek çağrı toparlar.

### Fullscreen render ayrımı

Fullscreen, yalnızca görsel bir detay olarak görülmemelidir. Bu
durum, başlık çubuğuna hangi child'ların ekleneceğini de değiştirir
(`platform_title_bar.rs:243-320`). `window.is_fullscreen()` `true`
döndüğünde sol tarafta ne macOS trafik ışığı padding'i ne de Linux
sol pencere kontrolleri eklenir; bunların yerine yalnızca `.pl_2()`
fallback değeri kullanılır. Aynı render zincirinde sağ taraf bloğu
da `when(!window.is_fullscreen(), ...)` koruyucusunun arkasında
durur; başka bir deyişle, fullscreen'de sağ caption kontrolleri ve
Linux CSD'deki sağ tık sistem pencere menüsü kurulmaz.
`SystemWindowTabs` child'ı ise bu koşulun dışında kalır ve
fullscreen olsun ya da olmasın titlebar'ın altına eklenmeye devam
eder (`platform_title_bar.rs:322-325`).

Port hedefinde bu ayrım, "fullscreen olunca padding'i değiştir"
basitliğinde ele alınmamalıdır. Çünkü fullscreen aynı anda hem
sol/sağ pencere kontrol render'ını etkiler hem de Linux CSD'deki
`window.show_window_menu(...)` bağını devre dışı bırakır. Tek bir
kural yerine her bir etkilenen alan ayrı ayrı düşünülür.

### Çift tıklama

Çift tıklama davranışı, Zed kaynağında platforma göre farklı
biçimlerde işlenir:

- macOS'ta `window.titlebar_double_click()` çağrılır.
- Linux/FreeBSD'de `window.zoom_window()` çağrılır.
- Windows'ta davranış uygulamadan değil, doğrudan platform caption ve
  hit-test katmanından beklenir.

Port hedefinde çift tıklamanın maximize yerine örneğin minimize gibi
farklı bir davranış izlemesi istenirse, bu nokta dışarıdan
parametreleştirilecek şekilde tasarlanır; aksi halde sabit davranış
değiştirilemez kalır.

macOS tarafında `window.titlebar_double_click()` çağrısının her zaman
"zoom" anlamına geldiği sanılmamalıdır. `gpui_macos` platform
implementasyonu, çağrı anında
`NSGlobalDomain/AppleActionOnDoubleClick` değerini okur ve buna göre
davranır: değer `"None"` ise hiçbir şey yapmaz, `"Minimize"` için
`miniaturize_` çağrılır, `"Maximize"` ve `"Fill"` için `zoom_`
çağrılır, bilinmeyen bir değer geldiğinde de varsayılan olarak yine
`zoom_` çağrılır (`gpui_macos/src/window.rs:1668-1712`). Buna karşılık
Linux tarafındaki `window.zoom_window()` çağrısı bu macOS kullanıcı
ayarını taklit etmez; her durumda doğrudan maximize/restore
davranışını uygular.

### Renk

`title_bar_color` fonksiyonu, çalıştığı platforma göre farklı
davranır. Linux/FreeBSD tarafında, aktif pencere için
`title_bar_background` token'ı kullanılırken; pencere pasif durumda
veya taşınmakta olduğunda `title_bar_inactive_background` token'ına
geçilir. Diğer platformlarda bu ayrım yapılmaz ve doğrudan
`title_bar_background` döner.

Bu davranışın amacı, başlık çubuğu ile alttaki sekme çubuğu
arasındaki görsel ayrımın korunmasıdır. Port hedefinin tema sisteminde
en az aşağıdaki token'ların tanımlı olması gerekir; aşağıdaki liste,
`cx\.theme\(\)\.colors\(\)\.X` desenli awk taramasının tam
çıktısıdır:

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

Listenin sonundaki iki token (`drop_target_background` ve
`drop_target_border`) özel olarak şu işe yarar: başka bir sekme
sürüklenip mevcut bir sekmenin üzerine gelindiğinde drop hedefi
görsel olarak vurgulanır. Eğer bu iki token tema'da tanımsız
bırakılırsa, drag-and-drop sırasındaki görsel geri besleme görünmez
hâle gelir ve kullanıcı nereye bırakacağını anlayamaz.

### Yükseklik

Zed, başlık çubuğu yüksekliğini `platform_title_bar_height(window)`
fonksiyonu üzerinden hesaplar:

- Windows'ta sabit `32px` değeri kullanılır.
- Diğer platformlarda hesap `1.75 * rem_size` formülüyle yapılır ve
  minimum `34px` değeriyle clamp'lenir.

Bu yükseklik değerinin sadece başlık çubuğunda değil, Windows pencere
buton yüksekliğinde ve diğer yardımcı başlıkların hizalamasında da
**aynı kaynaktan** alınması gerekir. Farklı yerlerde farklı sabitler
yazılırsa hizalama bozulur ve bu hata sonradan tek tek pikselle
kovalanır.

## 12. Buton yerleşimi ve ayar yönetimi

Linux/FreeBSD CSD tarafında pencere butonlarının sırası
`WindowButtonLayout` tipi üzerinden belirlenir. GPUI tarafındaki tip,
iki sabit slot dizisinden oluşur:

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

GPUI tarafındaki `WindowButton`, bu üç değerle birlikte dış API olarak
da kullanıma açıktır (`gpui/src/platform.rs:425-444`). Üzerinde
`#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]` derive set'i
vardır ve `pub fn id(&self) -> &'static str` metodu, varyantlara
karşılık olarak sırasıyla `"minimize"`, `"maximize"` ve `"close"`
stable element id'lerini döndürür. Bu id'ler Linux tarafındaki
`WindowControl::new(...)` çağrılarında doğrudan kullanılır; bu yüzden
port hedefinde de key/id uyumunun korunması gerekir. Aksi halde
Zed'le birebir uyumlu olması beklenen element id'leri sapar ve test
ile araç bağlamalarında ince hatalar ortaya çıkar.

`WindowButtonLayout` tipi üç public öğeyle gelir
(`gpui/src/platform.rs:457-486`):

| Öğe | İmza / değer | Davranış notu |
| :-- | :-- | :-- |
| `MAX_BUTTONS_PER_SIDE` | `pub const MAX_BUTTONS_PER_SIDE: usize = 3` | Her taraf en fazla üç slot tutar. |
| `WindowButtonLayout::linux_default` | `pub fn linux_default() -> Self` | Sol taraf boş, sağ taraf `Minimize, Maximize, Close`. Yalnız Linux/FreeBSD cfg'inde derlenir. |
| `WindowButtonLayout::parse` | `pub fn parse(layout_string: &str) -> Result<Self>` | GNOME tarzı `left:right` string'i okur; `:` yoksa sol boş, tüm string sağ taraf sayılır. |

`parse(...)` fonksiyonunun davranışının kolayca atlanabilecek iki
ince noktası vardır (`gpui/src/platform.rs:486-541`). İlki, geçersiz
isimlerin ele alınma biçimidir: string içinde tanınmayan adlar geçerse,
en az bir geçerli buton bulunduğu sürece bu adlar **sessizce yok
sayılır**. Sadece string'in tamamı geçersiz olduğunda hata döner.
İkincisi tekrar davranışıdır: aynı buton iki farklı tarafta veya aynı
tarafın içinde tekrar edilirse, ilk görülen slot tutulur ve sonraki
tekrarlar atlanır. Bu davranışın doğal sonucu olarak `"close,foo"`
ifadesi geçerli bir layout üretir, ancak yalnız `"foo"` yazıldığında
hata alınır.

Render tarafında bir tarafın "var olup olmadığı", yalnız o tarafın
ilk slotuna bakılarak belirlenir. `render_left_window_controls(...)`
için `button_layout.left[0].is_none()` ise tüm sol taraf `None` olarak
döner; aynı kontrol `render_right_window_controls(...)` için
`button_layout.right[0].is_none()` ile yapılır
(`platform_title_bar.rs:132-135`, `163-166`). Bunun pratik anlamı
şudur: manuel layout verilirken `[None, Some(Close), ...]` gibi bir
dizi yazılırsa o taraf bütünüyle gizlenir, çünkü ilk slot boştur.
İlk slot doluysa ve sonrasındaki slotlardan biri `None` ise, bu
`None` slotlar `LinuxWindowControls` render'ı içindeki
`filter_map(|b| *b)` adımıyla sadece atlanır
(`platform_linux.rs:31-34`); bütün tarafı düşürmez.

Zed'in ayar katmanı bu layout için üç farklı kullanım biçimi sunar:

| Ayar değeri | Sonuç |
| :-- | :-- |
| `platform_default` | Platform/desktop config takip edilir; `cx.button_layout()` fallback'i kullanılır. |
| `standard` | Zed Linux fallback'i: sağda minimize, maximize, close. |
| GNOME formatında string | Örneğin `"close:minimize,maximize"` veya `"close,minimize,maximize:"`. |

Uygulama katmanında bu ayarın saklanması istendiğinde izlenecek
yol şudur: kullanıcı tarafından girilen ayar değeri önce
`WindowButtonLayout` tipine çevrilir; ardından render sırasında
`title_bar.set_button_layout(layout)` çağrısı yapılır. İki adımın da
atlanmaması gerekir; aksi halde ayar elde tutulur ama render'a yansımaz.

Zed'in kendi `TitleBar` katmanı bu değişikliği
`cx.observe_button_layout_changed(window, ...)` çağrısı ile dinler ve
değişiklik gelir gelmez yeniden render tetikler. Port hedefinde
desktop button layout değişikliklerinin canlı izlenmesi isteniyorsa
aynı observer deseni kullanılır.

**`Platform::button_layout()` trait default'u `None` döner**
(`gpui/src/platform.rs:162-164`); bu default'u **yalnızca Linux/FreeBSD
platform implementasyonu** override eder ve GTK/GNOME masaüstü
ayarını (örneğin `gtk-decoration-layout`) okur. Yani `cx.button_layout()`
çağrısı Windows ve macOS üzerinde her zaman `None` döner. Aynı
biçimde `PlatformTitleBar::effective_button_layout(...)` de Linux +
`Decorations::Client` kombinasyonu dışındaki tüm durumlarda `None`
sonucunu verir (`platform_title_bar.rs:86-98`). Bu davranışın sonucu
açıktır: button layout ayar zinciri yalnızca Linux/FreeBSD CSD
penceresinde anlamlıdır; diğer platformlarda `set_button_layout(...)`
çağrısı yapılsa bile bir etki üretmez.

Linux tarafında bu değer, `gpui_linux` katmanının ortak state'inde
başlangıçta `WindowButtonLayout::linux_default()` olarak tutulur
(`gpui_linux/src/linux/platform.rs:143-150`).
`Platform::button_layout()` çağrıldığında, bu ortak state `Some(...)`
sarmalanmış hâlde geri döner (`gpui_linux/src/linux/platform.rs:619-620`).
Canlı desktop değişikliği ise XDP üzerinden gelen `ButtonLayout`
olayı ile yakalanır: Wayland ve X11 client'larının her ikisi de gelen
string'i `WindowButtonLayout::parse(...)` ile okur, parse başarısız
olursa yine `linux_default()` değerine düşer, ardından her pencere
için `window.set_button_layout()` çağrısını yapar
(`gpui_linux/src/linux/wayland/client.rs:636-645`,
`gpui_linux/src/linux/x11/client.rs:493-500`). Bu çağrı da
`on_button_layout_changed` callback'ini tetikler; Zed
`TitleBar::new(...)` içinde bu callback,
`cx.observe_button_layout_changed(window, ...)` aracılığıyla
`cx.notify()` çağrısına bağlanır (`title_bar/src/title_bar.rs:441`).
Yani zincir şu şekilde işler: masaüstü ayarı değişir → XDP olayı gelir
→ string parse edilir → pencere state'i güncellenir → callback
tetiklenir → titlebar yeniden render olur.

## 13. Butonları uygulama katmanına bağlama

### Close davranışı

`PlatformTitleBar`, kendi render fonksiyonunun içinde close action'ı
doğrudan şu şekilde sabitler:

```rust
let close_action = Box::new(workspace::CloseWindow);
```

Bu, Zed'in kendi kullanımı için doğrudur; ancak port hedefinde close
butonunun farklı bir varlığı kapatması isteniyorsa bu sabitlemenin
aşılması gerekir. Bunun üç yolu vardır:

1. `PlatformTitleBar` port edilirken bu tipe bir `close_action` alanı
   eklenir; her render'da bu alandan okunarak Zed'in sabit
   `workspace::CloseWindow` değeri yerine ürünün kendi action'ı geçirilir.
2. Zed'in `render_left_window_controls` ve
   `render_right_window_controls` serbest fonksiyonları doğrudan
   kullanılır ve bu fonksiyonlara argüman olarak ürünün kendi
   `Box<dyn Action>` değeri verilir.
3. Linux butonları doğrudan `LinuxWindowControls::new(...)` çağrısıyla
   üretilir ve close action'ı bu noktada verilir; üst sözleşme atlanır.

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

Close action'ının somut olarak neyi kapatacağı, uygulama modelinin
yapısına göre belirlenir. Aşağıdaki tablo en yaygın senaryoların
karşılıklarını gösterir:

| Uygulama varlığı | Close action anlamı |
| :-- | :-- |
| Tek pencereli app | Pencereyi kapat veya quit on last window politikasını işlet. |
| Workspace tabanlı app | Aktif workspace'i kapat, son workspace ise pencereyi kapat. |
| Doküman tabanlı app | Aktif dokümanı kapat, kirli state varsa kaydetme modalı aç. |
| Çok hesaplı/dashboard app | Aktif tenant veya view değil, pencere/shell lifecycle'ını kapat. |

### Minimize ve maximize

Linux'ta `WindowControl`, minimize ve maximize işlemlerini doğrudan
`Window` üzerinden gerçekleştirir:

- `window.minimize_window()` çağrısı pencereyi simge durumuna küçültür.
- `window.zoom_window()` çağrısı maximize/restore davranışını
  tetikler.

Bu butonlar uygulamanın action katmanına hiç uğramaz. Maximize ya da
minimize işleminden önce telemetry yazılması, bir policy
çalıştırılması veya layout state'inin persist edilmesi gerekiyorsa
`WindowControl` port edilir ve bu işlemler ürünün kendi action'larına
yönlendirilir. Aksi takdirde "minimize öncesi pencere boyutunu kaydet"
gibi bir mantığa hiç fırsat verilmez.

Windows tarafında durum farklıdır: butonlar click handler ile pencere
fonksiyonu çağırmaz. Onun yerine `WindowControlArea::{Min, Max, Close}`
ile bir hit-test alanı üretirler; davranışı uygulamak doğrudan platform
caption katmanına bırakılır. Bu yüzden Windows pencere butonlarının
davranışını uygulamanın action katmanına çekmek, Linux'a göre daha
fazla platform uyarlaması gerektirir; çünkü tıklamanın hiç
ulaşmadığı bir alana action yerleştirmek mümkün değildir.

`window.window_controls()` capability yüzeyi de platforma göre
farklılık gösterir. **`WindowControls` struct'ı dört alan taşır**
(`gpui/src/platform.rs:402-413`): `fullscreen`, `maximize`, `minimize`
ve `window_menu`. Dikkat çekici olarak `close` alanı bu yapıda
**yoktur**. Bunun nedeni Zed'in "close her zaman desteklenir" tasarım
kararıdır; `LinuxWindowControls` filter'ı içindeki koşulsuz
`WindowButton::Close => true` kolu da bu kararın doğrudan
yansımasıdır (`platform_linux.rs:38`).

`platform_title_bar` crate'inin bu capability yapısından gerçekten
okuduğu alanlar şunlardır: `minimize` ve `maximize` (Linux buton
filtresinde kullanılır), bir de `window_menu` (sağ tık ile açılan
pencere menüsünde kullanılır). `fullscreen` alanı bu crate içinde
hiç okunmaz; var ama burada işlevsel değildir.

Trait default'u (`WindowControls::default`,
`gpui/src/platform.rs:413-422`) tüm capability'lerin desteklendiği
varsayımıyla başlar. Buna karşın Wayland tarafında
`xdg_toplevel::Event::WmCapabilities` olayı geldiğinde önce bütün
bayraklar `false` yapılır; ardından compositor'ın bildirdiği
`Maximize`, `Minimize`, `Fullscreen`, `WindowMenu` capability'leri
tek tek `true` olarak set edilir
(`gpui_linux/src/linux/wayland/window.rs:788-817`). Bu değer bir
sonraki configure adımında `state.window_controls` içine alınır ve
appearance callback'i üzerinden yeniden render tetiklenir
(`gpui_linux/src/linux/wayland/window.rs:601-612`).

Bu mekanizmanın sonuçları üç başlıkta özetlenir:

- `LinuxWindowControls`, minimize ve maximize butonlarını bu
  capability değerine göre filtreler; close ise her durumda render
  edilebilir (`platform_linux.rs:30-39`).
- Linux CSD titlebar üzerindeki sağ tık window menu handler'ı, ancak
  `supported_controls.window_menu` `true` olduğunda eklenir
  (`platform_title_bar.rs:309-315`).
- Port hedefinde `WindowControls::default()` değerinin kalıcı gerçek
  olduğu sanılmamalıdır; özellikle Wayland'da capability configure
  olayı geldikten sonra bu değerler değişebilir ve render buna uyum
  sağlamalıdır.


---

