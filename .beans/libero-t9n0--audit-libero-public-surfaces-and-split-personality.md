---
# libero-t9n0
title: Audit Libero public surfaces and split-personality vocabulary
status: done
type: task
priority: high
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T20:00:00Z
parent: libero-lrc4
---

Audit result: latest Rally is the only active consumer, so Libero should not
carry alternative consumer paths.

The supported surface is the Rally-style seed-driven pipeline:

- type seeds
- source walking
- type graph walking
- ETF atom registration
- ETF wire transformer generation
- JavaScript typed decoder generation
- JSON typed codec and contract generation
- shared wire runtime helpers

Docs and tests were updated so the repository teaches that shape directly.
