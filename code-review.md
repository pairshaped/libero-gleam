# Code Review: libero 6.0.0

**467 Gleam tests pass. JS wire suite, JSON codec typecheck, iso routing fixture, and Erlang check pass. glinter currently fails with 98 configured errors.**

## Bean IDs

Findings were moved to Beans:

- 1 `libero-xruz`
- 2 `libero-d8ki`
- 3 `libero-ndcq`
- 4 `libero-nqgj`
- 5 `libero-fbep`
- 6 `libero-immu`
- 7 `libero-bucy`
- 8 `libero-nt5q`
- 9 `libero-q7ba`
- 10 `libero-rje0`
- 11 `libero-8l4f`
- 12 `libero-jxjj`
- 13 `libero-zi4f`
- 14 `libero-n955`
- 15 `libero-bkhh`
- 16 `libero-aone`
- 17 `libero-4zvg`
- 18 `libero-3h31`
- 19 `libero-aa23`
- 20 `libero-45lp`
- 21 `libero-rfrt`
- 22 `libero-phoq`
- 23 `libero-zaj4`
- 24 `libero-3nts`
- 25 `libero-hd0u`
- 26 `libero-2yuz`
- 27 `libero-bact`
- 28 `libero-ylsq`
- 29 `libero-ynsa`
- 30 `libero-lcem`

## Critical

**1. Request-side Float hints may be missing for primitive/container params (etf/wire_ffi.mjs:704, 1147-1168)**
JS has no runtime Int/Float distinction: `2 === 2.0` and `Number.isInteger(2.0)` is true. Libero already compensates for this when type metadata exists: generated user-type classes get `__fieldTypes`, and the ETF encoder forces `NEW_FLOAT_EXT` when it sees a `"float"` hint. The likely gap is request-side endpoint params that are primitive `Float` or containers of `Float`, because `encode_call` calls `encoder.encodeTerm(msg)` with no endpoint field hint. I reproduced a hand-built `server_echo_float(2.0)` request decoding on BEAM as `{<<"rpc">>, 123, {server_echo_float, 2}}`. Add a targeted generated-client regression test before fixing; the right fix is request-side field hints or typed request encoders, not more generic float guessing.

**2. Documented JS frame helpers lose byte-aligned BitArray payloads (etf/wire_ffi.mjs:376-380, 1192-1239)**
BEAM frame helpers preserve `BitArray`, and the JS raw typed-decoder path also preserves byte-aligned `BitArray` as a raw binary shape that `decode_bit_array` can decode. The public JS frame helpers are different: `decode_response_frame`, `decode_push_frame`, and `decode_server_frame` route payloads through non-raw `decode_safe`, where ETF `BINARY_EXT` is decoded as UTF-8 string. I reproduced `BitArray([255])` coming back from `decode_response_frame` as a replacement-character string instead of a BitArray-shaped value. The contract docs tell consumers to call `decode_server_frame`, while the E2E tests manually slice the frame and call `decode_value_raw` before generated typed decoders. So the issue is a docs/API/test mismatch: the tested path works, the documented JS helper path does not.

**3. `try_resolve_msg_type` silently drops extra payload params (scanner.gleam:356-377)**
The pattern `[param, ..]` matches one-or-more params. If the first payload param is a whole-message custom type and flattening succeeds, scanner replaces the endpoint params with that message type's fields and sets `msg_type: Some(...)`; any remaining payload params are ignored. The dispatch generator then calls the handler with only `wire.coerce(typed_msg)` and context/extra generated params, so `server_foo(msg: SetTheme, extra: Int, ctx: Ctx)` would generate a dispatch call without `extra`. Change this match to `[param]` so whole-message flattening only applies when there is exactly one payload param; multi-param handlers should use the existing fallback path.

## Important

**4. Resolver-construction asserts remain in helper paths (scanner.gleam:427-430; walker.gleam:279)**
Top-level handler scanning already maps ambiguous imports to `TypeResolutionFailed`, so this is not a broad production-assert problem. The remaining risky spots are narrower: discovered/shared type modules in `walker.gleam` still assert on `resolver_from_imports`, and scanner's cross-module whole-message helper asserts before `try_resolve_msg_type` can fall back. Keep the public ergonomics the same by wrapping only resolver construction: return `TypeResolutionFailed` from the walker path, and make `module_type_resolver` return `Result` so whole-message flattening can gracefully fall back. The `type_to_field_type(... PreserveUnsupported)` asserts are lower risk today because unsupported function/hole types are preserved as `TypeVar`.

