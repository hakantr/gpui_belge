# Ses ve diğer binary varlıklar

Bu bölüm, asset altyapısının daha az anılan ama önemli iki tüketicisini ele alır: `sounds/` klasöründeki WAV dosyalarını besleyen ses pipeline'ı ve `prompts/` klasöründeki Handlebars şablonlarını yükleyen prompt builder. İkisi de aynı `AssetSource` yüzeyini paylaşır fakat çok farklı yaşam döngüleri kurarsın. Ses dosyaları talep anında senkron yüklenir; decode'lanmış halde cache'lenir. Prompt şablonları uygulama başlangıcında topluca yüklenir; filesystem üzerinden override edilebilir. Bu farkı netleştirmek, "neden ses yükleme async değil ama prompt'lar bir watcher ile izleniyor?" gibi soruları cevaplar.

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

Her dosya `crates/audio/src/audio.rs` içindeki `Sound` enum'unun bir varyantı ile eşleşir:

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

**Sözleşme:** Her `Sound` varyantı için `assets/sounds/<file()>.wav` dosyasının bulunması zorunludur. Aksi halde `Audio::play_sound` çağrısı runtime'da `bail!` ile hata döner ve hata log'a düşer; uygulama çökmez ama o ses çalmaz.

---

## 2. `Audio::play_sound` ve senkron yükleme

`crates/audio/src/audio_pipeline.rs` içindeki ses pipeline'ı, asset yüklemeyi rodio decoder'ı ile birlikte ele alır:

```rust
pub fn play_sound(sound: Sound, cx: &mut App) {
    let output_audio_device = AudioSettings::get_global(cx).output_audio_device.clone();
    cx.update_default_global(|this: &mut Self, cx| {
        let source = this.sound_source(sound, cx).log_err()?;
        let output_mixer = this
            .ensure_output_exists(output_audio_device)
            .context("Could not get output mixer")
            .log_err()?;

        output_mixer.add(source);
        Some(())
    });
}

fn sound_source(&mut self, sound: Sound, cx: &App) -> Result<impl Source + use<>> {
    if let Some(wav) = self.source_cache.get(&sound) {
        return Ok(wav.clone());
    }

    let path = format!("sounds/{}.wav", sound.file());
    let bytes = cx
        .asset_source()
        .load(&path)?
        .map(anyhow::Ok)
        .with_context(|| format!("No asset available for path {path}"))??
        .into_owned();
    let cursor = Cursor::new(bytes);
    let source = Decoder::new(cursor)?.buffered();

    self.source_cache.insert(sound, source.clone());

    Ok(source)
}
```

Akış altı adımdadır:

1. **Cache lookup.** `source_cache: HashMap<Sound, Buffered<Decoder<Cursor<Vec<u8>>>>>` haritası, her sesin decode edilmiş halini tutar. İlk çağrı bu cache'i doldurur, sonraki çağrılar doğrudan oradan okur.
2. **Path inşası.** `format!("sounds/{}.wav", sound.file())` ile path üretilir. Dinamik string olduğu için her seferinde küçük bir tahsis vardır; ses çalma sıklığı düşük olduğundan bu maliyet gözardı edilebilir.
3. **`cx.asset_source().load(&path)` senkron çağrı.** `?` operatörü önce `Result<Option<Cow>>` sonucunu açar. Gerçek `Assets` kaynağında eksik path zaten `Err` olarak döner; boş `()` veya `Ok(None)` döndüren custom kaynaklarda ise `with_context` ikinci aşamada `No asset available for path ...` mesajını üretir. Her iki durumda da hata `play_sound` içinde log'a düşer ve uygulama çalışmaya devam eder.
4. **`into_owned()`.** `Cow<'static, [u8]>` `Vec<u8>` haline getirilir. `RustEmbed`'in döndürdüğü `Cow::Borrowed` zaten 'static yaşam süresinde olsa da `rodio::Decoder` Vec ister.
5. **`Decoder::new(cursor)?`.** WAV dosyası decode edilir. Format hatası varsa `?` ile yukarı atılır ve `play_sound` log'a düşer.
6. **`buffered()` çağrısı.** Decode edilmiş ses örnekleri buffer'lanır; aynı kaynak birden fazla mixer'a verilebilir hale gelir.

