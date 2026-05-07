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
import gleam/string
import libero/codegen_decoders
import libero/codegen_dispatch
import libero/format
import libero/gen_error.{type GenError}
import libero/scanner.{type HandlerEndpoint}
import libero/walker.{type DiscoveredType}
import simplifile

const out_dir = "src/generated/libero"

const default_atoms_module = "generated@rpc_atoms"

const default_context_module = "server/server_context"

type WriteError {
  CannotCreateDir(path: String, cause: simplifile.FileError)
  CannotWriteFile(path: String, cause: simplifile.FileError)
}

/// Run the full generation pipeline, writing files to `src/generated/libero/`.
pub fn main() -> Nil {
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
  let dispatch_src =
    generate_dispatch(endpoints:, atoms_module: option.Some(atoms_module))
  let atoms_erl = generate_atoms(endpoints:, discovered:, atoms_module:)
  let decoders_js = generate_decoders_ffi(discovered:, endpoints:)
  let decoders_gleam = generate_decoders_gleam()

  let atoms_path = "src/" <> atoms_module <> ".erl"
  case
    write_generated_files(
      dispatch_src:,
      decoders_js:,
      decoders_gleam:,
      atoms_path:,
      atoms_erl:,
    )
  {
    Ok(Nil) -> Nil
    Error(err) -> {
      print_write_error(err)
      halt(1)
    }
  }

  // Write client-side files only when the caller opts in.
  case client_output_dir_from_env(get_env("LIBERO_CLIENT_OUT_DIR")) {
    option.Some(client_out) ->
      write_client_files(
        client_out: client_out,
        js: decoders_js,
        gleam: decoders_gleam,
      )
    option.None -> Nil
  }

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

/// Walk the type graph from seeds. File paths are derived from `src/` and
/// `../shared/src/` (if present) to support Gleam monorepo layouts where custom
/// types live in a shared package.
pub fn walk(
  seeds: List(#(String, String)),
) -> Result(List(DiscoveredType), List(GenError)) {
  use server_files <- result.try(
    scanner.walk_directory("./src")
    |> result.map_error(fn(e) { [e] }),
  )
  let shared_files = case simplifile.is_directory("../shared/src") {
    Ok(True) ->
      scanner.walk_directory("../shared/src")
      |> result.unwrap(or: [])
    _ -> []
  }
  walker.walk(seeds, list.append(server_files, shared_files))
}

/// Generate the server dispatch module source.
pub fn generate_dispatch(
  endpoints endpoints: List(HandlerEndpoint),
  atoms_module atoms_module: option.Option(String),
) -> String {
  codegen_dispatch.generate(
    endpoints,
    default_context_module,
    "ServerContext",
    "rpc",
    atoms_module,
  )
}

/// Generate the Erlang atoms pre-registration file content.
/// Module name uses Gleam's @-separated convention (e.g. "generated@rpc_atoms").
pub fn generate_atoms(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  atoms_module atoms_module: String,
) -> String {
  codegen_dispatch.generate_atoms_erl(endpoints, discovered, atoms_module)
}

/// Generate the JS typed decoder FFI source.
pub fn generate_decoders_ffi(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
) -> String {
  codegen_decoders.generate_decoders_ffi(discovered, endpoints, "../../../")
}

/// Generate the Gleam wrapper for the typed decoder FFI.
pub fn generate_decoders_gleam() -> String {
  codegen_decoders.generate_decoders_gleam("rpc_decoders_ffi.mjs")
}

/// Resolve the optional client output directory from environment config.
/// Set `LIBERO_CLIENT_OUT_DIR` to opt in to client-side decoder writes.
pub fn client_output_dir_from_env(
  env_value: option.Option(String),
) -> option.Option(String) {
  case env_value {
    option.Some(path) -> {
      case string.trim(path) {
        "" -> option.None
        _ -> option.Some(path)
      }
    }
    _ -> option.None
  }
}

fn write_generated_files(
  dispatch_src dispatch_src: String,
  decoders_js decoders_js: String,
  decoders_gleam decoders_gleam: String,
  atoms_path atoms_path: String,
  atoms_erl atoms_erl: String,
) -> Result(Nil, WriteError) {
  use _ <- result.try(
    simplifile.create_directory_all(out_dir)
    |> result.map_error(fn(cause) { CannotCreateDir(path: out_dir, cause:) }),
  )
  use _ <- result.try(write_file(
    out_dir <> "/dispatch.gleam",
    format.format_gleam(dispatch_src),
  ))
  use _ <- result.try(write_file(
    out_dir <> "/rpc_decoders_ffi.mjs",
    decoders_js,
  ))
  use _ <- result.try(write_file(
    out_dir <> "/rpc_decoders.gleam",
    format.format_gleam(decoders_gleam),
  ))
  use _ <- result.try(write_file(atoms_path, atoms_erl))
  Ok(Nil)
}

fn write_file(path: String, content: String) -> Result(Nil, WriteError) {
  simplifile.write(path, content)
  |> result.map_error(fn(cause) { CannotWriteFile(path:, cause:) })
}

fn print_write_error(err: WriteError) -> Nil {
  let message = case err {
    CannotCreateDir(path, cause) ->
      gen_error.error_box(
        title: "Cannot create output directory",
        path:,
        body_lines: [simplifile.describe_error(cause)],
        hint: option.None,
      )
    CannotWriteFile(path, cause) ->
      gen_error.error_box(
        title: "Cannot write generated file",
        path:,
        body_lines: [simplifile.describe_error(cause)],
        hint: option.None,
      )
  }
  io.println_error(message)
}

// nolint: discarded_result -- client writes are best-effort
fn write_client_files(
  client_out out: String,
  js js: String,
  gleam gleam: String,
) -> Nil {
  let _ = simplifile.create_directory_all(out)
  let _ = simplifile.write(out <> "/rpc_decoders_ffi.mjs", js)
  let _ =
    simplifile.write(out <> "/rpc_decoders.gleam", format.format_gleam(gleam))
  Nil
}

// nolint: avoid_panic, discarded_result -- Erlang-only @external; JS fallback is unreachable
@external(erlang, "libero_ffi", "get_env")
fn get_env(name: String) -> option.Option(String) {
  let _ = name
  panic as "libero.get_env: Erlang-only, unreachable on JavaScript target"
}

// nolint: avoid_panic -- erlang:halt/1 FFI; JS body is unreachable
@external(erlang, "libero_ffi", "halt")
fn halt(_code: Int) -> a {
  panic as "halt: Erlang-only, unreachable on JavaScript target"
}
