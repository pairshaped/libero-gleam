---
# libero-flpl
title: Add Erlang-side resource caps for ETF decode
status: todo
type: bug
priority: high
tags:
    - security
    - etf
    - wire
created_at: 2026-05-08T15:14:20Z
updated_at: 2026-05-09T16:54:35Z
---

The JS ETF decoder (rpc_ffi.mjs) enforces MAX_COLLECTION_LEN=16M and MAX_BINARY_BYTES=64M to prevent a malicious frame from triggering gigabyte allocations. The Erlang side has no equivalent: libero_ffi:decode_safe/1 calls erlang:binary_to_term(Bin, [safe]) directly, which will happily decode arbitrarily large lists/tuples or deeply nested structures up to whatever mist's frame limit allows.

This is the only currently-open class of pre-authentication DoS we can identify against the v3 admin server: a small frame containing a single large list-of-tuples header can balloon into an enormous decoded term.

Fix: walk the decoded term once after binary_to_term and reject if any list/tuple exceeds N elements or nesting exceeds D levels. Mirror the JS caps. OR explore OTP options like {max_term_size, _} if available in our OTP version.

Reference: https://security.erlef.org/secure_coding_and_deployment_hardening/serialisation.html — calls out resource exhaustion as a class the [safe] flag does not address.



---
**See also:** [`docs/wire-type-identity.md`](../docs/wire-type-identity.md). Independent of this bean, but lands as part of the same hardening arc. The spec subsumes `libero-ljv6` and `libero-3ccw`.



Current status after partial implementation:
- `libero_ffi:decode_safe/1` was fixed so `apply_decode_term(Term)` runs inside the `try` expression. Depth errors raised by `decode_term` now return `DecodeError` instead of escaping.
- Generated `decode_term/1` and `encode_term/1` now have `/2` depth-tracking walkers with a hard limit of 512.
- This is not enough to close the bean. The depth limit only covers the generic fallthrough path where `decode_term` recurses into unknown tuples, lists, or maps itself.

Remaining gap:
- Dispatch does not call `decode_term`. Incoming RPC payloads go through `wire.decode_call` and then generated `decode_client_msg` plus per-type decoders, so deeply nested custom-type request bodies still bypass runtime depth tracking.
- Known custom types also bypass the generic depth walker on the `decode_safe` path. `decode_term(Tuple, Depth)` matches the known wire tag and delegates to `decode_<type>(Tuple)`, and those generated per-type decoders do not carry depth.
- Recursive custom types such as `Tree` can still recurse through generated `decode_<type>` calls until the process stack or heap fails.

Implementation direction:
- Thread a runtime `Depth` counter through generated `decode_<type>/2` functions, with `/1` wrappers preserved for the existing public exported API.
- Have `decode_term/2` delegate to known custom-type decoders as `decode_<type>(Tuple, Depth + 1)`.
- Have generated `decode_expr` pass depth through nested user types, lists, maps, tuples, options, and results.
- Add a depth-aware `decode_client_msg/2` wrapper path so dispatch request decoding gets the same protection.
- Keep `max_heap_size` documentation as the large-flat-structure backstop; do not treat it as a replacement for runtime depth rejection.

Acceptance additions:
- `wire.decode_safe` returns `Error(DecodeError(...))` for over-depth generic terms.
- `wire.decode_safe` returns `Error(DecodeError(...))` for over-depth recursive custom types.
- Generated dispatch returns `MalformedRequest` for an over-depth custom-type request payload and preserves the original request ID.



Decision:
- Implement runtime depth tracking through generated per-type decode functions. This is the simplest proper fix for the remaining depth hole in the current architecture because generated code owns every recursive typed decode edge.
- Preserve `/1` wrappers where cheap, but API compatibility is not the main constraint. The only known consumer is owned by this project. Optimize for correct rejection and readable generated code.
- Do not treat `max_heap_size` as the fix for this bean. Keep it as an operational backstop for large flat terms and other allocation-heavy inputs.
- Decode is the security path. Encode-side depth limits are useful defense-in-depth, but closing this bean requires depth-aware decode paths for `decode_term`, `decode_client_msg`, and generated per-type decoders.

Rejected alternatives:
- Generic post-decode validation alone is weaker here because dispatch and known custom-type paths still need typed recursive decode protection.
- Process heap limits fail after allocation pressure and do not give a controlled validation failure.
- Iterative decoder rewrites are much more invasive than threading a counter through existing generated recursion.
- Frame-size limits remain useful, but they do not address small deeply nested terms that expand into risky recursive decode work.


Implementation notes for the next worker:

Terminology:
- There are two different "depth" ideas in `src/libero/codegen_wire_erl.gleam` today.
- The existing Gleam helper argument named `depth` in `encode_expr` and `decode_expr` is a compile-time counter used to make temporary variable names such as `_X0` and `_T0_1`.
- The new protection needs a runtime Erlang variable, probably named `Depth`, that is threaded through generated Erlang decode functions.
- Keep those names distinct in the generator. Consider renaming the compile-time one to `var_depth` or `name_depth` while touching this area.

Suggested generated Erlang shape:

```erlang
decode_m__tree(Value) ->
    decode_m__tree(Value, 0).

decode_m__tree(_Value, Depth) when Depth >= 512 ->
    error({wire_depth_exceeded, Depth});
decode_m__tree({'hash_for_leaf', F0}, Depth) ->
    {leaf, F0};
decode_m__tree({'hash_for_node', F0, F1}, Depth) ->
    {node, decode_m__tree(F0, Depth + 1), decode_m__tree(F1, Depth + 1)}.
```

