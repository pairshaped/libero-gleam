# Libero v6: Library Cleanup

Strip libero down to a focused RPC plumbing library. Lando consumes it as a dependency for handler scanning, dispatch codegen, ETF wire protocol, and decoder generation. No backwards compatibility with v5.

## What libero becomes

A library with four capabilities:

1. **Scanner**: discover handler functions by signature (pub fn server_* with ServerContext param, returns Result)
2. **Dispatch codegen**: generate server-side routing from scanned endpoints
3. **Wire protocol**: ETF encode/decode, call envelopes, frame tagging (both Erlang and JS targets)
4. **Decoder codegen**: generate JS type registration for ETF decoding

Libero does NOT: generate client stubs, manage WebSocket connections, handle SSR, scaffold servers, manage push delivery, or parse project-specific TOML config.

## Public API (what lando calls)

```gleam
import libero/scanner.{type HandlerEndpoint}
import libero/walker
import libero/field_type.{type FieldType}
import libero/codegen_dispatch
import libero/codegen_decoders
import libero/wire
import libero/remote_data.{type RpcData}
import libero/error.{type RpcError}
```

### Scanner

```gleam
// Scan a source directory for handler functions.
// Looks for: pub fn server_*(args..., server_context: T) -> Result(ok, err)
// Returns the endpoint list or structured errors.
pub fn scan(src_dir: String, context_type_name: String) -> Result(List(HandlerEndpoint), List(GenError))
```

Changes from v5:
- No more `shared_src` parameter (no shared directory concept)
- Accepts `context_type_name` so it's not hardcoded to "HandlerContext" (lando uses "ServerContext")
- Looks for `server_` prefix on function names (not just signature matching)
- Strips `server_` prefix in the `fn_name` field of HandlerEndpoint (wire name is without prefix)

### Walker

```gleam
// Walk the type graph starting from seeds, discovering all reachable custom types.
// Seeds come from scanner output (param/return types of endpoints).
pub fn walk(seeds: List(#(String, String)), file_paths: List(String), src_root: String) -> List(DiscoveredType)
```

No changes needed, this already works generically.

### Dispatch codegen

```gleam
// Generate dispatch.gleam source from scanned endpoints.
// The dispatch function signature:
//   pub fn handle(server_context: a, data: BitArray) -> BitArray
// Returns an ETF-encoded Result: Ok(response) or Error(RpcError).
// Panics in handler code are caught and returned as InternalError with trace ID.
pub fn generate(endpoints: List(HandlerEndpoint), context_module: String) -> String
```

Changes from v5:
- Context type/module is configurable (not hardcoded to HandlerContext)
- No ws_logger integration
- Keeps panic catching (trace.try_call wraps each handler invocation). A panicked handler returns a structured InternalError response, not a crash. This is dispatch's responsibility because it's the boundary between wire data and user code.

### Decoder codegen

```gleam
// Generate the JS decoder registration file from discovered types.
pub fn generate_decoders_ffi(discovered: List(DiscoveredType)) -> String
pub fn generate_decoders_gleam(discovered: List(DiscoveredType)) -> String
```

### Wire (runtime, no changes)

```gleam
pub fn encode(value: a) -> BitArray
pub fn decode(data: BitArray) -> a
pub fn decode_safe(data: BitArray) -> Result(a, DecodeError)
pub fn decode_call(data: BitArray) -> Result(#(String, Int, Dynamic), DecodeError)
pub fn encode_call(module: String, request_id: Int, msg: a) -> BitArray
pub fn tag_response(request_id: Int, data: BitArray) -> BitArray
pub fn tag_push(module: String, msg: a) -> BitArray
pub fn variant_tag(value: Dynamic) -> Result(String, Nil)
pub fn coerce(value: a) -> b
```

### Remote data (runtime, no changes)

```gleam
pub type RpcData(ok, err)  // Success(ok) | Failure(RpcFailure(err))
pub type RpcFailure(err)   // DomainError(err) | TransportError(RpcError)
```

## Files: keep, modify, delete

### Keep as-is
- `src/libero/field_type.gleam` (171 lines) - type representation
- `src/libero/wire.gleam` (200 lines) - ETF codec
- `src/libero/error.gleam` (47 lines) - RPC error types
- `src/libero/remote_data.gleam` (192 lines) - RpcData type
- `src/libero/trace.gleam` (48 lines) - panic catching + trace IDs
- `src/libero/format.gleam` (91 lines) - gleam format runner
- `src/libero_ffi.erl` - signal trapping, try_call, unique_id, ETF encode
- `src/libero_wire_ffi.erl` - wire codec FFI (decode_call, variant_tag)
- `src/libero/rpc_ffi.mjs` - JS ETF codec and typed decode helpers
- `src/libero/decoders_prelude.mjs` - JS type registration
- `src/libero/libero_ffi.mjs` - JS unique_id

