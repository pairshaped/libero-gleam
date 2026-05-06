//// Libero: RPC plumbing library for Gleam.
////
//// Provides handler scanning, dispatch codegen, ETF wire protocol,
//// and decoder generation.
////
//// Run `gleam run -m libero` to generate the RPC pipeline into
//// `src/generated/libero/`. Or call the library functions directly
//// for programmatic use (e.g. from a framework).

import gleam/io
import gleam/list
import gleam/option
import gleam/result
import libero/codegen_decoders
import libero/codegen_dispatch
import libero/format
import libero/gen_error.{type GenError}
import libero/scanner.{type HandlerEndpoint}
import libero/walker.{type DiscoveredType}
import simplifile

const out_dir = "src/generated/libero"

const default_atoms_module = "generated@rpc_atoms"

/// Run the full generation pipeline, writing files to `src/generated/libero/`.
pub fn main() {
  let endpoints = case scan() {
    Ok(eps) -> eps
    Error(errors) -> {
      list.each(errors, gen_error.print_error)
      halt(1)
    }
  }
  let seeds = collect_seeds(endpoints)
  let discovered = case walk(seeds) {
    Ok(types) -> types
    Error(errors) -> {
      list.each(errors, gen_error.print_error)
      halt(1)
    }
  }
  let atoms_module = default_atoms_module
  let dispatch_src = generate_dispatch(endpoints, option.Some(atoms_module))
  let atoms_erl = generate_atoms(endpoints, atoms_module)
  let decoders_js = generate_decoders_ffi(discovered, endpoints)
  let decoders_gleam = generate_decoders_gleam()

  let _ = simplifile.create_directory_all(out_dir)
  let _ =
    simplifile.write(
      out_dir <> "/dispatch.gleam",
      format.format_gleam(dispatch_src),
    )
  let _ = simplifile.write(out_dir <> "/rpc_decoders_ffi.mjs", decoders_js)
  let _ =
    simplifile.write(
      out_dir <> "/rpc_decoders.gleam",
      format.format_gleam(decoders_gleam),
    )
  let atoms_path = "src/" <> atoms_module <> ".erl"
  let _ = simplifile.write(atoms_path, atoms_erl)

  io.println(
    "wrote "
    <> out_dir
    <> "/dispatch.gleam, rpc_decoders_ffi.mjs, rpc_decoders.gleam, "
    <> atoms_path,
  )
}

/// Scan `src/` for handler endpoints.
/// Context type is always `ServerContext`. Skips `src/generated/`.
pub fn scan() -> Result(List(HandlerEndpoint), List(GenError)) {
  scanner.scan("./src", "ServerContext")
}

/// Extract type seeds from endpoints for the walker.
pub fn collect_seeds(
  endpoints: List(HandlerEndpoint),
) -> List(#(String, String)) {
  scanner.collect_seeds(endpoints)
}

/// Walk the type graph from seeds. File paths are derived from `src/`.
pub fn walk(
  seeds: List(#(String, String)),
) -> Result(List(DiscoveredType), List(GenError)) {
  use file_paths <- result.try(
    scanner.walk_directory("./src")
    |> result.map_error(fn(e) { [e] }),
  )
  walker.walk(seeds, file_paths)
}

/// Generate the server dispatch module source.
pub fn generate_dispatch(
  endpoints: List(HandlerEndpoint),
  atoms_module: option.Option(String),
) -> String {
  codegen_dispatch.generate(
    endpoints,
    "server_context",
    "ServerContext",
    "rpc",
    atoms_module,
  )
}

/// Generate the Erlang atoms pre-registration file content.
/// Module name uses Gleam's @-separated convention (e.g. "generated@rpc_atoms").
pub fn generate_atoms(
  endpoints: List(HandlerEndpoint),
  atoms_module: String,
) -> String {
  codegen_dispatch.generate_atoms_erl(endpoints, atoms_module)
}

/// Generate the JS typed decoder FFI source.
pub fn generate_decoders_ffi(
  discovered: List(DiscoveredType),
  endpoints: List(HandlerEndpoint),
) -> String {
  codegen_decoders.generate_decoders_ffi(discovered, endpoints, "../../")
}

/// Generate the Gleam wrapper for the typed decoder FFI.
pub fn generate_decoders_gleam() -> String {
  codegen_decoders.generate_decoders_gleam("rpc_decoders_ffi.mjs")
}

@external(erlang, "libero_ffi", "halt")
fn halt(code: Int) -> a {
  let _ = code
  panic as "halt: Erlang-only, unreachable on JavaScript target"
}
