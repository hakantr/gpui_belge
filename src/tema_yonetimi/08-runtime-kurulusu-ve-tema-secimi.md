# Runtime kuruluşu ve tema seçimi

Üretilen temalar önce registry'ye ve global state'e yerleştirilir. Ardından sistem görünümü izlenir ve tema değiştiğinde pencereler yenilenir. Bu bölüm bu akışı sırayla anlatır: tema nerede tutulur, aktif tema nasıl seçilir ve UI yeni renkleri nasıl görür?

---

## 33. `ThemeRegistry`: API yüzeyi ve thread safety

**Kaynak modül:** `kvs_tema/src/registry.rs`.

Yüklü UI temalarının ve icon temalarının ad bazlı kataloğunu tutar. Thread-safe okuma/yazma erişimi sunar; runtime'ın tek "tema veritabanı" gibi çalışır.

### Yapı

```rust
use parking_lot::RwLock;
use std::sync::Arc;
use collections::HashMap;
use gpui::{AssetSource, SharedString};

#[derive(Debug, Clone)]
pub struct ThemeMeta {
    pub name: SharedString,
    pub appearance: Appearance,
}

struct ThemeRegistryState {
    themes: HashMap<SharedString, Arc<Theme>>,
    icon_themes: HashMap<SharedString, Arc<IconTheme>>,
    extensions_loaded: bool,
}

pub struct ThemeRegistry {
    state: RwLock<ThemeRegistryState>,
    assets: Box<dyn AssetSource>,
}
```

**Sarmalama katmanları:**

1. **`Arc<Theme>` / `Arc<IconTheme>`** — Her tema paylaşılabilir; klonu ucuzdur (yalnızca refcount artışı). Zed paritesinde `cx.theme()` ve `GlobalTheme::icon_theme(cx)` çağrıları `&Arc<_>` döndürür.
2. **`HashMap<SharedString, _>`** — Ad bazlı O(1) lookup. `SharedString` key olarak kullanılır (Bölüm III/Konu 7); klonsuz hash'leme yapar.
3. **`RwLock<...>`** — Çoklu okuyucu, tek yazıcı. Tema okuma sıktır (render path), yazma ise nadirdir (init + reload).
4. **`AssetSource`** — Built-in tema ve icon theme asset'lerini aynı registry üzerinden listeler ve yükler; production bundling ile uyumlu çalışır.

> **Neden `parking_lot::RwLock`?** `std::sync::RwLock` daha yavaş ve daha büyüktür. Ayrıca panic sonrası poison davranışı zorunlu `unwrap` çağrılarına yol açar. `parking_lot::RwLock`:
> - Yaklaşık 2× daha hızlı kilit-açma sağlar.
> - Daha küçük bir bellek ayak izi taşır.
> - Poison kavramı yoktur — panic sonrası bile lock kullanılmaya devam edebilir.
> - `read()` ve `write()` doğrudan guard döndürür; `unwrap()` çağrısına ihtiyaç bırakmaz.

### Hata tipleri

**Zed kaynak sözleşmesi** (`crates/theme/src/registry.rs:27`, `:32`): hata tipi adları `ThemeNotFoundError` ve `IconThemeNotFoundError` biçimindedir. Sonda `Error` suffix'i bulunur. `kvs_tema` mirror'ında da aynı isimler kullanılır:

```rust
use thiserror::Error;

#[derive(Debug, Error)]
#[error("tema bulunamadı: {0}")]
pub struct ThemeNotFoundError(pub SharedString);

#[derive(Debug, Error)]
#[error("icon tema bulunamadı: {0}")]
pub struct IconThemeNotFoundError(pub SharedString);
```

- `thiserror` makrosu `Display + std::error::Error` türevlerini ücretsiz olarak üretir.
- Tek alanlı newtype — hata mesajı `"tema bulunamadı: Kvs Default Dark"` biçiminde okunur.
- Hata propagation kolaydır: `?` operatörü ile `anyhow::Result<...>` veya başka bir error chain'e dönüştürülebilir.

> **İsim sözleşmesi:** Zed pariteli hata adları `Error` suffix'i taşır: `ThemeNotFoundError` ve `IconThemeNotFoundError`.

### Global wrapper

```rust
#[derive(Default)]
struct GlobalThemeRegistry(Arc<ThemeRegistry>);
impl Global for GlobalThemeRegistry {}
```

`Arc<ThemeRegistry>`'yi `App` global'i yapmak için bir newtype kullanılır (Bölüm III/Konu 10). `Arc<ThemeRegistry>`'yi doğrudan global yapmak iki nedenle uygun değildir:

- `Arc<T>` zaten `'static + Send + Sync` özelliklerini taşır; ancak global key olarak `Arc` kullanmak başka kodlarla, örneğin başka bir `Arc<ThemeRegistry>` tutan kodla çakışma yaratır.
- Newtype, bu özel registry'nin **kendine ait bir global anahtarına** sahip olduğunu garanti altına alır.

### Public API yüzeyi

Zed'in `crates/theme/src/registry.rs` dosyasındaki public yüzeye paraleldir. Üç önemli davranış farkı yorum satırlarında belirtilmiştir:

```rust
impl ThemeRegistry {
    // KONSTRUKTOR: tek imza, AssetSource ZORUNLU.
    // `ThemeRegistry::new()` (argümansız) yok; testte
    // `Box::new(()) as Box<dyn AssetSource>` geçirilir.
    pub fn new(assets: Box<dyn AssetSource>) -> Self;

    pub fn global(cx: &App) -> Arc<Self>;
    pub fn default_global(cx: &mut App) -> Arc<Self>;
    pub fn try_global(cx: &mut App) -> Option<Arc<Self>>;

    // `set_global` Zed'de `pub(crate)`; `init()` içinde çağrılır.
    // Tüketici doğrudan değiştiremez — global'i kurmak için
    // `init(LoadThemes::..., cx)` kullanılır (Konu 36).
    pub(crate) fn set_global(assets: Box<dyn AssetSource>, cx: &mut App);

    pub fn assets(&self) -> &dyn AssetSource;

    // TEK TEK Theme insert eden public API YOK.
    // Tek bir tema yüklemek için tek elemanlı koleksiyon geçirilir:
    //   registry.insert_themes([theme]);
    pub fn insert_theme_families(&self, families: impl IntoIterator<Item = ThemeFamily>);
    pub fn insert_themes(&self, themes: impl IntoIterator<Item = Theme>);
    pub fn remove_user_themes(&self, names: &[SharedString]);
    pub fn clear(&self);
    pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError>;
    pub fn list_names(&self) -> Vec<SharedString>;
    pub fn list(&self) -> Vec<ThemeMeta>;

    // Tek tek IconTheme insert eden public API DA YOK.
    // `load_icon_theme(family, root_dir)` aileden ekler;
    // `register_test_icon_themes` test-only kullanılır.
    pub fn get_icon_theme(&self, name: &str) -> Result<Arc<IconTheme>, IconThemeNotFoundError>;
    pub fn default_icon_theme(&self) -> Result<Arc<IconTheme>, IconThemeNotFoundError>;
    pub fn list_icon_themes(&self) -> Vec<ThemeMeta>;
    pub fn remove_icon_themes(&self, names: &[SharedString]);
    pub fn load_icon_theme(
        &self,
        family: IconThemeFamilyContent,
        icons_root_dir: &Path,
    ) -> anyhow::Result<()>;

    pub fn extensions_loaded(&self) -> bool;
    pub fn set_extensions_loaded(&self);

    #[cfg(any(test, feature = "test-support"))]
    pub fn register_test_themes(&self, families: impl IntoIterator<Item = ThemeFamily>);
    #[cfg(any(test, feature = "test-support"))]
    pub fn register_test_icon_themes(&self, icon_themes: impl IntoIterator<Item = IconTheme>);
}
```

