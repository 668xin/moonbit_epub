///|
/// S1 领域模型的单元测试：内容模型、元数据、清单/阅读顺序与章节树。

///|
test "plain_text: 递归提取嵌套内联文本" {
  let inlines : Array[Inline] = [
    Inline::text("a"),
    Inline::emphasis([Inline::text("b"), Inline::code("c")]),
    Inline::strong([Inline::text("d")]),
    Inline::link("x.xhtml", [Inline::text("e")]),
    Inline::footnote_ref("n1"),
  ]
  assert_eq(plain_text(inlines), "abcde")
  assert_eq(plain_text([]), "")
}

///|
test "Block: 段落 / 标题 / 代码块 构造" {
  let p = Block::paragraph("hi")
  match p {
    Paragraph(inlines) => assert_eq(plain_text(inlines), "hi")
    _ => panic()
  }
  let h = Block::heading(2, "Title")
  match h {
    Heading(level~, children~) => {
      assert_eq(level, 2)
      assert_eq(plain_text(children), "Title")
    }
    _ => panic()
  }
  let cb = Block::code_block("moonbit", "let x = 1")
  match cb {
    CodeBlock(language~, code~) => {
      assert_eq(language, "moonbit")
      assert_eq(code, "let x = 1")
    }
    _ => panic()
  }
}

///|
test "Block: 列表 / 表格 / 图片 / 引用 / 脚注 构造" {
  let list = Block::list(true, [[Block::paragraph("一")]])
  match list {
    List(ordered~, items~) => {
      assert_true(ordered)
      assert_eq(items.length(), 1)
    }
    _ => panic()
  }
  let table = Block::table([[Inline::text("h")]], [[[Inline::text("c")]]])
  match table {
    Table(header~, rows~) => {
      assert_eq(header.length(), 1)
      assert_eq(rows.length(), 1)
    }
    _ => panic()
  }
  let image = Block::image("images/a.png", "alt")
  match image {
    Image(src~, alt~) => {
      assert_eq(src, "images/a.png")
      assert_eq(alt, "alt")
    }
    _ => panic()
  }
  let note = Block::note("n1", [Block::paragraph("注")])
  match note {
    Note(id~, blocks~) => {
      assert_eq(id, "n1")
      assert_eq(blocks.length(), 1)
    }
    _ => panic()
  }
  assert_true(Block::horizontal_rule() is HorizontalRule)
  assert_true(Block::blockquote([Block::paragraph("q")]) is Blockquote(_))
}

///|
test "Metadata: 默认值、完整性与 setter" {
  let m = Metadata::new("书名", "zh-CN", "urn:uuid:abc")
  assert_eq(m.identifier_id, "pub-id")
  assert_true(m.is_complete())
  assert_eq(m.creator_names().length(), 0)
  m.set_title("")
  assert_false(m.is_complete())
  m.set_title("再命名")
  m.set_language("zh-TW")
  m.set_identifier("urn:uuid:new")
  m.set_identifier_id("uid")
  m.set_rights("(c) 2026")
  m.set_modified("2026-10-09T00:00:00Z")
  assert_eq(m.title, "再命名")
  assert_eq(m.language, "zh-TW")
  assert_eq(m.identifier, "urn:uuid:new")
  assert_eq(m.identifier_id, "uid")
  assert_eq(m.rights, Some("(c) 2026"))
  assert_eq(m.modified, Some("2026-10-09T00:00:00Z"))
}

