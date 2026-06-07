# Hedef, kapsam ve lisans

Üst bar konusuna geçmeden önce üç sorunun cevabı net olmalıdır: Tam olarak ne port ediliyor, hangi sorumluluk hangi katmanda kalıyor ve lisans sınırı nereden geçiyor. Bu bölüm, söz konusu üç çerçeveyi net bir biçimde kurar. Sonraki bölümlerin tamamı bu ayrımların üzerine oturur.

## 1. Üç katmanlı yaklaşım: platform kabuğu / ürün başlığı / uygulama durumu

Yapıyı aşağıdan yukarıya okumak en kolay yoldur. En altta **platform kabuğu** yer alır. Bu katmandan beklenen şey **davranış paritesi**dir: Zed pencereyle nasıl iletişim kuruyorsa, hangi platformda hangi butonu nereye koyuyorsa, port edilen kabuk da aynı davranışı sergiler. Üstteki iki katmanda ise ürünün kendi kararları devreye girer. Ekranda neyin görüneceği, hangi renklerin kullanılacağı, hangi menünün açılacağı ve hangi eylemin gönderileceği ürün tarafının sorumluluğudur.

```text
┌─────────────────────────────────────────────────────────────────┐
│  Uygulama durumu (senin kodun)                                  │
│  - TitleBarController trait                                     │
│  - kapat_eylemi, yeni_pencere_eylemi, buton_yerlesimi, yan_panel │
│  - UygulamaDurumu / CalismaAlaniDurumu / BelgeDurumu            │
├─────────────────────────────────────────────────────────────────┤
│  Ürün başlığı (kendi tasarımın, AppTitleBar)                    │
│  - Uygulama menüsü, proje/doküman adı, kullanıcı menüsü         │
│  - Tema renkleri, branş göstergesi, durum çipleri               │
│  - PlatformTitleBar entity'sine çocuk olarak verilir            │
├─────────────────────────────────────────────────────────────────┤
│  Platform kabuğu (port edilmiş, kvs_titlebar)                   │
│  - PlatformTitleBar: drag alanı, arka plan, köşe yuvarlama      │
│  - Linux/Windows caption buton render'ları                      │
│  - macOS trafik ışığı padding'i ve dbl-click                    │
│  - Native pencere sekmeleri (opsiyonel)                         │
│  - GPUI: WindowOptions, WindowControlArea, WindowButtonLayout   │
└─────────────────────────────────────────────────────────────────┘
```

**Platform kabuğu (en alt katman) — `mirror`:** Bu katmanda Zed'in `platform_title_bar` crate'indeki **davranış** yeniden kurulur. Hit-test alanları, sürükleme akışı ve platforma göre pencere butonlarının nerede render edileceği Zed sözleşmesiyle uyumlu şekilde ilerler. Burada amaç yeni bir tasarım denemek değildir; hedef, kullanıcının platformdan beklediği davranışı bozmadan yakalamaktır. Bu katman ilgili bölümde detaylıca anlatılmaktadır. **Lisans kuralları nedeniyle kaynak kodunu kopyalamaman**; yalnızca API'lerin gözlemlenebilir davranışını kendi kelimelerinle yeniden kurman gerekir.

**Ürün başlığı (orta katman) — `senin tasarımın`:** Kullanıcının başlık çubuğunda gördüğü ürün içeriği burada yaşar. Menü, proje adı, durum çipleri, kullanıcı avatarı ve benzeri parçalar ürünün kendi tasarım diliyle üretilir. Bu içerik platform kabuğuna **çocuk** (child) olarak verilir ve her render geçişinde yeniden iletilir. Bu tüketim modeli ilgili bölümde `set_children` üzerinden açıklanmaktadır. Mantık, tema rehberindeki UI tüketim mantığıyla aynıdır: Tema okunur ve mevcut duruma göre arayüz çizilir.

