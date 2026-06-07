# Ses ve diğer binary varlıklar

Bu bölüm, varlık altyapısının daha az anılan ama son derece önemli iki tüketicisini ele almaktadır: `sounds/` klasöründeki WAV dosyalarını işleyen ses hattı ve `prompts/` klasöründeki Handlebars şablonlarını yükleyen prompt üreticisi. Her iki sistem de aynı `AssetSource` yüzeyini paylaşmakla birlikte, birbirlerinden oldukça farklı yaşam döngülerine sahiptir. Ses dosyaları talep anında senkron olarak yüklenir ve decode edilmiş şekilde önbelleğe (cache) alınır. Prompt şablonları ise uygulama başlangıcında topluca yüklenir ve dosya sistemi üzerinden geçersiz kılınabilir. Bu farkın netleştirilmesi, 'neden ses yükleme işlemi asenkron yürütülmezken prompt'lar bir dosya izleyici ile takip ediliyor?' gibi soruları yanıtlar.

---

## 1. `sounds/` klasörü ve `Sound` enum'u

Zed sekiz adet WAV dosyasını gömülü olarak taşır:

```text
assets/sounds/
├── agent_done.wav
├── guest_joined_call.wav
├── joined_call.wav
├── leave_call.wav
├── mute.wav
├── start_screenshare.wav
├── stop_screenshare.wav
└── unmute.wav
```

Her dosya `audio` crate'indeki `Sound` enum'unun bir varyantı ile eşleşir:

```rust
#[derive(Debug, Copy, Clone, Eq, Hash, PartialEq)]
pub enum Sound {
    Joined,
    GuestJoined,
    Leave,
    Mute,
    Unmute,
    StartScreenshare,
    StopScreenshare,
    AgentDone,
}

impl Sound {
    fn file(&self) -> &'static str {
        match self {
            Self::Joined => "joined_call",
            Self::GuestJoined => "guest_joined_call",
            Self::Leave => "leave_call",
            Self::Mute => "mute",
            Self::Unmute => "unmute",
            Self::StartScreenshare => "start_screenshare",
            Self::StopScreenshare => "stop_screenshare",
            Self::AgentDone => "agent_done",
        }
    }
}
```

İkonlardaki `strum` türetiminin aksine `Sound::file` metodu manuel olarak yazılır. Bu bilinçli bir tasarım kararıdır: dosya adları, enum varyant adından farklı snake_case dönüşümlere sahip olabilir (`Joined` → `joined_call`). `strum` ile otomatik dönüşüm uygulansaydı, isimler `joined` veya `joined_call` arasında tutarsızlık gösterebilirdi; manuel eşleştirme yöntemi ise adlandırma üzerinde tam denetim sağlar.

**Sözleşme:** Her `Sound` varyantı için `assets/sounds/<file()>.wav` dosyasının bulunması zorunludur. `Audio::play_sound` dönüşü `()`'dir ve bir hata döndürmez; dosya yoksa ses kaynağı oluşturma adımı `with_context` ile bir hata mesajı üretir, bu hata `play_sound` içinde `.log_err()` ile log'a düşürülür. Uygulama çökmez, yalnızca o ses çalmaz.

---

## 2. `Audio::play_sound` ve senkron yükleme

`audio` crate'indeki ses hattı, varlık yüklemeyi rodio decoder'ı ile birlikte ele alır:

```rust
pub fn play_sound(sound: Sound, cx: &mut App) {
    let cikis_ses_cihazi = AudioSettings::get_global(cx).output_audio_device.clone();
    cx.update_default_global(|this: &mut Self, cx| {
        let kaynak = this.sound_source(sound, cx).log_err()?;
        let cikis_karistirici = this
            .ensure_output_exists(cikis_ses_cihazi)
            .context("Çıkış karıştırıcısı alınamadı")
            .log_err()?;

        cikis_karistirici.add(kaynak);
        Some(())
    });
}

fn sound_source(&mut self, sound: Sound, cx: &App) -> Result<impl Source + use<>> {
    if let Some(wav) = self.source_cache.get(&sound) {
        return Ok(wav.clone());
    }

    let yol = format!("sounds/{}.wav", sound.file());
    let baytlar = cx
        .asset_source()
        .load(&yol)?
        .map(anyhow::Ok)
        .with_context(|| format!("Bu yol için varlık yok: {yol}"))??
        .into_owned();
    let imlec = Cursor::new(baytlar);
    let kaynak = Decoder::new(imlec)?.buffered();

    self.source_cache.insert(sound, kaynak.clone());

    Ok(kaynak)
}
```

