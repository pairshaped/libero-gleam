//// Server-side dispatch generator.
////
//// Produces dispatch source from a list of handler endpoints. The generated
//// module pattern-matches incoming wire envelopes onto handler function
//// calls and produces ETF-encoded responses.
////
//// Each handler call is wrapped in `trace.try_call` so a panicked handler
//// produces a structured InternalError response (with trace ID for log
//// correlation) instead of crashing the caller's process.
////
//// When `wire_module` is set, the dispatch calls per-type wire transformer
//// FFI functions (from `<wire_module>.erl`) to convert between wire-shape
//// (hashed atoms) and BEAM-shape (bare atoms) at the dispatch boundary.

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import libero/codegen
import libero/field_type.{
  type FieldType, BitArrayField, BoolField, DictOf, FloatField, IntField, ListOf,
  NilField, OptionOf, ResultOf, StringField, TupleOf, TypeVar, UserType,
}
import libero/scanner
import libero/walker.{type DiscoveredType}
import libero/wire_identity

/// Generate dispatch.gleam source from scanned endpoints.
/// The generated dispatch function signature:
///   pub fn handle(ctx: a, data: BitArray) -> #(BitArray, a)
pub fn generate(
  endpoints endpoints: List(scanner.HandlerEndpoint),
  context_module context_module: String,
  context_type_name context_type_name: String,
  wire_module_tag wire_module_tag: String,
  atoms_module atoms_module: option.Option(String),
  wire_module wire_module: option.Option(String),
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

  let wire_transforms_active = option.is_some(wire_module)

  // Wire transformer FFI externals and conditional imports for container
  // mapping (list.map, option.map, etc.) in the generated dispatch.
  let #(wire_externals, list_import) = case wire_module {
    option.Some(wm) -> {
      let user_types = collect_wire_user_types(endpoints)
      let externals = emit_wire_externals(wm, user_types)
      let needs_list =
        list.any(endpoints, fn(e) {
          list.any(e.params, fn(p) { needs_container_import(p.1) })
          || needs_container_import(e.return_ok)
          || needs_container_import(e.return_err)
        })
      let li = case needs_list {
        True -> "\nimport gleam/list"
        False -> ""
      }
      #(externals, li)
    }
    option.None -> #("", "")
  }

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
      emit_case_arm(e, handler_modules, wire_transforms_active)
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
import libero/wire" <> dict_import <> option_import <> list_import <> "
import " <> context_module <> ".{type " <> context_type_name <> "}
" <> string.join(handler_imports, "\n") <> "
" <> string.join(shared_type_imports, "\n") <> "
" <> atoms_external <> wire_externals <> "
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

