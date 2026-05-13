---
# libero-hd0u
title: Gleam stdlib Dict detection by duck-typing (wire_ffi.mjs:750-757)
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

Imported from code-review.md finding 25 (Minor).

checking `"root" in value && "size" in value` could match non-Dict objects. Acknowledged in comments but fragile.
