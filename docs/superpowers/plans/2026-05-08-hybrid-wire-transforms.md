# Hybrid Wire Transform Architecture Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore typed generated transforms at wire boundaries as the primary correctness mechanism, keeping centralized `encode_term/decode_term` as a fallback safety net.

**Architecture:** Two layers. The primary layer is typed boundary transforms: a generated `decode_client_msg/1` that decodes ALL inbound ClientMsg variants in one function, and per-endpoint `encode_response_<fn>/1` functions that encode handler results. These go in the existing wire Erlang module and are called from the dispatch via FFI. The fallback layer is `encode_term/decode_term` in `wire.encode`/`wire.decode`, which catches incidental paths (SSR flags, future boundaries). The fallback is idempotent: already-hashed atoms pass through unchanged, so running both layers is safe.

**Tech Stack:** Gleam, Erlang FFI, codegen (`codegen_wire_erl.gleam`, `codegen_dispatch.gleam`, `libero_ffi.erl`)

---

## File Map

| File | Change |
|------|--------|
| `src/libero/codegen_wire_erl.gleam` | Add `emit_decode_client_msg` and `emit_encode_responses`. Accept endpoints in `generate`. |
| `src/libero/codegen_dispatch.gleam` | Add two FFI calls: `wire_decode_client_msg(msg)` before coerce, `wire_encode_response_<fn>(result)` before `wire.encode`. |
| `src/libero/wire_identity.gleam` | Remove `check_bare_arity_uniqueness`. |
| `src/libero/gen_error.gleam` | Remove `BareAtomArityCollision` variant. |
| `src/libero.gleam` | Pass endpoints to `generate_wire_erl`. |
| Tests | Update wire_erl tests, dispatch tests, wire_identity tests. |
| Rally | Revert SSR handler to call typed transforms for ClientContext and page models. |

---

### Task 1: Generate `decode_client_msg/1` in the wire module

**Files:**
- Modify: `src/libero/codegen_wire_erl.gleam`
- Modify: `src/libero.gleam`
- Test: `test/libero/codegen_wire_erl_test.gleam`

Add `endpoints: List(HandlerEndpoint)` parameter to `generate`. Emit a `decode_client_msg/1` function that pattern-matches on each endpoint's function name atom and decodes user-type fields:

```erlang
decode_client_msg({server_echo_item, F0}) ->
    {server_echo_item, decode_shared_types__item(F0)};
decode_client_msg({server_update_discount, F0, F1}) ->
    {server_update_discount, F0, decode_admin_discounts__discount_params(F1)};
decode_client_msg(server_load_discounts) ->
    server_load_discounts;
decode_client_msg(Other) ->
    Other.
```

