---
# libero-zaj4
title: Qualified context types are not part of the recognized handler signature (scanner.gleam:533-539)
status: todo
type: task
priority: deferred
tags:
    - code-review
    - minor
    - deferred
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-05-13T00:42:01Z
---

Imported from code-review.md finding 23 (Minor).

Libero intentionally scans for the conventional handler shape using an unqualified `ServerContext`. A handler using `ctx.ServerContext` will be skipped. That is acceptable if this signature contract is deliberate, but the docs should say it plainly or the scanner should offer a debug/report mode for skipped `server_` functions.
