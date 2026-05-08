---
# libero-zgrp
title: Add non-executable term validator to decode_safe
status: todo
type: feature
priority: normal
tags:
    - security
    - etf
created_at: 2026-05-08T15:14:35Z
updated_at: 2026-05-08T16:21:58Z
---

Defense in depth on top of [safe]. After binary_to_term(Bin, [safe]) succeeds, walk the term and assert it contains only ints, floats, atoms, binaries, lists, tuples, and maps. Reject pids, refs, ports, funs explicitly even though [safe] should block them.

Why bother if [safe] already blocks these? Two reasons:
1. Explicit failure messages: a typed error like {error, {non_executable_term, fun_ref_at_path}} is much easier to triage than a binary_to_term crash.
2. Future-proofing: if a future Erlang/OTP release subtly changes [safe] semantics or we accidentally hit a path that doesn't use [safe], this validator is a backstop.

Inspired by Plug.Crypto.non_executable_binary_to_term/1,2 in the Elixir ecosystem.

Add as libero_ffi:decode_safe_strict/1 (or replace decode_safe — TBD based on whether any caller actually wants to receive non-data terms, which seems unlikely).

Reference: https://security.erlef.org/secure_coding_and_deployment_hardening/serialisation.html



---
**See also:** [`docs/wire-type-identity.md`](../docs/wire-type-identity.md). Independent of this bean, but lands as part of the same hardening arc. The spec subsumes `libero-ljv6` and `libero-3ccw`.
