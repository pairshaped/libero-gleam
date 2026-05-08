// Test that the ETF decoder's non-raw mode reconstructs Ok, Error,
// Some, None constructor instances inline (in decodeTuple and
// decodeAtom), so Gleam callbacks can pattern match without a second
// typed-decoder pass.
//
// This is a focused test that inlines just enough of ETFDecoder to
// exercise the constructor reconstruction path. The real decoder
// lives in src/libero/rpc_ffi.mjs and src/rally_runtime/rpc_ffi.mjs.
//
// Run from the libero root:
//   node test/js/etf_constructor_decode_test.mjs

import { strict as assert } from "assert";

// ---------- Gleam stdlib stubs ----------

class CustomType {}
class Ok extends CustomType {
  constructor(value) { super(); this[0] = value; }
}
class ResultError extends CustomType {
  constructor(value) { super(); this[0] = value; }
}
class Some extends CustomType {
  constructor(value) { super(); this[0] = value; }
}
class None extends CustomType {}
class Empty extends CustomType {}
class NonEmpty extends CustomType {
  constructor(head, tail) { super(); this.head = head; this.tail = tail; }
}
class BitArray extends CustomType {
  constructor(rawBuffer) { super(); this.rawBuffer = rawBuffer; }
}

// ---------- Minimal ETF encoder for test fixtures ----------

class ETFEncoder {
  constructor() { this.bytes = []; }
  writeUint8(v) { this.bytes.push(v & 0xFF); }
  writeUint16(v) {
    this.bytes.push((v >> 8) & 0xFF, v & 0xFF);
  }
  writeUint32(v) {
    this.bytes.push((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF);
  }
  writeFloat64(v) {
    const buf = new ArrayBuffer(8);
    new DataView(buf).setFloat64(0, v, false);
    for (const b of new Uint8Array(buf)) this.bytes.push(b);
  }
  writeString(str) {
    const encoded = new TextEncoder().encode(str);
    this.writeUint16(encoded.length);
    for (const b of encoded) this.bytes.push(b);
  }
  writeBytes(bytes) { for (const b of bytes) this.bytes.push(b); }

  encodeTerm(value) {
    if (value === undefined || value === null) {
      // nil atom
      this.bytes.push(119, 3, 110, 105, 108); // SMALL_ATOM_UTF8 "nil"
    } else if (typeof value === "boolean") {
      const str = value ? "true" : "false";
      const enc = new TextEncoder().encode(str);
      this.bytes.push(119, enc.length, ...enc);
    } else if (typeof value === "number") {
      if (Number.isInteger(value) && value >= 0 && value <= 255) {
        this.bytes.push(97, value);
      } else if (Number.isInteger(value) && value >= -2147483648 && value <= 2147483647) {
        this.bytes.push(98);
        this.writeUint32(value >>> 0);
      } else {
        this.bytes.push(70);
        this.writeFloat64(value);
      }
    } else if (typeof value === "string") {
      const enc = new TextEncoder().encode(value);
      this.bytes.push(109);
      this.writeUint32(enc.length);
      for (const b of enc) this.bytes.push(b);
    } else if (Array.isArray(value)) {
      // Treat arrays as tuples
      const len = value.length;
      if (len <= 255) {
        this.bytes.push(104, len);
      } else {
        this.bytes.push(105);
        this.writeUint32(len);
      }
      for (const el of value) this.encodeTerm(el);
    } else if (value instanceof Ok) {
      this.bytes.push(104, 2); // small tuple(2)
      const enc = new TextEncoder().encode("ok");
      this.bytes.push(119, enc.length, ...enc);
      this.encodeTerm(value[0]);
    } else if (value instanceof ResultError) {
      this.bytes.push(104, 2);
      const enc = new TextEncoder().encode("error");
      this.bytes.push(119, enc.length, ...enc);
      this.encodeTerm(value[0]);
    } else if (value instanceof Some) {
      this.bytes.push(104, 2);
      const enc = new TextEncoder().encode("some");
      this.bytes.push(119, enc.length, ...enc);
      this.encodeTerm(value[0]);
    } else if (value instanceof None) {
      const enc = new TextEncoder().encode("none");
      this.bytes.push(119, enc.length, ...enc);
    }
  }

  encode(value) {
    this.bytes = [131]; // ETF version byte
    this.encodeTerm(value);
    return new Uint8Array(this.bytes);
  }
}

// ---------- Constructor registry (matches rpc_ffi.mjs) ----------
const constructorRegistry = new Map();

// ---------- Typed decoder registry (matches rpc_ffi.mjs) ----------
// Atom → decoder-name reverse mapping so non-raw decode_value can
// reconstruct custom types without the deprecated constructorRegistry.
const _typedDecoderRegistry = new Map();
const _atomToDecoderName = new Map();

function registerTypedDecoder(name, fn) {
  _typedDecoderRegistry.set(name, fn);
}
function registerAtomDecoder(atomName, decoderName, decoderFn) {
  registerTypedDecoder(decoderName, decoderFn);
  _atomToDecoderName.set(atomName, decoderName);
}
function lookupAtomDecoder(atomName) {
  const decoderName = _atomToDecoderName.get(atomName);
  if (!decoderName) return undefined;
  return _typedDecoderRegistry.get(decoderName);
}

// Convert a decoded value to raw ETF shape for typed decoder consumption.
// Gleam linked lists → JS arrays, Some/None/Ok/Error → raw tagged arrays.
function toRawShape(value) {
  if (value === undefined || value === null) return value;
  if (value instanceof Empty) return [];
  if (value instanceof NonEmpty) {
    const arr = [];
    let cur = value;
    while (cur instanceof NonEmpty) {
      arr.push(cur.head);
      cur = cur.tail;
    }
    return arr;
  }
  if (value instanceof Some) return ["some", value[0]];
  if (value instanceof None) return "none";
  if (value instanceof Ok) return ["ok", value[0]];
  if (value instanceof ResultError) return ["error", value[0]];
  return value;
}

// ---------- Minimal ETFDecoder with constructor reconstruction ----------
// Inlined from rpc_ffi.mjs - mirrors the real decodeTuple and
// decodeAtom paths for Ok, Error, Some, None, constructorRegistry,
// and the atom→typed-decoder reverse mapping.

const utf8Decoder = new TextDecoder();

class MiniETFDecoder {
  constructor(input, raw = false) {
    let bytes;
    if (input instanceof Uint8Array) bytes = input;
    else if (input instanceof ArrayBuffer) bytes = new Uint8Array(input);
    else throw new Error("bad input");
    this.bytes = bytes;
    this.view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    this.offset = 0;
    this.raw = raw;
  }

