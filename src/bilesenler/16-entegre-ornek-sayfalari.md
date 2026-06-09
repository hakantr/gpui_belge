# 16. Entegre Örnek Sayfaları

Bileşenleri tek tek doğru kullanmak yeterli değildir. Gerçek bir ekranda asıl önemli olan durumun hangi view'da tutulduğu, event'lerin hangi sınırdan geçtiği, asenkron işlerin nasıl izlendiği ve görsel durum değişiminden sonra render'ın nasıl yenilendiğidir. Tek başına anlaşılmış bileşenler, ancak bu akış içinde bir araya geldiklerinde anlamlı bir uygulama parçasına dönüşür.

Bu bölümdeki örnekler tam ekran uygulama değildir. Daha çok, kendi alan tiplerinin, ayar servislerinin ve action tiplerinin bağlanacağı iskeletlerdir. Kullanılan component API'leri `../zed` çalışma ağacındaki kaynak dosyalara göre düzenlenmiştir.

Ortak uygulama kuralları:

- Görünüme (view) ait geçici UI durumu görünüm struct'ında tutulur: Seçili satır, açık menü, bekleyen asenkron görev (async task), hata mesajı ve ilerleme değeri gibi alanlar burada yer alır.
- Paylaşılan veya servis kaynaklı durum doğrudan component içinde saklanmaz. Bunun yerine render sırasında component'e etiket, durum (status), ikon, geri çağrı (callback) ve üstveri (metadata) olarak aktarılır.
- Görünüm durumunu değiştiren işleyicilerde `cx.listener(...)` kullanılır. Bu sayede closure görünüm örneğine (view instance) güvenli bir şekilde ulaşır.
- Görsel sonucu olan bir durum değişiminden sonra `cx.notify()` çağrılır. Özellikle `selected`, `expanded`, `saving`, `error` ve `progress` gibi alanlarda bu çağrı durum değişimiyle birlikte düşünülmelidir.
- Tamamlanması izlenmesi gereken asenkron işler bir `Task` alanında saklanır. Arayüzü değiştirmeyen yangın ve unut (fire-and-forget) türündeki işler içinse `.detach_and_log_err(cx)` tercih edilir.
- Menü içerikleri `ContextMenu::build(...)` içinde oluşturulur. Menünün açılması ise `PopoverMenu` veya `right_click_menu(...)` gibi taşıyıcı bir bileşene bağlanır.

## Ayarlar Paneli Satırı

Bu örnekte `Headline`, `Label`, `SwitchField`, `Button` ve `Callout` tek bir ayar satırı içinde birlikte kullanılır.

Neden bir arada:

- `Headline`, bölüm (section) başlığını verir.
- `Label`, ayarın adı ve açıklaması için hafif bir metin katmanı sağlar.
- `SwitchField`, boolean bir ayarı erişilebilir bir toggle olarak yönetir.
- `Button`, elle kaydetme veya sıfırlama (reset) gibi komutları taşır.
- `Callout`, satırın altında bir hata, uyarı veya açıklayıcı bir aksiyon olarak görünür.

Durum (State):

- `kaydederken_bicimlendir`: Switch bileşeninin render durumudur.
- `kaydediliyor`: Butonu devre dışı (disable) bırakmak ve ilerleme metni göstermek için kullanılan geçici durumdur.
- `son_hata`: Yalnızca bir hata varsa `Callout` render edilir.
- `_kaydetme_gorevi`: Ayar yazımı bitene kadar task'ın drop edilmemesi için saklanır.

Örnek:

