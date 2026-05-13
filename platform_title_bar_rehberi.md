# Zed Platform Title Bar Kullanım Rehberi

Bu rehber, GPUI tabanlı kendi uygulamana **Zed-uyumlu, platforma duyarlı bir
başlık çubuğu** entegre etmen için yazılmıştır. Zed'in
`crates/platform_title_bar` ve `crates/title_bar` crate'lerini **doğrudan
dependency olarak kullanmadan** (GPL-3 lisans nedeniyle), aynı platform
davranışını veren, kendi action ve ayar sözleşmenize bağlanan, lisans
açısından temiz bir başlık çubuğu inşa etmek hedeftir.

> **Eşlik eden dosyalar (rehber tamamlandıktan sonra eklenecek):**
> `platform_title_bar_aktarimi.md` (upstream pin / sync günlüğü) ve
> `platform_title_bar_kaymasi_kontrol.sh` (drift raporu). Bu rehber
> **mimari, sözleşme ve kod** tarafına odaklanır; uzun vadeli senkron
> disiplini için onlara bakılır.

> **Anlatım biçimi:** Rehber, GPUI ana referansı `rehber.md` ve tema
> rehberi `tema_rehber.md` ile aynı biçimi kullanır — her konu kendi
> başına okunabilir; kullanılan tipi, hangi modülden geldiğini, kabul
> ettiği değerleri, runtime davranışını ve yaygın tuzakları tek yerde
> toplar. Mevcut faz-tabanlı eski içerik geçici olarak "Ek" bölümünde
> tutulur; bölümler tamamlandıkça absorbe edilip silinir.

---

## İçindekiler

