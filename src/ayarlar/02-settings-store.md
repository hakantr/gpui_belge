# SettingsStore

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `SettingsStore` | Metotlar 1 | `clear_local_settings`, `configured_settings_profiles`, `edits_for_update`, `error_for_file`, `get`, `get_all_files`, `get_all_locals`, `get_content_for_file`, `get_overrides_for_field`, `get_value_from_file`, `get_value_up_to_file`, `get_vscode_edits`, `import_vscode_settings`, `language_semantic_token_rules` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `SettingsStore` | Metotlar 2 | `local_settings`, `merged_settings`, `new`, `new_text_for_update`, `observe_active_settings_profile_name`, `override_global`, `project_json_schema`, `raw_default_settings`, `raw_user_settings`, `register_setting`, `remove_language_semantic_token_rules`, `set_default_settings`, `set_extension_settings`, `set_global_settings` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `SettingsStore` | Metotlar 3 | `set_language_semantic_token_rules`, `set_local_settings`, `set_server_settings`, `set_user_settings`, `try_get`, `update`, `update_default_settings`, `update_settings_file_with_completion`, `watch_settings_files` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `SettingsStore` | Alanlar | `editorconfig_store` | Public veri alanları; runtime, stil veya ayar sözleşmesinin taşınan parçalarıdır. |


`crates/settings/src/settings_store.rs`. `SettingsStore` Zed'in tüm ayar kaynaklarını tek bir tip-güvenli store içinde birleştirir. Default, user, global, server, extension ve local katmanları öncelik sırasıyla birleşir. Birleşik içerik daha sonra kayıtlı `Settings` tiplerine yedirilir.

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

`SettingsStore::watch_settings_files(fs, cx, callback)` kullanıcı ve global ayar dosyalarını `watch_config_file` ile bağlar; her değişimde ilgili `SettingsFile`, `SettingsParseResult` ve `App` callback'e verirsin.

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

`Ord` uygulaması `Project` > `Server` > `User` > `Global` > `Default` sırasıyla çözer. `merged_settings` bu sıraya göre `merge_from` ile inşa edilir. Aynı kullanıcının birden çok worktree dosyası varsa daha derin path daha yüksek önceliği alır.

`SettingsLocation { worktree_id, path }` sorgulayan tarafa "bana bu yol için geçerli değeri ver" der; store öncelik zincirinde local katmanları yer almıyorsa global değere düşer.

`LocalSettingsKind::{Settings, Tasks, Editorconfig, Debug}` proje yerel dosyalarının tipini belirtir. `LocalSettingsPath::{InWorktree(Arc<RelPath>), OutsideWorktree(Arc<Path>)}` worktree içi ve dışı yolları ayırır; `OutsideWorktree` ev dizinine yerleştirilmiş bir parent `.editorconfig` gibi kaynakları temsil eder.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `SettingsFile` | `Default`, `Global`, `User`, `Server`, `Project((WorktreeId, Arc<RelPath>))` | Store'a yedirilen ayar kaynağını ve merge önceliğini taşır. |
| `SettingsLocation` | `worktree_id`, `path` | Worktree/path özel ayar okumasında hedef konumu belirtir. |
| `LocalSettingsKind` | `Settings`, `Tasks`, `Editorconfig`, `Debug` | Worktree yerel dosyasının hangi içerik modeline göre parse edileceğini seçer. |
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
- `SettingsStore::get_all_files()` — store'a yedirilmiş tüm `SettingsFile` kaynaklarını döndürür; UI ayarlar görünümü hangi dosyaların aktif olduğunu bu liste üzerinden gösterir.
- `SettingsStore::get_content_for_file(file)` — belirli bir kaynağın ham `SettingsContent` referansını verir.
- `SettingsStore::get_overrides_for_field(...)`, `get_value_from_file(...)`, `get_value_up_to_file(...)` — belirli bir alanın hangi kaynakta hangi değeri taşıdığını açıklayan analitik yardımcılar; ayarlar UI'ında "bu değer hangi dosyadan geliyor?" sorusunu yanıtlamak için kullanırsın.

---

## Yazma

