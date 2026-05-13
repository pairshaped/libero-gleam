---
# libero-xruz
title: Request-side Float hints may be missing for primitive/container params (etf/wire_ffi.mjs:704, 1147-1168)
status: todo
type: task
priority: critical
tags:
    - code-review
    - critical
created_at: 2026-05-13T00:39:00Z
updated_at: 2026-05-13T00:39:00Z
---

Imported from code-review.md finding 1 (Critical).

JS has no runtime Int/Float distinction: `2 === 2.0` and `Number.isInteger(2.0)` is true. Libero already compensates for this when type metadata exists: generated user-type classes get `__fieldTypes`, and the ETF encoder forces `NEW_FLOAT_EXT` when it sees a `"float"` hint. The likely gap is request-side endpoint params that are primitive `Float` or containers of `Float`, because `encode_call` calls `encoder.encodeTerm(msg)` with no endpoint field hint. I reproduced a hand-built `server_echo_float(2.0)` request decoding on BEAM as `{<<"rpc">>, 123, {server_echo_float, 2}}`. Add a targeted generated-client regression test before fixing; the right fix is request-side field hints or typed request encoders, not more generic float guessing.
