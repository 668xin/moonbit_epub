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

///|
test "base_stylesheet: 关键排版规则齐全" {
  assert_false(base_stylesheet.is_empty())
  assert_true(base_stylesheet.contains("line-height: 1.6"))
  assert_true(base_stylesheet.contains("text-align: justify"))
  assert_true(base_stylesheet.contains("blockquote"))
  assert_true(base_stylesheet.contains("border-collapse"))
  assert_true(base_stylesheet.contains("page-break-after: avoid"))
  assert_true(base_stylesheet.contains("max-width: 100%"))
  assert_true(base_stylesheet.contains(".footnote"))
}

///|
test "compose_stylesheet: 换行拼接与空白自定义" {
  assert_eq(compose_stylesheet("   "), base_stylesheet + "\n   ")
  assert_eq(compose_stylesheet("p{}"), base_stylesheet + "\np{}")
}

///|
test "stylesheet_resource: 空自定义与内置资源字节一致" {
  let custom = stylesheet_resource("s.css", "")
  let base = base_stylesheet_resource("s.css")
  assert_eq(custom.media_type, @spec.mt_css)
  assert_eq(custom.href, "s.css")
  assert_eq(custom.data.length(), base.data.length())
  let mut same = true
  for i in 0..<custom.data.length() {
    if custom.data[i] != base.data[i] {
      same = false
    }
  }
  assert_true(same)
}

///|
test "stylesheet_resource: 自定义样式位于内置之后" {
  let res = stylesheet_resource("../styles/custom.css", ".x {}")
  assert_eq(res.href, "../styles/custom.css")
  assert_eq(res.media_type, @spec.mt_css)
  assert_eq(
    res.data.length(),
    @spec.utf8_len(base_stylesheet) + 1 + @spec.utf8_len(".x {}"),
  )
}

///|
test "mime_type_of: 扩展名映射覆盖" {
  assert_eq(mime_type_of("a.htm"), "text/html")
  assert_eq(mime_type_of("a.html"), "text/html")
  assert_eq(mime_type_of("a.xht"), @spec.mt_xhtml)
  assert_eq(mime_type_of("a.xml"), @spec.mt_xml)
  assert_eq(mime_type_of("a.opf"), @spec.mt_opf)
  assert_eq(mime_type_of("a.ncx"), @spec.mt_ncx)
  assert_eq(mime_type_of("a.js"), @spec.mt_js)
  assert_eq(mime_type_of("a.txt"), @spec.mt_txt)
  assert_eq(mime_type_of("a.gif"), @spec.mt_gif)
  assert_eq(mime_type_of("a.svg"), @spec.mt_svg)
  assert_eq(mime_type_of("a.webp"), @spec.mt_webp)
  assert_eq(mime_type_of("a.jpe"), @spec.mt_jpeg)
  assert_eq(mime_type_of("a.m4a"), @spec.mt_mp4)
  assert_eq(mime_type_of("a.m4b"), @spec.mt_mp4)
  assert_eq(mime_type_of("a.mp4"), @spec.mt_mp4)
  assert_eq(mime_type_of("a.oga"), @spec.mt_ogg)
  assert_eq(mime_type_of("a.ttf"), @spec.mt_ttf)
  assert_eq(mime_type_of("a.otf"), @spec.mt_otf)
  assert_eq(mime_type_of("a.woff"), @spec.mt_woff)
}

///|
test "mime_type_of: 反斜杠、查询串与片段处理" {
  assert_eq(mime_type_of("dir\\sub\\cover.PNG"), @spec.mt_png)
  assert_eq(mime_type_of("a/b/logo.svg#icon"), @spec.mt_svg)
  assert_eq(mime_type_of("a/b/photo.jpg?w=10&h=20"), @spec.mt_jpeg)
  assert_eq(mime_type_of("CSS.CSS"), @spec.mt_css)
  assert_eq(mime_type_of(""), @spec.mt_octet_stream)
  assert_eq(mime_type_of("name."), @spec.mt_octet_stream)
}

///|
test "is_image_type / is_font_type: 前缀判定" {
  assert_true(is_image_type(@spec.mt_png))
  assert_true(is_image_type(@spec.mt_jpeg))
  assert_true(is_image_type(@spec.mt_gif))
  assert_true(is_image_type(@spec.mt_svg))
  assert_true(is_image_type(@spec.mt_webp))
  assert_false(is_image_type(@spec.mt_mp3))
  assert_false(is_image_type(@spec.mt_css))
  assert_true(is_font_type(@spec.mt_ttf))
  assert_true(is_font_type(@spec.mt_otf))
  assert_true(is_font_type(@spec.mt_woff))
  assert_true(is_font_type(@spec.mt_woff2))
  assert_false(is_font_type(@spec.mt_png))
}

///|
test "ResourceRegistry: register 规范化路径去重" {
  let registry = ResourceRegistry::new()
  assert_true(registry.register("images/./cover.png", b"a"))
  assert_false(registry.register("images/cover.png", b"b"))
  assert_eq(registry.length(), 1)
  assert_true(registry.contains("images/cover.png"))
  let found = registry.find("images/cover.png").unwrap()
  assert_eq(found.media_type, @spec.mt_png)
  assert_eq(found.data.length(), 1)
}

///|
test "ResourceRegistry: by_prefix 筛选与空表" {
  let empty = ResourceRegistry::new()
  assert_true(empty.is_empty())
  assert_eq(empty.length(), 0)
  assert_eq(empty.by_prefix("image/").length(), 0)
  assert_true(empty.find("x") is None)
  let registry = ResourceRegistry::new()
  let _ = registry.register("images/a.png", b"x")
  let _ = registry.register("images/b.jpg", b"x")
  let _ = registry.register("fonts/c.woff2", b"x")
  let _ = registry.register("audio/d.mp3", b"x")
  assert_eq(registry.by_prefix("image/").length(), 2)
  assert_eq(registry.by_prefix("font/").length(), 1)
  assert_eq(registry.by_prefix("audio/").length(), 1)
  assert_eq(registry.by_prefix("text/").length(), 0)
}

///|
test "ResourceRegistry: manifest_items 产出 ID 与顺序" {
  let registry = ResourceRegistry::new()
  let _ = registry.register("images/cover.png", b"x")
  let _ = registry.add_stylesheet("styles/main.css", "body{}")
  let _ = registry.register("fonts/serif.woff2", b"x")
  let items = registry.manifest_items()
  assert_eq(items.length(), 3)
  assert_eq(items[0].id, "images-cover.png")
  assert_eq(items[0].media_type, @spec.mt_png)
  assert_eq(items[1].id, "styles-main.css")
  assert_eq(items[1].media_type, @spec.mt_css)
  assert_eq(items[2].id, "fonts-serif.woff2")
  assert_eq(items[2].media_type, @spec.mt_woff2)
}

///|
test "ResourceRegistry: resources 返回独立副本" {
  let registry = ResourceRegistry::new()
  let _ = registry.register("a.png", b"x")
  let _ = registry.register("b.png", b"y")
  let copy = registry.resources()
  assert_eq(copy.length(), 2)
  let _ = copy.pop()
  assert_eq(copy.length(), 1)
  assert_eq(registry.length(), 2)
}
