///|
/// MIME 类型推断（S5）。
///
/// 统一委托给规范常量层的 `@spec.media_type_of_path`，保证资源登记与
/// 结构校验使用同一套扩展名规则；未识别时回退为通用二进制类型。

///|
/// 依据路径扩展名推断 MIME 类型，未知扩展名回退为 `application/octet-stream`。
pub fn mime_type_of(path : String) -> String {
  @spec.media_type_of_path(path)
}

///|
/// 判断推断出的 MIME 类型是否属于图片。
pub fn is_image_type(media_type : String) -> Bool {
  media_type.has_prefix("image/")
}

///|
/// 判断推断出的 MIME 类型是否属于字体。
pub fn is_font_type(media_type : String) -> Bool {
  media_type.has_prefix("font/")
}
