///|
priv enum PluralExpr {
  PluralLiteral(Int)
  PluralCount
  PluralNot(PluralExpr)
  PluralPositive(PluralExpr)
  PluralNegative(PluralExpr)
  PluralMultiply(PluralExpr, PluralExpr)
  PluralDivide(PluralExpr, PluralExpr)
  PluralModulo(PluralExpr, PluralExpr)
  PluralAdd(PluralExpr, PluralExpr)
  PluralSubtract(PluralExpr, PluralExpr)
  PluralLess(PluralExpr, PluralExpr)
  PluralLessEqual(PluralExpr, PluralExpr)
  PluralGreater(PluralExpr, PluralExpr)
  PluralGreaterEqual(PluralExpr, PluralExpr)
  PluralEqual(PluralExpr, PluralExpr)
  PluralNotEqual(PluralExpr, PluralExpr)
  PluralAnd(PluralExpr, PluralExpr)
  PluralOr(PluralExpr, PluralExpr)
  PluralConditional(PluralExpr, PluralExpr, PluralExpr)
}

///|
priv struct PluralParser {
  tokens : Array[PluralToken]
  mut position : Int
}

///|
fn PluralParser::new(tokens : Array[PluralToken]) -> PluralParser {
  { tokens, position: 0 }
}

///|
fn PluralParser::current(self : PluralParser) -> PluralToken {
  self.tokens[self.position]
}

///|
fn PluralParser::advance(self : PluralParser) -> Unit {
  if self.position + 1 < self.tokens.length() {
    self.position += 1
  }
}

///|
fn PluralParser::syntax_error(
  self : PluralParser,
  message : String,
) -> GettextError {
  PluralSyntax(position=self.current().position, message~)
}

///|
fn PluralParser::parse_primary(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  match self.current().kind {
    Number(value) => {
      self.advance()
      PluralLiteral(value)
    }
    Variable => {
      self.advance()
      PluralCount
    }
    LeftParen => {
      self.advance()
      let expression = self.parse_conditional()
      guard self.current().kind == RightParen else {
        raise self.syntax_error("expected ')' after plural subexpression")
      }
      self.advance()
      expression
    }
    _ => raise self.syntax_error("expected n, an integer, or '('")
  }
}

///|
fn PluralParser::parse_unary(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  match self.current().kind {
    Bang => {
      self.advance()
      PluralNot(self.parse_unary())
    }
    Plus => {
      self.advance()
      PluralPositive(self.parse_unary())
    }
    Minus => {
      self.advance()
      PluralNegative(self.parse_unary())
    }
    _ => self.parse_primary()
  }
}

///|
fn PluralParser::parse_multiplicative(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  let mut left = self.parse_unary()
  for ;; {
    match self.current().kind {
      Star => {
        self.advance()
        left = PluralMultiply(left, self.parse_unary())
      }
      Slash => {
        self.advance()
        left = PluralDivide(left, self.parse_unary())
      }
      Percent => {
        self.advance()
        left = PluralModulo(left, self.parse_unary())
      }
      _ => break
    }
  }
  left
}

///|
fn PluralParser::parse_additive(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  let mut left = self.parse_multiplicative()
  for ;; {
    match self.current().kind {
      Plus => {
        self.advance()
        left = PluralAdd(left, self.parse_multiplicative())
      }
      Minus => {
        self.advance()
        left = PluralSubtract(left, self.parse_multiplicative())
      }
      _ => break
    }
  }
  left
}

///|
fn PluralParser::parse_relational(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  let mut left = self.parse_additive()
  for ;; {
    match self.current().kind {
      Less => {
        self.advance()
        left = PluralLess(left, self.parse_additive())
      }
      LessEqual => {
        self.advance()
        left = PluralLessEqual(left, self.parse_additive())
      }
      Greater => {
        self.advance()
        left = PluralGreater(left, self.parse_additive())
      }
      GreaterEqual => {
        self.advance()
        left = PluralGreaterEqual(left, self.parse_additive())
      }
      _ => break
    }
  }
  left
}

///|
fn PluralParser::parse_equality(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  let mut left = self.parse_relational()
  for ;; {
    match self.current().kind {
      Equal => {
        self.advance()
        left = PluralEqual(left, self.parse_relational())
      }
      NotEqual => {
        self.advance()
        left = PluralNotEqual(left, self.parse_relational())
      }
      _ => break
    }
  }
  left
}

