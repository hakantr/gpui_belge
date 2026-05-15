# Zed Platform Title Bar Kullanım Rehberi

Bu rehber, GPUI tabanlı kendi uygulamana **Zed-uyumlu, platforma duyarlı bir
başlık çubuğu** entegre etmen için yazılmıştır. Zed'in
`crates/platform_title_bar` ve `crates/title_bar` crate'lerini **doğrudan
dependency olarak kullanmadan** (GPL-3 lisans nedeniyle), aynı platform
davranışını veren, kendi action ve ayar sözleşmenize bağlanan, lisans
açısından temiz bir başlık çubuğu inşa etmek hedeftir.

> **Eşlik eden dosyalar:** `platform_title_bar_aktarimi.md` (upstream pin /
> sync günlüğü) ve `platform_title_bar_kaymasi_kontrol.sh` (drift raporu).
> Bu rehber **mimari, sözleşme ve kod** tarafına odaklanır; uzun vadeli
> senkron disiplini için onlara bakılır.

> **Anlatım biçimi:** Rehber, GPUI ana referansı `rehber.md` ve tema
> rehberi `tema_rehber.md` ile aynı biçimi kullanır — her konu kendi
> başına okunabilir; kullanılan tipi, hangi modülden geldiğini, kabul
> ettiği değerleri, runtime davranışını ve yaygın tuzakları tek yerde
> toplar.

---

## İçindekiler

Rehber, baştan sona okunduğunda önce hedef/kapsam/lisans sınırını, sonra Zed kaynak haritasını, ardından proje iskeletini ve pencere entegrasyonu ön koşullarını kurar. Bundan sonra uygulama sözleşmesi, PlatformTitleBar render akışı, pencere kontrol butonları, native sekmeler, ürün titlebar'ı, pratik kontrol listeleri ve son olarak referans/doğrulama komutları gelir. Böylece okuyucu önce neyi neden port ettiğini, sonra hangi kodu hangi sırayla yazacağını görür.

**Bölüm I — Hedef, kapsam ve lisans**

1. Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama state
2. Temel ilke: platform katmanı bilir, ürün katmanı karar verir
3. Lisans-temiz çalışma protokolü
4. Kapsam ve port yaklaşımları

**Bölüm II — Zed kaynak haritası ve bağlantı modeli**

5. Zed kaynak haritası
6. Zed içindeki bağlantı modeli

**Bölüm III — Proje iskeleti ve bağımlılıklar**

7. Crate yapısı ve klasör yerleşimi
8. Bağımlılık matrisi

**Bölüm IV — Entegrasyon başlangıcı ve uygulama sözleşmesi**

9. Entegrasyon ön koşulları
10. Uygulama katmanına önerilen model

**Bölüm V — Platform titlebar render akışı ve pencere kontrolleri**

11. Davranış modeli
12. Buton yerleşimi ve ayar yönetimi
13. Butonları uygulama katmanına bağlama

**Bölüm VI — Native pencere sekmeleri**

14. System window tabs

**Bölüm VII — Ürün titlebar'ı ve uygulamaya bağlama**

15. Sidebar ve workspace etkileşimi
16. Başlık çubuğuna içerik yerleştirme
17. Kendi uygulamana dahil etme

**Bölüm VIII — Pratik uygulama**

18. Özelleştirme noktaları
19. Kontrol listesi
20. Sık yapılan hatalar

**Bölüm IX — Referans ve doğrulama**

21. Public API envanteri
22. Kaynak doğrulama komutları

---

## Bölüm I — Hedef, kapsam ve lisans

Önce neyi port ettiğini, hangi sorumluluğun hangi katmanda kaldığını ve lisans sınırını netleştir.

### 1. Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama state

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

#### Zed ile bu rehberin terim eşlemesi

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

### 2. Temel ilke: platform katmanı bilir, ürün katmanı karar verir

Tek cümle: **Platform kabuğu pencerenin mekaniğini bilir; ürün katmanı
neyin kapanacağına, hangi menünün açılacağına, hangi workspace'in
taşınacağına karar verir.**

#### Üç şeyi ayırt et

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

#### Gerekçe

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

#### Kontrol listesi: bir davranışı hangi katmana koymalı?

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

#### "Tema rehberindeki Temel ilke ile farkı"

Tema rehberinin Konu 2'si **veri sözleşmesinde dışlama yok** diyordu —
tüm Zed alanları mirror edilmeli. Bu rehberin Konu 2'si **kapsam farkı**
söylüyor: platform vs ürün vs state. İki kural aynı zihniyetin iki
yüzü: **sözleşmeyi geliştiriciye, uygulamayı geliştiricinin ürününe
bırak**.

#### Tuzaklar

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

### 3. Lisans-temiz çalışma protokolü

Zed'in `platform_title_bar` ve `title_bar` crate'leri
**GPL-3.0-or-later** lisanslıdır. Kod gövdesi kopyalanamaz; ancak API
imzaları, JSON sözleşmeleri, davranış kuralları telif kapsamında değildir
ve mirror edilebilir.

> **Tema rehberi Konu 3 ile fark:** Tema sözleşmesi alan adlarını mirror
> ediyor (data shape). Burada **davranışı** mirror ediyoruz: "mouse'a
> basıldığında pencere sürüklenmeye başlar", "close butonu ana
> caption'da sağ uçtadır" gibi gözlemlenebilir davranışlar telif değil;
> bunları yeniden inşa edebilirsin.

