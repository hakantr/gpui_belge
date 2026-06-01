# Çalışma Alanı

Zed'in `workspace` crate'i GPUI çekirdeğinin üstüne uygulama seviyesinde bir oturum modeli koyar. Bu bölüm, GPUI rehberi içinde kapsam dışı kalan ama yeni bir Zed-benzeri uygulama yazılırken sık sık karşılaşılan workspace katmanını ayrı bir ünite olarak toplar. İçerik daha önce `gpui_kullanimi/14-zed-workspace.md` ve `gpui_kullanimi/16-komut-paleti-ve-picker.md` içinde dağınık olarak duruyordu; bu bölüme taşındı ve yeni alt başlıklara ayrıldı.

Ana referanslar: `crates/workspace/src/workspace.rs`, `crates/workspace/src/dock.rs`, `crates/workspace/src/pane.rs`, `crates/workspace/src/item.rs`, `crates/workspace/src/modal_layer.rs`, `crates/workspace/src/notifications.rs`, `crates/workspace/src/persistence.rs`, `crates/command_palette/`, `crates/command_palette_hooks/`.

`workspace` crate'inin public modül yüzeyi şu dosya ailelerinden oluşur: `active_file_name`, `dock`, `history_manager`, `invalid_item_view`, `item`, `notifications`, `pane`, `pane_group`, `path_list`, `searchable`, `security_modal`, `shared_screen`, `focus_follows_mouse`, `tasks` ve `welcome`. Bu bölüm ana uygulama akışında sık kullanılan `Workspace`, dock/pane/item, modal, notification, open/restore ve command palette sözleşmelerine odaklanır. `welcome`, `tasks`, `shared_screen` gibi daha özel modüller burada kaynak yüzeyi olarak izlenir; ayrı öğretici reçete olarak genişletilmez.

| Modül/crate | Bu bölümdeki doğal yeri |
|-------------|-------------------------|
| `command_palette` | Komut paleti modalı, fuzzy arama, geçmiş ve onay akışı. |
| `command_palette_hooks` | Palet filtreleri ve global interceptor özelleştirmeleri. |
| `dock` | Sol, sağ ve alt dock'lar; `Panel` trait'i ve panel boyut durumu. |
| `focus_follows_mouse` | Hover ile odak değiştirme davranışı. |
| `history_manager` | Yakın zamanlı workspace geçmişi ve jump list güncellemesi. |
| `modal_layer` | `ModalView` ve modal dismiss kararları. |
| `notifications` | Workspace notification, app-level notification ve hata yardımcıları. |
| `pane` | Tab listesi, item açma/kapama, zoom ve split action'ları. |
| `pane_group` | Split ağacı ve pane resize/swap/taşıma davranışı. |
| `path_list` | Workspace path kümeleri ve recent history path normalizasyonu. |

Workspace crate kökü ve `item` modülünden gelen küçük re-export/action kayıtları:

| API | Kısa anlamı |
| :-- | :-- |
| `CloseProject`, `CloseWindow`, `Reload`, `Mute`, `OpenComponentPreview`, `Feedback` | Workspace action tipleridir; komut paleti, menü veya titlebar gibi yüzeyler bu action'ları dispatch eder. |
| `reload`, `client_side_decorations` | Workspace reload ve client-side decoration kararını veren crate-level helper'lardır. |
| `ModalLayer` | Modal view'leri workspace üst katmanında tutan modeldir; ayrıntısı item/modal/toast bölümündedir. |
| `ItemSettings`, `SettingsLocation`, `RegisterSetting`, `Settings` | `workspace::item` tarafının settings entegrasyon re-export'larıdır; item davranışı için settings crate yüzeyine bağlanır. |
| `SidebarRenderState`, `item`, `ui` | Sidebar render durumu, item modülü ve UI re-export kapısıdır; üst bar/bileşen belgelerinde geçen kullanımların API sahibi yine `workspace` olur. |

Bölüm hangi alt dosyada hangi yüzeyi anlatır:

- **Dock ve Panel modeli** — `Workspace` iskeleti, `Dock`, `Panel` trait'i ve `toggle_dock` akışı.
- **Item, Pane, Modal, Toast ve Notification** — Pane tab içeriği için `Item`/`ItemHandle`, modal layer, `StatusItemView`, toast/notification API yüzeyi.
- **Serileştirme, OpenOptions ve open\_*** — `SerializableItem`, `OpenOptions`, `ProjectItem`, `SearchableItem`, `FollowableItem`.
- **PaneGroup, NavHistory, Toolbar ve Sidebar** — Split ağacı, preview/pin, `ItemNavHistory`, `ToolbarItemView`, `Sidebar`/`MultiWorkspace` entegrasyonu.
- **Notification yardımcıları ve async hata gösterimi** — App-level notification, `notify_err`, `detach_and_prompt_err` aileleri.
- **AppState, WorkspaceStore, WorkspaceDb ve OpenListener** — Workspace açma servis paketi, kalıcılık, CLI/URL açma akışı.
- **Item ayarları, bağlam menüsü, ApplicationMenu ve focus-follows-mouse** — `ItemSettings`, `ContextMenu`, client-side application menu, focus-follows-mouse davranışı.
- **Komut paleti** — `CommandPaletteFilter`, `CommandInterceptor`, aliases, çalışma zamanı akışı, fuzzy arama ve geçmiş.
