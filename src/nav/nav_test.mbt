///|
/// S3 nav.xhtml 与 toc.ncx 导航生成的单元测试。

///|
/// 构造测试用章节森林：第一章含一个子章节，第二章为叶节点。
fn sample_chapters() -> Array[@model.Chapter] {
  let ch1 = @model.Chapter::new("ch1", "第一章")
  ch1.add_child(@model.Chapter::new("ch1-1", "第一节"))
  let ch2 = @model.Chapter::new("ch2", "第二章")
  [ch1, ch2]
}

///|
/// 构造测试用书籍。
fn sample_book() -> @model.Book {
  @model.Book::new(@model.Metadata::new("书名", "zh-CN", "urn:uuid:1234"))
}

///|
test "render_nav_list: 嵌套目录树" {
  let out = render_nav_list(sample_chapters(), 0)
  let expected =
    #|<ol>
    #|  <li><a href="text/ch1.xhtml">第一章</a>
    #|    <ol>
    #|      <li><a href="text/ch1-1.xhtml">第一节</a></li>
    #|    </ol>
    #|  </li>
    #|  <li><a href="text/ch2.xhtml">第二章</a></li>
    #|</ol>
  assert_eq(out, expected)
  assert_eq(render_nav_list([], 0), "<ol>\n</ol>")
}

///|
test "render_nav: 完整文档含目录与自动地标" {
  let book = sample_book()
  for chapter in sample_chapters() {
    book.add_chapter(chapter)
  }
  let out = render_nav(book, NavOptions::new())
  let expected =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<!DOCTYPE html>
    #|<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="zh-CN" lang="zh-CN">
    #|  <head>
    #|    <meta charset="UTF-8"/>
    #|    <title>目录</title>
    #|  </head>
    #|  <body>
    #|    <nav epub:type="toc" id="toc" role="doc-toc">
    #|      <h1>目录</h1>
    #|      <ol>
    #|        <li><a href="text/ch1.xhtml">第一章</a>
    #|          <ol>
    #|            <li><a href="text/ch1-1.xhtml">第一节</a></li>
    #|          </ol>
    #|        </li>
    #|        <li><a href="text/ch2.xhtml">第二章</a></li>
    #|      </ol>
    #|    </nav>
    #|    <nav epub:type="landmarks" hidden="hidden">
    #|      <ol>
    #|        <li><a epub:type="bodymatter" href="text/ch1.xhtml">第一章</a></li>
    #|      </ol>
    #|    </nav>
    #|  </body>
    #|</html>
  assert_eq(out, expected)
}

///|
test "render_nav: 选项覆盖标题/语言/id 与自定义地标" {
  let book = sample_book()
  for chapter in sample_chapters() {
    book.add_chapter(chapter)
  }
  let options = NavOptions::new()
  options.set_title("Contents")
  options.set_language("en")
  options.set_nav_id("nav-toc")
  options.add_landmark(Landmark::new("cover", "text/cover.xhtml", "Cover"))
  options.add_landmark(Landmark::new("toc", "nav.xhtml", "Contents"))
  let out = render_nav(book, options)
  assert_true(out.contains("xml:lang=\"en\" lang=\"en\""))
  assert_true(out.contains("<title>Contents</title>"))
  assert_true(out.contains("<h1>Contents</h1>"))
  assert_true(
    out.contains("<nav epub:type=\"toc\" id=\"nav-toc\" role=\"doc-toc\">"),
  )
  assert_true(
    out.contains(
      "<li><a epub:type=\"cover\" href=\"text/cover.xhtml\">Cover</a></li>",
    ),
  )
  assert_true(
    out.contains(
      "<li><a epub:type=\"toc\" href=\"nav.xhtml\">Contents</a></li>",
    ),
  )
}

///|
test "render_nav: 关闭地标与空章节" {
  let book = sample_book()
  let options = NavOptions::new()
  options.set_include_landmarks(false)
  let out = render_nav(book, options)
  assert_false(out.contains("landmarks"))
  assert_true(out.contains("<ol>\n      </ol>\n    </nav>"))
}

