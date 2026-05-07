//// Direct tests for `walker.walk`.

import glance
import gleam/int
import gleam/list
import libero/gen_error
import libero/scanner
import libero/walker.{type DiscoveredType}
import simplifile

const fixture_root = "build/.test_walker"

fn walk_all_public_types(
  dir: String,
) -> Result(List(DiscoveredType), List(gen_error.GenError)) {
  let assert Ok(files) = scanner.walk_directory(path: dir)
  let seeds =
    list.flat_map(files, fn(file_path) {
      let module_path = scanner.derive_module_path(file_path:)
      case scanner.parse_module(file_path:) {
        Ok(parsed) ->
          list.filter_map(parsed.custom_types, fn(ct) {
            let glance_def = ct.definition
            case glance_def.publicity {
              glance.Public -> Ok(#(module_path, glance_def.name))
              _ -> Error(Nil)
            }
          })
        Error(_) -> []
      }
    })
  walker.walk(seeds:, file_paths: files)
}

pub fn walks_mutually_recursive_types_test() {
  let dir = fixture_root <> "/mutual/shared/src/shared"
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  let assert Ok(Nil) =
    simplifile.write(
      dir <> "/types.gleam",
      "pub type A {
  ANode(child: B)
  ALeaf
}

pub type B {
  BNode(child: A)
  BLeaf
}
",
    )

  let assert Ok(types) = walk_all_public_types(dir)

  let assert True = has_type(types, "A")
  let assert True = has_type(types, "B")
  let assert 1 = count_type(types, "A")
  let assert 1 = count_type(types, "B")

  let assert Ok(Nil) = simplifile.delete_all([fixture_root <> "/mutual"])
}

pub fn detects_float_field_indices_test() {
  let dir = fixture_root <> "/floats/shared/src/shared"
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  let assert Ok(Nil) =
    simplifile.write(
      dir <> "/types.gleam",
      "pub type Mixed {
  Mixed(name: String, score: Float, count: Int, ratio: Float)
}
",
    )

  let assert Ok(types) = walk_all_public_types(dir)

  let assert Ok(mixed) = find_type(types, "Mixed")
  let assert [variant] = mixed.variants
  let assert [1, 3] = list.sort(variant.float_field_indices, by: int.compare)

  let assert Ok(Nil) = simplifile.delete_all([fixture_root <> "/floats"])
}

pub fn returns_empty_for_no_seeds_test() {
  let dir = fixture_root <> "/empty/shared/src/shared"
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  let assert Ok(Nil) =
    simplifile.write(
      dir <> "/types.gleam",
      "// Only a private type - walker should not surface it.
type Hidden {
  Hidden(value: Int)
}
",
    )

  let assert Ok(types) = walk_all_public_types(dir)
  let assert [] = types

  let assert Ok(Nil) = simplifile.delete_all([fixture_root <> "/empty"])
}

pub fn walks_user_type_shadowing_stdlib_result_test() {
  let dir = fixture_root <> "/shadow/shared/src/shared"
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  let assert Ok(Nil) =
    simplifile.write(
      dir <> "/custom_result.gleam",
      "pub type Result {
  Result(value: Int)
}
",
    )
  let assert Ok(Nil) =
    simplifile.write(
      dir <> "/wrapper.gleam",
      "import shared/custom_result.{type Result}

pub type Wrapper {
  Wrapper(result: Result)
}
",
    )

  let assert Ok(files) = scanner.walk_directory(path: dir)
  let assert Ok(types) =
    walker.walk(seeds: [#("shared/wrapper", "Wrapper")], file_paths: files)

  let assert True = has_type(types, "Wrapper")
  let assert True = has_type(types, "Result")

  let assert Ok(Nil) = simplifile.delete_all([fixture_root <> "/shadow"])
}

fn has_type(types: List(DiscoveredType), name: String) -> Bool {
  list.any(types, fn(t) { t.type_name == name })
}

fn count_type(types: List(DiscoveredType), name: String) -> Int {
  list.length(list.filter(types, fn(t) { t.type_name == name }))
}

fn find_type(
  types: List(DiscoveredType),
  name: String,
) -> Result(DiscoveredType, Nil) {
  list.find(types, fn(t) { t.type_name == name })
}
