///|
/// S3 OPF 包文档序列化的单元测试。

///|
test "render_metadata: Dublin Core 全集顺序与转义" {
  let m = @model.Metadata::new("A & B", "zh-CN", "urn:uuid:x")
  m.add_creator(@model.Contributor::new("张三"))
  m.add_contributor(@model.Contributor::new("李四", role="edt"))
  m.add_publisher("P?")
  m.add_date("2026")
  m.add_subject("Fiction")
  m.add_description("<d>")
  m.set_rights("(c) 2026")
  let out = render_metadata(m, 0)
  let expected =
    #|<metadata>
    #|  <dc:identifier id="pub-id">urn:uuid:x</dc:identifier>
    #|  <dc:title>A &amp; B</dc:title>
    #|  <dc:language>zh-CN</dc:language>
    #|  <dc:creator id="creator-1">张三</dc:creator>
    #|  <dc:contributor id="contributor-1">李四</dc:contributor>
    #|  <meta refines="#contributor-1" property="role" scheme="marc:relators">edt</meta>
    #|  <dc:publisher>P?</dc:publisher>
    #|  <dc:date>2026</dc:date>
    #|  <dc:subject>Fiction</dc:subject>
    #|  <dc:description>&lt;d&gt;</dc:description>
    #|  <dc:rights>(c) 2026</dc:rights>
    #|</metadata>
  assert_eq(out, expected)
}

///|
test "render_metadata: 贡献者 role/file-as 细化与 dcterms:modified" {
  let m = @model.Metadata::new("T", "en", "id")
  m.add_creator(
    @model.Contributor::new("Jane Doe", role="aut", file_as="Doe, Jane"),
  )
  m.set_modified("2026-10-09T00:00:00Z")
  let out = render_metadata(m, 0)
  assert_true(
    out.contains(
      "<meta refines=\"#creator-1\" property=\"role\" scheme=\"marc:relators\">aut</meta>",
    ),
  )
  assert_true(
    out.contains(
      "<meta refines=\"#creator-1\" property=\"file-as\">Doe, Jane</meta>",
    ),
  )
  assert_true(
    out.contains(
      "<meta property=\"dcterms:modified\">2026-10-09T00:00:00Z</meta>",
    ),
  )
}

///|
test "render_metadata: 丛书与自定义 meta 三形态" {
  let m = @model.Metadata::new("T", "en", "id")
  m.add_series(@model.Series::new("S"))
  m.add_series(@model.Series::new("S2", index=2))
  m.add_meta(@model.Meta::named("calibre:series", "X"))
  m.add_meta(@model.Meta::of_property("dcterms:modified"))
  m.add_meta(@model.Meta::refining("title-type", "pub-title"))
  let out = render_metadata(m, 0)
  assert_true(
    out.contains(
      "<meta property=\"belongs-to-collection\" id=\"series-1\">S</meta>",
    ),
  )
  assert_true(
    out.contains(
      "<meta refines=\"#series-1\" property=\"collection-type\">series</meta>",
    ),
  )
  assert_false(out.contains("group-position\">1")) // 无 index 时不产出 group-position
  assert_true(
    out.contains(
      "<meta refines=\"#series-2\" property=\"group-position\">2</meta>",
    ),
  )
  assert_true(out.contains("<meta name=\"calibre:series\" content=\"X\"/>"))
  assert_true(out.contains("<meta property=\"dcterms:modified\"/>"))
  assert_true(
    out.contains("<meta refines=\"#pub-title\" property=\"title-type\"/>"),
  )
}

///|
test "render_manifest: 属性、properties 与 fallback" {
  let manifest = @model.Manifest::new()
  let nav = @model.ManifestItem::new(
    "nav", "nav.xhtml", "application/xhtml+xml",
  )
  nav.add_property("nav")
  nav.add_property("scripted")
  let _ = manifest.add(nav)
  let cover = @model.ManifestItem::new("cover", "cover.jpg", "image/jpeg")
  cover.set_fallback("fallback-id")
  cover.set_media_overlay("mo-1")
  let _ = manifest.add(cover)
  let out = render_manifest(manifest, 0)
  let expected =
    #|<manifest>
    #|  <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav scripted"/>
    #|  <item id="cover" href="cover.jpg" media-type="image/jpeg" fallback="fallback-id" media-overlay="mo-1"/>
    #|</manifest>
  assert_eq(out, expected)
}

///|
test "render_spine: toc、线性和 page-progression-direction" {
  let spine = @model.Spine::new()
  spine.add(@model.SpineItem::new("i1"))
  spine.add(@model.SpineItem::non_linear("i2"))
  spine.set_toc("ncx")
  let out = render_spine(spine, 0)
  let expected =
    #|<spine toc="ncx">
    #|  <itemref idref="i1"/>
    #|  <itemref idref="i2" linear="no"/>
    #|</spine>
  assert_eq(out, expected)
}

