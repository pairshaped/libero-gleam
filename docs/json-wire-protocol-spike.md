# JSON Wire Protocol Spike

Status: research note
Date: 2026-05-09

## Current Belief

Adding JSON only makes sense if JSON becomes an interop-friendly public
protocol. ETF should stay: the existing ETF work is valuable, fast, and already
fits BEAM-shaped deployments. Swapping ETF bytes for JSON while preserving BEAM
term shapes would keep most of the hard parts: constructor identity, tuple/list
distinctions, `Nil` vs `None`, `Dict`, `Float` handling, typed reconstruction,
and hostile input checks.

The win is not likely to be raw simplicity inside Libero. The win would be that
non-Gleam clients can understand and produce the protocol without implementing
ETF or knowing BEAM runtime shapes.

The intended product shape is multiple Libero-owned protocols. Gleam and Lustre
clients can keep using ETF and benefit from the existing native path. A Rust
CLI, Go tool, or hand-written JavaScript client can choose JSON for interop.
Both protocols should be generated from the same handler-derived contract.

## Why Consider JSON

ETF has strong performance and maps naturally to BEAM terms, but it makes Libero
harder to use outside the Gleam and Rally world. A configured JSON protocol
could make these consumers realistic:

- JavaScript clients that do not use generated Gleam output.
- Rust or Go command-line clients.
- Human debugging and message inspection.
- Documentation generated from the same contract Libero already derives.

The trade-off is real. JSON encode/decode will almost certainly be slower,
especially on the BEAM side where `term_to_binary` and `binary_to_term` are very
fast. The older benchmarks already show the shape of that cost. The branch
should not try to prove JSON is faster. It should prove the ecosystem story is
worth the added validation work.

## Direction

Libero should keep normal Gleam code as the source of truth:

```text
Gleam handlers and types
  -> Libero scanner and walker
  -> generated JSON contract artifact
  -> generated server decoders and encoders
  -> generated client decoders and encoders
  -> external client generators later
```

This keeps Libero distinct from schema-first tools. Users should not have to
write a parallel protocol file just to expose a handler.

## Public JSON Shape

The JSON format should be readable and stable enough to document. A request
could look like this:

```json
{
  "module": "rpc",
  "request_id": 1,
  "message": {
    "type": "server_get_article",
    "fields": {
      "slug": "hello-world"
    }
  }
}
```

A custom type could use a source-qualified type tag:

```json
{
  "type": "public/pages/article.Article",
  "variant": "Article",
  "fields": {
    "title": "Hello",
    "body": "..."
  }
}
```

The exact shape is still open. The branch should compare at least two shapes:

- Field-name objects: readable, good for external clients, larger payloads.
- Positional arrays with a contract artifact: smaller and more rename-tolerant,
  but less friendly for external clients.

Given the interop goal, field-name objects are the default recommendation unless
they create too much code or ambiguity.

If JSON lands, Libero should expose protocol selection in config. ETF remains a
valid protocol. JSON may also need an explicit output mode:

- `protocol = "etf"`: current binary protocol, optimized for Gleam/Rally and
  BEAM-shaped deployments.
- `protocol = "json"`: public JSON protocol, optimized for interop.
- `verbose`: readable field-name objects intended for third-party clients,
  debugging, and public documentation.
- `condensed`: smaller generated JSON, likely using positional fields and the
  contract artifact as the map.

This should not be tied to dev/prod environment. A production API may need
verbose JSON for external clients, and a development system may want condensed
JSON to test the production wire shape. Because Libero generates both sides of
the Gleam/Rally boundary, protocol and output mode can stay opaque to user
handler code.

## Security And Stability

Libero should own the wire boundary. A generic JSON codec can parse text, but it
cannot decide Libero's contract behavior.

The generated JSON path needs explicit checks for:

- Unknown message type.
- Unknown variant.
- Missing required field.
- Unknown field, unless we choose to allow it for forward compatibility.
- Field value with the wrong type.
- Non-finite or unsafe numeric values.
- Oversized strings, arrays, and objects.
- Excessive nesting depth.
- Malformed base64 for `BitArray`.

