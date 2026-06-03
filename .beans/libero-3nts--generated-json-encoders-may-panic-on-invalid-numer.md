---
# libero-3nts
title: Generated JSON encoders may panic on invalid numeric values (json/codegen.gleam:217-242)
status: completed
type: task
priority: normal
tags:
    - json
    - code-review
    - minor
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-06-03T22:30:54Z
parent: libero-lph9
---

Imported from code-review.md finding 24 (Minor).

out-of-range Int and non-finite Float panic on encode, while decode returns `JsonError`. This is acceptable if generated encoders only receive trusted, well-typed application values. Document that assumption; move broader untrusted JSON encode/decode hardening to bean `libero-yxe4`.



Completed: the generated JSON encoder behavior was already guarded and tested for JavaScript-safe `Int` and finite `Float` values. Documented the intended trust boundary in README and the JSON wire protocol doc: decoders treat wire input as untrusted and return `JsonError`, while encoders assume trusted typed application values and panic if FFI/unsafe construction produces numeric values that cannot be represented safely in JSON.

Validation: `beans check` and `git diff --check` passed.
