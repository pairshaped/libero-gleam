import gleam/option
import gleam/string
import gleeunit/should
import libero

pub fn rally_style_codegen_uses_seeded_types_only_test() {
  let assert Ok(discovered) = libero.walk([#("libero/error", "TransportError")])

  let atoms =
    libero.generate_atoms(
      discovered:,
      atoms_module: "generated@libero_atoms",
      wire_module: option.Some("generated@libero_wire"),
    )
  let assert Ok(wire) =
    libero.generate_wire_erl(discovered:, wire_module: "generated@libero_wire")
  let decoders_js =
    libero.generate_decoders_ffi(
      discovered:,
      package: "app",
      dependency_packages: [],
    )
  let decoders_gleam = libero.generate_decoders_gleam()
  let contract =
    libero.generate_json_contract(discovered:, push_types: [], ssr_models: [])

  atoms
  |> string.contains("-module(generated@libero_atoms).")
  |> should.be_true()
  wire
  |> string.contains("-module(generated@libero_wire).")
  |> should.be_true()
  decoders_js
  |> string.contains("registerAtomDecoder")
  |> should.be_true()
  decoders_js
  |> string.contains("requests.mjs")
  |> should.be_false()
  decoders_gleam
  |> string.contains("ensure_decoders")
  |> should.be_true()
  contract
  |> string.contains("\"type_name\":\"TransportError\"")
  |> should.be_true()
  let old_standalone_field = "\"end" <> "points\""
  contract
  |> string.contains(old_standalone_field)
  |> should.be_false()
}
