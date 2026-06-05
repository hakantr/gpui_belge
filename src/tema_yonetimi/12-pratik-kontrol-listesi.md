# Pratik kontrol listesi

Son bölüm, önceki adımlarda alınan kararları hata sınıflarına göre hızlıca taranabilir bir kontrol listesine çevirir. Her madde özet niteliğindedir; detay gerektiğinde ilgili konuya dönülmelidir.

---

## 45. Yaygın dikkat noktaları

Önceki bölümlerde geçen dikkat noktaları **tek bir yerde** toplanır. Her madde kısa bir özet içerir ve bölüm referansıyla bağlanır. Ayrıntılı tartışma için ilgili konuya dönülmelidir.

### Sözleşme katmanı

1. **Bilinmeyen alanların sessizce atlanması.** Mevcut Zed sözleşmesinde olmayan alanlar açık hataya düşmelidir. `style` alanı `flatten` kullandığı için bu kontrol açık anahtar allowlist'i ile yaparsın.
2. **JSON'da snake_case beklemek.** Zed `border.variant` yazar; `#[serde(rename = "border.variant")]` şarttır, yoksa alan sessizce boş kalır.
3. **`Option<Hsla>` yerine `Option<String>` kullanmanın gerekçesi.** Sıkı tipli bir parse hatası tüm temayı bozar; iki katmanlı opsiyonellik (Content katmanı string + Refinement katmanı Hsla) sözleşmenin temelidir.
4. **Alan gruplarının kapsamda tutulması.** `terminal_ansi`, debugger, diff hunk, vcs, vim, icon theme — UI'da okunmuyor olsa bile struct'ta bulunmalıdır. Aksi halde sözleşme delinir.
5. **`#[refineable(...)]` attribute'u.** Refinement tipi yalnızca `Default + Clone` türevini taşır; serde/JSON deserialize yolu kapanır.

### Refinement

6. **Türetme adımıyla `refine` sırası.** Status alanlarında kullanıcı `error` yazar ama `error_background` yazmazsa, baseline'dan gelen karışım renkler ortaya çıkar. `apply_status_color_defaults` çağrısı şarttır.
7. **`color()` helper'ında hata mesajının yutulması.** Üretim hata ayıklaması için `inspect_err` ile log ekleyebilirsin; varsayılanda kapalı tutulur.
8. **Baseline appearance seçimi.** Light tema yüklenirken dark baseline kullanılması uyumsuz bir görüntü doğurur. Baseline `content.appearance` değerine göre seçmen gerekir.

### Çalışma zamanı

9. **`cx.refresh_windows()` çağrısı.** Tema değiştiğinde UI'nın yeni renkleri okuması için `GlobalTheme::update_theme + refresh_windows` her zaman bir çift olarak çağrılmalıdır.
10. **`cx.notify()` ile yetinmek.** Yalnızca tek view'ı yeniler; oysa tema değişimi tüm pencerelerde geçerli olur.
11. **`kvs_tema::init` kurulumu.** Global tema kurulmadan `cx.theme()` çağrısı çalışma zamanında erken durur. `kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx)` çağrısı uygulama girişinin **ilk** satırlarında konumlanır.
12. **`update_global` içinde `set_global` çağrısı.** Re-entrancy koruması devreye girer. Update callback'i içinde yalnızca field mutate edilebilir.
13. **`observe_window_appearance` için `.detach()` saklama noktası.** Subscription drop edildiğinde observer sona erer.

### GPUI tipleri

14. **Hue'nun 0–360 aralığında yazılması.** GPUI hue 0–1 normalizedir; `hsla(210.0, ...)` aslında `hsla(210.0 / 360.0, ...)` biçiminde olmalıdır.
15. **`Hsla::default()` ile struct doldurmak.** `(0,0,0,0)` görünmez bir değer üretir. `ThemeColors`'ın 143 alanı ile `StatusColors`'ın 42 alanının tamamını açık değerlerle doldurman gerekir.
16. **`opacity` ile `alpha` arasındaki farkın karıştırılması.** `opacity(x)` mevcut alpha'yı `* x` ile çarpar; `alpha(x)` ise doğrudan set eder.
17. **`use kvs_tema::ActiveTheme;` import'u.** Trait kapsamda olmadığında `cx.theme()` çağrısı "method not found" hatası verir. Prelude kullanılması pratik bir çözüm sağlar.

