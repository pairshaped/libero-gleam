import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const buildRoot = readFileSync("test/js/.wire_e2e_build_root", "utf8").trim();
const webRoot = join(buildRoot, "clients/web/build/dev/javascript");

const rpcFfi = await import(
  pathToFileURL(join(webRoot, "libero/libero/etf/wire_ffi.mjs")).href
);
const gleam = await import(pathToFileURL(join(webRoot, "gleam_stdlib/gleam.mjs")).href);

function nestedSingleTuple(depth) {
  const bytes = [131];
  for (let i = 0; i < depth; i += 1) {
    bytes.push(104, 1);
  }
  bytes.push(97, 42);
  return Buffer.from(bytes);
}

rpcFfi.set_js_term_depth_limit(0);
assert.equal(rpcFfi.js_term_depth_limit(), 0);

const uncapped = rpcFfi.decode_safe(nestedSingleTuple(4));
assert.ok(uncapped instanceof gleam.Ok);

rpcFfi.set_js_term_depth_limit(3);
assert.equal(rpcFfi.js_term_depth_limit(), 3);

const capped = rpcFfi.decode_safe(nestedSingleTuple(4));
assert.ok(capped instanceof gleam.Error);
assert.match(capped[0].message, /term nesting depth/);

rpcFfi.set_js_term_depth_limit(0);
assert.equal(rpcFfi.js_term_depth_limit(), 0);

assert.equal(rpcFfi.strict_data_terms_enabled(), false);
assert.equal(rpcFfi.set_strict_data_terms(true), undefined);
assert.equal(rpcFfi.strict_data_terms_enabled(), false);

console.log("wire e2e security-config test passed");
