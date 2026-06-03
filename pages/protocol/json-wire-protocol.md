# JSON Wire Protocol

JSON is Libero's readable wire protocol for SDKs, tools, logs, fixtures, and
clients that should not need an ETF implementation. It uses the same typed
contract as ETF, but carries type identity as readable JSON fields.

JSON is an RPC protocol. It serializes Libero requests, responses, pushes, and
SSR flags. It is not a REST resource format.

The canonical typed value contract is named `typed-json-v1`. Every JSON
transport path that carries a user value uses this contract:

- RPC request `message`.
- RPC response `value`.
- Push `value`.
- SSR flag payloads.
- Page message fields.
- Client-context values.

Transport envelopes add routing, request IDs, protocol versions, and contract
hashes. They do not define private value dialects. Values inside those envelopes
must be produced by generated JSON encoders and consumed by generated JSON
decoders for `typed-json-v1`.

## Pros And Cons

JSON is a good fit when values need to be readable outside the BEAM or consumed
by generated SDKs and tools.

Pros:

- Easy to inspect in logs, fixtures, browser devtools, and documentation.
- Works with standard JSON tooling in other languages.
- Carries readable type identity with `type` and `variant`.
- Better fit for external SDKs and hand-written clients.

Cons:

- Larger than ETF before compression.
- Loses BEAM-native distinctions unless generated decoders provide type context.
- Needs explicit validation for safe integers, finite floats, field shapes, and
  contract hashes.
- Less efficient for BEAM-to-BEAM traffic than ETF.

## Request Envelope

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

- `kind` is `"request"`.
- `protocol_version` identifies the JSON protocol version.
- `contract_hash` must match the generated contract artifact.
- `module` is the logical Libero module tag.
- `request_id` identifies the request.
- `message` is a typed Libero value.

The contract hash is a fail-fast compatibility check. If client and server were
generated from different contracts, the server can reject the request before it
tries to decode the message.

## Response Envelope

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

The `request_id` matches the original request. The `value` is the generated
response value for that handler.

## Error Envelope

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

Errors are protocol errors, not handler domain errors. Decoders report paths so
callers can show useful diagnostics or logs.

## Push Envelope

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

Push values pass through generated typed encoders before they are wrapped in the
protocol envelope.

## Typed Values

`typed-json-v1` is the only JSON representation for generated Libero user
values. Custom types use a readable object shape:

```json
{
  "type": "module/path.TypeName",
  "variant": "VariantName",
  "fields": {}
}
```

`type` is the source module path plus type name. `variant` is the constructor
name. `fields` contains the constructor fields.

Labelled fields use an object:

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

Unlabelled fields use an array in declaration order:

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

Constructors with mixed labelled and unlabelled fields are rejected by JSON
codegen. That keeps the public JSON shape explainable and avoids a hybrid
object/array field format.

## How JSON Preserves Uniqueness

JSON uses readable identity instead of ETF's compact hashes. A constructor name
alone is never enough. The decoder validates the surrounding `type`, `variant`,
and field contract before constructing a value.

This means two modules can both define `Loaded`, and they stay distinct:

```json
{
  "type": "pages/home.State",
  "variant": "Loaded",
  "fields": { "count": 1 }
}
```

```json
{
  "type": "pages/admin.State",
  "variant": "Loaded",
  "fields": { "count": 1 }
}
```

Generated decoders enter through an expected type or contract artifact lookup.
They do not guess from object shape, constructor name, or arity.

For the shared identity rules behind both ETF and JSON, see
[Wire Type Identity](wire-type-identity.html).

## Built-In Shapes

| Gleam type | JSON shape | Notes |
|------------|------------|-------|
| `String` | JSON string | Unicode text. |
| `Bool` | JSON boolean | `true` or `false`. |
| `Int` | JSON integer | Must be within JavaScript safe integer range. |
| `Float` | JSON number | `NaN`, `Infinity`, and `-Infinity` are rejected. |
| `Nil` | `null` | No other sentinel value is accepted. |
| `List(a)` | JSON array | Elements use their own typed JSON shape. |
| `Dict(String, a)` | JSON object | Values use their own typed JSON shape. |
| `Dict(Int, a)` | JSON array of two-item arrays | Keys stay numbers, not strings. |
| `Dict(Bool, a)` | JSON array of two-item arrays | Keys stay booleans, not strings. |
| `#(...)` tuple | JSON array | Positional values in tuple order. |
| `BitArray` | Tagged object | `{ "encoding": "base64url", "data": "..." }`. |
| `Option(a)` | Typed custom shape | `gleam/option.Option` with variants `Some` and `None`. |
| `Result(a, e)` | Typed custom shape | `gleam/result.Result` with variants `Ok` and `Error`. |
| User custom type | Typed custom shape | `type`, `variant`, and `fields`. |

