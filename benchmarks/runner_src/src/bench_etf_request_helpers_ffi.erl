-module(bench_etf_request_helpers_ffi).
-export([load_admin/1, load_records/1, load_game/1, load_shots/1, load_matrix/1]).

load_admin(Value) ->
    {_, Title, Selected, Filters, Flags} =
        'generated@libero_wire':encode_shared_bench__admin_summary(Value),
    {server_load_admin, Title, Selected, Filters, Flags}.

load_records(Value) ->
    {_, Items, Total, Page} =
        'generated@libero_wire':encode_shared_bench__record_page(Value),
    {server_load_records, Items, Total, Page}.

load_game(Value) ->
    {_, GameId, Home, Away, Events, ByCode} =
        'generated@libero_wire':encode_shared_bench__game_data(Value),
    {server_load_game, GameId, Home, Away, Events, ByCode}.

load_shots(Value) ->
    {_, GameId, Shots, ByPlayer} =
        'generated@libero_wire':encode_shared_bench__shot_payload(Value),
    {server_load_shots, GameId, Shots, ByPlayer}.

load_matrix(Value) ->
    {_, Blob, Status, Pair, Position, MaybePair, FallibleItem, IntLookup,
     BoolLookup, NestedResult, Unit} =
        'generated@libero_wire':encode_shared_bench__type_matrix(Value),
    {server_load_matrix, Blob, Status, Pair, Position, MaybePair, FallibleItem,
     IntLookup, BoolLookup, NestedResult, Unit}.
