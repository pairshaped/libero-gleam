import gleam/dynamic.{type Dynamic}
import shared/bench.{
  type AdminSummary, type BenchError, type GameData, type RecordPage,
  type ShotPayload, type TypeMatrix,
}

@external(erlang, "generated@libero_wire", "encode_response_load_admin")
pub fn encode_response_load_admin(
  value: Result(AdminSummary, BenchError),
) -> Dynamic

@external(erlang, "generated@libero_wire", "encode_response_load_records")
pub fn encode_response_load_records(
  value: Result(RecordPage, BenchError),
) -> Dynamic

@external(erlang, "generated@libero_wire", "encode_response_load_game")
pub fn encode_response_load_game(value: Result(GameData, BenchError)) -> Dynamic

@external(erlang, "generated@libero_wire", "encode_response_load_shots")
pub fn encode_response_load_shots(
  value: Result(ShotPayload, BenchError),
) -> Dynamic

@external(erlang, "generated@libero_wire", "encode_response_load_matrix")
pub fn encode_response_load_matrix(
  value: Result(TypeMatrix, BenchError),
) -> Dynamic

@external(erlang, "generated@libero_wire", "decode_request_msg")
pub fn decode_request_msg(value: Dynamic) -> Dynamic

@external(erlang, "libero_etf_ffi", "validate_data_term")
pub fn validate_data_term(value: Dynamic) -> Dynamic
