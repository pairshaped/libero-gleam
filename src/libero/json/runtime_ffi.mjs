// @ts-check

import { Ok, Error as ResultError, Empty, NonEmpty, toList } from "../../../gleam_stdlib/gleam.mjs";
import { JsonError } from "./error.mjs";

function errorResult(path, message) {
  return new ResultError(
    new NonEmpty(new JsonError(path, message), new Empty()),
  );
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function hasOwn(value, key) {
  return Object.prototype.hasOwnProperty.call(value, key);
}

export function field(value, name, path) {
  if (isObject(value) && hasOwn(value, name)) {
    return new Ok(value[name]);
  }

  return errorResult(path, "missing");
}

export function field_string(value, name, path) {
  if (isObject(value) && typeof value[name] === "string") {
    return new Ok(value[name]);
  }

  return errorResult(path, "missing or not a string");
}

export function string(value, path) {
  if (typeof value === "string") {
    return new Ok(value);
  }

  return errorResult(path, "expected String");
}

export function int(value, path) {
  if (
    Number.isSafeInteger(value) &&
    value >= -9_007_199_254_740_991 &&
    value <= 9_007_199_254_740_991
  ) {
    return new Ok(value);
  }

  return errorResult(path, "expected Int");
}

export function float(value, path) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return new Ok(value);
  }

  return errorResult(path, "expected Float");
}

export function bool(value, path) {
  if (typeof value === "boolean") {
    return new Ok(value);
  }

  return errorResult(path, "expected Bool");
}

export function nil(value, path) {
  if (value === null) {
    return new Ok(undefined);
  }

  return errorResult(path, "expected null");
}

export function object_size(value, path) {
  if (isObject(value)) {
    return new Ok(Object.keys(value).length);
  }

  return errorResult(path, "expected Object");
}

export function array_length(value, path) {
  if (Array.isArray(value)) {
    return new Ok(value.length);
  }

  return errorResult(path, "expected Array");
}

export function list(value, path) {
  if (Array.isArray(value)) {
    return new Ok(toList(value));
  }

  return errorResult(path, "expected Array");
}

export function array_at(value, index, path) {
  if (!Array.isArray(value)) {
    return errorResult(path, "expected Array");
  }

  if (index >= 0 && index < value.length) {
    return new Ok(value[index]);
  }

  return errorResult(path, "missing");
}

export function object_entries(value, path) {
  if (!isObject(value)) {
    return errorResult(path, "expected Dict");
  }

  return new Ok(toList(Object.keys(value).map((key) => [key, value[key]])));
}

export function pair_entries(value, path) {
  if (!Array.isArray(value)) {
    return errorResult(path, "expected Array of pairs");
  }

  const pairs = [];
  for (const pair of value) {
    if (!Array.isArray(pair)) {
      return errorResult(path, "expected Array pair");
    }

    if (pair.length !== 2) {
      return errorResult(path, "expected [key, value] pair");
    }

    pairs.push([pair[0], pair[1]]);
  }

  return new Ok(toList(pairs));
}
