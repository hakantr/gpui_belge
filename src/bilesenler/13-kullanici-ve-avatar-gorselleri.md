# 13. Kullanıcı ve Avatar Görselleri

Avatar ve Facepile bileşenleri, kullanıcı veya katılımcı (collaborator) görsellerini ekranda göstermek için kullanılır. Bu gösterim tek bir kişi olabileceği gibi küçük ve birbiriyle örtüşen bir grup halinde de kurulabilir. Görsel kaynağı yüklenemediğinde `Avatar` bileşeni `IconName::Person` yedeğine (fallback) döner; `Facepile` ise kendi yedeğini üretmez, içindeki avatarların davranışını taşır. Ayrıca gösterge, kenarlık (border) ve boyut gibi ayarlarla avatarın çevresine durum bilgisi eklenebilir.

Bu bileşenlerde iki kuralı baştan netleştirmek faydalıdır:

- Avatar kaynağı (`ImageSource`) görünüm (view) veya bir servis tarafında çözümlenir. Bileşene yalnızca hazır URL veya asset verilir; kaynak çözümleme işinin bileşen tarafından yapılması beklenmez.
- Birden fazla katılımcı yan yana gösterilecekse `Facepile`, tek bir katılımcı için ise doğrudan `Avatar` kullanılır.

## Avatar

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Avatar`, `ui::AvatarAudioStatusIndicator`, `ui::AvatarAvailabilityIndicator`, `ui::AudioStatus`, `ui::CollaboratorAvailability`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Avatar`.

Tavsiye Edilen Kullanım Alanları:

- Kullanıcı, katılımcı (collaborator), oturum ortağı (participant) veya commit yazarı görseli göstermek için.
- Avatar üzerinde bir mikrofon veya uygunluk göstergesi gerektiğinde.
- Facepile içinde küçük, kenarlıklı ve örtüşen avatarlar oluşturmak için.

Tercih Edilmemesi Gereken Durumlar:

- Genel bir ikon veya logo için `Icon` ya da `Vector` daha doğru bir araçtır.
- Avatar kaynağı yoksa ve yalnızca bir harf rozeti gerekiyorsa, doğrudan bir `div()` ile `Label` kombinasyonu amaca daha uygun bir çözüm sunar.

Temel API:

- `Avatar::new(src: impl Into<ImageSource>)`.
- `.grayscale(bool)`.
- `.border_color(color)`.
- `.size(size)`.
- `.indicator(element)`.
- `AvatarAudioStatusIndicator::new(AudioStatus::Muted | AudioStatus::Deafened)`.
- `AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free | Busy)`.

Avatar gösterge (indicator) API'leri:

| API | Rol |
| :-- | :-- |
| `AudioStatus` | Ses durumunu `Muted` veya `Deafened` olarak seçer. |
| `AvatarAudioStatusIndicator` | Avatar üzerinde mikrofon/ses durumu göstergesini render eder; ipucu (tooltip) bağlanabilir. |
| `CollaboratorAvailability` | Katılımcı durumunu `Free` veya `Busy` olarak taşır. |
| `AvatarAvailabilityIndicator` | Avatar köşesinde uygunluk noktasını çizer; `.avatar_size(...)` ile gerçek avatar ölçüsüne hizalanır. |

Davranış:

- Varsayılan avatar boyutu `1rem`'dir.
- Görsel yüklenemediğinde `IconName::Person` ikonu ile bir yedek render edilir.
- `border_color(...)` çağrısı avatar çevresinde `1px` bir kenarlık açar. Bu kenarlık, özellikle facepile gibi örtüşen görünümlerde avatarların arasında görsel bir boşluk oluşturmak için kullanılır.
- Gösterge, avatar kapsayıcısının bir çocuk (child) öğesi olarak render edilir; göstergenin konumu kendi elementinde mutlak (absolute) olarak ayarlanır.

Örnek:

```rust
use ui::{
    Avatar, AvatarAvailabilityIndicator, CollaboratorAvailability, prelude::*,
};

fn inceleyen_avatar_render() -> impl IntoElement {
    Avatar::new("https://avatars.githubusercontent.com/u/1714999?v=4")
        .size(px(28.))
        .border_color(gpui::transparent_black())
        .indicator(
            AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free)
                .avatar_size(px(28.)),
        )
}
```