```rust
use gpui::{ClickEvent, Task};
use ui::{
    Button, ButtonSize, ButtonStyle, Callout, Headline, HeadlineSize, IconName,
    Label, LabelSize, Severity, SwitchField, ToggleState, prelude::*,
};

struct EditorAyarlariSatiri {
    kaydederken_bicimlendir: bool,
    kaydediliyor: bool,
    son_hata: Option<SharedString>,
    _kaydetme_gorevi: Option<Task<anyhow::Result<()>>>,
}

impl EditorAyarlariSatiri {
    fn kaydederken_bicimlendirmeyi_ayarla(&mut self, secili: bool, cx: &mut Context<Self>) {
        self.kaydederken_bicimlendir = secili;
        self.kaydediliyor = true;
        self.son_hata = None;
        cx.notify();

        self._kaydetme_gorevi = Some(cx.spawn(async move |this, cx| {
            let sonuc = kaydederken_bicimlendirmeyi_kaydet(secili).await;
            this.update(cx, |this, cx| {
                this.kaydediliyor = false;
                if let Err(hata) = sonuc {
                    this.son_hata = Some(hata.to_string().into());
                }
                cx.notify();
            })?;
            anyhow::Ok(())
        }));
    }

    fn kaydetmeyi_yeniden_dene(&mut self, cx: &mut Context<Self>) {
        self.kaydederken_bicimlendirmeyi_ayarla(self.kaydederken_bicimlendir, cx);
    }
}

impl Render for EditorAyarlariSatiri {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_3()
            .child(Headline::new("Düzenleyici").size(HeadlineSize::Small))
            .child(
                h_flex()
                    .justify_between()
                    .items_start()
                    .gap_3()
                    .child(
                        v_flex()
                            .gap_0p5()
                            .child(Label::new("Kaydederken biçimlendir"))
                            .child(
                                Label::new("Dosyaları yazmadan önce yapılandırılmış biçimlendiriciyi çalıştırır.")
                                    .size(LabelSize::Small)
                                    .color(Color::Muted),
                            ),
                    )
                    .child(
                        SwitchField::new(
                            "kaydederken-bicimlendir",
                            Some("Etkin"),
                            Some("Biçimlendirmeyi otomatik uygula".into()),
                            ToggleState::from(self.kaydederken_bicimlendir),
                            cx.listener(
                                |this, selection: &ToggleState, _window, cx| {
                                    this.kaydederken_bicimlendirmeyi_ayarla(selection.selected(), cx);
                                },
                            ),
                        )
                        .disabled(self.kaydediliyor),
                    ),
            )
            .child(
                Button::new("editor-ayarlari-kaydet", "Şimdi kaydet")
                    .size(ButtonSize::Compact)
                    .style(ButtonStyle::Filled)
                    .disabled(self.kaydediliyor)
                    .on_click(cx.listener(
                        |this, _: &ClickEvent, _window, cx| this.kaydetmeyi_yeniden_dene(cx),
                    )),
            )
            .when_some(self.son_hata.clone(), |this, hata| {
                this.child(
                    Callout::new()
                        .severity(Severity::Error)
                        .icon(IconName::Warning)
                        .title("Ayarlar kaydedilemedi")
                        .description(hata)
                        .actions_slot(
                            Button::new("editor-ayarlari-yeniden-dene", "Yeniden dene")
                                .size(ButtonSize::Compact)
                                .on_click(cx.listener(
                                    |this, _: &ClickEvent, _window, cx| this.kaydetmeyi_yeniden_dene(cx),
                                )),
                        ),
                )
            })
    }
}
```

Dikkat Edilmesi Gereken Hususlar:

- `SwitchField::new(...)` geri çağrısı (callback) yeni durumu bir `&ToggleState` olarak alır. `ToggleState::selected()` kararsız (indeterminate) durumu `false` olarak kabul eder; üç durumlu bir ayar söz konusu ise bir `match` ile açıkça ele alınır.
- Switch durumu iyimser (optimistic) olarak güncelleniyorsa, hata durumunda eski değer geri yazılır ve ardından `cx.notify()` çağrısı gerçekleştirilir.
- Uzun süren yazımlarda `Button` ile `SwitchField` devre dışı (disabled) olmalıdır; aksi takdirde aynı ayar için üst üste asenkron görev başlatma riski oluşur.

## Toolbar ve Komut Menüsü

Bu örnekte `Button`, `IconButton`, `SplitButton`, `PopoverMenu`, `ContextMenu`, `Tooltip` ve `KeybindingHint` aynı araç çubuğu davranışını birlikte tamamlar.

Neden bir arada:

- `Button` veya `ButtonLike`, birincil komutu taşır.
- `IconButton`, kompakt komutlar ve menü tetikleyicileri için uygundur.
- `SplitButton`, birincil eylem ile varyant menüsünü tek bir kontrol gibi gösterir.
- `PopoverMenu`, tetikleyici ile `ContextMenu` görünümünü ilişkilendirir.
- `Tooltip`, sadece ikondan oluşan kontrollerin niyetini açıklar.
- `KeybindingHint`, gerçek kısayol haritasından (keymap) gelen kısayol bilgisini görünür kılar.

Örnek:

```rust
use gpui::ClickEvent;
use ui::{
    ButtonLike, ButtonSize, ContextMenu, IconButton, IconName, Label,
    PopoverMenu, SplitButton, SplitButtonStyle, Tooltip, prelude::*,
};

struct KomutAracCubugu {
    calistirabilir: bool,
}

impl KomutAracCubugu {
    fn varsayilan_komutu_calistir(&mut self, _window: &mut Window, cx: &mut Context<Self>) {
        self.calistirabilir = false;
        cx.notify();

        cx.spawn(async move |this, cx| {
            let sonuc = varsayilan_gorevi_calistir().await;
            this.update(cx, |this, cx| {
                this.calistirabilir = true;
                cx.notify();
            })?;
            sonuc
        })
            .detach_and_log_err(cx);
    }
}

impl Render for KomutAracCubugu {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let sol = ButtonLike::new_rounded_left("varsayilan-calistir")
            .size(ButtonSize::Default)
            .disabled(!self.calistirabilir)
            .child(Label::new("Çalıştır"))
            .on_click(cx.listener(
                |this, _: &ClickEvent, window, cx| this.varsayilan_komutu_calistir(window, cx),
            ))
            .tooltip(|_window, cx| Tooltip::simple("Varsayılan komutu çalıştır", cx));

        let sag = PopoverMenu::<ContextMenu>::new("calistir-menusu")
            .trigger(
                IconButton::new("calistir-menusu-tetikleyici", IconName::ChevronDown)
                    .size(ButtonSize::Default)
                    .tooltip(|_window, cx| Tooltip::simple("Daha fazla çalıştırma komutu", cx)),
            )
            .menu(|window, cx| {
                Some(ContextMenu::build(window, cx, |menu, _window, _cx| {
                    menu.entry("Tümünü çalıştır", None, |_window, _cx| {})
                        .entry("Seçimi çalıştır", None, |_window, _cx| {})
                        .separator()
                        .entry("Görevi yapılandır...", None, |_window, _cx| {})
                }))
            });

        h_flex()
            .gap_1()
            .items_center()
            .child(
                SplitButton::new(sol, sag.into_any_element())
                    .style(SplitButtonStyle::Outlined),
            )
            .child(
                IconButton::new("gorevi-durdur", IconName::Stop)
                    .disabled(self.calistirabilir)
                    .tooltip(|_window, cx| Tooltip::simple("Çalışan görevi durdur", cx)),
            )
    }
}
```

`KeybindingHint` için pratik kurallar:

- Kısayol sabit bir string olarak yazılmaz. Mümkün olduğunda uygulamadaki eylem veya keymap çözümlemesinden dinamik bir `ui::KeyBinding` üretilir.
- Kısayol ipucu her araç çubuğunda görünmek zorunda değildir. Asıl değerli olduğu yerler komut paleti, boş durum veya ilk kullanım akışı gibi bağlamlardır.
- Sadece ikondan oluşan bir buton varsa `Tooltip` kullanımı zorunlu kabul edilir; etiketli bir buton üzerinde tooltip ise yalnızca ek bir bağlam sağlıyorsa kullanılır.

## Proje Listesi

Bu örnekte `List`, `ListItem`, `TreeViewItem`, `Disclosure`, `IndentGuides` ve `CountBadge`, bir proje gezgini benzeri görünümde birlikte çalışır.

Neden bir arada:

- `List`, liste kapsayıcısı ve boş durum davranışı için temel yapıyı sunar.
- `ListItem`, satır alanlarını, seçili durumu (selected state) ve ikincil tıklamayı (secondary click) destekler.
- `TreeViewItem`, dosya ağacı gibi açılma/kapanma (expand/collapse) ile odak davranışı olan satırlarda kullanılır.
- `Disclosure`, özel satır yerleşimlerinde açma/kapatma ikonunu ayrı bir parça olarak yerleştirmeye yarar.
- `IndentGuides`, sanallaştırma kullanan ağaç listelerinde girinti çizgilerini hesaplama ve render sürecine bağlar.
- `CountBadge`, bir klasör veya filtre sonucundaki sayıları kompakt biçimde gösterir.

Durum (State):

- `expanded_project_ids`: Hangi kök veya klasörlerin açık olduğu bilgisi.
- `selected_path`: Tek seçili proje veya dosya yolu.
- `pending_context_menu_path`: Sağ tık menüsü açılırken kullanılan yol.
- Büyük listelerde kaydırma (scroll) ve sanallaştırma (virtualization) durumu bileşenlerin dışında tutulur.

Örnek:

