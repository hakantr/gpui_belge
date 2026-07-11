# AppState, WorkspaceStore, WorkspaceDb ve OpenListener Akışı

## Sürüm Analiz Raporu

- [x] Doğrulanan çalışma alanı kalıcılığı yüzeyi: `workspace::persistence::Bookmark`, `project::bookmark_store::SerializedBookmark`, `BookmarkStore::toggle_bookmark`, `BookmarkStore::edit_bookmark` ve `bookmarks` SQLite tablosundaki `label` alanı.
- [x] Kaynak doğrulama dosyaları: `crates/workspace/src/persistence.rs` ve `crates/project/src/bookmark_store.rs`.

Zed uygulamasında çalışma alanı açmak yalnızca basit bir `open_window` çağrısından ibaret değildir. Başlangıç (startup), CLI istekleri, url yönlendirmeleri, çalışma alanı veritabanı ve collab follow (iş birliği takip) durumları; birkaç global servis ve handle üzerinden koordine edilerek birbirine bağlanır.

---

## AppState

`AppState`, Zed çalışma alanının açılması ve durumunun geri yüklenmesi (restore) süreçlerinde taşınan uygulama servis paketidir:

- `languages: Arc<LanguageRegistry>`
- `client: Arc<Client>`
- `user_store: Entity<UserStore>`
- `workspace_store: Entity<WorkspaceStore>`
- `fs: Arc<dyn fs::Fs>`
- `build_window_options: fn(Option<Uuid>, &mut App) -> WindowOptions`
- `node_runtime: NodeRuntime`
- `session: Entity<AppSession>`

`AppState::set_global(durum, cx)` çağrısı bu paketi global olarak kurar; `AppState::global(cx)` ve `try_global(cx)` metotları ise bu verileri okumak için kullanılır. Test süreçlerinde ise `AppState::test(cx)` yardımıyla sahte bir FS (dosya sistemi), test language registry ve test settings store yapılandırılır.

---

## WorkspaceStore

`WorkspaceStore`, açık olan çalışma alanlarını `AnyWindowHandle + WeakEntity<Workspace>` çifti halinde izler. Collab tarafındaki follow (takip etme) ve update follower (takipçileri güncelleme) mesajları bu store aracılığıyla uygun çalışma alanına yönlendirilir.

- `WorkspaceStore::new(client, cx)` metodu client istek ve mesaj işleyicilerini kaydeder.
- `WorkspaceStore::handle_follow(...)` metodu, collab follow isteklerini ilgili çalışma alanına yönlendiren asenkron bir istek işleyicidir (async request handler).
- `workspaces()` metodu, zayıf (weak) workspace referansları üzerinde dönen bir iterator döndürür.
- `workspaces_with_windows()` metodu, bu referansları window handle bilgileriyle birlikte verir.
- `update_followers(project_id, update, cx)` metodu, aktif çağrı (call) üzerinden takipçilere güncelleme mesajı gönderir.
- Collab, titlebar ve follow akışlarında client tarafındaki `User` yapısı, oda/protokol kimliğini `legacy_id: LegacyUserId` alanında taşır. Proto room role lookup (oda rolü sorgulama), participant index (katılımcı indeksi) ve `join_in_room_project` çağrılarında bu alandan faydalanılır. Bu client modelinde ayrıca bağımsız bir `user.id` alanı bulunmaz.

**Collab, Aktif Çağrı ve Follower API Kapsamı.** Bu yüzeyler `WorkspaceStore` ve aktif çağrı globali üzerinden oda, ekran paylaşımı, follow ve katılımcı konum bilgilerini birbirine bağlar:

| API | Rolü |
| :-- | :-- |
| `AnyActiveCall`, `GlobalAnyActiveCall`, `ActiveCallEvent` | Aktif çağrı görünümünü tip silinmiş (type-erased) trait/global olarak tutar ve çağrı durum değişimlerini olay (event) olarak yayar. |
| `CollaboratorId`, `ParticipantLocation`, `RemoteCollaborator` | `CollaboratorId` katılımcının kimliğidir (`PeerId` veya `Agent`); `ParticipantLocation` yalnızca proje düzeyindeki konumu (`SharedProject`, `UnsharedProject`, `External`) tutar; `RemoteCollaborator` ise uzaktaki katılımcının proje düzeyindeki durum ve metadata'sını taşır. |
| `CopyRoomId`, `ShareProject`, `JoinAll`, `JoinIntoNext`, `join_channel` | Oda kimliğini kopyalama, projeyi paylaşma, çağrıya veya kanala katılım eylemlerini tetikleyen action ve helper bileşenleridir. |
| `Deafen`, `LeaveCall`, `ScreenShare`, `OpenChannelNotes`, `OpenChannelNotesById` | Ses ve çağrı durumları, ekran paylaşımı ve kanal notlarını açma eylemlerini kapsar. |
| `FollowNextCollaborator`, `Unfollow`, `SharedScreen` | Sıradaki katılımcıyı takip etme, takipten çıkma ve paylaşılan ekran handle'ını çalışma alanı tarafında yönetme işlevlerini üstlenir. |

