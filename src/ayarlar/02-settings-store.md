# SettingsStore

`SettingsStore` Zed'in tüm ayar kaynaklarını tek bir tip güvenli store içinde birleştirir. Runtime global değerler `Default` üstüne `Extension`, `Global`, kullanıcı/profil/release/OS override'ları ve `Server` katmanlarıyla kurulur; worktree/path hedefli okumada `local_settings` bunun üstüne eklenir. Birleşik içerik daha sonra kayıtlı `Settings` tiplerine yedirilir.

![SettingsStore Katmanları](assets/settings-store-katmanlari.svg)

---

## Store yapısı

Aşağıdaki struct alanları, store'un hem kaynak içerikleri hem de birleşik sonucu nerede tuttuğunu gösterir:

```rust
pub struct SettingsStore {
    setting_values: HashMap<TypeId, Box<dyn AnySettingValue>>,
    default_settings: Rc<SettingsContent>,
    user_settings: Option<UserSettingsContent>,
    global_settings: Option<Box<SettingsContent>>,
    extension_settings: Option<Box<SettingsContent>>,
    server_settings: Option<Box<SettingsContent>>,
    language_semantic_token_rules: HashMap<SharedString, SemanticTokenRules>,
    merged_settings: Rc<SettingsContent>,
    last_user_settings_content: Option<String>,
    last_global_settings_content: Option<String>,
    local_settings: BTreeMap<(WorktreeId, Arc<RelPath>), SettingsContent>,
    pub editorconfig_store: Entity<EditorconfigStore>,
    file_errors: BTreeMap<SettingsFile, SettingsParseResult>,
    _settings_files_watcher: Option<Task<()>>,
    _setting_file_updates: Task<()>,
    setting_file_updates_tx: mpsc::UnboundedSender<
        Box<dyn FnOnce(AsyncApp) -> LocalBoxFuture<'static, Result<()>>>,
    >,
}

impl Global for SettingsStore {}
```

- `default_settings` `default.json` üzerinden yüklenen sabit içerik.
- `user_settings` kullanıcının `~/.config/zed/settings.json` içeriği. Release kanalı, OS ve profil override'larını da taşır.
- `global_settings` collab/uzak sunucu tarafından yayılan global içerik.
- `server_settings` SSH proje veya uzak sunucu yan ayar dosyasıdır.
- `extension_settings` yüklü uzantıların eklediği içeriktir.
- `local_settings` proje veya worktree içindeki `.zed/settings.json` dosyasını `(WorktreeId, RelPath)` çiftiyle saklar.
- `merged_settings` öncelik kuralına göre tek bir içerik halinde önbelleğe alınmış sonuçtur; sorgular bu değer üzerinden çözülür.
- `last_user_settings_content` ve `last_global_settings_content` aynı ham metnin tekrar parse edilmesini engelleyen son içerik önbellekleridir.
- `editorconfig_store` proje içindeki `.editorconfig` dosyalarını ayrı bir entity'de tutar.
- `_settings_files_watcher`, `_setting_file_updates` ve `setting_file_updates_tx` dosya izleme ile yazma isteklerini store yaşam döngüsüne bağlar.

---

## Kurulum

En küçük kurulumda store oluşturulur, global state'e konur ve aktif profil değişimi izlenir:

```rust
let ayarlar = SettingsStore::new(cx, &default_settings());
cx.set_global(ayarlar);
SettingsStore::observe_active_settings_profile_name(cx).detach();
```

`settings::init(cx)` aynı adımı uygular ve aktif profil değişimi için gözlemciyi kurarsın. Test koşumunda `SettingsStore::test(cx)` sahte FS ve test ortamı için minimum konfigürasyonu hazırlar.

`SettingsStore::update(cx, |store, cx| { ... })` herhangi bir `BorrowAppContext` üzerinden `cx.update_global` çağrısını sarmalar. Kaynak içinde doğrudan `SettingsStore::update_global(cx, ...)` kullanımı da GPUI `UpdateGlobal` trait'inden gelir; kayıt ekleme, üzerine yazma veya yeni içerik yedirme bu blok içinde yaparsın.

`SettingsStore::load_settings(fs)` kullanıcı `settings.json` metnini async olarak okuyan düşük seviye yardımcıdır; yazma/diff akışları eski metne ihtiyaç duyduğunda bunu kullanır. `SettingsStore::watch_settings_files(fs, cx, callback)` kullanıcı ve global ayar dosyalarını `watch_config_file` ile bağlar; her değişimde ilgili `SettingsFile`, `SettingsParseResult` ve `App` callback'e verirsin.

`SettingsStore::register_setting::<T>()` derive üzerinden `inventory` kayıt listesi zaten doluyken nadir kullanılır; manuel kayıt isteniyorsa burası ana giriştir.

---

## Kaynak öncelik sıralaması

`SettingsFile` enum'u ayar kaynaklarını ve çakışma çözüm sırasını taşır:

```rust
pub enum SettingsFile {
    Default,
    Global,
    User,
    Server,
    Project((WorktreeId, Arc<RelPath>)),
}
```

`Ord` uygulaması dosya raporlama ve override analizi için `Project` > `Server` > `User` > `Global` > `Default` sırasını verir. `merged_settings` ise store'un runtime merge hattında `Default` üstüne `Extension`, `Global`, kullanıcı/profil/release/OS override'ları ve `Server` katmanlarıyla inşa edilir; path hedefli okuma yaparsan local proje ayarları bu değerin üstüne eklenir. Aynı kullanıcının birden çok worktree dosyası varsa daha derin path daha yüksek önceliği alır.

`SettingsLocation { worktree_id, path }` sorgulayan tarafa "bana bu yol için geçerli değeri ver" der; store öncelik zincirinde local katmanları yer almıyorsa global değere düşer.

