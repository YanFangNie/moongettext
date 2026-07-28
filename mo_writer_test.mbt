///|
test "compile minimal little-endian MO file" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("a", translation="b"),
  ])
  let encoded = @moongettext.compile_mo(document)
  let expected : Bytes = [
    0xde, 0x12, 0x04, 0x95, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x1c,
    0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
    0x00, 0x2e, 0x00, 0x00, 0x00, 0x61, 0x00, 0x62, 0x00,
  ]
  assert_true(encoded == expected)
}

///|
test "compile minimal big-endian MO file" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("a", translation="b"),
  ])
  let encoded = @moongettext.compile_mo(document, endian=Big)
  let expected : Bytes = [
    0x95, 0x04, 0x12, 0xde, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
    0x00, 0x00, 0x1c, 0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x2e, 0x61, 0x00, 0x62, 0x00,
  ]
  assert_true(encoded == expected)
}

///|
test "compiler sorts keys and skips fuzzy obsolete untranslated entries" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("z", translation="zed"),
    {
      comments: [@moongettext.PoComment::new(Flag, "fuzzy")],
      context: None,
      msgid: "fuzzy",
      msgid_plural: None,
      translations: ["flou"],
      obsolete: false,
    },
    {
      comments: [],
      context: None,
      msgid: "obsolete",
      msgid_plural: None,
      translations: ["ancien"],
      obsolete: true,
    },
    @moongettext.PoEntry::singular("empty"),
    @moongettext.PoEntry::singular("a", translation="aye"),
  ])
  let encoded = @moongettext.compile_mo(document)
  assert_eq(encoded.length(), 72)
  assert_true(encoded[60:61].to_owned() == b"a")
  assert_true(encoded[62:63].to_owned() == b"z")
}

///|
test "compiler rejects duplicate context-aware keys" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("Open", translation="Ouvrir", context="verb"),
    @moongettext.PoEntry::singular("Open", translation="Ouvert", context="verb"),
  ])
  try @moongettext.compile_mo(document) catch {
    Validation(message~) => inspect(message, content="duplicate MO key: Open")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected duplicate-key error")
  }
}
