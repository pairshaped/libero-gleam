---
# libero-ylsq
title: '`TupleOf` codegen missing passthrough optimization (etf/codegen_erl.gleam:521-541)'
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

Imported from code-review.md finding 28 (Minor).

generates a case expression even when all elements are passthrough primitives, unlike `ListOf`/`OptionOf`/`ResultOf`/`DictOf`. Mixed tuples like `#(Int, UserType)` still need destructure/rebuild, and that path is tested. For all-passthrough tuples, compute `body_terms`, compare them to the fresh bind vars, and return `expr` when they all match. Add a primitive tuple passthrough test beside `list_of_int_passes_through_test`.
