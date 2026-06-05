# Ek A. Component Preview Sistemi

Component preview sistemi, bileşen varyantlarını Zed'in içinde görsel olarak incelemek için kullanırsın. Bu sistem `component` crate'i tarafından yönetilir. Üç ana parçadan oluşur: `Component` trait'i, `ComponentRegistry` global'i ve `single_example` ile `example_group_with_title` gibi layout yardımcıları.

Zed uygulamasında bu sistem iki seviyede ele alırsın:

- `workspace::init(app_state, cx)` içinde `component::init()` çağırırsın. Bu çağrı, `inventory::iter::<ComponentFn>()` ile `RegisterComponent` derive'larından gelen kayıt fonksiyonlarını çalıştırır ve `COMPONENT_DATA` registry'sini doldurur.
- `zed` crate'i, normal uygulama açılışında `component_preview::init(app_state.clone(), cx)` çağrısını yapar. Ana `zed` uygulamasında sıra şöyledir: önce `settings::init` ve theme init tamamlanır; ardından `workspace::init(...)` çağrılır ve `component::init()` bu çağrının içinden, yani settings/theme init'inden sonra çalışır; en sonda `component_preview::init(...)` gelir. Standalone preview örneği ise bu bağımlılıkları kendi içinde daha sade bir akışla kurduğundan, orada `component::init()` çağrısını settings/theme kurulumundan önce de görebilirsin; bu sıralama yalnızca o örneğe özgüdür.
- `ComponentPreview::new(...)`, registry'yi `components()` ile okur; `sorted_components()` ve `component_map()` değerlerini kendi view durumuna alır. Filtre editor'ü için `InputField::new(window, cx, "Find components or usages…")` kurar; listeyi `ListState` üzerinden sanallaştırır.
- Render tarafında preview sayfası `ComponentMetadata::preview()` callback'ini çağırır. Bu callback `fn(&mut Window, &mut App) -> AnyElement` tipindedir; kayıtlı her component için çağrılabilir bir preview elementi beklenir. Anlamlı bir görsel örnek yoksa `empty_example(...)` veya küçük bir placeholder elementi component'in kendi `preview` metodunda döndürülür.

Bu nedenle uygulama içi component sistemi bir runtime UI dependency injection mekanizması değildir. Asıl görevi **görsel inceleme ve dokümantasyon registry'si** olmaktır. Production ekranları bileşenleri doğrudan `ui::Button`, `ui::ContextMenu`, `ui::Table` gibi builder'larla kullanır. Component registry yalnızca preview tool'u, dokümantasyon ve arama ekranları için devrede tutulur.

Component tarafında `ui::prelude::*`, `Component`, `ComponentScope`, `example_group`, `example_group_with_title`, `single_example` ve `RegisterComponent` derive makrosunu da getirir; aynı prelude GPUI ve temel UI yapı taşlarını da içerir. `ui::component_prelude::*` buna ek olarak `ComponentId`, `ComponentStatus` ve `documented::Documented` gibi component preview odaklı öğeleri taşır. Programatik registry erişimi (`ComponentRegistry`, `ComponentMetadata`, `register_component`, `empty_example`, `ComponentExample`, `ComponentExampleGroup`, `ComponentFn`) gerektiğinde `use component::*;` veya doğrudan tek tek import kullanırsın.

`component_preview` crate'inin kendi dışa açık yüzeyi ise preview tool'unun workspace item katmanıdır:

- `component_preview::init(app_state, cx)`: `OpenComponentPreview` action'ını ve `ComponentPreview` serializable item'ını workspace'e kaydeder.
- `ComponentPreview`: component registry'yi okuyan, filtre editor'ünü tutan ve preview sayfasını render eden workspace item'dır.
- `PreviewPage`: `AllComponents` veya `Component(ComponentId)` ile aktif görünümü temsil eder.
- `ActivePageId(pub String)`: restore/serialize sırasında aktif preview sayfasını saklayan persistence anahtarıdır; varsayılan değeri `"AllComponents"` olur.
- `ComponentPreview::active_page_id(cx) -> ActivePageId`: aktif sayfayı persistence anahtarına çevirir.
- `ComponentPreviewPage`: tek bir `ComponentMetadata` için preview alanını render eden iç sayfa component'idir; `ComponentPreviewPage::new(component, reset_key)` ile kurarsın.

