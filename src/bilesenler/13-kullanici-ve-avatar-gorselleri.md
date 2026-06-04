# 13. Kullanıcı ve Avatar Görselleri

Avatar ve Facepile bileşenleri, kullanıcı veya collaborator görsellerini ekranda göstermek için kullanılır. Bu gösterim tek bir kişi olabilir ya da küçük, örtüşen bir grup halinde kurulabilir. Görsel kaynağı yüklenemezse her ikisi de yedek bir ikona döner. Ayrıca gösterge, border ve boyut gibi ayarlarla avatarın çevresine durum bilgisi ekleyebilirsin.

Bu bileşenlerde iki kuralı baştan netleştirmek faydalıdır:

- Avatar kaynağı (`ImageSource`) view veya bir servis tarafında çözümlenir. Bileşene yalnızca hazır URL veya asset verilir; kaynak çözümleme işini bileşenin yapması beklenmez.
- Birden fazla katılımcı yan yana gösterilecekse `Facepile`, tek bir katılımcı için doğrudan `Avatar` kullanırsın.

## Avatar

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Avatar`, `ui::AvatarAudioStatusIndicator`, `ui::AvatarAvailabilityIndicator`, `ui::AudioStatus`, `ui::CollaboratorAvailability`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Avatar`.

Ne zaman kullanırsın:

- Kullanıcı, collaborator, participant veya commit author görseli göstermek için.
- Avatar üzerinde bir mikrofon veya uygunluk göstergesi gerektiğinde.
- Facepile içinde küçük, border'lı ve örtüşen avatarlar için.

Ne zaman kullanmazsın:

- Genel bir icon veya logo için `Icon` ya da `Vector` daha doğru bir araçtır.
- Avatar kaynağı yoksa ve yalnızca bir harf rozeti gerekiyorsa, doğrudan bir `div()` ile `Label` kombinasyonu okuyucuya niyeti daha açık aktarır.

Temel API:

- `Avatar::new(src: impl Into<ImageSource>)`.
- `.grayscale(bool)`.
- `.border_color(color)`.
- `.size(size)`.
- `.indicator(element)`.
- `AvatarAudioStatusIndicator::new(AudioStatus::Muted | AudioStatus::Deafened)`.
- `AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free | Busy)`.

Avatar indicator API'leri:

| API | Rol |
| :-- | :-- |
| `AudioStatus` | Ses durumunu `Muted` veya `Deafened` olarak seçer. |
| `AvatarAudioStatusIndicator` | Avatar üzerinde mikrofon/ses durumu göstergesini render eder; tooltip bağlanabilir. |
| `CollaboratorAvailability` | Collaborator durumunu `Free` veya `Busy` olarak taşır. |
| `AvatarAvailabilityIndicator` | Avatar köşesinde uygunluk noktasını çizer; `.avatar_size(...)` ile gerçek avatar ölçüsüne hizalanır. |

Davranış:

- Varsayılan avatar boyutu `1rem`'dir.
- Görsel yüklenemediğinde `IconName::Person` ikonu ile bir yedek render edilir.
- `border_color(...)` çağrısı avatar çevresinde `1px` bir border açar. Bu border, özellikle facepile gibi örtüşen görünümlerde avatarların arasında görsel bir boşluk yaratmak için kullanılır.
- Gösterge, avatar kapsayıcısının bir child'ı olarak render edilir; göstergenin konumu kendi elementinde absolute olarak ayarlanır.

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

Ses durumunu göstermek gerektiğinde, indicator yerine `AvatarAudioStatusIndicator` kullanırsın:

```rust
use ui::{AudioStatus, Avatar, AvatarAudioStatusIndicator, prelude::*};

fn sesi_kapali_katilimci_render(avatar_adresi: SharedString) -> impl IntoElement {
    Avatar::new(avatar_adresi)
        .size(px(32.))
        .indicator(AvatarAudioStatusIndicator::new(AudioStatus::Muted))
}
```

Zed içinden kullanım örnekleri:

- `collab_ui` crate'i: contact ve participant satırları.
- `title_bar` crate'i: title bar collaborator avatarları.
- `editor` crate'i: author avatarları.

Dikkat edeceğin noktalar:

- `.size(...)` için hem `px(...)` hem de `rems(...)` kullanabilirsin. Facepile içinde aynı boyutun korunması görsel olarak çok daha temiz bir sonuç verir.
- Bir ses durumu için tooltip gerekiyorsa `AvatarAudioStatusIndicator::tooltip(...)` üzerinden bağlanır.
- Availability indicator için `.avatar_size(...)` değerinin gerçek avatar boyutuyla aynı verilmesi, gösterge noktasının oranını doğru hâle getirir.

## Facepile

Kaynak:

- Tanım: `ui` crate'i
- Export: `ui::Facepile`, `ui::EXAMPLE_FACES`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Facepile`.

Ne zaman kullanırsın:

- Aktif bir collaborator, reviewer veya participant grubunu kompakt biçimde göstermek için.
- Yüzleri soldan sağa örtüştürerek küçük bir alanda birden fazla kişiyi göstermek istendiğinde.

Ne zaman kullanmazsın:

- Tek bir kullanıcı için `Avatar` yeterlidir.
- Sıralı ve detaylı bir kullanıcı listesi için `ListItem` ile `Avatar` birlikte kullanırsın.

Temel API:

- `Facepile::empty()`.
- `Facepile::new(faces: SmallVec<[AnyElement; 2]>)`.
- ParentElement: `.child(...)`, `.children(...)`.
- Padding style yöntemleri desteklenir.

Örnek veri:

| API | Rol |
| :-- | :-- |
| `EXAMPLE_FACES` | Bileşen önizlemesi ve örnek kompozisyonlar için kullanılan hazır avatar URL listesidir; gerçek uygulama verisi yerine geçmez. |

Davranış:

- Render sırasında `flex_row_reverse()` kullanılır; bu sayede en sol yüz en üstte görünür ve doğal bir örtüşme elde edilir.
- İkinci ve sonraki yüzler `ml_neg_1()` ile birbirinin üzerine bindirilir.
- `Facepile` bir overflow sayacı üretmez. Görüntülenen kişi sayısından daha fazlası varsa, kalan sayıyı belirtmek için `Chip` veya `CountBadge` gibi başka bir eleman ayrıca eklersin.

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

- `collab_ui` crate'i: channel ve participant özetlerinde.
- `ui` crate'i: default ve özel boyut önizleme örnekleri.

Dikkat edeceğin noktalar:

- Örtüşme görünümünün düzgün okunması için, avatar border renginin üst arka plan ile eşleşmesi iyi bir tercih olur.
- Çok fazla avatarı yan yana sıkıştırmak yerine, ilk birkaç kişiyi gösterip kalan sayıyı ayrı bir göstergeyle belirtmek okunabilirliği korur.