#### Yapılabilir / Yapılamaz

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| API imzalarını gözlemleyip yeniden yazmak (örn. `pub fn set_button_layout(...)`) | `crates/platform_title_bar/src/*.rs` kod gövdesini kopyalamak |
| Davranışı tarif edip kendi kelimelerinle implement etmek | Doc comment'i kelime kelime taşımak |
| `WindowControlArea` enum varyantlarını mirror etmek (gpui'den, Apache-2.0) | Zed'in `LinuxWindowControls` impl'ini taşımak |
| `WindowButtonLayout` enum varyantlarını mirror etmek (gpui'den) | Zed'in render fonksiyonlarını birebir Rust → Rust kopyalamak |
| Platform-spesifik bilinen davranışları (hit-test, dbl-click) yeniden yazmak | Zed'in caption button hover renklerinin tam hex değerlerini kopyalamak |
| Sözleşme parite tabloları çıkarmak (sync turunda) | Zed'in mevcut SVG icon dosyalarını binary olarak gömmek |

#### Güvenli dependency'ler (hepsi Apache-2.0, Zed workspace'inden alınabilir)

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

#### Üç port yaklaşımı ve lisans sonucu

| Yaklaşım | Lisans sonucu | Kullanım koşulu |
|----------|---------------|-----------------|
| **1. Doğrudan `platform_title_bar` dependency** | Senin uygulaman **GPL-3** olur | Sadece kendin GPL altında dağıtacaksan |
| **2. Crate'i vendor'la (kaynak kodu kopyala)** | Vendor'lanan kod **hâlâ GPL-3**; senin uygulaman da GPL-3 olur | Yine GPL hedefin varsa |
| **3. Davranış mirror'ı (kendi koddan yeniden yaz)** | Senin kodun **kendi lisansın** olur | **Lisans-temiz hedef için tek doğru yol** |

Bu rehber **3. yolu** anlatır. 1. veya 2. yolu seçen geliştiriciler için
bu rehber yine işe yarar (Bölüm II–V referans amaçlı okunabilir), ama
"port" kelimesi geçen her yerde sadece "kullan" deyip geçebilirler.

#### Doc comment yazımı

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

#### Publishing uyarısı

`gpui` ve `refineable` Zed workspace'inde `publish = false` ile
işaretlidir. Yani crates.io'ya yayınlanacak bir kütüphane içinde git/path
dep olarak kullanılamazlar. Üç çözüm (tema rehberi Konu 3 ile aynı):

1. **Vendor:** Kaynak kodu kendi monorepo'na kopyala (lisans + atribusyon
   koru).
2. **Fork yayınla:** `gpui`'yi kendi adınla crates.io'ya yayınla.
3. **Sadece dahili kullan:** Uygulaman binary olarak dağıtılıyorsa
   (kütüphane değil), git dep yeterli.

#### Tuzaklar

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

### 4. Kapsam ve port yaklaşımları

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

## Bölüm II — Zed kaynak haritası ve bağlantı modeli

Ardından Zed içindeki gerçek kaynakları ve başlık çubuğunun uygulama içinde hangi callbacklerle yaşadığını oku.

### 5. Zed kaynak haritası

| Parça | Kaynak | Görev |
| :-- | :-- | :-- |
| `PlatformTitleBar` | `crates/platform_title_bar/src/platform_title_bar.rs` | Ana render entity'si, drag alanı, arka plan, köşe yuvarlama, child slotları, sol/sağ buton yerleşimi. |
| `render_left_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD'de sol pencere butonlarını üretir. |
| `render_right_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD veya Windows için sağ pencere butonlarını üretir. |
| `LinuxWindowControls` | `crates/platform_title_bar/src/platforms/platform_linux.rs` | Linux minimize, maximize/restore ve close butonlarının GPUI render katmanı. |
| `WindowsWindowControls` | `crates/platform_title_bar/src/platforms/platform_windows.rs` | Windows caption butonları ve `WindowControlArea` eşleşmeleri. |
| `SystemWindowTabs` | `crates/platform_title_bar/src/system_window_tabs.rs` | Native pencere sekmeleri, sekme menüsü, sürükle-bırak ve pencere birleştirme davranışları. Modül private olduğu için dış crate API'si değildir; `PlatformTitleBar` içinde child entity olarak kullanılır. |
| `TitleBar` | `crates/title_bar/src/title_bar.rs` | Zed'in uygulama başlığı, proje adı, menü, kullanıcı ve workspace state'ini `PlatformTitleBar` içine bağlayan üst seviye bileşen. |
| `client_side_decorations` | `crates/workspace/src/workspace.rs` | CSD pencere gölgesi, border, resize kenarları ve inset yönetimi. |
| `WindowOptions` | `crates/gpui/src/platform.rs` | Pencere dekorasyonu, titlebar options ve native tabbing identifier ayarları. |

### 6. Zed içindeki bağlantı modeli

Zed ana workspace penceresinde `title_bar::init(cx)` çalışır. Bu fonksiyon önce
`PlatformTitleBar::init(cx)` çağırır, sonra her yeni `Workspace` için bir
`TitleBar` entity'si oluşturur ve workspace titlebar item'ına yerleştirir.

Basitleştirilmiş akış şöyledir:

```rust
pub fn init(cx: &mut App) {
    platform_title_bar::PlatformTitleBar::init(cx);

    cx.observe_new(|workspace: &mut Workspace, window, cx| {
        let Some(window) = window else {
            return;
        };

        let multi_workspace = workspace.multi_workspace().cloned();
        let item = cx.new(|cx| {
            TitleBar::new("title-bar", workspace, multi_workspace, window, cx)
        });

        workspace.set_titlebar_item(item.into(), window, cx);
    })
    .detach();
}
```

`TitleBar`, kendi `Render` akışında `PlatformTitleBar` entity'sini günceller:

```rust
self.platform_titlebar.update(cx, |titlebar, _| {
    titlebar.set_button_layout(button_layout);
    titlebar.set_children(children);
});

self.platform_titlebar.clone().into_any_element()
```

Bu kullanım önemli bir detayı gösterir: `PlatformTitleBar`, child element'lerini
render sırasında `mem::take` ile tüketir. Bu yüzden dinamik başlık içeriği her
render geçişinde tekrar `set_children(...)` ile verilmelidir.

Zed uygulamasındaki gerçek yönetim zinciri şu kaynaklardan okunur:

| Aşama | Kaynak | Ne yapıyor? |
| :-- | :-- | :-- |
| Pencere açılışı | `crates/zed/src/zed.rs:322-370` | `ZED_WINDOW_DECORATIONS` env değeri veya `WorkspaceSettings::window_decorations` ile client/server decoration seçer; `TitlebarOptions { appears_transparent: true, traffic_light_position: Some(point(px(9), px(9))) }`, `is_movable: true`, `window_decorations`, `tabbing_identifier` ayarlarını verir. |
| GPUI pencere bootstrap'i | `crates/gpui/src/window.rs:1295-1299` | Platform native tab görünürlüğünü `SystemWindowTabController::init_visible` ile başlatır ve platform `tabbed_windows()` listesini controller'a ekler. |
| Title bar kurulumu | `crates/title_bar/src/title_bar.rs:79-88` | `PlatformTitleBar::init(cx)` çağrılır; her yeni `Workspace` için `TitleBar::new(...)` entity'si oluşturulup `workspace.set_titlebar_item(...)` ile workspace'e bağlanır. |
| Product titlebar render'i | `crates/title_bar/src/title_bar.rs:346-379` | `TitleBar`, her render'da `set_button_layout(...)` ve `set_children(...)` çağırır. `show_menus` açıksa platform kabuğu ile ürün başlığı iki satıra ayrılır; kapalıysa ürün child'ları doğrudan `PlatformTitleBar` içine verilir. |
| Platform titlebar render'i | `crates/platform_title_bar/src/platform_title_bar.rs:183-325` | Drag alanı, double-click, sidebar çakışması, Linux/Windows pencere kontrolleri, sağ tık window menu ve `SystemWindowTabs` child'ı burada birleşir. |
| CSD dış sarmal | `crates/workspace/src/workspace.rs:10475-10670` | `client_side_decorations(...)` shadow, border, resize edge, cursor ve `window.set_client_inset(...)` davranışlarını sağlar. Titlebar tek başına CSD penceresinin tamamı değildir. |
| Platform callback'leri | `crates/gpui/src/window.rs:1453-1565` | Button layout değişimi, aktif pencere değişimi, hit-test, native tab taşıma/birleştirme/seçme ve tab bar toggle callback'leri GPUI controller state'ine bağlanır. |

Bu zincirden çıkan port kuralı: `PlatformTitleBar` yalnızca render edilen başlık
kabuğudur. Zed'de onu yaşatan sistem `WindowOptions`, GPUI platform callback'leri,
`TitleBarSettings`, `Workspace` lifecycle'ı ve CSD sarmalıyla birlikte çalışır.

---

## Bölüm III — Proje iskeleti ve bağımlılıklar

Kaynak haritası anlaşıldıktan sonra lisans-temiz crate sınırlarını, klasörleri ve dependency grafiğini kur.

### 7. Crate yapısı ve klasör yerleşimi

Platform title bar **iki crate** olarak konumlanır; tema sisteminin
`kvs_tema` + `kvs_syntax_tema` ayrımıyla aynı zihniyet.

| Crate | Sorumluluk | Lisans |
|-------|-----------|--------|
| `kvs_titlebar` | `PlatformTitleBar`, platform-spesifik buton tipleri, native tabs, `WindowControlArea` mirror'ları, `TitleBarController` trait | senin lisansın |
| `kvs_app_titlebar` | Ürün başlık içeriği (menü, proje adı, kullanıcı UI, status chip'leri) | senin lisansın |

> **Crate adlandırma:** `kvs_*` prefix bu rehberde örnek. Kendi projende
> `app_titlebar`, `core_titlebar` veya istediğin adı ver; rehber kalıpları
> aynı kalır.

#### Neden iki crate?

**Bağımsız test ve evrim:**

- `kvs_titlebar` platform kabuğunu içerir → Zed'in `platform_title_bar`
  sync turlarında değişen tek crate olur.
- `kvs_app_titlebar` ürünün başlık içeriğini içerir → uygulamanın UI
  tasarım kararlarına bağlı; Zed evriminden etkilenmez.
- İkisi ayrı crate olunca **derleme süresi** ve **bağımlılık grafiği**
  net kalır; platform kabuğu sadece `gpui`'ye, ürün başlığı tema/menu
  crate'lerine bağlanır.

**Lisans izolasyonu:**

- `kvs_titlebar` Zed `platform_title_bar` davranışını mirror eder; doc
  comment, isim seçimi gibi konularda lisans-temizliğe en çok özen
  gerektiren crate burası.
- `kvs_app_titlebar` tamamen senin tasarım dilin; Zed davranışı sızıntısı
  yoktur.

#### Klasör yerleşimi

```
~/github/
├── gpui_belge/                       ← rehber + aktarım günlüğü + drift script
│   ├── platform_title_bar_rehberi.md
│   ├── platform_title_bar_aktarimi.md
│   └── platform_title_bar_kaymasi_kontrol.sh
├── zed/                              ← referans kaynak
└── kvs_ui/                           ← senin uygulaman
    ├── Cargo.toml                    ← workspace
    └── crates/
        ├── kvs_titlebar/
        │   ├── Cargo.toml
        │   ├── DECISIONS.md          ← Zed'den farklılıkların kaydı
        │   ├── src/
        │   │   ├── kvs_titlebar.rs       ← lib kökü (mod.rs değil)
        │   │   ├── platform_title_bar.rs ← PlatformTitleBar entity
        │   │   ├── platforms/
        │   │   │   ├── platform_linux.rs    ← LinuxWindowControls
        │   │   │   ├── platform_windows.rs  ← WindowsWindowControls
        │   │   │   └── platform_macos.rs    ← macOS davranış helper'ları
        │   │   ├── system_window_tabs.rs ← native pencere sekmeleri
        │   │   ├── controller.rs         ← TitleBarController trait
        │   │   └── style.rs              ← WindowControlStyle helper
        │   └── tests/
        │       ├── controller_mock.rs    ← Mock TitleBarController
        │       └── render_smoke.rs       ← Headless render testleri
        ├── kvs_app_titlebar/
        │   ├── Cargo.toml
        │   ├── src/
        │   │   ├── kvs_app_titlebar.rs   ← lib kökü
        │   │   ├── app_title_bar.rs      ← AppTitleBar entity (Zed'in TitleBar'ı muadili)
        │   │   ├── menu.rs               ← uygulama menüsü
        │   │   ├── project_picker.rs     ← proje/doküman adı widget'ı
        │   │   └── user_menu.rs          ← kullanıcı menüsü (opsiyonel)
        │   └── tests/
        └── kvs_tema/                ← tema rehberinden
            └── ...
```

#### Modül adlandırma kuralı

Lib kökü `mod.rs` yerine **crate adıyla aynı isimli dosya** (örn.
`kvs_titlebar.rs`). Bu, editör başlığında hangi dosyayı düzenlediğini
görmeni sağlar; Zed projesinin kendi konvansiyonu da budur (tema
rehberi Konu 4 ile aynı).

#### `DECISIONS.md`

Her crate kendi karar günlüğünü tutar. Zed'den farklı yaptığın her şey
burada gerekçesiyle kayıt altına alınır. Örnek ilk giriş:

```markdown
# kvs_titlebar karar günlüğü

## YYYY-MM-DD — İlk pin

- Pin: <Zed kısa SHA> (bkz. ../../gpui_belge/platform_title_bar_aktarimi.md)
- Crate yapısı: kvs_titlebar (platform kabuğu) + kvs_app_titlebar (ürün başlığı)
- TitleBarController trait: uygulama action / sidebar / button_layout
  sorularını trait üzerinden alır (Zed'in workspace doğrudan referansı
  yerine)
- SystemWindowTabs: ilk sürümde **kapalı** (feature flag default off);
  uygulama native tab desteğine ihtiyaç doğunca açılacak
- macOS double-click davranışı: sistem default'a teslim edilir; ayar
  override'ı yapılmaz (gerekirse Konu 11'e göre eklenir)
- Linux CSD: WindowDecorations::Client desteklenir; CSD sarmalı
  (client_side_decorations muadili) ayrı bir helper olarak yazılır
```

`DECISIONS.md`'yi her sync turunda ve mimari kararda **güncelle**. 6 ay
sonraki sen sana minnettar olur.

#### Modüllerin sorumluluk haritası

| Modül | İçerir | Dış API mı? |
|-------|--------|-------------|
| `kvs_titlebar.rs` (lib kökü) | Re-export'lar, `PlatformTitleBar`, `TitleBarController` | Evet |
| `platform_title_bar.rs` | `PlatformTitleBar`, render fonksiyonları, `render_left_window_controls`, `render_right_window_controls` | Evet |
| `platforms/platform_linux.rs` | `LinuxWindowControls`, `WindowControl`, `WindowControlStyle` | Evet (kararsız) |
| `platforms/platform_windows.rs` | `WindowsWindowControls` | Evet (kararsız) |
| `platforms/platform_macos.rs` | macOS davranış helper'ları (genelde trivial) | Crate-içi |
| `system_window_tabs.rs` | `SystemWindowTabs`, `SystemWindowTabController`, native tab davranışı | Evet (kararsız) |
| `controller.rs` | `TitleBarController` trait, ilgili veri tipleri (`ShellSidebarState`, vs.) | Evet |
| `style.rs` | `WindowControlStyle` builder helper'ı | Crate-içi (veya kararsız public) |

"Dış API" sütununda "kararsız" işareti olan modüller (platform-spesifik
butonlar, native tabs) Zed sync turlarında değişme olasılığı yüksek
olan parçalar; tüketici doğrudan bunlara dayanırsa breaking change'e
açıktır. Public API kararlılık seviyeleri Bölüm IX/Konu 21'de detaylı.

---

### 8. Bağımlılık matrisi

`kvs_titlebar/Cargo.toml`:

```toml
[package]
name = "kvs_titlebar"
version = "0.1.0"
edition = "2021"
license = "MIT"            # veya Apache-2.0 — kendi seçimin
publish = false

[lib]
path = "src/kvs_titlebar.rs" # mod.rs değil

[dependencies]
# Zed workspace (Apache-2.0; publish = false uyarısı için Konu 3)
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }

# Aile içi crate'ler
kvs_tema = { path = "../kvs_tema" }

# Üçüncü taraf
anyhow = "1"
serde = { version = "1", features = ["derive"] }
```

`kvs_app_titlebar/Cargo.toml`:

```toml
[package]
name = "kvs_app_titlebar"
version = "0.1.0"
edition = "2021"
license = "MIT"
publish = false

[lib]
path = "src/kvs_app_titlebar.rs"

[dependencies]
gpui = { git = "https://github.com/zed-industries/zed", branch = "main" }
kvs_titlebar = { path = "../kvs_titlebar" }
kvs_tema = { path = "../kvs_tema" }

anyhow = "1"
```

#### Her dependency'nin rolü

| Crate | Rol | Tema'da/title bar'da tipik kullanım |
|-------|-----|--------------------------------------|
| `gpui` | UI çatısı, pencere API'leri | `WindowOptions`, `WindowControlArea`, `WindowButtonLayout`, `Window` methodları, `App`/`Context` |
| `kvs_tema` | Tema renkleri | `cx.theme().colors().title_bar_background` |
| `kvs_titlebar` (kvs_app_titlebar için) | Platform kabuğu | `PlatformTitleBar`, `TitleBarController` trait |
| `anyhow` | Hata propagation | Tema/state init hatalarını caller'a iletmek |
| `serde` | Settings deserialize | `WindowButtonLayout` ayarını kullanıcı config'inden okumak |

#### Zed bağımlılığı → port karşılığı tablosu

Zed'in `platform_title_bar` ve `title_bar` crate'leri aşağıdaki Zed-içi
crate'lere bağlanır. Port ederken bunları **kendi karşılıklarınla
değiştir**:

| Zed bağımlılığı | Bu rehberdeki port karşılığı |
|-----------------|------------------------------|
| `workspace::Workspace` | Uygulamanın kendi shell state'i (örn. `AppShell` entity'si) |
| `workspace::CloseWindow` | `TitleBarController::close_action()` üzerinden gelen action |
| `workspace::MultiWorkspace` | `TitleBarController::sidebar_state()` (opsiyonel) |
| `workspace::client_side_decorations` | Kendi CSD sarmalı (Konu 9) |
| `zed_actions::OpenRecent { create_new_window: true }` | `TitleBarController::new_window_action()` |
| `WorkspaceSettings::use_system_window_tabs` | `TitleBarController::use_system_window_tabs(cx)` |
| `ItemSettings::close_position`, `ItemSettings::show_close_button` | Senin kendi `TabSettings` veya app config |
| `DisableAiSettings` | Senin kendi feature flag'in (`SidebarSettings::enabled` vb.) |
| `feature_flags::FeatureFlagAppExt`, `SkillsFeatureFlag` (`title_bar/Cargo.toml` ve `title_bar.rs`) | Kendi feature flag altyapısı; `cx.has_flag::<FooFlag>()` benzeri bir yardımcı veya boolean ayar ile değiştirilir. Zed `title_bar` crate'i bu bağımlılığı `OnboardingBanner` görünürlüğünü kapatıp açmak için kullanır. |
| `zed_actions::agent::OpenRulesToSkillsMigrationInfo` | Ürünün kendi duyuru/migration modalı action'ı; banner tıklandığında dispatch edilir. |
| `theme::Theme::colors()::title_bar_background` | `kvs_tema::ActiveTheme` + `cx.theme().colors().title_bar_background` |
| `theme::Theme::colors()::title_bar_inactive_background` | `cx.theme().colors().title_bar_inactive_background` |
| `ui::prelude::*`, `ui::IconButton`, `ui::Tooltip` | Kendi UI bileşen kütüphanen |
| `zed::ReleaseChannel::global(cx).app_id()` | Senin `AppState::app_id()` |

#### Versiyon pinleme tavsiyesi

- **`gpui` git `branch = "main"`** ile takip ediliyor; pin commit'e
  sabitlemek istersen `rev = "..."` kullan. Title bar için en kritik
  imzalar: `WindowControlArea`, `WindowButtonLayout`, `TitlebarOptions`,
  `Window::start_window_move`. Sync turunda bu imzaların değişip
  değişmediği kontrol edilir.
- **`kvs_tema`** tema rehberinde anlatılan crate; aynı workspace'in
  parçası olduğu için path dep yeterli.

#### Bağımlılık akış grafiği

```
kvs_app_titlebar  ──depends on──>  kvs_titlebar, kvs_tema, gpui
                                    ↑
                                    │  AppTitleBar, child olarak
                                    │  PlatformTitleBar'a verilir
                                    │
kvs_titlebar  ──depends on──>  gpui, kvs_tema, anyhow, serde

kvs_tema  ──depends on──>  gpui, refineable, collections, palette, serde, ...

gpui  ──published from──>  zed workspace (Apache-2.0)
```

Bu grafiğin yönü tersine işlemez; `gpui` asla `kvs_titlebar`'a bağlanmaz.
`kvs_titlebar` asla `kvs_app_titlebar`'a bağlanmaz. Bu kural, Zed'in
upstream'inde değişiklik olduğunda etkilenme yüzeyini sınırlar.

#### Lib kökü iskeleti (`kvs_titlebar/src/kvs_titlebar.rs`)

```rust
//! kvs_titlebar — Zed-uyumlu, lisans-temiz platform title bar.

mod controller;
mod platform_title_bar;
mod platforms;
mod style;
mod system_window_tabs;

pub use crate::controller::*;
pub use crate::platform_title_bar::*;
pub use crate::platforms::*;
pub use crate::system_window_tabs::*;

// style modülü crate-içi tutulabilir; sadece WindowControlStyle public ise re-export
pub use crate::style::WindowControlStyle;
```

`platforms` modülünü `pub mod platforms` yerine `mod platforms` + re-export
seçtim çünkü `platforms::platform_linux::*` gibi nested path tüketici için
karışık; düz `kvs_titlebar::LinuxWindowControls` daha okunabilir.

#### Bağımlılık denetim CI'ı

`cargo-deny` ile transit GPL bağımlılık girişini engelle (`deny.toml`):

```toml
[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause", "MPL-2.0", "ISC", "Unicode-DFS-2016"]
deny = ["GPL-3.0", "GPL-2.0", "AGPL-3.0", "LGPL-3.0"]

[bans]
# Zed'in GPL crate'lerini kazara dep olarak ekleme
deny = [
    { name = "platform_title_bar" },
    { name = "title_bar" },
    { name = "workspace" },
    { name = "theme" },
    { name = "theme_settings" },
    { name = "theme_selector" },
    { name = "zed_actions" },
]
```

CI workflow'una ekle:

```yaml
- name: License check
  run: cargo deny check licenses bans
```

**Bölüm III çıkış kriteri:** `cargo check -p kvs_titlebar -p kvs_app_titlebar`
yeşil. Tipler tanımlı (alanları boş veya `unimplemented!()` olsa bile);
modül ağacının iskeleti hazır; lisans-temiz dep listesi `cargo deny` ile
doğrulanıyor.


## Bölüm IV — Entegrasyon başlangıcı ve uygulama sözleşmesi

Pencere açılırken gereken GPUI ayarlarını yap ve platform kabuğunun uygulama state'ine soracağı controller sözleşmesini tanımla.

### 9. Entegrasyon ön koşulları

#### Pencere seçenekleri

Custom titlebar davranışı pencere açılırken başlar. Zed ana penceresinde
`WindowOptions` içinde şunlar ayarlanır:

```rust
WindowOptions {
    titlebar: Some(TitlebarOptions {
        title: None,
        appears_transparent: true,
        traffic_light_position: Some(point(px(9.0), px(9.0))),
    }),
    is_movable: true,
    window_decorations: Some(window_decorations),
    tabbing_identifier: if use_system_window_tabs {
        Some(String::from("zed"))
    } else {
        None
    },
    ..Default::default()
}
```

Kendi uygulamanızda:

- `titlebar.appears_transparent = true`, custom içerik ile native titlebar'ın
  görsel çakışmasını önler.
- `is_movable = true`, platform pencere taşıma davranışının çalışması için
  açık kalmalıdır.
- Linux/FreeBSD tarafında `window_decorations: Some(WindowDecorations::Client)`
  seçildiğinde Zed'in Linux butonları ve CSD kenarları devreye girer.
- macOS native tab grupları kullanılacaksa aynı uygulamaya ait pencerelerde
  ortak `tabbing_identifier` verilmelidir.

#### Client-side decoration sarmalı

`PlatformTitleBar`, üst başlık çubuğunu üretir; pencerenin shadow, border, resize
kenarı ve client inset davranışı Zed'de `workspace::client_side_decorations(...)`
ile sarılır.

Kendi uygulamanızda Linux CSD kullanıyorsanız aynı sorumlulukları karşılayan bir
sarmal gerekir:

- CSD aktifken `window.set_client_inset(...)` çağrısı.
- Border ve gölge.
- Tiling durumuna göre köşe yuvarlama.
- Kenarlardan resize başlatma.
- İçerik alanında cursor propagation'ı kesme.

Bu sarmal olmadan titlebar görünür, fakat pencere kenarı/resize davranışı Zed ile
aynı olmaz.

**İstenen decoration ile gerçek decoration aynı kabul edilmemelidir.**
`WindowOptions.window_decorations` sadece istek değeridir; render sırasında
her zaman `window.window_decorations()` sonucu esas alınır. Kaynakta iki
platform farkı var:

- Wayland'da server-side decoration istenir ama compositor decoration
  protokolünü desteklemezse GPUI `WindowDecorations::Client`'a düşer
  (`gpui_linux/src/linux/wayland/window.rs:1469-1484`).
- X11'de client-side decoration istenir ama compositor desteği yoksa GPUI
  server-side decoration'a döner; `window_decorations()` da doğrudan
  `Decorations::Server` verir (`gpui_linux/src/linux/x11/window.rs:1742-1748`,
  `1818-1828`).

Bu yüzden `PlatformTitleBar::effective_button_layout(...)` ve
`render_left/right_window_controls(...)` doğru şekilde ayar değerine değil
**actual** `Decorations::Client` sonucuna bakar.

### 10. Uygulama katmanına önerilen model

Kendi uygulamanızda titlebar davranışını merkezi yönetmek için şu sözleşme yeterli
olur:

```rust
trait TitleBarController {
    fn close_action(&self) -> Box<dyn Action>;
    fn new_window_action(&self) -> Box<dyn Action>;
    fn button_layout(&self, cx: &App) -> Option<WindowButtonLayout>;
    fn sidebar_state(&self, cx: &App) -> ShellSidebarState;
    fn use_system_window_tabs(&self, cx: &App) -> bool;
}
```

Bu sözleşme sayesinde platform titlebar şu soruları uygulama state'ine sormuş
olur:

- Kapatma ne anlama geliyor?
- Yeni pencere nasıl açılıyor?
- Linux butonları hangi tarafta durmalı?
- Sidebar pencere kontrolleriyle çakışıyor mu?
- Native tabs açık mı?

Zed'in tasarımında güçlü olan nokta budur: platform titlebar, pencere kabuğunun
mekaniğini bilir; ürünün neyi kapatacağına, hangi menüyü açacağına veya hangi
workspace'i taşıyacağına üst uygulama katmanı karar verir. Kendi uygulamanızda da
bu ayrımı korumak, bileşeni büyüdükçe yönetilebilir tutar.


## Bölüm V — Platform titlebar render akışı ve pencere kontrolleri

Bu noktadan sonra başlık çubuğunun render davranışı, Linux/Windows/macOS farkları ve close/minimize/maximize bağları uygulanır.

### 11. Davranış modeli

#### Sürükleme

Ana titlebar yüzeyi `WindowControlArea::Drag` ile işaretlenir. Ayrıca sol mouse
down/move akışıyla `window.start_window_move()` çağırır. Bu kombinasyon,
platforma bağlı titlebar drag davranışının tutarlı işlemesini sağlar.

Başlık çubuğuna koyduğunuz interaktif elementler kendi mouse down/click
olaylarında propagation'ı durdurmalıdır. Aksi halde buton, arama kutusu veya
menü tıklaması pencere sürükleme davranışıyla çakışabilir.

`should_move` state'i dört noktada düzenlenir
(`platform_title_bar.rs:200-220`):

- `on_mouse_down(Left, ...)` → `should_move = true`.
- `on_mouse_move(...)` → eğer `should_move` true ise **önce** `false`'a
  çekilir, **sonra** `window.start_window_move()` çağrılır. Tek-atışlık
  tetikleyici; her yeni drag için yeni bir mouse_down zincirine ihtiyaç
  vardır.
- `on_mouse_up(Left, ...)` → `should_move = false` (drag başlatılmadıysa
  da temizle).
- `on_mouse_down_out(...)` → `should_move = false` (titlebar dışına
  tıklanırsa state sızıntısını önle).

Linux pencere kontrol katmanı **üç ayrı `stop_propagation()` noktası**
kullanır (awk taraması ile çıkarılır; rg dağınık satırları toplamaz):

| Yer | Olay | Kaynak | Neyi engeller? |
| :-- | :-- | :-- | :-- |
| `LinuxWindowControls` h_flex container | `on_mouse_down(Left)` | `platform_linux.rs:50` | Buton grubuna basıldığında titlebar drag başlamasını. |
| `WindowControl` (her buton) | `on_mouse_move` | `platform_linux.rs:228` | Buton üzerinde mouse gezerken titlebar drag tetiklenmesini. |
| `WindowControl` `on_click` callback gövdesi | `cx.stop_propagation()` ilk satır | `platform_linux.rs:230` | Click event'inin yukarı kabarıp başka handler'lara ulaşmasını. Action dispatch'inden ÖNCE çalışır. |

Üçü birden olmadan: (1) buton üstüne mouse_down ile drag başlar, (2)
buton hover'larken mouse_move drag tetikler, (3) close action dispatch
edilirken aynı click PlatformTitleBar'a kabarıp `should_move = true`
yapar. Port hedefinde aynı üç noktaya **eşdeğer engeller** koymak
gerekir.

Windows tarafında `.occlude()` (`platform_windows.rs:128`) aynı amaca
hizmet eder ama tek satırlık ifade: caption butonu üzerinde tüm mouse
event'leri alt katmanlara sızdırmaz.

#### Fullscreen render ayrımı

Fullscreen koşulu yalnız görünsel bir detay değildir; hangi child'ların
eklendiğini değiştirir (`platform_title_bar.rs:243-320`). `window.is_fullscreen()`
true ise sol tarafta macOS trafik ışığı padding'i de Linux sol kontrolleri de
eklenmez, sadece `.pl_2()` fallback'i kullanılır. Aynı render zincirinde sağ
taraf bloğu da `when(!window.is_fullscreen(), ...)` arkasındadır; yani sağ
caption kontrolleri ve Linux CSD sağ tık sistem pencere menüsü fullscreen'de
kurulmaz. `SystemWindowTabs` child'ı ise bu koşulun dışında, titlebar'ın
altına eklenmeye devam eder (`platform_title_bar.rs:322-325`).

Port hedefinde bu ayrımı tek bir "fullscreen padding'i değiştir" kuralına
indirgemeyin: fullscreen, hem sol/sağ pencere kontrol render'ını hem de Linux
CSD `window.show_window_menu(...)` bağını etkiler.

#### Çift tıklama

Platform farkı Zed kaynağında ayrı işlenir:

- macOS: `window.titlebar_double_click()`
- Linux/FreeBSD: `window.zoom_window()`
- Windows: davranış platform caption/hit-test katmanına bırakılır.

Kendi uygulamanızda çift tıklamanın maximize yerine minimize gibi farklı bir
ayar izlemesini istiyorsanız bu bölüm parametreleştirilmelidir.

macOS tarafında `window.titlebar_double_click()` sabit "zoom" değildir.
`gpui_macos` platform impl'i `NSGlobalDomain/AppleActionOnDoubleClick`
değerini okur; `"None"` için hiçbir şey yapmaz, `"Minimize"` için
`miniaturize_`, `"Maximize"` ve `"Fill"` için `zoom_`, bilinmeyen değer
için de `zoom_` çağırır (`gpui_macos/src/window.rs:1668-1712`). Linux
tarafındaki `window.zoom_window()` çağrısı ise bu macOS kullanıcı ayarını
taklit etmez; doğrudan maximize/restore davranışıdır.

#### Renk

`title_bar_color` Linux/FreeBSD tarafında aktif pencere için
`title_bar_background`, pasif veya move sırasında `title_bar_inactive_background`
kullanır. Diğer platformlarda doğrudan `title_bar_background` döner.

Bu davranış, başlık çubuğu ve sekme çubuğu arasında görsel ayrımı korur. Kendi
tema sisteminizde en az şu token'lar gerekir (awk
`cx\.theme\(\)\.colors\(\)\.X` taramasının tam çıktısı):

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

