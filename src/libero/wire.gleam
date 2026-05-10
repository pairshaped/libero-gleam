//// Wire codec for Libero RPC.
////
//// Libero owns the protocol boundary. Consumers should use the
//// high-level frame API (encode_response, decode_response_frame,
//// encode_push, decode_push_frame) and not depend on the wire shape.
////
//// The current wire format is ETF (Erlang Term Format). Encoding
//// walks any Gleam value through `erlang:term_to_binary/1`, which
//// preserves the full Erlang type structure natively. Decoding
//// uses `erlang:binary_to_term/1` to reconstruct the original terms.
////
//// **Wire shape:**
//// - Call envelope: `{module_name_binary, request_id, client_msg_value}` -
////   a 3-tuple ETF payload wrapped in a request frame.
//// - Response frame: tag byte 0, 32-bit request ID, ETF payload.
//// - Push frame: tag byte 1, ETF payload (`{module, value}` tuple).
////
//// **Cross-target:** `encode` and `decode` work on both Erlang and
//// JavaScript targets. The Erlang path uses the BEAM's native
//// `term_to_binary` / `binary_to_term`. The JavaScript path uses
//// libero's own ETF encoder/decoder in `rpc_ffi.mjs`, which requires
//// that any custom-type constructors in the value have been registered
//// via the generated `rpc_decoders.gleam` module (which surfaces
//// `ensure_decoders` from the FFI). Libero's generator emits that
//// registration for every type reachable from a handler's params or
//// return type.

import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import libero/error.{type DecodeError}
import libero/frame.{Push, Response}

pub type ServerFrame(value) =
  frame.ServerFrame(value)

// ---------- Encoder ----------

/// Encode any Gleam value to an ETF binary.
///
/// **Not safe for user custom types.** This calls `encode_term` which
/// is a container-only walker: it recurses into lists, maps, and tuples
/// but passes atoms through unchanged. User custom type constructors
/// go over the wire as bare BEAM atoms, not hashed wire identities.
///
/// For user values, use the typed entry points instead:
/// - `encode_response` for RPC handler returns
/// - Generated `encode_push/2` pre-encoder (called by rally's
///   `encode_push_payload` FFI before `wire.encode_push` frames it)
/// - Per-type `wire_encode_<model>` (rally-generated) for SSR flags
///
/// This function is correct for primitives, containers of primitives,
/// and values that have already been pre-encoded by a typed encoder.
@external(erlang, "libero_ffi", "encode")
@external(javascript, "./rpc_ffi.mjs", "encode_value")
pub fn encode(value: a) -> BitArray

// ---------- Decoder (arbitrary value) ----------

/// Decode an ETF binary into an arbitrary Gleam value.
///
/// Works on both Erlang and JavaScript targets. Use this for non-RPC
/// paths - for example, reading server-rendered state from Lustre
/// flags on client boot. For decoding incoming RPC call envelopes
/// specifically, use `decode_call` instead.
///
/// Any custom types in the decoded value must be reachable from a
/// handler's params or return type so their constructors are registered
/// with the JavaScript codec (via the generated `rpc_decoders.gleam`
/// module, which calls `ensure_decoders` on import). On Erlang this
/// is automatic because atoms are pre-registered by the generated
/// `rpc_atoms` module.
///
/// **Warning: type safety is the caller's responsibility.** The return
/// type `a` is unwitnessed: the function returns whatever the ETF
/// binary deserializes to, cast to the caller's expected type. A
/// version skew between client and server will produce silent data
/// corruption, not a runtime error. This is an intentional tradeoff
/// for ergonomics in controlled deployments where both sides are
/// built from the same source.
///
/// This is by design: the generated code is the enforcement point.
///
/// **Panics on malformed input.** In a typical libero deployment
/// both sides are controlled, so this is a sharp-edge check rather
/// than a user-facing error. For untrusted input, use `decode_safe`
/// which returns a `Result`.
@external(erlang, "libero_ffi", "decode")
@external(javascript, "./rpc_ffi.mjs", "decode_value")
pub fn decode(data: BitArray) -> a

// ---------- Safe decoder (arbitrary value) ----------

/// Decode an ETF binary into an arbitrary Gleam value, returning a
/// `Result` instead of panicking on malformed input.
///
/// Use this for non-RPC paths where the input may be untrusted or
/// user-influenced - for example, reading server-rendered state from
/// Lustre flags on client boot where the binary may have been
/// corrupted in transit.
pub fn decode_safe(data: BitArray) -> Result(a, DecodeError) {
  ffi_decode_safe(data)
}

@external(erlang, "libero_ffi", "decode_safe")
@external(javascript, "./rpc_ffi.mjs", "decode_safe")
fn ffi_decode_safe(data: BitArray) -> Result(a, DecodeError) {
  let _ = data
  panic as "libero/wire.ffi_decode_safe: external is missing for this target. This indicates a libero packaging bug; the function should be resolved by the @external attributes."
}

