# `TitleBar` entity'si, `init` ve iki render modu

Bu bölüm ürün başlığının çekirdeğini anlatır: `TitleBar` entity'si nasıl kurulur, `init` ile uygulamaya nasıl bağlanır ve her render geçişinde iki ayrı moddan birini neden seçer. Sonraki bölümlerdeki tek tek göstergeler bu çekirdeğin üstüne oturur.

## 1. `init`: her `Workspace` için bir `TitleBar`

Crate'in giriş noktası `init` fonksiyonudur:

```rust
pub fn init(cx: &mut App)
```

`init` üç iş yapar. Önce platform kabuğunu hazırlamak için `PlatformTitleBar::init(cx)` çağırır. Sonra komut paletindeki panel düzeni eylemlerini (`UseClassicLayout`, `UseAgenticLayout`) yapay zekâ durumuna göre süzen süzgeci kurar: `update_layout_action_filter` bir kez doğrudan çağrılır ve `cx.observe_global::<SettingsStore>(...)` ile ayar her değiştiğinde yeniden çalışacak biçimde bağlanır; yapay zekâ kapalıysa bu eylemler palette gizlenir, açıksa gösterilir. Son olarak `cx.observe_new(...)` ile pencereye sahip her yeni `Workspace` için bir `TitleBar` entity'si üretir ve bunu `workspace.set_titlebar_item(...)` ile `Workspace` başlık alanına yerleştirir:

```rust
pub fn init(cx: &mut App) {
    platform_title_bar::PlatformTitleBar::init(cx);

    update_layout_action_filter(cx);
    cx.observe_global::<SettingsStore>(update_layout_action_filter)
        .detach();

    cx.observe_new(|calisma_alani: &mut Workspace, window, cx| {
        let Some(window) = window else { return };
        let coklu_calisma_alani = calisma_alani.multi_workspace().cloned();
        let oge = cx.new(|cx| {
            TitleBar::new("baslik-cubugu", calisma_alani, coklu_calisma_alani, window, cx)
        });
        calisma_alani.set_titlebar_item(oge.into(), window, cx);
        // ... eylem kayıtları
    })
    .detach();
}
```

Aynı blokta birkaç eylem `Workspace` içine bağlanır: her platformda `UseClassicLayout` ve `UseAgenticLayout` (klasik ve yapay zekâ panel düzeni arasında geçiş) ile `SimulateUpdateAvailable` (güncelleme yüzeyini test için); yalnız macOS dışında ayrıca `OpenApplicationMenu`, `ActivateMenuLeft`, `ActivateMenuRight` (uygulama menüsünü açma ve menüler arası gezinme). Bu eylemler `Workspace` üzerinden gelir, başlık öğesini bulur ve ilgili `TitleBar` metoduna ya da düzen ayarına yönlendirir.

Port hedefinde aynı kalıbı kurarsın: uygulama başlangıcında platform kabuğunu hazırla, sonra her pencere/çalışma alanı için bir ürün başlık entity'si üretip pencereye bağla.

## 2. `TitleBar::new`: alanlar ve abonelikler

```rust
pub fn new(
    id: impl Into<ElementId>,
    workspace: &Workspace,
    multi_workspace: Option<WeakEntity<MultiWorkspace>>,
    window: &mut Window,
    cx: &mut Context<Self>,
) -> Self
```

`new`, ürün başlığının ihtiyaç duyduğu tüm durum kaynaklarını toplar ve değişikliklerini izlemeye başlar:

| Alan | Rol | Sahiplik |
| :-- | :-- | :-- |
| `platform_titlebar` | Beslenen platform kabuğu | güçlü `Entity` |
| `project` | Proje, worktree'ler, git deposu | güçlü |
| `user_store` | Oturum açan kullanıcı, plan, avatar | güçlü |
| `client` | Bağlantı durumu, oturum, uzak sunucu | `Arc<Client>` |
| `workspace` | Çalışma alanı | **zayıf** (döngü önlemek için) |
| `multi_workspace` | Yan panel/çoklu pencere kaynağı | opsiyonel **zayıf** |
| `application_menu` | İstemci tarafı menü | opsiyonel çocuk entity |
| `update_version` | Güncelleme bildirimi | çocuk entity |
| `banner` | İlk karşılama duyuru bandı | opsiyonel; güncel HEAD'de `None` |

Tablo başlığın ana durum kaynaklarıyla sınırlıdır; struct'ta ayrıca abonelik tutan `_subscriptions`, ekran paylaşımı açılır menüsünü süren `screen_share_popover_handle` ve tanı aboneliğini tutan `_diagnostics_subscription` alanları da bulunur.

`new` ayrıca bir dizi abonelik kurar; her biri ilgili durum değiştiğinde `cx.notify()` ile yeniden render tetikler: `Workspace` değişimi, aktif çağrı (`ActiveCall`), pencere aktivasyonu, git store olayları (aktif repo/repo güncellemesi), kullanıcı store, çalışma ağacı oluşturma, pencere butonu yerleşimi değişimi ve varsa güvenilir çalışma ağacı (`TrustedWorktrees`) değişimi. Bu abonelikler, başlığın dört hızlı değişen alanını (proje, dal, bağlantı, kullanıcı) güncel tutmanın yoludur.

`application_menu` alanı platforma göre kurulur: macOS'ta yalnız derleme sırasında tanımlı `ZED_USE_CROSS_PLATFORM_MENU` derleme ortam değişkeni varsa, Linux ve Windows'ta ise her zaman bir `ApplicationMenu` entity'si üretilir. macOS'ta varsayılan olarak `None` kalır; çünkü orada yerel menü çubuğu kullanılır.

