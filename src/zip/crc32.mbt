///|
/// CRC-32 校验（IEEE 802.3）。
///
/// ZIP 的每个条目都需在本地文件头与中央目录登记数据校验值，采用反射
/// 多项式 `0xEDB88320`：寄存器初值与终值均与 `0xFFFFFFFF` 异或，
/// 输入按字节反射处理。查表法在首次调用时构建一次 256 项表。

///|
/// CRC-32 反射多项式常量。
let crc_poly : UInt = 0xEDB88320U

///|
/// 构造 256 项 CRC-32 查表。
fn crc_table() -> FixedArray[UInt] {
  let table = FixedArray::make(256, 0U)
  for n in 0..<256 {
    let mut c = n.reinterpret_as_uint()
    for _ in 0..<8 {
      if (c & 1U) != 0U {
        c = (c >> 1) ^ crc_poly
      } else {
        c = c >> 1
      }
    }
    table[n] = c
  }
  table
}

///|
/// 计算字节序列的 CRC-32 值。
pub fn crc32(data : Bytes) -> UInt {
  let table = crc_table()
  let mut crc = 0xFFFFFFFFU
  for i in 0..<data.length() {
    let idx = ((crc ^ data[i].to_uint()) & 0xFFU).reinterpret_as_int()
    crc = (crc >> 8) ^ table[idx]
  }
  crc ^ 0xFFFFFFFFU
}