`LocalSettingsKind::{Settings, Tasks, Editorconfig, Debug}` proje yerel dosyalarının tipini belirtir. `LocalSettingsPath::{InWorktree(Arc<RelPath>), OutsideWorktree(Arc<Path>)}` worktree içi ve dışı yolları ayırır; `OutsideWorktree` ev dizinine yerleştirilmiş bir parent `.editorconfig` gibi kaynakları temsil eder.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `SettingsFile` | `Default`, `Global`, `User`, `Server`, `Project((WorktreeId, Arc<RelPath>))` | Store'a yedirilen ayar kaynağını ve merge önceliğini taşır. |
| `SettingsLocation` | `worktree_id`, `path` | Worktree/path özel ayar okumasında hedef konumu belirtir. |
| `LocalSettingsKind` | `Settings`, `Tasks`, `Editorconfig`, `Debug` | Worktree yerel dosyasının hangi işlem yoluna ayrılacağını seçer; `Tasks` ve `Debug` settings store içine kabul edilmez, `Editorconfig` ayrı store'a gider. |
| `LocalSettingsPath` | `InWorktree`, `OutsideWorktree`, `is_outside_worktree`, `to_proto`, `from_proto` | Yerel dosya yolunun worktree içinde mi dışında mı olduğunu ve proto dönüşümünü taşır. |
| `WorktreeId` | `from_usize`, `from_proto`, `to_proto` | Worktree kimliğini store ve proto sınırında taşır. |

---

## Okuma

`SettingsStore::get<T: Settings>(path)` `path` üzerine yazma katmanlarını dahil ederek değeri çözer. Aşağıdaki sarmalayıcı yöntemler trait üzerinde bulunur:

- `T::get_global(cx)` — `path = None`, sadece global birleşik değer.
- `T::get(Some(SettingsLocation { ... }), cx)` — worktree veya path özel değer.
- `T::try_get(cx)` — store kurulmamışsa `None`.
- `T::try_read_global(async_cx, |ayar| ...)` — async bağlamda salt okuma.

Düşük seviye yardımcılar:

- `SettingsStore::merged_settings()` — birleşik `SettingsContent` referansı.
- `SettingsStore::raw_user_settings() -> Option<&UserSettingsContent>` — birleştirilmemiş kullanıcı içeriği; profil, kanal ve OS override'larıyla birlikte.
- `SettingsStore::raw_default_settings() -> &SettingsContent` — default'ı görüntülemek için.
- `SettingsStore::configured_settings_profiles()` — kullanıcı tarafında tanımlanmış profil adlarını listeler.
- `SettingsStore::get_all_locals::<T>()` — bir `Settings` tipinin worktree başı tüm local değerlerini döndürür.
- `SettingsStore::get_all_files()` — UI/override analizi için proje, server, user ve default `SettingsFile` kaynaklarını döndürür; global ve extension katmanları bu listede bilinçli olarak yer almaz.
- `SettingsStore::get_content_for_file(file)` — belirli bir kaynağın ham `SettingsContent` referansını verir.
- `SettingsStore::get_overrides_for_field(...)`, `get_value_from_file(...)`, `get_value_up_to_file(...)` — belirli bir alanın hangi kaynakta hangi değeri taşıdığını açıklayan analitik yardımcılar; ayarlar UI'ında "bu değer hangi dosyadan geliyor?" sorusunu yanıtlamak için kullanırsın.

---

## Yazma

- `SettingsStore::override_global<T>(value)` programatik üzerine yazmadır; dosyaya yazmaz.
- `SettingsStore::update_settings_file(fs, update)` user `settings.json` dosyasına closure üzerinden değişiklik uygular ve sonucu yazar. Üst seviye `settings::update_settings_file(fs, cx, update)` aynı çağrıyı sarmalar.
- `SettingsStore::update_settings_file_with_completion(fs, update) -> oneshot::Receiver<Result<()>>` aynı işi yapar ama yazma tamamlanınca tetiklenen bir kanal döndürür; UI tarafında "kaydedildi" geribildirimi gerektiğinde kullanırsın.
- `SettingsStore::update_user_settings(...)` yalnız test bağlamlarında mevcuttur; uygulama kodunda kalıcı yazma için `update_settings_file` yolu tercih edersin.
- `SettingsStore::import_vscode_settings(fs, vscode_settings, cx)` `VsCodeSettings` içeriğini kullanıcı ayar dosyasına aktarır; aşağıdaki "VS Code içe aktarımı" bölümünde detaylandırılır.

JSON metin güncelleme yardımcıları:

| API | Rol |
| :-- | :-- |
| `replace_value_in_json_text` | JSON metni içinde hedef path'teki değeri pretty biçim korunarak değiştirir; settings UI yazma akışının düşük seviye yardımcısıdır. |
| `replace_top_level_array_value_in_json_text` | Kök seviyedeki array değerlerinden birini bulup değiştirir. |
| `append_top_level_array_value_in_json_text` | Kök seviyedeki array'e yeni değer ekler. |
| `to_pretty_json` | `serde_json::Value` değerini Zed settings dosyasının beklediği pretty JSON metnine dönüştürür. |

Ayrı kaynakları doğrudan ayarlamak için store API'leri vardır:

- `set_default_settings(content, cx)` ve `update_default_settings(closure, cx)` — startup veya test sırasında default'ı değiştirir.
- `set_user_settings(content, cx)` — dosya izleyicisinden gelen ham JSON'u kullanıcıya yazar.
- `set_global_settings(content, cx)` — collab veya uzak sunucudan gelen globali yazar.
- `set_server_settings(content, cx)` — SSH proje veya uzak sunucu yan ayar içeriğini yedirir.
- `set_local_settings(worktree_id, path, kind, content, cx)` — proje yerel dosyasını yedirir. `kind` `LocalSettingsKind` üzerinden ayar/tasks/editorconfig/debug ayrımını yapar.
- `clear_local_settings(root_id, cx)` — worktree kapandığında ona ait yerel ayarları temizler.
- `set_extension_settings(content, cx)` — uzantıdan gelen ayarları yedirir.
- `set_language_semantic_token_rules(...)` ve `remove_language_semantic_token_rules(...)` — dil bazlı semantik token tanımlarını ekler veya temizler; `language_semantic_token_rules(language)` ile sorgulanır.