///|
test "render_guide: 指南引用" {
  let refs : Array[GuideReference] = [
    GuideReference::new("cover", "封面", "text/cover.xhtml"),
    GuideReference::new("toc", "目录", "nav.xhtml"),
  ]
  let out = render_guide(refs, 0)
  let expected =
    #|<guide>
    #|  <reference type="cover" title="封面" href="text/cover.xhtml"/>
    #|  <reference type="toc" title="目录" href="nav.xhtml"/>
    #|</guide>
  assert_eq(out, expected)
}

///|
test "render_package: 完整包文档" {
  let m = @model.Metadata::new("书名 & 副题", "zh-CN", "urn:uuid:1234")
  m.set_modified("2026-10-09T12:00:00Z")
  m.add_creator(
    @model.Contributor::new("张三", role="aut", file_as="Zhang, San"),
  )
  m.add_publisher("示例出版社")
  m.add_series(@model.Series::new("示例丛书", index=2))
  let book = @model.Book::new(m)
  let nav = @model.ManifestItem::new(
    "nav", "nav.xhtml", "application/xhtml+xml",
  )
  nav.add_property("nav")
  let _ = book.add_manifest_item(nav)
  book.spine.add(@model.SpineItem::non_linear("nav"))
  book.spine.set_toc("ncx")
  let out = render_package(book, OpfOptions::new())
  let expected =
    #|<?xml version="1.0" encoding="UTF-8"?>
    #|<package xmlns="http://www.idpf.org/2007/opf" xmlns:dc="http://purl.org/dc/elements/1.1/" prefix="marc: http://id.loc.gov/vocabulary/relators/" version="3.0" unique-identifier="pub-id" xml:lang="zh-CN">
    #|  <metadata>
    #|    <dc:identifier id="pub-id">urn:uuid:1234</dc:identifier>
    #|    <dc:title>书名 &amp; 副题</dc:title>
    #|    <dc:language>zh-CN</dc:language>
    #|    <dc:creator id="creator-1">张三</dc:creator>
    #|    <meta refines="#creator-1" property="role" scheme="marc:relators">aut</meta>
    #|    <meta refines="#creator-1" property="file-as">Zhang, San</meta>
    #|    <dc:publisher>示例出版社</dc:publisher>
    #|    <meta property="belongs-to-collection" id="series-1">示例丛书</meta>
    #|    <meta refines="#series-1" property="collection-type">series</meta>
    #|    <meta refines="#series-1" property="group-position">2</meta>
    #|    <meta property="dcterms:modified">2026-10-09T12:00:00Z</meta>
    #|  </metadata>
    #|  <manifest>
    #|    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
    #|  </manifest>
    #|  <spine toc="ncx">
    #|    <itemref idref="nav" linear="no"/>
    #|  </spine>
    #|</package>
  assert_eq(out, expected)
}

///|
test "render_package: unique-identifier 覆盖与 guide 开关" {
  let m = @model.Metadata::new("T", "en", "urn:uuid:1")
  m.set_identifier_id("uid")
  let book = @model.Book::new(m)
  let options = OpfOptions::new()
  options.set_include_guide(false)
  options.add_guide(GuideReference::new("text", "正文", "text/a.xhtml"))
  options.set_unique_identifier("other-id")
  let out = render_package(book, options)
  assert_true(out.contains("unique-identifier=\"other-id\""))
  assert_false(out.contains("<guide>"))
  assert_true(out.contains("<manifest>\n  </manifest>"))
  assert_true(out.contains("<spine>\n  </spine>"))
}

///|
test "render_metadata: 多创建者与贡献者编号" {
  let m = @model.Metadata::new("T", "en", "id")
  m.add_creator(@model.Contributor::new("C1"))
  m.add_creator(@model.Contributor::new("C2"))
  m.add_contributor(@model.Contributor::new("K1"))
  m.add_contributor(@model.Contributor::new("K2"))
  let out = render_metadata(m, 0)
  assert_true(out.contains("<dc:creator id=\"creator-1\">C1</dc:creator>"))
  assert_true(out.contains("<dc:creator id=\"creator-2\">C2</dc:creator>"))
  assert_true(
    out.contains("<dc:contributor id=\"contributor-1\">K1</dc:contributor>"),
  )
  assert_true(
    out.contains("<dc:contributor id=\"contributor-2\">K2</dc:contributor>"),
  )
}

///|
test "render_metadata: 多值字段顺序保持" {
  let m = @model.Metadata::new("T", "en", "id")
  m.add_publisher("P1")
  m.add_publisher("P2")
  m.add_date("2020")
  m.add_date("2021")
  m.add_subject("S1")
  m.add_subject("S2")
  m.add_description("D1")
  m.add_description("D2")
  let out = render_metadata(m, 0)
  let expected =
    #|<metadata>
    #|  <dc:identifier id="pub-id">id</dc:identifier>
    #|  <dc:title>T</dc:title>
    #|  <dc:language>en</dc:language>
    #|  <dc:publisher>P1</dc:publisher>
    #|  <dc:publisher>P2</dc:publisher>
    #|  <dc:date>2020</dc:date>
    #|  <dc:date>2021</dc:date>
    #|  <dc:subject>S1</dc:subject>
    #|  <dc:subject>S2</dc:subject>
    #|  <dc:description>D1</dc:description>
    #|  <dc:description>D2</dc:description>
    #|</metadata>
  assert_eq(out, expected)
}

