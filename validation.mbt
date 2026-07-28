///|
/// Severity assigned to a catalog validation issue.
pub(all) enum IssueSeverity {
  IssueInfo
  IssueWarning
  IssueError
} derive(Debug, Eq)

///|
/// One deterministic catalog validation finding.
pub(all) struct ValidationIssue {
  severity : IssueSeverity
  entry : Int?
  code : String
  message : String
} derive(Debug, Eq)

///|
fn issue(
  severity : IssueSeverity,
  entry : Int?,
  code : String,
  message : String,
) -> ValidationIssue {
  { severity, entry, code, message }
}

///|
fn gettext_error_message(error : GettextError) -> String {
  match error {
    PoSyntax(message~, ..) => message
    PluralSyntax(message~, ..) => message
    MoFormat(message~, ..) => message
    Validation(message~) => message
  }
}

///|
fn contains_nul(value : String) -> Bool {
  value.contains_char('\u{0000}')
}

///|
fn all_translations_empty(entry : PoEntry) -> Bool {
  for value in entry.translations {
    if value != "" {
      return false
    }
  }
  true
}

///|
fn validate_plural_rule_samples(
  rule : PluralRule,
  issues : Array[ValidationIssue],
) -> Unit {
  let mut failed = false
  for n in 0..<=200 {
    if failed {
      break
    }
    try rule.select(n) catch {
      error => {
        issues.push(
          issue(
            IssueError,
            None,
            "plural-rule-runtime",
            "Plural-Forms fails for n=\{n}: \{gettext_error_message(error)}",
          ),
        )
        failed = true
      }
    } noraise {
      _ => ()
    }
  }
}