- `SettingsStore::override_global<T>(value)` programatik üzerine yazmadır; dosyaya yazmaz.
- `SettingsStore::update_settings_file(fs, update)` user `settings.json` dosyasına closure üzerinden değişiklik uygular ve sonucu yazar. Üst seviye `settings::update_settings_file(fs, cx, update)` aynı çağrıyı sarmalar.
- `SettingsStore::update_settings_file_with_completion(fs, update) -> oneshot::Receiver<Result<()>>` aynı işi yapar ama yazma tamamlanınca tetiklenen bir kanal döndürür; UI tarafında "kaydedildi" geribildirimi gerektiğinde kullanırsın.
- `SettingsStore::update_user_settings(...)` yalnız test bağlamlarında mevcuttur; uygulama kodunda kalıcı yazma için `update_settings_file` yolu tercih edersin.
- `SettingsStore::import_vscode_settings(fs, vscode_settings, cx)` `VsCodeSettings` içeriğini kullanıcı ayar dosyasına aktarır; aşağıdaki "VS Code içe aktarımı" bölümünde detaylandırılır.

JSON metin güncelleme helper'ları:

| API | Rol |
| :-- | :-- |
| `replace_value_in_json_text` | JSON metni içinde hedef path'teki değeri pretty biçim korunarak değiştirir; settings UI yazma akışının düşük seviye helper'ıdır. |
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

`SettingsParseResult` her dosya için ayrıştırma sonucunu taşır; başarılı durumda `parse_status = ParseStatus::Success` ve `migration_status = MigrationStatus::NotNeeded` varsayılanı kullanırsın. Hata varsa parse veya migrasyon mesajı burada saklarsın. `SettingsStore::error_for_file(file)` belirli bir dosyanın hata durumunu okur. `MigrationStatus` migrasyon adımının başarılı olup olmadığını bildirir; uygulama kodunda birleşik sonuç `SettingsParseResult::result() -> Result<bool>` ile ele alman gerekir. Dönen `bool`, dosyanın otomatik migrasyon gerektirip gerektirmediğini bildirir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `SettingsParseResult` | `parse_status`, `migration_status`, `unwrap`, `expect`, `result`, `requires_user_action`, `ok`, `parse_error` | Parse ve migrasyon sonucunu UI veya log akışına çevirmek için kullanılır. |
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
| `RelativeLineNumbers`, `CompletionDetailAlignment`, `ToolbarContent` | Satır numarası, completion detay hizası ve editor toolbar tercihleri | Editor schema'sının küçük enum/struct taşıyıcılarıdır. |
| `ScrollbarContent`, `ScrollbarAxesContent`, `ScrollbarDiagnostics` | Editor scrollbar görünümü, eksenleri ve diagnostic işaretleri | Terminal scrollbar content'inden ayrı tutulur. |
| `StickyScrollContent`, `MinimapContent`, `MinimapThumb`, `MinimapThumbBorder` | Sticky scroll ve minimap görünüm ayarları | Minimap thumb ve border davranışı ayrı enum'larla seçilir. |
| `GutterContent`, `CodeLens`, `DocumentColorsRenderMode`, `CurrentLineHighlight` | Gutter, code lens, document color ve aktif satır vurgusu | Dil sunucusu çıktısını editor görünümüne bağlayan schema parçalarıdır. |
| `DoubleClickInMultibuffer`, `MultiCursorModifier`, `ScrollBeyondLastLine`, `CursorShape` | Çoklu buffer tıklama, multicursor modifier, scroll sınırı ve cursor şekli | Editor etkileşim davranışını JSON'dan taşır. |
| `GoToDefinitionFallback`, `GoToDefinitionScrollStrategy` | Definition bulunamadığında fallback ve hedefe scroll stratejisi | Navigation davranışı editor content katmanında kalır. |
| `SnippetSortOrder`, `DiffViewStyle`, `DiffViewStyleIter` | Snippet sıralaması ve diff görünümü | `DiffViewStyleIter` variant dolaşımı için üretilen yardımcıdır. |
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
| `IndentGuideSettingsContent`, `IndentGuideColoring`, `IndentGuideBackgroundColoring`, `LanguageTaskSettingsContent` | Dil bazlı indent guide ve task content'i | Worktree/local ayarlar ile global language ayarları aynı content tiplerini kullanır. |

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

### Kalan content taşıyıcıları ve modül re-export'ları

