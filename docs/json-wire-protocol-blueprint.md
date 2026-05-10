# JSON Wire Protocol Blueprint

Status: blueprint
Date: 2026-05-10

## Summary

Libero should add JSON as a second RPC protocol behind the protocol boundary that
already exists. ETF remains the native protocol for Gleam, Lustre, and BEAM-first
deployments. JSON exists for generated SDKs, external tools, debugging,
inspection, and client code that should not need an ETF implementation.

This is an RPC protocol. It serializes Libero messages, frames, pushes, and SSR
flags. It is not a REST resource surface.

The first JSON version has one public shape: readable JSON. There is no compact,
condensed, indexed, or positional mode in this blueprint. Compression can handle
repeated structural fields for most real traffic, and extra modes would add
support cost before we know they are needed.

## Goals

- Keep normal Gleam handlers and types as the source of truth.
- Keep Rally and downstream apps behind Libero protocol helpers.
- Make the JSON shape readable enough for logs, fixtures, docs, and SDK authors.
- Make generated SDKs possible without requiring ETF knowledge.
- Preserve ETF behavior and performance for existing Gleam and Rally users.
- Give malformed input structured errors with useful paths.
- Make contract changes visible through a generated contract artifact.

## Non-Goals

- Replace ETF.
- Create a REST API.
- Generate Rust or Go clients in the first JSON branch.
- Support multiple JSON output modes.
- Support batched requests or streaming responses.
- Preserve wire compatibility with the ETF frame bytes.
- Let consumers build protocol envelopes by hand inside Rally or v3.

## Development Rule

JSON protocol implementation must happen on isolated Libero and Rally worktree
branches. Do not implement this directly on `master`.

This work touches protocol config, codegen, generated artifacts, runtime FFI, and
Rally integration. It will be disruptive while in progress. Use paired sibling
worktrees so Rally's path dependency points at the Libero JSON branch:

```text
json-wire-worktrees/
  libero/
  rally/
```

Commit each slice independently. ETF tests should keep passing after each slice.
If a slice cannot pass tests on its own, the commit message must say why and the
next commit must close that gap.

## Boundary Rule

All protocol traffic goes through Libero-owned operations:

```text
encode_request(module, request_id, msg)
decode_request(data)
encode_response(request_id, value)
decode_server_frame(data)
encode_push(module, value)
encode_flags(value)
decode_flags_typed(flags, decoder_name)
```

The configured protocol decides whether these operations produce ETF bytes or
JSON text. Consumer code should not branch on ETF versus JSON. Rally may choose
the protocol in generated config and may pass text frames instead of binary
frames, but routing, timeouts, topics, reconnects, hydration, and dispatch should
stay protocol-agnostic.

For JSON, the static `libero/json/wire` helper takes a decoder function for SSR
flags. The generated Libero codec facade keeps the public name-based
`decode_flags_typed(flags, decoder_name)` boundary by selecting the typed decoder
and passing it to that helper. Rally never receives raw dynamic flag data.

## Identity Rule

JSON must preserve Libero's source identity rule. A constructor name is never
enough to identify a value. The identity basis is:

```text
module path + type name + constructor name + field types
```

The readable JSON shape may include `"variant": "Loaded"` for humans, but
generated encoders and decoders must validate the surrounding `"type"` and field
contract before constructing a value. Two modules can both define `Loaded`, and
they must remain distinct on the wire.

This is the rule we do not break:

- No global lookup indexed by bare constructor name.
- No dispatch indexed only by constructor name and arity.
- No fallback that guesses a type from a JSON object shape.
- No consumer responsibility to make names unique.

If JSON cannot preserve source identity through generated typed encoders and
decoders, the JSON protocol should not ship.

## Protocol Selection

Libero should expose protocol selection as generated configuration. The exact
Gleam API can follow existing config patterns, but the model is:

```gleam
pub type Protocol {
  Etf
  Json
}
```

`Etf` is the default. `Json` selects the readable JSON protocol described here.
The choice should be explicit config, not environment-derived. A production
system may expose JSON to third-party clients, and a development system may use
ETF while testing internal flows.