// ---------- Typed decoder (two-pass) ----------

/// Decode an ETF binary and apply a typed decoder by name.
///
/// On JavaScript, this does the two-pass decode: raw ETF → typed decoder
/// lookup via the registry populated by generated codec_ffi.mjs. The
/// `decoder_name` is the full function name, e.g.
/// `"decode_pages_home__model"`.
///
/// On Erlang, ETF is BEAM-native so the decoder_name is ignored;
/// `binary_to_term` already reconstructs all types correctly.
pub fn decode_typed(
  data data: BitArray,
  decoder_name decoder_name: String,
) -> Result(a, DecodeError) {
  ffi_decode_typed(data, decoder_name)
}

@external(erlang, "libero_ffi", "decode_typed")
@external(javascript, "./rpc_ffi.mjs", "decodeTypedWire")
fn ffi_decode_typed(
  data: BitArray,
  decoder_name: String,
) -> Result(a, DecodeError) {
  let _ = data
  let _ = decoder_name
  panic as "libero/wire.ffi_decode_typed: external is missing for this target."
}

// ---------- Decoder (incoming call envelope) ----------

/// Parse a `{<<"module_name">>, request_id, toserver_value}` tuple from an ETF binary.
/// Returns the module name, request ID, and the raw Dynamic value to be coerced.
/// Since `binary_to_term` returns real Erlang terms, no rebuild step
/// is needed - atoms are atoms, tuples are tuples, maps are maps.
///
/// This is specifically for RPC call envelopes. For decoding
/// arbitrary values, use `decode`.
pub fn decode_call(
  data: BitArray,
) -> Result(#(String, Int, Dynamic), DecodeError) {
  ffi_decode_call(data)
}

// nolint: avoid_panic, discarded_result -- Erlang-only @external; JS fallback is unreachable
@external(erlang, "libero_wire_ffi", "decode_call")
fn ffi_decode_call(
  data: BitArray,
) -> Result(#(String, Int, Dynamic), DecodeError) {
  let _ = data
  panic as "libero/wire.decode_call is a server-side function, unreachable on JavaScript target"
}

// ---------- Call envelope encoder ----------

