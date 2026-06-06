---
# libero-t9n0
title: Audit Libero public surfaces and split-personality vocabulary
status: todo
type: task
priority: high
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T05:46:36Z
parent: libero-lrc4
---

Read Libero code, tests, README, llms.txt, docs, and generated snapshots for competing stories: standalone `server_` RPC scanner/app generator, client file mirroring, RemoteData/client-state helpers, ETF/JSON protocol facades, raw wire helpers, Rally framework-consumer API, and compatibility wrappers.

Acceptance:
- Produce a concise inventory in the bean body grouping each surface as core, compatibility candidate, removal candidate, or unresolved.
- Identify current Rally usage from the Rally Scoreboard path and Rally generator imports.
- Identify docs that teach obsolete or mixed mental models.
- Recommend the child bean ordering before code edits begin.

Validation: read-only, but run `rg` audit commands and include them in the summary.