**Uygulama durumu (en üst katman) — `karar otoritesi`:** Platform kabuğunun ihtiyaç duyduğu **politika** kararları bu katmandan gelir. "Kapat butonu tam olarak neyi kapatıyor?", "Yeni pencere hangi eylem ile açılıyor?", "Linux butonları sağda mı solda mı duruyor?", "Sidebar açık mı kapalı mı?" gibi soruların cevabı uygulama durumunda tutulur. Bu cevaplar platform kabuğuna doğrudan `UygulamaDurumu` verisi olarak değil, bir **trait sözleşmesi** üzerinden iletilir (`TitleBarController` — ilgili bölüm sonu).

**Bağımlılık yönü:**

```text
Uygulama durumu  ←─okur─  Ürün başlığı  ←─çocuğu─  Platform kabuğu
                                                      │
                                                      └─okur─  TitleBarController
                                                               (uygulama durumundan trait obj)
```

Platform kabuğu, ürünün `UygulamaDurumu` tipini doğrudan tanımaz; yalnızca `TitleBarController` trait'ini bilir. Bu tek yönlü ilişki platform kabuğunu **bağımsız test edilebilir** tutar. Testlerde gerçek uygulama durumunu ayağa kaldırmak yerine, trait'i implement eden küçük bir sahte nesne yeterli olur.

**Lisans katmanlama:**

| Katman | Lisans Tarafı |
| -------- | --------------- |
| Platform kabuğu | Davranış öğrenilir, kod kendi sözcüklerinle yazılır (GPL-3 kod gövdesi kopyalama yasak) |
| Ürün başlığı | Tamamen senin; Zed'in `title_bar` koduyla hiçbir ilgisi yok |
| Uygulama durumu | Tamamen senin; trait imzası `TitleBarController` çıkış API'sidir |

### Zed ile bu rehberin terim eşlemesi

| Zed | Bu Rehber |
| ----- | ----------- |
| `platform_title_bar` crate | `kvs_titlebar` crate (port edilmiş) |
| `title_bar` crate | `kvs_app_titlebar` veya uygulamanın kendi crate'i |
| `workspace::Workspace` | Uygulamanın kendi shell/window durumu |
| `WorkspaceSettings`, `ItemSettings` | Uygulamanın config sistemi |
| `MultiWorkspace`, `SidebarRenderState` | `TitleBarController::sidebar_state` |
| `zed_actions::OpenRecent` vb. | Uygulamanın kendi eylemleri |

Zed güncellemelerinde bu eşleme tablosu, `platform_title_bar_aktarimi.md` günlüğüyle birlikte **referans kaynak** olarak kullanılır. Zed sözleşmesine yeni bir kavram girdiğinde, bu kavramın uygulama tarafında hangi tipe karşılık geleceği önce bu tablo üzerinden belirlenir. Kod yazımına ancak bu eşleşme netleştikten sonra başlanır.

---

## 2. Temel ilke: platform katmanı bilir, ürün katmanı karar verir

Katmanlamanın özeti şudur: **Platform kabuğu pencerenin mekaniğini bilir.** Ürün katmanı ise neyin kapanacağına, hangi menünün açılacağına ve hangi workspace'in taşınacağına karar verir. Bu ayrım akılda tutulduğunda rehberin geri kalanı çok daha kolay anlaşılır.

### Üç şeyi ayırt et

| Soru | Sahibi |
| ------ | -------- |
| Fare buradan basıldı, pencere sürüklenmeli mi? | **Platform** (`start_window_move`) |
| Kapat butonuna basıldı, ne kapatılmalı? | **Ürün** (`UygulamaDurumu::kapat_eylemi`) |
| Pencere zoom edilmeli mi yoksa minimize mi? | **Platform** (Linux: `zoom_window`; macOS: sistem) |
| Workspace kirli, kaydetme modali açılmalı mı? | **Ürün** (`UygulamaDurumu::kapatma_niyeti`) |
| Linux pencere butonu hangi tarafta? | **Platform** + **Ürün** (buton yerleşimi ayardan) |
| Native tab açıldığında ne yapılır? | **Platform** (`SystemWindowTabController`) + **Ürün** (yeni pencere ne içeriyor) |
| Hit-test: bu piksel caption mı, sürükleme mi, içerik mi? | **Platform** (`WindowControlArea`) |
| Pencerenin teması (renk) ne? | **Ürün** (`cx.theme().title_bar_background`) |