  decode() {
    const tag = this.readUint8();
    if (tag !== 131) throw new Error(`bad version ${tag}`);
    return this.decodeTerm();
  }

  readUint8() { return this.view.getUint8(this.offset++); }
  readUint16() { const v = this.view.getUint16(this.offset); this.offset += 2; return v; }
  readUint32() { const v = this.view.getUint32(this.offset); this.offset += 4; return v; }
  readFloat64() { const v = this.view.getFloat64(this.offset); this.offset += 8; return v; }

  readString(len) {
    const str = utf8Decoder.decode(
      new Uint8Array(this.bytes.buffer, this.bytes.byteOffset + this.offset, len)
    );
    this.offset += len;
    return str;
  }

  readBytes(len) {
    const bytes = new Uint8Array(this.bytes.buffer, this.bytes.byteOffset + this.offset, len);
    this.offset += len;
    return bytes;
  }

  checkCollectionLen(len, label) {
    if (len > 10_000_000) throw new Error(`${label} too long: ${len}`);
    return len;
  }

  decodeTerm() {
    const tag = this.readUint8();
    switch (tag) {
      case 97: return this.readUint8();
      case 98: return this.readInt32();
      case 70: return this.readFloat64();
      case 104: return this.decodeTuple(this.readUint8());
      case 105: return this.decodeTuple(this.readUint32());
      case 106:
        if (this.raw) return [];
        return new Empty();
      case 108: return this.decodeList();
      case 109: {
        const len = this.readUint32();
        const bytes = this.readBytes(len);
        if (this.raw) return { __liberoRawBinary: true, rawBuffer: bytes };
        return utf8Decoder.decode(bytes);
      }
      case 118: return this.decodeAtom(this.readUint16());
      case 119: return this.decodeAtom(this.readUint8());
      default: throw new Error(`unsupported tag ${tag}`);
    }
  }

