import gleam/option.{None, Some}
import gleeunit/should
import libero/field_type
import libero/scanner
import libero/walker
import simplifile

pub fn variant_field_labels_test() {
  // Build a minimal DiscoveredVariant by hand to test the field is present
  let v =
    walker.DiscoveredVariant(
      module_path: "shared/article",
      variant_name: "Article",
      atom_name: "shared_article__article",
      float_field_indices: [],
      field_labels: [Some("title"), Some("body")],
      fields: [field_type.StringField, field_type.StringField],
    )

  v.field_labels |> should.equal([Some("title"), Some("body")])

  let u =
    walker.DiscoveredVariant(
      module_path: "shared/pair",
      variant_name: "Pair",
      atom_name: "shared_pair__pair",
      float_field_indices: [],
      field_labels: [None, None],
      fields: [field_type.StringField, field_type.IntField],
    )

  u.field_labels |> should.equal([None, None])
}

pub fn walker_preserves_labels_from_source_test() {
  let root = "build/.test_json_field_labels/shared/src/shared"
  let assert Ok(Nil) = simplifile.create_directory_all(root)
  let assert Ok(Nil) =
    simplifile.write(
      root <> "/query.gleam",
      "
pub type Query {
  Query(String, limit: Int, offset: Int)
}
",
    )

  let assert Ok(files) = scanner.walk_directory(path: root)
  let assert Ok(types) =
    walker.walk(seeds: [#("shared/query", "Query")], file_paths: files)

  let assert [query] = types
  let assert [variant] = query.variants

  variant.field_labels |> should.equal([None, Some("limit"), Some("offset")])
  variant.fields
  |> should.equal([
    field_type.StringField,
    field_type.IntField,
    field_type.IntField,
  ])

  let assert Ok(Nil) = simplifile.delete_all(["build/.test_json_field_labels"])
}
