# Runtime kuruluşu ve tema seçimi

Üretilen temaları registry/global state içine yerleştir, sistem görünümünü izle ve tema değişiminde pencereleri yenile.

---

## 33. `ThemeRegistry`: API yüzeyi ve thread safety

**Kaynak modül:** `kvs_tema/src/registry.rs`.

Yüklü UI temalarının ve icon temalarının ad-bazlı kataloğu. Thread-safe
read/write erişim; runtime'ın tek "tema veritabanı"sı.

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

**Üç katmanlı sarmalama:**

1. **`Arc<Theme>` / `Arc<IconTheme>`** — Her tema paylaşılabilir; klon
   ucuz (refcount). Zed paritesinde `cx.theme()` ve
   `GlobalTheme::icon_theme(cx)` `&Arc<_>` döner.
2. **`HashMap<SharedString, _>`** — Ad bazlı O(1) lookup. `SharedString`
   key (Bölüm III/Konu 7); klonsuz hashleme.
3. **`RwLock<...>`** — Çoklu okuyucu, tek yazıcı. Tema okuma sık
   (render path); yazma nadir (init + reload).
4. **`AssetSource`** — Built-in tema ve icon theme asset'lerini aynı
   registry üstünden listeler/yükler; production bundling ile uyumlu.

> **Neden `parking_lot::RwLock`?** `std::sync::RwLock` daha yavaş ve
> daha büyük; ayrıca poisoned-on-panic davranışı zorunlu unwrap'lere
> yol açar. `parking_lot::RwLock`:
> - ~2× hızlı kilit-açma
> - Daha küçük bellek ayak izi
> - Poison yok — panic sonrası lock kullanılabilir
> - `read()`/`write()` doğrudan guard döner; `unwrap()` gereksiz

### Hata tipleri

**Zed kaynak sözleşmesi** (`crates/theme/src/registry.rs:27`, `:32`):
hata tipi adları `ThemeNotFoundError` / `IconThemeNotFoundError` — sonunda
`Error` suffix'i. `kvs_tema` mirror'ında aynı isimler kullanılır:

```rust
use thiserror::Error;

#[derive(Debug, Error)]
#[error("tema bulunamadı: {0}")]
pub struct ThemeNotFoundError(pub SharedString);

#[derive(Debug, Error)]
#[error("icon tema bulunamadı: {0}")]
pub struct IconThemeNotFoundError(pub SharedString);
```

- `thiserror` `Display + std::error::Error` derive eder.
- Tek alanlı newtype — hata mesajı `"tema bulunamadı: Kvs Default Dark"`.
- Hata propagation kolay: `?` operatörü ile `anyhow::Result<...>` veya
  başka error chain'e dönüşebilir.

> **İsim sözleşmesi:** Zed pariteli hata adları `Error` suffix'i taşır:
> `ThemeNotFoundError` ve `IconThemeNotFoundError`.

### Global wrapper

```rust
#[derive(Default)]
struct GlobalThemeRegistry(Arc<ThemeRegistry>);
impl Global for GlobalThemeRegistry {}
```

`Arc<ThemeRegistry>`'yi `App` global'i yapmak için newtype (Bölüm III/Konu 10). Doğrudan `Arc<ThemeRegistry>` global yapamazsın çünkü:

- `Arc<T>` zaten `'static + Send + Sync` ama global key olarak `Arc`
  kullanmak başka yerlerde `Arc<ThemeRegistry>` taşıyan kodla çakışır.
- Newtype, **bu özel registry'nin global anahtarı** olduğunu garantiler.

### Public API yüzeyi

Zed'in `crates/theme/src/registry.rs` dosyasındaki public yüzeye birebir
paralel. Önemli üç davranış farkı yorum satırlarında belirtildi:

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
    // `init(LoadThemes::..., cx)` kullanın (Konu 36).
    pub(crate) fn set_global(assets: Box<dyn AssetSource>, cx: &mut App);

    pub fn assets(&self) -> &dyn AssetSource;

    // TEK TEK Theme insert eden public API YOK.
    // Tek tema yüklemek için tek elemanlı koleksiyon geçirilir:
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
    // `register_test_icon_themes` test-only.
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

> **`ThemeRegistry::new` davranış notu:** Yapıcı kendi içinde
> `insert_theme_families([zed_default_themes()])` çağırır ve default icon
> theme'i de ekler. Yani `new` ile dönen registry hiçbir zaman tamamen
> boş değildir; mirror'da `kvs_default_themes()` ailesi otomatik
> yüklenmelidir.

**Her method'un davranışı:**

