# EditorConfig ve VS Code İçe Aktarımı

`SettingsStore`, yalnızca Zed'in kendi JSON ayar dosyalarını işlemekle sınırlı değildir. Proje genelinde kullanılan `.editorconfig` dosyaları ile kullanıcıların diğer editörlerden geçiş yaparken kullandığı VS Code ve Cursor `settings.json` dosyalarını okuyup entegre eden iki ek mekanizma daha bulunur.

---

## `EditorconfigStore`

`EditorconfigStore`, EditorConfig spesifikasyonunu (`ec4rs` kütüphanesi aracılığıyla) çalışma zamanında çözümler. Store, her worktree'nin dahili (`InWorktree`) ve harici (`OutsideWorktree`) EditorConfig dosyalarını ayrı ayrı tutar. Aynı harici dosya birden çok worktree tarafından paylaşılıyorsa, başarım kazanımı için yalnızca bir kez ayrıştırılır (parse edilir).

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

- `external_configs` — Worktree dışındaki `.editorconfig` dosyalarını içerik ve ayrıştırma sonuçlarıyla birlikte saklar. Aynı dosya yolu farklı worktree'ler tarafından ortaklaşa kullanılabilir.
- `worktree_state` — Worktree başına dahili dosya tablosunu ve hangi harici yolların (external path) o worktree'ye bağlı olduğunu tutar.
- `local_external_config_watchers` — Her harici dosya için bağımsız bir izleme görevi (watcher task) çalıştırır ve dosya değiştiğinde store olay yayar.
- `local_external_config_discovery_tasks` — Bir worktree açıldığında, üst dizinleri kök (root) dizine doğru tarayarak `.editorconfig` dosyası arayan keşif görevleridir (discovery tasks).

`Editorconfig::from_str` metodu, `ConfigParser::new_buffered` üzerinden içeriği ayrıştırır, `is_root` bayrağını okur ve bölümleri (sections) toplar. Ayrıştırma başarısız olduğunda bir `anyhow::Error` döndürülür. Bu hatayı yakalayıp dosyayı `None` ile saklayan ve buna istinaden `InvalidSettingsError::Editorconfig { message, path }` yapısını kuran `set_configs` metodudur; böylece hatalı durumlar kullanıcı arayüzünde (UI) görünür kılınır.

**Olay Akışı.** Store, bir `EventEmitter<EditorconfigEvent>` yapısıdır:

```rust
pub enum EditorconfigEvent {
    ExternalConfigChanged {
        path: LocalSettingsPath,
        content: Option<String>,
        affected_worktree_ids: Vec<WorktreeId>,
    },
}
```

- `ExternalConfigChanged` — Harici bir `.editorconfig` dosyasının içeriği değiştiğinde veya dosya silindiğinde yayılır.
- `affected_worktree_ids` — Hangi worktree'lerin yeniden hesaplanması gerektiğini bildirir; arayüz bu olay üzerinden ilgili çalışma alanlarını yeniden çizer.

Crate içindeki `EditorconfigStore::set_configs(worktree_id, path, content)` metodu yeni veya güncellenmiş içerikleri yedirir; `content = None` olması durumunda ilgili dosya yolu kaldırılır. Çağrı `Result<(), InvalidSettingsError>` döner; parse hatası varsa dosya `None` ayrıştırılmış haliyle saklanır ve hata yukarıya iletilir. Harici dosya değişim olayları, izleyici ve keşif mekanizmaları tarafından `EditorconfigEvent::ExternalConfigChanged` olayı ile yayılır.

EditorConfig sonuçları Zed tarafında `EditorconfigProperties` üzerinden tüketilir; `indent_style`, `indent_size`, `tab_width`, `end_of_line`, `trim_trailing_whitespace` ve `insert_final_newline` gibi alanlar GPUI editör ayarlarına dönüştürülür.

