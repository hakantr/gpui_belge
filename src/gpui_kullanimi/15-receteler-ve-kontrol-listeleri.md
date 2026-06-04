# Reçeteler ve Kontrol Listeleri

---

## Reçeteler

Bu bölüm, önceki başlıklardaki API'leri günlük senaryolara oturtarak özetler. Her reçete, ihtiyaç duyduğun ayarları ve çağrı sırasını tek yerde toplar.

![Reçete Karar Haritası](assets/recete-karar-haritasi.svg)

#### Yeni Workspace Penceresi

Bir Zed workspace penceresi açarken adımlar şu sırayı izler:

1. `zed::build_window_options(ekran_uuid, cx)` çağırırsın.
2. Kök view olarak workspace veya multi-workspace entity oluşturursun.
3. Başlık çubuğu için `TitleBar`/`PlatformTitleBar` yolunu izlersin.
4. Kök içeriği `workspace::client_side_decorations(...)` ile sararsın.
5. Kapatma işlemi için `workspace::CloseWindow` action'ını dispatch edersin.

#### Küçük Diyalog Penceresi

Küçük modal benzeri pencerelerde tipik konfigürasyon aşağıdaki gibidir; ana pencere değil bir diyalog hedeflediğin için `WindowKind::Dialog` ve resize/minimize kısıtlarını kullanırsın:

```rust
cx.open_window(
    WindowOptions {
        titlebar: Some(TitlebarOptions {
            title: Some("Diyalog".into()),
            appears_transparent: true,
            traffic_light_position: Some(point(px(12.), px(12.))),
        }),
        window_bounds: Some(WindowBounds::centered(size(px(440.), px(300.)), cx)),
        is_resizable: false,
        is_minimizable: false,
        kind: WindowKind::Dialog,
        app_id: Some(ReleaseChannel::global(cx).app_id().to_owned()),
        ..Default::default()
    },
    |window, cx| {
        window.activate_window();
        cx.new(|cx| DiyalogGorunumu::new(window, cx))
    },
)?;
```

#### Saydam/Bulanık Bildirim

Bildirim ve kaplama pencerelerinde tipik olarak başlık çubuğunu kapatır, pencerenin odak almamasını ayarlar ve arka planı saydam yaparsın:

```rust
WindowOptions {
    titlebar: None,
    focus: false,
    show: true,
    kind: WindowKind::PopUp,
    is_movable: false,
    is_resizable: false,
    window_background: WindowBackgroundAppearance::Transparent,
    window_decorations: Some(WindowDecorations::Client),
    ..Default::default()
}
```

Bulanıklık istiyorsan `Transparent` yerine `Blurred`'i kullanırsın; bunun için içerik kökünün tamamen opak bir arka plan çizmediğinden emin olman gerekir, aksi halde bulanıklık görünmez kalır.

#### Platforma Göre UI Ayırma

Çalışma zamanında platforma göre dallanma gerektiğinde `PlatformStyle`'ı kullanırsın:

```rust
match PlatformStyle::platform() {
    PlatformStyle::Mac => { /* macOS */ }
    PlatformStyle::Linux => { /* Linux */ }
    PlatformStyle::Windows => { /* Windows */ }
}
```

Derleme zamanı farkı gerekiyorsa `cfg!(target_os = "...")` veya `#[cfg(...)]`'ı tercih edersin. Çalışma zamanı stillendirmesi için `PlatformStyle` daha okunaklıdır.

#### Başlık Çubuğu Sürükleme ve Çift Tıklama

Sürükleme ve çift tıklama davranışını tek bir tıklama işleyicisi içinde toplarsın. Çift tıklamada platforma göre yerel ya da fluent yardımcıyı kullanırsın:

```rust
h_flex()
    .window_control_area(WindowControlArea::Drag)
    .on_click(|olay, window, _| {
        if olay.click_count() == 2 {
            if cfg!(target_os = "macos") {
                window.titlebar_double_click();
            } else {
                window.zoom_window();
            }
        }
    })
```

Linux veya macOS'ta elle sürükleme başlatman gerekirse fare hareketi sırasında şu çağrıyı yaparsın:

```rust
window.start_window_move();
```

Windows tarafında `WindowControlArea::Drag` yerel hit-test üzerinden daha doğru sonucu verir; bu nedenle Windows'ta sürükleme için ayrı bir `start_window_move` çağrısına gerek kalmaz.

#### İstemci Tarafı Yeniden Boyutlandırma Tutamacı

İstemci tarafı süslemesi ile birlikte sunulan yeniden boyutlandırma tutamaçlarında kenar hesabı yaparsın. İlgili `ResizeEdge` ile platform çağrısını tetiklersin:

```rust
.on_mouse_down(MouseButton::Left, move |olay, window, _| {
    if let Some(kenar) = yeniden_boyutlandirma_kenari(olay.position, golge, boyut, doseme) {
        window.start_window_resize(kenar);
    }
})
```

