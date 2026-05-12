// JSON wire FFI tests for libero's json/wire_ffi.mjs
//
// Standalone Node.js test - inlines the Gleam runtime types needed because
// the import chain (wire_ffi.mjs -> gleam_stdlib/gleam.mjs) only resolves
// after `gleam build --target javascript` copies files to the build output.
// Same pattern as test/js/etf_codec_test.mjs.
//
// Run: node test/js/json_wire_roundtrip_test.mjs

import { strict as assert } from "assert";

// ============================================================
// Inlined Gleam runtime types
// ============================================================

class CustomType {}

class Empty {}
class NonEmpty {
  constructor(head, tail) {
    this.head = head;
    this.tail = tail;
  }
}

class Ok {
  constructor(value) {
    this[0] = value;
  }
}

class ResultError {
  constructor(detail) {
    this[0] = detail;
  }
}

class Some {
  constructor(value) {
    this[0] = value;
  }
}
class None {}

// ============================================================
// Inlined ServerFrame constructors (mirrors compiled frame.gleam)
// ============================================================

class Response extends CustomType {
  constructor(request_id, value) {
    super();
    this.request_id = request_id;
    this.value = value;
  }
}

class Push extends CustomType {
  constructor(module, value) {
    super();
    this.module = module;
    this.value = value;
  }
}

class FrameError extends CustomType {
  constructor(request_id, errors) {
    super();
    this.request_id = request_id;
    this.errors = errors;
  }
}

// ============================================================
// Inlined JsonError (mirrors compiled json/error.gleam)
// ============================================================

class JsonError extends CustomType {
  constructor(path, message) {
    super();
    this.path = path;
    this.message = message;
  }
}

// ============================================================
// Helpers from wire_ffi.mjs
// ============================================================

function arrayToGleamList(arr) {
  let list = new Empty();
  for (let i = arr.length - 1; i >= 0; i--) {
    list = new NonEmpty(arr[i], list);
  }
  return list;
}

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
// Functions from wire_ffi.mjs (the unit under test)
// ============================================================

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

export function decode_server_frame(data) {
  try {
    const parsed = JSON.parse(data);
    if (!parsed || typeof parsed !== "object") {
      return new ResultError(
        new NonEmpty(new JsonError("", "expected object"), new Empty()),
      );
    }

    const kind = parsed.kind;

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

export function encode_flags(value) {
  var s = JSON.stringify(value);
  s = s.replace(/</g, "\\u003c");
  s = s.replace(/>/g, "\\u003e");
  s = s.replace(/&/g, "\\u0026");
  s = s.replace(/\u2028/g, "\\u2028");
  s = s.replace(/\u2029/g, "\\u2029");
  return s;
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
  const value = "line\u2028separator\u2029separator";
  const encoded = encode_flags(value);
  assert.ok(!encoded.includes("\u2028"), "should escape U+2028");
  assert.ok(!encoded.includes("\u2029"), "should escape U+2029");
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
