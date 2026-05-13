%% Test-only FFI helpers for libero codegen tests.

-module(libero_test_ffi).
-export([apply2/4, compile_module_from_source/1]).

apply2(Mod, Fun, Arg1, Arg2) ->
    erlang:apply(Mod, Fun, [Arg1, Arg2]).

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
