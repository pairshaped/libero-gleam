//// Libero: RPC plumbing library for Gleam.
////
//// Provides handler scanning, JSON dispatch codegen, JSON wire contract
//// generation, and secondary ETF wire helpers.
////
//// Run `gleam run -m libero` to generate the RPC pipeline into
//// `src/generated/libero/`. Or call the library functions directly
//// for programmatic use (e.g. from a framework).

import gleam/io
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import libero/codegen
import libero/codegen_decoders
import libero/codegen_dispatch
import libero/etf/codegen_erl
import libero/format
import libero/gen_error.{type GenError}
import libero/json/codegen as json_codegen
import libero/json/contract
import libero/json/error.{type JsonError}
import libero/protocol
import libero/scanner.{type HandlerEndpoint}
import libero/walker.{type DiscoveredType}
import simplifile
import tom

/// Re-export so consumers can construct push dispatch entries without
/// reaching into `libero/etf/codegen_erl` directly.
pub type PushDispatch =
  codegen_erl.PushDispatch

/// The wire protocol: ETF (Erlang Term Format) or JSON.
pub type Protocol =
  protocol.Protocol

/// Re-export so consumers can build qualified atom names for push
/// dispatch entries using the same logic as the codegen.
pub fn qualified_atom_name(
  module_path module_path: String,
  variant_name variant_name: String,
) -> String {
  walker.qualified_atom_name(module_path:, variant_name:)
}

const out_dir = "src/generated/libero"

const default_atoms_module = "generated@rpc_atoms"

const default_wire_module = "generated@rpc_wire"

const default_client_msg_module = "generated/libero/messages"

const default_json_codecs_module = "generated/libero/json_codecs"

const default_context_module = "server_context"

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
  case env_flag(get_env("LIBERO_GEN_ETF")) {
    True -> generate_etf_default(endpoints, discovered)
    False -> generate_json_default(endpoints, discovered)
  }
}

fn generate_json_default(
  endpoints: List(HandlerEndpoint),
  discovered: List(DiscoveredType),
) -> Nil {
  let contract_types =
    include_generated_client_msg(
      discovered:,
      endpoints:,
      client_msg_module: default_client_msg_module,
    )
  let contract_hash =
    contract.generate_hash(
      endpoints:,
      discovered: contract_types,
      push_types: [],
      ssr_models: [],
    )
  let dispatch_src =
    generate_json_dispatch(
      endpoints:,
      client_msg_module: default_client_msg_module,
      json_codecs_module: default_json_codecs_module,
      contract_hash:,
    )
  let client_msg_src = generate_client_msg_module(endpoints)
  let json_codecs_src = case
    generate_json_codecs_source(
      discovered:,
      endpoints:,
      client_msg_module: default_client_msg_module,
    )
  {
    Ok(src) -> src
    Error(errors) -> {
      print_json_codec_errors(errors)
      halt(1)
    }
  }
  let json_contract =
    contract.generate(
      endpoints:,
      discovered: contract_types,
      push_types: [],
      ssr_models: [],
    )

  case
    write_generated_files(
      dispatch_src:,
      client_msg_src:,
      json_codecs_src:,
      json_contract:,
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
      case
        write_client_files(
          client_out: client_out,
          client_msg_src:,
          json_codecs_src:,
          json_contract:,
        )
      {
        Ok(Nil) -> Nil
        Error(err) -> {
          print_write_error(err)
          halt(1)
        }
      }
    option.None -> Nil
  }

  io.println(
    "wrote "
    <> out_dir
    <> "/dispatch.gleam, "
    <> out_dir
    <> "/messages.gleam, "
    <> out_dir
    <> "/json_codecs.gleam, "
    <> out_dir
    <> "/rpc_contract.json",
  )
}

