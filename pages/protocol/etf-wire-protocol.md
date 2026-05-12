# ETF Wire Protocol

ETF is Libero's BEAM-native wire protocol. It uses Erlang's External Term
Format for bytes on the network, then relies on generated code to preserve the
typed contract between client and server.

The important idea is that ETF can encode atoms and tuples, but it does not know
which Gleam module a custom type came from. Libero adds that missing identity in
generated code before values cross the wire.

## Pros And Cons

ETF is a good fit when both sides are close to the BEAM or generated Libero
runtime code.

Pros:

- Compact binary encoding.
- Native support for BEAM terms such as atoms, tuples, bit arrays, integers, and
  floats.
- Preserves the difference between values like `2` and `2.0`.
- Fast path for Gleam, Erlang, and BEAM-first applications.

Cons:

- Harder to inspect in logs and fixtures.
- Non-BEAM clients need an ETF implementation.
- ETF has no module-qualified custom type identity, so Libero must add generated
  hashed wire tags.
- Safe decoding still needs resource limits for hostile input.

## Request Flow

A request is encoded as a three-item tuple:

```text
#(module, request_id, message)
```

Where:

- `module` is the logical Libero module tag, usually `"rpc"` for handler calls.
- `request_id` is the integer used to match a response to a request.
- `message` is a generated client message value.

Consumers should call `encode_request` rather than assemble this tuple directly.
The server decodes the request at the boundary, routes it through generated
dispatch, and calls the matching handler.

## Server Frames

Server-to-client messages are framed before the ETF payload:

| Frame | Shape |
|-------|-------|
| Response | tag byte `0`, 32-bit request ID, ETF payload |
| Push | tag byte `1`, ETF payload |

Consumers should call `decode_server_frame` and pattern match on the decoded
frame. They should not inspect tag bytes or slice request IDs themselves.

## Custom Type Identity

Gleam custom types compile to BEAM atoms and tuples. Two modules can both define
a constructor named `Loaded`, and both would have the same bare BEAM tag:
`loaded`. That is not enough identity for a wire protocol.

ETF values therefore use generated wire tags. For each constructor that crosses
the wire, Libero computes a 10-character hash from the constructor's source
identity:

```text
module path + constructor name + field types
```

Generated encoder functions translate the normal BEAM shape into the wire shape:

```erlang
encode_status(loaded) ->
    'a1b2c3d4e5'.

encode_item({item, Id, Name}) ->
    {'f6a7b8c9d0', Id, Name}.
```

Generated decoder functions translate the wire shape back into the normal BEAM
shape before the handler or client code sees it:

```erlang
decode_status('a1b2c3d4e5') ->
    loaded.

decode_item({'f6a7b8c9d0', Id, Name}) ->
    {item, Id, Name}.
```

The hash is opaque on the wire. The generated code knows which source type the
hash belongs to, so error messages can still refer to the source-level type.

For the full uniqueness model, see [Wire Type Identity](wire-type-identity.html).

## Why Hashes Are Needed

Readable constructor names are unsafe as global wire tags. These two types must
remain distinct:

```gleam
// pages/home.gleam
pub type State {
  Loaded(count: Int)
}

// pages/admin.gleam
pub type State {
  Loaded(count: Int)
}
```

Both constructors have the same name and the same field shape. The module path
is part of Libero's identity basis, so they produce different wire hashes.

Libero checks generated hashes for collisions at codegen time. A collision is
treated as a build error. The hash is not a security primitive; it is a compact
wire identity with a generated uniqueness check.

## Built-In Values

ETF preserves BEAM values that JSON cannot represent directly, including atoms,
tuples, bit arrays, and the difference between integers and floats.

Libero still needs generated field information for some values. JavaScript, for
example, does not preserve the difference between `2` and `2.0`. Generated
encoders carry field type hints so a whole-number `Float` can still be encoded
as an ETF float.

## Safe Decode

Use generated boundary helpers or `decode_safe` for untrusted ETF input. On the
BEAM, safe ETF decoding prevents atom and function-term injection.

Safe ETF decoding does not by itself limit input size or nesting depth. Code
that accepts hostile input should also set process memory limits and use Libero
helpers that validate the decoded shape before constructing typed values.

## Protocol Helpers

ETF helpers currently live in `libero/wire`. The target module path is
`libero/etf/wire`, matching `libero/json/wire`.

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

ETF may also expose lower-level response and push frame decoders for internal
use. Consumer code should prefer `decode_server_frame`.
