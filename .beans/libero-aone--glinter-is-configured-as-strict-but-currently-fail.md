---
# libero-aone
title: glinter is configured as strict but currently fails (gleam.toml:51-54)
status: todo
type: task
priority: high
tags:
    - code-review
    - important
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-05-13T00:39:01Z
---

Imported from code-review.md finding 16 (Important).

`warnings_as_errors = true` and `include = ["src/"]` signal that lint is meant to be part of the quality bar, and older project plans list `gleam run -m glinter` as a verification step. Today it reports 98 errors. Either fix the lint debt, tune noisy rules, or remove the strict config from the advertised bar. The current middle ground is noise: the repo says one thing and contributors learn to ignore it.
