---
# libero-zi4f
title: JS JSON wire tests inline production FFI code (test/js/json_wire_roundtrip_test.mjs)
status: todo
type: task
priority: high
tags:
    - code-review
    - important
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-05-13T00:39:01Z
---

Imported from code-review.md finding 13 (Important).

`test/js/json_wire_roundtrip_test.mjs` copies helpers and frame encode/decode functions from `src/libero/json/wire_ffi.mjs` instead of importing the production module. That means the test can pass while the code users run drifts. Import the real `wire_ffi.mjs` like `json_wire_ffi_imports_test.mjs` does, or keep only tiny local assertions/helpers in the test file.
