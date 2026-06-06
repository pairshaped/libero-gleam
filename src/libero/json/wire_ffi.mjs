// @ts-check
//
// JSON wire format for libero transport.
//
// Wire shape: JSON text (string). WebSocket uses text frames.
//
// This is the JS FFI for the JSON wire protocol, mirroring the ETF
// etf/wire_ffi.mjs but working with JSON text frames instead of ETF binary.
//
// IMPORTANT: This module is frame-level only. It wraps/unwraps JSON-transport-v1
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

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function byteLength(value, limit) {
  if (value.length <= Math.floor(limit / 3)) {
    return value.length;
  }

  return utf8Encoder.encode(value).byteLength;
}

function validateInputSize(data) {
  if (byteLength(data, MAX_JSON_INPUT_BYTES) <= MAX_JSON_INPUT_BYTES) {
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
    if (byteLength(value, MAX_JSON_STRING_BYTES) <= MAX_JSON_STRING_BYTES) {
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

function requiredStringField(parsed, name) {
  const value = parsed[name];
  if (typeof value === "string") {
    return { value };
  }

  return {
    error: {
      path: name,
      message: "expected String, got " + foundType(value),
    },
  };
}

function requiredIntField(parsed, name) {
  const value = parsed[name];
  if (
    Number.isSafeInteger(value) &&
    value >= -9_007_199_254_740_991 &&
    value <= 9_007_199_254_740_991
  ) {
    return { value };
  }

  return {
    error: {
      path: name,
      message: "expected Int, got " + foundType(value),
    },
  };
}

function requiredDynamicField(parsed, name) {
  if (Object.hasOwn(parsed, name)) {
    return { value: parsed[name] };
  }

  return {
    error: {
      path: name,
      message: "required field missing",
    },
  };
}

function optionalIntField(parsed, name) {
  if (!Object.hasOwn(parsed, name) || parsed[name] === null) {
    return { value: new None() };
  }

  const decoded = requiredIntField(parsed, name);
  if (decoded.error) {
    return decoded;
  }

  const requestId = validateRequestId(decoded.value);
  if (requestId.error) {
    return requestId;
  }

  return { value: new Some(requestId.value) };
}

function validateRequestId(value) {
  if (value >= 0 && value <= 4_294_967_295) {
    return { value };
  }

  return {
    error: {
      path: "request_id",
      message: "request_id outside 32-bit unsigned range",
    },
  };
}

function errorListField(parsed) {
  const errors = parsed.errors;
  if (!Array.isArray(errors)) {
    return {
      error: {
        path: "errors",
        message: "expected list of errors",
      },
    };
  }

  const out = [];
  for (const error of errors) {
    if (!isObject(error)) {
      return {
        error: {
          path: "errors",
          message: "expected error object",
        },
      };
    }

    if (typeof error.path !== "string") {
      return {
        error: {
          path: "errors[].path",
          message: "expected String, got " + foundType(error.path),
        },
      };
    }

    if (typeof error.message !== "string") {
      return {
        error: {
          path: "errors[].message",
          message: "expected String, got " + foundType(error.message),
        },
      };
    }

    out.push([error.path, error.message]);
  }

  return { value: arrayToGleamList(out) };
}

function foundType(value) {
  if (value === null) {
    return "Null";
  }
  if (Array.isArray(value)) {
    return "List";
  }

  switch (typeof value) {
    case "string":
      return "String";
    case "number":
      return Number.isInteger(value) ? "Int" : "Float";
    case "boolean":
      return "Bool";
    case "object":
      return "Dict";
    case "undefined":
      return "unknown";
    default:
      return typeof value;
  }
}

// ---------- Encode ----------

/**
 * Encode a JSON-transport-v1 request envelope.
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
    protocol_version: "libero-json-v1",
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
  if (!isObject(parsed)) {
    return errorResult("", "expected object");
  }

  const protocolVersion = requiredStringField(parsed, "protocol_version");
  if (protocolVersion.error) {
    return errorResult(
      protocolVersion.error.path,
      protocolVersion.error.message,
    );
  }

  if (protocolVersion.value !== "libero-json-v1") {
    return errorResult(
      "protocol_version",
      "unsupported version: " + protocolVersion.value,
    );
  }

  const kind = requiredStringField(parsed, "kind");
  if (kind.error) {
    return errorResult(kind.error.path, kind.error.message);
  }

  if (kind.value === "response") {
    const requestId = requiredIntField(parsed, "request_id");
    if (requestId.error) {
      return errorResult(requestId.error.path, requestId.error.message);
    }

    const validRequestId = validateRequestId(requestId.value);
    if (validRequestId.error) {
      return errorResult(
        validRequestId.error.path,
        validRequestId.error.message,
      );
    }

    const value = requiredDynamicField(parsed, "value");
    if (value.error) {
      return errorResult(value.error.path, value.error.message);
    }

    return new Ok(new Response(validRequestId.value, value.value));
  }

  if (kind.value === "push") {
    const module = requiredStringField(parsed, "module");
    if (module.error) {
      return errorResult(module.error.path, module.error.message);
    }

    const value = requiredDynamicField(parsed, "value");
    if (value.error) {
      return errorResult(value.error.path, value.error.message);
    }

    return new Ok(new Push(module.value, value.value));
  }

  if (kind.value === "error") {
    const requestId = optionalIntField(parsed, "request_id");
    if (requestId.error) {
      return errorResult(requestId.error.path, requestId.error.message);
    }

    const errors = errorListField(parsed);
    if (errors.error) {
      return errorResult(errors.error.path, errors.error.message);
    }

    return new Ok(new FrameError(requestId.value, errors.value));
  }

  return errorResult("kind", "unknown frame kind: " + kind.value);
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