fn generate_etf_default(
  endpoints: List(HandlerEndpoint),
  discovered: List(DiscoveredType),
) -> Nil {
  let atoms_module = default_atoms_module
  let wire_module = default_wire_module
  let dispatch_src =
    generate_dispatch(
      endpoints:,
      atoms_module: option.Some(atoms_module),
      wire_module: option.Some(wire_module),
    )
  let atoms_erl =
    generate_atoms(
      endpoints:,
      discovered:,
      atoms_module:,
      wire_module: option.Some(wire_module),
    )
  let wire_erl = case
    generate_wire_erl(
      discovered:,
      wire_module:,
      endpoints:,
      push_dispatches: [],
    )
  {
    Ok(src) -> src
    Error(err) -> {
      gen_error.print_error(err)
      halt(1)
    }
  }
  let package = case read_package_name() {
    Ok(name) -> name
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
  }
  let decoders_js = generate_decoders_ffi(discovered:, endpoints:, package:)
  let decoders_gleam = generate_decoders_gleam()
  let json_contract =
    contract.generate(endpoints:, discovered:, push_types: [], ssr_models: [])

  let atoms_path = "src/" <> atoms_module <> ".erl"
  let wire_path = "src/" <> wire_module <> ".erl"
  case
    write_etf_generated_files(
      dispatch_src:,
      decoders_js:,
      decoders_gleam:,
      atoms_path:,
      atoms_erl:,
      wire_path:,
      wire_erl:,
      json_contract:,
    )
  {
    Ok(Nil) -> Nil
    Error(err) -> {
      print_write_error(err)
      halt(1)
    }
  }

  case client_output_dir_from_env(get_env("LIBERO_CLIENT_OUT_DIR")) {
    option.Some(client_out) ->
      case
        write_etf_client_files(
          client_out: client_out,
          js: decoders_js,
          gleam: decoders_gleam,
        )
      {
        Ok(Nil) -> Nil
        Error(err) -> {
          print_write_error(err)
          halt(1)
        }
      }
    option.None -> Nil
  }

  io.println(
    "wrote "
    <> out_dir
    <> "/dispatch.gleam, rpc_decoders_ffi.mjs, rpc_decoders.gleam, "
    <> atoms_path
    <> ", "
    <> wire_path
    <> ", "
    <> out_dir
    <> "/rpc_contract.json",
  )
}

pub fn generate_client_msg_module(
  endpoints endpoints: List(HandlerEndpoint),
) -> String {
  let resolve_alias = codegen.build_alias_resolver(endpoints:)
  let imports =
    codegen.collect_endpoint_type_imports(
      endpoints:,
      include_return: False,
      resolve_alias:,
    )
    |> string.join("\n")
    |> fn(src) {
      case src {
        "" -> ""
        _ -> src <> "\n"
      }
    }
  let dict_import =
    codegen.import_if(
      endpoints:,
      predicate: codegen.is_dict,
      import_line: "import gleam/dict.{type Dict}",
    )
  let option_import =
    codegen.import_if(
      endpoints:,
      predicate: codegen.is_option,
      import_line: "import gleam/option.{type Option}",
    )
  let variants = case endpoints {
    [] -> ["  NoClientMsg"]
    _ -> codegen.emit_client_msg_variants(endpoints:, resolve_alias:)
  }

  "//// Code generated by libero. DO NOT EDIT.\n\n"
  <> dict_import
  <> option_import
  <> case dict_import <> option_import {
    "" -> ""
    _ -> "\n"
  }
  <> imports
  <> "\n"
  <> "pub type ClientMsg {\n"
  <> string.join(variants, "\n")
  <> "\n}"
}

fn include_generated_client_msg(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
  client_msg_module client_msg_module: String,
) -> List(DiscoveredType) {
  case endpoints {
    [] -> discovered
    _ ->
      list.append(discovered, [
        json_codegen.client_msg_discovered_type(
          endpoints:,
          module_path: client_msg_module,
          type_name: "ClientMsg",
        ),
      ])
  }
}

fn generate_json_codecs_source(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
  client_msg_module client_msg_module: String,
) -> Result(String, List(JsonError)) {
  json_codegen.generate_transport_codecs(
    discovered:,
    endpoints:,
    client_msg_module_path: client_msg_module,
    client_msg_type_name: "ClientMsg",
  )
}

fn print_json_codec_errors(errors: List(JsonError)) -> Nil {
  list.each(errors, fn(e) {
    io.println_error(gen_error.error_box(
      title: "JSON codec generation failed",
      path: e.path,
      body_lines: [e.message],
      hint: option.None,
    ))
  })
}

/// Scan `src/` for handler endpoints.
/// Context type is always `ServerContext`. Skips `src/generated/`.
pub fn scan() -> Result(List(HandlerEndpoint), List(GenError)) {
  scanner.scan("./src", "ServerContext")
}