| API | Alt Özellikler | Kısa Anlamı |
| :-- | :-- | :-- |
| `Editorconfig` | `is_root`, `sections`, `from_str` | `.editorconfig` içeriğinin parse edilmiş kök ve bölüm (section) listesidir. |
| `EditorconfigEvent` | `ExternalConfigChanged { path, content, affected_worktree_ids }` | Harici `.editorconfig` değiştiğinde etkilenen worktree listesini yayınlar. |
| `EditorconfigStore` | `set_configs`, `local_editorconfig_settings`, `discover_local_external_configs_chain`, `properties` | Worktree içi/dışı config kayıtlarını yedirir, yerel kaynak zincirini listeler, üst dizinlerde harici `.editorconfig` keşfi başlatır ve hedeflenen yol için birleşik property sonucunu üretir. |
| `EditorconfigProperties` | `ec4rs::Properties` type alias'ı | EditorConfig property sonucunun tüketim veri tipidir. |
| `InvalidSettingsError` | `LocalSettings`, `UserSettings`, `ServerSettings`, `DefaultSettings`, `Editorconfig`, `Tasks`, `Debug` | Ayar, task, debug veya EditorConfig parse hatalarını sınıflandırır. |
| `LocalSettingsPath` | `InWorktree`, `OutsideWorktree` | EditorConfig dosyasının worktree içinde mi yoksa dışında mı bulunduğunu ayırır. |

---

## `VsCodeSettings` ve `VsCodeSettingsSource`

Mevcut bir VS Code veya Cursor kullanıcısının ayar dosyasını okuyarak Zed kullanıcı JSON dosyasına aktarmaya yarayan yapılardır:

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

`Display` implementasyonu `"VS Code"` veya `"Cursor"` metinlerini üretir; arayüzde kaynağın adı bu metinler aracılığıyla gösterilir.

**Yükleme.** `VsCodeSettings::load_user_settings(source, fs)` metodu, asenkron olarak ilgili sistem yollarını arar:

- `VsCode` için `paths::vscode_settings_file_paths()`.
- `Cursor` için `paths::cursor_settings_file_paths()`.

Aday yollar `fs.is_file(...)` ile sırayla kontrol edilir; listenin sonundaki güncel dosya seçilir. Hiçbir aday bulunamazsa, aranan tüm yolları içeren bir `anyhow::Error` döndürülür. Dosya içerikleri `serde_json_lenient::from_str` ile yorum satırlarına toleranslı şekilde ayrıştırılır.

**Test Yardımcısı.** `VsCodeSettings::from_str(content, source)` metodu, test ortamlarında (`test-support`) string içeriklerinden örnekler üretmek amacıyla kullanılır; üretim derlemelerine dahil edilmez.

**Değer Okuma.** Yapı, dahili alanlarını sarmalayan modül içi tip güvenli okuma yardımcılarını kullanır:

- `read_value(setting) -> Option<&Value>` — Ham JSON değeri.
- `read_str(setting) -> Option<&str>`
- `read_string(setting) -> Option<String>`
- `read_bool(setting) -> Option<bool>`
- `read_f32(setting) -> Option<f32>`
- `read_u64(setting) -> Option<u64>`
- `read_usize(setting) -> Option<usize>`
- `read_u32(setting) -> Option<u32>`
- `read_enum(setting, mapper) -> Option<T>`
- `read_fonts(setting) -> (Option<FontFamilyName>, Option<Vec<FontFamilyName>>)`

Renk okumak için özel bir metot bulunmamaktadır; VS Code `editor.semanticTokenColorCustomizations` ayarı içerisindeki semantik token ön plan ve arka plan renkleri işlenirken, Zed renk modeline satır içi `Rgba::try_from(...)` çağrısıyla dönüştürülür.

`VsCodeSettings::settings_content()` metodu, bu dahili okuyucuları kullanarak bir `SettingsContent` üretir. Dışa açık içe aktarım (import) arayüzünün ana dönüşüm noktası burasıdır.

**İçe Aktarım Akışı.** `SettingsStore::import_vscode_settings(fs, vscode_settings)` çağrısı, `VsCodeSettings` içeriğini kullanıcının `settings.json` dosyasına uygular. İçe aktarım işlemi, alan bazlı tanımlanmış deterministik bir dönüşüm dizisinden geçer; başlıca eşlemelerden bir kısmı şunlardır:

