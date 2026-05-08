//// Wire-format type identity for libero codegen.
////
//// Each user type that crosses the wire is identified by a 10-char hex
//// hash derived from its source identity (module path + constructor
//// name + field types). The hash is computed at codegen time and baked
//// directly into generated encode/decode functions; the runtime carries
//// no global lookup tables for type identity.
////
//// Two same-named types in different modules produce different hashes
//// because the canonical signature includes the module path. There is
//// no scenario where two genuinely-distinct user types collide on the
//// wire short of a hash birthday collision, which the codegen-level
//// uniqueness check (separate module) catches as a build error.

import gleam/bit_array
import gleam/crypto
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

import libero/field_type.{
  type FieldType, BitArrayField, BoolField, DictOf, FloatField, IntField, ListOf,
  NilField, OptionOf, ResultOf, StringField, TupleOf, TypeVar, UserType,
}
import libero/gen_error.{
  type GenError, BareAtomArityCollision, DictKeyMustBePrimitive,
  TypeIdentityHashCollision, WireTypeContainsTypeVar,
}

/// The minimal projection of a constructor needed to compute its wire
/// identity: source module path, constructor name, and ordered field
/// types. Codegen converts from `walker.DiscoveredVariant` (which
/// carries additional fields like float-field indices) by dropping the
/// codegen-only fields, so this type stays free of incidental coupling
/// and tests don't need to fabricate codegen-internal data.
pub type Constructor {
  Constructor(module_path: String, name: String, fields: List(FieldType))
}

/// Render the canonical signature for a constructor: the deterministic
/// string of the form `<module_path>|<constructor_name>|<field_tokens>`
/// that feeds into `wire_hash`. Exposed so tests can pin the signature
/// shape independently of the hash function, and so the codegen can
/// surface the signature in collision error messages.
///
/// Field tokens come from `field_type.to_canonical_token`. Zero-field
/// constructors render with an empty trailing segment, e.g.
/// `shared/types|Pending|`.
pub fn canonical_signature(
  module_path module_path: String,
  constructor_name constructor_name: String,
  fields fields: List(FieldType),
) -> String {
  let field_tokens =
    fields
    |> list.map(field_type.to_canonical_token)
    |> string.join(",")
  module_path <> "|" <> constructor_name <> "|" <> field_tokens
}

/// Compute the 10-char lowercase hex wire hash for an arbitrary
/// canonical signature. SHA-256 truncated to 40 bits, rendered as 10
/// lowercase hex characters. Pure function: same signature always
/// produces the same hash.
///
/// 40 bits of identity is enough for our universe of types. Birthday
/// collisions become statistically likely around 1M distinct types in
/// one consumer; the codegen uniqueness check covers the residual case.
pub fn wire_hash(signature: String) -> String {
  signature
  |> bit_array.from_string
  |> crypto.hash(crypto.Sha256, _)
  |> bit_array.slice(at: 0, take: 5)
  |> result.unwrap(<<>>)
  |> bit_array.base16_encode
  |> string.lowercase
}

/// Compute the wire identity for a constructor. Returns the canonical
/// signature paired with its hash, so callers (codegen + uniqueness
/// check) that need both can avoid recomputing the signature twice.
pub fn wire_identity(
  module_path module_path: String,
  constructor_name constructor_name: String,
  fields fields: List(FieldType),
) -> #(String, String) {
  let sig =
    canonical_signature(
      module_path: module_path,
      constructor_name: constructor_name,
      fields: fields,
    )
  #(sig, wire_hash(sig))
}

