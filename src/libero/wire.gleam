//// Compatibility wrapper for the old ETF wire module path.

import gleam/dynamic.{type Dynamic}
import libero/error.{type DecodeError}
import libero/etf/wire as etf_wire

pub type ServerFrame(value) =
  etf_wire.ServerFrame(value)

pub fn encode(value: a) -> BitArray {
  etf_wire.encode(value)
}

pub fn decode(data: BitArray) -> a {
  etf_wire.decode(data)
}

pub fn decode_safe(data: BitArray) -> Result(a, DecodeError) {
  etf_wire.decode_safe(data)
}

pub fn decode_typed(
  data data: BitArray,
  decoder_name decoder_name: String,
) -> Result(a, DecodeError) {
  etf_wire.decode_typed(data:, decoder_name:)
}

pub fn decode_request(
  data: BitArray,
) -> Result(#(String, Int, Dynamic), DecodeError) {
  etf_wire.decode_request(data)
}

pub fn encode_request(
  module module: String,
  request_id request_id: Int,
  msg msg: a,
) -> BitArray {
  etf_wire.encode_request(module:, request_id:, msg:)
}

pub fn tag_response(
  request_id request_id: Int,
  data data: BitArray,
) -> BitArray {
  etf_wire.tag_response(request_id:, data:)
}

pub fn tag_push(data: BitArray) -> BitArray {
  etf_wire.tag_push(data)
}

pub fn encode_response(request_id request_id: Int, value value: a) -> BitArray {
  etf_wire.encode_response(request_id:, value:)
}

pub fn encode_push(module module: String, value value: a) -> BitArray {
  etf_wire.encode_push(module:, value:)
}

pub fn decode_response_frame(
  data: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  etf_wire.decode_response_frame(data)
}

pub fn decode_push_frame(
  data: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  etf_wire.decode_push_frame(data)
}

pub fn decode_server_frame(
  data: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  etf_wire.decode_server_frame(data)
}

pub fn encode_flags(value: a) -> String {
  etf_wire.encode_flags(value)
}

pub fn decode_flags_typed(
  flags flags: String,
  decoder_name decoder_name: String,
) -> Result(a, DecodeError) {
  etf_wire.decode_flags_typed(flags:, decoder_name:)
}

pub fn variant_tag(value: Dynamic) -> Result(String, Nil) {
  etf_wire.variant_tag(value)
}

pub fn coerce(value: a) -> b {
  etf_wire.coerce(value)
}
