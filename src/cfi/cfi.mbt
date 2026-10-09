///|
/// EPUB CFI（Canonical Fragment Identifier）定位（S5）。
///
/// 支持 CFI 的构造、序列化与解析。CFI 由若干「段」组成，段内以 `/` 分隔
/// 若干「步」；`!` 表示跨文档间接引用（如从导航文档进入章内正文）；末步
/// 可携带字符偏移 `:n`；步可携带元素 ID 断言 `[id]`。例如：
/// `epubcfi(/6/4[chap01]!/4[body01]/10/2:5)`。

///|
/// CFI 单步：子节点序号（从 1 起）与可选的 ID 断言。
pub struct CfiStep {
  index : Int
  id : String?
} derive(Eq, @debug.Debug)

///|
/// 构造 CFI 步。
pub fn CfiStep::new(index : Int, id? : String) -> CfiStep {
  { index, id, }
}

///|
/// EPUB CFI：由若干段组成，每段含一步或多步；末尾可选字符偏移。
pub struct Cfi {
  segments : Array[Array[CfiStep]]
  mut offset : Int?
} derive(Eq, @debug.Debug)

///|
/// 构造空 CFI（初始含一段空路径）。
pub fn Cfi::new() -> Cfi {
  { segments: [[]], offset: None, }
}

///|
/// 在当前段末尾追加一步。
pub fn Cfi::push(self : Cfi, index : Int, id? : String) -> Unit {
  self.segments[self.segments.length() - 1].push({ index, id, })
}

///|
/// 开始新的一段（`!` 间接引用），用于跨文档定位。
pub fn Cfi::indirect(self : Cfi) -> Unit {
  self.segments.push([])
}

///|
/// 设置末步的字符偏移。
pub fn Cfi::set_offset(self : Cfi, offset : Int) -> Unit {
  self.offset = Some(offset)
}

///|
/// 段数。
pub fn Cfi::segment_count(self : Cfi) -> Int {
  self.segments.length()
}

///|
/// 步总数（跨段累计）。
pub fn Cfi::step_count(self : Cfi) -> Int {
  let mut n = 0
  for segment in self.segments {
    n += segment.length()
  }
  n
}

///|
/// 末段的最后一步；路径为空时返回 `None`。
pub fn Cfi::last_step(self : Cfi) -> CfiStep? {
  let segment = self.segments[self.segments.length() - 1]
  if segment.is_empty() {
    None
  } else {
    Some(segment[segment.length() - 1])
  }
}

///|
/// 序列化为 CFI 字符串。
pub fn Cfi::render(self : Cfi) -> String {
  let out : Array[Char] = []
  out.push_iter("epubcfi(".iter())
  let mut first = true
  for segment in self.segments {
    if !first {
      out.push('!')
    }
    first = false
    for step in segment {
      out.push('/')
      push_int(out, step.index)
      match step.id {
        Some(id) => {
          out.push('[')
          out.push_iter(id.iter())
          out.push(']')
        }
        None => ()
      }
    }
  }
  match self.offset {
    Some(offset) => {
      out.push(':')
      push_int(out, offset)
    }
    None => ()
  }
  out.push(')')
  String::from_array(out)
}

// ---------------------------------------------------------------------------
// 解析
// ---------------------------------------------------------------------------

///|
/// 解析出的单步：步本身与其可选的字符偏移。
priv struct ParsedStep {
  step : CfiStep
  offset : Int?
}

///|
/// 判断字符是否为 ASCII 数字。
fn is_ascii_digit(c : Char) -> Bool {
  let v = c.to_int()
  v >= 48 && v <= 57
}

///|
/// 写入十进制整数。
fn push_int(out : Array[Char], value : Int) -> Unit {
  if value == 0 {
    out.push('0')
    return
  }
  let negative = value < 0
  let mut v = if negative { -value } else { value }
  let digits : Array[Char] = []
  while v > 0 {
    digits.push(Int::unsafe_to_char(48 + v % 10))
    v = v / 10
  }
  if negative {
    out.push('-')
  }
  let mut i = digits.length()
  while i > 0 {
    i -= 1
    out.push(digits[i])
  }
}

///|
/// 解析单个 CFI 步；`allow_offset` 表示允许出现字符偏移。
///
/// 步形如 `序号`、`序号[id]` 或 `序号[id]:偏移`，序号须为正整数。
fn parse_step(piece : String, allow_offset : Bool) -> ParsedStep? {
  let chars = piece.to_array()
  let n = chars.length()
  let mut i = 0
  let mut index = 0
  let mut digits = 0
  while i < n && is_ascii_digit(chars[i]) {
    index = index * 10 + (chars[i].to_int() - 48)
    digits += 1
    i += 1
  }
  if digits == 0 || index == 0 {
    return None
  }
  let mut id : String? = None
  if i < n && chars[i] == '[' {
    let buf : Array[Char] = []
    i += 1
    while i < n && chars[i] != ']' {
      buf.push(chars[i])
      i += 1
    }
    if i >= n || buf.is_empty() {
      return None
    }
    i += 1
    id = Some(String::from_array(buf))
  }
  let mut offset : Int? = None
  if i < n && chars[i] == ':' {
    if !allow_offset {
      return None
    }
    i += 1
    let mut value = 0
    let mut od = 0
    while i < n && is_ascii_digit(chars[i]) {
      value = value * 10 + (chars[i].to_int() - 48)
      od += 1
      i += 1
    }
    if od == 0 {
      return None
    }
    offset = Some(value)
  }
  if i != n {
    return None
  }
  Some({ step: { index, id, }, offset, })
}

///|
/// 去掉 `epubcfi(` 与 `)` 包裹，返回内部路径；格式不符时返回 `None`。
fn cfi_inner(text : String) -> String? {
  if !text.has_prefix("epubcfi(") || !text.has_suffix(")") {
    return None
  }
  let chars = text.to_array()
  let n = chars.length()
  if n < 11 {
    return None
  }
  let out : Array[Char] = []
  let end = n - 1
  for i in 8..<end {
    out.push(chars[i])
  }
  Some(String::from_array(out))
}

///|
/// 解析 CFI 字符串；格式非法时返回 `None`。
///
/// 要求每段以 `/` 开头、步序号为正整数、ID 断言非空、字符偏移仅出现在
/// 整体末步。解析与 `Cfi::render` 互逆。
pub fn parse_cfi(text : String) -> Cfi? {
  let inner = match cfi_inner(text) {
    Some(s) => s
    None => return None
  }
  let parts : Array[String] = []
  for part in inner.split("!") {
    parts.push(part.to_owned())
  }
  let segments : Array[Array[CfiStep]] = []
  let mut offset : Int? = None
  let part_count = parts.length()
  for pi in 0..<part_count {
    let pieces : Array[String] = []
    for piece in parts[pi].split("/") {
      pieces.push(piece.to_owned())
    }
    let piece_count = pieces.length()
    if piece_count < 2 || !pieces[0].is_empty() {
      return None
    }
    let segment : Array[CfiStep] = []
    for k in 1..<piece_count {
      let is_last = pi == part_count - 1 && k == piece_count - 1
      let parsed = match parse_step(pieces[k], is_last) {
        Some(p) => p
        None => return None
      }
      offset = parsed.offset
      segment.push(parsed.step)
    }
    segments.push(segment)
  }
  Some({ segments, offset, })
}
