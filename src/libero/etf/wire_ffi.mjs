// @ts-check
//
// ETF wire format for libero RPC.
//
// Wire shape: Erlang External Term Format (ETF), subset used by Gleam.
// WebSocket uses binary frames (ArrayBuffer).
//
// Gleam lists are rebuilt as linked lists so `gleam/list` operations
// work on them. Custom type decoding is handled by the typed decoder
// generated per consumer (rpc_decoders_ffi.mjs).

import { Ok, Error as ResultError, CustomType, Empty, NonEmpty, BitArray } from "../../../gleam_stdlib/gleam.mjs";
import { Some, None } from "../../../gleam_stdlib/gleam/option.mjs";
import {
  from_list as dictFromList,
  to_list as dictToList,
} from "../../../gleam_stdlib/gleam/dict.mjs";
import { DecodeError as WireDecodeError } from "../error.mjs";

// ---------- Custom type constructor registry ----------
// Generated codec_ffi.mjs registers per-type constructors here at init
// time. The ETF decoder (decodeTuple) looks up this registry when it
// encounters an atom-tagged tuple for a custom type like {sponsor, ...}
// and reconstructs the proper Gleam constructor instance.
//
// DEPRECATED: keyed by bare atom name, which causes collisions when
// two modules define types with the same variant name. Use
// registerTypedDecoder + decodeTyped instead.

const constructorRegistry = new Map();

/**
 * Register a custom type constructor for ETF decoding.
 * Called by the generated codec_ffi.mjs at module init time.
 * @param {string} atomName snake_case constructor name (e.g. "sponsor")
   * @param {typeof import("../../../gleam_stdlib/gleam.mjs").CustomType} ctor
 * @param {number} fieldCount number of positional fields
 */
export function registerConstructor(atomName, ctor, fieldCount) {
  constructorRegistry.set(atomName, { ctor, fieldCount });
}

// ---------- Typed decoder registry ----------
// Generated codec_ffi.mjs registers per-type decoder functions here so
// callers (e.g. SSR flag decoding) can apply the two-pass decode:
// raw ETF decode → typed decoder.
//
// Keyed by full decoder name (e.g. "decode_pages_home__item"), which
// includes the module path and cannot collide across modules.

const _typedDecoderRegistry = new Map();

export function registerTypedDecoder(name, fn) {
  _typedDecoderRegistry.set(name, fn);
}

export function decodeTyped(value, decoderName) {
  const fn = _typedDecoderRegistry.get(decoderName);
  if (!fn) throw new Error("Unknown typed decoder: " + decoderName);
  return fn(value);
}

// Atom → decoder-name reverse mapping so the ETF decoder's non-raw mode
// can reconstruct custom types without a constructor registry. Populated
// alongside registerTypedDecoder by the generated codec_ffi.mjs.
//
// If two modules define the same atom name the second registration
// overwrites the first, same as the old constructorRegistry. The two-pass
// path (decode_safe_raw + apply_typed_decoder) handles collisions
// correctly where the caller knows the expected type.
const _atomToDecoderName = new Map();

export function registerAtomDecoder(atomName, decoderName, decoderFn) {
  registerTypedDecoder(decoderName, decoderFn);
  _atomToDecoderName.set(atomName, decoderName);
}

export function lookupAtomDecoder(atomName) {
  const decoderName = _atomToDecoderName.get(atomName);
  if (!decoderName) return undefined;
  return _typedDecoderRegistry.get(decoderName);
}

// ---------- Error names ----------
//
// Error.name values set on exceptions thrown by the codec. Consumers
// that need to branch on failure mode can match `err.name === ERROR_X`
// instead of parsing message strings.

/** Input to ETFDecoder is not a supported buffer type. */
export const ERROR_INVALID_INPUT = "ETF_INVALID_INPUT";
/** First byte is not the ETF version tag (131). */
export const ERROR_VERSION_BYTE = "ETF_VERSION_BYTE";
/** Encountered a tag the decoder does not support. */
export const ERROR_UNKNOWN_TAG = "ETF_UNKNOWN_TAG";
/** List tail is not NIL_EXT. Gleam cannot produce improper lists. */
export const ERROR_IMPROPER_LIST = "ETF_IMPROPER_LIST";
/** Atom name exceeds the Erlang 255 codepoint limit. */
export const ERROR_ATOM_TOO_LONG = "ETF_ATOM_TOO_LONG";
/** Tuple arity or list length exceeds MAX_COLLECTION_LEN. */
export const ERROR_COLLECTION_TOO_LONG = "ETF_COLLECTION_TOO_LONG";
/** Binary or bit-binary length exceeds MAX_BINARY_BYTES. */
export const ERROR_BINARY_TOO_LARGE = "ETF_BINARY_TOO_LARGE";
/** Trailing bytes after a decoded term. */
export const ERROR_TRAILING_BYTES = "ETF_TRAILING_BYTES";

// Hard caps so that a malformed (or hostile) frame cannot pre-allocate
// gigabytes of references. Real mist frame limits will normally catch
// this first; these are defense-in-depth and independent of how the
// underlying transport is configured.
const MAX_COLLECTION_LEN = 16_000_000;
const MAX_BINARY_BYTES = 64 * 1024 * 1024;

/**
 * @param {string} message
 * @param {string} name
 * @returns {Error}
 */
function makeError(message, name) {
  const e = new Error(message);
  e.name = name;
  return e;
}

// ---------- Identity helper (for Gleam FFI) ----------

/**
 * @template T
 * @param {T} x
 * @returns {T}
 */
export function identity(x) {
  return x;
}

