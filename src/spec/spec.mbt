///|
/// EPUB 规范常量层（S0）。
///
/// 汇聚 W3C EPUB 3.3 与 Open Container Format 3.3 的字面量：
/// XML 命名空间、媒体类型、OCF 保留文件名、Dublin Core 元素名等。
///
/// 本包不依赖任何其他包，是整个引擎的最底层。

///|
/// EPUB 3 包文档（OPF）命名空间。
pub let ns_opf : String = "http://www.idpf.org/2007/opf"

///|
/// EPUB 3 语义属性命名空间（`epub:type`、`epub:prefix` 所在）。
pub let ns_epub : String = "http://www.idpf.org/2007/ops"

///|
/// Dublin Core 元素集命名空间。
pub let ns_dc : String = "http://purl.org/dc/elements/1.1/"

///|
/// Dublin Core 术语（DCMI Metadata Terms）命名空间。
pub let ns_dcterms : String = "http://purl.org/dc/terms/"

///|
/// OCF 容器文档命名空间。
pub let ns_container : String = "urn:oasis:names:tc:opendocument:xmlns:container"

///|
/// XHTML 命名空间。
pub let ns_xhtml : String = "http://www.w3.org/1999/xhtml"

///|
/// XML 保留命名空间。
pub let ns_xml : String = "http://www.w3.org/XML/1998/namespace"

///|
/// SMIL（Media Overlays）命名空间。
pub let ns_smil : String = "http://www.w3.org/ns/SMIL"

///|
/// EPUB 2 兼容导航（`toc.ncx`）命名空间。
pub let ns_ncx : String = "http://www.daisy.org/z3986/2005/ncx/"

///|
/// MARC 责任角色词表（`relators`）命名空间，用于元数据的 `role` 属性。
pub let ns_marc_relators : String = "http://id.loc.gov/vocabulary/relators/"

///|
/// 常用命名空间前缀。
pub let prefix_opf : String = "opf"

///|
/// 常用命名空间前缀。
pub let prefix_dc : String = "dc"

///|
/// 常用命名空间前缀。
pub let prefix_epub : String = "epub"

///|
/// 常用命名空间前缀。
pub let prefix_marc : String = "marc"

///|
/// OCF 硬编码 MIME 类型：`.epub` 容器本身的类型，也是 `mimetype` 文件的内容。
pub let mt_epub : String = "application/epub+zip"

///|
/// OPF 包文档媒体类型。
pub let mt_opf : String = "application/oebps-package+xml"

///|
/// EPUB 2 兼容导航（`toc.ncx`）媒体类型。
pub let mt_ncx : String = "application/x-dtbncx+xml"

///|
/// XHTML5 内容文档媒体类型。
pub let mt_xhtml : String = "application/xhtml+xml"

///|
/// CSS 样式表媒体类型。
pub let mt_css : String = "text/css"

///|
/// JavaScript 媒体类型。
pub let mt_js : String = "text/javascript"

///|
/// 通用 XML 媒体类型。
pub let mt_xml : String = "application/xml"

///|
/// Media Overlays（SMIL）媒体类型。
pub let mt_smil : String = "application/smil+xml"

///|
/// PNG 图片媒体类型。
pub let mt_png : String = "image/png"

///|
/// JPEG 图片媒体类型。
pub let mt_jpeg : String = "image/jpeg"

///|
/// GIF 图片媒体类型。
pub let mt_gif : String = "image/gif"

///|
/// SVG 图片媒体类型。
pub let mt_svg : String = "image/svg+xml"

///|
/// WebP 图片媒体类型。
pub let mt_webp : String = "image/webp"

///|
/// MP3 音频媒体类型。
pub let mt_mp3 : String = "audio/mpeg"

///|
/// MP4/M4A 音频媒体类型。
pub let mt_mp4 : String = "audio/mp4"

///|
/// Ogg 音频媒体类型。
pub let mt_ogg : String = "audio/ogg"

///|
/// TrueType 字体媒体类型。
pub let mt_ttf : String = "font/ttf"

///|
/// OpenType 字体媒体类型。
pub let mt_otf : String = "font/otf"

