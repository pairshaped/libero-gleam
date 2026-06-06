//// Protocol-neutral frame type shared by ETF and JSON wire modules.
////
//// Shared by both protocol implementations so ETF and JSON code can use the
//// same frame type without depending on each other.

import gleam/option.{type Option}

/// A decoded server-to-client frame.
///
/// Consumers use this to handle incoming server messages without
/// knowing the frame wire shape (tag bytes for ETF, kind field for JSON).
///
/// The `value` type parameter is typically `Dynamic` at the boundary
/// and narrowed by the consumer with a typed decoder or `coerce`.
///
pub type ServerFrame(value) {
  Response(request_id: Int, value: value)
  Push(module: String, value: value)
  Error(request_id: Option(Int), errors: List(#(String, String)))
}
