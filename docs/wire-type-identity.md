# Wire-Format Type Identity via Codegen

**Status:** Implementation in progress (libero steps 1-10 complete, v3 cutover pending)
**Created:** 2026-05-08
**Scope:** libero (primary), rally (consumer), v3 (smoke target)

### Implementation status

| Step | Description | Status |
|------|-------------|--------|
| 1-2 | Hash + canonical signature primitives, uniqueness check | Done (2b00822, 99297d4) |
| 3 | Per-type Erlang transformers (`codegen_wire_erl`) | Done (b9b2213) |
| 1+ | Wire `codegen_wire_erl.generate()` into pipeline | Done (this session) |
| 6 | Dispatch calls generated decode/encode transformers | Done (this session, was missing from previous attempt) |
| 4-5 | Per-class `__wireAtom`/`__fieldTypes` in JS codegen | Done (this session) |
| 7 | JS runtime cleanup (`_bareToQualifiedAtom`, `fieldTypeRegistry` removed) | Done (this session) |
| 8 | Erlang runtime cleanup (`qualify_atoms` removed, `encode/1` = `term_to_binary`) | Done (this session) |
| 9 | Same-name collision E2E fixture | Done (139d979, 452d241) |
| 10 | `gleam test` + `gleam run -m glinter` clean | Done |
| 11 | v3 cutover (`bin/regen`, smoke test) | Not yet |

**Lesson from first attempt:** Steps 4, 5, 7, 8 were landed without Step 6.
The dispatch never called the wire transformers, so JS sent hashed atoms that
the Erlang dispatch couldn't decode, and the Erlang handler returned bare atoms
that JS couldn't decode. The fix was to implement Step 6 first (dispatch calls
`decode_X` on inbound params, `encode_X` on outbound results), then layer the
other steps on top. The atoms_erl module also dropped its AtomMap in this pass
since wire identity is now baked into the transformer functions.

---

## Table of contents

