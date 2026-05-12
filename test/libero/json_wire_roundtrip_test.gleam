import gleam/json
import gleam/list
import gleam/option.{Some}
import gleam/string
import gleeunit/should
import libero/frame
import libero/json/error.{JsonError}
import libero/json/wire

pub fn request_encode_then_decode_roundtrip_test() {
  let message =
    json.object([
      #("type", json.string("shared/messages.MsgFromClient")),
      #("variant", json.string("GetArticle")),
      #("fields", json.object([#("slug", json.string("hello-world"))])),
    ])

  let encoded =
    wire.encode_request(
      module: "rpc",
      request_id: 42,
      msg: message,
      contract_hash: "test-hash",
    )

  let decoded = wire.decode_request(encoded, expected_hash: "test-hash")

  case decoded {
    Ok(wire.RequestEnvelope(module:, request_id:, message: _)) -> {
      module |> should.equal("rpc")
      request_id |> should.equal(42)
    }
    Error(_errors) -> should.fail()
  }
}

pub fn response_roundtrip_test() {
  let value =
    json.object([
      #("type", json.string("gleam/result.Result")),
      #("variant", json.string("Ok")),
      #("fields", json.array([json.string("done")], of: fn(x) { x })),
    ])

  let encoded = wire.encode_response(request_id: 1, value:)

  case wire.decode_server_frame(encoded) {
    Ok(frame.Response(request_id: 1, value: _)) -> Nil
    other -> {
      let _ = other
      should.fail()
    }
  }
}

pub fn push_roundtrip_test() {
  let value =
    json.object([
      #("type", json.string("public/pages/article.ToClient")),
      #("variant", json.string("CommentsUpdated")),
      #("fields", json.object([#("comments", json.array([], of: json.string))])),
    ])

  let encoded = wire.encode_push(module: "public/pages/article", value:)

  case wire.decode_server_frame(encoded) {
    Ok(frame.Push(module: "public/pages/article", value: _)) -> Nil
    other -> {
      let _ = other
      should.fail()
    }
  }
}

pub fn error_roundtrip_test() {
  let errors = [
    JsonError(path: "fields.slug", message: "expected String, got Null"),
  ]

  let encoded = wire.encode_error(request_id: Some(1), errors:)

  case wire.decode_server_frame(encoded) {
    Ok(frame.Error(request_id: Some(1), errors:)) ->
      errors |> should.equal([#("fields.slug", "expected String, got Null")])
    other -> {
      let _ = other
      should.fail()
    }
  }
}

pub fn protocol_version_mismatch_test() {
  let data =
    "{\"kind\":\"request\",\"protocol_version\":\"json-rpc-v2\",\"module\":\"rpc\",\"request_id\":1,\"message\":{}}"

  case wire.decode_request(data, expected_hash: "any") {
    Error(errors) -> {
      list.any(errors, fn(e) {
        string.contains(e.message, "unsupported version")
      })
      |> should.be_true()
    }
    Ok(_) -> should.fail()
  }
}

pub fn decode_server_frame_unknown_kind_test() {
  let data = "{\"kind\":\"unknown\",\"protocol_version\":\"json-rpc-v1\"}"

  case wire.decode_server_frame(data) {
    Error(errors) -> {
      list.any(errors, fn(e) {
        string.contains(e.message, "unknown frame kind")
      })
      |> should.be_true()
    }
    Ok(_) -> should.fail()
  }
}
