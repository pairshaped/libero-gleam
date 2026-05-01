//// Panic-catching + trace_id primitives for the dispatch layer.
////
//// `try_call(action)` runs a zero-arg function inside an Erlang
//// try/catch and returns `Ok(result)` on success or `Error(reason)`
//// where `reason` is the stringified exception.
////
//// `new_trace_id()` returns a short unique string built from a
//// monotonic counter and system time, suitable for correlating log
//// lines with RPC error responses. Unique enough for debugging;
//// not cryptographically random.
////
//// **Logging is intentionally not part of this module.** Libero stays
//// free of wisp/logging dependencies so it can be used in any
//// Erlang-target consumer. The generated dispatch code uses
//// `io.println_error` as a default logger; consumers that want
//// structured logging can wrap the primitives in their own module.

/// Run the given function, catching any panic. Returns the result on
/// success; on failure, returns the stringified exception reason.
/// Callers typically pair this with a trace id from `new_trace_id` and
/// log both under a single correlation id.
/// nolint: stringly_typed_error -- wraps OTP catch; exception reason is inherently a string
pub fn try_call(action: fn() -> a) -> Result(a, String) {
  do_try_call(action)
}

/// Generate a unique trace id for log correlation. Uses
/// `erlang:unique_integer` on Erlang and a counter + `Date.now()` on
/// JavaScript. Unique enough for debugging; not cryptographically
/// random.
pub fn new_trace_id() -> String {
  unique_id()
}

@external(erlang, "libero_ffi", "unique_id")
@external(javascript, "./libero_ffi.mjs", "uniqueId")
fn unique_id() -> String

// Note: there's no catch_panic convenience wrapper here. The
// generated dispatch code handles panics inline by calling
// `try_call` + `new_trace_id` and bubbling a `PanicInfo` value up
// through its return type. This keeps libero free of any logging
// dependency. Consumers decide what to do with panic info in their
// WebSocket handler, not in library code.

// nolint: stringly_typed_error
@external(erlang, "libero_ffi", "try_call")
fn do_try_call(action: fn() -> a) -> Result(a, String)
