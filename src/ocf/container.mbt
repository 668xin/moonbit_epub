///|
/// OCF 容器打包（S4）。
///
/// 组织 EPUB 容器内的物理布局：`mimetype` 作为首个条目且不压缩，
/// `META-INF/container.xml` 指向包文档；正文与资源统一置于内容目录
/// （默认 `OEBPS`）之下。`package_book` 从书籍模型自动装配清单、阅读
/// 顺序与全部文件，最终由 ZIP 写入器输出完整 `.epub` 字节流。
///
/// 约定：章节内容文档位于 `OEBPS/text/<id>.xhtml`，包文档、导航文档与
/// 资源则以内容目录为基准；清单 `href` 与资源 `href` 均相对包文档。

// ---------------------------------------------------------------------------
// container.xml
// ---------------------------------------------------------------------------

///|
/// 写入换行与按 `depth` 计算的缩进（每层两个空格）。
///
/// 缓冲为空时不写换行，避免首行出现前导空行。
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
/// 写入 `name="value"` 形式的属性（值经属性转义）。
fn write_attr(out : Array[Char], name : String, value : String) -> Unit {
  out.push(' ')
  out.push_iter(name.iter())
  out.push_iter("=\"".iter())
  out.push_iter(@spec.xml_escape_attr(value).iter())
  out.push('"')
}

///|
/// 生成 `META-INF/container.xml`，`rootfile` 指向给定包文档路径。
pub fn render_container(package_path : String) -> String {
  let out : Array[Char] = []
  out.push_iter("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".iter())
  out.push_iter("<container".iter())
  write_attr(out, "version", @spec.ocf_version)
  write_attr(out, "xmlns", @spec.ns_container)
  out.push('>')
  write_indent(out, 1)
  out.push_iter("<rootfiles>".iter())
  write_indent(out, 2)
  out.push_iter("<rootfile".iter())
  write_attr(out, "full-path", package_path)
  write_attr(out, "media-type", @spec.mt_opf)
  out.push_iter("/>".iter())
  write_indent(out, 1)
  out.push_iter("</rootfiles>".iter())
  write_indent(out, 0)
  out.push_iter("</container>".iter())
  String::from_array(out)
}

// ---------------------------------------------------------------------------
// 打包选项
// ---------------------------------------------------------------------------

///|
/// 容器打包选项。
pub struct PackageOptions {
  // 内容目录（相对容器根），默认为 `OEBPS`
  mut content_dir : String
  // 包文档文件名（位于内容目录内）
  mut package_filename : String
  // 导航文档文件名（位于内容目录内）
  mut nav_filename : String
  // EPUB 2 兼容导航文件名（位于内容目录内）
  mut ncx_filename : String
  // 覆盖文档语言；为空时取书籍元数据语言
  mut language : String
  // 是否为非 mimetype 条目启用 ZIP 数据描述符
  mut use_descriptors : Bool
  // 应用于内容文档的样式表 href（相对内容文档）
  stylesheets : Array[String]
} derive(@debug.Debug)

///|
/// 构造选项：目录与文件名取规范默认值。
pub fn PackageOptions::new() -> PackageOptions {
  {
    content_dir: @spec.default_content_dir,
    package_filename: @spec.default_package_filename,
    nav_filename: @spec.default_nav_filename,
    ncx_filename: @spec.default_ncx_filename,
    language: "",
    use_descriptors: false,
    stylesheets: [],
  }
}

///|
/// 设置内容目录。
pub fn PackageOptions::set_content_dir(
  self : PackageOptions,
  content_dir : String,
) -> Unit {
  self.content_dir = content_dir
}

///|
/// 设置包文档文件名。
pub fn PackageOptions::set_package_filename(
  self : PackageOptions,
  package_filename : String,
) -> Unit {
  self.package_filename = package_filename
}

///|
/// 设置导航文档文件名。
pub fn PackageOptions::set_nav_filename(
  self : PackageOptions,
  nav_filename : String,
) -> Unit {
  self.nav_filename = nav_filename
}

