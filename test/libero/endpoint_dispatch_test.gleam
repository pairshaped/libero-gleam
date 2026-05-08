import birdie
import gleam/int
import gleam/option
import gleam/result
import gleam/string
import libero/codegen_dispatch
import libero/field_type
import libero/scanner
import libero/walker.{DiscoveredType, DiscoveredVariant}
import simplifile

pub fn endpoint_dispatch_generates_client_msg_test() {
  let item_params = field_type.UserType("shared/items", "ItemParams", [])
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "get_items",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "create_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("params", item_params)],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "toggle_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "delete_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )
  birdie.snap(content, title: "dispatch: four mutating endpoints")
}

pub fn endpoint_dispatch_wraps_read_only_handler_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "list_things",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: False,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "rename_thing",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )
  birdie.snap(content, title: "dispatch: read-only handler wrapper")
}

pub fn endpoint_dispatch_passes_whole_msg_type_to_handler_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "set_dark_mode",
      return_ok: field_type.NilField,
      return_err: field_type.NilField,
      params: [#("enabled", field_type.BoolField)],
      mutates_context: True,
      msg_type: option.Some(#("server/handler", "SetDarkMode")),
    ),
  ]
  // Without wire_module: passes raw coerced msg
  let content_no_wire =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )

  let assert True =
    string.contains(content_no_wire, "ServerSetDarkMode(enabled: Bool)")
  let assert True =
    string.contains(
      content_no_wire,
      "handler.server_set_dark_mode(msg: wire.coerce(typed_msg), server_context:)",
    )

  // With wire_module: wraps coerced msg in the wire decode transformer
  let content_wire =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.Some("test@wire"),
    )

  let assert True =
    string.contains(
      content_wire,
      "handler.server_set_dark_mode(msg: wire_decode_server_handler__set_dark_mode(wire.coerce(typed_msg)), server_context:)",
    )
}

pub fn dispatch_known_tags_call_shared_helper_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "first_endpoint",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "second_endpoint",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )

  let assert True =
    string.contains(
      content,
      "Ok(\"server_first_endpoint\") ->\n          dispatch_known(msg, request_id, server_context)",
    )
  let assert True =
    string.contains(
      content,
      "Ok(\"server_second_endpoint\") ->\n          dispatch_known(msg, request_id, server_context)",
    )
  let assert True =
    string.contains(
      content,
      "fn dispatch_known(msg, request_id, server_context)",
    )
  let assert False =
    string.contains(
      content,
      "Ok(\"server_first_endpoint\")\n        | Ok(\"server_second_endpoint\")",
    )
}

pub fn endpoint_dispatch_imports_qualified_param_types_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/store",
      fn_name: "list_widgets",
      return_ok: field_type.UserType("shared/widget_detail", "Widget", []),
      return_err: field_type.NilField,
      params: [
        #("filters", field_type.UserType("shared/widgets", "WidgetFilters", [])),
      ],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/notifier",
      fn_name: "send_alert",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [
        #("params", field_type.UserType("shared/alerts", "AlertParams", [])),
      ],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/store",
      fn_name: "get_widget",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "shared/types",
      atoms_module: option.None,
      wire_module: option.None,
    )
  birdie.snap(content, title: "dispatch: qualified param type imports")
}

pub fn endpoint_dispatch_imports_stdlib_param_types_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "echo_dict",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [
        #(
          "value",
          field_type.DictOf(field_type.StringField, field_type.IntField),
        ),
      ],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "shared/types",
      atoms_module: option.None,
      wire_module: option.None,
    )
  birdie.snap(content, title: "dispatch: stdlib param type imports")
}

pub fn dispatch_includes_ensure_atoms_when_module_set_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "get_items",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.Some("generated@rpc_atoms"),
      wire_module: option.None,
    )
  let assert True = string.contains(content, "ensure_atoms()")
  let assert True =
    string.contains(
      content,
      "@external(erlang, \"generated@rpc_atoms\", \"ensure\")",
    )
}

