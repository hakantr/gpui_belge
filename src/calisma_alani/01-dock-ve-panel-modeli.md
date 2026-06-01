# Dock ve Panel Modeli

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Dock` | `focus_handle` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Dock` | Metotlar | `activate_panel`, `active_panel`, `new`, `position`, `remove_panel`, `resize_active_panel`, `resize_all_panels`, `set_open`, `toggle_action`, `visible_panel` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `Panel` | Trait üyeleri 1 | `activation_priority`, `default_size`, `enabled`, `has_flexible_size`, `hide_button_setting`, `icon_label`, `icon_tooltip`, `initial_size_state`, `is_agent_panel`, `is_zoomed`, `min_size`, `pane`, `panel_key`, `persistent_name` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |
| `Panel` | Trait üyeleri 2 | `position`, `position_is_valid`, `remote_id`, `set_active`, `set_flexible_size`, `set_position`, `set_zoomed`, `size_state_changed`, `starts_open`, `supports_flexible_size`, `toggle_action` | Implementasyonların karşıladığı trait sözleşmesi üyeleridir. |


---

## Çalışma Alanı İskeleti

![Çalışma Alanı İskeleti](assets/workspace-iskeleti.svg)

`workspace` crate'i GPUI çekirdeğinin üstüne `Workspace` adında merkezi bir uygulama görüntüsü koyar; merkezde pane grubunu, solda `left_dock`'u, sağda `right_dock`'u ve altta `bottom_dock`'u bir arada tutar. Aşağıdaki kaynaklar bu modelin tamamına yön verir: `crates/workspace/src/workspace.rs`, `crates/workspace/src/dock.rs`, `crates/workspace/src/pane.rs`.

**Panel yardımcı yüzeyi.** Panel UI'ı yazarken aşağıdaki sınırları bilmen gerekir:

- `panel::PanelHeader` varsayılan `header_height` veya `panel_header_container` sağlayan bir yardımcı trait değildir; `workspace::Panel` üstünde işaretleyici bir trait'tir. Başlık yüksekliği gerekiyorsa doğrudan `Tab::container_height(cx)`, kapsayıcı gerekiyorsa `h_flex()`/`v_flex()` ve `ui::Button`/`ui::IconButton` bileşenleri kurarsın.
- `panel_button`, `panel_filled_button`, `panel_icon_button` ve `panel_filled_icon_button` serbest fonksiyon yardımcıları yoktur. Panel UI'ında buton layer/size/style kararları doğrudan bileşen üzerinde açıkça belirtilir.
- Git paneli `GitPanelTab::{Changes, History}` durumuyla iki tab çizer. Changes sekmesi staged/unstaged liste ve commit footer akışını taşır; History sekmesi commit geçmişini `UniformListScrollHandle` ile sanallaştırır, ok tuşlarıyla `focused_history_entry` seçer ve confirm ile `CommitView::open` çağırır. Panel action dinleyicilerine `ActivateChangesTab` ve `ActivateHistoryTab` eklemen gerekir.
- Branch diff görünümü toolbar'daki `Base: ...` popover'ı ile diff baz branch'ini değiştirir. Picker `branch_picker::select_popover(...)` üzerinden checkout yapmadan branch seçer, geri çağrı `DiffBase::Merge { base_ref }` ayarlar ve `BranchDiff::set_diff_base` `BranchDiffEvent::DiffBaseChanged` yayar. Ağaç tabanlı merge-base diff hesabı sürerken `is_tree_base_loading()` true döner; boş görünümler bunu yükleme göstergesiyle ayırmalı, eski statik baz varsayımına dönmemelidir.

**Çalışma alanı yapısı.** Çalışma alanı üç ana dock'u ve merkezdeki pane grubunu bir arada tutar:

- **Oluşturma:** Zaten hazırlanmış bir `Project` entity'si için `Workspace::new(workspace_id, project, app_state, window, cx)` kullanılır; path listesinden yeni çalışma alanı açma akışında ise yüksek seviyeli `Workspace::new_local(...)` tercih edersin.
  - `workspace_id`: Varsa kalıcı çalışma alanı kimliği; yeni oturumlarda `None` verilebilir.
  - `project`: Dosya, arama, dil ve terminal servislerini sağlayan çekirdek proje entity'si.
  - `app_state`: Genel istemci (`client`), kullanıcı ve dil (`LanguageRegistry`) kayıtlarını barındıran durum.
- `Workspace` merkezde pane grubunu, solda `left_dock`'u, sağda `right_dock`'u ve altta `bottom_dock`'u taşır.
- Dock entity'si `DockPosition::{Left, Bottom, Right}` ile konumlanır.
- `Workspace::left_dock()`, `right_dock()`, `bottom_dock()`, `all_docks()`, `dock_at_position(position)` ile erişim sağlanır.
- Aksiyonlar: `ToggleLeftDock`, `ToggleRightDock`, `ToggleBottomDock`, `ToggleAllDocks`, `CloseActiveDock`, `CloseAllDocks`, `Increase/DecreaseActiveDockSize`, `ResetActiveDockSize` gibi.

**Panel yazma.** Yeni bir panel `Panel` trait'i uygulanarak tanımlanır:

- `persistent_name()` ve `panel_key()` persist, keymap ve telemetry kimliğidir.
- `position`, `position_is_valid`, `set_position` panelin hangi dock'ta oturduğunu yönetir.
- `default_size`, `min_size`, `initial_size_state`, `size_state_changed`, `supports_flexible_size`, `has_flexible_size`, `set_flexible_size` boyut ve kalıcılık davranışını belirler.
- `icon`, `icon_tooltip`, `icon_label`, `toggle_action`, `activation_priority` status bar butonunu ve sıralamayı tanımlar.
- `starts_open`, `enabled`, `set_active`, `is_zoomed`, `set_zoomed`, `pane`, `remote_id` dock durumu ve uzak çalışma alanı entegrasyonudur.
- `is_agent_panel` ajan paneli gibi özel panelleri işaretler; `hide_button_setting` panel butonunu gizleme ayarına bağlanır.
- Panel `Focusable + EventEmitter<PanelEvent> + Render` olmalıdır.

**Dock davranışı.** Dock entity'sinin panel ekleme ve görünürlük yönetimi şu şekildedir:

- `Dock::add_panel` paneli `activation_priority` sırasına göre ekler. Aynı priority'i kullanan iki panel hata ayıklama build'inde panic'e yol açar; her panel benzersiz bir priority seçmelidir.
- `Dock::set_open`, `activate_panel`, `active_panel`, `visible_panel`, `panel::<T>()`, `remove_panel`, `resize_active_panel`, `resize_all_panels` temel yönetim API'leridir.
- Panel `PanelEvent::Activate` yaydığında dock açılır, panel aktiflenir ve odak panele taşınır.
- `PanelEvent::Close` aktif görünür paneli kapatır.
- `PanelEvent::ZoomIn/ZoomOut` çalışma alanı zoom katmanı durumunu günceller.
- Boyut durumu `PanelSizeState { size, flex }` olarak kalıcılaştırılır.

**Dock ve panel API kapsamı.** Bu ailedeki action ve enum'ların çoğu ayrı uzun bölüm değil, davranış tablosu gerektirir:

| API | Açıklama |
|-----|----------|
| `dock` | `Dock`, `Panel`, `PanelHandle`, `DockPosition`, `PanelEvent` ve panel boyut durumunu barındıran modül ailesidir. |
| `DockPosition` | `Left`, `Bottom`, `Right` dock yerleşimlerini taşır; `axis()` yan dock'lar için `Horizontal`, alt dock için `Vertical` döndürür. |
| `PanelEvent` | `Activate`, `Close`, `ZoomIn`, `ZoomOut` olaylarıyla dock'un panel görünürlüğünü, odaklanmasını ve zoom katmanını günceller. |
| `PanelSizeState` | `size: Option<Pixels>` ve `flex: Option<f32>` alanlarıyla dock panel boyutunu kalıcılaştırır. |
| `ToggleLeftDock` | Sol dock'u açar veya kapatır. |
| `ToggleRightDock` | Sağ dock'u açar veya kapatır. |
| `ToggleBottomDock` | Alt dock'u açar veya kapatır. |
| `ToggleAllDocks` | Açık dock setini saklayıp tüm dock'ları kapatır; tekrar çağrıldığında önceki açık seti geri yükler. |
| `CloseActiveDock` | O anda odaklı veya aktif görünen dock'u kapatır. |
| `CloseAllDocks` | Üç dock'u da kapatır. |
| `DecreaseActiveDockSize` | `px` alanındaki piksel miktarı kadar aktif dock boyutunu azaltır. |
| `ResetActiveDockSize` | Aktif dock panel boyutunu varsayılan boyuta döndürür. |
| `ZoomIn` | Aktif pane veya panel görünümünü zoom katmanına taşır. |
| `ZoomOut` | Zoom durumunu kapatır ve normal pane/panel yerleşimine döner. |

**Dock, panel ve sidebar ek API kapsamı.** Aşağıdaki public yüzeyler dock modelinin ayar, serileştirme, render ve sidebar bağlantı parçalarıdır. Birçoğu re-export olduğu için ayrı başlık yerine ait olduğu karar hattında okunmalıdır.

| API | Rol |
| :-- | :-- |
| `DockData`, `DockStructure` | Dock/pane ağacının restore ve serialization sırasında taşınan veri modelidir. |
| `PanelId`, `PanelButtons`, `DraggedSidebar`, `SidebarHandle` | Panel kimliği, panel buton seti, sidebar drag payload'u ve sidebar entity handle sınırını temsil eder. |
| `ActivePanelModifiers`, `StatusBarSettings`, `TabBarSettings` | Workspace ayarlarından dock/panel/tab/status davranışına yansıyan küçük settings taşıyıcılarıdır. |
| `AutosaveSetting`, `BottomDockLayout`, `EncodingDisplayOptions`, `RestoreOnStartupBehavior` | Workspace'in settings content re-export'larıdır; autosave, alt dock düzeni, encoding görünümü ve startup restore davranışını bağlar. |
| `IncreaseActiveDockSize`, `DecreaseOpenDocksSize`, `IncreaseOpenDocksSize`, `ResetOpenDocksSize` | Aktif veya açık dock'ların piksel/flex boyutunu büyütme, küçültme ve sıfırlama action'larıdır. |
| `ActivePaneDecorator`, `PaneRenderContext`, `PaneRenderResult`, `HANDLE_HITBOX_SIZE` | Pane group render'ında aktif pane vurgusu, drag/resize hitbox ölçüsü ve render sonucu taşıyıcılarını kapsar. |
| `LeaderDecoration`, `PaneLeaderDecorator` | Collab/follow liderinin pane üzerinde görsel decoration olarak çizilmesini sağlayan trait ve taşıyıcı yüzeyidir. |
| `MoveFocusedPanelToNextPosition`, `CloseWorkspaceSidebar`, `FocusWorkspaceSidebar`, `ToggleWorkspaceSidebar` | Odaklı paneli konum döngüsünde taşır veya multi-workspace sidebar'ını kapatır, odaklar, açıp kapatır. |
| `MoveProjectToNewWindow`, `MultiWorkspaceEvent`, `MultiWorkspaceState`, `SerializedProjectGroup` | Multi-workspace penceresinde proje grubunu yeni pencereye taşıma, event ve persist state modelini taşır. |
| `NextProject`, `PreviousProject`, `NextThread`, `PreviousThread`, `NewThread` | Sidebar MRU geçişinde proje/thread ileri-geri gezinme ve yeni thread açma action'larıdır. |
| `PathList`, `SerializedPathList`, `RecentWorkspace`, `RemoteConnectionIdentity` | Recent workspace ve remote workspace açma akışında path listesi, serialize edilen path listesi ve remote kimliğini taşır. |
| `remote_connection_identity`, `same_remote_connection_identity`, `sidebar_side_context_menu` | Remote kimlik karşılaştırması ve sidebar tarafı bağlam menüsü için re-export edilen helper'lardır. |

