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

// ---------------------------------------------------------------------------
// 示例一：最小书籍
// ---------------------------------------------------------------------------

///|
/// 最小可打包书籍：单章节单段落，含可访问性元数据。
pub fn minimal() -> @model.Book {
  let metadata = base_metadata(
    "最小示例",
    "zh-CN",
    @spec.content_identifier("minimal"),
  )
  @a11y.Accessibility::text_only().apply_to(metadata)
  let book = @model.Book::new(metadata)
  book.add_chapter(
    @model.Chapter::with_body("ch1", "前言", [
      @model.Block::paragraph("这是一个最小可用的 EPUB 3 示例。"),
    ]),
  )
  @model.assemble_book(book)
}

// ---------------------------------------------------------------------------
// 示例二：多章节书籍
// ---------------------------------------------------------------------------

///|
/// 多章节书籍：嵌套目录与标题、段落、列表、引用、代码块、表格、脚注等
/// 多种块级元素。
pub fn multi_chapter() -> @model.Book {
  let metadata = base_metadata(
    "多章节示例",
    "zh-CN",
    @spec.content_identifier("multi-chapter"),
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
    @model.Block::paragraph_of([
      @model.Inline::text("参见脚注说明"),
      @model.Inline::footnote_ref("note-1"),
      @model.Inline::text("。"),
    ]),
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
  @model.assemble_book(book)
}

// ---------------------------------------------------------------------------
// 示例三：自定义样式书籍
// ---------------------------------------------------------------------------

///|
/// 自定义样式书籍：内置阅读器友好 CSS 与自定义规则合成，另附封面图片资源。
pub fn styled() -> @model.Book {
  let metadata = base_metadata(
    "样式示例",
    "zh-CN",
    @spec.content_identifier("styled"),
  )
  @a11y.Accessibility::text_only().apply_to(metadata)
  let book = @model.Book::new(metadata)
  book.add_chapter(
    @model.Chapter::with_body("ch1", "样式演示", [
      @model.Block::heading(1, "样式演示"),
      @model.Block::paragraph(
        "本示例演示自定义 CSS 的注入与合成。",
      ),
      @model.Block::image("../images/cover.svg", "封面示意"),
    ]),
  )
  book.add_resource(
    @assets.stylesheet_resource(
      "styles/custom.css", "h1 { color: #336699; }\nblockquote { border-left: 3px solid #ccc; }",
    ),
  )
  book.add_resource(
    @model.Resource::text(
      "images/cover.svg", @spec.mt_svg, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"600\" height=\"800\" viewBox=\"0 0 600 800\"><rect width=\"600\" height=\"800\" fill=\"#eef\"/><text x=\"300\" y=\"400\" text-anchor=\"middle\" font-size=\"48\" fill=\"#336\">封面</text></svg>",
    ),
  )
  @model.assemble_book(book)
}

// ---------------------------------------------------------------------------
// 示例四：Media Overlays
// ---------------------------------------------------------------------------

///|
/// 构造一帧结构完整的静音 MP3 占位数据
/// （MPEG-1 Layer III，128 kbps，44.1 kHz，417 字节）。
fn silent_mp3() -> Bytes {
  let buf = Buffer()
  buf.write_byte(0xFFU.to_byte())
  buf.write_byte(0xFBU.to_byte())
  buf.write_byte(0x90U.to_byte())
  buf.write_byte(0x64U.to_byte())
  for _ in 0..<413 {
    buf.write_byte(0U.to_byte())
  }
  buf.to_bytes()
}

///|
/// 有声书示例：单章节正文、一个音频资源，以及对应的 SMIL Media Overlay。
pub fn media() -> @model.Book {
  let metadata = base_metadata(
    "有声示例",
    "zh-CN",
    @spec.content_identifier("media"),
  )
  @a11y.Accessibility::audio_book().apply_to(metadata)
  let book = @model.Book::new(metadata)
  book.add_chapter(
    @model.Chapter::with_body("ch1", "朗读同步", [
      @model.Block::heading(1, "朗读同步"),
      @model.Block::paragraph("这段文字与音频片段同步播放。"),
    ]),
  )
  book.add_resource(
    @model.Resource::new("audio/ch1.mp3", @spec.mt_mp3, silent_mp3()),
  )
  @model.assemble_book(book)
}

///|
/// Media Overlay 示例的 SMIL 文本。
pub fn media_smil() -> String {
  let overlay = @media.Overlay::new()
  // SMIL 位于 text/ 下，因此正文与音频使用相对 SMIL 的路径
  let seq = @media.Seq::new("seq-ch1", "ch1.xhtml")
  seq.add_par(
    @media.Par::new(
      "par-1",
      "ch1.xhtml",
      @media.AudioClip::from_millis("../audio/ch1.mp3", 0, 1200),
    ),
  )
  overlay.add_seq(seq)
  @media.render_smil(overlay, @media.SmilOptions::new())
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
    "media" => Some(media())
    _ => None
  }
}

///|
/// 全部示例名称，按推荐展示顺序。
pub fn names() -> Array[String] {
  ["minimal", "multi-chapter", "styled", "media"]
}
