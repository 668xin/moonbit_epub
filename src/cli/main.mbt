///|
/// Moon EPUB 命令行工具入口（S8）。
///
/// 子命令：build 生成 EPUB / check 校验结构 / inspect 打印结构树。

///|
/// 打印顶层用法说明。
fn print_usage() -> Unit {
  println("moon-epub — EPUB 3 电子书生成引擎")
  println("")
  println("用法：moon-epub <command> [options]")
  println("")
  println("命令：")
  println("  build    从描述文件生成 EPUB")
  println("  check    校验 EPUB 的结构")
  println("  inspect  打印书籍结构树")
  println("  help     显示本帮助")
}

///|
/// 从进程参数中提取子命令。
///
/// js 后端下 `@env.args()` 的首个元素是脚本路径，统一跳过。
fn command_of(args : Array[String]) -> String {
  let mut i = 1
  if args.length() >= 2 && args[1].has_suffix(".js") {
    i = 2
  }
  if args.length() > i {
    args[i]
  } else {
    ""
  }
}

///|
/// 程序入口。
fn main {
  let cmd = command_of(@env.args())
  match cmd {
    "" | "help" | "--help" | "-h" => print_usage()
    "build" => println("build: 尚未实现（计划于 S8 阶段完成）")
    "check" => println("check: 尚未实现（计划于 S7 阶段完成）")
    "inspect" => println("inspect: 尚未实现（计划于 S8 阶段完成）")
    _ => {
      println("未知命令：" + cmd)
      println("")
      print_usage()
    }
  }
}
