---
# libero-zdpp
title: Rewrite Libero docs around the singular wire-contract role
status: draft
type: task
priority: normal
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T05:47:06Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Update README, llms.txt, Hex docs pages, and design/reference docs so Libero has one public story: a typed wire-contract and protocol-codegen layer used by frameworks such as Rally. The docs should point to Rally Scoreboard as the canonical framework integration.

Acceptance:
- Docs no longer present generated client mirroring, RemoteData/client state, or standalone `server_` scanning as the primary Libero identity unless explicitly marked compatibility.
- Docs clearly explain ETF/JSON protocol facades, request/result/push/flags ownership, and what consumers should not implement themselves.
- ADR/reference docs describe current/intended design, not migration history.
- `gleam docs build` passes if available.
