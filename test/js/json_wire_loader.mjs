// Node module resolution hook for json_wire_roundtrip_test.mjs.
//
// Redirects gleam_stdlib and compiled-module imports to local shims
// so the test can import the real src/libero/json/wire_ffi.mjs without
// a full `gleam build --target javascript`.

import { register } from "node:module";

register("./json_wire_resolver.mjs", import.meta.url);
