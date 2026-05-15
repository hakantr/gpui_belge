# Pratik kontrol listesi

Son bölüm, önceki adımlarda yapılan kararları hata sınıflarına göre hızlı kontrol listesine çevirir.

---

## 45. Yaygın tuzaklar

Önceki bölümlerde dağınık olan tuzakları **tek yerde** toplar; her
madde bir-iki cümle özet + bölüm referansı. Detay için ilgili konuya
dön.

### Sözleşme katmanı (Bölüm IV ve V)

1. **`#[serde(deny_unknown_fields)]` kullanmak.** Zed yeni alan ekleyince
   parse patlar. **Asla kullanma.** → Konu 22.
2. **JSON'da snake_case beklemek.** Zed `border.variant` yazıyor;
   `#[serde(rename = "border.variant")]` şart, yoksa alan sessizce
   boş kalır. → Konu 23.
3. **`Option<Hsla>` yerine `Option<String>` kullanmak.** Sıkı tipli
   parse hatası tüm temayı bozar; iki katmanlı opsiyonellik (Content
   katmanı string + Refinement katmanı Hsla) sözleşmenin temeli. → Konu 20.
4. **Bir alan grubunu "şimdilik gerek yok" diye atlamak.** `terminal_ansi`,
   debugger, diff hunk, vcs, vim, icon theme — UI'da okumasan bile
   struct'ta bulunmalı. Aksi halde sözleşme delinmesi. → Konu 2 (Temel
   ilke), Konu 13.
5. **`#[refineable(...)]` attribute'u atlamak.** Refinement tipi sadece
   `Default + Clone` türetilir; serde/JSON deserialize'a kapanır. → Konu 11.

### Refinement (Bölüm VII)

6. **Türetme adımını atlayıp `refine`'a doğrudan gitmek.** Status'ta
   kullanıcı `error` yazdı ama `error_background` yok; baseline'dan
   gelen koyu/açık karışım çıkar. `apply_status_color_defaults` şart.
   → Konu 31.
7. **`color()` helper'ında hata mesajı yutmak.** Production debug için
   `inspect_err` ile log ekle; default tut kapalı. → Konu 30.
8. **Baseline'ı yanlış appearance ile seçmek.** Light tema yüklerken
   dark baseline = uyumsuz görüntü. `content.appearance`'a göre seç.
   → Konu 32.

### Runtime (Bölüm VIII)

9. **`cx.refresh_windows()` çağırmamak.** Tema değişti ama UI eski
   renkte kalır — en yaygın tema bug'ı. `GlobalTheme::update_theme +
   refresh_windows` her zaman çift. → Konu 38.
10. **`cx.notify()` ile yetinmek.** Tek view'ı yeniler; tema tüm
    pencerelerde geçerli. → Konu 39.
11. **`kvs_tema::init`'i atlamak.** `cx.theme()` panic eder. Uygulama
    girişinin **ilk** satırı. → Konu 36.
12. **`update_global` içinde `set_global`.** Re-entrancy panic. Update
    callback içinde sadece field mutate. → Konu 34.
13. **`observe_window_appearance`'da `.detach()` unutmak.** Subscription
    drop olur, observer ölür. → Konu 35.

### GPUI tipleri (Bölüm III)

14. **Hue 0-360 yazmak.** GPUI hue 0-1 normalize; `hsla(210.0, ...)`
    aslında `hsla(210.0 / 360.0, ...)` olmalı. → Konu 6.
15. **`Hsla::default()` ile struct doldurmak.** `(0,0,0,0)` = görünmez.
    Tüm 150 + 42 alanı açık değerle yaz. → Konu 6, 25.
16. **`opacity` vs `alpha` karıştırmak.** `opacity(x)` `* x` çarpar;
    `alpha(x)` direkt set eder. → Konu 6.
17. **`use kvs_tema::ActiveTheme;` unutmak.** `cx.theme()` "method not
    found". Prelude kullan. → Konu 41.

### Etkileşim (Bölüm X)

18. **`.id()` atlamak.** Interactivity stateful; ID yoksa hover/active
    çalışmaz, sessiz başarısızlık. → Konu 42.
19. **`element_selected` ile `element_selection_background` karıştırmak.**
    İlki liste öğesi seçimi, ikincisi metin highlight. → Konu 42.
20. **Ghost vs element grubunu karıştırmak.** Toolbar'da `element_*`
    kullanırsan yüzey rengiyle dolar = tasarım dili kayar. → Konu 42.

### Bundling / lisans (Bölüm VI)

21. **`palette` versiyonunu Zed'le aynı tutmamak.** Renk dönüşümü kayar;
    fixture testleri kırılır. → Konu 5, 21.
22. **`refineable` dep'ini fork'lamadan production.** `publish = false`
    crates.io engelliyor; vendor veya fork şart. → Konu 3, 26.
23. **Zed `default_colors.rs` HSL'ini birebir kopyalamak.** GPL-3 ihlali.
    Kendi anchor'larını seç. → Konu 3, 25.
24. **Lisans dosyasını "sonra ekleyeyim" demek.** Bundled tema atıf
    eksik = telif ihlali. → Konu 27.
25. **GPL lisanslı fixture'ı atlamamak.** Tema JSON'unda HSL bile telif;
    sadece MIT/Apache lisanslı temaları fixture'a koy. → Konu 27.

### Test (Bölüm VI ve XI)

26. **`#[gpui::test]` `cx.update` içinde init yapmamak.** Test başında
    `kvs_tema::init(cx)` veya `init_test(cx)`. → Konu 44.