> **`ThemeRegistry::new` davranış notu:** Yapıcı kendi içinde `insert_theme_families([zed_default_themes()])` çağrısı yapar ve default icon theme'i de ekler. Yani `new`'den dönen registry hiçbir zaman tamamen boş değildir. Mirror tarafta `kvs_default_themes()` ailesinin otomatik yüklenmesi beklenir.

**Her metodun davranışı:**

| Metot | İmza | Davranış | Lock |
|--------|------|----------|------|
| `new` | `(assets: Box<dyn AssetSource>) -> Self` | `zed_default_themes()` ailesini ve default icon tema'yı yükleyerek registry kurar; asset zorunlu | Yok |
| `global` | `(cx: &App) -> Arc<Self>` | Aktif registry'yi döndürür; yoksa **panic** | App global okuma |
| `default_global` | `(cx: &mut App) -> Arc<Self>` | Yoksa default bir registry kurar ve döndürür | App global yazma |
| `try_global` | `(cx: &mut App) -> Option<Arc<Self>>` | Init edilmemişse `None` | App global okuma |
| `set_global` | `(assets, cx) -> ()` — `pub(crate)` | `init(...)` çağrısı içinden global'i kurar; tüketici çağıramaz | App global yazma |
| `insert_themes` | `(&self, themes)` | Her temayı `name` key'i ile ekler; aynı isimde varsa **üzerine yazar** | Write |
| `insert_theme_families` | `(&self, families)` | Ailelerdeki tüm temaları `insert_themes` ile ekler | Write |
| `remove_user_themes` | `(&self, names)` | Verilen ad listesindeki temaları kaldırır | Write |
| `clear` | `(&self)` | Tüm UI temalarını siler (icon temalar etkilenmez) | Write |
| `get` | `(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError>` | Tema'yı klonlar (Arc); yoksa hata döndürür | Read |
| `list_names` | `(&self) -> Vec<SharedString>` | Tüm tema adlarını sıralı liste olarak döndürür | Read |
| `list` | `(&self) -> Vec<ThemeMeta>` | Selector için ad + appearance metadata'sı döndürür | Read |
| `get_icon_theme` | `(&self, name)` | Icon tema lookup | Read |
| `default_icon_theme` | `(&self)` | Default icon tema; yoksa `IconThemeNotFoundError` | Read |
| `list_icon_themes` | `(&self) -> Vec<ThemeMeta>` | Icon selector için metadata | Read |
| `load_icon_theme` | `(family, root)` | Icon path'lerini root'a göre çözerek ekler | Write |
| `extensions_loaded` | `() -> bool` | Extension temaları yüklendi mi bilgisini taşır | Read |
| `register_test_themes` / `register_test_icon_themes` | `(&self, ...)` — `#[cfg(test-support)]` | Test feature'ı altında family/icon kayıtları | Write |

### Davranış detayları

**`insert_themes` üzerine yazma:**

```rust
pub fn insert_themes(&self, themes: impl IntoIterator<Item = Theme>) {
    let mut state = self.state.write();
    for theme in themes.into_iter() {
        state.themes.insert(theme.name.clone(), Arc::new(theme));
    }
}
```

`HashMap::insert` aynı key bulunduğunda eski değeri **drop eder**. Kullanıcı aynı "My Theme" adıyla iki tema yüklediğinde ikincisi birincinin yerini alır. Bu davranış **kasıtlıdır**; kullanıcının aynı adla yeniden yükleyerek temayı güncellemesi bu yolla karşılanır.

> Tek bir tema yüklemek gerektiğinde tek elemanlı bir koleksiyon geçirilir: `registry.insert_themes([theme]);` veya `registry.insert_themes(std::iter::once(theme));`. Zed'de tek tema eklemek için ayrı bir `insert(theme)` metodu bulunmaz.

**`get` clone semantiği:**

```rust
pub fn get(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError> {
    self.state
        .read()
        .themes
        .get(name)
        .cloned()    // Arc<Theme> → ucuz klon
        .ok_or_else(|| ThemeNotFoundError(name.to_string().into()))
}
```

`cloned()` çağrısı `Arc<Theme>`'i klonlar; yalnızca refcount artar. Caller kendi `Arc<Theme>` örneğine sahip olur, registry'nin storage'ı ondan bağımsız kalır.

**`list_names` sıralama:**

```rust
pub fn list_names(&self) -> Vec<SharedString> {
    let mut names: Vec<_> = self.state.read().themes.keys().cloned().collect();
    names.sort();
    names
}
```

`HashMap` sırasızdır; `sort()` deterministik bir liste sunar. UI'da tema seçici dropdown'u alfabetik görünür. Picker veya selector adın yanında appearance da gösterecekse `list()` çağrısı tercih edilir.

### Thread safety semantiği

- `&ThemeRegistry`'den (paylaşımlı erişimden) hem **okunabilir hem de yazılabilir**. `RwLock` iç-mutabilite sağladığı için `insert` çağrısı bile `&self` ile mümkündür.
- `Arc<ThemeRegistry>` **`Send + Sync`**'tir; çünkü `RwLock` iki özelliği de garanti eder.
- Lock hold süresi minimaldir — `insert`/`get` çağrısı tek bir HashMap operasyonundan ibarettir. Race condition oluşmaz.

> **Kilit zinciri uyarısı:** `registry.read()` guard'ı tutulurken başka bir kilide girilmesi, örneğin `GlobalTheme` güncellenmesi, **deadlock riski** doğurur. Tema değişiminde önce `registry.get()` çağrılır, dönen `Arc` alınır, lock düşer ve sonra `GlobalTheme::update_theme(...)` çağrılır. Mevcut API bu deseni zaten teşvik eder.

### Zed uyumlu tamamlanmış API

Zed-benzeri selector/settings/icon-theme akışı hedefleniyorsa aşağıdaki metotlar opsiyonel değildir, public runtime sözleşmesinin parçasıdır:

| Metot | Gerekçe |
|-------|---------|
| `default_global`, `try_global` | Init ve test akışları ile lazy setup. |
| `insert_theme_families` | Built-in, user ve extension temalarının aile halinde eklenmesi. |
| `remove_user_themes` | Kullanıcı tema dizini yeniden tarandığında eski kullanıcı temalarının temizlenmesi. |
| `list` (`ThemeMeta`) | Selector/picker için ad + appearance metadata'sı. |
| `assets()` | Built-in tema, icon, SVG ve lisans dosyalarının tek asset kaynağından yüklenmesi. |
| `list_icon_themes`, `get_icon_theme`, `load_icon_theme` | Icon theme selector ve aktif icon theme reload akışı. |
| `remove_icon_themes` | Extension/user icon theme yenileme. |
| `extensions_loaded`, `set_extensions_loaded` | Extension temaları gelmeden önce fallback'e sessiz düşme, geldikten sonra gerçek hata loglama. |

