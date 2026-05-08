---
# libero-c8hx
title: Run all JS codec tests from the JS test runner
status: todo
type: task
priority: normal
tags:
    - test
    - js
created_at: 2026-05-08T06:38:32Z
updated_at: 2026-05-08T06:38:32Z
---

test/js/typed_decode_pipeline_test.mjs and test/js/etf_constructor_decode_test.mjs pass when run directly but are omitted from test/run_js_tests.sh. Add them or replace the ad hoc list with test discovery so codec regressions are not missed.
