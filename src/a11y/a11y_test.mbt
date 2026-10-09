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