Bu metotlardan biri public API'ye eklenmeyecekse, bu karar açıkça kapsam dışı tasarım kararı olarak yazılmalıdır. "Şimdilik UI yok" yeterli bir gerekçe değildir; selector UI ileride gelse bile registry sözleşmesinin hazır olması beklenir.

### Tuzaklar

1. **`get(name: &str)` ile `get(&SharedString)` arasındaki tercih**: İmza `&str` aldığı için caller `&"...".into()` yazmak zorunda değildir; `"...".into()` ya da bir literal yeterli olur. HashMap key `SharedString` olsa bile `Borrow<str>` impl'i sayesinde `&str` ile lookup çalışır.
2. **`insert` race condition**: İki thread aynı anda aynı isimle insert yaptığında, hangisinin kazanacağı tanımsızdır — `RwLock::write()` sıraya sokar, son giren kazanır. Bu davranış mantıken kabul edilebilirdir.
3. **`global(cx)` panic'i**: Registry init edilmediyse panic atar. `kvs_tema::init()` çağrısı uygulama başında yapılmış olmalıdır. Test ortamında `set_global` elle de tetiklenebilir.
4. **`Arc<ThemeRegistry>`'yi parametre olarak almak ile `cx` kullanmak**: API `ThemeRegistry::global(cx)` desenine sahiptir; `&Arc<ThemeRegistry>` parametre geçmek de mümkündür ama tüketici kodu bu desene bağlar. Genel olarak `cx` üzerinden erişim daha esnektir.
5. **`SharedString` case sensitivity**: "Kvs Default" ile "kvs default" iki ayrı key olarak değerlendirilir (Bölüm III/Konu 7).
6. **Registry'i boş başlatıp aktif tema set etmemek**: registry `set_global` sonrası `cx.set_global(GlobalTheme::new(default, default_icon))` çağrısı şarttır. Aksi halde `cx.theme()` veya `GlobalTheme::icon_theme(cx)` panic atar.

---

## 34. `GlobalTheme` ve `ActiveTheme` trait

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`GlobalTheme`, aktif UI temasını ve aktif icon temasını taşıyan global'dir. `ActiveTheme` trait'i Zed'de yalnızca `cx.theme()` ergonomisini sağlar. Icon tema registry'de ayrı tutulur, ama aktif seçim aynı global altında saklanır. Bu sayede settings değişiminde UI ve icon refresh aynı akıştan geçer.

### `GlobalTheme` yapısı

```rust
use gpui::{App, BorrowAppContext, Global};
use std::sync::Arc;

pub struct GlobalTheme {
    theme: Arc<Theme>,
    icon_theme: Arc<IconTheme>,
}
impl Global for GlobalTheme {}
```

`Theme` ve `IconTheme` doğrudan global yapılmaz; bunun yerine bir newtype wrapper kullanılır (Bölüm III/Konu 10 kuralı). Alanlar private'tır. Dışarıdan erişim `theme()`/`icon_theme()` ve update metotları üzerinden yapılır.

### `GlobalTheme` API

```rust
impl GlobalTheme {
    pub fn new(theme: Arc<Theme>, icon_theme: Arc<IconTheme>) -> Self {
        Self { theme, icon_theme }
    }

    pub fn theme(cx: &App) -> &Arc<Theme> {
        &cx.global::<Self>().theme
    }

    pub fn icon_theme(cx: &App) -> &Arc<IconTheme> {
        &cx.global::<Self>().icon_theme
    }

    pub fn update_theme(cx: &mut App, theme: Arc<Theme>) {
        cx.update_global::<Self, _>(|this, _| this.theme = theme);
    }

    pub fn update_icon_theme(cx: &mut App, icon_theme: Arc<IconTheme>) {
        cx.update_global::<Self, _>(|this, _| this.icon_theme = icon_theme);
    }
}
```

**`theme(cx)`:**

- `cx.global::<Self>()` global'i okur; bulunmadığında panic atar.
- `&Arc<Theme>` döndürür — caller refcount artırmadan okur, klona ihtiyaç duymaz.

**`icon_theme(cx)`:**

- Aktif icon tema değerini döndürür.
- File tree, picker, tabs ve explorer icon çözümü bu değeri okur.

**İlk kurulum:**

- Zed public API'sinde `set_theme_and_icon` adında bir metot bulunmaz.
- `init` sırasında `cx.set_global(GlobalTheme::new(theme, icon_theme))` çağrılır.
- Global ilk kez kurulurken iki aktif değerin de hazır olması beklenir.

**`update_theme` / `update_icon_theme`:**

`init-or-update` deseni (Bölüm III/Konu 10) burada şöyle işler:

- `init` global'i `GlobalTheme::new` + `cx.set_global` ile kurar.
- Sonraki değişimler `update_global` ile yapılır — mevcut instance mutate edilir, `Drop` çalışmaz (eski `Arc<Theme>` refcount azalır, başka bir tutucu yoksa drop edilir).

> **Neden yeni bir `set_global` yerine `update_global`?** İki davranış görünüşte aynıdır, ancak:
> - `set_global` global tipini **kontrolsüz biçimde değiştirir** — observer'lar bilgilendirilmez.
> - `update_global` callback'i içinde GPUI'nin observer mekanizması tetiklenir (örneğin `cx.observe_global::<GlobalTheme>(|_, _| {})`).
>
> Tema değişim observer'ı yoksa fark görünmez; ama ileride eklenebilecek senaryolar düşünüldüğünde `update_global` daha güvenli bir tercihtir.

`kvs_tema` istediği takdirde yerel convenience metotları ekleyebilir; bunlar Zed public yüzeyinde olmadığı için yerel genişletme olarak değerlendirilir. Önerilen adlandırmalar:

| Yerel ad | Davranış | Neden bu ad |
|----------|----------|-------------|
| `install_or_update_theme(cx, theme)` | `has_global`'a göre `set_global` veya `update_theme` çağırır | `set_theme` adı `theme_settings::settings::set_theme` (Konu 39) ile çakışır — namespace karışıklığı bug çıkarır |
| `install_or_update_icon_theme(cx, icon)` | Aynı desen, icon tarafı | Aynı gerekçe |
| `install_active(cx, theme, icon)` | `cx.set_global(GlobalTheme::new(...))` çağrısının okunabilir alias'ı | İlk init'i tek satıra indirir |

Init öncesinde `GlobalTheme::update_theme` veya bu yerel sarmalayıcılar çağrılırsa global yokluğu nedeniyle panic oluşur.

### `ActiveTheme` trait

**Zed kaynak sözleşmesi** (`crates/theme/src/theme.rs:119`):

```rust
pub trait ActiveTheme {
    fn theme(&self) -> &Arc<Theme>;
}

impl ActiveTheme for App {
    fn theme(&self) -> &Arc<Theme> {
        GlobalTheme::theme(self)
    }
}
```

