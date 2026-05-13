// JSON wire FFI tests for libero's json/wire_ffi.mjs
//
// Imports the PRODUCTION module via a custom Node loader that shims
// gleam_stdlib and compiled-Gleam type imports. This ensures the test
// exercises the real code, not a stale inline copy.
//
// Run: node --import ./test/js/json_wire_loader.mjs test/js/json_wire_roundtrip_test.mjs

import { strict as assert } from "assert";

import {
  encode_request,
  decode_server_frame,
  encode_flags,
} from "../../src/libero/json/wire_ffi.mjs";

import { Ok, Error as ResultError, Empty, NonEmpty } from "./json_wire_shim.mjs";
import { Some, None } from "./json_wire_shim_option.mjs";
import { Response, Push, Error as FrameError } from "./json_wire_shim_frame.mjs";
import { JsonError } from "./json_wire_shim_error.mjs";

function gleamListToArray(list) {
  if (Array.isArray(list)) return list;
  const out = [];
  let cur = list;
  while (cur instanceof NonEmpty) {
    out.push(cur.head);
    cur = cur.tail;
  }
  return out;
}

// ============================================================
// Tests
// ============================================================

let passed = 0;
let failed = 0;
const failures = [];

function test(group, name, fn) {
  try {
    fn();
    passed++;
    console.log(`  \x1b[32m+\x1b[0m ${name}`);
  } catch (e) {
    failed++;
    const msg = `${group} > ${name}: ${e.message}`;
    failures.push(msg);
    console.log(`  \x1b[31mx ${name}\x1b[0m`);
    console.log(`    ${e.message}`);
  }
}

// ---------- encode_request ----------

console.log("\nJSON wire encode_request:");

test("encode_request", "produces valid JSON with correct shape", () => {
  const encoded = encode_request(
    "rpc",
    1,
    { type: "t.Test", variant: "V", fields: {} },
    "abc123",
  );
  const parsed = JSON.parse(encoded);
  assert.equal(parsed.kind, "request");
  assert.equal(parsed.protocol_version, "json-rpc-v1");
  assert.equal(parsed.contract_hash, "abc123");
  assert.equal(parsed.module, "rpc");
  assert.equal(parsed.request_id, 1);
  assert.deepEqual(parsed.message, {
    type: "t.Test",
    variant: "V",
    fields: {},
  });
});

test("encode_request", "handles null message", () => {
  const encoded = encode_request("rpc", 2, null, "hash");
  const parsed = JSON.parse(encoded);
  assert.equal(parsed.request_id, 2);
  assert.equal(parsed.message, null);
});

test("encode_request", "handles array message", () => {
  const encoded = encode_request("rpc", 3, [1, 2, 3], "hash");
  const parsed = JSON.parse(encoded);
  assert.deepEqual(parsed.message, [1, 2, 3]);
});

// ---------- decode_server_frame ----------

console.log("\nJSON wire decode_server_frame:");

test("decode_server_frame", "parses response frame", () => {
  const frame = JSON.stringify({
    kind: "response",
    protocol_version: "json-rpc-v1",
    request_id: 42,
    value: { type: "r.Result", variant: "Ok", fields: ["done"] },
  });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof Ok, "should be Ok");
  const serverFrame = result[0];
  assert.ok(serverFrame instanceof Response, "should be Response");
  assert.equal(serverFrame.request_id, 42);
  assert.deepEqual(serverFrame.value, {
    type: "r.Result",
    variant: "Ok",
    fields: ["done"],
  });
});

test("decode_server_frame", "parses push frame", () => {
  const frame = JSON.stringify({
    kind: "push",
    protocol_version: "json-rpc-v1",
    module: "my_page",
    value: { type: "m.Msg", variant: "Updated", fields: { id: 1 } },
  });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof Ok, "should be Ok");
  const serverFrame = result[0];
  assert.ok(serverFrame instanceof Push, "should be Push");
  assert.equal(serverFrame.module, "my_page");
  assert.deepEqual(serverFrame.value, {
    type: "m.Msg",
    variant: "Updated",
    fields: { id: 1 },
  });
});

test("decode_server_frame", "parses error frame with request_id", () => {
  const frame = JSON.stringify({
    kind: "error",
    protocol_version: "json-rpc-v1",
    request_id: 7,
    errors: [
      { path: "name", message: "required" },
      { path: "age", message: "expected Int, got String" },
    ],
  });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof Ok, "should be Ok");
  const serverFrame = result[0];
  assert.ok(serverFrame instanceof FrameError, "should be FrameError");
  assert.ok(serverFrame.request_id instanceof Some, "request_id should be Some");
  assert.equal(serverFrame.request_id[0], 7);
  const errors = gleamListToArray(serverFrame.errors);
  assert.equal(errors.length, 2);
  assert.deepEqual(errors[0], ["name", "required"]);
  assert.deepEqual(errors[1], ["age", "expected Int, got String"]);
});

