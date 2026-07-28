///|
/// A structured error raised while reading, compiling, or validating a
/// gettext catalog.
pub(all) suberror GettextError {
  PoSyntax(line~ : Int, column~ : Int, message~ : String)
  PluralSyntax(position~ : Int, message~ : String)
  MoFormat(offset~ : Int, message~ : String)
  Validation(message~ : String)
} derive(Debug, Eq)

///|
/// The semantic kind of a comment attached to a PO entry.
///
/// GNU gettext distinguishes comments by the marker immediately following
/// `#`: no marker for translator comments, `.` for extracted comments, `:`
/// for source references, `,` for flags, and `|` for previous values.
pub(all) enum CommentKind {
  Translator
  Extracted
  Reference
  Flag
  Previous
} derive(Debug, Eq)

///|
/// A comment attached to a PO entry.
pub(all) struct PoComment {
  kind : CommentKind
  text : String
} derive(Debug, Eq)

///|
/// Construct a PO comment.
pub fn PoComment::new(kind : CommentKind, text : String) -> PoComment {
  { kind, text }
}

///|
/// One message entry in a PO or POT catalog.
///
/// `translations` stores `msgstr` as element zero for singular entries and
/// stores `msgstr[N]` values by numeric index for plural entries. Missing
/// indexes are represented by empty strings so indexes remain stable.
pub(all) struct PoEntry {
  comments : Array[PoComment]
  context : String?
  msgid : String
  msgid_plural : String?
  translations : Array[String]
  obsolete : Bool
} derive(Debug, Eq)

///|
/// Construct a singular entry without comments.
pub fn PoEntry::singular(
  msgid : String,
  translation? : String = "",
  context? : String,
) -> PoEntry {
  {
    comments: [],
    context,
    msgid,
    msgid_plural: None,
    translations: [translation],
    obsolete: false,
  }
}

///|
/// Construct a plural entry without comments.
pub fn PoEntry::plural(
  msgid : String,
  msgid_plural : String,
  translations : Array[String],
  context? : String,
) -> PoEntry {
  {
    comments: [],
    context,
    msgid,
    msgid_plural: Some(msgid_plural),
    translations,
    obsolete: false,
  }
}

///|
/// Return true when this entry is the conventional metadata header.
pub fn PoEntry::is_header(self : PoEntry) -> Bool {
  self.context is None && self.msgid == ""
}

///|
/// Return true when a flag comment contains the exact comma-separated flag.
pub fn PoEntry::has_flag(self : PoEntry, flag : String) -> Bool {
  for comment in self.comments {
    if comment.kind == Flag {
      for item in comment.text.split(",") {
        if item.trim().to_owned() == flag {
          return true
        }
      }
    }
  }
  false
}

///|
/// Return true when this entry has GNU gettext's `fuzzy` flag.
pub fn PoEntry::is_fuzzy(self : PoEntry) -> Bool {
  self.has_flag("fuzzy")
}

///|
/// Return a translation by plural index, or `None` if it is absent or empty.
pub fn PoEntry::translation(self : PoEntry, index : Int) -> String? {
  guard index >= 0 && index < self.translations.length() else { return None }
  let value = self.translations[index]
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
/// A parsed PO or POT file.
pub(all) struct PoFile {
  entries : Array[PoEntry]
} derive(Debug, Eq)

///|
/// Construct a catalog document from entries.
pub fn PoFile::new(entries : Array[PoEntry]) -> PoFile {
  { entries, }
}

///|
/// Return the first conventional metadata header entry, if present.
pub fn PoFile::header(self : PoFile) -> PoEntry? {
  for entry in self.entries {
    if entry.is_header() {
      return Some(entry)
    }
  }
  None
}

///|
/// Byte order used when writing or reading a GNU MO file.
pub(all) enum Endian {
  Little
  Big
} derive(Debug, Eq)