| API | Kapsadığı davranış | Not |
| :-- | :-- | :-- |
| `ActionName` | Action adını JSON string olarak taşır | Runtime action registry ile schema autocomplete bağlanırken kullanılır. |
| `ExtendingVec`, `SaturatingBool` | Özel merge semantiği olan collection ve bool newtype'ları | `ExtendingVec` biriktirir, `SaturatingBool` bir kez `true` olduğunda geri düşmez. |
| `SeedQuerySetting`, `ActivateOnClose`, `ClosePosition`, `ShowCloseButton`, `ShowDiagnostics` | Editor/workspace davranışındaki küçük enum ve content seçimleri | Tek başına uzun konu istemeyen schema seçenekleridir. |
| `AutosaveSetting`, `RestoreOnStartupBehavior`, `EncodingDisplayOptions`, `TextRenderingMode`, `WindowDecorations`, `BottomDockLayout`, `FocusFollowsMouse` | Workspace başlatma, kaydetme, encoding, text render ve pencere dekorasyon ayarları | `WorkspaceSettingsContent` ailesinin alt enum/struct yüzeyidir. |
| `Shell`, `ShowScrollbar` | Terminal shell ve scrollbar gösterim ayarları | `TerminalSettingsContent` altında terminal davranışını seçer. |
| `SidebarSide` | Agent sidebar tarafının internal/content eşleşmesi | `SidebarDockPosition` public settings enum'unu tamamlayan küçük taşıyıcıdır. |
| `TitleBarSettingsContent`, `WindowButtonLayoutContent`, `title_bar` | Title bar ayar payload'ı, pencere düğmesi layout content'i ve re-export modülü | Üst bar dokümanı derin anlatır; settings content tarafında JSON schema sahibi olarak görünür. |

---

## Tuzaklar

- Store'un `Global` olması demek, her testte ayrı bir store gerektiği anlamına gelir; `SettingsStore::test(cx)` veya `SettingsStore::new(cx, ...)` ile yenisi kurulmadan testler birbirinin durumunu kirletebilir.
- `merged_settings` `Rc` paylaşımındadır; aynı `App`'te uzun süre tutulan referanslar yeni hesap sonrası eskimiş içerikten okumaya neden olabilir. Sorgu sırasında `get` çağrısı her zaman güncel `Rc`'yi çözmelidir.
- `set_local_settings` `kind` parametresi yanlış verilirse Tasks veya EditorConfig içeriği ayar gibi yedirilebilir; akış doğrudan worktree dosyalarını izleyen kod tarafından çağrılmalıdır.
- `SettingsStore::update_user_settings` `test-support` altındadır; üretim kodunda elle çağrılırsa derleme `cfg(test)` dışı build'lerde hata verir.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `Editorconfig`

| Grup | API | Not |
|---|---|---|
| Alanlar | `is_root`, `sections` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `WorktreeId`

| Grup | API | Not |
|---|---|---|
| Metotlar | `from_proto`, `from_usize`, `to_proto`, `to_usize` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `LocalSettingsKind`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Debug`, `Editorconfig`, `Settings`, `Tasks` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `LocalSettingsPath`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `InWorktree`, `OutsideWorktree` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `from_proto`, `is_outside_worktree`, `to_proto` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `SettingsJsonSchemaParams`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `action_documentation`, `action_names`, `deprecation_messages`, `deprecations`, `font_names`, `icon_theme_names`, `language_names`, `lsp_adapter_names` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `theme_names` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `MigrationStatus`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Failed`, `NotNeeded`, `Succeeded` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ActionName`

| Grup | API | Not |
|---|---|---|
| Metotlar | `build_schema`, `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `SidebarDockPosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SidebarSide`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ThinkingBlockDisplay`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `AlwaysCollapsed`, `AlwaysExpanded`, `Auto`, `Preview` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `AgentSettingsContent`

| Grup | API | Not |
|---|---|---|
| Metotlar 1 | `add_favorite_model`, `add_tool_allow_pattern`, `add_tool_deny_pattern`, `remove_favorite_model`, `set_dock`, `set_flexible_size`, `set_inline_assistant_model`, `set_model` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Metotlar 2 | `set_profile`, `set_sidebar_side`, `set_tool_default_permission`, `update_favorite_model` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar 1 | `button`, `cancel_generation_on_terminal_stop`, `commit_message_instructions`, `commit_message_model`, `default_height`, `default_model`, `default_profile`, `default_width` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `dock`, `enable_feedback`, `enabled`, `expand_edit_card`, `expand_terminal_card`, `favorite_models`, `flexible`, `inline_alternatives` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 3 | `inline_assistant_model`, `inline_assistant_use_streaming_tools`, `limit_content_width`, `max_content_width`, `message_editor_min_lines`, `model_parameters`, `notify_when_agent_waiting`, `play_sound_when_agent_done` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 4 | `profiles`, `show_merge_conflict_indicator`, `show_turn_stats`, `sidebar_side`, `single_file_review`, `subagent_model`, `thinking_display`, `thread_summary_model` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 5 | `tool_permissions`, `use_modifier_to_send` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `AgentProfileContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `context_servers`, `default_model`, `enable_all_context_servers`, `name`, `tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ContextServerPresetContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `NotifyWhenAgentWaiting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `AllScreens`, `Never`, `PrimaryScreen` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `PlaySoundWhenAgentDone`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Never`, `WhenHidden` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `should_play` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `LanguageModelSelection`

| Grup | API | Not |
|---|---|---|
| Alanlar | `effort`, `enable_thinking`, `model`, `provider`, `speed` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LanguageModelParameters`

