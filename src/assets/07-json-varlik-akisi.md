# JSON varlıkları: tema, keymap, settings, badge

Bu bölüm, varlık altyapısının yapılandırılmış varlık katmanını ele alır. JSON dosyaları binary ile birlikte taşınır, fakat tüketim biçimleri birbirinden farklıdır:

- Tema JSON'ları çalışma zamanında bir kayda eklenir.
- Keymap JSON'ları kullanıcı tercihine göre seçilip ayrıştırılır.
- Settings JSON'ları varsayılan değer kaynağı olarak okunur.
- Badge JSON'u çalışma zamanında hiç tüketilmez.

Bu dört yolu birlikte anlatmak, "neden tüm JSON'lar aynı tüketim hattından geçmiyor?" sorusunu cevaplar. Yeni bir JSON tabanlı varlık eklerken hangi modelin seçileceğini de netleştirir.

![JSON Varlık Tüketim Yolları](images/json-varlik-yollari.svg)

---

## 1. JSON varlıklarının topolojisi

JSON dosyaları üç klasör altında dağılmıştır:

```text
assets/
├── themes/
│   ├── one/
│   │   ├── one.json          # 4 tema (Light, Dark, Light Gentler, Dark Gentler)
│   │   └── LICENSE
│   ├── ayu/
│   ├── gruvbox/
│   └── LICENSES/
├── keymaps/
│   ├── default-linux.json
│   ├── default-macos.json
│   ├── default-windows.json
│   ├── initial.json          # kullanıcının keymap dosyası şablonu
│   ├── storybook.json
│   ├── vim.json
│   ├── linux/                # editör emülasyon paketleri
│   │   ├── atom.json
│   │   ├── cursor.json
│   │   ├── emacs.json
│   │   ├── jetbrains.json
│   │   └── sublime_text.json
│   └── macos/
│       ├── atom.json
│       ├── cursor.json
│       ├── emacs.json
│       ├── jetbrains.json
│       ├── sublime_text.json
│       └── textmate.json
├── settings/
│   ├── default.json
│   ├── default_semantic_token_rules.json
│   ├── initial_user_settings.json
│   ├── initial_server_settings.json
│   ├── initial_local_settings.json
│   ├── initial_tasks.json
│   ├── initial_debug_tasks.json
│   └── initial_local_debug_tasks.json
└── badge/
	    └── v0.json               # çalışma zamanında okunmaz; README rozeti
```

İki ayrı `RustEmbed` struct'ı bu klasörleri taşır:

- `Assets` (`assets`): `themes/` klasörünü taşır. `badge/` çalışma zamanında kullanılmaz; `Assets` include listesinde yer almaz, sadece repository'deki varlık topolojisinin parçasıdır.
- `SettingsAssets` (`settings`): `keymaps/` ve `settings/`.