/// Like `scan`, but excludes handler params whose resolved type matches any
/// #(module_path, type_name) in exclude_param_types. This lets frameworks
/// strip server-injected params (e.g. auth identity) before message-type
/// resolution, so the scanner sees only the client-facing payload.
pub fn scan_excluding(
  exclude_param_types exclude_param_types: List(#(String, String)),
) -> Result(List(HandlerEndpoint), List(GenError)) {
  scanner.scan_excluding(
    src_dir: "./src",
    context_type_name: "ServerContext",
    exclude_param_types:,
  )
}

/// Extract type seeds from endpoints for the walker.
pub fn collect_seeds(
  endpoints: List(HandlerEndpoint),
) -> List(#(String, String)) {
  scanner.collect_seeds(endpoints)
}

/// Walk the type graph from seeds. File paths are derived from this package's
/// `src/` directory. Frameworks that generate clients from a different package
/// layout should call the lower-level walker APIs with their own file list.
pub fn walk(
  seeds: List(#(String, String)),
) -> Result(List(DiscoveredType), List(GenError)) {
  use files <- result.try(
    scanner.walk_directory("./src")
    |> result.map_error(fn(e) { [e] }),
  )
  walker.walk(seeds, files)
}

/// Re-export so consumers can build extra dispatch parameters.
pub type ExtraParam =
  codegen_dispatch.ExtraParam

/// Generate the server dispatch module source.
pub fn generate_dispatch(
  endpoints endpoints: List(HandlerEndpoint),
  atoms_module atoms_module: option.Option(String),
  wire_module wire_module: option.Option(String),
) -> String {
  codegen_dispatch.generate(
    endpoints,
    default_context_module,
    "ServerContext",
    "rpc",
    atoms_module,
    wire_module,
  )
}

/// Generate dispatch with extra pass-through parameters on handle()
/// and every handler call.
pub fn generate_dispatch_with_extra_params(
  endpoints endpoints: List(HandlerEndpoint),
  atoms_module atoms_module: option.Option(String),
  wire_module wire_module: option.Option(String),
  extra_params extra_params: List(ExtraParam),
) -> String {
  codegen_dispatch.generate_with_extra_params(
    endpoints,
    default_context_module,
    "ServerContext",
    "rpc",
    atoms_module,
    wire_module,
    extra_params,
  )
}

/// Generate the JSON server dispatch module source.
///
/// JSON dispatch expects `ClientMsg` to live in `client_msg_module` so the
/// generated dispatch can import both that type module and `json_codecs_module`
/// without creating a circular import.
pub fn generate_json_dispatch(
  endpoints endpoints: List(HandlerEndpoint),
  client_msg_module client_msg_module: String,
  json_codecs_module json_codecs_module: String,
  contract_hash contract_hash: String,
) -> String {
  codegen_dispatch.generate_json(
    endpoints:,
    context_module: default_context_module,
    context_type_name: "ServerContext",
    wire_module_tag: "rpc",
    client_msg_module:,
    json_codecs_module:,
    contract_hash:,
  )
}

pub fn generate_json_dispatch_with_extra_params(
  endpoints endpoints: List(HandlerEndpoint),
  client_msg_module client_msg_module: String,
  json_codecs_module json_codecs_module: String,
  contract_hash contract_hash: String,
  extra_params extra_params: List(ExtraParam),
) -> String {
  codegen_dispatch.generate_json_with_extra_params(
    endpoints:,
    context_module: default_context_module,
    context_type_name: "ServerContext",
    wire_module_tag: "rpc",
    client_msg_module:,
    json_codecs_module:,
    contract_hash:,
    extra_params:,
  )
}

/// Generate the Erlang atoms pre-registration file content.
/// Module name uses Gleam's @-separated convention (e.g. "generated@rpc_atoms").
pub fn generate_atoms(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  atoms_module atoms_module: String,
  wire_module wire_module: option.Option(String),
) -> String {
  codegen_dispatch.generate_atoms_erl(
    endpoints,
    discovered,
    atoms_module,
    wire_module,
  )
}

/// Generate the per-type wire-transformer Erlang module.
pub fn generate_wire_erl(
  discovered discovered: List(DiscoveredType),
  wire_module wire_module: String,
  endpoints endpoints: List(HandlerEndpoint),
  push_dispatches push_dispatches: List(PushDispatch),
) -> Result(String, GenError) {
  codegen_erl.generate(
    module_name: wire_module,
    discovered:,
    endpoints:,
    push_dispatches:,
  )
}

/// Generate the JS typed decoder FFI source.
/// `package` is the Gleam package name that owns the modules (determines
/// the top-level directory in the JS build output).
pub fn generate_decoders_ffi(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
  package package: String,
) -> String {
  codegen_decoders.generate_decoders_ffi(
    discovered:,
    endpoints:,
    relpath_prefix: "../../../",
    package:,
    dispatch_module: option.Some("generated/libero/dispatch"),
  )
}

/// Generate the Gleam wrapper for the typed decoder FFI.
pub fn generate_decoders_gleam() -> String {
  codegen_decoders.generate_decoders_gleam("rpc_decoders_ffi.mjs")
}

/// Generate a deterministic JSON contract artifact from discovered types
/// and handler endpoints. The artifact describes every type, variant, and
/// endpoint that crosses the wire so external tools and SDKs can generate
/// clients from it.
pub fn generate_json_contract(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  push_types push_types: List(contract.PushContract),
  ssr_models ssr_models: List(contract.SsrModelContract),
) -> String {
  contract.generate(endpoints:, discovered:, push_types:, ssr_models:)
}

pub fn generate_json_contract_hash(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  push_types push_types: List(contract.PushContract),
  ssr_models ssr_models: List(contract.SsrModelContract),
) -> String {
  contract.generate_hash(endpoints:, discovered:, push_types:, ssr_models:)
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
        trimmed -> option.Some(trimmed)
      }
    }
    _ -> option.None
  }
}