///|
test "render_metadata: 标识符文本与 id 属性转义" {
  let m = @model.Metadata::new("T", "en", "urn:a&b<c>")
  m.set_identifier_id("id\"x")
  let out = render_metadata(m, 0)
  assert_true(
    out.contains(
      "<dc:identifier id=\"id&quot;x\">urn:a&amp;b&lt;c&gt;</dc:identifier>",
    ),
  )
}

///|
test "render_metadata: 自定义 meta 的属性与文本转义" {
  let m = @model.Metadata::new("T", "en", "id")
  m.add_meta(@model.Meta::named("a&b", "x<y"))
  m.add_meta(@model.Meta::of_property_content("dcterms:title-type", "A & B"))
  let out = render_metadata(m, 0)
  assert_true(out.contains("<meta name=\"a&amp;b\" content=\"x&lt;y\"/>"))
  assert_true(
    out.contains("<meta property=\"dcterms:title-type\">A &amp; B</meta>"),
  )
}

///|
test "render_manifest: 多条目顺序与 properties" {
  let manifest = @model.Manifest::new()
  let _ = manifest.add(
    @model.ManifestItem::new("a", "a.xhtml", "application/xhtml+xml"),
  )
  let b = @model.ManifestItem::new("b", "b.png", "image/png")
  b.add_property("cover-image")
  let _ = manifest.add(b)
  let out = render_manifest(manifest, 0)
  let expected =
    #|<manifest>
    #|  <item id="a" href="a.xhtml" media-type="application/xhtml+xml"/>
    #|  <item id="b" href="b.png" media-type="image/png" properties="cover-image"/>
    #|</manifest>
  assert_eq(out, expected)
}

///|
test "render_manifest: href 属性转义" {
  let manifest = @model.Manifest::new()
  let item = @model.ManifestItem::new("i", "a&b\".xhtml", "text/html")
  item.add_property("nav")
  let _ = manifest.add(item)
  let out = render_manifest(manifest, 0)
  assert_true(out.contains("href=\"a&amp;b&quot;.xhtml\""))
}

///|
test "render_manifest: 空清单边界" {
  assert_eq(
    render_manifest(@model.Manifest::new(), 0),
    "<manifest>\n</manifest>",
  )
}

///|
test "render_spine: itemref idref/toc 转义与空 spine" {
  let spine = @model.Spine::new()
  spine.add(@model.SpineItem::new("a\"b"))
  spine.add(@model.SpineItem::non_linear("n"))
  spine.set_toc("t&c")
  let out = render_spine(spine, 0)
  assert_true(out.contains("<spine toc=\"t&amp;c\">"))
  assert_true(out.contains("<itemref idref=\"a&quot;b\"/>"))
  assert_true(out.contains("<itemref idref=\"n\" linear=\"no\"/>"))
  let empty = @model.Spine::new()
  empty.set_toc("ncx")
  assert_eq(render_spine(empty, 0), "<spine toc=\"ncx\">\n</spine>")
}

///|
test "render_metadata: 空字段边界" {
  let m = @model.Metadata::new("", "", "")
  let out = render_metadata(m, 0)
  assert_true(out.contains("<dc:title></dc:title>"))
  assert_true(out.contains("<dc:language></dc:language>"))
  assert_true(out.contains("<dc:identifier id=\"pub-id\"></dc:identifier>"))
}

///|
test "render_guide: 空指南与标题转义" {
  assert_eq(render_guide([], 0), "<guide>\n</guide>")
  let out = render_guide([GuideReference::new("cover", "A & B", "c.xhtml")], 0)
  assert_true(out.contains("title=\"A &amp; B\""))
}

///|
test "render_package_from: 直接装配与语言空省略 xml:lang" {
  let m = @model.Metadata::new("T", "", "urn:uuid:9")
  let out = render_package_from(
    m,
    @model.Manifest::new(),
    @model.Spine::new(),
    OpfOptions::new(),
  )
  assert_false(out.contains("xml:lang="))
  assert_true(out.contains("unique-identifier=\"pub-id\""))
  assert_true(
    out.contains("prefix=\"marc: http://id.loc.gov/vocabulary/relators/\""),
  )
}

///|
test "render_package: version 覆盖与 guide 输出" {
  let m = @model.Metadata::new("T", "en", "urn:uuid:1")
  let book = @model.Book::new(m)
  let options = OpfOptions::new()
  options.set_version("2.0")
  options.add_guide(GuideReference::new("text", "A & B", "text/a.xhtml"))
  let out = render_package(book, options)
  assert_true(out.contains("version=\"2.0\""))
  assert_true(out.contains("<guide>"))
  assert_true(out.contains("title=\"A &amp; B\""))
}
