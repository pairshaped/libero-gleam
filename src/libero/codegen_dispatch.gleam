//// Server-side dispatch generator.
////
//// Produces dispatch source from a list of handler endpoints. The generated
//// module pattern-matches incoming wire envelopes onto handler function
//// calls and produces ETF-encoded responses.
////
//// Each handler call is wrapped in `trace.try_call` so a panicked handler
//// produces a structured InternalError response (with trace ID for log
//// correlation) instead of crashing the caller's process.

import gleam/list
import gleam/option
import gleam/string
import libero/codegen
import libero/field_type
import libero/scanner
import libero/walker.{type DiscoveredType}
import libero/wire_identity

pub type ExtraParam {
  ExtraParam(name: String, type_ref: String, import_line: String)
}

/// Generate dispatch.gleam source from scanned endpoints.
pub fn generate(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  context_module context_module: String,
  context_type_name context_type_name: String,
  wire_module_tag wire_module_tag: String,
  atoms_module atoms_module: option.Option(String),
  wire_module wire_module: option.Option(String),
) -> String {
  generate_with_extra_params(
    endpoints:,
    context_module:,
    context_type_name:,
    wire_module_tag:,
    atoms_module:,
    wire_module:,
    extra_params: [],
  )
}

/// Generate dispatch with additional pass-through parameters on handle()
/// and every handler call. Each ExtraParam adds an import, a function
/// parameter, and a labeled argument threaded to handlers.
pub fn generate_with_extra_params(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  context_module context_module: String,
  context_type_name context_type_name: String,
  wire_module_tag wire_module_tag: String,
  atoms_module atoms_module: option.Option(String),
  wire_module wire_module: option.Option(String),
  extra_params extra_params: List(ExtraParam),
) -> String {
  let extra_import_lines =
    extra_params
    |> list.filter(fn(p) { p.import_line != "" })
    |> list.map(fn(p) { p.import_line })
    |> list.unique
  let extra_handle_params =
    extra_params
    |> list.map(fn(p) {
      "\n  " <> p.name <> " " <> p.name <> ": " <> p.type_ref <> ","
    })
    |> string.join("")
  let extra_args =
    extra_params
    |> list.map(fn(p) { ", " <> p.name })
    |> string.join("")

  let handler_modules =
    endpoints
    |> list.map(fn(e) { e.module_path })
    |> list.unique()
  let handler_imports =
    list.map(handler_modules, fn(mod) {
      let alias = handler_alias(mod)
      "import " <> mod <> " as " <> alias
    })

  // Build an alias resolver that uses the handler alias when a type's
  // module is already imported for the handler (avoids duplicate imports).
  let base_resolve = codegen.build_alias_resolver(endpoints:)
  let resolve_alias = fn(module_path: String) -> String {
    case list.contains(handler_modules, module_path) {
      True -> handler_alias(module_path)
      False -> base_resolve(module_path)
    }
  }
  // Only emit type imports for modules NOT already covered by handler imports.
  let shared_type_imports =
    collect_dispatch_type_modules(endpoints:)
    |> list.filter(fn(module_path) {
      !list.contains(handler_modules, module_path)
    })
    |> list.map(fn(module_path) {
      let alias = resolve_alias(module_path)
      case alias == field_type.last_segment(module_path) {
        True -> "import " <> module_path
        False -> "import " <> module_path <> " as " <> alias
      }
    })
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

  let request_msg_variants =
    codegen.emit_request_msg_variants(endpoints:, resolve_alias:)

  let known_tag_arms =
    endpoints
    |> list.map(fn(e) {
      "        Ok(\"server_"
      <> e.fn_name
      <> "\") ->\n"
      <> "          dispatch_known(msg, request_id, server_context"
      <> extra_args
      <> ")"
    })
    |> string.join("\n")

  let case_arms =
    list.map(endpoints, emit_case_arm(
      _,
      wire_module:,
      extra_args:,
      resolve_alias:,
    ))

  let atoms_external = case atoms_module {
    option.Some(mod) ->
      "\n/// Pre-register all constructor atoms that may appear in client ETF
/// payloads, so binary_to_term([safe]) can decode them. Called once
/// on the first transport call; subsequent calls are a no-op (persistent_term
/// lookup).
@external(erlang, \"" <> mod <> "\", \"ensure\")
fn ensure_atoms() -> Nil
"
    option.None -> ""
  }

  let ensure_call = case atoms_module {
    option.Some(_) -> "  ensure_atoms()\n  "
    option.None -> ""
  }

  let inner_case = case endpoints {
    [] ->
      "        Ok(_) ->\n"
      <> "          #(wire.encode_response(request_id:, value:Error(UnknownFunction(\""
      <> wire_module_tag
      <> "\"))), server_context)\n"
      <> "        Error(_) ->\n"
      <> "          #(wire.encode_response(request_id:, value:Error(MalformedRequest)), server_context)"
    _ ->
      known_tag_arms
      <> "\n"
      <> "        Ok(tag) ->\n"
      <> "          #(wire.encode_response(request_id:, value:Error(UnknownFunction(\""
      <> wire_module_tag
      <> ".\" <> tag))), server_context)\n"
      <> "        Error(_) ->\n"
      <> "          #(wire.encode_response(request_id:, value:Error(MalformedRequest)), server_context)"
  }

  let wire_externals = case wire_module, endpoints {
    option.Some(mod), [_, ..] -> {
      let decode_ext =
        "\n@external(erlang, \""
        <> mod
        <> "\", \"decode_request_msg\")\nfn wire_decode_request_msg(msg: a) -> b\n"
      let response_exts =
        list.map(endpoints, fn(e) {
          "@external(erlang, \""
          <> mod
          <> "\", \"encode_response_"
          <> e.fn_name
          <> "\")\nfn wire_encode_response_"
          <> e.fn_name
          <> "(result: a) -> b\n"
        })
        |> string.join("\n")
      decode_ext <> "\n" <> response_exts
    }
    _, _ -> ""
  }

  let should_decode_msg = case wire_module, endpoints {
    option.Some(_), [_, ..] -> True
    _, _ -> False
  }

  let request_dispatch_body = case should_decode_msg {
    True -> "      case trace.try_call(fn() {
        let msg = wire_decode_request_msg(msg)
        case wire.variant_tag(msg) {
" <> inner_case <> "
        }
      }) {
        Ok(response) -> response
        Error(reason) -> {
          let trace_id = trace.new_trace_id()
          io.println_error(\"[libero] \" <> trace_id <> \" malformed message: \" <> reason)
          #(wire.encode_response(request_id:, value:Error(MalformedRequest)), server_context)
        }
      }"
    False -> "      case wire.variant_tag(msg) {
" <> inner_case <> "
      }"
  }

  // The outer trace.try_call catches coerce failures and pattern-match
  // crashes (malformed message shape). Each case arm has its own inner
  // trace.try_call around the actual handler call to isolate handler panics.
  let dispatch_known = case endpoints {
    [] -> ""
    _ -> "
fn dispatch_known(msg, request_id, server_context" <> extra_args <> ") {
  case trace.try_call(fn() {
  let typed_msg: RequestMsg = wire.coerce(msg)
  case typed_msg {
" <> string.join(case_arms, "\n") <> "
  }
  }) {
    Ok(response) -> response
    Error(reason) -> {
      let trace_id = trace.new_trace_id()
      io.println_error(\"[libero] \" <> trace_id <> \" malformed message: \" <> reason)
      #(wire.encode_response(request_id:, value:Error(MalformedRequest)), server_context)
    }
  }
}
"
  }

  "//// Code generated by libero. DO NOT EDIT.

import gleam/io
import libero/error.{InternalError, MalformedRequest, UnknownFunction}
import libero/trace
import libero/etf/wire" <> dict_import <> option_import <> "
import " <> context_module <> ".{type " <> context_type_name <> "}
" <> string.join(handler_imports, "\n") <> "
" <> string.join(shared_type_imports, "\n") <> "
" <> case extra_import_lines {
    [] -> ""
    lines -> string.join(lines, "\n") <> "\n"
  } <> atoms_external <> wire_externals <> "