### Bölüm I — Mimari ve İlkeler
1. [Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama state](#1-üç-katmanlı-yaklaşım-platform-kabuğu--ürün-başlığı--uygulama-state)
2. [Temel ilke: platform katmanı bilir, ürün katmanı karar verir](#2-temel-ilke-platform-katmanı-bilir-ürün-katmanı-karar-verir)
3. [Lisans-temiz çalışma protokolü](#3-lisans-temiz-çalışma-protokolü)
4. [Crate yapısı ve klasör yerleşimi](#4-crate-yapısı-ve-klasör-yerleşimi)
5. [Bağımlılık matrisi](#5-bağımlılık-matrisi)

### Bölüm II — GPUI'nin title bar için kullanılan yüzeyi
6. `WindowOptions`, `TitlebarOptions`, `WindowDecorations`
7. `WindowControlArea` ve hit-test sözleşmesi
8. `WindowButtonLayout`, `WindowButton`, `observe_button_layout_changed`
9. `Window` API'leri: minimize / zoom / start_window_move / show_window_menu / titlebar_double_click / set_client_inset
10. `tabbing_identifier`, `tab_bar_visible`, fullscreen ve `window_controls` capability filtresi

### Bölüm III — Platform katmanı tipleri
11. `PlatformTitleBar` üst yapısı ve render modeli
12. `LinuxWindowControls`, `WindowControl`, `WindowControlStyle`, `WindowControlType`
13. `WindowsWindowControls` ve caption button → `WindowControlArea` eşlemesi
14. macOS trafik ışıkları, `traffic_light_position`, `titlebar_double_click`
15. `SystemWindowTabs`, `SystemWindowTabController`, `SystemWindowTab`

### Bölüm IV — Davranış sözleşmesi
16. Drag alanı, `WindowControlArea::Drag` ve propagation kuralları
17. Çift tıklama platform farkları (macOS / Linux / Windows)
18. Title bar rengi: `title_bar_background` vs `title_bar_inactive_background` ve tema token kataloğu
19. Yükseklik hesabı (`platform_title_bar_height`)
20. Client-side decoration sarmalı (shadow / border / resize / inset)

### Bölüm V — Buton ve action yönetimi
21. Close action sözleşmesi ve `Box<dyn Action>` enjeksiyonu
22. Minimize/maximize: Linux doğrudan `Window`, Windows native caption
23. `WindowButtonLayout` ayar formatları (`platform_default` / `standard` / GNOME string)
24. Native tab action'ları: `ShowNextWindowTab` / `ShowPreviousWindowTab` / `MoveTabToNewWindow` / `MergeAllWindows`

### Bölüm VI — Sidebar ve workspace etkileşimi
25. `MultiWorkspace` zayıf referansı ve `SidebarRenderState`
26. Pencere kontrolleri sidebar çakışma kuralı
27. `is_multi_workspace_enabled` feature flag deseni

### Bölüm VII — Tüketim ve dış API
28. Doğrudan crate ile kullanım (Zed ekosistemi içi)
29. Bağımsız uygulama için port stratejisi
30. Public API kataloğu ve crate-içi sınır
31. Test ortamında title bar mock'lama

### Bölüm VIII — Pratik
32. Sınama listesi
33. Yaygın tuzaklar
34. Reçeteler

---

## Bölüm I — Mimari ve İlkeler

---

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
davranış paritesi. Bölüm III ve IV bu katmanı ele alır. **Lisans
nedeniyle kod kopyalanmaz**; sadece API'lerin gözlemlenebilir davranışı
yeniden inşa edilir.

**Ürün başlığı (orta katman) — `senin tasarımın`:** Uygulamanın
gerçek başlık içeriği. Menü, proje adı, status chip'leri, kullanıcı
avatar'ı — hepsi senin tasarım dilinde. Platform kabuğuna **child**
olarak verilir; her render'da yenilenir (Konu 11'de `set_children`
tüketim modeli). Tema rehberinin "Faz 5 — UI tüketim" bölümüyle aynı
zihniyet: temayı oku, durum-bazlı render et.

**Uygulama state (en üst katman) — `karar otoritesi`:** Platform
kabuğunun ihtiyaç duyduğu **politika** kararları: "close butonu ne
kapatıyor?", "new window action'ı hangi?", "Linux butonları sağda mı
solda mı?", "sidebar açık mı?". Bunları platform kabuğuna **trait
sözleşmesi** üzerinden verirsin (`TitleBarController` — Konu 17 sonu).

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

Sync turunda (`platform_title_bar_aktarimi.md` — rehber bittikten sonra
oluşturulacak) bu eşleme tablosu **referans değer**: Zed sözleşmesindeki
yeni bir kavram bizim hangi tipte mirror edilir, kararı burada verilir.

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
3. **Sidebar açıkken pencere kontrollerini gizleme kararı.** Bu Konu 26'da
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
bu rehber yine işe yarar (Bölüm II–IV referans amaçlı okunabilir), ama
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
   GPL dep girerse CI'da yakalanmalı (Bölüm I/Konu 5 sonu).

---

### 4. Crate yapısı ve klasör yerleşimi

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
├── gpui_belge/                       ← bu rehber + (sonradan) aktarımı + drift script
│   ├── platform_title_bar_rehberi.md
│   ├── platform_title_bar_aktarimi.md       ← rehber bittikten sonra
│   └── platform_title_bar_kaymasi_kontrol.sh ← rehber bittikten sonra
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

- Pin: <Zed kısa SHA> (bkz. ../../gpui_belge/platform_title_bar_aktarimi.md
  — rehber tamamlanınca oluşturulacak)
- Crate yapısı: kvs_titlebar (platform kabuğu) + kvs_app_titlebar (ürün başlığı)
- TitleBarController trait: uygulama action / sidebar / button_layout
  sorularını trait üzerinden alır (Zed'in workspace doğrudan referansı
  yerine)
- SystemWindowTabs: ilk sürümde **kapalı** (feature flag default off);
  uygulama native tab desteğine ihtiyaç doğunca açılacak
- macOS double-click davranışı: sistem default'a teslim edilir; ayar
  override'ı yapılmaz (gerekirse Konu 17'ye göre eklenir)
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
açıktır. Public API kararlılık seviyeleri Bölüm VII/Konu 30'da detaylı.

---

### 5. Bağımlılık matrisi

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
| `workspace::client_side_decorations` | Kendi CSD sarmalı (Konu 20) |
| `zed_actions::OpenRecent { create_new_window: true }` | `TitleBarController::new_window_action()` |
| `WorkspaceSettings::use_system_window_tabs` | `TitleBarController::use_system_window_tabs(cx)` |
| `ItemSettings::close_position`, `ItemSettings::show_close_button` | Senin kendi `TabSettings` veya app config |
| `DisableAiSettings` | Senin kendi feature flag'in (`SidebarSettings::enabled` vb.) |
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

**Bölüm I çıkış kriteri:** `cargo check -p kvs_titlebar -p kvs_app_titlebar`
yeşil. Tipler tanımlı (alanları boş veya `unimplemented!()` olsa bile);
modül ağacının iskeleti hazır; lisans-temiz dep listesi `cargo deny` ile
doğrulanıyor.

---

## Bölüm II — GPUI'nin title bar için kullanılan yüzeyi

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `WindowOptions`,
`TitlebarOptions`, `WindowDecorations`, `WindowControlArea`, `WindowButtonLayout`,
`WindowButton`, `observe_button_layout_changed`, `Window` API'leri
(`minimize_window`, `zoom_window`, `start_window_move`, `show_window_menu`,
`titlebar_double_click`, `set_client_inset`, `tab_bar_visible`,
`set_tabbing_identifier`), fullscreen ve `window_controls` capability
filtresi.)_

---

## Bölüm III — Platform katmanı tipleri

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `PlatformTitleBar`,
`LinuxWindowControls`, `WindowControl`, `WindowControlStyle`,
`WindowControlType`, `WindowsWindowControls`, macOS davranışı,
`SystemWindowTabs`, `SystemWindowTabController`, `SystemWindowTab`.)_

---

## Bölüm IV — Davranış sözleşmesi

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: drag alanı, çift
tıklama platform farkları, title bar rengi, yükseklik hesabı, CSD
sarmalı.)_