### Gerekçe

1. **Platform davranışı evrenseldir.** Bir Linux kullanıcısı kendi pencere yöneticisinin button layout ayarının çalışmasını bekler. Kendi compositor'unun resize edge davranışına da alışmıştır. Ürün bu beklentilerle kavga etmez; onları olduğu gibi kullanır. Aksi halde kullanıcı doğal olarak "neden bu uygulama benim sistemim gibi davranmıyor?" diye sorar.
2. **Ürün anlamı uygulamaya özgüdür.** "Kapat" her uygulamada aynı şey değildir. Zed'de bir workspace kapanır, bir metin editörde aktif doküman kapanır, bir launcher uygulamasında pencere yalnızca gizlenebilir. Platform bu farkı bilmez, bilmesine de gerek yoktur. Bu karar ürün katmanına aittir.
3. **Test izolasyonu için gereklidir.** Platform kabuğu test edilirken gerçek bir `UygulamaDurumu` ayağa kaldırmak zorunda kalınmaz. Basit bir sahte `TitleBarController` ile aynı testler yürütülebilir. Bu da testleri hem hızlandırır hem daha güvenilir kılar.

### Kontrol listesi: bir davranış hangi katmana yerleştirilmeli?

Yeni bir davranış eklenirken yer kararını üç soru ile vermek yeterlidir:

1. **Bu davranış pencere yöneticisinin veya işletim sisteminin sözleşmesini mi takip ediyor?** Cevap evet ise yer **platform katmanıdır**.
2. **Bu davranış uygulamanın iş kuralına mı bağlı?** Cevap evet ise yer **ürün katmanı** veya `UygulamaDurumu`'dur.
3. **Bu davranış hangi katmanda kalırsa aynı kabuk başka uygulamalarda da kullanılabilir?** Doğru cevap genellikle bu noktada gizlidir. Genel olan platformda, ürüne özel olan ise ürün katmanında konumlandırılır.

> **Sınır dışı yerleşim örneği:** "Kapat butonuna tıklandığında KaydetmeModalı aç" kuralı **ürün katmanında** olmalıdır. Platform kabuğu yalnızca "kapatma niyeti" gönderir. Modal açılıp açılmayacağına `UygulamaDurumu` karar verir. Bu karar platforma sızarsa kabuk tek bir uygulamaya bağlanır ve başka projede rahatça kullanılamaz.

### "Tema rehberindeki Temel ilke ile farkı"

Tema rehberinin ilgili bölümü **veri sözleşmesinde dışlama yok** kuralını anlatıyordu: Zed'in tema alanlarının tamamı mirror edilmeli. Bu rehberin ilgili bölümü ise **kapsam farkını** anlatır: platform, ürün ve durum birbirine karıştırılmaz. İki kural aynı düşünceye dayanır: Zed'den gelen sözleşme temiz biçimde korunur, ürünün anlamı ise uygulamanın kendi kodunda kalır.

### Dikkat Noktaları

