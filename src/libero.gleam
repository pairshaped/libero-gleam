//// Libero: typed wire-contract generation for Gleam.
////
//// Provides handler scanning, dispatch codegen, JSON/ETF wire contract
//// generation, and protocol facades.
////
//// Run `gleam run -m libero` to generate the wire-contract pipeline into
//// `src/generated/libero/`. Or call the library functions directly
//// for programmatic use (e.g. from a framework).

import gleam/dict
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

const default_atoms_module = "generated@libero_atoms"

const default_wire_module = "generated@libero_wire"

const default_generated_module = "generated/libero"

const default_context_module = "server_context"

pub type LiberoConfig {
  LiberoConfig(
    use_json: Bool,
    erlang_output_dir: String,
    mirrored_output_dir: option.Option(String),
    type_seeds: List(#(String, String)),
  )
}

type WriteError {
  CannotCreateDir(path: String, cause: simplifile.FileError)
  CannotWriteFile(path: String, cause: simplifile.FileError)
}

/// Run the full generation pipeline, writing files to `src/generated/libero/`.
pub fn main() -> Nil {
  let config = case read_libero_config() {
    Ok(config) -> config
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
  }
  let endpoints = case scan() {
    Ok(eps) -> eps
    Error(errors) -> {
      list.each(errors, gen_error.print_error)
      halt(1)
    }
  }
  let seeds =
    list.append(collect_seeds(endpoints), config.type_seeds)
    |> list.unique
  let discovered = case walk(seeds) {
    Ok(types) -> types
    Error(errors) -> {
      list.each(errors, gen_error.print_error)
      halt(1)
    }
  }
  let mirrored_out =
    resolve_mirrored_output_dir(config, get_env("LIBERO_MIRRORED_OUTPUT_DIR"))
  case resolve_use_json(config, get_env("LIBERO_USE_JSON")) {
    False ->
      generate_etf_default(
        endpoints,
        discovered,
        erlang_output_dir: config.erlang_output_dir,
        mirrored_out:,
      )
    True ->
      generate_json_default(
        endpoints,
        discovered,
        erlang_output_dir: config.erlang_output_dir,
        mirrored_out:,
      )
  }
}

fn generate_json_default(
  endpoints: List(HandlerEndpoint),
  discovered: List(DiscoveredType),
  erlang_output_dir erlang_output_dir: String,
  mirrored_out mirrored_out: option.Option(String),
) -> Nil {
  let generated_module = module_path_from_output_dir(erlang_output_dir)
  let request_msg_module = child_module(generated_module, "requests")
  let json_codecs_module = child_module(generated_module, "json_codecs")
  let contract_types =
    include_generated_request_msg(discovered:, endpoints:, request_msg_module:)
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
      request_msg_module:,
      json_codecs_module:,
      contract_hash:,
    )
  let request_msg_src = generate_request_msg_module(endpoints)
  let json_codecs_src = case
    generate_json_codecs_source(discovered:, endpoints:, request_msg_module:)
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
      out_dir: erlang_output_dir,
      dispatch_src:,
      request_msg_src:,
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

  case mirrored_out {
    option.Some(mirrored_out) ->
      case
        write_mirrored_json_files(
          out: mirrored_out,
          request_msg_src:,
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
    <> erlang_output_dir
    <> "/dispatch.gleam, "
    <> erlang_output_dir
    <> "/requests.gleam, "
    <> erlang_output_dir
    <> "/json_codecs.gleam, "
    <> erlang_output_dir
    <> "/contract.json",
  )
}

fn generate_etf_default(
  endpoints: List(HandlerEndpoint),
  discovered: List(DiscoveredType),
  erlang_output_dir erlang_output_dir: String,
  mirrored_out mirrored_out: option.Option(String),
) -> Nil {
  let request_msg_module =
    child_module(module_path_from_output_dir(erlang_output_dir), "requests")
  let decoders_module =
    child_module(module_path_from_output_dir(erlang_output_dir), "decoders")
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
  let dependency_packages = case read_dependency_names() {
    Ok(names) -> names
    Error(msg) -> {
      io.println_error(msg)
      halt(1)
    }
  }
  let decoders_js =
    generate_decoders_ffi_for_dispatch(
      discovered:,
      endpoints:,
      package:,
      dependency_packages:,
      dispatch_module: request_msg_module,
    )
  let decoders_gleam = generate_decoders_gleam()
  let etf_codec_gleam =
    generate_etf_codec_module(atoms_module:, decoders_module:)
  let request_msg_src = generate_request_msg_module(endpoints:)
  let json_contract =
    contract.generate(endpoints:, discovered:, push_types: [], ssr_models: [])

  let atoms_path = erlang_output_dir <> "/" <> atoms_module <> ".erl"
  let wire_path = erlang_output_dir <> "/" <> wire_module <> ".erl"
  case
    write_etf_generated_files(
      out_dir: erlang_output_dir,
      dispatch_src:,
      request_msg_src:,
      decoders_js:,
      decoders_gleam:,
      etf_codec_gleam:,
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

  case mirrored_out {
    option.Some(mirrored_out) ->
      case
        write_mirrored_etf_files(
          out: mirrored_out,
          request_msg_src:,
          js: decoders_js,
          gleam: decoders_gleam,
          etf_codec_gleam:,
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
    <> erlang_output_dir
    <> "/dispatch.gleam, "
    <> erlang_output_dir
    <> "/requests.gleam, decoders_ffi.mjs, decoders.gleam, "
    <> erlang_output_dir
    <> "/etf.gleam, "
    <> atoms_path
    <> ", "
    <> wire_path
    <> ", "
    <> erlang_output_dir
    <> "/contract.json",
  )
}

/// Generate the request message module source.
pub fn generate_request_msg_module(
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
    [] -> ["  NoRequestMsg"]
    _ -> codegen.emit_request_msg_variants(endpoints:, resolve_alias:)
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
  <> "pub type RequestMsg {\n"
  <> string.join(variants, "\n")
  <> "\n}"
}

fn include_generated_request_msg(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
  request_msg_module request_msg_module: String,
) -> List(DiscoveredType) {
  case endpoints {
    [] -> discovered
    _ ->
      list.append(discovered, [
        json_codegen.request_msg_discovered_type(
          endpoints:,
          module_path: request_msg_module,
          type_name: "RequestMsg",
        ),
      ])
  }
}

fn generate_json_codecs_source(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
  request_msg_module request_msg_module: String,
) -> Result(String, List(JsonError)) {
  json_codegen.generate_transport_codecs(
    discovered:,
    endpoints:,
    request_msg_module_path: request_msg_module,
    request_msg_type_name: "RequestMsg",
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
    "libero",
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
    "libero",
    atoms_module,
    wire_module,
    extra_params,
  )
}

/// Generate the JSON server dispatch module source.
///
/// JSON dispatch expects `RequestMsg` to live in `request_msg_module` so the
/// generated dispatch can import both that type module and `json_codecs_module`
/// without creating a circular import.
pub fn generate_json_dispatch(
  endpoints endpoints: List(HandlerEndpoint),
  request_msg_module request_msg_module: String,
  json_codecs_module json_codecs_module: String,
  contract_hash contract_hash: String,
) -> String {
  codegen_dispatch.generate_json(
    endpoints:,
    context_module: default_context_module,
    context_type_name: "ServerContext",
    wire_module_tag: "libero",
    request_msg_module:,
    json_codecs_module:,
    contract_hash:,
  )
}

pub fn generate_json_dispatch_with_extra_params(
  endpoints endpoints: List(HandlerEndpoint),
  request_msg_module request_msg_module: String,
  json_codecs_module json_codecs_module: String,
  contract_hash contract_hash: String,
  extra_params extra_params: List(ExtraParam),
) -> String {
  codegen_dispatch.generate_json_with_extra_params(
    endpoints:,
    context_module: default_context_module,
    context_type_name: "ServerContext",
    wire_module_tag: "libero",
    request_msg_module:,
    json_codecs_module:,
    contract_hash:,
    extra_params:,
  )
}

/// Generate the Erlang atoms pre-registration file content.
/// Module name uses Gleam's @-separated convention (e.g. "generated@libero_atoms").
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
  dependency_packages dependency_packages: List(String),
) -> String {
  generate_decoders_ffi_for_dispatch(
    discovered:,
    endpoints:,
    package:,
    dependency_packages:,
    dispatch_module: default_generated_module <> "/requests",
  )
}

fn generate_decoders_ffi_for_dispatch(
  discovered discovered: List(DiscoveredType),
  endpoints endpoints: List(HandlerEndpoint),
  package package: String,
  dependency_packages dependency_packages: List(String),
  dispatch_module dispatch_module: String,
) -> String {
  codegen_decoders.generate_decoders_ffi(
    discovered:,
    endpoints:,
    relpath_prefix: "../../../",
    package:,
    dependency_packages:,
    dispatch_module: request_msg_module_for_decoders(endpoints, dispatch_module),
  )
}

fn request_msg_module_for_decoders(
  endpoints: List(HandlerEndpoint),
  dispatch_module: String,
) -> option.Option(String) {
  case endpoints {
    [] -> option.None
    _ -> option.Some(dispatch_module)
  }
}

/// Generate the Gleam wrapper for the typed decoder FFI.
pub fn generate_decoders_gleam() -> String {
  codegen_decoders.generate_decoders_gleam("decoders_ffi.mjs")
}

/// Generate a neutral ETF codec wrapper for generated application code.
pub fn generate_etf_codec_module(
  atoms_module atoms_module: String,
  decoders_module decoders_module: String,
) -> String {
  "//// Code generated by libero. DO NOT EDIT.

import " <> decoders_module <> " as decoders
import gleam/dynamic.{type Dynamic}
import libero/error.{type DecodeError}
import libero/etf/wire as etf_wire
import libero/frame.{type ServerFrame}

pub fn ensure() -> Nil {
  let _ = ensure_atoms()
  let _ = decoders.ensure_decoders()
  Nil
}

pub fn encode(value: a) -> BitArray {
  ensure()
  etf_wire.encode(value)
}

pub fn decode(bytes: BitArray) -> Result(a, DecodeError) {
  ensure()
  etf_wire.decode_safe(bytes)
}

pub fn encode_request(
  module module: String,
  request_id request_id: Int,
  msg msg: a,
) -> BitArray {
  ensure()
  etf_wire.encode_request(module:, request_id:, msg:)
}

pub fn decode_request(
  bytes: BitArray,
) -> Result(#(String, Int, Dynamic), DecodeError) {
  ensure()
  etf_wire.decode_request(bytes)
}

pub fn encode_response(request_id request_id: Int, value value: a) -> BitArray {
  ensure()
  etf_wire.encode_response(request_id:, value:)
}

pub fn decode_server_frame(
  bytes: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  ensure()
  etf_wire.decode_server_frame(bytes)
}

pub fn encode_push(module module: String, value value: a) -> BitArray {
  ensure()
  etf_wire.encode_push(module:, value:)
}

pub fn encode_flags(value: a) -> String {
  ensure()
  etf_wire.encode_flags(value)
}

pub fn decode_flags_typed(
  flags flags: String,
  decoder_name decoder_name: String,
) -> Result(a, DecodeError) {
  ensure()
  etf_wire.decode_flags_typed(flags:, decoder_name:)
}

@external(erlang, \"" <> atoms_module <> "\", \"ensure\")
fn ensure_atoms() -> Nil {
  Nil
}
"
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

/// Resolve the optional mirrored generated-file output directory from
/// environment config.
pub fn mirrored_output_dir_from_env(
  env_value: option.Option(String),
) -> option.Option(String) {
  optional_output_dir(env_value)
}

pub fn config_from_toml(content: String) -> Result(LiberoConfig, String) {
  case tom.parse(content) {
    Error(_) -> Error("The file contains invalid TOML.")
    Ok(parsed) -> {
      use use_json <- result.try(
        optional_config_bool(parsed, ["tools", "libero", "use_json"]),
      )
      use erlang_output_dir <- result.try(
        optional_config_string(parsed, ["tools", "libero", "erlang_output_dir"]),
      )
      use mirrored_output_dir <- result.try(
        optional_config_string(parsed, [
          "tools",
          "libero",
          "mirrored_output_dir",
        ]),
      )
      use type_seeds <- result.try(optional_config_type_seeds(parsed))
      Ok(LiberoConfig(
        use_json: option.unwrap(use_json, False),
        erlang_output_dir: output_dir_or_default(erlang_output_dir),
        mirrored_output_dir: optional_output_dir(mirrored_output_dir),
        type_seeds:,
      ))
    }
  }
}

pub fn resolve_use_json(
  config: LiberoConfig,
  env_value: option.Option(String),
) -> Bool {
  case env_value {
    option.Some(_) -> env_flag(env_value)
    option.None -> config.use_json
  }
}

pub fn resolve_mirrored_output_dir(
  config: LiberoConfig,
  env_value: option.Option(String),
) -> option.Option(String) {
  case env_value {
    option.Some(_) -> mirrored_output_dir_from_env(env_value)
    option.None -> config.mirrored_output_dir
  }
}

fn output_dir_or_default(value: option.Option(String)) -> String {
  case optional_output_dir(value) {
    option.Some(path) -> path
    option.None -> out_dir
  }
}

fn optional_output_dir(value: option.Option(String)) -> option.Option(String) {
  case value {
    option.Some(path) -> {
      case string.trim(path) {
        "" -> option.None
        trimmed -> option.Some(trimmed)
      }
    }
    _ -> option.None
  }
}

fn module_path_from_output_dir(path: String) -> String {
  let trimmed = string.trim(path)
  let without_src = case string.starts_with(trimmed, "src/") {
    True -> string.drop_start(trimmed, 4)
    False -> trimmed
  }

  without_src
  |> string.split("/")
  |> list.filter(fn(part) { part != "" && part != "." })
  |> string.join("/")
}

fn child_module(parent: String, child: String) -> String {
  case parent {
    "" -> child
    _ -> parent <> "/" <> child
  }
}

fn optional_config_bool(
  parsed: dict.Dict(String, tom.Toml),
  key: List(String),
) -> Result(option.Option(Bool), String) {
  case tom.get_bool(parsed, key) {
    Ok(value) -> Ok(option.Some(value))
    Error(tom.NotFound(_)) -> Ok(option.None)
    Error(tom.WrongType(_, _, got)) ->
      Error(
        "Expected `"
        <> string.join(key, ".")
        <> "` to be a Bool, got "
        <> got
        <> ".",
      )
  }
}

fn optional_config_string(
  parsed: dict.Dict(String, tom.Toml),
  key: List(String),
) -> Result(option.Option(String), String) {
  case tom.get_string(parsed, key) {
    Ok(value) -> Ok(option.Some(value))
    Error(tom.NotFound(_)) -> Ok(option.None)
    Error(tom.WrongType(_, _, got)) ->
      Error(
        "Expected `"
        <> string.join(key, ".")
        <> "` to be a String, got "
        <> got
        <> ".",
      )
  }
}

fn optional_config_type_seeds(
  parsed: dict.Dict(String, tom.Toml),
) -> Result(List(#(String, String)), String) {
  let key = ["tools", "libero", "type_seeds"]
  case tom.get_array(parsed, key) {
    Ok(values) ->
      list.try_map(values, fn(value) {
        case value {
          tom.String(seed) -> parse_type_seed(seed)
          other ->
            Error(
              "Expected `"
              <> string.join(key, ".")
              <> "` to contain only String values, got "
              <> tom_type_name(other)
              <> ".",
            )
        }
      })
    Error(tom.NotFound(_)) -> Ok([])
    Error(tom.WrongType(_, _, got)) ->
      Error(
        "Expected `"
        <> string.join(key, ".")
        <> "` to be an Array, got "
        <> got
        <> ".",
      )
  }
}

fn parse_type_seed(seed: String) -> Result(#(String, String), String) {
  case string.split(string.trim(seed), ".") {
    [module_path, type_name] -> {
      let module_path = string.trim(module_path)
      let type_name = string.trim(type_name)
      case module_path, type_name {
        "", _ | _, "" -> type_seed_error(seed)
        _, _ -> Ok(#(module_path, type_name))
      }
    }
    _ -> type_seed_error(seed)
  }
}

fn type_seed_error(seed: String) -> Result(#(String, String), String) {
  Error(
    "Expected `tools.libero.type_seeds` value `"
    <> seed
    <> "` to use `module/path.TypeName`.",
  )
}

fn tom_type_name(value: tom.Toml) -> String {
  case value {
    tom.Int(_) -> "Int"
    tom.Float(_) -> "Float"
    tom.Infinity(_) -> "Infinity"
    tom.Nan(_) -> "Nan"
    tom.Bool(_) -> "Bool"
    tom.String(_) -> "String"
    tom.Date(_) -> "Date"
    tom.Time(_) -> "Time"
    tom.DateTime(..) -> "DateTime"
    tom.Array(_) -> "Array"
    tom.ArrayOfTables(_) -> "ArrayOfTables"
    tom.Table(_) -> "Table"
    tom.InlineTable(_) -> "InlineTable"
  }
}

fn write_generated_files(
  out_dir out_dir: String,
  dispatch_src dispatch_src: String,
  request_msg_src request_msg_src: String,
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
    out_dir <> "/requests.gleam",
    format.format_gleam(request_msg_src),
  ))
  use _ <- result.try(write_file(
    out_dir <> "/json_codecs.gleam",
    format.format_gleam(json_codecs_src),
  ))
  use _ <- result.try(write_file(out_dir <> "/contract.json", json_contract))
  Ok(Nil)
}

fn write_etf_generated_files(
  out_dir out_dir: String,
  dispatch_src dispatch_src: String,
  request_msg_src request_msg_src: String,
  decoders_js decoders_js: String,
  decoders_gleam decoders_gleam: String,
  etf_codec_gleam etf_codec_gleam: String,
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
    out_dir <> "/requests.gleam",
    format.format_gleam(request_msg_src),
  ))
  use _ <- result.try(write_file(out_dir <> "/decoders_ffi.mjs", decoders_js))
  use _ <- result.try(write_file(
    out_dir <> "/decoders.gleam",
    format.format_gleam(decoders_gleam),
  ))
  use _ <- result.try(write_file(
    out_dir <> "/etf.gleam",
    format.format_gleam(etf_codec_gleam),
  ))
  use _ <- result.try(write_file(atoms_path, atoms_erl))
  use _ <- result.try(write_file(wire_path, wire_erl))
  use _ <- result.try(write_file(out_dir <> "/contract.json", json_contract))
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

fn write_mirrored_json_files(
  out out: String,
  request_msg_src request_msg_src: String,
  json_codecs_src json_codecs_src: String,
  json_contract json_contract: String,
) -> Result(Nil, WriteError) {
  use _ <- result.try(
    simplifile.create_directory_all(out)
    |> result.map_error(fn(cause) { CannotCreateDir(path: out, cause:) }),
  )
  use _ <- result.try(write_file(
    out <> "/requests.gleam",
    format.format_gleam(request_msg_src),
  ))
  use _ <- result.try(write_file(
    out <> "/json_codecs.gleam",
    format.format_gleam(json_codecs_src),
  ))
  write_file(out <> "/contract.json", json_contract)
}

fn write_mirrored_etf_files(
  out out: String,
  request_msg_src request_msg_src: String,
  js js: String,
  gleam gleam: String,
  etf_codec_gleam etf_codec_gleam: String,
) -> Result(Nil, WriteError) {
  use _ <- result.try(
    simplifile.create_directory_all(out)
    |> result.map_error(fn(cause) { CannotCreateDir(path: out, cause:) }),
  )
  use _ <- result.try(write_file(
    out <> "/requests.gleam",
    format.format_gleam(request_msg_src),
  ))
  use _ <- result.try(write_file(out <> "/decoders_ffi.mjs", js))
  use _ <- result.try(write_file(
    out <> "/decoders.gleam",
    format.format_gleam(gleam),
  ))
  write_file(out <> "/etf.gleam", format.format_gleam(etf_codec_gleam))
}

fn read_libero_config() -> Result(LiberoConfig, String) {
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
      case config_from_toml(content) {
        Ok(config) -> Ok(config)
        Error(msg) ->
          Error(gen_error.error_box(
            title: "Could not read Libero config",
            path: "gleam.toml",
            body_lines: [msg],
            hint: option.Some(
              "Use `[tools.libero]` with `use_json = true`, `erlang_output_dir = \"...\"`, or `mirrored_output_dir = \"...\"`.",
            ),
          ))
      }
  }
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

fn read_dependency_names() -> Result(List(String), String) {
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
          case tom.get_table(parsed, ["dependencies"]) {
            Ok(dependencies) -> Ok(dict.keys(dependencies))
            Error(_) -> Ok([])
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
