///|
priv enum PluralTokenKind {
  Number(Int)
  Variable
  LeftParen
  RightParen
  Question
  Colon
  LogicalOr
  LogicalAnd
  Equal
  NotEqual
  Less
  LessEqual
  Greater
  GreaterEqual
  Plus
  Minus
  Star
  Slash
  Percent
  Bang
  End
} derive(Eq)

///|
priv struct PluralToken {
  kind : PluralTokenKind
  position : Int
}

///|
fn make_plural_token(kind : PluralTokenKind, position : Int) -> PluralToken {
  { kind, position }
}

///|
fn tokenize_plural(
  expression : String,
) -> Array[PluralToken] raise GettextError {
  let chars = expression.to_array()
  let tokens : Array[PluralToken] = []
  let mut index = 0
  while index < chars.length() {
    let c = chars[index]
    if c.is_whitespace() {
      index += 1
      continue
    }
    if c is ('0'..='9') {
      let start = index
      let mut value = 0
      while index < chars.length() && chars[index] is ('0'..='9') {
        let digit = chars[index].to_int() - '0'.to_int()
        if value > 214748364 || (value == 214748364 && digit > 7) {
          raise PluralSyntax(
            position=start,
            message="integer literal exceeds MoonBit Int range",
          )
        }
        value = value * 10 + digit
        index += 1
      }
      tokens.push(make_plural_token(Number(value), start))
      continue
    }
    match c {
      'n' => {
        tokens.push(make_plural_token(Variable, index))
        index += 1
      }
      '(' => {
        tokens.push(make_plural_token(LeftParen, index))
        index += 1
      }
      ')' => {
        tokens.push(make_plural_token(RightParen, index))
        index += 1
      }
      '?' => {
        tokens.push(make_plural_token(Question, index))
        index += 1
      }
      ':' => {
        tokens.push(make_plural_token(Colon, index))
        index += 1
      }
      '+' => {
        tokens.push(make_plural_token(Plus, index))
        index += 1
      }
      '-' => {
        tokens.push(make_plural_token(Minus, index))
        index += 1
      }
      '*' => {
        tokens.push(make_plural_token(Star, index))
        index += 1
      }
      '/' => {
        tokens.push(make_plural_token(Slash, index))
        index += 1
      }
      '%' => {
        tokens.push(make_plural_token(Percent, index))
        index += 1
      }
      '!' =>
        if index + 1 < chars.length() && chars[index + 1] == '=' {
          tokens.push(make_plural_token(NotEqual, index))
          index += 2
        } else {
          tokens.push(make_plural_token(Bang, index))
          index += 1
        }
      '=' =>
        if index + 1 < chars.length() && chars[index + 1] == '=' {
          tokens.push(make_plural_token(Equal, index))
          index += 2
        } else {
          raise PluralSyntax(
            position=index,
            message="use == for equality in a plural expression",
          )
        }
      '<' =>
        if index + 1 < chars.length() && chars[index + 1] == '=' {
          tokens.push(make_plural_token(LessEqual, index))
          index += 2
        } else {
          tokens.push(make_plural_token(Less, index))
          index += 1
        }
      '>' =>
        if index + 1 < chars.length() && chars[index + 1] == '=' {
          tokens.push(make_plural_token(GreaterEqual, index))
          index += 2
        } else {
          tokens.push(make_plural_token(Greater, index))
          index += 1
        }
      '&' =>
        if index + 1 < chars.length() && chars[index + 1] == '&' {
          tokens.push(make_plural_token(LogicalAnd, index))
          index += 2
        } else {
          raise PluralSyntax(
            position=index,
            message="use && for logical conjunction",
          )
        }
      '|' =>
        if index + 1 < chars.length() && chars[index + 1] == '|' {
          tokens.push(make_plural_token(LogicalOr, index))
          index += 2
        } else {
          raise PluralSyntax(
            position=index,
            message="use || for logical disjunction",
          )
        }
      _ =>
        raise PluralSyntax(
          position=index,
          message="unexpected character '\{c}' in plural expression",
        )
    }
  }
  tokens.push(make_plural_token(End, chars.length()))
  tokens
}
