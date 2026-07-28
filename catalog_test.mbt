///|
fn french_document() -> @moongettext.PoFile {
  @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Language: fr
        #|Content-Type: text/plain; charset=UTF-8
        #|Plural-Forms: nplurals=2; plural=(n > 1);
        #|
      ),
    ),
    @moongettext.PoEntry::singular("Open", translation="Ouvrir"),
    @moongettext.PoEntry::singular(
      "Open",
      translation="Ouvert",
      context="adjective",
    ),
    @moongettext.PoEntry::plural("file", "files", ["fichier", "fichiers"]),
  ])
}

///|
test "metadata parser handles fields and continuations" {
  let fields = @moongettext.parse_header_fields(
    "Language: fr\nX-Long: first\n second\n\tthird\ninvalid\n",
  )
  assert_eq(fields["Language"], "fr")
  assert_eq(fields["X-Long"], "first second third")
  assert_false(fields.contains("invalid"))
}

///|
test "catalog supports singular and contextual lookup" {
  let catalog = @moongettext.Catalog::from_po(french_document())
  assert_eq(catalog.length(), 3)
  assert_eq(catalog.gettext("Open"), "Ouvrir")
  assert_eq(catalog.pgettext("adjective", "Open"), "Ouvert")
  assert_eq(catalog.pgettext("missing", "Open"), "Open")
  assert_eq(catalog.gettext("Unknown"), "Unknown")
}

///|
test "catalog evaluates language-specific plural rules" {
  let catalog = @moongettext.Catalog::from_po(french_document())
  assert_eq(catalog.ngettext("file", "files", 0), "fichier")
  assert_eq(catalog.ngettext("file", "files", 1), "fichier")
  assert_eq(catalog.ngettext("file", "files", 2), "fichiers")
  assert_eq(catalog.plural_rule().nplurals, 2)
}

///|
test "catalog fallback is tried before source text" {
  let primary = @moongettext.Catalog::from_po(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("Hello", translation="Salut"),
    ]),
  )
  let fallback = @moongettext.Catalog::from_po(french_document())
  assert_eq(primary.gettext("Open", fallback~), "Ouvrir")
  assert_eq(primary.pgettext("adjective", "Open", fallback~), "Ouvert")
  assert_eq(primary.ngettext("file", "files", 2, fallback~), "fichiers")
  assert_eq(primary.ngettext("apple", "apples", 1), "apple")
  assert_eq(primary.ngettext("apple", "apples", 4), "apples")
}

///|
test "fuzzy and obsolete entries are ignored unless requested" {
  let document = @moongettext.PoFile::new([
    {
      comments: [@moongettext.PoComment::new(Flag, "fuzzy")],
      context: None,
      msgid: "Draft",
      msgid_plural: None,
      translations: ["Brouillon"],
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
  let normal = @moongettext.Catalog::from_po(document)
  let preview = @moongettext.Catalog::from_po(document, include_fuzzy=true)
  assert_eq(normal.gettext("Draft"), "Draft")
  assert_eq(preview.gettext("Draft"), "Brouillon")
  assert_eq(preview.gettext("Old"), "Old")
}

///|
test "catalog can load compiled MO bytes" {
  let bytes = @moongettext.compile_mo(french_document(), endian=Big)
  let catalog = @moongettext.Catalog::from_mo(bytes)
  assert_eq(catalog.gettext("Open"), "Ouvrir")
  assert_eq(catalog.ngettext("file", "files", 3), "fichiers")
}

///|
test "duplicate runtime keys are rejected" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("Same", translation="Un"),
    @moongettext.PoEntry::singular("Same", translation="Deux"),
  ])
  try @moongettext.Catalog::from_po(document) catch {
    Validation(message~) =>
      inspect(message, content="duplicate catalog key: Same")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected duplicate error")
  }
}