Son iki token, üzerine başka bir sekme sürüklendiğinde drop hedefini
vurgulamak için kullanılır; tema'da eksik kalırsa drag-and-drop görsel
geri-besleme çalışmaz.

#### Yükseklik

Zed `platform_title_bar_height(window)` kullanır:

- Windows: sabit `32px`.
- Diğer platformlar: `1.75 * rem_size`, minimum `34px`.

Bu değer hem titlebar hem Windows buton yüksekliği hem de bazı yardımcı
başlıkların hizalaması için ortak kullanılmalıdır.

### 12. Buton yerleşimi ve ayar yönetimi

Linux/FreeBSD CSD tarafında buton sırası `WindowButtonLayout` ile belirlenir.
GPUI tipi iki sabit slot dizisi taşır:

```rust
pub struct WindowButtonLayout {
    pub left: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE],
    pub right: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE],
}
```

`WindowButton` değerleri:

- `Minimize`
- `Maximize`
- `Close`

GPUI tarafındaki `WindowButton` da dış API'dir
(`gpui/src/platform.rs:425-444`): `#[derive(Debug, Clone, Copy, PartialEq,
Eq, Hash)]` taşır ve `pub fn id(&self) -> &'static str` ile sırasıyla
`"minimize"`, `"maximize"`, `"close"` stable element id'lerini döndürür.
Bu id'ler Linux `WindowControl::new(...)` çağrılarında doğrudan kullanıldığı
için port hedefinde key/id uyumu korunmalıdır.

`WindowButtonLayout` üç public öğe ile gelir (`gpui/src/platform.rs:457-486`):

| Öğe | İmza / değer | Davranış notu |
| :-- | :-- | :-- |
| `MAX_BUTTONS_PER_SIDE` | `pub const MAX_BUTTONS_PER_SIDE: usize = 3` | Her taraf en fazla üç slot tutar. |
| `WindowButtonLayout::linux_default` | `pub fn linux_default() -> Self` | Sol taraf boş, sağ taraf `Minimize, Maximize, Close`. Yalnız Linux/FreeBSD cfg'inde derlenir. |
| `WindowButtonLayout::parse` | `pub fn parse(layout_string: &str) -> Result<Self>` | GNOME tarzı `left:right` string'i okur; `:` yoksa sol boş, tüm string sağ taraf sayılır. |

