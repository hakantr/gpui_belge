# Tema Yukarı Akış (Upstream) Senkronu

Bu dosya, yerel tema sisteminin Zed'in `crates/theme` ve `crates/syntax_theme`
crate'lerine göre **hangi noktada senkron tutulduğunu** izler.

Amaç: Zed'de yapılan tema değişikliklerinin (yeni alan eklenmesi, schema
değişiklikleri, refinement davranışı değişimleri) bu projeye **kayda alınmış
şekilde** yansıyabilmesi.

> **Sync ritmi:** Önerilen cadence her 6-8 haftada bir tam tur.
> Her tur sonunda bu dosya **mutlaka güncellenmelidir**: pin commit + tarih +
> inceleyen + geçmiş tablosuna yeni satır.

---

## Dizin yerleşimi

Bu doküman ve eşlik eden drift script'i `gpui_belge/` deposu altında durur.
Kaynak olarak kardeş dizindeki Zed yerel kopyası kullanılır:

```
~/github/
├── gpui_belge/                        ← bu depo (notlar + araçlar)
│   ├── tema_aktarimi.md               ← bu dosya
│   └── tema_kaymasi_kontrol.sh        ← drift raporu
└── zed/                               ← Zed yerel kopyası (kaynak)
    ├── crates/theme/
    ├── crates/syntax_theme/
    └── assets/themes/
```

Script varsayılan olarak `../zed`'i (yani komşu `zed/` dizinini) okur.
Zed kopyan başka bir yerdeyse argüman olarak ver:

```sh
./tema_kaymasi_kontrol.sh /baska/yol/zed
```

---

## Mevcut durum

| Alan                       | Değer                                        |
|----------------------------|----------------------------------------------|
| Son incelenen Zed commit   | `db6039d815893750ad45e548d6a7c1a64bba5d2a`   |
| Pin tarihi                 | 2026-05-11                                   |
| İnceleyen                  | hakantr                                      |
| Üst depo                   | `https://github.com/zed-industries/zed`      |
| Üst depo dalı              | `main`                                       |
| Yerel Zed kopyası          | `../zed` (`~/github/zed`)                    |

> Drift raporu çalıştırmak için: `./tema_kaymasi_kontrol.sh`

---

## İzlenen yollar

Bu yolların **tamamı** her sync turunda gözden geçirilir (yollar Zed reposuna
göredir, yani `../zed/<yol>`):

- `crates/theme/src/theme.rs`
- `crates/theme/src/styles/` — alan paritesinin kritik olduğu yer
- `crates/theme/src/schema.rs` — JSON sözleşmesi
- `crates/theme/src/registry.rs` — runtime referansı (mirror zorunlu değil)
- `crates/theme/src/fallback_themes.rs` — türetme mantığı referansı
- `crates/theme/src/icon_theme.rs` (yalnızca icon tema aktifse)
- `crates/syntax_theme/src/`
- `assets/themes/*.json` — fixture testleri için referans

Aşağıdaki yollar **kasıtlı olarak izlenmez** (runtime farklılığı):

- `crates/theme_settings/` — kendi settings glue'muz var
- `crates/theme_selector/` — kendi UI'mız var
- `crates/theme_importer/` — geliştirici aracı, kullanmıyoruz
- `crates/theme_extension/` — extension sistemimiz farklı

---

## Senkron edilMEYEN (kasıtlı) Zed özellikleri

Bu liste, "bilinçli olarak aynalamadığımız" özellikleri ve **gerekçesini**
tutar. Sync turunda upstream'de bu alanlarla ilgili değişiklik görürsen
gözden geçir.

- _(henüz yok)_

<!--
Örnek:
- `terminal_ansi_*` (16 alan) — uygulamada terminal yok.
  Karar tarihi: 2026-05-11. Gözden geçirme: terminal eklediğimizde.
-->

---

## Bekleyen kararlar

Sync turunda fark edilen ama henüz karara bağlanmamış değişiklikler.

- _(henüz yok)_

<!--
Örnek:
- Zed #51784 (fb3218e01e): editor diff hunk renkleri eklendi.
  Soru: Bizim editor bileşenimiz diff gösteriyor mu? Yanıt bekleniyor.
-->

---

## Senkron turu geçmişi

Her tur sonunda **yeni bir satır ekle**, eskilerini silme. Bu tablo zaman
içindeki tema sözleşmesi evrimini gösterir.

| Tarih       | Önceki pin    | Yeni pin       | İnceleyen | Eklenen alan sayısı | Notlar |
|-------------|---------------|----------------|-----------|---------------------|--------|
| 2026-05-11  | —             | `db6039d815`   | hakantr   | —                   | İlk pin: yerel_tema crate'i kurulurken alınan baseline. |

---

## Tur prosedürü (her seferinde yapılacaklar)

1. **Drift raporunu çalıştır** (bu dizinden):
   ```sh
   ./tema_kaymasi_kontrol.sh
   ```
2. Çıkan commit listesinde tema/styles dosyalarına dokunan her PR'ı **tek tek aç**, alan değişikliklerini not al:
   ```sh
   git -C ../zed show <sha>
   ```
3. **Yeni eklenen alanlar** için karar ver:
   - Bizim için anlamlı mı? → yerel struct'a ekle, fixture testlerini güncelle.
   - Anlamlı değil mi? → bu dosyada "Senkron edilMEYEN" bölümüne **gerekçeyle** yaz.
4. **Kaldırılan alanlar** için karar ver:
   - Biz hâlâ kullanıyor muyuz? → kaldırma, ama "Pending decisions" bölümüne not düş.
5. **Davranış değişiklikleri** (refinement, türetme mantığı):
   - `DECISIONS.md`'ye yansıt; gerekirse implementasyonu güncelle.
6. **Fixture testlerini güncelle:** uygulama tarafındaki `tests/fixtures/`
   altındaki gerçek Zed tema JSON'larını yeni pin commit'inden yenile,
   testleri çalıştır.
7. **Bu dosyayı güncelle:**
   - "Mevcut durum" tablosundaki commit + tarih + inceleyen alanlarını değiştir.
   - "Senkron turu geçmişi" tablosuna yeni satır ekle.
8. **Tek bir commit olarak işle:** `tema: Upstream sync to <kısa-sha>` başlığıyla.

---

## Lisans notları

- `crates/theme` ve `crates/syntax_theme` → **GPL-3.0-or-later**.
  Kod gövdesi **kopyalanamaz**; yalnızca alan adları/JSON sözleşmesi mirror edilir.
- `crates/refineable`, `crates/collections`, `crates/gpui` → **Apache-2.0**.
  Doğrudan dependency olarak kullanılabilir.
- `assets/themes/*.json` → ayrı `LICENSE` dosyasına bak (Zed reposunda
  `assets/themes/` altında); fixture olarak kullanmadan önce **her sync
  turunda lisansı doğrula**.
