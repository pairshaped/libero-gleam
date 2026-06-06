---
# libero-t9n0
title: Audit Libero public surfaces and split-personality vocabulary
status: done
type: task
priority: high
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T15:17:19Z
parent: libero-lrc4
---

Read Libero code, tests, README, llms.txt, docs, and generated snapshots for competing stories: standalone `server_` transport scanner/app generator, client file mirroring, RemoteData/client-state helpers, ETF/JSON protocol facades, raw wire helpers, Rally framework-consumer API, and compatibility wrappers.

Acceptance:
- Produce a concise inventory in the bean body grouping each surface as core, compatibility candidate, removal candidate, or unresolved.
- Identify current Rally usage from the Rally Scoreboard path and Rally generator imports.
- Identify docs that teach obsolete or mixed mental models.
- Recommend the child bean ordering before code edits begin.

Validation: read-only, but run `rg` audit commands and include them in the summary.

## Audit Summary

Libero currently has a better internal direction than its README suggests. The code already has protocol-level ETF/JSON helpers and Rally consumes Libero as a codegen/contract dependency. The split personality is mostly caused by old top-level docs, CLI defaults, and a few public compatibility surfaces that still make Libero sound like it owns app/client state.

### Core Surface

- Type discovery: `libero.scan`, `libero.scan_excluding`, `libero.collect_seeds`, `libero.walk`, plus lower-level `libero/scanner`, `libero/walker`, `libero/field_type`, `libero/glance_type_resolver`, and `libero/gen_error`.
- Dispatch and codec generation: `libero.generate_dispatch`, `libero.generate_dispatch_with_extra_params`, `libero.generate_json_dispatch`, `libero.generate_json_dispatch_with_extra_params`, `libero.generate_atoms`, `libero.generate_wire_erl`, `libero.generate_decoders_ffi`, `libero.generate_decoders_gleam`, `libero.generate_etf_codec_module`, and `libero.generate_request_msg_module`.
- Contract artifacts: `libero.generate_json_contract`, `libero.generate_json_contract_hash`, `libero/json/contract`.
- Protocol facades: `libero/etf/wire` and `libero/json/wire` own request encode/decode, response frame encode/decode, push frame encode/decode, SSR flags, and server-frame dispatch. `libero/frame` is part of this story.
- Wire identity and validation: `libero/wire_identity`, `libero/etf/codegen_erl`, generated `libero_atoms`, generated `libero_wire`, typed JS decoder generation, JSON runtime validation, and safe ETF decode settings.
- Panic/error boundary: `libero/error` and `libero/trace` are core because generated dispatch depends on structured transport errors and panic-safe handler calls.

### Compatibility Candidates

- `libero/wire` is already documented as deprecated compatibility for `libero/etf/wire`. Keep it as compatibility unless the next boundary bean decides on a major-version removal.
- CLI generation through `gleam run -m libero` is still useful, but it should be described as the standalone/default generator path, not the definition of Libero's identity.
- `js_output_dir` and `LIBERO_JS_OUTPUT_DIR` mirror generated client files into another package. This is old standalone-client behavior. Keep only as compatibility unless there is an active consumer.
- Top-level `libero.ensure`, `libero.encode`, and `libero.decode` are convenience ETF wrappers. They are sharp because they expose raw encode/decode from the top-level facade. Either document as compatibility/escape hatch or move users toward generated protocol modules.
- `RemoteData`, `RpcOutcome`, and `RpcData` are app/client-state helpers. They should either move behind explicit compatibility/docs framing or leave Libero. They are not part of the wire-contract layer Rally needs.
- `generate_request_msg_module` is core for Libero-owned JSON and useful for standalone ETF dispatch, but Rally generates its own request/result/push facade. Document it as request message codegen, not client application generation.

### Removal Candidates

- README language saying Libero generates "Client state for loading, success, domain errors, and transport errors" should be removed or moved to compatibility notes. It conflicts with the "Transport Is Yours" and Rally ownership story.
- README and llms examples that make `server_` handlers and `ServerContext` the primary identity should be demoted. The current scanner still has those conventions, but the public story should say "handler-derived contract" first, with `server_`/`ServerContext` as the default scanner convention.
- Docs that teach "generated client files" as a primary workflow should be rewritten. Generated protocol facades and contract files are core; app/client package mirroring is not.
- Tests that still exercise `wire.tag_response` + `wire.encode` as normal generated-dispatch behavior should be converted where possible to `encode_response` and protocol-level facade assertions. Raw helpers can remain covered as low-level tests.

### Unresolved

