# Proje, branch, host ve restricted mode göstergeleri

Başlığın sol grubu, kullanıcıya "şu an neredeyim" sorusunu yanıtlar: hangi proje, hangi git branch, uzak bir sunucuda mı, projeyi başkası mı paylaşıyor ve proje güvenli mi. Bu bölüm bu dört göstergeyi ayrı ayrı ele alır. Hepsi `TitleBarSettings` alanlarına bağlı koşullu çizilir.

## 1. Proje adı

Proje adı, `effective_active_worktree` ile seçilen worktree'nin kök adından üretilir. Çok uzun adlar başlığı taşırmasın diye bir üst sınıra kadar kısaltılır:

```rust
const MAX_PROJECT_NAME_LENGTH: usize = 40;
```

Görsel olarak proje adı tıklanabilir bir tetikleyicidir; tıklanınca son projeler (recent projects) popover'ı açılır. Birden çok worktree açıksa adın yanında bir aşağı-ok (chevron) belirir; bu, başlığın çoklu worktree modunda olduğunun işaretidir. Proje adı yalnız `show_project_items` ayarı açıkken çizilir.

Port hedefinde proje/doküman adı genellikle tek bir worktree veya açık dosyadan gelir. Aynı kısaltma sınırını kendi modelinde uygularsın; çoklu proje desteklemiyorsan chevron ve popover kısmını tamamen atlayabilirsin.

## 2. Git branch ve worktree

Git etkinse, proje adının yanına git yüzeyi eklenir. Bu yüzey birkaç parçadan oluşur:

- **Worktree seçici**: birden çok worktree varsa, bağlı worktree adıyla bir popover tetikleyici.
- **Branch adı**: aktif branch bir popover tetikleyicide gösterilir; `MAX_BRANCH_NAME_LENGTH` (40) sınırına kadar kısaltılır. Detached HEAD durumunda branch adı yerine kısa commit SHA'sı (`MAX_SHORT_SHA_LENGTH` = 8 karakter) veya bir "Create Branch" eylemi gösterilir.
- **Durum ikonu**: `show_branch_status_icon` açıksa, çalışma ağacının git durumunu özetleyen bir ikon eklenir (temiz/değişmiş/çakışma gibi).

Branch tetikleyicisine bağlı `SwitchBranch` action'ı, branch değiştirme akışını başlatır. Branch adı yalnız `show_branch_name` ayarı açıkken metin olarak görünür; durum ikonu ise `show_branch_status_icon`'a bağlıdır. Böylece kullanıcı yalnız ikon, yalnız ad veya ikisini birden görmeyi seçebilir.

```rust
const MAX_BRANCH_NAME_LENGTH: usize = 40;
const MAX_SHORT_SHA_LENGTH: usize = 8;
```

Port hedefinde git göstergesi tamamen opsiyoneldir. Bir git arayüzün varsa aynı kalıbı kurarsın: aktif branch'i kısaltarak göster, tıklanınca branch değiştirme yüzeyini aç, opsiyonel olarak bir durum ikonu ekle. Detached HEAD gibi kenar durumları için (branch yok, yalnız SHA var) bir fallback metni hazırlamayı unutmazsın.

## 3. Uzak proje host'u

`render_project_host`, projenin nerede çalıştığına göre üç farklı şey gösterir:

```rust
pub fn render_project_host(&self, cx: &mut Context<Self>) -> Option<AnyElement>
```

- **Uzak sunucu üzerinden** (SSH, WSL, dev container gibi) çalışıyorsa, bağlantı durumunu ve host bilgisini gösteren uzak bağlantı yüzeyi çizilir.
- **Bağlantı kopmuşsa**, devre dışı bir "Disconnected" butonu gösterilir.
- **Proje bir başkası tarafından paylaşılıyorsa** (collab), paylaşan kullanıcının adı, katılımcı rengiyle tıklanabilir bir buton olarak çizilir; tıklanınca o kullanıcıyı takip etme (follow) başlar.

Bu üç durumun ortak yanı, başlığın projenin "konum bağlamını" tek bakışta vermesidir: yerel mi, uzak mı, paylaşımlı mı. Port hedefinde uzak sunucu veya işbirliği yoksa bu gösterge tamamen kaldırılabilir; yalnız uzak çalışma destekliyorsan bağlantı durumu (bağlanıyor/bağlı/koptu) için benzer bir özet yüzey kurarsın.

## 4. Restricted mode (güvenli olmayan proje)

`render_restricted_mode`, projede güvenilir olarak işaretlenmemiş worktree'ler olduğunda devreye girer:

```rust
pub fn render_restricted_mode(&self, cx: &mut Context<Self>) -> Option<AnyElement>
```

Davranış şudur: `TrustedWorktrees::has_restricted_worktrees` doğruysa, başlığa uyarı renginde bir "Restricted Mode" butonu eklenir. Buton bir uyarı ikonu taşır ve tooltip'inde `ToggleWorktreeSecurity` action'ına işaret eder ("projeyi güvenilir işaretle ve tüm özellikleri aç"). Tıklanınca çalışma alanının güven/güvenlik modalı açılır. Kısıtlı worktree yoksa fonksiyon `None` döner ve hiçbir şey çizilmez.

Bu gösterge, güvenlik modelinin başlıktaki görünür yüzüdür: kullanıcı güvenmediği bir projeyi açtığında bazı özellikler kısıtlanır ve bu durum başlıkta açıkça belirtilir. Port hedefinde benzer bir güven modeli varsa (örneğin "bu klasöre güveniyor musun?"), aynı kalıbı kurarsın: kısıtlı durumda görünür bir uyarı göster, tıklamayla güven kararını soran bir yüzey aç. Güven modeli yoksa bu gösterge gerekmez.

## 5. Sol grubun bir araya gelişi

Bu dört gösterge, [3. bölümde](03-titlebar-entity-ve-render.md#3-render-child-grubunun-hazırlanması) anlatılan sol grubun (`h_flex`) içinde sırayla toplanır: önce (menü modu kapalıysa) uygulama menüsü, sonra restricted mode uyarısı, sonra proje host'u, proje adı ve git yüzeyi. Bu grup sol mouse-down olayında propagation'ı durdurur; aksi halde gösterge üzerindeki tıklama alttaki sürükleme yüzeyini tetikleyip pencereyi yanlışlıkla taşıyabilir.

Port hedefinde bu propagation durdurma kuralı kritiktir ve [Platform Üst Barı](../platform_ust_bar/05-platform-titlebar-render-akisi-ve-pencere-kontrolleri.md) bölümünde ayrıntılı anlatılır: başlığa konan her interaktif element, kendi tıklama ve mouse-down olaylarında propagation'ı durdurmalıdır.