27. **Hsla `assert_eq!` ile karşılaştırma.** Float eşitliği tehlikeli;
    epsilon karşılaştırma. → Konu 28.
28. **`feature = "test-util"` production'da açık.** `#[cfg(any(test,
    feature = "test-util"))]` koşulu; release'de kapanmalı. → Konu 44.

### API yüzeyi (Bölüm XI)

29. **`refinement.rs` modülünü public yapmak.** `pub use crate::refinement::*`
    sözleşmeyi sızdırır. `pub(crate) mod refinement;` zorunlu. → Konu 43.
30. **`schema::*` glob ile public.** Yeni iç tip otomatik public olur.
    Tek tek `pub use` yaz. → Konu 43.
31. **`Theme.styles` field'ı doğrudan public.** İç düzen sızıntısı;
    accessor metotları (`theme.colors()`) öner. → Konu 12, 41.

### Özet karar matrisi

Önceki pratik bölümünde toplanmış olan "İleri öğeler" başlığı ilgili
katmanlara dağıtıldı; aşağıdaki tablo, mirror kararı için kanonik
kısa kontrol listesidir:

| Zed öğesi | `kvs_tema` mirror gerekli mi? | Hangi sürümde? |
|-----------|-------------------------------|----------------|
| `LoadThemes` | Önerilir | Init API'yi finalize ederken |
| `ThemeSettingsProvider` | Settings entegrasyonu için **gerekli** | Tema selector / runtime ayar yapacaksan |
| `UiDensity` | Tema değil, settings — yine de mirror edilmesi gerekir | Spacing tutarlılığı için |
| `all_theme_colors` / `ThemeColorField` | Tema editörü/preview için **gerekli**, başka durumda opsiyonel | Tema editörü yazılırken |
| `ColorScale` ailesi | **Çoğu uygulama için gereksiz** | Sadece geniş tema variant matrisi gerekirse |
| `apply_theme_color_defaults` | Gerekli (Konu 31'in ikiz fonksiyonu) | İlk sürümde |
| `deserialize_icon_theme` | Trivial helper, sarmalama önerilir | Icon tema yüklerken |
| `FontFamilyCache` | Hayır — sözleşme dışı | — |
| `DiagnosticColors` | Editor render path'i kullanıyorsa **gerekli** | Editor entegre olduğunda |
| Registry sabitleri / typed error'lar | Registry mirror ediliyorsa **gerekli** | İlk registry sürümünde |
| `default_color_scales` / `zed_default_themes` | Karara bağlı | Fallback ve scale mirror kararında |

Yukarıdaki öğeler kapsam kararına göre mirror edilir; public API'ye
alınmayan parçalar tüketici sözleşmesinin dışında kalır.

> **Referans:** Bölüm IV/Konu 14 (DiagnosticColors detayı), Bölüm VII/Konu
> 31 (apply_status_color_defaults + apply_theme_color_defaults), Bölüm
> VIII/Konu 34-38 ve Bölüm IX/Konu 39 (runtime/settings), Bölüm VI/Konu
> 25 (fallback tasarımı).

---

# Son

Bu rehber `kvs_tema` ve `kvs_syntax_tema` crate'lerinin **tüm yüzeyini**
12 bölüm ve 45 konuda, uygulama kurulum sırasına göre toplar. Üç temel kural:

1. **Veri sözleşmesinde dışlama yok** — Zed'in tüm alanları mirror edilir
   (Konu 2).
2. **Lisans-temiz çalışma** — kod gövdesi GPL'den kopyalanmaz, sadece
   sözleşme paritesi (Konu 3).
3. **Sözleşme sınırı** — public API ve crate-içi detaylar ayrılır; tüketici
   yalnız kararlı yüzeye bağlanır.

Beklenmedik bir durum yaşarsan önce Bölüm XII'deki tuzaklar listesine bak;
detay için ilgili konuya geri dön.

---

