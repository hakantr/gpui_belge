# Rust GPUI

Bu depo, Zed ve GPUI ekosistemini Turkce anlatan bir mdBook calismasidir. Kitap; GPUI'nin cekirdek uygulama modelini, Zed `ui` bilesenlerini, workspace katmanini, ayar sistemini, tema yonetimini, asset akisini ve ust bar entegrasyonunu pratik bir gelistirici rehberi olarak toplar.

Yayinlanan kitap: <https://hakantr.github.io/gpui_belge/>

Kaynak anlatim, yerel Zed calisma alanindaki guncel kod agacina gore tutulur. Bu nedenle rehber bir gecmis surum uyumluluk dokumani degildir; amac, `$HOME/github/zed` reposunun mevcut HEAD durumundaki API yuzeyini ve kullanim disiplinini ogretmektir.

## Kitap Yapisi

Ana icindekiler [src/SUMMARY.md](src/SUMMARY.md) dosyasinda bulunur. Kitap su bolumlerden olusur:

- [GPUI Kullanimi](src/gpui_kullanimi/gpui_kullanimi.md): `App`, `WindowContext`, view/model akisi, render modeli, stiller, metin sistemi, olaylar, keymap, input ve test yuzeyi.
- [Zed UI Bilesenleri](src/bilesenler/bilesenler.md): Zed `ui` katmanindaki layout, metin, ikon, buton, form, menu, liste, tab, tablo, feedback, avatar ve picker bilesenleri.
- [Calisma Alani](src/calisma_alani/calisma_alani.md): `workspace` crate'inin dock, panel, pane, item, modal, notification, open/restore ve komut paleti modelleri.
- [Ayarlar](src/ayarlar/ayarlar.md): `settings` crate'i, `SettingsStore`, ayar dosyasi izleme, keymap dosyalari, EditorConfig ve VS Code ice aktarimi.
- [Tema Yonetimi](src/tema_yonetimi/tema_yonetimi.md): Zed uyumlu tema sozlesmesi, runtime tema modeli, JSON parse katmani, refinement, registry ve UI tuketimi.
- [Asset Yonetimi](src/assets/assets.md): `AssetSource`, `RustEmbed`, font, ikon, SVG, raster gorsel, ses ve JSON varlik akislari.
- [Ust Bar](src/ust_bar/ust_bar.md): Platform titlebar davranisi, pencere kontrolleri, native pencere sekmeleri ve urun titlebar'i entegrasyonu.

## Okuma Yolu

GPUI'ye yeni baslayanlar once `GPUI Kullanimi` bolumunu sirayla okumali, ardindan `Zed UI Bilesenleri` ile hazir tasarim sistemi katmanina gecmelidir. Zed benzeri bir uygulama iskeleti kuran okuyucular icin `Calisma Alani`, `Ayarlar`, `Tema Yonetimi` ve `Asset Yonetimi` bolumleri uygulama seviyesindeki servisleri tamamlar.

Belirli bir uygulama yuzeyi tasiyorsan:

- pencere, render ve event akisi icin `gpui_kullanimi/`,
- hazir component secimi icin `bilesenler/`,
- dock, pane, modal ve komut paleti icin `calisma_alani/`,
- tema ve renk sistemi icin `tema_yonetimi/`,
- gomulu varliklar icin `assets/`,
- platform baslik cubugu icin `ust_bar/` altindaki konu dosyalarina bak.

## Yerel Calistirma

mdBook kuruluysa kitabi yerelde derleyebilirsin:

```sh
mdbook build
```

Gelisim sirasinda canli onizleme icin:

```sh
mdbook serve --open
```

Kitap yapilandirmasi [book.toml](book.toml), bolum haritasi ise [src/SUMMARY.md](src/SUMMARY.md) tarafindan yonetilir.

## Dokumantasyon Ilkeleri

Bu kitapta framework ve Rust terimleri orijinal adlariyla korunur: `App`, `WindowContext`, `View`, `Model`, `Element`, `Render`, `Result`, `Option`, `Arc`, `cx` ve `window` gibi adlar cevrilmez. Ornek uygulama tarafinda tanimlanan struct, enum, fonksiyon ve degisken adlari ise Turkce tutulur.

Yeni veya degisen API'ler konu dosyalarina dagitilarak anlatilir; envanter sayfalarina yigilmaz. Kod ornekleri guncel kaynak API'leriyle uyumlu olmali, Rust idiomlarini izlemeli ve hata yonetiminde `Result`/`Option` ile `?` operatorunu tercih etmelidir.

## Kaynaklar

- Yerel Zed kaynak agaci: `$HOME/github/zed`
- Kitap icerigi: [src/](src/)
- Bolum haritasi: [src/SUMMARY.md](src/SUMMARY.md)
- mdBook ayarlari: [book.toml](book.toml)
