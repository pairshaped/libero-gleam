---
# libero-or5z
title: Standardize protocol helper names
status: todo
type: task
priority: normal
created_at: 2026-05-12T12:08:09Z
updated_at: 2026-05-12T12:08:09Z
---

ETF and JSON currently use slightly different helper names for the same protocol concepts. The visible mismatch is inbound request decoding: ETF exposes `libero/wire.decode_call` while JSON exposes `libero/json/wire.decode_request`. Standardize the public generated/helper surface so protocol selection does not leak naming differences into consumers or docs. Keep compatibility aliases if needed, update docs/tests, and prefer names based on protocol concepts such as request, response, push, and flags.
