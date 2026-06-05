# Ses ve diğer binary varlıklar

Bu bölüm, varlık altyapısının daha az anılan ama önemli iki tüketicisini ele alır: `sounds/` klasöründeki WAV dosyalarını besleyen ses hattı ve `prompts/` klasöründeki Handlebars şablonlarını yükleyen prompt üreticisi. İkisi de aynı `AssetSource` yüzeyini paylaşır fakat çok farklı yaşam döngüleri kurarsın. Ses dosyaları talep anında senkron yüklenir; decode edilmiş halde cache'lenir. Prompt şablonları uygulama başlangıcında topluca yüklenir; dosya sistemi üzerinden geçersiz kılınabilir. Bu farkı netleştirmek, "neden ses yükleme asenkron değil ama prompt'lar bir izleyici ile izleniyor?" gibi soruları cevaplar.

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

İkonlardaki `strum` türetmesinin aksine `Sound::file` manuel olarak yazılır. Bu bilinçli bir tasarım kararıdır: dosya adları enum varyant adından farklı snake_case dönüşümlere sahiptir (`Joined` → `joined_call`). `strum` ile otomatik dönüşüm yapılsaydı isimler `joined` veya `joined_call` arasında tutarsız olabilirdi; manuel eşleştirme adlandırmayı denetim altına alır.

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
2. **Yol inşası.** `format!("sounds/{}.wav", sound.file())` ile yol üretilir. Dinamik string olduğu için her seferinde küçük bir tahsis vardır; ses çalma sıklığı düşük olduğundan bu maliyet gözardı edilebilir.
3. **`cx.asset_source().load(&yol)` senkron çağrı.** `?` operatörü önce `Result<Option<Cow>>` sonucunu açar. Gerçek `Assets` kaynağında eksik yol zaten `Err` olarak döner; boş `()` veya `Ok(None)` döndüren özel kaynaklarda ise `with_context` ikinci aşamada `Bu yol için varlık yok: ...` mesajını üretir. Her iki durumda da hata `play_sound` içinde log'a düşer ve uygulama çalışmaya devam eder.
4. **`into_owned()`.** `Cow<'static, [u8]>` `Vec<u8>` haline getirilir. `RustEmbed`'in döndürdüğü Cow build türüne bağlıdır: release build'de byte'lar binary'ye gömülü olduğundan `Cow::Borrowed`, debug build'de ise (rust-embed `debug-embed` özelliği kapalı olduğu için içerik dosya sisteminden okunur) `Cow::Owned` döner. Her iki durumda da `rodio::Decoder` bir `Vec` istediği için `into_owned()` çağrılır.
5. **`Decoder::new(cursor)?`.** WAV dosyası decode edilir. Format hatası varsa `?` ile yukarı atılır ve `play_sound` log'a düşer.
6. **`buffered()` çağrısı.** Decode edilmiş ses örnekleri buffer'lanır; aynı kaynak birden fazla mixer'a verilebilir hale gelir.

**Önemli karar:** Varlık yükleme **senkron** yapılır, asenkron değildir. Üç gerekçe vardır:

- WAV dosyaları küçüktür (10-100 KB civarı); binary'den okuma maliyeti milisaniyenin altındadır.
- Ses çalma çağrısı genellikle UI olaylarından tetiklenir (örneğin "çağrıya katıl" butonuna basıldığında). Bu olayın işlenmesi sırasında asenkron beklemenin getirisi yoktur.
- Cache mekanizması sayesinde her ses ömür boyu en fazla bir kez decode edilir; sonraki çağrılarda yükleme adımı atlanır.

---

## 3. Kaynak cache davranışı

`source_cache` haritası `Audio` hattının yaşam süresi boyunca durur. Bu, ses dosyalarının `App` global durumunda tutulması anlamına gelir; uygulamanın belleğinde kalıcı bir alan ayrılır.

Maliyet hesabı: Sekiz WAV dosyasının decode edilmiş hali en fazla birkaç MB. Bu, modern bir desktop uygulamasında ihmal edilebilir bir bellektir. Buna karşılık, her ses çalmada decode etmek hem CPU hem gecikme tarafında gözle görülür bir bekleme yaratır. Cache'leme açık bir ödünleşimdir.

