# Proje, dal, sunucu ve kısıtlı mod göstergeleri

Başlığın sol grubu, kullanıcıya "şu an neredeyim" sorusunu yanıtlar: hangi proje, hangi Git dalı, uzak bir sunucuda mı, projeyi başkası mı paylaşıyor ve proje güvenli mi. Bu bölüm bu dört göstergeyi ayrı ayrı ele alır. Hepsi `TitleBarSettings` alanlarına bağlı koşullu çizilir.

## 1. Proje adı

Proje adı, `effective_active_worktree` ile seçilen çalışma ağacının kök adından üretilir. Ama ilgili çalışma ağacının bir deposu varsa, ad depo kimliğinden (`repo_identity_path`) yeniden yazılır; bu yüzden git'li projelerde gördüğün ad çoğunlukla çalışma ağacı klasörünün değil, deponun adıdır. Çok uzun adlar başlığı taşırmasın diye bir üst sınıra kadar kısaltılır:

```rust
const MAX_PROJECT_NAME_LENGTH: usize = 40;
```

Görsel olarak proje adı tıklanabilir bir tetikleyicidir; tıklanınca son projeler açılır paneli açılır. Birden çok çalışma ağacı açıksa adın yanında bir aşağı ok belirir; bu, başlığın çoklu çalışma ağacı modunda olduğunun işaretidir. Proje adı yalnız `show_project_items` ayarı açıkken çizilir.

Port hedefinde proje/doküman adı genellikle tek bir çalışma ağacı veya açık dosyadan gelir. Aynı kısaltma sınırını kendi modelinde uygularsın; çoklu proje desteklemiyorsan aşağı ok ve açılır panel kısmını tamamen atlayabilirsin.

## 2. Git dalı ve çalışma ağacı

Git etkinse, proje adının yanına git yüzeyi eklenir. Bu yüzey birkaç parçadan oluşur:

- **Çalışma ağacı seçici**: git etkin ve depo varsa koşulsuz çizilen bir açılır panel tetikleyici; etiketi bağlı çalışma ağacının adıdır, bu ad yoksa `"main"`'e düşer. (Birden çok çalışma ağacı koşulu bu tetikleyiciye değil, yalnız proje adının yanındaki aşağı oka uygulanır.)
- **Dal adı**: aktif dal bir açılır panel tetikleyicide gösterilir; `MAX_BRANCH_NAME_LENGTH` (40) sınırına kadar kısaltılır. Detached HEAD durumunda butonun görünür metni her zaman `"Create Branch"` (port karşılığı `"Dal Oluştur"`) olur ve bir `GitBranchPlus` ikonu taşır; kısa commit SHA'sı (`MAX_SHORT_SHA_LENGTH` = 8 karakter) buton metni olarak değil, yalnız ipucunda `"Detached HEAD: {sha}"` biçiminde görünür.
- **Başlangıç ikonu**: dal butonu çiziliyorsa, butonun başında her zaman bir ikon bulunur. `show_branch_status_icon` açıksa bu ikon çalışma ağacının git durumunu özetler (değişmiş/eklenmiş/silinmiş/çakışma gibi); kapalıysa düz bir `GitBranch` ikonuna düşer.

Dal tetikleyicisi bir açılır panel düğmesidir; tıklayınca git dal ve stash seçicisini bir açılır panelde açar (ipucu `zed_actions::git::Branch` eylemine işaret eder). Dal butonunun tümü, ikonuyla birlikte, `show_branch_name` ayarına bağlıdır: bu ayar kapalıyken buton bütünüyle kaybolur, başlangıç ikonu da onunla birlikte gider. `show_branch_status_icon` ise yalnız bu ikonun durum-duyarlı (değişiklik/uyarı) mı yoksa düz `GitBranch` mi olacağını seçer; "ad olmadan yalnız ikon" diye bir yol yoktur.

```rust
const MAX_BRANCH_NAME_LENGTH: usize = 40;
const MAX_SHORT_SHA_LENGTH: usize = 8;
```

