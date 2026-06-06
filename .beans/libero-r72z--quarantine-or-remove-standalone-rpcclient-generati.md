---
# libero-r72z
title: Quarantine or remove standalone RPC/client-generation surfaces
status: draft
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T05:47:06Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

After the API boundary is decided, move older standalone app-facing surfaces behind explicit compatibility naming or delete them. Candidate surfaces include `server_` prefix scanner assumptions, `ServerContext` hardcoding, client file mirroring via `js_output_dir`, RemoteData/client-state helpers, and modules/docs that imply Libero owns transport or client application state.

Acceptance:
- Compatibility surfaces are clearly named and documented as compatibility, or removed with tests updated.
- Core Rally-style APIs do not require consumers to think in `server_*` handler names or generated client packages.
- Internal modules stay internal where possible.
- `gleam format && gleam test` passes.
