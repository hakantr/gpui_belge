# Bölüm I — Hedef, kapsam ve lisans

Önce neyi port ettiğini, hangi sorumluluğun hangi katmanda kaldığını ve lisans sınırını netleştir.

## 1. Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama state

**Kaynak yön:** Aşağıdan yukarıya — platform kabuğu en alttadır ve
**davranış paritesi** ister; üst katmanlar tasarım özgürlüğüyle yazılır.

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
`platform_title_bar` crate'inin **davranışını** yeniden yazarsın. Hit-test
alanları, drag akışı, hangi platformda hangi pencere butonu render
edilecek — hepsi Zed sözleşmesiyle paralel. Yaratıcılık yok; sadece
davranış paritesi. Bölüm V bu katmanı ele alır. **Lisans
nedeniyle kod kopyalanmaz**; sadece API'lerin gözlemlenebilir davranışı
yeniden inşa edilir.

**Ürün başlığı (orta katman) — `senin tasarımın`:** Uygulamanın
gerçek başlık içeriği. Menü, proje adı, status chip'leri, kullanıcı
avatar'ı — hepsi senin tasarım dilinde. Platform kabuğuna **child**
olarak verilir; her render'da yenilenir (Konu 16'da `set_children`
tüketim modeli). Tema rehberinin "Faz 5 — UI tüketim" bölümüyle aynı
zihniyet: temayı oku, durum-bazlı render et.

**Uygulama state (en üst katman) — `karar otoritesi`:** Platform
kabuğunun ihtiyaç duyduğu **politika** kararları: "close butonu ne
kapatıyor?", "new window action'ı hangi?", "Linux butonları sağda mı
solda mı?", "sidebar açık mı?". Bunları platform kabuğuna **trait
sözleşmesi** üzerinden verirsin (`TitleBarController` — Konu 10 sonu).

**Bağımlılık yönü:**

```
Uygulama state  ←─reads─  Ürün başlığı  ←─child of─  Platform kabuğu
                                                      │
                                                      └─reads─  TitleBarController
                                                                (uygulama state'inden trait obj)
```

Platform kabuğu doğrudan `AppState`'i bilmez — sadece `TitleBarController`
trait'ini bilir. Bu yön kuralı, platform kabuğunu **bağımsız test
edilebilir** kılar.

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

Sync turunda `platform_title_bar_aktarimi.md` ile birlikte bu eşleme tablosu
**referans değer** olarak kullanılır: Zed sözleşmesindeki yeni bir kavramın
hangi uygulama tipinde mirror edileceği burada belirlenir.

---

## 2. Temel ilke: platform katmanı bilir, ürün katmanı karar verir

Tek cümle: **Platform kabuğu pencerenin mekaniğini bilir; ürün katmanı
neyin kapanacağına, hangi menünün açılacağına, hangi workspace'in
taşınacağına karar verir.**

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

1. **Platform davranışı evrenseldir.** Bir Linux kullanıcısı kendi pencere
   manager'ının button layout ayarını bekler; kendi compositor'unun
   resize edge davranışını bekler. Ürün bu beklentilere karşı çıkamaz —
   onları tüketir.
2. **Ürün anlamı uygulamaya özgüdür.** Zed için close = workspace kapat;
   bir editor için close = doküman kapat; bir launcher için close = pencereyi
   gizle. Platform bu farkı bilmez, bilmek zorunda da değildir.
3. **Test izolasyonu için zorunludur.** Platform kabuğunu test ederken
   gerçek `AppState`'e ihtiyaç olmasın; mock `TitleBarController` yeterli
   olsun.

### Kontrol listesi: bir davranışı hangi katmana koymalı?

Bir davranış için üç soru:

1. **Bu davranış pencere yöneticisi/OS sözleşmesini takip mi ediyor?**
   → Platform katmanı.
2. **Bu davranış uygulamanın iş kuralına mı bağlı?**
   → Ürün katmanı veya `AppState`.
