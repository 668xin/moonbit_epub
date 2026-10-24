///|
/// EPUB 结构校验规则集（S7）。
///
/// 针对书籍模型与容器条目做规范级检查，覆盖：必需元数据、ID 唯一性、
/// 章节与资源可用性、清单一致性、阅读顺序引用完整性、资源可达性，
/// 以及 OCF 容器布局（`mimetype` 位置与压缩方式、必需文件存在性）。
///
/// 每条规则产出带稳定代码的 `Diagnostic`，写入 `Report`；`validate_book`
/// 串联全部模型级规则，`validate_container` 检查容器级布局。

// ---------------------------------------------------------------------------
// 元数据规则（MET）
// ---------------------------------------------------------------------------

///|
/// 检查 EPUB 3 必需元数据项与标识符形式。
pub fn validate_metadata(metadata : @model.Metadata) -> Report {
  let report = Report::new()
  if metadata.title.is_empty() {
    report.error(
      "MET-001", "package/metadata/dc:title", "缺少标题（dc:title）",
    )
  }
  if metadata.language.is_empty() {
    report.error(
      "MET-002", "package/metadata/dc:language", "缺少语言（dc:language）",
    )
  }
  if metadata.identifier.is_empty() {
    report.error(
      "MET-003", "package/metadata/dc:identifier", "缺少唯一标识符（dc:identifier）",
    )
  }
  match metadata.modified {
    Some(_) => ()
    None =>
      report.error(
        "MET-004", "package/metadata/meta", "缺少 dcterms:modified（EPUB 3 必需）",
      )
  }
  if !metadata.identifier.is_empty() && !metadata.identifier.contains(":") {
    report.warning(
      "MET-005", "package/metadata/dc:identifier", "唯一标识符未使用 URI 形式，建议采用 urn:uuid:",
    )
  }
  if metadata.creators.is_empty() && metadata.contributors.is_empty() {
    report.info("MET-006", "package/metadata", "未声明作者或贡献者")
  }
  report
}

// ---------------------------------------------------------------------------
// 章节规则（CHP）
// ---------------------------------------------------------------------------

///|
/// 检查章节树：ID 非空、合法且全局唯一，标题非空。
pub fn validate_chapters(chapters : Array[@model.Chapter]) -> Report {
  let report = Report::new()
  let flat = @model.flatten_chapters(chapters)
  if flat.is_empty() {
    report.info("CHP-005", "package/spine", "书籍不含任何章节")
  }
  let seen : Map[String, Bool] = Map([])
  for chapter in flat {
    if chapter.id.is_empty() {
      report.error("CHP-001", "chapter", "章节 id 为空")
    } else {
      if !@spec.is_valid_id(chapter.id) {
        report.error(
          "CHP-002",
          "chapter#\{chapter.id}",
          "章节 id 不是合法的 XML ID",
        )
      }
      if seen.contains(chapter.id) {
        report.error("CHP-003", "chapter#\{chapter.id}", "章节 id 重复")
      } else {
        seen.set(chapter.id, true)
      }
    }
    if chapter.title.is_empty() {
      report.warning("CHP-004", "chapter#\{chapter.id}", "章节标题为空")
    }
  }
  report
}

// ---------------------------------------------------------------------------
// 资源规则（RES）
// ---------------------------------------------------------------------------

///|
/// 检查资源集合：href 非空且唯一，媒体类型齐备且与扩展名一致。
pub fn validate_resources(resources : Array[@model.Resource]) -> Report {
  let report = Report::new()
  let seen : Map[String, Bool] = Map([])
  for resource in resources {
    let location = if resource.href.is_empty() {
      "resource"
    } else {
      "resource#\{resource.href}"
    }
    if resource.href.is_empty() {
      report.error("RES-001", location, "资源 href 为空")
      continue
    }
    let href = @model.resource_href(resource)
    if !@spec.is_safe_relative_path(href) {
      report.error(
        "RES-006", location, "资源 href 不是安全的容器内相对路径",
      )
    }
    if seen.contains(resource.href) {
      report.error("RES-002", location, "资源 href 重复")
    } else {
      seen.set(resource.href, true)
    }
    if resource.media_type.is_empty() {
      report.error("RES-003", location, "资源缺少媒体类型")
    } else {
      let inferred = @spec.media_type_of_path(resource.href)
      if inferred != @spec.mt_octet_stream && inferred != resource.media_type {
        report.warning(
          "RES-004",
          location,
          "资源媒体类型与扩展名推断不一致：声明 \{resource.media_type}，推断 \{inferred}",
        )
      }
    }
    if resource.data.length() == 0 {
      report.info("RES-005", location, "资源数据为空")
    }
  }
  report
}

// ---------------------------------------------------------------------------
// 清单规则（OPF）
// ---------------------------------------------------------------------------

