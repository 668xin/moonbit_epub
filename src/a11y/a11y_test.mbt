///|
/// S6 可访问性元数据的单元测试。

///|
/// 数组是否包含给定值（避免依赖测试端的集合 API）。
fn has(values : Array[String], target : String) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
test "Accessibility: 空集合" {
  let a11y = Accessibility::new()
  assert_true(a11y.is_empty())
  assert_eq(a11y.meta_count(), 0)
}

///|
test "Accessibility::text_only 预设" {
  let a11y = Accessibility::text_only()
  assert_false(a11y.is_empty())
  assert_eq(a11y.access_modes, [@spec.access_mode_textual])
  assert_eq(a11y.access_mode_sufficient, [@spec.access_mode_textual])
  assert_true(has(a11y.features, @spec.feature_structural_navigation))
  assert_true(has(a11y.features, @spec.feature_table_of_contents))
  assert_eq(a11y.hazards, [@spec.hazard_none])
  assert_eq(a11y.conforms_to, Some(@spec.conforms_to_wcag_aa))
  // 访问模式 1 + 充分模式 1 + 特性 2 + 危害 1 + 符合性 1
  assert_eq(a11y.meta_count(), 6)
}

///|
test "Accessibility::audio_book 预设" {
  let a11y = Accessibility::audio_book()
  assert_eq(a11y.access_modes.length(), 2)
  assert_true(has(a11y.access_modes, @spec.access_mode_textual))
  assert_true(has(a11y.access_modes, @spec.access_mode_auditory))
  assert_eq(a11y.access_mode_sufficient.length(), 2)
  assert_true(has(a11y.hazards, @spec.hazard_none))
}

///|
test "Accessibility: 各项 setter 与计数" {
  let a11y = Accessibility::new()
  a11y.add_access_mode(@spec.access_mode_visual)
  a11y.add_access_mode_sufficient(@spec.access_mode_visual)
  a11y.add_feature(@spec.feature_alternative_text)
  a11y.add_hazard(@spec.hazard_flashing)
  a11y.add_control("fullKeyboardControl")
  a11y.set_summary("含少量插图。")
  a11y.set_conforms_to(@spec.conforms_to_wcag_aa)
  assert_false(a11y.is_empty())
  assert_eq(a11y.meta_count(), 7)
}

///|
test "to_metas: property + 文本内容形态与顺序" {
  let a11y = Accessibility::new()
  a11y.add_access_mode(@spec.access_mode_textual)
  a11y.add_feature(@spec.feature_alternative_text)
  a11y.set_summary("summary text")
  let metas = a11y.to_metas()
  assert_eq(metas.length(), 3)
  assert_eq(metas[0].property, Some("schema:accessMode"))
  assert_eq(metas[0].content, Some("textual"))
  assert_eq(metas[0].name, None)
  assert_eq(metas[1].property, Some("schema:accessibilityFeature"))
  assert_eq(metas[1].content, Some("alternativeText"))
  assert_eq(metas[2].property, Some("schema:accessibilitySummary"))
  assert_eq(metas[2].content, Some("summary text"))
}

///|
test "apply_to: 追加写入书籍元数据" {
  let metadata = @model.Metadata::new("T", "en", "urn:uuid:1")
  let before = metadata.metas.length()
  let a11y = Accessibility::text_only()
  a11y.apply_to(metadata)
  assert_eq(metadata.metas.length(), before + a11y.meta_count())
  assert_eq(metadata.metas[before].property, Some("schema:accessMode"))
  assert_eq(metadata.metas[before].content, Some("textual"))
}

///|
test "text_only: meta 属性与内容序列" {
  let a11y = Accessibility::text_only()
  let metas = a11y.to_metas()
  assert_eq(metas.length(), 6)
  assert_eq(metas[0].property, Some(@spec.prop_access_mode))
  assert_eq(metas[0].content, Some(@spec.access_mode_textual))
  assert_eq(metas[1].property, Some(@spec.prop_access_mode_sufficient))
  assert_eq(metas[1].content, Some(@spec.access_mode_textual))
  assert_eq(metas[2].property, Some(@spec.prop_accessibility_feature))
  assert_eq(metas[3].property, Some(@spec.prop_accessibility_feature))
  assert_eq(metas[4].property, Some(@spec.prop_accessibility_hazard))
  assert_eq(metas[4].content, Some(@spec.hazard_none))
  assert_eq(metas[5].property, Some(@spec.prop_conforms_to))
  assert_eq(metas[5].content, Some(@spec.conforms_to_wcag_aa))
}

