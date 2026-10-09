///|
/// OPF 包文档序列化（S3）。
///
/// 把书籍模型序列化为 EPUB 3 的 OPF（Open Packaging Format）包文档：
/// `<metadata>`（Dublin Core 元素集 + EPUB 3 扩展 `meta`）、`<manifest>`
/// 资源清单、`<spine>` 阅读顺序，以及 EPUB 2 兼容的可选 `<guide>`。
///
/// 序列化输出为 `String`，不做任何文件写入（IO 由上层打包与 CLI 负责）。

// ---------------------------------------------------------------------------
// 选项类型
// ---------------------------------------------------------------------------

///|
/// 指南引用，对应 EPUB 2 兼容的 `guide/reference`。
pub struct GuideReference {
  // 引用类型，如 `cover` / `toc` / `text`
  ref_type : String
  // 人类可读标题
  title : String
  // 引用目标，容器内相对路径
  href : String
} derive(Eq, @debug.Debug)

///|
/// 构造指南引用。
pub fn GuideReference::new(
  ref_type : String,
  title : String,
  href : String,
) -> GuideReference {
  { ref_type, title, href, }
}

///|
/// 包文档序列化选项。
pub struct OpfOptions {
  // `package@version`
  mut version : String
  // `package@unique-identifier`，缺省取元数据的 `identifier_id`
  mut unique_identifier : String?
  // 是否输出可选的 `<guide>`
  mut include_guide : Bool
  guide : Array[GuideReference]
} derive(@debug.Debug)

///|
/// 构造选项：版本取规范默认值，输出 guide。
pub fn OpfOptions::new() -> OpfOptions {
  {
    version: @spec.package_version,
    unique_identifier: None,
    include_guide: true,
    guide: [],
  }
}

///|
/// 设置包版本。
pub fn OpfOptions::set_version(self : OpfOptions, version : String) -> Unit {
  self.version = version
}

///|
/// 覆盖 `unique-identifier` 所引用的元素 id。
pub fn OpfOptions::set_unique_identifier(
  self : OpfOptions,
  identifier_id : String,
) -> Unit {
  self.unique_identifier = Some(identifier_id)
}

///|
/// 设置是否输出 `<guide>`。
pub fn OpfOptions::set_include_guide(
  self : OpfOptions,
  include_guide : Bool,
) -> Unit {
  self.include_guide = include_guide
}

///|
/// 追加一条指南引用。
pub fn OpfOptions::add_guide(
  self : OpfOptions,
  reference : GuideReference,
) -> Unit {
  self.guide.push(reference)
}

// ---------------------------------------------------------------------------
// 内部写入工具
// ---------------------------------------------------------------------------

///|
/// 写入换行与按 `depth` 计算的缩进（每层两个空格）。
///
/// 缓冲为空时不写换行，使片段渲染函数的首行不产生前导空行；
/// 嵌套调用时缓冲非空，正常换行缩进。
fn write_indent(out : Array[Char], depth : Int) -> Unit {
  if out.length() > 0 {
    out.push('\n')
  }
  let n = depth * 2
  for _ in 0..<n {
    out.push(' ')
  }
}

///|
/// 以空格连接字符串数组。
fn join_with(arr : Array[String], sep : String) -> String {
  let out : Array[Char] = []
  for i, s in arr {
    if i > 0 {
      out.push_iter(sep.iter())
    }
    out.push_iter(s.iter())
  }
  String::from_array(out)
}

///|
/// 写入 `name="value"` 形式的属性（值经属性转义）。
fn write_attr(out : Array[Char], name : String, value : String) -> Unit {
  out.push(' ')
  out.push_iter(name.iter())
  out.push_iter("=\"".iter())
  out.push_iter(@spec.xml_escape_attr(value).iter())
  out.push('"')
}

// ---------------------------------------------------------------------------
// 元数据
// ---------------------------------------------------------------------------

///|
/// 写入单个 Dublin Core 文本元素，如 `<dc:title>…</dc:title>`。
fn write_dc(
  out : Array[Char],
  name : String,
  text : String,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<dc:".iter())
  out.push_iter(name.iter())
  out.push('>')
  out.push_iter(@spec.xml_escape(text).iter())
  out.push_iter("</dc:".iter())
  out.push_iter(name.iter())
  out.push('>')
}

///|
/// 写入 `meta` 细化的 `refines` 形式：
/// `<meta refines="#id" property="…" [scheme="…"]>值</meta>`。
fn write_refines(
  out : Array[Char],
  id : String,
  property : String,
  value : String,
  scheme : String?,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<meta refines=\"#".iter())
  out.push_iter(@spec.xml_escape_attr(id).iter())
  out.push('"')
  write_attr(out, "property", property)
  match scheme {
    Some(s) => write_attr(out, "scheme", s)
    None => ()
  }
  out.push('>')
  out.push_iter(@spec.xml_escape(value).iter())
  out.push_iter("</meta>".iter())
}

