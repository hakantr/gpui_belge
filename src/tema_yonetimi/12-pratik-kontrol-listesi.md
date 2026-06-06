# Pratik kontrol listesi

Bu son bölüm, önceki adımlarda alınan kararları hata sınıflarına göre hızlıca taranabilir pratik bir kontrol listesine dönüştürür. Her bir madde özet niteliğinde olup, daha kapsamlı ayrıntılara ihtiyaç duyulduğunda ilgili konu başlıklarına başvurulmalıdır.

---

## 45. Yaygın dikkat noktaları

Önceki bölümlerde ele alınan dikkat noktaları bu başlık altında **tek bir yerde** derlenmiştir. Her bir madde kısa bir özet sunmakta ve ilgili bölüm referansına bağlanmaktadır. Ayrıntılı teknik tartışmalar için ilgili konu başlıklarına başvurulması önerilir.

### Sözleşme katmanı

1. **Bilinmeyen alanlerin sessizce geçilmesi:** Mevcut Zed sözleşmesinde yer almayan alanların tespit edilmesi durumunda sistem açıkça hataya düşmelidir. `style` alanı `flatten` niteliğini kullandığı için, bu kontrolü açık bir anahtar allowlist (izin verilenler listesi) vasıtasıyla yürütmek gerekir.
2. **JSON tarafında snake_case formatı beklentisi:** Zed yapılandırma dosyalarında `border.variant` biçiminde anahtarlar yer alır. Bu nedenle `#[serde(rename = "border.variant")]` niteliğinin kullanılması zorunludur; aksi takdirde ilgili alan sessizce boş kalacaktır.
3. **`Option<Hsla>` yerine `Option<String>` tercih edilmesinin gerekçesi:** Doğrudan sıkı tipli bir parse hatası oluşması tüm temanın yüklenmesini engelleyebilir. Bu durumun önüne geçmek amacıyla tasarlanan iki katmanlı opsiyonellik (Content katmanında String, Refinement katmanında ise Hsla kullanımı) veri sözleşmesinin temel taşlarından biridir.
4. **Alan gruplarının kapsam dahilinde tutulması:** `terminal_ansi`, debugger, diff hunk, vcs, vim, icon theme gibi alanların (arayüz tarafında doğrudan okunmasa bile) ilgili struct'larda yer alması gerekir. Aksi takdirde Zed veri sözleşmesiyle olan parite bozulmuş olur.
5. **`#[refineable(...)]` özniteliği:** Üretilen refinement tipi yalnızca `Default + Clone` türevlerini taşır; bu durum serde/JSON deserialize yolunun kapanmasına sebebiyet verir.

### Refinement

6. **Türetme adımları ve `refine` sırası:** Status alanlarında kullanıcı `error` değerini belirttiği halde `error_background` değerini tanımlamamışsa, baseline üzerinden gelen uyumsuz veya karışık renkler ortaya çıkabilir. Bu durumun önüne geçmek için `apply_status_color_defaults` çağrısının yapılması zorunludur.
7. **`color()` yardımcısında (helper) hata mesajlarının yutulması:** Üretim ortamında hata ayıklama süreçlerini kolaylaştırmak amacıyla `inspect_err` ile loglama mekanizmaları eklenebilir; ancak bu işlevlerin varsayılan olarak kapalı tutulması önerilir.
8. **Baseline appearance seçimi:** Light tema yüklenirken dark baseline kullanılması görsel uyumsuzluklara yol açar. Bu nedenle baseline seçiminin doğrudan `content.appearance` değerine göre yapılması gerekir.

### Çalışma zamanı

9. **`cx.refresh_windows()` çağrısı:** Tema değişikliği gerçekleştiğinde kullanıcı arayüzünün yeni renkleri anında yansıtabilmesi için, `GlobalTheme::update_theme` ve `refresh_windows` çağrılarının her zaman birlikte (bir çift olarak) yapılması gerekir.
10. **Yalnızca `cx.notify()` çağrısıyla yetinilmesi:** Bu yöntem sadece ilgili view bileşenini yeniler; oysa tema değişiminin uygulamadaki tüm pencerelerde geçerli olması hedeflenir.
11. **`kvs_tema::init` kurulumu:** Global tema tanımlanmadan önce yapılacak bir `cx.theme()` çağrısı, çalışma zamanında hataya (panic/crash) sebebiyet verir. Bu nedenle `kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx)` çağrısının, uygulama giriş noktasının (main fonksiyonunun) **ilk** satırlarında konumlandırılması kritik önem taşır.
12. **`update_global` bloğu içerisinde `set_global` çağrısının yapılması:** Bu durum re-entrancy (tekrar girilebilirlik) korumasını devreye sokarak çalışma zamanını kilitleyebilir. Güncelleme callback'i içerisinde yalnızca ilgili alanların mutasyona (mutate) uğratılmasına izin verilir.
13. **`observe_window_appearance` için `.detach()` kullanımı:** Subscription yapısı drop edildiğinde observer işlevi de sona erer. Bu nedenle abonelik referanslarının uygun şekilde saklanması veya detach edilmesi gerekir.