**5. Untrimmed env path returned (libero.gleam:346-358)**
`client_output_dir_from_env` trims the path to check for blank, but returns the original untrimmed `path`. If `LIBERO_CLIENT_OUT_DIR` has leading/trailing whitespace, file writes target a bogus path. This is generator-only and opt-in, so it is not a runtime bug, but `write_client_files` currently swallows write errors, making the typo harder to notice. Return the trimmed value and add a test for `Some("  out  ") -> Some("out")`.

**6. `JsonLimits` defined but never enforced (json/limits.gleam)**
`max_input_bytes`, `max_nesting_depth`, `max_string_length`, `max_array_length`, `max_object_entries`, and `max_base64_decoded_bytes` exist as a type and defaults, but no decode function accepts or checks them. The comment says generated facades use these, but the only references are the type, `default_limits()`, and a sanity test. Remove this public limits API until it is wired; track real JSON transport hardening separately in bean `libero-yxe4`.

**7. Request IDs are 32-bit on the wire but not range-validated (etf/wire.gleam:204)**
The 32-bit request ID frame field is reasonable; generated clients should never need more than 4.29 billion correlation IDs, and uniqueness only needs to hold for in-flight requests. The defensive gap is that the public encode helpers accept an unconstrained Gleam `Int`. If caller state ever produces a negative or oversized ID, the frame header silently wraps/truncates instead of failing loudly. Define the valid range as `0..4_294_967_295` and validate before encoding.

**8. `read_package_name` crashes on missing/malformed gleam.toml (libero.gleam:428-433)**
Three consecutive `let assert` in the user-facing `main()` path. Crash message is an opaque match error instead of a boxed error like the rest of `main()`. Keep the `tom` dependency; hand-rolled TOML parsing would be a bad trade even for one field. The fix is to make `read_package_name` return `Result(String, String)` or a small local error type, then print a boxed error before `halt(1)`.

**9. `write_client_files` silently discards all errors (libero.gleam:416-426)**
When a user explicitly opts in via `LIBERO_CLIENT_OUT_DIR`, directory creation or write failures are silently swallowed. The comment calls these writes best-effort, but the env var is an explicit request to write client files. Prefer returning `Result(Nil, WriteError)` and handling failures like the main generated files. If these must remain non-fatal, print boxed warnings to stderr; silent failure is the bug.

**10. JSON contract write result discarded (libero.gleam:147)**
`let _ = write_file(out_dir <> "/rpc_contract.json", json_contract)` throws away the result. The contract is always generated, and the final success message claims the file was written regardless. Fold `rpc_contract.json` into `write_generated_files` or check the `write_file` result and halt with `print_write_error`; this should fail the command, not warn.

**11. JSON codec generation failure is non-fatal (libero.gleam:152-178)**
When `LIBERO_GEN_JSON_CODECS` is set and codegen fails, the error is printed but exit code is 0. The success path also discards the write result for `json_codecs.gleam`, so the final success message can list a file that was not written. Because this branch is explicit opt-in, generation or write failure should fail the command. Keep this separate from the contract write finding because the causes differ: codegen errors versus file write errors.

**12. `optional_int_field` skips safe-integer-range validation (json/wire.gleam:277-287)**
`required_int_field` validates the JS safe integer range. `optional_int_field` does not, and it collapses malformed, missing, null, and out-of-range values into `None`. For error frames, missing/null `request_id` is valid; malformed or out-of-range should be `Error`. Change the helper to return `Result(Option(Int), List(JsonError))`, reuse the same safe-int check, and make `decode_error_frame_body` fail on bad `request_id`.

**13. JS JSON wire tests inline production FFI code (test/js/json_wire_roundtrip_test.mjs)**
`test/js/json_wire_roundtrip_test.mjs` copies helpers and frame encode/decode functions from `src/libero/json/wire_ffi.mjs` instead of importing the production module. That means the test can pass while the code users run drifts. Import the real `wire_ffi.mjs` like `json_wire_ffi_imports_test.mjs` does, or keep only tiny local assertions/helpers in the test file.

