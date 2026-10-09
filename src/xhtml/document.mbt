///|
/// XHTML5 内容文档生成（S2）。
///
/// 把章节模型序列化为符合 EPUB 3 内容文档要求的 XHTML5：文档骨架
/// （XML 声明、DOCTYPE、命名空间）、头部元数据与块级/内联元素渲染。
/// 输出为 `String`，不做任何文件写入（IO 由 CLI 层负责）。

///|
/// 文档级渲染选项。
pub struct XhtmlOptions {
  // 文档语言（BCP 47），写入 `<html>` 的 `xml:lang` 与 `lang`
  mut language : String
  // 应用于 `<head>` 的样式表 href 列表（相对当前内容文档路径）
  stylesheets : Array[String]
}

///|
/// 构造渲染选项，语言缺省为 `"en"`。
pub fn XhtmlOptions::new(language? : String) -> XhtmlOptions {
  { language: language.unwrap_or("en"), stylesheets: [], }
}

///|
/// 设置文档语言。
pub fn XhtmlOptions::set_language(
  self : XhtmlOptions,
  language : String,
) -> Unit {
  self.language = language
}

///|
/// 追加一个样式表引用。
pub fn XhtmlOptions::add_stylesheet(self : XhtmlOptions, href : String) -> Unit {
  self.stylesheets.push(href)
}

// ---------------------------------------------------------------------------
// 内联元素渲染
// ---------------------------------------------------------------------------

///|
/// 渲染单个内联元素为 XHTML 片段。
pub fn render_inline(inline : @model.Inline) -> String {
  let out : Array[Char] = []
  write_inline(out, inline)
  String::from_array(out)
}

///|
/// 渲染内联序列为 XHTML 片段。
pub fn render_inlines(inlines : Array[@model.Inline]) -> String {
  let out : Array[Char] = []
  write_inlines(out, inlines)
  String::from_array(out)
}

///|
/// 把内联序列写入字符缓冲。
fn write_inlines(out : Array[Char], inlines : Array[@model.Inline]) -> Unit {
  for inline in inlines {
    write_inline(out, inline)
  }
}

///|
/// 渲染单个内联元素到字符缓冲。
fn write_inline(out : Array[Char], inline : @model.Inline) -> Unit {
  match inline {
    Text(s) => out.push_iter(@spec.xml_escape(s).iter())
    Emphasis(children) => {
      out.push_iter("<em>".iter())
      write_inlines(out, children)
      out.push_iter("</em>".iter())
    }
    Strong(children) => {
      out.push_iter("<strong>".iter())
      write_inlines(out, children)
      out.push_iter("</strong>".iter())
    }
    Code(s) => {
      out.push_iter("<code>".iter())
      out.push_iter(@spec.xml_escape(s).iter())
      out.push_iter("</code>".iter())
    }
    Link(href~, children~) => {
      out.push_iter("<a href=\"".iter())
      out.push_iter(@spec.xml_escape_attr(href).iter())
      out.push_iter("\">".iter())
      write_inlines(out, children)
      out.push_iter("</a>".iter())
    }
    FootnoteRef(id~) => write_footnote_ref(out, id)
  }
}

// ---------------------------------------------------------------------------
// 块级元素渲染
// ---------------------------------------------------------------------------

///|
/// 渲染单个块级元素为 XHTML 片段（无自身前导缩进）。
pub fn render_block(block : @model.Block) -> String {
  let out : Array[Char] = []
  write_block(out, block, 0)
  String::from_array(out)
}

///|
/// 渲染块序列为 XHTML 片段，块之间以换行分隔。
pub fn render_blocks(blocks : Array[@model.Block]) -> String {
  let out : Array[Char] = []
  for i, block in blocks {
    if i > 0 {
      write_indent(out, 0)
    }
    write_block(out, block, 0)
  }
  String::from_array(out)
}

///|
/// 把块序列写入缓冲，每块前换行并缩进到 `depth`。
fn write_blocks(
  out : Array[Char],
  blocks : Array[@model.Block],
  depth : Int,
) -> Unit {
  for block in blocks {
    write_indent(out, depth)
    write_block(out, block, depth)
  }
}