3. **Hangi katmana koyduğumda diğer uygulamalar bu kabuğu kullanabilir?**
   → O katman doğru cevap.

> **Örnek hatalı yerleşim:** "Close butonu tıklandığında SaveModal aç" —
> bu **ürün katmanında** olmalı; platform kabuğu sadece "close intent"
> dispatch eder, modal açma kararı `AppState`'in.

### "Tema rehberindeki Temel ilke ile farkı"

Tema rehberinin Konu 2'si **veri sözleşmesinde dışlama yok** diyordu —
tüm Zed alanları mirror edilmeli. Bu rehberin Konu 2'si **kapsam farkı**
söylüyor: platform vs ürün vs state. İki kural aynı zihniyetin iki
yüzü: **sözleşmeyi geliştiriciye, uygulamayı geliştiricinin ürününe
bırak**.

### Tuzaklar

1. **Close action'ı platforma sabitlemek.** `PlatformTitleBar`'a
   `close_action: Box::new(workspace::CloseWindow)` koyarsan platform
   kabuğu Zed'e bağlanır. **Daima dışarıdan** geçir.
2. **Çift tıklama davranışını ürüne sızdırmak.** macOS double-click
   `window.titlebar_double_click()` — platform sözleşmesi. Ürün burada
   `cx.dispatch_action(ZoomWorkspace)` çağırsa platform farkı bozulur.
3. **Sidebar açıkken pencere kontrollerini gizleme kararı.** Bu Konu 15'te
   ele alınıyor — sidebar bilgisi `TitleBarController` üzerinden gelir,
   platform kabuğu doğrudan workspace state'ini sorgulamaz.
4. **Native tab kararını ürüne kapatmak.** `tabbing_identifier`
   verilmesi/verilmemesi `TitleBarController::use_system_window_tabs`'tan
   gelir; platform kabuğu kendi karar vermez.

---

## 3. Lisans-temiz çalışma protokolü

Zed'in `platform_title_bar` ve `title_bar` crate'leri
**GPL-3.0-or-later** lisanslıdır. Kod gövdesi kopyalanamaz; ancak API
imzaları, JSON sözleşmeleri, davranış kuralları telif kapsamında değildir
ve mirror edilebilir.

> **Tema rehberi Konu 3 ile fark:** Tema sözleşmesi alan adlarını mirror
> ediyor (data shape). Burada **davranışı** mirror ediyoruz: "mouse'a
> basıldığında pencere sürüklenmeye başlar", "close butonu ana
> caption'da sağ uçtadır" gibi gözlemlenebilir davranışlar telif değil;
> bunları yeniden inşa edebilirsin.

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

- **`gpui`** — `WindowOptions`, `TitlebarOptions`, `WindowControlArea`,
  `WindowButtonLayout`, `WindowDecorations`, `Window` methodları
  (`start_window_move`, `minimize_window`, `zoom_window`, `show_window_menu`,
  `titlebar_double_click`, `set_client_inset`, `tab_bar_visible`,
  `set_tabbing_identifier`).
- **`refineable`** — Style cascade için (tema rehberindeki kullanım gibi;
  title bar'da çoğu zaman gerekmez ama opsiyonel).
- **`collections`** — `HashMap`/`IndexMap` wrapper'ları.

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

Bu rehber **3. yolu** anlatır. 1. veya 2. yolu seçen geliştiriciler için
bu rehber yine işe yarar (Bölüm II–V referans amaçlı okunabilir), ama
"port" kelimesi geçen her yerde sadece "kullan" deyip geçebilirler.

### Doc comment yazımı

Zed kaynak dosyasındaki bir fonksiyon imzasını mirror ediyorsan, doc
comment'i **kendi sözcüklerinle** yaz. Aynı cümleyi kullanma. Örnek:

```rust
// Zed'de (mirror EDİLMEZ — birebir kopyalama):
/// Renders the left window controls for Linux client-side decorations.

// Sizde (mirror EDİLİR — yeniden yazılmış):
/// Linux client-side decoration durumunda sol kenar pencere butonlarını
/// üretir; layout boş ise `None` döner.
pub fn render_left_window_controls(...) -> Option<impl IntoElement> { ... }
```

### Publishing uyarısı

`gpui` ve `refineable` Zed workspace'inde `publish = false` ile
işaretlidir. Yani crates.io'ya yayınlanacak bir kütüphane içinde git/path
dep olarak kullanılamazlar. Üç çözüm (tema rehberi Konu 3 ile aynı):

1. **Vendor:** Kaynak kodu kendi monorepo'na kopyala (lisans + atribusyon
   koru).