///|
test "Metadata: 贡献者、扩展元数据与丛书" {
  let m = Metadata::new("T", "en", "id")
  m.add_creator(Contributor::new("Jane Doe", role="aut"))
  m.add_creator(Contributor::new("John Roe"))
  m.add_contributor(Contributor::new("Ed", role="edt", file_as="Ed, E."))
  m.add_publisher("Pub")
  m.add_subject("Fiction")
  m.add_date("2026")
  m.add_description("Desc")
  m.add_meta(Meta::named("calibre:series", "X"))
  m.add_meta(Meta::of_property("dcterms:modified"))
  m.add_meta(Meta::refining("title-type", "pub-title"))
  m.add_series(Series::new("系列", index=2))
  assert_eq(m.creator_names(), ["Jane Doe", "John Roe"])
  assert_eq(m.contributors.length(), 1)
  assert_eq(m.contributors[0].role, Some("edt"))
  assert_eq(m.contributors[0].file_as, Some("Ed, E."))
  assert_eq(m.publishers, ["Pub"])
  assert_eq(m.subjects, ["Fiction"])
  assert_eq(m.dates, ["2026"])
  assert_eq(m.descriptions, ["Desc"])
  assert_eq(m.metas.length(), 3)
  assert_eq(m.metas[0].name, Some("calibre:series"))
  assert_eq(m.metas[0].content, Some("X"))
  assert_eq(m.metas[1].property, Some("dcterms:modified"))
  assert_eq(m.metas[2].refines, Some("pub-title"))
  assert_eq(m.series.length(), 1)
  assert_eq(m.series[0].name, "系列")
  assert_eq(m.series[0].index, Some(2))
}

///|
test "ManifestItem: properties 声明与查询" {
  let item = ManifestItem::new("nav", "nav.xhtml", "application/xhtml+xml")
  assert_false(item.has_property("cover-image"))
  item.add_property("cover-image")
  assert_true(item.has_property("cover-image"))
  assert_false(item.has_property("scripted"))
  assert_eq(item.properties, ["cover-image"])
}

///|
test "Manifest: ID 唯一性约束与查找" {
  let manifest = Manifest::new()
  assert_eq(manifest.length(), 0)
  assert_true(
    manifest.add(ManifestItem::new("i1", "a.xhtml", "application/xhtml+xml")),
  )
  assert_false(
    manifest.add(ManifestItem::new("i1", "b.xhtml", "application/xhtml+xml")),
  )
  assert_eq(manifest.length(), 1)
  assert_true(manifest.has_id("i1"))
  assert_false(manifest.has_id("i2"))
  assert_eq(manifest.find_by_id("i1").unwrap().href, "a.xhtml")
  assert_true(manifest.find_by_id("i2") is None)
  assert_true(manifest.has_href("a.xhtml"))
  assert_false(manifest.has_href("b.xhtml"))
}

///|
test "Spine: 阅读顺序与非线性条目" {
  let spine = Spine::new()
  spine.add(SpineItem::new("i1"))
  spine.add(SpineItem::non_linear("i2"))
  assert_eq(spine.idrefs(), ["i1", "i2"])
  assert_true(spine.contains("i2"))
  assert_false(spine.contains("i3"))
  assert_true(spine.items[0].linear)
  assert_false(spine.items[1].linear)
  spine.set_toc("ncx")
  assert_eq(spine.toc, Some("ncx"))
}

///|
test "Chapter: 遍历、展平、查找与统计" {
  let grand = Chapter::new("g1", "Grand")
  let child_a = Chapter::new("a", "A")
  child_a.add_child(grand)
  let child_b = Chapter::new("b", "B")
  let root = Chapter::new("root", "Root")
  root.add_child(child_a)
  root.add_child(child_b)
  let forest : Array[Chapter] = [root]
  assert_eq(count_chapters(forest), 4)
  assert_eq(chapter_depth(forest), 3)
  assert_eq(chapter_depth([]), 0)
  assert_eq(flatten_chapters(forest)[2].id, "g1")
  let visited : Array[String] = []
  walk_chapters(forest, fn(depth, chapter) {
    visited.push("\{depth}:\{chapter.title}")
  })
  assert_eq(visited, ["0:Root", "1:A", "2:Grand", "1:B"])
  assert_true(find_chapter(forest, "g1") is Some(_))
  assert_true(find_chapter(forest, "absent") is None)
  assert_eq(chapter_href(root), "text/root.xhtml")
}

///|
test "Resource: 文本 / CSS 与 UTF-8 编码" {
  let css = Resource::css("styles/style.css", "body { color: red }")
  assert_eq(css.media_type, "text/css")
  assert_eq(css.href, "styles/style.css")
  assert_eq(resource_id(css), "styles-style.css")
  let zh = Resource::text("text/a.xhtml", "application/xhtml+xml", "中文")
  assert_eq(zh.data.length(), 6)
}

