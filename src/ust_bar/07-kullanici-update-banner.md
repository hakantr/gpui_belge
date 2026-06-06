# Kullanıcı menüsü, oturum açma, plan çipi, güncelleme ve duyuru bandı

Başlığın sağ grubu hesap ve uygulama durumunu özetler: oturum açık mı, hangi plan, bir güncelleme var mı ve duyurulacak bir şey var mı. Bu bölüm bu parçaları birlikte ele alır; hepsi `TitleBarSettings` alanlarına ve oturum/güncelleme durumuna bağlı koşullu çizersin.

## 1. Oturum durumuna göre üç hâl

Render geçişi, kullanıcı ve `Client` bağlantı durumuna bakarak sağ grupta üç farklı şeyden birini gösterir:

- **Oturum açık** (`current_user` var): kullanıcı menüsü butonu çizersin.
- **Oturum açılıyor** (kullanıcı henüz yok ama durum `Authenticating`/`Authenticated`/`Connecting`): kaynak arayüzde titreşen bir `"Signing in…"` etiketi gösterilir. Bu etiket 2 saniyelik bir animasyonla 0.4-0.8 arası alfa değerinde nabız gibi yanıp söner; kullanıcıya "bekle, bağlanıyorum" sinyali verir. Türkçe portta görünür metin `"Oturum açılıyor…"` gibi yerelleştirilebilir.
- **Oturum kapalı veya kimlik hatası** (`SignedOut`/`AuthenticationError`) ve `show_sign_in` açık: kaynak arayüzde `"Sign In"` butonu çizersin. Türkçe portta görünür metin `"Oturum Aç"` gibi yerelleştirilebilir.

```rust
pub fn render_sign_in_button(&mut self, _: &mut Context<Self>) -> Button
pub fn render_user_menu_button(&mut self, cx: &mut Context<Self>) -> impl Element
```

Bu üç hâl birbirini dışlar; aynı anda yalnız biri görünür. Port hedefinde bir hesap/oturum sistemin varsa aynı durum makinesini kurarsın: açık → menü, açılıyor → geçici gösterge, kapalı → giriş daveti. Hesap sistemi yoksa bu yüzeyin tamamı kaldırılır.

## 2. Kullanıcı menüsü

Kullanıcı menüsü butonunun tetikleyicisi oturum durumuna ve `show_user_picture` ayarına göre değişir: oturum açık ve avatar gösterimi açıksa kullanıcının avatarı; aksi halde bir aşağı ok ikonu kullanırsın. Bir güncelleme menüde gösterilecekse avatarın köşesine küçük bir vurgu noktası eklenir; böylece kullanıcı menüyü açmadan güncelleme olduğunu fark eder.

Menü açıldığında bir açılır panel içinde hesap ve uygulama eylemleri listelenir: abonelik planı, varsa organizasyon bilgisi, ayarlar/tuş eşlemi/temalar gibi geçişler ve oturumu kapatma. `ToggleUserMenu` eylemi bu menüyü klavyeyle de açıp kapatmayı sağlar.

AI etkinken menüde ayrıca bir **"Panel Yerleşimi" alt menüsü** çizilir; bu alt menü çalışma alanı düzenini `"Klasik"` (editör odaklı) ve `"Ajanlı"` (AI panel düzeni) arasında değiştirir. İki giriş sırasıyla `UseClassicLayout` ve `UseAgenticLayout` eylemlerini gönderir; yürürlükteki düzen alt menüde işaretli görünür. Bu eylemler `workspace` ad alanındadır, bu yüzden komut paletinden veya bir klavye kısayoluna bağlanarak da çağrılabilir. Bir eylem tetiklendiğinde `AgentSettings::set_layout(...)` seçilen düzeni kullanıcının ayar dosyasına yazar (`UseClassicLayout` -> `WindowLayout::Editor`, `UseAgenticLayout` -> `WindowLayout::Agent`); böylece seçim kalıcıdır. AI devre dışıyken (`DisableAiSettings.disable_ai`) hem alt menü çizilmez hem de iki eylem komut paletinden gizlenir.

## 3. Plan çipi

Kullanıcının abonelik planı, kullanıcı menüsü içinde küçük bir etiket (`PlanChip`) olarak gösterilir:

```rust
pub fn new(plan: Plan) -> Self
```

`PlanChip`, `cloud_api_types::Plan` değerini alır ve plana göre renklendirilmiş bir etiket çizer: ücretsiz plan nötr renkte, ücretli planlar (Pro, Business, Pro Trial, Student gibi) vurgu renginde ve daha belirgin bir arka planla. Renkler tema token'larından gelir; bu yüzden açık/koyu temada otomatik uyumludur.

Plan bilgisi yalnız kullanıcının bir abonelik dönemi varsa gösterilir; eski ücretsiz durumdaki kullanıcılarda çip gizlenir. Port hedefinde bir abonelik modelin yoksa bu parça hiç gerekmez; varsa aynı kalıbı kurarsın: planı tek bir enum'dan oku, plana göre renk seç, küçük bir etiket çiz.

