# JSON varlıkları: tema, keymap, settings, badge

Bu bölüm, varlık altyapısının yapılandırılmış varlık katmanını ele almaktadır. JSON dosyaları binary ile birlikte taşınır; fakat tüketim biçimleri birbirinden farklılık gösterir:

- Tema JSON dosyaları çalışma zamanında bir sicile (registry) dahil edilir.
- Keymap JSON dosyaları kullanıcı tercihlerine göre seçilip ayrıştırılır.
- Settings JSON dosyaları varsayılan değer kaynağı olarak okunur.
- Badge JSON dosyası ise çalışma zamanında hiç tüketilmez.

Bu dört farklı yolun birlikte ele alınması, 'neden tüm JSON dosyaları aynı tüketim hattından geçmiyor?' sorusunu yanıtlar. Ayrıca yeni bir JSON tabanlı varlık eklenirken hangi modelin tercih edileceğini netleştirir.

![JSON Varlık Tüketim Yolları](images/json-varlik-yollari.svg)

---

## 1. JSON varlıklarının topolojisi

JSON dosyaları üç klasör altında dağılmıştır:

```text
assets/
├── themes/
│   ├── one/
│   │   ├── one.json          # 2 tema (One Dark, One Light)
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

Tema sistemi `cx.asset_source()` üzerinden okuma yapar (yani `Assets` struct yapısı çalışma zamanına `with_assets` ile bağlandıktan sonra erişilebilir hale gelir). Keymap ve settings dosyaları ise doğrudan `SettingsAssets::get` üzerinden senkron olarak okunur. Bu sayede `App` çalışma zamanı henüz kurulmadan bile çağrı yapılabilir. Bu ayrım, varlık altyapısının kuruluş sırasındaki en kritik kararlardan biridir ve sonraki bölümlerde örneklendirilecektir.

---

## 2. Tema JSON'larının akışı

Tema JSON'larının yüklenmesi `theme_settings` crate'i içerisindeki `load_bundled_themes` fonksiyonu vasıtasıyla yürütülür:

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
3. **`assets().load(&yol)` çağrısı:** Her tema dosyası ham byte olarak yüklenir. `log_err().flatten()` deseni, hata durumlarında hatayı günlüğe (log'a) yansıtır ve `None` döndürür; aksi takdirde elde edilen `Some(baytlar)` ile sürece devam edilir.
4. **`serde_json::from_slice`** — Baytlar `ThemeFamilyContent` struct'ına ayrıştırılır. Bu struct Zed tema JSON sözleşmesini yansıtır; kendisi yalnızca `name`, `author` ve `themes` alanlarını taşır. Renk alanları ise iç içe yapıda durur: her tema `ThemeContent` içinde bir `ThemeStyleContent` tutar, o da `ThemeColorsContent` ile durum renklerini barındırır ve bu alanların her biri `Option<String>` olduğu için eksik renkler atlanabilir.
5. **`refine_theme_family`:** `Content` → `Refinement` → `Theme` dönüşümlerini uygular. Bu adım tema sistemi bölümünde detaylandırılmıştır; özetle: kullanıcı temasındaki eksik alanlar yedek varsayılan değerlerle doldurulur ve çalışma zamanında kullanıma hazır hale getirilmiş bir `Theme` struct yapısı üretilir.
6. **`kayit.insert_theme_families`** — Hazır tema ailesi `ThemeRegistry`'ye eklenir; `cx.theme()` artık bu temaya erişebilir.

**Hata toleransı:** Bozuk bir tema dosyası tüm uygulamayı durdurmaz. Ayrıştırma hatası `log_err()` ile log'a düşer, `continue` ile bir sonraki temaya geçilir. Bu davranış kullanıcı sürtüşmesini azaltır: bir tema dosyası bozuksa kullanıcı yalnızca o temaya erişemez, kalan tema seçimleri çalışmaya devam eder.

### 2.1 `LoadThemes` kademeleri ve varlık bağımlılığı

Tema sistemini başlatan `theme::init`, `LoadThemes` parametresine göre iki farklı varlık davranışı seçer:

```rust
pub enum LoadThemes {
    /// Sadece yedek tema yüklenir; kullanıcı temaları yüklenmez.
    JustBase,
    /// Tüm gömülü temalar yüklenir.
    All(Box<dyn AssetSource>),
}

