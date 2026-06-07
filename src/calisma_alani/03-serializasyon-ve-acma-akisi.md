# Serileştirme, OpenOptions, ProjectItem ve SearchableItem

Çalışma alanında öğe (item) açma yalnız `Pane::add_item` çağrısından ibaret değildir. Zed oturum geri yükleme, project item çözme, search bar ve collab follow gibi katmanlar da item trait'leri üzerinden bağlanır.

---

## SerializableItem ve Geri Yükleme (Restore)

`SerializableItem` arayüzü, çalışma alanı kapanırken veya öğe (item) olayı geldiğinde öğe durumunu çalışma alanı veritabanına yazmak amacıyla kullanılır. Aynı veri daha sonra restore akışında geri yüklenir:

```rust
pub trait SerializableItem: Item {
    fn serialized_item_kind() -> &'static str;

    fn cleanup(
        workspace_id: WorkspaceId,
        alive_items: Vec<ItemId>,
        window: &mut Window,
        cx: &mut App,
    ) -> Task<Result<()>>;

    fn deserialize(
        project: Entity<Project>,
        workspace: WeakEntity<Workspace>,
        workspace_id: WorkspaceId,
        item_id: ItemId,
        window: &mut Window,
        cx: &mut App,
    ) -> Task<Result<Entity<Self>>>;

    fn serialize(
        &mut self,
        workspace: &mut Workspace,
        item_id: ItemId,
        closing: bool,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Option<Task<Result<()>>>;

    fn should_serialize(&self, event: &Self::Event) -> bool;
}
```

Kayıt için tek satırlık bir çağrı yeterlidir:

```rust
workspace::register_serializable_item::<BenimOgem>(cx);
```

- `serialized_item_kind()` session DB'deki discriminant'tır; restore akışı öğe tipini bu değer üzerinden bulur.
- `serialize(..., closing, ...)` `None` döndürürse o olay için yazma yapılmaz.
- `should_serialize(event)` öğe olayından sonra serileştirmenin gerekip gerekmediğini belirler.
- `cleanup(workspace_id, alive_items, ...)` DB'de canlı olmayan öğe kayıtlarını temizlemek için çağrılır.
- `SerializableItemHandle` `Entity<T: SerializableItem>` için blanket olarak uygulanır; pane ve çalışma alanı tip silme bu handle üzerinden çalışır.

---

## OpenOptions ve open_paths

Üst seviye `workspace::open_paths` ve `Workspace::open_paths` aynı seçenek modelini kullanır:

- `visible: Option<OpenVisible>` — `All`, `None`, `OnlyFiles`, `OnlyDirectories`. `All` hem dosya hem dizinleri proje panelinde (project panel) görünür yapar; `None` hiçbirini görünür yapmaz; `OnlyFiles` dizinleri, `OnlyDirectories` ise dosyaları dışarıda bırakır.
- `focus: Option<bool>` — Açılan öğe odak alsın mı?
- `workspace_matching: WorkspaceMatching` — `None`, `MatchExact`, `MatchSubdirectory`.
- `add_dirs_to_sidebar` — Eşleşmeyen dizin yeni pencere açmak yerine mevcut yerel `MultiWorkspace` penceresine workspace olarak eklensin mi? Varsayılan `true`. Ekleme yalnız hedef pencerede `multi_workspace_enabled(cx)` `true` olduğunda yapılır; bu durumda `requesting_window` aktif veya ilk yerel multi-workspace penceresine ayarlanır ve sidebar açılır.
- `wait` — CLI `--wait` benzeri akışlarda pencerenin kapanmasını bekleme davranışı.
- `requesting_window` — Hedef `WindowHandle<MultiWorkspace>` varsa onun kullanılması.
- `open_mode: OpenMode` — `NewWindow`, `Add`, `Activate`.
- `env` — Açılan çalışma alanı için ortam üzerine yazması.
- `open_in_dev_container` — Dev container açma isteği.

`OpenMode::Activate` `NewWindow` gibi hedef pencereyi öne getirir. Varsayılan davranışta `-n`, `-a` veya `-r` verilmeden klasör açmak mevcut pencerenin Threads sidebar'ına yeni bir project olarak ekler. Yeni pencere isteniyorsa CLI'da `zed -n path`, Open Recent'te değiştiricili enter tuşu, tıklama eylemi ya da `cli_default_open_behavior = "new_window"` ayarı tercih edilir.

