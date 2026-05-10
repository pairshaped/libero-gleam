//// JSON wire protocol: encode/decode, frame builders, SSR flags.
////
//// All encode functions take already-encoded `json.Json` values.
//// Generated typed encoders run first; this module wraps them in
//// protocol envelopes.
////
//// Produces/consumes `String` (JSON text), not `BitArray`.

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import libero/frame.{type ServerFrame}
import libero/json/error.{type JsonError, JsonError}

const json_rpc_v1 = "json-rpc-v1"

// ---------- Types ----------

pub type RequestEnvelope {
  RequestEnvelope(module: String, request_id: Int, message: Dynamic)
}

// ---------- Request ----------

pub fn encode_request(
  module module: String,
  request_id request_id: Int,
  msg msg: json.Json,
  contract_hash contract_hash: String,
) -> String {
  json.object([
    #("kind", json.string("request")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("contract_hash", json.string(contract_hash)),
    #("module", json.string(module)),
    #("request_id", json.int(request_id)),
    #("message", msg),
  ])
  |> json.to_string
}

pub fn decode_request(
  data data: String,
  expected_hash expected_hash: String,
) -> Result(RequestEnvelope, List(JsonError)) {
  use parsed <- result.try(parse_json(data))
  use _ <- result.try(validate_kind(parsed, "request"))
  use _ <- result.try(validate_protocol_version(parsed))
  use _ <- result.try(validate_contract_hash(parsed, expected_hash))

  use module <- result.try(required_string_field(parsed, "module"))
  use request_id <- result.try(required_int_field(parsed, "request_id"))
  use message <- result.try(required_dynamic_field(parsed, "message"))

  Ok(RequestEnvelope(module:, request_id:, message:))
}

// ---------- Response ----------

pub fn encode_response(
  request_id request_id: Int,
  value value: json.Json,
) -> String {
  json.object([
    #("kind", json.string("response")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("request_id", json.int(request_id)),
    #("value", value),
  ])
  |> json.to_string
}

// ---------- Error ----------

pub fn encode_error(
  request_id request_id: Option(Int),
  errors errors: List(JsonError),
) -> String {
  let rid = case request_id {
    Some(id) -> json.int(id)
    None -> json.null()
  }
  json.object([
    #("kind", json.string("error")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("request_id", rid),
    #(
      "errors",
      json.array(from: errors, of: fn(e) {
        json.object([
          #("path", json.string(e.path)),
          #("message", json.string(e.message)),
        ])
      }),
    ),
  ])
  |> json.to_string
}

// ---------- Push ----------

pub fn encode_push(module module: String, value value: json.Json) -> String {
  json.object([
    #("kind", json.string("push")),
    #("protocol_version", json.string(json_rpc_v1)),
    #("module", json.string(module)),
    #("value", value),
  ])
  |> json.to_string
}

// ---------- Server frame decode ----------

pub fn decode_server_frame(
  data data: String,
) -> Result(ServerFrame(Dynamic), List(JsonError)) {
  use parsed <- result.try(parse_json(data))
  use _ <- result.try(validate_protocol_version(parsed))

  use kind <- result.try(required_string_field(parsed, "kind"))

  case kind {
    "response" -> decode_response_frame_body(parsed)
    "push" -> decode_push_frame_body(parsed)
    "error" -> decode_error_frame_body(parsed)
    _ -> Error([JsonError("kind", "unknown frame kind: " <> kind)])
  }
}

fn decode_response_frame_body(
  parsed: Dynamic,
) -> Result(ServerFrame(Dynamic), List(JsonError)) {
  use request_id <- result.try(required_int_field(parsed, "request_id"))
  use value <- result.try(required_dynamic_field(parsed, "value"))

  Ok(frame.Response(request_id:, value:))
}

fn decode_push_frame_body(
  parsed: Dynamic,
) -> Result(ServerFrame(Dynamic), List(JsonError)) {
  use module <- result.try(required_string_field(parsed, "module"))
  use value <- result.try(required_dynamic_field(parsed, "value"))

  Ok(frame.Push(module:, value:))
}

fn decode_error_frame_body(
  parsed: Dynamic,
) -> Result(ServerFrame(Dynamic), List(JsonError)) {
  let request_id = optional_int_field(parsed, "request_id")
  use errors <- result.try(error_list_field(parsed, "errors"))

  Ok(frame.Error(request_id:, errors:))
}

// ---------- SSR flags ----------

pub fn encode_flags(value: json.Json) -> String {
  let json_str = json.to_string(value)
  escape_script_json(json_str)
}

pub fn decode_flags_typed(
  flags flags: String,
  decoder decoder: fn(Dynamic) -> Result(a, List(JsonError)),
) -> Result(a, List(JsonError)) {
  use parsed <- result.try(parse_json(flags))
  decoder(parsed)
}

// ---------- JSON parsing ----------

