///|
/// OCF 打包装配的白盒测试：验证端到端打包会继承书籍已有的
/// manifest 定制与自定义阅读顺序。

///|
test "build_manifest: 继承既有条目的 properties/fallback/media-overlay" {
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
  let manifest = build_manifest(book, PackageOptions::new())
  let nav_item = manifest.find_by_id("nav").unwrap()
  assert_true(nav_item.has_property(@spec.epub_property_nav))
  assert_true(nav_item.has_property("scripted"))
  let merged = manifest.find_by_id("ch1").unwrap()
  assert_eq(merged.fallback, Some("fallback"))
  assert_eq(merged.media_overlay, Some("mo"))
}

///|
test "build_spine: 沿用自定义顺序、线性与翻页方向" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:test"))
  book.add_chapter(@model.Chapter::new("ch1", "第一章"))
  book.add_chapter(@model.Chapter::new("ch2", "第二章"))
  book.add_spine_item(@model.SpineItem::non_linear("ch1"))
  book.add_spine_item(@model.SpineItem::new("ch2"))
  book.spine.set_toc("ncx")
  book.spine.set_page_progression_direction("rtl")
  let spine = build_spine(book)
  assert_eq(spine.items.length(), 2)
  assert_eq(spine.items[0].idref, "ch1")
  assert_false(spine.items[0].linear)
  assert_eq(spine.items[1].idref, "ch2")
  assert_true(spine.items[1].linear)
  assert_eq(spine.toc, Some("ncx"))
  assert_eq(spine.page_progression_direction, Some("rtl"))
}

///|
test "build_spine: 空 spine 按章节树深度优先生成" {
  let book = @model.Book::new(@model.Metadata::new("T", "en", "urn:uuid:test"))
  let ch1 = @model.Chapter::new("ch1", "第一章")
  ch1.add_child(@model.Chapter::new("ch1-1", "第一节"))
  book.add_chapter(ch1)
  book.add_chapter(@model.Chapter::new("ch2", "第二章"))
  let spine = build_spine(book)
  assert_eq(spine.items.length(), 3)
  assert_eq(spine.items[0].idref, "ch1")
  assert_eq(spine.items[1].idref, "ch1-1")
  assert_eq(spine.items[2].idref, "ch2")
  assert_eq(spine.toc, Some(@spec.manifest_id_ncx))
}
