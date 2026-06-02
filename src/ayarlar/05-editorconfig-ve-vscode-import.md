# EditorConfig ve VS Code İçe Aktarımı

`SettingsStore` yalnız Zed'in kendi JSON ayar dosyalarını işlemez. İki ek format için ayrı yüzeyler bulunur: proje boyunca yayılan `.editorconfig` dosyaları ve kullanıcı geçişlerinde okunan VS Code / Cursor `settings.json` dosyaları.

---

## `EditorconfigStore`

`crates/settings/src/editorconfig_store.rs` EditorConfig spesifikasyonunu (`ec4rs` üzerinden) çalışma zamanında çözer. Store her worktree'nin internal (`InWorktree`) ve external (`OutsideWorktree`) EditorConfig dosyalarını ayrı ayrı tutar; aynı external dosya birden çok worktree tarafından paylaşılıyorsa yalnız bir kez parse edilir.

```rust
pub struct EditorconfigStore {
    external_configs: BTreeMap<Arc<Path>, (String, Option<Editorconfig>)>,
    worktree_state: BTreeMap<WorktreeId, EditorconfigWorktreeState>,
    local_external_config_watchers: BTreeMap<Arc<Path>, Task<()>>,
    local_external_config_discovery_tasks: BTreeMap<WorktreeId, Task<()>>,
}

pub struct Editorconfig {
    pub is_root: bool,
    pub sections: SmallVec<[Section; 5]>,
}

pub type EditorconfigProperties = ec4rs::Properties;
```

- `external_configs` worktree dışı `.editorconfig` dosyalarını içerik ve parse sonucu ile saklar. Aynı yol farklı worktree'ler için ortaktır.
- `worktree_state` worktree başına internal dosya tablosunu ve hangi external path'lerin ona bağlı olduğunu tutar.
- `local_external_config_watchers` her external dosya için ayrı bir izleyici task çalıştırır; dosya değişince store olay yayar.
- `local_external_config_discovery_tasks` worktree açılırken ev dizinine doğru `.editorconfig` araması yapan keşif task'larıdır.

`Editorconfig::from_str` `ConfigParser::new_buffered` üzerinden parse eder, `is_root` bayrağını okur ve section'ları toplar. Parse başarısız olursa `InvalidSettingsError::Editorconfig { message, path }` döner; store bu dosyayı `None` ile saklayarak hatalı durumu UI'da gösterilir kılar.

**Olay akışı.** Store bir `EventEmitter<EditorconfigEvent>`'tir:

```rust
pub enum EditorconfigEvent {
    ExternalConfigChanged {
        path: LocalSettingsPath,
        content: Option<String>,
        affected_worktree_ids: Vec<WorktreeId>,
    },
}
```

- `ExternalConfigChanged` external bir `.editorconfig` dosyasının içeriği veya silme durumu değiştiğinde yayılır.
- `affected_worktree_ids` hangi worktree'lerin yeniden hesaplanması gerektiğini bildirir; uyumlu UI o worktree'leri yeniden çizmek için bunu dinler.

`EditorconfigStore::set_configs(worktree_id, path, content)` yeni ya da güncellenmiş içeriği yedirir; `content = None` o yolu kaldırır. Çağrı `Result<(), InvalidSettingsError>` döner; parse hatası varsa dosya boş parsed haliyle saklanır, hata yukarıya iletilir ve aksi takdirde store olay yayar.