`parse(...)` davranışının iki ince noktası var (`gpui/src/platform.rs:486-541`):
tanınmayan adlar, en az bir geçerli buton varsa **yok sayılır**; tüm string
geçersizse hata döner. Aynı buton iki tarafta veya aynı tarafta tekrar edilirse
ilk görülen slot tutulur, tekrarlar atlanır. Bu nedenle `"close,foo"` geçerli
layout üretir, `"foo"` hata verir.

Render tarafında side'ın varlığı yalnız ilk slota bakılarak belirlenir:
`render_left_window_controls(...)` için `button_layout.left[0].is_none()`,
`render_right_window_controls(...)` için `button_layout.right[0].is_none()`
ise tüm taraf `None` döner (`platform_title_bar.rs:132-135`, `163-166`).
Manuel layout verirken `[None, Some(Close), ...]` gibi bir dizi o tarafı
tamamen gizler. İlk slot doluysa içerdeki sonraki `None` slotlar
`LinuxWindowControls` render'ındaki `filter_map(|b| *b)` ile sadece atlanır
(`platform_linux.rs:31-34`).

Zed ayar katmanı üç kullanım biçimi sunar:

| Ayar değeri | Sonuç |
| :-- | :-- |
| `platform_default` | Platform/desktop config takip edilir; `cx.button_layout()` fallback'i kullanılır. |
| `standard` | Zed Linux fallback'i: sağda minimize, maximize, close. |
| GNOME formatında string | Örneğin `"close:minimize,maximize"` veya `"close,minimize,maximize:"`. |

Uygulama katmanında bu ayarı saklamak istiyorsanız kullanıcı ayarınızı önce
`WindowButtonLayout` karşılığına çevirin, sonra render sırasında
`title_bar.set_button_layout(layout)` çağırın.

Zed `TitleBar` bu değişimi `cx.observe_button_layout_changed(window, ...)` ile
izleyip yeniden render tetikler. Kendi uygulamanızda desktop button layout
değişikliklerini canlı izlemek istiyorsanız aynı observer desenini kullanın.

**`Platform::button_layout()` trait default'u `None` döndürür**
(`gpui/src/platform.rs:162-164`); bu default'u **yalnızca Linux/FreeBSD
platform impl'i** override edip GTK / GNOME desktop ayarını (örn.
`gtk-decoration-layout`) okur. Yani `cx.button_layout()` çağrısı
Windows ve macOS'ta daima `None`'dur. `PlatformTitleBar::effective_button_layout(...)`
de zaten Linux + `Decorations::Client` dışındaki kombinasyonlarda
`None` döndürür (`platform_title_bar.rs:86-98`). Sonuç: button layout
ayar zinciri yalnızca Linux/FreeBSD CSD penceresinde anlamlıdır;
diğer platformlarda `set_button_layout(...)` etkisizdir.

Linux tarafında bu değer `gpui_linux` ortak state'inde başta
`WindowButtonLayout::linux_default()` olarak tutulur
(`gpui_linux/src/linux/platform.rs:143-150`) ve `Platform::button_layout()`
bu common state'i `Some(...)` olarak döndürür (`gpui_linux/src/linux/platform.rs:619-620`).
Canlı desktop değişimi XDP `ButtonLayout` olayıyla gelir: Wayland ve X11
client'ları gelen string'i `WindowButtonLayout::parse(...)` ile okur,
parse hata verirse yine `linux_default()`'a düşer, sonra her pencere için
`window.set_button_layout()` çağırır (`gpui_linux/src/linux/wayland/client.rs:636-645`,
`gpui_linux/src/linux/x11/client.rs:493-500`). Bu çağrı da
`on_button_layout_changed` callback'ini tetikler; Zed `TitleBar::new(...)`
içinde bu callback'i `cx.observe_button_layout_changed(window, ...)` ile
`cx.notify()`'a bağlar (`title_bar/src/title_bar.rs:441`).

### 13. Butonları uygulama katmanına bağlama

#### Close davranışı

`PlatformTitleBar` kendi render'ında close action'ı şu şekilde sabitler:

```rust
let close_action = Box::new(workspace::CloseWindow);
```

Bu yüzden kendi uygulamanızda close butonunun farklı bir varlığı kapatmasını
istiyorsanız üç seçenek vardır:

1. `PlatformTitleBar`'ı port edip `close_action` alanı ekleyin.
2. Zed'in serbest fonksiyonlarını kullanıp `render_left_window_controls` ve
   `render_right_window_controls` çağrılarına kendi `Box<dyn Action>` değerinizi
   verin.
3. Linux butonlarını doğrudan `LinuxWindowControls::new(...)` ile üretip close
   action'ı orada verin.

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

Close action'ının ne kapatacağı uygulama modelinize göre belirlenmelidir:

| Uygulama varlığı | Close action anlamı |
| :-- | :-- |
| Tek pencereli app | Pencereyi kapat veya quit on last window politikasını işlet. |
| Workspace tabanlı app | Aktif workspace'i kapat, son workspace ise pencereyi kapat. |
| Doküman tabanlı app | Aktif dokümanı kapat, kirli state varsa kaydetme modalı aç. |
| Çok hesaplı/dashboard app | Aktif tenant veya view değil, pencere/shell lifecycle'ını kapat. |

#### Minimize ve maximize

Linux `WindowControl` minimize ve maximize işlemlerini doğrudan `Window` üstünden
yapar:

- `window.minimize_window()`
- `window.zoom_window()`

Bu butonlar uygulama action katmanına uğramaz. Eğer maximize/minimize öncesi
telemetry, policy veya layout persist istiyorsanız `WindowControl`'ü port edip
bu işlemleri kendi action'ınıza yönlendirin.

Windows tarafında butonlar click handler ile pencere fonksiyonu çağırmaz.
`WindowControlArea::{Min, Max, Close}` hit-test alanı üretir; platform katmanı
native caption davranışını uygular. Bu yüzden Windows buton davranışını action
katmanına almak Linux'e göre daha fazla platform uyarlaması gerektirir.

`window.window_controls()` capability yüzeyi de platforma göre değişebilir.
**`WindowControls` struct'ı dört alan taşır** (`gpui/src/platform.rs:402-413`):
`fullscreen`, `maximize`, `minimize`, `window_menu` — `close` alanı **yoktur**.
Bu, "close her zaman desteklenir" tasarım kararıdır ve `LinuxWindowControls`
filter'ındaki koşulsuz `WindowButton::Close => true` arm'ı bu yüzden gerekir
(`platform_linux.rs:38`). `platform_title_bar` crate'inin gerçekten okuduğu
capability'ler: `minimize`, `maximize` (Linux buton filtresi),
`window_menu` (sağ tık window menu); `fullscreen` ise bu crate içinde okunmaz.
Trait default'u "her şey destekleniyor" kabul eder (`WindowControls::default`,
`gpui/src/platform.rs:413-422`), fakat Wayland `xdg_toplevel::Event::WmCapabilities`
geldiğinde önce tüm bayrakları `false` yapar, sonra compositor'ın bildirdiği
`Maximize`, `Minimize`, `Fullscreen`, `WindowMenu` capability'lerini tek tek
`true` yapar (`gpui_linux/src/linux/wayland/window.rs:788-817`). Bu değer
sonraki configure'da `state.window_controls` içine alınır ve appearance
callback'iyle rerender tetiklenir (`gpui_linux/src/linux/wayland/window.rs:601-612`).
Sonuç:

- `LinuxWindowControls` minimize/maximize butonlarını bu capability'ye göre
  filtreler; close her zaman render edilebilir (`platform_linux.rs:30-39`).
- Linux CSD titlebar sağ tık window menu handler'ı sadece
  `supported_controls.window_menu` true ise eklenir (`platform_title_bar.rs:309-315`).
- Port ederken `WindowControls::default()` değerini kalıcı gerçek sanma;
  özellikle Wayland'da capability configure olayı geldikten sonra değişebilir.


---

## Bölüm VI — Native pencere sekmeleri

Native tab desteğini ayrı bir aşama olarak ele al; controller state'i, platform çağrıları ve drag/drop hedefleri birlikte düşünülür.

### 14. System window tabs

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

#### Sekme butonları

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


## Bölüm VII — Ürün titlebar'ı ve uygulamaya bağlama

Platform kabuğu hazır olunca ürün başlığı, sidebar bilgisi, menüler ve uygulama shell'i bu kabuğa bağlanır.

### 15. Sidebar ve workspace etkileşimi

`PlatformTitleBar`, `MultiWorkspace` zayıf referansı alabiliyor. Bunun tek amacı
başlık çubuğundaki pencere kontrollerinin sidebar ile çakışmasını önlemek:

- Sol sidebar açıksa sol pencere kontrolleri gizlenir.
- Sağ sidebar açıksa sağ pencere kontrolleri gizlenir.
- CSD köşe yuvarlama sidebar tarafında kapatılır.

Zed'de bu bilgi `SidebarRenderState { open, side }` ile gelir. Kendi
uygulamanızda sol/sağ panel varsa aynı soyutlamayı daha küçük bir tipe
indirgemek yeterlidir:

```rust
#[derive(Default, Clone, Copy)]
struct ShellSidebarState {
    open: bool,
    side: SidebarSide,
}
```

Eğer sidebar yoksa bu alanı tamamen kaldırabilir veya daima default state
döndürebilirsiniz.

`PlatformTitleBar::is_multi_workspace_enabled(cx)` Zed'de
`DisableAiSettings` üzerinden döner. Bu isim uygulama dışı görünse de davranış
aslında feature flag'dir. Kendi uygulamanızda bunu `AppSettings::multi_workspace`
veya `ShellSettings::sidebar_enabled` gibi doğrudan isimlendirilmiş bir ayarla
değiştirin.

Zed'in ürün modelinde klasör ve projeler varsayılan olarak yeni pencere açmak
yerine mevcut pencerenin threads sidebar'ına eklenebilir. `File > Open`,
`File > Open Recent`, klasör sürükleme ve `zed ~/project` davranışı aynı pencere
içinde workspace değiştirebilir; yeni pencere için Open Recent'ta Cmd/Ctrl+Enter
veya CLI tarafında `zed -n` kullanılır. `cli_default_open_behavior` varsayılanı
`existing_window` ise CLI açılışları da mevcut pencere/sidebar yolunu izler.

Bu durum `PlatformTitleBar` render sözleşmesini değiştirmez: zayıf
`MultiWorkspace` referansı platform kabuğunda sadece sidebar tarafındaki pencere
kontrolü çakışmasını çözmek için okunur. Ürün titlebar'ı için kural şudur:
aktif proje/workspace değişimi pencere değişmeden gerçekleşebilir. Proje adı,
worktree bilgisi, sidebar tarafı ve başlık içeriği `Window` lifecycle'ına değil
aktif `MultiWorkspace::workspace()` durumuna gözlemci bağlayarak güncellenmelidir.

Sidebar açık mı sorusunu "açık proje var mı" sorusundan ayrı tutun. Boş
workspace'lerde yeni thread/terminal oluşturma no-op olabilir; buna rağmen
sidebar'ın açık/kapalı ve sol/sağ konumu titlebar kontrol çakışması için ayrı
bir render state'tir.

### 16. Başlık çubuğuna içerik yerleştirme

`PlatformTitleBar` kendi başına sadece platform kabuğunu sağlar. Zed'in gerçek
ürün başlığı `crates/title_bar/src/title_bar.rs` içindeki `TitleBar` tarafından
oluşturulur. Bu katman şunları child olarak verir:

- Uygulama menüsü.
- Proje adı / recent projects popover.
- Git branch adı ve durum ikonu.
- Restricted mode göstergesi.
- Kullanıcı menüsü, sign-in butonu, plan chip, update bildirimi.
- Collab/screen share göstergeleri.
- Feature flag'e bağlı onboarding/announcement banner'ları.
- Update bildirimi tooltip'i (`Update to Version: ...` gibi).

Update tooltip'inin biçimi `crates/title_bar/src/update_version.rs:66-75`
içindeki `version_tooltip_message` fonksiyonunda kurulur. Sürüm semantik ise
`SemanticVersion::to_string()` çıktısı; commit SHA ise `AppCommitSha::full()`
ile kısaltılmamış 40 karakterlik hash döner (önceki "`14d9a41…`" tarzı kısa
gösterim kaldırılmıştır). Tooltip metni her durumda `"Update to Version:"`
ön ekiyle başlar. Portta tooltip kabuğu için bu uzun string'in tek satıra
sığacağı varsayılmamalıdır; `Tooltip::text` veya muadili genişlik sınırı
düşünülmelidir.

Kendi uygulamanızda aynı pattern'i kullanın: platform titlebar'ı shell olarak
tutun, ürününüzün anlamlı varlıklarını üst seviye `AppTitleBar` veya
`ShellTitleBar` entity'sinde üretin.

Önerilen ayrım:

| Katman | Sorumluluk |
| :-- | :-- |
| `PlatformTitleBar` | Platform davranışı, drag alanı, pencere kontrolleri, native tabs. |
| `AppTitleBar` | Uygulama adı, aktif workspace/doküman, menüler, kullanıcı aksiyonları. |
| `AppShell` | Pencere layout'u, CSD sarmalı, titlebar + içerik kompozisyonu. |
| `AppState` | Workspace, doküman, user session, ayar ve lifecycle action'ları. |

Başlık çubuğu içeriğinde `justify_between` kullanıldığı için çocukları sol,
orta ve sağ grup olarak vermek pratik olur:

```rust
let children = [
    h_flex()
        .id("title-left")
        .gap_2()
        .child(app_menu)
        .child(project_picker)
        .into_any_element(),
    h_flex()
        .id("title-right")
        .gap_1()
        .child(sync_status)
        .child(user_menu)
        .into_any_element(),
];

self.platform_titlebar.update(cx, |title_bar, _| {
    title_bar.set_children(children);
});
```

Interaktif child'larda dikkat edilecekler:

