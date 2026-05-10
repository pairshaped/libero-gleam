# JSON Wire Protocol: Implementation Design

Status: spec
Date: 2026-05-10

## Summary

Add JSON as a second RPC protocol behind Libero's existing protocol boundary.
ETF remains native for Gleam/Lustre/BEAM. JSON exists for generated SDKs,
external tools, debugging, and client code that should not need an ETF
implementation.

The first JSON version has one public shape: readable JSON. No compact,
condensed, indexed, or positional mode.

## Architecture Principle

Keep ETF code untouched. JSON is a parallel implementation with shared types.
Only `libero/wire.gleam` gains a thin protocol-dispatch layer (or that layer
goes in a separate `protocol_wire.gleam` if `wire.gleam` gets bulky).

JSON must preserve Libero's source identity rule. A constructor name is never
enough. Identity basis: module path + type name + constructor name + field types.
No global lookup by bare constructor name. No dispatch by constructor name + arity.
No shape-guessing fallback. No consumer responsibility to make names unique.

## Module Layout

```
libero/
  wire.gleam              # Unchanged ETF API. Imports libero/frame for ServerFrame.
  wire_identity.gleam     # Unchanged. Already protocol-agnostic.
  codegen_wire_erl.gleam  # Unchanged. Stays ETF/BEAM territory.
  codegen_decoders.gleam  # Unchanged. ETF JS decoder registration.
  codegen_dispatch.gleam  # Extended: protocol-aware dispatch delegating to ETF or JSON codegen.
  protocol.gleam          # NEW. Protocol type, re-exported from libero.gleam.
  frame.gleam             # NEW. Protocol-neutral ServerFrame type moved from wire.gleam.
  field_type.gleam        # Unchanged. FieldType stays structural; labels live on DiscoveredVariant.
  walker.gleam            # Extended: DiscoveredVariant gets field_labels: List(Option(String)).
  json/
    wire.gleam            # NEW. JSON encode/decode, frames, SSR flags (text-based).
    codegen.gleam         # NEW. Generates typed JSON encoders/decoders (Gleam + JS FFI).
    contract.gleam        # NEW. Contract artifact generation with canonical hash.
    error.gleam           # NEW. Structured JSON protocol errors with paths.
    limits.gleam          # NEW. JsonLimits type owned by Libero, not passed everywhere manually.
```

Shared types (`ServerFrame`, `DecodeError`, `FieldType`) stay in protocol-neutral
modules. JSON modules import them. No parallel types unless the shape truly differs.

`ServerFrame` moves from `libero/wire.gleam` to a new `libero/frame.gleam` so both
ETF and JSON wire modules can import it without creating a dependency from ETF onto
JSON error types. Both `libero/wire.gleam` and `libero/json/wire.gleam` import
`libero/frame.gleam`.

`ServerFrame` is extended with an `Error` variant:

```gleam
pub type ServerFrame(value) {
  Response(request_id: Int, value: value)
  Push(module: String, value: value)
  Error(request_id: Option(Int), errors: List(#(String, String)))
}
```

The error payload is `List(#(String, String))` — path+message tuples — so the
shared frame module has no dependency on JSON-specific error types.
`libero/json/error.gleam` provides a conversion from `List(JsonError)` to
`List(#(String, String))`.

ETF decode never produces `Error`. Callers that match exhaustively on `ServerFrame`
add a dead arm.

## Protocol Config

`libero/protocol.gleam`:

```gleam
pub type Protocol {
  Etf
  Json
}
```

No env-var derivation. No runtime sniffing. Protocol is baked into generated
config at generation time:

```gleam
pub const protocol = protocol.Etf
// or
pub const protocol = protocol.Json
```

The generated dispatch module bakes the protocol choice into which encode/decode
functions it calls. Consumer code that calls `wire.encode_request(...)` doesn't
branch on protocol; the generated dispatch does.

Client-side JS: generated client transport imports a generated protocol facade
(`generated/protocol_wire.mjs`) that delegates to ETF or JSON FFI. No global
mutable protocol state in Libero JS.

## JSON Wire API

`libero/json/wire.gleam` produces/consumes `String` (JSON text). All encode
functions take already-encoded `json.Json` values — generated typed encoders run
first, then the wire module wraps them in protocol envelopes. This prevents the
unsafe "generic encode guesses custom type identity" path.

