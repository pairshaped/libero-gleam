#!/bin/bash
# Typecheck verification for generated JSON codecs.
#
# Creates a temp Gleam project with fixture types covering every FieldType
# branch (Int, Float, String, Bool, BitArray, List, Dict, Option, Result,
# Tuple, nested UserType), generates JSON codecs via libero/json/codegen,
# and runs gleam check to verify the generated code is type-correct.
#
# Usage:
#   bash test/run_json_codec_typecheck_test.sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

WORK_DIR=$(mktemp -d)
trap 'cd / && rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

cat > gleam.toml <<'TOML'
name = "json_codec_test"
version = "0.1.0"

[dependencies]
gleam_stdlib = ">= 0.60.0 and < 2.0.0"
gleam_json = ">= 3.1.0 and < 4.0.0"
simplifile = ">= 2.0.0 and < 3.0.0"
libero = { path = "LIBERO_PATH" }
TOML

sed -i '' "s|LIBERO_PATH|$ROOT_DIR|" gleam.toml

mkdir -p src

# Fixture types covering every FieldType branch
cat > src/fixture.gleam <<'GLEAM'
import gleam/dict.{type Dict}
import gleam/option.{type Option}

// Primitives + containers
pub type IntFlag { IntFlag(value: Int) }
pub type FloatVal { FloatVal(value: Float) }
pub type NilVal { NilVal(value: Nil) }
pub type Article {
  Article(title: String, body: String, tags: List(String), published: Bool)
}

// BitArray (prelude type, no import needed)
pub type Blob { Blob(data: BitArray) }

// Dict (String-keyed)
pub type Lookup { Lookup(entries: Dict(String, String)) }
pub type IndexedLookup { IndexedLookup(entries: Dict(Int, String)) }
pub type BoolLookup { BoolLookup(entries: Dict(Bool, String)) }

// Nested user type
pub type Wrapper { Wrapper(inner: Article) }
pub type NestedEverything {
  NestedEverything(
    wrapper: Wrapper,
    items: List(Article),
    maybe: Option(Article),
    indexed: Dict(Int, Wrapper),
    pair: #(Article, Option(Int)),
    result: Result(Wrapper, String),
    blob: Blob,
    unit: Nil,
  )
}