///|
/// 检查清单：非空、含导航文档、条目字段齐备、href 唯一。
pub fn validate_manifest(manifest : @model.Manifest) -> Report {
  let report = Report::new()
  if manifest.length() == 0 {
    report.error("OPF-001", "package/manifest", "清单为空")
    return report
  }
  let has_nav = {
    let mut found = false
    for item in manifest.items {
      if item.has_property(@spec.epub_property_nav) {
        found = true
      }
    }
    found
  }
  if !has_nav {
    report.error(
      "OPF-002", "package/manifest", "清单缺少导航文档（properties 含 nav 的条目）",
    )
  }
  let seen_href : Map[String, Bool] = Map([])
  let seen_id : Map[String, Bool] = Map([])
  for item in manifest.items {
    let location = if item.id.is_empty() {
      "package/manifest/item"
    } else {
      "package/manifest/item#\{item.id}"
    }
    if item.id.is_empty() || !@spec.is_valid_id(item.id) {
      report.error("OPF-003", location, "清单条目 id 为空或非法")
    } else if seen_id.contains(item.id) {
      report.error("OPF-008", location, "清单条目 id 重复")
    } else {
      seen_id.set(item.id, true)
    }
    if item.href.is_empty() {
      report.error("OPF-004", location, "清单条目 href 为空")
    } else if !@spec.is_safe_relative_path(item.href) {
      report.error(
        "OPF-009", location, "清单条目 href 不是安全的容器内相对路径",
      )
    } else if seen_href.contains(item.href) {
      report.warning("OPF-006", location, "清单内 href 重复")
    } else {
      seen_href.set(item.href, true)
    }
    if item.media_type.is_empty() {
      report.error("OPF-005", location, "清单条目缺少 media-type")
    }
    if item.has_property(@spec.epub_property_nav) &&
      item.media_type != @spec.mt_xhtml {
      report.warning(
        "OPF-007", location, "导航文档条目 media-type 应为 XHTML",
      )
    }
    match item.media_overlay {
      Some(media_overlay) =>
        match manifest.find_by_id(media_overlay) {
          Some(target) =>
            if target.media_type != @spec.mt_smil {
              report.warning(
                "OPF-011", location, "media-overlay 未指向 SMIL 文档",
              )
            }
          None =>
            report.error(
              "OPF-010", location, "media-overlay 引用了不存在的清单 id",
            )
        }
      None => ()
    }
  }
  report
}

// ---------------------------------------------------------------------------
// 阅读顺序规则（SPN）
// ---------------------------------------------------------------------------

///|
/// 检查阅读顺序：非空、`idref` 可解析且指向内容文档、含线性条目。
pub fn validate_spine(
  spine : @model.Spine,
  manifest : @model.Manifest,
) -> Report {
  let report = Report::new()
  if spine.items.length() == 0 {
    report.error("SPN-001", "package/spine", "阅读顺序为空")
    return report
  }
  let mut linear = 0
  for item in spine.items {
    if item.linear {
      linear += 1
    }
    match manifest.find_by_id(item.idref) {
      Some(target) =>
        if target.media_type != @spec.mt_xhtml {
          report.error(
            "SPN-003",
            "package/spine/itemref#\{item.idref}",
            "阅读顺序条目未指向 XHTML 内容文档",
          )
        }
      None =>
        report.error(
          "SPN-002",
          "package/spine/itemref#\{item.idref}",
          "阅读顺序条目引用了不存在的清单 id",
        )
    }
  }
  if linear == 0 {
    report.warning(
      "SPN-005", "package/spine", "阅读顺序不含任何线性条目",
    )
  }
  match spine.toc {
    Some(toc) =>
      if !manifest.has_id(toc) {
        report.warning(
          "SPN-004", "package/spine", "spine@toc 指向的清单 id 不存在",
        )
      }
    None => ()
  }
  report
}

// ---------------------------------------------------------------------------
// 可达性规则（RCH）
// ---------------------------------------------------------------------------

///|
/// 检查章节与资源是否均已登记于清单（清单条目皆可达）。
pub fn validate_reachability(
  chapters : Array[@model.Chapter],
  resources : Array[@model.Resource],
  manifest : @model.Manifest,
) -> Report {
  let report = Report::new()
  for chapter in @model.flatten_chapters(chapters) {
    let href = @model.chapter_href(chapter)
    if !manifest.has_href(href) {
      report.error(
        "RCH-001",
        "chapter#\{chapter.id}",
        "章节内容文档 \{href} 未登记于清单",
      )
    }
  }
  for resource in resources {
    let href = @model.resource_href(resource)
    if !href.is_empty() && !manifest.has_href(href) {
      report.error(
        "RCH-002",
        "resource#\{resource.href}",
        "资源 \{href} 未登记于清单",
      )
    }
  }
  report
}