**Önemli sözleşme notu:** Zed'de `ActiveTheme` trait'i **yalnızca** `theme()` metoduna sahiptir; `icon_theme()` trait'in parçası **değildir**. Aktif icon tema'ya erişim `GlobalTheme::icon_theme(cx)` üzerinden yapılır. Zed paritesinde `cx.icon_theme()` doğrudan çalışmaz.

**`kvs_tema` için iki seçenek:**

1. **Paritede kalmak** — trait Zed'deki gibi tek metotlu tutulur; icon tema'ya `GlobalTheme::icon_theme(cx)` veya bağımsız bir `IconActiveTheme` trait'i üzerinden erişilir:

   ```rust
   pub trait ActiveTheme {
       fn theme(&self) -> &Arc<Theme>;
   }

   pub trait IconActiveTheme {
       fn icon_theme(&self) -> &Arc<IconTheme>;
   }

   impl ActiveTheme for App {
       fn theme(&self) -> &Arc<Theme> { GlobalTheme::theme(self) }
   }
   impl IconActiveTheme for App {
       fn icon_theme(&self) -> &Arc<IconTheme> { GlobalTheme::icon_theme(self) }
   }
   ```

2. **`kvs_tema` ek metot olarak `icon_theme` koymak** — bu, Zed paritesini genişletmek anlamına gelir; trait Zed'den farklı, iki metotlu bir yerel API olur.

Rehberin örnekleri 1. seçeneği varsayar; aktif icon tema için `GlobalTheme::icon_theme(cx)` çağrılır. 2. seçenek uygulandığında ilgili çağrılar `cx.icon_theme()` olarak kısaltılabilir.

**Mantık:**

- Trait **extension method** sağlar — `App` üzerinde `cx.theme()` çağrısını mümkün kılar.
- `Context<T>: Deref<Target = App>` (Bölüm III/Konu 9) sayesinde `cx.theme()` `Context<T>` üzerinden de çalışır — ayrı bir trait impl gerekmez; deref coercion yeterlidir.
- `AsyncApp` üzerinde `theme()` çalışmaz; `AsyncApp` `&App`'e doğrudan deref etmez. Gerektiğinde `cx.try_global::<GlobalTheme>()` ile manuel erişilir.

### Tüketici tarafı kullanımı

```rust
use kvs_tema::ActiveTheme;

impl Render for AnaPanel {
    fn render(&mut self, _w: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let tema = cx.theme();   // &Arc<Theme>
        let _icons = GlobalTheme::icon_theme(cx); // &Arc<IconTheme>
        div()
            .bg(tema.colors().background)
            .text_color(tema.colors().text)
    }
}
```

`use kvs_tema::ActiveTheme;` zorunludur — trait metodu import edilmediği sürece görünmez. Tipik bir desen, prelude modülü kullanmaktır:

```rust
// kvs_tema/src/prelude.rs (opsiyonel)
pub use crate::runtime::ActiveTheme;
pub use crate::Theme;
pub use crate::IconTheme;
```

```rust
use kvs_tema::prelude::*;  // tek satırlık import
```

### Accessor metotları

`styles` alanı crate-içi olduğu için tüketicinin kararlı okuma yolu Konu 12'deki accessor'lardır:

```rust
impl Theme {
    pub fn colors(&self) -> &ThemeColors { &self.styles.colors }
    pub fn status(&self) -> &StatusColors { &self.styles.status }
    pub fn players(&self) -> &PlayerColors { &self.styles.player }
}
```

Sonuç:

```rust
.bg(cx.theme().colors().background)
.text_color(cx.theme().colors().text)
```

Icon okuma:

```rust
let path = kvs_tema::icon_for_file("Cargo.toml", GlobalTheme::icon_theme(cx));
```

### Subscribe pattern (observer)

UI bileşeni tema değişimini takip etmek istediğinde aşağıdaki desen kullanılır:

```rust
impl AnaPanel {
    fn new(cx: &mut Context<Self>) -> Self {
        // Tema değişince notify
        cx.observe_global::<GlobalTheme>(|_, cx| cx.notify()).detach();
        Self
    }
}
```

`cx.observe_global` `Subscription` döndürür; `.detach()` çağrısı zorunludur. Aksi halde observer ölür.

Buna ek olarak şuna dikkat etmek gerekir: `cx.refresh_windows()` (Konu 38) zaten tüm view'ları yeniden çizdiği için explicit observer çoğu durumda gereksizdir. Observer yalnızca tema veya icon tema değişiminde özel bir state güncellenecekse anlamlı olur.

### Tuzaklar

1. **`theme(&Arc<Theme>)` üzerinde gereksiz clone**: `cx.theme()` zaten `&Arc<Theme>` döndürür; bunun üzerinde `.clone()` çağrılması gereksiz bir refcount artışı oluşturur. `let tema = cx.theme();` yeterli olur.
2. **`use kvs_tema::ActiveTheme` import etmemek**: Trait import edilmediğinde `cx.theme()` "method not found" hatasıyla karşılaşır. Prelude kullanmak en pratik çözüm olur.
3. **Global'i icon temasız kurmak**: Aktif icon tema yokken explorer render fallback path üretemez. `init` içinde default icon tema'nın mutlaka kurulması gerekir.
4. **`update_theme` callback'inde başka bir global'i set etmeye kalkmak**: `update_global::<Self, _>(|this, _| ...)` callback'inde yalnızca field mutate edilebilir; başka bir global'i set etmeye çalışmak re-entrancy panic'i çıkarır.
5. **Theme parametresinin `Theme` olarak alınması**: `update_theme(cx, theme: Theme)` yazıldığında her çağrıda klon oluşurdu. `Arc<Theme>` parametre tipi zorunludur.
6. **`observe_global` üzerinde `.detach()` çağırmamak**: Subscription drop edildiğinde observer ölür; tema değişince bileşen yenilenmez.

---

## 35. `SystemAppearance` ve sistem mod takibi

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

OS'un light/dark mod tercihini taşır. Tema seçim mantığı bu değeri okur ve uygun tema varyantını yükler.

### Yapı

**Zed kaynak sözleşmesi** (`crates/theme/src/theme.rs:132`):

```rust
#[derive(Debug, Clone, Copy)]
pub struct SystemAppearance(pub Appearance);

impl Default for SystemAppearance {
    fn default() -> Self {
        Self(Appearance::Dark)
    }
}

impl std::ops::Deref for SystemAppearance {
    type Target = Appearance;
    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

#[derive(Default)]
struct GlobalSystemAppearance(SystemAppearance);

impl std::ops::Deref for GlobalSystemAppearance {
    type Target = SystemAppearance;
    fn deref(&self) -> &Self::Target { &self.0 }
}

impl std::ops::DerefMut for GlobalSystemAppearance {
    fn deref_mut(&mut self) -> &mut Self::Target { &mut self.0 }
}

impl Global for GlobalSystemAppearance {}
```

- `SystemAppearance(pub Appearance)` — `Appearance` (Bölüm IV/Konu 16) newtype'ıdır; `Default` `Self(Appearance::Dark)` döndürür.
- `Deref<Target = Appearance>` impl'i sayesinde `system.is_light()` gibi `Appearance` metotları doğrudan çalışır; `.0` açmaya gerek kalmaz.
- `Copy` türevidir; çünkü `Appearance` `Copy`'dir. Bu sayede değer geçişi ucuz olur.
- `GlobalSystemAppearance` `Default` türevini taşır ve `Deref`/`DerefMut` ile newtype'ı tutucu olarak şeffaflaştırır.

