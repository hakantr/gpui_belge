# Hedef, kapsam ve lisans

Üst bar konusuna geçmeden önce üç sorunun cevabı net olmalıdır: tam olarak ne port ediliyor, hangi sorumluluk hangi katmanda kalıyor ve lisans sınırı nereden geçiyor. Bu bölüm bu üç çerçeveyi sakin biçimde kurar. Sonraki bölümlerin tamamı bu ayrımların üstüne oturur.

## 1. Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama state

Yapıyı aşağıdan yukarıya okumak en kolay yoldur. En altta **platform kabuğu** vardır. Bu katmandan beklenen şey **davranış paritesi**dir: Zed pencereyle nasıl konuşuyorsa, hangi platformda hangi butonu nereye koyuyorsa, port edilen kabuk da aynı davranışı verir. Üstteki iki katmanda ise ürünün kendi kararları devreye girer. Ekranda neyin görüneceği, hangi renklerin kullanılacağı, hangi menünün açılacağı ve hangi action'ın dispatch edileceği ürün tarafının sorumluluğudur.

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

**Platform kabuğu (en alt katman) — `mirror`:** Bu katmanda Zed'in `platform_title_bar` crate'indeki **davranış** yeniden kurulur. Hit-test alanları, drag akışı ve platforma göre pencere butonlarının nerede render edileceği Zed sözleşmesiyle uyumlu ilerler. Burada amaç yeni bir tasarım denemek değildir; hedef, kullanıcının platformdan beklediği davranışı bozmadan yakalamaktır. Bu katman Bölüm V'te detaylı anlatılır. **Lisans nedeniyle kaynak kodu kopyalanmaz**; yalnızca API'lerin gözlemlenebilir davranışı kendi kelimelerimizle yeniden kurulur.

**Ürün başlığı (orta katman) — `senin tasarımın`:** Kullanıcının başlık çubuğunda gördüğü ürün içeriği burada yaşar. Menü, proje adı, durum çipleri, kullanıcı avatarı ve benzeri parçalar ürünün kendi tasarım diliyle üretilir. Bu içerik platform kabuğuna **child** olarak verilir ve her render geçişinde yeniden iletilir. Bu tüketim modeli Konu 16'da `set_children` üzerinden anlatılır. Mantık, tema rehberindeki "Faz 5 — UI tüketim" bölümüyle aynıdır: tema okunur, mevcut state'e göre arayüz çizilir.

**Uygulama state (en üst katman) — `karar otoritesi`:** Platform kabuğunun ihtiyaç duyduğu **politika** kararları bu katmandan gelir. "Close butonu tam olarak neyi kapatıyor?", "Yeni pencere hangi action ile açılıyor?", "Linux butonları sağda mı solda mı duruyor?", "Sidebar açık mı kapalı mı?" gibi soruların cevabı uygulama state'inde tutulur. Bu cevaplar platform kabuğuna doğrudan `AppState` verisi olarak değil, bir **trait sözleşmesi** üzerinden iletilir (`TitleBarController` — Konu 10 sonu).

**Bağımlılık yönü:**

```
Uygulama state  ←─reads─  Ürün başlığı  ←─child of─  Platform kabuğu
                                                      │
                                                      └─reads─  TitleBarController
                                                                (uygulama state'inden trait obj)
```

Platform kabuğu, ürünün `AppState` tipini doğrudan tanımaz; yalnızca `TitleBarController` trait'ini bilir. Bu tek yönlü ilişki platform kabuğunu **bağımsız test edilebilir** tutar. Testlerde gerçek uygulama state'ini ayağa kaldırmak yerine, trait'i implement eden küçük bir mock yeterli olur.

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

Sync turlarında bu eşleme tablosu, `platform_title_bar_aktarimi.md` günlüğüyle birlikte **referans kaynak** olarak kullanılır. Zed sözleşmesine yeni bir kavram girdiğinde, bu kavramın uygulama tarafında hangi tipe karşılık geleceği önce bu tablo üzerinden belirlenir. Kod yazımına ancak bu eşleşme netleştikten sonra geçilir.

---

## 2. Temel ilke: platform katmanı bilir, ürün katmanı karar verir

Katmanlamanın özeti şudur: **platform kabuğu pencerenin mekaniğini bilir; ürün katmanı ise neyin kapanacağına, hangi menünün açılacağına ve hangi workspace'in taşınacağına karar verir.** Bu ayrım akılda kaldığında rehberin geri kalanı çok daha kolay okunur.

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