| Method | İmza | Davranış | Lock |
|--------|------|----------|------|
| `new` | `(assets: Box<dyn AssetSource>) -> Self` | `zed_default_themes()` ailesini ve default icon tema'yı yükleyerek registry kurar; asset zorunlu | Yok |
| `global` | `(cx: &App) -> Arc<Self>` | Aktif registry'yi döner; yoksa **panic** | App global okuma |
| `default_global` | `(cx: &mut App) -> Arc<Self>` | Yoksa default registry kurup döner | App global yazma |
| `try_global` | `(cx: &mut App) -> Option<Arc<Self>>` | Init edilmemişse `None` | App global okuma |
| `set_global` | `(assets, cx) -> ()` — `pub(crate)` | `init(...)` çağrısı içinden global'i kurar; tüketici çağıramaz | App global yazma |
| `insert_themes` | `(&self, themes)` | Her temayı `name` key'i ile ekler; aynı isimde varsa **üzerine yazar** | Write |
| `insert_theme_families` | `(&self, families)` | Ailelerdeki tüm temaları `insert_themes` ile ekler | Write |
| `remove_user_themes` | `(&self, names)` | Verilen ad listesindeki temaları kaldırır | Write |
| `clear` | `(&self)` | Tüm UI temalarını siler (icon temalar etkilenmez) | Write |
| `get` | `(&self, name: &str) -> Result<Arc<Theme>, ThemeNotFoundError>` | Tema'yı clone'lar (Arc); yoksa hata | Read |
| `list_names` | `(&self) -> Vec<SharedString>` | Tüm tema adlarını sıralı liste olarak döner | Read |
| `list` | `(&self) -> Vec<ThemeMeta>` | Selector için ad + appearance metadata'sı döner | Read |
| `get_icon_theme` | `(&self, name)` | Icon tema lookup | Read |
| `default_icon_theme` | `(&self)` | Default icon tema; yoksa `IconThemeNotFoundError` | Read |
| `list_icon_themes` | `(&self) -> Vec<ThemeMeta>` | Icon selector için metadata | Read |
| `load_icon_theme` | `(family, root)` | Icon path'lerini root'a göre çözerek ekler | Write |
| `extensions_loaded` | `() -> bool` | Extension temaları yüklendi mi bilgisi | Read |
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

`HashMap::insert` aynı key varsa eski değeri **drop eder**. Kullanıcı
"My Theme" adıyla iki tema yükledi → ikincisi birinciyi siler. Bu
davranış **kasıtlı** — kullanıcının "tema güncelleme" reflexi (aynı
adla yeniden yükleme).

> Tek tema yüklemek için tek elemanlı koleksiyon geçirilir:
> `registry.insert_themes([theme]);` veya `registry.insert_themes(std::iter::once(theme));`.
> Zed'de tek tema için ayrı bir `insert(theme)` metodu yoktur.

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

`cloned()` `Arc<Theme>`'i clone'lar — sadece refcount artırır. Caller
kendi `Arc<Theme>` instance'ına sahip olur; registry'nin storage'ı
bağımsız.

**`list_names` sıralama:**

```rust
pub fn list_names(&self) -> Vec<SharedString> {
    let mut names: Vec<_> = self.state.read().themes.keys().cloned().collect();
    names.sort();
    names
}
```

`HashMap` sırasız; `sort()` deterministik liste sunar. UI'da tema
seçici dropdown'u alfabetik sıralı görünür. Picker/selector ad yanında
appearance da gösterecekse `list()` kullanır.

### Thread safety semantiği

- `&ThemeRegistry`'den (paylaşımlı) **okunabilir ve yazılabilir**.
  `RwLock` iç-mutabilite veriyor; `&self` yetiyor `insert` için bile.
- `Arc<ThemeRegistry>` **`Send + Sync`** çünkü `RwLock` her ikisini
  veriyor.
- Lock hold süresi minimal — `insert`/`get` tek HashMap operation'u.
  Race condition yok.

> **Kilit zinciri uyarısı:** `registry.read()` guard'ı tutarken başka
> bir kilide girmek (örn. `GlobalTheme`) **deadlock riski** taşır.
> Tema değişim akışında: önce `registry.get()` çağır, döneni `Arc`
> olarak al, lock düşür, sonra `GlobalTheme::update_theme(...)` çağır.
> Mevcut API zaten bu deseni teşvik ediyor.

### Zed uyumlu tamamlanmış API

Zed-benzeri selector/settings/icon-theme akışı isteniyorsa aşağıdaki
metodlar opsiyonel değil, public runtime sözleşmesidir:

| Metod | Gerekçe |
|-------|---------|
| `default_global`, `try_global` | Init/test ve lazy setup akışları. |
| `insert_theme_families` | Built-in, user ve extension temalarını aile halinde eklemek. |
| `remove_user_themes` | Kullanıcı tema dizini yeniden tarandığında eski kullanıcı temalarını temizlemek. |
| `list` (`ThemeMeta`) | Selector/picker için ad + appearance metadata'sı. |
| `assets()` | Built-in tema, icon, SVG ve lisans dosyalarını tek asset kaynağından yüklemek. |
| `list_icon_themes`, `get_icon_theme`, `load_icon_theme` | Icon theme selector ve aktif icon theme reload akışı. |
| `remove_icon_themes` | Extension/user icon theme yenileme. |
| `extensions_loaded`, `set_extensions_loaded` | Extension temaları gelmeden önce fallback'e sessiz düşme, geldikten sonra gerçek hata loglama. |

Bu metodlardan birini public API'ye almıyorsan bunu kapsam dışı tasarım
kararı olarak ele al. "Şimdilik UI yok" dışlama gerekçesi değildir;
selector UI sonra gelse bile registry sözleşmesi hazır olmalı.

### Tuzaklar

1. **`get(name: &str)` vs `get(&SharedString)`**: İmza `&str` aldığı
   için caller'lar `&"...".into()` yazmaz; `"...".into()` veya literal
   geçer. HashMap key `SharedString` ama `Borrow<str>` impl'i sayesinde
   `&str` ile lookup çalışır.
2. **`insert` race condition**: İki thread aynı anda aynı isimle insert
   yaparsa hangisinin kazanacağı tanımsız — `RwLock::write()` sıraya
   sokar, son giren kazanır. Bu mantıken kabul edilebilir.
3. **`global(cx)` panic**: Registry init edilmemişse panic. `kvs_tema::init()`
   uygulama başında çağrılmalı. Test ortamında `set_global` manuel.
4. **`Arc<ThemeRegistry>`'i parametre olarak almak vs `cx`**: API
   `ThemeRegistry::global(cx)` deseni; `&Arc<ThemeRegistry>` parametre
   geçmek de mümkün ama tüketici kodunu bağlar. Genelde `cx` üzerinden
   eriş.
5. **`SharedString` case sensitive**: "Kvs Default" ve "kvs default" iki
   ayrı key (Bölüm III/Konu 7).
6. **Registry boş başlatmak ama aktif tema set etmemek**: registry
   `set_global` sonrası `cx.set_global(GlobalTheme::new(default, default_icon))`
   çağrısı şart. Aksi halde `cx.theme()` veya `GlobalTheme::icon_theme(cx)`
   panic eder.

---

## 34. `GlobalTheme` ve `ActiveTheme` trait

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`GlobalTheme` aktif UI temasını ve aktif icon temasını taşıyan global.
`ActiveTheme` trait'i Zed'de yalnızca `cx.theme()` ergonomisini sağlar.
Icon tema ayrı registry'de tutulsa bile aktif seçim aynı global
altında saklanır; böylece settings değişiminde UI ve icon refresh aynı
akıştan geçer.

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

`Theme` ve `IconTheme` doğrudan global yapılmaz; newtype wrapper
(Bölüm III/Konu 10 kuralı). Alanlar private — dışarıdan
`theme`/`icon_theme` ve update metotlarıyla erişilir.

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

- `cx.global::<Self>()` global'i okur; yoksa panic.
- `&Arc<Theme>` döner — clone'a gerek yok; caller refcount artırmadan
  okur.

**`icon_theme(cx)`:**

- Aktif icon tema'yı döner.
- File tree, picker, tabs ve explorer icon çözümü bu değeri okur.

**İlk kurulum:**

- Zed public API'de `set_theme_and_icon` metodu yoktur.
- `init` sırasında `cx.set_global(GlobalTheme::new(theme, icon_theme))`
  çağrılır.
- Global ilk kez kurulurken iki aktif değer de hazır olmalıdır.

**`update_theme` / `update_icon_theme`:**

`init-or-update` deseni (Bölüm III/Konu 10):

- `init` global'i `GlobalTheme::new` + `cx.set_global` ile kurar.
- Sonraki değişimler `update_global` ile yapılır — mevcut instance mutate edilir,
  `Drop` çalışmaz (eski `Arc<Theme>` refcount azalır, başkası
  tutmuyorsa drop).

> **Neden `update_global` mutate yerine yeni `set_global` değil?**
> İki davranış görünür aynı ama:
> - `set_global` global tipini **kontrolsüz değiştirir** — observer'lar
>   bilgilendirilmez.
> - `update_global` callback içinde GPUI'nin observer mekanizması
>   tetiklenir (örn. `cx.observe_global::<GlobalTheme>(|_, _| {})`).
>
> Tema değişim observer'ı yoksa fark yok; ama olur diye `update_global`
> tercih.

