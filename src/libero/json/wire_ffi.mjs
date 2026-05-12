// @ts-check
//
// JSON wire format for libero RPC.
//
// Wire shape: JSON text (string). WebSocket uses text frames.
//
// This is the JS FFI for the JSON wire protocol, mirroring the ETF
// etf/wire_ffi.mjs but working with JSON text frames instead of ETF binary.
//
// IMPORTANT: This module is frame-level only. It wraps/unwraps JSON-RPC-v1
// protocol envelopes. It does NOT perform typed encoding of user values.
//
// Callers must pre-encode message payloads through generated typed JSON
// encoders before passing them to encode_request. The `msg` parameter
// expects a plain JS object in the Libero typed-value shape:
//   { "type": "<module>.<Type>", "variant": "<Variant>", "fields": ... }
//
// Similarly, decode_server_frame returns a ServerFrame carrying a raw
// JSON value. Callers must route the value through a generated typed
// JSON decoder to reconstruct the Gleam type.
//
// The contract_hash parameter on encode_request is REQUIRED for JSON
// protocol. It must match the hash in the server's contract artifact.
// Mismatched hashes produce a protocol error response.

import { Ok, Error as ResultError, CustomType, Empty, NonEmpty } from "../../../gleam_stdlib/gleam.mjs";
import { Some, None } from "../../../gleam_stdlib/gleam/option.mjs";
import { Response, Push, Error as FrameError } from "../frame.mjs";
import { JsonError } from "./error.mjs";

// ---------- Helpers ----------

/**
 * Build a Gleam linked list from a plain JS array.
 * @param {any[]} arr
 * @returns {any}
 */
function arrayToGleamList(arr) {
  let list = new Empty();
  for (let i = arr.length - 1; i >= 0; i--) {
    list = new NonEmpty(arr[i], list);
  }
  return list;
}

// ---------- Encode ----------

/**
 * Encode a JSON-RPC-v1 request envelope.
 *
 * @param {string} module
 * @param {number} requestId
 * @param {any} msg - plain JS object (already JSON-encoded typed message)
 * @param {string} contractHash
 * @returns {string} JSON text
 */
export function encode_request(module, requestId, msg, contractHash) {
  return JSON.stringify({
    kind: "request",
    protocol_version: "json-rpc-v1",
    contract_hash: contractHash,
    module: module,
    request_id: requestId,
    message: msg,
  });
}

// ---------- Decode ----------

/**
 * Decode a server frame (response, push, or error) from JSON text.
 *
 * Returns Gleam Result(ServerFrame(Dynamic), List(JsonError)).
 *
 * @param {string} data - JSON text
 * @returns {any} Ok(Response|Push|FrameError) or ResultError(List(JsonError))
 */
export function decode_server_frame(data) {
  try {
    const parsed = JSON.parse(data);
    if (!parsed || typeof parsed !== "object") {
      return new ResultError(
        new NonEmpty(new JsonError("", "expected object"), new Empty()),
      );
    }

    const kind = parsed.kind;
    const protocolVersion = parsed.protocol_version;

    if (protocolVersion !== "json-rpc-v1") {
      return new ResultError(
        new NonEmpty(
          new JsonError(
            "protocol_version",
            "unsupported version: " + (protocolVersion ?? "undefined"),
          ),
          new Empty(),
        ),
      );
    }

    if (kind === "response") {
      return new Ok(new Response(parsed.request_id, parsed.value));
    }

    if (kind === "push") {
      return new Ok(new Push(parsed.module, parsed.value));
    }

    if (kind === "error") {
      const requestId =
        parsed.request_id !== undefined && parsed.request_id !== null
          ? new Some(parsed.request_id)
          : new None();
      const errors = arrayToGleamList(
        (parsed.errors || []).map((e) => [
          e.path || "",
          e.message || "",
        ]),
      );
      return new Ok(new FrameError(requestId, errors));
    }

    return new ResultError(
      new NonEmpty(
        new JsonError("kind", "unknown frame kind: " + (kind ?? "undefined")),
        new Empty(),
      ),
    );
  } catch (e) {
    const msg =
      e && typeof e.message === "string" ? e.message : "failed to parse JSON";
    return new ResultError(
      new NonEmpty(new JsonError("", msg), new Empty()),
    );
  }
}

// ---------- SSR flags ----------

/**
 * Encode a value as JSON with HTML-safe escaping for SSR.
 *
 * @param {any} value - plain JS value
 * @returns {string} JSON text with HTML-unsafe chars escaped
 */
export function encode_flags(value) {
  return JSON.stringify(value)
    .replace(/</g, "\\u003c")
    .replace(/>/g, "\\u003e")
    .replace(/&/g, "\\u0026")
    .replace(/\u2028/g, "\\u2028")
    .replace(/\u2029/g, "\\u2029");
}

/**
 * Decode SSR flags from JSON text.
 *
 * For now, just parses JSON and returns Ok. The typed decode (by decoderName)
 * happens in the generated codec module.
 *
 * @param {string} flags - JSON text
 * @param {string} _decoderName - name of the typed decoder function (unused for now)
 * @returns {any} Ok(parsed_value) or ResultError(List(JsonError))
 */
export function decode_flags_typed(flags, _decoderName) {
  try {
    const parsed = JSON.parse(flags);
    return new Ok(parsed);
  } catch (e) {
    const msg =
      e && typeof e.message === "string" ? e.message : "failed to parse JSON";
    return new ResultError(
      new NonEmpty(new JsonError("", msg), new Empty()),
    );
  }
}

/**
 * Identity function for type-level coercion in generated transport code.
 * The JS runtime representation is unchanged; this lets generated code
 * bridge between Dynamic/generic and concrete types.
 *
 * @param {any} x
 * @returns {any}
 */
export function identity(x) {
  return x;
}
