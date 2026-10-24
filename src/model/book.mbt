///|
/// 书籍模型（S1）。
///
/// 聚合元数据、章节树、资源、清单与阅读顺序，是整个引擎的核心输入类型。

///|
/// 资源：容器内的非章节文件（样式表、图片、字体等）。
pub struct Resource {
  // 相对容器根目录的路径
  href : String
  media_type : String
  data : Bytes
  properties : Array[String]
} derive(@debug.Debug)

///|
/// 由原始字节构造资源。
pub fn Resource::new(
  href : String,
  media_type : String,
  data : Bytes,
) -> Resource {
  { href, media_type, data, properties: [], }
}

///|
/// 由文本构造资源，按 UTF-8 编码为字节。
pub fn Resource::text(
  href : String,
  media_type : String,
  text : String,
) -> Resource {
  { href, media_type, data: @utf8.encode(text), properties: [], }
}

///|
/// 由 CSS 文本构造样式表资源。
pub fn Resource::css(href : String, css : String) -> Resource {
  Resource::text(href, @spec.mt_css, css)
}

///|
/// 由资源路径派生默认清单 ID（经 `normalize_id` 规范化）。
pub fn resource_id(resource : Resource) -> String {
  @spec.normalize_id(resource_href(resource))
}

///|
/// 资源在容器内的规范化路径：统一分隔符、解析 `.` 与 `..`。
///
/// 空 href 保持为空，交由校验层报告。
pub fn resource_href(resource : Resource) -> String {
  if resource.href.is_empty() {
    ""
  } else {
    @spec.normalize_path(resource.href)
  }
}

///|
/// 章节节点：可嵌套的树结构。
pub struct Chapter {
  // XML ID，须在章节树内唯一
  id : String
  title : String
  // 正文内容块
  body : Array[Block]
  // 子章节
  children : Array[Chapter]
} derive(@debug.Debug)

///|
/// 构造空章节。
pub fn Chapter::new(id : String, title : String) -> Chapter {
  { id, title, body: [], children: [], }
}

///|
/// 构造带正文的章节。
pub fn Chapter::with_body(
  id : String,
  title : String,
  body : Array[Block],
) -> Chapter {
  { id, title, body, children: [], }
}

///|
/// 追加子章节。
pub fn Chapter::add_child(self : Chapter, child : Chapter) -> Unit {
  self.children.push(child)
}

///|
/// 深度优先遍历章节森林，`depth` 自 0 起。
pub fn walk_chapters(
  chapters : Array[Chapter],
  visit : (Int, Chapter) -> Unit,
) -> Unit {
  walk_into(chapters, 0, visit)
}

///|
/// 遍历的递归实现。
fn walk_into(
  chapters : Array[Chapter],
  depth : Int,
  visit : (Int, Chapter) -> Unit,
) -> Unit {
  for chapter in chapters {
    visit(depth, chapter)
    walk_into(chapter.children, depth + 1, visit)
  }
}

///|
/// 按深度优先顺序展平为数组。
pub fn flatten_chapters(chapters : Array[Chapter]) -> Array[Chapter] {
  let out : Array[Chapter] = []
  append_chapters(chapters, out)
  out
}

///|
/// 展平的递归实现。
fn append_chapters(chapters : Array[Chapter], out : Array[Chapter]) -> Unit {
  for chapter in chapters {
    out.push(chapter)
    append_chapters(chapter.children, out)
  }
}

