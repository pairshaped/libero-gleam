//// Error envelope for Libero RPC responses.
////
//// Every RPC response is shaped as `Result(T, RpcError)`. The wire
//// carries this envelope uniformly regardless of the server function's
//// return type.
////
//// ## Two categories of failure
////
//// 1. Framework errors (`MalformedRequest`, `UnknownFunction`) are
////    errors in the RPC layer itself. The request was garbage or
////    named a function that doesn't exist. Usually deployment skew
////    or a client-side bug.
////
//// 2. Internal errors (`InternalError(trace_id, message)`) are
////    unexpected runtime panics caught by the dispatch layer. The
////    `trace_id` is opaque to the client; the full panic details
////    are logged server-side under that id. The `message` field
////    contains a client-safe string suitable for display to end
////    users without exposing internal details.

/// Wire-level decode failure. Returned by `wire.decode_safe` when the
/// input is not valid ETF or cannot be reconstructed.
pub type DecodeError {
  DecodeError(message: String)
}

/// The error envelope for every Libero RPC response.
pub type RpcError {
  /// The server couldn't parse the incoming request envelope.
  MalformedRequest

  /// The named RPC function doesn't exist in the server's dispatch
  /// table. Usually deployment skew or a client-side typo.
  UnknownFunction(name: String)

  /// The server function panicked while processing the request.
  /// The real details are logged server-side under this `trace_id`.
  /// The `message` field contains a client-safe string suitable for
  /// display to end users (e.g. "Something went wrong, please try
  /// again"). Consumers can override it in their error-display logic
  /// or use it as-is.
  InternalError(trace_id: String, message: String)
}
