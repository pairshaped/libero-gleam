---
# libero-15r6
title: Define Libero core API boundary for Rally-style consumers
status: done
type: task
priority: high
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T16:52:13Z
parent: libero-lrc4
blocked_by:
    - libero-t9n0
---

Based on the audit, define the public API boundary Libero should expose to framework consumers. The likely core is type graph walking, wire identity, typed codec generation, generated request/result/push/flags protocol facades, dispatch helpers, and contract artifacts.

Acceptance:
- Document which modules/functions are core API, which are internal, and which are compatibility.
- Decide whether `libero/wire` remains, moves behind explicit legacy naming, or is removed.
- Decide whether standalone handler scanning by `server_` prefix remains core or becomes a compatibility feature.
- Decide naming for transport/request terminology so Rally does not inherit old `server_*` vocabulary.
- Add follow-up beans for any migration too large for this slice.

## Boundary Decision

Libero's core role is a typed wire-contract layer. It derives contract shapes from Gleam source, generates protocol-specific code for those shapes, and exposes request/result/push/flags helpers so frameworks do not hand-roll wire envelopes or frame parsing.

The standalone CLI remains supported, but it is a default generator workflow on top of the same contract engine. It is not the public identity. Rally Scoreboard is the canonical framework-consumer example.

### Core Public API

- `libero.scan`, `libero.scan_excluding`, `libero.collect_seeds`, and `libero.walk`: default contract discovery pipeline.
- `libero.generate_dispatch`, `libero.generate_dispatch_with_extra_params`, `libero.generate_json_dispatch`, and `libero.generate_json_dispatch_with_extra_params`: server dispatch generation.
- `libero.generate_atoms`, `libero.generate_wire_erl`, `libero.generate_decoders_ffi`, `libero.generate_decoders_gleam`, and `libero.generate_etf_codec_module`: ETF generated contract support used by Rally-style frameworks.
- `libero.generate_request_msg_module`: generated request-message type support. Keep the function name for now, but docs should describe it as request-message generation rather than client app generation.
- `libero.generate_json_contract` and `libero.generate_json_contract_hash`: contract artifact generation.
- `libero.PushDispatch`, `libero.ExtraParam`, `libero.Protocol`, and `libero.qualified_atom_name`: supporting types/helpers that let framework generators compose Libero outputs without importing deeper modules.
- `libero/etf/wire`, `libero/json/wire`, and `libero/frame`: protocol-level request/result/push/flags facade. These are the normal integration path.
- `libero/error`, `libero/json/error`, and `libero/trace`: generated boundary support for structured protocol errors and panic-safe dispatch.

### Public but Low-Level/Internal-to-Frameworks

These modules are public because Gleam package boundaries or framework generators need them, but they should be documented as codegen/runtime internals rather than the default user surface:

- `libero/scanner`, `libero/walker`, `libero/field_type`, `libero/glance_type_resolver`, `libero/wire_identity`, `libero/codegen`, `libero/codegen_dispatch`, `libero/codegen_decoders`, `libero/etf/codegen_erl`, `libero/json/codegen`, `libero/json/contract`, and `libero/json/runtime`.
- Raw ETF helpers inside `libero/etf/wire`: `encode`, `decode`, `decode_safe`, `decode_typed`, `tag_response`, `tag_push`, `variant_tag`, and `coerce`. Keep them public because generated modules and tests need them, but docs must call out that normal consumers use `encode_request`, `encode_response`, `encode_push`, `decode_server_frame`, `encode_flags`, and `decode_flags_typed`.

### Compatibility API

- `libero/wire` was removed in the follow-up removal pass. Consumers use `libero/etf/wire`.
- Top-level `libero.ensure`, `libero.encode`, and `libero.decode` are compatibility/convenience ETF wrappers. New docs should use generated `src/generated/libero/etf.gleam` or `libero/etf/wire` protocol helpers instead.
- `js_output_dir`, `LIBERO_JS_OUTPUT_DIR`, `resolve_js_output_dir`, and client file mirroring remain compatibility for standalone split-package consumers. Do not present them as a primary workflow.
- `libero/remote_data` is compatibility/app-helper surface. It may stay for now, but it is not core to Libero's wire-contract role and should be excluded from the main README story.
- CLI `gleam run -m libero` remains supported as the default standalone workflow, but docs must state that frameworks can call the library API and own file placement.

### `server_` and `ServerContext`

Default scanner conventions stay for this cycle:

- Public handler function names start with `server_`.
- The default context type is an unqualified `ServerContext`.
- Top-level `libero.scan` and top-level dispatch generators use `./src`, `server_context`, `ServerContext`, and wire module tag `"libero"`.

However, these are the standalone scanner convention, not the core conceptual model. The public docs should say "handler-derived contract" first, then explain the default scanner convention. Rally-style consumers should be free to build or filter endpoint lists and generate their own request/result/push facade without adopting `server_*` vocabulary in generated Rally APIs.

If we later need configurable scanner conventions, that belongs in a follow-up bean. Do not mix it into the docs cleanup.

### Naming Decision

Public docs and new generated/facade concepts should use:

- Request: client-to-server message envelope.
- Result: server response for a request. Use "response frame" when talking about the protocol frame.
- Push: server-initiated message.
- Flags: SSR/hydration payloads.
- Contract: the derived typed boundary and its artifact.

Libero names the wire-facing generated surface directly: `RequestMsg`, `decoders`, `contract.json`, `generated@libero_wire`, `generated@libero_atoms`, the `"libero"` wire module tag, and `TransportError`.

### Follow-Up Coverage

Existing follow-up beans cover the large migrations:

- `libero-ir5g`: make protocol-facade behavior executable in tests.
- `libero-kvna`: align naming or document stable historical names.
- `libero-zdpp`: rewrite README, llms.txt, and pages around the boundary.
- `libero-r72z`: quarantine or remove compatibility surfaces after docs/tests settle the boundary.

No new follow-up bean is needed from this decision slice.

## Removal Update

The boundary decision changed after confirming Rally is the only active consumer. The compatibility API listed above was removed rather than kept:

- `libero/wire` was deleted.
- `libero/remote_data` was deleted.
- `libero/codegen_wire_erl` was deleted.
- `generate_request_msg_module` was deleted.
- `js_output_dir`, `LIBERO_JS_OUTPUT_DIR`, `resolve_js_output_dir`, and `js_output_dir_from_env` were deleted.
- Generated endpoint response decoders returning `RemoteData` were deleted.

Core API now points directly at `libero/etf/wire`, `libero/etf/codegen_erl`, `generate_request_msg_module`, and `mirrored_output_dir`.
