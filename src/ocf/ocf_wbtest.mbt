///|
/// OCF 打包装配的白盒测试：验证端到端打包会继承书籍已有的
/// manifest 定制与自定义阅读顺序。

///|
test "assemble_book: 继承既有条目的 properties/fallback/media-overlay" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:test"))
  book.add_chapter(@model.Chapter::new("ch1", "第一章"))
  book.add_resource(@model.Resource::css("styles/a.css", "body {}"))
  let nav = @model.ManifestItem::new("nav", "nav.xhtml", @spec.mt_xhtml)
  nav.add_property(@spec.epub_property_nav)
  nav.add_property("scripted")
  let _ = book.add_manifest_item(nav)
  let chapter_item = @model.ManifestItem::new(
    "ch1", "text/ch1.xhtml", @spec.mt_xhtml,
  )
  chapter_item.set_fallback("fallback")
  chapter_item.set_media_overlay("mo")
  let _ = book.add_manifest_item(chapter_item)
  let manifest = @model.assemble_book(book).manifest
  let nav_item = manifest.find_by_id("nav").unwrap()
  assert_true(nav_item.has_property(@spec.epub_property_nav))
  assert_true(nav_item.has_property("scripted"))
  let merged = manifest.find_by_id("ch1").unwrap()
  assert_eq(merged.fallback, Some("fallback"))
  assert_eq(merged.media_overlay, Some("mo"))
}

///|
test "assemble_book: 沿用自定义顺序、线性与翻页方向" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:test"))
  book.add_chapter(@model.Chapter::new("ch1", "第一章"))
  book.add_chapter(@model.Chapter::new("ch2", "第二章"))
  book.add_spine_item(@model.SpineItem::non_linear("ch1"))
  book.add_spine_item(@model.SpineItem::new("ch2"))
  book.spine.set_toc("ncx")
  book.spine.set_page_progression_direction("rtl")
  let spine = @model.assemble_book(book).spine
  assert_eq(spine.items.length(), 2)
  assert_eq(spine.items[0].idref, "ch1")
  assert_false(spine.items[0].linear)
  assert_eq(spine.items[1].idref, "ch2")
  assert_true(spine.items[1].linear)
  assert_eq(spine.toc, Some("ncx"))
  assert_eq(spine.page_progression_direction, Some("rtl"))
}

///|
test "assemble_book: 空 spine 按章节树深度优先生成" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:test"))
  let ch1 = @model.Chapter::new("ch1", "第一章")
  ch1.add_child(@model.Chapter::new("ch1-1", "第一节"))
  book.add_chapter(ch1)
  book.add_chapter(@model.Chapter::new("ch2", "第二章"))
  let spine = @model.assemble_book(book).spine
  assert_eq(spine.items.length(), 3)
  assert_eq(spine.items[0].idref, "ch1")
  assert_eq(spine.items[1].idref, "ch1-1")
  assert_eq(spine.items[2].idref, "ch2")
  assert_eq(spine.toc, Some(@spec.manifest_id_ncx))
}

///|
test "assemble_book: 缺省 modified 注入生成的 OPF" {
  let book = @model.Book::new(
    @model.Metadata::new("T", "en", "urn:uuid:no-mod"),
  )
  book.add_chapter(@model.Chapter::new("ch1", "C"))
  let assembled = @model.assemble_book(book)
  let opf = @opf.render_package_from(
    assembled.metadata,
    assembled.manifest,
    assembled.spine,
    @opf.OpfOptions::new(),
  )
  assert_true(
    opf.contains(
      "<meta property=\"dcterms:modified\">" +
      @spec.default_modified +
      "</meta>",
    ),
  )
}

///|
test "metadata_for: language 覆盖并进入 OPF/nav/NCX" {
  let book = @model.Book::new(
    @model.Metadata::new("T", "zh-CN", "urn:uuid:lang"),
  )
  book.add_chapter(@model.Chapter::new("ch1", "C"))
  let options = PackageOptions::new()
  options.set_language("en")
  let documents = render_documents(book, options)
  assert_eq(documents.book.metadata.language, "en")
  assert_true(documents.opf.contains("xml:lang=\"en\""))
  assert_true(documents.opf.contains("<dc:language>en</dc:language>"))
  assert_true(documents.nav.contains("xml:lang=\"en\""))
  assert_true(documents.ncx.contains("xml:lang=\"en\""))
}

///|
test "media overlay: 清单条目与 media-overlay 关联" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:mo"))
  book.add_chapter(@model.Chapter::new("ch1", "C"))
  let assembled = @model.assemble_book(book)
  apply_media_overlays(assembled.manifest, [
    MediaOverlayFile::new("text/ch1.smil", "text/ch1.xhtml", "<smil/>"),
  ])
  let chapter = assembled.manifest.find_by_href("text/ch1.xhtml").unwrap()
  assert_eq(chapter.media_overlay, Some("mo-text-ch1.smil"))
  let smil = assembled.manifest.find_by_id("mo-text-ch1.smil").unwrap()
  assert_eq(smil.media_type, @spec.mt_smil)
  assert_eq(smil.href, "text/ch1.smil")
}

///|
test "media duration: 生成全局与细化 media:duration 元数据" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:mo2"))
  book.add_chapter(@model.Chapter::new("ch1", "C"))
  let options = PackageOptions::new()
  options.add_media_overlay(
    "text/ch1.smil",
    "text/ch1.xhtml",
    "<smil/>",
    duration_ms=1200,
  )
  let documents = render_documents(book, options)
  assert_true(
    documents.opf.contains(
      "<meta property=\"media:duration\">0:00:01.200</meta>",
    ),
  )
  assert_true(
    documents.opf.contains(
      "refines=\"#mo-text-ch1.smil\" property=\"media:duration\"",
    ),
  )
  assert_true(documents.opf.contains(">0:00:01.200</meta>"))
}

///|
test "render_documents: 资源 properties 进入 OPF" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:props"))
  book.add_chapter(@model.Chapter::new("ch1", "C"))
  let resource = @model.Resource::new("images/cover.png", @spec.mt_png, b"x")
  resource.properties.push("cover-image")
  book.add_resource(resource)
  let documents = render_documents(book, PackageOptions::new())
  let item = documents.book.manifest.find_by_href("images/cover.png").unwrap()
  assert_true(item.has_property("cover-image"))
  assert_true(documents.opf.contains("properties=\"cover-image\""))
}