Port hedefinde git göstergesi tamamen opsiyoneldir. Bir git arayüzün varsa aynı kalıbı kurarsın: aktif dalı kısaltarak göster, tıklanınca dal değiştirme yüzeyini aç, opsiyonel olarak bir durum ikonu ekle. Detached HEAD gibi kenar durumları için (dal yok, yalnız SHA var) bir yedek metin hazırlanır.

## 3. Uzak proje sunucusu

`render_project_host`, projenin nerede çalıştığına göre üç farklı şey gösterir:

```rust
pub fn render_project_host(&self, cx: &mut Context<Self>) -> Option<AnyElement>
```

- **Uzak sunucu üzerinden** (SSH, WSL, dev container gibi) çalışıyorsa, bağlantı durumunu ve sunucu bilgisini gösteren uzak bağlantı yüzeyi çizilir.
- **Bağlantı kopmuşsa**, kaynak arayüzde devre dışı bir `"Disconnected"` butonu gösterilir; Türkçe portta bu görünür metin `"Bağlantı Koptu"` gibi yerelleştirilebilir.
- **Proje bir başkası tarafından paylaşılıyorsa**, paylaşan kullanıcının adı, katılımcı rengiyle tıklanabilir bir buton olarak çizilir; tıklanınca o kullanıcıyı takip etme başlar.

Bu üç durumun ortak yanı, başlığın projenin "konum bağlamını" tek bakışta vermesidir: yerel mi, uzak mı, paylaşımlı mı. Port hedefinde uzak sunucu veya işbirliği yoksa bu gösterge tamamen kaldırılabilir; yalnız uzak çalışma destekliyorsan bağlantı durumu (bağlanıyor/bağlı/koptu) için benzer bir özet yüzey kurarsın.

## 4. Kısıtlı mod (güvenli olmayan proje)

`render_restricted_mode`, projede güvenilir olarak işaretlenmemiş çalışma ağaçları olduğunda devreye girer:

```rust
pub fn render_restricted_mode(&self, cx: &mut Context<Self>) -> Option<AnyElement>
```

Davranış şudur: `TrustedWorktrees::has_restricted_worktrees` doğruysa, başlığa uyarı renginde bir `"Restricted Mode"` butonu eklenir. Türkçe portta bu görünür metin `"Kısıtlı Mod"` gibi yerelleştirilebilir. Buton bir uyarı ikonu taşır ve ipucunda `ToggleWorktreeSecurity` eylemine işaret eder: projeyi güvenilir işaretleyip tüm özellikleri açma. Tıklanınca çalışma alanının güven/güvenlik modalı açılır. Kısıtlı çalışma ağacı yoksa fonksiyon `None` döner ve hiçbir şey çizilmez.

Bu gösterge, güvenlik modelinin başlıktaki görünür yüzüdür: kullanıcı güvenmediği bir projeyi açtığında bazı özellikler kısıtlanır ve bu durum başlıkta açıkça belirtilir. Port hedefinde benzer bir güven modeli varsa (örneğin "bu klasöre güveniyor musun?"), aynı kalıbı kurarsın: kısıtlı durumda görünür bir uyarı göster, tıklamayla güven kararını soran bir yüzey aç. Güven modeli yoksa bu gösterge gerekmez.

## 5. Sol grubun bir araya gelişi

Bu dört gösterge, [3. bölümde](03-titlebar-entity-ve-render.md#3-render-child-grubunun-hazırlanması) anlatılan sol grubun (`h_flex`) içinde sırayla toplanır: önce (menü modu kapalıysa) uygulama menüsü, sonra kısıtlı mod uyarısı, sonra proje sunucusu, proje adı ve git yüzeyi. Bu grup sol fare basma olayında yayılımı durdurur; bu yayılım durdurulmazsa gösterge üzerindeki tıklama alttaki sürükleme yüzeyini tetikleyip pencereyi de hareket ettirebilir.

Port hedefinde bu yayılım durdurma kuralı kritiktir ve [Platform Üst Barı](../platform_ust_bar/05-platform-titlebar-render-akisi-ve-pencere-kontrolleri.md) bölümünde ayrıntılı anlatılır: başlığa konan her etkileşimli element, kendi tıklama ve fare basma olaylarında yayılımı durdurmalıdır.
