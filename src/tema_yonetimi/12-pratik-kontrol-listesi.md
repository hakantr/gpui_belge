# Pratik kontrol listesi

Son bölüm; önceki adımlarda alınan kararları hata sınıflarına göre
hızlıca taranabilir bir kontrol listesine çevirir. Burada her madde
yalnızca özet niteliğindedir; detay gerektiğinde ilgili konuya
dönülmesi gerekir.

---

## 45. Yaygın tuzaklar

Önceki bölümlerde dağınık olan tuzaklar **tek bir yerde** toplanır; her
madde bir-iki cümle özet içerir ve bölüm referansıyla bağlanır.
Ayrıntılı tartışma için ilgili konuya dönülmesi yerinde olur.

### Sözleşme katmanı (Bölüm IV ve V)

1. **`#[serde(deny_unknown_fields)]` kullanımı.** Zed yeni bir alan
   eklediğinde parse patlar. **Bu attribute hiçbir biçimde kullanılmaz.**
   → Konu 22.
2. **JSON'da snake_case beklemek.** Zed `border.variant` yazar;
   `#[serde(rename = "border.variant")]` şarttır, yoksa alan sessizce
   boş kalır. → Konu 23.
3. **`Option<Hsla>` yerine `Option<String>` kullanmanın gerekçesi.**
   Sıkı tipli bir parse hatası tüm temayı bozar; iki katmanlı
   opsiyonellik (Content katmanı string + Refinement katmanı Hsla)
   sözleşmenin temelidir. → Konu 20.
4. **Bir alan grubunu "şimdilik gerek yok" diye atlamak.**
   `terminal_ansi`, debugger, diff hunk, vcs, vim, icon theme — UI'da
   okunmuyor olsa bile struct'ta bulunmalıdır. Aksi halde sözleşme
   delinir. → Konu 2 (Temel ilke), Konu 13.
5. **`#[refineable(...)]` attribute'unu atlamak.** Refinement tipi
   yalnızca `Default + Clone` türevini taşır; serde/JSON deserialize
   yolu kapanır. → Konu 11.

### Refinement (Bölüm VII)

6. **Türetme adımının atlanıp doğrudan `refine`'a geçilmesi.** Status
   alanlarında kullanıcı `error` yazar ama `error_background` yazmazsa,
   baseline'dan gelen karışım renkler ortaya çıkar.
   `apply_status_color_defaults` çağrısı şarttır. → Konu 31.
7. **`color()` helper'ında hata mesajının yutulması.** Production
   debug için `inspect_err` ile log eklenebilir; default'ta kapalı
   tutulur. → Konu 30.
8. **Baseline'ın yanlış appearance ile seçilmesi.** Light tema
   yüklenirken dark baseline kullanılması uyumsuz bir görüntü doğurur.
   Baseline `content.appearance` değerine göre seçilmelidir. → Konu 32.

### Runtime (Bölüm VIII)

9. **`cx.refresh_windows()`'ın çağrılmaması.** Tema değişir ama UI
   eski renkte kalır — en yaygın tema bug'ıdır. `GlobalTheme::update_theme
   + refresh_windows` her zaman bir çift olarak çağrılmalıdır.
   → Konu 38.
10. **`cx.notify()` ile yetinmek.** Yalnızca tek view'ı yeniler; oysa
    tema değişimi tüm pencerelerde geçerli olur. → Konu 39.
11. **`kvs_tema::init`'in atlanması.** `cx.theme()` panic atar. Bu
    çağrı uygulama girişinin **ilk** satırı olarak konumlanır.
    → Konu 36.
12. **`update_global` içinde `set_global` çağrılması.** Re-entrancy
    panic'i üretir. Update callback'i içinde yalnızca field mutate
    edilebilir. → Konu 34.
13. **`observe_window_appearance`'da `.detach()` unutulması.**
    Subscription drop edildiğinde observer ölür. → Konu 35.

### GPUI tipleri (Bölüm III)

14. **Hue'nun 0–360 aralığında yazılması.** GPUI hue 0–1 normalizedir;
    `hsla(210.0, ...)` aslında `hsla(210.0 / 360.0, ...)` biçiminde
    olmalıdır. → Konu 6.
15. **`Hsla::default()` ile struct doldurmak.** `(0,0,0,0)` görünmez
    bir değer üretir. 150 + 42 alanın tamamı açık değerlerle
    doldurulmalıdır. → Konu 6, 25.
16. **`opacity` ile `alpha` arasındaki farkın karıştırılması.**
    `opacity(x)` mevcut alpha'yı `* x` ile çarpar; `alpha(x)` ise
    doğrudan set eder. → Konu 6.
17. **`use kvs_tema::ActiveTheme;` import'unun unutulması.**
    `cx.theme()` çağrısı "method not found" hatası verir. Prelude
    kullanılması pratik bir çözüm sağlar. → Konu 41.

### Etkileşim (Bölüm X)

18. **`.id()` çağrısının atlanması.** Interactivity stateful'dur; ID
    olmadan hover/active çalışmaz ve sessiz bir başarısızlık ortaya
    çıkar. → Konu 42.
19. **`element_selected` ile `element_selection_background`
    karıştırılması.** İlki liste öğesi seçimini, ikincisi metin
    highlight'ını temsil eder. → Konu 42.
20. **Ghost ile element grubunun karıştırılması.** Toolbar'da
    `element_*` kullanıldığında yüzey rengiyle dolar ve tasarım dili
    kayar. → Konu 42.

### Bundling / lisans (Bölüm VI)

21. **`palette` sürümünün Zed'le aynı tutulmaması.** Renk dönüşümü
    kayar; fixture testleri kırılır. → Konu 5, 21.
22. **`refineable` dep'inin fork'lanmadan production'a alınması.**
    `publish = false` ayarı crates.io yayını engeller; vendor veya
    fork şarttır. → Konu 3, 26.
23. **Zed `default_colors.rs` HSL değerlerinin birebir kopyalanması.**
    GPL-3 ihlalidir. Bağımsız anchor değerleri seçilmelidir. → Konu 3, 25.
24. **Lisans dosyasını "sonradan eklerim" demek.** Bundled tema'ya
    atıf eklenmediğinde telif ihlali oluşur. → Konu 27.
25. **GPL lisanslı fixture'ın atlanmaması.** Tema JSON'undaki HSL
    değerleri bile telif kapsamına girer; yalnızca MIT/Apache lisanslı
    temalar fixture'a alınır. → Konu 27.

### Test (Bölüm VI ve XI)

26. **`#[gpui::test]` `cx.update` içinde init yapmamak.** Test başında
    `kvs_tema::init(cx)` veya `init_test(cx)` çağrısı gerekir. → Konu 44.
