//// Protocol-neutral frame type shared by ETF and JSON wire modules.
////
//// Moved here from `libero/wire.gleam` so both protocol implementations
//// can import it without creating a dependency from ETF onto JSON types.

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
