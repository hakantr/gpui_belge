# Pratik uygulama

Uygulama sırasında değiştirilecek noktaları, platform kontrol listelerini ve sık hataları en sona yakın topla.

## 18. Özelleştirme noktaları

| İhtiyaç | Değiştirilecek yer |
| :-- | :-- |
| Close butonu farklı action dispatch etsin | `PlatformTitleBar` içine `close_action` alanı ekle veya serbest render fonksiyonlarını kullan. |
| Linux buton sırası ayardan gelsin | `set_button_layout(...)` çağrısını uygulama settings state'ine bağla. |
| Linux buton ikon/rengi değişsin | `WindowControlStyle` veya `WindowControlType::icon()` portunda değişiklik yap. |
| Windows close hover rengi değişsin | `platform_windows.rs` içindeki `WindowsCaptionButton::Close` (crate-içi enum) renklerini değiştir; tip pub değildir, port hedefinde aynı dört variantı kendi enum'unuzla yeniden yazın. |
| Titlebar yüksekliği değişsin | `platform_title_bar_height` karşılığını uygulamana taşı ve tüm titlebar/controls kullanımında aynı değeri kullan. |
| Native tabs kapatılsın | `SystemWindowTabs` render child'ını feature flag ile boş döndür. |
| Sekme plus butonu yeni pencere açsın | `zed_actions::OpenRecent` yerine uygulama `NewWindow` action'ını dispatch et. |
| Sidebar açıkken kontroller gizlenmesin | `sidebar_render_state` ve `show_left/right_controls` koşullarını değiştir. |
| Sağ tık window menu kapatılsın | Linux CSD `window.show_window_menu(ev.position)` bağını kaldır veya ayara bağla. |
| Çift tıklama maximize yerine özel action olsun | Platform click handler'larını kendi action'ına yönlendir. |

## 19. Kontrol listesi

### Genel

- `PlatformTitleBar::init(cx)` uygulama başlangıcında bir kez çağrılıyor.
- Pencere `WindowOptions.titlebar` değerini transparent titlebar ile açıyor.
- Linux CSD gerekiyorsa `WindowDecorations::Client` isteniyor.
- CSD kullanılıyorsa pencere gölge/border/resize sarmalı ayrıca uygulanıyor.
- Titlebar child'ları her render geçişinde `set_children(...)` ile yenileniyor.
- İnteraktif titlebar child'ları drag propagation ile çakışmıyor.
- Tema token'ları aktif, pasif ve hover durumlarını kapsıyor.

### Linux/FreeBSD

- `cx.button_layout()` veya uygulama ayarı ile `WindowButtonLayout` geliyor.
- Sol ve sağ buton dizilerinde boş slotlar doğru davranıyor.
- Desktop layout değişince titlebar yeniden render oluyor.
- `window.window_controls()` minimize/maximize desteğini doğru filtreliyor.
- Sağ tık sistem pencere menüsü istenen ürün davranışıyla uyumlu.

### Windows

- Caption button alanları `WindowControlArea::{Min, Max, Close}` olarak kalıyor.
- Sağdaki ürün butonları caption button hitbox'larıyla çakışmıyor.
- `platform_title_bar_height` Windows için `32px` varsayımını koruyor veya bilinçli
  değiştiriliyor.
- Close hover rengi tema politikanızla uyumlu.

### macOS

- Trafik ışıkları için sol padding korunuyor.
- `traffic_light_position` ile titlebar child'ları çakışmıyor.
- Fullscreen ve native tabs davranışı ayrıca test ediliyor.
- Çift tıklama sistem davranışına mı, özel davranışa mı gidecek netleştiriliyor.

### Native tabs

- `tabbing_identifier` tüm ilgili pencerelerde aynı.
- Sekme kapatma action'ı kirli doküman/workspace state'ini kontrol ediyor.
- Sekmeyi yeni pencereye alma uygulama state'ini doğru taşıyor.
- Plus butonu doğru yeni pencere/workspace action'ını dispatch ediyor.
- Sağ tık menü metinleri ve action'ları ürün diline uyarlanıyor.

## 20. Sık yapılan hatalar

- `PlatformTitleBar` child'larını yalnızca constructor'da vermek. Zed child'ları
  render sırasında tükettiği için içerik sonraki render'da kaybolur.
- Linux CSD butonlarını gösterip pencere resize/border sarmalını uygulamamak.
  Başlık çubuğu çalışır, fakat pencere kenarı native hissettirmez.
- Close butonunu uygulama lifecycle'ına bağlamadan doğrudan pencere kapatmak.
  Kirli doküman, background task veya workspace cleanup adımları atlanabilir.
- Windows butonlarını Linux gibi click handler ile yönetmeye çalışmak. Windows
  implementation hit-test alanı verir; davranış platform katmanındadır.
- Native tabs açıkken `tabbing_identifier` vermemek. Pencereler aynı native tab
  grubunda birleşmez.
- `DraggedWindowTab` payload'ını sadece alan listesi olarak mirror etmek.
  Aynı tab bar drop'u reorder yapar; tab bar dışına bırakma yeni pencereye taşır;
  merge ise ayrı action/context menu akışıdır.
- `SystemWindowTabController` state'i ile platform native tab state'ini tek
  kaynak sanmak. Controller Zed tarafındaki UI/action modelidir; platform çağrıları
  (`window.move_tab_to_new_window`, `window.merge_all_windows`) ayrıca yapılır.
- App-specific menüleri `PlatformTitleBar` içine gömmek. Daha temiz model,
  platform kabuğunu ayrı, ürün titlebar içeriğini ayrı tutmaktır.

