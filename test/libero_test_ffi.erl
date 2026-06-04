%% Test-only FFI helpers for libero codegen tests.

-module(libero_test_ffi).
-export([apply2/4, apply_catch/3, compile_module_from_source/1,
         deep_tuple/1, deep_tree/3, set_wire_module/1, clear_wire_module/0,
         term_to_binary/1, encoded_pid/0, encoded_ref/0, encoded_fun/0,
         encoded_port/0, encoded_request_with_pid/0]).

apply2(Mod, Fun, Arg1, Arg2) ->
    erlang:apply(Mod, Fun, [Arg1, Arg2]).

apply_catch(Mod, Fun, Args) ->
    try erlang:apply(Mod, Fun, Args) of
        Value -> {ok, Value}
    catch
        _:Reason -> {error, Reason}
    end.

compile_module_from_source(Source) when is_binary(Source) ->
    Str = binary_to_list(Source),
    {ok, Tokens, _} = erl_scan:string(Str),
    Forms = split_forms(Tokens, []),
    Parsed = [begin {ok, F} = erl_parse:parse_form(Toks), F end || Toks <- Forms],
    {ok, Mod, Bin} = compile:forms(Parsed, [return_errors]),
    {module, Mod} = code:load_binary(Mod, "", Bin),
    {ok, Mod}.

split_forms([], Acc) ->
    case Acc of
        [] -> [];
        _ -> [lists:reverse(Acc)]
    end;
split_forms([{dot, _} = Dot | Rest], Acc) ->
    [lists:reverse([Dot | Acc]) | split_forms(Rest, [])];
split_forms([Tok | Rest], Acc) ->
    split_forms(Rest, [Tok | Acc]).

deep_tuple(Depth) when Depth =< 0 ->
    leaf;
deep_tuple(Depth) ->
    {deep_tuple(Depth - 1)}.

deep_tree(_NodeHash, LeafHash, Depth) when Depth =< 0 ->
    LeafHash;
deep_tree(NodeHash, LeafHash, Depth) ->
    {NodeHash, Depth, deep_tree(NodeHash, LeafHash, Depth - 1), LeafHash}.

set_wire_module(Mod) ->
    persistent_term:put({libero, wire_module}, Mod),
    nil.

clear_wire_module() ->
    catch persistent_term:erase({libero, wire_module}),
    nil.

term_to_binary(Term) ->
    erlang:term_to_binary(Term).

encoded_pid() ->
    erlang:term_to_binary(self()).

encoded_ref() ->
    erlang:term_to_binary(make_ref()).

encoded_fun() ->
    erlang:term_to_binary(fun() -> ok end).

encoded_port() ->
    erlang:term_to_binary(hd(erlang:ports())).

encoded_request_with_pid() ->
    erlang:term_to_binary({<<"rpc">>, 123, self()}).
