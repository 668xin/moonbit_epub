///|
/// DEFLATE（RFC 1951）固定 Huffman 编码器。
///
/// 实现 OCF 打包所需的子集：单个 `BFINAL=1`、`BTYPE=01`（固定 Huffman）
/// 的压缩块，配合贪心 LZ77 匹配。DEFLATE 位流整体按 LSB-first 输出，
/// 而 Huffman 码字本身约定 MSB-first，故写码字前先做位反转；长度/距离
/// 的额外位则按 LSB-first 原样写出。
///
/// 输出为 `Bytes`，可交由 ZIP 写入器以 `deflate` 方法登记。

// ---------------------------------------------------------------------------
// 固定码表常量
// ---------------------------------------------------------------------------

///|
/// 长度码（257..285）的额外位长度。
let len_extra : Array[Int] = [
  0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5,
  5, 5, 0,
]

///|
/// 长度码（257..285）的基准匹配长度。
let len_base : Array[Int] = [
  3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83,
  99, 115, 131, 163, 195, 227, 258,
]

///|
/// 距离码（0..29）的额外位长度。
let dist_extra : Array[Int] = [
  0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11,
  12, 12, 13, 13,
]

///|
/// 距离码（0..29）的基准距离。
let dist_base : Array[Int] = [
  1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769,
  1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
]

///|
/// LZ77 最小匹配长度。
let min_match : Int = 3

///|
/// LZ77 最大匹配长度（DEFLATE 长度码上限）。
let max_match : Int = 258

///|
/// 匹配窗口大小（DEFLATE 距离码上限）。
let window_size : Int = 32768

///|
/// 哈希链头表位数与大小。
let hash_bits : Int = 15

///|
let hash_size : Int = 1 << hash_bits

// ---------------------------------------------------------------------------
// 位流写入
// ---------------------------------------------------------------------------

///|
/// LSB-first 位流写入器：按位累积，满 8 位即落盘为字节。
priv struct BitWriter {
  buf : Buffer
  mut bits : UInt
  mut count : Int
}

///|
/// 构造位写入器。
fn BitWriter::new() -> BitWriter {
  { buf: Buffer(), bits: 0U, count: 0, }
}

///|
/// 写入 `value` 的低 `n` 位，按 LSB-first 追加到当前位流。
fn BitWriter::write(self : BitWriter, value : UInt, n : Int) -> Unit {
  self.bits = self.bits | ((value & ((1U << n) - 1U)) << self.count)
  self.count += n
  while self.count >= 8 {
    self.buf.write_byte((self.bits & 0xFFU).to_byte())
    self.bits = self.bits >> 8
    self.count -= 8
  }
}

///|
/// 补齐最后一个字节并返回结果。
fn BitWriter::finish(self : BitWriter) -> Bytes {
  if self.count > 0 {
    self.buf.write_byte((self.bits & 0xFFU).to_byte())
    self.bits = 0U
    self.count = 0
  }
  self.buf.to_bytes()
}

///|
/// 反转 `code` 的低 `len` 位，用于把 MSB-first 的 Huffman 码字
/// 转换为可在 LSB-first 位流中直接写出的形式。
fn reverse_bits(code : UInt, len : Int) -> UInt {
  let mut r = 0U
  let mut c = code
  for _ in 0..<len {
    r = (r << 1) | (c & 1U)
    c = c >> 1
  }
  r
}

// ---------------------------------------------------------------------------
// 码字映射
// ---------------------------------------------------------------------------

///|
/// 固定 Huffman 字面量/长度码：返回 `(码字, 位长)`。
///
/// 码表（RFC 1951 §3.2.6）：
/// - `0..143` → 8 位，基码 `0x30`
/// - `144..255` → 9 位，基码 `0x190`
/// - `256..279` → 7 位，基码 `0x00`
/// - `280..287` → 8 位，基码 `0xC0`
fn fixed_lit_code(sym : Int) -> (UInt, Int) {
  if sym <= 143 {
    (0x30U + sym.reinterpret_as_uint(), 8)
  } else if sym <= 255 {
    (0x190U + (sym - 144).reinterpret_as_uint(), 9)
  } else if sym <= 279 {
    ((sym - 256).reinterpret_as_uint(), 7)
  } else {
    (0xC0U + (sym - 280).reinterpret_as_uint(), 8)
  }
}