`OpenResult { window, workspace, opened_items }` üst seviye açma sonucudur. İç çalışma alanı açma fonksiyonları çoğunlukla `Task<Result<Box<dyn ItemHandle>>>` veya çoklu yol için `Task<Vec<Option<Result<Box<dyn ItemHandle>>>>>` döndürür.

Yol bir worktree köküne denk geldiğinde `project_path.path` boş gelir ve dizin kararı doğrudan `worktree.root_entry()` üzerinden verilir. Bu özellikle uzak worktree'lerde önemlidir: local olmayan worktree için yerel dosya sistemi `fs.is_dir(abs_path)` fallback'ine güvenilmez. Root entry dizinse açma akışı onu dosya gibi aktif öğe yapmaya çalışmaz; sidebar/project ekleme sonucu deterministik kalır.

**Open/serialization API kapsamı.** Bu tipler açma ve restore akışını taşır:

| API | Rol |
|-----|-----|
| `ItemId` | Kalıcılık (persistence) modelinde öğe kayıtlarını tanımlar; `SerializableItem` cleanup ve restore akışında canlı öğe setiyle karşılaştırılır. |
| `WorkspaceId` | Kalıcı workspace kimliğidir; DB satırlarıyla taşınır ve `from_i64` ile dış integer değerden kurulabilir. |
| `Open` | `workspace` namespace'inde dosya/dizin açma eylemidir (action); `create_new_window` alanı yeni pencere davranışını seçer. |
| `OpenMode` | `NewWindow`, `Add`, `Activate` varyantlarıyla workspace'in pencereye nasıl ekleneceğini belirler. |
| `OpenVisible` | Açılan dosya veya dizinlerin proje panel görünürlüğünü `All`, `None`, `OnlyFiles`, `OnlyDirectories` olarak sınırlar. |
| `OpenResult` | Üst seviye açma sonucunda `window`, `workspace` ve yol başına `opened_items` sonucunu taşır. |
| `WorkspaceMatching` | `None`, `MatchExact`, `MatchSubdirectory` seçenekleriyle mevcut workspace yeniden kullanımını yönetir. |
| `ProjectItemKind` | `ProjectItem` türünü string discriminant ile sınıflandırır. |
| `Dedup` | İzlenebilir öğe (followable item) açılırken mevcut öğeyi koruma (`KeepExisting`) veya değiştirme (`ReplaceExisting`) kararını belirtir. |
| `SerializableItemHandle` | Tip silinmiş serializable item handle'ıdır; `serialized_item_kind`, `should_serialize` ve `serialize` çağrılarını taşır. |
| `register_serializable_item` | Bir `SerializableItem` tipini restore registry'sine ekler. |
| `pane` | Open/restore sonucunda öğelerin yerleştirildiği sekme (tab) ve split yönetim modülüdür. |

**Open, restore ve workspace konumu ek kapsamı.** Bu kayıtlar çalışma alanı açma hattının sınır durumlarını taşır: Mevcut pencere bulma, local/remote proje açma, restore state ve workspace konumunun kalıcılığını (persist) sağlama.