| Grup | API | Not |
|---|---|---|
| Alanlar | `model`, `provider`, `temperature` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LanguageModelProviderSetting`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `AllAgentServersSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CustomAgentServerSettings`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Custom`, `Registry` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ToolPermissionsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `default`, `tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ToolRulesContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `always_allow`, `always_confirm`, `always_deny`, `default` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ToolRegexRule`

| Grup | API | Not |
|---|---|---|
| Alanlar | `case_sensitive`, `pattern` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ToolPermissionMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Allow`, `Confirm`, `Deny` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `RelativeLineNumbers`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Disabled`, `Enabled`, `Wrapped` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `enabled`, `wrapped` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `CompletionDetailAlignment`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ToolbarContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `agent_review`, `breadcrumbs`, `code_actions`, `quick_actions`, `selections_menu` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ScrollbarContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `axes`, `cursors`, `diagnostics`, `git_diff`, `search_results`, `selected_symbol`, `selected_text`, `show` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `StickyScrollContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `MinimapContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `current_line_highlight`, `display_in`, `max_width_columns`, `show`, `thumb`, `thumb_border` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ScrollbarAxesContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `horizontal`, `vertical` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GutterContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `bookmarks`, `breakpoints`, `folds`, `line_numbers`, `min_line_number_digits`, `runnables` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CodeLens`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Menu`, `Off`, `On` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `enabled`, `inline`, `show_in_menu` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `DocumentColorsRenderMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Background`, `Border`, `Inlay`, `None` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CurrentLineHighlight`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `All`, `Gutter`, `Line`, `None` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SeedQuerySetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Never`, `Selection` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `DoubleClickInMultibuffer`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Open`, `Select` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `MinimapThumb`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Hover` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `MinimapThumbBorder`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Full`, `LeftOnly`, `LeftOpen`, `None`, `RightOpen` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ScrollbarDiagnostics`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `All`, `Error`, `Information`, `None`, `Warning` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `MultiCursorModifier`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Alt`, `CmdOrCtrl` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ScrollBeyondLastLine`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `OnePage`, `VerticalScrollMargin` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `GoToDefinitionFallback`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `FindAllReferences`, `None` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `GoToDefinitionScrollStrategy`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Center`, `Minimum`, `Preserve`, `Top` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SnippetSortOrder`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bottom`, `Inline`, `None`, `Top` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `DiffViewStyle`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Split`, `Unified` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SearchSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `button`, `case_sensitive`, `center_on_match`, `include_ignored`, `regex`, `whole_word` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `JupyterContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enabled`, `kernel_selections` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DragAndDropSelectionContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `delay`, `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ShowMinimap`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Auto`, `Never` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `DisplayIn`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `ActiveEditor`, `AllEditors` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `MinimumContrast`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `InactiveOpacity`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CenteredPaddingSettings`

