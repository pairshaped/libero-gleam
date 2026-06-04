---
# libero-2gni
title: Clean up generated JSON dispatch warnings
status: todo
type: task
priority: normal
tags:
    - json
    - codegen
created_at: 2026-06-03T23:25:24Z
updated_at: 2026-06-03T23:25:24Z
---

Generated `src/generated/libero/dispatch.gleam` can emit unused import and unused variable warnings, especially for JSON dispatch paths where handler calls are not compiled or fields are only pattern-matched for dispatch. Clean up the generated source so normal generation and benchmark fixture builds are quiet.

Acceptance criteria:
- Generated JSON dispatch does not emit unused import warnings for modules it does not need.
- Generated dispatch does not bind unused ClientMsg fields in branches where the values are not used.
- Existing dispatch behavior remains unchanged.
- Add or update generation tests that assert the warning-prone shapes are emitted cleanly.
