# Ayarlar

`settings` crate'i; `~/.config/zed/settings.json`, proje seviyesindeki `.zed/settings.json`, sunucu yan ayarları, paketlenmiş varsayılanlar ve uzaktan iletilen ayar override'larını (üzerine yazma) tek bir tip güvenli store (SettingsStore) içinde birleştirir. Bu bölüm `settings` arayüzünü ayrı bir ünite olarak ele alır; tema yönetimi konusu [Tema Yönetimi](../tema_yonetimi/tema_yonetimi.md) içinde anlatıldığı için burada tekrarlanmaz.

Bu arayüz `settings` crate'inde toplanır; ayar içeriği `settings_content`, derive ve attribute makroları ise `settings_macros` crate'inde bulunur. Güncel Zed kod yapısında ayrı bir keymap crate'i bulunmamaktadır: keymap ayar arayüzü `settings` crate'inde, düşük seviyeli GPUI binding tipleri ise `gpui` içinde yer alır.

Bölümün alt dosyalarında ele alınan konular şu şekildedir:

- **Akış ve Kayıt** — `Settings` trait'i, `RegisterSetting` derive makrosu, `Settings::register` metodu ve ayar değişimlerinin dinlenmesi.
- **`SettingsStore`** — Store tarafından tutulan kaynaklar (varsayılan, kullanıcı, global, sunucu, eklenti, yerel), öncelik sıralaması, sorgulama, yazma ve şema üretimi.
- **Ayar Dosyası İzleme ve Güncelleme** — `watch_config_file`, `watch_config_dir`, `update_settings_file`, `update_settings_file_with_completion`.
- **Keymap Dosyası** — `KeymapFile`, `KeymapSection`, `KeymapAction`, `KeybindSource`, `KeybindUpdateOperation`, `KeybindUpdateTarget`, `KeyBindingValidator`.
- **EditorConfig ve VS Code İçe Aktarımı** — `EditorconfigStore`, `Editorconfig`, `EditorconfigEvent`, `VsCodeSettings` ve `VsCodeSettingsSource`.

Kök crate'in daha küçük ama dışa açık yardımcıları da bu bölümün kapsamındadır:

- `SettingsAssets`, `DEFAULT_KEYMAP_PATH`, `VIM_KEYMAP_PATH` ve `EMPTY_THEME_NAME` paketlenmiş varsayılan ayar, keymap ve test tema varlıklarını bağlar.
- `DefaultSemanticTokenRules` global semantic token varsayılanını, `BaseKeymap` ise seçilen temel keymap adını GPUI ayar modeline taşır.
- `IntoGpui` ve `EditableSettingControl`, ayar içeriğinin UI/editör kontrol tiplerine çevrilmesinde kullanılan yardımcı trait'lerdir.
- `settings::fallible_options` modülü `FallibleOption` ve `parse_json` re-export'larını sağlar; `settings_macros` tarafındaki `with_fallible_options` niteliği (attribute) bu akışı alan bazlı toleranslı parse işlemi için kullanır.
- `settings_macros` crate'i dışa açık olarak `MergeFrom`, `RegisterSetting` ve `with_fallible_options` makrolarını üretir.
- `RegisteredSetting`, doğrudan uygulama kodu için değil, `RegisterSetting` derive makrosunun `inventory` kaydına yazdığı iç köprü tipidir.
- `UserSettingsContentExt`, aktif profil, release kanalı ve işletim sistemi override'larını `UserSettingsContent` üzerinden okumak için kullanılan extension trait'tir.

## Kök Crate Yardımcıları

Kök `settings` crate'i çok sayıda küçük dışa açık yardımcıyı re-export eder. Bunların çoğu ayrı uzun açıklamalar gerektirmez; hangi değerleri taşıdıklarını bilmek yeterlidir:

| API | Alt Özellikler | Kısa Anlamı |
| :-- | :-- | :-- |
| `DEFAULT_KEYMAP_PATH` | platforma göre `keymaps/default-*.json` | Paketlenmiş varsayılan keymap asset yoludur. |
| `VIM_KEYMAP_PATH` | `keymaps/vim.json` | Vim modu keymap asset yoludur. |
| `EMPTY_THEME_NAME` | `empty-theme` | Test/fallback tema dosyası için boş tema adıdır. |
| `BaseKeymap` | `VSCode`, `JetBrains`, `SublimeText`, `Atom`, `TextMate`, `Emacs`, `Cursor`, `None`, `OPTIONS`, `asset_path` | Kullanıcının seçtiği temel keymap ailesini ve asset yolunu taşır. |
| `DefaultSemanticTokenRules` | `SemanticTokenRules` sarmalayıcısı | Varsayılan semantic token kurallarını GPUI global'i olarak saklar. |
| `EditableSettingControl` | `RenderOnce` bound'u | Ayar editörü içinde render edilebilen özel kontrol sözleşmesidir. |
| `RegisteredSetting` | `settings_value`, `from_settings`, `id` | `RegisterSetting` derive makrosunun `inventory` kaydına yazdığı iç köprü tipidir. |
| `UserSettingsContentExt` | `for_profile`, `for_release_channel`, `for_os` | Aktif profil, release kanalı ve OS override katmanlarını okur. |
| `FallibleOption` | toleranslı alan parse sözleşmesi | Hatalı alanın tüm ayar dosyasını bozmasını önleyen toleranslı option modelidir. |
| `fallible_options` | modül/re-export | `FallibleOption` ve toleranslı parse yardımcılarının modül kapısıdır. |
| `settings_file` | modül/re-export | Ayar dosyası izleme, boş tema ve update yardımcılarının kaynak modülüdür. |
| `settings::init`, `SettingsAssets`, `IntoGpui` | startup kurulumu, paketlenmiş settings asset'leri ve content-to-GPUI dönüşümü | Kök `settings` crate'inin en sık kullanılan uygulama girişleridir. |
| `default_settings`, `default_keymap`, `vim_keymap`, `default_semantic_token_rules` | paketlenmiş default settings/keymap ve semantic token payload'ları | Startup ve test kurulumları bu yardımcılarla asset içeriğini çözer. |
| `initial_user_settings_content`, `initial_server_settings_content`, `initial_project_settings_content`, `initial_keymap_content`, `initial_tasks_content`, `initial_debug_tasks_content`, `initial_local_debug_tasks_content` | kullanıcıya veya projeye ilk kez yazılacak boş/örnek dosya içerikleri | Yeni ayar, keymap, task ve debug dosyası oluşturma akışının seed metinleridir. |
| `settings_json`, `parse_json`, `update_settings_file_with_completion` | JSON parse re-export'u ve tamamlanma sinyalli settings dosyası güncelleme helper'ı | Settings UI ve import akışında düşük seviyeli JSON yardımcılarına köprü kurar. |
| `settings_macros`, `MergeFrom`, `with_fallible_options` | derive ve attribute macro crate yüzeyi | `RegisterSetting` ile birlikte settings content schema'sının merge ve toleranslı parse davranışını üretir. |
| `infer_json_indent_size`, `parse_json_with_comments`, `update_value_in_json_text` | `settings_json` crate'inin girintileme, yorumlu parse ve path bazlı JSON güncelleme helper'ları | Ayar dosyasını biçim koruyarak güncelleyen alt katmanlarda bu yardımcılardan yararlanılır. |
