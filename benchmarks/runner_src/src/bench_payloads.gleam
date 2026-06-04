import gleam/bit_array
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{Some}
import shared/bench.{
  type AdminSummary, type BenchError, type GameData, type Item, type RecordPage,
  type Shot, type ShotPayload, type TypeMatrix, AdminSummary, BenchError, Event,
  GameData, Item, Pair, Published, RecordPage, Shot, ShotPayload, Team,
  TypeMatrix,
}

pub type PayloadCase(payload) {
  PayloadCase(name: String, payload: payload, iterations: Int)
}

pub fn error() -> BenchError {
  BenchError(code: "invalid", message: "benchmark error payload")
}

pub fn admin_case() -> PayloadCase(AdminSummary) {
  PayloadCase(
    name: "small_admin",
    payload: AdminSummary(
      title: "Admin dashboard",
      selected: Some(item(1)),
      filters: dict.from_list([
        #("status", "active"),
        #("region", "north"),
        #("owner", "ops"),
      ]),
      flags: [True, False, True, True],
    ),
    iterations: 5000,
  )
}

pub fn records_case() -> PayloadCase(RecordPage) {
  let items = range(1, 150) |> list.map(item)
  PayloadCase(
    name: "repeated_records",
    payload: RecordPage(items: items, total: 150, page: 1),
    iterations: 1000,
  )
}

pub fn game_case() -> PayloadCase(GameData) {
  let home = Team(id: 10, name: "Home", seed: 1, active: True)
  let away = Team(id: 11, name: "Away", seed: 4, active: True)
  let events =
    range(1, 80)
    |> list.map(fn(index) {
      Event(
        id: index,
        name: "event-" <> int.to_string(index),
        team: case index % 2 {
          0 -> home
          _ -> away
        },
        metadata: dict.from_list([
          #("period", int.to_string(1 + index % 4)),
          #("clock", int.to_string(720 - index)),
        ]),
      )
    })
  let by_code =
    events
    |> list.map(fn(event) { #("E" <> int.to_string(event.id), event) })
    |> dict.from_list
  PayloadCase(
    name: "nested_game",
    payload: GameData(
      game_id: "game-2026-06-03",
      home:,
      away:,
      events:,
      by_code:,
    ),
    iterations: 500,
  )
}

pub fn shots_case() -> PayloadCase(ShotPayload) {
  let shots = range(1, 1000) |> list.map(shot)
  let by_player =
    range(1, 25)
    |> list.map(fn(player_id) {
      #("P" <> int.to_string(player_id), player_id * 40)
    })
    |> dict.from_list
  PayloadCase(
    name: "large_shots",
    payload: ShotPayload(game_id: "game-heavy", shots:, by_player:),
    iterations: 250,
  )
}

pub fn matrix_case() -> PayloadCase(TypeMatrix) {
  PayloadCase(
    name: "type_matrix",
    payload: TypeMatrix(
      blob: bit_array.from_string("matrix-binary-payload"),
      status: Published,
      pair: Pair("pair", 42),
      position: #(7, 3.14, "north"),
      maybe_pair: Some(Pair("maybe", 9)),
      fallible_item: Ok(item(7)),
      int_lookup: dict.from_list([#(1, "one"), #(2, "two"), #(3, "three")]),
      bool_lookup: dict.from_list([#(True, item(8)), #(False, item(9))]),
      nested_result: Ok([Pair("a", 1), Pair("b", 2)]),
      unit: Nil,
    ),
    iterations: 2500,
  )
}

fn item(id: Int) -> Item {
  Item(
    id:,
    name: "Item " <> int.to_string(id),
    price: int.to_float(id) /. 3.0,
    in_stock: id % 3 != 0,
    tags: ["bench", "item", "tag-" <> int.to_string(id % 5)],
  )
}

fn shot(id: Int) -> Shot {
  Shot(
    id:,
    player_id: 1 + id % 25,
    x: int.to_float(id % 100) /. 100.0,
    y: int.to_float(id % 47) /. 47.0,
    made: id % 2 == 0,
    tags: ["shot", "zone-" <> int.to_string(id % 8)],
  )
}

fn range(first: Int, last: Int) -> List(Int) {
  range_loop(first, last, [])
}

fn range_loop(current: Int, last: Int, acc: List(Int)) -> List(Int) {
  case current > last {
    True -> list.reverse(acc)
    False -> range_loop(current + 1, last, [current, ..acc])
  }
}
