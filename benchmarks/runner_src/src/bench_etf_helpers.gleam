import gleam/dynamic.{type Dynamic}
import shared/bench.{
  type AdminSummary, type BenchError, type GameData, type RecordPage,
  type ShotPayload, type TypeMatrix,
}

@external(erlang, "bench_etf_helpers_ffi", "encode_response_admin")
pub fn encode_response_admin(value: Result(AdminSummary, BenchError)) -> Dynamic

@external(erlang, "bench_etf_helpers_ffi", "encode_response_records")
pub fn encode_response_records(value: Result(RecordPage, BenchError)) -> Dynamic

@external(erlang, "bench_etf_helpers_ffi", "encode_response_game")
pub fn encode_response_game(value: Result(GameData, BenchError)) -> Dynamic

@external(erlang, "bench_etf_helpers_ffi", "encode_response_shots")
pub fn encode_response_shots(value: Result(ShotPayload, BenchError)) -> Dynamic

@external(erlang, "bench_etf_helpers_ffi", "encode_response_matrix")
pub fn encode_response_matrix(value: Result(TypeMatrix, BenchError)) -> Dynamic

@external(erlang, "generated@libero_wire", "decode_bench_requests__request_msg")
pub fn decode_request_msg(value: Dynamic) -> Dynamic

@external(erlang, "libero_etf_ffi", "validate_data_term")
pub fn validate_data_term(value: Dynamic) -> Dynamic
