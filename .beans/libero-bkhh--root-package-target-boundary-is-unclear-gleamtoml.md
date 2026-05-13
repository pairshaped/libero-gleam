---
# libero-bkhh
title: Root package target boundary is unclear (gleam.toml; trace.gleam:42; format.gleam:68-83)
status: todo
type: task
priority: high
tags:
    - code-review
    - important
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-05-13T00:39:01Z
---

Imported from code-review.md finding 15 (Important).

`gleam.toml` has no target and comments describe a cross-target package, but `gleam check --target javascript` fails because Erlang-only modules and tests live in the root package. `format_gleam` is generator-only and `trace.try_call` is server-dispatch-only, so the issue is not that they need JS implementations. The problem is that the repo tells two stories: cross-target package versus Erlang-target generator/server runtime. Make the boundary explicit by setting an Erlang target, splitting JS-safe modules, or target-gating/excluding Erlang-only tests and modules.