Akış altı adımdadır:

1. **Cache araması.** `source_cache: HashMap<Sound, Buffered<Decoder<Cursor<Vec<u8>>>>>` haritası, her sesin decode edilmiş halini tutar. İlk çağrı bu cache'i doldurur, sonraki çağrılar doğrudan oradan okur.
2. **Yol inşası.** `format!("sounds/{}.wav", sound.file())` ile yol üretilir. Dinamik string olduğu için her seferinde küçük bir tahsis vardır; ses çalma sıklığı düşük olduğundan bu maliyet göz ardı edilebilir.
3. **`cx.asset_source().load(&yol)` senkron çağrısı:** `?` operatörü öncelikle `Result<Option<Cow>>` sonucunu çözer. Gerçek `Assets` kaynağında eksik yollar zaten doğrudan `Err` olarak döndürülür; boş `()` veya `Ok(None)` döndüren özel kaynaklarda ise `with_context` ikinci aşamada `Bu yol için varlık yok: ...` hata mesajını üretir. Her iki durumda da hata `play_sound` içinde log'a düşer ve uygulama kesintiye uğramadan çalışmaya devam eder.
4. **`into_owned()` metodu:** `Cow<'static, [u8]>` yapısı `Vec<u8>` haline getirilir. `RustEmbed`'in döndürdüğü Cow verisi derleme (build) türüne bağlıdır: release derlemesinde byte'lar binary içerisine gömüldüğünden `Cow::Borrowed` dönerken, debug derlemesinde (rust-embed `debug-embed` özelliği kapalı ise içerik dosya sisteminden dinamik okunduğu için) `Cow::Owned` döner. Her iki senaryoda da `rodio::Decoder` doğrudan bir `Vec` talep ettiği için `into_owned()` çağrısı gerçekleştirilir.
5. **`Decoder::new(cursor)?`:** WAV dosyası decode edilir. Format hatası bulunması durumunda hata `?` ile yukarı fırlatılır ve `play_sound` kapsamında log kaydına yansıtılır.
6. **`buffered()` çağrısı.** Decode edilmiş ses örnekleri buffer'lanır; aynı kaynak birden fazla mixer'a verilebilir hale gelir.

**Önemli karar:** Varlık yükleme işlemi asenkron yerine **senkron** olarak yürütülür. Bunun arkasında üç temel gerekçe yer alır:

- WAV dosyaları küçüktür (10-100 KB civarı); binary'den okuma maliyeti milisaniyenin altındadır.
- Ses çalma çağrıları genellikle kullanıcı arayüzü olaylarından tetiklenir (örneğin 'çağrıya katıl' butonuna tıklandığında). Bu tür olayların işlenmesi sırasında asenkron beklemenin pratik bir getirisi bulunmaz.
- Cache mekanizması sayesinde her ses ömür boyu en fazla bir kez decode edilir; sonraki çağrılarda yükleme adımı atlanır.

---

## 3. Kaynak cache davranışı

`source_cache` haritası `Audio` hattının yaşam süresi boyunca durur. Bu, ses dosyalarının `App` global durumunda tutulması anlamına gelir; uygulamanın bilinçli olarak belleğinde kalıcı bir alan ayrılır.

Maliyet hesabı: Sekiz WAV dosyasının decode edilmiş hali en fazla birkaç MB. Bu, modern bir desktop uygulamasında ihmal edilebilir bir bellektir. Buna karşılık, her ses çalmada decode etmek hem CPU hem gecikme tarafında gözle görülür bir bekleme yaratır. Cache'leme açık bir ödünleşimdir.

**Idempotency:** `sound_source` aynı `Sound` için ikinci kez çağrıldığında `Buffered<...>::clone()` döner. `Buffered` rodio'nun source'unun referans sayan bir wrapper'ıdır; clone maliyeti düşüktür ve örnek verisi paylaşılır.

---

## 4. Sound enum'unu genişletmek

Yeni bir ses eklemek için izlenmesi gereken adımlar:

1. `assets/sounds/yeni_ses.wav` dosyasını oluşturman veya eklemen gerekir.
2. `Sound` enum'una `YeniSes` varyantını ekleyebilirsin.
3. `Sound::file` `match` koluna `Self::YeniSes => "yeni_ses"` satırını eklemen gerekir.
4. UI kodunda `Audio::play_sound(Sound::YeniSes, cx)` ile tetikleyebilirsin.

Bu akışta dikkat edilmesi gereken durumlar şunlardır:

- Dosya yok ama enum varyantı eklendi: ilk çağrıda `Assets::load` veya `with_context` kaynaklı hata log'a düşer, ses çalmaz.
- `Sound::file` güncellenmedi: derleme zamanı hatası verir (`match` exhaustive değildir).
- Varyant yok ama dosya var: dosya varlık kümesine dahil kalır ama çağrı yolu yoktur; release'te binary boyutunu büyüten ölü varlık olarak durur.

Derleme zamanı kontrolünün yalnızca `Sound::file` `match` kapsayıcılığı üzerinden sağlandığına dikkat edilmelidir; dosyanın fiziksel varlığı çalışma zamanına kadar doğrulanmaz. Bu davranış modeli, varlık hattının tipik bir karakteristiğidir: tip sistemi enum varlığını garanti altına alırken, dosyanın varlığını denetleyemez.

---

## 5. `prompts/` klasörü ve Handlebars şablonları

İkinci tüketici grubu, AI prompt şablonlarıdır:

```text
assets/prompts/
├── content_prompt.hbs
├── content_prompt_v2.hbs
└── terminal_assistant_prompt.hbs
```

