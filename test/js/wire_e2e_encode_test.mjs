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
  ["status_active", new types.Active(), "active"],
  ["status_pending", new types.Pending(), "pending"],
  ["item", item, "{item,7,<<119,114,101,110,99,104>>,12.5,true}"],
  ["item_whole_float", wholeFloatItem, "{item,9,<<102,108,111,97,116,121>>,2.0,true}"],
  ["tree", tree, "{node,1,leaf,{node,2,leaf,leaf}}"],
  [
    "item_error",
    new types.ValidationFailed("name", "required"),
    "{validation_failed,<<110,97,109,101>>,<<114,101,113,117,105,114,101,100>>}",
  ],
  ["item_error_not_found", new types.NotFound(), "not_found"],
  [
    "with_floats",
    new types.WithFloats(2.0, 3.0, "whole"),
    "{with_floats,2.0,3.0,<<119,104,111,108,101>>}",
  ],
  [
    "list_of_items",
    gleam.toList([item, wholeFloatItem]),
    "[{item,7,<<119,114,101,110,99,104>>,12.5,true},{item,9,<<102,108,111,97,116,121>>,2.0,true}]",
  ],
  ["option_item", new option.Some(item), "{some,{item,7,<<119,114,101,110,99,104>>,12.5,true}}"],
  [
    "dict_string_item",
    itemDict,
    "#{<<111,110,101>> => {item,7,<<119,114,101,110,99,104>>,12.5,true},<<116,119,111>> => {item,9,<<102,108,111,97,116,121>>,2.0,true}}",
  ],
  [
    "nested_record",
    nested,
    "{nested_record,[{item,7,<<119,114,101,110,99,104>>,12.5,true},{item,9,<<102,108,111,97,116,121>>,2.0,true}],{some,{item,8,<<98,111,108,116>>,1.25,false}},[pending,active,cancelled],#{<<111,110,101>> => {item,7,<<119,114,101,110,99,104>>,12.5,true},<<116,119,111>> => {item,9,<<102,108,111,97,116,121>>,2.0,true}}}",
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
