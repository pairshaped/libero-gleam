---
# libero-ir5g
title: Add protocol-facade tests for request/result/push/flags
status: draft
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T05:47:06Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Add or tighten tests proving consumers can use Libero through protocol-level facades instead of raw frame matching or raw decoder calls. Cover ETF first and JSON where supported. The point is to make the Rally boundary executable: consumers should call named operations for request encode/decode, response/result frames, push frames, and SSR flags.

Acceptance:
- Tests fail if a consumer must inspect raw tag bytes, manually slice request IDs, or call raw typed decoders for normal request/result/push/flags flows.
- ETF and JSON surface differences are explicit and documented in tests.
- Rally Scoreboard-style usage is represented by a fixture or generated-code snapshot.
- `gleam format && gleam test` passes.
