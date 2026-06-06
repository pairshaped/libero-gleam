-module(bench_etf_request_helpers_ffi).
-export([load_admin/1, load_records/1, load_game/1, load_shots/1, load_matrix/1]).

load_admin(Value) ->
    'generated@libero_wire':encode_bench_requests__request_msg(
        {load_admin, Value}
    ).

load_records(Value) ->
    'generated@libero_wire':encode_bench_requests__request_msg(
        {load_records, Value}
    ).

load_game(Value) ->
    'generated@libero_wire':encode_bench_requests__request_msg(
        {load_game, Value}
    ).

load_shots(Value) ->
    'generated@libero_wire':encode_bench_requests__request_msg(
        {load_shots, Value}
    ).

load_matrix(Value) ->
    'generated@libero_wire':encode_bench_requests__request_msg(
        {load_matrix, Value}
    ).
