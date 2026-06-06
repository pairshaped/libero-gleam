import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const buildRoot = readFileSync("test/js/.wire_e2e_build_root", "utf8").trim();
const webRoot = join(buildRoot, "clients/web/build/dev/javascript");
const manifest = JSON.parse(
  readFileSync("test/js/.wire_e2e_decode_manifest.json", "utf8"),
);

const etfFfi = await import(
  pathToFileURL(join(webRoot, "libero/libero/etf/wire_ffi.mjs")).href
);
const liberoEtf = await import(
  pathToFileURL(join(webRoot, "web/generated/libero/etf.mjs")).href
);
liberoEtf.ensure();
const types = await import(
  pathToFileURL(join(webRoot, "shared/shared/types.mjs")).href
);
const collision = await import(
  pathToFileURL(join(webRoot, "shared/shared/collision.mjs")).href
);
const gleam = await import(pathToFileURL(join(webRoot, "gleam_stdlib/gleam.mjs")).href);
const option = await import(
  pathToFileURL(join(webRoot, "gleam_stdlib/gleam/option.mjs")).href
);
const dict = await import(
  pathToFileURL(join(webRoot, "gleam_stdlib/gleam/dict.mjs")).href
);

function decodeCase(name) {
  const bytes = Buffer.from(manifest[name], "base64");
  return etfFfi.decode_value(bytes);
}

function decodeCaseRawSuccess(name) {
  const raw = etfFfi.decode_value_raw(Buffer.from(manifest[name], "base64"));
  assert.equal(raw[0], "ok");
  assert.equal(raw[1][0], "ok");
  return raw[1][1];
}

function expectSuccess(data) {
  assert.ok(data instanceof gleam.Ok);
  const inner = data[0];
  assert.ok(inner instanceof gleam.Ok);
  return inner[0];
}

function expectDomainFailure(data) {
  assert.ok(data instanceof gleam.Ok);
  const inner = data[0];
  assert.ok(inner instanceof gleam.Error);
  return inner[0];
}

function listToArray(list) {
  return Array.from(list);
}

function bitArrayBytes(value) {
  if (value.rawBuffer instanceof Uint8Array) return [...value.rawBuffer];
  if (value.rawBuffer instanceof ArrayBuffer) return [...new Uint8Array(value.rawBuffer)];
  if (typeof value === "string") return [...value].map((ch) => ch.charCodeAt(0));
  throw new TypeError("expected BitArray rawBuffer");
}

function expectItem(item, expected) {
  assert.ok(item instanceof types.Item);
  assert.equal(item.id, expected.id);
  assert.equal(item.name, expected.name);
  assert.equal(item.price, expected.price);
  assert.equal(item.in_stock, expected.in_stock);
}

function expectValidationFailed(err) {
  assert.ok(err instanceof types.ValidationFailed);
  assert.equal(err.field, "name");
  assert.equal(err.reason, "required");
}

function dictGet(dictValue, key) {
  const result = dict.get(dictValue, key);
  assert.ok(result instanceof gleam.Ok);
  return result[0];
}

function expectDeepTree(tree) {
  assert.ok(tree instanceof types.Node);
  assert.equal(tree.value, 1);
  assert.ok(tree.left instanceof types.Node);
  assert.equal(tree.left.value, 2);
  assert.ok(tree.left.left instanceof types.Leaf);
  assert.ok(tree.left.right instanceof types.Leaf);
  assert.ok(tree.right instanceof types.Node);
  assert.equal(tree.right.value, 3);
  assert.ok(tree.right.right instanceof types.Node);
  assert.equal(tree.right.right.value, 4);
}

const item = { id: 7, name: "wrench", price: 12.5, in_stock: true };
const item2 = { id: 8, name: "bolt", price: 1.25, in_stock: false };

