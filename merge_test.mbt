///|
fn merge_template_fixture() -> @moongettext.PoFile {
  @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Project-Id-Version: next
        #|Content-Type: text/plain; charset=UTF-8
        #|
      ),
    ),
    {
      comments: [
        @moongettext.PoComment::new(Extracted, "new extraction note"),
        @moongettext.PoComment::new(Reference, "new.mbt:10"),
      ],
      context: Some("button"),
      msgid: "Open",
      msgid_plural: None,
      translations: [""],
      obsolete: false,
    },
    @moongettext.PoEntry::plural("file", "files changed", ["", ""]),
    @moongettext.PoEntry::singular("New message"),
  ])
}

///|
fn existing_translation_fixture() -> @moongettext.PoFile {
  @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Project-Id-Version: translated
        #|Language: fr
        #|Content-Type: text/plain; charset=UTF-8
        #|Plural-Forms: nplurals=2; plural=n > 1;
        #|
      ),
    ),
    {
      comments: [
        @moongettext.PoComment::new(Translator, "keep this note"),
        @moongettext.PoComment::new(Reference, "old.mbt:1"),
      ],
      context: Some("button"),
      msgid: "Open",
      msgid_plural: None,
      translations: ["Ouvrir"],
      obsolete: false,
    },
    @moongettext.PoEntry::plural("file", "files", ["fichier", "fichiers"]),
    @moongettext.PoEntry::singular("Removed", translation="Supprimé"),
  ])
}

///|
test "template merge preserves translations and refreshes source comments" {
  let result = @moongettext.merge_template(
    merge_template_fixture(),
    existing_translation_fixture(),
  )
  assert_true(result.stats == { matched: 2, added: 1, obsoleted: 1 })
  let open = result.document.entries[1]
  assert_true(open.translations == ["Ouvrir"])
  assert_true(
    open.comments.contains(
      @moongettext.PoComment::new(Translator, "keep this note"),
    ),
  )
  assert_true(
    open.comments.contains(@moongettext.PoComment::new(Reference, "new.mbt:10")),
  )
  assert_false(
    open.comments.contains(@moongettext.PoComment::new(Reference, "old.mbt:1")),
  )
}

///|
test "changed plural source is marked fuzzy" {
  let result = @moongettext.merge_template(
    merge_template_fixture(),
    existing_translation_fixture(),
  )
  let plural = result.document.entries[2]
  assert_true(plural.translations == ["fichier", "fichiers"])
  assert_true(plural.is_fuzzy())
  assert_true(plural.msgid_plural == Some("files changed"))
}

///|
test "new entries stay untranslated and removed entries become obsolete" {
  let result = @moongettext.merge_template(
    merge_template_fixture(),
    existing_translation_fixture(),
  )
  let added = result.document.entries[3]
  assert_eq(added.msgid, "New message")
  assert_true(added.translations == [""])
  let removed = result.document.entries[4]
  assert_eq(removed.msgid, "Removed")
  assert_true(removed.obsolete)
  assert_true(removed.translations == ["Supprimé"])
}

///|
test "existing metadata translation wins over template placeholder" {
  let result = @moongettext.merge_template(
    merge_template_fixture(),
    existing_translation_fixture(),
  )
  let header = result.document.entries[0]
  assert_true(header.is_header())
  assert_true(header.translations[0].contains("Language: fr"))
  assert_true(header.translations[0].contains("Project-Id-Version: translated"))
}

///|
test "merge can discard entries removed from template" {
  let result = @moongettext.merge_template(
    merge_template_fixture(),
    existing_translation_fixture(),
    keep_obsolete=false,
  )
  assert_eq(result.document.entries.length(), 4)
  assert_eq(result.stats.obsoleted, 0)
}

///|
test "merged document survives normalized PO round trip" {
  let result = @moongettext.merge_template(
    merge_template_fixture(),
    existing_translation_fixture(),
  )
  let reparsed = @moongettext.parse_po(@moongettext.write_po(result.document))
  assert_true(reparsed == result.document)
}

///|
test "merge rejects duplicate template keys" {
  let duplicate = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("same"),
    @moongettext.PoEntry::singular("same"),
  ])
  try
    @moongettext.merge_template(duplicate, existing_translation_fixture())
  catch {
    Validation(message~) =>
      inspect(message, content="duplicate template key during merge: same")
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected duplicate error")
  }
}
