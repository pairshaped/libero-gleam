---
# libero-w2up
title: Share module alias collision logic across generators
status: completed
type: task
priority: normal
tags:
    - code-review
    - readability
created_at: 2026-05-13T20:01:07Z
updated_at: 2026-06-03T23:05:12Z
---

src/libero/json/codegen.gleam build_module_alias_map and src/libero/codegen.gleam build_alias_resolver use the same last-segment collision strategy with different return shapes. Move the shared map construction into src/libero/codegen.gleam and let callers wrap it as needed.



Completed: moved the shared module alias collision map into `libero/codegen.build_module_alias_map`, updated the endpoint alias resolver to wrap it, and updated JSON codegen to use the same helper. Added direct tests for unique and colliding module aliases.

Validation: `gleam format --check src test` and `gleam test --target erlang test/libero/codegen_test.gleam test/libero/json_codegen_test.gleam test/libero/endpoint_dispatch_test.gleam` passed. The targeted Gleam test invocation ran the full Erlang suite: 499 passed.
