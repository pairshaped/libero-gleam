---
# libero-kxt4
title: Move ETF helpers under libero/etf
status: todo
type: task
priority: normal
created_at: 2026-05-12T12:09:10Z
updated_at: 2026-05-12T12:09:10Z
---

Protocol helper modules should use parallel paths. JSON helpers live under `libero/json/`, while ETF helpers currently live mostly in `libero/wire`. Move or mirror the ETF helper surface under `libero/etf/` so docs and generated code can refer to `libero/etf/wire` alongside `libero/json/wire`. Keep compatibility aliases where needed, update generated imports, tests, and docs, and coordinate with the protocol helper naming cleanup.
