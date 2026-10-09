///|
/// 内容模型（S1）。
///
/// 定义书籍正文的结构化表示：块级元素 `Block` 与内联元素 `Inline`。
/// 该模型是 XHTML 内容文档生成（S2）的直接输入，本身不含任何序列化逻辑。

///|
/// 内联元素：出现在段落、标题、表格单元格等块级元素内部的顺序内容。
pub enum Inline {
  /// 纯文本。
  Text(String)
  /// 强调（`em`）。
  Emphasis(Array[Inline])
  /// 加粗（`strong`）。
  Strong(Array[Inline])
  /// 行内代码（`code`）。
  Code(String)
  /// 超链接（`a`）。
  Link(href~ : String, children~ : Array[Inline])
  /// 脚注引用标记，指向对应的 `Block::Note`。
  FootnoteRef(id~ : String)
} derive(Eq, @debug.Debug)

///|
/// 块级内容元素。
pub enum Block {
  /// 段落。
  Paragraph(Array[Inline])
  /// 标题，`level` 为 1–6。
  Heading(level~ : Int, children~ : Array[Inline])
  /// 列表，`items` 的每个元素是一个列表项的块序列。
  List(ordered~ : Bool, items~ : Array[Array[Block]])
  /// 引用块。
  Blockquote(Array[Block])
  /// 代码块，`language` 可为空。
  CodeBlock(language~ : String, code~ : String)
  /// 图片。
  Image(src~ : String, alt~ : String)
  /// 表格，表头一行，数据若干行，单元格为内联序列。
  Table(header~ : Array[Array[Inline]], rows~ : Array[Array[Array[Inline]]])
  /// 水平分隔线。
  HorizontalRule
  /// 脚注/尾注的正文，由 `Inline::FootnoteRef` 引用。
  Note(id~ : String, blocks~ : Array[Block])
} derive(Eq, @debug.Debug)

///|
/// 构造纯文本内联。
pub fn Inline::text(text : String) -> Inline {
  Text(text)
}

///|
/// 构造强调内联。
pub fn Inline::emphasis(children : Array[Inline]) -> Inline {
  Emphasis(children)
}

///|
/// 构造加粗内联。
pub fn Inline::strong(children : Array[Inline]) -> Inline {
  Strong(children)
}

///|
/// 构造行内代码。
pub fn Inline::code(code : String) -> Inline {
  Code(code)
}

///|
/// 构造超链接。
pub fn Inline::link(href : String, children : Array[Inline]) -> Inline {
  Link(href~, children~)
}

///|
/// 构造脚注引用。
pub fn Inline::footnote_ref(id : String) -> Inline {
  FootnoteRef(id~)
}

///|
/// 构造仅含纯文本的段落。
pub fn Block::paragraph(text : String) -> Block {
  Paragraph([Text(text)])
}

///|
/// 构造仅含纯文本的标题。
pub fn Block::heading(level : Int, text : String) -> Block {
  Heading(level~, children=[Text(text)])
}

///|
/// 构造列表。
pub fn Block::list(ordered : Bool, items : Array[Array[Block]]) -> Block {
  List(ordered~, items~)
}

///|
/// 构造引用块。
pub fn Block::blockquote(blocks : Array[Block]) -> Block {
  Blockquote(blocks)
}

///|
/// 构造代码块。
pub fn Block::code_block(language : String, code : String) -> Block {
  CodeBlock(language~, code~)
}

///|
/// 构造图片。
pub fn Block::image(src : String, alt : String) -> Block {
  Image(src~, alt~)
}

///|
/// 构造表格。
pub fn Block::table(
  header : Array[Array[Inline]],
  rows : Array[Array[Array[Inline]]],
) -> Block {
  Table(header~, rows~)
}

///|
/// 构造水平分隔线。
pub fn Block::horizontal_rule() -> Block {
  HorizontalRule
}

///|
/// 构造脚注正文。
pub fn Block::note(id : String, blocks : Array[Block]) -> Block {
  Note(id~, blocks~)
}

///|
/// 提取内联序列的纯文本内容（丢弃标记，仅保留文字）。
pub fn plain_text(inlines : Array[Inline]) -> String {
  let out : Array[Char] = []
  for inline in inlines {
    append_inline_text(inline, out)
  }
  String::from_array(out)
}

///|
/// 递归收集单个内联元素的文字。
fn append_inline_text(inline : Inline, out : Array[Char]) -> Unit {
  match inline {
    Text(s) | Code(s) => out.push_iter(s.iter())
    Emphasis(children) | Strong(children) =>
      for child in children {
        append_inline_text(child, out)
      }
    Link(children~, ..) =>
      for child in children {
        append_inline_text(child, out)
      }
    FootnoteRef(..) => ()
  }
}