///|
/// 按 ID 在章节树中查找，未命中返回 `None`。
pub fn find_chapter(chapters : Array[Chapter], id : String) -> Chapter? {
  for chapter in chapters {
    if chapter.id == id {
      return Some(chapter)
    }
    match find_chapter(chapter.children, id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
/// 章节总数（含各级子章节）。
pub fn count_chapters(chapters : Array[Chapter]) -> Int {
  let mut n = 0
  for chapter in chapters {
    n += 1 + count_chapters(chapter.children)
  }
  n
}

///|
/// 章节树的最大嵌套深度，空树为 0。
pub fn chapter_depth(chapters : Array[Chapter]) -> Int {
  let mut max = 0
  for chapter in chapters {
    let d = 1 + chapter_depth(chapter.children)
    if d > max {
      max = d
    }
  }
  max
}

///|
/// 章节对应的内容文档容器内路径：`text/<id>.xhtml`。
///
/// 章节 id 中的 `/`、`\`、`:` 会被替换为 `-`，避免生成越界或非法路径；
/// 合法的 XML ID 不受影响。
pub fn chapter_href(chapter : Chapter) -> String {
  @spec.path_join(
    @spec.default_text_dir,
    @spec.safe_path_segment(chapter.id) + ".xhtml",
  )
}

///|
/// 书籍：引擎的核心输入。
pub struct Book {
  metadata : Metadata
  // 顶层章节（章节森林）
  chapters : Array[Chapter]
  resources : Array[Resource]
  manifest : Manifest
  spine : Spine
} derive(@debug.Debug)

///|
/// 以元数据构造空书。
pub fn Book::new(metadata : Metadata) -> Book {
  {
    metadata,
    chapters: [],
    resources: [],
    manifest: Manifest::new(),
    spine: Spine::new(),
  }
}

///|
/// 追加顶层章节。
pub fn Book::add_chapter(self : Book, chapter : Chapter) -> Unit {
  self.chapters.push(chapter)
}

///|
/// 追加资源。
pub fn Book::add_resource(self : Book, resource : Resource) -> Unit {
  self.resources.push(resource)
}

///|
/// 登记清单条目，ID 重复时返回 `false`。
pub fn Book::add_manifest_item(self : Book, item : ManifestItem) -> Bool {
  self.manifest.add(item)
}

///|
/// 追加阅读顺序条目。
pub fn Book::add_spine_item(self : Book, item : SpineItem) -> Unit {
  self.spine.add(item)
}

///|
/// 章节总数。
pub fn Book::chapter_count(self : Book) -> Int {
  count_chapters(self.chapters)
}

///|
/// 按 ID 查找章节。
pub fn Book::find_chapter(self : Book, id : String) -> Chapter? {
  find_chapter(self.chapters, id)
}

///|
/// 章节树内 ID 是否全局唯一。
pub fn Book::has_unique_chapter_ids(self : Book) -> Bool {
  let seen : Map[String, Bool] = Map([])
  for chapter in flatten_chapters(self.chapters) {
    if seen.contains(chapter.id) {
      return false
    }
    seen.set(chapter.id, true)
  }
  true
}

///|
/// 复制书籍并替换元数据，其余字段共享引用。
pub fn Book::with_metadata(self : Book, metadata : Metadata) -> Book {
  {
    metadata,
    chapters: self.chapters,
    resources: self.resources,
    manifest: self.manifest,
    spine: self.spine,
  }
}

// ---------------------------------------------------------------------------
// 统一装配
// ---------------------------------------------------------------------------

///|
/// 把既有清单条目上的可定制字段合并到自动装配的条目。
///
/// 自动装配负责 `id` / `href` / `media-type` 与文件实际位置，故只继承
/// `properties`、`fallback` 与 `media-overlay`。
fn merge_manifest_fields(target : ManifestItem, source : ManifestItem) -> Unit {
  for property in source.properties {
    if !target.has_property(property) {
      target.add_property(property)
    }
  }
  match source.fallback {
    Some(fallback) => target.set_fallback(fallback)
    None => ()
  }
  match source.media_overlay {
    Some(media_overlay) => target.set_media_overlay(media_overlay)
    None => ()
  }
}

///|
/// 按 href 优先、id 次之查找既有清单条目。
fn find_existing_item(
  manifest : Manifest,
  href : String,
  id : String,
) -> ManifestItem? {
  match manifest.find_by_href(href) {
    Some(item) => Some(item)
    None => manifest.find_by_id(id)
  }
}

///|
/// 查找既有导航条目：优先 `properties` 含 `nav`，其次约定 id / 文件名。
fn find_nav_item(manifest : Manifest, nav_filename : String) -> ManifestItem? {
  for item in manifest.items {
    if item.has_property(@spec.epub_property_nav) {
      return Some(item)
    }
  }
  match manifest.find_by_id(@spec.manifest_id_nav) {
    Some(item) => Some(item)
    None => manifest.find_by_href(nav_filename)
  }
}

///|
/// 依据章节树与资源装配清单：导航、NCX、各章节内容文档与全部资源。
///
/// 章节以 `chapter.id` 作为清单 ID；资源 ID 由其 href 规范化得到，
/// ID 冲突时后续条目被忽略（`Manifest::add` 拒绝重复）。
/// 若书籍已自行登记同名 / 同 href 条目，其 `properties`、`fallback` 与
/// `media-overlay` 会被继承，避免端到端打包丢失用户的清单定制。
fn assemble_manifest(
  book : Book,
  nav_filename : String,
  ncx_filename : String,
) -> Manifest {
  let manifest = Manifest::new()
  let nav_item = ManifestItem::new(
    @spec.manifest_id_nav, nav_filename, @spec.mt_xhtml,
  )
  nav_item.add_property(@spec.epub_property_nav)
  match find_nav_item(book.manifest, nav_filename) {
    Some(existing) => merge_manifest_fields(nav_item, existing)
    None => ()
  }
  let _ = manifest.add(nav_item)
  let ncx_item = ManifestItem::new(
    @spec.manifest_id_ncx, ncx_filename, @spec.mt_ncx,
  )
  match find_existing_item(book.manifest, ncx_filename, @spec.manifest_id_ncx) {
    Some(existing) => merge_manifest_fields(ncx_item, existing)
    None => ()
  }
  let _ = manifest.add(ncx_item)
  for chapter in flatten_chapters(book.chapters) {
    let href = chapter_href(chapter)
    let item = ManifestItem::new(chapter.id, href, @spec.mt_xhtml)
    match find_existing_item(book.manifest, href, chapter.id) {
      Some(existing) => merge_manifest_fields(item, existing)
      None => ()
    }
    let _ = manifest.add(item)
  }
  for resource in book.resources {
    let href = resource_href(resource)
    let id = resource_id(resource)
    let item = ManifestItem::new(id, href, resource.media_type)
    for property in resource.properties {
      if !item.has_property(property) {
        item.add_property(property)
      }
    }
    match find_existing_item(book.manifest, href, id) {
      Some(existing) => merge_manifest_fields(item, existing)
      None => ()
    }
    let _ = manifest.add(item)
  }
  manifest
}

///|
/// 依据章节树装配阅读顺序：优先沿用书籍已定义的 `spine`，为空时按
/// 章节树深度优先顺序生成；`spine@toc` 默认指向 NCX 条目。
fn assemble_spine(book : Book) -> Spine {
  let spine = Spine::new()
  if book.spine.items.length() > 0 {
    for item in book.spine.items {
      spine.add(item)
    }
    match book.spine.toc {
      Some(toc) => spine.set_toc(toc)
      None => spine.set_toc(@spec.manifest_id_ncx)
    }
  } else {
    spine.set_toc(@spec.manifest_id_ncx)
    for chapter in flatten_chapters(book.chapters) {
      spine.add(SpineItem::new(chapter.id))
    }
  }
  match book.spine.page_progression_direction {
    Some(direction) => spine.set_page_progression_direction(direction)
    None => ()
  }
  spine
}

///|
/// 装配出可打包的书籍视图：补齐导航 / NCX / 章节 / 资源清单与阅读顺序。
///
/// 返回新的 `Book`，不修改调用方对象；章节与资源数组共享引用。
/// 未设置 `dcterms:modified` 时注入确定性默认值，保证产物可复现且符合
/// EPUB 3 的必需元数据要求。`PackageOptions` 可覆盖导航 / NCX 文件名。
pub fn assemble_book(
  book : Book,
  nav_filename? : String,
  ncx_filename? : String,
) -> Book {
  let nav_filename = nav_filename.unwrap_or(@spec.default_nav_filename)
  let ncx_filename = ncx_filename.unwrap_or(@spec.default_ncx_filename)
  let metadata = match book.metadata.modified {
    Some(_) => book.metadata
    None => book.metadata.with_modified(@spec.default_modified)
  }
  {
    metadata,
    chapters: book.chapters,
    resources: book.resources,
    manifest: assemble_manifest(book, nav_filename, ncx_filename),
    spine: assemble_spine(book),
  }
}
