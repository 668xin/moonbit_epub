///|
/// 校验诊断与报告（S7）。
///
/// 定义诊断级别、单条诊断与诊断报告，供规则集（`rules.mbt`）填充，
/// 并由报告渲染层（`report.mbt`）输出为文本或机器可读格式。

///|
/// 诊断级别。
///
/// - `Error`：违反 EPUB 规范必需项，产物可能无法被阅读器打开；
/// - `Warning`：规范建议或潜在不一致，产物仍可使用；
/// - `Info`：提示性信息，不表示问题。
pub enum Severity {
  /// 错误：违反必需项。
  Error
  /// 警告：潜在问题或规范建议。
  Warning
  /// 提示：信息性说明。
  Info
} derive(Eq, @debug.Debug)

///|
/// 级别的小写标签，用于文本与 JSON 输出。
pub fn Severity::label(self : Severity) -> String {
  match self {
    Error => "error"
    Warning => "warning"
    Info => "info"
  }
}

///|
/// 单条诊断：级别、规则代码、定位与说明。
pub struct Diagnostic {
  severity : Severity
  // 稳定的规则代码，如 `OPF-002`
  code : String
  // 定位，如 `package/manifest` 或 `resource#images/cover.png`
  location : String
  // 人类可读说明
  message : String
} derive(Eq, @debug.Debug)

///|
/// 构造诊断。
pub fn Diagnostic::new(
  severity : Severity,
  code : String,
  location : String,
  message : String,
) -> Diagnostic {
  { severity, code, location, message, }
}

///|
/// 校验报告：诊断集合，按发生顺序保存。
pub struct Report {
  diagnostics : Array[Diagnostic]
} derive(@debug.Debug)

///|
/// 构造空报告。
pub fn Report::new() -> Report {
  { diagnostics: [], }
}

///|
/// 追加一条诊断。
pub fn Report::add(
  self : Report,
  severity : Severity,
  code : String,
  location : String,
  message : String,
) -> Unit {
  self.diagnostics.push(Diagnostic::new(severity, code, location, message))
}

///|
/// 追加一条错误级诊断。
pub fn Report::error(
  self : Report,
  code : String,
  location : String,
  message : String,
) -> Unit {
  self.add(Error, code, location, message)
}

///|
/// 追加一条警告级诊断。
pub fn Report::warning(
  self : Report,
  code : String,
  location : String,
  message : String,
) -> Unit {
  self.add(Warning, code, location, message)
}

///|
/// 追加一条提示级诊断。
pub fn Report::info(
  self : Report,
  code : String,
  location : String,
  message : String,
) -> Unit {
  self.add(Info, code, location, message)
}

///|
/// 把另一份报告的诊断按序并入本报告。
pub fn Report::merge(self : Report, other : Report) -> Unit {
  for diagnostic in other.diagnostics {
    self.diagnostics.push(diagnostic)
  }
}

///|
/// 诊断总数。
pub fn Report::length(self : Report) -> Int {
  self.diagnostics.length()
}

///|
/// 是否无任何诊断。
pub fn Report::is_empty(self : Report) -> Bool {
  self.diagnostics.is_empty()
}

///|
/// 指定级别的诊断数量。
pub fn Report::count_of(self : Report, severity : Severity) -> Int {
  let mut n = 0
  for diagnostic in self.diagnostics {
    if diagnostic.severity == severity {
      n += 1
    }
  }
  n
}

///|
/// 错误级诊断数量。
pub fn Report::error_count(self : Report) -> Int {
  self.count_of(Error)
}

///|
/// 警告级诊断数量。
pub fn Report::warning_count(self : Report) -> Int {
  self.count_of(Warning)
}

///|
/// 提示级诊断数量。
pub fn Report::info_count(self : Report) -> Int {
  self.count_of(Info)
}

///|
/// 是否含错误级诊断。
pub fn Report::has_errors(self : Report) -> Bool {
  for diagnostic in self.diagnostics {
    if diagnostic.severity == Error {
      return true
    }
  }
  false
}

///|
/// 是否通过校验（无错误级诊断）。
pub fn Report::is_ok(self : Report) -> Bool {
  !self.has_errors()
}
