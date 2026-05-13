---
# libero-phoq
title: Duplicate contract generation logic (json/contract.gleam:19-95)
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

Imported from code-review.md finding 22 (Minor).

`generate_hash` is currently unused, so this is future-proofing rather than a present bug. Still, `generate` and `generate_hash` each sort endpoints/types and build the same canonical JSON object. If `generate_hash` is used later, drift could make embedded hashes disagree with `rpc_contract.json`. Use a private `canonical_contract_json(...)` helper for both.
