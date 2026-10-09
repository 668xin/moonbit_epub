# Moonbit_EPUB

Moonbit_EPUB —— 用 MoonBit 实现的 **EPUB 3 电子书生成引擎**。

从结构化的书籍模型出发，生成符合 W3C EPUB 3.3 与 Open Container Format (OCF) 3.3
规范的 `.epub` 文件：包含 OPF 包文档、导航文档（`nav.xhtml` 与 `toc.ncx`）、
XHTML5 内容文档、样式与资源管理、Media Overlays 朗读同步、OCF/ZIP 容器打包，
以及一个可独立运行的**结构校验器**。

- 仓库（GitHub）：<https://github.com/668xin/moonbit_epub.git>

## 特性

- **纯生成方向**：只做"结构化内容 → `.epub` 字节流"的正向链路，与生态中已有的
  读取/解析类包互补。
- **零外部依赖**：仅依赖 MoonBit 核心库，ZIP 压缩（DEFLATE）与 CRC32 均为自研实现，
  输出与标准 Python `zipfile` 交叉验证兼容。
- **规范对齐**：媒体类型、命名空间、OCF 保留文件名等均以规范常量集中管理。
- **可访问性内建**：提供 schema.org 可访问性元数据（accessMode、accessibilityFeature、
  accessibilityHazard 等）与 WCAG conformance 声明。
- **有声书支持**：生成 EPUB Media Overlays（SMIL 3.0）文档，描述文本与音频的同步。
- **结构校验器**：独立于生成层，依据规范常量对书籍模型给出稳定的诊断代码
  （`MET` / `CHP` / `RES` / `OPF` / `SPN` / `RCH` / `CON`），支持文本与 JSON 输出。
- **可复现输出**：ZIP 时间戳固定为 1980-01-01，压缩无收益时自动退回存储模式，
  相同输入产生逐字节一致的产物。

## 安装

```bash
moon add 668xin/moon_epub
```

> 本库的 `preferred_target` 为 `js`。使用本机的 `wasm-gc` 后端时，`println`
> 输出可能丢失且 `moon test` 会崩溃，故所有命令建议显式携带 `--target js`。

## 命令行工具

项目自带一个 CLI，位于 `src/cli`，提供 `build` / `check` / `inspect` 子命令。

```bash
# 生成 EPUB 并以 Base64 输出（核心库无文件 IO，由 shell 解码落盘）
moon run src/cli --target js -- build minimal | base64 -d > minimal.epub

# 以十六进制输出（便于在无 base64 工具的环境中使用）
moon run src/cli --target js -- build multi-chapter --format hex

# 校验结构并输出文本诊断报告
moon run src/cli --target js -- check multi-chapter

# 以 JSON 输出机器可读报告
moon run src/cli --target js -- check multi-chapter --json

# 打印书籍结构树
moon run src/cli --target js -- inspect styled

# 列出内置示例
moon run src/cli --target js -- examples
```

## 作为库使用

```moonbit
// 取一个已装配好 manifest / spine 的示例书籍（也可自行构造 @model.Book）
let book = @examples.multi_chapter()

// 打包为 EPUB 字节流
let options = @ocf.PackageOptions::new()
let epub : Bytes = @ocf.package_book(book, options)

// 结构校验（独立于生成层）
let report = @validate.validate_book(book)
println(report.summary())
if report.is_ok() {
  println("结构校验通过")
}
```

生成端的分层 API（均为 `pub`，`moon info` 生成的 `src/*/pkg.generated.mbti`
列出了完整接口）：

| 包         | 职责                                                                              |
| ---------- | --------------------------------------------------------------------------------- |
| `spec`     | 规范常量：XML 命名空间、媒体类型、OCF 保留文件名、可访问性/SMIL 常量              |
| `model`    | 书籍领域模型：`Book` / `Chapter` / `Resource` / `Metadata` / `Manifest` / `Spine` |
| `xhtml`    | XHTML5 内容文档生成（块级与内联元素、脚注编号）                                   |
| `opf`      | OPF 包文档序列化（元数据、manifest、spine）                                       |
| `nav`      | `nav.xhtml` 导航与 `toc.ncx` 向后兼容目录                                         |
| `zip`      | ZIP 写入器：本地文件头、中央目录、CRC32、DEFLATE                                  |
| `ocf`      | OCF 容器布局与端到端打包（`package_book`）                                        |
| `assets`   | 样式表合成、MIME 类型推断、资源注册                                               |
| `cfi`      | EPUB CFI 定位路径构造与解析                                                       |
| `a11y`     | 可访问性元数据体系                                                                |
| `media`    | Media Overlays / SMIL 朗读同步                                                    |
| `validate` | 结构校验规则集与诊断报告                                                          |
| `examples` | 三个可直接打包的示例书籍（`minimal` / `multi-chapter` / `styled`）                |
| `cli`      | 命令行入口                                                                        |

## 内置示例

- `minimal`：单章节单段落，含可访问性元数据，用于最小可用验证。
- `multi-chapter`：嵌套目录与标题、段落、列表、引用、代码块、表格、脚注等
  多种块级元素。
- `styled`：内置阅读器友好 CSS 与自定义 CSS 合成，另附封面图片资源。

## 目录结构

```
src/
├── spec/      规范常量层
├── model/     书籍领域模型
├── xhtml/     XHTML5 内容文档生成
├── opf/       OPF 包文档序列化
├── nav/       nav.xhtml + toc.ncx 双轨导航
├── zip/       ZIP 写入器（本地文件头、中央目录、CRC32、DEFLATE）
├── ocf/       OCF 容器布局与打包
├── assets/    样式与静态资源管理
├── cfi/       EPUB CFI 定位路径
├── a11y/      可访问性元数据
├── media/     Media Overlays / SMIL
├── validate/  结构校验器
├── examples/  示例书籍
└── cli/       命令行入口
```

各包的 `moon.pkg` 声明依赖，依赖方向由编译器强制约束，保持单向无环。

## 验证与测试

```bash
moon check --target js   # 类型检查
moon build --target js   # 构建
moon test  --target js   # 全量单元测试
moon fmt   --check       # 格式检查
moon info  --target js   # 生成 .mbti 接口摘要
```

CLI 生成的 `.epub` 可用 Python 标准库交叉验证其 ZIP 兼容性：

```python
import base64, io, zipfile
data = base64.b64decode(open("minimal.epub.b64").read())
z = zipfile.ZipFile(io.BytesIO(data))
print(z.namelist(), z.testzip(), z.read("mimetype").decode())
```

## 发布到 mooncakes.io

MoonBit 使用 `moon` 工具链把模块发布到 <https://mooncakes.io>：

```bash
moon login            # 登录 mooncakes.io 账号
moon publish --dry-run  # 本地打包校验（仅检查，不实际上传）
moon publish          # 发布当前版本（moon.mod 中的 version 字段）
```

发布前请确认：

- `moon.mod` 的 `name` / `version` / `license` / `readme` / `repository` 字段完整；
- `moon check --target js`、`moon test --target js`、`moon fmt --check` 全部通过；
- 更新 `version` 后重新执行 `moon info --target js` 以刷新接口摘要。

## 许可证

Apache-2.0