`SettingsParseResult` user, global ve project settings parse akışlarında ayrıştırma sonucunu taşır; başarılı durumda `parse_status = ParseStatus::Success` ve `migration_status = MigrationStatus::NotNeeded` varsayılanı kullanırsın. `ParseStatus::Unchanged` ise dosya içeriği değişmediği için yeniden parse gerekmeyen durumları ayırır. Hata varsa parse veya migrasyon mesajı burada saklarsın. `SettingsStore::error_for_file(file)` belirli bir dosyanın hata durumunu okur. `MigrationStatus` migrasyon adımının başarılı olup olmadığını bildirir; uygulama kodunda birleşik sonuç `SettingsParseResult::result() -> Result<bool>` ile ele alman gerekir. Dönen `bool`, dosyanın otomatik migrasyon gerektirip gerektirmediğini bildirir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `SettingsParseResult` | `parse_status`, `migration_status`, `unwrap`, `expect`, `result`, `requires_user_action`, `ok`, `parse_error` | Parse ve migrasyon sonucunu UI veya log akışına çevirmek için kullanılır. |
| `ParseStatus` | `Success`, `Failed`, `Unchanged` | Parse sonucunun başarı, hata veya değişmeyen içerik durumunu taşır. |
| `MigrationStatus` | `NotNeeded`, `Succeeded`, `Failed { error }` | Ayar dosyasının otomatik migrasyon durumunu bildirir. |

---

## Schema üretimi

UI ayarlar editörü ve LSP otomatik tamamlama için `SettingsStore` JSON schema üretir:

- `SettingsStore::json_schema(&params)` user `settings.json` için tam schema'yı üretir.
- `SettingsStore::project_json_schema(&params)` proje seviyesindeki `.zed/settings.json` için kısıtlı schema'yı üretir.
- `SettingsJsonSchemaParams<'a>` schema üretimi için gerekli registry ve tema verisini taşır; çağıran genelde `App` üzerinden bunu inşa eder.

LSP ayarları için `LSP_SETTINGS_SCHEMA_URL_PREFIX = "zed://schemas/settings/lsp/"` ön ekiyle ayrı schema URL'leri yayılır; her dil server'ı için ayrı bir document bağlanır.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `SettingsJsonSchemaParams` | `language_names`, `font_names`, `theme_names`, `icon_theme_names`, `lsp_adapter_names`, `action_names`, `action_documentation`, `deprecations`, `deprecation_messages` | Runtime JSON schema üretiminde kullanılan isim ve dokümantasyon listelerini taşır. |
| `LSP_SETTINGS_SCHEMA_URL_PREFIX` | `zed://schemas/settings/lsp/` | LSP ayar schema URL'leri için ortak prefix'tir. |
| `SemanticTokenRules` | language semantic token kuralları | Dil bazlı semantic token ayarları store içinde bu tip üzerinden saklanır. |
| `language` | `settings_content` reexport | Dil bazlı ayar content tiplerini kök `settings_content` yüzeyine çıkarır; store bu tipleri schema ve path-scoped merge sırasında kullanır. |

---

## `SettingsContent` domain schema aileleri

`SettingsStore` içindeki `merged_settings: Rc<SettingsContent>` tek bir büyük runtime sözleşme gibi görünür, ama kaynakta bu sözleşme dosya/domain bazlı content ailelerine ayrılır. Aşağıdaki tablolar bu content tiplerini kullanıcı yüzeyindeki doğal aileleriyle okur; alan detayları gerektiğinde ilgili runtime bölümünde genişletilir.

### Editör content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `EditorSettingsContent` | Editor top-level schema payload'ı | Cursor, hover popover, scrollbar, minimap, gutter, arama, completion ve LSP editor davranışlarını tek content altında toplar. |
| `EditorSettingsContent` | Etkileşim ve arama alanları | `auto_signature_help`, `autoscroll_on_clicks`, `cursor_blink`, `double_click_in_multibuffer`, `drag_and_drop_selection`, `fast_scroll_sensitivity`, `horizontal_scroll_margin`, `middle_click_paste`, `mouse_wheel_zoom`, `multi_cursor_modifier`, `redact_private_values`, `relative_line_numbers`, `rounded_selection`, `scroll_beyond_last_line`, `scroll_sensitivity`, `search`, `search_wrap`, `seed_search_query_from_cursor`, `selection_highlight`, `show_signature_help_after_edits`, `snippet_sort_order`, `use_smartcase_search`, `vertical_scroll_margin` editor etkileşim ve search davranışını taşır. |
| `EditorSettingsContent` | LSP, hover ve diff alanları | `code_lens`, `completion_detail_alignment`, `completion_menu_item_kind`, `completion_menu_scrollbar`, `diagnostics_max_severity`, `diff_view_style`, `excerpt_context_lines`, `expand_excerpt_lines`, `go_to_definition_fallback`, `go_to_definition_scroll_strategy`, `hover_popover_delay`, `hover_popover_enabled`, `hover_popover_hiding_delay`, `hover_popover_sticky`, `inline_code_actions`, `jupyter`, `lsp_document_colors`, `lsp_highlight_debounce`, `minimum_contrast_for_highlights`, `minimum_split_diff_width` LSP, hover, completion, diff ve notebook bağlantılı ayar alanlarıdır. |
| `RelativeLineNumbers`, `CompletionDetailAlignment`, `ToolbarContent` | Satır numarası, completion detay hizası ve editor toolbar tercihleri | Editor schema'sının küçük enum/struct taşıyıcılarıdır. |
| `ScrollbarContent`, `ScrollbarAxesContent`, `ScrollbarDiagnostics` | Editor scrollbar görünümü, eksenleri ve diagnostic işaretleri | Terminal scrollbar content'inden ayrı tutulur. |
| `StickyScrollContent`, `MinimapContent`, `MinimapThumb`, `MinimapThumbBorder` | Sticky scroll ve minimap görünüm ayarları | Minimap thumb ve border davranışı ayrı enum'larla seçilir. |
| `GutterContent`, `CodeLens`, `DocumentColorsRenderMode`, `CurrentLineHighlight` | Gutter, code lens, document color ve aktif satır vurgusu | Dil sunucusu çıktısını editor görünümüne bağlayan schema parçalarıdır. |
| `DoubleClickInMultibuffer`, `MultiCursorModifier`, `ScrollBeyondLastLine`, `CursorShape` | Çoklu buffer tıklama, multicursor modifier, scroll sınırı ve cursor şekli | Editor etkileşim davranışını JSON'dan taşır. |
| `GoToDefinitionFallback`, `GoToDefinitionScrollStrategy` | Definition bulunamadığında fallback ve hedefe scroll stratejisi | Navigation davranışı editor content katmanında kalır. |
| `SnippetSortOrder`, `DiffViewStyle`, `DiffViewStyleIter`, `CompletionMenuItemKind` | Snippet sıralaması, diff görünümü ve completion menü satır tipi | `CompletionMenuItemKind::Symbol` completion menüsünde sembol türü bilgisinin gösterildiği modu seçer. |
| `SearchSettingsContent`, `JupyterContent`, `DragAndDropSelectionContent` | Arama, Jupyter ve drag-selection tercihleri | Editor içindeki feature-specific alt struct'lardır. |
| `ShowMinimap`, `DisplayIn`, `MinimumContrast`, `InactiveOpacity`, `CenteredPaddingSettings` | Minimap gösterimi, gösterim hedefi, kontrast, opacity ve centered layout padding | Tema ile kesişen görsel değerler de editor schema sahibi olarak kalır. |