Ses durumunu göstermek gerektiğinde, gösterge (indicator) yerine `AvatarAudioStatusIndicator` kullanılır:

```rust
use ui::{AudioStatus, Avatar, AvatarAudioStatusIndicator, prelude::*};

fn sesi_kapali_katilimci_render(avatar_adresi: SharedString) -> impl IntoElement {
    Avatar::new(avatar_adresi)
        .size(px(32.))
        .indicator(AvatarAudioStatusIndicator::new(AudioStatus::Muted))
}
```

Zed içinden kullanım örnekleri:

- `collab_ui` crate'i: İletişim ve katılımcı satırları.
- `title_bar` crate'i: Başlık çubuğu katılımcı avatarları.
- `editor` crate'i: Yazar (author) avatarları.

Dikkat Edilmesi Gereken Hususlar:

- `.size(...)` için hem `px(...)` hem de `rems(...)` kullanılabilir. Facepile içinde aynı boyutun korunması görsel açıdan daha temiz bir sonuç verir.
- Bir ses durumu için tooltip gerekiyorsa `AvatarAudioStatusIndicator::tooltip(...)` üzerinden bağlanır.
- Uygunluk göstergesi (availability indicator) için `.avatar_size(...)` değerinin gerçek avatar boyutuyla aynı verilmesi, gösterge noktasının oranını doğru hâle getirir.

## Facepile

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Facepile`, `ui::EXAMPLE_FACES`.
- Prelude: Hayır; ayrıca import edilmesi gerekir.
- Preview: `impl Component for Facepile`.

Tavsiye Edilen Kullanım Alanları:

- Aktif bir katılımcı, gözden geçiren (reviewer) veya oturum ortağı grubunu kompakt biçimde göstermek için.
- Yüzleri soldan sağa örtüştürerek küçük bir alanda birden fazla kişiyi göstermek istendiğinde.

Tercih Edilmemesi Gereken Durumlar:

- Tek bir kullanıcı için `Avatar` yeterlidir.
- Sıralı ve detaylı bir kullanıcı listesi için `ListItem` ile `Avatar` birlikte kullanılır.

Temel API:

- `Facepile::empty()`.
- `Facepile::new(faces: SmallVec<[AnyElement; 2]>)`.
- ParentElement: `.child(...)`, `.children(...)`.
- Kenar boşluğu (padding) stili yöntemleri desteklenir.

Örnek veri:

| API | Rol |
| :-- | :-- |
| `EXAMPLE_FACES` | Bileşen önizlemesi ve örnek kompozisyonlar için kullanılan hazır avatar URL listesidir; gerçek uygulama verisi yerine geçmez. |

Davranış:

- Render sırasında `flex_row_reverse()` kullanılır; bu sayede en sol yüz en üstte görünür ve doğal bir örtüşme elde edilir.
- İkinci ve sonraki yüzler `ml_neg_1()` ile birbirinin üzerine bindirilir.
- `Facepile` bir taşma (overflow) sayacı üretmez. Görüntülenen kişi sayısından daha fazlası varsa, kalan sayıyı belirtmek için `Chip` veya `CountBadge` gibi başka bir eleman ayrıca eklenir.

Örnek:

```rust
use ui::{Avatar, Facepile, prelude::*};

fn inceleyenler_render() -> impl IntoElement {
    Facepile::empty()
        .child(Avatar::new("https://avatars.githubusercontent.com/u/326587?s=60").size(px(24.)))
        .child(Avatar::new("https://avatars.githubusercontent.com/u/2280405?s=60").size(px(24.)))
        .child(Avatar::new("https://avatars.githubusercontent.com/u/1789?s=60").size(px(24.)))
}
```

Zed içinden kullanım örnekleri:

- `collab_ui` crate'i: Kanal ve katılımcı özetlerinde.
- `ui` crate'i: Varsayılan ve özel boyut önizleme örnekleri.

Dikkat Edilmesi Gereken Hususlar:

- Örtüşme görünümünün düzgün okunması için, avatar sınır renginin (border color) altındaki arka plan rengiyle eşleşmesi iyi bir tercih olur.
- Çok fazla avatarı yan yana sıkıştırmak yerine, ilk birkaç kişiyi gösterip kalan sayıyı ayrı bir göstergeyle belirtmek okunabilirliği korur.
