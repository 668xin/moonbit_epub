///|
/// S4 ZIP 写入器与 CRC-32 的单元测试。

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
/// 解析 ZIP 中央目录，返回 `(名称, 压缩方法号)` 列表。
fn zip_entries(data : Bytes) -> Array[(String, Int)] {
  let eocd = data.length() - 22
  let count = le_u16(data, eocd + 10)
  let mut p = le_u32(data, eocd + 16)
  let out : Array[(String, Int)] = []
  for _ in 0..<count {
    let compression = le_u16(data, p + 10)
    let name_len = le_u16(data, p + 28)
    let extra_len = le_u16(data, p + 30)
    let comment_len = le_u16(data, p + 32)
    let name = ascii(data, p + 46, name_len)
    out.push((name, compression))
    p += 46 + name_len + extra_len + comment_len
  }
  out
}

///|
test "crc32: 已知校验向量" {
  assert_eq(crc32(b""), 0U)
  assert_eq(crc32(b"123456789"), 0xCBF43926U)
  assert_eq(crc32(b"a"), 0xE8B7BE43U)
}

///|
test "deflate: 固定 Huffman 块头与空输入" {
  let d = deflate(b"abcabcabcabcabcabcabcabc")
  assert_true(d.length() > 0)
  // 首字节低 3 位：BFINAL=1、BTYPE=01
  assert_eq(d[0].to_uint() & 0x7U, 3U)
  let empty = deflate(b"")
  assert_eq(empty.length(), 2)
  assert_eq(empty[0].to_uint() & 0x7U, 3U)
}

///|
test "zip: mimetype 首条目且存储" {
  let zip = ZipWriter::new()
  zip.add_stored("mimetype", b"application/epub+zip")
  zip.add_deflated("hello.txt", b"hello hello hello hello hello hello")
  let data = zip.finish()
  // 首个本地文件头字段
  assert_eq(le_u32(data, 0), 0x04034B50)
  assert_eq(le_u16(data, 6), 0x0800) // UTF-8 文件名标志
  assert_eq(le_u16(data, 8), 0) // 存储方式
  assert_eq(le_u16(data, 26), 8) // 名称长度
  assert_eq(ascii(data, 30, 8), "mimetype")
  // 无额外字段，数据紧随名称
  assert_eq(ascii(data, 38, 20), "application/epub+zip")
  let entries = zip_entries(data)
  assert_eq(entries.length(), 2)
  let (name0, comp0) = entries[0]
  assert_eq(name0, "mimetype")
  assert_eq(comp0, 0)
  let (name1, comp1) = entries[1]
  assert_eq(name1, "hello.txt")
  assert_eq(comp1, 8) // 重复内容应被 Deflate
}

///|
test "zip: 压缩无收益时退回存储" {
  let zip = ZipWriter::new()
  zip.add_deflated("tiny.txt", b"A")
  let data = zip.finish()
  assert_eq(le_u16(data, 8), 0) // 存储
  assert_eq(le_u32(data, 18), 1) // 压缩后尺寸等于原始尺寸
}

///|
test "zip: 条目计数与 EOCD 记录" {
  let zip = ZipWriter::new()
  zip.add_stored("a", b"1")
  zip.add_stored("b", b"2")
  assert_eq(zip.entry_count(), 2)
  let data = zip.finish()
  let eocd = data.length() - 22
  assert_eq(le_u32(data, eocd), 0x06054B50)
  assert_eq(le_u16(data, eocd + 10), 2) // 条目总数
}

///|
test "zip: 数据描述符模式" {
  let zip = ZipWriter::new()
  zip.set_use_descriptors(true)
  zip.add_stored("mimetype", b"application/epub+zip")
  zip.add_stored("a.txt", b"xy")
  let data = zip.finish()
  // mimetype 始终不使用描述符
  assert_eq(le_u16(data, 6), 0x0800)
  // 第二个条目本地头偏移：mimetype 本地头 30 + 名称 8 + 数据 20
  let off = 30 + 8 + 20
  assert_eq(le_u16(data, off + 6), 0x0808)
  // 尺寸字段留零，描述符位于数据之后
  assert_eq(le_u32(data, off + 18), 0)
  let desc = off + 30 + 5 + 2
  assert_eq(le_u32(data, desc), 0x08074B50)
}