- Butonlar ve popover tetikleyicileri click/mouse down propagation'ını
  durdurmalıdır.
- Uzun metinler `truncate()` veya sabit `max_w(...)` ile sınırlandırılmalıdır.
- Sağ tarafta platform pencere butonları olabileceği için ürün butonlarınızın
  sağ padding ve flex shrink davranışını test edin.
- Fullscreen modunda native pencere kontrolleri değişebileceği için macOS ve
  Windows davranışını ayrı kontrol edin.

### 17. Kendi uygulamana dahil etme

#### Doğrudan Zed crate'iyle kullanım

Zed workspace crate'leri, settings kayıtları ve tema altyapısı uygulamanızda
zaten varsa entegrasyon iskeleti şöyledir. Bu yol, Zed'in uygulama başlangıç
kurulumuna yakın bir ortam bekler; bağımsız GPUI uygulamalarında port yaklaşımı
daha uygundur.

```rust
use gpui::{App, Context, Entity, Render, Window, div};
use platform_title_bar::PlatformTitleBar;
use ui::prelude::*;

pub fn init(cx: &mut App) {
    PlatformTitleBar::init(cx);
}

pub struct AppShell {
    title_bar: Entity<PlatformTitleBar>,
}

impl AppShell {
    pub fn new(cx: &mut Context<Self>) -> Self {
        Self {
            title_bar: cx.new(|cx| PlatformTitleBar::new("app-title-bar", cx)),
        }
    }
}

impl Render for AppShell {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let title = div()
            .id("title")
            .text_sm()
            .child("My GPUI App")
            .into_any_element();

        self.title_bar.update(cx, |title_bar, _| {
            title_bar.set_children([title]);
        });

        v_flex()
            .size_full()
            .child(self.title_bar.clone())
            .child(div().id("content").flex_1())
    }
}
```

Bu örnekte `set_children` render içinde çağrılır. Bunun nedeni, Zed kaynağında
child listesinin render sırasında tüketilmesidir. Entity oluşturulurken bir kez
child vermek yeterli değildir.

#### Bağımsız GPUI uygulamasına port

Zed dışındaki uygulamalarda doğrudan crate bağımlılığı genellikle ağırdır.
Port ederken şu değişimleri yapın:

| Zed bağımlılığı | Port karşılığı |
| :-- | :-- |
| `workspace::CloseWindow` | Uygulamanızın `CloseWindow`, `CloseDocument`, `CloseProject` veya `QuitRequested` action'ı. |
| `zed_actions::OpenRecent { create_new_window: true }` | Uygulamanızın `NewWindow` veya `OpenWorkspace` action'ı. |
| `WorkspaceSettings::use_system_window_tabs` | Uygulama ayarınızdaki native tab seçeneği. |
| `ItemSettings::{close_position, show_close_button}` | Sekme kapatma butonu konumu ve görünürlüğü için kendi ayar tipiniz. |
| `MultiWorkspace` ve `SidebarRenderState` | Sol/sağ panel açık mı bilgisini veren kendi shell state'iniz. |
| `DisableAiSettings` | Multi workspace veya sidebar davranışını açıp kapatan kendi feature flag'iniz. |
| `cx.theme().colors().title_bar_background` | Kendi tema sisteminizdeki titlebar token'ı. |

Pratik port sınırı:

- `platform_title_bar.rs` içinden Zed workspace bağımlılıklarını çıkarın.
- `system_window_tabs.rs` içindeki action ve settings kullanımlarını kendi
  action/settings tiplerinizle değiştirin veya native tab desteğini ilk sürümde
  tamamen kapatın.
- `platforms/platform_linux.rs` ve `platforms/platform_windows.rs` daha taşınabilir
  parçalardır; çoğu uygulamada daha az değişiklik ister.

---

## Bölüm VIII — Pratik uygulama

Uygulama sırasında değiştirilecek noktaları, platform kontrol listelerini ve sık hataları en sona yakın topla.

### 18. Özelleştirme noktaları

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Close butonu farklı action dispatch etsin | `PlatformTitleBar` içine `close_action` alanı ekle veya serbest render fonksiyonlarını kullan. |
| Linux buton sırası ayardan gelsin | `set_button_layout(...)` çağrısını uygulama settings state'ine bağla. |
| Linux buton ikon/rengi değişsin | `WindowControlStyle` veya `WindowControlType::icon()` portunda değişiklik yap. |
| Windows close hover rengi değişsin | `platform_windows.rs` içindeki `WindowsCaptionButton::Close` (crate-içi enum) renklerini değiştir; tip pub değildir, port hedefinde aynı dört variantı kendi enum'unuzla yeniden yazın. |
| Titlebar yüksekliği değişsin | `platform_title_bar_height` karşılığını uygulamana taşı ve tüm titlebar/controls kullanımında aynı değeri kullan. |
| Native tabs kapatılsın | `SystemWindowTabs` render child'ını feature flag ile boş döndür. |
| Sekme plus butonu yeni pencere açsın | `zed_actions::OpenRecent` yerine uygulama `NewWindow` action'ını dispatch et. |
| Sidebar açıkken kontroller gizlenmesin | `sidebar_render_state` ve `show_left/right_controls` koşullarını değiştir. |
| Sağ tık window menu kapatılsın | Linux CSD `window.show_window_menu(ev.position)` bağını kaldır veya ayara bağla. |
| Çift tıklama maximize yerine özel action olsun | Platform click handler'larını kendi action'ına yönlendir. |

### 19. Kontrol listesi

#### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında bir kez çağrılıyor.
- Pencere `WindowOptions.titlebar` değerini transparent titlebar ile açıyor.
- Linux CSD gerekiyorsa `WindowDecorations::Client` isteniyor.
- CSD kullanılıyorsa pencere gölge/border/resize sarmalı ayrıca uygulanıyor.
- Titlebar child'ları her render geçişinde `set_children(...)` ile yenileniyor.
- İnteraktif titlebar child'ları drag propagation ile çakışmıyor.
- Tema token'ları aktif, pasif ve hover durumlarını kapsıyor.

#### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı ile `WindowButtonLayout` geliyor.
- Sol ve sağ buton dizilerinde boş slotlar doğru davranıyor.
- Desktop layout değişince titlebar yeniden render oluyor.
- `window.window_controls()` minimize/maximize desteğini doğru filtreliyor.
- Sağ tık sistem pencere menüsü istenen ürün davranışıyla uyumlu.

#### Windows

- Caption button alanları `WindowControlArea::{Min, Max, Close}` olarak kalıyor.
- Sağdaki ürün butonları caption button hitbox'larıyla çakışmıyor.
- `platform_title_bar_height` Windows için `32px` varsayımını koruyor veya bilinçli
  değiştiriliyor.
- Close hover rengi tema politikanızla uyumlu.

#### macOS

- Trafik ışıkları için sol padding korunuyor.
- `traffic_light_position` ile titlebar child'ları çakışmıyor.
- Fullscreen ve native tabs davranışı ayrıca test ediliyor.
- Çift tıklama sistem davranışına mı, özel davranışa mı gidecek netleştiriliyor.

#### Native tabs

- `tabbing_identifier` tüm ilgili pencerelerde aynı.
- Sekme kapatma action'ı kirli doküman/workspace state'ini kontrol ediyor.
- Sekmeyi yeni pencereye alma uygulama state'ini doğru taşıyor.
- Plus butonu doğru yeni pencere/workspace action'ını dispatch ediyor.
- Sağ tık menü metinleri ve action'ları ürün diline uyarlanıyor.

### 20. Sık yapılan hatalar

- `PlatformTitleBar` child'larını yalnızca constructor'da vermek. Zed child'ları
  render sırasında tükettiği için içerik sonraki render'da kaybolur.
- Linux CSD butonlarını gösterip pencere resize/border sarmalını uygulamamak.
  Başlık çubuğu çalışır, fakat pencere kenarı native hissettirmez.
- Close butonunu uygulama lifecycle'ına bağlamadan doğrudan pencere kapatmak.
  Kirli doküman, background task veya workspace cleanup adımları atlanabilir.
- Windows butonlarını Linux gibi click handler ile yönetmeye çalışmak. Windows
  implementation hit-test alanı verir; davranış platform katmanındadır.
- Native tabs açıkken `tabbing_identifier` vermemek. Pencereler aynı native tab
  grubunda birleşmez.
- `DraggedWindowTab` payload'ını sadece alan listesi olarak mirror etmek.
  Aynı tab bar drop'u reorder yapar; tab bar dışına bırakma yeni pencereye taşır;
  merge ise ayrı action/context menu akışıdır.
- `SystemWindowTabController` state'i ile platform native tab state'ini tek
  kaynak sanmak. Controller Zed tarafındaki UI/action modelidir; platform çağrıları
  (`window.move_tab_to_new_window`, `window.merge_all_windows`) ayrıca yapılır.
- App-specific menüleri `PlatformTitleBar` içine gömmek. Daha temiz model,
  platform kabuğunu ayrı, ürün titlebar içeriğini ayrı tutmaktır.


## Bölüm IX — Referans ve doğrulama

Detaylı public API envanteri ve kaynak doğrulama komutları, okuma akışını bölmemesi için başvuru bölümünde kalır.

### 21. Public API envanteri

Bu bölümde `pub` iki anlama ayrılır:

- **Dış API:** Başka crate'lerin path üzerinden erişebildiği yüzey.
- **Lexical `pub`:** Kaynakta `pub` yazsa da private bir modülün içinde kaldığı
  için yalnızca crate içinde kullanılabilen yüzey.

`system_window_tabs.rs` içindeki `SystemWindowTabs` dış API değildir. Tip
kaynakta `pub struct` olarak yazılmıştır, fakat modülü crate kökünde
`mod system_window_tabs;` olarak private kaldığı için dışarıdan
`platform_title_bar::system_window_tabs::SystemWindowTabs` path'iyle erişilemez.
Dışa açılan parça yalnızca root'taki `pub use system_window_tabs::{...}`
satırlarıdır (`platform_title_bar.rs:24-26`).

#### Crate kökü (`platform_title_bar`)

| Dış API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `pub mod platforms` | `platform_title_bar.rs:1` | `platform_title_bar::platforms::{platform_linux, platform_windows}` path'ini açar. **Cfg-gate yoktur**: `platforms.rs` her iki alt modülü de koşulsuz `pub mod` ile expose eder (`platforms.rs:1-2`). Yani Windows derlemesinde dahi `platform_title_bar::platforms::platform_linux::LinuxWindowControls` derlenir; runtime seçimi `PlatformStyle::platform()` ile yapılır. |
| `pub use system_window_tabs::{...}` | `DraggedWindowTab`, `MergeAllWindows`, `MoveTabToNewWindow`, `ShowNextWindowTab`, `ShowPreviousWindowTab` (`platform_title_bar.rs:24-26`) | `SystemWindowTabs` re-export edilmez. |
| `pub struct PlatformTitleBar` | Private alanlar: `id: ElementId`, `platform_style: PlatformStyle`, `children: SmallVec<[AnyElement; 2]>`, `should_move: bool`, `system_window_tabs: Entity<SystemWindowTabs>` (**strong**), `button_layout: Option<WindowButtonLayout>`, `multi_workspace: Option<WeakEntity<MultiWorkspace>>` (**weak**) (`platform_title_bar.rs:28-36`) | Alanlara dışarıdan erişim yok. **Ownership farkı**: `system_window_tabs` strong `Entity` — titlebar tabs alt-entity'yi sahiplenir ve drop edildiğinde onu da sürükler. `multi_workspace` weak — workspace bağımsız yaşar; titlebar sadece gözlemler. Aksini yapmak (workspace'i strong tutmak) **ownership cycle** üretir. |
| `PlatformTitleBar::new` | `pub fn new(id: impl Into<ElementId>, cx: &mut Context<Self>) -> Self` (`platform_title_bar.rs:39`) | `SystemWindowTabs::new()` ile internal tab entity oluşturur. |
| `with_multi_workspace` | `pub fn with_multi_workspace(mut self, multi_workspace: WeakEntity<MultiWorkspace>) -> Self` (`platform_title_bar.rs:54`) | Builder tarzı ilk bağlantı. |
| `set_multi_workspace` | `pub fn set_multi_workspace(&mut self, multi_workspace: WeakEntity<MultiWorkspace>)` (`platform_title_bar.rs:59`) | Sonradan sidebar state kaynağı bağlar. |
| `title_bar_color` | `pub fn title_bar_color(&self, window: &mut Window, cx: &mut Context<Self>) -> Hsla` (`platform_title_bar.rs:63`) | Linux/FreeBSD'de aktif/pasif ve move state'ine bakar; diğer platformlarda active/inactive ayrımı yapmaz. |
| `set_children` | `pub fn set_children<T>(&mut self, children: T) where T: IntoIterator<Item = AnyElement>` (`platform_title_bar.rs:75-77`) | Render'da `mem::take` ile tüketildiği için her render'da tekrar çağrılır. |
| `set_button_layout` | `pub fn set_button_layout(&mut self, button_layout: Option<WindowButtonLayout>)` (`platform_title_bar.rs:82`) | Sadece Linux + `Decorations::Client` olduğunda `effective_button_layout` tarafından kullanılır. |
| `PlatformTitleBar::init` | `pub fn init(cx: &mut App)` (`platform_title_bar.rs:100`) | Internal `SystemWindowTabs::init(cx)` çağrısıdır. |
| `is_multi_workspace_enabled` | `pub fn is_multi_workspace_enabled(cx: &App) -> bool` (`platform_title_bar.rs:112`) | Zed'de `DisableAiSettings` tersine bağlı feature flag. |
| `render_left_window_controls` | `pub fn render_left_window_controls(button_layout: Option<WindowButtonLayout>, close_action: Box<dyn Action>, window: &Window) -> Option<AnyElement>` (`platform_title_bar.rs:121-125`) | Yalnız Linux/FreeBSD + CSD; `button_layout.left[0]` boşsa `None`. |
| `render_right_window_controls` | `pub fn render_right_window_controls(button_layout: Option<WindowButtonLayout>, close_action: Box<dyn Action>, window: &Window) -> Option<AnyElement>` (`platform_title_bar.rs:150-154`) | Linux/FreeBSD + CSD'de layout kullanır, Windows'ta `WindowsWindowControls::new(height)`, macOS'ta `None`. |

