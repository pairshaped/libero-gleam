//// Tests for the wire-identity primitives: canonical_signature,
//// wire_hash, wire_identity.
////
//// These are pure functions of (module_path, constructor_name, fields).
//// Tests pin format, determinism, and sensitivity. Uniqueness-collision
//// behaviour lives in the codegen check (separate module + test).

import gleam/string
import libero/field_type.{
  IntField, ListOf, OptionOf, StringField, UserType,
}
import libero/gen_error
import libero/wire_identity.{Constructor}

// -- canonical_signature ---------------------------------------------------

pub fn canonical_signature_zero_fields_test() {
  let assert "shared/types|Pending|" =
    wire_identity.canonical_signature(
      module_path: "shared/types",
      constructor_name: "Pending",
      fields: [],
    )
}

pub fn canonical_signature_one_primitive_test() {
  let assert "m|Leaf|int" =
    wire_identity.canonical_signature(
      module_path: "m",
      constructor_name: "Leaf",
      fields: [IntField],
    )
}

pub fn canonical_signature_multiple_primitives_test() {
  let assert "admin/discounts|Discount|int,string,option<string>" =
    wire_identity.canonical_signature(
      module_path: "admin/discounts",
      constructor_name: "Discount",
      fields: [IntField, StringField, OptionOf(StringField)],
    )
}

pub fn canonical_signature_list_of_user_type_test() {
  let assert "admin/discounts|DiscountAdminData|list<<type:admin/discounts|Discount>>" =
    wire_identity.canonical_signature(
      module_path: "admin/discounts",
      constructor_name: "DiscountAdminData",
      fields: [
        ListOf(UserType(
          module_path: "admin/discounts",
          type_name: "Discount",
          args: [],
        )),
      ],
    )
}

/// Same constructor name + same field shape, different module: must
/// produce different canonical signatures. This is the headline property
/// — the case that motivated the entire spec.
pub fn canonical_signature_same_shape_different_module_test() {
  let a =
    wire_identity.canonical_signature(
      module_path: "admin/pages/discounts",
      constructor_name: "Discount",
      fields: [IntField],
    )
  let b =
    wire_identity.canonical_signature(
      module_path: "admin/pages/promos",
      constructor_name: "Discount",
      fields: [IntField],
    )
  let assert True = a != b
}

// -- wire_hash -------------------------------------------------------------

pub fn wire_hash_known_empty_input_test() {
  // SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  // First 5 bytes (10 hex chars), lowercase: e3b0c44298
  let assert "e3b0c44298" = wire_identity.wire_hash("")
}

pub fn wire_hash_known_abc_input_test() {
  // SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  // First 5 bytes (10 hex chars), lowercase: ba7816bf8f
  let assert "ba7816bf8f" = wire_identity.wire_hash("abc")
}

pub fn wire_hash_is_ten_chars_test() {
  let h = wire_identity.wire_hash("any input")
  let assert 10 = string.length(h)
}

pub fn wire_hash_deterministic_test() {
  let sig = "admin/discounts|Discount|int,string,bool"
  let assert True = wire_identity.wire_hash(sig) == wire_identity.wire_hash(sig)
}

pub fn wire_hash_distinct_inputs_distinct_outputs_test() {
  let assert True =
    wire_identity.wire_hash("admin/discounts|Discount|int,string,bool")
    != wire_identity.wire_hash("admin/discounts|Discount|int,string,float")
}

// -- wire_identity ---------------------------------------------------------

pub fn wire_identity_returns_signature_and_hash_test() {
  let #(sig, hash) =
    wire_identity.wire_identity(
      module_path: "m",
      constructor_name: "Leaf",
      fields: [IntField],
    )
  let assert "m|Leaf|int" = sig
  let assert True = string.length(hash) == 10
  let assert True = hash == wire_identity.wire_hash(sig)
}

// -- check_uniqueness ------------------------------------------------------

pub fn check_uniqueness_empty_list_test() {
  let assert Ok(Nil) = wire_identity.check_uniqueness([])
}

pub fn check_uniqueness_distinct_constructors_test() {
  let constructors = [
    Constructor(
      module_path: "admin/discounts",
      name: "Discount",
      fields: [IntField, StringField],
    ),
    Constructor(
      module_path: "admin/promos",
      name: "Promo",
      fields: [IntField, StringField],
    ),
    Constructor(module_path: "shared/types", name: "Pending", fields: []),
  ]
  let assert Ok(Nil) = wire_identity.check_uniqueness(constructors)
}

/// Same constructor passed twice (identical canonical signature) is
/// not a collision — same identity, just listed twice.
pub fn check_uniqueness_duplicate_constructor_test() {
  let c =
    Constructor(
      module_path: "admin/discounts",
      name: "Discount",
      fields: [IntField],
    )
  let assert Ok(Nil) = wire_identity.check_uniqueness([c, c])
}

/// Same name and shape in different modules: distinct canonical
/// signatures, distinct hashes, no collision. Headline property.
pub fn check_uniqueness_same_name_different_module_test() {
  let constructors = [
    Constructor(
      module_path: "admin/pages/discounts",
      name: "Discount",
      fields: [IntField],
    ),
    Constructor(
      module_path: "admin/pages/promos",
      name: "Discount",
      fields: [IntField],
    ),
  ]
  let assert Ok(Nil) = wire_identity.check_uniqueness(constructors)
}

/// Mock hash that returns the same value for every input. Forces a
/// collision between any two distinct signatures.
fn const_hash(_signature: String) -> String {
  "deadbeef00"
}

pub fn check_uniqueness_with_mock_detects_collision_test() {
  let constructors = [
    Constructor(module_path: "m", name: "A", fields: [IntField]),
    Constructor(module_path: "m", name: "B", fields: [StringField]),
  ]
  let assert Error(gen_error.TypeIdentityHashCollision(
    hash: hash,
    signature_a: a,
    signature_b: b,
  )) = wire_identity.check_uniqueness_with(constructors, const_hash)
  let assert "deadbeef00" = hash
  let assert "m|A|int" = a
  let assert "m|B|string" = b
}

/// Mock collision check should NOT fire for duplicate signatures —
/// even when the mock would force a hash match, identical canonical
/// signatures count as the same type.
pub fn check_uniqueness_with_mock_ignores_duplicate_signatures_test() {
  let c = Constructor(module_path: "m", name: "A", fields: [IntField])
  let assert Ok(Nil) =
    wire_identity.check_uniqueness_with([c, c, c], const_hash)
}