For `decode_term`:

```erlang
decode_term(Term) ->
    decode_term(Term, 0).

decode_term(_Term, Depth) when Depth >= 512 ->
    error({wire_depth_exceeded, Depth});
decode_term(Tuple, Depth) when is_tuple(Tuple), tuple_size(Tuple) > 0 ->
    case {element(1, Tuple), tuple_size(Tuple)} of
        {'hash', Arity} -> decode_m__type(Tuple, Depth + 1);
        _ -> list_to_tuple([decode_term(E, Depth + 1) || E <- tuple_to_list(Tuple)])
    end;
...
```

For `decode_client_msg`:

```erlang
decode_client_msg(Msg) ->
    decode_client_msg(Msg, 0).

decode_client_msg(_Msg, Depth) when Depth >= 512 ->
    error({wire_depth_exceeded, Depth});
decode_client_msg({server_save_tree, F0}, Depth) ->
    {server_save_tree, decode_m__tree(F0, Depth + 1)};
decode_client_msg(Other, _Depth) ->
    Other.
```

Generator changes likely needed:
- `build_exports` should keep the existing `/1` exports. Export `/2` only if generated Gleam dispatch calls the Erlang external with arity 2. The lower-risk route is to keep dispatch calling `decode_client_msg/1` and make `/1` call `/2` internally.
- `emit_type_transformers` probably needs to emit decode wrappers and depth-aware decode clauses. Encoding can remain as-is unless the current encode depth work is intentionally kept.
- `emit_decode_clause` needs access to a runtime depth expression, not just the compile-time temp-name counter.
- `decode_expr` should accept something like `runtime_depth_expr: String` in addition to the temp-name counter.
- For `UserType`, emit `decode_<qual>(Expr, RuntimeDepth + 1)`.
- For `ListOf`, emit `[decode_inner(_X, RuntimeDepth + 1) || _X <- Expr]` when inner decoding is needed.
- For `DictOf`, emit `maps:map(fun(_K, _X) -> decode_inner(_X, RuntimeDepth + 1) end, Expr)` when value decoding is needed.
- For `TupleOf`, increment for each element that needs nested decoding.
- For `OptionOf` and `ResultOf`, increment before decoding the contained value.
- Primitive fields can still pass through unchanged, but they are only reached after the caller's function-level depth guard has run.
- If a container inner type is primitive and the generator currently optimizes to return `expr`, that optimization is fine. The containing function's guard has already counted the containing custom type. Only nested structures that require generated recursion need more checks.

Depth counting policy:
- Be consistent more than perfect. A reasonable rule is: every descent from a containing term into a nested custom type or generic container increments `Depth` by 1.
- The cap may reject at depth 512 or just before descending past 512. Existing partial code uses `Depth >= 512`, so prefer keeping that behavior unless tests make a better boundary clearer.
- Add tests around the boundary if practical: depth 511 accepted, depth 512 rejected, or whatever exact contract the generated code establishes.

Dispatch behavior:
- `wire.decode_call` will still run `binary_to_term([safe])` first, so this does not stop allocation of the initial Erlang term. It does stop unbounded generated recursive decode after that point.
- Generated dispatch already wraps `wire_decode_client_msg(msg)` and the `ClientMsg` pattern match in `trace.try_call` inside `dispatch_known`, so depth errors from `decode_client_msg/1` should become `MalformedRequest` with the original request ID.
- Add a regression that proves this. Do not rely on reasoning alone.

`decode_safe` behavior:
- `src/libero_ffi.erl` should keep `apply_decode_term(Term)` inside the `try` expression so errors raised by generated `decode_term` or `decode_<type>` are returned as `{error, {decode_error, Msg}}`.
- Add a regression that fails if `apply_decode_term` escapes the `try` body again.

Tests to add or update:
- Codegen string tests for exported `/1` wrappers and generated `/2` clauses.
- Compile-and-apply tests for a recursive custom type, preferably `Tree`, where a wire-shaped nested value over the cap raises `{wire_depth_exceeded, Depth}` through the generated decoder.
- `wire.decode_safe` test for an over-depth generic term that exercises `decode_term` fallback recursion.
- `wire.decode_safe` test for an over-depth known recursive custom type that exercises `decode_<type>/2` recursion.
- Wire E2E dispatch test that sends an over-depth custom-type request body and asserts `MalformedRequest` with the original request ID preserved.
- Keep or add tests for valid nested payloads below the limit so normal recursive custom types still decode.

Likely files:
- `src/libero/codegen_wire_erl.gleam`
- `src/libero_ffi.erl` if the try/catch fix is not already present in the final patch
- `test/libero/codegen_wire_erl_test.gleam`
- `test/libero/decode_safe_test.gleam` or a new focused test module
- `test/js/wire_e2e_dispatch_manifest.escript`
- `test/js/wire_e2e_dispatch_test.mjs`
- generated Birdie snapshots if emitted code changes are snapshot-covered

Verification before closing:
- `gleam test`
- `test/run_js_tests.sh`
- `gleam format --check src test`
- `beans check`

Review traps:
- Do not close this bean if only `decode_term/2` has depth tracking. Known custom types and dispatch must be covered.
- Do not rely on `max_heap_size` as proof of fix. It is only a process-level backstop.
- Do not accidentally change the ETF wire shape.
- Do not accidentally remove the existing `/1` generated functions unless all generated and downstream callers are updated in the same patch.
- Do not let Erlang `try ... of ... catch` scope hide an escaping `apply_decode_term` error. Test it.
