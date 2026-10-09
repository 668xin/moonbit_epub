///|
/// 资源登记表（S5）。
///
/// 集中登记样式表、图片与字体等静态资源，按规范化后的 href 去重，
/// 并可直接产出包文档清单条目，避免上层自行维护去重逻辑。

///|
/// 资源登记表：保持登记顺序，重复 href 被忽略。
pub struct ResourceRegistry {
  resources : Array[@model.Resource]
} derive(@debug.Debug)

///|
/// 构造空的资源登记表。
pub fn ResourceRegistry::new() -> ResourceRegistry {
  { resources: [], }
}

///|
/// 登记一个资源；href 已存在时返回 `false` 且不重复登记。
pub fn ResourceRegistry::add(
  self : ResourceRegistry,
  resource : @model.Resource,
) -> Bool {
  if self.contains(resource.href) {
    false
  } else {
    self.resources.push(resource)
    true
  }
}

///|
/// 登记样式表资源：href 经路径规范化，Media Type 固定为 `text/css`。
pub fn ResourceRegistry::add_stylesheet(
  self : ResourceRegistry,
  href : String,
  css : String,
) -> Bool {
  self.add(@model.Resource::css(@spec.normalize_path(href), css))
}

///|
/// 由原始字节登记资源，Media Type 依据 href 扩展名推断。
pub fn ResourceRegistry::register(
  self : ResourceRegistry,
  href : String,
  data : Bytes,
) -> Bool {
  let path = @spec.normalize_path(href)
  self.add(@model.Resource::new(path, mime_type_of(path), data))
}

///|
/// 是否已登记给定 href。
pub fn ResourceRegistry::contains(
  self : ResourceRegistry,
  href : String,
) -> Bool {
  for resource in self.resources {
    if resource.href == href {
      return true
    }
  }
  false
}

///|
/// 按 href 查找资源。
pub fn ResourceRegistry::find(
  self : ResourceRegistry,
  href : String,
) -> @model.Resource? {
  for resource in self.resources {
    if resource.href == href {
      return Some(resource)
    }
  }
  None
}

///|
/// 已登记的资源数量。
pub fn ResourceRegistry::length(self : ResourceRegistry) -> Int {
  self.resources.length()
}

///|
/// 是否为空。
pub fn ResourceRegistry::is_empty(self : ResourceRegistry) -> Bool {
  self.resources.is_empty()
}

///|
/// 按 Media Type 前缀筛选资源（如 `image/`、`font/`）。
pub fn ResourceRegistry::by_prefix(
  self : ResourceRegistry,
  prefix : String,
) -> Array[@model.Resource] {
  let out : Array[@model.Resource] = []
  for resource in self.resources {
    if resource.media_type.has_prefix(prefix) {
      out.push(resource)
    }
  }
  out
}

///|
/// 以登记顺序导出资源副本。
pub fn ResourceRegistry::resources(
  self : ResourceRegistry,
) -> Array[@model.Resource] {
  let out : Array[@model.Resource] = []
  for resource in self.resources {
    out.push(resource)
  }
  out
}

///|
/// 产出的包文档清单条目：ID 由 href 规范化得到，与打包层约定一致。
pub fn ResourceRegistry::manifest_items(
  self : ResourceRegistry,
) -> Array[@model.ManifestItem] {
  let out : Array[@model.ManifestItem] = []
  for resource in self.resources {
    out.push(
      @model.ManifestItem::new(
        @model.resource_id(resource),
        resource.href,
        resource.media_type,
      ),
    )
  }
  out
}
