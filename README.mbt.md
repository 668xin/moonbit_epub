# aoliaoxiaoxin/moon_epub

Moon EPUB — 用 MoonBit 实现的 EPUB 3 电子书生成引擎。

仓库：<https://gitee.com/aoliaoxiaoxin/moonbit_epub.git>

从结构化书籍模型出发，生成符合 W3C EPUB 3.3 与 OCF 3.3 规范的 `.epub` 文件：
包含 OPF 包文档、导航文档、XHTML5 内容文档、OCF/ZIP 容器打包，
以及一个结构校验器。

> 当前处于**骨架阶段**：目录分层、包配置与构建链路已就绪，
> 各模块实现按 `docs/开发工作计划.md` 分阶段填充。

## 安装

```bash
moon add aoliaoxiaoxin/moon_epub
```

## 快速开始

```bash
moon build --target js
moon run src/cli --target js -- help
```

## 目录结构

```
src/
├── spec/      规范常量层：XML 命名空间、媒体类型、OCF 保留文件名（S0）
├── model/     书籍领域模型：书籍、章节、资源、元数据（S1）
├── xhtml/     XHTML5 内容文档生成（S2）
├── opf/       OPF 包文档序列化：元数据、manifest、spine（S3）
├── nav/       nav.xhtml 导航与 toc.ncx 兼容目录（S3）
├── zip/       ZIP 写入器：本地文件头、中央目录、CRC32（S4）
├── ocf/       OCF 容器布局与打包（S4）
├── assets/    CSS 样式与静态资源管理（S5）
├── cfi/       EPUB CFI 定位路径（S5）
├── a11y/      可访问性元数据（S6）
├── media/     Media Overlays / SMIL 朗读同步（S6）
├── validate/  结构校验器（S7）
└── cli/       命令行入口（S8）
```

各包的 `moon.pkg` 声明依赖，依赖方向由编译器强制约束，保持单向无环。

## 开发环境

本机 `moon` 工具链需要 `MOON_CORE_OVERRIDE` 指向核心库源码目录才能注入标准库：

```bash
source env.sh        # bash
. .\env.ps1          # PowerShell
```

`preferred_target` 为 `js`——`wasm-gc` 后端存在 `println` 输出丢失与测试崩溃问题。

## 许可证

Apache-2.0
