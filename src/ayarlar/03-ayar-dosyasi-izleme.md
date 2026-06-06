# Ayar Dosyası İzleme ve Güncelleme

`SettingsStore`, ham JSON metnine ihtiyaç duyar; bu metni dosya sisteminden okuyup mpsc (multi-producer single-consumer) kanalları üzerinden taşıyan yardımcılar ayrı bir modülde yer alır. Bu sayede store'un kendisi `Fs` (dosya sistemi) veya doğrudan dosya olay akışlarıyla ilgilenmek durumunda kalmaz.

---

## `watch_config_file`

Tek bir konfigürasyon dosyasını izlemek için bu fonksiyondan yararlanılır:

```rust
pub fn watch_config_file(
    executor: &BackgroundExecutor,
    fs: Arc<dyn Fs>,
    path: PathBuf,
) -> (mpsc::UnboundedReceiver<String>, gpui::Task<()>);
```

Davranış Ayrıntıları:

- `fs.canonicalize(&path)` çağrısı ile sembolik bağlar (symlink) üzerinden ev dizinine yönlenen `~/.config/zed` gibi yollar normalleştirilir; kanonik (canonical) yol alma başarısız olsa dahi süreç özgün path ile devam eder.
- `fs.watch(&path, 100ms)` çağrısı dosya olay akışını başlatır; ilk olarak `fs.load(&path)` ile mevcut dosya içeriği kanala yazılır, ardından gelen her değişiklik olayından sonra dosya yeniden yüklenir.
- Eğer kanal alıcısı düşmüşse (örneğin arayüz kapandıysa veya store yenilendiyse) arka plandaki döngü sessizce sonlandırılır; böylece geri çağrı (callback) kanalının gereksiz doldurulması engellenir.
- Geri dönen `Task` nesnesi, izleme döngüsünün sahibidir; bu görev düşürüldüğünde (drop edildiğinde) arka plan görevi de iptal olur. `SettingsStore`'un `_settings_files_watcher` alanında saklanan görev ise bu izleyici görevin kendisi değil, `cx.spawn` ile oluşturulan tüketici görevidir. Bu tüketici görevi, gelen içerikleri `set_user_settings` metoduna aktarır ve ardından `cx.refresh_windows()` çağrısını yapar. `watch_config_file` fonksiyonunun döndürdüğü izleyici görevi doğrudan alana atanmaz; tüketici görevinin gövdesine taşınarak orada canlı tutulur.

Tipik Kullanım Örneği:

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

Birden çok dosyayı barındıran bir konfigürasyon klasörünü izlemek için kullanılır (örneğin `~/.config/zed/` altındaki `settings.json` ve `keymap.json` dosyalarını birlikte takip etmek için):

```rust
pub fn watch_config_dir(
    executor: &BackgroundExecutor,
    fs: Arc<dyn Fs>,
    dir_path: PathBuf,
    config_paths: HashSet<PathBuf>,
) -> mpsc::UnboundedReceiver<String>;
```

Davranış Ayrıntıları:

- İlk taramada `config_paths` içerisinde tanımlanan dosyalardan mevcut olanlar yüklenerek kanala yazılır.
- `fs.watch(&dir_path, 100ms)` ile başlatılan olay döngüsü; dosya bazında `Created` (oluşturuldu), `Changed` (değiştirildi), `Removed` (silindi) ve `Rescan` (yeniden tara) durumlarını ayrı ayrı ele alır.
- `Rescan` olayı dosya bazlı ya da genel dizin bazlı tetiklenebilir; her iki durumda da izlenen dosyaların tamamı diskten yeniden yüklenir. Editörlerin dosya kaydetme mekanizmalarına bağlı olarak, sembolik bağlar (symlink) veya bulut senkronizasyon araçlarının atomic-replace (atomik değiştirme) yöntemleri `Rescan` olayına neden olabilir; bu nedenle bu durum yedek bir yükleme yolu gibi işlev görür.
- `Removed` olayı algılandığında kanala boş bir metin (`""`) yazılır; tüketici tarafındaki store bu boş metni "dosya artık mevcut değil" olarak yorumlar.
- Geri dönen kanal `Task::detach` üzerinden arka planda bağımsız olarak yürütülür; sahiplik takibi gerektirmeyen akışlar için bu yöntem tercih edilir. Sahiplik takibi gerektiği durumlarda ise ayrı bir `Task` oluşturularak doğrudan `executor.spawn` döngüsü kurulabilir.

---

## `update_settings_file` ve Tamamlanma Kanalı

Kullanıcı ayar dosyasına programatik olarak veri yazmak için iki yardımcı fonksiyon sunulur:

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

Davranış Ayrıntıları:

