---
# libero-rj32
title: Add JS target generated JSON codec acceptance tests
status: completed
type: task
priority: high
tags:
    - json
    - testing
created_at: 2026-06-03T21:32:29Z
updated_at: 2026-06-03T21:34:05Z
parent: libero-lph9
---

Add JavaScript-target coverage for generated typed JSON codecs.

Problem:

- Current generated JSON codec round-trip coverage runs generated Gleam code on the Erlang target.
- Existing JS tests cover JSON wire envelopes and ETF-era typed decode paths, but not generated JSON encoders and decoders across the supported typed-value matrix.

Acceptance criteria:

- A JS-target fixture generates JSON codecs for every supported shape: primitives, BitArray, List, Dict with String/Int/Bool keys, tuple, Option, Result, labelled constructors, unlabelled constructors, zero-field variants, and nested custom types.
- The JS-target test runs generated encoders and decoders under Node and proves round-trip parity for representative values.
- Negative coverage includes malformed BitArray data and strict constructor field validation on JS.
- The test is wired into the existing JS test runner or documented as a first-class script if the existing JS fixture setup blocks integration.



Completion notes:

- `test/run_json_codec_typecheck_test.sh` now typechecks generated codecs on both Erlang and JavaScript, then runs the generated codec smoke matrix on both targets.
- `test/run_json_codec_acceptance_test.sh` now runs strict generated decoder acceptance tests on both Erlang and JavaScript.
- `test/run_js_tests.sh` runs these generated JSON codec checks before the existing wire E2E JS suite.
- The generated JSON codec sections pass under `test/run_js_tests.sh`; the runner still fails afterward in the pre-existing wire E2E setup because shared peer modules such as `shared/types.Tag` are not reachable during generation.
