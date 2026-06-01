# Keymap Dosyası

`crates/settings/src/keymap_file.rs`. Zed klavye bağlamalarını kullanıcı keymap.json, paketlenmiş varsayılan keymap dosyaları ve Vim modu keymap'i üzerinden çözer. Bu dosya hem ayrıştırma hem programatik düzenleme hem de telemetri için ortak bir yüzey sağlar.

---

## `KeymapFile` yapısı

`KeymapFile`, birden fazla bağlam bloğu içeren bir keymap JSON dosyasının ayrıştırılmış halidir. Her blok bir `KeymapSection` olarak tutulur:

```rust
pub struct KeymapFile(Vec<KeymapSection>);

pub struct KeymapSection {
    pub context: String,                            // dispatch context predicate
    use_key_equivalents: bool,                      // QWERTY position fallback (macOS)
    unbind: Option<IndexMap<String, UnbindTargetAction>>,
    bindings: Option<IndexMap<String, KeymapAction>>,
    unrecognized_fields: IndexMap<String, Value>,   // ileri uyumlu giriş
}
```

- `context` boş ise binding herhangi bir bağlamda çalışır; aksi halde `Editor`, `Workspace`, boolean `X && Y`, `!X`, OS check, dosya uzantısı kontrolü gibi predicate'ları içerir.
- `use_key_equivalents` macOS'ta QWERTY konum eşlemesini aktive eder; AZERTY/Dvorak gibi düzenlerde `cmd-shift-4` gibi key'lerin fiziksel konumdan üretilmesi içindir.
- `unbind` aynı section'da `bindings` ayrıştırılmadan önce ele alınır; aynı section içinde bir keystroke önce unbind edilip ardından farklı bir action'a tekrar bağlanabilir.
- `bindings` keystroke string'inden `KeymapAction`'a giden eşlemedir. Keystroke'lar boşluklarla ayrılır; her keystroke modifier (`ctrl`, `alt`, `shift`, `fn`, `cmd`, `super`, `win`) ve key sırası `-` ile yazılır. Aynı keystroke aynı context derinliğinde birden fazla tanımlanırsa dosyada sonraki kayıt öncelikli olur.
- `unrecognized_fields` ileri uyumluluk içindir; bilinmeyen alanlar parser'ı kırmaz ama loglanır.

`KeymapAction(Value)` `null`, string adı veya `[name, args]` array'i olarak yorumlanabilen JSON değeridir. JSON schema schemars üzerinden manuel `JsonSchema` impl'i ile üretilir ve `KeymapFile::generate_json_schema` içinde tüm action setine genişletilir.

`UnbindTargetAction(Value)` benzer şekilde unbind hedefi yapısıdır; bir keystroke'u serbest bırakmak için kullanırsın.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `KeymapSection` | `context`, `use_key_equivalents`, `unbind`, `bindings`, `unrecognized_fields` | Tek keymap JSON section'ını ve bağlam predicate'ini taşır. |
| `KeymapAction` | `Value`, `null`, string action adı, `[name, args]` | Binding hedef action'ının JSON gösterimidir. |

---

## Yükleme ve sonuç

`KeymapFileLoadResult` yükleme sonucunu üç durumdan biriyle döndürür:

```rust
pub enum KeymapFileLoadResult {
    Success { key_bindings: Vec<KeyBinding> },
    SomeFailedToLoad { key_bindings: Vec<KeyBinding>, error_message: MarkdownString },
    JsonParseFailure { error: anyhow::Error },
}
```

- `Success` tüm bindings hata vermeden yüklendiğinde.
- `SomeFailedToLoad` JSON ayrıştırıldı ama bazı action veya predicate ayrıştırması başarısız oldu; başarılı bindings döner, hata mesajı UI'da gösterilir.
- `JsonParseFailure` JSON formatı bozuk; tek bir hata mesajı döner, hiçbir binding yüklenmez.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `KeymapFileLoadResult` | `Success`, `SomeFailedToLoad`, `JsonParseFailure` | Keymap parse ve action doğrulama sonucunu UI'a taşır. |
| `DEFAULT_KEYMAP_PATH` | platforma göre default asset | Paketlenmiş default keymap dosyasıdır. |
| `VIM_KEYMAP_PATH` | `keymaps/vim.json` | Vim modu keymap asset dosyasıdır. |

API üzerinde sık kullanılan yapıcılar şunlardır:

- `KeymapFile::parse(content) -> Result<Self>` — boş içerik için boş bir `KeymapFile` döndürür; aksi halde `parse_json_with_comments` ile ayrıştırır.
- `KeymapFile::load(content, cx) -> KeymapFileLoadResult` — string içeriği `Vec<KeyBinding>`'e çevirir.
- `KeymapFile::load_asset(asset_path, source, cx)` — paketlenmiş asset üzerinden yükler ve `KeybindSource` belirtilmişse her binding'in metasına bunu yazar. Paketlenmiş keymap'ler için bu yol kullanırsın.
- `KeymapFile::load_asset_allow_partial_failure(...)` — kısmen yüklemeye izin verir; `SomeFailedToLoad` mesajını UI tarafına geri yansıtır.
- `KeymapFile::load_panic_on_failure(content, cx)` — `test-support` build'lerinde yalnızca başarı bekleyen yollar için.
- `KeymapFile::load_keymap_file(fs)` — kullanıcı `keymap.json` dosyasını async yükler; dosya yoksa paketlenmiş `initial_keymap_content()` metnine düşer.
- `KeymapFile::parse_action(action)` — `KeymapAction` JSON değerini `null`, `"action::Name"` veya `["action::Name", args]` formundan action adı ve opsiyonel argümana çözer. Keystroke parse etmez; keystroke ayrıştırma yükleme akışında ayrı yaparsın.
- `KeymapFile::sections()` — dosyadaki tüm bölümleri dolaşır.

---

## `KeybindSource`

```rust
pub enum KeybindSource {
    User, Vim, Base, Default, Unknown,
}
```

Her binding'in nereden geldiğini sınıflandırır. `KeyBindingMetaIndex` üzerinde sabit numaralarla saklanır; UI tarafında her satırın "User", "Default", "Vim", "Base" rozeti bu enum'dan çözülür.

- `KeybindSource::User` — kullanıcı keymap dosyası.
- `KeybindSource::Vim` — paketlenmiş `vim.json` keymap'i.
- `KeybindSource::Base` — kullanıcının seçtiği temel keymap (`base_keymap` ayarı: Atom, VS Code, Sublime, JetBrains, None).
- `KeybindSource::Default` — paketlenmiş platform varsayılan keymap'i.
- `KeybindSource::Unknown` — kaynak haritasına yerleştirilmemiş bindings.

API:

- `name(&self) -> &'static str` — `"User" | "Default" | "Base" | "Vim" | "Unknown"` döner; UI etiketi olarak ya da telemetri payload'unda kullanırsın.
- `meta(&self) -> KeyBindingMetaIndex` — GPUI tarafındaki binding metasına atılan numarayı verir.
- `KeybindSource::from_meta(index)` — geri dönüşüm.
- `From<KeyBindingMetaIndex> for KeybindSource` ve `From<KeybindSource> for KeyBindingMetaIndex` blanket impl'ler bu çift yönlü çevirimi otomatikleştirir.

---

## `KeybindUpdateOperation` ve `KeybindUpdateTarget`