### Dil ve formatter content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `AllLanguageSettingsContent`, `LanguageSettingsContent`, `LanguageToSettingsMap` | Dile özel settings map'i ve tek dil content'i | `SettingsContent.project.all_languages` altında path/language merge hattına girer. |
| `EditPredictionProvider`, `EditPredictionSettingsContent`, `CustomEditPredictionProviderSettingsContent`, `EditPredictionPromptFormatContent` | Edit prediction provider, özel provider ve prompt format ayarları | Copilot, Codestral ve Ollama içerikleriyle birlikte değerlendirilir. |
| `CopilotSettingsContent`, `CodestralSettingsContent`, `OllamaModelName`, `OllamaEditPredictionSettingsContent` | Built-in edit prediction provider payload'ları | Provider-specific URL/model ayarları schema'da ayrı tiplenir. |
| `EditPredictionDataCollectionChoice`, `EditPredictionsMode` | Edit prediction veri toplama ve çalışma modu | Kullanıcı consent ve mod seçimi enum'larıdır. |
| `AutoIndentMode`, `SoftWrap`, `ShowWhitespaceSetting`, `WhitespaceMapContent`, `RewrapBehavior` | Indent, wrap, whitespace ve rewrap davranışı | EditorConfig ve VS Code import akışında da bu alanlara yazılır. |
| `JsxTagAutoCloseSettingsContent`, `InlayHintSettingsContent`, `InlayHintKind`, `CompletionSettingsContent`, `LspInsertMode`, `WordsCompletionMode` | JSX kapanış, inlay hint, completion ve LSP insert davranışı | Dil server çıktısını editor davranışına çeviren content katmanıdır. |
| `FormatOnSave`, `FormatterList`, `Formatter`, `LanguageServerFormatterSpecifier`, `LineEndingSetting`, `PrettierSettingsContent` | Format-on-save, formatter zinciri ve line ending seçimi | Formatter listesi language server, external code action ve Prettier yollarını aynı schema'da toplar. |
| `IndentGuideSettingsContent`, `IndentGuideColoring`, `IndentGuideBackgroundColoring`, `LanguageTaskSettingsContent`, `ModifiersContent` | Dil bazlı indent guide, task content'i ve modifier tuş seti | Worktree/local ayarlar ile global language ayarları aynı content tiplerini kullanır; modifier content `control`, `alt`, `shift`, `platform` ve `function` alanlarıyla keybinding/gesture tercihlerini schema'ya taşır. |

### Project, LSP ve Git content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `ProjectSettingsContent`, `WorktreeSettingsContent`, `SessionSettingsContent` | Proje, worktree ve session top-level payload'ları | `SettingsContent.project` flatten alanının ana parçalarıdır. |
| `LspSettingsMap`, `LspSettings`, `GlobalLspSettingsContent`, `LspNotificationSettingsContent`, `LspPullDiagnosticsSettingsContent` | LSP server ayarı, bildirim ve pull diagnostic ayarları | LSP schema URL'leri `SettingsStore::json_schema` üretiminde bu tiplerden beslenir. |
| `DapSettingsContent`, `ContextServerSettingsContent`, `ContextServerCommand`, `OAuthClientSettings` | Debug adapter, context server ve OAuth client ayarları | Project content içinde araç/server entegrasyonlarını taşır. |
| `DiagnosticsSettingsContent`, `InlineDiagnosticsSettingsContent`, `DiagnosticSeverityContent` | Diagnostics ve inline diagnostics davranışı | Severity enum'u kullanıcı JSON'unda diagnostic eşiğini temsil eder. |
| `GitSettings`, `GitEnabledSettings`, `GitGutterSetting`, `GitHunkStyleSetting`, `GitPathStyle` | Git entegrasyonu, gutter ve hunk görünümü | Editor/git panel kullanımındaki Git davranış ayarlarının schema sahibidir. |
| `InlineBlameSettings`, `BlameSettings`, `BranchPickerSettingsContent` | Blame ve branch picker davranışı | Git UI feature'ları project content altında tiplenir. |
| `GitHostingProviderConfig`, `GitHostingProviderKind` | Git hosting provider bağlantı tipi | Provider kind enum'u hosting entegrasyonu seçimini saklar. |
| `SemanticTokenRule`, `SemanticTokenColorOverride`, `SemanticTokenFontStyle`, `SemanticTokenFontWeight` | Semantic token style override kuralları | Theme syntax renkleriyle kesişir ama schema sahibi project content'tir. |
| `NodeBinarySettings`, `BinarySettings`, `FetchSettings`, `DirenvSettings` | Node binary, generic binary fetch ve direnv ayarları | Toolchain keşfi ve dış süreç davranışını JSON'dan taşır. |

