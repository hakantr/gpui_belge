# Pratik uygulama, port ve doğrulama

Bu bölüm önceki konuları bir araya getirir: kendi ürün başlığını kurarken hangi parçaları nereden alacağın, Zed bağımlılıklarının port karşılıkları, sık yapılan hatalar ve teslim öncesi davranış doğrulama listesi.

## 1. Ürün başlığını kurma iskeleti

Kendi uygulamanda ürün başlığı, platform kabuğunu sahiplenen ve her render geçişinde besleyen bir entity'dir. İskelet, [2. bölümdeki](02-kaynak-haritasi-ve-kopru.md) köprü kalıbının genişletilmiş halidir:

```rust
struct UrunBasligi {
    platform_kabugu: Entity<PlatformTitleBar>,
    proje_durumu: Entity<ProjeDurumu>,
    ayarlar: BaslikAyarlari,
    _abonelikler: Vec<Subscription>,
}

impl Render for UrunBasligi {
    fn render(&mut self, window: &mut Window, cx: &mut Context<Self>) -> impl IntoElement {
        let mut cocuk_grubu = Vec::new();
        cocuk_grubu.push(self.sol_grubu_kur(cx));   // proje adı, dal, sunucu
        cocuk_grubu.push(self.sag_grubu_kur(cx));   // kullanıcı, güncelleme, durum

        self.platform_kabugu.update(cx, |kabuk, _| {
            kabuk.set_button_layout(self.ayarlar.buton_yerlesimi);
            kabuk.set_children(cocuk_grubu);
        });

        self.platform_kabugu.clone()
    }
}
```

Menüleri ayrı bir satıra taşıma ihtiyacın varsa, [3. bölümdeki](03-titlebar-entity-ve-render.md#4-i̇ki-render-modu-menü-içeride-mi-ayrı-satırda-mı) iki render modunu uygularsın: menü modunda platform kabuğuna yalnız menüyü ver, ürün içeriğini aynı renk ve yükseklikte ikinci bir satırda çiz.

## 2. Özelleştirme noktaları

| İhtiyaç | Yapılacak |
| :-- | :-- |
| Bir parçayı gizle/göster | Kendi `TitleBarSettings` muadilinde bir bayrak tut; render geçişinde o parçayı koşula bağla. |
| Proje adı farklı bir kaynaktan gelmeli | `effective_active_worktree` kalıbını kendi aktif doküman/proje modelinle değiştir. |
| Dal göstergesi eklenmeli | Aktif dalı kısaltarak göster, tıklamayı dal değiştirme yüzeyine bağla, opsiyonel durum ikonu ekle. |
| Menü ayrı satırda olmalı | Menü modunu (iki satır) etkinleştir; ikinci satırın rengini/yüksekliğini platform kabuğuyla eşitle. |
| Kullanıcı menüsü/oturum açma | Oturum durum makinesini kur: açık -> menü, açılıyor -> geçici gösterge, kapalı -> giriş. |
| Güncelleme bildirimi | Güncelleme durum yayınını izle; duruma göre buton çiz, süren işlemde butonu `disabled` yap. |
| Duyuru bandı | Tek duyuru bandı entity'si + `visible_when` koşulu + kalıcı kapatma kaydı. |
| İşbirliği kontrolleri | Yalnız bir çağrı/işbirliği özelliğin varsa; geçişleri küçük fonksiyonlara topla, butonları ince tetikleyici yap. |

## 3. Sık yapılan hatalar

- **Çocuk elementleri yalnız bir kez vermek.** `PlatformTitleBar`, çocuk listesini render sırasında tüketir. Ürün başlığı her render geçişinde `set_children(...)` çağırmazsa içerik ikinci karede kaybolur ve başlık boşalır.
- **Etkileşimli elementlerde yayılımı durdurmamak.** Başlığa konan butonlar, menüler ve tetikleyiciler kendi fare basma/tıklama olaylarında yayılımı durdurmazsa, aynı tıklama alttaki sürükleme yüzeyini tetikleyip pencereyi yanlışlıkla taşır.
- **Menü kararını tek bir bayrak sanmak.** Menünün görünürlüğü hem ayara hem platforma bağlıdır (macOS'ta yerel menü tercih edilir); ayrıca menü açıkken başlık iki satıra çıkar. Bu kararı "göster/gizle" diye basitleştirmek macOS davranışını ve ikinci satır hizalamasını bozar.
- **Ürün parçalarını platform kabuğuna gömmek.** Proje adı, kullanıcı menüsü, işbirliği gibi ürün mantığı platform kabuğunun içine yazılırsa kabuk tek bir uygulamaya kilitlenir ve yeniden kullanılamaz. Ürün içeriği her zaman ürün başlığı katmanında kalır.
- **Görünürlük ayarlarını atlamak.** Render geçişini ayardan bağımsız yazıp her parçayı her zaman çizmek, kullanıcıya sade bir başlık sunma imkanını kaybettirir. Her parça bir görünürlük bayrağına bağlanmalıdır.
- **Güncelleme butonunu süren işlemde tıklanabilir bırakmak.** `Checking`/`Downloading`/`Installing` durumlarında buton devre dışı olmalıdır; aksi halde kullanıcı yarım kalan işlemi tekrar başlatabilir.
- **İşbirliği/plan/duyuru bandı gibi Zed'e özgü parçaları gereksiz taşımak.** Bu yüzeyler Zed'in ürün altyapısına bağlıdır; karşılığı olmayan bir uygulamada hiç kurulmamalıdır.

## 4. Davranış doğrulama listesi

Ürün başlığı entegrasyonu tamamlandığında aşağıdaki karar noktaları tek tek doğrulanır:

- `init` her çalışma alanı için bir ürün başlık entity'si kuruyor ve platform kabuğunu bir kez hazırlıyor mu?
- Ürün çocukları her render geçişinde yeniden teslim ediliyor; başlık ikinci karede boşalmıyor mu?
- Menü modu (iki satır) etkinken ikinci satırın rengi ve yüksekliği platform kabuğuyla eşleşiyor mu? macOS'ta yerel menü tercih ediliyor mu?
- Proje adı, dal adı, sunucu ve kısıtlı mod göstergeleri ilgili görünürlük ayarlarına doğru tepki veriyor mu?
- Oturum durum makinesi (açık/açılıyor/kapalı) doğru çalışıyor; aynı anda yalnız bir hâl mi görünüyor?
- Güncelleme butonu, süren işlemler sırasında devre dışı mı? İpucu `"Sürüme Güncelle:"` kalıbını kullanıyor mu?
- Başlıktaki tüm etkileşimli elementler sürükleme yayılımını durduruyor mu (buton tıklaması pencereyi sürüklemiyor)?
- İşbirliği/duyuru bandı gibi opsiyonel parçalar, karşılığı olmayan bir uygulamada hiç kurulmamış mı?

Bu liste, ürün başlığının davranış paritesini gözden geçirmek için yeterlidir. API isimleri ve davranışlar bu rehberde anlatıldığı gibidir; bir API'nin güncel tam imzasını teyit etmek istersen Zed kaynağına bakman yeterlidir.
