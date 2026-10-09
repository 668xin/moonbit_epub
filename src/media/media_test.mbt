///|
/// S6 Media Overlays（SMIL）的单元测试。

///|
/// 构造一个含单个序列与两个 `par` 的覆盖文档。
fn sample_overlay() -> Overlay {
  let clip1 = AudioClip::from_millis("audio/ch1.mp3", 0, 5000)
  let clip2 = AudioClip::from_millis("audio/ch1.mp3", 5000, 12000)
  let seq = Seq::new(
    "seq-1",
    "text/ch1.xhtml",
    epub_type=@spec.epub_type_bodymatter,
  )
  seq.add_par(Par::new("par-1", "text/ch1.xhtml#p-1", clip1))
  seq.add_par(Par::new("par-2", "text/ch1.xhtml#p-2", clip2))
  let overlay = Overlay::new()
  overlay.add_seq(seq)
  overlay
}

///|
test "format_clock_ms: 完整时钟值格式化" {
  assert_eq(format_clock_ms(0), "0:00:00.000")
  assert_eq(format_clock_ms(5000), "0:00:05.000")
  assert_eq(format_clock_ms(60_000), "0:01:00.000")
  assert_eq(format_clock_ms(3_661_000), "1:01:01.000")
  assert_eq(format_clock_ms(3_723_456), "1:02:03.456")
}

///|
test "AudioClip::from_millis 生成时钟值" {
  let clip = AudioClip::from_millis("audio/a.mp3", 1500, 4250)
  assert_eq(clip.src, "audio/a.mp3")
  assert_eq(clip.clip_begin, "0:00:01.500")
  assert_eq(clip.clip_end, "0:00:04.250")
}

///|
test "AudioClip::new 直接使用时钟值" {
  let clip = AudioClip::new("audio/a.mp3", "0:00:01.500", "0:00:04.250")
  assert_eq(clip.clip_begin, "0:00:01.500")
  assert_eq(clip.clip_end, "0:00:04.250")
}

///|
test "Seq: 追加 par 与计数" {
  let seq = Seq::new("seq-1", "text/ch1.xhtml")
  assert_eq(seq.epub_type, None)
  assert_eq(seq.par_count(), 0)
  let clip = AudioClip::from_millis("audio/a.mp3", 0, 1000)
  seq.add_par(Par::new("par-1", "text/ch1.xhtml#p-1", clip))
  assert_eq(seq.par_count(), 1)
}

///|
test "Overlay: 追加 seq 与计数" {
  let overlay = Overlay::new()
  assert_true(overlay.is_empty())
  overlay.add_seq(Seq::new("seq-1", "text/ch1.xhtml"))
  overlay.add_seq(Seq::new("seq-2", "text/ch2.xhtml"))
  assert_eq(overlay.seq_count(), 2)
  assert_false(overlay.is_empty())
}

