# Ayar Dosyası İzleme ve Güncelleme

`crates/settings/src/settings_file.rs`. `SettingsStore` ham JSON metnine ihtiyaç duyar; bu metni dosya sisteminden okuyup mpsc kanalları üzerinden taşıyan yardımcılar ayrı bir modülde yaşar. Bu sayede store kendisi `Fs` veya dosya event akışıyla doğrudan ilgilenmez.

---

## `watch_config_file`

Tek bir konfigürasyon dosyasını izlemek için kullanırsın:

```rust
pub fn watch_config_file(
    executor: &BackgroundExecutor,
    fs: Arc<dyn Fs>,
    path: PathBuf,
) -> (mpsc::UnboundedReceiver<String>, gpui::Task<()>);
```

Davranış:

- `fs.canonicalize(&path)` ile sembolik bağ ev dizinine kurulu `~/.config/zed` gibi yollar normalleştirilir; canonical alma başarısız olsa bile özgün path ile devam eder.
- `fs.watch(&path, 100ms)` event akışını açar; ilk olarak `fs.load(&path)` ile mevcut içerik kanala yazılır, ardından her event sonrası yeniden yüklenir.
- Alıcı düşmüşse (UI kapandı, store yenilendi) loop sessizce sonlanır; sahibinin geri çağrı kanalı doldurmaması için.
- Geri dönen `Task` izleme döngüsünün sahibidir; düşürülürse arka plan görevi iptal olur. Aynı `Task` `_settings_files_watcher` alanında `SettingsStore` tarafından saklarsın.

Tipik kullanım:

```rust
let (mut alici, _gorev) =
    settings::watch_config_file(&cx.background_executor(), fs.clone(), kullanici_ayar_yolu);
cx.spawn(async move |cx| {
    while let Some(icerik) = alici.next().await {
        cx.update_global(|store: &mut SettingsStore, cx| {
            let sonuc = store.set_user_settings(&icerik, cx);
            if let Err(hata) = sonuc.result() {
                log::warn!("ayar dosyası okunamadı: {hata:?}");
            } else {
                cx.refresh_windows();
            }
        });
    }
}).detach();
```

---

## `watch_config_dir`

Birden çok dosyayı içeren bir konfigürasyon klasörü için kullanılır (örneğin `~/.config/zed/` altında `settings.json` ve `keymap.json` gibi):

```rust
pub fn watch_config_dir(
    executor: &BackgroundExecutor,
    fs: Arc<dyn Fs>,
    dir_path: PathBuf,
    config_paths: HashSet<PathBuf>,
) -> mpsc::UnboundedReceiver<String>;
```

Davranış:

- İlk turda `config_paths` içindeki her dosya mevcutsa yüklenip kanala yazılır.
- `fs.watch(&dir_path, 100ms)` event döngüsü dosya başına `Created`, `Changed`, `Removed`, `Rescan` durumlarını ayrı ele alır.
- `Rescan` olayı dosya olayı veya dizin olayı olarak gelebilir; her iki durumda da izlenen dosyaların hepsi yeniden yüklenir. Editör kayıt biçimine bağlı olarak symlink veya sürücü senkronizasyon araçlarının atomic-replace yöntemi `Rescan` üretebilir; bu yüzden bu durum kasıtlı olarak yedek yükleme yolu gibi davranır.
- `Removed` olayı kanala boş string yazar; tüketici store tarafında "dosya yok" olarak yorumlamalıdır.
- Geri dönen kanal `Task::detach` üzerinden arka planda yürür; sahip olunmasına gerek olmayan akış için seçersin. Sahiplik gerekirse ayrı bir `Task` yaratıp doğrudan `executor.spawn` döngüsü yazılabilir.

---

## `update_settings_file` ve completion kanalı

Kullanıcı ayar dosyasına programatik yazma için iki yardımcı vardır:

```rust
pub fn update_settings_file(
    fs: Arc<dyn Fs>,
    cx: &App,
    update: impl 'static + Send + FnOnce(&mut SettingsContent, &App),
);

pub fn update_settings_file_with_completion(
    fs: Arc<dyn Fs>,
    cx: &App,
    update: impl 'static + Send + FnOnce(&mut SettingsContent, &App),
) -> futures::channel::oneshot::Receiver<anyhow::Result<()>>;
```

Davranış:

- Yardımcılar global `SettingsStore` üzerinden çalışır; doğrudan `SettingsStore::update_settings_file(...)` çağrısının ergonomik sarmalayıcısıdır.
- Closure'a verilen `&mut SettingsContent` mevcut kullanıcı dosyasının ayrıştırılmış halidir; in-place mutate edilir.
- Mutasyon sonrası store fark üretir, JSON metnini minimum diff stratejisiyle yeniden yazar ve `fs.atomic_write(...)` üzerinden dosyaya kaydeder. JSON formatlayıcısı yorumları korur ve kullanıcı girintilemesini (`infer_json_indent_size`) saygılı tutar.
- `update_settings_file_with_completion` aynı işi yapar ama yazma tamamlanınca alıcısına `Ok` veya hata yollar. UI "kaydedildi" göstergesi veya yazma sonrası başka bir adım gerekiyorsa bu form tercih edersin.
- Hatalar `SettingsParseResult` ile değil doğrudan `anyhow::Error` ile döner; kalıcı ayrıştırma sorunu varsa dosya yeniden okunmadan store'a yedirilmez.

Tipik kullanım:

```rust
settings::update_settings_file(fs.clone(), cx, |icerik, _cx| {
    let bolum = icerik.ozellik.get_or_insert_with(Default::default);
    bolum.etkin = Some(true);
});
```

Tamamlanma bekleniyorsa:

```rust
let alici = settings::update_settings_file_with_completion(fs, cx, |icerik, _| {
    icerik.tema = Some("One Dark".into());
});
let sonuc = alici.await?;
```

---

## Test ortamı yardımcıları

Görsel ve birim testlerde paketlenmiş `default.json` üzerine font ve tema override'ı uygulayan iki yardımcı bulunur:

- `visual_test_settings()` — UI font olarak `.SystemUIFont`, buffer font olarak `Menlo` (macOS), boyut 14 ve tema `empty-theme` verir. Ekran görüntüsü veya yerleşim ölçüm testlerinde tutarlı yazı tipi gerektiğinde kullanırsın.
- `test_settings()` — Linux/macOS'ta `Courier`, Windows'ta `Courier New` ile sabit genişlikli font seçer. `EMPTY_THEME_NAME = "empty-theme"` minimum tema'yı bağlar.

Bu yardımcılar `cfg(any(test, feature = "test-support"))` altındadır; üretim koduna sızdırılmaz.

---

## Tuzaklar

- `watch_config_dir` dosya yokken `Created` olayını bekler; symlink hedefi sonradan oluşturulan yapılandırmalarda ilk yüklemenin ardından sessizce sıralanmaya başlar. İlk değer hiç gelmiyorsa dosyanın gerçekten yaratıldığını ve symlink path'inin canonical'da göründüğünü doğrulamak gerekir.
- `update_settings_file` user dosyasına yazar; proje yerel `.zed/settings.json` için aynı API yoktur. Proje yerel dosyayı düzenlemek için `Project::update_local_settings` veya doğrudan `fs.atomic_write` yolu kullanılır ve değişim ayrı bir `watch_config_dir` ile store'a yedirilir.
- Closure içinde panik veya hata bırakmak (`return`) yazma akışını sessizce keser; UI'da görünür olması için `update_settings_file_with_completion` veya çevresel kayıt mekanizması seçmen gerekir.
- Kanal alıcısı çok yavaş tüketirse `UnboundedReceiver` bellek tüketir; tüketici store update'i kısa sürede yapmalı veya akışı throttling'e almalıdır.