fn emit_case_arm(
  e: scanner.HandlerEndpoint,
  _handler_modules: List(String),
  wire_transforms: Bool,
) -> String {
  let variant_name = codegen.to_pascal_case("server_" <> e.fn_name)
  let alias = handler_alias(e.module_path)
  let param_destructure =
    codegen.variant_pattern(variant_name:, params: e.params)

  // Param decode: convert wire-shape (hashed atoms) to BEAM-shape (bare).
  // Skipped for msg_type handlers since the whole-message decoder handles
  // nested fields, and the destructured params use _ patterns.
  let param_decode_lets = case wire_transforms, e.msg_type {
    True, option.None ->
      e.params
      |> list.filter_map(fn(p) {
        let #(label, ft) = p
        case wire_decode_expr(ft, label) {
          option.None -> Error(Nil)
          option.Some(expr) ->
            Ok("          let " <> label <> " = " <> expr <> "\n")
        }
      })
      |> string.concat()
    _, _ -> ""
  }

  let handler_args = case e.msg_type {
    option.Some(#(module_path, type_name)) ->
      case wire_transforms {
        True -> {
          let qualified =
            walker.qualified_atom_name(module_path:, variant_name: type_name)
          "msg: wire_decode_"
          <> qualified
          <> "(wire.coerce(typed_msg)), server_context:"
        }
        False -> "msg: wire.coerce(typed_msg), server_context:"
      }
    option.None -> {
      let labeled = list.map(e.params, fn(p) { p.0 <> ":" })
      string.join(list.append(labeled, ["server_context:"]), ", ")
    }
  }
  let raw_call =
    alias <> "." <> "server_" <> e.fn_name <> "(" <> handler_args <> ")"
  let ok_destructure = case e.mutates_context {
    True -> "#(handler_result, new_ctx)"
    False -> "handler_result"
  }
  let ok_ctx = case e.mutates_context {
    True -> "new_ctx"
    False -> "server_context"
  }

  // Result encode: convert BEAM-shape handler result to wire-shape
  let result_encode_let = case wire_transforms {
    False -> ""
    True -> emit_result_encode(e.return_ok, e.return_err)
  }

  "        "
  <> param_destructure
  <> " -> {\n"
  <> param_decode_lets
  <> "          case trace.try_call(fn() { "
  <> raw_call
  <> " }) {\n"
  <> "            Ok("
  <> ok_destructure
  <> ") -> {\n"
  <> result_encode_let
  <> "              #(wire.tag_response(request_id:, data: wire.encode(Ok(handler_result))), "
  <> ok_ctx
  <> ")\n"
  <> "            }\n"
  <> "            Error(reason) -> {\n"
  <> "              let trace_id = trace.new_trace_id()\n"
  <> "              io.println_error(\"[libero] \" <> trace_id <> \" "
  <> e.fn_name
  <> ": \" <> reason)\n"
  <> "              #(wire.tag_response(request_id:, data: wire.encode(Error(InternalError(trace_id:, message: \"Something went wrong\")))), server_context)\n"
  <> "            }\n"
  <> "          }\n"
  <> "        }"
}

fn emit_result_encode(return_ok: FieldType, return_err: FieldType) -> String {
  let ok_fn = wire_transform_fn_ref(return_ok, "encode")
  let err_fn = wire_transform_fn_ref(return_err, "encode")
  case ok_fn, err_fn {
    option.None, option.None -> ""
    option.Some(ok_f), option.None ->
      "              let handler_result = case handler_result { Ok(v) -> Ok("
      <> ok_f
      <> "(v)) Error(e) -> Error(e) }\n"
    option.None, option.Some(err_f) ->
      "              let handler_result = case handler_result { Ok(v) -> Ok(v) Error(e) -> Error("
      <> err_f
      <> "(e)) }\n"
    option.Some(ok_f), option.Some(err_f) ->
      "              let handler_result = case handler_result { Ok(v) -> Ok("
      <> ok_f
      <> "(v)) Error(e) -> Error("
      <> err_f
      <> "(e)) }\n"
  }
}

fn handler_alias(module_path: String) -> String {
  codegen.module_to_underscored(module_path) <> "_handler"
}

// -- Wire transformation helpers --

fn wire_fn_name(module_path: String, type_name: String) -> String {
  walker.qualified_atom_name(module_path:, variant_name: type_name)
}

fn collect_wire_user_types(
  endpoints: List(scanner.HandlerEndpoint),
) -> List(#(String, String)) {
  list.flat_map(endpoints, fn(e) {
    let param_types =
      list.flat_map(e.params, fn(p) { field_type.collect_user_types(p.1) })
    let return_types =
      list.append(
        field_type.collect_user_types(e.return_ok),
        field_type.collect_user_types(e.return_err),
      )
    let msg_types = case e.msg_type {
      option.Some(#(mp, tn)) -> [#(mp, tn)]
      option.None -> []
    }
    list.flatten([param_types, return_types, msg_types])
  })
  |> list.unique()
}

fn emit_wire_externals(
  wm: String,
  user_types: List(#(String, String)),
) -> String {
  case user_types {
    [] -> ""
    _ ->
      list.flat_map(user_types, fn(t) {
        let #(module_path, type_name) = t
        let fn_atom = wire_fn_name(module_path, type_name)
        [
          "@external(erlang, \""
            <> wm
            <> "\", \"decode_"
            <> fn_atom
            <> "\")\nfn wire_decode_"
            <> fn_atom
            <> "(term: a) -> b\n",
          "@external(erlang, \""
            <> wm
            <> "\", \"encode_"
            <> fn_atom
            <> "\")\nfn wire_encode_"
            <> fn_atom
            <> "(term: a) -> b\n",
        ]
      })
      |> string.join("\n")
  }
}

fn needs_container_import(ft: FieldType) -> Bool {
  case ft {
    ListOf(element) -> option.is_some(wire_transform_fn_ref(element, "encode"))
    OptionOf(inner) -> option.is_some(wire_transform_fn_ref(inner, "encode"))
    DictOf(_, value) -> option.is_some(wire_transform_fn_ref(value, "encode"))
    ResultOf(ok, err) ->
      needs_container_import(ok) || needs_container_import(err)
    TupleOf(elements) -> list.any(elements, needs_container_import)
    UserType(args:, ..) -> list.any(args, needs_container_import)
    _ -> False
  }
}

fn wire_decode_expr(ft: FieldType, var: String) -> option.Option(String) {
  wire_transform_expr(ft:, var:, direction: "decode")
}

fn wire_transform_expr(
  ft ft: FieldType,
  var var: String,
  direction direction: String,
) -> option.Option(String) {
  case ft {
    UserType(module_path:, type_name:, ..) -> {
      let fn_name =
        "wire_" <> direction <> "_" <> wire_fn_name(module_path, type_name)
      option.Some(fn_name <> "(" <> var <> ")")
    }
    ListOf(element) ->
      case wire_transform_fn_ref(element, direction) {
        option.None -> option.None
        option.Some(fn_ref) ->
          option.Some("list.map(" <> var <> ", " <> fn_ref <> ")")
      }
    OptionOf(inner) ->
      case wire_transform_fn_ref(inner, direction) {
        option.None -> option.None
        option.Some(fn_ref) ->
          option.Some("option.map(" <> var <> ", " <> fn_ref <> ")")
      }
    DictOf(_, value) ->
      case wire_transform_fn_ref(value, direction) {
        option.None -> option.None
        option.Some(fn_ref) ->
          option.Some(
            "dict.map_values(" <> var <> ", fn(_, v) { " <> fn_ref <> "(v) })",
          )
      }
    ResultOf(ok, err) -> {
      let ok_fn = wire_transform_fn_ref(ok, direction)
      let err_fn = wire_transform_fn_ref(err, direction)
      case ok_fn, err_fn {
        option.None, option.None -> option.None
        option.Some(ok_f), option.None ->
          option.Some(
            "case "
            <> var
            <> " { Ok(v) -> Ok("
            <> ok_f
            <> "(v)) Error(e) -> Error(e) }",
          )
        option.None, option.Some(err_f) ->
          option.Some(
            "case "
            <> var
            <> " { Ok(v) -> Ok(v) Error(e) -> Error("
            <> err_f
            <> "(e)) }",
          )
        option.Some(ok_f), option.Some(err_f) ->
          option.Some(
            "case "
            <> var
            <> " { Ok(v) -> Ok("
            <> ok_f
            <> "(v)) Error(e) -> Error("
            <> err_f
            <> "(e)) }",
          )
      }
    }
    TupleOf(elements) -> wire_transform_tuple_expr(elements:, var:, direction:)
    IntField
    | FloatField
    | StringField
    | BoolField
    | BitArrayField
    | NilField
    | TypeVar(_) -> option.None
  }
}

fn wire_transform_tuple_expr(
  elements elements: List(FieldType),
  var var: String,
  direction direction: String,
) -> option.Option(String) {
  case tuple_transform_parts(elements, direction) {
    option.None -> option.None
    option.Some(#(pattern, body)) ->
      option.Some("{ let " <> pattern <> " = " <> var <> " " <> body <> " }")
  }
}

fn tuple_transform_parts(
  elements: List(FieldType),
  direction: String,
) -> option.Option(#(String, String)) {
  let indexed = list.index_map(elements, fn(ft, i) { #(ft, i) })
  let any_needs =
    list.any(indexed, fn(pair) {
      option.is_some(wire_transform_fn_ref(pair.0, direction))
    })
  case any_needs {
    False -> option.None
    True -> {
      let vars = list.map(indexed, fn(pair) { "t" <> int.to_string(pair.1) })
      let pattern = "#(" <> string.join(vars, ", ") <> ")"
      let body_terms =
        list.map(indexed, fn(pair) {
          let #(ft, i) = pair
          let elem_var = "t" <> int.to_string(i)
          case wire_transform_fn_ref(ft, direction) {
            option.None -> elem_var
            option.Some(fn_ref) -> fn_ref <> "(" <> elem_var <> ")"
          }
        })
      option.Some(#(pattern, "#(" <> string.join(body_terms, ", ") <> ")"))
    }
  }
}

fn wire_transform_fn_ref(
  ft: FieldType,
  direction: String,
) -> option.Option(String) {
  case ft {
    UserType(module_path:, type_name:, ..) ->
      option.Some(
        "wire_" <> direction <> "_" <> wire_fn_name(module_path, type_name),
      )
    ListOf(element) ->
      case wire_transform_fn_ref(element, direction) {
        option.None -> option.None
        option.Some(inner_fn) ->
          option.Some("fn(x) { list.map(x, " <> inner_fn <> ") }")
      }
    OptionOf(inner) ->
      case wire_transform_fn_ref(inner, direction) {
        option.None -> option.None
        option.Some(inner_fn) ->
          option.Some("fn(x) { option.map(x, " <> inner_fn <> ") }")
      }
    DictOf(_, value) ->
      case wire_transform_fn_ref(value, direction) {
        option.None -> option.None
        option.Some(inner_fn) ->
          option.Some(
            "fn(d) { dict.map_values(d, fn(_, v) { " <> inner_fn <> "(v) }) }",
          )
      }
    ResultOf(ok, err) -> {
      let ok_fn = wire_transform_fn_ref(ok, direction)
      let err_fn = wire_transform_fn_ref(err, direction)
      case ok_fn, err_fn {
        option.None, option.None -> option.None
        option.Some(ok_f), option.None ->
          option.Some(
            "fn(r) { case r { Ok(v) -> Ok("
            <> ok_f
            <> "(v)) Error(e) -> Error(e) } }",
          )
        option.None, option.Some(err_f) ->
          option.Some(
            "fn(r) { case r { Ok(v) -> Ok(v) Error(e) -> Error("
            <> err_f
            <> "(e)) } }",
          )
        option.Some(ok_f), option.Some(err_f) ->
          option.Some(
            "fn(r) { case r { Ok(v) -> Ok("
            <> ok_f
            <> "(v)) Error(e) -> Error("
            <> err_f
            <> "(e)) } }",
          )
      }
    }
    TupleOf(elements) ->
      case tuple_transform_parts(elements, direction) {
        option.None -> option.None
        option.Some(#(pattern, body)) ->
          option.Some("fn(tup) { let " <> pattern <> " = tup " <> body <> " }")
      }
    _ -> option.None
  }
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
    persistent_term:put({?MODULE, done}, true),
    nil.
"
}
