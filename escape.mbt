///|
fn hex_value(c : Char) -> Int? {
  match c {
    '0'..='9' => Some(c.to_int() - '0'.to_int())
    'a'..='f' => Some(c.to_int() - 'a'.to_int() + 10)
    'A'..='F' => Some(c.to_int() - 'A'.to_int() + 10)
    _ => None
  }
}

///|
fn octal_value(c : Char) -> Int? {
  match c {
    '0'..='7' => Some(c.to_int() - '0'.to_int())
    _ => None
  }
}

///|
/// Escape a string for the body of a double-quoted PO string.
///
/// The returned value does not include the surrounding quote characters.
pub fn escape_po_string(input : String) -> String {
  let output = StringBuilder()
  for c in input {
    match c {
      '\\' => output.write_string("\\\\")
      '"' => output.write_string("\\\"")
      '\n' => output.write_string("\\n")
      '\r' => output.write_string("\\r")
      '\t' => output.write_string("\\t")
      '\u{0008}' => output.write_string("\\b")
      '\u{000c}' => output.write_string("\\f")
      '\u{000b}' => output.write_string("\\v")
      '\u{0007}' => output.write_string("\\a")
      _ => output.write_char(c)
    }
  }
  output.to_string()
}

///|
/// Decode C-style escapes used inside a PO quoted string.
///
/// Common named escapes, octal escapes of up to three digits, and hexadecimal
/// escapes are supported. Unknown escapes follow gettext's permissive reader
/// behavior and evaluate to the escaped character itself.
pub fn unescape_po_string(input : String) -> String raise GettextError {
  let chars = input.to_array()
  let output = StringBuilder()
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c != '\\' {
      output.write_char(c)
      i += 1
      continue
    }
    if i + 1 >= chars.length() {
      raise PoSyntax(
        line=0,
        column=i + 1,
        message="unterminated escape sequence",
      )
    }
    let escaped = chars[i + 1]
    match escaped {
      'n' => {
        output.write_char('\n')
        i += 2
      }
      'r' => {
        output.write_char('\r')
        i += 2
      }
      't' => {
        output.write_char('\t')
        i += 2
      }
      'b' => {
        output.write_char('\u{0008}')
        i += 2
      }
      'f' => {
        output.write_char('\u{000c}')
        i += 2
      }
      'v' => {
        output.write_char('\u{000b}')
        i += 2
      }
      'a' => {
        output.write_char('\u{0007}')
        i += 2
      }
      '\\' => {
        output.write_char('\\')
        i += 2
      }
      '"' => {
        output.write_char('"')
        i += 2
      }
      '?' => {
        output.write_char('?')
        i += 2
      }
      'x' | 'X' => {
        let mut j = i + 2
        let mut value = 0
        let mut digits = 0
        while j < chars.length() {
          match hex_value(chars[j]) {
            Some(digit) => {
              value = value * 16 + digit
              digits += 1
              j += 1
            }
            None => break
          }
        }
        if digits == 0 {
          raise PoSyntax(
            line=0,
            column=i + 1,
            message="hexadecimal escape requires at least one digit",
          )
        }
        match value.to_char() {
          Some(decoded) => output.write_char(decoded)
          None =>
            raise PoSyntax(
              line=0,
              column=i + 1,
              message="escape is not a valid Unicode scalar value",
            )
        }
        i = j
      }
      '0'..='7' => {
        let mut j = i + 1
        let mut value = 0
        let mut digits = 0
        while j < chars.length() && digits < 3 {
          match octal_value(chars[j]) {
            Some(digit) => {
              value = value * 8 + digit
              digits += 1
              j += 1
            }
            None => break
          }
        }
        match value.to_char() {
          Some(decoded) => output.write_char(decoded)
          None =>
            raise PoSyntax(
              line=0,
              column=i + 1,
              message="escape is not a valid Unicode scalar value",
            )
        }
        i = j
      }
      _ => {
        output.write_char(escaped)
        i += 2
      }
    }
  }
  output.to_string()
}