///|
/// 设置 EPUB 2 兼容导航文件名。
pub fn PackageOptions::set_ncx_filename(
  self : PackageOptions,
  ncx_filename : String,
) -> Unit {
  self.ncx_filename = ncx_filename
}

///|
/// 覆盖文档语言。
pub fn PackageOptions::set_language(
  self : PackageOptions,
  language : String,
) -> Unit {
  self.language = language
}

///|
/// 设置是否为非 mimetype 条目启用数据描述符。
pub fn PackageOptions::set_use_descriptors(
  self : PackageOptions,
  use_descriptors : Bool,
) -> Unit {
  self.use_descriptors = use_descriptors
}

///|
/// 追加一个应用于内容文档的样式表 href（相对内容文档，如 `../styles/style.css`）。
pub fn PackageOptions::add_stylesheet(
  self : PackageOptions,
  href : String,
) -> Unit {
  self.stylesheets.push(href)
}

// ---------------------------------------------------------------------------
// 装配
// ---------------------------------------------------------------------------

///|
/// 把字符串按 UTF-8 编码为字节。
fn utf8_bytes(text : String) -> Bytes {
  let buf = Buffer()
  buf.write_string_utf8(text)
  buf.to_bytes()
}

///|
/// 把既有清单条目上的可定制字段合并到自动装配的条目。
///
/// 自动装配负责 `id` / `href` / `media-type` 与文件实际位置，故只继承
/// `properties`、`fallback` 与 `media-overlay`。
fn merge_manifest_fields(
  target : @model.ManifestItem,
  source : @model.ManifestItem,
) -> Unit {
  for property in source.properties {
    if !target.has_property(property) {
      target.add_property(property)
    }
  }
  match source.fallback {
    Some(fallback) => target.set_fallback(fallback)
    None => ()
  }
  match source.media_overlay {
    Some(media_overlay) => target.set_media_overlay(media_overlay)
    None => ()
  }
}

///|
/// 按 href 优先、id 次之查找既有清单条目。
fn find_existing_item(
  manifest : @model.Manifest,
  href : String,
  id : String,
) -> @model.ManifestItem? {
  match manifest.find_by_href(href) {
    Some(item) => Some(item)
    None => manifest.find_by_id(id)
  }
}

///|
/// 查找既有导航条目：优先 `properties` 含 `nav`，其次约定 id / 文件名。
fn find_nav_item(
  manifest : @model.Manifest,
  nav_filename : String,
) -> @model.ManifestItem? {
  for item in manifest.items {
    if item.has_property(@spec.epub_property_nav) {
      return Some(item)
    }
  }
  match manifest.find_by_id(@spec.manifest_id_nav) {
    Some(item) => Some(item)
    None => manifest.find_by_href(nav_filename)
  }
}

///|
/// 依据章节树与资源装配清单：导航、NCX、各章节内容文档与全部资源。
///
/// 章节以 `chapter.id` 作为清单 ID；资源 ID 由其 href 规范化得到，
/// ID 冲突时后续条目被忽略（`Manifest::add` 拒绝重复）。
/// 若书籍已自行登记同名 / 同 href 条目，其 `properties`、`fallback` 与
/// `media-overlay` 会被继承，避免端到端打包丢失用户的清单定制。
fn build_manifest(
  book : @model.Book,
  options : PackageOptions,
) -> @model.Manifest {
  let manifest = @model.Manifest::new()
  let nav_item = @model.ManifestItem::new(
    @spec.manifest_id_nav,
    options.nav_filename,
    @spec.mt_xhtml,
  )
  nav_item.add_property(@spec.epub_property_nav)
  match find_nav_item(book.manifest, options.nav_filename) {
    Some(existing) => merge_manifest_fields(nav_item, existing)
    None => ()
  }
  let _ = manifest.add(nav_item)
  let ncx_item = @model.ManifestItem::new(
    @spec.manifest_id_ncx,
    options.ncx_filename,
    @spec.mt_ncx,
  )
  match
    find_existing_item(
      book.manifest,
      options.ncx_filename,
      @spec.manifest_id_ncx,
    ) {
    Some(existing) => merge_manifest_fields(ncx_item, existing)
    None => ()
  }
  let _ = manifest.add(ncx_item)
  for chapter in @model.flatten_chapters(book.chapters) {
    let href = @model.chapter_href(chapter)
    let item = @model.ManifestItem::new(chapter.id, href, @spec.mt_xhtml)
    match find_existing_item(book.manifest, href, chapter.id) {
      Some(existing) => merge_manifest_fields(item, existing)
      None => ()
    }
    let _ = manifest.add(item)
  }
  for resource in book.resources {
    let id = @model.resource_id(resource)
    let item = @model.ManifestItem::new(id, resource.href, resource.media_type)
    match find_existing_item(book.manifest, resource.href, id) {
      Some(existing) => merge_manifest_fields(item, existing)
      None => ()
    }
    let _ = manifest.add(item)
  }
  manifest
}