Tema sistemi `cx.asset_source()` üzerinden okur (yani `Assets` struct'ı çalışma zamanına `with_assets` ile bağlandıktan sonra erişilebilir). Keymap ve settings doğrudan `SettingsAssets::get` üzerinden senkron okur. `App` çalışma zamanı kurulmadan da çağrılabilir. Bu ayrım varlık altyapısının kuruluş sırasındaki kritik bir kararıdır. Sonraki bölümlerde örneklenir.

---

## 2. Tema JSON'larının akışı

Tema JSON'larının yüklenmesi `theme_settings` crate'indeki `load_bundled_themes` fonksiyonunda yaparsın:

```rust
pub fn load_bundled_themes(kayit: &ThemeRegistry) {
    let tema_yollari = kayit
        .assets()
        .list("themes/")
        ?
        .into_iter()
        .filter(|yol| yol.ends_with(".json"));

    for yol in tema_yollari {
        let Some(tema) = kayit.assets().load(&yol).log_err().flatten() else {
            continue;
        };

        let Some(tema_ailesi) = serde_json::from_slice(&tema)
            .with_context(|| format!("tema ayrıştırılamadı: \"{yol}\""))
            .log_err()
        else {
            continue;
        };

        let iyilestirilmis = refine_theme_family(tema_ailesi);
        kayit.insert_theme_families([iyilestirilmis]);
    }
}
```

Akış altı adımdadır:

1. **`kayit.assets().list("themes/")`** — Özyinelemeli listeleme; `themes/one/one.json`, `themes/ayu/ayu.json`, `themes/LICENSES/...` gibi tüm yollar döner.
2. **`.json` filtresi** — `LICENSE` dosyaları ve klasörler dışlanır. Filtre uzantı bazlıdır.
3. **`assets().load(&yol)` çağrısı** — Her tema dosyası ham byte olarak yüklenir. `log_err().flatten()` deseni, hata varsa log'a düşürür ve `None` döndürür; aksi halde `Some(baytlar)` ile devam edilir.
4. **`serde_json::from_slice`** — Baytlar `ThemeFamilyContent` struct'ına ayrıştırılır. Bu struct Zed tema JSON sözleşmesini yansıtır; tüm renk alanlarını `Option<T>` olarak tutar.
5. **`refine_theme_family`** — `Content` → `Refinement` → `Theme` dönüşümü uygularsın. Bu adım tema sistemi bölümünde detaylıdır; özetle: kullanıcı temasındaki eksik alanlar yedek değerlerle doldurulur ve çalışma zamanında kullanıma hazır `Theme` struct'ı üretilir.
6. **`kayit.insert_theme_families`** — Hazır tema ailesi `ThemeRegistry`'ye eklenir; `cx.theme()` artık bu temaya erişebilir.

**Hata toleransı:** Bozuk bir tema dosyası tüm uygulamayı durdurmaz. Ayrıştırma hatası `log_err()` ile log'a düşer, `continue` ile bir sonraki temaya geçilir. Bu davranış kullanıcı sürtüşmesini azaltır: bir tema dosyası bozuksa kullanıcı yalnızca o temaya erişemez, kalan tema seçimleri çalışmaya devam eder.

### 2.1 `LoadThemes` kademeleri ve varlık bağımlılığı

Tema sistemi başlatılırken üç farklı varlık davranışı seçebilirsin:

```rust
pub enum LoadThemes {
    /// Sadece yedek tema yüklenir; kullanıcı temaları yüklenmez.
    JustBase,
    /// Tüm gömülü temalar yüklenir.
    All(Box<dyn AssetSource>),
}

pub fn init(yuklenecek_temalar: LoadThemes, cx: &mut App) {
    SystemAppearance::init(cx);
    let varliklar = match yuklenecek_temalar {
        LoadThemes::JustBase => Box::new(()) as Box<dyn AssetSource>,
        LoadThemes::All(varliklar) => varliklar,
    };
    ThemeRegistry::set_global(varliklar, cx);
    FontFamilyCache::init_global(cx);
    // ...
}
```

`JustBase` modu test ortamı için kritiktir: `()` boş `AssetSource` ile geçilirse `load_bundled_themes` çağrısı boş liste döner; kayıt yalnızca yedek temayla kalır. Tema JSON'ları olmayan bir test ortamı da bu mod ile çalışır.

`All(varliklar)` modu üretim için kullanırsın. `Box<dyn AssetSource>` parametresi `Assets` struct'ından bir referans ister; `Assets` struct'ı tema klasörünü include eder (yukarıdaki `#[include = "themes/**/*"]` direktifi).

Zed'in `main.rs` dosyasındaki kuruluş:

```rust
theme_settings::init(theme::LoadThemes::All(Box::new(Assets)), cx);
```

Bu çağrıdan sonra `ThemeRegistry::global(cx)` tüm gömülü tema ailelerini içerir.

### 2.2 Kullanıcı temaları ve kayda alma

Kullanıcı temaları (yani `~/.config/zed/themes/*.json` altındaki dosyalar) ayrı bir yoldan yüklenir:

```rust
fn kullanici_temalarini_arkada_yukle(dosya_sistemi: Arc<dyn fs::Fs>, cx: &mut App) {
    cx.spawn({
        let dosya_sistemi = dosya_sistemi.clone();
        async move |cx| {
            // ... temalar_dizini taranır, her .json dosyası dosya_sistemi.load ile okunur
            // kullanici_temasini_yukle(kayit, baytlar) ile kayda eklenir
        }
    })
}
```

Dosya sisteminden okuma asenkron yapılır; binary'deki tema yükleme ise senkron `list+load` döngüsüdür. İki yol birleştiğinde aynı `ThemeRegistry`'ye akar ve fark gözlemlenemez. Bu, "binary'deki varlık + dosya sistemi geçersiz kılması" deseninin tema sistemindeki karşılığıdır.

---

## 3. Keymap JSON'ları ve `SettingsAssets` yolu

Keymap dosyaları farklı bir tüketim yolu izler. `settings` crate'i:

```rust
#[cfg(target_os = "macos")]
pub const DEFAULT_KEYMAP_PATH: &str = "keymaps/default-macos.json";

#[cfg(target_os = "windows")]
pub const DEFAULT_KEYMAP_PATH: &str = "keymaps/default-windows.json";

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub const DEFAULT_KEYMAP_PATH: &str = "keymaps/default-linux.json";

pub fn default_keymap() -> Cow<'static, str> {
    asset_str::<SettingsAssets>(DEFAULT_KEYMAP_PATH)
}

pub const VIM_KEYMAP_PATH: &str = "keymaps/vim.json";

pub fn vim_keymap() -> Cow<'static, str> {
    asset_str::<SettingsAssets>(VIM_KEYMAP_PATH)
}

pub fn initial_keymap_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("keymaps/initial.json")
}
```

Üç noktanın altını çizmek gerekir:

- **`cfg` ile platform seçimi.** Derleme zamanında platforma göre `DEFAULT_KEYMAP_PATH` farklı bir değere atarsın. macOS binary'si yalnızca `keymaps/default-macos.json`'u kullanır; diğer platform varyantları release paketinde bulunsa da çağrı yolu yoktur. Pratikte üçü de `SettingsAssets` erişim kümesine girer (`keymaps/*` include eder), ama çalışma zamanı yalnızca platforma uygun olanı okur.
- **`asset_str::<SettingsAssets>` çağrısı.** `util::asset_str` jenerik bir yardımcıdır:

  ```rust
  pub fn asset_str<A: rust_embed::RustEmbed>(yol: &str) -> Cow<'static, str> {
      match A::get(yol)?.data {
          Cow::Borrowed(baytlar) => Cow::Borrowed(std::str::from_utf8(baytlar)?),
          Cow::Owned(baytlar) => Cow::Owned(String::from_utf8(baytlar)?),
      }
  }
  ```

  Bu fonksiyon `RustEmbed::get` çağrısını yapar (yani `cx.asset_source()` değil), baytları UTF-8 string'e çevirir ve `Cow<'static, str>` döner. Bu yapı sayesinde keymap ve settings dosyaları `App` çalışma zamanı kurulmadan da okunabilir; özellikle erken kuruluş aşamasında settings store'a varsayılan değerleri vermek için kritiktir.

- **Sert paketleme kontratı.** `A::get(yol)` `None` döndürürse kaynak kodu fail-fast davranır. Bu, keymap dosyalarının `SettingsAssets` erişim kümesinde mutlaka bulunması gerektiğini söyleyen bir paketleme varsayımıdır. Eğer dosya silinirse veya `#[include]` filtresi yanlışsa, uygulama başlatılırken panik atar; bu da dağıtım öncesi tespit edilebilir bir hatadır.

Burada küçük ama önemli bir paketleme ayrıntısı vardır: `SettingsAssets` kaynak kodunda `#[include = "keymaps/*"]` olarak görünür, buna rağmen tüketilen yollar `keymaps/macos/atom.json` ve `keymaps/linux/jetbrains.json` gibi alt dizinlerdedir. Bunun nedeni `rust-embed` 8.11'in `include-exclude` özelliğinde kullanılan `globset` varsayılanlarının `*` karakterini yol ayırıcısını da eşleyebilecek şekilde değerlendirmesidir. Yani Zed'in mevcut kalıbı alt paketleri kapsar; yine de bu kalıp değiştirilirken kök `keymaps/*.json` dosyalarının yanı sıra platform alt paketlerinin de gömülü kaldığı mutlaka doğrulanmalıdır. Daha açık bir ifade istenirse `keymaps/**/*` kalıbı tercih edebilirsin.

### 3.1 Platforma özgü editör keymap paketleri

`assets/keymaps/macos/` ve `assets/keymaps/linux/` altında editör emülasyon dosyaları durur (`atom.json`, `cursor.json`, `emacs.json`, `jetbrains.json`, `sublime_text.json`, `textmate.json`). Bunlar `BaseKeymap` enum'u üzerinden seçersin:

```rust
pub fn asset_path(&self) -> Option<&'static str> {
    #[cfg(target_os = "macos")]
    match self {
        BaseKeymap::JetBrains => Some("keymaps/macos/jetbrains.json"),
        BaseKeymap::SublimeText => Some("keymaps/macos/sublime_text.json"),
        BaseKeymap::Atom => Some("keymaps/macos/atom.json"),
        BaseKeymap::TextMate => Some("keymaps/macos/textmate.json"),
        BaseKeymap::Emacs => Some("keymaps/macos/emacs.json"),
        BaseKeymap::Cursor => Some("keymaps/macos/cursor.json"),
        BaseKeymap::VSCode => None,         // varsayılan, ek dosya yok
        BaseKeymap::None => None,
    }
    // ... linux varyantı
}
```

Üç davranış kuralı önemlidir:

- **VSCode varsayılan keymap'tir.** `default-<platform>.json` zaten VSCode kısayollarını taşır. `BaseKeymap::VSCode` için ek bir dosya yoktur; sadece varsayılan keymap aktif olur.
- **`BaseKeymap::None` boş keymap'tir.** Tüm kısayollar devre dışı bırakılır; kullanıcı her kısayolu kendisi tanımlar.
- **Linux'ta TextMate yoktur.** macOS'a özgü bir paketleme tercihidir; `#[cfg]` ile match koluna eklenmez. Bu, "binary'de olsa bile platforma uygun değilse çağırma" davranışının tipik bir örneğidir.

Keymap seçimi `BaseKeymap` ayarından okunur, `BaseKeymap::asset_path` ile yol elde edilir, `SettingsAssets` üzerinden içerik okunur ve varsayılan keymap'in üzerine eklersin. Bu zincir kullanıcı tercihinin varlık hattına nasıl bağlandığını net bir şekilde gösterir.

---

## 4. Settings JSON'ları

Settings yükleyici hattı `asset_str` ile birden fazla varsayılan dosyayı okur:

```rust
pub fn default_settings() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/default.json")
}

pub fn default_semantic_token_rules() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/default_semantic_token_rules.json")
}

pub fn initial_user_settings_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/initial_user_settings.json")
}

pub fn initial_server_settings_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/initial_server_settings.json")
}

pub fn initial_project_settings_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/initial_local_settings.json")
}

pub fn initial_tasks_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/initial_tasks.json")
}

pub fn initial_debug_tasks_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/initial_debug_tasks.json")
}

pub fn initial_local_debug_tasks_content() -> Cow<'static, str> {
    asset_str::<SettingsAssets>("settings/initial_local_debug_tasks.json")
}
```

Sekiz fonksiyon iki anlam grubuna ayrılır:

| Grup | Dosya | Anlamı |
|------|-------|--------|
| **Default** | `default.json`, `default_semantic_token_rules.json` | Çalışma zamanında varsayılan değer kaynağı; her settings okumasında yedek olarak kullanılır |
| **Initial** | `initial_user_settings.json`, `initial_server_settings.json`, `initial_local_settings.json`, `initial_tasks.json`, `initial_debug_tasks.json`, `initial_local_debug_tasks.json` | Kullanıcı dosyası ilk kez oluşturulurken diske yazılan şablon içerik |

**Default ve Initial farkı:** Default dosyalar `SettingsStore`'a varsayılan değer enjekte eder; her settings çağrısı bu değerleri okur. Initial dosyalar yalnızca yeni kullanıcı kurulumunda kullanılır; mevcut bir kullanıcı dosyası varsa initial dosyalara dokunulmaz.

Bu ayrım önemli bir tasarım kararıdır: varsayılan değerin değişmesi tüm kullanıcıları etkiler (binary güncelleyince); initial dosyanın değişmesi yalnızca yeni kullanıcılar üzerinden görünür. Bir ayar varsayılanının değiştirilmesi geri uyumluluk değerlendirmesi gerektirir; initial dosyasının değişmesi ise yalnızca ilk karşılama deneyimini etkiler.

### 4.1 `SettingsStore` ve varsayılan değer enjeksiyonu

`settings` crate'indeki `init`:

```rust
pub fn init(cx: &mut App) {
    let ayarlar = SettingsStore::new(cx, &default_settings());
    cx.set_global(ayarlar);
    SettingsStore::observe_active_settings_profile_name(cx).detach();
}
```

`SettingsStore::new` çağrısı `default_settings()` çıktısını (yani `settings/default.json` içeriği) ayrıştırır ve ayarların başlangıç değerlerini bu içerikten çıkarır. Kullanıcı dosyaları sonradan yüklendiğinde bu varsayılan değerlerin üzerine yazılır.

Önemli ayrıntı: `default_settings()` çağrısı **panic atabilir**. `asset_str::<SettingsAssets>` içindeki varlık okuma kontratı dosya yoksa panik atar. Yani settings sisteminin başlatılması, varsayılan JSON dosyasının `SettingsAssets` erişim kümesinde bulunmasına sıkı sıkıya bağlıdır. Bu kasıtlı bir sertliktir: settings olmadan Zed başlatılamaz, fail-fast davranışı kabul edilir.

---

## 5. İki RustEmbed yolu karşılaştırması

JSON varlıklarının üç farklı yoldan tüketildiği görülüyor:

| Varlık | Yol | `cx.asset_source()` mu? | Kuruluş sırası |
|--------|-----|------------------------|----------------|
| Tema JSON'ları | `cx.asset_source().list/load` | Evet | `App` çalışma zamanı kurulduktan sonra |
| Keymap JSON'ları | `asset_str::<SettingsAssets>` | Hayır (RustEmbed::get) | `App` kurulmadan önce de çağrılabilir |
| Settings JSON'ları | `asset_str::<SettingsAssets>` | Hayır | `App` kurulmadan önce de çağrılabilir |
| Badge JSON | - | Hayır (çalışma zamanında okunmaz) | - |

İki yolun pratikteki anlamı:

- **`cx.asset_source()` yolu (`Assets`)** dinamiktir: çalışma zamanında değiştirilebilir, test ortamında sahte kaynakla çalışabilir (`Arc::new(()) as Arc<dyn AssetSource>`), dosya sistemi yolu ile yer değiştirebilir.
- **`SettingsAssets::get` yolu** statiktir: derleme zamanında sabit, çalışma zamanında sahte kaynakla çalışamaz. Bu, settings ve keymap'in temel uygulama sözleşmesinin parçası olduğunu söyler; testte bile farklı varsayılanlarla çalışmak istenirse parametre olarak geçersiz kılma geçirmek gerekir.

**Yeni JSON varlık eklerken karar:** Eğer varlık çalışma zamanında değişebiliyorsa (tema gibi: kullanıcı geçersiz kılar, extension ekler) `Assets` yolu kullanırsın. Eğer varlık derleme zamanında sabit ve uygulamanın temel sözleşmesinin parçasıysa (settings varsayılanı, keymap tabanı) `SettingsAssets` yolu seçersin. İkinci yol, çalışma zamanında sahte kaynakla çalışmayı zorlaştırdığı için daha "katı" bir sözleşmedir.

---

## 6. `badge/v0.json` ve çalışma zamanı dışı tüketim

`assets/badge/v0.json` `RustEmbed` include kalıplarında yer almaz; ne `Assets` ne `SettingsAssets` bu dosyayı binary'ye gömer. Tüketicisi tamamen dışsaldır: README.md'deki shields.io rozeti bu JSON'u GitHub raw URL'inden çeker ve "Zed" yazılı bir rozet oluşturur.

Bu dosyanın varlık klasöründe durmasının iki gerekçesi vardır:

1. **Versiyonlama:** `v0.json` adı, ileride badge formatı değişirse `v1.json` eklenerek geriye uyumluluğun korunabileceğini gösterir. Eski README rozetleri eski formatı okumaya devam eder.
2. **Sahiplik:** `assets/` klasörü görsel sözleşmenin merkezi olduğundan, projeyi temsil eden bir badge dosyasının da burada durması anlamlıdır. `.github/` klasörüne konulabilirdi ama görsel kimlik açısından `assets/badge/` daha keşfedilebilir.

**Sonuç:** Varlık klasörü her dosyanın çalışma zamanı tüketicisi olduğu varsayımı yanlıştır. Yeni bir dosya eklerken include kalıplarını bilinçli yönetmek, binary boyutunu ve çalışma zamanı sözleşmesini koruma altına alır.

---

## 7. JSON tüketimi karşılaştırma tablosu

JSON varlık türlerinin tüketim profillerini özetlemek gerekirse:

| Varlık türü | Tüketici | Yükleme zamanı | Format | Geçersiz kılma mekanizması |
|-------------|----------|----------------|--------|---------------------|
| Tema | `ThemeRegistry` | Uygulama başlatma (eager) | `serde_json` ile `ThemeFamilyContent` | `~/.config/zed/themes/*.json` |
| Default keymap | `KeymapFile::load_settings_file` | Uygulama başlatma | Özel keymap ayrıştırıcısı | `~/.config/zed/keymap.json` |
| Base keymap (Atom/JetBrains/...) | Kullanıcı seçimi sonrası | Setting değişimi anında | Özel keymap ayrıştırıcısı | Yok (sabit dosya) |
| Default settings | `SettingsStore::new` | Uygulama başlatma | `serde_json` ile `SettingsContent` | `~/.config/zed/settings.json` |
| Initial settings | İlk kurulum | Diske yazılır | Salt metin | - (yeni kullanıcı oluşumunda kullanılır) |
| Badge | Çalışma zamanı yok | - | - | - |

Üç desen göze çarpar:

- **Binary + dosya sistemi geçersiz kılması** (tema, keymap, settings): Binary varsayılanları taşır, kullanıcı dosyaları geçersiz kılar. Üçü için de aynı kural geçerlidir: dosya yoksa varsayılandan okunur.
- **Initial dosya yalnızca ilk karşılama** (initial_*.json): Yeni kullanıcı için diske yazılır; sonradan binary güncellense de mevcut kullanıcı dosyası değişmez.
- **Çalışma zamanı dışı varlık** (badge): Binary'ye girmez, sadece klasörde durur.

---

## 8. Yeni JSON varlık eklerken karar ağacı

Yeni bir JSON dosyası eklenmesi gerektiğinde aşağıdaki sorular sırayla cevaplanır:

```text
1. Çalışma zamanında okunacak mı?
   ├── Hayır → assets/ altına koy, include kalıplarında yer verme (badge gibi)
   └── Evet ↓

2. Çalışma zamanında değişebilir mi (kullanıcı geçersiz kılma, extension)?
   ├── Evet → Assets struct'ı + cx.asset_source().load (tema gibi)
   └── Hayır ↓

3. App kurulmadan önce okunması gerekiyor mu?
   ├── Evet → SettingsAssets struct'ı + asset_str (settings, keymap gibi)
   └── Hayır → Assets struct'ı + cx.asset_source().load
```

Üç noktada karar vermen gerekir:

- **Tüketim yolu (Assets vs SettingsAssets):** Eğer dosya `App` çalışma zamanı kurulmadan okunacaksa veya başlatma sırasında erken çağrılan bir bileşen tarafından okunacaksa `SettingsAssets` tercih edersin. Aksi halde `Assets` daha esnektir (testte sahte kaynakla çalışabilir).
- **Ayrıştırma stratejisi:** Eğer dosya bir struct'a deserialize edilecekse `serde_json::from_slice` kullanırsın. Eğer dosya UTF-8 string olarak okunup özel bir ayrıştırıcıya verilecekse `asset_str` daha doğrudur (string dönüşümünü kendi içinde yapar).
- **Geçersiz kılma stratejisi:** Eğer kullanıcı dosyayı geçersiz kılabilmeliyse dosya sistemi izleyicisi kurulur veya `cx.spawn` ile asenkron yükleme yolu eklenir; aksi halde binary içeriği tek otoritedir.

Bu karar ağacı, JSON varlıklarının tüketim hattını seçerken üç boyutu birden değerlendirir: erişim zamanı, esneklik ve geçersiz kılma gereksinimi.

---