  readInt32() { const v = this.view.getInt32(this.offset); this.offset += 4; return v; }

  decodeAtom(len) {
    const name = this.readString(len);
    if (name === "true") return true;
    if (name === "false") return false;
    if (name === "nil" || name === "undefined") return undefined;
    if (!this.raw) {
      if (name === "none") return new None();
      const reg = constructorRegistry.get(name);
      if (reg && reg.fieldCount === 0) return new reg.ctor();
      const decoderFn = lookupAtomDecoder(name);
      if (decoderFn) return decoderFn(name);
    }
    return name;
  }

  decodeTuple(arity) {
    if (arity === 0) return [];

    const firstTag = this.bytes[this.offset];
    if (firstTag === 118 || firstTag === 119) {
      this.offset += 1;
      const atomLen = firstTag === 119 ? this.readUint8() : this.readUint16();
      const atomName = this.readString(atomLen);

      if (atomName === "true" || atomName === "false" || atomName === "nil" || atomName === "undefined") {
        const firstVal = atomName === "true" ? true
          : atomName === "false" ? false
          : undefined;
        const elements = [firstVal];
        for (let i = 1; i < arity; i++) elements.push(this.decodeTerm());
        return elements;
      }

      if (!this.raw) {
        switch (atomName) {
          case "ok": {
            const inner = arity >= 2 ? this.decodeTerm() : undefined;
            for (let i = 2; i < arity; i++) this.decodeTerm();
            return new Ok(inner);
          }
          case "error": {
            const inner = arity >= 2 ? this.decodeTerm() : undefined;
            for (let i = 2; i < arity; i++) this.decodeTerm();
            return new ResultError(inner);
          }
          case "some": {
            const inner = arity >= 2 ? this.decodeTerm() : undefined;
            for (let i = 2; i < arity; i++) this.decodeTerm();
            return new Some(inner);
          }
          case "none":
            for (let i = 1; i < arity; i++) this.decodeTerm();
            return new None();
        }
      }

      // Custom type reconstruction via constructorRegistry
      if (!this.raw) {
        const reg = constructorRegistry.get(atomName);
        if (reg) {
          const fields = [];
          for (let i = 1; i < arity; i++) fields.push(this.decodeTerm());
          while (fields.length < reg.fieldCount) fields.push(undefined);
          fields.length = reg.fieldCount;
          return new reg.ctor(...fields);
        }
      }

      // Typed decoder reconstruction: atom→decoder reverse mapping.
      // Decode fields in non-raw mode so nested custom types are resolved
      // through lookupAtomDecoder, then convert Gleam collection instances
      // back to raw ETF shapes for typed decoder primitives.
      if (!this.raw) {
        const decoderFn = lookupAtomDecoder(atomName);
        if (decoderFn) {
          const elements = [atomName];
          for (let i = 1; i < arity; i++) {
            elements.push(toRawShape(this.decodeTerm()));
          }
          return decoderFn(elements);
        }
      }

      const elements = [atomName];
      for (let i = 1; i < arity; i++) elements.push(this.decodeTerm());
      return elements;
    }

    const elements = [];
    for (let i = 0; i < arity; i++) elements.push(this.decodeTerm());
    return elements;
  }

  decodeList() {
    const count = this.readUint32();
    const elements = [];
    for (let i = 0; i < count; i++) elements.push(this.decodeTerm());
    this.readUint8(); // skip NIL_EXT tail
    if (this.raw) return elements;
    let list = new Empty();
    for (let i = elements.length - 1; i >= 0; i--) {
      list = new NonEmpty(elements[i], list);
    }
    return list;
  }
}

// ---------- Helpers ----------

const encoder = new ETFEncoder();

function roundtrip(value) {
  const bytes = encoder.encode(value);
  return bytes;
}

// ================================================================
// Tests: non-raw mode (decode_value) reconstructs constructors
// ================================================================

// --- Ok(value) ---

{
  const bytes = roundtrip(new Ok(42));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Ok, "Ok(42) should decode to Ok instance");
  assert.equal(decoded[0], 42);
  console.log("PASS: Ok(42) roundtrip");
}

