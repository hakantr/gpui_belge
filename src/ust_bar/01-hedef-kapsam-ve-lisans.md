# Hedef, kapsam ve lisans

Üst bar konusuna girmeden önce üç şey netleşmelidir: tam olarak ne port
ediliyor, hangi sorumluluk hangi katmana ait ve lisans sınırı nereden
geçiyor. Bu bölüm aceleci olmadan bu üç çerçeveyi kurar; sonraki
bölümlerin tamamı bu üç çerçevenin üstüne bina edilir.

## 1. Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama state

Yapı aşağıdan yukarıya okunur. En alta **platform kabuğu** oturur ve bu
katmandan **davranış paritesi** beklenir; yani Zed'in pencereyle nasıl
konuştuğu, hangi platformda hangi butonu nereye koyduğu birebir
tekrarlanır. Üstteki iki katman ise tasarım özgürlüğüyle yazılır: ne
görüneceği, hangi rengin/menünün geleceği, hangi action'ın dispatch
edileceği tamamen ürüne aittir.

```
┌─────────────────────────────────────────────────────────────────┐
│  Uygulama state (senin kodun)                                   │
│  - TitleBarController trait                                     │
│  - close_action, new_window_action, button_layout, sidebar      │
│  - AppState / WorkspaceState / DocumentState                    │
├─────────────────────────────────────────────────────────────────┤
│  Ürün başlığı (kendi tasarımın, AppTitleBar)                    │
│  - Uygulama menüsü, proje/doküman adı, kullanıcı menüsü         │
│  - Tema renkleri, branş göstergesi, status chip'leri            │
│  - PlatformTitleBar entity'sine child olarak verilir            │
├─────────────────────────────────────────────────────────────────┤
│  Platform kabuğu (port edilmiş, kvs_titlebar)                   │
│  - PlatformTitleBar: drag alanı, arka plan, köşe yuvarlama      │
│  - Linux/Windows caption buton render'ları                      │
│  - macOS trafik ışığı padding'i ve dbl-click                    │
│  - Native pencere sekmeleri (opsiyonel)                         │
│  - GPUI: WindowOptions, WindowControlArea, WindowButtonLayout   │
└─────────────────────────────────────────────────────────────────┘
```

**Platform kabuğu (en alt katman) — `mirror`:** Zed'in
`platform_title_bar` crate'inin **davranışı** yeniden yazılır. Hit-test
alanları, drag akışı, hangi platformda hangi pencere butonunun render
edileceği gibi konuların tamamı Zed sözleşmesine paralel ilerler.
Burada yaratıcılığa yer yoktur; tek hedef davranış paritesidir. Bu
katman Bölüm V'te detaylıca ele alınır. **Lisans nedeniyle kaynak kodu
kopyalanmaz**; yalnızca API'lerin gözlemlenebilir davranışı kendi
kelimelerle yeniden kurulur.

**Ürün başlığı (orta katman) — `senin tasarımın`:** Uygulamanın
kullanıcıya gözüken başlık içeriği bu katmanda yaşar. Menü, proje adı,
durum çipleri, kullanıcı avatarı gibi parçaların tamamı ürünün kendi
tasarım dilinde üretilir. Bu içerik, platform kabuğuna **child** olarak
verilir ve her render geçişinde yeniden iletilir; bu tüketim modeli
Konu 16'da `set_children` üzerinden anlatılır. Mantık olarak tema
rehberindeki "Faz 5 — UI tüketim" bölümüyle aynı zihniyettedir: tema
okunur, duruma göre render edilir.

**Uygulama state (en üst katman) — `karar otoritesi`:** Platform
kabuğunun ihtiyaç duyduğu **politika** kararları bu katmandan iner.
"Close butonu tam olarak neyi kapatıyor?", "Yeni pencere hangi action
ile açılıyor?", "Linux butonları sağda mı solda mı duruyor?", "Sidebar
açık mı kapalı mı?" gibi soruların cevabı uygulama state'inde tutulur.
Bu cevaplar, platform kabuğuna doğrudan veri olarak değil, bir **trait
sözleşmesi** üzerinden iletilir (`TitleBarController` — Konu 10 sonu).

**Bağımlılık yönü:**

```
Uygulama state  ←─reads─  Ürün başlığı  ←─child of─  Platform kabuğu
                                                      │
                                                      └─reads─  TitleBarController
                                                                (uygulama state'inden trait obj)
```