| API | Rol |
| :-- | :-- |
| `ActiveWorktreeCreation`, `AutoWatch`, `AddFolderToProject` | Worktree oluşturma durumu, otomatik izleme (auto-watch) tercihi ve mevcut projeye klasör ekleme eylemini kapsar. |
| `PreviousWorkspaceState`, `WorkspacePosition`, `WorkspaceHandle`, `ViewId` | Önceki workspace durumu, pencere/workspace konumu, `Entity<Workspace>` üzerinde projedeki dosya yollarını veren sözleşme ve görünüm (view) kimliği taşıyıcılarıdır. |
| `SERIALIZATION_THROTTLE_TIME`, `delete_unloaded_items`, `apply_restored_multiworkspace_state`, `restore_multiworkspace` | Oturum serileştirme (session serialization) debounce sabiti, yüklenmeyenleri temizleme (unload cleanup) ve multi-workspace geri yükleme yardımcılarıdır. |
| `last_opened_workspace_location`, `last_session_workspace_locations`, `remote_workspace_position_from_db` | DB veya oturum durumundan son yerel/uzak workspace konumlarını okur. |
| `workspace_windows_for_location`, `find_existing_workspace`, `get_any_active_multi_workspace`, `activate_any_workspace_window` | Açma isteği için yeniden kullanılabilecek pencere/workspace'i bulur veya aktif pencereye geçer. |
| `with_active_or_new_workspace`, `open_new`, `prompt_for_open_path_and_open` | Aktif workspace'i kullanma, yeni pencere açma veya kullanıcıdan yol isteyip açma akışlarını başlatır. |
| `create_and_open_local_file`, `open_remote_project_with_new_connection`, `open_remote_project_with_existing_connection` | Yerel yeni dosya oluşturup açma ve uzak proje bağlantısını yeni veya mevcut bağlantıyla açma yardımcılarıdır. |
| `register_project_item`, `clone_active_item`, `move_item`, `move_active_item` | Project item tiplerini kaydeder; aktif öğe klonlama/taşıma işlemlerinin çalışma alanı tarafındaki düşük seviyeli girişleridir. |
| `OpenLog`, `RevealLogInFileManager`, `OpenInTerminal`, `OpenTerminal` | Günlük (log) dosyasını açma/gösterme ve terminali çalışma alanı veya dosya bağlamında açma eylemleridir. |
| `ClearBookmarks`, `ClearNavigationHistory`, `ClearTrustedWorktrees`, `ToggleWorktreeSecurity` | Çalışma alanı kalıcılığında bookmark/gezinti geçmişi/güvenilen çalışma alanı kayıtlarını temizler veya aktif çalışma alanı güvenlik durumunu değiştirir. |
| `RemoteConnectionIdentity` | Uzak çalışma alanı açma ve karşılaştırma işlemlerinde bağlantı kimliğini taşıyan yeniden ihraç (re-export) yüzeyidir. |

**Proje grubu sıralaması.** Sidebar'da proje gruplarının görüntülenme sırası `MultiWorkspace` üzerindeki iki yeni yöntemle değiştirilebilir:

```rust
multi_workspace.move_project_group_up(&key, cx);
multi_workspace.move_project_group_down(&key, cx);
```

Her ikisi de `bool` döndürür: Zaten en başta ya da en sonda olan grup için `false`, başarıyla taşınan grup için `true`. Taşıma başarılıysa `ProjectGroupsChanged` olayı yayılır, durum kalıcı hale getirilir (`serialize`) ve yeniden çizim tetiklenir. Sidebar'da sürükleme veya bağlam menüsü üzerinden sıra değiştirme bu yöntemleri çağırır.

---

## ProjectItem

`ProjectItem` arayüzü, Zed project entry'sinden çalışma alanı öğe görünümü üretir:

```rust
pub trait ProjectItem: Item {
    type Item: project::ProjectItem;

    fn project_item_kind() -> Option<ProjectItemKind> { None }

    fn for_project_item(
        project: Entity<Project>,
        pane: Option<&Pane>,
        item: Entity<Self::Item>,
        window: &mut Window,
        cx: &mut Context<Self>,
    ) -> Self;

    fn for_broken_project_item(
        _abs_path: &Path,
        _is_local: bool,
        _error: &anyhow::Error,
        _window: &mut Window,
        _cx: &mut App,
    ) -> Option<InvalidItemView> {
        None
    }
}
```

Normal dosya açma işlemi `project::ProjectItem::try_open` üzerinden öğeyi çözer; hata durumunda `for_broken_project_item` bozuk veya eksik kaynağı temsil eden bir görünüm (view) üretmek için kullanılabilir.

---

## `path_link` — Metin İçindeki Yolu Çözümleme

Terminalde veya diff çıktısında görünen bir yol dizgesini worktree girişine veya dosya sistemi meta verisine çeviren altyapıdır. Terminal çıktısından dosya açma, git diff yolu çözümleme ve hover bağlantısı gibi akışlar bu modülü kullanır.

**Ana tipler:**

```rust
pub enum OpenTarget {
    Worktree(PathWithPosition, Entry, /* test: OpenTargetFoundBy */),
    File(PathWithPosition, Metadata),
}

pub fn possible_open_target(
    workspace: &WeakEntity<Workspace>,
    maybe_path: &str,
    cwd: Option<&Path>,
    cx: &App,
) -> Task<Option<OpenTarget>>
```

`OpenTarget::Worktree` verilen yolun worktree girişiyle eşleştiği durumu, `OpenTarget::File` ise yalnızca dosya sistemi üzerinden bulunan durumu temsil eder.

**Çözümleme önceliği.** `possible_open_target_internal` şu sırayı izler:

