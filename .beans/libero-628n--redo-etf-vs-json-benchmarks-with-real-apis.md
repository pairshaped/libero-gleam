---
# libero-628n
title: Redo ETF vs JSON benchmarks with real APIs
status: todo
type: task
priority: deferred
tags:
    - benchmark
    - deferred
created_at: 2026-05-12T12:42:10Z
updated_at: 2026-05-13T00:42:01Z
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
