//// Runtime helpers used by generated JSON decoders.
////
//// The Gleam fallback uses `gleam/dynamic/decode`. The JavaScript target
//// uses direct JS checks to avoid paying the dynamic decoder cost for every
//// envelope, constructor, and field lookup.

import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import libero/json/error.{type JsonError, JsonError}

@external(javascript, "./runtime_ffi.mjs", "field")
pub fn field(
  value value: Dynamic,
  name name: String,
  path path: String,
) -> Result(Dynamic, List(JsonError)) {
  case decode.run(value, decode.field(name, decode.dynamic, decode.success)) {
    Ok(raw) -> Ok(raw)
    Error(_) -> Error([JsonError(path, "missing")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "field_string")
pub fn field_string(
  value value: Dynamic,
  name name: String,
  path path: String,
) -> Result(String, List(JsonError)) {
  case decode.run(value, decode.field(name, decode.string, decode.success)) {
    Ok(raw) -> Ok(raw)
    Error(_) -> Error([JsonError(path, "missing or not a string")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "string")
pub fn string(
  value value: Dynamic,
  path path: String,
) -> Result(String, List(JsonError)) {
  case decode.run(value, decode.string) {
    Ok(raw) -> Ok(raw)
    Error(_) -> Error([JsonError(path, "expected String")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "int")
pub fn int(
  value value: Dynamic,
  path path: String,
) -> Result(Int, List(JsonError)) {
  case decode.run(value, decode.int) {
    Ok(raw) ->
      case raw >= -9_007_199_254_740_991 && raw <= 9_007_199_254_740_991 {
        True -> Ok(raw)
        False -> Error([JsonError(path, "expected Int in safe JSON range")])
      }
    Error(_) -> Error([JsonError(path, "expected Int")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "float")
pub fn float(
  value value: Dynamic,
  path path: String,
) -> Result(Float, List(JsonError)) {
  case decode.run(value, decode.float) {
    Ok(raw) -> Ok(raw)
    Error(_) -> Error([JsonError(path, "expected Float")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "bool")
pub fn bool(
  value value: Dynamic,
  path path: String,
) -> Result(Bool, List(JsonError)) {
  case decode.run(value, decode.bool) {
    Ok(raw) -> Ok(raw)
    Error(_) -> Error([JsonError(path, "expected Bool")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "nil")
pub fn nil(
  value value: Dynamic,
  path path: String,
) -> Result(Nil, List(JsonError)) {
  case decode.run(value, decode.optional(decode.dynamic)) {
    Ok(None) -> Ok(Nil)
    Ok(Some(_)) -> Error([JsonError(path, "expected null")])
    Error(_) -> Error([JsonError(path, "expected null")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "object_size")
pub fn object_size(
  value value: Dynamic,
  path path: String,
) -> Result(Int, List(JsonError)) {
  case decode.run(value, decode.dict(decode.string, decode.dynamic)) {
    Ok(field_map) -> Ok(dict.size(field_map))
    Error(_) -> Error([JsonError(path, "expected Object")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "array_length")
pub fn array_length(
  value value: Dynamic,
  path path: String,
) -> Result(Int, List(JsonError)) {
  case decode.run(value, decode.list(of: decode.dynamic)) {
    Ok(items) -> Ok(list.length(items))
    Error(_) -> Error([JsonError(path, "expected Array")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "list")
pub fn list(
  value value: Dynamic,
  path path: String,
) -> Result(List(Dynamic), List(JsonError)) {
  case decode.run(value, decode.list(of: decode.dynamic)) {
    Ok(items) -> Ok(items)
    Error(_) -> Error([JsonError(path, "expected Array")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "array_at")
pub fn array_at(
  value value: Dynamic,
  index index: Int,
  path path: String,
) -> Result(Dynamic, List(JsonError)) {
  case decode.run(value, decode.list(of: decode.dynamic)) {
    Ok(items) ->
      case list.drop(items, index) |> list.first {
        Ok(item) -> Ok(item)
        Error(_) -> Error([JsonError(path, "missing")])
      }
    Error(_) -> Error([JsonError(path, "expected Array")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "object_entries")
pub fn object_entries(
  value value: Dynamic,
  path path: String,
) -> Result(List(#(String, Dynamic)), List(JsonError)) {
  case decode.run(value, decode.dict(decode.string, decode.dynamic)) {
    Ok(entries) -> Ok(dict.to_list(entries))
    Error(_) -> Error([JsonError(path, "expected Dict")])
  }
}

@external(javascript, "./runtime_ffi.mjs", "pair_entries")
pub fn pair_entries(
  value value: Dynamic,
  path path: String,
) -> Result(List(#(Dynamic, Dynamic)), List(JsonError)) {
  case decode.run(value, decode.list(of: decode.dynamic)) {
    Ok(pairs_raw) ->
      list.try_map(pairs_raw, fn(pair_raw) {
        case decode.run(pair_raw, decode.list(of: decode.dynamic)) {
          Ok([k_raw, v_raw]) -> Ok(#(k_raw, v_raw))
          Ok(_) -> Error([JsonError(path, "expected [key, value] pair")])
          Error(_) -> Error([JsonError(path, "expected Array pair")])
        }
      })
    Error(_) -> Error([JsonError(path, "expected Array of pairs")])
  }
}

pub fn expected_size_error(
  path path: String,
  expected expected: Int,
  actual actual: Int,
) -> List(JsonError) {
  [
    JsonError(
      path,
      "expected "
        <> int.to_string(expected)
        <> " elements, got "
        <> int.to_string(actual),
    ),
  ]
}
