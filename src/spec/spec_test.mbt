///|
/// S0 基础工具与规范常量的单元测试。

///|
test "xml_escape: 文本模式只转义 &<>" {
  assert_eq(xml_escape("a < b & c > d"), "a &lt; b &amp; c &gt; d")
  assert_eq(xml_escape("\"quoted\""), "\"quoted\"")
}

///|
test "xml_escape_attr: 属性模式转义引号与控制字符" {
  assert_eq(xml_escape_attr("\"a\"&'b'"), "&quot;a&quot;&amp;&#39;b&#39;")
  assert_eq(xml_escape_attr("line\nbreak"), "line&#10;break")
}

///|
test "utf8_len: 与 UTF-8 字节数一致" {
  assert_eq(utf8_len("abc"), 3)
  assert_eq(utf8_len("é"), 2)
  assert_eq(utf8_len("中"), 3)
  assert_eq(utf8_len("😀"), 4)
  assert_eq(utf8_len(""), 0)
}

///|
test "normalize_id: 非法字符折叠、首字符与空串处理" {
  assert_eq(normalize_id("Hello World!"), "Hello-World")
  assert_eq(normalize_id("123"), "_123")
  assert_eq(normalize_id(""), "id")
  assert_eq(normalize_id("---"), "id")
  assert_eq(normalize_id("a  b"), "a-b")
  assert_eq(normalize_id("chapter_1"), "chapter_1")
}

///|
test "normalize_id: 幂等且结果合法" {
  for input in ["Hello World!", "123", "", "a/b c", "中文 标题"] {
    let once = normalize_id(input)
    assert_eq(normalize_id(once), once)
    assert_true(is_valid_id(once))
  }
}

///|
test "is_valid_id: 拒绝非法首字符与空串" {
  assert_true(is_valid_id("abc"))
  assert_true(is_valid_id("_x-1.2"))
  assert_false(is_valid_id(""))
  assert_false(is_valid_id("1abc"))
  assert_false(is_valid_id("a b"))
}

///|
test "path_join: 不产生重复或缺失的分隔符" {
  assert_eq(path_join("a", "b"), "a/b")
  assert_eq(path_join("a/", "b"), "a/b")
  assert_eq(path_join("", "b"), "b")
  assert_eq(path_join("a", ""), "a")
}

///|
test "normalize_path: 解析 . 与 .." {
  assert_eq(normalize_path("a/./b/../c"), "a/c")
  assert_eq(normalize_path("/a//b/"), "/a/b")
  assert_eq(normalize_path("../a"), "../a")
  assert_eq(normalize_path("a/.."), ".")
  assert_eq(normalize_path("/.."), "/")
}

///|
test "path_dirname / path_basename" {
  assert_eq(path_dirname("a/b/c.xhtml"), "a/b")
  assert_eq(path_basename("a/b/c.xhtml"), "c.xhtml")
  assert_eq(path_dirname("c.xhtml"), ".")
  assert_eq(path_basename("c.xhtml"), "c.xhtml")
}

///|
test "extension_of / media_type_of_path: 大小写无关的扩展名推断" {
  assert_eq(extension_of("a/b.XHTML"), "xhtml")
  assert_eq(extension_of("noext"), "")
  assert_eq(media_type_of_path("a/cover.PNG"), "image/png")
  assert_eq(media_type_of_path("text/ch1.xhtml"), "application/xhtml+xml")
  assert_eq(media_type_of_path("mystery.xyz"), "application/octet-stream")
}

///|
test "规范常量: 关键取值" {
  assert_eq(ns_opf, "http://www.idpf.org/2007/opf")
  assert_eq(mt_epub, "application/epub+zip")
  assert_eq(ocf_mimetype, "mimetype")
  assert_eq(ocf_container_path, "META-INF/container.xml")
  assert_eq(dc_elements.length(), 15)
}
