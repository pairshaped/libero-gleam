---
# libero-6vj3
title: Remove dispatch wire transform wrappers
status: todo
type: task
priority: normal
tags:
    - wire
    - codegen
created_at: 2026-05-09T13:51:26Z
updated_at: 2026-05-09T13:51:26Z
blocked_by:
    - libero-8hx9
---

Validation:
- `src/libero_ffi.erl` already centralizes arbitrary encode/decode through the registered wire module.
- `src/libero/codegen_dispatch.gleam` still accepts `wire_module`, emits `decode_client_msg` and `encode_response_*` externals, calls `wire_decode_client_msg(msg)`, and wraps handler results with `wire_encode_response_*` before `wire.encode`.
- `test/libero/endpoint_dispatch_test.gleam` still asserts those externals and wrapper calls.

Work:
- After ambiguous generic encoding is resolved, remove dispatch-level wire transform plumbing from `codegen_dispatch.gleam` and the public `libero.generate_dispatch` wrapper.
- Keep atoms module registration of the wire module, since `libero_ffi` still needs it.
- Update dispatch tests and snapshots to reflect the simpler generated dispatch.

Acceptance:
- Generated dispatch no longer emits `wire_decode_client_msg` or `wire_encode_response_*` externals.
- Handler results go straight through `wire.encode`.
- Libero tests, JS tests, and format check pass.
