# JSON Wire Protocol Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add readable JSON as a second Libero-owned RPC protocol while keeping ETF as the default and keeping Rally/v3 behind protocol-level helpers.

**Architecture:** JSON is a parallel implementation under `libero/json/`. ETF code stays untouched. Shared types (`ServerFrame`) move to a protocol-neutral module (`libero/frame.gleam`). Generated typed encoders/decoders handle user custom types before values hit the raw protocol codec. Rally selects protocol config and routes text or binary frames, but does not parse JSON envelopes or reconstruct custom types itself.

**Tech Stack:** Gleam 1.16.0, `gleam_json` >= 3.1.0, Erlang FFI, Libero codegen, Rally generators, Gleeunit, Birdie snapshots.

---

## Source Documents

- `docs/superpowers/specs/2026-05-10-json-wire-protocol-design.md`
- `docs/json-wire-protocol-blueprint.md`
- `docs/contract-boundary-spec.md`
- `docs/wire-type-identity.md`

## Golden Rule: Source Identity

Do not weaken Libero's identity model. JSON must identify custom types using the same source-identity basis as ETF:

```text
module path + type name + constructor name + field types
```

Every task that touches JSON encoding or decoding must preserve this rule:
- No global lookup keyed by bare constructor name
- No dispatch by constructor name + arity
- No shape-guessing fallback
- No consumer responsibility to make names unique

## Worktree Setup

- [ ] **Step 1: Create paired worktrees**

```bash
mkdir -p /Users/daverapin/projects/opensource/json-wire-worktrees
git -C /Users/daverapin/projects/opensource/libero worktree add /Users/daverapin/projects/opensource/json-wire-worktrees/libero -b codex/json-wire-protocol
git -C /Users/daverapin/projects/opensource/rally worktree add /Users/daverapin/projects/opensource/json-wire-worktrees/rally -b codex/json-wire-protocol
```

- [ ] **Step 2: Verify Rally points at the Libero worktree**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/rally
grep 'libero = { path = "../libero" }' gleam.toml
realpath ../libero
```

Expected:
```
libero = { path = "../libero" }
/Users/daverapin/projects/opensource/json-wire-worktrees/libero
```

- [ ] **Step 3: Verify clean baseline**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam test
cd /Users/daverapin/projects/opensource/json-wire-worktrees/rally
gleam test
```

Expected: both test suites pass.

- [ ] **Step 4: Add gleam_json to Libero dependencies**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam add gleam_json@">= 3.1.0 and < 4.0.0"
```

Commit after verifying `gleam.toml` and `manifest.toml` are updated and `gleam test` still passes.

---

## File Structure

### Libero (new files)

- `src/libero/protocol.gleam` — Protocol config type (`Etf` | `Json`)
- `src/libero/frame.gleam` — Protocol-neutral `ServerFrame` type, moved from `wire.gleam`
- `src/libero/json/error.gleam` — `JsonError` type with path+message
- `src/libero/json/limits.gleam` — `JsonLimits` record
- `src/libero/json/contract.gleam` — Deterministic contract artifact generator
- `src/libero/json/codegen.gleam` — Typed JSON encoder/decoder source generation
- `src/libero/json/wire.gleam` — JSON frame helpers (encode_request, decode_server_frame, etc.)

### Libero (modified files)

- `src/libero.gleam` — Re-export `Protocol`, wire in contract/codegen generation to `main()`
- `src/libero/wire.gleam` — Move `ServerFrame` out to `frame.gleam`; import it back
- `src/libero/walker.gleam` — Add `field_labels` to `DiscoveredVariant`

### Libero (test files)

- `test/libero/protocol_test.gleam`
- `test/libero/frame_test.gleam`
- `test/libero/walker_field_label_test.gleam`
- `test/libero/json_error_test.gleam`
- `test/libero/json_limits_test.gleam`
- `test/libero/json_contract_test.gleam`
- `test/libero/json_codegen_test.gleam`
- `test/libero/json_wire_test.gleam`

### Rally (modified files)

- `src/rally/types.gleam` — Add `protocol` field to `ScanConfig`
- `src/rally.gleam` — Parse protocol from TOML config
- `src/rally/generator/client.gleam` — Emit protocol-aware transport
- `src/rally/generator/ws_handler.gleam` — Generated WS handler uses `ServerFrame` from `libero/frame`

---

### Task 1: Protocol Config

**Files:**
- Create: `src/libero/protocol.gleam`
- Modify: `src/libero.gleam`
- Test: `test/libero/protocol_test.gleam`

- [ ] **Step 1: Write the failing test**

Create `test/libero/protocol_test.gleam`:

```gleam
import gleeunit/should
import libero/protocol

pub fn protocol_to_string_test() {
  protocol.to_string(protocol.Etf) |> should.equal("etf")
  protocol.to_string(protocol.Json) |> should.equal("json")
}

