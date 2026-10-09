///|
/// 校验报告的渲染（S7）。
///
/// 把 `Report` 输出为两种形态：供人阅读的文本行式报告，以及供程序解析的
/// JSON 机器可读报告。两者均只依赖诊断数据，不做任何 IO。

// ---------------------------------------------------------------------------
// 文本报告
// ---------------------------------------------------------------------------

///|
/// 一行式汇总：错误 / 警告 / 提示数量。
pub fn Report::summary(self : Report) -> String {
  let out : Array[Char] = []
  out.push_iter("报告：".iter())
  out.push_iter(self.error_count().to_string().iter())
  out.push_iter(" 个错误，".iter())
  out.push_iter(self.warning_count().to_string().iter())
  out.push_iter(" 个警告，".iter())
  out.push_iter(self.info_count().to_string().iter())
  out.push_iter(" 个提示".iter())
  String::from_array(out)
}

///|
/// 渲染文本报告：每条诊断一行 `级别 代码 定位: 说明`，末尾附汇总行。
///
/// 无诊断时只输出汇总行。
pub fn render_text(report : Report) -> String {
  let out : Array[Char] = []
  for diagnostic in report.diagnostics {
    out.push_iter(diagnostic.severity.label().iter())
    out.push(' ')
    out.push_iter(diagnostic.code.iter())
    out.push(' ')
    out.push_iter(diagnostic.location.iter())
    out.push_iter(": ".iter())
    out.push_iter(diagnostic.message.iter())
    out.push('\n')
  }
  out.push_iter(report.summary().iter())
  String::from_array(out)
}

// ---------------------------------------------------------------------------
// JSON 报告
// ---------------------------------------------------------------------------

///|
/// 转义 JSON 字符串中的特殊字符。
fn json_escape(text : String) -> String {
  let out : Array[Char] = []
  for c in text {
    match c {
      '"' => out.push_iter("\\\"".iter())
      '\\' => out.push_iter("\\\\".iter())
      '\n' => out.push_iter("\\n".iter())
      '\r' => out.push_iter("\\r".iter())
      '\t' => out.push_iter("\\t".iter())
      _ => out.push(c)
    }
  }
  String::from_array(out)
}

///|
/// 写入 `"key": "value"` 形式的 JSON 字符串字段。
fn write_json_string(out : Array[Char], key : String, value : String) -> Unit {
  out.push('"')
  out.push_iter(key.iter())
  out.push_iter("\": \"".iter())
  out.push_iter(json_escape(value).iter())
  out.push('"')
}

///|
/// 渲染 JSON 机器可读报告。
///
/// 结构：`{ "ok", "errors", "warnings", "infos", "diagnostics": [ ... ] }`，
/// 其中每个诊断含 `severity` / `code` / `location` / `message` 字段。
pub fn render_json(report : Report) -> String {
  let out : Array[Char] = []
  out.push('{')
  out.push_iter("\n  \"ok\": ".iter())
  let ok_text = if report.is_ok() { "true" } else { "false" }
  out.push_iter(ok_text.iter())
  out.push_iter(",\n  \"errors\": ".iter())
  out.push_iter(report.error_count().to_string().iter())
  out.push_iter(",\n  \"warnings\": ".iter())
  out.push_iter(report.warning_count().to_string().iter())
  out.push_iter(",\n  \"infos\": ".iter())
  out.push_iter(report.info_count().to_string().iter())
  out.push_iter(",\n  \"diagnostics\": [".iter())
  for i, diagnostic in report.diagnostics {
    if i > 0 {
      out.push(',')
    }
    out.push_iter("\n    {".iter())
    write_json_string(out, "severity", diagnostic.severity.label())
    out.push_iter(", ".iter())
    write_json_string(out, "code", diagnostic.code)
    out.push_iter(", ".iter())
    write_json_string(out, "location", diagnostic.location)
    out.push_iter(", ".iter())
    write_json_string(out, "message", diagnostic.message)
    out.push('}')
  }
  if report.diagnostics.length() > 0 {
    out.push('\n')
    out.push_iter("  ".iter())
  }
  out.push_iter("]\n}".iter())
  String::from_array(out)
}