/// Walk a list of constructors and detect identity hash collisions —
/// two distinct canonical signatures whose hashes collide. Returns
/// `Ok(Nil)` when every distinct signature has a distinct hash, or
/// `Error(TypeIdentityHashCollision)` on the first collision found.
///
/// Duplicate constructors (identical canonical signature) are not
/// collisions — the caller may pass the same constructor twice (for
/// example via cross-module type sharing) and that's expected.
///
/// This is the sole runtime safety mechanism against hash collisions;
/// the codegen calls this before emitting any wire-identity-dependent
/// code. With 40-bit truncated SHA-256 the chance of a real collision
/// in any realistic codebase is vanishingly small, but the cost of
/// catching it is one dict lookup per constructor.
pub fn check_uniqueness(
  constructors: List(Constructor),
) -> Result(Nil, GenError) {
  check_uniqueness_with(constructors, wire_hash)
}

/// Same as `check_uniqueness` but takes the hash function as a
/// parameter. Exists so tests can force a collision via a mock hash
/// (real SHA-256 collisions at 40 bits are computationally infeasible
/// to construct on demand). Production callers always pass `wire_hash`.
pub fn check_uniqueness_with(
  constructors: List(Constructor),
  hash_fn: fn(String) -> String,
) -> Result(Nil, GenError) {
  do_check_uniqueness(constructors, hash_fn, dict.new())
}

fn do_check_uniqueness(
  remaining: List(Constructor),
  hash_fn: fn(String) -> String,
  seen: Dict(String, String),
) -> Result(Nil, GenError) {
  case remaining {
    [] -> Ok(Nil)
    [c, ..rest] -> {
      let sig =
        canonical_signature(
          module_path: c.module_path,
          constructor_name: c.name,
          fields: c.fields,
        )
      let hash = hash_fn(sig)
      case dict.get(seen, hash) {
        Ok(prev_sig) if prev_sig != sig ->
          Error(TypeIdentityHashCollision(
            hash: hash,
            signature_a: prev_sig,
            signature_b: sig,
          ))
        _ -> do_check_uniqueness(rest, hash_fn, dict.insert(seen, hash, sig))
      }
    }
  }
}

/// Walk a list of constructors and verify each one's fields are wire-safe.
/// Returns `Ok(Nil)` when every field can be encoded over the wire, or
/// the first violation encountered as a `GenError`.
///
/// Currently rejects:
/// - `Dict(K, V)` where `K` is anything other than `Int`, `String`, or
///   `Bool` (other key types have ambiguous JS-side identity or wire
///   contracts that don't round-trip cleanly).
/// - `TypeVar(_)` — an unresolved generic parameter that survived to
///   runtime. Without a concrete type, codegen cannot emit transformer
///   logic for nested fields; matching JS's runtime stance, we reject
///   at codegen time so the failure is loud and early.
///
/// The codegen calls this before emission so unsafe types never reach
/// the transformer emitter (where they would become silent footguns).
pub fn check_wire_safety(
  constructors: List(Constructor),
) -> Result(Nil, GenError) {
  case constructors {
    [] -> Ok(Nil)
    [c, ..rest] -> {
      use _ <- result.try(check_constructor_safety(c))
      check_wire_safety(rest)
    }
  }
}

