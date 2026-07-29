# moongettext

Pure MoonBit tooling for GNU gettext catalogs.

`moongettext` parses and writes PO/POT text, compiles and reads MO revision 0
binaries, evaluates `Plural-Forms`, validates catalogs, merges templates, and
provides context-aware runtime lookup. The library code is backend-neutral and
is checked on MoonBit's `wasm`, `wasm-gc`, `js`, and `native` stable targets.

The file-oriented CLI uses `moonbitlang/x/fs`, so that package is intentionally
native-only.

## Why this package?

Applications often need a translation format that translators and existing
localization platforms already understand. PO is reviewable text, MO is a
compact runtime format, and the plural-expression language covers grammatical
rules that cannot be represented by a simple singular/plural Boolean.

`moongettext` keeps those concerns in one typed model:

- five PO comment classes: translator, extracted, reference, flag, previous;
- contexts, singular and plural entries, multiline strings, standard C escapes;
- obsolete `#~` entries and `fuzzy` filtering;
- deterministic semantic PO/POT serialization;
- GNU MO revision 0 read/write in both byte orders;
- a C-like `Plural-Forms` parser with short-circuit and ternary evaluation;
- runtime `gettext`, `pgettext`, `ngettext`, and `npgettext` operations;
- explicit catalog fallback;
- validation, statistics, source-reference queries, and POT/PO merging.

## Install

Install the package with Moon:

```bash
moon add YanFangNie/moongettext
```

For this source checkout, no global installation is required:

```bash
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon run examples/basic
```

The module pins `moonbitlang/x` for the native file CLI. The root library itself
uses only MoonBit core APIs.

## Quick start: parse and normalize PO

`parse_po` raises a structured `GettextError` for malformed input. `write_po`
normalizes layout but preserves the represented messages and comments.

```mbt check
///|
test "parse and normalize a PO entry" {
  let source =
    #|#. Shown on the launch screen
    #|#: src/main.mbt:12
    #|msgctxt "button"
    #|msgid "Open"
    #|msgstr "Ouvrir"
    #|
  let document = @moongettext.parse_po(source)
  assert_eq(document.entries.length(), 1)
  assert_true(
    document.find_entry("Open", context="button") is Some(entry) &&
    entry.translation(0) == Some("Ouvrir"),
  )
  let reparsed = @moongettext.parse_po(@moongettext.write_po(document))
  assert_true(reparsed == document)
}
```

PO serialization is a **semantic round trip**, not a byte-for-byte formatter:
indentation, blank lines, quoting, and multiline wrapping are canonicalized.

## Runtime lookup

Catalog construction reads `Plural-Forms` from the empty-`msgid` metadata
header. Missing translations return source text. Fuzzy and obsolete entries are
excluded from runtime catalogs by default.

```mbt check
///|
test "context and plural-aware lookup" {
  let document = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular(
      "",
      translation=(
        #|Content-Type: text/plain; charset=UTF-8
        #|Language: fr
        #|Plural-Forms: nplurals=2; plural=(n > 1);
        #|
      ),
    ),
    @moongettext.PoEntry::singular(
      "Open",
      translation="Ouvrir",
      context="button",
    ),
    @moongettext.PoEntry::plural("file", "files", ["fichier", "fichiers"]),
  ])
  let catalog = @moongettext.Catalog::from_po(document)
  assert_eq(catalog.pgettext("button", "Open"), "Ouvrir")
  assert_eq(catalog.ngettext("file", "files", 1), "fichier")
  assert_eq(catalog.ngettext("file", "files", 3), "fichiers")
  assert_eq(catalog.gettext("missing"), "missing")
}
```

Fallback is explicit:

```mbt check
///|
test "fallback catalog" {
  let primary = @moongettext.Catalog::from_po(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("Hello", translation="Salut"),
    ]),
  )
  let fallback = @moongettext.Catalog::from_po(
    @moongettext.PoFile::new([
      @moongettext.PoEntry::singular("Open", translation="Ouvrir"),
    ]),
  )
  assert_eq(primary.gettext("Hello", fallback~), "Salut")
  assert_eq(primary.gettext("Open", fallback~), "Ouvrir")
  assert_eq(primary.gettext("Unknown", fallback~), "Unknown")
}
```

