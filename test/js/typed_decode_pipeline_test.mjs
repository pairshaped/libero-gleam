// Tests that verify the typed ETF decode pipeline produces proper
// Gleam constructor instances (Ok, Error, custom types) rather than
// raw arrays with string atoms.
//
// There are two layers:
// 1. ETF decoder (etf/wire_ffi.mjs): decode_value (raw=false) now
//    reconstructs Ok, Error, Some, None inline in decodeTuple and
//    decodeAtom. decode_value_raw still returns raw arrays/strings.
// 2. Typed decoder prelude (decoders_prelude.mjs): decode_result_of,
//    decode_option_of, decode_list_of, etc. reconstruct custom types
//    from raw arrays. These are called by the generated codec_ffi.mjs
//    for ClientMsg variants, not by the ETF decoder directly.
//
// This test exercises the prelude layer (layer 2), which is still
// needed for custom type reconstruction. The ETF decoder layer
// (layer 1) handles framework types inline now.
//
// Run from the libero root:
//   node test/js/typed_decode_pipeline_test.mjs

import { strict as assert } from "assert";
import {
  decode_result_of,
  decode_option_of,
  decode_list_of,
  decode_tuple_of,
  setResultCtors,
  setOptionCtors,
  setListCtors,
  setDictFromList,
} from "../../src/libero/decoders_prelude.mjs";

// ---------- Minimal Gleam stdlib type stubs ----------
// These mirror the real constructors that gleam_stdlib registers.

class CustomType {}
class Some extends CustomType {
  constructor(value) {
    super();
    this[0] = value;
  }
}
class None extends CustomType {}
class Ok extends CustomType {
  constructor(value) {
    super();
    this[0] = value;
  }
}
class ResultError extends CustomType {
  constructor(value) {
    super();
    this[0] = value;
  }
}
class Empty extends CustomType {}
class NonEmpty extends CustomType {
  constructor(head, tail) {
    super();
    this.head = head;
    this.tail = tail;
  }
}

setOptionCtors(Some, None);
setResultCtors(Ok, ResultError);
setListCtors(Empty, NonEmpty);

// Mock dictFromList: converts a Gleam linked list of [k,v] pairs into a Map
function dictFromList(list) {
  const map = new Map();
  let cur = list;
  while (cur instanceof NonEmpty) {
    const pair = cur.head;
    let k, v;
    if (pair instanceof NonEmpty) {
      k = pair.head;
      const tail = pair.tail;
      if (tail instanceof NonEmpty) {
        v = tail.head;
      }
    }
    if (k !== undefined && v !== undefined) map.set(k, v);
    cur = cur.tail;
  }
  return map;
}
setDictFromList(dictFromList);

// ---------- Helpers for converting linked lists to arrays ----------

function listToArray(list) {
  const arr = [];
  let cur = list;
  while (cur instanceof NonEmpty) {
    arr.push(cur.head);
    cur = cur.tail;
  }
  return arr;
}

// ---------- Simulated raw ETF decode values ----------
// These are what decode_value_raw would return for common Gleam
// values. The typed decode pipeline (decoders_prelude.mjs functions)
// rebuilds proper constructor instances from these raw values.

// ---- Result (Ok/Error) ----

{
  // Raw decode_value_raw output for Ok(42):
  //   Gleam: Ok(42)
  //   ETF: {ok, 42}
  //   raw:  ["ok", 42]
  const rawOk = ["ok", 42];
  const decoded = decode_result_of(v => v, v => v, rawOk);
  assert.ok(decoded instanceof Ok, "Ok(42) should decode to Ok instance");
  assert.equal(decoded[0], 42, "Ok(42) inner value should be 42");
  console.log("PASS: Ok(42) raw → Ok instance");
}

{
  // Raw decode_value_raw output for Error(Nil):
  //   Gleam: Error(Nil)
  //   ETF: {error, nil}
  //   raw:  ["error", null]
  const rawError = ["error", null];
  const decoded = decode_result_of(v => v, v => v, rawError);
  assert.ok(decoded instanceof ResultError, "Error(Nil) should decode to Error instance");
  assert.equal(decoded[0], null, "Error(Nil) inner value should be null");
  console.log("PASS: Error(Nil) raw → Error instance");
}

{
  // Raw decode_value_raw output for Error("something"):
  //   Gleam: Error("something")
  //   ETF: {error, <<"something">>}
  //   raw:  ["error", "something"]
  const rawError = ["error", "something"];
  const decoded = decode_result_of(v => v, v => v, rawError);
  assert.ok(decoded instanceof ResultError, "Error(string) should decode to Error instance");
  assert.equal(decoded[0], "something");
  console.log("PASS: Error(string) raw → Error instance");
}

// ---- Option (Some/None) ----

{
  // Raw decode_value_raw output for Some(99):
  //   Gleam: Some(99)
  //   ETF: {some, 99}
  //   raw:  ["some", 99]
  const rawSome = ["some", 99];
  const decoded = decode_option_of(v => v, rawSome);
  assert.ok(decoded instanceof Some, "Some(99) should decode to Some instance");
  assert.equal(decoded[0], 99, "Some(99) inner value should be 99");
  console.log("PASS: Some(99) raw → Some instance");
}

{
  // Raw decode_value_raw output for None:
  //   Gleam: None
  //   ETF: none  (just the atom)
  //   raw:  "none"
  const rawNone = "none";
  const decoded = decode_option_of(v => v, rawNone);
  assert.ok(decoded instanceof None, "None should decode to None instance");
  console.log("PASS: None raw → None instance");
}

// ---- Tuple ----

