///|
/// 示例书籍集合（S8）。
///
/// 提供三本可直接打包的示例：最小书籍、多章节书籍（含嵌套目录与多种块级
/// 元素）、自定义样式书籍（内置 CSS 与自定义 CSS 合成）。示例以代码方式
/// 构造书籍模型，既作为可运行示例，也作为端到端测试的固定输入。

// ---------------------------------------------------------------------------
// 构造工具
// ---------------------------------------------------------------------------

///|
/// 构造带 `dcterms:modified` 的基础元数据。
fn base_metadata(
  title : String,
  language : String,
  identifier : String,
) -> @model.Metadata {
  let metadata = @model.Metadata::new(title, language, identifier)
  metadata.set_modified("2026-10-09T00:00:00Z")
  metadata.add_creator(@model.Contributor::new("示例作者", role="aut"))
  metadata
}

///|
/// 依据章节树与资源装配清单与阅读顺序，使书籍可直接通过结构校验。
///
/// 清单顺序：导航 → NCX → 各章节内容文档 → 各资源；阅读顺序取章节树的
/// 深度优先展平，并将 `spine@toc` 指向 NCX 条目。
fn assemble(book : @model.Book) -> Unit {
  let nav = @model.ManifestItem::new(
    @spec.manifest_id_nav, @spec.default_nav_filename, @spec.mt_xhtml,
  )
  nav.add_property(@spec.epub_property_nav)
  let _ = book.add_manifest_item(nav)
  let _ = book.add_manifest_item(
    @model.ManifestItem::new(
      @spec.manifest_id_ncx, @spec.default_ncx_filename, @spec.mt_ncx,
    ),
  )
  for chapter in @model.flatten_chapters(book.chapters) {
    let _ = book.add_manifest_item(
      @model.ManifestItem::new(
        chapter.id,
        @model.chapter_href(chapter),
        @spec.mt_xhtml,
      ),
    )
    book.add_spine_item(@model.SpineItem::new(chapter.id))
  }
  for resource in book.resources {
    let _ = book.add_manifest_item(
      @model.ManifestItem::new(
        @model.resource_id(resource),
        resource.href,
        resource.media_type,
      ),
    )
  }
  book.spine.set_toc(@spec.manifest_id_ncx)
}

// ---------------------------------------------------------------------------
// 示例一：最小书籍
// ---------------------------------------------------------------------------

///|
/// 最小可打包书籍：单章节单段落，含可访问性元数据。
pub fn minimal() -> @model.Book {
  let metadata = base_metadata("最小示例", "zh-CN", "urn:uuid:minimal-0001")
  @a11y.Accessibility::text_only().apply_to(metadata)
  let book = @model.Book::new(metadata)
  book.add_chapter(
    @model.Chapter::with_body("ch1", "前言", [
      @model.Block::paragraph("这是一个最小可用的 EPUB 3 示例。"),
    ]),
  )
  assemble(book)
  book
}

// ---------------------------------------------------------------------------
// 示例二：多章节书籍
// ---------------------------------------------------------------------------

///|
/// 多章节书籍：嵌套目录与标题、段落、列表、引用、代码块、表格、脚注等
/// 多种块级元素。
pub fn multi_chapter() -> @model.Book {
  let metadata = base_metadata(
    "多章节示例", "zh-CN", "urn:uuid:multi-0002",
  )
  @a11y.Accessibility::text_only().apply_to(metadata)
  let book = @model.Book::new(metadata)
  let intro = @model.Chapter::with_body("ch1", "引言", [
    @model.Block::heading(1, "引言"),
    @model.Block::paragraph("本书演示 EPUB 3 的多种内容结构。"),
    @model.Block::list(false, [
      [@model.Block::paragraph("结构化内容")],
      [@model.Block::paragraph("可访问性")],
      [@model.Block::paragraph("导航")],
    ]),
  ])
  let body = @model.Chapter::with_body("ch2", "正文", [
    @model.Block::heading(1, "正文"),
    @model.Block::paragraph("正文始于一段说明性文字。"),
    @model.Block::blockquote([
      @model.Block::paragraph("引用内容用于强调他人观点。"),
    ]),
    @model.Block::code_block("moonbit", "let book = @model.Book::new(metadata)"),
    @model.Block::table(
      [
        [@model.Inline::text("元素"), @model.Inline::text("用途")],
        [@model.Inline::text("nav"), @model.Inline::text("导航")],
      ],
      [[[@model.Inline::text("spine")], [@model.Inline::text("阅读顺序")]]],
    ),
    @model.Block::paragraph("参见脚注说明。"),
    @model.Block::note("note-1", [
      @model.Block::paragraph("这是脚注正文。"),
    ]),
  ])
  body.add_child(
    @model.Chapter::with_body("ch2-1", "小节", [
      @model.Block::paragraph("嵌套章节用于验证多级目录。"),
    ]),
  )
  let appendix = @model.Chapter::with_body("ch3", "附录", [
    @model.Block::paragraph("附录内容。"),
  ])
  book.add_chapter(intro)
  book.add_chapter(body)
  book.add_chapter(appendix)
  book.add_resource(
    @assets.base_stylesheet_resource(@spec.default_stylesheet_path),
  )
  assemble(book)
  book
}

// ---------------------------------------------------------------------------
// 示例三：自定义样式书籍
// ---------------------------------------------------------------------------

///|
/// 自定义样式书籍：内置阅读器友好 CSS 与自定义规则合成，另附封面图片资源。
pub fn styled() -> @model.Book {
  let metadata = base_metadata("样式示例", "zh-CN", "urn:uuid:styled-0003")
  @a11y.Accessibility::text_only().apply_to(metadata)
  let book = @model.Book::new(metadata)
  book.add_chapter(
    @model.Chapter::with_body("ch1", "样式演示", [
      @model.Block::heading(1, "样式演示"),
      @model.Block::paragraph(
        "本示例演示自定义 CSS 的注入与合成。",
      ),
      @model.Block::image("images/cover.png", "封面示意"),
    ]),
  )
  book.add_resource(
    @assets.stylesheet_resource(
      "styles/custom.css", "h1 { color: #336699; }\nblockquote { border-left: 3px solid #ccc; }",
    ),
  )
  book.add_resource(
    @model.Resource::new("images/cover.png", @spec.mt_png, b"PNG-placeholder"),
  )
  assemble(book)
  book
}

// ---------------------------------------------------------------------------
// 名称索引
// ---------------------------------------------------------------------------

///|
/// 按名称构造示例书籍，未知名称返回 `None`。
pub fn by_name(name : String) -> @model.Book? {
  match name {
    "minimal" => Some(minimal())
    "multi-chapter" | "multi" => Some(multi_chapter())
    "styled" => Some(styled())
    _ => None
  }
}

///|
/// 全部示例名称，按推荐展示顺序。
pub fn names() -> Array[String] {
  ["minimal", "multi-chapter", "styled"]
}