///|
/// 由匹配长度求长度码：返回 `(符号, 额外位长度, 额外位值)`。
fn length_symbol(length : Int) -> (Int, Int, Int) {
  let mut i = 0
  while i < len_base.length() {
    let base = len_base[i]
    let extra = len_extra[i]
    if length <= base + ((1 << extra) - 1) {
      return (257 + i, extra, length - base)
    }
    i += 1
  }
  (285, 0, 0)
}

///|
/// 由距离求距离码：返回 `(符号, 额外位长度, 额外位值)`。
fn distance_symbol(dist : Int) -> (Int, Int, Int) {
  let mut i = 0
  while i < dist_base.length() {
    let base = dist_base[i]
    let extra = dist_extra[i]
    if dist <= base + ((1 << extra) - 1) {
      return (i, extra, dist - base)
    }
    i += 1
  }
  (29, 13, dist - 24577)
}

///|
/// 写出一个固定 Huffman 字面量。
fn write_literal(w : BitWriter, byte : Int) -> Unit {
  let (code, bits) = fixed_lit_code(byte)
  w.write(reverse_bits(code, bits), bits)
}

///|
/// 写出一对长度/距离（LZ77 匹配）。
fn write_match(w : BitWriter, length : Int, dist : Int) -> Unit {
  let (lsym, lextra, lval) = length_symbol(length)
  let (lcode, lbits) = fixed_lit_code(lsym)
  w.write(reverse_bits(lcode, lbits), lbits)
  if lextra > 0 {
    w.write(lval.reinterpret_as_uint(), lextra)
  }
  let (dsym, dextra, dval) = distance_symbol(dist)
  w.write(reverse_bits(dsym.reinterpret_as_uint(), 5), 5)
  if dextra > 0 {
    w.write(dval.reinterpret_as_uint(), dextra)
  }
}

// ---------------------------------------------------------------------------
// 主流程
// ---------------------------------------------------------------------------

///|
/// 三元组哈希：把位置 `pos` 起的 3 个字节折叠为哈希链下标。
fn hash3(data : Bytes, pos : Int) -> Int {
  let a = data[pos].to_int()
  let b = data[pos + 1].to_int()
  let c = data[pos + 2].to_int()
  ((a << 10) ^ (b << 5) ^ c) & (hash_size - 1)
}

///|
/// 用固定 Huffman + 贪心 LZ77 压缩字节序列。
///
/// 采用哈希链在 32 KiB 窗口内寻找最长匹配，单条链最多回溯 128 个候选
/// 以控制耗时；匹配到的区间会逐位置并入链，保证后续仍有可利用的匹配。
pub fn deflate(data : Bytes) -> Bytes {
  let w = BitWriter::new()
  // 块头：BFINAL=1，BTYPE=01（固定 Huffman）
  w.write(1U, 1)
  w.write(1U, 2)
  let n = data.length()
  let head = FixedArray::make(hash_size, -1)
  let prev = FixedArray::make(n, -1)
  let mut i = 0
  while i < n {
    let mut best_len = 0
    let mut best_dist = 0
    if i + min_match <= n {
      let h = hash3(data, i)
      let mut candidate = head[h]
      let mut chain = 0
      let limit = if i + max_match <= n { max_match } else { n - i }
      while candidate >= 0 && chain < 128 {
        let dist = i - candidate
        if dist > window_size {
          break
        }
        let mut l = 0
        while l < limit && data[candidate + l] == data[i + l] {
          l += 1
        }
        if l > best_len {
          best_len = l
          best_dist = dist
          if best_len >= max_match {
            break
          }
        }
        candidate = prev[candidate]
        chain += 1
      }
    }
    if best_len >= min_match {
      write_match(w, best_len, best_dist)
      let end = i + best_len
      let mut j = i
      while j < end {
        if j + min_match <= n {
          let h = hash3(data, j)
          prev[j] = head[h]
          head[h] = j
        }
        j += 1
      }
      i = end
    } else {
      write_literal(w, data[i].to_int())
      if i + min_match <= n {
        let h = hash3(data, i)
        prev[i] = head[h]
        head[h] = i
      }
      i += 1
    }
  }
  // 块结束码（符号 256）
  let (ecode, ebits) = fixed_lit_code(256)
  w.write(reverse_bits(ecode, ebits), ebits)
  w.finish()
}
