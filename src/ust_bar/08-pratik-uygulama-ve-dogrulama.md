# Pratik uygulama, port ve doğrulama

Bu bölüm önceki konuları bir araya getirir: kendi ürün başlığını kurarken hangi parçaları nereden alacağın, Zed bağımlılıklarının port karşılıkları, sık yapılan hatalar ve teslim öncesi davranış doğrulama listesi.

## 1. Ürün başlığını kurma iskeleti

Kendi uygulamanda ürün başlığı, platform kabuğunu sahiplenen ve her render'da besleyen bir entity'dir. İskelet, [2. bölümdeki](02-kaynak-haritasi-ve-kopru.md) köprü kalıbının genişletilmiş hâlidir:

```rust
struct UrunBasligi {
    platform_kabugu: Entity<PlatformTitleBar>,
    proje_durumu: Entity<ProjeDurumu>,
    ayarlar: BaslikAyarlari,
    _abonelikler: Vec<Subscription>,
}

impl Render for UrunBasligi {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let mut child_grubu = Vec::new();
        child_grubu.push(self.sol_grubu_kur(cx));   // proje adı, branch, host
        child_grubu.push(self.sag_grubu_kur(cx));   // kullanıcı, güncelleme, durum

        self.platform_kabugu.update(cx, |kabuk, _| {
            kabuk.set_button_layout(self.ayarlar.button_layout);
            kabuk.set_children(child_grubu);
        });

        self.platform_kabugu.clone()
    }
}
```

Menüleri ayrı bir satıra taşıma ihtiyacın varsa, [3. bölümdeki](03-titlebar-entity-ve-render.md#4-i̇ki-render-modu-menü-içeride-mi-ayrı-satırda-mı) iki render modunu uygularsın: menü modunda platform kabuğuna yalnız menüyü ver, ürün içeriğini aynı renk ve yükseklikte ikinci bir satırda çiz.

## 2. Özelleştirme noktaları

| İhtiyaç | Yapılacak |
| :-- | :-- |
| Bir parçayı gizle/göster | Kendi `TitleBarSettings` muadilinde bir bayrak tut; render'da o parçayı koşula bağla. |
| Proje adı farklı bir kaynaktan gelmeli | `effective_active_worktree` kalıbını kendi aktif doküman/proje modelinle değiştir. |
| Branch göstergesi eklenmeli | Aktif branch'i kısaltarak göster, tıklamayı branch değiştirme yüzeyine bağla, opsiyonel durum ikonu ekle. |
| Menü ayrı satırda olmalı | Menü modunu (iki satır) etkinleştir; ikinci satırın rengini/yüksekliğini platform kabuğuyla eşitle. |
| Kullanıcı menüsü/sign-in | Oturum durum makinesini kur: açık → menü, açılıyor → geçici gösterge, kapalı → giriş. |
| Güncelleme bildirimi | Güncelleme durum yayınını izle; duruma göre buton çiz, süren işlemde butonu `disabled` yap. |
| Duyuru banner'ı | Tek banner entity'si + `visible_when` predicate + kalıcı kapatma kaydı. |
| Collab kontrolleri | Yalnız bir çağrı/işbirliği özelliğin varsa; toggle'ları küçük fonksiyonlara topla, butonları ince tetikleyici yap. |

## 3. Sık yapılan hatalar

- **Child'ları yalnız bir kez vermek.** `PlatformTitleBar`, child listesini render sırasında tüketir. Ürün başlığı her render'da `set_children(...)` çağırmazsa içerik ikinci frame'de kaybolur ve başlık boşalır.
- **İnteraktif element'lerde propagation'ı durdurmamak.** Başlığa konan butonlar, menüler ve tetikleyiciler kendi mouse-down/click olaylarında propagation'ı durdurmazsa, aynı tıklama alttaki sürükleme yüzeyini tetikleyip pencereyi yanlışlıkla taşır.
- **Menü kararını tek bir bayrak sanmak.** Menünün görünürlüğü hem ayara hem platforma bağlıdır (macOS'ta native menü tercih edilir); ayrıca menü açıkken başlık iki satıra çıkar. Bu kararı "göster/gizle" diye basitleştirmek macOS davranışını ve ikinci satır hizalamasını bozar.
- **Ürün parçalarını platform kabuğuna gömmek.** Proje adı, kullanıcı menüsü, collab gibi ürün mantığı platform kabuğunun içine yazılırsa kabuk tek bir uygulamaya kilitlenir ve yeniden kullanılamaz. Ürün içeriği her zaman ürün başlığı katmanında kalır.
- **Görünürlük ayarlarını atlamak.** Render'ı ayardan bağımsız yazıp her parçayı her zaman çizmek, kullanıcıya sade bir başlık sunma imkânını kaybettirir. Her parça bir görünürlük bayrağına bağlanmalıdır.
- **Güncelleme butonunu süren işlemde tıklanabilir bırakmak.** Checking/Downloading/Installing durumlarında buton devre dışı olmalıdır; aksi halde kullanıcı yarım kalan işlemi tekrar başlatabilir.
- **Collab/plan/banner gibi Zed'e özgü parçaları gereksiz taşımak.** Bu yüzeyler Zed'in ürün altyapısına bağlıdır; karşılığı olmayan bir uygulamada hiç kurulmamalıdır.

## 4. Davranış doğrulama listesi

Ürün başlığı entegrasyonu tamamlandığında aşağıdaki karar noktaları tek tek doğrulanır:

- `init` her çalışma alanı için bir ürün başlık entity'si kuruyor ve platform kabuğunu bir kez hazırlıyor mu?
- Ürün child'ları her render'da yeniden teslim ediliyor; başlık ikinci frame'de boşalmıyor mu?
- Menü modu (iki satır) etkinken ikinci satırın rengi ve yüksekliği platform kabuğuyla eşleşiyor mu? macOS'ta native menü tercih ediliyor mu?
- Proje adı, branch adı, host ve restricted mode göstergeleri ilgili görünürlük ayarlarına doğru tepki veriyor mu?
- Oturum durum makinesi (açık/açılıyor/kapalı) doğru çalışıyor; aynı anda yalnız bir hâl mi görünüyor?
- Güncelleme butonu, süren işlemler sırasında devre dışı mı? Tooltip "Update to Version:" kalıbını kullanıyor mu?
- Başlıktaki tüm interaktif element'ler sürükleme propagation'ını durduruyor mu (buton tıklaması pencereyi sürüklemiyor)?
- Collab/banner gibi opsiyonel parçalar, karşılığı olmayan bir uygulamada hiç kurulmamış mı?

Bu liste, ürün başlığının davranış paritesini gözden geçirmek için yeterlidir. API isimleri ve davranışlar bu rehberde anlatıldığı gibidir; bir API'nin güncel tam imzasını teyit etmek istersen Zed kaynağına bakman yeterlidir.
