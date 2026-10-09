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

///|
test "render_block: 标题 1–6 级全量渲染" {
  assert_eq(render_block(@model.Block::heading(1, "L")), "<h1>L</h1>")
  assert_eq(render_block(@model.Block::heading(2, "L")), "<h2>L</h2>")
  assert_eq(render_block(@model.Block::heading(3, "L")), "<h3>L</h3>")
  assert_eq(render_block(@model.Block::heading(4, "L")), "<h4>L</h4>")
  assert_eq(render_block(@model.Block::heading(5, "L")), "<h5>L</h5>")
  assert_eq(render_block(@model.Block::heading(6, "L")), "<h6>L</h6>")
}

///|
test "render_block: 标题文本转义" {
  assert_eq(
    render_block(@model.Block::heading(2, "A & B")),
    "<h2>A &amp; B</h2>",
  )
  assert_eq(render_block(@model.Block::heading(6, "")), "<h6></h6>")
}

///|
test "render_block: 列表嵌套子列表与多项顺序" {
  let nested = @model.Block::list(false, [
    [
      @model.Block::paragraph("a"),
      @model.Block::list(true, [[@model.Block::paragraph("b")]]),
    ],
  ])
  assert_eq(
    render_block(nested),
    "<ul>\n  <li>\n    <p>a</p>\n    <ol>\n      <li>b</li>\n    </ol>\n  </li>\n</ul>",
  )
  let multi = @model.Block::list(true, [
    [@model.Block::paragraph("1")],
    [@model.Block::paragraph("2")],
  ])
  assert_eq(render_block(multi), "<ol>\n  <li>1</li>\n  <li>2</li>\n</ol>")
}

///|
test "render_block: 引用嵌套缩进" {
  let nested = @model.Block::blockquote([
    @model.Block::blockquote([@model.Block::paragraph("x")]),
  ])
  assert_eq(
    render_block(nested),
    "<blockquote>\n  <blockquote>\n    <p>x</p>\n  </blockquote>\n</blockquote>",
  )
}

///|
test "render_block: 代码块语言属性转义与空语言" {
  assert_eq(
    render_block(@model.Block::code_block("c\"d", "x")),
    "<pre><code class=\"language-c&quot;d\">x</code></pre>",
  )
  assert_eq(
    render_block(@model.Block::code_block("", "")),
    "<pre><code></code></pre>",
  )
}

///|
test "render_block: 表格表头/数据行与空表边界" {
  let both = @model.Block::table(
    [[@model.Inline::text("A")], [@model.Inline::text("B")]],
    [[[@model.Inline::text("1")], [@model.Inline::text("2")]]],
  )
  assert_eq(
    render_block(both),
    "<table>\n  <thead>\n    <tr><th>A</th><th>B</th></tr>\n  </thead>\n" +
    "  <tbody>\n    <tr><td>1</td><td>2</td></tr>\n  </tbody>\n</table>",
  )
  let header_only = @model.Block::table([[@model.Inline::text("H")]], [])
  assert_eq(
    render_block(header_only),
    "<table>\n  <thead>\n    <tr><th>H</th></tr>\n  </thead>\n</table>",
  )
  let rows_only = @model.Block::table([], [[[@model.Inline::text("c")]]])
  assert_eq(
    render_block(rows_only),
    "<table>\n  <tbody>\n    <tr><td>c</td></tr>\n  </tbody>\n</table>",
  )
  assert_eq(render_block(@model.Block::table([], [])), "<table>\n</table>")
}

///|
test "render_block: 图片空 alt 与 src 属性转义" {
  assert_eq(
    render_block(@model.Block::image("a b.png", "")),
    "<img src=\"a b.png\" alt=\"\"/>",
  )
  assert_eq(
    render_block(@model.Block::image("i\"x.png", "图")),
    "<img src=\"i&quot;x.png\" alt=\"图\"/>",
  )
}

///|
test "render_inline: 内联嵌套与文本/代码转义" {
  assert_eq(
    render_inline(
      @model.Inline::emphasis([
        @model.Inline::strong([@model.Inline::text("x")]),
      ]),
    ),
    "<em><strong>x</strong></em>",
  )
  assert_eq(
    render_inline(
      @model.Inline::link("u", [
        @model.Inline::emphasis([@model.Inline::text("e")]),
      ]),
    ),
    "<a href=\"u\"><em>e</em></a>",
  )
  assert_eq(render_inline(@model.Inline::code("a&b")), "<code>a&amp;b</code>")
  // 文本转义只处理 & < >，不动引号
  assert_eq(render_inline(@model.Inline::text("a'b\"c")), "a'b\"c")
}

///|
test "render_block: 空段落与水平线序列" {
  assert_eq(render_block(@model.Block::paragraph("")), "<p></p>")
  assert_eq(
    render_blocks([
      @model.Block::paragraph("a"),
      @model.Block::horizontal_rule(),
      @model.Block::paragraph("b"),
    ]),
    "<p>a</p>\n<hr/>\n<p>b</p>",
  )
}

///|
test "NoteIndex: 跨嵌套块编号顺序与去重" {
  let blocks : Array[@model.Block] = [
    @model.Block::table([[@model.Inline::footnote_ref("n1")]], [
      [[@model.Inline::footnote_ref("n2")]],
    ]),
    @model.Block::blockquote([
      @model.Block::table([], [[[@model.Inline::footnote_ref("n1")]]]),
    ]),
    @model.Block::note("note", [
      @model.Block::table([[@model.Inline::footnote_ref("n3")]], []),
    ]),
  ]
  let index = NoteIndex::from_blocks(blocks)
  assert_eq(index.length(), 3)
  assert_eq(index.number_of("n1"), Some(1))
  assert_eq(index.number_of("n2"), Some(2))
  assert_eq(index.number_of("n3"), Some(3))
}

///|
test "NoteIndex: 空输入边界" {
  let empty = NoteIndex::empty()
  assert_eq(empty.length(), 0)
  assert_eq(empty.number_of("x"), None)
  assert_eq(NoteIndex::from_blocks([]).length(), 0)
  assert_eq(
    NoteIndex::from_blocks([@model.Block::paragraph("无脚注")]).length(),
    0,
  )
}

///|
test "render_document: 骨架属性、多样式表与标题转义" {
  let chapter = @model.Chapter::with_body("c1", "A & B", [
    @model.Block::paragraph("t"),
  ])
  let options = XhtmlOptions::new(language="fr")
  options.add_stylesheet("s1.css")
  options.add_stylesheet("s2.css")
  let doc = render_document(chapter, options)
  assert_true(
    doc.contains(
      "<html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\"",
    ),
  )
  assert_true(doc.contains("<meta charset=\"UTF-8\"/>"))
  assert_true(doc.contains("<title>A &amp; B</title>"))
  assert_true(
    doc.contains("<link rel=\"stylesheet\" type=\"text/css\" href=\"s1.css\"/>"),
  )
  assert_true(
    doc.contains("<link rel=\"stylesheet\" type=\"text/css\" href=\"s2.css\"/>"),
  )
}

///|
test "render_document: 语言属性转义与无 body 语义" {
  let chapter = @model.Chapter::new("c", "T")
  let options = XhtmlOptions::new(language="en\"gb")
  let doc = render_document(chapter, options)
  assert_true(doc.contains("xml:lang=\"en&quot;gb\" lang=\"en&quot;gb\""))
  assert_true(doc.contains("<body>"))
  assert_false(doc.contains("epub:type=\"bodymatter\""))
  assert_true(doc.contains("<title>T</title>"))
}
