///|
/// 可访问性元数据（S6）。
///
/// 依据 EPUB Accessibility / schema.org 词汇描述出版物的访问模式、可访问性
/// 特性、危害、控制方式与符合性声明，产出可并入包文档元数据区的 `meta`
/// 条目（`property` + 文本内容形态）。

///|
/// 可访问性元数据集合。
pub struct Accessibility {
  access_modes : Array[String]
  access_mode_sufficient : Array[String]
  features : Array[String]
  hazards : Array[String]
  controls : Array[String]
  mut summary : String?
  mut conforms_to : String?
} derive(@debug.Debug)

///|
/// 构造空的可访问性元数据集合。
pub fn Accessibility::new() -> Accessibility {
  {
    access_modes: [],
    access_mode_sufficient: [],
    features: [],
    hazards: [],
    controls: [],
    summary: None,
    conforms_to: None,
  }
}

///|
/// 纯文本出版物预设：文本访问模式，结构化导航与目录特性，声明无危害，
/// 并给出 EPUB Accessibility 1.1 / WCAG 2.0 AA 符合性。
pub fn Accessibility::text_only() -> Accessibility {
  let a11y = Accessibility::new()
  a11y.add_access_mode(@spec.access_mode_textual)
  a11y.add_access_mode_sufficient(@spec.access_mode_textual)
  a11y.add_feature(@spec.feature_structural_navigation)
  a11y.add_feature(@spec.feature_table_of_contents)
  a11y.add_hazard(@spec.hazard_none)
  a11y.set_conforms_to(@spec.conforms_to_wcag_aa)
  a11y
}

///|
/// 有声书预设：文本与听觉两种访问模式，声明无危害，并给出符合性。
pub fn Accessibility::audio_book() -> Accessibility {
  let a11y = Accessibility::new()
  a11y.add_access_mode(@spec.access_mode_textual)
  a11y.add_access_mode(@spec.access_mode_auditory)
  a11y.add_access_mode_sufficient(@spec.access_mode_textual)
  a11y.add_access_mode_sufficient(@spec.access_mode_auditory)
  a11y.add_feature(@spec.feature_structural_navigation)
  a11y.add_hazard(@spec.hazard_none)
  a11y.set_conforms_to(@spec.conforms_to_wcag_aa)
  a11y
}

///|
/// 追加一种访问模式（`visual` / `textual` / `auditory`）。
pub fn Accessibility::add_access_mode(
  self : Accessibility,
  mode : String,
) -> Unit {
  self.access_modes.push(mode)
}

///|
/// 追加一种充分访问模式。
pub fn Accessibility::add_access_mode_sufficient(
  self : Accessibility,
  mode : String,
) -> Unit {
  self.access_mode_sufficient.push(mode)
}

///|
/// 追加一项可访问性特性。
pub fn Accessibility::add_feature(
  self : Accessibility,
  feature : String,
) -> Unit {
  self.features.push(feature)
}

///|
/// 追加一项可访问性危害。
pub fn Accessibility::add_hazard(self : Accessibility, hazard : String) -> Unit {
  self.hazards.push(hazard)
}

///|
/// 追加一种可访问性控制方式（如 `fullKeyboardControl`）。
pub fn Accessibility::add_control(
  self : Accessibility,
  control : String,
) -> Unit {
  self.controls.push(control)
}

///|
/// 设置可访问性摘要。
pub fn Accessibility::set_summary(
  self : Accessibility,
  summary : String,
) -> Unit {
  self.summary = Some(summary)
}

///|
/// 设置符合性声明文本。
pub fn Accessibility::set_conforms_to(
  self : Accessibility,
  value : String,
) -> Unit {
  self.conforms_to = Some(value)
}

///|
/// 是否未声明任何访问模式与特性。
pub fn Accessibility::is_empty(self : Accessibility) -> Bool {
  self.access_modes.is_empty() && self.features.is_empty()
}

///|
/// 产出 `meta` 条目：按访问模式、充分模式、特性、危害、控制、摘要、
/// 符合性的顺序排列。
pub fn Accessibility::to_metas(self : Accessibility) -> Array[@model.Meta] {
  let out : Array[@model.Meta] = []
  for mode in self.access_modes {
    out.push(@model.Meta::of_property_content(@spec.prop_access_mode, mode))
  }
  for mode in self.access_mode_sufficient {
    out.push(
      @model.Meta::of_property_content(@spec.prop_access_mode_sufficient, mode),
    )
  }
  for feature in self.features {
    out.push(
      @model.Meta::of_property_content(
        @spec.prop_accessibility_feature, feature,
      ),
    )
  }
  for hazard in self.hazards {
    out.push(
      @model.Meta::of_property_content(@spec.prop_accessibility_hazard, hazard),
    )
  }
  for control in self.controls {
    out.push(
      @model.Meta::of_property_content(
        @spec.prop_accessibility_control, control,
      ),
    )
  }
  match self.summary {
    Some(summary) =>
      out.push(
        @model.Meta::of_property_content(
          @spec.prop_accessibility_summary, summary,
        ),
      )
    None => ()
  }
  match self.conforms_to {
    Some(value) =>
      out.push(@model.Meta::of_property_content(@spec.prop_conforms_to, value))
    None => ()
  }
  out
}

///|
/// 把可访问性 `meta` 条目追加写入给定书籍元数据。
pub fn Accessibility::apply_to(
  self : Accessibility,
  metadata : @model.Metadata,
) -> Unit {
  for meta in self.to_metas() {
    metadata.add_meta(meta)
  }
}

///|
/// 产出的 `meta` 条目数量。
pub fn Accessibility::meta_count(self : Accessibility) -> Int {
  self.to_metas().length()
}