///|
/// 写入 `meta(property)` 形式，值可为空（自闭合）。
fn write_meta_property(
  out : Array[Char],
  property : String,
  value : String?,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<meta".iter())
  write_attr(out, "property", property)
  match value {
    Some(v) => {
      out.push('>')
      out.push_iter(@spec.xml_escape(v).iter())
      out.push_iter("</meta>".iter())
    }
    None => out.push_iter("/>".iter())
  }
}

///|
/// 写入贡献者及其角色 / 排序名的细化元数据。
fn write_contributor(
  out : Array[Char],
  element : String,
  id : String,
  contributor : @model.Contributor,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<dc:".iter())
  out.push_iter(element.iter())
  write_attr(out, "id", id)
  out.push('>')
  out.push_iter(@spec.xml_escape(contributor.name).iter())
  out.push_iter("</dc:".iter())
  out.push_iter(element.iter())
  out.push('>')
  match contributor.role {
    Some(role) =>
      write_refines(
        out,
        id,
        "role",
        role,
        Some(@spec.scheme_marc_relators),
        depth,
      )
    None => ()
  }
  match contributor.file_as {
    Some(file_as) => write_refines(out, id, "file-as", file_as, None, depth)
    None => ()
  }
}

///|
/// 写入丛书 / 合集元数据：`belongs-to-collection` 及其细化项。
fn write_series(
  out : Array[Char],
  ordinal : Int,
  series : @model.Series,
  depth : Int,
) -> Unit {
  let id = "series-\{ordinal}"
  write_indent(out, depth)
  out.push_iter("<meta".iter())
  write_attr(out, "property", "belongs-to-collection")
  write_attr(out, "id", id)
  out.push('>')
  out.push_iter(@spec.xml_escape(series.name).iter())
  out.push_iter("</meta>".iter())
  write_refines(out, id, "collection-type", "series", None, depth)
  match series.index {
    Some(index) =>
      write_refines(out, id, "group-position", "\{index}", None, depth)
    None => ()
  }
}

///|
/// 写入自定义 `meta` 条目，兼容模型中的三种形态。
fn write_meta(out : Array[Char], meta : @model.Meta, depth : Int) -> Unit {
  match meta.name {
    Some(name) =>
      match meta.content {
        Some(content) => {
          write_indent(out, depth)
          out.push_iter("<meta".iter())
          write_attr(out, "name", name)
          write_attr(out, "content", content)
          out.push_iter("/>".iter())
        }
        None => ()
      }
    None =>
      match meta.property {
        Some(property) => {
          write_indent(out, depth)
          out.push_iter("<meta".iter())
          match meta.refines {
            Some(refines) => write_attr(out, "refines", "#" + refines)
            None => ()
          }
          write_attr(out, "property", property)
          match meta.scheme {
            Some(scheme) => write_attr(out, "scheme", scheme)
            None => ()
          }
          match meta.id {
            Some(id) => write_attr(out, "id", id)
            None => ()
          }
          match meta.content {
            Some(content) => {
              out.push('>')
              out.push_iter(@spec.xml_escape(content).iter())
              out.push_iter("</meta>".iter())
            }
            None => out.push_iter("/>".iter())
          }
        }
        None => ()
      }
  }
}

///|
/// 写入完整的 `<metadata>` 区块。
pub fn render_metadata(metadata : @model.Metadata, depth : Int) -> String {
  let out : Array[Char] = []
  write_metadata(out, metadata, depth)
  String::from_array(out)
}

///|
/// 把 `<metadata>` 写入缓冲。
fn write_metadata(
  out : Array[Char],
  metadata : @model.Metadata,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<metadata>".iter())
  let inner = depth + 1
  // 唯一标识符：承载 identifier_id，供 package@unique-identifier 引用
  write_indent(out, inner)
  out.push_iter("<dc:identifier".iter())
  write_attr(out, "id", metadata.identifier_id)
  out.push('>')
  out.push_iter(@spec.xml_escape(metadata.identifier).iter())
  out.push_iter("</dc:identifier>".iter())
  write_dc(out, @spec.dc_title, metadata.title, inner)
  write_dc(out, @spec.dc_language, metadata.language, inner)
  for i, creator in metadata.creators {
    write_contributor(out, @spec.dc_creator, "creator-\{i + 1}", creator, inner)
  }
  for i, contributor in metadata.contributors {
    write_contributor(
      out,
      @spec.dc_contributor,
      "contributor-\{i + 1}",
      contributor,
      inner,
    )
  }
  for publisher in metadata.publishers {
    write_dc(out, @spec.dc_publisher, publisher, inner)
  }
  for date in metadata.dates {
    write_dc(out, @spec.dc_date, date, inner)
  }
  for subject in metadata.subjects {
    write_dc(out, @spec.dc_subject, subject, inner)
  }
  for description in metadata.descriptions {
    write_dc(out, @spec.dc_description, description, inner)
  }
  match metadata.rights {
    Some(rights) => write_dc(out, @spec.dc_rights, rights, inner)
    None => ()
  }
  for i, series in metadata.series {
    write_series(out, i + 1, series, inner)
  }
  for meta in metadata.metas {
    write_meta(out, meta, inner)
  }
  match metadata.modified {
    Some(modified) =>
      write_meta_property(out, @spec.property_modified, Some(modified), inner)
    None => ()
  }
  write_indent(out, depth)
  out.push_iter("</metadata>".iter())
}

