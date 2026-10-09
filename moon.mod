// Moonbit_EPUB — EPUB 3 电子书生成引擎
//
// 重要：preferred_target 必须为 "js"。
// 本机 wasm-gc 后端存在两个致命问题：
//   1. println 输出静默丢失（CLI 无法工作）
//   2. moon test 崩溃（exit code 0xc0000139）
// js 后端下 check / build / test / run 全部正常。
// native 后端需要系统 C 编译器（本机未安装）。

name = "668xin/moon_epub"

version = "0.1.0"

readme = "README.md"

repository = "https://gitee.com/aoliaoxiaoxin/moonbit_epub"

license = "Apache-2.0"

keywords = [
  "epub",
  "ebook",
  "publishing",
  "opf",
  "ocf",
  "zip",
  "xhtml",
  "document-generation",
]

preferred_target = "js"

description = "EPUB 3 ebook generation engine for MoonBit: builds spec-conformant .epub files from a structured book model, with OPF package documents, navigation, XHTML content, OCF/ZIP packaging and a structure validator."
