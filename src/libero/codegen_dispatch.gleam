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
import libero/scanner
import libero/walker.{type DiscoveredType}

/// Generate dispatch.gleam source from scanned endpoints.
/// The generated dispatch function signature:
///   pub fn handle(ctx: a, data: BitArray) -> #(BitArray, a)
pub fn generate(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  context_module context_module: String,
  context_type_name context_type_name: String,
  wire_module_tag wire_module_tag: String,
  atoms_module atoms_module: option.Option(String),
) -> String {
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
    codegen.collect_endpoint_type_imports(
      endpoints:,
      include_return: False,
      resolve_alias:,
    )
    |> list.filter(fn(import_line) {
      !list.any(handler_modules, fn(mod) {
        string.contains(import_line, "import " <> mod)
      })
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

  let client_msg_variants =
    codegen.emit_client_msg_variants(endpoints:, resolve_alias:)

  let known_tag_arms =
    endpoints
    |> list.map(fn(e) {
      "        Ok(\"server_"
      <> e.fn_name
      <> "\") ->\n"
      <> "          dispatch_known(msg, request_id, server_context)"
    })
    |> string.join("\n")

  let case_arms =
    list.map(endpoints, fn(e) {
      let variant_name = codegen.to_pascal_case("server_" <> e.fn_name)
      let alias = handler_alias(e.module_path)
      let param_destructure =
        codegen.variant_pattern(variant_name:, params: e.params)
      let handler_args = case e.msg_type_name {
        option.Some(_) -> "msg: wire.coerce(typed_msg), server_context:"
        option.None -> {
          let labeled = list.map(e.params, fn(p) { p.0 <> ":" })
          string.join(list.append(labeled, ["server_context:"]), ", ")
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
      "        "
      <> param_destructure
      <> " -> {\n"
      <> "          case trace.try_call(fn() { "
      <> raw_call
      <> " }) {\n"
      <> "            Ok("
      <> ok_destructure
      <> ") ->\n"
      <> "              #(wire.tag_response(request_id:, data: wire.encode(Ok(result))), "
      <> ok_ctx
      <> ")\n"
      <> "            Error(reason) -> {\n"
      <> "              let trace_id = trace.new_trace_id()\n"
      <> "              io.println_error(\"[libero] \" <> trace_id <> \" "
      <> e.fn_name
      <> ": \" <> reason)\n"
      <> "              #(wire.tag_response(request_id:, data: wire.encode(Error(InternalError(trace_id:, message: \"Something went wrong\")))), server_context)\n"
      <> "            }\n"
      <> "          }\n"
      <> "        }"
    })

  let atoms_external = case atoms_module {
    option.Some(mod) ->
      "\n/// Pre-register all constructor atoms that may appear in client ETF
/// payloads, so binary_to_term([safe]) can decode them. Called once
/// on the first RPC call; subsequent calls are a no-op (persistent_term
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
      <> "          #(wire.tag_response(request_id:, data: wire.encode(Error(UnknownFunction(\""
      <> wire_module_tag
      <> "\")))), server_context)\n"
      <> "        Error(_) ->\n"
      <> "          #(wire.tag_response(request_id:, data: wire.encode(Error(MalformedRequest))), server_context)"
    _ ->
      known_tag_arms
      <> "\n"
      <> "        Ok(tag) ->\n"
      <> "          #(wire.tag_response(request_id:, data: wire.encode(Error(UnknownFunction(\""
      <> wire_module_tag
      <> ".\" <> tag)))), server_context)\n"
      <> "        Error(_) ->\n"
      <> "          #(wire.tag_response(request_id:, data: wire.encode(Error(MalformedRequest))), server_context)"
  }

  let dispatch_known = case endpoints {
    [] -> ""
    _ -> "
fn dispatch_known(msg, request_id, server_context) {
  let typed_msg: ClientMsg = wire.coerce(msg)
  case typed_msg {
" <> string.join(case_arms, "\n") <> "
  }
}
"
  }

  "//// Code generated by libero. DO NOT EDIT.

import gleam/io
import libero/error.{InternalError, MalformedRequest, UnknownFunction}
import libero/trace
import libero/wire" <> dict_import <> option_import <> "
import " <> context_module <> ".{type " <> context_type_name <> "}
" <> string.join(handler_imports, "\n") <> "
" <> string.join(shared_type_imports, "\n") <> "
" <> atoms_external <> "
pub type ClientMsg {
" <> string.join(client_msg_variants, "\n") <> "
}

pub fn handle(
  server_context server_context: " <> context_type_name <> ",
  data data: BitArray,
) -> #(BitArray, " <> context_type_name <> ") {
  " <> ensure_call <> "case wire.decode_call(data) {
    Ok(#(\"" <> wire_module_tag <> "\", request_id, msg)) -> {
      case wire.variant_tag(msg) {
" <> inner_case <> "
      }
    }
    Ok(#(name, request_id, _)) ->
      #(wire.tag_response(request_id:, data: wire.encode(Error(UnknownFunction(name)))), server_context)
    Error(_) ->
      #(wire.tag_response(request_id: 0, data: wire.encode(Error(MalformedRequest))), server_context)
  }
}
" <> dispatch_known
}

fn handler_alias(module_path: String) -> String {
  codegen.module_to_underscored(module_path) <> "_handler"
}

/// Generate an Erlang FFI file that pre-registers all constructor atoms
/// discovered from handler endpoints, plus framework atoms used by
/// libero's wire protocol. Calling `ensure/0` from this module creates
/// the atoms in the BEAM atom table so that `binary_to_term([safe])`
/// can decode client ETF payloads without rejecting unknown atoms.
pub fn generate_atoms_erl(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
  atoms_module atoms_module: String,
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
        [walker.to_snake_case(v.variant_name), v.atom_name]
      })
    })
  let all_atoms =
    list.flatten([framework_atoms, handler_atoms, variant_atoms])
    |> list.unique()
    |> list.sort(string.compare)
  let atom_list =
    list.map(all_atoms, fn(atom) { "        <<\"" <> atom <> "\">>" })
    |> string.join(",\n")

  let variant_mappings =
    list.flat_map(discovered, fn(dt) {
      list.map(dt.variants, fn(v) {
        let bare = walker.to_snake_case(v.variant_name)
        let qualified = v.atom_name
        "        <<\"" <> bare <> "\">> => <<\"" <> qualified <> "\">>"
      })
    })
    |> string.join(",\n")

  "%% Code generated by libero. DO NOT EDIT.
%%
%% Pre-registers all constructor atoms that may appear in client ETF
%% payloads, so binary_to_term([safe]) can decode them without
%% rejecting unknown atoms. Also stores an atom-qualification map
%% so the encoder can pack namespace-qualified atoms onto the wire.
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
    AtomMap = #{
" <> variant_mappings <> "
    },
    persistent_term:put({libero, atom_map}, AtomMap),
    persistent_term:put({?MODULE, done}, true),
    nil.
"
}
