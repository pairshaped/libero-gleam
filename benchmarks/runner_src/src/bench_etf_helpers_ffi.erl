-module(bench_etf_helpers_ffi).
-export([
    encode_response_admin/1,
    encode_response_records/1,
    encode_response_game/1,
    encode_response_shots/1,
    encode_response_matrix/1
]).

encode_response_admin(Result) ->
    encode_result(Result, fun 'generated@libero_wire':encode_shared_bench__admin_summary/1).

encode_response_records(Result) ->
    encode_result(Result, fun 'generated@libero_wire':encode_shared_bench__record_page/1).

encode_response_game(Result) ->
    encode_result(Result, fun 'generated@libero_wire':encode_shared_bench__game_data/1).

encode_response_shots(Result) ->
    encode_result(Result, fun 'generated@libero_wire':encode_shared_bench__shot_payload/1).

encode_response_matrix(Result) ->
    encode_result(Result, fun 'generated@libero_wire':encode_shared_bench__type_matrix/1).

encode_result({ok, Value}, EncodeOk) ->
    {ok, EncodeOk(Value)};
encode_result({error, Error}, _EncodeOk) ->
    {error, 'generated@libero_wire':encode_shared_bench__bench_error(Error)}.
