///|
/// S7 结构校验规则集的单元测试。

///|
/// 报告中是否存在指定规则代码的诊断。
fn has_code(report : Report, code : String) -> Bool {
  for diagnostic in report.diagnostics {
    if diagnostic.code == code {
      return true
    }
  }
  false
}

///|
/// 构造一份结构完整、可通过校验的书籍。
fn valid_book() -> @model.Book {
  let metadata = @model.Metadata::new("示例书", "zh-CN", "urn:uuid:00000000")
  metadata.set_modified("2026-10-09T00:00:00Z")
  metadata.add_creator(@model.Contributor::new("作者"))
  let book = @model.Book::new(metadata)
  book.add_chapter(@model.Chapter::new("ch1", "第一章"))
  book.add_chapter(@model.Chapter::new("ch2", "第二章"))
  let nav = @model.ManifestItem::new("nav", "nav.xhtml", @spec.mt_xhtml)
  nav.add_property(@spec.epub_property_nav)
  let _ = book.add_manifest_item(nav)
  let _ = book.add_manifest_item(
    @model.ManifestItem::new("ncx", "toc.ncx", @spec.mt_ncx),
  )
  let _ = book.add_manifest_item(
    @model.ManifestItem::new("ch1", "text/ch1.xhtml", @spec.mt_xhtml),
  )
  let _ = book.add_manifest_item(
    @model.ManifestItem::new("ch2", "text/ch2.xhtml", @spec.mt_xhtml),
  )
  let _ = book.add_manifest_item(
    @model.ManifestItem::new("style", "styles/style.css", @spec.mt_css),
  )
  book.add_resource(
    @model.Resource::css("styles/style.css", "body { color: #000; }"),
  )
  book.add_spine_item(@model.SpineItem::new("ch1"))
  book.add_spine_item(@model.SpineItem::new("ch2"))
  book.spine.set_toc("ncx")
  book
}

///|
test "validate_metadata: 必需项缺失" {
  let metadata = @model.Metadata::new("", "", "")
  let report = validate_metadata(metadata)
  assert_true(has_code(report, "MET-001"))
  assert_true(has_code(report, "MET-002"))
  assert_true(has_code(report, "MET-003"))
  assert_true(has_code(report, "MET-004"))
  assert_eq(report.error_count(), 4)
}

///|
test "validate_metadata: 完整元数据无诊断" {
  let metadata = @model.Metadata::new("书名", "zh-CN", "urn:uuid:abc")
  metadata.set_modified("2026-10-09T00:00:00Z")
  metadata.add_creator(@model.Contributor::new("作者"))
  let report = validate_metadata(metadata)
  assert_true(report.is_ok())
  assert_eq(report.length(), 0)
}

///|
test "validate_metadata: 非 URI 标识符触发警告" {
  let metadata = @model.Metadata::new("书名", "zh-CN", "isbn-12345")
  metadata.set_modified("2026-10-09T00:00:00Z")
  metadata.add_creator(@model.Contributor::new("作者"))
  let report = validate_metadata(metadata)
  assert_true(has_code(report, "MET-005"))
  assert_eq(report.warning_count(), 1)
}

///|
test "validate_chapters: 合法章节树" {
  let chapters = [
    @model.Chapter::new("ch1", "第一章"),
    @model.Chapter::new("ch2", "第二章"),
  ]
  let report = validate_chapters(chapters)
  assert_true(report.is_ok())
  assert_eq(report.length(), 0)
}

///|
test "validate_chapters: 重复与非法 id" {
  let chapters = [
    @model.Chapter::new("ch1", ""),
    @model.Chapter::new("ch1", "重复"),
    @model.Chapter::new("9bad", "非法"),
  ]
  let report = validate_chapters(chapters)
  assert_true(has_code(report, "CHP-002"))
  assert_true(has_code(report, "CHP-003"))
  assert_true(has_code(report, "CHP-004"))
}

