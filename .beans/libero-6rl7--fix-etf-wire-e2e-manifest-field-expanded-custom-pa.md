---
# libero-6rl7
title: Fix ETF wire E2E manifest field-expanded custom params
status: todo
type: task
priority: low
tags:
    - etf
    - test
created_at: 2026-06-03T22:29:02Z
updated_at: 2026-06-03T22:29:02Z
---

The JS wire E2E harness still sends whole encoded custom records for some handler calls, but generated ETF ClientMsg variants are field-expanded for those handler params. After making ETF generation explicit with LIBERO_GEN_ETF=1, test/run_js_tests.sh reaches this older mismatch and fails in generated@rpc_wire decode_client_msg/1 for cases like server_echo_item_list_data. This is ETF-specific and should be fixed separately from the JSON default transport work.