Each clause matches the function name atom (NOT hashed, since RPC function names aren't user types) and applies the appropriate transform to each field. Primitive fields pass through. 0-arity endpoints are atom-only (no tuple). The fallback clause passes unknown messages through.

Field transforms reuse the existing `decode_expr`/`encode_expr` recursive logic from `codegen_wire_erl.gleam`, which already handles the full `FieldType` tree: `UserType`, `ListOf`, `OptionOf`, `ResultOf`, `DictOf`, `TupleOf`, and arbitrary nesting (e.g., `DictOf(_, List(UserType(...)))`). Tasks 1 and 2 should extract a shared "emit Erlang expression for this FieldType" helper if one doesn't already exist, rather than duplicating the field-type dispatch.

Export `decode_client_msg/1` from the wire module.

Update `libero.gleam` to pass `endpoints` to `generate_wire_erl`.

- [ ] **Step 1: Write test** — generate wire module with endpoints, assert `decode_client_msg/1` appears in exports and contains expected clauses
- [ ] **Step 2: Implement `emit_decode_client_msg`** — new function in codegen_wire_erl
- [ ] **Step 3: Update `generate` signature** to accept endpoints, call emitter, add to exports
- [ ] **Step 4: Update `libero.gleam`** to pass endpoints
- [ ] **Step 5: Update rally** to pass endpoints to `generate_wire_erl`
- [ ] **Step 6: Run `gleam test`, `gleam run -m glinter`**
- [ ] **Step 7: Commit**

---

### Task 2: Generate per-endpoint `encode_response_<fn>/1` in the wire module

**Files:**
- Modify: `src/libero/codegen_wire_erl.gleam`
- Test: `test/libero/codegen_wire_erl_test.gleam`

For each endpoint, emit a function that transforms the handler's `Result(OkType, ErrType)`:

```erlang
encode_response_echo_item({ok, V}) ->
    {ok, encode_shared_types__item(V)};
encode_response_echo_item({error, E}) ->
    {error, E}.

encode_response_typed_err({ok, V}) ->
    {ok, encode_shared_types__item(V)};
encode_response_typed_err({error, E}) ->
    {error, encode_shared_types__item_error(E)}.

encode_response_echo_int({ok, V}) -> {ok, V};
encode_response_echo_int({error, E}) -> {error, E}.
```

For primitive Ok/Err types, the function is a passthrough. Only emit transform calls for UserType/container Ok/Err types. The encoder for each side follows the same field-type dispatch as `decode_client_msg` (UserType → call transformer, List/Option/Dict of UserType → inline container mapping, primitives → passthrough).

Export each `encode_response_<fn_name>/1`.

Endpoints with no user types in either Ok or Err can still get a passthrough function for uniformity (simpler dispatch codegen), or can be skipped (dispatch emits the encode call only when the function exists). The simpler option: always emit, even for passthrough.

- [ ] **Step 1: Write test** — endpoint with UserType Ok + UserType Err, endpoint with primitive Ok + Nil Err, assert both functions appear with correct transform/passthrough
- [ ] **Step 2: Implement `emit_encode_responses`**
- [ ] **Step 3: Add to exports and `generate` output**
- [ ] **Step 4: Run tests, commit**

---

### Task 3: Wire typed transforms into dispatch codegen

**Files:**
- Modify: `src/libero/codegen_dispatch.gleam`
- Modify: `src/libero.gleam`
- Test: `test/libero/endpoint_dispatch_test.gleam`
- Test: `test/birdie_snapshots/dispatch_*.accepted`

Add `wire_module: option.Option(String)` parameter back to `generate()` (it was removed in Task 4 of the previous plan). When set:

1. Emit ONE FFI external for `decode_client_msg`:
```gleam
@external(erlang, "<wire_module>", "decode_client_msg")
fn wire_decode_client_msg(msg: a) -> b
```

2. Emit ONE FFI external per endpoint for `encode_response_<fn>`:
```gleam
@external(erlang, "<wire_module>", "encode_response_echo_item")
fn wire_encode_response_echo_item(result: a) -> b
```

3. In `dispatch_known`, add the decode call BEFORE coerce:
```gleam
fn dispatch_known(msg, request_id, server_context) {
  let msg = wire_decode_client_msg(msg)
  let typed_msg: ClientMsg = wire.coerce(msg)
  case typed_msg { ... }
}
```

4. In each case arm, add the encode call before `wire.encode`:
```gleam
Ok(result) ->
  let result = wire_encode_response_echo_item(result)
  #(wire.tag_response(request_id:, data: wire.encode(Ok(result))), ctx)
```

This is much simpler than the old approach: no per-param decode lets, no container mapping helpers, no wire_transform_expr machinery. Just two categories of FFI call.

The `msg_type` handler path works automatically: `decode_client_msg` decodes the message fields before coerce, so `wire.coerce(typed_msg)` gives the handler correctly-decoded bare-atom values.

- [ ] **Step 1: Add `wire_module` param and FFI externals**
- [ ] **Step 2: Add `wire_decode_client_msg(msg)` call in `dispatch_known`**
- [ ] **Step 3: Add per-endpoint `wire_encode_response_<fn>(result)` calls**
- [ ] **Step 4: Update `libero.gleam`** to pass wire_module
- [ ] **Step 5: Update tests, accept snapshots**
- [ ] **Step 6: Run `gleam test`, `test/run_js_tests.sh`, `gleam run -m glinter`**
- [ ] **Step 7: Commit**

---

### Task 4: Remove `check_bare_arity_uniqueness`

**Files:**
- Modify: `src/libero/wire_identity.gleam`
- Modify: `src/libero/gen_error.gleam`
- Modify: `src/libero/codegen_wire_erl.gleam`
- Modify: `test/libero/wire_identity_test.gleam`
- Modify: `test/libero/codegen_wire_erl_test.gleam`

Delete `check_bare_arity_uniqueness` and the `BareAtomArityCollision` error variant. Remove the call from `codegen_wire_erl.generate`. Remove/update the tests that covered the check.

`encode_term` still matches on `{bare_atom, arity}`. For ambiguous pairs, it picks one arbitrarily (first match in the generated case clause). The fallback is best-effort and NOT identity-safe for ambiguous lowered shapes: if both sides of a round-trip use only the fallback (no typed boundary transform), a wrong hash could decode into the wrong same-shape constructor on BEAM. Generated typed boundary transforms are the only correctness mechanism for type identity. The fallback catches incidental paths and framework wrappers where full type identity is not critical.

Restore the codegen_wire_erl test that was modified in Task 3 of the previous plan (two Discount types with same arity from different modules). It should now succeed without error.

Add tests that exercise same-name/same-arity types through actual dispatch boundaries (not just echo handlers):
- One dispatch INBOUND test where the handler pattern-matches on the nested value (proves `decode_client_msg` routes to the correct per-type decoder)
- One dispatch OUTBOUND test where two same-arity Waiver-like records encode to different hashes (proves `encode_response_X` uses the correct per-type encoder)

Echo tests alone are too forgiving for this case because they don't inspect the decoded structure.

- [ ] **Step 1: Delete check, error variant, and call**
- [ ] **Step 2: Update existing tests**
- [ ] **Step 3: Add same-name/same-arity dispatch boundary tests**
- [ ] **Step 4: Run tests, commit**

---

### Task 5: Reintroduce typed transforms in rally SSR handler

**Files:**
- Modify: rally `src/rally/generator/ssr_handler.gleam`
- Modify: rally `src/rally.gleam`
- Modify: rally test files

Re-add `wire_module` and `client_context_module` params to the SSR handler generator. Emit FFI externals for `encode_<client_context_type>` and each page model type. Wrap `encode_flags(client_context)` and `encode_flags(data/model)` in the typed transform before encoding.

This is the same shape as what we had before but now runs alongside `encode_term` (which acts as safety net). The typed transform is the primary correctness mechanism; `encode_term` in `wire.encode` catches anything missed.

Also re-add `wire_module` to rally's `generate_dispatch` call (matching libero's restored parameter).

- [ ] **Step 1: Add SSR handler params and typed transforms**
- [ ] **Step 2: Update rally.gleam** to pass params
- [ ] **Step 3: Update tests**
- [ ] **Step 4: Regen + build v3** (`bin/regen && bin/build`)
- [ ] **Step 5: `bin/clean && bin/dev`** — smoke test `/admin/registration/discounts`
- [ ] **Step 6: Commit rally and v3**
