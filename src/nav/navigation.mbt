///|
/// 导航文档生成（S3）。
///
/// 生成 EPUB 3 的 nav.xhtml 导航文档：`epub:type="toc"` 的嵌套目录树，
/// 以及可选的 `epub:type="landmarks"` 地标。同时提供 EPUB 2 兼容的
/// toc.ncx 目录文档（见 `ncx.mbt`），供旧阅读器回退使用。
///
/// 约定 nav.xhtml 位于容器根目录，故章节 href（`text/<id>.xhtml`）
/// 相对其可直接寻址。

// ---------------------------------------------------------------------------
// 选项类型
// ---------------------------------------------------------------------------

///|
/// 导航地标：指向书内重要位置的快捷入口。
pub struct Landmark {
  // 语义类型，如 `cover` / `toc` / `bodymatter`
  ref_type : String
  // 目标，容器内相对路径
  href : String
  // 人类可读标题
  title : String
} derive(Eq, @debug.Debug)

///|
/// 构造导航地标。
pub fn Landmark::new(
  ref_type : String,
  href : String,
  title : String,
) -> Landmark {
  { ref_type, href, title, }
}

///|
/// nav.xhtml 生成选项。
pub struct NavOptions {
  // 文档语言，缺省取书籍元数据语言
  mut language : String
  // `nav` 标题与文档 `<title>`，缺省 `"目录"`
  mut title : String
  // 目录 `nav` 元素的 id
  mut nav_id : String
  // 是否输出地标 `nav`
  mut include_landmarks : Bool
  landmarks : Array[Landmark]
} derive(@debug.Debug)

///|
/// 构造选项：标题 `"目录"`，目录 id `"toc"`，输出地标。
pub fn NavOptions::new() -> NavOptions {
  {
    language: "",
    title: "目录",
    nav_id: "toc",
    include_landmarks: true,
    landmarks: [],
  }
}

///|
/// 设置文档语言。
pub fn NavOptions::set_language(self : NavOptions, language : String) -> Unit {
  self.language = language
}

///|
/// 设置目录标题。
pub fn NavOptions::set_title(self : NavOptions, title : String) -> Unit {
  self.title = title
}

///|
/// 设置目录 `nav` 的 id。
pub fn NavOptions::set_nav_id(self : NavOptions, nav_id : String) -> Unit {
  self.nav_id = nav_id
}

///|
/// 设置是否输出地标 `nav`。
pub fn NavOptions::set_include_landmarks(
  self : NavOptions,
  include_landmarks : Bool,
) -> Unit {
  self.include_landmarks = include_landmarks
}

///|
/// 追加一条地标。
pub fn NavOptions::add_landmark(self : NavOptions, landmark : Landmark) -> Unit {
  self.landmarks.push(landmark)
}

// ---------------------------------------------------------------------------
// 内部写入工具
// ---------------------------------------------------------------------------

///|
/// 写入换行与按 `depth` 计算的缩进（每层两个空格）。
///
/// 缓冲为空时不写换行，避免片段渲染产生前导空行。
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

// ---------------------------------------------------------------------------
// 目录树
// ---------------------------------------------------------------------------

///|
/// 渲染章节森林为嵌套 `<ol>` 目录，供测试与复用。
pub fn render_nav_list(chapters : Array[@model.Chapter], depth : Int) -> String {
  let out : Array[Char] = []
  write_nav_list(out, chapters, depth)
  String::from_array(out)
}

///|
/// 把嵌套目录 `<ol>` 写入缓冲。
fn write_nav_list(
  out : Array[Char],
  chapters : Array[@model.Chapter],
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<ol>".iter())
  for chapter in chapters {
    write_nav_item(out, chapter, depth + 1)
  }
  write_indent(out, depth)
  out.push_iter("</ol>".iter())
}

