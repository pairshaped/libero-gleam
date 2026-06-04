//// Tests for wire.decode_safe - the Result-returning decoder.

import gleam/string
import libero/error
import libero/etf/wire

@external(erlang, "libero_test_ffi", "encoded_pid")
fn encoded_pid() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_ref")
fn encoded_ref() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_fun")
fn encoded_fun() -> BitArray

@external(erlang, "libero_test_ffi", "encoded_port")
fn encoded_port() -> BitArray

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

pub fn decode_safe_rejects_pid_test() {
  let result: Result(Int, error.DecodeError) = wire.decode_safe(encoded_pid())
  let assert Error(error.DecodeError(message: message)) = result
  let assert True = string.contains(message, "non_executable_term")
  let assert True = string.contains(message, "pid")
}

pub fn decode_safe_rejects_ref_test() {
  let result: Result(Int, error.DecodeError) = wire.decode_safe(encoded_ref())
  let assert Error(error.DecodeError(message: message)) = result
  let assert True = string.contains(message, "non_executable_term")
  let assert True = string.contains(message, "reference")
}

pub fn decode_safe_rejects_fun_test() {
  let result: Result(Int, error.DecodeError) = wire.decode_safe(encoded_fun())
  let assert Error(error.DecodeError(message: message)) = result
  let assert True = string.contains(message, "non_executable_term")
  let assert True = string.contains(message, "function")
}

pub fn decode_safe_rejects_port_test() {
  let result: Result(Int, error.DecodeError) = wire.decode_safe(encoded_port())
  let assert Error(error.DecodeError(message: message)) = result
  let assert True = string.contains(message, "non_executable_term")
  let assert True = string.contains(message, "port")
}