// ---------------------------------------------------------------------------
// 容器规则（CON）
// ---------------------------------------------------------------------------

///|
/// 容器条目描述：路径与其是否以存储（未压缩）方式写入。
pub struct ContainerEntry {
  // 容器内路径，如 `mimetype`、`META-INF/container.xml`
  path : String
  // 是否以 ZIP 存储方式写入（`false` 表示经压缩）
  stored : Bool
} derive(Eq, @debug.Debug)

///|
/// 构造容器条目。
pub fn ContainerEntry::new(path : String, stored : Bool) -> ContainerEntry {
  { path, stored, }
}

///|
/// 构造以存储方式写入的容器条目。
pub fn ContainerEntry::stored(path : String) -> ContainerEntry {
  { path, stored: true, }
}

///|
/// 构造以压缩方式写入的容器条目。
pub fn ContainerEntry::deflated(path : String) -> ContainerEntry {
  { path, stored: false, }
}

///|
/// 检查 OCF 容器布局：必需文件存在性、`mimetype` 位置与压缩方式、条目唯一性。
pub fn validate_container(entries : Array[ContainerEntry]) -> Report {
  let report = Report::new()
  if entries.is_empty() {
    report.error("CON-001", "container", "容器不含任何条目")
    return report
  }
  let first = entries[0]
  if first.path != @spec.ocf_mimetype {
    report.error(
      "CON-002",
      "container",
      "首个条目不是 mimetype（实际为 \{first.path}）",
    )
  }
  let mut mimetype : ContainerEntry? = None
  let mut has_container_xml = false
  let mut has_opf = false
  let seen : Map[String, Bool] = Map([])
  for entry in entries {
    if !@spec.is_safe_relative_path(entry.path) {
      report.error(
        "CON-008",
        "container#\{entry.path}",
        "容器条目路径不是安全的相对路径",
      )
    }
    if entry.path == @spec.ocf_mimetype {
      mimetype = Some(entry)
    }
    if entry.path == @spec.ocf_container_path {
      has_container_xml = true
    }
    if entry.path.has_suffix(".opf") {
      has_opf = true
    }
    if seen.contains(entry.path) {
      report.error(
        "CON-005",
        "container#\{entry.path}",
        "容器包含重复条目",
      )
    } else {
      seen.set(entry.path, true)
    }
  }
  match mimetype {
    Some(entry) =>
      if !entry.stored {
        report.error(
          "CON-003", "container#mimetype", "mimetype 条目必须使用存储方式（不压缩）",
        )
      }
    None => report.error("CON-002", "container", "容器缺少 mimetype 条目")
  }
  if !has_container_xml {
    report.error("CON-004", "container", "缺少 META-INF/container.xml")
  }
  if !has_opf {
    report.warning("CON-006", "container", "容器不含包文档（.opf）")
  }
  report
}

// ---------------------------------------------------------------------------
// 综合校验
// ---------------------------------------------------------------------------

///|
/// 对已生成的 EPUB 字节流做容器级校验。
///
/// 从 ZIP 中央目录读取条目路径与压缩方式，复用 `validate_container`
/// 检查 `mimetype` 位置与压缩方式、必需文件存在性与条目唯一性。
pub fn validate_package(data : Bytes) -> Report {
  let entries = @zip.entries(data)
  let container_entries : Array[ContainerEntry] = []
  for entry in entries {
    container_entries.push(ContainerEntry::new(entry.path, entry.stored))
  }
  let report = validate_container(container_entries)
  match @zip.read_stored(data, @spec.ocf_mimetype) {
    Some(content) =>
      if @utf8.decode_lossy(content) != @spec.mt_epub {
        report.error(
          "CON-007", "container#mimetype", "mimetype 内容不是 application/epub+zip",
        )
      }
    None => ()
  }
  report
}

///|
/// 对已装配的书籍模型做原始校验，不自动补全清单与阅读顺序。
///
/// 适合需要显式检查自定义 `manifest` / `spine` 的调用方；若希望校验
/// 与默认打包一致的装配结果，请使用 `validate_book`。
pub fn validate_book_raw(book : @model.Book) -> Report {
  let report = Report::new()
  report.merge(validate_metadata(book.metadata))
  report.merge(validate_chapters(book.chapters))
  report.merge(validate_resources(book.resources))
  report.merge(validate_manifest(book.manifest))
  report.merge(validate_spine(book.spine, book.manifest))
  report.merge(
    validate_reachability(book.chapters, book.resources, book.manifest),
  )
  report
}

///|
/// 对书籍模型做完整的模型级校验：先按默认 nav / NCX 装配清单与阅读顺序
/// （与 `package_book` 的默认装配一致），再执行元数据、章节、资源、清单、
/// 阅读顺序与可达性检查。
pub fn validate_book(book : @model.Book) -> Report {
  validate_book_raw(@model.assemble_book(book))
}