## MO compile and load

`compile_mo_checked` first rejects validation errors and then emits deterministic
GNU MO revision 0 bytes. Obsolete, fuzzy, and untranslated non-header entries
are omitted. `parse_mo` validates all table ranges, NUL terminators, duplicate
keys, and UTF-8 before exposing a document.

```mbt check
///|
test "compile and load big-endian MO" {
  let source =
    #|msgid ""
    #|msgstr "Content-Type: text/plain; charset=UTF-8\n"
    #|
    #|msgid "Save"
    #|msgstr "Enregistrer"
    #|
  let po = @moongettext.parse_po(source)
  let bytes = @moongettext.compile_mo_checked(po, endian=Big)
  assert_true(@moongettext.mo_endian(bytes) == Big)
  let loaded = @moongettext.Catalog::from_mo(bytes)
  assert_eq(loaded.gettext("Save"), "Enregistrer")
}
```

Use `compile_mo` instead of `compile_mo_checked` only when a caller intentionally
handles validation separately.

## Plural-Forms

Supported operators, from high to low precedence:

1. primary values: integer, `n`, parentheses;
2. unary `!`, unary `+`, unary `-`;
3. `*`, `/`, `%`;
4. `+`, `-`;
5. `<`, `<=`, `>`, `>=`;
6. `==`, `!=`;
7. `&&`;
8. `||`;
9. right-associative `?:`.

Logical operations short-circuit and produce `0` or `1`.

```mbt check
///|
test "Russian three-form expression" {
  let rule = @moongettext.parse_plural_forms(
    "nplurals=3; plural=n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2;",
  )
  assert_eq(rule.select(1), 0)
  assert_eq(rule.select(2), 1)
  assert_eq(rule.select(5), 2)
  assert_eq(rule.select(21), 0)
}
```

Negative counts, division/modulo by zero, malformed syntax, and results outside
`[0, nplurals)` are reported as errors.

## Validate a catalog

`validate_po` returns every finding in stable order. It checks:

- metadata charset and `Plural-Forms`;
- duplicate context-aware keys;
- plural translation arity;
- embedded MO separator characters;
- fuzzy, obsolete, and untranslated entries;
- representative evaluation of plural rules for counts `0..=200`.

```mbt check
///|
test "structured validation report" {
  let invalid = @moongettext.PoFile::new([
    @moongettext.PoEntry::plural("item", "", [""]),
  ])
  let issues = @moongettext.validate_po(invalid)
  assert_true(@moongettext.validation_has_errors(issues))
  let report = @moongettext.validation_report(issues)
  assert_true(report.contains("empty-plural-id"))
}
```

`validate_po_strict` and `compile_mo_checked` raise if any `IssueError` exists.
Warnings do not block compilation.

## Merge a POT template

`merge_template(template, existing)` retains translations for matching
context/`msgid` keys, refreshes extracted comments and source references, keeps
translator notes, marks changed plural sources fuzzy, and carries removed
messages as obsolete.

```mbt check
///|
test "merge template with translated PO" {
  let template = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("Open"),
    @moongettext.PoEntry::singular("New"),
  ])
  let existing = @moongettext.PoFile::new([
    @moongettext.PoEntry::singular("Open", translation="Ouvrir"),
    @moongettext.PoEntry::singular("Old", translation="Ancien"),
  ])
  let merged = @moongettext.merge_template(template, existing)
  assert_true(merged.stats == { matched: 1, added: 1, obsoleted: 1 })
  assert_eq(merged.document.entries[0].translations[0], "Ouvrir")
  assert_true(merged.document.entries[2].obsolete)
}
```

Set `keep_obsolete=false` to omit removed entries.

## CLI