fn parse_json(data: String) -> Result(Dynamic, List(JsonError)) {
  case json.parse(from: data, using: decode.dynamic) {
    Ok(v) -> Ok(v)
    Error(_) -> Error([JsonError("", "failed to parse JSON")])
  }
}

// ---------- Validation helpers ----------

fn validate_kind(
  parsed: Dynamic,
  expected: String,
) -> Result(Nil, List(JsonError)) {
  case required_string_field(parsed, "kind") {
    Ok(s) if s == expected -> Ok(Nil)
    Ok(s) ->
      Error([
        JsonError(
          "kind",
          "expected \"" <> expected <> "\", got \"" <> s <> "\"",
        ),
      ])
    Error(errors) -> Error(errors)
  }
}

fn validate_protocol_version(parsed: Dynamic) -> Result(Nil, List(JsonError)) {
  case required_string_field(parsed, "protocol_version") {
    Ok(s) if s == json_rpc_v1 -> Ok(Nil)
    Ok(s) ->
      Error([JsonError("protocol_version", "unsupported version: " <> s)])
    Error(errors) -> Error(errors)
  }
}

fn validate_contract_hash(
  parsed: Dynamic,
  expected_hash: String,
) -> Result(Nil, List(JsonError)) {
  case required_string_field(parsed, "contract_hash") {
    Ok(s) if s == expected_hash -> Ok(Nil)
    Ok(_) -> Error([JsonError("contract_hash", "contract hash mismatch")])
    Error(errors) -> Error(errors)
  }
}

// ---------- Field extraction helpers (using gleam/dynamic/decode) ----------

fn required_string_field(
  parsed: Dynamic,
  name: String,
) -> Result(String, List(JsonError)) {
  let decoder = decode.field(name, decode.string, decode.success)
  case decode.run(parsed, decoder) {
    Ok(s) -> Ok(s)
    Error(errors) -> {
      let found = case errors {
        [decode.DecodeError(_, found, _), ..] -> found
        _ -> "unknown"
      }
      Error([JsonError(name, "expected String, got " <> found)])
    }
  }
}

fn required_int_field(
  parsed: Dynamic,
  name: String,
) -> Result(Int, List(JsonError)) {
  let decoder = decode.field(name, decode.int, decode.success)
  case decode.run(parsed, decoder) {
    Ok(n) -> {
      case n >= -9_007_199_254_740_991 && n <= 9_007_199_254_740_991 {
        True -> Ok(n)
        False ->
          Error([JsonError(name, "Int outside JavaScript safe integer range")])
      }
    }
    Error(errors) -> {
      let found = case errors {
        [decode.DecodeError(_, found, _), ..] -> found
        _ -> "unknown"
      }
      Error([JsonError(name, "expected Int, got " <> found)])
    }
  }
}

fn required_dynamic_field(
  parsed: Dynamic,
  name: String,
) -> Result(Dynamic, List(JsonError)) {
  let decoder = decode.field(name, decode.dynamic, decode.success)
  case decode.run(parsed, decoder) {
    Ok(v) -> Ok(v)
    Error(_) -> Error([JsonError(name, "required field missing")])
  }
}

fn optional_int_field(parsed: Dynamic, name: String) -> Option(Int) {
  let decoder = decode.field(name, decode.dynamic, decode.success)
  case decode.run(parsed, decoder) {
    Ok(dyn) ->
      case decode.run(dyn, decode.optional(decode.int)) {
        Ok(Some(n)) -> Some(n)
        _ -> None
      }
    Error(_) -> None
  }
}

fn error_list_field(
  parsed: Dynamic,
  name: String,
) -> Result(List(#(String, String)), List(JsonError)) {
  let decoder =
    decode.field(name, decode.list(of: decode.dynamic), decode.success)
  case decode.run(parsed, decoder) {
    Ok(items) -> {
      let errors =
        list.map(items, fn(item) {
          let path = case
            decode.run(
              item,
              decode.field("path", decode.string, decode.success),
            )
          {
            Ok(s) -> s
            _ -> ""
          }
          let message = case
            decode.run(
              item,
              decode.field("message", decode.string, decode.success),
            )
          {
            Ok(s) -> s
            _ -> "unknown error"
          }
          #(path, message)
        })
      Ok(errors)
    }
    Error(errors) -> {
      let found = case errors {
        [decode.DecodeError(_, found, _), ..] -> found
        _ -> "unknown"
      }
      Error([JsonError(name, "expected Array, got " <> found)])
    }
  }
}

// ---------- HTML escaping for SSR ----------

fn escape_script_json(input: String) -> String {
  input
  |> string.replace("<", "\\u003c")
  |> string.replace(">", "\\u003e")
  |> string.replace("&", "\\u0026")
  |> string.replace("\u{2028}", "\\u2028")
  |> string.replace("\u{2029}", "\\u2029")
}
