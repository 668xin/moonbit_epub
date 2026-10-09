///|
/// S8 命令行工具辅助函数的白盒单元测试。
///
/// 主包为可执行程序，这里的测试需访问包内私有的参数解析与渲染辅助函数，
/// 故采用白盒测试（`_wbtest.mbt`）。

///|
test "argv_of: 跳过程序名与 js 脚本路径" {
  assert_eq(argv_of(["node", "main.js", "build", "minimal"]), [
    "build", "minimal",
  ])
  assert_eq(argv_of(["moon-epub", "check"]), ["check"])
  assert_eq(argv_of([]).length(), 0)
}

///|
test "first_positional: 跳过命令与选项后的首个位置参数" {
  assert_eq(first_positional(["build", "minimal"]), "minimal")
  assert_eq(
    first_positional(["inspect", "styled", "--format", "hex"]),
    "styled",
  )
  assert_eq(first_positional(["build", "--format", "hex"]), "hex")
  assert_eq(first_positional(["help"]), "")
}

///|
test "has_flag 与 option_value" {
  let argv = ["build", "minimal", "--format", "hex", "--json"]
  assert_true(has_flag(argv, "--json"))
  assert_false(has_flag(argv, "--verbose"))
  assert_eq(option_value(argv, "--format"), Some("hex"))
  assert_eq(option_value(argv, "--missing"), None)
}

///|
test "render_inspect: 结构树关键字段" {
  let text = render_inspect(@examples.minimal())
  assert_true(text.contains("书籍：最小示例"))
  assert_true(text.contains("语言：zh-CN"))
  assert_true(text.contains("章节（1）："))
  assert_true(text.contains("• 前言 [ch1]"))
  assert_true(text.contains("清单条目：3"))
}

///|
test "join_names: 顿号连接示例名" {
  assert_eq(join_names(), "minimal、multi-chapter、styled")
}
