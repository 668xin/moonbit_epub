///|
/// 基础工具层（S0）。
///
/// 提供与规范无关的纯函数：XML 转义、ID 规范化、UTF-8 长度与路径处理。
/// 这些函数被上层的模型、序列化、打包各层复用，本身不依赖任何其他包。

///|
/// 转义 XML 文本内容中的 `&`、`<`、`>`。
pub fn xml_escape(text : String) -> String {
  let out : Array[Char] = []
  for c in text {
    match c {
      '&' => out.push_iter("&amp;".iter())
      '<' => out.push_iter("&lt;".iter())
      '>' => out.push_iter("&gt;".iter())
      _ => out.push(c)
    }
  }
  String::from_array(out)
}

///|
/// 转义 XML 属性值：在文本转义基础上再处理引号与空白控制字符，
/// 保证属性值无论用单引号还是双引号包裹都能无损还原。
pub fn xml_escape_attr(text : String) -> String {
  let out : Array[Char] = []
  for c in text {
    match c {
      '&' => out.push_iter("&amp;".iter())
      '<' => out.push_iter("&lt;".iter())
      '>' => out.push_iter("&gt;".iter())
      '"' => out.push_iter("&quot;".iter())
      '\'' => out.push_iter("&#39;".iter())
      '\n' => out.push_iter("&#10;".iter())
      '\r' => out.push_iter("&#13;".iter())
      '\t' => out.push_iter("&#9;".iter())
      _ => out.push(c)
    }
  }
  String::from_array(out)
}

///|
/// 计算字符串的 UTF-8 编码字节长度。
///
/// MoonBit 的 `String` 以 UTF-16 存储，`length()` 返回的是代码单元数，
/// 与 EPUB/ZIP 需要的字节长度不一致，故单独实现。
pub fn utf8_len(text : String) -> Int {
  let mut n = 0
  for c in text {
    let cp = c.to_int()
    if cp < 0x80 {
      n += 1
    } else if cp < 0x800 {
      n += 2
    } else if cp < 0x10000 {
      n += 3
    } else {
      n += 4
    }
  }
  n
}

///|
/// 判断字符能否作为 XML ID（近似 NCName）的首字符。
fn is_id_start(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c == '_' || c.to_int() >= 0x80
}

///|
/// 判断字符能否出现在 XML ID（近似 NCName）中。
fn is_id_continue(c : Char) -> Bool {
  is_id_start(c) || c.is_ascii_digit() || c == '-' || c == '.'
}

///|
/// 校验字符串是否为合法的 XML ID（以 NCName 为近似模型）。
pub fn is_valid_id(text : String) -> Bool {
  if text.is_empty() {
    return false
  }
  let chars = text.to_array()
  if !is_id_start(chars[0]) {
    return false
  }
  for i in 1..<chars.length() {
    if !is_id_continue(chars[i]) {
      return false
    }
  }
  true
}

///|
/// 把任意文本规范化为合法且稳定的 XML ID。
///
/// 规则：非法字符折叠为单个 `-`；首字符非法时补 `_`；`-` 不保留在首尾；
/// 结果为空时回退为 `"id"`。规范化是幂等的。
pub fn normalize_id(text : String) -> String {
  let out : Array[Char] = []
  let mut started = false
  let mut pending_sep = false
  for c in text {
    // 首字符位置上的 `-` 视作分隔符丢弃，避免产出以 `-` 开头的 ID。
    if is_id_continue(c) && (started || c != '-') {
      if pending_sep {
        if started {
          out.push('-')
        }
        pending_sep = false
      }
      if !started && !is_id_start(c) {
        out.push('_')
      }
      out.push(c)
      started = true
    } else {
      pending_sep = true
    }
  }
  while out.length() > 0 && out[out.length() - 1] == '-' {
    let _ = out.pop()
  }
  if out.is_empty() {
    "id"
  } else {
    String::from_array(out)
  }
}

///|
/// 拼接两段路径，避免出现重复或缺失的 `/`。
pub fn path_join(dir : String, name : String) -> String {
  if dir.is_empty() {
    return name
  }
  if name.is_empty() {
    return dir
  }
  if dir.has_suffix("/") {
    dir + name
  } else {
    dir + "/" + name
  }
}

///|
/// 规范化路径：合并重复 `/`、解析 `.` 与 `..`、去除末尾 `/`。
///
/// 绝对路径保留开头的 `/`；上溯越过根目录时不再保留 `..`。
pub fn normalize_path(path : String) -> String {
  let absolute = path.has_prefix("/")
  let parts : Array[String] = []
  for seg in path.split("/") {
    if seg.is_empty() || seg == "." {
      continue
    }
    if seg == ".." {
      if parts.length() > 0 && parts[parts.length() - 1] != ".." {
        let _ = parts.pop()
      } else if !absolute {
        parts.push("..")
      }
    } else {
      parts.push(seg.to_owned())
    }
  }
  let out : Array[Char] = []
  if absolute {
    out.push('/')
  }
  for i, part in parts {
    if i > 0 {
      out.push('/')
    }
    out.push_iter(part.iter())
  }
  if out.is_empty() {
    if absolute {
      "/"
    } else {
      "."
    }
  } else {
    String::from_array(out)
  }
}
