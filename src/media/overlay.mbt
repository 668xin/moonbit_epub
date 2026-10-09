///|
/// Media Overlays（S6）。
///
/// 生成 SMIL（Synchronized Multimedia Integration Language）文档，
/// 把音频片段与内容文档中的文本节点关联，实现「朗读同步」（read-aloud）：
/// 每个 `par` 描述一段文本与其对应音频片段的起止时刻。
///
/// 输出为 `String`，不做文件写入；文档保存与清单登记由上层打包负责。

// ---------------------------------------------------------------------------
// 音频片段
// ---------------------------------------------------------------------------

///|
/// 音频片段：一个音频资源上的时间区间。
pub struct AudioClip {
  // 音频资源在容器内的相对路径
  src : String
  // 起点时钟值，如 `0:00:00.000`
  clip_begin : String
  // 终点时钟值
  clip_end : String
} derive(Eq, @debug.Debug)

///|
/// 以时钟值字符串构造音频片段。
pub fn AudioClip::new(
  src : String,
  clip_begin : String,
  clip_end : String,
) -> AudioClip {
  { src, clip_begin, clip_end, }
}

///|
/// 以毫秒构造音频片段，时钟值由 `format_clock_ms` 生成。
pub fn AudioClip::from_millis(
  src : String,
  begin_ms : Int,
  end_ms : Int,
) -> AudioClip {
  {
    src,
    clip_begin: format_clock_ms(begin_ms),
    clip_end: format_clock_ms(end_ms),
  }
}

// ---------------------------------------------------------------------------
// 文本-音频对与序列
// ---------------------------------------------------------------------------

///|
/// 文本-音频对：一个 `par`，把一段文本节点与其音频片段绑定。
pub struct Par {
  // `par` 元素 id
  id : String
  // 文本节点定位，形如 `text/ch1.xhtml#p-1`
  text_src : String
  // 对应音频片段
  audio : AudioClip
} derive(Eq, @debug.Debug)

///|
/// 构造文本-音频对。
pub fn Par::new(id : String, text_src : String, audio : AudioClip) -> Par {
  { id, text_src, audio, }
}

///|
/// 序列：一组有序的 `par`，整体对应一个内容文档。
pub struct Seq {
  // `seq` 元素 id
  id : String
  // 对应内容文档，形如 `text/ch1.xhtml`，写入 `epub:textref`
  textref : String
  // 可选语义类型，写入 `epub:type`
  epub_type : String?
  pars : Array[Par]
} derive(Eq, @debug.Debug)

///|
/// 构造序列。
pub fn Seq::new(id : String, textref : String, epub_type? : String) -> Seq {
  { id, textref, epub_type, pars: [], }
}

///|
/// 追加一个文本-音频对。
pub fn Seq::add_par(self : Seq, par : Par) -> Unit {
  self.pars.push(par)
}

///|
/// 序列中文本-音频对的数量。
pub fn Seq::par_count(self : Seq) -> Int {
  self.pars.length()
}

// ---------------------------------------------------------------------------
// 覆盖文档与选项
// ---------------------------------------------------------------------------

///|
/// Media Overlay 文档：一组序列的集合。
pub struct Overlay {
  seqs : Array[Seq]
} derive(Eq, @debug.Debug)

///|
/// 构造空的覆盖文档。
pub fn Overlay::new() -> Overlay {
  { seqs: [], }
}

///|
/// 追加一个序列。
pub fn Overlay::add_seq(self : Overlay, seq : Seq) -> Unit {
  self.seqs.push(seq)
}

///|
/// 序列数量。
pub fn Overlay::seq_count(self : Overlay) -> Int {
  self.seqs.length()
}

///|
/// 是否未包含任何序列。
pub fn Overlay::is_empty(self : Overlay) -> Bool {
  self.seqs.is_empty()
}

///|
/// SMIL 文档生成选项。
pub struct SmilOptions {
  // 文档语言，写入根元素 `xml:lang`
  mut language : String?
} derive(@debug.Debug)

///|
/// 构造选项：不声明语言。
pub fn SmilOptions::new() -> SmilOptions {
  { language: None, }
}

///|
/// 设置文档语言。
pub fn SmilOptions::set_language(self : SmilOptions, language : String) -> Unit {
  self.language = Some(language)
}

// ---------------------------------------------------------------------------
// 时钟值格式化
// ---------------------------------------------------------------------------

