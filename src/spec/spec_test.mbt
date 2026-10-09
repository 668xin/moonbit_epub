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

///|
test "xml_escape: 全部保留字符与空串" {
  assert_eq(xml_escape("&<>"), "&amp;&lt;&gt;")
  assert_eq(xml_escape(""), "")
  assert_eq(xml_escape("plain"), "plain")
  // 文本模式不转义引号、制表符与换行。
  assert_eq(xml_escape("a\tb\nc\"d'e"), "a\tb\nc\"d'e")
  assert_eq(
    xml_escape("<a href=\"x\">t</a>"),
    "&lt;a href=\"x\"&gt;t&lt;/a&gt;",
  )
}

///|
test "xml_escape_attr: 引号与全部空白控制字符" {
  assert_eq(
    xml_escape_attr("&<>\"'\n\r\t"),
    "&amp;&lt;&gt;&quot;&#39;&#10;&#13;&#9;",
  )
  assert_eq(xml_escape_attr(""), "")
  assert_eq(xml_escape_attr("keep space"), "keep space")
  assert_eq(xml_escape_attr("a&b"), "a&amp;b")
}

///|
test "utf8_len: 各字节长度边界与混合串" {
  assert_eq(utf8_len("a中😀"), 8)
  assert_eq(utf8_len("é中"), 5)
  // ASCII 边界 0x7F 仍为单字节。
  assert_eq(utf8_len("\u{007f}"), 1)
  // 2/3/4 字节下界。
  assert_eq(utf8_len("\u{0080}"), 2)
  assert_eq(utf8_len("\u{0800}"), 3)
  assert_eq(utf8_len("\u{10000}"), 4)
}

///|
test "is_valid_id: 单字符、嵌套标点与 Unicode" {
  assert_true(is_valid_id("_"))
  assert_true(is_valid_id("a"))
  assert_true(is_valid_id("a.b-c_1"))
  assert_true(is_valid_id("中文标题"))
  assert_false(is_valid_id("-a"))
  assert_false(is_valid_id(".a"))
  assert_false(is_valid_id("a:b"))
  assert_false(is_valid_id("a/b"))
}

///|
test "normalize_id: 分隔符折叠与首尾处理" {
  // 多个非续接字符折叠为单个 `-`；`-` 本身是合法续接字符故保留。
  assert_eq(normalize_id("a!!b"), "a-b")
  assert_eq(normalize_id("--a--b--"), "a--b")
  assert_eq(normalize_id("a/b c"), "a-b-c")
  assert_eq(normalize_id("a-"), "a")
  assert_eq(normalize_id("9lives"), "_9lives")
  assert_eq(normalize_id("中文 标题"), "中文-标题")
  assert_eq(normalize_id("!!!"), "id")
  assert_eq(normalize_id(" "), "id")
}

///|
test "normalize_id: 广泛幂等且始终合法" {
  for
    input in [
      "--a--b--", "a/b c", "a-", "9lives", "中文 标题", "!!!", " ", "..", "_",
      "\u{0000}x",
    ] {
    let once = normalize_id(input)
    assert_eq(normalize_id(once), once)
    assert_true(is_valid_id(once))
  }
}

///|
test "path_join: 空段与结尾分隔符" {
  assert_eq(path_join("a/b", "c/"), "a/b/c/")
  assert_eq(path_join("", ""), "")
  assert_eq(path_join("a/", ""), "a/")
  assert_eq(path_join("/", "x"), "/x")
  assert_eq(path_join("", "a/b"), "a/b")
}

///|
test "normalize_path: 空串、上溯越过根与重复分隔符" {
  assert_eq(normalize_path(""), ".")
  assert_eq(normalize_path("./a/b/"), "a/b")
  assert_eq(normalize_path("/a/./b/../c/"), "/a/c")
  assert_eq(normalize_path("a/b/../.."), ".")
  assert_eq(normalize_path("/../a"), "/a")
  assert_eq(normalize_path("a/../../b"), "../b")
  assert_eq(normalize_path("//a//b//"), "/a/b")
  assert_eq(normalize_path("../.."), "../..")
}

///|
test "media_type_of_path: 各扩展名与回退" {
  assert_eq(media_type_of_path("a.html"), mt_xhtml)
  assert_eq(media_type_of_path("a.htm"), mt_xhtml)
  assert_eq(media_type_of_path("a.ncx"), mt_ncx)
  assert_eq(media_type_of_path("a.opf"), mt_opf)
  assert_eq(media_type_of_path("a.mjs"), mt_js)
  assert_eq(media_type_of_path("a.xml"), mt_xml)
  assert_eq(media_type_of_path("a.smil"), mt_smil)
  assert_eq(media_type_of_path("a.jpeg"), mt_jpeg)
  assert_eq(media_type_of_path("a.gif"), mt_gif)
  assert_eq(media_type_of_path("a.svg"), mt_svg)
  assert_eq(media_type_of_path("a.webp"), mt_webp)
  assert_eq(media_type_of_path("a.mp3"), mt_mp3)
  assert_eq(media_type_of_path("a.m4a"), mt_mp4)
  assert_eq(media_type_of_path("a.oga"), mt_ogg)
  assert_eq(media_type_of_path("a.ttf"), mt_ttf)
  assert_eq(media_type_of_path("a.otf"), mt_otf)
  assert_eq(media_type_of_path("a.woff"), mt_woff)
  assert_eq(media_type_of_path("a.woff2"), mt_woff2)
  assert_eq(media_type_of_path("a.txt"), mt_txt)
  assert_eq(media_type_of_path("a.bin"), mt_octet_stream)
  assert_eq(media_type_of_path("noext"), mt_octet_stream)
}

///|
test "extension_of: 多点、前导点与无扩展名" {
  assert_eq(extension_of("a.tar.gz"), "gz")
  assert_eq(extension_of(".gitignore"), "gitignore")
  assert_eq(extension_of("a/b/c"), "")
  assert_eq(extension_of(""), "")
  assert_eq(extension_of("DIR/File.MP3"), "mp3")
}

///|
test "path_basename / path_dirname: 根目录与空串边界" {
  assert_eq(path_dirname("/x"), "/")
  assert_eq(path_basename("/x"), "x")
  assert_eq(path_dirname("/"), "/")
  assert_eq(path_basename("/"), "")
  assert_eq(path_dirname("a/b/"), "a/b")
  assert_eq(path_basename("a/b/"), "")
  assert_eq(path_dirname(""), ".")
  assert_eq(path_basename(""), "")
  assert_eq(path_basename("abc"), "abc")
}
