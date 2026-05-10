# Contract Boundary Spec

Status: implemented boundary, JSON-ready facade
Date: 2026-05-10

## Summary

Libero derives a typed client/server contract from Gleam handler signatures and
generates the code needed for both sides to speak that contract. Consumers use
generated modules and runtime helpers. They should not need to know the wire
protocol shape.

This is the direction Libero has been moving toward. The first boundary pass is
now in place: consumers call protocol-level helpers instead of reaching into ETF
frames, raw decoders, or hand-built request envelopes.

The test is simple: adding JSON RPC as a configured protocol should not require
consumer code to understand JSON. ETF remains valuable and should not be thrown
away. Consumers may regenerate Libero-owned modules or update facade imports.
They should not rewrite transport logic, response handling, push handling, or
hydration logic because the configured protocol changed.

The target is not one protocol to rule every client. Gleam and Lustre clients
can keep using ETF. A Rust CLI, Go tool, or hand-written JavaScript client can
choose JSON. Both paths should be derived from the same Libero contract.

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

The short rule: consumers decide what messages exist and when to send them.
Libero decides how typed messages become protocol data and back.

## Consumer API Shape

Consumers should call Libero through operations that name the protocol concept,
not the byte format:

```text
encode_request(module, request_id, msg)
decode_request(bytes)
encode_response(request_id, value)
decode_response_frame(bytes)
encode_push(module, msg)
decode_push_frame(bytes)
encode_flags(value)
decode_flags(bytes_or_string, decoder)
```

The current API names differ a little from this sketch. The important part is
that callers ask Libero for "request", "response", "push", or "flags" behavior.
They do not assemble or slice wire frames themselves.

## Current State

Libero now owns the protocol boundary for the active ETF path:

- The scanner and walker derive the handler contract from source.
- Dispatch codegen turns request messages into handler calls.
- Wire transformers move type identity into generated code.
- JavaScript decoder codegen reconstructs typed values from wire values.
- `libero/wire` owns request, response, push, and SSR flag helpers.
- Rally receives WebSocket frames through `decode_server_frame`.
- Rally sends requests through `encode_request`.
- Server responses use `encode_response`.
- Server pushes pre-encode typed payloads through generated `encode_push/2`
  dispatch before framing with `wire.encode_push`.
- SSR flags use `encode_flags` and `decode_flags_typed`.

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
client can still live in Rally. It should just call Libero's protocol facade.

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

## Migration Status

Done:

- Higher-level Libero frame APIs exist while keeping the current ETF format.
- JavaScript response and push frame decoding goes through Libero helpers.
- SSR flag encode/decode goes through Libero helpers for contract values.
- Rally generated transport no longer imports raw decode operations.
- Outbound requests, server responses, server pushes, and SSR flags have typed
  boundary helpers.
- The RealWorld CLI uses Libero helpers instead of matching frame bytes.

Next:

- Keep raw codec calls out of Rally and generated consumer code.
- Evaluate JSON as a second configured Libero protocol behind the same facade.

## Acceptance Criteria

- A consumer can send an RPC request without knowing the wire envelope shape.
- A consumer can receive a response without knowing frame tag bytes.
- A consumer can receive a push without knowing frame tag bytes.
- A consumer can hydrate flags through generated Libero helpers.
- Rally no longer imports raw decode functions in generated transport code.
- The RealWorld CLI uses a Libero helper instead of matching frame bytes.
- Existing ETF behavior is preserved while the boundary is tightened.
- Server push payloads pass through generated typed pre-encoders before framing.
- The JSON spike can add a configured protocol without rewriting Rally's
  transport lifecycle, response handling, push handling, or hydration logic.

## Non-Goals

- Move WebSocket connection management into Libero.
- Move Rally page, topic, session, or reconnect semantics into Libero.
- Generate every possible third-party client in the first pass.
- Keep raw codec functions as the recommended framework integration API.

Raw codec functions may stay for low-level tests or advanced use. They should
not be the path framework consumers reach for first.