---

## Bölüm V — Buton ve action yönetimi

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: close action sözleşmesi,
minimize/maximize, button_layout ayar formatları, native tab action'ları.)_

---

## Bölüm VI — Sidebar ve workspace etkileşimi

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: `MultiWorkspace`
muadili, sidebar çakışma kuralı, feature flag deseni.)_

---

## Bölüm VII — Tüketim ve dış API

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: doğrudan kullanım, port
stratejisi, public API kataloğu ve crate-içi sınır, test mock'lama.)_

---

## Bölüm VIII — Pratik

_(Bu bölüm bir sonraki adımda yazılacak. Kapsam: sınama listesi, yaygın
tuzaklar, reçeteler.)_

---

# Ek (geçici): Faz tabanlı eski içerik

> **Not:** Aşağıdaki içerik bölüm bölüm yeni yapıya taşınmaktadır.
> Taşıma tamamlandıkça ilgili alt başlıklar bu ekten kaldırılır. Eski
> referansları kırmamak için geçici olarak korunur.

---

## 1. Kapsam

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

## 2. Kaynak Haritası

| Parça | Kaynak | Görev |
| :-- | :-- | :-- |
| `PlatformTitleBar` | `crates/platform_title_bar/src/platform_title_bar.rs` | Ana render entity'si, drag alanı, arka plan, köşe yuvarlama, child slotları, sol/sağ buton yerleşimi. |
| `render_left_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD'de sol pencere butonlarını üretir. |
| `render_right_window_controls` | `crates/platform_title_bar/src/platform_title_bar.rs` | Linux CSD veya Windows için sağ pencere butonlarını üretir. |
| `LinuxWindowControls` | `crates/platform_title_bar/src/platforms/platform_linux.rs` | Linux minimize, maximize/restore ve close butonlarının GPUI render katmanı. |
| `WindowsWindowControls` | `crates/platform_title_bar/src/platforms/platform_windows.rs` | Windows caption butonları ve `WindowControlArea` eşleşmeleri. |
| `SystemWindowTabs` | `crates/platform_title_bar/src/system_window_tabs.rs` | Native pencere sekmeleri, sekme menüsü, sürükle-bırak ve pencere birleştirme davranışları. |
| `TitleBar` | `crates/title_bar/src/title_bar.rs` | Zed'in uygulama başlığı, proje adı, menü, kullanıcı ve workspace state'ini `PlatformTitleBar` içine bağlayan üst seviye bileşen. |
| `client_side_decorations` | `crates/workspace/src/workspace.rs` | CSD pencere gölgesi, border, resize kenarları ve inset yönetimi. |
| `WindowOptions` | `crates/gpui/src/platform.rs` | Pencere dekorasyonu, titlebar options ve native tabbing identifier ayarları. |

## 3. Zed İçindeki Bağlantı Modeli

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

## 4. Entegrasyon Ön Koşulları

### Pencere seçenekleri

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

### Client-side decoration sarmalı

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

## 5. Public API Envanteri

### `PlatformTitleBar`

| API | Kullanım |
| :-- | :-- |
| `PlatformTitleBar::new(id, cx)` | Başlık çubuğu entity state'ini oluşturur. |
| `with_multi_workspace(weak)` | İlk oluşturma sırasında sidebar state kaynağı verir. |
| `set_multi_workspace(weak)` | Sonradan sidebar state kaynağı bağlar. |
| `title_bar_color(window, cx)` | Aktif/pasif pencere durumuna göre titlebar rengini döndürür. |
| `set_children(children)` | Başlık çubuğunun orta içeriğini verir. Her render geçişinde yenilenmelidir. |
| `set_button_layout(layout)` | Linux CSD butonlarının sol/sağ yerleşimini override eder. |
| `PlatformTitleBar::init(cx)` | `SystemWindowTabs` global observer ve action renderer kayıtlarını kurar. |
| `is_multi_workspace_enabled(cx)` | Zed'de AI ayarına bağlı workspace sidebar davranışını kontrol eder. |

### Yardımcı render fonksiyonları

`render_left_window_controls(button_layout, close_action, window)`:

- Yalnızca Linux/FreeBSD platform stili için anlamlıdır.
- Yalnızca `Decorations::Client` durumunda element döndürür.
- `button_layout.left[0]` boşsa `None` döner.
- Close butonu için dışarıdan `Box<dyn Action>` alır.

`render_right_window_controls(button_layout, close_action, window)`:

- Linux/FreeBSD CSD'de `button_layout.right` ile `LinuxWindowControls` üretir.
- Windows'ta `WindowsWindowControls::new(height)` üretir.
- macOS'ta `None` döner; trafik ışıkları native titlebar tarafından yönetilir.

### Platform butonları

| Tip | Platform | Davranış |
| :-- | :-- | :-- |
| `LinuxWindowControls` | Linux/FreeBSD CSD | `WindowButtonLayout` sırasını okur, desteklenmeyen minimize/maximize butonlarını filtreler. |
| `WindowControl` | Linux/FreeBSD CSD | Minimize için `window.minimize_window()`, maximize/restore için `window.zoom_window()`, close için verilen action'ı dispatch eder. |
| `WindowControlStyle` | Linux/FreeBSD CSD | Buton arka planı ve ikon renklerini değiştirmek için builder yüzeyi sağlar. |
| `WindowsWindowControls` | Windows | Minimize, maximize/restore ve close butonlarını `WindowControlArea::{Min, Max, Close}` olarak işaretler. |

## 6. Kendi Uygulamana Dahil Etme

### Doğrudan Zed crate'iyle kullanım

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

### Bağımsız GPUI uygulamasına port

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

## 7. Davranış Modeli

### Sürükleme

Ana titlebar yüzeyi `WindowControlArea::Drag` ile işaretlenir. Ayrıca sol mouse
down/move akışıyla `window.start_window_move()` çağırır. Bu kombinasyon,
platforma bağlı titlebar drag davranışının tutarlı işlemesini sağlar.

Başlık çubuğuna koyduğunuz interaktif elementler kendi mouse down/click
olaylarında propagation'ı durdurmalıdır. Aksi halde buton, arama kutusu veya
menü tıklaması pencere sürükleme davranışıyla çakışabilir.

### Çift tıklama

Platform farkı Zed kaynağında ayrı işlenir:

- macOS: `window.titlebar_double_click()`
- Linux/FreeBSD: `window.zoom_window()`
- Windows: davranış platform caption/hit-test katmanına bırakılır.

Kendi uygulamanızda çift tıklamanın maximize yerine minimize gibi farklı bir
ayar izlemesini istiyorsanız bu bölüm parametreleştirilmelidir.

### Renk

`title_bar_color` Linux/FreeBSD tarafında aktif pencere için
`title_bar_background`, pasif veya move sırasında `title_bar_inactive_background`
kullanır. Diğer platformlarda doğrudan `title_bar_background` döner.

Bu davranış, başlık çubuğu ve sekme çubuğu arasında görsel ayrımı korur. Kendi
tema sisteminizde en az şu token'lar gerekir:

- `title_bar_background`
- `title_bar_inactive_background`
- `tab_bar_background`
- `border`
- `ghost_element_background`
- `ghost_element_hover`
- `ghost_element_active`
- `icon`
- `icon_muted`
- `text`

### Yükseklik

Zed `platform_title_bar_height(window)` kullanır:

- Windows: sabit `32px`.
- Diğer platformlar: `1.75 * rem_size`, minimum `34px`.

Bu değer hem titlebar hem Windows buton yüksekliği hem de bazı yardımcı
başlıkların hizalaması için ortak kullanılmalıdır.

## 8. Buton Yerleşimi ve Ayar Yönetimi

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

## 9. Butonları Uygulama Katmanına Bağlama

### Close davranışı

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

### Minimize ve maximize

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

### Sekme butonları

`SystemWindowTabs` içindeki sekme kapatma davranışı da `workspace::CloseWindow`
dispatch eder. Sağ tık menüsünde şu işlemler bulunur:

- Close Tab
- Close Other Tabs
- Move Tab to New Window
- Show All Tabs

Alt sağdaki plus butonu `zed_actions::OpenRecent { create_new_window: true }`
dispatch eder. Kendi uygulamanızda bu action büyük olasılıkla `NewWindow`,
`OpenWorkspace` veya `CreateDocumentWindow` olmalıdır.

## 10. System Window Tabs

`PlatformTitleBar::init(cx)`, `SystemWindowTabs::init(cx)` çağırır. Bu kurulum
iki şeyi yapar:

1. `WorkspaceSettings::use_system_window_tabs` ayarını izler ve pencerelerin
   `tabbing_identifier` değerlerini günceller.
2. Yeni `Workspace` entity'leri için action renderer kaydeder:
   `ShowNextWindowTab`, `ShowPreviousWindowTab`, `MoveTabToNewWindow`,
   `MergeAllWindows`.

Render sırasında `SystemWindowTabController` global state'i okunur. Controller
aktif pencerenin sekme grubunu döndürür; yoksa current window tek sekme gibi
gösterilir.

Sekme çubuğu şu durumlarda boş döner:

- Platform `window.tab_bar_visible()` false ve controller görünür değilse.
- `use_system_window_tabs` false ve yalnızca bir sekme varsa.

Sekme drag payload tipi `DraggedWindowTab` (`system_window_tabs.rs:29`):

```rust
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
`SystemWindowTabs.last_dragged_tab` alanı bir önceki drag'ı saklar; drop
hedefi başka pencereye düşerse aynı payload yeniden okunup `merge`/`move`
akışına yönlendirilebilir. Kendi uygulamana port ediyorsan tab drag/drop
sözleşmesini bu tipi mirror ederek koru.

