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
  for item in manifest.items {
    let location = if item.id.is_empty() {
      "package/manifest/item"
    } else {
      "package/manifest/item#\{item.id}"
    }
    if item.id.is_empty() || !@spec.is_valid_id(item.id) {
      report.error("OPF-003", location, "清单条目 id 为空或非法")
    }
    if item.href.is_empty() {
      report.error("OPF-004", location, "清单条目 href 为空")
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
    if !resource.href.is_empty() && !manifest.has_href(resource.href) {
      report.error(
        "RCH-002",
        "resource#\{resource.href}",
        "资源 \{resource.href} 未登记于清单",
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
/// 对书籍模型做完整的模型级校验：元数据、章节、资源、清单、阅读顺序与可达性。
pub fn validate_book(book : @model.Book) -> Report {
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
