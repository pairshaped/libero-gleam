---
# libero-aa23
title: Stale three-peer package assumptions remain in JS decoder generation (codegen_decoders.gleam:180-188; libero.gleam:214-228)
status: todo
type: task
priority: high
tags:
    - code-review
    - important
created_at: 2026-05-13T00:39:01Z
updated_at: 2026-05-13T00:39:01Z
---

Imported from code-review.md finding 19 (Important).

`js_package_for_module` maps `shared/*` modules to a separate `shared` JS package, and `walk()` still scans `../shared/src`. Rally now owns client generation: it writes `src/generated/codec_ffi.mjs` inside the generated client package and calls Libero's lower-level decoder generator with `relpath_prefix: "../../"` and `package: "client"`. That means Libero's public `"../../../"` wrapper is mostly stale facade surface for Rally, but the lower-level `shared/* -> shared` remap can still emit wrong imports if any discovered server module starts with `shared/`. Remove or replace this legacy package mapping so decoder imports reflect Rally's current generated-client layout.