27. **Hsla'nın `assert_eq!` ile karşılaştırılması.** Float eşitliği
    yanıltıcıdır; epsilon karşılaştırması tercih edilir. → Konu 28.
28. **`feature = "test-util"`'ın production'da açık bırakılması.**
    `#[cfg(any(test, feature = "test-util"))]` koşulu kurulur; release
    build'inde kapatılmalıdır. → Konu 44.

### API yüzeyi (Bölüm XI)

29. **`refinement.rs` modülünün public yapılması.**
    `pub use crate::refinement::*` sözleşmeyi sızdırır.
    `pub(crate) mod refinement;` zorunludur. → Konu 43.
30. **`schema::*` glob ile public ihraç.** Yeni iç tip otomatik
    olarak public hale gelir. Tek tek `pub use` yazılmalıdır. → Konu 43.
31. **`Theme.styles` field'ının doğrudan public olması.** İç düzen
    sızıntısına yol açar; accessor metotlarının (`theme.colors()`)
    tercih edilmesi gerekir. → Konu 12, 41.

### Özet karar matrisi

Önceki pratik bölümünde toplanmış olan "İleri öğeler" başlığı ilgili
katmanlara dağıtılmıştır; aşağıdaki tablo, mirror kararı için kanonik
ve kısa kontrol listesini sunar:

| Zed öğesi | `kvs_tema` mirror gerekli mi? | Hangi sürümde? |
|-----------|-------------------------------|----------------|
| `LoadThemes` | Önerilir | Init API'sinin finalize edilmesi sırasında |
| `ThemeSettingsProvider` | Settings entegrasyonu için **gerekli** | Tema selector veya runtime ayar eklendiğinde |
| `UiDensity` | Tema değil, settings — yine de mirror edilmesi gerekir | Spacing tutarlılığı için |
| `all_theme_colors` / `ThemeColorField` | Tema editörü/preview için **gerekli**, diğer durumlarda opsiyonel | Tema editörü yazıldığında |
| `ColorScale` ailesi | **Çoğu uygulama için gereksiz** | Yalnızca geniş tema varyant matrisi gerektiğinde |
| `apply_theme_color_defaults` | Gerekli (Konu 31'in ikiz fonksiyonu) | İlk sürümde |
| `deserialize_icon_theme` | Trivial bir helper; sarmalanması önerilir | Icon tema yüklendiğinde |
| `FontFamilyCache` | Hayır — sözleşme dışıdır | — |
| `DiagnosticColors` | Editor render path'i kullanıyorsa **gerekli** | Editor entegre olduğunda |
| Registry sabitleri / typed error'lar | Registry mirror ediliyorsa **gerekli** | İlk registry sürümünde |
| `default_color_scales` / `zed_default_themes` | Karara bağlıdır | Fallback ve scale mirror kararı verildiğinde |

Yukarıdaki öğeler kapsam kararına göre mirror edilir; public API'ye
alınmayan parçalar tüketici sözleşmesinin dışında kalır.

> **Referans:** Bölüm IV/Konu 14 (DiagnosticColors detayı), Bölüm
> VII/Konu 31 (apply_status_color_defaults +
> apply_theme_color_defaults), Bölüm VIII/Konu 34–38 ile Bölüm IX/Konu
> 39 (runtime/settings), Bölüm VI/Konu 25 (fallback tasarımı).

---

# Son

Bu rehber, `kvs_tema` ve `kvs_syntax_tema` crate'lerinin **tüm
yüzeyini** 12 bölüm ve 45 konu altında, uygulama kurulum sırasını
izleyerek toplar. Üç temel kural baştan sona geçerli kalır:

1. **Veri sözleşmesinde dışlama yok** — Zed'in tüm alanları mirror
   edilir (Konu 2).
2. **Lisans-temiz çalışma** — kod gövdesi GPL'den kopyalanmaz; yalnızca
   sözleşme paritesi korunur (Konu 3).
3. **Sözleşme sınırı** — public API ile crate-içi detaylar birbirinden
   ayrılır; tüketici yalnızca kararlı yüzeye bağlanır.

Beklenmedik bir durumla karşılaşıldığında ilk başvurulacak yer Bölüm
XII'deki tuzaklar listesidir; daha geniş bir tartışma için ilgili
konuya geri dönülmesi yerinde olur.

---
