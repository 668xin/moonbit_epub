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

// ---------------------------------------------------------------------------
// 用于验证 DEFLATE 往返的固定 Huffman 解码器（仅覆盖编码器使用的块类型）
// ---------------------------------------------------------------------------

///|
/// LSB-first 位读取器。
struct BitReader {
  data : Bytes
  mut pos : Int
  mut bit : Int
}

///|
fn BitReader::new(data : Bytes) -> BitReader {
  { data, pos: 0, bit: 0, }
}

///|
/// 读取一位。
fn BitReader::read_bit(self : BitReader) -> Int {
  let b = (self.data[self.pos].to_int() >> self.bit) & 1
  self.bit += 1
  if self.bit == 8 {
    self.bit = 0
    self.pos += 1
  }
  b
}

///|
/// 按 LSB-first 读取 `n` 位（额外长度/距离位）。
fn read_extra(bits : BitReader, n : Int) -> Int {
  let mut v = 0
  for i in 0..<n {
    v = v | (bits.read_bit() << i)
  }
  v
}

///|
/// 按 MSB-first 读取 `n` 位（Huffman 码字）。
fn read_code(bits : BitReader, n : Int) -> Int {
  let mut v = 0
  for _ in 0..<n {
    v = (v << 1) | bits.read_bit()
  }
  v
}

///|
/// 固定 Huffman 字面量/长度码解码。
fn decode_lit(bits : BitReader) -> Int {
  let mut code = 0
  let mut len = 0
  let mut result = -1
  while result < 0 {
    code = (code << 1) | bits.read_bit()
    len += 1
    if len == 7 && code <= 0x17 {
      result = 256 + code
    } else if len == 8 && code >= 0x30 && code <= 0xBF {
      result = code - 0x30
    } else if len == 8 && code >= 0xC0 && code <= 0xC7 {
      result = 280 + code - 0xC0
    } else if len == 9 && code >= 0x190 && code <= 0x1FF {
      result = 144 + code - 0x190
    }
  }
  result
}

///|
let zt_len_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
let zt_len_extra : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 5,
]

///|
let zt_dist_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
let zt_dist_extra : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
/// 把固定 Huffman DEFLATE 数据解码为字符串（测试输入均为 ASCII）。
fn inflate_to_string(data : Bytes) -> String {
  let bits = BitReader::new(data)
  let _ = bits.read_bit()
  let _ = read_extra(bits, 2)
  let out : Array[Char] = []
  let mut done = false
  while !done {
    let sym = decode_lit(bits)
    if sym < 256 {
      out.push(sym.unsafe_to_char())
    } else if sym == 256 {
      done = true
    } else {
      let li = sym - 257
      let length = zt_len_base[li] + read_extra(bits, zt_len_extra[li])
      let dsym = read_code(bits, 5)
      let dist = zt_dist_base[dsym] + read_extra(bits, zt_dist_extra[dsym])
      let start = out.length() - dist
      for k in 0..<length {
        out.push(out[start + k])
      }
    }
  }
  String::from_array(out)
}

///|
/// 把 ASCII 文本编码为 UTF-8 字节。
fn ascii_bytes(text : String) -> Bytes {
  let buf = Buffer()
  buf.write_string_utf8(text)
  buf.to_bytes()
}

///|
/// 截取字节区间。
fn slice_bytes(data : Bytes, start : Int, len : Int) -> Bytes {
  let buf = Buffer()
  for i in start..<(start + len) {
    buf.write_byte(data[i])
  }
  buf.to_bytes()
}

///|
test "crc32: 更多已知向量" {
  assert_eq(crc32(b"abc"), 0x352441C2U)
  assert_eq(crc32(b"The quick brown fox jumps over the lazy dog"), 0x414FA339U)
}

///|
test "zip: 本地头与中央目录版本与标志" {
  let zip = ZipWriter::new()
  zip.add_stored("file.txt", b"hello")
  let data = zip.finish()
  assert_eq(le_u16(data, 4), 20) // 解压所需版本
  assert_eq(le_u16(data, 6), 0x0800)
  assert_eq(le_u16(data, 8), 0)
  let eocd = data.length() - 22
  let cd = le_u32(data, eocd + 16)
  assert_eq(le_u32(data, cd), 0x02014B50)
  assert_eq(le_u16(data, cd + 4), 20) // version made by
  assert_eq(le_u16(data, cd + 6), 20) // version needed
  assert_eq(le_u16(data, cd + 8), 0x0800)
  assert_eq(le_u16(data, cd + 10), 0)
  assert_eq(le_u16(data, cd + 28), 8) // 名称长度 "file.txt"
  assert_eq(le_u16(data, cd + 30), 0) // 无额外字段
  assert_eq(le_u16(data, cd + 32), 0) // 无注释
  assert_eq(le_u16(data, cd + 34), 0) // 起始磁盘号
  assert_eq(le_u16(data, cd + 36), 0) // 内部属性
  assert_eq(le_u32(data, cd + 38), 0) // 外部属性
  assert_eq(ascii(data, cd + 46, 8), "file.txt")
}

