# Proje, dal, sunucu ve kısıtlı mod göstergeleri

Başlığın sol grubu, kullanıcıya "Şu an neredeyim?" sorusunu yanıtlar: Hangi proje, hangi Git dalı, uzak bir sunucuda mı, projeyi başkası mı paylaşıyor ve proje güvenli mi? Bu bölüm, söz konusu dört göstergeyi ayrı ayrı ele alır. Hepsi `TitleBarSettings` alanlarına bağlı olarak koşullu şekilde çizilir.

## 1. Proje adı

Proje adı, `effective_active_worktree` ile seçilen çalışma ağacının kök adından üretilir. Ancak ilgili çalışma ağacının bir deposu varsa, ad depo kimliğinden (`repo_identity_path`) yeniden yazılır; bu yüzden git barındıran projelerde görünen ad çoğunlukla çalışma ağacı klasörünün değil, deponun adıdır. Çok uzun adların başlığı taşırmaması için bir üst sınıra kadar kısaltma uygulanır:

```rust
const MAX_PROJECT_NAME_LENGTH: usize = 40;
```

Görsel olarak proje adı tıklanabilir bir tetikleyicidir; tıklandığında son projeler açılır paneli açılır. Birden çok çalışma ağacı açık ise adın yanında bir aşağı ok belirir; bu durum, başlığın çoklu çalışma ağacı modunda olduğunun işaretidir. Proje adı yalnızca `show_project_items` ayarı açıkken çizilir.

Port hedefinde proje/doküman adı genellikle tek bir çalışma ağacından veya açık dosyadan gelir. Aynı kısaltma sınırı kendi modelinde de uygulanmalıdır; çoklu proje desteklenmiyorsa aşağı ok ve açılır panel kısmı tamamen atlanabilir.

## 2. Git dalı ve çalışma ağacı

Git etkin ise, proje adının yanına git yüzeyi eklenir. Bu yüzey birkaç parçadan oluşur:

- **Çalışma Ağacı Seçici:** Git etkin ve depo varsa koşulsuz çizilen bir açılır panel tetikleyicidir; etiketi bağlı çalışma ağacının adıdır, bu ad yoksa varsayılan olarak `"main"` değerine düşer. (Birden çok çalışma ağacı koşulu bu tetikleyiciye değil, yalnızca proje adının yanındaki aşağı oka uygulanır.)
- **Dal Adı:** Aktif dal bir açılır panel tetikleyicide gösterilir; `MAX_BRANCH_NAME_LENGTH` (40) sınırına kadar kısaltılır. Detached HEAD durumunda butonun görünür metni her zaman `"Create Branch"` (port karşılığı `"Dal Oluştur"`) olur ve bir `GitBranchPlus` ikonu taşır; kısa commit SHA'sı (`MAX_SHORT_SHA_LENGTH` = 8 karakter) buton metni olarak değil, yalnızca ipucunda `"Detached HEAD: {sha}"` biçiminde görünür.
- **Başlangıç İkonu:** Dal butonu çiziliyorsa, butonun başında her zaman bir ikon bulunur. `show_branch_status_icon` ayarı açık ise bu ikon çalışma ağacının git durumunu özetler (değişmiş/eklenmiş/silinmiş/çakışma gibi); kapalıysa düz bir `GitBranch` ikonuna düşer.

Dal tetikleyicisi bir açılır panel düğmesidir; tıklandığında git dal ve stash seçicisini bir açılır panelde açar (ipucu `zed_actions::git::Branch` eylemine işaret eder). Dal butonunun tümü, ikonuyla birlikte, `show_branch_name` ayarına bağlıdır: Bu ayar kapalıyken buton bütünüyle kaybolur, başlangıç ikonu da onunla birlikte gider. `show_branch_status_icon` ise yalnızca bu ikonun durum-duyarlı (değişiklik/uyarı) mı yoksa düz `GitBranch` mi olacağını belirler; "ad olmadan yalnızca ikon gösterilmesi" gibi bir yol bulunmamaktadır.

```rust
const MAX_BRANCH_NAME_LENGTH: usize = 40;
const MAX_SHORT_SHA_LENGTH: usize = 8;
```