**14. Test-only dynamic Erlang compiler ships in production FFI (libero_ffi.erl:10-14, 89-96)**
`compile_module_from_source/1` parses, compiles, and loads arbitrary Erlang source from a binary. The only caller is `test/libero/codegen_wire_erl_test.gleam`, and `libero_test_ffi.erl` already exists. This is not an immediate remote-code-execution issue, but it is unnecessary production package surface. Move it to `libero_test_ffi.erl` and point the test external there.

**15. Root package target boundary is unclear (gleam.toml; trace.gleam:42; format.gleam:68-83)**
`gleam.toml` has no target and comments describe a cross-target package, but `gleam check --target javascript` fails because Erlang-only modules and tests live in the root package. `format_gleam` is generator-only and `trace.try_call` is server-dispatch-only, so the issue is not that they need JS implementations. The problem is that the repo tells two stories: cross-target package versus Erlang-target generator/server runtime. Make the boundary explicit by setting an Erlang target, splitting JS-safe modules, or target-gating/excluding Erlang-only tests and modules.

**16. glinter is configured as strict but currently fails (gleam.toml:51-54)**
`warnings_as_errors = true` and `include = ["src/"]` signal that lint is meant to be part of the quality bar, and older project plans list `gleam run -m glinter` as a verification step. Today it reports 98 errors. Either fix the lint debt, tune noisy rules, or remove the strict config from the advertised bar. The current middle ground is noise: the repo says one thing and contributors learn to ignore it.

**17. Missing test coverage for 5 of 10 GenError variants**
`gen_error_test.gleam` says "`print_error` covers every GenError variant", but it only covers 6 of 11 variants. `TypeIdentityHashCollision`, `AmbiguousFallbackMapping`, `DictKeyMustBePrimitive`, `WireTypeContainsTypeVar`, and `TypeResolutionFailed` have no `print_error` smoke tests. Some are tested at producer level, but not through the CLI formatting path. Add smoke tests for the missing variants; the boxed error surface is a project strength, so every variant should stay covered.

**18. No test for scanner with unparseable files**
The all-or-nothing parse error path (scanner.gleam:142-159) is untested. This protects an important guarantee: if one source file is broken, Libero should fail the scan instead of generating a partial dispatch table from the files that happened to parse. Add a scanner integration test with one valid handler file and one syntactically invalid file, assert `Error([ParseFailed(...)])`, and verify no endpoint list is returned.

**19. Stale three-peer package assumptions remain in JS decoder generation (codegen_decoders.gleam:180-188; libero.gleam:214-228)**
`js_package_for_module` maps `shared/*` modules to a separate `shared` JS package, and `walk()` still scans `../shared/src`. Rally now owns client generation: it writes `src/generated/codec_ffi.mjs` inside the generated client package and calls Libero's lower-level decoder generator with `relpath_prefix: "../../"` and `package: "client"`. That means Libero's public `"../../../"` wrapper is mostly stale facade surface for Rally, but the lower-level `shared/* -> shared` remap can still emit wrong imports if any discovered server module starts with `shared/`. Remove or replace this legacy package mapping so decoder imports reflect Rally's current generated-client layout.

## Minor

**20. No JS ETF decoder depth limit (wire_ffi.mjs)**: JS ETF decoding has collection-length and binary-size caps, but no recursion depth cap. Because the JS decoder normally receives frames only from the developer's own Gleam server, this is defense-in-depth rather than a current trust-boundary issue. Do not add a per-term depth counter unless browser benchmarks show negligible overhead or the decoder starts accepting ETF from untrusted senders.

**21. JS JSON frame decoder accepts malformed frame fields (json/wire_ffi.mjs:78-122)**: the JS FFI path only checks top-level object shape and protocol version before constructing frames. Because Libero does not plan to support non-Gleam producers, this is cross-target consistency and hardening rather than a current trust-boundary issue. Fold into JSON transport hardening bean `libero-yxe4` unless the protocol contract changes.

**22. Duplicate contract generation logic (json/contract.gleam:19-95)**: `generate_hash` is currently unused, so this is future-proofing rather than a present bug. Still, `generate` and `generate_hash` each sort endpoints/types and build the same canonical JSON object. If `generate_hash` is used later, drift could make embedded hashes disagree with `rpc_contract.json`. Use a private `canonical_contract_json(...)` helper for both.