### Workspace ve panel content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `WorkspaceSettingsContent`, `ItemSettingsContent`, `PreviewTabsSettingsContent`, `TabBarSettingsContent`, `StatusBarSettingsContent` | Workspace, item/tab ve status bar görünümü | `SettingsContent.workspace` flatten alanına ve root panel alanlarına bağlanır. |
| `ActivePaneModifiers`, `CloseWindowWhenNoItems`, `CliDefaultOpenBehavior`, `AutosaveSettingDiscriminants` | Aktif pane modifier'ları, pencere kapanış, CLI açılış ve autosave discriminant'ları | Workspace davranışının enum/newtype schema yüzeyidir. |
| `PaneSplitDirectionHorizontal`, `PaneSplitDirectionVertical`, `CenteredLayoutSettings`, `OnLastWindowClosed` | Pane split yönü, centered layout ve son pencere kapanış davranışı | Pencere/workspace yerleşim ayarlarını taşır. |
| `ProjectPanelSettingsContent`, `ProjectPanelAutoOpenSettings`, `ProjectPanelEntrySpacing`, `ProjectPanelIndentGuidesSettings` | Project panel ana content'i, auto-open, spacing ve indent guide ayarları | File tree görünümünü kullanıcı JSON'una bağlar. |
| `ProjectPanelScrollbarSettingsContent`, `ProjectPanelSortMode`, `ProjectPanelSortOrder` | Project panel scrollbar ve sıralama ayarları | Sort mode/order ayrı enum'larla schema'da görünür. |
| `SemanticTokens`, `DocumentFoldingRanges`, `DocumentSymbols` | Workspace seviyesinde semantic token, folding range ve outline/document symbol kullanımı | Dil server feature toggles workspace ayarı olarak tiplenir. |

