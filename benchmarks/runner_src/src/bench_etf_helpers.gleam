import gleam/dynamic.{type Dynamic}
import shared/bench.{
  type AdminSummary, type BenchError, type GameData, type RecordPage,
  type ShotPayload, type TypeMatrix,
}

@external(erlang, "generated@rpc_wire", "encode_response_load_admin")
pub fn encode_response_load_admin(
  value: Result(AdminSummary, BenchError),
) -> Dynamic

@external(erlang, "generated@rpc_wire", "encode_response_load_records")
pub fn encode_response_load_records(
  value: Result(RecordPage, BenchError),
) -> Dynamic

@external(erlang, "generated@rpc_wire", "encode_response_load_game")
pub fn encode_response_load_game(value: Result(GameData, BenchError)) -> Dynamic

@external(erlang, "generated@rpc_wire", "encode_response_load_shots")
pub fn encode_response_load_shots(
  value: Result(ShotPayload, BenchError),
) -> Dynamic

@external(erlang, "generated@rpc_wire", "encode_response_load_matrix")
pub fn encode_response_load_matrix(
  value: Result(TypeMatrix, BenchError),
) -> Dynamic

@external(erlang, "generated@rpc_wire", "decode_client_msg")
pub fn decode_client_msg(value: Dynamic) -> Dynamic
