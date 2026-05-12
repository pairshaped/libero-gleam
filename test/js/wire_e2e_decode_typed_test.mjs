// Non-raw decode coverage. Mirrors wire_e2e_decode_test.mjs but uses
// etf/wire_ffi.decode_value (the production WebSocket path) instead of
// decode_value_raw. Production WebSocket frames take this code path,
// which interleaves atom→typed-decoder reconstruction with raw ETF
// decoding. The test below catches regressions where toRawShape, the
// reverse atom-name map, or any other step in the pipeline drops typed
// reconstruction for nested structures.
//
// Cases come from the same manifest as wire_e2e_decode_test so we
// keep one source of truth for fixture shapes.

import { strict as assert } from "node:assert";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const buildRoot = readFileSync("test/js/.wire_e2e_build_root", "utf8").trim();
const webRoot = join(buildRoot, "clients/web/build/dev/javascript");
const manifest = JSON.parse(
  readFileSync("test/js/.wire_e2e_decode_manifest.json", "utf8"),
);

const rpcFfi = await import(
  pathToFileURL(join(webRoot, "libero/libero/etf/wire_ffi.mjs")).href
);
// Importing the generated decoders has the side effect of calling
// registerAtomDecoder for every user type, populating the atom→decoder
// reverse map and the bare→qualified atom map that the encoder uses.
await import(
  pathToFileURL(join(webRoot, "web/generated/libero/rpc_decoders_ffi.mjs")).href
);
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

function decodeOk(name) {
  const bytes = Buffer.from(manifest[name], "base64");
  const decoded = rpcFfi.decode_value(bytes);
  // Wire shape is {ok, {ok, Value}}; outer Ok is the framework
  // "no transport error" envelope, inner Ok is the user handler's
  // success branch. Use array indexing rather than property names
  // because the Ok class instance keys vary by codegen.
  assert.ok(decoded instanceof gleam.Ok, `${name}: outer Ok`);
  const inner = decoded[0];
  assert.ok(inner instanceof gleam.Ok, `${name}: inner Ok`);
  return inner[0];
}

function decodeError(name) {
  const bytes = Buffer.from(manifest[name], "base64");
  const decoded = rpcFfi.decode_value(bytes);
  assert.ok(decoded instanceof gleam.Ok, `${name}: outer Ok`);
  const inner = decoded[0];
  assert.ok(inner instanceof gleam.Error, `${name}: inner Error`);
  return inner[0];
}

function listToArray(list) {
  const arr = [];
  let node = list;
  while (node && node.head !== undefined) {
    arr.push(node.head);
    node = node.tail;
  }
  return arr;
}

function dictGet(dictValue, key) {
  const result = dict.get(dictValue, key);
  assert.ok(result instanceof gleam.Ok, `dict.get(${key}) returned Error`);
  return result[0];
}

function expectItem(item, expected) {
  assert.ok(item instanceof types.Item, "expected Item instance");
  assert.equal(item.id, expected.id, "Item.id");
  assert.equal(item.name, expected.name, "Item.name");
  assert.equal(item.price, expected.price, "Item.price");
  assert.equal(item.in_stock, expected.in_stock, "Item.in_stock");
}

const item = { id: 7, name: "wrench", price: 12.5, in_stock: true };
const item2 = { id: 8, name: "bolt", price: 1.25, in_stock: false };

// ---------- Primitive payloads ----------

assert.equal(decodeOk("echo_int/positive"), 5);
assert.equal(decodeOk("echo_int/zero"), 0);
assert.equal(decodeOk("echo_int/negative"), -7);
assert.equal(decodeOk("echo_float/fractional"), 3.5);
assert.equal(decodeOk("echo_float/negative"), -1.5);
assert.equal(decodeOk("echo_float/whole"), 2.0);
assert.equal(decodeOk("echo_string/ascii"), "hello");
assert.equal(decodeOk("echo_string/empty"), "");
assert.equal(decodeOk("echo_string/utf8_cafe"), "café");
assert.equal(decodeOk("echo_bool/true"), true);
assert.equal(decodeOk("echo_bool/false"), false);
assert.equal(decodeOk("echo_unit/nil"), undefined);

// ---------- Container payloads ----------

assert.deepEqual(listToArray(decodeOk("echo_list_int/many")), [1, 2, 3]);
assert.deepEqual(listToArray(decodeOk("echo_list_int/empty")), []);
assert.deepEqual(listToArray(decodeOk("echo_list_int/single")), [42]);

{
  const v = decodeOk("echo_option_string/some");
  assert.ok(v instanceof option.Some, "Option.Some");
  assert.equal(v[0], "hello");
}
{
  const v = decodeOk("echo_option_string/none");
  assert.ok(v instanceof option.None, "Option.None");
}

// ---------- Enum and tagged-union ----------

assert.ok(decodeOk("echo_status/active") instanceof types.Active);
assert.ok(decodeOk("echo_status/pending") instanceof types.Pending);
assert.ok(decodeOk("echo_status/cancelled") instanceof types.Cancelled);

assert.ok(decodeOk("echo_tree/leaf") instanceof types.Leaf);
{
  const tree = decodeOk("echo_tree/deep");
  assert.ok(tree instanceof types.Node, "Tree.Node");
  assert.equal(tree.value, 1);
}

