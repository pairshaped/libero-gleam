#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
FIXTURE_SRC="$ROOT_DIR/test/fixtures/wire_e2e"
STAGE_ROOT="${TMPDIR:-/tmp}/libero-wire-e2e"
STAGED_FIXTURE="$STAGE_ROOT/wire_e2e"
BUILD_ROOT_FILE="$ROOT_DIR/test/js/.wire_e2e_build_root"
DECODE_MANIFEST="$ROOT_DIR/test/js/.wire_e2e_decode_manifest.json"

if [ "${1:-}" = "--clean" ]; then
  rm -rf "$STAGE_ROOT"
  rm -f "$BUILD_ROOT_FILE" "$DECODE_MANIFEST"
fi

rm -rf "$STAGED_FIXTURE"
mkdir -p "$STAGED_FIXTURE"

# Three-peer layout: $STAGED/server/, $STAGED/shared/, $STAGED/clients/web/.
mkdir -p "$STAGED_FIXTURE/server/src" "$STAGED_FIXTURE/shared/src" "$STAGED_FIXTURE/clients/web/src"
cp "$FIXTURE_SRC/gleam.toml" "$STAGED_FIXTURE/server/gleam.toml"
cp -R "$FIXTURE_SRC/shared/." "$STAGED_FIXTURE/shared/"
cp -R "$FIXTURE_SRC/shared_src/." "$STAGED_FIXTURE/shared/src/"
cp -R "$FIXTURE_SRC/clients/web/." "$STAGED_FIXTURE/clients/web/"
cp -R "$FIXTURE_SRC/client_src/." "$STAGED_FIXTURE/clients/web/src/"

find "$STAGED_FIXTURE" -name '*.gleam.template' -exec sh -c '
  for path do
    mv "$path" "${path%.template}"
  done
' sh {} +

perl -0pi -e "s#libero = \\{ path = \"[^\"]+\" \\}#libero = { path = \"$ROOT_DIR\" }#g" \
  "$STAGED_FIXTURE/server/gleam.toml"
perl -0pi -e "s#libero = \\{ path = \"[^\"]+\" \\}#libero = { path = \"$ROOT_DIR\" }#g" \
  "$STAGED_FIXTURE/clients/web/gleam.toml"

(
  cd "$STAGED_FIXTURE/server"
  cat > src/generate_libero.gleam <<'GLEAM'
import gleam/io
import gleam/list
import gleam/option
import gleam/string
import libero
import libero/gen_error
import libero/source
import libero/walker
import simplifile

fn write_pair(path: String, content: String) -> Nil {
  let assert Ok(Nil) = simplifile.write(path, content)
  let client_path =
    "../clients/web/src/generated/libero/"
    <> string_replace(path, "src/generated/libero/", "")
  let assert Ok(Nil) = simplifile.write(client_path, content)
  Nil
}

pub fn main() {
  let assert Ok(Nil) = simplifile.create_directory_all("src/generated/libero")
  let assert Ok(Nil) =
    simplifile.create_directory_all("../clients/web/src/generated/libero")
  let seeds = [
    #("shared/types", "Status"),
    #("shared/types", "Item"),
    #("shared/types", "Tree"),
    #("shared/types", "ItemError"),
    #("shared/types", "WithFloats"),
    #("shared/types", "NestedRecord"),
    #("shared/types", "ItemListData"),
    #("shared/types", "ItemSummaryData"),
    #("shared/types", "FormPrefill"),
    #("shared/types", "NestedEnvelope"),
    #("shared/types", "DictAndListEnvelope"),
    #("shared/types", "Tag"),
    #("shared/collision", "Tag"),
  ]
  let assert Ok(files) = source.walk_directory("../shared/src")
  let discovered = case walker.walk(seeds: seeds, file_paths: files) {
    Ok(types) -> types
    Error(errors) -> {
      list_each(errors, gen_error.print_error)
      panic as "Libero type discovery failed"
    }
  }
  let atoms_module = "generated@libero_atoms"
  let wire_module = "generated@libero_wire"
  let decoders_module = "generated/libero/decoders"
  let atoms =
    libero.generate_atoms(
      discovered:,
      atoms_module:,
      wire_module: option.Some(wire_module),
    )
  let wire = case libero.generate_wire_erl(discovered:, wire_module:) {
    Ok(source) -> source
    Error(err) -> {
      gen_error.print_error(err)
      panic as "Libero wire generation failed"
    }
  }
  let decoders_js =
    libero.generate_decoders_ffi(
      discovered:,
      package: "web",
      dependency_packages: ["shared"],
    )
  let decoders_gleam = libero.generate_decoders_gleam()
  let etf = libero.generate_etf_codec_module(atoms_module:, decoders_module:)
  let contract =
    libero.generate_json_contract(discovered:, push_types: [], ssr_models: [])

  write_pair("src/generated/libero/decoders_ffi.mjs", decoders_js)
  write_pair("src/generated/libero/decoders.gleam", decoders_gleam)
  write_pair("src/generated/libero/etf.gleam", etf)
  let assert Ok(Nil) =
    simplifile.write(
      "src/generated/libero/" <> atoms_module <> ".erl",
      atoms,
    )
  let assert Ok(Nil) =
    simplifile.write(
      "src/generated/libero/" <> wire_module <> ".erl",
      wire,
    )
  write_pair("src/generated/libero/contract.json", contract)
  io.println("generated Libero artifacts")
}

fn string_replace(content: String, pattern: String, replacement: String) -> String {
  string.replace(content, pattern, replacement)
}

fn list_each(items: List(a), f: fn(a) -> Nil) -> Nil {
  list.each(items, f)
}
GLEAM
  gleam run -m generate_libero
  gleam build --target erlang
)

(
  cd "$STAGED_FIXTURE/clients/web"
  gleam build --target javascript
)

printf '%s\n' "$STAGED_FIXTURE" > "$BUILD_ROOT_FILE"

ERL_EBINS=$(find "$STAGED_FIXTURE/server/build/dev/erlang" -path '*/ebin' -type d | tr '\n' ' ')

erl -noshell -pa $ERL_EBINS -eval "$(cat "$ROOT_DIR/test/js/wire_e2e_decode_manifest.escript")" > "$DECODE_MANIFEST"

# Verify atom pre-registration enables binary_to_term([safe]) with custom atoms
# before the dispatch handler loads them via ensure_atoms().
erl -noshell -pa $ERL_EBINS -eval "$(cat "$ROOT_DIR/test/js/wire_e2e_safe_atoms.escript")"