### Modify
- `src/libero/scanner.gleam` (623 lines) - add server_ prefix detection, configurable context type name, remove shared_src dependency
- `src/libero/walker.gleam` (673 lines) - remove shared_src assumption, work with any source paths
- `src/libero/codegen_dispatch.gleam` (191 lines) - configurable context type/module, simplify error handling
- `src/libero/codegen_decoders.gleam` (474 lines) - decouple from config.gleam, accept types directly
- `src/libero/codegen.gleam` (230 lines) - keep only the helpers needed by dispatch/decoders (path utils, naming)
- `src/libero/gen_error.gleam` (179 lines) - keep, maybe simplify
- `src/libero.gleam` (30 lines) - remove CLI, or keep as optional CLI entry point
- `gleam.toml` - remove mist, gleam_http, lustre deps (those are consumer concerns now)

### Delete
- `src/libero/cli/gen.gleam` - orchestrator (consumer's job now)
- `src/libero/codegen_stubs.gleam` - client stub gen (consumer generates its own)
- `src/libero/codegen_server.gleam` - server scaffolding (consumer's job)
- `src/libero/config.gleam` - libero-specific config type (too opinionated)
- `src/libero/toml_config.gleam` - libero-specific TOML parsing
- `src/libero/push.gleam` - push delivery (consumer handles this)
- `src/libero/rpc.gleam` - client-side send (consumer generates this)
- `src/libero/ssr.gleam` - SSR handling (consumer's job)
- `src/libero/ssr_decode.gleam` - SSR flag decode (consumer's job)
- `src/libero/ws_logger.gleam` - logger type (consumer uses standard logging)
- `src/libero_push_ffi.erl` - push FFI
- `src/libero_cli_ffi.erl` - CLI-only utilities (merge any needed bits into libero_ffi.erl)

## Scanner changes in detail

Current detection (v5): function is a handler if last param is `HandlerContext` and return is `Result` or `#(Result, HandlerContext)`.

New detection (v6): function is a handler if:
1. Name starts with `server_` (configurable prefix)
2. Has a parameter whose type matches the configured context type name (e.g. "ServerContext")
3. Return type is `Result(ok, err)` or `#(Result(ok, err), ContextType)`

The `fn_name` field in `HandlerEndpoint` stores the name WITHOUT the prefix (this becomes the wire name).

Example:
```gleam
// User writes:
pub fn server_login(email: String, password: String, server_context: ServerContext) -> Result(Token, List(String))

// Scanner produces:
HandlerEndpoint(
  module_path: "pages/login",
  fn_name: "login",  // prefix stripped
  return_ok: StringField,  // or UserType for Token
  return_err: ListOf(StringField),
  params: [("email", StringField), ("password", StringField)],
  mutates_context: False,
)
```

## Dependency changes

### Remove from gleam.toml
- `mist` (server framework, consumer's concern)
- `gleam_http` (HTTP types, consumer's concern)
- `lustre` (UI framework, consumer's concern)

### Keep
- `gleam_stdlib`
- `glance` (AST parsing for scanner)
- `simplifile` (reading source files)
- `tom` (only if libero keeps any TOML parsing, otherwise remove)
- `glexer` (used by gen_error for source location)

## Test plan

- Scanner tests: update for server_ prefix convention, remove shared_src fixtures
- Dispatch codegen tests: update for new output shape
- Walker tests: should pass with minimal changes
- Wire roundtrip tests: unchanged
- Decoder codegen tests: update for new API
- Remove tests for deleted modules (stubs, server, config, push, ssr)

## How lando uses it

After cleanup, lando's codegen pipeline (`src/lando.gleam`) would:

```gleam
import libero/scanner
import libero/walker
import libero/codegen_dispatch
import libero/codegen_decoders

fn run() {
  // ... existing route scanning ...

  // Scan for server handlers in page files
  let endpoints = scanner.scan(config.pages_root, "ServerContext")

  // Walk types reachable from handler signatures
  let seeds = scanner.collect_seeds(endpoints)
  let discovered = walker.walk(seeds, page_paths, config.pages_root)

  // Generate server dispatch
  let dispatch_source = codegen_dispatch.generate(endpoints, "server_context")
  write_file(config.output_dispatch, dispatch_source)

  // Generate JS decoders
  let decoders_ffi = codegen_decoders.generate_decoders_ffi(discovered)
  let decoders_gleam = codegen_decoders.generate_decoders_gleam(discovered)

  // Generate client stubs (lando's own code, not libero's)
  let stubs = lando_client.generate_stubs(endpoints)
  // ... etc
}
```

## Migration from lando's current code

Once libero v6 is ready, lando:
1. Adds libero as a dependency
2. Deletes its own copies: `src/lando/field_type.gleam`, `src/lando/walker.gleam`, wire-related code in `src/lando_runtime/`
3. Replaces `server_update`/`ServerModel`/`server_init` with handler scanning via libero
4. Rewrites client codegen to generate typed stubs from `HandlerEndpoint` list instead of from ToServer/ToClient types
5. Rewrites WS handler to call libero dispatch instead of its own server_dispatch
6. Adds HTTP handler that also calls libero dispatch

## Implementation order

1. Delete everything in the "delete" list
2. Remove dependencies (mist, gleam_http, lustre)
3. Modify scanner for server_ prefix + configurable context type
4. Modify codegen_dispatch for configurable context
5. Modify codegen_decoders to accept types directly (no config dependency)
6. Clean up codegen.gleam (remove stubs/server helpers)
7. Update/fix tests
8. Update gleam.toml version to 6.0.0
