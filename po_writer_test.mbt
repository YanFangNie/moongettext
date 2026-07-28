///|
test "PO parse write parse is a semantic round trip" {
  let source =
    #|# Human-facing note
    #|#. Extracted from UI
    #|#: src/ui.mbt:12
    #|#, fuzzy, moonbit-format
    #|#| msgid "Earlier"
    #|msgctxt "dialog"
    #|msgid "Hello\nworld"
    #|msgid_plural "Hello\nworlds"
    #|msgstr[0] "Bonjour\nmonde"
    #|msgstr[1] "Bonjour\nmondes"
    #|
    #|#~ msgid "Removed"
    #|#~ msgstr "Supprimé"
    #|
  let first = @moongettext.parse_po(source)
  let encoded = @moongettext.write_po(first)
  let second = @moongettext.parse_po(encoded)
  assert_true(first == second)
}

///|
test "writer uses canonical comment markers" {
  let document = @moongettext.PoFile::new([
    {
      comments: [
        @moongettext.PoComment::new(Translator, "for translators"),
        @moongettext.PoComment::new(Extracted, "from code"),
        @moongettext.PoComment::new(Reference, "main.mbt:7"),
        @moongettext.PoComment::new(Flag, "fuzzy"),
        @moongettext.PoComment::new(Previous, "msgid \"old\""),
      ],
      context: None,
      msgid: "new",
      msgid_plural: None,
      translations: ["nouveau"],
      obsolete: false,
    },
  ])
  inspect(
    @moongettext.write_po(document),
    content=(
      #|# for translators
      #|#. from code
      #|#: main.mbt:7
      #|#, fuzzy
      #|#| msgid "old"
      #|msgid "new"
      #|msgstr "nouveau"
      #|
      #|
    ),
  )
}

///|
test "POT generation clears translations but keeps header" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation="Content-Type: text/plain; charset=UTF-8\\n",
    ),
    @moongettext.PoEntry::singular("Open", translation="Ouvrir"),
    @moongettext.PoEntry::plural("file", "files", [
      "fichier", "fichiers", "many files",
    ]),
  ])
  let template = document.as_template()
  assert_eq(
    template.entries[0].translations[0],
    "Content-Type: text/plain; charset=UTF-8\\n",
  )
  assert_true(template.entries[1].translations == [""])
  assert_true(template.entries[2].translations == ["", "", ""])
  let reparsed = @moongettext.parse_po(@moongettext.write_pot(document))
  assert_true(reparsed == template)
}