### Etkileşim

18. **`.id()` çağrısının yeri.** Interactivity stateful'dur; ID olmadan hover/active state bağlanmaz ve etkileşim durumu görünmez kalır.
19. **`element_selected` ile `element_selection_background` karıştırılması.** İlki liste öğesi seçimini, ikincisi metin highlight'ını temsil eder.
20. **Ghost ile element grubunun karıştırılması.** Toolbar'da `element_*` kullanıldığında yüzey rengiyle dolar ve tasarım dili kayar.
21. **Mermaid kaynağında tema dışı stil taşımak.** `%%{init}%%`, elle `classDef` veya rastgele hex renkler aktif tema ile çakışır. Vurgu sınıfları renderer postprocess adımında `.zed-accent-0..N` olarak üretilir; cache tema/settings değişiminde geçersiz kılınmalıdır.
22. **Completion rozet ayarını tema ayarı sanmak.** `completion_menu_item_kind` `EditorSettingsContent` alanıdır; `ThemeSettingsContent` veya provider trait'ine eklenmez. Renk tüketimi syntax theme üstünden yaparsın.
23. **Markdown önizleme metin fontu ile code fontunu birleştirmek.** Düz önizleme metni `markdown_preview_font_family`, inline code ve code block ise `markdown_preview_code_font_family` kullanır. İki alanın fallback hedefleri farklıdır.
24. **Tema değişiminden sonra Mermaid cache'inin geçersiz kılınmaması.** SVG çıktısı `MermaidState::cache` içinde tutulur; tema veya `ThemeSettings` değiştiğinde `Markdown::invalidate_mermaid_cache(cx)` çağrılmazsa diyagramlar eski renkleri taşımaya devam eder. Tema observer'ı bu çağrıyı kendi mantığına bağlamalıdır.
25. **Mermaid kaynağına alpha taşıyan renk vermek.** Renderer alpha'yı **düşürmez**: opak renkleri `#rrggbb`, yarı saydam renkleri `#rrggbbaa` olarak yazar; alpha kanalı korunur. Bu yüzden tema renginde istenmeyen bir alpha doğrudan SVG'ye taşınır. Diyagramda tam dolgu beklediğin yerlerde renkleri **kasıtlı opak** vermen gerekir; yarı saydamlık ancak bilerek istendiğinde kullanılmalıdır.
26. **Yarı yazılmış fenced blok için render beklentisi.** Mermaid pipeline'ı yalnızca `metadata.is_fenced_closed` olan fenced blok'ları toplar; açık kalmış bir blok atlanır, parse hatası üretmez. Bu, akış halinde gelen markdown önizlemelerinde sessiz davranışın kaynağıdır.
27. **`~~~src` ile başka uzantı bağlamak.** Mermaid `FencedSrc` yolu yalnızca `.mermaid` ve `.mmd` uzantılarını tanır; diğerleri sessizce atlanır. Etiketli `~~~mermaid` blok'u her zaman alternatiftir.

### Bundling / lisans

28. **`palette` sürümünün Zed'le aynı tutulmaması.** Renk dönüşümü kayar; fixture testleri kırılır.
29. **`refineable` dep'inin üretim yolu.** `publish = false` ayarı crates.io yayını engeller; vendor veya fork şarttır.
30. **Zed `default_colors` HSL değerlerinin birebir kopyalanması.** GPL-3 ihlalidir. Bağımsız anchor değerleri seçmen gerekir.
31. **Lisans dosyasını "sonradan eklerim" demek.** Bundled tema'ya atıf eklenmediğinde telif ihlali oluşur.
32. **GPL lisanslı fixture'ın alınması.** Tema JSON'undaki HSL değerleri bile telif kapsamına girer; yalnızca MIT/Apache gibi uyumlu lisanslı temalar fixture'a alırsın.

