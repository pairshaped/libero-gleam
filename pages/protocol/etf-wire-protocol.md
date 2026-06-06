# ETF Wire Protocol

ETF is Libero's BEAM-native wire protocol. It uses Erlang's External Term
Format for bytes on the network, then relies on generated code to preserve the
typed contract between BEAM and JavaScript.

The important idea is that ETF can encode atoms and tuples, but it does not know
which Gleam module a custom type came from. Libero adds that missing identity in
generated code before values cross the wire.

## Pros And Cons

Pros:

- Compact binary encoding.
- Native support for BEAM terms such as atoms, tuples, bit arrays, integers,
  and floats.
- Preserves the difference between values like `2` and `2.0`.
- Fits Rally's generated Gleam and JavaScript runtime path.

Cons:

- Harder to inspect in logs and fixtures.
- Non-BEAM clients need an ETF implementation.
- ETF has no module-qualified custom type identity, so Libero must add
  generated hashed wire tags.
- Safe decoding still needs resource limits for hostile input.

## Request Envelope

A request envelope is encoded as a three-item tuple:

```text
#(module, request_id, payload)
```

Where:

- `module` is the logical framework module tag.
- `request_id` is the integer used to match a response to a request.
- `payload` is the framework-owned request value.

Callers that use Libero's low-level request helpers should call
`encode_request` and `decode_request` rather than assemble this tuple directly.
Rally's generated protocol modules own their frame shape and use the generated
ETF codec module's `encode` and `decode` entrypoints.

## Server Frames

Server-to-client messages are framed before the ETF payload:

| Frame | Shape |
|-------|-------|
| Response | tag byte `0`, 32-bit request ID, ETF payload |
| Push | tag byte `1`, ETF payload |

Callers that use Libero's low-level server-frame helpers should call
`decode_server_frame` and pattern match on the decoded frame. They should not
inspect tag bytes or slice request IDs themselves.

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
shape before framework code sees it:

```erlang
decode_status('a1b2c3d4e5') ->
    loaded.

decode_item({'f6a7b8c9d0', Id, Name}) ->
    {item, Id, Name}.
```

The hash is opaque on the wire. The generated code knows which source type the
hash belongs to, so error messages can still refer to the source-level type.

For the full uniqueness model, see [Wire Type Identity](wire-type-identity.html).

## Built-In Values

ETF preserves BEAM values that JSON cannot represent directly, including atoms,
tuples, bit arrays, and the difference between integers and floats.

Libero still needs generated field information for some values. JavaScript, for
example, does not preserve the difference between `2` and `2.0`. Generated
encoders carry field type hints so a whole-number `Float` can still be encoded
as an ETF float.

## Safe Decode

Use generated boundary helpers or `decode_safe` for untrusted ETF input. On the
BEAM, safe ETF decoding uses `[safe, used]` to block new atom creation and
reject trailing bytes after the decoded term.

Safe ETF decoding does not by itself limit input size, nesting depth, or every
BEAM runtime term class. `libero/etf/wire.set_strict_data_terms(True)` enables
an extra BEAM validator that rejects pids, refs, ports, and functions after
decode. It is disabled by default because generated typed decoding already walks
legitimate payloads.

`libero/etf/wire.set_js_term_depth_limit(512)` enables the optional recursive
term depth cap in the generated JavaScript ETF decoder. `0` disables the cap,
which is the default.

## Protocol Helpers

ETF helpers live in `libero/etf/wire`.

| Concept | Helper |
|---------|--------|
| Encode an outbound request envelope | `encode_request` |
| Decode an inbound request envelope | `decode_request` |
| Encode a response frame | `encode_response` |
| Decode a server frame | `decode_server_frame` |
| Encode a push frame | `encode_push` |
| Encode SSR flags | `encode_flags` |
| Decode SSR flags | `decode_flags_typed` |

ETF also exposes lower-level response and push frame decoders for tests and
internal callers. `decode_server_frame` is the unified helper for callers using
Libero's low-level frame API.
