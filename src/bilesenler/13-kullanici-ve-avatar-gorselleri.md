# 13. Kullanıcı ve Avatar Görselleri

Avatar ve Facepile bileşenleri, kullanıcı veya collaborator görsellerini
tek bir kişi veya örtüşen küçük grup olarak göstermek için kullanılır.
Görsel kaynağı yüklenemediğinde fallback ikona düşerler ve indicator,
border, boyut gibi alanlarla çevrelerine durum bilgisi eklerler.

Genel kural:

- Avatar kaynağı (`ImageSource`) view veya servis tarafında çözümlenir;
  component'e yalnızca hazır URL/asset verilir.
- Birden fazla katılımcıyı yan yana göstermek için `Facepile`; tek katılımcı
  için doğrudan `Avatar` kullanılır.

## Avatar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/avatar.rs`
- Export: `ui::Avatar`, `ui::AvatarAudioStatusIndicator`,
  `ui::AvatarAvailabilityIndicator`, `ui::AudioStatus`,
  `ui::CollaboratorAvailability`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Avatar`

Ne zaman kullanılır:

- Kullanıcı, collaborator, participant veya commit author görseli göstermek için.
- Avatar üstünde microphone veya availability göstergesi gerekiyorsa.
- Facepile içinde küçük, border'lı ve overlap eden avatarlar için.

Ne zaman kullanılmaz:

- Genel icon veya logo için `Icon` / `Vector`.
- Avatar kaynağı yoksa sadece harf badge'i gerekiyorsa özel `div()` + `Label`
  daha açık olabilir.

Temel API:

- `Avatar::new(src: impl Into<ImageSource>)`
- `.grayscale(bool)`
- `.border_color(color)`
- `.size(size)`
- `.indicator(element)`
- `AvatarAudioStatusIndicator::new(AudioStatus::Muted | AudioStatus::Deafened)`
- `AvatarAvailabilityIndicator::new(CollaboratorAvailability::Free | Busy)`

Davranış:

- Varsayılan avatar boyutu `1rem`.
- Görsel yüklenemezse `IconName::Person` ile fallback render eder.
- `border_color(...)`, avatar çevresinde `1px` border açar ve facepile overlap
  görünümünde görsel boşluk yaratmak için kullanılır.
- Indicator, avatar container'ının child'ı olarak render edilir; indicator
  pozisyonu kendi elementinde absolute ayarlanır.

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

Ses durumu:

```rust
use ui::{AudioStatus, Avatar, AvatarAudioStatusIndicator, prelude::*};

fn render_muted_participant(avatar_url: SharedString) -> impl IntoElement {
    Avatar::new(avatar_url)
        .size(px(32.))
        .indicator(AvatarAudioStatusIndicator::new(AudioStatus::Muted))
}
```

Zed içinden kullanım:

- `../zed/crates/collab_ui/src/collab_panel.rs`: contact ve participant
  satırları.
- `../zed/crates/title_bar/src/collab.rs`: title bar collaborator avatarları.
- `../zed/crates/editor/src/git.rs`: author avatarları.

Dikkat edilecekler:

- `.size(...)` için `px(...)` veya `rems(...)` kullanabilirsiniz; facepile'da aynı
  boyutu korumak daha temiz görünür.
- Audio status tooltip'i gerekiyorsa `AvatarAudioStatusIndicator::tooltip(...)`
  ile bağlayın.
- Availability indicator için `.avatar_size(...)` gerçek avatar boyutuyla aynı
  verilirse nokta oranı daha doğru olur.

## Facepile

Kaynak:

- Tanım: `../zed/crates/ui/src/components/facepile.rs`
- Export: `ui::Facepile`, `ui::EXAMPLE_FACES`
- Prelude: Hayır, ayrıca import edin.
- Preview: `impl Component for Facepile`

Ne zaman kullanılır:

- Aktif collaborator, reviewer veya participant grubunu kompakt göstermek için.
- Yüzleri soldan sağa overlap ederek küçük alanda birden çok kişiyi göstermek
  için.

Ne zaman kullanılmaz:

- Tek kullanıcı için `Avatar`.
- Sıralı, detaylı kullanıcı listesi için `ListItem` + `Avatar`.

Temel API:

- `Facepile::empty()`
- `Facepile::new(faces: SmallVec<[AnyElement; 2]>)`
- ParentElement: `.child(...)`, `.children(...)`
- Padding style yöntemleri desteklenir.

Davranış:

- Render sırasında `flex_row_reverse()` kullanır; sol yüz en üstte kalacak şekilde
  görsel overlap sağlar.
- İkinci ve sonraki yüzler `ml_neg_1()` ile bindirilir.
- `Facepile` overflow sayacı üretmez; daha fazla kişi varsa ayrıca `Chip` veya
  `CountBadge` benzeri bir eleman ekleyin.

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

Zed içinden kullanım:

- `../zed/crates/collab_ui/src/collab_panel.rs`: channel ve participant
  özetlerinde.
- `../zed/crates/ui/src/components/facepile.rs`: default ve custom size preview.

Dikkat edilecekler:

- Overlap görünümü için avatar border rengini parent background ile eşleştirmek
  iyi sonuç verir.
- Çok fazla avatar eklemek yerine ilk birkaç kişiyi gösterip kalan sayıyı ayrı
  belirtin.