1. **Platform davranışı evrenseldir.** Bir Linux kullanıcısı kendi pencere yöneticisinin button layout ayarının çalışmasını bekler. Kendi compositor'unun resize edge davranışına da alışmıştır. Ürün bu beklentilerle kavga etmez; onları olduğu gibi kullanır. Aksi halde kullanıcı doğal olarak "neden bu uygulama benim sistemim gibi davranmıyor?" diye sorar.
2. **Ürün anlamı uygulamaya özgüdür.** "Close" her uygulamada aynı şey değildir. Zed'de bir workspace kapanır, bir metin editörde aktif doküman kapanır, bir launcher uygulamasında pencere yalnızca gizlenebilir. Platform bu farkı bilmez, bilmesine de gerek yoktur. Bu karar ürün katmanına aittir.
3. **Test izolasyonu için gereklidir.** Platform kabuğu test edilirken gerçek bir `AppState` ayağa kaldırmak zorunda kalınmaz. Basit bir mock `TitleBarController` ile aynı testler yürütülebilir. Bu da testleri hem hızlandırır hem daha güvenilir kılar.

### Kontrol listesi: bir davranış hangi katmana yerleştirilmeli?

Yeni bir davranış eklenirken yer kararını üç soru ile vermek yeterlidir:

1. **Bu davranış pencere yöneticisinin veya işletim sisteminin sözleşmesini mi takip ediyor?** Cevap evet ise yer **platform katmanıdır**.
2. **Bu davranış uygulamanın iş kuralına mı bağlı?** Cevap evet ise yer **ürün katmanı** veya `AppState`'tir.
3. **Bu davranış hangi katmanda kalırsa aynı kabuk başka uygulamalarda da kullanılabilir?** Doğru cevap genellikle buradadır. Genel olan platformda, ürüne özel olan ürün katmanında kalır.

> **Örnek hatalı yerleşim:** "Close butonuna tıklandığında SaveModal aç" kuralı **ürün katmanında** olmalıdır. Platform kabuğu yalnızca "close intent" dispatch eder. Modal açılıp açılmayacağına `AppState` karar verir. Bu karar platforma sızarsa kabuk tek bir uygulamaya bağlanır ve başka projede rahatça kullanılamaz.

### "Tema rehberindeki Temel ilke ile farkı"

Tema rehberinin Konu 2'si **veri sözleşmesinde dışlama yok** kuralını anlatıyordu: Zed'in tema alanlarının tamamı mirror edilmeli. Bu rehberin Konu 2'si ise **kapsam farkını** anlatır: platform, ürün ve state birbirine karıştırılmaz. İki kural aynı düşünceye dayanır: Zed'den gelen sözleşme temiz biçimde korunur, ürünün anlamı ise uygulamanın kendi kodunda kalır.

### Tuzaklar

1. **Close action'ını platforma sabitlemek.** `PlatformTitleBar` içine doğrudan `close_action: Box::new(workspace::CloseWindow)` yazılırsa platform kabuğu Zed'in kendi action tipine bağlanır ve başka bir uygulamaya bu haliyle taşınamaz. Bu yüzden close action'ı **her zaman dışarıdan**, controller veya parametre yoluyla geçirilir.
2. **Çift tıklama davranışını ürüne sızdırmak.** macOS tarafında çift tıklama `window.titlebar_double_click()` ile sisteme devredilir. Bu davranış platform sözleşmesinin parçasıdır. Ürün burada araya girip `cx.dispatch_action(ZoomWorkspace)` çağırırsa macOS kullanıcısının sistem ayarları yok sayılmış olur.
3. **Sidebar açıkken pencere kontrollerini gizleme kararını yanlış yere koymak.** Bu konu Konu 15'te ele alınır. Sidebar bilgisi `TitleBarController` üzerinden gelir. Platform kabuğu doğrudan workspace state'ini sorgulamaz; çünkü "sidebar" kavramı platforma değil, ürüne aittir.
4. **Native tab kararını ürüne kapatmak.** `tabbing_identifier` alanının verilip verilmemesi tek başına ürün içeriğinde çözülmez. Bu bilgi `TitleBarController::use_system_window_tabs` üzerinden okunur. Platform kabuğu native tab desteğinin açık olup olmadığına kendi başına karar vermez.

---

## 3. Lisans-temiz çalışma protokolü