///|
test "Book: 聚合、阅读顺序与章节 ID 唯一性" {
  let book = Book::new(Metadata::new("T", "zh-CN", "urn:uuid:1"))
  book.add_chapter(Chapter::new("c1", "一"))
  book.add_chapter(Chapter::new("c2", "二"))
  assert_eq(book.chapter_count(), 2)
  assert_true(book.has_unique_chapter_ids())
  assert_true(
    book.add_manifest_item(
      ManifestItem::new("i1", "text/c1.xhtml", "application/xhtml+xml"),
    ),
  )
  assert_false(
    book.add_manifest_item(
      ManifestItem::new("i1", "text/c2.xhtml", "application/xhtml+xml"),
    ),
  )
  assert_eq(book.manifest.length(), 1)
  book.add_spine_item(SpineItem::new("i1"))
  book.add_spine_item(SpineItem::non_linear("i2"))
  assert_eq(book.spine.idrefs(), ["i1", "i2"])
  assert_true(book.find_chapter("c1") is Some(_))
  assert_eq(book.find_chapter("c1").unwrap().title, "一")
  book.add_resource(Resource::css("styles/a.css", "x"))
  assert_eq(book.resources.length(), 1)
  book.add_chapter(Chapter::new("c1", "重复"))
  assert_false(book.has_unique_chapter_ids())
}

///|
test "Meta: 四种构造形态的字段" {
  let named = Meta::named("calibre:series", "X")
  assert_eq(named.name, Some("calibre:series"))
  assert_eq(named.content, Some("X"))
  assert_eq(named.property, None)
  assert_eq(named.refines, None)
  assert_eq(named.id, None)
  let prop = Meta::of_property("dcterms:modified")
  assert_eq(prop.property, Some("dcterms:modified"))
  assert_eq(prop.name, None)
  assert_eq(prop.content, None)
  let refining_meta = Meta::refining("title-type", "pub-title")
  assert_eq(refining_meta.property, Some("title-type"))
  assert_eq(refining_meta.refines, Some("pub-title"))
  let pc = Meta::of_property_content("schema:accessMode", "textual")
  assert_eq(pc.property, Some("schema:accessMode"))
  assert_eq(pc.content, Some("textual"))
  assert_eq(pc.refines, None)
  assert_eq(Meta::of_property("a"), Meta::of_property("a"))
  assert_true(Meta::of_property("a") != Meta::of_property("b"))
}

///|
test "Contributor / Series: 可选字段与相等性" {
  let a = Contributor::new("Jane", role="aut", file_as="Doe, J.")
  assert_eq(a.name, "Jane")
  assert_eq(a.role, Some("aut"))
  assert_eq(a.file_as, Some("Doe, J."))
  let b = Contributor::new("Anon")
  assert_eq(b.role, None)
  assert_eq(b.file_as, None)
  assert_eq(
    Contributor::new("x", role="ill"),
    Contributor::new("x", role="ill"),
  )
  assert_eq(Series::new("S1", index=3).index, Some(3))
  assert_eq(Series::new("S2").index, None)
  assert_eq(Series::new("S3"), Series::new("S3"))
}

///|
test "Metadata: is_complete 各必需字段为空的分支" {
  assert_false(Metadata::new("", "zh", "id").is_complete())
  assert_false(Metadata::new("t", "", "id").is_complete())
  assert_false(Metadata::new("t", "zh", "").is_complete())
  let ok = Metadata::new("t", "zh", "id")
  assert_true(ok.is_complete())
  // 默认可选字段与承载标识符的元素 id。
  assert_eq(ok.identifier_id, "pub-id")
  assert_eq(ok.rights, None)
  assert_eq(ok.modified, None)
  assert_eq(ok.creator_names(), [])
}

///|
test "Metadata: creator_names 顺序与空" {
  let m = Metadata::new("t", "en", "id")
  assert_eq(m.creator_names(), [])
  m.add_creator(Contributor::new("A"))
  m.add_creator(Contributor::new("B"))
  m.add_creator(Contributor::new("C"))
  assert_eq(m.creator_names(), ["A", "B", "C"])
}

