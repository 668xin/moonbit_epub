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
