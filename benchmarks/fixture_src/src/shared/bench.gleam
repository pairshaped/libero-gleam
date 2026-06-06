import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type BenchError {
  BenchError(code: String, message: String)
}

pub type MatrixStatus {
  Draft
  Published
  Archived
}

pub type Pair {
  Pair(String, Int)
}

pub type AdminSummary {
  AdminSummary(
    title: String,
    selected: Option(Item),
    filters: Dict(String, String),
    flags: List(Bool),
  )
}

pub type Item {
  Item(id: Int, name: String, price: Float, in_stock: Bool, tags: List(String))
}

pub type RecordPage {
  RecordPage(items: List(Item), total: Int, page: Int)
}

pub type Team {
  Team(id: Int, name: String, seed: Int, active: Bool)
}

pub type Event {
  Event(id: Int, name: String, team: Team, metadata: Dict(String, String))
}

pub type GameData {
  GameData(
    game_id: String,
    home: Team,
    away: Team,
    events: List(Event),
    by_code: Dict(String, Event),
  )
}

pub type Shot {
  Shot(
    id: Int,
    player_id: Int,
    x: Float,
    y: Float,
    made: Bool,
    tags: List(String),
  )
}

pub type ShotPayload {
  ShotPayload(game_id: String, shots: List(Shot), by_player: Dict(String, Int))
}

pub type TypeMatrix {
  TypeMatrix(
    blob: BitArray,
    status: MatrixStatus,
    pair: Pair,
    position: #(Int, Float, String),
    maybe_pair: Option(Pair),
    fallible_item: Result(Item, BenchError),
    int_lookup: Dict(Int, String),
    bool_lookup: Dict(Bool, Item),
    nested_result: Result(List(Pair), BenchError),
    unit: Nil,
  )
}