Bu tipler production UI'da component seçmek için genel amaçlı bir API olarak kullanılmaz; Zed'in component preview paneline ve state restore akışına aittir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `component_preview` | modül export'u | Preview workspace item katmanının crate/modül yüzeyidir. |
| `ComponentPreview` | `new`, `active_page_id` ve workspace item state alanları | Registry'yi okuyan, filtreleyen ve aktif preview sayfasını render eden workspace item'dır. |
| `PreviewPage` | `AllComponents`, `Component(ComponentId)` | Sol navigasyonda tüm bileşenler veya tek bileşen sayfası seçimini taşır. |
| `ActivePageId` | `pub String`, `Default` | Restore/serialize sırasında aktif sayfa kimliğini saklar. |
| `ComponentPreviewPage` | `new(component, reset_key)` | Tek bir `ComponentMetadata` preview alanını render eden iç sayfa component'idir. |

`Component` trait'inin tam yüzeyi şu metotları içerir. Kimlik, scope, status ve isim metotlarının varsayılanları vardır; `description()` ve `preview(...)` ise trait sözleşmesinin zorunlu parçasıdır:

| Metot | Dönen | Varsayılan | Kullanım |
| :-- | :-- | :-- | :-- |
| `id() -> ComponentId` | `ComponentId(name)` | Otomatik | Registry lookup'u için sabit bir kimlik; aynı görünür ada sahip iki bileşeni ayırt etmek için override edilir |
| `scope() -> ComponentScope` | `ComponentScope::None` | `ComponentScope::None` | Gallery'de grup başlığını belirler; gruplamak istediğinde override edersin |
| `status() -> ComponentStatus` | `ComponentStatus::Live` | `ComponentStatus::Live` | Gallery filtreleme ve "production'a hazır mı" işareti; farklı bir durum gerektiğinde override edersin |
| `name() -> &'static str` | `type_name::<Self>()` | Genelde override | Gallery'de görünen ad; `type_name` modül yolunu da içerir |
| `sort_name() -> &'static str` | `Self::name()` | Bilinçli sıralama istendiğinde override | İlişkili bileşenleri sıralı tutmak için (örn. `ButtonA`, `ButtonB`, `ButtonC`) |
| `description() -> &'static str` | Açıklama metni | Zorunlu | `documented::Documented` derive ile doc comment `Self::DOCS` üzerinden açıklamaya dönüştürülebilir |
| `preview(window, cx) -> AnyElement` | Preview elementi | Zorunlu | Gallery'de gösterilen örnek alanı; boş durum için `empty_example(...)` döndürülebilir |

`ComponentScope` enum'unun tüm variant'ları ve kaynak `Display` çıktısındaki gallery grup başlıkları aşağıdaki gibidir:

```text
Agent, Collaboration, DataDisplay ("Data Display"), Editor,
Images ("Images & Icons"), Input ("Forms & Input"),
Layout ("Layout & Structure"), Loading ("Loading & Progress"),
Navigation, None ("Unsorted"), Notification,
Overlays ("Overlays & Layering"), Onboarding, Status,
Typography, Utilities, VersionControl ("Version Control")
```

`ComponentStatus` variant'ları ve anlamları:

| Varyant | Anlam | Galeri davranışı |
| :-- | :-- | :-- |
| `Live` (varsayılan) | Üretimde kullanabilirsin | Normal olarak listelenir |
| `WorkInProgress` | Hala tasarlanıyor veya kısmi olarak implement edilmiş | `"Work In Progress"` rozeti; üretim kodunda kullanılmamalı |
| `EngineeringReady` | Tasarım tamamlanmış, implementasyon bekleniyor | `"Ready To Build"` rozeti |
| `Deprecated` | Mevcut uygulama kodu için hedef yüzey değildir | Galeride uyarı rozetiyle gösterilir |

Preview'a dahil edilecek küçük bir örnek component şu yapıyı izler:

```rust
use ui::component_prelude::*;
use ui::prelude::*;

#[derive(IntoElement, RegisterComponent)]
struct OrnekButonKumesi;

impl RenderOnce for OrnekButonKumesi {
    fn render(self, _window: &mut Window, _cx: &mut App) -> impl IntoElement {
        h_flex()
            .gap_1()
            .child(Button::new("varsayilan", "Varsayılan"))
            .child(Button::new("birincil", "Birincil").style(ButtonStyle::Filled))
            .child(IconButton::new("ayarlar", IconName::Settings))
    }
}

impl Component for OrnekButonKumesi {
    fn scope() -> ComponentScope {
        ComponentScope::Input
    }

    fn description() -> &'static str {
        "Buton varyantlarını tek preview alanında gösterir."
    }

    fn preview(_window: &mut Window, _cx: &mut App) -> AnyElement {
        example_group_with_title(
            "Butonlar",
            vec![single_example("Buton kümesi", OrnekButonKumesi.into_any_element())],
        )
        .into_any_element()
    }
}
```

