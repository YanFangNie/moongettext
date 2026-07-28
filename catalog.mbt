///|
/// An indexed runtime translation catalog.
///
/// Construct catalogs with `Catalog::from_po` or `Catalog::from_mo`; fields are
/// intentionally private so duplicate-key and plural-rule checks cannot be
/// bypassed.
pub struct Catalog {
  messages : Map[String, PoEntry]
  rule : PluralRule
}

///|
fn catalog_key(msgid : String, context : String?) -> String {
  match context {
    Some(value) => value + "\u{0004}" + msgid
    None => msgid
  }
}

///|
fn validated_default_rule(rule : PluralRule) -> Unit raise GettextError {
  if rule.nplurals <= 0 {
    raise Validation(message="catalog plural rule must declare nplurals > 0")
  }
  ignore(parse_plural_ast(rule.expression))
}

///|
/// Build a runtime catalog from a parsed PO document.
///
/// Obsolete entries and the metadata header are excluded. Fuzzy entries are
/// excluded by default and can be explicitly included for preview tooling.
/// When no `Plural-Forms` header exists, the English rule (or
/// `default_rule`) is used.
pub fn Catalog::from_po(
  document : PoFile,
  default_rule? : PluralRule = PluralRule::english(),
  include_fuzzy? : Bool = false,
) -> Catalog raise GettextError {
  validated_default_rule(default_rule)
  let metadata = document.metadata()
  let rule = match metadata.get("Plural-Forms") {
    Some(value) => parse_plural_forms(value)
    None => default_rule
  }
  let messages : Map[String, PoEntry] = {}
  for entry in document.entries {
    if entry.is_header() ||
      entry.obsolete ||
      (!include_fuzzy && entry.is_fuzzy()) {
      continue
    }
    let key = catalog_key(entry.msgid, entry.context)
    if messages.contains(key) {
      raise Validation(message="duplicate catalog key: \{entry.msgid}")
    }
    messages[key] = entry
  }
  { messages, rule }
}

///|
/// Build a runtime catalog directly from GNU MO bytes.
pub fn Catalog::from_mo(bytes : Bytes) -> Catalog raise GettextError {
  Catalog::from_po(parse_mo(bytes))
}

///|
/// Number of indexed message entries, excluding the metadata header.
pub fn Catalog::length(self : Catalog) -> Int {
  self.messages.length()
}

///|
/// Return the catalog's validated plural rule.
pub fn Catalog::plural_rule(self : Catalog) -> PluralRule {
  self.rule
}

///|
fn Catalog::find_singular(
  self : Catalog,
  msgid : String,
  context : String?,
) -> String? {
  match self.messages.get(catalog_key(msgid, context)) {
    Some(entry) => entry.translation(0)
    None => None
  }
}

///|
fn Catalog::find_plural(
  self : Catalog,
  msgid : String,
  context : String?,
  n : Int,
) -> String? raise GettextError {
  match self.messages.get(catalog_key(msgid, context)) {
    Some(entry) => entry.translation(self.rule.select(n))
    None => None
  }
}

///|
/// Look up a singular message, returning the source `msgid` when neither this
/// catalog nor the optional fallback has a non-empty translation.
pub fn Catalog::gettext(
  self : Catalog,
  msgid : String,
  fallback? : Catalog,
) -> String {
  match self.find_singular(msgid, None) {
    Some(value) => value
    None =>
      match fallback {
        Some(other) => other.find_singular(msgid, None).unwrap_or(msgid)
        None => msgid
      }
  }
}

///|
/// Look up a context-qualified singular message.
pub fn Catalog::pgettext(
  self : Catalog,
  context : String,
  msgid : String,
  fallback? : Catalog,
) -> String {
  match self.find_singular(msgid, Some(context)) {
    Some(value) => value
    None =>
      match fallback {
        Some(other) =>
          other.find_singular(msgid, Some(context)).unwrap_or(msgid)
        None => msgid
      }
  }
}

///|
/// Look up a plural message using this catalog's `Plural-Forms` rule.
///
/// If no translation is available, the fallback catalog is tried. Source text
/// finally falls back to `singular` for `n == 1` and `plural` otherwise.
pub fn Catalog::ngettext(
  self : Catalog,
  singular : String,
  plural : String,
  n : Int,
  fallback? : Catalog,
) -> String raise GettextError {
  match self.find_plural(singular, None, n) {
    Some(value) => value
    None =>
      match fallback {
        Some(other) =>
          other
          .find_plural(singular, None, n)
          .unwrap_or(if n == 1 { singular } else { plural })
        None => if n == 1 { singular } else { plural }
      }
  }
}

///|
/// Look up a context-qualified plural message.
pub fn Catalog::npgettext(
  self : Catalog,
  context : String,
  singular : String,
  plural : String,
  n : Int,
  fallback? : Catalog,
) -> String raise GettextError {
  match self.find_plural(singular, Some(context), n) {
    Some(value) => value
    None =>
      match fallback {
        Some(other) =>
          other
          .find_plural(singular, Some(context), n)
          .unwrap_or(if n == 1 { singular } else { plural })
        None => if n == 1 { singular } else { plural }
      }
  }
}