2. **Fork yayınla:** `gpui`'yi kendi adınla crates.io'ya yayınla.
3. **Sadece dahili kullan:** Uygulaman binary olarak dağıtılıyorsa
   (kütüphane değil), git dep yeterli.

### Tuzaklar

1. **"Hangi dosya GPL?" diye düşünmemek.** `crates/platform_title_bar/`
   altındaki **her dosya** GPL. Tek bir helper fonksiyonu bile taşırsan
   ihlal.
2. **API imzasını "yeniden yazmak" diye kelime farkıyla kopyalamak.**
   `pub fn render_right_window_controls(button_layout, close_action, window)`
   ile aynı isim/parametre yazmak imza paritesi (kopya değil). Ama
   **gövde** içindeki match/if/loop zincirini birebir alırsan kopya
   olur — kendi kodunla yeniden çöz.
3. **Lisans kontrolünü "sonra" demek.** Bir kez GPL kod taşırsan
   uygulaman da GPL olur; bunu sonradan geri almak `cargo deny` ile
   yakalanmaz. **İlk port satırından önce** yaklaşımını seç.
4. **`cargo deny check licenses` çalıştırmamak.** Yanlışlıkla transit bir
   GPL dep girerse CI'da yakalanmalı (Bölüm III/Konu 8 sonu).

---

## 4. Kapsam ve port yaklaşımları

`platform_title_bar`, yalnızca bir toolbar bileşeni değildir. Zed içinde şu
işleri birlikte yürütür:

- Pencereyi sürüklenebilir yapan başlık çubuğu yüzeyini üretir.
- Linux client-side decoration durumunda sol veya sağ pencere butonlarını
  render eder.
- Windows'ta caption button hit-test alanlarını GPUI `WindowControlArea` ile
  platforma bildirir.
- macOS'ta trafik ışıklarına alan bırakır ve çift tıklama davranışını sistem
  titlebar davranışına iletir.
- `SystemWindowTabs` ile native pencere sekmeleri için görünür sekme çubuğu,
  sekme kapatma, sekme sürükleme, sekmeyi yeni pencereye alma ve tüm pencereleri
  birleştirme davranışlarını bağlar.
- Zed workspace katmanındaki `CloseWindow`, `OpenRecent`, `WorkspaceSettings`,
  `ItemSettings`, `MultiWorkspace` ve tema token'larına dayanır.

Kendi uygulamanıza alırken iki yaklaşım vardır:

1. **Zed ekosistemi içinde doğrudan kullanmak**: `platform_title_bar` crate'ini
   olduğu gibi kullanırsınız. Bunun için Zed'in `workspace`, `settings`,
   `theme`, `ui`, `project` ve `zed_actions` crate'leri de uygulamanızda
   bulunmalıdır.
2. **Bağımsız GPUI uygulaması için port etmek**: Render davranışını korur,
   Zed'e özel action ve ayarları kendi uygulama tiplerinizle değiştirirsiniz.
   Bu, Zed dışındaki uygulamalar için daha kontrollü yoldur.

Kod kopyalama veya doğrudan uyarlama yaparken `crates/platform_title_bar` paket
lisansının `GPL-3.0-or-later` olduğunu ayrıca kontrol edin.

---