// ---------- Field type hints ----------
//
// JS has no int/float distinction - `2.0 === 2` and
// `Number.isInteger(2.0) === true`. But ETF does distinguish them,
// and Gleam's BEAM runtime treats Int and Float as different types.
//
// Under the wire-identity scheme, codegen attaches an `__fieldTypes`
// static array to each Gleam custom-type class. The encoder reads
// `value.constructor.__fieldTypes[i]` for the i-th field's hint.
// This replaces the prior global `fieldTypeRegistry` map keyed by
// (qualified) atom name; the per-class static can never collide and
// requires no runtime registration step.

/**
 * Build a Gleam linked list from a plain JS array.
 * @param {any[]} arr
 * @returns {any}
 */
function arrayToGleamList(arr) {
  let list = new Empty();
  for (let i = arr.length - 1; i >= 0; i--) {
    list = new NonEmpty(arr[i], list);
  }
  return list;
}

/**
 * Flatten a Gleam linked list (or JS array) into a plain JS array.
 * @param {any} list
 * @returns {any[]}
 */
function gleamListToArray(list) {
  if (Array.isArray(list)) return list;
  const out = [];
  let cur = list;
  while (cur instanceof NonEmpty) {
    out.push(cur.head);
    cur = cur.tail;
  }
  return out;
}

// ---------- ETF Decoder ----------
//
// Design note: no wrapper classes for atoms or tuples.
//
// A general-purpose ETF decoder (e.g. arnu515/erlang-etf.js; see
// https://github.com/arnu515/erlang-etf.js, MIT) wraps atoms in `Atom`
// and tuples in `Tuple` because, in raw JS, atoms collide with
// binaries (both are strings) and tuples collide with lists (both are
// arrays). Without wrappers, the consumer can't tell `:ok` from
// `<<"ok">>` or `{1, 2}` from `[1, 2]`.
//
// Libero doesn't need wrappers because the typed decoder layer
// (rpc_decoders_ffi.mjs, generated per consumer) knows the expected
// shape from the Gleam type graph. When raw mode hands back
// `["some", 42]`, the typed decoder sees an `Option(Int)` field at that
// position and constructs `_Some(42)`. Same for atoms-vs-binaries: the
// type tells the decoder which one to expect.
//
// Adding wrapper classes here would just be one more layer the typed
// decoder unwraps. The cost is that raw mode is ambiguous on its own,
// fine for libero, but the reason a future standalone ETF library
// (split from this codec) would need wrappers.
//
// Prior art: libero's codec is independently implemented, but aligns
// with erlang-etf.js on BIT_BINARY_EXT handling and atom-length
// validation (255 codepoints). Credit to that project for the spec
// references.

const utf8Decoder = new TextDecoder();

/**
 * @typedef {ArrayBuffer | Uint8Array | { rawBuffer: Uint8Array }} DecoderInput
 */

class ETFDecoder {
  /**
   * @param {DecoderInput} input ArrayBuffer, Uint8Array, or Gleam BitArray
   * @param {boolean} [raw] if true, atoms stay as strings and tagged
   *   tuples stay as plain JS arrays. Used when the typed decoder
   *   will re-interpret the result.
   */
  constructor(input, raw = false) {
    // Accept any of: ArrayBuffer (WebSocket onmessage with binaryType
    // "arraybuffer"), Uint8Array, or a Gleam JS BitArray (which exposes
    // its bytes as `rawBuffer`, a Uint8Array). Normalising here lets the
    // public `wire.decode` primitive take a Gleam BitArray directly,
    // matching the cross-target promise of the Gleam-side function.
    /** @type {Uint8Array} */
    let bytes;
    if (input instanceof Uint8Array) {
      bytes = input;
    } else if (input instanceof ArrayBuffer) {
      bytes = new Uint8Array(input);
    } else if (input && /** @type {any} */ (input).rawBuffer instanceof Uint8Array) {
      bytes = /** @type {any} */ (input).rawBuffer;
    } else {
      throw makeError(
        "ETFDecoder: input must be ArrayBuffer, Uint8Array, or Gleam BitArray",
        ERROR_INVALID_INPUT,
      );
    }
    this.bytes = bytes;
    this.view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    this.offset = 0;
    this.raw = raw;
  }

  /** @returns {any} */
  decode() {
    const version = this.readUint8();
    if (version !== 131) {
      throw makeError(
        `ETF decode: expected version byte 131, got ${version}`,
        ERROR_VERSION_BYTE,
      );
    }
    const result = this.decodeTerm();
    if (this.offset !== this.bytes.byteLength) {
      throw makeError(
        `ETF decode: trailing bytes at offset ${this.offset}, total length ${this.bytes.byteLength}`,
        ERROR_TRAILING_BYTES,
      );
    }
    return result;
  }

  ensureAvailable(n) {
    if (this.offset + n > this.bytes.byteLength) {
      throw makeError(
        `ETF decode: need ${n} bytes at offset ${this.offset}, only ${this.bytes.byteLength - this.offset} available`,
        "ETF_TRUNCATED",
      );
    }
  }

  checkCollectionLen(n, label) {
    if (n > MAX_COLLECTION_LEN) {
      throw makeError(
        `ETF decode: ${label} ${n} exceeds limit ${MAX_COLLECTION_LEN}`,
        ERROR_COLLECTION_TOO_LONG,
      );
    }
    return n;
  }

  checkBinaryLen(n, label) {
    if (n > MAX_BINARY_BYTES) {
      throw makeError(
        `ETF decode: ${label} length ${n} exceeds limit ${MAX_BINARY_BYTES}`,
        ERROR_BINARY_TOO_LARGE,
      );
    }
    return n;
  }

