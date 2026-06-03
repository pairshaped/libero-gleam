---
# libero-3nts
title: Generated JSON encoders may panic on invalid numeric values (json/codegen.gleam:217-242)
status: todo
type: task
priority: normal
tags:
    - json
    - code-review
    - minor
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-06-03T18:55:26Z
parent: libero-lph9
---

Imported from code-review.md finding 24 (Minor).

out-of-range Int and non-finite Float panic on encode, while decode returns `JsonError`. This is acceptable if generated encoders only receive trusted, well-typed application values. Document that assumption; move broader untrusted JSON encode/decode hardening to bean `libero-yxe4`.
