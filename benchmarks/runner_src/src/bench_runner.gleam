import bench_etf_helpers as etf_helpers
import bench_etf_request_helpers
import bench_payloads
import bench_requests
import bench_timing
import generated/libero/json_codecs
import gleam/bit_array
import gleam/dynamic
import gleam/io
import gleam/json
import libero/etf/wire as etf_wire
import libero/json/error.{type JsonError}
import libero/json/wire as json_wire

const contract_hash = "CONTRACT_HASH"

pub fn main() {
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
    json_message: fn(value) {
      json_codecs.json_encode_bench_requests__request_msg(
        bench_requests.LoadAdmin(value),
      )
    },
    json_decode_message: json_codecs.json_decode_bench_requests__request_msg,
    etf_response: fn(value) { etf_helpers.encode_response_admin(Ok(value)) },
    etf_message: bench_etf_request_helpers.load_admin,
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
    json_message: fn(value) {
      json_codecs.json_encode_bench_requests__request_msg(
        bench_requests.LoadRecords(value),
      )
    },
    json_decode_message: json_codecs.json_decode_bench_requests__request_msg,
    etf_response: fn(value) { etf_helpers.encode_response_records(Ok(value)) },
    etf_message: bench_etf_request_helpers.load_records,
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
    json_message: fn(value) {
      json_codecs.json_encode_bench_requests__request_msg(
        bench_requests.LoadGame(value),
      )
    },
    json_decode_message: json_codecs.json_decode_bench_requests__request_msg,
    etf_response: fn(value) { etf_helpers.encode_response_game(Ok(value)) },
    etf_message: bench_etf_request_helpers.load_game,
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
    json_message: fn(value) {
      json_codecs.json_encode_bench_requests__request_msg(
        bench_requests.LoadShots(value),
      )
    },
    json_decode_message: json_codecs.json_decode_bench_requests__request_msg,
    etf_response: fn(value) { etf_helpers.encode_response_shots(Ok(value)) },
    etf_message: bench_etf_request_helpers.load_shots,
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
    json_message: fn(value) {
      json_codecs.json_encode_bench_requests__request_msg(
        bench_requests.LoadMatrix(value),
      )
    },
    json_decode_message: json_codecs.json_decode_bench_requests__request_msg,
    etf_response: fn(value) { etf_helpers.encode_response_matrix(Ok(value)) },
    etf_message: bench_etf_request_helpers.load_matrix,
  )
}

fn run_case(
  name name: String,
  payload payload: payload,
  iterations iterations: Int,
  json_response json_response: fn(payload) -> json.Json,
  json_message json_message: fn(payload) -> json.Json,
  json_decode_message json_decode_message: fn(dynamic.Dynamic) ->
    Result(bench_requests.RequestMsg, List(JsonError)),
  etf_response etf_response: fn(payload) -> dynamic.Dynamic,
  etf_message etf_message: fn(payload) -> dynamic.Dynamic,
) {
  let json_response_frame =
    json_wire.encode_response(request_id: 1, value: json_response(payload))
  let etf_response_frame =
    etf_wire.encode_response(request_id: 1, value: etf_response(payload))

  let json_request =
    json_wire.encode_request(
      module: "libero",
      request_id: 1,
      msg: json_message(payload),
      contract_hash:,
    )
  let etf_request =
    etf_wire.encode_request(
      module: "libero",
      request_id: 1,
      msg: etf_message(payload),
    )

  print(
    bench_timing.run(
      target: "beam",
      codec: "json",
      stage: "server_response_encode",
      payload: name,
      iterations:,
      bytes: string_bytes(json_response_frame),
      operation: fn() {
        json_wire.encode_response(request_id: 1, value: json_response(payload))
        |> string_bytes
      },
    ),
  )
  print(
    bench_timing.run(
      target: "beam",
      codec: "etf",
      stage: "server_response_encode",
      payload: name,
      iterations:,
      bytes: bit_array.byte_size(etf_response_frame),
      operation: fn() {
        etf_wire.encode_response(request_id: 1, value: etf_response(payload))
        |> bit_array.byte_size
      },
    ),
  )

  print(
    bench_timing.run(
      target: "beam",
      codec: "json",
      stage: "server_request_decode",
      payload: name,
      iterations:,
      bytes: string_bytes(json_request),
      operation: fn() {
        let assert Ok(envelope) =
          json_wire.decode_request(json_request, expected_hash: contract_hash)
        let assert Ok(_) = json_decode_message(envelope.message)
        envelope.request_id
      },
    ),
  )
  print(
    bench_timing.run(
      target: "beam",
      codec: "etf",
      stage: "server_request_decode",
      payload: name,
      iterations:,
      bytes: bit_array.byte_size(etf_request),
      operation: fn() {
        let assert Ok(#(_, request_id, message)) =
          etf_wire.decode_request(etf_request)
        let _ = etf_helpers.decode_request_msg(message)
        request_id
      },
    ),
  )

  print(
    bench_timing.run(
      target: "beam",
      codec: "etf_full_data_precheck",
      stage: "server_request_decode",
      payload: name,
      iterations:,
      bytes: bit_array.byte_size(etf_request),
      operation: fn() {
        let assert Ok(#(_, request_id, message)) =
          etf_wire.decode_request(etf_request)
        let _ = etf_helpers.validate_data_term(message)
        let _ = etf_helpers.decode_request_msg(message)
        request_id
      },
    ),
  )

  etf_wire.set_strict_data_terms(True)
  print(
    bench_timing.run(
      target: "beam",
      codec: "etf_strict_data_terms",
      stage: "server_request_decode",
      payload: name,
      iterations:,
      bytes: bit_array.byte_size(etf_request),
      operation: fn() {
        let assert Ok(#(_, request_id, message)) =
          etf_wire.decode_request(etf_request)
        let _ = etf_helpers.decode_request_msg(message)
        request_id
      },
    ),
  )
  etf_wire.set_strict_data_terms(False)
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
