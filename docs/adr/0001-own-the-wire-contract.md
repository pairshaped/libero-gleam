# Own The Wire Contract

Status: accepted

Libero owns the typed wire contract for Gleam values that cross a process,
target, or framework boundary. It discovers or receives type seeds, walks the
reachable type graph, and generates the protocol-facing pieces that must stay
in agreement: request types, dispatch code, typed encoders and decoders, atom
registration, wire transformer modules, protocol facades, and contract
artifacts.

## Consequences

Consumers should use generated Libero modules or Libero protocol helpers
instead of hand-writing envelopes, frame parsing, typed decoder registration, or
wire-transformer calls.

Libero can support multiple protocols, including ETF and JSON, without asking
frameworks to rewrite WebSocket lifecycle, routing, SSR, hydration, or app-state
code.