`.hbs` uzantısı [Handlebars](https://handlebarsjs.com/) şablon dilini gösterir. Bu şablonlar AI asistanının kullanıcıya veya modele gönderdiği prompt'ların gövdesini üretir; çalışma zamanında değişkenler doldurulur ve string üretilir.

`PromptBuilder` (içerisinde `Arc<Mutex<Handlebars<'static>>>` barındırır) bu şablonları `Assets` üzerinden okup uygulama başlatma esnasında Handlebars motoruna kaydeder. Release/debug-embed derlemelerinde şablon byte'ları binary içerisinden çekilirken, normal debug derlemelerinde aynı `Assets` API'si dosya sisteminden okuma gerçekleştirir. Sistem aynı zamanda dosya sistemindeki geçersiz kılma (override) klasörünü de izler; böylece kullanıcıların kendi özel şablonlarını yazabilmelerine imkan tanınır.

### 5.1 `register_built_in_templates`

```rust
fn register_built_in_templates(sablon_motoru: &mut Handlebars) -> Result<()> {
    for yol in Assets.list("prompts")? {
        if let Some(kimlik) = yol
            .split('/')
            .next_back()
            .and_then(|parca| parca.strip_suffix(".hbs"))
            && let Some(sablon) = Assets.load(yol.as_ref()).log_err().flatten()
        {
            log::debug!("Yerleşik prompt şablonu kaydediliyor: {}", kimlik);
            let sablon = String::from_utf8_lossy(sablon.as_ref());
            sablon_motoru.register_template_string(kimlik, LineEnding::normalize_cow(sablon))?
        }
    }
    Ok(())
}
```

Beş ayrıntı önemlidir:

- **`Assets.list("prompts")`** — `AssetSource::list` çağrısı; `prompts/content_prompt.hbs` gibi tüm yolları döner.
- **`yol.split('/').next_back().and_then(|parca| parca.strip_suffix(".hbs"))`:** Dosya yolunun son segmentinden dosya uzantısını çıkararak şablon kimliğini (template id) üretir. Örneğin `prompts/content_prompt_v2.hbs` yolu `content_prompt_v2` kimliğine dönüştürülür. Bu kimlikler ilerleyen süreçte `sablon_motoru.render("content_prompt_v2", &baglam)` çağrılarında kullanılır.
- **`String::from_utf8_lossy`** — Şablon byte'ları string'e çevrilirken UTF-8 hataları replacement character'a dönüşür. Bozuk encoding render'ı durdurmaz; sadece o bölüm okunaksız hale gelir.
- **`LineEnding::normalize_cow`:** Windows ortamında üretilmiş şablonlar CRLF (`\r\n`) içerebilir; ancak Handlebars motoru LF (`\n`) satır sonu formatı bekler. Bu tip `text` crate'i bünyesinde yer alır (`use text::LineEnding;`); `text::LineEnding::normalize_cow` işlevi satır sonlarını `\n` formatına dönüştürür. Sadece `\r\n` değil, tek başına duran `\r` satır sonları da `\n` formatına normalize edilir. `Cow` döndürüldüğü için zaten LF formatına sahip olan içerikler üzerinde gereksiz kopyalama yapılmaz.
- **`Assets.load(yol.as_ref()).log_err().flatten()`** — `Assets` struct'ı doğrudan static metot olarak çağrılır; `cx.asset_source()` üzerinden değil. Bu, `PromptBuilder::new`'in `App` referansına ihtiyaç duymadan çalışabilmesini sağlar.

### 5.2 Dosya sistemi geçersiz kılma mekanizması

`watch_fs_for_template_overrides` kullanıcının `~/.config/zed/prompt_overrides/` (veya muadili) altındaki `.hbs` dosyalarını izler:

```rust
if let Ok(mut girdiler) = parametreler.fs.read_dir(&sablonlar_dizini).await {
    while let Some(Ok(dosya_yolu)) = girdiler.next().await {
        if dosya_yolu.to_string_lossy().ends_with(".hbs")
            && let Ok(icerik) = parametreler.fs.load(&dosya_yolu).await {
                let dosya_adi = dosya_yolu.file_stem()?.to_string_lossy();
                log::debug!("Prompt şablonu geçersiz kılması kaydediliyor: {}", dosya_adi);
                sablon_motoru.lock().register_template_string(&dosya_adi, icerik).log_err();
            }
    }
}
```

Geçersiz kılma mantığı Handlebars motorunun çakışan şablon kimliklerinde en son kayıt eden çağrının kazanması davranışına dayanır. Akış:

1. `register_built_in_templates` ile binary'deki şablonlar yüklenir.
2. Geçersiz kılma klasörü taranır; kullanıcı şablonları aynı kimliklerle yeniden kaydedilir.
3. Geçersiz kılma dosyası değiştiğinde dosya izleyicisi tetiklenir ve şablon yeniden kaydedilir.
4. Geçersiz kılma klasörü silinirse `register_built_in_templates` yeniden çağrılır ve binary şablonları geri yüklenir.

Bu davranış varlık altyapısının önemli bir desenini örnekler: **binary'deki varlık varsayılan, dosya sistemindeki varlık geçersiz kılmadır**. Aynı yaklaşım tema, keymap ve settings sistemlerinde de görünür (sonraki bölümde işlenir).

### 5.3 Handlebars motoruna eklenirken Asset yolu seçimi

Prompt yükleyici tek bir yerde `Assets` struct'ını doğrudan kullanır (`cx.asset_source()` değil). Bu kararın iki gerekçesi vardır:

- **Kuruluş sırası.** `PromptBuilder::new` `App` global durumu kurulmadan da çağrılabilir olmalıdır. `Assets` static iken `cx.asset_source()` çalışma zamanı bağımlıdır.
- **Kuruluş yüzeyi.** `prompt_store` crate'i `gpui` ve `assets` crate'lerine bağımlıdır; ancak yerleşik şablon okuma fonksiyonu `App` veya `Context` istemez. İzleyicili `PromptBuilder::load(..., cx)` yolu `gpui::App` kullanırken, `PromptBuilder::new(None)` yalnızca gömülü/varsayılan şablonları kaydedebilir.

Aynı varlık klasörüne iki ayrı arayüzden ulaşmak, hem `PromptBuilder::new(None)` gibi çalışma zamanından bağımsız kuruluşu hem de `PromptBuilder::load(..., cx)` gibi izleyicili entegrasyonu mümkün kılar.

---

## 6. `badge/` klasörü ve çalışma zamanı dışı tüketim

`assets/badge/v0.json` tek dosyalı küçük bir varlıktır:

```json
{
  "label": "",
  "message": "Zed",
  "logoSvg": "<svg ...>...</svg>",
  "logoWidth": 16,
  "labelColor": "black",
  "color": "white"
}
```

Bu dosya `Assets` struct'ının `#[include]` listesinde **yer almaz**; sadece `assets/` klasöründe durur. Tüketicisi shields.io API'sidir; README.md dosyasındaki rozet bu JSON'u çekip render eder:

```markdown
[![Zed](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/zed-industries/zed/main/assets/badge/v0.json)](https://zed.dev)
```

**Sonuç:** Klasör topolojisinin 'her dosya çalışma zamanı tüketicisidir' varsayımı her zaman geçerli olmayabilir. `badge/` örneği, varlık klasörünün dış (CI, README, dokümantasyon gibi) tüketim amaçlarına hizmet eden parçaları da barındırabileceğini göstermektedir. Bu tür dosyaların `RustEmbed` include kalıbının dışında bırakılması iki temel avantaj sağlar:

1. Binary boyutunun gereksiz yere şişmesi önlenir (dosya boyutu küçük olsa dahi).
2. Dosyanın yanlışlıkla çalışma zamanında okunması engellenir; böylece dosyanın tüketim yolu ya CI ya da bir dış servis olarak netleştirilmiş olur.

Genel olarak: varlık klasörüne dosya eklerken "bu dosya çalışma zamanında mı yoksa dış araç tarafından mı tüketilecek?" sorusu sorulmalıdır. İkinci durumda `#[include]` direktifi yazılmaz.

---

## 7. Üç tüketici karşılaştırması

Ses, prompt ve badge tüketicilerinin tüketim profillerini bir arada görmek faydalıdır:

| Tüketici | Yükleme zamanı | Yükleme şekli | Cache | Geçersiz kılma |
|----------|----------------|---------------|-------|----------|
| `Sound` | Talep anında (lazy) | Senkron `asset_source.load` | `HashMap<Sound, Buffered>` | Yok |
| `PromptBuilder` | Uygulama başlatma anında (eager) | `Assets.list` + `Assets.load` döngüsü | Handlebars motoru içindeki şablon haritası | Dosya sistemi izleyicisi ile aktif |
| `badge/v0.json` | Hiç (çalışma zamanında okunmaz) | - | - | - |

Bu üç desen birlikte değerlendirildiğinde varlık altyapısının esnekliği belirginleşir: Aynı `AssetSource` arayüzü kullanılarak hem talep anında hızlı ve hafif erişim, hem uygulama başlangıcında toplu yükleme, hem de tamamen çalışma zamanı dışı tüketim modelleri inşa edilebilir. Yeni bir varlık türü eklenirken en uygun profilın seçilmesi; 'ne sıklıkla yükleneceği, kaç kez okunacağı, kullanıcının bu varlığı geçersiz kılıp kılamayacağı' gibi soruların yanıtlarına göre şekillendirilir.

---

## 8. Pratik akış özeti

```text
Audio::play_sound(Sound::AgentDone, cx)
       │
       ▼ source_cache araması
       │   ├── BULUNDU → Buffered<Decoder>::clone
       │   └── YOK ↓
       ▼ format!("sounds/{}.wav", sound.file())
       ▼ cx.asset_source().load(&yol)
       ▼ rodio::Decoder::new(Cursor::new(baytlar))?.buffered()
       ▼ source_cache.insert(sound, kaynak)
       ▼ cikis_karistirici.add(kaynak)
       ▼ Cihaz seviyesinde mixing + DAC
```

```text
Uygulama başlangıcı ──► PromptBuilder::new
                   │
                   ▼ Assets.list("prompts")
                   ▼ Her .hbs için:
                         Assets.load(yol) → baytlar
                         String::from_utf8_lossy
                         LineEnding::normalize_cow
                         sablon_motoru.register_template_string(kimlik, sablon)
                   ▼ dosya sistemi izleyicisi başlatılır (geçersiz kılma için)
                   ▼ handlebars motoru hazır; render çağrıları beklenir
```

İki akış arasındaki temel fark, yaşam döngülerinde (lifecycle) yatmaktadır: ses her tetiklendiğinde döngünün başına döner; prompt şablonları ise yalnızca dosya sistemindeki geçersiz kılma dosyaları değiştiğinde yeniden kaydedilir. Hangi profilin seçileceği, varlık türünün kullanım sıklığına ve geçersiz kılınabilirlik gereksinimlerine göre belirlenir.

---
