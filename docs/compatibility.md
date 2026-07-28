# Compatibility matrix

This document records what `moongettext` 0.1.0 accepts, normalizes, emits, or
deliberately leaves out. It is a scope statement, not a claim of drop-in
compatibility with every historical `gettext` implementation.

## PO and POT

| Feature | Status | Notes |
| --- | --- | --- |
| `msgid` / `msgstr` | Supported | Empty `msgid` is recognized as metadata header. |
| `msgctxt` | Supported | Encoded with EOT (`0x04`) in MO originals. |
| `msgid_plural` / `msgstr[N]` | Supported | Sparse indexes are filled with empty values during parse. |
| Multiline quoted strings | Supported | Concatenated semantically. |
| `\\`, `\"`, `\n`, `\r`, `\t` | Supported | Named control escapes also include `a`, `b`, `f`, and `v`. |
| Octal / hexadecimal escapes | Supported | Up to 3 octal digits; one or more hex digits. |
| Translator comments `#` | Supported | Preserved semantically. |
| Extracted comments `#.` | Supported | Preserved semantically. |
| References `#:` | Supported | Raw text is preserved; simple tokens have a typed query helper. |
| Flags `#,` | Supported | `fuzzy` affects compilation/runtime inclusion. |
| Previous values `#|` | Supported | Retained as typed comments, not reinterpreted as active fields. |
| Obsolete entries `#~` | Supported | Re-emitted with `#~` prefixes and excluded from MO output. |
| CRLF input | Supported | Writer emits LF. |
| Exact whitespace/layout | Not preserved | Writer produces canonical semantic output. |
| Domain directives | Out of scope | Use one `Catalog` per domain. |
| Source extraction | Out of scope | This release consumes PO/POT; it does not scan MoonBit source. |

Unknown active directives are rejected with a line-numbered `PoSyntax` error.
This avoids silently discarding catalog meaning.

## MO

| Feature | Read | Write | Notes |
| --- | --- | --- | --- |
| Revision 0 | Yes | Yes | Fully bounds-checked. |
| Little endian | Yes | Yes | Magic `de 12 04 95`. |
| Big endian | Yes | Yes | Magic `95 04 12 de`. |
| Context separator | Yes | Yes | EOT (`0x04`). |
| Plural separators | Yes | Yes | NUL between source/translated plural forms. |
| Sorted original table | Accepted | Emitted | Writer sorts UTF-8 bytes deterministically. |
| Hash table | Ignored | Not emitted | Header fields are tolerated if other ranges are valid. |
| System-dependent strings | No | No | MO revision extensions are not interpreted. |
| Non-UTF-8 catalogs | No | No | Invalid UTF-8 is rejected. |

The reader requires each table string to be followed by its specified NUL
terminator. All lengths and offsets must fit MoonBit `Int` and the input byte
array. Duplicate original keys are rejected.

## Plural expression grammar

The evaluator implements the portable expression subset documented for
`Plural-Forms`:

```text
conditional  := logical_or ("?" conditional ":" conditional)?
logical_or   := logical_and ("||" logical_and)*
logical_and  := equality ("&&" equality)*
equality     := relational (("==" | "!=") relational)*
relational   := additive (("<" | "<=" | ">" | ">=") additive)*
additive     := multiply (("+" | "-") multiply)*
multiply     := unary (("*" | "/" | "%") unary)*
unary        := ("!" | "+" | "-") unary | primary
primary      := INTEGER | "n" | "(" conditional ")"
```

Arithmetic uses MoonBit `Int`. Literal overflow is rejected. Runtime arithmetic
overflow is not promoted to arbitrary precision. Division and modulo by zero
raise validation errors. `PluralRule::select` rejects negative counts and
indexes outside the declared number of forms.

## Runtime behavior

- Catalog keys are `context + EOT + msgid`, or just `msgid` without context.
- Metadata headers are not exposed as translatable messages.
- Fuzzy and obsolete messages are not indexed by default.
- Empty translations trigger fallback.
- Fallback catalogs are explicit per lookup call.
- If every catalog misses, singular source text is chosen for `n == 1`, plural
  source text otherwise.
- A missing `Plural-Forms` header uses the English `n != 1` rule.

## Template merging

`merge_template` is intentionally smaller than GNU `msgmerge`:

- exact context/`msgid` matches retain translations;
- template extracted comments and references replace stale source metadata;
- translator and previous-value comments are retained;
- changed `msgid_plural` values are marked fuzzy;
- removed entries can be retained as obsolete;
- approximate/fuzzy string matching between renamed `msgid` values is not
  attempted.

This exact-key policy is deterministic and avoids silently attaching a
translation to the wrong source string.

## Reference material

- <https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html>
- <https://www.gnu.org/software/gettext/manual/html_node/MO-Files.html>
- <https://www.gnu.org/software/gettext/manual/html_node/Plural-forms.html>

