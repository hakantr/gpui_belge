# Ek B. Zed Uygulamasında Component Yönetimi

Zed'de `ui` bileşenleri çalışma zamanında (runtime) merkezi bir "component manager" tarafından yaratılmaz. Normal uygulama ekranlarında akış GPUI'ye aittir: Görünüm (view) veya entity durumu `Render` implementasyonunda tutulur; küçük ve durumsuz (stateless) UI parçaları `RenderOnce` builder'larıyla oluşturulur; `ui::prelude::*` ya da doğrudan `use ui::{...}` import'larıyla çağrılır. `Button::new`, `IconButton::new`, `ListItem::new`, `ContextMenu::build`, `PopoverMenu::new`, `Scrollbars::for_settings` ve `Table::new` gibi yapıcı metotlar (constructors) Zed uygulama paketlerinde doğrudan kullanılır.

Component preview ise bundan ayrı, kendi içinde bir registry akışıdır:

- `workspace` crate'inde `workspace::init(...)` başlangıçta `component::init()` çağrısını yapar. Bu çağrı, `inventory` ile toplanan tüm `ComponentFn` kayıtlarını çalıştırır.
- `#[derive(RegisterComponent)]` makrosu, `ui_macros` üzerinden her component için `component::register_component::<T>()` çağıran bir kayıt fonksiyonu üretir ve bunu `component::__private::inventory::submit!` ile registry'ye ekler.
- `component` crate'i, registry global'ini `COMPONENT_DATA: LazyLock<RwLock<ComponentRegistry>>` olarak tutar. Tüketici kod doğrudan bu global'e gitmez; bunun yerine `components()`, `register_component::<T>()` ve `ComponentRegistry` erişimcileri (accessors) kullanılır.
- `zed` crate'i, normal uygulama açılışında `component_preview::init(app_state.clone(), cx)` çağrısını yapar. Bu da workspace'e bir `OpenComponentPreview` eylemini ve bir `ComponentPreview` serileştirilebilir (serializable) öğesini kaydeder.
- `component_preview` crate'i, `components().sorted_components()` ile listeyi alır, `component_map()` ile id lookup haritası kurar, `InputField` ile filtreler. Sol navigasyonu `ListItem`, `ListSubHeader` ve `HighlightedLabel` ile render eder ve önizleme alanında `ComponentMetadata::preview()` fonksiyonunu çağırır. Bu callback her kayıt için çağrılabilir durumdadır ve `AnyElement` döndürür; "preview yok" durumu `None` ile değil, bileşenin kendi içinde minimal veya boş bir önizleme elementiyle modellenir.
- Aynı dosya, active page bilgisini `ComponentPreviewDb` üzerinden `component_previews` tablosunda saklar. Önizleme öğesi split veya restore sırasında `SerializableItem` implementasyonu bu durumu geri yükler.

| API | Katman | Kısa anlamı |
| :-- | :-- | :-- |
| `ui_macros` | derive macro crate | `RegisterComponent` derive makrosunu üretir ve registry kaydını `inventory` üzerinden bağlar. |
| `component_layout` | component crate re-export'u | Component preview/layout yardımcıları `component` crate'i tarafından dışa açılır; üretim ekran yaşam döngüsü yerine galeri düzeniyle ilgilidir. |
| `scrollbars` | scrollbar alt modülü | `ShowScrollbar`, `ScrollbarVisibility` ve `ScrollbarAutoHide` ayar tiplerinin kaynak modülüdür; `Scrollbars` yardımcısı aynı `scrollbar.rs` dosyasından `ui` üzerinden re-export edilir. |
| `Scrollbars` | runtime UI helper | Panel, tablo ve önizleme navigasyonu gibi alanlarda scroll handle ile birlikte scrollbar yüzeyi render eder. |

Gerçek uygulama kullanımı için en rahat okuma sırası şudur:

1. Kurucu (builder) imzası ve export yolu için önce `ui` crate'inin ilgili alt modül dosyasının okunması gerekir.
2. Registry ve önizleme davranışı için `component`, `ui_macros` ve `component_preview` akışının izlenmesi gerekir.
3. Uygulama kompozisyonu için bileşenin Zed'deki gerçek çağrı yerlerine bakılması gerekir. Örnekler arasında `title_bar` menü tetikleyicileri, `project_panel` scrollbars ve list öğesi kullanımı, `keymap_editor` veri tablosu kullanımı, `git_ui` branch ve commit picker'ları, `workspace::notifications` toast ve notification frame kullanımı yer alır.

Bu ayrım önemlidir: `impl Component for T`, üretim ekranındaki yaşam döngüsünü değil, önizleme ve galeri metadatasını anlatır. Üretim ekranındaki yaşam döngüsü GPUI tarafında `Entity`, `Context`, `Window`, `FocusHandle`, `Task` ve gerektiğinde çalışma alanı katmanındaki `ModalLayer`, bildirim yığını (notification stack) veya popover/menu durum tutamakları (state handles) tarafından yönetilir.