- Whether `server_` prefix scanning remains the default only, becomes configurable, or becomes a compatibility scanner while Rally-style consumers pass endpoints explicitly.
- Whether `ServerContext` stays hardcoded in top-level convenience APIs or the public facade gains context/module parameters so frameworks do not rely on Libero's standalone convention.
- Whether `libero/remote_data` should be deprecated, relocated to another package, or kept as a small compatibility utility.
- Whether generated filenames such as `decoders.gleam`, `contract.json`, and `generated@libero_wire.erl` should be renamed around request/result/push/flags, or documented as stable historical filenames.
- Whether top-level raw ETF helpers should remain on `libero` or only exist under `libero/etf/wire`.

### Current Rally Usage

Rally uses Libero as a contract/codegen dependency, not as a standalone app framework:

- `/home/daverapin/projects/gleam/rally-gleam/src/rally.gleam` imports `libero` and calls `libero.walk`, `libero.generate_atoms`, `libero.generate_wire_erl`, `libero.generate_decoders_ffi`, `libero.generate_decoders_gleam`, `libero.generate_etf_codec_module`, `libero.generate_json_contract`, and `libero.generate_request_msg_module`.
- `/home/daverapin/projects/gleam/rally-gleam/src/rally/internal/generator/load_libero.gleam` imports `libero/field_type` and `libero/glance_type_resolver`, then generates Rally-owned client/server protocol modules.
- Rally-generated snapshots import `generated/libero/etf as libero_etf` inside `generated/rally/client_protocol.gleam` and `generated/rally/server_protocol.gleam`.
- Rally Scoreboard contains generated Libero artifacts under `src/generated/libero/**`, but app transport, SSR, hydration, browser lifecycle, websocket handling, and broadcast delivery live in Rally/generated app modules.

### Mixed or Obsolete Docs

- `README.md` starts with standalone `server_` handler scanning, `ServerContext`, and client state. Later sections say transport belongs to the app/framework and Rally Scoreboard is canonical. The opening is now the misleading part.
- `README.md` "Client Output" teaches `js_output_dir` as advanced usage without naming it compatibility.
- `llms.txt` is better than the README: it says Libero does not generate client stubs, WebSocket clients, routers, SSR, scaffolded apps, or framework transport. It still lists RemoteData as a provided surface and gives `server_`/`ServerContext` too much weight in the main model.
- `pages/reference/contract-boundary.md`, `pages/protocol/etf-wire-protocol.md`, and `pages/protocol/json-wire-protocol.md` already teach the intended contract-level facade. They should be the source for the README rewrite.

### Recommended Child Bean Order

1. `libero-15r6`: define the API boundary now, including `server_`/`ServerContext`, `libero/wire`, top-level raw ETF helpers, generated filename vocabulary, and RemoteData classification.
2. `libero-ir5g`: add/adjust protocol-facade tests so request/result/push/flags behavior is executable before renames.
3. `libero-kvna`: align naming where it is low-risk or document stable historical names where renaming would break consumers.
4. `libero-zdpp`: rewrite README, llms.txt, and pages around the decided boundary. Use the existing protocol docs as the spine.
5. `libero-r72z`: quarantine or remove compatibility surfaces after tests and docs have made the intended boundary explicit.

### Audit Commands Run

- `rg --files`
- `rg -n "split personality|public surfaces|singular wire|cleanup|facade|boundary|rally" .beans README.md docs src test`
- `rg -n "^pub (type|fn|const)|^pub opaque" src/libero*.gleam src/libero/**/*.gleam`
- `rg -n "RemoteData|RpcData|client state|client-side state|client stub|client stubs|generated client|js_output_dir|LIBERO_JS_OUTPUT_DIR|server_|ServerContext|standalone|transport|framework|Rally|compatibility|Deprecated|libero/wire|raw codec|wire\\.encode|tag_response|tag_push" README.md llms.txt pages src test/fixtures test/libero test/birdie_snapshots`
- `rg -n "libero\\.|libero/field_type|libero/glance_type_resolver|libero/walker|libero/codegen|libero/json|libero/etf|libero/error|libero/remote_data|libero/wire" /home/daverapin/projects/gleam/rally-gleam/src/rally.gleam /home/daverapin/projects/gleam/rally-gleam/src/rally/internal/generator/load_libero.gleam /home/daverapin/projects/gleam/rally-gleam/test/rally/codegen_load_rpc_snapshot_test.gleam /home/daverapin/projects/gleam/rally-scoreboard-example/src /home/daverapin/projects/gleam/rally-scoreboard-example/test`
