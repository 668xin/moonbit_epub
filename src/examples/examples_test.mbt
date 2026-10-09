///|
/// S8 示例书籍的单元测试。

///|
test "minimal: 结构" {
  let book = minimal()
  assert_eq(book.chapter_count(), 1)
  assert_eq(book.spine.items.length(), 1)
  assert_eq(book.resources.length(), 0)
  // 导航 + NCX + 单章节
  assert_eq(book.manifest.length(), 3)
  assert_eq(book.metadata.title, "最小示例")
}

///|
test "multi_chapter: 嵌套章节与资源" {
  let book = multi_chapter()
  // 三章 + 一个嵌套小节
  assert_eq(book.chapter_count(), 4)
  assert_eq(book.spine.items.length(), 4)
  assert_eq(book.resources.length(), 1)
  // 导航 + NCX + 四章节 + 一样式表
  assert_eq(book.manifest.length(), 7)
}

///|
test "styled: 自定义样式与图片资源" {
  let book = styled()
  assert_eq(book.chapter_count(), 1)
  assert_eq(book.resources.length(), 2)
  assert_eq(book.manifest.length(), 2 + 1 + 2)
}

///|
test "by_name: 名称索引" {
  assert_true(by_name("minimal") is Some(_))
  assert_true(by_name("multi") is Some(_))
  assert_true(by_name("styled") is Some(_))
  assert_true(by_name("missing") is None)
}

///|
test "names: 示例清单" {
  let names = names()
  assert_eq(names.length(), 3)
  assert_eq(names[0], "minimal")
}

///|
/// 清单中是否登记了导航文档条目。
fn manifest_has_nav(book : @model.Book) -> Bool {
  let mut found = false
  for item in book.manifest.items {
    if item.has_property(@spec.epub_property_nav) {
      found = true
    }
  }
  found
}

///|
/// 全部章节（含子章节）是否均已登记于清单与阅读顺序。
fn chapters_registered(book : @model.Book) -> Bool {
  let mut ok = true
  for chapter in @model.flatten_chapters(book.chapters) {
    if !book.manifest.has_href(@model.chapter_href(chapter)) {
      ok = false
    }
    if !book.spine.contains(chapter.id) {
      ok = false
    }
  }
  ok
}

///|
/// 全部资源是否均已登记于清单。
fn resources_registered(book : @model.Book) -> Bool {
  let mut ok = true
  for resource in book.resources {
    if !book.manifest.has_href(resource.href) {
      ok = false
    }
  }
  ok
}

///|
/// 取示例书籍标题，`None` 视为空串。
fn title_of(book : @model.Book?) -> String {
  match book {
    Some(b) => b.metadata.title
    None => ""
  }
}

///|
test "names: 顺序与内容" {
  let names = names()
  assert_eq(names[0], "minimal")
  assert_eq(names[1], "multi-chapter")
  assert_eq(names[2], "styled")
}

///|
test "by_name: multi 别名等价于 multi-chapter" {
  assert_eq(title_of(by_name("multi")), title_of(by_name("multi-chapter")))
  assert_eq(title_of(by_name("multi")), "多章节示例")
  assert_eq(title_of(by_name("missing")), "")
}

///|
test "minimal: 结构一致性不变量" {
  let book = minimal()
  assert_true(manifest_has_nav(book))
  assert_true(chapters_registered(book))
  assert_true(resources_registered(book))
  assert_true(book.manifest.has_id(@spec.manifest_id_nav))
  assert_eq(book.spine.toc, Some(@spec.manifest_id_ncx))
}

///|
test "multi_chapter: 全部章节登记于清单与阅读顺序" {
  let book = multi_chapter()
  assert_true(manifest_has_nav(book))
  assert_true(chapters_registered(book))
  assert_true(resources_registered(book))
  assert_true(book.manifest.find_by_id("ch2-1") is Some(_))
}

///|
test "styled: 资源登记与封面图片" {
  let book = styled()
  assert_eq(book.resources.length(), 2)
  assert_true(resources_registered(book))
  assert_true(chapters_registered(book))
  match book.manifest.find_by_href("images/cover.png") {
    Some(item) => assert_eq(item.media_type, @spec.mt_png)
    None => assert_true(false)
  }
}

///|
test "minimal: 含可访问性元数据" {
  let book = minimal()
  let mut found_mode = false
  for meta in book.metadata.metas {
    if meta.property == Some(@spec.prop_access_mode) {
      found_mode = true
    }
  }
  assert_true(found_mode)
  assert_eq(book.metadata.language, "zh-CN")
}
