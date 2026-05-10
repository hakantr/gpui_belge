# Bölüm XIX — Zed Settings ve Theme

---

## 92. Persist, Settings ve Theme Akışı (Zed Tarafı)

GPUI çekirdeği değil ama yeni pencere/UI eklerken temaya ve ayarlara takılı
kalmak gerekir. Ana dosyalar: `crates/settings`, `crates/settings_content`,
`crates/theme`, `crates/theme_settings`.

Akış:

1. Kullanıcı `~/.config/zed/settings.json` veya proje `.zed/settings.json` yazar.
2. `SettingsStore` global'i değişimi yayar.
3. `Settings` trait'leri (`WorkspaceSettings`, `ThemeSettings`, ...) kendi
   bölümlerini parse eder.
4. UI tarafları `cx.observe_global::<SettingsStore>(...)` ile değişimi izler ve
   yeniden render eder.

Yeni bir ayar eklemek için önce `settings_content` içindeki JSON içerik modeline
alan eklenir, sonra runtime settings tipi `Settings` trait'ini uygular. Bu
repodaki gerçek trait ilişkili içerik tipi veya `load` yöntemi değil,
`from_settings` kullanır:

```rust
#[derive(Clone, Deserialize, RegisterSetting)]
pub struct YourSettings {
    pub enabled: bool,
}

impl Settings for YourSettings {
    fn from_settings(content: &settings::SettingsContent) -> Self {
        let section = &content.your_feature;
        Self {
            enabled: section.enabled.unwrap_or(false),
        }
    }
}
```

`RegisterSetting` derive'ı inventory üzerinden tipi `SettingsStore` içine kaydeder.
Elle kayıt gerekiyorsa uygulama başlangıcında `YourSettings::register(cx)` da
kullanılabilir. `Settings::get_global(cx)`, `Settings::get(path, cx)` ve
`Settings::try_get(cx)` okuma tarafındaki standart giriş noktalarıdır.

Güncel agent ayar içeriğinde `agent.default_model` yanında
`agent.subagent_model: Option<LanguageModelSelection>` de bulunur. `spawn_agent`
ile açılan subagent thread'i bu ayar set edilmişse onu kullanır; ayar yoksa parent
agent'ın model seçimiyle devam eder. Agent/multi-workspace davranışında
`AgentSettings::enabled` de önemli bir settings sinyalidir.

Tema renkleri:

```rust
let colors = cx.theme().colors();
let panel_bg = colors.panel_background;
let border = colors.border;
```

`cx.theme()` aktif `ThemeVariant` (light/dark) döndürür. `.colors()`,
`.players()`, `.syntax()` bölümlerini taşır. `theme::ActiveTheme` extension trait
`App` üzerinde olduğu için `cx.theme()` doğrudan çalışır.

Persist edilen örnekler:

- Pencere bounds (bkz. Bölüm 33).
- Açık projeler ve recent: `crates/recent_projects`.
- Workspace serialization: `crates/workspace/src/persistence.rs` ve
  `db` crate'i (SQLite tabanlı).
- Vim mod, panel boyutları, dock state: workspace serialization.

Tuzaklar:

- `cx.theme()` panel açılırken `None` olmaz; ancak `cx.global::<ThemeRegistry>()`
  henüz yüklenmemişse fallback theme döner.
- Settings serialization `SettingsContent` merge akışına bağlıdır; user/global,
  project ve language-specific kaynaklar `SettingsStore` içinde recompute edilir.
- Yeni ayar eklerken `settings_content` schema güncellenmeden JSON schema
  doğrulaması eski formatı kabul etmez.

## 93. SettingsStore: Kayıt, Okuma, Override ve Migration

`crates/settings/src/settings_store.rs`. `SettingsStore` Zed'in tüm ayar
kaynaklarını tek bir tip-güvenli store içinde birleştirir.

Ayar kayıt yolları:

```rust
// Derive ile inventory üzerinden otomatik kayıt:
#[derive(Clone, Deserialize, RegisterSetting)]
pub struct YourSettings { pub enabled: bool }

impl Settings for YourSettings {
    fn from_settings(content: &SettingsContent) -> Self {
        Self { enabled: content.your_feature.as_ref()
            .and_then(|f| f.enabled).unwrap_or(false) }
    }
}

// Manuel kayıt (her zaman çalışan path):
YourSettings::register(cx);
```

`RegisterSetting` derive `inventory::collect!` ile build-time topluluk yaratır.
Store kurulumu `SettingsStore::new(cx, &settings::default_settings())` imzasıyla
yapılır; Zed'in normal başlangıç yolunda bunu `settings::init(cx)` çağırır ve
oluşan store'u `cx.set_global(settings)` ile global yapar.

Okuma:

- `YourSettings::get_global(cx)`: aktif global değer.
- `YourSettings::get(Some(SettingsLocation { worktree_id, path }), cx)`:
  worktree veya `.zed/settings.json` override'ı dahil değer.
- `YourSettings::try_get(cx)`: store register edilmemişse `None`.
- `YourSettings::try_read_global(async_cx, |s| ...)`: async context içinde.

Yazma:

- `YourSettings::override_global(value, cx)`: programatik override; persist
  edilmez, sadece runtime state'i değiştirir.
- `settings::update_settings_file(fs, cx, |content, cx| { ... })`: user
  JSON'unu kalıcı yazma yolu; dosya okuma/yazma, parse ve store update akışı
  `SettingsStore::update_settings_file(...)` üzerinden tamamlanır.
- `SettingsStore::update_user_settings(...)` yalnızca `test-support` altında
  vardır; uygulama kodunda kalıcı yazma için kullanılmaz.

Observer akışı:

```rust
cx.observe_global::<SettingsStore>(|cx| {
    let theme = ThemeSettings::get_global(cx);
    apply_theme(theme, cx);
}).detach();
```

`SettingsStore` global'i her dosya değişimi veya programatik override sonrası
notify edilir; observer içinde değer zaten yeni state'tedir.

Migration:

- Kullanıcı JSON'u eski schema kullanıyorsa
  `crates/settings/src/migrator/` modülü değerleri yeni anahtarlara taşır.
- `SettingsStore::set_user_settings(...)` ve file watcher/update callback'leri
  `SettingsParseResult { parse_status, migration_status }` döndürür veya taşır.
- `MigrationStatus` değerleri `NotNeeded`, `Succeeded` ve
  `Failed { error }` şeklindedir. Başarılı migration in-memory uygulanır;
  çağıran taraf gerekiyorsa dosyayı yeniden yazar veya kullanıcıya uyarı üretir.
- Parse sonucu `ParseStatus::Success`, `ParseStatus::Unchanged` veya
  `ParseStatus::Failed { error }` olur; migration durumu ayrı alandır.

Tuzaklar:

- `from_settings` panic ediyorsa default JSON eksiktir; her alan
  `assets/settings/default.json` içinde tanımlı olmalıdır.
- Per-language ayar gerekiyorsa `LanguageSettings::get(Some(location), cx)` ile
  worktree-specific override otomatik gelir.
- Observer'da `cx.notify()` çağrısı entity'yi yeniden render etmek için gereklidir;
  `observe_global` sadece callback'i çalıştırır, view'i invalidate etmez.

## 94. ThemeRegistry, ThemeFamily ve Tema Yükleme

`crates/theme/src/registry.rs`, `crates/theme/src/theme.rs`,
`crates/theme_settings/src/theme_settings.rs`.

Tema veri modeli:

- `ThemeFamily { name, author, themes: Vec<Theme> }`: bir paket içindeki light/dark
  varyantlar.
- `Theme { name, appearance, styles }`: belirli bir varyant.
- `ThemeColors`, `StatusColors`, `PlayerColors`, `SyntaxTheme`: alt kategoriler.
- `Appearance::Light | Dark`: theme'in nominal görünüm modu.

