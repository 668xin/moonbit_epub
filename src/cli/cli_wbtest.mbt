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

///|
test "argv_of: 非 js 第二项不跳过" {
  assert_eq(argv_of(["moon-epub", "build", "minimal"]), ["build", "minimal"])
  assert_eq(argv_of(["prog", "check"]), ["check"])
  assert_eq(argv_of(["only"]).length(), 0)
}

///|
test "argv_of: 第二项 .js 结尾判定" {
  assert_eq(argv_of(["node", "main.js", "build"]), ["build"])
  assert_eq(argv_of(["node", "tool.js"]).length(), 0)
  assert_eq(argv_of(["node", "tool.wasm", "build"]), ["tool.wasm", "build"])
}

///|
test "first_positional: 全选项或空返回空串" {
  assert_eq(first_positional(["--json", "--verbose"]), "")
  assert_eq(first_positional([]), "")
  assert_eq(first_positional(["-x"]), "")
}

///|
test "option_value: 取值与末尾缺值" {
  assert_eq(option_value(["--format", "hex"], "--format"), Some("hex"))
  assert_eq(option_value(["--format"], "--format"), None)
  assert_eq(option_value(["a", "--f", "--g"], "--f"), Some("--g"))
  assert_eq(option_value([], "--format"), None)
}

///|
test "has_flag: 精确匹配与空数组" {
  assert_false(has_flag([], "--json"))
  assert_true(has_flag(["a", "--json", "b"], "--json"))
  assert_false(has_flag(["a", "--jsonx"], "--json"))
}

///|
test "render_inspect: styled 资源与清单计数" {
  let text = render_inspect(@examples.styled())
  assert_true(text.contains("书籍：样式示例"))
  assert_true(text.contains("章节（1）："))
  assert_true(text.contains("• 样式演示 [ch1]"))
  assert_true(text.contains("资源（2）："))
  assert_true(text.contains("images/cover.png  image/png"))
  assert_true(text.contains("清单条目：5"))
  assert_true(text.contains("阅读顺序条目：1"))
}

///|
test "render_inspect: multi 嵌套章节缩进" {
  let text = render_inspect(@examples.multi_chapter())
  assert_true(text.contains("书籍：多章节示例"))
  assert_true(text.contains("章节（4）："))
  assert_true(text.contains("• 正文 [ch2]"))
  assert_true(text.contains("    • 小节 [ch2-1]"))
  assert_true(text.contains("清单条目：7"))
}

///|
test "join_names: 无尾随或前导分隔符" {
  let s = join_names()
  assert_eq(s, "minimal、multi-chapter、styled")
  assert_false(s.has_suffix("、"))
  assert_false(s.has_prefix("、"))
}