Kendi uygulamanızda native tab desteğini ilk aşamada istemiyorsanız:

- `PlatformTitleBar::init(cx)` çağrısını kaldırmak yerine, port edilen
  `PlatformTitleBar` içinde `SystemWindowTabs` child'ını feature flag ile kapatın.
- `tabbing_identifier` değerini `None` bırakın.
- Sekme action'larını kaydetmeyin.

Native tab desteğini koruyacaksanız:

- Her pencereye aynı uygulama tab group adı verin.
- `SystemWindowTabController::init(cx)` çağrısını ayar açıldığında yapın.
- Yeni açılan pencereleri controller'a `SystemWindowTab::new(title, handle)` ile
  bildirin.
- Sekme kapatma ve yeni pencere action'larını uygulama lifecycle'ınıza bağlayın.

## 11. Sidebar ve Workspace Etkileşimi

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

## 12. Başlık Çubuğuna İçerik Yerleştirme

`PlatformTitleBar` kendi başına sadece platform kabuğunu sağlar. Zed'in gerçek
ürün başlığı `crates/title_bar/src/title_bar.rs` içindeki `TitleBar` tarafından
oluşturulur. Bu katman şunları child olarak verir:

- Uygulama menüsü.
- Proje adı / recent projects popover.
- Git branch adı ve durum ikonu.
- Restricted mode göstergesi.
- Kullanıcı menüsü, sign-in butonu, plan chip, update bildirimi.
- Collab/screen share göstergeleri.

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

