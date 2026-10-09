///|
/// 清单与阅读顺序模型（S1）。
///
/// 对应 OPF 的 `manifest` 与 `spine`：前者登记容器内全部资源，
/// 后者定义线性阅读顺序，两者通过 XML ID 相互引用。

///|
/// 清单条目，对应 `manifest/item`。
pub struct ManifestItem {
  // XML ID，在清单内必须唯一
  id : String
  // 相对容器根目录的路径
  href : String
  media_type : String
  // EPUB 3 `properties` 属性，如 `nav`、`cover-image`、`scripted`
  properties : Array[String]
  fallback : String?
  media_overlay : String?
} derive(Eq, @debug.Debug)

///|
/// 构造清单条目。
pub fn ManifestItem::new(
  id : String,
  href : String,
  media_type : String,
) -> ManifestItem {
  { id, href, media_type, properties: [], fallback: None, media_overlay: None, }
}

///|
/// 追加一个 `properties` 属性值。
pub fn ManifestItem::add_property(
  self : ManifestItem,
  property : String,
) -> Unit {
  self.properties.push(property)
}

///|
/// 判断是否声明了某个 `properties` 属性值。
pub fn ManifestItem::has_property(
  self : ManifestItem,
  property : String,
) -> Bool {
  for p in self.properties {
    if p == property {
      return true
    }
  }
  false
}

///|
/// 阅读顺序条目，对应 `spine/itemref`。
pub struct SpineItem {
  // 指向清单条目的 id
  idref : String
  // 是否参与线性阅读顺序
  linear : Bool
  properties : Array[String]
} derive(Eq, @debug.Debug)

///|
/// 构造阅读顺序条目，默认线性。
pub fn SpineItem::new(idref : String) -> SpineItem {
  { idref, linear: true, properties: [], }
}

///|
/// 构造不参与线性阅读顺序的条目。
pub fn SpineItem::non_linear(idref : String) -> SpineItem {
  { idref, linear: false, properties: [], }
}

///|
/// 阅读顺序，对应 `spine`。
pub struct Spine {
  items : Array[SpineItem]
  // `spine@toc`，指向 toc.ncx 的清单 id（EPUB 2 兼容）
  mut toc : String?
  // `spine@page-progression-direction`：`ltr` / `rtl` / `default`
  page_progression_direction : String?
} derive(Eq, @debug.Debug)

///|
/// 构造空的阅读顺序。
pub fn Spine::new() -> Spine {
  { items: [], toc: None, page_progression_direction: None, }
}

///|
/// 追加阅读顺序条目。
pub fn Spine::add(self : Spine, item : SpineItem) -> Unit {
  self.items.push(item)
}

///|
/// 全部 `idref`，按阅读顺序。
pub fn Spine::idrefs(self : Spine) -> Array[String] {
  let out : Array[String] = []
  for item in self.items {
    out.push(item.idref)
  }
  out
}

///|
/// 是否包含指定 `idref`。
pub fn Spine::contains(self : Spine, idref : String) -> Bool {
  for item in self.items {
    if item.idref == idref {
      return true
    }
  }
  false
}

///|
/// 设置 `spine@toc`，指向 toc.ncx 的清单 id。
pub fn Spine::set_toc(self : Spine, toc : String) -> Unit {
  self.toc = Some(toc)
}

///|
/// 清单，对应 `manifest`。
///
/// 内部维护 `id -> 下标` 索引，`add` 时强制 ID 唯一。
pub struct Manifest {
  items : Array[ManifestItem]
  priv index : Map[String, Int]
} derive(@debug.Debug)

///|
/// 构造空清单。
pub fn Manifest::new() -> Manifest {
  { items: [], index: Map([]), }
}

///|
/// 登记清单条目，ID 重复时拒绝并返回 `false`。
pub fn Manifest::add(self : Manifest, item : ManifestItem) -> Bool {
  if self.index.contains(item.id) {
    return false
  }
  self.index.set(item.id, self.items.length())
  self.items.push(item)
  true
}

///|
/// 是否已登记指定 ID。
pub fn Manifest::has_id(self : Manifest, id : String) -> Bool {
  self.index.contains(id)
}

///|
/// 按 ID 查找清单条目。
pub fn Manifest::find_by_id(self : Manifest, id : String) -> ManifestItem? {
  match self.index.get(id) {
    Some(i) => Some(self.items[i])
    None => None
  }
}

///|
/// 按 href 查找清单条目（线性扫描）。
pub fn Manifest::find_by_href(self : Manifest, href : String) -> ManifestItem? {
  for item in self.items {
    if item.href == href {
      return Some(item)
    }
  }
  None
}

///|
/// 是否已登记指定 href。
pub fn Manifest::has_href(self : Manifest, href : String) -> Bool {
  match self.find_by_href(href) {
    Some(_) => true
    None => false
  }
}

///|
/// 条目数量。
pub fn Manifest::length(self : Manifest) -> Int {
  self.items.length()
}
