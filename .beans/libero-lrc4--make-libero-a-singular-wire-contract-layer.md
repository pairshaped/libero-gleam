---
# libero-lrc4
title: Make Libero a singular wire-contract layer
status: done
type: epic
priority: high
created_at: 2026-06-06T05:46:19Z
updated_at: 2026-06-06T16:52:13Z
---

Libero should have one clear purpose in the Rally-era architecture: derive typed wire contracts, codecs, protocol facades, dispatch helpers, and contract artifacts for consumers such as Rally. The current repo still mixes that purpose with older standalone transport/client-generation language and APIs.

Goal: decide and implement a singular public story for Libero, with any old standalone transport surface either deliberately supported behind a compatibility boundary or removed.

Acceptance:
- README, llms.txt, docs, and public modules describe one coherent role for Libero.
- Rally Scoreboard is the canonical framework-consumer example.
- Standalone `server_` scanning, generated client mirroring, RemoteData/client-state helpers, JSON/ETF facades, and compatibility wrappers are each classified as core, compatibility, or removed.
- Tests cover the boundary Rally depends on: type walking, generated codecs, request/result/push framing, and protocol-agnostic consumer calls.
- Gleam format/test/docs validation passes.

## Result

Completed the cleanup as a boundary pass, then removed legacy surfaces after confirming latest Rally is the only active consumer.

Libero's documented role is now singular: a typed wire-contract layer that derives request/result/push/flags protocol code, dispatch helpers, codecs, and contract artifacts. Rally Scoreboard is the canonical framework-consumer example in README and `llms.txt`.

Classification:

- Core: scanning and type walking, dispatch generation, generated JSON/ETF codecs, generated `etf.gleam` facade, request/result/push/flags wire helpers, contract artifacts, structured protocol errors.
- Scanner convention: standalone `server_` handlers with unqualified `ServerContext` remain supported, but they are described as the default scanner convention rather than Libero's public identity.
- Compatibility: `libero/wire`, top-level ETF encode/decode helpers, `RequestMsg`, `generate_request_msg_module`, `js_output_dir`, `LIBERO_JS_OUTPUT_DIR`, and `libero/remote_data`.
- Removed: nothing in this pass. The cleaner choice was to add preferred names and docs while keeping stable historical APIs.

Tests added or updated:

- Generated ETF facade exposes request/result/push/flags helpers.
- Preferred `generate_request_msg_module` works and `generate_request_msg_module` remains an exact compatibility alias.
- Preferred mirrored output config/env names work, legacy aliases still work, and preference order is covered.
- Wire E2E fixture mirrors generated `etf.gleam` and JS tests import it before using decoders.
- JSON fixture scripts now use portable in-place replacement instead of BSD-only `sed -i ''`.

Validation:

- `gleam format`
- `gleam docs build`
- `gleam test --target erlang`
- `test/run_js_tests.sh`

Known residual warning: `test/libero/dispatch_panic_test.gleam` still reports an existing unreachable-code warning. It was not introduced by this cleanup.

## Removal Update

The cleanup is no longer compatibility-preserving. After confirming latest Rally is the only active consumer, the old standalone/client personality was removed:

- Removed `libero/remote_data`.
- Removed `libero/wire`.
- Removed `libero/codegen_wire_erl`.
- Removed the old client-message generation alias.
- Removed `js_output_dir` / `LIBERO_JS_OUTPUT_DIR` and old resolver helpers.
- Removed generated endpoint response decoders that returned `RemoteData`.
- Migrated Rally to `generate_request_msg_module` and `libero/etf/wire`.

The remaining generated names now use Libero's current vocabulary: `RequestMsg`, `decoders`, `contract.json`, `generated@libero_wire`, `generated@libero_atoms`, the `"libero"` module tag, and `TransportError`.
