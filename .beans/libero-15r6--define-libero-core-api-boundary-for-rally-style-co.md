---
# libero-15r6
title: Define Libero core API boundary for Rally-style consumers
status: done
type: task
priority: high
created_at: 2026-06-06T05:46:36Z
updated_at: 2026-06-06T20:00:00Z
parent: libero-lrc4
blocked_by:
    - libero-t9n0
---

Libero's public boundary is now the Rally-style library API:

- `libero.walk`
- `libero.generate_atoms`
- `libero.generate_wire_erl`
- `libero.generate_decoders_ffi`
- `libero.generate_decoders_gleam`
- `libero.generate_etf_codec_module`
- `libero.generate_json_contract`
- `libero.generate_json_contract_hash`

Frameworks supply seeds and own request/result/push/app glue. Libero owns type
walking, wire identity, ETF and JSON codec generation, atom registration, wire
transformers, codec runtime helpers, and contract artifacts.

The compatibility generator path was removed. There is no public Libero code
path for a non-Rally consumer shape.