```gleam
// Types
pub type RequestEnvelope {
  RequestEnvelope(module: String, request_id: Int, message: Dynamic)
}
// message is the parsed JSON value of the "message" field, ready for typed decode.
// contract_hash and protocol_version have already been validated before the
// envelope is returned.

// Request
pub fn encode_request(
  module: String,
  request_id: Int,
  msg: json.Json,
  contract_hash: String,
) -> String
pub fn decode_request(data: String) -> Result(RequestEnvelope, List(JsonError))
// Validates kind, protocol_version, contract_hash before returning envelope.
// Returns the raw message as Dynamic for the caller to pass through a typed decoder.

// Response
pub fn encode_response(request_id: Int, value: json.Json) -> String
// Emits "protocol_version": "json-rpc-v1" internally. No contract_hash on responses.

// Error
pub fn encode_error(request_id: Option(Int), errors: List(JsonError)) -> String

// Push
pub fn encode_push(module: String, value: json.Json) -> String

// Frames (client-side decode)
pub fn decode_server_frame(data: String) -> Result(ServerFrame(Dynamic), List(JsonError))
// Reads "kind" field. Dispatches to response/push/error.
// Error frames have errors as List(#(String, String)) via the shared ServerFrame type.

// SSR flags
pub fn encode_flags(value: json.Json) -> String
// Returns typed JSON value directly, with HTML-unsafe chars escaped.
pub fn decode_flags_typed(
  flags: String,
  decoder: fn(Dynamic) -> Result(a, List(JsonError)),
) -> Result(a, List(JsonError))
```

The generated JSON codec facade exposes the name-based public boundary used by
Rally:

```gleam
pub fn decode_flags_typed(flags: String, decoder_name: String) -> Result(a, List(JsonError))
```

That generated function selects the typed decoder by name and calls
`libero/json/wire.decode_flags_typed(flags:, decoder:)`. Rally never receives
raw `Dynamic` flags.

Kind-field dispatch replaces tag-byte dispatch. `"response"`, `"push"`, `"error"`.

## Typed Value Shape

Generated encoders produce `json.Json` builders directly. No `Dict(String, Dynamic)`
intermediate.

Generated decoders take `Dynamic` (from `gleam_json` parse) and return `Result(Type, List(JsonError))`.
They validate before constructing typed values.

Labelled constructor fields produce JSON objects. Unlabelled produce JSON arrays.
Mixed labelled/unlabelled constructors are rejected at JSON codegen time.

Decoders enter through expected type, never by global variant name lookup.
The `"type"` field is validated against the expected type, not used as a dispatch key.

## Contract Artifact

`libero/json/contract.gleam` emits a deterministic JSON file. The contract hash
is computed over canonical contract data (not the pretty-printed JSON artifact
string), so formatting and whitespace do not affect it. Same spirit as
`wire_identity`.

Contents: protocol version, contract hash, Libero version, endpoint modules
and request message variants, response value types, push modules and ToClient
types, SSR flag model types, custom type definitions with module path, type name,
variants, field labels, field order, field types, and built-in type encoding rules.

Deterministic: sorted keys, stable iteration order.

## Error Types

`libero/json/error.gleam`:

```gleam
pub type JsonError {
  JsonError(path: String, message: String)
}
```

`path` uses dot/bracket notation: `"message.fields.slug"`,
`"value.fields.comments[3].fields.author"`.

Error accumulation stops on compatibility failures. If `protocol_version` or
`contract_hash` mismatches, return that error immediately. Do not proceed to
typed decode against a stale contract. During typed decode, field errors
accumulate: a frame with three bad fields produces three errors.

## Validation Rules

| Rule | Applied at |
|---|---|
| Top-level must be object | Frame decode |
| `kind` must be known | Frame decode |
| `protocol_version` must match | Frame decode |
| `contract_hash` must match (requests) | Request decode |
| Required envelope fields present | Frame decode |
| Unknown envelope fields rejected | Frame decode |
| `type` must be known for decode path | Typed decode |
| `variant` must match expected type | Typed decode |
| Labelled fields present exactly once | Typed decode |
| Unknown labelled fields rejected | Typed decode |
| Unlabelled fields have correct arity | Typed decode |
| Field values match expected types | Typed decode |
| Int within safe integer range | Encode and decode |
| Float is finite (no NaN, Infinity) | Encode and decode |
| BitArray is valid base64 with padding | Typed decode |
| Strings, arrays, objects, nesting obey limits | Typed decode |

## Security Limits

`libero/json/limits.gleam`:

```gleam
pub type JsonLimits {
  JsonLimits(
    max_input_bytes: Int,       // Applied before parse (byte-level)
    max_nesting_depth: Int,     // Applied after parse (structure-level)
    max_string_length: Int,
    max_array_length: Int,
    max_object_entries: Int,
    max_base64_decoded_bytes: Int,
  )
}
```

`max_input_bytes` is a pre-parse byte limit. Nesting, object, string, and array
limits apply after `gleam_json` parses (structure-level validation). Defaults
are conservative and configurable. Generated facades use generated/default limits
so Rally doesn't become responsible for configuring them.

JS-specific: generated JS decoders create prototype-free objects
(`Object.create(null)`) for dict entries. Own-property-only iteration.

Protocol-owned keys (`__proto__`, `prototype`, `constructor`) are rejected on
frame envelopes and typed value objects. User-labelled fields with these names
(e.g. a field named `constructor`) keep their public JSON field name in the
wire format, but generated JS decoders use a safe internal property mapping
when constructing Gleam values. For `Dict(String, a)` entries, these strings
round-trip as data: decoders read only own properties and construct Gleam dicts
without assigning them as object prototype properties; encoders use
prototype-free objects before printing JSON.

## Codegen Responsibilities

