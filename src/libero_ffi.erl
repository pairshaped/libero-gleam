%% Libero RPC panic-catching FFI.
%%
%% try_call(F) runs the zero-arg function F and returns {ok, Result}
%% on success, or {error, ReasonBinary} if the function throws or
%% raises an error. Exit signals are not caught and propagate normally
%% so process lifecycle (exit/1, shutdown) is not suppressed.
%% The reason is stringified so the caller can log it alongside a
%% trace_id without pattern-matching on arbitrary Erlang term shapes.

-module(libero_ffi).
-export([try_call/1, encode/1, decode/1, decode_safe/1, decode_typed/2,
         identity/1, unique_id/0, run_executable_capturing/2,
         find_executable/1, get_env/1, halt/1, ensure_decoders/0]).

identity(X) -> X.

encode(Term) ->
    QTerm = qualify_atoms(Term),
    erlang:term_to_binary(QTerm).

qualify_atoms({Atom, _} = Tuple) when is_atom(Atom) ->
    case persistent_term:get({libero, atom_map}, #{}) of
        #{Atom := Qualified} -> setelement(1, Tuple, Qualified);
        #{} -> Tuple
    end;
qualify_atoms(Atom) when is_atom(Atom) ->
    case persistent_term:get({libero, atom_map}, #{}) of
        #{Atom := Qualified} -> Qualified;
        #{} -> Atom
    end;
qualify_atoms(List) when is_list(List) ->
    [qualify_atoms(Item) || Item <- List];
qualify_atoms(Tuple) when is_tuple(Tuple) ->
    list_to_tuple([qualify_atoms(Item) || Item <- tuple_to_list(Tuple)]);
qualify_atoms(Map) when is_map(Map) ->
    maps:from_list([{qualify_atoms(K), qualify_atoms(V)} || {K, V} <- maps:to_list(Map)]);
qualify_atoms(Term) ->
    Term.

decode(Bin) ->
    erlang:binary_to_term(Bin, [safe]).

decode_safe(Bin) ->
    try erlang:binary_to_term(Bin, [safe]) of
        Term -> {ok, Term}
    catch
        _:Reason ->
            Msg = erlang:iolist_to_binary(
                io_lib:format("~p", [Reason])
            ),
            {error, {decode_error, Msg}}
    end.

%% On BEAM, ETF is native — the decoder_name is ignored since
%% binary_to_term already reconstructs all types correctly.
decode_typed(Bin, _DecoderName) ->
    decode_safe(Bin).

try_call(F) ->
    try F() of
        Result -> {ok, Result}
    catch
        throw:Reason ->
            Message = io_lib:format(
                "throw: ~p",
                [Reason]
            ),
            {error, erlang:iolist_to_binary(Message)};
        error:Reason:Stacktrace ->
            Message = io_lib:format(
                "~p~nstacktrace: ~p",
                [Reason, Stacktrace]
            ),
            {error, erlang:iolist_to_binary(Message)}
    end.

%% Return a short unique hex string for trace IDs and temp file names.
unique_id() ->
    Int = erlang:unique_integer([positive, monotonic]),
    Time = erlang:system_time(millisecond),
    erlang:iolist_to_binary(io_lib:format("~.16b-~.16b", [Time, Int])).

run_executable_capturing(Path, Args) ->
    Port = erlang:open_port(
        {spawn_executable, unicode:characters_to_list(Path)},
        [{args, [unicode:characters_to_list(A) || A <- Args]},
         exit_status, stderr_to_stdout, binary]
    ),
    wait_for_port_capturing(Port, []).

wait_for_port_capturing(Port, Acc) ->
    receive
        {Port, {exit_status, Status}} ->
            Output = iolist_to_binary(lists:reverse(Acc)),
            {Status, Output};
        {Port, {data, Data}} ->
            wait_for_port_capturing(Port, [Data | Acc])
    end.

find_executable(Name) ->
    case os:find_executable(unicode:characters_to_list(Name)) of
        false -> none;
        Path -> {some, unicode:characters_to_binary(Path)}
    end.

get_env(Name) ->
    case os:getenv(unicode:characters_to_list(Name)) of
        false -> none;
        Value -> {some, unicode:characters_to_binary(Value)}
    end.

halt(Code) ->
    erlang:halt(Code).

ensure_decoders() ->
    true.
