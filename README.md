![Libero](https://github.com/pairshaped/libero-gleam/blob/master/libero.png?raw=true)

# Libero

[![Package Version](https://img.shields.io/hexpm/v/libero)](https://hex.pm/packages/libero)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/libero/)

Libero is [Rally](https://hex.pm/packages/rally)'s typed wire-contract layer
for Gleam.

Frameworks like Rally decide which values cross the boundary. Libero walks those
seeded types, generates the codec artifacts, and exposes ETF and JSON wire
helpers that agree on type identity. It does not scan handlers, generate
dispatch modules, write app transport, or own request/result/push API design.

That boundary is deliberate. For example, Rally owns pages, loaders, actions,
request correlation, WebSocket lifecycle, SSR, hydration, and broadcast
delivery. Libero owns the shared type graph and the protocol-facing pieces that
must stay in lockstep.

## What Libero Generates

Rally currently uses these Libero outputs:

| Artifact | Purpose |
|----------|---------|
| `generated@libero_atoms.erl` | Pre-registers ETF atoms before safe BEAM decode. |
| `generated@libero_wire.erl` | Converts seeded custom types between BEAM shape and wire shape. |
| `decoders_ffi.mjs` | JavaScript ETF decoders for every discovered type. |
| `decoders.gleam` | Gleam wrapper that registers JavaScript decoders. |
| `etf.gleam` | Neutral ETF facade used by generated framework protocol code. |
| `contract.json` | JSON contract artifact with protocol version, hash, push types, SSR models, and discovered types. |

Libero also keeps the JSON codec generator and JSON wire helpers. Those are for
framework-generated JSON contracts, not a separate standalone application path.

## Library API

Frameworks call Libero from their own generator:

```gleam
import gleam/option
import libero

let seeds = [
  #("public/pages/home", "ServerMsg"),
  #("public/pages/home", "LoadResult"),
  #("libero/error", "TransportError"),
]

let assert Ok(discovered) = libero.walk(seeds)

let atoms =
  libero.generate_atoms(
    discovered:,
    atoms_module: "generated@libero_atoms",
    wire_module: option.Some("generated@libero_wire"),
  )

let assert Ok(wire) =
  libero.generate_wire_erl(
    discovered:,
    wire_module: "generated@libero_wire",
  )

let decoders_js =
  libero.generate_decoders_ffi(
    discovered:,
    package: "my_app",
    dependency_packages: ["shared"],
  )

let decoders_gleam = libero.generate_decoders_gleam()
let etf =
  libero.generate_etf_codec_module(
    atoms_module: "generated@libero_atoms",
    decoders_module: "generated/libero/decoders",
  )
let contract =
  libero.generate_json_contract(
    discovered:,
    push_types: [],
    ssr_models: [],
  )
```

Each function returns source text or JSON text. The caller owns file layout,
formatting, rebuilds, and whether generated files are checked in.

## Type Discovery

`libero.walk(seeds)` searches `./src` and follows custom types reachable from
the given `#(module_path, type_name)` seeds. Lower-level callers can use
`libero/source.walk_directory` and `libero/walker.walk` when they need a
different source root, as the JavaScript E2E fixture does for a staged
multi-package project.

Libero skips generated directories while walking source. It also skips stdlib
and Libero runtime modules whose shapes are handled by codec runtime support.

## Wire Runtime

ETF helpers live in `libero/etf/wire`. JSON helpers live in `libero/json/wire`.
The generated ETF module from `generate_etf_codec_module` exposes only the
surface Rally uses: `ensure`, `encode`, and `decode`. Rally-generated protocol
modules own request ids, frame tags, dispatch, and result envelopes around those
helpers.

The lower-level runtime modules still expose codec helper functions used by the
ETF and JSON test matrix:

| Concept | ETF helper | JSON helper |
|---------|------------|-------------|
| Encode a request envelope | `encode_request` | `encode_request` |
| Decode a request envelope | `decode_request` | `decode_request` |
| Encode a response frame | `encode_response` | `encode_response` |
| Decode a server frame | `decode_server_frame` | `decode_server_frame` |
| Encode a push frame | `encode_push` | `encode_push` |
| Encode SSR flags | `encode_flags` | `encode_flags` |
| Decode SSR flags | `decode_flags_typed` | `decode_flags_typed` |

ETF preserves BEAM term fidelity and uses generated wire hashes for user custom
types. JSON uses readable type identity and contract hashes. Both codecs use the
same discovered type graph.

## ETF Safety

Untrusted ETF input is decoded with `binary_to_term(Bin, [safe, used])` on the
BEAM. This blocks new atom creation and rejects trailing bytes. Generated atom
registration makes legitimate custom type atoms available before decode.

`libero/etf/wire.set_strict_data_terms(True)` enables an extra BEAM term-kind
validator that rejects pids, refs, ports, and functions after decode. It is off
by default because generated typed decoding already walks legitimate payloads.
Applications that intentionally accept hand-written ETF should also enforce
transport frame limits and process memory limits.

`libero/etf/wire.set_js_term_depth_limit(512)` enables the optional JavaScript
recursive ETF depth cap. `0` disables it, which is the default.

## Example

[Rally Scoreboard](https://github.com/pairshaped/rally-scoreboard-example) is
the canonical consumer. It uses Rally's generator to pick the wire types, then
uses Libero to generate the shared codec and contract artifacts under
`src/generated/libero/**`.

## More Docs

- [Contract boundary](https://github.com/pairshaped/libero-gleam/blob/master/pages/reference/contract-boundary.md)
- [ETF wire protocol](https://github.com/pairshaped/libero-gleam/blob/master/pages/protocol/etf-wire-protocol.md)
- [JSON wire protocol](https://github.com/pairshaped/libero-gleam/blob/master/pages/protocol/json-wire-protocol.md)
- [Wire type identity](https://github.com/pairshaped/libero-gleam/blob/master/pages/protocol/wire-type-identity.md)
- [llms.txt](https://raw.githubusercontent.com/pairshaped/libero-gleam/master/llms.txt)

## License

MIT. See [LICENSE](https://github.com/pairshaped/libero-gleam/blob/master/LICENSE).