pub type RequestMsg {
" <> string.join(request_msg_variants, "\n") <> "
}

pub fn handle(
  server_context server_context: " <> context_type_name <> ",
  data data: BitArray," <> extra_handle_params <> "
) -> #(BitArray, " <> context_type_name <> ") {
  " <> ensure_call <> "case wire.decode_request(data) {
    Ok(#(\"" <> wire_module_tag <> "\", request_id, msg)) -> {
" <> request_dispatch_body <> "
    }
    Ok(#(name, request_id, _)) ->
      #(wire.encode_response(request_id:, value:Error(UnknownFunction(name))), server_context)
    Error(_) ->
      #(wire.encode_response(request_id: 0, value: Error(MalformedRequest)), server_context)
  }
}
" <> dispatch_known
}

/// Generate a JSON server dispatch module source from scanned endpoints.
///
/// The generated module accepts JSON text, validates the JSON contract hash
/// before decoding the request body, decodes `RequestMsg` through the generated
/// JSON codec module, and encodes handler results through generated response
/// helpers from the same module.
pub fn generate_json(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  context_module context_module: String,
  context_type_name context_type_name: String,
  wire_module_tag wire_module_tag: String,
  request_msg_module request_msg_module: String,
  json_codecs_module json_codecs_module: String,
  contract_hash contract_hash: String,
) -> String {
  generate_json_with_extra_params(
    endpoints:,
    context_module:,
    context_type_name:,
    wire_module_tag:,
    request_msg_module:,
    json_codecs_module:,
    contract_hash:,
    extra_params: [],
  )
}