///|
/// 以零填充左对齐 `value` 到 `width` 位。
fn pad(value : Int, width : Int) -> String {
  let digits = value.to_string()
  let out : Array[Char] = []
  let missing = width - digits.length()
  for _ in 0..<missing {
    out.push('0')
  }
  out.push_iter(digits.iter())
  String::from_array(out)
}

///|
/// 把毫秒格式化为 SMIL 完整时钟值 `h:mm:ss.mmm`。
///
/// 小时位不补零，分钟与秒补足两位，毫秒补足三位。
pub fn format_clock_ms(ms : Int) -> String {
  let hours = ms / 3_600_000
  let rem = ms % 3_600_000
  let minutes = rem / 60_000
  let rem2 = rem % 60_000
  let seconds = rem2 / 1000
  let millis = rem2 % 1000
  let out : Array[Char] = []
  out.push_iter(hours.to_string().iter())
  out.push(':')
  out.push_iter(pad(minutes, 2).iter())
  out.push(':')
  out.push_iter(pad(seconds, 2).iter())
  out.push('.')
  out.push_iter(pad(millis, 3).iter())
  String::from_array(out)
}

// ---------------------------------------------------------------------------
// 序列化
// ---------------------------------------------------------------------------

///|
/// 写入换行与按 `depth` 计算的缩进（每层两个空格）。
///
/// 缓冲为空时不写换行，避免片段渲染产生前导空行。
fn write_indent(out : Array[Char], depth : Int) -> Unit {
  if out.length() > 0 {
    out.push('\n')
  }
  let n = depth * 2
  for _ in 0..<n {
    out.push(' ')
  }
}

///|
/// 写入 `name="value"` 形式的属性（值经属性转义）。
fn write_attr(out : Array[Char], name : String, value : String) -> Unit {
  out.push(' ')
  out.push_iter(name.iter())
  out.push_iter("=\"".iter())
  out.push_iter(@spec.xml_escape_attr(value).iter())
  out.push('"')
}

///|
/// 写入单个 `par`：`text` 指向文本节点，`audio` 给出音频片段。
fn write_par(out : Array[Char], par : Par, depth : Int) -> Unit {
  write_indent(out, depth)
  out.push_iter("<par".iter())
  write_attr(out, "id", par.id)
  out.push('>')
  write_indent(out, depth + 1)
  out.push_iter("<text".iter())
  write_attr(out, "src", par.text_src)
  out.push_iter("/>".iter())
  write_indent(out, depth + 1)
  out.push_iter("<audio".iter())
  write_attr(out, "src", par.audio.src)
  write_attr(out, @spec.attr_clip_begin, par.audio.clip_begin)
  write_attr(out, @spec.attr_clip_end, par.audio.clip_end)
  out.push_iter("/>".iter())
  write_indent(out, depth)
  out.push_iter("</par>".iter())
}

///|
/// 写入单个 `seq` 及其全部 `par`。
fn write_seq(out : Array[Char], seq : Seq, depth : Int) -> Unit {
  write_indent(out, depth)
  out.push_iter("<seq".iter())
  write_attr(out, "id", seq.id)
  write_attr(out, @spec.epub_textref, seq.textref)
  match seq.epub_type {
    Some(epub_type) => write_attr(out, @spec.attr_epub_type, epub_type)
    None => ()
  }
  out.push('>')
  for par in seq.pars {
    write_par(out, par, depth + 1)
  }
  write_indent(out, depth)
  out.push_iter("</seq>".iter())
}

///|
/// 渲染完整的 SMIL 覆盖文档。
pub fn render_smil(overlay : Overlay, options : SmilOptions) -> String {
  let out : Array[Char] = []
  out.push_iter("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n".iter())
  out.push_iter("<smil".iter())
  write_attr(out, "xmlns", @spec.ns_smil)
  write_attr(out, "xmlns:epub", @spec.ns_epub)
  match options.language {
    Some(language) => write_attr(out, "xml:lang", language)
    None => ()
  }
  write_attr(out, "version", @spec.smil_version)
  out.push('>')
  write_indent(out, 1)
  out.push_iter("<body>".iter())
  for seq in overlay.seqs {
    write_seq(out, seq, 2)
  }
  write_indent(out, 1)
  out.push_iter("</body>".iter())
  write_indent(out, 0)
  out.push_iter("</smil>".iter())
  String::from_array(out)
}
