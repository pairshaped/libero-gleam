---
# libero-utaw
title: Make JSON builtin codec templates readable
status: todo
type: task
priority: low
tags:
    - code-review
    - readability
created_at: 2026-05-13T20:01:20Z
updated_at: 2026-05-13T20:01:20Z
---

src/libero/json/codegen.gleam emits Option and Result helper codecs as single-line string literals containing whole multi-line functions. Split these into readable concatenated templates like the rest of the emitters so contributors can inspect generated code shape without horizontal scrolling.