### GPUI tipleri

14. **Hue değerinin 0–360 aralığında tanımlanması:** GPUI bünyesinde hue kanalı 0.0 ile 1.0 arasında normalize edilmiştir; dolayısıyla `hsla(210.0, ...)` kullanımı hatalıdır ve `hsla(210.0 / 360.0, ...)` şeklinde dönüştürülmelidir.
15. **`Hsla::default()` kullanarak struct alanlarının doldurulması:** Varsayılan Hsla değeri `(0.0, 0.0, 0.0, 0.0)` olduğundan tamamen görünmez bir renk üretir. Hataları önlemek amacıyla, `ThemeColors`'ın 143 alanının ve `StatusColors`'ın 42 alanının tamamının açık ve belirgin değerlerle doldurulması gerekir.
16. **`opacity` ile `alpha` metotlarının karıştırılması:** `opacity(x)` çağrısı mevcut alpha değerini `x` çarpanıyla çarparak günceller; buna karşın `alpha(x)` doğrudan şeffaflık değerini `x` olarak atar.
17. **`use kvs_tema::ActiveTheme;` import ifadesinin unutulması:** Bu trait kapsamda (scope) bulunmadığı takdirde, `cx.theme()` çağrısı derleme sırasında 'method not found' hatasıyla sonuçlanır. Kütüphane prelude modülünün kullanılması bu durum için pratik bir çözüm sunar.

### Etkileşim

18. **`.id()` çağrısının önemi:** Etkileşim (interactivity) stateful bir yapıya sahiptir; benzersiz bir kimlik (ID) atanmadığında hover/active durumları bağlanamaz ve etkileşim görsel olarak yansıtılamaz.
19. **`element_selected` ile `element_selection_background` alanlarının karıştırılması:** İlk alan liste ögesinin seçilme durumunu temsil ederken, ikinci alan doğrudan metin vurgulama (text highlight) arka planını ifade eder.
20. **Ghost butonlar ile element gruplarının karıştırılması:** Araç çubuğunda (toolbar) `element_*` renkleri kullanıldığında buton yüzeyi dolgulu bir renkle kaplanır ve bu durum minimalist tasarım dilinden uzaklaşılmasına neden olur.
21. **Mermaid şemasında tema dışı özel stillerin kullanılması:** `%%{init}%%` tanımlamaları, elle eklenmiş `classDef` kuralları veya rastgele hex renk kodları aktif tema renkleriyle çakışabilir. Vurgu sınıfları, renderer'ın postprocess adımında `.zed-accent-0..N` adlarıyla dinamik olarak üretilir; dolayısıyla tema veya ayar değişikliklerinde bu önbelleğin geçersiz kılınması gerekir.
22. **Completion rozet yapılandırmasının tema ayarı olarak değerlendirilmesi:** `completion_menu_item_kind` alanı doğrudan `EditorSettingsContent` yapısına aittir; `ThemeSettingsContent` ya da provider trait'i içerisine eklenmez. Buradaki renk tüketiminin doğrudan syntax theme üzerinden yürütülmesi hedeflenir.
23. **Markdown önizlemedeki metin fontu ile kod fontunun birleştirilmesi:** Düz önizleme metni `markdown_preview_font_family` yapılandırmasını esas alırken, satır içi kodlar (inline code) ve kod blokları `markdown_preview_code_font_family` alanından beslenir. Bu iki alanın varsayılan (fallback) hedefleri farklılık gösterir.
24. **Tema değişiminin ardından Mermaid önbelleğinin geçersiz kılınmaması:** Üretilen SVG çıktıları `MermaidState::cache` yapısı içinde saklanır. Tema ya da `ThemeSettings` değiştiğinde `Markdown::invalidate_mermaid_cache(cx)` çağrısı yapılmazsa, diyagramlar eski renkleriyle çizilmeye devam eder. Bu nedenle tema observer yapısının bu çağrıyı tetikleyecek şekilde kurgulanması gerekir.
25. **Mermaid girdilerine alpha kanalı içeren renklerin aktarılması:** Renderer yapısı alpha değerini otomatik olarak silmez; opak renkleri `#rrggbb`, yarı saydam renkleri ise `#rrggbbaa` formatında yansıtır ve renk hassasiyetini korur. Bu yüzden tema renginde yer alan şeffaflık doğrudan üretilen SVG dosyasına yansır. Diyagramda tam dolgu yapılması planlanan alanlarda renklerin **bilinçli olarak opak** verilmesi; yarı saydamlığın ise yalnızca özel durumlarda tercih edilmesi önerilir.
26. **Yarım bırakılmış fenced bloklarında render beklentisi:** Mermaid işlem hattı yalnızca `metadata.is_fenced_closed` niteliği `true` olan (kapatılmış) fenced bloklarını işleme alır. Açık bırakılmış bloklar sessizce atlanır ve herhangi bir parse hatası üretilmez. Bu durum, canlı akan markdown önizlemelerinde bazı blokların görüntülenmemesinin temel sebebidir.
27. **`~~~src` formatıyla farklı uzantıların bağlanması:** Mermaid `FencedSrc` yolu yalnızca `.mermaid` ve `.mmd` dosya uzantılarını işleyebilir; diğer uzantılar sessizce devre dışı bırakılır. Etiketli standart `~~~mermaid` blok yapısı bu durumlar için her zaman kararlı bir alternatiftir.

