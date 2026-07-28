///|
test "source references parse paths lines columns and Windows drives" {
  let entry : @moongettext.PoEntry = {
    comments: [
      @moongettext.PoComment::new(
        Reference,
        "src/main.mbt:12 ui.mbt:8:4 C:\\work\\app.mbt:9 generated.mbt",
      ),
      @moongettext.PoComment::new(Reference, "src/main.mbt:12"),
    ],
    context: None,
    msgid: "Open",
    msgid_plural: None,
    translations: ["Ouvrir"],
    obsolete: false,
  }
  assert_true(
    entry.source_references() ==
    [
      { path: "src/main.mbt", line: Some(12), column: None },
      { path: "ui.mbt", line: Some(8), column: Some(4) },
      { path: "C:\\work\\app.mbt", line: Some(9), column: None },
      { path: "generated.mbt", line: None, column: None },
    ],
  )
}

///|
test "flags are deduplicated in first-seen order" {
  let entry : @moongettext.PoEntry = {
    comments: [
      @moongettext.PoComment::new(Flag, "fuzzy, moonbit-format"),
      @moongettext.PoComment::new(Flag, "fuzzy, c-format"),
    ],
    context: None,
    msgid: "value",
    msgid_plural: None,
    translations: [""],
    obsolete: false,
  }
  assert_true(entry.flags() == ["fuzzy", "moonbit-format", "c-format"])
}

///|
test "find entry respects context and obsolete filtering" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("Open", translation="Ouvrir", context="verb"),
    {
      comments: [],
      context: Some("old"),
      msgid: "Open",
      msgid_plural: None,
      translations: ["Ancien"],
      obsolete: true,
    },
  ])
  assert_true(document.find_entry("Open", context="verb") is Some(_))
  assert_true(document.find_entry("Open", context="missing") is None)
  assert_true(document.find_entry("Open", context="old") is None)
  assert_true(
    document.find_entry("Open", context="old", include_obsolete=true) is Some(_),
  )
}

///|
test "statistics summarize catalog status in one pass" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("", translation="Language: fr\\n"),
    @moongettext.PoEntry::singular("Open", translation="Ouvrir"),
    @moongettext.PoEntry::plural("file", "files", ["", ""]),
    {
      comments: [@moongettext.PoComment::new(Flag, "fuzzy")],
      context: Some("button"),
      msgid: "Save",
      msgid_plural: None,
      translations: ["Sauver"],
      obsolete: false,
    },
    {
      comments: [],
      context: None,
      msgid: "Old",
      msgid_plural: None,
      translations: ["Ancien"],
      obsolete: true,
    },
  ])
  assert_true(
    document.statistics() ==
    {
      headers: 1,
      messages: 4,
      active: 3,
      translated: 3,
      untranslated: 1,
      fuzzy: 1,
      obsolete: 1,
      singular: 3,
      plural: 1,
      contextual: 1,
    },
  )
}
