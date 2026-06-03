#!/bin/bash
# JSON codec acceptance tests for strict typed-value decoding.
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

WORK_DIR=$(mktemp -d)
trap 'cd / && rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

cat > gleam.toml <<'TOML'
name = "json_codec_acceptance_test"
version = "0.1.0"

[dependencies]
gleam_stdlib = ">= 0.60.0 and < 2.0.0"
gleam_json = ">= 3.1.0 and < 4.0.0"
simplifile = ">= 2.0.0 and < 3.0.0"
libero = { path = "LIBERO_PATH" }
TOML

sed -i '' "s|LIBERO_PATH|$ROOT_DIR|" gleam.toml

mkdir -p src

cat > src/fixture.gleam <<'GLEAM'
pub type Article {
  Article(title: String, body: String)
}

pub type Wrapper {
  Wrapper(inner: Article)
}

pub type Status {
  Ready
}
GLEAM

cat > src/generate.gleam <<'GLEAM'
import gleam/io
import libero/json/codegen
import libero/scanner
import libero/walker
import simplifile

pub fn main() {
  let assert Ok(cwd) = simplifile.current_directory()
  let assert Ok(files) = scanner.walk_directory(cwd <> "/src")
  let seeds = [
    #("fixture", "Article"),
    #("fixture", "Wrapper"),
    #("fixture", "Status"),
  ]
  let assert Ok(types) = walker.walk(seeds, files)
  let assert Ok(source) = codegen.generate(types)
  let assert Ok(Nil) = simplifile.write("src/gen_json.gleam", source)
  io.println("Generated JSON codecs")
}
GLEAM

gleam run -m generate

cat > src/codec_acceptance.gleam <<'GLEAM'
import gen_json
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/io
import gleam/json

fn parse_json(source: String) -> Dynamic {
  let assert Ok(raw) = json.parse(source, decode.dynamic)
  raw
}

fn labelled_fields_reject_unknown_field() {
  let raw =
    parse_json(
      "{
        \"type\": \"fixture.Article\",
        \"variant\": \"Article\",
        \"fields\": {
          \"title\": \"Hello\",
          \"body\": \"Body\",
          \"extra\": \"must fail\"
        }
      }",
    )

  case gen_json.json_decode_fixture__article(raw) {
    Error(_) -> Nil
    Ok(_) -> panic as "Article decoder accepted an unknown labelled field"
  }
}

fn zero_field_variants_reject_non_empty_fields() {
  let raw =
    parse_json(
      "{
        \"type\": \"fixture.Status\",
        \"variant\": \"Ready\",
        \"fields\": {
          \"extra\": true
        }
      }",
    )

  case gen_json.json_decode_fixture__status(raw) {
    Error(_) -> Nil
    Ok(_) -> panic as "Zero-field variant decoder accepted non-empty fields"
  }
}

fn nested_custom_fields_reject_unknown_field() {
  let raw =
    parse_json(
      "{
        \"type\": \"fixture.Wrapper\",
        \"variant\": \"Wrapper\",
        \"fields\": {
          \"inner\": {
            \"type\": \"fixture.Article\",
            \"variant\": \"Article\",
            \"fields\": {
              \"title\": \"Hello\",
              \"body\": \"Body\",
              \"extra\": \"must fail\"
            }
          }
        }
      }",
    )

  case gen_json.json_decode_fixture__wrapper(raw) {
    Error(_) -> Nil
    Ok(_) -> panic as "Nested custom decoder accepted an unknown labelled field"
  }
}

pub fn main() {
  labelled_fields_reject_unknown_field()
  zero_field_variants_reject_non_empty_fields()
  nested_custom_fields_reject_unknown_field()
  io.println("PASS: JSON codec acceptance tests")
}
GLEAM

echo "=== Running JSON codec acceptance tests ==="
gleam run -m codec_acceptance
gleam run --target javascript -m codec_acceptance