## 13. Özelleştirme Noktaları

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Close butonu farklı action dispatch etsin | `PlatformTitleBar` içine `close_action` alanı ekle veya serbest render fonksiyonlarını kullan. |
| Linux buton sırası ayardan gelsin | `set_button_layout(...)` çağrısını uygulama settings state'ine bağla. |
| Linux buton ikon/rengi değişsin | `WindowControlStyle` veya `WindowControlType::icon()` portunda değişiklik yap. |
| Windows close hover rengi değişsin | `platform_windows.rs` içinde `WindowsCaptionButton::Close` renklerini değiştir. |
| Titlebar yüksekliği değişsin | `platform_title_bar_height` karşılığını uygulamana taşı ve tüm titlebar/controls kullanımında aynı değeri kullan. |
| Native tabs kapatılsın | `SystemWindowTabs` render child'ını feature flag ile boş döndür. |
| Sekme plus butonu yeni pencere açsın | `zed_actions::OpenRecent` yerine uygulama `NewWindow` action'ını dispatch et. |
| Sidebar açıkken kontroller gizlenmesin | `sidebar_render_state` ve `show_left/right_controls` koşullarını değiştir. |
| Sağ tık window menu kapatılsın | Linux CSD `window.show_window_menu(ev.position)` bağını kaldır veya ayara bağla. |
| Çift tıklama maximize yerine özel action olsun | Platform click handler'larını kendi action'ına yönlendir. |

