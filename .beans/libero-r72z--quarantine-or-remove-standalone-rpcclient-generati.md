---
# libero-r72z
title: Remove standalone transport and app-generation surfaces
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T20:00:00Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Removed the old standalone app-generation path. Libero now supports the shape
Rally uses: framework-provided seeds plus Libero-generated codec and contract
artifacts.

Removed:

- handler discovery facade
- generated dispatch code
- generated request-message module code
- CLI/config/mirroring helpers
- dispatch panic/trace/format support modules
- compatibility FFI module
- old request fixture and dispatch snapshots

Kept:

- ETF wire runtime
- JSON wire runtime
- ETF Erlang transformer generator
- JavaScript typed decoder generator
- JSON codec generator
- atom pre-registration
- wire identity collision checks
- exhaustive JS and Erlang codec tests
