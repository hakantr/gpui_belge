# Ayarlar

`settings` crate'i `~/.config/zed/settings.json`, proje seviyesindeki `.zed/settings.json`, sunucu yan ayarları, paketlenmiş varsayılanlar ve uzaktan iletilen ayar override'larını tek bir tip-güvenli store içinde birleştirir. Bu bölüm `settings` yüzeyini ayrı bir ünite olarak toplar; tema tarafı [Tema Yönetimi](../tema_yonetimi/tema_yonetimi.md) içinde anlatıldığı için burada tekrarlanmaz.

Bu yüzey `settings` crate'inde toplanır; ayar içeriği `settings_content`, derive ve attribute makroları ise `settings_macros` crate'inde bulunur. Güncel Zed ağacında ayrı bir keymap crate'i yoktur: keymap ayar yüzeyi `settings` crate'inde, düşük seviye GPUI binding tipleri ise `gpui` içinde yaşar.

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
| `settings::init`, `SettingsAssets`, `IntoGpui` | startup kurulumu, paketlenmiş settings asset'leri ve content-to-GPUI dönüşümü | Kök `settings` crate'inin en sık kullanılan uygulama girişleridir. |
| `default_settings`, `default_keymap`, `vim_keymap`, `default_semantic_token_rules` | paketlenmiş default settings/keymap ve semantic token payload'ları | Startup ve test kurulumları bu helper'larla asset içeriğini çözer. |
| `initial_user_settings_content`, `initial_server_settings_content`, `initial_project_settings_content`, `initial_keymap_content`, `initial_tasks_content`, `initial_debug_tasks_content`, `initial_local_debug_tasks_content` | kullanıcıya veya projeye ilk kez yazılacak boş/örnek dosya içerikleri | Yeni ayar, keymap, task ve debug dosyası oluşturma akışının seed metinleridir. |
| `settings_json`, `parse_json`, `update_settings_file_with_completion` | JSON parse re-export'u ve tamamlanma sinyalli settings dosyası güncelleme helper'ı | Settings UI ve import akışında düşük seviye JSON helper'larına köprü kurar. |
| `settings_macros`, `MergeFrom`, `with_fallible_options` | derive ve attribute macro crate yüzeyi | `RegisterSetting` ile birlikte settings content schema'sının merge ve toleranslı parse davranışını üretir. |
| `infer_json_indent_size`, `parse_json_with_comments`, `update_value_in_json_text` | `settings_json` crate'inin indentation, yorumlu parse ve path bazlı JSON güncelleme helper'ları | Ayar dosyasını biçim koruyarak güncelleyen alt katmanda kullanılır. |
