# Contract Boundary Spec

## Summary

Libero derives a typed client/server contract from Gleam handler signatures and
generates the code needed for both sides to speak that contract. Consumers use
generated modules and runtime helpers. They should not need to know the wire
protocol shape, raw codec details, or frame layout.

The boundary is simple: consumers call contract-level helpers instead of
reaching into ETF frames, JSON envelopes, raw decoders, or hand-built request
values.

The consumer should be protocol-agnostic. Whether Libero is using ETF, JSON, or
another protocol later, consumer code should keep calling the same generated
contract helpers. Consumers may regenerate Libero-owned modules or update facade
imports, but they should not rewrite transport logic, response handling, push
handling, or hydration logic because the configured protocol changed.

Different consumers can choose different protocols. Gleam and Lustre clients can
use ETF. A Rust CLI, Go tool, or hand-written JavaScript client can choose JSON.
Both paths come from the same Libero contract.

## Ownership

Libero owns:

- Handler scanning.
- Reachable type discovery.
- Contract artifacts.
- Server dispatch generation.
- Typed client codec generation.
- Request envelope encoding and decoding.
- Response frame encoding and decoding.
- Push frame encoding and decoding.
- SSR flag encoding and decoding when the value is part of a Libero-derived
  contract.
- Protocol validation and malformed protocol errors.
- Protocol security limits.

Consumers own:

- Transport lifecycle.
- HTTP routes and WebSocket connection management.
- Retry, timeout, and reconnect policy.
- Framework concepts such as pages, sessions, topics, and app state.
- When a generated message should be sent.
- How decoded messages affect the application.

The short rule: handlers define what messages exist. Consumers decide when to
send those messages and what to do with decoded values. Libero decides how typed
messages become protocol data and back.

## Consumer API Shape

Consumers should call Libero through operations that name the protocol concept,
not the byte format. Protocol helpers should live under matching module paths,
such as `libero/etf/wire` and `libero/json/wire`.

Each protocol helper module should expose the same contract-level operations:

| Concept | Helper |
|---------|--------|
| Encode an outbound request | `encode_request` |
| Decode an inbound request | `decode_request` |
| Encode a response frame | `encode_response` |
| Decode a server frame | `decode_server_frame` |
| Encode a push frame | `encode_push` |
| Encode SSR flags | `encode_flags` |
| Decode SSR flags | `decode_flags_typed` |

ETF may also expose lower-level frame helpers for callers that already know the
frame kind. Most consumers should use `decode_server_frame` and let Libero
inspect the frame.

## Boundary Shape

The contract boundary has these parts:

- The scanner and walker derive the handler contract from source.
- Dispatch codegen turns request messages into handler calls.
- Wire transformers move type identity into generated code.
- JavaScript decoder codegen reconstructs typed values from wire values.
- `libero/etf/wire` and `libero/json/wire` own request, response, push, and
  SSR flag helpers for their protocols.
- Consumers receive WebSocket frames through `decode_server_frame` or a
  generated wrapper.
- Consumers send requests through `encode_request` or a generated wrapper.
- Servers send responses through `encode_response`.
- Server pushes pre-encode typed payloads through generated push dispatch before
  framing.
- SSR flags use generated flag helpers.

Raw codec functions still exist, but they are not the framework integration
path. `wire.encode` is documented as unsafe for user custom types unless the
value has already passed through a typed encoder.

The remaining low-level surface is intentional but sharp. It should stay for
tests, protocol internals, and advanced escape hatches. Framework consumers
should stay on the typed helpers.

## Target Frame API

Libero should expose a decoded frame type. For example:

```gleam
pub type ServerFrame(value) {
  Response(request_id: Int, value: value)
  Push(module: String, value: value)
}
```

On JavaScript, the runtime can expose the same idea as tagged objects:

```js
{ kind: "response", requestId, value }
{ kind: "push", module, value }
```

The exact representation can change. The invariant is that consumers never
read tag bytes or slice request IDs out of raw frames.

## Generated Modules

Generated modules should be the main consumer interface. A framework may still
compose generated files into its own package, but the package should expose
contract-level operations rather than raw codec operations.

Examples of generated outputs Libero may own over time:

- Contract artifact.
- Server dispatch.
- Server wire module.
- Client message constructors or mirrors.
- Client encoders and decoders.
- Frame helpers.
- SSR flag helpers.

This does not mean Libero owns framework-specific transport code. A WebSocket
client can still live in a consumer framework. It should call Libero's generated
facade instead of matching frame bytes, selecting raw decoders, or building
request envelopes by hand.

## Security Model

The protocol boundary is where hostile or malformed input becomes typed data.
Libero should make that boundary auditable.

The boundary should enforce:

- Valid request envelope.
- Known message type.
- Known response or push frame shape.
- Known variant.
- Expected field type.
- Size limits.
- Nesting limits.
- Safe atom behavior for ETF, or equivalent validation for JSON.

The caller should receive structured protocol errors. Consumers should not parse
codec exception strings.

## Acceptance Criteria

- A consumer can send an RPC request without knowing the wire envelope shape.
- A consumer can receive a response without knowing frame tag bytes.
- A consumer can receive a push without knowing frame tag bytes.
- A consumer can hydrate flags through generated Libero helpers.
- Generated consumer code does not import raw decode functions for normal RPC
  traffic.
- Generated consumer code does not match frame bytes.
- Existing ETF behavior is preserved while the boundary is tightened.
- Server push payloads pass through generated typed pre-encoders before framing.
- JSON can be added as a configured protocol without rewriting consumer
  transport lifecycle, response handling, push handling, or hydration logic.