`PlatformTitleBar` render davranışı API imzasından daha önemlidir:

- `close_action` kaynakta sabit `Box::new(workspace::CloseWindow)` olarak
  oluşturulur (`platform_title_bar.rs:189`). Serbest render fonksiyonları ise
  dışarıdan `Box<dyn Action>` alır.
- `button_layout` private helper `effective_button_layout(...)` ile sadece
  Linux + CSD durumunda `self.button_layout.or_else(|| cx.button_layout())`
  olarak çözülür (`platform_title_bar.rs:86-98`).
- Ana yüzey `WindowControlArea::Drag` alır (`platform_title_bar.rs:195-197`);
  macOS çift tıklamada `titlebar_double_click`, Linux/FreeBSD çift tıklamada
  `zoom_window` çağırır (`platform_title_bar.rs:225-237`).
- Sol/sağ sidebar açıksa ilgili taraftaki pencere kontrolleri gizlenir
  (`platform_title_bar.rs:241-257`, `294-307`).
- Linux CSD + `supported_controls.window_menu` varsa sağ tıkta
  `window.show_window_menu(ev.position)` çağrılır (`platform_title_bar.rs:309-315`).
- CSD render'ında titlebar kendi üst köşelerini de düzeltir: tiled olmayan ve
  sidebar tarafından kapatılmayan üst köşelere
  `theme::CLIENT_SIDE_DECORATION_ROUNDING` uygulanır, sonra transparent köşe
  boşluğunu kapatmak için `.mt(px(-1.)).mb(px(-1.)).border(px(1.))` ve
  `border_color(titlebar_color)` eklenir (`platform_title_bar.rs:262-279`).
- En sonda internal `SystemWindowTabs` child olarak eklenir
  (`platform_title_bar.rs:322-325`).

**Render pipeline sıralaması** (awk `.map(\|this\|` taraması, `render`
gövdesinde dört ardışık dönüşüm aşaması açığa çıkarır):

| Aşama | Yer | İş |
| :-- | :-- | :-- |
| 1 | `platform_title_bar.rs:199-221` | **Drag tespiti**: `on_mouse_down/up/down_out/move` zincirinin `should_move` bayrağıyla `window.start_window_move()` tetiklemesi. Bu aşama her zaman ilk uygulanır; sonraki stage'ler bu state'in üstüne kurulur. |
| 2 | `platform_title_bar.rs:222-239` | **ID + çift tıklama**: `this.id(self.id.clone())` + Mac/Linux platform branch'leri `on_click`'i `event.click_count() == 2` kontrolüyle `titlebar_double_click` / `zoom_window`'a yönlendirir. Windows branch'i yoktur. |
| 3 | `platform_title_bar.rs:240-261` | **Sol kenar padding/kontrolleri**: 4-yollu seçim — fullscreen ise `pl_2`, Mac + show_left_controls ise `pl(TRAFFIC_LIGHT_PADDING)`, Linux + CSD + dolu sol layout ise `render_left_window_controls(...)` child, aksi halde `pl_2` fallback. |
| 4 | `platform_title_bar.rs:262-280` | **Decorations branch**: `match decorations` — `Server` ise `el` olduğu gibi; `Client { tiling, .. }` ise tiled olmayan üst köşelere `rounded_tr/tl(CLIENT_SIDE_DECORATION_ROUNDING)` + `mt(-1)/mb(-1)/border(1)` transparent gap düzeltmesi. |

Bu zincirden sonra `.bg(titlebar_color).content_stretch().child(div().children(children))`
gelir (ana içerik), sonra `.when(!is_fullscreen, |title_bar| ...)` zinciri
sağ kontroller ve window_menu sağ-tık handler'ını ekler. Stage'ler
**commutative değildir**: stage 3'teki sol padding seçimi, stage 4'teki
corner rounding'in yatay hizalamasını etkiler.

`PlatformTitleBar.children` alanı `SmallVec<[AnyElement; 2]>` tipindedir
(`platform_title_bar.rs:31`). İki element için stack-inline kapasite
ayrılmış — Zed'in tipik kullanım kalıbı **sol grup + sağ grup**
şeklindedir (bkz. bu rehberin Konu 16 örneği). İkiden fazla element
verirseniz heap allocate edilir; iki gruba sıkıştırmak hem ergonomik
hem alokasyon-az'dır.

#### `platforms::platform_linux`

| Dış API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `LinuxWindowControls` | `pub struct LinuxWindowControls` private alanlı (`platform_linux.rs:7-11`) | `#[derive(IntoElement)]`; dışarıdan alan set edilemez. |
| `LinuxWindowControls::new` | `pub fn new(id: &'static str, buttons: [Option<WindowButton>; MAX_BUTTONS_PER_SIDE], close_action: Box<dyn Action>) -> Self` (`platform_linux.rs:14-18`) | Layout slotlarını ve close action'ı saklar. Render'da `WindowControls` capability'sine göre minimize/maximize filtrelenir, **`WindowButton::Close => true` arm'ı koşulsuzdur** (`platform_linux.rs:35-39`); `supported_controls.close` false olsa bile close butonu render edilir. |
| `WindowControlType` | `pub enum WindowControlType { Minimize, Restore, Maximize, Close }` (`platform_linux.rs:84-90`) | Variant sırası kaynakta `Minimize, Restore, Maximize, Close`; `WindowButton::Maximize` runtime'da pencere maximized ise `Restore` ikonuna çevrilir. |
| `WindowControlType::icon` | `pub fn icon(&self) -> IconName` (`platform_linux.rs:97`) | `GenericMinimize`, `GenericRestore`, `GenericMaximize`, `GenericClose` döner. |
| `WindowControlStyle` | `pub struct WindowControlStyle` private alanlı (`platform_linux.rs:107-113`) | Alanlar public değildir; sadece builder yüzeyi var. |
| `WindowControlStyle::default` | `pub fn default(cx: &mut App) -> Self` (`platform_linux.rs:116`) | `Default` trait impl'i değildir; argümansız `WindowControlStyle::default()` derlenmez. |
| `background` | `pub fn background(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:129`) | Builder. |
| `background_hover` | `pub fn background_hover(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:136`) | Builder. |
| `icon` | `pub fn icon(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:143`) | Builder. |
| `icon_hover` | `pub fn icon_hover(mut self, color: impl Into<Hsla>) -> Self` (`platform_linux.rs:150`) | Builder. |
| `WindowControl` | `pub struct WindowControl` private alanlı (`platform_linux.rs:156-162`) | `#[derive(IntoElement)]`; public setter yok. |
| `WindowControl::new` | `pub fn new(id: impl Into<ElementId>, icon: WindowControlType, cx: &mut App) -> Self` (`platform_linux.rs:165`) | `close_action: None`; close için kullanılırsa click handler panik atar. |
| `WindowControl::new_close` | `pub fn new_close(id: impl Into<ElementId>, icon: WindowControlType, close_action: Box<dyn Action>, cx: &mut App) -> Self` (`platform_linux.rs:176-181`) | `close_action.boxed_clone()` saklar (`platform_linux.rs:188`). |
| `WindowControl::custom_style` | `pub fn custom_style(id: impl Into<ElementId>, icon: WindowControlType, style: WindowControlStyle) -> Self` (`platform_linux.rs:193-197`) | `#[allow(unused)]`; crate içinde çağrılmıyor, close action `None`. |

Linux davranışının kritik private helper'ı `fn create_window_button(...)`
(`platform_linux.rs:56-62`) dış API değildir ama parite için zorunlu karar
noktasıdır. `WindowButton::Close` branch'i yalnız `WindowControl::new_close(...)`
çağırır (`platform_linux.rs:77-79`). `WindowControl::new(...)` ile close
üretmek no-op değil; `expect("Use WindowControl::new_close() for close control.")`
ile paniktir (`platform_linux.rs:235-239`).

**Derive ve clonability haritası** (awk `#[derive(...)]` taraması ile
yakalanır, rg satır-bazlı eşleşmede struct ile derive arasındaki bağı
göstermez):

| Tip | Derive set | Önemi |
| :-- | :-- | :-- |
| `WindowControlType` | `Debug, PartialEq, Eq, PartialOrd, Ord, Hash, Clone, Copy` (`platform_linux.rs:84`) | `Hash` + `Copy` — `HashMap` key olabilir, value semantiği. `PartialOrd/Ord` deklarasyon sırasını kullanır: `Minimize < Restore < Maximize < Close`. |
| `WindowControlStyle` | **Hiçbiri yok** (`platform_linux.rs:107-108`) | `Clone`, `Copy`, `Default` impl'i **yoktur**; her yeni instance için `WindowControlStyle::default(cx)` çağrısı gerekir. `Default` trait olmadığı için generic koddan `D: Default` ile alınamaz. |
| `LinuxWindowControls` | `IntoElement` (`platform_linux.rs:6`) | `RenderOnce` yüzeyi; build edilip child olarak verilir, alanları tekrar erişilemez. |
| `WindowControl` | `IntoElement` (`platform_linux.rs:156`) | Aynı RenderOnce yüzeyi. |
| `WindowsWindowControls` | `IntoElement` (`platform_windows.rs:5`) | Aynı. |
| `DraggedWindowTab` | `Clone` (`system_window_tabs.rs:28`) | Drag payload tipi; clone'lanabilir ama `Copy` değil. |
| `PlatformTitleBar`, `SystemWindowTabs` | Yok | `Entity` ile yönetilir; trait impl'leri (`Render`, `ParentElement`) yüzeyi sağlar. |

**`WindowControlStyle::default(cx)` hangi tema token'larını okur?**
(`platform_linux.rs:117-124`):

| Style alanı | Tema token |
| :-- | :-- |
| `background` | `colors.ghost_element_background` |
| `background_hover` | `colors.ghost_element_hover` |
| `icon` | `colors.icon` |
| `icon_hover` | `colors.icon_muted` |

Builder zincirinde override edilmeyen alanlar bu default'larda kalır;
yani port hedefi tema sisteminin **bu dört token'ı sağlaması** zorunludur
(diğer rehber bölümlerinde de listelenir).

