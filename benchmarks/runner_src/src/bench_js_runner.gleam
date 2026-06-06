import bench_payloads
import bench_timing
import generated/libero/decoders
import generated/libero/json_codecs
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode
import gleam/io
import gleam/json
import libero/etf/wire as etf_wire
import libero/frame
import libero/json/error.{type JsonError}
import libero/json/wire as json_wire
import shared/bench.{type BenchError}

pub fn main() {
  let _ = decoders.ensure_decoders()
  io.println(bench_timing.csv_header())
  run_admin()
  run_records()
  run_game()
  run_shots()
  run_matrix()
}

fn run_admin() {
  let bench_payloads.PayloadCase(name, payload, iterations) =
    bench_payloads.admin_case()
  run_case(
    name:,
    payload:,
    iterations:,
    json_response: fn(value) { json_response_admin(Ok(value)) },
    json_decode_ok: json_codecs.json_decode_shared_bench__admin_summary,
    etf_response_value: fn(value) { Ok(value) },
  )
}

fn run_records() {
  let bench_payloads.PayloadCase(name, payload, iterations) =
    bench_payloads.records_case()
  run_case(
    name:,
    payload:,
    iterations:,
    json_response: fn(value) { json_response_records(Ok(value)) },
    json_decode_ok: json_codecs.json_decode_shared_bench__record_page,
    etf_response_value: fn(value) { Ok(value) },
  )
}

fn run_game() {
  let bench_payloads.PayloadCase(name, payload, iterations) =
    bench_payloads.game_case()
  run_case(
    name:,
    payload:,
    iterations:,
    json_response: fn(value) { json_response_game(Ok(value)) },
    json_decode_ok: json_codecs.json_decode_shared_bench__game_data,
    etf_response_value: fn(value) { Ok(value) },
  )
}

fn run_shots() {
  let bench_payloads.PayloadCase(name, payload, iterations) =
    bench_payloads.shots_case()
  run_case(
    name:,
    payload:,
    iterations:,
    json_response: fn(value) { json_response_shots(Ok(value)) },
    json_decode_ok: json_codecs.json_decode_shared_bench__shot_payload,
    etf_response_value: fn(value) { Ok(value) },
  )
}

fn run_matrix() {
  let bench_payloads.PayloadCase(name, payload, iterations) =
    bench_payloads.matrix_case()
  run_case(
    name:,
    payload:,
    iterations:,
    json_response: fn(value) { json_response_matrix(Ok(value)) },
    json_decode_ok: json_codecs.json_decode_shared_bench__type_matrix,
    etf_response_value: fn(value) { Ok(value) },
  )
}

fn run_case(
  name name: String,
  payload payload: payload,
  iterations iterations: Int,
  json_response json_response: fn(payload) -> json.Json,
  json_decode_ok json_decode_ok: fn(dynamic.Dynamic) ->
    Result(payload, List(JsonError)),
  etf_response_value etf_response_value: fn(payload) ->
    Result(payload, BenchError),
) {
  let json_response_frame =
    json_wire.encode_response(request_id: 1, value: json_response(payload))
  let etf_response_frame =
    etf_wire.encode_response(request_id: 1, value: etf_response_value(payload))
  let assert Ok(json_decoded_frame) =
    json_wire.decode_server_frame(json_response_frame)
  let assert Ok(json_response_value) = response_value(json_decoded_frame)

  print(
    bench_timing.run(
      target: "js",
      codec: "json",
      stage: "client_response_parse_only",
      payload: name,
      iterations:,
      bytes: string_bytes(json_response_frame),
      operation: fn() {
        let assert Ok(_) =
          json.parse(from: json_response_frame, using: decode.dynamic)
        1
      },
    ),
  )
  print(
    bench_timing.run(
      target: "js",
      codec: "json",
      stage: "client_response_wire_decode",
      payload: name,
      iterations:,
      bytes: string_bytes(json_response_frame),
      operation: fn() { decode_json_response_frame(json_response_frame) },
    ),
  )
  print(
    bench_timing.run(
      target: "js",
      codec: "json",
      stage: "client_response_typed_decode",
      payload: name,
      iterations:,
      bytes: string_bytes(json_response_frame),
      operation: fn() {
        decode_json_response_value(json_response_value, json_decode_ok)
      },
    ),
  )
  print(
    bench_timing.run(
      target: "js",
      codec: "json",
      stage: "client_response_decode",
      payload: name,
      iterations:,
      bytes: string_bytes(json_response_frame),
      operation: fn() {
        decode_json_response(json_response_frame, json_decode_ok)
      },
    ),
  )
  print(
    bench_timing.run(
      target: "js",
      codec: "etf",
      stage: "client_response_decode",
      payload: name,
      iterations:,
      bytes: bit_array.byte_size(etf_response_frame),
      operation: fn() { decode_etf_response(etf_response_frame) },
    ),
  )

  etf_wire.set_js_term_depth_limit(512)
  print(
    bench_timing.run(
      target: "js",
      codec: "etf_depth_limit",
      stage: "client_response_decode",
      payload: name,
      iterations:,
      bytes: bit_array.byte_size(etf_response_frame),
      operation: fn() { decode_etf_response(etf_response_frame) },
    ),
  )
  etf_wire.set_js_term_depth_limit(0)
}

