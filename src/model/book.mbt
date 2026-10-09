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
  @spec.normalize_id(resource.href)
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
pub fn chapter_href(chapter : Chapter) -> String {
  @spec.path_join(@spec.default_text_dir, chapter.id + ".xhtml")
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
