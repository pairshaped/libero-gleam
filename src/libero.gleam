//// Libero: RPC plumbing library for Gleam.
////
//// Provides handler scanning, dispatch codegen, ETF wire protocol,
//// and decoder generation.

import gleam/result
import libero/codegen_decoders
import libero/codegen_dispatch
import libero/gen_error.{type GenError}
import libero/scanner.{type HandlerEndpoint}
import libero/walker.{type DiscoveredType}

/// Scan `src/` for handler endpoints.
/// Context type is always `ServerContext`. Skips `src/generated/`.
pub fn scan() -> Result(List(HandlerEndpoint), List(GenError)) {
  scanner.scan("src", "ServerContext")
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
    scanner.walk_directory("src")
    |> result.map_error(fn(e) { [e] }),
  )
  walker.walk(seeds, file_paths)
}

/// Generate the server dispatch module source.
pub fn generate_dispatch(endpoints: List(HandlerEndpoint)) -> String {
  codegen_dispatch.generate(endpoints, "server_context", "ServerContext", "rpc")
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