`Option(a)` does not use `null` as a shortcut. `None` and `Some(None)` are
different Gleam values, so JSON keeps them distinct.

`Dict` keys must be `String`, `Int`, or `Bool`. Other key types are rejected
during generation because JSON cannot preserve their identity without inventing
a lossy stringification rule.

`BitArray` values use an explicit object shape so binary data cannot be confused
with ordinary strings:

```json
{
  "encoding": "base64url",
  "data": "AAECAw=="
}
```

Tuple values use JSON arrays in tuple order:

```json
["count", 2]
```

Nested user types always route through their own generated encoder or decoder,
even when they appear inside `List`, `Dict`, tuple, `Option`, `Result`, or
another custom type.

## Unsupported Shapes

JSON generation fails before runtime for shapes that cannot be represented by
`typed-json-v1` without losing type information:

- Constructor fields that mix labelled and unlabelled fields.
- `Dict` keys other than `String`, `Int`, or `Bool`.
- Generic type variables that survive to the wire boundary.
- Unresolved or private user types.

Tuple support is currently positional. If that changes, the
`typed_value_contract` name must change and snapshots must be updated.

## Contract Artifact

The generated `rpc_contract.json` artifact records the JSON RPC protocol and the
typed value contract:

```json
{
  "contract_hash": "...",
  "protocol_version": "json-rpc-v1",
  "typed_value_contract": "typed-json-v1",
  "libero_version": "6.0.0",
  "endpoints": [],
  "push_types": [],
  "ssr_models": [],
  "types": []
}
```

`contract_hash` is computed from the canonical artifact fields without the hash
field itself. It covers endpoints, push types, SSR models, reachable user types,
the JSON protocol version, and the typed value contract name. A request whose
hash does not match the server contract is rejected before `message` decode.

## Validation

Generated JSON decoders validate before constructing typed values:

- Top-level JSON must be an object for frames and requests.
- `kind` must match the decode path.
- `protocol_version` must match exactly.
- `contract_hash` must match on requests.
- Required envelope fields must be present.
- `type` must be known for the expected decode path.
- `variant` must be known for the expected type.
- Labelled fields must be present exactly once.
- Unknown labelled fields are errors.
- Unlabelled fields must have the expected array length.
- Field values must match expected types.
- `Int` values must be safe JSON integers.
- `Float` values must be finite.
- `BitArray` values must use the tagged base64url object shape.
- Unsupported wire shapes, such as non-primitive `Dict` keys or unresolved type
  variables, fail during generation.

Errors include a path and message:

```text
message.fields.slug: expected String, got Null
value.fields.comments[3].fields.author.fields.id: expected Int, got String
```

## Security Limits

JSON decoding should apply limits before or during decode:

- Maximum input bytes.
- Maximum nesting depth.
- Maximum string length.
- Maximum array length.
- Maximum object entry count.
- Maximum base64 decoded byte length.

JavaScript decoders must avoid prototype mutation hazards. Protocol-owned
objects reject unsafe field names such as `__proto__`, `prototype`, and
`constructor`. User data in `Dict(String, a)` must still round-trip those strings
as data without assigning them as object prototype properties.

## Protocol Helpers

JSON helpers live in `libero/json/wire`.

The contract-level helper surface is:

| Concept | Helper |
|---------|--------|
| Encode an outbound request | `encode_request` |
| Decode an inbound request | `decode_request` |
| Encode a response frame | `encode_response` |
| Decode a server frame | `decode_server_frame` |
| Encode a push frame | `encode_push` |
| Encode SSR flags | `encode_flags` |
| Decode SSR flags | `decode_flags_typed` |
