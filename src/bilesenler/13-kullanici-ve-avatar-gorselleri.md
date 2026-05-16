# 13. Kullanıcı ve Avatar Görselleri

Avatar ve Facepile bileşenleri, kullanıcı veya collaborator görsellerini ekranda göstermek için kullanılır. Bu gösterim tek bir kişi olabilir ya da küçük, örtüşen bir grup halinde kurulabilir. Görsel kaynağı yüklenemezse her ikisi de fallback bir ikona döner. Ayrıca indicator, border ve boyut gibi ayarlarla avatarın çevresine durum bilgisi eklenebilir.

Bu bileşenlerde iki kuralı baştan netleştirmek faydalıdır:

- Avatar kaynağı (`ImageSource`) view veya bir servis tarafında çözümlenir. Component'e yalnızca hazır URL veya asset verilir; kaynak çözümleme işini component'in yapması beklenmez.
- Birden fazla katılımcı yan yana gösterilecekse `Facepile`, tek bir katılımcı için doğrudan `Avatar` kullanılır.

## Avatar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/avatar.rs`
- Export: `ui::Avatar`, `ui::AvatarAudioStatusIndicator`, `ui::AvatarAvailabilityIndicator`, `ui::AudioStatus`, `ui::CollaboratorAvailability`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Avatar`.

Ne zaman kullanılır:

- Kullanıcı, collaborator, participant veya commit author görseli göstermek için.
- Avatar üzerinde bir microphone veya availability göstergesi gerektiğinde.
- Facepile içinde küçük, border'lı ve overlap eden avatarlar için.

Ne zaman kullanılmaz:

- Genel bir icon veya logo için `Icon` ya da `Vector` daha doğru bir araçtır.
- Avatar kaynağı yoksa ve yalnızca bir harf badge'i gerekiyorsa, doğrudan bir `div()` ile `Label` kombinasyonu okuyucuya niyeti daha açık aktarır.

Temel API:

- `Avatar::new(src: impl Into<ImageSource>)`.
- `.grayscale(bool)`.
- `.border_color(color)`.
- `.size(size)`.
- `.indicator(element)`.
- `AvatarAudioStatusIndicator::new(AudioStatus::Muted | AudioStatus::Deafened)`.
- `AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free | Busy)`.

Davranış:

- Varsayılan avatar boyutu `1rem`'dir.
- Görsel yüklenemediğinde `IconName::Person` ikonu ile bir fallback render edilir.
- `border_color(...)` çağrısı avatar çevresinde `1px` bir border açar. Bu border, özellikle facepile gibi overlap görünümlerinde avatarların arasında görsel bir boşluk yaratmak için kullanılır.
- Indicator, avatar container'ının bir child'ı olarak render edilir; indicator'ın konumu kendi elementinde absolute olarak ayarlanır.

Örnek:

```rust
use ui::{
    Avatar, AvatarAvailabilityIndicator, CollaboratorAvailability, prelude::*,
};

fn render_reviewer_avatar() -> impl IntoElement {
    Avatar::new("https://avatars.githubusercontent.com/u/1714999?v=4")
        .size(px(28.))
        .border_color(gpui::transparent_black())
        .indicator(
            AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free)
                .avatar_size(px(28.)),
        )
}
```

Ses durumunu göstermek gerektiğinde, indicator yerine `AvatarAudioStatusIndicator` kullanılır:

```rust
use ui::{AudioStatus, Avatar, AvatarAudioStatusIndicator, prelude::*};

fn render_muted_participant(avatar_url: SharedString) -> impl IntoElement {
    Avatar::new(avatar_url)
        .size(px(32.))
        .indicator(AvatarAudioStatusIndicator::new(AudioStatus::Muted))
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/collab_ui/src/collab_panel.rs`: contact ve participant satırları.
- `../zed/crates/title_bar/src/collab.rs`: title bar collaborator avatarları.
- `../zed/crates/editor/src/git.rs`: author avatarları.

Dikkat edilecek noktalar:

- `.size(...)` için hem `px(...)` hem de `rems(...)` kullanılabilir. Facepile içinde aynı boyutun korunması görsel olarak çok daha temiz bir sonuç verir.
- Bir audio status için tooltip gerekiyorsa `AvatarAudioStatusIndicator::tooltip(...)` üzerinden bağlanır.
- Availability indicator için `.avatar_size(...)` değerinin gerçek avatar boyutuyla aynı verilmesi, indicator noktasının oranını doğru hâle getirir.

## Facepile

Kaynak:

- Tanım: `../zed/crates/ui/src/components/facepile.rs`
- Export: `ui::Facepile`, `ui::EXAMPLE_FACES`.
- Prelude: Hayır; ayrıca import edilir.
- Preview: `impl Component for Facepile`.

Ne zaman kullanılır:

- Aktif bir collaborator, reviewer veya participant grubunu kompakt biçimde göstermek için.
- Yüzleri soldan sağa overlap ederek küçük bir alanda birden fazla kişiyi göstermek istendiğinde.

Ne zaman kullanılmaz:

- Tek bir kullanıcı için `Avatar` yeterlidir.
- Sıralı ve detaylı bir kullanıcı listesi için `ListItem` ile `Avatar` birlikte kullanılır.

Temel API:

- `Facepile::empty()`.
- `Facepile::new(faces: SmallVec<[AnyElement; 2]>)`.
- ParentElement: `.child(...)`, `.children(...)`.
- Padding style yöntemleri desteklenir.

Davranış:

- Render sırasında `flex_row_reverse()` kullanılır; bu sayede en sol yüz en üstte görünür ve doğal bir overlap elde edilir.
- İkinci ve sonraki yüzler `ml_neg_1()` ile birbirinin üzerine bindirilir.
- `Facepile` bir overflow sayacı üretmez. Görüntülenen kişi sayısından daha fazlası varsa, kalan sayıyı belirtmek için `Chip` veya `CountBadge` gibi başka bir eleman ayrıca eklenir.

Örnek:

```rust
use ui::{Avatar, Facepile, prelude::*};

fn render_reviewers() -> impl IntoElement {
    Facepile::empty()
        .child(Avatar::new("https://avatars.githubusercontent.com/u/326587?s=60").size(px(24.)))
        .child(Avatar::new("https://avatars.githubusercontent.com/u/2280405?s=60").size(px(24.)))
        .child(Avatar::new("https://avatars.githubusercontent.com/u/1789?s=60").size(px(24.)))
}
```

Zed içinden kullanım örnekleri:

- `../zed/crates/collab_ui/src/collab_panel.rs`: channel ve participant özetlerinde.
- `../zed/crates/ui/src/components/facepile.rs`: default ve custom size preview örnekleri.

Dikkat edilecek noktalar:

- Overlap görünümünün düzgün okunması için, avatar border renginin parent background ile eşleşmesi iyi bir tercih olur.
- Çok fazla avatarı yan yana sıkıştırmak yerine, ilk birkaç kişiyi gösterip kalan sayıyı ayrı bir göstergeyle belirtmek okunabilirliği korur.