İmleç stilini de aynı kenara göre `ResizeUpDown`, `ResizeLeftRight`, `ResizeUpLeftDownRight` veya `ResizeUpRightDownLeft` olarak ayarlaman gerekir; aksi halde yeniden boyutlandırma bölgesinde görsel ipucu eksik kalır.

#### Tema Değişince Pencere Arka Planını Güncelleme

Tema akışı tüm pencerelere yansıtılırken ayar gözlemcisi içinden tek tek pencerelerin arka plan görünüşünü güncellersin:

```rust
cx.observe_global::<SettingsStore>(move |cx| {
    for window in cx.windows() {
        let gorunum = cx.theme().window_background_appearance();
        window.update(cx, |_, window, _| {
            window.set_background_appearance(gorunum);
        }).ok();
    }
}).detach();
```

Zed ana uygulaması bu deseni zaten kullanır.

#### HTTP'den Veri Çekip Listeleme

Basit veri yükleme akışı üç parçaya ayrılır: view alanları yükleniyor/hata/liste durumunu tutar, async task HTTP isteğini yapar, sonuç dönünce aynı view'i `update_in` içinde güncellersin:

```rust
#[derive(serde::Deserialize)]
struct Kayit {
    sira: usize,
    baslik: SharedString,
}

struct KayitListesiGorunumu {
    adres: SharedString,
    kayitlar: Vec<Kayit>,
    yukleniyor_mu: bool,
    hata: Option<SharedString>,
}

impl KayitListesiGorunumu {
    fn yenile(&mut self, window: &mut Window, cx: &mut Context<Self>) {
        self.yukleniyor_mu = true;
        self.hata = None;
        cx.notify();

        let http_istemcisi = cx.http_client();
        let adres = self.adres.clone();

        cx.spawn_in(window, async move |gorunum, cx| {
            let sonuc = kayitlari_cek(http_istemcisi, adres).await;

            gorunum.update_in(cx, |gorunum, _window, cx| {
                gorunum.yukleniyor_mu = false;
                match sonuc {
                    Ok(kayitlar) => gorunum.kayitlar = kayitlar,
                    Err(hata) => gorunum.hata = Some(hata.to_string().into()),
                }
                cx.notify();
            })?;

            Ok::<(), anyhow::Error>(())
        })
        .detach_and_log_err(cx);
    }
}
```

HTTP yardımcısını UI'dan ayrı tutarsın; böylece testlerde sahte `HttpClient` verebilirsin ve JSON parse hatası UI state'ine açıkça döner:

```rust
async fn kayitlari_cek(
    http_istemcisi: Arc<dyn HttpClient>,
    adres: SharedString,
) -> anyhow::Result<Vec<Kayit>> {
    use futures::AsyncReadExt as _;

    let mut cevap = http_istemcisi.get(adres.as_ref(), ().into(), true).await?;
    let mut govde = String::new();
    cevap.body_mut().read_to_string(&mut govde).await?;

    Ok(serde_json::from_str(&govde)?)
}
```

Render tarafında listeyi `.children(...)` ile üretir, yükleme ve hata durumlarını da aynı element ağacına bağlarsın:

```rust
div()
    .v_flex()
    .children(self.hata.as_ref().map(|hata| {
        Label::new(hata.clone()).color(Color::Error)
    }))
    .when(self.yukleniyor_mu, |oge| {
        oge.child(Label::new("Yükleniyor...").color(Color::Muted))
    })
    .children(self.kayitlar.iter().map(|kayit| {
        div()
            .id(("kayit", kayit.sira))
            .px_2()
            .py_1()
            .child(kayit.baslik.clone())
    }))
```

Bu desen fire-and-forget yenileme için uygundur. Kullanıcı pencereyi kapattığında ya da yeni istek eskisini iptal etmeliyse dönen `Task`'ı bir view alanında saklarsın; yalnızca bilinçli şekilde arka planda bıraktığın işlerde `detach_and_log_err(cx)`'i kullanırsın.

#### Git Graph Özel Komut Task'ı

Git Graph commit bağlam menüsünden özel bir task çalıştırmak için global `tasks.json` içine `git-command` etiketli bir task eklersin. Worktree yerel task'lar bu akışta desteklenmez. Task seçili commit ve repository bağlamıyla çözülür; varsayılan çalışma dizini seçili repository köküdür.

Desteklenen Git değişkenleri seçili commit ve onun bağlı olduğu repository
bağlamından üretilir. Bu bağlamda yalnız Git değişkenleri sağlanır. `ZED_FILE`,
`ZED_SELECTED_TEXT`, `ZED_WORKTREE_ROOT`, `ZED_MAIN_GIT_WORKTREE` gibi
editör/worktree değişkenleri varsayılan değer taşımadıkça çözümlenmez.

