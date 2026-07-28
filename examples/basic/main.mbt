///|
/// A dependency-free runtime example that works on every stable MoonBit
/// backend. The file-oriented CLI lives in `cmd/main`.
fn main {
  let source =
    #|msgid ""
    #|msgstr ""
    #|"Language: fr\n"
    #|"Content-Type: text/plain; charset=UTF-8\n"
    #|"Plural-Forms: nplurals=2; plural=(n > 1);\n"
    #|
    #|msgctxt "button"
    #|msgid "Open"
    #|msgstr "Ouvrir"
    #|
    #|msgid "file"
    #|msgid_plural "files"
    #|msgstr[0] "fichier"
    #|msgstr[1] "fichiers"
    #|
  let document = try! @moongettext.parse_po(source)
  let findings = @moongettext.validate_po(document)
  if @moongettext.validation_has_errors(findings) {
    println(@moongettext.validation_report(findings))
    return
  }
  let binary = try! @moongettext.compile_mo_checked(document)
  let catalog = try! @moongettext.Catalog::from_mo(binary)
  println(catalog.pgettext("button", "Open"))
  for n in [0, 1, 2, 5] {
    println("\{n}: \{try! catalog.ngettext("file", "files", n)}")
  }
}
