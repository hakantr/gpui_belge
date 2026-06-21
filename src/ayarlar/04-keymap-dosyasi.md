# Keymap Dosyası

Zed, klavye kısayolu bağlamalarını (keybindings) kullanıcıya ait `keymap.json`, paketlenmiş varsayılan keymap dosyaları ve Vim modu keymap'i üzerinden çözümler. `KeymapFile` yapısı; hem ayrıştırma, hem programatik düzenleme, hem de telemetri süreçleri için ortak bir erişim kapısı sağlar.

---

## `KeymapFile` Yapısı

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

- `context` boş ise tanımlanan kısayol herhangi bir bağlamda çalışabilir; aksi halde `Editor`, `Workspace`, boolean `X && Y`, `!X`, işletim sistemi (OS) kontrolü, dosya uzantısı kontrolü gibi predicate (koşul) yapılarını içerir.
- `use_key_equivalents` alanı, macOS platformunda QWERTY konum eşlemesini etkinleştirir; AZERTY veya Dvorak gibi farklı klavye düzenlerinde `cmd-shift-4` gibi tuşların fiziksel konumdan üretilmesini sağlamak amacıyla kullanılır.
- `unbind` alanı, aynı section (bölüm) içinde `bindings` ayrıştırılmadan önce ele alınır; bu sayede aynı bölüm içinde bir tuş vuruşu (keystroke) önce unbind edilip, ardından farklı bir action'a tekrar bağlanabilir.
- `bindings` alanı, tuş vuruşundan (keystroke string) `KeymapAction` yapısına giden eşlemedir. Tuş vuruşları aralarında boşluklarla ayrılır; her tuş vuruşu modifier tuşlar (`ctrl`, `alt`, `shift`, `fn`, `cmd`, `super`, `win`) ve karakter tuşunun aralarına `-` konularak yazılmasıyla oluşturulur. Aynı tuş vuruşu aynı bağlam derinliğinde birden fazla tanımlanırsa, dosyada daha altta (sonra) yer alan kayıt öncelikli kabul edilir.
- `unrecognized_fields` alanı, ileriye dönük uyumluluk içindir; bilinmeyen alanlar JSON ayrıştırma (parse) aşamasını kırmaz, fakat yükleme sonucunda kısmi hata mesajına dahil edilir ve başarılı olan diğer bağlamalar yine de yüklenir.

`KeymapAction(Value)`, `null`, string adı veya `[name, args]` dizisi (array) olarak yorumlanabilen bir JSON değeridir. JSON şeması, schemars aracılığıyla manuel `JsonSchema` implementasyonu ile üretilir ve `KeymapFile::generate_json_schema` içinde tüm eylem setine genişletilir.

`UnbindTargetAction(Value)` benzer şekilde bir unbind hedefi yapısıdır; bir tuş vuruşunu serbest bırakmak için kullanılır.

| API | Alt Özellikler | Kısa Anlamı |
| :-- | :-- | :-- |
| `KeymapSection` | `context`, `use_key_equivalents`, `unbind`, `bindings`, `unrecognized_fields` | Tek bir keymap JSON bölümünü ve bağlam koşulunu (predicate) taşır. |
| `KeymapAction` | `Value`, `null`, string action adı, `[name, args]` | Kısayolun hedeflediği eylemin JSON gösterimidir. |

`settings_content` tarafındaki action/keymap şema yardımcıları, keymap dosyasının çalışma zamanı eylem kayıt defteriyle (action registry) birleştiği noktayı oluşturur:

| API | Rolü | Not |
| :-- | :-- | :-- |
| `ActionWithArguments` | GPUI action adını ve argüman verisini iki elemanlı JSON dizisi olarak temsil eder | `JsonSchema` placeholder (geçici yer tutucu) döndürür; gerçek action şeması çalışma zamanı registry bilgisiyle `KeymapFile::generate_json_schema` içinde üretilir. |
| `BaseKeymapContent` | `base_keymap` ayarının VSCode, JetBrains, Sublime Text, Atom, TextMate, Emacs, Cursor veya None tercihlerini taşır | Kullanıcı keymap'inin altına hangi paketlenmiş varsayılan (base) keymap dosyasının yedirileceğini belirler. |

---

## Yükleme ve Sonuç