1. **Kapatma eylemini platforma sabitlemek.** `PlatformTitleBar` içine doğrudan `kapat_eylemi: Box::new(workspace::CloseWindow)` yazılırsa platform kabuğu Zed'in kendi eylem tipine bağlanır ve başka bir uygulamaya bu haliyle taşınamaz. Bu yüzden kapatma eylemi **her zaman dışarıdan**, controller veya parametre yoluyla geçirilir.
2. **Çift tıklama davranışını ürüne sızdırmak.** macOS tarafında çift tıklama `window.titlebar_double_click()` ile sisteme devredilir. Bu davranış platform sözleşmesinin parçasıdır. Ürün burada araya girip `cx.dispatch_action(ZoomWorkspace)` çağırırsa macOS kullanıcısının sistem ayarları yok sayılmış olur.
3. **Sidebar açıkken pencere kontrollerini gizleme kararının katmanını net tutmak.** Bu konu, ilgili bölümde ele alınmaktadır. Sidebar bilgisi `TitleBarController` aracılığıyla gelir. Platform kabuğu doğrudan workspace durumunu sorgulamaz; çünkü "sidebar" kavramı platforma değil, ürüne aittir.
4. **Native tab kararını ürüne kapatmak.** `tabbing_identifier` alanının verilip verilmemesi tek başına ürün içeriğinde çözülmez. Bu bilgi `TitleBarController::use_system_window_tabs` üzerinden okunur. Platform kabuğu native tab desteğinin açık olup olmadığına kendi başına karar vermez.

---

## 3. Lisans-temiz çalışma protokolü

Zed'in `platform_title_bar` ve `title_bar` crate'leri **GPL-3.0-or-later** lisansı altındadır. Bu lisans, kod gövdesinin kopyalanamayacağı anlamına gelir. Buna karşılık API imzaları, JSON sözleşmeleri ve gözlemlenebilir davranış kuralları mirror edilebilir. Kısacası satır satır kopyalama yasaktır; ama "Zed'de şu alana basınca şu davranış çalışıyor" gözlemi yasak değildir. Bu davranışı ürünün kendi kodunda, kendi kelimelerin ve kendi yapınla yeniden kurman gerekir.

> **Tema rehberi ilgili bölüm ile farkı:** Tema sözleşmesi alan adlarını mirror eder; yani veri şekli aynı tutulur. Burada ise **davranış** mirror edilir. "Fareye basıldığında pencere sürüklenmeye başlar" veya "kapat butonu ana caption'ın sağ ucunda durur" gibi gözlemlenebilir davranışlar telif kapsamında olmadığı için yeniden inşa edilebilir.

### Yapılabilir / Yapılamaz

