# Libero

RPC plumbing library for Gleam. Provides handler scanning, dispatch codegen, ETF wire protocol, and typed decoder generation. Consumed as a dependency by framework packages (e.g. lando).

## What it does

Libero turns handler function signatures into a typed RPC pipeline:

1. **Scanner** discovers handler endpoints by inspecting function signatures (public, `server_` prefix, context parameter, Result return type).
2. **Walker** traverses the type graph from those signatures, finding all custom types reachable from params and return types.
3. **Dispatch codegen** produces a Gleam module with a `ClientMsg` type and a `handle` function that routes incoming wire envelopes to the correct handler, with automatic panic catching.
4. **Decoder codegen** produces JavaScript typed decoders for every discovered type, so the JS client can reconstruct Gleam values from ETF without manual codec work.

The wire format is [ETF](https://www.erlang.org/doc/apps/erts/erl_ext_dist.html) (Erlang Term Format). Gleam types serialize automatically without explicit codecs. On the BEAM side, `term_to_binary`/`binary_to_term` handle everything natively. On JavaScript, libero ships its own ETF encoder/decoder with a typed decoder layer on top.

## Installation

```toml
[dependencies]
libero = ">= 6.0.0 and < 7.0.0"
```

## Public API

```gleam
import libero

// Discover handler endpoints from a source tree
libero.scan(src_dir: "src", context_type_name: "HandlerContext")

// Collect type seeds for the walker
libero.collect_seeds(endpoints)

// Walk the type graph to discover all custom types
libero.walk(seeds: seeds, file_paths: file_paths)

// Generate server dispatch module
libero.generate_dispatch(
  endpoints: endpoints,
  context_module: "handler_context",
  context_type_name: "HandlerContext",
  wire_module_tag: "rpc",
)

// Generate JS typed decoders
libero.generate_decoders_ffi(
  discovered: discovered_types,
  endpoints: endpoints,
  prelude_import_path: "../../libero/libero/decoders_prelude.mjs",
  relpath_prefix: "../../",
)
libero.generate_decoders_gleam(ffi_module_path: "./rpc_decoders_ffi.mjs")
```

## Handler-as-Contract

Libero's scanner detects RPC endpoints by checking:

1. **Public function** with a `server_` prefix
2. **Context parameter** (a named type matching the configured context type name)
3. **Return type** is either:
   - `Result(value, error)` for read-only handlers
   - `#(Result(value, error), ContextType)` for mutating handlers
4. **All types** in the signature are builtins or resolvable from the scanned source tree

```gleam
pub fn server_get_items(
  handler_ctx handler_ctx: HandlerContext,
) -> Result(List(Item), ItemError) {
  Ok(handler_ctx.items)
}

pub fn server_create_item(
  params params: ItemParams,
  handler_ctx handler_ctx: HandlerContext,
) -> #(Result(Item, ItemError), HandlerContext) {
  // ...
}
```

From these, `generate_dispatch` produces:
- A `ClientMsg` type: `GetItems`, `CreateItem(params: ItemParams)`
- A `handle` function that decodes the wire envelope, routes to the handler, and encodes the response

## Panic catching

The generated dispatch wraps every handler call in `trace.try_call`. If a handler panics:
- The client receives `Error(InternalError(trace_id, "Something went wrong"))`
- The full panic reason is logged to stderr with the trace ID for correlation
- The caller's process stays alive with its original context intact

## Wire protocol

The call envelope is a 3-tuple: `{module_name_binary, request_id, client_msg_value}`, serialized as ETF. The response is a tagged frame: `<<0, request_id:32-big, etf_response_bytes>>` for responses, `<<1, etf_push_bytes>>` for server pushes.

For safe decoding of untrusted ETF input, use `wire.decode_safe` which returns `Result(a, error.DecodeError)`.

## Modules

| Module | Target | Purpose |
|--------|--------|---------|
| `libero` | both | Public API facade |
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

Framework packages use these to wrap decoded responses so client views can pattern-match exhaustively on all states.

## Prior Art

Libero's JS-side ETF codec is independently implemented but aligns with [arnu515/erlang-etf.js](https://github.com/arnu515/erlang-etf.js) (MIT) on `BIT_BINARY_EXT` handling and atom-length validation. Credit to that project for clear spec references. Libero's codec adds encoding, a BEAM-native path, the float field registry, and offset-based parsing.

## License

MIT. See [LICENSE](https://github.com/pairshaped/libero/blob/master/LICENSE).
