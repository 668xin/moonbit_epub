///|
/// 元数据模型（S1）。
///
/// Dublin Core 全集 + EPUB 3 扩展元数据（`meta` 属性、`dcterms:modified`、
/// series/collection）。本包只承载数据与增改操作，序列化在 OPF 层（S3）完成。

///|
/// 贡献者：对应 `dc:creator` / `dc:contributor`。
pub struct Contributor {
  // 名称
  name : String
  // OPF 角色代码，如 `aut`（作者）、`edt`（编者）、`ill`（插图）
  role : String?
  // 排序用名称，如 `"Doe, Jane"`
  file_as : String?
} derive(Eq, @debug.Debug)

///|
/// 构造贡献者，`role` 与 `file_as` 可选。
pub fn Contributor::new(
  name : String,
  role? : String,
  file_as? : String,
) -> Contributor {
  { name, role, file_as, }
}

///|
/// EPUB 3 扩展元数据条目，对应 OPF 的 `meta` 元素。
///
/// 三种常见形态：
/// - `meta(name, content)`：`name` 与 `content` 均非空；
/// - `meta(property, refines)`：`property` 非空，可选 `refines` 指向被细化的 `id`；
/// - `meta(property)`：仅 `property`。
pub struct Meta {
  // 传统 name/content 形态
  name : String?
  content : String?
  // EPUB 3 property 形态
  property : String?
  refines : String?
  scheme : String?
  id : String?
} derive(Eq, @debug.Debug)

///|
/// 构造 `meta(name, content)` 形态。
pub fn Meta::named(name : String, content : String) -> Meta {
  {
    name: Some(name),
    content: Some(content),
    property: None,
    refines: None,
    scheme: None,
    id: None,
  }
}

///|
/// 构造 `meta(property)` 形态。
pub fn Meta::of_property(property : String) -> Meta {
  {
    name: None,
    content: None,
    property: Some(property),
    refines: None,
    scheme: None,
    id: None,
  }
}

///|
/// 构造 `meta(property, refines)` 形态。
pub fn Meta::refining(property : String, refines : String) -> Meta {
  {
    name: None,
    content: None,
    property: Some(property),
    refines: Some(refines),
    scheme: None,
    id: None,
  }
}

///|
/// 构造带文本内容的 `property` 形态 `meta`，如
/// `<meta property="schema:accessMode">textual</meta>`。
pub fn Meta::of_property_content(property : String, content : String) -> Meta {
  {
    name: None,
    content: Some(content),
    property: Some(property),
    refines: None,
    scheme: None,
    id: None,
  }
}

///|
/// 丛书 / 合集元数据，序列化为 `belongs-to-collection` 相关 `meta`。
pub struct Series {
  name : String
  // 在丛书中的序号
  index : Int?
} derive(Eq, @debug.Debug)

///|
/// 构造丛书元数据。
pub fn Series::new(name : String, index? : Int) -> Series {
  { name, index, }
}

///|
/// 书籍元数据聚合。
pub struct Metadata {
  mut title : String
  mut language : String
  // 唯一标识符的值（通常为 `urn:uuid:...`）
  mut identifier : String
  // 承载唯一标识符的元素 id，供 `package@unique-identifier` 引用
  mut identifier_id : String
  creators : Array[Contributor]
  contributors : Array[Contributor]
  publishers : Array[String]
  dates : Array[String]
  subjects : Array[String]
  descriptions : Array[String]
  mut rights : String?
  // `dcterms:modified`，EPUB 3 必需
  mut modified : String?
  metas : Array[Meta]
  series : Array[Series]
} derive(@debug.Debug)

///|
/// 构造元数据：标题、语言与唯一标识符为必填项。
pub fn Metadata::new(
  title : String,
  language : String,
  identifier : String,
) -> Metadata {
  {
    title,
    language,
    identifier,
    identifier_id: "pub-id",
    creators: [],
    contributors: [],
    publishers: [],
    dates: [],
    subjects: [],
    descriptions: [],
    rights: None,
    modified: None,
    metas: [],
    series: [],
  }
}

///|
/// 追加创建者。
pub fn Metadata::add_creator(self : Metadata, creator : Contributor) -> Unit {
  self.creators.push(creator)
}

///|
/// 追加贡献者。
pub fn Metadata::add_contributor(
  self : Metadata,
  contributor : Contributor,
) -> Unit {
  self.contributors.push(contributor)
}

///|
/// 追加出版者。
pub fn Metadata::add_publisher(self : Metadata, publisher : String) -> Unit {
  self.publishers.push(publisher)
}

///|
/// 追加日期。
pub fn Metadata::add_date(self : Metadata, date : String) -> Unit {
  self.dates.push(date)
}

///|
/// 追加主题。
pub fn Metadata::add_subject(self : Metadata, subject : String) -> Unit {
  self.subjects.push(subject)
}

///|
/// 追加描述。
pub fn Metadata::add_description(self : Metadata, description : String) -> Unit {
  self.descriptions.push(description)
}

///|
/// 追加扩展元数据条目。
pub fn Metadata::add_meta(self : Metadata, meta : Meta) -> Unit {
  self.metas.push(meta)
}

///|
/// 追加丛书元数据。
pub fn Metadata::add_series(self : Metadata, series : Series) -> Unit {
  self.series.push(series)
}

///|
/// 全部创建者名称，按登记顺序。
pub fn Metadata::creator_names(self : Metadata) -> Array[String] {
  let out : Array[String] = []
  for creator in self.creators {
    out.push(creator.name)
  }
  out
}

///|
/// EPUB 3 必需元数据是否齐备：标题、语言、唯一标识符非空。
pub fn Metadata::is_complete(self : Metadata) -> Bool {
  !self.title.is_empty() &&
  !self.language.is_empty() &&
  !self.identifier.is_empty()
}

///|
/// 设置标题。
pub fn Metadata::set_title(self : Metadata, title : String) -> Unit {
  self.title = title
}

///|
/// 设置语言（BCP 47 代码，如 `zh-CN`）。
pub fn Metadata::set_language(self : Metadata, language : String) -> Unit {
  self.language = language
}

///|
/// 设置唯一标识符值。
pub fn Metadata::set_identifier(self : Metadata, identifier : String) -> Unit {
  self.identifier = identifier
}

///|
/// 设置承载唯一标识符的元素 id。
pub fn Metadata::set_identifier_id(
  self : Metadata,
  identifier_id : String,
) -> Unit {
  self.identifier_id = identifier_id
}

///|
/// 设置版权声明。
pub fn Metadata::set_rights(self : Metadata, rights : String) -> Unit {
  self.rights = Some(rights)
}

///|
/// 设置 `dcterms:modified` 时间戳。
pub fn Metadata::set_modified(self : Metadata, modified : String) -> Unit {
  self.modified = Some(modified)
}