`KeymapFileLoadResult` yükleme sonucunu üç durumdan biriyle döndürür:

```rust
pub enum KeymapFileLoadResult {
    Success { key_bindings: Vec<KeyBinding> },
    SomeFailedToLoad { key_bindings: Vec<KeyBinding>, error_message: MarkdownString },
    JsonParseFailure { error: anyhow::Error },
}
```

- `Success` — Tüm klavye kısayolları hata vermeden başarıyla yüklendiğinde döndürülür.
- `SomeFailedToLoad` — JSON başarıyla ayrıştırıldı ancak bazı eylem veya koşul (predicate) ayrıştırmaları başarısız oldu; bu durumda başarılı olan kısayollar yine de yüklenir, hata mesajı ise arayüzde (UI) gösterilir.
- `JsonParseFailure` — JSON formatı bozuk olduğunda döndürülür; tek bir hata mesajı döner ve hiçbir kısayol yüklenmez.

| API | Alt Özellikler | Kısa Anlamı |
| :-- | :-- | :-- |
| `KeymapFileLoadResult` | `Success`, `SomeFailedToLoad`, `JsonParseFailure` | Keymap parse ve action doğrulama sonuçlarını arayüze taşır. |
| `DEFAULT_KEYMAP_PATH` | platforma göre default asset | Paketlenmiş varsayılan keymap dosyasının yoludur. |
| `SPECIFIC_OVERRIDES_KEYMAP_PATH` | platforma göre specific override asset | macOS için `keymaps/specific-overrides-macos.json`, diğer platformlar için `keymaps/specific-overrides.json` yolunu verir. |
| `VIM_KEYMAP_PATH` | `keymaps/vim.json` | Vim modu keymap asset dosyasının yoludur. |

API üzerinde sıkça kullanılan yapıcı metotlar şunlardır:

- `KeymapFile::parse(content) -> Result<Self>` — Boş içerikler için boş bir `KeymapFile` döndürür; aksi halde `parse_json_with_comments` ile içeriği ayrıştırır.
- `KeymapFile::load(content, cx) -> KeymapFileLoadResult` — String formatındaki içeriği `Vec<KeyBinding>` yapısına dönüştürür; içeride önce `parse(content)` ile ayrıştırır, ardından elde edilen `KeymapFile` üzerinde `load_keymap(cx)` çağırır.
- `KeymapFile::load_keymap(&self, cx) -> KeymapFileLoadResult` — Önceden ayrıştırılmış bir `KeymapFile` örneğinden tuş eşlemlerini (`Vec<KeyBinding>`) üretir; ayrıştırma ile yükleme adımlarının ayrı yürütülmesi gerektiğinde doğrudan kullanılır.
- `KeymapFile::load_asset(asset_path, source, cx) -> Result<Vec<KeyBinding>>` — Paketlenmiş asset üzerinden yükleme yapar ve `KeybindSource` belirtilmişse her binding'in metasına bunu yazar. Paketlenmiş keymap'ler için bu yöntem kullanılır ve dönen `Result` değeri `?` operatörü ile ele alınır; eğer yükleme `SomeFailedToLoad` veya `JsonParseFailure` ile sonuçlanırsa içeride `bail!` ile hataya çevrilir, yani kısmi yüklemeleri sessizce kabul etmez.
- `KeymapFile::load_asset_allow_partial_failure(...)` — Kısmi yüklemelere izin verir; `SomeFailedToLoad` hata mesajını doğrudan arayüz tarafına geri yansıtır.
- `KeymapFile::load_panic_on_failure(content, cx)` — Test ortamlarında (`test-support`) yalnızca başarı beklenen yollar için kullanılır.
- `KeymapFile::load_keymap_file(fs)` — Kullanıcıya ait `keymap.json` dosyasını asenkron olarak yükler; dosya mevcut değilse paketlenmiş varsayılan `initial_keymap_content()` metnine geri döner.
- `KeymapFile::parse_action(action)` — `KeymapAction` JSON değerini `null`, `"action::Name"` veya `["action::Name", args]` formatından çözerek action adı ve isteğe bağlı argümanına dönüştürür. Tuş vuruşlarını ayrıştırmaz; tuş vuruşu (keystroke) ayrıştırma işlemi yükleme akışında ayrı olarak gerçekleştirilir.
- `KeymapFile::sections()` — Dosyadaki tüm bölümleri gezmeyi sağlar.

