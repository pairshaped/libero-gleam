import gleam/list
import gleam/option
import libero/field_type
import libero/gen_error
import libero/scanner
import simplifile

// v6 criteria for an RPC endpoint:
// 1. Public function
// 2. Name starts with server_
// 3. Has a parameter typed as the configured context type
// 4. Return type is Result(ok, err) or #(Result(ok, err), ContextType)

/// Missing criterion 1: private function
pub fn excludes_private_function_test() {
  let names = scan_fixture_names()
  let assert False = list.contains(names, "internal_helper")
}

/// Missing criterion 2: no server_ prefix
pub fn excludes_no_prefix_test() {
  let names = scan_fixture_names()
  let assert False = list.contains(names, "utility_function")
}

/// Missing criterion 3: no context parameter
pub fn excludes_no_context_param_test() {
  let names = scan_fixture_names()
  let assert False = list.contains(names, "no_context")
}

/// Bare-Result handler shape is accepted (criterion 4b).
pub fn includes_bare_result_handler_test() {
  let names = scan_fixture_names()
  let assert True = list.contains(names, "process_items")
  let assert True = list.contains(names, "search_items")
}

/// Bare-Result handlers carry the read-only marker so codegen can wrap them.
pub fn bare_result_handler_marked_read_only_test() {
  let endpoints = scan_fixture_endpoints()
  let assert Ok(process_items) =
    list.find(endpoints, fn(e) { e.fn_name == "process_items" })
  let assert False = process_items.mutates_context

  let assert Ok(get_items) =
    list.find(endpoints, fn(e) { e.fn_name == "get_items" })
  let assert True = get_items.mutates_context
}

/// ServerContext in wrong position in return tuple
pub fn excludes_wrong_return_order_test() {
  let names = scan_fixture_names()
  let assert False = list.contains(names, "wrong_order")
}

/// Response is not Result(_, _)
pub fn excludes_non_result_response_test() {
  let names = scan_fixture_names()
  let assert False = list.contains(names, "ping")
}

/// All criteria met = included
pub fn includes_valid_endpoints_test() {
  let names = scan_fixture_names()
  let assert True = list.contains(names, "get_items")
  let assert True = list.contains(names, "create_item")
  let assert True = list.contains(names, "delete_item")
}

/// Dict is a builtin and must not cause valid endpoints to be filtered out.
pub fn includes_dict_typed_endpoint_test() {
  let names = scan_fixture_names()
  let assert True = list.contains(names, "lookup_items")
}

/// Non-shared types are now accepted (v6 removed the shared constraint).
pub fn includes_non_shared_type_endpoint_test() {
  let names = scan_fixture_names()
  let assert True = list.contains(names, "get_audit_log")
  let assert True = list.contains(names, "log_action")
}

pub fn resolves_cross_module_msg_type_fields_test() {
  let dir = "build/.test_cross_module_msg_type"
  let server_dir = dir <> "/src/server"
  let shared_dir = dir <> "/src/shared"
  let assert Ok(Nil) = simplifile.create_directory_all(server_dir)
  let assert Ok(Nil) = simplifile.create_directory_all(shared_dir)

  let assert Ok(Nil) =
    simplifile.write(
      shared_dir <> "/messages.gleam",
      "pub type SetDarkMode {
  SetDarkMode(enabled: Bool)
}
",
    )
  let assert Ok(Nil) =
    simplifile.write(
      shared_dir <> "/settings.gleam",
      "pub type SetTheme {
  SetTheme(name: String)
}
",
    )
  let assert Ok(Nil) =
    simplifile.write(
      server_dir <> "/handlers.gleam",
      "import shared/messages.{type SetDarkMode}
import shared/settings

pub type ServerContext {
  ServerContext
}

pub fn server_set_dark_mode(
  msg msg: SetDarkMode,
  server_context server_context: ServerContext,
) -> #(Result(Nil, Nil), ServerContext) {
  #(Ok(Nil), server_context)
}

pub fn server_set_theme(
  msg msg: settings.SetTheme,
  server_context server_context: ServerContext,
) -> #(Result(Nil, Nil), ServerContext) {
  #(Ok(Nil), server_context)
}
",
    )

  let assert Ok(endpoints) =
    scanner.scan(src_dir: dir <> "/src", context_type_name: "ServerContext")
  let assert Ok(set_dark_mode) =
    list.find(endpoints, fn(e) { e.fn_name == "set_dark_mode" })
  let assert Ok(set_theme) =
    list.find(endpoints, fn(e) { e.fn_name == "set_theme" })

  let assert option.Some("SetDarkMode") = set_dark_mode.msg_type_name
  let assert [#("enabled", field_type.BoolField)] = set_dark_mode.params
  let assert option.Some("SetTheme") = set_theme.msg_type_name
  let assert [#("name", field_type.StringField)] = set_theme.params

  let assert Ok(Nil) = simplifile.delete_all([dir])
}

fn scan_fixture_endpoints() -> List(scanner.HandlerEndpoint) {
  let assert Ok(endpoints) =
    scanner.scan(
      src_dir: "test/fixtures/endpoint_scan/server",
      context_type_name: "ServerContext",
    )
  endpoints
}

fn scan_fixture_names() -> List(String) {
  list.map(scan_fixture_endpoints(), fn(e) { e.fn_name })
}

/// Two handler files exporting the same function name (after prefix strip)
/// would compile into duplicate ClientMsg variants. The scanner surfaces this
/// as a libero-level error.
pub fn rejects_duplicate_fn_name_across_modules_test() {
  let dir = "build/.test_duplicate_fn_names"
  let server_dir = dir <> "/server"
  let assert Ok(Nil) = simplifile.create_directory_all(server_dir)

  let make_handler = fn(file: String) -> Nil {
    let assert Ok(Nil) =
      simplifile.write(
        server_dir <> "/" <> file <> ".gleam",
        "pub type ServerContext { ServerContext }

pub fn server_get_items(
  ctx ctx: ServerContext,
) -> Result(Int, Nil) {
  Ok(0)
}
",
      )
    Nil
  }
  make_handler("a")
  make_handler("b")

  let assert Error(errors) =
    scanner.scan(src_dir: server_dir, context_type_name: "ServerContext")
  let assert [gen_error.DuplicateEndpoint(fn_name: "get_items", modules:)] =
    errors
  let assert True = list.length(modules) == 2

  let assert Ok(Nil) = simplifile.delete_all([dir])
}
