# AppState, WorkspaceStore, WorkspaceDb ve OpenListener Akışı

Zed uygulamasında çalışma alanı açmak yalnızca `open_window` çağrısı değildir. Startup, CLI veya open-url istekleri, çalışma alanı veritabanı ve collab follow durumu birkaç global ve handle üzerinden birbirine bağlanır.

---

## AppState

`AppState` Zed çalışma alanı açma ve restore işlemlerinde taşınan uygulama servis paketidir:

- `languages: Arc<LanguageRegistry>`
- `client: Arc<Client>`
- `user_store: Entity<UserStore>`
- `workspace_store: Entity<WorkspaceStore>`
- `fs: Arc<dyn fs::Fs>`
- `build_window_options: fn(Option<Uuid>, &mut App) -> WindowOptions`
- `node_runtime: NodeRuntime`
- `session: Entity<AppSession>`

`AppState::set_global(durum, cx)` global olarak kurar; `AppState::global(cx)` ve `try_global(cx)` okuma yapar. Testlerde `AppState::test(cx)` sahte FS, test language registry ve test settings store kurarsın.

---

## WorkspaceStore

`WorkspaceStore` açık workspace'leri `AnyWindowHandle + WeakEntity<Workspace>` çifti olarak izler. Collab tarafındaki follow ve update follower mesajları bu store üzerinden uygun workspace'e yönlendirilir.

- `WorkspaceStore::new(client, cx)` client request ve message işleyicilerini kaydeder.
- `WorkspaceStore::handle_follow(...)` collab follow isteğini ilgili workspace'e yönlendiren async request handler'dır.
- `workspaces()` weak workspace iterator'ı döndürür.
- `workspaces_with_windows()` window handle ile birlikte verir.
- `update_followers(project_id, update, cx)` aktif call üzerinden follower update mesajı yollar.
- Collab, titlebar ve follow akışlarında client tarafındaki `User`, oda/protokol kimliğini `legacy_id: LegacyUserId` alanında taşır. Proto room role lookup, participant index ve `join_in_room_project` çağrılarında bu alan kullanırsın. Bu client modelinde ayrı bir `user.id` alanı yoktur.

**Collab, aktif çağrı ve follower API kapsamı.** Bu yüzeyler `WorkspaceStore` ve aktif call global'i üzerinden oda, ekran paylaşımı, follow ve katılımcı konum bilgisini birbirine bağlar.

| API | Rol |
| :-- | :-- |
| `AnyActiveCall`, `GlobalAnyActiveCall`, `ActiveCallEvent` | Aktif çağrı view'ini tip silinmiş trait/global olarak tutar ve çağrı state değişimlerini event olarak yayar. |
| `CollaboratorId`, `ParticipantLocation`, `RemoteCollaborator` | Katılımcıyı, hangi workspace/pane/item konumunda olduğunu ve remote collaborator metadata'sını taşır. |
| `CopyRoomId`, `ShareProject`, `JoinAll`, `JoinIntoNext`, `join_channel` | Oda kimliğini kopyalama, projeyi paylaşma, çağrı/kanal katılımı ve join davranışlarını tetikleyen action/helper yüzeyleridir. |
| `Deafen`, `LeaveCall`, `ScreenShare`, `OpenChannelNotes`, `OpenChannelNotesById` | Ses/çağrı state'i, ekran paylaşımı ve kanal notlarını açma action'larını kapsar. |
| `FollowNextCollaborator`, `Unfollow`, `SharedScreen` | Sıradaki collaborator'ı takip etme, takipten çıkma ve paylaşılan ekran handle'ını çalışma alanı tarafında taşır. |

---

## WorkspaceDb ve HistoryManager

`WorkspaceDb::global(cx)` oturum ve çalışma alanı kalıcılığı için kullanılan SQLite bağlantı sarmalayıcısıdır. Çalışma alanı restore ve yakın zamanlı proje geçmişi şu katmanlara dağılır:

- `open_workspace_by_id(workspace_id, app_state, requesting_window, cx)` DB'deki serileştirilmiş workspace'i açar.
- `read_serialized_multi_workspaces`, `SerializedMultiWorkspace`, `SerializedWorkspaceLocation`, `SessionWorkspace`, `ItemId` kalıcılık modelidir.
- `HistoryManager::global(cx)` yakın zamanlı yerel çalışma alanı geçmişini verir.
- `HistoryManager::update_history(id, entry, cx)` yakın zamanlı listeyi günceller ve platform jump list'ini yeniler.
- `HistoryManager::delete_history(id, cx)` boşaltılan çalışma alanını geçmişten kaldırır.

**Open/restore servis API kapsamı.** Bu public yüzeyler startup, restore ve dış açma isteklerinde birlikte görülür:

| API | Rol |
|-----|-----|
| `ItemId` | Serialized workspace içinde item kayıtlarını tanımlar. |
| `Open` | Dış action olarak dosya/dizin açma isteğini taşır; `create_new_window` yeni pencere davranışını seçer. |
| `SerializedMultiWorkspace` | Bir pencere içindeki çoklu workspace durumunun persist edilmiş modelidir. |
| `SerializedWorkspaceLocation` | Workspace'in local/remote konum bilgisini session restore için taşır. |
| `SessionWorkspace` | Oturum geri yüklemede açılacak workspace girdisini temsil eder. |
| `open_workspace_by_id` | DB id'sinden workspace'i geri açar; boş workspace ve unsaved content restore yolunda kullanılır. |
| `read_serialized_multi_workspaces` | Persist edilmiş multi-workspace pencerelerini restore listesi olarak okur. |
| `register_serializable_item` | Restore edilebilir item tiplerini startup sırasında kaydeder. |
| `join_in_room_project` | Collab oda/project bağlantısına katılma akışını workspace açma bağlamına bağlar. |
| `dock` | Restore edilen workspace'te panel/dock durumunu yeniden kuran modül ailesidir. |

---

## OpenListener ve RawOpenRequest

`zed::open_listener` uygulama dışından gelen açma isteklerini kuyruğa alır:

```rust
let (dinleyici, alici) = OpenListener::new();
dinleyici.open(RawOpenRequest {
    urls: urller,
    diff_paths: diff_yollari,
    diff_all: tumunu_karsilastir,
    dev_container: gelistirme_konteyneri,
    wsl: wsl_istegi,
    cwd: calisma_dizini,
});
```

- `OpenListener` bir `Global`'dir; `open(...)` isteği sınırsız bir kanala gönderir.
- `RawOpenRequest` ham CLI veya URL alanlarını taşır.
- `OpenRequest::parse(raw, cx)` bunları tipli `OpenRequest`'a çevirir.
- `OpenRequestKind` kaynak türünü belirtir: CLI connection, extension, agent panel, shared agent thread, dock menu action, builtin JSON schema, setting, git clone, git commit vb.
- Linux ve FreeBSD'de `listen_for_cli_connections` release-channel socket'i üzerinden CLI isteklerini alır.
- `RawOpenRequest::cwd` CLI işleminin çalışma dizinini taşır. Yalnızca `--diff` path'leri verildiğinde çalışma alanı bağlamı için bu cwd kullanılır; Zed app işleminin `std::env::current_dir()` değeri macOS bundle veya zaten çalışan örnek yüzünden güvenilir değildir.
- SSH URL ayrıştırma akışı normal URL'lere ek olarak SCP veya git tarzı `ssh://user@host:~/project` ve `ssh://user@host:/absolute/path` biçimlerini normalleştirir. Kullanıcı adı ve parola URL kodu çözülür; IPv6 SCP-style authority ve çift port benzeri belirsiz biçimler reddedilir.
- `open_paths_with_positions` diff path kanonikleştirme için `app_state.fs` kullanır; hataları `opened_items` listesine taşıyarak diğer path'leri açmaya devam eder.

**Global agent yönergesi.** Kullanıcının kişisel AGENTS.md dosyası şu akışla ele alırsın:

- Startup sırasında `zed::watch_user_agents_md(app_state.fs.clone(), cx)` çağırırsın. Bu, `paths::agents_file()` (`~/.config/zed/AGENTS.md`, platforma göre eşdeğer) dosyasını izler ve `agent::UserAgentsMd` global'ine yükler.
- Boş veya yalnızca boşluk içeren dosya `UserAgentsMdState::Empty`, başarılı okuma `Loaded`, okunamayan ama mevcut dosya `Error` olur. Hata durumunda ayar hatalarıyla aynı app seviyesindeki notification yolu kullanırsın.
- Yerel agent system prompt'u kişisel `AGENTS.md` içeriğini "Personal `AGENTS.md`" olarak project rules'tan önce çizer; çakışma durumunda project rules daha sonra geldiği için daha spesifik kabul edilir.

---

## Tuzaklar

Open akışı ve global durum ile çalışırken karşılaşılan hatalar:

- Çalışma alanı açma akışında `AppState::build_window_options` kullanılır; doğrudan `WindowOptions` kopyalamak Zed'in başlık çubuğu, app id, sınır geri yükleme ve platform ayarlarını atlar.
- `WorkspaceStore` weak workspace tutar; iterasyon sırasında upgrade başarısız olabilir.
- `OpenListener::open` dinleyici yokken hatayı loglar; talebin teslim edildiği varsayımıyla kullanıcı akışının başlatılmaması gerekir.
- DB restore yolunda serializable item kind eksikse item restore edilemez; yeni bir item türü eklenirken `register_serializable_item` startup init'inde çağrılmalıdır.
