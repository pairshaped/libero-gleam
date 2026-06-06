//// Source-file helpers for seed-driven type discovery.
////
//// Frameworks such as Rally decide which types cross the boundary and pass
//// those seeds to Libero.

import glance
import gleam/bool
import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import libero/field_type
import libero/gen_error.{
  type GenError, CannotReadDir, CannotReadFile, ParseFailed,
}
import simplifile

/// Recursively walk a directory, returning every `.gleam` file found.
/// Skips any subdirectory named `generated`.
pub fn walk_directory(path path: String) -> Result(List(String), GenError) {
  use entries <- result.try(
    simplifile.read_directory(path)
    |> result.map_error(fn(cause) { CannotReadDir(path: path, cause: cause) }),
  )
  use files <- result.map(
    list.try_fold(over: entries, from: [], with: fn(acc, entry) {
      visit_entry(acc: acc, parent: path, entry: entry)
    }),
  )
  list.sort(files, by: string.compare)
}

fn visit_entry(
  acc acc: List(String),
  parent parent: String,
  entry entry: String,
) -> Result(List(String), GenError) {
  let child = parent <> "/" <> entry
  let is_symlink = simplifile.is_symlink(child) |> result.unwrap(False)
  let is_dir = result.unwrap(simplifile.is_directory(child), False)
  use <- bool.guard(when: is_symlink && is_dir, return: Ok(acc))
  case is_dir {
    True -> visit_subdirectory(acc: acc, entry: entry, child: child)
    False -> Ok(visit_file(acc: acc, entry: entry, child: child))
  }
}

fn visit_subdirectory(
  acc acc: List(String),
  entry entry: String,
  child child: String,
) -> Result(List(String), GenError) {
  use <- bool.guard(when: entry == "generated", return: Ok(acc))
  use nested <- result.try(walk_directory(path: child))
  Ok(list.append(nested, acc))
}

fn visit_file(
  acc acc: List(String),
  entry entry: String,
  child child: String,
) -> List(String) {
  use <- bool.guard(when: !string.ends_with(entry, ".gleam"), return: acc)
  [child, ..acc]
}

/// Derive the Gleam module path from a file path by finding the last
/// occurrence of `/src/` and taking everything after it, then stripping
/// the `.gleam` extension.
pub fn derive_module_path(file_path file_path: String) -> String {
  let without_extension = case string.ends_with(file_path, ".gleam") {
    True ->
      string.slice(
        from: file_path,
        at_index: 0,
        length: string.length(file_path) - string.length(".gleam"),
      )
    False -> file_path
  }
  case string.split(without_extension, "/src/") {
    [_only] -> without_extension
    parts -> list.last(parts) |> result.unwrap(or: without_extension)
  }
}

/// Read a `.gleam` file and parse it via `glance`, surfacing both I/O and
/// parser failures as `GenError` variants tagged with the file path.
pub fn parse_module(
  file_path file_path: String,
) -> Result(glance.Module, GenError) {
  use content <- result.try(
    simplifile.read(file_path)
    |> result.map_error(fn(cause) { CannotReadFile(path: file_path, cause:) }),
  )
  glance.module(content)
  |> result.map_error(fn(cause) { ParseFailed(path: file_path, cause:) })
}

/// Build a map from unqualified type names to the full module path of their
/// import.
pub fn build_type_import_map(
  imports: List(glance.Definition(glance.Import)),
) -> dict.Dict(String, String) {
  list.fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    list.fold(imp.unqualified_types, acc, fn(inner_acc, uq) {
      let key = case uq.alias {
        option.Some(alias) -> alias
        option.None -> uq.name
      }
      dict.insert(inner_acc, key, imp.module)
    })
  })
}

/// Map locally-bound type names back to their original names from the source
/// module. Only populated when an import uses `type X as Y`.
pub fn build_type_alias_originals(
  imports: List(glance.Definition(glance.Import)),
) -> dict.Dict(String, String) {
  list.fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    list.fold(imp.unqualified_types, acc, fn(inner_acc, uq) {
      case uq.alias {
        option.Some(alias) -> dict.insert(inner_acc, alias, uq.name)
        option.None -> inner_acc
      }
    })
  })
}

/// Build a map from import aliases and bare module names to the full module
/// path.
pub fn build_alias_resolution_map(
  imports: List(glance.Definition(glance.Import)),
) -> dict.Dict(String, String) {
  list.fold(imports, dict.new(), fn(acc, def) {
    let glance.Definition(_, imp) = def
    let last_seg = field_type.last_segment(imp.module)
    let alias = case imp.alias {
      option.Some(glance.Named(name)) -> name
      _ -> last_seg
    }
    dict.insert(acc, alias, imp.module)
  })
}