EditorConfig sonucu Zed tarafında `EditorconfigProperties` üzerinden tüketilir; `indent_style`, `indent_size`, `tab_width`, `end_of_line`, `trim_trailing_whitespace`, `insert_final_newline` gibi alanlar GPUI editör ayarına çevrilir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `Editorconfig` | `is_root`, `sections`, `from_str` | `.editorconfig` içeriğinin parse edilmiş kök ve section listesidir. |
| `EditorconfigEvent` | `ExternalConfigChanged { path, content, affected_worktree_ids }` | External `.editorconfig` değiştiğinde etkilenen worktree listesini yayınlar. |
| `EditorconfigStore` | `set_configs`, `local_editorconfig_settings`, `discover_local_external_configs_chain`, `properties` | Worktree içi/dışı config kayıtlarını yedirir, yerel kaynak zincirini listeler, parent dizinlerde external `.editorconfig` keşfi başlatır ve path için birleşik property sonucunu üretir. |
| `EditorconfigProperties` | `ec4rs::Properties` type alias'ı | EditorConfig property sonucunun tüketim tipidir. |
| `InvalidSettingsError` | `LocalSettings`, `UserSettings`, `ServerSettings`, `DefaultSettings`, `Editorconfig`, `Tasks`, `Debug` | Ayar, task, debug veya EditorConfig parse hatalarını sınıflandırır. |
| `LocalSettingsPath` | `InWorktree`, `OutsideWorktree` | EditorConfig dosyasının worktree içinde mi dışında mı bulunduğunu ayırır. |

---

## `VsCodeSettings` ve `VsCodeSettingsSource`

**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `VsCodeSettings` | Metotlar | `load_user_settings`, `settings_content` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |
| `VsCodeSettings` | Alanlar | `source` | Public veri alanları; runtime, stil veya ayar sözleşmesinin taşınan parçalarıdır. |
| `VsCodeSettingsSource` | Varyantlar | `Cursor`, `VsCode` | Enum seçim değerleri; davranış farkı ilgili konu anlatımında verilir. |


`crates/settings/src/vscode_import.rs` mevcut VS Code veya Cursor kullanıcısının ayar dosyasını okuyup Zed kullanıcı JSON'una aktarır.

```rust
pub enum VsCodeSettingsSource {
    VsCode,
    Cursor,
}

pub struct VsCodeSettings {
    pub source: VsCodeSettingsSource,
    pub path: Arc<Path>,
    content: Map<String, Value>,
}
```

`Display` impl'i `"VS Code"` veya `"Cursor"` yazar; UI'da kaynağın adı bu üzerinden gösterilir.

**Yükleme.** `VsCodeSettings::load_user_settings(source, fs)` async olarak doğru sistem yolunu arar:

- `VsCode` için `paths::vscode_settings_file_paths()`.
- `Cursor` için `paths::cursor_settings_file_paths()`.

Adaylar `fs.is_file(...)` ile sırayla kontrol edilir; güncel kaynak her eşleşmede `path` değerini güncellediği için liste sırasındaki son mevcut dosya seçersin. Hiçbiri bulunamazsa beklenen yolların listesini içeren `anyhow::Error` döner. Dosya `serde_json_lenient::from_str` ile yorum-toleranslı parse edilir.

**Test yardımcı.** `VsCodeSettings::from_str(content, source)` `test-support` altında string içerikten örnek üretir; CI dışında derlenmez.

**Değer okuma.** Yapı private alanlarını sarmalayan modül içi tipli okuma yardımcıları kullanır; bunlar `pub` API değildir:

- `read_value(setting) -> Option<&Value>` — ham JSON değeri.
- `read_str(setting) -> Option<&str>`
- `read_string(setting) -> Option<String>`
- `read_bool(setting) -> Option<bool>`
- `read_f32(setting) -> Option<f32>`
- `read_u64(setting) -> Option<u64>`
- `read_usize(setting) -> Option<usize>`
- `read_u32(setting) -> Option<u32>`
- `read_enum(setting, mapper) -> Option<T>`
- `read_fonts(setting) -> (Option<FontFamilyName>, Option<Vec<FontFamilyName>>)`

Crate `Rgba` parse'ı için ayrıca renk yardımcıları içerir; importer modülü VS Code tema ve renk ayarlarını Zed `Hsla`/`Rgba` modeline çevirirken bu okuyucuları kullanır.