## Transport Encoding

ETF uses the current binary format.

JSON uses UTF-8 JSON text:

- WebSocket JSON messages should be text frames.
- HTTP JSON RPC should use `application/json` unless a more specific media type
  is introduced later.
- SSR flags should be a JSON string that is safe to embed in a script tag.

`encode_flags` must escape `<`, `>`, `&`, U+2028, and U+2029 before the JSON is
written into HTML.

## Envelope Shapes

### Request

```json
{
  "kind": "request",
  "protocol_version": "json-rpc-v1",
  "contract_hash": "example-contract-hash",
  "module": "rpc",
  "request_id": 1,
  "message": {
    "type": "shared/messages.MsgFromClient",
    "variant": "GetArticle",
    "fields": {
      "slug": "hello-world"
    }
  }
}
```

Rules:

- `kind` must be `"request"`.
- `protocol_version` must match the server's JSON protocol version.
- `contract_hash` must match the generated contract artifact the server is
  using.
- `module` is the same logical module tag used by the ETF request helper.
- `request_id` must be an integer from `0` through `4294967295`, matching the
  current ETF request ID range.
- `message` is a typed Libero value.

The protocol version and contract hash are not a full negotiation system. The
first JSON version uses fail-fast compatibility checks: if either value does not
match, the server returns a protocol error response instead of trying to decode
the message.

### Response

```json
{
  "kind": "response",
  "protocol_version": "json-rpc-v1",
  "request_id": 1,
  "value": {
    "type": "gleam/result.Result",
    "variant": "Ok",
    "fields": [
      {
        "type": "shared/article.Article",
        "variant": "Loaded",
        "fields": {
          "title": "Hello",
          "body": "..."
        }
      }
    ]
  }
}
```

Rules:

- `kind` must be `"response"`.
- `protocol_version` must be `"json-rpc-v1"`.
- `request_id` must match a client request.
- `value` is the generated dispatch response value for that request.

### Error

```json
{
  "kind": "error",
  "protocol_version": "json-rpc-v1",
  "request_id": 1,
  "errors": [
    {
      "path": "message.fields.slug",
      "message": "expected String, got Null"
    }
  ]
}
```

Rules:

- `kind` must be `"error"`.
- `protocol_version` must be `"json-rpc-v1"`.
- `request_id` is present when the request ID could be read safely. It is `null`
  when the request ID was missing, malformed, or unsafe.
- `errors` must contain at least one structured protocol error.
- SDKs should surface this as a transport/protocol error, not as a handler
  domain error.

### Push

```json
{
  "kind": "push",
  "protocol_version": "json-rpc-v1",
  "module": "public/pages/article",
  "value": {
    "type": "public/pages/article.ToClient",
    "variant": "CommentsUpdated",
    "fields": {
      "comments": []
    }
  }
}
```

Rules:

- `kind` must be `"push"`.
- `protocol_version` must be `"json-rpc-v1"`.
- `module` is a Libero/Rally channel tag, not always a Gleam module path. For
  RPC requests it is usually `"rpc"`. For Rally page pushes it is the page tag
  used by generated routing. For client context it is `"__ClientContext__"`.
- `value` must pass through the generated typed push encoder before framing.

### SSR Flags

For JSON, SSR flags are the encoded typed value itself:

```json
{
  "type": "public/pages/article.Model",
  "variant": "Model",
  "fields": {
    "article": null,
    "loading": true
  }
}
```

Rally still calls `encode_flags` on the server and the generated
`decode_flags_typed(flags, decoder_name)` facade during hydration. Rally should
not parse this shape directly.

## Typed Value Shape

Custom types encode as:

```json
{
  "type": "module/path.TypeName",
  "variant": "VariantName",
  "fields": {}
}
```

For labelled constructor fields, `fields` is an object whose entries are the
source labels:

```gleam
pub type Article {
  Article(title: String, body: String)
}
```