**Idempotency:** `sound_source` aynı `Sound` için ikinci kez çağrıldığında `Buffered<...>::clone()` döner. `Buffered` rodio'nun source'unun referans sayan bir wrapper'ıdır; clone maliyeti düşüktür ve örnek verisi paylaşılır.

---

## 4. Sound enum'unu genişletmek

Yeni bir ses eklemek için izlenmesi gereken adımlar:

1. `assets/sounds/yeni_ses.wav` dosyasını eklersin (ya da hangi snake_case ad uygunsa).
2. `Sound` enum'una `YeniSes` varyantı eklersin.
3. `Sound::file` `match` koluna `Self::YeniSes => "yeni_ses"` satırı eklersin.
4. UI kodunda `Audio::play_sound(Sound::YeniSes, cx)` ile tetiklersin.

Bu akışta dikkat edilmesi gereken durumlar şunlardır:

- Dosya yok ama enum varyantı eklendi: ilk çağrıda `Assets::load` veya `with_context` kaynaklı hata log'a düşer, ses çalmaz.
- `Sound::file` güncellenmedi: derleme zamanı hatası verir (`match` exhaustive değildir).
- Varyant yok ama dosya var: dosya varlık kümesine dahil kalır ama çağrı yolu yoktur; release'te binary boyutunu büyüten ölü varlık olarak durur.

Derleme zamanı kontrolünün yalnızca `Sound::file` `match` kapsayıcılığı üzerinden geçtiğine dikkat edersin; dosya varlığı çalışma zamanına kadar doğrulanmaz. Bu davranış, varlık hattının tipik bir karakteristiğidir: tip sistemi enum varlığını sağlar, dosya varlığını sağlamaz.

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

`PromptBuilder` (içinde `Arc<Mutex<Handlebars<'static>>>` tutar) bu şablonları `Assets` üzerinden okuyup uygulama başlatma sırasında handlebars motoruna kaydeder. Release/debug-embed build'de şablon byte'ları binary'den gelir; normal debug build'de aynı `Assets` API'si dosya sisteminden okur. Aynı zamanda dosya sistemindeki geçersiz kılma klasörünü izler; kullanıcı kendi şablonlarını yazabilir.

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
- **`yol.split('/').next_back().and_then(|parca| parca.strip_suffix(".hbs"))`** — Yolun son segmentinden uzantıyı çıkararak şablon kimliğini üretir. `prompts/content_prompt_v2.hbs` → `content_prompt_v2`. Bu kimlikleri ileride `sablon_motoru.render("content_prompt_v2", &baglam)` çağrılarında kullanırsın.
- **`String::from_utf8_lossy`** — Şablon byte'ları string'e çevrilirken UTF-8 hataları replacement character'a dönüşür. Bozuk encoding render'ı durdurmaz; sadece o bölüm okunaksız hale gelir.
- **`LineEnding::normalize_cow`** — Windows'ta üretilmiş şablonlar CRLF içerebilir; Handlebars motoru LF bekler. Tip `text` crate'inde durur (`use text::LineEnding;`); `text::LineEnding::normalize_cow` satır sonlarını `\n`'e çevirir. Yalnız `\r\n` değil, tek başına `\r` de `\n`'e normalize edilir. `Cow` döndüğü için zaten LF olan içerik ekstra kopyalanmaz.
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
3. Geçersiz kılma dosyası değişirse izleyici tetiklenir ve şablon tekrar kaydedilir.
4. Geçersiz kılma klasörü silinirse `register_built_in_templates` yeniden çağrılır ve binary şablonları geri yüklenir.

Bu davranış varlık altyapısının önemli bir desenini örnekler: **binary'deki varlık varsayılan, dosya sistemindeki varlık geçersiz kılmadır**. Aynı yaklaşım tema, keymap ve settings sistemlerinde de görünür (sonraki bölümde işlenir).