Preview kodunda `scope()` çağrısı, bileşenin gallery'de hangi grupta gösterileceğini belirler. `preview()` herhangi bir `AnyElement` döndürebilir. Tek bir örnek için `single_example`, ilişkili varyantları gruplayarak göstermek için `example_group_with_title` kullanırsın.

Preview'ları Zed reposunda görsel olarak incelemek için aşağıdaki komut çalıştırılır:

```sh
cargo run -p component_preview --example component_preview
```

Çalıştırılan örnek pencere, `RegisterComponent` derive ile kayda alınmış tüm bileşenleri sol panelden gezilebilir kategoriler altında (`ComponentScope`) listeler. Yeni bir bileşene preview eklendiğinde derive makrosu kaydı kendisi yapar; ayrı bir kayıt çağrısına ihtiyaç kalmaz. Bir tipin gallery'ye girmesi struct olmasına değil, kayda alınmasına bağlıdır: `RegisterComponent` derive'ı (veya elle yapılan bir `register_component::<T>()` çağrısı) olmayan tipler gallery'ye eklenmez. Bu yüzden en az boş bir `#[derive(IntoElement, RegisterComponent)] struct OrnekBilesen;` ile sarılması gerekir.

**Programatik registry erişimi.** Bir component preview tool'u, dokümantasyon üretici veya custom gallery yazılıyorsa `component` crate'inin registry API'sine doğrudan erişilebilir:

```rust
use component::{ComponentRegistry, ComponentScope, ComponentStatus, components, init as init_components};

fn canli_input_bilesenleri() -> Vec<String> {
    init_components();
    let kayit: ComponentRegistry = components();

    kayit
        .sorted_components()
        .into_iter()
        .filter(|ustveri| ustveri.scope() == ComponentScope::Input)
        .filter(|ustveri| ustveri.status() == ComponentStatus::Live)
        .map(|ustveri| {
            let aciklama = ustveri.description();
            format!("{} ({}): {}", ustveri.name(), ustveri.id().0, aciklama)
        })
        .collect()
}
```

`ComponentRegistry` yüzeyi şu metotları içerir:

| Metot | Dönen | Kullanım |
| :-- | :-- | :-- |
| `previews() -> impl Iterator<Item = &ComponentMetadata>` | Kayıtlı component metadata iterator'ı | Sıralanmamış ham metadata erişimi; gallery listesini bundan değil `sorted_components()`'tan kurar |
| `sorted_previews() -> Vec<ComponentMetadata>` | Aynı kayıtlar, `name()` değerine göre sıralı | Sabit sıralı liste |
| `components() -> Vec<&ComponentMetadata>` | Tüm kayıtlı bileşenler | Programatik inceleme |
| `sorted_components() -> Vec<ComponentMetadata>` | Aynı kayıtlar, `name()` değerine göre sıralı | Sabit sıralı |
| `component_map() -> HashMap<ComponentId, ComponentMetadata>` | Id → metadata haritası | Lookup |
| `get(id) -> Option<&ComponentMetadata>` | Id ile lookup | Tek bileşen sorgusu |
| `len() -> usize` | Toplam kayıt sayısı | Test asersiyonu |

`ComponentMetadata` accessor'ları: `id() -> ComponentId`, `name() -> SharedString`, `description() -> SharedString`, `preview() -> fn(&mut Window, &mut App) -> AnyElement`, `scope()`, `sort_name()`, `scopeless_name()`, `status()`.

`register_component::<T>()` çağrısı, `RegisterComponent` derive'ı yapmayan tipler için manuel bir kayıt sunar. Derive zaten kullanılıyorsa bu fonksiyonu çağırmaya gerek yoktur. `init_components()` ise `inventory` ile toplanan otomatik kayıtları çalıştırır ve registry global'ini hazırlar.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `COMPONENT_DATA` | `LazyLock<RwLock<ComponentRegistry>>` | Registry global'idir; tüketici kod bunun yerine `components()` ve registry accessor'larını kullanır. |
| `ComponentFn` | `new(fn())` | `inventory` ile toplanan kayıt fonksiyonu sarmalayıcısıdır. |
| `ComponentRegistry` | `previews`, `sorted_previews`, `components`, `sorted_components`, `component_map`, `get`, `len` | Kayıtlı component metadata listesini ve lookup haritasını sağlar. |
| `ComponentMetadata` | `id`, `description`, `name`, `preview`, `scope`, `sort_name`, `scopeless_name`, `status` | Bir component'in gallery metadata'sını ve preview callback'ini taşır. |
| `register_component` | `register_component::<T>()` | `Component` implement eden tipi manuel olarak registry'ye ekler. |
| `RegisterComponent` | derive macro | `register_component::<T>()` çağrısını `inventory` kaydı olarak üretir. |
| `ui_macros` | macro crate/modül | `RegisterComponent` derive makrosunun kaynak crate'idir. |