///|
/// 写入单个目录项；有子章节时递归嵌套 `<ol>`。
fn write_nav_item(
  out : Array[Char],
  chapter : @model.Chapter,
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<li><a".iter())
  write_attr(out, "href", @model.chapter_href(chapter))
  out.push('>')
  out.push_iter(@spec.xml_escape(chapter.title).iter())
  out.push_iter("</a>".iter())
  if chapter.children.length() > 0 {
    write_nav_list(out, chapter.children, depth + 1)
    write_indent(out, depth)
    out.push_iter("</li>".iter())
  } else {
    out.push_iter("</li>".iter())
  }
}

// ---------------------------------------------------------------------------
// 地标
// ---------------------------------------------------------------------------

///|
/// 写入地标 `<nav>`。
fn write_landmarks(
  out : Array[Char],
  landmarks : Array[Landmark],
  depth : Int,
) -> Unit {
  write_indent(out, depth)
  out.push_iter("<nav".iter())
  write_attr(out, "epub:type", @spec.epub_type_landmarks)
  write_attr(out, "hidden", "hidden")
  out.push('>')
  write_indent(out, depth + 1)
  out.push_iter("<ol>".iter())
  for landmark in landmarks {
    write_indent(out, depth + 2)
    out.push_iter("<li><a".iter())
    write_attr(out, "epub:type", landmark.ref_type)
    write_attr(out, "href", landmark.href)
    out.push('>')
    out.push_iter(@spec.xml_escape(landmark.title).iter())
    out.push_iter("</a></li>".iter())
  }
  write_indent(out, depth + 1)
  out.push_iter("</ol>".iter())
  write_indent(out, depth)
  out.push_iter("</nav>".iter())
}

// ---------------------------------------------------------------------------
// 文档骨架
// ---------------------------------------------------------------------------

///|
/// 渲染完整的 nav.xhtml 导航文档。
pub fn render_nav(book : @model.Book, options : NavOptions) -> String {
  let language = if options.language.is_empty() {
    book.metadata.language
  } else {
    options.language
  }
  // 未显式提供地标时，以首个章节作为正文起点
  let landmarks : Array[Landmark] = if options.landmarks.length() > 0 {
    options.landmarks
  } else if book.chapters.length() > 0 {
    let first = book.chapters[0]
    [
      Landmark::new(
        @spec.epub_type_bodymatter,
        @model.chapter_href(first),
        first.title,
      ),
    ]
  } else {
    []
  }
  let out : Array[Char] = []
  out.push_iter("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".iter())
  out.push_iter("<!DOCTYPE html>\n".iter())
  out.push_iter("<html".iter())
  write_attr(out, "xmlns", @spec.ns_xhtml)
  write_attr(out, "xmlns:epub", @spec.ns_epub)
  write_attr(out, "xml:lang", language)
  write_attr(out, "lang", language)
  out.push('>')
  // <head>
  write_indent(out, 1)
  out.push_iter("<head>".iter())
  write_indent(out, 2)
  out.push_iter("<meta charset=\"UTF-8\"/>".iter())
  write_indent(out, 2)
  out.push_iter("<title>".iter())
  out.push_iter(@spec.xml_escape(options.title).iter())
  out.push_iter("</title>".iter())
  write_indent(out, 1)
  out.push_iter("</head>".iter())
  // <body>
  write_indent(out, 1)
  out.push_iter("<body>".iter())
  write_indent(out, 2)
  out.push_iter("<nav".iter())
  write_attr(out, "epub:type", @spec.epub_type_toc)
  write_attr(out, "id", options.nav_id)
  write_attr(out, "role", "doc-toc")
  out.push('>')
  write_indent(out, 3)
  out.push_iter("<h1>".iter())
  out.push_iter(@spec.xml_escape(options.title).iter())
  out.push_iter("</h1>".iter())
  write_nav_list(out, book.chapters, 3)
  write_indent(out, 2)
  out.push_iter("</nav>".iter())
  if options.include_landmarks && landmarks.length() > 0 {
    write_landmarks(out, landmarks, 2)
  }
  write_indent(out, 1)
  out.push_iter("</body>".iter())
  write_indent(out, 0)
  out.push_iter("</html>".iter())
  String::from_array(out)
}
