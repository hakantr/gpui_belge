# Ek B. Zed Uygulamasında Component Yönetimi

Zed'de `crates/ui` bileşenleri runtime'da merkezi bir "component manager"
tarafından yaratılmaz. Normal uygulama ekranlarında akış GPUI'nindir:
view/entity state'i `Render` implementasyonunda tutulur, küçük stateless UI
parçaları `RenderOnce` builder'larıyla oluşturulur ve `ui::prelude::*` ya da
doğrudan `use ui::{...}` import'larıyla çağrılır. `Button::new`,
`IconButton::new`, `ListItem::new`, `ContextMenu::build`,
`PopoverMenu::new`, `Scrollbars::for_settings` ve `Table::new` gibi
constructor'lar Zed uygulama crate'lerinde doğrudan kullanılır.

Component preview ise ayrı bir registry akışıdır:

- `../zed/crates/workspace/src/workspace.rs` içinde `workspace::init(...)`,
  başlangıçta `component::init()` çağırır. Bu çağrı `inventory` ile toplanan
  tüm `ComponentFn` kayıtlarını çalıştırır.
- `#[derive(RegisterComponent)]`, `ui_macros` üzerinden her component için
  `component::register_component::<T>()` çağıran bir kayıt fonksiyonu üretir
  ve bunu `component::__private::inventory::submit!` ile registry'ye ekler.
- `../zed/crates/component/src/component.rs`, registry global'ini
  `COMPONENT_DATA: LazyLock<RwLock<ComponentRegistry>>` olarak tutar.
  Tüketici kodu doğrudan global'e değil `components()`,
  `register_component::<T>()` ve `ComponentRegistry` accessor'larına gider.
- `../zed/crates/zed/src/main.rs`, normal uygulama açılışında
  `component_preview::init(app_state.clone(), cx)` çağırır. Bu, workspace'e
  `OpenComponentPreview` action'ını ve `ComponentPreview` serializable item'ını
  kaydeder.
- `../zed/crates/component_preview/src/component_preview.rs`,
  `components().sorted_components()` ile listeyi alır, `component_map()` ile
  id lookup haritası kurar, `InputField` ile filtreler, `ListItem` /
  `ListSubHeader` / `HighlightedLabel` ile sol navigasyonu render eder ve
  preview alanında `ComponentMetadata::preview()` fonksiyonunu çağırır.
- Aynı dosya active page bilgisini `ComponentPreviewDb` üzerinden
  `component_previews` tablosunda saklar; preview item split/restore sırasında
  `SerializableItem` implementasyonu bu state'i geri yükler.

Gerçek uygulama kullanımı için okuma sırası:

1. Builder imzası ve export yolu için önce `crates/ui/src/components.rs` ile
   ilgili alt modül dosyasını okuyun.
2. Registry/preview davranışı için `crates/component`, `ui_macros` ve
   `crates/component_preview` akışını okuyun.
3. Uygulama kompozisyonu için component'in Zed'deki gerçek çağrı yerlerine
   bakın. Örnekler: `title_bar` menü trigger'ları, `project_panel`
   scrollbars/list item kullanımı, `keymap_editor` data table kullanımı,
   `git_ui` branch/commit picker'ları, `workspace::notifications` toast ve
   notification frame kullanımı.

Bu ayrım önemlidir: `impl Component for T`, üretim ekranındaki lifecycle'ı
değil preview/gallery metadata'sını anlatır. Üretim ekranındaki lifecycle
GPUI `Entity`, `Context`, `Window`, `FocusHandle`, `Task` ve gerektiğinde
workspace katmanındaki `ModalLayer`, notification stack veya popover/menu
state handle'ları tarafından yönetilir.

