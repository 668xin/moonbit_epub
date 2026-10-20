///|
/// ZIP 中央目录只读解析（S4）。
///
/// 供校验层检查生成容器的条目布局：从端记录（EOCD）定位中央目录，
/// 逐条读出路径与压缩方式。解析失败时返回空数组，由调用方决定如何
/// 报告（`validate_container` 会将空容器视为 `CON-001`）。
///
/// 本模块只读取中央目录，不负责解压；用于结构校验已足够。

///|
/// 中央目录条目信息。
pub struct ZipEntryInfo {
  // 容器内路径（UTF-8 解码）
  path : String
  // 是否以存储方式写入（未压缩）
  stored : Bool
  // 压缩后尺寸
  compressed_size : Int
  // 未压缩尺寸
  uncompressed_size : Int
} derive(Eq, @debug.Debug)

///|
/// 读取小端 16 位无符号整数。
fn read_u16_le(data : Bytes, offset : Int) -> Int {
  (data[offset].to_uint() | (data[offset + 1].to_uint() << 8)).reinterpret_as_int()
}

///|
/// 读取小端 32 位无符号整数。
fn read_u32_le(data : Bytes, offset : Int) -> Int {
  (data[offset].to_uint() |
  (data[offset + 1].to_uint() << 8) |
  (data[offset + 2].to_uint() << 16) |
  (data[offset + 3].to_uint() << 24)).reinterpret_as_int()
}

///|
/// 从文件尾部向前查找端记录（EOCD）签名，返回其偏移。
fn find_eocd(data : Bytes) -> Int? {
  if data.length() < 22 {
    return None
  }
  let mut i = data.length() - 22
  while i >= 0 {
    if read_u32_le(data, i) == 0x06054B50 {
      return Some(i)
    }
    i -= 1
  }
  None
}

///|
/// 把字节区间按 UTF-8 宽松解码为字符串（非法序列替换为 U+FFFD）。
fn bytes_to_string(data : Bytes, start : Int, end : Int) -> String {
  let buf = Buffer()
  for i in start..<end {
    buf.write_byte(data[i])
  }
  @utf8.decode_lossy(buf.to_bytes()[:])
}

///|
/// 解析 ZIP 中央目录，按登记顺序返回条目信息。
///
/// 数据不是合法 ZIP 时返回空数组。
pub fn entries(data : Bytes) -> Array[ZipEntryInfo] {
  let out : Array[ZipEntryInfo] = []
  let eocd = match find_eocd(data) {
    Some(offset) => offset
    None => return out
  }
  if eocd + 22 > data.length() {
    return out
  }
  let count = read_u16_le(data, eocd + 10)
  let mut p = read_u32_le(data, eocd + 16)
  for _ in 0..<count {
    if p < 0 || p + 46 > data.length() {
      break
    }
    if read_u32_le(data, p) != 0x02014B50 {
      break
    }
    let compression_method = read_u16_le(data, p + 10)
    let compressed_size = read_u32_le(data, p + 20)
    let uncompressed_size = read_u32_le(data, p + 24)
    let name_len = read_u16_le(data, p + 28)
    let extra_len = read_u16_le(data, p + 30)
    let comment_len = read_u16_le(data, p + 32)
    let name_start = p + 46
    let name_end = name_start + name_len
    if name_end > data.length() {
      break
    }
    out.push({
      path: bytes_to_string(data, name_start, name_end),
      stored: compression_method == 0,
      compressed_size,
      uncompressed_size,
    })
    p = name_end + extra_len + comment_len
  }
  out
}