`VsCodeSettings::settings_content()` bu private okuyucuları kullanarak bir `SettingsContent` üretir. Public import yüzeyinin ana dönüşüm noktası budur.

**Içe aktarım akışı.** `SettingsStore::import_vscode_settings(fs, vscode_settings)` `VsCodeSettings` içeriğini kullanıcı `settings.json`'una uygular. İçeri aktarım deterministik bir eşleme listesinden geçer; başlıca eşlemelerden bir kısmı şunlardır:

| VS Code ayarı | Zed ayarı |
|---|---|
| `editor.tabSize` | `tab_size` |
| `workbench.colorTheme` | `theme` |
| `editor.links` | `lsp_document_links` |
| `editor.fontSize` | `buffer_font_size` |
| `editor.fontFamily` | `buffer_font_family` / `buffer_font_fallbacks` |

`lsp_document_links` (VS Code: `editor.links`) editörde LSP `textDocument/documentLink` sorgusunu açıp kapatır; varsayılanı `true`'dur. VS Code bu özelliği `editor.links` anahtarıyla taşır; Zed içe aktarmada bool değeri olduğu gibi alır. Bu ayar `EditorSettings` alanıdır ve çalışma zamanında değiştirildiğinde editör yeniden bağlantı listesi ister ya da mevcut listeyi temizler — tam da kod lens veya satır içi renk davranışında olduğu gibi. Etkin olduğunda dil sunucusunun döndürdüğü belge bağlantıları, editörün buluşsal yöntemle bulduğu URL ve dosya bağlantılarından önce gelir; böylece sunucu bir aralığı tıklanabilir olarak işaretlemiş ise hem daha kesin hem daha güvenilir bir hedef gösterilir. Eşleşmesi olmayan ayarlar atlanır; `SettingsStore::get_vscode_edits(old_text, vscode)` aynı dönüşümü dosya yazımı yapmadan metin diff'i olarak döndürür ve mevcut kullanıcı içeriğine `merge_from` uygular. UI "şu dönüşümler uygulanacak" önizlemesi için bunu kullanır.

`SettingsStore::new_text_for_update(...)` ve `edits_for_update(...)` daha düşük seviye yardımcılarıdır; ayrı bir editör veya CLI komutu kendi diff'ini üretirken bunlarla çalışır.

---

## Tuzaklar

- `Editorconfig::from_str` hata verdiğinde store yine yer tutucu bir kayıt saklar; UI parse hatasını göstermek için `EditorconfigEvent` ile birlikte `InvalidSettingsError::Editorconfig` mesajını okumalıdır.
- `EditorconfigStore` worktree silindiğinde `worktree_state` girdisini temizler; external dosyalardan başka kimse referans göstermiyorsa external kayıtlar ve izleyici task'ları da kaldırılır. Worktree açma/kapama akışında bu temizlik manuel olarak garanti edilmez; store tarafından yönetilir.
- `VsCodeSettings::load_user_settings` aday path listesinde dosyayı bulamazsa anlaşılır bir hata mesajı üretir; bu hata `notify_app_err` ile kullanıcıya yansıtılmalıdır.
- `import_vscode_settings` `update_settings_file` ile aynı atomic-write yolunu kullanır; yazma sırasında store'un eski user metnine sahip olduğu varsayılır. Eş zamanlı kullanıcı düzenlemeleri sırasında değişikliği reddedmek yerine önce `update_settings_file_with_completion` üzerinden bir senkron yazma tamamlanmalıdır.
- VS Code ayarlarındaki `editor.fontFamily` gibi tek değer-çoklu fallback alanları Zed'in `buffer_font_fallbacks` listesine bölünür; tek string formatı doğrudan tek aileyi temsil eder, virgülle ayrılmış stringler bölünür.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `EditorconfigEvent`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `ExternalConfigChanged` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `InvalidSettingsError`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Debug`, `DefaultSettings`, `Editorconfig`, `LocalSettings`, `ServerSettings`, `Tasks`, `UserSettings` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