///|
test "ManifestItem: fallback / media_overlay 默认与设置" {
  let item = ManifestItem::new("i", "a.xhtml", @spec.mt_xhtml)
  assert_eq(item.fallback, None)
  assert_eq(item.media_overlay, None)
  assert_eq(item.properties.length(), 0)
  assert_false(item.has_property("nav"))
  item.set_fallback("alt")
  item.set_media_overlay("smil1")
  assert_eq(item.fallback, Some("alt"))
  assert_eq(item.media_overlay, Some("smil1"))
  item.add_property("nav")
  item.add_property("scripted")
  assert_eq(item.properties, ["nav", "scripted"])
  assert_true(item.has_property("scripted"))
}

///|
test "Manifest: 多条目索引、未命中与重复拒绝" {
  let manifest = Manifest::new()
  assert_true(manifest.add(ManifestItem::new("i1", "a.xhtml", @spec.mt_xhtml)))
  assert_true(manifest.add(ManifestItem::new("i2", "b.xhtml", @spec.mt_xhtml)))
  assert_true(manifest.add(ManifestItem::new("i3", "c.xhtml", @spec.mt_xhtml)))
  assert_eq(manifest.length(), 3)
  assert_eq(manifest.find_by_id("i2").unwrap().href, "b.xhtml")
  assert_true(manifest.find_by_id("i9") is None)
  assert_eq(manifest.find_by_href("c.xhtml").unwrap().id, "i3")
  assert_true(manifest.find_by_href("z.xhtml") is None)
  assert_true(manifest.has_href("a.xhtml"))
  assert_false(manifest.has_href("z.xhtml"))
  assert_false(
    manifest.add(ManifestItem::new("i1", "dup.xhtml", @spec.mt_xhtml)),
  )
  assert_eq(manifest.length(), 3)
}

///|
test "SpineItem: 线性默认与非线性构造" {
  let lin = SpineItem::new("i1")
  assert_true(lin.linear)
  assert_eq(lin.idref, "i1")
  assert_eq(lin.properties.length(), 0)
  let non = SpineItem::non_linear("i2")
  assert_false(non.linear)
  assert_eq(non.idref, "i2")
}

///|
test "Spine: 空、idrefs 顺序与 toc 默认" {
  let spine = Spine::new()
  assert_eq(spine.idrefs(), [])
  assert_false(spine.contains("x"))
  assert_eq(spine.toc, None)
  assert_eq(spine.items.length(), 0)
  spine.add(SpineItem::new("a"))
  spine.add(SpineItem::new("b"))
  assert_eq(spine.idrefs(), ["a", "b"])
  assert_true(spine.contains("b"))
  spine.set_toc("ncx")
  assert_eq(spine.toc, Some("ncx"))
}

///|
test "Chapter: 空森林与单节点边界" {
  assert_eq(count_chapters([]), 0)
  assert_eq(chapter_depth([]), 0)
  assert_eq(flatten_chapters([]).length(), 0)
  assert_true(find_chapter([], "x") is None)
  let solo = Chapter::new("solo", "Solo")
  assert_eq(count_chapters([solo]), 1)
  assert_eq(chapter_depth([solo]), 1)
  assert_eq(solo.children.length(), 0)
  assert_eq(solo.body.length(), 0)
  assert_eq(solo.title, "Solo")
}

///|
test "walk_chapters: 多层深度优先且空森林不触发" {
  let grand = Chapter::new("g1", "G")
  let child = Chapter::new("c1", "C")
  child.add_child(grand)
  let root1 = Chapter::new("r1", "R1")
  root1.add_child(child)
  let root2 = Chapter::new("r2", "R2")
  let visited : Array[String] = []
  walk_chapters([root1, root2], fn(depth, chapter) {
    visited.push("\{depth}:\{chapter.id}")
  })
  assert_eq(visited, ["0:r1", "1:c1", "2:g1", "0:r2"])
  let empty_visited : Array[String] = []
  walk_chapters([], fn(_, _) { empty_visited.push("x") })
  assert_eq(empty_visited.length(), 0)
}

