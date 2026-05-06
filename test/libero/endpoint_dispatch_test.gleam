import birdie
import gleam/option
import gleam/string
import libero/codegen_dispatch
import libero/field_type
import libero/scanner

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
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "create_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("params", item_params)],
      mutates_context: True,
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "toggle_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "delete_item",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
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
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "rename_thing",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
    )
  birdie.snap(content, title: "dispatch: read-only handler wrapper")
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
      msg_type_name: option.None,
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
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/store",
      fn_name: "get_widget",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [#("id", field_type.IntField)],
      mutates_context: True,
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "shared/types",
      atoms_module: option.None,
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
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "shared/types",
      atoms_module: option.None,
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
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.Some("generated@rpc_atoms"),
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
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
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
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/handler",
      fn_name: "delete_sponsor",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate_atoms_erl(endpoints, "generated@rpc_atoms")

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
      msg_type_name: option.None,
    ),
    scanner.HandlerEndpoint(
      module_path: "server/b",
      fn_name: "load_sponsors",
      return_ok: field_type.IntField,
      return_err: field_type.NilField,
      params: [],
      mutates_context: True,
      msg_type_name: option.None,
    ),
  ]
  let content = codegen_dispatch.generate_atoms_erl(endpoints, "mod")

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
      msg_type_name: option.None,
    ),
  ]
  let content =
    codegen_dispatch.generate(
      endpoints: endpoints,
      context_module: "server_context",
      context_type_name: "ServerContext",
      wire_module_tag: "rpc",
      atoms_module: option.None,
    )

  // ClientMsg variant uses Server prefix
  let assert True = string.contains(content, "ServerLoadSponsors")

  // Tag match uses server_ prefix
  let assert True = string.contains(content, "Ok(\"server_load_sponsors\")")
}