| VS Code Ayarı | Zed Ayarı |
|---|---|
| `editor.tabSize` | `tab_size` |
| `editor.links` | `lsp_document_links` |
| `editor.fontSize` | `buffer_font_size` |
| `editor.fontFamily` | `buffer_font_family` / `buffer_font_fallbacks` |
| `editor.insertSpaces` | `hard_tabs` ters değeri |
| `files.eol` | `line_ending` |
| `editor.formatOnSave` + `editor.formatOnSaveMode` | `format_on_save` |
| `workbench.editor.enablePreview` | `preview_tabs.enabled` |
| `telemetry.telemetryLevel` | `telemetry.metrics` / `telemetry.diagnostics` |

`lsp_document_links` ayarı (VS Code tarafında `editor.links`), editörde sunucu bazlı belge bağlantısı sorgularını açıp kapatır ve varsayılan değeri `true`'dur. VS Code bu özelliği `editor.links` anahtarıyla taşır; Zed içe aktarma sürecinde bu boolean değeri olduğu gibi devralır. Bu ayar `EditorSettings` alanıdır ve çalışma zamanında değiştirildiğinde editör yeniden bağlantı listesi talep eder veya mevcut listeyi temizler. Etkin olduğunda, dil sunucusunun (LSP) döndürdüğü belge bağlantıları, editörün buluşsal yöntemle (heuristic) bulduğu dosya ve URL bağlantılarından önce gelir; böylece sunucu bir alanı tıklanabilir olarak işaretlemişse daha kesin ve güvenilir hedefler gösterilir.

`editor.formatOnSave` kapalıysa VS Code tarafındaki `editor.formatOnSaveMode` tek başına aktarım üretmez. `editor.formatOnSave` açık olduğunda `"file"` veya eksik mode değeri Zed tarafında `"on"` sonucunu verir; `"modifications"` değeri `"modifications"`, `"modificationsIfAvailable"` değeri ise `"modifications_if_available"` biçimine çevrilir. Bu eşleme Zed'in `FormatOnSave` enum'unun `snake_case` JSON değerleriyle birebir uyumludur.

Eşleşmesi olmayan ayarlar aktarılmadan atlanır; `SettingsStore::get_vscode_edits(old_text, vscode)` fonksiyonu aynı dönüşümü diske yazma işlemi yapmadan, mevcut kullanıcı içeriğine `merge_from` uygulayarak güncellenmiş tam metni (`String`) döndürür. Arayüz tarafında "şu dönüşümler uygulanacak" önizlemesi sunulurken bu fonksiyondan yararlanılır.

`SettingsStore::new_text_for_update(...)` ve `edits_for_update(...)` daha düşük seviyeli yardımcı fonksiyonlardır; harici bir editör veya CLI aracı kendi diff (fark) çıktısını üretirken bunlarla çalışır.

---

## Dikkat Edilmesi Gereken Hususlar

- `Editorconfig::from_str` ayrıştırma hatası verdiğinde store yine de yer tutucu bir kayıt saklar; arayüz üzerinde parse hatasını göstermek için `EditorconfigEvent` ile birlikte `InvalidSettingsError::Editorconfig` mesajının okunması gerekir.
- `EditorconfigStore`, bir worktree silindiğinde `worktree_state` girdisini temizler; harici dosyalara başka hiçbir worktree referans göstermiyorsa harici kayıtlar ve bunlara bağlı izleyici görevler (watcher tasks) de kaldırılır. Bu temizlik süreçleri store tarafından otomatik olarak yönetilir.
- `VsCodeSettings::load_user_settings` metodu aday yol listesinde dosyayı bulamazsa anlaşılır bir hata mesajı üretir; bu hatanın `notify_app_err` aracılığıyla kullanıcıya yansıtılması gerekir.
- `import_vscode_settings` ile normal ayar güncelleme süreçleri aynı yolu izler; her ikisi de eski metni store önbelleğinden almak yerine, her çağrıda doğrudan diskten taze olarak okur. Güncellenecek eski kullanıcı metni yazımdan hemen önce diskten okunur ve tüm güncellemeler tek bir seri kanal üzerinde sırayla işlenir; böylece içe aktarım ve manuel düzenleme işlemleri birbirine girmeden sıraya alınır.
- VS Code ayarlarındaki `editor.fontFamily` gibi tek değerde çoklu fallback tanımlayan alanlar, Zed'in `buffer_font_fallbacks` listesine bölünür; tek aile adı doğrudan aktarılırken, virgülle ayrılmış aile isimleri bölünerek listeye yerleştirilir.