///|
fn PluralParser::parse_and(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  let mut left = self.parse_equality()
  while self.current().kind == LogicalAnd {
    self.advance()
    left = PluralAnd(left, self.parse_equality())
  }
  left
}

///|
fn PluralParser::parse_or(self : PluralParser) -> PluralExpr raise GettextError {
  let mut left = self.parse_and()
  while self.current().kind == LogicalOr {
    self.advance()
    left = PluralOr(left, self.parse_and())
  }
  left
}

///|
fn PluralParser::parse_conditional(
  self : PluralParser,
) -> PluralExpr raise GettextError {
  let condition = self.parse_or()
  if self.current().kind != Question {
    return condition
  }
  self.advance()
  let when_true = self.parse_conditional()
  guard self.current().kind == Colon else {
    raise self.syntax_error("expected ':' in conditional plural expression")
  }
  self.advance()
  let when_false = self.parse_conditional()
  PluralConditional(condition, when_true, when_false)
}

///|
fn parse_plural_ast(expression : String) -> PluralExpr raise GettextError {
  let parser = PluralParser::new(tokenize_plural(expression))
  let result = parser.parse_conditional()
  guard parser.current().kind == End else {
    raise parser.syntax_error("unexpected token after plural expression")
  }
  result
}

///|
fn plural_bool(value : Bool) -> Int {
  if value {
    1
  } else {
    0
  }
}

///|
fn evaluate_plural_ast(
  expression : PluralExpr,
  n : Int,
) -> Int raise GettextError {
  match expression {
    PluralLiteral(value) => value
    PluralCount => n
    PluralNot(value) => plural_bool(evaluate_plural_ast(value, n) == 0)
    PluralPositive(value) => evaluate_plural_ast(value, n)
    PluralNegative(value) => -evaluate_plural_ast(value, n)
    PluralMultiply(left, right) =>
      evaluate_plural_ast(left, n) * evaluate_plural_ast(right, n)
    PluralDivide(left, right) => {
      let divisor = evaluate_plural_ast(right, n)
      if divisor == 0 {
        raise Validation(message="division by zero in plural expression")
      }
      evaluate_plural_ast(left, n) / divisor
    }
    PluralModulo(left, right) => {
      let divisor = evaluate_plural_ast(right, n)
      if divisor == 0 {
        raise Validation(message="modulo by zero in plural expression")
      }
      evaluate_plural_ast(left, n) % divisor
    }
    PluralAdd(left, right) =>
      evaluate_plural_ast(left, n) + evaluate_plural_ast(right, n)
    PluralSubtract(left, right) =>
      evaluate_plural_ast(left, n) - evaluate_plural_ast(right, n)
    PluralLess(left, right) =>
      plural_bool(evaluate_plural_ast(left, n) < evaluate_plural_ast(right, n))
    PluralLessEqual(left, right) =>
      plural_bool(evaluate_plural_ast(left, n) <= evaluate_plural_ast(right, n))
    PluralGreater(left, right) =>
      plural_bool(evaluate_plural_ast(left, n) > evaluate_plural_ast(right, n))
    PluralGreaterEqual(left, right) =>
      plural_bool(evaluate_plural_ast(left, n) >= evaluate_plural_ast(right, n))
    PluralEqual(left, right) =>
      plural_bool(evaluate_plural_ast(left, n) == evaluate_plural_ast(right, n))
    PluralNotEqual(left, right) =>
      plural_bool(evaluate_plural_ast(left, n) != evaluate_plural_ast(right, n))
    PluralAnd(left, right) => {
      let left_value = evaluate_plural_ast(left, n)
      if left_value == 0 {
        0
      } else {
        plural_bool(evaluate_plural_ast(right, n) != 0)
      }
    }
    PluralOr(left, right) => {
      let left_value = evaluate_plural_ast(left, n)
      if left_value != 0 {
        1
      } else {
        plural_bool(evaluate_plural_ast(right, n) != 0)
      }
    }
    PluralConditional(condition, when_true, when_false) =>
      if evaluate_plural_ast(condition, n) != 0 {
        evaluate_plural_ast(when_true, n)
      } else {
        evaluate_plural_ast(when_false, n)
      }
  }
}

///|
/// Evaluate one GNU gettext plural expression for a non-negative count.
pub fn evaluate_plural_expression(
  expression : String,
  n : Int,
) -> Int raise GettextError {
  if n < 0 {
    raise Validation(message="plural count cannot be negative")
  }
  evaluate_plural_ast(parse_plural_ast(expression), n)
}
