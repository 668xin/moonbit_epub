///|
/// MIME 类型推断（S5）。
///
/// 依据资源路径的扩展名推断 Media Type，覆盖 EPUB 常用的图片、字体、
/// 音频、样式与文本类型；无法识别时回退为通用二进制类型。

///|
/// 取路径的文件名扩展名：小写、不含点。
///
/// 仅以点开头的隐藏文件、无扩展名者返回空串；`/`、`\` 之后重新计数，
/// 查询串与片段（`?`、`#` 起）不参与判定。
fn extension_of(path : String) -> String {
  let chars = path.to_array()
  let n = chars.length()
  let mut seg_start = 0
  let mut dot = -1
  let mut end = n
  let mut i = 0
  while i < n {
    let c = chars[i]
    if c == '?' || c == '#' {
      end = i
      break
    } else if c == '/' || c == '\\' {
      seg_start = i + 1
      dot = -1
    } else if c == '.' {
      dot = i
    }
    i += 1
  }
  if dot <= seg_start {
    return ""
  }
  let start = dot + 1
  let out : Array[Char] = []
  for j in start..<end {
    let v = chars[j].to_int()
    if v >= 65 && v <= 90 {
      out.push(Int::unsafe_to_char(v + 32))
    } else {
      out.push(chars[j])
    }
  }
  String::from_array(out)
}

///|
/// 依据路径扩展名推断 MIME 类型，未知扩展名回退为 `application/octet-stream`。
pub fn mime_type_of(path : String) -> String {
  match extension_of(path) {
    "css" => @spec.mt_css
    "xhtml" | "xht" => @spec.mt_xhtml
    "html" | "htm" => "text/html"
    "xml" => @spec.mt_xml
    "opf" => @spec.mt_opf
    "ncx" => @spec.mt_ncx
    "js" => @spec.mt_js
    "txt" => @spec.mt_txt
    "png" => @spec.mt_png
    "jpg" | "jpeg" | "jpe" => @spec.mt_jpeg
    "gif" => @spec.mt_gif
    "svg" => @spec.mt_svg
    "webp" => @spec.mt_webp
    "mp3" => @spec.mt_mp3
    "mp4" | "m4a" | "m4b" => @spec.mt_mp4
    "ogg" | "oga" => @spec.mt_ogg
    "ttf" => @spec.mt_ttf
    "otf" => @spec.mt_otf
    "woff" => @spec.mt_woff
    "woff2" => @spec.mt_woff2
    _ => @spec.mt_octet_stream
  }
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