  readUint8() {
    this.ensureAvailable(1);
    const v = this.view.getUint8(this.offset);
    this.offset += 1;
    return v;
  }

  readUint16() {
    this.ensureAvailable(2);
    const v = this.view.getUint16(this.offset);
    this.offset += 2;
    return v;
  }

  readUint32() {
    this.ensureAvailable(4);
    const v = this.view.getUint32(this.offset);
    this.offset += 4;
    return v;
  }

  readInt32() {
    this.ensureAvailable(4);
    const v = this.view.getInt32(this.offset);
    this.offset += 4;
    return v;
  }

  readFloat64() {
    this.ensureAvailable(8);
    const v = this.view.getFloat64(this.offset);
    this.offset += 8;
    return v;
  }

  readBytes(n) {
    this.ensureAvailable(n);
    const slice = this.bytes.slice(this.offset, this.offset + n);
    this.offset += n;
    return slice;
  }

  readString(n) {
    return utf8Decoder.decode(this.readBytes(n));
  }

  decodeTerm() {
    const tag = this.readUint8();
    switch (tag) {
      case 70: // NEW_FLOAT_EXT
        return this.readFloat64();

      case 97: // SMALL_INTEGER_EXT
        return this.readUint8();

      case 98: // INTEGER_EXT
        return this.readInt32();

      case 104: // SMALL_TUPLE_EXT
        return this.decodeTuple(this.readUint8());

      case 105: // LARGE_TUPLE_EXT
        return this.decodeTuple(this.checkCollectionLen(this.readUint32(), "tuple arity"));

      case 106: // NIL_EXT (empty list)
        if (this.raw) return [];
        return arrayToGleamList([]);

      case 108: // LIST_EXT
        return this.decodeList();

      case 107: { // STRING_EXT (list of small ints encoded as bytes)
        // Erlang optimizes lists of bytes (0-255) into this compact form.
        // Decode as a Gleam List(Int) - same semantics as LIST_EXT of SMALL_INTEGER_EXT.
        const len = this.readUint16();
        const elements = [];
        for (let i = 0; i < len; i++) {
          elements.push(this.readUint8());
        }
        if (this.raw) return elements;
        return arrayToGleamList(elements);
      }

      case 109: { // BINARY_EXT (Gleam string or byte-aligned BitArray)
        const len = this.checkBinaryLen(this.readUint32(), "binary");
        const bytes = this.readBytes(len);
        if (this.raw) return { __liberoRawBinary: true, rawBuffer: bytes };
        return utf8Decoder.decode(bytes);
      }

      case 110: // SMALL_BIG_EXT
        return this.decodeBigInt(this.readUint8());

      case 111: // LARGE_BIG_EXT
        return this.decodeBigInt(this.readUint32());

      case 116: // MAP_EXT
        return this.decodeMap();

      case 118: // ATOM_UTF8_EXT
        return this.decodeAtom(this.readUint16());

      case 119: // SMALL_ATOM_UTF8_EXT
        return this.decodeAtom(this.readUint8());

      case 77: { // BIT_BINARY_EXT (non-byte-aligned binary)
        // len bytes, then 1 byte for "bits in last byte" (1-8).
        // The last byte's high `bits` bits are meaningful; low `8 - bits`
        // bits are padding. A Gleam BitArray represents this natively
        // via bitSize, so no separate wrapper is needed.
        const len = this.checkBinaryLen(this.readUint32(), "bit_binary");
        const bitsInLastByte = this.readUint8();
        if (bitsInLastByte < 1 || bitsInLastByte > 8) {
          throw makeError(
            `ETF decode: bit_binary bits-in-last-byte ${bitsInLastByte} out of range (1-8)`,
            ERROR_BINARY_TOO_LARGE,
          );
        }
        const bytes = this.readBytes(len);
        const bitSize = len === 0 ? 0 : (len - 1) * 8 + bitsInLastByte;
        return new BitArray(bytes, bitSize, 0);
      }

      default:
        throw makeError(
          `ETF decode: unknown tag ${tag} at offset ${this.offset - 1}`,
          ERROR_UNKNOWN_TAG,
        );
    }
  }

  // DESIGN NOTE: No atom count limit on the JS side (unlike Erlang's [safe]
  // flag). This is acceptable because: (1) the server is the only sender and
  // it encodes well-typed Gleam values, (2) the WebSocket server (mist) can
  // enforce frame size limits, and (3) the typed decoder layer rejects
  // unknown constructors. A standalone ETF library should add a limit.
  decodeAtom(len) {
    const name = this.readString(len);
    // Erlang's hard limit is 255 codepoints (not bytes). UTF-8 codepoints
    // are 1-4 bytes, so a byte length under 256 can still produce <= 255
    // codepoints; but ATOM_UTF8_EXT (uint16 length) can exceed this.
    let codepointCount = 0;
    for (const _ of name) {
      codepointCount++;
      if (codepointCount >= 256) {
        throw makeError(
          "ETF decode: atom name exceeds 255 codepoints",
          ERROR_ATOM_TOO_LONG,
        );
      }
    }
    // Special atoms
    if (name === "true") return true;
    if (name === "false") return false;
    if (name === "nil" || name === "undefined") return undefined;
    // Framework constructor atoms: when not in raw mode, return proper
    // instances so Gleam pattern matching works on bare atoms too.
    if (!this.raw) {
      if (name === "none") return new None();
      const reg = constructorRegistry.get(name);
      if (reg && reg.fieldCount === 0) return new reg.ctor();
      const decoderFn = lookupAtomDecoder(name);
      if (decoderFn) return decoderFn(name);
    }
    // Return atom as string - unknown constructors are resolved
    // by the generated typed decoders in a second pass.
    return name;
  }