The native CLI is a reproducible example and a useful catalog probe:

```text
moon run cmd/main -- demo
moon run cmd/main -- validate examples/fr.po
moon run cmd/main -- normalize examples/fr.po
moon run cmd/main -- compile examples/fr.po _build/fr.mo
moon run cmd/main -- compile examples/fr.po _build/fr-be.mo --big-endian
moon run cmd/main -- inspect _build/fr.mo
```

`validate` returns exit status 1 for error findings. `compile` refuses error-level
findings and writes no partial output. Run `moon run cmd/main -- help` for the
same command summary.

The backend-neutral example is:

```bash
moon run examples/basic
```

Expected output:

```text
Ouvrir
0: fichier
1: fichier
2: fichiers
5: fichiers
```

## Main public API

| Area | Entry points |
| --- | --- |
| PO/POT | `parse_po`, `write_po`, `write_pot`, `PoFile::as_template` |
| MO | `compile_mo`, `compile_mo_checked`, `parse_mo`, `mo_endian` |
| Plurals | `parse_plural_forms`, `evaluate_plural_expression`, `PluralRule::select` |
| Runtime | `Catalog::from_po`, `Catalog::from_mo`, `gettext`, `pgettext`, `ngettext`, `npgettext` |
| Merge | `merge_template`, `MergeResult`, `MergeStats` |
| Validation | `validate_po`, `validate_po_strict`, `validation_report` |
| Query | `find_entry`, `flags`, `source_references`, `statistics`, `metadata` |

Run `moon info` to regenerate `pkg.generated.mbti`, which is the exact public
surface for the checked-out version.

## Compatibility and limits

See [docs/compatibility.md](docs/compatibility.md) for the detailed matrix.
Important boundaries:

- PO output preserves semantics, not original whitespace or line wrapping.
- MO revision 0 is supported; system-dependent revision extensions are not.
- MO strings must be UTF-8. Other declared charsets are reported.
- MO hash tables are accepted as header fields but ignored; emitted files use
  binary-search-compatible sorted original tables and no hash table.
- Advanced quoted source-reference filenames are retained as comment text but
  the convenience `source_references` tokenizer does not reconstruct them.
- This package does not extract translatable strings from MoonBit source and
  does not replace a translation-management platform.

## Project layout

```text
model / escape               shared PO model and string escaping
po_parser / po_writer         semantic PO/POT codec
plural_lexer / plural_parser  Plural-Forms grammar and evaluator
mo_reader / mo_writer         strict MO revision 0 codec
catalog                       indexed runtime lookup and fallback
validation / query / merge    tooling APIs
cmd/main                      native file CLI
examples/basic                backend-neutral runnable example
```

## Development and release checks

```bash
moon version --all
moon fmt --check
moon info --target all
moon check --target all --deny-warn --warn-list +73
moon test --target all --deny-warn --warn-list +73
moon build --target native
moon run examples/basic
moon run cmd/main -- validate examples/fr.po
moon package --frozen
git diff --exit-code
```

CI runs the same format/interface/check/build/test/example/CLI/package gates.

## Specification and source notice

This is an original MoonBit implementation informed by the public GNU gettext
format specifications and observable behavior. It is not a line-by-line port of
an existing codebase:

- [GNU gettext PO Files](https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html)
- [GNU gettext MO Files](https://www.gnu.org/software/gettext/manual/html_node/MO-Files.html)
- [GNU gettext Plural forms](https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html)

The ecosystem survey also found
[`Zhouz-z/moon_l10n`](https://mooncakes.io/docs/Zhouz-z/moon_l10n), which
focuses on an ICU MessageFormat subset and catalog linting. `moongettext`
instead focuses on GNU PO/POT/MO interoperability and gettext-style runtime
lookups; the projects have no implementation-source relationship.

No GNU gettext implementation source, generated code, or third-party catalog
fixture is copied into this repository. Test inputs are small original fixtures.
The project is licensed under Apache-2.0; see [LICENSE](LICENSE).
