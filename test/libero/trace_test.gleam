//// Tests for libero/trace - the panic-catching + trace_id primitives.
////
//// These are the building blocks behind the generated dispatch's
//// panic handling: every dispatch call runs inside try_call, and a
//// panic surfaces to the consumer as an InternalError envelope
//// tagged with a fresh trace_id.

import gleam/string
import libero/trace

// ---------- try_call ----------

pub fn try_call_success_returns_ok_test() {
  let assert Ok(42) = trace.try_call(fn() { 42 })
}

pub fn try_call_returns_value_verbatim_test() {
  let assert Ok("hello") = trace.try_call(fn() { "hello" })
}

pub fn try_call_catches_explicit_panic_test() {
  let result = trace.try_call(fn() { panic as "you asked for it" })
  let assert Error(reason) = result
  // The stringified Erlang exception mentions the panic message
  // somewhere in its body; we assert containment rather than
  // equality because the exact format includes file/line metadata
  // that changes across Gleam versions.
  let assert True = string.contains(reason, "you asked for it")
}

pub fn try_call_catches_division_by_zero_test() {
  // Gleam's / operator on integers is defined to return 0 on
  // division by zero (deliberately total), so this tests that
  // SUCCESSFUL integer division through a function body still
  // comes back as Ok - it should not be mistaken for a panic.
  let assert Ok(0) = trace.try_call(fn() { 10 / 0 })
}

// ---------- new_trace_id ----------
//
// The ID is a short unique string built from a monotonic counter and
// system time, formatted as "<time>-<counter>" in base-16 (Erlang) or
// base-36 (JavaScript). Unique enough for log correlation; not
// cryptographically random.

pub fn new_trace_id_is_non_empty_test() {
  let id = trace.new_trace_id()
  let assert True = string.length(id) > 0
}

pub fn new_trace_id_has_dash_separator_test() {
  let id = trace.new_trace_id()
  let assert True = string.contains(id, "-")
}

pub fn new_trace_id_is_unique_test() {
  let id1 = trace.new_trace_id()
  let id2 = trace.new_trace_id()
  let assert False = id1 == id2
}