///|
test "render_nav_map: 深度优先编号与 playOrder" {
  let out = render_nav_map(sample_chapters(), true)
  let expected =
    #|<navPoint id="navPoint-1" playOrder="1">
    #|  <navLabel>
    #|    <text>第一章</text>
    #|  </navLabel>
    #|  <content src="text/ch1.xhtml"/>
    #|  <navPoint id="navPoint-2" playOrder="2">
    #|    <navLabel>
    #|      <text>第一节</text>
    #|    </navLabel>
    #|    <content src="text/ch1-1.xhtml"/>
    #|  </navPoint>
    #|</navPoint>
    #|<navPoint id="navPoint-3" playOrder="3">
    #|  <navLabel>
    #|    <text>第二章</text>
    #|  </navLabel>
    #|  <content src="text/ch2.xhtml"/>
    #|</navPoint>
  assert_eq(out, expected)
  let no_order = render_nav_map(sample_chapters(), false)
  assert_false(no_order.contains("playOrder"))
  assert_eq(render_nav_map([], true), "")
}

///|
test "render_ncx: 完整向后兼容导航文档" {
  let book = sample_book()
  for chapter in sample_chapters() {
    book.add_chapter(chapter)
  }
  let out = render_ncx(book, NcxOptions::new())
  let expected =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">
    #|<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1" xml:lang="zh-CN">
    #|  <head>
    #|    <meta name="dtb:uid" content="urn:uuid:1234"/>
    #|    <meta name="dtb:depth" content="2"/>
    #|    <meta name="dtb:totalPageCount" content="0"/>
    #|    <meta name="dtb:maxPageNumber" content="0"/>
    #|  </head>
    #|  <docTitle>
    #|    <text>书名</text>
    #|  </docTitle>
    #|  <navMap>
    #|    <navPoint id="navPoint-1" playOrder="1">
    #|      <navLabel>
    #|        <text>第一章</text>
    #|      </navLabel>
    #|      <content src="text/ch1.xhtml"/>
    #|      <navPoint id="navPoint-2" playOrder="2">
    #|        <navLabel>
    #|          <text>第一节</text>
    #|        </navLabel>
    #|        <content src="text/ch1-1.xhtml"/>
    #|      </navPoint>
    #|    </navPoint>
    #|    <navPoint id="navPoint-3" playOrder="3">
    #|      <navLabel>
    #|        <text>第二章</text>
    #|      </navLabel>
    #|      <content src="text/ch2.xhtml"/>
    #|    </navPoint>
    #|  </navMap>
    #|</ncx>
  assert_eq(out, expected)
}

///|
test "render_ncx: 选项覆盖 uid/title 与关闭 playOrder" {
  let book = sample_book()
  book.add_chapter(@model.Chapter::new("ch1", "第一章"))
  let options = NcxOptions::new()
  options.set_uid("custom-uid")
  options.set_title("Custom")
  options.set_language("en")
  options.set_include_play_order(false)
  let out = render_ncx(book, options)
  assert_true(out.contains("<meta name=\"dtb:uid\" content=\"custom-uid\"/>"))
  assert_true(out.contains("<text>Custom</text>"))
  assert_true(out.contains("<meta name=\"dtb:depth\" content=\"1\"/>"))
  assert_true(out.contains("xml:lang=\"en\""))
  assert_false(out.contains("playOrder"))
}

///|
/// 构造三层章节森林：ch1 > ch1-1 > ch1-1-1，另有叶节点 ch2。
fn deep_chapters() -> Array[@model.Chapter] {
  let mid = @model.Chapter::new("ch1-1", "第一节")
  mid.add_child(@model.Chapter::new("ch1-1-1", "第一节一"))
  let ch1 = @model.Chapter::new("ch1", "第一章")
  ch1.add_child(mid)
  [ch1, @model.Chapter::new("ch2", "第二章")]
}

///|
test "render_nav_list: 三层目录树层级与顺序" {
  let expected =
    #|<ol>
    #|  <li><a href="text/ch1.xhtml">第一章</a>
    #|    <ol>
    #|      <li><a href="text/ch1-1.xhtml">第一节</a>
    #|        <ol>
    #|          <li><a href="text/ch1-1-1.xhtml">第一节一</a></li>
    #|        </ol>
    #|      </li>
    #|    </ol>
    #|  </li>
    #|  <li><a href="text/ch2.xhtml">第二章</a></li>
    #|</ol>
  assert_eq(render_nav_list(deep_chapters(), 0), expected)
}

///|
test "render_nav_list: 标题转义与起始缩进深度" {
  let chapters = [@model.Chapter::new("a", "A & B <c>")]
  assert_eq(
    render_nav_list(chapters, 0),
    "<ol>\n  <li><a href=\"text/a.xhtml\">A &amp; B &lt;c&gt;</a></li>\n</ol>",
  )
  assert_eq(
    render_nav_list(chapters, 1),
    "  <ol>\n    <li><a href=\"text/a.xhtml\">A &amp; B &lt;c&gt;</a></li>\n  </ol>",
  )
}