**Önemli karar:** Asset yükleme **senkron** yapılır, async değildir. Üç gerekçe vardır:

- WAV dosyaları küçüktür (10-100 KB civarı); binary'den okuma maliyeti milisaniyenin altındadır.
- Ses çalma çağrısı genellikle UI event'lerinden tetiklenir (örneğin "join call" butonuna basıldığında). Bu event'in işlenmesi sırasında async beklemenin getirisi yoktur.
- Cache mekanizması sayesinde her ses ömür boyu en fazla bir kez decode edilir; sonraki çağrılarda yükleme adımı atlanır.

---

## 3. Source cache davranışı

`source_cache` haritası `Audio` pipeline'ının yaşam süresi boyunca durur. Bu, ses dosyalarının `App` global state'inde tutulması anlamına gelir; uygulamanın belleğinde kalıcı bir alan ayrılır.

Maliyet hesabı: Sekiz WAV dosyasının decode edilmiş hali en fazla birkaç MB. Bu, modern bir desktop uygulamasında ihmal edilebilir bir bellektir. Buna karşılık, her ses çalmada decode etmek hem CPU hem latency tarafında gözle görülür bir gecikme yaratır. Cache'leme açık bir trade-off'tur.

**Idempotency:** `sound_source` aynı `Sound` için ikinci kez çağrıldığında `Buffered<...>::clone()` döner. `Buffered` rodio'nun source'unun referans sayan bir wrapper'ıdır; clone maliyeti düşüktür ve örnek verisi paylaşılır.

---

## 4. Sound enum'unu genişletmek

Yeni bir ses eklemek için izlenmesi gereken adımlar:

1. `assets/sounds/yeni_ses.wav` dosyası eklenir (ya da hangi snake_case ad uygunsa).
2. `Sound` enum'una `YeniSes` varyantı eklersin.
3. `Sound::file` `match` koluna `Self::YeniSes => "yeni_ses"` satırı eklersin.
4. UI kodunda `Audio::play_sound(Sound::YeniSes, cx)` ile tetiklersin.

Adımlardan herhangi biri eksikse uyarı verir:

- Dosya yok ama enum varyantı eklendi: ilk çağrıda `Assets::load` veya `with_context` kaynaklı hata log'a düşer, ses çalmaz.
- `Sound::file` güncellenmedi: derleme zamanı hatası verir (`match` exhaustive değildir).
- Varyant yok ama dosya var: dosya asset kümesine dahil kalır ama çağrı yolu yoktur; release'te binary boyutunu büyüten ölü asset olarak durur.

Derleme zamanı kontrolünün yalnızca `Sound::file` match exhaustiveness üzerinden geçtiğine dikkat etmek gerekir; dosya varlığı runtime'a kadar doğrulanmaz. Bu davranış, asset boru hattının tipik bir karakteristiğidir: tip sistemi enum varlığını sağlar, dosya varlığını sağlamaz.

---

## 5. `prompts/` klasörü ve Handlebars şablonları

İkinci tüketici grubu, AI prompt şablonlarıdır:

```text
assets/prompts/
├── content_prompt.hbs
├── content_prompt_v2.hbs
└── terminal_assistant_prompt.hbs
```

