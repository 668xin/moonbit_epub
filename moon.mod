// Moonbit_EPUB — EPUB 3 电子书生成引擎
//
// 默认后端为 wasm-gc：无需 Node，check / build / test / run 均已验证通过。
// 旧版 moonrun 在 Windows 上曾有 DLL 加载问题（0xc0000139）与输出丢失，
// 升级工具链后已修复；如需兼容旧环境，可显式使用 --target js。
// native 后端需要系统 C 编译器。

name = "668xin/moon_epub"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/668xin/moonbit_epub.git"

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

preferred_target = "wasm-gc"

description = "EPUB 3 ebook generation engine for MoonBit: builds spec-conformant .epub files from a structured book model, with OPF package documents, navigation, XHTML content, OCF/ZIP packaging and a structure validator."
