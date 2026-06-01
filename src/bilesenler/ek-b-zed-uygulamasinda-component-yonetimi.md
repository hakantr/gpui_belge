# Ek B. Zed Uygulamasında Component Yönetimi

Zed'de `crates/ui` bileşenleri runtime'da merkezi bir "component manager" tarafından yaratılmaz. Normal uygulama ekranlarında akış GPUI'ye aittir: view veya entity state'i `Render` implementasyonunda tutulur, küçük ve stateless UI parçaları `RenderOnce` builder'larıyla oluşturulur; `ui::prelude::*` ya da doğrudan `use ui::{...}` import'larıyla çağırırsın. `Button::new`, `IconButton::new`, `ListItem::new`, `ContextMenu::build`, `PopoverMenu::new`, `Scrollbars::for_settings` ve `Table::new` gibi constructor'lar Zed uygulama crate'lerinde doğrudan kullanırsın.

Component preview ise bundan ayrı, kendi içinde bir registry akışıdır:

- `../zed/crates/workspace/src/workspace.rs` içinde `workspace::init(...)` başlangıçta `component::init()` çağrısını yapar. Bu çağrı, `inventory` ile toplanan tüm `ComponentFn` kayıtlarını çalıştırır.
- `#[derive(RegisterComponent)]` makrosu, `ui_macros` üzerinden her component için `component::register_component::<T>()` çağıran bir kayıt fonksiyonu üretir ve bunu `component::__private::inventory::submit!` ile registry'ye ekler.
- `../zed/crates/component/src/component.rs`, registry global'ini `COMPONENT_DATA: LazyLock<RwLock<ComponentRegistry>>` olarak tutar. Tüketici kod doğrudan bu global'e gitmez; bunun yerine `components()`, `register_component::<T>()` ve `ComponentRegistry` accessor'ları kullanırsın.
- `../zed/crates/zed/src/main.rs`, normal uygulama açılışında `component_preview::init(app_state.clone(), cx)` çağrısını yapar. Bu da workspace'e bir `OpenComponentPreview` action'ı ve bir `ComponentPreview` serializable item'ı kaydeder.
- `../zed/crates/component_preview/src/component_preview.rs`, `components().sorted_components()` ile listeyi alır, `component_map()` ile id lookup haritası kurar, `InputField` ile filtreler. Sol navigasyonu `ListItem`, `ListSubHeader` ve `HighlightedLabel` ile render eder ve preview alanında `ComponentMetadata::preview()` fonksiyonunu çağırır. Bu callback her kayıt için çağrılabilir durumdadır ve `AnyElement` döndürür; "preview yok" durumu `None` ile değil, bileşenin kendi içinde minimal veya boş bir preview elementiyle modellenir.
- Aynı dosya, active page bilgisini `ComponentPreviewDb` üzerinden `component_previews` tablosunda saklar. Preview item split veya restore sırasında `SerializableItem` implementasyonu bu state'i geri yükler.

| API | Katman | Kısa anlamı |
| :-- | :-- | :-- |
| `ui_macros` | derive macro crate | `RegisterComponent` derive makrosunu üretir ve registry kaydını `inventory` üzerinden bağlar. |
| `component_layout` | component crate re-export'u | Component preview/layout yardımcılarını tek modül altında dışa açar; üretim ekran lifecycle'ı yerine gallery düzeniyle ilgilidir. |
| `scrollbars` | ui modülü | `Scrollbars` ve scrollbar yardımcılarının kaynak modülüdür. |
| `Scrollbars` | runtime UI helper | Panel, tablo ve preview navigasyonu gibi alanlarda scroll handle ile birlikte scrollbar yüzeyi render eder. |

Gerçek uygulama kullanımı için en rahat okuma sırası şudur:

1. Builder imzası ve export yolu için önce `crates/ui/src/components.rs` ile ilgili alt modül dosyası okunur.
2. Registry ve preview davranışı için `crates/component`, `ui_macros` ve `crates/component_preview` akışı izlenir.
3. Uygulama kompozisyonu için bileşenin Zed'deki gerçek çağrı yerlerine bakılır. Örnekler arasında `title_bar` menü trigger'ları, `project_panel` scrollbars ve list item kullanımı, `keymap_editor` data table kullanımı, `git_ui` branch ve commit picker'ları, `workspace::notifications` toast ve notification frame kullanımı yer alır.

Bu ayrım önemlidir: `impl Component for T`, üretim ekranındaki lifecycle'ı değil, preview ve gallery metadata'sını anlatır. Üretim ekranındaki lifecycle GPUI tarafında `Entity`, `Context`, `Window`, `FocusHandle`, `Task` ve gerektiğinde workspace katmanındaki `ModalLayer`, notification stack veya popover/menu state handle'ları tarafından yönetilir.
