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

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `ItemSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `activate_on_close`, `close_position`, `file_icons`, `git_status`, `show_close_button`, `show_diagnostics` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ModalLayer`

| Grup | API | Not |
|---|---|---|
| Metotlar | `active_modal`, `has_active_modal`, `hide_modal`, `new`, `toggle_modal` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `Workspace`

| Grup | API | Not |
|---|---|---|
| Metotlar 1 | `absolute_path_of_worktree`, `actions`, `activate_item`, `activate_last_pane`, `activate_next_pane`, `activate_next_window`, `activate_pane_in_direction`, `activate_panel_for_proto_id` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 2 | `activate_previous_pane`, `activate_previous_window`, `active_call`, `active_global_call`, `active_item`, `active_item_as`, `active_modal`, `active_pane` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 3 | `active_worktree_creation`, `add_folder_to_project`, `add_item`, `add_item_to_active_pane`, `add_item_to_center`, `add_panel`, `adjacent_pane`, `agent_panel_position` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 4 | `all_docks`, `app_state`, `auto_watch_state`, `bottom_dock`, `bounding_box_for_pane`, `cancel`, `capture_dock_state`, `capture_state_for_worktree_switch` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 5 | `clear_all_notifications`, `clear_bookmarks`, `clear_navigation_history`, `client`, `close_all_docks`, `close_all_items_and_panes`, `close_global`, `close_inactive_items_and_panes` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 6 | `close_item_in_all_panes`, `close_items_with_project_path`, `close_panel`, `database_id`, `debugger_provider`, `default_dock_flex`, `dismiss_notification`, `dismiss_toast` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 7 | `dock_at_position`, `dock_flex_for_size`, `find_pane_in_direction`, `find_project_item`, `flush_serialization`, `focus_center_pane`, `focus_panel`, `focused_dock_position` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 8 | `focused_pane`, `follow`, `follow_next_collaborator`, `for_window`, `go_back`, `go_forward`, `has_active_modal`, `hide_modal` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 9 | `is_being_followed`, `is_dock_at_position_open`, `is_edited`, `is_notification_suppressed`, `is_project_item_open`, `item_of_type`, `items`, `items_of_type` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 10 | `join_all_panes`, `join_pane_into_next`, `key_context`, `leader_for_pane`, `left_dock`, `most_recent_active_path`, `move_focused_panel_to_next_position`, `move_item_to_pane_in_direction` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 11 | `move_pane_to_border`, `multi_workspace`, `new`, `new_local`, `on_window_activation_changed`, `open_abs_path`, `open_in_dev_container`, `open_item_abs_paths` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 12 | `open_panel`, `open_path`, `open_path_preview`, `open_paths`, `open_project_item`, `open_resolved_path`, `open_shared_screen`, `open_workspace_for_paths` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 13 | `pane_for`, `pane_for_entity_id`, `pane_for_item_id`, `panel`, `panel_size_state`, `panes`, `panes_mut`, `path_style` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 14 | `persist_panel_size_state`, `persisted_panel_size_state`, `prepare_to_close`, `project`, `project_group_key`, `project_path_for_path`, `prompt_for_new_path`, `prompt_for_open_path` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 15 | `prompt_to_save_or_discard_dirty_items`, `recent_active_item_by_type`, `recent_navigation_history`, `recent_navigation_history_iter`, `recently_activated_items`, `register_action`, `register_action_renderer`, `remove_panel` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 16 | `reopen_closed_item`, `reset_pane_sizes`, `resize_pane`, `reveal_panel`, `right_dock`, `root_paths`, `save_active_item`, `send_keystrokes_impl` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 17 | `session_id`, `set_active_worktree_creation`, `set_bottom_dock_layout`, `set_debugger_provider`, `set_dev_container_task`, `set_dock_structure`, `set_multi_workspace`, `set_open_in_dev_container` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 18 | `set_panel_size_state`, `set_panels_task`, `set_prompt_for_new_path`, `set_prompt_for_open_path`, `set_sidebar_focus_handle`, `set_terminal_provider`, `set_titlebar_item`, `show_error` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 19 | `show_initial_notifications`, `show_notification`, `show_portal_error`, `show_toast`, `show_worktree_trust_security_modal`, `split_abs_path`, `split_and_clone`, `split_and_move` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 20 | `split_item`, `split_pane`, `split_path`, `split_path_preview`, `start_following`, `status_bar`, `status_bar_visible`, `suppress_notification` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 21 | `swap_pane_in_direction`, `take_panels_task`, `titlebar_item`, `toggle_auto_watch`, `toggle_centered_layout`, `toggle_dock`, `toggle_dock_panel_flexible_size`, `toggle_modal` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 22 | `toggle_panel_focus`, `toggle_status_toast`, `unfollow`, `unfollow_in_pane`, `unsuppress`, `update_active_view_for_followers`, `user_store`, `visible_worktrees` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 23 | `weak_handle`, `with_local_or_wsl_workspace`, `with_local_workspace`, `worktree_scans_complete`, `worktrees`, `zoomed_item` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `centered_layout` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

<!-- phase14-api-anchor:end -->