> **Neden `Appearance` doğrudan global yapılmaz?** `Appearance` enum'u farklı anlamlarda da kullanılır: tema'nın nominal modu ve JSON deserialize hedefi gibi. Global anahtarının **sisteme özgü** kalması önemlidir. `SystemAppearance` yalnızca "OS şu an ne söylüyor?" sorusunu cevaplar.

### API

```rust
impl SystemAppearance {
    /// Bağlamda yoksa default kurar; varsa pencere mevcut görünümünden
    /// günceller. Zed paritesi `default_global` + `From<WindowAppearance>`
    /// üzerinden çalışır.
    pub fn init(cx: &mut App) {
        *cx.default_global::<GlobalSystemAppearance>() =
            GlobalSystemAppearance(SystemAppearance(cx.window_appearance().into()));
    }

    /// Aktif sistem görünümünü döner; yoksa panic eder.
    pub fn global(cx: &App) -> Self {
        cx.global::<GlobalSystemAppearance>().0
    }

    /// Sistem görünümünü mutate etmek için. Pencere event'i veya test
    /// kurulumunda kullanılır.
    pub fn global_mut(cx: &mut App) -> &mut Self {
        cx.global_mut::<GlobalSystemAppearance>()
    }
}
```

> **`init` `default_global` ile çalışır:** `set_global` yerine `default_global` kullanıldığında, bağlamda global yoksa `Default::default()` (yani `SystemAppearance(Appearance::Dark)`) oluşturulup üstüne yazılır. İkinci `init` çağrısı eski global'i drop etmek yerine mevcut yerinde günceller — observer'lar tetiklenir.

**`init(cx)`:**

- `cx.window_appearance()` (Bölüm III/Konu 8) sorgusu yapılır.
- `WindowAppearance` dört variant'tan birini döndürür; `Vibrant*` macOS'a özgüdür ama tema seçiminde Light/Dark ile aynı kategoride ele alınır.
- Match ifadesi dört variant'ı iki kategoride birleştirir.
- `set_global` ile global kurulur.

**`global(cx)`:**

- `cx.global::<GlobalSystemAppearance>()` çağrısı `&GlobalSystemAppearance` döndürür.
- `.0` newtype'ı açar — `SystemAppearance` `Copy` olduğu için değer geri döner.

### Sistem mod değişimini izleme (public API)

`init` çağrısı yalnızca **başlangıçta** yapılır. OS theme değişimini takip etmek için observer gerekir. Observer kurmak `Window` referansı ister; `init` ise `&mut App` aldığı için bunu içeride yapamaz. Bu yüzden tüketici, pencere açıldıktan sonra ayrı bir public fonksiyon çağırır:

```rust
// kvs_tema/src/runtime.rs — public API
pub fn observe_system_appearance<V: 'static>(
    window: &mut Window,
    cx: &mut Context<V>,
) {
    cx.observe_window_appearance(window, |_, window, cx| {
        let new_appearance = match window.appearance() {
            WindowAppearance::Dark | WindowAppearance::VibrantDark => Appearance::Dark,
            WindowAppearance::Light | WindowAppearance::VibrantLight => Appearance::Light,
        };

        // SystemAppearance global'ini güncelle
        cx.set_global(GlobalSystemAppearance(SystemAppearance(new_appearance)));

        // Tüketici tema değişimini de istiyorsa observe_global ile
        // ayrı subscribe eder; bu fonksiyon sadece sistem mod'unu
        // raporlar (politika kullanıcıya bırakılır).
    }).detach();
}
```

**Çağrı yeri — pencere açma callback'i:**

```rust
fn main() {
    Application::new().run(|cx| {
        kvs_tema::init(cx);   // Adım 1: SystemAppearance::init burada

        cx.open_window(WindowOptions::default(), |window, cx| {
            cx.new(|cx| {
                // Adım 2: pencere açıldıktan sonra observer kur
                kvs_tema::observe_system_appearance(window, cx);
                AnaPanel
            })
        }).unwrap();
    });
}
```

**İki adımlı kuruluşun gerekçesi:**

- **Adım 1 (`init`)**: Sistem mod'unun **anlık değerini** yakalar (`cx.window_appearance()` `&App` üzerinden çalışır).
- **Adım 2 (`observe_system_appearance`)**: Mod **değişimini** dinler (`cx.observe_window_appearance` `Window` ister).

Tüketici 2. adımı atlayabilir. Bu durumda sistem modu "set once" davranışı gösterir ve uygulama yaşadığı sürece ilk değerinde kalır. Bu kasıtlı bir seçim olabilir; ancak otomatik tema takibi isteniyorsa observer kurulmalıdır.

> **`.detach()` zorunluluğu:** `cx.observe_window_appearance` `Subscription` döndürür; drop edildiğinde observer ölür (Bölüm III/Konu 10 tuzak 5). `observe_system_appearance` fonksiyonu zaten `.detach()` çağırır; tüketicinin elle çağırmasına gerek kalmaz.

### Sistemden tema seçme örneği

`SystemAppearance` okuyup uygun temayı yüklemek:

```rust
pub fn sistemden_tema_sec(cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let ad = match SystemAppearance::global(cx).0 {
        Appearance::Dark => "Kvs Default Dark",
        Appearance::Light => "Kvs Default Light",
    };
    GlobalTheme::update_theme(cx, registry.get(ad)?);
    cx.refresh_windows();
    Ok(())
}
```

> **Tema adının sabit string olarak yazılması:** "Kvs Default Dark" ifadesi tipo'ya açıktır. Production için iki yaklaşım daha güvenlidir:
> - Sabitler modülü: `pub const DEFAULT_DARK: &str = "Kvs Default Dark";`
> - Kullanıcı ayarlarından okuma: `SettingsTema { dark_default: String, light_default: String }`.

### `Appearance` ile `SystemAppearance` ve `WindowAppearance` ayrımı

| Tip | Anlamı | Kaynak |
|-----|--------|--------|
| `WindowAppearance` (GPUI) | OS'un raporladığı raw mode (Light/Dark/Vibrant*) | `cx.window_appearance()` |
| `SystemAppearance` (tema) | OS modunun **iki kategoriye** indirgenmiş hali (Light/Dark) | `SystemAppearance::init` |
| `Appearance` (tema) | Bir **tema'nın nominal modu** | `Theme.appearance` |

Bu üç tip farklı kavramları temsil eder; karıştırılmamalıdır:

- Kullanıcı sistem Dark modda olsa bile explicit olarak Light tema seçmişse: `SystemAppearance::Dark` ama `cx.theme().appearance == Light`.
- macOS Vibrant moda geçtiğinde: `WindowAppearance::VibrantDark` döner ama `SystemAppearance::Dark` olarak kategorize edilir (kategori indirme).

### Tuzaklar

