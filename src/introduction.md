# Zed GPUI Kullanım Haritası

Bu rehber, Zed içinde yeni bir pencere, başlık çubuğu, pencere dekorasyonu, platforma özel davranış, blur/transparency veya UI bileşeni eklerken doğru dosya ve API'ye hızla ulaşabilmek için hazırlanmış kapsamlı bir başvuru kaynağıdır.

Ana kaynak dosyalar:

- GPUI çekirdeği: `crates/gpui/src/gpui.rs`, `app.rs`, `window.rs`, `platform.rs`
- Platform seçimi: `crates/gpui_platform/src/gpui_platform.rs`
- Platform uygulamaları: `crates/gpui_macos`, `crates/gpui_windows`, `crates/gpui_linux`, `crates/gpui_web`
- Zed ana pencere seçenekleri: `crates/zed/src/zed.rs`
- Zed başlık çubuğu / dekorasyon: `crates/platform_title_bar`, `crates/title_bar`, `crates/workspace/src/workspace.rs`
- Zed UI bileşenleri: `crates/ui`, metin girişi için `crates/ui_input`
- Ayarlar ve tema: `crates/settings_content`, `crates/settings`, `crates/theme_settings`, `crates/theme`

Rehber, 21 ana bölüm ve 102 başlık halinde düzenlenmiştir. Her başlık, ilgili GPUI/Zed dosyalarındaki tipleri, fonksiyonları ve pratik kullanım desenlerini özetler. Sol kenar çubuğundaki içindekilerden ilgili bölüme geçebilirsiniz.
