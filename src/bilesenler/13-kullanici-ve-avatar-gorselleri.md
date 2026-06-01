# 13. Kullanıcı ve Avatar Görselleri

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Avatar` | `description`, `DOCS`, `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Avatar` | Metotlar | `border_color`, `grayscale`, `indicator`, `new`, `size` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Avatar ve Facepile bileşenleri, kullanıcı veya collaborator görsellerini ekranda göstermek için kullanırsın. Bu gösterim tek bir kişi olabilir ya da küçük, örtüşen bir grup halinde kurulabilir. Görsel kaynağı yüklenemezse her ikisi de fallback bir ikona döner. Ayrıca indicator, border ve boyut gibi ayarlarla avatarın çevresine durum bilgisi ekleyebilirsin.

Bu bileşenlerde iki kuralı baştan netleştirmek faydalıdır:

- Avatar kaynağı (`ImageSource`) view veya bir servis tarafında çözümlenir. Component'e yalnızca hazır URL veya asset verilir; kaynak çözümleme işini component'in yapması beklenmez.
- Birden fazla katılımcı yan yana gösterilecekse `Facepile`, tek bir katılımcı için doğrudan `Avatar` kullanırsın.

## Avatar

Kaynak:

- Tanım: `../zed/crates/ui/src/components/avatar.rs`
- Export: `ui::Avatar`, `ui::AvatarAudioStatusIndicator`, `ui::AvatarAvailabilityIndicator`, `ui::AudioStatus`, `ui::CollaboratorAvailability`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Avatar`.

Ne zaman kullanırsın:

- Kullanıcı, collaborator, participant veya commit author görseli göstermek için.
- Avatar üzerinde bir microphone veya availability göstergesi gerektiğinde.
- Facepile içinde küçük, border'lı ve overlap eden avatarlar için.

Ne zaman kullanmazsın:

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

Avatar indicator API'leri:

| API | Rol |
| :-- | :-- |
| `AudioStatus` | Ses durumunu `Muted` veya `Deafened` olarak seçer. |
| `AvatarAudioStatusIndicator` | Avatar üzerinde mikrofon/ses durumu göstergesini render eder; tooltip bağlanabilir. |
| `CollaboratorAvailability` | Collaborator durumunu `Free` veya `Busy` olarak taşır. |
| `AvatarAvailabilityIndicator` | Avatar köşesinde availability noktasını çizer; `.avatar_size(...)` ile gerçek avatar ölçüsüne hizalanır. |

Davranış:

- Varsayılan avatar boyutu `1rem`'dir.
- Görsel yüklenemediğinde `IconName::Person` ikonu ile bir fallback render edilir.
- `border_color(...)` çağrısı avatar çevresinde `1px` bir border açar. Bu border, özellikle facepile gibi overlap görünümlerinde avatarların arasında görsel bir boşluk yaratmak için kullanırsın.
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

Ses durumunu göstermek gerektiğinde, indicator yerine `AvatarAudioStatusIndicator` kullanırsın:

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

Dikkat edeceğin noktalar:

- `.size(...)` için hem `px(...)` hem de `rems(...)` kullanabilirsin. Facepile içinde aynı boyutun korunması görsel olarak çok daha temiz bir sonuç verir.
- Bir audio status için tooltip gerekiyorsa `AvatarAudioStatusIndicator::tooltip(...)` üzerinden bağlanır.
- Availability indicator için `.avatar_size(...)` değerinin gerçek avatar boyutuyla aynı verilmesi, indicator noktasının oranını doğru hâle getirir.

## Facepile

**Trait impl kapsamı.** Bu konu altında ayrı başlık açmayı gerektirmeyen trait implementasyon üyeleri:

| Konu | Üyeler | Not |
|---|---|---|
| `Facepile` | `description`, `DOCS`, `extend`, `scope` | Trait impl üzerinden gelen public üyelerdir; çoğu dönüşüm, render, builder veya standart trait köprüsüdür. |


**Public API kapsamı.** Bu başlık altında ayrı alt başlık açmayı gerektirmeyen public alt yüzeyler:

| Konu | Grup | API | Not |
|---|---|---|---|
| `Facepile` | Metotlar | `empty`, `new`, `p_2`, `p_3`, `pb`, `pl`, `pt`, `px`, `px_1`, `px_2`, `py`, `py_0p5`, `py_1` | Builder, sorgu veya runtime çağrıları; ayrıntı bu konu anlatımındaki kullanım bağlamıyla okunur. |


Kaynak:

- Tanım: `../zed/crates/ui/src/components/facepile.rs`
- Export: `ui::Facepile`, `ui::EXAMPLE_FACES`.
- Prelude: Hayır; ayrıca import edersin.
- Preview: `impl Component for Facepile`.

Ne zaman kullanırsın:

- Aktif bir collaborator, reviewer veya participant grubunu kompakt biçimde göstermek için.
- Yüzleri soldan sağa overlap ederek küçük bir alanda birden fazla kişiyi göstermek istendiğinde.

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
| `EXAMPLE_FACES` | Component preview ve örnek kompozisyonlar için kullanılan hazır avatar URL listesidir; gerçek uygulama verisi yerine geçmez. |

Davranış:

- Render sırasında `flex_row_reverse()` kullanılır; bu sayede en sol yüz en üstte görünür ve doğal bir overlap elde edilir.
- İkinci ve sonraki yüzler `ml_neg_1()` ile birbirinin üzerine bindirilir.
- `Facepile` bir overflow sayacı üretmez. Görüntülenen kişi sayısından daha fazlası varsa, kalan sayıyı belirtmek için `Chip` veya `CountBadge` gibi başka bir eleman ayrıca eklersin.

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

Dikkat edeceğin noktalar:

- Overlap görünümünün düzgün okunması için, avatar border renginin parent background ile eşleşmesi iyi bir tercih olur.
- Çok fazla avatarı yan yana sıkıştırmak yerine, ilk birkaç kişiyi gösterip kalan sayıyı ayrı bir göstergeyle belirtmek okunabilirliği korur.

<!-- phase14-api-anchor:start -->

## Ek public API kapsamı

Bu bölüm, mevcut HEAD API snapshot envanterinde bu dosyanın konu alanına bağlı olan ama ayrı anlatım başlığı gerektirmeyen public field, variant ve member yüzeylerini toplar. Adlar kaynak API sembolleriyle aynı tutulur; ayrıntı için ilgili ana konu anlatımı esas alınır.

### `AudioStatus`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Deafened`, `Muted` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `AvatarAudioStatusIndicator`

| Grup | API | Not |
|---|---|---|
| Metotlar | `new`, `tooltip` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

### `CollaboratorAvailability`

| Grup | API | Not |
|---|---|---|
| Varyantlar | `Busy`, `Free` | Public enum sözleşmesinin varyantlarıdır; davranış bu dosyadaki konu bağlamıyla okunur. |

### `AvatarAvailabilityIndicator`

| Grup | API | Not |
|---|---|---|
| Metotlar | `avatar_size`, `new` | Builder, sorgu veya runtime çağrılarıdır; ayrıntı bu dosyadaki kullanım bağlamıyla okunur. |

<!-- phase14-api-anchor:end -->