///|
/// WOFF 字体媒体类型。
pub let mt_woff : String = "font/woff"

///|
/// WOFF2 字体媒体类型。
pub let mt_woff2 : String = "font/woff2"

///|
/// 纯文本媒体类型。
pub let mt_txt : String = "text/plain"

///|
/// 未知扩展名时的回退媒体类型。
pub let mt_octet_stream : String = "application/octet-stream"

///|
/// OCF 容器首条目文件名（必须是压缩包内第一个条目且不压缩）。
pub let ocf_mimetype : String = "mimetype"

///|
/// OCF 容器描述文件路径。
pub let ocf_container_path : String = "META-INF/container.xml"

///|
/// OCF 保留目录名。
pub let ocf_meta_inf_dir : String = "META-INF"

///|
/// OCF 加密描述文件路径。
pub let ocf_encryption_path : String = "META-INF/encryption.xml"

///|
/// OCF 数字签名描述文件路径。
pub let ocf_signatures_path : String = "META-INF/signatures.xml"

///|
/// OCF 权限管理描述文件路径。
pub let ocf_rights_path : String = "META-INF/rights.xml"

///|
/// OCF 清单描述文件路径。
pub let ocf_manifest_path : String = "META-INF/manifest.xml"

///|
/// OCF 元数据描述文件路径。
pub let ocf_metadata_path : String = "META-INF/metadata.xml"

///|
/// OCF 容器文档版本。
pub let ocf_version : String = "1.0"

///|
/// 容器文档（`container.xml`）根元素名。
pub let elem_container : String = "container"

///|
/// 容器文档根文件列表元素名。
pub let elem_rootfiles : String = "rootfiles"

///|
/// 容器文档根文件元素名。
pub let elem_rootfile : String = "rootfile"

///|
/// 根文件元素指向包文档的属性名。
pub let attr_full_path : String = "full-path"

///|
/// 导航文档在清单中 `properties` 的语义值。
pub let epub_property_nav : String = "nav"

///|
/// 内容文档与资源在容器内的默认根目录。
pub let default_content_dir : String = "OEBPS"

///|
/// 包文档（OPF）默认文件名。
pub let default_package_filename : String = "content.opf"

///|
/// 导航文档（nav.xhtml）默认文件名。
pub let default_nav_filename : String = "nav.xhtml"

///|
/// EPUB 2 兼容导航（toc.ncx）默认文件名。
pub let default_ncx_filename : String = "toc.ncx"

///|
/// 清单中导航文档条目的约定 ID。
pub let manifest_id_nav : String = "nav"

///|
/// 清单中 NCX 条目的约定 ID，同时用于 `spine@toc`。
pub let manifest_id_ncx : String = "ncx"

///|
/// 包文档根元素名。
pub let elem_package : String = "package"

///|
/// 元数据区块元素名。
pub let elem_metadata : String = "metadata"

///|
/// 清单区块元素名。
pub let elem_manifest : String = "manifest"

///|
/// 阅读顺序区块元素名。
pub let elem_spine : String = "spine"

///|
/// 指南区块元素名（EPUB 2 兼容）。
pub let elem_guide : String = "guide"

///|
/// 清单条目元素名。
pub let elem_item : String = "item"

///|
/// 阅读顺序条目元素名。
pub let elem_itemref : String = "itemref"

///|
/// EPUB 3 元数据扩展元素名。
pub let elem_meta : String = "meta"

///|
/// OPF 包版本（EPUB 3.3 对应的包文档版本号）。
pub let package_version : String = "3.0"

///|
/// NCX 文档版本（DAISY/Z39.86 2005-1）。
pub let ncx_version : String = "2005-1"

///|
/// 元数据 `role` 属性的默认取值词表标识。
pub let scheme_marc_relators : String = "marc:relators"

///|
/// 导航文档 `<nav>` 的目录语义值。
pub let epub_type_toc : String = "toc"

///|
/// 导航文档 `<nav>` 的地标语义值。
pub let epub_type_landmarks : String = "landmarks"

///|
/// 导航地标中「正文起点」的语义值。
pub let epub_type_bodymatter : String = "bodymatter"

///|
/// Dublin Core 元素名：标题。
pub let dc_title : String = "title"