`kvs_tema` isterse yerel convenience metotları ekleyebilir; bunlar Zed
public yüzeyinde olmadığı için yerel genişletme olarak değerlendirilir.
Önerilen adlandırma:

| Yerel ad | Davranış | Neden bu ad |
|----------|----------|-------------|
| `install_or_update_theme(cx, theme)` | `has_global`'a göre `set_global` veya `update_theme` çağırır | `set_theme` adı `theme_settings::settings::set_theme` (Konu 39) ile çakışır — namespace karışıklığı bug çıkarır |
| `install_or_update_icon_theme(cx, icon)` | Aynı desen, icon tarafı | Aynı gerekçe |
| `install_active(cx, theme, icon)` | `cx.set_global(GlobalTheme::new(...))` çağrısının okunabilir alias'ı | İlk init'i tek satıra indirir |

Init öncesinde `GlobalTheme::update_theme` ya da bu yerel sarmalayıcılar
çağrılırsa global yokluğu nedeniyle panic eder.

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

**Önemli sözleşme notu:** Zed'de `ActiveTheme` trait'i **yalnızca**
`theme()` metoduna sahiptir; `icon_theme()` trait'in parçası **değildir**.
Aktif icon tema'ya erişim `GlobalTheme::icon_theme(cx)` üzerinden
yapılır — `cx.icon_theme()` Zed paritesinde doğrudan çalışmaz.

**`kvs_tema` için iki seçenek:**

1. **Paritede kal** — trait'i Zed gibi tek metotlu tut; icon tema'ya
   `GlobalTheme::icon_theme(cx)` veya bağımsız `IconActiveTheme` trait
   üzerinden eriş:

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

2. **`kvs_tema` ek metot olarak `icon_theme` koy** — Zed paritesini
   genişletmek anlamına gelir; bu durumda trait Zed'den farklı, iki
   metotlu bir yerel API olur.

Rehberin örnekleri Seçenek 1'i varsayar; aktif icon tema için
`GlobalTheme::icon_theme(cx)` kullanılır. Seçenek 2 uygulanırsa ilgili
çağrılar `cx.icon_theme()` olarak kısaltılabilir.

**Mantık:**

- Trait, **extension method** sağlar — `App` üzerinde `cx.theme()` çağrısı
  mümkün hale gelir.
- `Context<T>: Deref<Target = App>` (Bölüm III/Konu 9) sayesinde
  `cx.theme()` `Context<T>` üzerinden de çalışır — trait impl'ine gerek
  yok; deref coercion yeterli.
- `AsyncApp` üzerinde `theme()` çalışmaz çünkü `AsyncApp` `&App`'e
  doğrudan deref etmez; gerekirse `cx.try_global::<GlobalTheme>()`
  manuel.

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

`use kvs_tema::ActiveTheme;` zorunlu — trait method'u görünür olmaz
import olmadan. Tipik pattern: prelude module ekle.

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

`styles` alanı crate-içi olduğu için tüketicinin kararlı okuma yolu
Konu 12'deki accessor'lardır:

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

UI bileşeni tema değişimini izlemek isterse:

```rust
impl AnaPanel {
    fn new(cx: &mut Context<Self>) -> Self {
        // Tema değişince notify
        cx.observe_global::<GlobalTheme>(|_, cx| cx.notify()).detach();
        Self
    }
}
```

`cx.observe_global` `Subscription` döner; `.detach()` zorunlu yoksa
observer ölür.

Ama dikkat: `cx.refresh_windows()` (Konu 38) zaten tüm view'ları yeniden
çiziyor; explicit observer çoğu zaman gereksiz. Sadece tema veya icon
tema değişiminde özel state güncellemek istiyorsan kur.

### Tuzaklar

1. **`theme(&Arc<Theme>)` clone**: `cx.theme()` zaten `&Arc<Theme>`
   döndürüyor; üzerinde `.clone()` çağırırsan gereksiz refcount artışı.
   `let tema = cx.theme();` direkt yeterli.
2. **`use kvs_tema::ActiveTheme` unutmak**: Trait import edilmemişse
   `cx.theme()` "method not found" hatası. Prelude kullan.
3. **Global'i icon temasız kurmak**: Aktif icon tema yoksa explorer
   render'ı fallback path üretemez. `init` içinde default icon tema'yı
   mutlaka kur.
4. **`update_theme` callback boş**: `update_global::<Self, _>(|this, _| ...)`
   callback'inde sadece field mutate et; başka global'i set etmeye
   çalışırsan re-entrancy panic.
5. **Theme parametresini `Theme` yapmak**: `update_theme(cx, theme: Theme)`
   yazsaydın her çağrıda klon olurdu. `Arc<Theme>` zorunlu.
