---
# libero-zdpp
title: Rewrite Libero docs around the singular wire-contract role
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T16:52:13Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Update README, llms.txt, Hex docs pages, and design/reference docs so Libero has one public story: a typed wire-contract and protocol-codegen layer used by frameworks such as Rally. The docs should point to Rally Scoreboard as the canonical framework integration.

Acceptance:
- Docs no longer present generated client mirroring, RemoteData/client state, or standalone `server_` scanning as the primary Libero identity unless explicitly marked compatibility.
- Docs clearly explain ETF/JSON protocol facades, request/result/push/flags ownership, and what consumers should not implement themselves.
- ADR/reference docs describe current/intended design, not migration history.
- `gleam docs build` passes if available.

## Result

Rewrote the README opening around Libero as a typed wire-contract layer instead of a standalone transport/client-state generator. The default `server_`/`ServerContext` scanner convention is still documented, but it now sits under the core model rather than defining the package identity.

Updated README generated-file and advanced-usage sections:

- Added generated `etf.gleam` as the ETF request/result/push/flags facade.
- Expanded "Transport Is Yours" to include browser lifecycle, SSR, routing, and app state.
- Marked mirrored client output through `js_output_dir` as compatibility.

Updated `llms.txt` so future agent work inherits the same boundary:

- Libero is described as a typed wire-contract library.
- Default scanner conventions are called scanner conventions, not the whole design.
- Rally owns request/result/push API and transport lifecycle.
- RemoteData was later removed from Libero in the removal pass.
- Generated dispatch example uses `wire.encode_response` instead of raw `tag_response` plus `encode`.

Updated the `libero/etf/wire` source comment that still said "generated client stub functions".

The protocol and contract docs in `pages/` already described the intended boundary and did not need content churn for this slice.

Validation:

- `gleam format`
- `gleam docs build`
- `gleam test --target erlang`

The full Erlang suite passed 545 tests. It still reports the existing unreachable-code warning in `test/libero/dispatch_panic_test.gleam`, and the expected error text from formatter/error fixture tests.

## Removal Update

Updated README and `llms.txt` again after the removal pass:

- Removed compatibility language for `js_output_dir` and `LIBERO_JS_OUTPUT_DIR`.
- Removed `libero/wire` and `libero/remote_data` from the module map.
- Replaced the RemoteData error-model description with the actual wire envelope shape: domain errors are `Ok(Error(domain))`, transport errors are `Error(TransportError)`.
- Kept mirrored output documented as a current split-package generation option via `mirrored_output_dir`.
