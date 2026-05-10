//// Wire-format tests for libero/wire (ETF).
////
//// Encode→decode roundtrips live in wire_roundtrip_test.gleam.
//// This file covers decode_call envelope parsing, error handling,
//// and the encode_call/decode_call symmetric pair.

import gleam/dynamic.{type Dynamic}
import gleam/option.{None, Some}
import libero/error
import libero/wire

pub type TestVariant {
  TestAtom
  TestRecord(value: Int)
}

// ---------- Call envelope decoding (call envelope format: {module, request_id, value}) ----------

pub fn decode_call_with_nil_value_test() {
  // call envelope: {<<"shared/records">>, 1, nil}
  let envelope = encode_call_envelope("shared/records", 1, coerce(Nil))
  let assert Ok(#("shared/records", 1, _value)) = wire.decode_call(envelope)
}

pub fn decode_call_with_int_value_test() {
  // call envelope: {<<"shared/fizzbuzz">>, 2, 15}
  let envelope = encode_call_envelope("shared/fizzbuzz", 2, coerce(15))
  let assert Ok(#("shared/fizzbuzz", 2, value)) = wire.decode_call(envelope)
  let result: Int = unsafe_coerce(value)
  let assert 15 = result
}

pub fn decode_call_with_string_value_test() {
  // call envelope: {<<"shared/records">>, 3, "hello"}
  let envelope = encode_call_envelope("shared/records", 3, coerce("hello"))
  let assert Ok(#("shared/records", 3, value)) = wire.decode_call(envelope)
  let result: String = unsafe_coerce(value)
  let assert "hello" = result
}

pub fn decode_call_invalid_binary_test() {
  let assert Error(error.DecodeError(message: "invalid ETF binary")) =
    wire.decode_call(<<0, 1, 2, 3>>)
}

pub fn decode_call_wrong_shape_test() {
  // Encode a plain integer instead of a {module, request_id, value} tuple
  let bad = ffi_encode(coerce(42))
  let assert Error(error.DecodeError(
    message: "invalid call envelope: expected {binary, integer, value} tuple",
  )) = wire.decode_call(bad)
}

// ---------- Direct encode → decode round-trip ----------
//
// These exercise the public `wire.encode` and `wire.decode` functions
// as a symmetric pair, the way consumers use them for non-RPC paths
// (e.g. passing server-rendered state into a Lustre SPA via flags).
// Distinct from the call-envelope round-trips in wire_roundtrip_test.
// those wrap the value in `{name, args}` and use `decode_call`.

pub fn roundtrip_int_via_decode_test() {
  let result: Int = wire.decode(wire.encode(42))
  let assert 42 = result
}

pub fn roundtrip_string_via_decode_test() {
  let result: String = wire.decode(wire.encode("hello"))
  let assert "hello" = result
}

pub fn roundtrip_bool_via_decode_test() {
  let result: Bool = wire.decode(wire.encode(True))
  let assert True = result
}

pub fn roundtrip_list_via_decode_test() {
  let result: List(Int) = wire.decode(wire.encode([1, 2, 3]))
  let assert [1, 2, 3] = result
}

pub fn roundtrip_option_some_via_decode_test() {
  let result: option.Option(String) = wire.decode(wire.encode(Some("x")))
  let assert Some("x") = result
}

pub fn roundtrip_option_none_via_decode_test() {
  let result: option.Option(Int) = wire.decode(wire.encode(None))
  let assert None = result
}

pub fn roundtrip_tuple_via_decode_test() {
  let result: #(String, Int, Bool) =
    wire.decode(wire.encode(#("session", 42, True)))
  let assert #("session", 42, True) = result
}

pub fn tag_push_prepends_push_frame_tag_test() {
  let assert <<1, 2, 3, 4>> = wire.tag_push(<<2, 3, 4>>)
}

pub fn variant_tag_extracts_zero_arity_constructor_test() {
  let assert Ok("test_atom") = wire.variant_tag(coerce(TestAtom))
}

pub fn variant_tag_extracts_record_constructor_test() {
  let assert Ok("test_record") = wire.variant_tag(coerce(TestRecord(123)))
}

pub fn variant_tag_rejects_plain_tuple_test() {
  let assert Error(Nil) = wire.variant_tag(coerce(#("not_an_atom", 1)))
}

// ---------- High-level frame API ----------

pub fn encode_response_decode_response_frame_roundtrip_test() {
  let frame = wire.encode_response(request_id: 42, value: "hello")
  let assert Ok(wire.Response(request_id: 42, value:)) =
    wire.decode_response_frame(frame)
  let decoded: String = wire.coerce(value)
  let assert "hello" = decoded
}

pub fn encode_response_decode_response_frame_int_test() {
  let frame = wire.encode_response(request_id: 7, value: 99)
  let assert Ok(wire.Response(request_id: 7, value:)) =
    wire.decode_response_frame(frame)
  let decoded: Int = wire.coerce(value)
  let assert 99 = decoded
}

pub fn encode_push_decode_push_frame_roundtrip_test() {
  let frame = wire.encode_push(module: "pages/home", value: "hello push")
  let assert Ok(wire.Push(module: "pages/home", value:)) =
    wire.decode_push_frame(frame)
  let decoded: String = wire.coerce(value)
  let assert "hello push" = decoded
}

pub fn encode_push_decode_push_frame_int_test() {
  let frame = wire.encode_push(module: "core/topic", value: 123)
  let assert Ok(wire.Push(module: "core/topic", value:)) =
    wire.decode_push_frame(frame)
  let decoded: Int = wire.coerce(value)
  let assert 123 = decoded
}

pub fn decode_response_frame_garbage_test() {
  let assert Error(_) = wire.decode_response_frame(<<0, 1, 2, 3>>)
}

pub fn decode_push_frame_garbage_test() {
  let assert Error(_) = wire.decode_push_frame(<<1, 2, 3, 4>>)
}

pub fn decode_response_frame_wrong_tag_test() {
  let frame = wire.tag_push(wire.encode("not a response"))
  let assert Error(_) = wire.decode_response_frame(frame)
}

pub fn decode_push_frame_wrong_tag_test() {
  let frame = wire.tag_response(request_id: 0, data: wire.encode("not a push"))
  let assert Error(_) = wire.decode_push_frame(frame)
}

// ---------- Unified server frame decode ----------

pub fn decode_server_frame_response_test() {
  let frame = wire.encode_response(request_id: 42, value: "hello")
  let assert Ok(wire.Response(request_id: 42, value:)) =
    wire.decode_server_frame(frame)
  let decoded: String = wire.coerce(value)
  let assert "hello" = decoded
}

pub fn decode_server_frame_push_test() {
  let frame = wire.encode_push(module: "pages/home", value: 99)
  let assert Ok(wire.Push(module: "pages/home", value:)) =
    wire.decode_server_frame(frame)
  let decoded: Int = wire.coerce(value)
  let assert 99 = decoded
}

pub fn decode_server_frame_unknown_tag_test() {
  // A frame with tag byte 2 is not a valid server frame
  let assert Error(_) = wire.decode_server_frame(<<2, 0, 0, 0, 1>>)
}

pub fn decode_server_frame_empty_test() {
  let assert Error(_) = wire.decode_server_frame(<<>>)
}

// ---------- SSR flags ----------

pub fn encode_flags_decode_flags_typed_roundtrip_test() {
  let flags = wire.encode_flags("hello")
  let assert Ok("hello") = wire.decode_flags_typed(flags, "ignored_on_erlang")
}

pub fn encode_flags_decode_flags_typed_int_test() {
  let flags = wire.encode_flags(42)
  let assert Ok(42) = wire.decode_flags_typed(flags, "ignored_on_erlang")
}

pub fn encode_flags_decode_flags_typed_tuple_test() {
  let flags = wire.encode_flags(#("a", 1, True))
  let assert Ok(#("a", 1, True)) =
    wire.decode_flags_typed(flags, "ignored_on_erlang")
}

pub fn decode_flags_typed_empty_string_test() {
  let assert Error(_) = wire.decode_flags_typed("", "ignored_on_erlang")
}

pub fn decode_flags_typed_invalid_base64_test() {
  let assert Error(_) =
    wire.decode_flags_typed("!!!not-base64", "ignored_on_erlang")
}

// ---------- Helpers ----------

fn encode_call_envelope(
  module: String,
  request_id: Int,
  value: Dynamic,
) -> BitArray {
  ffi_encode(coerce(#(module, request_id, value)))
}

@external(erlang, "libero_ffi", "encode")
fn ffi_encode(value: Dynamic) -> BitArray

@external(erlang, "gleam_stdlib", "identity")
fn coerce(value: a) -> Dynamic

@external(erlang, "gleam_stdlib", "identity")
fn unsafe_coerce(value: Dynamic) -> a

pub fn encode_call_decode_call_roundtrip_string_test() {
  let encoded =
    wire.encode_call(module: "core/messages", request_id: 10, msg: "hello")
  let assert Ok(#("core/messages", 10, msg)) = wire.decode_call(encoded)
  let decoded: String = wire.coerce(msg)
  let assert "hello" = decoded
}

pub fn encode_call_decode_call_roundtrip_int_test() {
  let encoded =
    wire.encode_call(module: "core/messages", request_id: 20, msg: 42)
  let assert Ok(#("core/messages", 20, msg)) = wire.decode_call(encoded)
  let decoded: Int = wire.coerce(msg)
  let assert 42 = decoded
}

pub fn encode_call_decode_call_roundtrip_tuple_test() {
  let encoded =
    wire.encode_call(module: "my/module", request_id: 30, msg: #("a", 1))
  let assert Ok(#("my/module", 30, msg)) = wire.decode_call(encoded)
  let decoded: #(String, Int) = wire.coerce(msg)
  let assert #("a", 1) = decoded
}