**Sabit ölçüler** (Linux render closure'larında pixel parite için):

| Yer | Değer | Kaynak |
| :-- | :-- | :-- |
| `LinuxWindowControls` buton container gap'i | `.gap_3()` (12px @ default rem) | `platform_linux.rs:48` |
| `LinuxWindowControls` buton container yatay padding | `.px_3()` | `platform_linux.rs:49` |
| `WindowControl` buton boyutu | `.w_5().h_5()` (≈20px) | `platform_linux.rs:222-223` |
| `WindowControl` köşe yuvarlama | `.rounded_2xl()` | `platform_linux.rs:221` |

**`Box<dyn Action>` klonlama zinciri** (awk `boxed_clone()` taraması ile
çıkarılır — rg her satırı ayrı ayrı bulur, zinciri toplamaz):

| Adım | Yer | Tetikleyici | Çağrı |
| :-- | :-- | :-- | :-- |
| 1 | `platform_title_bar.rs:189` | `render()` başı | `let close_action = Box::new(workspace::CloseWindow);` (ilk Box üretimi, klon değil) |
| 2 | `platform_title_bar.rs:251` | Fullscreen değil, macOS trafik ışığı padding branch'i seçilmedi ve `show_left_controls` true | `close_action.as_ref().boxed_clone()` — `render_left_window_controls` argümanı |
| 3 | `platform_title_bar.rs:302` | `show_right_controls` true ve `!is_fullscreen` | `close_action.as_ref().boxed_clone()` — `render_right_window_controls` argümanı |
| 4 | `platform_linux.rs:78` | İlgili tarafta `WindowButton::Close` slot'u var | `create_window_button` → `WindowControl::new_close(..., close_action.boxed_clone(), cx)` |
| 5 | `platform_linux.rs:188` | `new_close` gövdesi | `close_action: Some(close_action.boxed_clone())` (parametre move'lanmak yerine yeniden klonlanır) |
| 6 | `platform_linux.rs:239` | Close butonuna **click anı** | `.expect(...).boxed_clone()` — `window.dispatch_action(...)` argümanı |

Adım 2 ve 3 clone'u render fonksiyonları çağrılmadan önce yapılır; bu yüzden
o tarafta close butonu üretilmese bile clone maliyeti doğabilir. Fullscreen'de
adım 2 ve 3 atlanır. macOS'ta sol taraf genellikle trafik ışığı padding branch'i
ile çözülür; bu durumda adım 2 çalışmaz, fakat fullscreen değilse adım 3
`render_right_window_controls(...)` çağrısı öncesinde boşa clone üretir ve
fonksiyon Mac'te `None` döner. Windows'ta `WindowsWindowControls` close action'ı
kullanmaz; buna rağmen fullscreen değilse adım 2 ve 3 çalışabilir.

Adım 4 ve 5 yalnızca Linux CSD + close butonunun bulunduğu tarafta tetiklenir.
Tipik bir Linux GNOME render'ı (close sağda, sidebar kapalı): adım 2 + 3 + 4
+ 5 = **4 boxed_clone** per render. Adım 6 yalnızca click anında, **+1** ek
klon.

`Box<dyn Action>::boxed_clone()` aslında trait üzerinden v-table dispatch
yapan klon işlemidir (`Action::boxed_clone(&self) -> Box<dyn Action>`).
Concrete tip için maliyet `Clone` impl'ine bağlıdır; `workspace::CloseWindow`
gibi unit struct'lar için ucuz, alan taşıyan action'lar için klonlama
maliyeti her render'da çarpılır. Port hedefinde action tipinin hafif
tutulması (alan içermemesi) bu yolu hızlandırır; ayrıca adım 5
optimize edilebilir (parametre `Some(close_action)` ile move'lanırsa
bir klon ortadan kalkar).

#### `platforms::platform_windows`

| Dış API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `WindowsWindowControls` | `pub struct WindowsWindowControls { button_height: Pixels }` private alanlı (`platform_windows.rs:6-8`) | `#[derive(IntoElement)]`; dışarıdan sadece constructor var. |
| `WindowsWindowControls::new` | `pub fn new(button_height: Pixels) -> Self` (`platform_windows.rs:11`) | Render'da minimize, maximize/restore ve close caption butonlarını üretir. |

`WindowsCaptionButton` public değildir (`platform_windows.rs:58-64`). Private
`id()`, `icon()` ve `control_area()` metotları sırasıyla stable id, Segoe glyph
ve `WindowControlArea::{Min, Max, Close}` döndürür (`platform_windows.rs:66-94`).
Windows butonları Linux gibi click handler çağırmaz; `.window_control_area(...)`
hit-test alanı verir (`platform_windows.rs:124-135`) ve davranış platform
caption katmanında yürür.

**Segoe Fluent Icons glyph kodları** (Windows native parite için):

| Variant | Kodepoint | Kaynak |
| :-- | :-- | :-- |
| `Minimize` | `\u{e921}` | `platform_windows.rs:80` |
| `Restore` | `\u{e923}` | `platform_windows.rs:81` |
| `Maximize` | `\u{e922}` | `platform_windows.rs:82` |
| `Close` | `\u{e8bb}` | `platform_windows.rs:83` |

Font seçimi `WindowsWindowControls::get_font()` ile yapılır
(`platform_windows.rs:16/21`); Windows build 22000+ (Windows 11) için
`"Segoe Fluent Icons"`, daha eski sürümler için `"Segoe MDL2 Assets"`.
Port hedefinde bu font'lar yoksa glyph'ler kareler olarak render olur;
fallback SVG ikon zorunlu olabilir.

**Renk sabitleri** (`platform_windows.rs:99-122`):

| Buton | Hover bg | Hover fg | Active bg | Active fg |
| :-- | :-- | :-- | :-- | :-- |
| `Close` | `Rgba { r: 232/255, g: 17/255, b: 32/255, a: 1.0 }` = `#E81120` | `gpui::white()` | `color.opacity(0.8)` | `white().opacity(0.8)` |
| Diğerleri | `theme.ghost_element_hover` | `theme.text` | `theme.ghost_element_active` | `theme.text` |

Close butonunun kırmızısı (`#E81120`) **tema'dan değil, koddan gelir** —
Microsoft'un Windows title bar kapatma kırmızısıdır. Port hedefinin tema
sistemi farklı bir close vurgu rengi istiyorsa bu sabit override
edilmelidir.

**Sabit ölçüler** (Windows caption butonu):

| Yer | Değer | Kaynak |
| :-- | :-- | :-- |
| Caption buton genişliği | `.w(px(36.))` (36px) | `platform_windows.rs:129` |
| Glyph metin boyutu | `.text_size(px(10.0))` (10px) | `platform_windows.rs:131` |
| Buton yüksekliği | `WindowsWindowControls::new(button_height)`'ten `.h_full()` ile yayılır | `platform_windows.rs:11, 130` |
| Mouse propagation | `.occlude()` (alt katmanlara mouse event sızdırmaz) | `platform_windows.rs:128` |

#### Root'tan re-export edilen system tab action'ları

`actions!(window, [...])` makrosu dört unit struct üretir
(`system_window_tabs.rs:18-26`). Makro çıktısı `Clone`, `PartialEq`, `Default`,
`Debug` ve `gpui::Action` derive eder (`gpui/src/action.rs:24-40`):

- `pub struct ShowNextWindowTab;`
- `pub struct ShowPreviousWindowTab;`
- `pub struct MergeAllWindows;`
- `pub struct MoveTabToNewWindow;`

Bu action'lar root'tan re-export edilir (`platform_title_bar.rs:24-26`) ve Zed
`title_bar` crate'i de aynı adları tekrar re-export eder
(`title_bar/src/title_bar.rs:13-16`).

`DraggedWindowTab` de root'tan re-export edilir. İmzası:

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

Kaynak: `system_window_tabs.rs:28-38`. Bu tip aynı zamanda drag preview için
`Render` implement eder (`system_window_tabs.rs:498-528`).

#### Lexical `pub` ama dış API olmayan parçalar

| Öğe | Neden dış API değil? | Kullanım |
| :-- | :-- | :-- |
| `SystemWindowTabs` | `system_window_tabs` modülü private (`platform_title_bar.rs:2`) | `PlatformTitleBar::new` içinde entity olarak oluşturulur (`platform_title_bar.rs:39-42`) ve render sonunda child yapılır (`platform_title_bar.rs:322-325`). |
| `SystemWindowTabs::new` | Private modül içinde lexical `pub` (`system_window_tabs.rs:47`) | Internal scroll handle, ölçülen tab genişliği ve `last_dragged_tab` başlangıcı. |
| `SystemWindowTabs::init` | Private modül içinde lexical `pub` (`system_window_tabs.rs:55`) | `PlatformTitleBar::init(cx)` üzerinden çağrılır (`platform_title_bar.rs:100-101`). |
| `SystemWindowTabs::render_tab` | Private method (`system_window_tabs.rs:142`) | Tab elementlerini, drag/drop'u, middle-click close'u, close button'u ve context menu'yü kurar. |
| `handle_tab_drop` | Private method (`system_window_tabs.rs:358`) | Sadece same-bar drop reorder: `SystemWindowTabController::update_tab_position(...)`. |
| `handle_right_click_action` | Private method (`system_window_tabs.rs:362`) | Context menu action'larını hedef tab penceresinde çalıştırır. |

Bu ayrım port için önemlidir: `SystemWindowTabs` dış API olarak taşınmak zorunda
değildir; ama davranışı mirror edilecekse private event router'ları da
incelenmelidir.

#### GPUI native tab destek yüzeyi

Bu tipler `platform_title_bar` crate'inden değil, `gpui` crate'inden gelir; yine
de native tab davranışının state kaynağıdır.

| API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `SystemWindowTab` | `#[doc(hidden)] pub struct SystemWindowTab { pub id, pub title, pub handle, pub last_active_at }` (`gpui/src/app.rs:276-283`) | Platform native tab metadata'sı. |
| `SystemWindowTab::new` | `pub fn new(title: SharedString, handle: AnyWindowHandle) -> Self` (`gpui/src/app.rs:287`) | `id` handle'dan, `last_active_at` `Instant::now()` ile gelir. |
| `SystemWindowTabController::new` | `pub fn new() -> Self` (`gpui/src/app.rs:308`) | Empty global controller. |
| `SystemWindowTabController::init` | `pub fn init(cx: &mut App)` (`gpui/src/app.rs:316`) | Global controller'ı resetler. |
| `tab_groups` | `pub fn tab_groups(&self) -> &FxHashMap<usize, Vec<SystemWindowTab>>` (`gpui/src/app.rs:321`) | Grupları doğrudan ref olarak verir. |
| `tabs` | `pub fn tabs(&self, id: WindowId) -> Option<&Vec<SystemWindowTab>>` (`gpui/src/app.rs:380`) | Verilen pencereyle aynı gruptaki tab listesi. |
| `init_visible` | `pub fn init_visible(cx: &mut App, visible: bool)` (`gpui/src/app.rs:387`) | Sadece `visible` `None` ise set eder. |
| `is_visible` | `pub fn is_visible(&self) -> bool` (`gpui/src/app.rs:395`) | `None` ise `false`. |
| `set_visible` | `pub fn set_visible(cx: &mut App, visible: bool)` (`gpui/src/app.rs:400`) | Platform toggle callback'i kullanır. |
| `update_last_active` | `pub fn update_last_active(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:406`) | Aktif pencere değişiminde çağrılır. |
| `update_tab_position` | `pub fn update_tab_position(cx: &mut App, id: WindowId, ix: usize)` (`gpui/src/app.rs:418`) | Same-bar drag/drop reorder. |
| `update_tab_title` | `pub fn update_tab_title(cx: &mut App, id: WindowId, title: SharedString)` (`gpui/src/app.rs:432`) | Workspace title güncellemesinde kullanılır. |
| `add_tab` | `pub fn add_tab(cx: &mut App, id: WindowId, tabs: Vec<SystemWindowTab>)` (`gpui/src/app.rs:456`) | Platform tab listesinden controller grubu kurar. |
| `remove_tab` | `pub fn remove_tab(cx: &mut App, id: WindowId) -> Option<SystemWindowTab>` (`gpui/src/app.rs:489`) | Boş kalan grupları temizler. |
| `move_tab_to_new_window` | `pub fn move_tab_to_new_window(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:504`) | Controller state'inde yeni grup açar; platform move ayrıca çağrılır. |
| `merge_all_windows` | `pub fn merge_all_windows(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:515`) | Controller gruplarını tek grupta birleştirir; platform merge ayrıca çağrılır. |
| `select_next_tab` | `pub fn select_next_tab(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:533`) | Sonraki handle'ı `activate_window()` ile aktive eder. |
| `select_previous_tab` | `pub fn select_previous_tab(cx: &mut App, id: WindowId)` (`gpui/src/app.rs:548`) | Önceki handle'ı aktive eder. |
| `get_next_tab_group_window` | `pub fn get_next_tab_group_window(cx: &mut App, id: WindowId) -> Option<&AnyWindowHandle>` (`gpui/src/app.rs:326`) | Grup id sırası `HashMap` key sırasından gelir; kaynakta TODO var. |
| `get_prev_tab_group_window` | `pub fn get_prev_tab_group_window(cx: &mut App, id: WindowId) -> Option<&AnyWindowHandle>` (`gpui/src/app.rs:351`) | Aynı key sırası belirsizliği geçerlidir. |

#### Zed `title_bar` crate'inin public tüketim yüzeyi

Zed uygulaması bu platform crate'ini doğrudan kök API olarak da, `title_bar`
crate'i üzerinden re-export olarak da kullanır:

| API | İmza / tanım | Not |
| :-- | :-- | :-- |
| `pub mod collab` | `title_bar/src/title_bar.rs:2` | Platform titlebar değil, Zed collab UI helper modülü. |
| Platform re-export'ları | `pub use platform_title_bar::{ self, DraggedWindowTab, MergeAllWindows, MoveTabToNewWindow, PlatformTitleBar, ShowNextWindowTab, ShowPreviousWindowTab }` (`title_bar/src/title_bar.rs:13-16`) | Zed içi tüketiciler aynı action/tipleri `title_bar` üzerinden de alabilir. |
| `restore_banner` | `pub use onboarding_banner::restore_banner` (`title_bar/src/title_bar.rs:59`) | Product titlebar banner helper'ı. |
| `init` | `pub fn init(cx: &mut App)` (`title_bar/src/title_bar.rs:79`) | Platform titlebar init + per-workspace `TitleBar` entity kurulumu. |
| `TitleBar` | `pub struct TitleBar` private alanlı (`title_bar/src/title_bar.rs:150-163`) | Zed ürün başlığıdır; generic platform shell değildir. |
| `TitleBar::new` | `pub fn new(id: impl Into<ElementId>, workspace: &Workspace, multi_workspace: Option<WeakEntity<MultiWorkspace>>, window: &mut Window, cx: &mut Context<Self>) -> Self` (`title_bar/src/title_bar.rs:385-391`) | `PlatformTitleBar::new(...)` entity'sini oluşturur ve `observe_button_layout_changed` subscription'ı kurar (`title_bar.rs:441-455`). |
| Product helper'ları | `effective_active_worktree`, `render_restricted_mode`, `render_project_host`, `render_sign_in_button`, `render_user_menu_button` (`title_bar.rs:490`, `625`, `672`, `1142`, `1161`) | Zed'e özgü proje/kullanıcı UI yüzeyi; platform titlebar port API'si olarak kopyalanmamalıdır. |
| Ürün banner'ı | `OnboardingBanner::new(...)` | Feature flag'e bağlı duyuru/ürün mesajı katmanıdır; platform titlebar API'sine taşınmamalıdır. |

Zed ürün titlebar'ı, duyuru banner'larını da `TitleBar` katmanında yönetir.
Örneğin Skills duyurusu `SkillsFeatureFlag` ile görünür olur ve ilgili migration
bilgi action'ını dispatch eder. Kendi uygulamanızda benzer bir duyuru varsa bunu
`AppTitleBar` child grubuna koyun; platform kabuğuna sorumluluk olarak eklemeyin.

`OnboardingBanner` örneği, görünürlük koşulunu builder zincirinin sonundaki
`.visible_when(|cx| cx.has_flag::<SkillsFeatureFlag>())` çağrısıyla alır
(`title_bar/src/title_bar.rs:455-472`). Bu kalıp portta da aynen kullanılabilir:
banner kurucusuna bir predicate kapanışı verilir, kapanış her render geçişinde
çağrılarak `App`/`Context` üzerinden gelen feature flag veya ayar durumuna göre
banner'ı tamamen gizler. `title_bar.rs` içindeki çağrı `feature_flags`
crate'inden gelen `FeatureFlagAppExt` trait'iyle `cx.has_flag::<...>()`
çağrısına dayanır; port hedefinde aynı yardımcı yoksa benzer bir
`AppSettings`/`AppFlags` API'si yeterlidir. `TitleBar::new` içinde banner artık
sabit olarak kurulup `Some(...)` ile alana yazılır; eski "`banner: None`"
yerleşik durum kaldırılmıştır, dolayısıyla banner katmanı her örnekte hazır
durumdadır ve sadece `visible_when` predicate'i ile gizlenir.

