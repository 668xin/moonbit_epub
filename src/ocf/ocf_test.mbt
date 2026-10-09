///|
/// S4 OCF 容器布局与端到端打包的单元测试。

///|
/// 读取小端 16 位无符号整数。
fn le_u16(data : Bytes, off : Int) -> Int {
  (data[off].to_uint() | (data[off + 1].to_uint() << 8)).reinterpret_as_int()
}

///|
/// 读取小端 32 位无符号整数。
fn le_u32(data : Bytes, off : Int) -> Int {
  (data[off].to_uint() |
  (data[off + 1].to_uint() << 8) |
  (data[off + 2].to_uint() << 16) |
  (data[off + 3].to_uint() << 24)).reinterpret_as_int()
}

///|
/// 把 ASCII 字节解码为字符串（测试条目名均为 ASCII）。
fn ascii(data : Bytes, off : Int, len : Int) -> String {
  let end = off + len
  let out : Array[Char] = []
  for i in off..<end {
    out.push(data[i].to_int().unsafe_to_char())
  }
  String::from_array(out)
}

///|
/// 解析 ZIP 中央目录，返回条目名称列表（按登记顺序）。
fn zip_names(data : Bytes) -> Array[String] {
  let eocd = data.length() - 22
  let count = le_u16(data, eocd + 10)
  let mut p = le_u32(data, eocd + 16)
  let out : Array[String] = []
  for _ in 0..<count {
    let name_len = le_u16(data, p + 28)
    let extra_len = le_u16(data, p + 30)
    let comment_len = le_u16(data, p + 32)
    out.push(ascii(data, p + 46, name_len))
    p += 46 + name_len + extra_len + comment_len
  }
  out
}

///|
/// 构造用于打包测试的最小书籍。
fn sample_book() -> @model.Book {
  let meta = @model.Metadata::new("示例书", "zh-CN", "urn:uuid:test")
  let book = @model.Book::new(meta)
  book.add_chapter(
    @model.Chapter::with_body("ch1", "第一章", [
      @model.Block::paragraph("你好"),
    ]),
  )
  book.add_chapter(
    @model.Chapter::with_body("ch2", "第二章", [
      @model.Block::heading(2, "小节"),
    ]),
  )
  book.add_resource(@model.Resource::css("styles/style.css", "body {}"))
  book
}

///|
test "render_container: 指向包文档的 rootfile" {
  let xml = render_container("OEBPS/content.opf")
  assert_true(
    xml.contains(
      "<rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/>",
    ),
  )
  assert_true(xml.contains("version=\"1.0\""))
  assert_true(xml.contains("urn:oasis:names:tc:opendocument:xmlns:container"))
}

///|
test "package_book: 首个条目为存储的 mimetype" {
  let data = package_book(sample_book(), PackageOptions::new())
  assert_eq(le_u32(data, 0), 0x04034B50)
  assert_eq(le_u16(data, 8), 0) // 存储
  assert_eq(ascii(data, 30, 8), "mimetype")
  assert_eq(ascii(data, 38, 20), "application/epub+zip")
}

///|
test "package_book: 容器完整布局" {
  let data = package_book(sample_book(), PackageOptions::new())
  assert_eq(zip_names(data), [
    "mimetype", "META-INF/container.xml", "OEBPS/content.opf", "OEBPS/nav.xhtml",
    "OEBPS/toc.ncx", "OEBPS/text/ch1.xhtml", "OEBPS/text/ch2.xhtml", "OEBPS/styles/style.css",
  ])
}

///|
test "package_book: 自定义内容目录" {
  let options = PackageOptions::new()
  options.set_content_dir("EPUB")
  options.set_language("en")
  options.add_stylesheet("../styles/style.css")
  let names = zip_names(package_book(sample_book(), options))
  assert_eq(names[2], "EPUB/content.opf")
  assert_eq(names[3], "EPUB/nav.xhtml")
  assert_eq(names[5], "EPUB/text/ch1.xhtml")
  assert_eq(names[7], "EPUB/styles/style.css")
}

///|
/// 在中央目录中查找条目的未压缩尺寸（供样式注入对比使用）。
fn entry_uncompressed_size(data : Bytes, name : String) -> Int {
  let eocd = data.length() - 22
  let count = le_u16(data, eocd + 10)
  let mut p = le_u32(data, eocd + 16)
  for _ in 0..<count {
    let name_len = le_u16(data, p + 28)
    let extra_len = le_u16(data, p + 30)
    let comment_len = le_u16(data, p + 32)
    if ascii(data, p + 46, name_len) == name {
      return le_u32(data, p + 24)
    }
    p += 46 + name_len + extra_len + comment_len
  }
  -1
}

