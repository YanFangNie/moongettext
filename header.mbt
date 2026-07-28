///|
/// Parse the translated string of a gettext header entry into metadata fields.
///
/// Lines without a colon are ignored. A line beginning with a space or tab is
/// treated as a continuation of the preceding field.
pub fn parse_header_fields(header : String) -> Map[String, String] {
  let fields : Map[String, String] = Map([])
  let mut current_key : String? = None
  for raw_line in header.split("\n") {
    let line = raw_line.to_owned().trim_end(chars="\r").to_owned()
    if line == "" {
      continue
    }
    if line.has_prefix(" ") || line.has_prefix("\t") {
      match current_key {
        Some(key) => {
          let continuation = line.trim().to_owned()
          let previous = fields.get(key).unwrap_or("")
          fields[key] = if previous == "" {
            continuation
          } else {
            previous + " " + continuation
          }
        }
        None => ()
      }
      continue
    }
    match line.split_once(":") {
      Some((raw_key, raw_value)) => {
        let key = raw_key.trim().to_owned()
        if key != "" {
          fields[key] = raw_value.trim().to_owned()
          current_key = Some(key)
        }
      }
      None => current_key = None
    }
  }
  fields
}

///|
/// Return parsed fields from the conventional empty-`msgid` header entry.
pub fn PoFile::metadata(self : PoFile) -> Map[String, String] {
  match self.header() {
    Some(entry) => parse_header_fields(entry.translations.get(0).unwrap_or(""))
    None => {}
  }
}
