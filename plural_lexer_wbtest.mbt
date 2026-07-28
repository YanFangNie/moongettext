///|
test "plural lexer recognizes every operator" {
  let tokens = tokenize_plural(
    "n != 1 && (n % 10 >= 2 || n / 2 <= 4) ? +3 * 2 : -5",
  )
  debug_inspect(
    tokens.map(token => token.kind),
    content=(
      #|[
      #|  Variable,
      #|  NotEqual,
      #|  Number(1),
      #|  LogicalAnd,
      #|  LeftParen,
      #|  Variable,
      #|  Percent,
      #|  Number(10),
      #|  GreaterEqual,
      #|  Number(2),
      #|  LogicalOr,
      #|  Variable,
      #|  Slash,
      #|  Number(2),
      #|  LessEqual,
      #|  Number(4),
      #|  RightParen,
      #|  Question,
      #|  Plus,
      #|  Number(3),
      #|  Star,
      #|  Number(2),
      #|  Colon,
      #|  Minus,
      #|  Number(5),
      #|  End,
      #|]
    ),
  )
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
