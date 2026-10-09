///|
/// S7 报告渲染的单元测试。

///|
/// 构造一份含错误、警告与提示的报告。
fn sample_report() -> Report {
  let report = Report::new()
  report.error("OPF-002", "package/manifest", "清单缺少导航文档")
  report.warning("CHP-004", "chapter#ch1", "章节标题为空")
  report.info("MET-006", "package/metadata", "未声明作者或贡献者")
  report
}

///|
test "Report::summary 汇总计数" {
  let report = sample_report()
  assert_eq(
    report.summary(),
    "报告：1 个错误，1 个警告，1 个提示",
  )
  let empty = Report::new()
  assert_eq(empty.summary(), "报告：0 个错误，0 个警告，0 个提示")
}

///|
test "render_text: 逐行诊断与汇总" {
  let text = render_text(sample_report())
  assert_true(
    text.contains("error OPF-002 package/manifest: 清单缺少导航文档"),
  )
  assert_true(text.contains("warning CHP-004 chapter#ch1: 章节标题为空"))
  assert_true(
    text.contains("info MET-006 package/metadata: 未声明作者或贡献者"),
  )
  assert_true(
    text.has_suffix("报告：1 个错误，1 个警告，1 个提示"),
  )
}

///|
test "render_text: 无诊断仅汇总" {
  let text = render_text(Report::new())
  assert_eq(text, "报告：0 个错误，0 个警告，0 个提示")
}

///|
test "render_json: 通过的报告" {
  let json = render_json(Report::new())
  assert_true(json.contains("\"ok\": true"))
  assert_true(json.contains("\"errors\": 0"))
  assert_true(json.contains("\"diagnostics\": []"))
}

///|
test "render_json: 含诊断的报告" {
  let json = render_json(sample_report())
  assert_true(json.contains("\"ok\": false"))
  assert_true(json.contains("\"errors\": 1"))
  assert_true(json.contains("\"warnings\": 1"))
  assert_true(json.contains("\"infos\": 1"))
  assert_true(
    json.contains(
      "{\"severity\": \"error\", \"code\": \"OPF-002\", \"location\": \"package/manifest\", \"message\": \"清单缺少导航文档\"}",
    ),
  )
}

///|
test "render_json: 转义特殊字符" {
  let report = Report::new()
  report.error("X-001", "loc", "含\"引号\"与\n换行")
  let json = render_json(report)
  assert_true(json.contains("含\\\"引号\\\"与\\n换行"))
}

///|
test "Report: add 各级别计数与判定" {
  let report = Report::new()
  assert_true(report.is_empty())
  assert_true(report.is_ok())
  report.error("E-1", "loc", "e")
  report.warning("W-1", "loc", "w")
  report.warning("W-2", "loc", "w")
  report.info("I-1", "loc", "i")
  assert_eq(report.length(), 4)
  assert_false(report.is_empty())
  assert_eq(report.error_count(), 1)
  assert_eq(report.warning_count(), 2)
  assert_eq(report.info_count(), 1)
  assert_eq(report.count_of(report.diagnostics[0].severity), 1)
  assert_eq(report.diagnostics[0].severity.label(), "error")
  assert_eq(report.diagnostics[1].severity.label(), "warning")
  assert_eq(report.diagnostics[3].severity.label(), "info")
  assert_true(report.has_errors())
  assert_false(report.is_ok())
}

///|
test "Report::merge 追加顺序与计数" {
  let base = Report::new()
  base.error("A", "loc", "a")
  let other = Report::new()
  other.warning("B", "loc", "b")
  other.info("C", "loc", "c")
  base.merge(other)
  assert_eq(base.length(), 3)
  assert_eq(base.diagnostics[0].code, "A")
  assert_eq(base.diagnostics[1].code, "B")
  assert_eq(base.diagnostics[2].code, "C")
  assert_eq(base.error_count(), 1)
  assert_eq(base.warning_count(), 1)
  assert_eq(base.info_count(), 1)
}

///|
test "Report: is_empty 边界" {
  let report = Report::new()
  assert_true(report.is_empty())
  assert_eq(report.length(), 0)
  report.info("I", "loc", "i")
  assert_false(report.is_empty())
  assert_eq(report.length(), 1)
  assert_true(report.is_ok())
}

///|
test "render_text: 多诊断按登记顺序" {
  let report = Report::new()
  report.error("E-1", "l1", "msg1")
  report.warning("W-1", "l2", "msg2")
  assert_eq(
    render_text(report),
    "error E-1 l1: msg1\nwarning W-1 l2: msg2\n报告：1 个错误，1 个警告，0 个提示",
  )
}

///|
test "render_text: 汇总行与 summary 一致" {
  let report = Report::new()
  report.warning("W", "loc", "w")
  assert_true(render_text(report).has_suffix(report.summary()))
}

///|
test "render_json: 多诊断逗号分隔与末尾结构" {
  let report = Report::new()
  report.error("E-1", "l1", "m1")
  report.info("I-1", "l2", "m2")
  let json = render_json(report)
  assert_true(json.contains("\"ok\": false"))
  assert_true(json.contains("\"errors\": 1"))
  assert_true(json.contains("\"infos\": 1"))
  assert_true(json.contains("},\n    {"))
  assert_true(json.has_suffix("]\n}"))
}

///|
test "render_json: 转义反斜杠与空白控制字符" {
  let report = Report::new()
  report.error("X", "loc", "反斜\\杠\t制表\r回车")
  let json = render_json(report)
  assert_true(json.contains("反斜\\\\杠\\t制表\\r回车"))
}