`ThemeRegistry`:

- `ThemeRegistry::global(cx) -> Arc<Self>`: aktif registry.
- `ThemeRegistry::default_global(cx)` ve `try_global(cx)`: init/test kodunda
  registry erişimi.
- `registry.assets()`: bundled theme/icon asset source'u.
- `registry.list_names() -> Vec<SharedString>`: yüklü tema adları.
- `registry.list() -> Vec<ThemeMeta>`: tema adı ve appearance metadata'sı.
- `registry.get(name) -> Result<Arc<Theme>, ThemeNotFoundError>`.
- `registry.insert_theme_families(families)` veya `insert_themes(themes)`:
  tema ekleme.
- `registry.remove_user_themes(&names)`: verilen tema adlarını temizleme.
- `registry.list_icon_themes()`, `get_icon_theme(name)`,
  `default_icon_theme()`, `load_icon_theme(content, icons_root_dir)`,
  `remove_icon_themes(&names)`: icon theme yönetimi.
- `registry.extensions_loaded()` ve `set_extensions_loaded()`: extension
  temalarının yüklenip yüklenmediği bayrağı.

Aktif tema akışı:

```rust
let theme = cx.theme();        // &Arc<Theme>
let colors = theme.colors();   // &ThemeColors
let status = theme.status();   // &StatusColors
let players = theme.players(); // &PlayerColors
let syntax = theme.syntax();   // &SyntaxTheme
```

`cx.theme()` extension trait `theme::ActiveTheme` ile sağlanır; `App` üzerinde
çalışır. Aktif tema `ThemeSettings` içindeki seçimden ve `SystemAppearance`'tan
hesaplanır:

```rust
pub fn reload_theme(cx: &mut App) {
    let theme = configured_theme(cx);
    GlobalTheme::update_theme(cx, theme);
    cx.refresh_windows();
}
```

`reload_icon_theme(cx)` aynı modeli icon theme için uygular. `theme::init(...)`
registry, `SystemAppearance`, font family cache ve fallback `GlobalTheme`
kurar; `theme_settings::init(...)` bunun üzerine settings observer'larını ve
bundled/user theme yükleme akışını bağlar.

Tema ayar sağlayıcısı:

- `theme::set_theme_settings_provider(provider, cx)`: UI font, buffer font,
  font size ve UI density kaynağını global olarak bağlar.
- `theme::theme_settings(cx) -> &dyn ThemeSettingsProvider`: theme crate'inin
  concrete settings crate'ine bağımlı olmadan font/density okumasını sağlar.
- `UiDensity::{Compact, Default, Comfortable}` ve `spacing_ratio()` spacing
  ölçeğini verir; Zed tarafında provider implementasyonu `theme_settings`
  crate'indedir.

Custom tema yükleme:

```rust
theme_settings::load_user_theme(&ThemeRegistry::global(cx), bytes)?;
theme_settings::reload_theme(cx);
```

`load_user_theme` JSON'u `ThemeFamilyContent` olarak deserialize eder,
`refine_theme_family` ile gerçek `ThemeFamily` üretir ve
`insert_theme_families` çağırır. `crates/theme_importer/` VS Code temalarından
`theme_settings::ThemeContent` üretmek için yardımcılar içerir. Zed tarafında
`load_user_themes_in_background` ve watcher akışı dosya değişiminden sonra
`theme_settings::reload_theme(cx)` çağırır.

Tuzaklar:

- `cx.theme()` ilk frame'de fallback theme döndürebilir; observer ile
  `SystemAppearance` veya `SettingsStore` dinleyip rerender şarttır.
- `ThemeColors` tüm tokenları içerir; eksik token kullanıcı temada `null`
  bırakılırsa default light/dark theme'den fallback alınır.
- `Theme.styles.colors.background` yerine doğrudan `theme.colors().background`
  kullan; styles alanı internal layout'tur.


---

