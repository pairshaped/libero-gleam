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
import gleam/list
import gleam/result
import gleam/string

import libero/field_type.{type FieldType}
import libero/gen_error.{type GenError, TypeIdentityHashCollision}

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
