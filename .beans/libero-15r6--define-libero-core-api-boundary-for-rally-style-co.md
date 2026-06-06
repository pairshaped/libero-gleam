---
# libero-15r6
title: Define Libero core API boundary for Rally-style consumers
status: draft
type: task
priority: high
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T05:47:06Z
parent: libero-lrc4
blocked_by:
    - libero-t9n0
---

Based on the audit, define the public API boundary Libero should expose to framework consumers. The likely core is type graph walking, wire identity, typed codec generation, generated request/result/push/flags protocol facades, dispatch helpers, and contract artifacts.

Acceptance:
- Document which modules/functions are core API, which are internal, and which are compatibility.
- Decide whether `libero/wire` remains a compatibility alias for `libero/etf/wire` or moves behind explicit legacy naming.
- Decide whether standalone handler scanning by `server_` prefix remains core or becomes a compatibility feature.
- Decide naming for RPC/request terminology so Rally does not inherit old `server_*` vocabulary.
- Add follow-up beans for any migration too large for this slice.