///|
/// 依据章节树装配阅读顺序：优先沿用书籍已定义的 `spine`，为空时按
/// 章节树深度优先顺序生成；`spine@toc` 默认指向 NCX 条目。
fn build_spine(book : @model.Book) -> @model.Spine {
  let spine = @model.Spine::new()
  if book.spine.items.length() > 0 {
    for item in book.spine.items {
      spine.add(item)
    }
    match book.spine.toc {
      Some(toc) => spine.set_toc(toc)
      None => spine.set_toc(@spec.manifest_id_ncx)
    }
    match book.spine.page_progression_direction {
      Some(direction) => spine.set_page_progression_direction(direction)
      None => ()
    }
  } else {
    spine.set_toc(@spec.manifest_id_ncx)
    for chapter in @model.flatten_chapters(book.chapters) {
      spine.add(@model.SpineItem::new(chapter.id))
    }
  }
  spine
}

// ---------------------------------------------------------------------------
// 端到端打包
// ---------------------------------------------------------------------------

///|
/// 把书籍模型打包为完整的 EPUB（OCF/ZIP）字节流。
///
/// 生成顺序：`mimetype`（存储）→ `META-INF/container.xml` → 包文档 →
/// 导航文档 → NCX → 各章节内容文档 → 资源。除 `mimetype` 外均优先
/// Deflate 压缩，压缩无收益时自动退回存储。
pub fn package_book(book : @model.Book, options : PackageOptions) -> Bytes {
  let language = if options.language.is_empty() {
    book.metadata.language
  } else {
    options.language
  }
  let content = options.content_dir
  let manifest = build_manifest(book, options)
  let spine = build_spine(book)
  let opf_path = @spec.path_join(content, options.package_filename)
  let opf_text = @opf.render_package_from(
    book.metadata,
    manifest,
    spine,
    @opf.OpfOptions::new(),
  )
  let nav_options = @nav.NavOptions::new()
  nav_options.set_language(language)
  let nav_text = @nav.render_nav(book, nav_options)
  let ncx_options = @nav.NcxOptions::new()
  ncx_options.set_language(language)
  let ncx_text = @nav.render_ncx(book, ncx_options)
  let zip = @zip.ZipWriter::new()
  zip.set_use_descriptors(options.use_descriptors)
  zip.add_stored(@spec.ocf_mimetype, utf8_bytes(@spec.mt_epub))
  zip.add_deflated(
    @spec.ocf_container_path,
    utf8_bytes(render_container(opf_path)),
  )
  zip.add_deflated(opf_path, utf8_bytes(opf_text))
  zip.add_deflated(
    @spec.path_join(content, options.nav_filename),
    utf8_bytes(nav_text),
  )
  zip.add_deflated(
    @spec.path_join(content, options.ncx_filename),
    utf8_bytes(ncx_text),
  )
  for chapter in @model.flatten_chapters(book.chapters) {
    let xhtml_options = @xhtml.XhtmlOptions::new(language~)
    for href in options.stylesheets {
      xhtml_options.add_stylesheet(href)
    }
    let doc = @xhtml.render_document(chapter, xhtml_options)
    zip.add_deflated(
      @spec.path_join(content, @model.chapter_href(chapter)),
      utf8_bytes(doc),
    )
  }
  for resource in book.resources {
    zip.add_deflated(@spec.path_join(content, resource.href), resource.data)
  }
  zip.finish()
}