const cases = [
  ["echo_int/positive", (v) => assert.equal(v, 5)],
  ["echo_int/zero", (v) => assert.equal(v, 0)],
  ["echo_int/negative", (v) => assert.equal(v, -7)],
  ["echo_float/fractional", (v) => assert.equal(v, 3.5)],
  ["echo_float/negative", (v) => assert.equal(v, -1.5)],
  ["echo_float/whole", (v) => assert.equal(v, 2.0)],
  ["echo_string/ascii", (v) => assert.equal(v, "hello")],
  ["echo_string/empty", (v) => assert.equal(v, "")],
  ["echo_string/null_byte", (v) => assert.equal(v, "a\0b")],
  ["echo_string/utf8_cafe", (v) => assert.equal(v, "café")],
  ["echo_string/cjk", (v) => assert.equal(v, "漢字")],
  ["echo_bool/true", (v) => assert.equal(v, true)],
  ["echo_bool/false", (v) => assert.equal(v, false)],
  ["echo_unit/nil", (v) => assert.equal(v, undefined)],
  ["echo_list_int/many", (v) => assert.deepEqual(listToArray(v), [1, 2, 3])],
  ["echo_list_int/empty", (v) => assert.deepEqual(listToArray(v), [])],
  ["echo_list_int/single", (v) => assert.deepEqual(listToArray(v), [42])],
  ["echo_option_string/some", (v) => {
    assert.ok(v instanceof option.Some);
    assert.equal(v[0], "hello");
  }],
  ["echo_option_string/none", (v) => assert.ok(v instanceof option.None)],
  ["echo_result_int_string/ok", (v) => {
    assert.ok(v instanceof gleam.Ok);
    assert.equal(v[0], 7);
  }],
  ["echo_result_int_string/error", (v) => {
    assert.ok(v instanceof gleam.Error);
    assert.equal(v[0], "bad");
  }],
  ["echo_dict_string_int/pairs", (v) => {
    assert.equal(dictGet(v, "one"), 1);
    assert.equal(dictGet(v, "two"), 2);
  }],
  ["echo_dict_string_int/empty", (v) => {
    assert.equal(dict.size(v), 0);
  }],
  ["echo_tuple_int_string/pair", (v) => assert.deepEqual(v, [9, "nine"])],
  ["echo_status/active", (v) => assert.ok(v instanceof types.Active)],
  ["echo_status/pending", (v) => assert.ok(v instanceof types.Pending)],
  ["echo_status/cancelled", (v) => assert.ok(v instanceof types.Cancelled)],
  ["echo_item/basic", (v) => expectItem(v, item)],
  ["echo_tree/leaf", (v) => assert.ok(v instanceof types.Leaf)],
  ["echo_tree/deep", expectDeepTree],
  ["echo_tree/deep_left", (v) => {
    assert.ok(v instanceof types.Node);
    assert.equal(v.value, 1);
    assert.ok(v.left instanceof types.Node);
    assert.equal(v.left.value, 2);
    assert.ok(v.left.left instanceof types.Node);
    assert.equal(v.left.left.value, 3);
    assert.ok(v.left.right instanceof types.Leaf);
    assert.ok(v.right instanceof types.Leaf);
  }],
  ["echo_item_error/not_found", (v) => assert.ok(v instanceof types.NotFound)],
  ["echo_item_error/validation_failed", expectValidationFailed],
  ["echo_with_floats/whole", (v) => {
    assert.ok(v instanceof types.WithFloats);
    assert.equal(v.x, 2.0);
    assert.equal(v.y, 3.0);
    assert.equal(v.label, "whole");
  }],
  ["echo_list_of_items/many", (v) => {
    const values = listToArray(v);
    assert.equal(values.length, 2);
    expectItem(values[0], item);
    expectItem(values[1], item2);
  }],
  ["echo_option_item/some", (v) => {
    assert.ok(v instanceof option.Some);
    expectItem(v[0], item);
  }],
  ["echo_option_item/none", (v) => assert.ok(v instanceof option.None)],
  ["echo_dict_string_item/pairs", (v) => {
    expectItem(dictGet(v, "one"), item);
    expectItem(dictGet(v, "two"), item2);
  }],
  ["echo_dict_string_item/empty", (v) => {
    assert.equal(dict.size(v), 0);
  }],
  ["echo_nested_record/basic", (v) => {
    assert.ok(v instanceof types.NestedRecord);
    assert.equal(listToArray(v.items).length, 2);
    assert.ok(v.primary instanceof option.Some);
    expectItem(v.primary[0], item);
    const statuses = listToArray(v.statuses);
    assert.ok(statuses[0] instanceof types.Pending);
    assert.ok(statuses[1] instanceof types.Active);
    assert.ok(statuses[2] instanceof types.Cancelled);
    expectItem(dictGet(v.by_id, "one"), item);
  }],
  ["echo_types_tag/basic", (v) => {
    assert.ok(v instanceof types.Tag);
    assert.equal(v.label, "sale");
    assert.equal(v.color, "red");
  }],
  ["echo_collision_tag/basic", (v) => {
    assert.ok(v instanceof collision.Tag);
    assert.equal(v.label, "promo");
  }],
];

for (const [name, assertValue] of cases) {
  assertValue(expectSuccess(decodeCase(name)));
}

assert.deepEqual(bitArrayBytes(decodeCaseRawSuccess("echo_bit_array/bytes")), [
  1, 2, 3,
]);
assert.deepEqual(bitArrayBytes(decodeCaseRawSuccess("echo_bit_array/empty")), []);
assert.deepEqual(bitArrayBytes(decodeCaseRawSuccess("echo_bit_array/single")), [
  255,
]);

expectValidationFailed(
  expectDomainFailure(
    decodeCase("echo_typed_err/validation_failed"),
  ),
);

console.log(`wire e2e decode test passed (${cases.length + 1} cases)`);
