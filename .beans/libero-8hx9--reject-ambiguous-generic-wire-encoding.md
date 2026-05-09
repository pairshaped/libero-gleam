---
# libero-8hx9
title: Reject ambiguous generic wire encoding
status: todo
type: bug
priority: high
tags:
    - wire
    - codegen
created_at: 2026-05-09T13:51:17Z
updated_at: 2026-05-09T13:51:17Z
---

Validation:
- `src/libero/codegen_wire_erl.gleam` generates `encode_term/1` clauses by matching `{bare_constructor_atom, tuple_size}`.
- `src/libero/wire_identity.gleam` checks hash uniqueness and field safety, but has no bare constructor plus arity collision check.
- `test/libero/codegen_wire_erl_test.gleam` currently has `same_named_same_arity_types_from_different_modules_succeed_test`, which proves the old per-endpoint helpers can handle this case, but it does not prove generic `encode_term/1` can.
- Since `libero_ffi:encode/1` now always calls `Mod:encode_term(Term)`, arbitrary `wire.encode` on the second same-name same-arity type can silently choose the first generated clause.

Work:
- Decide whether generic `encode_term/1` should reject same bare constructor atom plus tuple size across modules, or use a different disambiguation strategy.
- If rejecting, add a GenError variant and tests for collision and non-collision.
- Update or remove the existing same-name same-arity success test so it no longer blesses unsafe generic encoding.

Acceptance:
- Codegen can no longer emit ambiguous generic `encode_term/1` clauses.
- Tests cover same name same arity from different modules, same name different arity, and duplicate identical constructors.
