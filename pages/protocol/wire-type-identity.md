# Wire Type Identity

Libero derives a typed client/server contract from Gleam source. That contract
only works if values keep their source identity after they cross the wire.

The problem is that runtime shapes are often less specific than source types. A
constructor name, tuple shape, or JSON object shape can look the same for two
different Gleam types. Libero treats source identity as part of the wire
contract so those values stay distinct.

## The Identity Rule

Every custom type value that crosses the wire must be identified by its source
meaning, not by its runtime shape alone.

For ETF, the compact hash is based on:

```text
module path + constructor name + field types
```

For JSON, the readable value carries:

```text
module path + type name + variant name + fields
```

The details differ because ETF and JSON represent values differently, but the
goal is the same: two distinct source values must stay distinct on the wire.

This means these two values are distinct even though their constructor names and
field shapes match:

```gleam
// pages/home.gleam
pub type State {
  Loaded(count: Int)
}
```

```gleam
// pages/admin.gleam
pub type State {
  Loaded(count: Int)
}
```

The module path separates the two `Loaded` constructors.

## Why Shape Is Not Enough

Shape-based decoding is tempting, but it is unsafe for a generated RPC contract.

These two types have the same field shape:

```gleam
pub type Discount {
  Discount(id: Int, name: String)
}

pub type Promotion {
  Promotion(id: Int, name: String)
}
```

They could serialize to the same raw tuple or JSON object if the protocol only
looked at fields. That would let the receiver construct a value of the wrong
source type. Libero avoids that by carrying or deriving source identity at the
protocol boundary.

## How Protocols Apply It

ETF and JSON apply the same source-identity idea in different ways.

ETF uses compact generated hashes because ETF has no qualified custom type tag.
The hash is based on the constructor's module path, constructor name, and field
types. Generated encoders translate normal BEAM shapes into hashed wire shapes,
and generated decoders translate them back.

JSON uses readable identity. A custom value carries a `type` field and a
`variant` field, and decoders validate both before constructing a value. JSON
requests also carry a contract hash so mismatched generated client/server pairs
can fail before message decoding.

For protocol details, see [ETF Wire Protocol](etf-wire-protocol.html) and
[JSON Wire Protocol](json-wire-protocol.html).

## Field Types

Field types are part of the identity. Changing a constructor's field type,
adding a field, removing a field, or reordering fields changes the wire identity.

Field labels are not part of the ETF hash. Renaming a labelled field preserves
the ETF wire identity because ETF uses field order. JSON still uses field labels
for readability when the source constructor has labels.

## Nested Types

User-defined field types are represented by source references, not by nested
hashes. A field of type `Article` is represented as a reference to the source
type:

```text
<type:shared/article|Article>
```

This avoids cycles when types are recursive or mutually recursive. The parent
identity can be computed without first computing every nested hash.

Nested values still carry their own identity when they appear on the wire. If a
nested type changes shape, its own decoder catches the mismatch at the nested
boundary.

## Collision Checks

ETF hashes are compact, so Libero checks them during code generation.

The generator computes every constructor's canonical signature and hash. If two
different signatures produce the same hash, codegen fails with a type identity
collision error.

Duplicate sightings of the same canonical signature are fine. That can happen
when a shared type is reached through more than one endpoint. A collision only
means two distinct source identities produced the same hash.

The hash is not a security primitive. The safety property comes from generating
the hashes from source identity and checking for collisions before emitting code.

## Unsupported Wire Shapes

Libero rejects source types that would make the wire contract ambiguous or hard
to preserve across targets.

Current examples:

- `Dict` keys must be `Int`, `String`, or `Bool`.
- Unresolved type variables cannot cross the wire.
- JSON rejects constructors with mixed labelled and unlabelled fields.

These checks happen during code generation so failures are visible before the
application runs.