// theme::init
pub fn init(yuklenecek_temalar: LoadThemes, cx: &mut App) {
    SystemAppearance::init(cx);
    let varliklar = match yuklenecek_temalar {
        LoadThemes::JustBase => Box::new(()) as Box<dyn AssetSource>,
        LoadThemes::All(varliklar) => varliklar,
    };
    ThemeRegistry::set_global(varliklar, cx);
    FontFamilyCache::init_global(cx);
}
```

`JustBase` modu test ortamları için kritiktir: bu modda `theme::init` işlevi kaydı (registry) boş `()` `AssetSource` ile kurar ve kayıt yalnızca yedek varsayılan temayla sınırlı kalır. Asıl önemli ayrım ise üst katmandadır: gömülü temaları yükleyen `load_bundled_themes` çağrısını `theme::init` değil, onu saran `theme_settings::init` işlevi yapar ve bu çağrıyı yalnızca `LoadThemes::All` seçeneği geldiğinde tetikler. `JustBase` modunda `load_bundled_themes` tamamen atlanır; bu sayede tema JSON dosyaları bulunmayan bir test ortamı da sorunsuz şekilde çalışabilir.

`All(varliklar)` modu ise üretim (production) ortamı için tercih edilir. Burada `Box<dyn AssetSource>` parametresi `Assets` struct yapısından bir değer talep eder; `Assets` struct yapısı de tema klasörünü dahil eder (yukarıdaki `#[include = "themes/**/*"]` direktifi). Bu modda `theme_settings::init` işlevi `theme::init`'in ardından `load_bundled_themes` fonksiyonunu çağırarak gömülü temaları sicile ekler.

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
            // load_user_theme(kayit, &baytlar) ile kayda eklenir
        }
    })
}
```

Dosya sisteminden okuma işlemi asenkron olarak yürütülür; binary içerisindeki tema yükleme süreci ise senkron bir `list+load` döngüsüdür. Her iki yol birleştiğinde aynı `ThemeRegistry` yapısına akar ve dışarıdan herhangi bir fark gözlemlenmez. Bu durum, 'binary'deki varlık + dosya sistemi geçersiz kılması' deseninin tema sistemindeki somut karşılığıdır.

Bu iki yolun ayrıştırma katmanında de ince bir fark mevcuttur: `load_user_theme` kullanıcı temasını `serde_json_lenient` ile okur; böylece yorum satırları içeren ve sondaki virgülleri hoş gören kullanıcı dosyaları da sorunsuzca kabul edilebilir. Gömülü temalar ise `load_bundled_themes` içinde standart `serde_json` ile ayrıştırılır; nitekim binary içerisine paketlenen dosyaların zaten katı JSON formatında olması beklenir.

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

- **`cfg` ile platform seçimi:** Derleme zamanında hedef platforma göre `DEFAULT_KEYMAP_PATH` farklı bir dosya yoluna atanır. Örneğin macOS binary'si yalnızca `keymaps/default-macos.json` yolunu kullanır; diğer platform varyantları release paketinin içinde yer alsa dahi onlara giden bir çağrı yolu bulunmaz. Pratikte üç dosya da `SettingsAssets` erişim kümesinde yer alır (`keymaps/*` include kalıbı ile), ama çalışma zamanı yalnızca aktif platforma uygun olanı okur.
- **`asset_str::<SettingsAssets>` çağrısı.** `util::asset_str` jenerik bir yardımcıdır:

  ```rust
  pub fn asset_str<A: rust_embed::RustEmbed>(yol: &str) -> Cow<'static, str> {
      match A::get(yol)?.data {
          Cow::Borrowed(baytlar) => Cow::Borrowed(std::str::from_utf8(baytlar)?),
          Cow::Owned(baytlar) => Cow::Owned(String::from_utf8(baytlar)?),
      }
  }
  ```

  Bu fonksiyon doğrudan `RustEmbed::get` çağrısını tetikler (yani `cx.asset_source()` arayüzünden bağımsızdır), byte verilerini UTF-8 string formatına dönüştürür ve `Cow<'static, str>` döner. Bu yapı sayesinde keymap ve settings dosyaları `App` çalışma zamanı kurulmadan önce de okunabilir; bu durum özellikle erken kuruluş aşamasında settings store'a varsayılan değerlerin enjekte edilmesi için kritik önem taşır.

- **Sert paketleme sözleşmesi:** `A::get(yol)` metodu `None` döndürdüğünde kaynak kod yapısı fail-fast (erken durdurma) davranış sergiler. Bu, keymap dosyalarının `SettingsAssets` erişim kümesinde mutlaka bulunması gerektiğini şart koşan bir paketleme varsayımıdır. Dosya silindiğinde veya `#[include]` filtresi uyumsuz kaldığında, uygulama başlatma esnasında erken durma (panic) yaşanır; bu durumun dağıtım öncesi doğrulama testlerinde yakalanması hedeflenir.

Burada küçük ama önemli bir paketleme detayı mevcuttur: `SettingsAssets` kaynak kodunda `#[include = "keymaps/*"]` şeklinde tanımlanmış olmasına karşın, tüketilen yollar `keymaps/macos/atom.json` ve `keymaps/linux/jetbrains.json` gibi alt dizinlerdedir. Bunun sebebi `rust-embed` 8.11 sürümündeki `include-exclude` özelliğinde kullanılan `globset` varsayılanlarının `*` karakterini yol ayırıcısını da eşleyebilecek şekilde değerlendirmesidir. Dolayısıyla Zed'in mevcut kalıbı alt paketleri de kapsar; yine de bu kalıp değiştirilirken kök `keymaps/*.json` dosyalarının yanı sıra platform alt paketlerinin de gömülü kaldığını mutlaka doğrulaman gerekir. Daha açık bir ifade hedefleniyorsa `keymaps/**/*` kalıbını kullanman önerilir.

### 3.1 Platforma özgü editör keymap paketleri

`assets/keymaps/macos/` ve `assets/keymaps/linux/` altında editör emülasyon dosyaları yer alır (`atom.json`, `cursor.json`, `emacs.json`, `jetbrains.json`, `sublime_text.json`, `textmate.json`). Bu dosyalar `BaseKeymap` enum yapısı üzerinden seçilir:

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

Keymap seçimi `BaseKeymap` ayarından okunur, `BaseKeymap::asset_path` yardımıyla dosya yolu elde edilir, `SettingsAssets` üzerinden içerik okunur ve varsayılan keymap'in üzerine enjekte edilir. Bu zincir, kullanıcı tercihlerinin varlık hattına nasıl bağlandığını net bir şekilde gösterir.

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
| **Initial settings/tasks** | `initial_user_settings.json`, `initial_server_settings.json`, `initial_local_settings.json`, `initial_tasks.json`, `initial_debug_tasks.json`, `initial_local_debug_tasks.json` | Kullanıcı dosyası ilk kez oluşturulurken diske yazılan şablon içerik |
| **Initial keymap** | `keymaps/initial.json` | Kullanıcı keymap dosyası ilk kez oluşturulurken diske yazılan şablon içerik |

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

Önemli ayrıntı: `default_settings()` çağrısı fail-fast paketleme sözleşmesine tabidir. `asset_str::<SettingsAssets>` içindeki varlık okuma sözleşmesi, dosya mevcut değilse süreci erken durdurur. Yani settings sisteminin başlatılabilmesi, varsayılan JSON dosyasının `SettingsAssets` erişim kümesinde bulunmasına sıkı sıkıya bağlıdır. Bu bilinçli bir sertliktir: settings dosyası olmadan uygulama başlatılamaz, bu nedenle fail-fast davranışı kabul edilir.

---

## 5. İki RustEmbed yolu karşılaştırması

JSON varlıklarının üç farklı yoldan tüketildiği görülüyor:

| Varlık | Yol | `cx.asset_source()` mu? | Kuruluş sırası |
|--------|-----|------------------------|----------------|
| Tema JSON'ları | `cx.asset_source().list/load` | Evet | `App` çalışma zamanı kurulduktan sonra |
| Keymap JSON'ları | `asset_str::<SettingsAssets>` | Hayır (RustEmbed::get) | `App` kurulmadan önce भी çağrılabilir |
| Settings JSON'ları | `asset_str::<SettingsAssets>` | Hayır | `App` kurulmadan önce de çağrılabilir |
| Badge JSON | - | Hayır (çalışma zamanında okunmaz) | - |

İki yolun pratikteki anlamı:

- **`cx.asset_source()` yolu (`Assets`)** dinamiktir: çalışma zamanında değiştirilebilir, test ortamında sahte kaynakla çalışabilir (`Arc::new(()) as Arc<dyn AssetSource>`), dosya sistemi yolu ile yer değiştirebilir.
- **`SettingsAssets::get` yolu** statiktir: derleme zamanında sabitlenmiştir ve çalışma zamanında sahte bir kaynakla ikame edilemez. Bu durum, settings ve keymap dosyalarının uygulamanın temel sözleşmesinin bir parçası olduğunu gösterir; test ortamlarında bile farklı varsayılanlarla çalışmak istendiğinde parametre olarak geçersiz kılma (override) değerlerinin geçilmesi gerekir.

**Yeni JSON varlığı eklerken karar:** Eğer varlık çalışma zamanında dinamik olarak değişebiliyorsa (kullanıcının geçersiz kılması veya eklentilerle tema eklenmesi gibi) `Assets` yolu tercih edilir. Eğer varlık derleme zamanında sabitlenmiş ve uygulamanın temel sözleşmesinin bir parçası ise (varsayılan ayarlar veya temel keymap tabanı gibi) `SettingsAssets` yolu seçilir. İkinci yol, çalışma zamanında sahte kaynakla çalışmayı sınırladığı için daha 'katı' bir sözleşmedir.

---

## 6. `badge/v0.json` ve çalışma zamanı dışı tüketim

`assets/badge/v0.json` `RustEmbed` include kalıplarında yer almaz; ne `Assets` ne `SettingsAssets` bu dosyayı binary'ye gömer. Tüketicisi tamamen dışsaldır: README.md'deki shields.io rozeti bu JSON'u GitHub raw URL'inden çeker ve "Zed" yazılı bir rozet oluşturur.

Bu dosyanın varlık klasöründe durmasının iki gerekçesi vardır:

1. **Versiyonlama:** `v0.json` adı, ileride badge formatı değişirse `v1.json` eklenerek geriye uyumluluğun korunabileceğini gösterir. Eski README rozetleri eski formatı okumaya devam eder.
2. **Sahiplik:** `assets/` klasörü görsel sözleşmenin merkezi olduğundan, projeyi temsil eden bir badge dosyasının da burada durması anlamlıdır. `.github/` klasörüne konulabilirdi ama görsel kimlik açısından `assets/badge/` daha keşfedilebilir.

**Sonuç:** Varlık klasöründeki her dosyanın çalışma zamanı tüketicisi yoktur. Yeni bir dosya eklerken include kalıplarını bilinçli yönetmek, binary boyutunu ve çalışma zamanı sözleşmesini koruma altına alır.

---

## 7. JSON tüketimi karşılaştırma tablosu

JSON varlık türlerinin tüketim profillerini özetlemek gerekirse:

| Varlık türü | Tüketici | Yükleme zamanı | Format | Geçersiz kılma mekanizması |
|-------------|----------|----------------|--------|---------------------|
| Tema | `ThemeRegistry` | Uygulama başlatma (eager) | `serde_json` ile `ThemeFamilyContent` | `~/.config/zed/themes/*.json` |
| Default keymap | `KeymapFile::load_asset` | Uygulama başlatma | Özel keymap ayrıştırıcısı | `~/.config/zed/keymap.json` |
| Base keymap (Atom/JetBrains/...) | `KeymapFile::load_asset` (kullanıcı seçimi sonrası) | Setting değişimi anında | Özel keymap ayrıştırıcısı | Yok (sabit dosya) |
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

Burada üç temel noktada karar vermen gerekir:

- **Tüketim yolu (Assets vs SettingsAssets):** Eğer dosya `App` çalışma zamanı kurulmadan önce okunacaksa veya başlatma esnasında erken çağrılan bir bileşen tarafından talep edilecekse `SettingsAssets` kullanmayı tercih etmen gerekir. Aksi takdirde `Assets` yapısı daha esnektir (test ortamında sahte kaynakla çalışabilir).
- **Ayrıştırma stratejisi:** Eğer dosya bir struct yapısına deserialize edilecekse `serde_json::from_slice` kullanman gerekir. Eğer dosya UTF-8 string olarak okunup özel bir ayrıştırıcıya (parser) verilecekse `asset_str` kullanman daha doğrudur (string dönüşümünü kendi içinde gerçekleştirir).
- **Geçersiz kılma stratejisi:** Eğer kullanıcının dosyayı geçersiz kılması hedefleniyorsa dosya sistemi izleyicisi (file watcher) kurman veya `cx.spawn` ile asenkron yükleme yolu entegre etmen gerekir; aksi durumda binary içeriğini tek otorite kabul etmen gerekir.

Bu karar ağacı, JSON varlıklarının tüketim hattını seçerken üç boyutu birden değerlendirir: erişim zamanı, esneklik ve geçersiz kılma gereksinimi.

---
