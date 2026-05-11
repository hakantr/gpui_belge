# 21. Reçeteler ve Kontrol Listeleri

---

## 21.1. Reçeteler

#### Yeni Workspace Penceresi

1. `zed::build_window_options(display_uuid, cx)` kullan.
2. Kök görünüm (`root view`) olarak workspace/multi-workspace varlığı (`entity`) oluştur.
3. Titlebar için `TitleBar`/`PlatformTitleBar` yolunu izle.
4. Root content'i `workspace::client_side_decorations(...)` ile sar.
5. Close işlemi için `workspace::CloseWindow` action'ını dispatch et.

#### Küçük Dialog Penceresi

```rust
cx.open_window(
    WindowOptions {
        titlebar: Some(TitlebarOptions {
            title: Some("Dialog".into()),
            appears_transparent: true,
            traffic_light_position: Some(point(px(12.), px(12.))),
        }),
        window_bounds: Some(WindowBounds::centered(size(px(440.), px(300.)), cx)),
        is_resizable: false,
        is_minimizable: false,
        kind: WindowKind::Dialog,
        app_id: Some(ReleaseChannel::global(cx).app_id().to_owned()),
        ..Default::default()
    },
    |window, cx| {
        window.activate_window();
        cx.new(|cx| DialogView::new(window, cx))
    },
)?;
```

#### Transparent/Blurred Notification

```rust
WindowOptions {
    titlebar: None,
    focus: false,
    show: true,
    kind: WindowKind::PopUp,
    is_movable: false,
    is_resizable: false,
    window_background: WindowBackgroundAppearance::Transparent,
    window_decorations: Some(WindowDecorations::Client),
    ..Default::default()
}
```

Blur istersen `Transparent` yerine `Blurred` kullan; içerik root'unun tamamen opak
arka plan çizmediğinden emin ol.

#### Platforma Göre UI Ayırma

```rust
match PlatformStyle::platform() {
    PlatformStyle::Mac => { /* macOS */ }
    PlatformStyle::Linux => { /* Linux */ }
    PlatformStyle::Windows => { /* Windows */ }
}
```

Compile-time farklılık gerekiyorsa `cfg!(target_os = "...")` veya `#[cfg(...)]`
kullan. Runtime styling için `PlatformStyle` daha okunur.

#### Titlebar Drag ve Double Click

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
    .on_click(|event, window, _| {
        if event.click_count() == 2 {
            if cfg!(target_os = "macos") {
                window.titlebar_double_click();
            } else {
                window.zoom_window();
            }
        }
    })
