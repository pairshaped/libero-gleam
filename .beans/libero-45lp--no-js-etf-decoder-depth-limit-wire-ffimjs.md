---
# libero-45lp
title: No JS ETF decoder depth limit (wire_ffi.mjs)
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

Imported from code-review.md finding 20 (Minor).

JS ETF decoding has collection-length and binary-size caps, but no recursion depth cap. Because the JS decoder normally receives frames only from the developer's own Gleam server, this is defense-in-depth rather than a current trust-boundary issue. Do not add a per-term depth counter unless browser benchmarks show negligible overhead or the decoder starts accepting ETF from untrusted senders.
