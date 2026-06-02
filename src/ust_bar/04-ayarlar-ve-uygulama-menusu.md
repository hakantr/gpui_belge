# Ayarlar ve uygulama menüsü

Ürün başlığının neyi gösterip neyi gizleyeceği tek bir ayar tipiyle yönetilir. Uygulama menüsü ise platforma göre ya işletim sistemine bırakılır ya da Zed tarafından çizilir. Bu iki konu birlikte ele alınır, çünkü menünün çizilip çizilmeyeceği de bir ayara bağlıdır.

## 1. `TitleBarSettings`: görünürlük sözleşmesi

Başlık çubuğunun her bölümü `TitleBarSettings` içindeki bir alanla açılıp kapatılır:

```rust
pub struct TitleBarSettings {
    pub show_branch_status_icon: bool,
    pub show_onboarding_banner: bool,
    pub show_user_picture: bool,
    pub show_branch_name: bool,
    pub show_project_items: bool,
    pub show_sign_in: bool,
    pub show_user_menu: bool,
    pub show_menus: bool,
    pub button_layout: Option<WindowButtonLayout>,
}
```

| Alan | Etkisi |
| :-- | :-- |
| `show_branch_status_icon` | Git branch yanındaki durum ikonu (temiz/değişmiş/çakışma). |
| `show_onboarding_banner` | Onboarding/duyuru banner'ının render yolu açık mı. |
| `show_user_picture` | Kullanıcı menüsünde avatar/profil resmi gösterilsin mi. |
| `show_branch_name` | Git branch adı metni gösterilsin mi. |
| `show_project_items` | Proje adı ve host göstergesi gösterilsin mi. |
| `show_sign_in` | Oturum kapalıyken "Sign In" butonu çizilsin mi. |
| `show_user_menu` | Kullanıcı menüsü butonu çizilsin mi. |
| `show_menus` | Uygulama menüsü başlıkta gösterilsin mi (ve hangi render modu seçilsin). |
| `button_layout` | Linux/FreeBSD pencere butonu yerleşimi; platform kabuğuna iletilir. |

Bu ayar tipi runtime tarafıdır. Kullanıcının `settings.json` dosyasından okunan dış veri tipi `settings_content::title_bar::TitleBarSettingsContent`'tir; tüm alanları `Option<...>` sarmalındadır ve `TitleBarSettings`'e bu içerikten üretilir. `button_layout` alanı özel bir dönüşümle (`WindowButtonLayoutContent::into_layout`) `WindowButtonLayout`'a çevrilir; bu dönüşüm Linux/FreeBSD dışında `None` döner.

Port hedefinde aynı yaklaşımı izlersin: başlığın her parçası için bir görünürlük bayrağı tutan tek bir ayar struct'ı tanımlarsın ve render sırasında her parçayı bu bayrağa göre koşullu çizersin. Render kodunu ayardan bağımsız yazıp parçaları her zaman çizmek, kullanıcıya sade bir başlık sunma imkânını baştan kaybettirir.

## 2. `show_menus`: menü görünürlüğü ve platform farkı

Menünün başlıkta çizilip çizilmeyeceğine `show_menus` yardımcısı karar verir:

```rust
pub(crate) fn show_menus(cx: &mut App) -> bool
```

Mantık iki katmanlıdır:

- Önce `TitleBarSettings` içindeki `show_menus` ayarı okunur.
- Sonra platform koşulu uygulanır: **macOS'ta** istemci tarafı menü yalnız `ZED_USE_CROSS_PLATFORM_MENU` ortam değişkeni tanımlıysa gösterilir; aksi halde macOS'un native menü çubuğu kullanılır ve `show_menus` etkisini yitirir. **Linux ve Windows'ta** ayar açıksa menü her zaman istemci tarafında çizilir.

