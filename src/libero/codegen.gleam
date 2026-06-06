//// Cross-cutting naming helpers used by codegen submodules.

import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import libero/field_type

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
/// The package name is the Gleam package that owns the module (determines
/// the top-level directory in the JS build output).
pub fn module_to_mjs_path(
  module_path module_path: String,
  package package: String,
) -> String {
  package <> "/" <> module_path <> ".mjs"
}

/// Build a resolver function that maps a module path to its import alias.
/// Uses the last segment when unique, or the full underscored path when
/// two or more modules share the same last segment.
pub fn build_module_alias_map(modules: List(String)) -> Dict(String, String) {
  let modules = list.unique(modules)

  let segment_counts =
    list.fold(modules, dict.new(), fn(acc, module_path) {
      let segment = field_type.last_segment(module_path)
      let count = case dict.get(acc, segment) {
        Ok(n) -> n + 1
        Error(Nil) -> 1
      }
      dict.insert(acc, segment, count)
    })

  list.fold(modules, dict.new(), fn(acc, module_path) {
    let segment = field_type.last_segment(module_path)
    let alias = case dict.get(segment_counts, segment) {
      Ok(n) if n > 1 -> module_to_underscored(module_path)
      _ -> segment
    }
    dict.insert(acc, module_path, alias)
  })
}
