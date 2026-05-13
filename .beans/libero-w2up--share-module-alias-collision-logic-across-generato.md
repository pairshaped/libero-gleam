---
# libero-w2up
title: Share module alias collision logic across generators
status: todo
type: task
priority: normal
tags:
    - code-review
    - readability
created_at: 2026-05-13T20:01:07Z
updated_at: 2026-05-13T20:01:07Z
---

src/libero/json/codegen.gleam build_module_alias_map and src/libero/codegen.gleam build_alias_resolver use the same last-segment collision strategy with different return shapes. Move the shared map construction into src/libero/codegen.gleam and let callers wrap it as needed.