///|
test "audio_book: meta 顺序与计数" {
  let a11y = Accessibility::audio_book()
  assert_eq(a11y.access_modes.length(), 2)
  assert_eq(a11y.access_mode_sufficient.length(), 2)
  let metas = a11y.to_metas()
  assert_eq(metas.length(), 7)
  assert_eq(a11y.meta_count(), 7)
  assert_eq(metas[0].property, Some(@spec.prop_access_mode))
  assert_eq(metas[0].content, Some(@spec.access_mode_textual))
  assert_eq(metas[1].property, Some(@spec.prop_access_mode))
  assert_eq(metas[1].content, Some(@spec.access_mode_auditory))
  assert_eq(metas[2].property, Some(@spec.prop_access_mode_sufficient))
  assert_eq(metas[3].property, Some(@spec.prop_access_mode_sufficient))
  assert_eq(metas[4].property, Some(@spec.prop_accessibility_feature))
  assert_eq(metas[5].property, Some(@spec.prop_accessibility_hazard))
  assert_eq(metas[6].property, Some(@spec.prop_conforms_to))
}

///|
test "to_metas: 控制、摘要与符合性顺序" {
  let a11y = Accessibility::new()
  a11y.add_control("fullKeyboardControl")
  a11y.add_control("fullMouseControl")
  a11y.set_summary("摘要文本")
  a11y.set_conforms_to(@spec.conforms_to_wcag_aa)
  let metas = a11y.to_metas()
  assert_eq(metas.length(), 4)
  assert_eq(metas[0].property, Some(@spec.prop_accessibility_control))
  assert_eq(metas[0].content, Some("fullKeyboardControl"))
  assert_eq(metas[1].property, Some(@spec.prop_accessibility_control))
  assert_eq(metas[1].content, Some("fullMouseControl"))
  assert_eq(metas[2].property, Some(@spec.prop_accessibility_summary))
  assert_eq(metas[2].content, Some("摘要文本"))
  assert_eq(metas[3].property, Some(@spec.prop_conforms_to))
}

///|
test "is_empty: 仅控制/摘要/符合性仍视为空" {
  let a11y = Accessibility::new()
  a11y.add_control("fullKeyboardControl")
  a11y.set_summary("摘要")
  a11y.set_conforms_to(@spec.conforms_to_wcag_aa)
  assert_true(a11y.is_empty())
  assert_eq(a11y.meta_count(), 3)
  a11y.add_access_mode_sufficient(@spec.access_mode_visual)
  assert_true(a11y.is_empty())
  a11y.add_feature(@spec.feature_long_description)
  assert_false(a11y.is_empty())
}

///|
test "apply_to: 空集合不产生元数据" {
  let metadata = @model.Metadata::new("T", "en", "urn:uuid:2")
  let before = metadata.metas.length()
  Accessibility::new().apply_to(metadata)
  assert_eq(metadata.metas.length(), before)
}

///|
test "apply_to: 保留既有元数据并追加" {
  let metadata = @model.Metadata::new("T", "en", "urn:uuid:3")
  metadata.add_meta(@model.Meta::named("cover", "cover-img"))
  let a11y = Accessibility::audio_book()
  a11y.apply_to(metadata)
  assert_eq(metadata.metas.length(), 1 + 7)
  assert_eq(metadata.metas[0].name, Some("cover"))
  assert_eq(metadata.metas[1].property, Some(@spec.prop_access_mode))
  assert_eq(metadata.metas[1].content, Some(@spec.access_mode_textual))
}

///|
test "add_*: 重复值按顺序保留" {
  let a11y = Accessibility::new()
  a11y.add_access_mode(@spec.access_mode_visual)
  a11y.add_access_mode(@spec.access_mode_visual)
  a11y.add_hazard(@spec.hazard_flashing)
  a11y.add_hazard(@spec.hazard_motion)
  assert_eq(a11y.access_modes.length(), 2)
  let metas = a11y.to_metas()
  assert_eq(metas.length(), 4)
  assert_eq(metas[0].content, Some(@spec.access_mode_visual))
  assert_eq(metas[1].content, Some(@spec.access_mode_visual))
  assert_eq(metas[2].content, Some(@spec.hazard_flashing))
  assert_eq(metas[3].content, Some(@spec.hazard_motion))
}

///|
test "to_metas: 均为 property/content 形态" {
  for meta in Accessibility::text_only().to_metas() {
    assert_eq(meta.name, None)
    assert_true(meta.property is Some(_))
    assert_true(meta.content is Some(_))
  }
}
