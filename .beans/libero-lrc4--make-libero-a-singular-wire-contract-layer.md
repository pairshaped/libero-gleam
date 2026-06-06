---
# libero-lrc4
title: Make Libero a singular wire-contract layer
status: done
type: epic
priority: high
created_at: 2026-06-06T05:46:19Z
updated_at: 2026-06-06T20:00:00Z
---

Libero is now a singular typed wire-contract layer for Rally-era consumers.

Done:

- Added a Rally-style codegen test that uses only seeded type walking and codec
  generation.
- Removed the standalone generator surface and its tests.
- Removed compatibility modules that existed only for old consumer shapes.
- Kept ETF codec coverage, JSON codec coverage, JavaScript codec tests, Erlang
  codec tests, atom safety tests, and contract artifact tests.
- Updated README, `llms.txt`, Hex docs pages, and ADRs around the current
  library boundary.

Rally Scoreboard remains the canonical consumer to validate this boundary.
