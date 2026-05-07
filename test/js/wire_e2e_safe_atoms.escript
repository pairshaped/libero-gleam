%% Verifies that atom pre-registration enables binary_to_term([safe])
%% to decode ETF containing custom enum and tagged-union constructor atoms.
%%
%% This test runs before any handler module has loaded those atoms into
%% the BEAM atom table, confirming that the generated atoms module is
%% the sole mechanism making [safe] decoding work.
%%
%% Called from wire_e2e_setup.sh:
%%   erl -noshell -pa <ebin_dirs> -eval "$(cat wire_e2e_safe_atoms.escript)" -extra true

EnsureMod = case os:getenv("ATOMS_MODULE") of
    false -> generated@rpc_atoms;
    M -> erlang:list_to_atom(M)
end,
EnsureMod:ensure(),

Tests = [
    %% Custom enum variant (zero-arity): {server_echo_status, active}
    {"tagged tuple with enum variant atom",
     erlang:term_to_binary({server_echo_status, active})},
    %% Record-like tuple with custom atom: {server_echo_item, {item, 7, <<"w">>, 1.0, true}}
    {"tagged tuple with record constructor atom",
     erlang:term_to_binary({server_echo_item, {item, 7, <<"w">>, 1.0, true}})}
],

Pass = fun(Label) ->
    io:format("  + ~s~n", [Label])
end,
Fail = fun(Label, Reason) ->
    io:format("  x ~s: ~p~n", [Label, Reason]),
    halt(1)
end,

lists:foreach(fun({Label, Binary}) ->
    case catch erlang:binary_to_term(Binary, [safe]) of
        {'EXIT', Reason} ->
            Fail(Label, Reason);
        _Result ->
            Pass(Label)
    end
end, Tests),

io:format("safe atoms test passed (~B cases)~n", [length(Tests)]),
halt().
