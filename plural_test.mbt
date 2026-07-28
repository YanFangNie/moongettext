///|
test "operator precedence matches the gettext C-like grammar" {
  assert_eq(
    @moongettext.evaluate_plural_expression("1 + 2 * 3 == 7 && !0", 0),
    1,
  )
  assert_eq(@moongettext.evaluate_plural_expression("10 - 6 / 2", 0), 7)
  assert_eq(@moongettext.evaluate_plural_expression("8 % 3 + 1", 0), 3)
}

///|
test "English and French plural rules" {
  let english = @moongettext.parse_plural_forms("nplurals=2; plural=(n != 1);")
  assert_eq(english.select(0), 1)
  assert_eq(english.select(1), 0)
  assert_eq(english.select(2), 1)
  let french = @moongettext.parse_plural_forms(
    "Plural-Forms: nplurals=2; plural=(n > 1);\nLanguage: fr\n",
  )
  assert_eq(french.select(0), 0)
  assert_eq(french.select(1), 0)
  assert_eq(french.select(2), 1)
}

///|
test "Russian nested conditional plural rule" {
  let russian = @moongettext.parse_plural_forms(
    "nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;",
  )
  assert_eq(russian.select(1), 0)
  assert_eq(russian.select(2), 1)
  assert_eq(russian.select(5), 2)
  assert_eq(russian.select(11), 2)
  assert_eq(russian.select(21), 0)
  assert_eq(russian.select(24), 1)
  assert_eq(russian.select(25), 2)
}

///|
test "logical evaluation short circuits" {
  assert_eq(
    @moongettext.evaluate_plural_expression("n != 0 && 10 / n > 1", 0),
    0,
  )
  assert_eq(
    @moongettext.evaluate_plural_expression("n == 0 || 10 / n > 1", 0),
    1,
  )
}

///|
test "conditional expressions associate to the right" {
  assert_eq(
    @moongettext.evaluate_plural_expression("n == 1 ? 0 : n == 2 ? 1 : 2", 1),
    0,
  )
  assert_eq(
    @moongettext.evaluate_plural_expression("n == 1 ? 0 : n == 2 ? 1 : 2", 2),
    1,
  )
  assert_eq(
    @moongettext.evaluate_plural_expression("n == 1 ? 0 : n == 2 ? 1 : 2", 9),
    2,
  )
}

///|
test "malformed conditional is rejected" {
  try @moongettext.evaluate_plural_expression("n ? 1", 3) catch {
    PluralSyntax(message~, ..) =>
      inspect(message, content="expected ':' in conditional plural expression")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected syntax error")
  }
}

///|
test "division by zero and out of range results are rejected" {
  try @moongettext.evaluate_plural_expression("10 / (n - n)", 2) catch {
    Validation(message~) =>
      inspect(message, content="division by zero in plural expression")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected evaluation error")
  }
  let invalid : @moongettext.PluralRule = { nplurals: 2, expression: "2" }
  try invalid.select(1) catch {
    Validation(message~) =>
      inspect(message, content="plural expression returned 2, outside 0..<2")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected range error")
  }
}

///|
test "Plural-Forms requires both assignments" {
  try @moongettext.parse_plural_forms("plural=n != 1;") catch {
    Validation(message~) =>
      inspect(message, content="Plural-Forms is missing nplurals")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected validation error")
  }
}
