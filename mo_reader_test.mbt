///|
fn roundtrip_mo_document() -> @moongettext.PoFile {
  @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Project-Id-Version: moongettext
        #|Language: fr
        #|Plural-Forms: nplurals=2; plural=(n > 1);
        #|
      ),
    ),
    @moongettext.PoEntry::singular("Open", translation="Ouvrir", context="verb"),
    @moongettext.PoEntry::plural("file", "files", ["fichier", "fichiers"]),
    @moongettext.PoEntry::singular("snowman ☃", translation="bonhomme ☃"),
  ])
}

///|
test "little-endian MO round trip preserves contexts plurals and Unicode" {
  let original = roundtrip_mo_document()
  let encoded = @moongettext.compile_mo(original, endian=Little)
  assert_true(@moongettext.mo_endian(encoded) == Little)
  let decoded = @moongettext.parse_mo(encoded)
  assert_eq(decoded.entries.length(), original.entries.length())
  assert_true(@moongettext.compile_mo(decoded, endian=Little) == encoded)
  assert_true(decoded.entries[0].is_header())
}

///|
test "big-endian MO round trip preserves contexts plurals and Unicode" {
  let original = roundtrip_mo_document()
  let encoded = @moongettext.compile_mo(original, endian=Big)
  assert_true(@moongettext.mo_endian(encoded) == Big)
  let decoded = @moongettext.parse_mo(encoded)
  assert_eq(decoded.entries.length(), original.entries.length())
  assert_true(@moongettext.compile_mo(decoded, endian=Big) == encoded)
  assert_true(decoded.entries[0].is_header())
}

///|
test "MO reader rejects short input and invalid magic" {
  try @moongettext.parse_mo(b"tiny") catch {
    MoFormat(message~, ..) =>
      inspect(message, content="MO file is shorter than its 28-byte header")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected short-file error")
  }
  let invalid = Bytes::make(28, b'\x00')
  try @moongettext.parse_mo(invalid) catch {
    MoFormat(message~, ..) =>
      inspect(message, content="invalid GNU MO magic word")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected magic error")
  }
}

///|
test "MO reader rejects unsupported revision" {
  let valid = @moongettext.compile_mo(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("a", translation="b"),
    ]),
  )
  let changed = valid.to_array()
  changed[4] = b'\x01'
  try @moongettext.parse_mo(Bytes::from_array(changed)) catch {
    MoFormat(message~, ..) =>
      inspect(
        message,
        content="unsupported MO revision 1; only revision 0 is supported",
      )
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected revision error")
  }
}

///|
test "MO reader rejects out-of-bounds table" {
  let valid = @moongettext.compile_mo(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("a", translation="b"),
    ]),
  )
  let changed = valid.to_array()
  changed[12] = b'\xff'
  try @moongettext.parse_mo(Bytes::from_array(changed)) catch {
    MoFormat(message~, ..) =>
      inspect(message, content="MO string or table range is outside the file")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected table-range error")
  }
}

///|
test "MO reader rejects malformed UTF-8" {
  let valid = @moongettext.compile_mo(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("a", translation="b"),
    ]),
  )
  let changed = valid.to_array()
  changed[44] = b'\xff'
  try @moongettext.parse_mo(Bytes::from_array(changed)) catch {
    MoFormat(offset~, message~) => {
      inspect(offset, content="44")
      inspect(message, content="MO string is not valid UTF-8")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected UTF-8 error")
  }
}

///|
test "MO reader rejects missing string terminator" {
  let valid = @moongettext.compile_mo(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("a", translation="b"),
    ]),
  )
  let changed = valid.to_array()
  changed[45] = b'x'
  try @moongettext.parse_mo(Bytes::from_array(changed)) catch {
    MoFormat(message~, ..) =>
      inspect(message, content="MO string is not followed by a NUL terminator")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected terminator error")
  }
}
