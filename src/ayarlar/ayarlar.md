# Ayarlar

`settings` crate'i `~/.config/zed/settings.json`, proje seviyesindeki `.zed/settings.json`, sunucu yan ayarları, build-in defaults ve uzaktan iletilen ayar override'larını tek bir tip-güvenli store içinde birleştirir. Bu bölüm, daha önce `gpui_kullanimi/15-zed-settings-ve-theme.md` içinde dağınık duran ve kapsam dışı kalan `crates/settings` yüzeyini ayrı bir ünite olarak toplar; tema tarafı zaten [Tema Yönetimi](../tema_yonetimi/tema_yonetimi.md) içinde anlatılır, bu nedenle burada tekrarlanmaz.

Ana referanslar: `crates/settings/src/settings.rs`, `crates/settings/src/settings_store.rs`, `crates/settings/src/settings_file.rs`, `crates/settings/src/keymap_file.rs`, `crates/settings/src/editorconfig_store.rs`, `crates/settings/src/vscode_import.rs`, ayar içeriği için `crates/settings_content/`, derive ve attribute makroları için `crates/settings_macros/`. Güncel Zed ağacında ayrı bir `crates/keymap/` crate'i yoktur; keymap ayar yüzeyi `crates/settings/src/keymap_file.rs` içinde, düşük seviye GPUI binding tipleri ise `crates/gpui/src/keymap/` altında yaşar.

Bölüm hangi alt dosyada hangi yüzeyi anlatır:

- **Akış ve kayıt** — `Settings` trait'i, `RegisterSetting` derive'ı, `Settings::register`, ayar değişimini dinleme.
- **`SettingsStore`** — store'un tutuğu kaynaklar (default, user, global, server, extension, local), öncelik sıralaması, sorgulama, yazma ve schema üretimi.
- **Ayar dosyası izleme ve güncelleme** — `watch_config_file`, `watch_config_dir`, `update_settings_file`, `update_settings_file_with_completion`.
- **Keymap dosyası** — `KeymapFile`, `KeymapSection`, `KeymapAction`, `KeybindSource`, `KeybindUpdateOperation`, `KeybindUpdateTarget`, `KeyBindingValidator`.
- **EditorConfig ve VS Code içe aktarımı** — `EditorconfigStore`, `Editorconfig`, `EditorconfigEvent`, `VsCodeSettings` ve `VsCodeSettingsSource`.

Kök crate'in daha küçük ama public yardımcıları da bu bölümün kapsamındadır:

- `SettingsAssets`, `DEFAULT_KEYMAP_PATH`, `VIM_KEYMAP_PATH` ve `EMPTY_THEME_NAME` paketlenmiş default ayar, keymap ve test tema varlıklarını bağlar.
- `DefaultSemanticTokenRules` global semantic token default'ını, `BaseKeymap` ise seçilen temel keymap adını GPUI ayar modeline taşır.
- `IntoGpui` ve `EditableSettingControl` ayar içeriğinin UI/editör kontrol tiplerine çevrilmesinde kullanılan yardımcı trait'lerdir.
- `settings::fallible_options` modülü `FallibleOption` ve `parse_json` re-export'larını sağlar; `settings_macros` tarafındaki `with_fallible_options` attribute'u bu akışı alan bazlı toleranslı parse için kullanır.
- `settings_macros` crate'i public olarak `MergeFrom`, `RegisterSetting` ve `with_fallible_options` makrolarını üretir.
- `RegisteredSetting` doğrudan uygulama kodu için değil, `RegisterSetting` derive'ının `inventory` kaydına yazdığı iç köprü tipidir.
- `UserSettingsContentExt` aktif profil, release kanalı ve işletim sistemi override'larını `UserSettingsContent` üzerinden okumak için kullanılan extension trait'tir.

## Kök crate yardımcıları

Kök `settings` crate'i çok sayıda küçük public yardımcıyı re-export eder. Bunların çoğu ayrı uzun bölüm istemez; hangi değerleri taşıdıklarını bilmek yeterlidir:

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `DEFAULT_KEYMAP_PATH` | platforma göre `keymaps/default-*.json` | Paketlenmiş varsayılan keymap asset yoludur. |
| `VIM_KEYMAP_PATH` | `keymaps/vim.json` | Vim modu keymap asset yoludur. |
| `EMPTY_THEME_NAME` | `empty-theme` | Test/fallback tema dosyası için boş tema adıdır. |
| `BaseKeymap` | `VSCode`, `JetBrains`, `SublimeText`, `Atom`, `TextMate`, `Emacs`, `Cursor`, `None`, `OPTIONS`, `asset_path` | Kullanıcının seçtiği temel keymap ailesini ve asset yolunu taşır. |
| `DefaultSemanticTokenRules` | `SemanticTokenRules` sarmalayıcısı | Varsayılan semantic token kurallarını GPUI global'i olarak saklar. |
| `EditableSettingControl` | `RenderOnce` bound'u | Ayar editörü içinde render edilebilen özel kontrol sözleşmesidir. |
| `RegisteredSetting` | `settings_value`, `from_settings`, `id` | `RegisterSetting` derive'ının `inventory` kaydına yazdığı iç köprü tipidir. |
| `UserSettingsContentExt` | `for_profile`, `for_release_channel`, `for_os` | Aktif profil, release kanalı ve OS override katmanlarını okur. |
| `FallibleOption` | toleranslı alan parse sözleşmesi | Hatalı alanın tüm ayar dosyasını düşürmesini önleyen fallible option modelidir. |
| `fallible_options` | modül/re-export | `FallibleOption` ve toleranslı parse yardımcılarının modül kapısıdır. |
| `settings_file` | modül/re-export | Ayar dosyası izleme, boş tema ve update helper'larının kaynak modülüdür. |
