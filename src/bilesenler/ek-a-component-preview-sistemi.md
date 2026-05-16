# Ek A. Component Preview Sistemi

Component preview sistemi, bileşen varyantlarını Zed'in içinde görsel olarak
incelemek için kullanılır. Bu sistem `crates/component` crate'i tarafından
yönetilir ve üç ana parçadan oluşur: `Component` trait'i, `ComponentRegistry`
global'i ve `single_example` ile `example_group_with_title` gibi layout
helper'ları.

Zed uygulamasında bu sistem iki seviyede ele alınır:

- `workspace::init(app_state, cx)` içinde `component::init()` çağrılır.
  Bu çağrı, `inventory::iter::<ComponentFn>()` ile `RegisterComponent`
  derive'larından gelen kayıt fonksiyonlarını çalıştırır ve
  `COMPONENT_DATA` registry'sini doldurur.
- `crates/zed/src/main.rs`, normal uygulama açılışında
  `component_preview::init(app_state.clone(), cx)` çağrısını yapar.
  Standalone preview örneği de aynı şekilde önce `component::init()`,
  sonra settings ve theme init, ardından workspace init ve son olarak
  `component_preview::init(...)` sırasını izler.
- `ComponentPreview::new(...)`, registry'yi `components()` ile okur;
  `sorted_components()` ve `component_map()` değerlerini kendi view
  state'ine alır. Filtre editor'ü için
  `InputField::new(window, cx, "Find components or usages…")` kurar ve
  listeyi `ListState` üzerinden sanallaştırır.
- Render tarafında preview sayfası `ComponentMetadata::preview()`
  callback'ini çağırır. Callback `None` döndürürse, component registry'de
  kayıtlı kalmaya devam eder ama gallery'de bir örnek alanı çizmez.
  `AgentSetupButton` bu davranışın bilinçli bir örneğidir.

Bu nedenle uygulama içi component sistemi bir runtime UI dependency injection
mekanizması değildir. Asıl görevi **görsel inceleme ve dokümantasyon
registry'si** olmaktır. Production ekranları bileşenleri doğrudan `ui::Button`,
`ui::ContextMenu`, `ui::Table` gibi builder'larla kullanır. Component registry
yalnızca preview tool'u, dokümantasyon ve arama ekranları için devrede tutulur.

`ui::prelude::*` yalnızca `Component`, `ComponentScope`, `example_group`,
`example_group_with_title`, `single_example` ve `RegisterComponent` derive
makrosunu getirir. Programatik registry erişimi (`ComponentRegistry`,
`ComponentMetadata`, `ComponentStatus`, `ComponentId`, `register_component`,
`empty_example`, `ComponentExample`, `ComponentExampleGroup`, `ComponentFn`)
gerektiğinde `use component::*;` veya doğrudan tek tek import kullanılır.

`Component` trait'inin tam yüzeyi şu metotları içerir; her biri opsiyoneldir
ve derive makrosu varsayılan implementasyon sağlar:

| Metot | Dönen | Varsayılan | Kullanım |
| :-- | :-- | :-- | :-- |
| `id() -> ComponentId` | `ComponentId(name)` | Otomatik | Registry lookup'u için stabil bir kimlik; aynı görünür ada sahip iki bileşeni ayırt etmek için override edilir |
| `scope() -> ComponentScope` | `ComponentScope::None` | Override edilir | Gallery'de grup başlığını belirler |
| `status() -> ComponentStatus` | `ComponentStatus::Live` | İhtiyaca göre | Gallery filtreleme ve "production'a hazır mı" işareti |
| `name() -> &'static str` | `type_name::<Self>()` | Genelde override | Gallery'de görünen ad; `type_name` modül yolunu da içerir |
| `sort_name() -> &'static str` | `Self::name()` | Bilinçli sıralama istendiğinde override | İlişkili bileşenleri sıralı tutmak için (örn. `ButtonA`, `ButtonB`, `ButtonC`) |
| `description() -> Option<&'static str>` | `None` | Doc comment veya elle string | `documented::Documented` derive ile doc comment otomatik bir description'a dönüşür |
| `preview(window, cx) -> Option<AnyElement>` | `None` | Genelde override | Gallery'de gösterilen örnek alanı |

