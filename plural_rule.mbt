///|
/// A validated `Plural-Forms` rule.
pub struct PluralRule {
  nplurals : Int
  expression : String
} derive(Debug, Eq)

///|
/// The conventional English rule: singular only when `n == 1`.
pub fn PluralRule::english() -> PluralRule {
  { nplurals: 2, expression: "n != 1" }
}

///|
fn parse_positive_decimal(
  text : String,
  field : String,
) -> Int raise GettextError {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    raise Validation(message="\{field} cannot be empty")
  }
  let mut value = 0
  for c in trimmed {
    guard c is ('0'..='9') else {
      raise Validation(message="\{field} must be a positive decimal integer")
    }
    let digit = c.to_int() - '0'.to_int()
    if value > 214748364 || (value == 214748364 && digit > 7) {
      raise Validation(message="\{field} exceeds MoonBit Int range")
    }
    value = value * 10 + digit
  }
  if value <= 0 {
    raise Validation(message="\{field} must be greater than zero")
  }
  value
}

///|
fn plural_forms_payload(input : String) -> String {
  match input.find("Plural-Forms:") {
    Some(start) => {
      let after = input[start + "Plural-Forms:".length():].to_owned()
      match after.find("\n") {
        Some(end) => after[:end].trim_end(chars="\r").to_owned()
        None => after
      }
    }
    None => input
  }
}

///|
/// Parse a `Plural-Forms` value or a complete gettext metadata header.
///
/// Both `nplurals` and `plural` assignments are required. Assignment order and
/// surrounding whitespace are ignored.
pub fn parse_plural_forms(input : String) -> PluralRule raise GettextError {
  let payload = plural_forms_payload(input)
  let mut nplurals : Int? = None
  let mut expression : String? = None
  for raw_assignment in payload.split(";") {
    let assignment = raw_assignment.trim().to_owned()
    if assignment == "" {
      continue
    }
    match assignment.split_once("=") {
      Some((raw_key, raw_value)) => {
        let key = raw_key.trim().to_owned()
        let value = raw_value.trim().to_owned()
        if key == "nplurals" {
          nplurals = Some(parse_positive_decimal(value, "nplurals"))
        } else if key == "plural" {
          expression = Some(value)
        }
      }
      None => ()
    }
  }
  guard nplurals is Some(count) else {
    raise Validation(message="Plural-Forms is missing nplurals")
  }
  guard expression is Some(code) else {
    raise Validation(message="Plural-Forms is missing plural expression")
  }
  ignore(parse_plural_ast(code))
  { nplurals: count, expression: code }
}

///|
/// Select a translation index and ensure the expression stays inside the
/// declared `[0, nplurals)` range.
pub fn PluralRule::select(self : PluralRule, n : Int) -> Int raise GettextError {
  let index = evaluate_plural_expression(self.expression, n)
  if index < 0 || index >= self.nplurals {
    raise Validation(
      message="plural expression returned \{index}, outside 0..<\{self.nplurals}",
    )
  }
  index
}