| Grup | API | Not |
|---|---|---|
| Assoc const | `DEFAULT_PADDING`, `MAX_PADDING`, `MIN_PADDING` | Inherent impl üzerinde public sabit yüzeyidir; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `AllLanguageSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `defaults`, `edit_predictions`, `file_types`, `languages` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `EditPredictionProvider`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Codestral`, `Copilot`, `Mercury`, `None`, `Ollama`, `OpenAiCompatibleApi`, `Zed` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `display_name`, `is_zed` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `EditPredictionSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `allow_data_collection`, `codestral`, `copilot`, `disabled_globs`, `mode`, `ollama`, `open_ai_compatible_api`, `provider` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CustomEditPredictionProviderSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `max_output_tokens`, `model`, `prompt_format` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `EditPredictionPromptFormatContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar 1 | `CodeGemma`, `CodeLlama`, `Codestral`, `DeepseekCoder`, `Glm`, `Infer`, `Qwen`, `StarCoder` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Varyantlar 2 | `Zeta`, `Zeta2`, `Zeta2_1` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CopilotSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enable_next_edit_suggestions`, `enterprise_uri`, `proxy`, `proxy_no_verify` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `CodestralSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `max_tokens`, `model` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OllamaModelName`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OllamaEditPredictionSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `max_output_tokens`, `model`, `prompt_format` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `EditPredictionDataCollectionChoice`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Default`, `No`, `Yes` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `EditPredictionsMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Eager`, `Subtle` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `AutoIndentMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `None`, `PreserveIndent`, `SyntaxAware` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SoftWrap`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bounded`, `EditorWidth`, `None`, `PreferLine` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `LanguageSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `allow_rewrap`, `always_treat_brackets_as_autoclosed`, `auto_indent`, `auto_indent_on_paste`, `code_actions_on_format`, `colorize_brackets`, `completions`, `debuggers` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `document_folding_ranges`, `document_symbols`, `edit_predictions_disabled_in`, `enable_language_server`, `ensure_final_newline_on_save`, `extend_comment_on_newline`, `extend_list_on_newline`, `format_on_save` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 3 | `formatter`, `hard_tabs`, `indent_guides`, `indent_list_on_tab`, `inlay_hints`, `jsx_tag_auto_close`, `language_servers`, `line_ending` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 4 | `linked_edits`, `preferred_line_length`, `prettier`, `remove_trailing_whitespace_on_save`, `semantic_tokens`, `show_completion_documentation`, `show_completions_on_input`, `show_edit_predictions` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 5 | `show_whitespaces`, `show_wrap_guides`, `soft_wrap`, `tab_size`, `tasks`, `use_auto_surround`, `use_autoclose`, `use_on_type_format` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 6 | `whitespace_map`, `word_diff_enabled`, `wrap_guides` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ShowWhitespaceSetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `All`, `Boundary`, `None`, `Selection`, `Trailing` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `WhitespaceMapContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `space`, `tab` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `RewrapBehavior`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Anywhere`, `InComments`, `InSelections` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `JsxTagAutoCloseSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `InlayHintSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `edit_debounce_ms`, `enabled`, `scroll_debounce_ms`, `show_background`, `show_other_hints`, `show_parameter_hints`, `show_type_hints`, `show_value_hints` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `toggle_on_modifiers_press` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `InlayHintKind`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Parameter`, `Type` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `from_name`, `name` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `CompletionSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `lsp`, `lsp_fetch_timeout_ms`, `lsp_insert_mode`, `words`, `words_min_length` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LspInsertMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Insert`, `Replace`, `ReplaceSubsequence`, `ReplaceSuffix` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `WordsCompletionMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Disabled`, `Enabled`, `Fallback` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `PrettierSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `allowed`, `options`, `parser`, `plugins` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `FormatOnSave`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `On` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `LineEndingSetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Detect`, `EnforceCrlf`, `EnforceLf`, `PreferCrlf`, `PreferLf` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `FormatterList`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Single`, `Vec` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `Formatter`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Auto`, `CodeAction`, `External`, `LanguageServer`, `None`, `Prettier` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `LanguageServerFormatterSpecifier`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Current`, `Specific` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `IndentGuideSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `active_line_width`, `background_coloring`, `coloring`, `enabled`, `line_width` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LanguageTaskSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enabled`, `prefer_lsp`, `variables` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LanguageToSettingsMap`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `IndentGuideColoring`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Disabled`, `Fixed`, `IndentAware` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `IndentGuideBackgroundColoring`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Disabled`, `IndentAware` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `AllLanguageModelSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `anthropic`, `bedrock`, `deepseek`, `google`, `lmstudio`, `mistral`, `ollama`, `open_router` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `openai`, `openai_compatible`, `opencode`, `vercel_ai_gateway`, `x_ai`, `zed_dot_dev` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `AnthropicSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `AnthropicAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `cache_configuration`, `default_temperature`, `display_name`, `extra_beta_headers`, `max_output_tokens`, `max_tokens`, `mode`, `name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `tool_override` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `AmazonBedrockSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `allow_global`, `authentication_method`, `available_models`, `endpoint_url`, `guardrail_identifier`, `guardrail_version`, `profile`, `region` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `BedrockAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `cache_configuration`, `default_temperature`, `display_name`, `max_output_tokens`, `max_tokens`, `mode`, `name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `BedrockAuthMethodContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `ApiKey`, `Automatic`, `NamedProfile`, `SingleSignOn` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `OllamaSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `auto_discover`, `available_models`, `context_window` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OllamaAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `display_name`, `keep_alive`, `max_tokens`, `name`, `supports_images`, `supports_thinking`, `supports_tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `KeepAlive`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Duration`, `Seconds` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `indefinite` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `OpenCodeSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models`, `show_free_models`, `show_go_models`, `show_zen_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenCodeModelSubscription`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Free`, `Go`, `Zen` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `OpenCodeAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `custom_model_api_url`, `display_name`, `interleaved_reasoning`, `max_output_tokens`, `max_tokens`, `name`, `protocol`, `reasoning_effort_levels` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `subscription` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LmStudioSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_key`, `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LmStudioAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `display_name`, `max_tokens`, `name`, `supports_images`, `supports_tool_calls` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DeepseekSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DeepseekAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `display_name`, `max_output_tokens`, `max_tokens`, `name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `MistralSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `MistralAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `display_name`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `name`, `supports_images`, `supports_thinking`, `supports_tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenAiSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenAiAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `capabilities`, `display_name`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `name`, `reasoning_effort` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenAiCompatibleSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenAiModelCapabilities`