///|
test "render_container: 完整结构与命名空间" {
  let xml = render_container("OEBPS/content.opf")
  assert_true(xml.has_prefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
  assert_true(xml.has_suffix("</container>"))
  assert_true(
    xml.contains(
      "<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">",
    ),
  )
  assert_true(xml.contains("<rootfiles>"))
  assert_true(xml.contains("</rootfiles>"))
}

///|
test "render_container: 嵌套与自定义 full-path" {
  let xml = render_container("EPUB/pkg/book.opf")
  assert_true(
    xml.contains(
      "<rootfile full-path=\"EPUB/pkg/book.opf\" media-type=\"application/oebps-package+xml\"/>",
    ),
  )
  assert_false(xml.contains("OEBPS/content.opf"))
}

///|
test "render_container: full-path 中的特殊字符被转义" {
  let xml = render_container("a&b/c.opf")
  assert_true(xml.contains("full-path=\"a&amp;b/c.opf\""))
}

///|
test "PackageOptions: 规范默认值" {
  let options = PackageOptions::new()
  assert_eq(options.content_dir, "OEBPS")
  assert_eq(options.package_filename, "content.opf")
  assert_eq(options.nav_filename, "nav.xhtml")
  assert_eq(options.ncx_filename, "toc.ncx")
  assert_eq(options.language, "")
  assert_false(options.use_descriptors)
  assert_eq(options.stylesheets.length(), 0)
}

///|
test "PackageOptions: 各 setter 生效" {
  let options = PackageOptions::new()
  options.set_content_dir("EPUB")
  options.set_package_filename("book.opf")
  options.set_nav_filename("nav2.xhtml")
  options.set_ncx_filename("toc2.ncx")
  options.set_language("fr")
  options.set_use_descriptors(true)
  assert_eq(options.content_dir, "EPUB")
  assert_eq(options.package_filename, "book.opf")
  assert_eq(options.nav_filename, "nav2.xhtml")
  assert_eq(options.ncx_filename, "toc2.ncx")
  assert_eq(options.language, "fr")
  assert_true(options.use_descriptors)
}

///|
test "PackageOptions: add_stylesheet 按顺序追加" {
  let options = PackageOptions::new()
  options.add_stylesheet("../styles/a.css")
  options.add_stylesheet("../styles/b.css")
  assert_eq(options.stylesheets.length(), 2)
  assert_eq(options.stylesheets[0], "../styles/a.css")
  assert_eq(options.stylesheets[1], "../styles/b.css")
}

///|
test "package_book: 自定义文件名与内容目录生效" {
  let options = PackageOptions::new()
  options.set_content_dir("EPUB")
  options.set_package_filename("book.opf")
  options.set_nav_filename("navigation.xhtml")
  options.set_ncx_filename("notes.ncx")
  let names = zip_names(package_book(sample_book(), options))
  assert_eq(names[0], "mimetype")
  assert_eq(names[1], "META-INF/container.xml")
  assert_eq(names[2], "EPUB/book.opf")
  assert_eq(names[3], "EPUB/navigation.xhtml")
  assert_eq(names[4], "EPUB/notes.ncx")
  assert_eq(names[5], "EPUB/text/ch1.xhtml")
}

///|
test "package_book: 描述符模式标志位" {
  let options = PackageOptions::new()
  options.set_use_descriptors(true)
  let data = package_book(sample_book(), options)
  assert_eq(le_u16(data, 6), 0x0800) // mimetype 始终不用描述符
  let off = 30 + 8 + 20
  assert_eq(le_u16(data, off + 6), 0x0808) // container.xml 启用描述符
}

///|
test "package_book: 样式表注入增大内容文档" {
  let without = package_book(sample_book(), PackageOptions::new())
  let options = PackageOptions::new()
  options.add_stylesheet("../styles/style.css")
  let packaged = package_book(sample_book(), options)
  let a = entry_uncompressed_size(without, "OEBPS/text/ch1.xhtml")
  let b = entry_uncompressed_size(packaged, "OEBPS/text/ch1.xhtml")
  assert_true(a > 0)
  assert_true(b > a)
}
