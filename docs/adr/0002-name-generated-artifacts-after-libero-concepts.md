# Name Generated Artifacts After Libero Concepts

Status: accepted

Generated Libero artifacts use Libero's current boundary vocabulary. Request
payloads are named `RequestMsg`, JavaScript decoder registration lives in
`decoders_ffi.mjs` and `decoders.gleam`, the contract artifact is
`contract.json`, Erlang modules use `generated@libero_atoms` and
`generated@libero_wire`, the default envelope module tag is `"libero"`, and
wire-level framework failures use `TransportError`.

## Consequences

The generated file names describe the artifact's role instead of implying a
standalone client, app state helper, or generic remote-call system.

Consumers that check in generated Libero files should check in these names under
`src/generated/libero/**`.
