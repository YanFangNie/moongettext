///|
test "well-formed catalog has no validation errors" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Content-Type: text/plain; charset=UTF-8
        #|Plural-Forms: nplurals=2; plural=n != 1;
        #|
      ),
    ),
    @moongettext.PoEntry::plural("file", "files", ["fichier", "fichiers"]),
  ])
  let findings = @moongettext.validate_po(document)
  assert_false(@moongettext.validation_has_errors(findings))
  assert_true(@moongettext.compile_mo_checked(document).length() > 28)
}

///|
test "validator finds duplicates and plural arity" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Content-Type: text/plain; charset=UTF-8
        #|Plural-Forms: nplurals=3; plural=n == 1 ? 0 : 2;
        #|
      ),
    ),
    @moongettext.PoEntry::plural("item", "items", ["article", "articles"]),
    @moongettext.PoEntry::plural("item", "items", ["x", "y", "z"]),
  ])
  let findings = @moongettext.validate_po(document)
  assert_true(@moongettext.validation_has_errors(findings))
  assert_true(findings.any(finding => finding.code == "plural-arity"))
  assert_true(findings.any(finding => finding.code == "duplicate-key"))
}

///|
test "validator reports fuzzy untranslated obsolete and missing header" {
  let document = @moongettext.PoFile::new([
    {
      comments: [@moongettext.PoComment::new(Flag, "fuzzy")],
      context: None,
      msgid: "Draft",
      msgid_plural: None,
      translations: [""],
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
  let findings = @moongettext.validate_po(document)
  assert_true(findings.any(finding => finding.code == "missing-header"))
  assert_true(findings.any(finding => finding.code == "fuzzy"))
  assert_true(findings.any(finding => finding.code == "untranslated"))
  assert_true(findings.any(finding => finding.code == "obsolete"))
  assert_false(@moongettext.validation_has_errors(findings))
}

///|
test "validator rejects MO separator collisions" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "bad\u{0000}id",
      translation="bad\u{0000}translation",
      context="bad\u{0004}context",
    ),
  ])
  let findings = @moongettext.validate_po(document)
  assert_true(findings.any(finding => finding.code == "nul-msgid"))
  assert_true(findings.any(finding => finding.code == "invalid-context"))
  assert_true(findings.any(finding => finding.code == "nul-translation"))
}

///|
test "validator catches plural rules that leave declared range" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Content-Type: text/plain; charset=UTF-8
        #|Plural-Forms: nplurals=2; plural=2;
        #|
      ),
    ),
  ])
  let findings = @moongettext.validate_po(document)
  assert_true(findings.any(finding => finding.code == "plural-rule-runtime"))
}

///|
test "strict validation returns a readable report" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::plural("one", "", ["un"]),
  ])
  try @moongettext.validate_po_strict(document) catch {
    Validation(message~) => {
      assert_true(message.contains("[ERROR]"))
      assert_true(message.contains("empty-plural-id"))
    }
    _ => fail("unexpected error")
  } noraise {
    _ => fail("expected strict validation to fail")
  }
}