```rust
use gpui::ClickEvent;
use std::collections::HashSet;
use ui::{
    CountBadge, Disclosure, Icon, IconName, Label, List, ListHeader, ListItem,
    TreeViewItem, prelude::*,
};

struct ProjeListesi {
    acik: HashSet<SharedString>,
    secili_yol: Option<SharedString>,
}

impl ProjeListesi {
    fn projeyi_ac_kapat(&mut self, proje_id: SharedString, cx: &mut Context<Self>) {
        if !self.acik.insert(proje_id.clone()) {
            self.acik.remove(&proje_id);
        }
        cx.notify();
    }

    fn yolu_sec(&mut self, yol: SharedString, cx: &mut Context<Self>) {
        self.secili_yol = Some(yol);
        cx.notify();
    }
}

impl Render for ProjeListesi {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let proje_id: SharedString = "zed".into();
        let proje_acik = self.acik.contains(&proje_id);
        let kaynak_yolu: SharedString = "zed/crates/ui/src".into();

        List::new()
            .header(
                ListHeader::new("Projeler")
                    .end_slot(CountBadge::new(3))
                    .toggle(Some(proje_acik))
                    .on_toggle(cx.listener({
                        let proje_id = proje_id.clone();
                        move |this, _: &ClickEvent, _window, cx| {
                            this.projeyi_ac_kapat(proje_id.clone(), cx);
                        }
                    })),
            )
            .child(
                ListItem::new("proje-zed")
                    .toggle_state(self.secili_yol.as_ref() == Some(&proje_id))
                    .start_slot(
                        Disclosure::new("proje-zed-disclosure", proje_acik)
                            .on_click(cx.listener({
                                let proje_id = proje_id.clone();
                                  move |this, _: &ClickEvent, _window, cx| {
                                      this.projeyi_ac_kapat(proje_id.clone(), cx);
                                  }
                            })),
                    )
                    .end_slot(CountBadge::new(12))
                    .child(Label::new("zed"))
                    .on_click(cx.listener({
                        let proje_id = proje_id.clone();
                        move |this, _: &ClickEvent, _window, cx| {
                            this.yolu_sec(proje_id.clone(), cx);
                        }
                    })),
            )
            .when(proje_acik, |this| {
                this.child(
                    TreeViewItem::new("proje-zed-src", "crates/ui/src")
                        .expanded(true)
                        .toggle_state(self.secili_yol.as_ref() == Some(&kaynak_yolu))
                        .on_click(cx.listener({
                            let kaynak_yolu = kaynak_yolu.clone();
                            move |this, _: &ClickEvent, _window, cx| {
                                this.yolu_sec(kaynak_yolu.clone(), cx);
                            }
                        })),
                )
                .child(
                    ListItem::new("proje-zed-bilesenler")
                        .indent_level(2)
                        .start_slot(Icon::new(IconName::Folder))
                        .child(Label::new("bileşenler"))
                        .end_slot(CountBadge::new(41)),
                )
            })
    }
}
```

`IndentGuides` notları:

- `IndentGuides`, düz bir `List` içine otomatik olarak çizgi eklemez. `uniform_list` veya sabitlenmiş öğe süslemesi (sticky item decoration) bağlamında `indent_guides(indent_size, colors)` çağrısıyla kullanılır.
- Girinti hesabı için `with_compute_indents_fn(...)`, özel bir çizim için ise `with_render_fn(...)` bağlanır.
- Girinti durumu satır verisinden türetilir. Her satırda ayrı ayrı çizgi elemanları üretmek, büyük ağaçlarda gereksiz performans maliyeti oluşturur.

## Veri Tablosu

Bu örnekte `Table`, `TableInteractionState`, `RedistributableColumnsState`, `Indicator` ve `ProgressBar` birlikte kullanılır.

Neden bir arada:

- `Table`, satır ve sütun düzenini, başlık (header) davranışını sağlar.
- `TableInteractionState`, kaydırma ve odak durumunu görünüm (view) dışında tutulabilir hâle getirir.
- `RedistributableColumnsState`, sabit bir toplam genişlik içinde kullanıcıya sütun oranlarını yeniden dağıtma seçeneği sunar.
- `Indicator`, satırdaki kısa durum bilgisini gösterir.
- `ProgressBar`, tabloyu besleyen asenkron işlerin ilerlemesini gösterir.

Durum (State):

- `etkilesim_durumu: Entity<TableInteractionState>`.
- `sutun_durumu: Entity<RedistributableColumnsState>`.
- `satirlar: Vec<SatirVm>`.
- `senkron_ilerlemesi: Option<(f32, f32)>`.

Örnek:

```rust
use ui::{
    ColumnWidthConfig, Indicator, ProgressBar, RedistributableColumnsState,
    Table, TableInteractionState, TableResizeBehavior, prelude::*,
};

struct PaketSatiri {
    ad: SharedString,
    surum: SharedString,
    durum: PaketDurumu,
}

enum PaketDurumu {
    Hazir,
    Guncelleniyor,
    Basarisiz,
}

struct PaketTablosu {
    etkilesim_durumu: Entity<TableInteractionState>,
    sutun_durumu: Entity<RedistributableColumnsState>,
    satirlar: Vec<PaketSatiri>,
    senkron_ilerlemesi: Option<(f32, f32)>,
}

impl Render for PaketTablosu {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let tablo = self.satirlar.iter().fold(
            Table::new(3)
                .interactable(&self.etkilesim_durumu)
                .width_config(ColumnWidthConfig::redistributable(
                    self.sutun_durumu.clone(),
                ))
                .striped()
                .header(vec!["Durum", "Paket", "Sürüm"]),
            |tablo, satir| {
                let renk = match satir.durum {
                    PaketDurumu::Hazir => Color::Success,
                    PaketDurumu::Guncelleniyor => Color::Info,
                    PaketDurumu::Basarisiz => Color::Error,
                };

                tablo.row(vec![
                    Indicator::dot().color(renk).into_any_element(),
                    satir.ad.clone().into_any_element(),
                    satir.surum.clone().into_any_element(),
                ])
            },
        );

        v_flex()
            .gap_2()
            .when_some(self.senkron_ilerlemesi, |this, (deger, ust_sinir)| {
                this.child(ProgressBar::new("paket-senkron-ilerlemesi", deger, ust_sinir, cx))
            })
            .child(tablo)
    }
}
```

