# Kullanıcı menüsü, sign-in, plan chip, güncelleme ve banner

Başlığın sağ grubu hesap ve uygulama durumunu özetler: oturum açık mı, hangi plan, bir güncelleme var mı ve duyurulacak bir şey var mı. Bu bölüm bu parçaları birlikte ele alır; hepsi `TitleBarSettings` alanlarına ve oturum/güncelleme durumuna bağlı koşullu çizilir.

## 1. Oturum durumuna göre üç hâl

Render, kullanıcı ve `Client` bağlantı durumuna bakarak sağ grupta üç farklı şeyden birini gösterir:

- **Oturum açık** (`current_user` var): kullanıcı menüsü butonu çizilir.
- **Oturum açılıyor** (kullanıcı henüz yok ama durum `Authenticating`/`Authenticated`/`Connecting`): titreşen bir "Signing in…" etiketi gösterilir. Bu etiket 2 saniyelik bir animasyonla 0.4–0.8 arası alfa değerinde nabız gibi yanıp söner; kullanıcıya "bekle, bağlanıyorum" sinyali verir.
- **Oturum kapalı veya kimlik hatası** (`SignedOut`/`AuthenticationError`) ve `show_sign_in` açık: "Sign In" butonu çizilir.

```rust
pub fn render_sign_in_button(&mut self, _: &mut Context<Self>) -> Button
pub fn render_user_menu_button(&mut self, cx: &mut Context<Self>) -> impl Element
```

Bu üç hâl birbirini dışlar; aynı anda yalnız biri görünür. Port hedefinde bir hesap/oturum sistemin varsa aynı durum makinesini kurarsın: açık → menü, açılıyor → geçici gösterge, kapalı → giriş daveti. Hesap sistemi yoksa bu yüzeyin tamamı kaldırılır.

## 2. Kullanıcı menüsü

Kullanıcı menüsü butonunun tetikleyicisi oturum durumuna ve `show_user_picture` ayarına göre değişir: oturum açık ve avatar gösterimi açıksa kullanıcının avatarı; aksi halde bir aşağı-ok (chevron) ikonu kullanılır. Bir güncelleme menüde gösterilecekse avatarın köşesine küçük bir vurgu noktası (indicator) eklenir; böylece kullanıcı menüyü açmadan güncelleme olduğunu fark eder.

Menü açıldığında bir popover içinde hesap ve uygulama eylemleri listelenir: abonelik planı, varsa organizasyon bilgisi, ayarlar/keymap/temalar gibi geçişler ve oturumu kapatma. `ToggleUserMenu` action'ı bu menüyü klavyeyle de açıp kapatmayı sağlar.

AI etkinken menüde ayrıca bir **"Panel Layout" alt menüsü** çizilir; bu alt menü çalışma alanı düzenini "Classic" (editör odaklı) ve "Agentic" (AI panel düzeni) arasında değiştirir. İki giriş sırasıyla `UseClassicLayout` ve `UseAgenticLayout` action'larını dispatch eder; yürürlükteki düzen alt menüde işaretli görünür. Bu action'lar `workspace` namespace'indedir, dolayısıyla komut paletinden veya bir klavye kısayoluna bağlanarak da çağrılabilir. Bir action tetiklendiğinde `AgentSettings::set_layout(...)` seçilen düzeni kullanıcının ayar dosyasına yazar (`UseClassicLayout` → `WindowLayout::Editor`, `UseAgenticLayout` → `WindowLayout::Agent`); böylece seçim kalıcıdır. AI devre dışıyken (`DisableAiSettings.disable_ai`) hem alt menü çizilmez hem de iki action komut paletinden gizlenir.

## 3. Plan chip

Kullanıcının abonelik planı, kullanıcı menüsü içinde küçük bir etiket (`PlanChip`) olarak gösterilir:

```rust
pub fn new(plan: Plan) -> Self
```

`PlanChip`, `cloud_api_types::Plan` değerini alır ve plana göre renklendirilmiş bir etiket çizer: ücretsiz plan nötr renkte, ücretli planlar (Pro, Business, Trial, Student gibi) vurgu renginde ve daha belirgin bir arka planla. Renkler tema token'larından gelir; bu yüzden açık/koyu temada otomatik uyumludur.

Plan bilgisi yalnız kullanıcının bir abonelik dönemi varsa gösterilir; eski "legacy free" durumundaki kullanıcılarda chip gizlenir. Port hedefinde bir abonelik modelin yoksa bu parça hiç gerekmez; varsa aynı kalıbı kurarsın: planı tek bir enum'dan oku, plana göre renk seç, küçük bir etiket çiz.

