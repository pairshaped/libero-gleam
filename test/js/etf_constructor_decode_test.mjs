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

// ---------- Minimal ETFDecoder with constructor reconstruction ----------
// Inlined from rpc_ffi.mjs - just enough to test the decodeTuple and
// decodeAtom paths for Ok, Error, Some, None.

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
    if (!this.raw && name === "none") return new None();
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

console.log("\nAll ETF constructor decode tests passed.");
console.log("decode_value (raw=false) -> Ok/Error/Some/None instances.");
console.log("decode_value_raw (raw=true) -> raw arrays with string atoms.");
