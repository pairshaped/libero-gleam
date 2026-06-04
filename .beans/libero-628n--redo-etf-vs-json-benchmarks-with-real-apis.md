---
# libero-628n
title: Redo ETF vs JSON benchmarks with real APIs
status: completed
type: task
priority: normal
tags:
    - benchmark
    - json
    - transport
created_at: 2026-05-12T12:42:10Z
updated_at: 2026-06-03T23:34:59Z
parent: libero-lph9
---

The old benchmark docs and scripts were removed because they hand-modeled Libero wire behavior instead of exercising the current generated/public APIs. Rebuild the benchmark suite against real Libero ETF and JSON helpers and generated request/response/decoder code.

Requirements:

- Measure encode and decode separately. ETF and JSON have different cost profiles, and combining them hides the useful signal.
- Include warmup before timed runs on both BEAM and JS/V8. Record warmup policy in the docs.
- Measure server-side BEAM encode and decode for ETF and JSON.
- Measure client-side JS decode for ETF and JSON, including parse-only where useful and parse plus generated decoder/rebuild as the real end-to-end cost.
- Record wire size for each payload.
- Use current API names and generated code paths, not standalone copies of encoders, decoders, or fake constructors.
- Cover multiple payload shapes and sizes based on the old benchmark intent: small admin-style response with option fields and dicts, repeated records, nested event/game/team data, and a large shot-heavy payload.
- Scale iteration counts by payload size so large payloads finish in a reasonable time while small payloads still have stable measurements.
- Publish results only after the benchmark harness is reproducible from the repo and clearly states environment details.



Completed: added `benchmarks/` with a reproducible temp-project harness that generates JSON through the default CLI path, generates ETF helper modules through public Libero generator APIs, measures BEAM server encode/decode, JS JSON parse-only, JS full JSON decode, JS ETF decode, and writes timestamped CSV/Markdown reports under `benchmarks/reports/`.

Published report: `benchmarks/reports/20260603T232304Z/report.md`.

Validation: `bash benchmarks/run.sh`, `gleam format --check src test benchmarks/fixture_src/src benchmarks/runner_src/src`, `gleam test --target erlang`, `beans check`, and `git diff --check` passed.



Updated: added a `type_matrix` payload covering shared JSON/ETF support for primitives, BitArray, List, Option, Result, tuple fields, zero-field variants, unlabelled constructors, nested custom types, and Dict keys for String/Int/Bool. Reports now render results as a Markdown table with a `vs ETF` multiplier column using ETF as the 1.00x baseline. Latest report: `benchmarks/reports/20260603T233326Z/report.md`.