| Yapılabilir | Yapılamaz |
| ------------- | ----------- |
| API imzalarını gözlemleyip yeniden yazmak (örn. `pub fn set_button_layout(...)`) | `platform_title_bar` crate'inin kaynak kod gövdesini kopyalamak |
| Davranışı tarif edip kendi kelimelerinle implement etmek | Belge yorumunu kelime kelime taşımak |
| `WindowControlArea` enum varyantlarını mirror etmek (gpui'den, Apache-2.0) | Zed'in `LinuxWindowControls` impl'ini taşımak |
| `WindowButton` enum varyantlarını ve `WindowButtonLayout` struct şeklini mirror etmek (gpui'den) | Zed'in render fonksiyonlarını birebir Rust → Rust kopyalamak |
| Platforma özgü bilinen davranışları (hit-test, dbl-click, Windows native kapat rengi gibi) yeniden yazmak | Zed'e özgü tema/stil paletini veya render zincirini birebir taşımak |
| Sözleşme parite tabloları çıkarmak (Zed güncellemesinde) | Zed'in mevcut SVG ikon dosyalarını binary olarak gömmek |

### Lisans açısından güvenli bağımlılıklar (hepsi Apache-2.0)

- **`gpui`** — Pencere ve render katmanının çekirdeği. `WindowOptions`, `TitlebarOptions`, `WindowControlArea`, `WindowButtonLayout`, `WindowDecorations` gibi tipler ve `Window` üzerindeki `start_window_move`, `minimize_window`, `zoom_window`, `show_window_menu`, `titlebar_double_click`, `set_client_inset`, `tab_bar_visible`, `set_tabbing_identifier` gibi metotlar bu crate'ten alınır.
- **`refineable`** — Style cascade desenleri için kullanılır; tema rehberindeki kullanım gibi. Üst barda çoğu durumda zorunlu değildir, ama daha karmaşık stil zincirlerinde işe yarar.
- **`collections`** — Zed'in `HashMap` ve `IndexMap` wrapper'larını içerir; Zed ile aynı koleksiyon davranışına ihtiyaç duyulduğunda eklenebilir.

**GPL-3 crate'ler (referans için okunur, asla bağımlılık olarak eklenmez):**

| Crate | Lisans | Bu Rehberin Yaklaşımı |
| ------- | -------- | ---------------------- |
| `platform_title_bar` | GPL-3.0-or-later | **Mirror** — Kendi `kvs_titlebar` yapısına aktarım |
| `title_bar` | GPL-3.0-or-later | **Mirror** — Kendi `kvs_app_titlebar` yapısına aktarım |
| `workspace` | GPL-3.0-or-later | **Sadece referans** — `client_side_decorations` benzeri elle yazılmalıdır. |
| `theme` | GPL-3.0-or-later | Tema rehberindeki gibi mirror (`kvs_tema`) |
| `theme_settings`, `theme_selector` | GPL-3.0-or-later | Sadece referans |
| `zed_actions` | GPL-3.0-or-later | Eylem karşılıkları kendi `app::actions!` makronla tanımlanmalıdır. |

### Üç port yaklaşımı ve lisans sonucu

| Yaklaşım | Lisans Sonucu | Kullanım Koşulu |
| ---------- | --------------- | ----------------- |
| **1. Doğrudan `platform_title_bar` bağımlılığı** | Senin uygulaman **GPL-3** olur | Sadece kendin GPL altında dağıtacaksan |
| **2. Crate'i vendor'la (kaynak kodu kopyala)** | Vendor'lanan kod **hâlâ GPL-3**; senin uygulaman da GPL-3 olur | Yine GPL hedefin varsa |
| **3. Davranış mirror'ı (kendi koddan yeniden yaz)** | Senin kodun **kendi lisansın** olur | **Lisans-temiz hedef için tek doğru yol** |

Bu rehber **üçüncü yolu** anlatır. Birinci veya ikinci yolu seçenler için de rehber faydalıdır; bu durumda "port" kelimesi geçen ifadeleri "kullan" şeklinde okumak yeterlidir, çünkü aynı kod onlar için zaten hazır durumdadır.

### Belge yorumu yazımı

Zed kaynak dosyasındaki bir fonksiyon imzası mirror ediliyorsa, belge yorumunu da **kendi sözcüklerinle** yeniden yazman gerekir. Orijinal cümle aynen taşınmamalıdır. Örnek:

```rust
// Zed'de (mirror EDİLMEZ — birebir kopyalama):
/// Linux client-side decoration için sol pencere kontrollerini render eder.

// Portta (mirror EDİLİR — yeniden yazılmış):
/// Linux client-side decoration durumunda sol kenar pencere butonlarını
/// üretir; yerleşim boş ise `None` döner.
pub fn sol_pencere_kontrollerini_render_et(...) -> Option<impl IntoElement> { ... }
```

İki yorum da aynı fonksiyonu anlatır. Fakat ikincisi orijinal cümlenin ne kelimelerini ne de cümle yapısını taşır.

### Yayınlama uyarısı

`gpui` crate'i bu Zed sürümünde Apache-2.0 lisansıyla `publish = true` durumundadır. Buna karşılık `refineable` and `collections` gibi bazı yardımcı workspace crate'leri hâlâ `publish = false` işaretlidir. Bu nedenle crates.io'ya yayımlanacak bir kütüphanede yalnız `gpui` kullanımı tek başına engel değildir; ancak yayımlanmayan workspace crate'lerine path veya git bağımlılığı ile bağlanılıyorsa aşağıdaki üç çözümden biri gerekir. Bunlar tema rehberi ilgili bölüm ile de örtüşür:

1. **Vendor yolu:** Kaynak kod kendi monorepo'ya kopyalanır; lisans ve atribüsyon bilgileri korunur.
2. **Fork yayınlama:** Publish edilmeyen yardımcı crate'ler kendi adları altında crates.io'ya yayımlanır.
3. **Yalnızca dahili kullanım:** Uygulama binary olarak (kütüphane olarak değil) dağıtılıyorsa git bağımlılığı yeterlidir.

### Dikkat Noktaları

1. **GPL dosya sınırını baştan netleştirmek.** `platform_title_bar` crate'indeki **her dosya** GPL'dir. Buradan tek bir küçük yardımcı fonksiyon bile taşınırsa lisans ihlali oluşur. "Küçük bir parça sorun olmaz" varsayımı burada güvenli değildir.
2. **API imzasını "yeniden yazmak" sanıp gövdeyi kelime farkıyla kopyalamak.** `pub fn sag_pencere_kontrollerini_render_et(buton_yerlesimi, kapat_eylemi, window)` gibi eşdeğer imza ve parametreleri kullanmak parite kurmaktır; tek başına kopya sayılmaz. Buna karşılık **gövde** içindeki `match`/`if`/`loop` zincirini birebir taşımak açık bir kopyadır. Gövdeyi her zaman yeniden çözmen; kendi kodunla yazman gerekir.
3. **Lisans kontrolünü başlangıç adımı yapmak.** GPL kod bir kez taşındığında uygulamanın tamamı GPL etkisine girer. Bunu sonradan fark etmek çoğu zaman `cargo deny` gibi araçlarla bile kolay yakalanmaz. Bu yüzden lisans yaklaşımı **ilk port satırı yazılmadan önce** netleştirilir.
4. **`cargo deny check licenses` kontrolünü CI'a eklemek.** Geçişli bir GPL bağımlılığı projeye girerse bu komut CI'da uyarı verir.

---

## 4. Kapsam ve port yaklaşımları

`platform_title_bar` dışarıdan bakıldığında basit bir araç çubuğu bileşeni gibi görünebilir. Aslında bundan daha fazlasıdır. Zed içinde aynı anda birden çok işi yürütür:

- Pencereyi sürüklenebilir yapan başlık çubuğu yüzeyini üretir.
- Linux client-side decoration (CSD) durumunda sol veya sağ pencere butonlarını render eder.
- Windows tarafında caption button hit-test alanlarını GPUI'nin `WindowControlArea` API'si üzerinden platforma bildirir.
- macOS tarafında trafik ışıklarına yer ayırır ve çift tıklama davranışını sistem titlebar davranışına iletir.
- `SystemWindowTabs` aracılığıyla native pencere sekmelerinin yüzeyini üretir: Sekme çubuğu görünürlüğü, sekme kapatma, sekme sürükleme, sekmeyi yeni pencereye alma ve tüm pencereleri birleştirme davranışlarını birlikte bağlar.
- Zed workspace katmanındaki `CloseWindow`, `OpenRecent`, `WorkspaceSettings`, `ItemSettings`, `MultiWorkspace` gibi tipleri ve tema token'larını kullanır.

Bu paket bir uygulamaya alınırken iki ana yaklaşım söz konusudur:

1. **Zed ekosistemi içinde doğrudan kullanım.** `platform_title_bar` crate'i olduğu gibi tüketilir. Bu yolun ön koşulu, uygulamada Zed'in `workspace`, `settings`, `theme`, `theme_settings`, `ui`, `project` ve `zed_actions` crate'lerinin de mevcut olmasıdır.
2. **Bağımsız GPUI uygulaması için port.** Render davranışı korunur, ama Zed'e özgü eylem ve ayarlar ürünün kendi tipleriyle değiştirilir. Zed dışında bir uygulama için bu, kontrolün elde tutulduğu daha temiz yoldur.

Hangi yol seçilirse seçilsin, kod kopyalama veya birebir uyarlama gündeme geldiğinde `platform_title_bar` paketinin `GPL-3.0-or-later` lisanslı olduğu dikkate alınmalıdır. Kararın bu bilgi doğrultusunda verilmesi gerekir.

---