Bu yüzden "menüler nerede?" sorusunun cevabı tek bir ayara değil, ayar ve platformun birlikte verdiği karara bağlıdır. [3. bölümde](03-titlebar-entity-ve-render.md#4-i̇ki-render-modu-menü-içeride-mi-ayrı-satırda-mı) görüldüğü gibi bu karar aynı zamanda başlığın tek mi iki satır mı olacağını belirler.

## 3. `ApplicationMenu`: istemci tarafı menü çubuğu

`ApplicationMenu`, Zed kaynağında private bir modüldedir; crate dışına açılmaz ve `TitleBar` içinde child entity olarak yaşar. Görevi, native menü çubuğunun kullanılmadığı durumlarda (Linux/Windows veya `ZED_USE_CROSS_PLATFORM_MENU` ile macOS) File/Edit/View gibi menüleri başlıkta çizmektir.

Menü girişleri statik değildir: `ApplicationMenu::new`, menü listesini doğrudan uygulamanın menü kaydından (GPUI'nin sağladığı menü tanımları) okur. Böylece menü içeriği uygulamanın action/menü tanımlarıyla otomatik aynı kalır.

Davranışsal yüzeyi şu metotlardan oluşur:

```rust
pub fn new(_: &mut Window, cx: &mut Context<Self>) -> Self
pub fn open_menu(&mut self, action: &OpenApplicationMenu, window: &mut Window, cx: &mut Context<Self>)
pub fn navigate_menus_in_direction(&mut self, direction: ActivateDirection, window: &mut Window, cx: &mut Context<Self>)
pub fn all_menus_shown(&self, cx: &mut Context<Self>) -> bool
```

- `open_menu`, `OpenApplicationMenu(String)` action'ındaki menü adını alıp ilgili menüyü açmaya işaretler. (Yalnız macOS dışı.)
- `navigate_menus_in_direction`, açık menüden sağa veya sola komşu menüye döngüsel olarak geçer; `ActivateMenuLeft` / `ActivateMenuRight` action'larıyla tetiklenir. (Yalnız macOS dışı.)
- `all_menus_shown`, menü çubuğunun fiilen görünür olup olmadığını söyler; bu bilgi `TitleBar` render'ında proje öğelerinin menüyle çakışmaması için kullanılır.

Menü açılışı popover tabanlıdır: her menü bir tetikleyiciye ve bir popover'a sahiptir; menü üzerine gelince (hover) açılır, klavyeyle yukarı/aşağı gezinilir, `Escape` ile kapanır ve sağ/sol action'larıyla komşu menüye geçilir.

## 4. Menüye bağlı action'lar

```rust
#[action(namespace = app_menu)]
pub struct OpenApplicationMenu(String);   // açılacak menü adını taşır

pub enum ActivateDirection { Left, Right }  // menüler arası yön

ActivateMenuLeft   // soldaki menüye geç
ActivateMenuRight  // sağdaki menüye geç
```

Bu action'lar yalnız istemci tarafı menü çiziminde anlamlıdır. macOS'un native menü çubuğunda etkisizdirler; bu yüzden `init` içinde yalnız macOS dışında kayıtlıdırlar. Bir başka deyişle aynı klavye kısayolları macOS'ta sistem menüsüne, diğer platformlarda Zed'in kendi menü çubuğuna bağlanır.

## 5. Port hedefi için

İstemci tarafı menü, Zed'e özgü bir yüzey değildir; menü çubuğunu kendisi çizen her uygulamanın ihtiyaç duyduğu genel bir kalıptır. Port ederken üç şeyi kendi tarafında karşılarsın:

- **Menü kaynağı:** Zed menüleri uygulamanın menü kaydından dinamik okur. Sen menüleri ister statik tanımla, ister kendi durum ağacından üret; önemli olan başlığın bu kaynağı tek bir yerden okumasıdır.
- **Platform kararı:** macOS'ta native menü çubuğunu kullanmak çoğu zaman doğru tercihtir; Linux/Windows'ta menüyü kendin çizersin. Bu kararı bir ayar + platform kontrolüyle (Zed'in `show_menus` kalıbı gibi) tek noktada ver.
- **Klavye gezinmesi:** Menüler arası sağ/sol geçiş ve menü-içi yukarı/aşağı gezinme, istemci tarafı menüde senin sorumluluğundur. Bu davranışı action'lara bağlamak, hem klavye erişilebilirliğini sağlar hem de macOS/diğer platform ayrımını temiz tutar.
