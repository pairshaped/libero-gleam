---
# libero-ir5g
title: Keep protocol helper tests outside the generated Rally facade
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T16:52:13Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Keep the ETF and JSON low-level protocol helper tests, but do not make
`generate_etf_codec_module` expose a framework protocol facade Rally does not
use. The generated Rally-style ETF module should expose the codec entrypoints
Rally calls: `ensure`, `encode`, and `decode`.

Acceptance:
- Tests fail if the generated ETF module exposes request/result/push/flags
  helpers that belong to Rally's generated protocol modules.
- ETF and JSON runtime helper tests remain in place.
- Rally Scoreboard-style usage is represented by a generated-code test.
- `gleam format && gleam test` passes.

## Result

`test/libero/default_json_generation_test.gleam` now asserts that
`libero.generate_etf_codec_module` emits the generated ETF module Rally uses:

- `ensure`
- `encode`
- `decode`

Existing tests already covered the ETF and JSON runtime facades directly:

- `test/libero/wire_test.gleam` covers ETF request envelopes, response frames, push frames, unified server-frame decode, and flags.
- `test/libero/json_wire_roundtrip_test.gleam` covers JSON request envelopes, response/error/push server frames, and flags.

The generated-code test represents the Rally Scoreboard-style path where Rally
imports generated `src/generated/libero/etf.gleam` and layers its own generated
protocol modules on top.

Validation:

- `gleam format`
- `gleam test --target erlang -- --module libero/default_json_generation_test`

The test command ran the project gleeunit entrypoint and passed 387 tests,
including the generated ETF module surface check. It also printed expected
error-output fixture text from error-formatting tests.
