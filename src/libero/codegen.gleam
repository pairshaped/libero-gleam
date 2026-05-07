//// Cross-cutting helpers used by codegen submodules.
////
//// Naming helpers and small predicates over `field_type.FieldType` graphs.

import gleam/bool
import gleam/dict
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

/// Emit the body lines of the generated `ClientMsg` type. Uses
/// `resolve_alias` to qualify user-defined types with the correct
/// import alias (needed when multiple modules share the same last
/// segment, e.g. two different `id_` modules).
pub fn emit_client_msg_variants(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  resolve_alias resolve_alias: fn(String) -> String,
) -> List(String) {
  list.map(endpoints, fn(e) {
    let variant_name = to_pascal_case("server_" <> e.fn_name)
    case e.params {
      [] -> "  " <> variant_name
      params -> {
        let fields =
          list.map(params, fn(p) {
            let #(label, ft) = p
            label
            <> ": "
            <> field_type.to_gleam_source_with_alias(ft, resolve_alias)
          })
        "  " <> variant_name <> "(" <> string.join(fields, ", ") <> ")"
      }
    }
  })
}

/// Collect `import <module>` lines for every module path referenced
/// (transitively) by the endpoints' parameter types and, optionally,
/// return types. Uses aliases from `resolve_alias` so that modules
/// with the same last segment get distinct names.
pub fn collect_endpoint_type_imports(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  include_return include_return: Bool,
  resolve_alias resolve_alias: fn(String) -> String,
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
  |> list.map(fn(mod) {
    let alias = resolve_alias(mod)
    case alias == field_type.last_segment(mod) {
      True -> "import " <> mod
      False -> "import " <> mod <> " as " <> alias
    }
  })
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

/// Build a resolver function that maps a module path to its import alias.
/// Uses the last segment when unique, or the full underscored path when
/// two or more modules share the same last segment.
pub fn build_alias_resolver(
  endpoints endpoints: List(scanner.HandlerEndpoint),
) -> fn(String) -> String {
  let all_modules =
    endpoints
    |> list.flat_map(fn(e) {
      let from_params =
        list.flat_map(e.params, fn(p) { field_type.collect_user_types(p.1) })
      let from_return =
        list.append(
          field_type.collect_user_types(e.return_ok),
          field_type.collect_user_types(e.return_err),
        )
      list.append(from_params, from_return)
    })
    |> list.map(fn(ref) { ref.0 })
    |> list.unique()
  // Count how many modules share each last segment
  let segment_counts =
    list.fold(all_modules, dict.new(), fn(acc, mod) {
      let seg = field_type.last_segment(mod)
      let count = case dict.get(acc, seg) {
        Ok(n) -> n + 1
        Error(Nil) -> 1
      }
      dict.insert(acc, seg, count)
    })
  fn(module_path: String) -> String {
    let seg = field_type.last_segment(module_path)
    case dict.get(segment_counts, seg) {
      Ok(n) if n > 1 -> module_to_underscored(module_path)
      _ -> seg
    }
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
