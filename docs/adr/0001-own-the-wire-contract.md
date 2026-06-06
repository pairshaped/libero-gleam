# Own The Wire Contract

Status: accepted

Libero owns the typed wire contract for Gleam values that cross a process,
target, or framework boundary. Frameworks supply type seeds. Libero walks the
reachable type graph and generates the protocol-facing pieces that must stay in
agreement: typed encoders and decoders, atom registration, wire transformer
modules, protocol helper facades, and contract artifacts.

## Consequences

Consumers should use generated Libero modules or Libero protocol helpers instead
of hand-writing envelopes, frame parsing, typed decoder registration, or
wire-transformer calls.

Libero can support multiple protocols, including ETF and JSON, without asking
frameworks to rewrite WebSocket lifecycle, routing, SSR, hydration, or app-state
code.

Frameworks own application-facing request, result, push, routing, transport,
and SSR glue.
