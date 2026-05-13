---
# libero-r63b
title: Coordinate decode_call/encode_call removal with Rally
status: todo
type: task
priority: normal
created_at: 2026-05-13T01:22:17Z
updated_at: 2026-05-13T01:22:17Z
---

Aliases restored because Rally still depends on them. Must update Rally wire.gleam, generator.gleam, and ws_handler.gleam to use decode_request/encode_request before removing the Libero aliases.
