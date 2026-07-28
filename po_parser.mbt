///|
priv enum ActivePoField {
  ActiveContext
  ActiveId
  ActivePluralId
  ActiveTranslation(Int)
}

///|
priv struct PoEntryBuilder {
  comments : Array[PoComment]
  mut context : String?
  mut msgid : String
  mut msgid_plural : String?
  translations : Map[Int, String]
  mut active : ActivePoField?
  mut saw_msgid : Bool
  mut obsolete : Bool
}

///|
fn PoEntryBuilder::new() -> PoEntryBuilder {
  {
    comments: [],
    context: None,
    msgid: "",
    msgid_plural: None,
    translations: {},
    active: None,
    saw_msgid: false,
    obsolete: false,
  }
}

///|
fn PoEntryBuilder::has_content(self : PoEntryBuilder) -> Bool {
  self.saw_msgid ||
  self.context is Some(_) ||
  !self.comments.is_empty() ||
  !self.translations.is_empty()
}

///|
fn PoEntryBuilder::append_active(
  self : PoEntryBuilder,
  value : String,
  line : Int,
) -> Unit raise GettextError {
  match self.active {
    Some(ActiveContext) =>
      self.context = Some(self.context.unwrap_or("") + value)
    Some(ActiveId) => self.msgid = self.msgid + value
    Some(ActivePluralId) =>
      self.msgid_plural = Some(self.msgid_plural.unwrap_or("") + value)
    Some(ActiveTranslation(index)) => {
      let previous = self.translations.get(index).unwrap_or("")
      self.translations[index] = previous + value
    }
    None =>
      raise PoSyntax(
        line~,
        column=1,
        message="quoted continuation has no preceding field",
      )
  }
}

///|
fn PoEntryBuilder::finish(
  self : PoEntryBuilder,
  line : Int,
) -> PoEntry raise GettextError {
  if !self.saw_msgid {
    raise PoSyntax(
      line~,
      column=1,
      message="entry has comments or fields but no msgid",
    )
  }
  let mut max_index = -1
  for index, _ in self.translations {
    if index < 0 {
      raise PoSyntax(line~, column=1, message="msgstr index cannot be negative")
    }
    if index > max_index {
      max_index = index
    }
  }
  let translations = if max_index < 0 {
    if self.msgid_plural is Some(_) {
      []
    } else {
      [""]
    }
  } else {
    let values = Array::make(max_index + 1, "")
    for index, value in self.translations {
      values[index] = value
    }
    values
  }
  {
    comments: self.comments.copy(),
    context: self.context,
    msgid: self.msgid,
    msgid_plural: self.msgid_plural,
    translations,
    obsolete: self.obsolete,
  }
}

///|
fn parse_comment_line(line : String) -> PoComment {
  if line.has_prefix("#.") {
    PoComment::new(Extracted, line[2:].trim_start().to_owned())
  } else if line.has_prefix("#:") {
    PoComment::new(Reference, line[2:].trim_start().to_owned())
  } else if line.has_prefix("#,") {
    PoComment::new(Flag, line[2:].trim_start().to_owned())
  } else if line.has_prefix("#|") {
    PoComment::new(Previous, line[2:].trim_start().to_owned())
  } else if line == "#" {
    PoComment::new(Translator, "")
  } else {
    PoComment::new(Translator, line[1:].trim_start().to_owned())
  }
}

///|
fn quoted_value(text : String, line_number : Int) -> String raise GettextError {
  let trimmed = text.trim().to_owned()
  if trimmed.length() < 2 ||
    !trimmed.has_prefix("\"") ||
    !trimmed.has_suffix("\"") {
    raise PoSyntax(
      line=line_number,
      column=1,
      message="expected one double-quoted PO string",
    )
  }
  let body = trimmed[1:trimmed.length() - 1].to_owned()
  try unescape_po_string(body) catch {
    PoSyntax(column~, message~, ..) =>
      raise PoSyntax(line=line_number, column~, message~)
    error => raise error
  } noraise {
    value => value
  }
}