## 3. Render: çocuk grubunun hazırlanması

`TitleBar::render`, ürün çocuklarını sabit kapasiteli bir `ArrayVec` içinde toplar. Sıra ve içerik şudur:

1. **Sol grup** (`h_flex`): `show_menus` kapalıysa uygulama menüsü, ardından kısıtlı mod göstergesi, proje sunucusu, proje adı ve çalışma ağacı ile dal yüzeyi. Çalışma ağacı ve dal birlikte çizilir; bu blok git'in etkin olmasına (`git.enabled`) ve `show_project_items`/`show_branch_name` ayarlarına bağlıdır. Bu grup sol fare basma olayında yayılımı durdurur (sürükleme ile çakışmasın).
2. **Katılımcı listesi**: aktif çağrıda proje paylaşımı katılımcıları.
3. **İlk karşılama duyuru bandı**: yalnız `show_onboarding_banner` ayarı açık ve `banner` alanı `Some` ise. (Güncel HEAD'de `banner` her zaman `None` olduğu için pratikte çizilmez; ayrıntı [7. bölümde](07-kullanici-update-banner.md).)
4. **Sağ grup** (`h_flex`): işbirliği kontrolleri, bağlantı durumu, güncelleme bildirimi, oturum açma butonu, oturum açılırken titreşen durum etiketi ve kullanıcı menüsü. Bu grup da sol grup gibi sol fare basma olayında yayılımı durdurur (aynı sürükleme çakışmasını önlemek için). Port hedefinde bu görünür metinleri `"Oturum Aç"` ve `"Oturum açılıyor…"` gibi Türkçe yazarsın.

Hangi parçanın görüneceği büyük ölçüde `TitleBarSettings` alanlarına bağlıdır (`show_project_items`, `show_branch_name`, `show_sign_in`, `show_user_menu` …). Ayarlar [4. bölümde](04-ayarlar-ve-uygulama-menusu.md) ayrıntılı işlenir.

## 4. İki render modu: menü içeride mi, ayrı satırda mı?

Render'ın sonunda `show_menus` değeri iki ayrı yerleşim seçer. Bu, ürün başlığında dikkat isteyen kararlardan biridir.

**Mod A — `show_menus == false` (tek satır):** Tüm ürün çocukları doğrudan platform kabuğuna teslim edilir ve sonuç yalnız platform kabuğudur:

```rust
self.platform_titlebar.update(cx, |baslik_cubugu, _| {
    baslik_cubugu.set_button_layout(buton_yerlesimi);
    baslik_cubugu.set_children(cocuklar);
});
self.platform_titlebar.clone()
```

Bu modda uygulama menüsü (varsa) sol grubun başına eklenmiştir; başlık tek satırdır.

**Mod B — `show_menus == true` (iki satır):** Platform kabuğuna yalnız **uygulama menüsü** çocuk olarak verilir; ürün içeriği ise platform kabuğunun altında ikinci bir satır olarak çizilir:

```rust
self.platform_titlebar.update(cx, |baslik_cubugu, _| {
    baslik_cubugu.set_button_layout(buton_yerlesimi);
    baslik_cubugu.set_children(
        self.application_menu
            .clone()
            .map(|uygulama_menusu| uygulama_menusu.into_any_element()),
    );
});

let yukseklik = platform_title_bar_height(window);
let baslik_cubugu_rengi = self
    .platform_titlebar
    .update(cx, |platform_basligi, cx| platform_basligi.title_bar_color(window, cx));

v_flex()
    .w_full()
    .child(self.platform_titlebar.clone())
    .child(
        h_flex()
            .bg(baslik_cubugu_rengi)
            .h(yukseklik)
            .pl_2()
            .justify_between()
            .w_full()
            .children(cocuklar),
    )
```

İkinci satır, platform kabuğuyla aynı `title_bar_color` ve aynı yüksekliği (`platform_title_bar_height`) kullanır; böylece iki satır görsel olarak tek bir başlık bloğu gibi durur. `justify_between` ile sol ve sağ ürün grupları iki uca yaslanır.

Bu mod ayrımının pratik sonucu: port hedefinde "menü açık mı?" kararı yalnız bir görünürlük bayrağı değildir; başlığın **kaç satır** olacağını da belirler. Menü ayrı satıra taşındığında ikinci satırın rengini ve yüksekliğini platform kabuğuyla eşitlemek gerekir, yoksa iki katman görsel olarak kopuk görünür.

## 5. `effective_active_worktree`: başlıkta hangi proje görünür

Başlık, birden çok çalışma ağacı açık olduğunda hangisini göstereceğine `effective_active_worktree` ile karar verir:

```rust
pub fn effective_active_worktree(&self, cx: &App) -> Option<Entity<project::Worktree>>
```

Mantık şudur: önce projenin aktif git deposunun bulunduğu çalışma ağacı tercih edilir; o yoksa ilk görünür çalışma ağacına düşülür. Böylece monorepo veya çoklu çalışma ağacı senaryolarında başlık, kullanıcının üzerinde çalıştığı depo-sahibi ağacı gösterir. Seçilen çalışma ağacına ait en spesifik depo da `get_repository_for_worktree` yardımıyla (en uzun eşleşen yolu seçerek) bulunur.

Port hedefinde tek çalışma ağaçlı bir uygulamada bu mantık tamamen basitleşir: gösterilecek tek bir proje/doküman vardır. Çoklu çalışma ağacı veya iç içe depo destekliyorsan, aynı "aktif olanı tercih et, yoksa ilkine düş" kuralını kendi modelinde kurarsın.