///|
test "flatten_chapters: 空与深度优先展平顺序" {
  let ga = Chapter::new("ga", "GA")
  let a = Chapter::new("a", "A")
  a.add_child(ga)
  let b = Chapter::new("b", "B")
  let r = Chapter::new("r", "R")
  r.add_child(a)
  r.add_child(b)
  let flat = flatten_chapters([r])
  let ids : Array[String] = []
  for chapter in flat {
    ids.push(chapter.id)
  }
  assert_eq(ids, ["r", "a", "ga", "b"])
  assert_eq(flat.length(), 4)
}

///|
test "find_chapter: 各层级命中与未命中" {
  let grand = Chapter::new("g1", "Grand")
  let child = Chapter::new("c1", "Child")
  child.add_child(grand)
  let root = Chapter::new("root", "Root")
  root.add_child(child)
  let forest : Array[Chapter] = [root]
  assert_eq(find_chapter(forest, "root").unwrap().title, "Root")
  assert_eq(find_chapter(forest, "c1").unwrap().title, "Child")
  assert_eq(find_chapter(forest, "g1").unwrap().title, "Grand")
  assert_true(find_chapter(forest, "absent") is None)
}

///|
test "Chapter: chapter_href 与 with_body 构造" {
  let empty = Chapter::new("ch_1", "T")
  assert_eq(chapter_href(empty), "text/ch_1.xhtml")
  let body = Chapter::with_body("ch_2", "T2", [Block::paragraph("x")])
  assert_eq(body.body.length(), 1)
  assert_eq(body.children.length(), 0)
  assert_eq(chapter_href(body), "text/ch_2.xhtml")
}

///|
test "Resource: 原始字节 / 文本与 resource_id 规范化" {
  let png = Resource::text("images/cover.png", @spec.mt_png, "ab")
  assert_eq(png.media_type, "image/png")
  assert_eq(png.data.length(), 2)
  assert_eq(png.properties.length(), 0)
  assert_eq(resource_id(png), "images-cover.png")
  let empty = Resource::new("a.bin", @spec.mt_octet_stream, Bytes::new(0))
  assert_eq(empty.data.length(), 0)
  assert_eq(resource_id(empty), "a.bin")
}

///|
test "Book: 空书籍边界" {
  let book = Book::new(Metadata::new("T", "zh", "id"))
  assert_eq(book.chapter_count(), 0)
  assert_true(book.has_unique_chapter_ids())
  assert_true(book.find_chapter("x") is None)
  assert_eq(book.manifest.length(), 0)
  assert_eq(book.spine.idrefs(), [])
  assert_eq(book.resources.length(), 0)
  assert_eq(book.chapters.length(), 0)
}

///|
test "Book: 跨层级重复章节 ID 破坏唯一性" {
  let book = Book::new(Metadata::new("T", "zh", "id"))
  let root = Chapter::new("dup", "R")
  root.add_child(Chapter::new("dup", "C"))
  book.add_chapter(root)
  assert_eq(book.chapter_count(), 2)
  assert_false(book.has_unique_chapter_ids())
}

///|
test "Book: 元数据透传与清单 / 阅读顺序聚合" {
  let book = Book::new(Metadata::new("标题", "zh-CN", "urn:uuid:z"))
  assert_eq(book.metadata.title, "标题")
  assert_eq(book.metadata.language, "zh-CN")
  assert_true(
    book.add_manifest_item(ManifestItem::new("i1", "a.xhtml", @spec.mt_xhtml)),
  )
  assert_false(
    book.add_manifest_item(ManifestItem::new("i1", "b.xhtml", @spec.mt_xhtml)),
  )
  assert_eq(book.manifest.length(), 1)
  book.add_spine_item(SpineItem::new("i1"))
  book.add_spine_item(SpineItem::non_linear("i2"))
  assert_eq(book.spine.idrefs(), ["i1", "i2"])
  assert_true(book.spine.contains("i1"))
  book.spine.set_toc("ncx")
  assert_eq(book.spine.toc, Some("ncx"))
}