// Tuple
pub type Coords { Coords(point: #(Float, Float)) }

// Option + Result (Option needs import, Result is prelude)
pub type Optional { Optional(value: Option(Int)) }
pub type Fallible { Fallible(result: Result(Int, String)) }

// Unlabelled fields
pub type Pair { Pair(String, Int) }

// Zero-field variant (exercises empty-object case)
pub type Status {
  Draft
  Published
}
GLEAM

# Generation script that calls libero's codegen API
cat > src/generate.gleam <<'GLEAM'
import gleam/io
import libero/scanner
import libero/walker
import libero/json/codegen
import simplifile

pub fn main() {
  let assert Ok(cwd) = simplifile.current_directory()
  let src_path = cwd <> "/src"
  let assert Ok(files) = scanner.walk_directory(src_path)
  let seeds = [
    #("fixture", "IntFlag"),
    #("fixture", "FloatVal"),
    #("fixture", "NilVal"),
    #("fixture", "Article"),
    #("fixture", "Blob"),
    #("fixture", "Lookup"),
    #("fixture", "IndexedLookup"),
    #("fixture", "BoolLookup"),
    #("fixture", "Wrapper"),
    #("fixture", "NestedEverything"),
    #("fixture", "Coords"),
    #("fixture", "Optional"),
    #("fixture", "Fallible"),
    #("fixture", "Pair"),
    #("fixture", "Status"),
  ]
  let assert Ok(types) = walker.walk(seeds, files)
  let assert Ok(source) = codegen.generate(types)
  let assert Ok(Nil) = simplifile.write("src/gen_json.gleam", source)
  io.println("Generated JSON codecs")
}
GLEAM

gleam run -m generate

echo "=== Typechecking generated codecs ==="
gleam check
gleam check --target javascript

cat > src/codec_smoke.gleam <<'GLEAM'
import fixture
import gen_json
import gleam/dict
import gleam/dynamic/decode
import gleam/io
import gleam/json
import gleam/option.{None, Some}
import libero/json/error.{type JsonError, JsonError}

fn article() -> fixture.Article {
  fixture.Article("Hello", "Body", ["gleam", "json"], True)
}

fn roundtrip_int_flag(value: fixture.IntFlag) -> fixture.IntFlag {
  let encoded = gen_json.json_encode_fixture__int_flag(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__int_flag(raw)
  decoded
}

fn roundtrip_float_val(value: fixture.FloatVal) -> fixture.FloatVal {
  let encoded = gen_json.json_encode_fixture__float_val(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__float_val(raw)
  decoded
}

fn roundtrip_nil_val(value: fixture.NilVal) -> fixture.NilVal {
  let encoded = gen_json.json_encode_fixture__nil_val(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__nil_val(raw)
  decoded
}

fn roundtrip_article(value: fixture.Article) -> fixture.Article {
  let encoded = gen_json.json_encode_fixture__article(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__article(raw)
  decoded
}

fn assert_blob_roundtrip(bits: BitArray) {
  let encoded = gen_json.json_encode_fixture__blob(fixture.Blob(bits))
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(fixture.Blob(decoded)) = gen_json.json_decode_fixture__blob(raw)
  assert decoded == bits
}

fn roundtrip_lookup(value: fixture.Lookup) -> fixture.Lookup {
  let encoded = gen_json.json_encode_fixture__lookup(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__lookup(raw)
  decoded
}

fn roundtrip_indexed_lookup(
  value: fixture.IndexedLookup,
) -> fixture.IndexedLookup {
  let encoded = gen_json.json_encode_fixture__indexed_lookup(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__indexed_lookup(raw)
  decoded
}

fn roundtrip_bool_lookup(value: fixture.BoolLookup) -> fixture.BoolLookup {
  let encoded = gen_json.json_encode_fixture__bool_lookup(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__bool_lookup(raw)
  decoded
}

fn roundtrip_wrapper(value: fixture.Wrapper) -> fixture.Wrapper {
  let encoded = gen_json.json_encode_fixture__wrapper(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__wrapper(raw)
  decoded
}

fn roundtrip_nested_everything(
  value: fixture.NestedEverything,
) -> fixture.NestedEverything {
  let encoded = gen_json.json_encode_fixture__nested_everything(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) =
    gen_json.json_decode_fixture__nested_everything(raw)
  decoded
}

fn roundtrip_coords(value: fixture.Coords) -> fixture.Coords {
  let encoded = gen_json.json_encode_fixture__coords(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__coords(raw)
  decoded
}

fn roundtrip_optional(value: fixture.Optional) -> fixture.Optional {
  let encoded = gen_json.json_encode_fixture__optional(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__optional(raw)
  decoded
}

fn roundtrip_fallible(value: fixture.Fallible) -> fixture.Fallible {
  let encoded = gen_json.json_encode_fixture__fallible(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__fallible(raw)
  decoded
}

fn roundtrip_pair(value: fixture.Pair) -> fixture.Pair {
  let encoded = gen_json.json_encode_fixture__pair(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__pair(raw)
  decoded
}

fn roundtrip_status(value: fixture.Status) -> fixture.Status {
  let encoded = gen_json.json_encode_fixture__status(value)
  let assert Ok(raw) = json.parse(json.to_string(encoded), decode.dynamic)
  let assert Ok(decoded) = gen_json.json_decode_fixture__status(raw)
  decoded
}

fn assert_invalid_blob_fails() {
  let invalid =
    "{\"type\":\"fixture.Blob\",\"variant\":\"Blob\",\"fields\":{\"data\":{\"encoding\":\"base64url\",\"data\":\"!not-base64!\"}}}"
  let assert Ok(raw) = json.parse(invalid, decode.dynamic)
  let assert Error(errors) = gen_json.json_decode_fixture__blob(raw)
  assert_has_error_path(errors, "fields.data.data")
}

fn assert_has_error_path(errors: List(JsonError), expected_path: String) {
  case errors {
    [JsonError(path:, ..), ..] -> {
      case path == expected_path {
        True -> Nil
        False -> panic as "unexpected JsonError path"
      }
    }
    [] -> panic as "expected at least one JsonError"
  }
}

fn assert_primitive_roundtrips() {
  assert roundtrip_int_flag(fixture.IntFlag(42)) == fixture.IntFlag(42)
  assert roundtrip_float_val(fixture.FloatVal(3.5)) == fixture.FloatVal(3.5)
  assert roundtrip_nil_val(fixture.NilVal(Nil)) == fixture.NilVal(Nil)
  assert roundtrip_article(article()) == article()
}

fn assert_dict_roundtrips() {
  let string_entries =
    dict.new()
    |> dict.insert("one", "a")
    |> dict.insert("two", "b")
  let fixture.Lookup(string_result) = roundtrip_lookup(fixture.Lookup(string_entries))
  let assert Ok("a") = dict.get(string_result, "one")
  let assert Ok("b") = dict.get(string_result, "two")

  let int_entries =
    dict.new()
    |> dict.insert(1, "one")
    |> dict.insert(2, "two")
  let fixture.IndexedLookup(int_result) =
    roundtrip_indexed_lookup(fixture.IndexedLookup(int_entries))
  let assert Ok("one") = dict.get(int_result, 1)
  let assert Ok("two") = dict.get(int_result, 2)

  let bool_entries =
    dict.new()
    |> dict.insert(True, "yes")
    |> dict.insert(False, "no")
  let fixture.BoolLookup(bool_result) =
    roundtrip_bool_lookup(fixture.BoolLookup(bool_entries))
  let assert Ok("yes") = dict.get(bool_result, True)
  let assert Ok("no") = dict.get(bool_result, False)
  Nil
}

fn assert_container_roundtrips() {
  assert roundtrip_wrapper(fixture.Wrapper(article())) == fixture.Wrapper(article())
  assert roundtrip_coords(fixture.Coords(#(1.25, -2.5))) == fixture.Coords(#(1.25, -2.5))
  assert roundtrip_optional(fixture.Optional(Some(99))) == fixture.Optional(Some(99))
  assert roundtrip_optional(fixture.Optional(None)) == fixture.Optional(None)
  assert roundtrip_fallible(fixture.Fallible(Ok(7))) == fixture.Fallible(Ok(7))
  assert roundtrip_fallible(fixture.Fallible(Error("nope"))) == fixture.Fallible(Error("nope"))
  assert roundtrip_pair(fixture.Pair("count", 2)) == fixture.Pair("count", 2)
  assert roundtrip_status(fixture.Draft) == fixture.Draft
  assert roundtrip_status(fixture.Published) == fixture.Published
}

fn assert_nested_custom_roundtrip() {
  let indexed =
    dict.new()
    |> dict.insert(1, fixture.Wrapper(article()))
  let value =
    fixture.NestedEverything(
      wrapper: fixture.Wrapper(article()),
      items: [article()],
      maybe: Some(article()),
      indexed: indexed,
      pair: #(article(), Some(5)),
      result: Ok(fixture.Wrapper(article())),
      blob: fixture.Blob(<<0, 1, 255>>),
      unit: Nil,
    )
  let assert fixture.NestedEverything(
    wrapper: fixture.Wrapper(decoded_article),
    items: [decoded_item],
    maybe: Some(decoded_maybe),
    indexed: decoded_indexed,
    pair: #(decoded_pair_article, Some(5)),
    result: Ok(fixture.Wrapper(decoded_result_article)),
    blob: fixture.Blob(decoded_bits),
    unit: Nil,
  ) = roundtrip_nested_everything(value)

  assert decoded_article == article()
  assert decoded_item == article()
  assert decoded_maybe == article()
  assert decoded_pair_article == article()
  assert decoded_result_article == article()
  assert decoded_bits == <<0, 1, 255>>
  let assert Ok(fixture.Wrapper(indexed_article)) =
    dict.get(decoded_indexed, 1)
  assert indexed_article == article()
}

pub fn main() {
  assert_primitive_roundtrips()
  assert_blob_roundtrip(<<>>)
  assert_blob_roundtrip(<<0, 1, 2, 3>>)
  assert_blob_roundtrip(<<0, 255, 128>>)
  assert_invalid_blob_fails()
  assert_dict_roundtrips()
  assert_container_roundtrips()
  assert_nested_custom_roundtrip()
  io.println("PASS: Generated JSON codec smoke tests")
}
GLEAM

echo "=== Running generated codec smoke tests on Erlang ==="
gleam run -m codec_smoke

echo "=== Running generated codec smoke tests on JavaScript ==="
gleam run --target javascript -m codec_smoke

echo "PASS: Generated JSON codecs typecheck and run successfully on Erlang and JavaScript"