| Grup | API | Not |
|---|---|---|
| Alanlar | `chat_completions`, `images` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenAiCompatibleAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `capabilities`, `display_name`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `name`, `reasoning_effort` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenAiCompatibleModelCapabilities`

| Grup | API | Not |
|---|---|---|
| Alanlar | `chat_completions`, `images`, `interleaved_reasoning`, `parallel_tool_calls`, `prompt_cache_key`, `tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `VercelAiGatewaySettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `VercelAiGatewayAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `capabilities`, `display_name`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GoogleSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GoogleAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `display_name`, `max_tokens`, `mode`, `name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `XAiSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `XaiAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar | `display_name`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `name`, `parallel_tool_calls`, `supports_images`, `supports_tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ZedDotDevSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ZedDotDevAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `cache_configuration`, `default_temperature`, `display_name`, `extra_beta_headers`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `mode` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `name`, `provider`, `tool_override` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ZedDotDevAvailableProvider`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Anthropic`, `Google`, `OpenAi` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `OpenRouterSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `api_url`, `available_models` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OpenRouterAvailableModel`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `display_name`, `max_completion_tokens`, `max_output_tokens`, `max_tokens`, `mode`, `name`, `provider`, `supports_images` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `supports_tools` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DataCollection`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Allow`, `Disallow` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `LanguageModelCacheConfiguration`

| Grup | API | Not |
|---|---|---|
| Alanlar | `max_cache_anchors`, `min_total_token`, `should_speculate` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LspSettingsMap`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ProjectSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `all_languages`, `context_server_timeout`, `context_servers`, `dap`, `disable_ai`, `git_hosting_providers`, `load_direnv`, `lsp` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `terminal`, `worktree` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `WorktreeSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `file_scan_exclusions`, `file_scan_inclusions`, `hidden_files`, `prevent_sharing_in_public_channels`, `private_files`, `read_only_files` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LspSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `binary`, `enable_lsp_tasks`, `fetch`, `initialization_options`, `settings` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `BinarySettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `arguments`, `env`, `ignore_system_version`, `path` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `FetchSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `pre_release` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GlobalLspSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `button`, `notifications`, `request_timeout`, `semantic_token_rules` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LspNotificationSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `dismiss_timeout_ms` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SemanticTokenRules`

| Grup | API | Not |
|---|---|---|
| Assoc const | `FILE_NAME` | Inherent impl üzerinde public sabit yüzeyidir; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Metotlar | `load` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `rules` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SemanticTokenRule`

| Grup | API | Not |
|---|---|---|
| Metotlar | `no_style_defined` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar 1 | `background_color`, `font_style`, `font_weight`, `foreground_color`, `strikethrough`, `style`, `token_modifiers`, `token_type` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `underline` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SemanticTokenColorOverride`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `InheritForeground`, `Replace` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SemanticTokenFontWeight`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bold`, `Normal` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `SemanticTokenFontStyle`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Italic`, `Normal` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `DapSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `args`, `binary`, `env` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SessionSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `restore_unsaved_buffers`, `trust_all_worktrees` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ContextServerSettingsContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Extension`, `Http`, `Stdio` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `set_enabled` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `OAuthClientSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `client_id`, `client_secret` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ContextServerCommand`

