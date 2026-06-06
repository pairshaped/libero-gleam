---
# libero-kvna
title: Align Libero naming with Rally Scoreboard contract language
status: done
type: task
priority: normal
created_at: 2026-06-06T05:46:55Z
updated_at: 2026-06-06T16:52:13Z
parent: libero-lrc4
blocked_by:
    - libero-15r6
---

Rename or wrap public-facing generated artifacts and docs that still expose old transport/client wording where the concept is now request/result/push/flags contract generation. This may include contract JSON field names, generated module names, docs, comments, and helper function names.

Acceptance:
- Public docs and examples use request/result/push/flags or wire-contract terminology unless referring to explicit compatibility APIs.
- Generated filenames/module names are either aligned or documented as compatibility/stable historical names.
- Rally can keep consuming Libero without inheriting old vocabulary into generated Rally APIs.
- `gleam format && gleam test` passes.

## Result

Added `libero.generate_request_msg_module` as the public API for generated request-message source. The generated type now uses `RequestMsg`.

Updated default JSON and ETF generation to call the request-named API internally. Added tests proving the preferred API generates the request module and the old API remains an exact alias.

Introduced preferred mirrored-output naming:

- `mirrored_output_dir` in `gleam.toml`
- `LIBERO_MIRRORED_OUTPUT_DIR`
- `libero.mirrored_output_dir_from_env`
- `libero.resolve_mirrored_output_env`

Removed `js_output_dir`, `LIBERO_JS_OUTPUT_DIR`, `js_output_dir_from_env`, and `resolve_js_output_dir`.

Updated README, `llms.txt`, and wire comments so new docs use request/result/push/flags and wire-contract language. Generated names now use `RequestMsg`, `decoders`, `contract.json`, `generated@libero_wire`, `generated@libero_atoms`, the `"libero"` wire tag, and `TransportError`.

Validation:

- `gleam format`
- `gleam test --target erlang`
- `test/run_js_tests.sh`

## Removal Update

After confirming latest Rally is the only active consumer, removed the legacy aliases instead of keeping them:

- Removed the old client-message generation alias.
- Removed `js_output_dir`, `LIBERO_JS_OUTPUT_DIR`, `js_output_dir_from_env`, `resolve_js_output_dir`, and the old env fallback.
- Kept `generate_request_msg_module` as the only request-message generator.
- Kept `mirrored_output_dir` and `LIBERO_MIRRORED_OUTPUT_DIR` as the only mirrored-output names.
- Updated Rally to call `generate_request_msg_module`.

The generated request type is still named `RequestMsg` because it is part of generated dispatch shape, not a standalone client-state helper. Historical file names such as `decoders.gleam`, `contract.json`, and `TransportError` remain because renaming the wire artifact vocabulary would be a separate protocol/artifact migration.