pub fn generate_json_with_extra_params(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  context_module context_module: String,
  context_type_name context_type_name: String,
  wire_module_tag wire_module_tag: String,
  request_msg_module request_msg_module: String,
  json_codecs_module json_codecs_module: String,
  contract_hash contract_hash: String,
  extra_params extra_params: List(ExtraParam),
) -> String {
  let extra_import_lines =
    extra_params
    |> list.filter(fn(p) { p.import_line != "" })
    |> list.map(fn(p) { p.import_line })
    |> list.unique
  let extra_handle_params =
    extra_params
    |> list.map(fn(p) {
      "\n  " <> p.name <> " " <> p.name <> ": " <> p.type_ref <> ","
    })
    |> string.join("")
  let extra_args =
    extra_params
    |> list.map(fn(p) { ", " <> p.name })
    |> string.join("")

  let handler_modules =
    endpoints
    |> list.map(fn(e) { e.module_path })
    |> list.unique()
  let handler_imports =
    list.map(handler_modules, fn(mod) {
      let alias = handler_alias(mod)
      "import " <> mod <> " as " <> alias
    })
  let base_resolve = codegen.build_alias_resolver(endpoints:)
  let resolve_alias = fn(module_path: String) -> String {
    case list.contains(handler_modules, module_path) {
      True -> handler_alias(module_path)
      False -> base_resolve(module_path)
    }
  }
  let shared_type_imports =
    collect_msg_type_modules(endpoints:)
    |> list.filter(fn(module_path) {
      !list.contains(handler_modules, module_path)
    })
    |> list.map(fn(module_path) {
      let alias = resolve_alias(module_path)
      case alias == field_type.last_segment(module_path) {
        True -> "import " <> module_path
        False -> "import " <> module_path <> " as " <> alias
      }
    })

  let case_arms =
    list.map(endpoints, emit_json_case_arm(_, extra_args:, resolve_alias:))
    |> string.join("\n")

  let active_json_dispatch_imports = case endpoints {
    [] -> ""
    _ ->
      "import gleam/io\n"
      <> "import libero/trace\n"
      <> "import "
      <> request_msg_module
      <> " as request_msg\n"
      <> "import "
      <> json_codecs_module
      <> " as json_codecs\n"
  }

  let dispatch_known = case endpoints {
    [] -> ""
    _ -> "
fn dispatch_known(typed_msg: request_msg.RequestMsg, request_id: Int, server_context: " <> context_type_name <> extra_handle_params <> ") {
  case trace.try_call(fn() {
    case typed_msg {
" <> case_arms <> "
    }
  }) {
    Ok(response) -> response
    Error(reason) -> {
      let trace_id = trace.new_trace_id()
      io.println_error(\"[libero] \" <> trace_id <> \" malformed message: \" <> reason)
      #(wire.encode_error(request_id: Some(request_id), errors: [JsonError(\"message\", \"malformed request\")]), server_context)
    }
  }
}
"
  }

  let handle_known_module = case endpoints {
    [] ->
      "        True ->\n"
      <> "          #(wire.encode_error(request_id: Some(request_id), errors: [JsonError(\"module\", \"unknown function: "
      <> wire_module_tag
      <> "\")]), server_context)"
    _ ->
      "        True -> {\n"
      <> "          case json_codecs.json_decode_"
      <> walker.qualified_atom_name(
        module_path: request_msg_module,
        variant_name: "RequestMsg",
      )
      <> "(message) {\n"
      <> "            Ok(typed_msg) -> dispatch_known(typed_msg, request_id, server_context"
      <> extra_args
      <> ")\n"
      <> "            Error(errors) -> #(wire.encode_error(request_id: Some(request_id), errors:), server_context)\n"
      <> "          }\n"
      <> "        }"
  }

  "//// Code generated by libero. DO NOT EDIT.

import gleam/option.{None, Some}
import libero/json/error.{JsonError}
import libero/json/wire
" <> active_json_dispatch_imports <> "
import " <> context_module <> ".{type " <> context_type_name <> "}
" <> string.join(handler_imports, "\n") <> "
" <> string.join(shared_type_imports, "\n") <> "
" <> case extra_import_lines {
    [] -> ""
    lines -> string.join(lines, "\n") <> "\n"
  } <> "
pub fn handle(
  server_context server_context: " <> context_type_name <> ",
  data data: String," <> extra_handle_params <> "
) -> #(String, " <> context_type_name <> ") {
  case wire.decode_request(data, expected_hash: \"" <> contract_hash <> "\") {
    Ok(wire.RequestEnvelope(module:, request_id:, message:)) -> {
      case module == \"" <> wire_module_tag <> "\" {
" <> handle_known_module <> "
        False ->
          #(wire.encode_error(request_id: Some(request_id), errors: [JsonError(\"module\", \"unknown function: \" <> module)]), server_context)
      }
    }
    Error(errors) ->
      #(wire.encode_error(request_id: None, errors:), server_context)
  }
}
" <> dispatch_known
}