| Grup | API | Not |
|---|---|---|
| Alanlar | `args`, `env`, `path`, `timeout` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GitSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `blame`, `branch_picker`, `enabled`, `git_gutter`, `gutter_debounce`, `hunk_style`, `inline_blame`, `path_style` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `show_stage_restore_buttons`, `worktree_directory` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GitEnabledSettings`

| Grup | API | Not |
|---|---|---|
| Metotlar | `is_git_diff_enabled`, `is_git_status_enabled` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |
| Alanlar | `disable_git`, `enable_diff`, `enable_status` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GitGutterSetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Hide`, `TrackedFiles` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `InlineBlameSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `delay_ms`, `enabled`, `min_column`, `padding`, `show_commit_summary` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `BlameSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `show_avatar` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `BranchPickerSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `show_author_name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GitHunkStyleSetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `StagedHollow`, `UnstagedHollow` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `GitPathStyle`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `FileNameFirst`, `FilePathFirst` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `DiagnosticsSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `button`, `include_warnings`, `inline`, `lsp_pull_diagnostics` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `LspPullDiagnosticsSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `debounce_ms`, `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `InlineDiagnosticsSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enabled`, `max_severity`, `min_column`, `padding`, `update_debounce_ms` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `NodeBinarySettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `ignore_system_version`, `npm_path`, `path` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `DirenvSettings`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Direct`, `Disabled`, `ShellHook` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `DiagnosticSeverityContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `All`, `Error`, `Hint`, `Info`, `Off`, `Warning` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `GitHostingProviderConfig`

| Grup | API | Not |
|---|---|---|
| Alanlar | `base_url`, `name`, `provider` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `GitHostingProviderKind`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bitbucket`, `Forgejo`, `Gitea`, `Github`, `Gitlab`, `SourceHut` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ExtendingVec`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SaturatingBool`

| Grup | API | Not |
|---|---|---|
| Alanlar | `0` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ProjectTerminalSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `detect_venv`, `env`, `path_hyperlink_regexes`, `path_hyperlink_timeout_ms`, `shell`, `working_directory` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `TerminalSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `alternate_scroll`, `bell`, `blinking`, `button`, `copy_on_select`, `cursor_shape`, `default_height`, `default_width` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `dock`, `flexible`, `font_fallbacks`, `font_family`, `font_features`, `font_size`, `font_weight`, `keep_selection_on_copy` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 3 | `line_height`, `max_scroll_history_lines`, `minimum_contrast`, `option_as_meta`, `project`, `scroll_multiplier`, `scrollbar`, `show_count_badge` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 4 | `toolbar` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ShellDiscriminants`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Program`, `System`, `WithArguments` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `from_repr` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `Shell`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Program`, `System`, `WithArguments` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `WorkingDirectoryDiscriminants`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `AlwaysHome`, `CurrentFileDirectory`, `CurrentProjectDirectory`, `FirstProjectDirectory` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `from_repr` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `WorkingDirectory`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `AlwaysHome`, `CurrentFileDirectory`, `CurrentProjectDirectory`, `FirstProjectDirectory` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ScrollbarSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `show` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `TerminalLineHeight`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Comfortable`, `Custom`, `Standard` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `value` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `ShowScrollbar`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Auto`, `Never`, `System` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CursorShapeContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bar`, `Block`, `Hollow`, `Underline` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `TerminalBlink`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `On`, `TerminalControlled` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `AlternateScroll`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `On` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `TerminalToolbarContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `breadcrumbs` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `TerminalBell`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `System` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CondaManager`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Auto`, `Conda`, `Mamba`, `Micromamba` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `VenvSettings`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `On` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `as_option` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `VenvSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `activate_script`, `conda_manager`, `directories`, `venv_name` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PathHyperlinkRegex`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `MultiLine`, `SingleLine` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `TerminalDockPosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Bottom`, `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ActivateScript`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Csh`, `Default`, `Fish`, `Nushell`, `PowerShell`, `Pyenv` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `WindowButtonLayoutContent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Custom`, `PlatformDefault`, `Standard` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `into_layout` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `TitleBarSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `button_layout`, `show_branch_name`, `show_branch_status_icon`, `show_menus`, `show_onboarding_banner`, `show_project_items`, `show_sign_in`, `show_user_menu` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `show_user_picture` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `WorkspaceSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `active_pane_modifiers`, `autosave`, `bottom_dock_layout`, `centered_layout`, `cli_default_open_behavior`, `close_on_file_delete`, `close_panel_on_toggle`, `command_aliases` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `confirm_quit`, `drop_target_size`, `focus_follows_mouse`, `max_tabs`, `on_last_window_closed`, `pane_split_direction_horizontal`, `pane_split_direction_vertical`, `resize_all_panels_in_dock` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 3 | `restore_on_file_reopen`, `restore_on_startup`, `show_call_status_icon`, `text_rendering_mode`, `use_system_path_prompts`, `use_system_prompts`, `use_system_window_tabs`, `when_closing_with_no_tabs` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 4 | `window_decorations`, `zoomed_padding` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ItemSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `activate_on_close`, `close_position`, `file_icons`, `git_status`, `show_close_button`, `show_diagnostics` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `PreviewTabsSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `enable_keep_preview_on_code_navigation`, `enable_preview_file_from_code_navigation`, `enable_preview_from_file_finder`, `enable_preview_from_multibuffer`, `enable_preview_from_project_panel`, `enable_preview_multibuffer_from_code_navigation`, `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ClosePosition`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ShowCloseButton`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Always`, `Hidden`, `Hover` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ShowDiagnostics`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `All`, `Errors`, `Off` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ActivateOnClose`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `History`, `LeftNeighbour`, `Neighbour` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ActivePaneModifiers`

