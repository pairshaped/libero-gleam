---
# libero-yxe4
title: Harden JSON transport limits
status: todo
type: task
priority: deferred
tags:
    - json
    - security
    - deferred
created_at: 2026-05-12T18:39:09Z
updated_at: 2026-05-13T00:42:01Z
---

Track the real JSON transport hardening work separately from the code review cleanup. Scope should include deciding whether JSON frames are accepted from untrusted clients, wiring input-size and structural limits into decode paths, adding tests for oversized and deeply nested payloads, and removing any public limits API until it is enforced.