- `ZED_GIT_SHA` seçili commit'in tam SHA değeridir; `git show`, `git branch
  --contains` veya özel script argümanı olarak kullanırsın.
- `ZED_GIT_SHA_SHORT` aynı commit'in kısa gösterimidir; task etiketi veya kullanıcıya
  görünen çıktı için uygundur.
- `ZED_GIT_REPOSITORY_PATH` seçili commit'in geldiği repository'nin çalışma dizini
  yoludur; task `cwd` değeri için en güvenli seçimdir.
- `ZED_GIT_REPOSITORY_NAME` repository path'inin son bileşeninden türetilir; task
  etiketi veya environment değişkeninde kullanıcıya okunabilir repository adı
  gerektiğinde kullanılır.

Tipik bir tanım şöyledir:

```json
[
  {
    "label": "Branches containing commit: $ZED_GIT_SHA_SHORT",
    "command": "git",
    "args": ["branch", "-a", "--contains", "$ZED_GIT_SHA"],
    "tags": ["git-command"]
  }
]
```

## Sık Hatalar ve Doğru Desenler

Aşağıdaki liste rehber boyunca anlatılan tuzakları tek bir noktada toparlar; her madde belirtisi ile birlikte altta yatan nedeni de işaret eder.

- **İstenen süslemeye güvenme** — `WindowOptions.window_decorations` yalnız bir istektir. Çizim sırasında fiili sonucu `window.window_decorations()` çağrısı verir; kararını bu sonuca dayandırman gerekir.
- **Bulanıklık görünmüyor** — Kök view veya tema tamamen opak bir renk çiziyor olabilir. Bulanıklık efektinin görünmesi için saydam bir surface ve içerikte alfa bırakman şarttır.
- **Linux kontrol butonları yanlış tarafta** — Doğru kaynak `cx.button_layout()`'tur ve değişimini `observe_button_layout_changed` ile izlemen gerekir.
- **Windows başlık butonları tıklanmıyor** — Butonlarda `window_control_area(Close/Max/Min)` çağrısının eksik kalması yerel hit-test'i bozar.
- **Kapatma davranışı atlanıyor** — Zed workspace penceresinde doğrudan `remove_window` yerine `workspace::CloseWindow` action'ını dispatch etmen gerekir; aksi halde kirli buffer ve kullanıcı onayı akışları atlanır.
- **Async task çalışırken yok oluyor** — Dönen `Task`'ı saklamamış ya da detach etmemişsin; drop edildiği anda iş iptal olur.
- **Entity sızıntı** — Uzun yaşayan task veya abonelik içinde güçlü `Entity` yakalamak döngü üretir; bunun yerine `WeakEntity`'yi kullanman gerekir.
- **Çizim güncellenmiyor** — Durum değişiminden sonra `cx.notify()` unutulmuştur; view aynı verilerle yeniden çizilir.
- **Odak geri çağrısı tetiklenmiyor** — Element `.track_focus(&odak_tutamagi)` ile ağaca bağlanmamış olabilir.
- **Özel başlık çubuğu altında içerik tıklanamıyor** — Sürükleme veya window control hitbox'ı fazla geniş tutulmuş ya da `.occlude()` yanlış yere konmuş olabilir.
- **İstemci süslemesi gölge boşluğu** — `set_client_inset` ve dış sarmalayıcının padding/shadow değerlerini birlikte yönetmen gerekir; aralarındaki uyumsuzluk görünür bir boşluk üretir.

## Yeni Pencere Eklerken Kontrol Listesi

Yeni bir pencere eklerken aşağıdaki kontrol listesi unutulan bir ayrıntı kalmaması için sana bir hatırlatma görevi görür:

1. Bu pencerenin workspace mi, modal mı, popup mu olduğuna karar verir ve uygun `WindowKind`'ı seçersin.
2. Ana Zed penceresi ise `build_window_options`'ı kullanırsın.
3. Sınırları geri yükleyeceksen `WindowBounds`'u kalıcılaştırırsın.
4. Hangi display'de açılacağını belirler; `display_id` veya `display_uuid`'i seçersin.
5. Başlık çubuğu yerel mi, özel mi olacak? `TitlebarOptions` ile `PlatformTitleBar` arasındaki kararı verirsin.
6. Linux dekorasyon modu ayardan geliyorsa `window_decorations`'ı bağlarsın.
7. İstemci süslemesi varsa sarmalayıcıyı, inset'i, yeniden boyutlandırma tutamacını ve tiling durumunu eklersin.
8. Kapatma action'ı doğrudan pencereyi mi kapatmalı, yoksa workspace kapatma akışını mı tetiklemeli, belirlersin.
9. Bulanıklık veya saydamlık gerekiyorsa `window_background` ile kök alfa uyumunu kontrol edersin.
10. Odak başlangıcı doğru mu? `focus`, `show`, `activate_window` ve focus handle'ı gözden geçirirsin.
11. Minimum boyut gerekli mi, sorarsın.
12. App id ve Linux ikonu gerekiyor mu, kontrol edersin.
13. macOS yerel sekmeleme istiyorsan `tabbing_identifier`'ı ayarlarsın.
14. Ayar veya tema değişiminde arka planın güncellenip güncellenmeyeceğini planlarsın.
15. Buton yerleşim değişiminde başlık çubuğunun yeniden çizilip çizilmeyeceğini gözden geçirirsin.
16. Testte timer gerekiyorsa GPUI executor timer'ını kullanırsın.

## Kısa Cevaplar

Bu başlık altında rehber boyunca en çok sorulan dört konunun kısa özeti yer alır.

**İleride pencere oluşturmak için izleyeceğin yol.** Workspace penceresi için başlangıç noktası `zed::build_window_options`'tır. Özel ve küçük bir pencere için doğrudan `cx.open_window(WindowOptions { ... }, |window, cx| cx.new(...))` çağrısını kullanırsın. Kök view, `Render` uygulayan bir `Entity` olmalıdır.

**Pencere dekorunun tanımlanması.** Linux için `WindowOptions.window_decorations = Some(WindowDecorations::Client/Server)` verirsin. Çizim tarafında fiili sonucu `window.window_decorations()` ile okursun. Zed tarzı istemci süslemesi için `workspace::client_side_decorations`'ı kullanırsın. macOS ve Windows'ta özel başlık çubuğu için `TitlebarOptions { appears_transparent: true }` ya da `titlebar: None` ile `PlatformTitleBar`'ı tercih edersin.

**Kontrol butonlarının yönetimi.** Zed içinde `platform_title_bar::render_left_window_controls` ve `render_right_window_controls`'ı kullanırsın. Linux'ta `cx.button_layout()` ve `window.window_controls()` sonucu belirleyicidir. Windows'ta butonları `WindowControlArea::{Min, Max, Close}` ile yerel hit-test'e bağlarsın. Kapatma için workspace akışında `CloseWindow` action'ını dispatch edersin.

**Bulanıklık yönetiminin işletim sistemine göre uygulanması.** Pencere açılırken veya tema değiştiğinde `window.set_background_appearance(...)`'ı çağırırsın. Zed tema akışı `opaque`, `transparent` ve `blurred` değerlerini destekler. macOS gerçek bulanıklığı `NSVisualEffectView` ile, Windows composition/DWM ile, Wayland ise compositor bulanıklık protokolü ile uygular. Destek olmadığında `Blurred` saydam gibi davranabilir. Kök UI opak çizdiğinde bulanıklık görünmez kalır.

**Platform farklarının soyutlanacağı yer.** Davranış pencere ile ilgiliyse GPUI `Platform` ve `PlatformWindow` katmanına bağlanır. Zed UI görünümüyle ilgiliyse `PlatformStyle::platform()` ve `platform_title_bar` bileşenlerini kullanırsın. Ayar farkı gerekiyorsa `settings_content` şeması ve `settings` dönüşümleri devreye girer.

## Kavram → Crate/Modül Eşlemesi

Aşağıdaki liste, rehberde anlatılan kavramların hangi crate veya modülde yer aldığını tek bakışta verir. Yeni bir bileşen yazarken benzer örneğin nerede tanımlı olduğunu hızla bulmana yarar.

- Pencere açma API'si: `open_window`
- Pencere seçenekleri: `WindowOptions`
- Platform penceresi sözleşmesi: `PlatformWindow`
- Pencere sarmalayıcı metotları: `gpui` crate'i
- Element ve çizim trait'leri: `gpui` crate'i, `view`
- Style fluent API: `gpui` crate'i
- Interactivity fluent API: `gpui` crate'i
- Platform seçimi: `gpui_platform` crate'i
- macOS pencere davranışı: `gpui_macos` crate'i
- Windows pencere davranışı: `gpui_windows` crate'i, `events`
- Linux Wayland davranışı: `gpui_linux` crate'i
- Linux X11 davranışı: `gpui_linux` crate'i
- Zed ana window options: `build_window_options`
- Zed platform başlık çubuğu: `platform_title_bar` crate'i
- Linux kontroller: `platform_title_bar` crate'i
- Windows kontroller: `platform_title_bar` crate'i
- Workspace istemci süslemesi: `client_side_decorations`
- Zed başlık çubuğu kompozisyonu: `title_bar` crate'i
- Tema arka plan görünüşü: `theme` crate'i, `theme_settings` crate'i, `settings` crate'i
- UI bileşen dışa aktarım listesi: `ui` crate'i
- UI input: `ui_input` crate'i, `input_field`