Port hedefinde git göstergesi tamamen isteğe bağlıdır. Bir git arayüzü varsa benzer bir kalıp kurulur: Aktif dal kısaltılarak gösterilir, tıklandığında dal değiştirme yüzeyi açılır, isteğe bağlı olarak bir durum ikonu eklenir. Detached HEAD gibi uç durumlar için (dal yok, yalnızca SHA var) bir yedek metin hazırlanmalıdır.

## 3. Uzak proje sunucusu

`render_project_host`, projenin nerede çalıştığına göre üç farklı görünüm sunar:

```rust
pub fn render_project_host(&self, cx: &mut Context<Self>) -> Option<AnyElement>
```

- **Uzak sunucu üzerinden** (SSH, WSL, dev container gibi) çalışıyorsa, bağlantı durumunu ve sunucu bilgisini gösteren uzak bağlantı arayüzü çizilir.
- **Bağlantı kopmuşsa**, kaynak arayüzde devre dışı bir `"Disconnected"` butonu gösterilir; Türkçe portta bu görünür metin `"Bağlantı Koptu"` şeklinde yerelleştirilebilir.
- **Proje bir başkası tarafından paylaşılıyorsa**, paylaşan kullanıcının adı, katılımcı rengiyle tıklanabilir bir buton olarak çizilir; tıklandığında o kullanıcıyı takip etme işlemi başlar.

Bu üç durumun ortak yanı, başlığın projenin "konum bağlamını" tek bakışta sunmasıdır: Yerel mi, uzak mı, paylaşımlı mi. Port hedefinde uzak sunucu veya işbirliği yoksa bu gösterge tamamen kaldırılabilir; yalnızca uzak çalışma destekleniyorsa bağlantı durumu (bağlanıyor/bağlı/koptu) için benzer bir özet arayüz kurulur.

## 4. Kısıtlı mod (güvenli olmayan proje)

`render_restricted_mode`, projede güvenilir olarak işaretlenmemiş çalışma ağaçları olduğunda devreye girer:

```rust
pub fn render_restricted_mode(&self, cx: &mut Context<Self>) -> Option<AnyElement>
```

Davranış şudur: `TrustedWorktrees::has_restricted_worktrees` değeri doğruysa, başlığa uyarı renginde bir `"Restricted Mode"` butonu eklenir. Türkçe portta bu görünür metin `"Kısıtlı Mod"` şeklinde yerelleştirilebilir. Buton bir uyarı ikonu taşır ve ipucunda `ToggleWorktreeSecurity` eylemine işaret eder: Projeyi güvenilir işaretleyip tüm özellikleri açma. Tıklanınca çalışma alanının güven/güvenlik modalı açılır. Kısıtlı çalışma ağacı yoksa fonksiyon `None` döner ve hiçbir şey çizilmez.

Bu gösterge, güvenlik modelinin başlıktaki görünür yüzüdür: Kullanıcı güvenmediği bir projeyi açtığında bazı özellikler kısıtlanır ve bu durum başlıkta açıkça belirtilir. Port hedefinde benzer bir güven modeli varsa (örneğin "bu klasöre güveniyor musun?"), aynı kalıp uygulanır: Kısıtlı durumda görünür bir uyarı gösterilir, tıklamayla güven kararını soran bir arayüz açılır. Güven modeli yoksa bu gösterge gerekmez.

## 5. Sol grubun bir araya gelişi

Bu dört gösterge, [3. bölümde](03-titlebar-entity-ve-render.md#3-render-child-grubunun-hazırlanması) anlatılan sol grubun (`h_flex`) içinde sırayla toplanır: Önce (menü modu kapalıysa) uygulama menüsü, sonra kısıtlı mod uyarısı, sonra proje sunucusu, proje adı ve git yüzeyi. Bu grup sol fare basma olayında yayılımı durdurur; bu yayılım durdurulmazsa gösterge üzerindeki tıklama alttaki sürükleme yüzeyini tetikleyip pencereyi de hareket ettirebilir.

Port hedefinde bu yayılım durdurma kuralı kritiktir ve [Platform Üst Barı](../platform_ust_bar/05-platform-titlebar-render-akisi-ve-pencere-kontrolleri.md) bölümünde ayrıntılı anlatılır: Başlığa konan her etkileşimli element, kendi tıklama ve fare basma olaylarında yayılımı durdurmalıdır.

---
