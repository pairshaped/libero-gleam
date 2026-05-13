import glance
import gleam/list
import gleam/string

import gleeunit/should

import libero/field_type
import libero/glance_type_resolver.{PreserveUnsupported, RejectUnsupported}
import libero/wire_identity

fn parse_type(source: String, type_name: String) -> glance.Type {
  let assert Ok(ast) = glance.module(source)
  let assert Ok(def) =
    list.find(ast.custom_types, fn(def) { def.definition.name == type_name })
  let assert [variant] = def.definition.variants
  let assert [field] = variant.fields
  case field {
    glance.LabelledVariantField(item:, ..) -> item
    glance.UnlabelledVariantField(item:) -> item
  }
}

fn resolver(source: String) -> glance_type_resolver.TypeResolver {
  let assert Ok(ast) = glance.module(source)
  let assert Ok(r) = glance_type_resolver.resolver_from_imports(ast.imports)
  r
}

fn resolve(
  source: String,
  type_name: String,
  current_module: String,
  policy: glance_type_resolver.UnsupportedTypePolicy,
) {
  let t = parse_type(source, type_name)
  let r = resolver(source)
  glance_type_resolver.type_to_field_type(
    type_: t,
    resolver: r,
    current_module:,
    policy:,
  )
}

fn resolve_all_fields(
  source: String,
  type_name: String,
  current_module: String,
  policy: glance_type_resolver.UnsupportedTypePolicy,
) -> Result(List(field_type.FieldType), String) {
  let assert Ok(ast) = glance.module(source)
  let assert Ok(def) =
    list.find(ast.custom_types, fn(def) { def.definition.name == type_name })
  let assert [variant] = def.definition.variants
  let r = resolver(source)
  list.try_map(variant.fields, fn(field) {
    let t = case field {
      glance.LabelledVariantField(item:, ..) -> item
      glance.UnlabelledVariantField(item:) -> item
    }
    glance_type_resolver.type_to_field_type(
      type_: t,
      resolver: r,
      current_module:,
      policy:,
    )
  })
}

// -- Unqualified imported type --

pub fn unqualified_imported_type_test() {
  let source =
    "import shared/item.{type Item}
pub type W { W(item: Item) }"

  resolve(source, "W", "test/page", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("shared/item", "Item", []))
}

// -- Imported type alias --

pub fn imported_type_alias_test() {
  let source =
    "import shared/item.{type Item as SharedItem}
pub type W { W(item: SharedItem) }"

  resolve(source, "W", "test/page", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("shared/item", "Item", []))
}

// -- Qualified module alias --

pub fn qualified_module_alias_test() {
  let source =
    "import shared/item as item_types
pub type W { W(item: item_types.Item) }"

  resolve(source, "W", "test/page", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("shared/item", "Item", []))
}

// -- Local user type --

pub fn local_user_type_test() {
  let source = "pub type W { W(thing: LocalThing) }"

  resolve(source, "W", "test/page", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("test/page", "LocalThing", []))
}

// -- Builtins --

pub fn builtin_int_test() {
  let source = "pub type W { W(n: Int) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.IntField)
}

pub fn builtin_string_test() {
  let source = "pub type W { W(s: String) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.StringField)
}

pub fn builtin_bool_test() {
  let source = "pub type W { W(b: Bool) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.BoolField)
}

pub fn builtin_float_test() {
  let source = "pub type W { W(f: Float) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.FloatField)
}

pub fn builtin_bit_array_test() {
  let source = "pub type W { W(b: BitArray) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.BitArrayField)
}

pub fn builtin_nil_test() {
  let source = "pub type W { W(n: Nil) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.NilField)
}

pub fn builtin_list_test() {
  let source = "pub type W { W(items: List(String)) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.ListOf(element: field_type.StringField))
}

pub fn builtin_option_test() {
  let source = "pub type W { W(maybe: Option(Int)) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.OptionOf(inner: field_type.IntField))
}

pub fn builtin_result_test() {
  let source = "pub type W { W(r: Result(Int, String)) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.ResultOf(
    ok: field_type.IntField,
    err: field_type.StringField,
  ))
}

pub fn builtin_dict_test() {
  let source = "pub type W { W(d: Dict(String, Int)) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.DictOf(
    key: field_type.StringField,
    value: field_type.IntField,
  ))
}

pub fn builtin_tuple_test() {
  let source = "pub type W { W(t: #(Int, String)) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(
    field_type.TupleOf(elements: [
      field_type.IntField,
      field_type.StringField,
    ]),
  )
}

// -- Generic user type --