6. **`observe_global` `.detach()` unutmak**: Subscription drop olursa
   observer ölür; tema değişince bileşen yenilenmez.

---

## 35. `SystemAppearance` ve sistem mod takibi

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

OS'un light/dark mod tercihini taşır. Tema seçim mantığı bunu okur ve
uygun varyantı yükler.

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

- `SystemAppearance(pub Appearance)` — `Appearance` (Bölüm IV/Konu 16)
  newtype'ı; `Default` `Self(Appearance::Dark)` döner.
- `Deref<Target = Appearance>` impl'i sayesinde `system.is_light()` gibi
  Appearance metotları doğrudan çalışır — `.0` patlatmaya gerek yok.
- `Copy` çünkü `Appearance` `Copy`. Ucuz değer-geçirim.
- `GlobalSystemAppearance` `Default` türetir ve `Deref/DerefMut` ile
  newtype'ı tutucu olarak şeffaflaştırır.

> **Neden `Appearance` doğrudan global değil?** `Appearance` enum'u
> başka anlamlarda da kullanılır (tema'nın nominal modu, JSON deserialize
> hedefi). Global anahtarı **sistem-spesifik** kalsın: `SystemAppearance`
> sadece "OS şu an ne diyor?" sorusunu cevaplar.

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

> **`init` `default_global` ile çalışır:** `set_global` yerine
> `default_global` kullanıldığında, bağlamda global yoksa
> `Default::default()` (yani `SystemAppearance(Appearance::Dark)`)
> oluşturulup üstüne yazılır. İkinci `init` çağrısı eski global'i drop
> etmek yerine mevcut yerinde günceller — observer'lar tetiklenir.

**`init(cx)`:**

- `cx.window_appearance()` (Bölüm III/Konu 8) sorgular.
- `WindowAppearance` 4 variant'tan birini döner; `Vibrant*` macOS-özgü
  ama tema seçiminde Light/Dark ile aynı kategoride.
- Match ifadesi dört variant'ı iki kategoride birleştirir.
- `set_global` ile kurulur.

**`global(cx)`:**

- `cx.global::<GlobalSystemAppearance>()` → `&GlobalSystemAppearance`.
- `.0` newtype'ı açar — `SystemAppearance` `Copy` olduğu için değer
  döner.

### Sistem mod değişimini izleme (public API)

`init` sadece **başlangıçta** çağrılır. OS theme değişimini takip etmek
için observer şart; ama observer kurmak `Window` referansı ister ve
`init` `&mut App` aldığı için bunu içeride yapamaz. Tüketici pencere
açıldıktan sonra ayrı bir public fonksiyon çağırır:

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

- **Adım 1 (`init`)**: Sistem mod'unun **anlık değerini** yakalar
  (`cx.window_appearance()` `&App` üzerinden çalışır).
- **Adım 2 (`observe_system_appearance`)**: Mod **değişimini** dinler
  (`cx.observe_window_appearance` `Window` ister).

Tüketici Adım 2'yi atlayabilir — sistem mod'u "set once" olarak kalır
ve uygulama yaşadığı sürece ilk değerinde donar. Bu kasıtlı bir seçim
olabilir; ama otomatik tema takibi isteniyorsa observer şart.

> **`.detach()` zorunlu:** `cx.observe_window_appearance` `Subscription`
> döner; drop edilirse observer ölür (Bölüm III/Konu 10 tuzak 5).
> `observe_system_appearance` fonksiyonu zaten `.detach()` çağırır;
> tüketicinin elle çağırmasına gerek yok.

### Sistem'den tema seçme örneği

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

> **Tema adı sabit string olarak yazmak:** "Kvs Default Dark"
> tipo'ya açık. Production'da:
> - Sabitler modülü: `pub const DEFAULT_DARK: &str = "Kvs Default Dark";`
> - Veya kullanıcı ayarlarından (`SettingsTema { dark_default: String,
>   light_default: String }`).

### `Appearance` vs `SystemAppearance` vs `WindowAppearance` ayrımı

| Tip | Anlamı | Kaynak |
|-----|--------|--------|
| `WindowAppearance` (GPUI) | OS'un raporladığı raw mode (Light/Dark/Vibrant*) | `cx.window_appearance()` |
| `SystemAppearance` (tema) | OS modunun **iki kategoriye** indirgenmiş hali (Light/Dark) | `SystemAppearance::init` |
| `Appearance` (tema) | Bir **tema'nın nominal modu** | `Theme.appearance` |

Üçü farklı kavramlar; karıştırma:

- Kullanıcı sistem Dark modda ama explicit Light tema seçti →
  `SystemAppearance::Dark` ve `cx.theme().appearance == Light`.
