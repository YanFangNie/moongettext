///|
fn detect_mo_endian(bytes : Bytes) -> Endian raise GettextError {
  if bytes.length() < 4 {
    raise MoFormat(offset=0, message="MO file is shorter than its magic word")
  }
  if bytes[0] == b'\xde' &&
    bytes[1] == b'\x12' &&
    bytes[2] == b'\x04' &&
    bytes[3] == b'\x95' {
    Little
  } else if bytes[0] == b'\x95' &&
    bytes[1] == b'\x04' &&
    bytes[2] == b'\x12' &&
    bytes[3] == b'\xde' {
    Big
  } else {
    raise MoFormat(offset=0, message="invalid GNU MO magic word")
  }
}

///|
/// Detect byte order from a GNU MO magic word.
pub fn mo_endian(bytes : Bytes) -> Endian raise GettextError {
  detect_mo_endian(bytes)
}

///|
fn read_u32_at(
  bytes : Bytes,
  offset : Int,
  endian : Endian,
) -> Int raise GettextError {
  if offset < 0 || offset > bytes.length() - 4 {
    raise MoFormat(offset~, message="truncated 32-bit MO field")
  }
  let first = bytes[offset].to_int()
  let second = bytes[offset + 1].to_int()
  let third = bytes[offset + 2].to_int()
  let fourth = bytes[offset + 3].to_int()
  let high = match endian {
    Little => fourth
    Big => first
  }
  if high >= 128 {
    raise MoFormat(
      offset~,
      message="32-bit MO field exceeds the supported signed Int range",
    )
  }
  match endian {
    Little => first | (second << 8) | (third << 16) | (fourth << 24)
    Big => fourth | (third << 8) | (second << 16) | (first << 24)
  }
}

///|
fn checked_mo_range(
  offset : Int,
  length : Int,
  total : Int,
  field_offset : Int,
) -> Unit raise GettextError {
  if offset < 0 || length < 0 || offset > total || length > total - offset {
    raise MoFormat(
      offset=field_offset,
      message="MO string or table range is outside the file",
    )
  }
}

///|
fn read_mo_string(
  bytes : Bytes,
  offset : Int,
  length : Int,
  field_offset : Int,
) -> String raise GettextError {
  checked_mo_range(offset, length, bytes.length(), field_offset)
  if offset + length >= bytes.length() || bytes[offset + length] != b'\x00' {
    raise MoFormat(
      offset=field_offset,
      message="MO string is not followed by a NUL terminator",
    )
  }
  try @utf8.decode(bytes[offset:offset + length]) catch {
    _ => raise MoFormat(offset~, message="MO string is not valid UTF-8")
  } noraise {
    value => value
  }
}

///|
fn split_mo_original(
  original : String,
  field_offset : Int,
) -> (String?, String, String?) raise GettextError {
  let forms = original.split("\u{0000}").to_array()
  if forms.length() > 2 {
    raise MoFormat(
      offset=field_offset,
      message="MO original contains more than one plural separator",
    )
  }
  let singular_with_context = forms[0].to_owned()
  let plural = if forms.length() == 2 {
    Some(forms[1].to_owned())
  } else {
    None
  }
  match singular_with_context.split_once("\u{0004}") {
    Some((context, singular)) =>
      (Some(context.to_owned()), singular.to_owned(), plural)
    None => (None, singular_with_context, plural)
  }
}

///|
fn split_mo_translation(translation : String) -> Array[String] {
  translation.split("\u{0000}").map(part => part.to_owned()).to_array()
}

///|
/// Parse a GNU MO revision 0 file into the shared catalog model.
///
/// Both little- and big-endian files are accepted. Header/table bounds, NUL
/// terminators, UTF-8 strings, duplicate keys, context separators, and plural
/// separators are checked before a document is returned.
pub fn parse_mo(bytes : Bytes) -> PoFile raise GettextError {
  if bytes.length() < 28 {
    raise MoFormat(
      offset=0,
      message="MO file is shorter than its 28-byte header",
    )
  }
  let endian = detect_mo_endian(bytes)
  let revision = read_u32_at(bytes, 4, endian)
  if revision != 0 {
    raise MoFormat(
      offset=4,
      message="unsupported MO revision \{revision}; only revision 0 is supported",
    )
  }
  let count = read_u32_at(bytes, 8, endian)
  let original_table = read_u32_at(bytes, 12, endian)
  let translation_table = read_u32_at(bytes, 16, endian)
  if count > 2147483647 / 8 {
    raise MoFormat(offset=8, message="MO string count is too large")
  }
  let table_size = count * 8
  checked_mo_range(original_table, table_size, bytes.length(), 12)
  checked_mo_range(translation_table, table_size, bytes.length(), 16)

  let entries : Array[PoEntry] = []
  let seen : Map[String, Unit] = {}
  for index in 0..<count {
    let original_slot = original_table + index * 8
    let translation_slot = translation_table + index * 8
    let original_length = read_u32_at(bytes, original_slot, endian)
    let original_offset = read_u32_at(bytes, original_slot + 4, endian)
    let translation_length = read_u32_at(bytes, translation_slot, endian)
    let translation_offset = read_u32_at(bytes, translation_slot + 4, endian)
    let original = read_mo_string(
      bytes, original_offset, original_length, original_slot,
    )
    let translation = read_mo_string(
      bytes, translation_offset, translation_length, translation_slot,
    )
    if seen.contains(original) {
      raise MoFormat(
        offset=original_slot,
        message="duplicate MO original string",
      )
    }
    seen[original] = ()
    let (context, msgid, msgid_plural) = split_mo_original(
      original, original_slot,
    )
    let translations = split_mo_translation(translation)
    if msgid_plural is None && translations.length() > 1 {
      raise MoFormat(
        offset=translation_slot,
        message="singular MO entry contains plural translations",
      )
    }
    entries.push({
      comments: [],
      context,
      msgid,
      msgid_plural,
      translations,
      obsolete: false,
    })
  }
  PoFile::new(entries)
}