test("decode_server_frame", "parses error frame without request_id", () => {
  const frame = JSON.stringify({
    kind: "error",
    protocol_version: "json-rpc-v1",
    errors: [{ path: "", message: "server error" }],
  });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof Ok, "should be Ok");
  const serverFrame = result[0];
  assert.ok(serverFrame.request_id instanceof None, "request_id should be None");
  const errors = gleamListToArray(serverFrame.errors);
  assert.equal(errors.length, 1);
  assert.deepEqual(errors[0], ["", "server error"]);
});

test("decode_server_frame", "handles empty errors list", () => {
  const frame = JSON.stringify({
    kind: "error",
    protocol_version: "json-rpc-v1",
    request_id: null,
    errors: [],
  });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof Ok, "should be Ok");
  const serverFrame = result[0];
  assert.ok(serverFrame.request_id instanceof None, "request_id should be None");
  assert.ok(serverFrame.errors instanceof Empty, "errors should be empty list");
});

test("decode_server_frame", "rejects unknown kind", () => {
  const frame = JSON.stringify({
    kind: "unknown_thing",
    protocol_version: "json-rpc-v1",
  });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof ResultError, "should be ResultError");
  const errors = gleamListToArray(result[0]);
  assert.equal(errors.length, 1);
  assert.ok(errors[0] instanceof JsonError);
  assert.equal(errors[0].path, "kind");
  assert.ok(errors[0].message.includes("unknown frame kind"));
});

test("decode_server_frame", "rejects invalid JSON", () => {
  const result = decode_server_frame("not json at all");
  assert.ok(result instanceof ResultError, "should be ResultError");
  const errors = gleamListToArray(result[0]);
  assert.equal(errors.length, 1);
  assert.ok(errors[0] instanceof JsonError);
  assert.equal(errors[0].path, "");
});

test("decode_server_frame", "rejects non-object JSON", () => {
  const result = decode_server_frame('"just a string"');
  assert.ok(result instanceof ResultError, "should be ResultError");
});

test("decode_server_frame", "rejects missing protocol_version", () => {
  const frame = JSON.stringify({ kind: "response", request_id: 1, value: {} });
  const result = decode_server_frame(frame);
  assert.ok(result instanceof ResultError, "should be ResultError");
  const errors = gleamListToArray(result[0]);
  assert.ok(
    errors[0].message.includes("unsupported version"),
    "should reject missing protocol version",
  );
});

// ---------- encode_flags ----------

console.log("\nJSON wire encode_flags:");

test("encode_flags", "escapes < > &", () => {
  const value = "</script>&<script>alert(1)</script>";
  const encoded = encode_flags(value);
  assert.ok(!encoded.includes("<"), "should escape <");
  assert.ok(!encoded.includes(">"), "should escape >");
  assert.ok(!encoded.includes("&"), "should escape &");
  assert.ok(encoded.includes("\\u003c"), "should contain \\u003c");
  assert.ok(encoded.includes("\\u003e"), "should contain \\u003e");
  assert.ok(encoded.includes("\\u0026"), "should contain \\u0026");
});

test("encode_flags", "escapes U+2028 and U+2029", () => {
  const value = "line separator separator";
  const encoded = encode_flags(value);
  assert.ok(!encoded.includes(" "), "should escape U+2028");
  assert.ok(!encoded.includes(" "), "should escape U+2029");
  assert.ok(encoded.includes("\\u2028"), "should contain \\u2028");
  assert.ok(encoded.includes("\\u2029"), "should contain \\u2029");
});

test("encode_flags", "preserves normal JSON", () => {
  const value = { hello: "world", count: 42 };
  const encoded = encode_flags(value);
  const parsed = JSON.parse(encoded);
  assert.equal(parsed.hello, "world");
  assert.equal(parsed.count, 42);
});

// ============================================================
// Summary
// ============================================================

console.log(
  `\n\x1b[1m${passed + failed} tests: \x1b[32m${passed} passed\x1b[0m, \x1b[${failed > 0 ? "31" : "32"}m${failed} failed\x1b[0m`,
);

if (failures.length > 0) {
  console.log("\nFailures:");
  for (const f of failures) {
    console.log(`  - ${f}`);
  }
}

process.exit(failed > 0 ? 1 : 0);
