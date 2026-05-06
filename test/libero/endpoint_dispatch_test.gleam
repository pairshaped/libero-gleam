import birdie
import gleam/option
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
