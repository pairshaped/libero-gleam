import gleam/io
import gleam/option
import libero
import libero/json/codegen as json_codegen
import simplifile

pub fn main() {
  let seeds = [
    #("bench_requests", "RequestMsg"),
    #("shared/bench", "AdminSummary"),
    #("shared/bench", "RecordPage"),
    #("shared/bench", "GameData"),
    #("shared/bench", "ShotPayload"),
    #("shared/bench", "TypeMatrix"),
    #("shared/bench", "BenchError"),
  ]
  let assert Ok(discovered) = libero.walk(seeds)
  let atoms_module = "generated@libero_atoms"
  let wire_module = "generated@libero_wire"
  let assert Ok(wire_src) = libero.generate_wire_erl(discovered:, wire_module:)
  let atoms_src =
    libero.generate_atoms(
      discovered:,
      atoms_module:,
      wire_module: option.Some(wire_module),
    )
  let decoders_js =
    libero.generate_decoders_ffi(
      discovered:,
      package: "libero_transport_bench",
      dependency_packages: [],
    )
  let decoders_gleam = libero.generate_decoders_gleam()
  let assert Ok(json_codecs) = json_codegen.generate(discovered)
  let contract =
    libero.generate_json_contract(discovered:, push_types: [], ssr_models: [])

  let assert Ok(Nil) = simplifile.create_directory_all("src/generated/libero")
  let assert Ok(Nil) =
    simplifile.write("src/" <> atoms_module <> ".erl", atoms_src)
  let assert Ok(Nil) =
    simplifile.write("src/" <> wire_module <> ".erl", wire_src)
  let assert Ok(Nil) =
    simplifile.write("src/generated/libero/decoders_ffi.mjs", decoders_js)
  let assert Ok(Nil) =
    simplifile.write("src/generated/libero/decoders.gleam", decoders_gleam)
  let assert Ok(Nil) =
    simplifile.write("src/generated/libero/json_codecs.gleam", json_codecs)
  let assert Ok(Nil) =
    simplifile.write("src/generated/libero/contract.json", contract)
  io.println("wrote benchmark Libero artifacts")
}
