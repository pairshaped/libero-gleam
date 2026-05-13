---
# libero-nqgj
title: Resolver-construction asserts remain in helper paths (scanner.gleam:427-430; walker.gleam:279)
status: todo
type: task
priority: high
tags:
    - code-review
    - important
created_at: 2026-05-13T00:39:00Z
updated_at: 2026-05-13T00:39:00Z
---

Imported from code-review.md finding 4 (Important).

Top-level handler scanning already maps ambiguous imports to `TypeResolutionFailed`, so this is not a broad production-assert problem. The remaining risky spots are narrower: discovered/shared type modules in `walker.gleam` still assert on `resolver_from_imports`, and scanner's cross-module whole-message helper asserts before `try_resolve_msg_type` can fall back. Keep the public ergonomics the same by wrapping only resolver construction: return `TypeResolutionFailed` from the walker path, and make `module_type_resolver` return `Result` so whole-message flattening can gracefully fall back. The `type_to_field_type(... PreserveUnsupported)` asserts are lower risk today because unsupported function/hole types are preserved as `TypeVar`.