fn check_constructor_safety(c: Constructor) -> Result(Nil, GenError) {
  let label = c.module_path <> "." <> c.name
  c.fields
  |> list.index_map(fn(field, i) { #(field, i) })
  |> list.try_each(fn(pair) {
    let #(field, index) = pair
    check_field_safety(field, label <> " field[" <> int.to_string(index) <> "]")
  })
}

fn check_field_safety(
  ft: FieldType,
  field_path: String,
) -> Result(Nil, GenError) {
  case ft {
    IntField
    | FloatField
    | StringField
    | BoolField
    | BitArrayField
    | NilField -> Ok(Nil)
    TypeVar(name:) ->
      Error(WireTypeContainsTypeVar(field_path: field_path, var_name: name))
    ListOf(element:) -> check_field_safety(element, field_path <> ".element")
    OptionOf(inner:) -> check_field_safety(inner, field_path <> ".inner")
    ResultOf(ok:, err:) -> {
      use _ <- result.try(check_field_safety(ok, field_path <> ".ok"))
      check_field_safety(err, field_path <> ".err")
    }
    DictOf(key:, value:) -> {
      use _ <- result.try(check_dict_key(key, field_path))
      check_field_safety(value, field_path <> ".value")
    }
    TupleOf(elements:) ->
      elements
      |> list.index_map(fn(element, i) { #(element, i) })
      |> list.try_each(fn(pair) {
        let #(element, index) = pair
        check_field_safety(
          element,
          field_path <> ".element[" <> int.to_string(index) <> "]",
        )
      })
    UserType(args:, ..) ->
      args
      |> list.index_map(fn(arg, i) { #(arg, i) })
      |> list.try_each(fn(pair) {
        let #(arg, index) = pair
        check_field_safety(
          arg,
          field_path <> ".arg[" <> int.to_string(index) <> "]",
        )
      })
  }
}

fn check_dict_key(key: FieldType, field_path: String) -> Result(Nil, GenError) {
  case key {
    IntField | StringField | BoolField -> Ok(Nil)
    _ ->
      Error(DictKeyMustBePrimitive(
        field_path: field_path,
        key_type_repr: field_type.to_canonical_token(key),
      ))
  }
}

/// Walk a list of constructors and detect bare-atom/arity collisions —
/// two constructors from different modules that share the same
/// snake_case name and field count. `encode_term` dispatches on
/// `{bare_atom, arity}` and cannot distinguish them at runtime.
///
/// Returns `Ok(Nil)` when every `{snake_name, arity}` pair is
/// unambiguous, or `Error(BareAtomArityCollision)` on the first
/// conflict found.
///
/// Same-module constructors with the same name are impossible in Gleam
/// (the compiler enforces unique type names per module), but if the
/// same constructor is passed twice from the same module the check
/// passes — the key includes the module path only for conflict
/// detection, and equal module paths are not a conflict.
pub fn check_bare_arity_uniqueness(
  constructors: List(Constructor),
) -> Result(Nil, GenError) {
  do_check_bare_arity(constructors, dict.new())
}

fn do_check_bare_arity(
  remaining: List(Constructor),
  seen: Dict(#(String, Int), #(String, String)),
) -> Result(Nil, GenError) {
  case remaining {
    [] -> Ok(Nil)
    [c, ..rest] -> {
      let key = #(constructor_to_snake_case(c.name), list.length(c.fields))
      case dict.get(seen, key) {
        Ok(#(prev_module, prev_name)) if prev_module != c.module_path ->
          Error(BareAtomArityCollision(
            bare_atom: key.0,
            arity: key.1 + 1,
            first: prev_module <> "." <> prev_name,
            second: c.module_path <> "." <> c.name,
          ))
        _ ->
          do_check_bare_arity(
            rest,
            dict.insert(seen, key, #(c.module_path, c.name)),
          )
      }
    }
  }
}

fn constructor_to_snake_case(name: String) -> String {
  let graphemes = string.to_graphemes(name)
  let triples = build_triples_for_snake(graphemes, "")
  list.index_fold(triples, "", fn(acc, triple, i) {
    let #(prev, g, next) = triple
    case i == 0, is_upper(g) {
      True, _ -> acc <> string.lowercase(g)
      False, True -> {
        let prev_upper = is_upper(prev)
        let next_lower = next != "" && !is_upper(next)
        case prev_upper, next_lower {
          True, True -> acc <> "_" <> string.lowercase(g)
          True, False -> acc <> string.lowercase(g)
          _, _ -> acc <> "_" <> string.lowercase(g)
        }
      }
      False, False -> acc <> g
    }
  })
}

fn build_triples_for_snake(
  remaining: List(String),
  prev: String,
) -> List(#(String, String, String)) {
  case remaining {
    [] -> []
    [g] -> [#(prev, g, "")]
    [g, next, ..rest] -> [
      #(prev, g, next),
      ..build_triples_for_snake([next, ..rest], g)
    ]
  }
}

fn is_upper(g: String) -> Bool {
  g != "" && g == string.uppercase(g) && g != string.lowercase(g)
}
