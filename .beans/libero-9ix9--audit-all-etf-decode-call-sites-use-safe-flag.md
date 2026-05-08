---
# libero-9ix9
title: Audit all ETF decode call sites use [safe] flag
status: todo
type: task
priority: high
tags:
    - security
    - etf
    - audit
created_at: 2026-05-08T15:14:28Z
updated_at: 2026-05-08T16:21:56Z
---

libero_ffi.erl:57 and :60 use erlang:binary_to_term(Bin, [safe]). Need to confirm this is the only decode pathway in libero, rally, and consumer projects (v3) — no shortcut bare binary_to_term/1 calls anywhere on the request path.

[safe] is critical: it blocks atom creation (DoS via atom-table exhaustion) AND blocks function deserialisation (RCE via FUN_EXT/EXPORT_EXT). A single bare binary_to_term/1 call on user input defeats both protections.

Audit scope:
- libero/src/**/*.erl, *.gleam, *.mjs (any wire-decode helper)
- rally/src/**/*.erl, *.gleam, *.mjs
- v3 server/src/**/*.gleam (anywhere that decodes wire bytes)

Add a lint rule or test that fails the build if a bare binary_to_term/1 appears anywhere on the request path.

Reference: https://security.erlef.org/secure_coding_and_deployment_hardening/serialisation.html



---
**See also:** [`docs/wire-type-identity.md`](../docs/wire-type-identity.md). Independent of this bean, but lands as part of the same hardening arc. The spec subsumes `libero-ljv6` and `libero-3ccw`.