1. **`init` tek seferlik çağrılır**: Sistem mod değişirse `init` tekrar tetiklenmez. Değişimin yakalanması için observer'ın kurulması gerekir.
2. **`SystemAppearance` `Copy` ama `GlobalSystemAppearance` değil**: Newtype `Copy` türevini taşımaz (`Global` `Copy` gerektirmez); ama içindeki `SystemAppearance` `Copy` olduğu için `.0` `Copy` döner. Bu kasıtlı bir tasarım kararıdır.
3. **Vibrant variant'larını görmezden gelmek**: `match` ifadesinde `_ => Light` veya `_ => Dark` yazıldığında macOS'ta yanlış kategori üretilir. Dört variant'ın da listelenmesi gerekir.
4. **Sistem moduna zorla uymaya çalışmak**: Kullanıcı manuel olarak bir tema seçmiş olabilir; sistem mod değişimini doğrudan uygulamak kullanıcı tercihini ezer. Bunun için ayar yapısı genişletilebilir:
   ```rust
   pub struct AyarlarTema {
       pub mod_takibi: bool,  // false ise sistem mod'unu yok say
       pub ad: Option<String>,
   }
   ```
5. **`SystemAppearance::global(cx)` init'siz erişim**: Zed'de `SystemAppearance` `Default` (`Appearance::Dark`) türevini taşır; ancak `global(cx)` `cx.global::<...>` çağrısı yaptığı için bağlamda kayıt yoksa panic atar. Erişimden önce `default_global(cx)` veya `init(cx)` ile kurulum yapılması gerekir. Bu sıra `init()` fonksiyonu içinde garanti altındadır.

---

## 36. `init()` ve `LoadThemes`: kuruluş sırası, fallback ve yükleme modu

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`kvs_tema::init(cx)`, runtime'ın **tek giriş noktasıdır**. Uygulamanın başında, pencere açılmadan **mutlaka** çağrılır.

### Tam kod

`kvs_tema::init` Zed paritesi için `LoadThemes` enum'unu parametre olarak alır (Konu 43.1):

```rust
pub fn init(themes_to_load: LoadThemes, cx: &mut App) {
    SystemAppearance::init(cx);

    let assets: Box<dyn AssetSource> = match themes_to_load {
        LoadThemes::JustBase => Box::new(()),
        LoadThemes::All(assets) => assets,
    };

    // `ThemeRegistry::new(assets)` zed_default_themes ailesini ve
    // default icon tema'yı kendi içinde yükler.
    let registry = Arc::new(ThemeRegistry::new(assets));

    // Font picker dropdown'u ve `setup_ui_font` runtime hazırlığı.
    // Zed paritesi (`theme::init`, theme.rs:103): registry kurulduktan
    // hemen sonra font ailesi önbelleği init edilir. Atlamak settings UI
    // tarafında "fontlar yüklenmedi" race condition'ına yol açar.
    FontFamilyCache::init_global(cx);

    registry.insert_themes([
        crate::fallback::kvs_default_dark(),
        crate::fallback::kvs_default_light(),
    ]);

    let default = registry
        .get("Kvs Default Dark")
        .expect("default tema kayıtlı olmalı");
    let default_icon = registry
        .default_icon_theme()
        .expect("default icon tema kayıtlı olmalı");

    // `ThemeRegistry::set_global` Zed'de `pub(crate)`. `kvs_tema` mirror'ında
    // public yapıldığında tüketici tarafına da açılır; aksi halde global'i
    // yalnızca bu `init` fonksiyonu kurar.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(default, default_icon));
}
```

> **İki katmanlı init paritesi:** Zed bu kuruluşu **iki adımda** yapar. `theme::init` önce font cache, registry ve fallback dark temasını kurar. Daha sonra üst seviyede `theme_settings::init` (`theme_settings/src/theme_settings.rs:68`) çağrılır. Bu ikinci adım `set_theme_settings_provider` ile typography/density provider'ını kurar, `LoadThemes::All` durumunda `assets/themes/*.json` altındaki bundled tema asset'lerini yükler, `configured_theme(cx)` ile settings dosyasından gelen seçimi çözer ve aktif tema'yı **fallback dark'tan settings'in istediği temaya** geçirir. Kullanıcı disk temaları bu adımın parçası değildir; onlar `load_user_theme(registry, bytes)` veya `deserialize_user_theme(bytes)` yoluyla ayrıca registry'ye eklenir. Mirror tarafta da bu ayrım korunmalıdır: `kvs_tema::init` registry + `GlobalTheme` default'unu kurar, `kvs_tema_ayarlari::init` ise provider + settings observer + `configured_theme` akışını kurar. Bunları tek init'te birleştirmek `kvs_tema` crate'ini settings crate'ine zorunlu bağlar ve Konu 5'teki bağımlılık kararıyla çelişir.

### 5 adımlı kuruluş

**Adım 1 — `SystemAppearance::init(cx)`:**

Sistem mod sorgulanır ve global kurulur. **İlk** adım olmasının nedeni, sonraki adımların gerektiğinde sistem mod'una bakabilmesidir (`init` sırasında olmasa bile observer eklenirken).

**Adım 2 — Registry yaratma:**

```rust
let registry = Arc::new(ThemeRegistry::new(assets));
```

`Arc` global'e konacağı için kullanılır. `ThemeRegistry::new(assets)` `AssetSource` parametresini zorunlu alır; testte `Box::new(()) as Box<dyn AssetSource>` geçirilir. Yapıcı zaten içinde `insert_theme_families([zed_default_themes()])` çağrısı yapar ve default icon tema'yı ekler — yani `new`'den dönen registry hiçbir zaman boş değildir.

**Adım 3 — Fallback temalarının insert edilmesi:**

```rust
registry.insert_themes([
    crate::fallback::kvs_default_dark(),
    crate::fallback::kvs_default_light(),
]);
```

İki "default" tema her zaman registry'de bulunur. Bunun nedenleri:

- Kullanıcı tema yükleme akışı bozulsa bile **uygulama çalışmaya devam eder**.
- `cx.theme()` ve `GlobalTheme::icon_theme(cx)` çağrıları panic atamaz; her zaman geçerli bir tema bulunur.
- Sistem light/dark mod değişiminde her zaman bir hedef tema hazır durur.

**Adım 4 — Default seçimi:**

```rust
let default = registry
    .get("Kvs Default Dark")
    .expect("default tema kayıtlı olmalı");
let default_icon = registry
    .default_icon_theme()
    .expect("default icon tema kayıtlı olmalı");
```