Kurulum notu:

```rust
fn new(cx: &mut Context<PaketTablosu>) -> PaketTablosu {
    PaketTablosu {
        etkilesim_durumu: cx.new(|cx| TableInteractionState::new(cx)),
        sutun_durumu: cx.new(|_| {
            RedistributableColumnsState::new(
                3,
                vec![rems(5.), rems(16.), rems(8.)],
                vec![
                    TableResizeBehavior::None,
                    TableResizeBehavior::Resizable,
                    TableResizeBehavior::Resizable,
                ],
            )
        }),
        satirlar: Vec::new(),
        senkron_ilerlemesi: None,
    }
}
```

Dikkat Edilmesi Gereken Hususlar:

- `Table::row(...)` küçük ve sabit listeler için yeterlidir. Büyük bir veri setinde `.uniform_list(...)` veya `.variable_row_height_list(...)` kullanılır.
- `RedistributableColumnsState::new(cols, widths, resize_behavior)` içinde `cols`, genişlik sayısı ve yeniden boyutlandırma davranış sayısı birbirine eşit olmalıdır.
- İlerleme değeri değiştiğinde `senkron_ilerlemesi` güncellenir ve hemen ardından `cx.notify()` çağrısı yapılır.

## Bildirim Merkezi

Bu örnekte bir bildirim yaşam döngüsü ile birlikte `AnnouncementToast`, `Banner`, `AlertModal` ve `Button` birlikte ele alınır.

Neden bir arada:

- `Banner`, ekran veya panel üstündeki engelleyici olmayan bir duyuruyu gösterir.
- `AnnouncementToast`, ürün duyurusu veya yeni özellik tanıtımı için hazır bir yerleşim sağlar.
- `AlertModal`, kısa ve engelleyici bir karar anında devreye girer.
- `Button`, banner, toast ve modal eylem yüzeylerinin tamamlayıcısıdır.

Örnek:

```rust
use gpui::ClickEvent;
use ui::{
    AlertModal, AnnouncementToast, Banner, Button, ButtonSize, ListBulletItem,
    Severity, prelude::*,
};

struct BildirimMerkeziOnizleme {
    yeniden_baslatma_uyarisi_goster: bool,
}

impl Render for BildirimMerkeziOnizleme {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        v_flex()
            .gap_3()
            .child(
                Banner::new()
                    .severity(Severity::Warning)
                    .child("Dil sunucusu çökmeden sonra yeniden başlatıldı.")
                    .action_slot(
                        Button::new("lsp-log-ac", "Logu aç")
                            .size(ButtonSize::Compact),
                    ),
            )
            .child(
                AnnouncementToast::new()
                    .heading("Agent oturumları artık geri yüklenebilir")
                    .description("Son çalışmalar oturum geçmişinden kullanılabilir.")
                    .bullet_item(ListBulletItem::new("Önceki agent oturumlarını aç"))
                    .bullet_item(ListBulletItem::new("Kaydedilmiş bağlamdan devam et"))
                    .primary_action_label("Oturumları aç")
                    .primary_on_click(|_event, _window, _cx| thread_gecmisini_ac())
                    .secondary_action_label("Daha fazla bilgi")
                    .secondary_on_click(|_event, _window, _cx| surum_notlarini_ac())
                    .dismiss_on_click(|_event, _window, _cx| duyuruyu_kapat()),
            )
            .when(self.yeniden_baslatma_uyarisi_goster, |this| {
                this.child(
                    AlertModal::new("yeniden-baslatma-gerekli")
                        .title("Yeniden başlatma gerekli")
                        .child("Güncelleme, uygulama yeniden başlatıldıktan sonra uygulanacak.")
                        .primary_action("Yeniden başlat")
                        .dismiss_label("Sonra")
                        .on_action(cx.listener(
                            |this, _: &menu::Confirm, _window, cx| {
                                this.yeniden_baslatma_uyarisi_goster = false;
                                cx.notify();
                            },
                        )),
                )
            })
    }
}
```

Bildirim (Notification) Yaşam Döngüsü:

- Çalışma alanı bildirim yığınına girecek bir görünüm, `workspace::notifications::Notification` trait kuralını karşılamalıdır: `Render`, `Focusable`, `EventEmitter<DismissEvent>` ve `EventEmitter<SuppressEvent>` yapıları birlikte beklenir.
- Kapatma (dismiss) veya gizleme (suppress) durumu bileşen içinde kalıcı kabul edilmez. Kullanıcı tercihi kalıcı olarak saklanacaksa, ayarlar veya bir KV store tarafında tutulur.
- Engelleyici bir karar gerekmiyorsa, `AlertModal` yerine bir `Banner` çok daha uygun bir seçimdir. Çalışma alanının kalıcı bildirim yığınına girecek başlık/içerik/kapatma çerçevesi için ise `workspace::notifications::MessageNotification` görünümü `cx.new(...)` ile bir `Entity` olarak kurulur; ayrıntısı [Bildirim Yardımcıları](../calisma_alani/05-bildirim-yardimcilari.md) bölümündedir.

## AI Sağlayıcı Kartları

Bu örnekte `ConfiguredApiCard`, `AiSettingItem`, `AgentSetupButton`, `ThreadItem` ve `UpdateButton` aynı AI ayar alanında birlikte kullanılır.

Neden bir arada:

- `AiSettingItem`, bir temsilci veya sağlayıcı satırının durum (status) ve kaynak bilgisini taşır.
- `ConfiguredApiCard`, kimlik doğrulaması (credential) var/yok durumunu güvenli ve kısa bir kartla gösterir.
- `AgentSetupButton`, bir sağlayıcı veya temsilci kurulumu için eylem satırı sağlar.
- `ThreadItem`, son temsilci oturumlarını listelemek için alana özel bir satır sunar.
- `UpdateButton`, AI alanının dışında bir güncelleme veya collab özel durumu yaşandığında da aynı kompakt durum/eylem modelini gösterir.

Örnek:

```rust
use gpui::ClickEvent;
use ui::{
    AgentSetupButton, AgentThreadStatus, AiSettingItem, AiSettingItemSource,
    AiSettingItemStatus, ConfiguredApiCard, Icon, IconButton, IconName,
    ThreadItem, UpdateButton, prelude::*,
};

struct AiSaglayiciPaneli {
    saglayici_calisiyor: bool,
    secili_thread_id: Option<SharedString>,
}

impl Render for AiSaglayiciPaneli {
    fn render(&mut self, _window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let thread_id: SharedString = "thread-42".into();

        v_flex()
            .gap_2()
            .child(
                AiSettingItem::new(
                    "openai-provider",
                    "OpenAI",
                    if self.saglayici_calisiyor {
                        AiSettingItemStatus::Running
                    } else {
                        AiSettingItemStatus::Stopped
                    },
                    AiSettingItemSource::Custom,
                )
                .icon(Icon::new(IconName::ZedAgent))
                .detail_label("Asistan ve satır içi düzenlemeler tarafından kullanılır")
                .action(
                    IconButton::new("openai-ayarlari", IconName::Settings)
                        .on_click(|_event, _window, _cx| saglayici_ayarlarini_ac()),
                )
                .details(
                    ConfiguredApiCard::new("API anahtarı yapılandırıldı")
                        .button_label("Anahtarı sıfırla")
                        .tooltip_label("Saklanan API anahtarını değiştir")
                        .on_click(|_event, _window, _cx| saglayici_anahtarini_sifirla()),
                ),
            )
            .child(
                AgentSetupButton::new("yerel-ajan-kur")
                    .icon(Icon::new(IconName::Terminal))
                    .name("Yerel ajan")
                    .state(Label::new("Yapılandırılmadı").color(Color::Muted))
                    .on_click(|_event, _window, _cx| ajan_kurulumunu_ac()),
            )
            .child(
                ThreadItem::new(thread_id.clone(), "Ayarlar panelini yeniden düzenle")
                    .timestamp("2 dk önce")
                    .status(AgentThreadStatus::Running)
                    .project_name("gpui_belge")
                    .selected(self.secili_thread_id.as_ref() == Some(&thread_id))
                    .notified(true)
                    .added(12)
                    .removed(4)
                    .action_slot(IconButton::new("thread-42-arsivle", IconName::Archive))
                    .on_click(cx.listener({
                        let thread_id = thread_id.clone();
                        move |this, _: &ClickEvent, _window, cx| {
                            this.secili_thread_id = Some(thread_id.clone());
                            cx.notify();
                        }
                    })),
            )
            .child(
                UpdateButton::checking()
                    .tooltip("Sağlayıcı üstverisi kontrol ediliyor"),
            )
    }
}
```

Dikkat Edilmesi Gereken Hususlar:

- Sağlayıcı gizli anahtarı (provider secret) veya token değerleri bir component'e doğrudan verilmez. `ConfiguredApiCard` yalnızca yapılandırma durumunu ve sıfırlama eylemini taşıdığı için bu sınır net şekilde korunur.
- `AiSettingItemStatus::Authenticating` ve `AuthRequired` gibi durumlar servis durumundan türetilir; kullanıcı tıklamasıyla iyimser olarak değiştirilmesi yanıltıcı olabilir.
- `ThreadItem` eylem alanında (action slot) yıkıcı (destructive) bir eylem varsa, tooltip ve onay akışının eklenmesi gerekir.

