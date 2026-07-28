///|
priv struct MoPair {
  original : Bytes
  translation : Bytes
}

///|
fn mo_original_text(entry : PoEntry) -> String {
  let contextual = match entry.context {
    Some(context) => context + "\u{0004}" + entry.msgid
    None => entry.msgid
  }
  match entry.msgid_plural {
    Some(plural) => contextual + "\u{0000}" + plural
    None => contextual
  }
}

///|
fn mo_translation_text(entry : PoEntry) -> String {
  entry.translations.join("\u{0000}")
}

///|
fn entry_has_mo_translation(entry : PoEntry) -> Bool {
  if entry.is_header() {
    return true
  }
  for value in entry.translations {
    if value != "" {
      return true
    }
  }
  false
}

///|
fn collect_mo_pairs(document : PoFile) -> Array[MoPair] raise GettextError {
  let pairs : Array[MoPair] = []
  let seen : Map[String, Unit] = {}
  for entry in document.entries {
    if entry.obsolete || entry.is_fuzzy() || !entry_has_mo_translation(entry) {
      continue
    }
    let original_text = mo_original_text(entry)
    if seen.contains(original_text) {
      raise Validation(message="duplicate MO key: \{entry.msgid}")
    }
    seen[original_text] = ()
    pairs.push({
      original: @utf8.encode(original_text),
      translation: @utf8.encode(mo_translation_text(entry)),
    })
  }
  pairs.sort_by((left, right) => left.original.lexical_compare(right.original))
  pairs
}

///|
fn write_u32_at(
  buffer : Array[Byte],
  offset : Int,
  value : Int,
  endian : Endian,
) -> Unit {
  let byte0 = value.to_byte()
  let byte1 = (value >> 8).to_byte()
  let byte2 = (value >> 16).to_byte()
  let byte3 = (value >> 24).to_byte()
  match endian {
    Little => {
      buffer[offset] = byte0
      buffer[offset + 1] = byte1
      buffer[offset + 2] = byte2
      buffer[offset + 3] = byte3
    }
    Big => {
      buffer[offset] = byte3
      buffer[offset + 1] = byte2
      buffer[offset + 2] = byte1
      buffer[offset + 3] = byte0
    }
  }
}

///|
fn write_mo_magic(buffer : Array[Byte], endian : Endian) -> Unit {
  match endian {
    Little => {
      buffer[0] = b'\xde'
      buffer[1] = b'\x12'
      buffer[2] = b'\x04'
      buffer[3] = b'\x95'
    }
    Big => {
      buffer[0] = b'\x95'
      buffer[1] = b'\x04'
      buffer[2] = b'\x12'
      buffer[3] = b'\xde'
    }
  }
}

///|
/// Compile a PO document into GNU MO revision 0 bytes.
///
/// Obsolete, fuzzy, and untranslated non-header entries are deliberately
/// omitted, matching the behavior expected from a production message
/// compiler. Original strings are sorted by their UTF-8 byte representation.
pub fn compile_mo(
  document : PoFile,
  endian? : Endian = Little,
) -> Bytes raise GettextError {
  let pairs = collect_mo_pairs(document)
  let count = pairs.length()
  if count > (2147483647 - 28) / 16 {
    raise Validation(message="catalog is too large for an MO revision 0 file")
  }
  let original_table = 28
  let translation_table = original_table + count * 8
  let data_start = translation_table + count * 8
  let output = Array::make(data_start, b'\x00')
  let original_lengths : Array[Int] = []
  let original_offsets : Array[Int] = []
  let translation_lengths : Array[Int] = []
  let translation_offsets : Array[Int] = []

  for pair in pairs {
    original_lengths.push(pair.original.length())
    original_offsets.push(output.length())
    output.append(pair.original.to_array())
    output.push(b'\x00')
  }
  for pair in pairs {
    translation_lengths.push(pair.translation.length())
    translation_offsets.push(output.length())
    output.append(pair.translation.to_array())
    output.push(b'\x00')
  }

  write_mo_magic(output, endian)
  write_u32_at(output, 4, 0, endian)
  write_u32_at(output, 8, count, endian)
  write_u32_at(output, 12, original_table, endian)
  write_u32_at(output, 16, translation_table, endian)
  write_u32_at(output, 20, 0, endian)
  write_u32_at(output, 24, 0, endian)
  for index in 0..<count {
    let original_slot = original_table + index * 8
    write_u32_at(output, original_slot, original_lengths[index], endian)
    write_u32_at(output, original_slot + 4, original_offsets[index], endian)
    let translation_slot = translation_table + index * 8
    write_u32_at(output, translation_slot, translation_lengths[index], endian)
    write_u32_at(
      output,
      translation_slot + 4,
      translation_offsets[index],
      endian,
    )
  }
  Bytes::from_array(output)
}
