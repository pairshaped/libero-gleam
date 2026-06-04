---
# libero-cfgz
title: Optimize strict ETF non-executable validation
status: todo
type: task
priority: deferred
tags:
    - etf
    - performance
    - security
created_at: 2026-06-04T03:32:43Z
updated_at: 2026-06-04T03:32:43Z
---

Investigate how to make Libero's strict ETF non-executable term validation cheap enough to enable selectively or by default.

Context:

- `libero_etf_ffi:validate_data_term/1` rejects BEAM runtime terms such as pids, refs, ports, and functions after `binary_to_term`.
- On OTP 28, `binary_to_term(Bin, [safe])` can still decode at least some of those terms, so `[safe]` is not a full data-only policy.
- Calling `validate_data_term/1` on the default BEAM request decode hot path caused about a 5-6x slowdown in `server_request_decode` benchmarks because it walks the whole payload before generated typed decoding walks it again.
- The call is currently commented out on the default hot path with docs explaining the tradeoff. `[safe, used]` remains enabled to block atom creation and trailing bytes.

Acceptance criteria:

- Benchmark at least these options against `benchmarks/run.sh`: no validation baseline, current full prewalk validator, and one optimized approach.
- Consider folding non-executable checks into generated typed decode paths so legitimate payloads are not double-walked.
- Consider an opt-in strict mode for applications that accept hand-written ETF from untrusted non-Libero clients.
- Check whether OTP 29 changes `binary_to_term([safe])` behavior or performance for pids, refs, ports, funs, and export terms.
- Check whether Gleam 1.17 changes generated Erlang or JavaScript output in a way that affects this work.
- Document the chosen policy in README and `pages/protocol/etf-wire-protocol.md`.

Useful benchmark data:

- Full prewalk validator made BEAM request decode roughly 5-6.5x slower in report `benchmarks/reports/20260604T032032Z/`.
- Removing the hot-path validator call restored request decode to baseline in report `benchmarks/reports/20260604T033015Z/`.