## Collaboration Özeti

Bu örnekte `Avatar`, `Facepile`, `CollabNotification`, `DiffStat` ve `Chip` bir collaboration özet alanında birlikte kullanılır.

Neden bir arada:

- `Avatar`, tek bir kullanıcıyı veya çağrı katılımcısını gösterir.
- `Facepile`, aktif katılımcı grubunu az yer kaplayarak bir arada sunar.
- `CollabNotification`, bir davet veya paylaşım aksiyonu için hazır bir yerleşim verir.
- `DiffStat`, iş birliği sırasında değişen satır sayısını özetler.
- `Chip`, branch, rol, oda veya izin gibi kısa üstverileri taşır.

Örnek:

```rust
use ui::{
    Avatar, Button, Chip, CollabNotification, DiffStat, IconName,
    prelude::*,
};

fn collab_ozeti_render() -> impl IntoElement {
    v_flex()
        .gap_3()
        .child(
            h_flex()
                .gap_2()
                .items_center()
                .child(
                    Facepile::empty()
                        .child(Avatar::new("https://example.com/a.png").size(px(20.)))
                        .child(Avatar::new("https://example.com/b.png").size(px(20.)))
                        .child(Avatar::new("https://example.com/c.png").size(px(20.))),
                )
                .child(Chip::new("Canlı").icon(IconName::Circle).label_color(Color::Success))
                .child(DiffStat::new("collab-diff", 24, 7).tooltip("Paylaşılan dal diff'i")),
        )
        .child(
            CollabNotification::new(
                "https://example.com/avatar.png",
                Button::new("paylasimi-kabul-et", "Kabul et"),
                Button::new("paylasimi-kapat", "Kapat").color(Color::Muted),
            )
            .child("Hakan seni paylaşılan bir projeye davet etti.")
            .child(Chip::new("okuma/yazma").truncate()),
        )
}
```

Dikkat Edilmesi Gereken Hususlar:

- `Facepile` içinde avatar boyutları aynı tutulur; karışık boyutlar üst üste binme (overlap) hizasını bozar.
- `DiffStat` yalnızca özet bir sayı göstermek için tasarlanmıştır. Dosya bazlı bir diff gerekiyorsa ayrı bir liste veya diff görüntüleyici kullanılır.
- `CollabNotification` kabul ve kapatma davranışını kendi içinde yönetmez; iki butonun işleyicileri bildirim yaşam döngüsüne bağlanır.

## Uyum Kontrol Listesi

Bir ekran hedef uygulamaya taşınırken aşağıdaki sıranın izlenmesi faydalı olur:

- Her durum alanının sahibi belirli mi: `View`, `Entity`, servis deposu veya ayarlar?
- Görünüm durumunu değiştiren bütün olay işleyicileri (event handlers) `cx.listener(...)` üzerinden mi geçiyor?
- Görsel sonucu olan durum değişimlerinden sonra `cx.notify()` çağrısı yapılıyor mu?
- Asenkron görev sonucunda görünümün hâlâ hayatta olup olmadığını kontrol etmek için `Entity` veya `WeakEntity` güncelleme sınırları doğru kullanılıyor mu?
- Yangın ve unut (fire-and-forget) türündeki görevler `.detach_and_log_err(cx)` ile kaydediliyor mu?
- Menü içeriği render sırasında güncel durumdan mı kuruluyor?
- Sadece ikondan oluşan kontrollerde bir `Tooltip` yer alıyor mu?
- Kısayol gösterimi gerçek keymap veya eylem çözümlemesinden mi geliyor?
- Büyük listelerde `List` yerine bir sanallaştırma yapısı veya `Table::uniform_list(...)` gibi uygun bir yüzey tercih edildi mi?
- AI ve collab domain bileşenlerine yalnızca render üstverisi mi sağlanıyor, yoksa gizli kimlik bilgisi (credential) veya servis nesnesi mi taşınıyor?

## Klavye Erişimi ve Eylem Akışı Kontrol Listesi

GPUI'de bir ekranın klavye erişimi dört parçayla kurulur: Odak (focus), tab order, key context ve action dispatch. Bu dört parça `Navigable`, `Tooltip`, `KeyBinding`, `Button*`, `ListItem`, `ContextMenu` ve `AlertModal` gibi bileşenlerin kurucu arayüzlerinde dağıtık olarak yer alır. Bir ekran üretirken aşağıdaki sıranın izlenmesi tutarlı bir sonuç verir:

1. **Odak tutamacının (focus handle) tek bir noktada üretilmesi:** Görünüm struct'ında bir `focus_handle: FocusHandle` alanı tutulur ve görünüm `Focusable` trait'ini implement eder. `track_focus` metodu `AlertModal` ile saran eleman/`div` üzerinde bulunur; `Modal` `RenderOnce` olduğundan bu metodu taşımaz. Bir `AlertModal` kullanılıyorsa aynı handle `.track_focus(&focus_handle)` ile ona verilir; sade bir `Modal` kullanılıyorsa handle modalı saran elemana bağlanır.
2. **Tab sırasının (tab order) `tab_index(...)` ile tanımlanması:** `Button`, `IconButton`, `ButtonLike`, `SwitchField`, `Switch`, `DropdownMenu`, `Tab`, `ToggleButtonGroup` ve `TreeViewItem` kurucu arayüzleri `tab_index` değerini (genellikle `&mut isize` veya `isize`) kabul eder. `ConfiguredApiCard` aynı işi `button_tab_index(isize)` metoduyla yapar; içindeki butona tab sırası bu adla verilir. `Disclosure` ve `Table` ise `RenderOnce` olduğundan `tab_index` taşımaz; bu ikisini saran odaklanabilir bir elemana güvenilir. Aynı form üzerinde tek bir sayaç geçirilir; her kurucu sayacı kendi kullandığı kadar artırır.
3. **`tab_stop` ve `track_focus` ile özel odaklanabilir alanlar kurulması:** `ListItem` gibi yüksek seviyeli bileşenler odağı kendileri yönetir. Özel bir `div()` veya `h_flex()` üzerinde klavye odağı vermek için `.track_focus(&handle)` eklenir. Gerekli durumlarda aynı elemente `.tab_index(...)` da tanımlanır. `NavigableEntry::focusable(cx)`, scroll anchor olmadan odaklanabilir bir girdi üretir.
4. **`Navigable` ile yukarı/aşağı geçiş (traversal) kurulması:** Kaydırılabilir bir listede `menu::SelectNext` ve `menu::SelectPrevious` eylemleri, `Navigable::new(...).entry(NavigableEntry::new(...))` bağlamasıyla doğru girdiye kaydırma yapıp odak (focus) verir.
5. **`key_context(...)` ile bağlam zinciri kurulması:** `AlertModal::key_context(...)` ve `ContextMenu::key_context(...)` metotları, modal veya menü içindeyken keymap'in doğru kısayolları kullanmasını sağlar. Özel görünümlerde `cx.set_global` veya bir element üzerinde `.key_context("MyView")` çağrısı kullanılır; `.key_context(...)` doğrudan string kabul eder.
6. **Eylem tetiklemenin (action dispatch) `.on_action::<A>(listener)` ile bağlanması:** `AlertModal::on_action`, `Modal` içindeki `menu::Cancel` ve özel eylemler bu yolla yakalanır. Özel eylem tanımları `actions!(...)` makrosuyla veya `Action` derive makrosuyla yapılır.
7. **Kısayolların eylemlerden (action) türetilmesi:** Tooltip ve ipuçlarında kısayol metnini elle yazmak yerine `KeyBinding::for_action(action, cx)` veya `Tooltip::for_action_title(title, &action)` kullanılır. Bu sayede keymap değiştiğinde arayüz otomatik olarak güncel kalır.
8. **Sadece ikondan oluşan kontrollerde tooltip zorunluluğu:** `IconButton`, `Disclosure`, `CopyButton` gibi etiketsiz kontroller `Tooltip::text(...)` veya `Tooltip::for_action_title(...)` ile niyetlerini belirtmelidir.
9. **Modal veya menü kapandığında odağın geri verilmesi:** `ModalLayer`, `ContextMenu`, `PopoverMenu` ve `right_click_menu` bu davranışı zaten otomatik olarak uygular. Özel bir popover tasarlanıyorsa, önceki odak tutamacı (focus handle) saklanır ve dismiss anında `window.focus(&handle, cx)` çağrısıyla odağı eski yerine iade eder.

Hızlı kontrol listesi:

- [ ] Görünümün (view) bir `focus_handle` alanı var ve `Focusable` implement ediyor mu?
- [ ] Tab sırası için tek bir `&mut isize` veya artan bir `isize` paylaşıldı mı?
- [ ] Listede ok tuşu geçişleri için `Navigable` bağlandı mı?
- [ ] Modal veya menü için `key_context(...)` belirtildi mi?
- [ ] Kısayol tooltip'leri eylem tabanlı yardımcılarla mı üretiliyor?
- [ ] Sadece ikondan oluşan kontroller `Tooltip` taşıyor mu?
- [ ] Modal ya da menü kapanışında önceki odak geri veriliyor mu?
- [ ] Sağ tık menüsü ve `on_secondary_mouse_down` davranışları aynı eylem setine bağlanıyor mu (yani fare ve klavye akışı birbiriyle tutarlı mı)?
