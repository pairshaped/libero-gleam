---
# libero-r72z
title: Quarantine or remove standalone transport/client-generation surfaces
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T16:52:13Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

After the API boundary is decided, move older standalone app-facing surfaces behind explicit compatibility naming or delete them. Candidate surfaces include `server_` prefix scanner assumptions, `ServerContext` hardcoding, client file mirroring via `js_output_dir`, RemoteData/client-state helpers, and modules/docs that imply Libero owns transport or client application state.

Acceptance:
- Compatibility surfaces are clearly named and documented as compatibility, or removed with tests updated.
- Core Rally-style APIs do not require consumers to think in `server_*` handler names or generated client packages.
- Internal modules stay internal where possible.
- `gleam format && gleam test` passes.

## Result

Quarantined the split-package client-generation surface behind compatibility language rather than deleting it. Deleting it would have been churn without a clean migration path for existing standalone consumers.

The preferred setting is now `mirrored_output_dir`, with `js_output_dir` retained as a compatibility alias. The preferred one-off environment variable is `LIBERO_MIRRORED_OUTPUT_DIR`, with `LIBERO_JS_OUTPUT_DIR` retained as a fallback alias. Tests cover the new config key, legacy fallback, preference order, and type validation.

ETF mirrored output now includes generated `etf.gleam`, so split-package consumers get the same request/result/push/flags facade as the server-side generated package. The wire E2E fixture now uses `mirrored_output_dir`, imports the mirrored generated `etf` module, and calls `ensure()` before using generated JavaScript decoders.

RemoteData is documented as a compatibility app-state helper, not part of Libero's core wire-contract boundary. README and `llms.txt` no longer present generated client mirroring, RemoteData, transport, browser lifecycle, SSR, or app state as Libero's primary job.

The standalone `server_`/`ServerContext` scanner convention remains supported and documented as the default scanner convention. Rally-style consumers can still work from discovered endpoints and generated protocol facades without exposing that vocabulary in Rally APIs.

Validation:

- `gleam format`
- `gleam test --target erlang`
- `test/run_js_tests.sh`

## Removal Update

Removed the old standalone/client-state surfaces now that latest Rally is the only consumer:

- Deleted `src/libero/remote_data.gleam` and `test/libero/remote_data_test.gleam`.
- Deleted `src/libero/wire.gleam` and `src/libero_wire_ffi.erl`; consumers must use `libero/etf/wire`.
- Deleted `src/libero/codegen_wire_erl.gleam`; consumers must use `libero/etf/codegen_erl`.
- Removed generated JS endpoint response helpers (`decode_response_*`) that returned `RemoteData` shapes.
- Removed `js_output_dir` and `LIBERO_JS_OUTPUT_DIR` support.
- Updated JS E2E tests to decode response envelopes through the generated ETF facade and typed decode path instead of endpoint response helpers.
- Updated Rally's runtime wire wrapper to import `libero/etf/wire`.

Mirrored ETF output still writes a request-message module to `dispatch.gleam` for separate client packages. That is still needed for the generated request type; it no longer pulls in server dispatch code.
