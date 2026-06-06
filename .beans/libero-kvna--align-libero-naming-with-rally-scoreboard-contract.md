---
# libero-kvna
title: Align Libero naming with Rally Scoreboard contract language
status: draft
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T05:47:06Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Rename or wrap public-facing generated artifacts and docs that still expose old RPC/client wording where the concept is now request/result/push/flags contract generation. This may include contract JSON field names, generated module names, docs, comments, and helper function names.

Acceptance:
- Public docs and examples use request/result/push/flags or wire-contract terminology unless referring to explicit compatibility APIs.
- Generated filenames/module names are either aligned or documented as compatibility/stable historical names.
- Rally can keep consuming Libero without inheriting old vocabulary into generated Rally APIs.
- `gleam format && gleam test` passes.