### Tema ve görünüm content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `ThemeSettingsContent` | Tema, font ve UI density top-level payload'ı | `theme`, `icon_theme`, `markdown_preview_theme`, `ui_density`, UI/buffer/agent/git commit font boyutu ve ağırlığı, font family/fallback/features, `unnecessary_code_fade`, `experimental_theme_overrides` ve `theme_overrides` alanlarını taşır. |
| `ThemeSettingsContent` | Font alanları | `ui_font_family`, `ui_font_fallbacks`, `ui_font_size`, `ui_font_features`, `ui_font_weight`, `buffer_font_weight`, `buffer_line_height`, `buffer_font_features`, `agent_ui_font_size`, `agent_buffer_font_size`, `git_commit_buffer_font_size`, `markdown_preview_font_family`, `markdown_preview_code_font_family` tema ayar content'inin font odaklı parçalarıdır. |
| `ThemeSelection`, `ThemeSelectionDiscriminants`, `ThemeName`, `DEFAULT_LIGHT_THEME`, `DEFAULT_DARK_THEME` | Tema seçimi ve varsayılan tema adları | Static veya `Dynamic` light/dark payload seçimi yapılır; varsayılan seçim `One Light` / `One Dark` adlarını kullanır. |
| `IconThemeSelection`, `IconThemeSelectionDiscriminants`, `IconThemeName` | Icon theme seçimi | Icon teması da static veya `Dynamic` light/dark payload ile seçilebilir. |
| `ThemeAppearanceMode`, `UiDensity` | Görünüm modu ve yoğunluk | `Light`, `Dark`, `System` tema modunu; `Compact`, `Default`, `Comfortable` spacing oranını belirler. `UiDensity::spacing_ratio()` bu seçimi sayısal boşluk katsayısına çevirir. |
| `FontFeaturesContent`, `FontSize`, `FontStyleContent`, `FontWeightContent`, `BufferLineHeight`, `BufferLineHeightDiscriminants`, `CodeFade` | Font feature, ölçü ve satır yüksekliği değerleri | OpenType feature map'i, iki ondalıklı font/code fade sayıları, `FontStyleContent::Oblique`, `FontWeightContent::{THIN, EXTRA_LIGHT, LIGHT, NORMAL, MEDIUM, SEMIBOLD, BOLD, EXTRA_BOLD, BLACK}` sabitleri ve buffer line-height schema'sını taşır. |
| `ThemeStyleContent`, `AccentContent`, `PlayerColorContent` | Theme override dosyasının üst yapısı | `window_background_appearance`, `accents`, `colors`, `status`, `players` ve syntax highlight alanlarını birleştirir. |
| `ThemeColorsContent`, `StatusColorsContent`, `HighlightStyleContent` | Tema renkleri, status renkleri ve syntax highlight stili | Renk token'larını ve syntax `color`, `background_color`, `font_style`, `font_weight` parçalarını JSON sözleşmesine bağlar. |
| `ThemeColorsContent` | Yüzey ve border alanları | `border_disabled`, `border_focused`, `border_selected`, `border_transparent`, `border_variant`, `debugger_accent`, `drop_target_background`, `drop_target_border`, `element_active`, `element_background`, `element_disabled`, `element_hover`, `element_selected`, `element_selection_background`, `elevated_surface_background`, `surface_background` temel yüzey, border ve etkileşim renklerini taşır. |
| `ThemeColorsContent` | Ghost, text ve icon alanları | `ghost_element_active`, `ghost_element_background`, `ghost_element_disabled`, `ghost_element_hover`, `ghost_element_selected`, `icon`, `icon_accent`, `icon_disabled`, `icon_muted`, `icon_placeholder`, `link_text_hover`, `text_accent`, `text_disabled`, `text_muted`, `text_placeholder` düşük vurgu, text ve icon renklerini taşır. |
| `ThemeColorsContent` | Editor temel alanları | `editor_active_line_background`, `editor_active_line_number`, `editor_active_wrap_guide`, `editor_background`, `editor_debugger_active_line_background`, `editor_foreground`, `editor_gutter_background`, `editor_highlighted_line_background`, `editor_hover_line_number`, `editor_indent_guide`, `editor_indent_guide_active`, `editor_invisible`, `editor_line_number`, `editor_subheader_background`, `editor_wrap_guide` editor yüzeyi ve gutter renklerini taşır. |
| `ThemeColorsContent` | Editor highlight/diff alanları | `editor_document_highlight_bracket_background`, `editor_document_highlight_read_background`, `editor_document_highlight_write_background`, `editor_diff_hunk_added_background`, `editor_diff_hunk_added_hollow_background`, `editor_diff_hunk_added_hollow_border`, `editor_diff_hunk_deleted_background`, `editor_diff_hunk_deleted_hollow_background`, `editor_diff_hunk_deleted_hollow_border` document highlight ve diff hunk renklerini taşır. |
| `ThemeColorsContent` | Panel, pane ve tab alanları | `pane_focused_border`, `pane_group_border`, `panel_background`, `panel_focused_border`, `panel_indent_guide`, `panel_indent_guide_active`, `panel_indent_guide_hover`, `panel_overlay_background`, `panel_overlay_hover`, `status_bar_background`, `tab_active_background`, `tab_bar_background`, `tab_inactive_background`, `title_bar_background`, `title_bar_inactive_background`, `toolbar_background` panel/pane/tab/titlebar renklerini taşır. |
| `ThemeColorsContent` | Scrollbar, minimap ve search alanları | `deprecated_scrollbar_thumb_background`, `scrollbar_thumb_active_background`, `scrollbar_thumb_background`, `scrollbar_thumb_border`, `scrollbar_thumb_hover_background`, `scrollbar_track_background`, `scrollbar_track_border`, `minimap_thumb_active_background`, `minimap_thumb_background`, `minimap_thumb_border`, `minimap_thumb_hover_background`, `search_active_match_background`, `search_match_background` scroll, minimap ve search match renklerini taşır. |
| `ThemeColorsContent` | Terminal temel ve ANSI alanları 1 | `terminal_background`, `terminal_foreground`, `terminal_bright_foreground`, `terminal_dim_foreground`, `terminal_ansi_background`, `terminal_ansi_black`, `terminal_ansi_blue`, `terminal_ansi_cyan`, `terminal_ansi_green`, `terminal_ansi_magenta`, `terminal_ansi_red`, `terminal_ansi_white`, `terminal_ansi_yellow` terminal ana renklerini taşır. |
| `ThemeColorsContent` | Terminal ANSI alanları 2 | `terminal_ansi_bright_black`, `terminal_ansi_bright_blue`, `terminal_ansi_bright_cyan`, `terminal_ansi_bright_green`, `terminal_ansi_bright_magenta`, `terminal_ansi_bright_red`, `terminal_ansi_bright_white`, `terminal_ansi_bright_yellow`, `terminal_ansi_dim_black`, `terminal_ansi_dim_blue`, `terminal_ansi_dim_cyan`, `terminal_ansi_dim_green`, `terminal_ansi_dim_magenta`, `terminal_ansi_dim_red`, `terminal_ansi_dim_white`, `terminal_ansi_dim_yellow` bright/dim ANSI renklerini taşır. |
| `ThemeColorsContent` | Version control alanları | `version_control_added`, `version_control_conflict`, `version_control_conflict_marker_ours`, `version_control_conflict_marker_theirs`, `version_control_conflict_ours_background`, `version_control_conflict_theirs_background`, `version_control_deleted`, `version_control_ignored`, `version_control_modified`, `version_control_renamed`, `version_control_word_added`, `version_control_word_deleted` Git ve diff inline renklerini taşır. |
| `ThemeColorsContent` | Vim/Helix modal alanları | `vim_helix_jump_label_foreground`, `vim_helix_normal_background`, `vim_helix_normal_foreground`, `vim_helix_select_background`, `vim_helix_select_foreground`, `vim_insert_background`, `vim_insert_foreground`, `vim_normal_background`, `vim_normal_foreground`, `vim_replace_background`, `vim_replace_foreground`, `vim_visual_background`, `vim_visual_block_background`, `vim_visual_block_foreground`, `vim_visual_foreground`, `vim_visual_line_background`, `vim_visual_line_foreground`, `vim_yank_background` modal editing renklerini taşır. |
| `StatusColorsContent` | Semantic status renkleri | `info`, `info_border`, `info_background`, `warning`, `warning_border`, `warning_background`, `error_border`, `error_background`, `success`, `success_border`, `success_background`, `hint_border`, `hint_background`, `predictive`, `predictive_border`, `predictive_background`, `unreachable`, `unreachable_border`, `unreachable_background` status ve diagnostic tonlarını taşır. |
| `StatusColorsContent` | Git/file status renkleri | `created`, `created_border`, `created_background`, `modified`, `modified_border`, `modified_background`, `deleted`, `deleted_border`, `deleted_background`, `renamed`, `renamed_border`, `renamed_background`, `conflict`, `conflict_border`, `conflict_background`, `ignored_border`, `ignored_background`, `hidden_border`, `hidden_background` dosya durumu renklerini taşır. |
| `WindowBackgroundContent` | Pencere arka plan görünümü | `Opaque`, `Transparent`, `Blurred` değerleriyle tema kaynaklı pencere background seçimini taşır. |

