///|
/// ZIP 写入器（S4）。
///
/// 实现存储/Deflate 两种压缩方式、本地文件头、中央目录、数据描述符与
/// 端记录（EOCD），以及 CRC-32 校验，产出完整 ZIP 字节流。OCF 容器的
/// 物理载体即由本模块生成。
///
/// 采用「逐条目缓冲 → 一次序列化」策略：登记时即完成压缩与校验值计算，
/// `finish` 时按本地头/数据、中央目录、端记录的顺序写出，避免整包在
/// 中央目录前驻留额外内存。

///|
/// ZIP 条目压缩方式。
pub enum ZipMethod {
  /// 不压缩（如 OCF 的 `mimetype`）。
  Stored
  /// 使用 DEFLATE 压缩。
  Deflated
} derive(Eq, @debug.Debug)

///|
/// DOS 时间戳字段：`00:00:00`。
let dos_time : UInt = 0U

///|
/// DOS 日期字段：`1980-01-01`（ZIP 时间戳起点）。取固定值使产物可复现。
let dos_date : UInt = 0x21U

///|
/// 已登记的 ZIP 条目。
struct ZipEntry {
  name : String
  compression : ZipMethod
  crc : UInt
  // 已按压缩方式处理后的实际写入数据
  payload : Bytes
  uncompressed_size : Int
  mut local_offset : Int
  // 是否改用数据描述符（本地头尺寸字段留零，数据后追加描述符）
  descriptor : Bool
} derive(@debug.Debug)

///|
/// ZIP 写入器。
pub struct ZipWriter {
  entries : Array[ZipEntry]
  mut use_descriptors : Bool
} derive(@debug.Debug)

///|
/// 构造空的 ZIP 写入器，默认不使用数据描述符。
pub fn ZipWriter::new() -> ZipWriter {
  { entries: [], use_descriptors: false, }
}

///|
/// 设置是否为非 `mimetype` 条目启用数据描述符。
///
/// 数据描述符允许在本地文件头中省略尺寸与校验值、改由数据后置声明，
/// 适用于无法预先得知尺寸的流式场景。本写入器逐条目缓冲、尺寸已知，
/// 故默认关闭；仅在需要模拟流式布局时开启。
pub fn ZipWriter::set_use_descriptors(
  self : ZipWriter,
  use_descriptors : Bool,
) -> Unit {
  self.use_descriptors = use_descriptors
}

///|
/// 已登记的条目数量。
pub fn ZipWriter::entry_count(self : ZipWriter) -> Int {
  self.entries.length()
}

///|
/// 以指定压缩方式登记一个条目。
///
/// `Deflated` 时若压缩结果未变小则自动退回 `Stored`，避免无谓膨胀。
pub fn ZipWriter::add(
  self : ZipWriter,
  name : String,
  data : Bytes,
  compression : ZipMethod,
) -> Unit {
  let (payload, actual) = match compression {
    Stored => (data, Stored)
    Deflated => {
      let packed = deflate(data)
      if packed.length() < data.length() {
        (packed, Deflated)
      } else {
        (data, Stored)
      }
    }
  }
  self.entries.push({
    name,
    compression: actual,
    crc: crc32(data),
    payload,
    uncompressed_size: data.length(),
    local_offset: 0,
    // OCF 要求 mimetype 为首条目且布局固定，故不为其启用描述符
    descriptor: self.use_descriptors && name != @spec.ocf_mimetype,
  })
}

///|
/// 以 `Stored` 方式登记条目。
pub fn ZipWriter::add_stored(
  self : ZipWriter,
  name : String,
  data : Bytes,
) -> Unit {
  self.add(name, data, Stored)
}

///|
/// 以 `Deflated` 方式登记条目（压缩无收益时自动退回存储）。
pub fn ZipWriter::add_deflated(
  self : ZipWriter,
  name : String,
  data : Bytes,
) -> Unit {
  self.add(name, data, Deflated)
}

///|
/// 序列化为完整 ZIP 字节流：本地头与数据、中央目录、端记录。
pub fn ZipWriter::finish(self : ZipWriter) -> Bytes {
  let out = Buffer()
  for entry in self.entries {
    entry.local_offset = out.length()
    write_local_header(out, entry)
    out.write_bytes(entry.payload)
    if entry.descriptor {
      write_data_descriptor(out, entry)
    }
  }
  let cd_offset = out.length()
  for entry in self.entries {
    write_central_header(out, entry)
  }
  let cd_size = out.length() - cd_offset
  write_eocd(out, self.entries.length(), cd_size, cd_offset)
  out.to_bytes()
}