pub fn protocol_from_string_test() {
  protocol.from_string("etf") |> should.equal(Ok(protocol.Etf))
  protocol.from_string("json") |> should.equal(Ok(protocol.Json))
  protocol.from_string("xml") |> should.equal(Error("unknown protocol: xml"))
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam test --target erlang
```

Expected: compile fails because `libero/protocol` does not exist.

- [ ] **Step 3: Create `src/libero/protocol.gleam`**

```gleam
pub type Protocol {
  Etf
  Json
}

pub fn to_string(protocol: Protocol) -> String {
  case protocol {
    Etf -> "etf"
    Json -> "json"
  }
}

pub fn from_string(value: String) -> Result(Protocol, String) {
  case value {
    "etf" -> Ok(Etf)
    "json" -> Ok(Json)
    other -> Error("unknown protocol: " <> other)
  }
}
```

- [ ] **Step 4: Re-export from `libero.gleam`**

Add the import near the other imports:

```gleam
import libero/protocol
```

Add the re-export near the other `pub type` / `pub fn` entries:

```gleam
/// The wire protocol: ETF (Erlang Term Format) or JSON.
pub type Protocol =
  protocol.Protocol
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/libero/protocol.gleam src/libero.gleam test/libero/protocol_test.gleam
git commit -m "Add JSON protocol config type"
```

---

### Task 2: Move ServerFrame to protocol-neutral module

Before extending `ServerFrame` with the `Error` variant (needed by JSON), move it from `libero/wire.gleam` to a new `libero/frame.gleam` so both ETF and JSON wire modules can import it without creating a dependency from ETF onto JSON error types.

**Files:**
- Create: `src/libero/frame.gleam`
- Modify: `src/libero/wire.gleam` (remove `ServerFrame`, import from `frame`)
- Test: `test/libero/frame_test.gleam` (optional — the existing wire tests cover this)

- [ ] **Step 1: Create `src/libero/frame.gleam`**

```gleam
//// Protocol-neutral frame type shared by ETF and JSON wire modules.
////
//// Moved here from `libero/wire.gleam` so both protocol implementations
//// can import it without creating a dependency from ETF onto JSON types.

/// A decoded server-to-client frame.
///
/// Consumers use this to handle incoming server messages without
/// knowing the frame wire shape (tag bytes for ETF, kind field for JSON).
///
/// The `value` type parameter is typically `Dynamic` at the boundary
/// and narrowed by the consumer with a typed decoder or `coerce`.
///
pub type ServerFrame(value) {
  Response(request_id: Int, value: value)
  Push(module: String, value: value)
  Error(request_id: Option(Int), errors: List(#(String, String)))
}
```

- [ ] **Step 2: Update `src/libero/wire.gleam` — remove `ServerFrame` type definition, add import**

Remove the `ServerFrame` type definition block (lines ~34-45) and the preceding comment block. Add the import near the top:

```gleam
import libero/frame.{type ServerFrame, Error, Push, Response}
```

- [ ] **Step 3: Update test that imports `ServerFrame` variants from `wire`**

In `test/libero/wire_test.gleam`, change the import from:
```gleam
import libero/wire
// ... wire.Response, wire.Push used in patterns
```
to also import from `frame` or use the re-exported names from `wire`.

Since `wire.gleam` now imports and re-exports the variants, the test patterns like `wire.Response(...)` and `wire.Push(...)` still work as long as `wire.gleam` re-exports or at least imports them. The simplest approach: `wire.gleam` imports the variants and the existing `wire.Response` / `wire.Push` references in tests keep working because they are in scope via the `libero/wire` module.

Actually, Gleam requires explicit re-export for qualified access. So `wire.Response` won't work unless `wire.gleam` has `pub type ServerFrame = frame.ServerFrame`. Let me handle this differently: keep a type alias in `wire.gleam`.

In `wire.gleam`, replace the removed type definition with:

```gleam
pub type ServerFrame =
  frame.ServerFrame
```

This is a type alias that re-exports the type under the `wire` namespace, keeping all existing callers working.

- [ ] **Step 4: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass. The `ServerFrame` type alias in `wire.gleam` keeps `wire.Response` etc. working.

- [ ] **Step 5: Commit**

```bash
git add src/libero/frame.gleam src/libero/wire.gleam test/libero/wire_test.gleam
git commit -m "Move ServerFrame to protocol-neutral frame module"
```

---

### Task 3: Preserve Constructor Field Labels

**Files:**
- Modify: `src/libero/walker.gleam`
- Modify: All test files that construct `DiscoveredVariant` directly
- Test: `test/libero/walker_field_label_test.gleam`

- [ ] **Step 1: Write the field label test**

Create `test/libero/walker_field_label_test.gleam`:

```gleam
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import libero/field_type
import libero/gen_error
import libero/walker

pub fn variant_field_labels_test() {
  // Build a minimal DiscoveredVariant by hand to test the field is present
  let v = walker.DiscoveredVariant(
    module_path: "shared/article",
    variant_name: "Article",
    atom_name: "shared_article__article",
    float_field_indices: [],
    field_labels: [Some("title"), Some("body")],
    fields: [field_type.StringField, field_type.StringField],
  )

  v.field_labels |> should.equal([Some("title"), Some("body")])

  let u = walker.DiscoveredVariant(
    module_path: "shared/pair",
    variant_name: "Pair",
    atom_name: "shared_pair__pair",
    float_field_indices: [],
    field_labels: [None, None],
    fields: [field_type.StringField, field_type.IntField],
  )

  u.field_labels |> should.equal([None, None])
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam test --target erlang
```

Expected: compile fails because `DiscoveredVariant` has no `field_labels` field.

- [ ] **Step 3: Add `field_labels` to `DiscoveredVariant`**

In `src/libero/walker.gleam`, add the field to the type (around line 26):

```gleam
pub type DiscoveredVariant {
  DiscoveredVariant(
    /// Gleam module path, e.g. "shared/discount".
    module_path: String,
    /// PascalCase constructor name, e.g. "AdminData".
    variant_name: String,
    /// snake_case atom name, e.g. "admin_data".
    atom_name: String,
    /// 0-based indices of fields whose Gleam type is Float.
    float_field_indices: List(Int),
    /// Labels for each field. `None` for unlabelled, `Some("label")` for labelled.
    /// Carried alongside `fields` for JSON codegen; ignored by ETF codegen.
    field_labels: List(option.Option(String)),
    /// Structured types of each field, in declaration order.
    fields: List(FieldType),
  )
}
```

Add the import for `option` if not already present (it already uses `option` types, so the import exists).

Add the helper function near `variant_field_type`:

```gleam
fn variant_field_label(field: glance.VariantField) -> option.Option(String) {
  case field {
    glance.LabelledVariantField(label:, ..) -> option.Some(label)
    glance.UnlabelledVariantField(..) -> option.None
  }
}
```

In `process_type_ast_custom`, where each `DiscoveredVariant` is constructed (around line 289-298), add:

```gleam
let field_labels = list.map(variant.fields, variant_field_label)
```

And pass `field_labels:` into the `DiscoveredVariant(...)` constructor.

- [ ] **Step 4: Update all existing tests that construct `DiscoveredVariant`**

Add `field_labels: [],` (or the correct labels) to every `DiscoveredVariant(` constructor call in these files:

- `test/libero/endpoint_dispatch_test.gleam` (3 instances)
- `test/libero/codegen_wire_erl_test.gleam` (1 instance)
- `test/libero/typed_decoder_codegen_test.gleam` (~14 instances)

Use grep to find all instances:
```bash
grep -rn "DiscoveredVariant(" test/
```

For each one, add `field_labels:` after `float_field_indices:` with an empty list `[]` (tests don't need real labels unless specifically testing label behavior).

- [ ] **Step 5: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/libero/walker.gleam test/libero
git commit -m "Preserve variant field labels"
```

---

### Task 4: JSON Error and Limits Primitives

**Files:**
- Create: `src/libero/json/error.gleam`
- Create: `src/libero/json/limits.gleam`
- Test: `test/libero/json_error_test.gleam`
- Test: `test/libero/json_limits_test.gleam`

- [ ] **Step 1: Create the `libero/json` directory**

```bash
mkdir -p /Users/daverapin/projects/opensource/json-wire-worktrees/libero/src/libero/json
```

- [ ] **Step 2: Create `src/libero/json/error.gleam`**

```gleam
import gleam/list
import gleam/string

pub type JsonError {
  JsonError(path: String, message: String)
}

pub fn at(path: String, message: String) -> JsonError {
  JsonError(path:, message:)
}

/// Convert a list of JSON errors to protocol-neutral path+message tuples
/// suitable for the shared `ServerFrame` Error variant.
pub fn to_frame_errors(errors: List(JsonError)) -> List(#(String, String)) {
  list.map(errors, fn(e) { #(e.path, e.message) })
}

/// Append a segment to all error paths in the list. Used to contextualize
/// errors from nested decode (e.g. prepend "fields.slug" to errors from
/// decoding a String field).
pub fn prefix(errors: List(JsonError), segment: String) -> List(JsonError) {
  list.map(errors, fn(e) {
    JsonError(
      path: case e.path {
        "" -> segment
        _ -> segment <> "." <> e.path
      },
      message: e.message,
    )
  })
}
```

- [ ] **Step 3: Create `test/libero/json_error_test.gleam`**

```gleam
import gleeunit/should
import libero/json/error.{type JsonError, JsonError}

pub fn json_error_at_test() {
  let e = error.at("fields.slug", "expected String, got Null")
  e.path |> should.equal("fields.slug")
  e.message |> should.equal("expected String, got Null")
}

pub fn json_error_to_frame_test() {
  let errors = [
    error.at("fields.slug", "expected String, got Null"),
    error.at("fields.title", "expected String, got Int"),
  ]
  let frame_errors = error.to_frame_errors(errors)
  frame_errors
  |> should.equal([
    #("fields.slug", "expected String, got Null"),
    #("fields.title", "expected String, got Int"),
  ])
}

pub fn json_error_prefix_test() {
  let errors = [
    error.at("slug", "expected String"),
    error.at("title", "expected String"),
  ]
  let prefixed = error.prefix(errors, "fields")
  prefixed
  |> should.equal([
    error.at("fields.slug", "expected String"),
    error.at("fields.title", "expected String"),
  ])
}
```

- [ ] **Step 4: Create `src/libero/json/limits.gleam`**

```gleam
pub type JsonLimits {
  JsonLimits(
    max_input_bytes: Int,
    max_nesting_depth: Int,
    max_string_length: Int,
    max_array_length: Int,
    max_object_entries: Int,
    max_base64_decoded_bytes: Int,
  )
}

/// Conservative defaults. Generated facades use these; callers can override
/// for specific decode paths.
pub fn default_limits() -> JsonLimits {
  JsonLimits(
    max_input_bytes: 1_048_576,    // 1 MB
    max_nesting_depth: 32,
    max_string_length: 65_536,     // 64 KB
    max_array_length: 10_000,
    max_object_entries: 1_000,
    max_base64_decoded_bytes: 1_048_576,
  )
}
```

- [ ] **Step 5: Create `test/libero/json_limits_test.gleam`**

```gleam
import gleeunit/should
import libero/json/limits

pub fn default_limits_are_sane_test() {
  let l = limits.default_limits()
  l.max_input_bytes |> should.be_positive()
  l.max_nesting_depth |> should.be_positive()
  l.max_string_length |> should.be_positive()
}
```

- [ ] **Step 6: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass.

- [ ] **Step 7: Commit**

```bash
git add src/libero/json/error.gleam src/libero/json/limits.gleam test/libero/json_error_test.gleam test/libero/json_limits_test.gleam
git commit -m "Add JSON error and limits types"
```

---

### Task 5: Contract Artifact Generator

**Files:**
- Create: `src/libero/json/contract.gleam`
- Modify: `src/libero.gleam`
- Test: `test/libero/json_contract_test.gleam`

- [ ] **Step 1: Write the contract artifact test**

Create `test/libero/json_contract_test.gleam`:

```gleam
import gleam/json
import gleam/list
import gleam/option.{Some}
import gleeunit/should
import libero/field_type
import libero/json/contract
import libero/scanner
import libero/walker

pub fn contract_artifact_is_deterministic_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/rpc",
      fn_name: "get_article",
      params: [#("slug", field_type.StringField)],
      return_ok: field_type.UserType("shared/article", "Article", []),
      return_err: field_type.StringField,
      mutates_context: False,
      msg_type: option.None,
    ),
  ]

  let discovered = [
    walker.DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title"), Some("body")],
          fields: [field_type.StringField, field_type.StringField],
        ),
      ],
    ),
  ]

  let one = contract.generate(endpoints:, discovered:)
  let two = contract.generate(endpoints:, discovered:)

  one |> should.equal(two)
  one |> should.contain("\"protocol_version\"")
  one |> should.contain("\"json-rpc-v1\"")
  one |> should.contain("\"shared/article\"")
}

pub fn contract_artifact_includes_endpoints_test() {
  let endpoints = [
    scanner.HandlerEndpoint(
      module_path: "server/rpc",
      fn_name: "get_article",
      params: [#("slug", field_type.StringField)],
      return_ok: field_type.UserType("shared/article", "Article", []),
      return_err: field_type.StringField,
      mutates_context: False,
      msg_type: option.None,
    ),
  ]

  let discovered: List(walker.DiscoveredType) = []

  let artifact = contract.generate(endpoints:, discovered:)
  let parsed = json.parse(artifact, json.Decoder(fn(x) { Ok(x) }))

  // Don't crash on parse — the artifact must be valid JSON
  let assert Ok(_) = parsed
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam test --target erlang
```

Expected: compile fails because `libero/json/contract` does not exist.

- [ ] **Step 3: Implement `src/libero/json/contract.gleam`**

```gleam
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import libero/field_type.{type FieldType}
import libero/scanner.{type HandlerEndpoint}
import libero/walker.{type DiscoveredType, type DiscoveredVariant}

pub fn generate(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
) -> String {
  let sorted_endpoints =
    endpoints
    |> list.sort(fn(a, b) { string.compare(a.fn_name, b.fn_name) })

  let sorted_types =
    discovered
    |> list.sort(fn(a, b) {
      string.compare(
        a.module_path <> "." <> a.type_name,
        b.module_path <> "." <> b.type_name,
      )
    })

  json.object([
    #("protocol_version", json.string("json-rpc-v1")),
    #("libero_version", json.string("6.0.0")),
    #("endpoints", json.array(sorted_endpoints, of: endpoint_json)),
    #("types", json.array(sorted_types, of: discovered_type_json)),
  ])
  |> json.to_string
}

fn endpoint_json(e: HandlerEndpoint) -> json.Json {
  json.object([
    #("module_path", json.string(e.module_path)),
    #("fn_name", json.string(e.fn_name)),
    #("params", json.array(e.params, of: fn(p) {
      json.object([
        #("label", json.string(p.0)),
        #("type", field_type_json(p.1)),
      ])
    })),
    #("return_ok", field_type_json(e.return_ok)),
    #("return_err", field_type_json(e.return_err)),
  ])
}

fn discovered_type_json(t: DiscoveredType) -> json.Json {
  let sorted_variants =
    t.variants
    |> list.sort(fn(a, b) { string.compare(a.variant_name, b.variant_name) })

  json.object([
    #("module_path", json.string(t.module_path)),
    #("type_name", json.string(t.type_name)),
    #("type_params", json.array(t.type_params, of: json.string)),
    #("variants", json.array(sorted_variants, of: variant_json)),
  ])
}

fn variant_json(v: DiscoveredVariant) -> json.Json {
  json.object([
    #("variant_name", json.string(v.variant_name)),
    #("field_labels", json.array(v.field_labels, of: field_label_json)),
    #("field_types", json.array(v.fields, of: field_type_json)),
  ])
}

fn field_type_json(ft: FieldType) -> json.Json {
  case ft {
    field_type.IntField -> json.string("Int")
    field_type.FloatField -> json.string("Float")
    field_type.StringField -> json.string("String")
    field_type.BoolField -> json.string("Bool")
    field_type.BitArrayField -> json.string("BitArray")
    field_type.NilField -> json.string("Nil")
    field_type.TypeVar(name:) -> json.object([
      #("kind", json.string("TypeVar")),
      #("name", json.string(name)),
    ])
    field_type.ListOf(element:) -> json.object([
      #("kind", json.string("List")),
      #("element", field_type_json(element)),
    ])
    field_type.OptionOf(inner:) -> json.object([
      #("kind", json.string("Option")),
      #("inner", field_type_json(inner)),
    ])
    field_type.ResultOf(ok:, err:) -> json.object([
      #("kind", json.string("Result")),
      #("ok", field_type_json(ok)),
      #("err", field_type_json(err)),
    ])
    field_type.DictOf(key:, value:) -> json.object([
      #("kind", json.string("Dict")),
      #("key", field_type_json(key)),
      #("value", field_type_json(value)),
    ])
    field_type.TupleOf(elements:) -> json.object([
      #("kind", json.string("Tuple")),
      #("elements", json.array(elements, of: field_type_json)),
    ])
    field_type.UserType(module_path:, type_name:, args:) -> json.object([
      #("kind", json.string("UserType")),
      #("module_path", json.string(module_path)),
      #("type_name", json.string(type_name)),
      #("args", json.array(args, of: field_type_json)),
    ])
  }
}

fn field_label_json(label: option.Option(String)) -> json.Json {
  case label {
    option.Some(s) -> json.string(s)
    option.None -> json.null()
  }
}
```

- [ ] **Step 4: Re-export from `libero.gleam`**

Add the import:

```gleam
import libero/json/contract
```

Add the public function:

```gleam
/// Generate a deterministic JSON contract artifact from discovered types
/// and handler endpoints. The artifact describes every type, variant, and
/// endpoint that crosses the wire so external tools and SDKs can generate
/// clients from it.
pub fn generate_json_contract(
  endpoints endpoints: List(HandlerEndpoint),
  discovered discovered: List(DiscoveredType),
) -> String {
  contract.generate(endpoints:, discovered:)
}
```

- [ ] **Step 5: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass.

- [ ] **Step 6: Commit**

```bash
git add src/libero/json/contract.gleam src/libero.gleam test/libero/json_contract_test.gleam
git commit -m "Add JSON contract artifact generator"
```

---

### Task 6: Typed JSON Encoder/Decoder Codegen

**Files:**
- Create: `src/libero/json/codegen.gleam`
- Test: `test/libero/json_codegen_test.gleam`

- [ ] **Step 1: Write codegen tests**

Create `test/libero/json_codegen_test.gleam`:

```gleam
import gleam/list
import gleam/option.{None, Some}
import gleeunit/should
import libero/field_type
import libero/json/codegen
import libero/walker

pub fn generated_encoder_emits_type_and_variant_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/article",
      type_name: "Article",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/article",
          variant_name: "Article",
          atom_name: "shared_article__article",
          float_field_indices: [],
          field_labels: [Some("title"), Some("body")],
          fields: [field_type.StringField, field_type.StringField],
        ),
      ],
    ),
  ]

  let source = codegen.generate(types, [], [])

  // Encoder function exists
  source |> should.contain("fn json_encode_shared_article__article")
  // Type string
  source |> should.contain("shared/article.Article")
  // Variant string
  source |> should.contain("\"Article\"")
  // Field labels
  source |> should.contain("\"title\"")
  source |> should.contain("\"body\"")
  // Decoder function exists
  source |> should.contain("fn json_decode_shared_article__article")
}

pub fn duplicate_variant_names_generate_distinct_codecs_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "page/a",
      type_name: "ToClient",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "page/a",
          variant_name: "Updated",
          atom_name: "page_a__updated",
          float_field_indices: [],
          field_labels: [Some("msg")],
          fields: [field_type.StringField],
        ),
      ],
    ),
    walker.DiscoveredType(
      module_path: "page/b",
      type_name: "ToClient",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "page/b",
          variant_name: "Updated",
          atom_name: "page_b__updated",
          float_field_indices: [],
          field_labels: [Some("msg")],
          fields: [field_type.StringField],
        ),
      ],
    ),
  ]

  let source = codegen.generate(types, [], [])

  // Both encode functions exist with distinct names
  source |> should.contain("json_encode_page_a__to_client")
  source |> should.contain("json_encode_page_b__to_client")
  // Both type strings appear
  source |> should.contain("page/a.ToClient")
  source |> should.contain("page/b.ToClient")
}

pub fn unlabelled_fields_encode_as_array_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/pair",
      type_name: "Pair",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/pair",
          variant_name: "Pair",
          atom_name: "shared_pair__pair",
          float_field_indices: [],
          field_labels: [None, None],
          fields: [field_type.StringField, field_type.IntField],
        ),
      ],
    ),
  ]

  let source = codegen.generate(types, [], [])

  // Unlabelled fields should use json.array not json.object
  source |> should.contain("json.array(")
}

pub fn mixed_labelled_unlabelled_is_rejected_for_json_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/mixed",
      type_name: "Mixed",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/mixed",
          variant_name: "Mixed",
          atom_name: "shared_mixed__mixed",
          float_field_indices: [],
          field_labels: [None, Some("limit")],
          fields: [field_type.StringField, field_type.IntField],
        ),
      ],
    ),
  ]

  let result = codegen.generate(types, [], [])

  // Should contain an error message about mixed fields
  case result {
    Ok(_) -> should.fail("expected error for mixed fields")
    Error(errors) -> {
      let messages = list.map(errors, fn(e) { e.message })
      let found =
        list.any(messages, fn(m) { string.contains(m, "mixed") })
      should.be_true(found)
    }
  }
}

pub fn zero_field_variant_encodes_empty_object_test() {
  let types = [
    walker.DiscoveredType(
      module_path: "shared/status",
      type_name: "Status",
      type_params: [],
      variants: [
        walker.DiscoveredVariant(
          module_path: "shared/status",
          variant_name: "Ready",
          atom_name: "shared_status__ready",
          float_field_indices: [],
          field_labels: [],
          fields: [],
        ),
      ],
    ),
  ]

  let source = codegen.generate(types, [], [])

  // Zero-field variants should use json.object with type and variant only
  source |> should.contain("\"fields\"")
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam test --target erlang
```

Expected: compile fails because `libero/json/codegen` does not exist.

- [ ] **Step 3: Implement `src/libero/json/codegen.gleam`**

The generate function signature:

```gleam
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import libero/field_type.{type FieldType}
import libero/json/error.{type JsonError, JsonError}
import libero/walker.{type DiscoveredType, type DiscoveredVariant}

/// Generate Gleam source for JSON typed encoders and decoders.
/// Returns `Ok(source)` on success, or `Error(List(JsonError))` if any
/// constructor has mixed labelled/unlabelled fields (rejected for JSON v1).
pub fn generate(
  discovered: List(DiscoveredType),
  endpoints: List(a),
  push_dispatches: List(b),
) -> Result(String, List(JsonError)) {
  // Check for mixed fields first
  use _ <- result.try(
    check_no_mixed_fields(discovered)
  )

  let header = "// Generated by libero. DO NOT EDIT.
////
//// Typed JSON encoders and decoders for all discovered types.

import gleam/dynamic
import gleam/json
import libero/json/error.{type JsonError, JsonError}
"

  let encoders = list.map(discovered, emit_type_encoder)
  let decoders = list.map(discovered, emit_type_decoder)

  Ok(header <> string.join(encoders, "\n\n") <> "\n\n" <> string.join(decoders, "\n\n") <> "\n")
}

fn check_no_mixed_fields(
  discovered: List(DiscoveredType),
) -> Result(Nil, List(JsonError)) {
  let errors =
    list.flat_map(discovered, fn(dt) {
      list.flat_map(dt.variants, fn(v) {
        case has_mixed_fields(v.field_labels) {
          True -> [JsonError(
            path: dt.module_path <> "." <> dt.type_name <> "." <> v.variant_name,
            message: "mixed labelled/unlabelled fields are not supported in JSON v1",
          )]
          False -> []
        }
      })
    })
  case errors {
    [] -> Ok(Nil)
    _ -> Error(errors)
  }
}

fn has_mixed_fields(labels: List(Option(String))) -> Bool {
  let has_labelled = list.any(labels, fn(l) { l != None })
  let has_unlabelled = list.any(labels, fn(l) { l == None })
  has_labelled && has_unlabelled
}
```

The encoder/decoder emitter functions follow the spec patterns. For each `DiscoveredType`, emit:

```gleam
pub fn json_encode_<qualified>(value: <Type>) -> json.Json
pub fn json_decode_<qualified>(value: Dynamic) -> Result(<Type>, List(JsonError))
```

The qualified name uses `walker.qualified_atom_name`. Each variant encodes to:
- `json.object([#("type", json.string("<module>.<Type>")), #("variant", json.string("<Variant>")), #("fields", ...)])`

Labelled fields produce `json.object(...)` for fields. Unlabelled produce `json.array(...)`.

See the spec section "Generated Encoder/Decoder Shape" for the exact patterns.

- [ ] **Step 4: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass (codegen tests pass, ETF tests unchanged).

- [ ] **Step 5: Commit**

```bash
git add src/libero/json/codegen.gleam test/libero/json_codegen_test.gleam
git commit -m "Generate JSON typed codecs"
```

---

### Task 7: JSON Wire (Frame Helpers)

**Files:**
- Create: `src/libero/json/wire.gleam`
- Modify: `src/libero/wire.gleam` (add protocol-aware wrappers only if needed)
- Test: `test/libero/json_wire_test.gleam`

- [ ] **Step 1: Write JSON wire tests**

Create `test/libero/json_wire_test.gleam`:

```gleam
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should
import libero/json/error.{type JsonError, JsonError}
import libero/json/wire
import libero/frame.{type ServerFrame, Response, Push, Error}

pub fn encode_request_produces_correct_shape_test() {
  let message = json.object([
    #("type", json.string("shared/messages.MsgFromClient")),
    #("variant", json.string("GetArticle")),
    #("fields", json.object([#("slug", json.string("hello-world"))])),
  ])

  let encoded = wire.encode_request(
    module: "rpc",
    request_id: 1,
    msg: message,
    contract_hash: "abc123",
  )

  encoded |> should.contain("\"kind\"")
  encoded |> should.contain("\"request\"")
  encoded |> should.contain("\"protocol_version\"")
  encoded |> should.contain("json-rpc-v1")
  encoded |> should.contain("\"contract_hash\"")
  encoded |> should.contain("abc123")
  encoded |> should.contain("\"module\"")
  encoded |> should.contain("\"rpc\"")
  encoded |> should.contain("\"request_id\"")
  encoded |> should.contain("\"message\"")
}

pub fn encode_response_produces_correct_shape_test() {
  let value = json.object([
    #("type", json.string("gleam/result.Result")),
    #("variant", json.string("Ok")),
    #("fields", json.array([json.string("done")], of: fn(x) { x })),
  ])

  let encoded = wire.encode_response(request_id: 1, value:)

  encoded |> should.contain("\"kind\"")
  encoded |> should.contain("\"response\"")
  encoded |> should.contain("\"request_id\"")
  encoded |> should.contain("\"value\"")
}

pub fn encode_error_produces_correct_shape_test() {
  let errors = [JsonError(path: "message.fields.slug", message: "expected String, got Null")]

  let encoded = wire.encode_error(request_id: Some(1), errors:)

  encoded |> should.contain("\"kind\"")
  encoded |> should.contain("\"error\"")
  encoded |> should.contain("\"errors\"")
}

pub fn encode_push_produces_correct_shape_test() {
  let value = json.object([
    #("type", json.string("public/pages/article.ToClient")),
    #("variant", json.string("CommentsUpdated")),
    #("fields", json.object([#("comments", json.array([], of: json.string))])),
  ])

  let encoded = wire.encode_push(module: "public/pages/article", value:)

  encoded |> should.contain("\"kind\"")
  encoded |> should.contain("\"push\"")
  encoded |> should.contain("\"module\"")
  encoded |> should.contain("\"value\"")
}

pub fn encode_flags_escapes_html_unsafe_chars_test() {
  let value = json.string("</script><script>alert('xss')</script>")

  let encoded = wire.encode_flags(value)

  // Must NOT contain raw <, >, &
  encoded |> should.not_contain("<")
  encoded |> should.not_contain(">")
}

pub fn decode_server_frame_handles_unknown_kind_test() {
  let data = "{\"kind\":\"unknown\",\"protocol_version\":\"json-rpc-v1\"}"

  let result = wire.decode_server_frame(data)

  case result {
    Error(errors) -> {
      errors |> should.not_equal([])
    }
    Ok(_) -> should.fail("expected error for unknown kind")
  }
}

pub fn decode_request_validates_contract_hash_test() {
  let data = "{
    \"kind\": \"request\",
    \"protocol_version\": \"json-rpc-v1\",
    \"contract_hash\": \"wrong-hash\",
    \"module\": \"rpc\",
    \"request_id\": 1,
    \"message\": {\"type\":\"shared/messages.MsgFromClient\",\"variant\":\"GetArticle\",\"fields\":{\"slug\":\"hello\"}}
  }"

  let result = wire.decode_request(data, expected_hash: "abc123")

  case result {
    Error(errors) -> {
      let messages = errors |> list.map(fn(e) { e.message })
      list.any(messages, fn(m) { string.contains(m, "contract_hash") })
      |> should.be_true()
    }
    Ok(_) -> should.fail("expected contract hash mismatch error")
  }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam test --target erlang
```

Expected: compile fails because `libero/json/wire` does not exist.

- [ ] **Step 3: Implement `src/libero/json/wire.gleam`**

```gleam
//// JSON wire protocol: encode/decode, frame builders, SSR flags.
////
//// All encode functions take already-encoded `json.Json` values.
//// Generated typed encoders run first; this module wraps them in
//// protocol envelopes.
////
//// Produces/consumes `String` (JSON text), not `BitArray`.

import gleam/dynamic
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import libero/frame.{type ServerFrame, Error, Push, Response}
import libero/json/error.{type JsonError, JsonError}

const json_rpc_v1 = "json-rpc-v1"

// ---------- Types ----------

pub type RequestEnvelope {
  RequestEnvelope(module: String, request_id: Int, message: dynamic.Dynamic)
}

// ---------- Request ----------

pub fn encode_request(
  module module: String,
  request_id request_id: Int,
  msg msg: json.Json,
  contract_hash contract_hash: String,
) -> String {
  json.object([
    #("kind", json.string("request")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("contract_hash", json.string(contract_hash)),
    #("module", json.string(module)),
    #("request_id", json.int(request_id)),
    #("message", msg),
  ])
  |> json.to_string
}

pub fn decode_request(
  data data: String,
  expected_hash expected_hash: String,
) -> Result(RequestEnvelope, List(JsonError)) {
  let parsed = case json.parse(data, dynamic.dynamic) {
    Ok(v) -> v
    Error(_) -> return Error([JsonError("", "failed to parse JSON")])
  }

  // Validate kind
  use _ <- result.try(validate_kind(parsed, "request"))

  // Validate protocol_version (fail fast, no accumulation)
  use _ <- result.try(validate_protocol_version(parsed))

  // Validate contract_hash (fail fast, no accumulation)
  use _ <- result.try(validate_contract_hash(parsed, expected_hash))

  // Extract module
  let module = case dynamic.field(parsed, "module") {
    Ok(m) -> case dynamic.string(m) {
      Ok(s) -> s
      Error(_) -> return Error([JsonError("module", "expected String")])
    }
    Error(_) -> return Error([JsonError("module", "required field missing")])
  }

  // Extract request_id
  let request_id = case dynamic.field(parsed, "request_id") {
    Ok(id) -> case dynamic.int(id) {
      Ok(n) -> n
      Error(_) -> return Error([JsonError("request_id", "expected Int")])
    }
    Error(_) -> return Error([JsonError("request_id", "required field missing")])
  }

  // Extract message
  let message = case dynamic.field(parsed, "message") {
    Ok(m) -> m
    Error(_) -> return Error([JsonError("message", "required field missing")])
  }

  Ok(RequestEnvelope(module:, request_id:, message:))
}

// ---------- Response ----------

pub fn encode_response(request_id request_id: Int, value value: json.Json) -> String {
  json.object([
    #("kind", json.string("response")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("request_id", json.int(request_id)),
    #("value", value),
  ])
  |> json.to_string
}

// ---------- Error ----------

pub fn encode_error(
  request_id request_id: Option(Int),
  errors errors: List(JsonError),
) -> String {
  let rid = case request_id {
    Some(id) -> json.int(id)
    None -> json.null()
  }
  json.object([
    #("kind", json.string("error")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("request_id", rid),
    #("errors", json.array(errors, of: fn(e) {
      json.object([
        #("path", json.string(e.path)),
        #("message", json.string(e.message)),
      ])
    })),
  ])
  |> json.to_string
}

// ---------- Push ----------

pub fn encode_push(module module: String, value value: json.Json) -> String {
  json.object([
    #("kind", json.string("push")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("module", json.string(module)),
    #("value", value),
  ])
  |> json.to_string
}

// ---------- Server frame decode ----------

pub fn decode_server_frame(
  data data: String,
) -> Result(ServerFrame(dynamic.Dynamic), List(JsonError)) {
  let parsed = case json.parse(data, dynamic.dynamic) {
    Ok(v) -> v
    Error(_) -> return Error([JsonError("", "failed to parse JSON")])
  }

  let kind = case dynamic.field(parsed, "kind") {
    Ok(k) -> case dynamic.string(k) {
      Ok(s) -> s
      Error(_) -> return Error([JsonError("kind", "expected String")])
    }
    Error(_) -> return Error([JsonError("kind", "required field missing")])
  }

  case kind {
    "response" -> decode_response_frame_body(parsed)
    "push" -> decode_push_frame_body(parsed)
    "error" -> decode_error_frame_body(parsed)
    _ -> Error([JsonError("kind", "unknown frame kind: " <> kind)])
  }
}

fn decode_response_frame_body(
  parsed: dynamic.Dynamic,
) -> Result(ServerFrame(dynamic.Dynamic), List(JsonError)) {
  let request_id = case dynamic.field(parsed, "request_id") {
    Ok(id) -> case dynamic.int(id) {
      Ok(n) -> n
      Error(_) -> return Error([JsonError("request_id", "expected Int")])
    }
    Error(_) -> return Error([JsonError("request_id", "required field missing")])
  }

  let value = case dynamic.field(parsed, "value") {
    Ok(v) -> v
    Error(_) -> return Error([JsonError("value", "required field missing")])
  }

  Ok(Response(request_id:, value:))
}

fn decode_push_frame_body(
  parsed: dynamic.Dynamic,
) -> Result(ServerFrame(dynamic.Dynamic), List(JsonError)) {
  let module = case dynamic.field(parsed, "module") {
    Ok(m) -> case dynamic.string(m) {
      Ok(s) -> s
      Error(_) -> return Error([JsonError("module", "expected String")])
    }
    Error(_) -> return Error([JsonError("module", "required field missing")])
  }

  let value = case dynamic.field(parsed, "value") {
    Ok(v) -> v
    Error(_) -> return Error([JsonError("value", "required field missing")])
  }

  Ok(Push(module:, value:))
}

fn decode_error_frame_body(
  parsed: dynamic.Dynamic,
) -> Result(ServerFrame(dynamic.Dynamic), List(JsonError)) {
  let request_id = case dynamic.field(parsed, "request_id") {
    Ok(id) -> case dynamic.int(id) {
      Ok(n) -> Some(n)
      Error(_) -> None
    }
    Error(_) -> None
  }

  let errors = case dynamic.field(parsed, "errors") {
    Ok(arr) -> case dynamic.list(arr) {
      Ok(items) ->
        list.flat_map(items, fn(item) {
          let path = case dynamic.field(item, "path") {
            Ok(p) -> case dynamic.string(p) { Ok(s) -> s; Error(_) -> "" }
            Error(_) -> ""
          }
          let message = case dynamic.field(item, "message") {
            Ok(m) -> case dynamic.string(m) { Ok(s) -> s; Error(_) -> "unknown error" }
            Error(_) -> "unknown error"
          }
          [#(path, message)]
        })
      Error(_) -> [#("errors", "expected Array")]
    }
    Error(_) -> [#("errors", "required field missing")]
  }

  Ok(Error(request_id:, errors:))
}

// ---------- SSR flags ----------

pub fn encode_flags(value: json.Json) -> String {
  let json_str = json.to_string(value)
  escape_script_json(json_str)
}

pub fn decode_flags_typed(
  flags flags: String,
  decoder_name decoder_name: String,
) -> Result(a, List(JsonError)) {
  let _ = decoder_name
  // Typed decode delegation: the caller (generated codec module) will
  // pass this through to the generated decoder function. This function
  // just parses the JSON to Dynamic.
  case json.parse(flags, dynamic.dynamic) {
    Ok(value) -> {
      // Caller will apply typed decoder. We just verify valid JSON.
      // The actual typed decode happens through the generated codec
      // module, not here.
      Ok(dynamic.unsafe_coerce(value))
    }
    Error(_) -> Error([JsonError("flags", "failed to parse flags JSON")])
  }
}

// ---------- Validation helpers ----------

fn validate_kind(
  parsed: dynamic.Dynamic,
  expected: String,
) -> Result(Nil, List(JsonError)) {
  case dynamic.field(parsed, "kind") {
    Ok(k) -> case dynamic.string(k) {
      Ok(s) if s == expected -> Ok(Nil)
      Ok(s) -> Error([JsonError("kind", "expected \"" <> expected <> "\", got \"" <> s <> "\"")])
      Error(_) -> Error([JsonError("kind", "expected String")])
    }
    Error(_) -> Error([JsonError("kind", "required field missing")])
  }
}

fn validate_protocol_version(
  parsed: dynamic.Dynamic,
) -> Result(Nil, List(JsonError)) {
  case dynamic.field(parsed, "protocol_version") {
    Ok(v) -> case dynamic.string(v) {
      Ok(s) if s == json_rpc_v1 -> Ok(Nil)
      Ok(s) -> Error([JsonError("protocol_version", "unsupported version: " <> s)])
      Error(_) -> Error([JsonError("protocol_version", "expected String")])
    }
    Error(_) -> Error([JsonError("protocol_version", "required field missing")])
  }
}

fn validate_contract_hash(
  parsed: dynamic.Dynamic,
  expected_hash: String,
) -> Result(Nil, List(JsonError)) {
  case dynamic.field(parsed, "contract_hash") {
    Ok(v) -> case dynamic.string(v) {
      Ok(s) if s == expected_hash -> Ok(Nil)
      Ok(_) -> Error([JsonError("contract_hash", "contract hash mismatch")])
      Error(_) -> Error([JsonError("contract_hash", "expected String")])
    }
    Error(_) -> Error([JsonError("contract_hash", "required field missing")])
  }
}

// ---------- HTML escaping for SSR ----------

fn escape_script_json(input: String) -> String {
  input
  |> string.replace("<", "\\u003c")
  |> string.replace(">", "\\u003e")
  |> string.replace("&", "\\u0026")
  |> string.replace("\u{2028}", "\\u2028")
  |> string.replace("\u{2029}", "\\u2029")
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass (old ETF tests + new JSON wire tests).

- [ ] **Step 5: Commit**

```bash
git add src/libero/json/wire.gleam test/libero/json_wire_test.gleam
git commit -m "Add JSON wire protocol helpers"
```

---

### Task 8: Wire JSON Generation into libero.gleam main()

**Files:**
- Modify: `src/libero.gleam`

- [ ] **Step 1: Add contract and codec generation to `main()`**

In `src/libero.gleam`, import the new codegen:

```gleam
import libero/json/codegen
```

In the `main()` function, after the `discovered` variable is available and after the existing ETF generation calls, add:

```gleam
// JSON contract artifact
let json_contract = contract.generate(endpoints:, discovered:)
```

And after `write_generated_files(...)`, write the JSON outputs:

```gleam
let _ = write_file(out_dir <> "/rpc_contract.json", json_contract)

// JSON codecs (only if we have discovered types)
case discovered {
  [] -> Nil
  _ -> {
    case codegen.generate(discovered:, endpoints: [], push_dispatches: []) {
      Ok(json_codecs_src) -> {
        let _ = write_file(
          out_dir <> "/json_codecs.gleam",
          format.format_gleam(json_codecs_src),
        )
        Nil
      }
      Error(errors) -> {
        io.println_error("[libero] JSON codec generation failed:")
        list.each(errors, fn(e) { io.println_error("  " <> e.path <> ": " <> e.message) })
        Nil
      }
    }
  }
}
```

Update the `wrote` message to include the new files.

- [ ] **Step 2: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass.

- [ ] **Step 3: Commit**

```bash
git add src/libero.gleam
git commit -m "Wire JSON contract and codec generation into main()"
```

---

### Task 9: Rally Protocol Config

**Files:**
- Modify: `src/rally/types.gleam`
- Modify: `src/rally.gleam`
- Test: `test/rally/scaffold_contract_test.gleam` (or appropriate existing test)

- [ ] **Step 1: Add `protocol` to `ScanConfig`**

In `src/rally/types.gleam`, add `import libero/protocol.{type Protocol}` and add the field:

```gleam
protocol: Protocol,
```

to the `ScanConfig` type.

- [ ] **Step 2: Parse protocol from TOML config**

In `src/rally.gleam`, where `ScanConfig` is constructed from TOML, add:

```gleam
import libero/protocol

fn read_protocol(config: dict.Dict(String, tom.Toml)) -> Result(Protocol, RallyError) {
  case tom.get_string(config, ["protocol"]) {
    Ok(value) ->
      protocol.from_string(value)
      |> result.map_error(fn(msg) { RallyError(msg) })
    Error(_) -> Ok(protocol.Etf)
  }
}
```

Thread `protocol:` into every `ScanConfig` constructor call.

- [ ] **Step 3: Run Rally tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/rally
gleam format
gleam test
```

Expected: all Rally tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/rally/types.gleam src/rally.gleam
git commit -m "Add Rally protocol config"
```

---

### Task 10: Rally Generated Transport Stays Protocol-Agnostic

**Files:**
- Modify: `src/rally/generator/client.gleam` (emit protocol constant, keep transport agnostic)
- Test: `test/rally_runtime/transport_boundary_test.gleam` (verify no JSON.parse in generated output)

- [ ] **Step 1: Emit protocol constant in generated client**

In `client.gleam`, the generated `transport.gleam` should include a protocol constant based on the `ScanConfig.protocol` value:

```gleam
pub const protocol = "<etf or json>"
```

This is informational for the generated code; the actual protocol dispatch happens in Libero's FFI.

- [ ] **Step 2: Verify transport stays agnostic**

The generated `transport_ffi.mjs` must not contain `JSON.parse` or `JSON.stringify` for protocol handling. Those stay in Libero's `rpc_ffi.mjs`. The transport continues to call `encode_request` and `decode_server_frame` from Libero, which handles protocol dispatch internally.

- [ ] **Step 3: Run Rally tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/rally
gleam format
gleam test
```

Expected: all Rally tests pass.

- [ ] **Step 4: Commit**

```bash
git add src/rally/generator/client.gleam
git commit -m "Emit protocol constant in generated transport"
```

---

### Task 11: JSON End-to-End Libero Roundtrip Tests

**Files:**
- Test: `test/libero/json_wire_roundtrip_test.gleam`

- [ ] **Step 1: Write roundtrip tests**

Create `test/libero/json_wire_roundtrip_test.gleam`:

```gleam
import gleam/json
import gleam/option.{None, Some}
import gleeunit/should
import libero/json/error.{type JsonError}
import libero/json/wire

pub fn request_encode_then_decode_roundtrip_test() {
  let message = json.object([
    #("type", json.string("shared/messages.MsgFromClient")),
    #("variant", json.string("GetArticle")),
    #("fields", json.object([#("slug", json.string("hello-world"))])),
  ])

  let encoded = wire.encode_request(
    module: "rpc",
    request_id: 42,
    msg: message,
    contract_hash: "test-hash",
  )

  let decoded = wire.decode_request(encoded, expected_hash: "test-hash")

  case decoded {
    Ok(wire.RequestEnvelope(module:, request_id:, message:)) -> {
      module |> should.equal("rpc")
      request_id |> should.equal(42)
    }
    Error(errors) -> should.fail("decode failed: " <> string.inspect(errors))
  }
}

pub fn response_roundtrip_test() {
  let value = json.object([
    #("type", json.string("gleam/result.Result")),
    #("variant", json.string("Ok")),
    #("fields", json.array([json.string("done")], of: fn(x) { x })),
  ])

  let encoded = wire.encode_response(request_id: 1, value:)

  case wire.decode_server_frame(encoded) {
    Ok(Response(request_id: 1, value:)) -> Nil
    other -> should.fail("unexpected decode result: " <> string.inspect(other))
  }
}

pub fn push_roundtrip_test() {
  let value = json.object([
    #("type", json.string("public/pages/article.ToClient")),
    #("variant", json.string("CommentsUpdated")),
    #("fields", json.object([#("comments", json.array([], of: json.string))])),
  ])

  let encoded = wire.encode_push(module: "public/pages/article", value:)

  case wire.decode_server_frame(encoded) {
    Ok(Push(module: "public/pages/article", value:)) -> Nil
    other -> should.fail("unexpected decode result: " <> string.inspect(other))
  }
}

pub fn error_roundtrip_test() {
  let errors = [JsonError(path: "fields.slug", message: "expected String, got Null")]

  let encoded = wire.encode_error(request_id: Some(1), errors:)

  case wire.decode_server_frame(encoded) {
    Ok(Error(request_id: Some(1), errors:)) -> should.equal(errors, [#("fields.slug", "expected String, got Null")])
    other -> should.fail("unexpected decode result: " <> string.inspect(other))
  }
}

pub fn protocol_version_mismatch_test() {
  let data = "{\"kind\":\"request\",\"protocol_version\":\"json-rpc-v2\",\"module\":\"rpc\",\"request_id\":1,\"message\":{}}"

  case wire.decode_request(data, expected_hash: "any") {
    Error(errors) -> {
      list.any(errors, fn(e) { string.contains(e.message, "unsupported version") })
      |> should.be_true()
    }
    Ok(_) -> should.fail("expected protocol version error")
  }
}

pub fn decode_server_frame_unknown_kind_test() {
  let data = "{\"kind\":\"unknown\"}"

  case wire.decode_server_frame(data) {
    Error(errors) -> {
      list.any(errors, fn(e) { string.contains(e.message, "unknown frame kind") })
      |> should.be_true()
    }
    Ok(_) -> should.fail("expected unknown kind error")
  }
}
```

- [ ] **Step 2: Run tests**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format
gleam test
```

Expected: all Libero tests pass, including roundtrip tests.

- [ ] **Step 3: Commit**

```bash
git add test/libero/json_wire_roundtrip_test.gleam
git commit -m "Add JSON wire roundtrip tests"
```

---

### Task 12: Final Verification

- [ ] **Step 1: Libero verification**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
gleam format --check
gleam test
git status -sb
```

Expected: all tests pass, clean or intentionally-between-commits worktree.

- [ ] **Step 2: Rally verification**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/rally
gleam format --check
gleam test
git status -sb
```

Expected: all tests pass.

- [ ] **Step 3: Boundary grep**

Run in Rally:

```bash
rg "decode_safe_raw|decodeTyped|decode_value\\(|DataView|getUint32|0x00|0x01|JSON.parse|JSON.stringify" src/rally_runtime/transport_ffi.mjs src/rally/generator/
```

Expected: generated transport code does not contain JSON.parse or raw ETF frame operations. Guard test files may reference banned strings by name.

- [ ] **Step 4: Push both branches**

```bash
cd /Users/daverapin/projects/opensource/json-wire-worktrees/libero
git push -u origin codex/json-wire-protocol
cd /Users/daverapin/projects/opensource/json-wire-worktrees/rally
git push -u origin codex/json-wire-protocol
```

---

## Notes For The Implementing Agent

- Do not remove ETF.
- Do not add compact, condensed, or indexed JSON modes.
- Do not let Rally parse JSON envelopes.
- Do not dispatch custom types by bare constructor names.
- Do not dispatch custom types by constructor name plus arity.
- Do not infer custom type identity from JSON field shape.
- The `FieldType` record is NOT extended for labels. Labels live on `DiscoveredVariant.field_labels`.
- `codegen_wire_erl.gleam` stays ETF-only. Do not add JSON branches to it.
- All JSON wire encode functions take `json.Json`, not generic `a`.
- `ServerFrame` lives in `libero/frame.gleam`. Both `wire.gleam` and `json/wire.gleam` import it.
- If the plan and spec disagree, stop and update the spec first.