{
  // Raw decode_value_raw output for #(1, "two"):
  //   Gleam: #(1, "two")
  //   ETF: {1, <<"two">>}
  //   raw:  [1, "two"]
  const rawTuple = [1, "two"];
  const decoded = decode_tuple_of([v => v, v => v], rawTuple);
  assert.ok(Array.isArray(decoded), "tuple should decode to array (Gleam tuples are JS arrays)");
  assert.equal(decoded.length, 2);
  assert.equal(decoded[0], 1);
  assert.equal(decoded[1], "two");
  console.log("PASS: #(1, \"two\") raw → tuple array");
}

// ---- List ----

{
  // Raw decode_value_raw output for [1, 2, 3]:
  //   Gleam: [1, 2, 3]
  //   ETF: cons cells {1, {2, {3, []}}}
  //   raw:  [1, 2, 3] — libero's raw ETF decoder flattens cons cells
  const rawList = [1, 2, 3];
  const decoded = decode_list_of(v => v, rawList);
  assert.ok(decoded instanceof NonEmpty, "non-empty list should decode to NonEmpty");
  const arr = listToArray(decoded);
  assert.deepEqual(arr, [1, 2, 3], "list values should be [1, 2, 3]");
  console.log("PASS: [1,2,3] raw → NonEmpty linked list");
}

{
  // Empty list
  const rawEmpty = [];
  const decoded = decode_list_of(v => v, rawEmpty);
  assert.ok(decoded instanceof Empty, "empty list should decode to Empty");
  console.log("PASS: [] raw → Empty");
}

// ---- The critical RPC response scenario ----
// When the server returns Ok([Sponsor(...), Sponsor(...)]), the client
// must rebuild an Ok instance wrapping a linked list of Sponsor instances.
// decode_value (typed) does this. decode_value_raw would produce the
// array ["ok", [...]] which fails Gleam pattern matching.

{
  // Simulate a custom type constructor (like Sponsor)
  class Sponsor extends CustomType {
    constructor(name, tier) {
      super();
      this.name = name;
      this.tier = tier;
      this[0] = name;
      this[1] = tier;
    }
  }

  // Simulate: server returns Ok([Sponsor("Acme", 1), Sponsor("Beta", 2)])
  // ETF encodes as: {ok, {{sponsor, <<"Acme">>, 1}, {{sponsor, <<"Beta">>, 2}, []}}}
  // decode_value_raw would produce:
  //   ["ok", [["sponsor", "Acme", 1], [["sponsor", "Beta", 2], []]]]
  // decode_value (typed) produces:
  //   Ok(NonEmpty(Sponsor("Acme", 1), NonEmpty(Sponsor("Beta", 2), Empty)))

  // Simulate raw decode (ETF cons cells flattened to JS array)
  const rawResponse = ["ok", [["sponsor", "Acme", 1], ["sponsor", "Beta", 2]]];

  // Without typed decode, this is just an array with string atoms:
  assert.ok(Array.isArray(rawResponse), "raw response is an array");
  assert.equal(rawResponse[0], "ok", "raw: first element is the string 'ok'");
  assert.ok(Array.isArray(rawResponse[1]), "raw: second element is an array (list)");
  // Pattern matching `case result { Ok(sponsors) -> ... }` would FAIL
  // because `result` is a plain array, not an Ok instance.

  // With typed decode (what decode_value produces):
  const decodeSponsor = raw => new Sponsor(raw[1], raw[2]);
  const decodeSponsorList = raw => decode_list_of(decodeSponsor, raw);
  const decodeResponse = raw => decode_result_of(decodeSponsorList, v => v, raw);

  const typed = decodeResponse(rawResponse);

  // Now Gleam pattern matching works:
  assert.ok(typed instanceof Ok, "typed: response is an Ok instance");
  const sponsors = typed[0]; // Ok's inner value
  assert.ok(sponsors instanceof NonEmpty, "typed: inner value is NonEmpty list");
  const arr = listToArray(sponsors);
  assert.equal(arr.length, 2, "typed: 2 sponsors");
  assert.ok(arr[0] instanceof Sponsor, "typed: first is Sponsor instance");
  assert.equal(arr[0].name, "Acme");
  assert.equal(arr[0].tier, 1);
  assert.ok(arr[1] instanceof Sponsor, "typed: second is Sponsor instance");
  assert.equal(arr[1].name, "Beta");
  assert.equal(arr[1].tier, 2);

  console.log("PASS: RPC response scenario — Ok([Sponsor, Sponsor])");
}

// ---- Verify raw values DON'T match Gleam patterns ----
// This is the bug we want to prevent: using decode_value_raw and
// then pattern matching on the result.

{
  const rawOk = ["ok", 42];
  // `case result { Ok(v) -> ... }` checks `result instanceof Ok`
  // which is FALSE for a plain array:
  assert.equal(rawOk instanceof Ok, false,
    "raw [\"ok\", 42] is NOT an Ok instance — Gleam pattern match would fail");
  console.log("PASS: raw [\"ok\", 42] is not instanceof Ok");
}

{
  const rawSome = ["some", "hello"];
  assert.equal(rawSome instanceof Some, false,
    "raw [\"some\", \"hello\"] is NOT a Some instance");
  console.log("PASS: raw [\"some\", \"hello\"] is not instanceof Some");
}

{
  const rawNone = "none";
  assert.equal(rawNone instanceof None, false,
    "raw \"none\" string is NOT a None instance");
  console.log("PASS: raw \"none\" is not instanceof None");
}

console.log("\nAll typed decode pipeline tests passed.");
console.log("Remember: use decode_value (typed) for RPC responses and push frames.");
console.log("Only use decode_value_raw when you plan to re-decode through typed decoders manually.");