Platform kabuğu, ürünün `AppState`'ini doğrudan tanımaz; yalnızca
`TitleBarController` trait'ini bilir. Bu tek yönlü ilişki kuralı,
platform kabuğunun **bağımsız test edilebilir** kalmasını sağlar:
testlerde gerçek uygulama state'i yerine, sadece trait'i implement
eden basit bir mock yeterli olur.

**Lisans katmanlama:**

| Katman | Lisans tarafı |
|--------|---------------|
| Platform kabuğu | Davranış öğrenilir, kod kendi sözcüklerinizle yazılır (GPL-3 kod gövdesi kopyalama yasak) |
| Ürün başlığı | Tamamen senin; Zed'in `title_bar` koduyla hiçbir ilgisi yok |
| Uygulama state | Tamamen senin; trait imzası `TitleBarController` çıkış API'sidir |

### Zed ile bu rehberin terim eşlemesi

| Zed | Bu rehber |
|-----|-----------|
| `platform_title_bar` crate | `kvs_titlebar` crate (port edilmiş) |
| `title_bar` crate | `kvs_app_titlebar` veya uygulamanın kendi crate'i |
| `workspace::Workspace` | Uygulamanın kendi shell/window state'i |
| `WorkspaceSettings`, `ItemSettings` | Uygulamanın config sistemi |
| `MultiWorkspace`, `SidebarRenderState` | `TitleBarController::sidebar_state` |
| `zed_actions::OpenRecent` vb. | Uygulamanın kendi action'ları |

Sync turlarında `platform_title_bar_aktarimi.md` günlüğüyle birlikte bu
eşleme tablosu bir **referans değer** olarak kullanılır. Zed
sözleşmesine yeni bir kavram girdiğinde, bu kavramın uygulama tarafında
hangi tip ile karşılanacağı önce bu tablo üzerinden belirlenir; ancak
ondan sonra kod yazımına geçilir.

---

## 2. Temel ilke: platform katmanı bilir, ürün katmanı karar verir

Bütün katmanlamanın özeti tek cümleye sığar: **platform kabuğu
pencerenin mekaniğini bilir; ürün katmanı ise neyin kapanacağına,
hangi menünün açılacağına, hangi workspace'in taşınacağına karar
verir.** Bu kural ezberlenirse rehberin geri kalanı çok daha kolay
oturur.

### Üç şeyi ayırt et

| Soru | Sahibi |
|------|--------|
| Mouse buradan basıldı, pencere sürüklenmeli mi? | **Platform** (`start_window_move`) |
| Close butonuna basıldı, ne kapatılmalı? | **Ürün** (`AppState::close_action`) |
| Pencere zoom edilmeli mi yoksa minimize mi? | **Platform** (Linux: `zoom_window`; macOS: sistem) |
| Workspace kirli, save modal aç mı? | **Ürün** (`AppState::on_close_intent`) |
| Linux pencere butonu hangi tarafta? | **Platform** + **Ürün** (button_layout ayardan) |
| Native tab açıldığında ne yapılır? | **Platform** (`SystemWindowTabController`) + **Ürün** (yeni pencere ne içeriyor) |
| Hit-test: bu piksel caption mı, drag mı, content mi? | **Platform** (`WindowControlArea`) |
| Pencerenin teması (renk) ne? | **Ürün** (`cx.theme().title_bar_background`) |

### Gerekçe

1. **Platform davranışı evrenseldir.** Bir Linux kullanıcısı, kendi
   pencere yöneticisinin button layout ayarının çalışmasını bekler;
   kendi compositor'unun resize edge davranışına alışmıştır. Ürün bu
   beklentilere karşı çıkamaz — onları olduğu gibi tüketmek
   durumundadır. Aksi halde "neden bu uygulama benim sistemim gibi
   davranmıyor?" sorusu doğar.
2. **Ürün anlamı uygulamaya özgüdür.** "Close" sözcüğünün ne anlama
   geldiği uygulamaya göre değişir: Zed'de bir workspace kapanır, bir
   metin editörde aktif doküman kapanır, bir launcher uygulamasında
   pencere sadece gizlenir. Platform bu farkı bilmez ve bilmek de
   istemez; bu sorumluluk doğal olarak ürün katmanına aittir.
3. **Test izolasyonu için zorunludur.** Platform kabuğu test edilirken
   gerçek bir `AppState` ayağa kaldırılmak zorunda kalınmaz; basit bir
   mock `TitleBarController` ile aynı testler yürütülebilir. Bu, hem
   testlerin hızını hem de güvenilirliğini yukarı çeker.

### Kontrol listesi: bir davranış hangi katmana yerleştirilmeli?

Yeni bir davranış eklenirken üç soru ile yer kararı verilir:

1. **Bu davranış pencere yöneticisinin veya işletim sisteminin
   sözleşmesini mi takip ediyor?** Cevap evet ise yer **platform
   katmanıdır**.
2. **Bu davranış uygulamanın iş kuralına mı bağlı?** Cevap evet ise yer
   **ürün katmanı** veya `AppState`'tir.
3. **Bu davranış hangi katmana yerleştirildiğinde aynı kabuk başka
   uygulamalar tarafından da yeniden kullanılabilir?** O katman doğru
   cevaptır; çünkü genel olan platforma, özel olan ürüne aittir.

> **Örnek hatalı yerleşim:** "Close butonuna tıklandığında SaveModal
> aç" kuralı **ürün katmanında** olmalıdır. Platform kabuğu yalnızca
> "close intent" dispatch eder; bir modal'ın açılıp açılmayacağı kararı
> `AppState`'e aittir. Bu karar platforma sızdırılırsa kabuk artık tek
> bir uygulamaya bağlı hale gelir ve başka projede yeniden
> kullanılamaz.

### "Tema rehberindeki Temel ilke ile farkı"

Tema rehberinin Konu 2'si **veri sözleşmesinde dışlama yok** kuralını
anlatıyordu: Zed'in tema alanlarının tamamı mirror edilmeli. Bu
rehberin Konu 2'si ise **kapsam farkından** bahsediyor: platform vs
ürün vs state. İki kural aslında aynı zihniyetin iki yüzüdür:
**sözleşme tarafı geliştiriciye bırakılır, uygulama tarafı ise
geliştiricinin kendi ürününe bırakılır**.

### Tuzaklar

1. **Close action'ını platforma sabitlemek.** `PlatformTitleBar`
   içine doğrudan `close_action: Box::new(workspace::CloseWindow)`
   yazılırsa platform kabuğu Zed'in kendi action tipine bağlanmış olur
   ve başka bir uygulamaya bu hâliyle taşınamaz. Bu yüzden close
   action'ı **her zaman dışarıdan**, controller veya parametre yoluyla
   geçilir.
2. **Çift tıklama davranışını ürüne sızdırmak.** macOS tarafında çift
   tıklama `window.titlebar_double_click()` ile sisteme devredilir; bu
   tamamen platform sözleşmesinin parçasıdır. Ürün burada araya girip
   `cx.dispatch_action(ZoomWorkspace)` çağırırsa platforma özel
   davranış bozulur ve macOS kullanıcısının sistem ayarları
   yok sayılmış olur.
3. **Sidebar açıkken pencere kontrollerini gizleme kararını yanlış
   yere koymak.** Bu konu Konu 15'te ele alınır; sidebar bilgisi
   `TitleBarController` üzerinden gelir. Platform kabuğu, doğrudan
   workspace state'ini sorgulamaz; çünkü "sidebar" kavramı platforma
   değil ürüne aittir.
4. **Native tab kararını ürüne kapatmak.** `tabbing_identifier`
   alanının verilip verilmemesi tek başına ürüne bırakılmaz;
   `TitleBarController::use_system_window_tabs` üzerinden okunur.
   Platform kabuğu, native tab desteğinin açık olup olmadığına kendi
   başına karar vermez.

---

## 3. Lisans-temiz çalışma protokolü

Zed'in `platform_title_bar` ve `title_bar` crate'leri
**GPL-3.0-or-later** lisansı altındadır. Bu, kod gövdesinin
kopyalanamayacağı anlamına gelir; ancak API imzaları, JSON sözleşmeleri
ve gözlemlenebilir davranış kuralları telif kapsamı dışında olduğundan
mirror edilebilir. Yani satır satır kopyalama yasaktır, fakat "Zed
şuna basınca şu olur" gözlemi yasak değildir; bu gözlem ürünün kendi
kodunda kendi sözcükleriyle yeniden inşa edilebilir.

> **Tema rehberi Konu 3 ile fark:** Tema sözleşmesi alan adlarını
> mirror eder — yani veri şekli aynı tutulur. Burada ise **davranış**
> mirror edilir: "mouse'a basıldığında pencere sürüklenmeye başlar"
> ya da "close butonu ana caption'ın sağ ucunda durur" gibi
> gözlemlenebilir davranışlar telif kapsamında olmadığı için
> bunlar yeniden inşa edilebilir.

