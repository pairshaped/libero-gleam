import gleam/dynamic.{type Dynamic}
import shared/bench.{
  type AdminSummary, type GameData, type RecordPage, type ShotPayload,
  type TypeMatrix,
}

@external(erlang, "bench_etf_request_helpers_ffi", "load_admin")
pub fn load_admin(value: AdminSummary) -> Dynamic

@external(erlang, "bench_etf_request_helpers_ffi", "load_records")
pub fn load_records(value: RecordPage) -> Dynamic

@external(erlang, "bench_etf_request_helpers_ffi", "load_game")
pub fn load_game(value: GameData) -> Dynamic

@external(erlang, "bench_etf_request_helpers_ffi", "load_shots")
pub fn load_shots(value: ShotPayload) -> Dynamic

@external(erlang, "bench_etf_request_helpers_ffi", "load_matrix")
pub fn load_matrix(value: TypeMatrix) -> Dynamic
