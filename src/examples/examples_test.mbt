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