Programatik keymap güncellemesi (örneğin "Add/Change Keybinding" UI'ı veya komut paleti üzerinden binding düzenleme) `KeybindUpdateOperation` üzerinden modellenir:

```rust
pub enum KeybindUpdateOperation<'a> {
    Replace {
        source: KeybindUpdateTarget<'a>,
        target: KeybindUpdateTarget<'a>,
        target_keybind_source: KeybindSource,
    },
    Add {
        source: KeybindUpdateTarget<'a>,
        from: Option<KeybindUpdateTarget<'a>>,
    },
    Remove {
        target: KeybindUpdateTarget<'a>,
        target_keybind_source: KeybindSource,
    },
}

pub struct KeybindUpdateTarget<'a> {
    pub context: Option<&'a str>,
    pub keystrokes: &'a [KeybindingKeystroke],
    pub action_name: &'a str,
    pub action_arguments: Option<&'a str>,
}
```

- `Replace` mevcut bir bindingi yenisiyle değiştirir; eski binding'in kaynağı `target_keybind_source` ile bilinir, yenisi `source` ile tanımlanır. `target_keybind_source` `User` değilse keymap editörü hedefi yeni bir User kaydı üreterek üzerine yazar.
- `Add` doğrudan yeni bir binding ekler. `from` verildiyse "şu binding'in yanına" gibi bir referans noktası belirtir.
- `Remove` belirtilen hedefi unbind eder; `target_keybind_source` `User` ise tam kaldırma, aksi halde `unbind` girişi eklenerek üst katmandaki kayıt iptal edilir.
- `KeybindUpdateOperation::add(source)` `Add { from: None }` kısayoludur.
- `KeybindUpdateOperation::generate_telemetry()` `(new_binding, removed_binding, source)` üçlüsünü döndürür; ChangeKeybinding flow'u telemetry'ye bunu yollar.

`KeymapFile::update_keybinding(operation, keymap_contents, tab_size, keyboard_mapper)` mevcut user `keymap.json` metnini alır, verilen `KeybindUpdateOperation`'ı uygular ve yeni metni üretir. `tab_size` dosyanın girintileme biçimini korumak, `keyboard_mapper` ise platform klavye eşdeğerlerini hesaplamak için kullanırsın. Yazma yine `update_settings_file`'a benzer atomic-write akışı üzerinden yaparsın.

---

## `KeyBindingValidator`

Bazı action'lar için ek doğrulama (örneğin "bu action'a yalnız Editor bağlamında bağlanabilirsin") gereklidir. `KeyBindingValidator` trait'i her action tipi için ayrı doğrulayıcı kaydı yapar:

```rust
pub trait KeyBindingValidator: Send + Sync {
    fn action_type_id(&self) -> TypeId;
    fn validate(&self, binding: &KeyBinding) -> Result<(), MarkdownString>;
}

pub struct KeyBindingValidatorRegistration(pub fn() -> Box<dyn KeyBindingValidator>);

inventory::collect!(KeyBindingValidatorRegistration);
```

`inventory` ile derleme zamanında kaydedilen validator'lar `KEY_BINDING_VALIDATORS: LazyLock<BTreeMap<TypeId, Box<dyn KeyBindingValidator>>>` üzerinde toplanır. Keymap yüklenirken her binding'in action tipi için ilgili validator çağrılır; başarısızlık `SomeFailedToLoad.error_message` ile UI'da gösterilir.

| API | Alt özellikler | Kısa anlamı |
| :-- | :-- | :-- |
| `KeyBindingValidatorRegistration` | `pub fn() -> Box<dyn KeyBindingValidator>` | `inventory` listesine validator factory'si kaydeden sarmalayıcıdır. |

---

## `ActionSequence`

Tek bir tuş kombinasyonuna birden fazla action bağlamak için kullanılan kapsayıcıdır:

```rust
pub struct ActionSequence(pub Vec<Box<dyn Action>>);
```

`ActionSequence` bir keystroke'a birden çok action bağlamak için kullanırsın. Sequence içindeki action'lar sırayla dispatch edilir; asenkron action'ların tamamlanması beklenmez. Keymap içinde array formu ile yazılır (örneğin `["editor::Newline", "editor::AcceptInlineCompletion"]`).

---

## Schema üretimi

`KeymapFile::generate_json_schema_for_registered_actions(cx)` ve `generate_json_schema_from_inventory()` JSON schema üretir. Schema action listesi, action argümanlarının tip bilgisi ve binding ipuçlarını içerir. `get_action_schema_by_name(...)` belirli bir action için schema'yı tek başına döndürür; keymap editörü autocomplete bunun üzerinden çalışır.

`action_schema_generator()` schemars `SchemaGenerator`'ını paylaşılan formatta kurar; çapraz action ve setting schema üretiminde aynı generator kullanırsın.

---

## Tuzaklar

- Aynı keystroke aynı context'te iki kere tanımlanırsa dosyada sonraki kazanır; ancak UI'da iki kayıt arasında "winning binding" işareti yalnız `KeybindSource` farklıysa görünür. Aynı User kaydının iki kez tanımlanması karmaşadır; düzenleme akışı önce mevcut kaydı kaldırır.
- `unbind` her zaman `bindings`'ten önce işlendiği için aynı section içinde bir keystroke'u önce serbest bırakıp sonra yeni action'a bağlamak güvenlidir; başka section'a bağlanmış aynı keystroke yine üst katmandan gelirse override gerekebilir.
- `KeyBindingValidator` action kaydedilmeden kaydedilmek üzere `inventory::submit!` ile gönderilmelidir; aksi halde validator listede görünmez ve doğrulama atlanır.
- `KeybindUpdateOperation::Replace` `target_keybind_source = Default` ile çağrılırsa default keymap dosyasına yazma denemesi yapılmaz; kullanıcı dosyasına ek bir kayıt yazılır ve gerekirse `unbind` girişi eklersin.