## 14. Kontrol Listesi

### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında bir kez çağrılıyor.
- Pencere `WindowOptions.titlebar` değerini transparent titlebar ile açıyor.
- Linux CSD gerekiyorsa `WindowDecorations::Client` isteniyor.
- CSD kullanılıyorsa pencere gölge/border/resize sarmalı ayrıca uygulanıyor.
- Titlebar child'ları her render geçişinde `set_children(...)` ile yenileniyor.
- İnteraktif titlebar child'ları drag propagation ile çakışmıyor.
- Tema token'ları aktif, pasif ve hover durumlarını kapsıyor.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı ile `WindowButtonLayout` geliyor.
- Sol ve sağ buton dizilerinde boş slotlar doğru davranıyor.
- Desktop layout değişince titlebar yeniden render oluyor.
- `window.window_controls()` minimize/maximize desteğini doğru filtreliyor.
- Sağ tık sistem pencere menüsü istenen ürün davranışıyla uyumlu.

### Windows

- Caption button alanları `WindowControlArea::{Min, Max, Close}` olarak kalıyor.
- Sağdaki ürün butonları caption button hitbox'larıyla çakışmıyor.
- `platform_title_bar_height` Windows için `32px` varsayımını koruyor veya bilinçli
  değiştiriliyor.
- Close hover rengi tema politikanızla uyumlu.

### macOS

- Trafik ışıkları için sol padding korunuyor.
- `traffic_light_position` ile titlebar child'ları çakışmıyor.
- Fullscreen ve native tabs davranışı ayrıca test ediliyor.
- Çift tıklama sistem davranışına mı, özel davranışa mı gidecek netleştiriliyor.

### Native tabs

- `tabbing_identifier` tüm ilgili pencerelerde aynı.
- Sekme kapatma action'ı kirli doküman/workspace state'ini kontrol ediyor.
- Sekmeyi yeni pencereye alma uygulama state'ini doğru taşıyor.
- Plus butonu doğru yeni pencere/workspace action'ını dispatch ediyor.
- Sağ tık menü metinleri ve action'ları ürün diline uyarlanıyor.

## 15. Kaynak Doğrulama Komutları

Bu rehber hazırlanırken kaynak kontrolü `awk` ile yapılmıştır. Aynı kontrolleri
tekrar çalıştırmak için:

```sh
find ../zed/crates -name '*.rs' -print0 |
  xargs -0 awk '/PlatformTitleBar::|PlatformTitleBar|render_left_window_controls|render_right_window_controls|ShowNextWindowTab|MergeAllWindows|set_button_layout|set_multi_workspace/ { print FILENAME ":" FNR ":" $0 }'
```

Public API yüzeyini görmek için:

```sh
find ../zed/crates/title_bar ../zed/crates/platform_title_bar -name '*.rs' -print0 |
  xargs -0 awk '/pub struct|pub enum|pub fn|actions!|impl Render|impl RenderOnce|impl ParentElement/ { print FILENAME ":" FNR ":" $0 }'
```

Pencere seçenekleri ve CSD bağlantılarını kontrol etmek için:

```sh
find ../zed/crates -name '*.rs' -print0 |
  xargs -0 awk '/WindowOptions|WindowDecorations|Decorations::Client|WindowControlArea|set_tabbing_identifier|button_layout\\(|tab_bar_visible\\(|start_window_move|show_window_menu/ { print FILENAME ":" FNR ":" $0 }'
```

`WindowButtonLayout` ayar zincirini görmek için:

```sh
find ../zed/crates/gpui/src ../zed/crates/settings_content/src ../zed/crates/title_bar/src -name '*.rs' -print0 |
  xargs -0 awk '/WindowButtonLayout|WindowButton|button_layout|into_layout|observe_button_layout_changed/ { print FILENAME ":" FNR ":" $0 }'
```

## 16. Sık Yapılan Hatalar

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
- App-specific menüleri `PlatformTitleBar` içine gömmek. Daha temiz model,
  platform kabuğunu ayrı, ürün titlebar içeriğini ayrı tutmaktır.

## 17. Uygulama Katmanına Önerilen Model

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