Errors should include useful paths, for example:

```text
article.author.id: expected Int, got String
```

The contract artifact should make accidental breaking changes visible. Skir's
snapshot checks are a good reference point here.

## Adjacent Projects

### Skir

Skir is schema-first. Users write `.skir` files and generate code for many
languages. Its most relevant ideas are stable field and variant numbers,
removed slots, readable vs dense JSON modes, generated clients, and snapshot
checks.

Skir is not a fit as Libero's model because it makes the schema the source of
truth. Libero's source of truth is normal Gleam handler code.

Reference: <https://github.com/gepheum/skir>

### Sara

Sara scans Gleam source and generates JSON encode/decode functions for annotated
custom types. It is closer to Libero than Skir because it derives code from
Gleam source.

The useful ideas are recursive type handling, custom codec escape hatches, and
the general shape of generated companion codecs.

Sara is probably not a dependency for Libero. It requires user annotations, has
constraints around public non-opaque types, and does not cover RPC envelopes,
Rally frames, SSR flags, or contract artifacts.

Reference: <https://hexdocs.pm/sara/index.html>

### glon And json_blueprint

Both point toward pairing JSON decoding with generated JSON Schema. That is
worth borrowing. Libero can emit a contract artifact and possibly JSON Schema
from the same discovered handler graph.

References:

- <https://hexdocs.pm/glon/index.html>
- <https://hexdocs.pm/json_blueprint/index.html>

### gleam_json And gleam/dynamic/decode

`gleam_json` is the likely low-level parser/printer. `gleam/dynamic/decode` is
the best reference for composable decoders and readable error paths.

References:

- <https://hexdocs.pm/gleam_json/gleam/json.html>
- <https://hexdocs.pm/gleam_stdlib/gleam/dynamic/decode.html>

## Rally Impact

Rally is a main consumer and would need a real cutover. A Libero-only swap would
miss most of the risk.

Areas to cover:

- WebSocket request and response frames.
- HTTP RPC.
- Push frames.
- Page init frames.
- SSR flags.
- Client context.
- Message logging and inspector formatting.
- Generated client transport.
- Generated snapshots.
- The realworld example CLI.

Rally mostly wraps Libero's wire APIs, which helps. Still, the generated output
and runtime assumptions will change enough that the branch should include Rally
work before drawing conclusions.

## Branch Acceptance Criteria

The branch is worth keeping only if it can show:

- A documented JSON protocol that a non-Gleam client author could implement.
- Generated server-side validation with good error messages.
- Generated JS client encode/decode behavior matching the server contract.
- Existing consumers keep using Libero-generated modules and protocol helpers
  rather than learning the JSON shape.
- Gleam and Lustre clients can keep using ETF while a non-Gleam client uses
  JSON against the same handler contract.
- Rally realworld running through RPC, push, SSR flags, client context, and page
  init.
- A contract artifact that can be inspected and snapshot-tested.
- A meaningful reduction in ETF-specific machinery.
- A clear accounting of new JSON-specific machinery.

The blunt test: if the branch removes ETF but replaces it with opaque generated
JSON code that only Libero understands, it failed the reason for doing JSON.

## Non-Goals For The First Branch

- Prove JSON is faster than ETF.
- Remove ETF or treat it as legacy.
- Generate Rust or Go clients immediately.
- Preserve wire compatibility with current ETF frames.
- Move Libero to a separate schema language.

## Open Questions

- Should unknown fields be rejected or ignored?
- Should protocol config be project-wide, client-specific, or endpoint-specific?
- Should field names or stable field numbers be the compatibility anchor?
- Should JSON output mode be a single project-level config, or can individual
  generated surfaces choose `verbose` vs `condensed`?
- How should Gleam `Dict` encode when its lookup terms are not strings?
- How should `BitArray` encode: base64 string, hex string, or tagged object?
- Should custom types include both module path and variant name in every value?
- How much schema evolution should Libero support before it becomes a schema
  system in disguise?
