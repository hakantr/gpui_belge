# Tema Yukarı Akış (Upstream) Senkronu

Bu dosya, yerel tema sisteminin Zed'in `crates/theme` ve `crates/syntax_theme`
crate'lerine göre **hangi noktada senkron tutulduğunu** izler.

Amaç: Zed'de yapılan tema değişikliklerinin (yeni alan eklenmesi, schema
değişiklikleri, refinement davranışı değişimleri) bu projeye **kayda alınmış
şekilde** yansıyabilmesi.

> **Sync ritmi:** Önerilen cadence her 6-8 haftada bir tam tur.
> Her tur sonunda `zed_commit_pin.txt` ve bu dosya **mutlaka
> güncellenmelidir**: pin commit + tarih + inceleyen + geçmiş tablosuna yeni
> satır.

---

## Dizin yerleşimi

Bu doküman ve eşlik eden drift script'i `gpui_belge/` deposu altında durur.
Kaynak olarak kardeş dizindeki Zed yerel kopyası kullanılır:

```
~/github/
├── gpui_belge/                        ← bu depo (notlar + araçlar)
│   ├── tema_aktarimi.md               ← bu dosya
│   ├── zed_commit_pin.txt             ← diff taban commit'i
│   ├── tema_rehber.md                 ← mimari + kod rehberi
│   └── tema_kaymasi_kontrol.sh        ← timestamp'li Zed diff üretici
└── zed/                               ← Zed yerel kopyası (kaynak)
    ├── crates/theme/
    ├── crates/syntax_theme/
    ├── crates/settings_content/
    └── assets/themes/
```

Script varsayılan olarak `../zed`'i (yani komşu `zed/` dizinini) kullanır.
Çalıştırıldığında Zed kopyasını `zed_commit_pin.txt` içindeki commit'e geri
sabitler, yerel değişiklikleri temizler, sonra `git pull --ff-only` ile
upstream'den günceller. Zed kopyan başka bir yerdeyse argüman olarak ver:

```sh
./tema_kaymasi_kontrol.sh /baska/yol/zed /diff/cikti/dizini
```

---

## Mevcut durum

| Alan                       | Değer                                        |
|----------------------------|----------------------------------------------|
| Son incelenen Zed commit   | `db6039d815893750ad45e548d6a7c1a64bba5d2a`   |
| Pin dosyası                | `zed_commit_pin.txt`                         |
| Pin tarihi                 | 2026-05-11                                   |
| İnceleyen                  | hakantr                                      |
| Üst depo                   | `https://github.com/zed-industries/zed`      |
| Üst depo dalı              | `main`                                       |
| Yerel Zed kopyası          | `../zed` (`~/github/zed`)                    |

> Diff üretmek ve `../zed` kopyasını upstream'e çekmek için:
> `./tema_kaymasi_kontrol.sh`

Script, `zed_commit_pin.txt` içindeki commit'i taban alır; `../zed`
çalışma ağacını bu commit'e `git reset --hard` ile geri alır, untracked
dosyaları `git clean -fd` ile temizler, ardından `git pull --ff-only`
çalıştırır. Pull sonrası yeni `HEAD` pin'den farklıysa tam diff'i şu adla
kaydeder:

```text
zed_farkları<yıl-ay-gun-saat-dakika>-<güncel-kısa-commit>.diff
```

İş akışının amacı `../zed` deposunda yerel çalışma tutmamak, Zed'in upstream
kaynağına bağlı kalmaktır. Ignored dosyaların da silinmesi gerekiyorsa
`ZED_TEMIZLE_IGNORED=1 ./tema_kaymasi_kontrol.sh` kullan; bu durumda
`git clean -fdx` çalışır.

---

## İzlenen yollar

Bu yolların **tamamı** her sync turunda gözden geçirilir (yollar Zed reposuna
göredir, yani `../zed/<yol>`):

- `crates/theme/src/theme.rs`
- `crates/theme/src/styles/` — alan paritesinin kritik olduğu yer
- `crates/theme/src/schema.rs` — JSON sözleşmesi (eski konum, varsa)
- `crates/settings_content/src/theme.rs` — `ThemeColorsContent` / `StatusColorsContent` Content tipleri (rehberin Faz 2 kaynağı)
- `crates/theme/src/registry.rs` — runtime referansı
- `crates/theme/src/fallback_themes.rs` — türetme mantığı referansı
- `crates/theme/src/icon_theme.rs` — icon tema sözleşmesi
- `crates/syntax_theme/src/`
- `assets/themes/*.json` — fixture testleri için referans
- `assets/themes/LICENSE_*` — fixture lisans doğrulaması

Aşağıdaki yollar **kasıtlı olarak izlenmez** (runtime farklılığı):