`.hbs` uzantısı [Handlebars](https://handlebarsjs.com/) şablon dilini gösterir. Bu şablonlar AI assistantın kullanıcıya veya model'e gönderdiği prompt'ların gövdesini üretir; runtime'da değişkenler doldurulur ve string üretilir.

`PromptBuilder` (içinde `Arc<Mutex<Handlebars<'static>>>` tutar) bu şablonları `Assets` üzerinden okuyup uygulama başlatma sırasında handlebars motoruna kaydeder. Release/debug-embed build'de şablon byte'ları binary'den gelir; normal debug build'de aynı `Assets` API'si filesystem'den okur. Aynı zamanda filesystem'deki override klasörünü izler; kullanıcı kendi şablonlarını yazabilir.

### 5.1 `register_built_in_templates`

```rust
fn register_built_in_templates(handlebars: &mut Handlebars) -> Result<()> {
    for path in Assets.list("prompts")? {
        if let Some(id) = path
            .split('/')
            .next_back()
            .and_then(|s| s.strip_suffix(".hbs"))
            && let Some(prompt) = Assets.load(path.as_ref()).log_err().flatten()
        {
            log::debug!("Registering built-in prompt template: {}", id);
            let prompt = String::from_utf8_lossy(prompt.as_ref());
            handlebars.register_template_string(id, LineEnding::normalize_cow(prompt))?
        }
    }
    Ok(())
}
```

Beş ayrıntı önemlidir:

- **`Assets.list("prompts")`** — `AssetSource::list` çağrısı; `prompts/content_prompt.hbs` gibi tüm path'leri döner.
- **`path.split('/').next_back().and_then(|s| s.strip_suffix(".hbs"))`** — Path'in son segmentinden uzantıyı çıkararak template id'sini üretir. `prompts/content_prompt_v2.hbs` → `content_prompt_v2`. Bu id'ler ileride `handlebars.render("content_prompt_v2", &context)` çağrılarında kullanırsın.
- **`String::from_utf8_lossy`** — Şablon byte'ları string'e çevrilirken UTF-8 hataları replacement character'a dönüşür. Bozuk encoding render'ı durdurmaz; sadece o bölüm okunaksız hale gelir.
- **`LineEnding::normalize_cow`** — Windows'ta üretilmiş şablonlar CRLF içerebilir; Handlebars motoru LF bekler. `gpui_util::LineEnding::normalize_cow` `\r\n` → `\n` dönüşümünü yapar. `Cow` döndüğü için zaten LF olan içerik ekstra kopyalanmaz.
- **`Assets.load(path.as_ref()).log_err().flatten()`** — `Assets` struct'ı doğrudan static metot olarak çağrılır; `cx.asset_source()` üzerinden değil. Bu, `PromptBuilder::new`'in `App` referansına ihtiyaç duymadan çalışabilmesini sağlar.

### 5.2 Filesystem override mekanizması

`watch_fs_for_template_overrides` kullanıcının `~/.config/zed/prompt_overrides/` (veya muadili) altındaki `.hbs` dosyalarını izler:

```rust
if let Ok(mut entries) = params.fs.read_dir(&templates_dir).await {
    while let Some(Ok(file_path)) = entries.next().await {
        if file_path.to_string_lossy().ends_with(".hbs")
            && let Ok(content) = params.fs.load(&file_path).await {
                let file_name = file_path.file_stem()?.to_string_lossy();
                log::debug!("Registering prompt template override: {}", file_name);
                handlebars.lock().register_template_string(&file_name, content).log_err();
            }
    }
}
```

Override mantığı Handlebars motorunun çakışan template id'lerini en son kayıt eden çağrının kazanması davranışına dayanır. Akış:

1. `register_built_in_templates` ile binary'deki şablonlar yüklenir.
2. Override klasörü taranır; kullanıcı şablonları aynı id'lerle yeniden kaydedilir.
3. Override dosyası değişirse watcher tetiklenir ve template tekrar register edilir.
4. Override klasörü silinirse `register_built_in_templates` yeniden çağrılır ve binary şablonları geri yüklenir.

Bu davranış asset altyapısının önemli bir desenini örnekler: **binary'deki varlık varsayılan, filesystem'deki varlık override**. Aynı yaklaşım tema, keymap ve settings sistemlerinde de görünür (sonraki bölümde işlenir).

### 5.3 Handlebars motoruna eklenirken Asset yolu seçimi

Prompt yükleyici tek bir yerde `Assets` struct'ını doğrudan kullanır (`cx.asset_source()` değil). Bu kararın iki gerekçesi vardır:

- **Kuruluş sırası.** `PromptBuilder::new` `App` global state'i kurulmadan da çağrılabilir olmalıdır. `Assets` static iken `cx.asset_source()` runtime bağımlıdır.
- **Kuruluş yüzeyi.** `prompt_store` crate'i `gpui` ve `assets` crate'lerine bağlıdır; ancak built-in template okuma fonksiyonu `App` veya `Context` istemez. Watcher'lı `PromptBuilder::load(..., cx)` yolu `gpui::App` kullanırken, `PromptBuilder::new(None)` yalnızca gömülü/default şablonları kaydedebilir.

Bu desen ters yönde de geçerlidir: `prompt_store` crate'i hem `gpui`'ye (watcher'ı background executor üzerinde başlatmak için) hem de `assets` crate'ine bağlıdır; built-in şablonları okurken `cx.asset_source()` yerine doğrudan `Assets` struct'ını kullanır. Aynı asset klasörüne iki ayrı arayüzden ulaşmak, hem `PromptBuilder::new(None)` gibi runtime'dan bağımsız kuruluşu hem de `PromptBuilder::load(..., cx)` gibi watcher'lı entegrasyonu mümkün kılar.

---

## 6. `badge/` klasörü ve runtime dışı tüketim

`assets/badge/v0.json` tek dosyalı küçük bir varlık'tır:

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

**Sonuç:** Klasör topolojisinin "her şey runtime tüketicisidir" varsayımı her zaman geçerli değildir. `badge/` örneği, asset klasörünün dış (CI, README, dokümantasyon) tüketim için kullanılan parçalarını da barındırabileceğini gösterir. Bu tür dosyaları `RustEmbed` include kalıbından dışarıda tutmak iki avantaj sağlar:

1. Binary boyutu şişmez (küçük de olsa).
2. Yanlışlıkla runtime'dan okunması mümkün olmaz; dosyanın tüketim yolu ya CI ya da dış servis olarak netleşir.

Genel olarak: asset klasörüne dosya eklerken "bu dosya runtime'da mı yoksa dış araç tarafından mı tüketilecek?" sorusu sorulmalıdır. İkinci durumda `#[include]` direktifi yazılmaz.

---

## 7. Üç tüketici karşılaştırması

Ses, prompt ve badge tüketicilerinin tüketim profillerini bir arada görmek faydalıdır:

| Tüketici | Yükleme zamanı | Yükleme şekli | Cache | Override |
|----------|----------------|---------------|-------|----------|
| `Sound` | Talep anında (lazy) | Senkron `asset_source.load` | `HashMap<Sound, Buffered>` | Yok |
| `PromptBuilder` | Uygulama başlatma anında (eager) | `Assets.list` + `Assets.load` döngüsü | Handlebars motoru içindeki template haritası | Filesystem watcher ile aktif |
| `badge/v0.json` | Hiç (runtime'da okunmaz) | - | - | - |

Üç desen birlikte değerlendirildiğinde asset altyapısının esnekliği belirginleşir: Aynı `AssetSource` arayüzünden hem talep anında ucuz erişim, hem uygulama başlatma sırasında topluca yükleme, hem de tamamen runtime dışı tüketim modelleri kurulabilir. Yeni bir varlık türü eklerken doğru profil seçimi, "ne sıklıkla yüklenecek, kaç kez okunacak, kullanıcı override etmeli mi?" sorularıyla yaparsın.

---

## 8. Pratik akış özeti

```text
Audio::play_sound(Sound::AgentDone, cx)
       │
       ▼ source_cache lookup
       │   ├── HIT → Buffered<Decoder>::clone
       │   └── MISS ↓
       ▼ format!("sounds/{}.wav", sound.file())
       ▼ cx.asset_source().load(&path)
       ▼ rodio::Decoder::new(Cursor::new(bytes))?.buffered()
       ▼ source_cache.insert(sound, source)
       ▼ output_mixer.add(source)
       ▼ Cihaz seviyesinde mixing + DAC
```

```text
App start ──► PromptBuilder::new
                  │
                  ▼ Assets.list("prompts")
                  ▼ Her .hbs için:
                        Assets.load(path) → bytes
                        String::from_utf8_lossy
                        LineEnding::normalize_cow
                        handlebars.register_template_string(id, template)
                  ▼ filesystem watcher başlatılır (override için)
                  ▼ handlebars motoru hazır; render çağrıları beklenir
```

İki akış arasındaki temel fark, yaşam döngüsündedir: ses her tetiklendiğinde döngünün üst tarafına döner; prompt ise yalnızca filesystem override değiştiğinde yeniden register edilir. Hangi profilin seçileceği varlık türünün kullanım sıklığı ve override gereksinimine göre belirlersin.

---
