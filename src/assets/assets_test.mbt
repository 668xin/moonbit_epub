///|
/// S5 样式与资源管理的单元测试。

///|
test "base_stylesheet: 非空且覆盖基本排版" {
  assert_true(base_stylesheet.contains("body"))
  assert_true(base_stylesheet.contains("line-height"))
  assert_true(base_stylesheet.contains("img"))
}

///|
test "compose_stylesheet: 自定义样式后置以覆盖基础样式" {
  assert_eq(compose_stylesheet(""), base_stylesheet)
  let merged = compose_stylesheet("body { color: red; }")
  assert_true(merged.has_prefix(base_stylesheet))
  assert_true(merged.has_suffix("body { color: red; }"))
}

///|
test "stylesheet_resource: 内置与合并两种构造" {
  let base = base_stylesheet_resource("styles/base.css")
  assert_eq(base.href, "styles/base.css")
  assert_eq(base.media_type, @spec.mt_css)
  let css = "p { color: blue; }"
  let custom = stylesheet_resource("styles/custom.css", css)
  assert_eq(custom.media_type, @spec.mt_css)
  assert_eq(custom.data.length(), @spec.utf8_len(compose_stylesheet(css)))
  assert_true(custom.data.length() > base.data.length())
}

///|
test "mime_type_of: 常见扩展名推断" {
  assert_eq(mime_type_of("styles/style.css"), @spec.mt_css)
  assert_eq(mime_type_of("images/Cover.PNG"), @spec.mt_png)
  assert_eq(mime_type_of("images/photo.jpeg"), @spec.mt_jpeg)
  assert_eq(mime_type_of("fonts/book.woff2"), @spec.mt_woff2)
  assert_eq(mime_type_of("text/ch1.xhtml"), @spec.mt_xhtml)
  assert_eq(mime_type_of("audio/track.mp3"), @spec.mt_mp3)
}

///|
test "mime_type_of: 无扩展名与未知扩展名回退" {
  assert_eq(mime_type_of("README"), @spec.mt_octet_stream)
  assert_eq(mime_type_of(".gitignore"), @spec.mt_octet_stream)
  assert_eq(mime_type_of("data/archive.tar.gz"), @spec.mt_octet_stream)
  assert_eq(mime_type_of("styles/style.css?v=1"), @spec.mt_css)
  assert_eq(mime_type_of("a/b/style.CsS"), @spec.mt_css)
}

///|
test "is_image_type / is_font_type" {
  assert_true(is_image_type(mime_type_of("a.png")))
  assert_false(is_image_type(mime_type_of("a.css")))
  assert_true(is_font_type(mime_type_of("a.woff")))
  assert_false(is_font_type(mime_type_of("a.png")))
}

///|
test "ResourceRegistry: 按 href 去重" {
  let registry = ResourceRegistry::new()
  assert_true(registry.is_empty())
  assert_true(registry.add_stylesheet("styles/style.css", "body {}"))
  assert_false(
    registry.add_stylesheet("styles/style.css", "body { color: red }"),
  )
  assert_eq(registry.length(), 1)
  assert_true(registry.contains("styles/style.css"))
  assert_false(registry.contains("styles/none.css"))
}

///|
test "ResourceRegistry: href 路径规范化" {
  let registry = ResourceRegistry::new()
  assert_true(registry.add_stylesheet("./styles//a.css", "x"))
  assert_eq(registry.length(), 1)
  assert_true(registry.contains("styles/a.css"))
  assert_false(registry.add_stylesheet("styles/b/../a.css", "y"))
  assert_eq(registry.length(), 1)
}

///|
test "ResourceRegistry: register 推断类型并可按前缀筛选" {
  let registry = ResourceRegistry::new()
  assert_true(registry.register("images/cover.png", b"PNGDATA"))
  assert_true(registry.register("fonts/serif.woff", b"WOFFDATA"))
  assert_true(registry.register("misc/blob.bin", b"BIN"))
  assert_eq(registry.length(), 3)
  assert_eq(registry.find("images/cover.png").unwrap().media_type, @spec.mt_png)
  assert_eq(registry.by_prefix("image/").length(), 1)
  assert_eq(registry.by_prefix("font/").length(), 1)
  assert_true(registry.find("absent") is None)
}

///|
test "ResourceRegistry: 清单条目 ID 与顺序" {
  let registry = ResourceRegistry::new()
  let _ = registry.add_stylesheet("styles/style.css", "body {}")
  let _ = registry.register("images/cover.png", b"x")
  let items = registry.manifest_items()
  assert_eq(items.length(), 2)
  assert_eq(items[0].id, "styles-style.css")
  assert_eq(items[0].href, "styles/style.css")
  assert_eq(items[0].media_type, @spec.mt_css)
  assert_eq(items[1].id, "images-cover.png")
  assert_eq(items[1].media_type, @spec.mt_png)
  let copy = registry.resources()
  assert_eq(copy.length(), 2)
}
