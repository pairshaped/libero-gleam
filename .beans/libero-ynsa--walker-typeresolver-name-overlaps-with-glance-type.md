---
# libero-ynsa
title: Walker `TypeResolver` name overlaps with `glance_type_resolver.TypeResolver` (walker.gleam:49-61; glance_type_resolver.gleam:17-20)
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

Imported from code-review.md finding 29 (Minor).

the two types have related but different jobs. `glance_type_resolver.TypeResolver` converts `glance.Type` to `FieldType` and catches ambiguous imports; walker uses its resolver to collect graph edges and track original names for aliased imports. Rename the walker type to something like `TypeRefResolver` so the split responsibility is clear without doing a larger refactor.
