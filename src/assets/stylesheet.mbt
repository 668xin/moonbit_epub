///|
/// 样式与资源管理（S5）。
///
/// 提供阅读器友好的内置样式表、自定义样式注入，以及图片/字体等静态资源
/// 的登记、去重与 MIME 类型推断，产出可直接并入包文档清单的条目。

///|
/// 内置阅读器友好的基础样式表。
///
/// 仅约定正文排版（行高、段落间距、标题层级、列表/引用/代码块/表格/图片），
/// 不强制字体族与配色，交由阅读器主题与自定义样式接管。
pub let base_stylesheet : String =
  #|html {
  #|  font-size: 100%;
  #|}
  #|body {
  #|  margin: 0 5%;
  #|  line-height: 1.6;
  #|  text-align: justify;
  #|  word-wrap: break-word;
  #|}
  #|h1, h2, h3, h4, h5, h6 {
  #|  margin: 1.2em 0 0.6em;
  #|  line-height: 1.3;
  #|  text-align: left;
  #|  page-break-after: avoid;
  #|  break-after: avoid;
  #|}
  #|p {
  #|  margin: 0 0 0.8em;
  #|  text-indent: 0;
  #|}
  #|blockquote {
  #|  margin: 0.8em 2em;
  #|  font-style: italic;
  #|}
  #|ul, ol {
  #|  margin: 0.6em 0 0.6em 1.5em;
  #|  padding: 0;
  #|}
  #|li {
  #|  margin: 0.2em 0;
  #|}
  #|pre {
  #|  margin: 0.8em 0;
  #|  padding: 0.6em;
  #|  overflow-x: auto;
  #|  white-space: pre-wrap;
  #|  font-family: monospace;
  #|}
  #|code {
  #|  font-family: monospace;
  #|}
  #|table {
  #|  margin: 0.8em 0;
  #|  border-collapse: collapse;
  #|}
  #|th, td {
  #|  padding: 0.3em 0.6em;
  #|  border: 1px solid currentColor;
  #|  text-align: left;
  #|}
  #|img {
  #|  max-width: 100%;
  #|  height: auto;
  #|}
  #|hr {
  #|  margin: 1.2em 0;
  #|  border: 0;
  #|  border-top: 1px solid currentColor;
  #|}
  #|.footnote {
  #|  font-size: 0.85em;
  #|  color: inherit;
  #|}

///|
/// 把自定义样式追加到内置基础样式之后，使其可覆盖基础规则。
///
/// 自定义内容为空时直接返回基础样式，避免产生多余空行。
pub fn compose_stylesheet(custom : String) -> String {
  if custom.is_empty() {
    base_stylesheet
  } else {
    base_stylesheet + "\n" + custom
  }
}

///|
/// 构造样式表资源：内置基础样式与自定义样式合并后写入。
pub fn stylesheet_resource(href : String, custom : String) -> @model.Resource {
  @model.Resource::css(href, compose_stylesheet(custom))
}

///|
/// 构造仅含内置基础样式的样式表资源。
pub fn base_stylesheet_resource(href : String) -> @model.Resource {
  @model.Resource::css(href, base_stylesheet)
}
