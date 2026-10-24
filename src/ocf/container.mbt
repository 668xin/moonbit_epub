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
/// Media Overlay 文件：SMIL 文档及其对应的内容文档。
pub struct MediaOverlayFile {
  // SMIL 文档在内容目录内的路径，如 `text/ch1.smil`
  href : String
  // 对应的内容文档路径，如 `text/ch1.xhtml`
  content_href : String
  // SMIL 文档文本
  smil : String
  // SMIL 总时长（毫秒），用于生成 media:duration 元数据
  duration_ms : Int
} derive(@debug.Debug)

///|
/// 构造 Media Overlay 文件。
pub fn MediaOverlayFile::new(
  href : String,
  content_href : String,
  smil : String,
  duration_ms? : Int,
) -> MediaOverlayFile {
  { href, content_href, smil, duration_ms: duration_ms.unwrap_or(0), }
}

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
  // Media Overlays 文件
  media_overlays : Array[MediaOverlayFile]
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
    media_overlays: [],
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

///|
/// 追加一个 Media Overlay（SMIL）文件及其对应的内容文档。
///
/// `duration_ms` 用于生成 `media:duration` 元数据；缺省为 0 时不生成，
/// 但 EPUB 3 的 Media Overlays 通常要求该元数据，建议显式传入。
pub fn PackageOptions::add_media_overlay(
  self : PackageOptions,
  href : String,
  content_href : String,
  smil : String,
  duration_ms? : Int,
) -> Unit {
  let file = match duration_ms {
    Some(value) =>
      MediaOverlayFile::new(href, content_href, smil, duration_ms=value)
    None => MediaOverlayFile::new(href, content_href, smil)
  }
  self.media_overlays.push(file)
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

// ---------------------------------------------------------------------------
// 生成文档
// ---------------------------------------------------------------------------

///|
/// 已生成的包文档集合：装配后的书籍与三个 XML 文本。
pub struct PackageDocuments {
  book : @model.Book
  opf : String
  nav : String
  ncx : String
} derive(@debug.Debug)

///|
/// 按打包选项覆盖元数据语言。
fn metadata_for(
  metadata : @model.Metadata,
  options : PackageOptions,
) -> @model.Metadata {
  if options.language.is_empty() {
    metadata
  } else {
    metadata.with_language(options.language)
  }
}

///|
/// Media Overlay 的清单 id：由 SMIL 路径规范化得到。
fn media_overlay_id(href : String) -> String {
  "mo-" + @spec.normalize_id(@spec.normalize_path(href))
}

///|
/// 生成 media:duration 元数据：全局总时长与逐覆盖文档时长。
fn media_duration_metas(
  overlays : Array[MediaOverlayFile],
) -> Array[@model.Meta] {
  let out : Array[@model.Meta] = []
  let mut total = 0
  for overlay in overlays {
    total += overlay.duration_ms
    if overlay.duration_ms > 0 {
      out.push(
        @model.Meta::of_property_content_refines(
          "media:duration",
          media_overlay_id(overlay.href),
          @media.format_clock_ms(overlay.duration_ms),
        ),
      )
    }
  }
  if total > 0 {
    out.push(
      @model.Meta::of_property_content(
        "media:duration",
        @media.format_clock_ms(total),
      ),
    )
  }
  out
}

///|
/// 把 Media Overlay 条目加入清单，并为对应内容文档设置 `media-overlay`。
fn apply_media_overlays(
  manifest : @model.Manifest,
  overlays : Array[MediaOverlayFile],
) -> Unit {
  for overlay in overlays {
    let href = @spec.normalize_path(overlay.href)
    let content_href = @spec.normalize_path(overlay.content_href)
    let id = media_overlay_id(overlay.href)
    let item = @model.ManifestItem::new(id, href, @spec.mt_smil)
    let _ = manifest.add(item)
    match manifest.find_by_href(content_href) {
      Some(content) => content.set_media_overlay(id)
      None => ()
    }
  }
}

///|
/// 生成 OPF、nav.xhtml 与 toc.ncx 文本，不写 ZIP。
///
/// 与 `package_book` 使用完全相同的装配与语言覆盖逻辑，便于校验层检查
/// 实际生成的文档。
pub fn render_documents(
  book : @model.Book,
  options : PackageOptions,
) -> PackageDocuments {
  let assembled = @model.assemble_book(
    book,
    nav_filename=options.nav_filename,
    ncx_filename=options.ncx_filename,
  )
  apply_media_overlays(assembled.manifest, options.media_overlays)
  let metadata = metadata_for(assembled.metadata, options).with_metas_appended(
    media_duration_metas(options.media_overlays),
  )
  let assembled = assembled.with_metadata(metadata)
  let language = metadata.language
  let opf_text = @opf.render_package_from(
    metadata,
    assembled.manifest,
    assembled.spine,
    @opf.OpfOptions::new(),
  )
  let nav_options = @nav.NavOptions::new()
  nav_options.set_language(language)
  let nav_text = @nav.render_nav(assembled, nav_options)
  let ncx_options = @nav.NcxOptions::new()
  ncx_options.set_language(language)
  let ncx_text = @nav.render_ncx(assembled, ncx_options)
  { book: assembled, opf: opf_text, nav: nav_text, ncx: ncx_text, }
}

// ---------------------------------------------------------------------------
// 端到端打包
// ---------------------------------------------------------------------------

///|
/// 把书籍模型打包为完整的 EPUB（OCF/ZIP）字节流。
///
/// 生成顺序：`mimetype`（存储）→ `META-INF/container.xml` → 包文档 →
/// 导航文档 → NCX → 各章节内容文档 → 资源 → Media Overlays。除
/// `mimetype` 外均优先 Deflate 压缩，压缩无收益时自动退回存储。
pub fn package_book(book : @model.Book, options : PackageOptions) -> Bytes {
  let documents = render_documents(book, options)
  let content = options.content_dir
  let opf_path = @spec.path_join(content, options.package_filename)
  let language = documents.book.metadata.language
  let zip = @zip.ZipWriter::new()
  zip.set_use_descriptors(options.use_descriptors)
  zip.add_stored(@spec.ocf_mimetype, utf8_bytes(@spec.mt_epub))
  zip.add_deflated(
    @spec.ocf_container_path,
    utf8_bytes(render_container(opf_path)),
  )
  zip.add_deflated(opf_path, utf8_bytes(documents.opf))
  zip.add_deflated(
    @spec.path_join(content, options.nav_filename),
    utf8_bytes(documents.nav),
  )
  zip.add_deflated(
    @spec.path_join(content, options.ncx_filename),
    utf8_bytes(documents.ncx),
  )
  for chapter in @model.flatten_chapters(documents.book.chapters) {
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
  for resource in documents.book.resources {
    zip.add_deflated(
      @spec.path_join(content, @model.resource_href(resource)),
      resource.data,
    )
  }
  for overlay in options.media_overlays {
    zip.add_deflated(
      @spec.path_join(content, @spec.normalize_path(overlay.href)),
      utf8_bytes(overlay.smil),
    )
  }
  zip.finish()
}