`.expect()` kullanımı kasıtlıdır. Bu durum bir **mantıksal invariant**'tır: az önce UI fallback temaları insert edildi ve registry default icon tema'yı kurdu; eksik olmaları beklenmez. Eksiklerse bu programatik bir hatadır (typo veya init bug'ı) ve panic kabul edilebilir bir tepkidir.

> Alternatif olarak `SystemAppearance` baz alınarak başlangıç teması seçilebilir:
> ```rust
> let default_name = match SystemAppearance::global(cx).0 {
>     Appearance::Dark => "Kvs Default Dark",
>     Appearance::Light => "Kvs Default Light",
> };
> let default = registry.get(default_name).expect("...");
> ```
> Bu sürüm OS modunu hemen yansıtır. İki yaklaşım arasındaki seçim bir tercih meselesidir; varsayılan olarak dark tutmak da bilinçli bir karar olabilir.

**Adım 5 — Global'lerin kurulması:**

```rust
// ThemeRegistry::set_global Zed'de pub(crate) ve Box<dyn AssetSource>
// alır (içeride GlobalThemeRegistry newtype'ını oluşturur). Mirror
// tarafında newtype elle set edilerek aynı sözleşme kurulur.
cx.set_global(GlobalThemeRegistry(registry.clone()));
cx.set_global(GlobalTheme::new(default, default_icon));
```

Sıra önemlidir: önce registry global'i kurulur, ardından aktif UI tema + aktif icon tema aynı `GlobalTheme` içinde kurulur. `cx.theme()` ve `GlobalTheme::icon_theme(cx)` bu noktadan sonra güvenle çağrılabilir.

### Çağrı yeri

`gpui::Application` kurulurken, pencere açılmadan **mutlaka**:

```rust
use gpui::{Application, App};

fn main() {
    Application::new().run(|cx: &mut App| {
        // 1. Tema sistemini başlat
        kvs_tema::init(cx);

        // 2. Başka init'ler (settings, key bindings, vs.)
        // ...

        // 3. Pencere aç — render içinde cx.theme() artık güvenli
        cx.open_window(WindowOptions {
            // window_background dahil tema kullanılır
            window_background: cx.theme().window_background_appearance(),
            ..Default::default()
        }, |w, cx| {
            cx.new(|cx| AnaPanel::new(cx))
        }).unwrap();
    });
}
```

### Hata davranışları

| Hata | Davranış | Önlem |
|------|----------|-------|
| Fallback tema yüklenmediyse | `expect` panic | Code review — `kvs_default_*` fonksiyonları static olarak erişilebilir; runtime'da bu hatanın oluşması mümkün değildir |
| `cx.window_appearance()` panic eder mi? | Hayır, default `Light` döner | — |
| `cx` zaten init edilmişse (`init` iki kez çağrıldı) | `set_global` sessizce üzerine yazar; eski registry/theme drop edilir | İki kez çağrılması mantıksızdır |
| `kvs_tema::init` çağrılmadan `cx.theme()` / `GlobalTheme::icon_theme(cx)` | Panic: "global not found" | Init ilk satıra konur |

### Genişletilmiş init varyasyonları

**1. Bundled tema yüklemesi:**

```rust
pub fn init_with_bundled(cx: &mut App) {
    init(cx);  // Mevcut init

    // Bundled tema'ları ekle (Bölüm VI)
    let registry = ThemeRegistry::global(cx);
    if let Err(e) = load_bundled_themes(&registry) {
        tracing::warn!("bundled tema yükleme hatası: {}", e);
    }
}
```

`init`'in temel kontratı korunur; bundled yükleme **opsiyoneldir**. Hata oluşsa bile uygulama açılır; fallback temalar yeterlidir.

**2. Async user theme yükleme:**

```rust
pub fn init_with_user_themes(cx: &mut App, user_theme_dir: PathBuf) {
    init(cx);

    cx.spawn(async move |cx| {
        let entries = std::fs::read_dir(&user_theme_dir)?;
        for entry in entries.flatten() {
            let bytes = std::fs::read(entry.path())?;
            let family: ThemeFamilyContent = serde_json_lenient::from_slice(&bytes)?;
            cx.update(|cx| {
                let registry = ThemeRegistry::global(cx);
                let baseline = fallback::kvs_default_dark();
                let themes: Vec<Theme> = family
                    .themes
                    .into_iter()
                    .map(|tc| Theme::from_content(tc, &baseline))
                    .collect();
                registry.insert_themes(themes);
            })?;
        }
        anyhow::Ok(())
    }).detach_and_log_err(cx);
}
```

User theme yükleme **disk I/O** içerdiği için async çalışır; init akışını bloklamaz.

### Test senaryoları

```rust
#[gpui::test]
fn init_kurar_fallback_temalari(cx: &mut TestAppContext) {
    cx.update(|cx| {
        kvs_tema::init(cx);

        let registry = ThemeRegistry::global(cx);
        let names = registry.list_names();
        assert!(names.iter().any(|n| n.as_ref() == "Kvs Default Dark"));
        assert!(names.iter().any(|n| n.as_ref() == "Kvs Default Light"));

        let theme = cx.theme();
        assert_eq!(theme.name.as_ref(), "Kvs Default Dark");
    });
}
```

### Tuzaklar

1. **`init`'in pencere içinde çağrılması**: `Context<T>::update` callback'inde `init(cx)` çağırmak mantıksızdır — pencere zaten render başladığında `cx.theme()` çağırıyor olur. Init Application root'unda yer alır.
2. **`init`'in async yapılması**: `init` `&mut App` aldığından async olamaz. Async yüklemeler (kullanıcı tema dosyaları, network) `spawn` ile **init sonrası** başlatılır.
3. **Birden fazla `init` çağrısı**: İdempotent değildir — registry ve aktif tema sıfırlanır. Bu çağrı tekrarlanmamalıdır.
4. **`init` yokken `cx.theme()` çağrılması**: Panic mesajı `"global not found: GlobalTheme"` biçiminde olur. Hata mesajı yönlendiricidir; `init` eklendiğinde sorun giderilir.
5. **Default tema seçiminde fallback olmadan**: `registry.get("Yok").expect()` panic atar. Yalnızca insert edilmiş temaların seçilmesi gerekir.
6. **Fallback'lerin kaldırılması**: User theme'ler yüklendikten sonra "Kvs Default *" temaları gereksiz görünebilir; **kaldırılmaması** gerekir. Kullanıcı temasının yüklenmesi başarısız olduğunda son çare olarak iş görür.

### `LoadThemes` — yükleme modu enum'u

**Kaynak:** `crates/theme/src/theme.rs:81`.

Zed'in `init` fonksiyonu, `crates/theme/assets/themes/` altındaki temaların yüklenip yüklenmeyeceğini bir enum üzerinden kontrol eder:

```rust
pub enum LoadThemes {
    /// Yalnızca fallback (built-in baseline) temalarını yükle
    JustBase,
    /// Tüm bundled tema dosyalarını da yükle
    All(Box<dyn AssetSource>),
}
```

**Karşılığı `kvs_tema`'da:**

```rust
pub enum LoadThemes {
    JustBase,
    All(Box<dyn gpui::AssetSource>),
}

pub fn init(themes_to_load: LoadThemes, cx: &mut App) {
    SystemAppearance::init(cx);

    // ThemeRegistry::new tek imza taşır: AssetSource zorunlu.
    let assets: Box<dyn gpui::AssetSource> = match &themes_to_load {
        LoadThemes::JustBase => Box::new(()),
        LoadThemes::All(assets) => dyn_clone::clone_box(&**assets),
    };
    let registry = Arc::new(ThemeRegistry::new(assets));

    registry.insert_themes([
        fallback::kvs_default_dark(),
        fallback::kvs_default_light(),
    ]);

    if let LoadThemes::All(assets) = themes_to_load {
        if let Err(e) = load_bundled_themes_from_asset_source(&registry, assets.as_ref()) {
            tracing::warn!("bundled tema yüklemesi başarısız: {}", e);
        }
    }

    let default = registry.get("Kvs Default Dark").expect("...");
    let default_icon = registry.default_icon_theme().expect("...");

    // Zed'de set_global pub(crate); mirror tarafında newtype elle set
    // edildiğinde de aynı sözleşme kurulur ya da `init` içeride kalan tek
    // çağıran olarak tutulur.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(default, default_icon));
}
```

**Ne zaman `JustBase`?**

- Test ortamları (`#[gpui::test]` bağlamında bundled asset'lere ihtiyaç duyulmadığında).
- Headless CLI veya batch işler (registry yalnızca program içi kullanımda).
- Minimal binary çıkışı (önyükleme süresini düşürme amacı).

**Ne zaman `All(...)`?**

- Production uygulama girişi.
- Geliştirme çalışmaları (bundled tema fixture'larıyla doğrulama).

**Yapısal not:** `LoadThemes::All(Box<dyn AssetSource>)` enum içinde bir `AssetSource` taşır. `init` çağrısı sırasında `Application::new().with_assets(...)` ile geçirilen aynı asset source'un tekrar verilmesi zorunlu değildir; `cx.asset_source()` üzerinden dolaylı erişim de mümkündür. Hangi yolun seçileceği Bölüm VI/Konu 26'daki bundling stratejisine bağlıdır.

---

## 37. `font_family_cache` — font ailesi önbellek

**Kaynak:** `crates/theme/src/font_family_cache.rs:18`.

Zed sistem font ailelerini her sorguda yeniden almak yerine global bir önbellekte tutar:

```rust
pub struct FontFamilyCache {
    state: Arc<RwLock<FontFamilyCacheState>>,
}
```

**Rol:** Settings UI'daki font seçici dropdown'u, kullanıcının makinesindeki font listesini gösterir. OS sorgusu pahalı bir işlemdir; cache asenkron olarak init edilir ve sonrasında bellek üzerinden okunur.

Public yüzey:

```rust
impl FontFamilyCache {
    pub fn init_global(cx: &mut App);
    pub fn global(cx: &App) -> Arc<Self>;
    pub fn list_font_families(&self, cx: &App) -> Vec<SharedString>;
    pub fn try_list_font_families(&self) -> Option<Vec<SharedString>>;
    pub async fn prefetch(&self, cx: &gpui::AsyncApp);
}
```

**Tema sözleşmesindeki yer:** Yoktur — bu tip `kvs_tema` kapsamı dışında tutulabilir. Font ailesi listesini kullanan settings/picker bileşeni gerektiğinde, `kvs_settings` veya `kvs_ui` crate'inde benzer bir cache implement edilebilir.

**Atlama gerekçesi:** Mirror disiplini (Konu 2) `Theme` ve içerdiği tipleri zorunlu kılar; `FontFamilyCache` ise bir runtime önbelleğidir, sözleşmenin parçası değildir.

---

## 38. Tema değiştirme ve `cx.refresh_windows()`

Tema değişimi iki temel işlemdir: aktif tema güncellenir ve pencereler yenilenir. Pencereler yenilenmezse UI eski renkte kalır.

### Temel akış

```rust
pub fn temayi_degistir(ad: &str, cx: &mut App) -> anyhow::Result<()> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;       // 1. Tema lookup
    GlobalTheme::update_theme(cx, yeni); // 2. Global güncelle
    cx.refresh_windows();                // 3. UI yenile
    Ok(())
}
```

### Adım adım

**Adım 1 — Registry lookup:**

```rust
let registry = ThemeRegistry::global(cx);
let yeni = registry.get(ad)?;
```

- `registry.get(ad)` `Result<Arc<Theme>, ThemeNotFoundError>` döndürür.
- `?` operatörü hatayı caller'a propagate eder.
- Tema bulunamazsa `ThemeNotFoundError` döner — caller bunu loglayabilir veya UI'da gösterebilir (toast: "Tema bulunamadı: X").

**Adım 2 — Global update:**

```rust
GlobalTheme::update_theme(cx, yeni);
```

`init-or-update` pattern (Konu 34) burada da geçerlidir. İlk çağrıda global kurulur, sonraki çağrılarda ise içeride mutate edilir. `observe_global::<GlobalTheme>` observer'ları varsa tetiklenir.

**Adım 3 — `cx.refresh_windows()`:**

```rust
cx.refresh_windows();
```

(Bölüm III/Konu 10).

### `cx.refresh_windows()` semantiği

| Davranış | Etki |
|----------|------|
| Açık tüm pencerelere `refresh` mesajı gönderir | Sonraki frame'de tüm view ağacı yeniden inşa edilir |
| Pencerelere özel state (focus, scroll, selection) | **Korunur** |
| GPU resource (textures, font atlas) | **Reuse** edilir; yalnızca layout + paint tekrar çalışır |
| `cx.notify()` ile fark | `notify()` lokal entity'yi yeniler, `refresh_windows()` global olarak tüm pencereleri yeniler |

**Maliyet:**

- Frame budget tipik olarak 16 ms'tir (60 fps); refresh maliyeti ~2-5 ms civarında olur (içerik karmaşıklığına bağlı).
- Kullanıcı tema değiştirir, bir frame geçer ve yeni renk görünür hale gelir. Gözlemlenebilir bir gecikme oluşmaz.

### Helper fonksiyon önerisi

`temayi_degistir` çağrısının helper içine sarılması tüketici kodlarda tekrarın önüne geçer:

```rust
// kvs_tema/src/runtime.rs (public API)
pub fn temayi_degistir(ad: &str, cx: &mut App) -> Result<(), ThemeNotFoundError> {
    let registry = ThemeRegistry::global(cx);
    let yeni = registry.get(ad)?;
    GlobalTheme::update_theme(cx, yeni);
    cx.refresh_windows();
    Ok(())
}
```

Tüketici tarafından kullanım:

```rust
use kvs_tema::temayi_degistir;

fn handle_tema_secimi(secilen: &str, cx: &mut App) {
    if let Err(e) = temayi_degistir(secilen, cx) {
        // toast: "Tema değiştirilemedi: ..."
    }
}
```

### Tuzaklar

1. **`refresh_windows` çağrısının atlanması**: En sık karşılaşılan bug'lardan biridir. UI eski renkte kalır ve yeni renk ancak sonraki etkileşimle (örn. hover) görünür. Helper fonksiyona sarılması bu hatanın önüne geçer.
2. **`cx.notify()` ile yetinmek**: `notify` yalnızca lokal entity'i yeniler — tüm view'ları kapsamaz. Tema değişiminde `refresh_windows` şarttır.
3. **Reload sonrası `aktif_ad` lookup'ının başarısız olması**: Tema dosyasından o isim silinmiş olabilir. `get(&aktif_ad).is_err()` durumunda default fallback'e düşülür:
   ```rust
   match registry.get(&aktif_ad) {
       Ok(t) => GlobalTheme::update_theme(cx, t),
       Err(_) => {
           tracing::warn!("aktif tema silindi, fallback'e dönülüyor");
           let fallback = registry.get("Kvs Default Dark").unwrap();
           GlobalTheme::update_theme(cx, fallback);
       }
   }
   cx.refresh_windows();
   ```
4. **Frame budget aşımı**: Çok karmaşık UI'da `refresh_windows` çağrısı 16 ms'yi aşabilir ve bir frame skip olarak görünebilir. Bu noktada profilling yapılması yerinde olur; gerçek bir bug söz konusudur.

---