  decodeTuple(arity) {
    if (arity === 0) return [];

    // Peek at first element to check for atom tag
    const firstTag = this.bytes[this.offset];
    if (firstTag === 118 || firstTag === 119) {
      // First element is an atom - read the atom name directly
      this.offset += 1; // skip the tag byte
      const atomLen = firstTag === 119 ? this.readUint8() : this.readUint16();
      const atomName = this.readString(atomLen);

      // Special atoms in tuple position: treat as plain values
      if (atomName === "true" || atomName === "false" || atomName === "nil" || atomName === "undefined") {
        const firstVal = atomName === "true" ? true
          : atomName === "false" ? false
          : undefined;
        const elements = [firstVal];
        for (let i = 1; i < arity; i++) {
          elements.push(this.decodeTerm());
        }
        return elements;
      }

      // Framework constructor reconstruction: when not in raw mode,
      // rebuild Ok, Error, Some, None directly so Gleam callbacks
      // receive proper constructor instances for pattern matching.
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

      // Custom type reconstruction: check the constructor registry
      // populated by codec_ffi.mjs at init time.
      if (!this.raw) {
        const reg = constructorRegistry.get(atomName);
        if (reg) {
          const fields = [];
          for (let i = 1; i < arity; i++) {
            fields.push(this.decodeTerm());
          }
          while (fields.length < reg.fieldCount) fields.push(undefined);
          fields.length = reg.fieldCount;
          return new reg.ctor(...fields);
        }
      }

      // Typed decoder reconstruction: when not in raw mode, check the
      // atom→decoder reverse mapping populated by generated codec_ffi.mjs.
      // Decode fields in non-raw mode so nested custom types are resolved
      // through lookupAtomDecoder, then convert Gleam collection instances
      // (linked lists, Dicts, Some/None) back to raw ETF shapes that the
      // typed decoder primitives expect.
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

      // Unknown custom type: return as raw array with atom string as
      // first element. The generated typed decoders (codec_ffi.mjs)
      // resolve these in a second pass.
      const elements = [atomName];
      for (let i = 1; i < arity; i++) {
        elements.push(this.decodeTerm());
      }
      return elements;
    }

    // Not atom-tagged - decode all elements as plain JS array (Gleam tuple)
    const elements = [];
    for (let i = 0; i < arity; i++) {
      elements.push(this.decodeTerm());
    }
    return elements;
  }

  decodeList() {
    const count = this.checkCollectionLen(this.readUint32(), "list length");
    const elements = [];
    for (let i = 0; i < count; i++) {
      elements.push(this.decodeTerm());
    }
    // Read the tail - must be NIL_EXT (106) for proper lists.
    // Gleam cannot produce improper lists, so a non-nil tail indicates
    // corrupted data or a non-Gleam sender.
    const tailTag = this.readUint8();
    if (tailTag !== 106) {
      throw makeError(
        "ETF decode: improper list (non-nil tail) - Gleam cannot produce these",
        ERROR_IMPROPER_LIST,
      );
    }
    if (this.raw) return elements;
    return arrayToGleamList(elements);
  }

  decodeBigInt(n) {
    const sign = this.readUint8();
    const digits = this.readBytes(n);
    // Reconstruct the integer from little-endian digits
    let value = 0n;
    for (let i = n - 1; i >= 0; i--) {
      value = (value << 8n) | BigInt(digits[i]);
    }
    if (sign === 1) value = -value;
    // If it fits in a regular JS number, return as Number
    if (value >= Number.MIN_SAFE_INTEGER && value <= Number.MAX_SAFE_INTEGER) {
      return Number(value);
    }
    return value;
  }

  decodeMap() {
    const arity = this.checkCollectionLen(this.readUint32(), "map arity");
    const pairs = [];
    for (let i = 0; i < arity; i++) {
      const key = this.decodeTerm();
      const val = this.decodeTerm();
      pairs.push([key, val]);
    }
    if (this.raw) return pairs;
    return dictFromList(arrayToGleamList(pairs));
  }
}

// ---------- ETF Encoder ----------

const textEncoder = new TextEncoder();

class ETFEncoder {
  constructor() {
    // Start with 1024 bytes, grow as needed.
    this.buffer = new ArrayBuffer(1024);
    this.view = new DataView(this.buffer);
    this.bytes = new Uint8Array(this.buffer);
    this.offset = 0;
  }

  /** @param {number} needed */
  ensureCapacity(needed) {
    const required = this.offset + needed;
    if (required <= this.buffer.byteLength) return;
    let newSize = this.buffer.byteLength;
    while (newSize < required) newSize *= 2;
    const newBuffer = new ArrayBuffer(newSize);
    new Uint8Array(newBuffer).set(this.bytes);
    this.buffer = newBuffer;
    this.view = new DataView(this.buffer);
    this.bytes = new Uint8Array(this.buffer);
  }

  /** @param {number} v */
  writeUint8(v) {
    this.ensureCapacity(1);
    this.view.setUint8(this.offset, v);
    this.offset += 1;
  }

  /** @param {number} v */
  writeUint16(v) {
    this.ensureCapacity(2);
    this.view.setUint16(this.offset, v);
    this.offset += 2;
  }

  /** @param {number} v */
  writeUint32(v) {
    this.ensureCapacity(4);
    this.view.setUint32(this.offset, v);
    this.offset += 4;
  }

  /** @param {number} v */
  writeInt32(v) {
    this.ensureCapacity(4);
    this.view.setInt32(this.offset, v);
    this.offset += 4;
  }

