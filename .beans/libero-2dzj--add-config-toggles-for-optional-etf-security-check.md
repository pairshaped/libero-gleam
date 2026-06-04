---
# libero-2dzj
title: Add config toggles for optional ETF security checks
status: completed
type: task
priority: normal
tags:
    - etf
    - security
    - config
created_at: 2026-06-04T04:08:20Z
updated_at: 2026-06-04T04:30:22Z
---

Two ETF security checks are currently present in code but disabled on the hot path because their value depends on the deployment trust boundary and their cost is measurable. Add explicit configuration toggles so applications can opt into them without editing Libero internals.

Security checks to expose:

1. Strict Erlang ETF data-term validation

Current code:

- `src/libero_etf_ffi.erl`
  - `decode_safe/1` decodes with `binary_to_term(Bin, [safe, used])` through `decode_binary_term/1`.
  - The call to `validate_data_term(Term)` is commented out in `decode_safe/1`.
  - `validate_data_term/1` still exists and rejects executable/runtime BEAM terms like pids, refs, ports, and functions.
- `src/libero_etf_wire_ffi.erl`
  - `decode_request/1` also decodes through `decode_binary_term/1`.
  - The call to `libero_etf_ffi:validate_data_term(Term)` is commented out before request-shape validation.
- Docs that mention this policy:
  - `README.md`
  - `pages/protocol/etf-wire-protocol.md`
  - `src/libero/etf/wire.gleam`

Why disabled today:

- It double-walks decoded terms.
- Benchmarks around `20260604T032032Z` vs `20260604T033015Z` showed roughly a 5-6x BEAM request decode slowdown when called on the hot path.
- Proper generated Libero clients do not emit pids/refs/ports/functions.

Toggle shape to design:

- Prefer an app/runtime config option rather than a compile-time edit.
- Needs to affect both `libero_etf_ffi:decode_safe/1` and `libero_etf_wire_ffi:decode_request/1` if enabled.
- Naming should make the cost clear, for example `strict_etf_data_terms` or similar.
- Decide whether the default remains disabled.

2. JavaScript ETF recursive depth cap

Current code:

- `src/libero/etf/wire_ffi.mjs`
  - `MAX_TERM_DEPTH = 512` exists.
  - `TRUSTED_SERVER_TERM_DEPTH_LIMIT` is currently `undefined`.
  - A commented line shows how to enable it: `// const TRUSTED_SERVER_TERM_DEPTH_LIMIT = MAX_TERM_DEPTH;`
  - `ETFDecoder` accepts `maxTermDepth` and checks recursive tuple/list/map container depth only when set.
  - Public decode paths pass `TRUSTED_SERVER_TERM_DEPTH_LIMIT`:
    - `decode_value`
    - `decode_value_raw`
    - `decode_safe`
    - `decode_safe_raw`
    - `decodeTypedWire`
- `test/js/etf_codec_test.mjs`
  - Mirrors the inline decoder.
  - Tests that default decode leaves depth uncapped.
  - Tests that the optional cap accepts just below limit and rejects tuple/list/map nesting at the limit.

Why disabled today:

- The generated browser client normally decodes ETF from the same trusted app server that served the JS bundle.
- If that server is compromised, client-side decode caps are not a meaningful defense because the attacker can serve different JS.
- The measured JS ETF decode overhead was small but real when enabled, around 1-2% on most cases and about 5% on the largest payload in one benchmark comparison.

Toggle shape to design:

- Prefer generated/runtime client config rather than changing the constant by hand.
- Needs to preserve the current default of uncapped generated client decode unless we explicitly decide otherwise.
- Should allow setting the cap to `512` or another positive integer. Consider whether `true` maps to `MAX_TERM_DEPTH` and `false`/`undefined` disables it.

Acceptance criteria:

- Applications can enable strict Erlang ETF data-term validation without editing Erlang source.
- Applications can enable JS ETF depth limiting without editing `wire_ffi.mjs`.
- Defaults preserve current behavior unless the design explicitly chooses a breaking safety default.
- Tests cover enabled and disabled behavior for both features.
- Docs explain the trust boundary, performance cost, and when to enable each toggle.
- Benchmarks compare default vs enabled for both checks so the cost is visible.
