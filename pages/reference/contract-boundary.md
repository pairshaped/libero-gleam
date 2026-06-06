# Contract Boundary Spec

## Summary

Libero owns the typed wire-contract artifacts for values selected by a
framework. The framework supplies type seeds. Libero walks the reachable custom
type graph and generates protocol-facing code that must agree across BEAM,
JavaScript, ETF, JSON, and contract artifacts.

Libero does not own handler discovery, dispatch, routing, request correlation,
WebSocket lifecycle, SSR composition, hydration, broadcast delivery, or app
state. Rally owns those layers.

## Ownership

Libero owns:

- Seeded type graph traversal.
- Structured field type resolution.
- ETF atom pre-registration.
- ETF wire transformer generation.
- JavaScript ETF typed decoder generation.
- ETF request, response, push, and flags wire helpers.
- JSON typed value codec generation.
- JSON request, response, push, and flags wire helpers.
- JSON contract artifacts and contract hashes.
- Wire identity hashes and collision checks.
- Protocol decode errors and security limits.

Frameworks own:

- Which page, request, result, push, SSR, and error types cross the boundary.
- Generated app-facing request/result/push modules.
- Transport lifecycle.
- HTTP and WebSocket routing.
- Retry, timeout, reconnect, and auth policy.
- How decoded values affect application state.
- Where generated source files are written.

The short rule: framework code decides what crosses the boundary and when.
Libero decides how those typed values become protocol data and back.

## Consumer API Shape

Rally-style consumers call the top-level library API:

```gleam
let assert Ok(discovered) = libero.walk(seeds)
let atoms = libero.generate_atoms(discovered:, atoms_module:, wire_module:)
let assert Ok(wire) = libero.generate_wire_erl(discovered:, wire_module:)
let decoders_js =
  libero.generate_decoders_ffi(discovered:, package:, dependency_packages:)
let decoders_gleam = libero.generate_decoders_gleam()
let etf = libero.generate_etf_codec_module(atoms_module:, decoders_module:)
let contract =
  libero.generate_json_contract(discovered:, push_types:, ssr_models:)
```

The functions return strings. Frameworks own file I/O and generated module
layout.

## Runtime Helpers

ETF helpers live in `libero/etf/wire`. JSON helpers live in `libero/json/wire`.
The generated ETF module from `generate_etf_codec_module` exposes only
`ensure`, `encode`, and `decode`, which is the surface Rally's generated
protocol modules use. The lower-level runtime helper names describe protocol
concepts used by the codec runtimes and tests:

| Concept | Helper |
|---------|--------|
| Encode an outbound request envelope | `encode_request` |
| Decode an inbound request envelope | `decode_request` |
| Encode a response frame | `encode_response` |
| Decode a server frame | `decode_server_frame` |
| Encode a push frame | `encode_push` |
| Encode SSR flags | `encode_flags` |
| Decode SSR flags | `decode_flags_typed` |

Rally-generated modules own request ids, result envelopes, frame tags, and page
dispatch around the generated codec module. Application code should not inspect
ETF frame bytes, assemble JSON envelopes by hand, or call raw wire-transformer
functions for normal traffic.

## Generated Modules

The supported generated artifact set is:

- `generated@libero_atoms.erl`
- `generated@libero_wire.erl`
- `decoders_ffi.mjs`
- `decoders.gleam`
- `etf.gleam`
- `contract.json`

Frameworks may generate their own request/result/push facade around those
artifacts. Libero should not generate framework-specific app glue.

## Security Model

The protocol boundary is where malformed input becomes typed data. Libero
should make that boundary auditable.

The boundary should enforce:

- Valid request envelope shape.
- Known response or push frame shape.
- Known custom type identity.
- Expected field type.
- Size limits.
- Nesting limits.
- Safe atom behavior for ETF.
- JSON prototype-pollution guards.

The caller should receive structured protocol errors. Consumers should not parse
codec exception strings.

## Acceptance Criteria

- Rally can regenerate its Libero artifacts without any standalone scanner or
  dispatch code.
- Rally can send and receive ETF request, response, push, and SSR flag data
  through generated protocol modules.
- JSON codec and contract tests continue to cover the same seeded type graph.
- JavaScript and Erlang exhaustive codec tests remain in place.
- No public Libero code path exists solely for non-Rally legacy consumers.