Libero owns: JSON request encoding/decoding, JSON response frame encoding/decoding,
JSON push frame encoding/decoding, JSON SSR flag encoding and typed decoding,
generated typed JSON encoders and decoders, contract artifact generation, JSON
validation and protocol errors.

Rally owns: WebSocket lifecycle, HTTP route integration, request IDs, callbacks,
timeouts, reconnect policy, page/session/topic/client-context concepts, choosing
when generated messages are sent.

Rally must not contain JSON-specific parsing, type reconstruction, frame slicing,
or custom-type dispatch.

## Generated Encoder/Decoder Shape

Encoders produce `json.Json`:

```gleam
pub fn encode_article(value: Article) -> json.Json {
  case value {
    Article(title:, body:) ->
      json.object([
        #("type", json.string("shared/article.Article")),
        #("variant", json.string("Article")),
        #("fields", json.object([
          #("title", json.string(title)),
          #("body", json.string(body)),
        ])),
      ])
  }
}
```

Decoders take `Dynamic`:

```gleam
pub fn decode_article(value: Dynamic) -> Result(Article, List(JsonError)) {
  // Validate object shape, type field, variant field, field presence, field types
  // Then construct
}
```

JS decoders are emitted to `codec_json_ffi.mjs` (parallel to existing
`codec_ffi.mjs`). Each decoder receives a parsed JSON value (plain JS object)
and returns the Gleam-compatible shape with safe property access.

## Walker Extension

`DiscoveredVariant` gains `field_labels: List(Option(String))` parallel to
`fields`. `None` for unlabelled fields, `Some("label")` for labelled ones.
This feeds JSON codegen but is invisible to ETF codegen (which ignores it).

`FieldType` itself is NOT extended. Labels belong to constructor fields, not
to the type of the field. Wire identity stays unchanged.

## Built-In Type Encodings

| Gleam type | JSON shape |
|---|---|
| `String` | JSON string |
| `Bool` | JSON boolean |
| `Int` | JSON integer within JS safe integer range |
| `Float` | JSON number, excluding NaN, Infinity, -Infinity |
| `Nil` | `null` |
| `List(a)` | JSON array |
| `Dict(String, a)` | JSON object |
| `Dict(k, v)` for non-string `k` | JSON array of two-item arrays |
| `Tuple` | JSON array in tuple order |
| `BitArray` | Base64 string with standard padding |
| `Option(a)` | Typed custom shape with variants `Some` and `None` |
| `Result(a, e)` | Typed custom shape |

`Option(a)` must not use `null` as a special case. `None` and `Some(None)` are
different Gleam values and must round-trip distinctly.

Decoders never guess between `Dict(String, a)` and typed custom values. They
always enter through expected type.

## Development Rule

JSON protocol implementation must happen on isolated Libero and Rally worktree
branches. Do not implement directly on `master`.

This work touches protocol config, codegen, generated artifacts, runtime FFI, and
Rally integration. Use paired sibling worktrees so Rally's path dependency points
at the Libero JSON branch:

```text
json-wire-worktrees/
  libero/
  rally/
```

Commit each slice independently. ETF tests must keep passing after each slice.
If a slice cannot pass tests on its own, the commit message must say why and the
next commit must close that gap.

## Implementation Slices

1. **Protocol config** — `libero/protocol.gleam`, `Protocol` type, re-export from `libero.gleam`
2. **Field labels** — Extend `DiscoveredVariant` with `field_labels`, walker carries labels through
3. **JSON error/limits primitives** — `libero/json/error.gleam`, `libero/json/limits.gleam`
4. **Contract artifact** — `libero/json/contract.gleam`, deterministic JSON output, canonical hash
5. **Typed JSON encoders/decoders** — `libero/json/codegen.gleam` for custom types and built-ins
6. **JSON frame helpers** — `libero/json/wire.gleam`, request/response/push/SSR/error frames
7. **Rally routing** — Generated Rally code routes through protocol helpers
8. **Client fixture** — Small non-Gleam client sends one request and decodes one response
9. **Realworld** — Rally Realworld through RPC, push, SSR flags, client context, page init with JSON selected

Each slice keeps ETF tests passing. Slices 1-6 are pure Libero. Slices 7-9 involve Rally.

## Acceptance Criteria

- ETF remains the default protocol.
- A generated config can select JSON without changing user handler code.
- JSON request, response, push, and SSR flags use the documented shapes.
- Rally does not import JSON parser helpers or inspect JSON envelopes directly.
- v3 can regenerate against JSON without application code learning the protocol.
- Malformed JSON returns structured errors with paths.
- Duplicate variant names across modules remain distinct through generated typed encoders/decoders.
- No JSON encoder or decoder uses bare constructor names as global identity.
- `Option(Option(a))` round-trips without collapsing `Some(None)` into `None`.
- Mixed labelled/unlabelled constructors fail at codegen with a clear JSON-only error.
- Protocol version and contract hash mismatches return protocol error responses.
- The contract artifact is deterministic and snapshot-tested.
- A simple external client can be written from the JSON docs plus the contract artifact.
- Realworld passes through RPC, push, SSR flags, client context, and page init with JSON selected.