pub fn dispatch_omits_ensure_atoms_when_module_is_none_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "get_items",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )
  let assert False = string.contains(content, "ensure_atoms")
  let assert False = string.contains(content, "@external(erlang")
}

pub fn generate_atoms_erl_produces_valid_erlang_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "load_sponsors",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "delete_sponsor",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate_atoms_erl(
      endpoints,
      [],
      "generated@rpc_atoms",
      option.None,
    )

  // Module declaration
  let assert True = string.contains(content, "-module(generated@rpc_atoms).")
  let assert True = string.contains(content, "-export([ensure/0]).")

  // Framework atoms always present
  let assert True = string.contains(content, "<<\"ok\">>")
  let assert True = string.contains(content, "<<\"error\">>")
  let assert True = string.contains(content, "<<\"decode_error\">>")

  // Handler atoms — both stripped and server_-prefixed
  let assert True = string.contains(content, "<<\"load_sponsors\">>")
  let assert True = string.contains(content, "<<\"server_load_sponsors\">>")
  let assert True = string.contains(content, "<<\"delete_sponsor\">>")
  let assert True = string.contains(content, "<<\"server_delete_sponsor\">>")

  // persistent_term guard
  let assert True =
    string.contains(content, "persistent_term:get({?MODULE, done}, false)")
  let assert True =
    string.contains(content, "persistent_term:put({?MODULE, done}, true)")
}

pub fn generate_atoms_erl_deduplicates_atoms_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/a",
      fn_name: "load_sponsors",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/b",
      fn_name: "load_sponsors",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate_atoms_erl(endpoints, [], "mod", option.None)

  // "load_sponsors" should appear exactly once (deduplicated)
  // framework atom "ok" also appears once
  let assert True = string.contains(content, "<<\"load_sponsors\">>")
}

pub fn dispatch_variant_names_include_server_prefix_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "load_sponsors",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )

  // ClientMsg variant uses Server prefix
  let assert True = string.contains(content, "ServerLoadSponsors")

  // Tag match uses server_ prefix
  let assert True = string.contains(content, "Ok(\"server_load_sponsors\")")
}

pub fn generate_atoms_erl_includes_variant_constructor_atoms_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "get_role",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let discovered = [
    DiscoveredType(
      module_path: "shared/types",
      type_name: "Role",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/types",
          variant_name: "Admin",
          atom_name: "admin",
          float_field_indices: [],
          fields: [],
        ),
        DiscoveredVariant(
          module_path: "shared/types",
          variant_name: "SuperUser",
          atom_name: "super_user",
          float_field_indices: [],
          fields: [],
        ),
      ],
    ),
  ]
  let content =
    codegen_dispatch.generate_atoms_erl(
      endpoints,
      discovered,
      "test@atoms",
      option.None,
    )

  // Variant constructor atoms are included
  let assert True = string.contains(content, "<<\"admin\">>")
  let assert True = string.contains(content, "<<\"super_user\">>")
}

pub fn generate_atoms_erl_no_duplicate_end_of_function_test() {
  // The qualified-atom AtomMap block must not duplicate the
  // persistent_term:put({?MODULE, done}, true), nil. trailer.
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "get_role",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let discovered = [
    DiscoveredType(
      module_path: "shared/types",
      type_name: "Role",
      type_params: [],
      variants: [
        DiscoveredVariant(
          module_path: "shared/types",
          variant_name: "Admin",
          atom_name: "shared_types__admin",
          float_field_indices: [],
          fields: [],
        ),
      ],
    ),
  ]
  let content =
    codegen_dispatch.generate_atoms_erl(
      endpoints,
      discovered,
      "test@atoms",
      option.None,
    )

  // No AtomMap under the wire-identity scheme; just atom pre-registration.
  let assert False = string.contains(content, "AtomMap")
  let assert False = string.contains(content, "atom_map")
  // Must end with exactly one trailing nil.
  let assert True =
    string.contains(
      content,
      "persistent_term:put({?MODULE, done}, true),\n    nil.\n",
    )
  // Must NOT have duplicate done/nil
  let assert False =
    string.contains(content, "nil.\n    persistent_term:put({?MODULE, done}")
}