// ---------------------------------------------------------------------------
// 清单、阅读顺序与指南
// ---------------------------------------------------------------------------

///|
/// 写入完整的 `<manifest>` 区块。
pub fn render_manifest(manifest : @model.Manifest, depth : Int) -> String {
  let out : Array[Char] = []
  write_manifest(out, manifest, depth)
  String::from_array(out)
}

///|
/// 把 `<manifest>` 写入缓冲。
fn write_manifest(
  out : Array[Char],
  manifest : @model.Manifest,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<manifest>".iter())
  for item in manifest.items {
    write_indent(out, depth + 1)
    out.push_iter("<item".iter())
    write_attr(out, "id", item.id)
    write_attr(out, "href", item.href)
    write_attr(out, "media-type", item.media_type)
    if item.properties.length() > 0 {
      write_attr(out, "properties", join_with(item.properties, " "))
    }
    match item.fallback {
      Some(fallback) => write_attr(out, "fallback", fallback)
      None => ()
    }
    match item.media_overlay {
      Some(media_overlay) => write_attr(out, "media-overlay", media_overlay)
      None => ()
    }
    out.push_iter("/>".iter())
  }
  write_indent(out, depth)
  out.push_iter("</manifest>".iter())
}

///|
/// 写入完整的 `<spine>` 区块。
pub fn render_spine(spine : @model.Spine, depth : Int) -> String {
  let out : Array[Char] = []
  write_spine(out, spine, depth)
  String::from_array(out)
}

///|
/// 把 `<spine>` 写入缓冲。
fn write_spine(out : Array[Char], spine : @model.Spine, depth : Int) -> Unit {
  write_indent(out, depth)
  out.push_iter("<spine".iter())
  match spine.toc {
    Some(toc) => write_attr(out, "toc", toc)
    None => ()
  }
  match spine.page_progression_direction {
    Some(direction) => write_attr(out, "page-progression-direction", direction)
    None => ()
  }
  out.push('>')
  for item in spine.items {
    write_indent(out, depth + 1)
    out.push_iter("<itemref".iter())
    write_attr(out, "idref", item.idref)
    if !item.linear {
      write_attr(out, "linear", "no")
    }
    if item.properties.length() > 0 {
      write_attr(out, "properties", join_with(item.properties, " "))
    }
    out.push_iter("/>".iter())
  }
  write_indent(out, depth)
  out.push_iter("</spine>".iter())
}

///|
/// 写入完整的 `<guide>` 区块。
pub fn render_guide(references : Array[GuideReference], depth : Int) -> String {
  let out : Array[Char] = []
  write_guide(out, references, depth)
  String::from_array(out)
}

///|
/// 把 `<guide>` 写入缓冲。
fn write_guide(
  out : Array[Char],
  references : Array[GuideReference],
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<guide>".iter())
  for reference in references {
    write_indent(out, depth + 1)
    out.push_iter("<reference".iter())
    write_attr(out, "type", reference.ref_type)
    write_attr(out, "title", reference.title)
    write_attr(out, "href", reference.href)
    out.push_iter("/>".iter())
  }
  write_indent(out, depth)
  out.push_iter("</guide>".iter())
}

// ---------------------------------------------------------------------------
// 包文档骨架
// ---------------------------------------------------------------------------

///|
/// 渲染完整的 OPF 包文档。
pub fn render_package(book : @model.Book, options : OpfOptions) -> String {
  let metadata = book.metadata
  let unique_id = match options.unique_identifier {
    Some(id) => id
    None => metadata.identifier_id
  }
  let out : Array[Char] = []
  out.push_iter("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".iter())
  out.push_iter("<package".iter())
  write_attr(out, "xmlns", @spec.ns_opf)
  write_attr(out, "xmlns:dc", @spec.ns_dc)
  write_attr(out, "prefix", "\{@spec.prefix_marc}: \{@spec.ns_marc_relators}")
  write_attr(out, "version", options.version)
  write_attr(out, "unique-identifier", unique_id)
  if !metadata.language.is_empty() {
    write_attr(out, "xml:lang", metadata.language)
  }
  out.push('>')
  write_metadata(out, metadata, 1)
  write_manifest(out, book.manifest, 1)
  write_spine(out, book.spine, 1)
  if options.include_guide && options.guide.length() > 0 {
    write_guide(out, options.guide, 1)
  }
  write_indent(out, 0)
  out.push_iter("</package>".iter())
  String::from_array(out)
}