fn emit_case_arm(
  endpoint e: scanner.HandlerEndpoint,
  wire_module wire_module: option.Option(String),
  extra_args extra_args: String,
  resolve_alias resolve_alias: fn(String) -> String,
) -> String {
  let variant_name = codegen.to_pascal_case("server_" <> e.fn_name)
  let alias = handler_alias(e.module_path)
  let param_destructure =
    codegen.variant_pattern(variant_name:, params: e.params)

  let handler_args = case e.msg_type {
    option.Some(#(msg_module, msg_constructor)) ->
      msg_type_constructor(
        module_path: msg_module,
        constructor_name: msg_constructor,
        params: e.params,
        resolve_alias:,
      )
      <> ", server_context"
      <> extra_args
    option.None -> {
      let positional = list.map(e.params, fn(p) { p.0 })
      string.join(
        list.append(positional, ["server_context" <> extra_args]),
        ", ",
      )
    }
  }
  let raw_call =
    alias <> "." <> "server_" <> e.fn_name <> "(" <> handler_args <> ")"
  let ok_destructure = case e.mutates_context {
    True -> "#(result, new_ctx)"
    False -> "result"
  }
  let ok_ctx = case e.mutates_context {
    True -> "new_ctx"
    False -> "server_context"
  }
  let encode_line = case wire_module {
    option.Some(_) ->
      "              let result = wire_encode_response_"
      <> e.fn_name
      <> "(result)\n"
    option.None -> ""
  }

  "        "
  <> param_destructure
  <> " -> {\n"
  <> "          case trace.try_call(fn() { "
  <> raw_call
  <> " }) {\n"
  <> "            Ok("
  <> ok_destructure
  <> ") -> {\n"
  <> encode_line
  <> "              #(wire.encode_response(request_id:, value:Ok(result)), "
  <> ok_ctx
  <> ")\n"
  <> "            }\n"
  <> "            Error(reason) -> {\n"
  <> "              let trace_id = trace.new_trace_id()\n"
  <> "              io.println_error(\"[libero] \" <> trace_id <> \" "
  <> e.fn_name
  <> ": \" <> reason)\n"
  <> "              #(wire.encode_response(request_id:, value:Error(InternalError(trace_id:, message: \"Something went wrong\"))), server_context)\n"
  <> "            }\n"
  <> "          }\n"
  <> "        }"
}

fn emit_json_case_arm(
  endpoint e: scanner.HandlerEndpoint,
  extra_args extra_args: String,
  resolve_alias resolve_alias: fn(String) -> String,
) -> String {
  let variant_name = codegen.to_pascal_case("server_" <> e.fn_name)
  let alias = handler_alias(e.module_path)
  let param_destructure =
    "request_msg." <> codegen.variant_pattern(variant_name:, params: e.params)

  let handler_args = case e.msg_type {
    option.Some(#(msg_module, msg_constructor)) ->
      msg_type_constructor(
        module_path: msg_module,
        constructor_name: msg_constructor,
        params: e.params,
        resolve_alias:,
      )
      <> ", server_context"
      <> extra_args
    option.None -> {
      let positional = list.map(e.params, fn(p) { p.0 })
      string.join(
        list.append(positional, ["server_context" <> extra_args]),
        ", ",
      )
    }
  }
  let raw_call =
    alias <> "." <> "server_" <> e.fn_name <> "(" <> handler_args <> ")"
  let ok_destructure = case e.mutates_context {
    True -> "#(result, new_ctx)"
    False -> "result"
  }
  let ok_ctx = case e.mutates_context {
    True -> "new_ctx"
    False -> "server_context"
  }

  "      "
  <> param_destructure
  <> " -> {\n"
  <> "        case trace.try_call(fn() { "
  <> raw_call
  <> " }) {\n"
  <> "          Ok("
  <> ok_destructure
  <> ") -> {\n"
  <> "            let value = json_codecs.json_encode_response_"
  <> e.fn_name
  <> "(result)\n"
  <> "            #(wire.encode_response(request_id:, value:), "
  <> ok_ctx
  <> ")\n"
  <> "          }\n"
  <> "          Error(reason) -> {\n"
  <> "            let trace_id = trace.new_trace_id()\n"
  <> "            io.println_error(\"[libero] \" <> trace_id <> \" "
  <> e.fn_name
  <> ": \" <> reason)\n"
  <> "            #(wire.encode_error(request_id: Some(request_id), errors: [JsonError(\"handler."
  <> e.fn_name
  <> "\", \"internal error: \" <> trace_id)]), server_context)\n"
  <> "          }\n"
  <> "        }\n"
  <> "      }"
}

fn collect_dispatch_type_modules(
  endpoints endpoints: List(scanner.HandlerEndpoint),
) -> List(String) {
  let from_fields =
    codegen.collect_endpoint_type_modules(endpoints:, include_return: False)
  let from_msg_types = collect_msg_type_modules(endpoints:)
  list.append(from_fields, from_msg_types)
  |> list.unique()
  |> list.sort(string.compare)
}

fn collect_msg_type_modules(
  endpoints endpoints: List(scanner.HandlerEndpoint),
) -> List(String) {
  endpoints
  |> list.filter_map(fn(e) {
    case e.msg_type {
      option.Some(#(module_path, _)) -> Ok(module_path)
      option.None -> Error(Nil)
    }
  })
  |> list.unique()
  |> list.sort(string.compare)
}

fn msg_type_constructor(
  module_path module_path: String,
  constructor_name constructor_name: String,
  params params: List(#(String, field_type.FieldType)),
  resolve_alias resolve_alias: fn(String) -> String,
) -> String {
  let constructor = resolve_alias(module_path) <> "." <> constructor_name
  case params {
    [] -> constructor
    _ -> {
      let labels = list.map(params, fn(p) { p.0 <> ":" })
      constructor <> "(" <> string.join(labels, ", ") <> ")"
    }
  }
}

fn handler_alias(module_path: String) -> String {
  codegen.module_to_underscored(module_path) <> "_handler"
}

/// Generate an Erlang FFI file that pre-registers all constructor atoms
/// discovered from handler endpoints, plus framework atoms used by
/// libero's wire protocol. Calling `ensure/0` from this module creates
/// the atoms in the BEAM atom table so that `binary_to_term([safe])`
/// can decode client ETF payloads without rejecting unknown atoms.
///
/// Under the wire-identity scheme there is no AtomMap: identity is
/// baked into the per-type transformer functions in `<consumer>_wire.erl`
/// at codegen time, so the runtime carries no qualification table.
pub fn generate_atoms_erl(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  atoms_module atoms_module: String,
  wire_module wire_module: option.Option(String),
) -> String {
  let framework_atoms = [
    "ok", "error", "some", "none", "nil", "true", "false", "malformed_request",
    "unknown_function", "internal_error", "decode_error",
  ]
  let handler_atoms =
    list.flat_map(endpoints, fn(e) { [e.fn_name, "server_" <> e.fn_name] })
  let variant_atoms =
    list.flat_map(discovered, fn(dt) {
      list.flat_map(dt.variants, fn(v) {
        let #(_sig, hash) =
          wire_identity.wire_identity(
            module_path: v.module_path,
            constructor_name: v.variant_name,
            fields: v.fields,
          )
        // Bare atom kept for any code that still references the BEAM-shape
        // constructor before transformer conversion (e.g. on the handler
        // side returning bare-atom records). The wire hash is what
        // appears on the actual ETF wire after the transformer runs.
        [walker.to_snake_case(v.variant_name), hash]
      })
    })
  let all_atoms =
    list.flatten([framework_atoms, handler_atoms, variant_atoms])
    |> list.unique()
    |> list.sort(string.compare)
  let atom_list =
    list.map(all_atoms, fn(atom) { "        <<\"" <> atom <> "\">>" })
    |> string.join(",\n")

  "%% Code generated by libero. DO NOT EDIT.
%%
%% Pre-registers all atoms that may appear in client ETF payloads,
%% so binary_to_term([safe]) can decode them without rejecting unknown
%% atoms. Includes framework atoms, handler function names, bare
%% constructor names, and the 10-char hex wire-identity hashes that
%% the per-type transformer functions emit on the wire.
%%
%% ensure/0 uses persistent_term as a one-shot guard so the
%% binary_to_atom calls only run once per VM lifetime.

-module(" <> atoms_module <> ").
-export([ensure/0]).

ensure() ->
    case persistent_term:get({?MODULE, done}, false) of
        true -> nil;
        false -> do_ensure()
    end.

do_ensure() ->
    lists:foreach(fun(B) -> binary_to_atom(B) end, [
" <> atom_list <> "
    ]),
    " <> case wire_module {
    option.Some(mod) ->
      "persistent_term:put({libero, wire_module}, '" <> mod <> "'),\n    "
    option.None -> ""
  } <> "persistent_term:put({?MODULE, done}, true),
    nil.
"
}