// ---------------------------------------------------------------------------
// 生成文档一致性（OPF / nav / NCX）
// ---------------------------------------------------------------------------

///|
/// 统计 `needle` 在 `text` 中出现的次数。
fn count_occurrences(text : String, needle : String) -> Int {
  if needle.is_empty() {
    return 0
  }
  text.split(needle).length() - 1
}

///|
/// 检查实际生成的 OPF / nav / NCX 文本与装配模型是否一致。
///
/// 覆盖必需元数据、清单条目、阅读顺序条目、导航目标与保留前缀声明，
/// 用于发现生成层与模型层不一致的问题。完整的 XML 语义校验仍由外部
/// EPUBCheck 承担。
pub fn validate_documents(
  metadata : @model.Metadata,
  manifest : @model.Manifest,
  spine : @model.Spine,
  opf : String,
  nav : String,
  ncx : String,
) -> Report {
  let report = Report::new()
  // 必需元数据
  let title = @spec.xml_escape(metadata.title)
  if !opf.contains("<dc:title>\{title}</dc:title>") {
    report.error(
      "OPF-012", "package/metadata/dc:title", "生成 OPF 缺少标题",
    )
  }
  let language = @spec.xml_escape(metadata.language)
  if !opf.contains("<dc:language>\{language}</dc:language>") {
    report.error(
      "OPF-012", "package/metadata/dc:language", "生成 OPF 缺少语言",
    )
  }
  let identifier = @spec.xml_escape(metadata.identifier)
  if !opf.contains("\{identifier}</dc:identifier>") {
    report.error(
      "OPF-012", "package/metadata/dc:identifier", "生成 OPF 缺少标识符",
    )
  }
  match metadata.modified {
    Some(modified) => {
      let value = @spec.xml_escape(modified)
      if !opf.contains(
          "<meta property=\"dcterms:modified\">" + value + "</meta>",
        ) {
        report.error(
          "OPF-012", "package/metadata/meta", "生成 OPF 缺少 dcterms:modified",
        )
      }
    }
    None =>
      report.error(
        "OPF-012", "package/metadata/meta", "生成 OPF 缺少 dcterms:modified",
      )
  }
  // 清单条目数量与逐条属性
  let item_count = count_occurrences(opf, "<item ")
  if item_count != manifest.length() {
    report.error(
      "OPF-013", "package/manifest", "生成 OPF 清单条目数量与模型不一致",
    )
  }
  for item in manifest.items {
    let id = @spec.xml_escape_attr(item.id)
    let href = @spec.xml_escape_attr(item.href)
    let media_type = @spec.xml_escape_attr(item.media_type)
    let needle = "<item id=\"" +
      id +
      "\" href=\"" +
      href +
      "\" media-type=\"" +
      media_type +
      "\""
    if !opf.contains(needle) {
      report.error(
        "OPF-013",
        "package/manifest/item#\{item.id}",
        "生成 OPF 缺少清单条目",
      )
    }
  }
  // 阅读顺序条目
  let itemref_count = count_occurrences(opf, "<itemref ")
  if itemref_count != spine.items.length() {
    report.error(
      "SPN-006", "package/spine", "生成 OPF 阅读顺序条目数量与模型不一致",
    )
  }
  for item in spine.items {
    let idref = @spec.xml_escape_attr(item.idref)
    let needle = "<itemref idref=\"" + idref + "\""
    if !opf.contains(needle) {
      report.error(
        "SPN-006",
        "package/spine/itemref#\{item.idref}",
        "生成 OPF 缺少阅读顺序条目",
      )
    }
  }
  // 导航目标：仅检查参与线性阅读顺序的内容文档，避免把非章节
  // XHTML 资源误判为缺失导航项。
  for spine_item in spine.items {
    if !spine_item.linear {
      continue
    }
    match manifest.find_by_id(spine_item.idref) {
      Some(item) =>
        if item.media_type == @spec.mt_xhtml &&
          !item.has_property(@spec.epub_property_nav) {
          let href = @spec.xml_escape_attr(item.href)
          if !nav.contains("href=\"\{href}\"") {
            report.error(
              "RCH-003",
              "nav#\{item.id}",
              "生成 nav.xhtml 缺少章节链接",
            )
          }
          if !ncx.contains("src=\"\{href}\"") {
            report.error(
              "RCH-003",
              "ncx#\{item.id}",
              "生成 toc.ncx 缺少章节链接",
            )
          }
        }
      None => ()
    }
  }
  // marc 等保留前缀不应重复声明
  if opf.contains("prefix=\"marc:") {
    report.warning(
      "OPF-014", "package", "生成 OPF 重复声明了保留前缀 marc",
    )
  }
  report
}
