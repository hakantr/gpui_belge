# Anlatım Belgeleri Denetim Raporu

**Tarih:** 2026-06-07
**Kapsam:** `src/` altındaki tüm anlatım belgeleri — 95 Markdown dosyası, ~31.700 satır, 8 tematik bölüm + `SUMMARY.md`.
**Yöntem:** Her tematik bölüm bir denetçiye verilip dosyalar satır satır okundu (8 bölüm-denetçisi). `SUMMARY.md` ve kitap geneli terim tutarlılığı ayrıca elden geçirildi. Dört eksen denetlendi: **anlam**, **anlatım**, **kavram**, **konu bütünlüğü**.
**Sonuç:** Toplam **125 bulgu** — 12 yüksek, 43 orta, 70 düşük öncelik.

> Not: Çarpıcı bulgular (Devanagari sözcük kalıntısı, "Yapılamaz" sütunu çelişkisi, kopyalanmış cümle) gerçek dosyalara karşı tek tek doğrulanmıştır; rapor uydurma bulgu içermez.

---

## 1. Genel tablo

### Öneme göre bölüm dağılımı

| Bölüm | Yüksek | Orta | Düşük | Toplam |
|-------|:------:|:----:|:-----:|:------:|
| gpui_kullanimi | 2 | 8 | 8 | 18 |
| bilesenler | 1 | 17 | 10 | 28 |
| calisma_alani | 0 | 2 | 15 | 17 |
| ayarlar | 0 | 1 | 8 | 9 |
| tema_yonetimi | 4 | 4 | 5 | 13 |
| assets | 4 | 4 | 8 | 16 |
| platform_ust_bar | 0 | 4 | 8 | 12 |
| ust_bar | 1 | 3 | 8 | 12 |
| **Toplam** | **12** | **43** | **70** | **125** |

### Eksene göre dağılım

| Eksen | Bulgu |
|-------|:-----:|
| Anlatım (ifade, yazım, anglisizm) | 73 |
| Kavram (terim, tanım) | 20 |
| Konu bütünlüğü (akış, tekrar, sıra) | 19 |
| Anlam (mantık, çelişki) | 13 |

**Genel değerlendirme:** Belgelerin teknik kalitesi yüksek; kavramsal hata neredeyse yok ve kod tanımlayıcıları (tip/fonksiyon adları) tutarlı biçimde çevrilmeden korunmuş. Sorunların büyük çoğunluğu **anlatım düzeyinde** ve önemli bir bölümü **makineyle düzeltilebilir kopyala-yapıştır/çeviri kalıntısı**. En kritik kümeler `assets` ve `tema_yonetimi` bölümlerinde toplanıyor.

---

## 2. Kitap geneli sistematik sorunlar

Bunlar tek bir dosyaya değil, kitabın tamamına yayılan ve toplu düzeltilmesi gereken sorunlardır.

### 2.1 Devanagari "भी" sözcük kalıntısı — 5 dosya (kritik, mekanik)

Türkçe cümlelerin ortasına, "de/da" bağlacının geleceği yere, Hintçe **भी** (okunuşu "bhi", anlamı "de/da") sözcüğü karışmış. Bu, otomatik çeviri ya da kopyala-yapıştır kalıntısıdır ve cümleyi bozar. Beş yerde geçiyor:

- `src/assets/04-icon-ve-svg-sistemi.md:448`
- `src/assets/07-json-varlik-akisi.md:326`
- `src/gpui_kullanimi/04-async-gorev-ve-durum-yonetimi.md:627`
- `src/gpui_kullanimi/05-pencere-yonetimi.md:304`
- `src/tema_yonetimi/08-runtime-kurulusu-ve-tema-secimi.md:957`

**Düzeltme:** Her birinde `भी` → `de`/`da` (uygun ek uyumuyla). Tek geçişte toplu düzeltilebilir.

### 2.2 Düz metinde İngilizce "and" bağlacı (anglisizm kalıbı)

Kod bloğu **dışındaki** anlatım metninde, iki kod adı arasında İngilizce `and` bırakılmış. Özellikle `gpui_kullanimi` bölümünde yoğun: 02:138, 04:98, 10:186/192/271, 14:665/709 ve başka yerler. Hepsi `ve` olmalı.

### 2.3 Yazım/dizgi kalıntıları

Tekil ama belirgin dizgi hataları (otomatik düzeltme adayı):
- `assets/04:295` — "**Asel** rasterleştirme" → "**Asıl**"
- `assets/05:335` — "ayrı **un** cache yapısına" → "ayrı **bir önbellek** yapısına"
- `assets/08:387,398` — `disabled_dizin_tarama` fonksiyon adındaki anlamsız `disabled_` öneki (eski taslak kalıntısı)
- `gpui_kullanimi/06:31` — "görünüm**ın**" → "görünüm**ün**"
- `gpui_kullanimi/14:627` — "çağr**a**bilirsin" → "çağ**ı**rabilirsin"

### 2.4 Kopyalanmış cümle / yanlış zaman kalıntısı

- `assets/05-image-ve-raster-varlik.md:94` — Cümle 04. bölümden olduğu gibi kopyalanmış; "sonraki bölümde ele alınacaktır" diyor ama konu **tam da bu bölümde** işleniyor. 85-94 aralığı 04. bölümle büyük ölçüde tekrar.

### 2.5 Terim tutarsızlığı (kavram + anlatım, kitap geneli)

Kod adları çevrilmeden korunmuş (tutarlı, doğru). Ancak **gündelik teknik kavramlar** hem Türkçe-İngilizce arasında hem de birden çok Türkçe karşılık arasında salınıyor. Tek bir terim sözlüğüyle (her terim için tek karşılık) hizalanmalı:

| Kavram | Kullanılan karşılıklar | Öneri |
|--------|------------------------|-------|
| cache | "önbellek" / "cache" karışık | **önbellek** |
| fallback | "yedek" / "geri dönüş" / "fallback" | **yedek** |
| override | "geçersiz kılma" / "üzerine yazma" / "override" | tek karşılık seçilmeli |
| buffer | "tampon" / "arabellek" / "tampon bellek" (calisma_alani içinde 3 farklı) | tek karşılık seçilmeli |
| mirror | "ayna" / "yansıtma" / "mirror" (tema_yonetimi içinde 3'ü de) | tek karşılık seçilmeli |
| serialization | dosya adında "serializasyon", metinde "serileştirme" | **serileştirme** |
| registry | "sicil" / "kayıt" / "registry" | tek karşılık seçilmeli |
| recursive | "özyinelemeli" / "rekürsif" | **özyinelemeli** |
| sidebar | "sidebar" / "yan bar" / "yan panel" | tek karşılık seçilmeli |
| popover | "açılır panel" / "açılır menü" (ust_bar 03) | **açılır panel** |
| method | "metot" / "yöntem" | **metot** |

### 2.6 `SUMMARY.md` (içindekiler) — biçim tutarsızlıkları

- ✅ 94 dosyanın tamamı doğru bağlanmış; kırık bağlantı veya öksüz dosya yok.
- **Numaralandırma tutarsız:** Yalnızca "Zed UI Bileşenleri" bölümü başlıklarda numara taşıyor ("1.", … "17."); diğer 7 bölüm numarasız. Tek kalıba indirilmeli.
- **Başlık büyük/küçük harf düzeni iki kalıpta:** İlk 4 bölüm Başlık Düzeni ("Dock ve Panel Modeli"), son 4 bölüm (tema, asset, platform, üst bar) cümle düzeni ("Hedef, kapsam ve lisans"). Tek kalıp seçilmeli.
- **Anglisizm (başlık):** Satır 32 "**Feedback** ve Durum Göstergeleri" → "Geri Bildirim"; satır 45 "**Async** Hata" → "Eşzamansız".

---

## 3. Bölüm bölüm ayrıntılı bulgular

Aşağıda her bölümün özeti, klasör içi bütünlük değerlendirmesi ve bulguları öncelik sırasına göre listelenmiştir. Her bulguda: `dosya:satır` — [eksen] sorun, alıntı ve düzeltme önerisi.

## src/gpui_kullanimi/

**Özet:** 17 dosyanin tamami satir satir okundu. Genel kalite yuksek; cumleler akici, teknik kavramlar tutarli ve kod tanimlayicilari dogru sekilde cevrilmeden birakilmis. En kritik bulgular: (1) 04 ve 05 dosyalarinda Turkce metne karismis Devanagari 'भी' karakteri (yuksek onem, ceviri artigi, cumleyi bozuyor). (2) Birden cok dosyada (02, 04, 10x3, 14x2) duz anlatim metninde Ingilizce 'and' baglacinin 've' yerine kalmasi - tekrarlayan anglisizm kalibi. (3) Cesitli yazim hatalari: 'gorunumin' (06), 'cagrabilirsin' (14), 'dusunlenmemelidir' (14), 'ulasilasip' (12). (4) Birkac dusuk cumle/cati uyumsuzlugu (15 satir 187, 06 satir 117). (5) Kullanicinin temizlemeye calistigi 2. tekil sahis ifadeleri 14. dosyada hala birkac yerde kalmis. Kavramsal hata neredeyse yok; terim tutarliligi cok iyi (entity, gorunum, pencere, yerlesim gibi karsiliklarda butunluk var).

**Klasör içi bütünlük:** Klasor genel olarak iyi yapilandirilmis ve numarali dosyalar (01-16) mantikli bir ogrenme sirasi izliyor: temeller -> uygulama/platform -> baglamlar -> async/durum -> pencere -> render/element -> stil -> metin -> etkilesim -> action/keymap -> input/menu -> liste/cizim/animasyon -> zed ui -> test/dusuk seviye -> receteler -> erisilebilirlik. gpui_kullanimi.md dizin dosyasi tum bolumleri listeliyor; ancak icindekiler arasina harici klasor referanslari (calisma_alani, ayarlar, tema_yonetimi, bilesenler) 13. ve 14. bolum arasina sokusturulmus, bu da yerel 01-16 akisini gorsel olarak boluyor. 13-zed-ui-bilesenleri.md kasitli olarak kisa bir yonlendirme dosyasi (icerik bilesenler/ bolumune devrediliyor), bu tutarli bir tercih. Dosyalar arasi atiflar (or. '09-etkilesim-ve-olaylar.md' baglantisi, 'Entity Tip Soyutlamasi' baslik atiflari) genelde dogru ve isleyici. En belirgin konu butunlugu sorunu, ayni dusuk seviye API'lerin (ozellikle async update_in davranisi, Modifiers deref asimetrisi, SharedString performansi) birden cok dosyada ve dosya ici tablolarda tekrarlanmasi; bu kasitli bir referans tasarimi olabilir ama yer yer ayni cumlenin iki kez gecmesi gurultu yaratiyor. Genel akis kopuk degil, gecisler yeterli.

### Yüksek öncelik (2)

- **`src/gpui_kullanimi/04-async-gorev-ve-durum-yonetimi.md`:627** — [anlatim] Cumlenin ortasinda Devanagari (Hintce) script 'भी' karakteri var. Bu, Turkce metne karismis ait olmayan bir kelime; muhtemelen kopyala-yapistir veya otomatik ceviri artigi. Cumleyi anlasilmaz kiliyor.
  - Alıntı: `Inspector aracı açıkken भी hitbox'ların tam olarak taranabilmesi`
  - Öneri: 'भी' kelimesini kaldir; cumle 'Inspector araci acikken hitbox'larin tam olarak taranabilmesi adina onbellek devre disi kalir.' seklinde olmali.

- **`src/gpui_kullanimi/05-pencere-yonetimi.md`:304** — [anlatim] Ayni Devanagari 'भी' karakteri burada da var. Turkce cumleye karismis yabanci script; ceviri/kopyalama artigi.
  - Alıntı: ``WindowButtonLayout::{left, right}` dizileri भी bu sınır doğrultusunda yapılandırılır.`
  - Öneri: 'भी' kelimesini kaldir; cumle 'WindowButtonLayout::{left, right} dizileri de bu sinir dogrultusunda yapilandirilir.' seklinde olmali (gerekirse 'de' baglaci ile).

### Orta öncelik (8)

- **`src/gpui_kullanimi/02-uygulama-ve-platform.md`:138** — [anlatim] Duz anlatim metninde Ingilizce 'and' baglaci kalmis (kod blogu disi). Anglisizm; Turkce 've' olmali.
  - Alıntı: `doğrudan bu trait'lerle konuşmak yerine `App` and `Window` sarmalayıcı arayüzleri tercih edilir`
  - Öneri: '`App` ve `Window` sarmalayici arayuzleri' seklinde duzelt.

- **`src/gpui_kullanimi/04-async-gorev-ve-durum-yonetimi.md`:98** — [anlatim] Duz metinde Ingilizce 'and' baglaci. Iki kod tanimlayici arasinda 'and' kullanilmis; Turkce 've' olmali.
  - Alıntı: ``App::spawn_with_priority(...)` and `ForegroundExecutor::spawn_with_priority(...)` fonksiyonları`
  - Öneri: '... (...)` ve `ForegroundExecutor::spawn_with_priority(...)` fonksiyonlari' seklinde duzelt.

- **`src/gpui_kullanimi/10-action-ve-keymap.md`:186** — [anlatim] Duz metinde Ingilizce 'and' baglaci kalmis. Ayni hata kalibinin tekrari (10-action dosyasinda 3 yerde, 14 dosyasinda 2 yerde).
  - Alıntı: ``primary()` and `secondary()`, ayrıştırılan ana ve ek bağlam girişlerine erişir.`
  - Öneri: Tum 'and' baglaclarini 've' ile degistir. Bu dosyadaki diger ornekler: satir 192 ('cx.bind_keys(...)` and settings'), satir 271 ('.on_action(...)` and `.capture_action(...)`).

- **`src/gpui_kullanimi/14-test-inspector-ve-dusuk-seviye-api.md`:665** — [anlatim] Duz metinde Ingilizce 'and' baglaci. Bu dosyada satir 709'da da ('`ReadGlobal` and `UpdateGlobal`') ayni hata var.
  - Alıntı: `Arena tarafında `Arena` and `ArenaBox<T>` `arena` private modülünde`
  - Öneri: 'and' baglaclarini 've' ile degistir: '`Arena` ve `ArenaBox<T>`' ve satir 709'da '`ReadGlobal` ve `UpdateGlobal`'.

- **`src/gpui_kullanimi/06-render-ve-element-modeli.md`:31** — [anlatim] Yazim hatasi: 'görünümın' yanlis (unlu uyumu ve iyelik eki hatasi). Dogrusu 'gorunumun'.
  - Alıntı: `Bu işlevin tek sorumluluğu; görünümın alanlarında (fields) bulunan mevcut verilere bakarak`
  - Öneri: 'görünümün alanlarında (fields)' seklinde duzelt.

- **`src/gpui_kullanimi/14-test-inspector-ve-dusuk-seviye-api.md`:627** — [anlatim] Yazim hatasi: 'çağrabilirsin' yanlis (eksik hece). Dogrusu 'cagirabilirsin'. Ayrica 2. tekil sahis ifadesi (kullanicinin temizledigi kalip; bkz. recent commit '2. tekil sahis ifadeleri temizlendi').
  - Alıntı: `bu dört olay üzerinde doğrudan çağrabilirsin`
  - Öneri: 'cagrilabilir' veya kisisel olmayan bir ifadeyle 'bu dort olay uzerinde dogrudan cagrilabilir' seklinde duzelt.

- **`src/gpui_kullanimi/14-test-inspector-ve-dusuk-seviye-api.md`:318** — [anlatim] Yazim hatasi: 'düşünlenmemelidir' yanlis kelime (uydurulmus turetim). Dogrusu 'dusunulmemelidir'.
  - Alıntı: `uzun süre saklanacak kalıcı bir kimlik gibi düşünlenmemelidir`
  - Öneri: 'uzun sure saklanacak kalici bir kimlik gibi dusunulmemelidir' seklinde duzelt.

- **`src/gpui_kullanimi/15-receteler-ve-kontrol-listeleri.md`:187** — [anlatim] Ozne-yuklem/cati uyumsuzlugu. 'yardimcisini' belirtme hali alirken yuklem edilgen 'konumlandirilir'; ikisi uyumsuz. Dusuk cumle.
  - Alıntı: `HTTP yardımcısını UI katmanından bağımsız konumlandırılır; bu sayede testlerde sahte (mock) bir `HttpClient` iletilebilir`
  - Öneri: Ya 'HTTP yardimcisi UI katmanindan bagimsiz konumlandirilir' (edilgen) ya da 'HTTP yardimcisini UI katmanindan bagimsiz konumlandirmak gerekir' (etken) seklinde duzelt.

### Düşük öncelik (8)

- **`src/gpui_kullanimi/12-liste-cizim-ve-animasyon.md`:151** — [anlatim] Yazim hatasi: 'ulaşılaşıp' yanlis (fazla hece). Dogrusu 'ulasilip'.
  - Alıntı: `aksi halde son konuma ulaşılaşıp ulaşılmadığını bildirir`
  - Öneri: 'aksi halde son konuma ulasilip ulasilmadigini bildirir' seklinde duzelt.

- **`src/gpui_kullanimi/11-input-sistem-ve-menu.md`:157** — [anlatim] Noktalama/buyuk harf hatasi: cumle nokta ile bitmesine ragmen yeni cumle kucuk harfle ('arayuz') basliyor.
  - Alıntı: `...builder'ları aynı enum'un varyantlarını kurar. arayüz tarafında yeniden çizim yapılırken`
  - Öneri: '... varyantlarini kurar. Arayuz tarafinda yeniden cizim yapilirken ...' seklinde buyuk harfle basla.

- **`src/gpui_kullanimi/14-test-inspector-ve-dusuk-seviye-api.md`:657** — [anlatim] Noktalama/buyuk harf hatasi: ikinci cumle kucuk harfle ('tanı') basliyor. Ayrica 'tani ... platform tani yardimcilari' ifadesinde gereksiz 'tani' tekrari var.
  - Alıntı: `Bu tiplerin doğru sahibi `gpui_platform` uygulamalarıdır. tanı veya platform tanı yardımcıları üzerinden dolaylı erişim sağlanır.`
  - Öneri: '... uygulamalaridir. Tani veya platform yardimcilari uzerinden dolayli erisim saglanir.' seklinde duzelt.

- **`src/gpui_kullanimi/14-test-inspector-ve-dusuk-seviye-api.md`:644** — [anlatim] 2. tekil sahis ifadeleri ('yazmadigin', 'kullanirsin'). Kullanicinin son commit'lerinde temizledigi kalip; bu dosyada hala birkac yerde kalmis (satir 16, 277, 321, 447, 762'de 'verdigin/kullandigin/kurdugun' gibi).
  - Alıntı: `Platform uygulaması veya başsız renderer yazmadığın sürece aşağıdaki tipleri uygulama kodunda nadiren doğrudan kullanırsın`
  - Öneri: Kisisel olmayan ifadeye cevir: 'Platform uygulamasi veya bassiz renderer yazilmadigi surece asagidaki tipler uygulama kodunda nadiren dogrudan kullanilir.' Ayni kalip diger satirlarda da duzeltilmeli.

- **`src/gpui_kullanimi/03-baglamlar-ve-pencere-handlelari.md`:14** — [kavram] Olasi ic celiski: Bolum 04 (satir 109) ve 03 (satir 215) AsyncApp::update gibi cagrilarin App sonlanmissa 'panik' verdigini soyluyor; oysa async baglamlarin felsefesi 'await sonrasi canlilik varsayimini Result/Option ile iletmek' uzerine kurulu. App'in tamamen sonlanmasi (panik) ile pencere/entity'nin kapanmasi (Result) ayrimi metinde yer yer net ama 'panik' davranisinin gercek API ile dogrulanmasi onerilir.
  - Alıntı: `Eğer uygulama (`App`) tamamen sonlanmışsa bu çağrılar panikle sonuçlanır.`
  - Öneri: Gercek gpui kaynaginda AsyncApp::update'in App droplandiginda panik mi yoksa Err mi dondurdugu teyit edilmeli; metin tutarli sekilde guncellenmeli. Emin olunamiyorsa onem dusuk kalsin.

- **`src/gpui_kullanimi/04-async-gorev-ve-durum-yonetimi.md`:539** — [konu_butunlugu] Tekrar/cakisma: WeakEntity::update_in'in 'App::with_window ile son cizilen pencereyi bulma' davranisi hem satir 539 metninde hem satir 587 tablosunda neredeyse ayni cumlelerle iki kez anlatiliyor. Ayni dosya icinde yakin tekrar.
  - Alıntı: ``zayif.update_in(cx, |durum, window, cx| ...) -> Result<R>`: Entity'nin son çizildiği pencereyi `App::with_window` üzerinden bularak`
  - Öneri: Birini kisalt veya birinden digerine atif yap; ayni bilginin iki kez tam cumleyle verilmesi gereksiz.

- **`src/gpui_kullanimi/gpui_kullanimi.md`:20-24** — [konu_butunlugu] Icindekiler listesi klasor disi dosyalara (../calisma_alani, ../ayarlar, ../tema_yonetimi, ../bilesenler) baglanti veriyor; bunlar bu denetim kapsami disinda. Baglantilarin gercekten var oldugu (kirik link olmadigi) teyit edilmeli. Ayrica sira: 13-zed-ui-bilesenleri'nden sonra disaridaki bolumler araya giriyor, sonra 14-15-16 geliyor; numarali yerel dosyalarin akisi disardaki referanslarla bolunmus.
  - Alıntı: `- [Çalışma Alanı](../calisma_alani/calisma_alani.md) ... - [Picker Bileşeni](../bilesenler/17-picker-bileseni.md)`
  - Öneri: Harici baglantilarin hedef dosyalarinin varligi dogrulanmali. Numarali bolumlerin (14, 15, 16) harici referanslardan once mi sonra mi gelmesi gerektigi gozden gecirilebilir; okuyucu akisi acisindan yerel 01-16 sirasinin butun kalmasi tercih edilebilir.

- **`src/gpui_kullanimi/06-render-ve-element-modeli.md`:117** — [anlatim] Dusuk cumle/cati uyumsuzlugu: 'trait'lerini ... korunur' belirtme hali ile edilgen yuklem uyumsuz.
  - Alıntı: `örneğin olay (event) trait'lerini bu desenle korunur.`
  - Öneri: 'ornegin olay (event) trait'leri bu desenle korunur.' (belirtme ekini kaldir) veya 'olay trait'lerini bu desenle korur.' (etken) seklinde duzelt.

## src/bilesenler/

**Özet:** 20 dosyanin tamami satir satir okundu. Teknik icerik genel olarak isabetli: ButtonSize yukseklikleri (32/28/22/18/16px), IconSize degerleri (10/12/14/16/48px), IconButton varsayilan sekli (Wide) gibi sayisal/kavramsal iddialar Zed kaynagiyla dogrulandi ve tutuyor. Onemli sorunlar dilbilgisi ve anlatim eksenindedir, kavram/anlam hatasi nadir ve dusuk onemde. En kritik bulgular: (1) 06-form dosyasi satir 223'te \"modelnya\" yazim hatasi (baslik anlamsiz). (2) Birden cok dosyada anlatim metninde Ingilizce baglac \"and\" birakilmis (01:265, 01:277, 02:90, 03:185, 04:80, 04:380, 09:399) - hepsi \"ve\" olmali. (3) Yaygin bir kalip hata: \"X'i/degerini ... edilmesi/saklanmasi/okunmasi gerekir\" bicimindeki ozne-tumlec uyumsuzlugu (01:22, 01:241, 06:394, 07:304, 09:94, 10:3, 15:3) - belirtme eki ile edilgen ad-fiil celisiyor. (4) Tekil yazim hatalari: 01:251 \"juga\", 16:548 \"yiginana\". (5) 07-menu dosyasinda 2. tekil sahis kalintilari (07:91 \"edersin\", 07:82 \"kullaniyorsan\", 07:213 \"kullanman\") projenin 2. tekil sahis temizligi kuraliyla celisiyor. Anlam/kavram hatalari sinirli: 12:161 ikon turetimi cumlesi bulanik, 11:26 project_panel ornegi Table baglaminda kafa karistirici. Sorunsuz dosyalar: bilesenler.md, 08, 13, ek-a, ek-b'de kayda deger bulgu yok.

**Klasör içi bütünlük:** Klasor genel olarak guclu bir konu butunlugune sahip. Dizin dosyasi (bilesenler.md) okuma sirasini ve katman ayrimini (GPUI primitive'leri vs Zed ui bilesenleri) net kuruyor; numarali dosyalar bu vaadi izliyor: once ortak temeller (01), ham primitive'ler (02), layout (03), metin/ikon (04), buton (05), form (06), menu/popup (07), scrollbar (08), liste/tree (09), tab (10), tablo (11), feedback (12), avatar (13), genel yardimcilar (14), AI/collab (15), entegre ornekler (16), picker (17), ardindan iki ek. Akis mantikli ve her bileseni \"Kaynak / Ne zaman kullanilir / Ne zaman kullanilmaz / Temel API / Davranis / Ornek / Zed ornekleri / Dikkat\" sablonuyla tutarli sunuyor. Cakisma dusuk; tekrar eden kavramlar (DynamicSpacing, ToggleState scrollbar surukleme sozlesmesi, ButtonLike alt katmani) bilincli capraz referanslarla veriliyor. Iki kucuk yapisal not: (1) 01-08 araliginda sablon basliklari Turkce \"Ne zaman kullanilir / Ne zaman kullanilmaz\" iken 10-15 arasinda \"Tavsiye Edilen Kullanim Alanlari / Tercih Edilmemesi Gereken Durumlar\" ve \"Dikkat edilmesi gereken noktalar\" vs \"Dikkat Edilmesi Gereken Hususlar\" gibi baslik varyasyonlari var; ayni anlami tasiyan basliklarin klasor genelinde tek bicime cekilmesi tutarliligi artirir. (2) Divider ve grup yardimcilari hem 03 hem 14'te isleniyor; 14'teki tekrar capraz referansla daha kisa tutulabilir, ama mevcut haliyle 14 \"genel yardimci\" toplama mantigina uydugu icin kabul edilebilir.

### Yüksek öncelik (1)

- **`src/bilesenler/06-form-ve-secim-bilesenleri.md`:223** — [anlatim] "modelnya" yazim/dizgi hatasi; Turkce bir sozcuk degil, baslik anlamsiz kaliyor.
  - Alıntı: `Ortak `ToggleState` modelnya:`
  - Öneri: "Ortak `ToggleState` modeli:" seklinde duzeltilmeli.

### Orta öncelik (17)

- **`src/bilesenler/01-ortak-kullanim-temelleri.md`:251** — [anlatim] "juga" bir yazim/dizgi hatasi; Turkce bir sozcuk degil (muhtemelen baska bir dilden sizmis). Cumlenin anlami bozuluyor.
  - Alıntı: `yani editor yazisi ne buyuklukte ise metin juga o buyuklukte basilir.`
  - Öneri: "...metin de o buyuklukte basilir." seklinde duzeltilmeli.

- **`src/bilesenler/01-ortak-kullanim-temelleri.md`:265** — [anlatim] Duz anlatim metninde Ingilizce baglac "and" birakilmis; iki API adini baglayan baglac Turkce olmali.
  - Alıntı: `dogrudan metin yazildiginda `font_ui` and `text_ui_*` cagrilarinin atlanmamasi gerekir.`
  - Öneri: "`font_ui` ve `text_ui_*` cagrilarinin..." seklinde "and" -> "ve".

- **`src/bilesenler/01-ortak-kullanim-temelleri.md`:277** — [anlatim] Anlatim metninde Ingilizce baglac "and" kalmis.
  - Alıntı: ``Animation`, `AnimationExt`, `with_animation(...)` and `with_animations(...)` yapilari dogrudan kullanilabilir.`
  - Öneri: "... `with_animation(...)` ve `with_animations(...)` yapilari ..." seklinde "and" -> "ve".

- **`src/bilesenler/01-ortak-kullanim-temelleri.md`:22** — [anlatim] Ozne-tumlec uyumsuzlugu: "import'unu ... tercih edilmesi" hatali. Edilgen yuklemle belirtme hali (-u) celisiyor.
  - Alıntı: `Zed UI bilesenleri kullanilacaksa `ui::prelude::*` import'unu tercih edilmesi gerekir.`
  - Öneri: "...`ui::prelude::*` import'unun tercih edilmesi gerekir." veya "...import'unu tercih etmek gerekir."

- **`src/bilesenler/01-ortak-kullanim-temelleri.md`:241** — [anlatim] Ozne-tumlec uyumsuzlugu: "donus degerini ... saklanmasi" hatali; belirtme eki ile edilgen yuklem celisiyor.
  - Alıntı: ``PlatformStyle::platform()` donus degerini tek bir noktada saklanmasi onerilir.`
  - Öneri: "...donus degerinin tek bir noktada saklanmasi onerilir."

- **`src/bilesenler/02-ham-gpui-primitiveleri-ve-metod-kapsami.md`:90** — [anlatim] Anlatim metninde Ingilizce baglac "and" kalmis.
  - Alıntı: ``flex_grow(grow: f32)` and `flex_shrink(shrink: f32)` dogrudan ozel buyume/kuculme katsayilarini tanimlar.`
  - Öneri: "... `flex_grow(grow: f32)` ve `flex_shrink(shrink: f32)` ..." seklinde "and" -> "ve".

- **`src/bilesenler/03-layout-temelleri.md`:185** — [anlatim] Anlatim metninde Ingilizce baglac "and" kalmis.
  - Alıntı: ``Divider::render_dashed(base)` icinde `canvas(...)` and `PathBuilder::stroke(px(1.)).dash_array(...)` kullanilarak cizilir`
  - Öneri: "... `canvas(...)` ve `PathBuilder::stroke(...)...` kullanilarak ..." seklinde "and" -> "ve".

- **`src/bilesenler/04-metin-ve-ikon-bilesenleri.md`:80** — [anlatim] Anlatim metninde Ingilizce baglac "and" kalmis.
  - Alıntı: `uyari ve durum satirlarinda `Icon` and `Label` kompozisyonu kullanilir.`
  - Öneri: "...`Icon` ve `Label` kompozisyonu..." seklinde "and" -> "ve".

- **`src/bilesenler/04-metin-ve-ikon-bilesenleri.md`:380** — [anlatim] Anlatim metninde Ingilizce baglac "and" kalmis.
  - Alıntı: `Renk degerine mudahale edilmesi gerekiyorsa duz `Label` and yanina bagimsiz bir spinner kompozisyonu yerlestirilmesi daha guvenlidir.`
  - Öneri: "...duz `Label` ve yanina bagimsiz bir spinner..." seklinde "and" -> "ve".

- **`src/bilesenler/06-form-ve-secim-bilesenleri.md`:394** — [anlatim] Ozne-tumlec uyumsuzlugu: "degerini ... okunmasi" hatali; belirtme eki ile edilgen yuklem celisiyor.
  - Alıntı: `Metin degerini `field.read(cx).text(cx)` yardimiyla okunmasi gerekir.`
  - Öneri: "Metin degeri `field.read(cx).text(cx)` yardimiyla okunur." veya "...degerini ... okumak gerekir."

- **`src/bilesenler/15-ai-ve-collab-ozel-alani.md`:3** — [anlatim] Ozne-tumlec uyumsuzlugu: "...uyup uymadigini kontrol edilmesi gerekir" hatali; belirtme eki ile edilgen yuklem celisiyor.
  - Alıntı: `alan modelinin bu API'lere gercekten uyup uymadigini kontrol edilmesi gerekir.`
  - Öneri: "...uyup uymadiginin kontrol edilmesi gerekir." veya "...uyup uymadigini kontrol etmek gerekir."

- **`src/bilesenler/10-tab-bilesenleri.md`:3** — [anlatim] Ozne-tumlec uyumsuzlugu: "kararlari ... hesaplanmasi gerekir" hatali; belirtme eki (-i) ile edilgen yuklem celisiyor.
  - Alıntı: `gibi kararlari dogrudan ilgili gorunum (view) durumunda hesaplanmasi gerekir.`
  - Öneri: "...gibi kararlarin dogrudan ilgili gorunum durumunda hesaplanmasi gerekir."

- **`src/bilesenler/07-menu-popup-ve-tooltip.md`:82** — [anlatim] Ozne-tumlec uyumsuzlugu: "secili degeri ... yansitilmasi gerekir" hatali; ayrica 2. tekil sahis ("kullaniyorsan") belgenin geri kalanindaki edilgen/nesnel uslupla celisiyor (proje kurali 2. tekil sahis temizligi).
  - Alıntı: `Dinamik bir label kullaniyorsan mevcut secili degeri her render'da label'a yansitilmasi gerekir.`
  - Öneri: "Dinamik bir label kullaniliyorsa mevcut secili degerin her render'da label'a yansitilmasi gerekir."

- **`src/bilesenler/07-menu-popup-ve-tooltip.md`:213** — [anlatim] Iki sorun: (1) 2. tekil sahis "kullanman" diger metinle celisiyor; (2) "capture'larini sade tutulmasi" ozne-tumlec uyumsuzlugu (belirtme eki ile edilgen ad fiil celisiyor).
  - Alıntı: `Ust menudeki durumu kopyalayarak kullanman gerektiginde, closure capture'larini sade tutulması okunabilirligi artirir.`
  - Öneri: "Ust menudeki durumu kopyalayarak kullanmak gerektiginde, closure capture'larinin sade tutulmasi okunabilirligi artirir."

- **`src/bilesenler/07-menu-popup-ve-tooltip.md`:304** — [anlatim] Ozne-tumlec uyumsuzlugu: "handle'i ... saklanmasi gerekir" hatali; belirtme eki ile edilgen yuklem celisiyor.
  - Alıntı: ``with_handle(...)` kullanildiginda handle'i view durumunda saklanmasi gerekir.`
  - Öneri: "...handle'in view durumunda saklanmasi gerekir."

- **`src/bilesenler/09-liste-ve-tree-bilesenleri.md`:94** — [anlatim] Ozne-tumlec uyumsuzlugu: "onu ... iletilmesi gerekir" hatali; "onu" belirtme eki ile edilgen yuklem celisiyor.
  - Alıntı: `Bos durum ozel bir element ise onu `.into_any_element()` cagrisiyla iletilmesi gerekir.`
  - Öneri: "...bos durum ozel bir element ise onun `.into_any_element()` cagrisiyla iletilmesi gerekir."

- **`src/bilesenler/09-liste-ve-tree-bilesenleri.md`:399** — [anlatim] Anlatim metninde Ingilizce baglac "and" kalmis.
  - Alıntı: ``uniform_list(...)`, `ListItem` and `IndentGuides` uclusu cok daha esnek bir altyapi verir.`
  - Öneri: "...`ListItem` ve `IndentGuides` uclusu..." seklinde "and" -> "ve".

### Düşük öncelik (10)

- **`src/bilesenler/04-metin-ve-ikon-bilesenleri.md`:361** — [anlatim] "gorunur hale verir" bozuk bir esdizimlilik; dogrusu "gorunur hale getirir".
  - Alıntı: `Ilk animasyon adiminda metni soldan saga kademeli olarak gorunur hale verir;`
  - Öneri: "...metni soldan saga kademeli olarak gorunur hale getirir;"

- **`src/bilesenler/02-ham-gpui-primitiveleri-ve-metod-kapsami.md`:115** — [anlatim] "islerken;" ifadesinden sonra noktali virgul kullanimi gereksiz/yanlis; "-ken" zarf-fiil cumleyi zaten baglar.
  - Alıntı: `Normal varyantlar elemente gelen olaylari islerken; capture varyantlari olay dagitiminin (dispatch) erken asamalarinda devreye girer.`
  - Öneri: Noktali virgul kaldirilip "...islerken, capture varyantlari..." virgulle baglanmali.

- **`src/bilesenler/07-menu-popup-ve-tooltip.md`:91** — [anlatim] 2. tekil sahis ("edersin") kullanimi; diger tum bilesenlerin "Prelude" satirlarinda "ayrica import edilmesi gerekir / import edilir" edilgen kalibi kullanilmis. Tutarsizlik.
  - Alıntı: `Prelude: Hayir; ayrica import edersin.`
  - Öneri: "Prelude: Hayir; ayrica import edilir." ile bolumun geri kalaniyla ayni kalip kullanilmali.

- **`src/bilesenler/09-liste-ve-tree-bilesenleri.md`:462** — [anlatim] "devre disi olundugunda" ifadesi ozneyle (tiklama isleyicisi) uyumsuz ve bozuk; "olunmak" edilgeni burada anlam vermiyor.
  - Alıntı: `Tiklama isleyicisi devre disi olundugunda baglanmaz;`
  - Öneri: "Tiklama isleyicisi, satir devre disi oldugunda baglanmaz;" veya "...devre disi durumda baglanmaz;"

- **`src/bilesenler/05-buton-ailesi.md`:361** — [kavram] ButtonLink davranis bolumunde "arka planda bir ButtonLike kurulur" deniyor; ayni dosyada Button (l.127) ve IconButton (l.219) icin "render sonunda bir ButtonLike uretir" kalibi kullanilmis. Ifade tutarsizligi (anlam ayni ama soylem farkli); kavramsal hata degil ama bolum ici terim tutarliligi acisindan dikkat.
  - Alıntı: `Render asamasinda arka planda bir `ButtonLike::new(...)` kurulur.`
  - Öneri: Diger butonlarla ayni kalip kullanilarak "render sonunda arka planda bir `ButtonLike` uretilir" bicimine yaklastirilabilir.

- **`src/bilesenler/16-entegre-ornek-sayfalari.md`:548** — [anlatim] "yiginana" yazim hatasi; dogru ek "yiginina" olmali (yigin + ina).
  - Alıntı: `Calisma alani bildirim yiginana (workspace notification stack) girecek bir view`
  - Öneri: "Calisma alani bildirim yiginina ..."

- **`src/bilesenler/12-feedback-ve-durum-gostergeleri.md`:161** — [anlam] Cumle bulanik: "ikon adi severity'den turetilir" ile "verilen IconName alanin gosterilecegini belirtir" arasinda hafif celiski/karisiklik var; verilen IconName mi yoksa severity ikonu mu cizilir net degil.
  - Alıntı: `Cagrildiginda mevcut render akisinda gorunen ikon adi ve rengi severity'den turetilir; verilen `IconName` alanin gosterilecegini belirtir.`
  - Öneri: Davranis netlestirilmeli: ornegin "`.icon(IconName)` cagrildiginda ikon alani gorunur olur; ikonun adi ve rengi severity'den turetilir" gibi tek bir niyetle ifade edilmeli.

- **`src/bilesenler/01-ortak-kullanim-temelleri.md`:139** — [anlatim] "bir kismi secili olmasi" tirnak ici ibare dusuk; "bir kismi secili olmasi" yerine "bir kismi secili" daha dogru bir ad tamlamasi olur.
  - Alıntı: `Bu ikinci fonksiyon, "alt ogelerin bir kismi secili olmasi" gibi karmasik senaryolari otomatik olarak dogru duruma donusturur.`
  - Öneri: "...\"alt ogelerin yalnizca bir kisminin secili oldugu\" gibi karmasik senaryolari..."

- **`src/bilesenler/14-genel-yardimci-bilesenler.md`:453** — [anlam] trailing_separator bayraginin macOS'ta "etkisiz kaldigi" iddiasi guclu; davranis aslinda macOS'ta ayirici karakteri olmadigi icin gorsel etki uretmemesi. Kaynak dogrulamasi yapilmadiginda emin olunmamali; ifade biraz mutlak.
  - Alıntı: `bu ayirici yalnizca Linux ve Windows stilinde `+` oldugundan, macOS stilinde ayirici bulunmaz ve bayrak burada etkisiz kalir.`
  - Öneri: Daha temkinli: "macOS stilinde modifier'lar ikon oldugu icin ayrica bir ayirici karakteri eklenmez; bu nedenle bayragin gorsel etkisi macOS'ta gozlenmez."

- **`src/bilesenler/11-veri-ve-tablo-bilesenleri.md`:26** — [konu_butunlugu] `project_panel` bir tablo degil; cumle Table baglaminda `Infer` ornegi olarak project_panel'i verince, Table ile uniform_list (tablodisi) ornegi karisabiliyor. Okuyucu icin baglam gecisi belirsiz.
  - Alıntı: `UI tarafindaki `Table`, sanallastirilmis satirlarda `Auto` kullanir; `project_panel` gibi agac listelerinde `Infer` ornegi gorulur.`
  - Öneri: Cumle "Table sanallastirilmis satirlarda `Auto` kullanir; agac listeleri (orn. project_panel'in `uniform_list` kullanimi) ise `Infer` ornegidir." gibi netlestirilmeli.

## src/calisma_alani/

**Özet:** Bolum genel olarak yuksek kaliteli, teknik olarak isabetli ve tutarli yapidadir; kontrol edilen API iddialari (DecreaseActiveDockSize.px, OpenVisible::OnlyFiles/OnlyDirectories semantigi, multi_workspace_enabled kosulu, legacy_id/user.id, invert_axies) gercek Zed kaynagiyla dogrulandi ve dogru cikti. Yuksek onemli hata bulunmadi. En kritik 3-5 sorun: (1) 03 dosyasi satir 72'de klasor acma davranisinin kosulsuz anlatilmasi, ayni dosyanin 65. satirindaki 'yalniz multi_workspace_enabled true iken' kosuluyla ic celiski olusturuyor (orta). (2) 02 dosyasi satir 262'de 'türünü ... tanımlanması' ozne-tumlec uyumsuzlugu (orta). (3) Terim tutarsizliklari kitap geneli icin onemli: 'buffer' icin 'tampon/arabellek/tampon bellek', 'method' icin 'metot/yontem', 'item' icin 'oge/item', 'fuzzy/namespace/debounce/sidebar' icin Turkce-Ingilizce karisik kullanim. (4) Bazi tiplerin (OpenVisible, SuppressEvent, NotificationId) birden cok dosyada capraz referanssiz tekrari (dusuk). (5) Dizin dosyasi ile alt dosya H1 baslik adlarinin birkac yerde tam ortusmemesi (dusuk). Birkac belirsiz gonderme ('bu durum', satir 17/19 vs.) ve 'sentetik', 'spesifik' gibi gereksiz anglisizmler mevcut. Kod bloklarindaki tanimlayicilar (invert_axies dahil) kasitli kaynak yansimasi oldugu icin dokunulmamalidir.

**Klasör içi bütünlük:** Klasor genel olarak iyi yapilandirilmis: dizin dosyasi (calisma_alani.md) tum alt dosyalari numara sirasina gore tanitiyor ve her dosya tutarli bir kalibi izliyor (H1 baslik -> kavram aciklamasi -> kod blogu -> 'API Kapsami' tablolari -> 'Dikkat Edilmesi Gereken Hususlar'). Akis mantikli: dock/panel modeli -> item/pane/modal -> serilestirme/acma -> pane-group/navigasyon -> bildirim -> appstate/open-listener -> baglam menusu/focus -> komut paleti. Baslica kopukluk noktalari: (1) Dizin dosyasindaki modul/baslik adlari ile gercek dosya H1 basliklari birkac yerde tam ortusmuyor (or. 03 dosyasi). (2) `OpenVisible`, `SuppressEvent`, `NotificationId`, `TabContentParams`, `ItemBufferKind` gibi tipler birden fazla dosyada (02, 03, 05, 07) tabloda tekrar ediliyor; capraz referans olmadan ayni aciklama yeniden veriliyor; bu bilinçli bir 'her bolum kendi kendine yeter' tercihi olabilir ama bazi yerlerde gereksiz cakisma yaratiyor. (3) 03 dosyasindaki klasor acma davranisi (satir 72) ile 65. satirdaki kosul arasinda ufak ic celiski var. Genel sira ve gecisler saglam, vaat edilen konular karsiliklarini buluyor.

### Orta öncelik (2)

- **`src/calisma_alani/02-item-pane-modal-toast.md`:262** — [anlatim] Ozne-tumlec uyumsuzlugu/dusuk cumle. 'türünü ... tanımlanması' yapisi bozuk; 'türünü tanımlama' veya 'türünün tanımlanması' olmaliydi.
  - Alıntı: ``Self::Event` türünü doğru tanımlanması ve `EventEmitter<Self::Event>` uygulanması şarttır`
  - Öneri: '`Self::Event` türünün doğru tanımlanması ve `EventEmitter<Self::Event>`'in uygulanması şarttır' biciminde duzeltin.

- **`src/calisma_alani/03-serializasyon-ve-acma-akisi.md`:72** — [kavram] Onceki cumle (satir 68-71) ve OpenMode/add_dirs_to_sidebar aciklamalari, ekleme davranisinin yalniz 'multi_workspace_enabled(cx) true oldugunda' yapildigini soyluyor (satir 65). Burada kosulsuz 'mevcut pencerenin Threads sidebar'ina ekler' denmesi, multi-workspace devre disi durumunu atlayarak ic celiski/eksik kosul olusturuyor.
  - Alıntı: `Varsayılan davranışta `-n`, `-a` veya `-r` verilmeden klasör açmak mevcut pencerenin Threads sidebar'ına yeni bir project olarak ekler.`
  - Öneri: Cumleyi 'multi-workspace etkin pencerelerde mevcut pencerenin Threads sidebar'ina ... ekler; aksi halde davranis farklidir' gibi kosula baglayarak satir 65 ile uyumlandirin.

### Düşük öncelik (15)

- **`src/calisma_alani/02-item-pane-modal-toast.md`:40-57** — [anlatim] Ayni paragraf icinde 'yontem', 'metot' ve 'yöntem' karisik kullaniliyor (bkz. satir 55 'bu yöntemi geçersiz kılar' vs. baska dosyalarda 'metot'). Kitap genelinde 'metot' tercih edilmis; burada 'yontem' kullanimi terim tutarsizligi yaratiyor.
  - Alıntı: ``active_project_path`.** `Item` trait'inde varsayılan bir yöntem olarak tanımlıdır; `ItemHandle::project_path` ise buna yönlendirilmiştir`
  - Öneri: Tum bolumlerde tek bir karsilik secilmeli: 'metot' (ya da 'yontem'). Bu dosyada satir 40 ve 55'teki 'yöntem' kelimelerini diger dosyalarla uyumlu sekilde 'metot' yapmak tutarliligi artirir.

- **`src/calisma_alani/03-serializasyon-ve-acma-akisi.md`:68** — [anlam] Cumle iki ardisik tip adiyla ('Activate' ve 'NewWindow') yan yana baslayinca okuma guclugu yaratiyor ve 'NewWindow gibi' ifadesinin neyle kiyaslandigi (yeni pencere acmadan mi, sadece one getirme acisindan mi) belirsiz kaliyor.
  - Alıntı: ``OpenMode::Activate` `NewWindow` gibi hedef pencereyi öne getirir.`
  - Öneri: '`OpenMode::Activate`, yeni pencere acmadan, var olan hedef pencereyi `NewWindow` gibi one getirir.' seklinde netlestirin.

- **`src/calisma_alani/03-serializasyon-ve-acma-akisi.md`:62** — [anlatim] Eliptik cumle: 'OnlyFiles dizinleri ... disarida birakir' yapisinda yuklem ('disarida birakir') iki ogeye birden bagli ama arada eksiltme var. Kaynakla anlam dogru (OnlyFiles dizinleri gorunur yapmaz) ancak ifade biraz zorlama; daha acik kurulabilir.
  - Alıntı: ``All` hem dosya hem dizinleri proje panelinde (project panel) görünür yapar; `None` hiçbirini görünür yapmaz; `OnlyFiles` dizinleri, `OnlyDirectories` ise dosyaları dışarıda bırakır.`
  - Öneri: '`OnlyFiles` yalnizca dosyalari gorunur yapar (dizinleri disarida birakir), `OnlyDirectories` ise yalnizca dizinleri gorunur yapar (dosyalari disarida birakir).' seklinde acin.

- **`src/calisma_alani/01-dock-ve-panel-modeli.md`:23** — [anlatim] 'Genel istemci' ifadesi 'client'in 'global' olmasini mi yoksa 'genel amacli' oldugunu mu kastettigi belirsiz. AppState aciklamasinda (06 numarali dosya satir 11-18) client zaten Arc<Client>; burada 'genel' sifati anlami bulaniklastiriyor.
  - Alıntı: ``app_state`: Genel istemci (`client`), kullanıcı ve dil (`LanguageRegistry`) kayıtlarını barındıran durum.`
  - Öneri: '`app_state`: istemci (`client`), kullanici (`user_store`) ve dil (`LanguageRegistry`) servislerini barindiran uygulama durumu.' biciminde sadelestirin.

- **`src/calisma_alani/04-pane-group-ve-navigasyon.md`:19** — [anlatim] Belirsiz gonderme: 'bu durum' ifadesinin neye isaret ettigi net degil. Kastedilen 'yonleri sabit sirada vermesi'; 'bu durum' (=bir hal) yerine eylemi gosteren bir baglaç daha uygun.
  - Alıntı: ``SplitDirection::all()` metodu dört yönü `[Up, Down, Left, Right]` sırasıyla verir; bu durum yön taraması veya key binding (tuş ataması) üretiminde kolaylık sağlar.`
  - Öneri: '...sirasiyla verir; boylece yon taramasi veya tus atamasi uretimi kolaylasir.' seklinde duzeltin.

- **`src/calisma_alani/04-pane-group-ve-navigasyon.md`:163** — [anlatim] Anglisizm/tutarsizlik: ayni parantez icinde once Turkce 'yapay tus vuruslari' denip hemen ardindan parantezde 'sentetik keystroke' biraktirilmis. 'sentetik' gereksiz anglisizm ve 'keystroke' Turkcelestirilmis terimin yaninda fazlalik.
  - Alıntı: `düzenleme tahmini (edit prediction) ve yapay tuş vuruşları (sentetik keystroke) davranışlarını tetikler.`
  - Öneri: 'yapay tus vuruslari (synthetic keystrokes)' veya yalnizca 'yapay tus vuruslari' birakin; metin icinde 'sentetik' kelimesini kullanmayin.

- **`src/calisma_alani/02-item-pane-modal-toast.md`:266** — [anlam] 'süresi varsayilan degildir' ifadesi anlami kayiyor: kastedilen 'otomatik gizleme varsayilan olarak acik degildir / autohide varsayilan davranis degildir'. 'sure' kelimesi cumleye yanlis odak veriyor. Ayrica satir 186'da ayni konu 'otomatik kapanma yoktur' diye dogru ifade edilmis; iki anlatim ayrismis.
  - Alıntı: ``Toast` otomatik gizleme (autohide) süresi varsayılan değildir; uzun mesajlarda elle `dismiss_toast` çağrılması gerekebilir.`
  - Öneri: '`Toast` icin otomatik gizleme (autohide) varsayilan davranis degildir; ...' seklinde duzeltip satir 186 ile uyumlandirin.

- **`src/calisma_alani/05-bildirim-yardimcilari.md`:49** — [anlatim] 'beklenebilir yapidayken' bulanik; muhtemelen 'await edilebilir / beklenebilir bir gorev dondururken' kastediliyor. Mevcut hali ne dondurdugunu netlestirmiyor.
  - Alıntı: ``prompt_err` beklenebilir yapıdayken, `detach_and_prompt_err` işlemi arka planda yürütür.`
  - Öneri: '`prompt_err` beklenebilir (await edilebilir) bir gorev dondururken, `detach_and_prompt_err` islemi arka planda detach ederek yurutur.' seklinde acin.

- **`src/calisma_alani/06-appstate-ve-open-listener.md`:103** — [anlatim] Anglisizm: 'spesifik' yerine Turkce karsiligi 'ozgul' veya 'belirgin/daha dar kapsamli' kullanilabilir. Teknik tanimlayici degil, duz anlatim.
  - Alıntı: `çakışma durumunda ise proje kuralları daha sonra geldiği için daha spesifik kabul edilerek önceliklendirilir.`
  - Öneri: '...daha sonra geldigi icin daha ozgul kabul edilerek onceliklendirilir.' biciminde degistirin.

- **`src/calisma_alani/02-item-pane-modal-toast.md`:59** — [anlam] Mantik dongusu/kendini tekrar: 'olay geldiginde ... bu olayi yayarsa' ifadesi sebep ile kosulu birbirine kariyor. Olayin gelmesi zaten ogenin yaymasiyla olur; cumle dairesel.
  - Alıntı: ``ItemEvent::UpdateBreadcrumbs` olayı geldiğinde, aktif panedeki aktif öğe bu olayı yayarsa çalışma alanı `active_item_path_changed(false, window, cx)` çağrısını tetikler.`
  - Öneri: 'Aktif panedeki aktif oge `ItemEvent::UpdateBreadcrumbs` olayini yayinca calisma alani `active_item_path_changed(false, window, cx)` cagrisini tetikler.' seklinde tek kosula indirin.

- **`src/calisma_alani/08-komut-paleti.md`:39** — [anlatim] Dusuk/bulanik cumle. 'Yeni bir eylem uygulandiginda alias ... olarak dusunulmelidir' baglacı kopuk; eylem uygulamayla alias'in palet kisayolu olmasi arasindaki neden-sonuc net degil.
  - Alıntı: `Yeni bir eylem uygulandığında alias, kullanıcının kısa sorgular yazarak komutlara hızlı erişmesini sağlayan bir palet kısayolu olarak düşünülmelidir.`
  - Öneri: Cumleyi ikiye bolun: 'Alias, kullanicinin kisa sorgular yazarak komutlara hizli erismesini saglayan bir palet kisayolu olarak dusunulmelidir. Yeni bir eylem eklenirken alias tanimi da bu amacla degerlendirilmelidir.'

- **`src/calisma_alani/calisma_alani.md`:9-18** — [konu_butunlugu] Dizin tablosundaki modul listesi ile satir 5'te sayilan 'disa acik dosya ve modul yuzeyi' listesi tam ortusmuyor: tabloda `command_palette`, `command_palette_hooks`, `modal_layer`, `history_manager` var ama satir 5 yuzey listesinde bunlardan bazilari ayri sayilmiyor (or. modal_layer satir 5'te 'security_modal' var ama 'modal_layer' yok). Okuyucu icin hangi listenin esas oldugu belirsiz.
  - Alıntı: `| `command_palette` | Komut paleti modalı, fuzzy arama, geçmiş ve onay akışı. | ... | `modal_layer` | `ModalView` ve modal dismiss kararları. |`
  - Öneri: Satir 5 metin listesi ile satir 7-18 tablosunu ayni modul kumesine gore hizalayin veya tablonun 'sik kullanilan alt kume' oldugunu acikca belirtin.

- **`src/calisma_alani/calisma_alani.md`:34** — [konu_butunlugu] Dizindeki baslik '03-serializasyon-ve-acma-akisi.md' dosyasinin gercek H1 basligi 'Serileştirme, OpenOptions, ProjectItem ve SearchableItem' (dosya satir 1). Dizinde 'open_*' yaziyor, dosyada 'ProjectItem ve SearchableItem'; baslik-icerik adlandirmasi tam ortusmuyor. Ufak tutarsizlik.
  - Alıntı: `**Serileştirme, OpenOptions ve open\_*** — `SerializableItem`, `OpenOptions`, `ProjectItem`, `SearchableItem`, `FollowableItem`.`
  - Öneri: Dizin maddesini dosya H1 basligiyla ayni yapin (or. 'Serilestirme, OpenOptions, ProjectItem ve SearchableItem').

- **`src/calisma_alani/04-pane-group-ve-navigasyon.md`:17** — [kavram] Kaynakta metot adi gercekten `invert_axies` (yazim hatali ama kod tanimlayicisi, dokunulmamali). Ancak duz anlatimda 'eksenleri tersine cevirerek pane konumlarini yeniden isaretler' ifadesi muglak; metot yatay/dikey eksenleri degis tokus eder, 'isaretler' fiili davranisi tam karsilamiyor.
  - Alıntı: ``invert_axies(cx)` ise split ağacındaki eksenleri tersine çevirerek pane konumlarını yeniden işaretler.`
  - Öneri: '...split agacindaki eksenleri (yatay<->dikey) tersine cevirir ve pane yerlesimini buna gore yeniden hesaplar.' seklinde netlestirin. Metot adi kod oldugu icin oldugu gibi birakilmali.

- **`src/calisma_alani/02-item-pane-modal-toast.md`:204** — [konu_butunlugu] Ayni `OpenVisible` tipi hem bu dosyada (satir 204) hem 03 dosyasinda (satir 62, 86) tablo/aciklama olarak tekrarlaniyor. Iki bolum arasinda gereksiz cakisma var; biri ozet digeri ayrintili olabilir ama capraz referans yok.
  - Alıntı: `Açılan yolun (path) proje panelindeki görünürlüğünü `All`, `None`, `OnlyFiles`, `OnlyDirectories` olarak sınırlar.`
  - Öneri: 03 dosyasindaki ayrintili `OpenVisible` aciklamasina capraz referans verip 02'deki tekrari kisaltin ya da birbirine baglayin.

## src/ayarlar/

**Özet:** src/ayarlar/ bolumu teknik olarak guvenilir ve iyi organize edilmis. Kaynak kodla capraz dogruladigim onemli iddialar (lsp_document_links varsayilani true, editor.links -> lsp_document_links eslemesi, scan_symlinks varsayilani expanded, ProfileBase merge mantigi, SettingsFile oncelik sirasi, set_local_settings'in Tasks/Debug icin Err donmesi, SettingsParseResult::result() -> Result<bool>) hepsi dogru cikti; ciddi kavram/anlam hatasi yok. En kritik bulgular: (1) 02-settings-store.md satir 325'te 'Buna rağmen' baglaci yanlis karsitlik kuruyor, anlami bulandiriyor (orta onem). (2) Bolum genelinde 'override -> üzerine yazma' terimi tutarsiz kullaniliyor (override / üzerine yazma / parantezli). (3) 'yerel ayarlar' vs 'local ayarlar' vs 'proje ve local ayarlar' terim tutarsizligi (01 satir 127), proje ve local'in ayri katman sanilmasina yol acabilir. (4) KeybindSource degerlerinin 04 dosyasinda uc farkli sirayla listelenmesi. (5) Birkac dusuk cumle (02 satir 324, 144) ozne-yuklem iliskisinde zayif. Bulgularin cogu dusuk onemli anlatim/tutarlilik iyilestirmeleridir; bolum yayima yakin kalitede.

**Klasör içi bütünlük:** Klasor genel olarak iyi yapilandirilmis ve numara onekli sira (ayarlar.md dizin -> 01 akis/kayit -> 02 store -> 03 dosya izleme -> 04 keymap -> 05 editorconfig/vscode) mantikli bir ogrenme akisi sunuyor. Dizin dosyasi (ayarlar.md) alt dosyalarda anlatilacak konulari dogru sirayla vaat ediyor ve her vaat bir alt dosyada karsilaniyor; habersiz gelen ya da vaat edilip anlatilmayan ana konu yok. Iki SVG gorsel referansi (settings-akisi.svg, settings-store-katmanlari.svg) dosya sisteminde mevcut, kirik gorsel yok. Onemli bir cakisma noktasi: merge/oncelik siralamasi anlatimi hem 01 dosyasi (satir 127) hem 02 dosyasi (satir 3 ve 85) hem de dizin tablolarinda tekrar tekrar anlatiliyor; bilgi tutarli (Project > Server > User > Global > Default ve runtime merge zinciri Default+Extension+Global+user+release+os+profil+server) ama ucuncu kez tekrar edilmesi hafif gurultu yaratiyor. Tekrarlar celiskili degil, sadece yogunluk var. Dizin dosyasindaki uzun 'Kok Crate Yardimcilari' tablosu ile 02 dosyasindaki devasa SettingsContent domain tablolari referans niteliginde; akisi bozmuyor ama okuma agirligi yuksek. Genel kopukluk veya sira bozuklugu tespit edilmedi.

### Orta öncelik (1)

- **`src/ayarlar/02-settings-store.md`:325** — [anlam] 'Buna rağmen' baglaci mantiksal bir karsitlik kuruyormus gibi gozukuyor ama oncesindeki ifadelerle (Tasks/Editorconfig'in store disinda tutulmasi) son cumle (akisin worktree izleyen kod tarafindan cagrilmasi gerektigi) arasinda bir karsitlik yok. Baglac okuru yaniltiyor; cumlenin asil demek istedigi 'Tum bu yonlendirme/ayrim mantigina ragmen yine de bu metodun cagrilmasi gereken yer worktree izleyicisidir' degil, sadece bir bilgi eklemesi.
  - Alıntı: `Editorconfig ise ayrı bir editorconfig_store'a yönlendirilir, ayar deposuna hiç dahil edilmez. Buna rağmen bu akışın, doğrudan worktree dosyalarını izleyen kod tarafından çağrılması gerekir.`
  - Öneri: 'Buna rağmen' yerine notr bir gecis kullanin: 'Her durumda bu metot, doğrudan worktree dosyalarını izleyen kod tarafından çağrılır.' veya 'Bu ayrımdan bağımsız olarak, set_local_settings çağrısı worktree dosya izleyicisi tarafından yapılır.'

### Düşük öncelik (8)

- **`src/ayarlar/01-akis-ve-kayit.md`:144** — [konu_butunlugu] Cumle 'aşağıdaki daha küçük içerik tipleri' diyerek bir tabloya isaret ediyor; tablo hemen geliyor ama uzun ve heterojen bir cumle icinde gecis yapildigi icin akis bulaniklasiyor. Ayrica '... farkli alan iceriklerini aynı kök merge hattında birleştirir' ifadesinde ozne (alanlar) ile yuklem (birleştirir) arasinda anlamsal kayma var: alanlar birleştirmez, store/merge hatti birleştirir.
  - Alıntı: `farklı alan içeriklerini aynı kök merge hattında birleştirir; aşağıdaki daha küçük içerik tipleri ise üst seviye alanların şema, birleştirme (merge) ve varsayılan davranışlarını taşır.`
  - Öneri: Ozneyi netlestirin: 'Bu üst seviye alanlar aynı kök merge hattında birleştirilir; aşağıdaki tabloda listelenen daha küçük içerik tipleri ise ...' seklinde edilgen yapiyla yeniden kurun.

- **`src/ayarlar/02-settings-store.md`:324** — [anlatim] 'referanslar ... okuma yapılmasına yol açabilir' ifadesinde ozne-yuklem iliskisi dusuk; referansin kendisi okuma yapmaz, referansi tutan kod eski icerikten okur. Cumle anlasilir ama anlatim bozuk.
  - Alıntı: `bu nedenle App bağlamında uzun süre tutulan referanslar, yeni hesaplamalar sonrasında güncelliğini yitirmiş eski içeriklerden okuma yapılmasına yol açabilir.`
  - Öneri: '... uzun süre tutulan referanslar üzerinden, yeni hesaplamalardan sonra güncelliğini yitirmiş eski içerik okunabilir.' veya 'uzun süre tutulan bir referans, yeni hesaplama sonrası eski içeriği gösterebilir.'

- **`src/ayarlar/ayarlar.md`:3** — [anlatim] 'override' sozcugu metin boyunca cogu yerde 'üzerine yazma' parantezli aciklamasiyla veya dogrudan Ingilizce birakiliyor. Ayni kavram icin tutarsiz kullanim var: kimi yerde 'override (üzerine yazma)', kimi yerde sadece 'override', kimi yerde 'üzerine yazma' tek basina. override yerlesik bir teknik terim sayilabilir ama bolum genelinde tek bir bicim secilmeli.
  - Alıntı: `uzaktan iletilen ayar override'larını (üzerine yazma) tek bir tip güvenli store (SettingsStore) içinde birleştirir.`
  - Öneri: Tum bolumde tek bir kullanim belirleyin: ilk gecişte 'üzerine yazma (override)' tanitip sonrasinda tutarli sekilde 'üzerine yazma katmanı/override katmanı' kullanin; serbestçe degisken kullanimi azaltin.

- **`src/ayarlar/04-keymap-dosyasi.md`:100** — [konu_butunlugu] Ayni dosyada KeybindSource rozetleri/degerleri farkli sirayla listeleniyor. Satir 90'da 'User, Default, Vim, Base' sirasi, satir 100'de 'User, Default, Base, Vim, Unknown' sirasi, enum tanimi (satir 86) ise 'User, Vim, Base, Default, Unknown' sirasi veriyor. Hata degil ama tutarsiz siralama okuru gereksiz mesgul ediyor.
  - Alıntı: `name(&self) -> &'static str — "User" | "Default" | "Base" | "Vim" | "Unknown" değerlerinden birini döner`
  - Öneri: Tum listelerde enum tanim sirasini (User, Vim, Base, Default, Unknown) esas alarak siralayin; en azindan ayni dosya icinde tek sira kullanin.

- **`src/ayarlar/02-settings-store.md`:117** — [kavram] Cumle 'global ... katmanlari bu listede yer almaz' diyor; ancak SettingsFile enum'inda Global ayri bir varyant. Kaynak koddaki get_all_files'in Global'i dahil edip etmedigi metinde net dogrulanmiyor (kontrol edilen kaynakta fonksiyon mevcut ama varyant icerigi tam teyit edilmedi). Eger get_all_files Global'i de donduruyorsa burada celiski olur; emin olmadigim icin onem dusuk.
  - Alıntı: `SettingsStore::get_all_files() — Arayüz ve override analizleri için proje, server, user ve default SettingsFile kaynaklarını döndürür; profil, OS, release kanalı, global ve extension katmanları bu listede yer almaz.`
  - Öneri: get_all_files'in donus kumesini kaynaktan dogrulayip listeyi netlestirin: Global gercekten haric mi yoksa proje/server/user/default/global hepsi mi donuyor? Cumleyi koda gore tek bir kesin liste verecek bicimde yazin.

- **`src/ayarlar/03-ayar-dosyasi-izleme.md`:129** — [anlatim] 'dosya olayları sessizce sıralanmaya başlar' ifadesi bulanik; ne anlama geldigi (olaylarin kuyruga girmesi mi, akmasi mi, kaybolmasi mi) acik degil. Hemen ardindan 'İlk değerin hiç gelmemesi' denmesi okuru 'sessizce sıralanmaya başlar' ile 'hiç gelmemesi' arasinda celiskiye dusurebilir.
  - Alıntı: `ilk yüklemenin ardından dosya olayları sessizce sıralanmaya başlar. İlk değerin hiç gelmemesi durumunda ...`
  - Öneri: Ifadeyi somutlastirin: olaylarin ne yaptigi (or. 'dosya değişiklik olayları akmaya başlar' ya da 'kanala düzenli yazılmaya başlar') net belirtilsin; ilk degerin gelmeme senaryosuyla iliskisi aciklansin.

- **`src/ayarlar/01-akis-ve-kayit.md`:127** — [kavram] Bolum genelinde ayni kavram icin tutarsiz terim: bir yerde 'yerel ayarlar' (02 dosyasi), burada 'local ayarlar', baska yerde 'proje yerel ayarları'. Ayrica 'proje ve local ayarlar' ifadesi iki ayri sey gibi gosteriliyor; oysa SettingsFile::Project ile local_settings esit kavramlar (worktree yerel .zed/settings.json). Bu, proje ve local'in ayri katmanlar oldugu yanilgisini verebilir.
  - Alıntı: `Dosya/path hedefli okumalarda proje ve local ayarlar bu zincirin en üstüne eklenerek nihai sonucu belirler.`
  - Öneri: Tek terim secin (or. 'yerel proje ayarları'). Cumleyi 'Dosya/yol hedefli okumalarda yerel proje ayarları (.zed/settings.json) bu zincirin en üstüne eklenir.' bicimine getirin; 'proje ve local' ikiliginden kacinin.

- **`src/ayarlar/02-settings-store.md`:151** — [anlam] Anlatim akisinda 'migration_status başarılı oldu mu' ile 'dönen bool migrasyon gerektiriyor mu' arasinda okuyucu icin baglanti kopuk. result() metodu Ok(bool) donerken bool'un 'migrasyon gerekti mi' anlami sezgisel degil; aradaki iliski (basariliysa Ok, bool ise migrasyon yapildi/gerekti bilgisi) bir cumlede net kurulmamis.
  - Alıntı: `MigrationStatus otomatik migrasyon adımının başarılı olup olmadığını bildirir; uygulama kodunda birleşik sonucun SettingsParseResult::result() -> Result<bool> metodu ile ele alınması gerekir. Dönen bool değeri, dosyanın otomatik migrasyon gerektirip gerektirmediğini bildirir.`
  - Öneri: Iki cumleyi baglayin: 'result() basarili parse durumunda Ok(bool) doner; bu bool degeri dosyaya otomatik migrasyon uygulanip uygulanmadigini gosterir, hata durumunda ise Err doner.' gibi tek akista aciklayin.

## src/tema_yonetimi/

**Özet:** tema_yonetimi klasorundeki 13 .md dosyasinin tamami satir satir okundu. Belgeler teknik olarak son derece detayli ve cogunlukla Zed kaynagiyla dogru ortusuyor (green() lightness 0.25, darken imzasi, apply_status_color_defaults 6 cifti, version_control fallback zincirleri, WindowBackgroundAppearance 5 varyanti, DEFAULT_DARK/LIGHT_THEME degerleri kaynaktan dogrulandi ve dogru). En kritik 3-5 sorun: (1) YUKSEK - Mermaid renk hex formatinda alpha davranisi 10. ve 11. bolumlerde 'alpha tasinmaz, yalniz #rrggbb' deniyor ama gercek Zed kodu (css_color) saydam renkleri #rrggbbaa olarak korur; 12. bolum dogru, 10/11 yanlis - kitap ici celiski + gercek davranisla celiski. (2) YUKSEK - 06. bolumdeki 'bilinmeyen alan reddedilir' testi `scrollbar_thumb.background` kullaniyor, oysa 05. bolum bu anahtarin TANINAN deprecated alan oldugunu (reddedilmemesi gerektigini) soyluyor; dogru ornek cift-r'li `scrollbarr.thumb.background` olmaliydi. (3) YUKSEK - 08. bolum satir 957'de cumle icinde Devanagari sozcuk 'भी' bozulmasi var ('de' olmali). (4) ORTA - ThemeColorsContent alan sayisi 04 (143) ve 05 (146 deprecated) arasinda uzlasmamis. (5) ORTA - 11. ve 04. bolumlerde 43.3/43.5/43.8/43.9 ve 'rehber.md #75' gibi var olmayan alt-baslik/dis belge gondermeleri (kitap genelinde 'ilgili bölüm' kullaniliyor, bu numarali gondermeler iz surulemiyor). Genel dil kalitesi yuksek; ciddi anglisizm istilasi yok, terim secimleri buyuk olcude tutarli (kucuk istisna: mirror/ayna/yansitma ve accessor/erisim metodu degisimli kullaniliyor).

**Klasör içi bütünlük:** Klasor 13 dosyadan olusuyor ve numara onekine gore (01-12 + dizin) mantikli, asagidan-yukariya bir kurulum akisi izliyor: kapsam/lisans -> iskelet -> GPUI yuzeyi -> runtime model -> JSON sozlesmesi -> yedek/fixture -> refinement -> runtime kurulus -> ayarlar -> UI tuketimi -> dis API/test -> kontrol listesi. Genel akis guclu ve bolumler birbirine 'ilgili bölüm' diliyle bagli; dizin dosyasindaki okuma sirasi onerisi pratik. Ana kopukluk noktalari: (1) Mermaid alpha davranisi 10 ve 11. bolumlerde yanlis (alpha tasinmaz), 12. bolumde dogru (alpha korunur) anlatilarak kitap kendisiyle celisiyor - bu en kritik tutarlilik kusuru. (2) ThemeColors alan sayisi 04 (143) ile 05 (146) arasinda uzlasmamis. (3) 06. bolumdeki bilinmeyen-alan testi 05. bolumdeki deprecated-alan kuraliyla celisen bir anahtar kullaniyor. (4) Kirik ic gonderme zinciri: 11. bolumde 43.3/43.8/43.9 ve 'rehber.md #75', 04. bolumde '43.5' gibi var olmayan alt-baslik numaralari - kitabin geri kalani 'ilgili bölüm' kullanirken bu numarali gondermeler iz surulemiyor. SyntaxTheme::merge davranisi 07/11/18'de uc farkli ayrintida anlatiliyor; 11. en dogru, 18. en eksik. Bunlar disinda tekrar/cakisma kontrollu: 8. bolumdeki init kodu ile 11. bolumdeki ozet tablo bilincli olarak ust uste binse de celismiyor.

### Yüksek öncelik (4)

- **`src/tema_yonetimi/10-ui-tuketimi-ve-etkilesim-renkleri.md`:259, 277** — [kavram] Iddia gercek Zed davranisiyla celisiyor. Zed kaynaginda mermaid_render::css_color fonksiyonu opak renkler icin `#rrggbb`, herhangi bir saydamlik varsa `#rrggbbaa` uretir ve alpha'yi KORUR (kaynak: crates/mermaid_render/src/mermaid_render.rs satir 157-173). Yani 'alpha kanali tasinmaz' ifadesi yanlistir; hem satir 277'deki 'fill rengi player background degerinin 0.15 opacity ile blend edilmesi' anlatimi hem de 12. bolumdeki madde 25 ile celisir.
  - Alıntı: `Renkler renderer'a `#rrggbb` CSS hex olarak verilir; alpha kanalı taşınmaz`
  - Öneri: Ifadeyi gercek davranisla uyumlu hale getir: 'Renkler renderer'a CSS hex olarak verilir; opak renkler `#rrggbb`, saydamligi olan renkler ise `#rrggbbaa` olarak aktarilir, yani alpha korunur.' Satir 277'deki blend cumlesi de buna gore gozden gecirilmeli (tema tarafinda blend yapma zorunlulugu kaldirilabilir).

- **`src/tema_yonetimi/11-dis-api-ve-test-ortami.md`:350** — [kavram] Ayni hatali iddia (alpha tasinmaz / yalnizca #rrggbb). Gercek Zed davranisi alpha varsa #rrggbbaa uretir. Hem 10. bolumdeki ifadeyi tekrarliyor hem de 12. bolum madde 25 ile dogrudan celisiyor; bolumler arasi tutarsizlik yaratiyor.
  - Alıntı: ``Hsla` renkleri renderer'a alpha degeri olmadan `#rrggbb` formatinda aktarilir.`
  - Öneri: Cumleyi 'opak renkler #rrggbb, saydamligi olan renkler #rrggbbaa olarak aktarilir; alpha korunur' bicimine getir ve 10/12. bolumlerle ayni ifadeyi kullan.

- **`src/tema_yonetimi/06-fallback-varlik-ve-fixture-tabani.md`:868-883** — [anlam] Test fixture'i yanlis anahtari 'bilinmeyen alan' ornegi olarak kullaniyor. 05. bolum satir 378 acikca soyluyor: `scrollbar_thumb.background` sozlesmenin TANINAN ama onerilmeyen (deprecated) bir parcasidir ve uyariyla okunur; reddedilmez. Allowlist dogrulayicisi bu anahtari reddetmemeli. Dogru 'bilinmeyen alan' ornegi 05. bolumde dogru kullanildigi gibi cift-r'li `scrollbarr.thumb.background` olmalidir. Mevcut haliyle test, kendi belgelendigi sozlesmeyle celisiyor.
  - Alıntı: `"scrollbar_thumb.background": "#ffffffff" ... assert!(hata.to_string().contains("bilinmeyen tema stil alanı"));`
  - Öneri: Fixture'taki anahtari `scrollbar_thumb.background` yerine `scrollbarr.thumb.background` (fazladan r ile) yap; boylece 05. bolumdeki bos_tema/bilinmeyen_alan testleriyle ve deprecated-alan kuraliyla tutarli olur.

- **`src/tema_yonetimi/08-runtime-kurulusu-ve-tema-secimi.md`:957** — [anlatim] Cumlenin icinde Turkce/Latin disi bir karakter dizisi var: 'भी' (Devanagari/Hintce 'de/dahi' anlamina gelen sozcuk). Bu acik bir bozulma/yazim hatasi; cumle 'dolayli erisim de mumkundur' demek istemis.
  - Alıntı: ``cx.asset_source()` üzerinden dolaylı erişim भी mümkündür.`
  - Öneri: 'भी' sozcugunu 'de' ile degistir: 'cx.asset_source() üzerinden dolaylı erişim de mümkündür.'

### Orta öncelik (4)

- **`src/tema_yonetimi/05-json-sozlesmesi-ve-parse-katmani.md`:391** — [anlam] Alan sayisi belge ici tutarsiz. 04. bolum calisma zamani ThemeColors icin 143 alan (Hsla) verir ve content alanlarinin 'bu calisma zamani alanlarina karsilik gelen content alanlariyla sinirli' oldugunu soyler (satir 184-285). Burada ise '146 alan, 3'u deprecated' deniyor; gerekce/dayanak verilmeden 143 ile uyumsuz bir sayi. Deprecated alanlarin sayisi ve toplamin nasil 146'ya ulastigi baska hicbir yerde acilmiyor.
  - Alıntı: `| `ThemeColorsContent` (146 alan, 3'ü deprecated) | her biri `Option<String>` |`
  - Öneri: Sayiyi 04. bolumdeki 143 ile uzlastirin veya '143 kanonik + 3 deprecated alias = 146' aciklamasini metne ekleyin; aksi halde okur iki celisen sayiyla kalir.

- **`src/tema_yonetimi/04-runtime-veri-modeli.md`:1165** — [konu_butunlugu] Kirik ic gonderme. '43.5'te detay' diye bir alt-baslik yok; kitapta baslik numaralandirma 'NN.' (or. 17, 43, 44) ve cogunlukla 'ilgili bölüm' ifadesiyle yapiliyor, 43.5 gibi alt-numara hicbir yerde tanimli degil. 'ColorScale Ailesi' aslinda ayni dosyadaki 17. bolumde anlatiliyor.
  - Alıntı: `| `scales` | Aileye bağlı palet matrisi — `ColorScales` (43.5'te detay). |`
  - Öneri: '(43.5'te detay)' ifadesini '(bu bölümün ColorScale Ailesi başlığında detaylı)' veya '(17. bölümde detaylı)' ile degistirin; kitap genelindeki 'ilgili bölüm' uslubuna uydurun.

- **`src/tema_yonetimi/11-dis-api-ve-test-ortami.md`:271, 295, 301, 355, 585, 595, 622, 643** — [konu_butunlugu] Bir dizi kirik ic/dis gonderme. '43.8', '43.9', '43.3' gibi alt-baslik numaralari belgede yok (dosyada yalnizca '## 43.' ve '## 44.' var). 'rehber.md #75' ise bu kitabin disindaki/var olmayan bir belgeye gonderme; ayni dosyada baska yerlerde 'ilgili bölüm' kullaniliyor, bu yuzden tutarsiz ve okur icin izi suremez.
  - Alıntı: `public metotları 43.8'de not edilmiştir / 43.9'da resmi imzası verilir / 43.3 başlığı altında / rehber.md #75`
  - Öneri: Tum 43.x alt-numara gondermelerini 'ilgili bölüm' veya somut bölüm adina cevirin; 'rehber.md #75' gondermelerini gecerli bir kaynak yoksa kaldirin ya da dogru belge/bölüm adiyla degistirin.

- **`src/tema_yonetimi/11-dis-api-ve-test-ortami.md`:271** — [anlatim] Tablo hucresinin 'Öğe' sutunu bozuk. Ingilizce 'Redistributable' sozcugu ile Turkce 'degildir' karismis ve oge adi (FontFamilyCache) iki nokta sonrasinda gomulu; diger satirlarin aksine duzgun bir oge tanimlayicisi degil. Anlami da bulanik: FontFamilyCache'in 'yeniden dagitilamaz' olmasiyla 'sozlesme disi' olmasi farkli seyler.
  - Alıntı: `| `Redistributable değildir: FontFamilyCache` | Sözleşmenin dışında kalır...`
  - Öneri: Hucreyi sade bir oge adina indirgeyin: oge sutununa yalnizca `FontFamilyCache`, aciklama sutununa 'Sozlesmenin disinda kalir; public metotlari ilgili bölümde notlandi' yazin. Yanlis anglisizmi ('Redistributable degildir') kaldirin.

### Düşük öncelik (5)

- **`src/tema_yonetimi/09-ayarlar-ve-yogunluk-entegrasyonu.md`:930** — [konu_butunlugu] Dis dosya gondermesi 'bilesen_rehberi.md' bu tema_yonetimi klasorunde yok; baska bir konu/kitap bolumune gonderme oldugu acik degil ve dogrulanamaz. Kirik baglanti riski tasiyor.
  - Alıntı: `**`bilesen_rehberi.md` ile köprü:** `DynamicSpacing::BaseXX.px(cx)` helper'ı zaten `UiDensity`'i bilir`
  - Öneri: Gondermenin gecerli bir dosya/bölüm oldugunu dogrulayin; degilse 'ilgili bileşen rehberi bölümü' gibi notr bir ifadeye cevirin ya da kaldirin.

- **`src/tema_yonetimi/07-refinement-ve-tema-uretimi.md`:808-810** — [kavram] SyntaxTheme::merge davranisi 18. bolum (04. dosya, satir 1227-1232) ile 07. bolum arasinda gerilimli anlatiliyor. 18. bolumde merge 'tuple-bazli yeni capture ekleme / girdi bossa tabani oldugu gibi dondurme' olarak ozetlenirken, burada 'alan bazli option-or birlestirme (new.f.or(existing.f))' deniyor; 11. bolum satir 289 ise 'aynı capture varsa new.f.or(existing.f), capture yeni ise sona eklenir' diyerek en ayrintili dogru tanimi veriyor. 18. bolumdeki ozet bu alan-bazli birlesmeyi belirtmedigi icin okur iki farkli merge modeli arasinda kalabiliyor.
  - Alıntı: `Bu yol alan bazlı option-or birleştirme yapar; override'da olmayan bir capture tabandaki `HighlightStyle`'ı korur.`
  - Öneri: 18. bolumdeki SyntaxTheme::merge aciklamasini 11/07. bolumdeki 'ayni capture'da alan bazli option-or, yeni capture'da listeye ekleme' tanimiyla hizalayin; uc yerde ayni sozlesmeyi tek bicimde anlatin.

- **`src/tema_yonetimi/02-proje-iskeleti-ve-bagimliliklar.md`:188-191** — [konu_butunlugu] Tablonun baslik metni ve cevresindeki anlatim 'Her bağımlılığın rolü' diyor ve kvs_tema/Cargo.toml [dependencies] blogu (satir 113-133) icinde inventory, settings_macros, derive_more, serde_path_to_error YER ALMIYOR. Bu dort satir aslinda ayarlar tarafi (kvs_tema_ayarlari) icin gecerli; ama tablo dogrudan kvs_tema bagimlilik matrisinin devami gibi sunuldugundan, listelenen Cargo.toml ile tablo arasinda kopukluk/uyumsuzluk var.
  - Alıntı: `| `inventory` | Bağlama zamanında statik kayıt | ... | `settings_macros` (Zed iç crate) | ... | `derive_more` | ... | `serde_path_to_error` | ...`
  - Öneri: Bu dort satiri ayri bir alt-baslik altinda ('Ayarlar tarafinda devreye giren ek bağımlılıklar') toplayin veya tabloda 'yalnizca kvs_tema_ayarlari icin' notunu acik biçimde belirtin; boylece yukaridaki Cargo.toml ile tutarsizlik ortadan kalkar.

- **`src/tema_yonetimi/03-gpui-tema-yuzeyi.md`:236** — [konu_butunlugu] Gorsel referans yolu diger dosyalardaki konvansiyonla tutarsiz. Bu kitapta gorseller genelde '../assets/images/...' altinda (or. 01,04,05 bolumleri: ../assets/images/tema-crate-bagimliliklari.svg, theme-colors-yapisi.svg). Burada ve ayni dosyada baska yerlerde 'assets/...' (or. satir 5'teki json-parse-pipeline 05'te 'assets/...') gibi farkli/goreli yollar kullanilmis; en az biri kirik baglanti olma riski tasiyor.
  - Alıntı: `![FontWeight Ölçeği](assets/font-weight-olcegi.svg)`
  - Öneri: Tum gorsel yollarini tek bir konvansiyona ('../assets/images/...') gore birlestirip dosyalarin gercekten var oldugunu dogrulayin; tutarsiz 'assets/...' yollarini duzeltin.

- **`src/tema_yonetimi/01-hedef-kapsam-ve-lisans.md`:9** — [konu_butunlugu] Klasor dizin dosyasi (tema_yonetimi.md) okuma sirasi olarak 1->8 sirali ilerlemeyi onerirken (satir 35), 01. bolum buyuk resmi 'asagidan yukariya' (veri sozlesmesi -> refinement -> runtime) sunuyor. Iki anlatim celismez ama gecis acik degil: okur 'asagidan yukari ogren' ile 'bolumleri 1'den 8'e oku' onerilerini bagdastirmakta zorlanabilir; bir cümlelik koprü eksik.
  - Alıntı: `**Okuma yönü:** Aşağıdan yukarıya. En altta veri sözleşmesi durur; ... öğrenme sırası da en sıkı kuralların olduğu yerden başlar`
  - Öneri: 01. bolumde 'asagidan yukariya' kavramsal sirayi anlatirken, bolum numaralarinin (1->8) bu mantigi zaten izledigine dair tek cümlelik bir koprü ekleyin.

## src/assets/

**Özet:** Klasor genel olarak yuksek kaliteli, iyi yapilandirilmis ve teknik olarak buyuk olcude dogru; gercek Zed kaynagiyla ortusen aciklamalar isabetli. En kritik sorunlar: (1) Iki ayri yerde (04. bolum satir 448 ve 07. bolum satir 326) Turkce cumlenin ortasinda Devanagari/Hintce 'भी' sozcugu yer aliyor; metin bozuk gorunuyor ve 'de/da' baglaci ile degistirilmeli. (2) 05. bolum satir 94'te '...sonraki bolumde images/ klasoru ele alinacaktir' cumlesi 04. bolumden hatali kopyalanmis; oysa 05. bolumun kendisi images bolumudur. (3) 01. bolum satir 124-137'deki klasor agacinda font ailelerinin girintisi bozuk, ibm-plex-sans/ ve lilex/ fonts/ ile ayni seviyede gosterilmis. (4) 01. bolum satir 213'te 'Yapilamaz' sutunundaki hucre aslinda olumlu/onerilen bir davranisi tarif ederek sutun basligiyla celisiyor. (5) Cesitli dizgi hatalari: 'Asel' (Asil), 'un cache' (bir onbellek), 'and' (ve), 'baglanlanan' (baglanan), 'varlik varlik' tekrari ve 'disabled_dizin_tarama' anlamsiz fonksiyon adi. Terminoloji genelde tutarli olsa da 'registry' icin sicil/registry/kayit ve 'cache' icin onbellek/cache karisik kullaniliyor; kitap geneli icin sabitlenmesi onerilir.

**Klasör içi bütünlük:** Klasor genel olarak iyi planlanmis bir okuma sirasina sahip: assets.md dizini 9 bolumu mantikli bir ogrenme egrisine gore siralliyor (kapsam -> AssetSource sozlesmesi -> font -> ikon -> gorsel -> ses -> JSON -> test -> kontrol listesi) ve her bolum sonunda 'Pratik akis ozeti' diyagrami ile kapaniyor; terminoloji buyuk olcude tutarli. Ana butunluk sorunlari: (1) Tekrar/cakisma: font klasor agaci 01 ve 03'te, SvgAsset implementasyonu 04 ve 08'de, Resource enum + uc kaynak yolu 05 ve 08'de, badge aciklamasi 06 ve 07'de neredeyse birebir tekrarliyor; bu tekrarlar bazi yerlerde kasitli (referans bolumler) olsa da 05. bolumdeki 'Sonraki bolumde images/ klasoru ele alinacaktir' cumlesi 04'ten kopyalanip yanlis baglamda kalmis. (2) Kuruluk/dizgi kalintilari: iki yerde Devanagari 'भी' sozcugu, 'Asel', 'un cache', 'and', 'baglanlanan' gibi dizgi hatalari metnin titiz redaksiyondan tam gecmedigini gosteriyor. (3) 01. bolumdeki klasor agaci girinti hatasi font ailelerini yanlis seviyede gosteriyor. (4) API gosterim ikilemi (Application::with_platform vs gpui_platform::application) bolum ici tutarsizlik yaratiyor. Sira ve gecisler genel olarak saglam; vaat edilen konular ilgili bolumlerde karsilaniyor.

### Yüksek öncelik (4)

- **`src/assets/04-icon-ve-svg-sistemi.md`:448** — [anlatim] Cumlenin ortasinda Turkce olmayan Devanagari (Hintce) bir sozcuk 'भी' yer aliyor. Buraya Turkce baglac gelmeli; metin bozuk gorunuyor ve kopyala-yapistir hatasi izlenimi veriyor.
  - Alıntı: `nitekim `Vector` bileşeni भी `svg().path()` kullandığı için`
  - Öneri: 'भी' sozcugunu kaldirip 'nitekim `Vector` bileseni de `svg().path()` kullandigi icin' bicimine cevir.

- **`src/assets/07-json-varlik-akisi.md`:326** — [anlatim] Tablo hucresinde Devanagari (Hintce) 'भी' sozcugu var; Turkce 'de/da' baglaci olmali. Ayni satirin altindaki satirda (327) ayni anlam dogru bicimde 'App kurulmadan önce de çağrılabilir' yazilmis; bu da tutarsizligi gosteriyor.
  - Alıntı: ``App` kurulmadan önce भी çağrılabilir`
  - Öneri: 'भी' sozcugunu 'de' ile degistir: 'App kurulmadan önce de çağrılabilir'.

- **`src/assets/05-image-ve-raster-varlik.md`:94** — [konu_butunlugu] Bu cumle oldugu gibi 04. bolumden (satir 431) kopyalanmis. Ancak 05. bolumun kendisi zaten 'Gorsel ve raster varlik akisi' / images klasoru bolumudur; yani 'sonraki bolumde ele alinacaktir' ifadesi yanlistir, konu tam da bu bolumde isleniyor. Hatta bir onceki paragrafta (Vector ile Icon farki) ile bu cumle 04. bolumdeki paragrafin neredeyse birebir tekrari.
  - Alıntı: `Sonraki bölümde `images/` klasörü ve `Vector` bileşeni ayrıntılı olarak ele alınacaktır.`
  - Öneri: Bu cumleyi 05. bolumden cikar ya da gecmis zamana cevirerek 'bu bolumde ayrintili ele alinmaktadir' bicimine getir; ayrica 85-94 araliginin 04. bolumle birebir tekrarini gozden gecir.

- **`src/assets/01-hedef-kapsam-lisans-ve-topoloji.md`:213** — [anlam] Bu hucre 'Yapilamaz' sutununda yer aliyor ama icerigi aslinda 'yapilmasi onerilen' bir davranisi tarif ediyor ('kopyalamak yerine yeniden yazmak' iyi bir seydir). Sutun basligi ile icerik celisiyor; mantiken 'Yapilamaz' sutununda 'gövdesini dogrudan kopyalamak' yazmaliydi.
  - Alıntı: `Zed'in `assets` modülünün gövdesini doğrudan kopyalamak yerine yeniden yazmak`
  - Öneri: Hucreyi 'Zed'in `assets` modülünün gövdesini doğrudan kopyalamak' olarak duzelt; 'yerine yeniden yazmak' kismini cikar (zaten Yapilabilir sutunundaki son satir bu olumlu davranisi anlatiyor).

### Orta öncelik (4)

- **`src/assets/01-hedef-kapsam-lisans-ve-topoloji.md`:124-137** — [anlatim] Klasor agacindaki girinti bozuk: `ibm-plex-sans/` ve `lilex/` alt klasorleri `fonts/` altinda degil, `fonts/` ile ayni seviyede (└──/├── ust seviye) gosterilmis. Ayrica `lilex/` icin `└──` kullanildiktan sonra `icons/` yeniden `├──` ile basliyor; agac dallari mantiken kapanmiyor. Gerçek yapida her iki font ailesi de `fonts/` altinda olmali (bkz. 03. bolum satir 13-27 dogru gosterim).
  - Alıntı: `├── fonts/                       # TextSystem + USVG fontdb okur
├── ibm-plex-sans/`
  - Öneri: `ibm-plex-sans/` ve `lilex/` satirlarini `fonts/` altinda girintili (│ ile) gosterecek bicimde duzelt; 03. bolumdeki agac yapisini referans al.

- **`src/assets/05-image-ve-raster-varlik.md`:335** — [anlatim] 'ayri un cache' ifadesinde anlamsiz 'un' sozcugu var; muhtemelen yazim/dizgi hatasi (belki 'bir' yazilacakti). Cumle bozuk okunuyor.
  - Alıntı: `Belirli bir bölgedeki görsellerin ayrı un cache yapısına yönlendirilmesi`
  - Öneri: 'ayri un cache yapısına' ifadesini 'ayrı bir önbellek yapısına' veya 'ayrı bir cache yapısına' olarak duzelt.

- **`src/assets/04-icon-ve-svg-sistemi.md`:295** — [anlatim] 'Asel rasterlestirme' ifadesindeki 'Asel' anlamsiz; muhtemelen 'Asil' (esas) yazilacakti. Ayrica bu paragrafta kod tanimlayicilari (`render_pixmap`, `Some(bytes)`, `None`, `self.asset_source.load`) backtick'siz, duz metne karismis bicimde yazilmis; bolumun geri kalanindaki bicimle tutarsiz ve okunabilirligi dusuruyor.
  - Alıntı: `Asel rasterleştirme işlemi, gövde içerisinde yerel bir closure olarak tanımlanan `render_pixmap` vasıtasıyla yürütülür.`
  - Öneri: 'Asel' -> 'Asıl' olarak duzelt; paragraftaki `render_pixmap`, `bytes`, `Option<&[u8]>`, `Some(bytes)`, `None`, `self.asset_source.load(&params.path)?`, `Embedded`, `ExternalSvg` gibi tanimlayicilari backtick icine al.

- **`src/assets/03-font-yukleme.md`:73** — [anlatim] Turkce cumlenin ortasinda Ingilizce baglac 'and' kullanilmis. Gereksiz anglisizm; Turkce 've' olmali.
  - Alıntı: ``license.txt` and `OFL.txt` gibi dosyalar dışlanır.`
  - Öneri: '`license.txt` ve `OFL.txt` gibi dosyalar dışlanır.' olarak duzelt.

### Düşük öncelik (8)

- **`src/assets/02-asset-source-ve-rust-embed.md`:302-303** — [kavram] Ayni bolumde uygulama kurulus zinciri iki farkli API ile gosteriliyor: 4. bolumde (satir 182) `Application::with_platform(...).with_assets(...)`, 7. bolumde ise `gpui_platform::application()...`. Her iki API de kaynakta mevcut olsa da bolum ici tutarlilik acisindan okuyucu icin kafa karistirici; hangi yolun onerildigi netlesmiyor.
  - Alıntı: `let uygulama = gpui_platform::application().with_assets(UygulamaVarliklari);`
  - Öneri: Iki ornek arasinda kisa bir not ekleyerek `gpui_platform::application()` ile `Application::with_platform` iliskisini acikla veya ornekleri ayni kurulus desenine hizala.

- **`src/assets/08-test-headless-ve-dis-asset.md`:387-400** — [kavram] Dosya sistemi varlik kaynagi orneginde yardimci fonksiyon adi `disabled_dizin_tarama` olarak verilmis. 'disabled' (devre disi) oneki bu baglamda anlamsiz; fonksiyon aslinda dizini bekleyenler kuyruguna ekliyor. Muhtemelen onceki bir taslaktan kalmis yanlis ad. Kod blogu icindeki tanimlayici oldugu icin onemi dusuk birakildi, ancak duz metindeki anlatim ile uyumsuz.
  - Alıntı: `disabled_dizin_tarama(tam_yol, &mut bekleyenler);
...
fn disabled_dizin_tarama(tam_yol: PathBuf, bekleyenler: &mut Vec<PathBuf>) {`
  - Öneri: Fonksiyon adini anlamli bir Turkce ada cevir (or. `dizini_kuyruga_ekle` veya `alt_dizini_tara`) ve cagri yerini de guncelle.

- **`src/assets/01-hedef-kapsam-lisans-ve-topoloji.md`:68** — [anlam] Cumle 'SettingsAssets ... settings crate'iyle ayni konumda bulunmalari' diyor. SettingsAssets tek bir struct; 'bulunmalari' coguluyla ifade edilmesi ve 'ayni konumda' belirsizligi anlatimi bulaniklastiriyor. 02. bolum (satir 103-106) bu konuyu daha net (erken erisim + crate siniri) anlatiyor; 01'deki gerekce (yalnizca 'kucuk boyutlu olduklari icin') 02 ile kismen ortusmuyor.
  - Alıntı: `settings crate'iyle aynı konumda bulunmaları derleme süresi üzerinde kayda değer bir maliyet oluşturmaz.`
  - Öneri: Cumleyi sadelestir: 'SettingsAssets, kucuk JSON dosyalarini tasidigi ve settings crate'i icinde tutuldugu icin derleme suresine kayda deger bir maliyet eklemez' ve 02. bolumdeki gercek gerekce (erken erisim/crate siniri) ile uyumlu hale getir.

- **`src/assets/02-asset-source-ve-rust-embed.md`:258** — [anlatim] 'belirli bir varlik varlik turu icin' ifadesinde 'varlik' sozcugu gereksiz tekrarlanmis (yazim hatasi).
  - Alıntı: ``Asset` trait'i ise belirli bir varlık varlık türü için decode/parse/decode-image gibi işlemleri`
  - Öneri: 'belirli bir varlık türü için' olarak duzelt.

- **`src/assets/06-sound-ve-binary-varlik.md`:170** — [kavram] Kod orneginde `if let ... && let ...` zinciri kullaniliyor (let-chains). Bu, kararli Rust'ta uzun sure deneysel kalmis bir ozelliktir; rehberin geri kalaninda gosterilen kod stiliyle uyumlu olup olmadigi ve okuyucunun kafasini karistirip karistirmayacagi belirsiz. Kod blogu oldugu icin dilbilgisi denetimi disinda; onemi dusuk. Ayni kalip 08. bolum satir 197'de de var.
  - Alıntı: `&& let Some(sablon) = Assets.load(yol.as_ref()).log_err().flatten()`
  - Öneri: Mumkunse let-chains yerine ic ice `if let` kullan ya da bu sozdiziminin kullanildigina dair kisa bir not ekle (Rust surum gereksinimi).

- **`src/assets/01-hedef-kapsam-lisans-ve-topoloji.md`:126** — [konu_butunlugu] 01. bolumdeki klasor agacinda `fonts/` altinda yalnizca `ibm-plex-sans/` ve `lilex/` ailelerinin tam dosya listesi verilmis (license dosyalari dahil), ama diger klasorler (icons, themes) sadece ozet gosterilmis. Detay seviyesi klasorler arasinda tutarsiz; ayrica bu detayli font agaci 03. bolumde (satir 13-27) birebir tekrar ediliyor.
  - Alıntı: `├── ibm-plex-sans/`
  - Öneri: 01. bolumdeki agaci ozet seviyede tut (font ailelerinin tek tek .ttf dosyalarini listeleme), detayli font agacini 03. bolume birak; boylece tekrar azalir ve detay seviyesi tutarlilasir.

- **`src/assets/04-icon-ve-svg-sistemi.md`:342** — [anlatim] 'bağlanlanan' sozcugu yazim hatasi; 'bağlanan' olmali.
  - Alıntı: `Dizinin elemanları bir icon key'e bağlanlanan uzantılardır`
  - Öneri: 'bir icon key'e bağlanan uzantılardır' olarak duzelt.

- **`src/assets/04-icon-ve-svg-sistemi.md`:303** — [kavram] Anti-aliasing aciklamasi olarak 'GPU bunu kuculterek ... ara degerler elde eder' ifadesi teknik olarak yaklasik dogru olsa da, kaynak kodda olceklendirme RenderImage.scale_factor uzerinden yapilip ornekleme/yumusatma asagi-orneklemeyle gerceklesiyor; 'GPU kuculterek' ifadesi mekanizmayi fazla basitlestiriyor. Emin olunamadigi icin onem dusuk.
  - Alıntı: `render işlemi iki katı boyutta gerçekleştirildikten sonra GPU bunu küçülterek yumuşak geçişli ara değerler elde eder.`
  - Öneri: Ifadeyi 'iki kat cozunurlukte rasterlestirilip ekranda kucululdugunde (downsampling) kenar gecisleri yumusar' gibi mekanizmayi belirsiz birakmayan bir bicime getir.

## src/platform_ust_bar/

**Özet:** Bolum teknik olarak cok saglam: Zed kaynagiyla dogrulanan tum somut sabitler ve davranislar (yukseklik, padding, glyph kodlari, kapat kirmizisi, WindowControls alanlari, parse/linux_default, animasyon suresi) metinle birebir ortusuyor; uydurma ya da hatali kavram neredeyse yok. En kritik 5 sorun: (1) 09. bolum satir 251'deki 'iki turluk donus' ifadesi yanlistir ve kitabin kendi 07/08 bolumleriyle ve kaynakla celisir; animasyon 'her turu 2 saniyede tamamlayan sonsuz tekrarli' bir donustur. (2) Duz metinde uc yerde (01:178, 06:86, 07:168) cevrilmemis Ingilizce 'and' baglaci kalmis; Turkce 've' olmali. (3) 'butonler' yazim hatasi iki yerde (03:112, 05:188), dogrusu 'butonlar'. (4) UpdateButton/UpdateVersion detayinin 02/07/08/09'da asiri tekrari ve kucuk anlatim tutarsizliklari (sha.full vs AppCommitSha::full, App::button_layout vs cx.button_layout). (5) show_menus iki-render-modu konusunun 02'de habersiz tanitilip 09'a kadar aciklamasiz birakilmasi (ileri referans eksik). Sorunlarin cogu dusuk/orta onemde; bolumun anlam ve kavram dogrulugu yuksek, baslica iyilestirme alani bolumler arasi terim/yazim tutarliligi ve tekrarin azaltilmasi.

**Klasör içi bütünlük:** Klasor ici akis guclu ve mantikli bir ogretim sirasi izliyor: dizin (platform_ust_bar.md) -> hedef/kapsam/lisans (01) -> Zed kaynak haritasi (02) -> proje iskeleti (03) -> entegrasyon ve sozlesme (04) -> render akisi ve pencere kontrolleri (05) -> yerel sekmeler (06) -> urun basligi (07) -> pratik uygulama/kontrol listeleri (08) -> referans/dogrulama (09). Bolumler birbirine duzgun gondermeler yapiyor ('ilgili bolum', '[Ust Bar](../ust_bar/ust_bar.md)'). Uc katmanli model (platform kabugu / urun basligi / uygulama durumu) ilk bolumde kuruluyor ve tum kitap boyunca tutarli kullaniliyor. Onemli bir tekrar/cakisma sorunu: UpdateButton/UpdateVersion (cesma metinleri, disabled durumlar, LoadCircle animasyonu, SHA/full bilgisi) 02, 07, 08 ve 09'da tekrar tekrar anlatiliyor; cogu yerde ayni ama 09 satir 251'deki 'iki turluk donus' ifadesi digerleriyle celisiyor. Bu konunun bu kadar cok yerde tekrari, kitabin platform kabugundan cok urun basligi (title_bar) ayrintisina kaydigini gosteriyor; urun katmani zaten ayri 'Ust Bar' bolumune havale edildigi icin bu detayin platform kabugu rehberinde dort kez gecmesi gereksiz tekrar yaratiyor. show_menus iki-render-modu konusu 02'de habersiz tanitilip 09'da aciklaniyor (ileri referans eksik). Genel teknik dogruluk cok yuksek: kaynak Zed kodu ile dogrulanan tum sabitler (32px/34px/1.75rem yukseklik, TRAFFIC_LIGHT_PADDING 78/71, MAX_BUTTONS_PER_SIDE=3, Segoe glyph codepoint'leri e921/e922/e923/e8bb, #E81120 kapat kirmizisi, WindowControls'un 4 alani close olmadan, parse/linux_default davranisi, with_rotate_animation(2)=from_secs(2).repeat()) metinle birebir ortusuyor.

### Orta öncelik (4)

- **`src/platform_ust_bar/09-referans-ve-dogrulama.md`:251** — [anlam] Bu ifade hem kaynakla hem de kitabin diger bolumleriyle celisir. Kaynakta `with_rotate_animation(2)` cagrisi `Animation::new(Duration::from_secs(2)).repeat()` kullanir; yani '2' bir tur sayisi degil, BIR turun suresidir (2 saniye) ve animasyon sonsuz tekrarlidir. Ayni dosya 07 ve 08 bolumlerinde 'her turu 2 saniyede tamamlayan surekli (sonsuz tekrarli)' dogru ifadesi gecer. 'Iki turluk donus' yanlistir; donus sonludur izlenimi verir.
  - Alıntı: `Döner ikon yalnız `checking` ve `installing` durumlarında `IconName::LoadCircle` ile iki turluk dönüş yapar`
  - Öneri: Ifadeyi diger bolumlerle ayni dile getirin: 'her turu 2 saniyede tamamlayan surekli (sonsuz tekrarli) bir donus uygular' seklinde duzeltin.

- **`src/platform_ust_bar/01-hedef-kapsam-ve-lisans.md`:178** — [anlatim] Duz anlatim metninde Ingilizce baglac 'and' kalmis. Bu kod degil, Turkce cumledir; Turkce 've' kullanilmalidir. Ayni hata 06. bolum satir 86 ('tab_bar_visible() and tabbed_windows()') ve 07. bolum satir 168 ('platform_linux.rs and platform_windows.rs') metinlerinde de gecer.
  - Alıntı: `Buna karşılık `refineable` and `collections` gibi bazı yardımcı workspace crate'leri`
  - Öneri: Bu uc yerdeki ' and ' baglacini ' ve ' ile degistirin. Kod tanimlayicilari (geri tirnak icindekiler) korunur; yalniz baglac cevrilir.

- **`src/platform_ust_bar/06-native-pencere-sekmeleri.md`:86** — [anlatim] Duz metinde Ingilizce 'and' baglaci kalmis (01. ve 07. bolumlerle ayni kalip).
  - Alıntı: `platformun `tab_bar_visible()` and `tabbed_windows()` çağrılarının sonucunu`
  - Öneri: ' and ' -> ' ve '.

- **`src/platform_ust_bar/07-urun-titlebari-ve-uygulamaya-baglama.md`:168** — [anlatim] Duz metinde Ingilizce 'and' baglaci kalmis (01. ve 06. bolumlerle ayni kalip).
  - Alıntı: ``platforms/platform_linux.rs` and `platforms/platform_windows.rs` dosyaları`
  - Öneri: ' and ' -> ' ve '.

### Düşük öncelik (8)

- **`src/platform_ust_bar/09-referans-ve-dogrulama.md`:251** — [anlam] Bu satir `updated` durumu icin `Download` ikonu der; kaynakta `updated()` gercekten `IconName::Download` kullanir, bu dogrudur. Ancak ayni dosyada (ust kisimdaki tablolarda ve bolum 07/08 metinlerinde) `updated` durumunun ikonu cogu yerde anilmaz; bolumler arasi anlatim tutarliligi acisindan `updated`=Download bilgisinin tek yerde gecip baska yerde dusurulmesi okuyucuda belirsizlik yaratabilir. Bilgi dogru, sunum tutarsiz.
  - Alıntı: ``downloading` ve `updated` durumlarında `Download`, `errored` durumunda `Warning` ikonu kullanılır`
  - Öneri: `updated` durumunun `Download` ikonu kullandigini 07 ve 08 bolumlerindeki paralel cumlelerde de ayni bicimde belirtin ya da her yerde ayni ozetlemeyi kullanin.

- **`src/platform_ust_bar/05-platform-titlebar-render-akisi-ve-pencere-kontrolleri.md`:188** — [anlatim] Yazim hatasi: 'butonler' yanlistir, dogru cogul eki 'butonlar' olmalidir (buyuk unlu uyumu). Ayni hata 03. bolum satir 112'de ('Platforma ozel butonler') de gecer.
  - Alıntı: `Bu butonler uygulamanın eylem katmanına hiç uğramaz.`
  - Öneri: 'butonler' -> 'butonlar' olarak duzeltin (her iki dosyada).

- **`src/platform_ust_bar/03-proje-iskeleti-ve-bagimliliklar.md`:112** — [anlatim] Yazim hatasi: 'butonler' yerine 'butonlar' olmalidir (05. bolum satir 188 ile ayni kalip).
  - Alıntı: `Platforma özel butonler ve native sekmeler bu gruba girer.`
  - Öneri: 'butonler' -> 'butonlar'.

- **`src/platform_ust_bar/02-zed-kaynak-haritasi-ve-baglanti-modeli.md`:17** — [kavram] Burada API ismi `sha.full()` yazilmis; ayni kavram 07. bolum satir 50'de `AppCommitSha::full()`, 09. bolum satir 262'de yine `AppCommitSha::full()` ve 250'de 'SHA icin short() degil full() kullanilir' bicimindedir. Tip on eki bir yerde dusuruldugu icin ('sha.full()') ayni kavram bolumler arasi farkli yazilmis goruntusu veriyor. Kaynakta cagri `AppCommitSha::full(&self)` metodudur; islev dogru anlatilmis, yalniz yazim tekduze degil.
  - Alıntı: `İpucu `"Update to Version: "` önekini, SHA için de `sha.full()` ile kısaltılmamış tam commit değerini kullanır.`
  - Öneri: Tutarlilik icin `AppCommitSha::full()` bicimini her yerde ayni kullanin; ilk gectigi 02. bolumde de tam tip adini verin.

- **`src/platform_ust_bar/02-zed-kaynak-haritasi-ve-baglanti-modeli.md`:70** — [konu_butunlugu] show_menus(cx) yardimcisinin iki render moduna (urun basligi iki satira ayrilir / cocuklar dogrudan verilir) yol actigi burada kisaca aniliyor; ancak bu mekanizmanin asil aciklamasi cok sonra, 09. bolum satir 268'de geliyor. Ara bolumlerde (07) urun cocuk yerlesimi anlatilirken bu iki-mod ayrimina deginilmemesi, okuyucunun 02'de habersiz tanitilan konuyu 09'a kadar askida tutmasina yol acar. Ileri referans verilmemis.
  - Alıntı: `Bu yardımcı yalnız ayarı değil, macOS'ta `ZED_USE_CROSS_PLATFORM_MENU` çevre değişkeni koşulunu da dikkate alır.`
  - Öneri: 02. bolumdeki bu cumleye 'ayrintilari Referans ve dogrulama bolumunde' gibi bir ileri referans ekleyin, ya da iki render modunu tanitan kisa bir kapsam notu birakin.

- **`src/platform_ust_bar/03-proje-iskeleti-ve-bagimliliklar.md`:33** — [konu_butunlugu] Klasor agacinda `platform_title_bar_rehberi.md`, `platform_title_bar_aktarimi.md` ve `platform_title_bar_kaymasi_kontrol.sh` dosyalari gosteriliyor; ancak gercek depo yapisinda rehber `src/platform_ust_bar/` altinda numarali .md dosyalarina bolunmus durumda. Tek dosyalik `platform_title_bar_rehberi.md` ile bu cok-dosyali yapi arasinda kopukluk var; okuyucu agactaki yol ile fiili yapiyi eslestirmekte zorlanabilir. (Diger .md dosyalari aktarim gunlugune atif yapiyor, o yuzden bu kurgu bilincli olabilir; bu nedenle onem dusuk.)
  - Alıntı: `├── gpui_belge/                       ← rehber + aktarım günlüğü + kayma betiği`
  - Öneri: Agacta gosterilen rehber dosyasinin gercek dizin yapisiyla (or. src/platform_ust_bar/ altindaki bolumler) ortusen bir aciklama ya da not ekleyin; aksi halde 'rehber' tek dosya gibi algilaniyor.

- **`src/platform_ust_bar/01-hedef-kapsam-ve-lisans.md`:30** — [anlatim] Baslik etiketi olarak Ingilizce 'mirror' sozcugu geri tirnak icinde kullanilmis; metnin akisinda bu bir kod tanimlayicisi degil, kavram etiketidir ('davranis yansitma/aynalama'). Kitap genelinde fiil olarak 'mirror edilir' bilincli teknik terim olarak korunmus olsa da, bu baslik etiketinde duz Turkce karsiligi daha okunur olur. Onem dusuk cunku terim kitap genelinde tutarli.
  - Alıntı: `**Platform kabuğu (en alt katman) — `mirror`:**`
  - Öneri: Baslik etiketini 'davranis yansitma' veya 'aynalama' gibi Turkce bir karsilikla verip parantez icinde (mirror) birakmayi degerlendirin; ya da kitap genelindeki tercihi bilincli koruyun.

- **`src/platform_ust_bar/04-entegrasyon-baslangici-ve-uygulama-sozlesmesi.md`:71** — [kavram] Metin `App::button_layout()` der; kaynakta cagri `cx.button_layout()` (App uzerinde) ve trait tarafinda `Platform::button_layout()` olarak gecer. 05. bolum satir 137-139 bu ayrimi 'Platform::button_layout() trait varsayilani' ve 'cx.button_layout()' olarak dogru kurar. 04'te yalnizca 'App::button_layout()' denmesi teknik olarak yanlis degil ama 05 ile yazim tutarsizligi var; ayni kavram farkli on eklerle aniliyor.
  - Alıntı: `Buna karşılık `WindowButtonLayout` port kurgusu değil, doğrudan `gpui` tipidir ve `App::button_layout()` ile alınır.`
  - Öneri: Tutarlilik icin 04 ve 05'te ayni gosterimi kullanin (or. her yerde `cx.button_layout()` / `Platform::button_layout()` ayrimini ayni bicimde verin).

## src/ust_bar/

**Özet:** Klasor genel olarak yuksek kaliteli, iyi kurgulanmis ve kaynakla buyuk olcude dogru. Kaynak (zed/crates/title_bar) ile karsilastirilan tum davranis/sabit/dize iddialari (MAX_*_LENGTH degerleri, 'Create Branch'/'Disconnected'/'Restricted Mode' dizeleri, pulsating_between(0.4,0.8) ve 2 sn animasyon, 'Update to Version:' kalibi, effective_active_worktree mantigi, re-export listesi, eylem ad alanlari) dogru cikti. En kritik sorunlar: (1) 04, 07 ve 08 dosyalarindaki kod bloklarinin eski GPUI API adlarini (ViewContext, ModelContext, AppContext, View, Model) kullanmasi ve bunlarin hem guncel kaynak hem de kitabin 02/03 bolumlerindeki dogru 'Entity/Context<Self>/Window' kullanimiyla celismesi; (2) 05. dosya 62. satirindaki kirik ic baglanti (Turkce 'çocuk' yerine 'child' iceren capa); (3) birkac iyelik eki/yazim hatasi (ust_bar.md 'yığına', 07 'yığın', 07 'önekesi', 06 baslik 'paylaşimi'); (4) bir gereksiz anglisizm (06 'asenkron' -> 'eşzamansız'). Anlam/mantik duzeyinde ciddi bir hata bulunmadi; tum bulgular yazim, API tutarliligi ve baglanti duzeyinde.

**Klasör içi bütünlük:** Klasor genel olarak iyi yapilandirilmis ve tutarli bir akisa sahip. Dizin dosyasi (ust_bar.md) bolumleri dogru sirada listeliyor; numarali dosyalar (01-08) mantikli bir ilerleme izliyor: hedef/lisans -> kaynak haritasi/kopru -> TitleBar entity ve render -> ayarlar/menu -> sol grup gostergeleri -> isbirligi -> sag grup (kullanici/plan/guncelleme/bant) -> pratik/dogrulama. Her bolum, kitabin baslangicta vaat ettigi 'ne ise yarar / TitleBar icinde nasil kurulur / port karsiligi nasil olmali' uclu kalibini tutarli uyguluyor; bu, konu butunlugu acisindan guclu. Bolumler arasi gondermeler (3. ve 7. bolume yapilanlar) cogunlukla dogru. En belirgin kopukluk, 08. dosyadaki ornek kodun eski GPUI tiplerini (View/Model/ViewContext) kullanmasi; bu, 02/03 bolumlerinin guncel 'Entity/Context<Self>' kullanimiyla celisip okurda hangi API'nin gecerli oldugu konusunda kafa karisikligi yaratiyor. 04 ve 07 dosyalarindaki kod bloklari da ayni eski API sorununu tasiyor. Tekrar/cakisma sorunu kabul edilebilir duzeyde: render iki modu (03) ile pratik iskelet (08) ve dogrulama listesi (08) arasinda bilincli pekistirme var, fazlalik gurultu degil. Tek kirik ic baglanti 05. dosyada (Turkce 'çocuk' yerine 'child' iceren capa).

### Yüksek öncelik (1)

- **`src/ust_bar/05-proje-branch-host-restricted.md`:62** — [konu_butunlugu] Kirik ic baglanti. 3. bolumdeki baslik '## 3. Render: cocuk grubunun hazirlanmasi' oldugu icin GitHub/mdBook capasi '#3-render-çocuk-grubunun-hazırlanması' olur. Baglantida Turkce 'çocuk' yerine Ingilizce 'child' kullanildigindan capa hicbir basliga denk gelmez ve link kirik calisir. Ayni bolume yapilan diger gondermeler (04 ve 08 dosyalarinda '#4-i̇ki-render-...') dogru bicimdedir; bu yalniz buradaki link hatali.
  - Alıntı: `[3. bölümde](03-titlebar-entity-ve-render.md#3-render-child-grubunun-hazırlanması)`
  - Öneri: Capayi gercek baslikla esitle: '#3-render-çocuk-grubunun-hazırlanması'.

### Orta öncelik (3)

- **`src/ust_bar/04-ayarlar-ve-uygulama-menusu.md`:63-66** — [kavram] Kod blogundaki imzalar guncel GPUI/kaynak ile celisiyor. Gercek kaynakta tip 'Context<Self>' ve fonksiyonlar ek bir 'window: &mut Window' parametresi aliyor (or. ApplicationMenu::new(_: &mut Window, cx: &mut Context<Self>); open_menu(&mut self, action, _window: &mut Window, _cx: &mut Context<Self>)). Kitabin 02 ve 03 bolumleri zaten dogru sekilde 'Entity'/'Context<Self>'/'Window' kullaniyor; bu dosyadaki eski 'ViewContext' adlandirmasi hem kaynakla hem kitabin geri kalaniyla tutarsiz.
  - Alıntı: `pub fn new(cx: &mut ViewContext<Self>) -> Self ... pub fn open_menu(&mut self, action: &OpenApplicationMenu, cx: &mut ViewContext<Self>)`
  - Öneri: Imzalari guncel API'ye gore duzelt: 'ViewContext<Self>' -> 'Context<Self>' ve eksik 'window: &mut Window' parametresini ekle (new, open_menu, navigate_menus_in_direction, all_menus_shown icin).

- **`src/ust_bar/07-kullanici-update-banner.md`:14-15, 78-83** — [kavram] Kod bloklarindaki context tipleri kaynakla celisiyor. Gercekte: render_sign_in_button/render_user_menu_button '&mut Context<Self>' alir; OnboardingBanner::new '&mut Context<Self>'; visible_when predicate 'impl Fn(&mut App) -> bool'; restore_banner 'cx: &mut App'. Belge eski 'ViewContext<Self>', 'ModelContext<'_, Self>' ve 'AppContext' adlarini kullaniyor. Bu, kitabin 02/03 bolumlerindeki dogru 'Context<Self>'/'App' kullanimiyla da tutarsiz.
  - Alıntı: `pub fn render_sign_in_button(&mut self, _: &mut ViewContext<Self>) -> Button ... predicate: impl Fn(&mut ModelContext<'_, Self>) -> bool ... pub fn restore_banner(cx: &mut AppContext)`
  - Öneri: 'ViewContext<Self>' -> 'Context<Self>', 'ModelContext<'_, Self>' -> 'App', 'AppContext' -> 'App' olarak duzelt; gerekli yerlerde 'window: &mut Window' parametresini ekle.

- **`src/ust_bar/08-pratik-uygulama-ve-dogrulama.md`:11-18** — [kavram] Iskelet kod blogu artik var olmayan eski GPUI tiplerini kullaniyor: 'View<...>', 'Model<...>', 'ViewContext<Self>'. Guncel GPUI'de bunlarin yerine 'Entity<...>' ve 'Context<Self>' vardir; Render::render imzasi da 'fn render(&mut self, window: &mut Window, cx: &mut Context<Self>)' bicimindedir (window parametresi eksik). Kitabin 02 ve 03 bolumlerindeki ornek iskeletler dogru sekilde 'Entity'/'Context<Self>'/'window' kullaniyor; bu dosya onlarla celisiyor (bolum ici terim/API tutarsizligi).
  - Alıntı: `platform_kabugu: View<PlatformTitleBar>, proje_durumu: Model<ProjeDurumu>, ... fn render(&mut self, cx: &mut ViewContext<Self>) -> impl IntoElement`
  - Öneri: 'View<...>' ve 'Model<...>' -> 'Entity<...>'; 'ViewContext<Self>' -> 'Context<Self>'; render imzasina 'window: &mut Window' ekle. 02/03'teki iskeletle birebir ayni API'yi kullan.

### Düşük öncelik (8)

- **`src/ust_bar/ust_bar.md`:3** — [anlatim] Iyelik eki eksik yazim hatasi. 'Zed'in ... hesap yığına' tamlamasinda iyelik eki dusmus; dogrusu 'hesap yığınına'. Ayni kavram 01-hedef dosyasinin 33. satirinda dogru bicimde 'yığınına' geciyor.
  - Alıntı: `Zed'in işbirliği ve hesap yığına doğrudan bağımlıdır`
  - Öneri: 'hesap yığına' -> 'hesap yığınına' olarak duzelt.

- **`src/ust_bar/07-kullanici-update-banner.md`:65** — [anlatim] Iyelik eki eksik yazim hatasi. 'güncelleme yığın varsa' yerine 'güncelleme yığını varsa' olmalidir.
  - Alıntı: `Port hedefinde bir otomatik güncelleme yığın varsa aynı durum makinesi kurulur`
  - Öneri: 'güncelleme yığın varsa' -> 'güncelleme yığını varsa'.

- **`src/ust_bar/07-kullanici-update-banner.md`:86** — [anlatim] Yazim hatasi. Turkce 'önek' kelimesinin 3. tekil iyelik hali 'öneki'dir; 'önekesi' yanlistir.
  - Alıntı: `varsayılan olarak `"Introducing:"` önekesi kullanılır`
  - Öneri: 'önekesi' -> 'öneki' olarak duzelt.

- **`src/ust_bar/06-collab-ve-ekran-paylasimi.md`:1** — [anlatim] Baslikta yazim hatasi: 'paylaşimi' -> 'paylaşımı' (kalin unlu 'ı' gerekir). Ayni dosyanin 51 ve 53. satirlari ile dosya adi (paylasimi) disindaki govde metni dogru sekilde 'paylaşımı' kullaniyor; yalniz H1 basligi hatali. Baslik-icerik yazim tutarsizligi.
  - Alıntı: `# İşbirliği ve ekran paylaşimi kontrolleri`
  - Öneri: Basligi 'İşbirliği ve ekran paylaşımı kontrolleri' olarak duzelt.

- **`src/ust_bar/06-collab-ve-ekran-paylasimi.md`:23** — [anlatim] Gereksiz anglisizm. Turkce dogal karsiligi olan 'eşzamansız' varken 'asenkron' birakilmis. Kullanicinin anglisizm yasagi kuralina gore isaretlenmistir (kod tanimlayicisi degil, duz anlatim).
  - Alıntı: `Paylaşım başlatma asenkron bir görevle yapılır`
  - Öneri: 'asenkron bir görevle' -> 'eşzamansız bir görevle'.

- **`src/ust_bar/02-kaynak-haritasi-ve-kopru.md`:21** — [anlatim] Cifte 'de' baglaci nedeniyle dusuk/fazlalik anlatim. 'hem ... hem de ...' yapisindan sonra ayrica 'üzerinden de alabilir' denmesi gereksiz tekrardir; ayrica 'alabilir' oznesi (tuketiciler, cogul) ile uyumlu olsa da cumle bulanik.
  - Alıntı: `Zed içindeki tüketiciler hem platform sekmesi eylemlerini hem de `PlatformTitleBar` tipini `title_bar` üzerinden de alabilir`
  - Öneri: '... `title_bar` üzerinden alabilir.' bicimine indir; cumledeki ikinci 'de'yi kaldir.

- **`src/ust_bar/02-kaynak-haritasi-ve-kopru.md`:12, 50** — [kavram] Ayni kavram (otomatik guncelleme durumlari) icin bolum genelinde tutarsiz yazim. 02. bolum 12. satir bu durumlari kucuk harfle gayriresmi listeler (checking, downloading...); 07. bolum ve kaynak ise dogru sekilde 'AutoUpdateStatus' enum varyantlarini PascalCase yazar (Checking, Downloading...). Kucuk harfli liste bunlarin enum varyantlari oldugunu gizliyor.
  - Alıntı: `checking, downloading, installing, updated, errored ... `Checking` | Yalnızca manuel kontrolde`
  - Öneri: 02. bolumdeki listeyi de kaynakla ve 07. bolumle tutarli olacak sekilde PascalCase yaz: 'Checking, Downloading, Installing, Updated, Errored'.

- **`src/ust_bar/03-titlebar-entity-ve-render.md`:66** — [kavram] Terim tutarsizligi: 'popover' karsiligi kitap genelinde tutarli sekilde 'açılır panel' olarak kullanilirken (04/05/06/07 bolumleri), burada ayni 'popover' kavrami 'açılır menü' diye geciyor. Ayrica 06. bolum 49. satirda 'açılır menülü buton' ifadesi de bu ikiligi pekistiriyor.
  - Alıntı: `ekran paylaşımı açılır menüsünü süren `screen_share_popover_handle``
  - Öneri: Tutarlilik icin 'açılır menüsünü' -> 'açılır panelini' (ekran paylasimi popover'i icin) olarak hizala; 'popover' = 'açılır panel' karsiligini bolum boyunca koru.