### Yapılabilir / Yapılamaz

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| API imzalarını gözlemleyip yeniden yazmak (örn. `pub fn set_button_layout(...)`) | `crates/platform_title_bar/src/*.rs` kod gövdesini kopyalamak |
| Davranışı tarif edip kendi kelimelerinle implement etmek | Doc comment'i kelime kelime taşımak |
| `WindowControlArea` enum varyantlarını mirror etmek (gpui'den, Apache-2.0) | Zed'in `LinuxWindowControls` impl'ini taşımak |
| `WindowButtonLayout` enum varyantlarını mirror etmek (gpui'den) | Zed'in render fonksiyonlarını birebir Rust → Rust kopyalamak |
| Platform-spesifik bilinen davranışları (hit-test, dbl-click) yeniden yazmak | Zed'in caption button hover renklerinin tam hex değerlerini kopyalamak |
| Sözleşme parite tabloları çıkarmak (sync turunda) | Zed'in mevcut SVG icon dosyalarını binary olarak gömmek |

### Güvenli dependency'ler (hepsi Apache-2.0, Zed workspace'inden alınabilir)

- **`gpui`** — Pencere ve render katmanının çekirdeği. `WindowOptions`,
  `TitlebarOptions`, `WindowControlArea`, `WindowButtonLayout`,
  `WindowDecorations` gibi tipler ve `Window` üzerindeki
  `start_window_move`, `minimize_window`, `zoom_window`,
  `show_window_menu`, `titlebar_double_click`, `set_client_inset`,
  `tab_bar_visible`, `set_tabbing_identifier` gibi metotlar bu crate'ten
  alınır.
- **`refineable`** — Style cascade desenleri için kullanılır; tema
  rehberindeki kullanım gibi. Üst barda çoğu durumda zorunlu değildir,
  ama daha karmaşık stil zincirlerinde işe yarar.
- **`collections`** — Zed'in `HashMap` ve `IndexMap` wrapper'larını içerir;
  Zed ile aynı koleksiyon davranışına ihtiyaç duyulduğunda eklenebilir.

**GPL-3 crate'ler (referans için okunur, asla dependency olarak eklenmez):**

| Crate | Lisans | Bu rehberin yaklaşımı |
|-------|--------|----------------------|
| `platform_title_bar` | GPL-3.0-or-later | **Mirror** — kendi `kvs_titlebar`'a port |
| `title_bar` | GPL-3.0-or-later | **Mirror** — kendi `kvs_app_titlebar`'a port |
| `workspace` | GPL-3.0-or-later | **Sadece referans** — `client_side_decorations` benzerini elle yaz |
| `theme` | GPL-3.0-or-later | Tema rehberindeki gibi mirror (`kvs_tema`) |
| `theme_settings`, `theme_selector` | GPL-3.0-or-later | Sadece referans |
| `zed_actions` | GPL-3.0-or-later | Action karşılıkları kendi `app::actions!` makronla |

### Üç port yaklaşımı ve lisans sonucu

| Yaklaşım | Lisans sonucu | Kullanım koşulu |
|----------|---------------|-----------------|
| **1. Doğrudan `platform_title_bar` dependency** | Senin uygulaman **GPL-3** olur | Sadece kendin GPL altında dağıtacaksan |
| **2. Crate'i vendor'la (kaynak kodu kopyala)** | Vendor'lanan kod **hâlâ GPL-3**; senin uygulaman da GPL-3 olur | Yine GPL hedefin varsa |
| **3. Davranış mirror'ı (kendi koddan yeniden yaz)** | Senin kodun **kendi lisansın** olur | **Lisans-temiz hedef için tek doğru yol** |

Bu rehber **üçüncü yolu** anlatır. Birinci veya ikinci yolu seçen
geliştiriciler için rehber yine fayda sağlar; Bölüm II–V referans
amaçlı okunabilir. Bu durumda "port" kelimesi geçen her yer "kullan"
olarak okunabilir, çünkü onlar için aynı kod zaten hazırdır.

### Doc comment yazımı

Zed kaynak dosyasındaki bir fonksiyon imzası mirror ediliyorsa, doc
comment'in **kendi sözcüklerle** yeniden yazılması gerekir; orijinal
cümle aynen taşınamaz. Örnek olarak:

```rust
// Zed'de (mirror EDİLMEZ — birebir kopyalama):
/// Renders the left window controls for Linux client-side decorations.

// Portta (mirror EDİLİR — yeniden yazılmış):
/// Linux client-side decoration durumunda sol kenar pencere butonlarını
/// üretir; layout boş ise `None` döner.
pub fn render_left_window_controls(...) -> Option<impl IntoElement> { ... }
```

İki yorum da aynı fonksiyonu anlatır; ama ikincisi orijinal cümlenin
ne kelimesini ne de cümle yapısını kullanır.

### Publishing uyarısı

`gpui` ve `refineable` crate'leri Zed workspace'inde `publish = false`
olarak işaretlidir. Bu, crates.io'ya yayımlanacak bir kütüphanenin
içinde git veya path dependency olarak kullanılamayacakları anlamına
gelir. Bu engelin üç olası çözümü vardır (tema rehberi Konu 3 ile
örtüşür):

1. **Vendor yolu:** Kaynak kod kendi monorepo'ya kopyalanır; lisans
   ve atribüsyon bilgileri korunur.
2. **Fork yayınlama:** `gpui` kendi ad altında crates.io'ya yayımlanır.
3. **Yalnızca dahili kullanım:** Uygulama binary olarak (kütüphane
   olarak değil) dağıtılıyorsa git dependency yeterlidir.

### Tuzaklar

1. **"Hangi dosya GPL?" sorusunu hiç sormamak.**
   `crates/platform_title_bar/` altındaki **her dosya** GPL'dir.
   Buradan tek bir küçük helper fonksiyon bile taşınırsa lisans
   ihlali oluşur; "küçücük bir parça nasıl olsa sorun yapmaz" gibi
   bir varsayım kabul edilmez.
2. **API imzasını "yeniden yazmak" sanılarak kelime farkıyla
   kopyalamak.** `pub fn render_right_window_controls(button_layout,
   close_action, window)` ile aynı isim ve parametreleri kullanmak
   imza paritesidir ve kopya sayılmaz. Buna karşın **gövde**
   içindeki match/if/loop zincirinin birebir taşınması açık bir
   kopyadır; gövde her zaman kendi kelimelerle yeniden çözülmelidir.
3. **Lisans kontrolünü "sonra" diye ertelemek.** Bir kez GPL kod
   taşındığında, uygulamanın tamamı GPL olur; bunu sonradan geri
   almak `cargo deny` gibi bir araçla yakalanamayan bir durumdur. Bu
   yüzden lisans yaklaşımı **ilk port satırı yazılmadan önce**
   netleştirilir.
4. **`cargo deny check licenses` çalıştırmamak.** Yanlışlıkla transit
   bir GPL dependency'sinin sızması durumunda bu komut CI'da uyarı
   verir (Bölüm III, Konu 8 sonunda detayı vardır). Komutun
   çalıştırılmaması, ihlalin fark edilmesini geciktirir.

---

## 4. Kapsam ve port yaklaşımları

`platform_title_bar`, dışarıdan bakıldığında basit bir toolbar bileşeni
gibi görünebilir. Aslında değildir; Zed içinde aynı anda birden çok
görevi yürüten bir bileşendir. Listelemek gerekirse:

- Pencereyi sürüklenebilir yapan başlık çubuğu yüzeyini üretir.
- Linux client-side decoration (CSD) durumunda sol veya sağ pencere
  butonlarını render eder.
- Windows tarafında caption button hit-test alanlarını GPUI'nin
  `WindowControlArea` API'si üzerinden platforma bildirir.
- macOS tarafında trafik ışıklarına yer ayırır ve çift tıklama
  davranışını sistem titlebar davranışına iletir.
- `SystemWindowTabs` aracılığıyla native pencere sekmelerinin
  yüzeyini üretir: sekme çubuğu görünürlüğü, sekme kapatma, sekme
  sürükleme, sekmeyi yeni pencereye alma ve tüm pencereleri birleştirme
  davranışlarını birlikte bağlar.
- Zed workspace katmanındaki `CloseWindow`, `OpenRecent`,
  `WorkspaceSettings`, `ItemSettings`, `MultiWorkspace` gibi tipleri
  ve tema token'larını kullanır.

Bu paket bir uygulamaya alınırken iki ana yaklaşım söz konusudur:

1. **Zed ekosistemi içinde doğrudan kullanım.** `platform_title_bar`
   crate'i olduğu gibi tüketilir. Bu yolun ön koşulu, uygulamada Zed'in
   `workspace`, `settings`, `theme`, `ui`, `project` ve `zed_actions`
   crate'lerinin de mevcut olmasıdır.
2. **Bağımsız GPUI uygulaması için port.** Render davranışı korunur,
   ama Zed'e özgü action ve ayarlar ürünün kendi tipleriyle
   değiştirilir. Zed dışında bir uygulama için bu, kontrolün elde
   tutulduğu daha temiz yoldur.

Hangi yol seçilirse seçilsin, kod kopyalama veya birebir uyarlama söz
konusu olduğunda `crates/platform_title_bar` paket lisansının
`GPL-3.0-or-later` olduğu unutulmamalı ve karar ona göre verilmelidir.

---

