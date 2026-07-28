///|
test "entry flags and translation access" {
  let entry : @moongettext.PoEntry = {
    comments: [@moongettext.PoComment::new(Flag, "python-format, fuzzy")],
    context: Some("button"),
    msgid: "Open",
    msgid_plural: None,
    translations: ["Ouvrir"],
    obsolete: false,
  }
  assert_true(entry.has_flag("fuzzy"))
  assert_false(entry.has_flag("c-format"))
  assert_true(entry.is_fuzzy())
  debug_inspect(entry.translation(0), content="Some(\"Ouvrir\")")
  debug_inspect(entry.translation(1), content="None")
}

///|
test "PO escaping round trips Unicode and control characters" {
  let original = "quote=\" slash=\\ line\n tab\t 中文"
  let escaped = @moongettext.escape_po_string(original)
  inspect(escaped, content="quote=\\\" slash=\\\\ line\\n tab\\t 中文")
  assert_eq(@moongettext.unescape_po_string(escaped), original)
  assert_eq(@moongettext.unescape_po_string("\\x41\\101"), "AA")
}

///|
test "invalid hexadecimal escape is rejected" {
  try @moongettext.unescape_po_string("\\x") catch {
    PoSyntax(message~, ..) =>
      inspect(message, content="hexadecimal escape requires at least one digit")
    _ => fail("unexpected error type")
  } noraise {
    _ => fail("expected an error")
  }
}