`OnboardingBanner::new(...)` çağrısı, bu rehber yazıldığı anda sırasıyla şu
parametreleri alır: telemetri/dismiss kimliği için bir string (`"Skills
Migration Announcement"` gibi), `IconName` ikonu (`IconName::Sparkle`), banner
metni (`"Skills"`), opsiyonel ön ek (`Some("Introducing:".into())`) ve tıklama
ile dispatch edilecek boxed action (`zed_actions::agent::OpenRulesToSkillsMigrationInfo.boxed_clone()`).
Portta bu imzaların adları korunabilir; içerik, ikon ve action ürün tarafından
belirlenir.

`title_bar_settings.rs` içindeki `pub struct TitleBarSettings` (`title_bar_settings.rs:5-15`)
private modülde kaldığı için crate dışı API değildir; Zed ayar sistemi içinde
kullanılır. Kullanıcı ayarı tarafındaki dış veri tipi
`settings_content::title_bar::WindowButtonLayoutContent`'tir; Linux/FreeBSD'de
`pub fn into_layout(self) -> Option<WindowButtonLayout>` ile `WindowButtonLayout`
değerine çevrilir (`settings_content/src/title_bar.rs:24-49`).
`settings_content::title_bar::TitleBarSettingsContent` de public ayar payload'ıdır:
`show_branch_status_icon`, `show_onboarding_banner`, `show_user_picture`,
`show_branch_name`, `show_project_items`, `show_sign_in`, `show_user_menu`,
`show_menus` ve `button_layout` alanlarını `Option<...>` olarak taşır
(`settings_content/src/title_bar.rs:83-126`). Runtime tarafındaki
`TitleBarSettings` bu payload'dan üretilir (`title_bar_settings.rs:17-32`).

Zed uygulamasında `TitleBar` bu platform bileşenini iki farklı render modunda
besler (`title_bar/src/title_bar.rs:346-379`). `show_menus` true ise
`PlatformTitleBar::set_children(...)` yalnız uygulama menüsünü alır; ürün
başlığı ikinci bir satır olarak aynı `title_bar_color` ile render edilir.
`show_menus` false ise tüm ürün children'ı doğrudan `PlatformTitleBar` içine
verilir. Her iki yolda da `set_button_layout(button_layout)` render sırasında
çağrılır ve desktop layout değişimleri `observe_button_layout_changed(...)`
subscription'ı ile `cx.notify()` tetikler (`title_bar/src/title_bar.rs:441`).
Bu yüzden portta `PlatformTitleBar` tek başına "Zed titlebar UI'si" değildir;
Zed ürünü onu menü modu ve settings durumuna göre farklı child setleriyle
yönetir.

### 22. Kaynak doğrulama komutları

Kaynak doğrulamasını yalnız public adlar ve payload alanlarıyla sınırlamayın.
Owner/metot ve olay hedefi ayrımını da doğrulayın. Kontrolleri üç seviyede
çalıştır:

1. Public API envanteri.
2. Owner/metot yüzeyi.
3. Event akışı ve payload alan paritesi.

```sh
rg -n '^pub (struct|enum|fn)|^\s*pub fn|actions!\(' \
  ../zed/crates/platform_title_bar/src \
  -g '*.rs'
```

`PlatformTitleBar` owner/metot yüzeyi:

```sh
rg -n '^impl PlatformTitleBar|^\s*pub fn (new|with_multi_workspace|set_multi_workspace|title_bar_color|set_children|set_button_layout|init|is_multi_workspace_enabled)|^pub fn render_(left|right)_window_controls' \
  ../zed/crates/platform_title_bar/src/platform_title_bar.rs
```

System tab controller yüzeyi:

```sh
sed -n '270,560p' ../zed/crates/gpui/src/app.rs \
  | rg '^pub struct SystemWindowTab|^impl SystemWindowTab|^pub struct SystemWindowTabController|^impl SystemWindowTabController|^\s*pub fn'
```

`DraggedWindowTab` alan paritesi ve event akışı:

```sh
sed -n '28,39p' ../zed/crates/platform_title_bar/src/system_window_tabs.rs
rg -n 'on_drag|last_dragged_tab|drag_over::<DraggedWindowTab>|on_drop|on_mouse_up_out|handle_tab_drop|move_tab_to_new_window|merge_all_windows|update_tab_position' \
  ../zed/crates/platform_title_bar/src/system_window_tabs.rs
```

Fullscreen ve tab render ayrıntıları:

```sh
rg -n 'is_fullscreen|render_left_window_controls|render_right_window_controls|show_window_menu|CLIENT_SIDE_DECORATION_ROUNDING|mt\(px\(-1|SystemWindowTabs|Tab::content_height|Tab::container_height|measured_tab_width|max\(rem_size|ShowCloseButton|ClosePosition|visible_on_hover|drop_target|IconButton::new\("plus"' \
  ../zed/crates/platform_title_bar/src \
  ../zed/crates/ui/src/components/tab.rs \
  ../zed/crates/settings_content/src/workspace.rs
```

Native tab init ve sağ tık/action ayrımını görmek için:

```sh
rg -n 'observe_global::<SettingsStore>|was_use_system_window_tabs|set_tabbing_identifier|tabbed_windows|register_action_renderer|toggle_window_tab_overview|MergeAllWindows|build_window_options|tabbing_identifier' \
  ../zed/crates/platform_title_bar/src/system_window_tabs.rs \
  ../zed/crates/gpui/src/window.rs \
  ../zed/crates/zed/src/zed.rs
```

Controller grup mutasyonlarını görmek için:

```sh
rg -n 'pub fn (add_tab|remove_tab|move_tab_to_new_window|merge_all_windows|update_tab_position|update_tab_title|select_next_tab|select_previous_tab|get_next_tab_group_window|get_prev_tab_group_window)' \
  ../zed/crates/gpui/src/app.rs
```

Pencere seçenekleri ve CSD bağlantılarını kontrol etmek için:

```sh
find ../zed/crates -name '*.rs' -print0 |
  xargs -0 awk '/WindowOptions|WindowDecorations|Decorations::Client|WindowControlArea|set_tabbing_identifier|button_layout\\(|tab_bar_visible\\(|start_window_move|show_window_menu/ { print FILENAME ":" FNR ":" $0 }'
```

`WindowButtonLayout` ayar zincirini görmek için:

```sh
find ../zed/crates/gpui/src ../zed/crates/settings_content/src ../zed/crates/title_bar/src -name '*.rs' -print0 |
  xargs -0 awk '/MAX_BUTTONS_PER_SIDE|WindowButtonLayout|WindowButton|button_layout|linux_default|parse\\(|into_layout|observe_button_layout_changed/ { print FILENAME ":" FNR ":" $0 }'
```

Owner ayrımı (struct vs trait vs inherent fn vs free fn) için **state-machine
awk** kullan. `rg`'nin satır-tabanlı eşleşmesi bir `pub fn`'in hangi `impl`
bloğunun içinde olduğunu raporlamaz; awk içindeki kalıcı state ile bunu
çıkarırız:

```sh
find ../zed/crates/platform_title_bar/src -name '*.rs' -print0 |
  xargs -0 gawk '
    BEGIN { owner = "(free)" }
    /^pub struct [A-Za-z0-9_]+/  { print FILENAME ":" FNR ":STRUCT: " $0; next }
    /^pub enum [A-Za-z0-9_]+/    { print FILENAME ":" FNR ":ENUM: "   $0; next }
    /^pub trait [A-Za-z0-9_]+/   { print FILENAME ":" FNR ":TRAIT: "  $0; next }
    /^pub fn [A-Za-z0-9_]+/      { print FILENAME ":" FNR ":FREE_FN: " $0; next }
    /^impl[^!]/ {
      if (match($0, /for[[:space:]]+([A-Za-z0-9_]+)/, m))                  { owner = m[1] " (trait impl)" }
      else if (match($0, /impl(<[^>]+>)?[[:space:]]+([A-Za-z0-9_]+)/, m))   { owner = m[2] " (inherent)" }
      else                                                                  { owner = "?" }
      print FILENAME ":" FNR ":IMPL[" owner "]: " $0; next
    }
    /^[[:space:]]+pub fn [A-Za-z0-9_]+/ {
      print FILENAME ":" FNR ":  METHOD[" owner "]: " $0
    }
  '
```

Bu komut `WindowControl::new`, `WindowControl::new_close`,
`WindowControl::custom_style` üçlüsünü ve `WindowControlStyle::default(cx)` gibi
**inherent** ad çakışmalarını ayrı satırlarda gösterir. `rg '^impl '` yalnızca
header'ı verir; metotların hangi owner'a ait olduğunu eşleştirmek için ya
`-A N` ile blok büyüklüğünü tahmin etmek ya da awk state'i kullanmak gerekir —
state-machine yolu daha güvenlidir.

**Modül görünürlüğü kontrolü:** `pub struct` tek başına dış API değildir.
Önce crate kökündeki `pub mod`, `mod` ve `pub use` kapılarını gör:

```sh
rg -n '^(pub mod|mod |pub use)|^pub (struct|enum|fn)|^[[:space:]]+pub fn' \
  ../zed/crates/platform_title_bar/src/platform_title_bar.rs \
  ../zed/crates/platform_title_bar/src/platforms.rs \
  ../zed/crates/platform_title_bar/src/platforms/*.rs \
  ../zed/crates/platform_title_bar/src/system_window_tabs.rs
```

Okuma kuralı:

- `platform_title_bar.rs` içindeki `pub mod platforms;` dış path açar.
- `platform_title_bar.rs` içindeki `mod system_window_tabs;` private kapıdır.
- Private modül içindeki `pub struct SystemWindowTabs` dış API değildir.
- Aynı private modülden root'a `pub use` edilen `DraggedWindowTab` ve tab
  action'ları dış API olur.

**Sınırı:** Yukarıdaki kalıplar `^pub fn` ve `^[[:space:]]+pub fn` ile
sadece **public** öğeleri yakalar. Crate-içi `fn create_window_button(...)`
gibi file-private free helper'lar (Linux render yolunun gerçek
dispatch noktası) gözden kaçar. Davranış paritesi için bu helper'ları
da görmek istersen kalıpları gevşet:

```sh
find ../zed/crates/platform_title_bar/src -name '*.rs' -print0 |
  xargs -0 gawk '
    /^fn [A-Za-z0-9_]+/         { print FILENAME ":" FNR ":FREE_FN(priv): " $0 }
    /^[[:space:]]+fn [A-Za-z0-9_]+/ { print FILENAME ":" FNR ":  METHOD(priv): " $0 }
  '
```

Çıktıda şu file-private parçalar görünür:

- `fn create_window_button(...)` (`platform_linux.rs:56`) — Linux render
  yolunun gerçek dispatch noktası.
- `fn id(&self)`, `fn icon(&self)`, `fn control_area(&self)`
  (`platform_windows.rs:68, 78, 88`) — `WindowsCaptionButton` üzerindeki
  inherent yardımcılar.
- `fn get_font()` (`platform_windows.rs:16, 21`) — Windows 11 / Windows 10
  ayrımı için font seçicisi (`Segoe Fluent Icons` vs `Segoe MDL2 Assets`).
- `fn handle_tab_drop`, `fn handle_right_click_action`
  (`system_window_tabs.rs:358, 362`) — tab bar event router'ları.
- `PlatformTitleBar::effective_button_layout`, `::sidebar_render_state`
  (`platform_title_bar.rs:86, 104`) — public yüzeyin arkasındaki karar
  helper'ları.
- `fn render(...)` satırları — `Render`/`RenderOnce` trait impl gövdeleri;
  ayrı satırlarda görüldüklerinde `IMPL[Owner (trait impl)]` header'ı ile
  eşleştirilmesi gerekir.

Bu set, **dış API'ye değil ama davranış mirror'ına** dahil olan
parçaları açığa çıkarır. Port hedefinde aynı isimleri kullanmak şart
değil; ama her birinin davranışına paralel bir karar noktası
bulunmalıdır.

Crate sınırını aşan keşif için (örn. `SystemWindowTabController`
`platform_title_bar` referansıyla bulunur ama `gpui` crate'inde tanımlıdır):

```sh
# Önce platform_title_bar'da geçen tüm tip adlarını çıkar
gawk '
  match($0, /\<([A-Z][A-Za-z0-9_]+)\>/, m) { print m[1] }
' ../zed/crates/platform_title_bar/src/*.rs \
  ../zed/crates/platform_title_bar/src/platforms/*.rs \
  | sort -u > /tmp/ptb_referenced.txt

# Sonra her birinin tanım crate'ini bul
while read name; do
  defs=$(rg -l "^pub (struct|enum|trait|fn|type) ${name}\b" ../zed/crates 2>/dev/null)
  [ -n "${defs}" ] && echo "${name}: ${defs}"
done < /tmp/ptb_referenced.txt
```

Bu adım `DraggedWindowTab` doğrudan `platform_title_bar`'da olsa da
`SystemWindowTabController`'ın `gpui/src/app.rs`'te tanımlı olduğunu açığa
çıkarır — bu cross-crate sıçramayı **yalnızca** rehberin merkez crate'inde
tarama yapmak kaçırır.