  /** @param {number} v */
  writeFloat64(v) {
    this.ensureCapacity(8);
    this.view.setFloat64(this.offset, v);
    this.offset += 8;
  }

  /** @param {Uint8Array} bytes */
  writeBytes(bytes) {
    this.ensureCapacity(bytes.length);
    this.bytes.set(bytes, this.offset);
    this.offset += bytes.length;
  }

  /** @returns {ArrayBuffer} */
  result() {
    return this.buffer.slice(0, this.offset);
  }

  /**
   * @param {any} value
   * @param {any} typeHint
   */
  encodeTerm(value, typeHint = undefined) {
    if (value === undefined || value === null) {
      // Gleam Nil → atom "nil"
      this.writeAtom("nil");
      return;
    }

    if (typeof value === "boolean") {
      this.writeAtom(value ? "true" : "false");
      return;
    }

    if (typeof value === "string") {
      this.encodeBinary(value);
      return;
    }

    if (typeof value === "number") {
      if (typeHint === "float") {
        this.encodeFloat(value);
      } else {
        this.encodeNumber(value);
      }
      return;
    }

    if (typeof value === "bigint") {
      this.encodeBigInt(value);
      return;
    }

    // JS array = Gleam tuple
    if (Array.isArray(value)) {
      const elementHints =
        typeHint?.kind === "tuple" ? typeHint.elements : undefined;
      this.encodeTuple(value, elementHints);
      return;
    }

    // Gleam linked list
    if (value instanceof Empty || value instanceof NonEmpty) {
      const arr = gleamListToArray(value);
      const elementHint = typeHint?.kind === "list" ? typeHint.element : undefined;
      this.encodeList(arr, elementHint);
      return;
    }

    // Plain JS Map, useful for tests and low-level interop.
    if (value instanceof Map) {
      this.encodeMap(
        value,
        typeHint?.kind === "dict" ? typeHint.key : undefined,
        typeHint?.kind === "dict" ? typeHint.value : undefined,
      );
      return;
    }

    // Gleam stdlib Dict (HAMT object). Detected by duck-typing on the
    // internal `root` + `size` fields of gleam_stdlib's persistent hash
    // map implementation. This is coupled to stdlib internals: if the
    // HAMT representation changes (different field names, different data
    // structure), this branch silently stops matching and falls through
    // to the unsupported-value error. Verify after gleam_stdlib upgrades.
    if (value && typeof value === "object" && "root" in value && "size" in value) {
      this.encodeMap(
        new Map(gleamListToArray(dictToList(value))),
        typeHint?.kind === "dict" ? typeHint.key : undefined,
        typeHint?.kind === "dict" ? typeHint.value : undefined,
      );
      return;
    }

    // Gleam BitArray (has rawBuffer: Uint8Array).
    // Uses BINARY_EXT (tag 109) for all BitArrays. Sub-byte-aligned
    // BitArrays (bitSize % 8 != 0) should technically use BIT_BINARY_EXT
    // (tag 77), but Gleam's stdlib BitArray is always byte-aligned in
    // practice. The decoder handles BIT_BINARY_EXT correctly for
    // interop with Erlang values that use it.
    if (value && value.rawBuffer instanceof Uint8Array) {
      if (value.bitSize !== undefined && value.bitSize % 8 !== 0) {
        // Sub-byte-aligned: use BIT_BINARY_EXT (tag 77) to preserve
        // trailing bit count. Without this, the Erlang side would
        // receive a byte-aligned binary, losing the trailing bits.
        const byteLen = value.rawBuffer.length;
        const bitsInLastByte = value.bitSize % 8;
        this.writeUint8(77); // BIT_BINARY_EXT
        this.writeUint32(byteLen);
        this.writeUint8(bitsInLastByte);
        this.writeBytes(value.rawBuffer);
      } else {
        this.writeUint8(109); // BINARY_EXT
        this.writeUint32(value.rawBuffer.length);
        this.writeBytes(value.rawBuffer);
      }
      return;
    }

    // Gleam custom type instance
    if (value instanceof CustomType) {
      // Wire identity: prefer the codegen-baked `__wireAtom` static.
      // Fall back to a snake-cased class name for framework types
      // (Some, None, Ok, ResultError, Empty, NonEmpty) and any user
      // class that hasn't been processed by libero's codegen.
      const wireAtom =
        value.constructor.__wireAtom ?? snakeCase(value.constructor.name);
      const fieldTypes = value.constructor.__fieldTypes;
      const keys = Object.keys(value);
      if (keys.length === 0) {
        // 0-arity constructor → bare atom
        this.writeAtom(wireAtom);
      } else {
        // N-arity constructor → tuple {atom, field1, field2, ...}
        const arity = keys.length + 1;
        if (arity <= 255) {
          this.writeUint8(104); // SMALL_TUPLE_EXT
          this.writeUint8(arity);
        } else {
          this.writeUint8(105); // LARGE_TUPLE_EXT
          this.writeUint32(arity);
        }
        this.writeAtom(wireAtom);
        keys.forEach((k, i) => {
          const fieldValue = value[k];
          const hintedField = hintForConstructorField(wireAtom, i, typeHint)
            ?? fieldTypes?.[i];
          this.encodeTerm(fieldValue, hintedField);
        });
      }
      return;
    }

    // Fallback: this indicates a bug in the calling code; all Gleam
    // types should be handled above. Throw rather than silently
    // producing "[object Object]" which would be a corrupt payload.
    throw new Error(
      "ETF encode: unsupported value type: " + typeof value +
      " (" + String(value) + ")"
    );
  }

