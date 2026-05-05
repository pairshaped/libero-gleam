//// Cross-cutting helpers used by codegen submodules.
////
//// Naming helpers and small predicates over `field_type.FieldType` graphs.

import gleam/bool
import gleam/list
import gleam/string
import libero/field_type
import libero/scanner

// ---------- Naming ----------

/// Convert a Gleam module path like "shared/discount" to a flat
/// underscore-separated alias. e.g. "shared/discount" -> "shared_discount".
pub fn module_to_underscored(module_path: String) -> String {
  string.replace(module_path, "/", "_")
}

/// Convert a snake_case name to PascalCase.
pub fn to_pascal_case(name: String) -> String {
  name
  |> string.split("_")
  |> list.map(fn(word) {
    case string.pop_grapheme(word) {
      Ok(#(first, rest)) -> string.uppercase(first) <> rest
      Error(Nil) -> word
    }
  })
  |> string.join("")
}

/// Convert a Gleam module path to its compiled .mjs bundle path.
pub fn module_to_mjs_path(module_path: String) -> String {
  case string.split_once(module_path, "/") {
    Error(Nil) -> module_path <> "/" <> module_path <> ".mjs"
    Ok(#(package, _)) -> package <> "/" <> module_path <> ".mjs"
  }
}

// ---------- FieldType predicates over endpoints ----------

/// True if any endpoint's parameter or return type (transitively)
/// satisfies `predicate`.
pub fn endpoints_contain(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  predicate predicate: fn(field_type.FieldType) -> Bool,
) -> Bool {
  list.any(endpoints, fn(e) {
    field_type.contains(e.return_ok, predicate)
    || field_type.contains(e.return_err, predicate)
    || list.any(e.params, fn(p) { field_type.contains(p.1, predicate) })
  })
}

/// Emit a constructor / pattern shape like `Variant(label1:, label2:)` or
/// just `Variant` when there are no parameters.
pub fn variant_pattern(
  variant_name variant_name: String,
  params params: List(#(String, field_type.FieldType)),
) -> String {
  case params {
    [] -> variant_name
    _ -> {
      let labels = list.map(params, fn(p) { p.0 <> ":" })
      variant_name <> "(" <> string.join(labels, ", ") <> ")"
    }
  }
}

/// Emit the body lines of the generated `ClientMsg` type.
pub fn emit_client_msg_variants(
  endpoints endpoints: List(scanner.HandlerEndpoint),
) -> List(String) {
  list.map(endpoints, fn(e) {
    let variant_name = to_pascal_case(e.fn_name)
    case e.params {
      [] -> "  " <> variant_name
      params -> {
        let fields =
          list.map(params, fn(p) {
            let #(label, ft) = p
            label <> ": " <> field_type.to_gleam_source(ft)
          })
        "  " <> variant_name <> "(" <> string.join(fields, ", ") <> ")"
      }
    }
  })
}

/// Collect `import <module>` lines for every module path referenced
/// (transitively) by the endpoints' parameter types and, optionally,
/// return types.
pub fn collect_endpoint_type_imports(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  include_return include_return: Bool,
) -> List(String) {
  endpoints
  |> list.flat_map(fn(e) {
    let from_params =
      list.flat_map(e.params, fn(p) { field_type.collect_user_types(p.1) })
    case include_return {
      True ->
        from_params
        |> list.append(field_type.collect_user_types(e.return_ok))
        |> list.append(field_type.collect_user_types(e.return_err))
      False -> from_params
    }
  })
  |> list.map(fn(ref) { ref.0 })
  |> list.unique()
  |> list.sort(string.compare)
  |> list.map(fn(mod) { "import " <> mod })
}

pub fn is_dict(ft: field_type.FieldType) -> Bool {
  case ft {
    field_type.DictOf(_, _) -> True
    _ -> False
  }
}

pub fn is_option(ft: field_type.FieldType) -> Bool {
  case ft {
    field_type.OptionOf(_) -> True
    _ -> False
  }
}

/// Emit `import_line` (with a leading newline) iff any endpoint type
/// transitively satisfies `predicate`; otherwise the empty string.
pub fn import_if(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  predicate predicate: fn(field_type.FieldType) -> Bool,
  import_line import_line: String,
) -> String {
  use <- bool.guard(
    when: !endpoints_contain(endpoints:, predicate:),
    return: "",
  )
  "\n" <> import_line
}
