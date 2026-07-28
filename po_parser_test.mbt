///|
test "parse comments context plural and multiline values" {
  let source =
    #|# Translator note
    #|#. Extracted note
    #|#: src/cart.mbt:42 templates/cart.mbt:8
    #|#, moonbit-format, fuzzy
    #|#| msgid "Old cart"
    #|msgctxt "menu"
    #|msgid ""
    #|"Shopping "
    #|"cart"
    #|msgid_plural "Shopping carts"
    #|msgstr[0] ""
    #|"Panier"
    #|msgstr[1] "Paniers"
    #|
  let document = @moongettext.parse_po(source)
  assert_eq(document.entries.length(), 1)
  let entry = document.entries[0]
  assert_true(entry.context == Some("menu"))
  assert_eq(entry.msgid, "Shopping cart")
  assert_true(entry.msgid_plural == Some("Shopping carts"))
  assert_true(entry.translations == ["Panier", "Paniers"])
  assert_eq(entry.comments.length(), 5)
  assert_true(entry.is_fuzzy())
}

///|
test "parse CRLF header and escaped content" {
  let source = [
    "msgid \"\"", "msgstr \"Project-Id-Version: demo\\\\n\"", "", "msgid \"say \\\"hi\\\"\"",
    "msgstr \"dire \\\"salut\\\"\"", "",
  ].join("\r\n")
  let document = @moongettext.parse_po(source)
  assert_eq(document.entries.length(), 2)
  assert_true(document.entries[0].is_header())
  assert_eq(document.entries[0].translations[0], "Project-Id-Version: demo\\n")
  assert_eq(document.entries[1].msgid, "say \"hi\"")
}

///|
test "parse obsolete entry" {
  let source =
    #|#~ msgctxt "legacy"
    #|#~ msgid "Dial"
    #|#~ msgstr "Cadran"
    #|
  let document = @moongettext.parse_po(source)
  assert_eq(document.entries.length(), 1)
  assert_true(document.entries[0].obsolete)
  assert_true(document.entries[0].context == Some("legacy"))
  assert_true(document.entries[0].translations == ["Cadran"])
}

///|
test "reject continuation without a field" {
  try @moongettext.parse_po("\"orphan\"\n") catch {
    PoSyntax(line~, message~, ..) => {
      inspect(line, content="1")
      inspect(message, content="quoted continuation has no preceding field")
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected parsing to fail")
  }
}

///|
test "reject malformed plural index" {
  let source =
    #|msgid "item"
    #|msgid_plural "items"
    #|msgstr[x] "items"
    #|
  try @moongettext.parse_po(source) catch {
    PoSyntax(message~, ..) =>
      inspect(message, content="msgstr index must be a decimal integer")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected parsing to fail")
  }
}