  writeAtom(name) {
    const encoded = textEncoder.encode(name);
    if (encoded.length <= 255) {
      this.writeUint8(119); // SMALL_ATOM_UTF8_EXT
      this.writeUint8(encoded.length);
    } else {
      this.writeUint8(118); // ATOM_UTF8_EXT
      this.writeUint16(encoded.length);
    }
    this.writeBytes(encoded);
  }

  encodeBinary(str) {
    const encoded = textEncoder.encode(str);
    this.writeUint8(109); // BINARY_EXT
    this.writeUint32(encoded.length);
    this.writeBytes(encoded);
  }

  encodeNumber(n) {
    if (Number.isInteger(n)) {
      if (n >= 0 && n <= 255) {
        this.writeUint8(97); // SMALL_INTEGER_EXT
        this.writeUint8(n);
      } else if (n >= -2147483648 && n <= 2147483647) {
        this.writeUint8(98); // INTEGER_EXT
        this.writeInt32(n);
      } else {
        // Large integer - use bigint encoding
        this.encodeBigInt(BigInt(n));
      }
    } else {
      this.writeUint8(70); // NEW_FLOAT_EXT
      this.writeFloat64(n);
    }
  }

  /** @param {number} n */
  encodeFloat(n) {
    this.writeUint8(70); // NEW_FLOAT_EXT
    this.writeFloat64(n);
  }

  encodeBigInt(value) {
    const sign = value < 0n ? 1 : 0;
    let abs = value < 0n ? -value : value;
    const digits = [];
    while (abs > 0n) {
      digits.push(Number(abs & 0xFFn));
      abs >>= 8n;
    }
    if (digits.length === 0) {
      // Zero - encode as SMALL_INTEGER_EXT
      this.writeUint8(97);
      this.writeUint8(0);
      return;
    }
    if (digits.length <= 255) {
      this.writeUint8(110); // SMALL_BIG_EXT
      this.writeUint8(digits.length);
    } else {
      this.writeUint8(111); // LARGE_BIG_EXT
      this.writeUint32(digits.length);
    }
    this.writeUint8(sign);
    this.writeBytes(new Uint8Array(digits));
  }

  encodeTuple(elements, elementHints = undefined) {
    if (elements.length <= 255) {
      this.writeUint8(104); // SMALL_TUPLE_EXT
      this.writeUint8(elements.length);
    } else {
      this.writeUint8(105); // LARGE_TUPLE_EXT
      this.writeUint32(elements.length);
    }
    for (let i = 0; i < elements.length; i++) {
      this.encodeTerm(elements[i], elementHints?.[i]);
    }
  }

  encodeList(arr, elementHint = undefined) {
    if (arr.length === 0) {
      this.writeUint8(106); // NIL_EXT
      return;
    }
    this.writeUint8(108); // LIST_EXT
    this.writeUint32(arr.length);
    for (const el of arr) {
      this.encodeTerm(el, elementHint);
    }
    this.writeUint8(106); // NIL_EXT tail
  }

  encodeMap(map, keyHint = undefined, valueHint = undefined) {
    this.writeUint8(116); // MAP_EXT
    this.writeUint32(map.size);
    map.forEach((val, key) => {
      this.encodeTerm(key, keyHint);
      this.encodeTerm(val, valueHint);
    });
  }
}

/**
 * Convert a decoded Gleam value to its raw ETF shape for typed decoder
 * consumption. Gleam linked lists become JS arrays, Some/None/Ok/Error
 * instances become raw tagged arrays. Nested custom types (already
 * reconstructed via lookupAtomDecoder) pass through as-is.
 * @param {any} value
 * @returns {any}
 */
function toRawShape(value) {
  if (value === undefined || value === null) return value;
  // Gleam linked list → JS array (recursively raw-shape each element)
  if (value instanceof Empty) return [];
  if (value instanceof NonEmpty) {
    const arr = [];
    let cur = value;
    while (cur instanceof NonEmpty) {
      arr.push(toRawShape(cur.head));
      cur = cur.tail;
    }
    return arr;
  }
  // Gleam Dict → JS array of [key, value] pairs (recursively
  // raw-shape both sides). decode_dict_of expects this shape.
  if (value && typeof value === "object" && value.root !== undefined && value.size !== undefined) {
    const list = dictToList(value);
    const pairs = [];
    let cur = list;
    while (cur instanceof NonEmpty) {
      const [k, v] = cur.head;
      pairs.push([toRawShape(k), toRawShape(v)]);
      cur = cur.tail;
    }
    return pairs;
  }
  // Framework constructors → raw tagged shapes (recurse into payload)
  if (value instanceof Some) return ["some", toRawShape(value[0])];
  if (value instanceof None) return "none";
  if (value instanceof Ok) return ["ok", toRawShape(value[0])];
  if (value instanceof ResultError) return ["error", toRawShape(value[0])];
  // User custom type → reconstruct raw wire shape so a parent typed
  // decoder's `decode_list_of(inner_decoder, term[i])` (or any body
  // that re-decodes a field) sees the wire shape it was generated
  // against. 0-arity variants encode as bare atoms (the decoder body
  // checks `term === "atom"`); N-arity variants encode as tagged
  // arrays (the decoder body checks `term[0] === "atom"`).
  if (value instanceof CustomType) {
    const wireAtom =
      value.constructor.__wireAtom ?? snakeCase(value.constructor.name);
    const keys = Object.keys(value);
    if (keys.length === 0) return wireAtom;
    const fields = keys.map(k => toRawShape(value[k]));
    return [wireAtom, ...fields];
  }
  return value;
}

