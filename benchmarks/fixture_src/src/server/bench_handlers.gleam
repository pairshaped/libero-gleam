import server_context.{type ServerContext}
import shared/bench.{
  type AdminSummary, type BenchError, type GameData, type RecordPage,
  type ShotPayload, type TypeMatrix,
}

pub fn server_load_admin(
  value value: AdminSummary,
  server_context server_context: ServerContext,
) -> #(Result(AdminSummary, BenchError), ServerContext) {
  #(Ok(value), server_context)
}

pub fn server_load_records(
  value value: RecordPage,
  server_context server_context: ServerContext,
) -> #(Result(RecordPage, BenchError), ServerContext) {
  #(Ok(value), server_context)
}

pub fn server_load_game(
  value value: GameData,
  server_context server_context: ServerContext,
) -> #(Result(GameData, BenchError), ServerContext) {
  #(Ok(value), server_context)
}

pub fn server_load_shots(
  value value: ShotPayload,
  server_context server_context: ServerContext,
) -> #(Result(ShotPayload, BenchError), ServerContext) {
  #(Ok(value), server_context)
}

pub fn server_load_matrix(
  value value: TypeMatrix,
  server_context server_context: ServerContext,
) -> #(Result(TypeMatrix, BenchError), ServerContext) {
  #(Ok(value), server_context)
}