fn write_generated_files(
  dispatch_src dispatch_src: String,
  client_msg_src client_msg_src: String,
  json_codecs_src json_codecs_src: String,
  json_contract json_contract: String,
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
    out_dir <> "/messages.gleam",
    format.format_gleam(client_msg_src),
  ))
  use _ <- result.try(write_file(
    out_dir <> "/json_codecs.gleam",
    format.format_gleam(json_codecs_src),
  ))
  use _ <- result.try(write_file(out_dir <> "/rpc_contract.json", json_contract))
  Ok(Nil)
}

fn write_etf_generated_files(
  dispatch_src dispatch_src: String,
  decoders_js decoders_js: String,
  decoders_gleam decoders_gleam: String,
  atoms_path atoms_path: String,
  atoms_erl atoms_erl: String,
  wire_path wire_path: String,
  wire_erl wire_erl: String,
  json_contract json_contract: String,
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
  use _ <- result.try(write_file(wire_path, wire_erl))
  use _ <- result.try(write_file(out_dir <> "/rpc_contract.json", json_contract))
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

fn write_client_files(
  client_out out: String,
  client_msg_src client_msg_src: String,
  json_codecs_src json_codecs_src: String,
  json_contract json_contract: String,
) -> Result(Nil, WriteError) {
  use _ <- result.try(
    simplifile.create_directory_all(out)
    |> result.map_error(fn(cause) { CannotCreateDir(path: out, cause:) }),
  )
  use _ <- result.try(write_file(
    out <> "/messages.gleam",
    format.format_gleam(client_msg_src),
  ))
  use _ <- result.try(write_file(
    out <> "/json_codecs.gleam",
    format.format_gleam(json_codecs_src),
  ))
  write_file(out <> "/rpc_contract.json", json_contract)
}

fn write_etf_client_files(
  client_out out: String,
  js js: String,
  gleam gleam: String,
) -> Result(Nil, WriteError) {
  use _ <- result.try(
    simplifile.create_directory_all(out)
    |> result.map_error(fn(cause) { CannotCreateDir(path: out, cause:) }),
  )
  use _ <- result.try(write_file(out <> "/rpc_decoders_ffi.mjs", js))
  write_file(out <> "/rpc_decoders.gleam", format.format_gleam(gleam))
}

fn read_package_name() -> Result(String, String) {
  case simplifile.read("gleam.toml") {
    Error(_) ->
      Error(gen_error.error_box(
        title: "Could not read gleam.toml",
        path: "gleam.toml",
        body_lines: ["File is missing or unreadable."],
        hint: option.Some(
          "Run libero from the project root where gleam.toml lives.",
        ),
      ))
    Ok(content) ->
      case tom.parse(content) {
        Error(_) ->
          Error(gen_error.error_box(
            title: "Could not parse gleam.toml",
            path: "gleam.toml",
            body_lines: ["The file contains invalid TOML."],
            hint: option.None,
          ))
        Ok(parsed) ->
          case tom.get_string(parsed, ["name"]) {
            Error(_) ->
              Error(gen_error.error_box(
                title: "Missing \"name\" in gleam.toml",
                path: "gleam.toml",
                body_lines: ["Expected a top-level `name = \"...\"` field."],
                hint: option.None,
              ))
            Ok(name) -> Ok(name)
          }
      }
  }
}

fn env_flag(value: option.Option(String)) -> Bool {
  case value {
    option.Some("1") | option.Some("true") -> True
    _ -> False
  }
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