function hintForConstructorField(ctorName, index, typeHint) {
  if (index !== 0 || !typeHint || typeof typeHint !== "object") return undefined;
  if (typeHint.kind === "option" && ctorName === "some") return typeHint.inner;
  if (typeHint.kind === "result" && ctorName === "ok") return typeHint.ok;
  if (typeHint.kind === "result" && ctorName === "error") return typeHint.err;
  return undefined;
}

// ---------- Helper ----------

/**
 * Convert PascalCase to snake_case. Mirrors Gleam's `to_snake_case`
 * so runtime encoding and codegen-time atom registration agree.
 * Handles consecutive uppercase: "XMLParser" → "xml_parser",
 * "HTTPSConnection" → "https_connection".
 *
 * Digits are treated as lowercase; no underscore is inserted before
 * a digit run. This matches Gleam's compiler behavior and the Erlang
 * side (walker.to_snake_case). Verified by snake_case_test.gleam.
 * @param {string} name
 * @returns {string}
 */
function snakeCase(name) {
  let result = "";
  for (let i = 0; i < name.length; i++) {
    const ch = name[i];
    const isUpper = ch !== ch.toLowerCase();
    if (i === 0) {
      result += ch.toLowerCase();
      continue;
    }
    if (isUpper) {
      const prevUpper = name[i - 1] !== name[i - 1].toLowerCase();
      const nextLower = i + 1 < name.length
        && name[i + 1] === name[i + 1].toLowerCase();
      if (prevUpper && nextLower) {
        // UPPER→UPPER→lower: start of new word after acronym
        result += "_" + ch.toLowerCase();
      } else if (prevUpper) {
        // UPPER→UPPER→(UPPER|end): still in acronym
        result += ch.toLowerCase();
      } else {
        // lower→UPPER: normal camelCase boundary
        result += "_" + ch.toLowerCase();
      }
    } else {
      result += ch;
    }
  }
  return result;
}

// ---------- Public codec API ----------

/**
 * Encode a standalone Gleam value to an ETF binary. Used by the
 * public `libero/etf/wire.encode` function. Unlike `encode_request`, there
 * is no envelope; the result is the raw ETF encoding of a single
 * value. Intended for non-RPC paths like passing state into a
 * Lustre SPA via init flags.
 * @param {any} value
 * @returns {BitArray}
 */
export function encode_value(value) {
  const encoder = new ETFEncoder();
  encoder.writeUint8(131); // ETF version byte
  encoder.encodeTerm(value);
  return new BitArray(new Uint8Array(encoder.result()));
}

/**
 * Decode a standalone Gleam value from an ETF binary. Symmetric with
 * `encode_value`. Custom type reconstruction is handled by the typed
 * decoder (rpc_decoders_ffi.mjs).
 * @param {DecoderInput} buffer
 * @returns {any}
 */
export function decode_value(buffer) {
  const decoder = new ETFDecoder(buffer);
  return decoder.decode();
}

/**
 * Raw variant of `decode_value`: atoms stay as strings and tagged
 * tuples stay as plain JS arrays. Used internally when the typed
 * decoder (`ensure_decoders`) will re-interpret the result.
 * @param {DecoderInput} buffer
 * @returns {any}
 */
export function decode_value_raw(buffer) {
  const decoder = new ETFDecoder(buffer, true);
  return decoder.decode();
}

/**
 * Safe variant of `decode_value` that returns a Result instead of
 * throwing. Used by the public `libero.wire.decode_safe` function.
 *
 * WireDecodeError is imported from the compiled error.mjs (generated from
 * error.gleam's DecodeError type), keeping the JS and Gleam definitions
 * in sync automatically.
 * @param {DecoderInput} buffer
 * @returns {any} Ok(value) or Error(DecodeError)
 */
export function decode_safe(buffer) {
  try {
    const decoder = new ETFDecoder(buffer);
    const value = decoder.decode();
    return new Ok(value);
  } catch (e) {
    const msg = e && /** @type {any} */ (e).message ? /** @type {any} */ (e).message : String(e);
    return new ResultError(new WireDecodeError(msg));
  }
}

/**
 * Raw variant of `decode_safe`: atoms stay as strings and tagged
 * tuples stay as plain JS arrays. Safe wrapper that returns Result.
 * Used by typed decoder entry points that need raw input for the
 * two-pass decode (raw ETF → typed decoder body).
 * @param {DecoderInput} buffer
 * @returns {any} Ok(raw_value) or Error(DecodeError)
 */
export function decode_safe_raw(buffer) {
  try {
    const raw = new ETFDecoder(buffer, true).decode();
    return new Ok(raw);
  } catch (e) {
    const msg = e && /** @type {any} */ (e).message ? /** @type {any} */ (e).message : String(e);
    return new ResultError(new WireDecodeError(msg));
  }
}

/**
 * Two-pass decode: raw ETF → typed decoder lookup.
 * Used by wire.decode_typed for SSR flags and other non-RPC paths
 * where the caller knows the expected type at codegen time.
 * @param {DecoderInput} buffer
 * @param {string} decoderName e.g. "decode_pages_home__model"
 * @returns {any} Ok(typed_value) or Error(DecodeError)
 */
export function decodeTypedWire(buffer, decoderName) {
  try {
    const raw = new ETFDecoder(buffer, true).decode();
    return new Ok(decodeTyped(raw, decoderName));
  } catch (e) {
    const msg = e && /** @type {any} */ (e).message ? /** @type {any} */ (e).message : String(e);
    return new ResultError(new WireDecodeError(msg));
  }
}

/**
 * Encode a request envelope: `{module_name, request_id, msg}` as ETF binary.
 * Symmetric with the server-side `wire.decode_request`. Returns a raw
 * ArrayBuffer (not a Gleam BitArray).
 * @param {string} module
 * @param {number} requestId
 * @param {any} msg
 * @returns {ArrayBuffer}
 */