///|
/// 渲染单个块级元素（不含自身前导缩进）。
fn write_block(out : Array[Char], block : @model.Block, depth : Int) -> Unit {
  match block {
    Paragraph(inlines) => {
      out.push_iter("<p>".iter())
      write_inlines(out, inlines)
      out.push_iter("</p>".iter())
    }
    Heading(level~, children~) => {
      let level = clamp_heading(level)
      out.push_iter("<h\{level}>".iter())
      write_inlines(out, children)
      out.push_iter("</h\{level}>".iter())
    }
    List(ordered~, items~) => write_list(out, ordered, items, depth)
    Blockquote(blocks) => {
      out.push_iter("<blockquote>".iter())
      write_blocks(out, blocks, depth + 1)
      write_indent(out, depth)
      out.push_iter("</blockquote>".iter())
    }
    CodeBlock(language~, code~) => write_code_block(out, language, code)
    Image(src~, alt~) => write_image(out, src, alt)
    Table(header~, rows~) => write_table(out, header, rows, depth)
    HorizontalRule => out.push_iter("<hr/>".iter())
    Note(id~, blocks~) => write_note(out, id, blocks, depth)
  }
}

///|
/// 写入换行与按 `depth` 计算的缩进（每层两个空格）。
fn write_indent(out : Array[Char], depth : Int) -> Unit {
  out.push('\n')
  let n = depth * 2
  for _ in 0..<n {
    out.push(' ')
  }
}

///|
/// 把标题层级夹取到 1–6。
fn clamp_heading(level : Int) -> Int {
  if level < 1 {
    1
  } else if level > 6 {
    6
  } else {
    level
  }
}

///|
/// 渲染列表；列表项恰为单个段落时内联展开，否则嵌套渲染。
fn write_list(
  out : Array[Char],
  ordered : Bool,
  items : Array[Array[@model.Block]],
  depth : Int,
) -> Unit {
  let tag = if ordered { "ol" } else { "ul" }
  out.push_iter("<\{tag}>".iter())
  for item in items {
    match single_paragraph(item) {
      Some(inlines) => {
        write_indent(out, depth + 1)
        out.push_iter("<li>".iter())
        write_inlines(out, inlines)
        out.push_iter("</li>".iter())
      }
      None => {
        write_indent(out, depth + 1)
        out.push_iter("<li>".iter())
        write_blocks(out, item, depth + 2)
        write_indent(out, depth + 1)
        out.push_iter("</li>".iter())
      }
    }
  }
  write_indent(out, depth)
  out.push_iter("</\{tag}>".iter())
}

///|
/// 若块序列恰为单个段落，返回其内联序列。
fn single_paragraph(blocks : Array[@model.Block]) -> Array[@model.Inline]? {
  if blocks.length() == 1 {
    match blocks[0] {
      Paragraph(inlines) => Some(inlines)
      _ => None
    }
  } else {
    None
  }
}

///|
/// 渲染代码块；`language` 非空时附加 `language-*` 类名。
fn write_code_block(
  out : Array[Char],
  language : String,
  code : String,
) -> Unit {
  out.push_iter("<pre>".iter())
  if language.is_empty() {
    out.push_iter("<code>".iter())
  } else {
    out.push_iter("<code class=\"language-".iter())
    out.push_iter(@spec.xml_escape_attr(language).iter())
    out.push_iter("\">".iter())
  }
  out.push_iter(@spec.xml_escape(code).iter())
  out.push_iter("</code></pre>".iter())
}

///|
/// 渲染图片（XHTML 空元素）。
fn write_image(out : Array[Char], src : String, alt : String) -> Unit {
  out.push_iter("<img src=\"".iter())
  out.push_iter(@spec.xml_escape_attr(src).iter())
  out.push_iter("\" alt=\"".iter())
  out.push_iter(@spec.xml_escape_attr(alt).iter())
  out.push_iter("\"/>".iter())
}