```

Linux/macOS'ta elle drag başlatman gerekirse mouse move sırasında:

```rust
window.start_window_move();
```

Windows için `WindowControlArea::Drag` native hit-test tarafında daha doğru yoldur.

#### Client-Side Resize Handle

```rust
.on_mouse_down(MouseButton::Left, move |event, window, _| {
    if let Some(edge) = resize_edge(event.position, shadow, size, tiling) {
        window.start_window_resize(edge);
    }
})
```

Cursor'u da aynı edge'e göre `ResizeUpDown`, `ResizeLeftRight`,
`ResizeUpLeftDownRight`, `ResizeUpRightDownLeft` yap.

#### Tema Değişince Pencere Arka Planını Güncelleme

```rust
cx.observe_global::<SettingsStore>(move |cx| {
    for window in cx.windows() {
        let appearance = cx.theme().window_background_appearance();
        window.update(cx, |_, window, _| {
            window.set_background_appearance(appearance);
        }).ok();
    }
}).detach();
```

Zed ana uygulaması bu deseni zaten kullanır.

## 21.2. Sık Hatalar ve Doğru Desenler

- **İstenen decoration'a güvenme**: `WindowOptions.window_decorations` sadece istektir.
  Render sırasında `window.window_decorations()` sonucunu kullan.
- **Blur görünmüyor**: Root veya theme tamamen opak renk çiziyor olabilir. Transparent
  surface ve alfa gerekir.
- **Linux kontrol butonları yanlış tarafta**: `cx.button_layout()` ve
  `observe_button_layout_changed` kullanılmalı.
- **Windows caption butonları tıklanmıyor**: Buton UI öğelerinde
  `window_control_area(Close/Max/Min)` eksik olabilir.
- **Close davranışı bypass ediliyor**: Zed workspace penceresinde doğrudan
  `remove_window` yerine `workspace::CloseWindow` action'ını dispatch et.
- **Async task çalışırken yok oluyor**: Dönen `Task` saklanmamış veya detach edilmemiştir.
- **Entity leak**: Uzun yaşayan task/subscription içinde güçlü `Entity` yakalamak yerine
  `WeakEntity` kullan.
- **Render güncellenmiyor**: State değişiminden sonra `cx.notify()` unutulmuştur.
- **Focus callback'i fire etmiyor**: Element `.track_focus(&focus_handle)` ile ağaca
  bağlanmamış olabilir.
- **Custom titlebar altında içerik tıklanamıyor**: Drag/window control hitbox'ı fazla
  geniş olabilir veya `.occlude()` yanlış yerde olabilir.
- **Client decoration shadow boşluğu**: `set_client_inset` ve dış wrapper padding/shadow
  birlikte yönetilmelidir.

#### Dokümantasyon Dili

- Kod tipleri İngilizce bırakılır; açıklama metninde ilk kullanımda Türkçe karşılığıyla
  verilir: `entity` = varlık, `handle` = tutamaç, `view` = görünüm,
  `element` = UI öğesi, `state` = durum, `context` = bağlam.
- Okurun kavramı takip ettiği cümlelerde Türkçe karşılık kullanılır; Rust tipi veya API adı
  gerekiyorsa parantez içinde yazılır (örn. varlık (`Entity<T>`), odak tutamacı
  (`FocusHandle`)).
- "Yukarıda anlatıldı", "önceki bölümde değinildi" gibi ifadeler yerine ilgili başlığa
  doğrudan Markdown linki verilir.

## 21.3. Yeni Pencere Eklerken Kontrol Listesi

1. Bu pencere workspace mi, modal mı, popup mı? `WindowKind` seç.
2. Ana Zed penceresiyse `build_window_options` kullan.
3. Bounds restore edilecek mi? `WindowBounds` persist et.
4. Hangi display'de açılacak? `display_id` veya `display_uuid` seç.
5. Titlebar native mi custom mı? `TitlebarOptions`/`PlatformTitleBar` kararını ver.
6. Linux decoration modu ayardan mı gelecek? `window_decorations` bağla.
7. Client decoration varsa wrapper, inset, resize tutamacı ve tiling durumunu ekle.
8. Close action doğrudan pencereyi kapatmalı mı, yoksa workspace close flow mu?
9. Blur/transparent gerekiyorsa `window_background` ve root alpha uyumunu kontrol et.
10. Focus başlangıcı doğru mu? `focus`, `show`, `activate_window`, odak tutamacı.
11. Minimum size gerekli mi?
12. App id ve Linux icon gerekiyor mu?
13. macOS native tabbing isteniyor mu? `tabbing_identifier`.
14. Settings/theme değişiminde arka plan güncellenecek mi?
15. Button layout değişiminde titlebar yeniden render olacak mı?
16. Testte timer gerekiyorsa GPUI executor timer kullanıldı mı?

## 21.4. Kısa Cevaplar

**İleride pencere oluşturmak için nasıl yapmalıyım?**

Workspace penceresi için `zed::build_window_options` ile başla. Özel küçük pencere
için doğrudan `cx.open_window(WindowOptions { ... }, |window, cx| cx.new(...))`
kullan. Kök görünüm (`root view`) `Render` implement eden bir `Entity` olmalı.

**Pencere dekorunu nasıl tanımlarım?**

Linux için `WindowOptions.window_decorations = Some(WindowDecorations::Client/Server)`.
Render tarafında fiili sonucu `window.window_decorations()` ile oku. Zed tarzı
client decoration için `workspace::client_side_decorations` kullan. macOS/Windows'ta
custom titlebar için `TitlebarOptions { appears_transparent: true }` veya
`titlebar: None` ve `PlatformTitleBar` kullan.

**Kontrol butonlarını nasıl yönetirim?**

Zed içinde `platform_title_bar::render_left_window_controls` ve
`render_right_window_controls` kullan. Linux'ta `cx.button_layout()` ve
`window.window_controls()` sonucu belirleyicidir. Windows'ta butonlar
`WindowControlArea::{Min, Max, Close}` ile native hit-test'e bağlanır. Close için
workspace akışında `CloseWindow` action dispatch et.

**Blur yönetimini işletim sistemine göre nasıl yaparım?**

Pencere açarken veya tema değişince `window.set_background_appearance(...)` kullan.
Zed tema akışı `opaque`, `transparent`, `blurred` destekler. macOS gerçek blur'u
`NSVisualEffectView`/legacy blur radius ile, Windows composition/DWM ile, Wayland
compositor blur protocol ile uygular. Destek yoksa `Blurred` transparan gibi
davranabilir. Root UI opak çiziyorsa blur görünmez.

**Platform farklarını nerede soyutlarım?**

Davranış platform penceresiyle ilgiliyse GPUI `Platform`/`PlatformWindow` katmanında.
Zed UI görünümüyle ilgiliyse `PlatformStyle::platform()` ve `platform_title_bar`
bileşenlerinde. Ayar farkı gerekiyorsa `settings_content` schema ve `settings`
dönüşümlerinde.

## 21.5. Dosya Yoluna Göre Ne Nerede?

- Pencere açma API'si: `crates/gpui/src/app.rs::open_window`
- Pencere seçenekleri: `crates/gpui/src/platform.rs::WindowOptions`
- Platform penceresi sözleşmesi: `crates/gpui/src/platform.rs::PlatformWindow`
- Pencere wrapper metotları: `crates/gpui/src/window.rs`
- UI öğesi ve render trait'leri: `crates/gpui/src/element.rs`, `view.rs`
- Style fluent API: `crates/gpui/src/styled.rs`
- Interactivity fluent API: `crates/gpui/src/elements/div.rs`
- Platform seçimi: `crates/gpui_platform/src/gpui_platform.rs`
- macOS pencere davranışı: `crates/gpui_macos/src/window.rs`
- Windows pencere davranışı: `crates/gpui_windows/src/window.rs`, `events.rs`
- Linux Wayland davranışı: `crates/gpui_linux/src/linux/wayland/window.rs`
- Linux X11 davranışı: `crates/gpui_linux/src/linux/x11/window.rs`
- Zed ana window options: `crates/zed/src/zed.rs::build_window_options`
- Zed platform titlebar: `crates/platform_title_bar/src/platform_title_bar.rs`
- Linux controls: `crates/platform_title_bar/src/platforms/platform_linux.rs`
- Windows controls: `crates/platform_title_bar/src/platforms/platform_windows.rs`
- Workspace client decoration: `crates/workspace/src/workspace.rs::client_side_decorations`
- Zed titlebar composition: `crates/title_bar/src/title_bar.rs`
- Theme background appearance: `crates/theme/src/theme.rs`,
  `crates/theme_settings/src/theme_settings.rs`,
  `crates/settings/src/content_into_gpui.rs`
- UI component export list: `crates/ui/src/components.rs`
- UI input: `crates/ui_input/src/ui_input.rs`, `input_field.rs`
