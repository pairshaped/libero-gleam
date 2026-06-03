---
# libero-utaw
title: Make JSON builtin codec templates readable
status: completed
type: task
priority: low
tags:
    - readability
    - json
    - code-review
created_at: 2026-05-13T20:01:20Z
updated_at: 2026-06-03T22:32:41Z
parent: libero-lph9
---

src/libero/json/codegen.gleam emits Option and Result helper codecs as single-line string literals containing whole multi-line functions. Split these into readable concatenated templates like the rest of the emitters so contributors can inspect generated code shape without horizontal scrolling.



Completed: split the generated Option/Result encoder and decoder helper templates into readable concatenated strings without changing the emitted helper code shape.

Validation: `gleam format --check src test`, `gleam test --target erlang`, and `bash test/run_json_codec_typecheck_test.sh` passed.