- macOS Vibrant'a geçti → `WindowAppearance::VibrantDark` ama
  `SystemAppearance::Dark` (kategori indirme).

### Tuzaklar

1. **`init` tek seferlik**: Sistem mod değişirse `init` tekrar
   çağrılmaz. Observer kur.
2. **`SystemAppearance` `Copy` ama `GlobalSystemAppearance` değil**:
   Newtype `Copy` türetmez (`Global` `Copy` gerektirmez); ama içindeki
   `SystemAppearance` Copy olduğu için `.0` `Copy` döner. Bu kasıtlı.
3. **Vibrant variant'ları görmezden gelmek**: `match` ifadesinde `_ =>
   Light` veya `_ => Dark` yazmak macOS'ta yanlış kategori. Tüm 4
   variant'ı listele.
4. **Sistem moduna **zorla** uymak**: Kullanıcı manuel tema seçmiş
   olabilir; sistem mod değişimini direkt uygulamak kullanıcı tercihini
   ezer. Ayar:
   ```rust
   pub struct AyarlarTema {
       pub mod_takibi: bool,  // false ise sistem mod'unu yok say
       pub ad: Option<String>,
   }
   ```
5. **`SystemAppearance::global(cx)` init'siz erişim panic**: Zed'de
   `SystemAppearance` `Default` (`Appearance::Dark`) türetir; ama
   `global(cx)` `cx.global::<...>` çağırdığı için bağlamda kayıt yoksa
   panic eder. `default_global(cx)` veya `init(cx)` ile önce kurun.
   Init sırası `init()` fonksiyonu içinde garantili.

---

## 36. `init()` ve `LoadThemes`: kuruluş sırası, fallback ve yükleme modu

**Kaynak modül:** `kvs_tema/src/runtime.rs`.

`kvs_tema::init(cx)` — runtime'ın **tek giriş noktası**. Uygulamanın
başında, pencere açılmadan **mutlaka** çağrılır.

### Tam kod

`kvs_tema::init` Zed paritesi için `LoadThemes` enum'unu alır (Konu 43.1):

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

    // `ThemeRegistry::set_global` Zed'de `pub(crate)`. `kvs_tema`'da
    // mirror'da public yaparsan tüketici tarafa açık olur; aksi halde
    // global'i yalnızca bu `init` fonksiyonu kurar.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(default, default_icon));
}
```

> **İki katmanlı init paritesi:** Zed bu kuruluşu **iki adımda** yapar.
> `theme::init` (yukarıdaki akışla aynı, font cache + registry + fallback
> dark) çağrıldıktan sonra üst seviyede `theme_settings::init`
> (`theme_settings/src/theme_settings.rs:68`) çağrılır; o adım
> `set_theme_settings_provider` ile typography/density provider'ını kurar,
> `LoadThemes::All` ise `load_bundled_themes` ile `assets/themes/*.json`
> altındaki bundled tema asset'lerini yükler, `configured_theme(cx)` ile
> settings dosyasından gelen seçimi çözer ve `GlobalTheme::update_theme` + `update_icon_theme` ile
> aktif tema'yı **fallback dark'tan settings'in istediği temaya** geçirir.
> Kullanıcı disk temaları bu adımın parçası değildir; onlar
> `load_user_theme(registry, bytes)` / `deserialize_user_theme(bytes)`
> yoluyla ayrıca registry'ye eklenir.
> Mirror tarafta bu ayrımı koru: `kvs_tema::init` registry + GlobalTheme
> default'unu kurar, `kvs_tema_ayarlari::init` provider + settings observer
> + configured_theme akışını kurar. Tek init'te birleştirmek `kvs_tema`'yı
> settings crate'ine zorunlu bağımlı yapar (Konu 5 bağımlılık matrisi
> kararıyla çelişir).

### 5 adımlı kuruluş

**Adım 1 — `SystemAppearance::init(cx)`:**

Sistem mod sorgulanır ve global kurulur. **İlk** adım çünkü bundan
sonraki adımlar isterse sistem mod'una bakabilir (`init` sırasında değil
ama observer eklenirken).

**Adım 2 — Registry yaratma:**

```rust
let registry = Arc::new(ThemeRegistry::new(assets));
```

`Arc` çünkü global'e konacak. `ThemeRegistry::new(assets)` `AssetSource`
zorunlu alır; testte `Box::new(()) as Box<dyn AssetSource>` geçirilir.
Yapıcı zaten içinde `insert_theme_families([zed_default_themes()])`
çağırır ve default icon tema'yı ekler — yani `new` ile dönen registry
hiç boş değildir.

**Adım 3 — Fallback temaları insert:**