### Terminal content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `ProjectTerminalSettingsContent`, `TerminalSettingsContent` | Proje terminali ve global terminal ayarları | Project-local terminal content ile top-level terminal content ayrıdır. |
| `WorkingDirectory`, `WorkingDirectoryDiscriminants`, `ShellDiscriminants` | Terminal çalışma dizini ve shell discriminant'ları | `strum`/schema tarafında variant listesini görünür kılar. |
| `ScrollbarSettingsContent`, `TerminalLineHeight`, `TerminalToolbarContent` | Terminal scrollbar, line height ve toolbar görünümü | Editor scrollbar content'inden ayrı bir terminal schema yüzeyidir. |
| `CursorShapeContent`, `TerminalBlink`, `AlternateScroll`, `TerminalBell` | Terminal cursor, blink, alternate scroll ve bell davranışı | PTY/terminal etkileşim tercihlerini JSON'dan taşır. |
| `CondaManager`, `VenvSettings`, `VenvSettingsContent`, `PathHyperlinkRegex` | Conda/venv aktivasyonu ve path hyperlink regexp seçimi | Ortam aktivasyon script'i ile hyperlink yakalama terminal content'te birleşir. |
| `TerminalDockPosition`, `ActivateScript` | Terminal dock ve environment activation script davranışı | Project terminal ayarları global terminal ayarını tamamlar. |

### Agent content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `AgentSettingsContent`, `AgentProfileContent`, `ContextServerPresetContent` | Agent panel, profil ve context server preset ayarları | Agent top-level alanı model, panel ve izinleri aynı content altında toplar. |
| `AllAgentServersSettings`, `CustomAgentServerSettings` | Agent server ayar koleksiyonu ve custom server seçimi | External agent server davranışını settings JSON'una bağlar. |
| `LanguageModelSelection`, `LanguageModelParameters`, `LanguageModelProviderSetting` | Agent model seçimi ve provider-specific parametre override'ları | `language_models` provider ayarlarından ayrı, agent kullanım seçimini taşır. |
| `SidebarDockPosition`, `ThinkingBlockDisplay`, `NotifyWhenAgentWaiting`, `PlaySoundWhenAgentDone` | Agent panel layout, düşünme bloğu, bildirim ve ses davranışı | Kullanıcı etkileşimiyle ilgili enum payload'larıdır. |
| `ToolPermissionsContent`, `ToolRulesContent`, `ToolRegexRule`, `ToolPermissionMode` | Tool izinleri, regex kuralları ve izin modu | Tool çağrısı policy'si content schema seviyesinde tiplenir. |
| `SandboxPermissionsContent` | Agent terminal sandbox izinleri | Kaynaktaki `"Allow always"` seçimiyle kalıcı hale gelen ağ, yazma yolu ve sandbox dışı çalışma izinlerini taşır. |

### Language model provider content ailesi

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `language_model`, `AllLanguageModelSettingsContent` | Kök re-export ve tüm provider ayar koleksiyonu | `SettingsContent.language_models` alanının top-level schema'sıdır. |
| `AnthropicSettingsContent`, `AnthropicAvailableModel`, `LanguageModelCacheConfiguration` | Anthropic API URL, model listesi ve cache yapılandırması | Model entry'leri display name, token limitleri ve tool override taşıyabilir. |
| `AmazonBedrockSettingsContent`, `BedrockAvailableModel`, `BedrockAuthMethodContent` | Bedrock region, endpoint, auth ve model listesi | Auth enum'u named profile, SSO, API key ve automatic yollarını ayırır. |
| `OllamaSettingsContent`, `OllamaAvailableModel`, `KeepAlive` | Ollama API, auto-discover ve keep-alive davranışı | `KeepAlive` saniye veya duration string olarak deserialize edilir. |
| `OpenCodeSettingsContent`, `OpenCodeAvailableModel`, `OpenCodeModelSubscription` | OpenCode API ve subscription bazlı model listesi | Zen/Go/Free subscription enum'u provider content'inin parçasıdır. |
| `LmStudioSettingsContent`, `LmStudioAvailableModel`, `DeepseekSettingsContent`, `DeepseekAvailableModel` | LM Studio ve DeepSeek provider payload'ları | Her provider kendi available model struct'ını kullanır. |
| `MistralSettingsContent`, `MistralAvailableModel`, `OpenAiSettingsContent`, `OpenAiAvailableModel`, `OpenAiModelCapabilities` | Mistral ve OpenAI provider ayarları | Token, completion, reasoning ve tool/image capability alanları provider schema'sında kalır. |
| `OpenAiCompatibleSettingsContent`, `OpenAiCompatibleAvailableModel`, `OpenAiCompatibleModelCapabilities` | OpenAI-compatible named provider map'i | `HashMap<Arc<str>, ...>` ile birden çok custom provider tanımlanabilir. |
| `VercelAiGatewaySettingsContent`, `VercelAiGatewayAvailableModel`, `GoogleSettingsContent`, `GoogleAvailableModel` | Vercel AI Gateway ve Google provider ayarları | Gateway/provider ayarları `language_models` altında ayrı key'lerle tutulur. |
| `XAiSettingsContent`, `XaiAvailableModel`, `ZedDotDevSettingsContent`, `ZedDotDevAvailableModel`, `ZedDotDevAvailableProvider` | xAI ve `zed.dev` provider ayarları | `zed.dev` JSON key'i serde rename ile korunur. |
| `OpenRouterSettingsContent`, `OpenRouterAvailableModel`, `OpenRouterProvider`, `DataCollection` | OpenRouter provider, model metadata ve veri toplama tercihi | OpenRouter provider bilgisi model entry'sinden ayrı tiplenir. |