### Bundling / lisans

28. **`palette` kütüphane sürümünün Zed referansıyla aynı tutulmaması:** Bu uyumsuzluk renk uzayı dönüşümlerinde kaymalara sebep olur ve fixture testlerinin başarısızlığıyla sonuçlanır.
29. **`refineable` bağımlılığının dağıtım kanalı:** `publish = false` yapılandırması crates.io platformuna paket gönderilmesini engeller; bu durumda yerel vendor klasörlerinin kurulması veya bağımsız bir fork oluşturulması gerekir.
30. **Zed `default_colors` HSL değerlerinin birebir kopyalanması:** Bu durum lisans (GPL-3) ihlallerine sebebiyet verebilir. Tasarım aşamasında özgün anchor (çapa) renk değerlerinin belirlenmesi gerekir.
31. **Lisans veya atıf dosyalarının ertelenmesi:** Dahili (bundled) temalara gerekli telif/lisans atıfları eklenmediğinde yasal hak ihlalleriyle karşılaşılabilir.
32. **GPL lisanslı fixture dosyalarının projeye dahil edilmesi:** Tema JSON yapılandırmasındaki renk ve şema değerleri dahi telif hakkı kapsamına girebilir; bu sebeple yalnızca MIT/Apache gibi uyumlu ve açık kaynak lisanslarına sahip temalar test fixture'ı olarak tercih edilmelidir.

### Test

33. **`#[gpui::test]` kapsamındaki başlatma kurulumu:** Her test sürecinin başlangıcında `kvs_tema::init(kvs_tema::LoadThemes::JustBase, cx)` ya da `test_ortamini_baslat(cx)` çağrısı yapılarak gerekli global durumların hazır hale getirilmesi sağlanmalıdır.
34. **Hsla değerlerinin doğrudan `assert_eq!` ile sınanması:** Küsüratlı sayılardaki (float) hassasiyet farkları nedeniyle doğrudan karşılaştırma yanıltıcı sonuçlar doğurabilir; bu yüzden epsilon tabanlı sınır tolerans karşılaştırmalarının yapılması önerilir.
35. **`feature = "test-support"` yapılandırması:** Test yardımcılarının yalnızca test aşamalarında derlenmesi ve normal üretim (release) paketlerine sızmaması için `#[cfg(any(test, feature = "test-support"))]` koşullu derleme özniteliğinin kullanılması gerekir.

### API yüzeyi

36. **`refinement` modülünün public olarak dışa açılması:** `pub use crate::refinement::*` kullanımı içsel iş kurallarını sızdırır. Modülün `pub(crate) mod refinement;` şeklinde tanımlanarak dış dünyadan gizlenmesi şarttır.
37. **`schema::*` modülünün glob (`*`) ile public ihraç edilmesi:** Bu durum eklenen her iç tipin kontrolsüz şekilde public olmasına yol açar. Schema tiplerinin tek tek seçilerek `pub use` ile sunulması gerekir.
38. **`Theme.styles` alanının doğrudan public (`pub`) yapılması:** Veri yapısının içsel yerleşim detaylarının sızmasına yol açar; tüm erişimler için accessor metotlarının (`theme.colors()`) tercih edilmesi önem arz eder.

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

Yukarıdaki öğelerin proje kapsam kararlarına uygun şekilde mirror edilmesi hedeflenir. Public API kapsamına dahil edilmeyen modüller ve yardımcı tipler, tüketici sözleşmesinin dışında kalacaktır.


---

# Son

Bu rehber, `kvs_tema` ve `kvs_syntax_tema` crate'lerinin **tüm yüzeyini** 12 ana bölüm ve 45 konu başlığı altında, uygulama kurulum aşamalarını takip ederek ele almaktadır. Süreç boyunca şu üç temel kural geçerliliğini korur:

1. **Veri sözleşmesinde eksiltme yapılmaması:** Zed'e ait tüm şema alanlarının eksiksiz olarak mirror edilmesi hedeflenir.
2. **Lisans-temiz çalışma** — kod gövdesi GPL'den kopyalanmaz; yalnızca sözleşme paritesi korunur.
3. **Sözleşme sınırı** — public API ile crate-içi detaylar birbirinden ayrılır; tüketici yalnızca açıkça desteklenen yüzeye bağlanır.

Beklenmedik bir derleme veya çalışma zamanı hatasıyla karşılaşıldığında öncelikle ilgili bölümdeki dikkat noktaları listesi incelenmelidir. Daha kapsamlı analiz ve çözümler için ilgili konunun ana metnine başvurulması önerilir.

---