///|
test "zip: 固定 1980-01-01 时间戳" {
  let zip = ZipWriter::new()
  zip.add_stored("a", b"1")
  let data = zip.finish()
  assert_eq(le_u16(data, 10), 0) // 本地头时间 00:00:00
  assert_eq(le_u16(data, 12), 0x21) // 本地头日期 1980-01-01
  let eocd = data.length() - 22
  let cd = le_u32(data, eocd + 16)
  assert_eq(le_u16(data, cd + 12), 0)
  assert_eq(le_u16(data, cd + 14), 0x21)
}

///|
test "zip: 空文件退回存储且尺寸为零" {
  let zip = ZipWriter::new()
  zip.add_deflated("empty.bin", b"")
  assert_eq(zip.entry_count(), 1)
  let data = zip.finish()
  assert_eq(le_u16(data, 8), 0) // 压缩无收益，退回存储
  assert_eq(le_u32(data, 14), 0) // CRC
  assert_eq(le_u32(data, 18), 0) // 压缩尺寸
  assert_eq(le_u32(data, 22), 0) // 原始尺寸
}

///|
test "zip: 单字节条目字段与校验" {
  let zip = ZipWriter::new()
  zip.add_stored("one", b"Z")
  let data = zip.finish()
  assert_eq(le_u16(data, 8), 0)
  assert_eq(le_u32(data, 14), crc32(b"Z").reinterpret_as_int())
  assert_eq(le_u32(data, 18), 1)
  assert_eq(le_u32(data, 22), 1)
  assert_eq(ascii(data, 33, 1), "Z")
}

///|
test "zip: 中央目录 local_offset 指向本地头" {
  let zip = ZipWriter::new()
  zip.add_stored("a", b"12")
  zip.add_stored("bb", b"34")
  let data = zip.finish()
  let eocd = data.length() - 22
  let cd = le_u32(data, eocd + 16)
  assert_eq(le_u32(data, cd + 42), 0)
  // 第二条中央目录条目位于 46 + 名 1 之后，其 local_offset 应为第一条本地长度
  assert_eq(le_u32(data, cd + 46 + 1 + 42), 30 + 1 + 2)
}

///|
test "zip: EOCD 中央目录尺寸与偏移" {
  let zip = ZipWriter::new()
  zip.add_stored("a", b"1")
  zip.add_stored("bb", b"22")
  let data = zip.finish()
  let eocd = data.length() - 22
  assert_eq(le_u32(data, eocd), 0x06054B50)
  let cd = le_u32(data, eocd + 16)
  let cd_size = le_u32(data, eocd + 12)
  assert_eq(le_u32(data, cd), 0x02014B50)
  assert_eq(cd + cd_size, eocd)
  assert_eq(le_u16(data, eocd + 8), 2)
  assert_eq(le_u16(data, eocd + 10), 2)
  assert_eq(le_u16(data, eocd + 20), 0) // 无注释
}

///|
test "deflate: 确定性输出与块头位" {
  let a = deflate(b"abcabcabcabcabcabc")
  let b = deflate(b"abcabcabcabcabcabc")
  assert_eq(a.length(), b.length())
  let mut same = true
  for i in 0..<a.length() {
    if a[i] != b[i] {
      same = false
    }
  }
  assert_true(same)
  assert_eq(a[0].to_uint() & 0x7U, 3U)
}

///|
test "deflate: 空输入与文本往返一致" {
  assert_eq(inflate_to_string(deflate(b"")), "")
  assert_eq(inflate_to_string(deflate(b"a")), "a")
  assert_eq(inflate_to_string(deflate(b"ab")), "ab")
  assert_eq(
    inflate_to_string(deflate(b"hello hello hello hello")),
    "hello hello hello hello",
  )
  assert_eq(
    inflate_to_string(deflate(b"abcabcabcabcabcabcabcabc")),
    "abcabcabcabcabcabcabcabc",
  )
}

///|
test "zip: 大文本条目的压缩元数据与解压一致" {
  let out : Array[Char] = []
  for _ in 0..<300 {
    out.push_iter("The quick brown fox jumps. ".iter())
  }
  let text = String::from_array(out)
  let raw = ascii_bytes(text)
  let zip = ZipWriter::new()
  zip.add_deflated("large.txt", raw)
  let data = zip.finish()
  assert_eq(le_u16(data, 8), 8) // DEFLATE
  let comp = le_u32(data, 18)
  let unco = le_u32(data, 22)
  assert_eq(unco, raw.length())
  assert_true(comp < unco)
  assert_eq(le_u32(data, 14), crc32(raw).reinterpret_as_int())
  let payload = slice_bytes(data, 30 + @spec.utf8_len("large.txt"), comp)
  assert_eq(inflate_to_string(payload), text)
}
