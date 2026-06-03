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

const MAX_JSON_INPUT_BYTES = 1_048_576;
const MAX_JSON_DEPTH = 128;
const MAX_JSON_COLLECTION_LENGTH = 16_384;
const MAX_JSON_STRING_BYTES = 1_048_576;
const utf8Encoder = new TextEncoder();

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

function errorResult(path, message) {
  return new ResultError(
    new NonEmpty(new JsonError(path, message), new Empty()),
  );
}

function byteLength(value) {
  return utf8Encoder.encode(value).byteLength;
}

function validateInputSize(data) {
  if (byteLength(data) <= MAX_JSON_INPUT_BYTES) {
    return null;
  }

  return {
    path: "",
    message: "JSON input exceeds " + MAX_JSON_INPUT_BYTES + " byte limit",
  };
}

function appendPath(path, segment) {
  return path === "" ? segment : path + "." + segment;
}

function validateJsonStructure(value, depth = 0, path = "") {
  if (depth > MAX_JSON_DEPTH) {
    return {
      path,
      message: "JSON nesting depth exceeds " + MAX_JSON_DEPTH,
    };
  }

  if (typeof value === "string") {
    if (byteLength(value) <= MAX_JSON_STRING_BYTES) {
      return null;
    }

    return {
      path,
      message: "JSON string exceeds " + MAX_JSON_STRING_BYTES + " byte limit",
    };
  }

  if (Array.isArray(value)) {
    if (value.length > MAX_JSON_COLLECTION_LENGTH) {
      return {
        path,
        message:
          "JSON array exceeds " + MAX_JSON_COLLECTION_LENGTH + " item limit",
      };
    }

    for (let i = 0; i < value.length; i++) {
      const error = validateJsonStructure(
        value[i],
        depth + 1,
        appendPath(path, String(i)),
      );
      if (error) return error;
    }

    return null;
  }

  if (value !== null && typeof value === "object") {
    const entries = Object.entries(value);
    if (entries.length > MAX_JSON_COLLECTION_LENGTH) {
      return {
        path,
        message:
          "JSON object exceeds " +
          MAX_JSON_COLLECTION_LENGTH +
          " field limit",
      };
    }

    for (const [key, child] of entries) {
      const error = validateJsonStructure(
        child,
        depth + 1,
        appendPath(path, key),
      );
      if (error) return error;
    }
  }

  return null;
}

function parseLimitedJson(data) {
  const inputError = validateInputSize(data);
  if (inputError) {
    return { error: inputError };
  }

  let parsed;
  try {
    parsed = JSON.parse(data);
  } catch (e) {
    const msg =
      e && typeof e.message === "string" ? e.message : "failed to parse JSON";
    return { error: { path: "", message: msg } };
  }

  const structureError = validateJsonStructure(parsed);
  if (structureError) {
    return { error: structureError };
  }

  return { value: parsed };
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
  const limited = parseLimitedJson(data);
  if (limited.error) {
    return errorResult(limited.error.path, limited.error.message);
  }

  const parsed = limited.value;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return errorResult("", "expected object");
  }

  const kind = parsed.kind;
  const protocolVersion = parsed.protocol_version;

  if (protocolVersion !== "json-rpc-v1") {
    return errorResult(
      "protocol_version",
      "unsupported version: " + (protocolVersion ?? "undefined"),
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

  return errorResult("kind", "unknown frame kind: " + (kind ?? "undefined"));
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
  const limited = parseLimitedJson(flags);
  if (limited.error) {
    return errorResult(limited.error.path, limited.error.message);
  }

  return new Ok(limited.value);
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
