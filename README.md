![Libero](https://github.com/pairshaped/libero-gleam/blob/master/libero.png?raw=true)

# Libero

[![Package Version](https://img.shields.io/hexpm/v/libero)](https://hex.pm/packages/libero)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/libero/)

Libero helps Gleam tools and frameworks generate a typed wire contract: which
requests exist, what data crosses the boundary, and how results, pushes, and
hydration flags are encoded.

Encoding and decoding are part of that, but they are not the whole point. The
hard part is keeping every protocol-facing piece in agreement: request messages,
result frames, push frames, server dispatch, generated decoders, and contract
artifacts all need to match the same source types.

Libero can scan handler functions as the source of truth, then follow the types
used in those signatures. Frameworks can also call the library API directly and
choose where generated files live. In both cases, Libero owns the wire shape so
consumers do not hand-write envelopes, frame parsing, or typed decoders.

## Core Model

The default scanner treats a server handler as a Gleam function that runs on the
server:

```gleam
import gleam/result.{type Result}
import server_context.{type ServerContext}

pub fn server_get_items(
  server_context server_context: ServerContext,
) -> Result(List(Item), ItemError) {
  Ok(server_context.items)
}
```

Libero treats a public function as a request handler when its name starts with
`server_`, it takes a `ServerContext`, and it returns either a read-only result
or a result with an updated context. The context type must appear unqualified in
the signature (`ServerContext`, not `ctx.ServerContext`). Functions that use a
qualified context type are silently skipped.

From this handler, Libero can generate contract code such as:

- A request variant such as `ServerGetItems`
- Server dispatch code that decodes the request and calls `server_get_items`
- A typed result shape for `Result(List(Item), ItemError)`
- Protocol helpers for request, result, push, and flags data
- Generated ETF or JSON codec code for the types that cross the wire
- A contract artifact with a protocol version and contract hash

If the handler signature changes, you simply regenerate instead. Libero owns the
wire shape, whether you use the default ETF protocol or opt into JSON. Your app
or framework owns when messages are sent and how decoded values affect state.

## Quick Start

Add Libero to your project and run the generator:

```sh
gleam add libero
gleam run -m libero
```

Libero scans `src/`, finds request handlers, discovers the types they use, and
writes generated files under `src/generated/libero/`.

## Generated Files

After `gleam run -m libero`, you will see files like these:

| File | Purpose |
|------|---------|
| `src/generated/libero/dispatch.gleam` | Server dispatch code for your handlers |
| `src/generated/libero/requests.gleam` | Generated `RequestMsg` request type for JavaScript decoder hints |
| `src/generated/libero/decoders_ffi.mjs` | JavaScript ETF decoders for browser/client targets |
| `src/generated/libero/decoders.gleam` | Gleam bindings for generated JavaScript ETF decoders |
| `src/generated/libero/etf.gleam` | Generated ETF facade for request/result/push/flags helpers |
| `src/generated/libero/generated@libero_atoms.erl` | ETF atom pre-registration module for safe BEAM decode |
| `src/generated/libero/generated@libero_wire.erl` | ETF wire transformer module |
| `src/generated/libero/contract.json` | Contract artifact with protocol version and contract hash |

Import the generated server modules in your app like any other Gleam module.

When `use_json = true`, Libero generates JSON-specific files instead:

| File | Purpose |
|------|---------|
| `src/generated/libero/dispatch.gleam` | JSON server dispatch code for your handlers |
| `src/generated/libero/requests.gleam` | Generated JSON `RequestMsg` request type |
| `src/generated/libero/json_codecs.gleam` | Typed JSON encoders, decoders, and response helpers |
| `src/generated/libero/contract.json` | JSON contract artifact with protocol version and contract hash |

## Transport Is Yours

Libero leaves transport code to your app or framework. WebSocket setup, HTTP
routes, reconnect behavior, browser lifecycle, SSR, routing, and app state stay
outside the generator.

## Example

[Rally Scoreboard](https://github.com/pairshaped/rally-scoreboard-example)
shows Libero used as Rally's wire-contract layer. Rally drives Libero type
discovery and generated ETF codec output under `src/generated/libero/**`, while
Rally owns transport, SSR, hydration, browser lifecycle, and broadcast delivery.

## Benchmarks

Transport benchmarks live in [benchmarks/](benchmarks/) and compare the default
ETF path with the generated JSON path across BEAM request decode, BEAM response
encode, and JavaScript response decode stages.

Current benchmark report:
[benchmarks/report.md](benchmarks/report.md)

## Advanced Usage

### Mirrored Output

Projects with separate packages can mirror generated protocol files into another
package:

```toml
[tools.libero]
mirrored_output_dir = "../clients/web/src/generated/libero"
```

Then run:

```sh
gleam run -m libero
```

For one-off scripts, the environment variable still overrides `gleam.toml`:

```sh
LIBERO_MIRRORED_OUTPUT_DIR="../clients/web/src/generated/libero" gleam run -m libero
```

For the default ETF protocol, this copies `requests.gleam`,
`decoders_ffi.mjs`, `decoders.gleam`, and `etf.gleam`. When
`use_json = true`, this copies `requests.gleam`, `json_codecs.gleam`, and
`contract.json`. Libero still writes the server dispatch files to
`src/generated/libero/`.
Set `erlang_output_dir` when the generated server modules should live in a
different directory under `src`:

```toml
[tools.libero]
erlang_output_dir = "src/server/generated"
mirrored_output_dir = "../clients/web/src/generated/libero"
```

### Library API

You can also call the pipeline from your own codegen tool:

```gleam
import libero

let assert Ok(endpoints) = libero.scan()
let seeds = libero.collect_seeds(endpoints)
let assert Ok(discovered) = libero.walk(seeds)

let contract_hash =
  libero.generate_json_contract_hash(endpoints, discovered, [], [])
let contract_src =
  libero.generate_json_contract(endpoints, discovered, [], [])
let dispatch_src =
  libero.generate_json_dispatch(
    endpoints,
    request_msg_module: "generated/libero/requests",
    json_codecs_module: "generated/libero/json_codecs",
    contract_hash: contract_hash,
  )
let messages_src = libero.generate_request_msg_module(endpoints)
```

The API returns generated source as strings, so you choose where to write it.

### Multiple Protocols

ETF is Libero's default generated transport. Set `use_json = true` when you
want the generated JSON dispatch, typed JSON codecs, and contract hash/version
check instead.

Generated JSON decoders treat wire input as untrusted and return structured
errors. Generated encoders assume trusted typed application values; if FFI or
unsafe construction gives them an out-of-range `Int` or non-finite `Float`, they
panic rather than emit JSON the decoder would reject.

Both protocols are owned by the generated contract boundary: app code should
call Libero helpers instead of assembling wire messages by hand.

To generate JSON dispatch and codec files:

```toml
[tools.libero]
use_json = true
```

Then run:

```sh
gleam run -m libero
```

For one-off scripts, the environment variable still overrides `gleam.toml`:

```sh
LIBERO_USE_JSON=1 gleam run -m libero
```

For untrusted ETF input, decode through the generated helpers or
`libero/etf/wire.decode_safe`. ETF safe decoding uses `[safe, used]` on the
BEAM to block new atom creation and reject trailing bytes. It is not a full
"data terms only" validator by default. Applications that intentionally accept
hand-written ETF can opt into strict BEAM data-term validation with
`libero/etf/wire.set_strict_data_terms(True)`, but should still set process
memory limits for hostile input.

## Security: ETF Threat Model

ETF is Libero's default transport. It preserves BEAM term fidelity, but that
fidelity comes with a sharper threat model than JSON.

The [ERLEF serialisation guide](https://security.erlef.org/secure_coding_and_deployment_hardening/serialisation.html)
recommends against using ETF with untrusted parties. Libero does it anyway, with
a defense stack designed for a specific threat model.

### Trust assumptions

- The WebSocket endpoint requires authentication (cookie, session, or token)
  upstream of the handler. Libero does not enforce this; your transport layer
  must.
- The browser is adversarial despite serving your own JS. DevTools, XSS, browser
  extensions, and MITM (if HTTPS is broken) can all craft arbitrary ETF.
- The server's BEAM process is trusted. Libero never decodes untrusted ETF into
  the server without the defenses below.

### Defense stack (in order)

1. **Transport frame size limit.** Your WebSocket server (mist, cowboy, etc.)
   should cap frame size. This is outside Libero but is the first gate.
2. **`binary_to_term(Bin, [safe, used])`** on every decode path. This blocks
   new atom creation (atom-table exhaustion DoS) and rejects trailing bytes
   after the decoded term. Libero audits for bare `binary_to_term/1` calls;
   none exist in the codebase.
3. **Atom pre-registration.** The generated `libero_atoms` module calls
   `binary_to_atom/2` for every constructor atom at boot. With `[safe]`,
   `binary_to_term` only succeeds for atoms that already exist in the table.
4. **Typed dispatch.** The generated dispatch verifies the decoded term's
   constructor tag against a known handler set before invoking any handler
   function. Unknown tags return a wire error, not a crash.

`libero/etf/wire.set_strict_data_terms(True)` enables an extra BEAM validator
that rejects runtime terms such as pids, refs, ports, and functions after
decode. It is disabled by default because it still walks the full request before
generated typed decoding walks legitimate values again. The configured strict
mode uses a fast term-kind validator that does not build detailed error paths;
the older path-building precheck is kept for diagnostics and benchmarking.
Benchmarks on OTP 29 / Gleam 1.17 showed the path-building precheck around
4.5-7.3x slower than default ETF request decode, while configured strict mode
was around 1.25-1.56x slower. Proper Libero clients do not emit those terms.
Enable it if you intentionally accept hand-written ETF from untrusted non-Libero
clients.

`libero/etf/wire.set_js_term_depth_limit(512)` enables the optional recursive
term depth cap in the generated JavaScript ETF decoder. `0` disables the cap,
which is the default. This is useful when the JS bundle is trusted but the ETF
bytes are less trusted than the server that served the bundle. It is not a
defense against a compromised server, because that server can send different
JavaScript.

### What would weaken this model

- Adding a bare `binary_to_term/1` call (without `[safe]`) on any request path.
- Accepting ETF from unauthenticated connections.
- Passing decoded ETF terms to `erlang:apply/3` or similar without dispatch
  tag verification.
- Removing atom pre-registration while still accepting ETF from browsers.

If you modify Libero's decode path, verify that `[safe, used]` is present and
that the decoded term flows through typed dispatch before reaching handler code.

## More Docs

- [Contract boundary](https://github.com/pairshaped/libero-gleam/blob/master/pages/reference/contract-boundary.md):
  what Libero owns and what app code owns
- [ETF wire protocol](https://github.com/pairshaped/libero-gleam/blob/master/pages/protocol/etf-wire-protocol.md):
  ETF frames, safe decode, and hashed type identity
- [JSON wire protocol](https://github.com/pairshaped/libero-gleam/blob/master/pages/protocol/json-wire-protocol.md): readable JSON
  envelopes, validation, and contract hashes
- [Wire type identity](https://github.com/pairshaped/libero-gleam/blob/master/pages/protocol/wire-type-identity.md):
  how custom types stay unique across protocols
- [llms.txt](https://raw.githubusercontent.com/pairshaped/libero-gleam/master/llms.txt):
  raw package context for language models

## License

MIT. See [LICENSE](https://github.com/pairshaped/libero-gleam/blob/master/LICENSE).