```rust
registry.insert_themes([
    crate::fallback::kvs_default_dark(),
    crate::fallback::kvs_default_light(),
]);
```

İki "default" tema her zaman registry'de. Sebebi:

- Kullanıcı tema yükleme akışı bozulursa bile **uygulama yine çalışır**.
- `cx.theme()` ve `GlobalTheme::icon_theme(cx)` panic edemez; her zaman geçerli tema olur.
- Sistem light/dark mod değişiminde her zaman bir hedef tema var.

**Adım 4 — Default seçimi:**

```rust
let default = registry
    .get("Kvs Default Dark")
    .expect("default tema kayıtlı olmalı");
let default_icon = registry
    .default_icon_theme()
    .expect("default icon tema kayıtlı olmalı");
```

`.expect()` kullanımı kasıtlı — bu **mantıksal invariant**: az önce
UI fallback temalarını insert ettik ve registry default icon tema'yı
kurdu; eksik olamaz. Eksikse programatik hata (typo veya init bug'ı);
panic acceptable.

> Alternatif: `SystemAppearance` baz alarak başlangıç temasını seç:
> ```rust
> let default_name = match SystemAppearance::global(cx).0 {
>     Appearance::Dark => "Kvs Default Dark",
>     Appearance::Light => "Kvs Default Light",
> };
> let default = registry.get(default_name).expect("...");
> ```
> Bu sürüm OS mod'unu hemen yansıtır. Tercih senin; varsayılan dark
> bilinçli karar olabilir.

**Adım 5 — Global'leri kur:**

```rust
// ThemeRegistry::set_global Zed'de pub(crate) ve Box<dyn AssetSource>
// alır (içeride GlobalThemeRegistry newtype'ını oluşturur). Mirror tarafta
// newtype'ı kendin set ederek aynı sözleşmeyi kuruyorsun.
cx.set_global(GlobalThemeRegistry(registry.clone()));
cx.set_global(GlobalTheme::new(default, default_icon));
```

Sıra önemli: önce registry global kurulur, sonra aktif UI tema + aktif
icon tema aynı `GlobalTheme` içinde kurulur. `cx.theme()` ve
`GlobalTheme::icon_theme(cx)` bundan sonra güvenlidir.

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
| Fallback tema yüklenmediyse | `expect` panic | Code review — `kvs_default_*` fonksiyonları statically erişilebilir; runtime hatası imkansız |
| `cx.window_appearance()` panic eder mi? | Hayır, default `Light` döner | — |
| `cx` zaten init edilmiş ise (`init` iki kez çağrıldı) | `set_global` sessizce üzerine yazar; eski registry/theme drop | İki kez çağırma, mantıksız |
| `kvs_tema::init` çağrılmadan `cx.theme()` / `GlobalTheme::icon_theme(cx)` | Panic: "global not found" | Init'i ilk satıra koy |

### Genişletilmiş init varyasyonları

**1. Bundled tema yükleme:**

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

`init`'ın temel kontratı korunur; bundled yükleme **opsiyonel**. Hata
olsa bile uygulama açılır (fallback temalar yeterli).

**2. Async user theme load:**

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

User theme yükleme **disk I/O** içerdiğinden async; init'ı bloklamaz.

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

1. **`init`'i pencere içinde çağırmak**: `Context<T>::update` callback'inde
   `init(cx)` mantıksız — pencere zaten render başladığında `cx.theme()`
   çağırıyor. Init Application root'unda.
2. **`init` async yapmak**: `init` `&mut App` alıyor; async olamaz. Async
   yükleme (kullanıcı tema dosyaları, network) `spawn` ile **init
   sonrası**.
3. **Birden fazla `init` çağrısı**: İdempotent değil — registry ve aktif
   tema sıfırlanır. Yapma.
4. **`init` yokken `cx.theme()`**: Panic mesajı `"global not found:
   GlobalTheme"`. Hata mesajı uyarıcı; init'i ekle.
5. **Default tema seçiminde fallback olmadan**: `registry.get("Yok").expect()`
   panic. Sadece insert ettiğin temaları seç.
6. **Fallback'leri kaldırmak**: User theme'ler yüklendikten sonra
   "Kvs Default *" temaları gereksiz görünebilir; **kaldırma**.
   Kullanıcı temasının yüklemesi başarısız olduğunda son çare.

### `LoadThemes` — yükleme modu enum'u

**Kaynak:** `crates/theme/src/theme.rs:81`.

Zed'in `init` fonksiyonu hangi temaların `crates/theme/assets/themes/`
altından yükleneceğini bir enum ile kontrol eder:

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

    // Zed'de set_global pub(crate); mirror'da newtype'ı kendin set
    // edersin veya `init` içeride kalan tek çağıran olur.
    cx.set_global(GlobalThemeRegistry(registry.clone()));
    cx.set_global(GlobalTheme::new(default, default_icon));
}
```

**Ne zaman `JustBase`?**

- Test ortamları (`#[gpui::test]` bağlamında bundled asset'lere gerek yok).
- Headless CLI / batch işler (registry sadece program içi kullanım).
- Minimal binary çıkışı (önyükleme süresini düşürmek).