**`toggle_dock` akışı.** Dock'u açıp kapatan tipik akış birkaç adımdan oluşur:

1. Dock görünürse açık pozisyonlar kaydedilir.
2. Dock açık durumu terslenir.
3. Aktif panel yoksa ilk etkin panel aktif edilir.
4. Açılıyorsa odak, panelin focus handle'ına taşınır; kapanıyorsa odaktaki panelden geliniyorsa orta pane'e geri verirsin.
5. Çalışma alanı serileştirilir.

**Yeni panel eklerken kontrol.** Aşağıdaki noktalar yeni bir panel hazırlanırken gözden geçirilmelidir:

- `panel_key` kalıcılaştırma ve keymap kimliğidir; yeni panelde baştan sabit bir değer seçmen gerekir.
- `position_is_valid` alt ve yan sınırlamalarını net tanımlamalıdır.
- `toggle_action()` action'ı önceden kaydedilmiş olmalıdır.
- `activation_priority()` benzersiz olmalıdır.
- `set_active` içinde UI durumu değiştiriliyorsa `cx.notify()` çağrısı unutulmamalıdır.
- Dock değiştiren ayar gözlemcilerinde panel taşınırken boyut durumu ekseni değişiyorsa sıfırlanabilir; bu mevcut `Dock::add_panel`/ayar gözlemci akışında zaten yaparsın.

---

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `PanelEvent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Activate`, `Close`, `ZoomIn`, `ZoomOut` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `PanelHandle`

| Grup | API | Not |
|---|---|---|
| Trait metotları 1 | `activation_priority`, `default_size`, `enabled`, `has_flexible_size`, `hide_button_setting`, `icon`, `icon_label`, `icon_tooltip` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 2 | `initial_size_state`, `is_agent_panel`, `is_zoomed`, `min_size`, `move_to_next_position`, `pane`, `panel_focus_handle`, `panel_id` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 3 | `panel_key`, `persistent_name`, `position`, `position_is_valid`, `remote_id`, `set_active`, `set_flexible_size`, `set_position` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |
| Trait metotları 4 | `set_zoomed`, `size_state_changed`, `supports_flexible_size`, `to_any`, `toggle_action` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `DockPosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bottom`, `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `axis` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `PanelSizeState`

| Grup | API | Not |
|---|---|---|
| Alanlar | `flex`, `size` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PanelButtons`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `PaneRenderResult`

| Grup | API | Not |
|---|---|---|
| Alanlar | `contains_active_pane`, `element` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PaneRenderContext`

| Grup | API | Not |
|---|---|---|
| Alanlar | `active_call`, `active_pane`, `app_state`, `follower_states`, `project`, `workspace` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PaneLeaderDecorator`

| Grup | API | Not |
|---|---|---|
| Trait metotları | `active_pane`, `decorate`, `workspace` | Trait sözleşmesinin implementor tarafından sağlanan public metotlarıdır. |

### `ActivePaneDecorator`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `IncreaseActiveDockSize`

| Grup | API | Not |
|---|---|---|
| Alanlar | `px` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DecreaseActiveDockSize`

| Grup | API | Not |
|---|---|---|
| Alanlar | `px` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `IncreaseOpenDocksSize`

| Grup | API | Not |
|---|---|---|
| Alanlar | `px` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DecreaseOpenDocksSize`

| Grup | API | Not |
|---|---|---|
| Alanlar | `px` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ActivePanelModifiers`

| Grup | API | Not |
|---|---|---|
| Alanlar | `border_size`, `inactive_opacity` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `TabBarSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `show`, `show_nav_history_buttons`, `show_pinned_tabs_in_separate_row`, `show_tab_bar_buttons` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `StatusBarSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `active_encoding_button`, `active_language_button`, `cursor_position_button`, `line_endings_button`, `show`, `show_active_file` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

<!-- phase14-api-anchor:end -->
