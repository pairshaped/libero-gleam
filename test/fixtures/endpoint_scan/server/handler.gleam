// Fixture for endpoint scanner tests.
// Covers each criterion the v6 scanner enforces:
// 1. Public function
// 2. Name starts with server_
// 3. Has a parameter typed as the configured context type
// 4. Return type is Result(ok, err) or #(Result(ok, err), ContextType)

import gleam/dict.{type Dict}

pub type HandlerContext {
  HandlerContext
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
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(List(Item), ItemError), HandlerContext) {
  #(Ok([]), handler_ctx)
}

pub fn server_create_item(
  params _params: ItemParams,
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Item, ItemError), HandlerContext) {
  #(Error(NotFound), handler_ctx)
}

pub fn server_delete_item(
  id id: Int,
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Int, ItemError), HandlerContext) {
  #(Ok(id), handler_ctx)
}

pub fn server_lookup_items(
  ids _ids: Dict(String, Int),
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Dict(String, Item), ItemError), HandlerContext) {
  #(Ok(dict.new()), handler_ctx)
}

// Criterion 1 missing: private function.
fn server_internal_helper(
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Int, ItemError), HandlerContext) {
  #(Ok(0), handler_ctx)
}

// Criterion 2 missing: no server_ prefix.
pub fn utility_function(x x: Int) -> Int {
  x + 1
}

// Criterion 3 missing: no HandlerContext parameter.
pub fn server_no_context(x x: Int) -> Result(Int, Nil) {
  Ok(x)
}

// Bare-Result handler shape: read-only handlers may return Result(_, _)
// directly. The scanner treats this as equivalent to the tuple shape with
// an unchanged HandlerContext.
pub fn server_process_items(
  handler_ctx _handler_ctx: HandlerContext,
) -> Result(List(Item), ItemError) {
  Ok([])
}

pub fn server_search_items(
  query _query: String,
  handler_ctx _handler_ctx: HandlerContext,
) -> Result(List(Item), ItemError) {
  Ok([])
}

// HandlerContext in wrong position in return tuple.
pub fn server_wrong_order(
  handler_ctx handler_ctx: HandlerContext,
) -> #(HandlerContext, Result(Int, ItemError)) {
  #(handler_ctx, Ok(0))
}

// Response is not Result(_, _).
pub fn server_ping(
  handler_ctx handler_ctx: HandlerContext,
) -> #(String, HandlerContext) {
  #("pong", handler_ctx)
}

// With non-shared types (still valid in v6 since shared constraint removed).
pub fn server_get_audit_log(
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(AuditLog, ItemError), HandlerContext) {
  #(Ok(AuditLog), handler_ctx)
}

pub fn server_log_action(
  action _action: AuditEntry,
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Nil, ItemError), HandlerContext) {
  #(Ok(Nil), handler_ctx)
}

// Touch the unused private helper so Gleam doesn't warn.
pub fn touch_internal_helper(handler_ctx handler_ctx: HandlerContext) -> Nil {
  let _ = server_internal_helper(handler_ctx:)
  Nil
}