///|
test "render_nav: 单章节无子目录" {
  let book = @model.Book::new(@model.Metadata::new("B", "ja", "urn:1"))
  book.add_chapter(@model.Chapter::new("only", "唯一"))
  let out = render_nav(book, NavOptions::new())
  assert_true(out.contains("xml:lang=\"ja\" lang=\"ja\""))
  assert_true(out.contains("<li><a href=\"text/only.xhtml\">唯一</a></li>"))
  assert_true(
    out.contains(
      "<li><a epub:type=\"bodymatter\" href=\"text/only.xhtml\">唯一</a></li>",
    ),
  )
}

///|
test "render_nav: 空章节且开启地标时不输出 landmarks" {
  let book = @model.Book::new(@model.Metadata::new("B", "en", "urn:1"))
  let out = render_nav(book, NavOptions::new())
  assert_false(out.contains("landmarks"))
  assert_true(out.contains("      <ol>\n      </ol>"))
}

///|
test "render_nav: 标题与 nav id 属性转义" {
  let book = @model.Book::new(@model.Metadata::new("B", "en", "urn:1"))
  book.add_chapter(@model.Chapter::new("c", "C"))
  let options = NavOptions::new()
  options.set_title("目录 & 指南")
  options.set_nav_id("a\"b")
  let out = render_nav(book, options)
  assert_true(out.contains("<title>目录 &amp; 指南</title>"))
  assert_true(out.contains("<h1>目录 &amp; 指南</h1>"))
  assert_true(out.contains("id=\"a&quot;b\""))
}

///|
test "render_nav: 地标标题转义" {
  let book = @model.Book::new(@model.Metadata::new("B", "en", "urn:1"))
  book.add_chapter(@model.Chapter::new("c", "C"))
  let options = NavOptions::new()
  options.add_landmark(Landmark::new("cover", "cover.xhtml", "A & B"))
  let out = render_nav(book, options)
  assert_true(
    out.contains(
      "<li><a epub:type=\"cover\" href=\"cover.xhtml\">A &amp; B</a></li>",
    ),
  )
}

///|
test "render_nav_map: 三层深度优先 playOrder 编号" {
  let out = render_nav_map(deep_chapters(), true)
  assert_true(out.contains("<navPoint id=\"navPoint-1\" playOrder=\"1\">"))
  assert_true(out.contains("<navPoint id=\"navPoint-2\" playOrder=\"2\">"))
  assert_true(out.contains("<navPoint id=\"navPoint-3\" playOrder=\"3\">"))
  assert_true(out.contains("<navPoint id=\"navPoint-4\" playOrder=\"4\">"))
  assert_true(out.contains("<content src=\"text/ch1-1-1.xhtml\"/>"))
  assert_false(out.contains("navPoint-5"))
}

///|
test "render_nav_map: 标题转义与 content 目标" {
  let out = render_nav_map([@model.Chapter::new("a", "A & B")], true)
  assert_true(out.contains("<text>A &amp; B</text>"))
  assert_true(out.contains("<content src=\"text/a.xhtml\"/>"))
}

///|
test "render_ncx: 空章节深度与空 navMap" {
  let book = @model.Book::new(@model.Metadata::new("书名", "zh", "urn:1"))
  let out = render_ncx(book, NcxOptions::new())
  assert_true(out.contains("<meta name=\"dtb:depth\" content=\"0\"/>"))
  assert_true(out.contains("  <navMap>\n  </navMap>"))
  assert_false(out.contains("<navPoint"))
}

///|
test "render_ncx: 三层深度与 docTitle/uid 转义" {
  let book = @model.Book::new(@model.Metadata::new("书 & 名", "zh", "urn:1"))
  for chapter in deep_chapters() {
    book.add_chapter(chapter)
  }
  let options = NcxOptions::new()
  options.set_uid("u\"id")
  let out = render_ncx(book, options)
  assert_true(out.contains("<meta name=\"dtb:depth\" content=\"3\"/>"))
  assert_true(out.contains("<text>书 &amp; 名</text>"))
  assert_true(out.contains("<meta name=\"dtb:uid\" content=\"u&quot;id\"/>"))
}

///|
test "render_ncx: title 覆盖与文本转义" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:1"))
  let options = NcxOptions::new()
  options.set_title("A < B")
  let out = render_ncx(book, options)
  assert_true(out.contains("<text>A &lt; B</text>"))
}
