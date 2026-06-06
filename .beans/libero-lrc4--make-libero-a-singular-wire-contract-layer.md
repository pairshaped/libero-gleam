---
# libero-lrc4
title: Make Libero a singular wire-contract layer
status: todo
type: epic
priority: high
created_at: 2026-06-06T05:46:19Z
updated_at: 2026-06-06T05:46:19Z
---

Libero should have one clear purpose in the Rally-era architecture: derive typed wire contracts, codecs, protocol facades, dispatch helpers, and contract artifacts for consumers such as Rally. The current repo still mixes that purpose with older standalone RPC/client-generation language and APIs.

Goal: decide and implement a singular public story for Libero, with any old standalone RPC surface either deliberately supported behind a compatibility boundary or removed.

Acceptance:
- README, llms.txt, docs, and public modules describe one coherent role for Libero.
- Rally Scoreboard is the canonical framework-consumer example.
- Standalone `server_` scanning, generated client mirroring, RemoteData/client-state helpers, JSON/ETF facades, and compatibility wrappers are each classified as core, compatibility, or removed.
- Tests cover the boundary Rally depends on: type walking, generated codecs, request/result/push framing, and protocol-agnostic consumer calls.
- Gleam format/test/docs validation passes.
