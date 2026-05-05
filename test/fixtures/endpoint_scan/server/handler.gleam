// Fixture for endpoint scanner tests.
// Covers each criterion the v6 scanner enforces:
// 1. Public function
// 2. Name starts with server_
// 3. Has a parameter typed as the configured context type
// 4. Return type is Result(ok, err) or #(Result(ok, err), ContextType)

import gleam/dict.{type Dict}

pub type ServerContext {
  ServerContext
}

pub type Item {
  Item(id: Int, name: String)
}

pub type ItemParams {
  ItemParams(name: String)
}

pub type ItemError {
  NotFound
  Invalid
}

pub type AuditLog {
  AuditLog
}

pub type AuditEntry {
  AuditEntry
}

// All criteria met.

pub fn server_get_items(
  server_ctx server_ctx: ServerContext,
) -> #(Result(List(Item), ItemError), ServerContext) {
  #(Ok([]), server_ctx)
}

pub fn server_create_item(
  params _params: ItemParams,
  server_ctx server_ctx: ServerContext,
) -> #(Result(Item, ItemError), ServerContext) {
  #(Error(NotFound), server_ctx)
}

pub fn server_delete_item(
  id id: Int,
  server_ctx server_ctx: ServerContext,
) -> #(Result(Int, ItemError), ServerContext) {
  #(Ok(id), server_ctx)
}

pub fn server_lookup_items(
  ids _ids: Dict(String, Int),
  server_ctx server_ctx: ServerContext,
) -> #(Result(Dict(String, Item), ItemError), ServerContext) {
  #(Ok(dict.new()), server_ctx)
}

// Criterion 1 missing: private function.
fn server_internal_helper(
  server_ctx server_ctx: ServerContext,
) -> #(Result(Int, ItemError), ServerContext) {
  #(Ok(0), server_ctx)
}

// Criterion 2 missing: no server_ prefix.
pub fn utility_function(x x: Int) -> Int {
  x + 1
}

// Criterion 3 missing: no ServerContext parameter.
pub fn server_no_context(x x: Int) -> Result(Int, Nil) {
  Ok(x)
}

// Bare-Result handler shape: read-only handlers may return Result(_, _)
// directly. The scanner treats this as equivalent to the tuple shape with
// an unchanged ServerContext.
pub fn server_process_items(
  server_ctx _server_ctx: ServerContext,
) -> Result(List(Item), ItemError) {
  Ok([])
}

pub fn server_search_items(
  query _query: String,
  server_ctx _server_ctx: ServerContext,
) -> Result(List(Item), ItemError) {
  Ok([])
}

// ServerContext in wrong position in return tuple.
pub fn server_wrong_order(
  server_ctx server_ctx: ServerContext,
) -> #(ServerContext, Result(Int, ItemError)) {
  #(server_ctx, Ok(0))
}

// Response is not Result(_, _).
pub fn server_ping(
  server_ctx server_ctx: ServerContext,
) -> #(String, ServerContext) {
  #("pong", server_ctx)
}

// With non-shared types (still valid in v6 since shared constraint removed).
pub fn server_get_audit_log(
  server_ctx server_ctx: ServerContext,
) -> #(Result(AuditLog, ItemError), ServerContext) {
  #(Ok(AuditLog), server_ctx)
}

pub fn server_log_action(
  action _action: AuditEntry,
  server_ctx server_ctx: ServerContext,
) -> #(Result(Nil, ItemError), ServerContext) {
  #(Ok(Nil), server_ctx)
}

// Touch the unused private helper so Gleam doesn't warn.
pub fn touch_internal_helper(server_ctx server_ctx: ServerContext) -> Nil {
  let _ = server_internal_helper(server_ctx:)
  Nil
}