---

## WorkspaceDb ve HistoryManager

`WorkspaceDb::global(cx)` oturum ve çalışma alanı kalıcılığı (persistence) için kullanılan SQLite bağlantı sarmalayıcısıdır. Çalışma alanının geri yüklenmesi ve yakın zamanlı proje geçmişi şu katmanlara dağılır:

- `open_workspace_by_id(workspace_id, app_state, requesting_window, cx)` DB'deki serileştirilmiş workspace'i açar.
- `read_serialized_multi_workspaces`, `SerializedMultiWorkspace`, `SerializedWorkspaceLocation`, `SessionWorkspace`, `ItemId` kalıcılık modellerini oluşturur.
- `HistoryManager::global(cx)` yakın zamanlı yerel çalışma alanı geçmişini sağlar.
- `HistoryManager::update_history(id, entry, cx)` yakın zamanlı çalışma alanı listesini günceller ve platform jump list (hızlı erişim listesi) yapısını yeniler.
- `HistoryManager::delete_history(id, cx)` boşaltılan çalışma alanını geçmiş listesinden kaldırır.
- Bookmark kalıcılığı `bookmarks` SQLite tablosu üzerinden ilerler. Her kayıt `workspace_id`, `path`, `row` ve `label` alanlarını taşır; `workspace::persistence::Bookmark { row, label }` satır ve etiket bilgisini DB sınırında okur/yazar, `project::bookmark_store::SerializedBookmark { row, label }` ise buffer henüz yüklenmeden saklanan bookmark bilgisini temsil eder.

Bookmark akışında `BookmarkStore::toggle_bookmark(buffer, anchor, label, cx)` aynı satırda kayıt varsa onu kaldırır, yoksa verilen `label` ile yeni bookmark ekler. `BookmarkStore::edit_bookmark(buffer, anchor, label, cx)` yüklü buffer üzerindeki eşleşen bookmark etiketini günceller ve store gözlemcilerini bilgilendirir. Restore sırasında `load_serialized_bookmarks(...)` kayıtları önce `BookmarkEntry::Unloaded(Vec<SerializedBookmark>)` halinde tutar; ilgili buffer açıldığında satır numaraları anchor'a çözülür ve etiketler `Bookmark { anchor, label }` modeline aktarılır. Bu ayrım, workspace restore sırasında dosyaları hemen açmadan bookmark bilgisini korumayı sağlar.

**Open/Restore Servis API Kapsamı.** Bu dışa açık arayüzler başlangıç (startup), geri yükleme (restore) ve dış açma isteklerinde birlikte kullanılır:

| API | Rolü |
|-----|-----|
| `ItemId` | Serileştirilmiş workspace içindeki item (öğe) kayıtlarını tanımlar. |
| `Open` | Dış eylem olarak dosya ya da dizin açma isteğini taşır; `create_new_window: Option<bool>` verilirse yeni pencere davranışını açıkça belirler, `None` olduğunda workspace `default_open_behavior` ayarı uygulanır. |
| `SerializedMultiWorkspace` | Bir pencere içindeki çoklu çalışma alanı durumunun kalıcılaştırılmış (persist edilmiş) modelidir. |
| `SerializedWorkspaceLocation` | Workspace'in yerel/uzak konum bilgisini oturum geri yükleme (session restore) için taşır. |
| `SessionWorkspace` | Oturum geri yükleme esnasında açılacak çalışma alanı girdisini temsil eder. |
| `open_workspace_by_id` | Veritabanı kimliğinden (DB id) çalışma alanını yeniden açar; boş çalışma alanı ve kaydedilmemiş içerik kurtarma (unsaved content restore) akışlarında kullanılır. |
| `read_serialized_multi_workspaces` | Kalıcılaştırılmış multi-workspace pencerelerini geri yükleme listesi olarak okur. |
| `register_serializable_item` | Geri yüklenebilir item tiplerini başlangıç (startup) sırasında sisteme kaydeder. |
| `join_in_room_project` | Collab oda/proje bağlantısına katılma akışını çalışma alanı açma bağlamına bağlar. |
| `dock` | Geri yüklenen workspace'te panel/dock durumunu yeniden kuran modül ailesidir. |

---

## OpenListener ve RawOpenRequest

`zed::open_listener` modülü, uygulama dışından gelen dosya veya dizin açma isteklerini kuyruğa alır:

