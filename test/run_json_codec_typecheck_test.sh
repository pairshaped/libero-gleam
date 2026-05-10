#!/bin/bash
# Typecheck verification for generated JSON codecs.
#
# Creates a temp Gleam project with fixture types, generates JSON codecs
# via libero/json/codegen, and runs gleam check to verify the generated
# code is type-correct.
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

# Fixture types covering various field kinds
cat > src/fixture.gleam <<'GLEAM'
pub type IntFlag {
  IntFlag(value: Int)
}

pub type FloatVal {
  FloatVal(value: Float)
}

pub type Article {
  Article(title: String, body: String, tags: List(String), published: Bool)
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