///|
test "render_smil: 文档结构" {
  let smil = render_smil(sample_overlay(), SmilOptions::new())
  assert_true(smil.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
  assert_true(
    smil.contains(
      "<smil xmlns=\"http://www.w3.org/ns/SMIL\" xmlns:epub=\"http://www.idpf.org/2007/ops\" version=\"3.0\">",
    ),
  )
  assert_true(smil.contains("<body>"))
  assert_true(
    smil.contains(
      "<seq id=\"seq-1\" epub:textref=\"text/ch1.xhtml\" epub:type=\"bodymatter\">",
    ),
  )
  assert_true(smil.contains("<par id=\"par-1\">"))
  assert_true(smil.contains("<text src=\"text/ch1.xhtml#p-1\"/>"))
  assert_true(
    smil.contains(
      "<audio src=\"audio/ch1.mp3\" clipBegin=\"0:00:00.000\" clipEnd=\"0:00:05.000\"/>",
    ),
  )
  assert_true(smil.contains("<par id=\"par-2\">"))
  assert_true(smil.contains("</seq>"))
  assert_true(smil.has_suffix("</smil>"))
}

///|
test "render_smil: 语言声明" {
  let options = SmilOptions::new()
  options.set_language("zh-CN")
  let smil = render_smil(sample_overlay(), options)
  assert_true(smil.contains("xml:lang=\"zh-CN\""))
}

///|
test "render_smil: 空覆盖文档" {
  let smil = render_smil(Overlay::new(), SmilOptions::new())
  assert_true(smil.contains("<body>"))
  assert_true(smil.contains("</body>"))
  assert_false(smil.contains("<seq"))
}

///|
test "format_clock_ms: 不足一秒补零" {
  assert_eq(format_clock_ms(1), "0:00:00.001")
  assert_eq(format_clock_ms(7), "0:00:00.007")
  assert_eq(format_clock_ms(999), "0:00:00.999")
}

///|
test "format_clock_ms: 分与时进位边界" {
  assert_eq(format_clock_ms(59_999), "0:00:59.999")
  assert_eq(format_clock_ms(60_000), "0:01:00.000")
  assert_eq(format_clock_ms(3_599_999), "0:59:59.999")
  assert_eq(format_clock_ms(3_600_000), "1:00:00.000")
}

///|
test "format_clock_ms: 毫秒三位补零" {
  assert_eq(format_clock_ms(60_007), "0:01:00.007")
  assert_eq(format_clock_ms(3_661_050), "1:01:01.050")
  assert_eq(format_clock_ms(7_200_000), "2:00:00.000")
}

///|
test "render_smil: 无 epub:type 的 seq 不写属性" {
  let seq = Seq::new("seq-1", "text/ch1.xhtml")
  seq.add_par(
    Par::new(
      "par-1",
      "text/ch1.xhtml#p-1",
      AudioClip::from_millis("audio/a.mp3", 0, 1000),
    ),
  )
  let overlay = Overlay::new()
  overlay.add_seq(seq)
  let smil = render_smil(overlay, SmilOptions::new())
  assert_true(
    smil.contains("<seq id=\"seq-1\" epub:textref=\"text/ch1.xhtml\">"),
  )
  assert_false(smil.contains("epub:type="))
}

///|
test "render_smil: 多序列按登记顺序" {
  let overlay = Overlay::new()
  overlay.add_seq(Seq::new("seq-a", "text/ch1.xhtml"))
  overlay.add_seq(Seq::new("seq-b", "text/ch2.xhtml"))
  assert_eq(overlay.seq_count(), 2)
  let smil = render_smil(overlay, SmilOptions::new())
  assert_true(
    smil.contains(
      "</seq>\n    <seq id=\"seq-b\" epub:textref=\"text/ch2.xhtml\">",
    ),
  )
}

///|
test "render_smil: 属性值 XML 转义" {
  let seq = Seq::new("seq-1", "text/ch1.xhtml")
  seq.add_par(
    Par::new(
      "par-1",
      "text/ch1.xhtml#p-1",
      AudioClip::new("audio/a&b.mp3", "0:00:00.000", "0:00:01.000"),
    ),
  )
  let overlay = Overlay::new()
  overlay.add_seq(seq)
  let smil = render_smil(overlay, SmilOptions::new())
  assert_true(smil.contains("src=\"audio/a&amp;b.mp3\""))
}

///|
test "render_smil: 有 seq 无 par 时不写 par" {
  let overlay = Overlay::new()
  overlay.add_seq(Seq::new("seq-1", "text/ch1.xhtml"))
  let smil = render_smil(overlay, SmilOptions::new())
  assert_true(
    smil.contains("<seq id=\"seq-1\" epub:textref=\"text/ch1.xhtml\">"),
  )
  assert_false(smil.contains("<par"))
}

///|
test "render_smil: audio 的 clipBegin 先于 clipEnd" {
  let seq = Seq::new("seq-1", "text/ch1.xhtml")
  seq.add_par(
    Par::new(
      "par-1",
      "text/ch1.xhtml#p-1",
      AudioClip::from_millis("audio/x.mp3", 500, 2250),
    ),
  )
  let overlay = Overlay::new()
  overlay.add_seq(seq)
  let smil = render_smil(overlay, SmilOptions::new())
  assert_true(
    smil.contains("clipBegin=\"0:00:00.500\" clipEnd=\"0:00:02.250\""),
  )
  assert_true(smil.contains("src=\"audio/x.mp3\""))
}
