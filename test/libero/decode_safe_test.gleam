//// Tests for wire.decode_safe - the Result-returning decoder.

import libero/error
import libero/etf/wire

@external(erlang, "libero_test_ffi", "encoded_unknown_atom")
fn encoded_unknown_atom() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_trailing_bytes")
fn encoded_trailing_bytes() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_declared_large_tuple")
fn encoded_declared_large_tuple() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_declared_large_list")
fn encoded_declared_large_list() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_declared_large_binary")
fn encoded_declared_large_binary() -> BitArray

pub fn decode_safe_valid_int_test() {
  let encoded = wire.encode(42)
  let result: Result(Int, error.DecodeError) = wire.decode_safe(encoded)
  let assert Ok(42) = result
}

pub fn decode_safe_valid_string_test() {
  let encoded = wire.encode("hello")
  let result: Result(String, error.DecodeError) = wire.decode_safe(encoded)
  let assert Ok("hello") = result
}

pub fn decode_safe_valid_list_test() {
  let encoded = wire.encode([1, 2, 3])
  let result: Result(List(Int), error.DecodeError) = wire.decode_safe(encoded)
  let assert Ok([1, 2, 3]) = result
}

pub fn decode_safe_garbage_input_test() {
  let result: Result(Int, error.DecodeError) = wire.decode_safe(<<0, 1, 2, 3>>)
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_empty_input_test() {
  let result: Result(Int, error.DecodeError) = wire.decode_safe(<<>>)
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_truncated_etf_test() {
  // Valid ETF version byte (131) followed by incomplete data
  let result: Result(Int, error.DecodeError) = wire.decode_safe(<<131>>)
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_rejects_unknown_atom_test() {
  let result: Result(Int, error.DecodeError) =
    wire.decode_safe(encoded_unknown_atom())
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_rejects_trailing_bytes_test() {
  let result: Result(Int, error.DecodeError) =
    wire.decode_safe(encoded_trailing_bytes())
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_rejects_declared_large_tuple_test() {
  let result: Result(Int, error.DecodeError) =
    wire.decode_safe(encoded_declared_large_tuple())
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_rejects_declared_large_list_test() {
  let result: Result(Int, error.DecodeError) =
    wire.decode_safe(encoded_declared_large_list())
  let assert Error(error.DecodeError(message: _)) = result
}

pub fn decode_safe_rejects_declared_large_binary_test() {
  let result: Result(Int, error.DecodeError) =
    wire.decode_safe(encoded_declared_large_binary())
  let assert Error(error.DecodeError(message: _)) = result
}