**23. Qualified context types are not part of the recognized handler signature (scanner.gleam:533-539)**: Libero intentionally scans for the conventional handler shape using an unqualified `ServerContext`. A handler using `ctx.ServerContext` will be skipped. That is acceptable if this signature contract is deliberate, but the docs should say it plainly or the scanner should offer a debug/report mode for skipped `server_` functions.

**24. Generated JSON encoders may panic on invalid numeric values (json/codegen.gleam:217-242)**: out-of-range Int and non-finite Float panic on encode, while decode returns `JsonError`. This is acceptable if generated encoders only receive trusted, well-typed application values. Document that assumption; move broader untrusted JSON encode/decode hardening to bean `libero-yxe4`.

**25. Gleam stdlib Dict detection by duck-typing (wire_ffi.mjs:750-757)**: checking `"root" in value && "size" in value` could match non-Dict objects. Acknowledged in comments but fragile.

**26. `protocol.from_string` is case-sensitive with no indication (protocol.gleam:13-19)**: `"ETF"` or `"Etf"` returns Error. If parsed from user config, case-insensitive matching would be friendlier.

**27. `to_option` inconsistent label style (remote_data.gleam:125)**: positional param while every other public helper in the module uses labeled `data data:`. Since Libero is currently the only consumer, change this now before the API shape settles.

**28. `TupleOf` codegen missing passthrough optimization (etf/codegen_erl.gleam:521-541)**: generates a case expression even when all elements are passthrough primitives, unlike `ListOf`/`OptionOf`/`ResultOf`/`DictOf`. Mixed tuples like `#(Int, UserType)` still need destructure/rebuild, and that path is tested. For all-passthrough tuples, compute `body_terms`, compare them to the fresh bind vars, and return `expr` when they all match. Add a primitive tuple passthrough test beside `list_of_int_passes_through_test`.

**29. Walker `TypeResolver` name overlaps with `glance_type_resolver.TypeResolver` (walker.gleam:49-61; glance_type_resolver.gleam:17-20)**: the two types have related but different jobs. `glance_type_resolver.TypeResolver` converts `glance.Type` to `FieldType` and catches ambiguous imports; walker uses its resolver to collect graph edges and track original names for aliased imports. Rename the walker type to something like `TypeRefResolver` so the split responsibility is clear without doing a larger refactor.

**30. Coordinate `decode_call`/`encode_call` rename across Libero and Rally (etf/wire.gleam:165-193; rally generator/runtime)**: Libero now has `decode_request`/`encode_request`, but Rally still emits and wraps the older `decode_call`/`encode_call` names in generated protocol facades, WS handlers, and runtime tests. Since these current versions are not externally consumed, migrate Rally to the request terminology and remove the backward-compat aliases from Libero now instead of carrying extra API surface forward.

## Strengths

- **Error presentation is excellent.** `gen_error.error_box` gives every error a uniform boxed format with title, path, body, and hint. One of the best CLI error experiences in a Gleam library.

- **Pre-emission validation is thorough.** Wire safety, hash uniqueness, and endpoint field safety are all checked before any code is emitted. The emitter stays clean "happy path only" code.

- **Wire identity is well-designed.** SHA-256 truncated to 40 bits with codegen-time collision checks. Canonical signature format is deterministic and includes module path to prevent cross-module collisions.

- **ETF security is solid on BEAM.** `binary_to_term(Bin, [safe])`, atom pre-registration via `rpc_atoms`, 512-depth limit. Defense-in-depth on JS with collection limits, atom codepoint validation, trailing byte rejection.

- **Test suite is multi-layered.** Unit tests, snapshot tests via birdie, compilation tests that `gleam build` the generated dispatch, behavioral tests that compile Erlang from source and verify encode/decode roundtrips. 467 tests, zero failures.

- **`RemoteData` layering is clean.** `RemoteData` -> `RpcData` -> `RpcOutcome` separates transport from domain errors. `fold` is the right view-code primitive.

- **Public API facade is consistent.** `libero.gleam` re-exports internal types and wraps internal functions so consumers never reach into sub-modules.

- **Passthrough optimization in Erlang codegen.** When container inner types don't need transformation, codegen emits just the variable name instead of a comprehension. The `inner == inner_var` string comparison detects this cleanly.

- **Recursive type handling is correct.** BFS with visited set prevents infinite loops on mutually recursive types. Tested.

- **Ambiguous import detection** catches duplicate conflicting type imports at resolver-construction time rather than silently picking one.