{
  const bytes = roundtrip(new Ok("hello"));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Ok);
  assert.equal(decoded[0], "hello");
  console.log("PASS: Ok('hello') roundtrip");
}

{
  // Gleam Nil is encoded as ETF atom nil, decoded as undefined
  const bytes = roundtrip(new Ok(undefined));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Ok);
  assert.equal(decoded[0], undefined);
  console.log("PASS: Ok(Nil) roundtrip");
}

// --- Error(value) ---

{
  const bytes = roundtrip(new ResultError("something broke"));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof ResultError, "Error should decode to Error instance");
  assert.equal(decoded[0], "something broke");
  console.log("PASS: Error(string) roundtrip");
}

{
  // Gleam Nil is encoded as ETF atom nil, decoded as undefined
  const bytes = roundtrip(new ResultError(undefined));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof ResultError);
  assert.equal(decoded[0], undefined);
  console.log("PASS: Error(Nil) roundtrip");
}

// --- Some(value) ---

{
  const bytes = roundtrip(new Some(99));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Some, "Some(99) should decode to Some instance");
  assert.equal(decoded[0], 99);
  console.log("PASS: Some(99) roundtrip");
}

// --- None ---

{
  const bytes = roundtrip(new None());
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof None, "None should decode to None instance");
  console.log("PASS: None roundtrip");
}

// --- Nested: Ok(Some("value")) ---

{
  const bytes = roundtrip(new Ok(new Some("nested")));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Ok);
  assert.ok(decoded[0] instanceof Some);
  assert.equal(decoded[0][0], "nested");
  console.log("PASS: Ok(Some('nested')) roundtrip");
}

// --- Nested: Error(None) ---

{
  const bytes = roundtrip(new ResultError(new None()));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof ResultError);
  assert.ok(decoded[0] instanceof None);
  console.log("PASS: Error(None) roundtrip");
}

// ================================================================
// Tests: raw mode (decode_value_raw) returns raw arrays
// ================================================================

{
  const bytes = roundtrip(new Ok(42));
  const decoded = new MiniETFDecoder(bytes, true).decode();
  assert.ok(Array.isArray(decoded), "raw mode should return array");
  assert.equal(decoded[0], "ok", "raw: first element is string 'ok'");
  assert.equal(decoded[1], 42, "raw: second element is 42");
  assert.equal(decoded instanceof Ok, false, "raw: NOT an Ok instance");
  console.log("PASS: raw Ok(42) -> ['ok', 42]");
}

{
  const bytes = roundtrip(new None());
  const decoded = new MiniETFDecoder(bytes, true).decode();
  assert.equal(decoded, "none", "raw: bare atom 'none' is string");
  assert.equal(decoded instanceof None, false, "raw: NOT a None instance");
  console.log("PASS: raw None -> 'none'");
}

// ================================================================
// Regression: Gleam pattern matching works on decoded values
// ================================================================

{
  // Simulate: server returns Ok(Some(42)), client pattern matches.
  const bytes = roundtrip(new Ok(new Some(42)));
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Ok, "regression: decoded is Ok instance");
  const inner = decoded[0];
  assert.ok(inner instanceof Some, "regression: inner is Some instance");
  assert.equal(inner[0], 42);

  // Verify raw mode would fail pattern matching (the bug scenario):
  const rawBytes = roundtrip(new Ok(new Some(42)));
  const rawDecoded = new MiniETFDecoder(rawBytes, true).decode();
  assert.equal(rawDecoded instanceof Ok, false,
    "regression: raw mode returns array, not Ok instance");
  assert.ok(Array.isArray(rawDecoded));

  console.log("PASS: regression - Ok(Some(42)) pattern-matchable");
}

// ================================================================
// Custom type constructor registry roundtrip
// Tests the full registerConstructor -> decode_value flow.
// ================================================================