fn decode_json_response(
  response: String,
  decode_ok: fn(dynamic.Dynamic) -> Result(payload, List(JsonError)),
) -> Int {
  let assert Ok(decoded) = json_wire.decode_server_frame(response)
  let assert Ok(value) = response_value(decoded)
  decode_json_response_value(value, decode_ok)
}

fn decode_json_response_frame(response: String) -> Int {
  let assert Ok(decoded) = json_wire.decode_server_frame(response)
  case decoded {
    frame.Response(request_id:, value: _) -> request_id
    _ -> 0
  }
}

fn decode_json_response_value(
  value: dynamic.Dynamic,
  decode_ok: fn(dynamic.Dynamic) -> Result(payload, List(JsonError)),
) -> Int {
  let assert Ok(_) =
    json_codecs.json_decode_gleam_result__result(
      value,
      decode_ok,
      json_codecs.json_decode_shared_bench__bench_error,
    )
  1
}

fn response_value(
  decoded: frame.ServerFrame(dynamic.Dynamic),
) -> Result(dynamic.Dynamic, Nil) {
  case decoded {
    frame.Response(request_id: _, value:) -> Ok(value)
    _ -> Error(Nil)
  }
}

fn decode_etf_response(response: BitArray) -> Int {
  let assert Ok(decoded) = etf_wire.decode_server_frame(response)
  case decoded {
    frame.Response(request_id:, value: _) -> request_id
    _ -> 0
  }
}

fn print(result: bench_timing.BenchResult) {
  io.println(bench_timing.to_csv(result))
}

fn json_response_admin(value) -> json.Json {
  json_codecs.json_encode_gleam_result__result(
    value,
    json_codecs.json_encode_shared_bench__admin_summary,
    json_codecs.json_encode_shared_bench__bench_error,
  )
}

fn json_response_records(value) -> json.Json {
  json_codecs.json_encode_gleam_result__result(
    value,
    json_codecs.json_encode_shared_bench__record_page,
    json_codecs.json_encode_shared_bench__bench_error,
  )
}

fn json_response_game(value) -> json.Json {
  json_codecs.json_encode_gleam_result__result(
    value,
    json_codecs.json_encode_shared_bench__game_data,
    json_codecs.json_encode_shared_bench__bench_error,
  )
}

fn json_response_shots(value) -> json.Json {
  json_codecs.json_encode_gleam_result__result(
    value,
    json_codecs.json_encode_shared_bench__shot_payload,
    json_codecs.json_encode_shared_bench__bench_error,
  )
}

fn json_response_matrix(value) -> json.Json {
  json_codecs.json_encode_gleam_result__result(
    value,
    json_codecs.json_encode_shared_bench__type_matrix,
    json_codecs.json_encode_shared_bench__bench_error,
  )
}

fn string_bytes(value: String) -> Int {
  value
  |> bit_array.from_string
  |> bit_array.byte_size
}
