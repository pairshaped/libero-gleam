---
# libero-yxe4
title: Harden JSON transport limits
status: completed
type: task
priority: high
tags:
    - json
    - security
created_at: 2026-05-12T18:39:09Z
updated_at: 2026-06-03T22:17:54Z
parent: libero-lph9
---

Track the real JSON transport hardening work separately from the code review cleanup. Scope should include deciding whether JSON frames are accepted from untrusted clients, wiring input-size and structural limits into decode paths, adding tests for oversized and deeply nested payloads, and removing any public limits API until it is enforced.



Completed: JSON decode boundaries now enforce a 1 MiB input limit, depth limit, collection length limit, and string byte limit before returning dynamic values. This covers Gleam request/server-frame/SSR flag decode and the JS server-frame/SSR flag FFI paths. Added Erlang and JS tests for oversized and deeply nested payload rejection.