function makeAtomBytes(name) {
  const enc = new TextEncoder().encode(name);
  return [119, enc.length, ...enc];
}

function makeStringBytes(str) {
  const enc = new TextEncoder().encode(str);
  return [109, (enc.length >> 24) & 0xFF, (enc.length >> 16) & 0xFF,
    (enc.length >> 8) & 0xFF, enc.length & 0xFF, ...enc];
}

{
  // Simulate what the generated codec_ffi.mjs does at init time:
  // define a custom type class and register it, then decode
  // an ETF payload containing that custom type.

  class Sponsor extends CustomType {
    constructor(id, name) {
      super();
      this.id = id; this[0] = id;
      this.name = name; this[1] = name;
    }
  }

  // Register: codec_ffi.mjs calls registerConstructor at init
  constructorRegistry.set("sponsor", { ctor: Sponsor, fieldCount: 2 });

  // Manually encode: {ok, {sponsor, 1, <<"Acme">>}}
  // ETF: <<131, 104,2, 119,2,111,107, 104,3, 119,7,115,112,111,110,115,111,114, 97,1, 109,0,0,0,4,65,99,109,101>>
  const okAtom = [119, 2, 111, 107]; // "ok"
  const sponsorAtom = [119, 7, 115, 112, 111, 110, 115, 111, 114]; // "sponsor"
  const acme = makeStringBytes("Acme");
  const int1 = [97, 1]; // small int 1

  const sponsorTuple = [104, 3, ...sponsorAtom, ...int1, ...acme]; // {sponsor, 1, "Acme"}
  const okTuple = [104, 2, ...okAtom, ...sponsorTuple]; // {ok, {sponsor, 1, "Acme"}}
  const bytes = new Uint8Array([131, ...okTuple]);

  const decoded = new MiniETFDecoder(bytes).decode();

  // Verify: full reconstruction through the registry
  assert.ok(decoded instanceof Ok, "custom: outer is Ok instance");
  const inner = decoded[0];
  assert.ok(inner instanceof Sponsor, "custom: inner is Sponsor instance (via registry)");
  assert.equal(inner.id, 1);
  assert.equal(inner.name, "Acme");
  assert.equal(inner[0], 1);
  assert.equal(inner[1], "Acme");

  console.log("PASS: registerConstructor -> decode_value (Sponsor)");
}

{
  // Enum-style custom type (zero-arg variants)
  class Connected extends CustomType { constructor() { super(); } }
  class Disconnected extends CustomType { constructor() { super(); } }
  class Reconnecting extends CustomType { constructor() { super(); } }

  constructorRegistry.set("connected", { ctor: Connected, fieldCount: 0 });
  constructorRegistry.set("disconnected", { ctor: Disconnected, fieldCount: 0 });
  constructorRegistry.set("reconnecting", { ctor: Reconnecting, fieldCount: 0 });

  // Encode Connected (a bare atom)
  const bytes = new Uint8Array([131, 119, 9,
    99, 111, 110, 110, 101, 99, 116, 101, 100]); // "connected"
  const decoded = new MiniETFDecoder(bytes).decode();

  assert.ok(decoded instanceof Connected, "custom: zero-arg variant via atom");
  console.log("PASS: registerConstructor -> decode_value (enum variant)");
}

{
  // Unknown type falls through to raw (graceful degradation)
  // Encode {unknown_type, "data"} — not registered
  const utEnc = new TextEncoder().encode("unknown_type");
  const data = makeStringBytes("data");
  const bytes = new Uint8Array([131, 104, 2, 119, 12, ...utEnc, ...data]);
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(Array.isArray(decoded), "custom: unregistered type returns raw array");
  assert.equal(decoded[0], "unknown_type");
  assert.equal(decoded[1], "data");
  console.log("PASS: unregistered custom type falls through to raw array");
}

// ================================================================
// Tests: atom→typed-decoder reverse mapping
// These exercise the registerAtomDecoder + lookupAtomDecoder path
// (non-raw decode_value → typed decoder). The raw mode toggle ensures
// typed decoder primitives receive raw shapes for List/Dict/Option fields.
// ================================================================

