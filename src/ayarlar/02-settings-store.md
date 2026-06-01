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