pub fn generic_user_type_test() {
  let source =
    "import shared/item.{type Item}
pub type W { W(box: Box(Item)) }"

  resolve(source, "W", "test/page", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(
    field_type.UserType("test/page", "Box", [
      field_type.UserType("shared/item", "Item", []),
    ]),
  )
}

// -- Unsupported types: RejectUnsupported --

pub fn reject_function_type_test() {
  let source = "pub type W { W(handler: fn() -> Nil) }"
  resolve(source, "W", "m", RejectUnsupported("m.Model.handler"))
  |> should.be_error
  |> should.equal("Unsupported function type in m.Model.handler")
}

pub fn reject_hole_type_test() {
  let source = "pub type W { W(value: _) }"
  resolve(source, "W", "m", RejectUnsupported("m.Model.value"))
  |> should.be_error
  |> should.equal("Unsupported hole type in m.Model.value")
}

// -- Unsupported types: PreserveUnsupported --

pub fn preserve_function_type_test() {
  let source = "pub type W { W(handler: fn() -> Nil) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.TypeVar("_fn"))
}

pub fn preserve_hole_type_test() {
  let source = "pub type W { W(value: _) }"
  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.TypeVar("_"))
}

// -- Stdlib shadowing --

pub fn stdlib_shadowed_result_test() {
  let source =
    "import shared/custom_result.{type Result}
pub type W { W(r: Result) }"

  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("shared/custom_result", "Result", []))
}

pub fn stdlib_shadowed_option_test() {
  let source =
    "import shared/custom_option.{type Option}
pub type W { W(o: Option) }"

  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("shared/custom_option", "Option", []))
}

pub fn stdlib_shadowed_list_test() {
  let source =
    "import shared/custom_list.{type List}
pub type W { W(l: List) }"

  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.UserType("shared/custom_list", "List", []))
}

pub fn stdlib_explicit_import_test() {
  let source =
    "import gleam/option.{type Option}
pub type W { W(o: Option(Int)) }"

  resolve(source, "W", "m", PreserveUnsupported)
  |> should.be_ok
  |> should.equal(field_type.OptionOf(inner: field_type.IntField))
}

// -- Ambiguous unqualified imports --

pub fn ambiguous_import_error_test() {
  let source =
    "import shared/a.{type Item}
import shared/b.{type Item}"

  let assert Ok(ast) = glance.module(source)
  glance_type_resolver.resolver_from_imports(ast.imports)
  |> should.be_error
  |> should.equal(
    "Ambiguous import: \"Item\" is bound to shared/b.Item and shared/a.Item",
  )
}

pub fn same_import_twice_is_ok_test() {
  let source =
    "import shared/item.{type Item}
import shared/item.{type Item}"

  let assert Ok(ast) = glance.module(source)
  glance_type_resolver.resolver_from_imports(ast.imports)
  |> should.be_ok
}

// -- Canonical identity --

pub fn canonical_identity_different_modules_test() {
  let a = field_type.UserType("a/types", "Thing", [])
  let b = field_type.UserType("b/types", "Thing", [])
  should.not_equal(
    field_type.to_canonical_token(a),
    field_type.to_canonical_token(b),
  )
}

// -- Message-type hash inputs --

pub fn wire_identity_changes_with_module_path_test() {
  let fields = [field_type.BoolField]
  let #(_, hash_a) =
    wire_identity.wire_identity("page/a", "ServerToggle", fields)
  let #(_, hash_b) =
    wire_identity.wire_identity("page/b", "ServerToggle", fields)
  should.not_equal(hash_a, hash_b)
}

pub fn wire_identity_changes_with_field_order_test() {
  let fields_ab = [field_type.IntField, field_type.StringField]
  let fields_ba = [field_type.StringField, field_type.IntField]
  let #(_, hash_ab) =
    wire_identity.wire_identity("page/x", "ServerMsg", fields_ab)
  let #(_, hash_ba) =
    wire_identity.wire_identity("page/x", "ServerMsg", fields_ba)
  should.not_equal(hash_ab, hash_ba)
}

pub fn resolved_type_feeds_wire_identity_test() {
  let source =
    "import shared/item.{type Item}
pub type ServerAddItem { ServerAddItem(item: Item, count: Int) }"

  let assert Ok(fields) =
    resolve_all_fields(
      source,
      "ServerAddItem",
      "page/inventory",
      PreserveUnsupported,
    )

  should.equal(fields, [
    field_type.UserType("shared/item", "Item", []),
    field_type.IntField,
  ])

  let #(sig, hash) =
    wire_identity.wire_identity("page/inventory", "ServerAddItem", fields)
  should.be_true(string.contains(sig, "page/inventory"))
  should.equal(string.length(hash), 10)
}
