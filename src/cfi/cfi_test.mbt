///|
/// S5 EPUB CFI 构造与解析的单元测试。

///|
test "CfiStep: 序号与可选 ID 断言" {
  let with_id = CfiStep::new(4, id="chap01")
  assert_eq(with_id.index, 4)
  assert_eq(with_id.id, Some("chap01"))
  assert_true(CfiStep::new(2).id is None)
}

///|
test "Cfi: 空 CFI 的渲染" {
  let cfi = Cfi::new()
  assert_eq(cfi.segment_count(), 1)
  assert_eq(cfi.step_count(), 0)
  assert_eq(cfi.render(), "epubcfi()")
  assert_true(cfi.last_step() is None)
}

///|
test "Cfi: 单段构造与渲染" {
  let cfi = Cfi::new()
  cfi.push(6)
  cfi.push(4, id="chap01")
  assert_eq(cfi.step_count(), 2)
  assert_eq(cfi.segment_count(), 1)
  assert_eq(cfi.render(), "epubcfi(/6/4[chap01])")
  assert_eq(cfi.last_step().unwrap().index, 4)
}

///|
test "Cfi: 间接引用与字符偏移" {
  let cfi = Cfi::new()
  cfi.push(6)
  cfi.push(4, id="chap01")
  cfi.indirect()
  cfi.push(4, id="body01")
  cfi.push(10)
  cfi.push(2)
  cfi.set_offset(5)
  assert_eq(cfi.segment_count(), 2)
  assert_eq(cfi.step_count(), 5)
  assert_eq(cfi.render(), "epubcfi(/6/4[chap01]!/4[body01]/10/2:5)")
}

///|
test "parse_cfi: 与 render 互逆" {
  let sample = "epubcfi(/6/4[chap01]!/4[body01]/10/2:5)"
  let cfi = parse_cfi(sample).unwrap()
  assert_eq(cfi.render(), sample)
  assert_eq(cfi.segment_count(), 2)
  assert_eq(cfi.step_count(), 5)
  assert_eq(cfi.offset, Some(5))
  assert_eq(cfi.last_step().unwrap().index, 2)
}

///|
test "parse_cfi: 无 ID 与无偏移的简单路径" {
  let cfi = parse_cfi("epubcfi(/6/4/2)").unwrap()
  assert_eq(cfi.segment_count(), 1)
  assert_eq(cfi.step_count(), 3)
  assert_true(cfi.offset is None)
  assert_true(cfi.segments[0][0].id is None)
}

///|
test "parse_cfi: 非法格式返回 None" {
  assert_true(parse_cfi("not a cfi") is None)
  assert_true(parse_cfi("epubcfi(/6/4") is None) // 缺少右括号
  assert_true(parse_cfi("epubcfi()") is None) // 空路径
  assert_true(parse_cfi("epubcfi(6/4)") is None) // 缺少前导 /
  assert_true(parse_cfi("epubcfi(/6/ab)") is None) // 非数字步
  assert_true(parse_cfi("epubcfi(/6/0)") is None) // 序号须为正
  assert_true(parse_cfi("epubcfi(/6/4[])") is None) // 空 ID 断言
  assert_true(parse_cfi("epubcfi(/6//4)") is None) // 空步
  assert_true(parse_cfi("epubcfi(/6/4:5/2)") is None) // 偏移不在末步
  assert_true(parse_cfi("epubcfi(/6/4[unclosed)") is None) // 断言未闭合
}