## 4. Güncelleme bildirimi (`UpdateVersion`)

`UpdateVersion`, otomatik güncelleme durumunu başlıkta gösteren bir child entity'dir. Zed'in `auto_update` durumlarını izler ve duruma göre farklı bir buton çizer:

| Durum | Görünüm |
| :-- | :-- |
| `Checking` | Yalnız manuel kontrolde; dönen `LoadCircle` spinner. |
| `Downloading { version }` | İndirme göstergesi; tooltip'te sürüm. |
| `Installing { version }` | Kurulum göstergesi; tooltip'te sürüm. |
| `Updated { version }` | Tıklanınca çalışma alanı yeniden yüklenir; kapatılabilir. |
| `Errored { error }` | "Failed to Update" mesajı; tıklanınca uygulama günlüğü açılır; kapatılabilir. |
| `Idle` (ve manuel olmayan `Checking`) | Hiçbir şey çizilmez. |

Görsel kabuk, `ui` crate'indeki `UpdateButton` bileşenidir ve bu durumların her biri için ayrı bir constructor sunar. `Checking`, `Downloading`, `Installing` durumlarında buton `disabled(true)` ile gelir; yani indirme/kurulum sürerken kullanıcı tekrar tıklayıp aynı işi başlatamaz.

Tooltip metni `version_tooltip_message` ile üretilir:

```rust
fn version_tooltip_message(version: &VersionCheckType) -> String
```

Metin her durumda `"Update to Version: {version}"` kalıbındadır. Sürüm semantik bir versiyon ise sürüm numarası, commit SHA ise **kısaltılmamış tam SHA** kullanılır. Yani başlıkta kısa SHA değil, tam hash gösterilir.

`SimulateUpdateAvailable` action'ı, bu yüzeyi geliştirme sırasında test etmek içindir: `toggle_update_simulation` aracılığıyla `UpdateVersion`'ı durumlar arasında döndürür, böylece her durumun görünümü gerçek bir güncelleme beklemeden denenebilir.

Port hedefinde bir otomatik güncelleme yığının varsa aynı durum makinesini kurarsın: arka plan kontrolü bir durum yayını üretir, başlık bu durumu izleyip uygun butonu çizer, devam eden işlemler sırasında butonu devre dışı bırakır. Güncelleme yoksa bu parça kaldırılır.

## 5. Onboarding banner (güncel durumu)

`OnboardingBanner`, başlıkta özellik duyurusu yapmak için tasarlanmış genel bir mekanizmadır. Kurucusu ve yardımcıları crate'te mevcuttur:

```rust
pub fn new(
    source: &str,
    icon_name: IconName,
    label: impl Into<SharedString>,
    subtitle: Option<SharedString>,
    action: Box<dyn Action>,
    cx: &mut Context<Self>,
) -> Self

pub fn visible_when(self, predicate: impl Fn(&mut App) -> bool + 'static) -> Self

pub fn restore_banner(cx: &mut App)
```

Tasarım şudur: banner bir kaynak kimliği (telemetri/dismiss anahtarı), bir ikon, bir ana metin, opsiyonel bir ön ek ve tıklamada dispatch edilecek bir action alır. `visible_when` ile bir predicate verilir; bu predicate her render'da çağrılır ve banner'ın görünürlüğünü (örneğin bir özellik bayrağına göre) belirler. Kullanıcı banner'ı tıklarsa action dispatch edilir ve banner kapanır; kapatma (X) butonuna basarsa yalnız kapanır. Her iki durumda da kapatma kalıcı kaydedilir, böylece banner tekrar gösterilmez. `restore_banner` ise bu kaydı silip banner'ı yeniden görünür yapar (yönetim/test amaçlı).

**Güncel HEAD'in önemli notu:** Bu altyapı kodda hazır olsa da, şu anki Zed sürümünde `TitleBar`'ın `banner` alanı her zaman `None`'dır; `OnboardingBanner::new` hiçbir yerde çağrılmaz. Yani banner mekanizması **mevcut ama bağlı değildir** — başlıkta fiilen bir banner çizilmez. Render yolu `show_onboarding_banner` ayarı ve `banner` alanının `Some` olması koşuluna bağlı olduğundan, alan `None` kaldıkça bu yol hiç çalışmaz.

Port hedefinde duyuru banner'ı istiyorsan, aynı kalıp iyi bir şablondur: tek bir banner entity'si kur, görünürlüğünü bir predicate'e bağla, kapatma durumunu kalıcı sakla ve gerektiğinde geri getir. Bu parçanın yeri platform kabuğu değil, ürün başlığı katmanıdır; çünkü duyuru içeriği ürünün diline aittir.