// ---- Atom→decoder: custom type with List field ----
// The raw mode toggle ensures the List field is decoded as a raw JS array
// (not a Gleam linked list), so typed decoder primitives like decode_list_of
// receive arrays they can consume.
{
  class ItemList extends CustomType {
    constructor(items) { super(); this.items = items; this[0] = items; }
  }
  function decode_item_list(term) {
    if (!Array.isArray(term) || term[0] !== "item_list") throw new Error("expected item_list");
    // term[1] is a raw JS array because the atom→decoder path toggled raw mode
    const items = term[1];
    assert.ok(Array.isArray(items), "List field should be raw JS array, not Gleam linked list");
    return new ItemList(items);
  }
  registerAtomDecoder("item_list", "decode_item_list", decode_item_list);

  // Encode: {item_list, [1, 2, 3]}
  const ilAtom = [119, 9, 105, 116, 101, 109, 95, 108, 105, 115, 116]; // "item_list"
  const list = [108, 0, 0, 0, 3, 97, 1, 97, 2, 97, 3, 106]; // [1, 2, 3]
  const bytes = new Uint8Array([131, 104, 2, ...ilAtom, ...list]);
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof ItemList, "atom→decoder: List field reconstructed");
  assert.deepEqual(decoded[0], [1, 2, 3], "atom→decoder: List values preserved");
  console.log("PASS: atom→decoder with List field (raw mode toggle)");
  _atomToDecoderName.delete("item_list");
  _typedDecoderRegistry.delete("decode_item_list");
}

// ---- Atom→decoder: 0-arity enum variant (bare atom) ----
{
  class Pending extends CustomType { constructor() { super(); } }
  class Active extends CustomType { constructor() { super(); } }
  function decode_status(term) {
    if (term === "pending") return new Pending();
    if (term === "active") return new Active();
    throw new Error("unknown variant: " + term);
  }
  registerAtomDecoder("pending", "decode_status", decode_status);
  registerAtomDecoder("active", "decode_status", decode_status);

  // Encode Pending as a bare atom
  const bytes = new Uint8Array([131, 119, 7, 112, 101, 110, 100, 105, 110, 103]); // "pending"
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Pending, "atom→decoder: 0-arity enum reconstructed");
  console.log("PASS: atom→decoder 0-arity enum (bare atom)");
  _atomToDecoderName.delete("pending");
  _atomToDecoderName.delete("active");
  _typedDecoderRegistry.delete("decode_status");
}

// ---- Atom→decoder: nested custom types (A contains B) ----
{
  class Inner extends CustomType {
    constructor(x) { super(); this.x = x; this[0] = x; }
  }
  class Outer extends CustomType {
    constructor(inner) { super(); this.inner = inner; this[0] = inner; }
  }
  function decode_inner(term) {
    if (!Array.isArray(term) || term[0] !== "inner") throw new Error("expected inner");
    return new Inner(term[1]);
  }
  function decode_outer(term) {
    if (!Array.isArray(term) || term[0] !== "outer") throw new Error("expected outer");
    return new Outer(term[1]); // term[1] is the Inner instance
  }
  registerAtomDecoder("inner", "decode_inner", decode_inner);
  registerAtomDecoder("outer", "decode_outer", decode_outer);

  // Encode: {outer, {inner, 42}}
  const outerAtom = [119, 5, 111, 117, 116, 101, 114]; // "outer"
  const innerAtom = [119, 5, 105, 110, 110, 101, 114]; // "inner"
  const innerInt = [97, 42]; // small int 42
  const bytes = new Uint8Array([131, 104, 2, ...outerAtom, 104, 2, ...innerAtom, ...innerInt]);
  const decoded = new MiniETFDecoder(bytes).decode();
  assert.ok(decoded instanceof Outer, "atom→decoder: outer via typed decoder");
  assert.ok(decoded[0] instanceof Inner, "atom→decoder: nested inner via typed decoder");
  assert.equal(decoded[0][0], 42, "atom→decoder: nested value preserved");
  console.log("PASS: atom→decoder nested custom types");
  _atomToDecoderName.delete("inner");
  _atomToDecoderName.delete("outer");
  _typedDecoderRegistry.delete("decode_inner");
  _typedDecoderRegistry.delete("decode_outer");
}

