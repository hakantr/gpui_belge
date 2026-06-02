# `TitleBar` entity'si, `init` ve iki render modu

Bu bölüm ürün başlığının çekirdeğini anlatır: `TitleBar` entity'si nasıl kurulur, `init` ile uygulamaya nasıl bağlanır ve her render'da iki ayrı moddan birini neden seçer. Sonraki bölümlerdeki tek tek göstergeler bu çekirdeğin üstüne oturur.

## 1. `init`: her `Workspace` için bir `TitleBar`

Crate'in giriş noktası `init` fonksiyonudur:

```rust
pub fn init(cx: &mut App)
```

`init` iki iş yapar. Önce platform kabuğunu hazırlamak için `PlatformTitleBar::init(cx)` çağırır. Sonra `cx.observe_new(...)` ile her yeni `Workspace` açıldığında bir `TitleBar` entity'si üretir ve bunu `workspace.set_titlebar_item(...)` ile workspace'in başlık alanına yerleştirir:

```rust
pub fn init(cx: &mut App) {
    platform_title_bar::PlatformTitleBar::init(cx);

    cx.observe_new(|workspace: &mut Workspace, window, cx| {
        let Some(window) = window else { return };
        let multi_workspace = workspace.multi_workspace().cloned();
        let item = cx.new(|cx| TitleBar::new("title-bar", workspace, multi_workspace, window, cx));
        workspace.set_titlebar_item(item.into(), window, cx);
        // ... action kayıtları
    })
    .detach();
}
```

Aynı blokta birkaç action workspace'e bağlanır: `SimulateUpdateAvailable` (güncelleme yüzeyini test için), ve yalnız macOS dışında `OpenApplicationMenu`, `ActivateMenuLeft`, `ActivateMenuRight` (uygulama menüsünü açma ve menüler arası gezinme). Bu action'lar workspace üzerinden gelir, başlık item'ını bulur ve ilgili `TitleBar` metoduna yönlendirir.

Port hedefinde aynı kalıbı kurarsın: uygulama başlangıcında platform kabuğunu hazırla, sonra her pencere/çalışma alanı için bir ürün başlık entity'si üretip pencereye bağla.

## 2. `TitleBar::new`: alanlar ve subscription'lar

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
| `platform_titlebar` | Beslenen platform kabuğu | strong `Entity` |
| `project` | Proje, worktree'ler, git deposu | strong |
| `user_store` | Oturum açan kullanıcı, plan, avatar | strong |
| `client` | Bağlantı durumu, oturum, uzak sunucu | `Arc<Client>` |
| `workspace` | Çalışma alanı | **weak** (döngü önlemek için) |
| `multi_workspace` | Sidebar/çoklu pencere kaynağı | opsiyonel **weak** |
| `application_menu` | İstemci tarafı menü | opsiyonel child entity |
| `update_version` | Güncelleme bildirimi | child entity |
| `banner` | Onboarding banner | opsiyonel; güncel HEAD'de `None` |

`new` ayrıca bir dizi subscription kurar; her biri ilgili durum değiştiğinde `cx.notify()` ile yeniden render tetikler: workspace değişimi, aktif çağrı (`ActiveCall`), pencere aktivasyonu, git store olayları (aktif repo/repo güncellemesi), kullanıcı store, worktree oluşturma, pencere butonu yerleşimi değişimi ve — varsa — güvenilir worktree (`TrustedWorktrees`) değişimi. Bu subscription'lar, başlığın dört hızlı değişen alanını (proje, branch, bağlantı, kullanıcı) güncel tutmanın yoludur.

`application_menu` alanı platforma göre kurulur: macOS'ta yalnız `ZED_USE_CROSS_PLATFORM_MENU` ortam değişkeni varsa, Linux ve Windows'ta ise her zaman bir `ApplicationMenu` entity'si üretilir. macOS'ta varsayılan olarak `None` kalır; çünkü orada native menü çubuğu kullanılır.

## 3. Render: child grubunun hazırlanması

`TitleBar::render`, ürün child'larını sabit kapasiteli bir `ArrayVec` içinde toplar. Sıra ve içerik şudur:

1. **Sol grup** (`h_flex`): `show_menus` kapalıysa uygulama menüsü, ardından restricted mode göstergesi, proje host'u, proje adı ve git branch yüzeyi. Bu grup sol mouse-down'da propagation'ı durdurur (sürükleme ile çakışmasın).
2. **Katılımcı listesi**: aktif çağrıda proje paylaşımı katılımcıları.
3. **Onboarding banner**: yalnız `show_onboarding_banner` ayarı açık ve `banner` alanı `Some` ise. (Güncel HEAD'de `banner` her zaman `None` olduğu için pratikte çizilmez; ayrıntı [7. bölümde](07-kullanici-update-banner.md).)
4. **Sağ grup** (`h_flex`): collab kontrolleri, bağlantı durumu, güncelleme bildirimi, koşula göre "Sign In" butonu, oturum açılırken titreşen "Signing in…" etiketi ve kullanıcı menüsü.

Hangi parçanın görüneceği büyük ölçüde `TitleBarSettings` alanlarına bağlıdır (`show_project_items`, `show_branch_name`, `show_sign_in`, `show_user_menu` …). Ayarlar [4. bölümde](04-ayarlar-ve-uygulama-menusu.md) ayrıntılı işlenir.

## 4. İki render modu: menü içeride mi, ayrı satırda mı?

Render'ın sonunda `show_menus` değeri iki ayrı yerleşim seçer. Bu, ürün başlığının en kolay kaçırılan kararıdır.

**Mod A — `show_menus == false` (tek satır):** Tüm ürün child'ları doğrudan platform kabuğuna teslim edilir ve sonuç yalnız platform kabuğudur:

```rust
self.platform_titlebar.update(cx, |this, _| {
    this.set_button_layout(button_layout);
    this.set_children(children);
});
self.platform_titlebar.clone()
```

Bu modda uygulama menüsü (varsa) sol grubun başına eklenmiştir; başlık tek satırdır.

**Mod B — `show_menus == true` (iki satır):** Platform kabuğuna yalnız **uygulama menüsü** child olarak verilir; ürün içeriği ise platform kabuğunun altında ikinci bir satır olarak çizilir:

```rust
self.platform_titlebar.update(cx, |this, _| {
    this.set_button_layout(button_layout);
    this.set_children(self.application_menu.clone().map(|menu| menu.into_any_element()));
});

let height = platform_title_bar_height(window);
let title_bar_color = self.platform_titlebar.update(cx, |pt, cx| pt.title_bar_color(window, cx));

v_flex()
    .w_full()
    .child(self.platform_titlebar.clone())
    .child(
        h_flex().bg(title_bar_color).h(height).pl_2().justify_between().w_full()
            .children(children),
    )
```

İkinci satır, platform kabuğuyla aynı `title_bar_color` ve aynı yüksekliği (`platform_title_bar_height`) kullanır; böylece iki satır görsel olarak tek bir başlık bloğu gibi durur. `justify_between` ile sol ve sağ ürün grupları iki uca yaslanır.

Bu mod ayrımının pratik sonucu: port hedefinde "menü açık mı?" kararı yalnız bir görünürlük bayrağı değildir; başlığın **kaç satır** olacağını da belirler. Menü ayrı satıra taşındığında ikinci satırın rengini ve yüksekliğini platform kabuğuyla eşitlemek gerekir, yoksa iki katman görsel olarak kopuk görünür.

## 5. `effective_active_worktree`: başlıkta hangi proje görünür

Başlık, birden çok worktree açık olduğunda hangisini göstereceğine `effective_active_worktree` ile karar verir:

```rust
pub fn effective_active_worktree(&self, cx: &App) -> Option<Entity<project::Worktree>>
```

Mantık şudur: önce projenin aktif git deposunun bulunduğu worktree tercih edilir; o yoksa ilk görünür worktree'ye düşülür. Böylece monorepo veya çoklu worktree senaryolarında başlık, kullanıcının üzerinde çalıştığı depo-sahibi ağacı gösterir. Seçilen worktree'ye ait en spesifik depo da `get_repository_for_worktree` yardımıyla (en uzun eşleşen yolu seçerek) bulunur.

Port hedefinde tek worktree'li bir uygulamada bu mantık tamamen basitleşir: gösterilecek tek bir proje/doküman vardır. Çoklu worktree veya nested depo destekliyorsan, aynı "aktif olanı tercih et, yoksa ilkine düş" kuralını kendi modelinde kurarsın.
