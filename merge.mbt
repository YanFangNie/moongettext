///|
/// Summary of a template/catalog merge.
pub(all) struct MergeStats {
  matched : Int
  added : Int
  obsoleted : Int
} derive(Debug, Eq)

///|
/// Result of merging a POT-style template with an existing translation.
pub(all) struct MergeResult {
  document : PoFile
  stats : MergeStats
} derive(Debug, Eq)

///|
fn add_unique_string(values : Array[String], value : String) -> Unit {
  if value != "" && !values.contains(value) {
    values.push(value)
  }
}

///|
fn add_unique_comment(comments : Array[PoComment], comment : PoComment) -> Unit {
  if !comments.contains(comment) {
    comments.push(comment)
  }
}

///|
fn collect_comment_flags(entry : PoEntry, flags : Array[String]) -> Unit {
  for comment in entry.comments {
    if comment.kind == Flag {
      for raw_flag in comment.text.split(",") {
        add_unique_string(flags, raw_flag.trim().to_owned())
      }
    }
  }
}

///|
fn merged_comments(
  template : PoEntry,
  existing : PoEntry,
  source_changed : Bool,
) -> Array[PoComment] {
  let comments : Array[PoComment] = []
  for comment in existing.comments {
    if comment.kind == Translator {
      add_unique_comment(comments, comment)
    }
  }
  for comment in template.comments {
    if comment.kind == Translator ||
      comment.kind == Extracted ||
      comment.kind == Reference {
      add_unique_comment(comments, comment)
    }
  }
  let flags : Array[String] = []
  collect_comment_flags(template, flags)
  collect_comment_flags(existing, flags)
  if source_changed {
    add_unique_string(flags, "fuzzy")
  }
  if !flags.is_empty() {
    comments.push(PoComment::new(Flag, flags.join(", ")))
  }
  for comment in existing.comments {
    if comment.kind == Previous {
      add_unique_comment(comments, comment)
    }
  }
  comments
}

///|
fn merge_translation_values(
  template : PoEntry,
  existing : PoEntry,
) -> Array[String] {
  match template.msgid_plural {
    Some(_) =>
      match existing.msgid_plural {
        Some(_) => existing.translations.copy()
        None => template.translations.copy()
      }
    None => [existing.translations.get(0).unwrap_or("")]
  }
}

///|
fn merged_active_entry(template : PoEntry, existing : PoEntry) -> PoEntry {
  let source_changed = template.msgid_plural != existing.msgid_plural
  {
    comments: merged_comments(template, existing, source_changed),
    context: template.context,
    msgid: template.msgid,
    msgid_plural: template.msgid_plural,
    translations: merge_translation_values(template, existing),
    obsolete: template.obsolete,
  }
}

///|
fn merged_header(template : PoEntry, existing : PoEntry?) -> PoEntry {
  match existing {
    Some(previous) =>
      {
        comments: merged_comments(template, previous, false),
        context: None,
        msgid: "",
        msgid_plural: None,
        translations: previous.translations.copy(),
        obsolete: false,
      }
    None => template
  }
}

///|
fn index_existing_entries(
  document : PoFile,
) -> Map[String, PoEntry] raise GettextError {
  let entries : Map[String, PoEntry] = {}
  for entry in document.entries {
    if entry.is_header() {
      continue
    }
    let key = catalog_key(entry.msgid, entry.context)
    if entries.contains(key) {
      raise Validation(
        message="duplicate catalog key during merge: \{entry.msgid}",
      )
    }
    entries[key] = entry
  }
  entries
}

///|
fn ensure_template_keys_unique(document : PoFile) -> Unit raise GettextError {
  let keys : Map[String, Unit] = {}
  let mut headers = 0
  for entry in document.entries {
    if entry.is_header() {
      headers += 1
      if headers > 1 {
        raise Validation(message="template contains multiple metadata headers")
      }
      continue
    }
    let key = catalog_key(entry.msgid, entry.context)
    if keys.contains(key) {
      raise Validation(
        message="duplicate template key during merge: \{entry.msgid}",
      )
    }
    keys[key] = ()
  }
}

///|
fn copy_as_obsolete(entry : PoEntry) -> PoEntry {
  {
    comments: entry.comments.copy(),
    context: entry.context,
    msgid: entry.msgid,
    msgid_plural: entry.msgid_plural,
    translations: entry.translations.copy(),
    obsolete: true,
  }
}

///|
/// Merge a POT-style template with an existing translated PO document.
///
/// Source comments and references come from the template; translator and
/// previous-value comments come from the existing catalog. Matching
/// translations are retained. A changed plural source is marked `fuzzy`.
/// Existing entries absent from the template are appended as obsolete unless
/// `keep_obsolete=false`.
pub fn merge_template(
  template : PoFile,
  existing : PoFile,
  keep_obsolete? : Bool = true,
) -> MergeResult raise GettextError {
  ensure_template_keys_unique(template)
  let existing_entries = index_existing_entries(existing)
  let existing_header = existing.header()
  let consumed : Map[String, Unit] = {}
  let output : Array[PoEntry] = []
  let mut matched = 0
  let mut added = 0
  let mut obsoleted = 0

  for template_entry in template.entries {
    if template_entry.is_header() {
      output.push(merged_header(template_entry, existing_header))
      continue
    }
    let key = catalog_key(template_entry.msgid, template_entry.context)
    match existing_entries.get(key) {
      Some(previous) => {
        output.push(merged_active_entry(template_entry, previous))
        consumed[key] = ()
        matched += 1
      }
      None => {
        output.push(template_entry)
        added += 1
      }
    }
  }

  if template.header() is None {
    match existing_header {
      Some(header) => output.push(header)
      None => ()
    }
  }

  if keep_obsolete {
    for entry in existing.entries {
      if entry.is_header() {
        continue
      }
      let key = catalog_key(entry.msgid, entry.context)
      if !consumed.contains(key) &&
        !template.entries.any(candidate => {
          !candidate.is_header() &&
          catalog_key(candidate.msgid, candidate.context) == key
        }) {
        output.push(copy_as_obsolete(entry))
        obsoleted += 1
      }
    }
  }

  { document: PoFile::new(output), stats: { matched, added, obsoleted } }
}