---

## `KeybindSource`

```rust
pub enum KeybindSource {
    User, Vim, Base, Default, Unknown,
}
```

Klavye kısayollarının nereden geldiğini sınıflandırır. `KeyBindingMetaIndex` üzerinde sabit numaralarla saklanır; arayüz tarafında her satırın `"User"`, `"Default"`, `"Vim"`, `"Base"` rozetleri bu enum üzerinden çözümlenir.

- `KeybindSource::User` — Kullanıcının kendi keymap dosyasıdır.
- `KeybindSource::Vim` — Paketlenmiş `vim.json` keymap dosyasıdır.
- `KeybindSource::Base` — Kullanıcının seçtiği temel keymap ailesidir (`base_keymap` ayarı: VSCode, JetBrains, SublimeText, Atom, TextMate, Emacs, Cursor veya None).
- `KeybindSource::Default` — Paketlenmiş platform varsayılan keymap dosyasıdır.
- `KeybindSource::Unknown` — Kaynak haritasına yerleştirilmemiş olan klavye kısayollarıdır.

Arayüz Metotları:

- `name(&self) -> &'static str` — `"User" | "Default" | "Base" | "Vim" | "Unknown"` değerlerinden birini döner; UI etiketlerinde ya da telemetri verisinde kullanılır.
- `meta(&self) -> KeyBindingMetaIndex` — GPUI tarafındaki binding metasına atanan sayısal değeri döndürür.
- `KeybindSource::from_meta(index)` — İndis bilgisinden enum yapısını geri elde etmeyi sağlar.
- `From<KeyBindingMetaIndex> for KeybindSource` ve `From<KeybindSource> for KeyBindingMetaIndex` genel implementasyonları, bu çift yönlü dönüşüm sürecini otomatikleştirir.

---

## `KeybindUpdateOperation` ve `KeybindUpdateTarget`

Programatik olarak keymap güncellenmesi (örneğin arayüzdeki `"Add/Change Keybinding"` pencereleri veya komut paleti üzerinden tuş atamalarının düzenlenmesi) `KeybindUpdateOperation` üzerinden modellenir:

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

- `Replace` — Mevcut bir kısayolu yenisiyle değiştirir; eski kısayolun kaynağı `target_keybind_source` ile belirtilir, yenisi ise `source` ile tanımlanır. Eğer `target_keybind_source` değeri `User` değilse, keymap editörü hedefi yeni bir kullanıcı (`User`) kaydı üreterek üzerine yazar.
- `Add` — Doğrudan yeni bir kısayol bağlaması ekler. `from` parametresi verildiyse "şu kısayolun yanına" gibi bir referans noktası belirtir.
- `Remove` — Belirtilen hedefi unbind eder; eğer `target_keybind_source` değeri `User` ise tam silme işlemi uygulanır, aksi halde `unbind` girişi eklenerek üst katmandaki kayıt iptal edilir.
- `KeybindUpdateOperation::add(source)` — `Add { from: None }` çağrısının kısayoludur.
- `KeybindUpdateOperation::generate_telemetry()` — `(new_binding, removed_binding, source)` üçlüsünü döndürür; ChangeKeybinding akışı telemetri sistemine bu verileri yollar.

`KeymapFile::update_keybinding(operation, keymap_contents, tab_size, keyboard_mapper)` metodu; mevcut kullanıcı `keymap.json` metnini alır, verilen `KeybindUpdateOperation` işlemini uygular ve yalnızca güncellenmiş yeni metni döndürür. `tab_size` parametresi dosyanın girintileme biçimini korumak, `keyboard_mapper` ise platform klavye eşdeğerlerini hesaplamak amacıyla kullanılır. Kaydetme aşamasında dönen metin `fs.write(paths::keymap_file(), ...)` ile doğrudan yazılır; keymap kaydetme işlemleri, ayar dosyasındaki gibi `update_settings_file` ya da `atomic_write` akışlarını kullanmaz.

---

## `KeyBindingValidator`

Bazı eylemler için ek doğrulama kuralları (örneğin `"bu eyleme yalnızca Editor bağlamında bağlanılabilir"`) gerekebilir. `KeyBindingValidator` trait'i, her eylem tipi için ayrı doğrulayıcı kayıtları yapmayı sağlar:

```rust
pub trait KeyBindingValidator: Send + Sync {
    fn action_type_id(&self) -> TypeId;
    fn validate(&self, binding: &KeyBinding) -> Result<(), MarkdownString>;
}

pub struct KeyBindingValidatorRegistration(pub fn() -> Box<dyn KeyBindingValidator>);

inventory::collect!(KeyBindingValidatorRegistration);
```

`inventory` ile derleme zamanında kaydedilen doğrulayıcılar `KEY_BINDING_VALIDATORS: LazyLock<BTreeMap<TypeId, Box<dyn KeyBindingValidator>>>` üzerinde toplanır. Keymap yüklenirken her kısayolun eylem tipi için ilgili validator çalıştırılır; başarısızlık durumları `SomeFailedToLoad.error_message` ile arayüzde gösterilir.

| API | Alt Özellikler | Kısa Anlamı |
| :-- | :-- | :-- |
| `KeyBindingValidatorRegistration` | `pub fn() -> Box<dyn KeyBindingValidator>` | `inventory` listesine validator factory'sini kaydeden sarmalayıcı yapıdır. |

---

## `ActionSequence`

Tek bir tuş kombinasyonuna birden fazla eylemi ardışık olarak bağlamak için kullanılan kapsayıcı yapıdır:

```rust
pub struct ActionSequence(pub Vec<Box<dyn Action>>);
```

`ActionSequence`, bir tuş vuruşuna birden çok action bağlamak amacıyla kullanılır. Sequence (dizi) içindeki action'lar sırayla gönderilir (dispatch edilir); asenkron eylemlerin tamamlanması beklenmez. Keymap içinde `["action::Sequence", [...]]` formatıyla yazılır; örneğin `["action::Sequence", ["editor::Newline", "editor::AcceptInlineCompletion"]]`. Bu eylem, dispatch tarafında onu dinleyen yüzeylerde çalışır; Zed ana çalışma alanı bu dinleyiciyi kendi eylem zincirine entegre eder.

---

## Şema (Schema) Üretimi

`KeymapFile::generate_json_schema_for_registered_actions(cx)` ve `generate_json_schema_from_inventory()` fonksiyonları JSON şeması üretir. Şema; eylem listelerini, eylem argümanlarının tip bilgilerini ve tuş atama ipuçlarını içerir. `get_action_schema_by_name(...)` belirli bir eylem için şemayı tek başına döndürür; keymap editörünün otomatik tamamlaması (autocomplete) bu şemalar üzerinden çalışır.

`action_schema_generator()` fonksiyonu, schemars `SchemaGenerator` yapısını paylaşılan formatta yapılandırır; çapraz eylem ve ayar şeması üretim süreçlerinde aynı generator kullanılır.

---

## Dikkat Edilmesi Gereken Hususlar

- Aynı tuş vuruşu aynı bağlamda (context) iki kez tanımlanırsa dosyada daha altta yer alan kayıt kazanır; ancak arayüzde iki kayıt arasındaki "kazanan bağlama" işareti yalnızca `KeybindSource` değerleri farklıysa görüntülenir. Aynı kullanıcı kaydını iki kez tanımlamak yerine, düzenleme akışında önce mevcut kaydın kaldırılması gerekir.
- `unbind` işlemleri her zaman `bindings` listesinden önce işlendiği için, aynı bölüm içinde bir tuş vuruşunu önce serbest bırakıp sonra yeni bir eyleme bağlamak güvenlidir; farklı bir bölüme (section) bağlanmış olan aynı tuş vuruşu üst katmanlardan geliyorsa override edilmesi gerekebilir.
- `KeyBindingValidator` factory yapısını `inventory::submit!` ile derleme zamanında kaydedilmesi gerekir; aksi takdirde validator listede görünmez ve doğrulama aşaması atlanır.
- `KeybindUpdateOperation::Replace` işlemi `target_keybind_source = Default` ile çağrıldığında, GPUI varsayılan keymap dosyasına yazma denemesi yapmaz; bunun yerine kullanıcı dosyasına ek bir kayıt yazılır ve gerekirse `unbind` girişi eklenir.
