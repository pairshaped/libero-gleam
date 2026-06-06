---
# libero-ir5g
title: Add protocol-facade tests for request/result/push/flags
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T16:52:13Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Add or tighten tests proving consumers can use Libero through protocol-level facades instead of raw frame matching or raw decoder calls. Cover ETF first and JSON where supported. The point is to make the Rally boundary executable: consumers should call named operations for request encode/decode, response/result frames, push frames, and SSR flags.

Acceptance:
- Tests fail if a consumer must inspect raw tag bytes, manually slice request IDs, or call raw typed decoders for normal request/result/push/flags flows.
- ETF and JSON surface differences are explicit and documented in tests.
- Rally Scoreboard-style usage is represented by a fixture or generated-code snapshot.
- `gleam format && gleam test` passes.

## Result

Added a generated ETF facade test in `test/libero/default_json_generation_test.gleam` and extended `libero.generate_etf_codec_module` so generated `etf.gleam` exposes named protocol operations:

- `encode_request`
- `decode_request`
- `encode_response`
- `decode_server_frame`
- `encode_push`
- `encode_flags`
- `decode_flags_typed`

The generated module still keeps raw `encode` and `decode` helpers for low-level ETF use, but framework-generated protocol modules no longer need Libero to add new raw helpers when moving toward request/result/push/flags wrappers.

Existing tests already covered the ETF and JSON runtime facades directly:

- `test/libero/wire_test.gleam` covers ETF request envelopes, response frames, push frames, unified server-frame decode, and flags.
- `test/libero/json_wire_roundtrip_test.gleam` covers JSON request envelopes, response/error/push server frames, and flags.

The new generated-code test represents the Rally Scoreboard-style path where a framework imports generated `src/generated/libero/etf.gleam` and layers its own public protocol module on top.

Validation:

- `gleam format`
- `gleam test --target erlang test/libero/default_json_generation_test.gleam`

The test command ran the project gleeunit entrypoint and passed 545 tests. It also printed the existing unreachable-code warning in `test/libero/dispatch_panic_test.gleam` and expected error-output fixture text from error-formatting tests.

Follow-up: Rally still calls raw `generated/libero/etf.encode` and `decode` in its generated protocol modules. Libero now exposes the wrappers needed to migrate that generator, but the Rally-side migration is outside this bean.