| Grup | API | Not |
|---|---|---|
| Alanlar | `border_size`, `inactive_opacity` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `BottomDockLayout`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Contained`, `Full`, `LeftAligned`, `RightAligned` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `WindowDecorations`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Client`, `Server` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CloseWindowWhenNoItems`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `CloseWindow`, `KeepWindowOpen`, `PlatformDefault` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `should_close` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `CliDefaultOpenBehavior`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `ExistingWindow`, `NewWindow` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `RestoreOnStartupBehavior`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `EmptyTab`, `LastSession`, `LastWorkspace`, `Launchpad` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `TabBarSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `show`, `show_nav_history_buttons`, `show_pinned_tabs_in_separate_row`, `show_tab_bar_buttons` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `StatusBarSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `active_encoding_button`, `active_language_button`, `cursor_position_button`, `line_endings_button`, `show`, `show_active_file` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `EncodingDisplayOptions`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Disabled`, `Enabled`, `NonUtf8` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `should_show` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `AutosaveSettingDiscriminants`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `AfterDelay`, `Off`, `OnFocusChange`, `OnWindowChange` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `from_repr` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `AutosaveSetting`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `AfterDelay`, `Off`, `OnFocusChange`, `OnWindowChange` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `should_save_on_close` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `PaneSplitDirectionHorizontal`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Down`, `Up` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `PaneSplitDirectionVertical`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Left`, `Right` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `CenteredLayoutSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `left_padding`, `right_padding` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `OnLastWindowClosed`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `PlatformDefault`, `QuitApp` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `is_quit_app` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `TextRenderingMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Grayscale`, `PlatformDefault`, `Subpixel` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ProjectPanelAutoOpenSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `on_create`, `on_drop`, `on_paste` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ProjectPanelSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar 1 | `auto_fold_dirs`, `auto_open`, `auto_reveal_entries`, `bold_folder_labels`, `button`, `default_width`, `diagnostic_badges`, `dock` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 2 | `drag_and_drop`, `entry_spacing`, `file_icons`, `folder_icons`, `git_status`, `git_status_indicator`, `hide_gitignore`, `hide_hidden` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 3 | `hide_root`, `indent_guides`, `indent_size`, `scrollbar`, `show_diagnostics`, `sort_mode`, `sort_order`, `starts_open` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |
| Alanlar 4 | `sticky_scroll` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ProjectPanelEntrySpacing`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Comfortable`, `Standard` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ProjectPanelSortMode`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `DirectoriesFirst`, `FilesFirst`, `Mixed` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ProjectPanelSortOrder`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Default`, `Lower`, `Unicode`, `Upper` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `ProjectPanelScrollbarSettingsContent`

| Grup | API | Not |
|---|---|---|
| Alanlar | `horizontal_scroll`, `show` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `ProjectPanelIndentGuidesSettings`

| Grup | API | Not |
|---|---|---|
| Alanlar | `show` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

### `SemanticTokens`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Combined`, `Full`, `Off` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `enabled`, `use_tree_sitter` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `DocumentFoldingRanges`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `On` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `enabled` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `DocumentSymbols`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Off`, `On` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |
| Metotlar | `lsp_enabled` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `FocusFollowsMouse`

| Grup | API | Not |
|---|---|---|
| Alanlar | `debounce_ms`, `enabled` | Public veri sözleşmesinin alanlarıdır; kullanım bağlamı bu dosyadaki ana açıklamayla okunur. |

<!-- phase14-api-anchor:end -->