### 5.3 Handlebars motoruna eklenirken Asset yolu seçimi

Prompt yükleyici tek bir yerde `Assets` struct'ını doğrudan kullanır (`cx.asset_source()` değil). Bu kararın iki gerekçesi vardır:

- **Kuruluş sırası.** `PromptBuilder::new` `App` global durumu kurulmadan da çağrılabilir olmalıdır. `Assets` static iken `cx.asset_source()` çalışma zamanı bağımlıdır.
- **Kuruluş yüzeyi.** `prompt_store` crate'i `gpui` ve `assets` crate'lerine bağlıdır; ancak yerleşik şablon okuma fonksiyonu `App` veya `Context` istemez. İzleyicili `PromptBuilder::load(..., cx)` yolu `gpui::App` kullanırken, `PromptBuilder::new(None)` yalnızca gömülü/varsayılan şablonları kaydedebilir.

Bu desen ters yönde de geçerlidir: `prompt_store` crate'i hem `gpui`'ye (izleyiciyi background executor üzerinde başlatmak için) hem de `assets` crate'ine bağlıdır; yerleşik şablonları okurken `cx.asset_source()` yerine doğrudan `Assets` struct'ını kullanır. Aynı varlık klasörüne iki ayrı arayüzden ulaşmak, hem `PromptBuilder::new(None)` gibi çalışma zamanından bağımsız kuruluşu hem de `PromptBuilder::load(..., cx)` gibi izleyicili entegrasyonu mümkün kılar.

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

**Sonuç:** Klasör topolojisinin "her şey çalışma zamanı tüketicisidir" varsayımı her zaman geçerli değildir. `badge/` örneği, varlık klasörünün dış (CI, README, dokümantasyon) tüketim için kullanılan parçalarını da barındırabileceğini gösterir. Bu tür dosyaları `RustEmbed` include kalıbından dışarıda tutmak iki avantaj sağlar:

1. Binary boyutu şişmez (küçük de olsa).
2. Yanlışlıkla çalışma zamanından okunması mümkün olmaz; dosyanın tüketim yolu ya CI ya da dış servis olarak netleşir.

Genel olarak: varlık klasörüne dosya eklerken "bu dosya çalışma zamanında mı yoksa dış araç tarafından mı tüketilecek?" sorusu sorulmalıdır. İkinci durumda `#[include]` direktifi yazılmaz.

---

## 7. Üç tüketici karşılaştırması

Ses, prompt ve badge tüketicilerinin tüketim profillerini bir arada görmek faydalıdır:

| Tüketici | Yükleme zamanı | Yükleme şekli | Cache | Geçersiz kılma |
|----------|----------------|---------------|-------|----------|
| `Sound` | Talep anında (lazy) | Senkron `asset_source.load` | `HashMap<Sound, Buffered>` | Yok |
| `PromptBuilder` | Uygulama başlatma anında (eager) | `Assets.list` + `Assets.load` döngüsü | Handlebars motoru içindeki şablon haritası | Dosya sistemi izleyicisi ile aktif |
| `badge/v0.json` | Hiç (çalışma zamanında okunmaz) | - | - | - |

Üç desen birlikte değerlendirildiğinde varlık altyapısının esnekliği belirginleşir: Aynı `AssetSource` arayüzünden hem talep anında ucuz erişim, hem uygulama başlatma sırasında topluca yükleme, hem de tamamen çalışma zamanı dışı tüketim modelleri kurulabilir. Yeni bir varlık türü eklerken doğru profil seçimi, "ne sıklıkla yüklenecek, kaç kez okunacak, kullanıcı geçersiz kılabilmeli mi?" sorularıyla yaparsın.

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

İki akış arasındaki temel fark, yaşam döngüsündedir: ses her tetiklendiğinde döngünün üst tarafına döner; prompt ise yalnızca dosya sistemi geçersiz kılma dosyası değiştiğinde yeniden kaydedilir. Hangi profilin seçileceği varlık türünün kullanım sıklığı ve geçersiz kılma gereksinimine göre belirlersin.

---