### Test

33. **`#[gpui::test]` `cx.update` içinde init kurulumu.** Test başında `kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx)` veya `test_ortamini_baslat(cx)` çağrısı gerekir.
34. **Hsla'nın `assert_eq!` ile karşılaştırılması.** Float eşitliği yanıltıcıdır; epsilon karşılaştırması tercih edersin.
35. **`feature = "test-support"` kapsamı.** `#[cfg(any(test, feature = "test-support"))]` koşulunu kurarsın; release build'inde kapatırsın.

### API yüzeyi

36. **`refinement` modülünün public yapılması.** `pub use crate::refinement::*` sözleşmeyi sızdırır. `pub(crate) mod refinement;` zorunludur.
37. **`schema::*` glob ile public ihraç.** Yeni iç tip otomatik olarak public hale gelir. Tek tek `pub use` yazılmalıdır.
38. **`Theme.styles` alanının doğrudan public olması.** İç düzen sızıntısına yol açar; accessor metotlarının (`theme.colors()`) tercih edilmesi gerekir.

### Özet karar matrisi

Önceki pratik bölümünde toplanan "İleri öğeler" başlığı ilgili katmanlara dağıtılmıştır. Aşağıdaki tablo, mirror kararı için kısa kontrol listesidir:

| Zed öğesi | `kvs_tema` mirror gerekli mi? | Ne zaman gerekli? |
| ----------- | ------------------------------- | ------------------ |
| `LoadThemes` | Önerilir | Init API'si kapsamdaysa |
| `ThemeSettingsProvider` | Settings entegrasyonu için **gerekli** | Tema seçici veya çalışma zamanı ayar kapsamdaysa |
| `UiDensity` | Tema değil, settings — yine de mirror edilmesi gerekir | Spacing tutarlılığı için |
| `all_theme_colors` / `ThemeColorField` | Tema editörü/önizleme için **gerekli**, diğer durumlarda opsiyonel | Tema editörü yazıldığında |
| `ColorScale` ailesi | **Çoğu uygulama için gereksiz** | Yalnızca geniş tema varyant matrisi gerektiğinde |
| `apply_theme_color_defaults` | Gerekli (ilgili bölümün ikiz fonksiyonu) | Tema refinement akışı kurulduğunda |
| `deserialize_icon_theme` | Trivial bir helper; sarmalanması önerilir | Icon tema yüklendiğinde |
| `FontFamilyCache` | Hayır — sözleşme dışıdır | — |
| `DiagnosticColors` | Editor render path'i kullanıyorsa **gerekli** | Editor entegre olduğunda |
| Registry sabitleri / typed error'lar | Registry mirror ediliyorsa **gerekli** | Registry kapsamdaysa |
| `default_color_scales` / `zed_default_themes` | Karara bağlıdır | Fallback ve scale mirror kararı verildiğinde |

Yukarıdaki öğeler kapsam kararına göre mirror edilir. Public API'ye alınmayan parçalar tüketici sözleşmesinin dışında kalır.


---

# Son

Bu rehber, `kvs_tema` ve `kvs_syntax_tema` crate'lerinin **tüm yüzeyini** 12 bölüm ve 45 konu altında, uygulama kurulum sırasını izleyerek toplar. Üç temel kural baştan sona geçerli kalır:

1. **Veri sözleşmesinde dışlama yok** — Zed'in tüm alanları mirror edilir.
2. **Lisans-temiz çalışma** — kod gövdesi GPL'den kopyalanmaz; yalnızca sözleşme paritesi korunur.
3. **Sözleşme sınırı** — public API ile crate-içi detaylar birbirinden ayrılır; tüketici yalnızca açıkça desteklenen yüzeye bağlanır.

Beklenmedik bir durumla karşılaşıldığında ilk bakılacak yer ilgili bölümdeki dikkat noktaları listesidir. Daha geniş tartışma için ilgili konuya geri dönülmelidir.

---