1. `a/...` ve `b/...` önekleri soyularak git diff yolları için her iki biçim denenir.
2. Worktree kök yoluna göre göreli yol hesaplanır; çalışma dizini (`cwd`) bilinen bir worktree içindeyse ona öncelik verilir.
3. Worktree içinde tam eşleşme bulunursa `Task::ready` ile anında döner.
4. Proje yerel ise (`is_local()`) arka planda dosya sistemi kontrolü gerçekleştirilir: `~` ile başlayan yollar `dirs::home_dir()` ile genişletilir; göreli yollar için her worktree kökü denenir.
5. Eşleşme hâlâ bulunamazsa worktree `traverse_from_path` ile taranır (yavaş yol, suffix eşleştirme).

`sanitize_path_text` ve `first_unbalanced_open_paren` yardımcıları ham metinden önce noktalama ve dengesiz parantez temizliği yapar; böylece `"src/main.rs:42,"` gibi terminale yapıştırılmış yollar temiz ayrıştırılır.

**Dikkat Edilmesi Gereken Hususlar:**

- `BackgroundFsChecks::Disabled` yalnızca test/test-support yardımcıları (helper) üzerinden açıkça verilir. Normal `possible_open_target` akışında yerel projelerde arka plan dosya sistemi kontrolü açıktır; uzak projelerde bu kontrol kapalı kalır.
- `cwd` bilgisi verilmezse göreli yollar worktree köklerine birleştirilerek denenir; belirsizlik çözümlenmez, ilk eşleşme elde edilir.

---

## SearchableItem

Çalışma alanı arama çubuğunun (search bar) bir öğe içinde çalışması için `SearchableItem` gereklidir:

- `type Match` — Arama sonucunu temsil eden `Any + Sync + Send + Clone` match tipi.
- `supported_options() -> SearchOptions` — Case, word, regex, replacement, selection, select_all, find_in_results desteklerini bildirir.
- `find_matches(query, window, cx) -> Task<Vec<Match>>` veya token'lı `find_matches_with_token`.
- `update_matches`, `clear_matches`, `activate_match`, `select_matches`.
- `replace` ve `replace_all` replace destekleyen öğeler içindir.
- `SearchEvent::{MatchesInvalidated, ActiveMatchChanged}` search UI'ını yeniden sorgulamaya zorlar.
- `SearchableItemHandle` tipi silinmiş search item'ıdır; `Item::as_searchable` bunu döndürerek pane toolbar search bar'ına bağlanır.
- `query_suggestion(seed_query_override: Option<SeedQuerySetting>, window, cx)` search bar'ın başlangıç sorgusunu üretir. `None` normal `seed_search_query_from_cursor` ayarını kullanır; `Some(Always)` gibi üzerine yazmalar Cmd-E veya Vim search gibi "bu çağrıda imleç altındaki kelimeyi kesinlikle kullan" davranışını açıkça ifade eder.

---

## FollowableItem

Collab ve follow akışı için `FollowableItem` kullanılır:

- `remote_id()`, `to_state_proto`, `from_state_proto` uzak görünüm durumunu taşır.
- `to_follow_event(event)` öğe olayını follow olayına çevirir.
- `add_event_to_update_proto` ve `apply_update_proto` artımlı uzak güncelleme akışıdır.
- `set_leader_id` takip edilen kullanıcı bilgisini öğe durumuna işler.
- `is_project_item(window, cx)` takip edilen öğenin proje kaynaklı olup olmadığını bildirir.
- `update_agent_location(location, window, cx)` temsilci (agent) konumu gibi ek takip bilgisini öğeye işler.
- `dedup(existing, ...) -> Option<Dedup>` uzak öğe açılırken mevcut öğeyi koruma veya değiştirme kararıdır.

**Dikkat Edilmesi Gereken Hususlar.** Serileştirme, seçenekler ve arama tarafında hataya açık kullanımlar:

- Öğe serileştirmeyi (serializable item) kaydetmediğinde `deserialize` hiç çağrılmaz; oturum geri yükleme (session restore) sessiz biçimde geçersiz öğeye düşebilir.
- `serialized_item_kind` global bir ad alanı (namespace) gibidir; başka öğe kimlikleriyle çakıştırmaman gerekir.
- Arama eşleşme (search match) tipini byte offset, buffer snapshot ve token ile uyumlu tutman gerekir; bayat match'i yeni buffer üzerinde kullanman yanlış aralığa yönlenmesine neden olur.
- `OpenOptions::visible = None` varsayılan olarak çalışma alanına görünür worktree ekleme anlamı taşımaz; path açma davranışını dizin/dosya ayrımı için açıkça seçmen gerekir.