1. [Problem](#problem)
2. [Root cause](#root-cause)
3. [Solution overview](#solution-overview)
4. [Goals](#goals)
5. [Non-goals](#non-goals)
6. [Design](#design)
   - [Wire identity and hash design](#wire-identity-and-hash-design)
   - [Erlang side](#erlang-side)
   - [JS side](#js-side)
   - [User code](#user-code)
   - [Codegen uniqueness enforcement](#codegen-uniqueness-enforcement)
   - [Edge cases](#edge-cases)
7. [Why this over alternatives](#why-this-over-alternatives)
8. [File-by-file change inventory](#file-by-file-change-inventory)
9. [Codegen API changes](#codegen-api-changes)
10. [Hash function reference implementations](#hash-function-reference-implementations)
11. [Implementation: lockstep cutover](#implementation-lockstep-cutover)
12. [Test plan](#test-plan)
13. [Acceptance criteria](#acceptance-criteria)
14. [Risk and rollback](#risk-and-rollback)
15. [Security relationship](#security-relationship)
16. [Cross-references](#cross-references)
17. [Open questions](#open-questions)

---

## Problem

ETF (and BEAM more broadly) treats the atom table as global. Two Gleam types named `Discount` in different modules both compile to the wire tag `discount`. The Gleam compiler keeps them distinct at the type level, but the wire format does not. This is a flaw in ETF, not in Gleam: the wire format predates module-aware namespacing.

The current libero workaround maintains runtime lookup tables that map bare names to qualified atoms (Erlang `AtomMap`, JS `_bareToQualifiedAtom`, JS `fieldTypeRegistry`). The tables are populated at boot from generated codegen output. At encode time, the tables translate bare tags to qualified tags so the wire carries enough information to disambiguate.

This workaround has produced two related bugs in v3, both in libero, both rooted in "look up qualification from a bare key":

1. **`libero-ljv6` (the JS-side bug we hit on 2026-05-08).** `_bareToQualifiedAtom` is keyed by bare name only. When two types share a bare name (list-page `Discount` with 6 fields and edit-page `Discount` with 19 fields), the second registration overwrites the first. Outbound encoding emits the wrong qualified atom for one of the two types, and the receiving decoder rejects it.

2. **`libero-3ccw` (sibling bug, JS encode side).** `fieldTypeRegistry` is keyed by qualified atom but the encoder computes the lookup using `snakeCase(value.constructor.name)` (bare name) without first translating to qualified. Whole-number Float fields are encoded as Ints because the lookup misses.

Both bugs share a root cause: a global runtime lookup table keyed on a bare name (or accessed via a bare name) is one collision, or one missed translation, away from returning the wrong answer. The Erlang side has the same shape of risk; we have not yet observed it producing a bug in v3 because the BEAM lookup happens to use `{tag, arity}` rather than bare name, but it remains a global table with the same failure modes.

## Root cause

The architecture relies on global runtime lookup tables for type identity translation. The information needed for those translations is fully known at codegen time, but the codegen punts the answer to a global table consulted at runtime. Anywhere that table is keyed by something less than fully-unique, collision is possible.

## Solution overview

Move type identity resolution from runtime lookup tables to per-type generated code. Each type gets its own encode/decode functions (Erlang) and its own static identity (JS). The wire identity is baked into the generated function bodies, not stored in a global registry.

Wire identity is a 10-character hex hash with no name prefix. Readability is provided by generated error messages and an optional debug manifest, both produced by the codegen at build time. The hash is opaque on the wire; meaning lives at codegen time.

The hash basis is **unique source identity** (module path + constructor name + field type list), not just structural shape. Two types with the same constructor name and the same field shape in different modules produce different hashes by design, because their module paths differ. There is no scenario where two genuinely-distinct user types collide on the wire.

Codegen-time uniqueness enforcement is the only safety mechanism. It catches the only remaining collision case (a hash function birthday-collision between two distinct canonical signatures) and surfaces it as a build error. This is rare to the point of being almost theoretical, but the check is cheap and the test for it is small.

## Goals

1. Eliminate the runtime lookup tables (`AtomMap` on Erlang, `_bareToQualifiedAtom` on JS, `fieldTypeRegistry` on JS).
2. Eliminate the bug class where a global table can return the wrong qualified atom for a runtime value (`libero-ljv6` and `libero-3ccw` both go away).
3. User-facing Gleam types stay unchanged. No imports of generated wire types, no aliases in user code, no leak of hashed names into compile error messages or IDE tooling.
4. Wire bytes shrink: a wire atom is 10 hex chars instead of 44+ chars of module path.
5. Two modules with same-named, same-shaped types coexist without collision and without a codegen error.
6. Symmetric reasoning between Erlang and JS sides. Auditing the JS code and Erlang code arrives at the same mental model.

## Non-goals

1. Switching to a non-ETF wire format. JSON, Protobuf, Avro, and Cap'n Proto were all considered; none deliver enough win to justify the migration cost in our context (covered in [Why this over alternatives](#why-this-over-alternatives)).
2. Schema-first Gleam (libero owns type definitions, users import them). Considered and rejected because aliased imports leak the hashed name into compile error messages and IDE tooling.
3. Backward compatibility with the current qualified-path scheme. v3 and rally are pre-launch with one consumer; we do a lockstep cutover.
4. Hash collision resistance suitable for cryptographic use. The hash is a uniqueness check, not a security primitive. Codegen-time enforcement is the actual safety net.
5. Mixed-state operation. There is no scheme where libero ships the new codegen and a consumer continues to run with stale generated files. Consumers regenerate immediately after pulling new libero.

## Design

### Wire identity and hash design

Each type's wire atom is a 10-character lowercase hex hash. No bare name prefix, no module path embedded in text form. The atom is opaque on the wire.

Examples:

| Source                                                  | Wire atom    |
|---------------------------------------------------------|--------------|
| List-page `Discount` (6 fields, see v3)                 | `a3b9c2d1ee` |
| Edit-page `Discount` (19 fields, see v3)                | `b1f44d99c2` |
| Envelope `DiscountAdminData(discounts: List(Discount))` | `4f9821bcde` |
| 0-arity variant `Pending` of `Status`                   | `aa11bb22cc` |
| RPC envelope `ServerLoadDiscounts` (no args)            | `7c3e2a1b09` |
| RPC envelope `ServerUpdateDiscount(DiscountParams)`     | `aabbccddee` |

Wire bytes are 10 chars per atom occurrence, regardless of source module depth. Readability comes from two places: the codegen-baked error messages (each decoder body knows its own hash AND its source location), and an optional manifest file the codegen emits alongside the build (`build/wire-manifest.json` mapping hash → source location).

#### Hash basis (canonical signature)

The canonical signature is a UTF-8 string identifying the type by source identity, not just shape. Format:

```
<module_path>|<constructor_name>|<field_types>
```

Where:

- `module_path` is the Gleam module path, e.g. `admin/pages/registration/discounts`.
- `constructor_name` is the variant name as written in source (not snake-cased; it is the canonical constructor name).
- `field_types` is the comma-separated list of field types in declaration order, using these tokens:
  - Primitives: `int`, `string`, `float`, `bool`, `bit_array`, `nil`.
  - Containers: `list<T>`, `option<T>`, `result<T,E>`, `dict<K,V>`, `tuple<T1,T2,...>`.
  - User-defined types: `<type:module_path|type_name>` (a textual reference to the other type's source identity). It is not a recursive hash. This eliminates dependency cycles entirely.
  - Framework atom enums (rare): the bare atom name.

Example canonical signatures:

```
admin/pages/registration/discounts|Discount|int,string,option<string>,float,int,bool
admin/pages/registration/discounts/id_|Discount|int,string,option<string>,...,int,int
admin/pages/registration/discounts|DiscountAdminData|list<<type:admin/pages/registration/discounts|Discount>>
shared/types|Pending|
shared/types|Active|
shared/page|Leaf|int
shared/page|Node|int,<type:shared/page|Tree>,<type:shared/page|Tree>
```

Properties of this scheme:

- **Module path included.** Two modules with the same constructor and same field shape produce different canonical signatures (different `module_path` prefix) and different hashes. No collision.
- **Constructor name preserves case.** `Discount` and `discount` (if both were valid Gleam) produce different signatures. In practice Gleam constructors are PascalCase so this is moot; the rule is documented for completeness.
- **Field names are omitted from the signature.** Renaming a field preserves wire compatibility. Changing a field type or order does not.
- **No transitive hash dependency.** A user-type reference is a textual `<type:...>` reference, not the inner type's hash. Computing the hash for a parent type requires only the parent's own definition; the inner type's identity is referenced by source path. This means recursive and mutually-recursive types have no cycle problem.
- **Nested type changes do not change parent hashes.** If `Discount` changes shape, `DiscountAdminData(discounts: List(Discount))` keeps the same parent hash because the parent still points at the same source type. Nested values still fail fast when their own hashed atoms are decoded. Empty containers can still decode across versions because they contain no nested atoms to compare. This is acceptable because libero and v3 cut over in lockstep; mixed old/new generated output is unsupported.

#### Hash function

SHA-256 truncated to 40 bits, rendered as 10 lowercase hex chars. SHA-256 is universally available via OTP `crypto:hash/2` and Gleam's `gleam_crypto`. BLAKE2b would be slightly faster but its OTP support is version-dependent; not worth the dependency complexity.

40 bits gives roughly 1 trillion distinct values. Birthday-paradox collisions of two distinct canonical signatures become statistically likely around 1M types. Our universe never approaches this; codegen-time uniqueness enforcement covers the residual case.

Hashes that begin with a hex digit (`0`-`9`) are still valid wire atoms. In Erlang source, the codegen quotes them: `'3b9c2d1ee0'`. ETF wire encoding is unaffected by quoting. JS-side comparisons are string comparisons, also unaffected.

#### Hash stability

Hashes are pure functions of the canonical signature. The following actions change a hash (and therefore break wire compatibility):

- Adding, removing, reordering, or retyping a field.
- Renaming a constructor.
- Moving a type from one module to another (changes module path).

The following actions preserve a hash:

- Renaming a field.
- Changing a field's documentation comment, default, or other non-type-level metadata.

This is desired. A direct change to a constructor's own wire shape changes that constructor's hash, and any decoder built against the old shape fails fast on that constructor atom. Parent containers keep stable hashes when only nested types change; the nested values carry their own hashes and fail at the nested boundary.

### Erlang side

#### Per-type generated transformers

For each Gleam type that crosses the wire, libero codegen emits parent-type Erlang encode/decode transformers. The transformer function name is an internal source-derived symbol, while the emitted tuple/atom tag is the constructor's wire hash:

```erlang
%% generated/<consumer>_wire.erl
%%
%% Encode: BEAM-shape (bare tag) -> wire-shape (hashed tag)
encode_discount({discount, Id, NameEn, NameFr, Percent, Cents, Enabled}) ->
    {'a3b9c2d1ee', Id, NameEn, NameFr,
     encode_float(Percent), Cents, Enabled}.

%% Decode: wire-shape -> BEAM-shape
decode_discount({'a3b9c2d1ee', Id, NameEn, NameFr, Percent, Cents, Enabled}) ->
    {discount, Id, NameEn, NameFr, Percent, Cents, Enabled}.
```

Notes on field handling:

- Primitive fields (`int`, `string`, `bool`, `bit_array`) pass through unchanged.
- `Float` fields go through `encode_float/1`, a tiny helper that ensures whole-number floats are encoded as floats (`2.0`) rather than ints (`2`). This replaces the existing `fieldTypeRegistry` "float" hint mechanism.
- User-typed fields recurse through that type's generated parent transformer (for example `encode_status/1` for `Status`, or `encode_discount/1` for a single-constructor `Discount` type). Parent transformer names are codegen-internal symbols derived from source identity, so two modules can both define `Status` without colliding.
- Container fields (`List(T)`, `Option(T)`, etc.) inline a recursive call (see [Generic types](#generic-types) below).

For envelope types containing nested user types:

```erlang
encode_discount_admin_data({discount_admin_data, Discounts}) ->
    {'4f9821bcde',
     [encode_discount(D) || D <- Discounts]}.

decode_discount_admin_data({'4f9821bcde', Discounts}) ->
    {discount_admin_data,
     [decode_discount(D) || D <- Discounts]}.
```

The codegen always quotes generated hash atoms in Erlang source (`'a3b9c2d1ee'`, `'4f9821bcde'`). Quoting is valid even when the atom starts with a letter, and it avoids special cases for digit-leading hashes.

The codegen knows each field's type at generation time and emits the appropriate transformation directly. No runtime type inspection happens.

For sum types and 0-arity user variants, call sites use a parent-type umbrella transformer. Each variant still has its own wire hash, but fields typed as `Status` call `encode_status/1` and `decode_status/1`. The umbrella chooses the variant clause:

```erlang
encode_status(pending)   -> 'aa11bb22cc';
encode_status(active)    -> 'dd33ee44ff';
encode_status(cancelled) -> '99887766aa'.

decode_status('aa11bb22cc') -> pending;
decode_status('dd33ee44ff') -> active;
decode_status('99887766aa') -> cancelled.
```

For N-arity variants of a sum type, the umbrella transformer has one clause per variant:

```erlang
encode_item_error({not_found, Id}) ->
    {'<not_found_hash>', Id};
encode_item_error({invalid_state, Reason}) ->
    {'<invalid_state_hash>', Reason}.

decode_item_error({'<not_found_hash>', Id}) ->
    {not_found, Id};
decode_item_error({'<invalid_state_hash>', Reason}) ->
    {invalid_state, Reason}.
```

Single-constructor record types can be implemented as a one-clause umbrella (`encode_discount/1`) that emits the constructor hash directly. The important rule: generated field code always calls the transformer for the declared parent type, and the parent transformer chooses the right variant atom.

#### Where transformers are called from

The wire boundary is the dispatcher. Inbound: `libero_wire_ffi:decode_call/1` returns the raw decoded ETF term; the dispatch layer (`generated/<consumer>_dispatch.erl`) pattern-matches the request envelope (a hashed atom), calls the appropriate parent transformer to convert wire-shape arguments into BEAM-shape, then invokes the user handler. Outbound: the user handler returns BEAM-shape values; the dispatch layer calls the matching parent transformer, then `libero_ffi:encode/1` converts the resulting BEAM term to ETF bytes.

Pseudo-code for the dispatch layer:

```erlang
%% generated/admin_dispatch.erl (sketch). Generated hash atoms are quoted.
dispatch({'7c3e2a1b09'}, Context) ->
    %% server_load_discounts: 0-arity request, no decode needed
    Result = handler:server_load_discounts(Context),
    case Result of
        {ok, AdminData} -> libero_ffi:encode({ok, encode_discount_admin_data(AdminData)});
        {error, Msg}    -> libero_ffi:encode({error, Msg})
    end;

dispatch({'aabbccddee', ParamsWire}, Context) ->
    %% server_update_discount: decode the params wire shape, then call handler
    Params = decode_discount_params(ParamsWire),
    Result = handler:server_update_discount(Params, Context),
    case Result of
        {ok, Discount} -> libero_ffi:encode({ok, encode_discount(Discount)});
        {error, Err}   -> libero_ffi:encode({error, encode_item_error(Err)})
    end.
```

Result wrapping (`{ok, _}` / `{error, _}`) uses framework atoms unchanged.

#### What's removed

| File                                          | Removal                                                                                                     |
|-----------------------------------------------|-------------------------------------------------------------------------------------------------------------|
| `libero/src/libero_ffi.erl`                   | `qualify_atoms/1` and all clauses (lines 17, 21-54).                                                        |
| `libero/src/libero_ffi.erl`                   | The `qualify_atoms` step in `encode/1` (line 18). `encode/1` becomes `term_to_binary(Term)`.                |
| Generated `<consumer>_rpc_atoms.erl`          | The `AtomMap` build (lines 1064 and surrounding) and `persistent_term:put({libero, atom_map}, ...)` line.    |
| Generated `<consumer>_rpc_atoms.erl`          | The qualified-atom comment in the file header.                                                              |

#### What stays

- `libero_ffi:try_call/1` (panic catching, unrelated).
- `libero_ffi:decode/1`, `libero_ffi:decode_safe/1`, `libero_ffi:decode_typed/2` (still use `[safe]`).
- `libero_wire_ffi:decode_call/1` (unchanged in shape).
- Phase 1 of `do_ensure/0` in generated rpc_atoms (atom pre-registration for `[safe]`). The atom UNIVERSE changes (now hashed atoms instead of module-path atoms), but the registration mechanism is the same.
- All security work per the related beans.

### JS side

#### Per-class `__wireAtom` and `__fieldTypes` statics

Each generated class self-identifies via static fields:

```js
// generated/admin_pages_registration_discounts.mjs (sketch)
import { CustomType } from "../gleam.mjs";

export class Discount extends CustomType {
  static __wireAtom = "a3b9c2d1ee";
  static __fieldTypes = [null, null, { kind: "option", inner: null }, "float", null, null];

  constructor(id, name_en, name_fr, percent, fixed_amount_cents, enabled) {
    super();
    this.id = id;
    this.name_en = name_en;
    this.name_fr = name_fr;
    this.percent = percent;
    this.fixed_amount_cents = fixed_amount_cents;
    this.enabled = enabled;
  }
}
```

The `__wireAtom` replaces `_bareToQualifiedAtom` lookup. The `__fieldTypes` replaces `fieldTypeRegistry` lookup. Both are inert data attached directly to the constructor function.

#### Encoder (replaces `rpc_ffi.mjs` lines 802-829)

```js
// Gleam custom type instance
if (value instanceof CustomType) {
  const wireAtom = value.constructor.__wireAtom
    ?? snakeCase(value.constructor.name); // fallback for framework types
  const fieldTypes = value.constructor.__fieldTypes ?? [];
  const keys = Object.keys(value);
  if (keys.length === 0) {
    this.writeAtom(wireAtom);
  } else {
    const arity = keys.length + 1;
    if (arity <= 255) {
      this.writeUint8(104);
      this.writeUint8(arity);
    } else {
      this.writeUint8(105);
      this.writeUint32(arity);
    }
    this.writeAtom(wireAtom);
    keys.forEach((k, i) => {
      const fieldValue = value[k];
      const hintedField = hintForConstructorField(wireAtom, i, typeHint)
        ?? fieldTypes[i];
      this.encodeTerm(fieldValue, hintedField);
    });
  }
  return;
}
```

#### toRawShape (replaces `rpc_ffi.mjs` lines 990-996)

```js
if (value instanceof CustomType) {
  const wireAtom = value.constructor.__wireAtom
    ?? snakeCase(value.constructor.name);
  const keys = Object.keys(value);
  if (keys.length === 0) return wireAtom;
  return [wireAtom, ...keys.map(k => toRawShape(value[k]))];
}
```

The fallback to `snakeCase(value.constructor.name)` exists for framework types (`Some`, `None`, `Ok`, `ResultError`, `Empty`, `NonEmpty`) which don't have `__wireAtom` because their wire form is the literal framework atom (handled by the special-case branches earlier in `decodeTuple`).

#### Decoder body shape (unchanged)

Decoders today already check `term[0]` against the expected wire atom. Under the new scheme, that expected atom is the hash. The shape of decoder bodies is unchanged:

```js
export function decode_a3b9c2d1ee(term) {
  if (!Array.isArray(term) || term[0] !== "a3b9c2d1ee") {
    throw new DecodeError(
      "expected a3b9c2d1ee (Discount @ admin/pages/registration/discounts), got " +
        (Array.isArray(term) ? term[0] : typeof term)
    );
  }
  return new Discount(
    decode_int(term[1]),
    decode_string(term[2]),
    decode_option_of((t0) => decode_string(t0), term[3]),
    decode_float(term[4]),
    decode_int(term[5]),
    decode_bool(term[6])
  );
}
```

Error messages include both the hash and the source-level location, baked in at codegen time.

#### Atom-to-decoder registry

`registerAtomDecoder` keeps its purpose (mapping an incoming atom name to its typed decoder for the two-pass decode path) but loses the `bareName` parameter:

```js
// before
export function registerAtomDecoder(atomName, decoderName, decoderFn, bareName) { ... }

// after
export function registerAtomDecoder(atomName, decoderName, decoderFn) {
  registerTypedDecoder(decoderName, decoderFn);
  _atomToDecoderName.set(atomName, decoderName);
}
```

#### What's removed

| File                                       | Removal                                                                       |
|--------------------------------------------|-------------------------------------------------------------------------------|
| `libero/src/libero/rpc_ffi.mjs`            | `_bareToQualifiedAtom` map (line 77).                                         |
| `libero/src/libero/rpc_ffi.mjs`            | The `bareName` parameter and its body in `registerAtomDecoder` (lines 79-85). |
| `libero/src/libero/rpc_ffi.mjs`            | `fieldTypeRegistry` map (the `Map<string, any[]>` at line ~159).              |
| `libero/src/libero/rpc_ffi.mjs`            | `registerFieldTypes` export.                                                  |
| Generated `codec_ffi.mjs`                  | All `registerFieldTypes(...)` lines.                                          |
| Generated `codec_ffi.mjs`                  | `bareName` argument in `registerAtomDecoder(...)` lines.                      |
| Generated `codec_ffi.mjs`                  | The `import { ..., registerFieldTypes }` line.                                |

#### What stays

- `_typedDecoderRegistry` (still maps decoder name to function).
- `_atomToDecoderName` (still maps wire atom to decoder name; key is now the hash directly).
- `toRawShape` framework-constructor branches (Some, None, Ok, ResultError, Empty, NonEmpty, Dict).
- The ETF binary encode/decode primitives.
- The decoder body shape (compares against hashed atoms).
- The `lookupAtomDecoder` export.

### User code

Zero changes. The user-facing Gleam type definitions stay exactly as today:

```gleam
// admin/pages/registration/discounts.gleam (user-written, unchanged)
pub type Discount {
  Discount(id: Int, name_en: String, /* ... */)
}

pub type DiscountAdminData {
  DiscountAdminData(discounts: List(Discount))
}
```

The codegen-emitted transformer functions handle translation between user shape and wire shape. Pattern matching, construction, and field access work exactly as today. Compile error messages reference the user's own type, not the hashed wire form, because the user's type is what the compiler sees.

### Codegen uniqueness enforcement

The codegen-level check is the sole enforcement mechanism. After hashes are computed for every type in the consumer's type table, the codegen walks the result and looks for any two distinct canonical signatures that produced the same hash. If found, halt with a domain-level error:

```
Error: type identity hash collision (extremely rare birthday collision)
  Type A: Discount @ admin/pages/registration/discounts
    canonical: admin/pages/registration/discounts|Discount|int,string,option<string>,float,int,bool
  Type B: Promo @ admin/pages/registration/promos
    canonical: admin/pages/registration/promos|Promo|int,string,bool,bool,float,bool
  Both hash to: a3b9c2d1ee
  Action: rebuild with a different hash function (this should not happen
  in practice; please file a libero issue with the canonical signatures
  above so we can adjust the algorithm).
```

Since canonical signatures include module path AND constructor name AND field types, the only way to collide is a true hash birthday collision between distinct signatures. With 40-bit truncated SHA-256, this requires roughly a million distinct types in one consumer. Our universe never reaches that scale, but the check is cheap and catches the impossible-but-not-quite case.

There is no compiler-level fallback. Function-name uniqueness in the generated Erlang and JS modules is incidental; we do not rely on it as a safety mechanism. The codegen check fires before emission, and tests cover it explicitly (see [Test plan](#test-plan)).

### Edge cases

#### Framework atoms

Atoms `some`, `none`, `ok`, `error`, `nil`, `true`, `false`, and the empty list `[]` are handled by libero's framework constructor reconstruction (currently `rpc_ffi.mjs:506-526`). These are not user types; they have no per-type transformer and no `__wireAtom` field. The encode/decode path for framework atoms is unchanged; transformers pass them through.

User 0-arity variants DO get hashed: wire form is the variant's own hash, e.g., `aa11bb22cc` for `Pending`.

#### Generic types

Container types (`List(T)`, `Option(T)`, `Result(T, E)`, `Dict(K, V)`) are not generated per-instantiation. The codegen inlines the inner-type call at the use site:

```erlang
%% Field of type List(Discount), inlined at the use site
[encode_discount(X) || X <- Discounts]
```

For `Result(Discount, ItemError)`:

```erlang
case V of
    {ok, X}    -> {ok, encode_discount(X)};
    {error, E} -> {error, encode_item_error(E)}
end
```

For `Option(Discount)`:

```erlang
case V of
    {some, X} -> {some, encode_discount(X)};
    none      -> none
end
```

#### Dict(K, V)

Map keys must be simple scalar primitives: `int`, `string`, or `bool`. `float`, `bit_array`, user-typed keys, tuples, containers, and all other compound key types are rejected at codegen time with a clear error:

```
Error: unsupported Dict key type
  Field `<field>` of type `<TypeName>` declares Dict(<UnsupportedKey>, <ValueType>)
  but only Int, String, and Bool are allowed as Dict keys on the wire.
  Action: use Int/String/Bool keys, or restructure the data as
  List(#(UnsupportedKey, ValueType)) and convert at the application boundary.
```

For `Dict(String, Discount)` (primitive key), the codegen inlines:

```erlang
maps:map(fun(_K, X) -> encode_discount(X) end, V)
```

For `Dict(Int, Float)`, the value side still receives float handling:

```erlang
maps:map(fun(_K, X) -> encode_float(X) end, V)
```

Keys themselves pass through unchanged because the allowed key types are already unambiguous on both sides. In particular, Float keys are rejected so JS never has to decide whether a numeric key like `2` means Int or Float. BitArray keys are rejected because JS map-key equality and binary identity would make the wire contract harder to reason about. The corresponding JS side applies the same rule: primitive keys pass through, values recurse through the normal encoder hint/transformer path.

Rationale for rejecting user-typed keys: hashable identity for a custom type is poorly defined in JS (constructor + field values), the wire would need to round-trip both keys and values through transformers, and no real v3 use case requires it. Catching this at codegen with a helpful error is cleaner than trying to support it.

#### Two types with same shape, different name

`Discount(id: Int)` and `Promo(id: Int)` produce different canonical signatures (different constructor names) and therefore different hashes. No collision.

#### Two types with same shape, same name, different modules

`Discount(id: Int)` in module A and `Discount(id: Int)` in module B produce different canonical signatures (different module paths) and therefore different hashes. No collision. This is the case that motivated the spec; it now works correctly without intervention.

If the developer actually wants the two types to share a wire identity (because they semantically represent the same thing), they should extract a shared type into a common module and import it from both places. The wire identity will then be the shared type's hash, and codegen does not have to know about the previous duplication.

#### Recursive types

Self-referential types like `Tree` work without special handling because user-type references in the canonical signature are textual `<type:...>` references, not transitive hashes.

Example:

```gleam
pub type Tree {
  Leaf(value: Int)
  Node(value: Int, left: Tree, right: Tree)
}
```

`Tree`'s recursive constructor signature in module `m`:

```
m|Node|int,<type:m|Tree>,<type:m|Tree>
```

No cycle in hash computation. The hash of `Node` depends only on `Node`'s own fields, plus textual references to the parent type identity where recursive fields appear. Computing it requires no other hashes.

#### Mutually recursive types

```gleam
pub type A {
  A(b: B)
  AEnd
}

pub type B {
  B(a: A)
  BEnd
}
```

Both types can be hashed independently:

```
m|A|<type:m|B>
m|AEnd|
m|B|<type:m|A>
m|BEnd|
```

A's hash depends on the textual reference `<type:m|B>` rather than B's hash. B's hash depends on the textual reference `<type:m|A>` rather than A's hash. This avoids iteration, fixed-point search, and SCC analysis.

The codegen emits `encode_a/1` and `encode_b/1` parent transformers as ordinary recursive Erlang functions; the BEAM resolves the cross-references at module load time. Same on the JS side. The terminating variants make finite round-trip fixtures possible.

#### Cross-module shared types

If `shared/types.gleam` defines `Item` and both `pages/foo.gleam` and `pages/bar.gleam` use it in their wire types, the codegen emits one parent transformer pair for `Item` shared by both call sites. Standard codegen deduplication.

#### Large records

A 50-field record produces a 50-line transformer body in Erlang and a 50-call expression list in JS. No correctness concern. If readability becomes an issue, the codegen can break the function across multiple clauses or use record syntax.

#### Phantom-typed and zero-field records

A record with zero fields (`pub type Tag { Tag }`) is treated as a 0-arity variant: wire is the hashed atom. Field count zero in the canonical signature.

A record with phantom type parameters (`pub type Box(a) { Box(value: Int) }` where `a` is unused at runtime) hashes as if `a` did not exist. The phantom is a Gleam-level concept invisible to wire serialization.

## Why this over alternatives

### Runtime qualification with hash-based atoms (incremental fix)

Considered. Same architecture as today, just with hashed wire atoms instead of module-path atoms. Still has the global lookup tables; still has the bug class. Marginally better only because hashes are shorter than module paths. Not worth the rewrite if we're rewriting anyway.

### Schema-first Gleam (libero owns types, users import them)

Considered. Aliased imports keep construction and pattern-match syntax clean, but compile error messages and IDE hover leak the hashed constructor name into user-visible places. Hard requirement: user code stays clean. Rejected.

### Different wire format (JSON, Protobuf, Avro, Cap'n Proto)

Considered. JSON has the same namespace problem for sum-type discriminators; the workaround would be the same shape. Protobuf, Avro, and Cap'n Proto all push toward schema-first workflows, which we've rejected. ETF's BEAM-native efficiency and type fidelity (Float vs Int distinct, BitArray, atoms-as-variants) are real wins worth keeping. Rejected.

### Constructor-reference identity in JS

Considered. Use `value.constructor` itself as the registry key, since two `Discount` classes from two modules are distinct function objects in JS. Works on JS but creates an asymmetry with the BEAM side, where the equivalent does not exist. Symmetry is important for the audit story. Rejected in favor of `__wireAtom` static, which is conceptually similar but uses a stable string identifier on both sides.

### Structural-only hash (no module path)

Considered earlier in the design discussion. Two semantically-different types with the same shape would silently collide on the wire. The codegen-level uniqueness check would force a rename, which is correct in spirit but rejects valid patterns (two pages each defining their own `Discount` type whose fields happen to align). Including module path in the canonical signature is the better choice: every type is uniquely identified by source, codegen has nothing to reject, and developers are not forced into shared-type extractions they didn't want. Rejected in favor of source-identity hashing.

## File-by-file change inventory

### libero (Erlang/Gleam)

| File                                            | Change                                                                                                                                                                          |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `src/libero_ffi.erl`                            | Delete `qualify_atoms/1` (lines 21-54). Update `encode/1` to call `term_to_binary/1` directly (line 18). Drop `qualify_atoms/1` from any internal references.                  |
| `src/libero/codegen.gleam` (or new `wire_identity.gleam`) | Add `wire_hash/1`, `canonical_signature/1`, `wire_identity/1`, and `check_type_identity_uniqueness/1` (the codegen collision check).                                  |
| `src/libero/codegen_decoders.gleam`             | Substantial rewrite. Per-class `__wireAtom` and `__fieldTypes` statics emitted on each class. Drop `registerFieldTypes` calls. Drop `bareName` arg to `registerAtomDecoder`. Update decoder error messages to include source location.                                          |
| `src/libero/codegen_dispatch.gleam`             | Substantial rewrite. Drop AtomMap emission (lines 251-278). Emit per-type encode/decode transformer functions in `<consumer>_wire.erl`. Update dispatch case clauses to pattern-match on hashed atoms and call transformer functions on inbound args / outbound returns.        |
| `src/libero/wire.gleam`                         | Likely gains the public types describing wire identity (the hashed atom string, the canonical signature representation). Confirm during implementation.                          |
| `src/libero/field_type.gleam`                   | Add `to_canonical_token/1` that renders a `FieldType` to its canonical hash-basis token. Add a `dict_key_type_check/1` that rejects unsupported keys (anything except Int/String/Bool) with a typed error.        |
| `src/libero/rpc_ffi.mjs`                        | Delete `_bareToQualifiedAtom` (line 77) and its uses (lines 805, 992). Delete `fieldTypeRegistry` and `registerFieldTypes` (around line 159 and following). Update `registerAtomDecoder` signature (drop `bareName`). Update `toRawShape` and encoder to read `__wireAtom` and `__fieldTypes` from the constructor. |
| `src/libero/walker.gleam`                       | Confirm walker output includes module path for every type (it should already). Possibly gain a hash-precompute pass.                                                            |
| `src/libero/decoders_prelude.mjs`               | Likely no change. Confirm during implementation.                                                                                                                                |
| `src/libero_wire_ffi.erl`                       | No change.                                                                                                                                                                       |
| `src/libero/format.gleam`                       | If formatting helpers reference qualified-name conventions, update.                                                                                                              |
| `src/libero/error.gleam`                        | Add error variants: `TypeIdentityHashCollision` (codegen check) and `DictKeyMustBePrimitive` (Dict key check).                                                                  |
| `src/libero/gen_error.gleam`                    | Wire the new errors through the gen-error reporter.                                                                                                                              |
| `test/fixtures/wire_e2e/shared_src/shared/types.gleam.template`              | Add same-name-different-module fixture types. See [Test plan](#test-plan).                                                                            |
| `test/fixtures/wire_e2e/shared_src/shared/discount_collision.gleam.template` | New file with the second `Discount` type at different arity in a different module.                                                                                  |
| `test/fixtures/wire_e2e/server_src/server/handler.gleam.template`            | Add echo handlers for new fixture types.                                                                                                                                       |
| `test/js/wire_e2e_decode_manifest.escript`      | Add manifest entries for new fixtures.                                                                                                                                          |
| `test/js/wire_e2e_decode_typed_test.mjs`        | Add assertions for the new fixtures.                                                                                                                                            |
| `test/js/wire_e2e_dispatch_test.mjs`            | Add dispatch round-trip assertions for the new fixtures.                                                                                                                         |
| `test/js/wire_e2e_encode_test.mjs`              | Add encode-side assertions (Float-as-Int regression coverage).                                                                                                                   |
| `test/walker/...` (codegen unit tests)          | New tests: hash determinism, hash sensitivity, codegen collision detection (forced via mock hash function), Dict-key rejection, recursive type signatures.                       |

### rally (consumer of libero codegen)

| File                                            | Change                                                                                                                                                                          |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `<rally codegen entry points>`                  | Confirm that rally invokes libero codegen with the same inputs as before. The output now includes per-type transformer Erlang/JS functions; rally only needs to ensure those files reach the consumer build path. Probably no functional change.   |
| `<rally test fixtures>`                         | Confirm rally tests still pass against the new wire format. May need to update any rally test fixtures that bake in qualified atom strings.                                     |

### v3 (smoke target)

| File                                            | Change                                                                                                                                                                          |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `src/admin/pages/**/*.gleam`                    | NO user-code change. Page modules with same-name types continue to work because both sides of the wire use hashed atoms.                                                         |
| `src/generated@admin@rpc_atoms.erl`             | Regenerated by `bin/regen`. Phase 1 atom list contains hashed atoms; Phase 2 (AtomMap) is gone.                                                                                  |
| `.generated_client/admin/src/generated/codec_ffi.mjs` | Regenerated. `registerFieldTypes` calls gone. `__wireAtom` and `__fieldTypes` baked onto each class. `registerAtomDecoder` calls have no `bareName` argument.            |
| All other generated files                       | Regenerated by `bin/regen`. No human editing.                                                                                                                                   |

## Codegen API changes

### `libero/src/libero/codegen.gleam` (or new `wire_identity.gleam`)

```gleam
/// Compute the wire identity for a user type.
///
/// Returns a tuple #(canonical_signature, hash).
/// - canonical_signature: the source-identity string used as hash input
/// - hash: 10 lowercase hex chars (e.g. "a3b9c2d1ee")
pub fn wire_identity(constructor: ConstructorInfo) -> #(String, String)

/// Compute the canonical signature string used as the hash input.
/// Format: <module_path>|<constructor_name>|<field_types>
/// Exposed for testing.
pub fn canonical_signature(constructor: ConstructorInfo) -> String

/// Compute the wire hash for an arbitrary canonical signature.
/// Exposed for testing and for codegen direct use.
pub fn wire_hash(signature: String) -> String

/// Walk the type table and detect identity hash collisions.
/// Returns Ok(Nil) if no collisions, Error(Conflict) otherwise.
/// Conflict carries both canonical signatures and the colliding hash.
pub fn check_type_identity_uniqueness(
  types: List(ConstructorInfo)
) -> Result(Nil, IdentityConflict)
```

### `libero/src/libero/codegen_dispatch.gleam`

```gleam
/// Emit per-type Erlang encode/decode transformer functions for a consumer.
/// Returns the Erlang source for one wire transformers module.
pub fn emit_wire_transformers(types: List(ConstructorInfo)) -> String
```

Modify `emit_dispatch` (existing function) to:
- Drop AtomMap emission (lines 251-278).
- Emit hashed atoms in the case-clause patterns for inbound calls.
- Insert calls to the generated parent transformers in the dispatch clauses.

### `libero/src/libero/codegen_decoders.gleam`

Modify `emit_decoder_for_type` (or equivalent) to:
- Emit `static __wireAtom = "<hash>";` on each generated class.
- Emit `static __fieldTypes = [...];` on each generated class.
- Drop `registerFieldTypes(...)` emission entirely.
- Drop the `bareName` argument when emitting `registerAtomDecoder(...)`.
- Update decoder body error messages to include source-level location.

### `libero/src/libero/wire.gleam`

May gain types for representing wire identity and the canonical signature. Confirm during implementation; could also live in a new `wire_identity.gleam`.

### `libero/src/libero/field_type.gleam`

```gleam
/// Render a FieldType to its canonical hash-basis token.
pub fn to_canonical_token(t: FieldType) -> String

/// Validate that a Dict's key type is supported on the wire.
/// Returns Ok(Nil) for Int/String/Bool keys,
/// Error(DictKeyMustBePrimitive) for Float, BitArray, user-typed,
/// container, tuple, or other compound keys.
pub fn validate_dict_key(key_type: FieldType) -> Result(Nil, DictKeyError)
```

### `libero/src/libero/error.gleam`

```gleam
pub type LiberoError {
  // ... existing variants ...
  TypeIdentityHashCollision(
    hash: String,
    canonical_a: String,
    canonical_b: String,
  )
  DictKeyMustBePrimitive(
    field_path: String,
    key_type: FieldType,
  )
}
```

Wire both through `gen_error.gleam` for user-facing reporting.

## Hash function reference implementations

### Erlang (used at codegen time, not at runtime)

```erlang
%% Compute the 10-char hex wire-identity hash for a canonical signature.
%% Uses crypto:hash/2 which is in OTP since R16. Truncate to 5 bytes (40 bits).
wire_hash(Signature) when is_binary(Signature) ->
    <<Truncated:5/binary, _/binary>> = crypto:hash(sha256, Signature),
    binary:encode_hex(Truncated, lowercase).

%% Example:
%% wire_hash(<<"admin/pages/registration/discounts|Discount|int,string,option<string>,float,int,bool">>)
%%   -> <<"a3b9c2d1ee">>
```

### Gleam (codegen module helper)

```gleam
import gleam/crypto
import gleam/bit_array
import gleam/string
import gleam/result

pub fn wire_hash(signature: String) -> String {
  signature
  |> bit_array.from_string
  |> crypto.hash(crypto.Sha256, _)
  |> bit_array.slice(0, 5)
  |> result.unwrap(<<>>)
  |> bit_array.base16_encode
  |> string.lowercase
}
```

The exact API of `gleam_crypto` may differ slightly; confirm during implementation.

### JS (not used)

The JS side does not compute hashes. The codegen bakes hashes into the generated JS source. JS only ever compares strings.

## Implementation: lockstep cutover

This is a breaking change that lands as one logical unit. There are no preserved intermediate states. After libero ships, every consumer must `bin/regen` immediately.

The work is sequenced for the implementer's sanity, but everything lands together. Mixed states (libero with new codegen but a consumer with stale generated output) are explicitly unsupported and produce broken builds; this is expected and fine, because we control all consumers.

### Recommended order of work within the cutover

1. **Hash + canonical signature primitives.** Add `wire_hash`, `canonical_signature`, `wire_identity` in libero. Unit-test deterministically.
2. **Codegen-level uniqueness check.** Add `check_type_identity_uniqueness`. Unit-test the collision path with a mocked hash function.
3. **Per-type Erlang transformers.** Add `emit_wire_transformers` in codegen_dispatch. Snapshot-test the generated Erlang source for representative types (single-variant record, sum type with umbrella parent transformer, generic container, recursive type, mutual recursion).
4. **Per-class JS statics.** Update `codegen_decoders` to emit `__wireAtom` and `__fieldTypes` on each class. Drop `registerFieldTypes` and `bareName` arg from generated output.
5. **Hashed atoms in dispatch and decoder bodies.** Update `codegen_dispatch` to use hashed atoms in case clauses; update `codegen_decoders` to use hashed atoms in decoder body comparisons.
6. **Dispatch wiring uses transformers.** Update dispatch case clauses to call the generated parent transformers (`decode_discount_params`, `encode_discount`, `encode_item_error`, etc.) on inbound args and outbound returns. Drop AtomMap emission.
7. **JS runtime cleanup.** Drop `_bareToQualifiedAtom`, `fieldTypeRegistry`, `registerFieldTypes` from `rpc_ffi.mjs`. Update encoder and `toRawShape` to read `__wireAtom` and `__fieldTypes` from constructors. Drop `bareName` from `registerAtomDecoder` signature.
8. **Erlang runtime cleanup.** Drop `qualify_atoms/1` from `libero_ffi.erl`. Simplify `encode/1` to call `term_to_binary/1` directly.
9. **Same-name collision E2E fixture.** Add the wire_e2e fixture from the test plan.
10. **libero `gleam test`, `gleam run -m glinter` pass.** Verify libero is fully clean. (libero has no `bin/` scripts; v3 does.)
11. **v3 cutover.** In v3: `bin/regen`, `bin/dev`, smoke test admin SPA. Verify originally-failing `/admin/registration/discounts` loads. Walk all admin pages.

Steps 1-10 land in one libero PR. Step 11 is the v3-side action that runs immediately after libero is merged or pulled. There is no half-state where libero is "done" but v3 has not regenerated; v3 regenerates as part of the same change set.

## Test plan

### Test 1: codegen hash determinism

For a fixed canonical signature, `wire_hash` returns the same 10 hex chars on every invocation. Across two clean builds, the same type produces the same hash.

### Test 2: codegen hash sensitivity

Adding a field, removing a field, reordering fields, or changing a field type produces a different hash. Renaming a field (without changing types) produces the same hash. Moving a type from one module to another produces a different hash (because module path is in the canonical signature).

### Test 3: codegen collision detection

A unit test that mocks the hash function to return a fixed value for two distinct canonical signatures. `check_type_identity_uniqueness` returns `Error(TypeIdentityHashCollision)` with both canonical signatures named.

(We mock the hash function because real SHA-256 collisions at 40 bits are computationally infeasible to construct in a test. The mock proves the check works; the real hash function provides the resistance.)

### Test 4: same-name-different-module wire E2E

Two `Discount` types in two modules at different arities. Each gets a different hash (different module paths in canonical signature). Encode and decode round-trip both through the wire format, both end-to-end through dispatch, both match the original values.

### Test 5: envelope wrapping list of user type

`DiscountAdminData(discounts: List(Discount))` round-trips correctly with a non-empty list and an empty list. This is the originally-failing case from `libero-ljv6`.

### Test 6: float field encoding

A whole-number Float field (`percent: 2.0`) round-trips as a float, not an int. This is the regression for `libero-3ccw`. The new `encode_float/1` helper guarantees this without any registry lookup.

### Test 7: 0-arity variant identity

`Status::Pending` round-trips as the hashed atom for that variant. Two modules each defining `Pending` produce different hashes (different module paths).

### Test 8: recursive type round-trip

`Tree` with terminating `Leaf` and recursive `Node(value: Int, left: Tree, right: Tree)` variants round-trips a deeply-nested finite instance. Self-reference uses `<type:m|Tree>` in the canonical signature; the hash computes without iteration.

### Test 9: mutual recursion round-trip

Mutually recursive types with terminating variants (`A(b: B) | AEnd` and `B(a: A) | BEnd`) round-trip a finite value with at least 3 levels of cross-references. Both hashes compute independently because each canonical signature uses textual `<type:...>` references.

### Test 10: Dict-key rejection

A type with `Dict(SomeUserType, String)`, `Dict(Float, String)`, or `Dict(BitArray, String)` causes the codegen to fail with `DictKeyMustBePrimitive`, naming the field path. A type with `Dict(String, SomeUserType)` (supported key, user-typed value) succeeds.

### Test 11: hostile-input fixtures (covered by `libero-quoj`)

The hostile-input fixtures from `libero-quoj` exercise the new wire format. No change in scope; the fixtures just run against new atoms. Confirm all fixtures still produce typed errors, not crashes.

### Test 12: v3 admin smoke

Full admin SPA walk: every top-level page loads without DecodeError. The originally-failing `/admin/registration/discounts` is the canonical case.

## Acceptance criteria

The work is complete when ALL of the following hold:

1. `git grep -i 'qualify_atoms' libero/src/` returns zero hits.
2. `git grep '_bareToQualifiedAtom\|fieldTypeRegistry\|registerFieldTypes' libero/src/` returns zero hits.
3. `git grep '_bareToQualifiedAtom\|fieldTypeRegistry' v3/.generated_client/` returns zero hits after `bin/regen`.
4. `gleam test` passes in libero (including new fixtures from Tests 1-11).
5. `gleam run -m glinter` reports no issues in libero.
6. `bin/dev` builds cleanly in v3.
7. v3 admin SPA loads `/admin/registration/discounts` without a DecodeError.
8. Smoke walk of v3 admin SPA produces no regressions on any other page.
9. `libero-ljv6` and `libero-3ccw` are closed (subsumed by this spec).
10. `libero-05zr` (threat model) gains a section explaining the namespace gap and the codegen-level workaround.
11. `libero-quoj` (hostile-input fixtures) is updated to exercise the new wire format.

## Risk and rollback

### Risks

| Risk                                                       | Likelihood | Mitigation                                                                                                |
|------------------------------------------------------------|------------|-----------------------------------------------------------------------------------------------------------|
| Hash collision between two distinct canonical signatures   | Vanishingly low | Codegen uniqueness check (Test 3) catches as a build error.                                          |
| Float field encoding regression (`libero-3ccw`)            | Low        | Test 6 is the explicit regression test.                                                                    |
| Nested list-of-records decode regression (`libero-ljv6`)   | Low        | Test 5 is the explicit regression test.                                                                    |
| Recursive type signature ill-formed                        | Low        | `<type:...>` reference scheme has no cycle; Tests 8 and 9 cover it.                                        |
| Mutual recursion misses a code path                        | Low        | Test 9 explicitly covers cross-module mutual recursion.                                                    |
| Hash function non-determinism                              | Low        | Test 1 (determinism).                                                                                      |
| v3 fails to build after libero merge                       | Medium     | Smoke test as Step 11 of cutover; revert libero PR if v3 cannot regenerate cleanly within the same session.|
| Codegen takes meaningfully longer due to per-type emission | Low        | Per-type transformer emission is linear in type count; should not measurably slow the build.               |

### Rollback strategy

Pre-launch: no production rollback to worry about.

If the libero PR breaks v3 in a way that cannot be resolved within the same session: `git revert` the libero PR. v3 returns to its previous state without changes. No data migration, no wire-format coordination, no consumer outreach. Run `bin/regen` and `bin/dev` in v3 to rebuild against the reverted libero.

There are no intermediate states to reason about, because the cutover is lockstep. If anything is wrong, the entire change set reverts as one.

## Security relationship

This work is independent of the security audit beans (`libero-flpl`, `libero-9ix9`, `libero-zgrp`, `libero-quoj`, `libero-05zr`). Specifically:

1. Atom pre-registration for `[safe]` is unchanged in shape. Phase 1 of `do_ensure/0` still emits the full atom universe; the universe is now hashed atoms instead of module-path atoms, but the registration mechanism is the same.
2. Resource caps (`libero-flpl`) apply equally to the new wire format. The walker that enforces caps does not care what atoms are inside.
3. Non-executable validator (`libero-zgrp`) applies equally.
4. Hostile-input fixtures (`libero-quoj`) need a small update to use new atoms but otherwise unchanged.
5. Threat-model documentation (`libero-05zr`) gains a section: "ETF lacks namespace support, which is bridged at codegen time via per-type transformers and content-addressed hashes derived from source identity (module path + constructor name + field types). The runtime carries no global lookup tables for type identity. The only attack surface for type confusion is the codegen itself, which we treat as trusted (it ships with the build)."

## Cross-references

### Beans subsumed by this spec (delete on approval)

- `libero-ljv6`. Qualified atom encoding for JS decoders. The bug it describes goes away when `_bareToQualifiedAtom` is deleted.
- `libero-3ccw`. JS float type hints after qualified atom change. The bug it describes goes away when `fieldTypeRegistry` is replaced with per-class `__fieldTypes`.

(Both already deleted prior to spec v2; listed here for historical context.)

### Beans related but independent (cross-reference this spec from their bodies)

- `libero-flpl`. Erlang-side resource caps.
- `libero-9ix9`. `[safe]` flag audit.
- `libero-zgrp`. Non-executable validator.
- `libero-quoj`. Hostile-input fixtures (small update during this spec's implementation).
- `libero-05zr`. Threat-model README (gains a namespace-gap section during this spec's implementation).

### Beans not related

- `libero-5xxh`. Harden JS ETF decoder map and bit-binary validation. Independent.
- `libero-c8hx`. Run all JS codec tests from the JS test runner. Independent.
- `libero-jw7p`. Wire E2E non-byte-aligned bit_array test case. Independent.

## Open questions

These can be resolved during implementation, not before approval. Surfacing them in the spec so they aren't forgotten.

1. **Static field name on JS classes.** Proposed: `__wireAtom` and `__fieldTypes` (double-underscore prefix to signal "framework, not user-accessible"). Other JS codegen ecosystems use `__type`, `__id`, `_typeId`. Confirm naming during implementation.

2. **Codegen output directory layout.** Per-type transformer functions go into one `<consumer>_wire.erl` per consumer module, OR one file per type. Single-file-per-module is cleaner; confirm during implementation.

3. **rally interaction.** Does rally codegen need any changes, or does it consume libero output transparently? Confirm during implementation. Most likely no functional change because rally already passes through libero output to the consumer build directory.

4. **Phase 1 atom-list size.** With hashed atoms, the pre-registration list grows by one entry per user type. Confirm the list stays under any practical atom-table-size concern (Erlang default is 1,048,576 atoms; we will be far below).

5. **Whether the codegen should emit a debug manifest file** mapping each hash back to its source-level type. Convenient for log analysis (greppable hash → source location). Recommended yes; could be a follow-up bean if not in initial cutover.

6. **Whether `__fieldTypes` should be replaced with field-shape information embedded in the encoder/decoder bodies directly.** The current design keeps it as a static array indexed by field position; an alternative is to fold the type information into the per-field encode/decode calls (no array). Both work; the array is simpler to debug. Confirm during implementation.

7. **0-arity variant codegen layout.** Use one umbrella function per parent type that case-clauses over all variants. Confirm exact emitted helper names during implementation, but do not make call sites choose variant-specific helpers.

8. **Function naming convention.** Parent transformer names must be unique within the wire transformers module and readable enough in generated stack traces. A module-path-prefixed internal name (`encode_admin_pages_registration_discounts__discount/1`) is verbose but clear; a short source-identity hash suffix (`encode_discount__k9x2/1`) is shorter. Confirm during implementation. Wire atoms remain the 10-char hashes either way.