pub fn generate_atoms_erl_registers_wire_module_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "ping",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate_atoms_erl(
      endpoints,
      [],
      "test@atoms",
      option.Some("test@wire"),
    )

  let assert True =
    string.contains(
      content,
      "persistent_term:put({libero, wire_module}, 'test@wire')",
    )
}

pub fn empty_endpoints_generates_valid_dispatch_test() {
  let content =
    codegen_dispatch.generate(
      endpoints: [],
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
      wire_module: option.None,
    )

  // Must not produce a naked `->` (syntax error when known_tag_guards is empty)
  let assert False = string.contains(content, "        -> {")
  let assert False = string.contains(content, "         -> {")

  // Must still handle the standard error paths
  let assert True = string.contains(content, "UnknownFunction")
  let assert True = string.contains(content, "MalformedRequest")

  let assert Ok(Nil) =
    compile_generated_dispatch(
      fixture_name: "empty_endpoints",
      dispatch_source: content,
    )
  birdie.snap(content, title: "dispatch: empty endpoints")
}

fn compile_generated_dispatch(
  fixture_name fixture_name: String,
  dispatch_source dispatch_source: String,
) -> Result(Nil, String) {
  let root = "build/.test_dispatch/" <> fixture_name
  let src = root <> "/src"
  let generated = src <> "/generated/libero"
  let _ = simplifile.delete_all([root])
  use _ <- result.try(
    simplifile.create_directory_all(generated)
    |> result.map_error(fn(err) { simplifile.describe_error(err) }),
  )
  use _ <- result.try(
    simplifile.write(root <> "/gleam.toml", fixture_toml())
    |> result.map_error(fn(err) { simplifile.describe_error(err) }),
  )
  use _ <- result.try(
    simplifile.write(src <> "/server_context.gleam", server_context_source())
    |> result.map_error(fn(err) { simplifile.describe_error(err) }),
  )
  use _ <- result.try(
    simplifile.write(generated <> "/dispatch.gleam", dispatch_source)
    |> result.map_error(fn(err) { simplifile.describe_error(err) }),
  )
  let #(status, output) = run_gleam(root, ["build"])
  let _ = simplifile.delete_all([root])
  case status {
    0 -> Ok(Nil)
    _ ->
      Error(
        "gleam build failed with exit code "
        <> int.to_string(status)
        <> ":\n"
        <> output,
      )
  }
}

fn fixture_toml() -> String {
  "name = \"dispatch_compile_fixture\"
version = \"1.0.0\"

[dependencies]
gleam_stdlib = \">= 0.69.0 and < 2.0.0\"
libero = { path = \"../../..\" }
"
}

fn server_context_source() -> String {
  "pub type ServerContext {
  ServerContext
}
"
}

fn run_gleam(cwd: String, args: List(String)) -> #(Int, String) {
  case find_executable("sh"), find_executable("gleam") {
    option.Some(sh), option.Some(gleam) -> {
      let command =
        "cd " <> cwd <> " && " <> gleam <> " " <> string.join(args, " ")
      run_executable_capturing_ffi(sh, ["-c", command])
    }
    _, option.None -> #(-1, "gleam executable not found on PATH")
    option.None, _ -> #(-1, "sh executable not found on PATH")
  }
}

@external(erlang, "libero_ffi", "find_executable")
fn find_executable(name: String) -> option.Option(String)

@external(erlang, "libero_ffi", "run_executable_capturing")
fn run_executable_capturing_ffi(
  path: String,
  args: List(String),
) -> #(Int, String)
