///|
test "plural lexer recognizes every operator" {
  let tokens = tokenize_plural(
    "n != 1 && (n % 10 >= 2 || n / 2 <= 4) ? +3 * 2 : -5",
  )
  assert_eq(tokens.length(), 26)
  assert_true(tokens[0].kind == Variable)
  assert_true(tokens[1].kind == NotEqual)
  assert_true(tokens[2].kind == Number(1))
  assert_true(tokens[8].kind == GreaterEqual)
  assert_true(tokens[10].kind == LogicalOr)
  assert_true(tokens[17].kind == Question)
  assert_true(tokens[22].kind == Colon)
  assert_true(tokens[25].kind == End)
}

///|
test "plural lexer reports a lone assignment" {
  try tokenize_plural("n = 1") catch {
    PluralSyntax(position~, message~) => {
      inspect(position, content="2")
      inspect(message, content="use == for equality in a plural expression")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected lexing to fail")
  }
}