Zed'in `platform_title_bar` ve `title_bar` crate'leri **GPL-3.0-or-later** lisansı altındadır. Bu lisans, kod gövdesinin kopyalanamayacağı anlamına gelir. Buna karşılık API imzaları, JSON sözleşmeleri ve gözlemlenebilir davranış kuralları mirror edilebilir. Kısacası satır satır kopyalama yasaktır; ama "Zed'de şu alana basınca şu davranış çalışıyor" gözlemi yasak değildir. Bu davranış ürünün kendi kodunda, kendi kelimeleri ve kendi yapısıyla yeniden kurulabilir.

> **Tema rehberi Konu 3 ile fark:** Tema sözleşmesi alan adlarını mirror eder; yani veri şekli aynı tutulur. Burada ise **davranış** mirror edilir. "Mouse'a basıldığında pencere sürüklenmeye başlar" veya "close butonu ana caption'ın sağ ucunda durur" gibi gözlemlenebilir davranışlar telif kapsamında olmadığı için yeniden inşa edilebilir.

### Yapılabilir / Yapılamaz

| Yapılabilir | Yapılamaz |
|-------------|-----------|
| API imzalarını gözlemleyip yeniden yazmak (örn. `pub fn set_button_layout(...)`) | `crates/platform_title_bar/src/*.rs` kod gövdesini kopyalamak |
| Davranışı tarif edip kendi kelimelerinle implement etmek | Doc comment'i kelime kelime taşımak |
| `WindowControlArea` enum varyantlarını mirror etmek (gpui'den, Apache-2.0) | Zed'in `LinuxWindowControls` impl'ini taşımak |
| `WindowButton` enum varyantlarını ve `WindowButtonLayout` struct şeklini mirror etmek (gpui'den) | Zed'in render fonksiyonlarını birebir Rust → Rust kopyalamak |
| Platform-spesifik bilinen davranışları (hit-test, dbl-click, Windows native close rengi gibi) yeniden yazmak | Zed'e özgü tema/stil paletini veya render zincirini birebir taşımak |
| Sözleşme parite tabloları çıkarmak (sync turunda) | Zed'in mevcut SVG icon dosyalarını binary olarak gömmek |

### Lisans açısından güvenli dependency'ler (hepsi Apache-2.0)

- **`gpui`** — Pencere ve render katmanının çekirdeği. `WindowOptions`, `TitlebarOptions`, `WindowControlArea`, `WindowButtonLayout`, `WindowDecorations` gibi tipler ve `Window` üzerindeki `start_window_move`, `minimize_window`, `zoom_window`, `show_window_menu`, `titlebar_double_click`, `set_client_inset`, `tab_bar_visible`, `set_tabbing_identifier` gibi metotlar bu crate'ten alınır.
- **`refineable`** — Style cascade desenleri için kullanılır; tema rehberindeki kullanım gibi. Üst barda çoğu durumda zorunlu değildir, ama daha karmaşık stil zincirlerinde işe yarar.
- **`collections`** — Zed'in `HashMap` ve `IndexMap` wrapper'larını içerir; Zed ile aynı koleksiyon davranışına ihtiyaç duyulduğunda eklenebilir.

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

Bu rehber **üçüncü yolu** anlatır. Birinci veya ikinci yolu seçenler için de rehber faydalıdır; Bölüm II-V referans amacıyla okunabilir. Bu durumda "port" kelimesi geçen yerler "kullan" diye düşünülebilir, çünkü aynı kod onlar için zaten hazırdır.

### Doc comment yazımı

Zed kaynak dosyasındaki bir fonksiyon imzası mirror ediliyorsa, doc comment de **kendi sözcüklerimizle** yeniden yazılır. Orijinal cümle aynen taşınmaz. Örnek:

```rust
// Zed'de (mirror EDİLMEZ — birebir kopyalama):
/// Renders the left window controls for Linux client-side decorations.

// Portta (mirror EDİLİR — yeniden yazılmış):
/// Linux client-side decoration durumunda sol kenar pencere butonlarını
/// üretir; layout boş ise `None` döner.
pub fn render_left_window_controls(...) -> Option<impl IntoElement> { ... }
```

İki yorum da aynı fonksiyonu anlatır. Fakat ikincisi orijinal cümlenin ne kelimelerini ne de cümle yapısını taşır.

### Publishing uyarısı

`gpui` crate'i bu Zed sürümünde Apache-2.0 lisansıyla `publish = true` durumundadır. Buna karşılık `refineable` ve `collections` gibi bazı yardımcı workspace crate'leri hâlâ `publish = false` işaretlidir. Bu nedenle crates.io'ya yayımlanacak bir kütüphanede yalnız `gpui` kullanımı tek başına engel değildir; ancak publish edilmeyen workspace crate'lerine path veya git dependency ile bağlanılıyorsa aşağıdaki üç çözümden biri gerekir. Bunlar tema rehberi Konu 3 ile de örtüşür:

1. **Vendor yolu:** Kaynak kod kendi monorepo'ya kopyalanır; lisans ve atribüsyon bilgileri korunur.
2. **Fork yayınlama:** Publish edilmeyen yardımcı crate'ler kendi adları altında crates.io'ya yayımlanır.
3. **Yalnızca dahili kullanım:** Uygulama binary olarak (kütüphane olarak değil) dağıtılıyorsa git dependency yeterlidir.

### Tuzaklar

1. **"Hangi dosya GPL?" sorusunu hiç sormamak.** `crates/platform_title_bar/` altındaki **her dosya** GPL'dir. Buradan tek bir küçük helper fonksiyon bile taşınırsa lisans ihlali oluşur. "Küçük bir parça sorun olmaz" varsayımı burada güvenli değildir.
2. **API imzasını "yeniden yazmak" sanıp gövdeyi kelime farkıyla kopyalamak.** `pub fn render_right_window_controls(button_layout, close_action, window)` ile aynı isim ve parametreleri kullanmak imza paritesidir; tek başına kopya sayılmaz. Buna karşılık **gövde** içindeki match/if/loop zincirini birebir taşımak açık bir kopyadır. Gövde her zaman yeniden çözülmeli ve kendi koduyla yazılmalıdır.
3. **Lisans kontrolünü "sonra bakarız" diye ertelemek.** GPL kod bir kez taşındığında uygulamanın tamamı GPL etkisine girer. Bunu sonradan fark etmek çoğu zaman `cargo deny` gibi araçlarla bile kolay yakalanmaz. Bu yüzden lisans yaklaşımı **ilk port satırı yazılmadan önce** netleştirilir.
4. **`cargo deny check licenses` çalıştırmamak.** Yanlışlıkla transit bir GPL dependency'si projeye sızarsa bu komut CI'da uyarı verir (Bölüm III, Konu 8 sonunda detayı vardır). Komutun çalıştırılmaması ihlalin geç fark edilmesine yol açar.

---

## 4. Kapsam ve port yaklaşımları

`platform_title_bar` dışarıdan bakıldığında basit bir toolbar bileşeni gibi görünebilir. Aslında bundan daha fazlasıdır. Zed içinde aynı anda birden çok işi yürütür:

- Pencereyi sürüklenebilir yapan başlık çubuğu yüzeyini üretir.
- Linux client-side decoration (CSD) durumunda sol veya sağ pencere butonlarını render eder.
- Windows tarafında caption button hit-test alanlarını GPUI'nin `WindowControlArea` API'si üzerinden platforma bildirir.
- macOS tarafında trafik ışıklarına yer ayırır ve çift tıklama davranışını sistem titlebar davranışına iletir.
- `SystemWindowTabs` aracılığıyla native pencere sekmelerinin yüzeyini üretir: sekme çubuğu görünürlüğü, sekme kapatma, sekme sürükleme, sekmeyi yeni pencereye alma ve tüm pencereleri birleştirme davranışlarını birlikte bağlar.
- Zed workspace katmanındaki `CloseWindow`, `OpenRecent`, `WorkspaceSettings`, `ItemSettings`, `MultiWorkspace` gibi tipleri ve tema token'larını kullanır.

Bu paket bir uygulamaya alınırken iki ana yaklaşım söz konusudur:

1. **Zed ekosistemi içinde doğrudan kullanım.** `platform_title_bar` crate'i olduğu gibi tüketilir. Bu yolun ön koşulu, uygulamada Zed'in `workspace`, `settings`, `theme`, `ui`, `project` ve `zed_actions` crate'lerinin de mevcut olmasıdır.
2. **Bağımsız GPUI uygulaması için port.** Render davranışı korunur, ama Zed'e özgü action ve ayarlar ürünün kendi tipleriyle değiştirilir. Zed dışında bir uygulama için bu, kontrolün elde tutulduğu daha temiz yoldur.

Hangi yol seçilirse seçilsin, kod kopyalama veya birebir uyarlama gündeme geldiğinde `crates/platform_title_bar` paketinin `GPL-3.0-or-later` lisanslı olduğu unutulmamalıdır. Karar bu bilgiyle verilmelidir.

---