- Bu yardımcılar global `SettingsStore` üzerinden çalışır; doğrudan `SettingsStore::update_settings_file(...)` metodunu çağıran ergonomik sarmalayıcılardır.
- Closure fonksiyonuna parametre olarak verilen `&mut SettingsContent` referansı, mevcut kullanıcı dosyasının ayrıştırılmış halidir ve bellek üzerinde doğrudan mutasyona uğratılır.
- Mutasyon tamamlandıktan sonra store farkları (diff) hesaplar, JSON metnini minimum değişiklik stratejisiyle yeniden biçimlendirir ve `fs.atomic_write(...)` üzerinden dosyaya kaydeder. JSON güncelleme hattı; dosyadaki mevcut yorum satırlarını ve kullanıcının girinti boyutunu (`infer_json_indent_size`) koruyacak şekilde tasarlanmıştır.
- `update_settings_file_with_completion` fonksiyonu da aynı işlemi gerçekleştirir; ancak diske yazma ve ardından gelen store güncellemesi başarıyla tamamlandığında alıcısına `Ok(())` veya hata bilgisini yollar. Sinyal yalnızca `atomic_write` bittiğinde değil, onu takip eden `set_user_settings` adımı da tamamlandıktan sonra gönderilir. Arayüz (UI) üzerinde "kaydedildi" göstergesi gösterilmesi veya yazma eyleminin ardından başka bir mantıksal adımın tetiklenmesi gerekiyorsa bu yöntem tercih edilir.
- Hatalar `SettingsParseResult` yerine doğrudan `anyhow::Error` ile döndürülür; kalıcı bir ayrıştırma (parse) sorunu varsa dosya yeniden okunmadan store'a yedirilmez.

Tipik Kullanım Örneği:

```rust
settings::update_settings_file(fs.clone(), cx, |icerik, _cx| {
    let bolum = icerik.ozellik.get_or_insert_with(Default::default);
    bolum.etkin = Some(true);
});
```

Tamamlanma Durumunun Beklenmesi:

```rust
let alici = settings::update_settings_file_with_completion(fs, cx, |icerik, _| {
    icerik.tema = Some("One Dark".into());
});
let sonuc = alici.await?;
```

---

## Test Ortamı Yardımcıları

Görsel ve birim testlerinde (unit tests), paketlenmiş `default.json` üzerine font ve tema ayarlarının uygulanmasını sağlayan iki yardımcı fonksiyon bulunur:

- `visual_test_settings()` — Arayüz yazı tipi olarak `.SystemUIFont`, tampon (buffer) yazı tipi olarak `Menlo` (macOS), boyut değeri olarak `14` ve tema olarak `empty-theme` ayarlarını uygular. Ekran görüntüsü veya yerleşim ölçüm testlerinde tutarlı yazı tiplerine ihtiyaç duyulduğunda bu yardımlardan yararlanılır.
- `test_settings()` — Linux ve macOS platformlarında `Courier`, Windows platformunda ise `Courier New` ile sabit genişlikli font ayarlarını seçer. `EMPTY_THEME_NAME = "empty-theme"` ile en sade tema entegre edilir.

Bu yardımcılar yalnızca test derlemelerinde (`cfg(any(test, feature = "test-support"))`) etkindir ve üretim (release) koduna dahil edilmez.

---

## Dikkat Edilmesi Gereken Hususlar

- `watch_config_dir` fonksiyonu, dosya henüz mevcut değilse `Created` (oluşturuldu) olayını bekler. Sembolik bağ (symlink) hedefinin sonradan oluşturulduğu senaryolarda, ilk yüklemenin ardından dosya olayları sessizce sıralanmaya başlar. İlk değerin hiç gelmemesi durumunda, dosyanın gerçekten oluşturulduğunu ve sembolik bağ yolunun kanonikleştirilmiş (canonical) olarak göründüğünü doğrulamak gerekir.
- `update_settings_file` doğrudan kullanıcı ayar dosyasına yazar; proje yerelindeki `.zed/settings.json` dosyası için benzer bir API sunulmamaktadır. Proje yerelindeki dosya tarafında JSON metnini yeniden yazan ayrı bir yardımcı bulunmaz; bunun yerine ayrıştırılmış içerikler `SettingsStore::set_local_settings` ile store'un bellek içindeki `local_settings` haritasına işlenir ve bu çağrı doğrudan dosyaya yazma yapmaz. Dosya tarafındaki değişiklikleri store'a aktaran ise ayrı bir `watch_config_dir` akışıdır.
- Closure fonksiyonu içinde erken `return` kullanıldığında yazma akışı hata üretmez; yalnızca o ana kadar yapılan mutasyonlar dosyaya uygulanır. Arayüz tarafında yazma sonucunu görünür kılmak için `update_settings_file_with_completion` veya çevresel bir kayıt mekanizmasının seçilmesi gerekir.
- Kanal alıcısı verileri çok yavaş tüketirse `UnboundedReceiver` aşırı bellek kullanımına yol açabilir; bu nedenle tüketici tarafındaki store güncellemelerinin kısa sürede tamamlanması veya akış hızının sınırlandırılması gerekir.
