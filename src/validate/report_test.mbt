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
