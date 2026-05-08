import { strict as assert } from "node:assert";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const buildRoot = readFileSync("test/js/.wire_e2e_build_root", "utf8").trim();
const webRoot = join(buildRoot, "clients/web/build/dev/javascript");

await import(pathToFileURL(join(webRoot, "web/generated/libero/rpc_decoders_ffi.mjs")).href);
const wire = await import(pathToFileURL(join(webRoot, "libero/libero/wire.mjs")).href);
const types = await import(pathToFileURL(join(webRoot, "shared/shared/types.mjs")).href);
const gleam = await import(pathToFileURL(join(webRoot, "gleam_stdlib/gleam.mjs")).href);
const option = await import(
  pathToFileURL(join(webRoot, "gleam_stdlib/gleam/option.mjs")).href
);
const dict = await import(
  pathToFileURL(join(webRoot, "gleam_stdlib/gleam/dict.mjs")).href
);

const item = new types.Item(7, "wrench", 12.5, true);
const wholeFloatItem = new types.Item(9, "floaty", 2.0, true);
const item2 = new types.Item(8, "bolt", 1.25, false);
const tree = new types.Node(
  1,
  new types.Leaf(),
  new types.Node(2, new types.Leaf(), new types.Leaf()),
);
const itemDict = dict.from_list(gleam.toList([
  ["one", item],
  ["two", wholeFloatItem],
]));
const intDict = dict.from_list(gleam.toList([
  ["one", 1],
  ["two", 2],
]));
const nested = new types.NestedRecord(
  gleam.toList([item, wholeFloatItem]),
  new option.Some(item2),
  gleam.toList([new types.Pending(), new types.Active(), new types.Cancelled()]),
  itemDict,
);

const cases = [
  ["int", 5, "5"],
  ["int_zero", 0, "0"],
  ["int_negative", -7, "-7"],
  ["float_fractional", 3.5, "3.5"],
  ["float_negative", -1.5, "-1.5"],
  ["string_ascii", "hello", "<<104,101,108,108,111>>"],
  ["string_empty", "", "<<>>"],
  ["string_null_byte", "a\0b", "<<97,0,98>>"],
  ["string_utf8", "caf\u00E9", "<<99,97,102,195,169>>"],
  ["string_cjk", "\u6F22\u5B57", "<<230,188,162,229,173,151>>"],
  ["bool_true", true, "true"],
  ["bool_false", false, "false"],
  ["bit_array", new gleam.BitArray(new Uint8Array([1, 2, 3])), "<<1,2,3>>"],
  ["bit_array_empty", new gleam.BitArray(new Uint8Array([])), "<<>>"],
  ["unit", undefined, "nil"],
  ["list_int", gleam.toList([1, 2, 3]), "[1,2,3]"],
  ["list_empty", gleam.toList([]), "[]"],
  ["option_some", new option.Some("hello"), "{some,<<104,101,108,108,111>>}"],
  ["option_none", new option.None(), "none"],
  ["result_ok", new gleam.Ok(7), "{ok,7}"],
  ["result_error", new gleam.Error("bad"), "{error,<<98,97,100>>}"],
  ["dict_string_int", intDict, "#{<<111,110,101>> => 1,<<116,119,111>> => 2}"],
  ["dict_empty", dict.from_list(gleam.toList([])), "#{}"],
  ["tuple_int_string", [9, "nine"], "{9,<<110,105,110,101>>}"],
  ["status_active", new types.Active(), "c9650d0ff8"],
  ["status_pending", new types.Pending(), "'0916eb3b7c'"],
  ["item", item, "{'0cf13587b9',7,<<119,114,101,110,99,104>>,12.5,true}"],
  ["item_whole_float", wholeFloatItem, "{'0cf13587b9',9,<<102,108,111,97,116,121>>,2.0,true}"],
  ["tree", tree, "{'864f4ce0ef',1,'125f56d540',{'864f4ce0ef',2,'125f56d540','125f56d540'}}"],
  [
    "item_error",
    new types.ValidationFailed("name", "required"),
    "{'565c7780c5',<<110,97,109,101>>,<<114,101,113,117,105,114,101,100>>}",
  ],
  ["item_error_not_found", new types.NotFound(), "a377d65821"],
  [
    "with_floats",
    new types.WithFloats(2.0, 3.0, "whole"),
    "{d66cac69c8,2.0,3.0,<<119,104,111,108,101>>}",
  ],
  [
    "list_of_items",
    gleam.toList([item, wholeFloatItem]),
    "[{'0cf13587b9',7,<<119,114,101,110,99,104>>,12.5,true},{'0cf13587b9',9,<<102,108,111,97,116,121>>,2.0,true}]",
  ],
  ["option_item", new option.Some(item), "{some,{'0cf13587b9',7,<<119,114,101,110,99,104>>,12.5,true}}"],
  [
    "dict_string_item",
    itemDict,
    "#{<<111,110,101>> => {'0cf13587b9',7,<<119,114,101,110,99,104>>,12.5,true},<<116,119,111>> => {'0cf13587b9',9,<<102,108,111,97,116,121>>,2.0,true}}",
  ],
  [
    "nested_record",
    nested,
    "{'985b6a7d71',[{'0cf13587b9',7,<<119,114,101,110,99,104>>,12.5,true},{'0cf13587b9',9,<<102,108,111,97,116,121>>,2.0,true}],{some,{'0cf13587b9',8,<<98,111,108,116>>,1.25,false}},['0916eb3b7c',c9650d0ff8,a28fb8d228],#{<<111,110,101>> => {'0cf13587b9',7,<<119,114,101,110,99,104>>,12.5,true},<<116,119,111>> => {'0cf13587b9',9,<<102,108,111,97,116,121>>,2.0,true}}}",
  ],
];

const erlangCases = cases.map(([name, msg]) => {
  const payload = wire.encode_call("rpc", 7, msg);
  return `{${JSON.stringify(name)},${JSON.stringify(Buffer.from(payload.rawBuffer).toString("base64"))}}`;
});
const printed = execFileSync(
  "erl",
  [
    "-noshell",
    "-eval",
    `Cases = [${erlangCases.join(",")}], lists:foreach(fun({Name, B64}) -> {Module, RequestId, Msg} = binary_to_term(base64:decode(B64)), io:format("~s|~w|~w|~w~n", [Name, Module, RequestId, Msg]) end, Cases), halt().`,
  ],
  { encoding: "utf8" },
);

const terms = new Map(
  printed.trim().split("\n").map((line) => {
    const [name, module, requestId, term] = line.split("|");
    return [name, { module, requestId, term }];
  }),
);

for (const [name, _msg, expected] of cases) {
  const actual = terms.get(name);
  assert.equal(actual.module, "<<114,112,99>>", `${name} module`);
  assert.equal(actual.requestId, "7", `${name} request id`);
  assert.equal(actual.term, expected, name);
}

console.log(`wire e2e encode test passed (${cases.length} cases)`);
