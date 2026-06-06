---
# libero-zdpp
title: Rewrite Libero docs around the singular wire-contract role
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T20:00:00Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

README, `llms.txt`, docs pages, ADRs, fixtures, comments, and snapshots now
describe Libero as a seed-driven typed wire-contract library.

The docs point consumers at the Rally shape:

- framework code selects seeds and writes app protocol modules
- Libero walks types and generates codec/contract artifacts
- ETF and JSON runtimes remain covered and documented
- Rally Scoreboard is the canonical example

The docs do not present removed standalone app-generation behavior as a current
or compatibility path.