// ---------------------------------------------------------------------------
// 内部序列化
// ---------------------------------------------------------------------------

///|
/// 把非负 `Int` 截断为 16 位字段值。
fn as_u16(value : Int) -> UInt16 {
  value.reinterpret_as_uint().to_uint16()
}

///|
/// 压缩方式对应的 ZIP 方法号。
fn method_code(compression : ZipMethod) -> Int {
  match compression {
    Stored => 0
    Deflated => 8
  }
}

///|
/// 通用位标志：置 UTF-8 文件名位（`0x0800`），必要时叠加描述符位（`0x0008`）。
fn flag_bits(entry : ZipEntry) -> Int {
  if entry.descriptor {
    0x0808
  } else {
    0x0800
  }
}

///|
/// 写入本地文件头（含文件名）。
fn write_local_header(out : Buffer, entry : ZipEntry) -> Unit {
  out.write_uint_le(0x04034B50U)
  out.write_uint16_le(as_u16(20)) // 解压所需版本 2.0
  out.write_uint16_le(as_u16(flag_bits(entry)))
  out.write_uint16_le(as_u16(method_code(entry.compression)))
  out.write_uint16_le(dos_time.to_uint16())
  out.write_uint16_le(dos_date.to_uint16())
  if entry.descriptor {
    // 尺寸与校验值改由数据描述符承载
    out.write_uint_le(0U)
    out.write_uint_le(0U)
    out.write_uint_le(0U)
  } else {
    out.write_uint_le(entry.crc)
    out.write_uint_le(entry.payload.length().reinterpret_as_uint())
    out.write_uint_le(entry.uncompressed_size.reinterpret_as_uint())
  }
  out.write_uint16_le(as_u16(@spec.utf8_len(entry.name)))
  out.write_uint16_le(as_u16(0))
  out.write_string_utf8(entry.name)
}

///|
/// 写入数据描述符（带 `0x08074B50` 签名）。
fn write_data_descriptor(out : Buffer, entry : ZipEntry) -> Unit {
  out.write_uint_le(0x08074B50U)
  out.write_uint_le(entry.crc)
  out.write_uint_le(entry.payload.length().reinterpret_as_uint())
  out.write_uint_le(entry.uncompressed_size.reinterpret_as_uint())
}

///|
/// 写入中央目录条目（含文件名）。
fn write_central_header(out : Buffer, entry : ZipEntry) -> Unit {
  out.write_uint_le(0x02014B50U)
  out.write_uint16_le(as_u16(20)) // version made by
  out.write_uint16_le(as_u16(20)) // version needed
  out.write_uint16_le(as_u16(flag_bits(entry)))
  out.write_uint16_le(as_u16(method_code(entry.compression)))
  out.write_uint16_le(dos_time.to_uint16())
  out.write_uint16_le(dos_date.to_uint16())
  out.write_uint_le(entry.crc)
  out.write_uint_le(entry.payload.length().reinterpret_as_uint())
  out.write_uint_le(entry.uncompressed_size.reinterpret_as_uint())
  out.write_uint16_le(as_u16(@spec.utf8_len(entry.name)))
  out.write_uint16_le(as_u16(0)) // extra 长度
  out.write_uint16_le(as_u16(0)) // 注释长度
  out.write_uint16_le(as_u16(0)) // 起始磁盘号
  out.write_uint16_le(as_u16(0)) // 内部属性
  out.write_uint_le(0U) // 外部属性
  out.write_uint_le(entry.local_offset.reinterpret_as_uint())
  out.write_string_utf8(entry.name)
}

///|
/// 写入端记录（EOCD）。
fn write_eocd(
  out : Buffer,
  count : Int,
  cd_size : Int,
  cd_offset : Int,
) -> Unit {
  out.write_uint_le(0x06054B50U)
  out.write_uint16_le(as_u16(0)) // 当前磁盘号
  out.write_uint16_le(as_u16(0)) // 中央目录起始磁盘号
  out.write_uint16_le(as_u16(count)) // 本磁盘条目数
  out.write_uint16_le(as_u16(count)) // 条目总数
  out.write_uint_le(cd_size.reinterpret_as_uint())
  out.write_uint_le(cd_offset.reinterpret_as_uint())
  out.write_uint16_le(as_u16(0)) // 注释长度
}
