![Libero](libero.png)

# Libero

Libero helps a Gleam client and server share a typed RPC contract. The contract
is the main thing: both sides agree on which calls exist, what arguments they
take, and what each call returns.

Encoding and decoding are part of that, but they are not the whole point. The
hard part is keeping the client and server agreement true across the protocol
layer: request messages, response decoders, server dispatch, client state, and
wire-format details all need to match the handler signatures.

Libero treats the server handler as the source of truth. It scans your handler
functions, follows the types used in their signatures, and generates the RPC
plumbing around them. That gives the client and server a shared typed contract
without hand-written protocol messages or decoders.

## What Libero Replaces

A server handler is a Gleam function that runs on the server:

```gleam
import gleam/result.{type Result}
import server_context.{type ServerContext}

pub fn server_get_items(
  server_context server_context: ServerContext,
) -> Result(List(Item), ItemError) {
  Ok(server_context.items)
}
```

Libero treats a public function as an RPC handler when its name starts with
`server_`, it takes a `ServerContext`, and it returns either a read-only result
or a result with an updated context.

From just this handler, Libero writes all of the surrounding RPC code for you:

- A request variant such as `ServerGetItems`, which represents this call at the
  protocol boundary. The server dispatch decodes it, and generated client or
  framework code sends the matching shape.
- An encoder that turns `ServerGetItems` into bytes or JSON
- Server dispatch code that receives the message and calls `server_get_items`
- A response shape for `Result(List(Item), ItemError)`
- A client decoder that turns the response back into Gleam values
- Client state for loading, success, domain errors, and transport errors

If the handler signature changes, you simply regenerate instead. The wire format
is the bytes or JSON sent over the network; Libero owns that shape so application
code can stay focused on typed messages and handler results.

## Quick Start

Add Libero to your project and run the generator:

```sh
gleam add libero
gleam run -m libero
```

Libero scans `src/`, finds RPC handlers, discovers the types they use, and writes
generated files under `src/generated/libero/`.

## Generated Files

After `gleam run -m libero`, you will see files like these:

| File | Purpose |
|------|---------|
| `src/generated/libero/dispatch.gleam` | Server dispatch code for your handlers |
| `src/generated/libero/rpc_decoders.gleam` | Gleam wrapper for generated decoders |
| `src/generated/libero/rpc_decoders_ffi.mjs` | JavaScript decoders for discovered types |
| `src/generated@rpc_atoms.erl` | Erlang atom pre-registration for safe ETF decoding |

Import the generated server modules in your app like any other Gleam module.

## Transport Is Yours

Libero leaves transport code to your app or framework. WebSocket setup, HTTP
routes, reconnect behavior, and app-specific routing stay outside the generator.

## Advanced Usage

### Client Decoders

If your client lives in another package, mirror the generated JavaScript decoder
files into that package:

```sh
LIBERO_CLIENT_OUT_DIR="../clients/web/src/generated/libero" gleam run -m libero
```

This copies the client decoder output only. Libero still writes the server
dispatch files to `src/generated/libero/`.

### Library API

You can also call the pipeline from your own codegen tool:

```gleam
import libero

let assert Ok(endpoints) = libero.scan()
let seeds = libero.collect_seeds(endpoints)
let assert Ok(discovered) = libero.walk(seeds)

let dispatch_src = libero.generate_dispatch(endpoints)
let decoders_js = libero.generate_decoders_ffi(discovered, endpoints)
let decoders_gleam = libero.generate_decoders_gleam()
```

The API returns generated source as strings, so you choose where to write it.

### Multiple Protocols

Libero supports ETF for BEAM-first applications and JSON for generated SDKs,
tools, logs, and easier inspection. Both protocols are owned by the generated
contract boundary: app code should call Libero helpers instead of assembling wire
messages by hand.

For untrusted ETF input, decode through the generated helpers or
`wire.decode_safe`. ETF safe decoding prevents atom and function-term injection,
but callers should still set process memory limits for hostile input.

## More Docs

- [Contract boundary](https://github.com/pairshaped/libero/blob/master/pages/reference/contract-boundary.md):
  what Libero owns and what app code owns
- [ETF wire protocol](https://github.com/pairshaped/libero/blob/master/pages/protocol/etf-wire-protocol.md):
  ETF frames, safe decode, and hashed type identity
- [JSON wire protocol](https://github.com/pairshaped/libero/blob/master/pages/protocol/json-wire-protocol.md): readable JSON
  envelopes, validation, and contract hashes
- [Wire type identity](https://github.com/pairshaped/libero/blob/master/pages/protocol/wire-type-identity.md):
  how custom types stay unique across protocols
- [llms.txt](https://raw.githubusercontent.com/pairshaped/libero/master/llms.txt):
  raw package context for language models

## License

MIT. See [LICENSE](https://github.com/pairshaped/libero/blob/master/LICENSE).
