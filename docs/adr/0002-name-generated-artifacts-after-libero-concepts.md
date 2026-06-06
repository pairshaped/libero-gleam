# Name Generated Artifacts After Libero Concepts

Status: accepted

Generated Libero artifacts use Libero's wire-contract vocabulary. JavaScript
decoder registration lives in `decoders_ffi.mjs` and `decoders.gleam`, the
contract artifact is `contract.json`, Erlang modules use
`generated@libero_atoms` and `generated@libero_wire`, and wire-level framework
failures use `TransportError`.

## Consequences

The generated file names describe the artifact's role instead of implying a
standalone client, app state helper, handler scanner, or generic remote-call
system.

Consumers that check in generated Libero files should check in these names under
`src/generated/libero/**`.

Framework-owned generated request and result modules should use framework
names, as Rally does under `src/generated/rally/**`.
