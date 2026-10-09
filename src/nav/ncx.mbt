///|
/// EPUB 2 兼容导航（`toc.ncx`）生成。
///
/// 供不支持 EPUB 3 导航文档的旧阅读器回退使用：以 DAISY/Z39.86 NCX
/// 结构描述目录树，`navPoint` 深度优先编号，`content@src` 指向内容文档。

///|
/// NCX 生成选项。
pub struct NcxOptions {
  // 文档语言，缺省取书籍元数据语言
  mut language : String
  // `dtb:uid` 的值，缺省取书籍唯一标识符
  mut uid : String?
  // `docTitle` 文本，缺省取书籍标题
  mut title : String?
  // 是否输出 `playOrder` 属性
  mut include_play_order : Bool
} derive(@debug.Debug)

///|
/// 构造选项：语言与标识符取书籍元数据，输出 `playOrder`。
pub fn NcxOptions::new() -> NcxOptions {
  { language: "", uid: None, title: None, include_play_order: true, }
}

///|
/// 设置文档语言。
pub fn NcxOptions::set_language(self : NcxOptions, language : String) -> Unit {
  self.language = language
}

///|
/// 覆盖 `dtb:uid`。
pub fn NcxOptions::set_uid(self : NcxOptions, uid : String) -> Unit {
  self.uid = Some(uid)
}

///|
/// 覆盖 `docTitle` 文本。
pub fn NcxOptions::set_title(self : NcxOptions, title : String) -> Unit {
  self.title = Some(title)
}

///|
/// 设置是否输出 `playOrder`。
pub fn NcxOptions::set_include_play_order(
  self : NcxOptions,
  include_play_order : Bool,
) -> Unit {
  self.include_play_order = include_play_order
}

///|
/// `navPoint` 深度优先序号计数器。
struct NavCounter {
  mut next : Int
}

///|
/// 渲染章节森林为 `<navMap>` 内容，供测试与复用。
pub fn render_nav_map(
  chapters : Array[@model.Chapter],
  include_play_order : Bool,
) -> String {
  let out : Array[Char] = []
  write_nav_points(out, chapters, 0, { next: 1, }, include_play_order)
  String::from_array(out)
}

///|
/// 深度优先写入 `navPoint` 序列，序号自 `counter.next` 起递增。
fn write_nav_points(
  out : Array[Char],
  chapters : Array[@model.Chapter],
  depth : Int,
  counter : NavCounter,
  include_play_order : Bool,
) -> Unit {
  for chapter in chapters {
    let n = counter.next
    counter.next = n + 1
    write_indent(out, depth)
    out.push_iter("<navPoint".iter())
    write_attr(out, "id", "navPoint-\{n}")
    if include_play_order {
      write_attr(out, "playOrder", "\{n}")
    }
    out.push('>')
    write_indent(out, depth + 1)
    out.push_iter("<navLabel>".iter())
    write_indent(out, depth + 2)
    out.push_iter("<text>".iter())
    out.push_iter(@spec.xml_escape(chapter.title).iter())
    out.push_iter("</text>".iter())
    write_indent(out, depth + 1)
    out.push_iter("</navLabel>".iter())
    write_indent(out, depth + 1)
    out.push_iter("<content".iter())
    write_attr(out, "src", @model.chapter_href(chapter))
    out.push_iter("/>".iter())
    write_nav_points(
      out,
      chapter.children,
      depth + 1,
      counter,
      include_play_order,
    )
    write_indent(out, depth)
    out.push_iter("</navPoint>".iter())
  }
}

///|
/// 渲染完整的 toc.ncx 文档。
pub fn render_ncx(book : @model.Book, options : NcxOptions) -> String {
  let language = if options.language.is_empty() {
    book.metadata.language
  } else {
    options.language
  }
  let uid = match options.uid {
    Some(uid) => uid
    None => book.metadata.identifier
  }
  let title = match options.title {
    Some(title) => title
    None => book.metadata.title
  }
  let depth = @model.chapter_depth(book.chapters)
  let out : Array[Char] = []
  out.push_iter("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".iter())
  out.push_iter(
    "<!DOCTYPE ncx PUBLIC \"-//NISO//DTD ncx 2005-1//EN\" \"http://www.daisy.org/z3986/2005/ncx-2005-1.dtd\">\n".iter(),
  )
  out.push_iter("<ncx".iter())
  write_attr(out, "xmlns", @spec.ns_ncx)
  write_attr(out, "version", @spec.ncx_version)
  write_attr(out, "xml:lang", language)
  out.push('>')
  // <head>
  write_indent(out, 1)
  out.push_iter("<head>".iter())
  write_meta(out, "dtb:uid", uid, 2)
  write_meta(out, "dtb:depth", "\{depth}", 2)
  write_meta(out, "dtb:totalPageCount", "0", 2)
  write_meta(out, "dtb:maxPageNumber", "0", 2)
  write_indent(out, 1)
  out.push_iter("</head>".iter())
  // <docTitle>
  write_indent(out, 1)
  out.push_iter("<docTitle>".iter())
  write_indent(out, 2)
  out.push_iter("<text>".iter())
  out.push_iter(@spec.xml_escape(title).iter())
  out.push_iter("</text>".iter())
  write_indent(out, 1)
  out.push_iter("</docTitle>".iter())
  // <navMap>
  write_indent(out, 1)
  out.push_iter("<navMap>".iter())
  write_nav_points(
    out,
    book.chapters,
    2,
    { next: 1, },
    options.include_play_order,
  )
  write_indent(out, 1)
  out.push_iter("</navMap>".iter())
  write_indent(out, 0)
  out.push_iter("</ncx>".iter())
  String::from_array(out)
}

///|
/// 写入 `<meta name="…" content="…"/>`。
fn write_meta(
  out : Array[Char],
  name : String,
  content : String,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<meta".iter())
  write_attr(out, "name", name)
  write_attr(out, "content", content)
  out.push_iter("/>".iter())
}