/// Encode a call envelope: `{module_name, request_id, msg}` as ETF binary.
/// Used by generated client stub functions to pack a `ClientMsg` value
/// for transport to the server.
///
/// Prefer `encode_request` which names the protocol concept rather than
/// the implementation detail.
pub fn encode_call(
  module module: String,
  request_id request_id: Int,
  msg msg: a,
) -> BitArray {
  encode(#(module, request_id, msg))
}

/// Encode an outbound RPC request as a wire frame.
/// This is the preferred name for the request encoding boundary.
/// Identical to `encode_call`; exists so consumers name the protocol
/// concept ("request") rather than the mechanism ("call envelope").
pub fn encode_request(
  module module: String,
  request_id request_id: Int,
  msg msg: a,
) -> BitArray {
  encode_call(module:, request_id:, msg:)
}

// ---------- Frame tagging ----------

/// Tag a response frame so the JS client routes it to the correct callback.
/// Prepends a 0 tag byte and the 32-bit request ID so the client can
/// correlate the response with the originating call.
pub fn tag_response(
  request_id request_id: Int,
  data data: BitArray,
) -> BitArray {
  <<0, request_id:32, data:bits>>
}

/// Tag a push frame. Server-initiated messages use tag byte 1 with no
/// request ID, since there is no originating call to correlate.
pub fn tag_push(data: BitArray) -> BitArray {
  <<1, data:bits>>
}

// ---------- High-level frame API ----------

/// Encode a value and wrap it in a response frame (tag byte 0, 32-bit
/// request ID). This is the combined version of `encode` + `tag_response`.
/// Prefer this over calling the two functions separately.
pub fn encode_response(request_id request_id: Int, value value: a) -> BitArray {
  tag_response(request_id:, data: encode(value))
}

/// Encode a push message as a frame (tag byte 1, {module, value} tuple
/// as ETF payload). This is the combined version of `encode` + `tag_push`.
/// Prefer this over assembling the tuple and frame by hand.
pub fn encode_push(module module: String, value value: a) -> BitArray {
  tag_push(encode(#(module, value)))
}

/// Decode a response frame into its request ID and payload value.
/// Strips the frame tag byte and request ID header, then ETF-decodes
/// the payload. Returns the result as a `ServerFrame`.
///
/// Prefer `decode_server_frame` unless you know the frame is a
/// response and want to skip the tag-byte dispatch.
pub fn decode_response_frame(
  data: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  case ffi_decode_response_frame(data) {
    Ok(#(request_id, value)) -> Ok(Response(request_id:, value:))
    Error(err) -> Error(err)
  }
}

/// Decode a push frame into its module and payload value.
/// Strips the frame tag byte, then ETF-decodes the {module, value}
/// tuple from the payload. Returns the result as a `ServerFrame`.
///
/// Prefer `decode_server_frame` unless you know the frame is a
/// push and want to skip the tag-byte dispatch.
pub fn decode_push_frame(
  data: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  case ffi_decode_push_frame(data) {
    Ok(#(module, value)) -> Ok(Push(module:, value:))
    Error(err) -> Error(err)
  }
}

/// Decode any server-to-client frame (response or push) into a
/// `ServerFrame`. This is the primary entry point for consumers: hand
/// Libero the raw bytes and pattern-match on the result.
///
/// The tag byte (0 = response, 1 = push) is read and dispatched
/// internally. Consumers never inspect frame bytes.
///
pub fn decode_server_frame(
  data: BitArray,
) -> Result(ServerFrame(Dynamic), DecodeError) {
  case data {
    <<0, _:bits>> -> decode_response_frame(data)
    <<1, _:bits>> -> decode_push_frame(data)
    _ ->
      Error(error.DecodeError(message: "invalid server frame: unknown tag byte"))
  }
}

@external(erlang, "libero_wire_ffi", "decode_response_frame")
@external(javascript, "./rpc_ffi.mjs", "decode_response_frame")
fn ffi_decode_response_frame(
  data: BitArray,
) -> Result(#(Int, Dynamic), DecodeError) {
  let _ = data
  panic as "libero/wire.ffi_decode_response_frame: external is missing for this target."
}

@external(erlang, "libero_wire_ffi", "decode_push_frame")
@external(javascript, "./rpc_ffi.mjs", "decode_push_frame")
fn ffi_decode_push_frame(
  data: BitArray,
) -> Result(#(String, Dynamic), DecodeError) {
  let _ = data
  panic as "libero/wire.ffi_decode_push_frame: external is missing for this target."
}

// ---------- SSR flags ----------

/// Encode a value to a base64 ETF string for embedding in HTML.
/// Used server-side during SSR to serialize the page model or client
/// context into `<script>` tags for client hydration.
pub fn encode_flags(value: a) -> String {
  value
  |> encode
  |> bit_array.base64_encode(True)
}

/// Decode a base64 ETF flags string and apply a typed decoder.
/// Combines base64 decode, ETF decode, and typed decoder application
/// into a single call. Used client-side during hydration to reconstruct
/// typed values from SSR flags without touching raw decode helpers.
///
/// The `decoder_name` is the function name in the generated decoder
/// registry, e.g. `"decode_pages_home__model"`.
///
pub fn decode_flags_typed(
  flags flags: String,
  decoder_name decoder_name: String,
) -> Result(a, DecodeError) {
  case bit_array.base64_decode(flags) {
    Ok(bits) -> decode_typed(bits, decoder_name)
    Error(_) ->
      Error(error.DecodeError(message: "Failed to base64-decode flags"))
  }
}

// ---------- Variant tag ----------

/// Extract the constructor tag (snake_case atom name) from a Gleam variant
/// value at runtime. Used by generated server dispatch to recognize
/// unknown variants before the unwitnessed `coerce` + structural pattern
/// match would crash with `case_clause`.
///
/// Returns `Ok(name)` for atoms (zero-arg variants) and tagged tuples
/// (n-arg variants where the first element is the constructor atom).
/// Returns `Error(Nil)` for any other shape.
///
/// Server-side only. The JS fallback panics because dispatch never
/// runs on the JavaScript target.
pub fn variant_tag(value: dynamic.Dynamic) -> Result(String, Nil) {
  ffi_variant_tag(value)
}

// nolint: avoid_panic, discarded_result -- Erlang-only @external; JS fallback is unreachable
@external(erlang, "libero_wire_ffi", "variant_tag")
fn ffi_variant_tag(value: dynamic.Dynamic) -> Result(String, Nil) {
  let _ = value
  panic as "libero/wire.variant_tag is a server-side function, unreachable on JavaScript target"
}

// ---------- Coerce ----------

/// Cast a Dynamic value to any type.
/// Used by generated server dispatch code to coerce the decoded
/// `ClientMsg` value to its typed form. Safe when client and server are
/// built from the same source (the generator guarantees the types match).
///
/// **Warning: unwitnessed cast.** Same safety model as `decode`. Type
/// correctness depends on both sides being built from the same source.
/// A mismatch produces silent data corruption.
///
/// This is by design: the generated code is the enforcement point.
/// Making this internal would break the generated dispatch modules
/// which live in consumer packages and need pub access.
@external(erlang, "libero_ffi", "identity")
@external(javascript, "./rpc_ffi.mjs", "identity")
pub fn coerce(value: a) -> b {
  let _ = value
  panic as "libero/wire.coerce: external is missing for this target. This indicates a libero packaging bug; the function should be resolved by the @external attributes."
}
