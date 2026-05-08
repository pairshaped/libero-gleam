---
# libero-quoj
title: Add hostile-input ETF test fixtures
status: todo
type: task
priority: normal
tags:
    - security
    - etf
    - testing
created_at: 2026-05-08T15:14:45Z
updated_at: 2026-05-08T16:21:59Z
---

Test the ETF decode pipeline with adversarial inputs. Each should fail cleanly with a typed error — never crash the VM or hang.

Cases to cover:
- Hand-crafted binary containing FUN_EXT (117), NEW_FUN_EXT (112), EXPORT_EXT (113) → must be rejected by [safe]
- Hand-crafted binary containing PID_EXT (103), REF_EXT (101), NEWER_REFERENCE_EXT (90), PORT_EXT (102) → should be rejected by future non-executable validator
- Atom that does not exist in the pre-registration list → must be rejected by [safe]
- List/tuple with arity claiming MAX_COLLECTION_LEN+1 → must be rejected by resource caps
- Binary claiming MAX_BINARY_BYTES+1 → must be rejected by resource caps
- Deeply-nested structure (e.g., 10000-deep nested tuples) → must be rejected by nesting cap
- Truncated binary (declares an arity but data ends early) → typed error, not VM crash
- Trailing bytes after a valid term → already covered by ERROR_TRAILING_BYTES on JS side; mirror on Erlang side

Run on both encoder ends:
- Erlang decoder receives JS-encoded hostile bytes (test client → server path)
- JS decoder receives Erlang-encoded hostile bytes (test server → client path)

These fixtures form the regression suite for issues v3-related to qualified atoms AND for security work in this bean group.



---
**See also:** [`docs/wire-type-identity.md`](../docs/wire-type-identity.md). Fixtures here will need a small update to use the new hashed wire atoms once that spec is implemented (Phase 9 of the plan). Run alongside or after the spec lands.
