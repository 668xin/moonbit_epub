///|
/// Moonbit_EPUB 命令行工具入口（S8）。
///
/// 子命令：
/// - `build <example> [--format base64|hex]` 生成 EPUB 并以文本编码输出；
/// - `check <example> [--json]` 校验结构并输出诊断报告；
/// - `inspect <example>` 打印书籍结构树。
///
/// 核心库不依赖文件 IO，故 `build` 把二进制以 Base64（默认）或十六进制
/// 输出到标准输出，由 shell 重定向并解码落盘，例如：
/// `moon-epub build minimal | base64 -d > minimal.epub`。

// ---------------------------------------------------------------------------
// 参数解析
// ---------------------------------------------------------------------------

///|
/// 去除程序名与 js 脚本路径，返回有效参数。
///
/// js 后端下 `@env.args()` 形如 `["node", "main.js", ...]`，需跳过前两项；
/// 其他后端仅跳过可执行文件名。
fn argv_of(args : Array[String]) -> Array[String] {
  let mut i = 1
  if args.length() >= 2 && args[1].has_suffix(".js") {
    i = 2
  }
  let out : Array[String] = []
  let mut j = i
  while j < args.length() {
    out.push(args[j])
    j += 1
  }
  out
}

///|
/// 首个不以 `-` 开头的参数（即位置参数）。
fn first_positional(argv : Array[String]) -> String {
  let mut i = 1
  while i < argv.length() {
    if !argv[i].has_prefix("-") {
      return argv[i]
    }
    i += 1
  }
  ""
}

///|
/// 是否存在指定标志。
fn has_flag(argv : Array[String], name : String) -> Bool {
  for arg in argv {
    if arg == name {
      return true
    }
  }
  false
}

///|
/// 取 `--name value` 形式的选项值。
fn option_value(argv : Array[String], name : String) -> String? {
  let mut i = 0
  while i + 1 < argv.length() {
    if argv[i] == name {
      return Some(argv[i + 1])
    }
    i += 1
  }
  None
}

// ---------------------------------------------------------------------------
// 用法
// ---------------------------------------------------------------------------

///|
/// 打印顶层用法说明。
fn print_usage() -> Unit {
  println("moon-epub — EPUB 3 电子书生成引擎")
  println("")
  println("用法：moon-epub <command> [arguments]")
  println("")
  println("命令：")
  println(
    "  build <example> [--format base64|hex]  生成 EPUB 并编码输出",
  )
  println(
    "  check <example> [--json]               校验结构并输出诊断",
  )
  println("  inspect <example>                      打印书籍结构树")
  println("  examples                               列出内置示例")
  println("  help                                   显示本帮助")
  println("")
  println("示例：")
  println("  moon-epub build minimal | base64 -d > minimal.epub")
  println("  moon-epub check multi-chapter --json")
  println("  moon-epub inspect styled")
}

// ---------------------------------------------------------------------------
// 结构树
// ---------------------------------------------------------------------------

///|
/// 打印书籍结构树。
fn render_inspect(book : @model.Book) -> String {
  let out : Array[Char] = []
  let metadata = book.metadata
  out.push_iter("书籍：".iter())
  out.push_iter(metadata.title.iter())
  out.push('\n')
  out.push_iter("语言：".iter())
  out.push_iter(metadata.language.iter())
  out.push('\n')
  out.push_iter("标识符：".iter())
  out.push_iter(metadata.identifier.iter())
  out.push('\n')
  out.push_iter("章节（".iter())
  out.push_iter(book.chapter_count().to_string().iter())
  out.push_iter("）：".iter())
  out.push('\n')
  @model.walk_chapters(book.chapters, (depth, chapter) => {
    let mut i = 0
    while i <= depth {
      out.push_iter("  ".iter())
      i += 1
    }
    out.push_iter("• ".iter())
    out.push_iter(chapter.title.iter())
    out.push_iter(" [".iter())
    out.push_iter(chapter.id.iter())
    out.push_iter("]".iter())
    out.push('\n')
  })
  out.push_iter("资源（".iter())
  out.push_iter(book.resources.length().to_string().iter())
  out.push_iter("）：".iter())
  out.push('\n')
  for resource in book.resources {
    out.push_iter("  ".iter())
    out.push_iter(resource.href.iter())
    out.push_iter("  ".iter())
    out.push_iter(resource.media_type.iter())
    out.push_iter("  ".iter())
    out.push_iter(resource.data.length().to_string().iter())
    out.push_iter(" B".iter())
    out.push('\n')
  }
  out.push_iter("清单条目：".iter())
  out.push_iter(book.manifest.length().to_string().iter())
  out.push('\n')
  out.push_iter("阅读顺序条目：".iter())
  out.push_iter(book.spine.items.length().to_string().iter())
  out.push('\n')
  String::from_array(out)
}

// ---------------------------------------------------------------------------
// 子命令
// ---------------------------------------------------------------------------

///|
/// 未知示例的提示。
fn unknown_example(name : String) -> Unit {
  println("未知示例：" + name)
  println("可用示例：" + join_names())
}

///|
/// 以顿号连接全部示例名称。
fn join_names() -> String {
  let out : Array[Char] = []
  for i, name in @examples.names() {
    if i > 0 {
      out.push_iter("、".iter())
    }
    out.push_iter(name.iter())
  }
  String::from_array(out)
}

///|
/// `build`：生成 EPUB 并按指定编码输出。
fn run_build(argv : Array[String]) -> Unit {
  let name = first_positional(argv)
  match @examples.by_name(name) {
    None => unknown_example(name)
    Some(book) => {
      let options = @ocf.PackageOptions::new()
      // 为样式表资源生成指向内容文档的相对链接
      for resource in book.resources {
        if resource.media_type == @spec.mt_css {
          options.add_stylesheet("../" + resource.href)
        }
      }
      let epub = @ocf.package_book(book, options)
      let format = match option_value(argv, "--format") {
        Some(value) => value
        None => "base64"
      }
      if format == "hex" {
        println(@hex.encode(epub))
      } else {
        println(@base64.encode(epub))
      }
    }
  }
}

///|
/// `check`：校验结构并输出诊断报告。
fn run_check(argv : Array[String]) -> Unit {
  let name = first_positional(argv)
  match @examples.by_name(name) {
    None => unknown_example(name)
    Some(book) => {
      let report = @validate.validate_book(book)
      if has_flag(argv, "--json") {
        println(@validate.render_json(report))
      } else {
        println(@validate.render_text(report))
      }
    }
  }
}

///|
/// `inspect`：打印书籍结构树。
fn run_inspect(argv : Array[String]) -> Unit {
  let name = first_positional(argv)
  match @examples.by_name(name) {
    None => unknown_example(name)
    Some(book) => println(render_inspect(book))
  }
}

///|
/// `examples`：列出内置示例。
fn run_examples() -> Unit {
  println("内置示例：")
  for name in @examples.names() {
    println("  " + name)
  }
}

// ---------------------------------------------------------------------------
// 入口
// ---------------------------------------------------------------------------

///|
/// 程序入口。
fn main {
  let argv = argv_of(@env.args())
  let command = if argv.length() > 0 { argv[0] } else { "" }
  match command {
    "" | "help" | "--help" | "-h" => print_usage()
    "build" => run_build(argv)
    "check" => run_check(argv)
    "inspect" => run_inspect(argv)
    "examples" | "list" => run_examples()
    _ => {
      println("未知命令：" + command)
      println("")
      print_usage()
    }
  }
}