///|
/// 渲染表格：表头一行进 `thead`，数据行进 `tbody`。
fn write_table(
  out : Array[Char],
  header : Array[Array[@model.Inline]],
  rows : Array[Array[Array[@model.Inline]]],
  depth : Int,
) -> Unit {
  out.push_iter("<table>".iter())
  if header.length() > 0 {
    write_indent(out, depth + 1)
    out.push_iter("<thead>".iter())
    write_indent(out, depth + 2)
    write_cells(out, header, "th")
    write_indent(out, depth + 1)
    out.push_iter("</thead>".iter())
  }
  if rows.length() > 0 {
    write_indent(out, depth + 1)
    out.push_iter("<tbody>".iter())
    for row in rows {
      write_indent(out, depth + 2)
      write_cells(out, row, "td")
    }
    write_indent(out, depth + 1)
    out.push_iter("</tbody>".iter())
  }
  write_indent(out, depth)
  out.push_iter("</table>".iter())
}

///|
/// 渲染一行表格单元格，`tag` 为 `th` 或 `td`。
fn write_cells(
  out : Array[Char],
  cells : Array[Array[@model.Inline]],
  tag : String,
) -> Unit {
  out.push_iter("<tr>".iter())
  for cell in cells {
    out.push_iter("<\{tag}>".iter())
    write_inlines(out, cell)
    out.push_iter("</\{tag}>".iter())
  }
  out.push_iter("</tr>".iter())
}

// ---------------------------------------------------------------------------
// 脚注与文档骨架
// ---------------------------------------------------------------------------

///|
/// 渲染脚注引用为指向脚注正文的链接。
fn write_footnote_ref(out : Array[Char], id : String) -> Unit {
  let attr = @spec.xml_escape_attr(id)
  out.push_iter("<a href=\"#".iter())
  out.push_iter(attr.iter())
  out.push_iter("\" class=\"footnote-ref\">".iter())
  out.push_iter(@spec.xml_escape(id).iter())
  out.push_iter("</a>".iter())
}

///|
/// 渲染脚注/尾注正文容器。
fn write_note(
  out : Array[Char],
  id : String,
  blocks : Array[@model.Block],
  depth : Int,
) -> Unit {
  out.push_iter("<aside id=\"".iter())
  out.push_iter(@spec.xml_escape_attr(id).iter())
  out.push_iter("\">".iter())
  write_blocks(out, blocks, depth + 1)
  write_indent(out, depth)
  out.push_iter("</aside>".iter())
}

///|
/// 渲染章节为完整的 XHTML5 内容文档。
pub fn render_document(
  chapter : @model.Chapter,
  options : XhtmlOptions,
) -> String {
  let out : Array[Char] = []
  out.push_iter("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".iter())
  out.push_iter("<!DOCTYPE html>\n".iter())
  out.push_iter("<html xmlns=\"".iter())
  out.push_iter(@spec.ns_xhtml.iter())
  out.push_iter("\" xmlns:epub=\"".iter())
  out.push_iter(@spec.ns_epub.iter())
  out.push_iter("\" xml:lang=\"".iter())
  out.push_iter(@spec.xml_escape_attr(options.language).iter())
  out.push_iter("\" lang=\"".iter())
  out.push_iter(@spec.xml_escape_attr(options.language).iter())
  out.push_iter("\">".iter())
  // <head>
  write_indent(out, 1)
  out.push_iter("<head>".iter())
  write_indent(out, 2)
  out.push_iter("<meta charset=\"UTF-8\"/>".iter())
  write_indent(out, 2)
  out.push_iter("<title>".iter())
  out.push_iter(@spec.xml_escape(chapter.title).iter())
  out.push_iter("</title>".iter())
  for href in options.stylesheets {
    write_indent(out, 2)
    out.push_iter("<link rel=\"stylesheet\" type=\"text/css\" href=\"".iter())
    out.push_iter(@spec.xml_escape_attr(href).iter())
    out.push_iter("\"/>".iter())
  }
  write_indent(out, 1)
  out.push_iter("</head>".iter())
  // <body>
  write_indent(out, 1)
  out.push_iter("<body>".iter())
  write_blocks(out, chapter.body, 2)
  write_indent(out, 1)
  out.push_iter("</body>".iter())
  write_indent(out, 0)
  out.push_iter("</html>".iter())
  String::from_array(out)
}