```json
{
  "type": "shared/article.Article",
  "variant": "Article",
  "fields": {
    "title": "Hello",
    "body": "..."
  }
}
```

For unlabelled constructor fields, `fields` is an array in declaration order:

```gleam
pub type Pair {
  Pair(String, Int)
}
```

```json
{
  "type": "shared/pair.Pair",
  "variant": "Pair",
  "fields": ["count", 2]
}
```

Zero-field variants use an empty object:

```json
{
  "type": "shared/status.Status",
  "variant": "Ready",
  "fields": {}
}
```

The JSON branch must extend type discovery so generated codecs know whether each
constructor field was labelled. The current ETF wire identity can stay based on
field order and field types. JSON readability needs labels where source code has
labels.

Constructors with mixed labelled and unlabelled fields are rejected by the JSON
codegen in the first branch. They remain valid for ETF. Rejection is less clever
than inventing a half-object half-array JSON shape, and it keeps the public JSON
surface easy to explain. A later branch can add a tagged mixed-field shape if a
real contract needs it.

Readable names are not identity by themselves. The generated JSON decoder must
enter through an expected type or through a contract artifact lookup that
includes the full source identity. It must not accept `"variant": "Article"` and
then search globally for a matching constructor.

## Built-In Type Shapes

Built-ins use typed context from the generated decoder. Decoders should reject
the same JSON shape when it appears at the wrong expected type.

| Gleam type | JSON shape |
| --- | --- |
| `String` | JSON string |
| `Bool` | JSON boolean |
| `Int` | JSON integer within JavaScript safe integer range |
| `Float` | JSON number, excluding `NaN`, `Infinity`, and `-Infinity` |
| `Nil` | `null` |
| `List(a)` | JSON array |
| `Dict(String, a)` | JSON object |
| `Dict(k, v)` for non-string `k` | JSON array of two-item arrays |
| `Tuple` | JSON array in tuple order |
| `BitArray` | Base64 string with standard padding |
| `Option(a)` | Typed custom shape with variants `Some` and `None` |
| `Result(a, e)` | typed custom shape unless a later SDK layer wraps it |

The first branch should reject integers outside the JavaScript safe integer
range instead of silently changing values. A later branch can add a tagged
big-integer representation if real contracts need it.

Encoders must reject Int values outside the JavaScript safe integer range. They
must not truncate, round, stringify, or silently change the value.

`Option(a)` must not use `null` as a special case. `None` and `Some(None)` are
different Gleam values, so the JSON shape must preserve that difference:

```json
{
  "type": "gleam/option.Option",
  "variant": "Some",
  "fields": [
    {
      "type": "gleam/option.Option",
      "variant": "None",
      "fields": {}
    }
  ]
}
```

`Nil` remains JSON `null`.

Decoders never guess between `Dict(String, a)` and typed custom values. They
always enter through an expected type. If the expected type is `Dict(String, a)`,
a JSON object is decoded as a dict. If the expected type is a custom type, the
object must have the custom type shape.

## Contract Artifact

The JSON branch should emit a contract artifact next to generated code. It is
used for docs, fixtures, SDK generation, and snapshot checks.

The artifact should include:

- Protocol version.
- Contract hash.
- Libero version.
- Endpoint modules and request message variants.
- Response value type for each endpoint.
- Push modules and their `ToClient` types.
- SSR flag model types.
- Custom type definitions with module path, type name, variants, field labels,
  field order, and field types.
- Built-in type encoding rules.

The artifact should be deterministic. Reordering source files without changing
the contract should produce the same artifact.

## Validation And Errors

Generated JSON decoders must validate before constructing typed values:

- Top-level JSON must be an object for frames and requests.
- `kind` must be one of the known frame kinds for that decode path.
- `protocol_version` must match exactly.
- `contract_hash` must match on requests.
- Required envelope fields must be present.
- Unknown envelope fields are errors.
- `type` must be known for the expected decode path.
- `variant` must be known for the expected type.
- Labelled fields must be present exactly once.
- Unknown labelled fields are errors.
- Unlabelled fields must have the expected array length.
- Field values must match expected types.
- `Int` values must be safe JSON integers.
- `Float` values must be finite.
- Strings, arrays, objects, and nesting depth must obey configured limits.
- `BitArray` strings must be valid base64 with padding.

