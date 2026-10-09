///|
/// 脚注与注记语义（S2）。
///
/// 脚注引用 `Inline::FootnoteRef` 与脚注正文 `Block::Note` 通过 id 关联，
/// 编号按其在文档中的出现顺序确定。渲染时使用 EPUB 3 语义属性
/// `epub:type="noteref"` / `epub:type="footnote"` 及对应 ARIA role，
/// 便于阅读器与辅助技术识别并建立双向跳转。

///|
/// 脚注编号表：记录脚注 id 的首次出现顺序，编号自 1 起。
pub struct NoteIndex {
  order : Array[String]
}

///|
/// 构造空的编号表。
pub fn NoteIndex::empty() -> NoteIndex {
  { order: [], }
}

///|
/// 登记脚注 id 并返回其编号；重复登记返回既有编号。
fn NoteIndex::intern(self : NoteIndex, id : String) -> Int {
  for i, existing in self.order {
    if existing == id {
      return i + 1
    }
  }
  self.order.push(id)
  self.order.length()
}

///|
/// 查询脚注编号，未登记时返回 `None`。
pub fn NoteIndex::number_of(self : NoteIndex, id : String) -> Int? {
  for i, existing in self.order {
    if existing == id {
      return Some(i + 1)
    }
  }
  None
}

///|
/// 已登记的脚注数量。
pub fn NoteIndex::length(self : NoteIndex) -> Int {
  self.order.length()
}

///|
/// 扫描内联序列，按出现顺序登记脚注引用。
fn collect_inlines(index : NoteIndex, inlines : Array[@model.Inline]) -> Unit {
  for inline in inlines {
    match inline {
      Text(_) | Code(_) => ()
      Emphasis(children) | Strong(children) => collect_inlines(index, children)
      Link(children~, ..) => collect_inlines(index, children)
      FootnoteRef(id~) => {
        let _ = index.intern(id)
      }
    }
  }
}

///|
/// 扫描块序列，按出现顺序登记全部脚注引用。
fn collect_blocks(index : NoteIndex, blocks : Array[@model.Block]) -> Unit {
  for block in blocks {
    match block {
      Paragraph(inlines) => collect_inlines(index, inlines)
      Heading(children~, ..) => collect_inlines(index, children)
      List(items~, ..) =>
        for item in items {
          collect_blocks(index, item)
        }
      Blockquote(blocks) => collect_blocks(index, blocks)
      Table(header~, rows~) => {
        for cell in header {
          collect_inlines(index, cell)
        }
        for row in rows {
          for cell in row {
            collect_inlines(index, cell)
          }
        }
      }
      Note(blocks~, ..) => collect_blocks(index, blocks)
      CodeBlock(..) | Image(..) | HorizontalRule => ()
    }
  }
}

///|
/// 扫描块序列构造编号表。
pub fn NoteIndex::from_blocks(blocks : Array[@model.Block]) -> NoteIndex {
  let index = NoteIndex::empty()
  collect_blocks(index, blocks)
  index
}

///|
/// 扫描内联序列构造编号表。
pub fn NoteIndex::from_inlines(inlines : Array[@model.Inline]) -> NoteIndex {
  let index = NoteIndex::empty()
  collect_inlines(index, inlines)
  index
}

///|
/// 渲染脚注引用为带编号的语义化链接，`id` 用于回跳至引用处。
fn write_footnote_ref(
  out : Array[Char],
  id : String,
  notes : NoteIndex,
) -> Unit {
  let attr = @spec.xml_escape_attr(id)
  let marker = match notes.number_of(id) {
    Some(n) => "\{n}"
    None => id
  }
  out.push_iter("<a href=\"#".iter())
  out.push_iter(attr.iter())
  out.push_iter("\" id=\"ref-".iter())
  out.push_iter(attr.iter())
  out.push_iter(
    "\" class=\"footnote-ref\" epub:type=\"noteref\" role=\"doc-noteref\"><sup>".iter(),
  )
  out.push_iter(@spec.xml_escape(marker).iter())
  out.push_iter("</sup></a>".iter())
}

///|
/// 渲染脚注/尾注正文为语义化 `aside`。
fn write_note(
  out : Array[Char],
  id : String,
  blocks : Array[@model.Block],
  depth : Int,
  notes : NoteIndex,
) -> Unit {
  out.push_iter("<aside id=\"".iter())
  out.push_iter(@spec.xml_escape_attr(id).iter())
  out.push_iter("\" epub:type=\"footnote\" role=\"doc-footnote\">".iter())
  write_blocks(out, blocks, depth + 1, notes)
  write_indent(out, depth)
  out.push_iter("</aside>".iter())
}
