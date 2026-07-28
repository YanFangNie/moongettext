///|
/// A source location decoded from a `#:` PO reference comment.
pub(all) struct SourceReference {
  path : String
  line : Int?
  column : Int?
} derive(Debug, Eq)

///|
/// Aggregate status counts for a parsed PO/POT document.
pub(all) struct PoStatistics {
  headers : Int
  messages : Int
  active : Int
  translated : Int
  untranslated : Int
  fuzzy : Int
  obsolete : Int
  singular : Int
  plural : Int
  contextual : Int
} derive(Debug, Eq)

///|
fn parse_reference_number(text : String) -> Int? {
  if text == "" {
    return None
  }
  let mut value = 0
  for c in text {
    guard c is ('0'..='9') else { return None }
    let digit = c.to_int() - '0'.to_int()
    if value > 214748364 || (value == 214748364 && digit > 7) {
      return None
    }
    value = value * 10 + digit
  }
  Some(value)
}

///|
fn parse_source_reference(token : String) -> SourceReference {
  match token.rev_split_once(":") {
    Some((before_last, last)) =>
      match parse_reference_number(last.to_owned()) {
        Some(last_number) => {
          let remaining = before_last.to_owned()
          match remaining.rev_split_once(":") {
            Some((path, possible_line)) =>
              match parse_reference_number(possible_line.to_owned()) {
                Some(line) =>
                  {
                    path: path.to_owned(),
                    line: Some(line),
                    column: Some(last_number),
                  }
                None =>
                  { path: remaining, line: Some(last_number), column: None }
              }
            None => { path: remaining, line: Some(last_number), column: None }
          }
        }
        None => { path: token, line: None, column: None }
      }
    None => { path: token, line: None, column: None }
  }
}

///|
/// Return unique comma-separated flags in first-seen order.
pub fn PoEntry::flags(self : PoEntry) -> Array[String] {
  let result : Array[String] = []
  for comment in self.comments {
    if comment.kind == Flag {
      for raw_flag in comment.text.split(",") {
        add_unique_string(result, raw_flag.trim().to_owned())
      }
    }
  }
  result
}

///|
/// Decode whitespace-separated `#:` source reference tokens.
///
/// `path`, `path:line`, and `path:line:column` are recognized. GNU PO permits
/// tool-specific quoting for paths containing whitespace; this helper keeps
/// those advanced spellings as separate raw tokens rather than guessing.
pub fn PoEntry::source_references(self : PoEntry) -> Array[SourceReference] {
  let result : Array[SourceReference] = []
  for comment in self.comments {
    if comment.kind == Reference {
      let normalized = comment.text.replace_all(old="\t", new=" ")
      for raw_token in normalized.split(" ") {
        let token = raw_token.to_owned()
        if token != "" {
          let reference = parse_source_reference(token)
          if !result.contains(reference) {
            result.push(reference)
          }
        }
      }
    }
  }
  result
}

///|
/// Find a context-aware entry. Obsolete entries are ignored by default.
pub fn PoFile::find_entry(
  self : PoFile,
  msgid : String,
  context? : String,
  include_obsolete? : Bool = false,
) -> PoEntry? {
  for entry in self.entries {
    if entry.msgid == msgid &&
      entry.context == context &&
      (include_obsolete || !entry.obsolete) {
      return Some(entry)
    }
  }
  None
}

///|
/// Compute catalog status counts in one pass.
pub fn PoFile::statistics(self : PoFile) -> PoStatistics {
  let mut headers = 0
  let mut messages = 0
  let mut active = 0
  let mut translated = 0
  let mut untranslated = 0
  let mut fuzzy = 0
  let mut obsolete = 0
  let mut singular = 0
  let mut plural = 0
  let mut contextual = 0
  for entry in self.entries {
    if entry.is_header() {
      headers += 1
      continue
    }
    messages += 1
    if entry.obsolete {
      obsolete += 1
    } else {
      active += 1
    }
    if entry.is_fuzzy() {
      fuzzy += 1
    }
    if all_translations_empty(entry) {
      untranslated += 1
    } else {
      translated += 1
    }
    if entry.msgid_plural is Some(_) {
      plural += 1
    } else {
      singular += 1
    }
    if entry.context is Some(_) {
      contextual += 1
    }
  }
  {
    headers,
    messages,
    active,
    translated,
    untranslated,
    fuzzy,
    obsolete,
    singular,
    plural,
    contextual,
  }
}