**Layout yardımcı detayları.** Preview alanını kurarken üç farklı çıktı tipi vardır:

```rust
use component::{
    ComponentExample, ComponentExampleGroup, empty_example,
    example_group, example_group_with_title, single_example,
};

// Tek varyant
let ornek: ComponentExample =
    single_example("Varsayılan", Button::new("varsayilan", "Varsayılan").into_any_element())
        .description("Birincil eylem için varsayılan stil.")
        .width(px(160.));

// Boş slot (henüz implement edilmemiş varyant)
let yer_tutucu: ComponentExample = empty_example("Yakında");

// Başlıksız grup
let grup: ComponentExampleGroup = example_group(vec![ornek, yer_tutucu])
    .vertical();

// Başlıklı grup
let baslikli: ComponentExampleGroup = example_group_with_title(
    "Varyantlar",
    vec![
        single_example("Sade", Button::new("sade", "Sade").into_any_element()),
        single_example("Dolu",
            Button::new("dolu", "Dolu").style(ButtonStyle::Filled).into_any_element()),
    ],
)
.grow();
```

`ComponentExample` builder yüzeyi: `.description(text)`, `.width(pixels)`. `ComponentExampleGroup` builder yüzeyi: `.width(pixels)`, `.grow()`, `.vertical()` ile birlikte `with_title(title, examples)` constructor'ı.

`ComponentExample` dışa açık alanları: `variant_name`, `description`, `element`, `width`. Normal kullanımda bu alanları doğrudan mutasyona açmak yerine `single_example(...)`, `empty_example(...)`, `.description(...)` ve `.width(...)` yardımcılarının kullanılması beklenir. `variant_name` gallery'de görünen varyant başlığıdır; test ve dokümantasyon üretici kodlarda doğrudan okunabilir.

`ComponentExampleGroup` dışa açık alanları: `title`, `examples`, `width`, `grow`, `vertical`. Bunlar `RenderOnce` sırasında layout kararına çevrilir; üretim preview kodunda builder metotlarının kullanılması daha okunaklı bir sonuç verir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `ComponentExample` | `variant_name`, `description`, `element`, `width`, `new`, `description`, `width` | Tek preview varyantının başlığını, açıklamasını, elementini ve genişliğini taşır. |
| `ComponentExampleGroup` | `title`, `examples`, `width`, `grow`, `vertical`, `new`, `with_title`, `width`, `grow`, `vertical` | Birden fazla `ComponentExample` kaydını başlıklı veya başlıksız grup olarak düzenler. |
| `single_example` | `variant_name`, `example` | Tek varyantlı `ComponentExample` üretir. |
| `example_group` | `examples` | Başlıksız `ComponentExampleGroup` üretir. |
| `example_group_with_title` | `title`, `examples` | Başlıklı `ComponentExampleGroup` üretir. |
| `empty_example` | `variant_name` | Bilinçli boş/placeholder preview örneği üretir. |

**Component preview ile preview helper sözleşmesi.** Bir bileşenin `preview()` metodu doğrudan `AnyElement` döndürür. Registry "kayıtlı ama preview yok" durumunu `None` ile temsil etmez. Component henüz anlamlı bir görsel örneğe sahip değilse `empty_example("...").into_any_element()` gibi bilinçli bir placeholder döndürmek daha doğru olur; böylece preview paneli callback sonucunu her zaman render edebilir.

**`description()` ile doc comment otomasyonu.** `documented::Documented` derive'ı eklendiğinde, bir doc comment `Self::DOCS` sabitinden okunur ve description'a dönüşür:

```rust
use component::empty_example;
use documented::Documented;
use ui::component_prelude::*;
use ui::prelude::*;

/// Birincil eylemler için varsayılan buton.
#[derive(IntoElement, RegisterComponent, Documented)]
struct BirincilButonOrnegi;

impl Component for BirincilButonOrnegi {
    fn description() -> &'static str {
        Self::DOCS
    }

    fn preview(_window: &mut Window, _cx: &mut App) -> AnyElement {
        empty_example("Birincil buton").into_any_element()
    }
}
```