export function encode_request(module, requestId, msg) {
  const encoder = new ETFEncoder();
  encoder.writeUint8(131); // ETF version byte
  // Envelope: {<<"module_name">>, request_id, msg_value}
  encoder.writeUint8(104); // SMALL_TUPLE_EXT
  encoder.writeUint8(3);   // arity 3
  encoder.encodeBinary(module);
  encoder.encodeTerm(requestId);
  encoder.encodeTerm(msg);
  return encoder.result();
}


/**
 * Normalize libero decode input: Gleam BitArray ({rawBuffer}) or raw binary.
 * Same normalization as ETFDecoder constructor.
 * @param {DecoderInput} input
 * @returns {Uint8Array}
 */
function normalizeInput(input) {
  if (input instanceof Uint8Array) return input;
  if (input instanceof ArrayBuffer) return new Uint8Array(input);
  if (input && /** @type {any} */ (input).rawBuffer instanceof Uint8Array) {
    return /** @type {any} */ (input).rawBuffer;
  }
  return new Uint8Array(/** @type {ArrayBuffer} */ (input));
}

/**
 * Decode a response frame: tag byte 0, 32-bit request ID, ETF payload.
 * Returns Ok([requestId, value]) or Error(DecodeError).
 * @param {DecoderInput} buffer
 * @returns {any} Gleam Result
 */
export function decode_response_frame(buffer) {
  try {
    const bytes = normalizeInput(buffer);
    if (bytes.length < 5) {
      return new ResultError(new WireDecodeError("invalid response frame: too short"));
    }
    if (bytes[0] !== 0) {
      return new ResultError(new WireDecodeError("invalid response frame: expected tag byte 0"));
    }
    // Read 32-bit big-endian unsigned (use >>> 0 to avoid signed overflow).
    const requestId = ((bytes[1] << 24) | (bytes[2] << 16) | (bytes[3] << 8) | bytes[4]) >>> 0;
    const payloadResult = decode_safe_raw(bytes.subarray(5));
    if (payloadResult instanceof Ok) {
      return new Ok([requestId, payloadResult[0]]);
    }
    return payloadResult;
  } catch (e) {
    const msg = e && /** @type {any} */ (e).message ? /** @type {any} */ (e).message : String(e);
    return new ResultError(new WireDecodeError(msg));
  }
}

/**
 * Decode a push frame: tag byte 1, ETF {module, value} tuple payload.
 * Returns Ok([module, value]) or Error(DecodeError).
 * @param {DecoderInput} buffer
 * @returns {any} Gleam Result
 */
export function decode_push_frame(buffer) {
  try {
    const bytes = normalizeInput(buffer);
    if (bytes.length < 2) {
      return new ResultError(new WireDecodeError("invalid push frame: too short"));
    }
    if (bytes[0] !== 1) {
      return new ResultError(new WireDecodeError("invalid push frame: expected tag byte 1"));
    }
    const payloadResult = decode_safe_raw(bytes.subarray(1));
    if (payloadResult instanceof Ok) {
      const value = payloadResult[0];
      if (Array.isArray(value) && value.length === 2
          && typeof value[0] === "string") {
        return new Ok([value[0], value[1]]);
      }
      return new ResultError(new WireDecodeError("invalid push frame payload: expected [module, value] tuple"));
    }
    return payloadResult;
  } catch (e) {
    const msg = e && /** @type {any} */ (e).message ? /** @type {any} */ (e).message : String(e);
    return new ResultError(new WireDecodeError(msg));
  }
}

/**
 * Decode any server-to-client frame into a tagged object.
 * This is the primary JS entry point for consumers: hand Libero the raw
 * WebSocket bytes and switch on frame.kind. Callers never inspect tag bytes.
 *
 * Returns Ok({ kind: "response", requestId, value }) for response frames,
 * Ok({ kind: "push", module, value }) for push frames,
 * or Error(DecodeError) on malformed input.
 *
 * @param {DecoderInput} buffer
 * @returns {any} Gleam Result
 */
export function decode_server_frame(buffer) {
  try {
    const bytes = normalizeInput(buffer);
    if (bytes.length < 1) {
      return new ResultError(new WireDecodeError("invalid server frame: empty"));
    }
    const tag = bytes[0];

    if (tag === 0) {
      if (bytes.length < 5) {
        return new ResultError(new WireDecodeError("invalid response frame: too short"));
      }
      const requestId = ((bytes[1] << 24) | (bytes[2] << 16) | (bytes[3] << 8) | bytes[4]) >>> 0;
      const payloadResult = decode_safe(bytes.subarray(5));
      if (payloadResult instanceof Ok) {
        return new Ok({ kind: "response", requestId, value: payloadResult[0] });
      }
      return payloadResult;
    }

    if (tag === 1) {
      const payloadResult = decode_safe_raw(bytes.subarray(1));
      if (payloadResult instanceof Ok) {
        const tuple = payloadResult[0];
        if (Array.isArray(tuple) && tuple.length === 2
            && typeof tuple[0] === "string") {
          return new Ok({ kind: "push", module: tuple[0], value: tuple[1] });
        }
        return new ResultError(new WireDecodeError("invalid push frame payload: expected [module, value] tuple"));
      }
      return payloadResult;
    }

    return new ResultError(new WireDecodeError("invalid server frame: unknown tag byte " + tag));
  } catch (e) {
    const msg = e && /** @type {any} */ (e).message ? /** @type {any} */ (e).message : String(e);
    return new ResultError(new WireDecodeError(msg));
  }
}