///|
test "validate_resources: 重复与媒体类型不符" {
  let resources = [
    @model.Resource::new("images/a.png", @spec.mt_png, b"PNG"),
    @model.Resource::new("images/a.png", @spec.mt_png, b"PNG"),
    @model.Resource::new("style.css", @spec.mt_js, b"x"),
  ]
  let report = validate_resources(resources)
  assert_true(has_code(report, "RES-002"))
  assert_true(has_code(report, "RES-004"))
}

///|
test "validate_manifest: 空清单与缺少导航" {
  let empty = validate_manifest(@model.Manifest::new())
  assert_true(has_code(empty, "OPF-001"))
  let manifest = @model.Manifest::new()
  let _ = manifest.add(
    @model.ManifestItem::new("ch1", "text/ch1.xhtml", @spec.mt_xhtml),
  )
  let report = validate_manifest(manifest)
  assert_true(has_code(report, "OPF-002"))
}

///|
test "validate_spine: 引用不存在的 id 与非 XHTML 目标" {
  let manifest = @model.Manifest::new()
  let _ = manifest.add(
    @model.ManifestItem::new("img", "images/a.png", @spec.mt_png),
  )
  let spine = @model.Spine::new()
  spine.add(@model.SpineItem::new("missing"))
  spine.add(@model.SpineItem::new("img"))
  spine.set_toc("nav")
  let report = validate_spine(spine, manifest)
  assert_true(has_code(report, "SPN-002"))
  assert_true(has_code(report, "SPN-003"))
  assert_true(has_code(report, "SPN-004"))
}

///|
test "validate_spine: 空阅读顺序" {
  let report = validate_spine(@model.Spine::new(), @model.Manifest::new())
  assert_true(has_code(report, "SPN-001"))
}

///|
test "validate_container: 合法布局" {
  let entries = [
    ContainerEntry::stored("mimetype"),
    ContainerEntry::deflated("META-INF/container.xml"),
    ContainerEntry::deflated("OEBPS/content.opf"),
    ContainerEntry::deflated("OEBPS/nav.xhtml"),
  ]
  let report = validate_container(entries)
  assert_true(report.is_ok())
  assert_eq(report.length(), 0)
}

///|
test "validate_container: mimetype 位置与压缩方式" {
  let entries = [
    ContainerEntry::deflated("META-INF/container.xml"),
    ContainerEntry::deflated("mimetype"),
    ContainerEntry::deflated("OEBPS/content.opf"),
  ]
  let report = validate_container(entries)
  // 首条目非 mimetype
  assert_true(has_code(report, "CON-002"))
  // mimetype 被压缩
  assert_true(has_code(report, "CON-003"))
  // 缺 META-INF/container.xml 之外的重复检查：此处存在，故不报 CON-004
  assert_false(has_code(report, "CON-004"))
}

///|
test "validate_container: 缺必需文件与重复条目" {
  let entries = [
    ContainerEntry::stored("mimetype"),
    ContainerEntry::deflated("OEBPS/content.opf"),
    ContainerEntry::deflated("OEBPS/content.opf"),
  ]
  let report = validate_container(entries)
  assert_true(has_code(report, "CON-004"))
  assert_true(has_code(report, "CON-005"))
}

///|
test "validate_container: 空容器" {
  let report = validate_container([])
  assert_true(has_code(report, "CON-001"))
}

///|
test "validate_book: 完整书籍通过" {
  let report = validate_book(valid_book())
  assert_true(report.is_ok())
  assert_eq(report.error_count(), 0)
}

///|
test "validate_book: 章节未登记于清单" {
  let book = valid_book()
  // 追加一个未登记于清单的章节
  book.add_chapter(@model.Chapter::new("ch3", "第三章"))
  let report = validate_book(book)
  assert_true(has_code(report, "RCH-001"))
  assert_false(report.is_ok())
}