///|
fn decimal_index(text : String, line_number : Int) -> Int raise GettextError {
  if text == "" {
    raise PoSyntax(line=line_number, column=1, message="msgstr index is empty")
  }
  let mut value = 0
  for c in text {
    guard c is ('0'..='9') else {
      raise PoSyntax(
        line=line_number,
        column=1,
        message="msgstr index must be a decimal integer",
      )
    }
    value = value * 10 + c.to_int() - '0'.to_int()
  }
  value
}

///|
fn value_after_keyword(
  line : String,
  keyword : String,
  line_number : Int,
) -> String raise GettextError {
  let rest = line[keyword.length():].trim_start().to_owned()
  quoted_value(rest, line_number)
}

///|
fn strip_obsolete_prefix(line : String) -> (String, Bool) {
  if line.has_prefix("#~") {
    (line[2:].trim_start().to_owned(), true)
  } else {
    (line, false)
  }
}

///|
/// Parse a GNU gettext PO or POT document.
///
/// The parser accepts LF and CRLF input, multiline quoted strings, contexts,
/// plurals, the five standard comment classes, and obsolete `#~` entries.
/// Parsed output is semantic rather than lossless: whitespace and line wrapping
/// are normalized when the document is written again.
pub fn parse_po(source : String) -> PoFile raise GettextError {
  let entries : Array[PoEntry] = []
  let mut builder = PoEntryBuilder::new()
  let lines = source.split("\n").to_array()
  for index, raw_line in lines {
    let line_number = index + 1
    let physical_line = raw_line.to_owned().trim_end(chars="\r").to_owned()
    if physical_line.trim().is_empty() {
      if builder.has_content() {
        if builder.saw_msgid {
          entries.push(builder.finish(line_number))
        }
        builder = PoEntryBuilder::new()
      }
      continue
    }

    let (line, is_obsolete) = strip_obsolete_prefix(physical_line)
    if is_obsolete {
      builder.obsolete = true
    }

    if line.has_prefix("#") {
      if builder.saw_msgid && !is_obsolete {
        entries.push(builder.finish(line_number))
        builder = PoEntryBuilder::new()
      }
      builder.comments.push(parse_comment_line(line))
      builder.active = None
      continue
    }

    if line.trim_start().has_prefix("\"") {
      builder.append_active(quoted_value(line, line_number), line_number)
      continue
    }

    if line.has_prefix("msgctxt") {
      if builder.saw_msgid {
        entries.push(builder.finish(line_number))
        builder = PoEntryBuilder::new()
        if is_obsolete {
          builder.obsolete = true
        }
      }
      builder.context = Some(value_after_keyword(line, "msgctxt", line_number))
      builder.active = Some(ActiveContext)
    } else if line.has_prefix("msgid_plural") {
      if !builder.saw_msgid {
        raise PoSyntax(
          line=line_number,
          column=1,
          message="msgid_plural must follow msgid",
        )
      }
      builder.msgid_plural = Some(
        value_after_keyword(line, "msgid_plural", line_number),
      )
      builder.active = Some(ActivePluralId)
    } else if line.has_prefix("msgid") {
      if builder.saw_msgid {
        entries.push(builder.finish(line_number))
        builder = PoEntryBuilder::new()
        if is_obsolete {
          builder.obsolete = true
        }
      }
      builder.msgid = value_after_keyword(line, "msgid", line_number)
      builder.saw_msgid = true
      builder.active = Some(ActiveId)
    } else if line.has_prefix("msgstr[") {
      guard line.find("]") is Some(close) else {
        raise PoSyntax(
          line=line_number,
          column=1,
          message="msgstr index is missing a closing bracket",
        )
      }
      let translation_index = decimal_index(
        line[7:close].to_owned(),
        line_number,
      )
      let value = quoted_value(line[close + 1:].to_owned(), line_number)
      builder.translations[translation_index] = value
      builder.active = Some(ActiveTranslation(translation_index))
    } else if line.has_prefix("msgstr") {
      let value = value_after_keyword(line, "msgstr", line_number)
      builder.translations[0] = value
      builder.active = Some(ActiveTranslation(0))
    } else {
      raise PoSyntax(
        line=line_number,
        column=1,
        message="unknown PO directive: \{line}",
      )
    }
  }
  if builder.has_content() {
    entries.push(builder.finish(lines.length()))
  }
  PoFile::new(entries)
}