```rust
let (dinleyici, alici) = OpenListener::new();
dinleyici.open(RawOpenRequest {
    urls: urller,
    diff_paths: diff_yollari,
    diff_all: tumunu_karsilastir,
    dev_container: gelistirme_konteyneri,
    wsl: wsl_istegi,
    open_behavior: acma_davranisi,
});
```

- `OpenListener` bir `Global` yapıdır; `open(...)` aracılığıyla gelen istekleri sınırsız bir kanal (unbounded channel) üzerinden gönderir.
- `RawOpenRequest` ham URL, diff, WSL, dev container ve open-behavior (açılma şekli) alanlarını taşır. CLI bağlantısı üzerinden gelen `cwd` (çalışma dizini) bilgisi ham istek içinde yer almaz, `handle_cli_connection` tarafından `open_workspaces` ve `open_local_workspace` hattına bağımsız bir argüman olarak aktarılır.
- `OpenRequest::parse(raw, cx)` bu ham istekleri tipli `OpenRequest` yapısına dönüştürür.
- `OpenRequestKind` kaynak türünü belirtir: CLI connection, focus app, extension, agent panel, shared agent thread, install skill, dock menu action, builtin JSON schema, setting, git clone, git commit vb.
- Linux ve FreeBSD platformlarında `listen_for_cli_connections` fonksiyonu, release-channel socket'i üzerinden CLI isteklerini dinler.
- CLI connection hattında yalnızca `--diff` yolları (path) sağlandığında, çalışma alanı bağlamı için CLI'ın çalıştığı `cwd` kullanılır; zira Zed uygulamasının ana sürecine ait `std::env::current_dir()` değeri, macOS bundle yapısı veya arka planda zaten çalışan başka bir örnek (instance) nedeniyle her zaman güvenilir kabul edilmeyebilir.
- SSH URL ayrıştırma akışı; standart URL'lere ek olarak SCP veya git benzeri `ssh://user@host:~/project` ve `ssh://user@host:/absolute/path` biçimlerini de normalleştirir. Kullanıcı adı ve parola URL çözücüden (decoder) geçirilir; IPv6 SCP-style authority ve çift port benzeri belirsiz formatlar ise reddedilir.
- `open_paths_with_positions` fonksiyonu, diff yollarını kanonik hale getirmek için `app_state.fs` yapısını kullanır; hataları `opened_items` listesine taşıyarak diğer yolları açmaya kesintisiz devam eder.

**Global Agent Yönergesi.** Kullanıcının kişisel `AGENTS.md` dosyası şu akışla ele alınır:

- Başlangıç sırasında `zed::watch_user_agents_md(app_state.fs.clone(), cx)` çağrısı yapılır. Bu çağrı, `paths::agents_file()` (`~/.config/zed/AGENTS.md` veya platforma göre eşdeğeri) dosyasını izler ve `agent_settings::UserAgentsMd` globaline yükler.
- Dosya boşsa veya yalnızca boşluk karakterlerinden oluşuyorsa `UserAgentsMdState::Empty` durumuna, başarılı okunduğunda `Loaded` durumuna, mevcut ancak okunamıyorsa `Error` durumuna geçilir. Hata durumunda, ayar hatalarıyla aynı uygulama seviyesindeki bildirim (notification) mekanizması kullanılır.
- Yerel agent sistem yönlendirmesi (system prompt), kişisel `AGENTS.md` içeriğini "Personal `AGENTS.md`" başlığıyla proje kurallarından (project rules) önce ekler; çakışma durumunda ise proje kuralları daha sonra geldiği için daha spesifik kabul edilerek önceliklendirilir.

---

## Dikkat Edilmesi Gereken Hususlar

Açılış akışları ve global durumlar ile çalışırken hataya açık olan durumlar şunlardır:

- Çalışma alanı açma akışında `AppState::build_window_options` kullanılması gerekir; doğrudan `WindowOptions` kopyalamak Zed'in başlık çubuğu, app id, pencere dekorasyonları, sistem sekmeleri ve platforma özel arka plan/ikon ayarlarının atlanmasına neden olur.
- `WorkspaceStore` zayıf referanslar (`WeakEntity`) tuttuğu için iterasyon sırasında upgrade işlemleri başarısız olabilir; bu olasılığın kod içinde mutlaka kontrol edilmesi gerekir.
- `OpenListener::open` dinleyici yokken oluşan hataları loglar; talebin başarıyla teslim edildiği varsayımıyla kullanıcı akışının başlatılmaması gerekir.
- DB restore (veritabanından geri yükleme) yolunda serileştirilebilir öğe türü (serializable item kind) eksikse öğe geri yüklenemez; bu nedenle yeni bir öğe türü eklerken `register_serializable_item` kaydının başlangıç (startup) init sürecinde çağrılması gerekir.
