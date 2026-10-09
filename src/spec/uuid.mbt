///|
/// 唯一标识符派生：基于内容的确定性 UUID（S0）。
///
/// 采用 RFC 4122 版本 5（名字基、SHA-1）方案：把「命名空间 UUID 的 16 字节」
/// 与「名字的 UTF-8 字节」拼接后取 SHA-1 摘要，截取前 16 字节并按规范置入
/// 版本位（`0101`）与变体位（`10`），最后序列化为 8-4-4-4-12 的小写十六进制。
///
/// 相同内容恒得相同 UUID，无需时钟或随机源，故可用于生成可复现的
/// `dc:identifier`。也可配合 `Metadata::set_identifier` 承载自定义标识符方案。

///|
/// 项目默认命名空间 UUID（固定常量，保证派生结果可复现）。
pub let epub_uuid_namespace : String = "6f0a1e2c-3b4d-4e5f-8a9b-0c1d2e3f4a5b"

// ---------------------------------------------------------------------------
// SHA-1（RFC 3174）
// ---------------------------------------------------------------------------

///|
/// 32 位循环左移。
fn rotl32(x : UInt, n : Int) -> UInt {
  (x << n) | (x >> (32 - n))
}

///|
/// 以大端序写入 4 字节。
fn write_uint32_be(buf : Buffer, value : UInt) -> Unit {
  buf.write_byte(((value >> 24) & 0xFFU).to_byte())
  buf.write_byte(((value >> 16) & 0xFFU).to_byte())
  buf.write_byte(((value >> 8) & 0xFFU).to_byte())
  buf.write_byte((value & 0xFFU).to_byte())
}

///|
/// 计算字节序列的 SHA-1 摘要（20 字节）。
pub fn sha1(data : Bytes) -> Bytes {
  let n = data.length()
  // 填充：追加 0x80，补零至长度 ≡ 56 (mod 64)，再写 64 位大端比特长度。
  let buf = Buffer()
  buf.write_bytes(data)
  buf.write_byte(128U.to_byte())
  let mut cur = n + 1
  while cur % 64 != 56 {
    buf.write_byte(0U.to_byte())
    cur += 1
  }
  write_uint32_be(buf, (n >> 29).reinterpret_as_uint())
  write_uint32_be(buf, (n << 3).reinterpret_as_uint())
  let msg = buf.to_bytes()
  // 摘要状态。
  let mut h0 = 0x67452301U
  let mut h1 = 0xEFCDAB89U
  let mut h2 = 0x98BADCFEU
  let mut h3 = 0x10325476U
  let mut h4 = 0xC3D2E1F0U
  let mut block = 0
  while block < msg.length() {
    let w = FixedArray::make(80, 0U)
    for t in 0..<16 {
      let i = block + t * 4
      w[t] = (msg[i].to_uint() << 24) |
        (msg[i + 1].to_uint() << 16) |
        (msg[i + 2].to_uint() << 8) |
        msg[i + 3].to_uint()
    }
    for t in 16..<80 {
      w[t] = rotl32(w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16], 1)
    }
    let mut a = h0
    let mut b = h1
    let mut c = h2
    let mut d = h3
    let mut e = h4
    for t in 0..<80 {
      let f = if t < 20 {
        (b & c) | ((b ^ 0xFFFFFFFFU) & d)
      } else if t < 40 {
        b ^ c ^ d
      } else if t < 60 {
        (b & c) | (b & d) | (c & d)
      } else {
        b ^ c ^ d
      }
      let k = if t < 20 {
        0x5A827999U
      } else if t < 40 {
        0x6ED9EBA1U
      } else if t < 60 {
        0x8F1BBCDCU
      } else {
        0xCA62C1D6U
      }
      let temp = rotl32(a, 5) + f + e + k + w[t]
      e = d
      d = c
      c = rotl32(b, 30)
      b = a
      a = temp
    }
    h0 = h0 + a
    h1 = h1 + b
    h2 = h2 + c
    h3 = h3 + d
    h4 = h4 + e
    block += 64
  }
  let out = Buffer()
  write_uint32_be(out, h0)
  write_uint32_be(out, h1)
  write_uint32_be(out, h2)
  write_uint32_be(out, h3)
  write_uint32_be(out, h4)
  out.to_bytes()
}

