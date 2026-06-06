---
# libero-9316
title: Avoid blank Erlang wire sections
status: completed
type: bug
priority: normal
created_at: 2026-06-06T19:14:02Z
updated_at: 2026-06-06T19:18:56Z
---

Update Libero ETF Erlang codegen to omit empty optional sections so consumers that pass no endpoints or push dispatches do not get trailing blank lines in generated wire modules.

## Summary of Changes

- Joined only non-empty Erlang wire module sections so empty endpoints and push dispatches do not produce trailing blank runs.
- Kept generated ETF codec modules minimal: ensure, encode, and decode only. Protocol-level helpers remain in `libero/etf/wire`.
- Added regression coverage for empty optional sections and updated ETF codec module expectations.

## Validation

- gleam format
- git diff --check
- gleam test: 514 passed
