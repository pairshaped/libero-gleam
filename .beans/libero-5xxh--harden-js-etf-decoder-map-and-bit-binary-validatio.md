---
# libero-5xxh
title: Harden JS ETF decoder map and bit-binary validation
status: todo
type: task
priority: normal
tags:
    - js
    - security
created_at: 2026-05-08T06:38:32Z
updated_at: 2026-05-08T06:38:32Z
---

rpc_ffi.mjs applies MAX_COLLECTION_LEN to lists and large tuples but not MAP_EXT arity, and BIT_BINARY_EXT accepts impossible bits-in-last-byte values. Add production tests against src/libero/rpc_ffi.mjs and reject invalid or oversized frames before allocation/looping.
