import gleam/io
import gleam/option
import libero
import libero/codegen_decoders
import simplifile

pub fn main() {
  let assert Ok(endpoints) = libero.scan()
  let seeds = libero.collect_seeds(endpoints)
  let assert Ok(discovered) = libero.walk(seeds)
  let atoms_module = "generated@rpc_atoms"
  let wire_module = "generated@rpc_wire"
  let assert Ok(wire_src) =
    libero.generate_wire_erl(
      discovered:,
      wire_module:,
      endpoints:,
      push_dispatches: [],
    )
  let atoms_src =
    libero.generate_atoms(
      endpoints:,
      discovered:,
      atoms_module:,
      wire_module: option.Some(wire_module),
    )
  let decoders_js =
    codegen_decoders.generate_decoders_ffi(
      discovered:,
      endpoints:,
      relpath_prefix: "../../../",
      package: "libero_transport_bench",
      dispatch_module: option.None,
    )
  let decoders_gleam = libero.generate_decoders_gleam()

  let assert Ok(Nil) =
    simplifile.write("src/" <> atoms_module <> ".erl", atoms_src)
  let assert Ok(Nil) =
    simplifile.write("src/" <> wire_module <> ".erl", wire_src)
  let assert Ok(Nil) =
    simplifile.write("src/generated/libero/rpc_decoders_ffi.mjs", decoders_js)
  let assert Ok(Nil) =
    simplifile.write("src/generated/libero/rpc_decoders.gleam", decoders_gleam)
  io.println("wrote ETF benchmark wire modules")
}