assert.ok(decodeOk("echo_item_error/not_found") instanceof types.NotFound);
{
  const err = decodeError("echo_typed_err/validation_failed");
  assert.ok(err instanceof types.ValidationFailed);
  assert.equal(err.field, "name");
  assert.equal(err.reason, "required");
}

// ---------- Records ----------

expectItem(decodeOk("echo_item/basic"), item);

{
  const v = decodeOk("echo_with_floats/whole");
  assert.ok(v instanceof types.WithFloats);
  assert.equal(v.x, 2.0);
  assert.equal(v.y, 3.0);
  assert.equal(v.label, "whole");
}

// List of records
{
  const items = listToArray(decodeOk("echo_list_of_items/many"));
  assert.equal(items.length, 2);
  expectItem(items[0], item);
  expectItem(items[1], item2);
}

// Option of record
{
  const v = decodeOk("echo_option_item/some");
  assert.ok(v instanceof option.Some);
  expectItem(v[0], item);
}
assert.ok(decodeOk("echo_option_item/none") instanceof option.None);

// Dict of record
{
  const d = decodeOk("echo_dict_string_item/pairs");
  expectItem(dictGet(d, "one"), item);
  expectItem(dictGet(d, "two"), item2);
}

// ---------- Composite / nested ----------

{
  const r = decodeOk("echo_nested_record/basic");
  assert.ok(r instanceof types.NestedRecord);
  const items = listToArray(r.items);
  assert.equal(items.length, 2);
  expectItem(items[0], item);
  expectItem(items[1], item2);
  assert.ok(r.primary instanceof option.Some);
  expectItem(r.primary[0], item);
  const statuses = listToArray(r.statuses);
  assert.ok(statuses[0] instanceof types.Pending);
  assert.ok(statuses[1] instanceof types.Active);
  assert.ok(statuses[2] instanceof types.Cancelled);
  expectItem(dictGet(r.by_id, "one"), item);
  expectItem(dictGet(r.by_id, "two"), item2);
}

// ---------- v3 envelope shapes ----------
// Each of these mirrors a real production page-data shape and would
// have caught the discounts/fees/transactional_emails class of bug.

// Single-list envelope (DiscountAdminData, FeeAdminData pattern)
{
  const r = decodeOk("echo_item_list_data/basic");
  assert.ok(r instanceof types.ItemListData);
  const items = listToArray(r.items);
  assert.equal(items.length, 2);
  expectItem(items[0], item);
  expectItem(items[1], item2);
}
{
  const r = decodeOk("echo_item_list_data/empty");
  assert.ok(r instanceof types.ItemListData);
  assert.equal(listToArray(r.items).length, 0);
}

// List + paged metadata (financial reports pattern)
{
  const r = decodeOk("echo_item_summary_data/basic");
  assert.ok(r instanceof types.ItemSummaryData);
  assert.equal(listToArray(r.items).length, 2);
  assert.equal(r.total, 100);
  assert.equal(r.page, 1);
}

// Form prefill: record with optional record + enum default (edit-page pattern)
{
  const r = decodeOk("echo_form_prefill/with_item");
  assert.ok(r instanceof types.FormPrefill);
  assert.ok(r.item instanceof option.Some);
  expectItem(r.item[0], item);
  assert.ok(r.default_status instanceof types.Active);
}
{
  const r = decodeOk("echo_form_prefill/without_item");
  assert.ok(r instanceof types.FormPrefill);
  assert.ok(r.item instanceof option.None);
  assert.ok(r.default_status instanceof types.Pending);
}

// Doubly-nested envelope (page wrapper around list-data wrapper)
{
  const r = decodeOk("echo_nested_envelope/with_message");
  assert.ok(r instanceof types.NestedEnvelope);
  assert.ok(r.data instanceof types.ItemListData);
  assert.equal(listToArray(r.data.items).length, 2);
  assert.ok(r.message instanceof option.Some);
  assert.equal(r.message[0], "hello");
}
{
  const r = decodeOk("echo_nested_envelope/no_message");
  assert.ok(r instanceof types.NestedEnvelope);
  assert.equal(listToArray(r.data.items).length, 0);
  assert.ok(r.message instanceof option.None);
}

// Mixed dict + list (data exposed two ways)
{
  const r = decodeOk("echo_dict_and_list_envelope/basic");
  assert.ok(r instanceof types.DictAndListEnvelope);
  expectItem(dictGet(r.by_id, "a"), item);
  expectItem(dictGet(r.by_id, "b"), item2);
  const ordered = listToArray(r.ordered);
  assert.equal(ordered.length, 2);
  expectItem(ordered[0], item);
  expectItem(ordered[1], item2);
}

// ---------- Cross-module type-name collisions ----------

{
  const v = decodeOk("echo_types_tag/basic");
  assert.ok(v instanceof types.Tag, "types.Tag instance");
  assert.equal(v.label, "sale");
  assert.equal(v.color, "red");
}
{
  const v = decodeOk("echo_collision_tag/basic");
  assert.ok(v instanceof collision.Tag, "collision.Tag instance");
  assert.equal(v.label, "promo");
}

console.log("wire e2e decode-typed test passed (every manifest case via decode_value)");