///|
/// Validate PO/POT semantics used by the parser, MO compiler, and runtime.
///
/// The returned array is stable in document order. Validation checks metadata,
/// plural rules, duplicate context-aware keys, translation arity, fuzzy and
/// obsolete status, embedded NULs, and context separator collisions.
pub fn validate_po(document : PoFile) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let metadata = document.metadata()
  let mut plural_rule : PluralRule? = None
  let mut has_plural_entry = false

  match document.header() {
    Some(_) => {
      match metadata.get("Content-Type") {
        Some(content_type) =>
          if !content_type.contains("charset=UTF-8") &&
            !content_type.contains("charset=utf-8") {
            issues.push(
              issue(
                IssueWarning,
                None,
                "header-charset",
                "moongettext reads and writes MO strings as UTF-8; declare charset=UTF-8",
              ),
            )
          }
        None =>
          issues.push(
            issue(
              IssueWarning,
              None,
              "header-content-type",
              "metadata header does not declare Content-Type",
            ),
          )
      }
      match metadata.get("Plural-Forms") {
        Some(value) =>
          try parse_plural_forms(value) catch {
            error =>
              issues.push(
                issue(
                  IssueError,
                  None,
                  "plural-forms",
                  "invalid Plural-Forms: \{gettext_error_message(error)}",
                ),
              )
          } noraise {
            rule => plural_rule = Some(rule)
          }
        None => ()
      }
    }
    None =>
      issues.push(
        issue(
          IssueWarning,
          None,
          "missing-header",
          "catalog has no empty-msgid metadata header",
        ),
      )
  }

  let seen : Map[String, Int] = Map([])
  for entry_index, entry in document.entries {
    if entry.is_header() {
      continue
    }
    let key = catalog_key(entry.msgid, entry.context)
    match seen.get(key) {
      Some(previous) =>
        issues.push(
          issue(
            IssueError,
            Some(entry_index),
            "duplicate-key",
            "duplicates entry \{previous} for msgid '\{entry.msgid}'",
          ),
        )
      None => seen[key] = entry_index
    }

    if contains_nul(entry.msgid) {
      issues.push(
        issue(
          IssueError,
          Some(entry_index),
          "nul-msgid",
          "msgid contains NUL, which conflicts with the MO plural separator",
        ),
      )
    }
    match entry.context {
      Some(context) =>
        if contains_nul(context) || context.contains_char('\u{0004}') {
          issues.push(
            issue(
              IssueError,
              Some(entry_index),
              "invalid-context",
              "context contains a reserved MO separator",
            ),
          )
        }
      None => ()
    }
    match entry.msgid_plural {
      Some(plural) => {
        has_plural_entry = true
        if plural == "" {
          issues.push(
            issue(
              IssueError,
              Some(entry_index),
              "empty-plural-id",
              "msgid_plural cannot be empty",
            ),
          )
        }
        if contains_nul(plural) {
          issues.push(
            issue(
              IssueError,
              Some(entry_index),
              "nul-plural-id",
              "msgid_plural contains NUL",
            ),
          )
        }
        match plural_rule {
          Some(rule) =>
            if entry.translations.length() != rule.nplurals {
              issues.push(
                issue(
                  IssueError,
                  Some(entry_index),
                  "plural-arity",
                  "entry has \{entry.translations.length()} translations but Plural-Forms declares \{rule.nplurals}",
                ),
              )
            }
          None => ()
        }
      }
      None =>
        if entry.translations.length() > 1 {
          issues.push(
            issue(
              IssueError,
              Some(entry_index),
              "singular-arity",
              "singular entry has more than one translation",
            ),
          )
        }
    }
    for translation in entry.translations {
      if contains_nul(translation) {
        issues.push(
          issue(
            IssueError,
            Some(entry_index),
            "nul-translation",
            "translation contains NUL, which conflicts with MO plural storage",
          ),
        )
        break
      }
    }
    if entry.is_fuzzy() {
      issues.push(
        issue(
          IssueWarning,
          Some(entry_index),
          "fuzzy",
          "fuzzy entry is omitted from compiled MO output",
        ),
      )
    }
    if entry.obsolete {
      issues.push(
        issue(
          IssueInfo,
          Some(entry_index),
          "obsolete",
          "obsolete entry is omitted from compiled MO output",
        ),
      )
    } else if all_translations_empty(entry) {
      issues.push(
        issue(
          IssueWarning,
          Some(entry_index),
          "untranslated",
          "entry has no non-empty translation",
        ),
      )
    }
  }

  if has_plural_entry && metadata.get("Plural-Forms") is None {
    issues.push(
      issue(
        IssueWarning,
        None,
        "missing-plural-forms",
        "catalog has plural entries but no Plural-Forms metadata; runtime falls back to English",
      ),
    )
  }
  match plural_rule {
    Some(rule) => validate_plural_rule_samples(rule, issues)
    None => ()
  }
  issues
}

///|
/// Return true when at least one validation issue is an error.
pub fn validation_has_errors(issues : ArrayView[ValidationIssue]) -> Bool {
  for finding in issues {
    if finding.severity == IssueError {
      return true
    }
  }
  false
}

///|
fn severity_label(severity : IssueSeverity) -> String {
  match severity {
    IssueInfo => "INFO"
    IssueWarning => "WARNING"
    IssueError => "ERROR"
  }
}

///|
/// Format findings as a line-oriented CLI report.
pub fn validation_report(issues : ArrayView[ValidationIssue]) -> String {
  if issues.is_empty() {
    return "OK: no validation issues\n"
  }
  let output = StringBuilder()
  for finding in issues {
    let location = match finding.entry {
      Some(index) => " entry=\{index}"
      None => ""
    }
    output.write_string(
      "[\{severity_label(finding.severity)}]\{location} \{finding.code}: \{finding.message}\n",
    )
  }
  output.to_string()
}

///|
/// Raise a single `Validation` error when a catalog has any error findings.
pub fn validate_po_strict(document : PoFile) -> Unit raise GettextError {
  let findings = validate_po(document)
  if validation_has_errors(findings) {
    raise Validation(message=validation_report(findings))
  }
}

///|
/// Validate a document strictly and then compile it to GNU MO bytes.
pub fn compile_mo_checked(
  document : PoFile,
  endian? : Endian = Little,
) -> Bytes raise GettextError {
  validate_po_strict(document)
  compile_mo(document, endian~)
}