`ComponentScope` enum'unun tüm variant'ları, yani gallery'deki grup
başlıkları aşağıdaki gibidir:

```text
Agent, Collaboration, DataDisplay ("Data Display"), Editor,
Images ("Images & Icons"), Input ("Forms & Input"),
Layout ("Layout & Structure"), Loading ("Loading & Progress"),
Navigation, None ("Unsorted"), Notification,
Overlays ("Overlays & Layering"), Onboarding, Status,
Typography, Utilities, VersionControl ("Version Control")
```

`ComponentStatus` variant'ları ve anlamları:

| Variant | Anlam | Gallery davranışı |
| :-- | :-- | :-- |
| `Live` (varsayılan) | Üretimde kullanılabilir | Normal olarak listelenir |
| `WorkInProgress` | Hâlâ tasarlanıyor veya kısmi olarak implement edilmiş | "WIP" badge'i; üretim kodunda kullanılmamalı |
| `EngineeringReady` | Tasarım tamamlanmış, implementasyon bekleniyor | "Ready to Build" badge'i |
| `Deprecated` | Yeni kodda kullanılmamalı | Uyarı badge'i; ileride kaldırılabilir |

Preview'a dahil edilecek küçük bir örnek component şu yapıyı izler:

```rust
use ui::component_prelude::*;
use ui::prelude::*;

#[derive(IntoElement, RegisterComponent)]
struct ExampleButtonSet;

impl RenderOnce for ExampleButtonSet {
    fn render(self, _window: &mut Window, _cx: &mut App) -> impl IntoElement {
        h_flex()
            .gap_1()
            .child(Button::new("default", "Default"))
            .child(Button::new("primary", "Primary").style(ButtonStyle::Filled))
            .child(IconButton::new("settings", IconName::Settings))
    }
}

impl Component for ExampleButtonSet {
    fn scope() -> ComponentScope {
        ComponentScope::Input
    }

    fn preview(_window: &mut Window, _cx: &mut App) -> Option<AnyElement> {
        Some(
            example_group_with_title(
                "Buttons",
                vec![single_example("Button set", ExampleButtonSet.into_any_element())],
            )
            .into_any_element(),
        )
    }
}
```

Preview kodunda `scope()` çağrısı, bileşenin gallery'de hangi grupta
gösterileceğini belirler. `preview()` herhangi bir `AnyElement` döndürebilir.
Tek bir örnek için `single_example`, ilişkili varyantları gruplayarak göstermek
için `example_group_with_title` kullanılır.

Preview'ları Zed reposunda görsel olarak incelemek için aşağıdaki komut
çalıştırılır:

```sh
cargo run -p component_preview --example component_preview
```

Çalıştırılan örnek pencere, `RegisterComponent` derive ile kayda
alınmış tüm bileşenleri sol panelden gezilebilir kategoriler altında
(`ComponentScope`) listeler. Yeni bir bileşene preview eklendiğinde
derive makrosu kaydı kendisi yapar; ayrı bir kayıt çağrısına ihtiyaç
kalmaz. Preview için doğrudan `impl Component` yazılan tipler (struct
olmadan) gallery'ye eklenmez. Bu yüzden en az boş bir
`#[derive(IntoElement, RegisterComponent)] struct ExampleComponent;`
ile sarılması gerekir.

**Programatik registry erişimi.** Bir component preview tool'u,
dokümantasyon üretici veya custom gallery yazılıyorsa `component`
crate'inin registry API'sine doğrudan erişilebilir:

```rust
use component::{
    ComponentId, ComponentMetadata, ComponentRegistry, ComponentScope,
    ComponentStatus, components, init as init_components, register_component,
};

fn list_registered_buttons() {
    init_components();
    let registry: ComponentRegistry = components();

    for meta in registry.sorted_components() {
        if meta.scope() != ComponentScope::Input {
            continue;
        }
        if meta.status() != ComponentStatus::Live {
            continue;
        }
        println!(
            "{} ({}): {}",
            meta.name(),
            meta.id().0,
            meta.description().unwrap_or_else(|| "—".into()),
        );
    }
}
```

`ComponentRegistry` yüzeyi şu metotları içerir:

| Metot | Dönen | Kullanım |
| :-- | :-- | :-- |
| `previews() -> Vec<&ComponentMetadata>` | Preview verilmiş bileşenler | Gallery liste kaynağı |
| `sorted_previews() -> Vec<ComponentMetadata>` | Aynı, `sort_name`'e göre sıralı | Stabil sıralı liste |
| `components() -> Vec<&ComponentMetadata>` | Tüm kayıtlı bileşenler (preview'sız olanlar dahil) | Programatik inceleme |
| `sorted_components() -> Vec<ComponentMetadata>` | Aynı, sıralı | Stabil sıralı |
| `component_map() -> HashMap<ComponentId, ComponentMetadata>` | Id → metadata haritası | Lookup |
| `get(id) -> Option<&ComponentMetadata>` | Id ile lookup | Tek bileşen sorgusu |
| `len() -> usize` | Toplam kayıt sayısı | Test asersiyonu |

`ComponentMetadata` accessor'ları: `id()`, `name()`, `description()`,
`preview()`, `scope()`, `sort_name()`, `scopeless_name()`, `status()`.

`register_component::<T>()` çağrısı, `RegisterComponent` derive'ı
yapmayan tipler için manuel bir kayıt sunar. Derive zaten
kullanılıyorsa bu fonksiyonu çağırmaya gerek yoktur.
`init_components()` ise `inventory` ile toplanan otomatik kayıtları
çalıştırır ve registry global'ini hazırlar.

**Layout helper detayları.** Preview alanını kurarken üç farklı çıktı
tipi vardır:

```rust
use component::{
    ComponentExample, ComponentExampleGroup, empty_example,
    example_group, example_group_with_title, single_example,
};

// Tek varyant
let example: ComponentExample =
    single_example("Default", Button::new("d", "Default").into_any_element())
        .description("Birincil eylem için varsayılan stil.")
        .width(px(160.));

// Boş slot (henüz implement edilmemiş varyant)
let placeholder: ComponentExample = empty_example("Coming Soon");

// Başlıksız grup
let group: ComponentExampleGroup = example_group(vec![example, placeholder])
    .vertical();

// Başlıklı grup
let titled: ComponentExampleGroup = example_group_with_title(
    "Variants",
    vec![
        single_example("Subtle", Button::new("s", "Subtle").into_any_element()),
        single_example("Filled",
            Button::new("f", "Filled").style(ButtonStyle::Filled).into_any_element()),
    ],
)
.grow();
```

`ComponentExample` builder yüzeyi: `.description(text)`, `.width(pixels)`.
`ComponentExampleGroup` builder yüzeyi: `.width(pixels)`, `.grow()`,
`.vertical()` ile birlikte `with_title(title, examples)` constructor'ı.

`ComponentExample` public alanları: `variant_name`, `description`,
`element`, `width`. Normal kullanımda bu alanları doğrudan mutasyona
açmak yerine `single_example(...)`, `empty_example(...)`,
`.description(...)` ve `.width(...)` helper'larının kullanılması
beklenir. `variant_name` gallery'de görünen varyant başlığıdır; test ve
dokümantasyon üretici kodlarda doğrudan okunabilir.

`ComponentExampleGroup` public alanları: `title`, `examples`, `width`,
`grow`, `vertical`. Bunlar `RenderOnce` sırasında layout kararına
çevrilir; üretim preview kodunda builder metotlarının kullanılması daha
okunaklı bir sonuç verir.

**Component preview ile preview helper sözleşmesi.** Bir bileşenin
`preview()` metodu bir `Option<AnyElement>` döndürür. `None` döndürmek,
"bu bileşen registry'de kayıtlı ama gallery'de gösterilmesin" anlamına
gelir. Örneğin `AgentSetupButton` `impl Component` taşır ama
`preview()` `None` döner. Yine de `RegisterComponent` derive'ı sayesinde
`components()` ile listelenebilir kalır.

**`description()` ile doc comment otomasyonu.** `documented::Documented`
derive'ı eklendiğinde, bir doc comment `Self::DOCS` sabitinden okunur
ve description'a dönüşür:

```rust
use documented::Documented;

/// Birincil eylemler için varsayılan buton.
#[derive(IntoElement, RegisterComponent, Documented)]
struct PrimaryButtonExample;

impl Component for PrimaryButtonExample {
    fn description() -> Option<&'static str> {
        Some(Self::DOCS)
    }
}
```