///|
/// Dublin Core 元素名：创建者。
pub let dc_creator : String = "creator"

///|
/// Dublin Core 元素名：主题。
pub let dc_subject : String = "subject"

///|
/// Dublin Core 元素名：描述。
pub let dc_description : String = "description"

///|
/// Dublin Core 元素名：出版者。
pub let dc_publisher : String = "publisher"

///|
/// Dublin Core 元素名：贡献者。
pub let dc_contributor : String = "contributor"

///|
/// Dublin Core 元素名：日期。
pub let dc_date : String = "date"

///|
/// Dublin Core 元素名：资源类型。
pub let dc_type : String = "type"

///|
/// Dublin Core 元素名：格式。
pub let dc_format : String = "format"

///|
/// Dublin Core 元素名：标识符。
pub let dc_identifier : String = "identifier"

///|
/// Dublin Core 元素名：来源。
pub let dc_source : String = "source"

///|
/// Dublin Core 元素名：语言。
pub let dc_language : String = "language"

///|
/// Dublin Core 元素名：关联。
pub let dc_relation : String = "relation"

///|
/// Dublin Core 元素名：覆盖范围。
pub let dc_coverage : String = "coverage"

///|
/// Dublin Core 元素名：版权。
pub let dc_rights : String = "rights"

///|
/// 全部 Dublin Core 元素名（按规范顺序）。
pub let dc_elements : Array[String] = [
  "title", "creator", "subject", "description", "publisher", "contributor", "date",
  "type", "format", "identifier", "source", "language", "relation", "coverage", "rights",
]

///|
/// EPUB 3 必需的 `dcterms:modified` 元数据属性名。
pub let property_modified : String = "dcterms:modified"

///|
/// 唯一标识符前缀：基于内容的 UUID 派生的 URN 形式。
pub let urn_uuid_prefix : String = "urn:uuid:"

///|
/// 内置样式表在容器内的默认路径。
pub let default_stylesheet_path : String = "styles/style.css"

///|
/// 内容文档存放目录。
pub let default_text_dir : String = "text"

///|
/// 图片资源存放目录。
pub let default_images_dir : String = "images"

///|
/// 字体资源存放目录。
pub let default_fonts_dir : String = "fonts"

///|
/// 取路径中最后一个 `.` 之后的扩展名（不含点，统一小写）。
///
/// 无扩展名时返回空串。
pub fn extension_of(path : String) -> String {
  let base = path_basename(path)
  match base.rev_find(".") {
    Some(i) => {
      let (_, tail) = base.split_at(i + 1)
      tail.to_owned().to_lower()
    }
    None => ""
  }
}

///|
/// 按扩展名推断媒体类型，未识别时回退到 `application/octet-stream`。
pub fn media_type_of_path(path : String) -> String {
  match extension_of(path) {
    "xhtml" | "html" | "htm" => mt_xhtml
    "ncx" => mt_ncx
    "opf" => mt_opf
    "css" => mt_css
    "js" | "mjs" => mt_js
    "xml" => mt_xml
    "smil" => mt_smil
    "png" => mt_png
    "jpg" | "jpeg" => mt_jpeg
    "gif" => mt_gif
    "svg" => mt_svg
    "webp" => mt_webp
    "mp3" => mt_mp3
    "m4a" | "mp4" => mt_mp4
    "ogg" | "oga" => mt_ogg
    "ttf" => mt_ttf
    "otf" => mt_otf
    "woff" => mt_woff
    "woff2" => mt_woff2
    "txt" => mt_txt
    _ => mt_octet_stream
  }
}

///|
/// 取路径的目录部分；无目录分隔符时返回 `"."`。
pub fn path_dirname(path : String) -> String {
  match path.rev_find("/") {
    Some(i) =>
      if i == 0 {
        "/"
      } else {
        let (head, _) = path.split_at(i)
        head.to_owned()
      }
    None => "."
  }
}

///|
/// 取路径的文件名部分。
pub fn path_basename(path : String) -> String {
  match path.rev_find("/") {
    Some(i) => {
      let (_, tail) = path.split_at(i + 1)
      tail.to_owned()
    }
    None => path
  }
}