**Ne zaman `All(...)`?**

- Production uygulama girişi.
- Geliştirme çalışmaları (bundled tema fixture'larıyla doğrulama).

**Yapısal not:** `LoadThemes::All(Box<dyn AssetSource>)` enum içinde
`AssetSource` taşır; `init` çağrısı sırasında `Application::new().with_assets(...)`
ile geçen aynı asset source'u tekrar geçmek zorunda değilsin —
`cx.asset_source()` üzerinden dolaylı erişim de olur. Hangi yolu
seçtiğini Bölüm VI/Konu 26'teki bundling stratejisi belirler.

---

## 37. `font_family_cache` — font ailesi önbellek

**Kaynak:** `crates/theme/src/font_family_cache.rs:18`.

Zed sistem font ailelerini her sorguda yeniden almak yerine bir global
önbellekte tutar:

```rust
pub struct FontFamilyCache {
    state: Arc<RwLock<FontFamilyCacheState>>,
}
```

**Rol:** Settings UI'da font seçici dropdown'u, kullanıcının makinasındaki
fontların listesini gösterir. OS sorgusu pahalı; cache asenkron olarak
init edilir ve sonrasında bellek üzerinden okunur.

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

**Tema sözleşmesindeki yer:** Yok — bu tip `kvs_tema` kapsamı dışında
kalabilir. Font ailesi listesini kullanan settings/picker bileşeni
gerekirse `kvs_settings` veya `kvs_ui` crate'inde benzer bir cache
implement edilir.

**Atlama gerekçesi:** Mirror disiplini (Konu 2) `Theme` ve içerdiği
tipleri zorunlu kılar; `FontFamilyCache` bir runtime önbelleği,
sözleşmenin parçası değil.

---

## 38. Tema değiştirme ve `cx.refresh_windows()`

Tema değişimi **iki adımlık** bir işlem: aktif tema güncelle +
pencereleri yenile. Eksik bırakırsan UI eski renkte kalır.

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

- `registry.get(ad)` `Result<Arc<Theme>, ThemeNotFoundError>` döner.
- `?` operatörü hatayı caller'a propagate eder.
- Tema bulunamazsa `ThemeNotFoundError` döner — caller bunu loglar veya
  UI'da gösterir (toast: "Tema bulunamadı: X").

**Adım 2 — Global update:**

```rust
GlobalTheme::update_theme(cx, yeni);
```

`init-or-update` pattern (Konu 34). İlk çağrıda kurar, sonraki çağrılarda
mutate eder. `observe_global::<GlobalTheme>` observer'ları (varsa)
tetiklenir.

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
| GPU resource (textures, font atlas) | **Reuse** edilir; sadece layout + paint tekrar |
| `cx.notify()` ile fark | `notify()` lokal entity, `refresh_windows()` global tüm pencereler |

**Maliyet:**

- Frame budget tipik 16 ms (60 fps); refresh maliyeti ~2-5 ms (içerik
  karmaşıklığına bağlı).
- Kullanıcı tema değiştirir, bir frame geçer, yeni renk görünür.
  Gözlemlenebilir gecikme yok.

### Helper fonksiyon önerisi

`temayi_degistir`'i helper olarak sar — her tüketici kod tekrar
yazmasın:

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

Tüketici:

```rust
use kvs_tema::temayi_degistir;

fn handle_tema_secimi(secilen: &str, cx: &mut App) {
    if let Err(e) = temayi_degistir(secilen, cx) {
        // toast: "Tema değiştirilemedi: ..."
    }
}
```

### Tuzaklar

1. **`refresh_windows` çağırmamak**: En yaygın bug. UI eski renkte kalır
   ta ki sonraki etkileşime kadar (örn. hover). Helper fonksiyona sar.
2. **`cx.notify()` ile yetinmek**: `notify` lokal entity — tüm view'ları
   yenilemez. Tema için `refresh_windows` şart.
3. **Reload sonrası `aktif_ad` lookup yine başarısız**: Tema dosyasından
   o isim silindi. `get(&aktif_ad).is_err()` ise default fallback'e
   düş:
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
4. **Frame budget aşımı**: Çok karmaşık UI'da `refresh_windows` 16 ms'yi
   aşabilir; bir frame skip görünebilir. Profile et; gerçek bir bug.

---

