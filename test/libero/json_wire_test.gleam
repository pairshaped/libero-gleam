import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import libero/json/error.{JsonError}
import libero/json/wire

pub fn encode_request_produces_correct_shape_test() {
  let message =
    json.object([
      #("type", json.string("shared/messages.MsgFromClient")),
      #("variant", json.string("GetArticle")),
      #("fields", json.object([#("slug", json.string("hello-world"))])),
    ])

  let encoded =
    wire.encode_request(
      module: "rpc",
      request_id: 1,
      msg: message,
      contract_hash: "abc123",
    )

  string.contains(encoded, "\"kind\"") |> should.be_true()
  string.contains(encoded, "\"request\"") |> should.be_true()
  string.contains(encoded, "\"protocol_version\"") |> should.be_true()
  string.contains(encoded, "json-rpc-v1") |> should.be_true()
  string.contains(encoded, "\"contract_hash\"") |> should.be_true()
  string.contains(encoded, "abc123") |> should.be_true()
  string.contains(encoded, "\"module\"") |> should.be_true()
  string.contains(encoded, "\"rpc\"") |> should.be_true()
  string.contains(encoded, "\"request_id\"") |> should.be_true()
  string.contains(encoded, "\"message\"") |> should.be_true()
}

pub fn encode_response_produces_correct_shape_test() {
  let value =
    json.object([
      #("type", json.string("gleam/result.Result")),
      #("variant", json.string("Ok")),
      #("fields", json.array(from: [json.string("done")], of: fn(x) { x })),
    ])

  let encoded = wire.encode_response(request_id: 1, value:)

  string.contains(encoded, "\"kind\"") |> should.be_true()
  string.contains(encoded, "\"response\"") |> should.be_true()
  string.contains(encoded, "\"request_id\"") |> should.be_true()
  string.contains(encoded, "\"value\"") |> should.be_true()
}

pub fn encode_error_produces_correct_shape_test() {
  let errors = [
    JsonError(path: "message.fields.slug", message: "expected String, got Null"),
  ]

  let encoded = wire.encode_error(request_id: Some(1), errors:)

  string.contains(encoded, "\"kind\"") |> should.be_true()
  string.contains(encoded, "\"error\"") |> should.be_true()
  string.contains(encoded, "\"errors\"") |> should.be_true()
}

pub fn encode_push_produces_correct_shape_test() {
  let value =
    json.object([
      #("type", json.string("public/pages/article.ToClient")),
      #("variant", json.string("CommentsUpdated")),
      #(
        "fields",
        json.object([#("comments", json.array(from: [], of: json.string))]),
      ),
    ])

  let encoded = wire.encode_push(module: "public/pages/article", value:)

  string.contains(encoded, "\"kind\"") |> should.be_true()
  string.contains(encoded, "\"push\"") |> should.be_true()
  string.contains(encoded, "\"module\"") |> should.be_true()
  string.contains(encoded, "\"value\"") |> should.be_true()
}

pub fn encode_flags_escapes_html_unsafe_chars_test() {
  let value = json.string("</script>alert('xss')</script>")

  let encoded = wire.encode_flags(value)

  string.contains(encoded, "<") |> should.be_false()
  string.contains(encoded, ">") |> should.be_false()
}

pub fn decode_server_frame_handles_unknown_kind_test() {
  let data = "{\"kind\":\"unknown\",\"protocol_version\":\"json-rpc-v1\"}"

  let result = wire.decode_server_frame(data)

  case result {
    Error(errors) -> {
      errors |> should.not_equal([])
    }
    Ok(_) -> should.fail()
  }
}

pub fn decode_request_validates_contract_hash_test() {
  let data =
    "{
    \"kind\": \"request\",
    \"protocol_version\": \"json-rpc-v1\",
    \"contract_hash\": \"wrong-hash\",
    \"module\": \"rpc\",
    \"request_id\": 1,
    \"message\": {\"type\":\"t\",\"variant\":\"v\",\"fields\":{}}
  }"

  let result = wire.decode_request(data, expected_hash: "abc123")

  case result {
    Error(errors) -> {
      let paths = list.map(errors, fn(e) { e.path })
      list.any(paths, fn(p) { string.contains(p, "contract_hash") })
      |> should.be_true()
    }
    Ok(_) -> should.fail()
  }
}
