import shared/bench.{
  type AdminSummary, type GameData, type RecordPage, type ShotPayload,
  type TypeMatrix,
}

pub type RequestMsg {
  LoadAdmin(AdminSummary)
  LoadRecords(RecordPage)
  LoadGame(GameData)
  LoadShots(ShotPayload)
  LoadMatrix(TypeMatrix)
}
