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
updated_at: 2026-05-08T16:21:55Z
---

The JS ETF decoder (rpc_ffi.mjs) enforces MAX_COLLECTION_LEN=16M and MAX_BINARY_BYTES=64M to prevent a malicious frame from triggering gigabyte allocations. The Erlang side has no equivalent: libero_ffi:decode_safe/1 calls erlang:binary_to_term(Bin, [safe]) directly, which will happily decode arbitrarily large lists/tuples or deeply nested structures up to whatever mist's frame limit allows.

This is the only currently-open class of pre-authentication DoS we can identify against the v3 admin server: a small frame containing a single large list-of-tuples header can balloon into an enormous decoded term.

Fix: walk the decoded term once after binary_to_term and reject if any list/tuple exceeds N elements or nesting exceeds D levels. Mirror the JS caps. OR explore OTP options like {max_term_size, _} if available in our OTP version.

Reference: https://security.erlef.org/secure_coding_and_deployment_hardening/serialisation.html — calls out resource exhaustion as a class the [safe] flag does not address.



---
**See also:** [`docs/wire-type-identity.md`](../docs/wire-type-identity.md). Independent of this bean, but lands as part of the same hardening arc. The spec subsumes `libero-ljv6` and `libero-3ccw`.
