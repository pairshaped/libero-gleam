// Verify wire_ffi.mjs exports all expected functions.
//
// Uses static analysis instead of dynamic import because the FFI module
// imports from gleam_stdlib (only available after `gleam build`).
// This checks that the source file declares the expected exports.
//
// Run: node test/js/json_wire_ffi_imports_test.mjs

import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

function test() {
  const source = readFileSync(
    resolve(__dirname, "../../src/libero/json/wire_ffi.mjs"),
    "utf8",
  );

  // Extract all exported function names
  const exportRegex = /export function (\w+)/g;
  const exports = [];
  let match;
  while ((match = exportRegex.exec(source)) !== null) {
    exports.push(match[1]);
  }

  const required = [
    "encode_request",
    "decode_server_frame",
    "encode_flags",
    "decode_flags_typed",
  ];

  for (const name of required) {
    if (!exports.includes(name)) {
      console.error(`FAIL: export "${name}" not found in wire_ffi.mjs`);
      process.exit(1);
    }
  }

  console.log("DONE: wire_ffi.mjs exports all required functions");
  console.log("  found:", exports.join(", "));
}

test();
