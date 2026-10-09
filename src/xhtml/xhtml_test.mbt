///|
/// S2 XHTML5 内容文档骨架与块级/内联元素渲染的单元测试。

///|
test "render_inline: 基础内联元素与转义" {
  assert_eq(render_inline(@model.Inline::text("a < b & c")), "a &lt; b &amp; c")
  assert_eq(
    render_inline(@model.Inline::emphasis([@model.Inline::text("e")])),
    "<em>e</em>",
  )
  assert_eq(
    render_inline(@model.Inline::strong([@model.Inline::text("s")])),
    "<strong>s</strong>",
  )
  assert_eq(
    render_inline(@model.Inline::code("x < y")),
    "<code>x &lt; y</code>",
  )
  assert_eq(
    render_inline(@model.Inline::link("a.xhtml", [@model.Inline::text("l")])),
    "<a href=\"a.xhtml\">l</a>",
  )
}

///|
test "render_inlines: 链接属性转义" {
  assert_eq(
    render_inlines([
      @model.Inline::link("a\"b.xhtml", [@model.Inline::text("t")]),
    ]),
    "<a href=\"a&quot;b.xhtml\">t</a>",
  )
}

///|
test "render_block: 段落与标题层级" {
  assert_eq(render_block(@model.Block::paragraph("hi")), "<p>hi</p>")
  assert_eq(render_block(@model.Block::heading(2, "T")), "<h2>T</h2>")
  assert_eq(render_block(@model.Block::heading(0, "T")), "<h1>T</h1>")
  assert_eq(render_block(@model.Block::heading(9, "T")), "<h6>T</h6>")
  assert_eq(render_block(@model.Block::horizontal_rule()), "<hr/>")
}

///|
test "render_block: 列表（单项内联展开与多项嵌套）" {
  let ul = @model.Block::list(false, [[@model.Block::paragraph("a")]])
  assert_eq(render_block(ul), "<ul>\n  <li>a</li>\n</ul>")
  let ol = @model.Block::list(true, [[@model.Block::paragraph("a")]])
  assert_eq(render_block(ol), "<ol>\n  <li>a</li>\n</ol>")
  let nested = @model.Block::list(false, [
    [@model.Block::paragraph("a"), @model.Block::paragraph("b")],
  ])
  assert_eq(
    render_block(nested),
    "<ul>\n  <li>\n    <p>a</p>\n    <p>b</p>\n  </li>\n</ul>",
  )
}

///|
test "render_block: 引用、代码块与图片" {
  let bq = @model.Block::blockquote([@model.Block::paragraph("q")])
  assert_eq(render_block(bq), "<blockquote>\n  <p>q</p>\n</blockquote>")
  assert_eq(
    render_block(@model.Block::code_block("moonbit", "let x = 1")),
    "<pre><code class=\"language-moonbit\">let x = 1</code></pre>",
  )
  assert_eq(
    render_block(@model.Block::code_block("", "a < b")),
    "<pre><code>a &lt; b</code></pre>",
  )
  assert_eq(
    render_block(@model.Block::image("images/a.png", "图 \"x\"")),
    "<img src=\"images/a.png\" alt=\"图 &quot;x&quot;\"/>",
  )
}

///|
test "render_block: 表格" {
  let t = @model.Block::table([[@model.Inline::text("H")]], [
    [[@model.Inline::text("c")]],
  ])
  assert_eq(
    render_block(t),
    "<table>\n  <thead>\n    <tr><th>H</th></tr>\n  </thead>\n" +
    "  <tbody>\n    <tr><td>c</td></tr>\n  </tbody>\n</table>",
  )
}

///|
test "render_blocks: 块之间以换行分隔" {
  assert_eq(
    render_blocks([@model.Block::paragraph("a"), @model.Block::paragraph("b")]),
    "<p>a</p>\n<p>b</p>",
  )
  assert_eq(render_blocks([]), "")
}

///|
test "render_document: 完整骨架与元数据" {
  let chapter = @model.Chapter::with_body("ch1", "第一章", [
    @model.Block::paragraph("正文"),
  ])
  let options = XhtmlOptions::new(language="zh-CN")
  options.add_stylesheet("styles/style.css")
  let doc = render_document(chapter, options)
  let expected =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<!DOCTYPE html>
    #|<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="zh-CN" lang="zh-CN">
    #|  <head>
    #|    <meta charset="UTF-8"/>
    #|    <title>第一章</title>
    #|    <link rel="stylesheet" type="text/css" href="styles/style.css"/>
    #|  </head>
    #|  <body>
    #|    <p>正文</p>
    #|  </body>
    #|</html>
  assert_eq(doc, expected)
}

///|
test "render_document: 默认语言与空正文" {
  let chapter = @model.Chapter::new("c", "T")
  let doc = render_document(chapter, XhtmlOptions::new())
  assert_true(doc.contains("xml:lang=\"en\" lang=\"en\""))
  assert_true(doc.contains("<body>\n  </body>"))
  assert_true(doc.has_suffix("</html>"))
}

///|
test "NoteIndex: 按出现顺序编号且去重" {
  let index = NoteIndex::from_inlines([
    @model.Inline::footnote_ref("n2"),
    @model.Inline::footnote_ref("n1"),
    @model.Inline::footnote_ref("n2"),
  ])
  assert_eq(index.length(), 2)
  assert_eq(index.number_of("n2"), Some(1))
  assert_eq(index.number_of("n1"), Some(2))
  assert_eq(index.number_of("n3"), None)
}

///|
test "render_inlines: 脚注引用带编号与 epub:type 语义" {
  let rendered = render_inlines([
    @model.Inline::footnote_ref("n1"),
    @model.Inline::text("，"),
    @model.Inline::footnote_ref("n2"),
  ])
  assert_true(
    rendered.contains(
      "<a href=\"#n1\" id=\"ref-n1\" class=\"footnote-ref\" epub:type=\"noteref\" role=\"doc-noteref\"><sup>1</sup></a>",
    ),
  )
  assert_true(rendered.contains("<sup>2</sup>"))
}

///|
test "render_block: 脚注正文为语义化 aside" {
  let note = @model.Block::note("n1", [@model.Block::paragraph("注文")])
  assert_eq(
    render_block(note),
    "<aside id=\"n1\" epub:type=\"footnote\" role=\"doc-footnote\">\n" +
    "  <p>注文</p>\n</aside>",
  )
}

///|
test "render_document: body 语义与正文脚注" {
  let chapter = @model.Chapter::with_body("c", "T", [
    @model.Block::note("n1", [@model.Block::paragraph("注")]),
  ])
  let options = XhtmlOptions::new(language="zh")
  options.set_body_type("bodymatter")
  let doc = render_document(chapter, options)
  assert_true(doc.contains("<body epub:type=\"bodymatter\">"))
  assert_true(doc.contains("epub:type=\"footnote\""))
  assert_true(doc.contains("role=\"doc-footnote\""))
}
