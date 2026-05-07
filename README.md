# Libero

RPC plumbing library for Gleam. Run `gleam run -m libero` to generate a typed RPC pipeline from handler function signatures. Or call the library API directly from your own codegen tool.

## Quickstart

```sh
gleam run -m libero
```

This scans `src/` for handler functions, discovers all reachable types, and writes three files to `src/generated/libero/`:

| File | Purpose |
|------|---------|
| `dispatch.gleam` | Server dispatch module — `ClientMsg` type and `handle` function that route wire envelopes to handlers |
| `rpc_decoders_ffi.mjs` | JavaScript typed decoders for every discovered type |
| `rpc_decoders.gleam` | Gleam wrapper that registers the JS decoders |

Import the generated modules from your server and client code like any other Gleam module. If you are building a codegen tool that needs the intermediate data (discovered types, handler endpoints), use the library API instead.

To also write the JavaScript decoder files into a client package, set `LIBERO_CLIENT_OUT_DIR`:

```sh
LIBERO_CLIENT_OUT_DIR="../clients/web/src/generated/libero" gleam run -m libero
```

## Conventions

Libero is opinionated:

- **Source directory** is always `src/`. Files under `src/generated/` are skipped.
- **Context type** is always `ServerContext`, defined in the `server_context` module.
- **Wire tag** is always `"rpc"` — the first element of the call envelope 3-tuple.
- **Output directory** is always `src/generated/libero/`.
- **Client output directory** is opt-in via `LIBERO_CLIENT_OUT_DIR`.

## Handler-as-Contract

Libero's scanner detects RPC endpoints by checking each public function for:

1. A `server_` prefix on the name
2. A `ServerContext` parameter
3. A return type of `Result(value, error)` (read-only) or `#(Result(value, error), ServerContext)` (mutating)
4. All types in the signature are builtins or resolvable from the source tree

```gleam
pub fn server_get_items(
  server_ctx server_ctx: ServerContext,
) -> Result(List(Item), ItemError) {
  Ok(server_ctx.items)
}

pub fn server_create_item(
  params params: ItemParams,
  server_ctx server_ctx: ServerContext,
) -> #(Result(Item, ItemError), ServerContext) {
  // ...
}
```

From these, the generated dispatch produces:
- A `ClientMsg` type: `GetItems`, `CreateItem(params: ItemParams)`
- A `handle` function that decodes the wire envelope, routes to the handler, and encodes the response

## Library API

Call the functions directly when you need programmatic control over the pipeline:

```gleam
import libero

let assert Ok(endpoints) = libero.scan()
let seeds = libero.collect_seeds(endpoints)
let assert Ok(discovered) = libero.walk(seeds)
let dispatch_src = libero.generate_dispatch(endpoints)
let decoders_js = libero.generate_decoders_ffi(discovered, endpoints)
let decoders_gleam = libero.generate_decoders_gleam()
```

All functions return strings — you decide where to write them. Each step is exposed separately so frameworks can inject custom logic between scan, walk, and codegen.

## Wire protocol

The call envelope is a 3-tuple: `{module_name_binary, request_id, client_msg_value}`, serialized as [ETF](https://www.erlang.org/doc/apps/erts/erl_ext_dist.html) (Erlang Term Format). Responses are tagged frames: `<<0, request_id:32-big, etf_response_bytes>>`. Server pushes use tag `1` with no request ID.

On the BEAM side, `term_to_binary`/`binary_to_term` handle everything natively. On JavaScript, libero ships its own ETF encoder/decoder with a typed decoder layer on top.

For safe decoding of untrusted ETF input, use `wire.decode_safe` which returns `Result(a, DecodeError)`.

## Panic catching

The generated dispatch wraps every handler call in `trace.try_call`. If a handler panics:
- The client receives `Error(InternalError(trace_id, "Something went wrong"))`
- The full panic reason is logged to stderr with the trace ID for correlation
- The caller's process stays alive with its original context intact

## RemoteData

Libero ships `RemoteData` and `RpcData` types for client-side state management:

```gleam
pub type RemoteData(value, error) {
  NotAsked
  Loading
  Failure(error)
  Success(value)
}

pub type RpcOutcome(domain) {
  TransportError(RpcError)
  DomainError(domain)
}

pub type RpcData(value, domain) = RemoteData(value, RpcOutcome(domain))
```

`TransportError` covers `MalformedRequest`, `UnknownFunction`, and `InternalError`. `DomainError` wraps the handler's own error type. Client code pattern-matches exhaustively on `RpcData` with no unhandled states.

## Modules

| Module | Target | Purpose |
|--------|--------|---------|
| `libero` | both | Public API facade and CLI entry point |
| `libero/scanner` | erlang | Handler discovery from source |
| `libero/walker` | erlang | Type graph traversal |
| `libero/codegen_dispatch` | erlang | Server dispatch generator |
| `libero/codegen_decoders` | erlang | JS typed decoder generator |
| `libero/wire` | both | ETF codec (encode, decode, call envelope) |
| `libero/error` | both | RpcError, DecodeError |
| `libero/remote_data` | both | RemoteData/RpcData state machine for clients |
| `libero/field_type` | both | Structured type representation |
| `libero/trace` | erlang | Panic catching + trace ID generation |
| `libero/format` | erlang | Gleam code formatter integration |
| `libero/gen_error` | both | Structured codegen error types |
| `libero/codegen` | both | Cross-cutting codegen helpers |

## Prior Art

Libero's JS-side ETF codec is independently implemented but aligns with [arnu515/erlang-etf.js](https://github.com/arnu515/erlang-etf.js) (MIT) on `BIT_BINARY_EXT` handling and atom-length validation. Credit to that project for clear spec references. Libero's codec adds encoding, a BEAM-native path, the float field registry, and offset-based parsing.

## License

MIT. See [LICENSE](https://github.com/pairshaped/libero/blob/master/LICENSE).