## 4. Güncelleme bildirimi (`UpdateVersion`)

`UpdateVersion`, otomatik güncelleme durumunu başlıkta gösteren bir çocuk entity'dir. Zed'in `auto_update` durumlarını izler ve duruma göre farklı bir buton çizer:

| Durum | Görünüm |
| :-- | :-- |
| `Checking` | Yalnız manuel kontrolde; dönen `LoadCircle` ikonu. |
| `Downloading { version }` | İndirme göstergesi; ipucunda sürüm. |
| `Installing { version }` | Kurulum göstergesi; ipucunda sürüm. |
| `Updated { version }` | Tıklanınca çalışma alanı yeniden yüklenir; kapatılabilir. |
| `Errored { error }` | Görünür buton etiketi `"Failed to Update"`; hata ayrıntısı ise ipucuna konan ham hata metnidir. Tıklanınca uygulama günlüğü açılır; kapatılabilir. Türkçe portta görünür etiket anlam korunarak yerelleştirilir. |
| `Idle` (ve manuel olmayan `Checking`) | Hiçbir şey çizilmez. |

Görsel kabuk, `ui` crate'indeki `UpdateButton` bileşenidir ve bu durumların her biri için ayrı bir kurucu sunar. `Checking`, `Downloading`, `Installing` durumlarında buton `disabled(true)` ile gelir; yani indirme/kurulum sürerken kullanıcı tekrar tıklayıp aynı işi başlatamaz.

İpucu metni `version_tooltip_message` ile üretilir:

```rust
fn version_tooltip_message(version: &VersionCheckType) -> String
```

Bu yardımcı yalnız indirme, kurulum ve güncelleme-hazır durumlarında çağrılır; bu durumların ipucu `"Update to Version: {version}"` kalıbındadır. Sürüm semantik bir versiyon ise sürüm numarası, commit SHA ise **kısaltılmamış tam SHA** kullanırsın. Hata durumunda ise ipucu bu kalıba uymaz; doğrudan ham hata metnidir. Manuel kontroldeki `Checking` durumunda hiç ipucu yoktur. Türkçe portta bu metin yerelleştirilecekse aynı veri ayrımı korunur; başlıkta kısa SHA değil, tam hash gösterilir.

`SimulateUpdateAvailable` eylemi, bu yüzeyi geliştirme sırasında test etmek içindir: `toggle_update_simulation` aracılığıyla `UpdateVersion`'ı durumlar arasında döndürür, böylece her durumun görünümü gerçek bir güncelleme beklemeden denenebilir.

Port hedefinde bir otomatik güncelleme yığının varsa aynı durum makinesini kurarsın: arka plan kontrolü bir durum yayını üretir, başlık bu durumu izleyip uygun butonu çizer, devam eden işlemler sırasında butonu devre dışı bırakır. Güncelleme yoksa bu parça kaldırılır.

## 5. Duyuru bandı (güncel durumu)

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

Tasarım şudur: duyuru bandı bir kaynak kimliği (telemetri/kapatma anahtarı), bir ikon, bir ana metin, opsiyonel bir alt metin (verilmezse varsayılan olarak `"Introducing:"` öneki kullanırsın, bu yüzden pratikte daima bir alt metin çizilir) ve tıklamada gönderilecek bir eylem alır. `visible_when` ile bir koşul işlevi verilir; bu koşul her render geçişinde çağrılır ve duyuru bandının görünürlüğünü (örneğin bir özellik bayrağına göre) belirler. Kullanıcı bandı tıklarsa eylem gönderilir ve bant kapanır; kapatma (X) butonuna basarsa yalnız kapanır. Her iki durumda da kapatma kalıcı kaydedersin, böylece bant tekrar gösterilmez. `restore_banner` ise bu kaydı silip bandı yeniden görünür yapar (yönetim/test amaçlı).

**Güncel HEAD'in önemli notu:** Bu altyapı kodda hazır olsa da, şu anki Zed sürümünde `TitleBar`'ın `banner` alanı her zaman `None`'dır; `OnboardingBanner::new` hiçbir yerde çağrılmaz. Yani duyuru bandı mekanizması **mevcut ama bağlı değildir**; başlıkta fiilen bir duyuru bandı çizilmez. Render yolu `show_onboarding_banner` ayarı ve `banner` alanının `Some` olması koşuluna bağlı olduğundan, alan `None` kaldıkça bu yol hiç çalışmaz.

Port hedefinde duyuru bandı istiyorsan, aynı kalıp iyi bir şablondur: tek bir duyuru bandı entity'si kur, görünürlüğünü bir koşul işlevine bağla, kapatma durumunu kalıcı sakla ve gerektiğinde geri getir. Bu parçanın yeri platform kabuğu değil, ürün başlığı katmanıdır; çünkü duyuru içeriği ürünün diline aittir.