// ---- Regression: RPC response with record wrapping nested custom type ----
// Wire shape: {ok, {ok, {envelope, {item, int, int}, total}}}
// The outer Ok layers are framework-special-cased; the envelope goes
// through lookupAtomDecoder; the nested custom type must also be
// reconstructed (not left as raw array by toRawShape).
// Uses int fields only to avoid binary encoding complexity.
{
  class Item extends CustomType {
    constructor(x, y) { super(); this.x = x; this[0] = x; this.y = y; this[1] = y; }
  }
  class Envelope extends CustomType {
    constructor(item, total) { super(); this.item = item; this[0] = item; this.total = total; this[1] = total; }
  }

  function decode_item(term) {
    if (!Array.isArray(term) || term[0] !== "item") throw new Error("expected item");
    return new Item(term[1], term[2]);
  }
  function decode_envelope(term) {
    if (!Array.isArray(term) || term[0] !== "envelope") throw new Error("expected envelope");
    // term[1] must be an Item instance (reconstructed by atom→decoder)
    assert.ok(term[1] instanceof Item, "envelope field must be Item instance via nested atom→decoder");
    return new Envelope(term[1], term[2]);
  }

  registerAtomDecoder("item", "decode_item", decode_item);
  registerAtomDecoder("envelope", "decode_envelope", decode_envelope);

  // Manually encode: {ok, {ok, {envelope, {item, 10, 20}, 99}}}
  const okAtom = [119, 2, 111, 107];
  const envAtom = [119, 8, 101, 110, 118, 101, 108, 111, 112, 101]; // "envelope"
  const itemAtom = [119, 4, 105, 116, 101, 109]; // "item"
  const itemTuple = [104, 3, ...itemAtom, 97, 10, 97, 20]; // {item, 10, 20}
  const envTuple = [104, 3, ...envAtom, ...itemTuple, 97, 99]; // {envelope, {item,10,20}, 99}
  const innerOk = [104, 2, ...okAtom, ...envTuple]; // {ok, {envelope,...}}
  const outerOk = [104, 2, ...okAtom, ...innerOk]; // {ok, {ok, {envelope,...}}}
  const bytes = new Uint8Array([131, ...outerOk]);

  const decoded = new MiniETFDecoder(bytes).decode();

  assert.ok(decoded instanceof Ok, "RPC: outer Ok");
  const inner1 = decoded[0];
  assert.ok(inner1 instanceof Ok, "RPC: inner Ok");
  const envelope = inner1[0];
  assert.ok(envelope instanceof Envelope, "RPC: envelope via atom→decoder");
  // Nested item via atom→decoder (not stripped by toRawShape)
  const item = envelope[0];
  assert.ok(item instanceof Item, "RPC: nested item is Item instance (atom→decoder preserved)");
  assert.equal(item.x, 10);
  assert.equal(item.y, 20);
  assert.equal(envelope[1], 99, "RPC: total field");
  console.log("PASS: RPC response — Ok(Ok(Envelope{item: Item, total}))");

  _atomToDecoderName.delete("item");
  _atomToDecoderName.delete("envelope");
  _typedDecoderRegistry.delete("decode_item");
  _typedDecoderRegistry.delete("decode_envelope");
}

{
  // Clean up: remove test registrations so they don't leak
  constructorRegistry.delete("sponsor");
  constructorRegistry.delete("connected");
  constructorRegistry.delete("disconnected");
  constructorRegistry.delete("reconnecting");
  console.log("PASS: constructorRegistry cleanup");
}

console.log("\nAll ETF constructor decode tests passed.");
console.log("decode_value (raw=false) -> Ok/Error/Some/None instances.");
console.log("decode_value_raw (raw=true) -> raw arrays with string atoms.");
console.log("Custom types via constructorRegistry -> proper CustomType instances.");
console.log("Custom types via registerAtomDecoder -> typed decoder reconstruction.");