Errors should include the path and expected type:

```text
message.fields.slug: expected String, got Null
value.fields.comments[3].fields.author.fields.id: expected Int, got String
```

The decoder result should use structured protocol errors. Consumers should not
parse JSON parser exception strings.

## Security Limits

Libero should apply limits before or during decode:

- Maximum input bytes.
- Maximum nesting depth.
- Maximum string length.
- Maximum array length.
- Maximum object entry count.
- Maximum base64 decoded byte length.

The defaults can be conservative and configurable. The limits must apply to JSON
requests, JSON frames, and JSON SSR flags.

JavaScript decoders must create plain data without prototype mutation hazards.
`__proto__`, `prototype`, and `constructor` must not be written as raw object
properties by generated JavaScript decoders. Protocol-owned objects reject those
field names. User-labelled fields with those names use a generated safe property
mapping internally while preserving the public JSON field name. For example,
`constructor` can appear in JSON, but generated JS must store it with a safe
internal name before constructing the Gleam value.

`Dict(String, a)` entries are user data, so string entries named `__proto__`,
`prototype`, or `constructor` should round-trip as data. Decoders must read only
own properties and construct Gleam dicts without assigning those strings as
object prototype properties. Encoders must use a prototype-free object or an
equivalent safe builder before printing JSON.

## Codegen Responsibilities

Libero owns:

- JSON request encoding and decoding.
- JSON response frame encoding and decoding.
- JSON push frame encoding and decoding.
- JSON SSR flag encoding and typed decoding.
- Generated typed JSON encoders and decoders.
- Contract artifact generation.
- JSON validation and protocol errors.

Rally owns:

- WebSocket lifecycle.
- HTTP route integration.
- Request IDs, callbacks, timeouts, and reconnect policy.
- Page, session, topic, and client-context concepts.
- Choosing when generated messages are sent.

Rally must not contain JSON-specific parsing, type reconstruction, frame slicing,
or custom-type dispatch.

## Implementation Slices

1. Add protocol config and keep ETF as the default.
2. Add a generated contract artifact for the current discovered contract.
3. Extend type discovery to retain constructor field labels.
4. Generate JSON typed encoders and decoders for built-ins and custom types.
5. Add JSON request, response, push, and SSR flag helpers behind `libero/wire`.
6. Route Rally generated code through the same protocol helpers.
7. Add a small non-Gleam client fixture that sends one request and decodes one
   response using only the JSON contract docs.
8. Run Rally realworld through RPC, push, SSR flags, client context, and page
   init with JSON selected.

Each slice should keep ETF tests passing.

## Acceptance Criteria

- ETF remains the default protocol.
- A generated config can select JSON without changing user handler code.
- JSON request, response, push, and SSR flags use the documented shapes.
- Rally does not import JSON parser helpers or inspect JSON envelopes directly.
- v3 can regenerate against JSON without application code learning the protocol.
- Malformed JSON returns structured errors with paths.
- Duplicate variant names across modules remain distinct through generated typed
  encoders and decoders.
- No JSON encoder or decoder uses bare constructor names as global identity.
- `Option(Option(a))` round-trips without collapsing `Some(None)` into `None`.
- Mixed labelled/unlabelled constructors fail at codegen with a clear JSON-only
  error.
- Protocol version and contract hash mismatches return protocol error responses.
- The contract artifact is deterministic and snapshot-tested.
- A simple external client can be written from the JSON docs plus the contract
  artifact.
- Realworld passes through RPC, push, SSR flags, client context, and page init
  with JSON selected.

## Open Decisions For Implementation

- Exact config API shape.
- Exact contract artifact file name and path.
- Whether JSON HTTP RPC needs a Libero-specific media type.
- Default values for size and depth limits.
- Whether large `Int` support is needed in the first JSON branch.