- `crates/theme_settings/` — kendi settings glue'muz var
- `crates/theme_selector/` — kendi UI'mız var
- `crates/theme_importer/` — geliştirici aracı, kullanmıyoruz
- `crates/theme_extension/` — extension sistemimiz farklı

---

## Senkron edilMEYEN (kasıtlı) Zed özellikleri

Bu liste, **bilinçli olarak aynalamadığın** alanları ve gerekçesini tutar.
Sync turunda upstream'de bu alanlarla ilgili değişiklik görürsen gözden
geçir.

> **Varsayılan: hiçbir alan kasıtlı olarak dışlanmaz.** Bu rehber tüm
> Zed alanlarını (terminal_ansi, editor diff hunk, debugger, vcs, vim,
> vs.) destekleyen bir uygulama varsayar. Bir alanı buraya yazmak için
> **kalıcı ve kesin** bir dışlama kararı olmalı (örn. lisans çakışması).
> "Henüz yazmadık" bir dışlama sebebi değildir; o durumda struct'ta alan
> bulunur ama UI'da okunmaz — bkz. `tema_rehber.md` Faz 1.

- _(henüz yok)_

<!--
Format (gerçek karar değil, sadece şablon):
- `<alan veya alan grubu>` — kalıcı dışlama gerekçesi.
  Karar tarihi: YYYY-MM-DD. Gözden geçirme koşulu: <hangi durumda yeniden ele alınır>.
-->

---

## Bekleyen kararlar

Sync turunda fark edilen ama henüz karara bağlanmamış değişiklikler.

- _(henüz yok)_

<!--
Format (gerçek karar değil, sadece şablon):
- Zed #<PR> (<kısa-sha>): <ne değişti>.
  Soru: <kararlaştırılması gereken nokta>. Yanıt bekleniyor.
-->

---

## Senkron turu geçmişi

Her tur sonunda **yeni bir satır ekle**, eskilerini silme. Bu tablo zaman
içindeki tema sözleşmesi evrimini gösterir.

| Tarih       | Önceki pin    | Yeni pin       | İnceleyen | Eklenen alan sayısı | Notlar |
|-------------|---------------|----------------|-----------|---------------------|--------|
| 2026-05-11  | —             | `db6039d815`   | hakantr   | —                   | İlk pin: tema crate'i kurulurken alınan baseline. |

---

## Tur prosedürü (her seferinde yapılacaklar)

1. **Zed'i pine geri sabitle, upstream'den çek ve diff üret** (bu dizinden):
   ```sh
   ./tema_kaymasi_kontrol.sh
   ```
2. Script `zed_commit_pin.txt` commit'inden yeni Zed `HEAD` commit'ine kadar
   `zed_farkları*.diff` üretirse dosyayı incele; tema, bileşen, GPUI ve
   genel rehber yüzeylerini etkileyen değişiklikleri ayır.
3. Gerekirse commit listesinden ilgili PR/commit'i **tek tek aç**, alan
   değişikliklerini not al:
   ```sh
   git -C ../zed show <sha>
   ```
4. **Yeni eklenen alanlar** için karar ver:
   - Bizim için anlamlı mı? → yerel struct'a ekle, fixture testlerini güncelle.
   - Anlamlı değil mi? → bu dosyada "Senkron edilMEYEN" bölümüne **gerekçeyle** yaz.
5. **Kaldırılan alanlar** için karar ver:
   - Biz hâlâ kullanıyor muyuz? → kaldırma, ama "Pending decisions" bölümüne not düş.
6. **Davranış değişiklikleri** (refinement, türetme mantığı):
   - `DECISIONS.md`'ye yansıt; gerekirse implementasyonu güncelle.
7. **Fixture testlerini güncelle:** uygulama tarafındaki `tests/fixtures/`
   altındaki gerçek Zed tema JSON'larını yeni pin commit'inden yenile,
   testleri çalıştır.
8. **Pin ve bu dosyayı güncelle:**
   - `zed_commit_pin.txt` içeriğini yeni tam SHA ile değiştir.
   - "Mevcut durum" tablosundaki commit + tarih + inceleyen alanlarını değiştir.
   - "Senkron turu geçmişi" tablosuna yeni satır ekle.
9. **Tek bir commit olarak işle:** `tema: Upstream sync to <kısa-sha>` başlığıyla.

---

## Lisans notları

- `crates/theme` ve `crates/syntax_theme` → **GPL-3.0-or-later**.
  Kod gövdesi **kopyalanamaz**; yalnızca alan adları/JSON sözleşmesi mirror edilir.
- `crates/refineable`, `crates/collections`, `crates/gpui` → **Apache-2.0**.
  Doğrudan dependency olarak kullanılabilir.
- `assets/themes/*.json` → ayrı `LICENSE` dosyasına bak (Zed reposunda
  `assets/themes/` altında); fixture olarak kullanmadan önce **her sync
  turunda lisansı doğrula**.
