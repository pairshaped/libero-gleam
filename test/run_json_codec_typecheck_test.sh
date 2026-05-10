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
pub type Article {
  Article(title: String, body: String, tags: List(String), published: Bool)
}

// BitArray (prelude type, no import needed)
pub type Blob { Blob(data: BitArray) }

// Dict (String-keyed)
pub type Lookup { Lookup(entries: Dict(String, String)) }
pub type IndexedLookup { IndexedLookup(entries: Dict(Int, String)) }

// Nested user type
pub type Wrapper { Wrapper(inner: Article) }

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
    #("fixture", "Article"),
    #("fixture", "Blob"),
    #("fixture", "Lookup"),
    #("fixture", "IndexedLookup"),
    #("fixture", "Wrapper"),
    #("fixture", "Coords"),
    #("fixture", "Optional"),
    #("fixture", "Fallible"),
    #("fixture", "Pair"),
    #("fixture", "Status"),
  ]
  let assert Ok(types) = walker.walk(seeds, files)
  let assert Ok(source) = codegen.generate(types, [], [])
  let assert Ok(Nil) = simplifile.write("src/gen_json.gleam", source)
  io.println("Generated JSON codecs")
}
GLEAM

gleam run -m generate

echo "=== Typechecking generated codecs ==="
gleam check

echo "PASS: Generated JSON codecs typecheck successfully"