Provider settings struct'larının çoğunda `custom_headers: Option<HashMap<String, String>>` alanı bulunur. Bunu provider HTTP isteklerine ek başlık geçirmek için kullanırsın; API URL veya model listesinden ayrı tutulur, çünkü ağ katmanına ait bir override'dır.

### Kalan content taşıyıcıları ve modül re-export'ları

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `ActionName` | Action adını JSON string olarak taşır | Runtime action registry ile schema autocomplete bağlanırken kullanılır. |
| `ExtendingVec`, `SaturatingBool`, `MergeFrom`, `MergeFromTrait` | Özel merge semantiği olan collection, bool newtype ve re-export trait adı | `ExtendingVec` biriktirir, `SaturatingBool` bir kez `true` olduğunda geri düşmez; `MergeFrom::merge_from_option` opsiyonel katmanı varsa birleştirir, `MergeFromTrait` settings macro çıktısının public trait re-export'udur. |
| `RootUserSettings`, `SettingsProfile` | Root settings parse trait'i ve profil override payload'ı | `RootUserSettings` yorumlu/yorumsuz JSON parse girişlerini sağlar; `SettingsProfile` kullanıcı profilinin base ve settings override içeriğini taşır. |
| `SeedQuerySetting`, `ActivateOnClose`, `ClosePosition`, `ShowCloseButton`, `ShowDiagnostics` | Editor/workspace davranışındaki küçük enum ve content seçimleri | Tek başına uzun konu istemeyen schema seçenekleridir. |
| `AutosaveSetting`, `RestoreOnStartupBehavior`, `EncodingDisplayOptions`, `TextRenderingMode`, `WindowDecorations`, `BottomDockLayout`, `FocusFollowsMouse` | Workspace başlatma, kaydetme, encoding, text render ve pencere dekorasyon ayarları | `WorkspaceSettingsContent` ailesinin alt enum/struct yüzeyidir. |
| `Shell`, `ShowScrollbar` | Terminal shell ve scrollbar gösterim ayarları | `TerminalSettingsContent` altında terminal davranışını seçer. |
| `SidebarSide` | Agent sidebar tarafının internal/content eşleşmesi | `SidebarDockPosition` public settings enum'unu tamamlayan küçük taşıyıcıdır. |
| `TitleBarSettingsContent`, `WindowButtonLayoutContent`, `title_bar` | Title bar ayar payload'ı, pencere düğmesi layout content'i ve re-export modülü | Üst bar dokümanı derin anlatır; settings content tarafında JSON schema sahibi olarak görünür. |
| `serialize_f32_with_two_decimal_places`, `settings_content::serde_helper::serialize_f32_with_two_decimal_places` | `f32` değerlerini iki ondalıkla yazan serializer | `FontSize`, `CodeFade` ve benzer transparent numeric content tiplerinin settings JSON çıktısını sabit biçimde tutar. |

---

## Dikkat Noktaları

- Store'un `Global` olması demek, her testte ayrı bir store gerektiği anlamına gelir; `SettingsStore::test(cx)` veya `SettingsStore::new(cx, ...)` ile yenisi kurulmadan testler birbirinin durumunu kirletebilir.
- `merged_settings` `Rc` paylaşımındadır; aynı `App`'te uzun süre tutulan referanslar yeni hesap sonrası eskimiş içerikten okumaya neden olabilir. Sorgu sırasında `get` çağrısı her zaman güncel `Rc`'yi çözmelidir.
- `set_local_settings` `kind` parametresi yanlış verilirse Tasks veya EditorConfig içeriği ayar gibi yedirilebilir; akış doğrudan worktree dosyalarını izleyen kod tarafından çağrılmalıdır.
- `SettingsStore::update_user_settings` `test-support` altındadır; üretim kodunda elle çağrılırsa derleme `cfg(test)` dışı build'lerde hata verir.

## İlgili ek ayar tipleri ve davranışları

### `SandboxPermissionsContent`

`SandboxPermissionsContent`, agent tarafından çalıştırılan terminal komutlarının sandbox yükseltme isteklerinde kalıcı izinleri ayar JSON'una taşır. Yapı `AgentSettingsContent.sandbox_permissions: Option<SandboxPermissionsContent>` alanının içeriğidir; değer yoksa terminal sandbox izinleri prompt sonucuna göre anlık değerlendirilir.

| Grup | API | Not |
|---|---|---|
| Alanlar | `allow_network`, `allow_fs_write_all`, `allow_unsandboxed`, `write_paths` | Ağ erişimi, tüm dosya sistemine yazma, sandbox dışında çalışma ve belirli mutlak path alt ağaçlarına yazma izinlerini taşır. |

`allow_sandbox_network()`, `allow_sandbox_fs_write_all()` ve `allow_sandbox_unsandboxed()` ilgili boolean izni `Some(true)` yapar. `add_sandbox_write_path(path)` `write_paths: Option<ExtendingVec<PathBuf>>` içine path ekler; zaten daha genel bir izin varsa ekleme yapmaz, yeni path daha genelse eski alt path izinlerini temizler. Böylece ayar dosyasında `/tmp/proje` varken ayrıca `/tmp/proje/cache` gibi gereksiz tekrarlar birikmez.

### `WorktreeSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `file_scan_exclusions`, `file_scan_inclusions`, `hidden_files`, `prevent_sharing_in_public_channels`, `private_files`, `read_only_files`, `scan_symlinks` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

`scan_symlinks` alanı `Option<ScanSymlinksSetting>` taşır ve bağlı (symlinked) dizinlerin içeriğinin ne zaman taranacağını belirler. JSON'da `snake_case` değer bekler; varsayılan `expanded`'dır.

### `ScanSymlinksSetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Expanded` | Bağlı dizin içeriğinin tarama zamanını seçen public enum; serileştirmede `snake_case` (`always`, `expanded`) kullanılır. |

- `Always`: symlinked dizinler her zaman taranır.
- `Expanded` (varsayılan): symlinked dizinler yalnız çalışma alanında genişletildiklerinde taranır.
