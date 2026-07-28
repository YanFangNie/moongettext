///|
fn comment_marker(kind : CommentKind, text : String) -> String {
  match kind {
    Translator => if text == "" { "#" } else { "# " }
    Extracted => "#. "
    Reference => "#: "
    Flag => "#, "
    Previous => "#| "
  }
}

///|
fn write_po_line(
  output : StringBuilder,
  line : String,
  obsolete : Bool,
) -> Unit {
  if obsolete {
    output.write_string("#~ ")
  }
  output.write_string(line)
  output.write_char('\n')
}

///|
fn multiline_fragments(value : String) -> Array[String] {
  let fragments : Array[String] = []
  let current = StringBuilder()
  for c in value {
    if c == '\n' {
      current.write_char('\n')
      fragments.push(current.to_string())
      current.reset()
    } else {
      current.write_char(c)
    }
  }
  if !current.is_empty() {
    fragments.push(current.to_string())
  }
  fragments
}

///|
fn write_po_field(
  output : StringBuilder,
  keyword : String,
  value : String,
  obsolete : Bool,
) -> Unit {
  if !value.contains_char('\n') {
    write_po_line(output, "\{keyword} \"\{escape_po_string(value)}\"", obsolete)
    return
  }
  write_po_line(output, "\{keyword} \"\"", obsolete)
  for fragment in multiline_fragments(value) {
    write_po_line(output, "\"\{escape_po_string(fragment)}\"", obsolete)
  }
}

///|
/// Serialize a PO/POT document into deterministic GNU gettext syntax.
///
/// Semantic information is preserved, while whitespace, entry separation, and
/// multiline layout are normalized. Every entry is followed by one blank line.
pub fn write_po(document : PoFile) -> String {
  let output = StringBuilder()
  for entry in document.entries {
    for comment in entry.comments {
      write_po_line(
        output,
        comment_marker(comment.kind, comment.text) + comment.text,
        entry.obsolete,
      )
    }
    match entry.context {
      Some(context) =>
        write_po_field(output, "msgctxt", context, entry.obsolete)
      None => ()
    }
    write_po_field(output, "msgid", entry.msgid, entry.obsolete)
    match entry.msgid_plural {
      Some(plural) => {
        write_po_field(output, "msgid_plural", plural, entry.obsolete)
        if entry.translations.is_empty() {
          write_po_field(output, "msgstr[0]", "", entry.obsolete)
        } else {
          for index, translation in entry.translations {
            write_po_field(
              output,
              "msgstr[\{index}]",
              translation,
              entry.obsolete,
            )
          }
        }
      }
      None => {
        let translation = entry.translations.get(0).unwrap_or("")
        write_po_field(output, "msgstr", translation, entry.obsolete)
      }
    }
    output.write_char('\n')
  }
  output.to_string()
}

///|
/// Return a POT-style copy with non-header translations cleared.
///
/// The metadata header is retained because template generators commonly store
/// MIME and project fields there. Singular entries receive one empty `msgstr`;
/// plural entries retain at least two indexed slots.
pub fn PoFile::as_template(self : PoFile) -> PoFile {
  let entries : Array[PoEntry] = []
  for entry in self.entries {
    let translations = if entry.is_header() {
      entry.translations.copy()
    } else {
      match entry.msgid_plural {
        Some(_) =>
          Array::make(
            if entry.translations.length() > 2 {
              entry.translations.length()
            } else {
              2
            },
            "",
          )
        None => [""]
      }
    }
    entries.push({
      comments: entry.comments.copy(),
      context: entry.context,
      msgid: entry.msgid,
      msgid_plural: entry.msgid_plural,
      translations,
      obsolete: entry.obsolete,
    })
  }
  PoFile::new(entries)
}

///|
/// Serialize a document as a translation template.
pub fn write_pot(document : PoFile) -> String {
  write_po(document.as_template())
}