// ---------------------------------------------------------------------------
// UUID 文本编解码
// ---------------------------------------------------------------------------

///|
/// 单个十六进制字符的数值；非法字符返回 `None`。
fn hex_value(c : Char) -> Int? {
  let v = c.to_int()
  if v >= 48 && v <= 57 {
    Some(v - 48)
  } else if v >= 97 && v <= 102 {
    Some(v - 87)
  } else if v >= 65 && v <= 70 {
    Some(v - 55)
  } else {
    None
  }
}

///|
/// 单个十六进制半字节的字符。
fn hex_digit(v : Int) -> Char {
  if v < 10 {
    Int::unsafe_to_char(48 + v)
  } else {
    Int::unsafe_to_char(97 + v - 10)
  }
}

///|
/// 解析标准 8-4-4-4-12 形式的 UUID 文本为 16 字节；格式非法时返回 `None`。
pub fn parse_uuid(uuid : String) -> Bytes? {
  let chars = uuid.to_array()
  if chars.length() != 36 {
    return None
  }
  let buf = Buffer()
  let mut nibble : Int? = None
  let mut i = 0
  while i < 36 {
    let c = chars[i]
    if c == '-' {
      if i != 8 && i != 13 && i != 18 && i != 23 {
        return None
      }
      i += 1
      continue
    }
    match hex_value(c) {
      None => return None
      Some(v) =>
        match nibble {
          None => nibble = Some(v)
          Some(h) => {
            buf.write_byte((h * 16 + v).to_byte())
            nibble = None
          }
        }
    }
    i += 1
  }
  Some(buf.to_bytes())
}

///|
/// 由 16 字节摘要序列化为 8-4-4-4-12 形式。
fn format_uuid(digest : Bytes) -> String {
  let bytes = FixedArray::make(16, 0U.to_byte())
  for i in 0..<16 {
    bytes[i] = digest[i]
  }
  // 版本位：第 6 字节高半字节置 0101（版本 5）。
  bytes[6] = ((bytes[6].to_uint() & 0x0FU) | 0x50U).to_byte()
  // 变体位：第 8 字节高两位置 10（RFC 4122 变体）。
  bytes[8] = ((bytes[8].to_uint() & 0x3FU) | 0x80U).to_byte()
  let out : Array[Char] = []
  for i in 0..<16 {
    if i == 4 || i == 6 || i == 8 || i == 10 {
      out.push('-')
    }
    let v = bytes[i].to_uint()
    out.push(hex_digit((v >> 4).reinterpret_as_int()))
    out.push(hex_digit((v & 0x0FU).reinterpret_as_int()))
  }
  String::from_array(out)
}

// ---------------------------------------------------------------------------
// 名字基 UUID
// ---------------------------------------------------------------------------

///|
/// 以命名空间 UUID 的字节与名字的 UTF-8 字节派生版本 5 UUID 字符串。
fn uuid_v5_bytes(ns : Bytes, name : String) -> String {
  let buf = Buffer()
  buf.write_bytes(ns)
  buf.write_string_utf8(name)
  format_uuid(sha1(buf.to_bytes()))
}

///|
/// 由命名空间 UUID 文本与名字派生版本 5 UUID（8-4-4-4-12 小写）。
///
/// 命名空间不是合法 UUID 时返回 `None`。
pub fn uuid_v5(namespace_uuid : String, name : String) -> String? {
  match parse_uuid(namespace_uuid) {
    None => None
    Some(bytes) => Some(uuid_v5_bytes(bytes, name))
  }
}

///|
/// 由内容文本派生确定性 UUID 字符串（不含前缀）。
///
/// 采用项目默认命名空间，相同内容恒得相同结果。
pub fn content_uuid(content : String) -> String {
  let ns = match parse_uuid(epub_uuid_namespace) {
    Some(bytes) => bytes
    None => Bytes::new(0)
  }
  uuid_v5_bytes(ns, content)
}

///|
/// 由内容文本派生 `urn:uuid:` 形式的唯一标识符，可直接用作 `dc:identifier`。
pub fn content_identifier(content : String) -> String {
  urn_uuid_prefix + content_uuid(content)
}
